// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program DwarfArtifactTests;
{$mode objfpc}{$H+}
uses Classes, SysUtils, Process, obNXTestRegistry, obNXTestContext, utNXTestConsole;

type
  TRangeMode = (rmOriginal, rmRetained, rmDiscarded);

function CaseDirectory(const ASuffix: string): string;
var
  lId: TGUID;
begin
  CreateGUID(lId);
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(4))) +
    Copy(GUIDToString(lId), 2, 36) + ASuffix;
  ForceDirectories(Result);
end;

function FixturePath(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1))) +
    'tests/compiler-regressions/' + AName;
end;

function RunTool(AContext: TNXTestContext; const ADirectory, AExecutable: string;
  const AArguments: array of string): string;
var
  lStatus, lRunStatus: Integer;
begin
  lRunStatus := RunCommandIndir(ADirectory, AExecutable, AArguments, Result,
    lStatus, [poStderrToOutput]);
  AContext.AssertEquals(0, lRunStatus, 'Could not execute ' + AExecutable + ': ' + Result);
  AContext.AssertEquals(0, lStatus, AExecutable + ' failed: ' + Result);
end;

function CompileFixture(AContext: TNXTestContext;
  const ACPU, AOS, ADirectory, ASource, AExtraOption: string;
  const ALibraryDirectory: string = ''): string;
var
  lCompiler, lCPUOption, lRTL, lLibraryDirectory: string;
begin
  lLibraryDirectory := ALibraryDirectory;
  if lLibraryDirectory = '' then lLibraryDirectory := ADirectory;
  lCompiler := ExpandFileName(ParamStr(2));
  lCPUOption := '-P' + ACPU;
  lRTL := '-Fu' + ExtractFilePath(FixturePath(ASource));
  if DirectoryExists(lCompiler) then
  begin
    lCompiler := lCompiler + '/cross/' + ACPU + '-' + AOS;
    lRTL := '-Fu' + lCompiler + '/rtl';
    lCompiler := lCompiler + '/nxpc-' + ACPU;
    lCPUOption := '-n';
  end;
  RunTool(AContext, ADirectory, lCompiler,
    [lCPUOption, '-T' + AOS, lRTL, '-B', '-gw3', '-Xm', AExtraOption,
     '-Fu' + ExtractFilePath(FixturePath(ASource)), '-Fl' + lLibraryDirectory,
     '-FU' + ADirectory, '-FE' + ADirectory, FixturePath(ASource)]);
  Result := ADirectory + '/' + ChangeFileExt(ASource, '.exe');
end;

procedure VerifyRanges(AContext: TNXTestContext; const AImage: string;
  AExpectedRanges: Integer);
var
  lLines, lFields: TStringList;
  lLine, lOutput: string;
  lStart, lFinish: QWord;
  lCount: Integer;
