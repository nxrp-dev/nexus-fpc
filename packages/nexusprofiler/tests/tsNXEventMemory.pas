unit tsNXEventMemory;

{$mode objfpc}{$H+}

interface
uses obNXTestRegistry;
procedure RegistertsNXEventMemoryTests(ARegistry: TNXTestRegistry);
implementation

uses
  obNXTestContext, obNXTestSuite,
  NXProfile;

const
  ProducerCount = 8;
  RecordsPerProducer = 100000;

type
  PProducerInfo = ^TProducerInfo;
  TProducerInfo = record
    Memory: TNXEventMemory;
    ProducerId: LongInt;
  end;

var
  StressMemory: TNXEventMemory;
  StressEvent: PRTLEvent;
  ConsumerThread: TThreadID;
  StopConsumer: LongInt;
  ConsumedRecords: Int64;


function Consumer(Parameter: Pointer): PtrInt;
var
  Block: Pointer;
begin
  repeat
    repeat
      Block := StressMemory.TakeCompletedBlock;
      if Block <> nil then
      begin
        InterlockedExchangeAdd64(ConsumedRecords,
          StressMemory.CompletedRecordCount(Block));
        StressMemory.RecycleCompletedBlock(Block);
      end;
    until Block = nil;
    if (StopConsumer <> 0) and
       (StressMemory.SealedBlockCount = 0) then
      Break;
    RTLEventWaitFor(StressEvent);
  until False;
  Result := 0;
end;

function Producer(Parameter: Pointer): PtrInt;
var
  Info: PProducerInfo;
  Index: LongInt;
  RecordData: PNXProfileCaptureRecord;
begin
  Info := PProducerInfo(Parameter);
  for Index := 1 to RecordsPerProducer do
  begin
    RecordData := Info^.Memory.AcquireRecord;
    RecordData^.Context := Pointer(PtrUInt(Info^.ProducerId));
    RecordData^.Event := Default(TNXProfileEvent);
    RecordData^.Event.Kind := nxpeEnter;
    RecordData^.Event.ProcedureId := Index;
    RecordData^.Event.Timestamp := Index;
    Info^.Memory.FinalizeRecord(RecordData);
  end;
  Result := 0;
end;

procedure TestPartialBlock(AContext: TNXTestContext);
var
  Memory: TNXEventMemory;
  RecordData: PNXProfileCaptureRecord;
  Block: Pointer;
begin
  Memory := TNXEventMemory.Create(4);
  try
    RecordData := Memory.AcquireRecord;
    RecordData^.Event := Default(TNXProfileEvent);
    RecordData^.Event.ProcedureId := 42;
    Memory.FinalizeRecord(RecordData);
    Memory.SealCurrentBlock(False);
    AContext.AssertTrue(Memory.SealedBlockCount = 1,
      'Partial block was not sealed');
    Block := Memory.TakeCompletedBlock;
    AContext.AssertTrue(Block <> nil, 'Partial block was not published');
    AContext.AssertTrue(Memory.CompletedRecordCount(Block) = 1,
      'Partial block record count is wrong');
    AContext.AssertTrue(Memory.CompletedRecord(Block, 0)^.Event.ProcedureId = 42,
      'Partial block record contents are wrong');
    Memory.RecycleCompletedBlock(Block);
    AContext.AssertTrue(Memory.SealedBlockCount = 0,
      'Partial block remained sealed after recycling');
    AContext.AssertTrue(Memory.AvailableBlockCount = 1,
      'Partial block was not made available for reuse');
  finally
    Memory.Free;
  end;
end;

procedure TestIssuedFinishedAndReuse(AContext: TNXTestContext);
var
  Memory: TNXEventMemory;
  Records: array[0..3] of PNXProfileCaptureRecord;
  Block: Pointer;
  Index: LongInt;
