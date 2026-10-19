program tcompilerreal;
{$mode objfpc}{$H-}
uses Math, tpcompilerreal, unativerealbits, obNXTestRegistry, obNXTestContext, utNXTestConsole;

var TestContext: TNXTestContext;

procedure Check(ACondition: Boolean; const AMessage: ShortString);
begin
  TestContext.AssertTrue(ACondition, AMessage);
end;

function Parse(const AText: ShortString): bestreal;
var lCode: Integer;
begin
  Val(AText,Result,lCode);
  Check(lCode=0,'decimal parse: '+AText);
end;

procedure CheckBits(const AValue: bestreal; ASignificand: QWord;
  AExponent: Word; const AMessage: ShortString);
begin
  TestContext.AssertTrue((TExtended80Rec(AValue).Frac=ASignificand) and
    (TExtended80Rec(AValue)._Exp=AExponent), AMessage+': '+
    HexStr(TExtended80Rec(AValue)._Exp,4)+HexStr(TExtended80Rec(AValue).Frac,16));
end;

procedure Run;
var
  lValue, lSmall: bestreal;
  lText: ShortString;
  lCurrency: Currency;
  lRaw: Int64;
  lSingle: Single;
  lDouble: Double;
  lSingleBits: DWord;
  lDoubleBits: QWord;
begin
  SetExceptionMask([exInvalidOp,exDenormalized,exZeroDivide,exOverflow,exUnderflow,exPrecision]);
  Check(SizeOf(bestreal)=10,'constant storage');
  CheckBits(Parse('3.64519953188247460E-4951'),1,0,'minimum subnormal');
  CheckBits(Parse('1.7976931348623157e305'),QWord($83126E978D4FDAF8),$43F5,'large literal');
  CheckBits(Parse('1.7976931348623158e305'),QWord($83126E978D4FDD05),$43F5,'adjacent literal');
  lValue:=Parse('0.125');
  Str(lValue,lText);
  Check(Parse(lText)=lValue,'assembler real text preserves immediate');
  lValue:=FromBits(QWord($8000000000000001),$7FFE);
  Str(lValue,lText);
  Check(Parse(lText)=lValue,'real text round trip retains low bits');
  lSmall:=FromBits(QWord($8000000000000000),$3FC3);
  Check((bestreal(1)+lSmall)-bestreal(1)=lSmall,'arithmetic retains low bits');
  Check(Round(Parse('255.75'))=256,'round carry beyond byte');
  Check(Round(Parse('256.75'))=257,'round retains upper integer bits');
  Check(Round(Parse('-256.75'))=-257,'negative round retains upper integer bits');
  Check(Round(Parse('65535.5'))=65536,'round tie carry');
  Check(Round(Parse('65536.5'))=65536,'round even tie');
  lSingle:=Single(FromBits(QWord($8000008000000000),$3FFF));
  Move(lSingle,lSingleBits,SizeOf(lSingleBits));
  Check(lSingleBits=$3F800000,'Single conversion ties to even');
  lSingle:=Single(FromBits(QWord($8000008000000001),$3FFF));
  Move(lSingle,lSingleBits,SizeOf(lSingleBits));
  Check(lSingleBits=$3F800001,'Single conversion above halfway');
  lDouble:=Double(FromBits(QWord($8000000000000400),$3FFF));
  Move(lDouble,lDoubleBits,SizeOf(lDoubleBits));
  Check(lDoubleBits=QWord($3FF0000000000000),'Double conversion ties to even');
  lDouble:=Double(FromBits(QWord($8000000000000401),$3FFF));
  Move(lDouble,lDoubleBits,SizeOf(lDoubleBits));
  Check(lDoubleBits=QWord($3FF0000000000001),'Double conversion above halfway');
{$ifdef CPUI386}
  { The existing i386 Int helper normalizes a zero result to positive zero. }
  CheckBits(Int(Parse('-0.75')),0,0,'int negative fraction');
{$else}
  CheckBits(Int(Parse('-0.75')),0,$8000,'int negative fraction');
{$endif}
  { Native RTL subtraction produces positive zero here. The retired software
    evaluator preserved the input sign; see the native-real design record. }
  CheckBits(Frac(Parse('-1.0')),0,0,'native frac negative integer');
  CheckBits(Exp(bestreal(0)),QWord($8000000000000000),$3FFF,'exp zero');
  Check(IsInfinite(Exp(bestreal(11400))),'exp overflow');
  CheckBits(Exp(bestreal(-11450)),0,0,'exp underflow');
  lValue:=Parse('922337203685477.5807');
  lCurrency:=Currency(lValue);
  Move(lCurrency,lRaw,SizeOf(lRaw));
  Check(lRaw=High(Int64),'positive Currency boundary');
  lValue:=Parse('-922337203685477.5808');
  lCurrency:=Currency(lValue);
  Move(lCurrency,lRaw,SizeOf(lRaw));
  Check(lRaw=Low(Int64),'negative Currency boundary');
  CheckBits(ArcTan(bestreal(1)),QWord($C90FDAA22168C235),$3FFE,'atan(1)');
  CheckBits(Ln(bestreal(2)),QWord($B17217F7D1CF79AC),$3FFE,'ln(2)');
  CheckBits(Exp(bestreal(1)),QWord($ADF85458A2BB4A9B),$4000,'exp(1)');
  CheckBits(Sin(bestreal(1)),QWord($D76AA47848677021),$3FFE,'sin(1)');
  CheckBits(Cos(bestreal(1)),QWord($8A51407DA8345C92),$3FFE,'cos(1)');
  CheckBits(Sin(FromBits(0,$8000)),0,$8000,'sin(-0)');
  CheckBits(ArcTan(FromBits(0,$8000)),0,$8000,'atan(-0)');
  Check(IsNan(Ln(bestreal(-1))),'ln negative');
  Check(IsNan(Sin(FromBits(QWord($8000000000000000),$7FFF))),'sin infinity');
end;

procedure NativeCase(AContext: TNXTestContext);
var lSavedMask: TFPUExceptionMask;
begin
  TestContext := AContext;
  lSavedMask := GetExceptionMask;
  try Run; finally
    SetExceptionMask(lSavedMask);
    TestContext := nil;
  end;
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('Compiler.Numeric.Native').AddTest('ParsingAndEvaluation', @NativeCase, 'compiler-numeric');
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
