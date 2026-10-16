unit tests.rtti;

{$ifdef fpc}
{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$endif}

interface

uses
obNXTestContext, obNXTestRegistry, obNXTestSuite, {$IFDEF FPC}
  {$ELSE FPC}
  TestFramework,
{$ENDIF FPC}
  Classes, SysUtils, typinfo,
  Rtti;

type

  { TTestRTTI }

  TTestRTTI= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  public
    //procedure GetTypes;
    procedure GetTypeInteger;
    procedure GetTypePointer;
    procedure GetClassProperties;

    procedure GetClassPropertiesValue;

    procedure TestTRttiTypeProperties;
    procedure TestPropGetValueString;
    procedure TestPropGetValueInteger;
    procedure TestPropGetValueBoolean;
    procedure TestPropGetValueShortString;
    procedure TestPropGetValueProcString;
    procedure TestPropGetValueProcInteger;
    procedure TestPropGetValueProcBoolean;
    procedure TestPropGetValueProcShortString;
    procedure TestPropGetValueObject;
    procedure TestPropGetValueInterface;
    procedure TestPropGetValueFloat;
    procedure TestPropGetValueDynArray;
    procedure TestPropGetValueEnumeration;
    procedure TestPropGetValueChars;
    procedure TestPropGetValueRecord;

    procedure TestPropSetValueString;
    procedure TestPropSetValueInteger;
    procedure TestPropSetValueBoolean;
    procedure TestPropSetValueShortString;
    procedure TestPropSetValueObject;
    procedure TestPropSetValueInterface;
    procedure TestPropSetValueFloat;
    procedure TestPropSetValueDynArray;
    procedure TestPropSetValueEnumeration;
    procedure TestPropSetValueChars;
    procedure TestPropSetValueRecord;

    procedure TestGetValueStringCastError;
    procedure TestGetIsReadable;
    procedure TestIsWritable;

    procedure TestGetAttribute;

    procedure TestInterface;
{$ifdef fpc}
    procedure TestInterfaceRaw;
{$endif}

    procedure TestArray;
    procedure TestDynArray;

    procedure TestProcVar;
    procedure TestMethod;

    procedure TestRawThunk;

  private
{$ifndef fpc}
    procedure Ignore(const aMsg: String);
{$endif}
  end;

  { TTestExtendedRTTI }
  // Note: the tests assume that TObject has no RTTI associated with it.
  // The tests need to be adapted so they will work in both cases.
  TTestExtendedRTTI = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Private
    FCtx: TRttiContext;


    procedure CheckField(aIdx: Integer; aData: TRttiField; aName: String; aKind: TTypeKind; aVisibility: TMemberVisibility;
      aStrict: Boolean=False);
    procedure CheckMethod(aPrefix: string; aIdx: Integer; aData: TRttiMethod; aName: String; aVisibility: TMemberVisibility;
      aStrict: Boolean=False);
    procedure CheckProperty(aIdx: Integer; aData: TRttiProperty; aName: String; aKind: TTypeKind; aVisibility: TMemberVisibility;
      isStrict: Boolean=False);
  public
    Procedure Setup; virtual;
    Procedure TearDown; virtual;
  end;

  { TTestClassExtendedRTTI }

  TTestClassExtendedRTTI = class(TTestExtendedRtti)
  public
    Procedure TestFields;
    Procedure TestDeclaredFields;
    Procedure TestProperties;
    Procedure TestDeclaredMethods;
    Procedure TestMethods;
    Procedure TestMethodByAddress;
    Procedure TestMethodsInherited;
    Procedure TestPrivateFieldAttributes;
    Procedure TestProtectedFieldAttributes;
    Procedure TestPublicFieldAttributes;
    Procedure TestPrivatePropertyAttributes;
    Procedure TestProtectedPropertyAttributes;
    Procedure TestPublicPropertyAttributes;
    Procedure TestPublishedPropertyAttributes;
    procedure TestGetStaticProperty;
    procedure TestSetStaticProperty;
  end;

  { TTestRecordExtendedRTTI }

  TTestRecordExtendedRTTI = class(TTestExtendedRtti)
  public
    Procedure TestFields;
    Procedure TestProperties;
    Procedure TestDeclaredMethods;
    Procedure TestMethods;
    Procedure TestPrivateFieldAttributes;
    Procedure TestPublicFieldAttributes;
  end;


procedure RegistertestsrttiTests(ARegistry: TNXTestRegistry);

implementation

uses
  Tests.Rtti.Util,
  {tests.rtti.exttypes, }
  tests.rtti.attrtypes2,
  tests.rtti.attrtypes,
  tests.rtti.types;




