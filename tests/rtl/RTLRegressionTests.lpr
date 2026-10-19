program RTLRegressionTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, obNXTestRegistry, utNXTestConsole, tsNXRTLRegressions;
var lRegistry: TNXTestRegistry;
begin
  if ParamCount <> 4 then
  begin
    WriteLn(StdErr, 'Usage: RTLRegressionTests <source-root> <compiler> <matching-rtl> <external-output>');
    Halt(2);
  end;
  lRegistry := TNXTestRegistry.Create;
  try
    RegisterRTLRegressions(lRegistry, ExpandFileName(ParamStr(1)),
      ExpandFileName(ParamStr(2)), ExpandFileName(ParamStr(3)), ExpandFileName(ParamStr(4)));
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
