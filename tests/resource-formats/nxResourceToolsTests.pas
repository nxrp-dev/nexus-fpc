program NXResourceToolsTests;

{$mode objfpc}{$H+}{$codepage UTF8}

uses
  {$ifdef unix}CWString,{$endif}
  Classes, SysUtils, ResourceCatalog, ResourceTools;

type
  TTargetCase = record
    Triple: string;
    ResourceId: Word;
  end;

  TCommandObserver = class
    Count: Integer;
    procedure Command(const ACommand: TResourceToolCommand);
  end;

const
  CTargets: array[0..12] of TTargetCase = (
    (Triple: 'i386-unknown-linux-gnu'; ResourceId: 111),
    (Triple: 'x86_64-unknown-linux-gnu'; ResourceId: 112),
    (Triple: 'aarch64-unknown-linux-gnu'; ResourceId: 113),
    (Triple: 'i686-pc-windows-msvc'; ResourceId: 101),
    (Triple: 'x86_64-pc-windows-msvc'; ResourceId: 102),
    (Triple: 'aarch64-pc-windows-msvc'; ResourceId: 103),
    (Triple: 'x86_64-unknown-linux-android24'; ResourceId: 122),
    (Triple: 'aarch64-unknown-linux-android24'; ResourceId: 123),
    (Triple: 'x86_64-apple-macosx11.0'; ResourceId: 132),
    (Triple: 'aarch64-apple-macosx11.0'; ResourceId: 133),
    (Triple: 'x86_64-apple-ios14.0-simulator'; ResourceId: 142),
    (Triple: 'aarch64-apple-ios14.0-simulator'; ResourceId: 143),
    (Triple: 'aarch64-apple-ios14.0'; ResourceId: 153));

  CScript =
    '#include "values.h"' + LineEnding +
    '#if !defined(RC_INVOKED) || !defined(FPC)' + LineEnding +
    '#error missing resource defines' + LineEnding + '#endif' + LineEnding +
    '#if ORDERED != 2 || defined(REMOVED)' + LineEnding +
    '#error wrong macro ordering' + LineEnding + '#endif' + LineEnding +
    '#if defined(__i386__)' + LineEnding + '#define CPU_ID 1' + LineEnding +
    '#elif defined(__x86_64__)' + LineEnding + '#define CPU_ID 2' + LineEnding +
    '#elif defined(__aarch64__)' + LineEnding + '#define CPU_ID 3' + LineEnding +
    '#else' + LineEnding + '#error wrong CPU' + LineEnding + '#endif' + LineEnding +
    '#if defined(_WIN32)' + LineEnding + '#define OS_ID 100' + LineEnding +
    '#elif defined(__ANDROID__)' + LineEnding + '#define OS_ID 120' + LineEnding +
    '#elif defined(__linux__)' + LineEnding + '#define OS_ID 110' + LineEnding +
    '#elif defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__)' + LineEnding +
    '#define OS_ID 130' + LineEnding +
    '#elif __is_target_environment(simulator)' + LineEnding +
    '#define OS_ID 140' + LineEnding +
    '#elif defined(__ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__)' + LineEnding +
    '#define OS_ID 150' + LineEnding +
    '#else' + LineEnding + '#error wrong OS' + LineEnding + '#endif' + LineEnding +
    'LANGUAGE 9, 1' + LineEnding +
    '1 RCDATA BEGIN CPU_ID, OS_ID END' + LineEnding +
    '2 RCDATA "payload.bin"' + LineEnding +
    'STRINGTABLE' + LineEnding + 'BEGIN' + LineEnding +
    '  1 LABEL' + LineEnding + '  2 HEADER_TEXT' + LineEnding +
    'END' + LineEnding;

var
  CheckCount: Integer;
  ArtifactRoot, SourceDirectory, IncludeDirectory, SourceFile: string;
  ResourceCompiler: TLLVMResourceCompiler;
  Observer: TCommandObserver;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(CheckCount);
  if not ACondition then raise Exception.Create(AMessage);
end;

