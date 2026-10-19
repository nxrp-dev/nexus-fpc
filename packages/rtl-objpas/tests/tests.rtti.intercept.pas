unit tests.rtti.intercept;

{$mode objfpc}{$H+}

interface

uses
obNXTestContext, obNXTestRegistry, obNXTestSuite, {$IFDEF FPC}
  {$ELSE FPC}
  TestFramework,
{$ENDIF FPC}
  SysUtils, Classes, typinfo, Rtti;

type
  EInterceptTest = class(Exception);

{$RTTI EXPLICIT METHODS[vcPrivate,vcProtected,vcPublic,vcPublished]}

  { TInterceptSample }

  TInterceptSample = class
  public
    function Add(aA, aB: Integer): Integer; virtual;
    procedure Accumulate(var aValue: Integer; aDelta: Integer); virtual;
    function Describe: String; virtual;
    procedure Boom; virtual;
    function NonVirtualAdd(aA, aB: Integer): Integer;
  end;

  { TInterceptChild }

  TInterceptChild = class(TInterceptSample)
  public
    function Add(aA, aB: Integer): Integer; override;
  end;

  {$RTTI EXPLICIT METHODS[]}
  { TNoRttiSample: 
    its virtual methods have no RTTI and sit beyond the standard TObject slots. 
    Reproduces issue #41799, where the proxy VMT was sized from RTTI-visible 
    methods only and was therefore too small. 
    }
  TNoRttiSample = class
  public
    function Value: Integer; virtual;
  end;
  {$RTTI EXPLICIT METHODS[vcPrivate,vcProtected,vcPublic,vcPublished]}

  { TTestVirtualMethodInterceptor }

  TTestVirtualMethodInterceptor = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    FBeforeCount: Integer;
    FAfterCount: Integer;
    FExceptCount: Integer;
    FLastMethodName: String;
    FLastInstance: TObject;
    FLastArgCount: SizeInt;
    FArg0, FArg1: Integer;
    FLastExceptionMsg: String;
    { configuration read by the handlers }
    FSuppress: Boolean;
    FSuppressResult: Integer;
    FResultFactor: Integer;
    FReraise: Boolean;
    FSwallowResult: Integer;
    procedure DoBefore(aInstance: TObject; aMethod: TRttiMethod; const aArgs: TValueArray; out aDoInvoke: Boolean; out aResult: TValue);
    procedure DoAfter(aInstance: TObject; aMethod: TRttiMethod; const aArgs: TValueArray; var aResult: TValue);
    procedure DoException(aInstance: TObject; aMethod: TRttiMethod; const aArgs: TValueArray; out aRaiseException: Boolean; aTheException: Exception; out aResult: TValue);
    function CreateInterceptor(aClass: TClass): TVirtualMethodInterceptor;
  protected
    procedure SetUp; virtual;
  public
    procedure TestBeforeAfterFire;
    procedure TestUnproxifyRestores;
    procedure TestSuppressInvoke;
    procedure TestModifyResult;
    procedure TestExceptionReraise;
    procedure TestExceptionSwallow;
    procedure TestNonVirtualNotIntercepted;
    procedure TestIsOperatorAndParent;
    procedure TestVarParameter;
    procedure TestChildOverride;
    procedure TestNoRttiVirtualMethodNotCrash;
  end;

procedure RegistertestsrttiinterceptTests(ARegistry: TNXTestRegistry);

implementation

{ TInterceptSample }

function TInterceptSample.Add(aA, aB: Integer): Integer;

begin
  Result:=aA + aB;
end;


procedure TInterceptSample.Accumulate(var aValue: Integer; aDelta: Integer);

begin
  aValue:=aValue + aDelta;
end;


function TInterceptSample.Describe: String;

begin
  Result:='original';
end;


procedure TInterceptSample.Boom;

begin
  raise EInterceptTest.Create('boom');
end;


function TInterceptSample.NonVirtualAdd(aA, aB: Integer): Integer;

begin
  Result:=aA + aB;
end;


{ TInterceptChild }

function TInterceptChild.Add(aA, aB: Integer): Integer;

begin
  Result:=inherited Add(aA, aB) + 1000;
end;


{ TNoRttiSample }

function TNoRttiSample.Value: Integer;

begin
  Result:=4711;
end;


{ TTestVirtualMethodInterceptor }

