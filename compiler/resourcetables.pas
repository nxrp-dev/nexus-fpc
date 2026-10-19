(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

unit ResourceTables;

{$mode objfpc}{$H+}

interface

uses
  Classes, ResourceCatalog;

const
  CResourceHeaderLabel = 0; { FPC_RESSYMBOL }
  CResourceRootLabel = 1;
  CResourceHandlesLabel = 2;

type
  { Target-independent FPC data layout, not an object-format writer. A compiler
    sink translates these operations into assembly items; LLVM encodes objects
    and relocations. Resource data must be writable: the RTL mutates the header
    and language nodes while allocating handles. Handles belong in zero-fill
    writable storage. Labels are local to one owning image's resource table. }
  TResourceTableSink = class
  public
    procedure BeginResources(APointerSize: Byte); virtual; abstract;
    procedure BeginHandles(APointerSize: Byte); virtual; abstract;
    procedure EmitLabel(ALabel: Integer); virtual; abstract;
    procedure EmitPointer(ALabel: Integer); virtual; abstract;
    procedure EmitOrdinal(AValue: Word); virtual; abstract;
    procedure EmitDWord(AValue: Cardinal); virtual; abstract;
    procedure EmitBytes(const AData; ACount: LongInt); virtual; abstract;
    procedure EmitAlignment(AAlignment: Byte); virtual; abstract;
    procedure EmitZeroFill(ASize: QWord); virtual; abstract;
  end;

procedure EmitResourceTables(ACatalog: TResourceCatalog;
  APointerSize: Byte; ASink: TResourceTableSink);

implementation

uses
  SysUtils;

type
  TEncodedResource = class
    Entry: TResourceEntry; { Borrowed from the catalog. }
    TypeName, ResourceName: UTF8String;
  end;

  TResourceTableNode = class
    Key: TResourceKey;
    EncodedName: UTF8String;
    Children: TList;
    Entry: TResourceEntry;
    NamedCount: Cardinal;
    NameLabel, ChildrenLabel, PayloadLabel: Integer;
    constructor Create(const AKey: TResourceKey; const AEncodedName: UTF8String);
    destructor Destroy; override;
  end;

constructor TResourceTableNode.Create(const AKey: TResourceKey;
  const AEncodedName: UTF8String);
begin
  inherited Create;
  Key := AKey;
  EncodedName := AEncodedName;
  Children := TList.Create;
end;

destructor TResourceTableNode.Destroy;
var
  LIndex: Integer;
begin
  if Children <> nil then
    for LIndex := 0 to Children.Count - 1 do TObject(Children[LIndex]).Free;
  Children.Free;
  inherited Destroy;
end;

function EncodeName(const AKey: TResourceKey; const AOrigin: string): UTF8String;
var
  LIndex: SizeInt;
  LCharacter: Word;
begin
  Result := '';
  if not AKey.IsName then Exit;
  LIndex := 1;
  while LIndex <= Length(AKey.Name) do
  begin
    LCharacter := Ord(AKey.Name[LIndex]);
    if (LCharacter >= $D800) and (LCharacter <= $DBFF) then
    begin
      Inc(LIndex);
      if (LIndex > Length(AKey.Name)) or
        (Ord(AKey.Name[LIndex]) < $DC00) or (Ord(AKey.Name[LIndex]) > $DFFF) then
        raise EResourceCatalog.CreateFmt('%s: resource identifier contains an unpaired UTF-16 surrogate', [AOrigin]);
    end
    else if (LCharacter >= $DC00) and (LCharacter <= $DFFF) then
      raise EResourceCatalog.CreateFmt('%s: resource identifier contains an unpaired UTF-16 surrogate', [AOrigin]);
    Inc(LIndex);
  end;
  Result := UTF8Encode(AKey.Name);
end;

function CompareEncodedKeys(const AFirst, ASecond: TResourceKey;
  const AFirstName, ASecondName: UTF8String): Integer;
var
  LIndex, LLimit: SizeInt;
begin
  if AFirst.IsName <> ASecond.IsName then
  begin
    if AFirst.IsName then Exit(-1) else Exit(1);
  end;
  if not AFirst.IsName then Exit(Integer(AFirst.Id) - ASecond.Id);
  LLimit := Length(AFirstName);
  if Length(ASecondName) < LLimit then LLimit := Length(ASecondName);
  for LIndex := 1 to LLimit do
  begin
    Result := Ord(AFirstName[LIndex]) - Ord(ASecondName[LIndex]);
    if Result <> 0 then Exit;
  end;
  if Length(AFirstName) < Length(ASecondName) then Result := -1
  else if Length(AFirstName) > Length(ASecondName) then Result := 1
  else Result := 0;
end;

function CompareEncodedResources(AFirst, ASecond: Pointer): Integer;
var
  LFirst, LSecond: TEncodedResource;
begin
  LFirst := TEncodedResource(AFirst);
  LSecond := TEncodedResource(ASecond);
  Result := CompareEncodedKeys(LFirst.Entry.ResourceType, LSecond.Entry.ResourceType,
    LFirst.TypeName, LSecond.TypeName);
  if Result = 0 then
    Result := CompareEncodedKeys(LFirst.Entry.Name, LSecond.Entry.Name,
      LFirst.ResourceName, LSecond.ResourceName);
  if Result = 0 then Result := Integer(LFirst.Entry.Language) - LSecond.Entry.Language;
end;

procedure EmitResourceTables(ACatalog: TResourceCatalog;
  APointerSize: Byte; ASink: TResourceTableSink);
var
  LResources: TList;
  LRoot, LType, LName, LLeaf: TResourceTableNode;
  LResource: TEncodedResource;
  LIndex, LNextLabel: Integer;
  LDataSize: QWord;

  function NewLabel: Integer;
  begin
    if LNextLabel = High(Integer) then
      raise EResourceCatalog.Create('Too many resource table labels');
    Result := LNextLabel;
    Inc(LNextLabel);
  end;

  procedure AddSize(ASize: QWord);
  begin
    if (ASize > High(QWord) - LDataSize) or
      ((APointerSize = 4) and (ASize > High(Cardinal) - LDataSize)) then
      raise EResourceCatalog.Create('Resource tables exceed the target address space');
    Inc(LDataSize, ASize);
  end;

  procedure AlignSize;
  begin
    AddSize((APointerSize - (LDataSize mod APointerSize)) mod APointerSize);
  end;

  procedure PrepareNode(ANode: TResourceTableNode);
  var
    LChild: Integer;
  begin
    AddSize(APointerSize * 2 + 8);
    if ANode.Key.IsName then ANode.NameLabel := NewLabel;
    if ANode.Entry <> nil then ANode.PayloadLabel := NewLabel
    else ANode.ChildrenLabel := NewLabel;
    for LChild := 0 to ANode.Children.Count - 1 do
      PrepareNode(TResourceTableNode(ANode.Children[LChild]));
  end;

  procedure MeasureNames(ANode: TResourceTableNode);
  var
    LChild: Integer;
  begin
    if ANode.Key.IsName then AddSize(QWord(Length(ANode.EncodedName)) + 1);
    for LChild := 0 to ANode.Children.Count - 1 do
      MeasureNames(TResourceTableNode(ANode.Children[LChild]));
  end;

  procedure MeasurePayloads(ANode: TResourceTableNode);
  var
    LChild: Integer;
  begin
    if ANode.Entry <> nil then
    begin
      AlignSize;
      AddSize(Length(ANode.Entry.Data));
    end;
    for LChild := 0 to ANode.Children.Count - 1 do
      MeasurePayloads(TResourceTableNode(ANode.Children[LChild]));
  end;

  procedure EmitNode(ANode: TResourceTableNode);
  begin
    if ANode.Key.IsName then ASink.EmitPointer(ANode.NameLabel)
    else ASink.EmitOrdinal(ANode.Key.Id);
    if ANode.Entry <> nil then
    begin
      ASink.EmitDWord(0); { Mutable resource handle, initially unallocated. }
      ASink.EmitDWord(Length(ANode.Entry.Data));
      ASink.EmitPointer(ANode.PayloadLabel);
    end
    else
    begin
      ASink.EmitDWord(ANode.NamedCount);
      ASink.EmitDWord(ANode.Children.Count - ANode.NamedCount);
      ASink.EmitPointer(ANode.ChildrenLabel);
    end;
  end;

  procedure EmitChildren(ANode: TResourceTableNode);
  var
    LChild: Integer;
    LNode: TResourceTableNode;
  begin
    if ANode.Entry <> nil then Exit;
    ASink.EmitLabel(ANode.ChildrenLabel);
    for LChild := 0 to ANode.Children.Count - 1 do
      EmitNode(TResourceTableNode(ANode.Children[LChild]));
    for LChild := 0 to ANode.Children.Count - 1 do
    begin
      LNode := TResourceTableNode(ANode.Children[LChild]);
      EmitChildren(LNode);
    end;
  end;

  procedure EmitChunks(const AData; ACount: SizeInt);
  var
    LData: PByte;
    LCount: LongInt;
  begin
    LData := @AData;
    while ACount <> 0 do
    begin
      LCount := 65536;
      if ACount < LCount then LCount := ACount;
      ASink.EmitBytes(LData^, LCount);
      Inc(LData, LCount);
      Dec(ACount, LCount);
    end;
  end;

  procedure EmitNames(ANode: TResourceTableNode);
  const
    LZero: Byte = 0;
  var
    LChild: Integer;
  begin
    if ANode.Key.IsName then
    begin
      ASink.EmitLabel(ANode.NameLabel);
      if ANode.EncodedName <> '' then
        EmitChunks(ANode.EncodedName[1], Length(ANode.EncodedName));
      ASink.EmitBytes(LZero, 1);
    end;
    for LChild := 0 to ANode.Children.Count - 1 do
      EmitNames(TResourceTableNode(ANode.Children[LChild]));
  end;

  procedure EmitPayloads(ANode: TResourceTableNode);
  var
    LChild: Integer;
  begin
    if ANode.Entry <> nil then
    begin
      ASink.EmitAlignment(APointerSize);
      ASink.EmitLabel(ANode.PayloadLabel);
      if Length(ANode.Entry.Data) <> 0 then
        EmitChunks(ANode.Entry.Data[0], Length(ANode.Entry.Data));
    end;
    for LChild := 0 to ANode.Children.Count - 1 do
      EmitPayloads(TResourceTableNode(ANode.Children[LChild]));
  end;

begin
  if (ACatalog = nil) or (ASink = nil) or not (APointerSize in [4, 8]) then
    raise EResourceCatalog.Create('Resource tables require a catalog, sink and 4- or 8-byte target pointers');
  if ACatalog.Count = 0 then Exit;
  LResources := TList.Create;
  LRoot := nil;
  try
    for LIndex := 0 to ACatalog.Count - 1 do
    begin
      LResource := TEncodedResource.Create;
      LResources.Add(LResource);
      LResource.Entry := ACatalog.Entries[LIndex];
      LResource.TypeName := EncodeName(LResource.Entry.ResourceType, LResource.Entry.Origin);
      LResource.ResourceName := EncodeName(LResource.Entry.Name, LResource.Entry.Origin);
    end;
    { The catalog sorts UTF-16 for RES. The RTL searches bytewise UTF-8, whose
      ordering differs for supplementary characters versus high BMP values. }
    LResources.Sort(@CompareEncodedResources);
    LRoot := TResourceTableNode.Create(ResourceId(0), '');
    LType := nil;
    LName := nil;
    for LIndex := 0 to LResources.Count - 1 do
    begin
      LResource := TEncodedResource(LResources[LIndex]);
      if (LType = nil) or (CompareEncodedKeys(LType.Key, LResource.Entry.ResourceType,
        LType.EncodedName, LResource.TypeName) <> 0) then
      begin
        LType := TResourceTableNode.Create(LResource.Entry.ResourceType, LResource.TypeName);
        LRoot.Children.Add(LType);
        if LType.Key.IsName then Inc(LRoot.NamedCount);
        LName := nil;
      end;
      if (LName = nil) or (CompareEncodedKeys(LName.Key, LResource.Entry.Name,
        LName.EncodedName, LResource.ResourceName) <> 0) then
      begin
        LName := TResourceTableNode.Create(LResource.Entry.Name, LResource.ResourceName);
        LType.Children.Add(LName);
        if LName.Key.IsName then Inc(LType.NamedCount);
      end;
      LLeaf := TResourceTableNode.Create(ResourceId(LResource.Entry.Language), '');
      LLeaf.Entry := LResource.Entry;
      LName.Children.Add(LLeaf);
    end;
    LNextLabel := CResourceHandlesLabel + 1;
    LDataSize := APointerSize * 2 + 8; { Packed TResHdr. }
    PrepareNode(LRoot);
    MeasureNames(LRoot);
    MeasurePayloads(LRoot);
    AlignSize;
    AddSize(QWord(ACatalog.Count) * APointerSize); { Address-space bound includes handles. }
    ASink.BeginResources(APointerSize);
    ASink.EmitLabel(CResourceHeaderLabel);
    ASink.EmitPointer(CResourceRootLabel);
    ASink.EmitDWord(ACatalog.Count);
    ASink.EmitDWord(0);
    ASink.EmitPointer(CResourceHandlesLabel);
    ASink.EmitLabel(CResourceRootLabel);
    EmitNode(LRoot);
    EmitChildren(LRoot);
    EmitNames(LRoot);
    EmitPayloads(LRoot);
    ASink.BeginHandles(APointerSize);
    ASink.EmitLabel(CResourceHandlesLabel);
    ASink.EmitZeroFill(QWord(ACatalog.Count) * APointerSize);
  finally
    LRoot.Free;
    for LIndex := 0 to LResources.Count - 1 do TObject(LResources[LIndex]).Free;
    LResources.Free;
  end;
end;

end.
