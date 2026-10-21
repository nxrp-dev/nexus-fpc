{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
unit implicit_chain;
interface
uses implicit_chain_base;
const ChainResult = ChainValue;
implementation
initialization
  WriteLn('chain initialized');
finalization
  WriteLn('chain finalized');
end.
