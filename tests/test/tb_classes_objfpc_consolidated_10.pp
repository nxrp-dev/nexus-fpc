{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tfuncref23.pp }
{$push}



{$modeswitch functionreferences}


type
  tfuncref23_TLongIntFunc = reference to function(aArg: LongInt): LongInt;

  tfuncref23_TTest = class
    i: LongInt;
    function TestCaptureSelf: tfuncref23_TLongIntFunc;
  end;


function tfuncref23_TestNoCapture: tfuncref23_TLongIntFunc;

  function Foobar(aArg: LongInt): LongInt;
  begin
    Result := 42 * aArg;
  end;

begin
  Result := @Foobar;
end;

function tfuncref23_TestCaptureLocal: tfuncref23_TLongIntFunc;
var
  i: LongInt;

  function Foobar(aArg: LongInt): LongInt;
  begin
    Result := i * aArg;
  end;

begin
  i := 0;
  Result := @Foobar;
  i := 21;
end;

function tfuncref23_TTest.TestCaptureSelf: tfuncref23_TLongIntFunc;

  function Foobar(aArg: LongInt): LongInt;
  begin
    Result := i * aArg;
  end;

begin
  i := 0;
  Result := @Foobar;
  i := 84;
end;

var
  tfuncref23_t: tfuncref23_TTest;
  tfuncref23_f: tfuncref23_TLongIntFunc;

{$pop}

{ Case tfuncref25.pp }
{$push}



{$modeswitch functionreferences}

type
  tfuncref25_TTestFuncRef = reference to function: LongInt;
  tfuncref25_TTestFunc = function: LongInt;
  tfuncref25_TTestMethod = function: LongInt of object;

type
  TTest = class
    tfuncref25_f: LongInt;
    function Test: LongInt;
  end;

function TTest.Test: LongInt;
begin
  Result := tfuncref25_f;
end;

function tfuncref25_Test1: LongInt;
begin
  Result := 1;
end;

function tfuncref25_Test2: LongInt;
begin
  Result := 2;
end;

function tfuncref25_GetFunc: tfuncref25_TTestFuncRef;
var
  func: tfuncref25_TTestFunc;
begin
  func := @tfuncref25_Test1;
  Result := func;
  func := @tfuncref25_Test2;
end;

function tfuncref25_GetMethod(tfuncref25_t1, tfuncref25_t2: TTest): tfuncref25_TTestFuncRef;
var
  method: tfuncref25_TTestMethod;
begin
  method := @tfuncref25_t1.Test;
  Result := method;
  method := @tfuncref25_t2.Test;
end;

var
  tfuncref25_f: tfuncref25_TTestFuncRef;
  tfuncref25_t1, tfuncref25_t2: TTest;

{$pop}

{ Case tfuncref51.pp }
{$push}



{$modeswitch functionreferences}

type
  tfuncref51_TFunc = reference to function(aArg: LongInt): LongInt;

function tfuncref51_Test(aArg: tfuncref51_TFunc): LongInt;
begin
  Result := aArg(42);
end;

type
  tfuncref51_TTest = class
    function Method(aArg: String): LongInt; overload;
    function Method(aArg: LongInt): LongInt; overload;
    procedure DoTest;
  end;

function tfuncref51_TTest.Method(aArg: String): LongInt;
begin
  Result := 1;
end;

function tfuncref51_TTest.Method(aArg: LongInt): LongInt;
begin
  Result := 2;
end;

procedure tfuncref51_TTest.DoTest;
begin
  tfuncref51_Test(@Method);
end;

function tfuncref51_Func(aArg: String): LongInt; overload;
begin
  Result := 1;
end;

function tfuncref51_Func(aArg: LongInt): LongInt; overload;
begin
  Result := 2;
end;

var
  tfuncref51_t: tfuncref51_TTest;

{$pop}

begin

{ Case tfuncref23.pp }
{$push}

{$modeswitch functionreferences}
begin
  tfuncref23_f := tfuncref23_TestNoCapture();
  if tfuncref23_f(2) <> 84 then
    Halt(1);

  tfuncref23_f := tfuncref23_TestCaptureLocal();
  if tfuncref23_f(2) <> 42 then
    Halt(2);

  tfuncref23_t := tfuncref23_TTest.Create;
  try
    tfuncref23_f := tfuncref23_t.TestCaptureSelf;
    if tfuncref23_f(2) <> 168 then
      Halt(3);
  finally
    tfuncref23_t.Free;
  end;

  Writeln('ok');
end;
{$pop}

{ Case tfuncref25.pp }
{$push}

{$modeswitch functionreferences}
begin
  tfuncref25_f := tfuncref25_GetFunc;
  if tfuncref25_f() <> 1 then
    Halt(1);
  tfuncref25_t1 := TTest.Create;
  tfuncref25_t1.tfuncref25_f := 2;
  tfuncref25_t2 := TTest.Create;
  tfuncref25_t2.tfuncref25_f := 3;
  tfuncref25_f := tfuncref25_GetMethod(tfuncref25_t1, tfuncref25_t2);
  if tfuncref25_f() <> 2 then
    Halt(2);
  tfuncref25_t1.Free;
  tfuncref25_t2.Free;
end;
{$pop}

{ Case tfuncref51.pp }
{$push}

{$modeswitch functionreferences}
begin
  tfuncref51_t := tfuncref51_TTest.Create;
  tfuncref51_t.DoTest;
  tfuncref51_t.Free;
  if tfuncref51_Test(@tfuncref51_Func) <> 2 then
    Halt(2);
end;
{$pop}

end.
