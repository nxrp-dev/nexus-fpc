{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb_forward_classes_delphi.pas }
{$push}
{ Delphi self-references, forward class references and nested class declarations. }

{ tw0738.pas }


type
 (*
 {$IFDEF FPC}
 SomeClass = class; { this line shouldn't be necessary }
 {$ENDIF}
 *)

 tb_forward_classes_delphi_SomeClass = class
  SomeMember:tb_forward_classes_delphi_SomeClass;
 end;

{ tw0739.pas }


type
(* {$IFDEF FPC}
  y = class; { shouldn't be necessary }
{$ENDIF} *)
  tb_forward_classes_delphi_x = class of tb_forward_classes_delphi_y;
  tb_forward_classes_delphi_y = class
   z:Boolean;
  end;

{ tw17945.pas }

type
  tb_forward_classes_delphi_TFoo = class
  public
    type
      TEnumerator = object
      private
        FFoo: tb_forward_classes_delphi_TFoo; //Was error: Illegal expression
      end;
  end;

{ tw18086.pas }


type
  tb_forward_classes_delphi_TFoo1 = class; //Error: Type "TFoo1" is not completely defined

  tb_forward_classes_delphi_TFoo2 = class //it compiles if TFoo2 is removed
  type
    TFoo3 = class
    end;
  end;

  tb_forward_classes_delphi_TFoo1 = class
  end;


{$pop}

{ Case tb_method_names_delphi.pas }
{$push}
{ Delphi method name shadowing and abbreviated constructor implementations. }

{ tb0325.pas }

type
   tb_method_names_delphi_tc1 = class
      l : longint;
      property p : longint read l;
   end;

   tb_method_names_delphi_tc2 = class(tb_method_names_delphi_tc1)
      { in Delphi mode }
      { parameters can have the same name as properties }
      procedure p1(p : longint);
   end;

procedure tb_method_names_delphi_tc2.p1(p : longint);

  begin
  end;

{ tb0373.pas }
{$ifdef fpc}{$endif}
type
   tb_method_names_delphi_tmyinterface = interface
      procedure p(p : longint); // Delphi allows this
   end;

{ tb0456.pas }
{$ifdef fpc}{$endif}

type
  tb_method_names_delphi_c=class
   function Byte: Byte; virtual; abstract;
   function P(b: Byte):boolean; virtual; abstract;
  end;

{ tb0538.pas }

type
  tb_method_names_delphi_to1 = class
    procedure p1;
    procedure p2;
  end;

procedure tb_method_names_delphi_to1.p1;
  begin
  end;

procedure tb_method_names_delphi_to1.p2;
  const
    p1 : pointer = nil;
  begin
  end;

{ tb0518.pas }

type
  tb_method_names_delphi_tc = class
    constructor create(const n: ansistring);
  end;

constructor tb_method_names_delphi_tc.create;
begin
  if (n <> 'abc') then halt(1);
end;


{$pop}

{ Case tb_static_procvars_delphi.pas }
{$push}
{ Delphi static class method assignments from instance and global scopes. }

{ tw30936a.pas }


type
  tb_static_procvars_delphi_TImplicitStaticProc = class
  public type
    TProcedure = procedure;
  private
    class procedure MyProc; static;
  public
    constructor Create;
  end;

{ TTest }

constructor tb_static_procvars_delphi_TImplicitStaticProc.Create;
var
  tb_static_procvars_delphi_aProc: TProcedure;
begin
  tb_static_procvars_delphi_aProc := MyProc;
  tb_static_procvars_delphi_aProc;
end;

class procedure tb_static_procvars_delphi_TImplicitStaticProc.MyProc;
begin
  Writeln('OK');
end;

{ tw30936c.pas }


type
  tb_static_procvars_delphi_TExplicitStaticProc = class
  public type
    TProcedure = procedure;
  private
    class procedure MyProc; static;
  public
    constructor Create;
  end;

{ TTest }

constructor tb_static_procvars_delphi_TExplicitStaticProc.Create;
begin
end;

class procedure tb_static_procvars_delphi_TExplicitStaticProc.MyProc;
begin
  Writeln('OK');
end;

var
  tb_static_procvars_delphi_aProc: TProcedure;


{$pop}

{ Case tw0793.pas }
{$push}



type

tw0793_TMyObject = class
  public
    constructor Create; virtual;
    constructor Init;
end;

var
  tw0793_M: tw0793_TMyObject;


constructor tw0793_TMyObject.Create;
begin
  Writeln('Now executing  TmyObject.Create');
end;

constructor tw0793_TMyObject.Init;
begin
  Create;
  Writeln('Now finishing the INIT constructor.');
end;


{$pop}

{ Case tw10002.pas }
{$push}


{$ifdef fpc}

{$endif}

type tw10002__ulong = Cardinal;

tw10002_TCCC = class
public
    constructor Create(Size: tw10002__ulong=0); overload;
    constructor Create(Buffer: Pointer); overload;
end;

constructor tw10002_TCCC.Create(Size: tw10002__ulong);
begin
	inherited Create;
	WriteLn('TCCC.Create(Size: _ulong) called.');
end;

constructor tw10002_TCCC.Create(Buffer: Pointer);
begin
 halt(1);
end;

var tw10002_c: tw10002_TCCC;
tw10002_l: longint;

{$pop}

{ Case tw10320.pas }
{$push}




type
  tw10320_TRgb = record
    R,G,B : Byte;
  end;

  tw10320_TRgbArray = array of tw10320_TRgb;

  tw10320_TSomeClass = class
    tw10320_a: tw10320_TRgbArray;
    function GetP(Index : integer) : Pointer;
    constructor create;
  public
    property P[Index: Integer]: Pointer read GetP;
  end;

var tw10320_a : tw10320_TRgbArray;
    tw10320_c : tw10320_TSomeClass;

constructor tw10320_tsomeclass.create;
begin
  setlength(tw10320_a,2);
  tw10320_a[0].r:=1;
  tw10320_a[0].g:=2;
  tw10320_a[0].b:=3;
  tw10320_a[1].r:=4;
  tw10320_a[1].g:=5;
  tw10320_a[1].b:=6;
end;

function tw10320_TSomeClass.GetP(Index : integer) : Pointer;
begin
  result := pointer(tw10320_a);
end;


{$pop}

{ Case tw10727.pas }
{$push}
{$ifdef fpc} {$endif}
Type
   tw10727_TStringBuilder = Class
    function Insert(Index: Integer; const Value: string; Count: Integer = 1): tw10727_TStringBuilder; overload;
    function Insert(Index: Integer; const Value: array of Char): tw10727_TStringBuilder; overload;
end;

function tw10727_TStringBuilder.Insert(Index: Integer; const Value: array of Char): tw10727_TStringBuilder;
begin
 writeln('Called TStringBuilder.Insert(Index: Integer; const Value: array of Char): TStringBuilder;');
 result:=nil;
end;

function tw10727_TStringBuilder.Insert(Index: Integer; const Value: string; Count: Integer): tw10727_TStringBuilder;
begin
  writeln('Called TStringBuilder.Insert(Index: Integer; const Value: string; Count: Integer): TStringBuilder;');
 result:=nil;
end;

var tw10727_sb : tw10727_TSTringBuilder;


{$pop}

{ Case tw12756.pas }
{$push}

{$M+}

type
  tw12756_TFooR = object { put "record" here and it works. }
    Thing : integer;
  end;

  tw12756_TFoo = class
  private
    fRecord : tw12756_TFooR;
  published
    property Thing : integer read fRecord.Thing;
  end;

var
  tw12756_fFoo : tw12756_TFoo;

{$pop}

{ Case tw15391a.pas }
{$push}
{$ifdef fpc}

{$endif}

{$r+}

type
  tw15391a_FuncA = function : Integer of object;
  tw15391a_ObjA = class
    function Func1: Integer;
    procedure Proc1(const Arr: Array of tw15391a_FuncA);
  end;

var tw15391a_A : tw15391a_ObjA;

procedure tw15391a_test(fa: tw15391a_funca);
begin
  if fa<>tw15391a_a.func1 then
    halt(2);
end;

function tw15391a_ObjA.Func1: Integer;
begin
  Result := 1;
end;

procedure tw15391a_ObjA.Proc1(const Arr: Array of tw15391a_FuncA);
begin
  if (low(arr)<>0) or
     (high(arr)<>1) or
     assigned(arr[0]) or
     (arr[1]<>tw15391a_a.func1) then
    halt(1);
end;


{$pop}

{ Case tw18706.pas }
{$push}


type

  tw18706_TExecProc = procedure of object;

  tw18706_TA = class
  public
    procedure P1; overload; virtual;
    procedure P1(const param: boolean); overload; virtual;
  end;

  tw18706_TB = class(tw18706_TA)
  public
    procedure P1(const param: boolean); override;
  end;

procedure tw18706_ShowProc(p: tw18706_TExecProc);
begin
  p;
end;

procedure tw18706_TA.P1;
begin
  writeln('1');
end;

procedure tw18706_TA.P1(const param: boolean);
begin
  writeln('2');
  halt(1);
end;

procedure tw18706_TB.P1(const param: boolean);
begin
  writeln('3');
  halt(2);
end;

var
  tw18706_a: tw18706_TA;
  tw18706_b: tw18706_TB;

{$pop}

{ Case tw22154.pas }
{$push}




type
  tw22154_TWrapper<T> = class
    procedure Z;
  end;

procedure tw22154_TWrapper<T>.Z;
const
  A0: array [0..0] of Integer = (0);     { OK }
  A1: array [0..1] of Integer = (0, 1);  { Comma not expected }
begin
end;


{$pop}

{ Case tw23212.pas }
{$push}




Type

  tw23212_TSomeRec1 = Packed Record
    A : Integer; // Changing this to Byte oddly enough will work, but Integer does not..
    B : Byte;
  End; { Record }

  tw23212_TSomeRecord = Packed Record
    Case x : Cardinal OF
      0 : (A : tw23212_TSomeRec1);
  End; { Record }

  tw23212_TBaseList<T> = Class

    Private

      // Fields //

      FItems : Array OF T;

    Protected

      // Methods //

      Function  GetItem(Index : Integer) : T; Virtual;
      Procedure SetItem(Index : Integer; Const Value : T); Virtual;

    Public

      // Methods //

      Constructor Create;
      Destructor  Destroy; Override;

      // Properties //

      Property Items[Index : Integer] : T Read GetItem Write SetItem; Default;

  End; { Class }

  tw23212_TSomeList = tw23212_TBaseList<tw23212_TSomeRecord>;

  tw23212_TSomeClass = Class

    Private

      // Fields //

      FItems : tw23212_TSomeList;

    Public

      // Methods //

      Constructor Create;
      Destructor  Destroy; Override;

      Procedure GetRec(Index : Integer; Out tw23212_Rec : tw23212_TSomeRecord);
      Procedure SetRec(Index : Integer; Const tw23212_Rec : tw23212_TSomeRecord);

  End; { Class }

//****************************************************************************//
//****************************************************************************//
//********** TBaseList Class *************************************************//
//****************************************************************************//
//****************************************************************************//

//========== Protected Methods ===============================================//

Function  tw23212_TBaseList<T>.GetItem(Index : Integer) : T;
Begin
  Result := FItems[Index];
End; { Function }

Procedure tw23212_TBaseList<T>.SetItem(Index : Integer; Const Value : T);
Begin
  IF Index >= High(FItems) Then SetLength(FItems, Index + 1);
  FItems[Index] := Value;
End; { Procedure }

//========== Public Methods ==================================================//

Constructor tw23212_TBaseList<T>.Create;
Begin
  Inherited;
End; { Constructor }

Destructor  tw23212_TBaseList<T>.Destroy;
Begin
  Finalize(FItems);
  Inherited;
End; { Destructor }

//****************************************************************************//
//****************************************************************************//
//********** TSomeClass Class ************************************************//
//****************************************************************************//
//****************************************************************************//

//========== Public Methods ==================================================//

Constructor tw23212_TSomeClass.Create;
Begin
  Inherited;
  FItems := tw23212_TSomeList.Create;
End; { Constructor }

Destructor  tw23212_TSomeClass.Destroy;
Begin
  FItems.Free;
  Inherited;
End; { Destructor }

Procedure tw23212_TSomeClass.GetRec(Index : Integer; Out tw23212_Rec : tw23212_TSomeRecord);
Begin
  tw23212_Rec := FItems[Index];
End; { Procedure }

Procedure tw23212_TSomeClass.SetRec(Index : Integer; Const tw23212_Rec : tw23212_TSomeRecord);
Begin
  FItems[Index] := tw23212_Rec;
End; { Procedure }

//========== Global Variables ================================================//

Var

  tw23212_C   : tw23212_TSomeClass;
  tw23212_Rec : tw23212_TSomeRecord;


{$pop}

{ Case tw23270.pas }
{$push}


type
  tw23270_TSmallWrapper<TValue> = record
    Value: TValue;
  end;

  tw23270_TWrapper<T> = class
  strict private
    class var FSmallWrapper: tw23270_TSmallWrapper<PInteger>;
  public
    class procedure Z; static;
  end;

class procedure tw23270_TWrapper<T>.Z;
begin
  FSmallWrapper.Value := New(PInteger);
  Dispose(FSmallWrapper.Value);  { Error: pointer type expected, but ... }
end;


{$pop}

{ Case tw23299.pas }
{$push}


type
  tw23299_TSmallWrapper<TValue> = record
    Value: TValue;
  end;

  tw23299_TWrapper<T> = class
  strict private
    class var FSmallWrapper: tw23299_TSmallWrapper<Integer>;
  public
    class procedure Z; static;
  end;

class procedure tw23299_TWrapper<T>.Z;
begin
  FSmallWrapper.Value := 0;
  Inc(FSmallWrapper.Value);
  Dec(FSmallWrapper.Value);
  FSmallWrapper.Value := Succ(FSmallWrapper.Value);
  FSmallWrapper.Value := Pred(FSmallWrapper.Value);
end;


{$pop}

{ Case tw23568.pas }
{$push}




type
  tw23568_TInteger32Boolean = record
  public
    tw23568_Value: Integer;

    class operator Implicit(const Operand: tw23568_TInteger32Boolean): Boolean;
  end;

{ TInteger32Boolean }

class operator tw23568_TInteger32Boolean.Implicit(const Operand: tw23568_TInteger32Boolean): Boolean;
begin
  Result := Operand.tw23568_Value <> 0;
  WriteLn('In TInteger32Boolean.Implicit()');
end;

var
  tw23568_Value:        tw23568_TInteger32Boolean;
  tw23568_Intermediate: Boolean;


{$pop}

{ Case tw25030.pas }
{$push}




type

  { TInteger32Boolean }

  tw25030_TInteger32Boolean = record
  public
    Value: Integer;
    const
      FALSE = 0;
      TRUE = 1;

    class operator Implicit(const Operand: tw25030_TInteger32Boolean): Boolean;
    class operator Implicit(Operand: Boolean): tw25030_TInteger32Boolean;
    class operator LogicalNot(const Operand: tw25030_TInteger32Boolean): tw25030_TInteger32Boolean;
  end;

{ TInteger32Boolean }

class operator tw25030_TInteger32Boolean.Implicit(const Operand: tw25030_TInteger32Boolean): Boolean;
begin
  Result := Operand.Value <> FALSE;
end;

class operator tw25030_TInteger32Boolean.Implicit(Operand: Boolean): tw25030_TInteger32Boolean;
begin
  if Operand then
    Result.Value := TRUE
  else
    Result.Value := FALSE;
end;

class operator tw25030_TInteger32Boolean.LogicalNot(const Operand: tw25030_TInteger32Boolean): tw25030_TInteger32Boolean;
begin
  if Operand then
    Result.Value := FALSE
  else
    Result.Value := TRUE;
end;

var
  tw25030_IntegerBoolean: tw25030_TInteger32Boolean;


{$pop}

{ Case tw25043.pas }
{$push}


{$IFDEF FPC}
  
{$ENDIF}

const
  tw25043_TestValue = 30061978;

type
  tw25043_TDescendant = class(TObject)
  public
    function    GetValue(): Integer;
  end;

  tw25043_TCollection<E: class> = class(TObject)
  protected
    Value: E;

    function    GetElements(Index: Integer): E;

  public
    property    Element: E read Value;
    property    Elements[Index: Integer]: E read GetElements; default;
  end;

  tw25043_TDescendantCollection<E: tw25043_TDescendant> = class(tw25043_TCollection<E>)
  public
    procedure   TestValues();
  end;

{ TDescendant }

function tw25043_TDescendant.GetValue(): Integer;
begin
  Result := tw25043_TestValue;
end;

{ TDescendantCollection<E> }

procedure tw25043_TDescendantCollection<E>.TestValues();
begin
  if Value.GetValue() <> tw25043_TestValue then
    Halt(1);

  if Element.GetValue() <> tw25043_TestValue then
    Halt(1);

  if GetElements(0).GetValue() <> tw25043_TestValue then
    Halt(1);

  if Elements[0].GetValue() <> tw25043_TestValue then
    Halt(1);

  if Self[0].GetValue() <> tw25043_TestValue then
    Halt(1);
end;

{ TCollection<E> }

function tw25043_TCollection<E>.GetElements(Index: Integer): E;
begin
  Result := Value;
end;

var
  tw25043_Collection: tw25043_TDescendantCollection<tw25043_TDescendant>;
  tw25043_Descendant: tw25043_TDescendant;


{$pop}

{ Case tw25101.pas }
{$push}


{$IFDEF FPC}
  
{$ENDIF}

type
  tw25101_TTest = class(TObject)
  public
    procedure Test(); virtual; deprecated 'Do not use this method'; abstract;
  end;


{$pop}

{ Case tw25602.pas }
{$push}


type
  tw25602_TA = class
    const C = 1;
  end;

  tw25602_TB<T> = object
    procedure Foo;
  end;

procedure tw25602_TB<T>.Foo;
var
  // X: array[0..T.C] of byte = (0); // Error: Expected another 1 array elements
  tw25602_X: array[0..T.C] of byte = (0, 2); // Fatal: Syntax error, ")" expected but "," found
begin
  if high(tw25602_x)<>1 then
    halt(1);
  writeln('ok');
end;

var
  tw25602_x: tw25602_TB<tw25602_TA>;

{$pop}

{ Case tw25603.pas }
{$push}


type
  tw25603_TA = class
    const C = 1;
  end;

  tw25603_TB<T> = class
    procedure Foo;
  end;

procedure tw25603_TB<T>.Foo;
var
  i: Integer = 0;
begin
  // i := i + T.C; // <- is ok
  Inc(i, T.C); // Error: Incompatible types: got "untyped" expected "LongInt"
  if i<>1 then
    halt(1);
end;
var
  tw25603_B : tw25603_TB<tw25603_TA>;

{$pop}

{ Case tw2626.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2626 }
{ Submitted by "Jose Santos" on  2003-08-10 }
{ e-mail: jcas@netcabo.pt }


type
  tw2626_TBug = class
         public
            constructor Create; overload;
            constructor Create(var S: String); overload;
         end;

  constructor tw2626_TBug.Create;
  begin
  end;

  constructor tw2626_TBug.Create(var S: String);
  begin
    S:='Test';
  end;

var
  tw2626_Bug: tw2626_TBug;


{$pop}

{ Case tw2705.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2705 }
{ Submitted by "Johannes Berg" on  2003-10-01 }
{ e-mail: johannes -at- sipsolutions -dot- de }




type
  tw2705_TClassA = class
  end;
  tw2705_TClassB = class
    FA: tw2705_TClassA;
    property a: tw2705_TClassA read FA write FA default nil;
  end;


{$pop}

{ Case tw2721.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2721 }
{ Submitted by "marcov" on  2003-10-07 }
{ e-mail:  }


type
  tw2721_TIntfPersistent = class
  public
    function _Release: Integer; virtual; cdecl;
    end;

  tw2721_t2 = class(tw2721_Tintfpersistent)
    public
     function _Release: Integer; override;
    end;

function tw2721_TIntfPersistent._Release: Integer;
begin
end;

function tw2721_t2._Release: Integer;
begin
end;



{$pop}

{ Case tw2736.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2736 }
{ Submitted by "Johannes Berg" on  2003-10-13 }
{ e-mail: bugs@johannes.sipsolutions.de }



type
  tw2736_TTest1 = class
    FA: Integer;
  private
    property a: Integer read FA write FA;
  end;
  tw2736_TTest2 = class(tw2736_TTest1)
    procedure b(a: Integer);
  end;

procedure tw2736_TTest2.b(a: Integer);
begin
end;


{$pop}

{ Case tw2737.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2737 }
{ Submitted by "Johannes Berg" on  2003-10-13 }
{ e-mail: bugs@johannes.sipsolutions.de }



type
  tw2737_TTest1 = class
    FA: Integer;
    property a: Integer read FA write FA;
  end;
  tw2737_TTest2 = class(tw2737_TTest1)
    procedure b(aa: Integer);
  end;

procedure tw2737_TTest2.b(aa: Integer);
var a: Integer;
begin
end;


{$pop}

{ Case tw2829.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2829 }
{ Submitted by "marco (the gory bugs department)" on  2003-12-04 }
{ e-mail:  }
{$ifdef fpc}{$endif}

type
  tw2829_TFloat64     = Double;
  tw2829_TFloat64Func = function: tw2829_TFloat64;

  tw2829_TExprVirtMachOp = class end;
  tw2829_TExprVirtMachNode= class end;
  tw2829_TExprCallFloat64VmOp = class(tw2829_TExprVirtMachOp)
  private
    FFunc: tw2829_TFloat64Func;
  public
    constructor Create(AFunc: tw2829_TFloat64Func);
  end;


    tw2829_TExprCallFloat64VmNode = class(tw2829_TExprVirtMachNode)
  private
    FFunc: tw2829_TFloat64Func;
    FExprVmCode : tw2829_TExprCallFloat64VMOp;
  public
    procedure GenCode;
  end;

constructor tw2829_TExprCallFloat64VmOp.Create(AFunc:tw2829_TFloat64Func);

begin

end;

procedure tw2829_TExprCallFloat64VmNode.GenCode;
begin
  FExprVmCode := tw2829_TExprCallFloat64VmOp.Create(FFunc);
end;


{$pop}

{ Case tw30357.pas }
{$push}




type
  tw30357_TMyRecord = record
  private
    class function GetEmpty: tw30357_TMyRecord; static;
  public
    class property Empty: tw30357_TMyRecord read GetEmpty;
  private
    FData: IInterface;
  end;

class function tw30357_TMyRecord.GetEmpty: tw30357_TMyRecord; static;
begin
end;

procedure tw30357_Main2(Sender: TObject);
var
  v1: PtrUInt;
begin
  v1 := 42;
end;

procedure tw30357_Main(Sender: TObject);
var
  v1: tw30357_TMyRecord;
begin
  if v1.FData <> nil then
    Halt(1);
end;


{$pop}

{ Case tw3255.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3255 }
{ Submitted by "Patrick Dietrich" on  2004-08-17 }
{ e-mail: patrick.dietrich@informatik.uni-ulm.de }




type
  tw3255_TProc = procedure (Sender: TClass) of object;

  tw3255_TTest = class
  public
    class procedure foo;
    class procedure bar(Sender: TClass);
    class procedure baz(proc: tw3255_TProc);
  end;

class procedure tw3255_TTest.foo;
begin
  baz(bar);
end;

class procedure tw3255_TTest.bar;
begin
  writeln('hello world');
end;

class procedure tw3255_TTest.baz;
begin
  proc(self);
end;


{$pop}

{ Case tw3506.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3506 }
{ Submitted by "Frank Kintrup" on  2005-01-04 }
{ e-mail: frank.kintrup@gmx.de }


type
  tw3506_TEnumType = (tw3506_enum0, tw3506_enum1, tw3506_enum2);

type
  tw3506_TTestClass = class (TObject)
  private
    function GetPropValue(
      nIndex : tw3506_TEnumType) : Integer;

  public
    property Prop0 : Integer index tw3506_enum0
      read GetPropValue;
  end;

function tw3506_TTestClass.GetPropValue(
  nIndex : tw3506_TEnumType) : Integer;
begin
  Result := Integer(nIndex);
end;


{$pop}

{ Case tw3564.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3564 }
{ Submitted by "Patrick Dietrich" on  2005-01-17 }
{ e-mail: patrick.dietrich@SPAM.informatik.ME.uni-ulm.NOT.de }



type
   tw3564_StringArray = array of string;

   tw3564_TestClass = class(TObject)
   public
      FArr : tw3564_StringArray;
      function getArr: tw3564_StringArray;
      function getCopy: tw3564_StringArray;
      constructor create;
      property arr : tw3564_StringArray read getArr;
   end;

function tw3564_TestClass.getArr: tw3564_StringArray;
begin
   result := self.FArr;
end;

function tw3564_TestClass.getCopy: tw3564_StringArray;
begin
   Result := Copy(arr, 0, Length(arr)-1);
end; { getCopy }

constructor tw3564_TestClass.create;
begin
   setLength( Farr, 3);

   Farr[0] := 'one';
   Farr[1] := 'two';
   Farr[2] := 'three';
end;


{$pop}

{ Case tw40019.pas }
{$push}


{$H+}

type
  tw40019_TArray4IntegerType = array[0..3] of Longint;

  tw40019_TPoint = record
       X : Longint; Y : Longint;
  end;

  tw40019_TRect = record
       case Longint of
         0: (Left,Top,Right,Bottom : Longint);
         1: (TopLeft,BottomRight : tw40019_TPoint);
         2: (Vector:tw40019_TArray4IntegerType);
  end;

  tw40019_THead=class
  end;

  tw40019_TDrawCellInfo=class
      m1,m2:integer;
  end;

  tw40019_TCanvas=class
    procedure dosmth(arect:tw40019_TRect);
  end;

  tw40019_TCellState=set of (tw40019_A,tw40019_B,tw40019_C,tw40019_D);
  tw40019_TDrawCellState=set of (tw40019_xA,tw40019_xB,tw40019_xC,tw40019_xD);

  { TGridObject }

  tw40019_TGridObject=class
    fCellInfo:tw40019_TDrawCellInfo;
    procedure GetCellInfo(ACol, ARow:integer; AState:tw40019_TCellState; AColHead, ARowHead:tw40019_THead; ACellInfo:tw40019_TDrawCellInfo);
    procedure DrawCell(APrevCol, APrevRow, ACol, ARow, ANextCol, ANextRow: Integer;
      AColHead, ARowHead: tw40019_THead;
      AState: tw40019_TCellState; ARect: tw40019_TRect; DrawSelection: Boolean; ACanvas: tw40019_TCanvas);overload;virtual;
    procedure DrawCell(CellInfo: tw40019_TDrawCellInfo; APrevCol, APrevRow, ACol, ARow, ANextCol, ANextRow: Integer;
      AColHead, ARowHead: tw40019_THead;
      AState: tw40019_TCellState; ARect: tw40019_TRect; DrawSelection: Boolean; ACanvas: tw40019_TCanvas);

  end;

  procedure tw40019_TGridObject.GetCellInfo(ACol, ARow: integer; AState: tw40019_TCellState;
    AColHead, ARowHead: tw40019_THead; ACellInfo: tw40019_TDrawCellInfo);
  begin
    AColHead:=ARowHead;
    ACellInfo.m1:=ACellInfo.m2;
    end;

  procedure tw40019_TGridObject.DrawCell(APrevCol, APrevRow, ACol, ARow, ANextCol, ANextRow: Integer;
      AColHead, ARowHead: tw40019_THead;
      AState: tw40019_TCellState; ARect: tw40019_TRect; DrawSelection: Boolean; ACanvas: tw40019_TCanvas);
var
  ACellInfo: tw40019_TDrawCellInfo;
begin
  if ARect.left<>1 then
    halt(1);
  if ARect.right<>2 then
    halt(2);
  if ARect.top<>3 then
    halt(3);
  if ARect.bottom<>4 then
    halt(4);
  ACellInfo := fCellInfo;
  GetCellInfo(ACol, ARow, AState, AColHead, ARowHead, ACellInfo);
  if not Assigned(ACellInfo) then
    ACellInfo := fCellInfo;
  DrawCell(ACellInfo,APrevCol,APrevRow,ACol,ARow,ANextCol,ANextRow,
    AColHead,ARowHead,AState,ARect,false,nil);
end;

procedure tw40019_TGridObject.DrawCell(CellInfo: tw40019_TDrawCellInfo; APrevCol, APrevRow, ACol, ARow, ANextCol, ANextRow: Integer;
      AColHead, ARowHead: tw40019_THead;
      AState: tw40019_TCellState; ARect: tw40019_TRect; DrawSelection: Boolean; ACanvas: tw40019_TCanvas);
var
  //CellInfo: TDrawCellInfo;
  FrameFlags, FrameFlagsOuter, RegionIndex: Integer;



begin
  if drawSelection then Acanvas.dosmth(Arect);
end;

procedure tw40019_TCanvas.dosmth(arect:tw40019_TRect);
begin
    if arect.left<>1 then
      halt(21);
    if arect.right<>2 then
      halt(22);
    if arect.top<>3 then
      halt(23);
    if arect.bottom<>4 then
      halt(24);
  arect.left:=arect.top+arect.right
end;

var tw40019_go:tw40019_TGridObject;
    tw40019_r: tw40019_TRect;

{$pop}

{ Case tw40770.pas }
{$push}


{$ifdef FPC}{$endif}

type
  tw40770_Wrapper<T> = record
    Value: T;
    function GetValue: T;
  end;

  tw40770_Utils = record
  public
    class function Method1<T>(): tw40770_Wrapper<T>; static;
    class function Method2<T>(): tw40770_Wrapper<T>; static;
  end;

function tw40770_Wrapper<T>.GetValue: T;
begin
  Result := Value;
end;

var
  tw40770_Log: string;
procedure tw40770_AppendToLog(const S: string);
begin
  if tw40770_Log = '' then tw40770_Log := S else tw40770_Log := tw40770_Log + ' ' + S;
end;

class function tw40770_Utils.Method1<T>(): tw40770_Wrapper<T>;
begin
  if TypeInfo(T) = TypeInfo(Integer) then
    tw40770_AppendToLog('Method1<Integer>')
  else if TypeInfo(T) = TypeInfo(string) then
     tw40770_AppendToLog('Method1<string>')
  else
    Halt(1);
end;

class function tw40770_Utils.Method2<T>(): tw40770_Wrapper<T>;
begin
  Result := Method1<T>();
end;


{$pop}

{ Case tw8145.pas }
{$push}


{$IFDEF FPC}
  
{$ENDIF}

var
  tw8145_l: longint;

type
  tw8145_TMyObject = class
    class procedure Foo;
    class procedure Foo2; virtual;
  end;

  tw8145_TMyClass = class of tw8145_TMyObject;

  tw8145_TMyDerivedObject = class(tw8145_TMyObject)
    class procedure Foo2; override;
  end;

  tw8145_TMyDerivedClass = class of tw8145_TMyDerivedObject;


  tw8145_TMyObject2 = class
    class procedure Foo3;
  end;
  tw8145_TMyClass2 = class of tw8145_TMyObject2;

  tw8145_TMyDerivedObject2 = class(tw8145_TMyObject2)
  end;
  tw8145_TMyDerivedClass2 = class of tw8145_TMyDerivedObject2;


class procedure tw8145_TMyObject.Foo;
begin
  if (tw8145_l <> 1) then
    halt(1);
end;

class procedure tw8145_TMyObject.Foo2;
begin
  if (tw8145_l <> 2) then
    halt(2);
end;


class procedure tw8145_TMyDerivedObject.Foo2;
begin
  if (tw8145_l <> 3) then
    halt(3);
end;


class procedure tw8145_TMyObject2.Foo3;
begin
  if (tw8145_l <> 4) then
    halt(4);
end;


var
  tw8145_MyClassA : tw8145_TMyClass = tw8145_TMyObject;
  tw8145_MyClassB : tw8145_TMyClass = tw8145_TMyDerivedObject;
  tw8145_MyDerivedClass : tw8145_TMyDerivedClass = tw8145_TMyDerivedObject;

  tw8145_MyClassA2 : tw8145_TMyClass2 = tw8145_TMyObject2;
  tw8145_MyClassB2 : tw8145_TMyClass2 = tw8145_TMyDerivedObject2;
  tw8145_MyDerivedClass2 : tw8145_TMyDerivedClass2 = tw8145_TMyDerivedObject2;


{$pop}

{ Case tw8810.pas }
{$push}
{$ifdef fpc}

{$endif}

{$r+}

CONST tw8810_MaxBitmaps=129;

TYPE  tw8810_tbitmap = longint;
      tw8810_TBack =CLASS
                 constructor create;
                 PRIVATE
                   FBitmaps :ARRAY [0..tw8810_MaxBitmaps] OF tw8810_TBitmap;

                 PUBLIC
                   PROPERTY Bitmap :tw8810_TBitmap READ FBitmaps[0];
                   PROPERTY LightBitmap :tw8810_TBitmap READ FBitmaps[1];
                   PROPERTY ShadowBitmap:tw8810_TBitmap READ FBitmaps[2];
            end;

constructor tw8810_tback.create;
var
  i: longint;
begin
  for i := low(fbitmaps) to high(fbitmaps) do
    fbitmaps[i] := i;
end;

var
  tw8810_b: tw8810_tback;

{$pop}

begin

{ Case tb_forward_classes_delphi.pas }
{$push}

{$IFDEF FPC}
{$ENDIF}

{$IFDEF FPC}
{$ENDIF}


begin

end;
{$pop}

{ Case tb_method_names_delphi.pas }
{$push}

{$ifdef fpc}

{$endif}
{$ifdef fpc}

{$endif}


begin
  { tb0518.pas }
  tb_method_names_delphi_tc.create('abc');
end;
{$pop}

{ Case tb_static_procvars_delphi.pas }
{$push}


begin
  { tw30936a.pas }
  tb_static_procvars_delphi_TImplicitStaticProc.Create;
  ;

  { tw30936c.pas }
  tb_static_procvars_delphi_aProc := tb_static_procvars_delphi_TExplicitStaticProc.MyProc;
    tb_static_procvars_delphi_aProc;
  ;
end;
{$pop}

{ Case tw0793.pas }
{$push}

begin
  tw0793_M := tw0793_TMyObject.Init;
end;
{$pop}

{ Case tw10002.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
	tw10002_c := tw10002_TCCC.Create(20);
	tw10002_c := tw10002_TCCC.Create(tw10002_l);
end;
{$pop}

{ Case tw10320.pas }
{$push}

begin
  tw10320_c := tw10320_TSomeClass.Create;
  tw10320_a := tw10320_TRgbArray(tw10320_c.P[1]); // Fatal: Internal error 2006111510
  if (length(tw10320_a)<>2) or
     (tw10320_a[0].r<>1) or
     (tw10320_a[0].g<>2) or
     (tw10320_a[0].b<>3) or
     (tw10320_a[1].r<>4) or
     (tw10320_a[1].g<>5) or
     (tw10320_a[1].b<>6) then
    halt(1);
  tw10320_c.free;
end;
{$pop}

{ Case tw10727.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tw10727_sb:=tw10727_TStringBuilder.Create;
  tw10727_sb.Insert(0, '0 ');
  tw10727_sb.Free;
end;
{$pop}

{ Case tw12756.pas }
{$push}

{$M+}
begin
  tw12756_fFoo := tw12756_TFoo.Create;
  tw12756_fFoo.fRecord.Thing:=123;
  if (tw12756_fFoo.Thing <> 123) then
    halt(1);
  tw12756_fFoo.free;
end;
{$pop}

{ Case tw15391a.pas }
{$push}
{$ifdef fpc}

{$endif}
{$r+}
begin
  tw15391a_A := tw15391a_ObjA.Create;
  tw15391a_A.Proc1([nil,tw15391a_A.Func1]);
  tw15391a_test(tw15391a_a.func1);
  tw15391a_a.free;
end;
{$pop}

{ Case tw18706.pas }
{$push}

begin
  tw18706_a := tw18706_TA.Create;
  tw18706_b := tw18706_TB.Create;

  tw18706_ShowProc(tw18706_a.P1); // compile and execute correctly
  tw18706_ShowProc(tw18706_b.P1); // error on compile !!! but here should be call TA.P1 !!!
end;
{$pop}

{ Case tw22154.pas }
{$push}

begin
end;
{$pop}

{ Case tw23212.pas }
{$push}

Begin

  tw23212_C := tw23212_TSomeClass.Create;

  tw23212_Rec.A.A := 42;
  tw23212_Rec.A.B := 5;

  tw23212_C.SetRec(0, tw23212_Rec);
  tw23212_C.GetRec(0, tw23212_Rec);

  Writeln(tw23212_Rec.A.A, ',', tw23212_Rec.A.B);

  tw23212_C.Free;
  if (tw23212_rec.a.a<>42) or (tw23212_rec.a.b<>5) then
    halt(1);

End;
{$pop}

{ Case tw23270.pas }
{$push}

begin
  tw23270_TWrapper<Byte>.Z;
end;
{$pop}

{ Case tw23299.pas }
{$push}

begin
  tw23299_TWrapper<Byte>.Z;
end;
{$pop}

{ Case tw23568.pas }
{$push}

begin
  // Assign True to TInteger32Boolean
  tw23568_Value.tw23568_Value := 1;

  // If statement using intermediate assignment through Intermediate
  tw23568_Intermediate := tw23568_Value;

  if tw23568_Intermediate then
    WriteLn('True')
  else
    halt(1);

  // If statement should perform implicit type conversion from TInteger32Boolean to Boolean
  if tw23568_Value then
    WriteLn('True')
  else
    halt(2);

  // While statement should perform implicit type conversion as well
  while tw23568_Value do
  begin
    if tw23568_Value.tw23568_Value=0 then
      halt(3);
    tw23568_Value.tw23568_Value := 0;
    WriteLn('While');
  end;

  // Repeat until statement should perform implicit type conversion as well
  repeat
    if tw23568_Value.tw23568_Value=1 then
      halt(4);
    tw23568_Value.tw23568_Value := 1;
    WriteLn('Repeat until');
  until tw23568_Value;
end;
{$pop}

{ Case tw25030.pas }
{$push}

begin
  tw25030_IntegerBoolean := True;
  if tw25030_IntegerBoolean.Value<>1 then
    halt(1);

  if not tw25030_IntegerBoolean then
    halt(2);
end;
{$pop}

{ Case tw25043.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
begin
  tw25043_Descendant := tw25043_TDescendant.Create();

  tw25043_Collection := tw25043_TDescendantCollection<tw25043_TDescendant>.Create();
  tw25043_Collection.Value := tw25043_Descendant;
  tw25043_Collection.TestValues();
  tw25043_Collection.Free();

  tw25043_Descendant.Free();
end;
{$pop}

{ Case tw25101.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
begin
end;
{$pop}

{ Case tw25602.pas }
{$push}

begin
  tw25602_x.Foo;
end;
{$pop}

{ Case tw25603.pas }
{$push}

begin
  tw25603_B:=tw25603_TB<tw25603_TA>.Create;
  tw25603_B.Foo;
  tw25603_B.Free;
  writeln('ok');
end;
{$pop}

{ Case tw2626.pas }
{$push}

begin
  tw2626_Bug:=tw2626_TBug.Create;
end;
{$pop}

{ Case tw2705.pas }
{$push}

begin
end;
{$pop}

{ Case tw2721.pas }
{$push}

begin
end;
{$pop}

{ Case tw2736.pas }
{$push}

begin
end;
{$pop}

{ Case tw2737.pas }
{$push}

begin
end;
{$pop}

{ Case tw2829.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tw30357.pas }
{$push}

begin
  { with Main2 we ensure that the stack area is not 0 }
  tw30357_Main2(nil);
  tw30357_Main(nil);
end;
{$pop}

{ Case tw3255.pas }
{$push}

begin
  tw3255_TTest.foo;
end;
{$pop}

{ Case tw3506.pas }
{$push}

begin
end;
{$pop}

{ Case tw3564.pas }
{$push}

begin
end;
{$pop}

{ Case tw40019.pas }
{$push}

{$H+}
begin
  tw40019_go:=tw40019_TGridObject.Create;
  tw40019_r.left:=1;
  tw40019_r.right:=2;
  tw40019_r.top:=3;
  tw40019_r.bottom:=4;
  tw40019_go.DrawCell(nil,0,0,0,0,0,0,nil,nil,[],tw40019_r,true,tw40019_TCanvas.create);
end;
{$pop}

{ Case tw40770.pas }
{$push}
{$ifdef FPC}

{$endif}
begin
  tw40770_Utils.Method2<Integer>();
  tw40770_Utils.Method2<string>();
  if tw40770_Log <> 'Method1<Integer> Method1<string>' then
    Halt(2);
  WriteLn('OK');
end;
{$pop}

{ Case tw8145.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
begin

  tw8145_l := 1;
  tw8145_TMyObject.Foo; //works in FPC and Delphi
  tw8145_TMyDerivedObject.Foo; //works in FPC and Delphi

  tw8145_MyClassA.Foo; //works in FPC and Delphi
  tw8145_MyClassB.Foo; //works in FPC and Delphi
  tw8145_MyDerivedClass.Foo; //works in FPC and Delphi
  tw8145_TMyClass.Foo; //works only in Delphi
  tw8145_TMyDerivedClass.Foo; //works only in Delphi

  tw8145_l := 2;
  tw8145_TMyObject.Foo2;
  tw8145_MyClassA.Foo2;
  tw8145_TMyClass.Foo2;

  tw8145_l := 3;
  tw8145_TMyDerivedObject.Foo2;
  tw8145_TMyDerivedClass.Foo2;
  tw8145_MyClassB.Foo2;


  tw8145_l := 4;
  tw8145_TMyObject2.Foo3; //works in FPC and Delphi
  tw8145_TMyDerivedObject2.Foo3; //works in FPC and Delphi

  tw8145_MyClassA2.Foo3; //works in FPC and Delphi
  tw8145_MyClassB2.Foo3; //works in FPC and Delphi
  tw8145_MyDerivedClass2.Foo3; //works in FPC and Delphi
  tw8145_TMyClass2.Foo3; //works only in Delphi
  tw8145_TMyDerivedClass2.Foo3; //works only in Delphi

end;
{$pop}

{ Case tw8810.pas }
{$push}
{$ifdef fpc}

{$endif}
{$r+}
begin
  tw8810_b:=tw8810_tback.create;
  if (tw8810_b.Bitmap <> 0) or
     (tw8810_b.LightBitmap <> 1) or
     (tw8810_b.ShadowBitmap <> 2) then
    halt(1);
  tw8810_b.free;
end;
{$pop}

end.
