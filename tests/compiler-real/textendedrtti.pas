program textendedrtti;
{$mode objfpc}{$H+}{$M+}
uses Rtti, TypInfo, obNXTestRegistry, obNXTestContext, utNXTestConsole;
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
procedure NumericProperties(AContext: TNXTestContext);
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
    AContext.AssertTrue((lValue.Kind=tkFloat) and (lValue.AsExtended-1=lSmall), 'Extended property retains low bits');
    lValue:=lType.GetProperty('IntegerValue').GetValue(lSample);
{$ifdef FPC_COMP_IS_INT64}
    AContext.AssertTrue((lValue.Kind=tkInt64) and (lValue.AsInt64=123456789), 'Integer Comp property');
{$else}
    AContext.AssertTrue((lValue.Kind=tkFloat) and (lValue.AsExtended=123456789), 'Floating Comp property');
{$endif}
    lValue:=lType.GetProperty('MoneyValue').GetValue(lSample);
    AContext.AssertTrue(lValue.AsCurrency=lSample.MoneyValue, 'Currency property value');
  finally
    lSample.Free;
    lContext.Free;
  end;
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('RTL.Rtti.NumericProperties').AddTest('ExtendedCompAndCurrency', @NumericProperties, 'rtl-rtti');
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
