unit tsNXResourceInputs;

{$mode objfpc}{$H+}

interface
uses obNXTestRegistry;
procedure RegisterInputsTests(ARegistry: TNXTestRegistry);
implementation

uses
  obNXTestContext, obNXTestSuite, utNXResourceTestArgs,
  {$ifdef unix}CWString,{$endif}
  Classes, SysUtils, ResourceCatalog, ResourceInputs;

const
  CForm = 'object Demo: TDemo' + LineEnding +
    '  Caption = ''Hello''#13#10''World''' + LineEnding +
    '  Left = -1' + LineEnding +
    '  Width = 320' + LineEnding +
    '  Styles = [First, Second]' + LineEnding +
    '  Data = {0001FF}' + LineEnding +
    '  Items = <item Text = ''One'' end>' + LineEnding +
    '  object Child: TChild' + LineEnding + '  end' + LineEnding +
    'end' + LineEnding;

var
  TestContext: TNXTestContext;
  SourceRoot, ArtifactRoot: string;


procedure CheckForm(AEntry: TResourceEntry; const AClassName: string);
begin
  TestContext.AssertTrue((not AEntry.ResourceType.IsName) and (AEntry.ResourceType.Id = 10),
    'Form resource type');
  TestContext.AssertTrue(AEntry.Name.IsName and (AEntry.Name.Name = UnicodeString(AClassName)),
    'Form root class');
  TestContext.AssertTrue((AEntry.Language = 0) and (AEntry.MemoryFlags = $1010) and
    (AEntry.DataVersion = 0) and (AEntry.Version = 0) and
    (AEntry.Characteristics = 0), 'Form metadata defaults');
  TestContext.AssertTrue((Length(AEntry.Data) >= 4) and (AEntry.Data[0] = Ord('T')) and
    (AEntry.Data[3] = Ord('0')), 'Binary form payload');
end;

procedure TestForm(const AName, AText, AClassName: string);
var
  LText: TStringStream;
  LBinary: TMemoryStream;
  LCatalog, LFromBinary: TResourceCatalog;
begin
  LText := TStringStream.Create(AText);
  LBinary := TMemoryStream.Create;
  LCatalog := TResourceCatalog.Create;
  LFromBinary := TResourceCatalog.Create;
  try
    LText.SaveToFile(ArtifactRoot + AName + '.lfm');
    LText.Position := 0;
    LoadFormResource(LCatalog, LText, AName + '.lfm');
    TestContext.AssertTrue(LCatalog.Count = 1, 'Form resource count');
    CheckForm(LCatalog[0], AClassName);
    LCatalog.SaveRes(ArtifactRoot + AName + '.res');
    LBinary.WriteBuffer(LCatalog[0].Data[0], Length(LCatalog[0].Data));
    LBinary.SaveToFile(ArtifactRoot + AName + '.dfm');
    LBinary.Position := 0;
    LoadFormResource(LFromBinary, LBinary, AName + '.dfm');
    CheckForm(LFromBinary[0], AClassName);
    TestContext.AssertTrue((Length(LCatalog[0].Data) = Length(LFromBinary[0].Data)) and
      CompareMem(@LCatalog[0].Data[0], @LFromBinary[0].Data[0],
        Length(LCatalog[0].Data)), 'Binary form bytes changed');
    LFromBinary.SaveRes(ArtifactRoot + AName + '-binary.res');
  finally
    LFromBinary.Free;
    LCatalog.Free;
    LBinary.Free;
    LText.Free;
  end;
end;

procedure TestFormFile;
var
  LCatalog: TResourceCatalog;
  LStream: TFileStream;
begin
  LCatalog := TResourceCatalog.Create;
  LStream := TFileStream.Create(SourceRoot + 'tests/rtl/fixtures/system/tres6.lfm', fmOpenRead);
  try
    LoadFormResource(LCatalog, LStream, 'tres6.lfm');
    TestContext.AssertTrue(LCatalog.Count = 1, 'Real form resource count');
    CheckForm(LCatalog[0], 'TMYRES');
    LCatalog.SaveRes(ArtifactRoot + 'tres6.res');
  finally
    LStream.Free;
    LCatalog.Free;
  end;
