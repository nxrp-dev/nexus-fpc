(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
program BootstrapSmoke;

{$mode objfpc}{$H+}

uses Classes, SysUtils, DynLibs, obNXTestRegistry, obNXTestSuite,
  obNXTestContext, obNXTestResult;

procedure TestNativeRTL(AContext: TNXTestContext);
var
  lValues: TStringList;
begin
  lValues := TStringList.Create;
  try
    lValues.Add('z');
    lValues.Add('a');
    lValues.Sort;
    AContext.AssertEquals('a', lValues[0]);
    AContext.AssertEquals('2:a', Format('%d:%s', [lValues.Count, lValues[0]]));
  finally
    lValues.Free;
  end;
end;

procedure TestSharedRTL(AContext: TNXTestContext);
type
  TProbeValue = function: LongInt; cdecl;
var
  lLibrary: TLibHandle;
  lProbe: TProbeValue;
begin
  lLibrary := LoadLibrary(ParamStr(1));
  AContext.AssertTrue(lLibrary <> NilHandle, 'Load bootstrap shared library: ' + GetLoadErrorStr);
  try
    lProbe := TProbeValue(GetProcedureAddress(lLibrary, 'ProbeValue'));
    AContext.AssertTrue(Assigned(lProbe), 'Exported probe');
    AContext.AssertEquals(42, lProbe());
  finally
    AContext.AssertTrue(UnloadLibrary(lLibrary), 'Unload bootstrap shared library');
  end;
end;

procedure Run;
var
  lRegistry: TNXTestRegistry;
  lSuite: TNXTestSuite;
  lResult: TNXTestResult;
  lIndex, lPassed, lFailed: Integer;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lSuite := lRegistry.AddSuite('Bootstrap');
    lSuite.AddTest('NativeRTL', @TestNativeRTL);
    lSuite.AddTest('SharedRTL', @TestSharedRTL);
    lPassed := 0;
    lFailed := 0;
    for lIndex := 0 to lSuite.TestCount - 1 do
    begin
      lResult := lSuite.Tests[lIndex].Execute(lSuite.Name);
      try
        if lResult.Status = tsPassed then Inc(lPassed) else Inc(lFailed);
        WriteLn(lResult.StatusText, ' ', lResult.TestId, ' ', lResult.Message, ' ', lResult.ErrorMessage);
      finally
        lResult.Free;
      end;
    end;
    WriteLn(lPassed, ' passed; ', lFailed, ' failed/errors/skipped');
    if lFailed <> 0 then ExitCode := 1;
  finally
    lRegistry.Free;
  end;
end;

begin
  Run;
end.