procedure WriteText(const AFileName, AText: string);
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create(AText);
  try
    LStream.SaveToFile(AFileName);
  finally
    LStream.Free;
  end;
end;

function ReadText(const AFileName: string): string;
var
  LStream: TStringStream;
begin
  LStream := TStringStream.Create('');
  try
    LStream.LoadFromFile(AFileName);
    Result := LStream.DataString;
  finally
    LStream.Free;
  end;
end;

function StringSlot(AEntry: TResourceEntry; ASlot: Integer): UnicodeString;
var
  LSlot, LPosition, LLength, LIndex: Integer;
begin
  LPosition := 0;
  Result := '';
  for LSlot := 0 to ASlot do
  begin
    LLength := Integer(AEntry.Data[LPosition]) or
      (Integer(AEntry.Data[LPosition + 1]) shl 8);
    Inc(LPosition, 2);
    if LSlot = ASlot then
    begin
      SetLength(Result, LLength);
      for LIndex := 0 to LLength - 1 do
        Result[LIndex + 1] := WideChar(Word(AEntry.Data[LPosition + LIndex * 2]) or
          (Word(AEntry.Data[LPosition + LIndex * 2 + 1]) shl 8));
    end;
    Inc(LPosition, LLength * 2);
  end;
end;

procedure TCommandObserver.Command(const ACommand: TResourceToolCommand);
begin
  Inc(Count);
  Check((ACommand.Executable <> '') and (Length(ACommand.Arguments) <> 0),
    'Empty resource command');
end;

procedure TestWindowsQuoting;
var
  LArguments: TResourceArguments;
begin
  SetLength(LArguments, 1);
  LArguments[0] := '';
  Check(WindowsResourceArguments(LArguments) = '""', 'Empty Windows argument');
  LArguments[0] := 'C:\path with spaces\';
  Check(WindowsResourceArguments(LArguments) = '"C:\path with spaces\\"',
    'Trailing Windows path separator');
  LArguments[0] := '-DLABEL="Hello world"';
  Check(WindowsResourceArguments(LArguments) = '"-DLABEL=\"Hello world\""',
    'Embedded quotes in Windows define');
  SetLength(LArguments, 2);
  LArguments[0] := 'one';
  LArguments[1] := 'two words';
  Check(WindowsResourceArguments(LArguments) = '"one" "two words"',
    'Separate Windows arguments');
end;

procedure TestTargets;
var
  LIndex, LCommandCount: Integer;
  LCatalog: TResourceCatalog;
  LEntry: TResourceEntry;
  LPrefix, LDependencies, LExistingRes: string;
  LPlan: TResourceCompilePlan;
  LHadResource: Boolean;
