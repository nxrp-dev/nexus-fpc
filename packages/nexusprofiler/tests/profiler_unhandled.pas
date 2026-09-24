program profiler_unhandled;

{$mode objfpc}

procedure RaiseUnhandled; noinline;
begin
  raise TObject.Create;
end;

begin
  RaiseUnhandled;
end.
