program profiler_benchmark_normal;

{$mode objfpc}

uses
  Windows,
  profiler_benchmark_unit;

const
  Iterations = 1000000;
  NestedIterations = 250000;
  ThreadIterations = 500000;

var
  StartStamp, EndStamp, Frequency: Int64;
  Index, Checksum: LongInt;
  ThreadSumA, ThreadSumB: LongInt;
  ThreadA, ThreadB: TThreadID;

function Worker(Parameter: Pointer): PtrInt;
var
  WorkerIndex, WorkerSum: LongInt;
begin
  WorkerSum := 0;
  for WorkerIndex := 1 to ThreadIterations do
    WorkerSum := WorkerSum + EmptyLeaf(WorkerIndex);
  PLongInt(Parameter)^ := WorkerSum;
  Result := 0;
end;
begin
  QueryPerformanceFrequency(Frequency);
  Checksum := 0;
  QueryPerformanceCounter(StartStamp);
  for Index := 1 to Iterations do
    Checksum := Checksum + EmptyLeaf(Index);
  QueryPerformanceCounter(EndStamp);
  WriteLn('leaf_ticks=', EndStamp - StartStamp);

  QueryPerformanceCounter(StartStamp);
  for Index := 1 to NestedIterations do
    Checksum := Checksum + NestedLeaf(Index);
  QueryPerformanceCounter(EndStamp);
  WriteLn('nested_ticks=', EndStamp - StartStamp);

  QueryPerformanceCounter(StartStamp);
  for Index := 1 to NestedIterations do
    Checksum := Checksum + RecursiveLeaf(8);
  QueryPerformanceCounter(EndStamp);
  WriteLn('recursive_ticks=', EndStamp - StartStamp);

  QueryPerformanceCounter(StartStamp);
  ThreadA := BeginThread(@Worker, @ThreadSumA);
  ThreadB := BeginThread(@Worker, @ThreadSumB);
  WaitForSingleObject(THandle(ThreadA), INFINITE);
  WaitForSingleObject(THandle(ThreadB), INFINITE);
  CloseHandle(THandle(ThreadA));
  CloseHandle(THandle(ThreadB));
  QueryPerformanceCounter(EndStamp);
  WriteLn('thread_ticks=', EndStamp - StartStamp);
  Checksum := Checksum + ThreadSumA + ThreadSumB;
  WriteLn('frequency=', Frequency);
  WriteLn('checksum=', Checksum);
end.
