unit NXProfile;

{$mode objfpc}{$H+}

{ Binary trace serialization is deliberately isolated here. TNXProfileWriter
  is a serialized stream writer; its caller owns synchronization.
  TNXProfileReader is a minimal sequential, length-bounded parser. Neither
  class imposes a producer queue, threading policy, or analysis policy. }

interface

uses
  Classes,
  SysUtils;

const
  NXPROFILE_FORMAT_VERSION = 2;
  NXPROFILE_ABI_VERSION = 1;
  NXPROFILE_BYTE_ORDER_LE = $04030201;

  nxprFileHeader = 1;
  nxprModuleDefine = 2;
  nxprModuleUnload = 3;
  nxprProcedureDefine = 4;
  nxprThreadDefine = 5;
  nxprCallBlock = 6;
  nxprTraceGap = 7;
  nxprTraceEnd = 8;

  nxpeEnter = 1;
  nxpeLeave = 2;
  nxpeUnwind = 3;

  nxpcfUnwind = $01;
  nxpcfUnmatched = $02;

type
  ENXProfileFormatError = class(Exception);

  TNXProfileEvent = packed record
    Kind: Byte;
    Flags: Byte;
    Reserved: Word;
    ProcedureId: DWord;
    Timestamp: QWord;
  end;
  PNXProfileEvent = ^TNXProfileEvent;

  PNXProfileCaptureRecord = ^TNXProfileCaptureRecord;
  TNXProfileCaptureRecord = record
    { Owned by TNXEventMemory. Profiling hooks populate only Context and Event. }
    OwnerBlock: Pointer;
    Context: Pointer;
    Event: TNXProfileEvent;
  end;
  TNXProfileEvents = array of TNXProfileEvent;

  TNXProfileCall = record
    Flags: Byte;
    ProcedureId: DWord;
    CallerProcedureId: DWord;
    InclusiveTicks: QWord;
    SelfTicks: QWord;
  end;
  TNXProfileCalls = array of TNXProfileCall;

  TNXProfileModuleInfo = record
    ModuleId: DWord;
    Flags: DWord;
    BuildId: QWord;
    LoadAddress: QWord;
    Timestamp: QWord;
    ImagePath: AnsiString;
  end;

  TNXProfileProcedureInfo = record
    ProcedureId: DWord;
    ModuleId: DWord;
    Flags: DWord;
    StableId: QWord;
    CodeStart: QWord;
    CodeEnd: QWord;
    SourceLine: DWord;
    SourceColumn: DWord;
    Name: AnsiString;
    UnitName: AnsiString;
    SourceFile: AnsiString;
  end;

  TNXProfileThreadInfo = record
    ThreadId: DWord;
    Flags: DWord;
    Timestamp: QWord;
    Name: AnsiString;
  end;

  TNXProfileCallBlock = record
    ThreadId: DWord;
    Sequence: QWord;
    LostEventCount: QWord;
    FirstTimestamp: QWord;
    LastTimestamp: QWord;
    Calls: TNXProfileCalls;
  end;

  TNXProfileRecord = record
    Kind: Word;
    RecordFlags: Word;
    Flags: DWord;
    ModuleInfo: TNXProfileModuleInfo;
    ProcedureInfo: TNXProfileProcedureInfo;
    ThreadInfo: TNXProfileThreadInfo;
    ModuleId: DWord;
    ThreadId: DWord;
    Sequence: QWord;
    Timestamp: QWord;
    LostEventCount: QWord;
    CallBlock: TNXProfileCallBlock;
  end;

  TNXEventMemory = class
  private
    FRotationLock: TRTLCriticalSection;
    FQueueLock: TRTLCriticalSection;
    FActiveBlock: Pointer;
    FAvailableHead: Pointer;
    FAvailableTail: Pointer;
    FCompletedHead: Pointer;
    FCompletedTail: Pointer;
    FAllBlocks: Pointer;
    FCompletionEvent: PRTLEvent;
    FBlockCapacity: LongInt;
    FAllocatedBlockCount: LongInt;
    FAvailableBlockCount: LongInt;
    FSealedBlockCount: LongInt;
    function AllocateBlock: Pointer;
    function ObtainAvailableBlock: Pointer;
    procedure ResetBlock(ABlock: Pointer);
    procedure RotateFullBlock(ABlock: Pointer);
    procedure PublishIfComplete(ABlock: Pointer);
    procedure EnqueueAvailable(ABlock: Pointer);
    procedure EnqueueCompleted(ABlock: Pointer);
  public
    constructor Create(ABlockCapacity: LongInt = 4096);
    destructor Destroy; override;
    function AcquireRecord: PNXProfileCaptureRecord;
    procedure FinalizeRecord(ARecord: PNXProfileCaptureRecord);
    procedure SealCurrentBlock(ACreateReplacement: Boolean);
    procedure SetCompletionEvent(AEvent: PRTLEvent);
    function TakeCompletedBlock: Pointer;
    function CompletedRecordCount(ABlock: Pointer): LongInt;
    function CompletedRecord(ABlock: Pointer;
      AIndex: LongInt): PNXProfileCaptureRecord;
    procedure RecycleCompletedBlock(ABlock: Pointer);
    property BlockCapacity: LongInt read FBlockCapacity;
    property AllocatedBlockCount: LongInt read FAllocatedBlockCount;
    property AvailableBlockCount: LongInt read FAvailableBlockCount;
    property SealedBlockCount: LongInt read FSealedBlockCount;
  end;

  TNXProfileWriter = class
  private
    FStream: TStream;
    FOwnsStream: Boolean;
    FFinished: Boolean;
    FEventMemory: TNXEventMemory;
    FCallBuffer: TBytes;
    procedure WriteRecordHeader(AKind, AFlags: Word; APayloadSize: DWord);
    procedure WriteByte(AValue: Byte);
    procedure WriteWord(AValue: Word);
    procedure WriteDWord(AValue: DWord);
    procedure WriteQWord(AValue: QWord);
    procedure WriteCString(const AValue: AnsiString);
    procedure WriteFileHeader(AProcessId: DWord; ASessionId,
      AClockFrequency, AStartTimestamp: QWord);
  public
    constructor Create(AEventMemory: TNXEventMemory); overload;
    constructor Create(AStream: TStream; AOwnsStream: Boolean;
      AProcessId: DWord; ASessionId, AClockFrequency,
      AStartTimestamp: QWord); overload;
    constructor Create(const AFileName: AnsiString; AProcessId: DWord;
      ASessionId, AClockFrequency, AStartTimestamp: QWord); overload;
    constructor Create(const AFileName: AnsiString; AProcessId: DWord;
      ASessionId, AClockFrequency, AStartTimestamp: QWord;
      AEventMemory: TNXEventMemory); overload;
    destructor Destroy; override;
    procedure StartTrace(const AFileName: AnsiString; AProcessId: DWord;
      ASessionId, AClockFrequency, AStartTimestamp: QWord);
    function WriteModuleDefine(const AInfo: TNXProfileModuleInfo): Boolean;
    procedure WriteModuleUnload(AModuleId, AFlags: DWord;
      ATimestamp: QWord);
    function WriteProcedureDefine(const AInfo: TNXProfileProcedureInfo): Boolean;
    procedure WriteThreadDefine(const AInfo: TNXProfileThreadInfo);
    procedure WriteCallBlock(AThreadId: DWord; ASequence,
      ALostEventCount, AFirstTimestamp, ALastTimestamp: QWord;
      const ACalls: array of TNXProfileCall);
    procedure WriteTraceGap(AThreadId, AFlags: DWord; ASequence,
      ALostEventCount, ATimestamp: QWord);
    procedure Finish(ATimestamp, ATotalLostEventCount: QWord);
    procedure Flush;
    function AcquireRecord: PNXProfileCaptureRecord;
    procedure FinalizeRecord(ARecord: PNXProfileCaptureRecord);
    property Finished: Boolean read FFinished;
  end;

  TNXProfileReader = class
  private
    FStream: TStream;
    FOwnsStream: Boolean;
    FFormatVersion: Word;
    FAbiVersion: Word;
    FProcessId: DWord;
    FSessionId: QWord;
    FClockFrequency: QWord;
    FStartTimestamp: QWord;
    FTruncatedTail: Boolean;
    FLastCompleteOffset: Int64;
    function ReadExact(var ABuffer; ACount: LongInt): Boolean;
    function ReadEnvelope(out AKind, AFlags: Word;
      out APayloadSize: DWord): Boolean;
    function ReadPayload(APayloadSize: DWord; out AData: TBytes): Boolean;
    procedure ReadFileHeader;
    procedure ParseRecord(AKind, AFlags: Word; const AData: TBytes;
      out ARecord: TNXProfileRecord);
  public
    constructor Create(AStream: TStream; AOwnsStream: Boolean); overload;
    constructor Create(const AFileName: AnsiString); overload;
    destructor Destroy; override;
    function ReadNext(out ARecord: TNXProfileRecord): Boolean;
    property FormatVersion: Word read FFormatVersion;
    property AbiVersion: Word read FAbiVersion;
    property ProcessId: DWord read FProcessId;
    property SessionId: QWord read FSessionId;
    property ClockFrequency: QWord read FClockFrequency;
    property StartTimestamp: QWord read FStartTimestamp;
    property TruncatedTail: Boolean read FTruncatedTail;
    property LastCompleteOffset: Int64 read FLastCompleteOffset;
  end;

