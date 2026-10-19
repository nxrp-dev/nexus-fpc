{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2023 by Michael Van Canneyt
    member of the Free Pascal development team

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}

unit utcpoint;

{$mode ObjFPC}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, types, utmathvectorbase, system.math.vectors;

type
    { TTestPoint3D }

  TTestPoint3D = Class(TCMathVectorsBase)
  Private
    FP : Array[1..3] of TPoint3D;
    procedure ClearPoints;
    function GetP(aIndex: Integer): TPoint3D;
    procedure SetP(aIndex: Integer; aValue: TPoint3D);
  Protected
    procedure SetUp; override;
    procedure TearDown; override;
    Property P1 : TPoint3D Index 1 Read GetP Write SetP;
    Property P2 : TPoint3D Index 2 Read GetP Write SetP;
    Property P3 : TPoint3D Index 3 Read GetP Write SetP;
  public
    procedure TestHookUp;
    Procedure TestZero;
    Procedure TestCreate;
    Procedure TestCreate2DPointAndZ;
    Procedure TestCreateVector3D;
    Procedure TestAdd;
    Procedure TestMultiplyFactor;
    Procedure TestMultiply;
    Procedure TestSubtract;
    Procedure TestEqual;
    Procedure TestDivide;
    Procedure TestUnEqual;
    Procedure TestUnaryMinus;
    Procedure TestAngleCosine;
    Procedure TestCrossProduct;
    Procedure TestDistance;
    Procedure TestDotProduct;
    Procedure TestEqualsTo;
    Procedure TestLength;
    Procedure TestMidPoint;
    Procedure TestNormalize;
    Procedure TestOffsetPoint;
    Procedure TestOffsetDelta;
    Procedure TestReflect;
    Procedure TestRotate;
  end;


procedure RegisterutcpointTests(ARegistry: TNXTestRegistry);

implementation
{ TTestPoint3D }

procedure TTestPoint3D.ClearPoints;

var
  I : integer;

begin
  For I:=1 to 3 do
    begin
    FP[I].X:=0;
    FP[I].Y:=0;
    FP[I].Z:=0;
    end;
end;

function TTestPoint3D.GetP(aIndex: Integer): TPoint3D;
begin
  Result.X:=FP[AIndex].X;
  Result.Y:=FP[AIndex].Y;
  Result.Z:=FP[AIndex].Z;
end;

procedure TTestPoint3D.SetP(aIndex: Integer; aValue: TPoint3D);
begin
  FP[AIndex].X:=aValue.X;
  FP[AIndex].Y:=aValue.Y;
  FP[AIndex].Z:=aValue.Z;
end;

procedure TTestPoint3D.SetUp;
begin
  inherited SetUp;
  ClearPoints;
end;

procedure TTestPoint3D.TearDown;
begin
  inherited TearDown;
end;

procedure TTestPoint3D.TestHookUp;
var
  I : Integer;
begin
  For I:=1 to 3 do
    begin
    TestContext.AssertTrue((0.0)=(FP[I].X), 'Point3D '+intTostr(i)+'.X');
    TestContext.AssertTrue((0.0)=(FP[I].Y), 'Point3D '+intTostr(i)+'.Y');
    TestContext.AssertTrue((0.0)=(FP[I].Z), 'Point3D '+intTostr(i)+'.Z');
    end;
end;

procedure TTestPoint3D.TestZero;
begin
  P1:=TPoint3D.Zero;
  AssertPoint3D('Zero',0,0,0,P1);
end;

procedure TTestPoint3D.TestCreate;
begin
  P1:=TPoint3D.Create(1,2,3);
  AssertPoint3D('Create',1,2,3,P1);
end;

procedure TTestPoint3D.TestCreate2DPointAndZ;
begin
  P1:=TPoint3D.Create(PointF(1,2),3);
  AssertPoint3D('Create',1,2,3,P1);
end;

procedure TTestPoint3D.TestCreateVector3D;
begin
  P1:=TPoint3D.Create([1,2,3,4]);
  AssertPoint3D('Create',1,2,3,P1);
end;

procedure TTestPoint3D.TestAdd;
begin
  P1:=TPoint3D.Create(1,2,3);
  P2:=TPoint3D.Create(5,4,3);
  P3:=P2+P1;
  AssertPoint3D('Add 1',6,6,6,P3);
  P2:=TPoint3D.Create(7,8,9);
  P3:=P2+P1;
  AssertPoint3D('Add 2',8,10,12,P3);
end;

procedure TTestPoint3D.TestMultiplyFactor;
begin
  P1:=TPoint3D.Create(1,2,3);
  P2:=P1*3;
  AssertPoint3D('Factor 1',3,6,9,P2);
  P2:=2*P1;
  AssertPoint3D('Factor 2',2,4,6,P2);
