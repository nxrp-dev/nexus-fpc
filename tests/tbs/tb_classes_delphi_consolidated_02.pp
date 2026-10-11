{ Consolidated classes regressions; original case IDs and assertions are retained. }
{ %NORUN }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb_classes_delphi_compile_01.pp }
{$push}
{ Classes regression cases; original case IDs are retained below. }


{ Case tw16980.pp }
{$push}

{$packset 4}
type
  tw16980_tcolorcomponent = (tb_classes_delphi_compile_01_ccRed, tb_classes_delphi_compile_01_ccGreen, tb_classes_delphi_compile_01_ccBlue, tb_classes_delphi_compile_01_ccAlpha);
  tw16980_tcolormask = set of tw16980_tcolorcomponent;

  tw16980_tglstatecache = class
  private
    tw16980_fcolorwritemask: array[0..15] of tw16980_tcolormask;
    procedure tw16980_setcolorwritemask(Index: Integer; const tw16980_value: tw16980_tcolormask);
  end;
  tw16980_tgluint = cardinal;
  tw16980_tglboolean = boolean;

var
  tw16980_glcolormaski: procedure(index: tw16980_tgluint; tw16980_r: tw16980_tglboolean; tw16980_g: tw16980_tglboolean;
                            tw16980_b: tw16980_tglboolean; tw16980_a: tw16980_tglboolean);{$IFDEF MSWINDOWS} stdcall; {$ENDIF} {$IFDEF UNIX} cdecl; {$ENDIF}

procedure tw16980_tglstatecache.tw16980_setcolorwritemask(Index: Integer;
  const tw16980_value: tw16980_tcolormask);
begin
//  if FColorWriteMask[Index]<>Value then
  begin
    tw16980_fcolorwritemask[Index] := tw16980_value;
    tw16980_glcolormaski(Index, tb_classes_delphi_compile_01_ccRed in tw16980_value, tb_classes_delphi_compile_01_ccGreen in tw16980_value, tb_classes_delphi_compile_01_ccBlue in tw16980_value,
                 tb_classes_delphi_compile_01_ccAlpha in tw16980_value);
  end;
end;
{$pop}

{ Case tw24486.pp }
{$push}


type
  tw24486_tproc1 = procedure(a: integer);

var
  tw24486_proc1: tw24486_tproc1;

type
  tw24486_tclass1 = class
    class procedure tw24486_p1(a: integer); static;
  end;

{ tclass1 }

class procedure tw24486_tclass1.tw24486_p1(a: integer);
begin
end;
{$pop}

{ Case tw27349.pp }
{$push}

{.$mode objfpc}
{.$modeswitch advancedrecords}

type

  tw27349_c = class

   type

    tw27349_tmyintf = class(TInterfacedObject, iinterface)
     function _AddRef : longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    end;

  end;

  tw27349_r = record

   type

    tw27349_tmyintf = class(TInterfacedObject, iinterface)
     function _AddRef : longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    end;

  end;

function tw27349_c.tw27349_tmyintf._AddRef: longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
 result := inherited _AddRef; // OK
end;

function tw27349_r.tw27349_tmyintf._AddRef: longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
 result := inherited _AddRef; // FAIL
end;
{$pop}

{ Case tw30179.pp }
{$push}


type
  tw30179_ttest1 = record
    class function tw30179_add<T>(const A, B: T): T; static; inline;
  end;

class function tw30179_ttest1.tw30179_add<T>(const A, B: T): T;
begin
  Result := A + B;
end;

procedure tw30179_main();
var
  tw30179_i: Integer;
begin
  tw30179_i := tw30179_ttest1.tw30179_add<Integer>(1, 2); // project1.lpr(14,26) Error: Identifier not found "Add$1"
end;
{$pop}


{$pop}

{ Case tb_nested_fields_delphi.pp }
{$push}
{ Nested Delphi field types, private record members and class variables. }


{ tw18767a.pp }
{$H+}

type
  tb_nested_fields_delphi_TConstArrayOwner = class
  strict private
    const
      n = 3;
    var
      x: array[0..1] of record
        y: array[0..n] of integer;
      end;
  end;

{ tw18767b.pp }
{$H+}

type
  tb_nested_fields_delphi_TEnumArrayOwner = class
  strict private
    type
      TBar = (one, two);
    var
      x: array of record
        y: array[TBar] of integer;
      end;
  end;

{ tw18768.pp }
{$H+}

