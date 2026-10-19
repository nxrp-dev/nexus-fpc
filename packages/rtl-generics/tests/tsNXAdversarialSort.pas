unit tsNXAdversarialSort;
{$mode objfpc}
{$h+}
{$typedaddress on}
{$modeswitch advancedrecords}
{$coperators on}
{$modeswitch anonymousfunctions}
{$modeswitch duplicatelocals}

interface
uses obNXTestRegistry;
procedure RegisterAdversarialSortTests(ARegistry: TNXTestRegistry);
implementation
uses
	obNXTestContext,
	{$ifdef unix}cwstring,{$endif}
	SysUtils, Generics.Collections, Generics.Defaults;


	generic procedure Swap<Ty>(var a, b: Ty);
	var
		temp: Ty;
	begin
		temp := a; a := b; b := temp;
	end;

type
	generic TTracingComparer<Ty> = class(specialize TComparer<Ty>)
		orig: specialize IComparer<Ty>;
		count: uint64;
		constructor Create(const orig: specialize IComparer<Ty>);
		function Compare(const a, b: Ty): integer; override;
	end;

	constructor TTracingComparer.Create(const orig: specialize IComparer<Ty>);
	begin
		inherited Create;
		self.orig := orig;
	end;

	function TTracingComparer.Compare(const a, b: Ty): integer;
	begin
		result := orig.Compare(a, b);
		count += 1;
	end;

type
	// https://igoro.com/archive/quicksort-killer/
	// Will work against wide range of qsort implementations.
	TQSortKillerComparer = class(specialize TComparer<SizeInt>)
		keys: array of int32; { TDictionary is a lot slower... }
		candidate, nKeys: int32;
		constructor Create(arrayLen: SizeInt);
		function Compare(const a, b: SizeInt): integer; override;
	end;

	constructor TQSortKillerComparer.Create(arrayLen: SizeInt);
	begin
		inherited Create;
		SetLength(keys, arrayLen);
		FillChar(pInt32(keys)^, length(keys) * sizeof(keys[0]), byte(-1));
	end;

	function TQSortKillerComparer.Compare(const a, b: SizeInt): integer;
	begin
		if keys[a] and keys[b] < 0 then
		begin
			if a = candidate then keys[a] := nKeys else keys[b] := nKeys;
			nKeys += 1;
		end;
		if keys[a] < 0 then begin candidate := a; exit(1); end;
		if keys[b] < 0 then begin candidate := b; exit(-1); end;
		result := keys[a] - keys[b];
	end;

