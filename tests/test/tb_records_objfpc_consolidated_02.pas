{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tforin25.pas }
{$push}


{$modeswitch advancedrecords}

type
  tforin25_TIntArray = array[0..3] of Integer;

  tforin25_TEnumerator = record
  private
    FIndex: Integer;
    FArray: tforin25_TIntArray;
    function GetCurrent: Integer;
  public
    function MoveNext: Boolean;
    property Current: Integer read GetCurrent;
  end;

  tforin25_TMyArray = record
    F: array[0..3] of Integer;
    function GetEnumerator: tforin25_TEnumerator;
  end;

function tforin25_TEnumerator.MoveNext: Boolean;
begin
  inc(FIndex);
  Result := FIndex < Length(FArray);
end;

function tforin25_TEnumerator.GetCurrent: Integer;
begin
  Result := FArray[FIndex];
end;

function tforin25_TMyArray.GetEnumerator: tforin25_TEnumerator;
begin
  Result.FArray := F;
  Result.FIndex := -1;
end;
{ this will compile too
operator Enumerator(const A: TMyArray): TEnumerator;
begin
  Result.FArray := A.F;
  Result.FIndex := -1;
end;
}
var
  tforin25_Arr: tforin25_TMyArray;
  tforin25_I: Integer;

{$pop}

{ Case tisconstvalue1.pas }
{$push}



{$modeswitch advancedrecords}

type
  tisconstvalue1_TTestLongInt = record
    a: LongInt;
  end;

  tisconstvalue1_TTestAnsiString = record
    a: AnsiString;
  end;
{
  TTestManaged = record
    a: LongInt;
    class operator Initialize(var aTestManaged: TTestManaged);
  end;

  class operator TTestManaged.Initialize(var aTestManaged: TTestManaged);
  begin
    aTestManaged.a := 42;
  end;
}
type
  tisconstvalue1_TDynArrayLongInt = array of LongInt;
  tisconstvalue1_TStaticArrayAnsiString = array[0..4] of AnsiString;

  tisconstvalue1_TEnum = (tisconstvalue1_eOne, tisconstvalue1_eTwo, tisconstvalue1_eThree);
  tisconstvalue1_TSet = set of (sOne, sTwo, sThree);

const
  // untyped
  tisconstvalue1_Number = 100;
  tisconstvalue1_Str = 'Hello World!';
  tisconstvalue1_Dbl = 1.1;
  tisconstvalue1_NilPtr = nil;
  tisconstvalue1_IsConst = True;
  tisconstvalue1_GUID = '{10101010-1010-0101-1001-110110110110}';
  // typed
  tisconstvalue1_IntConst: Integer = 13;
  tisconstvalue1_RealConst: Real = 12;
  tisconstvalue1_Alphabet: array [1..26] of char =
       ('A','B','C','D','E','F','G','H','I',
        'J','K','L','M','N','O','P','Q','R',
        'S','T','U','V','W','X','Y','Z');
  tisconstvalue1_MyGUID: TGUID = '{10101010-1010-0101-1001-110110110110}';
  tisconstvalue1_Bool: Boolean = False;

var
  tisconstvalue1_l: LongInt;
  tisconstvalue1_o: TObject;
  tisconstvalue1__as: AnsiString;
  tisconstvalue1_lir: tisconstvalue1_TTestLongInt;
  tisconstvalue1_asr: tisconstvalue1_TTestAnsiString;
  //mr: TTestManaged;
  tisconstvalue1_liarr: tisconstvalue1_TDynArrayLongInt;
  tisconstvalue1_sasarr: tisconstvalue1_TStaticArrayAnsiString;


{$pop}

