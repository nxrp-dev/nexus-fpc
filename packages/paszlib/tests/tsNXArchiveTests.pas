{ Migrated from tczipper, tczstreamseek and testsingle.
  Original ZIP tests copyright (c) 2012-2014 Free Pascal Development Team.
  See packages/COPYING.FPC. }
unit tsNXArchiveTests;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterArchiveTests(ARegistry: TNXTestRegistry);
implementation
uses Classes, SysUtils, Contnrs, PasZLibIO, nullstream,
  obNXTestContext, obNXTestSuite;

type
  TZipFixture = class
  private
    FContext: TNXTestContext;
  public
    Directory, ArchiveName: string;
    Zipper: TZipper;
    Streams: TObjectList;
    Expected: RawByteString;
    Extracted: Integer;
    constructor Create(AContext: TNXTestContext);
    destructor Destroy; override;
    procedure Add(const AName, AData: RawByteString);
    procedure StartFile(Sender: TObject; const AName: AnsiString);
    procedure EndFile(Sender: TObject; const ARatio: Double);
    procedure CreateStream(Sender: TObject; var AStream: TStream;
      AItem: TFullZipFileEntry);
    procedure DoneStream(Sender: TObject; var AStream: TStream;
      AItem: TFullZipFileEntry);
  end;

function ReadBytes(const AName: string): RawByteString;
var lFile: TFileStream;
begin
  lFile := TFileStream.Create(AName, fmOpenRead);
  try
    SetLength(Result, lFile.Size);
    if Length(Result) > 0 then lFile.ReadBuffer(Result[1], Length(Result));
  finally lFile.Free; end;
end;

constructor TZipFixture.Create(AContext: TNXTestContext);
var lGuid: TGUID;
begin
  inherited Create;
  FContext := AContext;
  CreateGUID(lGuid);
  Directory := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'nxtest-zip-' + GUIDToString(lGuid);
  FContext.AssertTrue(ForceDirectories(Directory), 'Create private archive directory');
  Directory := IncludeTrailingPathDelimiter(Directory);
  ArchiveName := Directory + 'archive.zip';
  Streams := TObjectList.Create(True);
  Zipper := TZipper.Create;
  Zipper.FileName := ArchiveName;
end;

destructor TZipFixture.Destroy;
var lSearch: TSearchRec;
begin
  Zipper.Free;
  Streams.Free;
  if FindFirst(Directory + '*', faAnyFile, lSearch) = 0 then
  begin
    repeat
      if (lSearch.Name <> '.') and (lSearch.Name <> '..') then
        DeleteFile(Directory + lSearch.Name);
    until FindNext(lSearch) <> 0;
    FindClose(lSearch);
  end;
  RemoveDir(ExcludeTrailingPathDelimiter(Directory));
  inherited Destroy;
end;

procedure TZipFixture.Add(const AName, AData: RawByteString);
var lStream: TStringStream;
begin
  lStream := TStringStream.Create(AData);
  Streams.Add(lStream);
  Zipper.Entries.AddFileEntry(lStream, AName);
end;

