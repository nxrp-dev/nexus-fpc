unit unativerealbits;
{$mode objfpc}{$H-}
interface
uses tpcompilerreal;
function FromBits(ASignificand: QWord; AExponent: Word): bestreal;
implementation
function FromBits(ASignificand: QWord; AExponent: Word): bestreal;
var lBits: TExtended80Rec;
begin
 lBits.Frac:=ASignificand;
 lBits._Exp:=AExponent;
 Result:=lBits.Value;
end;
end.