// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit tsNXPasZLibTests;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterPasZLibTests(ARegistry: TNXTestRegistry);
implementation
uses Classes, SysUtils, ZStream, PasZLib, utNXPasZLibCRC32, obNXTestContext, obNXTestSuite;

procedure CheckWindowRoundTrip(AContext: TNXTestContext; ALevel: TCompressionLevel);
var
  lSource, lCompressed, lRestored: TMemoryStream;
  lCompressor: TCompressionStream;
  lDecompressor: TDecompressionStream;
  lInput: RawByteString;
  lIndex: Integer;
  lState: QWord;
begin
  SetLength(lInput, 196608);
  lState := 12345;
  for lIndex := 1 to Length(lInput) do
  begin
    lState := (lState * 1664525 + 1013904223) and $FFFFFFFF;
    lInput[lIndex] := AnsiChar(lState shr 24);
  end;
  lSource := TMemoryStream.Create;
  lCompressed := TMemoryStream.Create;
  lRestored := TMemoryStream.Create;
  try
    lSource.WriteBuffer(lInput[1], Length(lInput));
    lSource.Position := 0;
    lCompressor := TCompressionStream.Create(ALevel, lCompressed);
    try
      lCompressor.CopyFrom(lSource, 0);
    finally
      lCompressor.Free;
    end;
    lCompressed.Position := 0;
    lDecompressor := TDecompressionStream.Create(lCompressed);
    try
      lRestored.CopyFrom(lDecompressor, 0);
    finally
      lDecompressor.Free;
    end;
    AContext.AssertEquals(lSource.Size, lRestored.Size, 'Window slide changed data length');
    AContext.AssertTrue(CompareMem(lSource.Memory, lRestored.Memory, lSource.Size),
      'Window slide changed data bytes');
  finally
    lRestored.Free;
    lCompressed.Free;
    lSource.Free;
  end;
end;

procedure TestStoredHeader(AContext: TNXTestContext);
var
  lOutput: TMemoryStream;
  lCompressor: TCompressionStream;
  lHeader: array[0..1] of Byte;
  lValue: Byte;
begin
  lOutput := TMemoryStream.Create;
  try
    lCompressor := TCompressionStream.Create(clNone, lOutput);
    try
      lValue := 42;
      lCompressor.WriteBuffer(lValue, 1);
    finally
      lCompressor.Free;
    end;
    lOutput.Position := 0;
    lOutput.ReadBuffer(lHeader, SizeOf(lHeader));
    AContext.AssertEquals(0, lHeader[1] shr 6, 'Stored compression should use the fastest-level hint');
    AContext.AssertEquals(0, ((lHeader[0] * 256) + lHeader[1]) mod 31);
  finally
    lOutput.Free;
  end;
end;

procedure TestStoredWindow(AContext: TNXTestContext);
begin CheckWindowRoundTrip(AContext, clNone); end;
procedure TestFastWindow(AContext: TNXTestContext);
begin CheckWindowRoundTrip(AContext, clFastest); end;
procedure TestDefaultWindow(AContext: TNXTestContext);
begin CheckWindowRoundTrip(AContext, clDefault); end;
procedure TestMaximumWindow(AContext: TNXTestContext);
begin CheckWindowRoundTrip(AContext, clMax); end;

procedure TestCRC32Facade(AContext: TNXTestContext);
const
  cText: RawByteString = '123456789';
var
  lSeed: Cardinal;
  lByte: Byte;
begin
  AContext.AssertEquals('CBF43926', IntToHex(PasZLib.crc32(0, PAnsiChar(cText), 9), 8));
  AContext.AssertEquals(0, PasZLib.crc32($12345678, nil, 17), 'Nil initializes CRC');
  lByte := 0;
  AContext.AssertEquals($12345678, PasZLib.crc32($12345678, @lByte, 0), 'Empty preserves seed');
  lSeed := PasZLib.crc32(0, PAnsiChar(cText), 4);
  AContext.AssertEquals('CBF43926', IntToHex(PasZLib.crc32(lSeed, @cText[5], 5), 8), 'Chunk continuation');
end;

procedure TestCRC32TableAndRawState(AContext: TNXTestContext);
var
  lIndex, lBit: Integer;
  lValue, lRaw: Cardinal;
  lTable: PCardinal;
begin
  lTable := PasZLib.get_crc_table;
  AContext.AssertTrue(lTable = PasZLib.get_crc_table, 'Stable table pointer');
  for lIndex := 0 to 255 do
  begin
    lValue := lIndex;
    for lBit := 1 to 8 do
      if (lValue and 1) <> 0 then lValue := (lValue shr 1) xor $EDB88320
      else lValue := lValue shr 1;
    AContext.AssertTrue(lValue = lTable[lIndex], 'IEEE table entry');
    lRaw := PasZLibCRC32Byte($12345678, lIndex);
    AContext.AssertTrue(lRaw = (lTable[Byte($78 xor lIndex)] xor $00123456),
      'Uncomplemented ZIP state step');
  end;
end;

procedure TestCRC32Binary(AContext: TNXTestContext);
var
  lData: array[0..255] of Byte;
  lIndex: Integer;
begin
  for lIndex := 0 to High(lData) do lData[lIndex] := lIndex;
  // Independently fixed with zlib.crc32(bytes(range(256)), seed).
  AContext.AssertEquals('29058C73', IntToHex(PasZLib.crc32(0, @lData[0], 256), 8));
  AContext.AssertEquals('8490598D', IntToHex(PasZLib.crc32($12345678, @lData[0], 256), 8));
end;

procedure RegisterPasZLibTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('PasZLib');
  lSuite.AddTest('CRC32Facade', @TestCRC32Facade);
  lSuite.AddTest('CRC32TableAndRawState', @TestCRC32TableAndRawState);
  lSuite.AddTest('CRC32Binary', @TestCRC32Binary);
  lSuite.AddTest('StoredHeader', @TestStoredHeader);
  lSuite.AddTest('StoredWindow', @TestStoredWindow);
  lSuite.AddTest('FastWindow', @TestFastWindow);
  lSuite.AddTest('DefaultWindow', @TestDefaultWindow);
  lSuite.AddTest('MaximumWindow', @TestMaximumWindow);
end;
end.
