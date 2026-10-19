program nxResourceMetadataTests;

{$mode objfpc}{$H+}

uses
  obNXTestRegistry, obNXTestContext, utNXTestConsole,
  Classes, SysUtils, ResourceCatalog, ResourceArtifacts, ResourceTools,
  ResourceMetadata;

var TestContext: TNXTestContext;

type
  TBoundedStream = class(TMemoryStream)
    function Read(var ABuffer; ACount: LongInt): LongInt; override;
    function Write(const ABuffer; ACount: LongInt): LongInt; override;
  end;

var
  LChecks: Integer;
  LOriginal, LRead: TModuleResourceInputs;
  LTools, LRestoredTools: TLLVMResourceCompiler;
  LStream, LBad: TBoundedStream;
  LInput: TModuleResourceInput;
  LIndex: Integer;
  LSavedName: string;
  LByte: Byte;
  LVersion: Cardinal;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  TestContext.AssertTrue(ACondition, AMessage);
  Inc(LChecks);
end;

function TBoundedStream.Read(var ABuffer; ACount: LongInt): LongInt;
begin
  Check(ACount <= 65536, 'Unbounded metadata read');
  Result := inherited Read(ABuffer, ACount);
end;

function TBoundedStream.Write(const ABuffer; ACount: LongInt): LongInt;
begin
  Check(ACount <= 65536, 'Unbounded metadata write');
  Result := inherited Write(ABuffer, ACount);
end;

procedure ExpectReadFailure;
var
  LRejected: Boolean;
begin
  LBad.Position := 0;
  LRejected := False;
  try
    LRead.LoadFromStream(LBad);
  except
    on E: EResourceCatalog do LRejected := True;
  end;
  Check(LRejected, 'Malformed resource metadata was accepted');
  Check((LRead.Count = 2) and (LRead[0].OriginalPath = LOriginal[0].OriginalPath),
    'Failed metadata read changed the previous list');
end;

procedure CopyValid;
var
  LBuffer: array[0..65535] of Byte;
  LCount: LongInt;
begin
  LBad.Clear;
  LStream.Position := 0;
  repeat
    LCount := LStream.Read(LBuffer, SizeOf(LBuffer));
    if LCount <> 0 then LBad.WriteBuffer(LBuffer, LCount);
  until LCount = 0;
end;

procedure ExpectWriteFailure;
var
  LRejected: Boolean;
begin
  LBad.Clear;
  LRejected := False;
  try
    LOriginal.SaveToStream(LBad);
  except
    on E: EResourceCatalog do LRejected := True;
  end;
  Check(LRejected, 'Invalid resource metadata was serialized');
  Check(LBad.Size = 0, 'Validation failure wrote partial metadata');
end;

