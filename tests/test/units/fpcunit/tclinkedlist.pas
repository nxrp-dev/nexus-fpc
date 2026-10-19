unit tclinkedlist;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, fplists;

type

  { TTestLinkedList }

  TTestLinkedList= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  public
    procedure TestCreate;
    procedure TestAdd;
    procedure TestAdd2;
    procedure TestClear;
    procedure TestRemove;
    procedure TestRemove2;
    procedure TestRemove3;
    Procedure TestVisit;
  end;

procedure RegistertclinkedlistTests(ARegistry: TNXTestRegistry);

implementation


procedure TTestLinkedList.TestCreate;

Var
  LL : TLinkedList;

begin
  LL:=TLinkedList.Create(TLinkedListItem);
  Try
    TestContext.AssertTrue((TLinkedListItem)=(LL.ItemClass), 'Item class is TLinkedListItem.');
    TestContext.AssertTrue((0)=(LL.Count), 'Item count is 0');
    If (LL.Root<>Nil) then
      TestContext.Fail('Root is not nil')
  Finally
    LL.Free;
  end;
end;

procedure TTestLinkedList.TestAdd;

Var
  LL : TLinkedList;
  I  : TLinkedListItem;

begin
  LL:=TLinkedList.Create(TLinkedListItem);
  Try
    I:=LL.Add;
    TestContext.AssertTrue((TLinkedListItem)=(I.ClassType), 'Add result is TLinkedListItem.');
    TestContext.AssertTrue((1)=(LL.Count), 'Item count is 1');
    If (I<>LL.Root) then
      TestContext.Fail('Root item is not added item');
  Finally
    LL.Free;
  end;
end;

procedure TTestLinkedList.TestClear;

Var
  LL : TLinkedList;
  I  : Integer;

begin
  LL:=TLinkedList.Create(TLinkedListItem);
  Try
    For I:=1 to 3 do
      LL.Add;
    LL.Clear;
    TestContext.AssertTrue((0)=(LL.Count), 'Item count after clear is 0');
  Finally
    LL.Free;
  end;
end;

procedure TTestLinkedList.TestAdd2;

Var
  LL : TLinkedList;
  I1,I2  : TLinkedListItem;

begin
  LL:=TLinkedList.Create(TLinkedListItem);
  Try
    I1:=LL.Add;
    I2:=LL.Add;
    If (I2<>LL.Root) then
      TestContext.Fail('Root item is not last added item');
    If (I2.Next<>I1) then
      TestContext.Fail('Items ordered in the wrong way');
  Finally
    LL.Free;
  end;
end;

procedure TTestLinkedList.TestRemove;

Var
  LL : TLinkedList;
  I  : TLinkedListItem;

begin
  LL:=TLinkedList.Create(TLinkedListItem);
  Try
    I:=LL.Add;
    Try
      LL.RemoveItem(I);
      TestContext.AssertTrue((0)=(LL.Count), 'After remove Item count is 0');
      If (Nil<>LL.Root) then
        TestContext.Fail('Root item is not nil after last removed item');
    Finally
      I.Free;
    end;
  Finally
    LL.Free;
  end;
end;

procedure TTestLinkedList.TestRemove2;

Var
  LL : TLinkedList;
  I1,I2  : TLinkedListItem;

begin
  LL:=TLinkedList.Create(TLinkedListItem);
  Try
    I1:=LL.Add;
    Try
      I2:=LL.Add;
      LL.RemoveItem(I1);
      TestContext.AssertTrue((1)=(LL.Count), 'After remove first Item count is 1');
      If (I2<>LL.Root) then
        TestContext.Fail('Root item is not I2 after remove of I1');
    Finally
      I1.Free;
    end;
  Finally
    LL.Free;
  end;
end;

procedure TTestLinkedList.TestRemove3;

Var
  LL : TLinkedList;
  I1,I2, I3  : TLinkedListItem;

begin
  LL:=TLinkedList.Create(TLinkedListItem);
  Try
    I1:=LL.Add;
    I2:=LL.Add;
    I3:=LL.Add;
    LL.RemoveItem(I2);
    Try
      TestContext.AssertTrue((2)=(LL.Count), 'After remove I2 Item count is 2');
      If (I3.Next<>I1) then
        TestContext.Fail('After Remove of I2, I3.Next<>I1');
    Finally
      I2.Free;
    end;
  Finally
    LL.Free;
  end;
end;