implementation

const
  NXPROFILE_RECORD_HEADER_SIZE = 8;
  NXPROFILE_FILE_HEADER_PAYLOAD_SIZE = 44;
  NXPROFILE_EVENT_SIZE = 16;
  NXPROFILE_CALL_SIZE = 25;
  NXPROFILE_AVAILABLE_BLOCK_LIMIT = 64;
  nxebAvailable = 0;
  nxebActive = 1;
  nxebSealed = 2;
  nxebCompleted = 3;
  nxebProcessing = 4;

type
  PNXEventMemoryBlock = ^TNXEventMemoryBlock;
  TNXEventMemoryBlock = record
    QueueNext: PNXEventMemoryBlock;
    AllNext: PNXEventMemoryBlock;
    AllPrevious: PNXEventMemoryBlock;
    Issued: LongInt;
    Finished: LongInt;
    Acquirers: LongInt;
    State: LongInt;
  end;

  TNXProfileRecordHeader = packed record
    Kind: Word;
    Flags: Word;
    Size: DWord;
  end;

  TNXProfileBufferReader = record
    Data: Pointer;
    Size: SizeInt;
    Position: SizeInt;
  end;

procedure RaiseFormatError(const AMessage: AnsiString);
begin
  raise ENXProfileFormatError.Create(AMessage);
end;

function CheckedPayloadSize(ABaseSize: QWord): DWord;
begin
  if ABaseSize > High(DWord) - NXPROFILE_RECORD_HEADER_SIZE then
    raise ERangeError.Create('NXProfile record is too large');
  Result := DWord(ABaseSize);
end;

function CStringSize(const AValue: AnsiString): QWord; inline;
begin
  Result := QWord(Length(AValue)) + 1;
end;

procedure BufferRequire(const AReader: TNXProfileBufferReader;
  ACount: SizeInt);
begin
  if (ACount < 0) or (AReader.Position > AReader.Size - ACount) then
    RaiseFormatError('NXProfile record payload is truncated');
