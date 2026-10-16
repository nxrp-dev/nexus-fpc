unit tccollection;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils;

type

  { TMyItem }

  TMyItem = Class(TCollectionItem)
  private
    FNr: integer;
  protected
    // Expose
    function GetOwner: TPersistent; override;
  published
    Property Nr : integer Read FNr Write FNr;
  end;

  { TMyCollection }

  TMyCollection = Class(TCollection)
  Private
    FOwner : TPersistent;
    FUpdateCount : Integer;
    FLastNotifyItem,
    FLastUpdate : TCollectionItem;
    FNotifyCount : Integer;
    FLastNotify : TCollectionNotification;
    Function GetOwner : TPersistent; override;
  Public
    procedure Update(Item: TCollectionItem); override;
    procedure Notify(Item: TCollectionItem;Action: TCollectionNotification); override;
    Procedure ResetUpdate;
    Procedure ResetNotify;
    property PropName;
  end;


  { TTestTCollection }

  TTestTCollection= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    procedure AccessNegativeIndex;
    procedure AccessTooBigIndex;
    procedure DeleteNegativeIndex;
    procedure DeleteTooBigIndex;
    procedure MoveNegativeIndex;
    procedure MoveTooBigIndex;
  protected
    FColl : TMyCollection;
    Function MyItem(I : integer) : TMyItem;
    procedure AddItems(ACount : Integer);
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure TestCreate;
    procedure TestAdd;
    procedure TestItemCollection;
    procedure TestAddTwo;
    Procedure TestDelete;
    procedure TestClear;
    Procedure TestFreeItem;
    Procedure TestMoveForward;
    Procedure TestMoveBackward;
    Procedure TestID;
    Procedure TestItemOwner;
    Procedure TestDisplayName;
    procedure TestOwnerNamePath;
    Procedure TestItemNamePath;
    Procedure TestOwnerItemNamePath;
    Procedure TestChangeCollection;
    procedure TestAccesIndexOutOfBounds;
    procedure TestDeleteIndexOutOfBounds;
    procedure TestMoveIndexOutOfBounds;
    Procedure TestUpdateAdd;
    Procedure TestUpdateDelete;
    Procedure TestUpdateDisplayName;
    Procedure TestUpdateCount;
    Procedure TestUpdateCountNested;
    Procedure TestUpdateMove;
    Procedure TestNotifyAdd;
    Procedure TestNotifyDelete;
  end;

procedure RegistertccollectionTests(ARegistry: TNXTestRegistry);

implementation

procedure TTestTCollection.TestCreate;
begin
  TestContext.AssertTrue((0)=(FColl.Count), 'Item count 0 at create');
  TestContext.AssertTrue((TMyItem)=(FColl.ItemClass), 'ItemClass is TMyItem');
end;

procedure TTestTCollection.TestAdd;
begin
  AddItems(1);
  TestContext.AssertTrue((1)=(FColl.Count), 'Item count is 1 after add');
  TestContext.AssertTrue((FColl.ItemClass)=(FColl.Items[0].ClassType), 'Item class is correct');
  TestContext.AssertTrue((0)=(FColl.Items[0].Index), 'Item index is 0');
  TestContext.AssertTrue((0)=(FColl.Items[0].Id), 'Item ID is 0');
end;

procedure TTestTCollection.TestItemCollection;
begin
  AddItems(1);
  If MyItem(0).Collection<>FColl then
    TestContext.Fail('Item''s Collection is not collection');
end;

procedure TTestTCollection.TestAddTwo;

Var
  I: Integer;

begin
  AddItems(3);
  TestContext.AssertTrue((3)=(FColl.Count), 'Item count is 3 after add');
  For I:=0 to 2 do
    begin
    TestContext.AssertTrue((FColl.ItemClass)=(FColl.Items[i].ClassType), Format('Item %d class is correct',[i]));
    TestContext.AssertTrue((i)=(FColl.Items[i].Index), Format('Item %d index is 0',[i]));
    TestContext.AssertTrue((i)=(FColl.Items[i].Id), Format('Item %d ID is 0',[i]));
    TestContext.AssertTrue((i+1)=(MyItem(i).Nr), Format('Item %d ID is %d',[i,i+1]));
    end;
end;

procedure TTestTCollection.TestDelete;
begin
  AddItems(3);
  FColl.Delete(1);
  TestContext.AssertTrue((2)=(FColl.Count), 'Item count after delete');
  TestContext.AssertTrue((1)=(MyItem(0).Nr), 'Item 0 ok after delete');
  TestContext.AssertTrue((3)=(MyItem(1).Nr), 'Item 1 ok after delete');
