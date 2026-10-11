{ Consolidated generics regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb_generic_classes_objfpc.pp }
{$push}
{ Generic method overloads, class tests, nested aliases and pointer comparisons. }

{ tw15683.pp }


type
  generic tb_generic_classes_objfpc_GSomething<TSomeType> = class
    procedure Method(i :Integer);
    procedure Method(tb_generic_classes_objfpc_s :TSomeType);
  end;

procedure tb_generic_classes_objfpc_GSomething.Method(i: Integer);
begin
end;

procedure tb_generic_classes_objfpc_GSomething.Method(tb_generic_classes_objfpc_s: TSomeType);
begin
end;

{ tw16065.pp }


type
  generic tb_generic_classes_objfpc_TGen<_T> = class
  public
    function Check(ASource: TObject): Boolean;
  end;

  tb_generic_classes_objfpc_TSpec = specialize tb_generic_classes_objfpc_TGen<Integer>;

function tb_generic_classes_objfpc_TGen.Check(ASource: TObject): Boolean;
begin
  Result := (ASource is tb_generic_classes_objfpc_TGen)   // this line breaks the compiler...
  and (ASource is ClassType);   // ...it should be equivalent to this line
end;

var
  tb_generic_classes_objfpc_f:  tb_generic_classes_objfpc_TSpec;
  tb_generic_classes_objfpc_o: TObject;

{ tw17184.pp }
 { -*- text -*- }

type
   generic tb_generic_classes_objfpc_Test1<T> = class end;
   generic tb_generic_classes_objfpc_Test2<T> = class
    type
      Test3 = specialize tb_generic_classes_objfpc_Test1<T>;
   end;
   tb_generic_classes_objfpc_Test4 = specialize tb_generic_classes_objfpc_Test2<Integer>;

{ tw19548.pp }
 { -*- text -*- }

type
   generic tb_generic_classes_objfpc_TTest <PTest> = class
     FPointer: PTest;
     procedure Foo();
   end;

procedure tb_generic_classes_objfpc_TTest.Foo();
var
   Result: Boolean;
begin
   Result := FPointer = nil;
end;

type
  tb_generic_classes_objfpc_TPointerTest = specialize tb_generic_classes_objfpc_TTest <Pointer>;

{ tw17193.pp }
{$H+}

type
  generic tb_generic_classes_objfpc_G1<T> = class
  public
    value : T;
  end;

  generic tb_generic_classes_objfpc_G2<T> = class
  public type
    S1 = specialize tb_generic_classes_objfpc_G1<T>;
    S2 = specialize tb_generic_classes_objfpc_G1<T>;
  public
    procedure P;
  end;

  tb_generic_classes_objfpc_S = specialize tb_generic_classes_objfpc_G2<Integer>;

procedure tb_generic_classes_objfpc_G2.P;
begin
end;

var
  tb_generic_classes_objfpc_x1 : tb_generic_classes_objfpc_S.S1;
  tb_generic_classes_objfpc_x2 : tb_generic_classes_objfpc_S.S2;


{$pop}

{ Case tgenfunc12.pp }
{$push}




type
  tgenfunc12_TTest = class
    generic function tgenfunc12_Test<tgenfunc12_T: class>: tgenfunc12_T;
  end;

generic function tgenfunc12_TTest.tgenfunc12_Test<tgenfunc12_T>: tgenfunc12_T;
begin
  Result := tgenfunc12_T.Create;
end;

generic function tgenfunc12_Test<tgenfunc12_T: IInterface>: tgenfunc12_T;
begin
  Result := TInterfacedObject.Create;
end;

var
  tgenfunc12_t: tgenfunc12_TTest;

{$pop}

{ Case tgenfunc3.pp }
{$push}
{ test syntax of a generic class function in mode objfpc }





type
  tgenfunc3_TTest = class
    generic class function Add<T>(aLeft, aRight: T): T;
  end;

generic class function tgenfunc3_TTest.Add<T>(aLeft, aRight: T): T;
begin
  Result := aLeft + aRight;
end;


{$pop}

begin

{ Case tb_generic_classes_objfpc.pp }
{$push}





{$H+}
begin
  { tw16065.pp }
  tb_generic_classes_objfpc_f := tb_generic_classes_objfpc_TSpec.Create;
    tb_generic_classes_objfpc_o := TObject.Create;
    if not(tb_generic_classes_objfpc_f.Check(tb_generic_classes_objfpc_f)) or tb_generic_classes_objfpc_f.Check(tb_generic_classes_objfpc_o) then
      halt(1);
    writeln('ok');
  ;

  { tw17193.pp }
  tb_generic_classes_objfpc_x1 := tb_generic_classes_objfpc_S.S1.Create;
    tb_generic_classes_objfpc_x2 := tb_generic_classes_objfpc_S.S2.Create;
    tb_generic_classes_objfpc_x1.value := 111;
    tb_generic_classes_objfpc_x2.value := tb_generic_classes_objfpc_x1.value;
    if tb_generic_classes_objfpc_x2.value <> 111 then
      Halt(1);
  ;
end;
{$pop}

{ Case tgenfunc12.pp }
{$push}

begin
  tgenfunc12_t := tgenfunc12_TTest.Create;
  tgenfunc12_t.specialize tgenfunc12_Test<TObject>.Free;
  specialize tgenfunc12_Test<IInterface>;
end;
{$pop}

{ Case tgenfunc3.pp }
{$push}

begin
  if tgenfunc3_TTest.specialize Add<LongInt>(2, 3) <> 5 then
    Halt(1);
  if tgenfunc3_TTest.specialize Add<String>('Hello', 'World') <> 'HelloWorld' then
    Halt(2);
end;
{$pop}

end.
