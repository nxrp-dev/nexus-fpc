{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: GPL-2.0-or-later }
unit tpcompilerreal;

{$mode objfpc}{$H-}

interface

type
  { Constant evaluation follows the host's native precision. Official x86
    compilers must be built with a hardware Extended bootstrap compiler. }
  BestReal = Extended;
  PBestReal = ^BestReal;
{$ifdef FPC_HAS_TYPE_EXTENDED}
  BestRealRec = TExtended80Rec;
const
  BestRealHiddenBit = QWord($8000000000000000);
{$else}
  BestRealRec = TDoubleRec;
const
  BestRealHiddenBit = QWord($0010000000000000);
{$endif}

implementation
end.