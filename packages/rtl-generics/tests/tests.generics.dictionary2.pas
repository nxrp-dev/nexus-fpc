unit tests.generics.dictionary2;

{$mode objfpc}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, Generics.Defaults, Generics.Collections;

Type

  { TTestGenDictionary }

  generic TTestGenDictionary<T> = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Private
    FDict : T;
    FAddMethod: (amAdd, amAddPair, amTryAdd, amAddOrSet, amGetOrAdd);
    //FCheckOrder = ()
  Public
    procedure SetUp; virtual;
    procedure TearDown; virtual;
    procedure RecreateDict;

    procedure DoTestAddByMethod(ATestVal: integer; AnAddDup: Boolean = False); virtual;
    procedure DoTestAdd(ATestVal: integer);
    procedure DoTestRemove(ATestVal: integer);
    procedure AssertKeyVal(ATestVal: integer);
    procedure AssertKeyNotFound(ATestVal: integer);
    procedure AssertEmpty;
    procedure AssertCount(AnExpCount: integer);

    procedure DoRunTestAdd;
  public
    Procedure TestAddModify;

    Procedure TestAdd;
    Procedure TestAddPair;
    //Procedure TestTryAdd;
    Procedure TestAddOrSet;
    //Procedure TestGetOrAdd;
  end;

  { TTestGenDictionary_TryAdd }

  generic TTestGenDictionary_TryAdd<T> = Class(specialize TTestGenDictionary<T>)
  public
    procedure DoTestAddByMethod(ATestVal: integer; AnAddDup: Boolean = False); override;
  public
    Procedure TestTryAdd;
    Procedure TestGetOrAdd;
  end;


  TTestHashFactory = class(TGenericsHashFactory)
  public
    class function GetHashService: THashServiceClass; override;
    class function GetHashCode(AKey: Pointer; ASize: SizeInt; AInitVal: UInt32 = 0): UInt32; override;
  end;

  TTestHashFactory2 = class(TGenericsHashFactory)
  public
    class function GetHashService: THashServiceClass; override;
    class function GetHashCode(AKey: Pointer; ASize: SizeInt; AInitVal: UInt32 = 0): UInt32; override;
  end;


  TTestDoubleHashFactory = class(TDelphiDoubleHashFactory)
  public
    class function GetHashService: THashServiceClass; override;
    class function GetHashCode(AKey: Pointer; ASize: SizeInt; AInitVal: UInt32 = 0): UInt32; override;
    //class procedure GetHashList(AKey: Pointer; ASize: SizeInt; AHashList: PUInt32; AOptions: TGetHashListOptions = []); override;
  end;

  TTestDoubleHashFactory2 = class(TDelphiDoubleHashFactory)
  public
    class function GetHashService: THashServiceClass; override;
    class function GetHashCode(AKey: Pointer; ASize: SizeInt; AInitVal: UInt32 = 0): UInt32; override;
    //class procedure GetHashList(AKey: Pointer; ASize: SizeInt; AHashList: PUInt32; AOptions: TGetHashListOptions = []); override;
  end;



procedure Registertestsgenericsdictionary2Tests(ARegistry: TNXTestRegistry);

implementation

class function TTestHashFactory.GetHashService: THashServiceClass;
begin
  Result := specialize THashService<TTestHashFactory>;
end;

class function TTestHashFactory.GetHashCode(AKey: Pointer; ASize: SizeInt; AInitVal: UInt32
  ): UInt32;
var
  s: AnsiString;
begin
  s := pchar(AKey);
  result := UInt32(StrToInt(s));
end;

class function TTestHashFactory2.GetHashService: THashServiceClass;
begin
  Result := specialize THashService<TTestHashFactory2>;
end;

class function TTestHashFactory2.GetHashCode(AKey: Pointer; ASize: SizeInt; AInitVal: UInt32
  ): UInt32;
var
  s: AnsiString;
begin
  s := pchar(AKey);
  result := UInt32(StrToInt(s)) << 12; // lots of clashes for: bucket := hash and mask;