type
  tb_nested_fields_delphi_TPrivateRecordOuter = record
  private
    type
      TFoo3 = record
      private
        b, c: integer;
      strict private
        a: integer;
      public
        function GetFoo2: integer;
      end;
  end;

function tb_nested_fields_delphi_TPrivateRecordOuter.TFoo3.GetFoo2: integer;
begin
  c := a * b;
end;

{ tw18131.pp }


type
  tb_nested_fields_delphi_TFoo1 = class
    type
      TFoo2 = class
        class var
          x: integer;
        constructor Create;
      end;
  end;

constructor tb_nested_fields_delphi_TFoo1.TFoo2.Create;
begin
  inherited;
  inc(x);
end;


{$pop}

{ Case tw13992a.pp }
{$push}


{ dispose(property) should be accepted }





type
  tw13992a_TMyRec = record
    s: string;
  end;
  tw13992a_PMyRec = ^tw13992a_TMyRec;

  tw13992a_TSomeClass = class
  private
    FMyRec: tw13992a_PMyRec;
  public
    constructor Create;
    destructor Destroy; override;
    property MyRec: tw13992a_PMyRec read FMyRec write FMyRec;
  end;

{ TSomeClass }

constructor tw13992a_TSomeClass.Create;
begin
//  New(MyRec);
end;

destructor tw13992a_TSomeClass.Destroy;
begin
  Dispose(MyRec);
  inherited;
end;


{$pop}

{ Case tw15610.pp }
{$push}



{$ifdef FPC}
	
{$endif}

type
    tw15610_TBase=class
    private
	fData:string;
	procedure Setdata(ndx:integer;const s:string);
	function GetData(ndx:integer):string;
	function OldIsStored(ndx:integer):boolean;
    public
	property Data:string index 0 read GetData write SetData stored OldIsStored;
    end;

    tw15610_TDerived=class(tw15610_TBase)
    private
	function IsDataStored(ndx:integer):boolean;
    published
	property Data stored IsDataStored;
    end;


    procedure tw15610_TBase.Setdata(ndx:integer;const s:string);
    begin
	if ndx=0 then fData:=s;
    end;

    function tw15610_TBase.GetData(ndx:integer):string;
    begin
	if ndx=0 then
	    Result:=fData
	else
	    Result:='';
    end;

    function tw15610_TBase.OldIsStored(ndx:integer):boolean;
    begin
	Result:=ndx>1;
    end;



    function tw15610_TDerived.IsDataStored(ndx:integer):boolean;
    begin
	Result:=ndx=0;
    end;



{$pop}

{ Case tw16083.pp }
{$push}



{$ifdef fpc}
  
{$endif}

type
  tw16083_TClass1 = class
  public type
    TNestedClass = class
    end;

    TNestedClass2 = class(TNestedClass)
    end;
  end;

  tw16083_TClass3 = class(tw16083_TClass1.TNestedClass)
  end;


{$pop}

{ Case tw16222.pp }
{$push}



{$ifdef fpc}
  
{$endif}

type
  tw16222_TOuterClass = class
  public
    type
      TInnerClass = class
      end;
  end;

function tw16222_fn(P: Pointer): tw16222_TOuterClass.TInnerClass;
begin
  Result := tw16222_TOuterClass.TInnerClass(P);
end;


{$pop}

{ Case tw18103c.pp }
{$push}




// alias test generic class
// example is a subset of a working delphi class
// the nested types are there so that they can be used to defined types (e.g.  var p : bwimagespecialization.reft;)
//




Type
  tw18103c_tbwimagegen<T> = Class(TObject)
                 Type
                    TLocalType = tw18103c_tbwimagegen<T>;
                    BaseUnit = T;
                    RefT= ^BaseUnit;
                  procedure copylines(source: tw18103c_tbwimagegen<T>;xfrom,xto:integer;xdestline:integer=0);
                  function GetImagePointer( OriginX, OriginY : Integer ): reft;inline;
                  function GetLinePointer(originy:integer):reft;
                  property scanline[i:integer]:reft read getlinepointer;
                  end;


procedure tw18103c_tbwimagegen<T>.copylines(source: tw18103c_tbwimagegen<T>;xfrom,xto:integer;xdestline:integer=0);
begin
end;
function tw18103c_tbwimagegen<T>.GetImagePointer( OriginX, OriginY : Integer ): reft;inline;
begin
end;
function tw18103c_tbwimagegen<T>.GetLinePointer(originy:integer):reft;
begin
end;


{$pop}

{ Case tw20421.pp }
{$push}





