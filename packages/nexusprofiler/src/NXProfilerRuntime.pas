unit NXProfilerRuntime;

{$mode objfpc}{$H+}
{$pointermath on}
{$R-}{$Q-}

interface

procedure nxp_module_register(ModuleDescriptor: Pointer); cdecl;
procedure nxp_module_unregister(ModuleDescriptor: Pointer); cdecl;
procedure nxp_enter(ProcedureDescriptor: Pointer); cdecl;
procedure nxp_leave(ProcedureDescriptor: Pointer); cdecl;
procedure nxp_unwind(ProcedureDescriptor: Pointer; EstablisherFrame: PtrUInt;
  ExceptionFlags: DWord); cdecl;
procedure nxp_flush; cdecl;
procedure nxp_shutdown; cdecl;

implementation

uses
  Windows,
  NXProfile;

const
  NXP_DESC_MAGIC = $4450584E;
  NXP_DESC_ABI = 1;
  NXP_MODULE_MAGIC = $4D50584E;
  NXP_MODULE_ABI = 1;
  NXP_THREAD_BUFFER_COUNT = 4096;
  NXP_WORKER_BLOCK_BATCH = 64;
  FLS_OUT_OF_INDEXES = DWORD($FFFFFFFF);
  NXP_CONTROL_CLASS: PAnsiChar = 'NexusFPCProfilerControl';
  NXP_CONTROL_TITLE_PREFIX: PAnsiChar = 'NexusFPCProfiler-';
  NXP_START_MESSAGE_NAME: PAnsiChar = 'NexusFPCProfiler.Start';
  NXP_STOP_MESSAGE_NAME: PAnsiChar = 'NexusFPCProfiler.Stop';

type
  TFlsCallback = procedure(Data: Pointer); stdcall;

  PNXPProcedureDescriptor = ^TNXPProcedureDescriptor;
  TNXPProcedureDescriptor = packed record
    Magic: DWord;
    AbiVersion: Word;
    Flags: Word;
    RuntimeId: DWord;
    Reserved: DWord;
    StableId: QWord;
    CodeStart: Pointer;
    CodeEnd: Pointer;
    Name: AnsiString;
    UnitName: AnsiString;
    SourceFile: AnsiString;
    SourceLine: DWord;
    SourceColumn: DWord;
  end;

  PNXPModuleDescriptor = ^TNXPModuleDescriptor;
  TNXPModuleDescriptor = packed record
    Magic: DWord;
    AbiVersion: Word;
    Flags: Word;
    Reserved: DWord;
    Reserved2: DWord;
    DescriptorStart: Pointer;
    DescriptorEnd: Pointer;
  end;

  PNXPRuntimeModule = ^TNXPRuntimeModule;
  TNXPRuntimeModule = record
    Descriptor: PNXPModuleDescriptor;
    ModuleId: DWord;
    ImageBase: Pointer;
    BuildId: QWord;
    ImagePath: AnsiString;
    Active: Boolean;
    Defined: Boolean;
    LoadTimestamp: QWord;
  end;

  PNXPRuntimeProcedure = ^TNXPRuntimeProcedure;
  TNXPRuntimeProcedure = record
    Descriptor: PNXPProcedureDescriptor;
    Info: TNXProfileProcedureInfo;
    Defined: Boolean;
  end;

  PNXPCallFrame = ^TNXPCallFrame;
  TNXPCallFrame = record
    ProcedureId: DWord;
    EnterTimestamp: QWord;
    ChildTicks: QWord;
  end;

  PNXPThreadState = ^TNXPThreadState;
  TNXPThreadState = record
    Next: PNXPThreadState;
    ThreadId: DWord;
    Guard: LongInt;
    Defined: Boolean;
    Sequence: QWord;
    StartTimestamp: QWord;
    CallCount: DWord;
    FirstCompletionTimestamp: QWord;
    LastCompletionTimestamp: QWord;
    Frames: PNXPCallFrame;
    FrameCount: DWord;
    FrameCapacity: DWord;
    Calls: array[0..NXP_THREAD_BUFFER_COUNT - 1] of TNXProfileCall;
  end;

function FlsAlloc(Callback: TFlsCallback): DWORD; stdcall;
  external 'kernel32.dll' name 'FlsAlloc';
function FlsFree(Index: DWORD): LongBool; stdcall;
  external 'kernel32.dll' name 'FlsFree';
function FlsGetValue(Index: DWORD): Pointer; stdcall;
  external 'kernel32.dll' name 'FlsGetValue';
function FlsSetValue(Index: DWORD; Value: Pointer): LongBool; stdcall;
  external 'kernel32.dll' name 'FlsSetValue';