end;

class function TTestDoubleHashFactory.GetHashService: THashServiceClass;
begin
  Result := specialize TExtendedHashService<TTestDoubleHashFactory>;
end;

class function TTestDoubleHashFactory.GetHashCode(AKey: Pointer; ASize: SizeInt; AInitVal: UInt32
  ): UInt32;
var
  s: AnsiString;
begin
  s := pchar(AKey);
  result := UInt32(StrToInt(s));
end;

class function TTestDoubleHashFactory2.GetHashService: THashServiceClass;
begin
  Result := specialize TExtendedHashService<TTestDoubleHashFactory2>;
end;

class function TTestDoubleHashFactory2.GetHashCode(AKey: Pointer; ASize: SizeInt; AInitVal: UInt32
  ): UInt32;
var
  s: AnsiString;
begin
  s := pchar(AKey);
  result := UInt32(StrToInt(s)) << 12; // lots of clashes for: bucket := hash and mask;
end;

{ TTestGenDictionary }

procedure TTestGenDictionary.SetUp;
begin

  FDict := T.Create;
end;

procedure TTestGenDictionary.TearDown;
begin
  FDict.Destroy;
end;

procedure TTestGenDictionary.RecreateDict;
begin
  FDict.Destroy;
  FDict := T.Create;
end;

procedure TTestGenDictionary.DoTestAddByMethod(ATestVal: integer; AnAddDup: Boolean);
var
  k, v: AnsiString;
  p: PAnsiString;
  APair: specialize TPair<AnsiString, AnsiString>;
  GotExcept: Boolean;
begin
  k := IntToStr(ATestVal);
  v := 'Val'+k;
  GotExcept := False;
  case FAddMethod of
    amAdd,
    amTryAdd, // TryAdd not supported
    amGetOrAdd: // not supported
    begin
      try FDict.Add(k, v); except GotExcept := True; end;
      TestContext.AssertTrue((GotExcept)=(AnAddDup), 'dup exception');
    end;
    amAddPair:
    begin
      APair.Key := k;
      APair.Value := v;
      try FDict.Add(APair); except GotExcept := True; end;
      TestContext.AssertTrue((GotExcept)=(AnAddDup), 'dup exception');
    end;
    amAddOrSet:
      FDict.AddOrSetValue(k, v);
  end;
end;

procedure TTestGenDictionary.DoTestAdd(ATestVal: integer);
begin
  FDict.Add(IntToStr(ATestVal), 'Val'+IntToStr(ATestVal));
end;

procedure TTestGenDictionary.DoTestRemove(ATestVal: integer);
begin
  FDict.Remove(IntToStr(ATestVal));
end;

procedure TTestGenDictionary.AssertKeyVal(ATestVal: integer);
var
  ValGotten, k: AnsiString;
begin
  k := IntToStr(ATestVal);
  TestContext.AssertTrue(FDict.ContainsKey(k), 'Has key '+k);
  TestContext.AssertTrue((FDict[k])=('Val'+k), 'Value for Key '+k);
  TestContext.AssertTrue(FDict.TryGetValue(k, ValGotten), 'Try key '+k);
  TestContext.AssertTrue((ValGotten)=('Val'+k), 'Tried value for Key '+k);
end;

procedure TTestGenDictionary.AssertKeyNotFound(ATestVal: integer);
var
  ValGotten, k: AnsiString;
begin
  k := IntToStr(ATestVal);
  TestContext.AssertTrue(not (FDict.ContainsKey(k)), 'Not has key '+k);
  TestContext.AssertTrue(not (FDict.TryGetValue(k, ValGotten)), 'Not try key '+k);
end;

procedure TTestGenDictionary.AssertEmpty;
begin
  AssertKeyNotFound(0);
  AssertKeyNotFound(1);
  AssertCount(0);
end;

procedure TTestGenDictionary.AssertCount(AnExpCount: integer);
begin
  TestContext.AssertTrue((FDict.Count)=(AnExpCount), 'Count');
