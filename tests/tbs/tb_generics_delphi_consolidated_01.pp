{ Consolidated generics regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb_generics_delphi_compile_01.pp }
{$push}

{ Consolidated feature cases; original case IDs and settings are retained below. }



{ Source group: tb_generics_delphi_compile_01.pp }
{$push}

{ Case tw21064a.pp }
{$push}


type
  tw21064a_igenericintf<T> = interface
    function tw21064a_somemethod: T;
  end;

  tw21064a_tgenericclass<T> = class(TInterfacedObject, tw21064a_igenericintf<T>)
  private
  protected
    function tw21064a_genericintf_somemethod: T;
    function tw21064a_igenericintf<T>.tw21064a_somemethod = tw21064a_genericintf_somemethod;
  end;

function tw21064a_tgenericclass<T>.tw21064a_genericintf_somemethod: T;
begin
end;

type
  tw21064a_tgenericclasslongint = tw21064a_tgenericclass<LongInt>;
{$pop}

{ Case tw21064b.pp }
{$push}


type
  tw21064b_igenericintf<T> = interface
    function tw21064b_somemethod: T;
  end;

  tw21064b_tgenericclass<T> = class(TInterfacedObject, tw21064b_igenericintf<T>)
  private
    type
      tw21064b_intftype = tw21064b_igenericintf<T>;
  protected
    function tw21064b_genericintf_somemethod: T;
    function tw21064b_intftype.tw21064b_somemethod = tw21064b_genericintf_somemethod;
  end;

function tw21064b_tgenericclass<T>.tw21064b_genericintf_somemethod: T;
begin
end;

type
  tw21064b_tgenericclasslongint = tw21064b_tgenericclass<LongInt>;
{$pop}

{ Case tw22192.pp }
{$push}


 type
   tw22192_twrapper<T> = record end;
   tw22192_twrapper = tw22192_twrapper<Byte>;
{$pop}

{ Case tw22433.pp }
{$push}


type tw22433_twrapper<T> = record end;

procedure tw22433_z(const a: array of tw22433_twrapper<Integer>);
begin
end;
{$pop}

{ Case tw24073.pp }
{$push}


type
  tw24073_ta<T: record> = record
  end;

  tw24073_tunamanagedrec = record
    tw24073_x: integer;
  end;

  tw24073_tmanagedrec = record
    tw24073_s: string;
  end;

  tw24073_tenum = (tb_generics_delphi_compile_01_e1, tb_generics_delphi_compile_01_e2, tb_generics_delphi_compile_01_e3);

  tw24073_tobj = object
  end;

var
  tw24073_a: tw24073_ta<tw24073_tunamanagedrec>;
  tw24073_b: tw24073_ta<tw24073_tmanagedrec>;
  tw24073_d: tw24073_ta<Single>;
  tw24073_e: tw24073_ta<Integer>;
  tw24073_f: tw24073_ta<tw24073_tenum>;
  tw24073_g: tw24073_ta<tw24073_tobj>;
{$pop}

{ Case tw24848.pp }
{$push}


type
  tw24848_tfoo<T> = class
    class constructor Create;
  end;

class constructor tw24848_tfoo<T>.Create;
begin
end;
{$pop}

{ Case tw24872.pp }
{$push}


procedure tw24872_test;
begin
end;

type
  tw24872_trec<T> = record {for generic class is ok, and non generic record too}
    procedure tw24872_foo;
  end;

procedure tw24872_trec<T>.tw24872_foo;
begin
  tw24872_test
end; // Error: Global Generic template references static symtable
{$pop}

{ Case tw25604.pp }
{$push}


type
  tw25604_ta<T> = class
  private
    tw25604_f1, tw25604_f2: T;
    procedure tw25604_foo;
  end;

procedure tw25604_ta<T>.tw25604_foo;
var
  tw25604_b: Integer;
begin
  tw25604_b := (tw25604_b and tw25604_f1) shr tw25604_f2; // pass
  tw25604_b := (tw25604_b and not tw25604_f1) or (tw25604_b shl tw25604_f2); // Error: Operator is not overloaded: "LongInt" shl "<undefined type>"
end;
{$pop}

{ Case tw25929.pp }
{$push}


type
  tw25929_tr<T> = record
  end;

  tw25929_ta<T> = class
    procedure tw25929_foo;
  end;

procedure tw25929_ta<T>.tw25929_foo;
var
  tw25929_r: tw25929_tr<T>;
begin
  tw25929_r := Default(tw25929_tr<T>);
  tw25929_r := Default(tw25929_tr<T>); // Error: Duplicate identifier "zero_$P$PLC03_$$_TR$1"
end;
{$pop}

{ Case tw26180.pp }
{$push}

{$Assertions on}

type
  tw26180_ta<T> = class
  private
    tw26180_f: T;
    procedure tw26180_foo;
  end;

procedure tw26180_ta<T>.tw26180_foo;
begin
  Assert(tw26180_f <> 0); // Error: Boolean expression expected, but got "<undefined type>"
                  // same for >, <, <=, >=, =
end;
{$pop}

{ Case tw26483.pp }
{$push}


type
  tw26483_ta<T> = class
  private
    tw26483_f: Integer;
  end;

  tw26483_tb<T> = class
    procedure tw26483_foo(A: TObject);
  end;

procedure tw26483_tb<T>.tw26483_foo(A: TObject);
begin
  WriteLn(tw26483_ta<T>(A).tw26483_f); // p004.Error: identifier idents no member "F"
