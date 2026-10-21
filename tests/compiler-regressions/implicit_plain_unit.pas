{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
unit implicit_plain_unit;
interface
const
  DependencyValue = 42;
implementation
initialization
  WriteLn('PASS implicit dependency initialized');
end.