end;

procedure TTestGenDictionary.DoRunTestAdd;
var
  i: Integer;
  GotExcept: Boolean;
begin
  AssertEmpty;

  DoTestAddByMethod(-999);
  AssertKeyVal(-999);
  AssertKeyNotFound(0);
  AssertKeyNotFound(1);
  AssertCount(1);

  DoTestRemove(-999);
  AssertEmpty;
  AssertKeyNotFound(-999);


  // Add again
  DoTestAddByMethod(-999);
  AssertKeyVal(-999);
  AssertKeyNotFound(0);
  AssertKeyNotFound(1);
  AssertCount(1);

  FDict.Clear;
  AssertEmpty;
  AssertKeyNotFound(-999);


  // Add again
  DoTestAddByMethod(-999);
  AssertKeyVal(-999);
  AssertKeyNotFound(0);
  AssertKeyNotFound(1);
  AssertCount(1);

  // Add duplicate
  DoTestAddByMethod(-999, True);
  AssertKeyVal(-999);
  AssertKeyNotFound(0);
  AssertKeyNotFound(1);
  AssertCount(1);


  RecreateDict;

  for i :=   0 to  99 do DoTestAddByMethod(i);
  for i :=   0 to  99 do AssertKeyVal(i);
  for i := 100 to 199 do AssertKeyNotFound(i);
  for i := -99 to  -1 do AssertKeyNotFound(i);
  AssertCount(100);

  DoTestRemove(99);
  AssertCount(99);
  AssertKeyNotFound(99);

  DoTestRemove(98);
  AssertCount(98);
  AssertKeyNotFound(99);
  AssertKeyNotFound(98);

  for i := 200 to 999 do DoTestAddByMethod(i);
  for i := 200 to 999 do AssertKeyVal(i);
  for i :=   0 to  97 do AssertKeyVal(i);
  for i :=  98 to 199 do AssertKeyNotFound(i);

  for i :=1000 to 9999 do DoTestAddByMethod(i);
  for i := 200 to 9999 do AssertKeyVal(i);
  for i :=   0 to  97 do AssertKeyVal(i);
  for i :=  98 to 199 do AssertKeyNotFound(i);

  FDict.TrimExcess;
  for i := 200 to 9999 do AssertKeyVal(i);
  for i :=   0 to  97 do AssertKeyVal(i);
  for i :=  98 to 199 do AssertKeyNotFound(i);

  FDict.TrimExcess;
  for i :=10000 to 10100 do DoTestAddByMethod(i);
  for i := 200 to 10100 do AssertKeyVal(i);
  for i :=   0 to  97 do AssertKeyVal(i);
  for i :=  98 to 199 do AssertKeyNotFound(i);

  FDict.Clear;
  AssertCount(0);
  for i :=   0 to  999 do AssertKeyNotFound(i);
  for i := 9999 to 10100 do AssertKeyNotFound(i);


  RecreateDict;

  // call add multiple times
  for i :=   0 to  199 do begin
    DoTestAddByMethod(i);
    DoTestAddByMethod(i, True);
    DoTestAddByMethod(i, True);
  end;
  for i :=   0 to  199 do AssertKeyVal(i);
  AssertCount(200);

end;

procedure TTestGenDictionary.TestAddModify;
var
  i: Integer;
  GotExcept: Boolean;
begin
  GotExcept := False;
  DoTestAdd(-999);
  AssertKeyVal(-999);
  AssertKeyNotFound(0);
  AssertKeyNotFound(1);
  AssertCount(1);

  FDict.AddOrSetValue('998', 'B');
  TestContext.AssertTrue((FDict['998'])=('B'), '');
  AssertKeyVal(-999);
  AssertCount(2);

  FDict.AddOrSetValue('-999', 'A');
  TestContext.AssertTrue((FDict['-999'])=('A'), '');
  TestContext.AssertTrue((FDict['998'])=('B'), '');
  AssertCount(2);

end;

