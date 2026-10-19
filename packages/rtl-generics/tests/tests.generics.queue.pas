unit tests.generics.queue;

{$mode objfpc}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, Generics.Defaults, Generics.Collections;


Type
  TMySimpleQueue = Class(Specialize TQueue<String>);
{$IFDEF FPC}
  EList = EListError;
{$ENDIF}

  { TTestSimpleQueue }

  TTestSimpleQueue = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Private
    FQueue : TMySimpleQueue;
    FnotifyMessage : String;
    FCurrentValueNotify : Integer;
    FExpectValues : Array of String;
    FExpectValueAction: Array of TCollectionNotification;
    procedure DoAdd(aCount: Integer; aOffset: Integer=0);
    procedure DoAdd2;
    Procedure DoneExpectValues;
    procedure DoGetValue(Match: String; ExceptionClass: TClass=nil);
    procedure DoValueNotify(ASender: TObject; const AItem: String; AAction: TCollectionNotification);
  Public
    Procedure SetExpectValues(aMessage : string; AKeys : Array of String; AActions : Array of TCollectionNotification; DoReverse : Boolean = False);
    Procedure SetUp; virtual;
    Procedure TearDown; virtual;
    Property Queue : TMySimpleQueue Read FQueue;
  public
    Procedure TestEmpty;
    Procedure TestAdd;
    Procedure TestClear;
    Procedure TestGetValue;
    Procedure TestPeek;
    Procedure TestDequeue;
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

  TSingleObjectQueue = Class(Specialize TObjectQueue<TMyObject>);

  { TTestSingleObjectQueue }

  TTestSingleObjectQueue = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    FOQueue: TSingleObjectQueue;
    FList : TFPList;
    procedure DoAdd(aID: Integer);
    procedure DoDestroy(Sender: TObject);
  Public
    Procedure SetUp; virtual;
    Procedure TearDown; virtual;
    Property Queue : TSingleObjectQueue Read FOQueue;
  public
    Procedure TestEmpty;
    Procedure TestFreeOnDequeue;
    Procedure TestNoFreeOnDeQueue;
  end;

procedure RegistertestsgenericsqueueTests(ARegistry: TNXTestRegistry);

implementation

{ TTestSingleObjectQueue }

procedure TTestSingleObjectQueue.SetUp;
begin
  FOQueue:=TSingleObjectQueue.Create(True);
  FList:=TFPList.Create;

end;

procedure TTestSingleObjectQueue.TearDown;
begin
  FreeAndNil(FOQueue);
  FreeAndNil(FList);

end;

procedure TTestSingleObjectQueue.TestEmpty;
begin
  TestContext.AssertTrue((Queue)<>nil, 'Have object');
  TestContext.AssertTrue((0)=(Queue.Count), 'Have empty object');
end;

procedure TTestSingleObjectQueue.DoAdd(aID : Integer);

Var
  O :  TMyObject;

begin
  O:=TMyObject.Create(aID,@DoDestroy);
  FOQueue.EnQueue(O);
  FList.Add(O);
end;

procedure TTestSingleObjectQueue.DoDestroy(Sender: TObject);

Var
  I : Integer;

begin
  I:=FList.IndexOf(Sender);
  TestContext.AssertTrue(I<>-1, 'Have object in Queue');
  FList.Delete(I);
end;

procedure TTestSingleObjectQueue.TestFreeOnDeQueue;

begin
  DoAdd(1);
  TestContext.AssertTrue((1)=(FList.Count), 'Have obj');
  Queue.Dequeue;
  TestContext.AssertTrue((0)=(FList.Count), 'Have no obj');
end;

procedure TTestSingleObjectQueue.TestNoFreeOnDeQueue;
begin
  Queue.OwnsObjects:=False;
  DoAdd(1);
  TestContext.AssertTrue((1)=(FList.Count), 'Have obj');
  Queue.DeQueue;
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

{ TTestSimpleQueue }

procedure TTestSimpleQueue.SetUp;
begin

  FQueue:=TMySimpleQueue.Create;
  FCurrentValueNotify:=0;
  FExpectValues:=[];
  FExpectValueAction:=[];
end;

procedure TTestSimpleQueue.TearDown;
begin
  // So we don't get clear messages
  FQueue.OnNotify:=Nil;
  FreeAndNil(FQueue);

end;

procedure TTestSimpleQueue.TestEmpty;
begin
  TestContext.AssertTrue((Queue)<>nil, 'Have dictionary');
  TestContext.AssertTrue((0)=(Queue.Count), 'empty dictionary');
end;

procedure TTestSimpleQueue.DoAdd(aCount : Integer; aOffset : Integer=0);

Var
  I : Integer;

begin
  if aOffset=-1 then
    aOffset:=Queue.Count;
  For I:=aOffset+1 to aOffset+aCount do
    Queue.EnQueue(IntToStr(i));
