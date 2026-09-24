program profiler_threads;

{$mode objfpc}{$H+}

uses
  Windows,
  profiler_thread_unit;

var
  FpcHandle: TThreadID;
  ForeignHandle: THandle;
  ForeignId: DWord;
begin
  FpcHandle := BeginThread(@FpcWorker, nil);
  ForeignHandle := CreateThread(nil, 0, @ForeignWorker, nil, 0, ForeignId);
  if (FpcHandle = 0) or (ForeignHandle = 0) then Halt(10);
  WaitForSingleObject(THandle(FpcHandle), INFINITE);
  WaitForSingleObject(ForeignHandle, INFINITE);
  CloseHandle(THandle(FpcHandle));
  CloseHandle(ForeignHandle);
  ThreadRecursiveWork(4);
end.