end;

procedure TTestPoint3D.TestMultiply;
begin
  P1:=TPoint3D.Create(1,2,3);
  P2:=TPoint3D.Create(5,4,3);
  P3:=P2*P1;
  AssertPoint3D('Create',5,8,9,P3);
end;

procedure TTestPoint3D.TestSubtract;
begin
  P1:=TPoint3D.Create(1,2,3);
  P2:=TPoint3D.Create(5,4,3);
  P3:=P2-P1;
  AssertPoint3D('Subtract 1',4,2,0,P3);
  P2:=TPoint3D.Create(7,8,9);
  P3:=P2-P1;
  AssertPoint3D('Subtract 2',6,6,6,P3);
end;

procedure TTestPoint3D.TestEqual;
begin
  P1:=TPoint3D.Create(1,2,3);
  P2:=TPoint3D.Create(5,4,3);
  TestContext.AssertTrue(not (P1=P2), 'Equal NOk');
  P2:=TPoint3D.Create(1,2,3);
  TestContext.AssertTrue(P1=P2, 'Equal OK');
end;

procedure TTestPoint3D.TestDivide;
begin
  P1:=TPoint3D.Create(3,6,9);
  P2:=P1/3;
  AssertPoint3D('Factor 1',1,2,3,P2);
end;

procedure TTestPoint3D.TestUnEqual;
begin
  P1:=TPoint3D.Create(1,2,3);
  P2:=TPoint3D.Create(5,4,3);
  TestContext.AssertTrue(P1<>P2, 'unEqual Ok');
  P2:=TPoint3D.Create(1,2,3);
  TestContext.AssertTrue(not (P1<>P2), 'unEqual OK');
end;

procedure TTestPoint3D.TestUnaryMinus;
begin
  P1:=TPoint3D.Create(1,2,3);
  P2:=-P1;
  AssertPoint3D('Unary minus',-1,-2,-3,P2);
end;

procedure TTestPoint3D.TestAngleCosine;
begin
  P1:=TPoint3D.Create(1,0,0);
  P2:=TPoint3D.Create(0,1,0);
  TestContext.AssertTrue((0)=(P1.AngleCosine(P2)), 'Angle');
  P1:=TPoint3D.Create(1,0,0);
  P2:=TPoint3D.Create(0,0,1);
  TestContext.AssertTrue((0)=(P1.AngleCosine(P2)), 'Angle');
  P1:=TPoint3D.Create(0,1,0);
  P2:=TPoint3D.Create(0,0,1);
  TestContext.AssertTrue((0)=(P1.AngleCosine(P2)), 'Angle');
  P1:=TPoint3D.Create(0,1,0);
  P2:=TPoint3D.Create(1,1,0);
  TestContext.AssertTrue(Abs((c45)-(P1.AngleCosine(P2)))<=TEpsilon.Vector, 'Angle');
end;

procedure TTestPoint3D.TestCrossProduct;
begin
  P1:=TPoint3D.Create(1,1,0);
  P2:=TPoint3D.Create(2,2,0);
  P3:=P2.CrossProduct(P1);
  AssertPoint3D('T1',0,0,0,P3);
  P1:=TPoint3D.Create(1,1,0);
  P2:=TPoint3D.Create(2,2,0);
  P3:=P2.CrossProduct(P1);
  AssertPoint3D('T2',0,0,0,P3);
end;

procedure TTestPoint3D.TestDistance;
begin
  P1:=TPoint3D.Create(1,1,0);
  P2:=TPoint3D.Create(1,2,0);
  TestContext.AssertTrue((1)=(P1.Distance(P2)), 'Dist 1,');
  P1:=TPoint3D.Create(0,1,1);
  P2:=TPoint3D.Create(0,2,1);
  TestContext.AssertTrue((1)=(P1.Distance(P2)), 'Dist 2,');
  P1:=TPoint3D.Create(0,0,0);
  P2:=TPoint3D.Create(1,1,0);
  TestContext.AssertTrue(Abs((c45*2)-(P1.Distance(P2)))<=TEpsilon.Vector, 'Dist 3,');
end;

procedure TTestPoint3D.TestDotProduct;
begin
  P1:=TPoint3D.Create(3,4,9);
  P2:=TPoint3D.Create(3,4,9);
  TestContext.AssertTrue((9+16+81)=(P1.DotProduct(P2)), 'Test 1');
  P2:=TPoint3D.Create(1,1,0);
  TestContext.AssertTrue((7)=(P1.DotProduct(P2)), 'Test 1');
end;

