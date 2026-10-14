{ Consolidated generics regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tatomic9.pas }
{$push}






generic procedure tatomic9_TestInc<T>(var aArg: T);
begin
  AtomicIncrement(aArg);
end;

generic procedure tatomic9_TestAdd<T>(var aArg1: T; aArg2: T);
begin
  AtomicIncrement(aArg1, aArg2);
end;

generic procedure tatomic9_TestXchg<T>(var aArg1: T; aArg2: T);
begin
  AtomicExchange(aArg1, aArg2);
end;

generic procedure tatomic9_TestCmpXchg<T>(var aArg1: T; aArg2, aArg3: T);
begin
  AtomicCmpExchange(aArg1, aArg2, aArg3);
end;

generic procedure tatomic9_TestCmpXchg<T; U>(var aArg1: T; aArg2, aArg3: T; out aArg4: U);
begin
  AtomicCmpExchange(aArg1, aArg2, aArg3, aArg4);
end;

var
  tatomic9_l: LongInt;
  tatomic9_b: Boolean;
  tatomic9_b32: Boolean32;
  tatomic9_lb: LongBool;

{$pop}

{ Case tgenconst1.pas }
{$push}


{
	test all possible constants
}


type
	tgenconst1_TEnums = (tgenconst1_Blaise, tgenconst1_Pascal);
	tgenconst1_kNames = set of tgenconst1_TEnums;
	tgenconst1_kChars = set of char;

type
	generic tgenconst1_TBoolean<const U: boolean> = record end;
	generic tgenconst1_TString<const U: string> = record end;
	generic tgenconst1_TFloat<const U: single> = record end;
	generic tgenconst1_TInteger<const U: integer> = record end;
	generic tgenconst1_TChar<const U: char> = record end;
	generic tgenconst1_TByte<const U: byte> = record end;
	generic tgenconst1_TQWord<const U: QWord> = record end;
	generic tgenconst1_TEnum<const U: tgenconst1_TEnums> = record end;
	generic tgenconst1_TNames<const U: tgenconst1_kNames> = record end;
	generic tgenconst1_TChars<const U: tgenconst1_kChars> = record end;
	generic tgenconst1_TPointer<const U: pointer> = record end;

var
	tgenconst1_a: specialize tgenconst1_TBoolean<true>;
	tgenconst1_b: specialize tgenconst1_TString<'string'>;
	tgenconst1_c: specialize tgenconst1_TFloat<1>;
	tgenconst1_d: specialize tgenconst1_TInteger<10>;
	tgenconst1_e: specialize tgenconst1_TByte<255>;
	tgenconst1_f: specialize tgenconst1_TChar<'a'>;
	tgenconst1_g: specialize tgenconst1_TEnum<tgenconst1_Pascal>;
	tgenconst1_h: specialize tgenconst1_TNames<[tgenconst1_Blaise,tgenconst1_Pascal]>;
	tgenconst1_i: specialize tgenconst1_TChars<['a','b']>;
	tgenconst1_j: specialize tgenconst1_TQWord<10>;
	tgenconst1_k: specialize tgenconst1_TPointer<nil>;

{$pop}

{ Case tgenconst12.pas }
{$push}


{
  test def compare with specialized types
}


type
  generic tgenconst12_TTest<const U: integer> = class
  end;

type
	tgenconst12_ATest = specialize tgenconst12_TTest<100>;

{$pop}

{ Case tgenconst2.pas }
{$push}


{
  test lists of types/constants
}


type
	generic tgenconst2_TMoreThanOne<T1,T2;const U1,U2:integer> = record end;

var
	tgenconst2_a: specialize tgenconst2_TMoreThanOne<integer,string,10,10>;

{$pop}

{ Case tgenconst29.pas }
{$push}





type
  tgenconst29_TRange = 3..4;

  generic tgenconst29_TTest<const U: tgenconst29_TRange> = record end;

var
  tgenconst29_t: specialize tgenconst29_TTest<3>;

{$pop}

{ Case tgenconst4.pas }
{$push}


{
  test constants in generic procedures
}


generic procedure tgenconst4_DoThis<T;const U:string>(msg: string = U);
begin
	writeln(msg, ' sizeof:',sizeof(t), ' default: ', U);
end;


{$pop}

{ Case tgenconst5.pas }
{$push}


{
	test nested generic records with constants
}


type
	generic tgenconst5_THelperA<const U:integer> = record
		tgenconst5_list: array[0..U-1] of byte;
	end;

type
	generic tgenconst5_THelperB<T> = record
		value: T;
	end;

type
	generic tgenconst5_TList<T; const U:integer> = record
		helperA: specialize tgenconst5_THelperA<U>;
		helperB: specialize tgenconst5_THelperB<T>;
	end;

var
	tgenconst5_list: specialize tgenconst5_TList<integer,32>;

{$pop}

{ Case tgenconstraint37.pas }
{$push}






