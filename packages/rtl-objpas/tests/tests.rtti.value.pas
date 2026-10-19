unit tests.rtti.value;

{$mode ObjFPC}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, typinfo,
  Classes, SysUtils, Rtti;

Type
  TTestValueGeneral = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  public
    procedure TestDataSize;
    procedure TestDataSizeEmpty;
    procedure TestReferenceRawData;
    procedure TestReferenceRawDataEmpty;
    procedure TestIsManaged;
    procedure TestCasts;
    procedure TestAssignPointer;
    procedure TestAssignDateTime;
    procedure TestAssignDate;
    procedure TestAssignTime;
  end;

  TTestValueSimple = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    procedure MakeFromOrdinalTObject;
    procedure MakeFromOrdinalSet;
    procedure MakeFromOrdinalString;
    procedure MakeFromOrdinalNil;
  public
    // Moved here from Tests.rtti
    procedure TestIsType;
    procedure TestMakeNil;
    procedure TestMakeObject;
    procedure TestMakeSingle;
    procedure TestMakeDouble;
    procedure TestMakeExtended;
    procedure TestMakeCurrency;
    procedure TestMakeComp;
    procedure TestMakeEnum;
    procedure TestMakeAnsiChar;
    procedure TestMakeWideChar;

    procedure TestMakeNativeInt;
    procedure TestMakeVariant;


    procedure TestMakeGenericNil;
    procedure TestMakeGenericLongInt;
    procedure TestMakeGenericString;
    procedure TestMakeGenericObject;
    procedure TestMakeGenericDouble;
    procedure TestMakeGenericAnsiChar;
    procedure TestMakeGenericWideChar;

    procedure TestFromOrdinal;
    Procedure TestTryCastUnicodeString;

    procedure TestMakeManagedRecord;
    procedure TestMakeStaticArrayOfManagedRecord;
  end;

  { TTestValueArray }

  TTestValueArray = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  public
    procedure TestMakeArrayDynamic;
    procedure TestMakeArrayStatic;
    procedure TestMakeFromArray;
    {$ifdef fpc}
    procedure TestMakeArrayOpen;
    Procedure TestOpenArrayToDyn;
    {$ENDIF}
  end;

  { TTestValueVariant }

  TTestValueVariant = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    FSrc: Variant;
    FValue: TValue;
    FVarRec: TVarRec;
  Public
    Procedure Setup; virtual;
    Procedure TearDown; virtual;
    Procedure DoFromVariant;
    Procedure DoFromVarRec;
    Property Value : TValue Read FValue;
    Property Src : Variant Read FSrc;
    Property VarRec : TVarRec Read FVarRec;
  public
    Procedure TestFromVariantInteger;
    Procedure TestFromVariantBoolean;
    Procedure TestFromVariantSmallInt;
    Procedure TestFromVariantOleStr;
    Procedure TestFromVariantInt64;
    Procedure TestFromVariantQWord;
    Procedure TestFromVariantShortInt;
    Procedure TestFromVariantByte;
    Procedure TestFromVariantWord;
    Procedure TestFromVariantLongWord;
    Procedure TestFromVariantSingle;
    Procedure TestFromVariantDouble;
    Procedure TestFromVariantDate;
    Procedure TestFromVariantDispatch;
    Procedure TestFromVariantError;
    Procedure TestFromVariantUnknown;
    Procedure TestFromVariantCurrency;
    Procedure TestFromVariantString;
    Procedure TestFromVariantUnicodeString;
    Procedure TestFromVarrecInteger;
    Procedure TestFromVarrecBoolean;
    Procedure TestFromVarRecChar;
    Procedure TestFromVarRecExtended;
    Procedure TestFromVarRecString;
    Procedure TestFromVarRecPointer;
    Procedure TestFromVarRecPChar;
    Procedure TestFromVarRecObject;
    Procedure TestFromVarRecClass;
    Procedure TestFromVarRecWideChar;
    Procedure TestFromVarRecPWideChar;
    Procedure TestFromVarRecAnsiString;
    Procedure TestFromVarRecCurrency;
    Procedure TestFromVarRecVariant;
    Procedure TestFromVarRecInterface;
    Procedure TestFromVarRecWideString;
    Procedure TestFromVarRecInt64;
    Procedure TestFromVarRecQWord;
    Procedure TestFromVarRecUnicodeString;
    Procedure TestArrayOfConstToTValue;
    procedure TestCastAnsiString;
{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
    procedure TestCastUnicodeString;
{$endif}
    procedure TestCastWideString;
    procedure TestCastShortString;
  end;

  { TMyUNknown }

  TMyUNknown = Class(TInterfacedObject,IDispatch)
    function GetTypeInfoCount(out count : longint) : HResult;stdcall;
    function GetTypeInfo(Index,LocaleID : longint; out TypeInfo): HResult;stdcall;
    function GetIDsOfNames(const iid: TGUID; names: Pointer; NameCount, LocaleID: LongInt; DispIDs: Pointer) : HResult;stdcall;
    function Invoke(DispID: LongInt;const iid : TGUID; LocaleID : longint; Flags: Word;var params; VarResult,ExcepInfo,ArgErr : pointer) : HResult;stdcall;
  end;


procedure RegistertestsrttivalueTests(ARegistry: TNXTestRegistry);

implementation

uses tests.rtti.types, variants;

{ TTestValueVariant }

procedure TTestValueVariant.Setup;
begin

  FValue:=Default(TValue);
  FSrc:=unassigned;
end;

procedure TTestValueVariant.TearDown;
begin
  FValue:=Default(TValue);
  FSrc:=unassigned;

end;

procedure TTestValueVariant.DoFromVariant;
begin
  FValue:=TValue.FromVariant(Src);
end;

procedure TTestValueVariant.DoFromVarRec;
begin
  FValue:=TValue.FromVarRec(FVarRec);
end;

procedure TTestValueVariant.TestFromVarrecInteger;
begin
  FVarrec.VType:=vtInteger;
  FVarrec.VInteger:=1;
  DoFromVarRec;
  TestContext.AssertTrue((1)=(Value.AsInteger), 'Value');
  TestContext.AssertTrue(TypeInfo(Integer)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarrecBoolean;
begin
  FVarrec.VType:=vtBoolean;
  FVarrec.VBoolean:=True;
  DoFromVarRec;
  TestContext.AssertTrue((True)=(Value.AsBoolean), 'Value');
  TestContext.AssertTrue(TypeInfo(Boolean)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecChar;
begin
  FVarrec.VType:=vtChar;
  FVarrec.VChar:='c';
  DoFromVarRec;
  TestContext.AssertTrue(('c')=(Value.AsAnsiChar), 'Value');
  TestContext.AssertTrue(TypeInfo(AnsiChar)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecExtended;

var
  E : Extended;

begin
  E:=1.23;
  FVarRec.VExtended:=@E;
  FVarRec.vType:=vtExtended;
  DoFromVarRec;
  TestContext.AssertTrue(Abs((1.23)-(Value.AsExtended))<=(0.01), 'Value');
  TestContext.AssertTrue(TypeInfo(Extended)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecString;

Var
  s : ShortString;

begin
  S:='123';
  FVarrec.VType:=vtString;
  FVarrec.VString:=@S;
  DoFromVarRec;
  TestContext.AssertTrue(('123')=(Value.AsString), 'Value');
  TestContext.AssertTrue(TypeInfo(ShortString)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecPointer;
Var
  s : ShortString;

begin
  S:='123';
  FVarrec.VType:=vtPointer;
  FVarrec.VString:=@S;
  DoFromVarRec;
  TestContext.AssertTrue(@S=Value.AsPointer, 'Value');
  TestContext.AssertTrue(TypeInfo(Pointer)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecPChar;
Var
  s : AnsiString;

begin
  S:='123';
  FVarrec.VType:=vtPChar;
  FVarrec.VPChar:=PAnsiChar(S);
  DoFromVarRec;
  TestContext.AssertTrue(S=Value.AsAnsiString, 'Value');
  // In delphi it is String, but not widestring !
  TestContext.AssertTrue(TypeInfo(AnsiString)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecObject;
Var
  C : TObject;

begin
  C:=TComponent.Create(Nil);
  FVarrec.VType:=vtObject;
  FVarrec.VObject:=C;
  DoFromVarRec;
  TestContext.AssertTrue((C)=(Value.AsObject), 'Value');
  // In delphi it is String, but not widestring !
  TestContext.AssertTrue(TypeInfo(TComponent)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(True), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecClass;
Var
  C : TClass;

begin
  C:=TComponent;
  FVarrec.VType:=vtClass;
  FVarrec.VClass:=C;
  DoFromVarRec;
  TestContext.AssertTrue((C)=(Value.AsClass), 'Value');
  // In delphi it is String, but not widestring !
  TestContext.AssertTrue(TypeInfo(TClass)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(True), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');

end;

procedure TTestValueVariant.TestFromVarRecWideChar;
begin
  FVarrec.VType:=vtWideChar;
  FVarrec.VWideChar:='c';
  DoFromVarRec;
  TestContext.AssertTrue(('c')=(Value.AsWideChar), 'Value');
  TestContext.AssertTrue(TypeInfo(WideChar)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecPWideChar;
Var
  s : WideString;

begin
  S:='123';
  FVarrec.VType:=vtPWideChar;
  FVarrec.VPWideChar:=PWideChar(S);
  DoFromVarRec;
  TestContext.AssertTrue(('123')=(Value.AsUnicodeString), 'Value');
  TestContext.AssertTrue(TypeInfo(WideString)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecAnsiString;
Var
  s : AnsiString;

begin
  S:='123';
  FVarrec.VType:=vtAnsiString;
  FVarrec.VAnsiString:=Pointer(S);
  DoFromVarRec;
  TestContext.AssertTrue(('123')=(Value.AsAnsiString), 'Value');
  TestContext.AssertTrue(TypeInfo(AnsiString)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecCurrency;

var
  C : Currency;

begin
  C:=1.23;
  FVarRec.VCurrency:=@C;
  FVarRec.vType:=vtCurrency;
  DoFromVarRec;
  TestContext.AssertTrue(Abs((1.23)-(Value.AsCurrency))<=(0.01), 'Value');
  TestContext.AssertTrue(TypeInfo(Currency)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecVariant;

var
  V : Variant;

begin
  V:='1.23';
  FVarRec.VVariant:=@V;
  FVarRec.vType:=vtVariant;
  DoFromVarRec;
  TestContext.AssertTrue((V)=(String(Value.AsVariant)), 'Value');
  TestContext.AssertTrue(TypeInfo(Variant)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecInterface;
Var
  U : IInterface;

begin
  U:=TMyUNknown.Create;
  FVarRec.VInterface:=U;
  FVarRec.VType:=vtInterface;
  DoFromVarRec;
  TestContext.AssertTrue(U=Value.AsInterface, 'Value');
  TestContext.AssertTrue(TypeInfo(IInterface)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecWideString;
Var
  s : WideString;

begin
  S:='123';
  FVarrec.VType:=vtWideString;
  FVarrec.VWideString:=Pointer(S);
  DoFromVarRec;
  TestContext.AssertTrue(('123')=(Value.AsUnicodeString), 'Value');
  TestContext.AssertTrue(TypeInfo(WideString)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecInt64;

Var
  I : Int64;

begin
  I:=Int64(1);
  FVarRec.VInt64:=@I;
  FVarRec.vType:=vtInt64;
  DoFromVarRec;
  TestContext.AssertTrue((1)=(Value.AsInt64), 'Value');
  TestContext.AssertTrue(TypeInfo(Int64)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecQWord;

Var
  Q : QWord;


begin
  Q:=1;
  FVarRec.VQWord:=@Q;
  FVarRec.vType:=vtQWord;
  DoFromVarRec;
  TestContext.AssertTrue((1)=(Value.AsUInt64), 'Value');
  TestContext.AssertTrue(TypeInfo(QWord)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVarRecUnicodeString;

Var
  s : UnicodeString;

begin
  S:='123';
  FVarrec.VType:=vtUnicodeString;
  FVarrec.VUnicodeString:=Pointer(S);
  DoFromVarRec;
  TestContext.AssertTrue(('123')=(Value.AsUnicodeString), 'Value');
  TestContext.AssertTrue(TypeInfo(UnicodeString)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;


procedure TTestValueVariant.TestFromVariantInteger;


begin
  FSrc:=Integer(1);
  DoFromVariant;
  TestContext.AssertTrue((1)=(Value.AsInteger), 'Value');
  TestContext.AssertTrue(TypeInfo(Longint)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;


procedure TTestValueVariant.TestFromVariantBoolean;
begin
  FSrc:=True;
  DoFromVariant;
  TestContext.AssertTrue((True)=(Value.AsBoolean), 'Value');
  TestContext.AssertTrue(TypeInfo(Boolean)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantSmallInt;
begin
  FSrc:=SmallInt(1);
  DoFromVariant;
  TestContext.AssertTrue((1)=(Value.AsInteger), 'Value');
  TestContext.AssertTrue(TypeInfo(SmallInt)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantOleStr;

begin
  FSrc:=WideString('1.23');
  DoFromVariant;
  TestContext.AssertTrue(('1.23')=(Value.AsUnicodeString), 'Value');
  TestContext.AssertTrue(TypeInfo(WideString)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantInt64;
begin
  FSrc:=Int64(1);
  DoFromVariant;
  TestContext.AssertTrue((1)=(Value.AsInt64), 'Value');
  TestContext.AssertTrue(TypeInfo(Int64)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantQWord;
begin
  FSrc:=QWord(1);
  DoFromVariant;
  TestContext.AssertTrue((1)=(Value.AsInt64), 'Value');
  TestContext.AssertTrue(TypeInfo(QWord)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantShortInt;
begin
  FSrc:=ShortInt(1);
  DoFromVariant;
  TestContext.AssertTrue((1)=(Value.AsInteger), 'Value');
  TestContext.AssertTrue(TypeInfo(Shortint)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantByte;
begin
  FSrc:=Byte(1);
  DoFromVariant;
  TestContext.AssertTrue((1)=(Value.AsInteger), 'Value');
  TestContext.AssertTrue(TypeInfo(Byte)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantWord;
begin
  FSrc:=Word(1);
  DoFromVariant;
  TestContext.AssertTrue((1)=(Value.AsInteger), 'Value');
  TestContext.AssertTrue(TypeInfo(Word)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantLongWord;
begin
  FSrc:=Cardinal(1);
  DoFromVariant;
  TestContext.AssertTrue((1)=(Value.AsInteger), 'Value');
  TestContext.AssertTrue(TypeInfo(Cardinal)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantSingle;
begin
  FSrc:=Single(1.23); // Results in double...
  VarCast(FSrc,FSrc,varSingle);
  DoFromVariant;
  TestContext.AssertTrue(Abs((1.23)-(Value.AsSingle))<=(0.01), 'Value');
  TestContext.AssertTrue(TypeInfo(Single)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantDouble;
begin
  FSrc:=Double(1.23);
  DoFromVariant;
  TestContext.AssertTrue(Abs((1.23)-(Value.AsDouble))<=(0.01), 'Value');
  TestContext.AssertTrue(TypeInfo(Double)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantDate;

Var
  D : TDateTime;

begin
  D:=Time;
  FSrc:=D;
  DoFromVariant;
  TestContext.AssertTrue(Abs((D)-(Value.AsDateTime))<=(0.01), 'Value');
  TestContext.AssertTrue(TypeInfo(TDateTime)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantDispatch;
Var
  U : IDispatch;

begin
  U:=TMyUNknown.Create;
  FSrc:=U;
  DoFromVariant;
  TestContext.AssertTrue(U=Value.AsInterface, 'Value');
  TestContext.AssertTrue(TypeInfo(IDispatch)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantError;

begin
  TVarData(FSrc).verror:=S_FALSE;
  TVarData(FSrc).vtype:=varError;
  DoFromVariant;
  TestContext.AssertTrue(S_FALSE=Value.AsError, 'Value');
  TestContext.AssertTrue(TypeInfo(HRESULT)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(True), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantUnknown;

Var
  U : IInterface;

begin
  U:=TMyUNknown.Create;
  FSrc:=U;
  DoFromVariant;
  TestContext.AssertTrue(U=Value.AsInterface, 'Value');
  TestContext.AssertTrue(TypeInfo(IInterface)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantCurrency;
begin
  FSrc:=Currency(1.23);
  DoFromVariant;
  TestContext.AssertTrue(Abs((1.23)-(Value.AsCurrency))<=(0.01), 'Value');
  TestContext.AssertTrue(TypeInfo(Currency)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantString;
begin
  FSrc:='1.23';
  DoFromVariant;
  TestContext.AssertTrue(('1.23')=(Value.AsString), 'Value');
  TestContext.AssertTrue(TypeInfo(AnsiString)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;

procedure TTestValueVariant.TestFromVariantUnicodeString;
begin
  TVarData(FSrc).vustring:=Pointer(UnicodeString('1.23'));
  TVarData(FSrc).vtype:=varUString;
  DoFromVariant;
  TestContext.AssertTrue(('1.23')=(Value.AsString), 'Value');
  TestContext.AssertTrue(TypeInfo(UnicodeString)=Value.TypeInfo, 'Correct typeinfo');
  TestContext.AssertTrue((Value.IsClass)=(False), 'Class');
  TestContext.AssertTrue((Value.IsObject)=(False), 'Object');
  TestContext.AssertTrue((Value.IsOrdinal)=(False), 'Ordinal');
end;



procedure TTestValueVariant.TestArrayOfConstToTValue;

Var
  S:TValueArray;

begin
  S:=ArrayOfConstToTValueArray([1,'something',1.23]);
  TestContext.AssertTrue((3)=(Length(S)), 'Length');
  TestContext.AssertTrue((1)=(S[0].AsInteger), 'Value 1');
  TestContext.AssertTrue(('something')=(S[1].AsString), 'Value 3');
  TestContext.AssertTrue(Abs((1.23)-(S[2].AsDouble))<=(0.01), 'Value 3');
end;

procedure TTestValueVariant.TestCastAnsiString;
var
  s: AnsiString;
  v: Variant;
  vvar, vstr: TValue;
begin
  s := 'Test';
  v := s;
  vvar := TValue.{$ifdef fpc}specialize{$endif}From<Variant>(v);
  TestContext.AssertTrue(vvar.TryCast(TypeInfo(AnsiString), vstr), '');
  TestContext.AssertTrue((s)=(vstr.AsAnsiString), '');
end;

{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
procedure TTestValueVariant.TestCastUnicodeString;
var
  u: UnicodeString;
  v: Variant;
  vvar, vstr: TValue;
begin
  u := 'Test';
  TVarData(v).vType := varUString;
  TVarData(v).vuString := Pointer(u);
  vvar := TValue.{$ifdef fpc}specialize{$endif}From<Variant>(v);
  TestContext.AssertTrue(vvar.TryCast(TypeInfo(UnicodeString), vstr), '');
  TestContext.AssertTrue((u)=(vstr.AsUnicodeString), '');
end;
{$endif}

procedure TTestValueVariant.TestCastWideString;
var
  w: WideString;
  v: Variant;
  vvar, vstr: TValue;
begin
  w := 'Test';
  v := w;
  vvar := TValue.{$ifdef fpc}specialize{$endif}From<Variant>(v);
  TestContext.AssertTrue(vvar.TryCast(TypeInfo(WideString), vstr), '');
  TestContext.AssertTrue((w)=(vstr.AsUnicodeString), '');
end;

procedure TTestValueVariant.TestCastShortString;
var
  s: ShortString;
  v: Variant;
  vvar, vstr: TValue;
begin
  s := 'Test';
  v := s;
  vvar := TValue.{$ifdef fpc}specialize{$endif}From<Variant>(v);
  TestContext.AssertTrue(vvar.TryCast(TypeInfo(ShortString), vstr), '');
  TestContext.AssertTrue((s)=(vstr.AsAnsiString), '');
end;

{ TMyUNknown }

function TMyUNknown.GetTypeInfoCount(out count: longint): HResult; stdcall;
begin
  count:=0;
  Result:=S_OK;
end;

function TMyUNknown.GetTypeInfo(Index, LocaleID: longint; out TypeInfo
  ): HResult; stdcall;
begin

  Result:=S_OK;
end;

function TMyUNknown.GetIDsOfNames(const iid: TGUID; names: Pointer; NameCount,
  LocaleID: LongInt; DispIDs: Pointer): HResult; stdcall;
begin
  Result:=S_OK;
end;

function TMyUNknown.Invoke(DispID: LongInt; const iid: TGUID;
  LocaleID: longint; Flags: Word; var params; VarResult, ExcepInfo,
  ArgErr: pointer): HResult; stdcall;
begin
  Result:=S_OK;
end;

type
  TMyLongInt = type LongInt;

procedure TTestValueSimple.TestIsType;
{ Delphi does not provide type information for local types :/ }
{type
  TMyLongInt = type LongInt;}
var
  v: TValue;
  l: LongInt;
  ml: TMyLongInt;
begin
  l := 42;
  ml := 42;
  TValue.Make(@l, TypeInfo(LongInt), v);
  TestContext.AssertTrue(v.IsType(TypeInfo(LongInt)), '');
  TestContext.AssertTrue(not v.IsType(TypeInfo(TMyLongInt)), '');
  TestContext.AssertTrue(not v.IsType(TypeInfo(String)), '');
  TestContext.AssertTrue(v.{$ifdef fpc}specialize{$endif} IsType<LongInt>, '');
  TestContext.AssertTrue(not v.{$ifdef fpc}specialize{$endif} IsType<TMyLongInt>, '');
  TestContext.AssertTrue(not v.{$ifdef fpc}specialize{$endif} IsType<String>, '');

  TValue.Make(@ml, TypeInfo(TMyLongInt), v);
  TestContext.AssertTrue(v.IsType(TypeInfo(TMyLongInt)), '');
  TestContext.AssertTrue(not v.IsType(TypeInfo(LongInt)), '');
  TestContext.AssertTrue(not v.IsType(TypeInfo(String)), '');
  TestContext.AssertTrue(v.{$ifdef fpc}specialize{$endif} IsType<TMyLongInt>, '');
  TestContext.AssertTrue(not v.{$ifdef fpc}specialize{$endif} IsType<LongInt>, '');
  TestContext.AssertTrue(not v.{$ifdef fpc}specialize{$endif} IsType<String>, '');
end;

procedure TTestValueSimple.TestMakeNil;
var
  value: TValue;
begin
  TValue.Make(Nil, Nil, value);
  TestContext.AssertTrue(value.Kind = tkUnknown, '');
  TestContext.AssertTrue(value.IsEmpty, '');
  TestContext.AssertTrue(value.IsObject, '');
  TestContext.AssertTrue(value.IsClass, '');
  TestContext.AssertTrue(value.IsOrdinal, '');
  TestContext.AssertTrue(not (value.IsArray), '');
  TestContext.AssertTrue(value.AsObject = Nil, '');
  TestContext.AssertTrue(value.AsClass = Nil, '');
  TestContext.AssertTrue(value.AsInterface = Nil, '');
  TestContext.AssertTrue((0)=(value.AsOrdinal), '');

  TValue.Make(Nil, TypeInfo(TObject), value);
  TestContext.AssertTrue(value.IsEmpty, '');
  TestContext.AssertTrue(value.IsObject, '');
  TestContext.AssertTrue(value.IsClass, '');
  TestContext.AssertTrue(value.IsOrdinal, '');
  TestContext.AssertTrue(not (value.IsArray), '');
  TestContext.AssertTrue(value.AsObject=Nil, '');
  TestContext.AssertTrue(value.AsClass=Nil, '');
  TestContext.AssertTrue(value.AsInterface=Nil, '');
  TestContext.AssertTrue((0)=(value.AsOrdinal), '');

  TValue.Make(Nil, TypeInfo(TClass), value);
  TestContext.AssertTrue(value.IsEmpty, '');
  TestContext.AssertTrue(value.IsClass, '');
  TestContext.AssertTrue(value.IsOrdinal, '');
  TestContext.AssertTrue(not (value.IsArray), '');
  TestContext.AssertTrue(value.AsObject=Nil, '');
  TestContext.AssertTrue(value.AsClass=Nil, '');
  TestContext.AssertTrue(value.AsInterface=Nil, '');
  TestContext.AssertTrue((0)=(value.AsOrdinal), '');

  TValue.Make(Nil, TypeInfo(LongInt), value);
  TestContext.AssertTrue(value.IsOrdinal, '');
  TestContext.AssertTrue(not (value.IsEmpty), '');
  TestContext.AssertTrue(not (value.IsClass), '');
  TestContext.AssertTrue(not (value.IsObject), '');
  TestContext.AssertTrue(not (value.IsArray), '');
  TestContext.AssertTrue((0)=(value.AsOrdinal), '');
  TestContext.AssertTrue((0)=(value.AsInteger), '');
  TestContext.AssertTrue((0)=(value.AsInt64), '');
  TestContext.AssertTrue((0)=(value.AsUInt64), '');

  TValue.Make(Nil, TypeInfo(String), value);
  TestContext.AssertTrue(not (value.IsEmpty), '');
  TestContext.AssertTrue(not (value.IsObject), '');
  TestContext.AssertTrue(not (value.IsClass), '');
  TestContext.AssertTrue(not (value.IsArray), '');
  TestContext.AssertTrue(('')=(value.AsString), '');
end;

procedure TTestValueSimple.TestMakeObject;
var
  AValue: TValue;
  ATestClass: TTestValueClass;
begin
  ATestClass := TTestValueClass.Create;
  ATestClass.AInteger := 54329;
  TValue.Make(@ATestClass, TypeInfo(TTestValueClass),AValue);
  TestContext.AssertTrue((AValue.IsClass)=(False), '');
  TestContext.AssertTrue((AValue.IsObject)=(True), '');
  TestContext.AssertTrue(AValue.AsObject=ATestClass, '');
  TestContext.AssertTrue(PPointer(AValue.GetReferenceToRawData)^ = Pointer(ATestClass), '');
  TestContext.AssertTrue((TTestValueClass(AValue.AsObject).AInteger)=(54329), '');
  ATestClass.Free;
end;

procedure TTestValueArray.TestMakeArrayDynamic;
var
  arr: TArrayOfLongintDyn;
  value: TValue;
begin
  SetLength(arr, 2);
  arr[0] := 42;
  arr[1] := 21;
  TValue.Make(@arr, TypeInfo(TArrayOfLongintDyn), value);
  TestContext.AssertTrue((value.IsArray)=(True), '');
  TestContext.AssertTrue((value.IsObject)=(False), '');
  TestContext.AssertTrue((value.IsOrdinal)=(False), '');
  TestContext.AssertTrue((value.IsClass)=(False), '');
  TestContext.AssertTrue((value.GetArrayLength)=(2), '');
  TestContext.AssertTrue((value.GetArrayElement(0).AsInteger)=(42), '');
  TestContext.AssertTrue((value.GetArrayElement(1).AsInteger)=(21), '');
  TestContext.AssertTrue(PPointer(value.GetReferenceToRawData)^ = Pointer(arr), '');
  value.SetArrayElement(0, Integer(84));
  TestContext.AssertTrue((arr[0])=(84), '');
end;

procedure TTestValueArray.TestMakeArrayStatic;
type
  TArrStat = array[0..1] of LongInt;
  TArrStat2D = array[0..1, 0..1] of LongInt;
var
  arr: TArrStat;
  arr2D: TArrStat2D;
  value: TValue;
begin
  arr[0] := 42;
  arr[1] := 21;
  TValue.Make(@arr, TypeInfo(TArrStat), value);
  TestContext.AssertTrue((value.IsArray)=(True), '');
  TestContext.AssertTrue((value.IsObject)=(False), '');
  TestContext.AssertTrue((value.IsOrdinal)=(False), '');
  TestContext.AssertTrue((value.IsClass)=(False), '');
  TestContext.AssertTrue((value.GetArrayLength)=(2), '');
  TestContext.AssertTrue((value.GetArrayElement(0).AsInteger)=(42), '');
  TestContext.AssertTrue((value.GetArrayElement(1).AsInteger)=(21), '');
  value.SetArrayElement(0, integer(84));
  { since this is a static array the original array isn't touched! }
  TestContext.AssertTrue((arr[0])=(42), '');

  arr2D[0, 0] := 42;
  arr2D[0, 1] := 21;
  arr2D[1, 0] := 84;
  arr2D[1, 1] := 63;

  TValue.Make(@arr2D, TypeInfo(TArrStat2D), value);
  TestContext.AssertTrue((value.IsArray)=(True), '');
  TestContext.AssertTrue((value.GetArrayLength)=(4), '');
  TestContext.AssertTrue((value.GetArrayElement(0).AsInteger)=(42), '');
  TestContext.AssertTrue((value.GetArrayElement(1).AsInteger)=(21), '');
  TestContext.AssertTrue((value.GetArrayElement(2).AsInteger)=(84), '');
  TestContext.AssertTrue((value.GetArrayElement(3).AsInteger)=(63), '');
end;

{$ifdef fpc}
procedure TTestValueArray.TestMakeArrayOpen;



  procedure TestOpenArrayValueCopy(aArr: array of LongInt);
  var
    value: TValue;
  begin
    TValue.MakeOpenArray(@aArr[0], Length(aArr), PTypeInfo(TypeInfo(aArr)), value);
    TestContext.AssertTrue((value.IsArray)=(True), '');
    TestContext.AssertTrue((value.IsOpenArray)=(True), '');
    TestContext.AssertTrue((value.IsObject)=(False), '');
    TestContext.AssertTrue((value.IsOrdinal)=(False), '');
    TestContext.AssertTrue((value.IsClass)=(False), '');
    TestContext.AssertTrue((value.GetArrayLength)=(2), '');
    TestContext.AssertTrue((value.GetArrayElement(0).AsInteger)=(42), '');
    TestContext.AssertTrue((value.GetArrayElement(1).AsInteger)=(21), '');
    value.SetArrayElement(0, Integer(84));
    { since this is an open array the original array is modified! }
    TestContext.AssertTrue((aArr[0])=(84), '');
  end;

  procedure TestOpenArrayValueVar(var aArr: array of LongInt);
  var
    value: TValue;
  begin
    TValue.MakeOpenArray(@aArr[0], Length(aArr), PTypeInfo(TypeInfo(aArr)), value);
    TestContext.AssertTrue((value.IsArray)=(True), '');
    TestContext.AssertTrue((value.IsOpenArray)=(True), '');
    TestContext.AssertTrue((value.IsObject)=(False), '');
    TestContext.AssertTrue((value.IsOrdinal)=(False), '');
    TestContext.AssertTrue((value.IsClass)=(False), '');
    TestContext.AssertTrue((value.GetArrayLength)=(2), '');
    TestContext.AssertTrue((value.GetArrayElement(0).AsInteger)=(42), '');
    TestContext.AssertTrue((value.GetArrayElement(1).AsInteger)=(21), '');
    value.SetArrayElement(0, 84);
    { since this is an open array the original array is modified! }
    TestContext.AssertTrue((aArr[0])=(84), '');
  end;

  procedure TestOpenArrayValueOut(var aArr: array of LongInt);
  var
    value: TValue;
  begin
    TValue.MakeOpenArray(@aArr[0], Length(aArr), PTypeInfo(TypeInfo(aArr)), value);
    TestContext.AssertTrue((value.IsArray)=(True), '');
    TestContext.AssertTrue((value.IsOpenArray)=(True), '');
    TestContext.AssertTrue((value.IsObject)=(False), '');
    TestContext.AssertTrue((value.IsOrdinal)=(False), '');
    TestContext.AssertTrue((value.IsClass)=(False), '');
    TestContext.AssertTrue((value.GetArrayLength)=(2), '');
    TestContext.AssertTrue((value.GetArrayElement(0).AsInteger)=(42), '');
    TestContext.AssertTrue((value.GetArrayElement(1).AsInteger)=(21), '');
    value.SetArrayElement(0, 84);
    value.SetArrayElement(1, 128);
    { since this is an open array the original array is modified! }
    TestContext.AssertTrue((aArr[0])=(84), '');
    TestContext.AssertTrue((aArr[1])=(128), '');
    TestContext.AssertTrue((value.GetArrayElement(0).AsInteger)=(84), '');
    TestContext.AssertTrue((value.GetArrayElement(1).AsInteger)=(128), '');
  end;

var
  arr: array of LongInt;
begin
  TestOpenArrayValueCopy([42, 21]);

  arr := [42, 21];
  TestOpenArrayValueVar(arr);
  TestContext.AssertTrue((arr[0])=(84), '');
  TestContext.AssertTrue((arr[1])=(21), '');

  arr := [42, 21];
  TestOpenArrayValueOut(arr);
  TestContext.AssertTrue((arr[0])=(84), '');
  TestContext.AssertTrue((arr[1])=(128), '');
end;

{$endif}

procedure TTestValueSimple.TestMakeSingle;
var
  fs: Single;
  v: TValue;
  hadexcept: Boolean;
begin
  fs := 3.14;

  TValue.Make(@fs, TypeInfo(Single), v);
  TestContext.AssertTrue((v.IsClass)=(False), '');
  TestContext.AssertTrue((v.IsObject)=(False), '');
  TestContext.AssertTrue((v.IsOrdinal)=(False), '');
  TestContext.AssertTrue(v.AsExtended=fs, '');
  TestContext.AssertTrue(v.GetReferenceToRawData <> @fs, '');

  try
    hadexcept := False;
    v.AsInt64;
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(hadexcept, 'No signed type conversion exception');

  try
    hadexcept := False;
    v.AsUInt64;
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(hadexcept, 'No unsigned type conversion exception');
end;

procedure TTestValueSimple.TestMakeDouble;
var
  fd: Double;
  v: TValue;
  hadexcept: Boolean;
begin
  fd := 3.14;

  TValue.Make(@fd, TypeInfo(Double), v);
  TestContext.AssertTrue((v.IsClass)=(False), '');
  TestContext.AssertTrue((v.IsObject)=(False), '');
  TestContext.AssertTrue((v.IsOrdinal)=(False), '');
  TestContext.AssertTrue(v.AsExtended=fd, '');
  TestContext.AssertTrue(v.GetReferenceToRawData <> @fd, '');

  try
    hadexcept := False;
    v.AsInt64;
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(hadexcept, 'No signed type conversion exception');

  try
    hadexcept := False;
    v.AsUInt64;
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(hadexcept, 'No unsigned type conversion exception');
end;

procedure TTestValueSimple.TestMakeExtended;
var
  fe: Extended;
  v: TValue;
  hadexcept: Boolean;
begin
  fe := 3.14;

  TValue.Make(@fe, TypeInfo(Extended), v);
  TestContext.AssertTrue((v.IsClass)=(False), '');
  TestContext.AssertTrue((v.IsObject)=(False), '');
  TestContext.AssertTrue((v.IsOrdinal)=(False), '');
  TestContext.AssertTrue(v.AsExtended=fe, '');
  TestContext.AssertTrue(v.GetReferenceToRawData <> @fe, '');

  try
    hadexcept := False;
    v.AsInt64;
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(hadexcept, 'No signed type conversion exception');

  try
    hadexcept := False;
    v.AsUInt64;
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(hadexcept, 'No unsigned type conversion exception');
end;

procedure TTestValueSimple.TestMakeCurrency;
var
  fcu: Currency;
  v: TValue;
  hadexcept: Boolean;
begin
  fcu := 3.14;

  TValue.Make(@fcu, TypeInfo(Currency), v);
  TestContext.AssertTrue((v.IsClass)=(False), '');
  TestContext.AssertTrue((v.IsObject)=(False), '');
  TestContext.AssertTrue((v.IsOrdinal)=(False), '');
  TestContext.AssertTrue(v.AsExtended=Extended(fcu), '');
  TestContext.AssertTrue(v.AsCurrency=fcu, '');
  TestContext.AssertTrue(v.GetReferenceToRawData <> @fcu, '');

  try
    hadexcept := False;
    v.AsInt64;
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(hadexcept, 'No signed type conversion exception');

  try
    hadexcept := False;
    v.AsUInt64;
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(hadexcept, 'No unsigned type conversion exception');
end;

procedure TTestValueSimple.TestMakeComp;
var
  fco: Comp;
  v: TValue;
  hadexcept: Boolean;
begin
  fco := 314;

  TValue.Make(@fco, TypeInfo(Comp), v);

  if v.Kind <> tkFloat then
    Exit;

  TestContext.AssertTrue((v.IsClass)=(False), '');
  TestContext.AssertTrue((v.IsObject)=(False), '');
  TestContext.AssertTrue((v.IsOrdinal)=(False), '');
  TestContext.AssertTrue(v.AsExtended=Extended(fco), '');
  TestContext.AssertTrue(v.GetReferenceToRawData <> @fco, '');

  try
    hadexcept := False;
    TestContext.AssertTrue((v.AsInt64)=(314), '');
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(not (hadexcept), 'Had signed type conversion exception');

  try
    hadexcept := False;
    TestContext.AssertTrue((v.AsUInt64)=(314), '');
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(not (hadexcept), 'Had unsigned type conversion exception');
end;

procedure TTestValueSimple.TestMakeEnum;
var
  e: TTestEnum;
  v: TValue;
begin
  e := te1;

  TValue.Make(@e, TypeInfo(TTestEnum), v);
  TestContext.AssertTrue(not v.IsClass, '');
  TestContext.AssertTrue(not v.IsArray, '');
  TestContext.AssertTrue(not v.IsEmpty, '');
{$ifdef fpc}
  TestContext.AssertTrue(not v.IsOpenArray, '');
{$endif}
  TestContext.AssertTrue(not v.IsObject, '');
  TestContext.AssertTrue(v.IsOrdinal, '');

  TestContext.AssertTrue(v.GetReferenceToRawData <> @e, '');
  TestContext.AssertTrue(TTestEnum(v.AsOrdinal) = te1, '');
end;

procedure TTestValueSimple.TestMakeAnsiChar;
var
  c: AnsiChar;
  v: TValue;
begin
  c := #20;

  TValue.Make(@c, TypeInfo(AnsiChar), v);
  TestContext.AssertTrue(not v.IsClass, '');
  TestContext.AssertTrue(not v.IsArray, '');
  TestContext.AssertTrue(not v.IsEmpty, '');
{$ifdef fpc}
  TestContext.AssertTrue(not v.IsOpenArray, '');
{$endif}
  TestContext.AssertTrue(not v.IsObject, '');
  TestContext.AssertTrue(v.IsOrdinal, '');

  TestContext.AssertTrue(v.GetReferenceToRawData <> @c, '');
  TestContext.AssertTrue(AnsiChar(v.AsOrdinal) = #20, '');
  TestContext.AssertTrue(v.AsAnsiChar = #20, '');
end;

procedure TTestValueSimple.TestMakeWideChar;
var
  c: WideChar;
  v: TValue;
begin
  c := #$1234;

  TValue.Make(@c, TypeInfo(WideChar), v);
  TestContext.AssertTrue(not v.IsClass, '');
  TestContext.AssertTrue(not v.IsArray, '');
  TestContext.AssertTrue(not v.IsEmpty, '');
{$ifdef fpc}
  TestContext.AssertTrue(not v.IsOpenArray, '');
{$endif}
  TestContext.AssertTrue(not v.IsObject, '');
  TestContext.AssertTrue(v.IsOrdinal, '');

  TestContext.AssertTrue(v.GetReferenceToRawData <> @c, '');
  TestContext.AssertTrue(WideChar(v.AsOrdinal) = #$1234, '');
  TestContext.AssertTrue(v.AsWideChar = #$1234, '');
end;

procedure TTestValueSimple.TestMakeNativeInt;
var
  fni: NativeInt;
  s: AnsiString;
  v: TValue;
  o: TObject;
begin
  fni := 2021;

  TValue.Make(fni, TypeInfo(LongInt), v);
  TestContext.AssertTrue((v.IsClass)=(False), '');
  TestContext.AssertTrue((v.IsObject)=(False), '');
  TestContext.AssertTrue((v.IsOrdinal)=(True), '');
  TestContext.AssertTrue(NativeInt(v.GetReferenceToRawData) <> fni, '');
  TestContext.AssertTrue((v.AsOrdinal)=(2021), '');

  s := 'Hello World';
  TValue.Make(NativeInt(s), TypeInfo(AnsiString), v);
  TestContext.AssertTrue((v.IsClass)=(False), '');
  TestContext.AssertTrue((v.IsObject)=(False), '');
  TestContext.AssertTrue((v.IsOrdinal)=(False), '');
  TestContext.AssertTrue((v.AsString)=(s), '');

  o := TObject.Create;
  TValue.Make(NativeInt(o), TypeInfo(TObject), v);
  TestContext.AssertTrue((v.IsClass)=(False), '');
  TestContext.AssertTrue((v.IsObject)=(True), '');
  TestContext.AssertTrue((v.IsOrdinal)=(False), '');
  TestContext.AssertTrue(PPointer(v.GetReferenceToRawData)^ = Pointer(o), '');
  TestContext.AssertTrue(v.AsObject = o, '');
  o.Free;
end;

procedure TTestValueSimple.TestMakeVariant;
var
  vv : Variant;
  vd : TVarData;
  v: TValue;
begin
  vv := 'Some String';

  TValue.Make(@vv, TypeInfo(Variant), v);
  TestContext.AssertTrue(not v.IsClass, '');
  TestContext.AssertTrue(not v.IsArray, '');
  TestContext.AssertTrue(not v.IsEmpty, '');
{$ifdef fpc}
  TestContext.AssertTrue(not v.IsOpenArray, '');
{$endif}
  TestContext.AssertTrue(not v.IsObject, '');
  TestContext.AssertTrue(not v.IsOrdinal, '');

  TestContext.AssertTrue(v.GetReferenceToRawData <> @vv, '');
  TestContext.AssertTrue(String(v.AsVariant) = 'Some String', '');
end;

procedure TTestValueArray.TestMakeFromArray;
var
  arr, subarr: array of TValue;
  v, varr: TValue;
  ti: PTypeInfo;
  i: LongInt;
begin
  SetLength(arr, 3 * 4);
  for i := 0 to High(arr) do
    TValue.{$ifdef fpc}specialize{$endif} Make<LongInt>(i + 1, arr[i]);

  ti := PTypeInfo(TypeInfo(LongInt));

  v := TValue.FromArray(TypeInfo(TArrayOfLongintDyn), arr);
  TestContext.AssertTrue(not v.IsEmpty, 'Array is empty');
  TestContext.AssertTrue(v.IsArray, 'Value is not an array');
  TestContext.AssertTrue((Length(arr))=(v.GetArrayLength), 'Array length does not match');
  for i := 0 to High(arr) do begin
    varr := v.GetArrayElement(i);
    TestContext.AssertTrue(varr.TypeInfo = ti, 'Type info of array element does not match');
    TestContext.AssertTrue(varr.IsOrdinal, 'Array element is not an ordinal');
    TestContext.AssertTrue(varr.AsInteger = arr[i].AsInteger, 'Value of array element does not match');
  end;

  subarr := Copy(arr, 0, 4);
  v := TValue.FromArray(TypeInfo(TArrayOfLongintStatic), subarr);
  TestContext.AssertTrue(not v.IsEmpty, 'Array is empty');
  TestContext.AssertTrue(v.IsArray, 'Value is not an array');
  TestContext.AssertTrue((Length(subarr))=(v.GetArrayLength), 'Array length does not match');
  for i := 0 to High(subarr) do begin
    varr := v.GetArrayElement(i);
    TestContext.AssertTrue(varr.TypeInfo = ti, 'Type info of array element does not match');
    TestContext.AssertTrue(varr.IsOrdinal, 'Array element is not an ordinal');
    TestContext.AssertTrue(varr.AsInteger = subarr[i].AsInteger, 'Value of array element does not match');
  end;

  v := TValue.FromArray(TypeInfo(TArrayOfLongint2DStatic), arr);
  TestContext.AssertTrue(not v.IsEmpty, 'Array is empty');
  TestContext.AssertTrue(v.IsArray, 'Value is not an array');
  TestContext.AssertTrue((Length(arr))=(v.GetArrayLength), 'Array length does not match');
  for i := 0 to High(arr) do begin
    varr := v.GetArrayElement(i);
    TestContext.AssertTrue(varr.TypeInfo = ti, 'Type info of array element does not match');
    TestContext.AssertTrue(varr.IsOrdinal, 'Array element is not an ordinal');
    TestContext.AssertTrue(varr.AsInteger = arr[i].AsInteger, 'Value of array element does not match');
  end;
end;

procedure TTestValueSimple.TestMakeGenericNil;
var
  value: TValue;
begin
  TValue.{$ifdef fpc}specialize{$endif} Make<TObject>(Nil, value);
  TestContext.AssertTrue(value.IsEmpty, '');
  TestContext.AssertTrue(value.IsObject, '');
  TestContext.AssertTrue(value.IsClass, '');
  TestContext.AssertTrue(value.IsOrdinal, '');
  TestContext.AssertTrue(not (value.IsArray), '');
  TestContext.AssertTrue(value.AsObject=Nil, '');
  TestContext.AssertTrue(value.AsClass=Nil, '');
  TestContext.AssertTrue(value.AsInterface=Nil, '');
  TestContext.AssertTrue((0)=(value.AsOrdinal), '');

  TValue.{$ifdef fpc}specialize{$endif} Make<TClass>(Nil, value);
  TestContext.AssertTrue(value.IsEmpty, '');
  TestContext.AssertTrue(value.IsClass, '');
  TestContext.AssertTrue(value.IsOrdinal, '');
  TestContext.AssertTrue(not (value.IsArray), '');
  TestContext.AssertTrue(value.AsObject=Nil, '');
  TestContext.AssertTrue(value.AsClass=Nil, '');
  TestContext.AssertTrue(value.AsInterface=Nil, '');
  TestContext.AssertTrue((0)=(value.AsOrdinal), '');
end;

procedure TTestValueSimple.TestMakeGenericLongInt;
var
  value: TValue;
begin
  TValue.{$ifdef fpc}specialize{$endif} Make<LongInt>(0, value);
  TestContext.AssertTrue(value.IsOrdinal, '');
  TestContext.AssertTrue(not (value.IsEmpty), '');
  TestContext.AssertTrue(not (value.IsClass), '');
  TestContext.AssertTrue(not (value.IsObject), '');
  TestContext.AssertTrue(not (value.IsArray), '');
  TestContext.AssertTrue((0)=(value.AsOrdinal), '');
  TestContext.AssertTrue((0)=(value.AsInteger), '');
  TestContext.AssertTrue((0)=(value.AsInt64), '');
  TestContext.AssertTrue((0)=(value.AsUInt64), '');
end;

procedure TTestValueSimple.TestMakeGenericString;
var
  value: TValue;
begin
  TValue.{$ifdef fpc}specialize{$endif} Make<String>('test', value);
  TestContext.AssertTrue(not (value.IsEmpty), '');
  TestContext.AssertTrue(not (value.IsObject), '');
  TestContext.AssertTrue(not (value.IsClass), '');
  TestContext.AssertTrue(not (value.IsArray), '');
  TestContext.AssertTrue(('test')=(value.AsString), '');
end;

procedure TTestValueSimple.TestMakeGenericObject;
var
  value: TValue;
  TestClass: TTestValueClass;
begin
  TestClass := TTestValueClass.Create;
  TestClass.AInteger := 54329;
  TValue.{$ifdef fpc}specialize{$endif} Make<TTestValueClass>(TestClass, value);
  TestContext.AssertTrue((value.IsClass)=(False), '');
  TestContext.AssertTrue((value.IsObject)=(True), '');
  TestContext.AssertTrue(value.AsObject=TestClass, '');
  TestContext.AssertTrue(PPointer(value.GetReferenceToRawData)^ = Pointer(TestClass), '');
  TestContext.AssertTrue((TTestValueClass(value.AsObject).AInteger)=(54329), '');
  TestClass.Free;
end;

procedure TTestValueSimple.TestMakeGenericDouble;
var
  fd: Double;
  v: TValue;
  hadexcept: Boolean;
begin
  fd := 3.14;

  TValue.{$ifdef fpc}specialize{$endif} Make<Double>(fd, v);
  TestContext.AssertTrue((v.IsClass)=(False), '');
  TestContext.AssertTrue((v.IsObject)=(False), '');
  TestContext.AssertTrue((v.IsOrdinal)=(False), '');
  TestContext.AssertTrue(v.AsExtended=fd, '');
  TestContext.AssertTrue(v.GetReferenceToRawData <> @fd, '');

  try
    hadexcept := False;
    v.AsInt64;
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(hadexcept, 'No signed type conversion exception');

  try
    hadexcept := False;
    v.AsUInt64;
  except
    hadexcept := True;
  end;

  TestContext.AssertTrue(hadexcept, 'No unsigned type conversion exception');
end;


procedure TTestValueSimple.TestMakeGenericAnsiChar;
var
  c: AnsiChar;
  v: TValue;
begin
  c := #20;

  TValue.{$ifdef fpc}specialize{$endif} Make<AnsiChar>(c, v);
  TestContext.AssertTrue(not v.IsClass, '');
  TestContext.AssertTrue(not v.IsArray, '');
  TestContext.AssertTrue(not v.IsEmpty, '');
{$ifdef fpc}
  TestContext.AssertTrue(not v.IsOpenArray, '');
{$endif}
  TestContext.AssertTrue(not v.IsObject, '');
  TestContext.AssertTrue(v.IsOrdinal, '');

  TestContext.AssertTrue(v.GetReferenceToRawData <> @c, '');
  TestContext.AssertTrue(AnsiChar(v.AsOrdinal) = #20, '');
  TestContext.AssertTrue(v.AsAnsiChar = #20, '');
end;

procedure TTestValueSimple.TestMakeGenericWideChar;
var
  c: WideChar;
  v: TValue;
begin
  c := #$1234;

  TValue.{$ifdef fpc}specialize{$endif} Make<WideChar>(c, v);
  TestContext.AssertTrue(not v.IsClass, '');
  TestContext.AssertTrue(not v.IsArray, '');
  TestContext.AssertTrue(not v.IsEmpty, '');
{$ifdef fpc}
  TestContext.AssertTrue(not v.IsOpenArray, '');
{$endif}
  TestContext.AssertTrue(not v.IsObject, '');
  TestContext.AssertTrue(v.IsOrdinal, '');

  TestContext.AssertTrue(v.GetReferenceToRawData <> @c, '');
  TestContext.AssertTrue(WideChar(v.AsOrdinal) = #$1234, '');
  TestContext.AssertTrue(v.AsWideChar = #$1234, '');
end;

procedure TTestValueSimple.MakeFromOrdinalTObject;
begin
  TValue.FromOrdinal(TypeInfo(TObject), 42);
end;

procedure TTestValueSimple.MakeFromOrdinalSet;
begin
  TValue.FromOrdinal(TypeInfo(TTestSet), 42);
end;

procedure TTestValueSimple.MakeFromOrdinalString;
begin
  TValue.FromOrdinal(TypeInfo(AnsiString), 42);
end;

procedure TTestValueSimple.MakeFromOrdinalNil;
begin
  TValue.FromOrdinal(Nil, 42);
end;

procedure TTestValueSimple.TestFromOrdinal;
var
  v: TValue;
begin
  v := TValue.FromOrdinal(TypeInfo(LongInt), 42);
  TestContext.AssertTrue(v.IsOrdinal, '');
  TestContext.AssertTrue((v.AsOrdinal)=(42), '');

  v := TValue.FromOrdinal(TypeInfo(Boolean), Ord(True));
  TestContext.AssertTrue(v.IsOrdinal, '');
  TestContext.AssertTrue((v.AsOrdinal)=(Ord(True)), '');

  v := TValue.FromOrdinal(TypeInfo(Int64), $1234123412341234);
  TestContext.AssertTrue(v.IsOrdinal, '');
  TestContext.AssertTrue((v.AsOrdinal)=($1234123412341234), '');

  v := TValue.FromOrdinal(TypeInfo(QWord), $1234123412341234);
  TestContext.AssertTrue(v.IsOrdinal, '');
  TestContext.AssertTrue((v.AsOrdinal)=($1234123412341234), '');

  v := TValue.FromOrdinal(TypeInfo(LongBool), Ord(True));
  TestContext.AssertTrue(v.IsOrdinal, '');
  TestContext.AssertTrue((v.AsOrdinal)=(Ord(True)), '');

  v := TValue.FromOrdinal(TypeInfo(TTestEnum), Ord(te1));
  TestContext.AssertTrue(v.IsOrdinal, '');
  TestContext.AssertTrue((v.AsOrdinal)=(Ord(te1)), '');

  v := TValue.FromOrdinal(TypeInfo(AnsiChar), Ord(#20));
  TestContext.AssertTrue(v.IsOrdinal, '');
  TestContext.AssertTrue((v.AsOrdinal)=(Ord(#20)), '');

  v := TValue.FromOrdinal(TypeInfo(WideChar), Ord(#$1234));
  TestContext.AssertTrue(v.IsOrdinal, '');
  TestContext.AssertTrue((v.AsOrdinal)=(Ord(#$1234)), '');

  TestContext.AssertRaises(EInvalidCast, {$ifdef fpc}@{$endif}MakeFromOrdinalNil, '');
  TestContext.AssertRaises(EInvalidCast, {$ifdef fpc}@{$endif}MakeFromOrdinalTObject, '');
  TestContext.AssertRaises(EInvalidCast, {$ifdef fpc}@{$endif}MakeFromOrdinalSet, '');
  TestContext.AssertRaises(EInvalidCast, {$ifdef fpc}@{$endif}MakeFromOrdinalString, '');
end;

procedure TTestValueSimple.TestTryCastUnicodeString;

var
  S: string;
  V, V2: TValue;
begin
  S := 'str';
  V := S;
  TestContext.AssertTrue(V.TryCast(TypeInfo(UnicodeString), V2), 'Cast OK');
end;

type
  TMyManagedRecord = record
    I: IntPtr;
    Intf: IUnknown;
  end;
  TTestIntfObject = class(TInterfacedObject);

procedure TTestValueSimple.TestMakeManagedRecord;


  function GetValue: TValue;
  var
    R: TMyManagedRecord;
  begin
    R.Intf := TTestIntfObject.Create;
    Result := TValue.{$ifdef fpc}specialize{$endif} From<TMyManagedRecord>(R);
  end;
var
  P: Pointer;
  R: TMyManagedRecord;
  V: TValue;
begin
  V := GetValue();
  P := AllocMem(64);
  R := V.{$ifdef fpc}specialize{$endif} AsType<TMyManagedRecord>;
  TestContext.AssertTrue((R.Intf as TTestIntfObject).RefCount >= 2, 'RefCount should be >= 2. One ref in in V, and another one is in R');
  FreeMem(P);
end;

procedure TTestValueSimple.TestMakeStaticArrayOfManagedRecord;
type
  TArrayOfRec = array[0..0] of TMyManagedRecord;

  function GetValue: TValue;
  var
    Arr: TArrayOfRec;
  begin
    Arr[0].Intf := TTestIntfObject.Create;
    Result := TValue.{$ifdef fpc}specialize{$endif} From<TArrayOfRec>(Arr);
  end;

var
  P: Pointer;
  Arr: TArrayOfRec;
  V: TValue;
begin
  V := GetValue();
  P := AllocMem(64);
  Arr := V.{$ifdef fpc}specialize{$endif} AsType<TArrayOfRec>;
  TestContext.AssertTrue((Arr[0].Intf as TTestIntfObject).RefCount >= 2, 'RefCount should be >= 2. One ref in in V, and another one is in Arr');
  FreeMem(P);
end;

{ TTestValueArray }


{$ifdef fpc}
procedure TTestValueArray.TestOpenArrayToDyn;



  procedure OpenArrayProc(aArr: array of LongInt);
  var
    value: TValue;
  begin
{$ifndef InLazIDE}
    value := specialize OpenArrayToDynArrayValue<LongInt>(aArr);
{$endif}
    TestContext.AssertTrue((value.IsArray)=(True), '');
    TestContext.AssertTrue((value.IsOpenArray)=(False), '');
    TestContext.AssertTrue((value.IsObject)=(False), '');
    TestContext.AssertTrue((value.IsOrdinal)=(False), '');
    TestContext.AssertTrue((value.IsClass)=(False), '');
    TestContext.AssertTrue((value.GetArrayLength)=(2), '');
    TestContext.AssertTrue((value.GetArrayElement(0).AsInteger)=(42), '');
    TestContext.AssertTrue((value.GetArrayElement(1).AsInteger)=(84), '');
    value.SetArrayElement(0, Integer(21));
    { since this is a copy the original array is not modified! }
    TestContext.AssertTrue((aArr[0])=(42), '');
  end;

begin
  OpenArrayProc([42, 84]);
end;
{$endif}

procedure TTestValueGeneral.TestDataSize;
var
  u8: UInt8;
  u16: UInt16;
  u32: UInt32;
  u64: UInt64;
  s8: Int8;
  s16: Int16;
  s32: Int32;
  s64: Int64;
  f32: Single;
  f64: Double;
{$ifdef FPC_HAS_TYPE_EXTENDED}
  f80: Extended;
{$endif}
  fco: Comp;
  fcu: Currency;
  ss: ShortString;
  sa: AnsiString;
  su: UnicodeString;
  sw: WideString;
  o: TObject;
  c: TClass;
  i: IInterface;
  ad: TArrayOfLongintDyn;
  _as: TArrayOfLongintStatic;
  b8: Boolean;
{$ifdef fpc}
  b16: Boolean16;
  b32: Boolean32;
  b64: Boolean64;
{$endif}
  bl8: ByteBool;
  bl16: WordBool;
  bl32: LongBool;
{$ifdef fpc}
  bl64: QWordBool;
{$endif}
  e: TTestEnum;
  s: TTestSet;
  t: TTestRecord;
  p: Pointer;
  proc: TTestProc;
  method: TTestMethod;

  value: TValue;
begin
  u8:=245;
  TValue.Make(@u8, TypeInfo(UInt8), value);
  TestContext.AssertTrue((1)=(value.DataSize), 'Size of UInt8 differs');
  u16:=789;
  TValue.Make(@u16, TypeInfo(UInt16), value);
  TestContext.AssertTrue((2)=(value.DataSize), 'Size of UInt16 differs');
  u32:=568789;
  TValue.Make(@u32, TypeInfo(UInt32), value);
  TestContext.AssertTrue((4)=(value.DataSize), 'Size of UInt32 differs');
  u64:=$abdcefadbcef;
  TValue.Make(@u64, TypeInfo(UInt64), value);
  TestContext.AssertTrue((8)=(value.DataSize), 'Size of UInt64 differs');
  s8:=-32;
  TValue.Make(@s8, TypeInfo(Int8), value);
  TestContext.AssertTrue((1)=(value.DataSize), 'Size of Int8 differs');
  s16:=-5345;
  TValue.Make(@s16, TypeInfo(Int16), value);
  TestContext.AssertTrue((2)=(value.DataSize), 'Size of Int16 differs');
  s32:=-234567;
  TValue.Make(@s32, TypeInfo(Int32), value);
  TestContext.AssertTrue((4)=(value.DataSize), 'Size of Int32 differs');
  s64:=23456789012;
  TValue.Make(@s64, TypeInfo(Int64), value);
  TestContext.AssertTrue((8)=(value.DataSize), 'Size of Int64 differs');
  b8:=false;
  TValue.Make(@b8, TypeInfo(Boolean), value);
  TestContext.AssertTrue((1)=(value.DataSize), 'Size of Boolean differs');
{$ifdef fpc}
  b16:=true;
  TValue.Make(@b16, TypeInfo(Boolean16), value);
  TestContext.AssertTrue((2)=(value.DataSize), 'Size of Boolean16 differs');
  b32:=false;
  TValue.Make(@b32, TypeInfo(Boolean32), value);
  TestContext.AssertTrue((4)=(value.DataSize), 'Size of Boolean32 differs');
  b64:=true;
  TValue.Make(@b64, TypeInfo(Boolean64), value);
  TestContext.AssertTrue((8)=(value.DataSize), 'Size of Boolean64 differs');
{$endif}
  bl8:=true;
  TValue.Make(@bl8, TypeInfo(ByteBool), value);
  TestContext.AssertTrue((1)=(value.DataSize), 'Size of ByteBool differs');
  bl16:=false;
  TValue.Make(@bl16, TypeInfo(WordBool), value);
  TestContext.AssertTrue((2)=(value.DataSize), 'Size of WordBool differs');
  bl32:=false;
  TValue.Make(@bl32, TypeInfo(LongBool), value);
  TestContext.AssertTrue((4)=(value.DataSize), 'Size of LongBool differs');
{$ifdef fpc}
  bl64:=true;
  TValue.Make(@bl64, TypeInfo(QWordBool), value);
  TestContext.AssertTrue((8)=(value.DataSize), 'Size of QWordBool differs');
{$endif}
  f32:=4.567;
  TValue.Make(@f32, TypeInfo(Single), value);
  TestContext.AssertTrue((4)=(value.DataSize), 'Size of Single differs');
  f64:=-3456.678;
  TValue.Make(@f64, TypeInfo(Double), value);
  TestContext.AssertTrue((8)=(value.DataSize), 'Size of Double differs');
{$ifdef FPC_HAS_TYPE_EXTENDED}
  f80:=-2345.678;
  TValue.Make(@f80, TypeInfo(Extended), value);
  TestContext.AssertTrue((10)=(value.DataSize), 'Size of Extended differs');
{$endif}
  fcu:=56.78;
  TValue.Make(@fcu, TypeInfo(Currency), value);
  TestContext.AssertTrue((SizeOf(Currency))=(value.DataSize), 'Size of Currency differs');
  fco:=456;
  TValue.Make(@fco, TypeInfo(Comp), value);
  TestContext.AssertTrue((SizeOf(Comp))=(value.DataSize), 'Size of Comp differs');
  ss := '';
  TValue.Make(@ss, TypeInfo(ShortString), value);
  TestContext.AssertTrue((254)=(value.DataSize), 'Size ofShortString differs');
  sa:= '';
  TValue.Make(@sa, TypeInfo(AnsiString), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of AnsiString differs');
  sw := '';
  TValue.Make(@sw, TypeInfo(WideString), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of WideString differs');
  su:='';
  TValue.Make(@su, TypeInfo(UnicodeString), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of UnicodeString differs');
  o := TTestValueClass.Create;
  TValue.Make(@o, TypeInfo(TObject), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of TObject differs');
  o.Free;
  c := TObject;
  TValue.Make(@c, TypeInfo(TClass), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of TClass differs');
  i := Nil;
  TValue.Make(@i, TypeInfo(IInterface), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of IInterface differs');
  TValue.Make(@t, TypeInfo(TTestRecord), value);
  TestContext.AssertTrue((SizeOf(TTestRecord))=(value.DataSize), 'Size of TTestRecord differs');
  proc := Nil;
  TValue.Make(@proc, TypeInfo(TTestProc), value);
  TestContext.AssertTrue((SizeOf(TTestProc))=(value.DataSize), 'Size of TTestProc differs');
  method := Nil;
  TValue.Make(@method, TypeInfo(TTestMethod), value);
  TestContext.AssertTrue((SizeOf(TTestMethod))=(value.DataSize), 'Size of TTestMethod differs');
  TValue.Make(@_as, TypeInfo(TArrayOfLongintStatic), value);
  TestContext.AssertTrue((SizeOf(TArrayOfLongintStatic))=(value.DataSize), 'Size of TArrayOfLongintStatic differs');
  TValue.Make(@ad, TypeInfo(TArrayOfLongintDyn), value);
  TestContext.AssertTrue((SizeOf(TArrayOfLongintDyn))=(value.DataSize), 'Size of TArrayOfLongintDyn differs');
  e:=low(TTestEnum);
  TValue.Make(@e, TypeInfo(TTestEnum), value);
  TestContext.AssertTrue((SizeOf(TTestEnum))=(value.DataSize), 'Size of TTestEnum differs');
  s:=[low(TTestEnum),high(TTestEnum)];
  TValue.Make(@s, TypeInfo(TTestSet), value);
  TestContext.AssertTrue((SizeOf(TTestSet))=(value.DataSize), 'Size of TTestSet differs');
  p := Self;
  TValue.Make(@p, TypeInfo(Pointer), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of Pointer differs');
end;

procedure TTestValueGeneral.TestDataSizeEmpty;
var
  value: TValue;
begin
  TValue.Make(Nil, TypeInfo(UInt8), value);
  TestContext.AssertTrue((1)=(value.DataSize), 'Size of UInt8 differs');
  TValue.Make(Nil, TypeInfo(UInt16), value);
  TestContext.AssertTrue((2)=(value.DataSize), 'Size of UInt16 differs');
  TValue.Make(Nil, TypeInfo(UInt32), value);
  TestContext.AssertTrue((4)=(value.DataSize), 'Size of UInt32 differs');
  TValue.Make(Nil, TypeInfo(UInt64), value);
  TestContext.AssertTrue((8)=(value.DataSize), 'Size of UInt64 differs');
  TValue.Make(Nil, TypeInfo(Int8), value);
  TestContext.AssertTrue((1)=(value.DataSize), 'Size of Int8 differs');
  TValue.Make(Nil, TypeInfo(Int16), value);
  TestContext.AssertTrue((2)=(value.DataSize), 'Size of Int16 differs');
  TValue.Make(Nil, TypeInfo(Int32), value);
  TestContext.AssertTrue((4)=(value.DataSize), 'Size of Int32 differs');
  TValue.Make(Nil, TypeInfo(Int64), value);
  TestContext.AssertTrue((8)=(value.DataSize), 'Size of Int64 differs');
  TValue.Make(Nil, TypeInfo(Boolean), value);
  TestContext.AssertTrue((1)=(value.DataSize), 'Size of Boolean differs');
{$ifdef fpc}
  TValue.Make(Nil, TypeInfo(Boolean16), value);
  TestContext.AssertTrue((2)=(value.DataSize), 'Size of Boolean16 differs');
  TValue.Make(Nil, TypeInfo(Boolean32), value);
  TestContext.AssertTrue((4)=(value.DataSize), 'Size of Boolean32 differs');
  TValue.Make(Nil, TypeInfo(Boolean64), value);
  TestContext.AssertTrue((8)=(value.DataSize), 'Size of Boolean64 differs');
{$endif}
  TValue.Make(Nil, TypeInfo(ByteBool), value);
  TestContext.AssertTrue((1)=(value.DataSize), 'Size of ByteBool differs');
  TValue.Make(Nil, TypeInfo(WordBool), value);
  TestContext.AssertTrue((2)=(value.DataSize), 'Size of WordBool differs');
  TValue.Make(Nil, TypeInfo(LongBool), value);
  TestContext.AssertTrue((4)=(value.DataSize), 'Size of LongBool differs');
{$ifdef fpc}
  TValue.Make(Nil, TypeInfo(QWordBool), value);
  TestContext.AssertTrue((8)=(value.DataSize), 'Size of QWordBool differs');
{$endif}
  TValue.Make(Nil, TypeInfo(Single), value);
  TestContext.AssertTrue((4)=(value.DataSize), 'Size of Single differs');
  TValue.Make(Nil, TypeInfo(Double), value);
  TestContext.AssertTrue((8)=(value.DataSize), 'Size of Double differs');
{$ifdef FPC_HAS_TYPE_EXTENDED}
  TValue.Make(Nil, TypeInfo(Extended), value);
  TestContext.AssertTrue((10)=(value.DataSize), 'Size of Extended differs');
{$endif}
  TValue.Make(Nil, TypeInfo(Currency), value);
  TestContext.AssertTrue((SizeOf(Currency))=(value.DataSize), 'Size of Currency differs');
  TValue.Make(Nil, TypeInfo(Comp), value);
  TestContext.AssertTrue((SizeOf(Comp))=(value.DataSize), 'Size of Comp differs');
  TValue.Make(Nil, TypeInfo(ShortString), value);
  TestContext.AssertTrue((254)=(value.DataSize), 'Size of ShortString differs');
  TValue.Make(Nil, TypeInfo(AnsiString), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of Pointer differs');
  TValue.Make(Nil, TypeInfo(WideString), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of WideString differs');
  TValue.Make(Nil, TypeInfo(UnicodeString), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of UnicodeString differs');
  TValue.Make(Nil, TypeInfo(TObject), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of TObject differs');
  TValue.Make(Nil, TypeInfo(TClass), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of TClass differs');
  TValue.Make(Nil, TypeInfo(IInterface), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of IInterface differs');
  TValue.Make(Nil, TypeInfo(TTestRecord), value);
  TestContext.AssertTrue((SizeOf(TTestRecord))=(value.DataSize), 'Size of TTestRecord differs');
  TValue.Make(Nil, TypeInfo(TTestProc), value);
  TestContext.AssertTrue((SizeOf(TTestProc))=(value.DataSize), 'Size of TTestProc differs');
  TValue.Make(Nil, TypeInfo(TTestMethod), value);
  TestContext.AssertTrue((SizeOf(TTestMethod))=(value.DataSize), 'Size of TTestMethod differs');
  TValue.Make(Nil, TypeInfo(TArrayOfLongintStatic), value);
  TestContext.AssertTrue((SizeOf(TArrayOfLongintStatic))=(value.DataSize), 'Size of TArrayOfLongintStatic differs');
  TValue.Make(Nil, TypeInfo(TArrayOfLongintDyn), value);
  TestContext.AssertTrue((SizeOf(TArrayOfLongintDyn))=(value.DataSize), 'Size of TArrayOfLongintDyn differs');
  TValue.Make(Nil, TypeInfo(TTestEnum), value);
  TestContext.AssertTrue((SizeOf(TTestEnum))=(value.DataSize), 'Size of TTestEnum differs');
  TValue.Make(Nil, TypeInfo(TTestSet), value);
  TestContext.AssertTrue((SizeOf(TTestSet))=(value.DataSize), 'Size of TTestSet differs');
  TValue.Make(Nil, TypeInfo(Pointer), value);
  TestContext.AssertTrue((SizeOf(Pointer))=(value.DataSize), 'Size of Pointer differs');
end;

procedure TTestValueGeneral.TestIsManaged;
begin
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(ansistring))), 'IsManaged for tkAString');
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(widestring))), 'IsManaged for tkWString');
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(Variant))), 'IsManaged for tkVariant');
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(TArrayOfManagedRec))), 'IsManaged for tkArray (with managed ElType)');
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(TArrayOfString))), 'IsManaged for tkArray (with managed ElType)');
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(TManagedRec))), 'IsManaged for tkRecord');
  {$ifdef fpc}
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(TManagedRecOp))), 'IsManaged for tkRecord');
  {$endif}
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(IInterface))), 'IsManaged for tkInterface');
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(TManagedObj))), 'IsManaged for tkObject');
  {$ifdef fpc}
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(specialize TArray<byte>))), 'IsManaged for tkDynArray');
  {$else}
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(TArray<byte>))), 'IsManaged for tkDynArray');
  {$endif}
  TestContext.AssertTrue((true)=(IsManaged(TypeInfo(unicodestring))), 'IsManaged for tkUString');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(shortstring))), 'IsManaged for tkSString');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(Byte))), 'IsManaged for tkInteger');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(Char))), 'IsManaged for tkChar');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(TTestEnum))), 'IsManaged for tkEnumeration');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(Single))), 'IsManaged for tkFloat');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(TTestSet))), 'IsManaged for tkSet');
  {$ifdef fpc}
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(TTestMethod))), 'IsManaged for tkMethod');
  {$else}
  { Delphi bug (or sabotage). For some reason Delphi considers method pointers to be managed (only in newer versions, probably since XE7) :/ }
  TestContext.AssertTrue((RTLVersion >= 28)=(IsManaged(TypeInfo(TTestMethod))), 'IsManaged for tkMethod');
  {$endif}
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(TArrayOfByte))), 'IsManaged for tkArray (with non managed ElType)');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(TArrayOfNonManagedRec))), 'IsManaged for tkArray (with non managed ElType)');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(TNonManagedRec))), 'IsManaged for tkRecord');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(TObject))), 'IsManaged for tkClass');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(TNonManagedObj))), 'IsManaged for tkObject');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(WideChar))), 'IsManaged for tkWChar');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(Boolean))), 'IsManaged for tkBool');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(Int64))), 'IsManaged for tkInt64');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(UInt64))), 'IsManaged for tkQWord');
  {$ifdef fpc}
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(ICORBATest))), 'IsManaged for tkInterfaceRaw');
  {$endif}
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(TTestProc))), 'IsManaged for tkProcVar');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(TTestHelper))), 'IsManaged for tkHelper');
  {$ifdef fpc}
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(file))), 'IsManaged for tkFile');
  {$endif}
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(TClass))), 'IsManaged for tkClassRef');
  TestContext.AssertTrue((false)=(IsManaged(TypeInfo(Pointer))), 'IsManaged for tkPointer');
  TestContext.AssertTrue((false)=(IsManaged(nil)), 'IsManaged for nil');
