program profiler_smoke;
{$mode objfpc}{$H+}
uses
  profiler_smoke_unit;
begin
  if UsedWork(5) <> 120 then Halt(2);
  RaiseAndCatch;
end.