procedure TTestGenDictionary.TestAdd;
begin
  FAddMethod := amAdd;
  DoRunTestAdd;
end;

procedure TTestGenDictionary.TestAddPair;
begin
  FAddMethod := amAddPair;
  DoRunTestAdd;
end;

//procedure TTestGenDictionary.TestTryAdd;
//begin
//  FAddMethod := amTryAdd;
//  DoRunTestAdd;
//end;

procedure TTestGenDictionary.TestAddOrSet;
begin
  FAddMethod := amAddOrSet;
  DoRunTestAdd;
end;

//procedure TTestGenDictionary.TestGetOrAdd;
//begin
//  FAddMethod := amGetOrAdd;
//  DoRunTestAdd;
//end;

{ TTestGenDictionary_TryAdd }

procedure TTestGenDictionary_TryAdd.DoTestAddByMethod(ATestVal: integer; AnAddDup: Boolean);
var
  k, v: AnsiString;
  p: PAnsiString;
  APair: specialize TPair<AnsiString, AnsiString>;
  GotExcept: Boolean;
begin
  k := IntToStr(ATestVal);
  v := 'Val'+k;
  GotExcept := False;
  case FAddMethod of
    amAdd:
    begin
      try FDict.Add(k, v); except GotExcept := True; end;
      TestContext.AssertTrue((GotExcept)=(AnAddDup), 'dup exception');
    end;
    amAddPair:
    begin
      APair.Key := k;
      APair.Value := v;
      try FDict.Add(APair); except GotExcept := True; end;
      TestContext.AssertTrue((GotExcept)=(AnAddDup), 'dup exception');
    end;
    amTryAdd:
    begin
      if AnAddDup then
        TestContext.AssertTrue(not (FDict.TryAdd(k, v)), '')
      else
        TestContext.AssertTrue(FDict.TryAdd(k, v), '');
    end;
    amAddOrSet:
      FDict.AddOrSetValue(k, v);
    amGetOrAdd:
    begin
      p := FDict.GetOrAddMutableValue(k);
      TestContext.AssertTrue(p <> nil, '');
      if AnAddDup then
        TestContext.AssertTrue(p^ = v, '')
      else
        TestContext.AssertTrue(p^ = '', '');
      p^ := v;
    end;
  end;
end;

procedure TTestGenDictionary_TryAdd.TestTryAdd;
begin
  FAddMethod := amTryAdd;
  DoRunTestAdd;
end;

procedure TTestGenDictionary_TryAdd.TestGetOrAdd;
begin
  FAddMethod := amGetOrAdd;
  DoRunTestAdd;
end;


type TNXDictionaryCase17 = specialize TTestGenDictionary< specialize THashMap<AnsiString, AnsiString> >;

type TNXDictionaryCase16 = specialize TTestGenDictionary< specialize TFastHashMap<AnsiString, AnsiString> >;

type TNXDictionaryCase15 = specialize TTestGenDictionary< specialize TCuckooD6<AnsiString, AnsiString> >;

type TNXDictionaryCase14 = specialize TTestGenDictionary< specialize TCuckooD4<AnsiString, AnsiString> >;

type TNXDictionaryCase13 = specialize TTestGenDictionary< specialize TCuckooD2<AnsiString, AnsiString> >;

type TNXDictionaryCase12 = specialize TTestGenDictionary_TryAdd< specialize TOpenAddressingDH<AnsiString, AnsiString, TTestDoubleHashFactory2> >;

type TNXDictionaryCase11 = specialize TTestGenDictionary_TryAdd< specialize TOpenAddressingDH<AnsiString, AnsiString, TTestDoubleHashFactory> >;

type TNXDictionaryCase10 = specialize TTestGenDictionary_TryAdd< specialize TOpenAddressingDH<AnsiString, AnsiString> >;

type TNXDictionaryCase9 = specialize TTestGenDictionary_TryAdd< specialize TOpenAddressingQP<AnsiString, AnsiString, TTestHashFactory2> >;

