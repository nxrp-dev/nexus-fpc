program NXResourceTablesTests;

{$mode objfpc}{$H+}{$codepage UTF8}

uses
  {$ifdef unix}CWString,{$endif}
  Classes, SysUtils, ResourceCatalog, ResourceTables;

type
  TAssemblySink = class(TResourceTableSink)
  private
    FPointerSize: Byte;
    FDirectory: string;
    FText: TStringList;
    FChunkCount: Integer;
    FHandleLabel: string;
    FInHandles, FMachO: Boolean;
    function LabelName(ALabel: Integer): string;
  public
    Begins, MaximumChunk: Integer;
    constructor Create(const ADirectory: string; AMachO: Boolean);
    destructor Destroy; override;
    procedure BeginResources(APointerSize: Byte); override;
    procedure BeginHandles(APointerSize: Byte); override;
    procedure EmitLabel(ALabel: Integer); override;
    procedure EmitPointer(ALabel: Integer); override;
    procedure EmitOrdinal(AValue: Word); override;
    procedure EmitDWord(AValue: Cardinal); override;
    procedure EmitBytes(const AData; ACount: LongInt); override;
    procedure EmitAlignment(AAlignment: Byte); override;
    procedure EmitZeroFill(ASize: QWord); override;
    procedure Save;
  end;

var
  CheckCount: Integer;
  ArtifactRoot: string;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(CheckCount);
  if not ACondition then raise Exception.Create(AMessage);
end;

constructor TAssemblySink.Create(const ADirectory: string; AMachO: Boolean);
begin
  inherited Create;
  FDirectory := IncludeTrailingPathDelimiter(ADirectory);
  ForceDirectories(FDirectory);
  FMachO := AMachO;
  FText := TStringList.Create;
end;

destructor TAssemblySink.Destroy;
begin
  FText.Free;
  inherited Destroy;
end;

function TAssemblySink.LabelName(ALabel: Integer): string;
begin
  if ALabel = CResourceHeaderLabel then Result := 'FPC_RESSYMBOL'
  else Result := 'NXRTable' + IntToStr(ALabel);
end;

procedure TAssemblySink.BeginResources(APointerSize: Byte);
begin
  Inc(Begins);
  FPointerSize := APointerSize;
  FInHandles := False;
  if FMachO then FText.Add('.section __DATA,fpc.resources,regular,no_dead_strip')
  else FText.Add('.section fpc.resources,"aw",@progbits');
  EmitAlignment(APointerSize);
  FText.Add('.globl FPC_RESSYMBOL');
end;

procedure TAssemblySink.BeginHandles(APointerSize: Byte);
begin
  Check(APointerSize = FPointerSize, 'Handle pointer width changed');
  FInHandles := True;
  if not FMachO then
  begin
    FText.Add('.section fpc.reshandles,"aw",@nobits');
    EmitAlignment(APointerSize);
  end;
end;

procedure TAssemblySink.EmitLabel(ALabel: Integer);
begin
  if FInHandles and FMachO then FHandleLabel := LabelName(ALabel)
  else FText.Add(LabelName(ALabel) + ':');
end;

procedure TAssemblySink.EmitPointer(ALabel: Integer);
begin
  if FPointerSize = 4 then FText.Add('.long ' + LabelName(ALabel))
  else FText.Add('.quad ' + LabelName(ALabel));
end;

procedure TAssemblySink.EmitOrdinal(AValue: Word);
begin
  if FPointerSize = 4 then FText.Add('.long ' + IntToStr(AValue))
  else FText.Add('.quad ' + IntToStr(AValue));
end;

procedure TAssemblySink.EmitDWord(AValue: Cardinal);
begin
  FText.Add('.long ' + IntToStr(AValue));
end;

procedure TAssemblySink.EmitBytes(const AData; ACount: LongInt);
var
  LFileName: string;
  LStream: TFileStream;
begin
  Check((ACount > 0) and (ACount <= 65536), 'Unbounded table byte emission');
  if ACount > MaximumChunk then MaximumChunk := ACount;
  Inc(FChunkCount);
  LFileName := FDirectory + 'chunk-' + IntToStr(FChunkCount) + '.bin';
  LStream := TFileStream.Create(LFileName, fmCreate);
  try
    LStream.WriteBuffer(AData, ACount);
  finally
    LStream.Free;
  end;
  FText.Add('.incbin "' + LFileName + '"');
end;

procedure TAssemblySink.EmitAlignment(AAlignment: Byte);
begin
  FText.Add('.balign ' + IntToStr(AAlignment));
end;

procedure TAssemblySink.EmitZeroFill(ASize: QWord);
var
  LPower: Integer;
begin
  Check(FInHandles, 'Zero-fill outside handle storage');
  if FMachO then
  begin
    if FPointerSize = 4 then LPower := 2 else LPower := 3;
    FText.Add('.zerofill __DATA,fpc.reshandles,' + FHandleLabel + ',' +
      UIntToStr(ASize) + ',' + IntToStr(LPower));
  end
  else FText.Add('.zero ' + UIntToStr(ASize));
end;

procedure TAssemblySink.Save;
begin
  if not FMachO then
  begin
    { This exported location lets the existing RTL read a standalone test SO.
      In compiler integration InsertResourceInfo owns FPC_RESLOCATION. }
    FText.Add('.data');
    EmitAlignment(FPointerSize);
    FText.Add('.globl FPC_RESLOCATION');
    FText.Add('FPC_RESLOCATION:');
    EmitPointer(CResourceHeaderLabel);
    FText.Add('.section .note.GNU-stack,"",@progbits');
  end;
  FText.SaveToFile(FDirectory + 'tables.s');