var
  ProcessHeap: THandle;
  FlsIndex: DWord = FLS_OUT_OF_INDEXES;
  WriterLock: TRTLCriticalSection;
  EventMemory: TNXEventMemory;
  Writer: TNXProfileWriter;
  WorkerWakeEvent: PRTLEvent;
  WorkerControlReadyEvent: PRTLEvent;
  WorkerThread: TThreadID;
  WorkerStarted: Boolean;
  WorkerStop: LongInt;
  ControlWindow: HWND;
  StartControlMessage: UINT;
  StopControlMessage: UINT;
  CaptureEnabled: LongInt;
  ActiveHooks: LongInt;
  CounterFrequency: TLargeInteger;
  Modules: array of TNXPRuntimeModule;
  Procedures: array of TNXPRuntimeProcedure;
  ThreadRoot: Pointer;
  NextModuleId: DWord;
  NextProcedureId: DWord;
  StartupCounter: LongInt;
  RuntimeInitialized: LongInt;
  RuntimeHealthy: LongInt;
  ShuttingDown: LongInt;
  RegisteredDescriptor: PNXPModuleDescriptor;

function Timestamp: QWord; inline;
var
  Stamp: TLargeInteger;
begin
  if QueryPerformanceCounter(Stamp) then
    Result := QWord(Stamp)
  else
    Result := 0;
end;

function OwnString(const Value: AnsiString): AnsiString;
begin
  SetLength(Result, Length(Value));
  if Result <> '' then
    Move(Value[1], Result[1], Length(Value));
end;

function ModuleBaseFor(Address: Pointer): Pointer;
var
  Info: TMemoryBasicInformation;
begin
  Result := nil;
  FillChar(Info, SizeOf(Info), 0);
  if VirtualQuery(Address, @Info, SizeOf(Info)) <> 0 then
    Result := Info.AllocationBase;
end;

function ModuleBuildId(ImageBase: Pointer): QWord;
var
  NTHeader: PByte;
begin
  Result := 0;
  if ImageBase = nil then
    Exit;
  NTHeader := PByte(ImageBase) + PLongInt(PByte(ImageBase) + $3c)^;
  Result := PDWord(NTHeader + 8)^;
end;

function ModulePath(ImageBase: Pointer): AnsiString;
var
  Buffer: array[0..MAX_PATH * 2] of AnsiChar;
  Count: DWord;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  Count := GetModuleFileNameA(HMODULE(ImageBase), @Buffer[0], High(Buffer));
  if Count = 0 then
    Result := ''
  else
    SetString(Result, PAnsiChar(@Buffer[0]), Count);
end;

function FindModule(Descriptor: PNXPModuleDescriptor): PNXPRuntimeModule;
var
  Index: SizeInt;
begin
  for Index := High(Modules) downto 0 do
    if Modules[Index].Active and
       (Modules[Index].Descriptor = Descriptor) then
      Exit(@Modules[Index]);
  Result := nil;
end;

procedure AppendDecimal(var Buffer: array of AnsiChar; var Position: SizeInt;
  Value: DWord);
var
  Digits: array[0..9] of AnsiChar;
  Count: SizeInt;
begin
  Count := 0;
  repeat
    Digits[Count] := AnsiChar(Ord('0') + Value mod 10);
    Inc(Count);
    Value := Value div 10;
  until Value = 0;
  while Count <> 0 do
  begin
    Dec(Count);
    Buffer[Position] := Digits[Count];
    Inc(Position);
  end;
end;

function BuildTraceFileName(var Buffer: array of AnsiChar;
  ProcessId, Counter: DWord): SizeInt;
const
  Prefix: PAnsiChar = 'nexus-profile-';
  Suffix: PAnsiChar = '.nxp';
var
  Index, Position: SizeInt;
begin
  Position := 0;
  Index := 0;
  while Prefix[Index] <> #0 do
  begin
    Buffer[Position] := Prefix[Index];
    Inc(Position);
    Inc(Index);
  end;
  AppendDecimal(Buffer, Position, ProcessId);
  Buffer[Position] := '-';
  Inc(Position);
  AppendDecimal(Buffer, Position, Counter);
  Index := 0;
  while Suffix[Index] <> #0 do
  begin
    Buffer[Position] := Suffix[Index];
    Inc(Position);
    Inc(Index);
  end;
  Buffer[Position] := #0;
  Result := Position;
end;

function BuildControlWindowTitle(var Buffer: array of AnsiChar;
  ProcessId: DWord): SizeInt;
var
  Index, Position: SizeInt;