type TNXDictionaryCase8 = specialize TTestGenDictionary_TryAdd< specialize TOpenAddressingQP<AnsiString, AnsiString, TTestHashFactory> >;

type TNXDictionaryCase7 = specialize TTestGenDictionary_TryAdd< specialize TOpenAddressingQP<AnsiString, AnsiString> >;

type TNXDictionaryCase6 = specialize TTestGenDictionary_TryAdd< specialize TOpenAddressingLPT<AnsiString, AnsiString, TTestHashFactory2> >;

type TNXDictionaryCase5 = specialize TTestGenDictionary_TryAdd< specialize TOpenAddressingLPT<AnsiString, AnsiString, TTestHashFactory> >;

type TNXDictionaryCase4 = specialize TTestGenDictionary_TryAdd< specialize TOpenAddressingLPT<AnsiString, AnsiString> >;

type TNXDictionaryCase3 = specialize TTestGenDictionary_TryAdd< specialize TOpenAddressingLP<AnsiString, AnsiString, TTestHashFactory2> >;

type TNXDictionaryCase2 = specialize TTestGenDictionary_TryAdd< specialize TOpenAddressingLP<AnsiString, AnsiString, TTestHashFactory> >;

type TNXDictionaryCase1 = specialize TTestGenDictionary_TryAdd< specialize TDictionary<AnsiString, AnsiString> >;

constructor TTestGenDictionary.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTNXDictionaryCase1TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase1;
begin
  lFixture:=TNXDictionaryCase1.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase1TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase1;
begin
  lFixture:=TNXDictionaryCase1.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase1TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase1;
begin
  lFixture:=TNXDictionaryCase1.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase1TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase1;
begin
  lFixture:=TNXDictionaryCase1.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase1TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase1;
begin
  lFixture:=TNXDictionaryCase1.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase1TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase1;
begin
  lFixture:=TNXDictionaryCase1.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase2TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase2;
begin
  lFixture:=TNXDictionaryCase2.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase2TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase2;
begin
  lFixture:=TNXDictionaryCase2.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase2TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase2;
begin
  lFixture:=TNXDictionaryCase2.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase2TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase2;
begin
  lFixture:=TNXDictionaryCase2.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase2TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase2;
begin
  lFixture:=TNXDictionaryCase2.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase2TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase2;
begin
  lFixture:=TNXDictionaryCase2.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase3TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase3;
begin
  lFixture:=TNXDictionaryCase3.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase3TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase3;
begin
  lFixture:=TNXDictionaryCase3.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase3TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase3;
begin
  lFixture:=TNXDictionaryCase3.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase3TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase3;
begin
  lFixture:=TNXDictionaryCase3.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase3TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase3;
begin
  lFixture:=TNXDictionaryCase3.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase3TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase3;
begin
  lFixture:=TNXDictionaryCase3.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase4TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase4;
begin
  lFixture:=TNXDictionaryCase4.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase4TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase4;
begin
  lFixture:=TNXDictionaryCase4.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase4TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase4;
begin
  lFixture:=TNXDictionaryCase4.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase4TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase4;
begin
  lFixture:=TNXDictionaryCase4.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase4TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase4;
begin
  lFixture:=TNXDictionaryCase4.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase4TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase4;
begin
  lFixture:=TNXDictionaryCase4.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase5TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase5;
begin
  lFixture:=TNXDictionaryCase5.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase5TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase5;
begin
  lFixture:=TNXDictionaryCase5.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase5TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase5;
begin
  lFixture:=TNXDictionaryCase5.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase5TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase5;
begin
  lFixture:=TNXDictionaryCase5.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase5TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase5;
begin
  lFixture:=TNXDictionaryCase5.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase5TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase5;
begin
  lFixture:=TNXDictionaryCase5.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase6TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase6;
begin
  lFixture:=TNXDictionaryCase6.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase6TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase6;