end;

procedure AddResource(ACatalog: TResourceCatalog; const AType, AName: TResourceKey;
  ALanguage: Word; const AData: RawByteString);
var
  LEntry: TResourceEntry;
begin
  LEntry := TResourceEntry.Create;
  try
    LEntry.ResourceType := AType;
    LEntry.Name := AName;
    LEntry.Language := ALanguage;
    LEntry.MemoryFlags := $1010;
    LEntry.Origin := 'table-layout fixture';
    SetLength(LEntry.Data, Length(AData));
    if AData <> '' then Move(AData[1], LEntry.Data[0], Length(AData));
    ACatalog.AddOwned(LEntry);
    LEntry := nil;
  finally
    LEntry.Free;
  end;
end;

procedure TestLayouts;
var
  LCatalog: TResourceCatalog;
  LSink: TAssemblySink;
  LIndex: Integer;
  LPointerSize: Byte;
  LName, LDirectory: string;
begin
  LCatalog := TResourceCatalog.Create;
  try
    AddResource(LCatalog, ResourceId(10), ResourceId(1), 1033, 'english');
    AddResource(LCatalog, ResourceId(10), ResourceId(1), 1041, 'japanese');
    AddResource(LCatalog, ResourceId(10), ResourceName('1'), 0, 'named one');
    AddResource(LCatalog, ResourceId(10), ResourceName('ALPHA'), 0, 'alpha');
    AddResource(LCatalog, ResourceId(10), ResourceName(WideChar($E000)), 0, 'high BMP');
    AddResource(LCatalog, ResourceId(10),
      ResourceName(WideChar($D800) + WideChar($DC00)), 0, 'supplementary');
    AddResource(LCatalog, ResourceName('雪'), ResourceName('café'), 1033, 'unicode type');
    AddResource(LCatalog, ResourceName('10'), ResourceId(1), 0, 'named type');
    AddResource(LCatalog, ResourceId(65535), ResourceId(65535), 65535, #0#$FF'edge');
    AddResource(LCatalog, ResourceId(10), ResourceId(4), 0, StringOfChar('z', 150001));
    AddResource(LCatalog, ResourceId(10), ResourceId(5), 0, '');
    if ParamCount = 2 then LCatalog.LoadRes(ParamStr(2));
    LCatalog.SaveRes(ArtifactRoot + 'tables.res');
    for LIndex := 0 to 2 do
    begin
      case LIndex of
        0: begin LName := 'elf32'; LPointerSize := 4; end;
        1: begin LName := 'elf64'; LPointerSize := 8; end;
        2: begin LName := 'macho64'; LPointerSize := 8; end;
      end;
      LDirectory := ArtifactRoot + LName;
      LSink := TAssemblySink.Create(LDirectory, LIndex = 2);
      try
        EmitResourceTables(LCatalog, LPointerSize, LSink);
        Check(LSink.Begins = 1, 'Missing resource table');
        Check(LSink.MaximumChunk = 65536, 'Large payload was not emitted in bounded chunks');
        LSink.Save;
      finally
        LSink.Free;
      end;
    end;
  finally
    LCatalog.Free;
  end;
end;

procedure TestRejectedNames;
var
  LCatalog: TResourceCatalog;
  LSink: TAssemblySink;
  LIndex: Integer;
  LRaised: Boolean;
  LName: UnicodeString;
begin
  for LIndex := 0 to 2 do
  begin
    if LIndex = 0 then LName := WideChar($D800)
    else if LIndex = 1 then LName := WideChar($DC00)
    else LName := WideChar($D800) + WideChar($E000);
    LCatalog := TResourceCatalog.Create;
    LSink := TAssemblySink.Create(ArtifactRoot + 'invalid', False);
    try
      AddResource(LCatalog, ResourceId(10), ResourceName(LName), 0, 'invalid');
      LRaised := False;
      try
        EmitResourceTables(LCatalog, 8, LSink);
      except
        on E: EResourceCatalog do
        begin
          LRaised := True;
          Check(Pos('unpaired UTF-16 surrogate', E.Message) <> 0, 'Unclear identifier diagnostic');
        end;
      end;
      Check(LRaised, 'Lossy UTF-16 identifier conversion was accepted');
      Check(LSink.Begins = 0, 'Invalid identifiers emitted a partial resource table');
    finally
      LSink.Free;
      LCatalog.Free;
    end;
  end;
end;

procedure TestEmpty;
var
  LCatalog: TResourceCatalog;
  LSink: TAssemblySink;
  LRaised: Boolean;
begin
  LCatalog := TResourceCatalog.Create;
  LSink := TAssemblySink.Create(ArtifactRoot + 'empty', False);
  try
    EmitResourceTables(LCatalog, 8, LSink);
    Check(LSink.Begins = 0, 'Resource-free image emitted a table');
    LRaised := False;
    try
      EmitResourceTables(LCatalog, 3, LSink);
    except
      on E: EResourceCatalog do LRaised := True;
    end;
    Check(LRaised, 'Unsupported pointer width was accepted');
  finally
    LSink.Free;
    LCatalog.Free;
  end;
end;

begin
  if not (ParamCount in [1, 2]) then
  begin
    WriteLn(StdErr, 'Usage: nxResourceTablesTests <artifact-root> [version-info.res]');
    Halt(2);
  end;
  ArtifactRoot := IncludeTrailingPathDelimiter(ExpandFileName(ParamStr(1)));
  TestLayouts;
  TestRejectedNames;
  TestEmpty;
  WriteLn('PASS: ', CheckCount, ' resource table layout checks');
end.
