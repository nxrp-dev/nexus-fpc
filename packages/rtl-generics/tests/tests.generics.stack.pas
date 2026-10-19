unit tests.generics.stack;

{$mode objfpc}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, Generics.Defaults, Generics.Collections;


Type
  TMySimpleStack = Class(Specialize TStack<String>);
{$IFDEF FPC}
  EList = EListError;
{$ENDIF}

  { TTestSimpleStack }

  TTestSimpleStack = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Private
    FStack : TMySimpleStack;
    FnotifyMessage : String;
    FCurrentValueNotify : Integer;
    FExpectValues : Array of String;
    FExpectValueAction: Array of TCollectionNotification;
    procedure DoAdd(aCount: Integer);
    procedure DoAdd2;
    Procedure DoneExpectValues;
    procedure DoGetValue(Match: String; ExceptionClass: TClass=nil);
    procedure DoValueNotify(ASender: TObject; const AItem: String; AAction: TCollectionNotification);
  Public
    Procedure SetExpectValues(aMessage : string; AKeys : Array of String; AActions : Array of TCollectionNotification; DoReverse : Boolean = False);
    Procedure SetUp; virtual;
    Procedure TearDown; virtual;
    Property Stack : TMySimpleStack Read FStack;
  public
    Procedure TestEmpty;
    Procedure TestAdd;
    Procedure TestClear;
    Procedure TestGetValue;
    Procedure TestPeek;
    Procedure TestPop;
    Procedure TestToArray;
    Procedure TestEnumerator;
    procedure TestValueNotification;
    procedure TestValueNotificationDelete;
  end;

  { TMyObject }

  TMyObject = Class(TObject)
  Private
    fOnDestroy : TNotifyEvent;
    FID : Integer;
  public
    Constructor Create(aID : Integer; aOnDestroy : TNotifyEvent);
    destructor destroy; override;
    Property ID : Integer Read FID;
  end;

  TSingleObjectStack = Class(Specialize TObjectStack<TMyObject>);

  { TTestSingleObjectStack }

  TTestSingleObjectStack = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    FOStack: TSingleObjectStack;
    FList : TFPList;
    procedure DoAdd(aID: Integer);
    procedure DoDestroy(Sender: TObject);
  Public
    Procedure SetUp; virtual;
    Procedure TearDown; virtual;
    Property Stack : TSingleObjectStack Read FOStack;
  public
    Procedure TestEmpty;
    Procedure TestFreeOnPop;
    Procedure TestNoFreeOnPop;
  end;

procedure RegistertestsgenericsstackTests(ARegistry: TNXTestRegistry);

implementation

{ TTestSingleObjectStack }

procedure TTestSingleObjectStack.SetUp;
begin
  FOStack:=TSingleObjectStack.Create(True);
  FList:=TFPList.Create;

end;

procedure TTestSingleObjectStack.TearDown;

Var
  I : integer;
  A : TObject;

begin
  FreeAndNil(FOStack);
  for I:=0 to FList.Count-1 do
    begin
    A:=TObject(FList[i]);
    A.Free;
    end;
  FreeAndNil(FList);

end;

procedure TTestSingleObjectStack.TestEmpty;
begin
  TestContext.AssertTrue((Stack)<>nil, 'Have object');
  TestContext.AssertTrue((0)=(Stack.Count), 'Have empty object');
end;

procedure TTestSingleObjectStack.DoAdd(aID : Integer);

Var
  O :  TMyObject;

begin
  O:=TMyObject.Create(aID,@DoDestroy);
  FOStack.Push(O);
  FList.Add(O);
end;

procedure TTestSingleObjectStack.DoDestroy(Sender: TObject);

Var
  I : Integer;

begin
  I:=FList.IndexOf(Sender);
  TestContext.AssertTrue(I<>-1, 'Have object in Stack');
  FList.Delete(I);
end;

procedure TTestSingleObjectStack.TestFreeOnPop;

begin
  DoAdd(1);
  TestContext.AssertTrue((1)=(FList.Count), 'Have obj');
  Stack.Pop;
  TestContext.AssertTrue((0)=(FList.Count), 'Have no obj');
end;

