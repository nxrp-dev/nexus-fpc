program NXResourceTableReaderTests;

{$mode objfpc}{$H+}

uses
  {$ifdef unix}CWString,{$endif}
  Classes, SysUtils, ResourceCatalog, Resource, ElfReader, ElfTypes, ElfConsts, MachOReader;

var
  LExpected: TResourceCatalog;
  LStream: TFileStream;
  LFile: Integer;

function Key(ADescription: TResourceDesc): TResourceKey;
begin
  if ADescription.DescType = dtName then
    Result := ResourceName(UTF8Decode(ADescription.Name))
  else
  begin
    if ADescription.ID > High(Word) then raise Exception.Create('Unexpected large resource ID');
    Result := ResourceId(ADescription.ID);
  end;
end;

procedure CompareStream(AStream: TStream; const AOrigin: string);
var
  LActual: TResources;
  LIndex, LByte: Integer;
  LResource: TAbstractResource;
  LEntry: TResourceEntry;
  LBytes: TBytes;
begin
  AStream.Position := 0;
  LActual := TResources.Create;
  try
    LActual.LoadFromStream(AStream);
    if LActual.Count <> LExpected.Count then
      raise Exception.CreateFmt('%s: expected %d resources, read %d',
        [AOrigin, LExpected.Count, LActual.Count]);
    for LIndex := 0 to LActual.Count - 1 do
    begin
      LResource := LActual[LIndex];
      LEntry := LExpected.Find(Key(LResource._Type), Key(LResource.Name), LResource.LangID);
      if LEntry = nil then
        raise Exception.CreateFmt('%s: unexpected resource %d', [AOrigin, LIndex]);
      LResource.RawData.Position := 0;
      LBytes := ReadResourceData(LResource.RawData, AOrigin);
      if Length(LBytes) <> Length(LEntry.Data) then
        raise Exception.CreateFmt('%s: resource %d payload length differs', [AOrigin, LIndex]);
      for LByte := 0 to Length(LBytes) - 1 do
        if LBytes[LByte] <> LEntry.Data[LByte] then
          raise Exception.CreateFmt('%s: resource %d payload byte %d differs',
            [AOrigin, LIndex, LByte]);
    end;
    WriteLn('PASS: metadata reader recovered ', LActual.Count,
      ' resource identities, languages and payloads from ', AOrigin);
  finally
    LActual.Free;
  end;
end;

procedure CheckDynamicRelocations(AInput: TStream; const AOrigin: string);
var
  LHeader: TElf64Hdr;
  LIdent: TElfIdent;
  LSection, LStrings: TElf64SectHdr;
  LFirst, LSecond, LTemporary: TElf64Rela;
  LIndex, LCount, LCase: Integer;
  LSectionPosition, LPosition: Int64;
  LName: string;
  LCharacter: AnsiChar;
  LCopy: TMemoryStream;
  LRelativeType: Cardinal;
  LFirstPosition, LSecondPosition: Int64;
  LRaised: Boolean;
  LReason: string;
