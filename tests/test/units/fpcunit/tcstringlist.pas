unit tcstringlist;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils;

type

  { TTestTStringList }

  TTestTStringList= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private
    procedure AddB;
    procedure DeleteNegativeIndex;
    procedure DeleteTooBigIndex;
    procedure ExchangeNegativeIndex1;
    procedure ExchangeTooBigIndex1;
    procedure ExchangeNegativeIndex2;
    procedure ExchangeTooBigIndex2;
    procedure AccessNegativeIndex;
    procedure AccessTooBigIndex;
    Procedure Shuffle;
  protected
    List : TStringList;
    Procedure FillList(ACount : Integer);
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure TestCreate;
    procedure TestAdd;
    procedure TestAddIndex;
    procedure TestAdd2;
    procedure TestInsertFirst;
    Procedure TestInsertMiddle;
    procedure TestDelete;
    Procedure TestClear;
    Procedure TestIndexOf;
    procedure TestExchange;
    procedure TestAccesIndexOutOfBounds;
    procedure TestDeleteIndexOutOfBounds;
    procedure TestExchangeIndexOutOfBounds;
    Procedure TestSort;
    Procedure TestSorted;
    Procedure TestSortedAdd;
    Procedure TestSortedAddAll;
    Procedure TestSortedDupError;
    procedure TestSortedAddDuplicate;
    Procedure TestSortedIndexOf;
    Procedure TestChange;
    procedure TestChangeAgain;
    procedure TestChangeCount;
    procedure TestChangeClear;
    Procedure TestSetText;
    procedure TestSetTextEOL;
    procedure TestSetTextEmpty;
    procedure TestSetTextEOLEmpty;
  end;

  { TEventSink }

  TEventSink = Class(TObject)
  private
    FCOunt: Integer;
    FSender: TObject;
  public
    Procedure Change(Sender : TObject);
    Procedure Reset;
    Property ChangeCount : Integer Read FCOunt;
    Property LastSender : TObject Read FSender;
  end;

procedure RegistertcstringlistTests(ARegistry: TNXTestRegistry);

implementation

procedure TTestTStringList.TestCreate;
begin
  TestContext.AssertTrue((0)=(List.Count), 'Empty list has count 0');
  TestContext.AssertTrue((False)=(List.Sorted), 'Empty list has sorted false');
  If List.Duplicates<>dupIgnore then
    TestContext.Fail('Empty list has duplicates=dupIgnore');
end;

procedure TTestTStringList.TestAdd;

begin
  FillList(1);
  TestContext.AssertTrue((1)=(List.Count), 'Add 1 element, count is 1');
  TestContext.AssertTrue(('Item 1')=(List[0]), 'Add 1 element, last element is "Item 1"');
end;

procedure TTestTStringList.TestAddIndex;

begin
  TestContext.AssertTrue((0)=(List.Add('First')), 'Add first element at index 0');
  TestContext.AssertTrue((1)=(List.Add('second')), 'Add second element, at index 1');
end;

procedure TTestTStringList.TestAdd2;

begin
  FillList(2);
  TestContext.AssertTrue((2)=(List.Count), 'Add 2 elements, count is 2');
  TestContext.AssertTrue(('Item 1')=(List[0]), 'Add 2 elements, first element is "Item 1"');
  TestContext.AssertTrue(('Item 2')=(List[1]), 'Add 2 elements, second element is "Item 2"');
end;

procedure TTestTStringList.TestInsertFirst;
begin
  FillList(3);
  List.Insert(0,'New');
  TestContext.AssertTrue((4)=(List.Count), 'Insert 1 in 3, count is 4');
  TestContext.AssertTrue(('New')=(List[0]), 'Insert 1 in 3, first is inserted');
  TestContext.AssertTrue(('Item 1')=(List[1]), 'Insert 1 in 3, second is old first');
end;

