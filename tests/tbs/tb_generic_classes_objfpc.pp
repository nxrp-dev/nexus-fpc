{ Generic method overloads, class tests, nested aliases and pointer comparisons. }

{ tw15683.pp }
{$mode objfpc}

type
  generic GSomething<TSomeType> = class
    procedure Method(i :Integer);
    procedure Method(s :TSomeType);
  end;

procedure GSomething.Method(i: Integer);
begin
end;

procedure GSomething.Method(s: TSomeType);
begin
end;

{ tw16065.pp }
{$mode objfpc}

type
  generic TGen<_T> = class
  public
    function Check(ASource: TObject): Boolean;
  end;

  TSpec = specialize TGen<Integer>;

function TGen.Check(ASource: TObject): Boolean;
begin
  Result := (ASource is TGen)   // this line breaks the compiler...
  and (ASource is ClassType);   // ...it should be equivalent to this line
end;

var
  f:  TSpec;
  o: TObject;

{ tw17184.pp }
{$MODE OBJFPC} { -*- text -*- }

type
   generic Test1<T> = class end;
   generic Test2<T> = class
    type
      Test3 = specialize Test1<T>;
   end;
   Test4 = specialize Test2<Integer>;

{ tw19548.pp }
{$MODE OBJFPC} { -*- text -*- }

type
   generic TTest <PTest> = class
     FPointer: PTest;
     procedure Foo();
   end;

procedure TTest.Foo();
var
   Result: Boolean;
begin
   Result := FPointer = nil;
end;

type
  TPointerTest = specialize TTest <Pointer>;

{ tw17193.pp }
{$mode objfpc}{$H+}

type
  generic G1<T> = class
  public
    value : T;
  end;

  generic G2<T> = class
  public type
    S1 = specialize G1<T>;
    S2 = specialize G1<T>;
  public
    procedure P;
  end;

  S = specialize G2<Integer>;

procedure G2.P;
begin
end;

var
  x1 : S.S1;
  x2 : S.S2;

begin
  { tw16065.pp }
  f := TSpec.Create;
    o := TObject.Create;
    if not(f.Check(f)) or f.Check(o) then
      halt(1);
    writeln('ok');
  ;

  { tw17193.pp }
  x1 := S.S1.Create;
    x2 := S.S2.Create;
    x1.value := 111;
    x2.value := x1.value;
    if x2.value <> 111 then
      Halt(1);
  ;
end.
