unit tccomponent;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils;

type

  { TEventSink }

  TEventSink = Class(TObject)
    FEventCount : Integer;
    FLastSender : TObject;
    Procedure Event(Sender : TObject); virtual;
    Procedure ResetEvent;
  end;

  { TNotification }

  TNotification = Class(TCollectionItem)
  Public
    ASender,
    AComponent : TComponent;
    AOperation : TOperation;
  end;

  { TNotificationSink }

  TNotificationSink = Class(TObject)
  private
    Fevents : TCollection;
    function GetNot(Index : Integer): TNotification;
  Public
    Destructor Destroy; override;
    procedure Notification(Sender, AComponent: TComponent; Operation: TOperation); virtual;
    Procedure Reset;
    Function EventCount : Integer;
    Property Notifications [Index : Integer] : TNotification Read GetNot;
  end;

  { TMyComponent }

  TNotificationEvent = procedure (Sender : TComponent; AComponent: TComponent; Operation: TOperation) of object;

  TMyComponent = Class(TComponent)
  private
    FOnDestroy: TNotifyEvent;
    FOnNotify: TNotificationEvent;
  Public
    Destructor Destroy; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    Property OnDestroy : TNotifyEvent Read FOnDestroy Write FOnDestroy;
    Property OnNotification : TNotificationEvent Read FOnNotify Write FOnNotify;
  end;

  { TTestTComponentBase }

  TTestTComponentBase = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  protected
    FRoot : TMyComponent;
    Procedure CreateComponents(ACount : Integer);
    Procedure CreateComponents(ACount : Integer; Const BaseName : String);
    Procedure CreateComponents(ACount : Integer; AClass : TComponentClass);
    Procedure CreateComponents(ACount : Integer; AClass : TComponentClass; Const BaseName : String);
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  end;

  { TTestTComponent }

  TTestTComponent = Class(TTestTComponentBase)
  private
    procedure TestDoubleName;
    procedure TestTextName;
    procedure TestNumberName;
    procedure TestNumberTextName;
  public
    Procedure TestCreate;
    Procedure TestName;
    procedure TestIdentiFierName;
    procedure TestIdentiFierNameTwo;
    procedure TestIdentiFierNameThree;
    procedure TestIdentiFierNameFour;
    procedure TestOwner;
    procedure TestChildren;
    Procedure TestDestroyChild;
    Procedure TestDestroyChildren;
    Procedure TestUniqueName;
    Procedure TestRemoveComponent;
  end;

  { TTestTComponentNotifies }

  TTestTComponentNotifies = Class(TTestTComponentBase)
  Protected
    N : TNotificationSink;
    procedure SetUp; override;
    procedure TearDown; override;
  public
    Procedure TestInsertNotification;
    Procedure TestRemoveNotification;
  end;


procedure RegistertccomponentTests(ARegistry: TNXTestRegistry);

implementation

procedure TTestTComponentBase.CreateComponents(ACount: Integer);
begin
  CreateComponents(ACount,'');
end;

procedure TTestTComponentBase.CreateComponents(ACount: Integer;
  const BaseName: String);
begin
  CreateComponents(ACount,TMyComponent,BaseName);
end;

procedure TTestTComponentBase.CreateComponents(ACount: Integer;
  AClass: TComponentClass);
begin
  CreateComponents(ACount,AClass,'');
end;

procedure TTestTComponentBase.CreateComponents(ACount: Integer;
  AClass: TComponentClass; const BaseName: String);

Var
  I : Integer;
  C : TComponent;

begin
  For I:=0 to ACount-1 do
    begin
    C:=TMyComponent.Create(FRoot);
    If (BaseName<>'') then
      C.Name:=BaseName+IntToStr(I+1);
    end;
end;

procedure TTestTComponentBase.SetUp;
begin
  FRoot:=TMyComponent.Create(Nil);
  FRoot.Name:='Root';
end;

procedure TTestTComponentBase.TearDown;
begin
  FreeAndNil(FRoot);
end;

{ TTestTComponent }

procedure TTestTComponent.TestCreate;
begin
  FreeAndNil(Froot);
  FRoot:=TMyComponent.Create(Nil);
  TestContext.AssertTrue(('')=(FRoot.Name), 'Empty name');
  TestContext.AssertTrue((0)=(FRoot.ComponentCount), 'No owned components');
  If (FRoot.ComponentState<>[]) then
    TestContext.Fail('Componentstate is not empty');
  If (FRoot.Owner<>Nil) then
    TestContext.Fail('Owner is not nil');
end;

procedure TTestTComponent.TestName;
begin
  TestContext.AssertTrue(('Root')=(FRoot.Name), 'Name is Root');
end;

procedure TTestTComponent.TestOwner;

Var
  C : TComponent;

begin
  C:=TComponent.Create(FRoot);
  If (C.Owner<>FRoot) then
    TestContext.Fail('Owner not saved after create');
end;