begin
  Position := 0;
  Index := 0;
  while NXP_CONTROL_TITLE_PREFIX[Index] <> #0 do
  begin
    Buffer[Position] := NXP_CONTROL_TITLE_PREFIX[Index];
    Inc(Position);
    Inc(Index);
  end;
  AppendDecimal(Buffer, Position, ProcessId);
  Buffer[Position] := #0;
  Result := Position;
end;

function StartsPaused: Boolean;
var
  Buffer: array[0..15] of AnsiChar;
  Count: DWord;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  Count := GetEnvironmentVariableA('NEXUS_PROFILE_START',
    @Buffer[0], Length(Buffer));
  Result := (Count = 6) and
    ((Buffer[0] = 'p') or (Buffer[0] = 'P')) and
    ((Buffer[1] = 'a') or (Buffer[1] = 'A')) and
    ((Buffer[2] = 'u') or (Buffer[2] = 'U')) and
    ((Buffer[3] = 's') or (Buffer[3] = 'S')) and
    ((Buffer[4] = 'e') or (Buffer[4] = 'E')) and
    ((Buffer[5] = 'd') or (Buffer[5] = 'D'));
end;

procedure WriteModuleLocked(AModule: PNXPRuntimeModule);
var
  Info: TNXProfileModuleInfo;
begin
  if (Writer = nil) or AModule^.Defined then
    Exit;
  Info := Default(TNXProfileModuleInfo);
  Info.ModuleId := AModule^.ModuleId;
  Info.BuildId := AModule^.BuildId;
  Info.LoadAddress := PtrUInt(AModule^.ImageBase);
  Info.Timestamp := AModule^.LoadTimestamp;
  Info.ImagePath := AModule^.ImagePath;
  if Writer.WriteModuleDefine(Info) then
    AModule^.Defined := True;
end;

procedure WriteProcedureLocked(AProcedure: PNXPRuntimeProcedure);
begin
  if (Writer = nil) or AProcedure^.Defined then
    Exit;
  if Writer.WriteProcedureDefine(AProcedure^.Info) then
    AProcedure^.Defined := True;
end;

procedure WriteMetadataLocked;
var
  Index: SizeInt;
begin
  for Index := 0 to High(Modules) do
    WriteModuleLocked(@Modules[Index]);
  for Index := 0 to High(Procedures) do
    WriteProcedureLocked(@Procedures[Index]);
end;

procedure ResetMetadataDefinitionsLocked;
var
  Index: SizeInt;
  State: PNXPThreadState;
begin
  for Index := 0 to High(Modules) do
    Modules[Index].Defined := False;
  for Index := 0 to High(Procedures) do
    Procedures[Index].Defined := False;
  State := PNXPThreadState(ThreadRoot);
  while State <> nil do
  begin
    State^.Defined := False;
    State := State^.Next;
  end;
end;

procedure StartWriterLocked;
var
  FileNameBuffer: array[0..63] of AnsiChar;
  FileName: AnsiString;
  FileNameLength: SizeInt;
  StartStamp, SessionId: QWord;
begin
  if (Writer = nil) or (RuntimeHealthy = 0) or
     (ShuttingDown <> 0) then
    Exit;
  StartStamp := Timestamp;
  Inc(StartupCounter);
  SessionId := (QWord(GetCurrentProcessId) shl 32) or DWord(StartupCounter);
  FileNameLength := BuildTraceFileName(FileNameBuffer,
    GetCurrentProcessId, StartupCounter);
  SetString(FileName, PAnsiChar(@FileNameBuffer[0]), FileNameLength);
  Writer.StartTrace(FileName, GetCurrentProcessId, SessionId,
    QWord(CounterFrequency), StartStamp);
  ResetMetadataDefinitionsLocked;
  WriteMetadataLocked;
end;

procedure DefineThreadLocked(State: PNXPThreadState);
var
  Info: TNXProfileThreadInfo;
begin
  if (Writer = nil) or State^.Defined then
    Exit;
  Info := Default(TNXProfileThreadInfo);
  Info.ThreadId := State^.ThreadId;
  Info.Timestamp := State^.StartTimestamp;
  Writer.WriteThreadDefine(Info);
  State^.Defined := True;
end;

procedure FlushStateLocked(State: PNXPThreadState);
begin
  if (Writer = nil) or (State = nil) or (State^.CallCount = 0) then
    Exit;
  DefineThreadLocked(State);
  Writer.WriteCallBlock(State^.ThreadId, State^.Sequence, 0,
    State^.FirstCompletionTimestamp, State^.LastCompletionTimestamp,
    Slice(State^.Calls, State^.CallCount));
  Inc(State^.Sequence);
  State^.CallCount := 0;
  State^.FirstCompletionTimestamp := 0;
  State^.LastCompletionTimestamp := 0;
