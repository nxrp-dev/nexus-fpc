// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program ImplicitRuntimeTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, Process, obNXTestRegistry, obNXTestSuite,
  obNXTestContext, utNXTestConsole;

function CaseDirectory: string;
var
  lId: TGUID;
begin
  CreateGUID(lId);
  Result := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(4))) +
    GUIDToString(lId);
  ForceDirectories(Result);
end;

function FixturePath(const AName: string): string;
begin
  Result := ExpandFileName(ParamStr(1)) + '/tests/compiler-regressions/' + AName;
end;

function RunProcess(AContext: TNXTestContext; AProcess: TProcess;
  AExpectedExit: Integer; const ALog: string): string;
var
  lOutputStream: TStringStream;
  lBuffer: array[0..8191] of Byte;
  lCount: LongInt;
begin
  AProcess.Options := [poUsePipes, poStderrToOutput];
  AProcess.Execute;
  lOutputStream := TStringStream.Create('');
  try
    repeat
      lCount := AProcess.Output.Read(lBuffer, SizeOf(lBuffer));
      AContext.AssertTrue(lCount >= 0, 'Could not read process output');
      if lCount > 0 then lOutputStream.WriteBuffer(lBuffer, lCount);
    until lCount = 0;
    Result := lOutputStream.DataString;
    lOutputStream.SaveToFile(ALog);
  finally
    lOutputStream.Free;
  end;
  AProcess.WaitOnExit;
  AContext.AssertEquals(AExpectedExit, AProcess.ExitStatus,
    AProcess.Executable + ': ' + Result);
end;

function CompileFixture(AContext: TNXTestContext; const ADirectory,
  ASource: string; ASourceFirst: Boolean; AHeapTrace: Boolean = False;
  APIE: Boolean = False): string;
var
  lProcess: TProcess;
  lRoot, lRTL: string;
begin
  lRoot := ExpandFileName(ParamStr(1));
  lRTL := ExpandFileName(ParamStr(3));
  lProcess := TProcess.Create(nil);
  try
    lProcess.Executable := ExpandFileName(ParamStr(2));
    lProcess.CurrentDirectory := ADirectory;
    lProcess.Parameters.Add('-n');
    lProcess.Parameters.Add('-gl');
    lProcess.Parameters.Add('-vi');
    if AHeapTrace then lProcess.Parameters.Add('-gh');
    lProcess.Parameters.Add('-Aas-clang');
    if APIE then
    begin
      lProcess.Parameters.Add('-k-pie');
      lProcess.Parameters.Add('-k--dynamic-linker=/lib64/ld-linux-x86-64.so.2');
    end;
    if not ASourceFirst then lProcess.Parameters.Add('-Fu' + lRTL);
    lProcess.Parameters.Add('-Fu' + lRoot + '/rtl/inc');
    if ASourceFirst then lProcess.Parameters.Add('-Fu' + lRTL);
    lProcess.Parameters.Add('-Fi' + lRoot + '/rtl/inc');
    lProcess.Parameters.Add('-Fi' + lRoot + '/rtl/' + {$I %FPCTARGETCPU%});
    lProcess.Parameters.Add('-Fi' + lRoot + '/rtl/unix');
    lProcess.Parameters.Add('-Fi' + lRoot + '/rtl/linux');
    lProcess.Parameters.Add('-Fi' + lRoot + '/rtl/linux/' + {$I %FPCTARGETCPU%});
    lProcess.Parameters.Add('-FU' + ADirectory);
    lProcess.Parameters.Add('-FE' + ADirectory);
    lProcess.Parameters.Add(FixturePath(ASource));
    Result := RunProcess(AContext, lProcess, 0,
      ADirectory + '/' + ChangeFileExt(ASource, '-compile.log'));
  finally
    lProcess.Free;
  end;
end;

function RunFixture(AContext: TNXTestContext; const ADirectory,
  ASource: string; AExpectedExit: Integer): string;
