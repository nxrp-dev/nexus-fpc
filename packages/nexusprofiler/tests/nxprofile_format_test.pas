program nxprofile_format_test;

{$mode objfpc}{$H+}

uses
  Classes,
  SysUtils,
  NXProfile;

type
  TTestRecordHeader = packed record
    Kind: Word;
    Flags: Word;
    Size: DWord;
  end;

procedure Check(ACondition: Boolean; const AMessage: AnsiString);
begin
  if not ACondition then
    raise Exception.Create(AMessage);
end;

function RepeatedString(ACharacter: AnsiChar; ACount: SizeInt): AnsiString;
begin
  SetLength(Result, ACount);
  if ACount > 0 then
    FillChar(Result[1], ACount, ACharacter);
end;

procedure PopulateTrace(AStream: TStream);
var
  Writer: TNXProfileWriter;
  ModuleInfo: TNXProfileModuleInfo;
  ProcedureInfo: TNXProfileProcedureInfo;
  ThreadInfo: TNXProfileThreadInfo;
  Events: array[0..2] of TNXProfileEvent;
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
    Check(Writer.WriteModuleDefine(ModuleInfo),
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
    Check(Writer.WriteProcedureDefine(ProcedureInfo),
      'procedure definition was not written');

    ThreadInfo := Default(TNXProfileThreadInfo);
    ThreadInfo.ThreadId := 17;
    ThreadInfo.Timestamp := 520;
    ThreadInfo.Name := 'worker';
    Writer.WriteThreadDefine(ThreadInfo);

    FillChar(Events, SizeOf(Events), 0);
    Events[0].Kind := nxpeEnter;
    Events[0].ProcedureId := 91;
    Events[0].Timestamp := 530;
    Events[1].Kind := nxpeUnwind;
    Events[1].ProcedureId := 91;
    Events[1].Timestamp := 540;
    Events[2].Kind := nxpeLeave;
    Events[2].ProcedureId := 999;
    Events[2].Timestamp := 550;
    Writer.WriteEventBlock(17, 1, 0, Events);
    Writer.WriteEventBlock(17, 2, 0, []);
    Writer.WriteTraceGap(17, 2, 3, 27, 560);
    Writer.WriteModuleUnload(7, 4, 570);
    Writer.Finish(580, 27);
  finally
    Writer.Free;
  end;
end;

procedure CheckCompleteTrace(AStream: TStream);
var
  Reader: TNXProfileReader;
  Rec: TNXProfileRecord;
  Index: LongInt;
  Expected: array[0..7] of Word;
begin
  Expected[0] := nxprModuleDefine;
  Expected[1] := nxprProcedureDefine;
  Expected[2] := nxprThreadDefine;
  Expected[3] := nxprEventBlock;
  Expected[4] := nxprEventBlock;
  Expected[5] := nxprTraceGap;
  Expected[6] := nxprModuleUnload;
  Expected[7] := nxprTraceEnd;
  AStream.Position := 0;
  Reader := TNXProfileReader.Create(AStream, False);
  try
    Check(Reader.FormatVersion = NXPROFILE_FORMAT_VERSION,
      'format version did not round trip');
    Check(Reader.AbiVersion = NXPROFILE_ABI_VERSION,
      'ABI version did not round trip');
    Check(Reader.ProcessId = 1234, 'process ID did not round trip');
    Check(Reader.SessionId = $1122334455667788,
      'session ID did not round trip');
    Check(Reader.ClockFrequency = 10000000,
      'clock frequency did not round trip');
    Index := 0;
    while Reader.ReadNext(Rec) do
    begin
      Check(Index <= High(Expected), 'reader returned an extra record');
      Check(Rec.Kind = Expected[Index], 'reader returned the wrong record kind');
      case Rec.Kind of
        nxprModuleDefine:
          begin
            Check(Rec.ModuleInfo.ModuleId = 7, 'module ID mismatch');
            Check(Rec.ModuleInfo.ImagePath = 'C:\test\profiled.exe',
              'module path mismatch');
          end;
        nxprProcedureDefine:
          begin
            Check(Rec.ProcedureInfo.ProcedureId = 91,
              'procedure ID mismatch');
            Check(Length(Rec.ProcedureInfo.Name) = 400,
              'long procedure name was truncated');
            Check(Rec.ProcedureInfo.SourceLine = 42,
              'procedure source line mismatch');
          end;
        nxprEventBlock:
          if Rec.EventBlock.Sequence = 1 then
          begin
            Check(Length(Rec.EventBlock.Events) = 3,
              'event count mismatch');
            Check(Rec.EventBlock.Events[1].Kind = nxpeUnwind,
              'unwind event mismatch');
            Check(Rec.EventBlock.Events[2].ProcedureId = 999,
              'orphan leave evidence was not preserved');
          end
          else
            Check(Length(Rec.EventBlock.Events) = 0,
              'empty event block did not round trip');
        nxprTraceGap:
          Check(Rec.LostEventCount = 27, 'gap loss count mismatch');
        nxprTraceEnd:
          Check(Rec.LostEventCount = 27, 'trace loss total mismatch');
      end;
      Inc(Index);
    end;
    Check(Index = Length(Expected), 'reader returned too few records');
    Check(not Reader.TruncatedTail, 'complete trace reported truncation');
    Check(Reader.LastCompleteOffset = AStream.Size,
      'last complete offset mismatch');
  finally
    Reader.Free;
  end;
end;

procedure CheckTruncatedTrace(AComplete: TMemoryStream);
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
      Check(Count = 7, 'truncated trace lost a complete record');
      Check(Reader.TruncatedTail, 'truncated tail was not reported');
      Check(Reader.LastCompleteOffset < Truncated.Size,
        'truncated offset was reported as complete');
    finally
      Reader.Free;
    end;
  finally
    Truncated.Free;
  end;
end;

procedure CheckFileRoundTrip(const AFileName: AnsiString);
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
    Check(Reader.ReadNext(Rec), 'file trace has no end record');
    Check(Rec.Kind = nxprTraceEnd, 'file trace end record mismatch');
    Check(not Reader.ReadNext(Rec), 'file trace has an extra record');
  finally
    Reader.Free;
  end;
  DeleteFile(AFileName);
end;

procedure CheckMalformedString;
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
      Check(Raised, 'unterminated bounded string was accepted');
    finally
      Reader.Free;
    end;
  finally
    Stream.Free;
  end;
end;

var
  Stream: TMemoryStream;
  FileName: AnsiString;
begin
  Stream := TMemoryStream.Create;
  try
    PopulateTrace(Stream);
    CheckCompleteTrace(Stream);
    CheckTruncatedTrace(Stream);
  finally
    Stream.Free;
  end;
  FileName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'nxprofile-format-test-' + IntToStr(GetProcessID) + '.nxp';
  CheckFileRoundTrip(FileName);
  CheckMalformedString;
  WriteLn('NXProfile reader/writer tests passed');
end.
