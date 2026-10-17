// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program NXSharedLibraryTests;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads, cwstring,{$ENDIF}
  SysUtils, obNXTestRegistry, utNXTestConsole, tsNXSharedLibraryTests;
var lRegistry: TNXTestRegistry;
begin
  if ParamCount <> 5 then
    raise Exception.Create('Usage: NXSharedLibraryTests compiler rtl output clang llvm-readobj');
  lRegistry := TNXTestRegistry.Create;
  try
    RegisterSharedLibraryTests(lRegistry, ParamStr(1), ParamStr(2),
      ParamStr(3), ParamStr(4), ParamStr(5));
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
