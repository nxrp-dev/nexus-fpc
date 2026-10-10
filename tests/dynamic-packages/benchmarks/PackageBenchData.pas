unit PackageBenchData;

{$mode objfpc}{$H+}

interface

type
  TBenchValue = class
    Text: string;
    Values: array of LongInt;
  end;

var
  BenchCounter: QWord;

function MakeValue(Seed: LongInt): TBenchValue;

implementation

uses SysUtils;

function MakeValue(Seed: LongInt): TBenchValue;
begin
  Result:=TBenchValue.Create;
  Result.Text:=IntToStr(Seed)+StringOfChar('x',Seed and 31);
  SetLength(Result.Values,4);
  Result.Values[0]:=Seed;
  Result.Values[3]:=Seed xor $55;
end;

end.
