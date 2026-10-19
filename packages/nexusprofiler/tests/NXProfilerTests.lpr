program NXProfilerTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, obNXTestRegistry, utNXTestConsole, tsNXProfileFormat, tsNXEventMemory, tsNXProfileControl;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    if (ParamCount = 5) and (ParamStr(1) = 'control') then
      RegisterProfileControlTests(lRegistry)
    else if ParamCount = 0 then
    begin
      RegistertsNXProfileFormatTests(lRegistry);
      RegistertsNXEventMemoryTests(lRegistry);
    end
    else
    begin
      WriteLn(StdErr, 'Usage: NXProfilerTests [control <trace> <required-procedure> <forbidden-procedure> <forbidden-procedure>]');
      Halt(2);
    end;
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
