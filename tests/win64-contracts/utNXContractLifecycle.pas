{ Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
unit utNXContractLifecycle;
{$mode objfpc}{$H+}
interface
uses tpNXContractState;
procedure Unreferenced; public name 'NX_DISCARD_ME';
implementation
procedure Unreferenced;
begin
  InitOrder := -999;
end;
initialization
  InitOrder := InitOrder * 10 + 2;
finalization
  if FinalOrder <> nil then FinalOrder^ := FinalOrder^ * 10 + 2;
end.
