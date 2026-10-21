// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
unit utDwarfRangesFixture;
{$mode objfpc}{$H+}
interface
function FirstValue: LongInt;
function SecondValue: LongInt;
{$if defined(INCLUDE_UNUSED_RANGE) or defined(KEEP_UNUSED_RANGE)}
function UnusedValue: LongInt;
{$endif}
implementation
function FirstValue: LongInt;
begin
  Result := 1;
end;
function SecondValue: LongInt;
begin
  Result := 2;
end;
{$if defined(INCLUDE_UNUSED_RANGE) or defined(KEEP_UNUSED_RANGE)}
function UnusedValue: LongInt;
begin
  Result := 3;
end;
{$endif}
end.
