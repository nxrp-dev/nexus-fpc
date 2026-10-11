{ Consolidated generics regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tgenconst32.pp }
{$push}




var
  tgenconst32_Test: LongInt = 42;

type
  tgenconst32_Test<const tgenconst32_N: LongInt> = class

  end;

const
  tgenconst32_N = 42;


{$pop}

{ Case tgeneric34.pp }
{$push}




type
  tgeneric34_TFoo<T> = record
    function DoSomething(Arg: T): T;
  end;

function tgeneric34_TFoo<T>.DoSomething(Arg: T): T;
begin
  Result := Arg;
end;

var
  tgeneric34_FooInt: tgeneric34_TFoo<Integer>;

{$pop}

{ Case tgeneric35.pp }
{$push}




type
  tgeneric35_TSomeRecord = record
    F: Integer;
  end;

  tgeneric35_TSomeRecord<TData> = record
    data: TData;
  end;
var
  tgeneric35_R1: tgeneric35_TSomeRecord;
  tgeneric35_R2: tgeneric35_TSomeRecord<Integer>;

{$pop}

{ Case tgenfunc4.pp }
{$push}
{ test syntax of a generic class function in mode delphi }





type
  tgenfunc4_TTest = class
    class function Add<T>(aLeft, aRight: T): T;
  end;

class function tgenfunc4_TTest.Add<T>(aLeft, aRight: T): T;
begin
  Result := aLeft + aRight;
end;


{$pop}

{ Case tgenfunc6.pp }
{$push}
{ test syntax of a generic method in mode delphi }





type
  tgenfunc6_TTest = class
    function Add<tgenfunc6_T>(aLeft, aRight: tgenfunc6_T): tgenfunc6_T;
  end;

function tgenfunc6_TTest.Add<tgenfunc6_T>(aLeft, aRight: tgenfunc6_T): tgenfunc6_T;
begin
  Result := aLeft + aRight;
end;

var
  tgenfunc6_t: tgenfunc6_TTest;

{$pop}

begin

{ Case tgenconst32.pp }
{$push}

begin
  if tgenconst32_Test<tgenconst32_N then
    Writeln('Foo');
end;
{$pop}

{ Case tgeneric34.pp }
{$push}

begin
  if tgeneric34_FooInt.DoSomething(1) <> 1 then
    halt(1);
end;
{$pop}

{ Case tgeneric35.pp }
{$push}

begin
  tgeneric35_R1.F := 2;
  tgeneric35_R2.data := 1;
end;
{$pop}

{ Case tgenfunc4.pp }
{$push}

begin
  if tgenfunc4_TTest.Add<LongInt>(2, 3) <> 5 then
    Halt(1);
  if tgenfunc4_TTest.Add<String>('Hello', 'World') <> 'HelloWorld' then
    Halt(2);
end;
{$pop}

{ Case tgenfunc6.pp }
{$push}

begin
  if tgenfunc6_t.Add<LongInt>(2, 3) <> 5 then
    Halt(1);
  if tgenfunc6_t.Add<String>('Hello', 'World') <> 'HelloWorld' then
    Halt(2);
end;
{$pop}

end.
