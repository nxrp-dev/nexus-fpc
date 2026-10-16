// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program FCLHashTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads, cwstring,{$ENDIF}
  obNXTestRegistry, utNXTestConsole,
  utestsha256,
  utestsha512,
  utestonetimepass,
  utestpem;
var
  lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    Registerutestsha256Tests(lRegistry);
    Registerutestsha512Tests(lRegistry);
    RegisterutestonetimepassTests(lRegistry);
    RegisterutestpemTests(lRegistry);
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