procedure TTestTStringList.TestInsertMiddle;
begin
  FillList(3);
  List.Insert(1,'New');
  TestContext.AssertTrue((4)=(List.Count), 'Insert 1 in 3, count is 4');
  TestContext.AssertTrue(('New')=(List[1]), 'Insert 1 in 3, 1 is inserted');
  TestContext.AssertTrue(('Item 2')=(List[2]), 'Insert 1 in 3, 2 is old 2');
  TestContext.AssertTrue(('Item 1')=(List[0]), 'Insert 1 in 3, 0 is untouched');
end;

procedure TTestTStringList.TestClear;
begin
  FillList(3);
  List.Clear;
  TestContext.AssertTrue((0)=(List.Count), 'Clear: count is 0');
end;

procedure TTestTStringList.TestIndexOf;
begin
  FillList(11);
  TestContext.AssertTrue((2)=(List.IndexOf('Item 3')), 'Find third element');
  TestContext.AssertTrue((2)=(List.IndexOf('ITEM 3')), 'Find third element, wrong case');
end;

procedure TTestTStringList.TestDelete;

begin
  FillList(3);
  List.Delete(1);
  TestContext.AssertTrue((2)=(List.Count), 'Delete 1 from 3, count is 2');
  TestContext.AssertTrue(('Item 1')=(List[0]), 'Delete 1 from 3, first is "Item 1"');
  TestContext.AssertTrue(('Item 3')=(List[1]), 'Delete 1 from 3, second is "Item 3"');
end;

procedure TTestTStringList.TestExchange;

begin
  FillList(3);
  List.Exchange(0,2);
  TestContext.AssertTrue((3)=(List.Count), 'Exchange 0 and 2, count is 3');
  TestContext.AssertTrue(('Item 3')=(List[0]), 'Exchange 0 and 2, first is "Item 3"');
  TestContext.AssertTrue(('Item 2')=(List[1]), 'Exchange 0 and 2, second is "Item 2"');
  TestContext.AssertTrue(('Item 1')=(List[2]), 'Exchange 0 and 2, third is "Item 1"');
end;

procedure TTestTStringList.DeleteNegativeIndex;
begin
  List.Delete(-1);
end;

procedure TTestTStringList.DeleteTooBigIndex;
begin
  List.Delete(3);
end;

procedure TTestTStringList.ExchangeNegativeIndex1;
begin
  List.Exchange(-1,2);
end;

procedure TTestTStringList.ExchangeTooBigIndex1;
begin
  List.Exchange(3,2);
end;

procedure TTestTStringList.ExchangeNegativeIndex2;
begin
  List.Exchange(2,-1);

end;

procedure TTestTStringList.ExchangeTooBigIndex2;
begin
  List.Exchange(2,3);
end;

procedure TTestTStringList.AccessNegativeIndex;

begin
  List[-1];
end;

procedure TTestTStringList.AccessTooBigIndex;

begin
  List[3];
end;

procedure TTestTStringList.Shuffle;

Var
  I,I1,I2 : Integer;

begin
  For I:=1 to List.Count* 2 do
    begin
    I1:=Random(List.Count);
    I2:=Random(List.Count);
    if I1<>I2 then
      List.Exchange(I1,I2);
    end;
end;

procedure TTestTStringList.TestAccesIndexOutOfBounds;
begin
  FillList(3);
  TestContext.AssertRaises(EStringListError, @AccessNegativeIndex, 'Access Negative Index');
  TestContext.AssertRaises(EStringListError, @AccessTooBigIndex, 'Access Index too big');
end;

procedure TTestTStringList.TestDeleteIndexOutOfBounds;
begin
  FillList(3);
  TestContext.AssertRaises(EStringListError, @DeleteNegativeIndex, 'Delete Negative Index');
  TestContext.AssertRaises(EStringListError, @DeleteTooBigIndex, 'Delete Index too big');
end;