procedure TTestVirtualMethodInterceptor.SetUp;

begin

  FBeforeCount:=0;
  FAfterCount:=0;
  FExceptCount:=0;
  FLastMethodName:='';
  FLastInstance:=nil;
  FLastArgCount:=-1;
  FArg0:=0;
  FArg1:=0;
  FLastExceptionMsg:='';
  FSuppress:=False;
  FSuppressResult:=0;
  FResultFactor:=0;
  FReraise:=True;
  FSwallowResult:=0;
end;


procedure TTestVirtualMethodInterceptor.DoBefore(aInstance: TObject; aMethod: TRttiMethod; const aArgs: TValueArray; out aDoInvoke: Boolean; out aResult: TValue);

begin
  Inc(FBeforeCount);
  FLastMethodName:=aMethod.Name;
  FLastInstance:=aInstance;
  FLastArgCount:=Length(aArgs);
  if Length(aArgs) >= 1 then
    FArg0:=aArgs[0].AsInteger;
  if Length(aArgs) >= 2 then
    FArg1:=aArgs[1].AsInteger;
  aDoInvoke:=not FSuppress;
  if FSuppress then
    aResult:=FSuppressResult;
end;


procedure TTestVirtualMethodInterceptor.DoAfter(aInstance: TObject; aMethod: TRttiMethod; const aArgs: TValueArray; var aResult: TValue);

begin
  Inc(FAfterCount);
  if FResultFactor <> 0 then
    aResult:=aResult.AsInteger * FResultFactor;
end;


procedure TTestVirtualMethodInterceptor.DoException(aInstance: TObject; aMethod: TRttiMethod; const aArgs: TValueArray; out aRaiseException: Boolean; aTheException: Exception; out aResult: TValue);

begin
  Inc(FExceptCount);
  FLastExceptionMsg:=aTheException.Message;
  aRaiseException:=FReraise;
  if not FReraise then
    aResult:=FSwallowResult;
end;


function TTestVirtualMethodInterceptor.CreateInterceptor(aClass: TClass): TVirtualMethodInterceptor;

begin
  { degrade gracefully on platforms without a function call manager }
  try
    Result:=TVirtualMethodInterceptor.Create(aClass);
  except
    on e: ENotImplemented do
      begin
      TestContext.Skip('Method implementations not supported on this platform: ' + e.Message);
      Result:=nil;
      end;
    on e: EInsufficientRtti do
      begin
      TestContext.Skip('Insufficient RTTI: ' + e.Message);
      Result:=nil;
      end;
  end;
end;


procedure TTestVirtualMethodInterceptor.TestBeforeAfterFire;

var
  itc: TVirtualMethodInterceptor;
  obj: TInterceptSample;
  res: Integer;

begin
  itc:=CreateInterceptor(TInterceptSample);
  obj:=TInterceptSample.Create;
  try
    itc.OnBefore:=@DoBefore;
    itc.OnAfter:=@DoAfter;
    itc.Proxify(obj);
    res:=obj.Add(2, 3);
    TestContext.AssertTrue((5)=(res), 'Original method result');
    TestContext.AssertTrue((1)=(FBeforeCount), 'OnBefore fired once');
    TestContext.AssertTrue((1)=(FAfterCount), 'OnAfter fired once');
    TestContext.AssertTrue(('Add')=(FLastMethodName), 'Intercepted method name');
    TestContext.AssertTrue((obj)=(FLastInstance), 'Instance passed to handler');
    TestContext.AssertTrue((2)=(FLastArgCount), 'Argument count (Self excluded)');
    TestContext.AssertTrue((2)=(FArg0), 'First argument');
    TestContext.AssertTrue((3)=(FArg1), 'Second argument');
    itc.Unproxify(obj);
  finally
    obj.Free;
    itc.Free;
  end;
end;


procedure TTestVirtualMethodInterceptor.TestUnproxifyRestores;

var
  itc: TVirtualMethodInterceptor;
  obj: TInterceptSample;

begin
  itc:=CreateInterceptor(TInterceptSample);
  obj:=TInterceptSample.Create;
  try
    itc.OnBefore:=@DoBefore;
    itc.Proxify(obj);
    obj.Add(1, 1);
    TestContext.AssertTrue((1)=(FBeforeCount), 'Fired while proxified');
    itc.Unproxify(obj);
    TestContext.AssertTrue(obj.ClassType = TInterceptSample, 'Class restored after Unproxify');
    obj.Add(1, 1);
    TestContext.AssertTrue((1)=(FBeforeCount), 'Not fired after Unproxify');
  finally
    obj.Free;
    itc.Free;
  end;