end;

procedure FlushAllStatesLocked;
var
  State: PNXPThreadState;
begin
  State := PNXPThreadState(ThreadRoot);
  while State <> nil do
  begin
    FlushStateLocked(State);
    State := State^.Next;
  end;
end;

function GrowFrameStack(State: PNXPThreadState): Boolean;
var
  NewCapacity: DWord;
  NewFrames: Pointer;
begin
  if State^.FrameCapacity = 0 then
    NewCapacity := 64
  else
    NewCapacity := State^.FrameCapacity * 2;
  if State^.Frames = nil then
    NewFrames := HeapAlloc(ProcessHeap, 0,
      SizeUInt(NewCapacity) * SizeOf(TNXPCallFrame))
  else
    NewFrames := HeapReAlloc(ProcessHeap, 0, State^.Frames,
      SizeUInt(NewCapacity) * SizeOf(TNXPCallFrame));
  Result := NewFrames <> nil;
  if Result then
  begin
    State^.Frames := PNXPCallFrame(NewFrames);
    State^.FrameCapacity := NewCapacity;
  end;
end;

procedure AppendCallLocked(State: PNXPThreadState;
  const Call: TNXProfileCall; CompletionTimestamp: QWord);
begin
  DefineThreadLocked(State);
  if State^.CallCount = 0 then
    State^.FirstCompletionTimestamp := CompletionTimestamp;
  State^.LastCompletionTimestamp := CompletionTimestamp;
  State^.Calls[State^.CallCount] := Call;
  Inc(State^.CallCount);
  if State^.CallCount = NXP_THREAD_BUFFER_COUNT then
    FlushStateLocked(State);
end;

procedure ProcessEventLocked(State: PNXPThreadState;
  const Event: TNXProfileEvent);
var
  Frame, ParentFrame: PNXPCallFrame;
  Call: TNXProfileCall;
begin
  if Event.Kind = nxpeEnter then
  begin
    if (State^.FrameCount = State^.FrameCapacity) and
       (not GrowFrameStack(State)) then
      Exit;
    Frame := State^.Frames + State^.FrameCount;
    Frame^.ProcedureId := Event.ProcedureId;
    Frame^.EnterTimestamp := Event.Timestamp;
    Frame^.ChildTicks := 0;
    Inc(State^.FrameCount);
    Exit;
  end;

  Call := Default(TNXProfileCall);
  Call.ProcedureId := Event.ProcedureId;
  if Event.Kind = nxpeUnwind then
    Call.Flags := nxpcfUnwind;
  if (State^.FrameCount = 0) then
  begin
    Call.Flags := Call.Flags or nxpcfUnmatched;
    AppendCallLocked(State, Call, Event.Timestamp);
    Exit;
  end;
  Frame := State^.Frames + State^.FrameCount - 1;
  if (Frame^.ProcedureId <> Event.ProcedureId) or
     (Event.Timestamp < Frame^.EnterTimestamp) or
     (Frame^.ChildTicks > Event.Timestamp - Frame^.EnterTimestamp) then
  begin
    Call.Flags := Call.Flags or nxpcfUnmatched;
    AppendCallLocked(State, Call, Event.Timestamp);
    Exit;
  end;

  Call.InclusiveTicks := Event.Timestamp - Frame^.EnterTimestamp;
  Call.SelfTicks := Call.InclusiveTicks - Frame^.ChildTicks;
  Dec(State^.FrameCount);
  if State^.FrameCount <> 0 then
  begin
    ParentFrame := State^.Frames + State^.FrameCount - 1;
    Call.CallerProcedureId := ParentFrame^.ProcedureId;
    Inc(ParentFrame^.ChildTicks, Call.InclusiveTicks);
  end;
  AppendCallLocked(State, Call, Event.Timestamp);
end;

procedure ProcessCompletedBlock(Block: Pointer);
var
  Index, Count: LongInt;
  Capture: PNXProfileCaptureRecord;
  State: PNXPThreadState;
begin
  EnterCriticalSection(WriterLock);
  try
    Count := EventMemory.CompletedRecordCount(Block);
    for Index := 0 to Count - 1 do
    begin
      Capture := EventMemory.CompletedRecord(Block, Index);
      State := PNXPThreadState(Capture^.Context);
      ProcessEventLocked(State, Capture^.Event);
    end;
  finally
    LeaveCriticalSection(WriterLock);
  end;
  EventMemory.RecycleCompletedBlock(Block);
