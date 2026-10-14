program tw10670;

{$IFDEF FPC}
  {$MODE Delphi}
  {$MACRO ON}
{$ENDIF}

begin
  {$DEFINE FLT := 1e+2}
  {$IF FLT < 99}
    {$MESSAGE Error 'Float expressions with macro failed!'}
  {$ELSE}
    {$MESSAGE Note 'Float expressions with macro work!'}
  {$IFEND}
end.