begin
  Memory := TNXEventMemory.Create(4);
  try
    for Index := 0 to 3 do
    begin
      Records[Index] := Memory.AcquireRecord;
      Records[Index]^.Event := Default(TNXProfileEvent);
      Records[Index]^.Event.ProcedureId := Index + 1;
    end;
    for Index := 1 to 3 do
      Memory.FinalizeRecord(Records[Index]);
    AContext.AssertTrue(Memory.TakeCompletedBlock = nil,
      'Block published before the first issued record finished');
    Memory.FinalizeRecord(Records[0]);
    Block := Memory.TakeCompletedBlock;
    AContext.AssertTrue(Block <> nil, 'Completed full block was not published');
    AContext.AssertTrue(Memory.TakeCompletedBlock = nil,
      'Completed block was published more than once');
    Memory.RecycleCompletedBlock(Block);
    AContext.AssertTrue(Memory.AllocatedBlockCount = 2,
      'Unexpected block count before reuse');

    for Index := 0 to 3 do
    begin
      Records[Index] := Memory.AcquireRecord;
      Records[Index]^.Event := Default(TNXProfileEvent);
      Memory.FinalizeRecord(Records[Index]);
    end;
    AContext.AssertTrue(Memory.AllocatedBlockCount = 2,
      'Reusable block was not selected during rotation');
    Block := Memory.TakeCompletedBlock;
    AContext.AssertTrue(Block <> nil, 'Reused block did not complete');
    Memory.RecycleCompletedBlock(Block);
    Memory.SealCurrentBlock(False);
  finally
    Memory.Free;
  end;
end;

procedure TestConcurrentProducers(AContext: TNXTestContext);
var
  ProducerInfo: array[0..ProducerCount - 1] of TProducerInfo;
  ProducerThreads: array[0..ProducerCount - 1] of TThreadID;
  Index: LongInt;
begin
  ConsumedRecords := 0;
  StopConsumer := 0;
  StressMemory := TNXEventMemory.Create(8);
  StressEvent := RTLEventCreate;
  StressMemory.SetCompletionEvent(StressEvent);
  ConsumerThread := BeginThread(@Consumer, nil);
  for Index := 0 to ProducerCount - 1 do
  begin
    ProducerInfo[Index].Memory := StressMemory;
    ProducerInfo[Index].ProducerId := Index + 1;
    ProducerThreads[Index] := BeginThread(@Producer, @ProducerInfo[Index]);
  end;
  for Index := 0 to ProducerCount - 1 do
  begin
    WaitForThreadTerminate(ProducerThreads[Index], -1);
    CloseThread(ProducerThreads[Index]);
  end;
  StressMemory.SealCurrentBlock(False);
  InterlockedExchange(StopConsumer, 1);
  RTLEventSetEvent(StressEvent);
  WaitForThreadTerminate(ConsumerThread, -1);
  CloseThread(ConsumerThread);
  AContext.AssertTrue(ConsumedRecords = Int64(ProducerCount) * RecordsPerProducer,
    'Concurrent producer record count is wrong');
  AContext.AssertTrue(StressMemory.SealedBlockCount = 0,
    'Concurrent test left sealed blocks');
  StressMemory.SetCompletionEvent(nil);
  RTLEventDestroy(StressEvent);
  StressMemory.Free;
  StressMemory := nil;
end;

procedure TestAvailableBlockLimit(AContext: TNXTestContext);
const
  RecordCount = 70;
var
  Memory: TNXEventMemory;
  RecordData: PNXProfileCaptureRecord;
  Blocks: array[0..RecordCount - 1] of Pointer;
  Index: LongInt;
begin
  Memory := TNXEventMemory.Create(1);
  try
    for Index := 0 to RecordCount - 1 do
    begin
      RecordData := Memory.AcquireRecord;
      RecordData^.Event := Default(TNXProfileEvent);
      Memory.FinalizeRecord(RecordData);
    end;
    AContext.AssertTrue(Memory.AllocatedBlockCount = RecordCount + 1,
      'Block growth count is wrong');
    for Index := 0 to RecordCount - 1 do
    begin
      Blocks[Index] := Memory.TakeCompletedBlock;
      AContext.AssertTrue(Blocks[Index] <> nil, 'Completed block is missing');
    end;
    for Index := 0 to RecordCount - 1 do
      Memory.RecycleCompletedBlock(Blocks[Index]);
    AContext.AssertTrue(Memory.AvailableBlockCount = 64,
      'Available block pool did not stop at its warm limit');
    AContext.AssertTrue(Memory.AllocatedBlockCount = 65,
      'Surplus blocks were not released');
  finally
    Memory.Free;
  end;
end;

procedure RegistertsNXEventMemoryTests(ARegistry: TNXTestRegistry);
var lSuite: TNXTestSuite;
begin
  lSuite := ARegistry.AddSuite('Profiler.EventMemory');
  lSuite.AddTest('TestPartialBlock', @TestPartialBlock, 'profiler');
  lSuite.AddTest('TestIssuedFinishedAndReuse', @TestIssuedFinishedAndReuse, 'profiler');
  lSuite.AddTest('TestAvailableBlockLimit', @TestAvailableBlockLimit, 'profiler');
  lSuite.AddTest('TestConcurrentProducers', @TestConcurrentProducers, 'concurrency');
end;

end.
