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
unit utcvector;

{$mode ObjFPC}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, types, utmathvectorbase, system.math.vectors;

Type

  { TTestVector }

  TTestVector = class(TCMathVectorsBase)
  Private
    FV : Array[1..3] of TVector;
    procedure ClearVectors;
    function GetV(AIndex: Integer): TVector;
    procedure SetV(AIndex: Integer; AValue: TVector);
  Protected
    procedure SetUp; override;
    procedure TearDown; override;
    Property V1 : TVector Index 1 Read GetV Write SetV;
    Property V2 : TVector Index 2 Read GetV Write SetV;
    Property V3 : TVector Index 3 Read GetV Write SetV;
  public
    procedure TestHookUp;
    Procedure TestZero;
    Procedure TestCreate;
    Procedure TestCreateW;
    Procedure TestAssign;
    Procedure TestAssignPointf;
    Procedure TestAssignToPointf;
    Procedure TestAdd;
    Procedure TestMultiplyFactor;
    Procedure TestDivide;
    Procedure TestEqual;
    Procedure TestNotEqual;
    Procedure TestSubtract;
    Procedure TestLength;
    Procedure TestNormalize;
    Procedure TestCrossProduct;
    Procedure TestDotProduct;
    Procedure TestToPointF;
  end;

procedure RegisterutcvectorTests(ARegistry: TNXTestRegistry);

implementation
{ TTestVector }

function TTestVector.GetV(AIndex: Integer): TVector;
begin
  Result:=FV[aIndex];
end;

procedure TTestVector.SetV(AIndex: Integer; AValue: TVector);
begin
  FV[aIndex]:=aValue;
end;

procedure TTestVector.ClearVectors;

var
  I : integer;

begin
  For I:=1 to 3 do
    begin
    FV[I].X:=0;
    FV[I].Y:=0;
    FV[I].W:=0;
    end;
end;



procedure TTestVector.SetUp;
begin
  inherited SetUp;
  ClearVectors;
end;

procedure TTestVector.TearDown;
begin
  inherited TearDown;
end;

procedure TTestVector.TestHookUp;
var
  I : Integer;
begin
  For I:=1 to 3 do
    begin
    TestContext.AssertTrue((0.0)=(FV[I].X), 'Vector '+intTostr(i)+'.X');
    TestContext.AssertTrue((0.0)=(FV[I].Y), 'Vector '+intTostr(i)+'.Y');
    TestContext.AssertTrue((0.0)=(FV[I].W), 'Vector '+intTostr(i)+'.W');
    end;
end;

procedure TTestVector.TestZero;
begin
  V1:=TVector.Zero;
  TestContext.AssertTrue((0.0)=(V1.X), 'Vector.X');
  TestContext.AssertTrue((0.0)=(V1.Y), 'Vector.Y');
  TestContext.AssertTrue((0.0)=(V1.W), 'Vector.W');
end;

procedure TTestVector.TestCreate;
begin
  V1:=TVector.Create(1,2);
  TestContext.AssertTrue((1.0)=(V1.X), 'Vector.X');
  TestContext.AssertTrue((2.0)=(V1.Y), 'Vector.Y');
  TestContext.AssertTrue((DefaultVectorWidth)=(V1.W), 'Vector.W');
end;

procedure TTestVector.TestCreateW;
begin
  V1:=TVector.Create(1,2,3);
  AssertVector('Vector',1,2,3,V1);
end;

procedure TTestVector.TestAssign;
begin
  V2:=TVector.Create(1,2,3);
  V1:=V2;
  AssertVector('Assign',1,2,3,V1);
end;

procedure TTestVector.TestAssignPointf;

var
  P : TPointF;

begin
  P:=PointF(1,2);
  V1:=P;
  AssertVector('Vector',1,2,DefaultVectorWidth,V1);
end;

procedure TTestVector.TestAssignToPointf;
Var
  P : TPointF;

begin
  V1:=TVector.Create(1,2,3);
  P:=V1;
  TestContext.AssertTrue((PointF(0.3333,0.6666))=(P), 'Assign 1');
  V1:=TVector.Create(1,2,1);
  P:=V1;
  TestContext.AssertTrue((PointF(1,2))=(P), 'Assign 2');
  V1:=TVector.Create(1,2,0);
  P:=V1;
  TestContext.AssertTrue((PointF(1,2))=(P), 'Assign 3');
end;

procedure TTestVector.TestAdd;

