unit tcresref;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, TypInfo;

type

  { TRefComponent }

  TRefComponent = Class(TComponent)
  private
    FRef1: TComponent;
    FRef2: TComponent;
  Published
    Property Ref1 : TComponent Read FRef1 Write FRef1;
    Property Ref2 : TComponent Read FRef2 Write FRef2;
  end;

  TRootA = Class(TRefComponent)
  end;

  TRootB = Class(TRefComponent)
  end;

  TA = Class(TRefComponent)
  end;
  TB = Class(TRefComponent)
  end;


  { TTestResolveReference }

  TTestResolveReference = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Private
    RootA : TRootA;
    RootB : TRootB;
    PropA1,
    PropA2,
    PropB1,
    PropB2 : PPRopInfo;
    UnrA : TObject;
    UnrB : TObject;
  protected
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure TestAddInst1;
    procedure TestAddInst2;
    procedure TestAddInst3;
    procedure TestAdd2;
    procedure TestAdd3;
    Procedure TestFixupReferenceNames1;
    procedure TestFixupReferenceNames2;
    procedure TestFixupReferenceNames3;
    Procedure TestFixupInstanceNames1;
    Procedure TestFixupInstanceNames2;
    procedure TestFixupInstanceNames3;
    procedure TestFixupInstanceNames4;
    procedure TestFixupInstanceNames5;
    procedure TestRedirectFixupReferences1;
    procedure TestRedirectFixupReferences2;
    procedure TestRedirectFixupReferences3;
    procedure TestRemoveFixupReferences1;
    procedure TestRemoveFixupReferences2;
    procedure TestFixupReferences1;
    procedure TestFixupReferences2;
    procedure TestFixupReferences3;
  end;

procedure RegistertcresrefTests(ARegistry: TNXTestRegistry);

implementation


{$i sllist2.inc}
{$i resref2.inc}

{ ---------------------------------------------------------------------
  Auxiliary routines
  ---------------------------------------------------------------------}

// Simulate Adding RootA to unresolved instances
Function RootAToResolveList(TC : TTestResolveReference) : TUnresolvedInstance;

begin
  Result:=AddToResolveList(TC.RootA);
  TC.UnrA:=Result;
end;

// Simulate Adding RootB to unresolved instances
Function RootBToResolveList(TC : TTestResolveReference) : TUnresolvedInstance;

begin
  Result:=AddToResolveList(TC.RootB);
  TC.UnrB:=Result;
end;

// Simulate RootA.Ref1 -> RootB.A unresolved reference
Function SetupARef1A(TC : TTestResolveReference) : TUnresolvedReference;

begin
  Result:=RootAToResolveList(TC).AddReference(TC.RootA,TC.PropA1,'RootB','A');
end;

// Simulate RootA.Ref1 -> RootB.B unresolved reference
Function SetupARef1B(TC : TTestResolveReference) : TUnresolvedReference;

begin
  Result:=RootAToResolveList(TC).AddReference(TC.RootA,TC.PropA1,'RootB','B');
end;


// Simulate RootA.Ref2 -> RootB.A unresolved reference
Function SetupARef2A(TC : TTestResolveReference) : TUnresolvedReference;

begin
  Result:=RootAToResolveList(TC).AddReference(TC.RootA,TC.PropA2,'RootB','A');
end;
// Simulate RootA.Ref2 -> RootB.B unresolved reference
Function SetupARef2B(TC : TTestResolveReference) : TUnresolvedReference;

begin
  Result:=RootAToResolveList(TC).AddReference(TC.RootA,TC.PropA2,'RootB','B');
end;

// Simulate RootB.Ref2 -> RootA.B unresolved reference
Function SetupBRef2B(TC : TTestResolveReference) : TUnresolvedReference;

begin
  Result:=RootBToResolveList(TC).AddReference(TC.RootB,TC.PropB2,'RootA','B');
end;

Function SetupBRef1A(TC : TTestResolveReference) : TUnresolvedReference;

