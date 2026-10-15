begin
  {$if fileexists('tfileexists1.pas')}
    halt(0);
  {$else fileexists('tfileexists1.pas')}
    halt(1);
  {$endif fileexists('tfileexists1.pas')}
end.