end;

Type
  TEnum1 = (en1_1, en1_2);
  TEnum2 = (en2_1);
  TEnum3 = en1_1..en1_1;

procedure TTestValueGeneral.TestCasts;

var
  TempV,T1,T2,T3 : TValue;

begin
  T1:=TValue. specialize From<TEnum1>(en1_1);
  T2:=T1. specialize Cast<TEnum3>;
//  T3:=T2. specialize AsType<TEnum3>;
  TestContext.AssertTrue((en1_1 = T2. specialize AsType<TEnum3>), 'en1_1 = (TValue.From<TEnum1>(en1_1).Cast<TEnum3>.AsType<TEnum3>)');
  TestContext.AssertTrue(not (TValue. specialize From<Integer>(32).TryCast(TypeInfo(AnsiChar), TempV)), 'not (TValue.From<Integer>(32).TryCast(TypeInfo(AnsiChar), V)');
  TestContext.AssertTrue(not (TValue. specialize From<Integer>(32).TryCast(TypeInfo(WideChar), TempV)), 'not (TValue.From<Integer>(32).TryCast(TypeInfo(WideChar), V)');
{$ifdef fpc}
  TestContext.AssertTrue(not (TValue. specialize From<Integer>(32).TryCast(TypeInfo(UnicodeChar), TempV)), 'not (TValue.From<Integer>(32).TryCast(TypeInfo(UnicodeChar), V)');
{$endif}
  TestContext.AssertTrue(Byte(397) = (TValue. specialize From<Integer>(397). specialize Cast<Byte>(). specialize AsType<Byte>), 'Byte(397) = (TValue.From<Integer>(397).Cast<Byte>().AsType<Byte>)');
  TestContext.AssertTrue(32 = (TValue. specialize From<Byte>(32). specialize Cast<Integer>(). specialize AsType<Integer>), '32 = (TValue.From<Byte>(32).Cast<Integer>().AsType<Integer>)');

  TestContext.AssertTrue('test_str' = TValue.{$ifdef fpc}specialize{$endif} From<ShortString>('test_str')
              .{$ifdef fpc}specialize{$endif} Cast<AnsiString>
              .{$ifdef fpc}specialize{$endif} AsType<AnsiString>, 'TValue.From<shortring>.Cast<AnsiString> failed');
