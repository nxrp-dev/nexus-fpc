{$MODE OBJFPC}
program RemovedSSNames;

type
  TExample = object
    constructor Build;
    destructor Release;
  end;

constructor TExample.Build;
begin
end;

destructor TExample.Release;
begin
end;

var
  Example: TExample;

begin
  Example.Build;
  Example.Release;
end.
