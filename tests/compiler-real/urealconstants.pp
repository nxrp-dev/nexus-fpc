unit urealconstants;
{$mode objfpc}{$H-}{$inline on}
interface
const
{$ifdef FPC_HAS_TYPE_EXTENDED}
  cLowBitDenominator = 1152921504606846976.0;
{$else}
  cLowBitDenominator = 1125899906842624.0;
{$endif}
  cLowBit = (Extended(1.0) + Extended(1.0) / Extended(cLowBitDenominator)) - Extended(1.0);
  cPositive: Currency = 922337203685477.5807;
  cAdjacent: Currency = 922337203685477.5806;
  cNegative: Currency = -922337203685477.5808;
  cNegativeZero = -0.0;
  cRoundWide = Round(256.75);
  cRoundNegative = Round(-65535.5);
  cTruncMinimum = Trunc(-9223372036854775808.0);
{$ifdef FPC_HAS_TYPE_EXTENDED}
  cLargest: Extended = 1.18973149535723176502E4932;
  cSmallest: Extended = 3.64519953188247460E-4951;
{$endif}
function InlinePositive: Currency; inline;
function InlineAdjacent: Currency; inline;
function InlineLowBit: Double; inline;
implementation
function InlinePositive: Currency;
begin Result:=922337203685477.5807; end;
function InlineAdjacent: Currency;
begin Result:=922337203685477.5806; end;
function InlineLowBit: Double;
begin Result:=(Extended(1.0)+Extended(1.0)/Extended(cLowBitDenominator))-Extended(1.0); end;
end.