{ Case trhlp31.pas }
{$push}
{ methods introduced by the helper's parent hide the record methods as well }


{$ifdef fpc}
  
  {$modeswitch advancedrecords}
{$endif}

type
  trhlp31_TTest = record
    function Test: Integer;
  end;

  trhlp31_TTestHelper = record helper for trhlp31_TTest
    function Test: Integer;
  end;

  trhlp31_TTestHelperSub = record helper(trhlp31_TTestHelper) for trhlp31_TTest
  end;

function trhlp31_TTest.Test: Integer;
begin
  Result := 1;
end;

function trhlp31_TTestHelper.Test: Integer;
begin
  Result := 2;
end;

var
  trhlp31_t: trhlp31_TTest;
  trhlp31_res: Integer;

{$pop}

begin

{ Case tforin25.pas }
{$push}

{$modeswitch advancedrecords}
begin
  for tforin25_I in tforin25_Arr do
    WriteLn(tforin25_I);
end;
{$pop}

{ Case tisconstvalue1.pas }
{$push}

{$modeswitch advancedrecords}
begin
  tisconstvalue1_l := 1;
  if IsConstValue(tisconstvalue1_l) then
    Halt(1);

  tisconstvalue1_o := TObject.Create;
  try
    if IsConstValue(tisconstvalue1_o) then
      Halt(2);
  finally
    tisconstvalue1_o.Free;
  end;

  tisconstvalue1__as := 'Hello World!';
  if IsConstValue(tisconstvalue1__as) then
    Halt(3);

  if not IsConstValue(tisconstvalue1_eOne) then
    Halt(4);
  if not IsConstValue(tisconstvalue1_eTwo) then
    Halt(5);
  if not IsConstValue(tisconstvalue1_eThree) then
    Halt(6);

  if not IsConstValue(tisconstvalue1_Number) then
    Halt(7);
  if not IsConstValue(tisconstvalue1_Str) then
    Halt(8);

  tisconstvalue1_lir.a := 5;
  if IsConstValue(tisconstvalue1_lir) then
    Halt(9);

  tisconstvalue1_asr.a := 'Hello World!';
  if IsConstValue(tisconstvalue1_asr) then
    Halt(10);
{
  if IsConstValue(mr) then
    Halt(11);
}
  SetLength(tisconstvalue1_liarr, 2);
  tisconstvalue1_liarr[0] := 1;
  tisconstvalue1_liarr[1] := 2;
  if IsConstValue(tisconstvalue1_liarr) then
    Halt(12);

  tisconstvalue1_sasarr[0] := 'Hell';
  tisconstvalue1_sasarr[1] := 'o ';
  tisconstvalue1_sasarr[2] := 'Wor';
  tisconstvalue1_sasarr[3] := 'ld!';
  if IsConstValue(tisconstvalue1_sasarr) then
    Halt(13);

  if not IsConstValue(sOne) then
    Halt(14);
  if not IsConstValue(sTwo) then
    Halt(15);
  if not IsConstValue(sThree) then
    Halt(16);

  if not IsConstValue(tisconstvalue1_Dbl) then
    Halt(17);

  if not IsConstValue(tisconstvalue1_NilPtr) then
    Halt(18);

  if not IsConstValue(tisconstvalue1_IsConst) then
    Halt(19);

  if not IsConstValue(tisconstvalue1_GUID) then
    Halt(20);

  if IsConstValue(tisconstvalue1_IntConst) then
    Halt(21);

  if IsConstValue(tisconstvalue1_RealConst) then
    Halt(22);

  if IsConstValue(tisconstvalue1_Alphabet) then
    Halt(23);

  if IsConstValue(tisconstvalue1_MyGUID) then
    Halt(24);

  if IsConstValue(tisconstvalue1_Bool) then
    Halt(25);

  Writeln('Ok');
end;
{$pop}

{ Case trhlp31.pas }
{$push}
{$ifdef fpc}

{$modeswitch advancedrecords}
{$endif}
begin
  trhlp31_res := trhlp31_t.Test;
  Writeln('t.Test: ', trhlp31_res);
  if trhlp31_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

end.
