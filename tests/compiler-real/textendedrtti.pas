program textendedrtti;
{$mode objfpc}{$H+}{$M+}
uses Rtti, TypInfo;
type
  TSample = class
  private
    FExtended: Extended;
    FComp: Comp;
    FCurrency: Currency;
  published
    property RealValue: Extended read FExtended write FExtended;
    property IntegerValue: Comp read FComp write FComp;
    property MoneyValue: Currency read FCurrency write FCurrency;
  end;
var
  lContext: TRttiContext;
  lSample: TSample;
  lType: TRttiType;
  lSmall: Extended;
  lValue: TValue;
begin
  lContext:=TRttiContext.Create;
  lSample:=TSample.Create;
  try
    lSmall:=1/Extended(1152921504606846976);
    lSample.RealValue:=1+lSmall;
    lSample.IntegerValue:=123456789;
    lSample.MoneyValue:=12345.6789;
    lType:=lContext.GetType(TSample.ClassInfo);
    lValue:=lType.GetProperty('RealValue').GetValue(lSample);
    if (lValue.Kind<>tkFloat) or (lValue.AsExtended-1<>lSmall) then Halt(1);
    lValue:=lType.GetProperty('IntegerValue').GetValue(lSample);
{$ifdef FPC_COMP_IS_INT64}
    if (lValue.Kind<>tkInt64) or (lValue.AsInt64<>123456789) then Halt(2);
{$else}
    if (lValue.Kind<>tkFloat) or (lValue.AsExtended<>123456789) then Halt(2);
{$endif}
    lValue:=lType.GetProperty('MoneyValue').GetValue(lSample);
    if lValue.AsCurrency<>lSample.MoneyValue then Halt(3);
  finally
    lSample.Free;
    lContext.Free;
  end;
  WriteLn('Extended, Comp and Currency RTTI passed');
end.
