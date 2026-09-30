unit NXAssemblerProbe;

{$mode objfpc}{$H+}

interface

function RunProbe: LongInt;

implementation

uses SysUtils;

threadvar
  ThreadValue: LongInt;

function AddValues(AValue, BValue: LongInt): LongInt;
begin
  Result := AValue + BValue;
end;

function RunProbe: LongInt;
var
  Text: AnsiString;
  Values: array of LongInt;
  Add: function(AValue, BValue: LongInt): LongInt;
begin
  ThreadValue := 19;
  Text := IntToStr(ThreadValue);
  SetLength(Values, 2);
  Values[0] := StrToInt(Text);
  Values[1] := 23;
  Add := @AddValues;
  Result := Add(Values[0], Values[1]);
  try
    raise Exception.Create('assembler exception probe');
  except
    on E: Exception do
      if E.Message <> 'assembler exception probe' then
        Result := -1;
  end;
end;

end.