begin
  Result:=RootBToResolveList(TC).AddReference(TC.RootB,TC.PropB1,'RootA','A');
end;

// Simulate RootB.Ref1 -> RootA.B unresolved reference
Function SetupNRef1B(TC : TTestResolveReference) : TUnresolvedReference;

begin
  Result:=RootBToResolveList(TC).AddReference(TC.RootB,TC.PropB1,'RootA','B');
end;

// Simulate RootA.Ref2 -> RootA.A unresolved reference
Function SetupBRef2A(TC : TTestResolveReference) : TUnresolvedReference;

begin
  Result:=RootBToResolveList(TC).AddReference(TC.RootB,TC.PropB2,'RootA','A');
end;

{ ---------------------------------------------------------------------
  Search callback
  ---------------------------------------------------------------------}

Var
  TI : TTestResolveReference;

Function SearchRoots(Const AName : String) : TComponent;

begin
  Result:=Nil;
  If Assigned(TI) then
    begin
    If CompareText(AName,'RootA')=0 then
      Result:=TI.RootA
    else If CompareText(AName,'RootB')=0 then
      Result:=TI.RootB;
    end;
end;

{ ---------------------------------------------------------------------
  Setup/TearDown
  ---------------------------------------------------------------------}

procedure TTestResolveReference.SetUp;
begin
  TI:=Self;
  RegisterFindGlobalComponentProc(@SearchRoots);
  RootA:=TRootA.Create(Nil);
  RootA.Name:='RootA';
  With TA.Create(RootA) do
    Name:='A';
  With TB.Create(RootA) do
    Name:='B';
  RootB:=TRootB.Create(Nil);
  With TA.Create(RootB) do
    Name:='A';
  With TB.Create(RootB) do
    Name:='B';
  PRopA1:=GetPropInfo(TRootA,'Ref1');
  PRopA2:=GetPropInfo(TRootA,'Ref2');
  PRopB1:=GetPropInfo(TRootB,'Ref1');
  PRopB2:=GetPropInfo(TRootB,'Ref2');
end;

procedure TTestResolveReference.TearDown;
begin
  TI:=Nil;
  UnRegisterFindGlobalComponentProc(@SearchRoots);
  FreeAndNil(NeedResolving);
  FreeAndNil(RootA);
  FreeAndNil(RootB);
end;

{ ---------------------------------------------------------------------
  Actual tests
  ---------------------------------------------------------------------}

procedure TTestResolveReference.TestAddInst1;

Var
  A : TObject;

begin
  A:=AddToResolveList(RootA);
  If Not (A is TUnresolvedInstance) then
    TestContext.Fail('AddToResolveList returns TUnresolvedInstance');
  TestContext.AssertTrue((RootA)=(TUnresolvedInstance(A).Instance), 'UNresolvedinstance.Instance is RootA');
  TestContext.AssertTrue((Nil)=(TUnresolvedInstance(A).Next), 'UNresolvedinstance.Next is nil');
end;

procedure TTestResolveReference.TestAddInst2;

Var
  A,B : TObject;

begin
  A:=AddToResolveList(RootA);
  B:=AddToResolveList(RootA);
  TestContext.AssertTrue((A)=(B), 'UNresolvedinstance.Instance is RootA');
end;

procedure TTestResolveReference.TestAddInst3;

Var
  A,B : TUnresolvedInstance;

begin
  A:=AddToResolveList(RootA);
  B:=AddToResolveList(RootB);
  TestContext.AssertTrue((A)=(B.Next), 'UnresolvedInstances are chained');
end;


procedure TTestResolveReference.TestAdd2;

Var
  R : TUnresolvedReference;

begin
  R:=SetupARef1A(Self);
  If (UnrA=Nil) then
    TestContext.Fail('UnresolvedInstance A not set');
  TestContext.AssertTrue((RootA)=(R.FRoot), 'TUnresolvedReference FRoot is rootA');
  TestContext.AssertTrue((PropA1)=(R.FPropInfo), 'TUnresolvedReference FPropInfo is PropA1');
  TestContext.AssertTrue(('RootB')=(R.FGlobal), 'TUnresolvedReference FGlobal is rootB');
  TestContext.AssertTrue(('A')=(R.FRelative), 'TUnresolvedReference FRelative is A');
  TestContext.AssertTrue((TUnresolvedinstance(UnrA).RootUnresolved)=(R), 'Unresolved is root object');
