{ Consolidated generics regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb_generic_routines_objfpc.pp }
{$push}
{ Generic recursion, overload declaration order and nested forward procedures. }


{ tb0666b.pp }


generic function tb_generic_routines_objfpc_Test<T>: T;

  procedure Foo;
  begin
    specialize tb_generic_routines_objfpc_Test<T>;
    specialize tb_generic_routines_objfpc_Test<LongInt>;
    specialize tb_generic_routines_objfpc_Test<String>;
  end;

begin
  Foo;
end;

{ tb0668a.pp }


procedure tb_generic_routines_objfpc_FreeAndNil(var Obj);
begin
end;

generic procedure tb_generic_routines_objfpc_FreeAndNil<T: class>(var Obj: T);
begin
end;

var
  tb_generic_routines_objfpc_lNonGenericFirst: TObject;

{ tb0668b.pp }


generic procedure tb_generic_routines_objfpc_FreeAndNilGenericFirst<T: class>(var Obj: T);
begin
end;

procedure tb_generic_routines_objfpc_FreeAndNilGenericFirst(var Obj);
begin
end;

var
  tb_generic_routines_objfpc_lGenericFirst: TObject;

{ tb0673.pp }


type
  tb_generic_routines_objfpc_TTest = class
    generic procedure tb_generic_routines_objfpc_Test<T>;
  end;

generic procedure tb_generic_routines_objfpc_TTest.tb_generic_routines_objfpc_Test<T>;

  procedure SubTest1; forward;

  procedure SubTest2;
  begin
    SubTest1;
  end;

  procedure SubTest1;
  begin

  end;

begin
  SubTest2;
end;

var
  tb_generic_routines_objfpc_lMethodTest: tb_generic_routines_objfpc_TTest;


{$pop}

{ Case tw20836.pp }
{$push}


{ adjusted test by removing some "Lazarusisms" }


{$H+}

type
  generic tw20836_TGObjectChangeCommand<_T>=object
                                        private
                                        DoData,UnDoData:_T;
                                        method:tmethod;
                                        public
                                        procedure UnDo;virtual;
                                    end;
  tw20836_TCommand=specialize tw20836_TGObjectChangeCommand<Integer>;
procedure tw20836_TGObjectChangeCommand.UnDo;
type
    TCangeMethod=procedure(const data:_T)of object;
begin
     TCangeMethod(method)(UnDoData);
end;

{$pop}

{ Case tw29546.pp }
{$push}






type
  tw29546_TUtils = class sealed(TObject)
  public
    generic class function Iif<T>(ACondition: Boolean;
      const ATrueValue, AFalseValue: T): T; static;
  end;

  generic class function tw29546_TUtils.Iif<T>(ACondition: Boolean;
    const ATrueValue, AFalseValue: T): T;
  begin
    if ACondition then
      Result := ATrueValue
    else
      Result := AFalseValue;
  end;

var
  tw29546_S: string;

{$pop}

{ Case tgenfwd9.pp }
{$push}






type
  tgenfwd9_TFoo = class
    procedure Bar;
  end;

  tgenfwd9_TSomeClass = class
  public type
    generic TTest<T> = class;

    TSomeNestedClass = class
      f: specialize TTest<tgenfwd9_TFoo>;
    end;

    generic TTest<T> = class
      f: T;
    end;

  var
    tgenfwd9_s: TSomeNestedClass;
  end;

procedure tgenfwd9_TFoo.Bar;
begin
end;

var
  tgenfwd9_s: tgenfwd9_TSomeClass;

{$pop}

begin

{ Case tb_generic_routines_objfpc.pp }
{$push}




begin
  { tb0666b.pp }
  specialize tb_generic_routines_objfpc_Test<LongInt>;

  { tb0668a.pp }
  tb_generic_routines_objfpc_FreeAndNil(tb_generic_routines_objfpc_lNonGenericFirst);
  specialize tb_generic_routines_objfpc_FreeAndNil<TObject>(tb_generic_routines_objfpc_lNonGenericFirst);

  { tb0668b.pp }
  tb_generic_routines_objfpc_FreeAndNilGenericFirst(tb_generic_routines_objfpc_lGenericFirst);
  specialize tb_generic_routines_objfpc_FreeAndNilGenericFirst<TObject>(tb_generic_routines_objfpc_lGenericFirst);

  { tb0673.pp }
  tb_generic_routines_objfpc_lMethodTest.specialize tb_generic_routines_objfpc_Test<LongInt>;
end;
{$pop}

{ Case tw20836.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw29546.pp }
{$push}

begin
  tw29546_S := tw29546_TUtils.specialize Iif<string>(False, 'YES', 'NO');
  tw29546_S := tw29546_TUtils.specialize Iif<string>(True, 'YES', 'NO');
end;
{$pop}

{ Case tgenfwd9.pp }
{$push}

begin
  tgenfwd9_s.tgenfwd9_s.f.f.Bar;
end;
{$pop}

end.
