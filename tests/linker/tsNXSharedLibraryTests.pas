// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit tsNXSharedLibraryTests;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterSharedLibraryTests(ARegistry: TNXTestRegistry;
  const ACompiler, ARTL, AOutput, AClang, AReadObj: string);
implementation
uses Classes, SysUtils, Process, obNXTestContext, obNXTestSuite;
var lCompiler, lRTL, lOutputRoot, lClang, lReadObj: string;

procedure SaveText(const APath, AText: string);
var lText: TStringList;
begin
  lText := TStringList.Create;
  try
    lText.Text := AText;
    lText.SaveToFile(APath);
  finally
    lText.Free;
  end;
end;

function CaseDirectory(const AName: string): string;
begin
  Result := IncludeTrailingPathDelimiter(lOutputRoot) + AName;
  ForceDirectories(Result);
end;

procedure BuildLibrary(AContext: TNXTestContext;
  const ADirectory, AFileName, ASONAME: string; AValue: Integer);
var lSource, lOutput: string;
begin
  lSource := ADirectory + '/provider.c';
  SaveText(lSource, 'int nx_soname_value(void) { return ' + IntToStr(AValue) + '; }');
  AContext.AssertTrue(RunCommand(lClang, ['-shared', '-fPIC', '-nostdlib',
    '-fuse-ld=lld', '-Wl,-soname,' + ASONAME, '-o', ADirectory + '/' + AFileName,
    lSource], lOutput), lOutput);
end;

function CompileFile(const ADirectory, AFileName: string;
  const AExtraOption: string = ''): Boolean;
var lOutput: string; lArguments: array of string;
begin
  lArguments := ['-n', '-Aas-clang', '-XLL', '-Fu' + lRTL,
    '-Fu' + ADirectory, '-FU' + ADirectory, '-FE' + ADirectory,
    '-Fl' + ADirectory, '-k-rpath=$ORIGIN'];
  if AExtraOption <> '' then
    begin
      SetLength(lArguments, Length(lArguments) + 1);
      lArguments[High(lArguments)] := AExtraOption;
    end;
  SetLength(lArguments, Length(lArguments) + 1);
  lArguments[High(lArguments)] := ADirectory + '/' + AFileName;
  Result := RunCommand(lCompiler, lArguments, lOutput, [poStderrToOutPut]);
  SaveText(ADirectory + '/' + AFileName + '.log', lOutput);
end;

procedure WriteProbe(const ADirectory, ADeclarations: string);
begin
  SaveText(ADirectory + '/probe.pas', 'program probe;' + LineEnding + '{$linklib c}' + LineEnding +
    '{$mode objfpc}' + LineEnding + ADeclarations + LineEnding +
    'begin if NXValue <> 42 then Halt(7); WriteLn(''linked''); end.');
end;

procedure CheckProbe(AContext: TNXTestContext; const ADirectory, ASONAME: string);
var lOutput: string;
begin
  AContext.AssertTrue(CompileFile(ADirectory, 'probe.pas'),
    'Compiler failed; see ' + ADirectory + '/probe.pas.log');
  AContext.AssertTrue(RunCommand(ADirectory + '/probe', [], lOutput, [poStderrToOutPut]), lOutput);
  AContext.AssertEquals('linked', Trim(lOutput));
  AContext.AssertTrue(RunCommand(lReadObj, ['--needed-libs', ADirectory + '/probe'],
    lOutput), lOutput);
  SaveText(ADirectory + '/needed-libs.txt', lOutput);
  AContext.AssertTrue(Pos(ASONAME, lOutput) > 0, 'Missing DT_NEEDED ' + ASONAME);
end;

procedure TestExternalSONAME(AContext: TNXTestContext);
var lDirectory: string;
begin
  lDirectory := CaseDirectory('external');
  BuildLibrary(AContext, lDirectory, 'libnxexact.so.42', 'libnxexact.so.42', 42);
  WriteProbe(lDirectory,
    'function NXValue: LongInt; cdecl; external ''libnxexact.so.42'' name ''nx_soname_value'';');
  CheckProbe(AContext, lDirectory, 'libnxexact.so.42');
