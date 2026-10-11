{$mode delphi}

Program test;

procedure outer_proc(var outer: ShortString);

procedure inner_proc;
Begin
  outer := 'abc';
End;

Begin
  inner_proc();
End;

procedure CheckBounds(var AText: ShortString; var AValues: array of Integer);
  procedure Inner;
    procedure Deep;
    begin
      AText := 'longer';
      AValues[High(AValues)] := Length(AText);
    end;
  begin
    Deep;
  end;
begin
  Inner;
end;

var
 s: shortstring;
 lSmall: string[1];
 lValues: array[0..2] of Integer;

Begin
  outer_proc(s);
  if s<>'abc' then
    halt(1);
  outer_proc(lSmall);
  if lSmall<>'a' then
    halt(2);
  CheckBounds(lSmall, lValues);
  if (lSmall <> 'l') or (lValues[2] <> 1) then
    Halt(3);
End.
