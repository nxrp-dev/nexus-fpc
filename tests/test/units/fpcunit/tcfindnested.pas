unit tcfindnested;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils;

type

  { TTestFindComponent }

  TTestFindComponent= class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Private
    R,A,B,AC,BC,D : TComponent;
    Function CreateNamed(AOwner : TComponent; AName : String) : TComponent;
    Procedure CheckFind(Root : TComponent; AName : String; Expected : TComponent);
  Protected
    procedure SetUp; virtual;
    procedure TearDown; virtual;
  public
    procedure TestFindA;
    procedure TestEmpty;
    procedure TestFindB;
    procedure TestFindACaseDiffer;
    procedure TestFindBCaseDiffer;
    procedure TestFindNonExist;
    procedure TestFindNonExistSub;
    procedure TestFindOwner;
    procedure TestFindOwnerNameOwner;
    procedure TestFindOwnerNamed;
    procedure TestFindOwnerSelf;
    procedure TestFindSubA;
    procedure TestFindSubB;
    procedure TestFindSubNoC;
  end;

procedure RegistertcfindnestedTests(ARegistry: TNXTestRegistry);

implementation
{$DEFINE USENEW}
{$IFDEF USENEW}
Function FindNestedComponent(Root : TComponent; APath : String; CStyle : Boolean = True) : TComponent;

  Function GetNextName : String; inline;

  Var
    P : Integer;
    CM : Boolean;

  begin
    P:=Pos('.',APath);
    CM:=False;
    If (P=0) then
      begin
      If CStyle then
        begin
        P:=Pos('->',APath);
        CM:=P<>0;
        end;
      If (P=0) Then
        P:=Length(APath)+1;
      end;
    Result:=Copy(APath,1,P-1);
    Delete(APath,1,P+Ord(CM));
  end;

Var
  C : TComponent;
  S : String;
begin
  If (APath='') then
    Result:=Nil
  else
    begin
    Result:=Root;
    While (APath<>'') And (Result<>Nil) do
      begin
      C:=Result;
      S:=Uppercase(GetNextName);
      Result:=C.FindComponent(S);
      If (Result=Nil) And (S='OWNER') then
        Result:=C;
      end;
    end;
end;
{$ENDIF}

procedure TTestFindComponent.TestEmpty;

begin
  // Delphi crashes on this test, don't think we should copy that :-)
  CheckFind(R,'',Nil);
end;

procedure TTestFindComponent.TestFindA;

begin
  CheckFind(R,'AAAA',A);
end;

procedure TTestFindComponent.TestFindB;

begin
  CheckFind(R,'BBBB',B);
end;

procedure TTestFindComponent.TestFindACaseDiffer;
begin
  CheckFind(R,'aaaa',A);
end;

procedure TTestFindComponent.TestFindBCaseDiffer;
begin
  CheckFind(R,'bbbb',B);
end;

procedure TTestFindComponent.TestFindNonExistSub;
begin
  CheckFind(R,'aaaa.bbbb',Nil);
end;

procedure TTestFindComponent.TestFindNonExist;
begin
  CheckFind(R,'qqqq',Nil);
end;

procedure TTestFindComponent.TestFindSubA;
begin
  CheckFind(R,'aaaa.cccc',ac);
end;

procedure TTestFindComponent.TestFindSubB;
begin
  CheckFind(R,'bbbb.cccc',bc);
end;

procedure TTestFindComponent.TestFindSubNoC;
begin
  CheckFind(R,'cccc',nil);
end;

procedure TTestFindComponent.TestFindOwnerNamed;
begin
  CheckFind(R,'BBBB.OWNER',D);
end;

procedure TTestFindComponent.TestFindOwner;
begin
  CheckFind(B,'OWNER',D);
end;

procedure TTestFindComponent.TestFindOwnerSelf;
begin
  CheckFind(A,'OWNER',A);
end;

procedure TTestFindComponent.TestFindOwnerNameOwner;
begin
  CheckFind(B,'OWNER.OWNER',D);
end;

function TTestFindComponent.CreateNamed(AOwner: TComponent; AName: String
  ): TComponent;
begin
  Result:=TComponent.Create(AOwner);
  Result.Name:=AName;
end;

procedure TTestFindComponent.CheckFind(Root: TComponent; AName: String;
  Expected: TComponent);



  Function FN (C : TComponent): String;

  begin
    If (C=Nil) then
      Result:='<Nil>'
    else
      Result:=C.GetNamePath;
  end;

