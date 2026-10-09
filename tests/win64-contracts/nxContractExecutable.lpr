{ Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
program nxContractExecutable;
{$mode objfpc}{$H+}
uses SysUtils, tpNXContractState, utNXContractLifecycle;
{$link foreign_bridge.obj}
type
  TNXCallback = procedure; cdecl;
procedure NXForeignFrame(ACallback: TNXCallback); cdecl; external;
function ImportedStorageOne: LongInt; cdecl; external 'nxContractOne.dll' name 'StaticStorage';
function ImportedStorageTwo: LongInt; cdecl; external 'nxContractTwo.dll' index 7;
var
  ImportedValue: Int64; external 'nxContractOne.dll' name 'ExportedValue';
  ZeroStorage: array[0..131071] of Byte;
  Initialized: Int64 = 42;
  StaticPointer: PInt64 = @Initialized;
  FinallyCount: LongInt;

procedure RaiseException; cdecl;
begin
  try
    raise Exception.Create('unwind through Clang frame');
  finally
    Inc(FinallyCount);
  end;
end;
var
  lIndex: LongInt;
begin
  if (InitOrder <> 12) or (StaticPointer <> @Initialized) or
    (StaticPointer^ <> 42) then Halt(1);
  for lIndex := Low(ZeroStorage) to High(ZeroStorage) do
    if ZeroStorage[lIndex] <> 0 then Halt(2);
  if (ImportedStorageOne <> 1) or (ImportedStorageTwo <> 2) or
    (ImportedValue <> 123456789) then Halt(5);
  try
    NXForeignFrame(@RaiseException);
    Halt(3);
  except
    on Exception do
      if FinallyCount <> 1 then Halt(4);
  end;
  WriteLn('PASS EXE storage, initialization, name/ordinal/data imports, unwind through Clang frame');
end.
