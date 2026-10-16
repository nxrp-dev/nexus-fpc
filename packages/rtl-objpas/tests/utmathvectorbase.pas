unit utmathvectorbase;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, Types, system.math.vectors;

const
  c45 = Sqrt(2)/2;  // cosine/sine 45°
  c60 = Sqrt(3)/2;  // cosine 60°
  c30 = 1/2;        // cosine 30°

  s30 = C60; // sine 30°
  s45 = c45; // sine 45°
  s60 = c30; // sine 60°



type
  { TCMathVectorsBase }

  TCMathVectorsBase = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  protected
    procedure SetUp; virtual;
    procedure TearDown; virtual;
    Procedure AssertEquals(const Msg : String; aExpected,aActual : TVector); overload;
    Procedure AssertEquals(const Msg : String; aExpected,aActual : TPoint3D); overload;
    Procedure AssertEquals(const Msg : String; aExpected,aActual : TPointF); overload;
    Procedure AssertEquals(const Msg : String; aExpected,aActual : TVector3D); overload;
    Procedure AssertVector3D(const Msg : String; aExpectedX,aExpectedY,aExpectedZ,aExpectedW: Single; aActual : TVector3D);
    Procedure AssertVector(const Msg : String; aExpectedX,aExpectedY,aExpectedW: Single; aActual : TVector);
    Procedure AssertPoint3D(const Msg : String; aExpectedX,aExpectedY,aExpectedZ: Single; aActual : TPoint3D);
    procedure AssertMatrix(Const Msg : String; m11, m12, m13,  m21, m22, m23,  m31, m32, m33 : Single; aActual : TMatrix);
    procedure AssertMatrix(Const Msg : String; aExpected : Array of single; aActual : TMatrix);
    procedure AssertMatrix(Const Msg : String; aExpected, aActual : TMatrix);
    procedure AssertMatrix3D(Const Msg : String; m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44 : Single; aActual : TMatrix3D);
    procedure AssertMatrix3D(Const Msg : String; aExpected : Array of single; aActual : TMatrix3D);
    procedure AssertMatrix3D(Const Msg : String; aExpected, aActual : TMatrix3D);
    Procedure AssertPointF(const Msg : String; aExpectedX,aExpectedY: Single; aActual : TPointF);
    Procedure AssertQuaternion(const Msg : String; aExpectedReal,aExpectedImagX,aExpectedImagY,aExpectedImagZ: Single; aActual : TQuaternion3D);
    Procedure AssertQuaternion(const Msg : String; aExpectedReal: Single; aExpectedImag : TPoint3D; aActual : TQuaternion3D);
  end;



procedure RegisterutmathvectorbaseTests(ARegistry: TNXTestRegistry);

implementation

procedure TCMathVectorsBase.SetUp;
begin
end;

procedure TCMathVectorsBase.TearDown;
begin
end;

procedure TCMathVectorsBase.AssertEquals(const Msg: String; aExpected,
  aActual: TVector);
begin
  TestContext.AssertTrue(Abs((aExpected.X)-(aActual.X))<=(TEpsilon.Vector), Msg+' X');
  TestContext.AssertTrue(Abs((aExpected.Y)-(aActual.Y))<=(TEpsilon.Vector), Msg+' Y');
  TestContext.AssertTrue(Abs((aExpected.W)-(aActual.W))<=(TEpsilon.Vector), Msg+' W');
end;

procedure TCMathVectorsBase.AssertEquals(const Msg: String; aExpected,
  aActual: TPoint3D);
begin
  TestContext.AssertTrue(Abs((aExpected.X)-(aActual.X))<=(TEpsilon.Vector), Msg+' X');
  TestContext.AssertTrue(Abs((aExpected.Y)-(aActual.Y))<=(TEpsilon.Vector), Msg+' Y');
  TestContext.AssertTrue(Abs((aExpected.Z)-(aActual.Z))<=(TEpsilon.Vector), Msg+' Z');
end;

procedure TCMathVectorsBase.AssertEquals(const Msg: String; aExpected,
  aActual: TPointF);
begin
  TestContext.AssertTrue(Abs((aExpected.X)-(aActual.X))<=(TEpsilon.Vector), Msg+' X');
  TestContext.AssertTrue(Abs((aExpected.Y)-(aActual.Y))<=(TEpsilon.Vector), Msg+' Y');

end;

procedure TCMathVectorsBase.AssertEquals(const Msg: String; aExpected,
  aActual: TVector3D);
begin
  TestContext.AssertTrue(Abs((aExpected.X)-(aActual.X))<=(TEpsilon.Vector), Msg+' X');
  TestContext.AssertTrue(Abs((aExpected.Y)-(aActual.Y))<=(TEpsilon.Vector), Msg+' Y');
  TestContext.AssertTrue(Abs((aExpected.Z)-(aActual.Z))<=(TEpsilon.Vector), Msg+' Z');
  TestContext.AssertTrue(Abs((aExpected.W)-(aActual.W))<=(TEpsilon.Vector), Msg+' W');
