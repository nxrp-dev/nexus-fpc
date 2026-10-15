begin
  {$if not(fileexists('tfileexists0.pas'))}
    halt(0);
  {$else not(fileexists('tfileexists0.pas'))}
    halt(1);
  {$endif not(fileexists('tfileexists0.pas'))}
end.