end;

procedure TTestTCollection.TestClear;
begin
  AddItems(3);
  FColl.Clear;
  TestContext.AssertTrue((0)=(FColl.Count), 'Item count after clear');
end;

procedure TTestTCollection.TestFreeItem;
begin
  AddItems(3);
  MyItem(1).Free;
  TestContext.AssertTrue((2)=(FColl.Count), 'Item count after free');
  TestContext.AssertTrue((1)=(MyItem(0).Nr), 'Item 0 ok after free');
  TestContext.AssertTrue((3)=(MyItem(1).Nr), 'Item 1 ok after free');
end;

procedure TTestTCollection.TestMoveForward;
begin
  AddItems(5);
  MyItem(4).Index:=1;
  TestContext.AssertTrue((1)=(MyItem(0).Nr), 'Item 0 ok after move');
  TestContext.AssertTrue((5)=(MyItem(1).Nr), 'Item 1 ok after move');
  TestContext.AssertTrue((2)=(MyItem(2).Nr), 'Item 2 ok after move');
  TestContext.AssertTrue((3)=(MyItem(3).Nr), 'Item 3 ok after move');
  TestContext.AssertTrue((4)=(MyItem(4).Nr), 'Item 4 ok after move');
end;

procedure TTestTCollection.TestMoveBackward;

begin
  AddItems(5);
  MyItem(1).Index:=3;
  TestContext.AssertTrue((1)=(MyItem(0).Nr), 'Item 0 ok after move');
  TestContext.AssertTrue((3)=(MyItem(1).Nr), 'Item 1 ok after move');
  TestContext.AssertTrue((4)=(MyItem(2).Nr), 'Item 2 ok after move');
  TestContext.AssertTrue((2)=(MyItem(3).Nr), 'Item 3 ok after move');
  TestContext.AssertTrue((5)=(MyItem(4).Nr), 'Item 4 ok after move');
end;

procedure TTestTCollection.TestID;

Var
  I : TMyItem;

begin
  AddItems(5);
  FColl.Delete(2);
  FColl.Delete(2);
  I:=TMyItem(FColl.Add);
  TestContext.AssertTrue((5)=(I.Id), 'ID keeps counting up')
end;

procedure TTestTCollection.TestItemOwner;
begin
  AddItems(1);
  If (MyItem(0).GetOwner<>FColl) then
    TestContext.Fail('Item owner is not collection');
end;

procedure TTestTCollection.TestDisplayName;
begin
  AddItems(1);
  TestContext.AssertTrue(('TMyItem')=(MyItem(0).DisplayName), 'Displayname is classname');
end;

procedure TTestTCollection.TestItemNamePath;
begin
  AddItems(2);
  TestContext.AssertTrue((FColl.GetNamePath+'[0]')=(MyItem(0).GetNamePath), 'Item namepath is collection namepath+index');
  TestContext.AssertTrue((FColl.GetNamePath+'[1]')=(MyItem(1).GetNamePath), 'Item namepath is collection namepath+index');
end;

procedure TTestTCollection.TestOwnerItemNamePath;

Var
  P : TPersistent;

begin
  P:=TPersistent.Create;
  try
    TMyCollection(FColl).FOwner:=P;
    AddItems(2);
    TMyCollection(FColl).PropName:='Something';
    TestContext.AssertTrue(('TPersistent.Something[0]')=(MyItem(0).GetNamePath), 'Item namepath is collection namepath+index');
  finally
    P.Free;
  end;
end;

procedure TTestTCollection.TestOwnerNamePath;

Var
  P : TPersistent;

begin
  P:=TPersistent.Create;
  try
    TMyCollection(FColl).FOwner:=P;
    AddItems(2);
    TMyCollection(FColl).PropName:='Something';
    TestContext.AssertTrue(('TPersistent.Something')=(FColl.GetNamePath), 'Namepath is collection namepath+index');
  finally
    P.Free;
  end;
end;

procedure TTestTCollection.TestChangeCollection;

Var
  FCol2 : TCollection;
  I : TCollectionItem;

begin
  AddItems(2);
  FCol2:=TCollection.Create(TMyItem);
  try
    I:=FCol2.Add;
    I.Collection:=FColl;
    TestContext.AssertTrue((0)=(FCol2.Count), 'Moved item, count of source is zero');
    TestContext.AssertTrue((3)=(FColl.Count), 'Moved item, count of dest is 1');
    TestContext.AssertTrue((2)=(I.Index), 'Moved item, index is 2');
    If (FColl.Items[0].Collection<>FColl) then
      TestContext.Fail('Collection owner is not set correctly after move');
    TestContext.AssertTrue((2)=(I.ID), 'Moved item, ID is 2');
  finally
    FCol2.free;
  end;
