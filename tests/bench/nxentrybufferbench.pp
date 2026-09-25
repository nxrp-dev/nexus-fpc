program NXEntryBufferBench;

{$mode objfpc}
{$H+}

uses
  SysUtils, CStreams, NXEntryBuffer;

const
  BufferSize = 16384;
  EntryCount = 2000000;
  OutputCapacity = 128*1024*1024;
  RunCount = 5;

type
  TEntryHeader = packed record
    Size: LongInt;
    ID: Byte;
    Number: Byte;
  end;

  TFixedMemoryStream = class(TCStream)
  private
    FMemory: Pointer;
    FCapacity: LongInt;
    FSize: LongInt;
    FPosition: LongInt;
  public
    constructor Create(ACapacity: LongInt);
    destructor Destroy; override;
    procedure Reset;
    function Read(var Buffer; Count: LongInt): LongInt; override;
    function Write(const Buffer; Count: LongInt): LongInt; override;
    function Seek(Offset: LongInt; Origin: Word): LongInt; override;
    property Memory: Pointer read FMemory;
    property DataSize: LongInt read FSize;
  end;

  TLegacyEntryBuffer = class
  private
    FData: Pointer;
    FPosition: LongInt;
    FStart: LongInt;
    FStream: TFixedMemoryStream;
  public
    constructor Create(AStream: TFixedMemoryStream);
    destructor Destroy; override;
    procedure Reset;
    procedure Write(const Buffer; Count: LongInt);
    procedure Patch(Offset: LongInt; const Buffer; Count: LongInt);
    procedure Flush;
    property Position: LongInt read FPosition;
    property Start: LongInt read FStart;
  end;

constructor TFixedMemoryStream.Create(ACapacity: LongInt);
begin
  inherited Create;
  FCapacity:=ACapacity;
  GetMem(FMemory, FCapacity);
  Reset;
end;

destructor TFixedMemoryStream.Destroy;
begin
  FreeMem(FMemory, FCapacity);
  inherited Destroy;
end;

procedure TFixedMemoryStream.Reset;
begin
  FSize:=0;
  FPosition:=0;
end;

function TFixedMemoryStream.Read(var Buffer; Count: LongInt): LongInt;
begin
  Result:=FSize-FPosition;
  if Result>Count then
    Result:=Count;
  if Result>0 then
    begin
      Move(Pointer(PtrUInt(FMemory)+PtrUInt(FPosition))^, Buffer, Result);
      Inc(FPosition, Result);
    end;
end;

function TFixedMemoryStream.Write(const Buffer; Count: LongInt): LongInt;
begin
  Result:=Count;
  Move(Buffer, Pointer(PtrUInt(FMemory)+PtrUInt(FPosition))^, Count);
  Inc(FPosition, Count);
  if FPosition>FSize then
    FSize:=FPosition;
end;

function TFixedMemoryStream.Seek(Offset: LongInt; Origin: Word): LongInt;
begin
  case Origin of
    soFromBeginning: FPosition:=Offset;
    soFromCurrent: Inc(FPosition, Offset);
    soFromEnd: FPosition:=FSize+Offset;
  end;
  Result:=FPosition;
end;

constructor TLegacyEntryBuffer.Create(AStream: TFixedMemoryStream);
begin
  inherited Create;
  FStream:=AStream;
  GetMem(FData, BufferSize);
  Reset;
end;

destructor TLegacyEntryBuffer.Destroy;
begin
  FreeMem(FData, BufferSize);
  inherited Destroy;
end;

procedure TLegacyEntryBuffer.Reset;
begin
  FPosition:=0;
  FStart:=0;
end;

procedure TLegacyEntryBuffer.Flush;
begin
  if FPosition>0 then
    FStream.Write(FData^, FPosition);
  Inc(FStart, FPosition);
  FPosition:=0;
end;

procedure TLegacyEntryBuffer.Write(const Buffer; Count: LongInt);
var
  Source: PByte;
  Available: LongInt;
begin
  Source:=@Buffer;
  while Count>0 do
    begin
      Available:=BufferSize-FPosition;
      if Available>Count then
        Available:=Count;
      Move(Source^, Pointer(PtrUInt(FData)+PtrUInt(FPosition))^, Available);
      Inc(Source, Available);
      Inc(FPosition, Available);
      Dec(Count, Available);
      if FPosition=BufferSize then
        Flush;
    end;
end;

procedure TLegacyEntryBuffer.Patch(Offset: LongInt; const Buffer; Count: LongInt);
var
  SavedPosition: LongInt;
begin
  if Offset>=FStart then
    Move(Buffer, Pointer(PtrUInt(FData)+PtrUInt(Offset-FStart))^, Count)
  else
    begin
      Flush;
      SavedPosition:=FStream.Position;
      FStream.Position:=Offset;
      FStream.Write(Buffer, Count);
      FStream.Position:=SavedPosition;
    end;
end;

procedure FillPayload(var Payload: array of Byte; Seed: LongInt);
var
  Index: LongInt;
begin
  for Index:=0 to High(Payload) do
    Payload[Index]:=Byte(Seed+Index*17);
end;

procedure WriteLegacy(Buffer: TLegacyEntryBuffer);
var
  Index: LongInt;
  Header: TEntryHeader;
  HeaderOffset: LongInt;
  Value8: Byte;
  Value16: Word;
  Value32: DWord;
  Value64: QWord;
  Payload: array[0..30] of Byte;
  PayloadSize: LongInt;
