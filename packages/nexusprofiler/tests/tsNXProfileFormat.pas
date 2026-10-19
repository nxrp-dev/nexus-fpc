unit tsNXProfileFormat;

{$mode objfpc}{$H+}

interface
uses obNXTestRegistry;
procedure RegistertsNXProfileFormatTests(ARegistry: TNXTestRegistry);
implementation

uses
  obNXTestContext, obNXTestSuite,
  Classes,
  SysUtils,
  NXProfile;

type
  TTestRecordHeader = packed record
    Kind: Word;
    Flags: Word;
    Size: DWord;
  end;


function RepeatedString(ACharacter: AnsiChar; ACount: SizeInt): AnsiString;
begin
  SetLength(Result, ACount);
  if ACount > 0 then
    FillChar(Result[1], ACount, ACharacter);
end;

procedure PopulateTrace(AContext: TNXTestContext; AStream: TStream);
var
  Writer: TNXProfileWriter;
  ModuleInfo: TNXProfileModuleInfo;
  ProcedureInfo: TNXProfileProcedureInfo;
  ThreadInfo: TNXProfileThreadInfo;
  Calls: array[0..2] of TNXProfileCall;
  UnknownHeader: TTestRecordHeader;
  UnknownPayload: DWord;
begin
  Writer := TNXProfileWriter.Create(AStream, False, 1234, $1122334455667788,
    10000000, 500);
  try
    ModuleInfo := Default(TNXProfileModuleInfo);
    ModuleInfo.ModuleId := 7;
    ModuleInfo.Flags := 3;
    ModuleInfo.BuildId := $0102030405060708;
    ModuleInfo.LoadAddress := $0000000140000000;
    ModuleInfo.Timestamp := 510;
    ModuleInfo.ImagePath := 'C:\test\profiled.exe';
    AContext.AssertTrue(Writer.WriteModuleDefine(ModuleInfo),
      'module definition was not written');

    UnknownHeader.Kind := $8000;
    UnknownHeader.Flags := $55AA;
    UnknownHeader.Size := SizeOf(UnknownHeader) + SizeOf(UnknownPayload);
    UnknownPayload := $AABBCCDD;
    AStream.WriteBuffer(UnknownHeader, SizeOf(UnknownHeader));
    AStream.WriteBuffer(UnknownPayload, SizeOf(UnknownPayload));

    ProcedureInfo := Default(TNXProfileProcedureInfo);
    ProcedureInfo.ProcedureId := 91;
    ProcedureInfo.ModuleId := 7;
    ProcedureInfo.Flags := 5;
    ProcedureInfo.StableId := (QWord($88776655) shl 32) or $44332211;
    ProcedureInfo.CodeStart := $140001000;
    ProcedureInfo.CodeEnd := $140001080;
    ProcedureInfo.SourceLine := 42;
    ProcedureInfo.SourceColumn := 9;
    ProcedureInfo.Name := RepeatedString('N', 400);
    ProcedureInfo.UnitName := 'profile_unit';
    ProcedureInfo.SourceFile := 'C:\source\profile_unit.pas';
    AContext.AssertTrue(Writer.WriteProcedureDefine(ProcedureInfo),
      'procedure definition was not written');

    ThreadInfo := Default(TNXProfileThreadInfo);
    ThreadInfo.ThreadId := 17;
    ThreadInfo.Timestamp := 520;
    ThreadInfo.Name := 'worker';
    Writer.WriteThreadDefine(ThreadInfo);

    FillChar(Calls, SizeOf(Calls), 0);
    Calls[0].ProcedureId := 91;
    Calls[0].InclusiveTicks := 10;
    Calls[0].SelfTicks := 10;
    Calls[1].Flags := nxpcfUnwind;
    Calls[1].ProcedureId := 92;
    Calls[1].CallerProcedureId := 91;
    Calls[1].InclusiveTicks := 20;
    Calls[1].SelfTicks := 15;
    Calls[2].Flags := nxpcfUnmatched;
    Calls[2].ProcedureId := 999;
    Writer.WriteCallBlock(17, 1, 0, 530, 550, Calls);
    Writer.WriteCallBlock(17, 2, 0, 0, 0, []);
    Writer.WriteTraceGap(17, 2, 3, 27, 560);
    Writer.WriteModuleUnload(7, 4, 570);
    Writer.Finish(580, 27);
  finally
    Writer.Free;
  end;
end;

