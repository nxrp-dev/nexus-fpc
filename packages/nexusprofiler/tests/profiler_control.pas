program profiler_control;

{$mode objfpc}{$H+}

uses
  Windows,
  SysUtils;

const
  ControlClass: PAnsiChar = 'NexusFPCProfilerControl';
  StartMessageName: PAnsiChar = 'NexusFPCProfiler.Start';
  StopMessageName: PAnsiChar = 'NexusFPCProfiler.Stop';

procedure FirstIntervalLeaf(var Value: QWord); noinline;
begin
  Inc(Value);
end;

procedure PausedLeaf(var Value: QWord); noinline;
begin
  Inc(Value);
end;

procedure SecondIntervalLeaf(var Value: QWord); noinline;
begin
  Inc(Value);
end;

procedure FirstIntervalWork; noinline;
var
  Value: QWord;
  Index: LongInt;
begin
  Value := 0;
  for Index := 1 to 8000 do
    FirstIntervalLeaf(Value);
  if Value <> 8000 then
    Halt(10);
end;

procedure PausedWork; noinline;
var
  Value: QWord;
  Index: LongInt;
begin
  Value := 0;
  for Index := 1 to 8000 do
    PausedLeaf(Value);
  if Value <> 8000 then
    Halt(11);
end;

procedure SecondIntervalWork; noinline;
var
  Value: QWord;
  Index: LongInt;
begin
  Value := 0;
  for Index := 1 to 8000 do
    SecondIntervalLeaf(Value);
  if Value <> 8000 then
    Halt(12);
end;

function FindControlWindow: HWND;
var
  Title: AnsiString;
  Attempts: LongInt;
begin
  Title := 'NexusFPCProfiler-' + IntToStr(GetCurrentProcessId);
  for Attempts := 1 to 500 do
  begin
    Result := FindWindowA(ControlClass, PAnsiChar(Title));
    if Result <> 0 then
      Exit;
    Sleep(10);
  end;
  Result := 0;
end;

var
  Window: HWND;
  StartMessage: UINT;
  StopMessage: UINT;
begin
  Window := FindControlWindow;
  if Window = 0 then
    Halt(20);
  StartMessage := RegisterWindowMessageA(StartMessageName);
  StopMessage := RegisterWindowMessageA(StopMessageName);
  if (StartMessage = 0) or (StopMessage = 0) then
    Halt(21);

  PausedWork;
  if SendMessageA(Window, StartMessage, 0, 0) <> 1 then
    Halt(22);
  FirstIntervalWork;
  Sleep(250);
  if SendMessageA(Window, StopMessage, 0, 0) <> 1 then
    Halt(23);

  PausedWork;
  if SendMessageA(Window, StartMessage, 0, 0) <> 1 then
    Halt(24);
  SecondIntervalWork;
  Sleep(250);
  if SendMessageA(Window, StopMessage, 0, 0) <> 1 then
    Halt(25);
end.
