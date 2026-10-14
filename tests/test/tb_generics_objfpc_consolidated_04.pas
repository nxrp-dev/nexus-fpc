{ Consolidated generics regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case timpfuncspez13.pas }
{$push}


{$modeswitch implicitfunctionspecialization}
{
  Test specializing proc vars by inferring parameters from callback function
}



type
  generic timpfuncspez13_TProc<S, V> = procedure(name: S; context: V);

generic procedure timpfuncspez13_Run<U, T>(proc: specialize timpfuncspez13_TProc<U, T>; context: T);
begin
  proc('TProc', context);
end;

procedure timpfuncspez13_DoCallback(name: string; value: shortint);
begin
  writeln(name, ' called ', value);
end;


{$pop}

{ Case timpfuncspez14.pas }
{$push}


{$modeswitch implicitfunctionspecialization}
{
  Test specializing proc vars by inferring parameters from callback function
}



type
  generic timpfuncspez14_TProc<S> = procedure(name: S; value: integer);

generic procedure timpfuncspez14_Run<T, U>(proc: specialize timpfuncspez14_TProc<T>; context: U);
begin
  proc('TProc', context);
end;

procedure timpfuncspez14_DoCallback(name: string; value: integer);
begin
  writeln(name, ' called ', value);
end;


{$pop}

{ Case timpfuncspez19.pas }
{$push}


{$modeswitch implicitfunctionspecialization}
{
  Test specializing related object types

  DoThis<T> can be specialized as DoThis<Integer>
  because TSomeClass is specialized from TAnyClass<Integer>
  and therefore we can infer "Integer" as the correct parameter
}


type
  generic timpfuncspez19_TAnyClass<U> = class
  end;

type
  timpfuncspez19_TSomeClass = specialize timpfuncspez19_TAnyClass<Integer>;

generic procedure timpfuncspez19_DoThis<T>(aClass: specialize timpfuncspez19_TAnyClass<T>);
begin
end;


{$pop}

{ Case timpfuncspez20.pas }
{$push}


{$modeswitch implicitfunctionspecialization}
{
  Test specializing related object types

  DoThis<T> can be specialized as DoThis<Integer>
  because TSomeRecord is specialized from TAnyRecord<Integer>
  and therefore we can infer "Integer" as the correct parameter
}


type
  generic timpfuncspez20_TAnyRecord<U> = record
  end;

type
  timpfuncspez20_TSomeRecord = specialize timpfuncspez20_TAnyRecord<Integer>;

generic procedure timpfuncspez20_DoThis<T>(aRecord: specialize timpfuncspez20_TAnyRecord<T>);
begin
end;

var
  timpfuncspez20_rec: timpfuncspez20_TSomeRecord;

{$pop}

{ Case timpfuncspez21.pas }
{$push}


{$modeswitch implicitfunctionspecialization}
{
  Test class constraints
}



type
  timpfuncspez21_TMyClass = class
  end;
  timpfuncspez21_TMyChild = class(timpfuncspez21_TMyClass)
  end;

generic procedure timpfuncspez21_DoThis<T: timpfuncspez21_TMyClass>(obj: T);
begin
end;


{$pop}

{ Case timpfuncspez23.pas }
{$push}


{$modeswitch implicitfunctionspecialization}
{
  Test multi-dimensional array specializations
}



type
  generic timpfuncspez23_TArray<T> = array of T;

generic procedure timpfuncspez23_DoThis<T>(param: specialize timpfuncspez23_TArray<specialize timpfuncspez23_TArray<T>>);
begin
end;


{$pop}

{ Case timpfuncspez24.pas }
{$push}


{$modeswitch implicitfunctionspecialization}
{
  Test multi-dimensional array specializations
}



type
  generic timpfuncspez24_TArray<T> = array of T;

generic procedure timpfuncspez24_DoThis<T>(param: specialize timpfuncspez24_TArray<specialize timpfuncspez24_TArray<T>>);
begin
end;


{$pop}

{ Case timpfuncspez25.pas }
{$push}


{$modeswitch implicitfunctionspecialization}
{
  Test generic methods within generic method bodies
}



type
  timpfuncspez25_TMyClass = class
    generic procedure DoThis<T>(msg: T);
    generic procedure DoThat<T>(msg: T);
  end;
  timpfuncspez25_TMyChild = class(timpfuncspez25_TMyClass)
    generic procedure DoSomething<T>(msg: T);
  end;