end;

procedure TTestValueGeneral.TestAssignPointer;
var
  V : TValue;
begin
  V:=Pointer(Nil);
  TestContext.AssertTrue((TypeInfo(Pointer))=(V.TypeInfo), 'Correct type info');
end;

procedure TTestValueGeneral.TestAssignDateTime;
var
  dt: TDateTime;
  v: TValue;
begin
  dt := Now;
  v := dt;
  TestContext.AssertTrue((TypeInfo(TDateTime))=(V.TypeInfo), 'Incorrect type info');
  TestContext.AssertTrue((dt)=(V.AsDateTime), 'Incorrect value');
end;

procedure TTestValueGeneral.TestAssignDate;
var
  d: TDate;
  v: TValue;
begin
  d := Date;
  v := d;
  TestContext.AssertTrue((TypeInfo(TDate))=(V.TypeInfo), 'Incorrect type info');
  TestContext.AssertTrue((d)=(V.AsDateTime), 'Incorrect value');
end;

procedure TTestValueGeneral.TestAssignTime;
var
  t: System.TTime;
  v: TValue;
begin
  t := Time;
  v := t;
  TestContext.AssertTrue((TypeInfo(System.TTime))=(V.TypeInfo), 'Incorrect type info');
  TestContext.AssertTrue((t)=(V.AsDateTime), 'Incorrect value');
