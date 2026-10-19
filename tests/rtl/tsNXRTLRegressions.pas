unit tsNXRTLRegressions;
{$mode objfpc}{$H+}
interface
uses obNXTestRegistry;
procedure RegisterRTLRegressions(ARegistry: TNXTestRegistry;
  const ASourceRoot, ACompiler, ARTL, AOutputRoot: string);
implementation
uses Classes, SysUtils, StrUtils, Process, tsutils, tstypes, obNXTestContext, obNXTestSuite;

type
  TFixture = record
    Id, Source, Execution, Dependencies, Platform, Reason: string;
  end;
var
  Fixtures: array of TFixture;
  SourceRoot, Compiler, RTL, OutputRoot: string;

procedure SaveText(const AName, AText: string);
var lText: TStringList;
begin
  lText := TStringList.Create;
  try lText.Text := AText; lText.SaveToFile(AName); finally lText.Free; end;
end;

procedure CopyFile(const ASource, ADestination: string);
var lInput, lOutput: TFileStream;
begin
  lInput := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    lOutput := TFileStream.Create(ADestination, fmCreate);
    try lOutput.CopyFrom(lInput, 0); finally lOutput.Free; end;
  finally lInput.Free; end;
end;

procedure CopyInputs(const ASource, ADestination: string);
var lSearch: TSearchRec;
begin
  ForceDirectories(ADestination);
  if FindFirst(IncludeTrailingPathDelimiter(ASource) + '*', faAnyFile, lSearch) <> 0 then Exit;
  try
    repeat
      if (lSearch.Attr and faDirectory) = 0 then
        CopyFile(IncludeTrailingPathDelimiter(ASource) + lSearch.Name,
          IncludeTrailingPathDelimiter(ADestination) + lSearch.Name);
    until FindNext(lSearch) <> 0;
  finally FindClose(lSearch); end;
end;

function Execute(AContext: TNXTestContext; const AExecutable, ADirectory: string;
  AArguments: TStrings; const ALogName: string): Integer;
var lProcess: TProcess; lOutput: TMemoryStream; lBuffer: array[0..8191] of Byte;
  lCount: LongInt; lStart: QWord; lTimedOut: Boolean; lText: RawByteString;
begin
  lProcess := TProcess.Create(nil);
  lOutput := TMemoryStream.Create;
  try
    lProcess.Executable := AExecutable;
    lProcess.CurrentDirectory := ADirectory;
    lProcess.Parameters.Assign(AArguments);
    lProcess.Options := [poUsePipes, poStderrToOutput];
    lProcess.Execute;
    lStart := GetTickCount64;
    lTimedOut := False;
    repeat
      while lProcess.Output.NumBytesAvailable > 0 do
      begin
        lCount := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
        if lCount > 0 then lOutput.WriteBuffer(lBuffer, lCount);
      end;
      if not lProcess.Running then Break;
      if GetTickCount64 - lStart > 30000 then
      begin
        lTimedOut := True;
        lProcess.Terminate(9);
        lProcess.WaitOnExit;
        Break;
      end;
      Sleep(1);
    until False;
    while lProcess.Output.NumBytesAvailable > 0 do
    begin
      lCount := lProcess.Output.Read(lBuffer, SizeOf(lBuffer));
      if lCount > 0 then lOutput.WriteBuffer(lBuffer, lCount);
    end;
    SetLength(lText, lOutput.Size);
    if Length(lText) > 0 then Move(lOutput.Memory^, lText[1], Length(lText));
    SaveText(ADirectory + PathDelim + ALogName, lText);
    AContext.AssertFalse(lTimedOut, 'Timed out after 30 seconds; see ' + ADirectory + PathDelim + ALogName);
    Result := lProcess.ExitCode;
  finally lOutput.Free; lProcess.Free; end;
end;

procedure AddSearchPath(AOptions: TStrings; const ARelative: string);
begin
  if DirectoryExists(SourceRoot + ARelative) then
  begin
    AOptions.Add('-Fu' + SourceRoot + ARelative);
    AOptions.Add('-Fi' + SourceRoot + ARelative);
  end;
end;

procedure RunFixture(AContext: TNXTestContext);
var lFixture: TFixture; lIndex, lStatus, lOutputOption: Integer; lDirectory, lSource, lExecutable, lDependency: string;
  lOptions, lLog: TStringList; lConfig: TConfig;
