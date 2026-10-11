{ Consolidated generics regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tgenconst6.pp }
{$push}


{
  test delphi mode
}


type
	tgenconst6_TList<T; const tgenconst6_U: integer> = class
		list: array[0..tgenconst6_U-1] of T;
		function capacity: integer;
	end;

function tgenconst6_TList<T; tgenconst6_U>.capacity: integer;
begin
	result := tgenconst6_U;
end;

var
	tgenconst6_nums:tgenconst6_TList<integer,16>;
	tgenconst6_strs:tgenconst6_TList<string,16>;

{$pop}

{ Case tgeneric117.pp }
{$push}






type
  tgeneric117_TTest<T> = class
  public type
    TT = ^tgeneric117_TTest<T>;
  end;

  tgeneric117_TTest2<T> = class
  public type
    TT2 = tgeneric117_TTest2<T>;
    TT = tgeneric117_TTest<TT2>;
  end;


{$pop}

{ Case tgeneric126.pp }
{$push}






type
  tgeneric126_TTest<S, T> = record
    class operator Implicit(const aArg: tgeneric126_TTest<S, T>): T;
    class operator Implicit(const aArg: tgeneric126_TTest<S, T>): TArray<T>;
    class operator Implicit(const aArg: tgeneric126_TTest<S, T>): S;
  end;

class operator tgeneric126_TTest<S, T>.Implicit(const aArg: tgeneric126_TTest<S, T>): T;
begin

end;

class operator tgeneric126_TTest<S, T>.Implicit(const aArg: tgeneric126_TTest<S, T>): TArray<T>;
begin

end;

class operator tgeneric126_TTest<S, T>.Implicit(const aArg: tgeneric126_TTest<S, T>): S;
begin

end;


{$pop}

{ Case tgeneric128.pp }
{$push}






type
  tgeneric128_Foo<T> = record
  public
    class operator Equal(const left: tgeneric128_Foo<T>; const right: T): Boolean;
  end;

  tgeneric128_Bar<T> = record
  public
    class operator Implicit(const value: tgeneric128_Bar<T>): tgeneric128_Foo<T>;
  end;

class operator tgeneric128_Foo<T>.Equal(const left: tgeneric128_Foo<T>; const right: T): Boolean;
begin
end;

class operator tgeneric128_Bar<T>.Implicit(const value: tgeneric128_Bar<T>): tgeneric128_Foo<T>;
begin
end;


{$pop}

{ Case tgeneric129.pp }
{$push}






type
  tgeneric129_Vector<T> = record
  public
    class operator Add(const left: TArray<T>; const right: tgeneric129_Vector<T>): tgeneric129_Vector<T>; inline;
  end;

class operator tgeneric129_Vector<T>.Add(const left: TArray<T>; const right: tgeneric129_Vector<T>): tgeneric129_Vector<T>;
begin
end;


{$pop}

{ Case tgeneric28.pp }
{$push}




// check delphi generic syntax

type
  tgeneric28_TGenericClass<T> = class
    F: T;
  end;

  tgeneric28_TGenericRecord<T> = record
    F: T;
  end;

  tgeneric28_TGenericArray<T> = array of T;

var
  tgeneric28_ClassSpecialize: tgeneric28_TGenericClass<Integer>;
  tgeneric28_RecordSpecialize: tgeneric28_TGenericRecord<Integer>;
  tgeneric28_ArraySpecialize: tgeneric28_TGenericArray<Integer>;

{$pop}

{ Case tgeneric29.pp }
{$push}





type
  tgeneric29_IGenericInterface<T> = interface
    function DoSomething(Arg: T): T;
  end;

  tgeneric29_TGenericClass<T> = class(TInterfacedObject, tgeneric29_IGenericInterface<T>)
    F: T;
    type
      Intf = tgeneric29_IGenericInterface<Integer>;
    function DoSomething(Arg: T): T;
    function Test(Arg: Intf): Intf;
  end;

  tgeneric29_TGenericRecord<T> = record
    F: T;
  end;

  tgeneric29_TGenericArray<T> = array of T;

function tgeneric29_TGenericClass<T>.DoSomething(Arg: T): T;
begin
  Result := Arg;
end;

function tgeneric29_TGenericClass<T>.Test(Arg: Intf): Intf;
begin
  Result := Arg;
end;

var
  tgeneric29_ClassSpecialize: tgeneric29_TGenericClass<Integer>;
  tgeneric29_RecordSpecialize: tgeneric29_TGenericRecord<Integer>;
  tgeneric29_ArraySpecialize: tgeneric29_TGenericArray<Integer>;