type
  tw20421_TAncestor = class
  private
    function GetTest(index: integer): integer;
  public
    property test[index: integer]: integer read GetTest;
  end;

  tw20421_TDescendant = class(tw20421_TAncestor)
  private
    procedure SetTest(index, value: integer);
  public
    property test write SetTest;
  end;

{ TAncestor }

function tw20421_TAncestor.GetTest(index: integer): integer;
begin

end;

{ TDescendant }

procedure tw20421_TDescendant.SetTest(index, value: integer);
begin

end;


{$pop}

{ Case tw21051.pp }
{$push}




{$H+}

type
  tw21051_TCustomInner<T> = class abstract
  protected
    function SomeMethod: T; virtual; abstract;
  end;

  tw21051_TContainer<T> = class
  public
    function GetInner: tw21051_TCustomInner<T>;
  end;

  tw21051_TInner<T> = class(tw21051_TCustomInner<T>)
  private
    FContainer: tw21051_TContainer<T>;
  protected
    function SomeMethod: T; override;
  public
    constructor Create(AContainer: tw21051_TContainer<T>);
  end;


function tw21051_TContainer<T>.GetInner: tw21051_TCustomInner<T>;
type
  InnerClass = tw21051_TInner<T>;
begin
  Result := InnerClass.Create(Self);
end;

function tw21051_TInner<T>.SomeMethod: T;
begin

end;

constructor tw21051_TInner<T>.Create(AContainer: tw21051_TContainer<T>);
begin
  FContainer := AContainer;
end;

procedure tw21051_Test;
var
  C: tw21051_TContainer<string>;
begin
  C := tw21051_TContainer<string>.Create;
end;


{$pop}

{ Case tw22329.pp }
{$push}






type
  tw22329_TObjectHelper = class helper for TObject
    procedure SayHello(const I: Integer); overload;
    procedure SayHello(const S: string); overload;
  end;

procedure tw22329_TObjectHelper.SayHello(const I: Integer); overload;
begin
  Writeln('Hello ', I);
end;

procedure tw22329_TObjectHelper.SayHello(const S: string); overload;
begin
  Writeln('Hello ', S);
end;

var
  tw22329_Obj: TObject;

{$pop}

{ Case tw22792.pp }
{$push}






type
  tw22792_TStaticArray<T> = array [0..MaxInt div SizeOf(T) - 1] of T;

  tw22792_TWrapper<TValue> = class
  strict private
    type
      PValue = ^TValue;
      PList = ^TList;
      TList = tw22792_TStaticArray<PValue>;
        { Expand this manually to get rid of the error }
  strict private
    FList: PList;
  public
    procedure Z(const value: TValue);
  end;

procedure tw22792_TWrapper<TValue>.Z(const value: TValue);
begin
  FList := GetMem(SizeOf(PValue));
  FList^[0] := GetMem(SizeOf(TValue));
  FList^[0]^ := value;
    { Error: Illegal qualifier; use a manual cast to get rid of the error }
  FreeMem(FList^[0]);
  FreeMem(FList, SizeOf(PValue));
end;


{$pop}

{ Case tw22796.pp }
{$push}




{$H+}

//uses Classes;

type
  tw22796_TWordTagValue = record
  strict private
    FValue: Word;
    FMissingOrInvalid: Boolean; // Try to disable this line !
  public
    class function CreateFromString(const AString: string): tw22796_TWordTagValue; static;
    property Value: Word read FValue;
  end;

class function tw22796_TWordTagValue.CreateFromString(const AString: string): tw22796_TWordTagValue;
begin
  Result.FValue := 0;
end;


{$pop}

{ Case tw24071.pp }
{$push}






type
  tw24071_TA<T> = class
  end;

  tw24071_TB<T> = class
  public
  type
    TC = class;
    TC = class(tw24071_TA<TC>)
    private
      procedure Foo; virtual; abstract;
    end;
  end;

var
  tw24071_X: tw24071_TB<Integer>;

{$pop}

{ Case tw24072.pp }
{$push}






type
  tw24072_TA<tw24072_T> = record
  end;

  tw24072_TB<tw24072_T> = class
  public
    type
      TC = tw24072_TA<tw24072_T>;

      TD = record
        Foo: TC; // ! FATAL !
      end;
  end;

var
  tw24072_t: tw24072_TB<LongInt>;

{$pop}

{ Case tw24285.pp }
{$push}




{$H+}

type
  tw24285_TA<T> = class
  end;

  tw24285_TB<T> = class
  public
    type
      tw24285_TA = class(tw24285_TA<T>)
      end;
  end;

