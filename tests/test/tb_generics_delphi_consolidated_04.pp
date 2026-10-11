{ Consolidated generics regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb_generics_delphi_consolidated_01.pp }
{$push}
{ Consolidated generics regressions; original case IDs and assertions are retained. }



{ Case tgenconst32.pp }
{$push}




var
  tb_generics_delphi_consolidated_01_tgenconst32_Test: LongInt = 42;

type
  tb_generics_delphi_consolidated_01_tgenconst32_Test<const tb_generics_delphi_consolidated_01_tgenconst32_N: LongInt> = class

  end;

const
  tb_generics_delphi_consolidated_01_tgenconst32_N = 42;


{$pop}

{ Case tgeneric34.pp }
{$push}




type
  tb_generics_delphi_consolidated_01_tgeneric34_TFoo<T> = record
    function DoSomething(Arg: T): T;
  end;

function tb_generics_delphi_consolidated_01_tgeneric34_TFoo<T>.DoSomething(Arg: T): T;
begin
  Result := Arg;
end;

var
  tb_generics_delphi_consolidated_01_tgeneric34_FooInt: tb_generics_delphi_consolidated_01_tgeneric34_TFoo<Integer>;

{$pop}

{ Case tgeneric35.pp }
{$push}




type
  tb_generics_delphi_consolidated_01_tgeneric35_TSomeRecord = record
    F: Integer;
  end;

  tb_generics_delphi_consolidated_01_tgeneric35_TSomeRecord<TData> = record
    data: TData;
  end;
var
  tb_generics_delphi_consolidated_01_tgeneric35_R1: tb_generics_delphi_consolidated_01_tgeneric35_TSomeRecord;
  tb_generics_delphi_consolidated_01_tgeneric35_R2: tb_generics_delphi_consolidated_01_tgeneric35_TSomeRecord<Integer>;

{$pop}

{ Case tgenfunc4.pp }
{$push}
{ test syntax of a generic class function in mode delphi }





type
  tb_generics_delphi_consolidated_01_tgenfunc4_TTest = class
    class function Add<T>(aLeft, aRight: T): T;
  end;

class function tb_generics_delphi_consolidated_01_tgenfunc4_TTest.Add<T>(aLeft, aRight: T): T;
begin
  Result := aLeft + aRight;
end;


{$pop}

{ Case tgenfunc6.pp }
{$push}
{ test syntax of a generic method in mode delphi }





type
  tb_generics_delphi_consolidated_01_tgenfunc6_TTest = class
    function Add<tb_generics_delphi_consolidated_01_tgenfunc6_T>(aLeft, aRight: tb_generics_delphi_consolidated_01_tgenfunc6_T): tb_generics_delphi_consolidated_01_tgenfunc6_T;
  end;

function tb_generics_delphi_consolidated_01_tgenfunc6_TTest.Add<tb_generics_delphi_consolidated_01_tgenfunc6_T>(aLeft, aRight: tb_generics_delphi_consolidated_01_tgenfunc6_T): tb_generics_delphi_consolidated_01_tgenfunc6_T;
begin
  Result := aLeft + aRight;
end;

var
  tb_generics_delphi_consolidated_01_tgenfunc6_t: tb_generics_delphi_consolidated_01_tgenfunc6_TTest;

{$pop}


{$pop}

{ Case tgeneric106.pp }
{$push}




type tgeneric106_G<T> = class
    var X: T;
    // EXPECTED: gets compiled
    // ACTUAL: 'Error: Generics without specialization cannot be used as a type for a variable'
    class var F: function(const X: T) : tgeneric106_G<T> of object;
    function Foo(const X: T): tgeneric106_G<T>;
end;

function tgeneric106_G<T>.Foo(const X: T): tgeneric106_G<T>;
begin
    result := tgeneric106_G<T>.Create;
    result.X := X
end;


{$pop}

{ Case tgenfwd2.pp }
{$push}




type
  tgenfwd2_TGen1<T> = class;
  tgenfwd2_TGen2<T: class> = class;
  tgenfwd2_TGen3<const N: Integer> = class;
  tgenfwd2_TGen4<T; S: class; const N: Integer> = class;

  tgenfwd2_TTest = class
    f1: tgenfwd2_TGen1<LongInt>;
    f2: tgenfwd2_TGen2<TObject>;
    f3: tgenfwd2_TGen3<42>;
    f4: tgenfwd2_TGen4<LongInt, TObject, 42>;

    { this will reuse the above specializations }
    f5: tgenfwd2_TGen1<LongInt>;
    f6: tgenfwd2_TGen2<TObject>;
    f7: tgenfwd2_TGen3<42>;
    f8: tgenfwd2_TGen4<LongInt, TObject, 42>;
  end;

  tgenfwd2_TGen1<T> = class
  end;

  tgenfwd2_TGen2<T: class> = class
  end;

  tgenfwd2_TGen3<const N: Integer> = class
  end;

  tgenfwd2_TGen4<T; S: class; const N: Integer> = class
  end;


{$pop}

begin

{ Case tb_generics_delphi_consolidated_01.pp }
{$push}

{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
begin

{ Case tgenconst32.pp }
{$push}

begin
  if tb_generics_delphi_consolidated_01_tgenconst32_Test<tb_generics_delphi_consolidated_01_tgenconst32_N then
    Writeln('Foo');
end;
{$pop}

{ Case tgeneric34.pp }
{$push}

begin
  if tb_generics_delphi_consolidated_01_tgeneric34_FooInt.DoSomething(1) <> 1 then
    halt(1);
end;
{$pop}

{ Case tgeneric35.pp }
{$push}

begin
  tb_generics_delphi_consolidated_01_tgeneric35_R1.F := 2;
  tb_generics_delphi_consolidated_01_tgeneric35_R2.data := 1;
end;
{$pop}

{ Case tgenfunc4.pp }
{$push}

begin
  if tb_generics_delphi_consolidated_01_tgenfunc4_TTest.Add<LongInt>(2, 3) <> 5 then
    Halt(1);
  if tb_generics_delphi_consolidated_01_tgenfunc4_TTest.Add<String>('Hello', 'World') <> 'HelloWorld' then
    Halt(2);
end;
{$pop}

{ Case tgenfunc6.pp }
{$push}

begin
  if tb_generics_delphi_consolidated_01_tgenfunc6_t.Add<LongInt>(2, 3) <> 5 then
    Halt(1);
  if tb_generics_delphi_consolidated_01_tgenfunc6_t.Add<String>('Hello', 'World') <> 'HelloWorld' then
    Halt(2);
end;
{$pop}

end;
{$pop}

{ Case tgeneric106.pp }
{$push}

begin
    tgeneric106_G<Integer>.F := tgeneric106_G<Integer>.Create.Foo;
    if tgeneric106_G<Integer>.F(42).X <> 42 then
      halt(1);
end;
{$pop}

{ Case tgenfwd2.pp }
{$push}

begin

end;
{$pop}

end.