end;

function BufferReadWord(var AReader: TNXProfileBufferReader): Word;
begin
  BufferRequire(AReader, SizeOf(Result));
  Move((PByte(AReader.Data) + AReader.Position)^, Result, SizeOf(Result));
  Inc(AReader.Position, SizeOf(Result));
end;

function BufferReadByte(var AReader: TNXProfileBufferReader): Byte;
begin
  BufferRequire(AReader, SizeOf(Result));
  Result := (PByte(AReader.Data) + AReader.Position)^;
  Inc(AReader.Position, SizeOf(Result));
end;

function BufferReadDWord(var AReader: TNXProfileBufferReader): DWord;
begin
  BufferRequire(AReader, SizeOf(Result));
  Move((PByte(AReader.Data) + AReader.Position)^, Result, SizeOf(Result));
  Inc(AReader.Position, SizeOf(Result));
end;

function BufferReadQWord(var AReader: TNXProfileBufferReader): QWord;
begin
  BufferRequire(AReader, SizeOf(Result));
  Move((PByte(AReader.Data) + AReader.Position)^, Result, SizeOf(Result));
  Inc(AReader.Position, SizeOf(Result));
end;

function BufferReadCString(var AReader: TNXProfileBufferReader): AnsiString;
var
  Start, Count: SizeInt;
begin
  Start := AReader.Position;
  while (AReader.Position < AReader.Size) and
    ((PByte(AReader.Data) + AReader.Position)^ <> 0) do
    Inc(AReader.Position);
  if AReader.Position >= AReader.Size then
    RaiseFormatError('NXProfile string has no terminator inside its record');
  Count := AReader.Position - Start;
  SetLength(Result, Count);
  if Count > 0 then
    Move((PByte(AReader.Data) + Start)^, Result[1], Count);
  Inc(AReader.Position);
end;

procedure BufferFinished(const AReader: TNXProfileBufferReader);
begin
  if AReader.Position <> AReader.Size then
    RaiseFormatError('NXProfile record contains unexpected trailing data');
end;

{ TNXEventMemory }

function AtomicRead(var AValue: LongInt): LongInt; inline;
begin
  Result := InterlockedCompareExchange(AValue, 0, 0);
end;

function EventMemoryBlockRecord(ABlock: PNXEventMemoryBlock;
  AIndex: LongInt): PNXProfileCaptureRecord; inline;
begin
  Result := PNXProfileCaptureRecord(PByte(ABlock) +
    SizeOf(TNXEventMemoryBlock) +
    SizeUInt(AIndex) * SizeOf(TNXProfileCaptureRecord));
end;

constructor TNXEventMemory.Create(ABlockCapacity: LongInt);
var
  Block: PNXEventMemoryBlock;
begin
  inherited Create;
  FBlockCapacity := ABlockCapacity;
  InitCriticalSection(FRotationLock);
  InitCriticalSection(FQueueLock);
  Block := PNXEventMemoryBlock(AllocateBlock);
  Block^.State := nxebActive;
  FActiveBlock := Block;
end;

destructor TNXEventMemory.Destroy;
var
  Block, Next: PNXEventMemoryBlock;
begin
  Block := PNXEventMemoryBlock(FAllBlocks);
  while Block <> nil do
  begin
    Next := Block^.AllNext;
    FreeMem(Block);
    Block := Next;
  end;
  DoneCriticalSection(FQueueLock);
  DoneCriticalSection(FRotationLock);
  inherited Destroy;
end;

function TNXEventMemory.AllocateBlock: Pointer;
var
  Block: PNXEventMemoryBlock;
  Index: LongInt;
  AllocationSize: SizeUInt;
begin
  AllocationSize := SizeOf(TNXEventMemoryBlock) +
    SizeUInt(FBlockCapacity) * SizeOf(TNXProfileCaptureRecord);
  GetMem(Block, AllocationSize);
  FillChar(Block^, AllocationSize, 0);
  EnterCriticalSection(FQueueLock);
  try
    Block^.AllNext := PNXEventMemoryBlock(FAllBlocks);
    if Block^.AllNext <> nil then
      Block^.AllNext^.AllPrevious := Block;
    FAllBlocks := Block;
    InterlockedIncrement(FAllocatedBlockCount);
  finally
    LeaveCriticalSection(FQueueLock);
  end;
  for Index := 0 to FBlockCapacity - 1 do
    EventMemoryBlockRecord(Block, Index)^.OwnerBlock := Block;
  Result := Block;
end;

procedure TNXEventMemory.ResetBlock(ABlock: Pointer);
var
  Block: PNXEventMemoryBlock;
begin
  Block := PNXEventMemoryBlock(ABlock);
  Block^.QueueNext := nil;
  Block^.Issued := 0;
  Block^.Finished := 0;
  Block^.State := nxebAvailable;
end;

function TNXEventMemory.ObtainAvailableBlock: Pointer;
var
  Block: PNXEventMemoryBlock;
begin
  Block := nil;
  EnterCriticalSection(FQueueLock);
  try
    if FAvailableHead <> nil then
    begin
      Block := PNXEventMemoryBlock(FAvailableHead);
      FAvailableHead := Block^.QueueNext;
      if FAvailableHead = nil then
        FAvailableTail := nil;
      Block^.QueueNext := nil;
      InterlockedDecrement(FAvailableBlockCount);
    end;
  finally
    LeaveCriticalSection(FQueueLock);
  end;
  if Block = nil then
    Block := PNXEventMemoryBlock(AllocateBlock);
  Block^.State := nxebActive;
  Result := Block;
end;

procedure TNXEventMemory.EnqueueAvailable(ABlock: Pointer);
var
  Block: PNXEventMemoryBlock;
  FreeBlock: Boolean;