end;

procedure ResetThreadCaptureLocked;
var
  State: PNXPThreadState;
begin
  State := PNXPThreadState(ThreadRoot);
  while State <> nil do
  begin
    State^.Defined := False;
    State^.Sequence := 0;
    State^.CallCount := 0;
    State^.FirstCompletionTimestamp := 0;
    State^.LastCompletionTimestamp := 0;
    State^.FrameCount := 0;
    State := State^.Next;
  end;
end;

procedure DiscardOutstandingCapture;
var
  Block: Pointer;
begin
  while InterlockedCompareExchange(ActiveHooks, 0, 0) <> 0 do
    ThreadSwitch;
  EventMemory.SealCurrentBlock(True);
  repeat
    Block := EventMemory.TakeCompletedBlock;
    if Block <> nil then
      EventMemory.RecycleCompletedBlock(Block)
    else if EventMemory.SealedBlockCount <> 0 then
      RTLEventWaitFor(WorkerWakeEvent);
  until (Block = nil) and (EventMemory.SealedBlockCount = 0);
end;

procedure StopCapture;
var
  StopTimestamp: QWord;
begin
  if InterlockedExchange(CaptureEnabled, 0) = 0 then
    Exit;
  StopTimestamp := Timestamp;
  DiscardOutstandingCapture;
  EnterCriticalSection(WriterLock);
  try
    ResetThreadCaptureLocked;
    if Writer <> nil then
      Writer.Finish(StopTimestamp, 0);
    Writer.Free;
    Writer := TNXProfileWriter.Create(EventMemory);
  finally
    LeaveCriticalSection(WriterLock);
  end;
end;

procedure StartCapture;
begin
  if (CaptureEnabled <> 0) or (ShuttingDown <> 0) then
    Exit;
  EnterCriticalSection(WriterLock);
  try
    StartWriterLocked;
    InterlockedExchange(CaptureEnabled, 1);
  finally
    LeaveCriticalSection(WriterLock);
  end;
end;

function ControlWindowProc(AWindow: HWND; AMessage: UINT;
  AWParam: WPARAM; ALParam: LPARAM): LRESULT; stdcall;
begin
  if AMessage = StartControlMessage then
  begin
    StartCapture;
    Exit(1);
  end;
  if AMessage = StopControlMessage then
  begin
    StopCapture;
    Exit(1);
  end;
  Result := DefWindowProcA(AWindow, AMessage, AWParam, ALParam);
end;

function CreateControlWindow: HWND;
var
  WindowClass: WNDCLASSA;
  Instance: HINST;
  Title: array[0..63] of AnsiChar;
begin
  Result := 0;
  Instance := GetModuleHandleA(nil);
  FillChar(WindowClass, SizeOf(WindowClass), 0);
  WindowClass.lpfnWndProc := @ControlWindowProc;
  WindowClass.hInstance := Instance;
  WindowClass.lpszClassName := NXP_CONTROL_CLASS;
  if RegisterClassA(@WindowClass) = 0 then
    Exit;
  BuildControlWindowTitle(Title, GetCurrentProcessId);
  Result := CreateWindowExA(0, NXP_CONTROL_CLASS, @Title[0], 0,
    0, 0, 0, 0, 0, 0, Instance, nil);
  if Result = 0 then
    UnregisterClassA(NXP_CONTROL_CLASS, Instance);
end;

procedure DestroyControlWindow;
var
  Instance: HINST;
begin
  Instance := GetModuleHandleA(nil);
  if ControlWindow <> 0 then
  begin
    DestroyWindow(ControlWindow);
    ControlWindow := 0;
  end;
  UnregisterClassA(NXP_CONTROL_CLASS, Instance);
end;

procedure PumpControlMessages;
var
  MessageData: TMsg;
begin
  while PeekMessageA(MessageData, ControlWindow, 0, 0, PM_REMOVE) do
  begin
    TranslateMessage(MessageData);
    DispatchMessageA(MessageData);
  end;
end;

function WriterThreadMain(Parameter: Pointer): PtrInt;
var
  Block: Pointer;
  BlocksProcessed: LongInt;
  WakeHandle: THandle;
