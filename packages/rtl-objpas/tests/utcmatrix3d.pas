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
unit utcmatrix3d;

{$mode ObjFPC}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, utmathvectorbase, types, system.math.vectors;

Type
  { TTestMatrix3D }

  TTestMatrix3D = class(TCMathVectorsBase)
  Private
    FM : Array[1..3] of TMatrix3D;
    procedure ClearMatrices;
    function GetM(AIndex: Integer): TMatrix3D;
    procedure SetM(AIndex: Integer; AValue: TMatrix3D);
  Protected
    procedure SetUp; override;
    procedure TearDown; override;
    Property M1 : TMatrix3D Index 1 Read GetM Write SetM;
    Property M2 : TMatrix3D Index 2 Read GetM Write SetM;
    Property M3 : TMatrix3D Index 3 Read GetM Write SetM;
  public
    procedure TestHookUp;
    procedure TestCreate;
    procedure TestCreateArray;

    Procedure TestZero;

    Procedure TestCreateLookAtDirLH;
    Procedure TestCreateLookAtDirRH;
    Procedure TestCreateLookAtLH;
    Procedure TestCreateLookAtRH;

    Procedure TestCreateOrthoLH;
    Procedure TestCreateOrthoOffCenterLH;
    Procedure TestCreateOrthoOffCenterRH;
    Procedure TestCreateOrthoRH;

    Procedure TestCreatePerspectiveFovLH;
    Procedure TestCreatePerspectiveFovRH;

    Procedure TestCreateRotation;
    Procedure TestCreateRotationX;
    Procedure TestCreateRotationY;
    Procedure TestCreateRotationZ;
    Procedure TestCreateRotationHeadingPitchBank;
    Procedure TestCreateRotationYawPitchRoll;
    Procedure TestCreateScaling;
    Procedure TestCreateTranslation;

    Procedure TestMultiplyPoint;
    Procedure TestMultiplyMatrix;
    Procedure TestMultiplyVector3D;
    Procedure TestMultiplyFactor;
    Procedure TestMultiplyFactor2;
    Procedure TestDiv;

    Procedure TestAdjoint;
    Procedure TestDeterminant;
    Procedure TestEyePosition;
    Procedure TestInverse;
    Procedure TestScale;
    Procedure TestToMatrix;
    Procedure TestTranspose;
  end;


procedure Registerutcmatrix3dTests(ARegistry: TNXTestRegistry);

implementation

procedure TTestMatrix3D.ClearMatrices;

var
  I : integer;

begin
  For I:=1 to 3 do
    FM[I]:=Default(TMatrix3D);
end;

Function TTestMatrix3D.GetM(AIndex: Integer): TMatrix3D;
begin
  Result:=FM[aIndex];
end;

procedure TTestMatrix3D.SetM(AIndex: Integer; AValue: TMatrix3D);
begin
  FM[aIndex]:=aValue;
end;

procedure TTestMatrix3D.SetUp;
begin
  inherited SetUp;
  ClearMatrices;
end;

procedure TTestMatrix3D.TearDown;
begin
  inherited TearDown;
  ClearMatrices;
end;

procedure TTestMatrix3D.TestHookUp;

var
  I,C,R : Integer;

begin
  For I:=1 to 3 do
    For R:=0 to 3 do
      For C:=0 to 3 do
        TestContext.AssertTrue((0.0)=(FM[I].M[R].V[C]), Format('M%d[%d,%d]',[I,C,R]));
end;

procedure TTestMatrix3D.TestCreate;
begin
  M1:=TMatrix3D.Create(1,2,3,4,
                       5,6,7,8,
                       9,10,11,12,
                       13,14,15,16);
  // actual test
  AssertMatrix3D('Create',1,2,3,4,
                          5,6,7,8,
                          9,10,11,12,
                          13,14,15,16,M1);
  // Test assert using array
  AssertMatrix3D('Create',[1,2,3,4,
                          5,6,7,8,
                          9,10,11,12,
                          13,14,15,16],M1);
  // Test assert using second matrix
  M2:=M1;
  AssertMatrix3D('Create',M2,M1);
end;