end;

procedure TTestResolveReference.TestAdd3;

Var
  R1 : TUnresolvedReference;
  R2 : TUnresolvedReference;

begin
  R1:=SetupARef1A(Self);
  R2:=SetupARef2B(Self);
  TestContext.AssertTrue((RootA)=(R2.FRoot), 'TUnresolvedReference FRoot is rootA');
  TestContext.AssertTrue((PropA2)=(R2.FPropInfo), 'TUnresolvedReference FPropInfo is PropA2');
  TestContext.AssertTrue(('RootB')=(R2.FGlobal), 'TUnresolvedReference FGlobal is rootB');
  TestContext.AssertTrue(('B')=(R2.FRelative), 'TUnresolvedReference FRelative is A');
  TestContext.AssertTrue((R1)=(R2.Next), 'Unresolved references are chained');
end;

procedure TTestResolveReference.TestFixupReferenceNames1;

Var
  L : TStringList;
begin
  SetupARef1A(Self);
  L:=TstringList.Create;
  try
    GetFixupReferenceNames(RootA,L);
    TestContext.AssertTrue((1)=(L.Count), 'Number of referenced components in root component RootA is 1');
    TestContext.AssertTrue(('RootB')=(L[0]), 'Root component referred to is RootB');
  finally
    L.Free;
  end;
end;

procedure TTestResolveReference.TestFixupReferenceNames2;

Var
  L : TStringList;
begin
  // Should result in 1 referenced name only.
  SetupARef1A(Self);
  SetupARef2B(Self);
  L:=TstringList.Create;
  try
    GetFixupReferenceNames(RootA,L);
    TestContext.AssertTrue((1)=(L.Count), 'Number of referenced components in root component RootA is 1');
    TestContext.AssertTrue(('RootB')=(L[0]), 'Root component referred to is always RootB');
  finally
    L.Free;
  end;
end;

procedure TTestResolveReference.TestFixupReferenceNames3;

Var
  L : TStringList;
begin
  // Should result in 1 referenced name only.
  SetupARef1A(Self);
  SetupARef2B(Self);
  L:=TstringList.Create;
  try
    GetFixupReferenceNames(RootB,L);
    TestContext.AssertTrue((0)=(L.Count), 'Number of referenced components in root component RootB is 0');
  finally
    L.Free;
  end;
end;

//procedure GetFixupInstanceNames(Root: TComponent; const ReferenceRootName: string; Names: TStrings);

procedure TTestResolveReference.TestFixupInstanceNames1;

Var
  L : TStringList;
begin
  SetupARef1A(Self);
  L:=TstringList.Create;
  try
    GetFixupinstanceNames(RootA,'RootB',L);
    TestContext.AssertTrue((1)=(L.Count), 'Number of references in RootA to component RootB is 1');
    TestContext.AssertTrue(('A')=(L[0]), 'Subcomponent of RootB referenced is A');
  finally
    L.Free;
  end;
end;

procedure TTestResolveReference.TestFixupInstanceNames2;

Var
  L : TStringList;
begin
  SetupARef1A(Self);
  SetupARef2B(Self);
  L:=TstringList.Create;
  try
    GetFixupinstanceNames(RootA,'RootB',L);
    TestContext.AssertTrue((2)=(L.Count), 'Number of references in RootA to component RootB is 2');
    If L.IndexOf('A')=-1 then
      TestContext.Fail('A is not in list of references to RootB');
    If L.IndexOf('B')=-1 then
      TestContext.Fail('B is not in list of references to RootB');
  finally
    L.Free;
  end;
end;

procedure TTestResolveReference.TestFixupInstanceNames3;