type
  generic tgenconstraint37_TGenericTObject<T: TObject> = class
  end;

  generic tgenconstraint37_TGenericClass<T: class> = class
  end;

  generic tgenconstraint37_TGenericIInterface<T: IInterface> = class
  end;

  tgenconstraint37_TTestObject = class;
  tgenconstraint37_ITestInterface = interface;


  tgenconstraint37_TGenericTObjectTTestObject = specialize tgenconstraint37_TGenericTObject<tgenconstraint37_TTestObject>;

  tgenconstraint37_TGenericClassTTestObject = specialize tgenconstraint37_TGenericClass<tgenconstraint37_TTestObject>;

  tgenconstraint37_TGenericIInterfaceITestInterface = specialize tgenconstraint37_TGenericIInterface<tgenconstraint37_ITestInterface>;


  tgenconstraint37_TTestObject = class
  end;

  tgenconstraint37_ITestInterface = interface
  end;


{$pop}

{ Case tgeneric118.pas }
{$push}






type
  generic tgeneric118_TTest<T> = class
  public type
    TT = ^specialize tgeneric118_TTest<T>;
  end;

  generic tgeneric118_TTest2<T> = class
  public type
    TT2 = specialize tgeneric118_TTest2<T>;
    TT = specialize tgeneric118_TTest<TT2>;
  end;


{$pop}

{ Case tgeneric119.pas }
{$push}





{$warn 5024 error}
{$warn 5036 error}

type
  generic tgeneric119_TTest<tgeneric119_T> = class
    procedure Test(aArg: tgeneric119_T);
  end;

{$push}
{$warn 5024 off}
procedure tgeneric119_TTest.Test(aArg: tgeneric119_T);
var
  v: LongInt;
begin
  {$push}
  {$warn 5036 off}
  Writeln(v);
  {$pop}
end;
{$pop}

type
  tgeneric119_TTestLongInt = specialize tgeneric119_TTest<LongInt>;

var
  tgeneric119_t: tgeneric119_TTestLongInt;

{$pop}

{ Case tgeneric71.pas }
{$push}


{ This tests that one can use a specialization of another generic which was
  introduced in the currently parsed generic can be used as a parameter type
  in a procedure variable introduced in the current generic as well }




type
  generic tgeneric71_TSomeGeneric<T> = class

  end;

  generic tgeneric71_TSomeOtherGeneric<T> = class
  type
    TSomeGenericT = specialize tgeneric71_TSomeGeneric<T>;
    TSomeProc = procedure(aParam: TSomeGenericT);
  end;


{$pop}

{ Case tgeneric72.pas }
{$push}


{ This tests that the two specializations of TUsedGeneric (once with
  TGeneric<LongInt>.TSubType and once with TGeneric<Pointer>.TSubType)  inside
  TGeneric are unique }





type
  generic tgeneric72_TUsedGeneric<T> = class
  type
    PT = ^T;
  var
    f: PT;
  end;

  generic tgeneric72_TGeneric<T> = class
  type
    TSubType = record
      Field: T;
    end;
    PSubType = ^TSubType;
    TMyUsedGeneric = specialize tgeneric72_TUsedGeneric<TSubType>;
  private
    f: PSubType;
  public
    function GetUsedGeneric: TMyUsedGeneric;
  end;

function tgeneric72_TGeneric.GetUsedGeneric: TMyUsedGeneric;
begin
  Result := TMyUsedGeneric.Create;
  Result.f := f;
end;

type
  tgeneric72_TGenericLongInt = specialize tgeneric72_TGeneric<LongInt>;
  tgeneric72_TGenericPointer = specialize tgeneric72_TGeneric<Pointer>;


{$pop}

{ Case tgeneric73.pas }
{$push}


{ This tests that nested types can reference each other inside a generic }




type
  generic tgeneric73_TTest<T> = class
  public type
    TSubClass1 = class

    end;

    TSubClass2 = class
      f: TSubClass1;
    end;
  end;


{$pop}

{ Case tgeneric79.pas }
{$push}


{ additional test based on 21064 }




type
  generic tgeneric79_IGenericIntf<T> = interface
    function SomeMethod: T;
  end;

  generic tgeneric79_TGenericClass<T> = class(TInterfacedObject, specialize tgeneric79_IGenericIntf<LongInt>)
  private
  protected
    function GenericIntf_SomeMethod: LongInt;
    function specialize tgeneric79_IGenericIntf<LongInt>.SomeMethod = GenericIntf_SomeMethod;
  end;

function tgeneric79_TGenericClass.GenericIntf_SomeMethod: LongInt;
begin
end;

type
  tgeneric79_TGenericClassLongInt = specialize tgeneric79_TGenericClass<String>;

{$pop}

{ Case tgeneric98.pas }
{$push}