procedure TTestTComponent.TestChildren;
begin
  CreateComponents(3,'Child');
  TestContext.AssertTrue((3)=(FRoot.ComponentCount), 'Componentcount is 3');
  TestContext.AssertTrue(('Child1')=(FRoot.Components[0].Name), 'Child component 0 is child1');
  TestContext.AssertTrue(('Child2')=(FRoot.Components[1].Name), 'Child component 1 is child2');
  TestContext.AssertTrue(('Child3')=(FRoot.Components[2].Name), 'Child component 2 is child3');
end;

procedure TTestTComponent.TestDestroyChild;

Var
  S : TEventSink;

begin
  CreateComponents(1);
  S:=TEventSink.Create;
  try
    TMyComponent(FRoot.Components[0]).OnDestroy:=@S.Event;
    FreeAndNil(FRoot);
    TestContext.AssertTrue((1)=(S.FEventcount), 'One child destroyed');
    If (S.FLastSender=Nil) then
      TestContext.Fail('No sender passed');
  finally
    S.Free;
  end;
end;

procedure TTestTComponent.TestDestroyChildren;

Var
  S : TEventSink;
  I : Integer;

begin
  CreateComponents(3);
  S:=TEventSink.Create;
  try
    For I:=0 to 2 do
      TMyComponent(FRoot.Components[I]).OnDestroy:=@S.Event;
    FreeAndNil(FRoot);
    TestContext.AssertTrue((3)=(S.FEventcount), 'One child destroyed');
    If (S.FLastSender=Nil) then
      TestContext.Fail('No sender passed');
  finally
    S.Free;
  end;
end;

procedure TTestTComponent.TestDoubleName;

begin
  FRoot.Components[1].Name:='Child1';
end;

procedure TTestTComponent.TestUniqueName;
begin
  CreateComponents(3,'Child');
  TestContext.AssertRaises(EComponentError, @TestDoubleName, 'Unique name');
end;

procedure TTestTComponent.TestRemoveComponent;

Var
  C : TComponent;

begin
  CreateComponents(1);
  C:=FRoot.Components[0];
  FRoot.RemoveComponent(C);
  Try
    TestContext.AssertTrue((0)=(FRoot.ComponentCount), 'No components left');
    TestContext.AssertTrue((Nil)=(C.Owner), 'Component has no owner');
  Finally
    C.Free;
  end;
end;


procedure TTestTComponent.TestTextName;

begin
  FRoot.Name:='Child 1';
end;

procedure TTestTComponent.TestNumberName;
begin
  FRoot.Name:='1';
end;

procedure TTestTComponent.TestNumberTextName;
begin
  FRoot.Name:='1Too';
end;

procedure TTestTComponent.TestIdentiFierName;
begin
  TestContext.AssertRaises(EComponentError, @TestTextName, 'Identifier name');
end;

procedure TTestTComponent.TestIdentiFierNameTwo;

begin
  TestContext.AssertRaises(EComponentError, @TestNumberTextName, 'Identifier name');
end;

procedure TTestTComponent.TestIdentiFierNameThree;
begin
  TestContext.AssertRaises(EComponentError, @TestNumberName, 'Identifier name');
end;

procedure TTestTComponent.TestIdentiFierNameFour;

Var
  Failed : Boolean;

begin
  Failed:=False;
  Try
    FRoot.Name:='Some1';
  except
    Failed:=True;
  end;
  If Failed then
    TestContext.Fail('No identifier ending on 1 accepted ?');
end;

{ TMyComponent }

destructor TMyComponent.Destroy;
begin
  If Assigned(FOnDestroy) then
    FOnDestroy(Self);
  inherited Destroy;
end;

procedure TMyComponent.Notification(AComponent: TComponent;
  Operation: TOperation);
begin
  If Assigned(FOnNotify) then
    FOnNotify(Self, AComponent, Operation);
  inherited Notification(AComponent, Operation);
end;

{ TEventSink }

procedure TEventSink.Event(Sender: TObject);
begin
  Inc(FEventCount);
  FLastSender:=Sender;
end;

procedure TEventSink.ResetEvent;
begin
  FLastSender:=Nil;
  FEventCount:=0;
end;

{ TNotificationSink }

function TNotificationSink.GetNot(Index : Integer): TNotification;
begin
  If Assigned(FEvents) then
    Result:=TNotification(FEvents.Items[Index])
  else
    Result:=Nil;
end;

destructor TNotificationSink.Destroy;
begin
  FreeAndNil(FEvents);
  inherited Destroy;
end;

procedure TNotificationSink.Notification(Sender, AComponent: TComponent;
  Operation: TOperation);

Var
  N : TNotification;

begin
  If (Fevents=Nil) then
    FEvents:=TCollection.Create(TNotification);
  N:=FEvents.Add as TNotification;
  N.AComponent:=AComponent;
  N.ASender:=Sender;
  N.AOperation:=Operation;
end;

procedure TNotificationSink.Reset;
begin
  FreeAndNil(FEvents);
end;

function TNotificationSink.EventCount: Integer;
begin
  If (Fevents<>Nil) then
    Result:=FEvents.Count
  else
    Result:=0;
end;

{ TTestTComponentNotifies }

