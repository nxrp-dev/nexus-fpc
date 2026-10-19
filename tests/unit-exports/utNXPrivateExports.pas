{ Copyright (c) 2026 Kevin Collins.
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
