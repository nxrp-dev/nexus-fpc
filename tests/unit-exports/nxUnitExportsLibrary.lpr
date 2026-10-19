{ Copyright (c) 2026 Kevin Collins.
SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
library nxUnitExportsLibrary;
{$mode objfpc}{$H+}
uses utNXPrivateExports;
function MainMarker: LongInt; cdecl;
begin
  Result := 99;
end;
exports MainMarker name 'NX_MainMarker';
begin
end.
