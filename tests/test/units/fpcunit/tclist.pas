unit tclist;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils;

type

  { TTestTList }


  TTestTList= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  private

    procedure DeleteNegativeIndex;
    procedure DeleteTooBigIndex;
    procedure ExchangeNegativeIndex1;
    procedure ExchangeNegativeIndex2;
    procedure ExchangeTooBigIndex1;
    procedure ExchangeTooBigIndex2;
    procedure AccessNegativeIndex;
    procedure AccessTooBigIndex;
    procedure Shuffle;
  protected
    List : TList;
    List2 : TList;
    List3 : TList;
    Pointers : Packed Array[0..20] of Byte;
    procedure SetUp; virtual;
    procedure TearDown; virtual;
    Procedure FillList(ACount : Integer); overload;
    Procedure FillList(AList : TList; AOffSet, ACount : Integer); overload;
    procedure HavePointer(I: Integer);
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
    procedure TestExtractCount;
    procedure TestExtractResult;
    procedure TestExtractNonExisting;
    procedure TestExtractNonExistingResult;
    procedure TestExtractOnlyFirst;
    Procedure TestNotifyAdd;
    Procedure TestNotifyDelete;
    Procedure TestNotifyExtract;
    Procedure TestPack;
    Procedure TestAssignCopy;
    Procedure TestAssignCopy2;
    Procedure TestAssignAnd;
    procedure TestAssignAnd2;
    Procedure TestAssignOr;
    procedure TestAssignOr2;
    procedure TestAssignXOr;
    procedure TestAssignXOr2;
    procedure TestAssignSrcUnique;
    procedure TestAssignSrcUnique2;
    procedure TestAssignDestUnique;
    procedure TestAssignDestUnique2;
  end;

  { TMyList }

  TMyList = Class(TList)
    FLastPointer : Pointer;
    FLastAction : TListNotification;
    procedure Notify(Ptr: Pointer; Action: TListNotification); override;
  end;


procedure RegistertclistTests(ARegistry: TNXTestRegistry);

implementation



procedure TTestTList.SetUp;

Var
  I : Integer;

begin
  List:=TMyList.Create;
  List2:=TMyList.Create;
  List3:=TMyList.Create;
  For I:=0 to 20 do
    Pointers[i]:=I; // Zero serves as sentinel.
end;

procedure TTestTList.TearDown;
begin
  FreeAndNil(List);
  FreeAndNil(List2);
  FreeAndNil(List3);
end;

procedure TTestTList.FillList(ACount: Integer);


begin
  FillList(List,0,ACount);
end;

procedure TTestTList.FillList(AList: TList; AOffSet, ACount: Integer);

Var
  I : integer;

begin
  If ACount+AOffSet>20 then
    TestContext.Fail('Too many elements added to list. Max is 20');
  For I:=1+AOffSet to AOffSet+ACount do
    AList.Add(@Pointers[i]);
end;

procedure TTestTList.TestCreate;
begin
  TestContext.AssertTrue((0)=(List.Count), 'Empty list has count 0');
end;



procedure TTestTList.TestAdd;

begin
  FillList(1);
  TestContext.AssertTrue((1)=(List.Count), 'Add 1 element, count is 1');
  TestContext.AssertTrue((@Pointers[1])=(List[0]), 'Add 1 element, last element is Ptrint(1)');
end;

procedure TTestTList.TestAddIndex;

begin
  TestContext.AssertTrue((0)=(List.Add(Nil)), 'Add first element at index 0');
  TestContext.AssertTrue((1)=(List.Add(Nil)), 'Add second element, at index 1');
end;

procedure TTestTList.TestAdd2;

begin
  FillList(2);
  TestContext.AssertTrue((2)=(List.Count), 'Add 2 elements, count is 2');
  TestContext.AssertTrue((@Pointers[1])=(List[0]), 'Add 2 elements, first element is Pointers[1]');
  TestContext.AssertTrue((@Pointers[2])=(List[1]), 'Add 2 elements, second element is Pointers[2]');
end;

procedure TTestTList.TestInsertFirst;
begin
  FillList(3);
  List.Insert(0,@Pointers[0]);
  TestContext.AssertTrue((4)=(List.Count), 'Insert 1 in 3, count is 4');
  TestContext.AssertTrue((@Pointers[0])=(List[0]), 'Insert 1 in 3, first is inserted');
  TestContext.AssertTrue((@Pointers[1])=(List[1]), 'Insert 1 in 3, second is old first');
