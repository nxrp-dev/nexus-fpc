program treference;
{$mode objfpc}{$H-}
uses SysUtils, Math, tpcompilerreal, unativerealbits;
var
  lFile: Text;
  lLine: ShortString;
  lFields: array[0..4] of ShortString;
  lValue, lActual, lExpected: bestreal;
  lCount, lFailed, lIndex, lField, lOperation: Integer;
begin
  SetExceptionMask([exInvalidOp,exDenormalized,exZeroDivide,exOverflow,exUnderflow,exPrecision]);
  Assign(lFile,ParamStr(1));
  Reset(lFile);
  lCount:=0;
  lFailed:=0;
  while not EOF(lFile) do
    begin
      ReadLn(lFile,lLine);
      for lIndex:=0 to 4 do lFields[lIndex]:='';
      lField:=0;
      for lIndex:=1 to Length(lLine) do
        if lLine[lIndex]=' ' then Inc(lField)
        else lFields[lField]:=lFields[lField]+lLine[lIndex];
      lOperation:=StrToInt(lFields[0]);
      lValue:=FromBits(StrToQWord('$'+lFields[2]),StrToInt('$'+lFields[1]));
      lExpected:=FromBits(StrToQWord('$'+lFields[4]),StrToInt('$'+lFields[3]));
      case lOperation of
        0: lActual:=Sin(lValue);
        1: lActual:=Cos(lValue);
        2: lActual:=ArcTan(lValue);
        3: lActual:=Ln(lValue);
        4: lActual:=Exp(lValue);
        else Halt(2);
      end;
      Inc(lCount);
      if (TExtended80Rec(lActual).Frac<>TExtended80Rec(lExpected).Frac) or
         (TExtended80Rec(lActual)._Exp<>TExtended80Rec(lExpected)._Exp) then
        begin
          Inc(lFailed);
          WriteLn(lCount,': ',lLine,' actual ',HexStr(TExtended80Rec(lActual)._Exp,4),
            ' ',HexStr(TExtended80Rec(lActual).Frac,16));
        end;
    end;
  Close(lFile);
  WriteLn(lCount,' independent vectors, ',lFailed,' differences');
  if lFailed<>0 then Halt(1);
end.
