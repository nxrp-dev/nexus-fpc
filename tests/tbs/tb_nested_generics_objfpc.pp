{ Nested generic types, constructors, return types and constrained arrays. }
{ %NORUN }

{ tw32118.pp }
{$MODE OBJFPC}
type
  generic TTestClass<SomeTemplate> = class
    procedure Test;
  end;

procedure TTestClass.Test;
var
  i : SomeTemplate;
begin
  for i := 1 to 10 do WriteLn(i);
end;

{ tw37187.pp }
{$mode objfpc}

type
  generic TTest<T: class> = class
    arr: array[0..SizeOf(T)] of Byte;
  end;

  generic TTest2<T: class> = class
  public type
    TTestT = specialize TTest<T>;
  end;

{ tw19498.pp }
{$MODE OBJFPC} { -*- text -*- }

type
   generic TFoo1 <T> = class
    type
     TFoo2 = class
        constructor Create(Owner: specialize TFoo1<T>);
     end;
   end;

constructor TFoo1.TFoo2.Create(Owner: specialize TFoo1<T>);
begin
end;

type
   TIntegerFoo1 = specialize TFoo1<Integer>;

var
   Foo1: TIntegerFoo1;
   Foo2: TIntegerFoo1.TFoo2;

{ tw19500.pp }
{$MODE OBJFPC} { -*- text -*- }

type
   generic TReturnGenericOuter <T> = class
     type
      TBar = class
         function Baz(): T;
      end;
   end;

function TReturnGenericOuter.TBar.Baz(): T;
begin
   Result := nil;
end;

{ tw19511.pp }
{$MODE OBJFPC} { -*- text -*- }

type
   generic TNestedSpecializationFoo<X> = class
   end;
   generic TSelfGenericBar<Y> = class
    type
     TIntegerSpecializedFoo = specialize TNestedSpecializationFoo<Integer>;
     TSelfSpecializedFoo = specialize TNestedSpecializationFoo<TSelfGenericBar>;
    function SelfTest(): TSelfGenericBar; // returns a TBar<Y>
      TSpecializedBar = specialize TSelfGenericBar<Y>; // this rightly would not compile since TBar here refers to the specialized TBar<Y>
   end;

function TSelfGenericBar.SelfTest(): TSelfGenericBar;
begin
   Result := Self;
end;

begin

end.
