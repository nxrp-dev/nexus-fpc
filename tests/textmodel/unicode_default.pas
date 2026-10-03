program UnicodeDefault;

{$mode objfpc}
{$H-}
{$LONGSTRINGS OFF}

{$IFOPT H-}
  {$FATAL H- must not select ShortString}
{$ENDIF}
{$IFNDEF FPC_UNICODESTRINGS}
  {$FATAL Unicode choice must define FPC_UNICODESTRINGS}
{$ENDIF}

procedure RequireUnicodeString(var Value: UnicodeString);
begin
end;

procedure RequireWideChar(var Value: WideChar);
begin
end;

procedure RequirePWideChar(var Value: PWideChar);
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
  RequireUnicodeString(S);
  RequireWideChar(C);
  RequireWideChar(QualifiedC);
  RequirePWideChar(P);
  RequirePWideChar(QualifiedP);
  if (SizeOf(Fixed) <> 41) or (SizeOf(Short) <> 256) then
    Halt(1);
end.
