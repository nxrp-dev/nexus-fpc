{ Consolidated files regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode iso}

{ Case tisobuf1.pas }
{$push}



  var
    tisobuf1_t : text;

  
{$pop}

{ Case tisoext1.pas }
{$push}

var
  tisoext1_f : file of byte;
  tisoext1_b : byte;

{$pop}

{ Case tisoext4.pas }
{$push}

var
  tisoext4_f : text;
  tisoext4_s : array[0..10] of char;

{$pop}

begin

{ Case tisobuf1.pas }
{$push}

begin
    assign(tisobuf1_t,'tisobuf1.tmp');
    rewrite(tisobuf1_t);
    writeln(tisobuf1_t,'{Test}');
    close(tisobuf1_t);
    reset(tisobuf1_t);
    if tisobuf1_t^<>'{' then
      halt(1);
    close(tisobuf1_t);
    erase(tisobuf1_t);
    writeln('ok');
  end;
{$pop}

{ Case tisoext1.pas }
{$push}

begin
  rewrite(tisoext1_f,'tisoext1.tmp');
  write(tisoext1_f,123);
  close(tisoext1_f);
  tisoext1_b:=0;
  reset(tisoext1_f,'tisoext1.tmp');
  read(tisoext1_f,tisoext1_b);
  if tisoext1_b<>123 then
    halt(1);
  close(tisoext1_f);
  erase(tisoext1_f);
  writeln('ok');
end;
{$pop}

{ Case tisoext4.pas }
{$push}

begin
  rewrite(tisoext4_f,'tisoext4.tmp');
  write(tisoext4_f,'FPC');
  close(tisoext4_f);
  reset(tisoext4_f,'tisoext4.tmp');
  read(tisoext4_f,tisoext4_s);
  if tisoext4_s<>'FPC' then
    halt(1);
  close(tisoext4_f);
  erase(tisoext4_f);
  writeln('ok');
end;
{$pop}

end.
