{ Generic recursion, overload declaration order and nested forward procedures. }
{ %NORUN }

{ tb0666b.pp }
{$mode objfpc}

generic function Test<T>: T;

  procedure Foo;
  begin
    specialize Test<T>;
    specialize Test<LongInt>;
    specialize Test<String>;
  end;

begin
  Foo;
end;

{ tb0668a.pp }
{$mode objfpc}

procedure FreeAndNil(var Obj);
begin
end;

generic procedure FreeAndNil<T: class>(var Obj: T);
begin
end;

var
  lNonGenericFirst: TObject;

{ tb0668b.pp }
{$mode objfpc}

generic procedure FreeAndNilGenericFirst<T: class>(var Obj: T);
begin
end;

procedure FreeAndNilGenericFirst(var Obj);
begin
end;

var
  lGenericFirst: TObject;

{ tb0673.pp }
{$mode objfpc}

type
  TTest = class
    generic procedure Test<T>;
  end;

generic procedure TTest.Test<T>;

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
  lMethodTest: TTest;

begin
  { tb0666b.pp }
  specialize Test<LongInt>;

  { tb0668a.pp }
  FreeAndNil(lNonGenericFirst);
  specialize FreeAndNil<TObject>(lNonGenericFirst);

  { tb0668b.pp }
  FreeAndNilGenericFirst(lGenericFirst);
  specialize FreeAndNilGenericFirst<TObject>(lGenericFirst);

  { tb0673.pp }
  lMethodTest.specialize Test<LongInt>;
end.