begin
  Block := PNXEventMemoryBlock(ABlock);
  Block^.QueueNext := nil;
  FreeBlock := False;
  EnterCriticalSection(FQueueLock);
  try
    if FAvailableBlockCount >= NXPROFILE_AVAILABLE_BLOCK_LIMIT then
    begin
      if Block^.AllPrevious = nil then
        FAllBlocks := Block^.AllNext
      else
        Block^.AllPrevious^.AllNext := Block^.AllNext;
      if Block^.AllNext <> nil then
        Block^.AllNext^.AllPrevious := Block^.AllPrevious;
      InterlockedDecrement(FAllocatedBlockCount);
      FreeBlock := True;
    end
    else
    begin
      if FAvailableTail = nil then
        FAvailableHead := Block
      else
        PNXEventMemoryBlock(FAvailableTail)^.QueueNext := Block;
      FAvailableTail := Block;
      InterlockedIncrement(FAvailableBlockCount);
    end;
  finally
    LeaveCriticalSection(FQueueLock);
  end;
  if FreeBlock then
    FreeMem(Block);
end;

procedure TNXEventMemory.EnqueueCompleted(ABlock: Pointer);
var
  Block: PNXEventMemoryBlock;
  CompletionEvent: PRTLEvent;
begin
  Block := PNXEventMemoryBlock(ABlock);
  Block^.QueueNext := nil;
  CompletionEvent := nil;
  EnterCriticalSection(FQueueLock);
  try
    if FCompletedTail = nil then
      FCompletedHead := Block
    else
      PNXEventMemoryBlock(FCompletedTail)^.QueueNext := Block;
    FCompletedTail := Block;
    CompletionEvent := FCompletionEvent;
  finally
    LeaveCriticalSection(FQueueLock);
  end;
  if CompletionEvent <> nil then
    RTLEventSetEvent(CompletionEvent);
end;

procedure TNXEventMemory.PublishIfComplete(ABlock: Pointer);
var
  Block: PNXEventMemoryBlock;
begin
  Block := PNXEventMemoryBlock(ABlock);
  if (AtomicRead(Block^.Acquirers) = 0) and
     (AtomicRead(Block^.Finished) = AtomicRead(Block^.Issued)) and
     (InterlockedCompareExchange(Block^.State, nxebCompleted,
       nxebSealed) = nxebSealed) then
  begin
    EnqueueCompleted(Block);
  end;
end;

procedure TNXEventMemory.RotateFullBlock(ABlock: Pointer);
var
  Block, Replacement: PNXEventMemoryBlock;
begin
  Block := PNXEventMemoryBlock(ABlock);
  EnterCriticalSection(FRotationLock);
  try
    if (FActiveBlock = Block) and
       (AtomicRead(Block^.Issued) = FBlockCapacity) then
    begin
      InterlockedExchange(Block^.State, nxebSealed);
      InterlockedIncrement(FSealedBlockCount);
      Replacement := PNXEventMemoryBlock(ObtainAvailableBlock);
      FActiveBlock := Replacement;
      PublishIfComplete(Block);
    end;
  finally
    LeaveCriticalSection(FRotationLock);
  end;
end;

function TNXEventMemory.AcquireRecord: PNXProfileCaptureRecord;
var
  Block: PNXEventMemoryBlock;
  Issued: LongInt;
begin
  Result := nil;
  repeat
    Block := PNXEventMemoryBlock(
      InterlockedCompareExchangePointer(FActiveBlock, nil, nil));
    if Block = nil then
      Exit;
    InterlockedIncrement(Block^.Acquirers);
    if (InterlockedCompareExchangePointer(FActiveBlock, nil, nil) <> Block) or
       (AtomicRead(Block^.State) <> nxebActive) then
    begin
      InterlockedDecrement(Block^.Acquirers);
      PublishIfComplete(Block);
      Continue;
    end;
    Issued := AtomicRead(Block^.Issued);
    if Issued >= FBlockCapacity then
    begin
      InterlockedDecrement(Block^.Acquirers);
      PublishIfComplete(Block);
      RotateFullBlock(Block);
      Continue;
    end;
    if InterlockedCompareExchange(Block^.Issued, Issued + 1, Issued) =
       Issued then
    begin
      InterlockedDecrement(Block^.Acquirers);
      PublishIfComplete(Block);
      if Issued + 1 = FBlockCapacity then
        RotateFullBlock(Block);
      Result := EventMemoryBlockRecord(Block, Issued);
      Exit;
    end;
    InterlockedDecrement(Block^.Acquirers);
    PublishIfComplete(Block);
  until False;
end;

procedure TNXEventMemory.FinalizeRecord(ARecord: PNXProfileCaptureRecord);
var
  Block: PNXEventMemoryBlock;
begin
  Block := PNXEventMemoryBlock(ARecord^.OwnerBlock);
  InterlockedIncrement(Block^.Finished);
  PublishIfComplete(Block);
end;

procedure TNXEventMemory.SealCurrentBlock(ACreateReplacement: Boolean);
var
  Block, Replacement: PNXEventMemoryBlock;
begin
  EnterCriticalSection(FRotationLock);
  try
    Block := PNXEventMemoryBlock(FActiveBlock);
    if Block = nil then
      Exit;
    if AtomicRead(Block^.Issued) = 0 then
    begin
      if not ACreateReplacement then
        FActiveBlock := nil;
      Exit;
    end;
    InterlockedExchange(Block^.State, nxebSealed);
    InterlockedIncrement(FSealedBlockCount);
    if ACreateReplacement then
    begin
      Replacement := PNXEventMemoryBlock(ObtainAvailableBlock);
      FActiveBlock := Replacement;
    end
    else
      FActiveBlock := nil;
    PublishIfComplete(Block);
  finally
    LeaveCriticalSection(FRotationLock);
  end;
