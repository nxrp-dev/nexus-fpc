program textendedabi;
{$mode objfpc}{$H-}
uses SysUtils, Math, uextendedabi;

procedure Check(ACondition: Boolean; ACode: Integer);
begin if not ACondition then Halt(ACode); end;

function Callback(AValue: Extended): Extended; cdecl;
begin Result:=AValue-1; end;

function SelectType(AValue: Single): Integer; overload;
begin Result:=1; end;
function SelectType(AValue: Double): Integer; overload;
begin Result:=2; end;
function SelectType(AValue: Extended): Integer; overload;
begin Result:=3; end;

var
  lSmall, lValue, lZero: Extended;
  lRecord: TExtendedRecord;
  lIndex: Integer;
  lCaught: Boolean;
  lMask: TFPUExceptionMask;
begin
  Check(SizeOf(Extended)=10,1);
{$ifdef win64}
  Check(SizeOf(CExtended)=8,2);
  Check(SizeOf(Currency)=8,3);
  Check(SizeOf(Comp)=8,4);
  Check(Low(Comp)=Low(Int64),5);
{$endif}
  lSmall:=1/Extended(1152921504606846976);
  for lIndex:=1 to 100 do
    begin
      lValue:=Mixed(17,2.5,1,$FEDCBA9876543210,lSmall,3.25);
      Check(CallExtended(@Callback,lValue)=lSmall,6);
      UpdateExtended(lValue,lSmall);
      Check(lValue-1=2*lSmall,7);
    end;
  lRecord.Before:=$0123456789ABCDEF;
  lRecord.After:=$FEDCBA9876543210;
  lRecord.Value:=lValue;
  lRecord:=RecordResult(lRecord);
  Check(lRecord.Before=$0123456789ABCDEF,8);
  Check(lRecord.After=QWord($FEDCBA9876543210),9);
  Check(lRecord.Value-2=4*lSmall,10);
  Check(SelectType(Single(1))=1,11);
  Check(SelectType(Double(1))=2,12);
  Check(SelectType(Extended(1))=3,13);
  lMask:=GetExceptionMask;
  SetExceptionMask(lMask-[exZeroDivide]);
  lCaught:=False;
  lZero:=0;
  try
    lValue:=lValue/lZero;
  except
    on EZeroDivide do lCaught:=True;
  end;
  SetExceptionMask(lMask);
  Check(lCaught,14);
  lValue:=1+lSmall;
  Check(lValue-1=lSmall,15);
  WriteLn('Extended ABI passed');
end.