end;
{$pop}

{ Case tw26599.pp }
{$push}


type
  tw26599_tsomelist<T : TObject> = Class
  End; { Class }

  tw26599_tsomeclass = Class;
  tw26599_tsomeclasslist = tw26599_tsomelist<tw26599_tsomeclass>;

  tw26599_tsomeclass = Class(TObject)
    tw26599_somelist : tw26599_tsomeclasslist;
  End;
{$pop}


{$pop}

{ Source group: tb_generics_delphi_compile_02.pp }
{$push}

{ Case tw29053.pp }
{$push}


type
  tw29053_tmodelarray<T: class> = array of T;
{$pop}

{ Case tw30030.pp }
{$push}


type
  tw30030_tacl<K, R, M> = Class
  End;

  tw30030_tassertion<K, R, M> = Function(Acl: tw30030_tacl<K, R, M>): Boolean Of Object;
{$pop}

{ Case tw30524a.pp }
{$push}
{$ifdef FPC}

{$endif}

{uses
  Generics.Defaults;}

type
  tw30524a_tuple<tw30524a_t> = record
    tw30524a_item1: tw30524a_t;
    class operator Equal( a, b: tw30524a_tuple<tw30524a_t> ): Boolean; // FPC Error: Compilation raised exception internally
    class operator NotEqual( a, b: tw30524a_tuple<tw30524a_t> ): Boolean;
  end;

  tw30524a_tuple = record
    class function Create<tw30524a_t>( tw30524a_item1: tw30524a_t ): tw30524a_tuple<tw30524a_t>; overload; static;
  end;

class function tw30524a_tuple.Create<tw30524a_t>( tw30524a_item1: tw30524a_t ): tw30524a_tuple<tw30524a_t>;
begin
  Result.tw30524a_item1 := tw30524a_item1;
end;

class operator tw30524a_tuple<tw30524a_t>.Equal( a, b: tw30524a_tuple<tw30524a_t> ): Boolean;
begin
  Result := False;//TEqualityComparer<T>.Default.Equals( a.Item1, b.Item1 );
end;

class operator tw30524a_tuple<tw30524a_t>.NotEqual( a, b: tw30524a_tuple<tw30524a_t> ): Boolean;
begin
  Result := not( a = b );
end;

var
  tw30524a_t: tw30524a_tuple<LongInt>;
{$pop}

{ Case tw30534.pp }
{$push}


type
  tw30534_tsmartptr<T: class> = record
    class operator Implicit(aValue: T): tw30534_tsmartptr<T>;
  end;

class operator tw30534_tsmartptr<T>.Implicit(aValue: T): tw30534_tsmartptr<T>;
begin
end;

var
  tw30534_sp: tw30534_tsmartptr<TObject>;
{$pop}

{ Case tw30830b.pp }
{$push}


type
  tw30830b_tbase<T> = class
    procedure tw30830b_test1(const a: T);
  end;

  tw30830b_tderived<T> = class(tw30830b_tbase<T>)
    procedure tw30830b_test2(const a: T);
  end;

procedure tw30830b_tbase<T>.tw30830b_test1(const a: T);
begin
end;

procedure tw30830b_tderived<T>.tw30830b_test2(const a: T);
begin
end;

procedure tw30830b_test<T>(aIntf: tw30830b_tbase<T>); overload; // works
begin
end;

procedure tw30830b_test<T>(aIntf: tw30830b_tderived<T>); overload; // SIGSEGV :(
begin
end;

var
  tw30830b_b: tw30830b_tbase<LongInt>;
  tw30830b_d: tw30830b_tderived<LongInt>;
{$pop}

{ Case tw30939b.pp }
{$push}


Type
  tw30939b_tgdata<T> = record
    tw30939b_b: T
  end;

  tw30939b_tgwrapper<T> = record
    tw30939b_a: tw30939b_tgdata<T>
  end;

Function tw30939b_dosomething<T>: tw30939b_tgwrapper<T>;
  Begin
    result.tw30939b_a.tw30939b_b := default(T)
  End;
{$pop}

{ Case tw38145a.pp }
{$push}

type
  tw38145a_tmywrap<T> = record
    tw38145a_value: T;
    class operator Explicit(const w: tw38145a_tmywrap<T>): T;
    class operator Implicit(const w: tw38145a_tmywrap<T>): T;
  end;

class operator tw38145a_tmywrap<T>.Explicit(const w: tw38145a_tmywrap<T>): T;
begin
  Result := w.tw38145a_value;
end;

class operator tw38145a_tmywrap<T>.Implicit(const w: tw38145a_tmywrap<T>): T;
begin
  Result := w.tw38145a_value;
end;

type
  //TString = string[255]; //compiles
  tw38145a_tstring = string[254]; //not compiles

var
  tw38145a_myspec: tw38145a_tmywrap<tw38145a_tstring>;
{$pop}

{ Case tw40712b.pp }
{$push}

type
    tw40712b_tsomegeneric<T> = object
    type
      tw40712b_tmine = T;
    var
      tw40712b_data: record
        tw40712b_value: T;
      end;
  end;
  tw40712b_tsomegeneric2 = object(tw40712b_tsomegeneric<Integer>)
  end;
{$pop}


{$pop}

{ Source group: tb_generics_delphi_compile_03.pp }
{$push}

{ Case tw21921.pp }
{$push}
{$H+}