end;

procedure TestInvalidForms;
var
  LCatalog: TResourceCatalog;
  LStream: TStringStream;
  LData: string;
  LCase: Integer;
  LRaised: Boolean;
begin
  for LCase := 0 to 3 do
  begin
    case LCase of
      0: LData := '';
      1: LData := 'object Broken TBroken' + LineEnding + 'end';
      2: LData := 'TPF0'#9'Short';
      3: LData := 'TPF0'#0#0#0#0;
    end;
    LCatalog := TResourceCatalog.Create;
    LStream := TStringStream.Create(LData);
    try
      LRaised := False;
      try
        LoadFormResource(LCatalog, LStream, 'malformed-form');
      except
        on E: EResourceCatalog do
        begin
          LRaised := True;
          TestContext.AssertTrue(Pos('malformed-form', E.Message) <> 0, 'Form diagnostic provenance');
        end;
      end;
      TestContext.AssertTrue(LRaised, 'Malformed form accepted: ' + IntToStr(LCase));
      TestContext.AssertTrue(LCatalog.Count = 0, 'Malformed form published a resource');
    finally
      LStream.Free;
      LCatalog.Free;
    end;
  end;
end;

procedure TestTypeLibraries;
var
  LCatalog: TResourceCatalog;
  LStream: TStream;
  LExpected: TBytes;
  LCase: Integer;
  LSignature: string;
  LRaised: Boolean;
