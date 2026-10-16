unit tests.generics.dictionary;

{$mode objfpc}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, Generics.Defaults, Generics.Collections;

Type
  TMySimpleDict = Class(Specialize TDictionary<Integer,String>);
{$IFDEF FPC}
  EDictionary = EListError;
  TMyPair = specialize TPair<Integer,String>;
{$ENDIF}
  { TTestSimpleDictionary }

  TTestSimpleDictionary = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Private
    FDict : TMySimpleDict;
    FnotifyMessage : String;
    FCurrentKeyNotify : Integer;
    FCurrentValueNotify : Integer;
    FExpectKeys : Array of Integer;
    FExpectValues : Array of String;
    FExpectValueAction,
    FExpectKeyAction: Array of TCollectionNotification;
    procedure DoAdd(aCount: Integer; aOffset: Integer=0);
    procedure DoAdd2;
    Procedure DoneExpectKeys;
    Procedure DoneExpectValues;
    procedure DoGetValue(aKey: Integer; Match: String; ExceptionClass: TClass=nil);
    procedure DoKeyNotify(ASender: TObject; const AItem: Integer; AAction: TCollectionNotification);
    procedure DoValueNotify(ASender: TObject; const AItem: String; AAction: TCollectionNotification);
  Public
    Procedure SetExpectKeys(aMessage : string; AKeys : Array of Integer; AActions : Array of TCollectionNotification; DoReverse : Boolean = False);
    Procedure SetExpectValues(aMessage : string; AKeys : Array of String; AActions : Array of TCollectionNotification; DoReverse : Boolean = False);
    Procedure SetUp; virtual;
    Procedure TearDown; virtual;
    Property Dict : TMySimpleDict Read FDict;
  public
    Procedure TestEmpty;
    Procedure TestAdd;
    Procedure TestClear;
    Procedure TestTryGetValue;
    Procedure TestGetValue;
    Procedure TestSetValue;
    Procedure TestAddDuplicate;
    Procedure TestAddOrSet;
    Procedure TestTryAdd;
    Procedure TestContainsKey;
    Procedure TestContainsValue;
    Procedure TestDelete;
    Procedure TestToArray;
    procedure TestKeys;
    Procedure TestValues;
    Procedure TestEnumerator;
    Procedure TestNotification;
    procedure TestNotificationDelete;
    procedure TestValueNotification;
    procedure TestValueNotificationDelete;
    procedure TestKeyValueNotificationSet;
  end;

procedure RegistertestsgenericsdictionaryTests(ARegistry: TNXTestRegistry);

implementation

{ TTestSimpleDictionary }

procedure TTestSimpleDictionary.SetUp;
begin

  FDict:=TMySimpleDict.Create;
  FCurrentKeyNotify:=0;
  FCurrentValueNotify:=0;
  FExpectKeys:=[];
  FExpectKeyAction:=[];
  FExpectValues:=[];
  FExpectValueAction:=[];
end;

procedure TTestSimpleDictionary.TearDown;
begin
  // So we don't get clear messages
  FDict.OnKeyNotify:=Nil;
  FDict.OnValueNotify:=Nil;
  FreeAndNil(FDict);

end;

procedure TTestSimpleDictionary.TestEmpty;
begin
  TestContext.AssertTrue((Dict)<>nil, 'Have dictionary');
  TestContext.AssertTrue((0)=(Dict.Count), 'empty dictionary');
end;

procedure TTestSimpleDictionary.DoAdd(aCount : Integer; aOffset : Integer=0);

Var
  I : Integer;

begin
  if aOffset=-1 then
    aOffset:=Dict.Count;
  For I:=aOffset+1 to aOffset+aCount do
    Dict.Add(I,IntToStr(i));
end;

procedure TTestSimpleDictionary.TestAdd;

begin
  DoAdd(1);
  TestContext.AssertTrue((1)=(Dict.Count), 'Count OK');
  TestContext.AssertTrue(Dict.ContainsKey(1), 'Has added value');
  DoAdd(1,1);
  TestContext.AssertTrue((2)=(Dict.Count), 'Count OK');
  TestContext.AssertTrue(Dict.ContainsKey(2), 'Has added value');
end;

procedure TTestSimpleDictionary.TestClear;
begin
  DoAdd(3);
  TestContext.AssertTrue((3)=(Dict.Count), 'Count OK');
  Dict.Clear;
  TestContext.AssertTrue((0)=(Dict.Count), 'Count after clear OK');