var
  lProcess: TProcess;
begin
  lProcess := TProcess.Create(nil);
  try
    lProcess.Executable := ADirectory + '/' + ChangeFileExt(ASource, '');
    lProcess.CurrentDirectory := ADirectory;
    Result := RunProcess(AContext, lProcess, AExpectedExit,
      ADirectory + '/' + ChangeFileExt(ASource, '-run.log'));
  finally
    lProcess.Free;
  end;
end;

function ReadArtifact(const APath: string): RawByteString;
var
  lStream: TFileStream;
begin
  lStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, lStream.Size);
    if Length(Result) > 0 then lStream.ReadBuffer(Result[1], Length(Result));
  finally
    lStream.Free;
  end;
end;

procedure VerifySourceUnit(AContext: TNXTestContext; const ADirectory: string);
begin
  AContext.AssertTrue(FileExists(ADirectory + '/lnfodwrf.nxu'),
    'The original line information source must be compiled.');
  AContext.AssertTrue(FileExists(ADirectory + '/lnfodwrf.o'),
    'The line information object must be generated.');
end;

procedure VerifyBacktrace(AContext: TNXTestContext; const ADirectory: string);
var
  lOutput: string;
  lSource: TStringList;
  lIndex, lExpectedLine: Integer;
begin
  lSource := TStringList.Create;
  try
    lSource.LoadFromFile(FixturePath('implicit_lineinfo_backtrace.pas'));
    lExpectedLine := 0;
    for lIndex := 0 to lSource.Count - 1 do
      if Trim(lSource[lIndex]) = 'RunError(216);' then lExpectedLine := lIndex + 1;
    AContext.AssertTrue(lExpectedLine > 0, 'The backtrace fixture must contain its failure line');
  finally
    lSource.Free;
  end;
  lOutput := LowerCase(RunFixture(AContext, ADirectory, 'implicit_lineinfo_backtrace.pas', 216));
  AContext.AssertTrue(Pos('raisewithbacktrace', lOutput) > 0,
    'The runtime backtrace must name the failing procedure: ' + lOutput);
  AContext.AssertTrue(Pos('line ' + IntToStr(lExpectedLine) + ' of ', lOutput) > 0,
    'The runtime backtrace must identify the failure line: ' + lOutput);
  AContext.AssertTrue(Pos('implicit_lineinfo_backtrace.pas', lOutput) > 0,
    'The runtime backtrace must name the source file: ' + lOutput);
end;