type
  generic tgeneric98_TTest<T> = class
  public type
    TAlias = T;
  private
    fField: TAlias;
    procedure SetField(aValue: TAlias);
  public
    property Field: TAlias read fField write SetField;
    function CalcField: TAlias;
  end;

  generic tgeneric98_TTest2<T> = class
  public type
    TTestT = specialize tgeneric98_TTest<T>;
  private
    fField: TTestT.TAlias;
    procedure SetField(aValue: TTestT.TAlias);
  public
    property Field: TTestT.TAlias read fField write SetField;
    function CalcField: TTestT.TAlias;
  end;

procedure tgeneric98_TTest.SetField(aValue: TAlias);
begin
end;

function tgeneric98_TTest.CalcField: TAlias;
begin
  Result := Default(TAlias);
end;

procedure tgeneric98_TTest2.SetField(aValue: TTestT.TAlias);
begin
end;

function tgeneric98_TTest2.CalcField: TTestT.TAlias;
begin
  Result := Default(TTestT.TAlias);
end;


{$pop}

{ Case tgenfwd1.pas }
{$push}






type
  generic tgenfwd1_TGen1<T> = class;
  generic tgenfwd1_TGen2<T: class> = class;
  generic tgenfwd1_TGen3<const N: Integer> = class;
  generic tgenfwd1_TGen4<T; S: class; const N: Integer> = class;

  tgenfwd1_TTest = class
    f1: specialize tgenfwd1_TGen1<LongInt>;
    f2: specialize tgenfwd1_TGen2<TObject>;
    f3: specialize tgenfwd1_TGen3<42>;
    f4: specialize tgenfwd1_TGen4<LongInt, TObject, 42>;

    { this will reuse the above specializations }
    f5: specialize tgenfwd1_TGen1<LongInt>;
    f6: specialize tgenfwd1_TGen2<TObject>;
    f7: specialize tgenfwd1_TGen3<42>;
    f8: specialize tgenfwd1_TGen4<LongInt, TObject, 42>;
  end;

  generic tgenfwd1_TGen1<T> = class
  end;

  generic tgenfwd1_TGen2<T: class> = class
  end;

  generic tgenfwd1_TGen3<const N: Integer> = class
  end;

  generic tgenfwd1_TGen4<T; S: class; const N: Integer> = class
  end;


{$pop}

{ Case tgenfwd13.pas }
{$push}






type
  generic tgenfwd13_ITest<T> = interface;

  generic tgenfwd13_ISomeIntf<T> = interface
    procedure Something(aTest: specialize tgenfwd13_ITest<T>);
  end;

  generic tgenfwd13_ITest<T> = interface
  end;


{$pop}

begin

{ Case tatomic9.pas }
{$push}

begin
  tatomic9_l := 0;
  specialize tatomic9_TestInc<LongInt>(tatomic9_l);
  specialize tatomic9_TestAdd<LongInt>(tatomic9_l, 42);
  specialize tatomic9_TestXchg<LongInt>(tatomic9_l, 21);
  specialize tatomic9_TestCmpXchg<LongInt>(tatomic9_l, 21, 84);
  specialize tatomic9_TestCmpXchg<LongInt, Boolean>(tatomic9_l, 84, 42, tatomic9_b);
  specialize tatomic9_TestCmpXchg<LongInt, Boolean32>(tatomic9_l, 84, 42, tatomic9_b32);
  specialize tatomic9_TestCmpXchg<LongInt, LongBool>(tatomic9_l, 84, 42, tatomic9_lb);
end;
{$pop}

{ Case tgenconst1.pas }
{$push}

begin
end;
{$pop}

{ Case tgenconst12.pas }
{$push}

begin
end;
{$pop}

{ Case tgenconst2.pas }
{$push}

begin
end;
{$pop}

{ Case tgenconst29.pas }
{$push}

begin
end;
{$pop}

{ Case tgenconst4.pas }
{$push}

begin
	specialize tgenconst4_DoThis<integer,'genparam'>('hello world');
end;
{$pop}

{ Case tgenconst5.pas }
{$push}

begin
	writeln('sizeof:',sizeof(tgenconst5_list));
end;
{$pop}

{ Case tgenconstraint37.pas }
{$push}

begin
end;
{$pop}

{ Case tgeneric118.pas }
{$push}

begin

end;
{$pop}

{ Case tgeneric119.pas }
{$push}

{$warn 5024 error}
{$warn 5036 error}
{$push}
{$warn 5024 off}
{$push}
{$warn 5036 off}
{$pop}
{$pop}
begin
  tgeneric119_t := tgeneric119_TTestLongInt.Create;
  tgeneric119_t.Free;
end;
{$pop}

{ Case tgeneric71.pas }
{$push}

begin

end;
{$pop}

{ Case tgeneric72.pas }
{$push}

begin

end;
{$pop}

{ Case tgeneric73.pas }
{$push}

begin

end;
{$pop}

{ Case tgeneric79.pas }
{$push}

begin
end;
{$pop}

{ Case tgeneric98.pas }
{$push}

begin

end;
{$pop}

{ Case tgenfwd1.pas }
{$push}

begin

end;
{$pop}

{ Case tgenfwd13.pas }
{$push}

begin

end;
{$pop}

end.
