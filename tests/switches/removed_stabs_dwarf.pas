program RemovedSTABSDwarf;
{$mode objfpc}
{$inline off}
uses SysUtils;

procedure DebugMarker(Value: LongInt);
var
  LocalValue: LongInt;
  FunctionName, SourceName: ShortString;
  SourceLine: LongInt;
begin
  LocalValue := Value + 1;
  if not GetLineInfo(PtrUInt(@DebugMarker), FunctionName, SourceName, SourceLine) then
    Halt(1);
  if (ExtractFileName(SourceName) <> 'removed_stabs_dwarf.pas') or (SourceLine <= 0) then
    Halt(2);
  if LocalValue <> 42 then
    Halt(3);
  WriteLn('PASS: DWARF source locations and execution');
end;

begin
  DebugMarker(41);
end.
