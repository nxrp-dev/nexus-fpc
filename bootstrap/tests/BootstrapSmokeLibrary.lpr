(* Copyright (c) 2026 Kevin Collins.
   SPDX-License-Identifier: MPL-2.0-no-copyleft-exception *)
library BootstrapSmokeLibrary;

{$mode objfpc}{$H+}

uses Classes;

function ProbeValue: LongInt; cdecl;
var
  lValues: TStringList;
begin
  lValues := TStringList.Create;
  try
    lValues.Add('shared RTL');
    Result := 41 + lValues.Count;
  finally
    lValues.Free;
  end;
end;

exports ProbeValue;

begin
end.