begin
  lIndex := 0;
  while (lIndex < Length(Fixtures)) and (Fixtures[lIndex].Id <> AContext.Result.TestId) do Inc(lIndex);
  AContext.AssertTrue(lIndex < Length(Fixtures), 'Fixture must be registered');
  lFixture := Fixtures[lIndex];
  if lFixture.Reason <> '' then AContext.Skip(lFixture.Reason);
  if (lFixture.Platform <> '') and
    (Pos(',' + LowerCase({$I %FPCTARGETOS%}) + ',', ',' + lFixture.Platform + ',') = 0) then
    AContext.Skip('Requires platform ' + lFixture.Platform);
  AContext.AssertTrue(GetConfig('', SourceRoot + lFixture.Source, lConfig), 'Read fixture directives');
  if (lConfig.NeedTarget <> '') and
    (Pos(',' + LowerCase({$I %FPCTARGETOS%}) + ',', ',' + LowerCase(lConfig.NeedTarget) + ',') = 0) then
    AContext.Skip('Requires target ' + lConfig.NeedTarget);
  if (lConfig.NeedCPU <> '') and
    (Pos(',' + LowerCase({$I %FPCTARGETCPU%}) + ',', ',' + LowerCase(lConfig.NeedCPU) + ',') = 0) then
    AContext.Skip('Requires CPU ' + lConfig.NeedCPU);
  if Pos(',' + LowerCase({$I %FPCTARGETOS%}) + ',', ',' + LowerCase(lConfig.SkipTarget) + ',') > 0 then
    AContext.Skip('Excluded target ' + lConfig.SkipTarget);
  if Pos(',' + LowerCase({$I %FPCTARGETCPU%}) + ',', ',' + LowerCase(lConfig.SkipCPU) + ',') > 0 then
    AContext.Skip('Excluded CPU ' + lConfig.SkipCPU);
  if lConfig.Interactive then AContext.Skip('Interactive terminal fixture');
  lDirectory := OutputRoot + StringReplace(lFixture.Id, '.', '-', [rfReplaceAll]);
  ForceDirectories(lDirectory);
  lSource := SourceRoot + lFixture.Source;
  CopyInputs(ExtractFileDir(lSource), lDirectory);
  lSource := lDirectory + PathDelim + ExtractFileName(lSource);
  lExecutable := lDirectory + PathDelim + ChangeFileExt(ExtractFileName(lSource),
    {$IFDEF MSWINDOWS}'.exe'{$ELSE}''{$ENDIF});
  lOptions := TStringList.Create;
  lLog := TStringList.Create;
  try
    lOptions.Add('-n');
    {$IFDEF UNIX}lOptions.Add('-Aas-clang'); lOptions.Add('-XLL');{$ENDIF}
    lOptions.Add('-Fu' + RTL);
    lOptions.Add('-FU' + lDirectory);
    lOptions.Add('-FE' + lDirectory);
    lOptions.Add('-o' + lExecutable);
    lOptions.Add('-Fi' + ExtractFileDir(SourceRoot + lFixture.Source));
    lOptions.Add('-Fu' + ExtractFileDir(SourceRoot + lFixture.Source));
    AddSearchPath(lOptions, '../nexus/packages/nexus-packages/rtl-unicode/src/inc');
    AddSearchPath(lOptions, '../../nexus/packages/nexus-packages/rtl-unicode/src/inc');
    AddSearchPath(lOptions, 'rtl/inc');
    AddSearchPath(lOptions, 'rtl/objpas');
    AddSearchPath(lOptions, 'tests/tstunits');
    AddSearchPath(lOptions, 'packages/rtl-objpas/src/inc');
    AddSearchPath(lOptions, 'packages/rtl-objpas/src/' + {$IFDEF MSWINDOWS}'win'{$ELSE}'unix'{$ENDIF});
    AddSearchPath(lOptions, 'packages/rtl-generics/src');
    AddSearchPath(lOptions, 'packages/rtl-generics/src/inc');
    AddSearchPath(lOptions, '../nexus/packages/nexus-packages/fcl-base/src');
    AddSearchPath(lOptions, '../../nexus/packages/nexus-packages/fcl-base/src');
    AddSearchPath(lOptions, '../../nexus/packages/nexus-packages/fcl-base/src/' + {$IFDEF MSWINDOWS}'win'{$ELSE}'unix'{$ENDIF});
    AddSearchPath(lOptions, '../../nexus/packages/nexus-packages/fcl-base/src/dummy');
    AddSearchPath(lOptions, '../nexus/packages/nexus-packages/fcl-base/src/' + {$IFDEF MSWINDOWS}'win'{$ELSE}'unix'{$ENDIF});
    AddSearchPath(lOptions, '../nexus/packages/nexus-packages/fcl-base/src/dummy');
    AddSearchPath(lOptions, '../nexus/packages/nexus-packages/pthreads/src');
    AddSearchPath(lOptions, '../../nexus/packages/nexus-packages/pthreads/src');
    AddSearchPath(lOptions, 'packages/rtl-extra/src/' + {$IFDEF MSWINDOWS}'win'{$ELSE}'unix'{$ENDIF});
    lOptions.AddStrings(lConfig.NeedOptions.Split([' '], TStringSplitOptions.ExcludeEmpty));
    lOptions.Add(lSource);
    SaveText(lDirectory + PathDelim + 'compiler-arguments.txt', lOptions.Text);
    lStatus := Execute(AContext, Compiler, lDirectory, lOptions, 'compile.log');
    lLog.LoadFromFile(lDirectory + PathDelim + 'compile.log');
    AContext.AssertTrue(Pos('internal error', LowerCase(lLog.Text)) = 0,
      'Internal compiler error: ' + lLog.Text);
    if lConfig.ShouldFail then
    begin
      AContext.AssertTrue(lStatus <> 0, 'Expected compilation to fail');
      AContext.AssertTrue((Pos('Error:', lLog.Text) > 0) or (Pos('Fatal: Syntax error', lLog.Text) > 0), 'Expected an ordinary compiler error: ' + lLog.Text);
      Exit;
    end;
    AContext.AssertEquals(0, lStatus, 'Compilation failed: ' + lLog.Text);
    if lConfig.NoRun or (lFixture.Execution = 'compile') then Exit;
    // Helper executables are compiled into this case's private directory.
    lOutputOption := lOptions.IndexOf('-o' + lExecutable);
    for lDependency in lFixture.Dependencies.Split([';'], TStringSplitOptions.ExcludeEmpty) do
    begin
      lOptions[lOptions.Count - 1] := lDirectory + PathDelim + lDependency;
      lOptions[lOutputOption] := '-o' + lDirectory + PathDelim +
        ChangeFileExt(lDependency, {$IFDEF MSWINDOWS}'.exe'{$ELSE}''{$ENDIF});
      lStatus := Execute(AContext, Compiler, lDirectory, lOptions, lDependency + '.compile.log');
      AContext.AssertEquals(0, lStatus, 'Subprocess fixture compilation failed: ' + lDependency);
    end;
    lOptions.Clear;
    lStatus := Execute(AContext, lExecutable, lDirectory, lOptions, 'run.log');
    AContext.AssertEquals(lConfig.ResultCode, lStatus,
      'Unexpected fixture exit; see ' + lDirectory + PathDelim + 'run.log');
  finally lLog.Free; lOptions.Free; end;
