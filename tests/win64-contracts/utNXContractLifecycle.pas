{ Copyright (c) 2026 Kevin Collins.
SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
unit utNXContractLifecycle;
{$mode objfpc}{$H+}
interface
uses tpNXContractState;
procedure Unreferenced; public name 'NX_DISCARD_ME';
implementation
procedure Unreferenced;
begin
  InitOrder := -999;
end;
initialization
  InitOrder := InitOrder * 10 + 2;
finalization
  if FinalOrder <> nil then FinalOrder^ := FinalOrder^ * 10 + 2;
end.
