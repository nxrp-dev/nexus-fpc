{ Copyright (c) 2026 Kevin Collins.
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