procedure TTestSingleObjectStack.TestNoFreeOnPop;
begin
  Stack.OwnsObjects:=False;
  DoAdd(1);
  TestContext.AssertTrue((1)=(FList.Count), 'Have obj');
  Stack.Pop;
  TestContext.AssertTrue((1)=(FList.Count), 'Have  obj');
end;


{ TMyObject }

constructor TMyObject.Create(aID: Integer; aOnDestroy: TNotifyEvent);
begin
  FOnDestroy:=aOnDestroy;
  FID:=AID;
end;

destructor TMyObject.destroy;
begin
  if Assigned(FOnDestroy) then
    FOnDestroy(Self);
  inherited destroy;
end;

{ TTestSimpleStack }

procedure TTestSimpleStack.SetUp;
begin

  FStack:=TMySimpleStack.Create;
  FCurrentValueNotify:=0;
  FExpectValues:=[];
  FExpectValueAction:=[];
end;

procedure TTestSimpleStack.TearDown;
begin
  // So we don't get clear messages
  FStack.OnNotify:=Nil;
  FreeAndNil(FStack);

end;

procedure TTestSimpleStack.TestEmpty;
begin
  TestContext.AssertTrue((Stack)<>nil, 'Have dictionary');
  TestContext.AssertTrue((0)=(Stack.Count), 'empty dictionary');
end;

procedure TTestSimpleStack.DoAdd(aCount : Integer);

Var
  I : Integer;

begin
  For I:=1 to aCount do
    Stack.Push(IntToStr(i));
end;

procedure TTestSimpleStack.TestAdd;

begin
  DoAdd(1);
  TestContext.AssertTrue((1)=(Stack.Count), 'Count OK');
  DoAdd(1);
  TestContext.AssertTrue((2)=(Stack.Count), 'Count OK');
end;

procedure TTestSimpleStack.TestClear;
begin
  DoAdd(3);
  TestContext.AssertTrue((3)=(Stack.Count), 'Count OK');
  Stack.Clear;
  TestContext.AssertTrue((0)=(Stack.Count), 'Count after clear OK');
end;

procedure TTestSimpleStack.DoGetValue(Match: String; ExceptionClass: TClass);

Var
  EC : TClass;
  A,EM : String;

begin
  EC:=Nil;
  try
    A:=Stack.Pop;
  except
    On E : Exception do
      begin
      EC:=E.ClassType;
      EM:=E.Message;
      end
  end;
  if ExceptionClass=Nil then
    begin
    if EC<>Nil then
      TestContext.Fail('Got exception '+EC.ClassName+' with message: '+EM);
    TestContext.AssertTrue((Match)=(A), 'Value is correct')
    end
  else
    begin
    if EC=Nil then
      TestContext.Fail('Expected exception '+ExceptionClass.ClassName+' but got none');
    if EC<>ExceptionClass then
      TestContext.Fail('Expected exception class '+ExceptionClass.ClassName+' but got '+EC.ClassName+' with message '+EM);
    end;
end;

procedure TTestSimpleStack.DoValueNotify(ASender: TObject; const AItem: String; AAction: TCollectionNotification);
begin
//  Writeln(FnotifyMessage+' value Notification',FCurrentValueNotify);
  TestContext.AssertTrue((FStack)=(aSender), FnotifyMessage+' value Correct sender');
  if (FCurrentValueNotify>=Length(FExpectValues)) then
    TestContext.Fail(FnotifyMessage+' Too many value notificiations');
  TestContext.AssertTrue((FExpectValues[FCurrentValueNotify])=(aItem), FnotifyMessage+' Notification value no '+IntToStr(FCurrentValueNotify));
  Inc(FCurrentValueNotify);
end;


procedure TTestSimpleStack.SetExpectValues(aMessage: string; AKeys: array of String;
  AActions: array of TCollectionNotification; DoReverse: Boolean);
Var
  I,L : integer;