begin
  lFixture:=TNXDictionaryCase6.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase6TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase6;
begin
  lFixture:=TNXDictionaryCase6.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase6TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase6;
begin
  lFixture:=TNXDictionaryCase6.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase6TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase6;
begin
  lFixture:=TNXDictionaryCase6.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase6TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase6;
begin
  lFixture:=TNXDictionaryCase6.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase7TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase7;
begin
  lFixture:=TNXDictionaryCase7.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase7TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase7;
begin
  lFixture:=TNXDictionaryCase7.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase7TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase7;
begin
  lFixture:=TNXDictionaryCase7.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase7TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase7;
begin
  lFixture:=TNXDictionaryCase7.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase7TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase7;
begin
  lFixture:=TNXDictionaryCase7.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase7TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase7;
begin
  lFixture:=TNXDictionaryCase7.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase8TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase8;
begin
  lFixture:=TNXDictionaryCase8.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase8TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase8;
begin
  lFixture:=TNXDictionaryCase8.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase8TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase8;
begin
  lFixture:=TNXDictionaryCase8.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase8TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase8;
begin
  lFixture:=TNXDictionaryCase8.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase8TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase8;
begin
  lFixture:=TNXDictionaryCase8.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase8TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase8;
begin
  lFixture:=TNXDictionaryCase8.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase9TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase9;
begin
  lFixture:=TNXDictionaryCase9.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase9TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase9;
begin
  lFixture:=TNXDictionaryCase9.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase9TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase9;
begin
  lFixture:=TNXDictionaryCase9.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase9TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase9;
begin
  lFixture:=TNXDictionaryCase9.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase9TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase9;
begin
  lFixture:=TNXDictionaryCase9.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase9TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase9;
begin
  lFixture:=TNXDictionaryCase9.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase10TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase10;
begin
  lFixture:=TNXDictionaryCase10.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase10TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase10;
begin
  lFixture:=TNXDictionaryCase10.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase10TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase10;
begin
  lFixture:=TNXDictionaryCase10.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase10TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase10;
begin
  lFixture:=TNXDictionaryCase10.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase10TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase10;
begin
  lFixture:=TNXDictionaryCase10.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase10TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase10;
begin
  lFixture:=TNXDictionaryCase10.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase11TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase11;
begin
  lFixture:=TNXDictionaryCase11.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase11TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase11;
begin
  lFixture:=TNXDictionaryCase11.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase11TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase11;
begin
  lFixture:=TNXDictionaryCase11.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase11TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase11;
begin
  lFixture:=TNXDictionaryCase11.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase11TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase11;
begin
  lFixture:=TNXDictionaryCase11.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase11TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase11;
begin
  lFixture:=TNXDictionaryCase11.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase12TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase12;
begin
  lFixture:=TNXDictionaryCase12.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase12TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase12;
begin
  lFixture:=TNXDictionaryCase12.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase12TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase12;
begin
  lFixture:=TNXDictionaryCase12.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase12TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase12;
begin
  lFixture:=TNXDictionaryCase12.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase12TestTryAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase12;
begin
  lFixture:=TNXDictionaryCase12.Create(AContext, 'TestTryAdd');
  try
    lFixture.SetUp;
    try lFixture.TestTryAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase12TestGetOrAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase12;
begin
  lFixture:=TNXDictionaryCase12.Create(AContext, 'TestGetOrAdd');
  try
    lFixture.SetUp;
    try lFixture.TestGetOrAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase13TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase13;
begin
  lFixture:=TNXDictionaryCase13.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase13TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase13;
begin
  lFixture:=TNXDictionaryCase13.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase13TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase13;
begin
  lFixture:=TNXDictionaryCase13.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase13TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase13;
begin
  lFixture:=TNXDictionaryCase13.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase14TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase14;