type

 { THashEntry }

 tw21921_thashentry<T> = record
   tw21921_key: string;
   tw21921_value: T;
   class function Create(const AKey: string; const tw21921_avalue: T): tw21921_thashentry<T>; static; inline;
 end;

class function tw21921_thashentry<T>.Create(const AKey: string; const tw21921_avalue: T): tw21921_thashentry<T>;
begin
  Result.tw21921_key := AKey;
  Result.tw21921_value := tw21921_avalue;
end;

var
  tw21921_entry: tw21921_thashentry<Integer>;
{$pop}

{ Case tw24283.pp }
{$push}
{$H+}

type
  tw24283_ta<tw24283_t> = record
  end;

  tw24283_tb<tw24283_t> = class
  end;

  tw24283_tc<tw24283_t> = class(tw24283_tb<tw24283_ta<tw24283_t>>)
  end;

{ ensure that specialization works as well }
var
  tw24283_t: tw24283_tc<LongInt>;
{$pop}

{ Case tw39581.pp }
{$push}
 {$H+}

Type
  tw39581_timplclass<P> = class;

  tw39581_ilinkingintf<P> = interface
    procedure tw39581_nestedcall(const DataFrom: tw39581_timplclass<P>);
  end;

(* Компиляция проекта, цель: Project1.exe: Код завершения 1, ошибок: 1
Project1.pas(9,55) Error: Internal error 2012101001
*)

  { TImplClass }

  tw39581_timplclass<P> = class( TInterfacedObject, tw39581_ilinkingintf<P> )
  protected
    procedure tw39581_nestedcall(const DataFrom: tw39581_timplclass<P> );
  end;

{ TImplClass }

procedure tw39581_timplclass<P>.tw39581_nestedcall(const DataFrom: tw39581_timplclass<P>);
begin

end;
{$pop}


{$pop}

{ Source group: tb_generic_routines_delphi_compile_01.pp }
{$push}

{ Case tw35670b.pp }
{$push}
procedure tw35670b_dothis<T>(tw35670b_msg: T);
begin
end;

procedure tw35670b_dothis(tw35670b_msg: TObject);
begin
end;
{$pop}

{ Case tw37380.pp }
{$push}
function tw37380_gtest<T>(tw37380_a: T; tw37380_b: T = T(1)): T;
begin
  Result := tw37380_a + tw37380_b;
end;

function tw37380_foobar(tw37380_a: Single; tw37380_b: Single = Single(1)): Single;
begin
  Result := tw37380_a + tw37380_b;
end;
{$pop}

{ Case tw38083.pp }
{$push}
procedure tw38083_test<T>(tw38083_a: T; tw38083_b: Boolean); overload;
  begin

  end;

  procedure tw38083_test(tw38083_a: String); overload;
  begin
    tw38083_test<String>(tw38083_a, True);
  end;
{$pop}


{$pop}


{$pop}

{ Case tb_generics_delphi_consolidated_02.pp }
{$push}
{ Consolidated generics regressions; original case IDs and assertions are retained. }




{ Case tgenconst6.pp }
{$push}


{
  test delphi mode
}


type
	tb_generics_delphi_consolidated_02_tgenconst6_TList<T; const tgenconst6_U: integer> = class
		list: array[0..tgenconst6_U-1] of T;
		function capacity: integer;
	end;

function tb_generics_delphi_consolidated_02_tgenconst6_TList<T; tgenconst6_U>.capacity: integer;
begin
	result := tgenconst6_U;
end;

var
	tb_generics_delphi_consolidated_02_tgenconst6_nums:tb_generics_delphi_consolidated_02_tgenconst6_TList<integer,16>;
	tb_generics_delphi_consolidated_02_tgenconst6_strs:tb_generics_delphi_consolidated_02_tgenconst6_TList<string,16>;

{$pop}

{ Case tgeneric117.pp }
{$push}






type
  tb_generics_delphi_consolidated_02_tgeneric117_TTest<T> = class
  public type
    TT = ^tb_generics_delphi_consolidated_02_tgeneric117_TTest<T>;
  end;

  tb_generics_delphi_consolidated_02_tgeneric117_TTest2<T> = class
  public type
    TT2 = tb_generics_delphi_consolidated_02_tgeneric117_TTest2<T>;
    TT = tb_generics_delphi_consolidated_02_tgeneric117_TTest<TT2>;
  end;


{$pop}

{ Case tgeneric126.pp }
{$push}






type
  tb_generics_delphi_consolidated_02_tgeneric126_TTest<S, T> = record
    class operator Implicit(const aArg: tb_generics_delphi_consolidated_02_tgeneric126_TTest<S, T>): T;
    class operator Implicit(const aArg: tb_generics_delphi_consolidated_02_tgeneric126_TTest<S, T>): TArray<T>;
    class operator Implicit(const aArg: tb_generics_delphi_consolidated_02_tgeneric126_TTest<S, T>): S;
  end;

class operator tb_generics_delphi_consolidated_02_tgeneric126_TTest<S, T>.Implicit(const aArg: tb_generics_delphi_consolidated_02_tgeneric126_TTest<S, T>): T;
begin

end;

class operator tb_generics_delphi_consolidated_02_tgeneric126_TTest<S, T>.Implicit(const aArg: tb_generics_delphi_consolidated_02_tgeneric126_TTest<S, T>): TArray<T>;
begin

end;

