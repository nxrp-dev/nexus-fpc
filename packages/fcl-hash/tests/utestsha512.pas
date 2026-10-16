unit utestsha512;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, fpsha512, fphashutils;

type

  { TTestSHA512 }

  TTestSHA512 = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Public
    Procedure TestHexString(Const aString,aDigest : String);
    Procedure TestBase64String(Const aString,aDigest : String);
    Procedure TestHMACString(Const aString,aKey,aDigest : String);
  public
    procedure TestEmpty;
    procedure TestSmallString;
    procedure TestLargeString;
    procedure TestEmptyBase64;
    procedure TestSmallBase64;
    procedure TestSmallHMAC;
    procedure TestHMACStream;
  end;

  { TTestSHA384 }

  TTestSHA384 = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
  Public
    Procedure TestHexString(Const aString,aDigest : String);
    Procedure TestBase64String(Const aString,aDigest : String);
    Procedure TestHMACString(Const aString,aKey,aDigest : String);
  public
    procedure TestEmpty;
    procedure TestSmallString;
    procedure TestLargeString;
    procedure TestEmptyBase64;
    procedure TestSmallBase64;
    procedure TestSmallHMAC;
    procedure TestHMACStream;
  end;


procedure Registerutestsha512Tests(ARegistry: TNXTestRegistry);

implementation

uses
  basenenc;

{ TTestSHA512 }

procedure TTestSHA512.TestHexString(const aString, aDigest: String);
var
  Digest : AnsiString;
  S : TBytes;

begin
  S:=[];
  Digest:='';
  S:=TEncoding.UTF8.GetAnsiBytes(aString);
  TSHA512.DigestHexa(S, Digest);
  TestContext.AssertTrue((aDigest)=(Digest), 'Correct hex digest');
end;

procedure TTestSHA512.TestBase64String(const aString, aDigest: String);
var
  Digest : AnsiString;
  S : TBytes;

begin
  S:=TEncoding.UTF8.GetAnsiBytes(aString);
  Digest:='';
  TSHA512.DigestBase64(S,False,Digest);
  TestContext.AssertTrue((aDigest)=(Digest), 'Correct base64 digest');
end;

procedure TTestSHA512.TestHMACString(const aString, aKey, aDigest: String);
var
  Digest : AnsiString;
  S,K : TBytes;

begin
  S:=TEncoding.UTF8.GetAnsiBytes(aString);
  K:=TEncoding.UTF8.GetAnsiBytes(aKey);
  TSHA512.HMACHexa(K,S,Digest);
  TestContext.AssertTrue((aDigest)=(Digest), 'Correct base64 digest');
end;


const
  Empty512Hash = 'CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E';
  // Taken from DCPCrypt
  Test1Out: array[0..63] of byte=
    ($dd,$af,$35,$a1,$93,$61,$7a,$ba,$cc,$41,$73,$49,$ae,$20,$41,$31,
     $12,$e6,$fa,$4e,$89,$a9,$7e,$a2,$0a,$9e,$ee,$e6,$4b,$55,$d3,$9a,
     $21,$92,$99,$2a,$27,$4f,$c1,$a8,$36,$ba,$3c,$23,$a3,$fe,$eb,$bd,
     $45,$4d,$44,$23,$64,$3c,$e8,$0e,$2a,$9a,$c9,$4f,$a5,$4c,$a4,$9f);
  Test2Out: array[0..63] of byte=
    ($8e,$95,$9b,$75,$da,$e3,$13,$da,$8c,$f4,$f7,$28,$14,$fc,$14,$3f,
     $8f,$77,$79,$c6,$eb,$9f,$7f,$a1,$72,$99,$ae,$ad,$b6,$88,$90,$18,
     $50,$1d,$28,$9e,$49,$00,$f7,$e4,$33,$1b,$99,$de,$c4,$b5,$43,$3a,
     $c7,$d3,$29,$ee,$b6,$dd,$26,$54,$5e,$96,$e5,$5b,$87,$4b,$e9,$09);


procedure TTestSHA512.TestEmpty;
begin
  TestHexString('',Empty512Hash);
end;

procedure TTestSHA512.TestSmallString;

Var
  S : AnsiString;
begin
  BytesToHexStr(S,@Test1Out,SizeOf(Test1Out));
  TestHexString('abc',S);
end;

procedure TTestSHA512.TestLargeString;
Var
  S : AnsiString;
begin
  BytesToHexStr(S,@Test2Out,SizeOf(Test2Out));
  TestHexString('abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu',S);
end;

procedure TTestSHA512.TestEmptyBase64;

begin
  TestBase64String('',Base64.Encode(Base16.Decode(Empty512Hash),False));
end;

procedure TTestSHA512.TestSmallBase64;
begin
  TestBase64String('abc',Base64.Encode(@Test1out,SizeOf(Test1Out),False));
end;

procedure TTestSHA512.TestSmallHMAC;

// Consts taken from HashlibTestBase