procedure TTestPoint3D.TestEqualsTo;
begin
  P1:=TPoint3D.Create(3,4,9);
  P2:=TPoint3D.Create(3,4,9);
  TestContext.AssertTrue(P1.EqualsTo(P2), 'Test 1');
  P2:=TPoint3D.Create(1,1,1);
  TestContext.AssertTrue(not (P1.EqualsTo(P2)), 'Test 2');
end;

procedure TTestPoint3D.TestLength;
begin
  P1:=TPoint3D.Create(1,0,0);
  TestContext.AssertTrue((1)=(P1.Length), 'Dist 1,');
  P1:=TPoint3D.Create(0,1,1);
  TestContext.AssertTrue(Abs((c45*2)-(P1.Length))<=TEpsilon.Vector, 'Dist 2,');
  P1:=TPoint3D.Create(1,1,1);
  TestContext.AssertTrue(Abs((Sqrt(3))-(P1.Length))<=TEpsilon.Vector, 'Dist 3,');
end;

procedure TTestPoint3D.TestMidPoint;
begin
  P1:=TPoint3D.Create(0,0,1);
  P2:=TPoint3D.Create(0,2,1);
  AssertPoint3D('Midpoint1',0,1,1,P1.MidPoint(P2));
  P1:=TPoint3D.Create(1,0,0);
  P2:=TPoint3D.Create(0,1,0);
  AssertPoint3D('Midpoint2',0.5,0.5,0,P1.MidPoint(P2));
end;

procedure TTestPoint3D.TestNormalize;
begin
  P1:=TPoint3D.Create(1,1,1);
  P2:=P1.Normalize;
  AssertPoint3D('Normalize 1',0.5773,0.5773,0.5773,P2);
  P1:=TPoint3D.Create(0,0,1);
  P2:=P1.Normalize;
  AssertPoint3D('Normalize 2',0,0,1,P2);
  P1:=TPoint3D.Create(1,0,0);
  P2:=P1.Normalize;
  AssertPoint3D('Normalize 3',1,0,0,P2);
end;

procedure TTestPoint3D.TestOffsetPoint;

Var
  P : TPoint3D; // Cannot use property

begin
  P:=TPoint3D.Create(1,2,3);
  P.Offset(Point3D(4,5,6));
  AssertPoint3D('Off',5,7,9,P);
end;

procedure TTestPoint3D.TestOffsetDelta;

Var
  P : TPoint3D; // Cannot use property

begin
  P:=TPoint3D.Create(0,0,0);
  P.Offset(1,2,3);
  AssertPoint3D('Off',1,2,3,P);
end;

procedure TTestPoint3D.TestReflect;

// P2 is normal of reflecting surface: X,Y plane.

begin
  P1:=TPoint3D.Create(0,0,1);
  P2:=TPoint3D.Create(0,0,1);
  P3:=P1.Reflect(P2);
  AssertPoint3D('Reflect 1',0,0,-1,P3);
  P1:=TPoint3D.Create(0,-1,-1);
  P3:=P1.Reflect(P2);
  AssertPoint3D('Reflect 2',0,-1,1,P3);
end;

procedure TTestPoint3D.TestRotate;
begin
  P1:=TPoint3D.Create(1,0,0);
  P2:=TPoint3D.Create(0,0,1); // Z-axis
  P3:=P1.Rotate(P2,Pi/2);
  AssertPoint3D('Rotate 1',0,1,0,P3);
  P2:=TPoint3D.Create(0,1,0); // Y-axis
  P3:=P1.Rotate(P2,Pi/2);
  AssertPoint3D('Rotate 2',0,0,-1,P3); // Z is pointing down!
end;