class operator tb_generics_delphi_consolidated_02_tgeneric126_TTest<S, T>.Implicit(const aArg: tb_generics_delphi_consolidated_02_tgeneric126_TTest<S, T>): S;
begin

end;


{$pop}

{ Case tgeneric128.pp }
{$push}






type
  tb_generics_delphi_consolidated_02_tgeneric128_Foo<T> = record
  public
    class operator Equal(const left: tb_generics_delphi_consolidated_02_tgeneric128_Foo<T>; const right: T): Boolean;
  end;

  tb_generics_delphi_consolidated_02_tgeneric128_Bar<T> = record
  public
    class operator Implicit(const value: tb_generics_delphi_consolidated_02_tgeneric128_Bar<T>): tb_generics_delphi_consolidated_02_tgeneric128_Foo<T>;
  end;

class operator tb_generics_delphi_consolidated_02_tgeneric128_Foo<T>.Equal(const left: tb_generics_delphi_consolidated_02_tgeneric128_Foo<T>; const right: T): Boolean;
begin
end;

class operator tb_generics_delphi_consolidated_02_tgeneric128_Bar<T>.Implicit(const value: tb_generics_delphi_consolidated_02_tgeneric128_Bar<T>): tb_generics_delphi_consolidated_02_tgeneric128_Foo<T>;
begin
end;


{$pop}

{ Case tgeneric129.pp }
{$push}






type
  tb_generics_delphi_consolidated_02_tgeneric129_Vector<T> = record
  public
    class operator Add(const left: TArray<T>; const right: tb_generics_delphi_consolidated_02_tgeneric129_Vector<T>): tb_generics_delphi_consolidated_02_tgeneric129_Vector<T>; inline;
  end;

class operator tb_generics_delphi_consolidated_02_tgeneric129_Vector<T>.Add(const left: TArray<T>; const right: tb_generics_delphi_consolidated_02_tgeneric129_Vector<T>): tb_generics_delphi_consolidated_02_tgeneric129_Vector<T>;
begin
end;


{$pop}

{ Case tgeneric28.pp }
{$push}




// check delphi generic syntax

type
  tb_generics_delphi_consolidated_02_tgeneric28_TGenericClass<T> = class
    F: T;
  end;

  tb_generics_delphi_consolidated_02_tgeneric28_TGenericRecord<T> = record
    F: T;
  end;

  tb_generics_delphi_consolidated_02_tgeneric28_TGenericArray<T> = array of T;

var
  tb_generics_delphi_consolidated_02_tgeneric28_ClassSpecialize: tb_generics_delphi_consolidated_02_tgeneric28_TGenericClass<Integer>;
  tb_generics_delphi_consolidated_02_tgeneric28_RecordSpecialize: tb_generics_delphi_consolidated_02_tgeneric28_TGenericRecord<Integer>;
  tb_generics_delphi_consolidated_02_tgeneric28_ArraySpecialize: tb_generics_delphi_consolidated_02_tgeneric28_TGenericArray<Integer>;

{$pop}

{ Case tgeneric29.pp }
{$push}





type
  tb_generics_delphi_consolidated_02_tgeneric29_IGenericInterface<T> = interface
    function DoSomething(Arg: T): T;
  end;

  tb_generics_delphi_consolidated_02_tgeneric29_TGenericClass<T> = class(TInterfacedObject, tb_generics_delphi_consolidated_02_tgeneric29_IGenericInterface<T>)
    F: T;
    type
      Intf = tb_generics_delphi_consolidated_02_tgeneric29_IGenericInterface<Integer>;
    function DoSomething(Arg: T): T;
    function Test(Arg: Intf): Intf;
  end;

  tb_generics_delphi_consolidated_02_tgeneric29_TGenericRecord<T> = record
    F: T;
  end;

  tb_generics_delphi_consolidated_02_tgeneric29_TGenericArray<T> = array of T;

function tb_generics_delphi_consolidated_02_tgeneric29_TGenericClass<T>.DoSomething(Arg: T): T;
begin
  Result := Arg;
end;

function tb_generics_delphi_consolidated_02_tgeneric29_TGenericClass<T>.Test(Arg: Intf): Intf;
begin
  Result := Arg;
end;

var
  tb_generics_delphi_consolidated_02_tgeneric29_ClassSpecialize: tb_generics_delphi_consolidated_02_tgeneric29_TGenericClass<Integer>;
  tb_generics_delphi_consolidated_02_tgeneric29_RecordSpecialize: tb_generics_delphi_consolidated_02_tgeneric29_TGenericRecord<Integer>;
  tb_generics_delphi_consolidated_02_tgeneric29_ArraySpecialize: tb_generics_delphi_consolidated_02_tgeneric29_TGenericArray<Integer>;

{$pop}

{ Case tgeneric36.pp }
{$push}


{ in mode Delphi generic types might be overloaded - here: class only }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric36_TTest = class

  end;

  tb_generics_delphi_consolidated_02_tgeneric36_TTest<T> = class

  end;

  tb_generics_delphi_consolidated_02_tgeneric36_TTest<T, S> = class

  end;


{$pop}

{ Case tgeneric37.pp }
{$push}


{ in mode Delphi generic types might be overloaded - here: record only }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric37_TTest = record

  end;

  tb_generics_delphi_consolidated_02_tgeneric37_TTest<T> = record

  end;

  tb_generics_delphi_consolidated_02_tgeneric37_TTest<T, S> = record

  end;


{$pop}