procedure TTestTStringList.TestExchangeIndexOutOfBounds;
begin
  FillList(3);
  TestContext.AssertRaises(EStringListError, @ExchangeNegativeIndex1, 'Exchange Negative first index');
  TestContext.AssertRaises(EStringListError, @ExchangeNegativeIndex2, 'Exchange Negative second index');
  TestContext.AssertRaises(EStringListError, @ExchangeTooBigIndex1, 'Exchange first Index too big');
  TestContext.AssertRaises(EStringListError, @ExchangeTooBigIndex2, 'Exchange second Index too big');
end;

procedure TTestTStringList.TestSort;

Var
  I : Integer;

begin
  FillList(9);
  Shuffle;
  List.Sort;
  For I:=0 to List.Count-1 do
    If (List[i]<>'Item '+IntToStr(I+1)) then
      TestContext.Fail(Format('Item at position %d is out of place (%s)',[I,List[i]]));
end;

procedure TTestTStringList.TestSorted;

Var
  I : Integer;
begin
  FillList(9);
  Shuffle;
  List.Sorted:=True;
  For I:=0 to List.Count-1 do
    If (List[i]<>'Item '+IntToStr(I+1)) then
      TestContext.Fail(Format('Item at position %d is out of place (%s)',[I,List[i]]));
end;

procedure TTestTStringList.TestSortedAdd;
begin
  List.Sorted:=True;
  List.Add('B');
  TestContext.AssertTrue((0)=(List.Add('A')), 'Add second element at first location in sorted list');
  TestContext.AssertTrue((1)=(List.Add('AB')), 'Add third element at first location in sorted list');
  TestContext.AssertTrue((3)=(List.Add('C')), 'Add fourth element at last location in sorted list');
end;

procedure TTestTStringList.TestSortedAddAll;

Var
  I : Integer;

begin
  List.Sorted:=True;
  FillList(9);
  For I:=0 to List.Count-1 do
    If (List[i]<>'Item '+IntToStr(I+1)) then
      TestContext.Fail(Format('Item at position %d is out of place (%s)',[I,List[i]]));
end;

procedure TTestTStringList.AddB;

begin
  List.Add('B');
end;

procedure TTestTStringList.TestSortedDupError;
begin
  List.Sorted:=True;
  List.Duplicates:=dupError;
  List.Add('B');
  TestContext.AssertTrue((0)=(List.Add('A')), 'Add second element at first location in sorted list');
  TestContext.AssertRaises(EStringListError, @AddB, '');
end;

procedure TTestTStringList.TestSortedAddDuplicate;

begin
  List.Sorted:=True;
  List.Duplicates:=dupAccept;
  List.Add('B');
  TestContext.AssertTrue((0)=(List.Add('A')), 'Add second element at first location in sorted list');
  TestContext.AssertTrue((1)=(List.Add('B')), 'Add third element at first location in sorted list');
  TestContext.AssertTrue((3)=(List.Add('C')), 'Add fourth element at last location in sorted list');
end;

procedure TTestTStringList.TestSortedIndexOf;

// Tests find, as find is called in case of sorted index

begin
  List.Sorted:=True;
  FillList(11);
  // 1 10 11 2 3 - so index 4
  TestContext.AssertTrue((4)=(List.IndexOf('Item 3')), 'Find third element');
  TestContext.AssertTrue((4)=(List.IndexOf('ITEM 3')), 'Find third element, wrong case');
end;

procedure TTestTStringList.TestChange;

Var
  S : TEventSink;

begin
  S:=TEventSink.Create;
  try
    List.OnChange:=@S.Change;
    List.Add('new');
    TestContext.AssertTrue((1)=(S.ChangeCount), 'Change count equals 1 after add');
    If List<>S.LastSender then
      TestContext.Fail('Sender is list');
  finally
    S.Free;
  end;
end;

procedure TTestTStringList.TestChangeAgain;

Var
  S : TEventSink;

