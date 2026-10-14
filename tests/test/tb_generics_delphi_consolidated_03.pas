{ Consolidated generics regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tgeneric32.pas }
{$push}


{$APPTYPE CONSOLE}
type
  tgeneric32_TFoo<T> = class
    constructor Create;
  end;

constructor tgeneric32_TFoo<T>.Create;
begin
  inherited Create;
end;

var
  tgeneric32_FooInt: tgeneric32_TFoo<Integer>;

{$pop}

{ Case tgeneric51.pas }
{$push}
{ this tests that simple inline specializations work }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tgeneric51_TTest<tgeneric51_T> = class
    function Test(a: tgeneric51_T): tgeneric51_T;
    class function ClassTest(a: tgeneric51_T): tgeneric51_T;
  end;

function tgeneric51_TTest<tgeneric51_T>.Test(a: tgeneric51_T): tgeneric51_T;
begin
  Result := a;
end;

class function tgeneric51_TTest<tgeneric51_T>.ClassTest(a: tgeneric51_T): tgeneric51_T;
begin
  Result := a;
end;

var
  tgeneric51_t: tgeneric51_TTest<Integer>;
  tgeneric51_res: Integer;

{$pop}

{ Case tgeneric52.pas }
{$push}
{ this tests that forced typecasts to inline specialized types work }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tgeneric52_TTest = class
    function Test: Integer;
  end;

  tgeneric52_TTestGen<tgeneric52_T> = class(tgeneric52_TTest)
    function Test: Integer;
  end;

function tgeneric52_TTest.Test: Integer;
begin
  Result := 1;
end;

function tgeneric52_TTestGen<tgeneric52_T>.Test: Integer;
begin
  Result := 2;
end;

var
  tgeneric52_t: tgeneric52_TTest;
  tgeneric52_res: Integer;

{$pop}

{ Case tgeneric53.pas }
{$push}
{ this tests that checked typecasts to inline specialized types work }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tgeneric53_TTest = class
    function Test: Integer;
  end;

  tgeneric53_TTestGen<tgeneric53_T> = class(tgeneric53_TTest)
    function Test: Integer;
  end;

function tgeneric53_TTest.Test: Integer;
begin
  Result := 1;
end;

function tgeneric53_TTestGen<tgeneric53_T>.Test: Integer;
begin
  Result := 2;
end;

var
  tgeneric53_t: tgeneric53_TTest;
  tgeneric53_res: Integer;

{$pop}

{ Case tgeneric54.pas }
{$push}
{ this tests that type checks for inline specialized types work }


{$ifdef fpc}
  
{$endif}
{$apptype console}

type
  tgeneric54_TTest = class
    function Test: Integer;
  end;

  tgeneric54_TTestGen<tgeneric54_T> = class(tgeneric54_TTest)
    function Test: Integer;
  end;

function tgeneric54_TTest.Test: Integer;
begin
  Result := 1;
end;

function tgeneric54_TTestGen<tgeneric54_T>.Test: Integer;
begin
  Result := 2;
end;

var
  tgeneric54_t: tgeneric54_TTest;

{$pop}

begin

{ Case tgeneric32.pas }
{$push}

{$APPTYPE CONSOLE}
begin
  // check inline specialization
  tgeneric32_FooInt := tgeneric32_TFoo<Integer>.Create;
  tgeneric32_FooInt.Free;
end;
{$pop}

{ Case tgeneric51.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tgeneric51_t := tgeneric51_TTest<Integer>.Create;
  tgeneric51_res := tgeneric51_t.Test(42);
  Writeln('t.Test: ', tgeneric51_res);
  if tgeneric51_res <> 42 then
    Halt(1);
  tgeneric51_res := tgeneric51_TTest<Integer>.ClassTest(42);
  Writeln('t.ClassTest: ', tgeneric51_res);
  if tgeneric51_res <> 42 then
    Halt(2);
  Writeln('ok');
end;
{$pop}

{ Case tgeneric52.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tgeneric52_t := tgeneric52_TTestGen<Integer>.Create;
  tgeneric52_res := tgeneric52_TTestGen<Integer>(tgeneric52_t).Test;
  Writeln('t.Test: ', tgeneric52_res);
  if tgeneric52_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tgeneric53.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tgeneric53_t := tgeneric53_TTestGen<Integer>.Create;
  tgeneric53_res := (tgeneric53_t as tgeneric53_TTestGen<Integer>).Test;
  Writeln('t.Test: ', tgeneric53_res);
  if tgeneric53_res <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tgeneric54.pas }
{$push}
{$ifdef fpc}

{$endif}
{$apptype console}
begin
  tgeneric54_t := tgeneric54_TTestGen<Integer>.Create;
  if tgeneric54_t is tgeneric54_TTestGen<Integer> then
    Writeln('t is a TTestGen<Integer>')
  else begin
    Writeln('t is not a TTestGen<Integer>');
    Halt(1);
  end;
  Writeln('ok');
end;
{$pop}

end.