{ Case tgeneric42.pp }
{$push}


{ in mode Delphi generic types might be overloaded - here: class only
  Note: This tests a different code path than in the compiler than tgeneric36! }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric42_TTest<T> = class

  end;

  tb_generics_delphi_consolidated_02_tgeneric42_TTest = class

  end;

  tb_generics_delphi_consolidated_02_tgeneric42_TTest<T, S> = class

  end;


{$pop}

{ Case tgeneric43.pp }
{$push}


{ in mode Delphi generic types might be overloaded - here: record only
  Note: This tests a different code path than in the compiler than tgeneric37! }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric43_TTest<T> = record

  end;

  tb_generics_delphi_consolidated_02_tgeneric43_TTest = record

  end;

  tb_generics_delphi_consolidated_02_tgeneric43_TTest<T, S> = record

  end;


{$pop}

{ Case tgeneric49.pp }
{$push}


{ This tests whether the correct deprecated messages are printed. As I don't
  know of a way to check these inside a test this needs to be done by hand }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric49_TTest<tb_generics_delphi_consolidated_02_tgeneric49_T> = class

  end deprecated 'Message A';

  tb_generics_delphi_consolidated_02_tgeneric49_TTest = class

  end deprecated 'Message B';

  // this should print 'Message A'
  tb_generics_delphi_consolidated_02_tgeneric49_TTestInteger = tb_generics_delphi_consolidated_02_tgeneric49_TTest<Integer>;

  tb_generics_delphi_consolidated_02_tgeneric49_FooInt = Integer deprecated;

  // this should print that TTest<T> and FooInt are deprecated
  tb_generics_delphi_consolidated_02_tgeneric49_TTestFooInt = tb_generics_delphi_consolidated_02_tgeneric49_TTest<tb_generics_delphi_consolidated_02_tgeneric49_FooInt>;

var
  // this should print 'Message B'
  tb_generics_delphi_consolidated_02_tgeneric49_t: tb_generics_delphi_consolidated_02_tgeneric49_TTest;
  // this should print nothing
  tb_generics_delphi_consolidated_02_tgeneric49_t2: tb_generics_delphi_consolidated_02_tgeneric49_TTestInteger;
  // this should print that TTest<T> and FooInt are deprecated
  tb_generics_delphi_consolidated_02_tgeneric49_t3: tb_generics_delphi_consolidated_02_tgeneric49_TTest<tb_generics_delphi_consolidated_02_tgeneric49_FooInt>;

{$pop}

{ Case tgeneric50.pp }
{$push}


{ this tests that hint directives defined for a generic only apply when
  specializung a generic and that specializations may introduce their own
  directives }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric50_TTest<tb_generics_delphi_consolidated_02_tgeneric50_T> = class

  end deprecated 'Message A' platform;

  // these will both print that TTest<T> is deprecated and platform
  tb_generics_delphi_consolidated_02_tgeneric50_TTestInteger = tb_generics_delphi_consolidated_02_tgeneric50_TTest<Integer> deprecated 'Message B' experimental;
  tb_generics_delphi_consolidated_02_tgeneric50_TTestString = tb_generics_delphi_consolidated_02_tgeneric50_TTest<String>;

var
  // this will print that TTestInteger is deprecated and experimental
  tb_generics_delphi_consolidated_02_tgeneric50_t: tb_generics_delphi_consolidated_02_tgeneric50_TTestInteger;
  // this will print nothing
  tb_generics_delphi_consolidated_02_tgeneric50_t2: tb_generics_delphi_consolidated_02_tgeneric50_TTestString;

{$pop}

{ Case tgeneric60.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: record in class }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric60_TTest<tb_generics_delphi_consolidated_02_tgeneric60_T> = class
  type
    TTestSub = record
      class function Test(a: tb_generics_delphi_consolidated_02_tgeneric60_T): tb_generics_delphi_consolidated_02_tgeneric60_T; static;
    end;
  end;

class function tb_generics_delphi_consolidated_02_tgeneric60_TTest<tb_generics_delphi_consolidated_02_tgeneric60_T>.TTestSub.Test(a: tb_generics_delphi_consolidated_02_tgeneric60_T): tb_generics_delphi_consolidated_02_tgeneric60_T;
begin
  Result := a;
end;

var
  tb_generics_delphi_consolidated_02_tgeneric60_t: tb_generics_delphi_consolidated_02_tgeneric60_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric61.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: class in class }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric61_TTest<tb_generics_delphi_consolidated_02_tgeneric61_T> = class
  type
    TTestSub = class
      class function Test(a: tb_generics_delphi_consolidated_02_tgeneric61_T): tb_generics_delphi_consolidated_02_tgeneric61_T;
    end;
  end;

class function tb_generics_delphi_consolidated_02_tgeneric61_TTest<tb_generics_delphi_consolidated_02_tgeneric61_T>.TTestSub.Test(a: tb_generics_delphi_consolidated_02_tgeneric61_T): tb_generics_delphi_consolidated_02_tgeneric61_T;
begin
  Result := a;
end;

var
  tb_generics_delphi_consolidated_02_tgeneric61_t: tb_generics_delphi_consolidated_02_tgeneric61_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric62.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: object in class }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric62_TTest<tb_generics_delphi_consolidated_02_tgeneric62_T> = class
  type
    TTestSub = object
      function Test(a: tb_generics_delphi_consolidated_02_tgeneric62_T): tb_generics_delphi_consolidated_02_tgeneric62_T;
    end;
  end;

