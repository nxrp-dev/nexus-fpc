program NXClangBackendTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads, cwstring,{$ENDIF}
  obNXTestRegistry, utNXTestConsole, tsNXClangContracts;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    RegisterClangContractTests(lRegistry);
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
