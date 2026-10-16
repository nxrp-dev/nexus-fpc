program NXResourceCatalogTests;

{$mode objfpc}{$H+}

uses
  {$ifdef unix}CWString,{$endif}
  Classes, SysUtils, ResourceCatalog;

var
  CheckCount: Integer;

type
  TChunkedMemoryStream = class(TMemoryStream)
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
  end;

function TChunkedMemoryStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  if Count > 65536 then raise Exception.Create('Unbounded resource read');
  Result := inherited Read(Buffer, Count);
end;

function TChunkedMemoryStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  if Count > 65536 then raise Exception.Create('Unbounded resource write');
  Result := inherited Write(Buffer, Count);
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(CheckCount);
  if not ACondition then raise Exception.Create(AMessage);
end;

function NewEntry(AType, AName, ALanguage: Word;
  const AData, AOrigin: string): TResourceEntry;
begin
  Result := TResourceEntry.Create;
  Result.ResourceType := ResourceId(AType);
  Result.Name := ResourceId(AName);
  Result.Language := ALanguage;
  Result.Origin := AOrigin;
  SetLength(Result.Data, Length(AData));
  if Length(AData) <> 0 then Move(AData[1], Result.Data[0], Length(AData));
end;

procedure PutWord(var AData: TBytes; AOffset: Integer; AValue: Word);
begin
  AData[AOffset] := Byte(AValue);
  AData[AOffset + 1] := Byte(AValue shr 8);
end;

function Group(AType, AName, AImageId, ASize: Word): TResourceEntry;
begin
  Result := NewEntry(AType, AName, 1033, '', 'group.res');
  SetLength(Result.Data, 20);
  if AType = 14 then PutWord(Result.Data, 2, 1)
  else PutWord(Result.Data, 2, 2);
  PutWord(Result.Data, 4, 1);
  PutWord(Result.Data, 14, ASize);
  PutWord(Result.Data, 18, AImageId);
end;

function GroupImage(AEntry: TResourceEntry): Word;
begin
  Result := Word(AEntry.Data[18]) or (Word(AEntry.Data[19]) shl 8);
end;

procedure TestRoundTrip;
var
  LFirst, LSecond: TResourceCatalog;
  LStream, LAgain: TMemoryStream;
  LEntry: TResourceEntry;
  LName: UnicodeString;
