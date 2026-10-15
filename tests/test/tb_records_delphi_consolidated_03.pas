{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case trhlp38.pas }
{$push}
{ without "inherited" the methods of the helper are called first }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  trhlp38_TTest = record
    function Test(aRecurse: Boolean): Integer;
  end;

  trhlp38_TTestHelper = record helper for trhlp38_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

function trhlp38_TTest.Test(aRecurse: Boolean): Integer;
begin
  Result := 1;
end;

function trhlp38_TTestHelper.Test(aRecurse: Boolean): Integer;
begin
  if aRecurse then
    Result := Test(False)
  else
    Result := 2;
end;

var
  trhlp38_t: trhlp38_TTest;
  trhlp38_res: Integer;

{$pop}

{ Case trhlp39.pas }
{$push}
{ methods defined in a helper have higher priority than those defined in the
  extended type }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  trhlp39_TTest = record
    function Test: Integer;
  end;

  trhlp39_TTestHelper = record helper for trhlp39_TTest
  private
    function Test: Integer;
  public
    function AccessTest: Integer;
  end;

function trhlp39_TTest.Test: Integer;
begin
  Result := 1;
end;

function trhlp39_TTestHelper.Test: Integer;
begin
  Result := 2;
end;

function trhlp39_TTestHelper.AccessTest: Integer;
begin
  Result := Test;
end;

var
  trhlp39_t: trhlp39_TTest;
  trhlp39_res: Integer;

{$pop}

{ Case trhlp7.pas }
{$push}
{ the size of a record helper is equivalent to that of a pointer }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  trhlp7_TTest = packed record
    s: String;
    i32: Integer;
    b: Boolean;
    i64: Int64;
  end;

  trhlp7_TTestHelper = record helper for trhlp7_TTest
  end;

var
  trhlp7_res: Integer;

{$pop}

{ Case trhlp8.pas }
{$push}
{ helpers may introduce new default properties }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  trhlp8_TTest = record

  end;

  trhlp8_TTestHelper = record helper for trhlp8_TTest
    function GetTest(aIndex: Integer): Integer;
    property Test[Index: Integer]: Integer read GetTest; default;
  end;

function trhlp8_TTestHelper.GetTest(aIndex: Integer): Integer;
begin
  Result := aIndex;
end;

var
  trhlp8_t: trhlp8_TTest;
  trhlp8_res: Integer;

{$pop}

{ Case trhlp9.pas }
{$push}
{ helpers may override existing default properties }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  trhlp9_TTest = record
  private
    function GetTest(aIndex: Integer): Integer;
  public
    property Test[Index: Integer]: Integer read GetTest; default;
  end;

  trhlp9_TTestHelper = record helper for trhlp9_TTest
    function GetTest(aIndex: Integer): Integer;
    property Test[Index: Integer]: Integer read GetTest; default;
  end;

function trhlp9_TTest.GetTest(aIndex: Integer): Integer;
begin
  Result := - aIndex;
end;

function trhlp9_TTestHelper.GetTest(aIndex: Integer): Integer;
begin
  Result := aIndex;
end;

var
  trhlp9_t: trhlp9_TTest;
  trhlp9_res: Integer;

{$pop}

begin

{ Case trhlp38.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  trhlp38_res := trhlp38_t.Test(True);
  Writeln('t.Test: ', trhlp38_res);
  if trhlp38_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case trhlp39.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  trhlp39_res := trhlp39_t.AccessTest;
  Writeln('t.AccessTest: ', trhlp39_res);
  if trhlp39_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case trhlp7.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  trhlp7_res := SizeOf(trhlp7_TTestHelper);
  Writeln('SizeOf(TTest): ', SizeOf(trhlp7_TTest));
  Writeln('SizeOf(TTestHelper): ', trhlp7_res);
  if trhlp7_res <> SizeOf(Pointer) then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case trhlp8.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  trhlp8_res := trhlp8_t[3];
  Writeln('value: ', trhlp8_res);
  if trhlp8_res <> 3 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case trhlp9.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  trhlp9_res := trhlp9_t[3];
  Writeln('value: ', trhlp9_res);
  if trhlp9_res <> 3 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

end.
