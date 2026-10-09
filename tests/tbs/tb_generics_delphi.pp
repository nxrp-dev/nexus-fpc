{ Delphi generic arithmetic, recursive records and nested routine specialization. }
{ %NORUN }

{ tb0606.pp }
{$mode delphi}

type
  TArithmeticGeneric<T> = class
    procedure Test;
  end;

procedure TArithmeticGeneric<T>.Test;
var
  r: T;
  i: LongInt;
begin
  r := i div r;
  r := r div i;
  r := i mod r;
  r := r mod i;
  r := i shl r;
  r := r shl i;
  r := i shr r;
  r := r shr i;
  r := - r;
  r := not r;
  r := + r;
end;

{ tb0624.pp }
{$mode delphi}

type
  TTest<T> = record
  public type
    PSelf = ^TTest<T>;
  public
    Next: PSelf;
  end;

  TTest2<T> = record
    Next: ^TTest<T>;
  end;

  TTestLongInt = TTest<LongInt>;
  TTestString = TTest<String>;

  TTest2LongInt = TTest2<LongInt>;
  TTest2String = TTest2<String>;

{ tb0666a.pp }
{$mode delphi}

function Test<T>: T;

  procedure Foo;
  begin
    Test<T>;
    Test<LongInt>;
    Test<String>;
  end;

begin
  Foo;
end;

begin
  { tb0666a.pp }
  Test<LongInt>;
end.
