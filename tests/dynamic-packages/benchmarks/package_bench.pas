program package_bench;

{$mode objfpc}{$H+}

uses SysUtils, PackageBenchData;

var
  I, Count: LongInt;
  Value: TBenchValue;
  Checksum: QWord;
begin
  Count:=StrToInt(ParamStr(2));
  Checksum:=0;
  if ParamStr(1)='globals' then
    begin
      BenchCounter:=17;
      for I:=1 to Count do
        BenchCounter:=(BenchCounter+QWord(I)) xor (BenchCounter shr 7);
      Checksum:=BenchCounter;
    end
  else if ParamStr(1)='managed' then
    for I:=1 to Count do
      begin
        Value:=MakeValue(I);
        try
          if not (Value is TBenchValue) then Halt(1);
          Inc(Checksum,Length(Value.Text)+Value.Values[0]+Value.Values[3]);
        finally
          Value.Free;
        end;
      end
  else
    Halt(2);
  WriteLn(Checksum);
end.
