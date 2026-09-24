unit profiler_smoke_unit;
{$mode objfpc}{$H+}
interface
function UsedWork(N: LongInt): LongInt; noinline;
function UnusedWork(N: LongInt): LongInt; noinline;
procedure RaiseAndCatch; noinline;
implementation
function UsedWork(N: LongInt): LongInt;
begin
  if N <= 1 then Exit(1);
  Result := N * UsedWork(N - 1);
end;
function UnusedWork(N: LongInt): LongInt;
begin
  Result := N + 99;
end;
procedure RaiseLeaf; noinline;
begin
  raise TObject.Create;
end;
procedure RaiseAndCatch; noinline;
begin
  try
    RaiseLeaf;
  except
  end;
end;
end.