end;

procedure TTestValueGeneral.TestReferenceRawData;
var
  value: TValue;
  str: String;
  intf: IInterface;
  i: LongInt;
  test: TTestRecord;
  arrdyn: TArrayOfLongintDyn;
  arrstat: TArrayOfLongintStatic;
begin
  str := 'Hello World';
  UniqueString(str);
  TValue.Make(@str, TypeInfo(String), value);
  TestContext.AssertTrue(PPointer(value.GetReferenceToRawData)^ = Pointer(str), 'Reference to string data differs');

  intf := TInterfacedObject.Create;
  TValue.Make(@intf, TypeInfo(IInterface), value);
  TestContext.AssertTrue(PPointer(value.GetReferenceToRawData)^ = Pointer(intf), 'Reference to interface data differs');

  i := 42;
  TValue.Make(@i, TypeInfo(LongInt), value);
  TestContext.AssertTrue(value.GetReferenceToRawData <> @i, 'Reference to longint is equal');
  TestContext.AssertTrue(PLongInt(value.GetReferenceToRawData)^ = PLongInt(@i)^, 'Reference to longint data differs');

  test.value1 := 42;
  test.value2 := 'Hello World';
  TValue.Make(@test, TypeInfo(TTestRecord), value);
  TestContext.AssertTrue(value.GetReferenceToRawData <> @test, 'Reference to record is equal');
  TestContext.AssertTrue(PTestRecord(value.GetReferenceToRawData)^.value1 = PTestRecord(@test)^.value1, 'Reference to record data value1 differs');
  TestContext.AssertTrue(PTestRecord(value.GetReferenceToRawData)^.value2 = PTestRecord(@test)^.value2, 'Reference to record data value2 differs');

  SetLength(arrdyn, 3);
  arrdyn[0] := 42;
  arrdyn[1] := 23;
  arrdyn[2] := 49;
  TValue.Make(@arrdyn, TypeInfo(TArrayOfLongintDyn), value);
  TestContext.AssertTrue(PPointer(value.GetReferenceToRawData)^ = Pointer(arrdyn), 'Reference to dynamic array data differs');

  arrstat[0] := 42;
  arrstat[1] := 23;
  arrstat[2] := 49;
  arrstat[3] := 59;
  TValue.Make(@arrstat, TypeInfo(TArrayOfLongintStatic), value);
  TestContext.AssertTrue(value.GetReferenceToRawData <> @arrstat, 'Reference to static array is equal');
  TestContext.AssertTrue(PLongInt(value.GetReferenceToRawData)^ = PLongInt(@arrstat)^, 'Reference to static array data differs');
