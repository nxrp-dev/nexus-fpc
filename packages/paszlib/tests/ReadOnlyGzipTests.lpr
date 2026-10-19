// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program ReadOnlyGzipTests;
{$mode objfpc}{$H+}
{$ifndef NO_DEFLATE}{$fatal This regression requires -dNO_DEFLATE}{$endif}

uses Classes, SysUtils, PasZLibIO, obNXTestRegistry, obNXTestContext,
  obNXTestSuite, utNXTestConsole;

procedure TestReadOnlyGzip(AContext: TNXTestContext);
const
  // Independent Python gzip fixture for the eight bytes below.
  cGzip: array[0..27] of Byte = ($1F, $8B, $08, $00, $00, $00, $00, $00, $02, $03,
    $F3, $4B, $AD, $28, $2D, $66, $68, $F8, $0F, $00, $53, $F4, $F3, $39, $08, $00, $00, $00);
  cData: RawByteString = 'Nexus' + #0 + #128 + #255;
var
  lName: string;
  lFile: TFileStream;
  lGzip: Pointer;
  lBuffer: array[0..7] of Byte;
  lStream: TGZFileStream;
  lRejected: Boolean;
begin
  lName := GetTempFileName(GetCurrentDir, 'readonly');
  try
    lFile := TFileStream.Create(lName, fmCreate);
    try lFile.WriteBuffer(cGzip, SizeOf(cGzip)); finally lFile.Free; end;
    lGzip := gzopen(lName, 'rb');
    AContext.AssertTrue(lGzip <> nil, 'Read mode remains available');
    try
      AContext.AssertEquals(Length(cData), gzread(lGzip, @lBuffer[0], SizeOf(lBuffer)));
      AContext.AssertTrue(CompareMem(@lBuffer[0], @cData[1], Length(cData)));
    finally AContext.AssertEquals(0, gzclose(lGzip)); end;
    AContext.AssertTrue(gzopen(lName + '.write', 'wb') = nil, 'Write mode is rejected');
    AContext.AssertFalse(FileExists(lName + '.write'), 'No writer output is created');
    lStream := TGZFileStream.Create(lName, gzopenread);
    try
      lStream.ReadBuffer(lBuffer, SizeOf(lBuffer));
      AContext.AssertTrue(CompareMem(@lBuffer[0], @cData[1], Length(cData)));
      lRejected := False;
      try lStream.WriteBuffer(lBuffer, 1);
      except on EGzFileError do lRejected := True; end;
      AContext.AssertTrue(lRejected, 'A read stream rejects writes');
    finally lStream.Free; end;
    lRejected := False;
    try
      lStream := TGZFileStream.Create(lName + '.write', gzopenwrite);
      lStream.Free;
    except on EGzFileError do lRejected := True; end;
    AContext.AssertTrue(lRejected, 'The stream writer cannot be opened');
  finally
    DeleteFile(lName);
    DeleteFile(lName + '.write');
  end;
end;

var
  lRegistry: TNXTestRegistry;
  lSuite: TNXTestSuite;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lSuite := lRegistry.AddSuite('PasZLib');
    lSuite.AddTest('ReadOnlyGzip', @TestReadOnlyGzip, 'gzip');
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