end;

procedure TNXEventMemory.SetCompletionEvent(AEvent: PRTLEvent);
var
  HasCompleted: Boolean;
begin
  EnterCriticalSection(FQueueLock);
  try
    FCompletionEvent := AEvent;
    HasCompleted := FCompletedHead <> nil;
  finally
    LeaveCriticalSection(FQueueLock);
  end;
  if HasCompleted and (AEvent <> nil) then
    RTLEventSetEvent(AEvent);
end;

function TNXEventMemory.TakeCompletedBlock: Pointer;
var
  Block: PNXEventMemoryBlock;
begin
  Block := nil;
  EnterCriticalSection(FQueueLock);
  try
    if FCompletedHead <> nil then
    begin
      Block := PNXEventMemoryBlock(FCompletedHead);
      FCompletedHead := Block^.QueueNext;
      if FCompletedHead = nil then
        FCompletedTail := nil;
      Block^.QueueNext := nil;
      Block^.State := nxebProcessing;
    end;
  finally
    LeaveCriticalSection(FQueueLock);
  end;
  Result := Block;
end;

function TNXEventMemory.CompletedRecordCount(ABlock: Pointer): LongInt;
begin
  Result := PNXEventMemoryBlock(ABlock)^.Issued;
end;

function TNXEventMemory.CompletedRecord(ABlock: Pointer;
  AIndex: LongInt): PNXProfileCaptureRecord;
begin
  Result := EventMemoryBlockRecord(PNXEventMemoryBlock(ABlock), AIndex);
end;

procedure TNXEventMemory.RecycleCompletedBlock(ABlock: Pointer);
begin
  ResetBlock(ABlock);
  InterlockedDecrement(FSealedBlockCount);
  EnqueueAvailable(ABlock);
end;

{ TNXProfileWriter }

constructor TNXProfileWriter.Create(AEventMemory: TNXEventMemory);
begin
  inherited Create;
  FEventMemory := AEventMemory;
end;

constructor TNXProfileWriter.Create(AStream: TStream; AOwnsStream: Boolean;
  AProcessId: DWord; ASessionId, AClockFrequency,
  AStartTimestamp: QWord);
begin
  inherited Create;
  if AStream = nil then
    raise EArgumentNilException.Create('NXProfile output stream is nil');
  if SizeOf(TNXProfileEvent) <> NXPROFILE_EVENT_SIZE then
    raise EInvalidOpException.Create('TNXProfileEvent ABI size is invalid');
  FStream := AStream;
  FOwnsStream := AOwnsStream;
  WriteFileHeader(AProcessId, ASessionId, AClockFrequency, AStartTimestamp);
end;

constructor TNXProfileWriter.Create(const AFileName: AnsiString;
  AProcessId: DWord; ASessionId, AClockFrequency,
  AStartTimestamp: QWord);
begin
  Create(TFileStream.Create(AFileName, fmCreate or fmShareDenyWrite), True,
    AProcessId, ASessionId, AClockFrequency, AStartTimestamp);
end;

constructor TNXProfileWriter.Create(const AFileName: AnsiString;
  AProcessId: DWord; ASessionId, AClockFrequency,
  AStartTimestamp: QWord; AEventMemory: TNXEventMemory);
begin
  Create(AEventMemory);
  StartTrace(AFileName, AProcessId, ASessionId, AClockFrequency,
    AStartTimestamp);
end;

destructor TNXProfileWriter.Destroy;
begin
  if FOwnsStream then
    FStream.Free;
  inherited Destroy;
end;

procedure TNXProfileWriter.StartTrace(const AFileName: AnsiString;
  AProcessId: DWord; ASessionId, AClockFrequency,
  AStartTimestamp: QWord);
begin
  if FStream <> nil then
    Exit;
  FStream := TFileStream.Create(AFileName, fmCreate or fmShareDenyWrite);
  FOwnsStream := True;
  WriteFileHeader(AProcessId, ASessionId, AClockFrequency, AStartTimestamp);
end;

procedure TNXProfileWriter.WriteRecordHeader(AKind, AFlags: Word;
  APayloadSize: DWord);
var
  Header: TNXProfileRecordHeader;
begin
  Header.Kind := AKind;
  Header.Flags := AFlags;
  Header.Size := APayloadSize + NXPROFILE_RECORD_HEADER_SIZE;
  FStream.WriteBuffer(Header, SizeOf(Header));
end;

procedure TNXProfileWriter.WriteByte(AValue: Byte);
begin
  FStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure TNXProfileWriter.WriteWord(AValue: Word);
begin
  FStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure TNXProfileWriter.WriteDWord(AValue: DWord);
begin
  FStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure TNXProfileWriter.WriteQWord(AValue: QWord);
begin
  FStream.WriteBuffer(AValue, SizeOf(AValue));
end;

procedure TNXProfileWriter.WriteCString(const AValue: AnsiString);
var
  Zero: Byte;
begin
  if AValue <> '' then
    FStream.WriteBuffer(AValue[1], Length(AValue));
  Zero := 0;
  WriteByte(Zero);
end;

procedure TNXProfileWriter.WriteFileHeader(AProcessId: DWord;
  ASessionId, AClockFrequency, AStartTimestamp: QWord);
const
  Magic: array[0..3] of AnsiChar = ('N', 'X', 'P', 'F');
begin
  WriteRecordHeader(nxprFileHeader, 0, NXPROFILE_FILE_HEADER_PAYLOAD_SIZE);
  FStream.WriteBuffer(Magic, SizeOf(Magic));
  WriteWord(NXPROFILE_FORMAT_VERSION);
  WriteWord(NXPROFILE_ABI_VERSION);
  WriteDWord(NXPROFILE_BYTE_ORDER_LE);
  WriteDWord(AProcessId);
  WriteDWord(0);
  WriteQWord(ASessionId);
  WriteQWord(AClockFrequency);
  WriteQWord(AStartTimestamp);