procedure TTestTComponentNotifies.SetUp;
begin
  inherited SetUp;
  N:=TNotificationSink.Create;
  FRoot.OnNotification:=@N.Notification;
end;

procedure TTestTComponentNotifies.TearDown;
begin
  FreeAndNil(N);
  inherited TearDown;
end;

procedure TTestTComponentNotifies.TestInsertNotification;

Var
  E : TNotification;

begin
  CreateComponents(1);
  TestContext.AssertTrue((1)=(N.EventCount), 'One notification received');
  E:=N.Notifications[0];
  TestContext.AssertTrue((Ord(opInsert))=(Ord(E.AOperation)), 'Insert notification received');
end;

procedure TTestTComponentNotifies.TestRemoveNotification;

Var
  C : TComponent;
  E : TNotification;

begin
  CreateComponents(1);
  N.Reset;
  C:=FRoot.Components[0];
  FRoot.RemoveComponent(C);
  Try
    TestContext.AssertTrue((1)=(N.EventCount), 'One notification received');
    E:=N.Notifications[0];
  Finally
    C.Free;
  end;
end;



constructor TTestTComponentBase.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestTComponentTestCreate(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestCreate');
  try
    lFixture.SetUp;
    try lFixture.TestCreate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentTestName(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestName');
  try
    lFixture.SetUp;
    try lFixture.TestName; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentTestIdentiFierName(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestIdentiFierName');
  try
    lFixture.SetUp;
    try lFixture.TestIdentiFierName; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentTestIdentiFierNameTwo(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestIdentiFierNameTwo');
  try
    lFixture.SetUp;
    try lFixture.TestIdentiFierNameTwo; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentTestIdentiFierNameThree(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestIdentiFierNameThree');
  try
    lFixture.SetUp;
    try lFixture.TestIdentiFierNameThree; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentTestIdentiFierNameFour(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestIdentiFierNameFour');
  try
    lFixture.SetUp;
    try lFixture.TestIdentiFierNameFour; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentTestOwner(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestOwner');
  try
    lFixture.SetUp;
    try lFixture.TestOwner; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentTestChildren(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestChildren');
  try
    lFixture.SetUp;
    try lFixture.TestChildren; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentTestDestroyChild(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestDestroyChild');
  try
    lFixture.SetUp;
    try lFixture.TestDestroyChild; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentTestDestroyChildren(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestDestroyChildren');
  try
    lFixture.SetUp;
    try lFixture.TestDestroyChildren; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentTestUniqueName(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestUniqueName');
  try
    lFixture.SetUp;
    try lFixture.TestUniqueName; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentTestRemoveComponent(AContext: TNXTestContext);
var lFixture: TTestTComponent;
begin
  lFixture:=TTestTComponent.Create(AContext, 'TestRemoveComponent');
  try
    lFixture.SetUp;
    try lFixture.TestRemoveComponent; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentNotifiesTestInsertNotification(AContext: TNXTestContext);
var lFixture: TTestTComponentNotifies;
begin
  lFixture:=TTestTComponentNotifies.Create(AContext, 'TestInsertNotification');
  try
    lFixture.SetUp;
    try lFixture.TestInsertNotification; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTComponentNotifiesTestRemoveNotification(AContext: TNXTestContext);
var lFixture: TTestTComponentNotifies;
begin
  lFixture:=TTestTComponentNotifies.Create(AContext, 'TestRemoveNotification');
  try
    lFixture.SetUp;
    try lFixture.TestRemoveNotification; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertccomponentTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tccomponent.TTestTComponent');
  lSuite.AddTest('TestCreate', @RunTTestTComponentTestCreate);
  lSuite.AddTest('TestName', @RunTTestTComponentTestName);
  lSuite.AddTest('TestIdentiFierName', @RunTTestTComponentTestIdentiFierName);
  lSuite.AddTest('TestIdentiFierNameTwo', @RunTTestTComponentTestIdentiFierNameTwo);
  lSuite.AddTest('TestIdentiFierNameThree', @RunTTestTComponentTestIdentiFierNameThree);
  lSuite.AddTest('TestIdentiFierNameFour', @RunTTestTComponentTestIdentiFierNameFour);
  lSuite.AddTest('TestOwner', @RunTTestTComponentTestOwner);
  lSuite.AddTest('TestChildren', @RunTTestTComponentTestChildren);
  lSuite.AddTest('TestDestroyChild', @RunTTestTComponentTestDestroyChild);
  lSuite.AddTest('TestDestroyChildren', @RunTTestTComponentTestDestroyChildren);
  lSuite.AddTest('TestUniqueName', @RunTTestTComponentTestUniqueName);
  lSuite.AddTest('TestRemoveComponent', @RunTTestTComponentTestRemoveComponent);
  lSuite:=ARegistry.AddSuite('tccomponent.TTestTComponentNotifies');
  lSuite.AddTest('TestInsertNotification', @RunTTestTComponentNotifiesTestInsertNotification);
  lSuite.AddTest('TestRemoveNotification', @RunTTestTComponentNotifiesTestRemoveNotification);
end;

end.