end;

procedure TTestSimpleQueue.TestAdd;

begin
  DoAdd(1);
  TestContext.AssertTrue((1)=(Queue.Count), 'Count OK');
  DoAdd(1,1);
  TestContext.AssertTrue((2)=(Queue.Count), 'Count OK');
end;

procedure TTestSimpleQueue.TestClear;
begin
  DoAdd(3);
  TestContext.AssertTrue((3)=(Queue.Count), 'Count OK');
  Queue.Clear;
  TestContext.AssertTrue((0)=(Queue.Count), 'Count after clear OK');
end;

procedure TTestSimpleQueue.DoGetValue(Match: String; ExceptionClass: TClass);

Var
  EC : TClass;
  A,EM : String;

begin
  EC:=Nil;
  try
    A:=Queue.DeQueue;
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

procedure TTestSimpleQueue.DoValueNotify(ASender: TObject; const AItem: String; AAction: TCollectionNotification);
begin
//  Writeln(FnotifyMessage+' value Notification',FCurrentValueNotify);
  TestContext.AssertTrue((FQueue)=(aSender), FnotifyMessage+' value Correct sender');
  if (FCurrentValueNotify>=Length(FExpectValues)) then
    TestContext.Fail(FnotifyMessage+' Too many value notificiations');
  TestContext.AssertTrue((FExpectValues[FCurrentValueNotify])=(aItem), FnotifyMessage+' Notification value no '+IntToStr(FCurrentValueNotify));
  Inc(FCurrentValueNotify);
end;


