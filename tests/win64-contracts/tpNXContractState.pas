{ Copyright (c) 2026 Kevin Collins.
SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
}
unit tpNXContractState;
{$mode objfpc}{$H+}
interface
type
  TNXPair = record
    First, Second: Int64;
  end;
var
  InitOrder: LongInt;
  FinalOrder: PLongInt;
implementation
initialization
  InitOrder := 1;
finalization
  if FinalOrder <> nil then FinalOrder^ := FinalOrder^ * 10 + 1;
end.