end;

procedure TTestValueGeneral.TestReferenceRawDataEmpty;
var
  value: TValue;
begin
  TValue.Make(Nil, TypeInfo(String), value);
  TestContext.AssertTrue(Assigned(value.GetReferenceToRawData()), 'Reference to empty String is not assigned');
  TestContext.AssertTrue(not Assigned(PPointer(value.GetReferenceToRawData)^), 'Empty String data is assigned');

  TValue.Make(Nil, TypeInfo(IInterface), value);
  TestContext.AssertTrue(Assigned(value.GetReferenceToRawData()), 'Reference to empty interface is not assigned');
  TestContext.AssertTrue(not Assigned(PPointer(value.GetReferenceToRawData)^), 'Empty interface data is assigned');

  TValue.Make(Nil, TypeInfo(LongInt), value);
  TestContext.AssertTrue(Assigned(value.GetReferenceToRawData()), 'Reference to empty LongInt is not assigned');
  TestContext.AssertTrue(PLongInt(value.GetReferenceToRawData)^ = 0, 'Empty longint data is not 0');

  TValue.Make(Nil, TypeInfo(TTestRecord), value);
  TestContext.AssertTrue(Assigned(value.GetReferenceToRawData()), 'Reference to empty record is not assigned');
  TestContext.AssertTrue(PTestRecord(value.GetReferenceToRawData)^.value1 = 0, 'Empty record data value1 is not 0');
  TestContext.AssertTrue(PTestRecord(value.GetReferenceToRawData)^.value2 = '', 'Empty record data value2 is not empty');

  TValue.Make(Nil, TypeInfo(TArrayOfLongintDyn), value);
  TestContext.AssertTrue(Assigned(value.GetReferenceToRawData()), 'Reference to empty dynamic array is not assigned');
  TestContext.AssertTrue(not Assigned(PPointer(value.GetReferenceToRawData)^), 'Empty dynamic array data is assigned');

  TValue.Make(Nil, TypeInfo(TArrayOfLongintStatic), value);
  TestContext.AssertTrue(Assigned(value.GetReferenceToRawData()), 'Reference to empty static array is not assigned');
  TestContext.AssertTrue(PLongInt(value.GetReferenceToRawData)^ = 0, 'Empty static array data is not 0');
