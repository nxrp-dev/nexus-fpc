{ Abs masks in an ordinary or shared-RTL consumer, and RTL math using Abs. }
{$mode objfpc}
{$inline off}

type
  TSingleBits = record
    case Boolean of
      False: (Value: Single);
      True: (Bits: LongWord);
  end;
  TDoubleBits = record
    case Boolean of
      False: (Value: Double);
      True: (Bits: QWord);
  end;

procedure CheckSingle(ABits, AExpected: LongWord);
var
  lValue: TSingleBits;
begin
  lValue.Bits := ABits;
  lValue.Value := Abs(lValue.Value);
  if lValue.Bits <> AExpected then Halt(1);
end;

procedure CheckDouble(ABits, AExpected: QWord);
var
  lValue: TDoubleBits;
begin
  lValue.Bits := ABits;
  lValue.Value := Abs(lValue.Value);
  if lValue.Bits <> AExpected then Halt(2);
end;

procedure CheckTrig(AAngle: Double);
begin
  if Abs(Sin(AAngle)) > 1e-12 then Halt(3);
  if Abs(Cos(AAngle) + 1) > 1e-12 then Halt(4);
end;

const
  cSinPi = Sin(Pi);
  cCosPi = Cos(Pi);

begin
  CheckSingle($80000000, 0);
  CheckSingle($BFC00000, $3FC00000);
  CheckSingle($3FC00000, $3FC00000);
  CheckDouble($8000000000000000, 0);
  CheckDouble($BFF8000000000000, $3FF8000000000000);
  CheckDouble($3FF8000000000000, $3FF8000000000000);
  CheckTrig(Pi);
  if Abs(cSinPi) > 1e-12 then Halt(5);
  if Abs(cCosPi + 1) > 1e-12 then Halt(6);
end.
