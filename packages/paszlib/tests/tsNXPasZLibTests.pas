// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit tsNXPasZLibTests;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterPasZLibTests(ARegistry: TNXTestRegistry);
implementation
uses Classes, SysUtils, PasZLibIO, PasZLib, CRC32, obNXTestContext, obNXTestSuite;

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

procedure TestSharedCRC32(AContext: TNXTestContext);
const
  cText: RawByteString = '123456789';
var
  lData: array[0..255] of Byte;
  lIndex: Integer;
  lCRC: Cardinal;
begin
  AContext.AssertEquals('CBF43926', IntToHex(UpdateCRC32(0, cText[1], Length(cText)), 8));
  AContext.AssertEquals($12345678, UpdateCRC32($12345678, lData, 0), 'Empty preserves the seed');
  AContext.AssertEquals($12345678, UpdateCRC32($12345678, lData, -1), 'Compiler negative counts remain empty');
  lCRC := UpdateCRC32(0, cText[1], 4);
  lCRC := UpdateCRC32(lCRC, cText[5], 5);
  AContext.AssertEquals('CBF43926', IntToHex(lCRC, 8), 'Compiler incremental checksum');
  for lIndex := Low(lData) to High(lData) do lData[lIndex] := lIndex;
  AContext.AssertEquals('29058C73', IntToHex(UpdateCRC32(0, lData, SizeOf(lData)), 8));
  AContext.AssertEquals('8490598D', IntToHex(UpdateCRC32($12345678, lData, SizeOf(lData)), 8));
  lCRC := 0;
  for lIndex := Low(lData) to High(lData) do
    lCRC := UpdateCRC32(lCRC, lData[lIndex], 1);
  AContext.AssertEquals('29058C73', IntToHex(lCRC, 8), 'Bytewise incremental checksum');
  AContext.AssertTrue(CRC32Table = PasZLib.get_crc_table, 'Compiler and compression share one table');
end;

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
    lRaw := CRC32Byte($12345678, lIndex);
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

// Independent fixture bytes generated by Python's gzip/zipfile standard libraries.
procedure TestGzipRejectedOpen(AContext: TNXTestContext);
var
  lName: string;
  lIndex: Integer;
  lByte: Byte;
begin
  lName := GetTempFileName(GetCurrentDir, 'gzip-rejected');
  DeleteFile(lName);
  lByte := 0;
  for lIndex := 1 to 16 do
  begin
    AContext.AssertTrue(PasZLibIO.gzopen(lName, '?') = nil, 'Invalid mode is rejected');
    AContext.AssertTrue(PasZLibIO.gzopen(lName, 'rb') = nil, 'Missing input is rejected');
    AContext.AssertEquals(0, FileWrite(TextRec(Output).Handle, lByte, 0),
      'Rejected opens preserve the console handle');
    AContext.AssertEquals(0, IOResult, 'Rejected opens consume their I/O status');
  end;
  AContext.AssertFalse(FileExists(lName), 'Rejected opens create no output');
end;

procedure TestGzipInteroperability(AContext: TNXTestContext);
const
  cData: RawByteString = 'Nexus' + #0 + #$80 + #$FF;
  cGzip: array[0..27] of Byte = ($1F, $8B, $08, $00, $00, $00, $00, $00, $02, $03, $F3, $4B, $AD, $28, $2D, $66, $68, $F8, $0F, $00, $53, $F4, $F3, $39, $08, $00, $00, $00);
var
  lFileName: string;
  lFile: TFileStream;
  lGzip: Pointer;
  lBuffer: array[0..31] of Byte;
  lCRC: Cardinal;
begin
  lFileName := GetTempFileName(GetTempDir(False), 'nxg');
  try
    lFile := TFileStream.Create(lFileName, fmCreate);
    try lFile.WriteBuffer(cGzip, SizeOf(cGzip)); finally lFile.Free; end;
    lGzip := PasZLibIO.gzopen(lFileName, 'rb');
    AContext.AssertTrue(lGzip <> nil);
    try
      AContext.AssertEquals(Length(cData), PasZLibIO.gzread(lGzip, @lBuffer[0], SizeOf(lBuffer)));
      AContext.AssertTrue(CompareMem(@cData[1], @lBuffer[0], Length(cData)), 'Independent GZIP payload');
      AContext.AssertEquals(0, PasZLibIO.gzread(lGzip, @lBuffer[0], SizeOf(lBuffer)));
    finally PasZLibIO.gzclose(lGzip); end;
    lGzip := PasZLibIO.gzopen(lFileName, 'wb');
    AContext.AssertTrue(lGzip <> nil);
    try AContext.AssertEquals(Length(cData), PasZLibIO.gzwrite(lGzip, @cData[1], Length(cData)));
    finally AContext.AssertEquals(0, PasZLibIO.gzclose(lGzip)); end;
    lFile := TFileStream.Create(lFileName, fmOpenRead);
    try
      lFile.Position := lFile.Size - 8;
      lFile.ReadBuffer(lCRC, SizeOf(lCRC));
      AContext.AssertEquals('39F3F453', IntToHex(lCRC, 8), 'Independent GZIP trailer CRC');
    finally lFile.Free; end;
  finally DeleteFile(lFileName); end;