end;


constructor TTestValueGeneral.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestValueSimple.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestValueArray.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestValueVariant.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestValueGeneralTestDataSize(AContext: TNXTestContext);
var lFixture: TTestValueGeneral;
begin
  lFixture:=TTestValueGeneral.Create(AContext, 'TestDataSize');
  try
    lFixture.TestDataSize;
  finally lFixture.Free; end;
end;

procedure RunTTestValueGeneralTestDataSizeEmpty(AContext: TNXTestContext);
var lFixture: TTestValueGeneral;
begin
  lFixture:=TTestValueGeneral.Create(AContext, 'TestDataSizeEmpty');
  try
    lFixture.TestDataSizeEmpty;
  finally lFixture.Free; end;
end;

procedure RunTTestValueGeneralTestReferenceRawData(AContext: TNXTestContext);
var lFixture: TTestValueGeneral;
begin
  lFixture:=TTestValueGeneral.Create(AContext, 'TestReferenceRawData');
  try
    lFixture.TestReferenceRawData;
  finally lFixture.Free; end;
end;

procedure RunTTestValueGeneralTestReferenceRawDataEmpty(AContext: TNXTestContext);
var lFixture: TTestValueGeneral;
begin
  lFixture:=TTestValueGeneral.Create(AContext, 'TestReferenceRawDataEmpty');
  try
    lFixture.TestReferenceRawDataEmpty;
  finally lFixture.Free; end;