{$pop}

{ Case tgeneric36.pp }
{$push}


{ in mode Delphi generic types might be overloaded - here: class only }


{$ifdef fpc}
  
{$endif}

type
  tgeneric36_TTest = class

  end;

  tgeneric36_TTest<T> = class

  end;

  tgeneric36_TTest<T, S> = class

  end;


{$pop}

{ Case tgeneric37.pp }
{$push}


{ in mode Delphi generic types might be overloaded - here: record only }


{$ifdef fpc}
  
{$endif}

type
  tgeneric37_TTest = record

  end;

  tgeneric37_TTest<T> = record

  end;

  tgeneric37_TTest<T, S> = record

  end;


{$pop}

{ Case tgeneric42.pp }
{$push}


{ in mode Delphi generic types might be overloaded - here: class only
  Note: This tests a different code path than in the compiler than tgeneric36! }


{$ifdef fpc}
  
{$endif}

type
  tgeneric42_TTest<T> = class

  end;

  tgeneric42_TTest = class

  end;

  tgeneric42_TTest<T, S> = class

  end;


{$pop}

{ Case tgeneric43.pp }
{$push}


{ in mode Delphi generic types might be overloaded - here: record only
  Note: This tests a different code path than in the compiler than tgeneric37! }


{$ifdef fpc}
  
{$endif}

type
  tgeneric43_TTest<T> = record

  end;

  tgeneric43_TTest = record

  end;

  tgeneric43_TTest<T, S> = record

  end;


{$pop}

{ Case tgeneric49.pp }
{$push}


{ This tests whether the correct deprecated messages are printed. As I don't
  know of a way to check these inside a test this needs to be done by hand }


{$ifdef fpc}
  
{$endif}

type
  tgeneric49_TTest<tgeneric49_T> = class

  end deprecated 'Message A';

  tgeneric49_TTest = class

  end deprecated 'Message B';

  // this should print 'Message A'
  tgeneric49_TTestInteger = tgeneric49_TTest<Integer>;

  tgeneric49_FooInt = Integer deprecated;

  // this should print that TTest<T> and FooInt are deprecated
  tgeneric49_TTestFooInt = tgeneric49_TTest<tgeneric49_FooInt>;

var
  // this should print 'Message B'
  tgeneric49_t: tgeneric49_TTest;
  // this should print nothing
  tgeneric49_t2: tgeneric49_TTestInteger;
  // this should print that TTest<T> and FooInt are deprecated
  tgeneric49_t3: tgeneric49_TTest<tgeneric49_FooInt>;

{$pop}

{ Case tgeneric50.pp }
{$push}


{ this tests that hint directives defined for a generic only apply when
  specializung a generic and that specializations may introduce their own
  directives }


{$ifdef fpc}
  
{$endif}

type
  tgeneric50_TTest<tgeneric50_T> = class

  end deprecated 'Message A' platform;

  // these will both print that TTest<T> is deprecated and platform
  tgeneric50_TTestInteger = tgeneric50_TTest<Integer> deprecated 'Message B' experimental;
  tgeneric50_TTestString = tgeneric50_TTest<String>;

var
  // this will print that TTestInteger is deprecated and experimental
  tgeneric50_t: tgeneric50_TTestInteger;
  // this will print nothing
  tgeneric50_t2: tgeneric50_TTestString;

{$pop}

{ Case tgeneric60.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: record in class }


{$ifdef fpc}
  
{$endif}

type
  tgeneric60_TTest<tgeneric60_T> = class
  type
    TTestSub = record
      class function Test(a: tgeneric60_T): tgeneric60_T; static;
    end;
  end;

class function tgeneric60_TTest<tgeneric60_T>.TTestSub.Test(a: tgeneric60_T): tgeneric60_T;
begin
  Result := a;
end;

var
  tgeneric60_t: tgeneric60_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric61.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: class in class }


{$ifdef fpc}
  
{$endif}

type
  tgeneric61_TTest<tgeneric61_T> = class
  type
    TTestSub = class
      class function Test(a: tgeneric61_T): tgeneric61_T;
    end;
  end;

class function tgeneric61_TTest<tgeneric61_T>.TTestSub.Test(a: tgeneric61_T): tgeneric61_T;
begin
  Result := a;
end;

var
  tgeneric61_t: tgeneric61_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric62.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: object in class }


{$ifdef fpc}
  
{$endif}