Var
  L : TStringList;
begin
  SetupARef1A(Self);
  SetupARef2B(Self);
  L:=TstringList.Create;
  try
    GetFixupinstanceNames(RootA,'RootA',L);
    TestContext.AssertTrue((0)=(L.Count), 'Number of references in RootA to component RootA is 0');
  finally
    L.Free;
  end;
end;

procedure TTestResolveReference.TestFixupInstanceNames4;

Var
  L : TStringList;
begin
  SetupARef1A(Self);
  SetupARef2B(Self);
  L:=TstringList.Create;
  try
    GetFixupinstanceNames(RootB,'RootB',L);
    TestContext.AssertTrue((0)=(L.Count), 'Number of references in RootB to component RootB is 0');
  finally
    L.Free;
  end;
end;

procedure TTestResolveReference.TestFixupInstanceNames5;

Var
  L : TStringList;
begin
  SetupARef1A(Self);
  SetupBRef2B(Self);
  L:=TstringList.Create;
  try
    GetFixupinstanceNames(RootB,'RootB',L);
    TestContext.AssertTrue((0)=(L.Count), 'Number of references in RootB to component RootB is 0');
  finally
    L.Free;
  end;
end;

// procedure RedirectFixupReferences(Root: TComponent; const OldRootName, NewRootName: string);

procedure TTestResolveReference.TestRedirectFixupReferences1;

Var
  L : TStringList;
  R1 : TUnresolvedReference;
  R2 : TUnresolvedReference;

begin
  R1:=SetupARef1A(Self);
  R2:=SetupARef2B(Self);
  RedirectFixupReferences(RootA,'RootB','RootC');
  TestContext.AssertTrue(('RootC')=(R1.FGLobal), 'Redirected R1.Root is RootC');
  TestContext.AssertTrue(('RootC')=(R2.FGLobal), 'Redirected R1.Root is RootC');
end;

procedure TTestResolveReference.TestRedirectFixupReferences2;

Var
  L : TStringList;
  R1 : TUnresolvedReference;
  R2 : TUnresolvedReference;

begin
  R1:=SetupARef1A(Self);
  R2:=SetupBRef2B(Self);
  RedirectFixupReferences(RootA,'RootB','RootC');
  TestContext.AssertTrue(('RootC')=(R1.FGLobal), 'Redirected R1.Root is RootC');
  TestContext.AssertTrue(('RootA')=(R2.FGLobal), 'R2.Root is not redirected, remains RootA');
end;

procedure TTestResolveReference.TestRedirectFixupReferences3;

Var
  R1,R2 : TUnresolvedReference;

begin
  R1:=SetupARef1A(Self);
  R2:=SetupARef2B(Self);
  RedirectFixupReferences(RootA,'RootC','RootQ');
  TestContext.AssertTrue(('RootB')=(R1.FGLobal), 'R1.Root is not redirected, remains RootB');
  TestContext.AssertTrue(('RootB')=(R2.FGLobal), 'R2.Root is not redirected, remains RootB');
end;

// procedure RemoveFixupReferences(Root: TComponent; const RootName: string);
procedure TTestResolveReference.TestRemoveFixupReferences1;

begin
  SetupARef1A(Self);
  SetupARef2A(Self);
  RemoveFixupReferences(RootA,'RootB');
  TestContext.AssertTrue((Nil)=(NeedResolving.Root), 'No references left');
end;

procedure TTestResolveReference.TestRemoveFixupReferences2;

Var
  RA,RB : TUnresolvedInstance;
  R1,R2 : TUnresolvedReference;

begin
  RA:=RootAToResolveList(Self);
  RB:=RootBToResolveList(Self);
  R1:=SetupARef1A(Self);
  R2:=SetupBRef2A(Self);
  RemoveFixupReferences(RootA,'RootB');
  TestContext.AssertTrue((RB)=(NeedResolving.Root), '1 reference left');
end;


procedure TTestResolveReference.TestFixupReferences1;

