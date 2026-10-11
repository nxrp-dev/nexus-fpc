program tcachedreal;
{$mode objfpc}{$H-}{$inline on}
uses urealconstants;
procedure Check(ACondition: Boolean; ACode: Integer);
begin if not ACondition then Halt(ACode); end;
function RawCurrency(AValue: Currency): Int64;
begin Move(AValue,Result,SizeOf(Result)); end;
{$ifdef FPC_HAS_TYPE_EXTENDED}
procedure CheckExtended(AValue: Extended; ASignificand: QWord; AExponent: Word; ACode: Integer);
var lBits: packed record Significand: QWord; Exponent: Word; end;
begin
  Move(AValue,lBits,SizeOf(lBits));
  Check((lBits.Significand=ASignificand) and (lBits.Exponent=AExponent),ACode);
end;
{$endif}
var lValue: Double; lBits: QWord;
begin
  Check(cLowBit=1.0/cLowBitDenominator,1);
  Check(InlineLowBit=cLowBit,2);
  Check(RawCurrency(cPositive)=High(Int64),3);
  Check(RawCurrency(cAdjacent)=High(Int64)-1,4);
  Check(RawCurrency(cNegative)=Low(Int64),5);
  Check(RawCurrency(InlinePositive)=High(Int64),6);
  Check(RawCurrency(InlineAdjacent)=High(Int64)-1,7);
  lValue:=cNegativeZero;
  Move(lValue,lBits,SizeOf(lBits));
  Check(lBits=QWord($8000000000000000),8);
  Check(cRoundWide=257,11);
  Check(cRoundNegative=-65536,12);
  Check(cTruncMinimum=Low(Int64),13);
{$ifdef FPC_HAS_TYPE_EXTENDED}
  CheckExtended(cLargest,High(QWord),$7FFE,9);
  CheckExtended(cSmallest,1,0,10);
{$endif}
  WriteLn('cached real constants passed');
end.