Const
  Expected = 'DEDFCEAD40225068527D0E53B7C892226E188891D939E21A0777A40EA2E29D7233638C178C879F26088A502A887674C01DF61EAF1635D707D114097ED1D0D762';
  DefaultData = 'HashLib4Pascal';

begin
  TestHMACString(DefaultData,'Hash' ,Expected);
end;

procedure TTestSHA512.TestHMACStream;

Var
  S : TStringStream;
  res : AnsiString;

begin
  BytesToHexStr(Res,@Test1Out,SizeOf(Test1Out));
  S:=TStringStream.Create('abc');
  try
    TestContext.AssertTrue((Res)=(TSHA512.StreamHexa(S)), 'Correct hash');
  finally
    S.Free;
  end;
end;


{ TTestSHA384 }

procedure TTestSHA384.TestHexString(const aString, aDigest: String);
var
  Digest : AnsiString;
  S : TBytes;

begin
  S:=[];
  Digest:='';
  S:=TEncoding.UTF8.GetAnsiBytes(aString);
  TSHA384.DigestHexa(S, Digest);
  TestContext.AssertTrue((aDigest)=(Digest), 'Correct hex digest');
end;

procedure TTestSHA384.TestBase64String(const aString, aDigest: String);
var
  Digest : AnsiString;
  S : TBytes;

begin
  S:=TEncoding.UTF8.GetAnsiBytes(aString);
  Digest:='';
  TSHA384.DigestBase64(S,False,Digest);
  TestContext.AssertTrue((aDigest)=(Digest), 'Correct base64 digest');
end;

procedure TTestSHA384.TestHMACString(const aString, aKey, aDigest: String);
var
  Digest : AnsiString;
  S,K : TBytes;

begin
  S:=TEncoding.UTF8.GetAnsiBytes(aString);
  K:=TEncoding.UTF8.GetAnsiBytes(aKey);
  TSHA384.HMACHexa(K,S,Digest);
  TestContext.AssertTrue((aDigest)=(Digest), 'Correct base64 digest');
end;

const
  Empty384Hash = '38B060A751AC96384CD9327EB1B1E36A21FDB71114BE07434C0CC7BF63F6E1DA274EDEBFE76F65FBD51AD2F14898B95B';
  Test1Out384: array[0..47] of byte=
    ($cb,$00,$75,$3f,$45,$a3,$5e,$8b,$b5,$a0,$3d,$69,$9a,$c6,$50,$07,
     $27,$2c,$32,$ab,$0e,$de,$d1,$63,$1a,$8b,$60,$5a,$43,$ff,$5b,$ed,
     $80,$86,$07,$2b,$a1,$e7,$cc,$23,$58,$ba,$ec,$a1,$34,$c8,$25,$a7);
  Test2Out384: array[0..47] of byte=
    ($09,$33,$0c,$33,$f7,$11,$47,$e8,$3d,$19,$2f,$c7,$82,$cd,$1b,$47,
     $53,$11,$1b,$17,$3b,$3b,$05,$d2,$2f,$a0,$80,$86,$e3,$b0,$f7,$12,
     $fc,$c7,$c7,$1a,$55,$7e,$2d,$b9,$66,$c3,$e9,$fa,$91,$74,$60,$39);

procedure TTestSHA384.TestEmpty;
begin
  TestHexString('',Empty384Hash);
end;

procedure TTestSHA384.TestSmallString;
Var
  S : AnsiString;
begin
  BytesToHexStr(S,@Test1Out384,SizeOf(Test1Out384));
  TestHexString('abc',S);
end;

procedure TTestSHA384.TestLargeString;
Var
  S : AnsiString;
begin
  BytesToHexStr(S,@Test2Out384,SizeOf(Test2Out384));
  TestHexString('abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu',S);
end;

procedure TTestSHA384.TestEmptyBase64;

begin
  TestBase64String('',Base64.Encode(Base16.Decode(Empty384Hash),False));
end;

procedure TTestSHA384.TestSmallBase64;
begin
  TestBase64String('abc',Base64.Encode(@Test1out384,SizeOf(Test1Out384),False));
end;

procedure TTestSHA384.TestSmallHMAC;

// Consts taken from HashlibTestBase

Const
  Expected = '3D6DCED731DAF3599CC0971646C1A8B8CCC61650722F111A9EB26CE7B65189EB220EACB09152D9A09065099FE6C1FDC9';
  DefaultData = 'HashLib4Pascal';

begin
  TestHMACString(DefaultData,'Hash' ,Expected);
end;

procedure TTestSHA384.TestHMACStream;

Var
  S : TStringStream;
  res : AnsiString;

begin
  BytesToHexStr(Res,@Test1Out384,SizeOf(Test1Out384));
  S:=TStringStream.Create('abc');
  try
    TestContext.AssertTrue((Res)=(TSHA384.StreamHexa(S)), 'Correct hash');
  finally
    S.Free;
  end;
