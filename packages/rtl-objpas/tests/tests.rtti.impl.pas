unit Tests.Rtti.Impl;

{$ifdef fpc}
{$mode objfpc}{$H+}
{$endif}

{ $define debug}

interface

uses
obNXTestContext, obNXTestRegistry, obNXTestSuite, {$IFDEF FPC}
  {$ELSE FPC}
  TestFramework,
{$ENDIF FPC}
  sysutils, typinfo, Rtti,
  Tests.Rtti.Util,
  tests.rtti.impltypes;

{ Note: Delphi does not provide a CreateImplementation for TRttiInvokableType
        and its descendants, so these tests are disabled for Delphi }

type
  { TTestImplBase }

  TTestImplBase = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Protected

    InputArgs: array of TValue;
    OutputArgs: array of TValue;
    ResultValue: TValue;
    InOutMapping: array of SizeInt;
    InputUntypedTypes: array of PTypeInfo;
    InvokedMethodName: String;

    procedure OnHandleIntfMethod(aMethod: TRttiMethod; const aArgs: TValueArray; out aResult: TValue);
    procedure DoIntfImpl(aIntf: IInterface; aTypeInfo: PTypeInfo; aIndex: LongInt; aInputArgs, aOutputArgs: TValueArray; aInOutMapping: array of SizeInt; aResult: TValue);
{$ifdef fpc}
    procedure OnHandleInvokable(aInvokable: TRttiInvokableType; const aArgs: TValueArray; out aResult: TValue);
    procedure DoMethodImpl(aTypeInfo: PTypeInfo; aInputArgs, aOutputArgs: TValueArray; aInOutMapping: array of SizeInt; aResult: TValue);
    procedure DoProcImpl(aTypeInfo: PTypeInfo; aInputArgs, aOutputArgs: TValueArray; aInOutMapping: array of SizeInt; aResult: TValue);
{$endif}
    end;

(*
TTestImpl = class(TTestCase)
  private
  published
    procedure TestIntfMethods;
{$ifdef fpc}
    procedure TestMethodVars;
    procedure TestProcVars;
{$endif}
  end;
*)
  { TTestIntfMethods }
  TTestIntfMethods = class(TTestImplBase)
  private
    intf: ITestInterface;
  public
    procedure DoTestIntfImpl(aIndex: LongInt; const aInputArgs, aOutputArgs: TValueArray; const aInOutMapping: array of SizeInt; aResult: TValue);
    procedure Setup; virtual;
    procedure teardown; virtual;
    public
    Procedure Test1;
    procedure Test2;
    procedure Test3;
    procedure Test4;
    procedure Test5;
    procedure Test6;
    procedure Test7;
    procedure Test8;
    procedure Test9;
    procedure Test10;
    procedure Test11;
    procedure Test12;
    procedure Test13;
    procedure Test14;
    procedure Test15;
    procedure Test16;
    procedure Test17;
    procedure Test18;
    procedure Test19;
    procedure Test20;
    procedure Test21;
    procedure Test21s;
    procedure Test22;
  end;

  { TTestDirectIntfCalls }
  TIntfCallCallBack = Procedure(aIntf : ITestInterface) of object;

  TTestDirectIntfCalls = class(TTestImplBase)
  private
    Fintf: ITestInterface;
    FActualResult : TValue;
    FProgress : Boolean;
    RecordedOutputArgs : Array of TValue;
    procedure CallTestMethod1(aIntf: ITestInterface);
    procedure CallTestMethod2(aIntf: ITestInterface);
    procedure CallTestMethod3(aIntf: ITestInterface);
    procedure CallTestMethod4(aIntf: ITestInterface);
    procedure CallTestMethod5(aIntf: ITestInterface);
    procedure CallTestMethod6(aIntf: ITestInterface);
    procedure CallTestMethod7(aIntf: ITestInterface);
    procedure CallTestMethod8(aIntf: ITestInterface);
    procedure CallTestMethod9(aIntf: ITestInterface);
    procedure CallTestMethod10(aIntf: ITestInterface);
    procedure CallTestMethod11(aIntf: ITestInterface);
    procedure CallTestMethod12(aIntf: ITestInterface);
    procedure CallTestMethod13(aIntf: ITestInterface);
    procedure CallTestMethod14(aIntf: ITestInterface);
    procedure CallTestMethod15(aIntf: ITestInterface);
    procedure CallTestMethod16(aIntf: ITestInterface);
    procedure CallTestMethod17(aIntf: ITestInterface);
    procedure CallTestMethod18(aIntf: ITestInterface);
    procedure CallTestMethod19(aIntf: ITestInterface);
    procedure CallTestMethod20(aIntf: ITestInterface);
    procedure CallTestMethod21(aIntf: ITestInterface);
    procedure CallTestMethod21s(aIntf: ITestInterface);
    procedure CallTestMethod22(aIntf: ITestInterface);
    procedure DoStep(const aname: string);
  public
    procedure DoTestIntfImpl(aCall : TIntfCallCallBack; const aName : string; const aInputArgs, aOutputArgs: TValueArray; const aInOutMapping: array of SizeInt; aResult: TValue);
    procedure Setup; virtual;
    procedure teardown; virtual;
  public
    Procedure Test1;
    procedure Test2;
    procedure Test3;
    procedure Test4;
    procedure Test5;
    procedure Test6;
    procedure Test7;
    procedure Test8;
    procedure Test9;
    procedure Test10;
    procedure Test11;
    procedure Test12;
    procedure Test13;
    procedure Test14;
    procedure Test15;
    procedure Test16;
    procedure Test17;
    procedure Test18;
    procedure Test19;
    procedure Test20;
    procedure Test21;
    procedure Test21s;
    procedure Test22;
  end;

  { TTestMethodVars }

  TTestMethodVars = class(TTestImplBase)
  public
    Procedure TestMethodVar1;
    Procedure TestMethodVar2;
    procedure TestMethodVar3;
    procedure TestMethodVar4;
    procedure TestMethodVar5;
    procedure TestMethodVar6;
    procedure TestMethodVar7;
    procedure TestMethodVar8;
    procedure TestMethodVar9;
    procedure TestMethodVar10;
    procedure TestMethodVar11;
    procedure TestMethodVar12;
    procedure TestMethodVar13;
    procedure TestMethodVar14;
    procedure TestMethodVar15;
    procedure TestMethodVar16;
    procedure TestMethodVar17;
    procedure TestMethodVar18;
    procedure TestMethodVar19;
    procedure TestMethodVar20;
    procedure TestMethodVar21;
    procedure TestMethodVar21as;
    procedure TestMethodVar21ss;
  end;

  { TTestProcVars }

  TTestProcVars = class (TTestImplBase)
  public
    Procedure TestProcVar1;
    Procedure TestProcVar2;
    procedure TestProcVar3;
    procedure TestProcVar4;
    procedure TestProcVar5;
    procedure TestProcVar6;
    procedure TestProcVar7;
    procedure TestProcVar8;
    procedure TestProcVar9;
    procedure TestProcVar10;
    procedure TestProcVar11;
    procedure TestProcVar12;
    procedure TestProcVar13;
    procedure TestProcVar14;
    procedure TestProcVar15;
    procedure TestProcVar16;
    procedure TestProcVar17;
    procedure TestProcVar18;
    procedure TestProcVar19;
    procedure TestProcVar20;
    procedure TestProcVar21;
    procedure TestProcVar21as;
    procedure TestProcVar21ss;
  end;


procedure RegisterTestsRttiImplTests(ARegistry: TNXTestRegistry);

implementation



{ TTestImpl }

procedure TTestImplBase.OnHandleIntfMethod(aMethod: TRttiMethod; const aArgs: TValueArray; out aResult: TValue);
var
  selfofs, i: SizeInt;

begin
  selfofs := 1;
  WriteLn('In Callback');
  InvokedMethodName :=  aMethod.Name;
  //  WriteLn('Self: ' + HexStr(Self));
  if Assigned(aMethod.ReturnType) then
    aResult := CopyValue(ResultValue);
  // WriteLn('Setting input args');
  SetLength(InputArgs, Length(aArgs));
  for i := 0 to High(aArgs) do begin
    // WriteLn(Format('Arg %d: %p %p %s', [i, aArgs[i].GetReferenceToRawData, PPointer(aArgs[i].GetReferenceToRawData)^, aArgs[i].TypeInfo^.Name]));
    // Writeln('Untyped: ',Assigned(InputUntypedTypes[i]));
    if Assigned(InputUntypedTypes[i]) then
      begin
      // Writeln('Input type untyped, creating value for actual type ',InputUntypedTypes[i]^.Name);
      TValue.Make(PPointer(aArgs[i].GetReferenceToRawData)^, InputUntypedTypes[i], InputArgs[i])
      end
    else
      InputArgs[i] := CopyValue(aArgs[i]);
    // Writeln('OK');
  end;
  { Note: account for Self }
  for i := 0 to High(InOutMapping) do begin
    Move(OutputArgs[i].GetReferenceToRawData^, aArgs[InOutMapping[i] + selfofs].GetReferenceToRawData^, OutputArgs[i].DataSize);
  end;
  WriteLn('Callback done');
end;

procedure TTestImplBase.DoIntfImpl(aIntf: IInterface; aTypeInfo: PTypeInfo; aIndex: LongInt; aInputArgs, aOutputArgs: TValueArray; aInOutMapping: array of SizeInt; aResult: TValue);
var
  context: TRttiContext;
  t: TRttiType;
  instance, res: TValue;
  method: TRttiMethod;
  i: SizeInt;
  input: array of TValue;
  intf: TRttiInterfaceType;
  params: array of TRttiParameter;
  name : string;
begin
  input:=nil;
  name := 'TestMethod' + IntToStr(aIndex);

  context := TRttiContext.Create;
  try
    t := context.GetType(aTypeInfo);
    TestContext.AssertTrue(t is TRttiInterfaceType, 'Not a interface type: ' + aTypeInfo^.Name);
    intf := t as TRttiInterfaceType;

    method := intf.GetMethod(name);
    TestContext.AssertTrue(Assigned(method), 'Method not found: ' + name);

    WriteLn(Format('Executing method %s', [name]));

    TestContext.AssertTrue((Length(aOutputArgs))=(Length(aInOutMapping)), 'Invalid in/out mapping');
    TestContext.AssertTrue(Length(aOutputArgs) <= Length(aInputArgs), 'Output args not part of input args');

    params := method.GetParameters;

    TValue.Make(@aIntf, aTypeInfo, instance);

    { arguments might be modified by Invoke (Note: Copy() does not uniquify the
      IValueData of managed types) }
    SetLength(input, Length(aInputArgs) + 1);
    SetLength(InputUntypedTypes, Length(aInputArgs) + 1);
    input[0] := instance;
    InputUntypedTypes[0] := Nil;
    for i := 0 to High(aInputArgs) do begin
      input[i + 1] := CopyValue(aInputArgs[i]);
      if not Assigned(params[i].ParamType) then
        InputUntypedTypes[i + 1] := aInputArgs[i].TypeInfo
      else
        InputUntypedTypes[i + 1] := Nil;
    end;

    SetLength(InOutMapping, Length(aInOutMapping));
    for i := 0 to High(InOutMapping) do
      InOutMapping[i] := aInOutMapping[i];
    SetLength(OutputArgs, Length(aOutputArgs));
    for i := 0 to High(OutputArgs) do
      OutputArgs[i] := CopyValue(aOutputArgs[i]);
    ResultValue := aResult;

    res := method.Invoke(instance, aInputArgs);
    WriteLn('After invoke');

    TestContext.AssertTrue((name)=(InvokedMethodName), 'Invoked method name differs for ' + name);
    TestContext.AssertTrue(EqualValues(ResultValue, res), 'Reported result value differs from returned for ' + name);
    TestContext.AssertTrue(EqualValues(aResult, res), 'Expected result value differs from returned for ' + name);
    TestContext.AssertTrue((Length(input))=(Length(InputArgs)), 'Count of input args differs for ' + name);
    for i := 0 to High(input) do begin
      TestContext.AssertTrue(EqualValues(input[i], InputArgs[i]), Format('Input argument %d differs for %s', [i + 1, name]));
    end;
    for i := 0 to High(aOutputArgs) do begin
      TestContext.AssertTrue(EqualValues(aOutputArgs[i], aInputArgs[InOutMapping[i]]), Format('New output argument %d differs from expected output for %s', [i + 1, name]));
    end;
  finally
    context.Free;
  end;