begin
  V1:=TVector.Create(1,2,3);
  V2:=TVector.Create(6,5,4);
  V3:=V1+V2;
  AssertVector('Vector',7,7,7,V3);
end;

procedure TTestVector.TestMultiplyFactor;
begin
  V1:=TVector.Create(1,2,3);
  V2:=V1*3;
  AssertVector('Vector 1',3,6,9,V2);
  V2:=3*V1;
  AssertVector('Vector 2',3,6,9,V2);
end;

procedure TTestVector.TestDivide;
begin
  V1:=TVector.Create(1,2,3);
  V2:=V1/3;
  AssertVector('Vector 1',0.3333,0.6666,1,V2);
end;

procedure TTestVector.TestEqual;
begin
  V1:=TVector.Create(1,2,3);
  V2:=TVector.Create(1,2,3);
  TestContext.AssertTrue(V1=V2, 'Equal 1');
  V2:=TVector.Create(3,2,1);
  TestContext.AssertTrue(not (V1=V2), 'Equal 2');
  V2:=TVector.Create(1+TEpsilon.Vector*0.99,2,3);
  TestContext.AssertTrue(V1=V2, 'Equal within precision');
  V2:=TVector.Create(1+TEpsilon.Vector*1.1,2,3);
  TestContext.AssertTrue(not (V1=V2), 'Unequal outside precision');
end;

procedure TTestVector.TestNotEqual;
begin
  V1:=TVector.Create(1,2,3);
  V2:=TVector.Create(1,2,3);
  TestContext.AssertTrue(not (V1<>V2), 'Not Equal');
  V2:=TVector.Create(3,2,1);
  TestContext.AssertTrue(V1<>V2, 'Equal');
  V2:=TVector.Create(1+TEpsilon.Vector*0.99,2,3);
  TestContext.AssertTrue(not (V1<>V2), 'Equal within precision');
  V2:=TVector.Create(1+TEpsilon.Vector*1.1,2,3);
  TestContext.AssertTrue(V1<>V2, 'Unequal outside precision');
end;

procedure TTestVector.TestSubtract;
begin
  V1:=TVector.Create(1,2,3);
  V2:=TVector.Create(6,5,4);
  V3:=V2-V1;
  AssertVector('Vector',5,3,1,V3);
end;

procedure TTestVector.TestLength;
begin
  V1:=TVector.Create(3,4,0);
  TestContext.AssertTrue((5)=(V1.Length), 'Length 1');
  V1:=TVector.Create(3,4,1);
  TestContext.AssertTrue(Abs((Sqrt(26))-(V1.Length))<=(TEpsilon.Vector), 'Length 1');
end;

procedure TTestVector.TestNormalize;
begin
  V1:=TVector.Create(3,4,0);
  V2:=V1.Normalize;
  AssertVector('No width',3/5,4/5,0,V2);
  TestContext.AssertTrue(Abs((1)-(V2.Length))<=(TEpsilon.Vector), 'Length 1');
  V1:=TVector.Create(3,4,1);
  V2:=V1.Normalize;
  AssertVector('No width',3/Sqrt(26),4/Sqrt(26),1/Sqrt(26),V2);
  TestContext.AssertTrue(Abs((1)-(V2.Length))<=(TEpsilon.Vector), 'Length 1');
end;

procedure TTestVector.TestCrossProduct;
begin
  V1:=TVector.Create(1,1,0);
  V2:=TVector.Create(2,2,0);
  V3:=V2.CrossProduct(V1);
  AssertVector('T1',0,0,0,V3);
  V1:=TVector.Create(1,1,0);
  V2:=TVector.Create(2,2,0);
  V3:=V2.CrossProduct(V1);
  AssertVector('T1',0,0,0,V3);
end;

procedure TTestVector.TestDotProduct;
begin
  V1:=TVector.Create(3,4,9);
  V2:=TVector.Create(3,4,9);
  TestContext.AssertTrue((9+16+81)=(V1.DotProduct(V2)), 'Test 1');
  V2:=TVector.Create(1,1,0);
  TestContext.AssertTrue((7)=(V1.DotProduct(V2)), 'Test 1');
end;

procedure TTestVector.TestToPointF;

var
  P : TPointF;

begin
  V1:=TVector.Create(1,2,3);
  P:=V1.ToPointF;
  TestContext.AssertTrue((PointF(0.3333,0.6666))=(P), 'ToPointF 1');
  V1:=TVector.Create(1,2,1);
  P:=V1.ToPointF;
  TestContext.AssertTrue((PointF(1,2))=(P), 'ToPointF 2');
