program tcbridge;
{$mode objfpc}{$H-}
type TCallback = function(AValue: CExtended): CExtended; cdecl;
function call_callback(ACallback: TCallback; AValue: CExtended): CExtended;
  cdecl; external 'nativebridge.dll';
function variadic_sum(ACount: LongInt): CExtended;
  cdecl; varargs; external 'nativebridge.dll';
function Callback(AValue: CExtended): CExtended; cdecl;
var lValue, lSmall: Extended;
begin
  lSmall:=1/Extended(1152921504606846976);
  lValue:=AValue+lSmall;
  if lValue-AValue<>lSmall then Halt(1);
  Result:=AValue*2;
end;
var lValue: Extended;
begin
  if call_callback(@Callback,1)<>2 then Halt(2);
  lValue:=1.25;
  { Deliberately checks implicit Extended -> Microsoft Double varargs lowering. }
  if variadic_sum(5,lValue,Double(2.5),Double(3.75),Double(4),Double(5))<>16.5 then Halt(3);
  WriteLn('Microsoft C bridge passed');
end.
