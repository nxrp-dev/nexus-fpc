// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program NXPackageStorageTests;
{$mode objfpc}{$H+}
uses obNXTestRegistry, utNXTestConsole, tsNXPackageStorageTests;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    RegisterPackageStorageTests(lRegistry);
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