end;

procedure TestLinkLibSONAME(AContext: TNXTestContext);
var lDirectory: string;
begin
  lDirectory := CaseDirectory('linklib');
  BuildLibrary(AContext, lDirectory, 'libnxexact.so.42', 'libnxexact.so.42', 42);
  WriteProbe(lDirectory, '{$linklib libnxexact.so.42}' + LineEnding +
    'function NXValue: LongInt; cdecl; external name ''nx_soname_value'';');
  CheckProbe(AContext, lDirectory, 'libnxexact.so.42');
end;

procedure TestCachedUnitSONAME(AContext: TNXTestContext);
var lDirectory: string;
begin
  lDirectory := CaseDirectory('cached-unit');
  BuildLibrary(AContext, lDirectory, 'libnxexact.so.42', 'libnxexact.so.42', 42);
  SaveText(lDirectory + '/nximport.pas', 'unit nximport; interface' + LineEnding +
    'function NXValue: LongInt; cdecl; external ''libnxexact.so.42'' name ''nx_soname_value'';' +
    LineEnding + 'implementation end.');
  AContext.AssertTrue(CompileFile(lDirectory, 'nximport.pas'));
  AContext.AssertTrue(RenameFile(lDirectory + '/nximport.pas', lDirectory + '/nximport.hidden'));
  WriteProbe(lDirectory, 'uses nximport;');
  CheckProbe(AContext, lDirectory, 'libnxexact.so.42');
end;

procedure TestExplicitLookup(AContext: TNXTestContext);
var lDirectory: string;
begin
  lDirectory := CaseDirectory('explicit-lookup');
  BuildLibrary(AContext, lDirectory, 'libnxexact.so.42', 'libnxexact.so.42', 42);
  WriteProbe(lDirectory, '{$linklib '':libnxexact.so.42''}' + LineEnding +
    'function NXValue: LongInt; cdecl; external name ''nx_soname_value'';');
  CheckProbe(AContext, lDirectory, 'libnxexact.so.42');
end;

procedure TestBareLibraryName(AContext: TNXTestContext);
var lDirectory: string;
begin
  lDirectory := CaseDirectory('bare-name');
  BuildLibrary(AContext, lDirectory, 'libnxplain.so', 'libnxplain.so', 42);
  WriteProbe(lDirectory,
    'function NXValue: LongInt; cdecl; external ''nxplain'' name ''nx_soname_value'';');
  CheckProbe(AContext, lDirectory, 'libnxplain.so');
end;

procedure TestBareArchiveFallback(AContext: TNXTestContext);
var lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory('bare-archive');
  SaveText(lDirectory + '/provider.c', 'int nx_soname_value(void) { return 42; }');
  AContext.AssertTrue(RunCommand(lClang, ['-c', '-o', lDirectory + '/provider.o',
    lDirectory + '/provider.c'], lOutput, [poStderrToOutPut]), lOutput);
  AContext.AssertTrue(RunCommand('llvm-ar', ['rcs', lDirectory + '/libnxarchive.a',
    lDirectory + '/provider.o'], lOutput, [poStderrToOutPut]), lOutput);
  WriteProbe(lDirectory,
    'function NXValue: LongInt; cdecl; external ''nxarchive'' name ''nx_soname_value'';');
  CheckProbe(AContext, lDirectory, 'libc.so.6');
end;

procedure TestExplicitFilename(AContext: TNXTestContext);
var lDirectory: string;
begin
  lDirectory := CaseDirectory('explicit-filename');
  BuildLibrary(AContext, lDirectory, 'oddshared.so', 'oddshared.so', 42);
  WriteProbe(lDirectory, '{$linklib '':oddshared.so''}' + LineEnding +
    'function NXValue: LongInt; cdecl; external name ''nx_soname_value'';');
  CheckProbe(AContext, lDirectory, 'oddshared.so');
end;