type
  tgeneric62_TTest<tgeneric62_T> = class
  type
    TTestSub = object
      function Test(a: tgeneric62_T): tgeneric62_T;
    end;
  end;

function tgeneric62_TTest<tgeneric62_T>.TTestSub.Test(a: tgeneric62_T): tgeneric62_T;
begin
  Result := a;
end;

var
  tgeneric62_t: tgeneric62_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric63.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: record in record }


{$ifdef fpc}
  
{$endif}

type
  tgeneric63_TTest<tgeneric63_T> = record
  type
    TTestSub = record
      class function Test(a: tgeneric63_T): tgeneric63_T; static;
    end;
  end;

class function tgeneric63_TTest<tgeneric63_T>.TTestSub.Test(a: tgeneric63_T): tgeneric63_T;
begin
  Result := a;
end;

var
  tgeneric63_t: tgeneric63_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric64.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: class in record }


{$ifdef fpc}
  
{$endif}

type
  tgeneric64_TTest<tgeneric64_T> = record
  type
    TTestSub = class
      class function Test(a: tgeneric64_T): tgeneric64_T;
    end;
  end;

class function tgeneric64_TTest<tgeneric64_T>.TTestSub.Test(a: tgeneric64_T): tgeneric64_T;
begin
  Result := a;
end;

var
  tgeneric64_t: tgeneric64_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric65.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: object in record }


{$ifdef fpc}
  
{$endif}

type
  tgeneric65_TTest<tgeneric65_T> = record
  type
    TTestSub = object
      function Test(a: tgeneric65_T): tgeneric65_T;
    end;
  end;

function tgeneric65_TTest<tgeneric65_T>.TTestSub.Test(a: tgeneric65_T): tgeneric65_T;
begin
  Result := a;
end;

var
  tgeneric65_t: tgeneric65_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric66.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: record in object }


{$ifdef fpc}
  
{$endif}

type
  tgeneric66_TTest<tgeneric66_T> = object
  type
    TTestSub = record
      class function Test(a: tgeneric66_T): tgeneric66_T; static;
    end;
  end;

class function tgeneric66_TTest<tgeneric66_T>.TTestSub.Test(a: tgeneric66_T): tgeneric66_T;
begin
  Result := a;
end;

var
  tgeneric66_t: tgeneric66_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric67.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: class in object }


{$ifdef fpc}
  
{$endif}

type
  tgeneric67_TTest<tgeneric67_T> = object
  type
    TTestSub = class
      class function Test(a: tgeneric67_T): tgeneric67_T;
    end;
  end;

class function tgeneric67_TTest<tgeneric67_T>.TTestSub.Test(a: tgeneric67_T): tgeneric67_T;
begin
  Result := a;
end;

var
  tgeneric67_t: tgeneric67_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric69.pp }
{$push}


{ This tests that one can use a specialization of another generic which was
  introduced in the currently parsed generic can be used as a parameter type
  in a procedure variable introduced in the current generic as well }




type
  tgeneric69_TSomeGeneric<T> = class

  end;

  tgeneric69_TSomeOtherGeneric<T> = class
  type
    TSomeGenericT = tgeneric69_TSomeGeneric<T>;
    TSomeProc = procedure(aParam: TSomeGenericT);
  end;


{$pop}

{ Case tgeneric70.pp }
{$push}


{ This tests that one can use a specialization of another generic which was
  introduced in the currently parsed generic can be used as a parameter type
  in a procedure variable introduced in the current generic as well }




type
  tgeneric70_TSomeGeneric<T> = class

  end;

  tgeneric70_TSomeOtherGeneric<T> = class
  type
    TSomeProc = procedure(aParam: tgeneric70_TSomeGeneric<T>);
  end;


{$pop}

{ Case tgeneric78.pp }
{$push}


{ additional test based on 21064 }




type
  tgeneric78_IGenericIntf<T> = interface
    function SomeMethod: T;
  end;

  tgeneric78_TGenericClass<T> = class(TInterfacedObject, tgeneric78_IGenericIntf<LongInt>)
  private
  protected
    function GenericIntf_SomeMethod: LongInt;
    function tgeneric78_IGenericIntf<LongInt>.SomeMethod = GenericIntf_SomeMethod;
  end;

function tgeneric78_TGenericClass<T>.GenericIntf_SomeMethod: LongInt;
begin
end;

type
  tgeneric78_TGenericClassLongInt = tgeneric78_TGenericClass<String>;

{$pop}

{ Case tgeneric80.pp }
{$push}