end;

procedure TCMathVectorsBase.AssertVector3D(const Msg: String; aExpectedX,
  aExpectedY, aExpectedZ, aExpectedW: Single; aActual: TVector3D);
begin
  TestContext.AssertTrue(Abs((aExpectedX)-(aActual.X))<=(TEpsilon.Vector), Msg+' X');
  TestContext.AssertTrue(Abs((aExpectedY)-(aActual.Y))<=(TEpsilon.Vector), Msg+' Y');
  TestContext.AssertTrue(Abs((aExpectedZ)-(aActual.Z))<=(TEpsilon.Vector), Msg+' Z');
  TestContext.AssertTrue(Abs((aExpectedW)-(aActual.W))<=(TEpsilon.Vector), Msg+' W');
end;

procedure TCMathVectorsBase.AssertVector(const Msg: String; aExpectedX,
  aExpectedY, aExpectedW: Single; aActual: TVector);
begin
  TestContext.AssertTrue(Abs((aExpectedX)-(aActual.X))<=(TEpsilon.Vector), Msg+' X');
  TestContext.AssertTrue(Abs((aExpectedY)-(aActual.Y))<=(TEpsilon.Vector), Msg+' Y');
  TestContext.AssertTrue(Abs((aExpectedW)-(aActual.W))<=(TEpsilon.Vector), Msg+' W');
end;

procedure TCMathVectorsBase.AssertPoint3D(const Msg: String; aExpectedX, aExpectedY, aExpectedZ: Single; aActual: TPoint3D);
begin
  TestContext.AssertTrue(Abs((aExpectedX)-(aActual.X))<=(TEpsilon.Vector), Msg+' X');
  TestContext.AssertTrue(Abs((aExpectedY)-(aActual.Y))<=(TEpsilon.Vector), Msg+' Y');
  TestContext.AssertTrue(Abs((aExpectedZ)-(aActual.Z))<=(TEpsilon.Vector), Msg+' Z');
end;

procedure TCMathVectorsBase.AssertMatrix(const Msg: String; m11, m12, m13, m21, m22, m23, m31, m32, m33: Single;
  aActual: TMatrix);
begin
  TestContext.AssertTrue(Abs((m11)-(aActual.m11))<=(TEpsilon.Vector), Msg+' m11');
  TestContext.AssertTrue(Abs((m12)-(aActual.m12))<=(TEpsilon.Vector), Msg+' m12');
  TestContext.AssertTrue(Abs((m13)-(aActual.m13))<=(TEpsilon.Vector), Msg+' m13');

  TestContext.AssertTrue(Abs((m21)-(aActual.m21))<=(TEpsilon.Vector), Msg+' m21');
  TestContext.AssertTrue(Abs((m22)-(aActual.m22))<=(TEpsilon.Vector), Msg+' m22');
  TestContext.AssertTrue(Abs((m23)-(aActual.m23))<=(TEpsilon.Vector), Msg+' m23');

  TestContext.AssertTrue(Abs((m31)-(aActual.m31))<=(TEpsilon.Vector), Msg+' m31');
  TestContext.AssertTrue(Abs((m32)-(aActual.m32))<=(TEpsilon.Vector), Msg+' m32');
  TestContext.AssertTrue(Abs((m33)-(aActual.m33))<=(TEpsilon.Vector), Msg+' m33');
end;

procedure TCMathVectorsBase.AssertMatrix(const Msg: String; aExpected: array of single; aActual: TMatrix);
begin
  TestContext.AssertTrue((9)=(Length(aExpected)), Msg+' number of elements');
  AssertMatrix(Msg,aExpected[0],aExpected[1],aExpected[2],
                   aExpected[3],aExpected[4],aExpected[5],
                   aExpected[6],aExpected[7],aExpected[8],aActual);
end;

procedure TCMathVectorsBase.AssertMatrix(const Msg: String; aExpected, aActual: TMatrix);
begin
  With aExpected do
    AssertMatrix(Msg,m11, m12, m13, m21, m22, m23, m31, m32, m33,aActual);
end;

procedure TCMathVectorsBase.AssertMatrix3D(const Msg: String; m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33,
  m34, m41, m42, m43, m44 : Single; aActual: TMatrix3D);