end;


procedure TTestVirtualMethodInterceptor.TestSuppressInvoke;

var
  itc: TVirtualMethodInterceptor;
  obj: TInterceptSample;
  res: Integer;

begin
  itc:=CreateInterceptor(TInterceptSample);
  obj:=TInterceptSample.Create;
  try
    FSuppress:=True;
    FSuppressResult:=42;
    itc.OnBefore:=@DoBefore;
    itc.Proxify(obj);
    res:=obj.Add(2, 3);
    TestContext.AssertTrue((42)=(res), 'Suppressed call returns the supplied result');
  finally
    obj.Free;
    itc.Free;
  end;
end;


procedure TTestVirtualMethodInterceptor.TestModifyResult;

var
  itc: TVirtualMethodInterceptor;
  obj: TInterceptSample;
  res: Integer;

begin
  itc:=CreateInterceptor(TInterceptSample);
  obj:=TInterceptSample.Create;
  try
    FResultFactor:=2;
    itc.OnAfter:=@DoAfter;
    itc.Proxify(obj);
    res:=obj.Add(2, 3);
    TestContext.AssertTrue((10)=(res), 'OnAfter doubled the result');
  finally
    obj.Free;
    itc.Free;
  end;
end;


procedure TTestVirtualMethodInterceptor.TestExceptionReraise;

var
  itc: TVirtualMethodInterceptor;
  obj: TInterceptSample;
  raised: Boolean;

begin
  itc:=CreateInterceptor(TInterceptSample);
  obj:=TInterceptSample.Create;
  raised:=False;
  try
    FReraise:=True;
    itc.OnException:=@DoException;
    itc.Proxify(obj);
    try
      obj.Boom;
    except
      on e: EInterceptTest do
        raised:=True;
    end;
    TestContext.AssertTrue((1)=(FExceptCount), 'OnException fired');
    TestContext.AssertTrue(('boom')=(FLastExceptionMsg), 'Exception message');
    TestContext.AssertTrue(raised, 'Exception was re-raised');
  finally
    obj.Free;
    itc.Free;
  end;
end;


procedure TTestVirtualMethodInterceptor.TestExceptionSwallow;

var
  itc: TVirtualMethodInterceptor;
  obj: TInterceptSample;

begin
  itc:=CreateInterceptor(TInterceptSample);
  obj:=TInterceptSample.Create;
  try
    FReraise:=False;
    itc.OnException:=@DoException;
    itc.Proxify(obj);
    try
      obj.Boom;
    except
      TestContext.Fail('Exception should have been swallowed');
    end;
    TestContext.AssertTrue((1)=(FExceptCount), 'OnException fired');
  finally
    obj.Free;
    itc.Free;
  end;
end;


procedure TTestVirtualMethodInterceptor.TestNonVirtualNotIntercepted;

var
  itc: TVirtualMethodInterceptor;
  obj: TInterceptSample;
  res: Integer;

begin
  itc:=CreateInterceptor(TInterceptSample);
  obj:=TInterceptSample.Create;
  try
    itc.OnBefore:=@DoBefore;
    itc.Proxify(obj);
    res:=obj.NonVirtualAdd(2, 3);
    TestContext.AssertTrue((5)=(res), 'Non-virtual method result');
    TestContext.AssertTrue((0)=(FBeforeCount), 'Non-virtual methods are not intercepted');
  finally
    obj.Free;
    itc.Free;
  end;
end;


procedure TTestVirtualMethodInterceptor.TestIsOperatorAndParent;

var
  itc: TVirtualMethodInterceptor;
  obj: TInterceptSample;

begin
  itc:=CreateInterceptor(TInterceptSample);
  obj:=TInterceptSample.Create;
  try
    itc.Proxify(obj);
    TestContext.AssertTrue(obj is TInterceptSample, '"is" still holds after Proxify');
    TestContext.AssertTrue(obj.InheritsFrom(TInterceptSample), 'InheritsFrom still holds');
    TestContext.AssertTrue(itc.ProxyClass.ClassParent = TInterceptSample, 'Proxy descends from original');
    itc.Unproxify(obj);
  finally
    obj.Free;
    itc.Free;
  end;
