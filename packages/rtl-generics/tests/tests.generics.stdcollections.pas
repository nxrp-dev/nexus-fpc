{
    This file is part of the Free Pascal/NewPascal run time library.
    Copyright (c) 2018 by Maciej Izak (hnb),
    member of the NewPascal development team (http://newpascal.org)

    Copyright(c) 2004-2018 DaThoX

    It contains tests for the Free Pascal generics library

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

    Acknowledgment

    Thanks to Sphere 10 Software (http://sphere10.com) for sponsoring
    many new types, tests and major refactoring of entire library

    Thanks to Castle Game Engine (https://castle-engine.sourceforge.io)
    Part of tests for this module was copied from Castle Game Engine tests

 **********************************************************************}

unit tests.generics.stdcollections;

{$mode delphi}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, tests.generics.utils,
  Classes, SysUtils, Generics.Collections, Generics.Defaults;

type
  TTestStdCollections = class(TTestCollections)
  private
    procedure Test_TList_Notification(AList: TList<string>); overload;
  public
    // Tests from Castle Game Engine
    procedure Test_List;
    procedure Test_FreeingManually;
    procedure Test_AddingLists;
    procedure Test_Sort;
    procedure Test_Pack;
    procedure Test_RecordsList;
    procedure Test_VectorsList;
    procedure Test_MethodsList;

    // My (c) tests
    procedure Test_SortedList;
    procedure Test_Queue;
    procedure Test_GenericListBox;

    procedure Test_TList_Notification; overload;
    procedure Test_TSortedList_Notification;
    procedure Test_TQueue_Notification;
    procedure Test_TStack_Notification;
    procedure Test_TObjectList_Notification;
    procedure Test_TObjectQueue_Notification;
    procedure Test_TObjectStack_Notification;

    procedure Test_TrimExcess;
  end;

  TGenericListBox<T> = class
  private class var
    F : TList<TComponentClass>;
    class procedure Test(AContext: TNXTestContext);
  end;

procedure RegistertestsgenericsstdcollectionsTests(ARegistry: TNXTestRegistry);

implementation

class procedure TGenericListBox<T>.Test(AContext: TNXTestContext);
begin
  F := TList<TComponentClass>.Create;
  F.Add(TDataModule);
  F.Add(nil);
  with TList<TComponentClass>.Create(F) do
  begin
    AContext.AssertTrue(Count = 2);
    AContext.AssertTrue(F[0] = Items[0]);
    AContext.AssertTrue(F[1] = Items[1]);
    AContext.AssertTrue(F[0] = TDataModule);
    AContext.AssertTrue(F[1] = nil);
    Free;
  end;
  F.Free;
end;

type
  TApple = class
    Name: string;
  end;

type
  TAppleList = class(TObjectList<TApple>)
    procedure Pack;
  end;

procedure TAppleList.Pack;
begin
  while Remove(nil) <> -1 do ;
end;

procedure TTestStdCollections.Test_List;
var
  A: TApple;
  Apples: TAppleList;
begin
  Apples := TAppleList.Create(true);
  try
    A := TApple.Create;
    Apples.Add(A);
    Apples.Add(TApple.Create);
    A := TApple.Create;
    Apples.Add(A);

    TestContext.AssertTrue((3)=(Apples.Count), '');
    TestContext.AssertTrue((2)=(Apples.IndexOf(A)), '');

    Apples.Delete(0);

    TestContext.AssertTrue((2)=(Apples.Count), '');
    TestContext.AssertTrue((1)=(Apples.IndexOf(A)), '');

    Apples.Remove(A);

    TestContext.AssertTrue((1)=(Apples.Count), '');

    Apples.Delete(0);

    TestContext.AssertTrue((0)=(Apples.Count), '');
  finally FreeAndNil(Apples) end;
end;

procedure TTestStdCollections.Test_FreeingManually;
var
  A: TApple;
  Apples: TAppleList;
begin
  Apples := TAppleList.Create(false);
  try
    A := TApple.Create;
    Apples.Add(A);
    Apples.Add(A);
    Apples.Add(TApple.Create);

    { This freeing would be invalid on a list that owns children,
      as we free something twice, and we leave some invalid references
      (to already freed items) in the list at various stages.
      But it should be OK with list that has OwnsChildren = false. }

    Apples[0].Free;
    Apples[0] := nil;
    Apples[1] := nil;
    Apples[2].Free;
  finally FreeAndNil(Apples) end;
end;

procedure TTestStdCollections.Test_AddingLists;
var
  A: TApple;
  Apples, Apples2: TAppleList;
begin
  Apples := TAppleList.Create(true);
  try
    A := TApple.Create;
    A.Name := 'One';
    Apples.Add(A);

    A := TApple.Create;
    A.Name := 'Two';
    Apples.Add(A);

    Apples2 := TAppleList.Create(false);
    try
      Apples2.AddRange(Apples);
      Apples2.AddRange(Apples);
      Apples2.AddRange(Apples);
      TestContext.AssertTrue((6)=(Apples2.Count), '');
      TestContext.AssertTrue(('One')=(Apples2[0].Name), '');
      TestContext.AssertTrue(('Two')=(Apples2[1].Name), '');
      TestContext.AssertTrue(('One')=(Apples2[2].Name), '');
      TestContext.AssertTrue(('Two')=(Apples2[3].Name), '');
      TestContext.AssertTrue(('One')=(Apples2[4].Name), '');
      TestContext.AssertTrue(('Two')=(Apples2[5].Name), '');
    finally FreeAndNil(Apples2) end;
  finally FreeAndNil(Apples) end;
end;

function CompareApples(const Left, Right: TApple): Integer;
begin
  Result := AnsiCompareStr(Left.Name, Right.Name);
end;

procedure TTestStdCollections.Test_Sort;
type
  TAppleComparer = TComparer<TApple>;
var
  A: TApple;
  L: TAppleList;
begin
  L := TAppleList.Create(true);
  try
    A := TApple.Create;
    A.Name := '11';
    L.Add(A);

    A := TApple.Create;
    A.Name := '33';
    L.Add(A);

    A := TApple.Create;
    A.Name := '22';
    L.Add(A);

    L.Sort(TAppleComparer.Construct(@CompareApples));

    TestContext.AssertTrue((3)=(L.Count), '');
    TestContext.AssertTrue(('11')=(L[0].Name), '');
    TestContext.AssertTrue(('22')=(L[1].Name), '');
    TestContext.AssertTrue(('33')=(L[2].Name), '');
  finally FreeAndNil(L) end;
end;

procedure TTestStdCollections.Test_Pack;
var
  A: TApple;
  L: TAppleList;
begin
  L := TAppleList.Create(true);
  try
    L.Add(nil);

    A := TApple.Create;
    A.Name := '11';
    L.Add(A);

    L.Add(nil);

    A := TApple.Create;
    A.Name := '33';
    L.Add(A);

    A := TApple.Create;
    A.Name := '22';
    L.Add(A);

    L.Add(nil);
    L.Add(nil);

    L.Pack;

    TestContext.AssertTrue((3)=(L.Count), '');
    TestContext.AssertTrue(('11')=(L[0].Name), '');
    TestContext.AssertTrue(('33')=(L[1].Name), '');
    TestContext.AssertTrue(('22')=(L[2].Name), '');
  finally FreeAndNil(L) end;
end;

procedure TTestStdCollections.Test_RecordsList;
type
  TMyRecord = packed record
    A, B: Integer;
  end;
  TMyRecordList = TList<TMyRecord>;
var
  List: TMyRecordList;
  R1, R2, R: TMyRecord;
begin
  List := TMyRecordList.Create;
  try
    R1.A := 11;
    R1.B := 22;
    List.Add(R1);

    R2.A := 33;
    R2.B := 44;
    List.Add(R2);

    R2.A := 33;
    R2.B := 44;
    List.Add(R2);

    TestContext.AssertTrue((3)=(List.Count), '');
    TestContext.AssertTrue((11)=(List[0].A), '');
    TestContext.AssertTrue((22)=(List[0].B), '');
    TestContext.AssertTrue((33)=(List[1].A), '');
    TestContext.AssertTrue((44)=(List[1].B), '');
    TestContext.AssertTrue((33)=(List[2].A), '');
    TestContext.AssertTrue((44)=(List[2].B), '');

    List.Delete(2);

    TestContext.AssertTrue((2)=(List.Count), '');
    TestContext.AssertTrue((11)=(List[0].A), '');
    TestContext.AssertTrue((22)=(List[0].B), '');
    TestContext.AssertTrue((33)=(List[1].A), '');
    TestContext.AssertTrue((44)=(List[1].B), '');

    TestContext.AssertTrue((0)=(List.IndexOf(R1)), '');
    TestContext.AssertTrue((1)=(List.IndexOf(R2)), '');

    // change R1 and R2, to make sure it doesn't matter for tests
    R1.A := 111111;
    R1.B := 222222;
    R2.A := 333333;
    R2.B := 444444;
    TestContext.AssertTrue((-1)=(List.IndexOf(R1)), '');
    TestContext.AssertTrue((-1)=(List.IndexOf(R2)), '');

    R.A := 11;
    R.B := 22;
    TestContext.AssertTrue((0)=(List.IndexOf(R)), '');

    R.A := 33;
    R.B := 44;
    TestContext.AssertTrue((1)=(List.IndexOf(R)), '');

    R.A := 11;
    R.B := 22;
    List.Remove(R);
    TestContext.AssertTrue((1)=(List.Count), '');
    TestContext.AssertTrue((33)=(List[0].A), '');
    TestContext.AssertTrue((44)=(List[0].B), '');

    R.A := 666;
    R.B := 22;
    List.Remove(R); // does nothing, no such record
    TestContext.AssertTrue((1)=(List.Count), '');
    TestContext.AssertTrue((33)=(List[0].A), '');
    TestContext.AssertTrue((44)=(List[0].B), '');
  finally FreeAndNil(List) end;
end;

procedure TTestStdCollections.Test_VectorsList;
type
  TMyVector = packed array [0..1] of Single;
  TMyVectorList = TList<TMyVector>;
var
  List: TMyVectorList;
  R1, R2, R: TMyVector;
begin
  List := TMyVectorList.Create;
  try
    R1[0] := 11;
    R1[1] := 22;
    List.Add(R1);

    R2[0] := 33;
    R2[1] := 44;
    List.Add(R2);

    R2[0] := 33;
    R2[1] := 44;
    List.Add(R2);

    TestContext.AssertTrue((3)=(List.Count), '');
    TestContext.AssertTrue((11)=(List[0][0]), '');
    TestContext.AssertTrue((22)=(List[0][1]), '');
    TestContext.AssertTrue((33)=(List[1][0]), '');
    TestContext.AssertTrue((44)=(List[1][1]), '');
    TestContext.AssertTrue((33)=(List[2][0]), '');
    TestContext.AssertTrue((44)=(List[2][1]), '');

    List.Delete(2);

    TestContext.AssertTrue((2)=(List.Count), '');
    TestContext.AssertTrue((11)=(List[0][0]), '');
    TestContext.AssertTrue((22)=(List[0][1]), '');
    TestContext.AssertTrue((33)=(List[1][0]), '');
    TestContext.AssertTrue((44)=(List[1][1]), '');

    TestContext.AssertTrue((0)=(List.IndexOf(R1)), '');
    TestContext.AssertTrue((1)=(List.IndexOf(R2)), '');

    // change R1 and R2, to make sure it doesn't matter for tests
    R1[0] := 111111;
    R1[1] := 222222;
    R2[0] := 333333;
    R2[1] := 444444;
    TestContext.AssertTrue((-1)=(List.IndexOf(R1)), '');
    TestContext.AssertTrue((-1)=(List.IndexOf(R2)), '');

    R[0] := 11;
    R[1] := 22;
    TestContext.AssertTrue((0)=(List.IndexOf(R)), '');

    R[0] := 33;
    R[1] := 44;
    TestContext.AssertTrue((1)=(List.IndexOf(R)), '');

    R[0] := 11;
    R[1] := 22;
    List.Remove(R);
    TestContext.AssertTrue((1)=(List.Count), '');
    TestContext.AssertTrue((33)=(List[0][0]), '');
    TestContext.AssertTrue((44)=(List[0][1]), '');

    R[0] := 666;
    R[1] := 22;
    List.Remove(R); // does nothing, no such item
    TestContext.AssertTrue((1)=(List.Count), '');
    TestContext.AssertTrue((33)=(List[0][0]), '');
    TestContext.AssertTrue((44)=(List[0][1]), '');
  finally FreeAndNil(List) end;
end;

type
  TSomeClass = class
    procedure Foo(A: Integer);
  end;

procedure TSomeClass.Foo(A: Integer);
begin
end;

procedure TTestStdCollections.Test_MethodsList;
type
  TMyMethod = procedure (A: Integer) of object;
  TMyMethodList = TList<TMyMethod>;

  procedure AssertMethodsEqual(const M1, M2: TMyMethod);
  begin
    TestContext.AssertTrue(TMethod(M1).Code = TMethod(M2).Code, '');
    TestContext.AssertTrue(TMethod(M1).Data = TMethod(M2).Data, '');
  end;

var
  List: TMyMethodList;
  C1, C2, C3: TSomeClass;
  M: TMyMethod;
begin
  C1 := TSomeClass.Create;
  C2 := TSomeClass.Create;
  C3 := TSomeClass.Create;

  List := TMyMethodList.Create;
  try
    List.Add(C1.Foo);
    List.Add(C2.Foo);
    List.Add(C2.Foo);

    TestContext.AssertTrue((3)=(List.Count), '');
    M := C1.Foo;
    AssertMethodsEqual(List[0], M);
    M := C2.Foo;
    AssertMethodsEqual(List[1], M);
    AssertMethodsEqual(List[2], M);

    List.Delete(2);

    TestContext.AssertTrue((2)=(List.Count), '');
    M := C1.Foo;
    AssertMethodsEqual(List[0], M);
    M := C2.Foo;
    AssertMethodsEqual(List[1], M);

    TestContext.AssertTrue((0)=(List.IndexOf(C1.Foo)), '');
    TestContext.AssertTrue((1)=(List.IndexOf(C2.Foo)), '');

    TestContext.AssertTrue((-1)=(List.IndexOf(C3.Foo)), '');

    List.Remove(C1.Foo);
    TestContext.AssertTrue((1)=(List.Count), '');
    M := C2.Foo;
    AssertMethodsEqual(List[0], M);

    List.Remove(C3.Foo); // does nothing, no such item
    TestContext.AssertTrue((1)=(List.Count), '');
    M := C2.Foo;
    AssertMethodsEqual(List[0], M);
  finally FreeAndNil(List) end;

  C1.Free;
  C2.Free;
  C3.Free;
end;

procedure TTestStdCollections.Test_SortedList;
var
  LSortedList: TSortedList<Integer>;
  i: integer;
  LRandomOrder: TArray<Integer>;
begin
  LRandomOrder := TArray<Integer>.Create(
    10, 8, 17, 19, 2, 0, 13, 15, 5, 7, 12, 14, 4, 6, 11, 9, 16, 18, 3, 1);

  LSortedList := TSortedList<Integer>.Create;
  for i in LRandomOrder do
    LSortedList.Add(i);

  TestContext.AssertTrue((Length(LRandomOrder))=(LSortedList.Count), 'Wrong Count value for TSortedList');

  for i := 0 to 19 do
    TestContext.AssertTrue((i)=(LSortedList[i]), Format('Wrong item (%d) index (%d) in TSortedList',[LSortedList[i], i]));

  LSortedList.Free;
end;

procedure TTestStdCollections.Test_Queue;
const
  NUMBERS: array[0..2] of Integer = (3,4,5);
var
  LQueue: TQueue<Integer>;
  i: Integer;
  j: Integer;
  pi: Pinteger;
begin
  LQueue := TQueue<Integer>.Create;

  for i := 1 to 5 do
  begin
    LQueue.Enqueue(i);
    TestContext.AssertTrue((LQueue.Peek)=(1), '');
  end;

  TestContext.AssertTrue((LQueue.Dequeue)=(1), '');
  TestContext.AssertTrue((LQueue.Extract)=(2), '');

  j := 0;
  for i in LQueue do
  begin
    TestContext.AssertTrue((i)=(NUMBERS[j]), '');
    Inc(j);
  end;

  j := 0;
  for pi in LQueue.Ptr^ do
  begin
    TestContext.AssertTrue((pi^)=(NUMBERS[j]), '');
    Inc(j);
  end;

  LQueue.Free;
end;

procedure TTestStdCollections.Test_TList_Notification(AList: TList<string>);
var
  LStringsObj: TEnumerable<string>;
  LStringsIntf: IEnumerable<string>;
begin
  try
    LStringsObj := EnumerableStringsObj(['Ddd', 'Eee']);
    LStringsIntf := EnumerableStringsIntf(['Fff', 'Ggg']);
    AList.OnNotify := NotifyTestStr;

    { Add + AddRange }

    NotificationAdd(AList, ['Aaa', 'Bbb', 'Ccc', 'Ddd', 'Eee', 'Fff', 'Ggg'], cnAdded);
    AList.Add('Aaa');
    AList.AddRange(['Bbb', 'Ccc']);
    AList.AddRange(LStringsObj);
    AList.AddRange(LStringsIntf);
    AssertNotificationsExecutedStr;

    { Clear }

    NotificationAdd(AList, ['Aaa', 'Bbb', 'Ccc', 'Ddd', 'Eee', 'Fff', 'Ggg'], cnRemoved);
    AList.Clear;
    AssertNotificationsExecutedStr;

    { Insert + InsertRange }

    NotificationAdd(AList, ['Aaa', 'Bbb', 'Ccc', 'Ddd', 'Eee', 'Fff', 'Ggg'], cnAdded);
    AList.Insert(0, 'Aaa');
    AList.InsertRange(1, ['Bbb', 'Ccc']);
    AList.InsertRange(3, LStringsObj);
    AList.InsertRange(5, LStringsIntf);
    AssertNotificationsExecutedStr;

    { Remove + Delete + DeleteRange }

    NotificationAdd(AList, ['Aaa', 'Bbb', 'Ccc', 'Ddd', 'Eee', 'Fff', 'Ggg'], cnRemoved);
    AList.Remove('Aaa');
    AList.Delete(0);
    AList.DeleteRange(0, 5);
    TestContext.AssertTrue((AList.Count)=(0), '');
    AssertNotificationsExecutedStr;

    { ExtractIndex, Extract }

    NotificationAdd(AList, ['Aaa', 'Bbb', 'Ccc'], cnAdded);
    AList.AddRange(['Aaa', 'Bbb', 'Ccc']);
    AssertNotificationsExecutedStr;
    NotificationAdd(AList, ['Aaa', 'Bbb'], cnExtracted);
    TestContext.AssertTrue((AList.ExtractIndex(0))=('Aaa'), '');
    TestContext.AssertTrue((AList.Extract('Bbb'))=('Bbb'), '');
    AssertNotificationsExecutedStr;

    { SetItem }
    NotificationAdd(AList, 'Ccc', cnRemoved);
    NotificationAdd(AList, 'FPC', cnAdded);
    AList[0] := 'FPC';
    AssertNotificationsExecutedStr;

  finally
    LStringsObj.Free;
    { Free }
    NotificationAdd(AList, 'FPC', cnRemoved);
    AList.Free;
    AssertNotificationsExecutedStr;
  end;
end;

procedure TTestStdCollections.Test_TList_Notification;
begin
  Test_TList_Notification(TList<string>.Create);
end;

procedure TTestStdCollections.Test_TSortedList_Notification;
var
  LList: TSortedList<string>;
begin
  LList := TSortedList<string>.Create;
  LList.SortStyle := cssUser;
  Test_TList_Notification(LList);
end;

procedure TTestStdCollections.Test_TQueue_Notification;
var
  LQueue: TQueue<string>;
begin
  LQueue := TQueue<string>.Create();
  try
    LQueue.OnNotify := NotifyTestStr;

    { Enqueue }
    NotificationAdd(LQueue, ['Aaa', 'Bbb', 'Ccc', 'Ddd'], cnAdded);
    LQueue.Enqueue('Aaa');
    LQueue.Enqueue('Bbb');
    LQueue.Enqueue('Ccc');
    LQueue.Enqueue('Ddd');
    AssertNotificationsExecutedStr;

    { Dequeue }
    NotificationAdd(LQueue, 'Aaa', cnRemoved);
    TestContext.AssertTrue((LQueue.Dequeue)=('Aaa'), '');
    AssertNotificationsExecutedStr;

    { Extract }
    NotificationAdd(LQueue, 'Bbb', cnExtracted);
    TestContext.AssertTrue((LQueue.Extract)=('Bbb'), '');
    AssertNotificationsExecutedStr;

    { Clear }
    NotificationAdd(LQueue, ['Ccc', 'Ddd'], cnRemoved);
    LQueue.Clear;
    AssertNotificationsExecutedStr;

    { Enqueue }
    NotificationAdd(LQueue, ['FPC', 'Polandball'], cnAdded);
    LQueue.Enqueue('FPC');
    LQueue.Enqueue('Polandball');
    AssertNotificationsExecutedStr;
  finally
    NotificationAdd(LQueue, ['FPC', 'Polandball'], cnRemoved);
    LQueue.Free;
    AssertNotificationsExecutedStr;
  end;
end;

procedure TTestStdCollections.Test_TStack_Notification;
var
  LStack: TStack<string>;
begin
  LStack := TStack<string>.Create();
  try
    LStack.OnNotify := NotifyTestStr;

    { Push }
    NotificationAdd(LStack, ['Aaa', 'Bbb', 'Ccc', 'Ddd'], cnAdded);
    LStack.Push('Aaa');
    LStack.Push('Bbb');
    LStack.Push('Ccc');
    LStack.Push('Ddd');
    AssertNotificationsExecutedStr;

    { Pop }
    NotificationAdd(LStack, 'Ddd', cnRemoved);
    TestContext.AssertTrue((LStack.Pop)=('Ddd'), '');
    AssertNotificationsExecutedStr;

    { Extract }
    NotificationAdd(LStack, 'Ccc', cnExtracted);
    TestContext.AssertTrue((LStack.Extract)=('Ccc'), '');
    AssertNotificationsExecutedStr;

    { Clear }
    NotificationAdd(LStack, ['Bbb', 'Aaa'], cnRemoved);
    LStack.Clear;
    AssertNotificationsExecutedStr;

    { Push }
    NotificationAdd(LStack, ['FPC', 'Polandball'], cnAdded);
    LStack.Push('FPC');
    LStack.Push('Polandball');
    AssertNotificationsExecutedStr;
  finally
    NotificationAdd(LStack, ['Polandball', 'FPC'], cnRemoved);
    LStack.Free;
    AssertNotificationsExecutedStr;
  end;
end;

procedure TTestStdCollections.Test_TObjectList_Notification;
var
  LObj: TEnumerable<TObject>;
  LIntf: IEnumerable<TObject>;
  O: TArray<TObject>;
  LList: TObjectList<TObject>;
  i: Integer;
begin
  try
    CreateObjects(O, 8);

    LList := TObjectList<TObject>.Create(false);
    LList.OnNotify := NotifyTestObj;

    LObj := EnumerableObjectsObj([O[3], O[4]]);
    LIntf := EnumerableObjectsIntf([O[5], O[6]]);

    { Add + AddRange }

    NotificationAdd(LList, [O[0], O[1], O[2], O[3], O[4], O[5], O[6]], cnAdded);
    LList.Add(O[0]);
    LList.AddRange([O[1], O[2]]);
    LList.AddRange(LObj);
    LList.AddRange(LIntf);
    AssertNotificationsExecutedObj;

    { Clear }

    NotificationAdd(LList, [O[0], O[1], O[2], O[3], O[4], O[5], O[6]], cnRemoved);
    LList.Clear;
    AssertNotificationsExecutedObj;

    { Insert + InsertRange }

    NotificationAdd(LList, [O[0], O[1], O[2], O[3], O[4], O[5], O[6]], cnAdded);
    LList.Insert(0, O[0]);
    LList.InsertRange(1, [O[1], O[2]]);
    LList.InsertRange(3, LObj);
    LList.InsertRange(5, LIntf);
    AssertNotificationsExecutedObj;

    { Remove + Delete + DeleteRange }

    NotificationAdd(LList, [O[0], O[1], O[2], O[3], O[4], O[5], O[6]], cnRemoved);
    LList.Remove(O[0]);
    LList.Delete(0);
    LList.DeleteRange(0, 5);
    TestContext.AssertTrue((LList.Count)=(0), '');
    AssertNotificationsExecutedObj;

    { ExtractIndex, Extract }

    NotificationAdd(LList, [O[0], O[1], O[2]], cnAdded);
    LList.AddRange([O[0], O[1], O[2]]);
    AssertNotificationsExecutedObj;
    NotificationAdd(LList, [O[0], O[1]], cnExtracted);
    TestContext.AssertTrue(LList.ExtractIndex(0) = O[0], '');
    TestContext.AssertTrue(LList.Extract(O[1]) = O[1], '');
    AssertNotificationsExecutedObj;

    { SetItem }
    NotificationAdd(LList, O[2], cnRemoved);
    NotificationAdd(LList, O[7], cnAdded);
    LList[0] := O[7];
    AssertNotificationsExecutedObj;

  finally
    LObj.Free;
    { Free }
    NotificationAdd(LList, O[7], cnRemoved);
    FreeObjects(O);
    LList.Free;
    AssertNotificationsExecutedObj;
  end;
end;

procedure TTestStdCollections.Test_TObjectQueue_Notification;
var
  LQueue: TObjectQueue<TObject>;
  O: TArray<TObject>;
begin
  LQueue := TObjectQueue<TObject>.Create(false);
  try
    CreateObjects(O, 6);
    LQueue.OnNotify := NotifyTestObj;

    { Enqueue }
    NotificationAdd(LQueue, [O[0], O[1], O[2], O[3]], cnAdded);
    LQueue.Enqueue(O[0]);
    LQueue.Enqueue(O[1]);
    LQueue.Enqueue(O[2]);
    LQueue.Enqueue(O[3]);
    AssertNotificationsExecutedObj;

    { Dequeue }
    NotificationAdd(LQueue, O[0], cnRemoved);
    LQueue.Dequeue;
    AssertNotificationsExecutedObj;

    { Extract }
    NotificationAdd(LQueue, O[1], cnExtracted);
    TestContext.AssertTrue(LQueue.Extract = O[1], '');
    AssertNotificationsExecutedObj;

    { Clear }
    NotificationAdd(LQueue, [O[2], O[3]], cnRemoved);
    LQueue.Clear;
    AssertNotificationsExecutedObj;

    { Enqueue }
    NotificationAdd(LQueue, [O[4], O[5]], cnAdded);
    LQueue.Enqueue(O[4]);
    LQueue.Enqueue(O[5]);
    AssertNotificationsExecutedObj;
  finally
    NotificationAdd(LQueue, [O[4], O[5]], cnRemoved);
    FreeObjects(O);
    LQueue.Free;
    AssertNotificationsExecutedObj;
  end;
end;

procedure TTestStdCollections.Test_TObjectStack_Notification;
var
  LStack: TStack<TObject>;
  O: TArray<TObject>;
begin
  LStack := TObjectStack<TObject>.Create(false);
  try
    CreateObjects(O, 6);
    LStack.OnNotify := NotifyTestObj;

    { Push }
    NotificationAdd(LStack, [O[0], O[1], O[2], O[3]], cnAdded);
    LStack.Push(O[0]);
    LStack.Push(O[1]);
    LStack.Push(O[2]);
    LStack.Push(O[3]);
    AssertNotificationsExecutedObj;

    { Pop }
    NotificationAdd(LStack, O[3], cnRemoved);
    TestContext.AssertTrue(LStack.Pop = O[3], '');
    AssertNotificationsExecutedObj;

    { Extract }
    NotificationAdd(LStack, O[2], cnExtracted);
    TestContext.AssertTrue(LStack.Extract = O[2], '');
    AssertNotificationsExecutedObj;

    { Clear }
    NotificationAdd(LStack, [O[1], O[0]], cnRemoved);
    LStack.Clear;
    AssertNotificationsExecutedObj;

    { Pop }
    NotificationAdd(LStack, [O[4], O[5]], cnAdded);
    LStack.Push(O[4]);
    LStack.Push(O[5]);
    AssertNotificationsExecutedObj;
  finally
    NotificationAdd(LStack, [O[5], O[4]], cnRemoved);
    FreeObjects(O);
    LStack.Free;
    AssertNotificationsExecutedObj;
  end;
end;

procedure TTestStdCollections.Test_GenericListBox;
begin
  TGenericListBox<Integer>.Test(TestContext);
end;

procedure TTestStdCollections.Test_TrimExcess;
var
  LList: TList<Integer>;
  LQueue: TQueue<Integer>;
  LStack: TStack<Integer>;
begin
  LList := TList<Integer>.Create;
  LQueue := TQueue<Integer>.Create;
  LStack := TStack<Integer>.Create;

  try
    LList.AddRange([1, 2, 3, 4, 5, 6]);
    LList.DeleteRange(2, 3);
    TestContext.AssertTrue((LList.Capacity)<>(LList.Count), '');
    LList.TrimExcess;
    TestContext.AssertTrue((LList.Capacity)=(LList.Count), '');

    LQueue.Enqueue(1);
    LQueue.Enqueue(2);
    LQueue.Dequeue;
    TestContext.AssertTrue((LQueue.Capacity)<>(LQueue.Count), '');
    LQueue.TrimExcess;
    TestContext.AssertTrue((LQueue.Capacity)=(LQueue.Count), '');

    LStack.Push(1);
    LStack.Push(2);
    LStack.Pop;
    TestContext.AssertTrue((LStack.Capacity)<>(LStack.Count), '');
    LStack.TrimExcess;
    TestContext.AssertTrue((LStack.Capacity)=(LStack.Count), '');
  finally
    LStack.Free;
    LQueue.Free;
    LList.Free;
  end;
end;


procedure RunTTestStdCollectionsTest_List(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_List');
  try
    lFixture.Test_List;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_FreeingManually(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_FreeingManually');
  try
    lFixture.Test_FreeingManually;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_AddingLists(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_AddingLists');
  try
    lFixture.Test_AddingLists;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_Sort(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_Sort');
  try
    lFixture.Test_Sort;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_Pack(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_Pack');
  try
    lFixture.Test_Pack;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_RecordsList(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_RecordsList');
  try
    lFixture.Test_RecordsList;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_VectorsList(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_VectorsList');
  try
    lFixture.Test_VectorsList;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_MethodsList(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_MethodsList');
  try
    lFixture.Test_MethodsList;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_SortedList(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_SortedList');
  try
    lFixture.Test_SortedList;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_Queue(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_Queue');
  try
    lFixture.Test_Queue;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_GenericListBox(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_GenericListBox');
  try
    lFixture.Test_GenericListBox;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_TList_Notification(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_TList_Notification');
  try
    lFixture.Test_TList_Notification;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_TSortedList_Notification(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_TSortedList_Notification');
  try
    lFixture.Test_TSortedList_Notification;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_TQueue_Notification(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_TQueue_Notification');
  try
    lFixture.Test_TQueue_Notification;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_TStack_Notification(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_TStack_Notification');
  try
    lFixture.Test_TStack_Notification;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_TObjectList_Notification(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_TObjectList_Notification');
  try
    lFixture.Test_TObjectList_Notification;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_TObjectQueue_Notification(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_TObjectQueue_Notification');
  try
    lFixture.Test_TObjectQueue_Notification;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_TObjectStack_Notification(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_TObjectStack_Notification');
  try
    lFixture.Test_TObjectStack_Notification;
  finally lFixture.Free; end;
end;

procedure RunTTestStdCollectionsTest_TrimExcess(AContext: TNXTestContext);
var lFixture: TTestStdCollections;
begin
  lFixture:=TTestStdCollections.Create(AContext, 'Test_TrimExcess');
  try
    lFixture.Test_TrimExcess;
  finally lFixture.Free; end;
end;

procedure RegistertestsgenericsstdcollectionsTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tests.generics.stdcollections.TTestStdCollections');
  lSuite.AddTest('Test_List', @RunTTestStdCollectionsTest_List);
  lSuite.AddTest('Test_FreeingManually', @RunTTestStdCollectionsTest_FreeingManually);
  lSuite.AddTest('Test_AddingLists', @RunTTestStdCollectionsTest_AddingLists);
  lSuite.AddTest('Test_Sort', @RunTTestStdCollectionsTest_Sort);
  lSuite.AddTest('Test_Pack', @RunTTestStdCollectionsTest_Pack);
  lSuite.AddTest('Test_RecordsList', @RunTTestStdCollectionsTest_RecordsList);
  lSuite.AddTest('Test_VectorsList', @RunTTestStdCollectionsTest_VectorsList);
  lSuite.AddTest('Test_MethodsList', @RunTTestStdCollectionsTest_MethodsList);
  lSuite.AddTest('Test_SortedList', @RunTTestStdCollectionsTest_SortedList);
  lSuite.AddTest('Test_Queue', @RunTTestStdCollectionsTest_Queue);
  lSuite.AddTest('Test_GenericListBox', @RunTTestStdCollectionsTest_GenericListBox);
  lSuite.AddTest('Test_TList_Notification', @RunTTestStdCollectionsTest_TList_Notification);
  lSuite.AddTest('Test_TSortedList_Notification', @RunTTestStdCollectionsTest_TSortedList_Notification);
  lSuite.AddTest('Test_TQueue_Notification', @RunTTestStdCollectionsTest_TQueue_Notification);
  lSuite.AddTest('Test_TStack_Notification', @RunTTestStdCollectionsTest_TStack_Notification);
  lSuite.AddTest('Test_TObjectList_Notification', @RunTTestStdCollectionsTest_TObjectList_Notification);
  lSuite.AddTest('Test_TObjectQueue_Notification', @RunTTestStdCollectionsTest_TObjectQueue_Notification);
  lSuite.AddTest('Test_TObjectStack_Notification', @RunTTestStdCollectionsTest_TObjectStack_Notification);
  lSuite.AddTest('Test_TrimExcess', @RunTTestStdCollectionsTest_TrimExcess);
end;

end.