procedure RunCase(AContext: TNXTestContext);
begin
  TestContext := AContext;
  try
    Check(ParamCount = 1, 'Expected an external artifact filename');
    LOriginal := TModuleResourceInputs.Create;
    LRead := TModuleResourceInputs.Create;
    LTools := TLLVMResourceCompiler.Create;
    LRestoredTools := TLLVMResourceCompiler.Create;
    LStream := TBoundedStream.Create;
    LBad := TBoundedStream.Create;
    try
      LTools.TargetTriple := 'arm64-apple-ios14.0-simulator';
      LTools.CodePage := 1252;
      LTools.ClangPath := '/original-host/clang';
      LTools.RCPath := '/original-host/llvm-rc';
      LTools.IncludeDirectories.Add('include directory/with spaces');
      LTools.Define('ORDERED', '1');
      LTools.Undefine('ORDERED');
      LTools.Define('ORDERED', '2');
      for LIndex := 0 to 1 do
      begin
        LInput := TModuleResourceInput.Create;
        LOriginal.AddOwned(LInput);
        LInput.OriginalPath := StringOfChar('p', 70000) + '/same.rc';
        LInput.DirectiveFile := 'owner' + IntToStr(LIndex) + '.pas';
        LInput.DirectiveLine := 42 + LIndex;
        LInput.ArtifactFile := ResourceArtifactName('owner.nxu', LIndex);
        LInput.Kind := rikRC;
        LInput.CaptureConfiguration(LTools);
      end;
      LTools.CodePage := 65001;
      LTools.MacroArguments.Clear;
      LOriginal.SaveToStream(LStream);
      LStream.SaveToFile(ParamStr(1));
      LStream.Position := 0;
      LRead.LoadFromStream(LStream);
      Check(LRead.Count = 2, 'Resource input count differs');
      for LIndex := 0 to 1 do
      begin
        LInput := LRead[LIndex];
        Check(LInput.OriginalPath = LOriginal[LIndex].OriginalPath, 'Long original path changed');
        Check(LInput.DirectiveFile = LOriginal[LIndex].DirectiveFile, 'Directive filename changed');
        Check(LInput.DirectiveLine = 42 + LIndex, 'Directive line changed');
        Check(LInput.ArtifactFile = ResourceArtifactName('owner.nxu', LIndex), 'Artifact identity changed');
        Check(LInput.Kind = rikRC, 'Input kind changed');
        Check(LInput.TargetTriple = 'arm64-apple-ios14.0-simulator', 'Target identity changed');
        Check(LInput.CodePage = 1252, 'Per-unit codepage was not preserved');
        Check(LInput.MacroArguments.Text = '-DORDERED=1' + LineEnding +
          '-UORDERED' + LineEnding + '-DORDERED=2' + LineEnding, 'Macro order changed');
      end;
      LRestoredTools.ClangPath := '/current-host/clang';
      LRestoredTools.RCPath := '/current-host/llvm-rc';
      LRestoredTools.TargetTriple := 'current-target';
      LRead[0].ConfigureCompiler(LRestoredTools);
      Check((LRestoredTools.ClangPath = '/current-host/clang') and
        (LRestoredTools.RCPath = '/current-host/llvm-rc'), 'Metadata replaced current tool paths');
      Check(LRestoredTools.TargetTriple = 'current-target', 'Metadata replaced actual target');
      Check((LRestoredTools.CodePage = 1252) and
        (LRestoredTools.MacroArguments.Count = 3) and
        (LRestoredTools.IncludeDirectories[0] = 'include directory/with spaces'),
        'Stored resource configuration was not restored');
      for LIndex := 0 to 11 do
      begin
        CopyValid;
        LBad.Size := LIndex;
        ExpectReadFailure;
      end;
      CopyValid;
      LBad.Size := LBad.Size - 1;
      ExpectReadFailure;
      CopyValid;
      LBad.Position := 0;
      LByte := 0;
      LBad.WriteBuffer(LByte, 1);
      ExpectReadFailure;
      CopyValid;
      LBad.Position := 4;
      LVersion := 2;
      LBad.WriteBuffer(LVersion, 4);
      ExpectReadFailure;
      CopyValid;
      LBad.Position := 8;
      LVersion := High(Cardinal);
      LBad.WriteBuffer(LVersion, 4);
      ExpectReadFailure;
      CopyValid;
      LBad.Position := 12;
      LBad.WriteBuffer(LVersion, 4);
      ExpectReadFailure;
      CopyValid;
      LBad.Position := LBad.Size;
      LBad.WriteBuffer(LByte, 1);
      ExpectReadFailure;
      LSavedName := LOriginal[1].ArtifactFile;
      LOriginal[1].ArtifactFile := UpperCase(LOriginal[0].ArtifactFile);
      ExpectWriteFailure;
      LOriginal[1].ArtifactFile := '../outside.res';
      ExpectWriteFailure;
      LOriginal[1].ArtifactFile := '..\outside.res';
      ExpectWriteFailure;
      LOriginal[1].ArtifactFile := 'C:outside.res';
      ExpectWriteFailure;
      LOriginal[1].ArtifactFile := LSavedName;
      LOriginal[1].CodePage := 0;
      ExpectWriteFailure;
      LOriginal[1].CodePage := 1252;
      LOriginal[1].MacroArguments.Add('-include hidden.h');
      ExpectWriteFailure;
      LOriginal[1].MacroArguments.Delete(3);
      LOriginal[1].IncludeDirectories.Add('bad'#0'path');
      ExpectWriteFailure;
      LOriginal[1].IncludeDirectories.Delete(1);
      LBad.Clear;
      LOriginal.SaveToStream(LBad);
      Check((LStream.Size = LBad.Size) and
        CompareMem(LStream.Memory, LBad.Memory, LStream.Size), 'Metadata output is not deterministic');
      WriteLn('PASS resource metadata: ', LChecks, ' checks');
    finally
      LBad.Free;
      LStream.Free;
      LRestoredTools.Free;
      LTools.Free;
      LRead.Free;
      LOriginal.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('FAIL ', E.ClassName, ': ', E.Message);
      DumpExceptionBackTrace(Output);
      TestContext.Fail(E.ClassName + ': ' + E.Message);
    end;
  end;
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('Resources.Metadata').AddTest('SerializationAndRejection', @RunCase, 'resources');
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
