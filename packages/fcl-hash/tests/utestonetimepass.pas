unit utestonetimepass;

{$mode ObjFPC}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, onetimepass ;

type

  { TTestOnetimePass }

  TTestOnetimePass = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  public
    Procedure Test1Interval;
    Procedure Test2Intervals;
    Procedure TestValid1;
    Procedure TestInValid1;
    Procedure TestGen;
  end;

procedure RegisterutestonetimepassTests(ARegistry: TNXTestRegistry);

implementation

Const
  Secret = 'MFRGGZDFMZTWQ2LK';

Procedure TTestOnetimePass.Test1Interval;

begin
  TestContext.AssertTrue((765705)=(HOTPCalculateToken(Secret, 1)), '1 interval');
end;

procedure TTestOnetimePass.Test2Intervals;
begin
  TestContext.AssertTrue((816065)=(HOTPCalculateToken(Secret, 2)), '2 interval');
end;

procedure TTestOnetimePass.TestValid1;

Var
  C,Tok : LongInt;

begin
  C:=1;
  Tok:=TOTPCalculateToken(Secret);
  TestContext.AssertTrue(TOTPValidate(Secret,Tok,1,C), 'Valid');
end;

procedure TTestOnetimePass.TestInValid1;
Var
  C,Tok : LongInt;

begin
  C:=1;
  Tok:=TOTPCalculateToken(Secret);
  TestContext.AssertTrue(not (TOTPValidate(Secret,Tok+1,1,C)), 'Invalid');
end;

procedure TTestOnetimePass.TestGen;

var
  lSecret : String;
  C,Tok : LongInt;

begin
  c:=1;
  lSecret:=TOTPSharedSecret();
  TestContext.AssertTrue((16)=(Length(lSecret)), 'Length');
  Tok:=TOTPCalculateToken(lSecret);
  TestContext.AssertTrue(TOTPValidate(lSecret,Tok,1,C), 'Valid');
end;


constructor TTestOnetimePass.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestOnetimePassTest1Interval(AContext: TNXTestContext);
var lFixture: TTestOnetimePass;
begin
  lFixture:=TTestOnetimePass.Create(AContext, 'Test1Interval');
  try
    lFixture.Test1Interval;
  finally lFixture.Free; end;
end;

procedure RunTTestOnetimePassTest2Intervals(AContext: TNXTestContext);
var lFixture: TTestOnetimePass;
begin
  lFixture:=TTestOnetimePass.Create(AContext, 'Test2Intervals');
  try
    lFixture.Test2Intervals;
  finally lFixture.Free; end;
end;

procedure RunTTestOnetimePassTestValid1(AContext: TNXTestContext);
var lFixture: TTestOnetimePass;
begin
  lFixture:=TTestOnetimePass.Create(AContext, 'TestValid1');
  try
    lFixture.TestValid1;
  finally lFixture.Free; end;
end;

procedure RunTTestOnetimePassTestInValid1(AContext: TNXTestContext);
var lFixture: TTestOnetimePass;
begin
  lFixture:=TTestOnetimePass.Create(AContext, 'TestInValid1');
  try
    lFixture.TestInValid1;
  finally lFixture.Free; end;
end;

procedure RunTTestOnetimePassTestGen(AContext: TNXTestContext);
var lFixture: TTestOnetimePass;
begin
  lFixture:=TTestOnetimePass.Create(AContext, 'TestGen');
  try
    lFixture.TestGen;
  finally lFixture.Free; end;
end;

procedure RegisterutestonetimepassTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('utestonetimepass.TTestOnetimePass');
  lSuite.AddTest('Test1Interval', @RunTTestOnetimePassTest1Interval);
  lSuite.AddTest('Test2Intervals', @RunTTestOnetimePassTest2Intervals);
  lSuite.AddTest('TestValid1', @RunTTestOnetimePassTestValid1);
  lSuite.AddTest('TestInValid1', @RunTTestOnetimePassTestInValid1);
  lSuite.AddTest('TestGen', @RunTTestOnetimePassTestGen);
end;

end.