procedure TTestMatrix3D.TestCreateArray;
begin
  M1:=TMatrix3D.Create([ 1,  2,  3,  4,
                         5,  6,  7,  8,
                         9, 10, 11, 12,
                        13, 14, 15, 16]);

  AssertMatrix3D('Create',1,  5,  9, 13,
                          2,  6, 10, 14,
                          3,  7, 11, 15,
                          4,  8, 12, 16, M1);
end;

procedure TTestMatrix3D.TestZero;
begin
  M1:=TMatrix3D.Zero;
  AssertMatrix3D('Create',0,0,0,0,
                          0,0,0,0,
                          0,0,0,0,
                          0,0,0,0, M1);
end;

procedure TTestMatrix3D.TestCreateLookAtDirLH;
begin
  M1:=TMatrix3D.CreateLookAtDirLH(Point3D(0,0,0),Point3D(0,0,1),Point3D(0,0,1));
  // test 46
  AssertMatrix3D('Create 1',[ 0.0000, 0.0000, 0.0000, 0.0000,
                            0.0000, 0.0000, 0.0000, 0.0000,
                            0.0000, 0.0000,-1.0000, 0.0000,
                            0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 47
  M1:=TMatrix3D.CreateLookAtDirLH(Point3D(0,0,0),Point3D(0,1,0),Point3D(0,0,1));
  AssertMatrix3D('Create 2',[ 1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000,-1.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 48
  M1:=TMatrix3D.CreateLookAtDirLH(Point3D(0,0,0),Point3D(1,0,0),Point3D(0,0,1));
  AssertMatrix3D('Create 3',[ 0.0000, 0.0000,-1.0000, 0.0000,
                             -1.0000, 0.0000, 0.0000, 0.0000,
                             0.0000, 1.0000, 0.0000, 0.0000,
                             0.0000, 0.0000, 0.0000, 1.0000],M1);

end;

procedure TTestMatrix3D.TestCreateLookAtDirRH;
begin
  // test 49
  M1:=TMatrix3D.CreateLookAtDirRH(Point3D(0,0,0),Point3D(0,0,1),Point3D(0,0,1));
  AssertMatrix3D('Create 1',[ 0.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 1.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 50
  M1:=TMatrix3D.CreateLookAtDirRH(Point3D(0,0,0),Point3D(0,1,0),Point3D(0,0,1));
  AssertMatrix3D('Create 2',[ -1.0000, 0.0000, 0.0000, 0.0000,
                               0.0000, 0.0000, 1.0000, 0.0000,
                               0.0000, 1.0000, 0.0000, 0.0000,
                               0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 51
  M1:=TMatrix3D.CreateLookAtDirRH(Point3D(0,0,0),Point3D(1,0,0),Point3D(0,0,1));
  AssertMatrix3D('Create 3',[ 0.0000, 0.0000, 1.0000, 0.0000,
                              1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);
end;

procedure TTestMatrix3D.TestCreateLookAtLH;
begin
  M1:=TMatrix3D.CreateLookAtLH(Point3D(0,0,0),Point3D(0,0,1),Point3D(0,0,1));
  // test 52
  AssertMatrix3D('Create 1',[  0.0000, 0.0000, 0.0000, 0.0000,
                               0.0000, 0.0000, 0.0000, 0.0000,
                               0.0000, 0.0000, 1.0000, 0.0000,
                               0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 53
  M1:=TMatrix3D.CreateLookAtLH(Point3D(0,0,0),Point3D(0,1,0),Point3D(0,0,1));
  AssertMatrix3D('Create 2',[ -1.0000, 0.0000, 0.0000, 0.0000,
                               0.0000, 0.0000, 1.0000, 0.0000,
                               0.0000, 1.0000, 0.0000, 0.0000,
                               0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 54
  M1:=TMatrix3D.CreateLookAtLH(Point3D(0,0,0),Point3D(1,0,0),Point3D(0,0,1));
  AssertMatrix3D('Create 3',[ 0.0000, 0.0000, 1.0000, 0.0000,
                              1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);

end;

procedure TTestMatrix3D.TestCreateLookAtRH;
begin
  M1:=TMatrix3D.CreateLookAtRH(Point3D(0,0,0),Point3D(0,0,1),Point3D(0,0,1));
  // test 55
  AssertMatrix3D('Create 1',[  0.0000, 0.0000, 0.0000, 0.0000,
                               0.0000, 0.0000, 0.0000, 0.0000,
                               0.0000, 0.0000,-1.0000, 0.0000,
                               0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 56
  M1:=TMatrix3D.CreateLookAtRH(Point3D(0,0,0),Point3D(0,1,0),Point3D(0,0,1));
  AssertMatrix3D('Create 2',[  1.0000, 0.0000, 0.0000, 0.0000,
                               0.0000, 0.0000,-1.0000, 0.0000,
                               0.0000, 1.0000, 0.0000, 0.0000,
                               0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 57
  M1:=TMatrix3D.CreateLookAtRH(Point3D(0,0,0),Point3D(1,0,0),Point3D(0,0,1));
  AssertMatrix3D('Create 3',[  0.0000, 0.0000,-1.0000, 0.0000,
                               -1.0000, 0.0000, 0.0000, 0.0000,
                                0.0000, 1.0000, 0.0000, 0.0000,
                                0.0000, 0.0000, 0.0000, 1.0000],M1);
end;

procedure TTestMatrix3D.TestCreateOrthoLH;
begin
  // test 58
  M1:=TMatrix3D.CreateOrthoLH(1,1,0,1);
  AssertMatrix3D('Create 1',[  2.0000, 0.0000, 0.0000, 0.0000,
                               0.0000, 2.0000, 0.0000, 0.0000,
                               0.0000, 0.0000, 1.0000, 0.0000,
                               0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 59
  M1:=TMatrix3D.CreateOrthoLH(1,1,0,2);
  AssertMatrix3D('Create 2',[2.0000, 0.0000, 0.0000, 0.0000,
                             0.0000, 2.0000, 0.0000, 0.0000,
                             0.0000, 0.0000, 0.5000, 0.0000,
                             0.0000, 0.0000, 0.0000, 1.0000],M1);
end;

procedure TTestMatrix3D.TestCreateOrthoRH;
begin
  // test 60
  M1:=TMatrix3D.CreateOrthoRH(1,1,0,1);
  AssertMatrix3D('Create 1',[  2.0000, 0.0000, 0.0000, 0.0000,
                               0.0000, 2.0000, 0.0000, 0.0000,
                               0.0000, 0.0000,-1.0000, 0.0000,
                               0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 61
  M1:=TMatrix3D.CreateOrthoRH(1,1,0,2);
  AssertMatrix3D('Create 2',[  2.0000, 0.0000, 0.0000, 0.0000,
                               0.0000, 2.0000, 0.0000, 0.0000,
                               0.0000, 0.0000,-0.5000, 0.0000,
                               0.0000, 0.0000, 0.0000, 1.0000],M1);
end;

procedure TTestMatrix3D.TestCreateOrthoOffCenterLH;
begin
  // test 62
  M1:=TMatrix3D.CreateOrthoOffCenterLH(0,0,1,1,0,1);
  AssertMatrix3D('Create 1',[2.0000, 0.0000, 0.0000, 0.0000,
                             0.0000,-2.0000, 0.0000, 0.0000,
                             0.0000, 0.0000, 1.0000, 0.0000,
                             -1.0000, 1.0000, 0.0000, 1.0000],M1);
  // test 63
  M1:=TMatrix3D.CreateOrthoOffCenterLH(0,0,1,1,0,2);
  AssertMatrix3D('Create 2',[2.0000, 0.0000, 0.0000, 0.0000,
                             0.0000,-2.0000, 0.0000, 0.0000,
                             0.0000, 0.0000, 0.5000, 0.0000,
                             -1.0000, 1.0000, 0.0000, 1.0000],M1);
end;

procedure TTestMatrix3D.TestCreateOrthoOffCenterRH;
begin
  // test 64
  M1:=TMatrix3D.CreateOrthoOffCenterRH(0,0,1,1,0,1);
  AssertMatrix3D('Create 1',[2.0000, 0.0000, 0.0000, 0.0000,
                             0.0000,-2.0000, 0.0000, 0.0000,
                             0.0000, 0.0000,-1.0000, 0.0000,
                             -1.0000, 1.0000, 0.0000, 1.0000],M1);
  // test 65
  M1:=TMatrix3D.CreateOrthoOffCenterRH(0,0,1,1,0,2);
  AssertMatrix3D('Create 2',[ 2.0000, 0.0000, 0.0000, 0.0000,
                              0.0000,-2.0000, 0.0000, 0.0000,
                              0.0000, 0.0000,-0.5000, 0.0000,
                              -1.0000, 1.0000, 0.0000, 1.0000],M1);
end;


procedure TTestMatrix3D.TestCreatePerspectiveFovLH;
begin
  // Test 66
  M1:=TMatrix3D.CreatePerspectiveFovLH(pi/2,1,0,1);
  AssertMatrix3D('Create 1',[ 1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 1.0000, 1.0000,
                              0.0000, 0.0000, 0.0000, 0.0000],M1);
  // Test 67
  M1:=TMatrix3D.CreatePerspectiveFovLH(pi/2,1,0,1,True);
  AssertMatrix3D('Create 2',[ 1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 1.0000, 1.0000,
                              0.0000, 0.0000,-0.0000, 0.0000], M1);
end;

procedure TTestMatrix3D.TestCreatePerspectiveFovRH;
begin
  // Test 68
  M1:=TMatrix3D.CreatePerspectiveFovRH(pi/2,1,0,1);
  AssertMatrix3D('Create 1',[ 1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000,-1.0000,-1.0000,
                              0.0000, 0.0000, 0.0000, 0.0000],M1);
  // Test 69
  M1:=TMatrix3D.CreatePerspectiveFovRH(pi/2,1,0,1,True);
  AssertMatrix3D('Create 2',[ 1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000,-1.0000,-1.0000,
                              0.0000, 0.0000, 0.0000, 0.0000 ],M1);
end;

procedure TTestMatrix3D.TestCreateRotation;
begin
  // test 32
  M1:=TMatrix3D.CreateRotation(Point3D(1,0,0),Pi/2);
  AssertMatrix3D('Create 1',[ 1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 1.0000, 0.0000,
                              0.0000,-1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 33
  M1:=TMatrix3D.CreateRotation(Point3D(0,1,0),Pi/2);
  AssertMatrix3D('Create 2',[ 0.0000, 0.0000,-1.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 34
  M1:=TMatrix3D.CreateRotation(Point3D(0,0,1),pi/2);
  AssertMatrix3D('Create 3',[ -0.0000, 1.0000, 0.0000, 0.0000,
                              -1.0000,-0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 1.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);
end;

procedure TTestMatrix3D.TestCreateRotationX;
begin
  // test 40
  M1:=TMatrix3D.CreateRotationX(Pi/2);
  AssertMatrix3D('Create 1',[ 1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 1.0000, 0.0000,
                              0.0000,-1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);


end;

procedure TTestMatrix3D.TestCreateRotationY;
begin
  // test 41
  M1:=TMatrix3D.CreateRotationY(Pi/2);
  AssertMatrix3D('Create 1',[ 0.0000, 0.0000,-1.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);

end;

procedure TTestMatrix3D.TestCreateRotationZ;
begin
  // test 42
  M1:=TMatrix3D.CreateRotationZ(Pi/2);
  AssertMatrix3D('Create 1',[ -0.0000, 1.0000, 0.0000, 0.0000,
                              -1.0000,-0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 1.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);
end;

procedure TTestMatrix3D.TestCreateRotationHeadingPitchBank;
begin
  // Test 37
  M1:=TMatrix3D.CreateRotationHeadingPitchBank(Pi/2,0,0);
  AssertMatrix3D('Create 1',[ 0.0000, 0.0000, 1.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              -1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);
  // Test 38
  M1:=TMatrix3D.CreateRotationHeadingPitchBank(0,Pi/2,0);
  AssertMatrix3D('Create 2',[ 1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000,-1.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);
  // Test 39
  M1:=TMatrix3D.CreateRotationHeadingPitchBank(0,0,Pi/2);
  AssertMatrix3D('Create 3',[ 0.0000,-1.0000, 0.0000, 0.0000,
                              1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 1.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000 ],M1);
end;

procedure TTestMatrix3D.TestCreateRotationYawPitchRoll;
begin
  // test 43
  M1:=TMatrix3D.CreateRotationYawPitchRoll(Pi/2,0,0);
  AssertMatrix3D('Create 1',[ 0.0000,-1.0000, 0.0000, 0.0000,
                              1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 1.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000 ],M1);
  // test 44
  M1:=TMatrix3D.CreateRotationYawPitchRoll(0,Pi/2,0);
  AssertMatrix3D('Create 2',[ 1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 1.0000, 0.0000,
                              0.0000,-1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);
  // test 45
  M1:=TMatrix3D.CreateRotationYawPitchRoll(0,0,Pi/2);
  AssertMatrix3D('Create 3',[ 0.0000, 0.0000,-1.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 0.0000, 1.0000],M1);
end;

procedure TTestMatrix3D.TestCreateScaling;
begin
  // test 71
  M1:=TMatrix3D.CreateScaling(Point3D(1,2,3));
  AssertMatrix3D('Create 1',[ 1, 0, 0, 0,
                              0, 2, 0, 0,
                              0, 0, 3, 0,
                              0, 0, 0, 1],M1);

end;

procedure TTestMatrix3D.TestCreateTranslation;
begin
  // test 72
  M1:=TMatrix3D.CreateTranslation(Point3D(1,2,3));
  AssertMatrix3D('Create 1',[ 1.0000, 0.0000, 0.0000, 0.0000,
                              0.0000, 1.0000, 0.0000, 0.0000,
                              0.0000, 0.0000, 1.0000, 0.0000,
                              1.0000, 2.0000, 3.0000, 1.0000 ],M1);
end;

procedure TTestMatrix3D.TestMultiplyPoint;
var
  P1,P2 : TPoint3D;
begin
  P1:=Point3D(1,0,0);
  M1:=TMatrix3D.CreateRotationZ(pi/2);
  P2:=P1*M1;
  AssertPoint3D('Multiply 1',0,1,0,P2);
  M1:=TMatrix3D.CreateRotationY(pi/2);
  P2:=P1*M1;
  AssertPoint3D('Multiply 2',0,0,-1,P2);
  P1:=Point3D(0,1,0);
  M1:=TMatrix3D.CreateRotationX(pi/2);
  P2:=P1*M1;
  AssertPoint3D('Multiply 3',0,0,1,P2);
end;

procedure TTestMatrix3D.TestMultiplyMatrix;
begin
  // Test 73
  M1:=TMatrix3D.Create( [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]);
  M2:=TMatrix3D.Create([16,15,14,13,12,11,10,9,8,7,6,5,4,3,2,1]);
  M3:=M1*M2;
  AssertMatrix3D('Multiplied',[ 386.0000,274.0000,162.0000,50.0000,
                                444.0000,316.0000,188.0000,60.0000,
                                502.0000,358.0000,214.0000,70.0000,
                                560.0000,400.0000,240.0000,80.0000],m3);
end;

procedure TTestMatrix3D.TestMultiplyVector3D;
var
  P1,P2 : TVector3D;
begin
  P1:=Vector3D(1,0,0);
  M1:=TMatrix3D.CreateRotationZ(pi/2);
  P2:=P1*M1;
  AssertVector3D('Multiply 1',0,1,0,1,P2);
  M1:=TMatrix3D.CreateRotationY(pi/2);
  P2:=P1*M1;
  AssertVector3D('Multiply 2',0,0,-1,1,P2);
  P1:=Point3D(0,1,0);
  M1:=TMatrix3D.CreateRotationX(pi/2);
  P2:=P1*M1;
  AssertVector3D('Multiply 3',0,0,1,1,P2);
end;

procedure TTestMatrix3D.TestMultiplyFactor;
begin
  M1:=TMatrix3D.Create( 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16);
  M2:=2*M1;
  AssertMatrix3D('Multiplied',[ 2, 4, 6, 8,
                                10, 12, 14, 16,
                                18, 20, 22, 24,
                                26, 28, 30, 32],M2);
end;

procedure TTestMatrix3D.TestMultiplyFactor2;
begin
  M1:=TMatrix3D.Create( 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16);
  M3:=M1*2;
  AssertMatrix3D('Multiplied',[ 2, 4, 6, 8,
                                10, 12, 14, 16,
                                18, 20, 22, 24,
                                26, 28, 30, 32],M3);
end;

procedure TTestMatrix3D.TestDiv;
begin
  M1:=TMatrix3D.Create( 2, 4, 6, 8,
                        10, 12, 14, 16,
                        18, 20, 22, 24,
                        26, 28, 30, 32);
  M3:=M1/2;
  AssertMatrix3D('Divided',[ 1 ,  2,  3,  4,
                                5 ,  6,  7,  8,
                                9 , 10, 11, 12,
                                13, 14, 15, 16 ],M3);

end;

procedure TTestMatrix3D.TestAdjoint;
begin
  // Test 74
  M1:=TMatrix3D.CreateRotationZ(Pi/3);
  M2:=M1.Adjoint;
  AssertMatrix3D('Adjoint',[0.5000,-0.8660, 0.0000, 0.0000,
                            0.8660, 0.5000, 0.0000, 0.0000,
                            0.0000, 0.0000, 1.0000, 0.0000,
                            0.0000, 0.0000, 0.0000, 1.0000],M2);
end;

procedure TTestMatrix3D.TestDeterminant;
begin
  // Test 75
  M1:=TMatrix3D.CreateRotationZ(Pi/3);
  TestContext.AssertTrue((1.0)=(M1.Determinant), 'Determinant');
  // Test 76
  M1:=TMatrix3D.Create(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16);
  TestContext.AssertTrue((0)=(M1.Determinant), 'Determinant');
  M1:=TMatrix3D.Create(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1);
  TestContext.AssertTrue((1)=(M1.Determinant), 'Determinant');
end;

procedure TTestMatrix3D.TestEyePosition;
begin
  // Test 77
  M1:=TMatrix3D.CreateRotationZ(Pi/3);
  AssertPoint3D('EyePosition 1',0,0,0,M1.EyePosition);
  // Test 78
  M1:=TMatrix3D.CreateRotationZ(Pi/3)*TMatrix3D.CreateTranslation(Point3D(1,0,0));
  AssertPoint3D('EyePosition 2',-0.50, 0.8660, 0,M1.EyePosition);
end;

procedure TTestMatrix3D.TestInverse;
begin
  // Test 77
  M1:=TMatrix3D.CreateRotationZ(Pi/3);
  M2:=TMatrix3D.CreateRotationZ(-Pi/3);
  AssertMatrix3D('Inverse 1',M2,M1.Inverse);
  AssertMatrix3D('Inverse 2',TMatrix3D.Identity,M1*M1.Inverse);

end;

procedure TTestMatrix3D.TestScale;
begin
  M1:=TMatrix3D.Create( 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16);
  M3:=M1.Scale(2);
  AssertMatrix3D('Multiplied',[ 2, 4, 6, 8,
                                10, 12, 14, 16,
                                18, 20, 22, 24,
                                26, 28, 30, 32],M3);

end;

procedure TTestMatrix3D.TestToMatrix;

Var
  M : TMatrix;

begin
  M1:=TMatrix3D.CreateRotationZ(Pi/3);
  M:=M1.ToMatrix;
  AssertMatrix('To Matrix',TMatrix.CreateRotation(Pi/3),M);
end;

procedure TTestMatrix3D.TestTranspose;
begin
  M1:=TMatrix3D.Create( 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16);
  M2:=TMatrix3D.Create( [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]);
  M3:=M1.Transpose;
  AssertMatrix3D('Transposed',M2,M3);
end;


procedure RunTTestMatrix3DTestHookUp(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestHookUp');
  try
    lFixture.SetUp;
    try lFixture.TestHookUp; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestZero(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestZero');
  try
    lFixture.SetUp;
    try lFixture.TestZero; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateLookAtDirLH(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateLookAtDirLH');
  try
    lFixture.SetUp;
    try lFixture.TestCreateLookAtDirLH; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateLookAtDirRH(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateLookAtDirRH');
  try
    lFixture.SetUp;
    try lFixture.TestCreateLookAtDirRH; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateLookAtLH(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateLookAtLH');
  try
    lFixture.SetUp;
    try lFixture.TestCreateLookAtLH; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateLookAtRH(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateLookAtRH');
  try
    lFixture.SetUp;
    try lFixture.TestCreateLookAtRH; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateOrthoLH(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateOrthoLH');
  try
    lFixture.SetUp;
    try lFixture.TestCreateOrthoLH; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateOrthoOffCenterLH(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateOrthoOffCenterLH');
  try
    lFixture.SetUp;
    try lFixture.TestCreateOrthoOffCenterLH; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateOrthoOffCenterRH(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateOrthoOffCenterRH');
  try
    lFixture.SetUp;
    try lFixture.TestCreateOrthoOffCenterRH; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateOrthoRH(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateOrthoRH');
  try
    lFixture.SetUp;
    try lFixture.TestCreateOrthoRH; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreatePerspectiveFovLH(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreatePerspectiveFovLH');
  try
    lFixture.SetUp;
    try lFixture.TestCreatePerspectiveFovLH; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreatePerspectiveFovRH(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreatePerspectiveFovRH');
  try
    lFixture.SetUp;
    try lFixture.TestCreatePerspectiveFovRH; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateRotation(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateRotation');
  try
    lFixture.SetUp;
    try lFixture.TestCreateRotation; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateRotationX(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateRotationX');
  try
    lFixture.SetUp;
    try lFixture.TestCreateRotationX; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateRotationY(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateRotationY');
  try
    lFixture.SetUp;
    try lFixture.TestCreateRotationY; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateRotationZ(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateRotationZ');
  try
    lFixture.SetUp;
    try lFixture.TestCreateRotationZ; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateRotationHeadingPitchBank(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateRotationHeadingPitchBank');
  try
    lFixture.SetUp;
    try lFixture.TestCreateRotationHeadingPitchBank; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateRotationYawPitchRoll(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateRotationYawPitchRoll');
  try
    lFixture.SetUp;
    try lFixture.TestCreateRotationYawPitchRoll; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateScaling(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateScaling');
  try
    lFixture.SetUp;
    try lFixture.TestCreateScaling; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreateTranslation(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestCreateTranslation');
  try
    lFixture.SetUp;
    try lFixture.TestCreateTranslation; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestMultiplyPoint(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestMultiplyPoint');
  try
    lFixture.SetUp;
    try lFixture.TestMultiplyPoint; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestMultiplyMatrix(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestMultiplyMatrix');
  try
    lFixture.SetUp;
    try lFixture.TestMultiplyMatrix; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestMultiplyVector3D(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestMultiplyVector3D');
  try
    lFixture.SetUp;
    try lFixture.TestMultiplyVector3D; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestMultiplyFactor(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestMultiplyFactor');
  try
    lFixture.SetUp;
    try lFixture.TestMultiplyFactor; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestMultiplyFactor2(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestMultiplyFactor2');
  try
    lFixture.SetUp;
    try lFixture.TestMultiplyFactor2; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestDiv(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestDiv');
  try
    lFixture.SetUp;
    try lFixture.TestDiv; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestAdjoint(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestAdjoint');
  try
    lFixture.SetUp;
    try lFixture.TestAdjoint; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestDeterminant(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestDeterminant');
  try
    lFixture.SetUp;
    try lFixture.TestDeterminant; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestEyePosition(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestEyePosition');
  try
    lFixture.SetUp;
    try lFixture.TestEyePosition; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestInverse(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestInverse');
  try
    lFixture.SetUp;
    try lFixture.TestInverse; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestScale(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestScale');
  try
    lFixture.SetUp;
    try lFixture.TestScale; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestToMatrix(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestToMatrix');
  try
    lFixture.SetUp;
    try lFixture.TestToMatrix; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestTranspose(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext, 'TestTranspose');
  try
    lFixture.SetUp;
    try lFixture.TestTranspose; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure RunTTestMatrix3DTestCreate(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext,'TestCreate');
  try
    lFixture.SetUp;
    try lFixture.TestCreate; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;


procedure RunTTestMatrix3DTestCreateArray(AContext: TNXTestContext);
var lFixture: TTestMatrix3D;
begin
  lFixture:=TTestMatrix3D.Create(AContext,'TestCreateArray');
  try
    lFixture.SetUp;
    try lFixture.TestCreateArray; finally lFixture.TearDown; end;
  finally lFixture.Free; end;
end;

procedure Registerutcmatrix3dTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('utcmatrix3d.TTestMatrix3D');
  lSuite.AddTest('TestCreate', @RunTTestMatrix3DTestCreate);
  lSuite.AddTest('TestCreateArray', @RunTTestMatrix3DTestCreateArray);
  lSuite.AddTest('TestHookUp', @RunTTestMatrix3DTestHookUp);
  lSuite.AddTest('TestZero', @RunTTestMatrix3DTestZero);
  lSuite.AddTest('TestCreateLookAtDirLH', @RunTTestMatrix3DTestCreateLookAtDirLH);
  lSuite.AddTest('TestCreateLookAtDirRH', @RunTTestMatrix3DTestCreateLookAtDirRH);
  lSuite.AddTest('TestCreateLookAtLH', @RunTTestMatrix3DTestCreateLookAtLH);
  lSuite.AddTest('TestCreateLookAtRH', @RunTTestMatrix3DTestCreateLookAtRH);
  lSuite.AddTest('TestCreateOrthoLH', @RunTTestMatrix3DTestCreateOrthoLH);
  lSuite.AddTest('TestCreateOrthoOffCenterLH', @RunTTestMatrix3DTestCreateOrthoOffCenterLH);
  lSuite.AddTest('TestCreateOrthoOffCenterRH', @RunTTestMatrix3DTestCreateOrthoOffCenterRH);
  lSuite.AddTest('TestCreateOrthoRH', @RunTTestMatrix3DTestCreateOrthoRH);
  lSuite.AddTest('TestCreatePerspectiveFovLH', @RunTTestMatrix3DTestCreatePerspectiveFovLH);
  lSuite.AddTest('TestCreatePerspectiveFovRH', @RunTTestMatrix3DTestCreatePerspectiveFovRH);
  lSuite.AddTest('TestCreateRotation', @RunTTestMatrix3DTestCreateRotation);
  lSuite.AddTest('TestCreateRotationX', @RunTTestMatrix3DTestCreateRotationX);
  lSuite.AddTest('TestCreateRotationY', @RunTTestMatrix3DTestCreateRotationY);
  lSuite.AddTest('TestCreateRotationZ', @RunTTestMatrix3DTestCreateRotationZ);
  lSuite.AddTest('TestCreateRotationHeadingPitchBank', @RunTTestMatrix3DTestCreateRotationHeadingPitchBank);
  lSuite.AddTest('TestCreateRotationYawPitchRoll', @RunTTestMatrix3DTestCreateRotationYawPitchRoll);
  lSuite.AddTest('TestCreateScaling', @RunTTestMatrix3DTestCreateScaling);
  lSuite.AddTest('TestCreateTranslation', @RunTTestMatrix3DTestCreateTranslation);
  lSuite.AddTest('TestMultiplyPoint', @RunTTestMatrix3DTestMultiplyPoint);
  lSuite.AddTest('TestMultiplyMatrix', @RunTTestMatrix3DTestMultiplyMatrix);
  lSuite.AddTest('TestMultiplyVector3D', @RunTTestMatrix3DTestMultiplyVector3D);
  lSuite.AddTest('TestMultiplyFactor', @RunTTestMatrix3DTestMultiplyFactor);
  lSuite.AddTest('TestMultiplyFactor2', @RunTTestMatrix3DTestMultiplyFactor2);
  lSuite.AddTest('TestDiv', @RunTTestMatrix3DTestDiv);
  lSuite.AddTest('TestAdjoint', @RunTTestMatrix3DTestAdjoint);
  lSuite.AddTest('TestDeterminant', @RunTTestMatrix3DTestDeterminant);
  lSuite.AddTest('TestEyePosition', @RunTTestMatrix3DTestEyePosition);
  lSuite.AddTest('TestInverse', @RunTTestMatrix3DTestInverse);
  lSuite.AddTest('TestScale', @RunTTestMatrix3DTestScale);
  lSuite.AddTest('TestToMatrix', @RunTTestMatrix3DTestToMatrix);
  lSuite.AddTest('TestTranspose', @RunTTestMatrix3DTestTranspose);
end;

end.
