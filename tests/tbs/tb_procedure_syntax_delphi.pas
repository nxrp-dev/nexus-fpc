{ Delphi procedural types, calling conventions, exports and empty parameter lists. }

{ tb0274.pas }

{$mode delphi}
type
  tfunc = function : longint stdcall;

{ tb0283.pas }

{$mode delphi}
procedure f;stdcall export;
asm
end;

{ tb0378.pas }
{$mode delphi}

procedure p();
begin
end;

{ tb0425.pas }
{$mode delphi}

var
  glResizeBuffersMESA: procedure(); cdecl;

begin
  { tb0425.pas }
  if not Assigned(glResizeBuffersMESA) then;
end.