end;

procedure TTestSimpleDictionary.TestTryGetValue;

Var
  I : integer;
  SI,A : string;

begin
  DoAdd(3);
  For I:=1 to 3 do
    begin
    SI:=IntToStr(I);
    TestContext.AssertTrue(Dict.TryGetValue(I,A), 'Have value '+SI);
    TestContext.AssertTrue((SI)=(A), 'Value is correct '+SI);
    end;
  TestContext.AssertTrue(not (Dict.TryGetValue(4,A)), 'Have no value 4');
end;

procedure TTestSimpleDictionary.DoGetValue(aKey: Integer; Match: String; ExceptionClass: TClass);

Var
  EC : TClass;
  A,EM : String;

begin
  EC:=Nil;
  try
    A:=Dict.Items[aKey];
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
    TestContext.AssertTrue((Match)=(A), 'Value is correct for '+IntToStr(aKey))
    end
  else
    begin
    if EC=Nil then
      TestContext.Fail('Expected exception '+ExceptionClass.ClassName+' but got none');
    if EC<>ExceptionClass then
      TestContext.Fail('Expected exception class '+ExceptionClass.ClassName+' but got '+EC.ClassName+' with message '+EM);
    end;
end;

procedure TTestSimpleDictionary.DoKeyNotify(ASender: TObject; const AItem: Integer; AAction: TCollectionNotification);
var
  I,J : integer;
begin
  Writeln(FnotifyMessage+' Notification ',FCurrentKeyNotify);
  TestContext.AssertTrue((FDict)=(aSender), FnotifyMessage+' Correct sender');
  if (FCurrentKeyNotify>=Length(FExpectKeys)) then
    TestContext.Fail(FnotifyMessage+' Too many notificiations');
  if AAction=cnRemoved then
    begin
      j:=-1;
      for i:=0 to Length(FExpectKeys)-1 do
        if AItem=FExpectKeys[i] then
	  begin
            j:=i;
            FExpectKeys[i]:=-1;
	    break;
	  end;
      if j=-1 then
        TestContext.Fail(FnotifyMessage+' Notification Key '+IntToStr(aItem)+' not found');
    end
  else
    TestContext.AssertTrue((FExpectKeys[FCurrentKeyNotify])=(aItem), FnotifyMessage+' Notification Key no '+IntToStr(FCurrentKeyNotify));
  Inc(FCurrentKeyNotify);
end;

procedure TTestSimpleDictionary.DoValueNotify(ASender: TObject; const AItem: String; AAction: TCollectionNotification);
var
  I,J : integer;
begin
  Writeln(FnotifyMessage+' value Notification ',FCurrentValueNotify);
  TestContext.AssertTrue((FDict)=(aSender), FnotifyMessage+' value Correct sender');
  if (FCurrentValueNotify>=Length(FExpectValues)) then
    TestContext.Fail(FnotifyMessage+' Too many value notificiations');
  if AAction=cnRemoved then
    begin
      j:=-1;
      for i:=0 to Length(FExpectValues)-1 do
        if AItem=FExpectValues[i] then
	  begin
            j:=i;
            FExpectValues[i]:='Already found';
	    break;
	  end;
      if j=-1 then
        TestContext.Fail(FnotifyMessage+' Notification value '+AItem+' not found');
    end
  else
    TestContext.AssertTrue((FExpectValues[FCurrentValueNotify])=(aItem), FnotifyMessage+' Notification value no '+IntToStr(FCurrentValueNotify));
  Inc(FCurrentValueNotify);
end;

procedure TTestSimpleDictionary.SetExpectKeys(aMessage: string; AKeys: array of Integer;
  AActions: array of TCollectionNotification; DoReverse: Boolean = False);

Var
  I,L : integer;

begin
  FnotifyMessage:=aMessage;
  FCurrentKeyNotify:=0;
  L:=Length(aKeys);
  TestContext.AssertTrue((l)=(Length(aActions)), 'SetExpectkeys: Lengths arrays equal');
  SetLength(FExpectKeys,L);
  SetLength(FExpectKeyAction,L);
  Dec(L);
  if DoReverse then
    For I:=0 to L do
      begin
      FExpectKeys[L-i]:=AKeys[i];
      FExpectKeyAction[L-i]:=AActions[I];
      end
  else
    For I:=0 to L do
      begin
      FExpectKeys[i]:=AKeys[i];
      FExpectKeyAction[i]:=AActions[I];
      end;