end;

function TNXProfileWriter.WriteModuleDefine(
  const AInfo: TNXProfileModuleInfo): Boolean;
var
  PayloadSize: DWord;
begin
  Result := False;
  if FStream = nil then
    Exit;
  PayloadSize := CheckedPayloadSize(32 + CStringSize(AInfo.ImagePath));
  WriteRecordHeader(nxprModuleDefine, 0, PayloadSize);
  WriteDWord(AInfo.ModuleId);
  WriteDWord(AInfo.Flags);
  WriteQWord(AInfo.BuildId);
  WriteQWord(AInfo.LoadAddress);
  WriteQWord(AInfo.Timestamp);
  WriteCString(AInfo.ImagePath);
  Result := True;
end;

procedure TNXProfileWriter.WriteModuleUnload(AModuleId, AFlags: DWord;
  ATimestamp: QWord);
begin
  if FStream = nil then
    Exit;
  WriteRecordHeader(nxprModuleUnload, 0, 16);
  WriteDWord(AModuleId);
  WriteDWord(AFlags);
  WriteQWord(ATimestamp);
end;

function TNXProfileWriter.WriteProcedureDefine(
  const AInfo: TNXProfileProcedureInfo): Boolean;
var
  PayloadSize: DWord;
begin
  Result := False;
  if FStream = nil then
    Exit;
  PayloadSize := CheckedPayloadSize(48 + CStringSize(AInfo.Name) +
    CStringSize(AInfo.UnitName) + CStringSize(AInfo.SourceFile));
  WriteRecordHeader(nxprProcedureDefine, 0, PayloadSize);
  WriteDWord(AInfo.ProcedureId);
  WriteDWord(AInfo.ModuleId);
  WriteDWord(AInfo.Flags);
  WriteDWord(0);
  WriteQWord(AInfo.StableId);
  WriteQWord(AInfo.CodeStart);
  WriteQWord(AInfo.CodeEnd);
  WriteDWord(AInfo.SourceLine);
  WriteDWord(AInfo.SourceColumn);
  WriteCString(AInfo.Name);
  WriteCString(AInfo.UnitName);
  WriteCString(AInfo.SourceFile);
  Result := True;
end;

procedure TNXProfileWriter.WriteThreadDefine(
  const AInfo: TNXProfileThreadInfo);
var
  PayloadSize: DWord;
begin
  if FStream = nil then
    Exit;
  PayloadSize := CheckedPayloadSize(16 + CStringSize(AInfo.Name));
  WriteRecordHeader(nxprThreadDefine, 0, PayloadSize);
  WriteDWord(AInfo.ThreadId);
  WriteDWord(AInfo.Flags);
  WriteQWord(AInfo.Timestamp);
  WriteCString(AInfo.Name);
end;

procedure TNXProfileWriter.WriteCallBlock(AThreadId: DWord; ASequence,
  ALostEventCount, AFirstTimestamp, ALastTimestamp: QWord;
  const ACalls: array of TNXProfileCall);
var
  PayloadSize: DWord;
  EncodedSize: SizeInt;
  CallIndex: SizeInt;
  Position: SizeInt;

  procedure PutByte(AValue: Byte); inline;
  begin
    FCallBuffer[Position] := AValue;
    Inc(Position);
  end;

  procedure PutDWord(AValue: DWord); inline;
  begin
    Move(AValue, FCallBuffer[Position], SizeOf(AValue));
    Inc(Position, SizeOf(AValue));
  end;

  procedure PutQWord(AValue: QWord); inline;
  begin
    Move(AValue, FCallBuffer[Position], SizeOf(AValue));
    Inc(Position, SizeOf(AValue));
  end;
begin
  if FStream = nil then
    Exit;
  PayloadSize := CheckedPayloadSize(40 + QWord(Length(ACalls)) *
    NXPROFILE_CALL_SIZE);
  WriteRecordHeader(nxprCallBlock, 0, PayloadSize);
  WriteDWord(AThreadId);
  WriteDWord(Length(ACalls));
  WriteQWord(ASequence);
  WriteQWord(ALostEventCount);
  WriteQWord(AFirstTimestamp);
  WriteQWord(ALastTimestamp);
  if Length(ACalls) = 0 then
    Exit;
  EncodedSize := Length(ACalls) * NXPROFILE_CALL_SIZE;
  if Length(FCallBuffer) < EncodedSize then
    SetLength(FCallBuffer, EncodedSize);
  Position := 0;
  for CallIndex := 0 to High(ACalls) do
  begin
    PutByte(ACalls[CallIndex].Flags);
    PutDWord(ACalls[CallIndex].ProcedureId);
    PutDWord(ACalls[CallIndex].CallerProcedureId);
    PutQWord(ACalls[CallIndex].InclusiveTicks);
    PutQWord(ACalls[CallIndex].SelfTicks);
  end;
  FStream.WriteBuffer(FCallBuffer[0], EncodedSize);
end;

procedure TNXProfileWriter.WriteTraceGap(AThreadId, AFlags: DWord;
  ASequence, ALostEventCount, ATimestamp: QWord);
begin
  if FStream = nil then
    Exit;
  WriteRecordHeader(nxprTraceGap, 0, 32);
  WriteDWord(AThreadId);
  WriteDWord(AFlags);
  WriteQWord(ASequence);
  WriteQWord(ALostEventCount);
  WriteQWord(ATimestamp);
end;

procedure TNXProfileWriter.Finish(ATimestamp,
  ATotalLostEventCount: QWord);
