{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}
uses sysutils;

{ Every case starts with the process locale settings it had standalone. }
var lOriginalFormatSettings: TFormatSettings;

{ Case tb_sysutils_default_run_01.pp }
{$push}
{ Managed array copying and numeric formatting with explicit separators. }
{ Original case IDs and variable scopes are retained below. }



{ Case tb0572.pp }
{$push}
{ test copy optimization of dyn. arrays }
var
  tb0572_a,tb0572_b,tb0572_c : array of ansistring;
  tb0572_i : longint;
{$pop}

{ Case tb0364.pp }
{$push}
{ comment by submitter:
  The following statement (which works in Delphi)
    result:=Format('%10.n', [ival*1.0]);
  generated an unhandled exception (and said: Missing argument in format "").
  Checking the Delphi documentation, it agrees with the fpc documentation
  (units.pdf), that a dot should be followed by a <prec> (but Delphi does
  not appear to explicitly state that prec should be an integer).
  It appears that Delphi is treating this like %10.0n, although it is
  potentially undefined behaviour.  The fpc documentation indicates I
  should get an EConversionError exception if there are problems.
  (Actually the documentation may be inconsistent, since it also says
  I may get an EConvertError exception.)

  If I change the format string to %10.0n, the program runs OK using
  fpc, however, my thousand separators do not appear.
}

var
   tb0364_s : string;
   tb0364_ival : integer;
{$pop}


{$pop}

{ Case tw10519.pp }
{$push}


var
  tw10519_cs:String;

{$pop}



{ Case tw11711.pp }
{$push}


var
  tw11711_cs:String;

{$pop}

{ Case tw13552.pp }
{$push}


var
  tw13552_s: ansistring;

{$pop}

{ Case tw15364.pp }
{$push}




 var
   tw15364_a : array [Boolean,Boolean] of string;
   tw15364_b : wordbool;

{$pop}

{ Case tw1867.pp }
{$push}


var
  tw1867_s : string;

{$pop}

{ Case tw21443a.pp }
{$push}


var
  tw21443a_p1, tw21443a_p2, tw21443a_p3, tw21443a_p4: pwidechar;

{$pop}

{ Case tw40563.pp }
{$push}


var tw40563_s:string[20];
  tw40563_r:shortstring;
  tw40563_x: Char;

{$pop}

{ Case tw7276.pp }
{$push}


var
  tw7276_s : AnsiString;


{$pop}

{ Case tw7637.pp }
{$push}


var
  tw7637_s: ansistring;

{$pop}

{ Case tw8258a.pp }
{$push}




var
  tw8258a_FCommentChars: TSysCharSet;
  tw8258a_s: string;


{$pop}

begin
  lOriginalFormatSettings := DefaultFormatSettings;
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tb_sysutils_default_run_01.pp }
{$push}
{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tb0572.pp }
  {$push}
begin
  SetLength(tb0572_a,1000);
  SetLength(tb0572_c,1000);
  for tb0572_i:=low(tb0572_a) to high(tb0572_a) do
    tb0572_a[tb0572_i]:=IntToStr(random(10000));
  tb0572_b:=copy(tb0572_a);
  tb0572_c:=copy(tb0572_a);
  tb0572_a:=nil;
  for tb0572_i:=low(tb0572_b) to high(tb0572_b) do
    if tb0572_b[tb0572_i]<>tb0572_c[tb0572_i] then
      halt(1);
  writeln('ok');
end;
  {$pop}

  { Case tb0364.pp }
  {$push}
begin
   ThousandSeparator:='.';
   DecimalSeparator:=',';
   tb0364_ival:=1234;
   tb0364_s:=Format('%10.n', [tb0364_ival*1.0]);
   writeln('s: "',tb0364_s,'"');
   if tb0364_s<>'     1.234' then
     begin
        writeln('Problem with Format');
        halt(1);
     end;
end;
  {$pop}

end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tw10519.pp }
{$push}

begin
  tw10519_cs:=FormatFloat('0.00000E+0000',52247.9532745);
  if (tw10519_cs<>'5'+DecimalSeparator+'22480E+0004') then
    halt(1);
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;


  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tw11711.pp }
{$push}

begin
  tw11711_cs:=FormatFloat('000.000',-1);
  if (tw11711_cs<>'-001'+DecimalSeparator+'000') then
    halt(1);
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tw13552.pp }
{$push}

begin
  ThousandSeparator:=#0;
  DecimalSeparator:='.';
  tw13552_s:=formatfloat('#,0.00',1000.0);
  writeln(tw13552_s);
  if (tw13552_s<>'1000.00') then
    halt(1);
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tw15364.pp }
{$push}

begin
  tw15364_a[False,True] := 'True';
  tw15364_a[False,False] := 'False';
  tw15364_a[True,True] := 'True';
  tw15364_a[True,False] := 'False';
  tw15364_b := True;
  if tw15364_a[false,tw15364_b]<>'True' then
    halt(1);
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tw1867.pp }
{$push}

begin
  tw1867_s:=formatdatetime ('hh:nn:ss.zzz', encodetime (12, 30, 44, 4));
  writeln(tw1867_s);
  if tw1867_s<>'12:30:44.004' then
   begin
     writeln('ERROR!');
     halt(1);
   end;
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tw21443a.pp }
{$push}

begin

 { StrECopy(Dest,Source) is equivalent to the following:
    strcopy(Dest,Source);
    StrECopy := StrEnd(Dest);
  }
  tw21443a_p1:='abcdefg';
  getmem(tw21443a_p2,100);
  tw21443a_p3:=strecopy(tw21443a_p2,tw21443a_p1);
  fillchar(tw21443a_p2^,100,0);
  strcopy(tw21443a_p2,tw21443a_p1);
  tw21443a_p4:=strend(tw21443a_p2);
  if tw21443a_p3<>tw21443a_p4 then
    halt(1);
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tw40563.pp }
{$push}

begin
  tw40563_r:='';
  tw40563_s:=inttostr(12345);
  for tw40563_x in tw40563_s do begin
    tw40563_r:=tw40563_r+tw40563_x;
    write(ord(tw40563_x):4);
  end;
  writeln;
  if tw40563_r<>tw40563_s then
    Halt(1);
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tw7276.pp }
{$push}

begin
  tw7276_s := 'Hello';
  // tests whether the * in the format specifier allows all
  // kind of integers; note that the * in the format specifier here
  // is an incomplete format specification, i.e. it does not change
  // the length of the result string
  Format('%*s', [Integer(length(tw7276_s)), tw7276_s]);
  // this is only seemingly equivalent to above, but on 64 bit
  // machines the default integer type is Int64
  Format('%*s', [length(tw7276_s), tw7276_s]);
  // also test QWord
  Format('%*s', [QWord(length(tw7276_s)), tw7276_s]);
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tw7637.pp }
{$push}

begin
  DecimalSeparator:='.';
  tw7637_s := format('%e',[1.72]);
{$ifdef FPC_HAS_TYPE_EXTENDED}
  if tw7637_s <> '1.7200000000000000E+000' then
{$else}
  if tw7637_s <> '1.72000000000000E+000' then
{$endif}
    halt(1);
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

{ Case tw8258a.pp }
{$push}

begin
  tw8258a_s := '#';
  tw8258a_FCommentChars := [';','#'];
  if not (tw8258a_s[1] in tw8258a_FCommentChars) then
    halt(1);
end;
{$pop}
  DefaultFormatSettings := lOriginalFormatSettings;

end.