end;


procedure TTestVirtualMethodInterceptor.TestVarParameter;

var
  itc: TVirtualMethodInterceptor;
  obj: TInterceptSample;
  value: Integer;

begin
  itc:=CreateInterceptor(TInterceptSample);
  obj:=TInterceptSample.Create;
  try
    itc.OnBefore:=@DoBefore;
    itc.OnAfter:=@DoAfter;
    itc.Proxify(obj);
    value:=10;
    obj.Accumulate(value, 5);
    TestContext.AssertTrue((15)=(value), 'var parameter written back through interception');
    TestContext.AssertTrue((1)=(FBeforeCount), 'OnBefore fired');
    TestContext.AssertTrue((1)=(FAfterCount), 'OnAfter fired');
  finally
    obj.Free;
    itc.Free;
  end;
end;


procedure TTestVirtualMethodInterceptor.TestChildOverride;

var
  itc: TVirtualMethodInterceptor;
  obj: TInterceptChild;
  res: Integer;

begin
  itc:=CreateInterceptor(TInterceptChild);
  obj:=TInterceptChild.Create;
  try
    itc.OnBefore:=@DoBefore;
    itc.Proxify(obj);
    res:=obj.Add(2, 3);
    TestContext.AssertTrue((1005)=(res), 'Childmost override is invoked');
    TestContext.AssertTrue((1)=(FBeforeCount), 'OnBefore fired once for the override');
  finally
    obj.Free;
    itc.Free;
  end;
end;


procedure TTestVirtualMethodInterceptor.TestNoRttiVirtualMethodNotCrash;

var
  itc: TVirtualMethodInterceptor;
  obj: TNoRttiSample;

begin
  itc:=CreateInterceptor(TNoRttiSample);
  obj:=TNoRttiSample.Create;
  try
    itc.Proxify(obj);
    { Issue #41799: 
      a proxified virtual method without RTTI must still be callable 
      (falling through to the original implementation) and must not
      cause an access violation because of a too-small proxy VMT. }
    TestContext.AssertTrue((4711)=(obj.Value), 'Non-RTTI virtual method callable when proxified');
    itc.Unproxify(obj);
  finally
    obj.Free;
    itc.Free;
  end;
end;



constructor TTestVirtualMethodInterceptor.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestVirtualMethodInterceptorTestBeforeAfterFire(AContext: TNXTestContext);
var lFixture: TTestVirtualMethodInterceptor;
begin
  lFixture:=TTestVirtualMethodInterceptor.Create(AContext, 'TestBeforeAfterFire');
  try
    lFixture.SetUp;
    lFixture.TestBeforeAfterFire;
  finally lFixture.Free; end;
end;

procedure RunTTestVirtualMethodInterceptorTestUnproxifyRestores(AContext: TNXTestContext);
var lFixture: TTestVirtualMethodInterceptor;
begin
  lFixture:=TTestVirtualMethodInterceptor.Create(AContext, 'TestUnproxifyRestores');
  try
    lFixture.SetUp;
    lFixture.TestUnproxifyRestores;
  finally lFixture.Free; end;
end;

procedure RunTTestVirtualMethodInterceptorTestSuppressInvoke(AContext: TNXTestContext);
var lFixture: TTestVirtualMethodInterceptor;
begin
  lFixture:=TTestVirtualMethodInterceptor.Create(AContext, 'TestSuppressInvoke');
  try
    lFixture.SetUp;
    lFixture.TestSuppressInvoke;
  finally lFixture.Free; end;
end;

procedure RunTTestVirtualMethodInterceptorTestModifyResult(AContext: TNXTestContext);
var lFixture: TTestVirtualMethodInterceptor;
begin
  lFixture:=TTestVirtualMethodInterceptor.Create(AContext, 'TestModifyResult');
  try
    lFixture.SetUp;
    lFixture.TestModifyResult;
  finally lFixture.Free; end;
end;

procedure RunTTestVirtualMethodInterceptorTestExceptionReraise(AContext: TNXTestContext);
var lFixture: TTestVirtualMethodInterceptor;
begin
  lFixture:=TTestVirtualMethodInterceptor.Create(AContext, 'TestExceptionReraise');
  try
    lFixture.SetUp;
    lFixture.TestExceptionReraise;
  finally lFixture.Free; end;