type
  tw24285_TBLongInt = tw24285_TB<LongInt>;


{$pop}

{ Case tw24458.pp }
{$push}






type
  tw24458_TA<T: class> = class
  public
    procedure Foo(const AValue: T);
  end;

procedure tw24458_TA<T>.Foo(const AValue: T);
begin
  AValue.Free; // Error: identifier idents no member "Free"
end;


{$pop}

{ Case tw24865.pp }
{$push}





type
  tw24865_TTest = class
  public
    class var fc3: integer;
    class procedure c1();
    class procedure c2(); static;
    class property c3: integer read fc3 write fc3;
  end;

class procedure tw24865_TTest.c1;
begin
end;

class procedure tw24865_TTest.c2;

  function nested: integer;
  begin
    c1;
    fc3 := 1;
    c3 := 2;
    result := c3;
  end;

begin
end;


{$pop}

{ Case tw25044.pp }
{$push}




{$IFDEF FPC}
  
{$ENDIF}

type
  tw25044_TBase = class(TObject)
  end;

  tw25044_TDescendant = class(tw25044_TBase)
  end;

  tw25044_T123456789012345678901 = record
  public
    Value: tw25044_TDescendant;

    class operator Implicit(Operand: tw25044_T123456789012345678901): tw25044_TBase;
    class operator Implicit(Operand: tw25044_T123456789012345678901): tw25044_TDescendant;
  end;

{ T123456789012345678901 }

class operator tw25044_T123456789012345678901.Implicit(Operand: tw25044_T123456789012345678901): tw25044_TBase;
begin
  Result := Operand.Value;
end;

class operator tw25044_T123456789012345678901.Implicit(Operand: tw25044_T123456789012345678901): tw25044_TDescendant;
begin
  Result := Operand.Value;
end;


{$pop}

{ Case tw27750a.pp }
{$push}






type

  { TGeneric }

  tw27750a_TGeneric<Foo, Bar> = record
  public type
    TGFB = tw27750a_TGeneric<Foo, Bar>;
  public
    class operator implicit(aFoo : Foo) : TGFB;
    class operator implicit(aBar : Bar) : TGFB;
  end;

{ TGeneric }

class operator tw27750a_TGeneric<Foo, Bar>.implicit(aFoo: Foo): TGFB;
begin

end;

class operator tw27750a_TGeneric<Foo, Bar>.implicit(aBar: Bar): TGFB;
begin

end;


{$pop}

{ Case tw30202.pp }
{$push}





{$POINTERMATH ON}

type
  tw30202_TArray = record
    class procedure QuickSort<T>(var A: Array of T; const Index, Count: Integer); static; inline;
  end;

class procedure tw30202_TArray.QuickSort<T>(var A: Array of T; const Index, Count: Integer);
var
  I, J: Integer;
  Temp, Pivot: T;
begin
  if Index < Count then
  begin
    Pivot := A[Random(Count - Index) + Index + 1];
    I := Index - 1;
    J := Count + 1;
    repeat
      repeat Inc(I) until A[I] >= Pivot;
      repeat Dec(J) until A[J] <= Pivot;
      Temp := A[I];
      A[I] := A[J];
      A[J] := Temp;
    until I >= J;
    A[J] := A[I];
    A[I] := Temp;
    QuickSort<T>(A, Index, I - 1); // project1.lpr(30,17) Error: Compilation raised exception internally
    QuickSort<T>(A, I, Count);
  end;
end;

var
  tw30202_arri: array of LongInt;
  tw30202_arrs: array of String;

{$pop}

{ Case tw30534b.pp }
{$push}




type
  tw30534b_TNullable<T: record> = record
  public type
    PT = ^T;
  public
    class operator Implicit(A: PT): tw30534b_TNullable<T>;
    class operator Implicit(A: T): tw30534b_TNullable<T>;
    class operator Equal(A: tw30534b_TNullable<T>; B: PT): Boolean;
    class operator Equal(A: tw30534b_TNullable<T>; B: T): Boolean;
  end;

  TRec = record
  end;

class operator tw30534b_TNullable<T>.Implicit(A: PT): tw30534b_TNullable<T>;
begin
end;

class operator tw30534b_TNullable<T>.Implicit(A: T): tw30534b_TNullable<T>;
begin
end;

class operator tw30534b_TNullable<T>.Equal(A: tw30534b_TNullable<T>; B: PT): Boolean;
begin
end;