end;

procedure TestMiniZipInteroperability(AContext: TNXTestContext);
const
  cData: RawByteString = 'Nexus' + #0 + #$80 + #$FF;
  cZip: array[0..121] of Byte = ($50, $4B, $03, $04, $14, $00, $00, $00, $08, $00, $00, $00, $21, $00, $53, $F4, $F3, $39, $0A, $00, $00, $00, $08, $00, $00, $00, $07, $00, $00, $00, $70, $61, $79, $6C, $6F, $61, $64, $F3, $4B, $AD, $28, $2D, $66, $68, $F8, $0F, $00, $50, $4B, $01, $02, $14, $03, $14, $00, $00, $00, $08, $00, $00, $00, $21, $00, $53, $F4, $F3, $39, $0A, $00, $00, $00, $08, $00, $00, $00, $07, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $80, $01, $00, $00, $00, $00, $70, $61, $79, $6C, $6F, $61, $64, $50, $4B, $05, $06, $00, $00, $00, $00, $01, $00, $01, $00, $35, $00, $00, $00, $2F, $00, $00, $00, $00, $00);
var
  lFileName: string;
  lFile: TFileStream;
  lArchive: Pointer;
  lBuffer: array[0..31] of Byte;
  lCRC: Cardinal;
  lBadZip: TBytes;
  lIndex: Integer;

  procedure ReadEntry(AExpectedClose: Integer);
  begin
    lArchive := PasZLibIO.unzOpen(PAnsiChar(lFileName));
    AContext.AssertTrue(lArchive <> nil);
    try
      AContext.AssertEquals(UNZ_OK, PasZLibIO.unzGoToFirstFile(lArchive));
      AContext.AssertEquals(UNZ_OK, PasZLibIO.unzOpenCurrentFile(lArchive));
      AContext.AssertEquals(4, PasZLibIO.unzReadCurrentFile(lArchive, @lBuffer[0], 4));
      AContext.AssertEquals(Length(cData) - 4, PasZLibIO.unzReadCurrentFile(lArchive, @lBuffer[4], SizeOf(lBuffer) - 4));
      AContext.AssertTrue(CompareMem(@cData[1], @lBuffer[0], Length(cData)), 'ZIP raw payload');
      AContext.AssertEquals(AExpectedClose, PasZLibIO.unzCloseCurrentFile(lArchive));
    finally PasZLibIO.unzClose(lArchive); end;
  end;
begin
  lFileName := GetTempFileName(GetTempDir(False), 'nxz');
  try
    lFile := TFileStream.Create(lFileName, fmCreate);
    try lFile.WriteBuffer(cZip, SizeOf(cZip)); finally lFile.Free; end;
    ReadEntry(UNZ_OK);
    // Corrupt matching local and central CRC fields, leaving the compressed bytes valid.
    SetLength(lBadZip, SizeOf(cZip));
    Move(cZip, lBadZip[0], SizeOf(cZip));
    lBadZip[14] := lBadZip[14] xor 1;
    for lIndex := 0 to Length(lBadZip) - 20 do
      if (lBadZip[lIndex] = $50) and (lBadZip[lIndex + 1] = $4B) and
         (lBadZip[lIndex + 2] = 1) and (lBadZip[lIndex + 3] = 2) then
      begin lBadZip[lIndex + 16] := lBadZip[lIndex + 16] xor 1; Break; end;
    lFile := TFileStream.Create(lFileName, fmCreate);
    try lFile.WriteBuffer(lBadZip[0], Length(lBadZip)); finally lFile.Free; end;
    ReadEntry(UNZ_CRCERROR);
    for lIndex := 0 to 1 do
    begin
      lArchive := PasZLibIO.zipOpen(PAnsiChar(lFileName), 0);
      AContext.AssertTrue(lArchive <> nil);
      try
        AContext.AssertEquals(ZIP_OK, PasZLibIO.zipOpenNewFileInZip(lArchive, 'payload',
          nil, nil, 0, nil, 0, nil, lIndex * 8, -1));
        AContext.AssertEquals(ZIP_OK, PasZLibIO.zipWriteInFileInZip(lArchive, @cData[1], 4));
        AContext.AssertEquals(ZIP_OK, PasZLibIO.zipWriteInFileInZip(lArchive, @cData[5], Length(cData) - 4));
        AContext.AssertEquals(ZIP_OK, PasZLibIO.zipCloseFileInZip(lArchive));
      finally AContext.AssertEquals(ZIP_OK, PasZLibIO.zipClose(lArchive, nil)); end;
      lFile := TFileStream.Create(lFileName, fmOpenRead);
      try
        lFile.Position := 14;
        lFile.ReadBuffer(lCRC, SizeOf(lCRC));
        AContext.AssertEquals('39F3F453', IntToHex(lCRC, 8), 'Independent ZIP local-header CRC');
      finally lFile.Free; end;
      ReadEntry(UNZ_OK);
    end;
  finally DeleteFile(lFileName); end;