begin
  FnotifyMessage:=aMessage;
  FCurrentValueNotify:=0;
  L:=Length(aKeys);
  TestContext.AssertTrue((l)=(Length(aActions)), 'SetExpectValues: Lengths arrays equal');
  SetLength(FExpectValues,L);
  SetLength(FExpectValueAction,L);
  Dec(L);
  if DoReverse then
    For I:=0 to L do
      begin
      FExpectValues[L-i]:=AKeys[i];
      FExpectValueAction[L-i]:=AActions[I];
      end
  else
    For I:=0 to L do
      begin
      FExpectValues[i]:=AKeys[i];
      FExpectValueAction[i]:=AActions[I];
      end;
end;

procedure TTestSimpleStack.TestGetValue;

Var
  I : integer;

begin
  DoAdd(3);
  For I:=3 downto 1 do
    DoGetValue(IntToStr(I));
  DoGetValue('4',EArgumentOutOfRangeException);
end;

procedure TTestSimpleStack.TestPeek;
Var
  I : integer;

begin
  DoAdd(3);
  For I:=3 downto 1 do
    begin
    TestContext.AssertTrue((IntToStr(I))=(FStack.Peek), 'Peek ');
    DoGetValue(IntToStr(I));
    end;
end;


procedure TTestSimpleStack.DoAdd2;

begin
  Stack.Push('A new 2');
end;

procedure TTestSimpleStack.DoneExpectValues;
begin
  TestContext.AssertTrue((Length(FExpectValues))=(FCurrentValueNotify), FnotifyMessage+' Expected number of values seen');
end;

procedure TTestSimpleStack.TestPop;

Var
  I : Integer;
  SI : String;

begin
  DoAdd(3);
  For I:=3 downto 1 do
    begin
    SI:=IntToStr(I);
    TestContext.AssertTrue((SI)=(FStack.Pop), 'Value '+SI);
    end;
  TestContext.AssertTrue((0)=(Stack.Count), 'Count');
end;

procedure TTestSimpleStack.TestToArray;

Var
  A : specialize TArray<String>;
  I : Integer;
  SI : String;

begin
  DoAdd(3);
  A:=Stack.ToArray;
  TestContext.AssertTrue((3)=(Length(A)), 'Length Ok');
  For I:=1 to 3 do
    begin
    SI:=IntToStr(I);
    TestContext.AssertTrue((SI)=(A[i-1]), 'Value '+SI);
    end;
end;


procedure TTestSimpleStack.TestEnumerator;

Var
  A : String;
  I : Integer;
  SI : String;

begin
  DoAdd(3);
  I:=1;
  For A in Stack do
    begin
    SI:=IntToStr(i);
    TestContext.AssertTrue((SI)=(A), 'Value '+SI);
    Inc(I);
    end;
end;

procedure TTestSimpleStack.TestValueNotification;
begin
  Stack.OnNotify:=@DoValueNotify;
  SetExpectValues('Add',['1','2','3'],[cnAdded,cnAdded,cnAdded]);
  DoAdd(3);
  DoneExpectValues;
end;

procedure TTestSimpleStack.TestValueNotificationDelete;
begin
  DoAdd(3);
  Stack.OnNotify:=@DoValueNotify;
  SetExpectValues('Clear',['3','2','1'],[cnRemoved,cnRemoved,cnRemoved],False);
  Stack.Clear;
  DoneExpectValues;
end;


constructor TTestSimpleStack.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestSingleObjectStack.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestSimpleStackTestEmpty(AContext: TNXTestContext);
var lFixture: TTestSimpleStack;
begin
  lFixture:=TTestSimpleStack.Create(AContext, 'TestEmpty');
  try
    lFixture.SetUp;
    try lFixture.TestEmpty; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleStackTestAdd(AContext: TNXTestContext);
var lFixture: TTestSimpleStack;
begin
  lFixture:=TTestSimpleStack.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleStackTestClear(AContext: TNXTestContext);
var lFixture: TTestSimpleStack;
begin
  lFixture:=TTestSimpleStack.Create(AContext, 'TestClear');
  try
    lFixture.SetUp;
    try lFixture.TestClear; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleStackTestGetValue(AContext: TNXTestContext);
var lFixture: TTestSimpleStack;
begin
  lFixture:=TTestSimpleStack.Create(AContext, 'TestGetValue');
  try
    lFixture.SetUp;
    try lFixture.TestGetValue; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleStackTestPeek(AContext: TNXTestContext);
