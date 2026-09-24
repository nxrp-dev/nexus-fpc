unit profiler_thread_unit;

{$mode objfpc}{$H+}

interface

uses
  Windows;

function ThreadRecursiveWork(Value: LongInt): LongInt; noinline;
function FpcWorker(Data: Pointer): PtrInt;
function ForeignWorker(Data: Pointer): DWord; stdcall;

implementation

function ThreadRecursiveWork(Value: LongInt): LongInt;
begin
  if Value <= 0 then Exit(1);
  Result := ThreadRecursiveWork(Value - 1) + 1;
end;

function FpcWorker(Data: Pointer): PtrInt;
var
  I: LongInt;
begin
  for I := 1 to 20000 do
    ThreadRecursiveWork(2);
  Result := 0;
end;

function ForeignWorker(Data: Pointer): DWord; stdcall;
var
  I: LongInt;
begin
  for I := 1 to 20000 do
    ThreadRecursiveWork(2);
  Result := 0;
end;

end.
