{ Reproduced in pre-extension-rename NexusFPC 8f0cd324 with -O2.
  The Win64 compiler reports wrong parameter counts at Assigned below.
  Default project options and stock FPC 3.2.2 i386-win32 compile it.
  Retained for evaluation and future nxtest coverage. }
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
