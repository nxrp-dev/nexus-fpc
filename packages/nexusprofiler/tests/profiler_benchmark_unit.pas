unit profiler_benchmark_unit;

{$mode objfpc}

interface

function EmptyLeaf(Value: LongInt): LongInt; noinline;
function NestedLeaf(Value: LongInt): LongInt; noinline;
function RecursiveLeaf(Value: LongInt): LongInt; noinline;

implementation

function EmptyLeaf(Value: LongInt): LongInt;
begin
  Result := Value + 1;
end;

function NestedLeaf(Value: LongInt): LongInt;
begin
  Result := EmptyLeaf(Value) + 1;
end;

function RecursiveLeaf(Value: LongInt): LongInt;
begin
  if Value = 0 then
    Exit(0);
  Result := RecursiveLeaf(Value - 1) + 1;
end;

end.