procedure CheckCompleteTrace(AContext: TNXTestContext; AStream: TStream);
var
  Reader: TNXProfileReader;
  Rec: TNXProfileRecord;
  Index: LongInt;
  Expected: array[0..7] of Word;
begin
  Expected[0] := nxprModuleDefine;
  Expected[1] := nxprProcedureDefine;
  Expected[2] := nxprThreadDefine;
  Expected[3] := nxprCallBlock;
  Expected[4] := nxprCallBlock;
  Expected[5] := nxprTraceGap;
  Expected[6] := nxprModuleUnload;
  Expected[7] := nxprTraceEnd;
  AStream.Position := 0;
  Reader := TNXProfileReader.Create(AStream, False);
  try
    AContext.AssertTrue(Reader.FormatVersion = NXPROFILE_FORMAT_VERSION,
      'format version did not round trip');
    AContext.AssertTrue(Reader.AbiVersion = NXPROFILE_ABI_VERSION,
      'ABI version did not round trip');
    AContext.AssertTrue(Reader.ProcessId = 1234, 'process ID did not round trip');
    AContext.AssertTrue(Reader.SessionId = $1122334455667788,
      'session ID did not round trip');
    AContext.AssertTrue(Reader.ClockFrequency = 10000000,
      'clock frequency did not round trip');
    Index := 0;
    while Reader.ReadNext(Rec) do
    begin
      AContext.AssertTrue(Index <= High(Expected), 'reader returned an extra record');
      AContext.AssertTrue(Rec.Kind = Expected[Index], 'reader returned the wrong record kind');
      case Rec.Kind of
        nxprModuleDefine:
          begin
            AContext.AssertTrue(Rec.ModuleInfo.ModuleId = 7, 'module ID mismatch');
            AContext.AssertTrue(Rec.ModuleInfo.ImagePath = 'C:\test\profiled.exe',
              'module path mismatch');
          end;
        nxprProcedureDefine:
          begin
            AContext.AssertTrue(Rec.ProcedureInfo.ProcedureId = 91,
              'procedure ID mismatch');
            AContext.AssertTrue(Length(Rec.ProcedureInfo.Name) = 400,
              'long procedure name was truncated');
            AContext.AssertTrue(Rec.ProcedureInfo.SourceLine = 42,
              'procedure source line mismatch');
          end;
        nxprCallBlock:
          if Rec.CallBlock.Sequence = 1 then
          begin
            AContext.AssertTrue(Length(Rec.CallBlock.Calls) = 3,
              'call count mismatch');
            AContext.AssertTrue((Rec.CallBlock.Calls[1].Flags and nxpcfUnwind) <> 0,
              'unwind call mismatch');
            AContext.AssertTrue(Rec.CallBlock.Calls[1].CallerProcedureId = 91,
              'caller ID mismatch');
            AContext.AssertTrue(Rec.CallBlock.Calls[1].SelfTicks = 15,
              'self time mismatch');
            AContext.AssertTrue((Rec.CallBlock.Calls[2].Flags and nxpcfUnmatched) <> 0,
              'orphan terminal evidence was not preserved');
          end
          else
            AContext.AssertTrue(Length(Rec.CallBlock.Calls) = 0,
              'empty call block did not round trip');
        nxprTraceGap:
          AContext.AssertTrue(Rec.LostEventCount = 27, 'gap loss count mismatch');
        nxprTraceEnd:
          AContext.AssertTrue(Rec.LostEventCount = 27, 'trace loss total mismatch');
      end;
      Inc(Index);
    end;
    AContext.AssertTrue(Index = Length(Expected), 'reader returned too few records');
    AContext.AssertTrue(not Reader.TruncatedTail, 'complete trace reported truncation');
    AContext.AssertTrue(Reader.LastCompleteOffset = AStream.Size,
      'last complete offset mismatch');
  finally
    Reader.Free;
  end;
end;

procedure CheckTruncatedTrace(AContext: TNXTestContext; AComplete: TMemoryStream);
var
  Truncated: TMemoryStream;
  Reader: TNXProfileReader;
  Rec: TNXProfileRecord;
  Count: LongInt;
