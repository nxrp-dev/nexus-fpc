program NXPackageLifecycleTests;
{$mode objfpc}{$H+}
uses obNXTestRegistry, utNXTestConsole, tsNXPackageLifecycle;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    RegisterPackageLifecycleTests(lRegistry);
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