generic procedure timpfuncspez25_TMyClass.DoThis<T>(msg:T);
begin
  DoThat(msg);
end;

generic procedure timpfuncspez25_TMyClass.DoThat<T>(msg: T);
begin
end;

generic procedure timpfuncspez25_TMyChild.DoSomething<T>(msg: T);
begin
  DoThis(msg);
end;

var
  timpfuncspez25_a: timpfuncspez25_TMyClass;
  timpfuncspez25_b: timpfuncspez25_TMyChild;

{$pop}

{ Case timpfuncspez34.pas }
{$push}


{$modeswitch implicitfunctionspecialization}
{
  Test various overloads
}



generic procedure timpfuncspez34_DoThis<A>(param1: A);
begin
end;

generic procedure timpfuncspez34_DoThis<A, B>(param1: A; param2: B);
begin
end;

generic procedure timpfuncspez34_DoThis<A, B, C>(param1: A; param2: B; param3: C);
begin
end;


{$pop}

{ Case timpfuncspez36.pas }
{$push}





{$modeswitch implicitfunctionspecialization}

type
  generic timpfuncspez36_TTestFunc<T> = procedure(aArg1: String; aArg2: T);

generic procedure timpfuncspez36_DoTest<T>(aArg: specialize timpfuncspez36_TTestFunc<T>);
begin
end;

procedure timpfuncspez36_TestFunc(aArg1: String; aArg2: LongInt);
begin
end;


{$pop}

begin

{ Case timpfuncspez13.pas }
{$push}

{$modeswitch implicitfunctionspecialization}
begin
  timpfuncspez13_Run(@timpfuncspez13_DoCallback, 100);
end;
{$pop}

{ Case timpfuncspez14.pas }
{$push}

{$modeswitch implicitfunctionspecialization}
begin
  timpfuncspez14_Run(@timpfuncspez14_DoCallback, 100);
end;
{$pop}

{ Case timpfuncspez19.pas }
{$push}

{$modeswitch implicitfunctionspecialization}
begin
  timpfuncspez19_DoThis(timpfuncspez19_TSomeClass.Create);
end;
{$pop}

{ Case timpfuncspez20.pas }
{$push}

{$modeswitch implicitfunctionspecialization}
begin
  timpfuncspez20_DoThis(timpfuncspez20_rec);
end;
{$pop}

{ Case timpfuncspez21.pas }
{$push}

{$modeswitch implicitfunctionspecialization}
begin
  timpfuncspez21_DoThis(timpfuncspez21_TMyClass.Create);
  timpfuncspez21_DoThis(timpfuncspez21_TMyChild.Create);
end;
{$pop}

{ Case timpfuncspez23.pas }
{$push}

{$modeswitch implicitfunctionspecialization}
begin
  timpfuncspez23_DoThis([[1,2,3],[2,3,4],[3,4,5]]);
end;
{$pop}

{ Case timpfuncspez24.pas }
{$push}

{$modeswitch implicitfunctionspecialization}
begin
  timpfuncspez24_DoThis([[1,2,3],[2,3,4],[3,4,5]]);
end;
{$pop}

{ Case timpfuncspez25.pas }
{$push}

{$modeswitch implicitfunctionspecialization}
begin
  timpfuncspez25_a := timpfuncspez25_TMyClass.Create;
  timpfuncspez25_a.DoThis(1);
  timpfuncspez25_b := timpfuncspez25_TMyChild.create;
  timpfuncspez25_b.DoSomething(1);
end;
{$pop}

{ Case timpfuncspez34.pas }
{$push}

{$modeswitch implicitfunctionspecialization}
begin
  timpfuncspez34_DoThis(1);
  timpfuncspez34_DoThis(1,2);
  timpfuncspez34_DoThis(1,2,3);

  timpfuncspez34_DoThis(1);
  timpfuncspez34_DoThis(1,'aaa');
  timpfuncspez34_DoThis(1,'aaa',nil);
end;
{$pop}

{ Case timpfuncspez36.pas }
{$push}

{$modeswitch implicitfunctionspecialization}
begin
  timpfuncspez36_DoTest(@timpfuncspez36_TestFunc);
end;
{$pop}

end.