{ Note: GetTypes currently only returns those types that had been acquired using
        GetType, so GetTypes itself can't be really tested currently }
(*procedure TTestRTTI.GetTypes;
var
  LContext: TRttiContext;
  LType: TRttiType;
  IsTestCaseClassFound: boolean;
begin
  LContext := TRttiContext.Create;

  { Enumerate all types declared in the application }
  for LType in LContext.GetTypes() do
    begin
    if LType.Name='TTestRTTI' then
      IsTestCaseClassFound:=true;
    end;
  LContext.Free;
  CheckTrue(IsTestCaseClassFound, 'RTTI information does not contain class of testcase.');
end;*)

{$ifndef fpc}
procedure TTestRTTI.Ignore(const aMsg: string);
begin
  { empty }
end;
{$endif}

procedure TTestRTTI.TestGetValueStringCastError;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AValue: TValue;
  i: integer;
  HadException: boolean;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AString := '12';
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      AValue := ARttiType.GetProperty('astring').GetValue(ATestClass);
      HadException := false;
      try
        i := AValue.AsInteger;
      except
        on E: Exception do
          if E.ClassType=EInvalidCast then
            HadException := true;
      end;
      TestContext.AssertTrue(HadException, 'No or invalid exception on invalid cast');
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;


procedure TTestRTTI.TestGetIsReadable;
var
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
begin
  c := TRttiContext.Create;
  try
    ARttiType := c.GetType(TTestValueClass);
    AProperty := ARttiType.GetProperty('aBoolean');
    TestContext.AssertTrue((AProperty.IsReadable)=(true), '');
    AProperty := ARttiType.GetProperty('aGetBoolean');
    TestContext.AssertTrue((AProperty.IsReadable)=(true), '');
    AProperty := ARttiType.GetProperty('aWriteOnly');
    TestContext.AssertTrue((AProperty.IsReadable)=(False), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestIsWritable;
var
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
begin
  c := TRttiContext.Create;
  try
    ARttiType := c.GetType(TTestValueClass);
    AProperty := ARttiType.GetProperty('aBoolean');
    TestContext.AssertTrue((AProperty.IsWritable)=(true), '');
    AProperty := ARttiType.GetProperty('aGetBoolean');
    TestContext.AssertTrue((AProperty.IsWritable)=(false), '');
    AProperty := ARttiType.GetProperty('aWriteOnly');
    TestContext.AssertTrue((AProperty.IsWritable)=(True), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestGetAttribute;
// TMyAnnotatedClass
// TMyAttribute

var
  c: TRttiContext;
  aType: TRttiType;
  aClass : TMyAnnotatedClass;
  custAttr : TCustomAttribute;
  myAttr : TMyAttribute absolute custattr;

begin
  aType:=nil;
  custAttr:=Nil;
  c := TRttiContext.Create;
  try
    aClass:=TMyAnnotatedClass.Create;
    aType := c.GetType(aClass.ClassInfo);
    custAttr:=aType.GetAttribute(TMyAttribute);
    TestContext.AssertTrue((custAttr.ClassType)=(TMyAttribute), 'Correct class');
    TestContext.AssertTrue(('something')=(MyAttr.value), 'Correct value');
  finally
    aClass.Free;
//    custAttr.Free;
    C.Free;
  end;
end;


procedure TTestRTTI.TestPropGetValueBoolean;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.ABoolean := true;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('aBoolean');
      AValue := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue((true)=(AValue.AsBoolean), '');
      ATestClass.ABoolean := false;
      TestContext.AssertTrue((true)=(AValue.AsBoolean), '');
      TestContext.AssertTrue(('True')=(AValue.ToString), '');
      TestContext.AssertTrue((True)=(AValue.IsOrdinal), '');
      TestContext.AssertTrue((1)=(AValue.AsOrdinal), '');
    finally
      AtestClass.Free;
    end;
      TestContext.AssertTrue((True)=(AValue.AsBoolean), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueShortString;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AShortString := 'Hello World';
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('aShortString');
      AValue := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(('Hello World')=(AValue.AsString), '');
      ATestClass.AShortString := 'Foobar';
      TestContext.AssertTrue(('Hello World')=(AValue.AsString), '');
      TestContext.AssertTrue((False)=(AValue.IsOrdinal), '');
      TestContext.AssertTrue((False)=(AValue.IsObject), '');
      TestContext.AssertTrue((False)=(AValue.IsArray), '');
      TestContext.AssertTrue((False)=(AValue.IsClass), '');
    finally
      AtestClass.Free;
    end;
    TestContext.AssertTrue(('Hello World')=(AValue.AsString), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueInteger;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AInteger := 472349;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('ainteger');
      AValue := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue((472349)=(AValue.AsInteger), '');
      ATestClass.AInteger := 12;
      TestContext.AssertTrue((472349)=(AValue.AsInteger), '');
      TestContext.AssertTrue(('472349')=(AValue.ToString), '');
      TestContext.AssertTrue((True)=(AValue.IsOrdinal), '');
    finally
      AtestClass.Free;
    end;
      TestContext.AssertTrue((472349)=(AValue.AsInteger), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueString;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  i: int64;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AString := 'Hello World';
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('astring');
      AValue := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(('Hello World')=(AValue.AsString), '');
      ATestClass.AString := 'Goodbye World';
      TestContext.AssertTrue(('Hello World')=(AValue.AsString), '');
      TestContext.AssertTrue(('Hello World')=(AValue.ToString), '');
      TestContext.AssertTrue(TypeInfo(string)=AValue.TypeInfo, '');
      TestContext.AssertTrue(AValue.TypeData=GetTypeData(AValue.TypeInfo), '');
      TestContext.AssertTrue(AValue.IsEmpty=false, '');
      TestContext.AssertTrue(AValue.IsObject=false, '');
      TestContext.AssertTrue(AValue.IsClass=false, '');
      TestContext.AssertTrue((AValue.IsOrdinal)=(false), '');
      TestContext.AssertTrue((AValue.TryAsOrdinal(i))=(false), '');
      TestContext.AssertTrue((AValue.IsType(TypeInfo(string)))=(true), '');
      TestContext.AssertTrue((AValue.IsType(TypeInfo(integer)))=(false), '');
      TestContext.AssertTrue((AValue.IsArray)=(false), '');
    finally
      AtestClass.Free;
    end;
    TestContext.AssertTrue(('Hello World')=(AValue.AsString), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueProcBoolean;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.ABoolean := true;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('aGetBoolean');
      AValue := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue((true)=(AValue.AsBoolean), '');
    finally
      AtestClass.Free;
    end;
      TestContext.AssertTrue((True)=(AValue.AsBoolean), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueProcShortString;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AShortString := 'Hello World';
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('aGetShortString');
      AValue := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(('Hello World')=(AValue.AsString), '');
    finally
      AtestClass.Free;
    end;
    TestContext.AssertTrue(('Hello World')=(AValue.AsString), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueObject;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  O: TObject;
begin
  c := TRttiContext.Create;
  O := TObject.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AObject := O;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('AObject');
      AValue := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue((O.GetHashCode)=(AValue.AsObject.GetHashCode), '');
    finally
      AtestClass.Free;
    end;
    TestContext.AssertTrue((O.GetHashCode)=(AValue.AsObject.GetHashCode), '');
  finally
    c.Free;
    O.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueInterface;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  i: IInterface;
begin
  c := TRttiContext.Create;
  i := TInterfacedObject.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AUnknown := i;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('AUnknown');
      AValue := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(i = AValue.AsInterface, '');
    finally
      AtestClass.Free;
    end;
    TestContext.AssertTrue(i = AValue.AsInterface, '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueFloat;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValueS, AValueD, AValueE, AValueC, AValueCm: TValue;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.ASingle := 1.1;
    ATestClass.ADouble := 2.2;
    ATestClass.AExtended := 3.3;
    ATestClass.ACurrency := 4;
    ATestClass.AComp := 5;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');

      AProperty := ARttiType.GetProperty('ASingle');
      AValueS := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(Abs((1.1)-(AValueS.AsExtended))<=(0.001), 'Floating comparison');

      AProperty := ARttiType.GetProperty('ADouble');
      AValueD := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(Abs((2.2)-(AValueD.AsExtended))<=(0.001), 'Floating comparison');

      AProperty := ARttiType.GetProperty('AExtended');
      AValueE := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(Abs((3.3)-(AValueE.AsExtended))<=(0.001), 'Floating comparison');

      AProperty := ARttiType.GetProperty('ACurrency');
      AValueC := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(Abs((4.0)-(AValueC.AsExtended))<=(0.001), 'Floating comparison');

      AProperty := ARttiType.GetProperty('AComp');
      AValueCm := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(Abs((5.0)-(AValueCm.AsExtended))<=(0.001), 'Floating comparison');
    finally
      AtestClass.Free;
    end;

    TestContext.AssertTrue(Abs((1.1)-(AValueS.AsExtended))<=(0.001), 'Floating comparison');
    TestContext.AssertTrue(Abs((2.2)-(AValueD.AsExtended))<=(0.001), 'Floating comparison');
    TestContext.AssertTrue(Abs((3.3)-(AValueE.AsExtended))<=(0.001), 'Floating comparison');
    TestContext.AssertTrue(Abs((4.0)-(AValueC.AsExtended))<=(0.001), 'Floating comparison');
    TestContext.AssertTrue(Abs((5.0)-(AValueCm.AsExtended))<=(0.001), 'Floating comparison');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueDynArray;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  A: TTestDynArray;
begin
  c := TRttiContext.Create;
  A := [1, 2, 3, 4];
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AArray := A;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('AArray');
      AValue := AProperty.GetValue(ATestClass);

      TestContext.AssertTrue((A[0])=(AValue.GetArrayElement(0).AsInteger), '');
      TestContext.AssertTrue((A[1])=(AValue.GetArrayElement(1).AsInteger), '');
      TestContext.AssertTrue((A[2])=(AValue.GetArrayElement(2).AsInteger), '');
      TestContext.AssertTrue((A[3])=(AValue.GetArrayElement(3).AsInteger), '');
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueEnumeration;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AEnumeration := en3;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('AEnumeration');
      AValue := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue((Ord(en3))=(AValue.AsOrdinal), '');
      ATestClass.AEnumeration := en1;
      TestContext.AssertTrue((Ord(en3))=(AValue.AsOrdinal), '');
      TestContext.AssertTrue(('en3')=(AValue.ToString), '');
      TestContext.AssertTrue((True)=(AValue.IsOrdinal), '');
    finally
      AtestClass.Free;
    end;

    TestContext.AssertTrue((Ord(en3))=(AValue.AsOrdinal), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueChars;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValueC, AValueW: TValue;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AChar := 'C';
    ATestClass.AWideChar := 'W';
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');

      AProperty := ARttiType.GetProperty('AChar');
      AValueC := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(('C')=(AValueC.AsAnsiChar), '');
      ATestClass.AChar := 'N';
      TestContext.AssertTrue(('C')=(AValueC.AsAnsiChar), '');
      TestContext.AssertTrue(('C')=(AValueC.ToString), '');
      TestContext.AssertTrue((True)=(AValueC.IsOrdinal), '');

      AProperty := ARttiType.GetProperty('AWideChar');
      AValueW := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(('W')=(AValueW.AsWideChar), '');
      ATestClass.AWideChar := 'Z';
      TestContext.AssertTrue(('W')=(AValueW.AsWideChar), '');
      TestContext.AssertTrue(('W')=(AValueW.ToString), '');
      TestContext.AssertTrue((True)=(AValueW.IsOrdinal), '');
    finally
      AtestClass.Free;
    end;

    TestContext.AssertTrue(('C')=(AValueC.AsAnsiChar), '');
    TestContext.AssertTrue(('W')=(AValueW.AsWideChar), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueRecord;

var
  ATestClass : TRecordRttiClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  R : TRTTIRecord;
  P : PRTTIRecord;

begin
  R.a:=23;
  r.B:=54;
  c := TRttiContext.Create(False);
  try
    ATestClass := TRecordRttiClass.Create;
    ATestClass.RecordProp:=R;
    try
      ARttiType := c.GetType(TRecordRttiClass);
      TestContext.AssertTrue((ARttiType)<>nil, 'Type');
      AProperty := ARttiType.GetProperty('RecordProp');
      TestContext.AssertTrue((aProperty)<>nil, 'Prop');
      AValue := AProperty.GetValue(ATestClass);
      P:=PRTTIRecord(AValue.GetReferenceToRawData);
      TestContext.AssertTrue((23)=(P^.A), 'a');
      TestContext.AssertTrue((54)=(P^.B), 'b');
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropSetValueString;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  s: string;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      AProperty := ARttiType.GetProperty('astring');

      s := 'ipse lorem or something like that';
      TValue.Make(@s, TypeInfo(string), AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue((ATestClass.AString)=(s), '');
      s := 'Another string';
      TestContext.AssertTrue((ATestClass.AString)=('ipse lorem or something like that'), '');
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropSetValueInteger;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  i: integer;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      AProperty := ARttiType.GetProperty('aInteger');

      i := -43573;
      TValue.Make(@i, TypeInfo(Integer), AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue((ATestClass.AInteger)=(i), '');
      i := 1;
      TestContext.AssertTrue((ATestClass.AInteger)=(-43573), '');
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropSetValueBoolean;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  b: boolean;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      AProperty := ARttiType.GetProperty('aboolean');

      b := true;
      TValue.Make(@b, TypeInfo(Boolean), AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue((ATestClass.ABoolean)=(b), '');
      b := false;
      TestContext.AssertTrue((ATestClass.ABoolean)=(true), '');
      TValue.Make(@b, TypeInfo(Boolean), AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue((ATestClass.ABoolean)=(false), '');
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropSetValueShortString;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  s: string;
  ss: ShortString;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      AProperty := ARttiType.GetProperty('aShortString');

      s := 'ipse lorem or something like that';
      TValue.Make(@s, TypeInfo(String), AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue((ATestClass.AShortString)=(s), '');
      s := 'Another string';
      TestContext.AssertTrue((ATestClass.AShortString)=('ipse lorem or something like that'), '');

      ss := 'Hello World';
      TValue.Make(@ss, TypeInfo(ShortString), AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue((ATestClass.AShortString)=(ss), '');
      ss := 'Foobar';
      TestContext.AssertTrue((ATestClass.AShortString)=('Hello World'), '');

      AProperty.SetValue(ATestClass, 'Another string');
      TestContext.AssertTrue((ATestClass.AShortString)=('Another string'), '');
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropSetValueObject;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  O: TObject;
  TypeInfo: PTypeInfo;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      AProperty := ARttiType.GetProperty('AObject');
      TypeInfo := GetPropInfo(ATestClass, 'AObject')^.PropType{$ifndef fpc}^{$endif};

      O := TPersistent.Create;
      TValue.Make(@O, TypeInfo, AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue((ATestClass.AObject.GetHashCode)=(O.GetHashCode), '');
      O.Free;

      O := TPersistent.Create;
      AProperty.SetValue(ATestClass, O);
      TestContext.AssertTrue((ATestClass.AObject.GetHashCode)=(O.GetHashCode), '');
      O.Free;
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropSetValueInterface;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  TypeInfo: PTypeInfo;
  i: IInterface;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      AProperty := ARttiType.GetProperty('AUnknown');
      TypeInfo := GetPropInfo(ATestClass, 'AUnknown')^.PropType{$ifndef fpc}^{$endif};

      i := TInterfacedObject.Create;
      TValue.Make(@i, TypeInfo, AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue(ATestClass.AUnknown = i, '');

    {$ifdef fpc}
      { Delphi does not provide an implicit assignment overload for IUnknown }
      i := TInterfacedObject.Create;
      AProperty.SetValue(ATestClass, i);
      TestContext.AssertTrue(ATestClass.AUnknown = i, '');
    {$endif}
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropSetValueFloat;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  TypeInfo: PTypeInfo;
  S: Single;
  D: Double;
  E: Extended;
  Cur: Currency;
  Cmp: Comp;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);

      AProperty := ARttiType.GetProperty('ASingle');
      TypeInfo := GetPropInfo(ATestClass, 'ASingle')^.PropType{$ifndef fpc}^{$endif};

      S := 1.1;
      TValue.Make(@S, TypeInfo, AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue(Abs((S)-(ATestClass.ASingle))<=(0.001), 'Floating comparison');

      S := 1.2;
      AProperty.SetValue(ATestClass, S);
      TestContext.AssertTrue(Abs((S)-(ATestClass.ASingle))<=(0.001), 'Floating comparison');

      AProperty := ARttiType.GetProperty('ADouble');
      TypeInfo := GetPropInfo(ATestClass, 'ADouble')^.PropType{$ifndef fpc}^{$endif};

      D := 2.1;
      TValue.Make(@D, TypeInfo, AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue(Abs((D)-(ATestClass.ADouble))<=(0.001), 'Floating comparison');

      D := 2.2;
      AProperty.SetValue(ATestClass, D);
      TestContext.AssertTrue(Abs((D)-(ATestClass.ADouble))<=(0.001), 'Floating comparison');

      AProperty := ARttiType.GetProperty('AExtended');
      TypeInfo := GetPropInfo(ATestClass, 'AExtended')^.PropType{$ifndef fpc}^{$endif};

      E := 3.1;
      TValue.Make(@E, TypeInfo, AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue(Abs((E)-(ATestClass.AExtended))<=(0.001), 'Floating comparison');

      E := 3.2;
      AProperty.SetValue(ATestClass, E);
      TestContext.AssertTrue(Abs((E)-(ATestClass.AExtended))<=(0.001), 'Floating comparison');

      AProperty := ARttiType.GetProperty('ACurrency');
      TypeInfo := GetPropInfo(ATestClass, 'ACurrency')^.PropType{$ifndef fpc}^{$endif};

      Cur := 40;
      TValue.Make(@Cur, TypeInfo, AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue(Abs((Cur)-(ATestClass.ACurrency))<=(0.001), 'Floating comparison');

      Cur := 41;
      AProperty.SetValue(ATestClass, Cur);
      TestContext.AssertTrue(Abs((Cur)-(ATestClass.ACurrency))<=(0.001), 'Floating comparison');

      AProperty := ARttiType.GetProperty('AComp');
      TypeInfo := GetPropInfo(ATestClass, 'AComp')^.PropType{$ifndef fpc}^{$endif};

      Cmp := 50;
      TValue.Make(@Cmp, TypeInfo, AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue(Abs((Cmp)-(ATestClass.AComp))<=(0.001), 'Floating comparison');

      Cmp := 51;
      AProperty.SetValue(ATestClass, Cmp);
      TestContext.AssertTrue(Abs((Cmp)-(ATestClass.AComp))<=(0.001), 'Floating comparison');
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropSetValueDynArray;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  A: TTestDynArray;
  TypeInfo: PTypeInfo;
  i: Integer;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      AProperty := ARttiType.GetProperty('AArray');
      TypeInfo := GetPropInfo(ATestClass, 'AArray')^.PropType{$ifndef fpc}^{$endif};

      A := [1, 2, 3, 4, 5];
      TValue.Make(@A, TypeInfo, AValue);
      AProperty.SetValue(ATestClass, AValue);

      for i := 0 to High(A) do
        TestContext.AssertTrue((A[i])=(ATestClass.AArray[i]), '');
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropSetValueEnumeration;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  E: TTestEnumeration;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      AProperty := ARttiType.GetProperty('AEnumeration');

      E := en2;
      TValue.Make(@E, TypeInfo(TTestEnumeration), AValue);
      AProperty.SetValue(ATestClass, AValue);
      TestContext.AssertTrue((Ord(E))=(Ord(ATestClass.AEnumeration)), '');
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropSetValueChars;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValueC, AValueW: TValue;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AChar := 'C';
    ATestClass.AWideChar := 'W';
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');

      AProperty := ARttiType.GetProperty('AChar');
      AValueC := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(('C')=(AValueC.AsAnsiChar), '');

      AProperty := ARttiType.GetProperty('AWideChar');
      AValueW := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(('W')=(AValueW.AsWideChar), '');
    finally
      AtestClass.Free;
    end;
      TestContext.AssertTrue(('C')=(AValueC.AsAnsiChar), '');
      TestContext.AssertTrue(('W')=(AValueW.AsWideChar), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropSetValueRecord;
var
  ATestClass : TRecordRttiClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
  R : TRTTIRecord;
  P : PRTTIRecord;

begin
  R.a:=23;
  r.B:=54;
  c := TRttiContext.Create(False);
  try
    ATestClass := TRecordRttiClass.Create;
    ATestClass.RecordProp:=R;
    try
      ARttiType := c.GetType(TRecordRttiClass);
      TestContext.AssertTrue((ARttiType)<>nil, 'Type');
      AProperty := ARttiType.GetProperty('RecordProp');
      TestContext.AssertTrue((aProperty)<>nil, 'Prop');
      AProperty.SetValue(ATestClass,TValue.specialize From<TRttiRecord>(R));
      TestContext.AssertTrue((23)=(aTestClass.RecordProp.A), 'a');
      TestContext.AssertTrue((54)=(aTestClass.RecordProp.B), 'b');
    finally
      AtestClass.Free;
    end;
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueProcInteger;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AInteger := 472349;
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('agetinteger');
      AValue := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue((472349)=(AValue.AsInteger), '');
    finally
      AtestClass.Free;
    end;
      TestContext.AssertTrue((472349)=(AValue.AsInteger), '');
  finally
    c.Free;
  end;
end;

procedure TTestRTTI.TestPropGetValueProcString;
var
  ATestClass : TTestValueClass;
  c: TRttiContext;
  ARttiType: TRttiType;
  AProperty: TRttiProperty;
  AValue: TValue;
begin
  c := TRttiContext.Create;
  try
    ATestClass := TTestValueClass.Create;
    ATestClass.AString := 'Hello World';
    try
      ARttiType := c.GetType(ATestClass.ClassInfo);
      TestContext.AssertTrue(assigned(ARttiType), '');
      AProperty := ARttiType.GetProperty('agetstring');
      AValue := AProperty.GetValue(ATestClass);
      TestContext.AssertTrue(('Hello World')=(AValue.AsString), '');
    finally
      AtestClass.Free;
    end;
    TestContext.AssertTrue(('Hello World')=(AValue.AsString), '');
  finally
    c.Free;
  end;
end;


procedure TTestRTTI.TestTRttiTypeProperties;
var
  c: TRttiContext;
  ARttiType: TRttiType;

begin
  c := TRttiContext.Create;
  try
    ARttiType := c.GetType(TTestValueClass);
    TestContext.AssertTrue(assigned(ARttiType), '');
    TestContext.AssertTrue((ARttiType.Name)=('TTestValueClass'), '');
    TestContext.AssertTrue(ARttiType.TypeKind=tkClass, '');
//    CheckEquals(ARttiType.IsPublicType,false);
    TestContext.AssertTrue((ARttiType.TypeSize)=(SizeOf(TObject)), '');
    TestContext.AssertTrue((ARttiType.IsManaged)=(false), '');
    TestContext.AssertTrue((ARttiType.BaseType.classname)=('TRttiInstanceType'), '');
    TestContext.AssertTrue((ARttiType.IsInstance)=(True), '');
    TestContext.AssertTrue((ARttiType.AsInstance.DeclaringUnitName)=('tests.rtti.types'), '');
    TestContext.AssertTrue(ARttiType.BaseType.Name='TObject', '');
    TestContext.AssertTrue(ARttiType.AsInstance.BaseType.Name='TObject', '');
    TestContext.AssertTrue((ARttiType.IsOrdinal)=(False), '');
    TestContext.AssertTrue((ARttiType.IsRecord)=(False), '');
    TestContext.AssertTrue((ARttiType.IsSet)=(False), '');
  finally
    c.Free;
  end;

end;

procedure TTestRTTI.GetTypeInteger;
var
  LContext: TRttiContext;
  LType: TRttiType;
begin
  LContext := TRttiContext.Create;

  LType := LContext.GetType(TypeInfo(integer));
{$ifdef fpc}
  TestContext.AssertTrue((LType.Name)=('LongInt'), '');
{$else}
  TestContext.AssertTrue((LType.Name)=('Integer'), '');
{$endif}

  LContext.Free;
end;

procedure TTestRTTI.GetTypePointer;
var
  context: TRttiContext;
  t: TRttiType;
  p: TRttiPointerType absolute t;
begin
  context := TRttiContext.Create;
  try
    t := context.GetType(TypeInfo(Pointer));
    Assert(t is TRttiPointerType, 'Type of Pointer is not a TRttiPointerType');
    Assert(not Assigned(p.ReferredType), 'ReferredType of Pointer is not Nil');
    t := context.GetType(TypeInfo(PLongInt));
    Assert(t is TRttiPointerType, 'Type of Pointer is not a TRttiPointerType');
    Assert(Assigned(p.ReferredType), 'ReferredType of PLongInt is Nil');
    Assert(p.ReferredType = context.GetType(TypeInfo(LongInt)), 'ReferredType of PLongInt is not a LongInt');
    t := context.GetType(TypeInfo(PWideChar));
    Assert(t is TRttiPointerType, 'Type of Pointer is not a TRttiPointerType');
    Assert(Assigned(p.ReferredType), 'ReferredType of PWideChar is Nil');
    Assert(p.ReferredType = context.GetType(TypeInfo(WideChar)), 'ReferredType of PWideChar is not a WideChar');
  finally
    context.Free;
  end;
end;

procedure TTestRTTI.GetClassProperties;
var
  LContext: TRttiContext;
  LType: TRttiType;
  PropList, PropList2: {$ifdef fpc}specialize{$endif} TArray<TRttiProperty>;
  i: LongInt;
begin
  LContext := TRttiContext.Create;

  LType := LContext.GetType(TypeInfo(TGetClassProperties));
  PropList := LType.GetProperties;

  TestContext.AssertTrue((4)=(length(PropList)), '');
  TestContext.AssertTrue(('PubPropRO')=(PropList[0].Name), '');
  TestContext.AssertTrue(('PubPropRW')=(PropList[1].Name), '');
  TestContext.AssertTrue(('PubPropSetRO')=(PropList[2].Name), '');
  TestContext.AssertTrue(('PubPropSetRW')=(PropList[3].Name), '');

  LType := LContext.GetType(TypeInfo(TGetClassPropertiesSub));
  PropList2 := LType.GetProperties;

  TestContext.AssertTrue((Length(PropList))=(Length(PropList2)), '');
  for i := 0 to High(PropList) do
    TestContext.AssertTrue(PropList[i] = PropList2[i], 'Property instances are not equal');

  LContext.Free;
end;

procedure TTestRTTI.GetClassPropertiesValue;
var
  AGetClassProperties: TGetClassProperties;
  LContext: TRttiContext;
  LType: TRttiType;
  AValue: TValue;
begin
  LContext := TRttiContext.Create;

  LType := LContext.GetType(TGetClassProperties);

  AGetClassProperties := TGetClassProperties.Create;
  try
    AGetClassProperties.PubPropRW:=12345;

    AValue := LType.GetProperty('PubPropRW').GetValue(AGetClassProperties);
    TestContext.AssertTrue((12345)=(AValue.AsInteger), '');

  finally
    AGetClassProperties.Free;
  end;

  LContext.Free;
end;


procedure TTestRTTI.TestInterface;
var
  context: TRttiContext;
  t: TRttiType;
  ti1, ti2: TRttiInterfaceType;
  methods: {$ifdef fpc}specialize{$endif} TArray<TRttiMethod>;
  params: {$ifdef fpc}specialize{$endif} TArray<TRttiParameter>;
  method: TRttiMethod;
  param: TRttiParameter;
  flag: TParamFlag;
begin
  context := TRttiContext.Create;
  try
    t := context.GetType(TypeInfo(IInterface));
    TestContext.AssertTrue(t is TRttiInterfaceType, 'Type is not an interface type');

    TestContext.AssertTrue(not Assigned(t.BaseType), 'Base type is assigned');

    ti1 := TRttiInterfaceType(t);
    TestContext.AssertTrue(not Assigned(ti1.BaseType), 'Base type is assigned');

    methods := t.GetMethods;
    TestContext.AssertTrue((0)=(Length(methods)), 'Overall method count does not match');

    methods := t.GetDeclaredMethods;
    TestContext.AssertTrue((0)=(Length(methods)), 'Declared method conut does not match');

    t := context.GetType(TypeInfo(ITestInterface));
    TestContext.AssertTrue(t is TRttiInterfaceType, 'Type is not an interface type');

    TestContext.AssertTrue(Assigned(t.BaseType), 'Base type is not assigned');
    TestContext.AssertTrue(t.BaseType = TRttiType(ti1), 'Base type does not match');

    ti2 := TRttiInterfaceType(t);
    TestContext.AssertTrue(Assigned(ti2.BaseType), 'Base type is not assigned');
    TestContext.AssertTrue(ti2.BaseType = ti1, 'Base type does not match');

    methods := t.GetMethods;
    TestContext.AssertTrue((4)=(Length(methods)), 'Overall method count does not match');

    methods := t.GetDeclaredMethods;
    TestContext.AssertTrue((4)=(Length(methods)), 'Declared method count does not match');

    method := methods[0];
    TestContext.AssertTrue((method.Name)=('Test'), 'Method name of Test does not match');
    TestContext.AssertTrue(method.CallingConvention = DefaultCC, 'Calling convention of Test does not match');
    TestContext.AssertTrue(method.MethodKind = mkProcedure, 'Method kind of Test does not match');
    TestContext.AssertTrue(method.DispatchKind = dkInterface, 'Dispatch kind of Test does not match');
    TestContext.AssertTrue(not Assigned(method.CodeAddress), 'Code address of Test is not Nil');
    TestContext.AssertTrue((method.VirtualIndex)=(3), 'Virtual index of Test does not match');
    TestContext.AssertTrue(not Assigned(method.ReturnType), 'Return type of Test is not Nil');
    params := method.GetParameters;
    TestContext.AssertTrue((0)=(Length(params)), 'Parameter count of Test does not match');

    method := methods[1];
    TestContext.AssertTrue((method.Name)=('Test2'), 'Method name of Test2 does not match');
    TestContext.AssertTrue(method.CallingConvention = DefaultCC, 'Calling convention of Test2 does not match');
    TestContext.AssertTrue(method.MethodKind = mkFunction, 'Method kind of Test2 does not match');
    TestContext.AssertTrue(method.DispatchKind = dkInterface, 'Dispatch kind of Test2 does not match');
    TestContext.AssertTrue(not Assigned(method.CodeAddress), 'Code address of Test2 is not Nil');
    TestContext.AssertTrue((method.VirtualIndex)=(4), 'Virtual index of Test2 does not match');
    TestContext.AssertTrue(Assigned(method.ReturnType), 'Return type of Test2 is Nil');
    TestContext.AssertTrue(method.ReturnType.TypeKind = tkInteger, 'Return type of Test2 is not an ordinal');
    params := method.GetParameters;
    TestContext.AssertTrue((0)=(Length(params)), 'Parameter count of Test2 does not match');

    method := methods[2];
    TestContext.AssertTrue((method.Name)=('Test3'), 'Method name of Test3 does not match');
    TestContext.AssertTrue(method.CallingConvention = DefaultCC, 'Calling convention of Test3 does not match');
    TestContext.AssertTrue(method.MethodKind = mkProcedure, 'Method kind of Test3 does not match');
    TestContext.AssertTrue(method.DispatchKind = dkInterface, 'Dispatch kind of Test3 does not match');
    TestContext.AssertTrue(not Assigned(method.CodeAddress), 'Code address of Test3 is not Nil');
    TestContext.AssertTrue((method.VirtualIndex)=(5), 'Virtual index of Test3 does not match');
    TestContext.AssertTrue(not Assigned(method.ReturnType), 'Return type of Test3 is not Nil');

    params := method.GetParameters;
    TestContext.AssertTrue((4)=(Length(params)), 'Parameter count of Test3 does not match');

    param := params[0];
    TestContext.AssertTrue((param.Name)=('aArg1'), 'Parameter name of Test3.aArg1 does not match');
    TestContext.AssertTrue(param.Flags = [], 'Parameter flags of Test3.aArg1 do not match');
    TestContext.AssertTrue(Assigned(param.ParamType), 'Parameter type of Test3.aArg1 is Nil');
    TestContext.AssertTrue(param.ParamType.TypeKind = tkInteger, 'Parameter type of Test3.aArg1 is not an ordinal');

    param := params[1];
    TestContext.AssertTrue((param.Name)=('aArg2'), 'Parameter name of Test3.aArg2 does not match');
    TestContext.AssertTrue(param.Flags = [pfConst], 'Parameter flags of Test3.aArg2 do not match');
    TestContext.AssertTrue(Assigned(param.ParamType), 'Parameter type of Test3.aArg2 is Nil');
    TestContext.AssertTrue(param.ParamType.TypeKind = tkAnsiString, 'Parameter type of Test3.aArg2 is not a string');

    param := params[2];
    TestContext.AssertTrue((param.Name)=('aArg3'), 'Parameter name of Test3.aArg3 does not match');
    TestContext.AssertTrue(param.Flags = [pfVar], 'Parameter flags of Test3.aArg3 do not match');
    TestContext.AssertTrue(Assigned(param.ParamType), 'Parameter type of Test3.aArg3 is Nil');
    TestContext.AssertTrue(param.ParamType.TypeKind = {$ifdef fpc}tkBool{$else}tkEnumeration{$endif}, 'Parameter type of Test3.aArg3 is not a boolean');

    param := params[3];
    TestContext.AssertTrue((param.Name)=('aArg4'), 'Parameter name of Test3.aArg4 does not match');
    TestContext.AssertTrue(param.Flags = [pfOut], 'Parameter flags of Test3.aArg4 do not match');
    TestContext.AssertTrue(Assigned(param.ParamType), 'Parameter type of Test3.aArg4 is Nil');
    TestContext.AssertTrue(param.ParamType.TypeKind = tkInteger, 'Parameter type of Test3.aArg4 is not a string');

    method := methods[3];
    TestContext.AssertTrue((method.Name)=('Test4'), 'Method name of Test4 does not match');
    TestContext.AssertTrue(method.CallingConvention = DefaultCC, 'Calling convention of Test4 does not match');
    TestContext.AssertTrue(method.MethodKind = mkFunction, 'Method kind of Test4 does not match');
    TestContext.AssertTrue(method.DispatchKind = dkInterface, 'Dispatch kind of Test4 does not match');
    TestContext.AssertTrue(not Assigned(method.CodeAddress), 'Code address of Test4 is not Nil');
    TestContext.AssertTrue((method.VirtualIndex)=(6), 'Virtual index of Test4 does not match');
    TestContext.AssertTrue(Assigned(method.ReturnType), 'Return type of Test4 is not Nil');
    TestContext.AssertTrue(method.ReturnType.TypeKind = tkAnsiString, 'Return type of Test4 is not a string');

    params := method.GetParameters;
    TestContext.AssertTrue((2)=(Length(params)), 'Parameter count of Test4 does not match');

    param := params[0];
    TestContext.AssertTrue((param.Name)=('aArg1'), 'Parameter name of Test4.aArg1 does not match');
    TestContext.AssertTrue(param.Flags = [pfArray, pfReference], 'Parameter flags of Test4.aArg1 do not match');
    TestContext.AssertTrue(Assigned(param.ParamType), 'Parameter type of Test4.aArg1 is Nil');
    TestContext.AssertTrue(param.ParamType.TypeKind = tkInteger, 'Parameter type of Test4.aArg1 is not an ordinal');

    param := params[1];
    TestContext.AssertTrue((param.Name)=('aArg2'), 'Parameter name of Test4.aArg2 does not match');
    TestContext.AssertTrue(param.Flags = [pfArray, pfReference], 'Parameter flags of Test4.aArg2 do not match');
    TestContext.AssertTrue(Assigned(param.ParamType), 'Parameter type of Test4.aArg2 is Nil');
    TestContext.AssertTrue(param.ParamType.TypeKind = tkRecord, 'Parameter type of Test4.aArg2 is not a record');
  finally
    context.Free;
  end;
end;

procedure TTestRTTI.TestRawThunk;
var
  intf: IInterface;
begin
  { we test the raw thunking by instantiating a TVirtualInterface of IInterface }
  { this does not require a function call manager as the thunking is implemented
    directly inside the RTTI unit }
  try
    intf := TVirtualInterface.Create(PTypeInfo(TypeInfo(IInterface))) as IInterface;
  except
    on e: ENotImplemented do
      TestContext.Skip('RawThunk not implemented');
  end;
  { if all went well QueryInterface and _AddRef were called and now we call
    _Release as well }
  intf := Nil;
end;

{$ifdef fpc}
procedure TTestRTTI.TestInterfaceRaw;
var
  context: TRttiContext;
  t: TRttiType;
  ti: TRttiInterfaceType;
begin
  context := TRttiContext.Create;
  try
    t := context.GetType(TypeInfo(ICORBATest));
    TestContext.AssertTrue(t is TRttiInterfaceType, 'Type is not a raw interface type');

    TestContext.AssertTrue(not Assigned(t.BaseType), 'Base type is assigned');

    ti := TRttiInterfaceType(t);
    TestContext.AssertTrue(not Assigned(ti.BaseType), 'Base type is assigned');
  finally
    context.Free;
  end;
end;
{$endif}

procedure TTestRTTI.TestArray;
var
  context: TRttiContext;
  t, el: TRttiType;
  a: TRttiArrayType;
  o: TRttiOrdinalType;
begin
  context := TRttiContext.Create;
  try
    t := context.GetType(PTypeInfo(TypeInfo(TArrayOfLongintStatic)));
    TestContext.AssertTrue(t is TRttiArrayType, 'Type is not a TRttiArrayType');

    a := TRttiArrayType(t);
    TestContext.AssertTrue((1)=(a.DimensionCount), 'Dimension count does not match');
    TestContext.AssertTrue((4)=(a.TotalElementCount), 'Total element count does not match');

    el := a.ElementType;
    TestContext.AssertTrue(el is TRttiOrdinalType, 'Element type is not a TRttiOrdinalType');
    TestContext.AssertTrue(el = context.GetType(PTypeInfo(TypeInfo(LongInt))), 'Element type is not a LongInt');

    t := a.Dimensions[0];
    {$ifdef fpc}
    TestContext.AssertTrue(t is TRttiOrdinalType, 'Index type is not a TRttiOrdinalType');

    o := TRttiOrdinalType(t);
    { Currently this is a full type :/ }
    {CheckEquals(0, o.MinValue, 'Minimum value of 1st dimension does not match');
    CheckEquals(3, o.MaxValue, 'Maximum value of 1st dimension does not match');}
    {$else}
    TestContext.AssertTrue(t = Nil, 'Index type is not Nil');
    {$endif}

    t := context.GetType(PTypeInfo(TypeInfo(TArrayOfLongint2DStatic)));
    TestContext.AssertTrue(t is TRttiArrayType, 'Type is not a TRttiArrayType');

    a := TRttiArrayType(t);
    TestContext.AssertTrue((2)=(a.DimensionCount), 'Dimension count does not match');
    TestContext.AssertTrue((4 * 3)=(a.TotalElementCount), 'Total element count does not match');

    el := a.ElementType;
    TestContext.AssertTrue(el is TRttiOrdinalType, 'Element type is not a TRttiOrdinalType');
    TestContext.AssertTrue(el = context.GetType(PTypeInfo(TypeInfo(LongInt))), 'Element type is not a LongInt');

    t := a.Dimensions[0];
    {$ifdef fpc}
    TestContext.AssertTrue(t is TRttiOrdinalType, 'Index type is not a TRttiOrdinalType');

    o := TRttiOrdinalType(t);
    { Currently this is a full type :/ }
    {CheckEquals(0, o.MinValue, 'Minimum value of 1st dimension does not match');
    CheckEquals(3, o.MaxValue, 'Maximum value of 1st dimension does not match');}
    {$else}
    TestContext.AssertTrue(t = Nil, 'Index type is not Nil');
    {$endif}

    t := a.Dimensions[1];
    {$ifdef fpc}
    TestContext.AssertTrue(t is TRttiOrdinalType, 'Index type is not a TRttiOrdinalType');

    o := TRttiOrdinalType(t);
    { Currently this is a full type :/ }
    {CheckEquals(2, o.MinValue, 'Minimum value of 1st dimension does not match');
    CheckEquals(4, o.MaxValue, 'Maximum value of 1st dimension does not match');}
    {$else}
    TestContext.AssertTrue(t = Nil, 'Index type is not Nil');
    {$endif}
  finally
    context.Free;
  end;
end;

procedure TTestRTTI.TestDynArray;
var
  context: TRttiContext;
  t, el: TRttiType;
  a: TRttiDynamicArrayType;
begin
  context := TRttiContext.Create;
  try
    t := context.GetType(PTypeInfo(TypeInfo(TArrayOfLongintDyn)));
    TestContext.AssertTrue(t is TRttiDynamicArrayType, 'Type is not a TRttiDynamicArrayType');

    a := TRttiDynamicArrayType(t);

    TestContext.AssertTrue(('tests.rtti.types')=(LowerCase(a.DeclaringUnitName)), 'Unit type does not match for dynamic array');
    TestContext.AssertTrue((a.ElementSize)=(SizeUInt(SizeOf(LongInt))), 'Element size does not match for dynamic array');

    el := a.ElementType;
    TestContext.AssertTrue(el is TRttiOrdinalType, 'Element type is not a TRttiOrdinalType');

    TestContext.AssertTrue(el = context.GetType(PTypeInfo(TypeInfo(LongInt))), 'Element type is not a LongInt');

    { ToDo: check OLE type }
  finally
    context.Free;
  end;
end;

procedure TTestRTTI.TestProcVar;
var
  context: TRttiContext;
  t: TRttiType;
  p: TRttiProcedureType;
  params: {$ifdef fpc}specialize{$endif} TArray<TRttiParameter>;
begin
  context := TRttiContext.Create;
  try
    t := context.GetType(PTypeInfo(TypeInfo(TTestProc)));
    TestContext.AssertTrue(Assigned(t), 'Rtti Type is Nil');
    TestContext.AssertTrue(t is TRttiInvokableType, 'Rtti Type is not an invokeable');
    TestContext.AssertTrue(t is TRttiProcedureType, 'Rtti Type is not a procedure type');

    p := t as TRttiProcedureType;
    TestContext.AssertTrue(p.CallingConvention = DefaultCC, 'Calling convention does not match');
    TestContext.AssertTrue(not Assigned(p.ReturnType), 'Return type is assigned');
    TestContext.AssertTrue((0)=(Length(p.GetParameters)), 'Procedure variable has parameters');

    t := context.GetType(PTypeInfo(TypeInfo(TTestFunc1)));
    TestContext.AssertTrue(Assigned(t), 'Rtti Type is Nil');
    TestContext.AssertTrue(t is TRttiInvokableType, 'Rtti Type is not an invokeable');
    TestContext.AssertTrue(t is TRttiProcedureType, 'Rtti Type is not a procedure type');

    p := t as TRttiProcedureType;
    TestContext.AssertTrue(p.CallingConvention = DefaultCC, 'Calling convention does not match');
    TestContext.AssertTrue(Assigned(p.ReturnType), 'Return type is not assigned');
    //Check(p.ReturnType is TRttiOrdinalType, 'Return type is not an ordinal type');
    TestContext.AssertTrue((0)=(Length(p.GetParameters)), 'Procedure variable has parameters');

    t := context.GetType(PTypeInfo(TypeInfo(TTestFunc2)));
    TestContext.AssertTrue(Assigned(t), 'Rtti Type is Nil');
    TestContext.AssertTrue(t is TRttiInvokableType, 'Rtti Type is not an invokeable');
    TestContext.AssertTrue(t is TRttiProcedureType, 'Rtti Type is not a procedure type');

    p := t as TRttiProcedureType;
    TestContext.AssertTrue(p.CallingConvention = DefaultCC, 'Calling convention does not match');
    TestContext.AssertTrue(Assigned(p.ReturnType), 'Return type is not assigned');
    TestContext.AssertTrue(p.ReturnType is TRttiStringType, 'Return type is not a string type');

    params := p.GetParameters;
    TestContext.AssertTrue((2)=(Length(params)), 'Procedure variable has incorrect amount of parameters');

    TestContext.AssertTrue(params[0].ParamType.TypeKind in [tkInteger, tkInt64], 'Parameter 1 is not an ordinal type');
    //Check(params[0].ParamType is TRttiOrdinalType, 'Parameter 1 is not an ordinal type');
    TestContext.AssertTrue(pfArray in params[1].Flags, 'Parameter 2 is not an array');
    TestContext.AssertTrue(params[1].ParamType.TypeKind in [tkInteger, tkInt64], 'Parameter 2 is not an ordinal array');
  finally
    context.Free;
  end;
end;

procedure TTestRTTI.TestMethod;
var
  context: TRttiContext;
  t: TRttiType;
  m: TRttiMethodType;
  params: {$ifdef fpc}specialize{$endif} TArray<TRttiParameter>;
begin
  context := TRttiContext.Create;
  try
    t := context.GetType(PTypeInfo(TypeInfo(TTestMethod)));
    TestContext.AssertTrue(Assigned(t), 'Rtti Type is Nil');
    TestContext.AssertTrue(t is TRttiInvokableType, 'Rtti Type is not an invokeable');
    TestContext.AssertTrue(t is TRttiMethodType, 'Rtti Type is not a method type');

    m := t as TRttiMethodType;
    TestContext.AssertTrue(m.CallingConvention = DefaultCC, 'Calling convention does not match');
    TestContext.AssertTrue(not Assigned(m.ReturnType), 'Return type is assigned');
    TestContext.AssertTrue((0)=(Length(m.GetParameters)), 'Method variable has parameters');

    t := context.GetType(PTypeInfo(TypeInfo(TTestMethod1)));
    TestContext.AssertTrue(Assigned(t), 'Rtti Type is Nil');
    TestContext.AssertTrue(t is TRttiInvokableType, 'Rtti Type is not an invokeable');
    TestContext.AssertTrue(t is TRttiMethodType, 'Rtti Type is not a method type');

    m := t as TRttiMethodType;
    TestContext.AssertTrue(m.CallingConvention = DefaultCC, 'Calling convention does not match');
    TestContext.AssertTrue(Assigned(m.ReturnType), 'Return type is not assigned');
    //Check(p.ReturnType is TRttiOrdinalType, 'Return type is not an ordinal type');
    TestContext.AssertTrue((0)=(Length(m.GetParameters)), 'Method variable has parameters');

    t := context.GetType(PTypeInfo(TypeInfo(TTestMethod2)));
    TestContext.AssertTrue(Assigned(t), 'Rtti Type is Nil');
    TestContext.AssertTrue(t is TRttiInvokableType, 'Rtti Type is not an invokeable');
    TestContext.AssertTrue(t is TRttiMethodType, 'Rtti Type is not a method type');

    m := t as TRttiMethodType;
    TestContext.AssertTrue(m.CallingConvention = DefaultCC, 'Calling convention does not match');
    TestContext.AssertTrue(Assigned(m.ReturnType), 'Return type is not assigned');
    TestContext.AssertTrue(m.ReturnType is TRttiStringType, 'Return type is not a string type');

    params := m.GetParameters;
    TestContext.AssertTrue((2)=(Length(params)), 'Method variable has incorrect amount of parameters');

    TestContext.AssertTrue(params[0].ParamType.TypeKind in [tkInteger, tkInt64], 'Parameter 1 is not an ordinal type');
    //Check(params[0].ParamType is TRttiOrdinalType, 'Parameter 1 is not an ordinal type');
    TestContext.AssertTrue(pfArray in params[1].Flags, 'Parameter 2 is not an array');
    TestContext.AssertTrue(params[1].ParamType.TypeKind in [tkInteger, tkInt64], 'Parameter 2 is not an ordinal array');
  finally
    context.Free;
  end;
end;

{ TTestExtendedRTTI }






procedure TTestExtendedRTTI.Setup;

begin

  FCtx:=TRttiContext.Create;
  FCtx.UsePublishedOnly:=False;
end;

procedure TTestExtendedRTTI.TearDown;
begin
  FCtx.Free;

end;

Procedure TTestExtendedRTTI.CheckField(aIdx : Integer; aData: TRttiField; aName : String; aKind : TTypeKind; aVisibility : TMemberVisibility; aStrict : Boolean = False);

Var
  Msg : String;

begin
  Msg:='Checking field '+IntToStr(aIdx)+' ('+aName+') ';
  TestContext.AssertTrue((AData)<>nil, Msg+'Have data');
  TestContext.AssertTrue((aName)=(aData.Name), Msg+'name');
  TestContext.AssertTrue((aKind)=(aData.FieldType.TypeKind), Msg+'kind');
  TestContext.AssertTrue((aVisibility)=(aData.Visibility), Msg+'visibility');
  TestContext.AssertTrue((aStrict)=(aData.StrictVisibility), Msg+'strict');
end;

Procedure TTestExtendedRTTI.CheckProperty(aIdx : Integer; aData: TRttiProperty; aName : String; aKind : TTypeKind; aVisibility : TMemberVisibility; isStrict : Boolean = False);

Var
  Msg : String;

begin
  Msg:='Checking prop '+IntToStr(aIdx)+' ('+aName+') ';
  TestContext.AssertTrue((AData)<>nil, Msg+'Have data');
  TestContext.AssertTrue((aName)=(aData.Name), Msg+'name');
  TestContext.AssertTrue((aKind)=(aData.PropertyType.TypeKind), Msg+'kind');
  TestContext.AssertTrue((aVisibility)=(aData.Visibility), Msg+'visibility');
  TestContext.AssertTrue((isStrict)=(aData.StrictVisibility), Msg+'strict');
end;

Procedure TTestExtendedRTTI.CheckMethod(aPrefix : string; aIdx : Integer; aData: TRttiMethod; aName : String; aVisibility : TMemberVisibility; aStrict : Boolean = False);

Var
  Msg : String;

begin
  Msg:=aPrefix+': Checking method '+IntToStr(aIdx)+' ('+aName+') ';
  TestContext.AssertTrue((AData)<>nil, Msg+'Have data');
  TestContext.AssertTrue((aData.Name)=(aName), Msg+'name');
  TestContext.AssertTrue((aVisibility)=(aData.Visibility), Msg+'visibility');
  TestContext.AssertTrue((aData.StrictVisibility)=(aStrict), Msg+'strict');
end;

procedure TTestClassExtendedRTTI.TestFields;

Var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  A : TRttiFieldArray;
  t : TFieldRTTI;

begin
  Obj:=FCtx.GetType(TFieldRTTI.ClassInfo);
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  A:=RttiData.GetFields;
  TestContext.AssertTrue((10)=(Length(A)), 'Class field Count');
  CheckField(0, A[0],'FPrivateA',tkInteger,mvPrivate);
  CheckField(1, A[1],'FPrivateB',tkInteger,mvPrivate,True);
  CheckField(2, A[2],'FProtectedA',tkInteger,mvProtected);
  CheckField(3, A[3],'FProtectedB',tkInteger,mvProtected,True);
  CheckField(4, A[4],'FPublicA',tkInteger,mvPublic);
  CheckField(5, A[5],'FPublicB',tkInteger,mvPublic);
  CheckField(6, A[6],'FPublishedA',tkInteger,mvPrivate);
  CheckField(7, A[7],'FPublishedB',tkInteger,mvPrivate);
  CheckField(8, A[8],'FPublishedC',tkClass,mvPublished);
  CheckField(9, A[9],'FPublishedD',tkClass,mvPublished);

  t := TFieldRTTI.Create;
  TestContext.AssertTrue((A[8].Offset)=(Integer(PByte(t.FieldAddress('FPublishedC')) - PByte(t))), 'Legacy Field 0');
  TestContext.AssertTrue((A[9].Offset)=(Integer(PByte(t.FieldAddress('FPublishedD')) - PByte(t))), 'Legacy Field 1');
  T.Free;
end;

procedure TTestClassExtendedRTTI.TestDeclaredFields;

Var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  Obj2 : TRttiObject;
  RttiData2 : TRttiInstanceType absolute obj2;
  A : TRttiFieldArray;
  I : Integer;

begin
  Obj:=FCtx.GetType(TFieldRTTIChild.ClassInfo);
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  Obj2:=FCtx.GetType(TFieldRTTI.ClassInfo);
  TestContext.AssertTrue((TRttiInstanceType)=(Obj2.ClassType), 'Correct class type');
  A:=RttiData.GetFields;
  TestContext.AssertTrue((11)=(Length(A)), 'Class field Count');
  For I:=1 to 10 do
    TestContext.AssertTrue((Obj2)=(A[I].Parent), 'Field parent'+IntToStr(i)+' is parent class');
  A:=RttiData.GetDeclaredFields;
  TestContext.AssertTrue((1)=(Length(A)), 'Class declared field Count');
  TestContext.AssertTrue((Obj)=(A[0].Parent), 'Declared Field parent is sels');
end;

procedure TTestClassExtendedRTTI.TestProperties;

Var
  A : TRttiPropertyArray;
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  aCount : Integer;


begin
  Obj:=FCtx.GetType(TFieldRTTI.ClassInfo);
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  A:=RttiData.GetProperties;
  aCount:=Length(A);
  TestContext.AssertTrue((8)=(aCount), 'Property Count');
  CheckProperty(0, A[0],'PrivateA',tkInteger,mvPrivate);
  CheckProperty(1, A[1],'PrivateB',tkInteger,mvPrivate,True);
  CheckProperty(2, A[2],'ProtectedA',tkInteger,mvProtected);
  CheckProperty(3, A[3],'ProtectedB',tkInteger,mvProtected,True);
  CheckProperty(4, A[4],'PublicA',tkInteger,mvPublic);
  CheckProperty(5, A[5],'PublicB',tkInteger,mvPublic);
  CheckProperty(6, A[6],'PublishedA',tkInteger,mvPublished);
  CheckProperty(7, A[7],'PublishedB',tkInteger,mvPublished);
end;

procedure TTestClassExtendedRTTI.TestDeclaredMethods;

Var
  A : TRttiMethodArray;
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  Parms : TRttiParameterArray;
  aCount : Integer;

begin
  Obj:=FCtx.GetType(TMethodClassRTTI.ClassInfo);
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  A:=RttiData.GetDeclaredMethods;
  aCount:=Length(A);
  TestContext.AssertTrue((12)=(aCount), 'Full Count');
  CheckMethod('Full',0, A[0],'PrivateMethodA',mvPrivate);
  CheckMethod('Full',1, A[1],'PrivateMethodB',mvPrivate,True);
  CheckMethod('Full',2, A[2],'PrivateMethodC',mvPrivate);
  CheckMethod('Full',3, A[3],'ProtectedMethodA',mvProtected);
  CheckMethod('Full',4, A[4],'ProtectedMethodB',mvProtected,True);
  CheckMethod('Full',5, A[5],'ProtectedMethodC',mvProtected);
  CheckMethod('Full',6, A[6],'PublicMethodA',mvPublic);
  CheckMethod('Full',7, A[7],'PublicMethodB',mvPublic);
  CheckMethod('Full',8, A[8],'PublicMethodC',mvPublic);
  CheckMethod('Full',9, A[9],'PublishedMethodA',mvPublished);
  CheckMethod('Full',10, A[10],'PublishedMethodB',mvPublished);
  CheckMethod('Full',11, A[11],'PublishedMethodC',mvPublished);
  Parms:=A[9].GetParameters;
  TestContext.AssertTrue((1)=(Length(Parms)), 'Parameter length');
  TestContext.AssertTrue(('a')=(Parms[0].Name), 'Parameter name');
end;

procedure TTestClassExtendedRTTI.TestMethods;
Var
  A : TRttiMethodArray;
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  aCount : Integer;

begin
  Obj:=FCtx.GetType(TAdditionalMethodClassRTTI.ClassInfo);
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  A:=RttiData.GetMethods;
  aCount:=Length(A);
  TestContext.AssertTrue((13)=(aCount), 'Full Count');
  CheckMethod('Full',0, A[0],'PublicAdditionalMethod',mvPublic);
  A:=RttiData.GetDeclaredMethods;
  aCount:=Length(A);
  TestContext.AssertTrue((1)=(aCount), 'Full declared Count');
  CheckMethod('Full declared',1, A[0],'PublicAdditionalMethod',mvPublic);
end;

procedure TTestClassExtendedRTTI.TestMethodByAddress;

var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  M1,M2 : TRttiMethod;
begin
  Obj:=FCtx.GetType(TAdditionalMethodClassRTTI.ClassInfo);
  M1:=RttiData.GetMethod('PublicAdditionalMethod');
  TestContext.AssertTrue((m1)<>nil, 'have method');
  M2:=RttiData.GetMethod(@TAdditionalMethodClassRTTI.PublicAdditionalMethod);
  TestContext.AssertTrue((M1)=(M2), 'Correct method ');
end;

procedure TTestClassExtendedRTTI.TestMethodsInherited;
Var
  A : TRttiMethodArray;
  Obj,Obj2 : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  RttiData2 : TRttiInstanceType absolute obj2;
  i,aCount : Integer;

begin
  Obj:=FCtx.GetType(TAdditionalMethodClassRTTI.ClassInfo);
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  Obj2:=FCtx.GetType(TMethodClassRTTI.ClassInfo);
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  A:=RttiData.GetMethods;
  aCount:=Length(A);
  TestContext.AssertTrue((13)=(aCount), 'Full Count');
  For I:=1 to 12 do
    TestContext.AssertTrue((Obj2)=(A[I].Parent), 'Parent is RTTI of parent class');
  A:=RttiData.GetDeclaredMethods;
  aCount:=Length(A);
  TestContext.AssertTrue((1)=(aCount), 'Full declared Count');
  CheckMethod('Full declared',1, A[0],'PublicAdditionalMethod',mvPublic);
  TestContext.AssertTrue((Obj)=(A[0].Parent), 'Parent is RTTI of parent class');
end;

procedure TTestClassExtendedRTTI.TestPrivateFieldAttributes;

var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  Attrs : TCustomAttributeArray;
  Fld : TRttiField;
  O : TCustomAttribute;
  M2 : My2Attribute absolute O;

begin
  Obj:=FCtx.GetType(TypeInfo(TFieldObject));
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  Fld:=RttiData.GetField('PrivateField');
  TestContext.AssertTrue((Fld)<>nil, 'Have field');
  Attrs:=Fld.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'Have attribute data');
  TestContext.AssertTrue((3)=(Length(Attrs)), 'attribute count');
  TestContext.AssertTrue(('WeakAttribute')=(Attrs[0].ClassName), 'Attribute 1 name');
  TestContext.AssertTrue(('MyAttribute')=(Attrs[1].ClassName), 'Attribute 2 name');
  TestContext.AssertTrue(('My2Attribute')=(Attrs[2].ClassName), 'Attribute 2 name');
  O:=Attrs[2];
  TestContext.AssertTrue((O)<>nil, 'Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My2Attribute), 'Attribute class ');
  TestContext.AssertTrue((2)=(M2.Int), 'Attribute value ');
end;

procedure TTestClassExtendedRTTI.TestProtectedFieldAttributes;

var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  Attrs : TCustomAttributeArray;
  Fld : TRttiField;
  O : TCustomAttribute;
  M2 : My2Attribute absolute O;

begin
  Obj:=FCtx.GetType(TypeInfo(TFieldObject));
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  Fld:=RttiData.GetField('ProtectedField');
  TestContext.AssertTrue((Fld)<>nil, 'Have field');
  Attrs:=Fld.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'Have attribute data');
  TestContext.AssertTrue((1)=(Length(Attrs)), 'attribute count');
  TestContext.AssertTrue(('My2Attribute')=(Attrs[0].ClassName), 'Attribute 1 name');
  O:=Attrs[0];
  TestContext.AssertTrue((O)<>nil, 'Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My2Attribute), 'Attribute class ');
  TestContext.AssertTrue((3)=(M2.Int), 'Attribute value ');
end;

procedure TTestClassExtendedRTTI.TestPublicFieldAttributes;

var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  Attrs : TCustomAttributeArray;
  Fld : TRttiField;
  O : TCustomAttribute;
  M3 : My3Attribute absolute O;
  aCount : Integer;

begin
  Obj:=FCtx.GetType(TypeInfo(TFieldObject));
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  aCount:=0;
  For Fld in RttiData.GetFields do
    if Fld.Visibility=mvPublic then
      inc(aCount);
  TestContext.AssertTrue((3)=(aCount), 'Field count');
  // PublicField
  Fld:=RttiData.GetField('PublicField');
  TestContext.AssertTrue((Fld)<>nil, 'Have field');
  Attrs:=Fld.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'Have attribute data');
  TestContext.AssertTrue((1)=(Length(Attrs)), 'attribute count');
  TestContext.AssertTrue(('My3Attribute')=(Attrs[0].ClassName), 'Attribute 1 name');
  O:=Attrs[0];
  TestContext.AssertTrue((O)<>nil, 'Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My3Attribute), 'Attribute class ');
  TestContext.AssertTrue((4)=(M3.Int), 'Attribute value ');
  // A
  Fld:=RttiData.GetField('A');
  TestContext.AssertTrue((Fld)<>nil, 'A Have field');
  Attrs:=Fld.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'A Have attribute data');
  TestContext.AssertTrue((1)=(Length(Attrs)), 'A Attribute count');
  TestContext.AssertTrue(('My3Attribute')=(Attrs[0].ClassName), 'A Attribute 1 name');
  O:=Attrs[0];
  TestContext.AssertTrue((O)<>nil, 'A: Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My3Attribute), 'A: Attribute class ');
  TestContext.AssertTrue((4)=(M3.Int), 'A: Attribute value ');
  // B
  Fld:=RttiData.GetField('B');
  TestContext.AssertTrue((Fld)<>nil, 'B Have field');
  Attrs:=Fld.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'B Have attribute data');
  TestContext.AssertTrue((1)=(Length(Attrs)), 'A Attribute count');
  TestContext.AssertTrue(('My3Attribute')=(Attrs[0].ClassName), 'A Attribute 1 name');
  O:=Attrs[0];
  TestContext.AssertTrue((O)<>nil, 'B: Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My3Attribute), 'B: Attribute class ');
  TestContext.AssertTrue((4)=(M3.Int), 'B: Attribute value ');
end;

procedure TTestClassExtendedRTTI.TestPrivatePropertyAttributes;

var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  Attrs : TCustomAttributeArray;
  Prop : TRttiProperty;
  O : TCustomAttribute;
  aCount : Integer;
  M2 : My2Attribute absolute O;

begin
  Obj:=FCtx.GetType(TypeInfo(TPropertyObject));
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  aCount:=0;
  Prop:=RttiData.GetProperty('PrivateProperty');
  TestContext.AssertTrue((Prop)<>nil, 'Have property');
  Attrs:=Prop.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'Have attribute data');
  TestContext.AssertTrue((3)=(Length(Attrs)), 'attribute count');
  TestContext.AssertTrue(('WeakAttribute')=(Attrs[0].ClassName), 'Attribute 1 name');
  TestContext.AssertTrue(('MyAttribute')=(Attrs[1].ClassName), 'Attribute 2 name');
  TestContext.AssertTrue(('My2Attribute')=(Attrs[2].ClassName), 'Attribute 2 name');
  O:=Attrs[2];
  TestContext.AssertTrue((O)<>nil, 'Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My2Attribute), 'Attribute class ');
  TestContext.AssertTrue((2)=(M2.Int), 'Attribute value ');
end;

procedure TTestClassExtendedRTTI.TestProtectedPropertyAttributes;

var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  Attrs : TCustomAttributeArray;
  Prop : TRttiProperty;
  O : TCustomAttribute;
  M2 : My2Attribute absolute O;

begin
  Obj:=FCtx.GetType(TypeInfo(TPropertyObject));
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  Prop:=RttiData.GetProperty('ProtectedProperty');
  TestContext.AssertTrue((Prop)<>nil, 'Have property');
  Attrs:=Prop.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'Have attribute data');
  TestContext.AssertTrue((1)=(Length(Attrs)), 'attribute count');
  TestContext.AssertTrue(('My2Attribute')=(Attrs[0].ClassName), 'Attribute 1 name');
  O:=Attrs[0];
  TestContext.AssertTrue((O)<>nil, 'Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My2Attribute), 'Attribute class ');
  TestContext.AssertTrue((3)=(M2.Int), 'Attribute value ');
end;

procedure TTestClassExtendedRTTI.TestPublicPropertyAttributes;

var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  Attrs : TCustomAttributeArray;
  Prop : TRttiProperty;
  O : TCustomAttribute;
  M3 : My3Attribute absolute O;

begin
  Obj:=FCtx.GetType(TypeInfo(TPropertyObject));
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  Prop:=RttiData.GetProperty('PublicProperty');
  TestContext.AssertTrue((Prop)<>nil, 'Have property');
  Attrs:=Prop.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'Have attribute data');
  TestContext.AssertTrue((1)=(Length(Attrs)), 'attribute count');
  TestContext.AssertTrue(('My3Attribute')=(Attrs[0].ClassName), 'Attribute 1 name');
  O:=Attrs[0];
  TestContext.AssertTrue((O)<>nil, 'Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My3Attribute), 'Attribute class ');
  TestContext.AssertTrue((4)=(M3.Int), 'Attribute value ');
end;

procedure TTestClassExtendedRTTI.TestPublishedPropertyAttributes;

var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  Attrs : TCustomAttributeArray;
  Prop : TRttiProperty;
  O : TCustomAttribute;
  M3 : My3Attribute absolute O;

begin
  Obj:=FCtx.GetType(TypeInfo(TPropertyObject));
  TestContext.AssertTrue((TRttiInstanceType)=(Obj.ClassType), 'Correct class type');
  Prop:=RttiData.GetProperty('PublishedProperty');
  TestContext.AssertTrue((Prop)<>nil, 'Have property');
  Attrs:=Prop.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'Have attribute data');
  TestContext.AssertTrue((1)=(Length(Attrs)), 'attribute count');
  TestContext.AssertTrue(('My3Attribute')=(Attrs[0].ClassName), 'Attribute 1 name');
  O:=Attrs[0];
  TestContext.AssertTrue((O)<>nil, 'Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My3Attribute), 'Attribute class ');
  TestContext.AssertTrue((5)=(M3.Int), 'Attribute value ');
end;

procedure TTestClassExtendedRTTI.TestGetStaticProperty;
var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  Prop : TRttiProperty;
begin
  Obj:=FCtx.GetType(TypeInfo(TTestAttr2Class));
  TTestAttr2Class.StaticProp:=4539;
  Prop:=rttiData.GetProperty('StaticProp');
  TestContext.AssertTrue((4539)=(Prop.GetValue(nil).AsInteger), 'Class property is set or got incorrectly via methods');
end;

procedure TTestClassExtendedRTTI.TestSetStaticProperty;
var
  Obj : TRttiObject;
  RttiData : TRttiInstanceType absolute obj;
  Prop : TRttiProperty;
begin
  Obj:=FCtx.GetType(TypeInfo(TTestAttr2Class));
  Prop:=rttiData.GetProperty('StaticProp');
  // Write
  Prop.SetValue(nil, 4539);
  TestContext.AssertTrue((4539)=(TTestAttr2Class.StaticProp), 'Property correctly set');
end;


{ TTestRecordExtendedRTTI }

procedure TTestRecordExtendedRTTI.TestFields;

Var
  A : TRttiFieldArray;
  Obj : TRttiObject;
  RttiData : TRttiRecordType absolute obj;
  aCount : Integer;

begin
  Obj:=FCtx.GetType(TypeInfo(TRecordFieldRTTI));
  TestContext.AssertTrue((TRttiRecordType)=(Obj.ClassType), 'Correct class type');
  A:=RttiData.GetFields;
  aCount:=Length(A);
  TestContext.AssertTrue((4)=(aCount), 'Record fields Count');
  CheckField(0, A[0],'FRPrivateA',tkInteger,mvPrivate);
  CheckField(1, A[1],'FRPrivateB',tkInteger,mvPrivate);
  CheckField(4, A[2],'FRPublicA',tkInteger,mvPublic);
  CheckField(5, A[3],'FRPublicB',tkInteger,mvPublic);


  Obj:=FCtx.GetType(TypeInfo(TRecordFieldRTTIMixed));
  TestContext.AssertTrue((TRttiRecordType)=(Obj.ClassType), 'Correct class type');
  A:=RttiData.GetFields;
  aCount:=Length(A);
  TestContext.AssertTrue((4)=(aCount), 'Mixed record fields Count');
  CheckField(0, A[0],'FRPrivateA',tkInteger,mvPrivate);
  CheckField(1, A[1],'FRPrivateB',tkInteger,mvPrivate);
  CheckField(4, A[2],'FRPublicA',tkInteger,mvPublic);
  CheckField(5, A[3],'FRPublicB',tkInteger,mvPublic);

end;

procedure TTestRecordExtendedRTTI.TestProperties;

Var
  A : TRttiPropertyArray;
  Obj : TRttiObject;
  RttiData : TRttiRecordType absolute obj;
  aCount : Integer;

begin
  // TRecordFieldRTTI
  Obj:=FCtx.GetType(TypeInfo(TRecordFieldRTTI));
  TestContext.AssertTrue((TRttiRecordType)=(Obj.ClassType), 'Correct class type');
  A:=RttiData.GetProperties;
  aCount:=Length(A);
  TestContext.AssertTrue((4)=(aCount), 'Record property Count');
  CheckProperty(0, A[0],'RPrivateA',tkInteger,mvPrivate);
  CheckProperty(1, A[1],'RPrivateB',tkInteger,mvPrivate);
  CheckProperty(2, A[2],'RPublicA',tkInteger,mvPublic);
  CheckProperty(3, A[3],'RPublicB',tkInteger,mvPublic);
  // TRecordFieldRTTIMixed
  Obj:=FCtx.GetType(TypeInfo(TRecordFieldRTTIMixed));
  TestContext.AssertTrue((TRttiRecordType)=(Obj.ClassType), 'Correct class type');
  A:=RttiData.GetProperties;
  aCount:=Length(A);
  TestContext.AssertTrue((4)=(aCount), 'Record mixed property Count');
  CheckProperty(0, A[0],'RPrivateA',tkInteger,mvPrivate);
  CheckProperty(1, A[1],'RPrivateB',tkInteger,mvPrivate);
  CheckProperty(2, A[2],'RPublicA',tkInteger,mvPublic);
  CheckProperty(3, A[3],'RPublicB',tkInteger,mvPublic);
end;

procedure TTestRecordExtendedRTTI.TestDeclaredMethods;
Var
  A : TRttiMethodArray;
  Obj : TRttiObject;
  RttiData : TRttiRecordType absolute obj;
  aCount : Integer;
  Parms : TRttiParameterArray;

begin
  Obj:=FCtx.GetType(TypeInfo(TRecordMethodRTTI));
  TestContext.AssertTrue((TRttiRecordType)=(Obj.ClassType), 'Correct class type');
  A:=RttiData.GetDeclaredMethods;
  aCount:=Length(A);
  TestContext.AssertTrue((4)=(aCount), 'Method Full Count');
  CheckMethod('Full',0, A[0],'PrivateMethodA',mvPrivate);
  CheckMethod('Full',1, A[1],'PrivateMethodB',mvPrivate);
  CheckMethod('Full',2, A[2],'PublicMethodA',mvPublic);
  CheckMethod('Full',3, A[3],'PublicMethodB',mvPublic);
  Parms:=A[3].GetParameters;
  TestContext.AssertTrue((1)=(Length(Parms)), 'Parameter length');
  TestContext.AssertTrue((Parms[0])<>nil, 'Have Parameter');
  TestContext.AssertTrue(('I')=(Parms[0].Name), 'Parameter name');
end;

procedure TTestRecordExtendedRTTI.TestMethods;
Var
  A : TRttiMethodArray;
  Obj : TRttiObject;
  RttiData : TRttiRecordType absolute obj;
  aCount : Integer;
begin
  Obj:=FCtx.GetType(TypeInfo(TRecordMethodRTTI));
  TestContext.AssertTrue((TRttiRecordType)=(Obj.ClassType), 'Correct class type');
  A:=RttiData.GetDeclaredMethods;
  aCount:=Length(A);
  // Just check that the count is correct
  TestContext.AssertTrue((4)=(aCount), 'Method Full Count');
end;

Procedure TTestRecordExtendedRTTI.TestPrivateFieldAttributes;

var
  Obj : TRttiObject;
  RttiData : TRttiRecordType absolute obj;
  Attrs : TCustomAttributeArray;
  Fld : TRttiField;
  O : TCustomAttribute;
  M2 : My2Attribute absolute O;

begin
  Obj:=FCtx.GetType(TypeInfo(TFieldRecord));
  TestContext.AssertTrue((TRttiRecordType)=(Obj.ClassType), 'Correct class type');
  Fld:=RttiData.GetField('PrivateField');
  TestContext.AssertTrue((Fld)<>nil, 'Have field');
  Attrs:=Fld.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'Have attribute data');
  TestContext.AssertTrue((3)=(Length(Attrs)), 'attribute count');
  TestContext.AssertTrue(('WeakAttribute')=(Attrs[0].ClassName), 'Attribute 1 name');
  TestContext.AssertTrue(('MyAttribute')=(Attrs[1].ClassName), 'Attribute 2 name');
  TestContext.AssertTrue(('My2Attribute')=(Attrs[2].ClassName), 'Attribute 2 name');
  O:=Attrs[2];
  TestContext.AssertTrue((O)<>nil, 'Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My2Attribute), 'Attribute class ');
  TestContext.AssertTrue((2)=(M2.Int), 'Attribute value ');
end;

Procedure TTestRecordExtendedRTTI.TestPublicFieldAttributes;

var
  Obj : TRttiObject;
  RttiData : TRttiRecordType absolute obj;
  Attrs : TCustomAttributeArray;
  Fld : TRttiField;
  O : TCustomAttribute;
  M3 : My3Attribute absolute O;
  aCount : Integer;

begin
  Obj:=FCtx.GetType(TypeInfo(TFieldRecord));
  TestContext.AssertTrue((TRttiRecordType)=(Obj.ClassType), 'Correct class type');
  aCount:=0;
  For Fld in RttiData.GetFields do
    if Fld.Visibility=mvPublic then
      inc(aCount);
  TestContext.AssertTrue((3)=(aCount), 'Field count');
  // PublicField
  Fld:=RttiData.GetField('PublicField');
  TestContext.AssertTrue((Fld)<>nil, 'Have field');
  Attrs:=Fld.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'Have attribute data');
  TestContext.AssertTrue((1)=(Length(Attrs)), 'attribute count');
  TestContext.AssertTrue(('My3Attribute')=(Attrs[0].ClassName), 'Attribute 1 name');
  O:=Attrs[0];
  TestContext.AssertTrue((O)<>nil, 'Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My3Attribute), 'Attribute class ');
  TestContext.AssertTrue((3)=(M3.Int), 'Attribute value ');
  // A
  Fld:=RttiData.GetField('A');
  TestContext.AssertTrue((Fld)<>nil, 'A Have field');
  Attrs:=Fld.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'A Have attribute data');
  TestContext.AssertTrue((1)=(Length(Attrs)), 'A Attribute count');
  TestContext.AssertTrue(('My3Attribute')=(Attrs[0].ClassName), 'A Attribute 1 name');
  O:=Attrs[0];
  TestContext.AssertTrue((O)<>nil, 'A: Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My3Attribute), 'A: Attribute class ');
  TestContext.AssertTrue((4)=(M3.Int), 'A: Attribute value ');
  // B
  Fld:=RttiData.GetField('B');
  TestContext.AssertTrue((Fld)<>nil, 'B Have field');
  Attrs:=Fld.GetAttributes;
  TestContext.AssertTrue((Pointer(Attrs))<>nil, 'B Have attribute data');
  TestContext.AssertTrue((1)=(Length(Attrs)), 'A Attribute count');
  TestContext.AssertTrue(('My3Attribute')=(Attrs[0].ClassName), 'A Attribute 1 name');
  O:=Attrs[0];
  TestContext.AssertTrue((O)<>nil, 'B: Attribute class ');
  TestContext.AssertTrue((O.ClassType)=(My3Attribute), 'B: Attribute class ');
  TestContext.AssertTrue((4)=(M3.Int), 'B: Attribute value ');
end;

constructor TTestRTTI.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestExtendedRTTI.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestRTTIGetTypeInteger(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'GetTypeInteger');
  try
    lFixture.GetTypeInteger;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTIGetTypePointer(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'GetTypePointer');
  try
    lFixture.GetTypePointer;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTIGetClassProperties(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'GetClassProperties');
  try
    lFixture.GetClassProperties;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTIGetClassPropertiesValue(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'GetClassPropertiesValue');
  try
    lFixture.GetClassPropertiesValue;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestTRttiTypeProperties(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestTRttiTypeProperties');
  try
    lFixture.TestTRttiTypeProperties;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueString(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueString');
  try
    lFixture.TestPropGetValueString;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueInteger(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueInteger');
  try
    lFixture.TestPropGetValueInteger;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueBoolean(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueBoolean');
  try
    lFixture.TestPropGetValueBoolean;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueShortString(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueShortString');
  try
    lFixture.TestPropGetValueShortString;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueProcString(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueProcString');
  try
    lFixture.TestPropGetValueProcString;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueProcInteger(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueProcInteger');
  try
    lFixture.TestPropGetValueProcInteger;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueProcBoolean(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueProcBoolean');
  try
    lFixture.TestPropGetValueProcBoolean;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueProcShortString(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueProcShortString');
  try
    lFixture.TestPropGetValueProcShortString;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueObject(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueObject');
  try
    lFixture.TestPropGetValueObject;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueInterface(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueInterface');
  try
    lFixture.TestPropGetValueInterface;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueFloat(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueFloat');
  try
    lFixture.TestPropGetValueFloat;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueDynArray(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueDynArray');
  try
    lFixture.TestPropGetValueDynArray;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueEnumeration(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueEnumeration');
  try
    lFixture.TestPropGetValueEnumeration;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueChars(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueChars');
  try
    lFixture.TestPropGetValueChars;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropGetValueRecord(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropGetValueRecord');
  try
    lFixture.TestPropGetValueRecord;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropSetValueString(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropSetValueString');
  try
    lFixture.TestPropSetValueString;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropSetValueInteger(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropSetValueInteger');
  try
    lFixture.TestPropSetValueInteger;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropSetValueBoolean(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropSetValueBoolean');
  try
    lFixture.TestPropSetValueBoolean;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropSetValueShortString(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropSetValueShortString');
  try
    lFixture.TestPropSetValueShortString;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropSetValueObject(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropSetValueObject');
  try
    lFixture.TestPropSetValueObject;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropSetValueInterface(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropSetValueInterface');
  try
    lFixture.TestPropSetValueInterface;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropSetValueFloat(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropSetValueFloat');
  try
    lFixture.TestPropSetValueFloat;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropSetValueDynArray(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropSetValueDynArray');
  try
    lFixture.TestPropSetValueDynArray;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropSetValueEnumeration(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropSetValueEnumeration');
  try
    lFixture.TestPropSetValueEnumeration;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropSetValueChars(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropSetValueChars');
  try
    lFixture.TestPropSetValueChars;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestPropSetValueRecord(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestPropSetValueRecord');
  try
    lFixture.TestPropSetValueRecord;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestGetValueStringCastError(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestGetValueStringCastError');
  try
    lFixture.TestGetValueStringCastError;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestGetIsReadable(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestGetIsReadable');
  try
    lFixture.TestGetIsReadable;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestIsWritable(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestIsWritable');
  try
    lFixture.TestIsWritable;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestGetAttribute(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestGetAttribute');
  try
    lFixture.TestGetAttribute;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestInterface(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestInterface');
  try
    lFixture.TestInterface;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestInterfaceRaw(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestInterfaceRaw');
  try
    lFixture.TestInterfaceRaw;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestArray(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestArray');
  try
    lFixture.TestArray;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestDynArray(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestDynArray');
  try
    lFixture.TestDynArray;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestProcVar(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestProcVar');
  try
    lFixture.TestProcVar;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestMethod(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestMethod');
  try
    lFixture.TestMethod;
  finally lFixture.Free; end;
end;

procedure RunTTestRTTITestRawThunk(AContext: TNXTestContext);
var lFixture: TTestRTTI;
begin
  lFixture:=TTestRTTI.Create(AContext, 'TestRawThunk');
  try
    lFixture.TestRawThunk;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestFields(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestFields');
  try
    lFixture.SetUp;
    try lFixture.TestFields; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestDeclaredFields(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestDeclaredFields');
  try
    lFixture.SetUp;
    try lFixture.TestDeclaredFields; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestProperties(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestProperties');
  try
    lFixture.SetUp;
    try lFixture.TestProperties; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestDeclaredMethods(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestDeclaredMethods');
  try
    lFixture.SetUp;
    try lFixture.TestDeclaredMethods; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestMethods(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestMethods');
  try
    lFixture.SetUp;
    try lFixture.TestMethods; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestMethodByAddress(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestMethodByAddress');
  try
    lFixture.SetUp;
    try lFixture.TestMethodByAddress; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestMethodsInherited(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestMethodsInherited');
  try
    lFixture.SetUp;
    try lFixture.TestMethodsInherited; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestPrivateFieldAttributes(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestPrivateFieldAttributes');
  try
    lFixture.SetUp;
    try lFixture.TestPrivateFieldAttributes; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestProtectedFieldAttributes(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestProtectedFieldAttributes');
  try
    lFixture.SetUp;
    try lFixture.TestProtectedFieldAttributes; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestPublicFieldAttributes(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestPublicFieldAttributes');
  try
    lFixture.SetUp;
    try lFixture.TestPublicFieldAttributes; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestPrivatePropertyAttributes(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestPrivatePropertyAttributes');
  try
    lFixture.SetUp;
    try lFixture.TestPrivatePropertyAttributes; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestProtectedPropertyAttributes(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestProtectedPropertyAttributes');
  try
    lFixture.SetUp;
    try lFixture.TestProtectedPropertyAttributes; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestPublicPropertyAttributes(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestPublicPropertyAttributes');
  try
    lFixture.SetUp;
    try lFixture.TestPublicPropertyAttributes; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestPublishedPropertyAttributes(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestPublishedPropertyAttributes');
  try
    lFixture.SetUp;
    try lFixture.TestPublishedPropertyAttributes; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestGetStaticProperty(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestGetStaticProperty');
  try
    lFixture.SetUp;
    try lFixture.TestGetStaticProperty; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestClassExtendedRTTITestSetStaticProperty(AContext: TNXTestContext);
var lFixture: TTestClassExtendedRTTI;
begin
  lFixture:=TTestClassExtendedRTTI.Create(AContext, 'TestSetStaticProperty');
  try
    lFixture.SetUp;
    try lFixture.TestSetStaticProperty; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestRecordExtendedRTTITestFields(AContext: TNXTestContext);
var lFixture: TTestRecordExtendedRTTI;
begin
  lFixture:=TTestRecordExtendedRTTI.Create(AContext, 'TestFields');
  try
    lFixture.SetUp;
    try lFixture.TestFields; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestRecordExtendedRTTITestProperties(AContext: TNXTestContext);
var lFixture: TTestRecordExtendedRTTI;
begin
  lFixture:=TTestRecordExtendedRTTI.Create(AContext, 'TestProperties');
  try
    lFixture.SetUp;
    try lFixture.TestProperties; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestRecordExtendedRTTITestDeclaredMethods(AContext: TNXTestContext);
var lFixture: TTestRecordExtendedRTTI;
begin
  lFixture:=TTestRecordExtendedRTTI.Create(AContext, 'TestDeclaredMethods');
  try
    lFixture.SetUp;
    try lFixture.TestDeclaredMethods; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestRecordExtendedRTTITestMethods(AContext: TNXTestContext);
var lFixture: TTestRecordExtendedRTTI;
begin
  lFixture:=TTestRecordExtendedRTTI.Create(AContext, 'TestMethods');
  try
    lFixture.SetUp;
    try lFixture.TestMethods; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestRecordExtendedRTTITestPrivateFieldAttributes(AContext: TNXTestContext);
var lFixture: TTestRecordExtendedRTTI;
begin
  lFixture:=TTestRecordExtendedRTTI.Create(AContext, 'TestPrivateFieldAttributes');
  try
    lFixture.SetUp;
    try lFixture.TestPrivateFieldAttributes; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestRecordExtendedRTTITestPublicFieldAttributes(AContext: TNXTestContext);
var lFixture: TTestRecordExtendedRTTI;
begin
  lFixture:=TTestRecordExtendedRTTI.Create(AContext, 'TestPublicFieldAttributes');
  try
    lFixture.SetUp;
    try lFixture.TestPublicFieldAttributes; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertestsrttiTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tests.rtti.TTestRTTI');
  lSuite.AddTest('GetTypeInteger', @RunTTestRTTIGetTypeInteger);
  lSuite.AddTest('GetTypePointer', @RunTTestRTTIGetTypePointer);
  lSuite.AddTest('GetClassProperties', @RunTTestRTTIGetClassProperties);
  lSuite.AddTest('GetClassPropertiesValue', @RunTTestRTTIGetClassPropertiesValue);
  lSuite.AddTest('TestTRttiTypeProperties', @RunTTestRTTITestTRttiTypeProperties);
  lSuite.AddTest('TestPropGetValueString', @RunTTestRTTITestPropGetValueString);
  lSuite.AddTest('TestPropGetValueInteger', @RunTTestRTTITestPropGetValueInteger);
  lSuite.AddTest('TestPropGetValueBoolean', @RunTTestRTTITestPropGetValueBoolean);
  lSuite.AddTest('TestPropGetValueShortString', @RunTTestRTTITestPropGetValueShortString);
  lSuite.AddTest('TestPropGetValueProcString', @RunTTestRTTITestPropGetValueProcString);
  lSuite.AddTest('TestPropGetValueProcInteger', @RunTTestRTTITestPropGetValueProcInteger);
  lSuite.AddTest('TestPropGetValueProcBoolean', @RunTTestRTTITestPropGetValueProcBoolean);
  lSuite.AddTest('TestPropGetValueProcShortString', @RunTTestRTTITestPropGetValueProcShortString);
  lSuite.AddTest('TestPropGetValueObject', @RunTTestRTTITestPropGetValueObject);
  lSuite.AddTest('TestPropGetValueInterface', @RunTTestRTTITestPropGetValueInterface);
  lSuite.AddTest('TestPropGetValueFloat', @RunTTestRTTITestPropGetValueFloat);
  lSuite.AddTest('TestPropGetValueDynArray', @RunTTestRTTITestPropGetValueDynArray);
  lSuite.AddTest('TestPropGetValueEnumeration', @RunTTestRTTITestPropGetValueEnumeration);
  lSuite.AddTest('TestPropGetValueChars', @RunTTestRTTITestPropGetValueChars);
  lSuite.AddTest('TestPropGetValueRecord', @RunTTestRTTITestPropGetValueRecord);
  lSuite.AddTest('TestPropSetValueString', @RunTTestRTTITestPropSetValueString);
  lSuite.AddTest('TestPropSetValueInteger', @RunTTestRTTITestPropSetValueInteger);
  lSuite.AddTest('TestPropSetValueBoolean', @RunTTestRTTITestPropSetValueBoolean);
  lSuite.AddTest('TestPropSetValueShortString', @RunTTestRTTITestPropSetValueShortString);
  lSuite.AddTest('TestPropSetValueObject', @RunTTestRTTITestPropSetValueObject);
  lSuite.AddTest('TestPropSetValueInterface', @RunTTestRTTITestPropSetValueInterface);
  lSuite.AddTest('TestPropSetValueFloat', @RunTTestRTTITestPropSetValueFloat);
  lSuite.AddTest('TestPropSetValueDynArray', @RunTTestRTTITestPropSetValueDynArray);
  lSuite.AddTest('TestPropSetValueEnumeration', @RunTTestRTTITestPropSetValueEnumeration);
  lSuite.AddTest('TestPropSetValueChars', @RunTTestRTTITestPropSetValueChars);
  lSuite.AddTest('TestPropSetValueRecord', @RunTTestRTTITestPropSetValueRecord);
  lSuite.AddTest('TestGetValueStringCastError', @RunTTestRTTITestGetValueStringCastError);
  lSuite.AddTest('TestGetIsReadable', @RunTTestRTTITestGetIsReadable);
  lSuite.AddTest('TestIsWritable', @RunTTestRTTITestIsWritable);
  lSuite.AddTest('TestGetAttribute', @RunTTestRTTITestGetAttribute);
  lSuite.AddTest('TestInterface', @RunTTestRTTITestInterface);
  lSuite.AddTest('TestInterfaceRaw', @RunTTestRTTITestInterfaceRaw);
  lSuite.AddTest('TestArray', @RunTTestRTTITestArray);
  lSuite.AddTest('TestDynArray', @RunTTestRTTITestDynArray);
  lSuite.AddTest('TestProcVar', @RunTTestRTTITestProcVar);
  lSuite.AddTest('TestMethod', @RunTTestRTTITestMethod);
  lSuite.AddTest('TestRawThunk', @RunTTestRTTITestRawThunk);
  lSuite:=ARegistry.AddSuite('tests.rtti.TTestClassExtendedRTTI');
  lSuite.AddTest('TestFields', @RunTTestClassExtendedRTTITestFields);
  lSuite.AddTest('TestDeclaredFields', @RunTTestClassExtendedRTTITestDeclaredFields);
  lSuite.AddTest('TestProperties', @RunTTestClassExtendedRTTITestProperties);
  lSuite.AddTest('TestDeclaredMethods', @RunTTestClassExtendedRTTITestDeclaredMethods);
  lSuite.AddTest('TestMethods', @RunTTestClassExtendedRTTITestMethods);
  lSuite.AddTest('TestMethodByAddress', @RunTTestClassExtendedRTTITestMethodByAddress);
  lSuite.AddTest('TestMethodsInherited', @RunTTestClassExtendedRTTITestMethodsInherited);
  lSuite.AddTest('TestPrivateFieldAttributes', @RunTTestClassExtendedRTTITestPrivateFieldAttributes);
  lSuite.AddTest('TestProtectedFieldAttributes', @RunTTestClassExtendedRTTITestProtectedFieldAttributes);
  lSuite.AddTest('TestPublicFieldAttributes', @RunTTestClassExtendedRTTITestPublicFieldAttributes);
  lSuite.AddTest('TestPrivatePropertyAttributes', @RunTTestClassExtendedRTTITestPrivatePropertyAttributes);
  lSuite.AddTest('TestProtectedPropertyAttributes', @RunTTestClassExtendedRTTITestProtectedPropertyAttributes);
  lSuite.AddTest('TestPublicPropertyAttributes', @RunTTestClassExtendedRTTITestPublicPropertyAttributes);
  lSuite.AddTest('TestPublishedPropertyAttributes', @RunTTestClassExtendedRTTITestPublishedPropertyAttributes);
  lSuite.AddTest('TestGetStaticProperty', @RunTTestClassExtendedRTTITestGetStaticProperty);
  lSuite.AddTest('TestSetStaticProperty', @RunTTestClassExtendedRTTITestSetStaticProperty);
  lSuite:=ARegistry.AddSuite('tests.rtti.TTestRecordExtendedRTTI');
  lSuite.AddTest('TestFields', @RunTTestRecordExtendedRTTITestFields);
  lSuite.AddTest('TestProperties', @RunTTestRecordExtendedRTTITestProperties);
  lSuite.AddTest('TestDeclaredMethods', @RunTTestRecordExtendedRTTITestDeclaredMethods);
  lSuite.AddTest('TestMethods', @RunTTestRecordExtendedRTTITestMethods);
  lSuite.AddTest('TestPrivateFieldAttributes', @RunTTestRecordExtendedRTTITestPrivateFieldAttributes);
  lSuite.AddTest('TestPublicFieldAttributes', @RunTTestRecordExtendedRTTITestPublicFieldAttributes);
end;




initialization
{$ifdef fpc}



{$else fpc}



{$endif fpc}
end.

