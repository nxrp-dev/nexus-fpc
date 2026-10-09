{ Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
unit utNXPrivateExports;
{$mode objfpc}{$H+}
interface
implementation
var
  PrivateData: LongInt = 1234;
function PrivateMarker(Value: LongInt): LongInt; cdecl;
begin
  Result := Value + 42;
end;
function AutomaticMarker: LongInt; cdecl;
begin
  Result := 77;
end;
exports
  PrivateMarker index 7 name 'NX_PrivateMarker',
  PrivateData index 9 name 'NX_PrivateData',
  AutomaticMarker name 'NX_AutomaticMarker';
end.
