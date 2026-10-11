{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: GPL-2.0-or-later }
unit utcurrencyparse;
{$mode objfpc}{$H-}
interface
function ParseCurrencyLiteral(const AText: ShortString; out ACode: Integer): Currency;
implementation
{ Use the current integer decimal parser even when the compiler is built against
  an older bootstrap RTL whose Currency Val does not report endpoint overflow. }
function ParseCurrencyLiteral(const AText: ShortString; out ACode: Integer): Currency;
{$i ../rtl/inc/currval.inc}
end.