unit tcbucketlist;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, contnrs;

type
  TMyBucketList = Class(TBucketList)
  public
    property BucketCount;
  end;

  PPtrInt= ^PtrInt;

  { TTestBucketList }

  TTestBucketList= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Private
    FList : TMyBucketList;
    FData : Array[1..10] of PtrInt;
    FPointers : Array[1..10] of PPtrInt;
    procedure DoDuplicate;
    Procedure AddPointers(ACount : Integer);
    function GetCount: Integer;
  protected
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure TestCreate;
    procedure TestAdd;
    procedure TestAdd2;
    procedure TestAddDuplicate;
    procedure TestDelete;
    procedure TestDelete2;
    procedure TestClear;
  end;

procedure RegistertcbucketlistTests(ARegistry: TNXTestRegistry);

implementation

Type

{ TCounter }

TCounter = Class(TObject)
private
  FCount: Integer;
Public
  procedure CountItems(AItem, AData: Pointer; out AContinue: Boolean);
  Property Count : Integer Read FCount;
end;


procedure TCounter.CountItems(AItem, AData: Pointer; out AContinue: Boolean);

begin
  Inc(FCount);
end;

procedure TTestBucketList.TestAdd;

Var
  P : POinter;

begin
  P:=FList.add(FPointers[1],Pointer(FData[1]));
  TestContext.AssertTrue((P)=(Pointer(FData[1])), 'Add returns data pointer');
  TestContext.AssertTrue((1)=(GetCount), 'Item count is 1');
end;

procedure TTestBucketList.TestAdd2;

begin
  AddPointers(2);
  With TCounter.Create do
    try
      FList.ForEach(@CountItems);
      TestContext.AssertTrue((2)=(Count), 'Item count is 1');
    Finally
      Free;
    end;
end;

procedure TTestBucketList.DoDuplicate;

begin
  AddPointers(1);
end;

Function TTestBucketList.GetCount : Integer;

begin
  With TCounter.Create do
    try
      FList.ForEach(@CountItems);
      Result:=Count;
    Finally
      Free;
    end;
end;


procedure TTestBucketList.AddPointers(ACount: Integer);

Var
  I : Integer;

begin
  For I:=1 to ACount do
    FList.Add(FPointers[I],Pointer(FData[i]));
end;

procedure TTestBucketList.TestAddDuplicate;

begin
  AddPointers(1);
  TestContext.AssertRaises(EListError, @DoDuplicate, 'Adding duplicate raises exception');
end;

procedure TTestBucketList.TestDelete;

begin
  AddPointers(3);
  FList.Remove(FPointers[3]);
  TestContext.AssertTrue((False)=(Flist.Exists(FPointers[3])), 'Deleted no longer exists');
  TestContext.AssertTrue((True)=(Flist.Exists(FPointers[2])), 'Remaining 2 exists');
  TestContext.AssertTrue((True)=(Flist.Exists(FPointers[1])), 'Remaining 1 exists');
end;

procedure TTestBucketList.TestDelete2;

begin
  AddPointers(3);
  FList.Remove(FPointers[3]);
  TestContext.AssertTrue((2)=(GetCount), 'Count after delete is 2');
  FList.Remove(FPointers[2]);
  TestContext.AssertTrue((1)=(GetCount), 'Count after delete is 2');
  FList.Remove(FPointers[1]);
  TestContext.AssertTrue((0)=(GetCount), 'Count after delete is 2');
end;

procedure TTestBucketList.TestClear;
begin
  AddPointers(10);
  FList.Clear;
  TestContext.AssertTrue((0)=(GetCount), 'Count after Clear is 0');
end;

procedure TTestBucketList.TestCreate;

begin
  TestContext.AssertTrue((64)=(Flist.BucketCount), 'Count should be 64');
  TestContext.AssertTrue((0)=(GetCount), 'Item count is 0');
end;

procedure TTestBucketList.SetUp;

Var
  I : integer;

begin
  FList:=TMyBucketList.create(bl64);
  For I:=1 to 10 do
    begin
    FData[i]:=I;
    FPointers[i]:=@FData[i];
    end;
end;

procedure TTestBucketList.TearDown;
begin
  FreeAndNil(FList);
end;


constructor TTestBucketList.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestBucketListTestCreate(AContext: TNXTestContext);
var lFixture: TTestBucketList;
begin
  lFixture:=TTestBucketList.Create(AContext, 'TestCreate');
  try
    lFixture.SetUp;
    try lFixture.TestCreate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestBucketListTestAdd(AContext: TNXTestContext);
var lFixture: TTestBucketList;
begin
  lFixture:=TTestBucketList.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestBucketListTestAdd2(AContext: TNXTestContext);
var lFixture: TTestBucketList;
begin
  lFixture:=TTestBucketList.Create(AContext, 'TestAdd2');
  try
    lFixture.SetUp;
    try lFixture.TestAdd2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestBucketListTestAddDuplicate(AContext: TNXTestContext);
var lFixture: TTestBucketList;
begin
  lFixture:=TTestBucketList.Create(AContext, 'TestAddDuplicate');
  try
    lFixture.SetUp;
    try lFixture.TestAddDuplicate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestBucketListTestDelete(AContext: TNXTestContext);
var lFixture: TTestBucketList;
begin
  lFixture:=TTestBucketList.Create(AContext, 'TestDelete');
  try
    lFixture.SetUp;
    try lFixture.TestDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestBucketListTestDelete2(AContext: TNXTestContext);
var lFixture: TTestBucketList;
begin
  lFixture:=TTestBucketList.Create(AContext, 'TestDelete2');
  try
    lFixture.SetUp;
    try lFixture.TestDelete2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestBucketListTestClear(AContext: TNXTestContext);
var lFixture: TTestBucketList;
begin
  lFixture:=TTestBucketList.Create(AContext, 'TestClear');
  try
    lFixture.SetUp;
    try lFixture.TestClear; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertcbucketlistTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tcbucketlist.TTestBucketList');
  lSuite.AddTest('TestCreate', @RunTTestBucketListTestCreate);
  lSuite.AddTest('TestAdd', @RunTTestBucketListTestAdd);
  lSuite.AddTest('TestAdd2', @RunTTestBucketListTestAdd2);
  lSuite.AddTest('TestAddDuplicate', @RunTTestBucketListTestAddDuplicate);
  lSuite.AddTest('TestDelete', @RunTTestBucketListTestDelete);
  lSuite.AddTest('TestDelete2', @RunTTestBucketListTestDelete2);
  lSuite.AddTest('TestClear', @RunTTestBucketListTestClear);
end;

end.