type
  tgeneric80_TTest<T, S> = record
  end;
  tgeneric80_TTest<T> = record
  end;
  tgeneric80_PTest = ^tgeneric80_TTest;
  tgeneric80_TTest = record
  end;


{$pop}

{ Case tgeneric81.pp }
{$push}






type
  tgeneric81_PTest = ^tgeneric81_TTest;
  tgeneric81_TTest<T, S> = record
  end;
  tgeneric81_TTest<T> = record
  end;
  tgeneric81_TTest = record
  end;


{$pop}

{ Case tgeneric82.pp }
{$push}






type
  tgeneric82_TTest = record
  end;
  tgeneric82_TTest<T, S> = record
  end;
  tgeneric82_TTest<T> = record
  end;
  tgeneric82_PTest = ^tgeneric82_TTest;


{$pop}

{ Case tgeneric89.pp }
{$push}






type
  tgeneric89_TTest<T> = record

  end;

  tgeneric89_PTestLongInt = ^tgeneric89_TTest<LongInt>;
  tgeneric89_PTestBoolean = ^tgeneric89_TTest<Boolean>;


{$pop}

{ Case tgeneric90.pp }
{$push}






type
  tgeneric90_TTest = record

  end;

  tgeneric90_TTest<T> = record

  end;

  tgeneric90_TTest<T, S> = record

  end;

  tgeneric90_PTestLongInt = ^tgeneric90_TTest<LongInt>;
  tgeneric90_PTestLongIntLongInt = ^tgeneric90_TTest<LongInt, LongInt>;
  tgeneric90_PTest = ^tgeneric90_TTest;


{$pop}

begin

{ Case tgenconst6.pp }
{$push}

begin
	tgenconst6_nums := tgenconst6_TList<integer,16>.Create;
	tgenconst6_strs := tgenconst6_TList<string,16>.Create;
end;
{$pop}

{ Case tgeneric117.pp }
{$push}

begin

end;
{$pop}

{ Case tgeneric126.pp }
{$push}

begin

end;
{$pop}

{ Case tgeneric128.pp }
{$push}

begin

end;
{$pop}

{ Case tgeneric129.pp }
{$push}

begin
end;
{$pop}

{ Case tgeneric28.pp }
{$push}

begin
end;
{$pop}

{ Case tgeneric29.pp }
{$push}

begin
end;
{$pop}

{ Case tgeneric36.pp }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

{ Case tgeneric37.pp }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

{ Case tgeneric42.pp }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

{ Case tgeneric43.pp }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

{ Case tgeneric49.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  // this should print that TTest<T> and FooInt are deprecated
  tgeneric49_t3 := tgeneric49_TTest<tgeneric49_FooInt>.Create;
end;
{$pop}

{ Case tgeneric50.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  // this will print that TTest<T> is deprecated and platform
  tgeneric50_t2 := tgeneric50_TTest<String>.Create;
  // this will print that TTestInteger is deprecated and experimental
  tgeneric50_t := tgeneric50_TTestInteger.Create;
end;
{$pop}

{ Case tgeneric60.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tgeneric60_TTest<Integer>.TTestSub.Test(42);
end;
{$pop}

{ Case tgeneric61.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tgeneric61_TTest<Integer>.TTestSub.Test(42);
end;
{$pop}

{ Case tgeneric62.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tgeneric62_t.Test(42);
end;
{$pop}

{ Case tgeneric63.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tgeneric63_TTest<Integer>.TTestSub.Test(42);
end;
{$pop}

{ Case tgeneric64.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tgeneric64_TTest<Integer>.TTestSub.Test(42);
end;
{$pop}

{ Case tgeneric65.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tgeneric65_t.Test(42);
end;
{$pop}

{ Case tgeneric66.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tgeneric66_TTest<Integer>.TTestSub.Test(42);
end;
{$pop}

{ Case tgeneric67.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tgeneric67_TTest<Integer>.TTestSub.Test(42);
end;
{$pop}

{ Case tgeneric69.pp }
{$push}

begin

end;
{$pop}

{ Case tgeneric70.pp }
{$push}

begin

end;
{$pop}

{ Case tgeneric78.pp }
{$push}

begin
end;
{$pop}

{ Case tgeneric80.pp }
{$push}

begin

end;
{$pop}

{ Case tgeneric81.pp }
{$push}

begin

end;
{$pop}

{ Case tgeneric82.pp }
{$push}

begin

end;
{$pop}

{ Case tgeneric89.pp }
{$push}

begin

end;
{$pop}

{ Case tgeneric90.pp }
{$push}

begin

end;
{$pop}

end.
