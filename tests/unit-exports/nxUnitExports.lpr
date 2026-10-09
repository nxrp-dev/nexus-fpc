{ Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
program nxUnitExports;
{$mode objfpc}{$H+}
uses Windows, SysUtils, utNXPrivateExports;
type
  TMarker = function(Value: LongInt): LongInt; cdecl;
  TSimpleMarker = function: LongInt; cdecl;
var
  ModuleHandle: HMODULE;
  Marker, OrdinalMarker: TMarker;
  AutomaticMarker, MainExport: TSimpleMarker;
  Data: PLongInt;
function MainMarker: LongInt; cdecl;
begin
  Result := 99;
end;
exports MainMarker name 'NX_MainMarker';
begin
  if ParamCount = 0 then
    ModuleHandle := GetModuleHandle(nil)
  else
    ModuleHandle := LoadLibrary(PChar(ParamStr(1)));
  if ModuleHandle = 0 then raise Exception.Create('Cannot load test image');
  try
    Marker := TMarker(GetProcAddress(ModuleHandle, 'NX_PrivateMarker'));
    OrdinalMarker := TMarker(GetProcAddress(ModuleHandle, PChar(PtrUInt(7))));
    AutomaticMarker := TSimpleMarker(GetProcAddress(ModuleHandle, 'NX_AutomaticMarker'));
    MainExport := TSimpleMarker(GetProcAddress(ModuleHandle, 'NX_MainMarker'));
    Data := PLongInt(GetProcAddress(ModuleHandle, 'NX_PrivateData'));
    if not Assigned(Marker) or not Assigned(OrdinalMarker) or
       not Assigned(AutomaticMarker) or not Assigned(MainExport) or not Assigned(Data) then
      raise Exception.Create('Missing export');
    if Pointer(Marker) <> Pointer(OrdinalMarker) then
      raise Exception.Create('Ordinal and name disagree');
    if (Marker(5) <> 47) or (OrdinalMarker(8) <> 50) or
       (AutomaticMarker() <> 77) or (MainExport() <> 99) then
      raise Exception.Create('Incorrect exported procedure');
    if Pointer(Data) <> Pointer(GetProcAddress(ModuleHandle, PChar(PtrUInt(9)))) then
      raise Exception.Create('Data ordinal and name disagree');
    if Data^ <> 1234 then raise Exception.Create('Incorrect exported data');
    Data^ := 4321;
    if Data^ <> 4321 then raise Exception.Create('Exported data is not writable');
    WriteLn('PASS exported procedures, ordinal, alias and writable data');
  finally
    if ParamCount <> 0 then FreeLibrary(ModuleHandle);
  end;
end.