end;

procedure TTestSimpleDictionary.SetExpectValues(aMessage: string; AKeys: array of String;
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

procedure TTestSimpleDictionary.TestGetValue;

Var
  I : integer;

begin
  DoAdd(3);
  For I:=1 to 3 do
    DoGetValue(I,IntToStr(I));
  DoGetValue(4,'4',EDictionary);
end;

procedure TTestSimpleDictionary.TestSetValue;
begin
  TestGetValue;
  Dict.Items[3]:='Six';
  DoGetValue(3,'Six');
end;

procedure TTestSimpleDictionary.DoAdd2;

begin
  Dict.Add(2,'A new 2');
end;

procedure TTestSimpleDictionary.DoneExpectKeys;
begin
  TestContext.AssertTrue((Length(FExpectKeys))=(FCurrentKeyNotify), FnotifyMessage+' Expected number of keys seen');
end;

procedure TTestSimpleDictionary.DoneExpectValues;
begin
  TestContext.AssertTrue((Length(FExpectValues))=(FCurrentValueNotify), FnotifyMessage+' Expected number of values seen');
end;

procedure TTestSimpleDictionary.TestAddDuplicate;
begin
  DoAdd(3);
  TestContext.AssertRaises(EDictionary, @DoAdd2, 'Cannot add duplicate');
end;

procedure TTestSimpleDictionary.TestAddOrSet;

begin
  DoAdd(3);
  Dict.AddOrSetValue(2,'a new 2');
  DoGetValue(2,'a new 2');
end;

procedure TTestSimpleDictionary.TestTryAdd;
begin
  TestContext.AssertTrue(Dict.TryAdd(1, 'Foobar'), '');
  TestContext.AssertTrue(not (Dict.TryAdd(1, 'Foo')), '');
  TestContext.AssertTrue(Dict.TryAdd(2, 'Bar'), '');
end;

procedure TTestSimpleDictionary.TestContainsKey;

Var
  I : Integer;

begin
  DoAdd(3);
  For I:=1 to 3 do
    TestContext.AssertTrue(Dict.ContainsKey(I), 'Has '+IntToStr(i));
  TestContext.AssertTrue(not (Dict.ContainsKey(4)), 'Has not 4');
end;

procedure TTestSimpleDictionary.TestContainsValue;

Var
  I : Integer;

begin
  DoAdd(3);
  For I:=1 to 3 do
    TestContext.AssertTrue(Dict.ContainsValue(IntToStr(i)), 'Has '+IntToStr(i));
  TestContext.AssertTrue(not (Dict.ContainsValue('4')), 'Has not 4');
end;

procedure TTestSimpleDictionary.TestDelete;

begin
  DoAdd(3);
  Dict.Remove(2);
  TestContext.AssertTrue((2)=(Dict.Count), 'Count');
  TestContext.AssertTrue(not (Dict.ContainsKey(2)), 'Has not 2');
end;

procedure TTestSimpleDictionary.TestToArray;

Var
{$ifdef fpc}
  A : specialize TArray<TMyPair>;
{$else}
  A : specialize TArray<TMySimpleDict.TMyPair>;
{$endif}
  I : Integer;
  SI : String;

begin
  DoAdd(3);
  A:=Dict.ToArray;
  specialize TArrayHelper<TMyPair>.Sort(A{$ifndef fpc}, specialize TComparer<TMySimpleDict.TMyPair>.Default{$endif});
  TestContext.AssertTrue((3)=(Length(A)), 'Length Ok');
  For I:=1 to 3 do
    begin
    SI:=IntToStr(I);
    TestContext.AssertTrue((I)=(A[i-1].Key), 'key '+SI);
    TestContext.AssertTrue((SI)=(A[i-1].Value), 'Value '+SI);
    end;
end;

procedure TTestSimpleDictionary.TestKeys;

Var
  A : Array of Integer;
  I : Integer;
  SI : String;

begin
  DoAdd(3);
  A:=Dict.Keys.ToArray;
  specialize TArrayHelper<Integer>.Sort(A{$ifndef fpc}, specialize TComparer<Integer>.Default{$endif});
  TestContext.AssertTrue((3)=(Length(A)), 'Length Ok');
  For I:=1 to 3 do
    begin
    SI:=IntToStr(I);
    TestContext.AssertTrue((I)=(A[i-1]), 'key '+SI);
    end;
end;

procedure TTestSimpleDictionary.TestValues;
Var
  A : Array of String;
  I : Integer;
  SI : String;

begin
  DoAdd(3);
  A:=Dict.Values.ToArray;
  specialize TArrayHelper<String>.Sort(A{$ifndef fpc}, specialize TComparer<String>.Default{$endif});
  TestContext.AssertTrue((3)=(Length(A)), 'Length Ok');
  For I:=1 to 3 do
    begin
    SI:=IntToStr(I);
    TestContext.AssertTrue((SI)=(A[i-1]), 'Value '+SI);
    end;
end;

procedure TTestSimpleDictionary.TestEnumerator;
type
  TStringList = specialize TList<String>;
  TIntegerList = specialize TList<Integer>;

Var
{$ifdef fpc}
  A : TMyPair;
{$else}
  A : TMySimpleDict.TMyPair;
{$endif}
  I,J : Integer;
  SI : String;
  IL: TIntegerList;
  SL: TStringList;
begin
  DoAdd(3);
  IL:=Nil;
  SL:=TStringList.Create;
  try
    IL:=TIntegerList.Create;
    for I:=1 to 3 do begin
      IL.Add(I);
      SL.Add(IntToStr(I));
    end;
    I:=1;
    For A in Dict do
      begin
      SI:=IntToStr(I);
      J:=IL.IndexOf(A.Key);
      TestContext.AssertTrue(J>=0, 'key '+SI);
      IL.Delete(J);
      J:=SL.IndexOf(A.Value);
      TestContext.AssertTrue(J>=0, 'value '+SI);
      SL.Delete(J);
      Inc(I);
      end;
  finally
    IL.Free;
    SL.Free;
  end;
end;

procedure TTestSimpleDictionary.TestNotification;
begin
  Dict.OnKeyNotify:=@DoKeyNotify;
  SetExpectKeys('Add',[1,2,3],[cnAdded,cnAdded,cnAdded]);
  DoAdd(3);
  DoneExpectKeys;
end;

Const
{$IFDEF FPC}
    ReverseDeleteNotification = True;
{$ELSE}
   ReverseDeleteNotification = False;
{$ENDIF}

procedure TTestSimpleDictionary.TestNotificationDelete;


begin
  DoAdd(3);
  Dict.OnKeyNotify:=@DoKeyNotify;
  SetExpectKeys('Clear',[1,2,3],[cnRemoved,cnRemoved,cnRemoved],ReverseDeleteNotification);
  Dict.Clear;
  DoneExpectKeys;
end;

procedure TTestSimpleDictionary.TestValueNotification;
begin
  Dict.OnValueNotify:=@DoValueNotify;
  SetExpectValues('Add',['1','2','3'],[cnAdded,cnAdded,cnAdded]);
  DoAdd(3);
  DoneExpectValues;
end;

procedure TTestSimpleDictionary.TestValueNotificationDelete;
begin
  DoAdd(3);
  Dict.OnValueNotify:=@DoValueNotify;
  SetExpectValues('Clear',['1','2','3'],[cnRemoved,cnRemoved,cnRemoved],ReverseDeleteNotification);
  Dict.Clear;
  DoneExpectValues;
end;

procedure TTestSimpleDictionary.TestKeyValueNotificationSet;
begin
  DoAdd(3);
  Dict.OnValueNotify:=@DoValueNotify;
  Dict.OnKeyNotify:=@DoKeyNotify;
  SetExpectValues('Set',['2','Six'],[cnRemoved,cnAdded]);
  SetExpectKeys('Set',[],[]);
  Dict[2]:='Six';
  DoneExpectKeys;
  DoneExpectValues;
end;


constructor TTestSimpleDictionary.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestSimpleDictionaryTestEmpty(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestEmpty');
  try
    lFixture.SetUp;
    try lFixture.TestEmpty; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestAdd(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestClear(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestClear');
  try
    lFixture.SetUp;
    try lFixture.TestClear; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestTryGetValue(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestTryGetValue');
  try
    lFixture.SetUp;
    try lFixture.TestTryGetValue; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestGetValue(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestGetValue');
  try
    lFixture.SetUp;
    try lFixture.TestGetValue; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestSetValue(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestSetValue');
  try
    lFixture.SetUp;
    try lFixture.TestSetValue; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestAddDuplicate(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestAddDuplicate');
  try
    lFixture.SetUp;
    try lFixture.TestAddDuplicate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestAddOrSet(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestTryAdd(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestContainsKey(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestContainsKey');
  try
    lFixture.SetUp;
    try lFixture.TestContainsKey; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestContainsValue(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestContainsValue');
  try
    lFixture.SetUp;
    try lFixture.TestContainsValue; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestDelete(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestDelete');
  try
    lFixture.SetUp;
    try lFixture.TestDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestToArray(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestToArray');
  try
    lFixture.SetUp;
    try lFixture.TestToArray; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestKeys(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestKeys');
  try
    lFixture.SetUp;
    try lFixture.TestKeys; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestValues(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestValues');
  try
    lFixture.SetUp;
    try lFixture.TestValues; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestEnumerator(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestEnumerator');
  try
    lFixture.SetUp;
    try lFixture.TestEnumerator; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestNotification(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestNotification');
  try
    lFixture.SetUp;
    try lFixture.TestNotification; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestNotificationDelete(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestNotificationDelete');
  try
    lFixture.SetUp;
    try lFixture.TestNotificationDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestValueNotification(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestValueNotification');
  try
    lFixture.SetUp;
    try lFixture.TestValueNotification; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestValueNotificationDelete(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestValueNotificationDelete');
  try
    lFixture.SetUp;
    try lFixture.TestValueNotificationDelete; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestSimpleDictionaryTestKeyValueNotificationSet(AContext: TNXTestContext);
var lFixture: TTestSimpleDictionary;
begin
  lFixture:=TTestSimpleDictionary.Create(AContext, 'TestKeyValueNotificationSet');
  try
    lFixture.SetUp;
    try lFixture.TestKeyValueNotificationSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertestsgenericsdictionaryTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary.TTestSimpleDictionary');
  lSuite.AddTest('TestEmpty', @RunTTestSimpleDictionaryTestEmpty);
  lSuite.AddTest('TestAdd', @RunTTestSimpleDictionaryTestAdd);
  lSuite.AddTest('TestClear', @RunTTestSimpleDictionaryTestClear);
  lSuite.AddTest('TestTryGetValue', @RunTTestSimpleDictionaryTestTryGetValue);
  lSuite.AddTest('TestGetValue', @RunTTestSimpleDictionaryTestGetValue);
  lSuite.AddTest('TestSetValue', @RunTTestSimpleDictionaryTestSetValue);
  lSuite.AddTest('TestAddDuplicate', @RunTTestSimpleDictionaryTestAddDuplicate);
  lSuite.AddTest('TestAddOrSet', @RunTTestSimpleDictionaryTestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTTestSimpleDictionaryTestTryAdd);
  lSuite.AddTest('TestContainsKey', @RunTTestSimpleDictionaryTestContainsKey);
  lSuite.AddTest('TestContainsValue', @RunTTestSimpleDictionaryTestContainsValue);
  lSuite.AddTest('TestDelete', @RunTTestSimpleDictionaryTestDelete);
  lSuite.AddTest('TestToArray', @RunTTestSimpleDictionaryTestToArray);
  lSuite.AddTest('TestKeys', @RunTTestSimpleDictionaryTestKeys);
  lSuite.AddTest('TestValues', @RunTTestSimpleDictionaryTestValues);
  lSuite.AddTest('TestEnumerator', @RunTTestSimpleDictionaryTestEnumerator);
  lSuite.AddTest('TestNotification', @RunTTestSimpleDictionaryTestNotification);
  lSuite.AddTest('TestNotificationDelete', @RunTTestSimpleDictionaryTestNotificationDelete);
  lSuite.AddTest('TestValueNotification', @RunTTestSimpleDictionaryTestValueNotification);
  lSuite.AddTest('TestValueNotificationDelete', @RunTTestSimpleDictionaryTestValueNotificationDelete);
  lSuite.AddTest('TestKeyValueNotificationSet', @RunTTestSimpleDictionaryTestKeyValueNotificationSet);
end;

end.
