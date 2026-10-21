// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program ImplicitRuntimeTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, Process, obNXTestRegistry, obNXTestSuite,
  obNXTestContext, utNXTestConsole;

procedure TestLineInfoFromSource(AContext: TNXTestContext);
var
  lProcess: TProcess;
  lOutputStream: TStringStream;
  lOutput: string;
  lDirectory: string;
  lId: TGUID;
begin
  CreateGUID(lId);
  lDirectory := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(4))) +
    GUIDToString(lId);
  ForceDirectories(lDirectory);
  lProcess := TProcess.Create(nil);
  try
    lProcess.Executable := ExpandFileName(ParamStr(2));
    lProcess.CurrentDirectory := lDirectory;
    lProcess.Parameters.Add('-n');
    lProcess.Parameters.Add('-gl');
    lProcess.Parameters.Add('-Aas-clang');
    lProcess.Parameters.Add('-Fu' + ExpandFileName(ParamStr(1)) + '/rtl/inc');
    lProcess.Parameters.Add('-Fi' + ExpandFileName(ParamStr(1)) + '/rtl/inc');
    lProcess.Parameters.Add('-Fu' + ExpandFileName(ParamStr(3)));
    lProcess.Parameters.Add('-FU' + lDirectory);
    lProcess.Parameters.Add('-FE' + lDirectory);
    lProcess.Parameters.Add(ExpandFileName(ParamStr(1)) +
      '/tests/compiler-regressions/implicit_lineinfo_source.pas');
    lProcess.Options := [poUsePipes, poStderrToOutput];
    lProcess.Execute;
    lOutputStream := TStringStream.Create('');
    try
      lOutputStream.CopyFrom(lProcess.Output, 0);
      lOutput := lOutputStream.DataString;
      lOutputStream.SaveToFile(lDirectory + '/compile.log');
    finally
      lOutputStream.Free;
    end;
    lProcess.WaitOnExit;
    AContext.AssertEquals(0, lProcess.ExitStatus,
      'Implicit line information source compilation failed: ' + lOutput);
    AContext.AssertTrue(FileExists(lDirectory + '/lnfodwrf.nxu'),
      'The original line information source must be compiled.');
  finally
    lProcess.Free;
  end;
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
    lRegistry.AddSuite('ImplicitRuntime').AddTest('LineInfoFromSource',
      @TestLineInfoFromSource, 'compiler-implicit-units');
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