begin
  AInput.Position := 0;
  if AInput.Read(LIdent, SizeOf(LIdent)) <> SizeOf(LIdent) then Exit;
  if (LIdent.Magic <> #$7F'ELF') or (LIdent.ElfClass <> ELFCLASS64) or
    (LIdent.ElfData <> ELFDATA2LSB) then Exit;
  FillChar(LHeader, SizeOf(LHeader), 0);
  if AInput.Read(LHeader, SizeOf(LHeader)) <> SizeOf(LHeader) then Exit;
  if LHeader._Type <> ET_DYN then Exit;
  if LHeader.Machine = EM_X86_64 then LRelativeType := R_X86_64_RELATIVE
  else if LHeader.Machine = EM_AARCH64 then LRelativeType := R_AARCH64_RELATIVE
  else Exit;
  AInput.Position := LHeader.SectHdrOffset + QWord(LHeader.NameTableIndex) * LHeader.SectHdrEntrySize;
  AInput.ReadBuffer(LStrings, SizeOf(LStrings));
  LSectionPosition := -1;
  for LIndex := 0 to LHeader.SectHdrNum - 1 do
  begin
    LPosition := LHeader.SectHdrOffset + QWord(LIndex) * LHeader.SectHdrEntrySize;
    AInput.Position := LPosition;
    AInput.ReadBuffer(LSection, SizeOf(LSection));
    AInput.Position := LStrings.Offset + LSection.NameIdx;
    LName := '';
    repeat
      AInput.ReadBuffer(LCharacter, 1);
      if LCharacter <> #0 then LName := LName + LCharacter;
    until LCharacter = #0;
    if LName = '.rela.dyn' then
    begin
      LSectionPosition := LPosition;
      Break;
    end;
  end;
  if LSectionPosition < 0 then raise Exception.Create('Dynamic relocation fixture lacks .rela.dyn');
  LCount := LSection.Size div SizeOf(TElf64Rela);
  LFirstPosition := -1;
  LSecondPosition := -1;
  for LIndex := 0 to LCount - 1 do
  begin
    LPosition := LSection.Offset + QWord(LIndex) * SizeOf(TElf64Rela);
    AInput.Position := LPosition;
    AInput.ReadBuffer(LTemporary, SizeOf(LTemporary));
    if (LTemporary.Info and $FFFFFFFF) <> LRelativeType then Continue;
    if LFirstPosition < 0 then
    begin
      LFirstPosition := LPosition;
      LFirst := LTemporary;
    end
    else
    begin
      LSecondPosition := LPosition;
      LSecond := LTemporary;
      Break;
    end;
  end;
  if LSecondPosition < 0 then raise Exception.Create('Dynamic fixture needs two relative relocations');
  LCopy := TMemoryStream.Create;
  try
    for LCase := 0 to 5 do
    begin
      LCopy.Clear;
      AInput.Position := 0;
      LCopy.CopyFrom(AInput, 0);
      case LCase of
        0: begin
          LCopy.Position := LFirstPosition;
          LCopy.WriteBuffer(LSecond, SizeOf(LSecond));
          LCopy.Position := LSecondPosition;
          LCopy.WriteBuffer(LFirst, SizeOf(LFirst));
          CompareStream(LCopy, AOrigin + ' (unsorted .rela.dyn)');
          Continue;
        end;
        1: begin
          Dec(LSection.Size);
          LReason := 'Invalid ELF relocation section size';
        end;
        2: begin
          LSection.Offset := QWord(AInput.Size) + 1;
          LReason := 'ELF relocation section lies outside the file';
        end;
        3: begin
          Inc(LFirst.Info, QWord(1) shl 32);
          LCopy.Position := LFirstPosition;
          LCopy.WriteBuffer(LFirst, SizeOf(LFirst));
          LReason := 'ELF relative relocation has a symbol index';
        end;
        4: begin
          LSecond.Offset := LFirst.Offset;
          LCopy.Position := LSecondPosition;
          LCopy.WriteBuffer(LSecond, SizeOf(LSecond));
          LReason := 'Duplicate ELF relative relocation offset';
        end;
        5: begin
          Inc(LSection.EntSize);
          LReason := 'Invalid ELF dynamic relocation section';
        end;
      end;
      if LCase in [1, 2, 5] then
      begin
        LCopy.Position := LSectionPosition;
        LCopy.WriteBuffer(LSection, SizeOf(LSection));
      end;
      LRaised := False;
      try
        CompareStream(LCopy, AOrigin + ' (malformed relocations)');
      except
        on E: EElfResourceReaderException do
        begin
          LRaised := True;
          if Pos(LReason, E.Message) = 0 then raise;
        end;
      end;
      if not LRaised then raise Exception.Create('Malformed dynamic relocation fixture was accepted');
      { Restore header/records for the next independent mutation. }
      AInput.Position := LSectionPosition;
      AInput.ReadBuffer(LSection, SizeOf(LSection));
      AInput.Position := LFirstPosition;
      AInput.ReadBuffer(LFirst, SizeOf(LFirst));
      AInput.Position := LSecondPosition;
      AInput.ReadBuffer(LSecond, SizeOf(LSecond));
    end;
    WriteLn('PASS: unsorted and five malformed dynamic-relocation cases for ', AOrigin);
  finally
    LCopy.Free;
  end;
end;

begin
  if ParamCount < 2 then
  begin
    WriteLn(StdErr, 'Usage: nxResourceTableReaderTests <expected.res> <object-or-image> [...]');
    Halt(2);
  end;
  LExpected := TResourceCatalog.Create;
  try
    LExpected.LoadRes(ParamStr(1));
    for LFile := 2 to ParamCount do
    begin
      LStream := nil;
      try
        LStream := TFileStream.Create(ParamStr(LFile), fmOpenRead or fmShareDenyWrite);
        CompareStream(LStream, ExtractFileName(ParamStr(LFile)));
        CheckDynamicRelocations(LStream, ExtractFileName(ParamStr(LFile)));
      finally
        LStream.Free;
      end;
    end;
  finally
    LExpected.Free;
  end;
end.
