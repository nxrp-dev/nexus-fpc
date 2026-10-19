{ Copyright (c) 2026 Kevin Collins.
SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
library nxLinuxExportsLibrary;
{$mode objfpc}{$H+}
uses utNXLinuxExports;
function MainMarker: LongInt; cdecl;
begin
  Result := 99;
end;
exports MainMarker name 'NX_LinuxMain';
begin
end.
