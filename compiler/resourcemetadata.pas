(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit ResourceMetadata;

{$mode objfpc}{$H+}

interface

uses
  Classes, ResourceCatalog, ResourceArtifacts, ResourceTools;

type
  { Keep the compiled-unit bridge independent of RTL container name imports. }
  TResourceMetadataStream = TMemoryStream;

  { Persist input provenance and RC configuration with each compiled unit.
    Tool executable paths are invocation settings, not distributed-unit data.
    ArtifactFile is always a basename relative to the unit's installed path. }
  TModuleResourceInput = class
  public
    OriginalPath: string;
    DirectiveFile: string;
    DirectiveLine: Cardinal;
    ArtifactFile: string;
    Kind: TResourceInputKind;
    TargetTriple: string;
    CodePage: Cardinal;
    IncludeDirectories: TStringList;
    MacroArguments: TStringList;
    { Invocation state, never serialized. }
    PendingCatalog: TResourceCatalog;
    PendingStage: TResourceArtifactStage;
    ScratchPrefix: string;
    constructor Create;
    destructor Destroy; override;
    procedure CaptureConfiguration(ATools: TLLVMResourceCompiler);
    procedure ConfigureCompiler(ATools: TLLVMResourceCompiler);
  end;

  TModuleResourceInputs = class
  private
    FItems: TList;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TModuleResourceInput;
    procedure Validate;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddOwned(AInput: TModuleResourceInput);
    procedure SaveToStream(AStream: TStream);
    { A failed read leaves the previous list intact. }
    procedure LoadFromStream(AStream: TStream);
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TModuleResourceInput read GetItem; default;
  end;

implementation

uses
  SysUtils;

const
  CResourceMetadataMagic: array[0..3] of AnsiChar = ('N', 'X', 'R', 'M');
  CResourceMetadataVersion = 1;

procedure InvalidMetadata(const AReason: string);
begin
  raise EResourceCatalog.Create('Invalid compiled-unit resource metadata: ' + AReason);
end;

constructor TModuleResourceInput.Create;
begin
  inherited Create;
  CodePage := 65001;
  IncludeDirectories := TStringList.Create;
  MacroArguments := TStringList.Create;
end;

destructor TModuleResourceInput.Destroy;
begin
  PendingStage.Free;
  PendingCatalog.Free;
  if ScratchPrefix <> '' then
  begin
    DeleteFile(ScratchPrefix + '.rc.i');
    DeleteFile(ScratchPrefix + '.rc.d');
    DeleteFile(ScratchPrefix + '.raw.res');
    DeleteFile(ScratchPrefix);
  end;
  MacroArguments.Free;
  IncludeDirectories.Free;
  inherited Destroy;
end;

procedure TModuleResourceInput.CaptureConfiguration(ATools: TLLVMResourceCompiler);
begin
  TargetTriple := ATools.TargetTriple;
  CodePage := ATools.CodePage;
  IncludeDirectories.Assign(ATools.IncludeDirectories);
  MacroArguments.Assign(ATools.MacroArguments);
end;

procedure TModuleResourceInput.ConfigureCompiler(ATools: TLLVMResourceCompiler);
begin
  { The caller selects current tool paths and the actual target. It must check
    TargetTriple before consuming a source-hidden unit's existing artifact. }
  ATools.CodePage := CodePage;
  ATools.IncludeDirectories.Assign(IncludeDirectories);
  ATools.MacroArguments.Assign(MacroArguments);
end;

constructor TModuleResourceInputs.Create;
begin
  inherited Create;
  FItems := TList.Create;
end;

destructor TModuleResourceInputs.Destroy;
var
  LIndex: Integer;
begin
  if FItems <> nil then
    for LIndex := 0 to FItems.Count - 1 do TObject(FItems[LIndex]).Free;
  FItems.Free;
  inherited Destroy;
end;

function TModuleResourceInputs.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TModuleResourceInputs.GetItem(AIndex: Integer): TModuleResourceInput;
begin
  Result := TModuleResourceInput(FItems[AIndex]);
end;

procedure TModuleResourceInputs.AddOwned(AInput: TModuleResourceInput);
begin
  if AInput = nil then InvalidMetadata('nil resource input');
  FItems.Add(AInput);
end;

procedure TModuleResourceInputs.Validate;
var
  LIndex, LOther, LArgument: Integer;
  LInput: TModuleResourceInput;
  LName: string;

  procedure CheckText(const AValue: string);
  begin
    if Pos(#0, AValue) <> 0 then InvalidMetadata('NUL byte in text field');
  end;

begin
  for LIndex := 0 to Count - 1 do
  begin
    LInput := Items[LIndex];
    CheckText(LInput.OriginalPath);
    CheckText(LInput.DirectiveFile);
    CheckText(LInput.ArtifactFile);
    CheckText(LInput.TargetTriple);
    if (LInput.OriginalPath = '') or (LInput.TargetTriple = '') or
       (LInput.CodePage = 0) then InvalidMetadata('missing input configuration');
    LName := LInput.ArtifactFile;
    if (Length(LName) <= 4) or (Pos('/', LName) <> 0) or
       (Pos('\', LName) <> 0) or (Pos(':', LName) <> 0) or
       (LowerCase(ExtractFileExt(LName)) <> '.res') then
      InvalidMetadata('resource artifact must be a RES basename');
    if (Ord(LInput.Kind) < Ord(Low(TResourceInputKind))) or
       (Ord(LInput.Kind) > Ord(High(TResourceInputKind))) then
      InvalidMetadata('unknown input format');
    for LOther := 0 to LIndex - 1 do
      if CompareText(Items[LOther].ArtifactFile, LName) = 0 then
        InvalidMetadata('duplicate artifact basename');
    for LArgument := 0 to LInput.IncludeDirectories.Count - 1 do
      CheckText(LInput.IncludeDirectories[LArgument]);
    for LArgument := 0 to LInput.MacroArguments.Count - 1 do
    begin
      LName := LInput.MacroArguments[LArgument];
      CheckText(LName);
      if (Length(LName) < 3) or
         ((Copy(LName, 1, 2) <> '-D') and (Copy(LName, 1, 2) <> '-U')) then
        InvalidMetadata('unknown resource macro argument');
    end;
  end;
end;

procedure WriteCardinal(AStream: TStream; AValue: Cardinal);
var
  LBytes: array[0..3] of Byte;
  LIndex: Integer;
begin
  for LIndex := 0 to 3 do LBytes[LIndex] := (AValue shr (LIndex * 8)) and $FF;
  AStream.WriteBuffer(LBytes, SizeOf(LBytes));
end;

procedure WriteText(AStream: TStream; const AValue: string);
var
  LOffset: SizeInt;
  LCount: LongInt;
begin
  if QWord(Length(AValue)) > High(Cardinal) then InvalidMetadata('text field is too large');
  WriteCardinal(AStream, Length(AValue));
  LOffset := 1;
  while LOffset <= Length(AValue) do
  begin
    LCount := 65536;
    if Length(AValue) - LOffset + 1 < LCount then LCount := Length(AValue) - LOffset + 1;
    AStream.WriteBuffer(AValue[LOffset], LCount);
    Inc(LOffset, LCount);
  end;
end;

procedure WriteStrings(AStream: TStream; AValues: TStrings);
var
  LIndex: Integer;
begin
  WriteCardinal(AStream, AValues.Count);
  for LIndex := 0 to AValues.Count - 1 do WriteText(AStream, AValues[LIndex]);
end;

procedure TModuleResourceInputs.SaveToStream(AStream: TStream);
var
  LIndex: Integer;
  LInput: TModuleResourceInput;
begin
  Validate;
  AStream.WriteBuffer(CResourceMetadataMagic, SizeOf(CResourceMetadataMagic));
  WriteCardinal(AStream, CResourceMetadataVersion);
  WriteCardinal(AStream, Count);
  for LIndex := 0 to Count - 1 do
  begin
    LInput := Items[LIndex];
    WriteText(AStream, LInput.OriginalPath);
    WriteText(AStream, LInput.DirectiveFile);
    WriteCardinal(AStream, LInput.DirectiveLine);
    WriteText(AStream, LInput.ArtifactFile);
    WriteCardinal(AStream, Ord(LInput.Kind));
    WriteText(AStream, LInput.TargetTriple);
    WriteCardinal(AStream, LInput.CodePage);
    WriteStrings(AStream, LInput.IncludeDirectories);
    WriteStrings(AStream, LInput.MacroArguments);
  end;
end;

procedure ReadChecked(AStream: TStream; var AData; ASize: LongInt);
begin
  if (AStream.Position < 0) or (AStream.Position > AStream.Size) or
     (ASize > AStream.Size - AStream.Position) then InvalidMetadata('truncated data');
  AStream.ReadBuffer(AData, ASize);
end;

function ReadCardinal(AStream: TStream): Cardinal;
var
  LBytes: array[0..3] of Byte;
begin
  ReadChecked(AStream, LBytes, SizeOf(LBytes));
  Result := Cardinal(LBytes[0]) or (Cardinal(LBytes[1]) shl 8) or
    (Cardinal(LBytes[2]) shl 16) or (Cardinal(LBytes[3]) shl 24);
end;

function ReadText(AStream: TStream): string;
var
  LSize: Cardinal;
  LOffset: SizeInt;
  LCount: LongInt;
begin
  LSize := ReadCardinal(AStream);
  if (QWord(LSize) > QWord(High(SizeInt))) or
     (LSize > AStream.Size - AStream.Position) then InvalidMetadata('invalid text length');
  SetLength(Result, LSize);
  LOffset := 1;
  while LOffset <= Length(Result) do
  begin
    LCount := 65536;
    if Length(Result) - LOffset + 1 < LCount then LCount := Length(Result) - LOffset + 1;
    ReadChecked(AStream, Result[LOffset], LCount);
    Inc(LOffset, LCount);
  end;
end;

procedure ReadStrings(AStream: TStream; AValues: TStrings);
var
  LCount, LIndex: Cardinal;
begin
  LCount := ReadCardinal(AStream);
  if (LCount > Cardinal(High(Integer))) or
     (LCount > (AStream.Size - AStream.Position) div 4) then
    InvalidMetadata('invalid argument count');
  LIndex := 0;
  while LIndex < LCount do
  begin
    AValues.Add(ReadText(AStream));
    Inc(LIndex);
  end;
end;

procedure TModuleResourceInputs.LoadFromStream(AStream: TStream);
var
  LMagic: array[0..3] of AnsiChar;
  LNew: TModuleResourceInputs;
  LOldItems: TList;
  LInput: TModuleResourceInput;
  LCount, LIndex, LKind: Cardinal;
begin
  ReadChecked(AStream, LMagic, SizeOf(LMagic));
  if LMagic <> CResourceMetadataMagic then InvalidMetadata('wrong signature');
  if ReadCardinal(AStream) <> CResourceMetadataVersion then InvalidMetadata('unknown version');
  LCount := ReadCardinal(AStream);
  { Each record contains at least nine cardinal-sized fields, even with empty
    strings/lists. Check the count before allocating objects. }
  if (LCount > Cardinal(High(Integer))) or
     (LCount > (AStream.Size - AStream.Position) div 36) then
    InvalidMetadata('invalid input count');
  LNew := TModuleResourceInputs.Create;
  try
    LIndex := 0;
    while LIndex < LCount do
    begin
      LInput := TModuleResourceInput.Create;
      LNew.AddOwned(LInput);
      LInput.OriginalPath := ReadText(AStream);
      LInput.DirectiveFile := ReadText(AStream);
      LInput.DirectiveLine := ReadCardinal(AStream);
      LInput.ArtifactFile := ReadText(AStream);
      LKind := ReadCardinal(AStream);
      if LKind > Ord(High(TResourceInputKind)) then InvalidMetadata('unknown input format');
      LInput.Kind := TResourceInputKind(LKind);
      LInput.TargetTriple := ReadText(AStream);
      LInput.CodePage := ReadCardinal(AStream);
      ReadStrings(AStream, LInput.IncludeDirectories);
      ReadStrings(AStream, LInput.MacroArguments);
      Inc(LIndex);
    end;
    if AStream.Position <> AStream.Size then InvalidMetadata('trailing data');
    LNew.Validate;
    LOldItems := FItems;
    FItems := LNew.FItems;
    LNew.FItems := LOldItems;
  finally
    LNew.Free;
  end;
end;

end.
