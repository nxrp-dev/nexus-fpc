// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
library WindowsPathLibrary;
{$mode objfpc}{$H+}
{$linklib nxpath}
function PathValue: LongInt; cdecl; external name 'nx_path_value';
function SearchValue: LongInt; cdecl; external name 'nx_search_value';
function ExportValue: LongInt; cdecl;
begin
  Result := PathValue + SearchValue;
end;
exports ExportValue name 'nx_export_value';
begin
end.