begin
  if (FStream = nil) or FFinished then
    Exit;
  WriteRecordHeader(nxprTraceEnd, 0, 16);
  WriteQWord(ATimestamp);
  WriteQWord(ATotalLostEventCount);
  FFinished := True;
  Flush;
end;

procedure TNXProfileWriter.Flush;
begin
  if FStream is TFileStream then
    TFileStream(FStream).Flush;
end;

function TNXProfileWriter.AcquireRecord: PNXProfileCaptureRecord;
begin
  Result := FEventMemory.AcquireRecord;
end;

procedure TNXProfileWriter.FinalizeRecord(ARecord: PNXProfileCaptureRecord);
begin
  FEventMemory.FinalizeRecord(ARecord);
end;

{ TNXProfileReader }

constructor TNXProfileReader.Create(AStream: TStream; AOwnsStream: Boolean);
begin
  inherited Create;
  if AStream = nil then
    raise EArgumentNilException.Create('NXProfile input stream is nil');
  if SizeOf(TNXProfileEvent) <> NXPROFILE_EVENT_SIZE then
    raise EInvalidOpException.Create('TNXProfileEvent ABI size is invalid');
  FStream := AStream;
  FOwnsStream := AOwnsStream;
  ReadFileHeader;
end;

constructor TNXProfileReader.Create(const AFileName: AnsiString);
begin
  Create(TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite), True);
end;

destructor TNXProfileReader.Destroy;
begin
  if FOwnsStream then
    FStream.Free;
  inherited Destroy;
end;

function TNXProfileReader.ReadExact(var ABuffer; ACount: LongInt): Boolean;
var
  Done, ReadCount: LongInt;
begin
  Done := 0;
  while Done < ACount do
  begin
    ReadCount := FStream.Read((PByte(@ABuffer) + Done)^, ACount - Done);
    if ReadCount <= 0 then
      Exit(False);
    Inc(Done, ReadCount);
  end;
  Result := True;
end;

function TNXProfileReader.ReadEnvelope(out AKind, AFlags: Word;
  out APayloadSize: DWord): Boolean;
var
  Header: TNXProfileRecordHeader;
  StartPosition: Int64;
begin
  StartPosition := FStream.Position;
  if StartPosition >= FStream.Size then
    Exit(False);
  if not ReadExact(Header, SizeOf(Header)) then
  begin
    FTruncatedTail := True;
    Exit(False);
  end;
  if Header.Size < NXPROFILE_RECORD_HEADER_SIZE then
    RaiseFormatError('NXProfile record size is smaller than its header');
  AKind := Header.Kind;
  AFlags := Header.Flags;
  APayloadSize := Header.Size - NXPROFILE_RECORD_HEADER_SIZE;
  if QWord(APayloadSize) > QWord(FStream.Size - FStream.Position) then
  begin
    FTruncatedTail := True;
    FStream.Position := FStream.Size;
    Exit(False);
  end;
  Result := True;
end;

function TNXProfileReader.ReadPayload(APayloadSize: DWord;
  out AData: TBytes): Boolean;
begin
  SetLength(AData, APayloadSize);
  if APayloadSize = 0 then
    Exit(True);
  Result := ReadExact(AData[0], APayloadSize);
end;

procedure TNXProfileReader.ReadFileHeader;
var
  Kind, Flags: Word;
  PayloadSize: DWord;
  Data: TBytes;
  Reader: TNXProfileBufferReader;
  Magic: array[0..3] of AnsiChar;
  ByteOrder, Reserved: DWord;
begin
  if not ReadEnvelope(Kind, Flags, PayloadSize) then
    RaiseFormatError('NXProfile file header is missing or truncated');
  if (Kind <> nxprFileHeader) or
     (PayloadSize <> NXPROFILE_FILE_HEADER_PAYLOAD_SIZE) then
    RaiseFormatError('NXProfile file header is invalid');
  if not ReadPayload(PayloadSize, Data) then
    RaiseFormatError('NXProfile file header is truncated');
  Reader.Data := @Data[0];
  Reader.Size := Length(Data);
  Reader.Position := 0;
  BufferRequire(Reader, SizeOf(Magic));
  Move(PByte(Reader.Data)^, Magic, SizeOf(Magic));
  Inc(Reader.Position, SizeOf(Magic));
  if (Magic[0] <> 'N') or (Magic[1] <> 'X') or
     (Magic[2] <> 'P') or (Magic[3] <> 'F') then
    RaiseFormatError('NXProfile file magic is invalid');
  FFormatVersion := BufferReadWord(Reader);
  FAbiVersion := BufferReadWord(Reader);
  ByteOrder := BufferReadDWord(Reader);
  if ByteOrder <> NXPROFILE_BYTE_ORDER_LE then
    RaiseFormatError('NXProfile byte order is unsupported');
  FProcessId := BufferReadDWord(Reader);
  Reserved := BufferReadDWord(Reader);
  FSessionId := BufferReadQWord(Reader);
  FClockFrequency := BufferReadQWord(Reader);
  FStartTimestamp := BufferReadQWord(Reader);
  BufferFinished(Reader);
  if FFormatVersion <> NXPROFILE_FORMAT_VERSION then
    RaiseFormatError(Format('Unsupported NXProfile format version %d',
      [FFormatVersion]));
  if FAbiVersion <> NXPROFILE_ABI_VERSION then
    RaiseFormatError(Format('Unsupported NXProfile ABI version %d',
      [FAbiVersion]));
  if (Flags <> 0) or (Reserved <> 0) then
    RaiseFormatError('NXProfile file header contains unsupported flags');
  FLastCompleteOffset := FStream.Position;
end;

procedure TNXProfileReader.ParseRecord(AKind, AFlags: Word;
  const AData: TBytes; out ARecord: TNXProfileRecord);
