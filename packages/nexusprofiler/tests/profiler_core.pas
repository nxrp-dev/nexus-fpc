program profiler_core;

{$mode objfpc}{$H+}

uses
  profiler_core_unit;

var
  Value: LongInt;
  Instance: TProfiledObject;
begin
  if ExitWork(4) <> 5 then Halt(10);
  if RecursiveWork(4) <> 5 then Halt(11);
  if Overloaded(4) <> 6 then Halt(12);
  if Overloaded('four') <> 4 then Halt(13);
  if InlineWork(4) <> 7 then Halt(14);
  Value := 0;
  NestedWork(Value);
  AnonymousWork(Value);
  if Value <> 2 then Halt(15);
  AssemblyExcluded;
  Instance := TProfiledObject.Create;
  if ConstructedCount <> 1 then Halt(16);
  Instance.Free;
  if ConstructedCount <> 0 then Halt(17);
  if FinalizedCount <> 1 then Halt(18);
end.