class operator tw30534b_TNullable<T>.Equal(A: tw30534b_TNullable<T>; B: T): Boolean;
begin
end;

var
  tw30534b_x: tw30534b_TNullable<integer>;
  tw30534b_y: tw30534b_TNullable<TRec>;

{$pop}

{ Case tw41062.pp }
{$push}




{$H+}

type

  { TTest }

  tw41062_TTest = class
  public
    class procedure Test; static;
    class function Test2<T>: T; static;
  end;

class procedure tw41062_TTest.Test;
var
	Obj1, Obj2: TObject;
begin
  if (AtomicCmpExchange(Pointer(Obj1), Pointer(Obj2), nil) <> nil) then; // It's ok
end;

class function tw41062_TTest.Test2<T>: T;
var
	Obj1, Obj2: TObject;
begin
  AtomicCmpExchange(Pointer(Obj1), Pointer(Obj2), nil); // It's ok

  if (AtomicCmpExchange(Pointer(Obj1), Pointer(Obj2), nil) <> nil) then; // Error: Operator is not overloaded: "untyped" = "^untyped"
end;


{$pop}

{ Case tw41184.pp }
{$push}





{$warn 6058 off}

type
  tw41184_TMyClass = class;
  tw41184_TMyClassClass = class of tw41184_TMyClass;
  tw41184_TMyClass = class
    class function Func: tw41184_TMyClassClass; inline;
  end;

class function tw41184_TMyClass.Func: tw41184_TMyClassClass;
begin
  Func().Func;
end;


{$pop}

{ Case tw41516b.pp }
{$push}



type

  tw41516b_TFoo = class
    procedure       Foo2;
  end;

  tw41516b_TGen<T2: TObject> = class
    procedure       Foo2;
  end;

  tw41516b_TWrap1 = class
  public type
    TTest4<T2: TObject> = class
      procedure       Foo2;
    end;

  public
    procedure         P1;
  end;

var
  tw41516b_gTest4:  tw41516b_TWrap1.TTest4<TObject>;

{ TFoo }

procedure tw41516b_TFoo.Foo2;
var
  v2:  tw41516b_TWrap1.TTest4<TObject>;
begin
end;

procedure tw41516b_TGen<T2>.Foo2;
var
  v2:  tw41516b_TWrap1.TTest4<TObject>;
begin
end;

// TWRAP1

procedure tw41516b_TWrap1.TTest4<T2>.Foo2;
var     // V2: project1.lpr(50,32) Error: Parameters or result types cannot contain local type definitions. Use a separate type definition in a type block.
  v2:  tw41516b_TWrap1.TTest4<TObject>;
  v3:  TTest4<TObject>;
type
  x2 =  tw41516b_TWrap1.TTest4<TObject>;
  x3 =  TTest4<TObject>;
begin
end;

procedure tw41516b_TWrap1.P1;
var        // V2: project1.lpr(50,32) Error: Parameters or result types cannot contain local type definitions. Use a separate type definition in a type block.
  v2:  tw41516b_TWrap1.TTest4<TObject>;
  v3:  TTest4<TObject>;
type
  x2 =  tw41516b_TWrap1.TTest4<TObject>;
  x3 =  TTest4<TObject>;
begin
end;


{$pop}

{ Case tw8777f.pp }
{$push}


{$ifdef fpc}

{$endif}

type
  tw8777f_tc = class
    private
      f: integer;
    public
      property prop: integer read f write f;
  end;

var
  tw8777f_c: tw8777f_tc;
  tw8777f_p: pointer;

{$pop}

{ Case tw8777g.pp }
{$push}


{$ifdef fpc}

{$endif}

type
  tw8777g_tc = class
    private
      f: integer;
      procedure setf(const val: integer);
    public
      property prop: integer read f write setf;
  end;

procedure tw8777g_tc.setf(const val: integer);
begin
  f:=val;
end;

var
  tw8777g_c: tw8777g_tc;
  tw8777g_p: pointer;

{$pop}

{ Case tw8777i.pp }
{$push}

{$ifdef fpc}

{$endif}

type
  tw8777i_tc = class
    private
      f: array[0..5] of integer;
      procedure setf(const val: integer);
    public
      property prop: integer read f[1] write setf;
  end;

procedure tw8777i_tc.setf(const val: integer);
begin
  f[1]:=val;
end;

var
  tw8777i_c: tw8777i_tc;
  tw8777i_p: pointer;

{$pop}

begin

{ Case tb_classes_delphi_compile_01.pp }
{$push}
{$push}