begin
  WriteText(SourceFile, CScript);
  WriteText(SourceDirectory + 'payload.bin', 'first payload'#0#$FF);
  WriteText(IncludeDirectory + 'values.h', '#define HEADER_TEXT "From header"' + LineEnding);
  for LIndex := Low(CTargets) to High(CTargets) do
  begin
    ResourceCompiler.TargetTriple := CTargets[LIndex].Triple;
    LPrefix := ArtifactRoot + 'target-' + IntToStr(LIndex);
    LCommandCount := Observer.Count;
    LHadResource := FileExists(LPrefix + '.raw.res');
    if LHadResource then LExistingRes := ReadText(LPrefix + '.raw.res');
    LPlan := ResourceCompiler.Plan(SourceFile, LPrefix);
    Check(Observer.Count = LCommandCount, 'Planning executed a tool');
    Check(FileExists(LPlan.RawResFile) = LHadResource, 'Planning published a resource');
    if LHadResource then
      Check(ReadText(LPlan.RawResFile) = LExistingRes, 'Planning changed an existing resource');
    LCatalog := TResourceCatalog.Create;
    try
      ResourceCompiler.CompileRC(LCatalog, SourceFile, LPrefix);
      Check(Observer.Count = LCommandCount + 2, 'Clang/LLVM RC stage ordering');
      Check(LCatalog.Count = 3, 'Target resource count');
      LEntry := LCatalog.Find(ResourceId(10), ResourceId(1), 1033);
      Check((LEntry <> nil) and (Length(LEntry.Data) = 4) and
        (LEntry.Data[1] = 0) and (LEntry.Data[3] = 0) and
        (Integer(LEntry.Data[0]) + LEntry.Data[2] = CTargets[LIndex].ResourceId),
        'Wrong target macros for ' + CTargets[LIndex].Triple);
      LEntry := LCatalog.Find(ResourceId(10), ResourceId(2), 1033);
      Check(LEntry <> nil, 'Missing opaque payload');
      Check((Length(LEntry.Data) = 15) and (LEntry.Data[0] = Ord('f')) and
        (LEntry.Data[14] = $FF), 'Opaque RC payload');
      Check(LEntry.Origin = SourceFile, 'RC original-file provenance');
      LEntry := LCatalog.Find(ResourceId(6), ResourceId(1), 1033);
      Check(LEntry <> nil, 'Missing preprocessed string table');
      Check(StringSlot(LEntry, 1) = 'Hello "LLVM"', 'Quoted macro value');
      Check(StringSlot(LEntry, 2) = 'From header', 'Explicit include path');
      LDependencies := ReadText(LPlan.DependencyFile);
      Check(Pos('values.h', LDependencies) <> 0, 'Header dependency missing');
      Check(Pos('payload.bin', LDependencies) = 0,
        'Payload scan assumption changed; review conservative regeneration policy');
      LCatalog.SaveRes(LPrefix + '.res');
    finally
      LCatalog.Free;
    end;
  end;
end;

procedure TestPayloadRefresh;
var
  LCatalog: TResourceCatalog;
  LEntry: TResourceEntry;
begin
  ResourceCompiler.TargetTriple := 'x86_64-unknown-linux-gnu';
  WriteText(SourceDirectory + 'payload.bin', 'updated');
  LCatalog := TResourceCatalog.Create;
  try
    ResourceCompiler.CompileRC(LCatalog, SourceFile, ArtifactRoot + 'target-1');
    LEntry := LCatalog.Find(ResourceId(10), ResourceId(2), 1033);
    Check((LEntry <> nil) and (Length(LEntry.Data) = 7) and
      (LEntry.Data[0] = Ord('u')), 'Payload-only modification was not refreshed');
  finally
    LCatalog.Free;
  end;
end;

procedure ExpectFailure(const AText, AStage: string; AExpectedCommands: Integer;
  const ALocation: string = ''; const AReason: string = '');
var
  LCatalog: TResourceCatalog;
  LBefore: Integer;
  LPrefix: string;
  LPlan: TResourceCompilePlan;
  LRaised: Boolean;
begin
  LPrefix := ArtifactRoot + 'failure';
  LPlan := ResourceCompiler.Plan(SourceFile, LPrefix);
  WriteText(LPlan.RawResFile, 'stale compiled resource');
  WriteText(LPrefix + '.res', 'published sentinel');
  WriteText(SourceFile, AText);
  LBefore := Observer.Count;
  WriteLn('EXPECT REJECTION: ', AStage);
  Flush(Output);
  LCatalog := TResourceCatalog.Create;
  try
    LRaised := False;
    try
      ResourceCompiler.CompileRC(LCatalog, SourceFile, LPrefix);
    except
      on E: EResourceTool do
      begin
        LRaised := True;
        Check((Pos(SourceFile, E.Message) <> 0) and
          (Pos(AStage, E.Message) <> 0), 'Failure diagnostic origin/stage');
        if ALocation <> '' then
          Check(Pos(ALocation, E.Message) <> 0, 'Failure diagnostic source line');
        if AReason <> '' then
          Check(Pos(AReason, E.Message) <> 0, 'Failure diagnostic reason');
        if AStage = 'resource encoding' then
          Check(Pos('#63426', E.Message) <> 0, 'Encoding diagnostic LLVM issue');
        WriteLn('REJECTED: ', E.Message);
      end;
    end;
    Check(LRaised, 'Resource tool failure was accepted');
    Check(Observer.Count = LBefore + AExpectedCommands, 'Wrong failure stage ordering');
    Check(not FileExists(LPlan.RawResFile), 'Failed tool left a stale compiled resource');
    Check(LCatalog.Count = 0, 'Failed tool published catalog entries');
    Check(ReadText(LPrefix + '.res') = 'published sentinel', 'Failed tool changed published artifact');
  finally
    LCatalog.Free;
  end;
end;

procedure TestCodePages;
var
  LCatalog: TResourceCatalog;
  LEntry: TResourceEntry;
  LCase: Integer;
  LText: string;
  LExpected: UnicodeString;
begin
  for LCase := 0 to 10 do
  begin
    LExpected := 'caf' + WideChar($E9);
    if LCase in [0, 3, 5] then
    begin
      ResourceCompiler.CodePage := 1252;
      LText := 'caf' + AnsiChar($E9);
    end
    else
    begin
      ResourceCompiler.CodePage := 65001;
      if LCase = 10 then LExpected := LExpected + ' 日本語 العربية 😀';
      LText := UTF8Encode(LExpected);
    end;
    LText := 'LANGUAGE 9, 1' + LineEnding + 'STRINGTABLE' + LineEnding +
      'BEGIN' + LineEnding + '1 "' + LText + '"' + LineEnding + 'END' + LineEnding;
    case LCase of
      2: LText := '#pragma code_page(65001)' + LineEnding + LText;
      3: LText := '#pragma code_page( 1252 ) // matching legacy encoding' + LineEnding + LText;
      4, 5: LText := '#pragma code_page(DEFAULT)' + LineEnding + LText;
      6: LText := '#if 0' + LineEnding + '#pragma code_page(1252)' + LineEnding +
        '#endif' + LineEnding + '/* #pragma code_page(1252) */' + LineEnding + LText +
        'STRINGTABLE BEGIN 2 "#pragma code_page(1252)" END' + LineEnding;
      7: begin
        WriteText(IncludeDirectory + 'encoding.h', '#pragma code_page(65001)' + LineEnding);
        LText := '#include "encoding.h"' + LineEnding + LText;
      end;
      8: LText := '_Pragma("code_page(65001)")' + LineEnding + LText;
      9: LText := '#pragma nexus_padding "' + StringOfChar('x', 65530) +
        UTF8Encode(LExpected) + '"' + LineEnding + LText;
    end;
    WriteText(SourceFile, LText);
    LCatalog := TResourceCatalog.Create;
    try
      ResourceCompiler.CompileRC(LCatalog, SourceFile,
        ArtifactRoot + 'codepage-' + IntToStr(LCase));
      LEntry := LCatalog.Find(ResourceId(6), ResourceId(1), 1033);
      Check((LEntry <> nil) and (StringSlot(LEntry, 1) = LExpected),
        'Explicit/pragma RC codepage: ' + IntToStr(LCase));
      if LCase = 6 then
        Check(StringSlot(LEntry, 2) = '#pragma code_page(1252)',
          'Pragma text in a resource literal');
      LCatalog.SaveRes(ArtifactRoot + 'codepage-' + IntToStr(LCase) + '.res');
    finally
      LCatalog.Free;
    end;
  end;
  { The accepted contract rejects encoding changes before LLVM can corrupt
    text. Keep the original /C1252 + UTF-8 pragma regression as a rejection. }
  ResourceCompiler.CodePage := 1252;
  ExpectFailure('#pragma code_page(65001)' + LineEnding +
    'STRINGTABLE BEGIN 1 "café" END' + LineEnding, 'resource encoding', 1,
    SourceFile + ':1:');
  ResourceCompiler.CodePage := 65001;
  ExpectFailure('STRINGTABLE BEGIN 1 "first" END' + LineEnding +
    '#pragma code_page(1252)' + LineEnding +
    'STRINGTABLE BEGIN 2 "second" END' + LineEnding, 'resource encoding', 1,
    SourceFile + ':2:');
  WriteText(IncludeDirectory + 'encoding.h', '// header source location' + LineEnding +
    '#pragma code_page(1252)' + LineEnding);
  ExpectFailure('#include "encoding.h"' + LineEnding, 'resource encoding', 1,
    IncludeDirectory + 'encoding.h:2:');
  ExpectFailure('#pragma code_page(unknown)' + LineEnding,
    'resource encoding', 1, SourceFile + ':1:');
  ExpectFailure('#pragma code_page(4294967296)' + LineEnding,
    'resource encoding', 1, SourceFile + ':1:', 'malformed');
  ExpectFailure('#pragma code_page(65001' + LineEnding,
    'resource encoding', 1, SourceFile + ':1:');
  ExpectFailure('#pragma code_page(65001) unexpected' + LineEnding,
    'resource encoding', 1, SourceFile + ':1:');
  ExpectFailure('_Pragma("code_page(1252)")' + LineEnding,
    'resource encoding', 1, SourceFile + ':1:');
  WriteText(IncludeDirectory + 'encoding.h', '#pragma code_page(65001)' + LineEnding);
  ExpectFailure('#include "encoding.h"' + LineEnding +
    '#pragma code_page(1252)' + LineEnding, 'resource encoding', 1,
    SourceFile + ':2:');
  ExpectFailure('STRINGTABLE BEGIN 1 "caf' + AnsiChar($E9) + '" END' + LineEnding,
    'resource encoding', 1, SourceFile + ':1:');
  ExpectFailure('STRINGTABLE BEGIN 1 "' + AnsiChar($C0) + AnsiChar($AF) + '" END' + LineEnding,
    'resource encoding', 1);
  ExpectFailure('STRINGTABLE BEGIN 1 "' + AnsiChar($ED) + AnsiChar($A0) +
    AnsiChar($80) + '" END' + LineEnding, 'resource encoding', 1);
  ExpectFailure('STRINGTABLE BEGIN 1 "' + AnsiChar($F4) + AnsiChar($90) +
    AnsiChar($80) + AnsiChar($80) + '" END' + LineEnding, 'resource encoding', 1);
end;

begin
  if ParamCount <> 3 then
  begin
    WriteLn(StdErr, 'Usage: nxResourceToolsTests <clang> <llvm-rc> <artifact-root>');
    Halt(2);
  end;
  ArtifactRoot := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(3)));
  SourceDirectory := ArtifactRoot + 'source & Pascal''s résumé' + PathDelim;
  IncludeDirectory := ArtifactRoot + 'include & space' + PathDelim;
  ForceDirectories(SourceDirectory);
  ForceDirectories(IncludeDirectory);
  SourceFile := SourceDirectory + 'fixture.rc';
  Observer := TCommandObserver.Create;
  ResourceCompiler := TLLVMResourceCompiler.Create;
  try
    ResourceCompiler.ClangPath := ParamStr(1);
    ResourceCompiler.RCPath := ParamStr(2);
    ResourceCompiler.OnCommand := @Observer.Command;
    ResourceCompiler.IncludeDirectories.Add(IncludeDirectory);
    ResourceCompiler.Define('ORDERED', '1');
    ResourceCompiler.Undefine('ORDERED');
    ResourceCompiler.Define('ORDERED', '2');
    ResourceCompiler.Define('REMOVED');
    ResourceCompiler.Undefine('REMOVED');
    ResourceCompiler.Define('LABEL', '"Hello ""LLVM"""');
    TestWindowsQuoting;
    TestTargets;
    TestPayloadRefresh;
    ExpectFailure('#include "does-not-exist.h"' + LineEnding,
      'Clang resource preprocessing', 1);
    ExpectFailure('1 RCDATA BEGIN' + LineEnding, 'LLVM resource compilation', 2);
    TestCodePages;
  finally
    ResourceCompiler.Free;
    Observer.Free;
  end;
  WriteLn('PASS: ', CheckCount, ' resource tool checks across 13 targets');
end.