end;

procedure TestMiniZipHighBitCRC(AContext: TNXTestContext);
const
  cZip: array[0..112] of Byte = ($50, $4B, $03, $04, $14, $00, $00, $00, $00, $00, $00, $00, $21, $00, $8D, $EF, $02, $D2, $01, $00, $00, $00, $01, $00, $00, $00, $07, $00, $00, $00, $70, $61, $79, $6C, $6F, $61, $64, $00, $50, $4B, $01, $02, $14, $03, $14, $00, $00, $00, $00, $00, $00, $00, $21, $00, $8D, $EF, $02, $D2, $01, $00, $00, $00, $01, $00, $00, $00, $07, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $80, $01, $00, $00, $00, $00, $70, $61, $79, $6C, $6F, $61, $64, $50, $4B, $05, $06, $00, $00, $00, $00, $01, $00, $01, $00, $35, $00, $00, $00, $26, $00, $00, $00, $00, $00);
var
  lFileName: string;
  lFile: TFileStream;
  lArchive: Pointer;
  lInfo: unz_file_info;
  lByte: Byte;
begin
  lFileName := GetTempFileName(GetTempDir(False), 'nxh');
  try
    lFile := TFileStream.Create(lFileName, fmCreate);
    try lFile.WriteBuffer(cZip, SizeOf(cZip)); finally lFile.Free; end;
    lArchive := PasZLibIO.unzOpen(PAnsiChar(lFileName));
    AContext.AssertTrue(lArchive <> nil);
    try
      AContext.AssertEquals(UNZ_OK, PasZLibIO.unzGoToFirstFile(lArchive));
      AContext.AssertEquals(UNZ_OK, PasZLibIO.unzGetCurrentFileInfo(lArchive, @lInfo, nil, 0, nil, 0, nil, 0));
      AContext.AssertEquals('D202EF8D', IntToHex(lInfo.crc, 8), 'Unsigned stored CRC');
      AContext.AssertEquals(UNZ_OK, PasZLibIO.unzOpenCurrentFile(lArchive));
      AContext.AssertEquals(1, PasZLibIO.unzReadCurrentFile(lArchive, @lByte, 1));
      AContext.AssertEquals(0, lByte);
      AContext.AssertEquals(UNZ_OK, PasZLibIO.unzCloseCurrentFile(lArchive));
    finally PasZLibIO.unzClose(lArchive); end;
  finally DeleteFile(lFileName); end;
end;

procedure RegisterPasZLibTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('PasZLib.Checksums');
  lSuite.AddTest('MiniZipHighBitCRC', @TestMiniZipHighBitCRC, 'checksums');
  lSuite := ARegistry.AddSuite('PasZLib.Gzip');
  lSuite.AddTest('GzipRejectedOpen', @TestGzipRejectedOpen, 'gzip');
  lSuite.AddTest('GzipInteroperability', @TestGzipInteroperability, 'gzip');
  lSuite := ARegistry.AddSuite('PasZLib.Archives');
  lSuite.AddTest('MiniZipInteroperability', @TestMiniZipInteroperability, 'archives');
  lSuite := ARegistry.AddSuite('PasZLib.Checksums');
  lSuite.AddTest('SharedCRC32', @TestSharedCRC32, 'checksums');
  lSuite.AddTest('CRC32Facade', @TestCRC32Facade, 'checksums');
  lSuite.AddTest('CRC32TableAndRawState', @TestCRC32TableAndRawState, 'checksums');
  lSuite.AddTest('CRC32Binary', @TestCRC32Binary, 'checksums');
  lSuite := ARegistry.AddSuite('PasZLib.Streams');
  lSuite.AddTest('StoredHeader', @TestStoredHeader, 'streams');
  lSuite.AddTest('StoredWindow', @TestStoredWindow, 'streams');
  lSuite.AddTest('FastWindow', @TestFastWindow, 'streams');
  lSuite.AddTest('DefaultWindow', @TestDefaultWindow, 'streams');
  lSuite.AddTest('MaximumWindow', @TestMaximumWindow, 'streams');
end;
end.