begin
  Buffer.Reset;
  for Index:=0 to EntryCount-1 do
    begin
      FillChar(Header, SizeOf(Header), 0);
      HeaderOffset:=Buffer.Start+Buffer.Position;
      Buffer.Write(Header, SizeOf(Header));
      Value8:=Byte(Index);
      Value16:=Word(Index*3);
      Value32:=DWord(Index*17);
      Value64:=QWord(Index)*QWord(65537);
      Buffer.Write(Value8, SizeOf(Value8));
      Buffer.Write(Value16, SizeOf(Value16));
      Buffer.Write(Value32, SizeOf(Value32));
      Buffer.Write(Value64, SizeOf(Value64));
      PayloadSize:=(Index mod Length(Payload))+1;
      FillPayload(Payload, Index);
      Buffer.Write(Payload, PayloadSize);
      Header.Size:=15+PayloadSize;
      Header.ID:=1;
      Header.Number:=Byte(Index);
      Buffer.Patch(HeaderOffset, Header, SizeOf(Header));
    end;
  Buffer.Flush;
end;

procedure WriteNX(Buffer: TNXEntryBuffer; Stream: TFixedMemoryStream);
var
  Index: LongInt;
  Header: TEntryHeader;
  HeaderOffset: LongInt;
  Value8: Byte;
  Value16: Word;
  Value32: DWord;
  Value64: QWord;
  Payload: array[0..30] of Byte;
  PayloadSize: LongInt;
begin
  Buffer.Reset;
  for Index:=0 to EntryCount-1 do
    begin
      FillChar(Header, SizeOf(Header), 0);
      HeaderOffset:=Buffer.Position;
      Buffer.Write(Header, SizeOf(Header));
      Value8:=Byte(Index);
      Value16:=Word(Index*3);
      Value32:=DWord(Index*17);
      Value64:=QWord(Index)*QWord(65537);
      Buffer.Write(Value8, SizeOf(Value8));
      Buffer.Write(Value16, SizeOf(Value16));
      Buffer.Write(Value32, SizeOf(Value32));
      Buffer.Write(Value64, SizeOf(Value64));
      PayloadSize:=(Index mod Length(Payload))+1;
      FillPayload(Payload, Index);
      Buffer.Write(Payload, PayloadSize);
      Header.Size:=15+PayloadSize;
      Header.ID:=1;
      Header.Number:=Byte(Index);
      Buffer.Patch(HeaderOffset, Header, SizeOf(Header));
    end;
  Buffer.SaveToStream(Stream);
end;

procedure SortTimes(var Values: array of QWord);
var
  LeftIndex: LongInt;
  RightIndex: LongInt;
  Temporary: QWord;
begin
  for LeftIndex:=Low(Values) to High(Values)-1 do
    for RightIndex:=LeftIndex+1 to High(Values) do
      if Values[RightIndex]<Values[LeftIndex] then
        begin
          Temporary:=Values[LeftIndex];
          Values[LeftIndex]:=Values[RightIndex];
          Values[RightIndex]:=Temporary;
        end;
end;

var
  LegacyStream: TFixedMemoryStream;
  NXStream: TFixedMemoryStream;
  LegacyBuffer: TLegacyEntryBuffer;
  NXBuffer: TNXEntryBuffer;
  LegacyTimes: array[0..RunCount-1] of QWord;
  NXTimes: array[0..RunCount-1] of QWord;
  Started: QWord;
  Run: LongInt;
begin
  LegacyStream:=TFixedMemoryStream.Create(OutputCapacity);
  NXStream:=TFixedMemoryStream.Create(OutputCapacity);
  LegacyBuffer:=TLegacyEntryBuffer.Create(LegacyStream);
  NXBuffer:=TNXEntryBuffer.Create(BufferSize);
  try
    WriteLegacy(LegacyBuffer);
    WriteNX(NXBuffer, NXStream);
    if LegacyStream.DataSize<>NXStream.DataSize then
      raise Exception.Create('Parity failure: output sizes differ');
    if not CompareMem(LegacyStream.Memory, NXStream.Memory, LegacyStream.DataSize) then
      raise Exception.Create('Parity failure: output bytes differ');
    Writeln('PARITY=PASS BYTES=',LegacyStream.DataSize);
    for Run:=0 to RunCount-1 do
      begin
        LegacyStream.Reset;
        Started:=GetTickCount64;
        WriteLegacy(LegacyBuffer);
        LegacyTimes[Run]:=GetTickCount64-Started;
        NXStream.Reset;
        Started:=GetTickCount64;
        WriteNX(NXBuffer, NXStream);
        NXTimes[Run]:=GetTickCount64-Started;
        Writeln('RUN=',Run+1,' LEGACY_MS=',LegacyTimes[Run],' NX_MS=',NXTimes[Run]);
      end;
    SortTimes(LegacyTimes);
    SortTimes(NXTimes);
    Writeln('LEGACY_MEDIAN_MS=',LegacyTimes[RunCount div 2]);
    Writeln('NX_MEDIAN_MS=',NXTimes[RunCount div 2]);
  finally
    NXBuffer.Free;
    LegacyBuffer.Free;
    NXStream.Free;
    LegacyStream.Free;
  end;
end.