end;

procedure RunTTestValueGeneralTestIsManaged(AContext: TNXTestContext);
var lFixture: TTestValueGeneral;
begin
  lFixture:=TTestValueGeneral.Create(AContext, 'TestIsManaged');
  try
    lFixture.TestIsManaged;
  finally lFixture.Free; end;
end;

procedure RunTTestValueGeneralTestCasts(AContext: TNXTestContext);
var lFixture: TTestValueGeneral;
begin
  lFixture:=TTestValueGeneral.Create(AContext, 'TestCasts');
  try
    lFixture.TestCasts;
  finally lFixture.Free; end;
end;

procedure RunTTestValueGeneralTestAssignPointer(AContext: TNXTestContext);
var lFixture: TTestValueGeneral;
begin
  lFixture:=TTestValueGeneral.Create(AContext, 'TestAssignPointer');
  try
    lFixture.TestAssignPointer;
  finally lFixture.Free; end;
end;

procedure RunTTestValueGeneralTestAssignDateTime(AContext: TNXTestContext);
var lFixture: TTestValueGeneral;
begin
  lFixture:=TTestValueGeneral.Create(AContext, 'TestAssignDateTime');
  try
    lFixture.TestAssignDateTime;
  finally lFixture.Free; end;
end;

procedure RunTTestValueGeneralTestAssignDate(AContext: TNXTestContext);
var lFixture: TTestValueGeneral;
begin
  lFixture:=TTestValueGeneral.Create(AContext, 'TestAssignDate');
  try
    lFixture.TestAssignDate;
  finally lFixture.Free; end;
end;

