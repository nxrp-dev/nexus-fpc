unit utestsha256;

{$mode objfpc}{$H+}

interface

uses
  obNXTestContext, obNXTestRegistry, obNXTestSuite, Classes, SysUtils, fpecc, fphashutils;

type

  { TTestSHA256 }

  TTestSHA256 = class(TObject)
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
    procedure TestEmptyBase64;
    procedure TestSmallBase64;
    procedure TestSmallHMAC;
    procedure TestHMACStream;
  end;

  { TTestECDSASHA256 }

  TTestECDSASHA256 = class(TObject)
  private
    FContext: TNXTestContext;
    FCaseName: string;
  protected
    property TestContext: TNXTestContext read FContext;
    property CaseName: string read FCaseName;
  public
    constructor Create(AContext: TNXTestContext; const ACaseName: string);
    // base64url encoded
    Const
    aInput =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJFUzI1NiJ9.' +
      'eyJpYXQiOjE1MTYyMzkwMjIsImV4cCI6MTUxNjI0OTAyMiwiaXNzIjoiRGVscGhpIEpPU0UgYW5kIEpXVCBMaWJyYXJ5In0';
    aOutput =
      '4QDMKAvHwb6pA5fN0oQjlzuKmPIlNpmIQ8vPH7zy4fjZdtcPVJMtfiVhztwQldQL9A5yzBKI8q2puVygm-2Adw';
    // Private key in PEM format
    Const APrivateKeyPem =
        '-----BEGIN EC PRIVATE KEY-----'+ #10+
        'MHcCAQEEIFzS3/5bCnrlpa4902/zkYzURF6E2D8pazgnJu4smhpQoAoGCCqGSM49'+ #10+
        'AwEHoUQDQgAEqTjyg2z65i+zbyUZW8BQ+K87DNsICRaEH7Fy7Rm3MseXy9ItSCQU'+ #10+
        'VeJbtO6kYUA00mx7bKoC1sx5sbtFExnYPQ=='+ #10+
        '-----END EC PRIVATE KEY-----';
   public
     Procedure TestSignVerify;
     Procedure TestVerify;
     Procedure TestVerifyFromKey;
   end;

procedure Registerutestsha256Tests(ARegistry: TNXTestRegistry);

implementation

uses HlpHashFactory,

   fppem, fpecdsa,  basenenc;

{ TTestECDSASHA256 }

procedure TTestECDSASHA256.TestSignVerify;

var
  aPrivateKey : TEccPrivateKey;
  aPublicKey : TEccPublicKey;
  aSignature : TECCSignature;
  X,Y : Ansistring;
  S : TStringStream;

begin
  S:=TStringStream.Create(APrivateKeyPem);
  try
    TestContext.AssertTrue(PemLoadECDSA(S,aPrivateKey,aPublicKey,X,Y), 'Loaded key');
    TestContext.AssertTrue(TECDSA.SignSHA256(aInput,aPrivateKey,aSignature), 'Encrypted');
    EccPublicKeyFromPrivateKey(aPublicKey,aPrivateKey);
    TestContext.AssertTrue(TECDSA.VerifySHA256(aInput,aPublicKey,aSignature), 'Verified our own');
    TestContext.AssertFalse(TECDSA.VerifySHA256(aInput + 'x',aPublicKey,aSignature), 'Reject changed payload');
  finally
    S.Free;
  end;
end;

procedure TTestECDSASHA256.TestVerify;

var
  aPrivateKey : TEccPrivateKey;
  aPublicKey : TEccPublicKey;
  aSignature : TECCSignature;
  X,Y : Ansistring;
  S : TStringStream;

begin
  S:=TStringStream.Create(APrivateKeyPem);
  try
    TestContext.AssertTrue(PemLoadECDSA(S,aPrivateKey,aPublicKey,X,Y), 'Loaded key');
    TestContext.AssertTrue(TECDSA.SignSHA256(aInput,aPrivateKey,aSignature), 'Encrypted');
    // Now verify with result of someone else (random elements)
    BytesToVar(Base64URL.Decode(aOutput),aSignature,SizeOf(aSignature));
    TestContext.AssertTrue(TECDSA.VerifySHA256(aInput,aPrivateKey,aSignature), 'Verified other');
  finally
    S.Free;
  end;