procedure TTestSimpleQueue.SetExpectValues(aMessage: string; AKeys: array of String;
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

procedure TTestSimpleQueue.TestGetValue;

Var
  I : integer;

begin
  DoAdd(3);
  For I:=1 to 3 do
    DoGetValue(IntToStr(I));
  DoGetValue('4',EArgumentOutOfRangeException);
end;

procedure TTestSimpleQueue.TestPeek;
Var
  I : integer;

begin
  DoAdd(3);
  For I:=1 to 3 do
    begin
    TestContext.AssertTrue((IntToStr(I))=(FQueue.Peek), 'Peek ');
    DoGetValue(IntToStr(I));
    end;
end;


procedure TTestSimpleQueue.DoAdd2;

begin
  Queue.Enqueue('A new 2');
end;

procedure TTestSimpleQueue.DoneExpectValues;
begin
  TestContext.AssertTrue((Length(FExpectValues))=(FCurrentValueNotify), FnotifyMessage+' Expected number of values seen');
end;

procedure TTestSimpleQueue.TestDequeue;

begin
  DoAdd(3);
  TestContext.AssertTrue(('1')=(Queue.Dequeue), '');
  TestContext.AssertTrue((2)=(Queue.Count), 'Count');
end;

procedure TTestSimpleQueue.TestToArray;

Var
  A : specialize TArray<String>;

  I : Integer;
  SI : String;

begin
  DoAdd(3);
  A:=Queue.ToArray;
  TestContext.AssertTrue((3)=(Length(A)), 'Length Ok');
  For I:=1 to 3 do
    begin
    SI:=IntToStr(I);
    TestContext.AssertTrue((SI)=(A[i-1]), 'Value '+SI);
    end;
end;


procedure TTestSimpleQueue.TestEnumerator;

Var
  A : String;
  I : Integer;
  SI : String;

begin
  DoAdd(3);
  I:=1;
  For A in Queue do
    begin
    SI:=IntToStr(I);
    TestContext.AssertTrue((SI)=(A), 'Value '+SI);
    Inc(I);
    end;
end;

procedure TTestSimpleQueue.TestValueNotification;
begin
  Queue.OnNotify:=@DoValueNotify;
  SetExpectValues('Add',['1','2','3'],[cnAdded,cnAdded,cnAdded]);
  DoAdd(3);
  DoneExpectValues;
end;

procedure TTestSimpleQueue.TestValueNotificationDelete;
begin
  DoAdd(3);
  Queue.OnNotify:=@DoValueNotify;
  SetExpectValues('Clear',['1','2','3'],[cnRemoved,cnRemoved,cnRemoved]);
  Queue.Clear;
  DoneExpectValues;
end;


constructor TTestSimpleQueue.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestSingleObjectQueue.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestSimpleQueueTestEmpty(AContext: TNXTestContext);
var lFixture: TTestSimpleQueue;
begin
  lFixture:=TTestSimpleQueue.Create(AContext, 'TestEmpty');
  try
    lFixture.SetUp;
    try lFixture.TestEmpty; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleQueueTestAdd(AContext: TNXTestContext);
var lFixture: TTestSimpleQueue;
begin
  lFixture:=TTestSimpleQueue.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleQueueTestClear(AContext: TNXTestContext);
var lFixture: TTestSimpleQueue;
begin
  lFixture:=TTestSimpleQueue.Create(AContext, 'TestClear');
  try
    lFixture.SetUp;
    try lFixture.TestClear; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleQueueTestGetValue(AContext: TNXTestContext);
var lFixture: TTestSimpleQueue;
begin
  lFixture:=TTestSimpleQueue.Create(AContext, 'TestGetValue');
  try
    lFixture.SetUp;
    try lFixture.TestGetValue; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleQueueTestPeek(AContext: TNXTestContext);
var lFixture: TTestSimpleQueue;
begin
  lFixture:=TTestSimpleQueue.Create(AContext, 'TestPeek');
  try
    lFixture.SetUp;
    try lFixture.TestPeek; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleQueueTestDequeue(AContext: TNXTestContext);
var lFixture: TTestSimpleQueue;
begin
  lFixture:=TTestSimpleQueue.Create(AContext, 'TestDequeue');
  try
    lFixture.SetUp;
    try lFixture.TestDequeue; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleQueueTestToArray(AContext: TNXTestContext);
var lFixture: TTestSimpleQueue;
begin
  lFixture:=TTestSimpleQueue.Create(AContext, 'TestToArray');
  try
    lFixture.SetUp;
    try lFixture.TestToArray; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleQueueTestEnumerator(AContext: TNXTestContext);
var lFixture: TTestSimpleQueue;
begin
  lFixture:=TTestSimpleQueue.Create(AContext, 'TestEnumerator');
  try
    lFixture.SetUp;
    try lFixture.TestEnumerator; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleQueueTestValueNotification(AContext: TNXTestContext);
var lFixture: TTestSimpleQueue;
begin
  lFixture:=TTestSimpleQueue.Create(AContext, 'TestValueNotification');
  try
    lFixture.SetUp;
    try lFixture.TestValueNotification; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleQueueTestValueNotificationDelete(AContext: TNXTestContext);
var lFixture: TTestSimpleQueue;
begin
  lFixture:=TTestSimpleQueue.Create(AContext, 'TestValueNotificationDelete');
  try
    lFixture.SetUp;
    try lFixture.TestValueNotificationDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSingleObjectQueueTestEmpty(AContext: TNXTestContext);
var lFixture: TTestSingleObjectQueue;
begin
  lFixture:=TTestSingleObjectQueue.Create(AContext, 'TestEmpty');
  try
    lFixture.SetUp;
    try lFixture.TestEmpty; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSingleObjectQueueTestFreeOnDequeue(AContext: TNXTestContext);
var lFixture: TTestSingleObjectQueue;
begin
  lFixture:=TTestSingleObjectQueue.Create(AContext, 'TestFreeOnDequeue');
  try
    lFixture.SetUp;
    try lFixture.TestFreeOnDequeue; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSingleObjectQueueTestNoFreeOnDeQueue(AContext: TNXTestContext);
var lFixture: TTestSingleObjectQueue;
begin
  lFixture:=TTestSingleObjectQueue.Create(AContext, 'TestNoFreeOnDeQueue');
  try
    lFixture.SetUp;
    try lFixture.TestNoFreeOnDeQueue; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertestsgenericsqueueTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tests.generics.queue.TTestSimpleQueue');
  lSuite.AddTest('TestEmpty', @RunTTestSimpleQueueTestEmpty, 'generics');
  lSuite.AddTest('TestAdd', @RunTTestSimpleQueueTestAdd, 'generics');
  lSuite.AddTest('TestClear', @RunTTestSimpleQueueTestClear, 'generics');
  lSuite.AddTest('TestGetValue', @RunTTestSimpleQueueTestGetValue, 'generics');
  lSuite.AddTest('TestPeek', @RunTTestSimpleQueueTestPeek, 'generics');
  lSuite.AddTest('TestDequeue', @RunTTestSimpleQueueTestDequeue, 'generics');
  lSuite.AddTest('TestToArray', @RunTTestSimpleQueueTestToArray, 'generics');
  lSuite.AddTest('TestEnumerator', @RunTTestSimpleQueueTestEnumerator, 'generics');
  lSuite.AddTest('TestValueNotification', @RunTTestSimpleQueueTestValueNotification, 'generics');
  lSuite.AddTest('TestValueNotificationDelete', @RunTTestSimpleQueueTestValueNotificationDelete, 'generics');
  lSuite:=ARegistry.AddSuite('tests.generics.queue.TTestSingleObjectQueue');
  lSuite.AddTest('TestEmpty', @RunTTestSingleObjectQueueTestEmpty, 'generics');
  lSuite.AddTest('TestFreeOnDequeue', @RunTTestSingleObjectQueueTestFreeOnDequeue, 'generics');
  lSuite.AddTest('TestNoFreeOnDeQueue', @RunTTestSingleObjectQueueTestNoFreeOnDeQueue, 'generics');
end;

end.
