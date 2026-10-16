program NXResourceArtifactsTests;

{$mode objfpc}{$H+}

uses
  {$ifdef unix}CWString,{$endif}
  Classes, SysUtils, ResourceCatalog, ResourceArtifacts, ResourceTools;

var
  ArtifactRoot, SourceRoot: string;
  CheckCount: Integer;

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

function ReadBytes(const AFileName: string): TBytes;
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := ReadResourceData(LStream, AFileName);
  finally
    LStream.Free;
  end;
end;

procedure CopyFileBytes(const ASource, ADestination: string);
var
  LInput, LOutput: TFileStream;
begin
  LInput := TFileStream.Create(ASource, fmOpenRead or fmShareDenyWrite);
  try
    LOutput := TFileStream.Create(ADestination, fmCreate);
    try
      LOutput.CopyFrom(LInput, 0);
    finally
      LOutput.Free;
    end;
  finally
    LInput.Free;
  end;
end;

procedure AddPayload(ACatalog: TResourceCatalog; AId: Word; AValue: Byte);
var
  LEntry: TResourceEntry;
begin
  LEntry := TResourceEntry.Create;
  try
    LEntry.ResourceType := ResourceId(10);
    LEntry.Name := ResourceId(AId);
    LEntry.Origin := 'artifact test input';
    SetLength(LEntry.Data, 150001); { Exercise chunked comparison. }
    FillChar(LEntry.Data[0], Length(LEntry.Data), AValue);
    ACatalog.AddOwned(LEntry);
    LEntry := nil;
  finally
    LEntry.Free;
  end;
end;

procedure TestPublication;
var
  LCatalog, LLoaded: TResourceCatalog;
  LStage: TResourceArtifactStage;
  LName, LPrefix: string;
  LBefore: LongInt;
  LRaised: Boolean;
  LBytes: TBytes;
begin
  LName := ArtifactRoot + ResourceArtifactName('owner.nxu', 0);
  LPrefix := ArtifactRoot + 'staged';
  LCatalog := TResourceCatalog.Create;
  try
    AddPayload(LCatalog, 1, 11);
    WriteText(LName, 'old published sentinel');
    LStage := TResourceArtifactStage.Create(LCatalog, LName, LPrefix);
    try
      LBytes := ReadBytes(LName);
      Check((Length(LBytes) = 22) and (LBytes[0] = Ord('o')),
        'Staging changed published resource');
    finally
      LStage.Free;
    end;
    Check(not FileExists(LPrefix + '.canonical.res'), 'Abandoned stage was not removed');
    LStage := TResourceArtifactStage.Create(LCatalog, LName, LPrefix);
    try
      Check(LStage.Publish, 'Changed resource was not published');
      LRaised := False;
      try
        LStage.Publish;
      except
        on E: EResourceCatalog do LRaised := True;
      end;
      Check(LRaised, 'Published stage was accepted twice');
    finally
      LStage.Free;
    end;
    Check(not FileExists(LPrefix + '.canonical.res'), 'Published stage remains');
    Check(FileSetDate(LName, DateTimeToFileDate(EncodeDate(2020, 1, 2))) = 0,
      'Cannot set timestamp for unchanged-artifact check');
    LBefore := FileAge(LName);
    LStage := TResourceArtifactStage.Create(LCatalog, LName, LPrefix);
    try
      Check(not LStage.Publish, 'Unchanged resource was replaced');
    finally
      LStage.Free;
    end;
    Check(FileAge(LName) = LBefore, 'Unchanged artifact timestamp changed');
    Check(not FileExists(LPrefix + '.canonical.res'), 'Unchanged stage remains');
    LCatalog.Entries[0].Data[75000] := 22;
    LStage := TResourceArtifactStage.Create(LCatalog, LName, LPrefix);
    try
      Check(LStage.Publish, 'Same-size payload change was missed');
    finally
      LStage.Free;
    end;
    LLoaded := TResourceCatalog.Create;
    try
      LLoaded.LoadRes(LName);
      Check((LLoaded.Count = 1) and (LLoaded.Entries[0].Data[75000] = 22),
        'Changed payload was not published');
    finally
      LLoaded.Free;
    end;
    { A directory cannot be replaced by a file. Check this without depending
      on Unix root permission behavior or a particular Windows sharing mode. }
    ForceDirectories(ArtifactRoot + 'blocked');
    WriteText(ArtifactRoot + 'blocked' + PathDelim + 'sentinel', 'preserved');
    LStage := TResourceArtifactStage.Create(LCatalog, ArtifactRoot + 'blocked', LPrefix);
    try
      LRaised := False;
      try
        LStage.Publish;
      except
        on E: EResourceCatalog do LRaised := True;
      end;
      Check(LRaised, 'Failed publication was accepted');
      Check(FileExists(ArtifactRoot + 'blocked' + PathDelim + 'sentinel'),
        'Failed publication destroyed old destination');
    finally
      LStage.Free;
    end;
    Check(not FileExists(LPrefix + '.canonical.res'), 'Failed publication stage remains');
    LRaised := False;
    try
      LStage := TResourceArtifactStage.Create(LCatalog, LName,
        ArtifactRoot + 'other' + PathDelim + 'scratch');
      LStage.Free;
    except
      on E: EResourceCatalog do LRaised := True;
    end;
    Check(LRaised, 'Stage on another directory was accepted');
    LRaised := False;
    try
      LStage := TResourceArtifactStage.Create(LCatalog, LPrefix + '.canonical.res', LPrefix);
      LStage.Free;
    except
      on E: EResourceCatalog do LRaised := True;
    end;
    Check(LRaised, 'Stage overlapping published artifact was accepted');
  finally
    LCatalog.Free;
  end;
