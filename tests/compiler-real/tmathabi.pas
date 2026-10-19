program tmathabi;
{$mode objfpc}{$H-}
uses SysUtils, Math, obNXTestRegistry, obNXTestContext, utNXTestConsole;
type
  TGuardedExtended = packed record
    Before: QWord;
    Value: Extended;
    After: QWord;
  end;
const
  cGuard = QWord($FEDCBA9876543210);
var
  lSin, lCos: TGuardedExtended;
  lTheta, lX, lY: Extended;
var TestContext: TNXTestContext;

procedure Check(ACondition: Boolean; ACode: Integer);
begin TestContext.AssertTrue(ACondition, 'Extended Math ABI check ' + IntToStr(ACode)); end;
procedure Near(AValue, AExpected: Extended; ACode: Integer);
begin Check(Abs(AValue-AExpected)<1.0e-18,ACode); end;
procedure Run;
begin
  lSin.Before:=cGuard;
  lSin.After:=cGuard;
  lCos.Before:=cGuard;
  lCos.After:=cGuard;
  lSin.Value:=-123;
  lCos.Value:=-456;
  lTheta:=0;
  SinCos(lTheta,lSin.Value,lCos.Value);
  Near(lSin.Value,0,1);
  Near(lCos.Value,1,2);
  Check((lSin.Before=cGuard) and (lSin.After=cGuard) and
    (lCos.Before=cGuard) and (lCos.After=cGuard),3);
  lTheta:=Pi;
  SinCos(lTheta,lSin.Value,lCos.Value);
  Near(lSin.Value,0,4);
  Near(lCos.Value,-1,5);
  lTheta:=Pi/4;
  Near(Tan(lTheta),1,6);
  Near(Cotan(lTheta),1,7);
  lTheta:=8;
  Near(Log2(lTheta),3,8);
  lX:=0;
  lY:=1;
  Near(ArcTan2(lY,lX),Pi/2,9);
  lX:=-1;
  lY:=-1;
  Near(ArcTan2(lY,lX),-3*Pi/4,10);
  Near(ArcCos(Extended(-1)),Pi,11);
end;

procedure NativeCase(AContext: TNXTestContext);
begin
  TestContext := AContext;
  try Run; finally
    TestContext := nil;
  end;
end;
var lRegistry: TNXTestRegistry;
begin
  lRegistry := TNXTestRegistry.Create;
  try
    lRegistry.AddSuite('RTL.Math.ABI').AddTest('ExtendedFunctions', @NativeCase, 'rtl-math-abi');
    ExitCode := RunConsoleTests(lRegistry);
  finally lRegistry.Free; end;
end.
