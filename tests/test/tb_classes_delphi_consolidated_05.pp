{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Preserve terminal exit-status assertions while allowing later cases to run. }
procedure CheckCaseExitCode(AValue: LongInt);
begin
  if AValue <> 0 then Halt(AValue);
end;

{ Case tfuncref24.pp }
{$push}



{$modeswitch functionreferences}


type
  tfuncref24_TLongIntFunc = reference to function(aArg: LongInt): LongInt;

  tfuncref24_TTest = class
    i: LongInt;
    function TestCaptureSelf: tfuncref24_TLongIntFunc;
  end;


function tfuncref24_TestNoCapture: tfuncref24_TLongIntFunc;

  function Foobar(aArg: LongInt): LongInt;
  begin
    Result := 42 * aArg;
  end;

begin
  Result := Foobar;
end;

function tfuncref24_TestCaptureLocal: tfuncref24_TLongIntFunc;
var
  i: LongInt;

  function Foobar(aArg: LongInt): LongInt;
  begin
    Result := i * aArg;
  end;

begin
  i := 0;
  Result := Foobar;
  i := 21;
end;

function tfuncref24_TTest.TestCaptureSelf: tfuncref24_TLongIntFunc;

  function Foobar(aArg: LongInt): LongInt;
  begin
    Result := i * aArg;
  end;

begin
  i := 0;
  Result := Foobar;
  i := 84;
end;

var
  tfuncref24_t: tfuncref24_TTest;
  tfuncref24_f: tfuncref24_TLongIntFunc;

{$pop}

{ Case tfuncref45.pp }
{$push}



{$modeswitch functionreferences}

{ test assigning global procedures, methods, and object methods to function
  references

  same as tfuncref8 but with mode delphi
}

type
  tfuncref45_TProc = reference to procedure;

procedure tfuncref45_CallProc(AProc: tfuncref45_TProc);
begin
  AProc();
end;

type
  tfuncref45_TTest = class
    class procedure ClassMethod;
    procedure InstanceMethod;
  end;

var
  tfuncref45_Acc: Integer;

procedure tfuncref45_GlobalProc;
begin
  Inc(tfuncref45_Acc);
end;

class procedure tfuncref45_TTest.ClassMethod;
begin
  Inc(tfuncref45_Acc, 10);
end;

procedure tfuncref45_TTest.InstanceMethod;
begin
  Inc(tfuncref45_Acc, 100);
end;

var
  tfuncref45_Proc: tfuncref45_TProc;
  tfuncref45_Obj: tfuncref45_TTest;

{$pop}

{ Case tfuncref46.pp }
{$push}



{$modeswitch functionreferences}

{same as tfuncref23 but with mode delphi}

type
  tfuncref46_TLongIntFunc = reference to function(aArg: LongInt): LongInt;

  tfuncref46_TTest = class
    i: LongInt;
    function TestCaptureSelf: tfuncref46_TLongIntFunc;
  end;


function tfuncref46_TestNoCapture: tfuncref46_TLongIntFunc;

  function Foobar(aArg: LongInt): LongInt;
  begin
    Result := 42 * aArg;
  end;

begin
  Result := Foobar;
end;

function tfuncref46_TestCaptureLocal: tfuncref46_TLongIntFunc;
var
  i: LongInt;

  function Foobar(aArg: LongInt): LongInt;
  begin
    Result := i * aArg;
  end;

begin
  i := 0;
  Result := Foobar;
  i := 21;
end;

function tfuncref46_TTest.TestCaptureSelf: tfuncref46_TLongIntFunc;

  function Foobar(aArg: LongInt): LongInt;
  begin
    Result := i * aArg;
  end;

begin
  i := 0;
  Result := Foobar;
  i := 84;
end;

var
  tfuncref46_t: tfuncref46_TTest;
  tfuncref46_f: tfuncref46_TLongIntFunc;

{$pop}

{ Case tfuncref47.pp }
{$push}



{$modeswitch functionreferences}

{same as tfuncref25 but with mode delphi}

type
  tfuncref47_TTestFuncRef = reference to function: LongInt;
  tfuncref47_TTestFunc = function: LongInt;
  tfuncref47_TTestMethod = function: LongInt of object;

type
  TTest = class
    tfuncref47_f: LongInt;
    function Test: LongInt;
  end;

function TTest.Test: LongInt;
begin
  Result := tfuncref47_f;
end;

function tfuncref47_Test1: LongInt;
begin
  Result := 1;
end;

function tfuncref47_Test2: LongInt;
begin
  Result := 2;
end;

function tfuncref47_GetFunc: tfuncref47_TTestFuncRef;
var
  func: tfuncref47_TTestFunc;
begin
  func := @tfuncref47_Test1;
  Result := func;
  func := @tfuncref47_Test2;
end;

function tfuncref47_GetMethod(tfuncref47_t1, tfuncref47_t2: TTest): tfuncref47_TTestFuncRef;
var
  method: tfuncref47_TTestMethod;
begin
  method := tfuncref47_t1.Test;
  Result := method;
  method := tfuncref47_t2.Test;
