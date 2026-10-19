unit tcpersistent;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils;

type

  { TTestTPersistent }

  TTestTPersistent= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  protected
    Instance : TPersistent;
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure TestPropCount;
    procedure TestNamePath;
  end;

  { TMyPersistent }

  TMyPersistent = Class(TPersistent)
  private
    FMyProp: Integer;
    FOwner : TPersistent;
  protected
    function GetOwner: TPersistent; override;
  public
    procedure Assign(Source: TPersistent); override;
  published
    Property MyProp : Integer Read FMyProp Write FMyProp;
  end;

  { TTestPersistentDescendent }

  TTestPersistentDescendent = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    procedure WrongAssign;
  Protected
    Instance : TMyPersistent;
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure TestPropCount;
    procedure TestNamePath;
    procedure TestNamePathWithOwner;
    Procedure TestAssign;
    Procedure TestAssignFail;
  end;


procedure RegistertcpersistentTests(ARegistry: TNXTestRegistry);

implementation

uses typinfo;

procedure TTestTPersistent.TestPropCount;

Var
  ACOunt : Integer;
  P : Pointer;

begin
  P:=Nil;
  ACOunt:=GetPropList(Instance,P);
  TestContext.AssertTrue((0)=(ACount), 'Property count of TPersistence is zero');
end;

procedure TTestTPersistent.TestNamePath;
begin
  TestContext.AssertTrue(('TPersistent')=(Instance.GetNamePath), 'Namepath is class name if there is no owner');
end;

procedure TTestTPersistent.SetUp;
begin
  Instance:=TPersistent.Create;
end;

procedure TTestTPersistent.TearDown;
begin
  FreeAndNil(Instance);
end;

{ TTestPersistentDescendent }

procedure TTestPersistentDescendent.SetUp;
begin
  Instance:=TMyPersistent.Create;
end;

procedure TTestPersistentDescendent.TearDown;
begin
  FreeAndNil(Instance);
end;

procedure TTestPersistentDescendent.TestPropCount;

Var
  ACOunt : Integer;
  P : Pointer;

begin
  P:=Nil;
  ACount:=GetPropList(Instance,P);
  TestContext.AssertTrue((1)=(ACount), 'Property count of TPersistence is zero');
  Freemem(p);
end;

procedure TTestPersistentDescendent.TestNamePath;
begin
  TestContext.AssertTrue(('TMyPersistent')=(Instance.GetNamePath), 'Namepath is class name if there is no owner');
end;

procedure TTestPersistentDescendent.TestNamePathWithOwner;

Var
  AOwner : TMyPersistent;

begin
  AOwner:=TMyPersistent.Create;
  try
    Instance.FOwner:=AOwner;
    TestContext.AssertTrue(('TMyPersistent.TMyPersistent')=(Instance.GetNamePath), 'Namepath is owner namepath plus class name');
  finally
    Aowner.Free;
  end;
end;

procedure TTestPersistentDescendent.TestAssign;

Var
  I2 : TMyPersistent;

begin
  I2:=TMyPersistent.Create;
  try
    I2.MyProp:=2;
    Instance.Assign(I2);
    TestContext.AssertTrue((2)=(Instance.MyProp), 'Property passed on during assign');
  finally
    I2.Free;
  end;
end;


procedure TTestPersistentDescendent.TestAssignFail;

begin
  TestContext.AssertRaises(EConvertError, @WrongAssign, 'Assigning the wrong class');
end;

procedure TTestPersistentDescendent.WrongAssign;
Var
  I2 : TPersistent;

begin
  I2:=TPersistent.Create;
  try
    Instance.Assign(I2);
  finally
    I2.Free;
  end;
end;

{ TMyPersistent }

function TMyPersistent.GetOwner: TPersistent;
begin
  Result:=FOwner;
end;

procedure TMyPersistent.Assign(Source: TPersistent);
begin
  If (Source is TMyPersistent) then
    FMyProp:=TMyPersistent(Source).FMyProp
  else
    Inherited;
end;


constructor TTestTPersistent.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestPersistentDescendent.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestTPersistentTestPropCount(AContext: TNXTestContext);
var lFixture: TTestTPersistent;
begin
  lFixture:=TTestTPersistent.Create(AContext, 'TestPropCount');
  try
    lFixture.SetUp;
    try lFixture.TestPropCount; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTPersistentTestNamePath(AContext: TNXTestContext);
var lFixture: TTestTPersistent;
begin
  lFixture:=TTestTPersistent.Create(AContext, 'TestNamePath');
  try
    lFixture.SetUp;
    try lFixture.TestNamePath; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPersistentDescendentTestPropCount(AContext: TNXTestContext);
var lFixture: TTestPersistentDescendent;
begin
  lFixture:=TTestPersistentDescendent.Create(AContext, 'TestPropCount');
  try
    lFixture.SetUp;
    try lFixture.TestPropCount; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPersistentDescendentTestNamePath(AContext: TNXTestContext);
var lFixture: TTestPersistentDescendent;
begin
  lFixture:=TTestPersistentDescendent.Create(AContext, 'TestNamePath');
  try
    lFixture.SetUp;
    try lFixture.TestNamePath; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPersistentDescendentTestNamePathWithOwner(AContext: TNXTestContext);
var lFixture: TTestPersistentDescendent;
begin
  lFixture:=TTestPersistentDescendent.Create(AContext, 'TestNamePathWithOwner');
  try
    lFixture.SetUp;
    try lFixture.TestNamePathWithOwner; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPersistentDescendentTestAssign(AContext: TNXTestContext);
var lFixture: TTestPersistentDescendent;
begin
  lFixture:=TTestPersistentDescendent.Create(AContext, 'TestAssign');
  try
    lFixture.SetUp;
    try lFixture.TestAssign; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPersistentDescendentTestAssignFail(AContext: TNXTestContext);
var lFixture: TTestPersistentDescendent;
begin
  lFixture:=TTestPersistentDescendent.Create(AContext, 'TestAssignFail');
  try
    lFixture.SetUp;
    try lFixture.TestAssignFail; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertcpersistentTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tcpersistent.TTestTPersistent');
  lSuite.AddTest('TestPropCount', @RunTTestTPersistentTestPropCount, 'collections');
  lSuite.AddTest('TestNamePath', @RunTTestTPersistentTestNamePath, 'collections');
  lSuite:=ARegistry.AddSuite('tcpersistent.TTestPersistentDescendent');
  lSuite.AddTest('TestPropCount', @RunTTestPersistentDescendentTestPropCount, 'collections');
  lSuite.AddTest('TestNamePath', @RunTTestPersistentDescendentTestNamePath, 'collections');
  lSuite.AddTest('TestNamePathWithOwner', @RunTTestPersistentDescendentTestNamePathWithOwner, 'collections');
  lSuite.AddTest('TestAssign', @RunTTestPersistentDescendentTestAssign, 'collections');
  lSuite.AddTest('TestAssignFail', @RunTTestPersistentDescendentTestAssignFail, 'collections');
end;

end.