begin
  Truncated := TMemoryStream.Create;
  try
    AComplete.Position := 0;
    Truncated.CopyFrom(AComplete, AComplete.Size - 3);
    Truncated.Position := 0;
    Reader := TNXProfileReader.Create(Truncated, False);
    try
      Count := 0;
      while Reader.ReadNext(Rec) do
        Inc(Count);
      AContext.AssertTrue(Count = 7, 'truncated trace lost a complete record');
      AContext.AssertTrue(Reader.TruncatedTail, 'truncated tail was not reported');
      AContext.AssertTrue(Reader.LastCompleteOffset < Truncated.Size,
        'truncated offset was reported as complete');
    finally
      Reader.Free;
    end;
  finally
    Truncated.Free;
  end;
end;

procedure CheckFileRoundTrip(AContext: TNXTestContext; const AFileName: AnsiString);
var
  Writer: TNXProfileWriter;
  Reader: TNXProfileReader;
  Rec: TNXProfileRecord;
begin
  Writer := TNXProfileWriter.Create(AFileName, 77, 88, 99, 100);
  try
    Writer.Finish(101, 0);
  finally
    Writer.Free;
  end;
  Reader := TNXProfileReader.Create(AFileName);
  try
    AContext.AssertTrue(Reader.ReadNext(Rec), 'file trace has no end record');
    AContext.AssertTrue(Rec.Kind = nxprTraceEnd, 'file trace end record mismatch');
    AContext.AssertTrue(not Reader.ReadNext(Rec), 'file trace has an extra record');
  finally
    Reader.Free;
  end;
  DeleteFile(AFileName);
end;

procedure CheckMalformedString(AContext: TNXTestContext);
var
  Stream: TMemoryStream;
  Writer: TNXProfileWriter;
  Reader: TNXProfileReader;
  Rec: TNXProfileRecord;
  Header: TTestRecordHeader;
  FixedData: array[0..31] of Byte;
  Unterminated: array[0..2] of AnsiChar;
  Raised: Boolean;
begin
  Stream := TMemoryStream.Create;
  try
    Writer := TNXProfileWriter.Create(Stream, False, 1, 2, 3, 4);
    try
      FillChar(FixedData, SizeOf(FixedData), 0);
      Unterminated[0] := 'b';
      Unterminated[1] := 'a';
      Unterminated[2] := 'd';
      Header.Kind := nxprModuleDefine;
      Header.Flags := 0;
      Header.Size := SizeOf(Header) + SizeOf(FixedData) + SizeOf(Unterminated);
      Stream.WriteBuffer(Header, SizeOf(Header));
      Stream.WriteBuffer(FixedData, SizeOf(FixedData));
      Stream.WriteBuffer(Unterminated, SizeOf(Unterminated));
    finally
      Writer.Free;
    end;
    Stream.Position := 0;
    Reader := TNXProfileReader.Create(Stream, False);
    try
      Raised := False;
      try
        Reader.ReadNext(Rec);
      except
        on ENXProfileFormatError do
          Raised := True;
      end;
      AContext.AssertTrue(Raised, 'unterminated bounded string was accepted');
    finally
      Reader.Free;
    end;
  finally
    Stream.Free;
  end;
end;

procedure CompleteTrace(AContext: TNXTestContext);
var lStream: TMemoryStream;
begin
  lStream := TMemoryStream.Create;
  try
    PopulateTrace(AContext, lStream);
    CheckCompleteTrace(AContext, lStream);
  finally
    lStream.Free;
  end;
end;

procedure TruncatedTrace(AContext: TNXTestContext);
var lStream: TMemoryStream;
begin
  lStream := TMemoryStream.Create;
  try
    PopulateTrace(AContext, lStream);
    CheckTruncatedTrace(AContext, lStream);
  finally
    lStream.Free;
  end;
end;

procedure FileRoundTrip(AContext: TNXTestContext);
var lFileName: string; lGuid: TGUID;
begin
  CreateGUID(lGuid);
  lFileName := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'nxtest-profile-' + GUIDToString(lGuid) + '.nxtrace';
  try
    CheckFileRoundTrip(AContext, lFileName);
  finally
    DeleteFile(lFileName);
  end;
end;

procedure RegistertsNXProfileFormatTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('Profiler.TraceFormat');
  lSuite.AddTest('CompleteTrace', @CompleteTrace, 'profiler');
  lSuite.AddTest('TruncatedTrace', @TruncatedTrace, 'profiler');
  lSuite.AddTest('FileRoundTrip', @FileRoundTrip, 'profiler');
  lSuite.AddTest('CheckMalformedString', @CheckMalformedString, 'profiler');
end;

end.