end;

var
  tfuncref47_f: tfuncref47_TTestFuncRef;
  tfuncref47_t1, tfuncref47_t2: TTest;

{$pop}

{ Case tfuncref9.pp }
{$push}



{$modeswitch functionreferences}

{ test assigning global procedures, methods, and object methods to function references }

type
  tfuncref9_TProc = reference to procedure;

procedure tfuncref9_CallProc(AProc: tfuncref9_TProc);
begin
  AProc();
end;

type
  tfuncref9_TTest = class
    class procedure ClassMethod;
    procedure InstanceMethod;
  end;

var
  tfuncref9_Acc: Integer;

procedure tfuncref9_GlobalProc;
begin
  Inc(tfuncref9_Acc);
end;

class procedure tfuncref9_TTest.ClassMethod;
begin
  Inc(tfuncref9_Acc, 10);
end;

procedure tfuncref9_TTest.InstanceMethod;
begin
  Inc(tfuncref9_Acc, 100);
end;

var
  tfuncref9_Proc: tfuncref9_TProc;
  tfuncref9_Obj: tfuncref9_TTest;

{$pop}

begin

{ Case tfuncref24.pp }
{$push}

{$modeswitch functionreferences}
begin
  tfuncref24_f := tfuncref24_TestNoCapture();
  if tfuncref24_f(2) <> 84 then
    Halt(1);

  tfuncref24_f := tfuncref24_TestCaptureLocal();
  if tfuncref24_f(2) <> 42 then
    Halt(2);

  tfuncref24_t := tfuncref24_TTest.Create;
  try
    tfuncref24_f := tfuncref24_t.TestCaptureSelf;
    if tfuncref24_f(2) <> 168 then
      Halt(3);
  finally
    tfuncref24_t.Free;
  end;

  Writeln('ok');
end;
{$pop}

{ Case tfuncref45.pp }
{$push}

{$modeswitch functionreferences}
begin
  tfuncref45_Proc := tfuncref45_GlobalProc;
  tfuncref45_Proc();
  tfuncref45_CallProc(tfuncref45_GlobalProc);

  tfuncref45_Proc := tfuncref45_TTest.ClassMethod;
  tfuncref45_Proc();
  tfuncref45_CallProc(tfuncref45_TTest.ClassMethod);

  tfuncref45_Obj := tfuncref45_TTest.Create;
  tfuncref45_Proc := tfuncref45_Obj.InstanceMethod;
  tfuncref45_Proc();
  tfuncref45_CallProc(tfuncref45_Obj.InstanceMethod);
  tfuncref45_Obj.Free;

  if tfuncref45_Acc <> 222 then
    CheckCaseExitCode(tfuncref45_Acc);
end;
{$pop}

{ Case tfuncref46.pp }
{$push}

{$modeswitch functionreferences}
begin
  tfuncref46_f := tfuncref46_TestNoCapture();
  if tfuncref46_f(2) <> 84 then
    Halt(1);

  tfuncref46_f := tfuncref46_TestCaptureLocal();
  if tfuncref46_f(2) <> 42 then
    Halt(2);

  tfuncref46_t := tfuncref46_TTest.Create;
  try
    tfuncref46_f := tfuncref46_t.TestCaptureSelf;
    if tfuncref46_f(2) <> 168 then
      Halt(3);
  finally
    tfuncref46_t.Free;
  end;

  Writeln('ok');
end;
{$pop}

{ Case tfuncref47.pp }
{$push}

{$modeswitch functionreferences}
begin
  tfuncref47_f := tfuncref47_GetFunc;
  if tfuncref47_f() <> 1 then
    Halt(1);
  tfuncref47_t1 := TTest.Create;
  tfuncref47_t1.tfuncref47_f := 2;
  tfuncref47_t2 := TTest.Create;
  tfuncref47_t2.tfuncref47_f := 3;
  tfuncref47_f := tfuncref47_GetMethod(tfuncref47_t1, tfuncref47_t2);
  if tfuncref47_f() <> 2 then
    Halt(2);
  tfuncref47_t1.Free;
  tfuncref47_t2.Free;
end;
{$pop}

{ Case tfuncref9.pp }
{$push}

{$modeswitch functionreferences}
begin
  tfuncref9_Proc := tfuncref9_GlobalProc;
  tfuncref9_Proc();
  tfuncref9_CallProc(tfuncref9_GlobalProc);

  tfuncref9_Proc := tfuncref9_TTest.ClassMethod;
  tfuncref9_Proc();
  tfuncref9_CallProc(tfuncref9_TTest.ClassMethod);

  tfuncref9_Obj := tfuncref9_TTest.Create;
  tfuncref9_Proc := tfuncref9_Obj.InstanceMethod;
  tfuncref9_Proc();
  tfuncref9_CallProc(tfuncref9_Obj.InstanceMethod);
  tfuncref9_Obj.Free;

  if tfuncref9_Acc <> 222 then
    CheckCaseExitCode(tfuncref9_Acc);
end;
{$pop}

end.
