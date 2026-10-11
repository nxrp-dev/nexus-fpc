{ Consolidated control flow regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}
uses sysutils;

{ Case tb0559.pp }
{$push}


var
 tb0559_Info: TSearchRec;

{$pop}

{ Case tw19851b.pp }
{$push}



{$pop}

{ Case tw22290.pp }
{$push}



{$pop}

{ Case tw3479.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3479 }
{ Submitted by "Michalis Kamburelis" on  2004-12-26 }
{ e-mail: michalis@camelot.homedns.org }
{ Two cases where BreakStr = #10 hang WrapText.
  After applying my fix all things work OK.
}


const
  tw3479_Line1 = 'one blahblah blah bb b';
  tw3479_Line2 = 'two hhhhh sss sssss wwwww';

{$pop}

{ Case tw39735.pp }
{$push}


var
  tw39735_LStart: TDateTime;

{$pop}

begin

{ Case tb0559.pp }
{$push}

begin
 // should not match, is a directory
 if FindFirst('..',faArchive,tb0559_Info)=0 then
   halt(1);
 FindClose(tb0559_Info);
end;
{$pop}

{ Case tw19851b.pp }
{$push}

begin
{$ifdef WINDOWS}
  executeprocess(GetEnvironmentVariable('COMSPEC'),'/c echo abcdefghijklmnopqrstuvwxyz1 | tw19851a');
{$endif WINDOWS}
end;
{$pop}

{ Case tw22290.pp }
{$push}

begin
  if formatfloat('0e',-1)<>'-1e' then
    halt(1);
end;
{$pop}

{ Case tw3479.pp }
{$push}

begin
 Writeln(WrapText(tw3479_Line1 +   #10+ tw3479_Line2,    #10, [' '], 40));
 Writeln(WrapText(tw3479_Line1 +#13#10+ tw3479_Line2, #13#10, [' '], 40));
 Writeln(WrapText(tw3479_Line1 +   #10+ tw3479_Line2,    #10, [' '], 10));
 Writeln(WrapText(tw3479_Line1 +#13#10+ tw3479_Line2, #13#10, [' '], 10));
end;
{$pop}

{ Case tw39735.pp }
{$push}

begin
  tw39735_LStart := DateTimeToTimeStamp(Now).Time;
end;
{$pop}

end.