type
	generic SortBenchmark<Ty> = record
	type
		CreateProc = function(id: SizeUint): Ty;
		TyArray = array of Ty;

		class procedure Run(create: CreateProc; const tyPlural: string; lenMul: double; AContext: TNXTestContext); static;
		class procedure BenchSort(const src, ref: array of Ty; var prevComparisons: uint64; AContext: TNXTestContext); static;
		// 'ref' must be sorted and contain no duplicates.
		class function BuildQSortKiller(const ref: array of Ty): TyArray; static;
	end;

	class procedure SortBenchmark.Run(create: CreateProc; const tyPlural: string; lenMul: double; AContext: TNXTestContext);
	type
		OrderEnum = (RandomOrder, QSortKillerOrder);
	const
		OrderNames: array[OrderEnum] of string = ('random', 'QSort killer');
	var
		ref, src: TyArray;
		i, lenBase, len: SizeInt;
		cmp: specialize IComparer<Ty>;
		srcOrder: OrderEnum;
		msg: string;
		prevComparisons: uint64;
	begin
		writeln('--- ', tyPlural, ' ---', LineEnding);

		for srcOrder in OrderEnum do
		begin
			writeln('Order: ', OrderNames[srcOrder], '.');
			prevComparisons := uint64(-1);
			for lenBase in specialize TArray<SizeInt>.Create(10 * 1000, 20 * 1000, 40 * 1000) do
			begin
				len := round(lenMul * lenBase);

				SetLength(ref, len);
				cmp := specialize TComparer<Ty>.Default;
				for i := 0 to len - 1 do
				begin
					ref[i] := create(i);
					if (i > 0) and (cmp.Compare(ref[i - 1], ref[i]) >= 0) then
					begin
						writeln('''create'' callback must return ', tyPlural, ' in strictly ascending order.');
						AContext.Fail('Adversarial sorting contract failed; see comparison diagnostics');
						exit;
					end;
				end;

				case srcOrder of
					RandomOrder:
						begin
							RandSeed := 1;
							src := Copy(ref);
							for i := len - 1 downto 1 do
								specialize Swap<Ty>(src[i], src[random(int64(i))]);
						end;

					QSortKillerOrder:
						src := BuildQSortKiller(ref);
				end;

				WriteStr(msg, 'n = ', len, ': ');
				write(msg.PadRight(12));
				BenchSort(src, ref, prevComparisons, AContext);
			end;
			writeln;
		end;
	end;

	class function SortBenchmark.BuildQSortKiller(const ref: array of Ty): TyArray;
	var
		ris: array of SizeInt;
		i: SizeInt;
		cmpRef: specialize IComparer<SizeInt>;
	begin
		SetLength(ris, length(ref));
		for i := 0 to High(ris) do ris[i] := i;
		cmpRef := TQSortKillerComparer.Create(length(ref));
		specialize TArrayHelper<SizeInt>.Sort(ris, cmpRef);
		SetLength(result, length(ref));
		for i := 0 to High(result) do result[ris[i]] := ref[i];
	end;

	class procedure SortBenchmark.BenchSort(const src, ref: array of Ty; var prevComparisons: uint64; AContext: TNXTestContext);
	var
		arr: TyArray;
		i: SizeInt;
		cmp: specialize TTracingComparer<Ty>;
		cmpRef: specialize IComparer<Ty>;
		prevCount: uint64;
	begin
		cmp := specialize TTracingComparer<Ty>.Create(specialize TComparer<Ty>.Default);
		cmpRef := cmp;

		arr := Copy(src);
		specialize TArrayHelper<Ty>.Sort(arr, cmpRef);
		prevCount := prevComparisons;
		prevComparisons := cmp.count;
		write(cmp.count, ' comparisons');
		if prevCount <> uint64(-1) then write(' (', cmp.count / prevCount:0:1, 'x from previous)');

		for i := 0 to High(ref) do
			if arr[i] <> ref[i] then
			begin
				writeln(', FAIL @ ', i, ' / ', length(ref));
				AContext.Fail('Adversarial sorting contract failed; see comparison diagnostics');
				exit;
			end;

		if (prevCount <> uint64(-1)) and (cmp.count > 2 * prevCount + prevCount div 2 + 5 * length(src) + 1000) then
		begin
			writeln(', potentially bad sorting algorithm behaviour');
			AContext.Fail('Adversarial sorting contract failed; see comparison diagnostics');
			exit;
		  end;
		writeln(', OK');
	end;

procedure Strings(AContext: TNXTestContext);
var lSeed: Cardinal;
begin
  lSeed := RandSeed;
  RandSeed := 1;
  try
	specialize SortBenchmark<string>.Run(
		function(id: SizeUint): string
		begin
			SetLength(result, 5);
			result[5] := Char(ord('A') + id mod 26); id := id div 26;
			result[4] := Char(ord('A') + id mod 26); id := id div 26;
			result[3] := Char(ord('A') + id mod 26); id := id div 26;
			result[2] := Char(ord('A') + id mod 26); id := id div 26;
			result[1] := Char(ord('A') + id mod 26);
		end, 'strings', 0.15, AContext);

  finally
    RandSeed := lSeed;
  end;
end;

procedure Float32(AContext: TNXTestContext);
var lSeed: Cardinal;
begin
  lSeed := RandSeed;
  RandSeed := 1;
  try

	specialize SortBenchmark<single>.Run(
		function(id: SizeUint): single
		begin
			result := -1000 + id / 1000;
		end, 'float32''s', 1.0, AContext);

  finally
    RandSeed := lSeed;
  end;
end;

procedure RegisterAdversarialSortTests(ARegistry: TNXTestRegistry);
begin
  ARegistry.AddSuite('Generics.Sorting.Adversarial').AddTest('Strings', @Strings, 'generics-sorting');
  ARegistry.AddSuite('Generics.Sorting.Adversarial').AddTest('Float32', @Float32, 'generics-sorting');
end;
end.
