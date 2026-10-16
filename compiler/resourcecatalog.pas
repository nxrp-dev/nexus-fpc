(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit ResourceCatalog;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  EResourceCatalog = class(Exception);

  TResourceKey = record
    IsName: Boolean;
    Id: Word;
    Name: UnicodeString;
  end;

  TResourceEntry = class
  public
    ResourceType: TResourceKey;
    Name: TResourceKey;
    Language: Word;
    MemoryFlags: Word;
    DataVersion: Cardinal;
    Version: Cardinal;
    Characteristics: Cardinal;
    Data: TBytes;
    Origin: string;
  end;

  TResourceCatalog = class
  private
    FEntries: TList;
    function GetCount: Integer;
    function GetEntry(AIndex: Integer): TResourceEntry;
    function FindIndex(const AType, AName: TResourceKey;
      ALanguage: Word; out AIndex: Integer): Boolean;
    procedure MergeStrings(AExisting, AIncoming: TResourceEntry);
    procedure RebaseImages(AIncoming: TResourceCatalog);
  public
    constructor Create;
    destructor Destroy; override;
    { AddOwned takes ownership on successful return. }
    procedure AddOwned(AEntry: TResourceEntry);
    { MergeFrom transfers entries out of AIncoming. A failed merge invalidates
      both catalogs: callers must abort normalization and discard them. }
    procedure MergeFrom(AIncoming: TResourceCatalog);
    function Find(const AType, AName: TResourceKey;
      ALanguage: Word): TResourceEntry;
    procedure LoadRes(AStream: TStream; const AOrigin: string); overload;
    procedure LoadRes(const AFileName: string); overload;
    procedure SaveRes(AStream: TStream); overload;
    procedure SaveRes(const AFileName: string); overload;
    property Count: Integer read GetCount;
    property Entries[AIndex: Integer]: TResourceEntry read GetEntry; default;
  end;

function ResourceId(AId: Word): TResourceKey;
function ResourceName(const AName: UnicodeString): TResourceKey;
function CompareResourceKeys(const ALeft, ARight: TResourceKey): Integer;
function ResourceKeyText(const AKey: TResourceKey): string;
function HasResSignature(AStream: TStream): Boolean;
function ReadResourceData(AStream: TStream; const AOrigin: string): TBytes;

implementation

const
  CResSignature: array[0..31] of Byte = (
    0, 0, 0, 0, 32, 0, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

procedure Invalid(const AOrigin, AReason: string);
begin
  raise EResourceCatalog.CreateFmt('%s: %s', [AOrigin, AReason]);
end;

function ResourceId(AId: Word): TResourceKey;
begin
  Result.IsName := False;
  Result.Id := AId;
  Result.Name := '';
end;

function ResourceName(const AName: UnicodeString): TResourceKey;
var
  LIndex: SizeInt;
begin
  if (Length(AName) > High(Word)) or (Pos(WideChar(0), AName) <> 0) or
     ((Length(AName) <> 0) and (AName[1] = WideChar($FFFF))) then
    raise EResourceCatalog.Create('Invalid resource identifier');
  Result.IsName := True;
  Result.Id := 0;
  Result.Name := AName;
  { Match TResourceDesc and the runtime's ASCII case folding. Preserve all
    other UTF-16 code units rather than applying locale-dependent casing. }
  for LIndex := 1 to Length(Result.Name) do
    if (Result.Name[LIndex] >= 'a') and (Result.Name[LIndex] <= 'z') then
      Result.Name[LIndex] := WideChar(Ord(Result.Name[LIndex]) - 32);
end;

function CompareResourceKeys(const ALeft, ARight: TResourceKey): Integer;
var
  LIndex, LCount: SizeInt;
begin
  if ALeft.IsName <> ARight.IsName then
  begin
    if ALeft.IsName then Exit(-1) else Exit(1);
  end;
  if not ALeft.IsName then Exit(Integer(ALeft.Id) - Integer(ARight.Id));
  LCount := Length(ALeft.Name);
  if Length(ARight.Name) < LCount then LCount := Length(ARight.Name);
  for LIndex := 1 to LCount do
    if ALeft.Name[LIndex] <> ARight.Name[LIndex] then
      Exit(Ord(ALeft.Name[LIndex]) - Ord(ARight.Name[LIndex]));
  if Length(ALeft.Name) < Length(ARight.Name) then Exit(-1);
  if Length(ALeft.Name) > Length(ARight.Name) then Exit(1);
  Result := 0;
end;

function ResourceKeyText(const AKey: TResourceKey): string;
begin
  if AKey.IsName then Result := '"' + UTF8Encode(AKey.Name) + '"'
  else Result := '#' + IntToStr(AKey.Id);
end;

function HasResSignature(AStream: TStream): Boolean;
var
  LPosition: Int64;
  LBytes: array[0..31] of Byte;
begin
  LPosition := AStream.Position;
  try
    Result := (AStream.Read(LBytes, SizeOf(LBytes)) = SizeOf(LBytes)) and
      CompareMem(@LBytes[0], @CResSignature[0], SizeOf(LBytes));
  finally
    AStream.Position := LPosition;
  end;
end;

procedure ReadChecked(AStream: TStream; var ABuffer; ACount: SizeInt;
  ALimit: Int64; const AOrigin: string);
var
  LBuffer: PByte;
  LCount: LongInt;
begin
  if (AStream.Position < 0) or (AStream.Position > ALimit) or
     (ACount < 0) or (ACount > ALimit - AStream.Position) then
    Invalid(AOrigin, 'truncated resource record');
  LBuffer := @ABuffer;
  while ACount <> 0 do
  begin
    LCount := 65536;
    if ACount < LCount then LCount := ACount;
    AStream.ReadBuffer(LBuffer^, LCount);
    Inc(LBuffer, LCount);
    Dec(ACount, LCount);
  end;
end;

function ReadResourceData(AStream: TStream; const AOrigin: string): TBytes;
var
  LSize: Int64;
begin
  LSize := AStream.Size - AStream.Position;
  if (LSize < 0) or (QWord(LSize) > High(Cardinal)) or
     (QWord(LSize) > QWord(High(SizeInt))) then
    Invalid(AOrigin, 'invalid resource payload size');
  SetLength(Result, LSize);
  if LSize <> 0 then ReadChecked(AStream, Result[0], LSize, AStream.Size, AOrigin);
end;

procedure WriteBytes(AStream: TStream; const AData: TBytes);
var
  LPosition, LRemaining: SizeInt;
  LCount: LongInt;
begin
  LPosition := 0;
  LRemaining := Length(AData);
  while LRemaining <> 0 do
  begin
    LCount := 65536;
    if LRemaining < LCount then LCount := LRemaining;
    AStream.WriteBuffer(AData[LPosition], LCount);
    Inc(LPosition, LCount);
    Dec(LRemaining, LCount);
  end;
end;

function ReadWord(AStream: TStream; ALimit: Int64;
  const AOrigin: string): Word;
var
  LBytes: array[0..1] of Byte;
begin
  ReadChecked(AStream, LBytes, 2, ALimit, AOrigin);
  Result := Word(LBytes[0]) or (Word(LBytes[1]) shl 8);
end;

function ReadDWord(AStream: TStream; ALimit: Int64;
  const AOrigin: string): Cardinal;
var
  LBytes: array[0..3] of Byte;
begin
  ReadChecked(AStream, LBytes, 4, ALimit, AOrigin);
  Result := Cardinal(LBytes[0]) or (Cardinal(LBytes[1]) shl 8) or
    (Cardinal(LBytes[2]) shl 16) or (Cardinal(LBytes[3]) shl 24);
end;

procedure WriteWord(AStream: TStream; AValue: Word);
var
  LBytes: array[0..1] of Byte;
begin
  LBytes[0] := Byte(AValue);
  LBytes[1] := Byte(AValue shr 8);
  AStream.WriteBuffer(LBytes, 2);
end;

procedure WriteDWord(AStream: TStream; AValue: Cardinal);
begin
  WriteWord(AStream, Word(AValue));
  WriteWord(AStream, Word(AValue shr 16));
end;

procedure AlignRead(AStream: TStream; ALimit: Int64; const AOrigin: string);
var
  LPadding: LongInt;
  LBytes: array[0..2] of Byte;
begin
  LPadding := (4 - (AStream.Position and 3)) and 3;
  ReadChecked(AStream, LBytes, LPadding, ALimit, AOrigin);
end;

procedure AlignWrite(AStream: TStream);
const
  CZero: Cardinal = 0;
begin
  AStream.WriteBuffer(CZero, (4 - (AStream.Position and 3)) and 3);
end;

function ReadKey(AStream: TStream; ALimit: Int64;
  const AOrigin: string): TResourceKey;
var
  LWord: Word;
  LName: UnicodeString;
  LCount, LCapacity: Integer;
begin
  LWord := ReadWord(AStream, ALimit, AOrigin);
  if LWord = $FFFF then Exit(ResourceId(ReadWord(AStream, ALimit, AOrigin)));
  LCount := 0;
  LCapacity := 32;
  SetLength(LName, LCapacity);
  while LWord <> 0 do
  begin
    if LCount = High(Word) then Invalid(AOrigin, 'resource identifier is too long');
    if LCount = LCapacity then
    begin
      LCapacity := LCapacity * 2;
      if LCapacity > High(Word) then LCapacity := High(Word);
      SetLength(LName, LCapacity);
    end;
    Inc(LCount);
    LName[LCount] := WideChar(LWord);
    LWord := ReadWord(AStream, ALimit, AOrigin);
  end;
  SetLength(LName, LCount);
  Result := ResourceName(LName);
end;

procedure WriteKey(AStream: TStream; const AKey: TResourceKey);
var
  LIndex: SizeInt;
begin
  if not AKey.IsName then
  begin
    WriteWord(AStream, $FFFF);
    WriteWord(AStream, AKey.Id);
  end
  else
  begin
    for LIndex := 1 to Length(AKey.Name) do WriteWord(AStream, Ord(AKey.Name[LIndex]));
    WriteWord(AStream, 0);
  end;
end;

function KeySize(const AKey: TResourceKey): Cardinal;
begin
  if AKey.IsName then Result := (Length(AKey.Name) + 1) * 2
  else Result := 4;
end;

constructor TResourceCatalog.Create;
begin
  inherited Create;
  FEntries := TList.Create;
end;

destructor TResourceCatalog.Destroy;
var
  LIndex: Integer;
begin
  for LIndex := 0 to FEntries.Count - 1 do TObject(FEntries[LIndex]).Free;
  FEntries.Free;
  inherited Destroy;
end;

function TResourceCatalog.GetCount: Integer;
begin
  Result := FEntries.Count;
end;

function TResourceCatalog.GetEntry(AIndex: Integer): TResourceEntry;
begin
  Result := TResourceEntry(FEntries[AIndex]);
end;

function TResourceCatalog.FindIndex(const AType, AName: TResourceKey;
  ALanguage: Word; out AIndex: Integer): Boolean;
var
  LLow, LHigh, LMiddle, LCompare: Integer;
  LEntry: TResourceEntry;
begin
  LLow := 0;
  LHigh := Count - 1;
  while LLow <= LHigh do
  begin
    LMiddle := LLow + (LHigh - LLow) div 2;
    LEntry := Entries[LMiddle];
    LCompare := CompareResourceKeys(LEntry.ResourceType, AType);
    if LCompare = 0 then LCompare := CompareResourceKeys(LEntry.Name, AName);
    if LCompare = 0 then LCompare := Integer(LEntry.Language) - Integer(ALanguage);
    if LCompare = 0 then
    begin
      AIndex := LMiddle;
      Exit(True);
    end;
    if LCompare < 0 then LLow := LMiddle + 1 else LHigh := LMiddle - 1;
  end;
  AIndex := LLow;
  Result := False;
end;

function TResourceCatalog.Find(const AType, AName: TResourceKey;
  ALanguage: Word): TResourceEntry;
var
  LIndex: Integer;
begin
  if FindIndex(AType, AName, ALanguage, LIndex) then Result := Entries[LIndex]
  else Result := nil;
end;

procedure Duplicate(AExisting, AIncoming: TResourceEntry);
begin
  raise EResourceCatalog.CreateFmt(
    'Duplicate resource %s/%s/language %.4x in %s and %s',
    [ResourceKeyText(AIncoming.ResourceType), ResourceKeyText(AIncoming.Name),
     AIncoming.Language, AExisting.Origin, AIncoming.Origin]);
end;

type
  TStringEntries = array[0..15] of TBytes;

procedure DecodeStrings(AEntry: TResourceEntry; out AStrings: TStringEntries);
var
  LSlot, LPosition, LLength: Integer;
begin
  if AEntry.Name.IsName or (AEntry.Name.Id = 0) then
    Invalid(AEntry.Origin, 'string-table block requires a nonzero ordinal ID');
  LPosition := 0;
  for LSlot := 0 to 15 do
  begin
    if Length(AEntry.Data) - LPosition < 2 then
      Invalid(AEntry.Origin, 'truncated string-table block');
    LLength := (Integer(AEntry.Data[LPosition]) or
      (Integer(AEntry.Data[LPosition + 1]) shl 8)) * 2;
    Inc(LPosition, 2);
    if LLength > Length(AEntry.Data) - LPosition then
      Invalid(AEntry.Origin, 'truncated string-table string');
    AStrings[LSlot] := Copy(AEntry.Data, LPosition, LLength);
    Inc(LPosition, LLength);
  end;
  if LPosition <> Length(AEntry.Data) then
    Invalid(AEntry.Origin, 'extra data after string-table block');
end;

procedure TResourceCatalog.MergeStrings(AExisting, AIncoming: TResourceEntry);
var
  LOld, LNew: TStringEntries;
  LIndex, LLength, LTotal, LOffset: Integer;
  LData: TBytes;
begin
  DecodeStrings(AExisting, LOld);
  DecodeStrings(AIncoming, LNew);
  LTotal := 32;
  for LIndex := 0 to 15 do
  begin
    if (Length(LOld[LIndex]) <> 0) and (Length(LNew[LIndex]) <> 0) then
      Duplicate(AExisting, AIncoming);
    if Length(LNew[LIndex]) <> 0 then LOld[LIndex] := LNew[LIndex];
    Inc(LTotal, Length(LOld[LIndex]));
  end;
  SetLength(LData, LTotal);
  LOffset := 0;
  for LIndex := 0 to 15 do
  begin
    LLength := Length(LOld[LIndex]);
    LData[LOffset] := Byte(LLength div 2);
    LData[LOffset + 1] := Byte((LLength div 2) shr 8);
    Inc(LOffset, 2);
    if LLength <> 0 then Move(LOld[LIndex][0], LData[LOffset], LLength);
    Inc(LOffset, LLength);
  end;
  AExisting.Data := LData;
end;

procedure TResourceCatalog.AddOwned(AEntry: TResourceEntry);
var
  LIndex: Integer;
  LExisting: TResourceEntry;
  LStrings: TStringEntries;
begin
  if AEntry.ResourceType.IsName then
    AEntry.ResourceType := ResourceName(AEntry.ResourceType.Name);
  if AEntry.Name.IsName then AEntry.Name := ResourceName(AEntry.Name.Name);
  if QWord(Length(AEntry.Data)) > High(Cardinal) then
    Invalid(AEntry.Origin, 'resource payload exceeds the RES size limit');
  if not AEntry.ResourceType.IsName and (AEntry.ResourceType.Id = 6) then
    DecodeStrings(AEntry, LStrings);
  if FindIndex(AEntry.ResourceType, AEntry.Name, AEntry.Language, LIndex) then
  begin
    LExisting := Entries[LIndex];
    if not AEntry.ResourceType.IsName and (AEntry.ResourceType.Id = 6) then
      MergeStrings(LExisting, AEntry)
    else Duplicate(LExisting, AEntry);
    AEntry.Free;
  end
  else FEntries.Insert(LIndex, AEntry);
end;

procedure TResourceCatalog.RebaseImages(AIncoming: TResourceCatalog);
type
  TImageReference = record
    Group: TResourceEntry;
    Child: TResourceEntry;
    Offset: Integer;
  end;
  TImageMapping = record
    Child: TResourceEntry;
    NewId: Word;
  end;
  TIdMap = array of Boolean;
var
  LReferences: array of TImageReference;
  LMappings: array of TImageMapping;
  LUsedIcons, LUsedCursors: TIdMap;
  LIndex, LItem, LCount, LOffset, LRefCount, LMapCount, LMap: Integer;
  LType, LId: Word;
  LGroup, LChild, LEntry: TResourceEntry;
  LSize: Cardinal;

  function DataWord(AEntry: TResourceEntry; AOffset: Integer): Word;
  begin
    if (AOffset < 0) or (Length(AEntry.Data) - AOffset < 2) then
      Invalid(AEntry.Origin, 'truncated icon/cursor group');
    Result := Word(AEntry.Data[AOffset]) or (Word(AEntry.Data[AOffset + 1]) shl 8);
  end;

  procedure MarkIds(ACatalog: TResourceCatalog);
  var
    LItem: Integer;
    LEntry: TResourceEntry;
  begin
    for LItem := 0 to ACatalog.Count - 1 do
    begin
      LEntry := ACatalog[LItem];
      if LEntry.ResourceType.IsName or LEntry.Name.IsName then Continue;
      case LEntry.ResourceType.Id of
        1: LUsedCursors[LEntry.Name.Id] := True;
        3: LUsedIcons[LEntry.Name.Id] := True;
      end;
    end;
  end;

  function IdInUse(ACatalog: TResourceCatalog; AType, AId: Word): Boolean;
  var
    LItem: Integer;
    LEntry: TResourceEntry;
  begin
    for LItem := 0 to ACatalog.Count - 1 do
    begin
      LEntry := ACatalog[LItem];
      if not LEntry.ResourceType.IsName and not LEntry.Name.IsName and
         (LEntry.ResourceType.Id = AType) and (LEntry.Name.Id = AId) then Exit(True);
    end;
    Result := False;
  end;

  function FreeId(var AUsed: TIdMap; const AOrigin: string): Word;
  var
    LId: Integer;
  begin
    for LId := 1 to High(Word) do
      if not AUsed[LId] then
      begin
        AUsed[LId] := True;
        Exit(LId);
      end;
    Invalid(AOrigin, 'no free icon/cursor resource IDs');
    Result := 0;
  end;

begin
  LRefCount := 0;
  for LIndex := 0 to AIncoming.Count - 1 do
  begin
    LGroup := AIncoming[LIndex];
    if LGroup.ResourceType.IsName or
       not (LGroup.ResourceType.Id in [12, 14]) then Continue;
    if LGroup.ResourceType.Id = 14 then LType := 3 else LType := 1;
    if (DataWord(LGroup, 0) <> 0) or
       (DataWord(LGroup, 2) <> (2 - Ord(LType = 3))) then
      Invalid(LGroup.Origin, 'invalid icon/cursor group header');
    LCount := DataWord(LGroup, 4);
    if Length(LGroup.Data) <> 6 + LCount * 14 then
      Invalid(LGroup.Origin, 'invalid icon/cursor group size');
    SetLength(LReferences, LRefCount + LCount);
    for LItem := 0 to LCount - 1 do
    begin
      LOffset := 6 + LItem * 14;
      LId := DataWord(LGroup, LOffset + 12);
      LChild := AIncoming.Find(ResourceId(LType), ResourceId(LId), LGroup.Language);
      if LChild = nil then Invalid(LGroup.Origin, 'missing icon/cursor group image');
      LSize := Cardinal(DataWord(LGroup, LOffset + 8)) or
        (Cardinal(DataWord(LGroup, LOffset + 10)) shl 16);
      if LSize <> Cardinal(Length(LChild.Data)) then
        Invalid(LGroup.Origin, 'icon/cursor image size does not match its group');
      LReferences[LRefCount].Group := LGroup;
      LReferences[LRefCount].Child := LChild;
      LReferences[LRefCount].Offset := LOffset + 12;
      Inc(LRefCount);
    end;
  end;
  if LRefCount = 0 then Exit;
  SetLength(LUsedIcons, 65536);
  SetLength(LUsedCursors, 65536);
  MarkIds(Self);
  MarkIds(AIncoming);
  SetLength(LMappings, LRefCount);
  LMapCount := 0;
  for LIndex := 0 to LRefCount - 1 do
  begin
    LChild := LReferences[LIndex].Child;
    LMap := 0;
    while (LMap < LMapCount) and (LMappings[LMap].Child <> LChild) do Inc(LMap);
    if LMap <> LMapCount then Continue;
    LId := LChild.Name.Id;
    if IdInUse(Self, LChild.ResourceType.Id, LId) then
    begin
      if LChild.ResourceType.Id = 3 then LId := FreeId(LUsedIcons, LChild.Origin)
      else LId := FreeId(LUsedCursors, LChild.Origin);
    end;
    LMappings[LMapCount].Child := LChild;
    LMappings[LMapCount].NewId := LId;
    Inc(LMapCount);
  end;
  for LMap := 0 to LMapCount - 1 do
    LMappings[LMap].Child.Name := ResourceId(LMappings[LMap].NewId);
  for LIndex := 0 to LRefCount - 1 do
    for LMap := 0 to LMapCount - 1 do
      if LMappings[LMap].Child = LReferences[LIndex].Child then
      begin
        LEntry := LReferences[LIndex].Group;
        LOffset := LReferences[LIndex].Offset;
        LEntry.Data[LOffset] := Byte(LMappings[LMap].NewId);
        LEntry.Data[LOffset + 1] := Byte(LMappings[LMap].NewId shr 8);
        Break;
      end;
end;

procedure TResourceCatalog.MergeFrom(AIncoming: TResourceCatalog);
var
  LEntry: TResourceEntry;
begin
  if AIncoming = Self then raise EResourceCatalog.Create('Cannot merge a resource catalog into itself');
  RebaseImages(AIncoming);
  while AIncoming.Count <> 0 do
  begin
    LEntry := AIncoming[AIncoming.Count - 1];
    AIncoming.FEntries.Delete(AIncoming.Count - 1);
    try
      AddOwned(LEntry);
    except
      LEntry.Free;
      raise;
    end;
  end;
end;

procedure TResourceCatalog.LoadRes(AStream: TStream; const AOrigin: string);
var
  LIncoming: TResourceCatalog;
  LEntry: TResourceEntry;
  LStart, LHeaderEnd, LEnd: Int64;
  LDataSize, LHeaderSize: Cardinal;
begin
  if not HasResSignature(AStream) then Invalid(AOrigin, 'invalid Win32 RES signature');
  AStream.Position := AStream.Position + SizeOf(CResSignature);
  LIncoming := TResourceCatalog.Create;
  try
    LEnd := AStream.Size;
    while AStream.Position < LEnd do
    begin
      LStart := AStream.Position;
      LDataSize := ReadDWord(AStream, LEnd, AOrigin);
      LHeaderSize := ReadDWord(AStream, LEnd, AOrigin);
      if (LHeaderSize < 28) or (LHeaderSize > LEnd - LStart) then
        Invalid(AOrigin, 'invalid resource header size');
      LHeaderEnd := LStart + LHeaderSize;
      LEntry := TResourceEntry.Create;
      try
        LEntry.Origin := AOrigin;
        LEntry.ResourceType := ReadKey(AStream, LHeaderEnd - 16, AOrigin);
        LEntry.Name := ReadKey(AStream, LHeaderEnd - 16, AOrigin);
        AlignRead(AStream, LHeaderEnd - 16, AOrigin);
        LEntry.DataVersion := ReadDWord(AStream, LHeaderEnd, AOrigin);
        LEntry.MemoryFlags := ReadWord(AStream, LHeaderEnd, AOrigin);
        LEntry.Language := ReadWord(AStream, LHeaderEnd, AOrigin);
        LEntry.Version := ReadDWord(AStream, LHeaderEnd, AOrigin);
        LEntry.Characteristics := ReadDWord(AStream, LHeaderEnd, AOrigin);
        if AStream.Position <> LHeaderEnd then Invalid(AOrigin, 'invalid resource header extent');
        if (QWord(LDataSize) > QWord(High(SizeInt))) or
           (LDataSize > LEnd - AStream.Position) then
          Invalid(AOrigin, 'invalid resource payload size');
        SetLength(LEntry.Data, LDataSize);
        if LDataSize <> 0 then
          ReadChecked(AStream, LEntry.Data[0], LDataSize, LEnd, AOrigin);
        AlignRead(AStream, LEnd, AOrigin);
        LIncoming.AddOwned(LEntry);
        LEntry := nil;
      finally
        LEntry.Free;
      end;
    end;
    MergeFrom(LIncoming);
  finally
    LIncoming.Free;
  end;
end;

procedure TResourceCatalog.LoadRes(const AFileName: string);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadRes(LStream, AFileName);
  finally
    LStream.Free;
  end;
end;

procedure TResourceCatalog.SaveRes(AStream: TStream);
var
  LIndex: Integer;
  LEntry: TResourceEntry;
  LHeaderSize: Cardinal;
begin
  AStream.WriteBuffer(CResSignature, SizeOf(CResSignature));
  for LIndex := 0 to Count - 1 do
  begin
    LEntry := Entries[LIndex];
    LHeaderSize := (8 + KeySize(LEntry.ResourceType) + KeySize(LEntry.Name) + 3) and not Cardinal(3);
    Inc(LHeaderSize, 16);
    WriteDWord(AStream, Length(LEntry.Data));
    WriteDWord(AStream, LHeaderSize);
    WriteKey(AStream, LEntry.ResourceType);
    WriteKey(AStream, LEntry.Name);
    AlignWrite(AStream);
    WriteDWord(AStream, LEntry.DataVersion);
    WriteWord(AStream, LEntry.MemoryFlags);
    WriteWord(AStream, LEntry.Language);
    WriteDWord(AStream, LEntry.Version);
    WriteDWord(AStream, LEntry.Characteristics);
    WriteBytes(AStream, LEntry.Data);
    AlignWrite(AStream);
  end;
end;

procedure TResourceCatalog.SaveRes(const AFileName: string);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    SaveRes(LStream);
  finally
    LStream.Free;
  end;
end;

end.