end;




constructor TTestSHA512.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestSHA384.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestSHA512TestEmpty(AContext: TNXTestContext);
var lFixture: TTestSHA512;
begin
  lFixture:=TTestSHA512.Create(AContext, 'TestEmpty');
  try
    lFixture.TestEmpty;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA512TestSmallString(AContext: TNXTestContext);
var lFixture: TTestSHA512;
begin
  lFixture:=TTestSHA512.Create(AContext, 'TestSmallString');
  try
    lFixture.TestSmallString;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA512TestLargeString(AContext: TNXTestContext);
var lFixture: TTestSHA512;
begin
  lFixture:=TTestSHA512.Create(AContext, 'TestLargeString');
  try
    lFixture.TestLargeString;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA512TestEmptyBase64(AContext: TNXTestContext);
var lFixture: TTestSHA512;
begin
  lFixture:=TTestSHA512.Create(AContext, 'TestEmptyBase64');
  try
    lFixture.TestEmptyBase64;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA512TestSmallBase64(AContext: TNXTestContext);
var lFixture: TTestSHA512;
begin
  lFixture:=TTestSHA512.Create(AContext, 'TestSmallBase64');
  try
    lFixture.TestSmallBase64;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA512TestSmallHMAC(AContext: TNXTestContext);
var lFixture: TTestSHA512;
begin
  lFixture:=TTestSHA512.Create(AContext, 'TestSmallHMAC');
  try
    lFixture.TestSmallHMAC;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA512TestHMACStream(AContext: TNXTestContext);
var lFixture: TTestSHA512;
begin
  lFixture:=TTestSHA512.Create(AContext, 'TestHMACStream');
  try
    lFixture.TestHMACStream;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA384TestEmpty(AContext: TNXTestContext);
var lFixture: TTestSHA384;
begin
  lFixture:=TTestSHA384.Create(AContext, 'TestEmpty');
  try
    lFixture.TestEmpty;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA384TestSmallString(AContext: TNXTestContext);
var lFixture: TTestSHA384;
begin
  lFixture:=TTestSHA384.Create(AContext, 'TestSmallString');
  try
    lFixture.TestSmallString;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA384TestLargeString(AContext: TNXTestContext);
var lFixture: TTestSHA384;
begin
  lFixture:=TTestSHA384.Create(AContext, 'TestLargeString');
  try
    lFixture.TestLargeString;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA384TestEmptyBase64(AContext: TNXTestContext);
var lFixture: TTestSHA384;
begin
  lFixture:=TTestSHA384.Create(AContext, 'TestEmptyBase64');
  try
    lFixture.TestEmptyBase64;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA384TestSmallBase64(AContext: TNXTestContext);
var lFixture: TTestSHA384;
begin
  lFixture:=TTestSHA384.Create(AContext, 'TestSmallBase64');
  try
    lFixture.TestSmallBase64;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA384TestSmallHMAC(AContext: TNXTestContext);
var lFixture: TTestSHA384;
begin
  lFixture:=TTestSHA384.Create(AContext, 'TestSmallHMAC');
  try
    lFixture.TestSmallHMAC;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA384TestHMACStream(AContext: TNXTestContext);
var lFixture: TTestSHA384;
begin
  lFixture:=TTestSHA384.Create(AContext, 'TestHMACStream');
  try
    lFixture.TestHMACStream;
  finally lFixture.Free; end;
end;

procedure Registerutestsha512Tests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('utestsha512.TTestSHA512');
  lSuite.AddTest('TestEmpty', @RunTTestSHA512TestEmpty);
  lSuite.AddTest('TestSmallString', @RunTTestSHA512TestSmallString);
  lSuite.AddTest('TestLargeString', @RunTTestSHA512TestLargeString);
  lSuite.AddTest('TestEmptyBase64', @RunTTestSHA512TestEmptyBase64);
  lSuite.AddTest('TestSmallBase64', @RunTTestSHA512TestSmallBase64);
  lSuite.AddTest('TestSmallHMAC', @RunTTestSHA512TestSmallHMAC);
  lSuite.AddTest('TestHMACStream', @RunTTestSHA512TestHMACStream);
  lSuite:=ARegistry.AddSuite('utestsha512.TTestSHA384');
  lSuite.AddTest('TestEmpty', @RunTTestSHA384TestEmpty);
  lSuite.AddTest('TestSmallString', @RunTTestSHA384TestSmallString);
  lSuite.AddTest('TestLargeString', @RunTTestSHA384TestLargeString);
  lSuite.AddTest('TestEmptyBase64', @RunTTestSHA384TestEmptyBase64);
  lSuite.AddTest('TestSmallBase64', @RunTTestSHA384TestSmallBase64);
  lSuite.AddTest('TestSmallHMAC', @RunTTestSHA384TestSmallHMAC);
  lSuite.AddTest('TestHMACStream', @RunTTestSHA384TestHMACStream);
end;

end.