procedure RunTTestPoint3DTestHookUp(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestHookUp');
  try
    lFixture.SetUp;
    try lFixture.TestHookUp; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestZero(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestZero');
  try
    lFixture.SetUp;
    try lFixture.TestZero; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestCreate(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestCreate');
  try
    lFixture.SetUp;
    try lFixture.TestCreate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestCreate2DPointAndZ(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestCreate2DPointAndZ');
  try
    lFixture.SetUp;
    try lFixture.TestCreate2DPointAndZ; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestCreateVector3D(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestCreateVector3D');
  try
    lFixture.SetUp;
    try lFixture.TestCreateVector3D; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestAdd(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestMultiplyFactor(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestMultiplyFactor');
  try
    lFixture.SetUp;
    try lFixture.TestMultiplyFactor; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestMultiply(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestMultiply');
  try
    lFixture.SetUp;
    try lFixture.TestMultiply; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestSubtract(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestSubtract');
  try
    lFixture.SetUp;
    try lFixture.TestSubtract; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestEqual(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestEqual');
  try
    lFixture.SetUp;
    try lFixture.TestEqual; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestDivide(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestDivide');
  try
    lFixture.SetUp;
    try lFixture.TestDivide; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestUnEqual(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestUnEqual');
  try
    lFixture.SetUp;
    try lFixture.TestUnEqual; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestUnaryMinus(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestUnaryMinus');
  try
    lFixture.SetUp;
    try lFixture.TestUnaryMinus; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestAngleCosine(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestAngleCosine');
  try
    lFixture.SetUp;
    try lFixture.TestAngleCosine; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestCrossProduct(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestCrossProduct');
  try
    lFixture.SetUp;
    try lFixture.TestCrossProduct; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestDistance(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestDistance');
  try
    lFixture.SetUp;
    try lFixture.TestDistance; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestDotProduct(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestDotProduct');
  try
    lFixture.SetUp;
    try lFixture.TestDotProduct; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestEqualsTo(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestEqualsTo');
  try
    lFixture.SetUp;
    try lFixture.TestEqualsTo; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestLength(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestLength');
  try
    lFixture.SetUp;
    try lFixture.TestLength; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestMidPoint(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestMidPoint');
  try
    lFixture.SetUp;
    try lFixture.TestMidPoint; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestNormalize(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestNormalize');
  try
    lFixture.SetUp;
    try lFixture.TestNormalize; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestOffsetPoint(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestOffsetPoint');
  try
    lFixture.SetUp;
    try lFixture.TestOffsetPoint; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestOffsetDelta(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestOffsetDelta');
  try
    lFixture.SetUp;
    try lFixture.TestOffsetDelta; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestReflect(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestReflect');
  try
    lFixture.SetUp;
    try lFixture.TestReflect; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestPoint3DTestRotate(AContext: TNXTestContext);
var lFixture: TTestPoint3D;
begin
  lFixture:=TTestPoint3D.Create(AContext, 'TestRotate');
  try
    lFixture.SetUp;
    try lFixture.TestRotate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegisterutcpointTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('utcpoint.TTestPoint3D');
  lSuite.AddTest('TestHookUp', @RunTTestPoint3DTestHookUp, 'math-vectors');
  lSuite.AddTest('TestZero', @RunTTestPoint3DTestZero, 'math-vectors');
  lSuite.AddTest('TestCreate', @RunTTestPoint3DTestCreate, 'math-vectors');
  lSuite.AddTest('TestCreate2DPointAndZ', @RunTTestPoint3DTestCreate2DPointAndZ, 'math-vectors');
  lSuite.AddTest('TestCreateVector3D', @RunTTestPoint3DTestCreateVector3D, 'math-vectors');
  lSuite.AddTest('TestAdd', @RunTTestPoint3DTestAdd, 'math-vectors');
  lSuite.AddTest('TestMultiplyFactor', @RunTTestPoint3DTestMultiplyFactor, 'math-vectors');
  lSuite.AddTest('TestMultiply', @RunTTestPoint3DTestMultiply, 'math-vectors');
  lSuite.AddTest('TestSubtract', @RunTTestPoint3DTestSubtract, 'math-vectors');
  lSuite.AddTest('TestEqual', @RunTTestPoint3DTestEqual, 'math-vectors');
  lSuite.AddTest('TestDivide', @RunTTestPoint3DTestDivide, 'math-vectors');
  lSuite.AddTest('TestUnEqual', @RunTTestPoint3DTestUnEqual, 'math-vectors');
  lSuite.AddTest('TestUnaryMinus', @RunTTestPoint3DTestUnaryMinus, 'math-vectors');
  lSuite.AddTest('TestAngleCosine', @RunTTestPoint3DTestAngleCosine, 'math-vectors');
  lSuite.AddTest('TestCrossProduct', @RunTTestPoint3DTestCrossProduct, 'math-vectors');
  lSuite.AddTest('TestDistance', @RunTTestPoint3DTestDistance, 'math-vectors');
  lSuite.AddTest('TestDotProduct', @RunTTestPoint3DTestDotProduct, 'math-vectors');
  lSuite.AddTest('TestEqualsTo', @RunTTestPoint3DTestEqualsTo, 'math-vectors');
  lSuite.AddTest('TestLength', @RunTTestPoint3DTestLength, 'math-vectors');
  lSuite.AddTest('TestMidPoint', @RunTTestPoint3DTestMidPoint, 'math-vectors');
  lSuite.AddTest('TestNormalize', @RunTTestPoint3DTestNormalize, 'math-vectors');
  lSuite.AddTest('TestOffsetPoint', @RunTTestPoint3DTestOffsetPoint, 'math-vectors');
  lSuite.AddTest('TestOffsetDelta', @RunTTestPoint3DTestOffsetDelta, 'math-vectors');
  lSuite.AddTest('TestReflect', @RunTTestPoint3DTestReflect, 'math-vectors');
  lSuite.AddTest('TestRotate', @RunTTestPoint3DTestRotate, 'math-vectors');
end;

end.