Var
  Res : TComponent;

begin
  Res:=FindNestedComponent(Root,AName);
  If Res<>Expected then
    TestContext.Fail('Search for "'+AName+'" failed : Found "'+FN(Res)+'", expected : "'+Fn(Expected)+'"');
end;

procedure TTestFindComponent.SetUp;
begin
  R:=CreateNamed(Nil,'Root');
  A:=CreateNamed(R,'AAAA');
  B:=CreateNamed(R,'BBBB');
  AC:=CreateNamed(A,'CCCC');
  BC:=CreateNamed(B,'CCCC');
  D:=CreateNamed(B,'OWNER');

end;

procedure TTestFindComponent.TearDown;
begin
  FreeAndNil(R); // Will free the rest.
  A:=Nil;
  B:=Nil;
  AC:=Nil;
  BC:=Nil;
  D:=Nil;
end;



constructor TTestFindComponent.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestFindComponentTestFindA(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindA');
  try
    lFixture.SetUp;
    try lFixture.TestFindA; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestEmpty(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestEmpty');
  try
    lFixture.SetUp;
    try lFixture.TestEmpty; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindB(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindB');
  try
    lFixture.SetUp;
    try lFixture.TestFindB; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindACaseDiffer(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindACaseDiffer');
  try
    lFixture.SetUp;
    try lFixture.TestFindACaseDiffer; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindBCaseDiffer(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindBCaseDiffer');
  try
    lFixture.SetUp;
    try lFixture.TestFindBCaseDiffer; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindNonExist(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindNonExist');
  try
    lFixture.SetUp;
    try lFixture.TestFindNonExist; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindNonExistSub(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindNonExistSub');
  try
    lFixture.SetUp;
    try lFixture.TestFindNonExistSub; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindOwner(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindOwner');
  try
    lFixture.SetUp;
    try lFixture.TestFindOwner; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindOwnerNameOwner(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindOwnerNameOwner');
  try
    lFixture.SetUp;
    try lFixture.TestFindOwnerNameOwner; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindOwnerNamed(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindOwnerNamed');
  try
    lFixture.SetUp;
    try lFixture.TestFindOwnerNamed; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindOwnerSelf(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindOwnerSelf');
  try
    lFixture.SetUp;
    try lFixture.TestFindOwnerSelf; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindSubA(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindSubA');
  try
    lFixture.SetUp;
    try lFixture.TestFindSubA; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindSubB(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindSubB');
  try
    lFixture.SetUp;
    try lFixture.TestFindSubB; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestFindComponentTestFindSubNoC(AContext: TNXTestContext);
var lFixture: TTestFindComponent;
begin
  lFixture:=TTestFindComponent.Create(AContext, 'TestFindSubNoC');
  try
    lFixture.SetUp;
    try lFixture.TestFindSubNoC; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegistertcfindnestedTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('tcfindnested.TTestFindComponent');
  lSuite.AddTest('TestFindA', @RunTTestFindComponentTestFindA);
  lSuite.AddTest('TestEmpty', @RunTTestFindComponentTestEmpty);
  lSuite.AddTest('TestFindB', @RunTTestFindComponentTestFindB);
  lSuite.AddTest('TestFindACaseDiffer', @RunTTestFindComponentTestFindACaseDiffer);
  lSuite.AddTest('TestFindBCaseDiffer', @RunTTestFindComponentTestFindBCaseDiffer);
  lSuite.AddTest('TestFindNonExist', @RunTTestFindComponentTestFindNonExist);
  lSuite.AddTest('TestFindNonExistSub', @RunTTestFindComponentTestFindNonExistSub);
  lSuite.AddTest('TestFindOwner', @RunTTestFindComponentTestFindOwner);
  lSuite.AddTest('TestFindOwnerNameOwner', @RunTTestFindComponentTestFindOwnerNameOwner);
  lSuite.AddTest('TestFindOwnerNamed', @RunTTestFindComponentTestFindOwnerNamed);
  lSuite.AddTest('TestFindOwnerSelf', @RunTTestFindComponentTestFindOwnerSelf);
  lSuite.AddTest('TestFindSubA', @RunTTestFindComponentTestFindSubA);
  lSuite.AddTest('TestFindSubB', @RunTTestFindComponentTestFindSubB);
  lSuite.AddTest('TestFindSubNoC', @RunTTestFindComponentTestFindSubNoC);
end;

end.