begin
  TestContext.AssertTrue(Abs((m11)-(aActual.m11))<=(TEpsilon.Vector), Msg+' m11');
  TestContext.AssertTrue(Abs((m12)-(aActual.m12))<=(TEpsilon.Vector), Msg+' m12');
  TestContext.AssertTrue(Abs((m13)-(aActual.m13))<=(TEpsilon.Vector), Msg+' m13');
  TestContext.AssertTrue(Abs((m14)-(aActual.m14))<=(TEpsilon.Vector), Msg+' m14');

  TestContext.AssertTrue(Abs((m21)-(aActual.m21))<=(TEpsilon.Vector), Msg+' m21');
  TestContext.AssertTrue(Abs((m22)-(aActual.m22))<=(TEpsilon.Vector), Msg+' m22');
  TestContext.AssertTrue(Abs((m23)-(aActual.m23))<=(TEpsilon.Vector), Msg+' m23');
  TestContext.AssertTrue(Abs((m24)-(aActual.m24))<=(TEpsilon.Vector), Msg+' m24');

  TestContext.AssertTrue(Abs((m31)-(aActual.m31))<=(TEpsilon.Vector), Msg+' m31');
  TestContext.AssertTrue(Abs((m32)-(aActual.m32))<=(TEpsilon.Vector), Msg+' m32');
  TestContext.AssertTrue(Abs((m33)-(aActual.m33))<=(TEpsilon.Vector), Msg+' m33');
  TestContext.AssertTrue(Abs((m34)-(aActual.m34))<=(TEpsilon.Vector), Msg+' m34');

  TestContext.AssertTrue(Abs((m41)-(aActual.m41))<=(TEpsilon.Vector), Msg+' m41');
  TestContext.AssertTrue(Abs((m42)-(aActual.m42))<=(TEpsilon.Vector), Msg+' m42');
  TestContext.AssertTrue(Abs((m43)-(aActual.m43))<=(TEpsilon.Vector), Msg+' m43');
  TestContext.AssertTrue(Abs((m44)-(aActual.m44))<=(TEpsilon.Vector), Msg+' m44');

end;

procedure TCMathVectorsBase.AssertMatrix3D(const Msg: String; aExpected: array of single; aActual: TMatrix3D);
begin
  TestContext.AssertTrue((16)=(Length(aExpected)), Msg+' number of elements');
  AssertMatrix3D(Msg,aExpected[0],aExpected[1],aExpected[2],aExpected[3],
                   aExpected[4],aExpected[5],aExpected[6],aExpected[7],
                   aExpected[8],aExpected[9], aExpected[10], aExpected[11],
                   aExpected[12], aExpected[13], aExpected[14], aExpected[15], aActual);
end;

procedure TCMathVectorsBase.AssertMatrix3D(const Msg: String; aExpected, aActual: TMatrix3D);
begin
  With aExpected do
    AssertMatrix3D(Msg,m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44, aActual);
end;

procedure TCMathVectorsBase.AssertPointF(const Msg: String; aExpectedX, aExpectedY: Single; aActual: TPointF);
begin
  TestContext.AssertTrue(Abs((aExpectedX)-(aActual.X))<=(TEpsilon.Vector), Msg+' X');
  TestContext.AssertTrue(Abs((aExpectedY)-(aActual.Y))<=(TEpsilon.Vector), Msg+' Y');
end;

procedure TCMathVectorsBase.AssertQuaternion(const Msg: String; aExpectedReal, aExpectedImagX, aExpectedImagY,
  aExpectedImagZ: Single; aActual: TQuaternion3D);
begin
  TestContext.AssertTrue(Abs((aExpectedReal)-(aActual.RealPart))<=(TEpsilon.Vector), Msg+' RealPart');
  TestContext.AssertTrue(Abs((aExpectedImagX)-(aActual.ImagPart.X))<=(TEpsilon.Vector), Msg+' ImagPart.X');
  TestContext.AssertTrue(Abs((aExpectedImagY)-(aActual.ImagPart.Y))<=(TEpsilon.Vector), Msg+' ImagPart.Y');
  TestContext.AssertTrue(Abs((aExpectedImagZ)-(aActual.ImagPart.Z))<=(TEpsilon.Vector), Msg+' ImagPart.Z');
end;

procedure TCMathVectorsBase.AssertQuaternion(const Msg: String; aExpectedReal: Single; aExpectedImag: TPoint3D;
  aActual: TQuaternion3D);
begin
  TestContext.AssertTrue(Abs((aExpectedReal)-(aActual.RealPart))<=(TEpsilon.Vector), Msg+' RealPart');
  TestContext.AssertTrue(Abs((aExpectedImag.X)-(aActual.ImagPart.X))<=(TEpsilon.Vector), Msg+' ImagPart.X');
  TestContext.AssertTrue(Abs((aExpectedImag.Y)-(aActual.ImagPart.Y))<=(TEpsilon.Vector), Msg+' ImagPart.Y');
  TestContext.AssertTrue(Abs((aExpectedImag.Z)-(aActual.ImagPart.Z))<=(TEpsilon.Vector), Msg+' ImagPart.Z');
end;


constructor TCMathVectorsBase.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RegisterutmathvectorbaseTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin

end;

end.