begin
  S:=TEventSink.Create;
  try
    List.BeginUpdate;
    Try
    List.OnChange:=@S.Change;
    List.Add('new');
      TestContext.AssertTrue((0)=(S.ChangeCount), 'Change count equals 0 after add (beginupdate)');
      If (Nil<>S.LastSender) then
        TestContext.Fail('Sender is nil');
    Finally
      List.EndUpdate;
    end;
    TestContext.AssertTrue((1)=(S.ChangeCount), 'Change count equals 1 after add endupdate');
    If List<>S.LastSender then
      TestContext.Fail('Sender is list');
  finally
    S.Free;
  end;
end;

procedure TTestTStringList.TestChangeCount;

Var
  S : TEventSink;

begin
  S:=TEventSink.Create;
  try
    List.BeginUpdate;
    Try
      // Count is 1, no notification
      List.OnChange:=@S.Change;
      List.Add('new');
      TestContext.AssertTrue((0)=(S.ChangeCount), 'Change count equals 0 after add (1st beginupdate)');
      If (Nil<>S.LastSender) then
        TestContext.Fail('Sender is nil');
      List.BeginUpdate;
      Try
        List.Add('new2');
        // Count is 2, no notification
        TestContext.AssertTrue((0)=(S.ChangeCount), 'Change count equals 0 after add (2nd beginupdate)');
        If (Nil<>S.LastSender) then
          TestContext.Fail('Sender is nil');
      Finally
        List.EndUpdate;
      end;
      // Count is 1 again, no notification
      TestContext.AssertTrue((0)=(S.ChangeCount), 'Change count equals 0 after first endupdate');
      If (Nil<>S.LastSender) then
        TestContext.Fail('Sender is nil after first endupdate');
    Finally
      List.EndUpdate;
    end;
    TestContext.AssertTrue((1)=(S.ChangeCount), 'Change count equals 1 after add endupdate');
    If List<>S.LastSender then
      TestContext.Fail('Sender is list');
  finally
    S.Free;
  end;
end;

procedure TTestTStringList.TestChangeClear;

Var
  S : TEventSink;

begin
  FillList(9);
  S:=TEventSink.Create;
  try
    List.OnChange:=@S.Change;
    List.Clear;
    TestContext.AssertTrue((1)=(S.ChangeCount), 'Change count equals 1 after clear');
  finally
    S.Free;
  end;
end;

procedure TTestTStringList.TestSetText;

Const
  Lines = 'Line 1'+sLineBreak+'Line 2'+sLineBreak+'Line 3';

begin
  List.Text:=Lines;
  TestContext.AssertTrue((3)=(List.Count), '3 lines set');
  TestContext.AssertTrue(('Line 1')=(List[0]), 'First line is "Line 1"');
  TestContext.AssertTrue(('Line 2')=(List[1]), 'Second line is "Line 2"');
  TestContext.AssertTrue(('Line 3')=(List[2]), 'Third line is "Line 3"');
end;

procedure TTestTStringList.TestSetTextEOL;

Const
  Lines = 'Line 1'+sLineBreak+'Line 2'+sLineBreak;

begin
  List.Text:=Lines;
  TestContext.AssertTrue((2)=(List.Count), '2 lines set');
  TestContext.AssertTrue(('Line 1')=(List[0]), 'First line is "Line 1"');
  TestContext.AssertTrue(('Line 2')=(List[1]), 'Second line is "Line 2"');
end;

procedure TTestTStringList.TestSetTextEOLEmpty;

Const
  Lines = 'Line 1'+sLineBreak+'Line 2'+sLineBreak+slineBreak;

begin
  List.Text:=Lines;
  TestContext.AssertTrue((3)=(List.Count), '3 lines set');
  TestContext.AssertTrue(('Line 1')=(List[0]), 'First line is "Line 1"');
  TestContext.AssertTrue(('Line 2')=(List[1]), 'Second line is "Line 2"');
  TestContext.AssertTrue(('')=(List[2]), 'Third line is empty');