end;



procedure RunTTestVectorTestHookUp(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestHookUp');
  try
    lFixture.SetUp;
    try lFixture.TestHookUp; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestZero(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestZero');
  try
    lFixture.SetUp;
    try lFixture.TestZero; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestCreate(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestCreate');
  try
    lFixture.SetUp;
    try lFixture.TestCreate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestCreateW(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestCreateW');
  try
    lFixture.SetUp;
    try lFixture.TestCreateW; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestAssign(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestAssign');
  try
    lFixture.SetUp;
    try lFixture.TestAssign; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestAssignPointf(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestAssignPointf');
  try
    lFixture.SetUp;
    try lFixture.TestAssignPointf; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestAssignToPointf(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestAssignToPointf');
  try
    lFixture.SetUp;
    try lFixture.TestAssignToPointf; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestAdd(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestAdd');
  try
    lFixture.SetUp;
    try lFixture.TestAdd; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestMultiplyFactor(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestMultiplyFactor');
  try
    lFixture.SetUp;
    try lFixture.TestMultiplyFactor; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestDivide(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestDivide');
  try
    lFixture.SetUp;
    try lFixture.TestDivide; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestEqual(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestEqual');
  try
    lFixture.SetUp;
    try lFixture.TestEqual; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestNotEqual(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestNotEqual');
  try
    lFixture.SetUp;
    try lFixture.TestNotEqual; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestSubtract(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestSubtract');
  try
    lFixture.SetUp;
    try lFixture.TestSubtract; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestLength(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestLength');
  try
    lFixture.SetUp;
    try lFixture.TestLength; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestNormalize(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestNormalize');
  try
    lFixture.SetUp;
    try lFixture.TestNormalize; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestCrossProduct(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestCrossProduct');
  try
    lFixture.SetUp;
    try lFixture.TestCrossProduct; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestDotProduct(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestDotProduct');
  try
    lFixture.SetUp;
    try lFixture.TestDotProduct; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestVectorTestToPointF(AContext: TNXTestContext);
var lFixture: TTestVector;
begin
  lFixture:=TTestVector.Create(AContext, 'TestToPointF');
  try
    lFixture.SetUp;
    try lFixture.TestToPointF; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RegisterutcvectorTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('utcvector.TTestVector');
  lSuite.AddTest('TestHookUp', @RunTTestVectorTestHookUp, 'math-vectors');
  lSuite.AddTest('TestZero', @RunTTestVectorTestZero, 'math-vectors');
  lSuite.AddTest('TestCreate', @RunTTestVectorTestCreate, 'math-vectors');
  lSuite.AddTest('TestCreateW', @RunTTestVectorTestCreateW, 'math-vectors');
  lSuite.AddTest('TestAssign', @RunTTestVectorTestAssign, 'math-vectors');
  lSuite.AddTest('TestAssignPointf', @RunTTestVectorTestAssignPointf, 'math-vectors');
  lSuite.AddTest('TestAssignToPointf', @RunTTestVectorTestAssignToPointf, 'math-vectors');
  lSuite.AddTest('TestAdd', @RunTTestVectorTestAdd, 'math-vectors');
  lSuite.AddTest('TestMultiplyFactor', @RunTTestVectorTestMultiplyFactor, 'math-vectors');
  lSuite.AddTest('TestDivide', @RunTTestVectorTestDivide, 'math-vectors');
  lSuite.AddTest('TestEqual', @RunTTestVectorTestEqual, 'math-vectors');
  lSuite.AddTest('TestNotEqual', @RunTTestVectorTestNotEqual, 'math-vectors');
  lSuite.AddTest('TestSubtract', @RunTTestVectorTestSubtract, 'math-vectors');
  lSuite.AddTest('TestLength', @RunTTestVectorTestLength, 'math-vectors');
  lSuite.AddTest('TestNormalize', @RunTTestVectorTestNormalize, 'math-vectors');
  lSuite.AddTest('TestCrossProduct', @RunTTestVectorTestCrossProduct, 'math-vectors');
  lSuite.AddTest('TestDotProduct', @RunTTestVectorTestDotProduct, 'math-vectors');
  lSuite.AddTest('TestToPointF', @RunTTestVectorTestToPointF, 'math-vectors');
end;

end.
