{ Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
program nxLinuxExports;
{$mode objfpc}{$H+}
uses utNXLinuxExports;
function Marker(Value: LongInt): LongInt; cdecl; external name 'NX_LinuxMarker';
function AutomaticMarker: LongInt; cdecl; external name 'NX_LinuxAutomatic';
var
  Data: LongInt; external name 'NX_LinuxData';
function MainMarker: LongInt; cdecl;
begin
  Result := 99;
end;
exports MainMarker name 'NX_LinuxMain';
begin
  if (Marker(5) <> 47) or (AutomaticMarker() <> 77) then Halt(3);
  if Data <> 1234 then Halt(4);
  Data := 4321;
  if Data <> 4321 then Halt(5);
  WriteLn('PASS Linux unit function aliases and writable data');
end.