end;

procedure TTestTList.TestInsertMiddle;
begin
  FillList(3);
  List.Insert(1,@Pointers[0]);
  TestContext.AssertTrue((4)=(List.Count), 'Insert 1 in 3, count is 4');
  TestContext.AssertTrue((@Pointers[0])=(List[1]), 'Insert 1 in 3, 1 is inserted');
  TestContext.AssertTrue((@Pointers[2])=(List[2]), 'Insert 1 in 3, 2 is old 2');
  TestContext.AssertTrue((@Pointers[1])=(List[0]), 'Insert 1 in 3, 0 is untouched');
end;

procedure TTestTList.TestClear;
begin
  FillList(3);
  List.Clear;
  TestContext.AssertTrue((0)=(List.Count), 'Clear: count is 0');
end;

procedure TTestTList.TestIndexOf;
begin
  FillList(11);
  TestContext.AssertTrue((2)=(List.IndexOf(@Pointers[3])), 'Find third element');
end;

procedure TTestTList.TestDelete;

begin
  FillList(3);
  List.Delete(1);
  TestContext.AssertTrue((2)=(List.Count), 'Delete 1 from 3, count is 2');
  TestContext.AssertTrue((@Pointers[1])=(List[0]), 'Delete 1 from 3, first is pointers[1]');
  TestContext.AssertTrue((@Pointers[3])=(List[1]), 'Delete 1 from 3, second is "pointers[3]');
end;

procedure TTestTList.TestExchange;

begin
  FillList(3);
  List.Exchange(0,2);
  TestContext.AssertTrue((3)=(List.Count), 'Exchange 0 and 2, count is 3');
  TestContext.AssertTrue((@Pointers[3])=(List[0]), 'Exchange 0 and 2, first is Pointers[3]');
  TestContext.AssertTrue((@Pointers[2])=(List[1]), 'Exchange 0 and 2, second is Pointers[2]');
  TestContext.AssertTrue((@Pointers[1])=(List[2]), 'Exchange 0 and 2, third is Pointers[1]');
end;

procedure TTestTList.DeleteNegativeIndex;
begin
  List.Delete(-1);
end;

procedure TTestTList.DeleteTooBigIndex;
begin
  List.Delete(3);
end;

procedure TTestTList.ExchangeNegativeIndex1;
begin
  List.Exchange(-1,2);
end;

procedure TTestTList.ExchangeTooBigIndex1;
begin
  List.Exchange(3,2);
end;

procedure TTestTList.ExchangeNegativeIndex2;
begin
  List.Exchange(2,-1);

end;

procedure TTestTList.ExchangeTooBigIndex2;
begin
  List.Exchange(2,3);
end;

procedure TTestTList.AccessNegativeIndex;

begin
  List[-1];
end;

procedure TTestTList.AccessTooBigIndex;

begin
  List[3];
end;

procedure TTestTList.Shuffle;

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

procedure TTestTList.TestAccesIndexOutOfBounds;
begin
  FillList(3);
  TestContext.AssertRaises(EListError, @AccessNegativeIndex, 'Access Negative Index');
  TestContext.AssertRaises(EListError, @AccessTooBigIndex, 'Access Index too big');
end;

procedure TTestTList.TestDeleteIndexOutOfBounds;
begin
  FillList(3);
  TestContext.AssertRaises(EListError, @DeleteNegativeIndex, 'Delete Negative Index');
  TestContext.AssertRaises(EListError, @DeleteTooBigIndex, 'Delete Index too big');
end;

procedure TTestTList.TestExchangeIndexOutOfBounds;
begin
  FillList(3);
  TestContext.AssertRaises(EListError, @ExchangeNegativeIndex1, 'Exchange Negative first index');
  TestContext.AssertRaises(EListError, @ExchangeNegativeIndex2, 'Exchange Negative second index');
  TestContext.AssertRaises(EListError, @ExchangeTooBigIndex1, 'Exchange first Index too big');
  TestContext.AssertRaises(EListError, @ExchangeTooBigIndex2, 'Exchange second Index too big');
