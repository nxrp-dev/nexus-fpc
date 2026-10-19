// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program NXScannerBuildTests;

{$mode objfpc}{$H+}

uses
  SysUtils, obNXTestRegistry, obNXTestContext, utNXTestConsole;

procedure BuildDebugCompiler(AContext: TNXTestContext; ACheckPointers: Boolean);
var
  lCompiler, lRTL, lSource, lOutput: RawByteString;
  lArguments: array of RawByteString;
  lExitCode: Integer;
begin
  lCompiler := GetEnvironmentVariable('NX_SCANNER_TEST_COMPILER');
  lRTL := GetEnvironmentVariable('NX_SCANNER_TEST_RTL');
  lSource := GetEnvironmentVariable('NX_SCANNER_TEST_SOURCE');
  lOutput := GetEnvironmentVariable('NX_SCANNER_TEST_OUTPUT');
  AContext.AssertTrue((lCompiler <> '') and (lRTL <> '') and
    (lSource <> '') and (lOutput <> ''),
    'Set NX_SCANNER_TEST_COMPILER, RTL, SOURCE and OUTPUT as documented');
  if ACheckPointers then
    lOutput := lOutput + '/ExtDebugWithPointerChecks'
  else
    lOutput := lOutput + '/ExtDebug';
  AContext.AssertTrue(ForceDirectories(lOutput + '/units'),
    'Create the isolated compiler-unit output directory');
  lArguments := ['-n', '-O2', '-Xs', '-Sa', '-Aas-clang', '-XLL',
    '-dx86_64', '-dREVINC', '-dRELEASE', '-dEXTDEBUG',
    '-Fu' + lRTL, '-Fu' + lSource + '/x86_64', '-Fu' + lSource + '/x86',
    '-Fu' + lSource + '/systems', '-Fu' + lSource + '/../rtl/objpas',
    '-Fi' + lSource, '-Fi' + lSource + '/x86_64', '-Fi' + lSource + '/x86',
    '-Fi' + lSource + '/systems', '-FU' + lOutput + '/units',
    '-o' + lOutput + '/ppcx64', lSource + '/pp.pas'];
  if ACheckPointers then
  begin
    SetLength(lArguments, Length(lArguments) + 1);
    lArguments[High(lArguments)] := '-dCHECK_INPUTPOINTER_LIMITS';
  end;
  lExitCode := ExecuteProcess(lCompiler, lArguments);
  AContext.AssertEquals(0, lExitCode,
    'Compiler build must succeed; actual exit code ' + IntToStr(lExitCode));
end;

procedure ExtDebug(AContext: TNXTestContext);
begin
  BuildDebugCompiler(AContext, False);
end;

procedure ExtDebugWithPointerChecks(AContext: TNXTestContext);
begin
  BuildDebugCompiler(AContext, True);
end;

procedure CompileMultilineFixture(AContext: TNXTestContext; const AName: RawByteString);
var
  lCompiler, lRTL, lFixtures, lOutput: RawByteString;
  lExitCode: Integer;
begin
  lCompiler := GetEnvironmentVariable('NX_SCANNER_TEST_COMPILER');
  lRTL := GetEnvironmentVariable('NX_SCANNER_TEST_RTL');
  lFixtures := GetEnvironmentVariable('NX_SCANNER_TEST_FIXTURES');
  lOutput := GetEnvironmentVariable('NX_SCANNER_TEST_OUTPUT');
  AContext.AssertTrue((lCompiler <> '') and (lRTL <> '') and
    (lFixtures <> '') and (lOutput <> ''),
    'Set NX_SCANNER_TEST_COMPILER, RTL, FIXTURES and OUTPUT as documented');
  lOutput := lOutput + '/' + AName;
  AContext.AssertTrue(ForceDirectories(lOutput), 'Create isolated fixture outputs');
  lExitCode := ExecuteProcess(lCompiler, ['-n', '-O2', '-Aas-clang', '-XLL',
    '-Fu' + lRTL, '-FU' + lOutput, '-FE' + lOutput,
    '-o' + lOutput + '/sample', lFixtures + '/' + AName + '.pas']);
  AContext.AssertEquals(0, lExitCode,
    'Multiline fixture must compile; actual exit code ' + IntToStr(lExitCode));
  lExitCode := ExecuteProcess(lOutput + '/sample', RawByteString(''));
  AContext.AssertEquals(0, lExitCode, 'Multiline fixture must preserve its exact text');
end;

procedure AsciiMultiQuote(AContext: TNXTestContext);
begin
  CompileMultilineFixture(AContext, 'ScannerAsciiMultiQuote');
end;

procedure UTF8MultiQuote(AContext: TNXTestContext);
begin
  CompileMultilineFixture(AContext, 'ScannerUTF8MultiQuote');
end;

var
  lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    with lRegistry.AddSuite('Compiler.Scanner.BuildFlags') do
    begin
      AddTest('ExtDebug', @ExtDebug, 'compiler-build');
      AddTest('ExtDebugWithPointerChecks', @ExtDebugWithPointerChecks, 'compiler-build');
    end;
    with lRegistry.AddSuite('Compiler.Scanner.StringLiterals') do
    begin
      AddTest('AsciiMultiQuote', @AsciiMultiQuote, 'compiler-scanner');
      AddTest('UTF8MultiQuote', @UTF8MultiQuote, 'compiler-scanner');
    end;
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
