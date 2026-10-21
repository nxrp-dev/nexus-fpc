{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
unit implicit_revision_user;
interface
uses implicit_revision_base;
function CurrentValue: LongInt;
implementation
function CurrentValue: LongInt;
begin
  CurrentValue := RevisionValue;
end;
initialization
  WriteLn('revision ', CurrentValue);
end.