end;

{$ifdef fpc}
procedure TTestImplBase.OnHandleInvokable(aInvokable: TRttiInvokableType; const aArgs: TValueArray; out
  aResult: TValue);
var
  selfofs, i: SizeInt;
begin
  TestContext.AssertTrue((aInvokable is TRttiMethodType) or (aInvokable is TRttiProcedureType), 'Invokable is not a method or procedure variable: ' + aInvokable.ClassName);

  selfofs := 0;
  if aInvokable is TRttiMethodType then
    selfofs := 1;

  WriteLn('In Callback');
  WriteLn('Self: ' + HexStr(Self));
  if Assigned(aInvokable.ReturnType) then
    aResult := CopyValue(ResultValue);
  WriteLn('Setting input args');
  SetLength(InputArgs, Length(aArgs));
  for i := 0 to High(aArgs) do begin
    WriteLn(Format('Arg %d: %p %p', [i, aArgs[i].GetReferenceToRawData, PPointer(aArgs[i].GetReferenceToRawData)^]));
    if Assigned(InputUntypedTypes[i]) then
      TValue.Make(PPointer(aArgs[i].GetReferenceToRawData)^, InputUntypedTypes[i], InputArgs[i])
    else
      InputArgs[i] := CopyValue(aArgs[i]);
  end;
  WriteLn('Setting output args');
  { Note: account for Self }
  for i := 0 to High(InOutMapping) do begin
    WriteLn(Format('OutputArg %d -> Arg %d', [i, InOutMapping[i] + selfofs]));
    { check input arg type? }
    Move(OutputArgs[i].GetReferenceToRawData^, aArgs[InOutMapping[i] + selfofs].GetReferenceToRawData^, OutputArgs[i].DataSize);
  end;
  WriteLn('Callback done');
end;

procedure TTestImplBase.DoMethodImpl(aTypeInfo: PTypeInfo; aInputArgs,
  aOutputArgs: TValueArray; aInOutMapping: array of SizeInt; aResult: TValue);
var
  context: TRttiContext;
  t: TRttiType;
  callable, res: TValue;
  method: TRttiMethodType;
  i: SizeInt;
  input: array of TValue;
  impl: TMethodImplementation;
  mrec: TMethod;
  name: String;
  params: array of TRttiParameter;
begin
  Input:=nil;
  name := aTypeInfo^.Name;

  impl := Nil;
  context := TRttiContext.Create;
  try
    t := context.GetType(aTypeInfo);
    TestContext.AssertTrue(t is TRttiMethodType, 'Not a method variable: ' + name);
    method := t as TRttiMethodType;

    WriteLn(Format('Executing method %s', [name]));

    TestContext.AssertTrue((Length(aOutputArgs))=(Length(aInOutMapping)), 'Invalid in/out mapping');
    TestContext.AssertTrue(Length(aOutputArgs) <= Length(aInputArgs), 'Output args not part of input args');

    params := method.GetParameters;

    { arguments might be modified by Invoke (Note: Copy() does not uniquify the
      IValueData of managed types) }
    SetLength(input, Length(aInputArgs) + 1);
    SetLength(InputUntypedTypes, Length(aInputArgs) + 1);
    input[0] := GetPointerValue(Self);
    InputUntypedTypes[0] := Nil;
    for i := 0 to High(aInputArgs) do begin
      input[i + 1] := CopyValue(aInputArgs[i]);
      if not Assigned(params[i].ParamType) then
        InputUntypedTypes[i + 1] := aInputArgs[i].TypeInfo
      else
        InputUntypedTypes[i + 1] := Nil;
    end;

    try
      impl := method.CreateImplementation({$ifdef fpc}@{$endif}OnHandleInvokable);
    except
      on e: ENotImplemented do
        Exit;
    end;
    TestContext.AssertTrue((impl)<>nil, 'Method implementation is Nil');

    mrec.Data := Self;
    mrec.Code := impl.CodeAddress;
    TValue.Make(@mrec, aTypeInfo, callable);

    SetLength(InOutMapping, Length(aInOutMapping));
    for i := 0 to High(InOutMapping) do
      InOutMapping[i] := aInOutMapping[i];
    SetLength(OutputArgs, Length(aOutputArgs));
    for i := 0 to High(OutputArgs) do
      OutputArgs[i] := CopyValue(aOutputArgs[i]);
    ResultValue := aResult;

    res := method.Invoke(callable, aInputArgs);
    WriteLn('After invoke');

    TestContext.AssertTrue(EqualValues(ResultValue, res), 'Reported result value differs from returned for ' + name);
    TestContext.AssertTrue(EqualValues(aResult, res), 'Expected result value differs from returned for ' + name);
    TestContext.AssertTrue((Length(input))=(Length(InputArgs)), 'Count of input args differs for ' + name);
    for i := 0 to High(input) do begin
      TestContext.AssertTrue(EqualValues(input[i], InputArgs[i]), Format('Input argument %d differs for %s', [i + 1, name]));
    end;
    for i := 0 to High(aOutputArgs) do begin
      TestContext.AssertTrue(EqualValues(aOutputArgs[i], aInputArgs[InOutMapping[i]]), Format('New output argument %d differs from expected output for %s', [i + 1, name]));
    end;
  finally
    impl.Free;
    context.Free;
  end;
end;

procedure TTestImplBase.DoProcImpl(aTypeInfo: PTypeInfo; aInputArgs,
  aOutputArgs: TValueArray; aInOutMapping: array of SizeInt; aResult: TValue);
var
  context: TRttiContext;
  t: TRttiType;
  callable, res: TValue;
  proc: TRttiProcedureType;
  i: SizeInt;
  input: array of TValue;
  impl: TMethodImplementation;
  name: String;
  cp: CodePointer;
  params: array of TRttiParameter;
begin
  Input:=nil;
  name := aTypeInfo^.Name;

  impl := Nil;
  context := TRttiContext.Create;
  try
    t := context.GetType(aTypeInfo);
    TestContext.AssertTrue(t is TRttiProcedureType, 'Not a procedure variable: ' + name);
    proc := t as TRttiProcedureType;

    WriteLn(Format('Executing procedure %s', [name]));

    TestContext.AssertTrue((Length(aOutputArgs))=(Length(aInOutMapping)), 'Invalid in/out mapping');
    TestContext.AssertTrue(Length(aOutputArgs) <= Length(aInputArgs), 'Output args not part of input args');

    params := proc.GetParameters;

    { arguments might be modified by Invoke (Note: Copy() does not uniquify the
      IValueData of managed types) }
    SetLength(input, Length(aInputArgs));
    SetLength(InputUntypedTypes, Length(aInputArgs));
    for i := 0 to High(aInputArgs) do begin
      input[i] := CopyValue(aInputArgs[i]);
      if not Assigned(params[i].ParamType) then
        InputUntypedTypes[i] := aInputArgs[i].TypeInfo
      else
        InputUntypedTypes[i] := Nil;
    end;

    try
      impl := proc.CreateImplementation({$ifdef fpc}@{$endif}OnHandleInvokable);
    except
      on e: ENotImplemented do
        Exit;
    end;
    TestContext.AssertTrue((impl)<>nil, 'Method implementation is Nil');

    cp := impl.CodeAddress;
    TValue.Make(@cp, aTypeInfo, callable);

    SetLength(InOutMapping, Length(aInOutMapping));
    for i := 0 to High(InOutMapping) do
      InOutMapping[i] := aInOutMapping[i];
    SetLength(OutputArgs, Length(aOutputArgs));
    for i := 0 to High(OutputArgs) do
      OutputArgs[i] := CopyValue(aOutputArgs[i]);
    ResultValue := aResult;

    res := proc.Invoke(callable, aInputArgs);
    WriteLn('After invoke');

    TestContext.AssertTrue(EqualValues(ResultValue, res), 'Reported result value differs from returned for ' + name);
    TestContext.AssertTrue(EqualValues(aResult, res), 'Expected result value differs from returned for ' + name);
    TestContext.AssertTrue((Length(input))=(Length(InputArgs)), 'Count of input args differs for ' + name);
    for i := 0 to High(input) do begin
      TestContext.AssertTrue(EqualValues(input[i], InputArgs[i]), Format('Input argument %d differs for %s', [i + 1, name]));
    end;
    for i := 0 to High(aOutputArgs) do begin
      TestContext.AssertTrue(EqualValues(aOutputArgs[i], aInputArgs[InOutMapping[i]]), Format('New output argument %d differs from expected output for %s', [i + 1, name]));
    end;
  finally
    impl.Free;
    context.Free;
  end;
end;
{$endif}


procedure TTestIntfMethods.teardown;
begin
  Intf:=Nil;
end;

procedure TTestIntfMethods.Setup;

begin

  try
    intf := TVirtualInterface.Create(PTypeInfo(TypeInfo(ITestInterface)), {$ifdef fpc}@{$endif}OnHandleIntfMethod) as ITestInterface;
  except
    on e: ENotImplemented do
      TestContext.Skip('TVirtualInterface not supported for ' + {$I %FPCTARGETCPU%} + '-' + {$I %FPCTARGETOS%}+': '+E.Message);
  end;
  TestContext.AssertTrue(Assigned(intf), 'ITestInterface instance is Nil');
end;

procedure TTestIntfMethods.DoTestIntfImpl(aIndex: LongInt; const aInputArgs, aOutputArgs: TValueArray; const aInOutMapping: array of SizeInt; aResult: TValue);

begin
  DoIntfImpl(Intf, TypeInfo(ITestInterface),aIndex,aInputArgs,aOutputArgs,aInOutMapping,aResult);
end;

procedure TTestIntfMethods.Test1;

begin
  DoTestIntfImpl(1, [], [], [], TValue.Empty);
end;

procedure TTestIntfMethods.Test2;

begin
   DoTestIntfImpl(2, [GetIntValue(42)], [], [], GetIntValue(21));
end;

procedure TTestIntfMethods.Test3;

begin
  DoTestIntfImpl(3, [GetAnsiString('Hello World')], [], [], TValue.Empty);
end;

procedure TTestIntfMethods.Test4;

begin
  DoTestIntfImpl(4, [GetShortString('Hello World')], [], [], TValue.Empty);
end;

procedure TTestIntfMethods.Test5;

begin
  DoTestIntfImpl(5, [], [], [], GetAnsiString('Hello World'));
end;

procedure TTestIntfMethods.Test6;

begin
  DoTestIntfImpl(6, [], [], [], GetShortString('Hello World'));
end;

procedure TTestIntfMethods.Test7;

