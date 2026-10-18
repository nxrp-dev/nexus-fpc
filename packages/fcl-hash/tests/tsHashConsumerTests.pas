// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit tsHashConsumerTests;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterHashConsumerTests(ARegistry: TNXTestRegistry);
implementation
uses SysUtils, uuid, ntlm, fprsa, onetimepass, fppem, fpecc,
  obNXTestContext, obNXTestSuite;

function BytesHex(const ABytes: array of Byte): string;
var
  lIndex: Integer;
begin
  Result := '';
  for lIndex := 0 to High(ABytes) do
    Result := Result + IntToHex(ABytes[lIndex], 2);
end;

procedure TestUUIDNames(AContext: TNXTestContext);
var
  lNamespace, lUUID: TGuid;
begin
  lNamespace := StringToGUID('{6BA7B810-9DAD-11D1-80B4-00C04FD430C8}');
  uuid_create_md5_from_name(lUUID, lNamespace, 'www.widgets.com');
  AContext.AssertEquals('{3D813CBB-47FB-32BA-91DF-831E1593AC29}', GUIDToString(lUUID), GUIDToString(lUUID));
  uuid_create_sha1_from_name(lUUID, lNamespace, 'www.widgets.com');
  AContext.AssertEquals('{21F7F8DE-8051-5B89-8680-0195EF798B6A}', GUIDToString(lUUID), GUIDToString(lUUID));
  uuid_create_md5_from_name(lUUID, lNamespace, '');
  AContext.AssertEquals('{C87EE674-4DDC-3EFE-A74E-DFE25DA5D7B3}', GUIDToString(lUUID), GUIDToString(lUUID));
  uuid_create_sha1_from_name(lUUID, lNamespace, '');
  AContext.AssertEquals('{4EBD0208-8328-5D69-8C44-EC50939C0967}', GUIDToString(lUUID), GUIDToString(lUUID));
end;

procedure TestNTLMPassword(AContext: TNXTestContext);
begin
  AContext.AssertEquals('8846F7EAEE8FB117AD06BDD830B7586C', BytesHex(NTGenerate('password')));
  AContext.AssertEquals('31D6CFE0D16AE931B73C59D7E0C089C0', BytesHex(NTGenerate('')));
  AContext.AssertEquals('E52CAC67419A9A224A3B108F3FA6CB6D', BytesHex(LMGenerate('Password')));
  AContext.AssertEquals('AAD3B435B51404EEAAD3B435B51404EE', BytesHex(LMGenerate('')));
end;

procedure CheckRSAHash(AContext: TNXTestContext; const AHash: TRSAHashFuncInfo;
  const AExpected, AEmpty: string);
var
  lInput: RawByteString;
  lDigest: TBytes;
begin
  lInput := 'abc';
  SetLength(lDigest, AHash.DigestLen);
  AHash.Func(@lInput[1], Length(lInput), @lDigest[0]);
  AContext.AssertEquals(AExpected, BytesHex(lDigest));
  AHash.Func(nil, 0, @lDigest[0]);
  AContext.AssertEquals(AEmpty, BytesHex(lDigest));
end;

procedure TestRSAHashCallbacks(AContext: TNXTestContext);
var
  lHash: TRSAHashFuncInfo;
begin
  lHash.UseSHA1;
  CheckRSAHash(AContext, lHash, 'A9993E364706816ABA3E25717850C26C9CD0D89D',
    'DA39A3EE5E6B4B0D3255BFEF95601890AFD80709');
  lHash.UseSHA256;
  CheckRSAHash(AContext, lHash, 'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD',
    'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855');
  lHash.UseSHA384;
  CheckRSAHash(AContext, lHash, 'CB00753F45A35E8BB5A03D699AC65007272C32AB0EDED1631A8B605A43FF5BED8086072BA1E7CC2358BAECA134C825A7',
    '38B060A751AC96384CD9327EB1B1E36A21FDB71114BE07434C0CC7BF63F6E1DA274EDEBFE76F65FBD51AD2F14898B95B');
  lHash.UseSHA512;
  CheckRSAHash(AContext, lHash, 'DDAF35A193617ABACC417349AE20413112E6FA4E89A97EA20A9EEEE64B55D39A2192992A274FC1A836BA3C23A3FEEBBD454D4423643CE80E2A9AC94FA54CA49F',
    'CF83E1357EEFB8BDF1542850D66D8007D620E4050B5715DC83F4A921D36CE9CE47D0D13C5D85F2B0FF8318D2877EEC2F63B931BD47417A81A538327AF927DA3E');
end;

procedure TestRSAMGF1(AContext: TNXTestContext);
var
  lData: RawByteString;
begin
  lData := MGF1SHA1('abc', 45);
  AContext.AssertEquals('A03EB8AC3E6AD809805EC489CE85F2CEFE8D00C69595E19565AEC43DB343F6E8C11E1224A7617F6F8D54D36CA2',
    BytesHex(BytesOf(lData)));
  lData := MGF1SHA256('abc', 45);
  AContext.AssertEquals('CF2DB1AC9867DEBDF8CE91F99F141E5544BF26CA36B3FD4F8E4035EEC42CAB0D46C386EBCCEF82BA0BB0B095AA',
    BytesHex(BytesOf(lData)));
end;

procedure TestHOTPEmptyKey(AContext: TNXTestContext);
begin
  AContext.AssertEquals(328482, HOTPCalculateToken('', 0));
end;

procedure TestPEMThumbprint(AContext: TNXTestContext);
var
  lPrivate: TEccPrivateKey;
  lPublic: TEccPublicKey;
  lX, lY, lThumbprint: AnsiString;
begin
  AContext.AssertTrue(PemLoadECDSA('private-key.pem', lPrivate, lPublic,
    lX, lY, lThumbprint), 'Load existing EC fixture');
  AContext.AssertEquals('FVLEv-6RfvjEKme1nMwXhOm-ZgIfjEHSH0B-mOlIPf8', lThumbprint);
end;

procedure RegisterHashConsumerTests(ARegistry: TNXTestRegistry);
var
  lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('HashConsumers');
  lSuite.AddTest('UUIDNames', @TestUUIDNames);
  lSuite.AddTest('NTLMPassword', @TestNTLMPassword);
  lSuite.AddTest('RSAHashCallbacks', @TestRSAHashCallbacks);
  lSuite.AddTest('RSAMGF1', @TestRSAMGF1);
  lSuite.AddTest('HOTPEmptyKey', @TestHOTPEmptyKey);
  lSuite.AddTest('PEMThumbprint', @TestPEMThumbprint);
end;
end.