var lFixture: TTestSimpleStack;
begin
  lFixture:=TTestSimpleStack.Create(AContext, 'TestPeek');
  try
    lFixture.SetUp;
    try lFixture.TestPeek; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleStackTestPop(AContext: TNXTestContext);
var lFixture: TTestSimpleStack;
begin
  lFixture:=TTestSimpleStack.Create(AContext, 'TestPop');
  try
    lFixture.SetUp;
    try lFixture.TestPop; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleStackTestToArray(AContext: TNXTestContext);
var lFixture: TTestSimpleStack;
begin
  lFixture:=TTestSimpleStack.Create(AContext, 'TestToArray');
  try
    lFixture.SetUp;
    try lFixture.TestToArray; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleStackTestEnumerator(AContext: TNXTestContext);
var lFixture: TTestSimpleStack;
begin
  lFixture:=TTestSimpleStack.Create(AContext, 'TestEnumerator');
  try
    lFixture.SetUp;
    try lFixture.TestEnumerator; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleStackTestValueNotification(AContext: TNXTestContext);
var lFixture: TTestSimpleStack;
begin
  lFixture:=TTestSimpleStack.Create(AContext, 'TestValueNotification');
  try
    lFixture.SetUp;
    try lFixture.TestValueNotification; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleStackTestValueNotificationDelete(AContext: TNXTestContext);
var lFixture: TTestSimpleStack;
begin
  lFixture:=TTestSimpleStack.Create(AContext, 'TestValueNotificationDelete');
  try
    lFixture.SetUp;
    try lFixture.TestValueNotificationDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSingleObjectStackTestEmpty(AContext: TNXTestContext);
var lFixture: TTestSingleObjectStack;
begin
  lFixture:=TTestSingleObjectStack.Create(AContext, 'TestEmpty');
  try
    lFixture.SetUp;
    try lFixture.TestEmpty; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSingleObjectStackTestFreeOnPop(AContext: TNXTestContext);
var lFixture: TTestSingleObjectStack;
begin
  lFixture:=TTestSingleObjectStack.Create(AContext, 'TestFreeOnPop');
  try
    lFixture.SetUp;
    try lFixture.TestFreeOnPop; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSingleObjectStackTestNoFreeOnPop(AContext: TNXTestContext);
var lFixture: TTestSingleObjectStack;
begin
  lFixture:=TTestSingleObjectStack.Create(AContext, 'TestNoFreeOnPop');
  try
    lFixture.SetUp;
    try lFixture.TestNoFreeOnPop; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertestsgenericsstackTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tests.generics.stack.TTestSimpleStack');
  lSuite.AddTest('TestEmpty', @RunTTestSimpleStackTestEmpty, 'generics');
  lSuite.AddTest('TestAdd', @RunTTestSimpleStackTestAdd, 'generics');
  lSuite.AddTest('TestClear', @RunTTestSimpleStackTestClear, 'generics');
  lSuite.AddTest('TestGetValue', @RunTTestSimpleStackTestGetValue, 'generics');
  lSuite.AddTest('TestPeek', @RunTTestSimpleStackTestPeek, 'generics');
  lSuite.AddTest('TestPop', @RunTTestSimpleStackTestPop, 'generics');
  lSuite.AddTest('TestToArray', @RunTTestSimpleStackTestToArray, 'generics');
  lSuite.AddTest('TestEnumerator', @RunTTestSimpleStackTestEnumerator, 'generics');
  lSuite.AddTest('TestValueNotification', @RunTTestSimpleStackTestValueNotification, 'generics');
  lSuite.AddTest('TestValueNotificationDelete', @RunTTestSimpleStackTestValueNotificationDelete, 'generics');
  lSuite:=ARegistry.AddSuite('tests.generics.stack.TTestSingleObjectStack');
  lSuite.AddTest('TestEmpty', @RunTTestSingleObjectStackTestEmpty, 'generics');
  lSuite.AddTest('TestFreeOnPop', @RunTTestSingleObjectStackTestFreeOnPop, 'generics');
  lSuite.AddTest('TestNoFreeOnPop', @RunTTestSingleObjectStackTestNoFreeOnPop, 'generics');
end;

end.