procedure TZipFixture.StartFile(Sender: TObject; const AName: AnsiString);
begin FContext.AssertTrue(AName <> '', 'Callback filename is present'); end;
procedure TZipFixture.EndFile(Sender: TObject; const ARatio: Double);
begin FContext.AssertTrue(ARatio >= 0, 'Callback compression ratio is nonnegative'); end;
procedure TZipFixture.CreateStream(Sender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
begin AStream := TMemoryStream.Create; end;
procedure TZipFixture.DoneStream(Sender: TObject; var AStream: TStream;
  AItem: TFullZipFileEntry);
var lData: RawByteString;
begin
  try
    AStream.Position := 0;
    SetLength(lData, AStream.Size);
    if Length(lData) > 0 then AStream.ReadBuffer(lData[1], Length(lData));
    FContext.AssertEquals(Expected, lData, AItem.ArchiveFileName);
    Inc(Extracted);
  finally FreeAndNil(AStream); end;
end;

procedure FileRoundTrip(AContext: TNXTestContext);
var lFixture: TZipFixture; lInput: TStringList; lUnzip: TUnZipper;
  lFirst, lSecond: RawByteString;
begin
  lFixture := TZipFixture.Create(AContext);
  try
    lInput := TStringList.Create;
    try
      lInput.Text := 'This is an uncompressed file.' + LineEnding + 'And another line.';
      lInput.SaveToFile(lFixture.Directory + 'first.txt');
      lInput.Text := 'Have you looked into using fpcup today?' + LineEnding +
        'It works nicely with fpc and goes well with a fruity red wine, too.';
      lInput.SaveToFile(lFixture.Directory + 'second.txt');
    finally lInput.Free; end;
    lFirst := ReadBytes(lFixture.Directory + 'first.txt');
    lSecond := ReadBytes(lFixture.Directory + 'second.txt');
    lFixture.Zipper.OnStartFile := @lFixture.StartFile;
    lFixture.Zipper.OnEndFile := @lFixture.EndFile;
    lFixture.Zipper.Entries.AddFileEntry(lFixture.Directory + 'first.txt', 'first.txt');
    lFixture.Zipper.Entries.AddFileEntry(lFixture.Directory + 'second.txt', 'second.txt');
    lFixture.Zipper.ZipAllFiles;
    DeleteFile(lFixture.Directory + 'first.txt');
    DeleteFile(lFixture.Directory + 'second.txt');
    lUnzip := TUnZipper.Create;
    try
      lUnzip.FileName := lFixture.ArchiveName;
      lUnzip.OutputPath := lFixture.Directory;
      lUnzip.OnStartFile := @lFixture.StartFile;
      lUnzip.OnEndFile := @lFixture.EndFile;
      lUnzip.Examine;
      lUnzip.UnZipAllFiles;
      AContext.AssertEquals(lFirst, ReadBytes(lFixture.Directory + 'first.txt'));
      AContext.AssertEquals(lSecond, ReadBytes(lFixture.Directory + 'second.txt'));
    finally lUnzip.Free; end;
  finally lFixture.Free; end;
end;

procedure CheckEntries(AContext: TNXTestContext; ACount: Integer; AEmpty: Boolean);
var lFixture: TZipFixture; lUnzip: TUnZipper; lIndex: Integer;
  lSelected: TStringList;
begin
  lFixture := TZipFixture.Create(AContext);
  try
    if AEmpty then lFixture.Expected := '' else lFixture.Expected := 'abcd';
    for lIndex := 1 to ACount do lFixture.Add(IntToStr(lIndex), lFixture.Expected);
    if not AEmpty then
    begin
      lFixture.Zipper.Entries[0].CompressionLevel := clDefault;
      lFixture.Zipper.Entries[1].CompressionLevel := clNone;
    end;
    lFixture.Zipper.ZipAllFiles;
    lUnzip := TUnZipper.Create;
    lSelected := TStringList.Create;
    try
      lUnzip.FileName := lFixture.ArchiveName;
      lUnzip.Examine;
      AContext.AssertEquals(ACount, lUnzip.Entries.Count, 'Entry count including Zip64');
      if not AEmpty then
      begin
        AContext.AssertEquals(Length(lFixture.Expected), lUnzip.Entries[0].Size, 'Small stream original length');
        AContext.AssertEquals(Length(lFixture.Expected), lUnzip.Entries[1].CompressedSize, 'Stored stream has no compression overhead');
      end;
      lUnzip.OnCreateStream := @lFixture.CreateStream;
      lUnzip.OnDoneStream := @lFixture.DoneStream;
      if AEmpty then lUnzip.UnZipAllFiles
      else
        for lIndex := 0 to lUnzip.Entries.Count - 1 do
        begin
          lSelected.Clear;
          lSelected.Add(lUnzip.Entries[lIndex].ArchiveFileName);
          lUnzip.UnZipFiles(lSelected);
        end;
      AContext.AssertEquals(ACount, lFixture.Extracted, 'Every entry extracted and checked');
    finally lSelected.Free; lUnzip.Free; end;
  finally lFixture.Free; end;
end;
procedure StreamEntries(AContext: TNXTestContext);
begin CheckEntries(AContext, 2, False); end;
procedure EmptyEntries(AContext: TNXTestContext);
begin CheckEntries(AContext, 10, True); end;
procedure Zip64EntryCount(AContext: TNXTestContext);
begin CheckEntries(AContext, 65537, True); end;

procedure EntryNames(AContext: TNXTestContext);
var lFixture: TZipFixture; lUnzip: TUnZipper; lLongName: string;
begin
  lFixture := TZipFixture.Create(AContext);
  try
    lLongName := StringOfChar('A', 259);
    lFixture.Add(lLongName, 'a');
    lFixture.Add('test\afile.txt', 'a');
    lFixture.Zipper.ZipAllFiles;
    lUnzip := TUnZipper.Create;
    try
      lUnzip.FileName := lFixture.ArchiveName;
      lUnzip.Examine;
      AContext.AssertEquals(lLongName, lUnzip.Entries[0].ArchiveFileName);
      {$IFDEF MSWINDOWS}
      AContext.AssertEquals('test/afile.txt', lUnzip.Entries[1].ArchiveFileName);
      {$ELSE}
      AContext.AssertEquals('test\afile.txt', lUnzip.Entries[1].ArchiveFileName);
      {$ENDIF}
    finally lUnzip.Free; end;
  finally lFixture.Free; end;
end;

procedure SaveAndExtractMember(AContext: TNXTestContext);
var lFixture: TZipFixture; lCopy, lTarget: string;
begin
  lFixture := TZipFixture.Create(AContext);
  try
    lFixture.Add('files/file1.txt', 'selected content');
    lFixture.Add('other.txt', 'unselected content');
    lFixture.Zipper.ZipAllFiles;
    lCopy := lFixture.Directory + 'copy.zip';
    lFixture.Zipper.SaveToFile(lCopy);
    AContext.AssertTrue(FileExists(lCopy), 'SaveToFile publishes the new filename');
    lTarget := lFixture.Directory + 'chosen.txt';
    TUnZipper.Unzip(lFixture.ArchiveName, 'files/file1.txt', lTarget);
    AContext.AssertEquals('selected content', ReadBytes(lTarget), 'Single member to explicit path');
    AContext.AssertFalse(FileExists(lFixture.Directory + 'other.txt'), 'Only selected member extracted');
  finally lFixture.Free; end;
end;

procedure LargeZip64(AContext: TNXTestContext);
var lFixture: TZipFixture; lSource: TNullStream; lUnzip: TUnZipper;
begin
  if GetEnvironmentVariable('NXTEST_LARGE_ZIP') <> '1' then
    AContext.Skip('Opt in with NXTEST_LARGE_ZIP=1 for the 4 GiB Zip64 workload');
  lFixture := TZipFixture.Create(AContext);
  try
    lSource := TNullStream.Create;
    lFixture.Streams.Add(lSource);
    lSource.Size := QWord($FFFFFFFF) + 1;
    lFixture.Zipper.Entries.AddFileEntry(lSource, 'HugeString.txt');
    lFixture.Zipper.ZipAllFiles;
    lUnzip := TUnZipper.Create;
    try
      lUnzip.FileName := lFixture.ArchiveName;
      lUnzip.Examine;
      AContext.AssertEquals(1, lUnzip.Entries.Count);
      AContext.AssertEquals('HugeString.txt', lUnzip.Entries[0].ArchiveFileName);
    finally lUnzip.Free; end;
  finally lFixture.Free; end;
end;

procedure DecompressionSeek(AContext: TNXTestContext);
const cValue: DWord = $123456;
var lData: TMemoryStream; lCompressor: TCompressionStream;
  lReader: TDecompressionStream; lRejected: Boolean;
begin
  lData := TMemoryStream.Create;
  try
    lCompressor := TCompressionStream.Create(clMax, lData);
    try lCompressor.WriteDWord(cValue); finally lCompressor.Free; end;
    lData.Position := 0;
    lReader := TDecompressionStream.Create(lData);
    try
      AContext.AssertTrue(lReader.ReadDWord = cValue, 'Initial value');
      AContext.AssertEquals(4, lReader.Position, 'Position after read');
      lReader.Seek(0, soFromBeginning);
      AContext.AssertEquals(0, lReader.Position, 'Absolute rewind');
      AContext.AssertTrue(lReader.ReadDWord = cValue, 'Read after rewind');
      lReader.Seek(-4, soFromCurrent);
      AContext.AssertEquals(0, lReader.Position, 'Relative rewind');
      AContext.AssertTrue(lReader.ReadDWord = cValue, 'Read after relative rewind');
      lReader.Seek(0, soFromBeginning);
      lRejected := False;
      try lReader.Seek(-4, soFromCurrent);
      except on EDecompressionError do lRejected := True; end;
      AContext.AssertTrue(lRejected, 'Seeking before beginning is rejected');
      lReader.Seek(4, soFromBeginning);
      AContext.AssertEquals(4, lReader.Position, 'Seek to end');
      lRejected := False;
      try lReader.Seek(40, soFromBeginning);
      except on EDecompressionError do lRejected := True; end;
      AContext.AssertTrue(lRejected, 'Seeking beyond end is rejected');
    finally lReader.Free; end;
  finally lData.Free; end;
end;

procedure RegisterArchiveTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('PasZLib.Archives');
  lSuite.AddTest('FileRoundTrip', @FileRoundTrip, 'archive-files');
  lSuite.AddTest('StreamEntries', @StreamEntries, 'archive-entries');
  lSuite.AddTest('EmptyEntries', @EmptyEntries, 'archive-entries');
  lSuite.AddTest('Zip64EntryCount', @Zip64EntryCount, 'archive-zip64');
  lSuite.AddTest('EntryNames', @EntryNames, 'archive-metadata');
  lSuite.AddTest('SaveAndExtractMember', @SaveAndExtractMember, 'archive-files');
  lSuite.AddTest('LargeZip64', @LargeZip64, 'archive-zip64');
  lSuite := ARegistry.AddSuite('PasZLib.Streams');
  lSuite.AddTest('DecompressionSeek', @DecompressionSeek, 'compression-streams');
end;
end.