end;

procedure TTestTCollection.AccessNegativeIndex;

begin
  FColl.Items[-1];
end;

procedure TTestTCollection.AccessTooBigIndex;

begin
  FColl.Items[3];
end;


procedure TTestTCollection.TestAccesIndexOutOfBounds;
begin
  AddItems(3);
  TestContext.AssertRaises(EListError, @AccessNegativeIndex, 'Access Negative Index');
  TestContext.AssertRaises(EListError, @AccessTooBigIndex, 'Access Index too big');
end;

procedure TTestTCollection.DeleteNegativeIndex;
begin
  FColl.Delete(-1);
end;

procedure TTestTCollection.DeleteTooBigIndex;
begin
  FColl.Delete(3);
end;

procedure TTestTCollection.TestDeleteIndexOutOfBounds;
begin
  AddItems(3);
  TestContext.AssertRaises(EListError, @DeleteNegativeIndex, 'Delete Negative Index');
  TestContext.AssertRaises(EListError, @DeleteTooBigIndex, 'Delete Index too big');
end;

procedure TTestTCollection.MoveNegativeIndex;
begin
  FColl.Items[1].Index:=-1;
end;

procedure TTestTCollection.MoveTooBigIndex;
begin
  FColl.Items[1].Index:=3;
end;

procedure TTestTCollection.TestMoveIndexOutOfBounds;
begin
  AddItems(3);
  TestContext.AssertRaises(EListError, @MoveNegativeIndex, 'Move Negative first index');
  TestContext.AssertRaises(EListError, @MoveTooBigIndex, 'Exchange Negative second index');
end;

procedure TTestTCollection.TestUpdateAdd;
begin
  AddItems(1);
  If (FColl.FLastUpdate<>Nil) then
    TestContext.Fail('update item found !');
  TestContext.AssertTrue((1)=(FColl.FUpdateCount), 'Update count is 1');

end;

procedure TTestTCollection.TestUpdateDelete;
begin
  AddItems(1);
  FColl.ResetUpdate;
  FColl.Delete(0);
  If (FColl.FLastUpdate<>Nil) then
    TestContext.Fail('update item found !');
  TestContext.AssertTrue((1)=(FColl.FUpdateCount), 'Update count is 1');

end;

procedure TTestTCollection.TestUpdateDisplayName;
begin
  AddItems(1);
  FColl.ResetUpdate;
  MyItem(0).DisplayName:='Something';
  TestContext.AssertTrue((1)=(FColl.FUpdateCount), 'Display name notification. Update count is 1');
  If (FColl.FLastUpdate<>MyItem(0)) then
    TestContext.Fail('No displayname update');
end;

procedure TTestTCollection.TestUpdateCount;
begin
  FColl.BeginUpdate;
  Try
    AddItems(2);

    TestContext.AssertTrue((0)=(FColl.FUpdateCount), 'Beginupdate; adds. Update count is 0');
    If (FColl.FLastUpdate<>Nil) then
      TestContext.Fail('Beginupdate; FlastUpdate not nil');
  finally
    FColl.EndUpdate;
  end;
  TestContext.AssertTrue((1)=(FColl.FUpdateCount), 'Endupdate; adds. Update count is 1');
  If (FColl.FLastUpdate<>Nil) then
    TestContext.Fail('Endupdate; FlastUpdate not nil');
end;

procedure TTestTCollection.TestUpdateCountNested;
begin
  FColl.BeginUpdate;
  Try
    AddItems(2);
    FColl.BeginUpdate;
    Try
      AddItems(2);
      TestContext.AssertTrue((0)=(FColl.FUpdateCount), 'Beginupdate 2; adds. Update count is 0');
      If (FColl.FLastUpdate<>Nil) then
        TestContext.Fail('Beginupdate 2; FlastUpdate not nil');
    finally
      FColl.EndUpdate;
    end;
    TestContext.AssertTrue((0)=(FColl.FUpdateCount), 'Endupdate 1; Update count is 0');
    If (FColl.FLastUpdate<>Nil) then
      TestContext.Fail('EndUpdate 1; FlastUpdate not nil');
  finally
    FColl.EndUpdate;
  end;
  TestContext.AssertTrue((1)=(FColl.FUpdateCount), 'Endupdate 2; adds. Update count is 1');
  If (FColl.FLastUpdate<>Nil) then
    TestContext.Fail('Endupdate 2; FlastUpdate not nil');
end;

