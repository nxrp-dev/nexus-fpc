(*
  Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
*)

program NXPackageLifecycleTests;

{$mode objfpc}{$H+}

uses
  obNXTestRegistry,
  utNXTestConsole,
  tsNXPackageLifecycle,
  tsNXMovePairs;

var
  lRegistry: TNXTestRegistry;

begin
  lRegistry := TNXTestRegistry.Create;
  try
    RegisterPackageLifecycleTests(lRegistry);
    RegisterMovePairTests(lRegistry);
    ExitCode := RunConsoleTests(lRegistry);
  finally
    lRegistry.Free;
  end;
end.