end;

Function CompareBytePointers(P1,P2 : Pointer) : Integer;

begin
  Result:=PByte(P1)^-PByte(P2)^;
end;

procedure TTestTList.TestSort;

Var
  I : Integer;

begin
  FillList(9);
  Shuffle;
  List.Sort(@CompareBytePointers);
  For I:=0 to List.Count-1 do
    If (List[i]<>@Pointers[i+1]) then
      TestContext.Fail(Format('Item at position %d is out of place (%d)',[I,PByte(List[i])^]));
end;

procedure TTestTList.TestExtractResult;
begin
  FillList(9);
  TestContext.AssertTrue((@Pointers[4])=(List.Extract(@Pointers[4])), 'Extracting pointers[4]');
end;

procedure TTestTList.TestExtractCount;
begin
  FillList(9);
  List.Extract(@Pointers[4]);
  TestContext.AssertTrue((8)=(List.Count), 'Extracting pointers[4], count is 8');
end;

procedure TTestTList.TestExtractNonExisting;
begin
  FillList(9);
  List.Extract(@List);
  TestContext.AssertTrue((9)=(List.Count), 'Extracting unexisting, count remains 9');
end;

procedure TTestTList.TestExtractNonExistingResult;
begin
  FillList(9);
  TestContext.AssertTrue((Nil)=(List.Extract(@List)), 'Extracting unexisting, result is nil');
end;

procedure TTestTList.TestExtractOnlyFirst;
begin
  FillList(9);
  List.Insert(0,@Pointers[4]);
  List.Extract(@Pointers[4]);
  TestContext.AssertTrue((3)=(List.IndexOf(@Pointers[4])), 'Extracting pointers[4], result is nil');
end;

procedure TTestTList.TestNotifyAdd;
begin
  List.Add(@Pointers[1]);
  TestContext.AssertTrue((@Pointers[1])=(TMyList(List).FLastPointer), 'Add notification, pointer is pointer[1]');
  TestContext.AssertTrue((ord(lnAdded))=(Ord(TMyList(List).FLastAction)), 'Add notification, action is lnAdded');
end;

procedure TTestTList.TestNotifyDelete;
begin
  FillList(9);
  List.Delete(3);
  TestContext.AssertTrue((@Pointers[4])=(TMyList(List).FLastPointer), 'Delete notification, pointer is pointer[4]');
  TestContext.AssertTrue((ord(lnDeleted))=(Ord(TMyList(List).FLastAction)), 'Delete notification, action is lnDeleted');
end;

procedure TTestTList.TestNotifyExtract;
begin
  FillList(9);
  List.Extract(@Pointers[4]);
  TestContext.AssertTrue((@Pointers[4])=(TMyList(List).FLastPointer), 'Extract notification, pointer is pointer[4]');
  TestContext.AssertTrue((ord(lnExtracted))=(Ord(TMyList(List).FLastAction)), 'Extract notification, action is lnExtracted');
end;

procedure TTestTList.TestPack;

Var
  I : integer;

begin
  FillList(9);
  List[3]:=Nil;
  List[6]:=Nil;
  List.Pack;
  TestContext.AssertTrue((7)=(List.Count), 'Pack, count is 7');
  For I:=0 to List.Count-1 do
    If (List[i]=Nil) then
      TestContext.Fail(Format('Packed list contains nil pointer at position %d',[i]));
  TestContext.AssertTrue((@Pointers[5])=(List[3]), 'Packed list[3] is @pointer[5]');
  TestContext.AssertTrue((@pointers[9])=(List[6]), 'Packed list[6] is @pointer[9]');
end;

procedure TTestTList.TestAssignCopy;

Var
  I : Integer;
begin
  FillList(20);
  List2.Assign(List,laCopy);
  TestContext.AssertTrue((20)=(List2.Count), '20 elements copied');
  For I:=0 to 19 do
    TestContext.AssertTrue((@Pointers[I+1])=(List2[i]), Format('Element %d copied correctly',[i]));
end;

procedure TTestTList.TestAssignAnd;

Var
  I : Integer;
begin
  FillList(10); // 1--10
  FillList(List2,5,10); // 6--15
  List.Assign(List2,laAnd); // Should have 6-10
  TestContext.AssertTrue((5)=(List.Count), '5 elements copied');
  For I:=0 to 4 do
    HavePointer(6+i);