procedure TestLineInfoFromSource(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  CompileFixture(AContext, lDirectory, 'implicit_lineinfo_source.pas', True);
  VerifySourceUnit(AContext, lDirectory);
  lOutput := RunFixture(AContext, lDirectory, 'implicit_lineinfo_source.pas', 0);
  AContext.AssertTrue(Pos('PASS implicit line information source compilation', lOutput) > 0,
    'The original no-uses fixture must execute successfully: ' + lOutput);
end;

procedure TestLineInfoBacktraceFromSource(AContext: TNXTestContext);
var
  lDirectory: string;
begin
  lDirectory := CaseDirectory;
  CompileFixture(AContext, lDirectory, 'implicit_lineinfo_backtrace.pas', True);
  VerifySourceUnit(AContext, lDirectory);
  VerifyBacktrace(AContext, lDirectory);
end;

procedure TestLineInfoCached(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
  lUnit, lObject: RawByteString;
begin
  lDirectory := CaseDirectory;
  CompileFixture(AContext, lDirectory, 'implicit_lineinfo_source.pas', True);
  VerifySourceUnit(AContext, lDirectory);
  lUnit := ReadArtifact(lDirectory + '/lnfodwrf.nxu');
  lObject := ReadArtifact(lDirectory + '/lnfodwrf.o');
  lOutput := CompileFixture(AContext, lDirectory, 'implicit_lineinfo_backtrace.pas', True);
  AContext.AssertTrue(Pos('compiling ' + LowerCase(ExpandFileName(ParamStr(1))) +
    '/rtl/inc/lnfodwrf.pas', LowerCase(lOutput)) = 0,
    'The second build must load the cached line information unit: ' + lOutput);
  AContext.AssertTrue(lUnit = ReadArtifact(lDirectory + '/lnfodwrf.nxu'),
    'Cached line information metadata must remain unchanged');
  AContext.AssertTrue(lObject = ReadArtifact(lDirectory + '/lnfodwrf.o'),
    'Cached line information code must remain unchanged');
  VerifyBacktrace(AContext, lDirectory);
end;

procedure TestLineInfoInstalled(AContext: TNXTestContext);
var
  lDirectory: string;
begin
  lDirectory := CaseDirectory;
  AContext.AssertTrue(FileExists(ExpandFileName(ParamStr(3)) + '/lnfodwrf.nxu'),
    'The installed-unit control requires matching compiled line information');
  CompileFixture(AContext, lDirectory, 'implicit_lineinfo_backtrace.pas', False);
  AContext.AssertFalse(FileExists(lDirectory + '/lnfodwrf.nxu'),
    'The installed-unit control must not rebuild line information');
  VerifyBacktrace(AContext, lDirectory);
end;

procedure TestLineInfoWithHeapTrace(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  CompileFixture(AContext, lDirectory, 'implicit_lineinfo_source.pas', True, True);
  VerifySourceUnit(AContext, lDirectory);
  AContext.AssertTrue(FileExists(lDirectory + '/heaptrc.nxu'),
    'Both implicit runtime units must compile from source');
  lOutput := RunFixture(AContext, lDirectory, 'implicit_lineinfo_source.pas', 0);
  AContext.AssertTrue(Pos('0 unfreed memory blocks', lOutput) > 0,
    'Combined heap tracing and line information must finish cleanly: ' + lOutput);
end;

procedure CheckElfLayout(AContext: TNXTestContext; const ADirectory: string;
  APIE, ARemovePHDR: Boolean);
var
  lFile: TFileStream;
  lMagic, lKind: LongWord;
  lType, lEntrySize, lCount: Word;
  lOffset: QWord;
  lIndex, lRemoved: Integer;
begin
  lFile := TFileStream.Create(ADirectory + '/implicit_lineinfo_backtrace', fmOpenReadWrite);
  try
    lFile.ReadBuffer(lMagic, SizeOf(lMagic));
    AContext.AssertTrue(lMagic = $464C457F, 'Expected an ELF executable');
    lFile.Position := 16;
    lFile.ReadBuffer(lType, SizeOf(lType));
    if APIE then
      AContext.AssertEquals(3, lType, 'The control must be a PIE executable')
    else
      AContext.AssertEquals(2, lType, 'The regression must be a fixed-address executable');
    lFile.Position := 32;
    lFile.ReadBuffer(lOffset, SizeOf(lOffset));
    lFile.Position := 54;
    lFile.ReadBuffer(lEntrySize, SizeOf(lEntrySize));
    lFile.ReadBuffer(lCount, SizeOf(lCount));
    AContext.AssertEquals(56, lEntrySize, 'Expected ELF64 program headers');
    lRemoved := 0;
    for lIndex := 0 to lCount - 1 do
    begin
      lFile.Position := lOffset + QWord(lIndex) * lEntrySize;
      lFile.ReadBuffer(lKind, SizeOf(lKind));
      if lKind = 6 then
      begin
        Inc(lRemoved);
        if ARemovePHDR then
        begin
          { PT_PHDR is optional. Replace only that descriptor with PT_NULL;
            the executable code, load segments and DWARF stay unchanged. }
          lKind := 0;
          lFile.Position := lOffset + QWord(lIndex) * lEntrySize;
          lFile.WriteBuffer(lKind, SizeOf(lKind));
        end;
      end;
    end;
    AContext.AssertEquals(1, lRemoved, 'The LLVM fixture must initially contain PT_PHDR');
  finally
    lFile.Free;
  end;
end;

procedure TestElfBacktrace(AContext: TNXTestContext; APIE, ARemovePHDR: Boolean);
var
  lDirectory: string;
begin
  lDirectory := CaseDirectory;
  CompileFixture(AContext, lDirectory, 'implicit_lineinfo_backtrace.pas', True, False, APIE);
  CheckElfLayout(AContext, lDirectory, APIE, ARemovePHDR);
  VerifyBacktrace(AContext, lDirectory);
end;

procedure TestLineInfoPIE(AContext: TNXTestContext);
begin
  TestElfBacktrace(AContext, True, False);
end;

procedure TestLineInfoWithoutPHDR(AContext: TNXTestContext);
begin
  TestElfBacktrace(AContext, False, True);
end;

procedure CompilePlainFixture(AContext: TNXTestContext; const ADirectory,
  ASource: string; AAutoload: Boolean);
var
  lProcess: TProcess;
begin
  lProcess := TProcess.Create(nil);
  try
    lProcess.Executable := ExpandFileName(ParamStr(2));
    lProcess.CurrentDirectory := ADirectory;
    lProcess.Parameters.Add('-n');
    lProcess.Parameters.Add('-Fu' + ExpandFileName(ParamStr(3)));
    lProcess.Parameters.Add('-Fu' + ADirectory);
    lProcess.Parameters.Add('-Fu' + ExtractFilePath(FixturePath(ASource)));
    lProcess.Parameters.Add('-FU' + ADirectory);
    lProcess.Parameters.Add('-FE' + ADirectory);
    if AAutoload then lProcess.Parameters.Add('-Faimplicit_plain_unit');
    lProcess.Parameters.Add(FixturePath(ASource));
    RunProcess(AContext, lProcess, 0,
      ADirectory + '/' + ChangeFileExt(ASource, '-compile.log'));
  finally
    lProcess.Free;
  end;
end;

procedure VerifyPlainFixture(AContext: TNXTestContext; const ADirectory,
  ASource: string);
var
  lOutput: string;
begin
  lOutput := RunFixture(AContext, ADirectory, ASource, 0);
  AContext.AssertEquals('PASS implicit dependency initialized' + LineEnding +
    'PASS implicit program' + LineEnding, lOutput,
    'The dependency must be initialized before the program');
end;

procedure TestExplicitPlainSource(AContext: TNXTestContext);
var
  lDirectory: string;
begin
  lDirectory := CaseDirectory;
  CompilePlainFixture(AContext, lDirectory, 'implicit_plain_explicit.pas', False);
  VerifyPlainFixture(AContext, lDirectory, 'implicit_plain_explicit.pas');
end;

procedure TestAutoloadPlainSource(AContext: TNXTestContext);
var
  lDirectory: string;
begin
  lDirectory := CaseDirectory;
  CompilePlainFixture(AContext, lDirectory, 'implicit_plain_program.pas', True);
  VerifyPlainFixture(AContext, lDirectory, 'implicit_plain_program.pas');
end;

procedure TestAutoloadPlainCached(AContext: TNXTestContext);
var
  lDirectory: string;
begin
  lDirectory := CaseDirectory;
  CompilePlainFixture(AContext, lDirectory, 'implicit_plain_unit.pas', False);
  CompilePlainFixture(AContext, lDirectory, 'implicit_plain_program.pas', True);
  VerifyPlainFixture(AContext, lDirectory, 'implicit_plain_program.pas');
end;

function CompileDependency(AContext: TNXTestContext; const ADirectory,
  ASource: string; const AOptions: array of string; AExpectedExit: Integer = 0): string;
var
  lProcess: TProcess;
  lRoot, lPath: string;
  lIndex: Integer;
begin
  lRoot := ExpandFileName(ParamStr(1));
  lProcess := TProcess.Create(nil);
  try
    lProcess.Executable := ExpandFileName(ParamStr(2));
    lProcess.CurrentDirectory := ADirectory;
    lProcess.Parameters.Add('-n');
    lProcess.Parameters.Add('-vi');
    for lIndex := Low(AOptions) to High(AOptions) do
      lProcess.Parameters.Add(AOptions[lIndex]);
    lProcess.Parameters.Add('-Fu' + ADirectory);
    lProcess.Parameters.Add('-Fu' + ExpandFileName(ParamStr(3)));
    lProcess.Parameters.Add('-Fu' + FixturePath('implicit_dependency_flow'));
    lProcess.Parameters.Add('-Fu' + ExtractFilePath(FixturePath(ASource)));
    for lPath in ['inc', 'x86_64', 'unix', 'linux', 'linux/x86_64', 'objpas'] do
      lProcess.Parameters.Add('-Fi' + lRoot + '/rtl/' + lPath);
    lProcess.Parameters.Add('-FU' + ADirectory);
    lProcess.Parameters.Add('-FE' + ADirectory);
    lProcess.Parameters.Add(FixturePath(ASource));
    Result := RunProcess(AContext, lProcess, AExpectedExit,
      ADirectory + '/' + ChangeFileExt(ExtractFileName(ASource), '-compile.log'));
  finally
    lProcess.Free;
  end;
end;

procedure TestImplicitSymbols(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  CompileDependency(AContext, lDirectory, 'implicit_dependency_flow/implicit_symbols.pas',
    ['-Faimplicit_plain_unit', '-Fu' + ExtractFilePath(FixturePath('implicit_plain_unit.pas'))]);
  lOutput := RunFixture(AContext, lDirectory, 'implicit_symbols.pas', 0);
  AContext.AssertTrue(Pos('PASS implicit symbols', lOutput) > 0, lOutput);
end;

procedure TestImplicitChain(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  CompileDependency(AContext, lDirectory, 'implicit_plain_program.pas', ['-Faimplicit_chain']);
  lOutput := RunFixture(AContext, lDirectory, 'implicit_plain_program.pas', 0);
  AContext.AssertEquals('base initialized' + LineEnding + 'chain initialized' + LineEnding +
    'PASS implicit program' + LineEnding + 'chain finalized' + LineEnding, lOutput);
end;

procedure TestImplicitCycle(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  CompileDependency(AContext, lDirectory, 'implicit_plain_program.pas', ['-Faimplicit_cycle_a']);
  lOutput := RunFixture(AContext, lDirectory, 'implicit_plain_program.pas', 0);
  AContext.AssertEquals('cycle B initialized' + LineEnding + 'cycle A initialized' + LineEnding +
    'PASS implicit program' + LineEnding, lOutput);
end;

procedure TestImplicitInvalidCycle(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  lOutput := LowerCase(CompileDependency(AContext, lDirectory, 'implicit_plain_program.pas',
    ['-Faimplicit_badcycle_a'], 1));
  AContext.AssertTrue(Pos('circular unit reference', lOutput) > 0, lOutput);
  AContext.AssertFalse(Pos('internal error', lOutput) > 0, lOutput);
end;

procedure TestImplicitStaleDependency(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  CompileDependency(AContext, lDirectory,
    'implicit_dependency_flow/before/implicit_revision_base.pas', []);
  CompileDependency(AContext, lDirectory,
    'implicit_dependency_flow/implicit_revision_user.pas', []);
  CompileDependency(AContext, lDirectory,
    'implicit_dependency_flow/after/implicit_revision_base.pas', []);
  lOutput := CompileDependency(AContext, lDirectory, 'implicit_plain_program.pas',
    ['-Faimplicit_revision_user']);
  AContext.AssertTrue(Pos('implicit_revision_user.pas', lOutput) > 0,
    'The cached dependent must be recompiled after its dependency changes: ' + lOutput);
  lOutput := RunFixture(AContext, lDirectory, 'implicit_plain_program.pas', 0);
  AContext.AssertEquals('revision 2' + LineEnding + 'PASS implicit program' + LineEnding, lOutput);
end;

procedure TestImplicitLanguageSource(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  CompileDependency(AContext, lDirectory, 'implicit_dependency_flow/implicit_objpas.pas',
    ['-Fu' + ExpandFileName(ParamStr(1)) + '/rtl/objpas']);
  AContext.AssertTrue(FileExists(lDirectory + '/objpas.nxu'), 'ObjPas must compile from its original source');
  lOutput := RunFixture(AContext, lDirectory, 'implicit_objpas.pas', 0);
  AContext.AssertEquals('PASS language dependency' + LineEnding, lOutput);
end;

procedure TestISOProgramParameters(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  CompileDependency(AContext, lDirectory, '../test/tisobuf2.pas',
    ['-Sr', '-Fu' + ExpandFileName(ParamStr(1)) + '/rtl/inc']);
  AContext.AssertTrue(FileExists(lDirectory + '/iso7185.nxu'),
    'ISO7185 must compile from its original source before parsing declarations');
  lOutput := RunFixture(AContext, lDirectory, 'tisobuf2.pas', 0);
  AContext.AssertEquals('ok' + LineEnding, lOutput,
    'Program file parameters must survive waiting for the language dependency');
end;

procedure TestImplicitVariantsSource(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  CompileDependency(AContext, lDirectory, 'implicit_dependency_flow/implicit_variants.pas',
    ['-Fu' + ExpandFileName(ParamStr(1)) + '/packages/rtl-objpas/src/inc']);
  AContext.AssertTrue(FileExists(lDirectory + '/variants.nxu'), 'Variants must compile from its original source');
  lOutput := RunFixture(AContext, lDirectory, 'implicit_variants.pas', 0);
  AContext.AssertEquals('PASS late dependency' + LineEnding, lOutput);
end;

procedure TestImplicitSystemAndStartupSource(AContext: TNXTestContext);
var
  lDirectory, lRoot, lOutput: string;
begin
  lDirectory := CaseDirectory;
  lRoot := ExpandFileName(ParamStr(1));
  CompileDependency(AContext, lDirectory, 'implicit_plain_program.pas',
    ['-Sg', '-Fu' + lRoot + '/rtl/linux', '-Fu' + lRoot + '/rtl/inc',
     '-Fu' + lRoot + '/rtl/unix', '-Fu' + lRoot + '/rtl/x86_64',
     '-Fu' + lRoot + '/rtl/objpas']);
  AContext.AssertTrue(FileExists(lDirectory + '/system.nxu'), 'System must compile from its original source');
  AContext.AssertTrue(FileExists(lDirectory + '/si_prc.nxu'), 'The startup unit must compile from its original source');
  lOutput := RunFixture(AContext, lDirectory, 'implicit_plain_program.pas', 0);
  AContext.AssertEquals('PASS implicit program' + LineEnding, lOutput);
end;

procedure TestImplicitUnitVariantsSource(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  CompileDependency(AContext, lDirectory, 'implicit_dependency_flow/implicit_variant_unit.pas',
    ['-Fu' + ExpandFileName(ParamStr(1)) + '/packages/rtl-objpas/src/inc']);
  AContext.AssertTrue(FileExists(lDirectory + '/variants.nxu'),
    'The unit finalization phase must compile Variants from its original source');
  CompileDependency(AContext, lDirectory, 'implicit_plain_program.pas',
    ['-Faimplicit_variant_unit']);
  lOutput := RunFixture(AContext, lDirectory, 'implicit_plain_program.pas', 0);
  AContext.AssertEquals('PASS unit late dependency' + LineEnding +
    'PASS implicit program' + LineEnding, lOutput);
end;

procedure CompilePackageFoundation(AContext: TNXTestContext; const ADirectory: string);
begin
  CompileDependency(AContext, ADirectory, 'implicit_dependency_flow/implicit_package_base.nxpk',
    ['-Aas-clang', '-Fu' + ExpandFileName(ParamStr(1)) + '/rtl/inc']);
end;

procedure TestImplicitPackageImport(AContext: TNXTestContext);
var
  lDirectory: string;
begin
  lDirectory := CaseDirectory;
  CompilePackageFoundation(AContext, lDirectory);
  CompileDependency(AContext, lDirectory, 'implicit_dependency_flow/implicit_package_consumer.nxpk',
    ['-Aas-clang', '-Fp' + lDirectory, '-Fl' + lDirectory,
     '-Fu' + ExtractFilePath(FixturePath('implicit_plain_unit.pas'))]);
  AContext.AssertTrue(FileExists(lDirectory + '/implicit_package_consumer.nxpl'),
    'The consumer must import its implicit System dependency from the required package');
end;

procedure TestExplicitPackageOwnershipConflict(AContext: TNXTestContext);
var
  lDirectory, lOutput: string;
begin
  lDirectory := CaseDirectory;
  CompilePackageFoundation(AContext, lDirectory);
  lOutput := LowerCase(CompileDependency(AContext, lDirectory,
    'implicit_dependency_flow/implicit_package_duplicate.nxpk',
    ['-Aas-clang', '-Fp' + lDirectory, '-Fl' + lDirectory], 1));
  AContext.AssertTrue(Pos('unit fpcpackage is already contained in package implicit_package_base', lOutput) > 0,
    'Explicitly claiming a provider-owned unit must still fail: ' + lOutput);
  AContext.AssertFalse(Pos('internal error', lOutput) > 0, lOutput);
end;

var
  lRegistry: TNXTestRegistry;
begin
  if ParamCount <> 4 then
  begin
    WriteLn(StdErr, 'Usage: ImplicitRuntimeTests <source-root> <compiler> <matching-rtl> <external-output>');
    Halt(2);
  end;
  lRegistry := TNXTestRegistry.Create;
  try
    with lRegistry.AddSuite('ImplicitRuntime') do
    begin
      AddTest('LineInfoFromSource', @TestLineInfoFromSource, 'compiler-implicit-units');
      AddTest('LineInfoBacktraceFromSource', @TestLineInfoBacktraceFromSource);
      AddTest('LineInfoCached', @TestLineInfoCached);
      AddTest('LineInfoInstalled', @TestLineInfoInstalled);
      AddTest('LineInfoPIE', @TestLineInfoPIE);
      AddTest('LineInfoWithoutPHDR', @TestLineInfoWithoutPHDR);
      AddTest('LineInfoWithHeapTrace', @TestLineInfoWithHeapTrace);
      AddTest('ExplicitPlainSource', @TestExplicitPlainSource);
      AddTest('AutoloadPlainSource', @TestAutoloadPlainSource);
      AddTest('AutoloadPlainCached', @TestAutoloadPlainCached);
      AddTest('ImplicitSymbols', @TestImplicitSymbols);
      AddTest('ImplicitChain', @TestImplicitChain);
      AddTest('ImplicitCycle', @TestImplicitCycle);
      AddTest('ImplicitInvalidCycle', @TestImplicitInvalidCycle);
      AddTest('ImplicitStaleDependency', @TestImplicitStaleDependency);
      AddTest('ImplicitLanguageSource', @TestImplicitLanguageSource);
      AddTest('ISOProgramParameters', @TestISOProgramParameters);
      AddTest('ImplicitVariantsSource', @TestImplicitVariantsSource);
      AddTest('ImplicitSystemAndStartupSource', @TestImplicitSystemAndStartupSource);
      AddTest('ImplicitUnitVariantsSource', @TestImplicitUnitVariantsSource);
      AddTest('ImplicitPackageImport', @TestImplicitPackageImport);
      AddTest('ExplicitPackageOwnershipConflict', @TestExplicitPackageOwnershipConflict);
    end;
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