begin
  SetupARef1A(Self);
  GlobalFixupReferences;
  TestContext.AssertTrue((RootB.FindComponent('A'))=(RootA.Ref1), 'RootA.Ref1 resolved to RootB.A');
  TestContext.AssertTrue((0)=(NeedResolving.Count), 'No more resolving needs to be done');
end;

procedure TTestResolveReference.TestFixupReferences2;

Var
  RI : TUnresolvedInstance;
  UR : TUnresolvedReference;

begin
  // Add Not existing
  RI:=RootBToResolveList(Self);
  UR:=RI.AddReference(RootB,PropB1,'RootC','A');
  // Add existing
  SetupARef1A(Self);
  GlobalFixupReferences;
  TestContext.AssertTrue((RootB.FindComponent('A'))=(RootA.Ref1), 'RootA.Ref1 resolved to RootB.A');
  TestContext.AssertTrue((RI)=(NeedResolving.Root), 'Reference to RootC unresolved');
end;

procedure TTestResolveReference.TestFixupReferences3;

Var
  RI : TUnresolvedInstance;
  UR : TUnresolvedReference;

begin
  // Add Not existing
  RI:=RootAToResolveList(Self);
  UR:=RI.AddReference(RootA,PropA2,'RootC','A');
  // Add existing
  SetupARef1A(Self);
  GlobalFixupReferences;
  TestContext.AssertTrue((RootB.FindComponent('A'))=(RootA.Ref1), 'RootA.Ref1 resolved to RootB.A');
  TestContext.AssertTrue((RI)=(NeedResolving.Root), 'Reference to RootC unresolved');
  TestContext.AssertTrue((RI.RootUnresolved)=(UR), 'Reference to RootC unresolved');
end;

