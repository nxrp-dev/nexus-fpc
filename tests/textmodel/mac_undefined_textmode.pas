program MacUndefinedTextMode;

{$mode macpas}

{$IF UNDEFINED FPC_UNICODESTRINGS}
  {$IFDEF FPC_UNICODESTRINGS}
    {$FATAL UNDEFINED disagrees with IFDEF}
  {$ENDIF}
{$ELSE}
  {$IFNDEF FPC_UNICODESTRINGS}
    {$FATAL UNDEFINED disagrees with IFNDEF}
  {$ENDIF}
{$ENDIF}

begin
end.