function tb_generics_delphi_consolidated_02_tgeneric62_TTest<tb_generics_delphi_consolidated_02_tgeneric62_T>.TTestSub.Test(a: tb_generics_delphi_consolidated_02_tgeneric62_T): tb_generics_delphi_consolidated_02_tgeneric62_T;
begin
  Result := a;
end;

var
  tb_generics_delphi_consolidated_02_tgeneric62_t: tb_generics_delphi_consolidated_02_tgeneric62_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric63.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: record in record }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric63_TTest<tb_generics_delphi_consolidated_02_tgeneric63_T> = record
  type
    TTestSub = record
      class function Test(a: tb_generics_delphi_consolidated_02_tgeneric63_T): tb_generics_delphi_consolidated_02_tgeneric63_T; static;
    end;
  end;

class function tb_generics_delphi_consolidated_02_tgeneric63_TTest<tb_generics_delphi_consolidated_02_tgeneric63_T>.TTestSub.Test(a: tb_generics_delphi_consolidated_02_tgeneric63_T): tb_generics_delphi_consolidated_02_tgeneric63_T;
begin
  Result := a;
end;

var
  tb_generics_delphi_consolidated_02_tgeneric63_t: tb_generics_delphi_consolidated_02_tgeneric63_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric64.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: class in record }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric64_TTest<tb_generics_delphi_consolidated_02_tgeneric64_T> = record
  type
    TTestSub = class
      class function Test(a: tb_generics_delphi_consolidated_02_tgeneric64_T): tb_generics_delphi_consolidated_02_tgeneric64_T;
    end;
  end;

class function tb_generics_delphi_consolidated_02_tgeneric64_TTest<tb_generics_delphi_consolidated_02_tgeneric64_T>.TTestSub.Test(a: tb_generics_delphi_consolidated_02_tgeneric64_T): tb_generics_delphi_consolidated_02_tgeneric64_T;
begin
  Result := a;
end;

var
  tb_generics_delphi_consolidated_02_tgeneric64_t: tb_generics_delphi_consolidated_02_tgeneric64_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric65.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: object in record }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric65_TTest<tb_generics_delphi_consolidated_02_tgeneric65_T> = record
  type
    TTestSub = object
      function Test(a: tb_generics_delphi_consolidated_02_tgeneric65_T): tb_generics_delphi_consolidated_02_tgeneric65_T;
    end;
  end;

function tb_generics_delphi_consolidated_02_tgeneric65_TTest<tb_generics_delphi_consolidated_02_tgeneric65_T>.TTestSub.Test(a: tb_generics_delphi_consolidated_02_tgeneric65_T): tb_generics_delphi_consolidated_02_tgeneric65_T;
begin
  Result := a;
end;

var
  tb_generics_delphi_consolidated_02_tgeneric65_t: tb_generics_delphi_consolidated_02_tgeneric65_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric66.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: record in object }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric66_TTest<tb_generics_delphi_consolidated_02_tgeneric66_T> = object
  type
    TTestSub = record
      class function Test(a: tb_generics_delphi_consolidated_02_tgeneric66_T): tb_generics_delphi_consolidated_02_tgeneric66_T; static;
    end;
  end;

class function tb_generics_delphi_consolidated_02_tgeneric66_TTest<tb_generics_delphi_consolidated_02_tgeneric66_T>.TTestSub.Test(a: tb_generics_delphi_consolidated_02_tgeneric66_T): tb_generics_delphi_consolidated_02_tgeneric66_T;
begin
  Result := a;
end;

var
  tb_generics_delphi_consolidated_02_tgeneric66_t: tb_generics_delphi_consolidated_02_tgeneric66_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric67.pp }
{$push}


{ this tests that nested non-generic structured types can be used inside
  generics - here: class in object }


{$ifdef fpc}
  
{$endif}

type
  tb_generics_delphi_consolidated_02_tgeneric67_TTest<tb_generics_delphi_consolidated_02_tgeneric67_T> = object
  type
    TTestSub = class
      class function Test(a: tb_generics_delphi_consolidated_02_tgeneric67_T): tb_generics_delphi_consolidated_02_tgeneric67_T;
    end;
  end;

class function tb_generics_delphi_consolidated_02_tgeneric67_TTest<tb_generics_delphi_consolidated_02_tgeneric67_T>.TTestSub.Test(a: tb_generics_delphi_consolidated_02_tgeneric67_T): tb_generics_delphi_consolidated_02_tgeneric67_T;
begin
  Result := a;
end;

var
  tb_generics_delphi_consolidated_02_tgeneric67_t: tb_generics_delphi_consolidated_02_tgeneric67_TTest<Integer>.TTestSub;

{$pop}

{ Case tgeneric69.pp }
{$push}


{ This tests that one can use a specialization of another generic which was
  introduced in the currently parsed generic can be used as a parameter type
  in a procedure variable introduced in the current generic as well }




type
  tb_generics_delphi_consolidated_02_tgeneric69_TSomeGeneric<T> = class

  end;

  tb_generics_delphi_consolidated_02_tgeneric69_TSomeOtherGeneric<T> = class
  type
    TSomeGenericT = tb_generics_delphi_consolidated_02_tgeneric69_TSomeGeneric<T>;
    TSomeProc = procedure(aParam: TSomeGenericT);
  end;


{$pop}