var
  Reader: TNXProfileBufferReader;
  Count, I, Reserved: DWord;
begin
  ARecord := Default(TNXProfileRecord);
  ARecord.Kind := AKind;
  ARecord.RecordFlags := AFlags;
  if Length(AData) = 0 then
    Reader.Data := nil
  else
    Reader.Data := @AData[0];
  Reader.Size := Length(AData);
  Reader.Position := 0;
  case AKind of
    nxprModuleDefine:
      begin
        ARecord.ModuleInfo.ModuleId := BufferReadDWord(Reader);
        ARecord.ModuleInfo.Flags := BufferReadDWord(Reader);
        ARecord.ModuleInfo.BuildId := BufferReadQWord(Reader);
        ARecord.ModuleInfo.LoadAddress := BufferReadQWord(Reader);
        ARecord.ModuleInfo.Timestamp := BufferReadQWord(Reader);
        ARecord.ModuleInfo.ImagePath := BufferReadCString(Reader);
      end;
    nxprModuleUnload:
      begin
        ARecord.ModuleId := BufferReadDWord(Reader);
        ARecord.Flags := BufferReadDWord(Reader);
        ARecord.Timestamp := BufferReadQWord(Reader);
      end;
    nxprProcedureDefine:
      begin
        ARecord.ProcedureInfo.ProcedureId := BufferReadDWord(Reader);
        ARecord.ProcedureInfo.ModuleId := BufferReadDWord(Reader);
        ARecord.ProcedureInfo.Flags := BufferReadDWord(Reader);
        Reserved := BufferReadDWord(Reader);
        if Reserved <> 0 then
          RaiseFormatError('NXProfile procedure record has unsupported data');
        ARecord.ProcedureInfo.StableId := BufferReadQWord(Reader);
        ARecord.ProcedureInfo.CodeStart := BufferReadQWord(Reader);
        ARecord.ProcedureInfo.CodeEnd := BufferReadQWord(Reader);
        ARecord.ProcedureInfo.SourceLine := BufferReadDWord(Reader);
        ARecord.ProcedureInfo.SourceColumn := BufferReadDWord(Reader);
        ARecord.ProcedureInfo.Name := BufferReadCString(Reader);
        ARecord.ProcedureInfo.UnitName := BufferReadCString(Reader);
        ARecord.ProcedureInfo.SourceFile := BufferReadCString(Reader);
      end;
    nxprThreadDefine:
      begin
        ARecord.ThreadInfo.ThreadId := BufferReadDWord(Reader);
        ARecord.ThreadInfo.Flags := BufferReadDWord(Reader);
        ARecord.ThreadInfo.Timestamp := BufferReadQWord(Reader);
        ARecord.ThreadInfo.Name := BufferReadCString(Reader);
      end;
    nxprCallBlock:
      begin
        ARecord.CallBlock.ThreadId := BufferReadDWord(Reader);
        Count := BufferReadDWord(Reader);
        ARecord.CallBlock.Sequence := BufferReadQWord(Reader);
        ARecord.CallBlock.LostEventCount := BufferReadQWord(Reader);
        ARecord.CallBlock.FirstTimestamp := BufferReadQWord(Reader);
        ARecord.CallBlock.LastTimestamp := BufferReadQWord(Reader);
        if QWord(Count) * NXPROFILE_CALL_SIZE >
           QWord(Reader.Size - Reader.Position) then
          RaiseFormatError('NXProfile call count exceeds its record');
        SetLength(ARecord.CallBlock.Calls, Count);
        if Count > 0 then
          for I := 0 to Count - 1 do
          begin
            ARecord.CallBlock.Calls[I].Flags := BufferReadByte(Reader);
            ARecord.CallBlock.Calls[I].ProcedureId := BufferReadDWord(Reader);
            ARecord.CallBlock.Calls[I].CallerProcedureId :=
              BufferReadDWord(Reader);
            ARecord.CallBlock.Calls[I].InclusiveTicks :=
              BufferReadQWord(Reader);
            ARecord.CallBlock.Calls[I].SelfTicks := BufferReadQWord(Reader);
          end;
      end;
    nxprTraceGap:
      begin
        ARecord.ThreadId := BufferReadDWord(Reader);
        ARecord.Flags := BufferReadDWord(Reader);
        ARecord.Sequence := BufferReadQWord(Reader);
        ARecord.LostEventCount := BufferReadQWord(Reader);
        ARecord.Timestamp := BufferReadQWord(Reader);
      end;
    nxprTraceEnd:
      begin
        ARecord.Timestamp := BufferReadQWord(Reader);
        ARecord.LostEventCount := BufferReadQWord(Reader);
      end;
  else
    RaiseFormatError('Internal NXProfile record dispatch error');
  end;
  BufferFinished(Reader);
end;

function TNXProfileReader.ReadNext(out ARecord: TNXProfileRecord): Boolean;
var
  Kind, Flags: Word;
  PayloadSize: DWord;
  Data: TBytes;
begin
  ARecord := Default(TNXProfileRecord);
  while ReadEnvelope(Kind, Flags, PayloadSize) do
  begin
    if not ReadPayload(PayloadSize, Data) then
    begin
      FTruncatedTail := True;
      Exit(False);
    end;
    FLastCompleteOffset := FStream.Position;
    if Kind in [nxprModuleDefine, nxprModuleUnload, nxprProcedureDefine,
      nxprThreadDefine, nxprCallBlock, nxprTraceGap, nxprTraceEnd] then
    begin
      ParseRecord(Kind, Flags, Data, ARecord);
      Exit(True);
    end;
    { Unknown records are length-bounded extensions and are skipped. }
  end;
  Result := False;
end;

end.
