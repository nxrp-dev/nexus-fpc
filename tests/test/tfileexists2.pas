begin
  {$if fileexists('tfileexists0.pas')}
    halt(1);
  {$else fileexists('tfileexists0.pas')}
    halt(0);
  {$endif fileexists('tfileexists0.pas')}
end.