{ Case tgeneric70.pp }
{$push}


{ This tests that one can use a specialization of another generic which was
  introduced in the currently parsed generic can be used as a parameter type
  in a procedure variable introduced in the current generic as well }




type
  tb_generics_delphi_consolidated_02_tgeneric70_TSomeGeneric<T> = class

  end;

  tb_generics_delphi_consolidated_02_tgeneric70_TSomeOtherGeneric<T> = class
  type
    TSomeProc = procedure(aParam: tb_generics_delphi_consolidated_02_tgeneric70_TSomeGeneric<T>);
  end;


{$pop}

{ Case tgeneric78.pp }
{$push}


{ additional test based on 21064 }




type
  tb_generics_delphi_consolidated_02_tgeneric78_IGenericIntf<T> = interface
    function SomeMethod: T;
  end;

  tb_generics_delphi_consolidated_02_tgeneric78_TGenericClass<T> = class(TInterfacedObject, tb_generics_delphi_consolidated_02_tgeneric78_IGenericIntf<LongInt>)
  private
  protected
    function GenericIntf_SomeMethod: LongInt;
    function tb_generics_delphi_consolidated_02_tgeneric78_IGenericIntf<LongInt>.SomeMethod = GenericIntf_SomeMethod;
  end;

function tb_generics_delphi_consolidated_02_tgeneric78_TGenericClass<T>.GenericIntf_SomeMethod: LongInt;
begin
end;

type
  tb_generics_delphi_consolidated_02_tgeneric78_TGenericClassLongInt = tb_generics_delphi_consolidated_02_tgeneric78_TGenericClass<String>;

{$pop}

{ Case tgeneric80.pp }
{$push}






type
  tb_generics_delphi_consolidated_02_tgeneric80_TTest<T, S> = record
  end;
  tb_generics_delphi_consolidated_02_tgeneric80_TTest<T> = record
  end;
  tb_generics_delphi_consolidated_02_tgeneric80_PTest = ^tb_generics_delphi_consolidated_02_tgeneric80_TTest;
  tb_generics_delphi_consolidated_02_tgeneric80_TTest = record
  end;


{$pop}

{ Case tgeneric81.pp }
{$push}






type
  tb_generics_delphi_consolidated_02_tgeneric81_PTest = ^tb_generics_delphi_consolidated_02_tgeneric81_TTest;
  tb_generics_delphi_consolidated_02_tgeneric81_TTest<T, S> = record
  end;
  tb_generics_delphi_consolidated_02_tgeneric81_TTest<T> = record
  end;
  tb_generics_delphi_consolidated_02_tgeneric81_TTest = record
  end;


{$pop}

{ Case tgeneric82.pp }
{$push}






type
  tb_generics_delphi_consolidated_02_tgeneric82_TTest = record
  end;
  tb_generics_delphi_consolidated_02_tgeneric82_TTest<T, S> = record
  end;
  tb_generics_delphi_consolidated_02_tgeneric82_TTest<T> = record
  end;
  tb_generics_delphi_consolidated_02_tgeneric82_PTest = ^tb_generics_delphi_consolidated_02_tgeneric82_TTest;


{$pop}

{ Case tgeneric89.pp }
{$push}






type
  tb_generics_delphi_consolidated_02_tgeneric89_TTest<T> = record

  end;

  tb_generics_delphi_consolidated_02_tgeneric89_PTestLongInt = ^tb_generics_delphi_consolidated_02_tgeneric89_TTest<LongInt>;
  tb_generics_delphi_consolidated_02_tgeneric89_PTestBoolean = ^tb_generics_delphi_consolidated_02_tgeneric89_TTest<Boolean>;


{$pop}

{ Case tgeneric90.pp }
{$push}






type
  tb_generics_delphi_consolidated_02_tgeneric90_TTest = record

  end;

  tb_generics_delphi_consolidated_02_tgeneric90_TTest<T> = record

  end;

  tb_generics_delphi_consolidated_02_tgeneric90_TTest<T, S> = record

  end;

  tb_generics_delphi_consolidated_02_tgeneric90_PTestLongInt = ^tb_generics_delphi_consolidated_02_tgeneric90_TTest<LongInt>;
  tb_generics_delphi_consolidated_02_tgeneric90_PTestLongIntLongInt = ^tb_generics_delphi_consolidated_02_tgeneric90_TTest<LongInt, LongInt>;
  tb_generics_delphi_consolidated_02_tgeneric90_PTest = ^tb_generics_delphi_consolidated_02_tgeneric90_TTest;


{$pop}


{$pop}

{ Case tgeneric130.pp }
{$push}






type
  tgeneric130_TNotifyEvent = procedure(aSender: TObject) of object;
  tgeneric130_TNotifyEvent<T> = procedure(aSender: TObject; aArg: T) of object;

  tgeneric130_IEvent<T> = interface
    procedure Add(aArg: T);
  end;

  tgeneric130_INotifyEvent = tgeneric130_IEvent<tgeneric130_TNotifyEvent>;

  tgeneric130_INotifyEvent<T> = interface(tgeneric130_IEvent<tgeneric130_TNotifyEvent<T>>)
  ['{3B510AF8-DC7F-4C41-9118-2591E38D30D7}']
  end;

  tgeneric130_TTest<T> = class(TInterfacedObject, tgeneric130_INotifyEvent<T>)
    procedure Add(aArg: tgeneric130_TNotifyEvent<T>);
  end;

