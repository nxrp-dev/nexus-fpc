{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case trhlp10.pas }
{$push}
{ helpers may introduce new default properties (includes default properties
  introduced by the helper's parent) }


{$ifdef fpc}
  
  {$modeswitch advancedrecords}
{$endif}
{$apptype console}

type
  trhlp10_TTest = record

  end;

  trhlp10_TTestHelper = record helper for trhlp10_TTest
    function GetTest(aIndex: Integer): Integer;
    property Test[Index: Integer]: Integer read GetTest; default;
  end;

  trhlp10_TTestHelperSub = record helper(trhlp10_TTestHelper) for trhlp10_TTest
  end;

function trhlp10_TTestHelper.GetTest(aIndex: Integer): Integer;
begin
  Result := aIndex;
end;

var
  trhlp10_t: trhlp10_TTest;
  trhlp10_res: Integer;

{$pop}

{ Case trhlp32.pas }
{$push}
{ methods of the extended record can be called using "inherited", but only in
  mode ObjFPC }


{$ifdef fpc}
  
  {$modeswitch advancedrecords}
{$endif}
{$apptype console}

type
  trhlp32_TTest = record
    function Test(aRecurse: Boolean): Integer;
  end;

  trhlp32_TTestHelper = record helper for trhlp32_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

function trhlp32_TTest.Test(aRecurse: Boolean): Integer;
begin
  Result := 1;
end;

function trhlp32_TTestHelper.Test(aRecurse: Boolean): Integer;
begin
  if aRecurse then
    Result := inherited Test(False)
  else
    Result := 2;
end;

var
  trhlp32_t: trhlp32_TTest;
  trhlp32_res: Integer;

{$pop}

{ Case trhlp34.pas }
{$push}
{ the extended record has higher priority than the parent helper when
  searching for symbols }


{$ifdef fpc}
  
  {$modeswitch advancedrecords}
{$endif}
{$apptype console}

type
  trhlp34_TTest = record
    function Test(aRecurse: Boolean): Integer;
  end;

  trhlp34_TTestHelper = record helper for trhlp34_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

  trhlp34_TTestHelperSub = record helper(trhlp34_TTestHelper) for trhlp34_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

function trhlp34_TTest.Test(aRecurse: Boolean): Integer;
begin
  Result := 1;
end;

function trhlp34_TTestHelper.Test(aRecurse: Boolean): Integer;
begin
  Result := 2;
end;

function trhlp34_TTestHelperSub.Test(aRecurse: Boolean): Integer;
begin
  if aRecurse then
    Result := inherited Test(False)
  else
    Result := 3;
end;

var
  trhlp34_t: trhlp34_TTest;
  trhlp34_res: Integer;

{$pop}

{ Case trhlp37.pas }
{$push}
{ test that helpers can access the methods of the parent helper using
  "inherited" }


{$ifdef fpc}
  
  {$modeswitch advancedrecords}
{$endif}
{$apptype console}

type
  trhlp37_TTest = record

  end;

  trhlp37_TTestHelper = record helper for trhlp37_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

  trhlp37_TTestHelperSub = record helper(trhlp37_TTestHelper) for trhlp37_TTest
    function Test(aRecurse: Boolean): Integer;
  end;

function trhlp37_TTestHelper.Test(aRecurse: Boolean): Integer;
begin
  Result := 1;
end;

function trhlp37_TTestHelperSub.Test(aRecurse: Boolean): Integer;
begin
  if aRecurse then
    Result := inherited Test(False)
  else
    Result := 2;
end;

var
  trhlp37_t: trhlp37_TTest;
  trhlp37_res: Integer;

{$pop}

begin

{ Case trhlp10.pas }
{$push}
{$ifdef fpc}

{$modeswitch advancedrecords}
{$endif}
{$apptype console}
begin
  trhlp10_res := trhlp10_t[3];
  Writeln('value: ', trhlp10_res);
  if trhlp10_res <> 3 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case trhlp32.pas }
{$push}
{$ifdef fpc}

{$modeswitch advancedrecords}
{$endif}
{$apptype console}
begin
  trhlp32_res := trhlp32_t.Test(True);
  Writeln('t.Test: ', trhlp32_res);
  if trhlp32_res <> 1 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case trhlp34.pas }
{$push}
{$ifdef fpc}

{$modeswitch advancedrecords}
{$endif}
{$apptype console}
begin
  trhlp34_res := trhlp34_t.Test(True);
  Writeln('t.Test: ', trhlp34_res);
  if trhlp34_res <> 1 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case trhlp37.pas }
{$push}
{$ifdef fpc}

{$modeswitch advancedrecords}
{$endif}
{$apptype console}
begin
  trhlp37_res := trhlp37_t.Test(True);
  Writeln('t.Test: ', trhlp37_res);
  if trhlp37_res <> 1 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

end.
