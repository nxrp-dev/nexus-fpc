program NXHashPreBench;

{$mode objfpc}
{$H+}

uses
  SysUtils,
  Windows,
  CClasses,
  GlobType;

const
  ItemCount = 131072;
  IterationCount = 8;
  RunCount = 5;

type
  TSymStrArray = array of TSymStr;
  THashArray = array of LongWord;
  TTimeArray = array[0..RunCount-1] of QWord;

function Counter: QWord;
var
  Value: Int64;
begin
  QueryPerformanceCounter(Value);
  Result:=QWord(Value);
end;

function MillisecondsSince(Started: QWord): QWord;
var
  Frequency: Int64;
begin
  QueryPerformanceFrequency(Frequency);
  Result:=((Counter-Started)*1000+QWord(Frequency div 2)) div QWord(Frequency);
end;

procedure SortTimes(var Values: TTimeArray);
var
  LeftIndex: LongInt;
  RightIndex: LongInt;
  Temporary: QWord;
begin
  for LeftIndex:=Low(Values) to High(Values)-1 do
    for RightIndex:=LeftIndex+1 to High(Values) do
      if Values[RightIndex]<Values[LeftIndex] then
        begin
          Temporary:=Values[LeftIndex];
          Values[LeftIndex]:=Values[RightIndex];
          Values[RightIndex]:=Temporary;
        end;
end;

procedure BuildNames(out Names: TSymStrArray; out Hashes: THashArray);
var
  Index: LongInt;
begin
  SetLength(Names, ItemCount);
  SetLength(Hashes, ItemCount);
  for Index:=0 to ItemCount-1 do
    begin
      Names[Index]:='symbol_'+IntToHex(Index, 8)+'_'+IntToHex(Index*2654435761, 8);
      Hashes[Index]:=FPHash(Names[Index]);
    end;
end;

function BenchmarkNormal(const Names: TSymStrArray): QWord;
var
  HashList: TViHashList;
  Iteration: LongInt;
  Index: LongInt;
  Hash: LongWord;
  Started: QWord;
begin
  Started:=Counter;
  for Iteration:=1 to IterationCount do
    begin
      HashList:=TViHashList.Create;
      try
        for Index:=0 to ItemCount-1 do
          begin
            Hash:=FPHash(Names[Index]);
            if HashList.FindWithHash(Names[Index], Hash)<>nil then
              Halt(1);
            HashList.Add(Names[Index], Pointer(PtrUInt(Index+1)));
          end;
      finally
        HashList.Free;
      end;
    end;
  Result:=MillisecondsSince(Started);
end;

function BenchmarkPrehashed(const Names: TSymStrArray): QWord;
var
  HashList: TViHashList;
  Iteration: LongInt;
  Index: LongInt;
  Hash: LongWord;
  Started: QWord;
begin
  Started:=Counter;
  for Iteration:=1 to IterationCount do
    begin
      HashList:=TViHashList.Create;
      try
        for Index:=0 to ItemCount-1 do
          begin
            Hash:=FPHash(Names[Index]);
            if HashList.FindWithHash(Names[Index], Hash)<>nil then
              Halt(1);
            HashList.AddWithHash(Names[Index], Hash,
              Pointer(PtrUInt(Index+1)));
          end;
      finally
        HashList.Free;
      end;
    end;
  Result:=MillisecondsSince(Started);
end;

var
  Names: TSymStrArray;
  Hashes: THashArray;
  NormalTimes: TTimeArray;
  PrehashedTimes: TTimeArray;
  RunIndex: LongInt;
  HashList: TViHashList;
begin
  BuildNames(Names, Hashes);
  HashList:=TViHashList.Create;
  try
    HashList.AddWithHash(Names[100], Hashes[100], Pointer(PtrUInt(101)));
    if PtrUInt(HashList.FindWithHash(Names[100], Hashes[100]))<>101 then
      Halt(1);
  finally
    HashList.Free;
  end;

  for RunIndex:=0 to RunCount-1 do
    begin
      NormalTimes[RunIndex]:=BenchmarkNormal(Names);
      PrehashedTimes[RunIndex]:=BenchmarkPrehashed(Names);
    end;
  SortTimes(NormalTimes);
  SortTimes(PrehashedTimes);
  Writeln('normal_add_median_ms=', NormalTimes[RunCount div 2]);
  Writeln('prehashed_add_median_ms=', PrehashedTimes[RunCount div 2]);
end.