end;

procedure TTestECDSASHA256.TestVerifyFromKey;

Const
  // from JWT.IO
  aInput2 = 'eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiYWRtaW4iOnRydWUsImlhdCI6MTUxNjIzOTAyMn0';
  aOutput2 = 'tyh-VfuzIxCyGYDlkBA7DfyjrqmSHu6pQ2hoZuFqUSLPNY2N0mpHb3nk5K17HWP_3cYHBw7AhHale5wky6-sVA';

  aPrivateKey2: TEccPrivateKey = ($7a,$f6,$73,$2f,$58,$1d,$00,$5a,$fc,$f2,$16,$f6,$38,$5f,$f6,
                $37,$10,$29,$24,$2c,$c6,$08,$40,$dd,$7d,$2a,$7a,$55,$03,$b7,
                $d2,$1c);

var
  aSignature : TECCSignature;

begin
  BytesToVar(Base64URL.Decode(aOutput2),aSignature,SizeOf(aSignature));
  TestContext.AssertTrue(TECDSA.VerifySHA256(aInput2,aPrivateKey2,aSignature), 'Verified other');
end;

{ TTestSHA256 }

Procedure TTestSHA256.TestHexString(Const aString,aDigest : String);

var
  Digest : AnsiString;
  S : TBytes;

begin
  S:=[];
  Digest:='';
  S:=TEncoding.UTF8.GetAnsiBytes(aString);
  Digest := THashFactory.TCrypto.CreateSHA2_256.ComputeBytes(S).ToString(False);
  TestContext.AssertTrue((aDigest)=(Digest), 'Correct hex digest');
end;

procedure TTestSHA256.TestBase64String(const aString, aDigest: String);
var
  Digest : AnsiString;
  S : TBytes;

begin
  S:=TEncoding.UTF8.GetAnsiBytes(aString);
  Digest:='';
  Digest := Base64.Encode(THashFactory.TCrypto.CreateSHA2_256.ComputeBytes(S).GetBytes, False);
  TestContext.AssertTrue((aDigest)=(Digest), 'Correct base64 digest');
end;

procedure TTestSHA256.TestHMACString(const aString, aKey, aDigest: String);
var
  Digest : AnsiString;
  S,K : TBytes;

begin
  S:=TEncoding.UTF8.GetAnsiBytes(aString);
  K:=TEncoding.UTF8.GetAnsiBytes(aKey);
  Digest := THashFactory.THMAC.CreateHMAC(THashFactory.TCrypto.CreateSHA2_256, K).ComputeBytes(S).ToString(False);
  TestContext.AssertTrue((aDigest)=(Digest), 'Correct digest');
end;

procedure TTestSHA256.TestEmpty;


begin
  TestHexString('','E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855');
end;

procedure TTestSHA256.TestSmallString;

begin
  TestHexString('abc','BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD');
end;

procedure TTestSHA256.TestEmptyBase64;
begin
  TestBase64String('','47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU');
end;

procedure TTestSHA256.TestSmallBase64;

begin
  TestBase64String('abc','ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0');
end;

procedure TTestSHA256.TestSmallHMAC;
begin
  TestHMACString('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ',
                 'Secret key' ,
                 '6AE3261635F57BF68B6E3DF9C06ED14D3FA793F1B7BE55BC3429895B09F52F77');
end;

procedure TTestSHA256.TestHMACStream;

Var
  S : TStringStream;

begin
  S:=TStringStream.Create('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ');
  try
    TestContext.AssertTrue(('3964294B664613798D1A477EB8AD02118B48D0C5738C427613202F2ED123B5F1')=(THashFactory.TCrypto.CreateSHA2_256.ComputeStream(S).ToString(False)), 'Correct hash');
  finally
    S.Free;
  end;