procedure TTestTCollection.TestUpdateMove;
begin
  AddItems(5);
  FColl.ResetUpdate;
  MyItem(4).Index:=2;
  TestContext.AssertTrue((1)=(FColl.FUpdateCount), 'Moved item. Update count is 1');
  If (FColl.FLastUpdate<>Nil) then
    TestContext.Fail('Moved item notification - not all items updated');
end;

procedure TTestTCollection.TestNotifyAdd;
begin
  AddItems(1);
  If (FColl.FLastNotifyItem<>MyItem(0)) then
    TestContext.Fail('No notify item found !');
  TestContext.AssertTrue((1)=(FColl.FNotifyCount), 'Notify count is 1');
  TestContext.AssertTrue((Ord(cnAdded))=(Ord(FColl.FLastNotify)), 'Notify action is cnAdded');
end;

procedure TTestTCollection.TestNotifyDelete;

begin
  AddItems(3);
  FColl.ResetNotify;
  FColl.Delete(1);
  // cnDeleting/cnExtracting. Can't currently test for 2 events...
  TestContext.AssertTrue((2)=(FColl.FNotifyCount), 'Notify count is 2');
  TestContext.AssertTrue((Ord(cnExtracting))=(Ord(FColl.FLastNotify)), 'Notify action is cnExtracted');
end;

function TTestTCollection.MyItem(I: integer): TMyItem;
begin
  Result:=TMyItem(FColl.Items[i]);
end;

procedure TTestTCollection.AddItems(ACount: Integer);

Var
  I : integer;

begin
  For I:=1 to ACount do
    TMyItem(FColl.Add).Nr:=I;
end;

procedure TTestTCollection.SetUp;
begin
  FColl:=TMyCollection.Create(TMyItem);
end;

procedure TTestTCollection.TearDown;
begin
   FreeAndNil(FColl);
end;

{ TMyItem }

function TMyItem.GetOwner: TPersistent;
begin
  Result:=inherited GetOwner;
end;

{ TMyCollection }

function TMyCollection.GetOwner: TPersistent;
begin
  Result:=FOwner;
  If (Result=Nil) then
    Result:=Inherited GetOwner;
end;

procedure TMyCollection.Update(Item: TCollectionItem);
begin
  Inc(FUpdateCount);
  FLastUpdate:=Item;
end;

procedure TMyCollection.Notify(Item: TCollectionItem;
  Action: TCollectionNotification);
begin
  Inc(FNotifyCount);
  FLastNotify:=Action;
  FLastNotifyItem:=Item;
end;

procedure TMyCollection.ResetUpdate;
begin
  FUpdateCount:=0;
  FLastUpdate:=Nil;
end;

procedure TMyCollection.ResetNotify;
begin
  FNotifyCount:=0;
  FLastNotifyItem:=Nil;
end;