{$packset 4}
{$IFDEF MSWINDOWS}
{$ENDIF}
{$IFDEF UNIX}
{$ENDIF}
{$pop}
{$push}

{$pop}
{$push}

{$IFNDEF WINDOWS}
{$ELSE}
{$ENDIF}
{$IFNDEF WINDOWS}
{$ELSE}
{$ENDIF}
{$IFNDEF WINDOWS}
{$ELSE}
{$ENDIF}
{$IFNDEF WINDOWS}
{$ELSE}
{$ENDIF}
{$pop}
{$push}

{$pop}
begin
  { Case tw24486.pp }
  {$push}

  begin
tw24486_proc1 := tw24486_tclass1.tw24486_p1;
  end;
  {$pop}

  { Case tw30179.pp }
  {$push}

  begin
tw30179_main();
  end;
  {$pop}

end;
{$pop}

{ Case tb_nested_fields_delphi.pp }
{$push}

{$H+}

{$H+}

{$H+}

begin
  { tw18767a.pp }
  tb_nested_fields_delphi_TConstArrayOwner.Create;
  ;

  { tw18767b.pp }
  tb_nested_fields_delphi_TEnumArrayOwner.Create;
  ;

  { tw18131.pp }
  tb_nested_fields_delphi_TFoo1.TFoo2.x := 0;
    tb_nested_fields_delphi_TFoo1.TFoo2.Create.Destroy;
    if tb_nested_fields_delphi_TFoo1.TFoo2.x<>1 then
      halt(1);
  ;
end;
{$pop}

{ Case tw13992a.pp }
{$push}

begin
end;
{$pop}

{ Case tw15610.pp }
{$push}
{$ifdef FPC}

{$endif}
begin
end;
{$pop}

{ Case tw16083.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tw16222.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tw18103c.pp }
{$push}

begin
end;
{$pop}

{ Case tw20421.pp }
{$push}

begin

end;
{$pop}

{ Case tw21051.pp }
{$push}

{$H+}
begin
  tw21051_Test;
end;
{$pop}

{ Case tw22329.pp }
{$push}

begin
  tw22329_Obj := TObject.Create;
  try
    tw22329_Obj.SayHello('FPC');
  finally
    tw22329_Obj.Free;
  end;
end;
{$pop}

{ Case tw22792.pp }
{$push}

begin
end;
{$pop}

{ Case tw22796.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw24071.pp }
{$push}

begin
end;
{$pop}

{ Case tw24072.pp }
{$push}

begin
end;
{$pop}

{ Case tw24285.pp }
{$push}

{$H+}
begin

end;
{$pop}

{ Case tw24458.pp }
{$push}

begin

end;
{$pop}

{ Case tw24865.pp }
{$push}

begin
end;
{$pop}

{ Case tw25044.pp }
{$push}
{$IFDEF FPC}

{$ENDIF}
begin
end;
{$pop}

{ Case tw27750a.pp }
{$push}

begin
end;
{$pop}

{ Case tw30202.pp }
{$push}

{$POINTERMATH ON}
begin
  SetLength(tw30202_arri, 4);
  tw30202_arri[0] := 4;
  tw30202_arri[1] := 2;
  tw30202_arri[2] := 6;
  tw30202_arri[3] := 1;
  SetLength(tw30202_arrs, 4);
  tw30202_arrs[0] := 'World';
  tw30202_arrs[1] := 'Alpha';
  tw30202_arrs[2] := 'Hello';
  tw30202_arrs[3] := 'Foo';
  tw30202_TArray.QuickSort<LongInt>(tw30202_arri, Low(tw30202_arri), High(tw30202_arri));
  tw30202_TArray.QuickSort<String>(tw30202_arrs, Low(tw30202_arrs), High(tw30202_arrs));
end;
{$pop}

{ Case tw30534b.pp }
{$push}

begin
  tw30534b_x := nil;
  tw30534b_x := 1;
  if tw30534b_x = nil then ;
  if tw30534b_x = 1 then ;
end;
{$pop}

{ Case tw41062.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw41184.pp }
{$push}

{$warn 6058 off}
begin
end;
{$pop}

{ Case tw41516b.pp }
{$push}

begin
end;
{$pop}

{ Case tw8777f.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tw8777f_p := @tw8777f_c.f;
end;
{$pop}

{ Case tw8777g.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tw8777g_p := @tw8777g_c.prop;
end;
{$pop}

{ Case tw8777i.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tw8777i_p := @tw8777i_c.prop;
end;
{$pop}

end.