end;

procedure TestPublicationTransactions;
var
  LCatalog: TResourceCatalog;
  LFirst,LSecond: TResourceArtifactStage;
  LName,LPrefix,LNew: string;
  LBefore: LongInt;
  LOriginal,LRestored: TBytes;
  LRaised: Boolean;
begin
  LName:=ArtifactRoot+'transaction.res';
  LPrefix:=ArtifactRoot+'transaction-stage';
  LNew:=ArtifactRoot+'transaction-new.res';
  DeleteFile(LNew);
  WriteText(LName,'previous resources');
  Check(FileSetDate(LName,DateTimeToFileDate(EncodeDate(2020,1,2)))=0,
    'Cannot set transaction timestamp');
  LBefore:=FileAge(LName);
  LOriginal:=ReadBytes(LName);
  LCatalog:=TResourceCatalog.Create;
  try
    AddPayload(LCatalog,1,33);
    LFirst:=TResourceArtifactStage.Create(LCatalog,LName,LPrefix,True);
    LSecond:=TResourceArtifactStage.Create(LCatalog,ArtifactRoot+'blocked',
      ArtifactRoot+'transaction-blocked',True);
    try
      Check(LFirst.Publish,'Provisional replacement failed');
      LRaised:=False;
      try LSecond.Publish;
      except on E:EResourceCatalog do LRaised:=True; end;
      Check(LRaised,'Second publication should fail');
    finally
      LSecond.Free;
      LFirst.Free;
    end;
    LRestored:=ReadBytes(LName);
    Check((Length(LOriginal)=Length(LRestored)) and
      CompareMem(@LOriginal[0],@LRestored[0],Length(LOriginal)),
      'Failed publication batch did not restore old bytes');
    Check(FileAge(LName)=LBefore,'Rollback changed the original timestamp');
    Check(not FileExists(LPrefix+'.canonical.res.previous'),'Rollback left backup');
    LFirst:=TResourceArtifactStage.Create(LCatalog,LNew,LPrefix,True);
    try Check(LFirst.Publish,'New provisional artifact was not published');
    finally LFirst.Free; end;
    Check(not FileExists(LNew),'Abandoned new artifact was retained');
    LFirst:=TResourceArtifactStage.Create(LCatalog,LName,LPrefix,True);
    try
      Check(LFirst.Publish,'Committed artifact was not published');
      LFirst.Commit;
    finally LFirst.Free; end;
    Check(Length(ReadBytes(LName))>Length(LOriginal),'Committed artifact rolled back');
    LFirst:=TResourceArtifactStage.Create(LCatalog,LName,LPrefix,True);
    try Check(not LFirst.Publish,'Unchanged provisional artifact was replaced');
    finally LFirst.Free; end;
    Check(not FileExists(LPrefix+'.canonical.res.previous'),'Commit left backup');
  finally
    LCatalog.Free;
  end;