end;


constructor TTestSHA256.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

constructor TTestECDSASHA256.Create(AContext: TNXTestContext; const ACaseName: string);
begin
  inherited Create;
  FContext:=AContext;
  FCaseName:=ACaseName;
end;

procedure RunTTestSHA256TestEmpty(AContext: TNXTestContext);
var lFixture: TTestSHA256;
begin
  lFixture:=TTestSHA256.Create(AContext, 'TestEmpty');
  try
    lFixture.TestEmpty;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA256TestSmallString(AContext: TNXTestContext);
var lFixture: TTestSHA256;
begin
  lFixture:=TTestSHA256.Create(AContext, 'TestSmallString');
  try
    lFixture.TestSmallString;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA256TestEmptyBase64(AContext: TNXTestContext);
var lFixture: TTestSHA256;
begin
  lFixture:=TTestSHA256.Create(AContext, 'TestEmptyBase64');
  try
    lFixture.TestEmptyBase64;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA256TestSmallBase64(AContext: TNXTestContext);
var lFixture: TTestSHA256;
begin
  lFixture:=TTestSHA256.Create(AContext, 'TestSmallBase64');
  try
    lFixture.TestSmallBase64;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA256TestSmallHMAC(AContext: TNXTestContext);
var lFixture: TTestSHA256;
begin
  lFixture:=TTestSHA256.Create(AContext, 'TestSmallHMAC');
  try
    lFixture.TestSmallHMAC;
  finally lFixture.Free; end;
end;

procedure RunTTestSHA256TestHMACStream(AContext: TNXTestContext);
var lFixture: TTestSHA256;
begin
  lFixture:=TTestSHA256.Create(AContext, 'TestHMACStream');
  try
    lFixture.TestHMACStream;
  finally lFixture.Free; end;
end;

procedure RunTTestECDSASHA256TestSignVerify(AContext: TNXTestContext);
var lFixture: TTestECDSASHA256;
begin
  lFixture:=TTestECDSASHA256.Create(AContext, 'TestSignVerify');
  try
    lFixture.TestSignVerify;
  finally lFixture.Free; end;
end;

procedure RunTTestECDSASHA256TestVerify(AContext: TNXTestContext);
var lFixture: TTestECDSASHA256;
begin
  lFixture:=TTestECDSASHA256.Create(AContext, 'TestVerify');
  try
    lFixture.TestVerify;
  finally lFixture.Free; end;
end;

procedure RunTTestECDSASHA256TestVerifyFromKey(AContext: TNXTestContext);
var lFixture: TTestECDSASHA256;
begin
  lFixture:=TTestECDSASHA256.Create(AContext, 'TestVerifyFromKey');
  try
    lFixture.TestVerifyFromKey;
  finally lFixture.Free; end;
end;

procedure Registerutestsha256Tests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite:=ARegistry.AddSuite('utestsha256.TTestSHA256');
  lSuite.AddTest('TestEmpty', @RunTTestSHA256TestEmpty);
  lSuite.AddTest('TestSmallString', @RunTTestSHA256TestSmallString);
  lSuite.AddTest('TestEmptyBase64', @RunTTestSHA256TestEmptyBase64);
  lSuite.AddTest('TestSmallBase64', @RunTTestSHA256TestSmallBase64);
  lSuite.AddTest('TestSmallHMAC', @RunTTestSHA256TestSmallHMAC);
  lSuite.AddTest('TestHMACStream', @RunTTestSHA256TestHMACStream);
  lSuite:=ARegistry.AddSuite('utestsha256.TTestECDSASHA256');
  lSuite.AddTest('TestSignVerify', @RunTTestECDSASHA256TestSignVerify);
  lSuite.AddTest('TestVerify', @RunTTestECDSASHA256TestVerify);
  lSuite.AddTest('TestVerifyFromKey', @RunTTestECDSASHA256TestVerifyFromKey);
end;

end.
