{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
program little_endian_platform;
{$mode objfpc}{$H+}
{$if defined(ENDIAN_BIG) or defined(FPC_BIG_ENDIAN)}
  {$fatal Unexpected big-endian platform macro}
{$endif}
{$if not defined(ENDIAN_LITTLE) or not defined(FPC_LITTLE_ENDIAN)}
  {$fatal Missing little-endian platform macro}
{$endif}
uses SysUtils, obNXTestRegistry, obNXTestContext, utNXTestConsole;
var TestContext: TNXTestContext;
type
  TSmallRecord = packed record
    A, B, C: Byte;
  end;
  TPackedValues = bitpacked array[0..15] of 0..31;
var
  lNumber: QWord;
  lBytes: array[0..7] of Byte;
  lEncoded: TBytes;
  lGuid: TGUID;
  lValues: TPackedValues;
  lRecord: TSmallRecord;
  lIndex: Integer;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  TestContext.AssertTrue(ACondition, AMessage);
end;

function SumRecord(AValue: TSmallRecord): Integer; noinline;
begin
  Result := AValue.A + AValue.B * 2 + AValue.C * 3;
end;

procedure NativeLayout(AContext: TNXTestContext);
begin
  TestContext := AContext;
  lNumber := QWord($0102030405060708);
  Move(lNumber, lBytes, SizeOf(lBytes));
  for lIndex := 0 to High(lBytes) do
    Check(lBytes[lIndex] = 8 - lIndex, 'Native byte order');
  for lIndex := Low(lValues) to High(lValues) do
    lValues[lIndex] := lIndex + 7;
  for lIndex := Low(lValues) to High(lValues) do
    Check(lValues[lIndex] = lIndex + 7, 'Bitpacked element access');
  lRecord.A := 17;
  lRecord.B := 41;
  lRecord.C := 63;
  Check(SumRecord(lRecord) = 288, 'Composite parameter placement');
end;

procedure DataConversions(AContext: TNXTestContext);
begin
  TestContext := AContext;
  lNumber := QWord($0102030405060708);
  Check(NToBE(Word($1234)) = $3412, '16-bit network order');
  Check(NToBE(LongWord($12345678)) = $78563412, '32-bit network order');
  Check(NToBE(lNumber) = QWord($0807060504030201), '64-bit network order');
  Check(BEToN(NToBE(lNumber)) = lNumber, 'Network round trip');
  Check(NToLE(lNumber) = lNumber, 'Little-endian conversion');
  lEncoded := TEncoding.BigEndianUnicode.GetBytes(UnicodeString('A') + WideChar($20AC));
  Check((Length(lEncoded) = 4) and (lEncoded[0] = 0) and
    (lEncoded[1] = $41) and (lEncoded[2] = $20) and (lEncoded[3] = $AC), 'UTF-16BE bytes');
  Check(TEncoding.BigEndianUnicode.GetString(lEncoded) = UnicodeString('A') + WideChar($20AC),
    'UTF-16BE round trip');
  lEncoded := TBytes.Create($00, $11, $22, $33, $44, $55, $66, $77,
    $88, $99, $AA, $BB, $CC, $DD, $EE, $FF);
  lGuid := TGUID.Create(lEncoded, 0, True);
  Check(GUIDToString(lGuid) = '{00112233-4455-6677-8899-AABBCCDDEEFF}', 'Big-endian GUID data');
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('Compiler.Layout').AddTest('LittleEndian', @NativeLayout, 'compiler-layout');
    lRegistry.AddSuite('RTL.DataConversions').AddTest('NetworkUnicodeAndGuid', @DataConversions, 'rtl-conversion');
    ExitCode := RunConsoleTests(lRegistry);
  finally TestContext := nil; lRegistry.Free; end;
end.