procedure RunTTestValueGeneralTestAssignTime(AContext: TNXTestContext);
var lFixture: TTestValueGeneral;
begin
  lFixture:=TTestValueGeneral.Create(AContext, 'TestAssignTime');
  try
    lFixture.TestAssignTime;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestIsType(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestIsType');
  try
    lFixture.TestIsType;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeNil(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeNil');
  try
    lFixture.TestMakeNil;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeObject(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeObject');
  try
    lFixture.TestMakeObject;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeSingle(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeSingle');
  try
    lFixture.TestMakeSingle;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeDouble(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeDouble');
  try
    lFixture.TestMakeDouble;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeExtended(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeExtended');
  try
    lFixture.TestMakeExtended;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeCurrency(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeCurrency');
  try
    lFixture.TestMakeCurrency;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeComp(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeComp');
  try
    lFixture.TestMakeComp;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeEnum(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeEnum');
  try
    lFixture.TestMakeEnum;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeAnsiChar(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeAnsiChar');
  try
    lFixture.TestMakeAnsiChar;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeWideChar(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeWideChar');
  try
    lFixture.TestMakeWideChar;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeNativeInt(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeNativeInt');
  try
    lFixture.TestMakeNativeInt;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeVariant(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeVariant');
  try
    lFixture.TestMakeVariant;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeGenericNil(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeGenericNil');
  try
    lFixture.TestMakeGenericNil;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeGenericLongInt(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeGenericLongInt');
  try
    lFixture.TestMakeGenericLongInt;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeGenericString(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeGenericString');
  try
    lFixture.TestMakeGenericString;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeGenericObject(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeGenericObject');
  try
    lFixture.TestMakeGenericObject;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeGenericDouble(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeGenericDouble');
  try
    lFixture.TestMakeGenericDouble;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeGenericAnsiChar(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeGenericAnsiChar');
  try
    lFixture.TestMakeGenericAnsiChar;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeGenericWideChar(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeGenericWideChar');
  try
    lFixture.TestMakeGenericWideChar;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestFromOrdinal(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestFromOrdinal');
  try
    lFixture.TestFromOrdinal;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestTryCastUnicodeString(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestTryCastUnicodeString');
  try
    lFixture.TestTryCastUnicodeString;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeManagedRecord(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeManagedRecord');
  try
    lFixture.TestMakeManagedRecord;
  finally lFixture.Free; end;
end;

procedure RunTTestValueSimpleTestMakeStaticArrayOfManagedRecord(AContext: TNXTestContext);
var lFixture: TTestValueSimple;
begin
  lFixture:=TTestValueSimple.Create(AContext, 'TestMakeStaticArrayOfManagedRecord');
  try
    lFixture.TestMakeStaticArrayOfManagedRecord;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantInteger(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantInteger');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantInteger; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantBoolean(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantBoolean');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantBoolean; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantSmallInt(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantSmallInt');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantSmallInt; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantOleStr(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantOleStr');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantOleStr; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantInt64(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantInt64');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantInt64; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantQWord(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantQWord');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantQWord; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantShortInt(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantShortInt');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantShortInt; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantByte(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantByte');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantByte; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantWord(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantWord');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantWord; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantLongWord(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantLongWord');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantLongWord; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantSingle(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantSingle');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantSingle; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantDouble(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantDouble');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantDouble; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantDate(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantDate');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantDate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantDispatch(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantDispatch');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantDispatch; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantError(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantError');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantError; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantUnknown(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantUnknown');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantUnknown; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantCurrency(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantCurrency');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantCurrency; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantString(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantString');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantString; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVariantUnicodeString(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVariantUnicodeString');
  try
    lFixture.SetUp;
    try lFixture.TestFromVariantUnicodeString; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarrecInteger(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarrecInteger');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarrecInteger; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarrecBoolean(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarrecBoolean');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarrecBoolean; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecChar(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecChar');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecChar; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecExtended(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecExtended');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecExtended; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecString(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecString');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecString; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecPointer(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecPointer');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecPointer; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecPChar(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecPChar');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecPChar; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecObject(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecObject');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecObject; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecClass(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecClass');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecClass; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecWideChar(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecWideChar');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecWideChar; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecPWideChar(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecPWideChar');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecPWideChar; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecAnsiString(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecAnsiString');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecAnsiString; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecCurrency(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecCurrency');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecCurrency; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecVariant(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecVariant');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecVariant; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecInterface(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecInterface');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecInterface; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecWideString(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecWideString');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecWideString; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecInt64(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecInt64');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecInt64; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecQWord(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecQWord');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecQWord; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestFromVarRecUnicodeString(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestFromVarRecUnicodeString');
  try
    lFixture.SetUp;
    try lFixture.TestFromVarRecUnicodeString; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestArrayOfConstToTValue(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestArrayOfConstToTValue');
  try
    lFixture.SetUp;
    try lFixture.TestArrayOfConstToTValue; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestCastAnsiString(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestCastAnsiString');
  try
    lFixture.SetUp;
    try lFixture.TestCastAnsiString; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

{$IFNDEF FPC_WIDESTRING_EQUAL_UNICODESTRING}
procedure RunTTestValueVariantTestCastUnicodeString(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestCastUnicodeString');
  try
    lFixture.SetUp;
    try lFixture.TestCastUnicodeString; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;
{$ENDIF}


procedure RunTTestValueVariantTestCastWideString(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestCastWideString');
  try
    lFixture.SetUp;
    try lFixture.TestCastWideString; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestValueVariantTestCastShortString(AContext: TNXTestContext);
var lFixture: TTestValueVariant;
begin
  lFixture:=TTestValueVariant.Create(AContext, 'TestCastShortString');
  try
    lFixture.SetUp;
    try lFixture.TestCastShortString; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertestsrttivalueTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tests.rtti.value.TTestValueGeneral');
  lSuite.AddTest('TestDataSize', @RunTTestValueGeneralTestDataSize, 'rtti');
  lSuite.AddTest('TestDataSizeEmpty', @RunTTestValueGeneralTestDataSizeEmpty, 'rtti');
  lSuite.AddTest('TestReferenceRawData', @RunTTestValueGeneralTestReferenceRawData, 'rtti');
  lSuite.AddTest('TestReferenceRawDataEmpty', @RunTTestValueGeneralTestReferenceRawDataEmpty, 'rtti');
  lSuite.AddTest('TestIsManaged', @RunTTestValueGeneralTestIsManaged, 'rtti');
  lSuite.AddTest('TestCasts', @RunTTestValueGeneralTestCasts, 'rtti');
  lSuite.AddTest('TestAssignPointer', @RunTTestValueGeneralTestAssignPointer, 'rtti');
  lSuite.AddTest('TestAssignDateTime', @RunTTestValueGeneralTestAssignDateTime, 'rtti');
  lSuite.AddTest('TestAssignDate', @RunTTestValueGeneralTestAssignDate, 'rtti');
  lSuite.AddTest('TestAssignTime', @RunTTestValueGeneralTestAssignTime, 'rtti');
  lSuite:=ARegistry.AddSuite('tests.rtti.value.TTestValueSimple');
  lSuite.AddTest('TestIsType', @RunTTestValueSimpleTestIsType, 'rtti');
  lSuite.AddTest('TestMakeNil', @RunTTestValueSimpleTestMakeNil, 'rtti');
  lSuite.AddTest('TestMakeObject', @RunTTestValueSimpleTestMakeObject, 'rtti');
  lSuite.AddTest('TestMakeSingle', @RunTTestValueSimpleTestMakeSingle, 'rtti');
  lSuite.AddTest('TestMakeDouble', @RunTTestValueSimpleTestMakeDouble, 'rtti');
  lSuite.AddTest('TestMakeExtended', @RunTTestValueSimpleTestMakeExtended, 'rtti');
  lSuite.AddTest('TestMakeCurrency', @RunTTestValueSimpleTestMakeCurrency, 'rtti');
  lSuite.AddTest('TestMakeComp', @RunTTestValueSimpleTestMakeComp, 'rtti');
  lSuite.AddTest('TestMakeEnum', @RunTTestValueSimpleTestMakeEnum, 'rtti');
  lSuite.AddTest('TestMakeAnsiChar', @RunTTestValueSimpleTestMakeAnsiChar, 'rtti');
  lSuite.AddTest('TestMakeWideChar', @RunTTestValueSimpleTestMakeWideChar, 'rtti');
  lSuite.AddTest('TestMakeNativeInt', @RunTTestValueSimpleTestMakeNativeInt, 'rtti');
  lSuite.AddTest('TestMakeVariant', @RunTTestValueSimpleTestMakeVariant, 'rtti');
  lSuite.AddTest('TestMakeGenericNil', @RunTTestValueSimpleTestMakeGenericNil, 'rtti');
  lSuite.AddTest('TestMakeGenericLongInt', @RunTTestValueSimpleTestMakeGenericLongInt, 'rtti');
  lSuite.AddTest('TestMakeGenericString', @RunTTestValueSimpleTestMakeGenericString, 'rtti');
  lSuite.AddTest('TestMakeGenericObject', @RunTTestValueSimpleTestMakeGenericObject, 'rtti');
  lSuite.AddTest('TestMakeGenericDouble', @RunTTestValueSimpleTestMakeGenericDouble, 'rtti');
  lSuite.AddTest('TestMakeGenericAnsiChar', @RunTTestValueSimpleTestMakeGenericAnsiChar, 'rtti');
  lSuite.AddTest('TestMakeGenericWideChar', @RunTTestValueSimpleTestMakeGenericWideChar, 'rtti');
  lSuite.AddTest('TestFromOrdinal', @RunTTestValueSimpleTestFromOrdinal, 'rtti');
  lSuite.AddTest('TestTryCastUnicodeString', @RunTTestValueSimpleTestTryCastUnicodeString, 'rtti');
  lSuite.AddTest('TestMakeManagedRecord', @RunTTestValueSimpleTestMakeManagedRecord, 'rtti');
  lSuite.AddTest('TestMakeStaticArrayOfManagedRecord', @RunTTestValueSimpleTestMakeStaticArrayOfManagedRecord, 'rtti');
  lSuite:=ARegistry.AddSuite('tests.rtti.value.TTestValueVariant');
  lSuite.AddTest('TestFromVariantInteger', @RunTTestValueVariantTestFromVariantInteger, 'rtti');
  lSuite.AddTest('TestFromVariantBoolean', @RunTTestValueVariantTestFromVariantBoolean, 'rtti');
  lSuite.AddTest('TestFromVariantSmallInt', @RunTTestValueVariantTestFromVariantSmallInt, 'rtti');
  lSuite.AddTest('TestFromVariantOleStr', @RunTTestValueVariantTestFromVariantOleStr, 'rtti');
  lSuite.AddTest('TestFromVariantInt64', @RunTTestValueVariantTestFromVariantInt64, 'rtti');
  lSuite.AddTest('TestFromVariantQWord', @RunTTestValueVariantTestFromVariantQWord, 'rtti');
  lSuite.AddTest('TestFromVariantShortInt', @RunTTestValueVariantTestFromVariantShortInt, 'rtti');
  lSuite.AddTest('TestFromVariantByte', @RunTTestValueVariantTestFromVariantByte, 'rtti');
  lSuite.AddTest('TestFromVariantWord', @RunTTestValueVariantTestFromVariantWord, 'rtti');
  lSuite.AddTest('TestFromVariantLongWord', @RunTTestValueVariantTestFromVariantLongWord, 'rtti');
  lSuite.AddTest('TestFromVariantSingle', @RunTTestValueVariantTestFromVariantSingle, 'rtti');
  lSuite.AddTest('TestFromVariantDouble', @RunTTestValueVariantTestFromVariantDouble, 'rtti');
  lSuite.AddTest('TestFromVariantDate', @RunTTestValueVariantTestFromVariantDate, 'rtti');
  lSuite.AddTest('TestFromVariantDispatch', @RunTTestValueVariantTestFromVariantDispatch, 'rtti');
  lSuite.AddTest('TestFromVariantError', @RunTTestValueVariantTestFromVariantError, 'rtti');
  lSuite.AddTest('TestFromVariantUnknown', @RunTTestValueVariantTestFromVariantUnknown, 'rtti');
  lSuite.AddTest('TestFromVariantCurrency', @RunTTestValueVariantTestFromVariantCurrency, 'rtti');
  lSuite.AddTest('TestFromVariantString', @RunTTestValueVariantTestFromVariantString, 'rtti');
  lSuite.AddTest('TestFromVariantUnicodeString', @RunTTestValueVariantTestFromVariantUnicodeString, 'rtti');
  lSuite.AddTest('TestFromVarrecInteger', @RunTTestValueVariantTestFromVarrecInteger, 'rtti');
  lSuite.AddTest('TestFromVarrecBoolean', @RunTTestValueVariantTestFromVarrecBoolean, 'rtti');
  lSuite.AddTest('TestFromVarRecChar', @RunTTestValueVariantTestFromVarRecChar, 'rtti');
  lSuite.AddTest('TestFromVarRecExtended', @RunTTestValueVariantTestFromVarRecExtended, 'rtti');
  lSuite.AddTest('TestFromVarRecString', @RunTTestValueVariantTestFromVarRecString, 'rtti');
  lSuite.AddTest('TestFromVarRecPointer', @RunTTestValueVariantTestFromVarRecPointer, 'rtti');
  lSuite.AddTest('TestFromVarRecPChar', @RunTTestValueVariantTestFromVarRecPChar, 'rtti');
  lSuite.AddTest('TestFromVarRecObject', @RunTTestValueVariantTestFromVarRecObject, 'rtti');
  lSuite.AddTest('TestFromVarRecClass', @RunTTestValueVariantTestFromVarRecClass, 'rtti');
  lSuite.AddTest('TestFromVarRecWideChar', @RunTTestValueVariantTestFromVarRecWideChar, 'rtti');
  lSuite.AddTest('TestFromVarRecPWideChar', @RunTTestValueVariantTestFromVarRecPWideChar, 'rtti');
  lSuite.AddTest('TestFromVarRecAnsiString', @RunTTestValueVariantTestFromVarRecAnsiString, 'rtti');
  lSuite.AddTest('TestFromVarRecCurrency', @RunTTestValueVariantTestFromVarRecCurrency, 'rtti');
  lSuite.AddTest('TestFromVarRecVariant', @RunTTestValueVariantTestFromVarRecVariant, 'rtti');
  lSuite.AddTest('TestFromVarRecInterface', @RunTTestValueVariantTestFromVarRecInterface, 'rtti');
  lSuite.AddTest('TestFromVarRecWideString', @RunTTestValueVariantTestFromVarRecWideString, 'rtti');
  lSuite.AddTest('TestFromVarRecInt64', @RunTTestValueVariantTestFromVarRecInt64, 'rtti');
  lSuite.AddTest('TestFromVarRecQWord', @RunTTestValueVariantTestFromVarRecQWord, 'rtti');
  lSuite.AddTest('TestFromVarRecUnicodeString', @RunTTestValueVariantTestFromVarRecUnicodeString, 'rtti');
  lSuite.AddTest('TestArrayOfConstToTValue', @RunTTestValueVariantTestArrayOfConstToTValue, 'rtti');
  lSuite.AddTest('TestCastAnsiString', @RunTTestValueVariantTestCastAnsiString, 'rtti');
  {$IFNDEF FPC_WIDESTRING_EQUAL_UNICODESTRING}
  lSuite.AddTest('TestCastUnicodeString', @RunTTestValueVariantTestCastUnicodeString, 'rtti');
  {$ENDIF}
  lSuite.AddTest('TestCastWideString', @RunTTestValueVariantTestCastWideString, 'rtti');
  lSuite.AddTest('TestCastShortString', @RunTTestValueVariantTestCastShortString, 'rtti');
end;

end.
