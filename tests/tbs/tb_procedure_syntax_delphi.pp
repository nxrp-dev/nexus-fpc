{ Delphi procedural types, calling conventions, exports and empty parameter lists. }

{ tb0274.pp }

{$mode delphi}
type
  tfunc = function : longint stdcall;

{ tb0283.pp }

{$mode delphi}
procedure f;stdcall export;
asm
end;

{ tb0378.pp }
{$mode delphi}

procedure p();
begin
end;

{ tb0425.pp }
{$mode delphi}

var
  glResizeBuffersMESA: procedure(); cdecl;

begin
  { tb0425.pp }
  if not Assigned(glResizeBuffersMESA) then;
end.