procedure TestExactPath(AContext: TNXTestContext);
var lDirectory: string;
begin
  lDirectory := CaseDirectory('path with spaces');
  BuildLibrary(AContext, lDirectory, 'libnxexact.so.42', 'libnxexact.so.42', 42);
  WriteProbe(lDirectory, '{$linklib ''' + lDirectory + '/libnxexact.so.42''}' + LineEnding +
    'function NXValue: LongInt; cdecl; external name ''nx_soname_value'';');
  CheckProbe(AContext, lDirectory, 'libnxexact.so.42');
end;

procedure TestMissingABIDoesNotFallback(AContext: TNXTestContext);
var lDirectory: string; lLog: TStringList;
begin
  lDirectory := CaseDirectory('missing-abi');
  BuildLibrary(AContext, lDirectory, 'libnxmissing.so', 'libnxmissing.so.43', 999);
  WriteProbe(lDirectory,
    'function NXValue: LongInt; cdecl; external ''libnxmissing.so.42'' name ''nx_soname_value'';');
  AContext.AssertFalse(CompileFile(lDirectory, 'probe.pas'),
    'A missing ABI must not link to a different library through an unversioned name');
  lLog := TStringList.Create;
  try
    lLog.LoadFromFile(lDirectory + '/probe.pas.log');
    AContext.AssertTrue(Pos('unable to find library -l:libnxmissing.so.42', lLog.Text) > 0,
      'Expected the missing ABI diagnostic: ' + lLog.Text);
  finally
    lLog.Free;
  end;
end;

procedure TestNXPLFilename(AContext: TNXTestContext);
var lDirectory: string;
begin
  lDirectory := CaseDirectory('nxpl-filename');
  BuildLibrary(AContext, lDirectory, 'ExactPackage.nxpl', 'ExactPackage.nxpl', 42);
  WriteProbe(lDirectory, '{$linklib ExactPackage.nxpl}' + LineEnding +
    'function NXValue: LongInt; cdecl; external name ''nx_soname_value'';');
  CheckProbe(AContext, lDirectory, 'ExactPackage.nxpl');
end;

procedure TestPICDefault(AContext: TNXTestContext);
var lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory('pic-default');
  SaveText(lDirectory + '/probe.pas', 'program probe;' + LineEnding +
    '{$ifndef FPC_PIC}{$fatal Linux x86-64 must default to PIC}{$endif}' + LineEnding +
    'begin WriteLn(''pic-default''); end.');
  AContext.AssertTrue(CompileFile(lDirectory, 'probe.pas'),
    'Compiler failed; see ' + lDirectory + '/probe.pas.log');
  AContext.AssertTrue(RunCommand(lDirectory + '/probe', [], lOutput, [poStderrToOutPut]), lOutput);
  AContext.AssertEquals('pic-default', Trim(lOutput));
end;

procedure TestPICOptOut(AContext: TNXTestContext);
var lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory('pic-opt-out');
  SaveText(lDirectory + '/probe.pas', 'program probe;' + LineEnding +
    '{$ifdef FPC_PIC}{$fatal Explicit PIC opt-out was ignored}{$endif}' + LineEnding +
    'var Value: LongInt = 42;' + LineEnding +
    'begin WriteLn(Value); end.');
  AContext.AssertTrue(CompileFile(lDirectory, 'probe.pas', '-Cg-'),
    'Compiler failed; see ' + lDirectory + '/probe.pas.log');
  AContext.AssertTrue(RunCommand(lDirectory + '/probe', [], lOutput, [poStderrToOutPut]), lOutput);
  AContext.AssertEquals('42', Trim(lOutput));
end;

