{ Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
unit utNXLinuxExports;
{$mode objfpc}{$H+}
interface
implementation
var
  NX_LinuxData: LongInt = 1234; cvar;
function PrivateMarker(Value: LongInt): LongInt; cdecl;
begin
  Result := Value + 42;
end;
function AutomaticMarker: LongInt; cdecl;
begin
  Result := 77;
end;
function PlainMarker: LongInt; cdecl;
begin
  Result := 55;
end;
function DiscardMarker: LongInt; cdecl;
begin
  Result := -1;
end;
exports
  PrivateMarker name 'NX_LinuxMarker',
  AutomaticMarker name 'NX_LinuxAutomatic',
  NX_LinuxData,
  PlainMarker,
  PlainMarker name 'UTNXLINUXEXPORTS_$$_PLAINMARKER$$LONGINT';
end.