end;

procedure TTestTList.TestAssignAnd2;

Var
  I : Integer;
begin
  FillList(10); // 1--10
  FillList(List2,5,10); // 6--15
  FillList(List3,10,9); // 11--19
  List.Assign(List2,laAnd,List3); // Should have 11-15
  TestContext.AssertTrue((5)=(List.Count), '5 elements copied');
  For I:=0 to 4 do
    HavePointer(11+i);
end;

procedure TTestTList.TestAssignOr;

Var
  I : Integer;
begin
  FillList(10); // 1--10
  FillList(List2,5,10); // 6--15
  List.Assign(List2,laOr); // Should have 6-10
  TestContext.AssertTrue((15)=(List.Count), '15 elements copied');
  For I:=0 to 14 do
    HavePointer(1+i);
end;

procedure TTestTList.TestAssignOr2;

Var
  I : Integer;
begin
  FillList(10); // 1--10
  FillList(List2,5,10); // 6--15
  FillList(List3,10,9); // 11--19
  List.Assign(List2,laOr,List3); // Should have 6-19
  TestContext.AssertTrue((14)=(List.Count), '14 elements copied');
  For I:=0 to 13 do
    HavePointer(6+i);
end;

procedure TTestTList.TestAssignXOr;

Var
  I : Integer;
begin
  FillList(10); // 1--10
  FillList(List2,5,10); // 6--15
  List.Assign(List2,laxOr); // Should have 1-5 and 11-15
  TestContext.AssertTrue((10)=(List.Count), '10 elements copied');
  For I:=0 to 4 do
    HavePointer(1+i);
  For I:=5 to 9 do
    HavePointer(6+i);
end;

procedure TTestTList.TestAssignXOr2;

Var
  I : Integer;
begin
  FillList(10); // 1--10
  FillList(List2,5,10); // 6--15
  FillList(List3,10,9); // 11--19
  List.Assign(List2,laXor,List3); // Should have 6-10 and 16-19
  TestContext.AssertTrue((9)=(List.Count), '14 elements copied');
  For I:=0 to 4 do
    HavePointer(6+i);
  For I:=5 to 8 do
    HavePointer(11+i);
end;

procedure TTestTList.TestAssignSrcUnique;

Var
  I : Integer;
begin
  FillList(10); // 1--10
  FillList(List2,5,10); // 6--15
  List.Assign(List2,laSrcUnique); // Should have 1-5
  TestContext.AssertTrue((5)=(List.Count), '5 elements copied');
  For I:=0 to 4 do
    HavePointer(1+i);
end;

procedure TTestTList.TestAssignSrcUnique2;

Var
  I : Integer;
begin
  FillList(10); // 1--10
  FillList(List2,5,10); // 6--15
  FillList(List3,10,9); // 11--19
  List.Assign(List2,laSrcUnique,List3); // Should have 6-10
  TestContext.AssertTrue((5)=(List.Count), '5 elements copied');
  For I:=0 to 4 do
    HavePointer(6+i);
end;

procedure TTestTList.HavePointer(I : Integer);

begin
  If List.IndexOf(@Pointers[i])=-1 then
    TestContext.Fail(Format('Pointer to %d not in list',[i]));
end;
procedure TTestTList.TestAssignDestUnique;

Var
  I : Integer;
begin
  FillList(10); // 1--10
  FillList(List2,5,10); // 6--15
  List.Assign(List2,laDestUnique); // Should have 11-15
  TestContext.AssertTrue((5)=(List.Count), '5 elements copied');
  For I:=0 to 4 do
    HavePointer(11+I);
end;

procedure TTestTList.TestAssignDestUnique2;

Var
  I : Integer;
begin
  FillList(10); // 1--10
  FillList(List2,5,10); // 6--15
  FillList(List3,10,9); // 11--19
  List.Assign(List2,laDestUnique,List3); // Should have 16-19
  TestContext.AssertTrue((4)=(List.Count), '4 elements copied');
  For I:=0 to 3 do
    HavePointer(16+i);
end;

procedure TTestTList.TestAssignCopy2;
Var
  I : Integer;