begin
  LFirst := TResourceCatalog.Create;
  LSecond := TResourceCatalog.Create;
  LStream := TMemoryStream.Create;
  LAgain := TMemoryStream.Create;
  try
    LEntry := NewEntry(10, 1, 1033, #0#$FF'abc', 'roundtrip.res');
    LEntry.Name := ResourceName('MixedCase');
    LEntry.DataVersion := 123;
    LEntry.MemoryFlags := $1030;
    LEntry.Version := 456;
    LEntry.Characteristics := 789;
    LFirst.AddOwned(LEntry);
    LName := WideChar($96EA);
    LEntry := NewEntry(10, 0, 0, '', 'unicode.res');
    LEntry.ResourceType := ResourceName(LName);
    LFirst.AddOwned(LEntry);
    LFirst.AddOwned(NewEntry(10, 1, 1031, 'german', 'language.res'));
    LFirst.AddOwned(NewEntry(10, 1, 1033, 'english', 'language.res'));
    LEntry := NewEntry(10, 0, 1033, 'named ordinal', 'identifiers.res');
    LEntry.Name := ResourceName('1');
    LFirst.AddOwned(LEntry);
    LEntry := NewEntry(10, 0, 1033, 'accented name', 'identifiers.res');
    LEntry.Name := ResourceName('r' + WideChar($E9) + 'sum' + WideChar($E9));
    LFirst.AddOwned(LEntry);
    LFirst.AddOwned(NewEntry(65535, 65535, 65535, 'edge', 'identifiers.res'));
    LFirst.SaveRes(LStream);
    LStream.Position := 0;
    Check(HasResSignature(LStream), 'Missing standard RES signature');
    Check(LStream.Position = 0, 'Signature probe changed stream position');
    LSecond.LoadRes(LStream, 'roundtrip-output.res');
    Check(LSecond.Count = 7, 'Round-trip entry count');
    LEntry := LSecond.Find(ResourceId(10), ResourceName('mixedcase'), 1033);
    Check(LEntry <> nil, 'Case-normalized identifier');
    Check((Length(LEntry.Data) = 5) and (LEntry.Data[0] = 0) and
      (LEntry.Data[1] = $FF) and (LEntry.Data[4] = Ord('c')), 'Opaque payload bytes');
    Check((LEntry.DataVersion = 123) and (LEntry.MemoryFlags = $1030) and
      (LEntry.Version = 456) and (LEntry.Characteristics = 789), 'RES metadata');
    Check(LSecond.Find(ResourceName(LName), ResourceId(0), 0) <> nil, 'UTF-16 type name');
    Check(LSecond.Find(ResourceId(10), ResourceId(1), 1031) <> nil, 'Separate languages');
    Check((LSecond.Find(ResourceId(10), ResourceName('1'), 1033) <> nil) and
      (LSecond.Find(ResourceId(10), ResourceId(1), 1033) <> nil),
      'String and ordinal IDs coexist');
    Check(LSecond.Find(ResourceId(10),
      ResourceName('R' + WideChar($E9) + 'SUM' + WideChar($E9)), 1033) <> nil,
      'Non-ASCII name preserved');
    Check(LSecond.Find(ResourceId(65535), ResourceId(65535), 65535) <> nil,
      'Maximum ordinal and language values');
    LSecond.SaveRes(LAgain);
    Check((LStream.Size = LAgain.Size) and
      CompareMem(LStream.Memory, LAgain.Memory, LStream.Size), 'Canonical RES round trip');
    LSecond.SaveRes(ChangeFileExt(ParamStr(3), '.identifiers.res'));
  finally
    LAgain.Free;
    LStream.Free;
    LSecond.Free;
    LFirst.Free;
  end;
end;

procedure TestTruncation;
var
  LSource, LTarget: TResourceCatalog;
  LStream: TMemoryStream;
  LFullSize, LCut: Int64;
  LBytes: TBytes;
  LRaised: Boolean;
begin
  LSource := TResourceCatalog.Create;
  LStream := TMemoryStream.Create;
  try
    LSource.AddOwned(NewEntry(10, 123, 0, 'payload', 'complete.res'));
    LSource.SaveRes(LStream);
    LFullSize := LStream.Size;
    SetLength(LBytes, LFullSize);
    Move(LStream.Memory^, LBytes[0], LFullSize);
    for LCut := 0 to LFullSize - 1 do
    begin
      LStream.Size := 0;
      if LCut <> 0 then LStream.WriteBuffer(LBytes[0], LCut);
      LStream.Position := 0;
      LTarget := TResourceCatalog.Create;
      try
        LRaised := False;
        try
          LTarget.LoadRes(LStream, 'truncated.res');
        except
          on E: EResourceCatalog do LRaised := True;
        end;
        Check(LRaised = (LCut <> 32), 'Truncated input at byte ' + IntToStr(LCut));
        Check(LTarget.Count = 0, 'Malformed input published a partial record');
      finally
        LTarget.Free;
      end;
    end;
  finally
    LStream.Free;
    LSource.Free;
  end;
end;

procedure TestMalformedRecords;
var
  LSource, LTarget: TResourceCatalog;
  LStream: TMemoryStream;
  LBytes: TBytes;
  LCase: Integer;
  LRaised: Boolean;
begin
  LSource := TResourceCatalog.Create;
  LStream := TMemoryStream.Create;
  try
    LSource.AddOwned(NewEntry(10, 123, 0, 'payload', 'complete.res'));
    LSource.SaveRes(LStream);
    SetLength(LBytes, LStream.Size);
    Move(LStream.Memory^, LBytes[0], Length(LBytes));
    for LCase := 0 to 6 do
    begin
      LStream.Size := 0;
      LStream.WriteBuffer(LBytes[0], Length(LBytes));
      case LCase of
        0: PByte(LStream.Memory)[0] := 1; { Signature }
        1: PByte(LStream.Memory)[36] := 24; { Short header }
        2: PByte(LStream.Memory)[39] := $FF; { Header exceeds file }
        3: PByte(LStream.Memory)[35] := $FF; { Payload exceeds file }
        4: PByte(LStream.Memory)[36] := 33; { Invalid metadata extent }
        5: begin LStream.WriteByte(0); LStream.WriteByte(0); end; { Excess tail }
        6: begin { Unterminated named identifiers }
             FillChar(PByte(LStream.Memory)[40], 8, 1);
           end;
      end;
      LStream.Position := 0;
      LTarget := TResourceCatalog.Create;
      try
        LRaised := False;
        try
          LTarget.LoadRes(LStream, 'malformed.res');
        except
          on E: EResourceCatalog do LRaised := True;
        end;
        Check(LRaised, 'Malformed record accepted: ' + IntToStr(LCase));
        Check(LTarget.Count = 0, 'Malformed input published resources');
      finally
        LTarget.Free;
      end;
    end;
  finally
    LStream.Free;
    LSource.Free;
  end;
end;

procedure TestChunkedPayload;
var
  LSource, LTarget: TResourceCatalog;
  LStream: TChunkedMemoryStream;
  LEntry: TResourceEntry;
  LIndex: Integer;
begin
  LSource := TResourceCatalog.Create;
  LTarget := TResourceCatalog.Create;
  LStream := TChunkedMemoryStream.Create;
  try
    LEntry := NewEntry(10, 1, 0, '', 'large.res');
    SetLength(LEntry.Data, 3 * 65536 + 7);
    for LIndex := 0 to High(LEntry.Data) do LEntry.Data[LIndex] := Byte(LIndex);
    LSource.AddOwned(LEntry);
    LSource.SaveRes(LStream);
    LStream.Position := 0;
    LTarget.LoadRes(LStream, 'large.res');
    Check((LTarget.Count = 1) and
      (Length(LTarget[0].Data) = Length(LEntry.Data)), 'Chunked payload size');
    Check(CompareMem(@LTarget[0].Data[0], @LEntry.Data[0], Length(LEntry.Data)),
      'Chunked payload bytes');
  finally
    LStream.Free;
    LTarget.Free;
    LSource.Free;
  end;
end;

procedure TestIdentifiers;
var
  LCatalog: TResourceCatalog;
  LKey: TResourceKey;
  LIndex: Integer;
  LName: UnicodeString;
  LRaised: Boolean;
begin
  LCatalog := TResourceCatalog.Create;
  try
    LKey := ResourceName('r' + WideChar($E9) + 'sum' + WideChar($E9));
    Check(LKey.Name = 'R' + WideChar($E9) + 'SUM' + WideChar($E9),
      'Resource case folding must match existing ASCII lookup semantics');
    for LIndex := 0 to 2 do
    begin
      case LIndex of
        0: LName := 'embedded' + WideChar(0) + 'nul';
        1: LName := WideChar($FFFF) + 'ordinal-sentinel';
        2: LName := UnicodeString(StringOfChar('x', 65536));
      end;
      LRaised := False;
      try
        LKey := ResourceName(LName);
      except
        on E: EResourceCatalog do LRaised := True;
      end;
      Check(LRaised, 'Invalid identifier accepted: ' + IntToStr(LIndex));
    end;
  finally
    LCatalog.Free;
  end;
end;

procedure TestMalformedStrings;
var
  LCatalog: TResourceCatalog;
  LEntry: TResourceEntry;
  LCase: Integer;
  LRaised: Boolean;
begin
  LCatalog := TResourceCatalog.Create;
  try
    for LCase := 0 to 4 do
    begin
      LEntry := NewEntry(6, 1, 1033, '', 'bad-strings.res');
      try
        SetLength(LEntry.Data, 32);
        case LCase of
          0: SetLength(LEntry.Data, 31);
          1: PutWord(LEntry.Data, 0, 65535);
          2: SetLength(LEntry.Data, 33);
          3: LEntry.Name := ResourceId(0);
          4: LEntry.Name := ResourceName('named-block');
        end;
        LRaised := False;
        try
          LCatalog.AddOwned(LEntry);
          LEntry := nil;
        except
          on E: EResourceCatalog do LRaised := True;
        end;
        Check(LRaised, 'Malformed string block accepted: ' + IntToStr(LCase));
        Check(LCatalog.Count = 0, 'Malformed string block published');
      finally
        LEntry.Free;
      end;
    end;
  finally
    LCatalog.Free;
  end;
end;

procedure TestDuplicate;
var
  LCatalog: TResourceCatalog;
  LEntry: TResourceEntry;
  LRaised: Boolean;
begin
  LCatalog := TResourceCatalog.Create;
  try
    LCatalog.AddOwned(NewEntry(10, 1, 1033, 'first', 'first.res'));
    LEntry := NewEntry(10, 1, 1033, 'second', 'second.res');
    try
      LRaised := False;
      try
        LCatalog.AddOwned(LEntry);
        LEntry := nil;
      except
        on E: EResourceCatalog do
        begin
          LRaised := True;
          Check((Pos('first.res', E.Message) <> 0) and
            (Pos('second.res', E.Message) <> 0), 'Duplicate diagnostic origins');
        end;
      end;
      Check(LRaised, 'Duplicate resource was accepted');
    finally
      LEntry.Free;
    end;
  finally
    LCatalog.Free;
  end;
end;

procedure TestImageGroups(AGroupType, AImageType: Word);
var
  LCatalog, LIncoming: TResourceCatalog;
  LGroup, LImage: TResourceEntry;
  LId: Word;
begin
  LCatalog := TResourceCatalog.Create;
  LIncoming := TResourceCatalog.Create;
  try
    LIncoming.AddOwned(NewEntry(AImageType, 1, 1033, 'first', 'first.res'));
    LIncoming.AddOwned(Group(AGroupType, 101, 1, 5));
    LCatalog.MergeFrom(LIncoming);
    Check(LIncoming.Count = 0, 'Catalog transfer ownership');
    LIncoming.AddOwned(NewEntry(AImageType, 1, 1033, 'second', 'second.res'));
    LIncoming.AddOwned(Group(AGroupType, 102, 1, 6));
    LCatalog.MergeFrom(LIncoming);
    Check(LCatalog.Count = 4, 'Image/group aggregation count');
    LGroup := LCatalog.Find(ResourceId(AGroupType), ResourceId(101), 1033);
    LId := GroupImage(LGroup);
    LImage := LCatalog.Find(ResourceId(AImageType), ResourceId(LId), 1033);
    Check((LImage <> nil) and (LImage.Data[0] = Ord('f')), 'Original group image');
    LGroup := LCatalog.Find(ResourceId(AGroupType), ResourceId(102), 1033);
    Check(GroupImage(LGroup) <> LId, 'Colliding image ID was not rebased');
    LImage := LCatalog.Find(ResourceId(AImageType), ResourceId(GroupImage(LGroup)), 1033);
    Check((LImage <> nil) and (LImage.Data[0] = Ord('s')), 'Rebased group image');
  finally
    LIncoming.Free;
    LCatalog.Free;
  end;
end;

procedure TestMalformedGroups;
var
  LCatalog, LIncoming: TResourceCatalog;
  LGroup: TResourceEntry;
  LCase: Integer;
  LRaised: Boolean;
begin
  for LCase := 0 to 4 do
  begin
    LCatalog := TResourceCatalog.Create;
    LIncoming := TResourceCatalog.Create;
    try
      LGroup := Group(14, 101, 1, 5);
      case LCase of
        0: PutWord(LGroup.Data, 0, 1);
        1: PutWord(LGroup.Data, 2, 2);
        2: SetLength(LGroup.Data, 19);
        3: PutWord(LGroup.Data, 14, 6);
        4: LGroup.Language := 1031;
      end;
      LIncoming.AddOwned(LGroup);
      LIncoming.AddOwned(NewEntry(3, 1, 1033, 'image', 'image.res'));
      LRaised := False;
      try
        LCatalog.MergeFrom(LIncoming);
      except
        on E: EResourceCatalog do LRaised := True;
      end;
      Check(LRaised, 'Invalid group accepted: ' + IntToStr(LCase));
      Check(LCatalog.Count = 0, 'Invalid group published');
    finally
      LIncoming.Free;
      LCatalog.Free;
    end;
  end;
end;

procedure TestLLVMInputs;
var
  LCatalog, LAgain: TResourceCatalog;
  LEntry: TResourceEntry;
  LOffset: Integer;
  LOverlapRaised: Boolean;
begin
  LCatalog := TResourceCatalog.Create;
  LAgain := TResourceCatalog.Create;
  try
    LCatalog.LoadRes(ParamStr(1));
    LCatalog.LoadRes(ParamStr(2));
    Check(LCatalog.Count = 3, 'Disjoint string-block aggregation count');
    LEntry := LCatalog.Find(ResourceId(6), ResourceId(1), 1033);
    Check(LEntry <> nil, 'Merged string-table block');
    Check((LEntry.Data[2] = 5) and (LEntry.Data[4] = Ord('A')), 'First string retained');
    LOffset := 4 + 5 * 2;
    Check((LEntry.Data[LOffset] = 4) and
      (LEntry.Data[LOffset + 2] = Ord('B')), 'Second string merged');
    LCatalog.SaveRes(ParamStr(3));
    LAgain.LoadRes(ParamStr(3));
    Check(LAgain.Count = LCatalog.Count, 'Merged resource output reload');
    LEntry := NewEntry(6, 1, 1033, '', 'overlapping-strings.res');
    LEntry.Data := Copy(LCatalog.Find(ResourceId(6), ResourceId(1), 1033).Data);
    LOverlapRaised := False;
    try
      try
        LCatalog.AddOwned(LEntry);
        LEntry := nil;
      except
        on E: EResourceCatalog do
        begin
          LOverlapRaised := True;
          Check(Pos('overlapping-strings.res', E.Message) <> 0,
            'Overlapping string origin');
        end;
      end;
    finally
      LEntry.Free;
    end;
    Check(LOverlapRaised, 'Overlapping nonempty string entries were accepted');
    LAgain.Free;
    LAgain := nil;
    LAgain := TResourceCatalog.Create;
    LAgain.LoadRes(ParamStr(4));
    Check(LAgain.Count = 3, 'Corrected tres4 fixture');
  finally
    LAgain.Free;
    LCatalog.Free;
  end;
end;

procedure TestLLVMImages;
var
  LCatalog: TResourceCatalog;
  LGroup, LImage: TResourceEntry;
  LKind, LVariant, LPayloadOffset: Integer;
  LGroupType, LImageType, LGroupId: Word;
begin
  LCatalog := TResourceCatalog.Create;
  try
    LCatalog.LoadRes(ParamStr(5));
    LCatalog.LoadRes(ParamStr(6));
    Check(LCatalog.Count = 8, 'Real ICO/CUR merge count');
    for LKind := 0 to 1 do
    begin
      if LKind = 0 then
      begin
        LGroupType := 14;
        LImageType := 3;
        LGroupId := 201;
        LPayloadOffset := 40;
      end
      else
      begin
        LGroupType := 12;
        LImageType := 1;
        LGroupId := 301;
        LPayloadOffset := 44; { Cursor payload includes its hotspot. }
      end;
      for LVariant := 0 to 1 do
      begin
        LGroup := LCatalog.Find(ResourceId(LGroupType),
          ResourceId(LGroupId + LVariant), 1033);
        Check(LGroup <> nil, 'Real ICO/CUR group retained');
        LImage := LCatalog.Find(ResourceId(LImageType),
          ResourceId(GroupImage(LGroup)), 1033);
        Check(LImage <> nil, 'Real ICO/CUR reference resolved');
        Check(Length(LImage.Data) = LPayloadOffset + 8, 'Real ICO/CUR payload size');
        if LVariant = 0 then
          Check((LImage.Data[LPayloadOffset + 1] = 0) and
            (LImage.Data[LPayloadOffset + 2] = $FF), 'Original red image retained')
        else
          Check((LImage.Data[LPayloadOffset + 1] = $FF) and
            (LImage.Data[LPayloadOffset + 2] = 0), 'Colliding green image retained');
      end;
    end;
    LCatalog.SaveRes(ChangeFileExt(ParamStr(3), '.images.res'));
  finally
    LCatalog.Free;
  end;
end;

begin
  if ParamCount <> 6 then
  begin
    WriteLn(StdErr, 'Usage: nxResourceCatalogTests <first.res> <second.res> <merged.res> <tres4.res> <first-images.res> <second-images.res>');
    Halt(2);
  end;
  TestRoundTrip;
  TestTruncation;
  TestMalformedRecords;
  TestChunkedPayload;
  TestIdentifiers;
  TestMalformedStrings;
  TestDuplicate;
  TestImageGroups(14, 3);
  TestImageGroups(12, 1);
  TestMalformedGroups;
  TestLLVMInputs;
  TestLLVMImages;
  WriteLn('PASS: ', CheckCount, ' resource catalog checks');
end.