procedure tgeneric130_TTest<T>.Add(aArg: tgeneric130_TNotifyEvent<T>);
begin
end;

var
  tgeneric130_intf: tgeneric130_INotifyEvent<LongInt>;

{$pop}

{ Case tgeneric48.pp }
{$push}


{ in mode Delphi generic types might be overloaded - here: a mix }


{$ifdef fpc}
  
{$endif}

type
  tgeneric48_TTest = class
  end;

  tgeneric48_TTest<T> = record
  end;

  tgeneric48_TTest<T, S> = interface
  end;

  tgeneric48_TTest<T, S, R> = procedure;

  tgeneric48_TTest<T, S, R, Q> = array of Integer;

  tgeneric48_TTest<T, S, R, Q, P> = procedure of object;


{$pop}

begin

{ Case tb_generics_delphi_compile_01.pp }
{$push}

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
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$Assertions on}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$pop}
{$push}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$ifdef FPC}
{$endif}
{$pop}
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
{$pop}
{$push}
{$push}
{$H+}
{$pop}
{$push}
{$H+}
{$pop}
{$push}
{$H+}
{$pop}
{$pop}
{$push}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$pop}
begin
  { Source group: tb_generics_delphi_compile_01.pp }
  {$push}


begin

end;
  {$pop}

  { Source group: tb_generics_delphi_compile_02.pp }
  {$push}


begin
  { Case tw30524a.pp }
  {$push}
{$ifdef FPC}
{$endif}
  begin
tw30524a_t := tw30524a_tuple.Create<LongInt>(42);
  end;
  {$pop}

  { Case tw30534.pp }
  {$push}

  begin
tw30534_sp := nil;
  end;
  {$pop}

  { Case tw30830b.pp }
  {$push}

  begin
tw30830b_test<LongInt>(tw30830b_b);
  tw30830b_test<LongInt>(tw30830b_d);
  end;
  {$pop}

  { Case tw30939b.pp }
  {$push}

  begin
tw30939b_dosomething<LongInt>;
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_generics_delphi_compile_03.pp }
  {$push}


begin
  { Case tw21921.pp }
  {$push}

  begin
tw21921_entry := tw21921_thashentry<Integer>.Create('One', 1);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_generic_routines_delphi_compile_01.pp }
  {$push}


begin
  { Case tw35670b.pp }
  {$push}
begin

end;
  {$pop}

  { Case tw37380.pp }
  {$push}
begin
  WriteLn(tw37380_gtest<Single>(2, 1));
  WriteLn(tw37380_foobar(2));
end;
  {$pop}

  { Case tw38083.pp }
  {$push}
begin

end;
  {$pop}


end;
  {$pop}

end;
{$pop}

{ Case tb_generics_delphi_consolidated_02.pp }
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
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
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
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
begin

{ Case tgenconst6.pp }
{$push}

begin
	tb_generics_delphi_consolidated_02_tgenconst6_nums := tb_generics_delphi_consolidated_02_tgenconst6_TList<integer,16>.Create;
	tb_generics_delphi_consolidated_02_tgenconst6_strs := tb_generics_delphi_consolidated_02_tgenconst6_TList<string,16>.Create;
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
  tb_generics_delphi_consolidated_02_tgeneric49_t3 := tb_generics_delphi_consolidated_02_tgeneric49_TTest<tb_generics_delphi_consolidated_02_tgeneric49_FooInt>.Create;
end;
{$pop}

{ Case tgeneric50.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  // this will print that TTest<T> is deprecated and platform
  tb_generics_delphi_consolidated_02_tgeneric50_t2 := tb_generics_delphi_consolidated_02_tgeneric50_TTest<String>.Create;
  // this will print that TTestInteger is deprecated and experimental
  tb_generics_delphi_consolidated_02_tgeneric50_t := tb_generics_delphi_consolidated_02_tgeneric50_TTestInteger.Create;
end;
{$pop}

{ Case tgeneric60.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tb_generics_delphi_consolidated_02_tgeneric60_TTest<Integer>.TTestSub.Test(42);
end;
{$pop}

{ Case tgeneric61.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tb_generics_delphi_consolidated_02_tgeneric61_TTest<Integer>.TTestSub.Test(42);
end;
{$pop}

{ Case tgeneric62.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tb_generics_delphi_consolidated_02_tgeneric62_t.Test(42);
end;
{$pop}

{ Case tgeneric63.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tb_generics_delphi_consolidated_02_tgeneric63_TTest<Integer>.TTestSub.Test(42);
end;
{$pop}

{ Case tgeneric64.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tb_generics_delphi_consolidated_02_tgeneric64_TTest<Integer>.TTestSub.Test(42);
end;
{$pop}

{ Case tgeneric65.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tb_generics_delphi_consolidated_02_tgeneric65_t.Test(42);
end;
{$pop}

{ Case tgeneric66.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tb_generics_delphi_consolidated_02_tgeneric66_TTest<Integer>.TTestSub.Test(42);
end;
{$pop}

{ Case tgeneric67.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tb_generics_delphi_consolidated_02_tgeneric67_TTest<Integer>.TTestSub.Test(42);
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

end;
{$pop}

{ Case tgeneric130.pp }
{$push}

begin
  tgeneric130_intf := (tgeneric130_TTest<LongInt>.Create) as tgeneric130_INotifyEvent<LongInt>;
end;
{$pop}

{ Case tgeneric48.pp }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

end.