constructor TTestTCollection.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestTCollectionTestCreate(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestCreate');
  try
    lFixture.SetUp;
    try lFixture.TestCreate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestAdd(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestItemCollection(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestItemCollection');
  try
    lFixture.SetUp;
    try lFixture.TestItemCollection; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestAddTwo(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestAddTwo');
  try
    lFixture.SetUp;
    try lFixture.TestAddTwo; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestDelete(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestDelete');
  try
    lFixture.SetUp;
    try lFixture.TestDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestClear(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestClear');
  try
    lFixture.SetUp;
    try lFixture.TestClear; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestFreeItem(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestFreeItem');
  try
    lFixture.SetUp;
    try lFixture.TestFreeItem; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestMoveForward(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestMoveForward');
  try
    lFixture.SetUp;
    try lFixture.TestMoveForward; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestMoveBackward(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestMoveBackward');
  try
    lFixture.SetUp;
    try lFixture.TestMoveBackward; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestID(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestID');
  try
    lFixture.SetUp;
    try lFixture.TestID; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestItemOwner(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestItemOwner');
  try
    lFixture.SetUp;
    try lFixture.TestItemOwner; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestDisplayName(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestDisplayName');
  try
    lFixture.SetUp;
    try lFixture.TestDisplayName; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestOwnerNamePath(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestOwnerNamePath');
  try
    lFixture.SetUp;
    try lFixture.TestOwnerNamePath; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestItemNamePath(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestItemNamePath');
  try
    lFixture.SetUp;
    try lFixture.TestItemNamePath; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestOwnerItemNamePath(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestOwnerItemNamePath');
  try
    lFixture.SetUp;
    try lFixture.TestOwnerItemNamePath; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestChangeCollection(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestChangeCollection');
  try
    lFixture.SetUp;
    try lFixture.TestChangeCollection; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestAccesIndexOutOfBounds(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestAccesIndexOutOfBounds');
  try
    lFixture.SetUp;
    try lFixture.TestAccesIndexOutOfBounds; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestDeleteIndexOutOfBounds(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestDeleteIndexOutOfBounds');
  try
    lFixture.SetUp;
    try lFixture.TestDeleteIndexOutOfBounds; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestMoveIndexOutOfBounds(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestMoveIndexOutOfBounds');
  try
    lFixture.SetUp;
    try lFixture.TestMoveIndexOutOfBounds; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestUpdateAdd(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestUpdateAdd');
  try
    lFixture.SetUp;
    try lFixture.TestUpdateAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestUpdateDelete(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestUpdateDelete');
  try
    lFixture.SetUp;
    try lFixture.TestUpdateDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestUpdateDisplayName(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestUpdateDisplayName');
  try
    lFixture.SetUp;
    try lFixture.TestUpdateDisplayName; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestUpdateCount(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestUpdateCount');
  try
    lFixture.SetUp;
    try lFixture.TestUpdateCount; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestUpdateCountNested(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestUpdateCountNested');
  try
    lFixture.SetUp;
    try lFixture.TestUpdateCountNested; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestUpdateMove(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestUpdateMove');
  try
    lFixture.SetUp;
    try lFixture.TestUpdateMove; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestNotifyAdd(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestNotifyAdd');
  try
    lFixture.SetUp;
    try lFixture.TestNotifyAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTCollectionTestNotifyDelete(AContext: TNXTestContext);
var lFixture: TTestTCollection;
begin
  lFixture:=TTestTCollection.Create(AContext, 'TestNotifyDelete');
  try
    lFixture.SetUp;
    try lFixture.TestNotifyDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertccollectionTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tccollection.TTestTCollection');
  lSuite.AddTest('TestCreate', @RunTTestTCollectionTestCreate);
  lSuite.AddTest('TestAdd', @RunTTestTCollectionTestAdd);
  lSuite.AddTest('TestItemCollection', @RunTTestTCollectionTestItemCollection);
  lSuite.AddTest('TestAddTwo', @RunTTestTCollectionTestAddTwo);
  lSuite.AddTest('TestDelete', @RunTTestTCollectionTestDelete);
  lSuite.AddTest('TestClear', @RunTTestTCollectionTestClear);
  lSuite.AddTest('TestFreeItem', @RunTTestTCollectionTestFreeItem);
  lSuite.AddTest('TestMoveForward', @RunTTestTCollectionTestMoveForward);
  lSuite.AddTest('TestMoveBackward', @RunTTestTCollectionTestMoveBackward);
  lSuite.AddTest('TestID', @RunTTestTCollectionTestID);
  lSuite.AddTest('TestItemOwner', @RunTTestTCollectionTestItemOwner);
  lSuite.AddTest('TestDisplayName', @RunTTestTCollectionTestDisplayName);
  lSuite.AddTest('TestOwnerNamePath', @RunTTestTCollectionTestOwnerNamePath);
  lSuite.AddTest('TestItemNamePath', @RunTTestTCollectionTestItemNamePath);
  lSuite.AddTest('TestOwnerItemNamePath', @RunTTestTCollectionTestOwnerItemNamePath);
  lSuite.AddTest('TestChangeCollection', @RunTTestTCollectionTestChangeCollection);
  lSuite.AddTest('TestAccesIndexOutOfBounds', @RunTTestTCollectionTestAccesIndexOutOfBounds);
  lSuite.AddTest('TestDeleteIndexOutOfBounds', @RunTTestTCollectionTestDeleteIndexOutOfBounds);
  lSuite.AddTest('TestMoveIndexOutOfBounds', @RunTTestTCollectionTestMoveIndexOutOfBounds);
  lSuite.AddTest('TestUpdateAdd', @RunTTestTCollectionTestUpdateAdd);
  lSuite.AddTest('TestUpdateDelete', @RunTTestTCollectionTestUpdateDelete);
  lSuite.AddTest('TestUpdateDisplayName', @RunTTestTCollectionTestUpdateDisplayName);
  lSuite.AddTest('TestUpdateCount', @RunTTestTCollectionTestUpdateCount);
  lSuite.AddTest('TestUpdateCountNested', @RunTTestTCollectionTestUpdateCountNested);
  lSuite.AddTest('TestUpdateMove', @RunTTestTCollectionTestUpdateMove);
  lSuite.AddTest('TestNotifyAdd', @RunTTestTCollectionTestNotifyAdd);
  lSuite.AddTest('TestNotifyDelete', @RunTTestTCollectionTestNotifyDelete);
end;

end.
