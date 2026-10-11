{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb0728.pp }
{$push}



{$modeswitch advancedrecords}

type
  { with the Spacer field we make sure that TSmallPoint is passed as reference
    for const parameters also on non-Windows }
  tb0728_TSmallPoint =
  packed record
      X,
      Y : SmallInt;
      Spacer: array[0..7] of SmallInt;
      end;

  tb0728_TPoint  =
  record
       X : Longint; Y : Longint;
     public
       class operator := (const aspt : tb0728_TSmallPoint) : tb0728_TPoint;
     end;

  class operator tb0728_TPoint.:= (const aspt : tb0728_TSmallPoint): tb0728_TPoint;
  begin
    result.x:=aspt.x;
    result.y:=aspt.y;
  end;

var
  tb0728_s: tb0728_TSmallPoint;
  tb0728_p: tb0728_TPoint;

{$pop}

{ Case tw40392.pp }
{$push}
 {$modeswitch advancedrecords}

{ define doublefree}
var
	tw40392_InitCount: int32 = 0;

type
	tw40392_ManRec = record
		x: int32;
		class operator Initialize(var self: tw40392_ManRec);
		class operator Finalize(var self: tw40392_ManRec);
		class operator Copy(constref b: tw40392_ManRec; var self: tw40392_ManRec);
		class operator AddRef(var self: tw40392_ManRec);
	end;

	class operator tw40392_ManRec.Initialize(var self: tw40392_ManRec);
	begin
		inc(tw40392_InitCount);
	end;

	class operator tw40392_ManRec.Finalize(var self: tw40392_ManRec);
	begin
		dec(tw40392_InitCount);
	end;

	class operator tw40392_ManRec.Copy(constref b: tw40392_ManRec; var self: tw40392_ManRec);
	begin
		writeln('shouldn''t happen');
		halt(1);
	end;

	class operator tw40392_ManRec.AddRef(var self: tw40392_ManRec);
	begin
		writeln('shouldn''t happen');
		halt(2);
	end;

	function tw40392_GetManRec: tw40392_ManRec;
	begin
		result.x := 1;
	end;

	procedure tw40392_Use(const mr: tw40392_ManRec);
	begin
	end;

	procedure tw40392_Main;
	var
		mr: tw40392_ManRec;
	begin
	{$ifdef doublefree}
		tw40392_GetManRec; // imperfect, double Finalize()
	{$else}
		mr := tw40392_GetManRec; // ok
		tw40392_Use(tw40392_GetManRec); // ok as well
	{$endif}
	end;


{$pop}

{ Case tmoperator12.pp }
{$push}
{$H+}
{$ModeSwitch AdvancedRecords}

type
  tmoperator12_TMyRec = record
    i: Integer;
    class operator :=(const rhs: Integer): tmoperator12_TMyRec;
    class operator Copy(constref src: tmoperator12_TMyRec; var dst: tmoperator12_TMyRec);
    class operator +(const lhs,rhs: tmoperator12_TMyRec): tmoperator12_TMyRec;
  end;

class operator tmoperator12_TMyRec.:=(const rhs: Integer): tmoperator12_TMyRec;
begin
  Result.i:=rhs;
end;

var
  tmoperator12_CopyCount: Integer = 0;
class operator tmoperator12_TMyRec.Copy(constref src: tmoperator12_TMyRec; var dst: tmoperator12_TMyRec);
begin
  Inc(tmoperator12_CopyCount);
  dst.i:=src.i;
end;

class operator tmoperator12_TMyRec.+(const lhs,rhs: tmoperator12_TMyRec): tmoperator12_TMyRec;
begin
  Result.i:=lhs.i+rhs.i;
end;

var
  tmoperator12_r1, tmoperator12_r2, tmoperator12_r3: tmoperator12_TMyRec;

{$pop}

{ Case toperator94.pp }
{$push}



{$modeswitch advancedrecords}

type
  toperator94_TString80 = String[80];
  toperator94_TString90 = String[90];
  toperator94_TString40 = String[40];
  toperator94_TString100 = String[100];

  toperator94_TTest1 = record
    class operator :=(const aArg: toperator94_TTest1): toperator94_TString80;
  end;

  toperator94_TTest2 = record
    class operator :=(const aArg: toperator94_TTest2): ShortString;
  end;

var
  toperator94_ImplicitTest1ShortString: LongInt;
  toperator94_ImplicitTest1String80: LongInt;
  toperator94_ImplicitTest2ShortString: LongInt;
  toperator94_ImplicitTest2String80: LongInt;

class operator toperator94_TTest1.:=(const aArg: toperator94_TTest1): toperator94_TString80;
begin
  Writeln('TTest1 Implicit TString80');
  Inc(toperator94_ImplicitTest1String80);
  Result := '';
end;

class operator toperator94_TTest2.:=(const aArg: toperator94_TTest2): ShortString;
begin
  Writeln('TTest2 Implicit ShortString');
  Inc(toperator94_ImplicitTest2ShortString);
  Result := '';
end;

operator :=(const aArg: toperator94_TTest1): ShortString;
begin
  Writeln('TTest1 Implicit ShortString');
  Inc(toperator94_ImplicitTest1ShortString);
  Result := '';
end;

operator :=(const aArg: toperator94_TTest2): toperator94_TString80;
begin
  Writeln('TTest2 Implicit TString80');
  Inc(toperator94_ImplicitTest2String80);
  Result := '';
end;

var
  toperator94_t1: toperator94_TTest1;
  toperator94_t2: toperator94_TTest2;
  toperator94_s80: toperator94_TString80;

{$pop}

begin

{ Case tb0728.pp }
{$push}

{$modeswitch advancedrecords}
begin
  tb0728_s.x:=123;
  tb0728_s.y:=-2;
  tb0728_p:=tb0728_s;
  if tb0728_p.x <> 123 then
    Halt(1);
  if tb0728_p.y <> -2 then
    Halt(2);
  Writeln('ok');
end;
{$pop}

{ Case tw40392.pp }
{$push}

{$modeswitch advancedrecords}
{$ifdef doublefree}
{$else}
{$endif}
begin
	tw40392_Main;
	writeln('InitCount = ', tw40392_InitCount, ' (should ideally be 0).');
        if tw40392_InitCount <> 0 then
          halt(1);
end;
{$pop}

{ Case tmoperator12.pp }
{$push}

{$H+}
{$ModeSwitch AdvancedRecords}
begin
  tmoperator12_r1 := 42;
  tmoperator12_r2 := 32;
  tmoperator12_r3 := tmoperator12_r1 + tmoperator12_r2;
  if tmoperator12_r3.i<>42+32 then
    Halt(1);
  if tmoperator12_CopyCount <> 0 then
    Halt(2);
  WriteLn('Ok');
end;
{$pop}

{ Case toperator94.pp }
{$push}

{$modeswitch advancedrecords}
begin
  toperator94_s80 := toperator94_t1;
  if toperator94_ImplicitTest1ShortString <> 1 then
    Halt(1);
  toperator94_s80 := toperator94_t2;
  if toperator94_ImplicitTest2ShortString <> 1 then
    Halt(2);
  Writeln('ok');
end;
{$pop}

end.