constructor TTestResolveReference.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestResolveReferenceTestAddInst1(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestAddInst1');
  try
    lFixture.SetUp;
    try lFixture.TestAddInst1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestAddInst2(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestAddInst2');
  try
    lFixture.SetUp;
    try lFixture.TestAddInst2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestAddInst3(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestAddInst3');
  try
    lFixture.SetUp;
    try lFixture.TestAddInst3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestAdd2(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestAdd2');
  try
    lFixture.SetUp;
    try lFixture.TestAdd2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestAdd3(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestAdd3');
  try
    lFixture.SetUp;
    try lFixture.TestAdd3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestFixupReferenceNames1(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestFixupReferenceNames1');
  try
    lFixture.SetUp;
    try lFixture.TestFixupReferenceNames1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestFixupReferenceNames2(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestFixupReferenceNames2');
  try
    lFixture.SetUp;
    try lFixture.TestFixupReferenceNames2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestFixupReferenceNames3(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestFixupReferenceNames3');
  try
    lFixture.SetUp;
    try lFixture.TestFixupReferenceNames3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestFixupInstanceNames1(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestFixupInstanceNames1');
  try
    lFixture.SetUp;
    try lFixture.TestFixupInstanceNames1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestFixupInstanceNames2(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestFixupInstanceNames2');
  try
    lFixture.SetUp;
    try lFixture.TestFixupInstanceNames2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestFixupInstanceNames3(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestFixupInstanceNames3');
  try
    lFixture.SetUp;
    try lFixture.TestFixupInstanceNames3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestFixupInstanceNames4(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestFixupInstanceNames4');
  try
    lFixture.SetUp;
    try lFixture.TestFixupInstanceNames4; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestFixupInstanceNames5(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestFixupInstanceNames5');
  try
    lFixture.SetUp;
    try lFixture.TestFixupInstanceNames5; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestRedirectFixupReferences1(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestRedirectFixupReferences1');
  try
    lFixture.SetUp;
    try lFixture.TestRedirectFixupReferences1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestRedirectFixupReferences2(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestRedirectFixupReferences2');
  try
    lFixture.SetUp;
    try lFixture.TestRedirectFixupReferences2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestRedirectFixupReferences3(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestRedirectFixupReferences3');
  try
    lFixture.SetUp;
    try lFixture.TestRedirectFixupReferences3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestRemoveFixupReferences1(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestRemoveFixupReferences1');
  try
    lFixture.SetUp;
    try lFixture.TestRemoveFixupReferences1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestRemoveFixupReferences2(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestRemoveFixupReferences2');
  try
    lFixture.SetUp;
    try lFixture.TestRemoveFixupReferences2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestFixupReferences1(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestFixupReferences1');
  try
    lFixture.SetUp;
    try lFixture.TestFixupReferences1; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestFixupReferences2(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestFixupReferences2');
  try
    lFixture.SetUp;
    try lFixture.TestFixupReferences2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestResolveReferenceTestFixupReferences3(AContext: TNXTestContext);
var lFixture: TTestResolveReference;
begin
  lFixture:=TTestResolveReference.Create(AContext, 'TestFixupReferences3');
  try
    lFixture.SetUp;
    try lFixture.TestFixupReferences3; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertcresrefTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tcresref.TTestResolveReference');
  lSuite.AddTest('TestAddInst1', @RunTTestResolveReferenceTestAddInst1, 'streaming');
  lSuite.AddTest('TestAddInst2', @RunTTestResolveReferenceTestAddInst2, 'streaming');
  lSuite.AddTest('TestAddInst3', @RunTTestResolveReferenceTestAddInst3, 'streaming');
  lSuite.AddTest('TestAdd2', @RunTTestResolveReferenceTestAdd2, 'streaming');
  lSuite.AddTest('TestAdd3', @RunTTestResolveReferenceTestAdd3, 'streaming');
  lSuite.AddTest('TestFixupReferenceNames1', @RunTTestResolveReferenceTestFixupReferenceNames1, 'streaming');
  lSuite.AddTest('TestFixupReferenceNames2', @RunTTestResolveReferenceTestFixupReferenceNames2, 'streaming');
  lSuite.AddTest('TestFixupReferenceNames3', @RunTTestResolveReferenceTestFixupReferenceNames3, 'streaming');
  lSuite.AddTest('TestFixupInstanceNames1', @RunTTestResolveReferenceTestFixupInstanceNames1, 'streaming');
  lSuite.AddTest('TestFixupInstanceNames2', @RunTTestResolveReferenceTestFixupInstanceNames2, 'streaming');
  lSuite.AddTest('TestFixupInstanceNames3', @RunTTestResolveReferenceTestFixupInstanceNames3, 'streaming');
  lSuite.AddTest('TestFixupInstanceNames4', @RunTTestResolveReferenceTestFixupInstanceNames4, 'streaming');
  lSuite.AddTest('TestFixupInstanceNames5', @RunTTestResolveReferenceTestFixupInstanceNames5, 'streaming');
  lSuite.AddTest('TestRedirectFixupReferences1', @RunTTestResolveReferenceTestRedirectFixupReferences1, 'streaming');
  lSuite.AddTest('TestRedirectFixupReferences2', @RunTTestResolveReferenceTestRedirectFixupReferences2, 'streaming');
  lSuite.AddTest('TestRedirectFixupReferences3', @RunTTestResolveReferenceTestRedirectFixupReferences3, 'streaming');
  lSuite.AddTest('TestRemoveFixupReferences1', @RunTTestResolveReferenceTestRemoveFixupReferences1, 'streaming');
  lSuite.AddTest('TestRemoveFixupReferences2', @RunTTestResolveReferenceTestRemoveFixupReferences2, 'streaming');
  lSuite.AddTest('TestFixupReferences1', @RunTTestResolveReferenceTestFixupReferences1, 'streaming');
  lSuite.AddTest('TestFixupReferences2', @RunTTestResolveReferenceTestFixupReferences2, 'streaming');
  lSuite.AddTest('TestFixupReferences3', @RunTTestResolveReferenceTestFixupReferences3, 'streaming');
end;


initialization

  InitCriticalSection(ResolveSection);

finalization
  FreeAndNil(NeedResolving);
  DoneCriticalsection(ResolveSection);
end.

