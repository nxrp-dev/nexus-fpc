program NXResourceInputsTests;

{$mode objfpc}{$H+}

uses
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
  CheckCount: Integer;
  SourceRoot, ArtifactRoot: string;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(CheckCount);
  if not ACondition then raise Exception.Create(AMessage);
end;

procedure CheckForm(AEntry: TResourceEntry; const AClassName: string);
begin
  Check((not AEntry.ResourceType.IsName) and (AEntry.ResourceType.Id = 10),
    'Form resource type');
  Check(AEntry.Name.IsName and (AEntry.Name.Name = UnicodeString(AClassName)),
    'Form root class');
  Check((AEntry.Language = 0) and (AEntry.MemoryFlags = $1010) and
    (AEntry.DataVersion = 0) and (AEntry.Version = 0) and
    (AEntry.Characteristics = 0), 'Form metadata defaults');
  Check((Length(AEntry.Data) >= 4) and (AEntry.Data[0] = Ord('T')) and
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
    Check(LCatalog.Count = 1, 'Form resource count');
    CheckForm(LCatalog[0], AClassName);
    LCatalog.SaveRes(ArtifactRoot + AName + '.res');
    LBinary.WriteBuffer(LCatalog[0].Data[0], Length(LCatalog[0].Data));
    LBinary.SaveToFile(ArtifactRoot + AName + '.dfm');
    LBinary.Position := 0;
    LoadFormResource(LFromBinary, LBinary, AName + '.dfm');
    CheckForm(LFromBinary[0], AClassName);
    Check((Length(LCatalog[0].Data) = Length(LFromBinary[0].Data)) and
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
  LStream := TFileStream.Create(SourceRoot + 'tests/test/units/system/tres6.lfm', fmOpenRead);
  try
    LoadFormResource(LCatalog, LStream, 'tres6.lfm');
    Check(LCatalog.Count = 1, 'Real form resource count');
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
          Check(Pos('malformed-form', E.Message) <> 0, 'Form diagnostic provenance');
        end;
      end;
      Check(LRaised, 'Malformed form accepted: ' + IntToStr(LCase));
      Check(LCatalog.Count = 0, 'Malformed form published a resource');
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
      Check(LCatalog.Count = 1, 'Type-library resource count');
      Check(LCatalog[0].ResourceType.IsName and
        (LCatalog[0].ResourceType.Name = 'TYPELIB') and
        not LCatalog[0].Name.IsName and (LCatalog[0].Name.Id = 1),
        'Direct type-library identity');
      Check((LCatalog[0].Language = 0) and (LCatalog[0].MemoryFlags = $1010),
        'Type-library metadata defaults');
      Check((Length(LCatalog[0].Data) = Length(LExpected)) and
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
          Check((Pos('first.tlb', E.Message) <> 0) and
            (Pos('second.tlb', E.Message) <> 0), 'TLB duplicate provenance');
        end;
      end;
      Check(LRaised, 'A direct type library was silently renumbered');
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
    Check(LRaised and (LCatalog.Count = 0), 'Invalid type-library signature');
  finally
    LStream.Free;
    LCatalog.Free;
  end;
end;

begin
  if ParamCount <> 2 then
  begin
    WriteLn(StdErr, 'Usage: nxResourceInputsTests <source-root> <artifact-root>');
    Halt(2);
  end;
  SourceRoot := IncludeTrailingPathDelimiter(ParamStr(1));
  ArtifactRoot := IncludeTrailingPathDelimiter(ParamStr(2));
  TestForm('simple', CForm, 'TDEMO');
  TestForm('bom', #$EF#$BB#$BF + CForm, 'TDEMO');
  TestForm('inherited', 'inherited Demo: TDemo' + LineEnding +
    '  Caption = ''Inherited''' + LineEnding + 'end' + LineEnding, 'TDEMO');
  TestForm('childpos', 'inherited Demo: TDemo [4]' + LineEnding +
    'end' + LineEnding, 'TDEMO');
  TestFormFile;
  TestInvalidForms;
  TestTypeLibraries;
  WriteLn('PASS: ', CheckCount, ' resource input checks');
end.