begin
  ControlWindow := CreateControlWindow;
  RTLEventSetEvent(WorkerControlReadyEvent);
  WakeHandle := THandle(PtrUInt(WorkerWakeEvent));
  repeat
    PumpControlMessages;
    BlocksProcessed := 0;
    while BlocksProcessed < NXP_WORKER_BLOCK_BATCH do
    begin
      Block := EventMemory.TakeCompletedBlock;
      if Block = nil then
        Break;
      ProcessCompletedBlock(Block);
      Inc(BlocksProcessed);
    end;
    if (WorkerStop <> 0) and (EventMemory.SealedBlockCount = 0) then
      Break;
    if BlocksProcessed = NXP_WORKER_BLOCK_BATCH then
      ThreadSwitch
    else
      MsgWaitForMultipleObjects(1, WakeHandle, False, DWord(-1),
        QS_ALLINPUT);
  until False;
  EnterCriticalSection(WriterLock);
  try
    FlushAllStatesLocked;
  finally
    LeaveCriticalSection(WriterLock);
  end;
  DestroyControlWindow;
  Result := 0;
end;

procedure EnsureRuntime;
begin
  if RuntimeInitialized <> 0 then
    Exit;
  ProcessHeap := GetProcessHeap;
  InitCriticalSection(WriterLock);
  EventMemory := TNXEventMemory.Create;
  Writer := TNXProfileWriter.Create(EventMemory);
  StartControlMessage := RegisterWindowMessageA(NXP_START_MESSAGE_NAME);
  StopControlMessage := RegisterWindowMessageA(NXP_STOP_MESSAGE_NAME);
  QueryPerformanceFrequency(CounterFrequency);
  RuntimeHealthy := 1;
  if (StartControlMessage = 0) or (StopControlMessage = 0) then
    RuntimeHealthy := 0;
  FlsIndex := FlsAlloc(nil);
  if FlsIndex = FLS_OUT_OF_INDEXES then
    RuntimeHealthy := 0;
  RuntimeInitialized := 1;
end;

procedure StartRuntime;
var
  InitialPause: Boolean;
begin
  EnsureRuntime;
  if RuntimeHealthy = 0 then
    Exit;
  InitialPause := StartsPaused;
  WorkerWakeEvent := RTLEventCreate;
  WorkerControlReadyEvent := RTLEventCreate;
  EventMemory.SetCompletionEvent(WorkerWakeEvent);
  WorkerThread := BeginThread(@WriterThreadMain, nil);
  if WorkerThread = 0 then
  begin
    RuntimeHealthy := 0;
    Exit;
  end;
  WorkerStarted := True;
  RTLEventWaitFor(WorkerControlReadyEvent);
  if ControlWindow = 0 then
  begin
    RuntimeHealthy := 0;
    Exit;
  end;
  if not InitialPause then
    StartCapture;
  RTLEventSetEvent(WorkerWakeEvent);
end;

function AllocateThreadState: PNXPThreadState;
var
  OldRoot: Pointer;
begin
  Result := HeapAlloc(ProcessHeap, HEAP_ZERO_MEMORY, SizeOf(TNXPThreadState));
  if Result = nil then
    Exit;
  Result^.ThreadId := GetCurrentThreadId;
  Result^.StartTimestamp := Timestamp;
  if not FlsSetValue(FlsIndex, Result) then
  begin
    HeapFree(ProcessHeap, 0, Result);
    Exit(nil);
  end;
  repeat
    OldRoot := ThreadRoot;
    Result^.Next := PNXPThreadState(OldRoot);
  until InterlockedCompareExchangePointer(ThreadRoot, Result, OldRoot) = OldRoot;
end;

function ThreadState: PNXPThreadState; inline;
begin
  Result := nil;
  if FlsIndex = FLS_OUT_OF_INDEXES then
    Exit;
  Result := PNXPThreadState(FlsGetValue(FlsIndex));
  if Result = nil then
    Result := AllocateThreadState;
end;

procedure RecordEvent(Descriptor: PNXPProcedureDescriptor; Kind: Byte);
var
  State: PNXPThreadState;
  Capture: PNXProfileCaptureRecord;
begin
  if (RuntimeHealthy = 0) or (ShuttingDown <> 0) or
     (CaptureEnabled = 0) or
     (Descriptor = nil) or (Descriptor^.RuntimeId = 0) then
    Exit;
  InterlockedIncrement(ActiveHooks);
  if (CaptureEnabled = 0) or (ShuttingDown <> 0) then
  begin
    InterlockedDecrement(ActiveHooks);
    Exit;
  end;
  State := ThreadState;
  if (State = nil) or (State^.Guard <> 0) then
  begin
    InterlockedDecrement(ActiveHooks);
    Exit;
  end;
  State^.Guard := 1;
  Capture := Writer.AcquireRecord;
  if Capture = nil then
  begin
    State^.Guard := 0;
    InterlockedDecrement(ActiveHooks);
    Exit;
  end;
  Capture^.Context := State;
  Capture^.Event := Default(TNXProfileEvent);
  Capture^.Event.Kind := Kind;
  Capture^.Event.ProcedureId := Descriptor^.RuntimeId;
  Capture^.Event.Timestamp := Timestamp;
  Writer.FinalizeRecord(Capture);
  State^.Guard := 0;
  InterlockedDecrement(ActiveHooks);
