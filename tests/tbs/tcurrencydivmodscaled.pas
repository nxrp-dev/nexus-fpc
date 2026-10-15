{ Integer-backed Currency div/mod: scaling, signs, constants and evaluation. }
{$mode objfpc}

{$ifdef FPC_CURRENCY_IS_INT64}
var
  lCalls: Integer;

function Operand(AValue: Currency): Currency;
begin
  Inc(lCalls);
  Result := AValue;
end;

procedure Check(AValue, ADivisor, AQuotient, ARemainder: Currency);
var
  lResult: Currency;
begin
  lResult := AValue div ADivisor;
  if lResult <> AQuotient then Halt(1);
  if (AValue div ADivisor) + 1 <> AQuotient + 1 then Halt(2);
  lResult := AValue mod ADivisor;
  if lResult <> ARemainder then Halt(3);
  if (AValue mod ADivisor) + 1 <> ARemainder + 1 then Halt(4);
end;
{$endif}

begin
{$ifdef FPC_CURRENCY_IS_INT64}
  Check(10, 3, 3, 1);
  Check(10.5, 3, 3, 1.5);
  Check(-10.5, 3, -3, -1.5);
  Check(10.5, -3, -3, 1.5);
  Check(-10.5, -3, 3, -1.5);
  Check(0.0005, 0.0002, 2, 0.0001);
  Check(1, 3, 0, 1);
  Check(0, 3, 0, 0);
  if Currency(10) div Currency(3) <> 3 then Halt(5);
  if Currency(10.5) mod Currency(3) <> 1.5 then Halt(6);
  if Operand(10) div 3 <> 3 then Halt(7);
  if 10 div Operand(3) <> 3 then Halt(8);
  if Operand(10.5) mod 3 <> 1.5 then Halt(9);
  if 10 mod Operand(3) <> 1 then Halt(10);
  if Operand(0.0005) mod Currency(0.0002) <> 0.0001 then Halt(11);
  if Operand(0.0005) div Currency(0.0002) <> 2 then Halt(12);
  if lCalls <> 6 then Halt(13);
{$endif}
end.