Type

  { TCountVisitor }

  TCountVisitor = Class(TLinkedListVisitor)
    FCount : integer;
    FMax : integer;
    Function Visit(Item : TLinkedListItem) : Boolean; override;
    Constructor Create(AMax : integer);
  end;

{ TCountVisitor }

function TCountVisitor.Visit(Item: TLinkedListItem): Boolean;
begin
  Inc(FCount);
  Result:=(FMax=-1) or (FCount<FMax);
end;

constructor TCountVisitor.Create(AMax: integer);
begin
  FMax:=AMax;
end;

procedure TTestLinkedList.TestVisit;

Var
  I  : Integer;
  V  : TCountVisitor;
  LL : TLinkedList;

begin
  LL:=TLinkedList.Create(TLinkedListItem);
  Try
    For I:=1 to 5 do
      LL.Add;
    V:=TCountVisitor.Create(-1);
    Try
      LL.Foreach(V);
      TestContext.AssertTrue((5)=(V.FCount), 'Counter visited all items');
    Finally
      V.Free;
    end;
    V:=TCountVisitor.Create(3);
    Try
      LL.Foreach(V);
      TestContext.AssertTrue((3)=(V.FCount), 'Counter visited 3 items');
    Finally
      V.Free;
    end;
  Finally
    LL.Free;
  end;

end;



constructor TTestLinkedList.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestLinkedListTestCreate(AContext: TNXTestContext);
var lFixture: TTestLinkedList;
begin
  lFixture:=TTestLinkedList.Create(AContext, 'TestCreate');
  try
    lFixture.TestCreate;
  finally lFixture.Free; end;
end;

procedure RunTTestLinkedListTestAdd(AContext: TNXTestContext);
var lFixture: TTestLinkedList;
begin
  lFixture:=TTestLinkedList.Create(AContext, 'TestAdd');
  try
    lFixture.TestAdd;
  finally lFixture.Free; end;
end;

procedure RunTTestLinkedListTestAdd2(AContext: TNXTestContext);
var lFixture: TTestLinkedList;
begin
  lFixture:=TTestLinkedList.Create(AContext, 'TestAdd2');
  try
    lFixture.TestAdd2;
  finally lFixture.Free; end;
end;

procedure RunTTestLinkedListTestClear(AContext: TNXTestContext);
var lFixture: TTestLinkedList;
begin
  lFixture:=TTestLinkedList.Create(AContext, 'TestClear');
  try
    lFixture.TestClear;
  finally lFixture.Free; end;
end;

procedure RunTTestLinkedListTestRemove(AContext: TNXTestContext);
var lFixture: TTestLinkedList;
begin
  lFixture:=TTestLinkedList.Create(AContext, 'TestRemove');
  try
    lFixture.TestRemove;
  finally lFixture.Free; end;
end;

procedure RunTTestLinkedListTestRemove2(AContext: TNXTestContext);
var lFixture: TTestLinkedList;
begin
  lFixture:=TTestLinkedList.Create(AContext, 'TestRemove2');
  try
    lFixture.TestRemove2;
  finally lFixture.Free; end;
end;

procedure RunTTestLinkedListTestRemove3(AContext: TNXTestContext);
var lFixture: TTestLinkedList;
begin
  lFixture:=TTestLinkedList.Create(AContext, 'TestRemove3');
  try
    lFixture.TestRemove3;
  finally lFixture.Free; end;
end;

procedure RunTTestLinkedListTestVisit(AContext: TNXTestContext);
var lFixture: TTestLinkedList;
begin
  lFixture:=TTestLinkedList.Create(AContext, 'TestVisit');
  try
    lFixture.TestVisit;
  finally lFixture.Free; end;
end;

procedure RegistertclinkedlistTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tclinkedlist.TTestLinkedList');
  lSuite.AddTest('TestCreate', @RunTTestLinkedListTestCreate, 'collections');
  lSuite.AddTest('TestAdd', @RunTTestLinkedListTestAdd, 'collections');
  lSuite.AddTest('TestAdd2', @RunTTestLinkedListTestAdd2, 'collections');
  lSuite.AddTest('TestClear', @RunTTestLinkedListTestClear, 'collections');
  lSuite.AddTest('TestRemove', @RunTTestLinkedListTestRemove, 'collections');
  lSuite.AddTest('TestRemove2', @RunTTestLinkedListTestRemove2, 'collections');
  lSuite.AddTest('TestRemove3', @RunTTestLinkedListTestRemove3, 'collections');
  lSuite.AddTest('TestVisit', @RunTTestLinkedListTestVisit, 'collections');
end;

end.