begin
  lOutput := RunTool(AContext, ExtractFilePath(AImage), ExpandFileName(ParamStr(3)),
    ['--debug-ranges', AImage]);
  lLines := TStringList.Create;
  lFields := TStringList.Create;
  try
    lLines.Text := lOutput;
    lCount := 0;
    for lLine in lLines do
    begin
      lFields.Clear;
      ExtractStrings([' ', #9], [], PChar(lLine), lFields);
      if (lFields.Count = 3) and
        TryStrToQWord('$' + lFields[1], lStart) and
        TryStrToQWord('$' + lFields[2], lFinish) and
        (lStart <> High(QWord)) and (lStart <> High(LongWord)) then
      begin
        AContext.AssertTrue((lStart <> 0) and (lFinish > lStart),
          'Every retained range must describe live code: ' + lLine);
        Inc(lCount);
      end;
    end;
    AContext.AssertEquals(AExpectedRanges, lCount,
      'Only retained functions may contribute DWARF ranges: ' + lOutput);
  finally
    lFields.Free;
    lLines.Free;
  end;
end;

procedure VerifyProcedureRange(AContext: TNXTestContext; const AImage,
  AName: string; ARetained: Boolean);
var
  lOutput: string;
  lStart, lFinish: QWord;

  function ReadAddress(const AAttribute: string): QWord;
  var
    lText: string;
    lFirst, lLast: Integer;
  begin
    lFirst := Pos(AAttribute, lOutput);
    AContext.AssertTrue(lFirst > 0, AName + ' must have ' + AAttribute + ': ' + lOutput);
    lText := Copy(lOutput, lFirst, Length(lOutput));
    lFirst := Pos('(0x', lText);
    lLast := Pos(')', lText);
    AContext.AssertTrue((lFirst > 0) and (lLast > lFirst + 3),
      'Expected an address for ' + AAttribute + ': ' + lText);
    AContext.AssertTrue(TryStrToQWord('$' + Copy(lText, lFirst + 3,
      lLast - lFirst - 3), Result), 'Invalid address: ' + lText);
  end;

begin
  lOutput := RunTool(AContext, ExtractFilePath(AImage), ExpandFileName(ParamStr(3)),
    ['--name=' + AName, AImage]);
  lStart := ReadAddress('DW_AT_low_pc');
  lFinish := ReadAddress('DW_AT_high_pc');
  if ARetained then
    AContext.AssertTrue((lStart > 0) and (lFinish > lStart),
      AName + ' must retain its live address range: ' + lOutput)
  else
    AContext.AssertTrue((lStart = 0) and (lFinish = 0),
      AName + ' must have an empty range after removal: ' + lOutput);
end;

procedure CheckWindowsRanges(AContext: TNXTestContext; const ACPU, AOS: string;
  AMode: TRangeMode);
var
  lDirectory, lImage, lOption, lMap: string;
  lLines: TStringList;
  lExpectedRanges: Integer;
begin
  lDirectory := CaseDirectory('');
  lOption := '-XX';
  lExpectedRanges := 3; // program body and two live unit functions
  if AMode = rmRetained then
  begin
    lOption := '-dKEEP_UNUSED_RANGE';
    Inc(lExpectedRanges);
  end
  else if AMode = rmDiscarded then
    lOption := '-dINCLUDE_UNUSED_RANGE';
  lImage := CompileFixture(AContext, ACPU, AOS, lDirectory,
    'DwarfRangesProbe.pas', lOption);
  lLines := TStringList.Create;
  try
    lLines.LoadFromFile(ChangeFileExt(lImage, '.map'));
    lMap := LowerCase(lLines.Text);
    AContext.AssertTrue(Pos('firstvalue', lMap) > 0, 'FirstValue must remain linked');
    AContext.AssertTrue(Pos('secondvalue', lMap) > 0, 'SecondValue must remain linked');
    AContext.AssertTrue((Pos('unusedvalue', lMap) > 0) = (AMode = rmRetained),
      'UnusedValue must be linked only when the source calls it');
  finally
    lLines.Free;
  end;
  VerifyRanges(AContext, lImage, lExpectedRanges);
  VerifyProcedureRange(AContext, lImage, 'FirstValue', True);
  VerifyProcedureRange(AContext, lImage, 'SecondValue', True);
  if AMode <> rmOriginal then
    VerifyProcedureRange(AContext, lImage, 'UnusedValue', AMode = rmRetained);
  RunTool(AContext, lDirectory, ExpandFileName(ParamStr(3)), ['--verify', lImage]);
end;

procedure TestI386WindowsRanges(AContext: TNXTestContext);
begin
  CheckWindowsRanges(AContext, 'i386', 'win32', rmOriginal);
end;

procedure TestX64WindowsRanges(AContext: TNXTestContext);
begin
  CheckWindowsRanges(AContext, 'x86_64', 'win64', rmOriginal);
end;

procedure TestARM64WindowsRanges(AContext: TNXTestContext);
begin
  CheckWindowsRanges(AContext, 'aarch64', 'win64', rmOriginal);
end;

procedure TestI386RetainedRanges(AContext: TNXTestContext);
begin
  CheckWindowsRanges(AContext, 'i386', 'win32', rmRetained);
end;

procedure TestX64RetainedRanges(AContext: TNXTestContext);
begin
  CheckWindowsRanges(AContext, 'x86_64', 'win64', rmRetained);
end;

procedure TestARM64RetainedRanges(AContext: TNXTestContext);
begin
  CheckWindowsRanges(AContext, 'aarch64', 'win64', rmRetained);
end;

procedure TestI386DiscardedFunctionInfo(AContext: TNXTestContext);
begin
  CheckWindowsRanges(AContext, 'i386', 'win32', rmDiscarded);
end;

procedure TestX64DiscardedFunctionInfo(AContext: TNXTestContext);
begin
  CheckWindowsRanges(AContext, 'x86_64', 'win64', rmDiscarded);
end;

procedure TestARM64DiscardedFunctionInfo(AContext: TNXTestContext);
begin
  CheckWindowsRanges(AContext, 'aarch64', 'win64', rmDiscarded);
end;

procedure TestBracedResponsePath(AContext: TNXTestContext);
var
  lImage: string;
begin
  lImage := CompileFixture(AContext, 'x86_64', 'win64', CaseDirectory('{braces}'),
    'DwarfRangesProbe.pas', '-XX');
  AContext.AssertTrue(FileExists(lImage), 'The requested executable must exist');
end;

procedure CheckResponsePaths(AContext: TNXTestContext; const ACPU, AOS: string;
  ALibrary: Boolean);
const
  cSuffixes: array[0..2] of string = ('{braces}', ' with spaces', ' {braces} and ''apostrophe');
var
  lSuffix, lDirectory, lLibraryDirectory, lTriplet, lSource, lImage, lOutput: string;
begin
  if ACPU = 'i386' then lTriplet := 'i686' else lTriplet := ACPU;
  lTriplet := lTriplet + '-pc-windows-msvc';
  for lSuffix in cSuffixes do
  begin
    lDirectory := CaseDirectory(lSuffix);
    lLibraryDirectory := lDirectory + '/archive directory/';
    ForceDirectories(lLibraryDirectory);
    RunTool(AContext, lDirectory, 'clang', ['-target', lTriplet, '-c',
      FixturePath('WindowsPathProvider.c'), '-o', lDirectory + '/provider.o']);
    RunTool(AContext, lDirectory, 'llvm-ar', ['rcs', lLibraryDirectory + 'libnxpath.a',
      lDirectory + '/provider.o']);
    RunTool(AContext, lDirectory, 'clang', ['-target', lTriplet, '-c', '-DSEARCH_LIBRARY',
      FixturePath('WindowsPathProvider.c'), '-o', lDirectory + '/search.o']);
    RunTool(AContext, lDirectory, 'llvm-ar', ['rcs', lLibraryDirectory + 'libnxsearch.a',
      lDirectory + '/search.o']);
    if ALibrary then lSource := 'WindowsPathLibrary.lpr'
    else lSource := 'WindowsPathProbe.pas';
    { One archive is resolved by the compiler; the other requires LLD's /libpath. }
    lImage := CompileFixture(AContext, ACPU, AOS, lDirectory, lSource,
      '-klibnxsearch.a', lLibraryDirectory);
    if ALibrary then lImage := ChangeFileExt(lImage, '.dll');
    AContext.AssertTrue(FileExists(lImage), 'The requested image must exist: ' + lImage);
    AContext.AssertTrue(FileExists(ChangeFileExt(lImage, '.map')),
      'The map must be written at the requested path');
    RunTool(AContext, lDirectory, ExpandFileName(ParamStr(3)), ['--verify', lImage]);
    if ALibrary then
    begin
      lOutput := RunTool(AContext, lDirectory, 'llvm-readobj', ['--coff-exports', lImage]);
      AContext.AssertTrue(Pos('Name: nx_export_value', lOutput) > 0,
        'The definition file must preserve the requested DLL export: ' + lOutput);
    end;
  end;
end;

procedure TestI386ResponsePaths(AContext: TNXTestContext);
begin
  CheckResponsePaths(AContext, 'i386', 'win32', False);
end;

procedure TestX64ResponsePaths(AContext: TNXTestContext);
begin
  CheckResponsePaths(AContext, 'x86_64', 'win64', False);
end;

procedure TestARM64ResponsePaths(AContext: TNXTestContext);
begin
  CheckResponsePaths(AContext, 'aarch64', 'win64', False);
end;

procedure TestI386LibraryPaths(AContext: TNXTestContext);
begin
  CheckResponsePaths(AContext, 'i386', 'win32', True);
end;

procedure TestX64LibraryPaths(AContext: TNXTestContext);
begin
  CheckResponsePaths(AContext, 'x86_64', 'win64', True);
end;

procedure TestARM64LibraryPaths(AContext: TNXTestContext);
begin
  CheckResponsePaths(AContext, 'aarch64', 'win64', True);
end;

var
  lRegistry: TNXTestRegistry;
begin
  if ParamCount <> 4 then
  begin
    WriteLn(StdErr, 'Usage: DwarfArtifactTests <source-root> <nxpc-driver-or-bootstrap-root> <llvm-dwarfdump> <external-output>');
    Halt(2);
  end;
  lRegistry := TNXTestRegistry.Create;
  try
    with lRegistry.AddSuite('DwarfArtifacts') do
    begin
      AddTest('I386WindowsRanges', @TestI386WindowsRanges);
      AddTest('X64WindowsRanges', @TestX64WindowsRanges);
      AddTest('ARM64WindowsRanges', @TestARM64WindowsRanges);
      AddTest('I386RetainedRanges', @TestI386RetainedRanges);
      AddTest('X64RetainedRanges', @TestX64RetainedRanges);
      AddTest('ARM64RetainedRanges', @TestARM64RetainedRanges);
    end;
    with lRegistry.AddSuite('DiscardedFunctionInfo') do
    begin
      AddTest('I386', @TestI386DiscardedFunctionInfo);
      AddTest('X64', @TestX64DiscardedFunctionInfo);
      AddTest('ARM64', @TestARM64DiscardedFunctionInfo);
    end;
    with lRegistry.AddSuite('WindowsLink') do
    begin
      AddTest('BracedResponsePath', @TestBracedResponsePath);
      AddTest('I386ResponsePaths', @TestI386ResponsePaths);
      AddTest('X64ResponsePaths', @TestX64ResponsePaths);
      AddTest('ARM64ResponsePaths', @TestARM64ResponsePaths);
      AddTest('I386LibraryPaths', @TestI386LibraryPaths);
      AddTest('X64LibraryPaths', @TestX64LibraryPaths);
      AddTest('ARM64LibraryPaths', @TestARM64LibraryPaths);
    end;
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
