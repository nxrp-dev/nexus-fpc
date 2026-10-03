program AnsiDefault;

{$mode objfpc}
{$H-}
{$LONGSTRINGS OFF}

{$IFOPT H-}
  {$FATAL H- must not select ShortString}
{$ENDIF}
{$IFDEF FPC_UNICODESTRINGS}
  {$FATAL ANSI default must not define FPC_UNICODESTRINGS}
{$ENDIF}

procedure RequireAnsiString(var Value: AnsiString);
begin
end;

procedure RequireAnsiChar(var Value: AnsiChar);
begin
end;

procedure RequirePAnsiChar(var Value: PAnsiChar);
begin
end;

var
  S: String;
  C: Char;
  QualifiedC: System.Char;
  P: PChar;
  QualifiedP: System.PChar;
  Fixed: String[40];
  Short: ShortString;

begin
  RequireAnsiString(S);
  RequireAnsiChar(C);
  RequireAnsiChar(QualifiedC);
  RequirePAnsiChar(P);
  RequirePAnsiChar(QualifiedP);
  if (SizeOf(Fixed) <> 41) or (SizeOf(Short) <> 256) then
    Halt(1);
end.