end;

procedure RunTTestVirtualMethodInterceptorTestExceptionSwallow(AContext: TNXTestContext);
var lFixture: TTestVirtualMethodInterceptor;
begin
  lFixture:=TTestVirtualMethodInterceptor.Create(AContext, 'TestExceptionSwallow');
  try
    lFixture.SetUp;
    lFixture.TestExceptionSwallow;
  finally lFixture.Free; end;
end;

procedure RunTTestVirtualMethodInterceptorTestNonVirtualNotIntercepted(AContext: TNXTestContext);
var lFixture: TTestVirtualMethodInterceptor;
begin
  lFixture:=TTestVirtualMethodInterceptor.Create(AContext, 'TestNonVirtualNotIntercepted');
  try
    lFixture.SetUp;
    lFixture.TestNonVirtualNotIntercepted;
  finally lFixture.Free; end;
end;

procedure RunTTestVirtualMethodInterceptorTestIsOperatorAndParent(AContext: TNXTestContext);
var lFixture: TTestVirtualMethodInterceptor;
begin
  lFixture:=TTestVirtualMethodInterceptor.Create(AContext, 'TestIsOperatorAndParent');
  try
    lFixture.SetUp;
    lFixture.TestIsOperatorAndParent;
  finally lFixture.Free; end;
end;

procedure RunTTestVirtualMethodInterceptorTestVarParameter(AContext: TNXTestContext);
var lFixture: TTestVirtualMethodInterceptor;
begin
  lFixture:=TTestVirtualMethodInterceptor.Create(AContext, 'TestVarParameter');
  try
    lFixture.SetUp;
    lFixture.TestVarParameter;
  finally lFixture.Free; end;
end;

procedure RunTTestVirtualMethodInterceptorTestChildOverride(AContext: TNXTestContext);
var lFixture: TTestVirtualMethodInterceptor;
begin
  lFixture:=TTestVirtualMethodInterceptor.Create(AContext, 'TestChildOverride');
  try
    lFixture.SetUp;
    lFixture.TestChildOverride;
  finally lFixture.Free; end;
end;

procedure RunTTestVirtualMethodInterceptorTestNoRttiVirtualMethodNotCrash(AContext: TNXTestContext);
var lFixture: TTestVirtualMethodInterceptor;
begin
  lFixture:=TTestVirtualMethodInterceptor.Create(AContext, 'TestNoRttiVirtualMethodNotCrash');
  try
    lFixture.SetUp;
    lFixture.TestNoRttiVirtualMethodNotCrash;
  finally lFixture.Free; end;
end;

procedure RegistertestsrttiinterceptTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tests.rtti.intercept.TTestVirtualMethodInterceptor');
  lSuite.AddTest('TestBeforeAfterFire', @RunTTestVirtualMethodInterceptorTestBeforeAfterFire, 'rtti');
  lSuite.AddTest('TestUnproxifyRestores', @RunTTestVirtualMethodInterceptorTestUnproxifyRestores, 'rtti');
  lSuite.AddTest('TestSuppressInvoke', @RunTTestVirtualMethodInterceptorTestSuppressInvoke, 'rtti');
  lSuite.AddTest('TestModifyResult', @RunTTestVirtualMethodInterceptorTestModifyResult, 'rtti');
  lSuite.AddTest('TestExceptionReraise', @RunTTestVirtualMethodInterceptorTestExceptionReraise, 'rtti');
  lSuite.AddTest('TestExceptionSwallow', @RunTTestVirtualMethodInterceptorTestExceptionSwallow, 'rtti');
  lSuite.AddTest('TestNonVirtualNotIntercepted', @RunTTestVirtualMethodInterceptorTestNonVirtualNotIntercepted, 'rtti');
  lSuite.AddTest('TestIsOperatorAndParent', @RunTTestVirtualMethodInterceptorTestIsOperatorAndParent, 'rtti');
  lSuite.AddTest('TestVarParameter', @RunTTestVirtualMethodInterceptorTestVarParameter, 'rtti');
  lSuite.AddTest('TestChildOverride', @RunTTestVirtualMethodInterceptorTestChildOverride, 'rtti');
  lSuite.AddTest('TestNoRttiVirtualMethodNotCrash', @RunTTestVirtualMethodInterceptorTestNoRttiVirtualMethodNotCrash, 'rtti');
end;

end.