end;

procedure TestModuleOwnershipAndRelocation;
var
  LIndex: Integer;
  LInput, LName, LNames: string;
  LCatalog, LFinal: TResourceCatalog;
  LStage: TResourceArtifactStage;
begin
  LNames := '';
  ForceDirectories(ArtifactRoot + 'source-a');
  ForceDirectories(ArtifactRoot + 'source-b');
  ForceDirectories(ArtifactRoot + 'relocated');
  for LIndex := 0 to 1 do
  begin
    if LIndex = 0 then
    begin
      LInput := ArtifactRoot + 'source-a' + PathDelim + 'shared.res';
      LName := ResourceArtifactName('alpha.nxu', 0);
    end
    else
    begin
      LInput := ArtifactRoot + 'source-b' + PathDelim + 'shared.res';
      LName := ResourceArtifactName('beta.nxu', 0);
    end;
    Check(Pos(LName, LNames) = 0, 'Module-owned artifact name collision');
    LNames := LNames + LName;
    LCatalog := TResourceCatalog.Create;
    try
      AddPayload(LCatalog, LIndex + 1, LIndex + 10);
      LCatalog.SaveRes(LInput);
    finally
      LCatalog.Free;
    end;
    LCatalog := TResourceCatalog.Create;
    try
      Check(NormalizeResourceInput(LCatalog, nil, LInput, '') = rikRes,
        'Binary RES needs a compiler tool');
      LStage := TResourceArtifactStage.Create(LCatalog, ArtifactRoot + LName,
        ArtifactRoot + 'owner-' + IntToStr(LIndex));
      try
        LStage.Publish;
      finally
        LStage.Free;
      end;
    finally
      LCatalog.Free;
    end;
    CopyFileBytes(ArtifactRoot + LName, ArtifactRoot + 'relocated' + PathDelim + LName);
    Check(DeleteFile(LInput), 'Cannot hide original resource');
    Check(DeleteFile(ArtifactRoot + LName), 'Cannot hide original artifact directory');
  end;
  Check(ResourceArtifactName('alpha.nxu', 0) <> ResourceArtifactName('alpha.nxu', 1),
    'Two inputs of one module have the same artifact name');
  LFinal := TResourceCatalog.Create;
  try
    for LIndex := 0 to 1 do
    begin
      if LIndex = 0 then LName := ResourceArtifactName('alpha.nxu', 0)
      else LName := ResourceArtifactName('beta.nxu', 0);
      LCatalog := TResourceCatalog.Create;
      try
        LCatalog.LoadRes(ArtifactRoot + 'relocated' + PathDelim + LName);
        LFinal.MergeFrom(LCatalog);
      finally
        LCatalog.Free;
      end;
    end;
    Check(LFinal.Count = 2, 'Relocated source-hidden resource count');
    Check(LFinal.Find(ResourceId(10), ResourceId(1), 0).Data[0] = 10,
      'First source-hidden module payload');
    Check(LFinal.Find(ResourceId(10), ResourceId(2), 0).Data[0] = 11,
      'Second source-hidden module payload');
    LFinal.SaveRes(ArtifactRoot + 'relocated.res');
  finally
    LFinal.Free;
  end;
end;

procedure TestInputDetection;
var
  LCatalog, LLoaded: TResourceCatalog;
  LCompiler: TLLVMResourceCompiler;
  LSource: string;
  LRaised: Boolean;
