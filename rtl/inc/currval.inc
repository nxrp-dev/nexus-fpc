{ Currency decimal conversion shared by System and compiler literals.
  Extracted from sstrings.inc; original RTL copyright and COPYING.FPC apply. }
const
  MinInt64 : Int64  =-$8000000000000000;
  MinInt64Edge : Int64 = (-$8000000000000000 + 10) div 10;
var
  lRaw : Int64;
  lDigits,lDigit,lPower,lSign,lLength : longint;
  lFractionOverflow : boolean;
begin
  Result:=0;
  lRaw:=0;
  lLength:=Length(AText);
  ACode:=1;
  lSign:=-1;
  lPower:=0;
  while True do
    if ACode > lLength then
      exit
    else
      if AText[ACode] in [' ', #9] then
        Inc(ACode)
      else
        break;
  { Read sign }
  case AText[ACode] of
   '+' : begin
           Inc(ACode);
         end;
   '-' : begin
           lSign:=+1;
           Inc(ACode);
         end;
  end;
  { Read digits }
  lFractionOverflow:=False;
  lDigits:=0;
  while ACode <= lLength do
    begin
      case AText[ACode] of
        '0'..'9':
          begin
            lDigit:=Ord(AText[ACode])-Ord('0');
            { check overflow }
            if (lRaw >= MinInt64Edge) or (lRaw >= (MinInt64 + lDigit) div 10) then
              begin
                lRaw:=lRaw*10 - lDigit;
                Inc(lDigits);
              end
            else
              if lPower = 0 then
                { exit if integer part overflow }
                exit
              else
                begin
                  if not lFractionOverflow and (lDigit >= 5) and (lRaw > MinInt64) then
                    { round if first digit of fractional part overflow }
                    Dec(lRaw);
                  lFractionOverflow:=True;
                end;
          end;
        '.':
          begin
            if lPower = 0 then
              begin
                lPower:=1;
                lDigits:=0;
              end
            else
              exit;
          end;
        else
          break;
      end;
      Inc(ACode);
    end;
  if (lDigits = 0) and (lPower = 0) then
    exit;
  if lPower <> 0 then
    lPower:=lDigits;
  lPower:=4 - lPower;
  { Exponent? }
  if ACode <= lLength then
    if AText[ACode] in ['E', 'e'] then
      begin
        Inc(ACode);
        if ACode > lLength then
          exit;
        lDigits:=1;
        case AText[ACode] of
          '+':
            Inc(ACode);
          '-':
            begin
              lDigits:=-1;
              Inc(ACode);
            end;
        end;
        { read exponent }
        lDigit:=0;
        while ACode <= lLength do
          if AText[ACode] in ['0'..'9'] then
            begin
              if lDigit > 4951 then
                exit;
              lDigit:=lDigit*10 + (Ord(AText[ACode])-Ord('0'));
              Inc(ACode);
            end
          else
            exit;
        lPower:=lPower + lDigit*lDigits;
      end
    else
      exit;

  if lPower > 0 then
    begin
      for lDigits:=1 to lPower do
        if lRaw >= MinInt64 div 10 then
          lRaw:=lRaw*10
        else
          exit;
    end
  else
    for lDigits:=1 to -lPower do
      begin
        if lRaw >= MinInt64 + 5 then
          Dec(lRaw, 5);
        lRaw:=lRaw div 10;
      end;

  if lSign <> 1 then
    if lRaw > MinInt64 then
      lRaw:=lRaw*lSign
    else
      exit;

  Result:=PCurrency(@lRaw)^;
  ACode:=0;
end;
