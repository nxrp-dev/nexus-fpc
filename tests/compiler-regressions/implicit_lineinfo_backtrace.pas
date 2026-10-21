{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
program implicit_lineinfo_backtrace;

procedure RaiseWithBacktrace;
begin
  RunError(216);
end;

begin
  RaiseWithBacktrace;
end.