end;

procedure RegisterRTLRegressions(ARegistry: TNXTestRegistry;
  const ASourceRoot, ACompiler, ARTL, AOutputRoot: string);
var lLines, lFields: TStringList; lIndex, lCount: Integer; lSuite: TNXTestSuite;
  lRunId: TGUID;
begin
  SourceRoot := IncludeTrailingPathDelimiter(ASourceRoot);
  Compiler := ACompiler;
  RTL := ARTL;
  if not FileExists(Compiler) then raise Exception.Create('Missing matching compiler: ' + Compiler);
  if not DirectoryExists(RTL) then raise Exception.Create('Missing matching RTL: ' + RTL);
  if AnsiStartsText(SourceRoot, IncludeTrailingPathDelimiter(AOutputRoot)) then
    raise Exception.Create('Output must be outside the source tree');
  CreateGUID(lRunId);
  OutputRoot := IncludeTrailingPathDelimiter(AOutputRoot) + GUIDToString(lRunId) + PathDelim;
  ForceDirectories(OutputRoot);
  WriteLn('Fixture logs: ', OutputRoot);
  lLines := TStringList.Create;
  lFields := TStringList.Create;
  try
    lFields.Delimiter := #9;
    lFields.StrictDelimiter := True;
    lFields.QuoteChar := #0;
    lLines.LoadFromFile(SourceRoot + 'tests/rtl/fixtures.tsv');
    SetLength(Fixtures, lLines.Count - 1);
    for lIndex := 1 to lLines.Count - 1 do
    begin
      lFields.DelimitedText := lLines[lIndex];
      if lFields.Count <> 7 then raise Exception.Create('Invalid fixture manifest row ' + IntToStr(lIndex + 1));
      lCount := lIndex - 1;
      Fixtures[lCount].Id := lFields[0] + '.' + lFields[1];
      Fixtures[lCount].Source := lFields[2];
      Fixtures[lCount].Execution := lFields[3];
      Fixtures[lCount].Dependencies := lFields[4];
      Fixtures[lCount].Platform := lFields[5];
      Fixtures[lCount].Reason := lFields[6];
      lSuite := ARegistry.AddSuite(lFields[0]);
      lSuite.AddTest(lFields[1], @RunFixture, 'rtl-' + LowerCase(Copy(lFields[0], 5, MaxInt)));
    end;
  finally lFields.Free; lLines.Free; end;
end;
end.