begin
  LSource := ArtifactRoot + 'detected.rc';
  LCatalog := TResourceCatalog.Create;
  try
    AddPayload(LCatalog, 3, 33);
    LCatalog.SaveRes(LSource);
  finally
    LCatalog.Free;
  end;
  LCatalog := TResourceCatalog.Create;
  try
    Check(NormalizeResourceInput(LCatalog, nil, LSource, '') = rikRes,
      'RES signature must precede RC extension');
    LCatalog.SaveRes(ArtifactRoot + 'detected.dcr');
  finally
    LCatalog.Free;
  end;
  LCatalog := TResourceCatalog.Create;
  try
    Check(NormalizeResourceInput(LCatalog, nil, ArtifactRoot + 'detected.dcr', '') = rikRes,
      'Delphi DCR resource signature');
  finally
    LCatalog.Free;
  end;
  WriteText(ArtifactRoot + 'detected.lfm',
    'object Form: TTestForm' + LineEnding + 'end' + LineEnding);
  LCatalog := TResourceCatalog.Create;
  try
    Check(NormalizeResourceInput(LCatalog, nil, ArtifactRoot + 'detected.lfm', '') = rikForm,
      'Text form extension detection');
    LLoaded := TResourceCatalog.Create;
    try
      WriteText(LSource, '');
      with TFileStream.Create(LSource, fmCreate) do
      try
        WriteBuffer(LCatalog.Entries[0].Data[0], Length(LCatalog.Entries[0].Data));
      finally
        Free;
      end;
      Check(NormalizeResourceInput(LLoaded, nil, LSource, '') = rikForm,
        'Binary form signature must precede RC extension');
    finally
      LLoaded.Free;
    end;
  finally
    LCatalog.Free;
  end;
  LCatalog := TResourceCatalog.Create;
  try
    CopyFileBytes(SourceRoot + 'packages' + PathDelim + 'winunits-base' + PathDelim +
      'tests' + PathDelim + 'inproccomtest' + PathDelim + 'com_serv.tlb', LSource);
    Check(NormalizeResourceInput(LCatalog, nil, LSource, '') = rikTypeLibrary,
      'Type library signature must precede RC extension');
  finally
    LCatalog.Free;
  end;
  LCompiler := TLLVMResourceCompiler.Create;
  try
    LCompiler.ClangPath := ParamStr(3);
    LCompiler.RCPath := ParamStr(4);
    LCompiler.TargetTriple := 'x86_64-unknown-linux-gnu';
    WriteText(LSource, '1 RCDATA BEGIN 123 END' + LineEnding);
    LCatalog := TResourceCatalog.Create;
    try
      Check(NormalizeResourceInput(LCatalog, LCompiler, LSource,
        ArtifactRoot + 'detected') = rikRC, 'RC input normalization');
      Check(LCatalog.Count = 1, 'Compiled RC resource count');
    finally
      LCatalog.Free;
    end;
    WriteText(LSource, '1 RCDATA BEGIN' + LineEnding);
    WriteLn('EXPECT REJECTION: malformed RC input');
    Flush(Output);
    LCatalog := TResourceCatalog.Create;
    try
      LRaised := False;
      try
        NormalizeResourceInput(LCatalog, LCompiler, LSource, ArtifactRoot + 'detected');
      except
        on E: EResourceTool do LRaised := True;
      end;
      Check(LRaised and (LCatalog.Count = 0), 'Bad RC input was published');
      Check(not FileExists(ArtifactRoot + 'detected.raw.res'), 'Failed RC left stale raw RES');
    finally
      LCatalog.Free;
    end;
  finally
    LCompiler.Free;
  end;
end;

begin
  if ParamCount <> 4 then
  begin
    WriteLn(StdErr, 'Usage: nxResourceArtifactsTests <source-root> <artifact-root> <clang> <llvm-rc>');
    Halt(2);
  end;
  SourceRoot := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  ArtifactRoot := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(2)));
  TestPublication;
  TestPublicationTransactions;
  TestModuleOwnershipAndRelocation;
  TestInputDetection;
  WriteLn('PASS: ', CheckCount, ' resource artifact checks');
end.
