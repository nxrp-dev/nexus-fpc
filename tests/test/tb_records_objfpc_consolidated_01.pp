{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tanonfunc35.pp }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test anonymous methods with calling conventions }

type
  tanonfunc35_TRec = record
    l: longint;
    c: ansichar;
    b: boolean;
    p: ^tanonfunc35_TRec;
  end;

  tanonfunc35_TCdeclFunc = reference to function(l: longint; tanonfunc35_r: tanonfunc35_TRec): longint cdecl;
  tanonfunc35_TRegisterFunc = reference to function(l: longint; tanonfunc35_r: tanonfunc35_TRec): longint register;

procedure tanonfunc35_Foo(aRec: tanonfunc35_TRec);
var
  cdeclFunc: tanonfunc35_TCdeclFunc;
  registerFunc: tanonfunc35_TRegisterFunc;
begin
  cdeclFunc := function(l: longint; tanonfunc35_r: tanonfunc35_TRec): longint cdecl
  begin
    Result := l + tanonfunc35_r.l;
    if tanonfunc35_r.c <> 'a' then
      halt(1);
  end;
  if cdeclFunc(123, aRec) <> 246 then
    halt(2);

  registerFunc := function(l: longint; tanonfunc35_r: tanonfunc35_TRec): longint register
  begin
    Result := l + tanonfunc35_r.l;
    if tanonfunc35_r.c <> 'a' then
      halt(3);
  end;
  if registerFunc(321, aRec) <> 444 then
    halt(4);
end;

var
  tanonfunc35_r: tanonfunc35_TRec;

{$pop}

{ Case tanonfunc43.pp }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test capturing record and array variables }

type
  tanonfunc43_TIntFunc = reference to function: Integer;

function tanonfunc43_TestCaptureArray: tanonfunc43_TIntFunc;
var
  A: array[0..15] of Integer;
begin
  Result := function: Integer
    begin
      Result := A[0] + A[1];
    end;
  A[0] := 1;
  A[1] := 2;
end;

function tanonfunc43_TestCaptureRecord: tanonfunc43_TIntFunc;
var
  R: record
    I1, I2: Integer;
  end;
begin
  Result := function: Integer
    begin
      Result := R.I1 + R.I2;
    end;
  R.I1 := 1;
  R.I2 := 2;
end;


{$pop}

{ Case tanonfunc44.pp }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test capturing record and array arguments }

type
  tanonfunc44_TIntFunc = reference to function: Integer;

  tanonfunc44_TIntArr = array[0..15] of Integer;
  tanonfunc44_TIntRec = record
    I1, I2: Integer;
    P1, P2: Pointer;
  end;

function tanonfunc44_TestCaptureArray(tanonfunc44_A: tanonfunc44_TIntArr): tanonfunc44_TIntFunc;
begin
  Result := function: Integer
    begin
      Result := tanonfunc44_A[0] + tanonfunc44_A[1];
    end;
end;

function tanonfunc44_TestCaptureRecord(tanonfunc44_R: tanonfunc44_TIntRec): tanonfunc44_TIntFunc;
begin
  Result := function: Integer
    begin
      Result := tanonfunc44_R.I1 + tanonfunc44_R.I2;
    end;
end;

var
  tanonfunc44_A: tanonfunc44_TIntArr;
  tanonfunc44_R: tanonfunc44_TIntRec;
  tanonfunc44_F: tanonfunc44_TIntFunc;

{$pop}

begin

{ Case tanonfunc35.pp }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc35_r.l := 123;
  tanonfunc35_r.c := 'a';
  tanonfunc35_r.b := False;
  tanonfunc35_r.p := @tanonfunc35_r;
  tanonfunc35_Foo(tanonfunc35_r);
end;
{$pop}

{ Case tanonfunc43.pp }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  if tanonfunc43_TestCaptureArray()() <> 3 then
    Halt(1);

  if tanonfunc43_TestCaptureRecord()() <> 3 then
    Halt(2);
end;
{$pop}

{ Case tanonfunc44.pp }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc44_A[0] := 1;
  tanonfunc44_A[1] := 2;
  tanonfunc44_F := tanonfunc44_TestCaptureArray(tanonfunc44_A);
  if tanonfunc44_F() <> 3 then
    Halt(1);

  tanonfunc44_A[0] := 3;
  if tanonfunc44_F() <> 3 then
    Halt(2);

  tanonfunc44_R.I1 := 1;
  tanonfunc44_R.I2 := 2;
  tanonfunc44_F := tanonfunc44_TestCaptureRecord(tanonfunc44_R);
  if tanonfunc44_F() <> 3 then
    Halt(3);

  tanonfunc44_R.I1 := 3;
  if tanonfunc44_F() <> 3 then
    Halt(3);
end;
{$pop}

end.