end;

procedure nxp_enter(ProcedureDescriptor: Pointer); cdecl;
  [public,alias:'nxp_enter'];
begin
  RecordEvent(PNXPProcedureDescriptor(ProcedureDescriptor), nxpeEnter);
end;

procedure nxp_leave(ProcedureDescriptor: Pointer); cdecl;
  [public,alias:'nxp_leave'];
begin
  RecordEvent(PNXPProcedureDescriptor(ProcedureDescriptor), nxpeLeave);
end;

procedure nxp_unwind(ProcedureDescriptor: Pointer; EstablisherFrame: PtrUInt;
  ExceptionFlags: DWord); cdecl; [public,alias:'nxp_unwind'];
begin
  RecordEvent(PNXPProcedureDescriptor(ProcedureDescriptor), nxpeUnwind);
end;

procedure RegisterProceduresLocked(AModule: PNXPRuntimeModule;
  Descriptor: PNXPModuleDescriptor);
var
  Cursor, Limit: PByte;
  ProcDescriptor: PNXPProcedureDescriptor;
  RuntimeProcedure: PNXPRuntimeProcedure;
begin
  Cursor := Descriptor^.DescriptorStart;
  Limit := Descriptor^.DescriptorEnd;
  while (Cursor <> nil) and
        (PtrUInt(Limit) - PtrUInt(Cursor) >= SizeOf(TNXPProcedureDescriptor)) do
  begin
    ProcDescriptor := PNXPProcedureDescriptor(Cursor);
    if (ProcDescriptor^.Magic <> NXP_DESC_MAGIC) or
       (ProcDescriptor^.AbiVersion <> NXP_DESC_ABI) then
      Break;
    SetLength(Procedures, Length(Procedures) + 1);
    RuntimeProcedure := @Procedures[High(Procedures)];
    RuntimeProcedure^ := Default(TNXPRuntimeProcedure);
    RuntimeProcedure^.Descriptor := ProcDescriptor;
    Inc(NextProcedureId);
    ProcDescriptor^.RuntimeId := NextProcedureId;
    RuntimeProcedure^.Info.ProcedureId := NextProcedureId;
    RuntimeProcedure^.Info.ModuleId := AModule^.ModuleId;
    RuntimeProcedure^.Info.Flags := ProcDescriptor^.Flags;
    RuntimeProcedure^.Info.StableId := ProcDescriptor^.StableId;
    RuntimeProcedure^.Info.CodeStart := PtrUInt(
      ProcDescriptor^.CodeStart);
    RuntimeProcedure^.Info.CodeEnd := PtrUInt(ProcDescriptor^.CodeEnd);
    RuntimeProcedure^.Info.SourceLine := ProcDescriptor^.SourceLine;
    RuntimeProcedure^.Info.SourceColumn := ProcDescriptor^.SourceColumn;
    RuntimeProcedure^.Info.Name := OwnString(ProcDescriptor^.Name);
    RuntimeProcedure^.Info.UnitName := OwnString(
      ProcDescriptor^.UnitName);
    RuntimeProcedure^.Info.SourceFile := OwnString(
      ProcDescriptor^.SourceFile);
    if Writer <> nil then
      WriteProcedureLocked(RuntimeProcedure);
    Inc(Cursor, SizeOf(TNXPProcedureDescriptor));
  end;
end;

procedure nxp_module_register(ModuleDescriptor: Pointer); cdecl;
  [public,alias:'nxp_module_register'];
var
  Descriptor: PNXPModuleDescriptor;
  RuntimeModule: PNXPRuntimeModule;
begin
  EnsureRuntime;
  if RuntimeHealthy = 0 then
    Exit;
  Descriptor := PNXPModuleDescriptor(ModuleDescriptor);
  if (Descriptor = nil) or (Descriptor^.Magic <> NXP_MODULE_MAGIC) or
     (Descriptor^.AbiVersion <> NXP_MODULE_ABI) then
    Exit;
  EnterCriticalSection(WriterLock);
  try
    if FindModule(Descriptor) <> nil then
      Exit;
    SetLength(Modules, Length(Modules) + 1);
    RuntimeModule := @Modules[High(Modules)];
    RuntimeModule^ := Default(TNXPRuntimeModule);
    RuntimeModule^.Descriptor := Descriptor;
    Inc(NextModuleId);
    RuntimeModule^.ModuleId := NextModuleId;
    RuntimeModule^.ImageBase := ModuleBaseFor(Descriptor);
    RuntimeModule^.BuildId := ModuleBuildId(RuntimeModule^.ImageBase);
    RuntimeModule^.ImagePath := OwnString(ModulePath(RuntimeModule^.ImageBase));
    RuntimeModule^.Active := True;
    RuntimeModule^.LoadTimestamp := Timestamp;
    WriteModuleLocked(RuntimeModule);
    RegisterProceduresLocked(RuntimeModule, Descriptor);
    RegisteredDescriptor := Descriptor;
  finally
    LeaveCriticalSection(WriterLock);
  end;
