{ Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
unit tpNXContractState;
{$mode objfpc}{$H+}
interface
type
  TNXPair = record
    First, Second: Int64;
  end;
var
  InitOrder: LongInt;
  FinalOrder: PLongInt;
implementation
initialization
  InitOrder := 1;
finalization
  if FinalOrder <> nil then FinalOrder^ := FinalOrder^ * 10 + 1;
end.
