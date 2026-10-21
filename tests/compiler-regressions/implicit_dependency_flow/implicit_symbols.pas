{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
program implicit_symbols;
begin
  if DependencyValue <> 42 then Halt(1);
  WriteLn('PASS implicit symbols');
end.