end;

procedure nxp_module_unregister(ModuleDescriptor: Pointer); cdecl;
  [public,alias:'nxp_module_unregister'];
var
  RuntimeModule: PNXPRuntimeModule;
begin
  EnterCriticalSection(WriterLock);
  try
    RuntimeModule := FindModule(PNXPModuleDescriptor(ModuleDescriptor));
    if (RuntimeModule <> nil) and RuntimeModule^.Active then
    begin
      RuntimeModule^.Active := False;
      if Writer <> nil then
        Writer.WriteModuleUnload(RuntimeModule^.ModuleId, 0, Timestamp);
    end;
  finally
    LeaveCriticalSection(WriterLock);
  end;
end;

procedure nxp_flush; cdecl; [public,alias:'nxp_flush'];
begin
  if (RuntimeInitialized = 0) or (EventMemory = nil) then
    Exit;
  EventMemory.SealCurrentBlock(True);
  if WorkerWakeEvent <> nil then
    RTLEventSetEvent(WorkerWakeEvent);
  while EventMemory.SealedBlockCount <> 0 do
    ThreadSwitch;
  EnterCriticalSection(WriterLock);
  try
    FlushAllStatesLocked;
    if Writer <> nil then
      Writer.Flush;
  finally
    LeaveCriticalSection(WriterLock);
  end;
end;

procedure FreeThreadStorage;
var
  State, Next: PNXPThreadState;
begin
  State := PNXPThreadState(ThreadRoot);
  while State <> nil do
  begin
    Next := State^.Next;
    if State^.Frames <> nil then
      HeapFree(ProcessHeap, 0, State^.Frames);
    HeapFree(ProcessHeap, 0, State);
    State := Next;
  end;
  ThreadRoot := nil;
end;

procedure nxp_shutdown; cdecl; [public,alias:'nxp_shutdown'];
var
  OldFlsIndex: DWord;
begin
  if InterlockedExchange(ShuttingDown, 1) <> 0 then
    Exit;
  InterlockedExchange(CaptureEnabled, 0);
  while InterlockedCompareExchange(ActiveHooks, 0, 0) <> 0 do
    ThreadSwitch;
  if EventMemory <> nil then
    EventMemory.SealCurrentBlock(False);
  InterlockedExchange(WorkerStop, 1);
  if WorkerWakeEvent <> nil then
    RTLEventSetEvent(WorkerWakeEvent);
  if WorkerStarted then
  begin
    WaitForThreadTerminate(WorkerThread, DWord(-1));
    CloseThread(WorkerThread);
    WorkerStarted := False;
  end;
  EnterCriticalSection(WriterLock);
  try
    if Writer <> nil then
      Writer.Finish(Timestamp, 0);
    Writer.Free;
    Writer := nil;
  finally
    LeaveCriticalSection(WriterLock);
  end;
  if EventMemory <> nil then
    EventMemory.SetCompletionEvent(nil);
  if WorkerWakeEvent <> nil then
  begin
    RTLEventDestroy(WorkerWakeEvent);
    WorkerWakeEvent := nil;
  end;
  if WorkerControlReadyEvent <> nil then
  begin
    RTLEventDestroy(WorkerControlReadyEvent);
    WorkerControlReadyEvent := nil;
  end;
  OldFlsIndex := FlsIndex;
  FlsIndex := FLS_OUT_OF_INDEXES;
  if OldFlsIndex <> FLS_OUT_OF_INDEXES then
    FlsFree(OldFlsIndex);
  FreeThreadStorage;
  EventMemory.Free;
  EventMemory := nil;
  DoneCriticalSection(WriterLock);
  RuntimeHealthy := 0;
end;

initialization
  StartRuntime;

finalization
  if RuntimeInitialized <> 0 then
  begin
    if RegisteredDescriptor <> nil then
      nxp_module_unregister(RegisteredDescriptor);
    nxp_shutdown;
  end;

end.