end;

procedure TTestTStringList.TestSetTextEmpty;

Const
  Lines = 'Line 1'+sLineBreak+sLineBreak+SlineBreak+'Line 2';

begin
  List.Text:=Lines;
  TestContext.AssertTrue((4)=(List.Count), '4 lines set');
  TestContext.AssertTrue(('Line 1')=(List[0]), 'First line is "Line 1"');
  TestContext.AssertTrue(('')=(List[1]), 'Second line is empty');
  TestContext.AssertTrue(('')=(List[2]), 'Third line is empty');
  TestContext.AssertTrue(('Line 2')=(List[3]), 'Fourth line is "Line 2"');
end;


procedure TTestTStringList.FillList(ACount: Integer);

Var
  I : integer;

begin
  For I:=1 to ACount do
    List.Add('Item '+IntToStr(I));
end;

procedure TTestTStringList.SetUp;
begin
  List:=TStringList.Create;
end;

procedure TTestTStringList.TearDown;
begin
  FreeAndNil(List);
end;

{ TEventSink }

procedure TEventSink.Change(Sender: TObject);
begin
  Inc(FCount);
  FSender:=Sender;
end;

procedure TEventSink.Reset;
begin
  FCount:=0;
  FSender:=Nil;
end;


constructor TTestTStringList.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestTStringListTestCreate(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestCreate');
  try
    lFixture.SetUp;
    try lFixture.TestCreate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestAdd(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestAddIndex(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestAddIndex');
  try
    lFixture.SetUp;
    try lFixture.TestAddIndex; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestAdd2(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestAdd2');
  try
    lFixture.SetUp;
    try lFixture.TestAdd2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestInsertFirst(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestInsertFirst');
  try
    lFixture.SetUp;
    try lFixture.TestInsertFirst; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestInsertMiddle(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestInsertMiddle');
  try
    lFixture.SetUp;
    try lFixture.TestInsertMiddle; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestDelete(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestDelete');
  try
    lFixture.SetUp;
    try lFixture.TestDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestClear(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestClear');
  try
    lFixture.SetUp;
    try lFixture.TestClear; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestIndexOf(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestIndexOf');
  try
    lFixture.SetUp;
    try lFixture.TestIndexOf; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestExchange(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestExchange');
  try
    lFixture.SetUp;
    try lFixture.TestExchange; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestAccesIndexOutOfBounds(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestAccesIndexOutOfBounds');
  try
    lFixture.SetUp;
    try lFixture.TestAccesIndexOutOfBounds; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestDeleteIndexOutOfBounds(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestDeleteIndexOutOfBounds');
  try
    lFixture.SetUp;
    try lFixture.TestDeleteIndexOutOfBounds; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestExchangeIndexOutOfBounds(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestExchangeIndexOutOfBounds');
  try
    lFixture.SetUp;
    try lFixture.TestExchangeIndexOutOfBounds; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestSort(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestSort');
  try
    lFixture.SetUp;
    try lFixture.TestSort; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestSorted(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestSorted');
  try
    lFixture.SetUp;
    try lFixture.TestSorted; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestSortedAdd(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestSortedAdd');
  try
    lFixture.SetUp;
    try lFixture.TestSortedAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestSortedAddAll(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestSortedAddAll');
  try
    lFixture.SetUp;
    try lFixture.TestSortedAddAll; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestSortedDupError(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestSortedDupError');
  try
    lFixture.SetUp;
    try lFixture.TestSortedDupError; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestSortedAddDuplicate(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestSortedAddDuplicate');
  try
    lFixture.SetUp;
    try lFixture.TestSortedAddDuplicate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestSortedIndexOf(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestSortedIndexOf');
  try
    lFixture.SetUp;
    try lFixture.TestSortedIndexOf; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestChange(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestChange');
  try
    lFixture.SetUp;
    try lFixture.TestChange; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestChangeAgain(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestChangeAgain');
  try
    lFixture.SetUp;
    try lFixture.TestChangeAgain; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestChangeCount(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestChangeCount');
  try
    lFixture.SetUp;
    try lFixture.TestChangeCount; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestChangeClear(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestChangeClear');
  try
    lFixture.SetUp;
    try lFixture.TestChangeClear; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestSetText(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestSetText');
  try
    lFixture.SetUp;
    try lFixture.TestSetText; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestSetTextEOL(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestSetTextEOL');
  try
    lFixture.SetUp;
    try lFixture.TestSetTextEOL; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestSetTextEmpty(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestSetTextEmpty');
  try
    lFixture.SetUp;
    try lFixture.TestSetTextEmpty; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTStringListTestSetTextEOLEmpty(AContext: TNXTestContext);
var lFixture: TTestTStringList;
begin
  lFixture:=TTestTStringList.Create(AContext, 'TestSetTextEOLEmpty');
  try
    lFixture.SetUp;
    try lFixture.TestSetTextEOLEmpty; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertcstringlistTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tcstringlist.TTestTStringList');
  lSuite.AddTest('TestCreate', @RunTTestTStringListTestCreate);
  lSuite.AddTest('TestAdd', @RunTTestTStringListTestAdd);
  lSuite.AddTest('TestAddIndex', @RunTTestTStringListTestAddIndex);
  lSuite.AddTest('TestAdd2', @RunTTestTStringListTestAdd2);
  lSuite.AddTest('TestInsertFirst', @RunTTestTStringListTestInsertFirst);
  lSuite.AddTest('TestInsertMiddle', @RunTTestTStringListTestInsertMiddle);
  lSuite.AddTest('TestDelete', @RunTTestTStringListTestDelete);
  lSuite.AddTest('TestClear', @RunTTestTStringListTestClear);
  lSuite.AddTest('TestIndexOf', @RunTTestTStringListTestIndexOf);
  lSuite.AddTest('TestExchange', @RunTTestTStringListTestExchange);
  lSuite.AddTest('TestAccesIndexOutOfBounds', @RunTTestTStringListTestAccesIndexOutOfBounds);
  lSuite.AddTest('TestDeleteIndexOutOfBounds', @RunTTestTStringListTestDeleteIndexOutOfBounds);
  lSuite.AddTest('TestExchangeIndexOutOfBounds', @RunTTestTStringListTestExchangeIndexOutOfBounds);
  lSuite.AddTest('TestSort', @RunTTestTStringListTestSort);
  lSuite.AddTest('TestSorted', @RunTTestTStringListTestSorted);
  lSuite.AddTest('TestSortedAdd', @RunTTestTStringListTestSortedAdd);
  lSuite.AddTest('TestSortedAddAll', @RunTTestTStringListTestSortedAddAll);
  lSuite.AddTest('TestSortedDupError', @RunTTestTStringListTestSortedDupError);
  lSuite.AddTest('TestSortedAddDuplicate', @RunTTestTStringListTestSortedAddDuplicate);
  lSuite.AddTest('TestSortedIndexOf', @RunTTestTStringListTestSortedIndexOf);
  lSuite.AddTest('TestChange', @RunTTestTStringListTestChange);
  lSuite.AddTest('TestChangeAgain', @RunTTestTStringListTestChangeAgain);
  lSuite.AddTest('TestChangeCount', @RunTTestTStringListTestChangeCount);
  lSuite.AddTest('TestChangeClear', @RunTTestTStringListTestChangeClear);
  lSuite.AddTest('TestSetText', @RunTTestTStringListTestSetText);
  lSuite.AddTest('TestSetTextEOL', @RunTTestTStringListTestSetTextEOL);
  lSuite.AddTest('TestSetTextEmpty', @RunTTestTStringListTestSetTextEmpty);
  lSuite.AddTest('TestSetTextEOLEmpty', @RunTTestTStringListTestSetTextEOLEmpty);
end;

end.
