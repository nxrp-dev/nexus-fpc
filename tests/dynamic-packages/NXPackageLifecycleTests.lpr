(*
  Copyright (c) 2026 Kevin Collins.

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at https://mozilla.org/MPL/2.0/.

  This Source Code Form is "Incompatible With Secondary Licenses",
  as defined by the Mozilla Public License, v. 2.0.

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