procedure TestDefaultPICSharedLibrary(AContext: TNXTestContext);
var lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory('pic-shared-library');
  SaveText(lDirectory + '/nxpicstate.pas',
    'unit nxpicstate; {$mode objfpc}{$H+}' + LineEnding +
    'interface function NextValue: LongInt; cdecl;' + LineEnding +
    'implementation uses SysUtils; var Value: LongInt = 40;' + LineEnding +
    'function NextValue: LongInt; cdecl;' + LineEnding +
    'begin Inc(Value); Result := StrToInt(IntToStr(Value)); end; end.');
  AContext.AssertTrue(CompileFile(lDirectory, 'nxpicstate.pas'),
    'Unit compilation failed; see ' + lDirectory + '/nxpicstate.pas.log');
  AContext.AssertTrue(RenameFile(lDirectory + '/nxpicstate.pas',
    lDirectory + '/nxpicstate.hidden'));
  SaveText(lDirectory + '/nxpic.pas', 'library nxpic;' + LineEnding +
    'uses nxpicstate; exports NextValue name ''nx_pic_value''; begin end.');
  AContext.AssertTrue(CompileFile(lDirectory, 'nxpic.pas', '-k-ztext'),
    'Shared library failed; see ' + lDirectory + '/nxpic.pas.log');
  AContext.AssertTrue(RunCommand(lReadObj, ['--dynamic-table',
    lDirectory + '/libnxpic.so'], lOutput, [poStderrToOutPut]), lOutput);
  SaveText(lDirectory + '/dynamic-table.txt', lOutput);
  AContext.AssertTrue(Pos('TEXTREL', lOutput) = 0, lOutput);
  SaveText(lDirectory + '/probe.pas', 'program probe; {$mode objfpc}' + LineEnding +
    'uses DynLibs;' + LineEnding +
    'type TNextValue = function: LongInt; cdecl;' + LineEnding +
    'var Handle: TLibHandle; NextValue: TNextValue;' + LineEnding +
    'begin Handle := LoadLibrary(''libnxpic.so''); if Handle = NilHandle then Halt(1);' + LineEnding +
    'Pointer(NextValue) := GetProcedureAddress(Handle, ''nx_pic_value'');' + LineEnding +
    'if not Assigned(NextValue) then Halt(2);' + LineEnding +
    'if NextValue() <> 41 then Halt(3); if NextValue() <> 42 then Halt(4);' + LineEnding +
    'if not UnloadLibrary(Handle) then Halt(5); WriteLn(''pic-shared''); end.');
  AContext.AssertTrue(CompileFile(lDirectory, 'probe.pas'),
    'Consumer compilation failed; see ' + lDirectory + '/probe.pas.log');
  AContext.AssertTrue(RunCommand(lDirectory + '/probe', [], lOutput, [poStderrToOutPut]), lOutput);
  AContext.AssertEquals('pic-shared', Trim(lOutput));
end;

procedure RegisterSharedLibraryTests(ARegistry: TNXTestRegistry;
  const ACompiler, ARTL, AOutput, AClang, AReadObj: string);
var lSuite: TNXTestSuite;
begin
  lCompiler := ExpandFileName(ACompiler);
  lRTL := ExpandFileName(ARTL);
  lOutputRoot := ExpandFileName(AOutput);
  lClang := ExpandFileName(AClang);
  lReadObj := ExpandFileName(AReadObj);
  lSuite := ARegistry.AddSuite('LinuxSharedLibraries');
  lSuite.AddTest('ExternalSONAME', @TestExternalSONAME, 'linker');
  lSuite.AddTest('LinkLibSONAME', @TestLinkLibSONAME, 'linker');
  lSuite.AddTest('CachedUnitSONAME', @TestCachedUnitSONAME, 'linker');
  lSuite.AddTest('ExplicitLookup', @TestExplicitLookup, 'linker');
  lSuite.AddTest('BareLibraryName', @TestBareLibraryName, 'linker');
  lSuite.AddTest('BareArchiveFallback', @TestBareArchiveFallback, 'linker');
  lSuite.AddTest('ExplicitFilename', @TestExplicitFilename, 'linker');
  lSuite.AddTest('ExactPath', @TestExactPath, 'linker');
  lSuite.AddTest('MissingABIDoesNotFallback', @TestMissingABIDoesNotFallback, 'linker');
  lSuite.AddTest('NXPLFilename', @TestNXPLFilename, 'linker');
  lSuite.AddTest('PICDefault', @TestPICDefault, 'linker');
  lSuite.AddTest('PICOptOut', @TestPICOptOut, 'linker');
  lSuite.AddTest('DefaultPICSharedLibrary', @TestDefaultPICSharedLibrary, 'linker');
end;
end.
