program profiler_optimized_params;

{$mode objfpc}

type
  TAccumulator = class
    Base: LongInt;
    function Add(Value: LongInt): LongInt; noinline;
  end;

function SumIntegers(A, B, C, D: LongInt): LongInt; noinline;
begin
  Result := A + B + C + D;
end;

function SumFloats(A, B, C, D: Double): Double; noinline;
begin
  Result := A + B + C + D;
end;

function ReadPointer(Value: PLongInt; Delta: LongInt): LongInt; noinline;
begin
  Result := Value^ + Delta;
end;

function Recurse(Value: LongInt): LongInt; noinline;
begin
  if Value = 0 then
    Exit(0);
  Result := Recurse(Value - 1) + 1;
end;

function TAccumulator.Add(Value: LongInt): LongInt;
begin
  Result := Base + Value;
end;

var
  Accumulator: TAccumulator;
  Value: LongInt;
begin
  Value := 40;
  if SumIntegers(1, 2, 3, 4) <> 10 then
    Halt(1);
  if SumFloats(1.0, 2.0, 3.0, 4.0) <> 10.0 then
    Halt(2);
  if ReadPointer(@Value, 2) <> 42 then
    Halt(3);
  if Recurse(32) <> 32 then
    Halt(4);
  Accumulator := TAccumulator.Create;
  try
    Accumulator.Base := 37;
    if Accumulator.Add(5) <> 42 then
      Halt(5);
  finally
    Accumulator.Free;
  end;
end.