begin
  lFixture:=TNXDictionaryCase14.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase14TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase14;
begin
  lFixture:=TNXDictionaryCase14.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase14TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase14;
begin
  lFixture:=TNXDictionaryCase14.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase14TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase14;
begin
  lFixture:=TNXDictionaryCase14.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase15TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase15;
begin
  lFixture:=TNXDictionaryCase15.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase15TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase15;
begin
  lFixture:=TNXDictionaryCase15.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase15TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase15;
begin
  lFixture:=TNXDictionaryCase15.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase15TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase15;
begin
  lFixture:=TNXDictionaryCase15.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase16TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase16;
begin
  lFixture:=TNXDictionaryCase16.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase16TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase16;
begin
  lFixture:=TNXDictionaryCase16.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase16TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase16;
begin
  lFixture:=TNXDictionaryCase16.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase16TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase16;
begin
  lFixture:=TNXDictionaryCase16.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase17TestAddModify(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase17;
begin
  lFixture:=TNXDictionaryCase17.Create(AContext, 'TestAddModify');
  try
    lFixture.SetUp;
    try lFixture.TestAddModify; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase17TestAdd(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase17;
begin
  lFixture:=TNXDictionaryCase17.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase17TestAddPair(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase17;
begin
  lFixture:=TNXDictionaryCase17.Create(AContext, 'TestAddPair');
  try
    lFixture.SetUp;
    try lFixture.TestAddPair; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTNXDictionaryCase17TestAddOrSet(AContext: TNXTestContext);
var lFixture: TNXDictionaryCase17;
begin
  lFixture:=TNXDictionaryCase17.Create(AContext, 'TestAddOrSet');
  try
    lFixture.SetUp;
    try lFixture.TestAddOrSet; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure Registertestsgenericsdictionary2Tests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase1');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase1TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase1TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase1TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase1TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase1TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase1TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase2');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase2TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase2TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase2TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase2TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase2TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase2TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase3');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase3TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase3TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase3TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase3TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase3TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase3TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase4');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase4TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase4TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase4TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase4TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase4TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase4TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase5');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase5TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase5TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase5TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase5TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase5TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase5TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase6');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase6TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase6TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase6TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase6TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase6TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase6TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase7');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase7TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase7TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase7TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase7TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase7TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase7TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase8');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase8TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase8TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase8TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase8TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase8TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase8TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase9');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase9TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase9TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase9TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase9TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase9TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase9TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase10');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase10TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase10TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase10TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase10TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase10TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase10TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase11');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase11TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase11TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase11TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase11TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase11TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase11TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase12');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase12TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase12TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase12TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase12TestAddOrSet);
  lSuite.AddTest('TestTryAdd', @RunTNXDictionaryCase12TestTryAdd);
  lSuite.AddTest('TestGetOrAdd', @RunTNXDictionaryCase12TestGetOrAdd);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase13');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase13TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase13TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase13TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase13TestAddOrSet);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase14');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase14TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase14TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase14TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase14TestAddOrSet);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase15');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase15TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase15TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase15TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase15TestAddOrSet);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase16');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase16TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase16TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase16TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase16TestAddOrSet);
  lSuite:=ARegistry.AddSuite('tests.generics.dictionary2.TNXDictionaryCase17');
  lSuite.AddTest('TestAddModify', @RunTNXDictionaryCase17TestAddModify);
  lSuite.AddTest('TestAdd', @RunTNXDictionaryCase17TestAdd);
  lSuite.AddTest('TestAddPair', @RunTNXDictionaryCase17TestAddPair);
  lSuite.AddTest('TestAddOrSet', @RunTNXDictionaryCase17TestAddOrSet);
end;

end.
