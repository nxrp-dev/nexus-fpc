{ Regression: -O2 must compare callback addresses without calling them.
  The original failure reported wrong parameter counts at Assigned below.
  A try/finally block is not required; this preserves the original shape.
  See assigned_procvar_callbacks.pas for runtime behavior checks. }
program assigned_procvar_try_finally;

{$mode delphi}

type
  TCompare = function(const A, B): Integer;
  TMatch = function(const Key; var Value; Index, Count: Integer;
    Opaque: Pointer): Boolean of object;
  TDictionary = class
    function Check(const OnMatch: TMatch; KeyCompare, ValueCompare: TCompare;
      const Key, Value; Opaque: Pointer): Integer;
  end;

function TDictionary.Check(const OnMatch: TMatch;
  KeyCompare, ValueCompare: TCompare; const Key, Value;
  Opaque: Pointer): Integer;
begin
  try
    Result := 0;
    if not Assigned(OnMatch) or
      (not Assigned(KeyCompare) and not Assigned(ValueCompare)) then
      Exit;
  finally
  end;
end;

begin
end.