begin
  for LCase := 0 to 2 do
  begin
    LCatalog := TResourceCatalog.Create;
    case LCase of
      0: LStream := TFileStream.Create(SourceRoot +
        'packages/winunits-base/tests/inproccomtest/com_serv.tlb', fmOpenRead);
      1, 2: begin
              if LCase = 1 then LSignature := 'MSFT' else LSignature := 'SLTG';
              LStream := TStringStream.Create(LSignature + #0#$FF'opaque typelib');
            end;
    end;
    try
      LExpected := ReadResourceData(LStream, 'expected');
      LStream.Position := 0;
      LoadTypeLibraryResource(LCatalog, LStream, 'first.tlb');
      TestContext.AssertTrue(LCatalog.Count = 1, 'Type-library resource count');
      TestContext.AssertTrue(LCatalog[0].ResourceType.IsName and
        (LCatalog[0].ResourceType.Name = 'TYPELIB') and
        not LCatalog[0].Name.IsName and (LCatalog[0].Name.Id = 1),
        'Direct type-library identity');
      TestContext.AssertTrue((LCatalog[0].Language = 0) and (LCatalog[0].MemoryFlags = $1010),
        'Type-library metadata defaults');
      TestContext.AssertTrue((Length(LCatalog[0].Data) = Length(LExpected)) and
        CompareMem(@LCatalog[0].Data[0], @LExpected[0], Length(LExpected)),
        'Opaque type-library payload');
      if LCase = 0 then LCatalog.SaveRes(ArtifactRoot + 'com_serv.res');
      LStream.Position := 0;
      LRaised := False;
      try
        LoadTypeLibraryResource(LCatalog, LStream, 'second.tlb');
      except
        on E: EResourceCatalog do
        begin
          LRaised := True;
          TestContext.AssertTrue((Pos('first.tlb', E.Message) <> 0) and
            (Pos('second.tlb', E.Message) <> 0), 'TLB duplicate provenance');
        end;
      end;
      TestContext.AssertTrue(LRaised, 'A direct type library was silently renumbered');
    finally
      LStream.Free;
      LCatalog.Free;
    end;
  end;
  LCatalog := TResourceCatalog.Create;
  LStream := TStringStream.Create('bad!');
  try
    LRaised := False;
    try
      LoadTypeLibraryResource(LCatalog, LStream, 'invalid.tlb');
    except
      on E: EResourceCatalog do LRaised := True;
    end;
    TestContext.AssertTrue(LRaised and (LCatalog.Count = 0), 'Invalid type-library signature');
  finally
    LStream.Free;
    LCatalog.Free;
  end;
end;

procedure RunSimpleForm(AContext: TNXTestContext);
begin
  TestContext := AContext;
  try
    SourceRoot := IncludeTrailingPathDelimiter(ResourceTestArg(1));
    ArtifactRoot := IncludeTrailingPathDelimiter(ResourceTestArg(2));
    TestForm('simple', CForm, 'TDEMO');
  finally
    TestContext := nil;
  end;
end;

procedure RunBOMForm(AContext: TNXTestContext);
begin
  TestContext := AContext;
  try
    SourceRoot := IncludeTrailingPathDelimiter(ResourceTestArg(1));
    ArtifactRoot := IncludeTrailingPathDelimiter(ResourceTestArg(2));
    TestForm('bom', #$EF#$BB#$BF + CForm, 'TDEMO');
  finally
    TestContext := nil;
  end;
end;

procedure RunInheritedForm(AContext: TNXTestContext);
begin
  TestContext := AContext;
  try
    SourceRoot := IncludeTrailingPathDelimiter(ResourceTestArg(1));
    ArtifactRoot := IncludeTrailingPathDelimiter(ResourceTestArg(2));
    TestForm('inherited', 'inherited Demo: TDemo' + LineEnding + '  Caption = ''Inherited''' + LineEnding + 'end' + LineEnding, 'TDEMO');
  finally
    TestContext := nil;
  end;
end;

procedure RunChildPosition(AContext: TNXTestContext);
begin
  TestContext := AContext;
  try
    SourceRoot := IncludeTrailingPathDelimiter(ResourceTestArg(1));
    ArtifactRoot := IncludeTrailingPathDelimiter(ResourceTestArg(2));
    TestForm('childpos', 'inherited Demo: TDemo [4]' + LineEnding + 'end' + LineEnding, 'TDEMO');
  finally
    TestContext := nil;
  end;
end;

procedure RunFormFile(AContext: TNXTestContext);
begin
  TestContext := AContext;
  try
    SourceRoot := IncludeTrailingPathDelimiter(ResourceTestArg(1));
    ArtifactRoot := IncludeTrailingPathDelimiter(ResourceTestArg(2));
    TestFormFile;
  finally
    TestContext := nil;
  end;
end;

procedure RunInvalidForms(AContext: TNXTestContext);
begin
  TestContext := AContext;
  try
    SourceRoot := IncludeTrailingPathDelimiter(ResourceTestArg(1));
    ArtifactRoot := IncludeTrailingPathDelimiter(ResourceTestArg(2));
    TestInvalidForms;
  finally
    TestContext := nil;
  end;
end;

procedure RunTypeLibraries(AContext: TNXTestContext);
begin
  TestContext := AContext;
  try
    SourceRoot := IncludeTrailingPathDelimiter(ResourceTestArg(1));
    ArtifactRoot := IncludeTrailingPathDelimiter(ResourceTestArg(2));
    TestTypeLibraries;
  finally
    TestContext := nil;
  end;
end;

procedure RegisterInputsTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  if ResourceTestArgCount <> 2 then raise Exception.Create('Invalid arguments for resource inputs tests');
  lSuite := ARegistry.AddSuite('Resources.Inputs');
  lSuite.AddTest('SimpleForm', @RunSimpleForm, 'resources-inputs');
  lSuite.AddTest('BOMForm', @RunBOMForm, 'resources-inputs');
  lSuite.AddTest('InheritedForm', @RunInheritedForm, 'resources-inputs');
  lSuite.AddTest('ChildPosition', @RunChildPosition, 'resources-inputs');
  lSuite.AddTest('FormFile', @RunFormFile, 'resources-inputs');
  lSuite.AddTest('InvalidForms', @RunInvalidForms, 'resources-inputs');
  lSuite.AddTest('TypeLibraries', @RunTypeLibraries, 'resources-inputs');
end;
end.
