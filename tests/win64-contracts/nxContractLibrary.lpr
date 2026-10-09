{ Copyright (c) 2026 Kevin Collins.

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is "Incompatible With Secondary Licenses",
as defined by the Mozilla Public License, v. 2.0.

SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
library nxContractLibrary;
{$mode objfpc}{$H+}
uses Windows, SysUtils, tpNXContractState, utNXContractLifecycle;
{$R fixture.res}
const
{$ifdef MODULE_TWO}
  cIdentity = 2;
{$else}
  cIdentity = 1;
{$endif}
type
  TNXCallback = function(AValue: Int64): Int64; cdecl;
var
  ExportedValue: Int64 = 123456789;
  ValuePointer: PInt64 = @ExportedValue;
  ZeroStorage: array[0..131071] of Byte;
threadvar
  ThreadValue: Int64;

function StaticStorage: LongInt; cdecl;
var
  lIndex: LongInt;
  lResource: HRSRC;
  lBytes: PWord;
begin
  Result := 0;
  if (InitOrder <> 12) or (ValuePointer <> @ExportedValue) or
    (ValuePointer^ <> 123456789) then Exit;
  for lIndex := Low(ZeroStorage) to High(ZeroStorage) do
    if ZeroStorage[lIndex] <> 0 then Exit;
  ZeroStorage[High(ZeroStorage)] := 7;
  ZeroStorage[High(ZeroStorage)] := 0;
  lResource := FindResource(HInstance, MAKEINTRESOURCE(101), RT_RCDATA);
  if (lResource = 0) or (SizeofResource(HInstance, lResource) <> 2) then Exit;
  lBytes := LockResource(LoadResource(HInstance, lResource));
  if (lBytes = nil) or (lBytes^ <> cIdentity) then Exit;
  Result := cIdentity;
end;

function ExchangeThread(AValue: Int64): Int64; cdecl;
begin
  Result := ThreadValue;
  ThreadValue := AValue;
end;

function MixedArguments(AFirst: Int64; ASecond: Double; AThird: Int64;
  AFourth: Double; AFifth: Int64): Double; cdecl;
begin
  Result := AFirst + ASecond * 2 + AThird * 3 + AFourth * 4 + AFifth * 5;
end;

function PairResult(AValue: Int64): TNXPair; cdecl;
begin
  Result.First := AValue;
  Result.Second := AValue + 17;
end;

function InvokeCallback(ACallback: TNXCallback; AValue: Int64): Int64; cdecl;
begin
  Result := ACallback(AValue) + 1;
end;

function ExceptionUnwind: LongInt; cdecl;
var
  lFinally: LongInt;
begin
  lFinally := 0;
  Result := 0;
  try
    try
      raise Exception.Create('contract exception');
    finally
      Inc(lFinally);
    end;
  except
    on Exception do Result := lFinally;
  end;
end;

procedure SetFinalDestination(ADestination: PLongInt); cdecl;
begin
  FinalOrder := ADestination;
end;

exports
  StaticStorage index 7, ExchangeThread, MixedArguments, PairResult,
  InvokeCallback, ExceptionUnwind, SetFinalDestination, ExportedValue;
begin
end.