begin
  DoTestIntfImpl(7, [
    GetIntValue(1234), GetIntValue(4321), GetIntValue(0), GetIntValue(9876)
  ], [
    GetIntValue(5678), GetIntValue(6789)
  ], [1, 2], TValue.Empty);
end;

procedure TTestIntfMethods.Test8;

begin
  DoTestIntfImpl(8, [
    GetAnsiString('Alpha'), GetAnsiString('Beta'), GetAnsiString(''), GetAnsiString('Delta')
  ], [
    GetAnsiString('Gamma'), GetAnsiString('Epsilon')
  ], [1, 2], TValue.Empty);
end;

procedure TTestIntfMethods.Test9;

begin
  DoTestIntfImpl(9, [
    GetShortString('Alpha'), GetShortString('Beta'), GetShortString(''), GetShortString('Delta')
  ], [
    GetShortString('Gamma'), GetShortString('Epsilon')
  ], [1, 2], TValue.Empty);
end;

procedure TTestIntfMethods.Test10;

begin
  DoTestIntfImpl(10, [
    GetSingleValue(SingleArg1), GetSingleValue(SingleArg2In), GetSingleValue(0), GetSingleValue(SingleArg4)
  ], [
    GetSingleValue(SingleArg2Out), GetSingleValue(SingleArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestIntfMethods.Test11;

begin
  DoTestIntfImpl(11, [
    GetDoubleValue(DoubleArg1), GetDoubleValue(DoubleArg2In), GetDoubleValue(0), GetDoubleValue(DoubleArg4)
  ], [
    GetDoubleValue(DoubleArg2Out), GetDoubleValue(DoubleArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestIntfMethods.Test12;

begin
  DoTestIntfImpl(12, [
    GetExtendedValue(ExtendedArg1), GetExtendedValue(ExtendedArg2In), GetExtendedValue(0), GetExtendedValue(ExtendedArg4)
  ], [
    GetExtendedValue(ExtendedArg2Out), GetExtendedValue(ExtendedArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestIntfMethods.Test13;

begin
  DoTestIntfImpl(13, [
    GetCompValue(CompArg1), GetCompValue(CompArg2In), GetCompValue(0), GetCompValue(CompArg4)
  ], [
    GetCompValue(CompArg2Out), GetCompValue(CompArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestIntfMethods.Test14;

begin
  DoTestIntfImpl( 14, [
    GetCurrencyValue(CurrencyArg1), GetCurrencyValue(CurrencyArg2In), GetCurrencyValue(0), GetCurrencyValue(CurrencyArg4)
  ], [
    GetCurrencyValue(CurrencyArg2Out), GetCurrencyValue(CurrencyArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestIntfMethods.Test15;

begin
  DoTestIntfImpl(15, [
    GetIntValue(1), GetIntValue(2), GetIntValue(3), GetIntValue(4), GetIntValue(5),
    GetIntValue(6), GetIntValue(7), GetIntValue(8), GetIntValue(9), GetIntValue(10)
  ], [], [], GetIntValue(11));
end;

procedure TTestIntfMethods.Test16;

begin
  DoTestIntfImpl(16, [
    GetSingleValue(SingleAddArg1), GetSingleValue(SingleAddArg2), GetSingleValue(SingleAddArg3), GetSingleValue(SingleAddArg4), GetSingleValue(SingleAddArg5),
    GetSingleValue(SingleAddArg6), GetSingleValue(SingleAddArg7), GetSingleValue(SingleAddArg8), GetSingleValue(SingleAddArg9), GetSingleValue(SingleAddArg10)
  ], [], [], GetSingleValue(SingleAddRes));
end;

procedure TTestIntfMethods.Test17;

begin
  DoTestIntfImpl(17, [
    GetDoubleValue(DoubleAddArg1), GetDoubleValue(DoubleAddArg2), GetDoubleValue(DoubleAddArg3), GetDoubleValue(DoubleAddArg4), GetDoubleValue(DoubleAddArg5),
    GetDoubleValue(DoubleAddArg6), GetDoubleValue(DoubleAddArg7), GetDoubleValue(DoubleAddArg8), GetDoubleValue(DoubleAddArg9), GetDoubleValue(DoubleAddArg10)
  ], [], [], GetDoubleValue(DoubleAddRes));
end;

procedure TTestIntfMethods.Test18;

begin
  DoTestIntfImpl(18, [
    GetExtendedValue(ExtendedAddArg1), GetExtendedValue(ExtendedAddArg2), GetExtendedValue(ExtendedAddArg3), GetExtendedValue(ExtendedAddArg4), GetExtendedValue(ExtendedAddArg5),
    GetExtendedValue(ExtendedAddArg6), GetExtendedValue(ExtendedAddArg7), GetExtendedValue(ExtendedAddArg8), GetExtendedValue(ExtendedAddArg9), GetExtendedValue(ExtendedAddArg10)
  ], [], [], GetExtendedValue(ExtendedAddRes));
end;

procedure TTestIntfMethods.Test19;

begin
  DoTestIntfImpl(19, [
    GetCompValue(CompAddArg1), GetCompValue(CompAddArg2), GetCompValue(CompAddArg3), GetCompValue(CompAddArg4), GetCompValue(CompAddArg5),
    GetCompValue(CompAddArg6), GetCompValue(CompAddArg7), GetCompValue(CompAddArg8), GetCompValue(CompAddArg9), GetCompValue(CompAddArg10)
  ], [], [], GetCompValue(CompAddRes));
end;

procedure TTestIntfMethods.Test20;

begin
  DoTestIntfImpl(20, [
    GetCurrencyValue(CurrencyAddArg1), GetCurrencyValue(CurrencyAddArg2), GetCurrencyValue(CurrencyAddArg3), GetCurrencyValue(CurrencyAddArg4), GetCurrencyValue(CurrencyAddArg5),
    GetCurrencyValue(CurrencyAddArg6), GetCurrencyValue(CurrencyAddArg7), GetCurrencyValue(CurrencyAddArg8), GetCurrencyValue(CurrencyAddArg9), GetCurrencyValue(CurrencyAddArg10)
  ], [], [], GetCurrencyValue(CurrencyAddRes));
end;

procedure TTestIntfMethods.Test21;

begin
  DoTestIntfImpl(21, [
    GetIntValue(1234), GetIntValue(4321), GetIntValue(0), GetIntValue(9876)
  ], [
    GetIntValue(5678), GetIntValue(6789)
  ], [0, 1], TValue.Empty);
end;

procedure TTestIntfMethods.Test21s;

begin
  DoTestIntfImpl(21, [
    GetAnsiString('Alpha'), GetAnsiString('Beta'), GetAnsiString(''), GetAnsiString('Delta')
  ], [
    GetAnsiString('Gamma'), GetAnsiString('Epsilon')
  ], [0, 1], TValue.Empty);
end;

procedure TTestIntfMethods.Test22;

begin
  { for some reason this fails, though it fails in Delphi as well :/ }
  {
  DoTestIntfImpl(21, [
    GetShortString('Alpha'), GetShortString('Beta'), GetShortString(''), GetShortString('Delta')
  ], [
    GetShortString('Gamma'), GetShortString('Epsilon')
  ], [0, 1], TValue.Empty);
  }
end;

{ TTestDirectIntfCalls }

procedure TTestDirectIntfCalls.DoStep(const aname : string);
begin
  if FProgress then
    Writeln(aname);
end;

procedure TTestDirectIntfCalls.DoTestIntfImpl(aCall: TIntfCallCallBack;
  const aName : string;
  const aInputArgs, aOutputArgs: TValueArray;
  const aInOutMapping: array of SizeInt; aResult: TValue);
var
  context: TRttiContext;
  t: TRttiType;
  instance: TValue;
  method: TRttiMethod;
  i: SizeInt;
  input: array of TValue;
  intf: TRttiInterfaceType;
  params: array of TRttiParameter;
  i6 : Int64;
begin
//  FProgress:=True;
  input:=nil;
  context := TRttiContext.Create;
  try
    t := context.GetType(TypeInfo(ITestInterface));
    TestContext.AssertTrue(t is TRttiInterfaceType, 'Not a interface type !');
    intf := t as TRttiInterfaceType;
    method := intf.GetMethod(aname);
    TestContext.AssertTrue(Assigned(method), 'Method not found: ' + aname);
    params := method.GetParameters;
  dostep('a');
  TestContext.AssertTrue((Length(aOutputArgs))=(Length(aInOutMapping)), 'Invalid in/out mapping');
  dostep('b');
  TestContext.AssertTrue(Length(aOutputArgs) <= Length(aInputArgs), 'Output args not part of input args');
  dostep('c');
  TValue.Make(@FIntf, TypeInfo(ITestInterface), instance);
  dostep('d');
  { arguments might be modified by Invoke (Note: Copy() does not uniquify the
    IValueData of managed types) }
  SetLength(input, Length(aInputArgs) + 1);
  dostep('e');
  SetLength(InputUntypedTypes, Length(aInputArgs) + 1);
  dostep('f');
  input[0] := instance;
  dostep('g');
  InputUntypedTypes[0] := Nil;
  dostep('h');
  for i := 0 to High(aInputArgs) do begin
    dostep('h_'+IntToStr(i));
    input[i + 1] := CopyValue(aInputArgs[i]);
    dostep('h__'+IntToStr(i));
    if not Assigned(params[i].ParamType) then
      begin
      dostep('h__/'+IntToStr(i)+' : Param '+params[i].Name+' is untyped, Actual type is '+aInputArgs[i].TypeInfo^.Name);
      InputUntypedTypes[i + 1] := aInputArgs[i].TypeInfo
      end
    else
    begin
      dostep('h__\'+IntToStr(i)+' : Param '+params[i].Name+' is typed');
      InputUntypedTypes[i + 1] := Nil;
    end;
  end;
  dostep('i');

  SetLength(InOutMapping, Length(aInOutMapping));
  dostep('j');
  for i := 0 to High(InOutMapping) do
    InOutMapping[i] := aInOutMapping[i];
  dostep('k');
  SetLength(OutputArgs, Length(aOutputArgs));
  for i := 0 to High(OutputArgs) do
    OutputArgs[i] := CopyValue(aOutputArgs[i]);
  dostep('l');
  ResultValue := aResult;
  dostep('m');
  aCall(self.FIntf);
  dostep('n');
  TestContext.AssertTrue((aName)=(InvokedMethodName), 'Invoked method name differs');
  dostep('o');
  TestContext.AssertTrue(EqualValues(ResultValue, FActualResult), Format('Actual result %s value differs from saved expected %s',[FActualResult.ToString,ResultValue.ToString]));
  dostep('p');
  TestContext.AssertTrue(EqualValues(aResult, FActualResult), Format('Actual result %s value differs from expected %s',[FActualResult.ToString, aResult.ToString]));
  dostep('q');
  TestContext.AssertTrue((Length(input))=(Length(InputArgs)), 'Count of input args differs');
  dostep('q1');
  for i := 0 to Length(InputArgs)-1 do
  begin
    // Can't compare untyped in direct call.
    if (I=0) or Assigned(Params[I-1].ParamType) then
      TestContext.AssertTrue(EqualValues(input[i], InputArgs[i]), Format('Input argument %d differs (actual: %s, expected: %s)', [i,input[i].tostring, InputArgs[i].toString]));
  end;
  dostep('r');
  TestContext.AssertTrue((Length(aOutputArgs))=(Length(RecordedOutputArgs)), 'Count of recorded and expected output args differs');
  for i := 0 to High(aOutputArgs) do begin
    TestContext.AssertTrue(EqualValues(aOutputArgs[i], RecordedOutputArgs[i]), Format('New output argument %d (%s) differs from expected output (%s)', [i + 1, RecordedOutputArgs[i].ToString, aOutputArgs[i].toString]));
  end;
  dostep('s');
  finally
    context.Free;
  end;

end;


procedure TTestDirectIntfCalls.Setup;
begin

  try
    Fintf := TVirtualInterface.Create(PTypeInfo(TypeInfo(ITestInterface)), {$ifdef fpc}@{$endif}OnHandleIntfMethod) as ITestInterface;
  except
    on e: ENotImplemented do
      TestContext.Skip('TVirtualInterface not supported for ' + {$I %FPCTARGETCPU%} + '-' + {$I %FPCTARGETOS%}+': '+E.Message);
  end;
  TestContext.AssertTrue(Assigned(Fintf), 'ITestInterface instance is Nil');
  FActualResult:=TValue.Empty;
end;

procedure TTestDirectIntfCalls.teardown;
begin
  FIntf:=nil;

end;

procedure TTestDirectIntfCalls.CallTestMethod1(aIntf : ITestInterface);

begin
  DoStep('> TTestDirectIntfCalls.CallTestMethod1');
  aIntf.TestMethod1;
  DoStep('< TTestDirectIntfCalls.CallTestMethod1');
end;


procedure TTestDirectIntfCalls.Test1;
begin
  DoTestIntfImpl(@CallTestMethod1,'TestMethod1', [], [], [], TValue.Empty);
  DoStep('< TTestDirectIntfCalls.Test1');
end;

procedure TTestDirectIntfCalls.CallTestMethod2(aIntf : ITestInterface);

var
  I : Integer;

begin
  DoStep('> TTestDirectIntfCalls.CallTestMethod2');
  I:=aIntf.TestMethod2(42);
  TValue.Make(I,TypeInfo(Sizeint),FActualResult);
  DoStep('< TTestDirectIntfCalls.CallTestMethod2');
end;

procedure TTestDirectIntfCalls.Test2;
begin
  DoTestIntfImpl(@CallTestMethod2,'TestMethod2', [GetIntValue(42)], [], [], GetIntValue(21));
end;

procedure TTestDirectIntfCalls.CallTestMethod3(aIntf: ITestInterface);
begin
  DoStep('> TTestDirectIntfCalls.CallTestMethod3');
  aIntf.TestMethod3('Hello World');
  DoStep('< TTestDirectIntfCalls.CallTestMethod3');
end;


procedure TTestDirectIntfCalls.Test3;
begin
  DoTestIntfImpl(@CallTestMethod3,'TestMethod3', [GetAnsiString('Hello World')], [], [], TValue.Empty);
end;

procedure TTestDirectIntfCalls.CallTestMethod4(aIntf: ITestInterface);

var
  S : ShortString;

begin
  DoStep('> TTestDirectIntfCalls.CallTestMethod4');
  S:='Hello World';
  aIntf.TestMethod4(S);
  DoStep('< TTestDirectIntfCalls.CallTestMethod4');
end;


procedure TTestDirectIntfCalls.Test4;
begin
  DoTestIntfImpl(@CallTestMethod4,'TestMethod4', [GetShortString('Hello World')], [], [], TValue.Empty);
end;


procedure TTestDirectIntfCalls.CallTestMethod5(aIntf: ITestInterface);
var
  S : AnsiString;

begin
  DoStep('> TTestDirectIntfCalls.CallTestMethod5');
  S:=aIntf.TestMethod5();
  TValue.Make(@S,TypeInfo(AnsiString),FActualResult);
  DoStep('< TTestDirectIntfCalls.CallTestMethod5');
end;

procedure TTestDirectIntfCalls.Test5;
begin
  DoTestIntfImpl(@CallTestMethod5,'TestMethod5', [], [], [], GetAnsiString('Hello World'));
end;

procedure TTestDirectIntfCalls.CallTestMethod6(aIntf: ITestInterface);
var
  S : ShortString;

begin
  DoStep('> TTestDirectIntfCalls.CallTestMethod6');
  S:=aIntf.TestMethod6();
  TValue.Make(@S,TypeInfo(ShortString),FActualResult);
  DoStep('< TTestDirectIntfCalls.CallTestMethod6');
end;

procedure TTestDirectIntfCalls.Test6;
begin
  DoTestIntfImpl(@CallTestMethod6, 'TestMethod6', [], [], [], GetShortString('Hello World'));
end;

procedure TTestDirectIntfCalls.CallTestMethod7(aIntf: ITestInterface);

Var
  i2,i3 : SizeInt;

begin
  i2:=4321;
  i3:=0;
  aIntf.TestMethod7(1234,I2,I3,9876);
  SetLength(RecordedOutputArgs,2);
  TValue.Make(@I2,TypeInfo(SizeInt),RecordedOutputArgs[0]);
  TValue.Make(@I3,TypeInfo(SizeInt),RecordedOutputArgs[1]);
end;



procedure TTestDirectIntfCalls.Test7;
begin
  DoTestIntfImpl(@CallTestMethod7, 'TestMethod7', [
    GetIntValue(1234), GetIntValue(4321), GetIntValue(0), GetIntValue(9876)
  ], [
    GetIntValue(5678), GetIntValue(6789)
  ], [1, 2], TValue.Empty);

end;

procedure TTestDirectIntfCalls.CallTestMethod8(aIntf: ITestInterface);

var
  s2,s3 : AnsiString;

begin
  s2:='Beta';
  s3:='';
  aIntf.TestMethod8('Alpha',S2,S3,'Delta');
  SetLength(RecordedOutputArgs,2);
  TValue.Make(@S2,TypeInfo(AnsiString),RecordedOutputArgs[0]);
  TValue.Make(@S3,TypeInfo(AnsiString),RecordedOutputArgs[1]);
end;

procedure TTestDirectIntfCalls.Test8;
begin
  DoTestIntfImpl(@CallTestMethod8, 'TestMethod8', [
    GetAnsiString('Alpha'), GetAnsiString('Beta'), GetAnsiString(''), GetAnsiString('Delta')
  ], [
    GetAnsiString('Gamma'), GetAnsiString('Epsilon')
  ], [1, 2], TValue.Empty);
end;

procedure TTestDirectIntfCalls.CallTestMethod9(aIntf: ITestInterface);

Var
  S1,S2,S3,S4 : Shortstring;

begin
  S1:='Alpha';
  S2:='Beta';
  S3:='';
  S4:='Delta';
  aIntf.TestMethod9(S1,S2,S3,S4);
  SetLength(RecordedOutputArgs,2);
  TValue.Make(@S2,TypeInfo(ShortString),RecordedOutputArgs[0]);
  TValue.Make(@S3,TypeInfo(ShortString),RecordedOutputArgs[1]);
end;

procedure TTestDirectIntfCalls.Test9;
begin
  DoTestIntfImpl(@CallTestMethod9, 'TestMethod9', [
    GetShortString('Alpha'), GetShortString('Beta'), GetShortString(''), GetShortString('Delta')
  ], [
    GetShortString('Gamma'), GetShortString('Epsilon')
  ], [1, 2], TValue.Empty);
end;

procedure TTestDirectIntfCalls.CallTestMethod10(aIntf: ITestInterface);

var
  S1,S2,S3,S4 : Single;

begin
  S1:=SingleArg1;
  S2:=SingleArg2in;
  S3:=0;
  S4:=SingleArg4;
  aIntf.TestMethod10(S1,S2,S3,S4);
  SetLength(RecordedOutputArgs,2);
  TValue.Make(@S2,TypeInfo(Single),RecordedOutputArgs[0]);
  TValue.Make(@S3,TypeInfo(Single),RecordedOutputArgs[1]);
end;

procedure TTestDirectIntfCalls.Test10;
begin
  DoTestIntfImpl(@CallTestMethod10, 'TestMethod10', [
    GetSingleValue(SingleArg1), GetSingleValue(SingleArg2In), GetSingleValue(0), GetSingleValue(SingleArg4)
  ], [
    GetSingleValue(SingleArg2Out), GetSingleValue(SingleArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestDirectIntfCalls.CallTestMethod11(aIntf: ITestInterface);

var
  S1,S2,S3,S4 : Double;

begin
  S1:=DoubleArg1;
  S2:=DoubleArg2in;
  S3:=0;
  S4:=DoubleArg4;
  aIntf.TestMethod11(S1,S2,S3,S4);
  SetLength(RecordedOutputArgs,2);
  TValue.Make(@S2,TypeInfo(Double),RecordedOutputArgs[0]);
  TValue.Make(@S3,TypeInfo(Double),RecordedOutputArgs[1]);
end;

procedure TTestDirectIntfCalls.Test11;
begin
  DoTestIntfImpl(@CallTestMethod11, 'TestMethod11', [
    GetDoubleValue(DoubleArg1), GetDoubleValue(DoubleArg2In), GetDoubleValue(0), GetDoubleValue(DoubleArg4)
  ], [
    GetDoubleValue(DoubleArg2Out), GetDoubleValue(DoubleArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestDirectIntfCalls.CallTestMethod12(aIntf: ITestInterface);
var
  S1,S2,S3,S4 : Extended;

begin
  S1:=ExtendedArg1;
  S2:=ExtendedArg2in;
  S3:=0;
  S4:=ExtendedArg4;
  aIntf.TestMethod12(S1,S2,S3,S4);
  SetLength(RecordedOutputArgs,2);
  TValue.Make(@S2,TypeInfo(Extended),RecordedOutputArgs[0]);
  TValue.Make(@S3,TypeInfo(Extended),RecordedOutputArgs[1]);
end;

procedure TTestDirectIntfCalls.Test12;
begin
  DoTestIntfImpl(@CallTestMethod12, 'TestMethod12', [
    GetExtendedValue(ExtendedArg1), GetExtendedValue(ExtendedArg2In), GetExtendedValue(0), GetExtendedValue(ExtendedArg4)
  ], [
    GetExtendedValue(ExtendedArg2Out), GetExtendedValue(ExtendedArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestDirectIntfCalls.CallTestMethod13(aIntf: ITestInterface);
var
  S1,S2,S3,S4 : Comp;

begin
  S1:=CompArg1;
  S2:=CompArg2in;
  S3:=0;
  S4:=CompArg4;
  aIntf.TestMethod13(S1,S2,S3,S4);
  SetLength(RecordedOutputArgs,2);
  TValue.Make(@S2,TypeInfo(Comp),RecordedOutputArgs[0]);
  TValue.Make(@S3,TypeInfo(Comp),RecordedOutputArgs[1]);
end;

procedure TTestDirectIntfCalls.Test13;
begin
  DoTestIntfImpl(@CallTestMethod13, 'TestMethod13', [
    GetCompValue(CompArg1), GetCompValue(CompArg2In), GetCompValue(0), GetCompValue(CompArg4)
  ], [
    GetCompValue(CompArg2Out), GetCompValue(CompArg3Out)
  ], [1, 2], TValue.Empty);

end;

procedure TTestDirectIntfCalls.CallTestMethod14(aIntf: ITestInterface);
var
  S1,S2,S3,S4 : Currency;

begin
  S1:=CurrencyArg1;
  S2:=CurrencyArg2in;
  S3:=0;
  S4:=CurrencyArg4;
  aIntf.TestMethod14(S1,S2,S3,S4);
  SetLength(RecordedOutputArgs,2);
  TValue.Make(@S2,TypeInfo(Currency),RecordedOutputArgs[0]);
  TValue.Make(@S3,TypeInfo(Currency),RecordedOutputArgs[1]);
end;


procedure TTestDirectIntfCalls.Test14;
begin
  DoTestIntfImpl( @CallTestMethod14, 'TestMethod14', [
    GetCurrencyValue(CurrencyArg1), GetCurrencyValue(CurrencyArg2In), GetCurrencyValue(0), GetCurrencyValue(CurrencyArg4)
  ], [
    GetCurrencyValue(CurrencyArg2Out), GetCurrencyValue(CurrencyArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestDirectIntfCalls.CallTestMethod15(aIntf: ITestInterface);

var
  res :  SizeInt;

begin
  Res:=aIntf.TestMethod15(1,2,3,4,5,6,7,8,9,10);
  TValue.Make(@Res,TypeInfo(SizeInt),FActualResult);
end;


procedure TTestDirectIntfCalls.Test15;
begin
  DoTestIntfImpl(@CallTestMethod15, 'TestMethod15', [
    GetIntValue(1), GetIntValue(2), GetIntValue(3), GetIntValue(4), GetIntValue(5),
    GetIntValue(6), GetIntValue(7), GetIntValue(8), GetIntValue(9), GetIntValue(10)
  ], [], [], GetIntValue(11));
end;

procedure TTestDirectIntfCalls.CallTestMethod16(aIntf: ITestInterface);

var
  res : single;

begin
  Res:=aIntf.TestMethod16(SingleAddArg1,SingleAddArg2,SingleAddArg3,SingleAddArg4,SingleAddArg5,
                          SingleAddArg6,SingleAddArg7,SingleAddArg8,SingleAddArg9,SingleAddArg10);
  TValue.Make(@Res,TypeInfo(Single),FActualResult);
end;

procedure TTestDirectIntfCalls.Test16;
begin
  DoTestIntfImpl(@CallTestMethod16, 'TestMethod16', [
    GetSingleValue(SingleAddArg1), GetSingleValue(SingleAddArg2), GetSingleValue(SingleAddArg3), GetSingleValue(SingleAddArg4), GetSingleValue(SingleAddArg5),
    GetSingleValue(SingleAddArg6), GetSingleValue(SingleAddArg7), GetSingleValue(SingleAddArg8), GetSingleValue(SingleAddArg9), GetSingleValue(SingleAddArg10)
  ], [], [], GetSingleValue(SingleAddRes));
end;

procedure TTestDirectIntfCalls.CallTestMethod17(aIntf: ITestInterface);
var
  res : Double;

begin
  Res:=aIntf.TestMethod17(DoubleAddArg1,DoubleAddArg2,DoubleAddArg3,DoubleAddArg4,DoubleAddArg5,
                          DoubleAddArg6,DoubleAddArg7,DoubleAddArg8,DoubleAddArg9,DoubleAddArg10);
  TValue.Make(@Res,TypeInfo(Double),FActualResult);
end;


procedure TTestDirectIntfCalls.Test17;
begin
  DoTestIntfImpl(@CallTestMethod17, 'TestMethod17', [
    GetDoubleValue(DoubleAddArg1), GetDoubleValue(DoubleAddArg2), GetDoubleValue(DoubleAddArg3), GetDoubleValue(DoubleAddArg4), GetDoubleValue(DoubleAddArg5),
    GetDoubleValue(DoubleAddArg6), GetDoubleValue(DoubleAddArg7), GetDoubleValue(DoubleAddArg8), GetDoubleValue(DoubleAddArg9), GetDoubleValue(DoubleAddArg10)
  ], [], [], GetDoubleValue(DoubleAddRes));
end;

procedure TTestDirectIntfCalls.CallTestMethod18(aIntf: ITestInterface);
var
  res : Extended;

begin
  Res:=aIntf.TestMethod18(ExtendedAddArg1,ExtendedAddArg2,ExtendedAddArg3,ExtendedAddArg4,ExtendedAddArg5,
                          ExtendedAddArg6,ExtendedAddArg7,ExtendedAddArg8,ExtendedAddArg9,ExtendedAddArg10);
  TValue.Make(@Res,TypeInfo(Extended),FActualResult);
end;


procedure TTestDirectIntfCalls.Test18;
begin
  DoTestIntfImpl(@CallTestMethod18, 'TestMethod18', [
    GetExtendedValue(ExtendedAddArg1), GetExtendedValue(ExtendedAddArg2), GetExtendedValue(ExtendedAddArg3), GetExtendedValue(ExtendedAddArg4), GetExtendedValue(ExtendedAddArg5),
    GetExtendedValue(ExtendedAddArg6), GetExtendedValue(ExtendedAddArg7), GetExtendedValue(ExtendedAddArg8), GetExtendedValue(ExtendedAddArg9), GetExtendedValue(ExtendedAddArg10)
  ], [], [], GetExtendedValue(ExtendedAddRes));
end;

procedure TTestDirectIntfCalls.CallTestMethod19(aIntf: ITestInterface);
var
  res : comp;

begin
  Res:=aIntf.TestMethod19(compAddArg1,compAddArg2,compAddArg3,compAddArg4,compAddArg5,
                          compAddArg6,compAddArg7,compAddArg8,compAddArg9,compAddArg10);
  TValue.Make(@Res,TypeInfo(comp),FActualResult);
end;

procedure TTestDirectIntfCalls.Test19;
begin
  DoTestIntfImpl(@CallTestMethod19, 'TestMethod19', [
    GetCompValue(CompAddArg1), GetCompValue(CompAddArg2), GetCompValue(CompAddArg3), GetCompValue(CompAddArg4), GetCompValue(CompAddArg5),
    GetCompValue(CompAddArg6), GetCompValue(CompAddArg7), GetCompValue(CompAddArg8), GetCompValue(CompAddArg9), GetCompValue(CompAddArg10)
  ], [], [], GetCompValue(CompAddRes));
end;

procedure TTestDirectIntfCalls.CallTestMethod20(aIntf: ITestInterface);
var
  res : Currency;

begin
  Res:=aIntf.TestMethod20(CurrencyAddArg1,CurrencyAddArg2,CurrencyAddArg3,CurrencyAddArg4,CurrencyAddArg5,
                          CurrencyAddArg6,CurrencyAddArg7,CurrencyAddArg8,CurrencyAddArg9,CurrencyAddArg10);
  TValue.Make(@Res,TypeInfo(Currency),FActualResult);
end;

procedure TTestDirectIntfCalls.Test20;
begin
  DoTestIntfImpl(@CallTestMethod20, 'TestMethod20', [
    GetCurrencyValue(CurrencyAddArg1), GetCurrencyValue(CurrencyAddArg2), GetCurrencyValue(CurrencyAddArg3), GetCurrencyValue(CurrencyAddArg4), GetCurrencyValue(CurrencyAddArg5),
    GetCurrencyValue(CurrencyAddArg6), GetCurrencyValue(CurrencyAddArg7), GetCurrencyValue(CurrencyAddArg8), GetCurrencyValue(CurrencyAddArg9), GetCurrencyValue(CurrencyAddArg10)
  ], [], [], GetCurrencyValue(CurrencyAddRes));
end;

procedure TTestDirectIntfCalls.CallTestMethod21(aIntf: ITestInterface);

var
  S1,S2,S3,S4 : Sizeint;

begin
  S1:=1234;
  S2:=4321;
  S3:=0;
  S4:=9876;
  aIntf.TestMethod21(s1,s2,s3,s4);
  SetLength(RecordedOutputArgs,2);
  TValue.Make(@S1,TypeInfo(SizeInt),RecordedOutputArgs[0]);
  TValue.Make(@S2,TypeInfo(SizeInt),RecordedOutputArgs[1]);
end;

procedure TTestDirectIntfCalls.Test21;
begin
  DoTestIntfImpl(@CallTestMethod21, 'TestMethod21', [
    GetIntValue(1234), GetIntValue(4321), GetIntValue(0), GetIntValue(9876)
  ], [
    GetIntValue(5678), GetIntValue(6789)
  ], [0, 1], TValue.Empty);
end;

procedure TTestDirectIntfCalls.CallTestMethod21s(aIntf: ITestInterface);
var
  S1,S2,S3,S4 : AnsiString;

begin
  S1:='Alpha';
  S2:='Beta';
  S3:='';
  S4:='Delta';
  aIntf.TestMethod21(s1,s2,s3,s4);
  SetLength(RecordedOutputArgs,2);
  TValue.Make(@S1,TypeInfo(AnsiString),RecordedOutputArgs[0]);
  TValue.Make(@S2,TypeInfo(AnsiString),RecordedOutputArgs[1]);
end;

procedure TTestDirectIntfCalls.Test21s;
begin
  DoTestIntfImpl(@CallTestMethod21s, 'TestMethod21', [
    GetAnsiString('Alpha'), GetAnsiString('Beta'), GetAnsiString(''), GetAnsiString('Delta')
  ], [
    GetAnsiString('Gamma'), GetAnsiString('Epsilon')
  ], [0, 1], TValue.Empty);
end;

procedure TTestDirectIntfCalls.CallTestMethod22(aIntf: ITestInterface);


var
  S1,S2,S3,S4 : ShortString;

begin
  S1:='Alpha';
  S2:='Beta';
  S3:='';
  S4:='Delta';
  aIntf.TestMethod21(s1,s2,s3,s4);
  SetLength(RecordedOutputArgs,2);
  TValue.Make(@S1,TypeInfo(ShortString),RecordedOutputArgs[0]);
  TValue.Make(@S2,TypeInfo(ShortString),RecordedOutputArgs[1]);
end;

procedure TTestDirectIntfCalls.Test22;
begin
  { for some reason this fails, though it fails in Delphi as well :/ }
  (*

  DoTestIntfImpl(@CallTestMethod22, 'TestMethod21', [
    GetShortString('Alpha'), GetShortString('Beta'), GetShortString(''), GetShortString('Delta')
  ], [
    GetShortString('Gamma'), GetShortString('Epsilon')
  ], [0, 1], TValue.Empty);
  *)
end;

{ TTestMethodVars }

{$ifdef fpc}
procedure TTestMethodVars.TestMethodVar1;
begin
  DoMethodImpl(TypeInfo(TTestMethod1),[], [], [], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar2;
begin
  DoMethodImpl(TypeInfo(TTestMethod2),[GetIntValue(42)], [], [], GetIntValue(21));
end;

procedure TTestMethodVars.TestMethodVar3;
begin
  DoMethodImpl(TypeInfo(TTestMethod3),[GetAnsiString('Hello World')], [], [], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar4;
begin
  DoMethodImpl(TypeInfo(TTestMethod4),[GetShortString('Hello World')], [], [], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar5;
begin
  DoMethodImpl(TypeInfo(TTestMethod5),[], [], [], GetAnsiString('Hello World'));
end;

procedure TTestMethodVars.TestMethodVar6;
begin
  DoMethodImpl(TypeInfo(TTestMethod6),[], [], [], GetShortString('Hello World'));
end;

procedure TTestMethodVars.TestMethodVar7;
begin

  DoMethodImpl(TypeInfo(TTestMethod7),[
    GetIntValue(1234), GetIntValue(4321), GetIntValue(0), GetIntValue(9876)
  ], [
    GetIntValue(5678), GetIntValue(6789)
  ], [1, 2], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar8;
begin

  DoMethodImpl(TypeInfo(TTestMethod8),[
    GetAnsiString('Alpha'), GetAnsiString('Beta'), GetAnsiString(''), GetAnsiString('Delta')
  ], [
    GetAnsiString('Gamma'), GetAnsiString('Epsilon')
  ], [1, 2], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar9;
begin

  DoMethodImpl(TypeInfo(TTestMethod9),[
    GetShortString('Alpha'), GetShortString('Beta'), GetShortString(''), GetShortString('Delta')
  ], [
    GetShortString('Gamma'), GetShortString('Epsilon')
  ], [1, 2], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar10;
begin
  DoMethodImpl(TypeInfo(TTestMethod10),[
    GetSingleValue(SingleArg1), GetSingleValue(SingleArg2In), GetSingleValue(0), GetSingleValue(SingleArg4)
  ], [
    GetSingleValue(SingleArg2Out), GetSingleValue(SingleArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar11;
begin

  DoMethodImpl(TypeInfo(TTestMethod11),[
    GetDoubleValue(DoubleArg1), GetDoubleValue(DoubleArg2In), GetDoubleValue(0), GetDoubleValue(DoubleArg4)
  ], [
    GetDoubleValue(DoubleArg2Out), GetDoubleValue(DoubleArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar12;
begin

  DoMethodImpl(TypeInfo(TTestMethod12),[
    GetExtendedValue(ExtendedArg1), GetExtendedValue(ExtendedArg2In), GetExtendedValue(0), GetExtendedValue(ExtendedArg4)
  ], [
    GetExtendedValue(ExtendedArg2Out), GetExtendedValue(ExtendedArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar13;
begin
  DoMethodImpl(TypeInfo(TTestMethod13),[
    GetCompValue(CompArg1), GetCompValue(CompArg2In), GetCompValue(0), GetCompValue(CompArg4)
  ], [
    GetCompValue(CompArg2Out), GetCompValue(CompArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar14;
begin

  DoMethodImpl(TypeInfo(TTestMethod14),[
    GetCurrencyValue(CurrencyArg1), GetCurrencyValue(CurrencyArg2In), GetCurrencyValue(0), GetCurrencyValue(CurrencyArg4)
  ], [
    GetCurrencyValue(CurrencyArg2Out), GetCurrencyValue(CurrencyArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar15;
begin

  DoMethodImpl(TypeInfo(TTestMethod15),[
    GetIntValue(1), GetIntValue(2), GetIntValue(3), GetIntValue(4), GetIntValue(5),
    GetIntValue(6), GetIntValue(7), GetIntValue(8), GetIntValue(9), GetIntValue(10)
  ], [], [], GetIntValue(11));
end;

procedure TTestMethodVars.TestMethodVar16;
begin
  DoMethodImpl(TypeInfo(TTestMethod16),[
    GetSingleValue(SingleAddArg1), GetSingleValue(SingleAddArg2), GetSingleValue(SingleAddArg3), GetSingleValue(SingleAddArg4), GetSingleValue(SingleAddArg5),
    GetSingleValue(SingleAddArg6), GetSingleValue(SingleAddArg7), GetSingleValue(SingleAddArg8), GetSingleValue(SingleAddArg9), GetSingleValue(SingleAddArg10)
  ], [], [], GetSingleValue(SingleAddRes));
end;

procedure TTestMethodVars.TestMethodVar17;
begin
  DoMethodImpl(TypeInfo(TTestMethod17),[
    GetDoubleValue(DoubleAddArg1), GetDoubleValue(DoubleAddArg2), GetDoubleValue(DoubleAddArg3), GetDoubleValue(DoubleAddArg4), GetDoubleValue(DoubleAddArg5),
    GetDoubleValue(DoubleAddArg6), GetDoubleValue(DoubleAddArg7), GetDoubleValue(DoubleAddArg8), GetDoubleValue(DoubleAddArg9), GetDoubleValue(DoubleAddArg10)
  ], [], [], GetDoubleValue(DoubleAddRes));
end;

procedure TTestMethodVars.TestMethodVar18;
begin
  DoMethodImpl(TypeInfo(TTestMethod18),[
    GetExtendedValue(ExtendedAddArg1), GetExtendedValue(ExtendedAddArg2), GetExtendedValue(ExtendedAddArg3), GetExtendedValue(ExtendedAddArg4), GetExtendedValue(ExtendedAddArg5),
    GetExtendedValue(ExtendedAddArg6), GetExtendedValue(ExtendedAddArg7), GetExtendedValue(ExtendedAddArg8), GetExtendedValue(ExtendedAddArg9), GetExtendedValue(ExtendedAddArg10)
  ], [], [], GetExtendedValue(ExtendedAddRes));
end;

procedure TTestMethodVars.TestMethodVar19;
begin

  DoMethodImpl(TypeInfo(TTestMethod19),[
    GetCompValue(CompAddArg1), GetCompValue(CompAddArg2), GetCompValue(CompAddArg3), GetCompValue(CompAddArg4), GetCompValue(CompAddArg5),
    GetCompValue(CompAddArg6), GetCompValue(CompAddArg7), GetCompValue(CompAddArg8), GetCompValue(CompAddArg9), GetCompValue(CompAddArg10)
  ], [], [], GetCompValue(CompAddRes));
end;

procedure TTestMethodVars.TestMethodVar20;
begin

  DoMethodImpl(TypeInfo(TTestMethod20),[
    GetCurrencyValue(CurrencyAddArg1), GetCurrencyValue(CurrencyAddArg2), GetCurrencyValue(CurrencyAddArg3), GetCurrencyValue(CurrencyAddArg4), GetCurrencyValue(CurrencyAddArg5),
    GetCurrencyValue(CurrencyAddArg6), GetCurrencyValue(CurrencyAddArg7), GetCurrencyValue(CurrencyAddArg8), GetCurrencyValue(CurrencyAddArg9), GetCurrencyValue(CurrencyAddArg10)
  ], [], [], GetCurrencyValue(CurrencyAddRes));
end;

procedure TTestMethodVars.TestMethodVar21;
begin

  DoMethodImpl(TypeInfo(TTestMethod21),[
    GetIntValue(1234), GetIntValue(4321), GetIntValue(0), GetIntValue(9876)
  ], [
    GetIntValue(5678), GetIntValue(6789)
  ], [0, 1], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar21as;
begin
  DoMethodImpl(TypeInfo(TTestMethod21),[
    GetAnsiString('Alpha'), GetAnsiString('Beta'), GetAnsiString(''), GetAnsiString('Delta')
  ], [
    GetAnsiString('Gamma'), GetAnsiString('Epsilon')
  ], [0, 1], TValue.Empty);
end;

procedure TTestMethodVars.TestMethodVar21ss;
begin

  { for some reason this fails, though it fails in Delphi as well :/ }
  (*
  DoMethodImpl(TypeInfo(TTestMethod21),[
    GetShortString('Alpha'), GetShortString('Beta'), GetShortString(''), GetShortString('Delta')
  ], [
    GetShortString('Gamma'), GetShortString('Epsilon')
  ], [0, 1], TValue.Empty);
  *)
end;

{ TTestProcVars }

procedure TTestProcVars.TestProcVar1;
begin
  DoProcImpl(TypeInfo(TTestProc1),[], [], [], TValue.Empty);
end;

procedure TTestProcVars.TestProcVar2;
begin
  DoProcImpl(TypeInfo(TTestProc2),[GetIntValue(42)], [], [], GetIntValue(21));
end;

procedure TTestProcVars.TestProcVar3;
begin
  DoProcImpl(TypeInfo(TTestProc3),[GetAnsiString('Hello World')], [], [], TValue.Empty);
end;

procedure TTestProcVars.TestProcVar4;
begin
  DoProcImpl(TypeInfo(TTestProc4),[GetShortString('Hello World')], [], [], TValue.Empty);
end;

procedure TTestProcVars.TestProcVar5;
begin
  DoProcImpl(TypeInfo(TTestProc5),[], [], [], GetAnsiString('Hello World'));
end;

procedure TTestProcVars.TestProcVar6;
begin
  DoProcImpl(TypeInfo(TTestProc6),[], [], [], GetShortString('Hello World'));
end;

procedure TTestProcVars.TestProcVar7;
begin
  DoProcImpl(TypeInfo(TTestProc7),[
    GetIntValue(1234), GetIntValue(4321), GetIntValue(0), GetIntValue(9876)
  ], [
    GetIntValue(5678), GetIntValue(6789)
  ], [1, 2], TValue.Empty);

end;

procedure TTestProcVars.TestProcVar8;
begin

  DoProcImpl(TypeInfo(TTestProc8),[
      GetAnsiString('Alpha'), GetAnsiString('Beta'), GetAnsiString(''), GetAnsiString('Delta')
    ], [
      GetAnsiString('Gamma'), GetAnsiString('Epsilon')
    ], [1, 2], TValue.Empty);


end;

procedure TTestProcVars.TestProcVar9;
begin
  DoProcImpl(TypeInfo(TTestProc9),[
    GetShortString('Alpha'), GetShortString('Beta'), GetShortString(''), GetShortString('Delta')
  ], [
    GetShortString('Gamma'), GetShortString('Epsilon')
  ], [1, 2], TValue.Empty);

end;

procedure TTestProcVars.TestProcVar10;
begin

  DoProcImpl(TypeInfo(TTestProc10),[
      GetSingleValue(SingleArg1), GetSingleValue(SingleArg2In), GetSingleValue(0), GetSingleValue(SingleArg4)
    ], [
      GetSingleValue(SingleArg2Out), GetSingleValue(SingleArg3Out)
    ], [1, 2], TValue.Empty);
end;

procedure TTestProcVars.TestProcVar11;
begin
  DoProcImpl(TypeInfo(TTestProc11),[
    GetDoubleValue(DoubleArg1), GetDoubleValue(DoubleArg2In), GetDoubleValue(0), GetDoubleValue(DoubleArg4)
  ], [
    GetDoubleValue(DoubleArg2Out), GetDoubleValue(DoubleArg3Out)
  ], [1, 2], TValue.Empty);
end;

procedure TTestProcVars.TestProcVar12;
begin

  DoProcImpl(TypeInfo(TTestProc12),[
    GetExtendedValue(ExtendedArg1), GetExtendedValue(ExtendedArg2In), GetExtendedValue(0), GetExtendedValue(ExtendedArg4)
  ], [
    GetExtendedValue(ExtendedArg2Out), GetExtendedValue(ExtendedArg3Out)
  ], [1, 2], TValue.Empty);

end;

procedure TTestProcVars.TestProcVar13;
begin
  DoProcImpl(TypeInfo(TTestProc13),[
    GetCompValue(CompArg1), GetCompValue(CompArg2In), GetCompValue(0), GetCompValue(CompArg4)
  ], [
    GetCompValue(CompArg2Out), GetCompValue(CompArg3Out)
  ], [1, 2], TValue.Empty);

end;

procedure TTestProcVars.TestProcVar14;
begin
  DoProcImpl(TypeInfo(TTestProc14),[
    GetCurrencyValue(CurrencyArg1), GetCurrencyValue(CurrencyArg2In), GetCurrencyValue(0), GetCurrencyValue(CurrencyArg4)
  ], [
    GetCurrencyValue(CurrencyArg2Out), GetCurrencyValue(CurrencyArg3Out)
  ], [1, 2], TValue.Empty);

end;

procedure TTestProcVars.TestProcVar15;
begin

  DoProcImpl(TypeInfo(TTestProc15),[
    GetIntValue(1), GetIntValue(2), GetIntValue(3), GetIntValue(4), GetIntValue(5),
    GetIntValue(6), GetIntValue(7), GetIntValue(8), GetIntValue(9), GetIntValue(10)
  ], [], [], GetIntValue(11));

end;

procedure TTestProcVars.TestProcVar16;
begin

  DoProcImpl(TypeInfo(TTestProc16),[
    GetSingleValue(SingleAddArg1), GetSingleValue(SingleAddArg2), GetSingleValue(SingleAddArg3), GetSingleValue(SingleAddArg4), GetSingleValue(SingleAddArg5),
    GetSingleValue(SingleAddArg6), GetSingleValue(SingleAddArg7), GetSingleValue(SingleAddArg8), GetSingleValue(SingleAddArg9), GetSingleValue(SingleAddArg10)
  ], [], [], GetSingleValue(SingleAddRes));

end;

procedure TTestProcVars.TestProcVar17;
begin

  DoProcImpl(TypeInfo(TTestProc17),[
    GetDoubleValue(DoubleAddArg1), GetDoubleValue(DoubleAddArg2), GetDoubleValue(DoubleAddArg3), GetDoubleValue(DoubleAddArg4), GetDoubleValue(DoubleAddArg5),
    GetDoubleValue(DoubleAddArg6), GetDoubleValue(DoubleAddArg7), GetDoubleValue(DoubleAddArg8), GetDoubleValue(DoubleAddArg9), GetDoubleValue(DoubleAddArg10)
  ], [], [], GetDoubleValue(DoubleAddRes));

end;

procedure TTestProcVars.TestProcVar18;
begin

  DoProcImpl(TypeInfo(TTestProc18),[
    GetExtendedValue(ExtendedAddArg1), GetExtendedValue(ExtendedAddArg2), GetExtendedValue(ExtendedAddArg3), GetExtendedValue(ExtendedAddArg4), GetExtendedValue(ExtendedAddArg5),
    GetExtendedValue(ExtendedAddArg6), GetExtendedValue(ExtendedAddArg7), GetExtendedValue(ExtendedAddArg8), GetExtendedValue(ExtendedAddArg9), GetExtendedValue(ExtendedAddArg10)
  ], [], [], GetExtendedValue(ExtendedAddRes));

end;

procedure TTestProcVars.TestProcVar19;
begin

  DoProcImpl(TypeInfo(TTestProc19),[
    GetCompValue(CompAddArg1), GetCompValue(CompAddArg2), GetCompValue(CompAddArg3), GetCompValue(CompAddArg4), GetCompValue(CompAddArg5),
    GetCompValue(CompAddArg6), GetCompValue(CompAddArg7), GetCompValue(CompAddArg8), GetCompValue(CompAddArg9), GetCompValue(CompAddArg10)
  ], [], [], GetCompValue(CompAddRes));

end;

procedure TTestProcVars.TestProcVar20;
begin

  DoProcImpl(TypeInfo(TTestProc20),[
    GetCurrencyValue(CurrencyAddArg1), GetCurrencyValue(CurrencyAddArg2), GetCurrencyValue(CurrencyAddArg3), GetCurrencyValue(CurrencyAddArg4), GetCurrencyValue(CurrencyAddArg5),
    GetCurrencyValue(CurrencyAddArg6), GetCurrencyValue(CurrencyAddArg7), GetCurrencyValue(CurrencyAddArg8), GetCurrencyValue(CurrencyAddArg9), GetCurrencyValue(CurrencyAddArg10)
  ], [], [], GetCurrencyValue(CurrencyAddRes));

end;

procedure TTestProcVars.TestProcVar21;
begin
  DoProcImpl(TypeInfo(TTestProc21),[
    GetIntValue(1234), GetIntValue(4321), GetIntValue(0), GetIntValue(9876)
  ], [
    GetIntValue(5678), GetIntValue(6789)
  ], [0, 1], TValue.Empty);

end;

procedure TTestProcVars.TestProcVar21as;
begin

  DoProcImpl(TypeInfo(TTestProc21),[
    GetAnsiString('Alpha'), GetAnsiString('Beta'), GetAnsiString(''), GetAnsiString('Delta')
  ], [
    GetAnsiString('Gamma'), GetAnsiString('Epsilon')
  ], [0, 1], TValue.Empty);

end;

procedure TTestProcVars.TestProcVar21ss;
begin

  { for some reason this fails, though it fails in Delphi as well :/ }
  {
  DoProcImpl(TypeInfo(TTestProc21),[
    GetShortString('Alpha'), GetShortString('Beta'), GetShortString(''), GetShortString('Delta')
  ], [
    GetShortString('Gamma'), GetShortString('Epsilon')
  ], [0, 1], TValue.Empty);}

end;

{$endif fpc}

constructor TTestImplBase.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestIntfMethodsTest1(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test1');
  try
    lFixture.SetUp;
    try lFixture.Test1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest2(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test2');
  try
    lFixture.SetUp;
    try lFixture.Test2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest3(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test3');
  try
    lFixture.SetUp;
    try lFixture.Test3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest4(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test4');
  try
    lFixture.SetUp;
    try lFixture.Test4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest5(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test5');
  try
    lFixture.SetUp;
    try lFixture.Test5; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest6(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test6');
  try
    lFixture.SetUp;
    try lFixture.Test6; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest7(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test7');
  try
    lFixture.SetUp;
    try lFixture.Test7; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest8(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test8');
  try
    lFixture.SetUp;
    try lFixture.Test8; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest9(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test9');
  try
    lFixture.SetUp;
    try lFixture.Test9; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest10(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test10');
  try
    lFixture.SetUp;
    try lFixture.Test10; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest11(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test11');
  try
    lFixture.SetUp;
    try lFixture.Test11; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest12(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test12');
  try
    lFixture.SetUp;
    try lFixture.Test12; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest13(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test13');
  try
    lFixture.SetUp;
    try lFixture.Test13; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest14(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test14');
  try
    lFixture.SetUp;
    try lFixture.Test14; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest15(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test15');
  try
    lFixture.SetUp;
    try lFixture.Test15; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest16(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test16');
  try
    lFixture.SetUp;
    try lFixture.Test16; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest17(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test17');
  try
    lFixture.SetUp;
    try lFixture.Test17; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest18(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test18');
  try
    lFixture.SetUp;
    try lFixture.Test18; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest19(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test19');
  try
    lFixture.SetUp;
    try lFixture.Test19; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest20(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test20');
  try
    lFixture.SetUp;
    try lFixture.Test20; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest21(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test21');
  try
    lFixture.SetUp;
    try lFixture.Test21; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest21s(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test21s');
  try
    lFixture.SetUp;
    try lFixture.Test21s; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestIntfMethodsTest22(AContext: TNXTestContext);
var lFixture: TTestIntfMethods;
begin
  lFixture:=TTestIntfMethods.Create(AContext, 'Test22');
  try
    lFixture.SetUp;
    try lFixture.Test22; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest1(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test1');
  try
    lFixture.SetUp;
    try lFixture.Test1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest2(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test2');
  try
    lFixture.SetUp;
    try lFixture.Test2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest3(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test3');
  try
    lFixture.SetUp;
    try lFixture.Test3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest4(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test4');
  try
    lFixture.SetUp;
    try lFixture.Test4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest5(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test5');
  try
    lFixture.SetUp;
    try lFixture.Test5; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest6(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test6');
  try
    lFixture.SetUp;
    try lFixture.Test6; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest7(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test7');
  try
    lFixture.SetUp;
    try lFixture.Test7; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest8(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test8');
  try
    lFixture.SetUp;
    try lFixture.Test8; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest9(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test9');
  try
    lFixture.SetUp;
    try lFixture.Test9; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest10(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test10');
  try
    lFixture.SetUp;
    try lFixture.Test10; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest11(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test11');
  try
    lFixture.SetUp;
    try lFixture.Test11; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest12(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test12');
  try
    lFixture.SetUp;
    try lFixture.Test12; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest13(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test13');
  try
    lFixture.SetUp;
    try lFixture.Test13; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest14(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test14');
  try
    lFixture.SetUp;
    try lFixture.Test14; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest15(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test15');
  try
    lFixture.SetUp;
    try lFixture.Test15; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest16(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test16');
  try
    lFixture.SetUp;
    try lFixture.Test16; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest17(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test17');
  try
    lFixture.SetUp;
    try lFixture.Test17; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest18(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test18');
  try
    lFixture.SetUp;
    try lFixture.Test18; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest19(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test19');
  try
    lFixture.SetUp;
    try lFixture.Test19; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest20(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test20');
  try
    lFixture.SetUp;
    try lFixture.Test20; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest21(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test21');
  try
    lFixture.SetUp;
    try lFixture.Test21; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest21s(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test21s');
  try
    lFixture.SetUp;
    try lFixture.Test21s; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestDirectIntfCallsTest22(AContext: TNXTestContext);
var lFixture: TTestDirectIntfCalls;
begin
  lFixture:=TTestDirectIntfCalls.Create(AContext, 'Test22');
  try
    lFixture.SetUp;
    try lFixture.Test22; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar1(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar1');
  try
    lFixture.TestMethodVar1;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar2(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar2');
  try
    lFixture.TestMethodVar2;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar3(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar3');
  try
    lFixture.TestMethodVar3;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar4(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar4');
  try
    lFixture.TestMethodVar4;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar5(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar5');
  try
    lFixture.TestMethodVar5;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar6(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar6');
  try
    lFixture.TestMethodVar6;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar7(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar7');
  try
    lFixture.TestMethodVar7;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar8(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar8');
  try
    lFixture.TestMethodVar8;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar9(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar9');
  try
    lFixture.TestMethodVar9;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar10(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar10');
  try
    lFixture.TestMethodVar10;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar11(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar11');
  try
    lFixture.TestMethodVar11;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar12(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar12');
  try
    lFixture.TestMethodVar12;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar13(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar13');
  try
    lFixture.TestMethodVar13;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar14(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar14');
  try
    lFixture.TestMethodVar14;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar15(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar15');
  try
    lFixture.TestMethodVar15;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar16(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar16');
  try
    lFixture.TestMethodVar16;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar17(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar17');
  try
    lFixture.TestMethodVar17;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar18(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar18');
  try
    lFixture.TestMethodVar18;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar19(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar19');
  try
    lFixture.TestMethodVar19;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar20(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar20');
  try
    lFixture.TestMethodVar20;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar21(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar21');
  try
    lFixture.TestMethodVar21;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar21as(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar21as');
  try
    lFixture.TestMethodVar21as;
  finally lFixture.Free; end;
end;

procedure RunTTestMethodVarsTestMethodVar21ss(AContext: TNXTestContext);
var lFixture: TTestMethodVars;
begin
  lFixture:=TTestMethodVars.Create(AContext, 'TestMethodVar21ss');
  try
    lFixture.TestMethodVar21ss;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar1(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar1');
  try
    lFixture.TestProcVar1;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar2(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar2');
  try
    lFixture.TestProcVar2;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar3(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar3');
  try
    lFixture.TestProcVar3;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar4(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar4');
  try
    lFixture.TestProcVar4;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar5(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar5');
  try
    lFixture.TestProcVar5;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar6(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar6');
  try
    lFixture.TestProcVar6;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar7(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar7');
  try
    lFixture.TestProcVar7;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar8(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar8');
  try
    lFixture.TestProcVar8;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar9(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar9');
  try
    lFixture.TestProcVar9;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar10(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar10');
  try
    lFixture.TestProcVar10;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar11(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar11');
  try
    lFixture.TestProcVar11;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar12(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar12');
  try
    lFixture.TestProcVar12;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar13(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar13');
  try
    lFixture.TestProcVar13;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar14(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar14');
  try
    lFixture.TestProcVar14;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar15(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar15');
  try
    lFixture.TestProcVar15;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar16(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar16');
  try
    lFixture.TestProcVar16;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar17(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar17');
  try
    lFixture.TestProcVar17;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar18(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar18');
  try
    lFixture.TestProcVar18;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar19(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar19');
  try
    lFixture.TestProcVar19;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar20(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar20');
  try
    lFixture.TestProcVar20;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar21(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar21');
  try
    lFixture.TestProcVar21;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar21as(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar21as');
  try
    lFixture.TestProcVar21as;
  finally lFixture.Free; end;
end;

procedure RunTTestProcVarsTestProcVar21ss(AContext: TNXTestContext);
var lFixture: TTestProcVars;
begin
  lFixture:=TTestProcVars.Create(AContext, 'TestProcVar21ss');
  try
    lFixture.TestProcVar21ss;
  finally lFixture.Free; end;
end;

procedure RegisterTestsRttiImplTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('Tests.Rtti.Impl.TTestIntfMethods');
  lSuite.AddTest('Test1', @RunTTestIntfMethodsTest1, 'rtti');
  lSuite.AddTest('Test2', @RunTTestIntfMethodsTest2, 'rtti');
  lSuite.AddTest('Test3', @RunTTestIntfMethodsTest3, 'rtti');
  lSuite.AddTest('Test4', @RunTTestIntfMethodsTest4, 'rtti');
  lSuite.AddTest('Test5', @RunTTestIntfMethodsTest5, 'rtti');
  lSuite.AddTest('Test6', @RunTTestIntfMethodsTest6, 'rtti');
  lSuite.AddTest('Test7', @RunTTestIntfMethodsTest7, 'rtti');
  lSuite.AddTest('Test8', @RunTTestIntfMethodsTest8, 'rtti');
  lSuite.AddTest('Test9', @RunTTestIntfMethodsTest9, 'rtti');
  lSuite.AddTest('Test10', @RunTTestIntfMethodsTest10, 'rtti');
  lSuite.AddTest('Test11', @RunTTestIntfMethodsTest11, 'rtti');
  lSuite.AddTest('Test12', @RunTTestIntfMethodsTest12, 'rtti');
  lSuite.AddTest('Test13', @RunTTestIntfMethodsTest13, 'rtti');
  lSuite.AddTest('Test14', @RunTTestIntfMethodsTest14, 'rtti');
  lSuite.AddTest('Test15', @RunTTestIntfMethodsTest15, 'rtti');
  lSuite.AddTest('Test16', @RunTTestIntfMethodsTest16, 'rtti');
  lSuite.AddTest('Test17', @RunTTestIntfMethodsTest17, 'rtti');
  lSuite.AddTest('Test18', @RunTTestIntfMethodsTest18, 'rtti');
  lSuite.AddTest('Test19', @RunTTestIntfMethodsTest19, 'rtti');
  lSuite.AddTest('Test20', @RunTTestIntfMethodsTest20, 'rtti');
  lSuite.AddTest('Test21', @RunTTestIntfMethodsTest21, 'rtti');
  lSuite.AddTest('Test21s', @RunTTestIntfMethodsTest21s, 'rtti');
  lSuite.AddTest('Test22', @RunTTestIntfMethodsTest22, 'rtti');
  lSuite:=ARegistry.AddSuite('Tests.Rtti.Impl.TTestDirectIntfCalls');
  lSuite.AddTest('Test1', @RunTTestDirectIntfCallsTest1, 'rtti');
  lSuite.AddTest('Test2', @RunTTestDirectIntfCallsTest2, 'rtti');
  lSuite.AddTest('Test3', @RunTTestDirectIntfCallsTest3, 'rtti');
  lSuite.AddTest('Test4', @RunTTestDirectIntfCallsTest4, 'rtti');
  lSuite.AddTest('Test5', @RunTTestDirectIntfCallsTest5, 'rtti');
  lSuite.AddTest('Test6', @RunTTestDirectIntfCallsTest6, 'rtti');
  lSuite.AddTest('Test7', @RunTTestDirectIntfCallsTest7, 'rtti');
  lSuite.AddTest('Test8', @RunTTestDirectIntfCallsTest8, 'rtti');
  lSuite.AddTest('Test9', @RunTTestDirectIntfCallsTest9, 'rtti');
  lSuite.AddTest('Test10', @RunTTestDirectIntfCallsTest10, 'rtti');
  lSuite.AddTest('Test11', @RunTTestDirectIntfCallsTest11, 'rtti');
  lSuite.AddTest('Test12', @RunTTestDirectIntfCallsTest12, 'rtti');
  lSuite.AddTest('Test13', @RunTTestDirectIntfCallsTest13, 'rtti');
  lSuite.AddTest('Test14', @RunTTestDirectIntfCallsTest14, 'rtti');
  lSuite.AddTest('Test15', @RunTTestDirectIntfCallsTest15, 'rtti');
  lSuite.AddTest('Test16', @RunTTestDirectIntfCallsTest16, 'rtti');
  lSuite.AddTest('Test17', @RunTTestDirectIntfCallsTest17, 'rtti');
  lSuite.AddTest('Test18', @RunTTestDirectIntfCallsTest18, 'rtti');
  lSuite.AddTest('Test19', @RunTTestDirectIntfCallsTest19, 'rtti');
  lSuite.AddTest('Test20', @RunTTestDirectIntfCallsTest20, 'rtti');
  lSuite.AddTest('Test21', @RunTTestDirectIntfCallsTest21, 'rtti');
  lSuite.AddTest('Test21s', @RunTTestDirectIntfCallsTest21s, 'rtti');
  lSuite.AddTest('Test22', @RunTTestDirectIntfCallsTest22, 'rtti');
  lSuite:=ARegistry.AddSuite('Tests.Rtti.Impl.TTestMethodVars');
  lSuite.AddTest('TestMethodVar1', @RunTTestMethodVarsTestMethodVar1, 'rtti');
  lSuite.AddTest('TestMethodVar2', @RunTTestMethodVarsTestMethodVar2, 'rtti');
  lSuite.AddTest('TestMethodVar3', @RunTTestMethodVarsTestMethodVar3, 'rtti');
  lSuite.AddTest('TestMethodVar4', @RunTTestMethodVarsTestMethodVar4, 'rtti');
  lSuite.AddTest('TestMethodVar5', @RunTTestMethodVarsTestMethodVar5, 'rtti');
  lSuite.AddTest('TestMethodVar6', @RunTTestMethodVarsTestMethodVar6, 'rtti');
  lSuite.AddTest('TestMethodVar7', @RunTTestMethodVarsTestMethodVar7, 'rtti');
  lSuite.AddTest('TestMethodVar8', @RunTTestMethodVarsTestMethodVar8, 'rtti');
  lSuite.AddTest('TestMethodVar9', @RunTTestMethodVarsTestMethodVar9, 'rtti');
  lSuite.AddTest('TestMethodVar10', @RunTTestMethodVarsTestMethodVar10, 'rtti');
  lSuite.AddTest('TestMethodVar11', @RunTTestMethodVarsTestMethodVar11, 'rtti');
  lSuite.AddTest('TestMethodVar12', @RunTTestMethodVarsTestMethodVar12, 'rtti');
  lSuite.AddTest('TestMethodVar13', @RunTTestMethodVarsTestMethodVar13, 'rtti');
  lSuite.AddTest('TestMethodVar14', @RunTTestMethodVarsTestMethodVar14, 'rtti');
  lSuite.AddTest('TestMethodVar15', @RunTTestMethodVarsTestMethodVar15, 'rtti');
  lSuite.AddTest('TestMethodVar16', @RunTTestMethodVarsTestMethodVar16, 'rtti');
  lSuite.AddTest('TestMethodVar17', @RunTTestMethodVarsTestMethodVar17, 'rtti');
  lSuite.AddTest('TestMethodVar18', @RunTTestMethodVarsTestMethodVar18, 'rtti');
  lSuite.AddTest('TestMethodVar19', @RunTTestMethodVarsTestMethodVar19, 'rtti');
  lSuite.AddTest('TestMethodVar20', @RunTTestMethodVarsTestMethodVar20, 'rtti');
  lSuite.AddTest('TestMethodVar21', @RunTTestMethodVarsTestMethodVar21, 'rtti');
  lSuite.AddTest('TestMethodVar21as', @RunTTestMethodVarsTestMethodVar21as, 'rtti');
  lSuite.AddTest('TestMethodVar21ss', @RunTTestMethodVarsTestMethodVar21ss, 'rtti');
  lSuite:=ARegistry.AddSuite('Tests.Rtti.Impl.TTestProcVars');
  lSuite.AddTest('TestProcVar1', @RunTTestProcVarsTestProcVar1, 'rtti');
  lSuite.AddTest('TestProcVar2', @RunTTestProcVarsTestProcVar2, 'rtti');
  lSuite.AddTest('TestProcVar3', @RunTTestProcVarsTestProcVar3, 'rtti');
  lSuite.AddTest('TestProcVar4', @RunTTestProcVarsTestProcVar4, 'rtti');
  lSuite.AddTest('TestProcVar5', @RunTTestProcVarsTestProcVar5, 'rtti');
  lSuite.AddTest('TestProcVar6', @RunTTestProcVarsTestProcVar6, 'rtti');
  lSuite.AddTest('TestProcVar7', @RunTTestProcVarsTestProcVar7, 'rtti');
  lSuite.AddTest('TestProcVar8', @RunTTestProcVarsTestProcVar8, 'rtti');
  lSuite.AddTest('TestProcVar9', @RunTTestProcVarsTestProcVar9, 'rtti');
  lSuite.AddTest('TestProcVar10', @RunTTestProcVarsTestProcVar10, 'rtti');
  lSuite.AddTest('TestProcVar11', @RunTTestProcVarsTestProcVar11, 'rtti');
  lSuite.AddTest('TestProcVar12', @RunTTestProcVarsTestProcVar12, 'rtti');
  lSuite.AddTest('TestProcVar13', @RunTTestProcVarsTestProcVar13, 'rtti');
  lSuite.AddTest('TestProcVar14', @RunTTestProcVarsTestProcVar14, 'rtti');
  lSuite.AddTest('TestProcVar15', @RunTTestProcVarsTestProcVar15, 'rtti');
  lSuite.AddTest('TestProcVar16', @RunTTestProcVarsTestProcVar16, 'rtti');
  lSuite.AddTest('TestProcVar17', @RunTTestProcVarsTestProcVar17, 'rtti');
  lSuite.AddTest('TestProcVar18', @RunTTestProcVarsTestProcVar18, 'rtti');
  lSuite.AddTest('TestProcVar19', @RunTTestProcVarsTestProcVar19, 'rtti');
  lSuite.AddTest('TestProcVar20', @RunTTestProcVarsTestProcVar20, 'rtti');
  lSuite.AddTest('TestProcVar21', @RunTTestProcVarsTestProcVar21, 'rtti');
  lSuite.AddTest('TestProcVar21as', @RunTTestProcVarsTestProcVar21as, 'rtti');
  lSuite.AddTest('TestProcVar21ss', @RunTTestProcVarsTestProcVar21ss, 'rtti');
end;



initialization
{$ifdef fpc}




{$endif fpc}
end.

