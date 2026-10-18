// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program CollationDataTests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, PasZLib, PasZLibIO,  utNXCollationData,
  obNXTestContext, obNXTestRegistry, obNXTestSuite, utNXTestConsole;

const
  cNonIgnorable = 'CollationTest_NON_IGNORABLE_SHORT.txt';
  cShifted = 'CollationTest_SHIFTED_SHORT.txt';

function ArchiveName: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'CollationTests.zip';
end;

procedure AssertNoExtractedFiles(AContext: TNXTestContext);
begin
  AContext.AssertFalse(FileExists(cNonIgnorable), 'No expanded input in working directory');
  AContext.AssertFalse(FileExists(cShifted), 'No expanded input in working directory');
  AContext.AssertFalse(FileExists(ExtractFilePath(ParamStr(0)) + cNonIgnorable),
    'No expanded input beside executable');
  AContext.AssertFalse(FileExists(ExtractFilePath(ParamStr(0)) + cShifted),
    'No expanded input beside executable');
end;

procedure CheckFixture(AContext: TNXTestContext; const AEntryName: string;
  ASize: Int64; ACRC: Cardinal);
var
  lStream: TMemoryStream;
begin
  lStream := TMemoryStream.Create;
  try
    LoadCollationData(lStream, ArchiveName, AEntryName);
    AContext.AssertEquals(ASize, lStream.Size, 'Original byte length');
    AContext.AssertTrue(ACRC = PasZLib.crc32(0, lStream.Memory, lStream.Size),
      'Original bytes, independent Python zlib expectation');
    AContext.AssertEquals(Int64(0), lStream.Position, 'Ready for the existing parser');
    // A second load must replace the existing member rather than append to it.
    LoadCollationData(lStream, ArchiveName, AEntryName);
    AContext.AssertEquals(ASize, lStream.Size);
    AContext.AssertTrue(ACRC = PasZLib.crc32(0, lStream.Memory, lStream.Size),
      'Repeated load preserves the original bytes');
    AssertNoExtractedFiles(AContext);
  finally
    lStream.Free;
  end;
end;

procedure TestNonIgnorable(AContext: TNXTestContext);
begin
  CheckFixture(AContext, cNonIgnorable, 2245489, $C958C551);
end;

procedure TestShifted(AContext: TNXTestContext);
begin
  CheckFixture(AContext, cShifted, 2482352, $934635D0);
end;

procedure TestMissingMember(AContext: TNXTestContext);
var
  lStream: TMemoryStream;
  lFailed: Boolean;
  lByte: Byte;
begin
  lStream := TMemoryStream.Create;
  try
    lByte := 42;
    lStream.WriteBuffer(lByte, 1);
    lFailed := False;
    try
      LoadCollationData(lStream, ArchiveName, 'missing.txt');
    except
      on lError: EReadError do lFailed := True;
    end;
    AContext.AssertTrue(lFailed, 'Missing member must fail');
    AContext.AssertEquals(Int64(0), lStream.Size, 'No stale or partial data');
    lStream.WriteBuffer(lByte, 1);
    AContext.AssertEquals(Int64(1), lStream.Size, 'Caller still owns a usable stream');
    AssertNoExtractedFiles(AContext);
  finally
    lStream.Free;
  end;
end;

procedure TestMissingArchive(AContext: TNXTestContext);
var
  lStream: TMemoryStream;
  lFailed: Boolean;
begin
  lStream := TMemoryStream.Create;
  try
    lFailed := False;
    try
      LoadCollationData(lStream, ArchiveName + '.missing', cNonIgnorable);
    except
      on lError: EFOpenError do lFailed := True;
    end;
    AContext.AssertTrue(lFailed, 'Missing archive must fail');
    AContext.AssertEquals(Int64(0), lStream.Size);
    AssertNoExtractedFiles(AContext);
  finally
    lStream.Free;
  end;
end;

procedure TestCorruptMember(AContext: TNXTestContext);
var
  lArchive, lStream: TMemoryStream;
  lBadName: string;
  lByte: Byte;
  lFailed: Boolean;
begin
  lBadName := GetTempFileName(GetTempDir(False), 'ucazip');
  lArchive := TMemoryStream.Create;
  try
    lArchive.LoadFromFile(ArchiveName);
    // Corrupt the first member after earlier output blocks; leave the ZIP directory intact.
    lArchive.Position := 200000;
    lArchive.ReadBuffer(lByte, 1);
    lByte := lByte xor $FF;
    lArchive.Position := 200000;
    lArchive.WriteBuffer(lByte, 1);
    lArchive.SaveToFile(lBadName);
    lStream := TMemoryStream.Create;
    try
      lFailed := False;
      try
        LoadCollationData(lStream, lBadName, cNonIgnorable);
      except
        on lError: EZipError do lFailed := True;
        on lError: EDecompressionError do lFailed := True;
      end;
      AContext.AssertTrue(lFailed, 'Corrupt compressed input must fail');
      AContext.AssertEquals(Int64(0), lStream.Size, 'Partial extraction is discarded');
      // Recovery also proves that the extractor did not free the borrowed stream.
      LoadCollationData(lStream, ArchiveName, cShifted);
      AContext.AssertEquals(Int64(2482352), lStream.Size);
      AssertNoExtractedFiles(AContext);
    finally
      lStream.Free;
    end;
  finally
    lArchive.Free;
    if FileExists(lBadName) and not DeleteFile(lBadName) then
      RaiseLastOSError;
  end;
end;

var
  lRegistry: TNXTestRegistry;
  lSuite: TNXTestSuite;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lSuite := lRegistry.AddSuite('CollationData');
    lSuite.AddTest('NonIgnorable', @TestNonIgnorable);
    lSuite.AddTest('Shifted', @TestShifted);
    lSuite.AddTest('MissingMember', @TestMissingMember);
    lSuite.AddTest('MissingArchive', @TestMissingArchive);
    lSuite.AddTest('CorruptMember', @TestCorruptMember);
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
