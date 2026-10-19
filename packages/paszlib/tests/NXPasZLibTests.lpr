// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program NXPasZLibTests;
{$mode objfpc}{$H+}
uses
  {$ifdef UNIX}cthreads, cwstring,{$endif}
  obNXTestRegistry, utNXTestConsole, tsNXPasZLibTests, tsNXArchiveTests;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    RegisterPasZLibTests(lRegistry);
    RegisterArchiveTests(lRegistry);
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