begin
  FillList(6); // 1--6
  FillList(List2,6,6); // 7--12
  FillList(List3,12,6); // 13--18
  List.Assign(List2,laCopy,List3); // Should have 13-18
  TestContext.AssertTrue((6)=(List.Count), '6 elements copied');
  For I:=1 to 6 do
    HavePointer(12+i);
end;


{ TMyList }

procedure TMyList.Notify(Ptr: Pointer; Action: TListNotification);
begin
  inherited Notify(Ptr, Action);
  FLastAction:=Action;
  FLastPointer:=Ptr;
end;


constructor TTestTList.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestTListTestCreate(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestCreate');
  try
    lFixture.SetUp;
    try lFixture.TestCreate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAdd(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAddIndex(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAddIndex');
  try
    lFixture.SetUp;
    try lFixture.TestAddIndex; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAdd2(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAdd2');
  try
    lFixture.SetUp;
    try lFixture.TestAdd2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestInsertFirst(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestInsertFirst');
  try
    lFixture.SetUp;
    try lFixture.TestInsertFirst; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestInsertMiddle(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestInsertMiddle');
  try
    lFixture.SetUp;
    try lFixture.TestInsertMiddle; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestDelete(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestDelete');
  try
    lFixture.SetUp;
    try lFixture.TestDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestClear(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestClear');
  try
    lFixture.SetUp;
    try lFixture.TestClear; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestIndexOf(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestIndexOf');
  try
    lFixture.SetUp;
    try lFixture.TestIndexOf; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestExchange(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestExchange');
  try
    lFixture.SetUp;
    try lFixture.TestExchange; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAccesIndexOutOfBounds(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAccesIndexOutOfBounds');
  try
    lFixture.SetUp;
    try lFixture.TestAccesIndexOutOfBounds; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestDeleteIndexOutOfBounds(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestDeleteIndexOutOfBounds');
  try
    lFixture.SetUp;
    try lFixture.TestDeleteIndexOutOfBounds; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestExchangeIndexOutOfBounds(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestExchangeIndexOutOfBounds');
  try
    lFixture.SetUp;
    try lFixture.TestExchangeIndexOutOfBounds; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestSort(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestSort');
  try
    lFixture.SetUp;
    try lFixture.TestSort; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestExtractCount(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestExtractCount');
  try
    lFixture.SetUp;
    try lFixture.TestExtractCount; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestExtractResult(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestExtractResult');
  try
    lFixture.SetUp;
    try lFixture.TestExtractResult; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestExtractNonExisting(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestExtractNonExisting');
  try
    lFixture.SetUp;
    try lFixture.TestExtractNonExisting; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestExtractNonExistingResult(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestExtractNonExistingResult');
  try
    lFixture.SetUp;
    try lFixture.TestExtractNonExistingResult; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestExtractOnlyFirst(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestExtractOnlyFirst');
  try
    lFixture.SetUp;
    try lFixture.TestExtractOnlyFirst; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestNotifyAdd(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestNotifyAdd');
  try
    lFixture.SetUp;
    try lFixture.TestNotifyAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestNotifyDelete(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestNotifyDelete');
  try
    lFixture.SetUp;
    try lFixture.TestNotifyDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestNotifyExtract(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestNotifyExtract');
  try
    lFixture.SetUp;
    try lFixture.TestNotifyExtract; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestPack(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestPack');
  try
    lFixture.SetUp;
    try lFixture.TestPack; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignCopy(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignCopy');
  try
    lFixture.SetUp;
    try lFixture.TestAssignCopy; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignCopy2(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignCopy2');
  try
    lFixture.SetUp;
    try lFixture.TestAssignCopy2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignAnd(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignAnd');
  try
    lFixture.SetUp;
    try lFixture.TestAssignAnd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignAnd2(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignAnd2');
  try
    lFixture.SetUp;
    try lFixture.TestAssignAnd2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignOr(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignOr');
  try
    lFixture.SetUp;
    try lFixture.TestAssignOr; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignOr2(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignOr2');
  try
    lFixture.SetUp;
    try lFixture.TestAssignOr2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignXOr(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignXOr');
  try
    lFixture.SetUp;
    try lFixture.TestAssignXOr; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignXOr2(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignXOr2');
  try
    lFixture.SetUp;
    try lFixture.TestAssignXOr2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignSrcUnique(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignSrcUnique');
  try
    lFixture.SetUp;
    try lFixture.TestAssignSrcUnique; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignSrcUnique2(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignSrcUnique2');
  try
    lFixture.SetUp;
    try lFixture.TestAssignSrcUnique2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignDestUnique(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignDestUnique');
  try
    lFixture.SetUp;
    try lFixture.TestAssignDestUnique; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestTListTestAssignDestUnique2(AContext: TNXTestContext);
var lFixture: TTestTList;
begin
  lFixture:=TTestTList.Create(AContext, 'TestAssignDestUnique2');
  try
    lFixture.SetUp;
    try lFixture.TestAssignDestUnique2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertclistTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tclist.TTestTList');
  lSuite.AddTest('TestCreate', @RunTTestTListTestCreate);
  lSuite.AddTest('TestAdd', @RunTTestTListTestAdd);
  lSuite.AddTest('TestAddIndex', @RunTTestTListTestAddIndex);
  lSuite.AddTest('TestAdd2', @RunTTestTListTestAdd2);
  lSuite.AddTest('TestInsertFirst', @RunTTestTListTestInsertFirst);
  lSuite.AddTest('TestInsertMiddle', @RunTTestTListTestInsertMiddle);
  lSuite.AddTest('TestDelete', @RunTTestTListTestDelete);
  lSuite.AddTest('TestClear', @RunTTestTListTestClear);
  lSuite.AddTest('TestIndexOf', @RunTTestTListTestIndexOf);
  lSuite.AddTest('TestExchange', @RunTTestTListTestExchange);
  lSuite.AddTest('TestAccesIndexOutOfBounds', @RunTTestTListTestAccesIndexOutOfBounds);
  lSuite.AddTest('TestDeleteIndexOutOfBounds', @RunTTestTListTestDeleteIndexOutOfBounds);
  lSuite.AddTest('TestExchangeIndexOutOfBounds', @RunTTestTListTestExchangeIndexOutOfBounds);
  lSuite.AddTest('TestSort', @RunTTestTListTestSort);
  lSuite.AddTest('TestExtractCount', @RunTTestTListTestExtractCount);
  lSuite.AddTest('TestExtractResult', @RunTTestTListTestExtractResult);
  lSuite.AddTest('TestExtractNonExisting', @RunTTestTListTestExtractNonExisting);
  lSuite.AddTest('TestExtractNonExistingResult', @RunTTestTListTestExtractNonExistingResult);
  lSuite.AddTest('TestExtractOnlyFirst', @RunTTestTListTestExtractOnlyFirst);
  lSuite.AddTest('TestNotifyAdd', @RunTTestTListTestNotifyAdd);
  lSuite.AddTest('TestNotifyDelete', @RunTTestTListTestNotifyDelete);
  lSuite.AddTest('TestNotifyExtract', @RunTTestTListTestNotifyExtract);
  lSuite.AddTest('TestPack', @RunTTestTListTestPack);
  lSuite.AddTest('TestAssignCopy', @RunTTestTListTestAssignCopy);
  lSuite.AddTest('TestAssignCopy2', @RunTTestTListTestAssignCopy2);
  lSuite.AddTest('TestAssignAnd', @RunTTestTListTestAssignAnd);
  lSuite.AddTest('TestAssignAnd2', @RunTTestTListTestAssignAnd2);
  lSuite.AddTest('TestAssignOr', @RunTTestTListTestAssignOr);
  lSuite.AddTest('TestAssignOr2', @RunTTestTListTestAssignOr2);
  lSuite.AddTest('TestAssignXOr', @RunTTestTListTestAssignXOr);
  lSuite.AddTest('TestAssignXOr2', @RunTTestTListTestAssignXOr2);
  lSuite.AddTest('TestAssignSrcUnique', @RunTTestTListTestAssignSrcUnique);
  lSuite.AddTest('TestAssignSrcUnique2', @RunTTestTListTestAssignSrcUnique2);
  lSuite.AddTest('TestAssignDestUnique', @RunTTestTListTestAssignDestUnique);
  lSuite.AddTest('TestAssignDestUnique2', @RunTTestTListTestAssignDestUnique2);
end;

end.
