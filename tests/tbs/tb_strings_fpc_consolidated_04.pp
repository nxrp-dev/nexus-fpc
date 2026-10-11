{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}
uses strings;

{ Case tw21443.pp }
{$push}


var
  tw21443_p1, tw21443_p2, tw21443_p3, tw21443_p4: pchar;

{$pop}

{ Case tstring8.pp }
{$push}


var
  tstring8_a, tstring8_b: pchar;


{$pop}

{ Case tstrcopy.pp }
{$push}


procedure tstrcopy_test_strcopy;
var
  p: pchar;
  s: array[0..256] of char;
  buf: array[0..512] of char;
  i, j, k, l: longint;
begin
  for i := 0 to 256 do
    begin
      fillchar(s,sizeof(s),'b');
      s[i] := #0;
      for j := 0 to 3 do
        begin
          fillchar(buf,sizeof(buf),'a');
          p := strcopy(@buf[j+32],@s[0]);
          if (p <> @buf[j+32]) then
            begin
              writeln('error 0 (i=',i,')');
              halt(1);
            end;
          for l := 0 to j+31 do
            if buf[l] <> 'a' then
              begin
                writeln('error 1 (i=',i,')');
                halt(1);
              end;
          for l := j+32 to j+32+i-1 do
            if buf[l] <> 'b' then
              begin
                writeln('error 2 (i=',i,')');
                halt(1);
              end;
          if buf[j+i+32] <> #0 then
            begin
              writeln('error 3 (i=',i,')');
              halt(1);
            end;
          for l := j+i+32+1 to 512 do
            if buf[l] <> 'a' then
              begin
                writeln('error 4 (i=',i,')');
                halt(1);
              end;
        end;
    end;
end;


{$pop}

{ Case tstrings1.pp }
{$push}
{ Basic test suite for the strings unit }




procedure tstrings1_failed;
  begin
     writeln('Failed.');
     halt(1);
  end;

procedure tstrings1_teststrlen;
  Const
     P1 : PChar = '';
     P2 : PChar = 'This is a constant pchar string';
  begin
     if strlen(P1)<>0 then
       tstrings1_failed;
     if strlen(P2)<>31 then
       tstrings1_failed;
  end;

procedure tstrings1_teststrcomp;
  Const
     P1 : PChar = 'This is the first string.';
     P2 : PCHar = 'This is the second string.';
     P3 : PChar = 'This is the first string.';
  begin
     If StrComp (P1,P2)=0 then
       tstrings1_failed;
     If StrComp (P1,P3)<>0 then
       tstrings1_failed;
     If StrComp (P1,P2)>0 then
       tstrings1_failed;
     If StrComp (P2,P1)<0 then
       tstrings1_failed;
  end;

procedure tstrings1_teststrpas;
  Const
     P1 : PChar = 'This is a PCHAR string';
     P2 : PChar = '';
  var
     S : string;
  begin
     S:=StrPas(P1);
     if S<>'This is a PCHAR string' then
       tstrings1_failed;
     S:=StrPas(P2);
     if S<>'' then
       tstrings1_failed;
end;


procedure tstrings1_teststrlcomp;
  Const
     P1 : PChar = 'This is the first string.';
     P2 : PCHar = 'This is the second string.';
     P3 : PChar = 'This is the first string.';
  Var
     L : Longint;
  begin
     L:=1;
     While StrLComp(P1,P2,L)=0 do
       inc (L);
     if L<>13 then tstrings1_failed;
     If StrLComp (P1,P2,255)=0 then
       tstrings1_failed;
     If StrLComp (P1,P3,100)<>0 then
       tstrings1_failed;
     If StrLComp (P1,P2,65535)>0 then
       tstrings1_failed;
     If StrLComp (P2,P1,12341234)<0 then
       tstrings1_failed;
  end;


procedure tstrings1_teststrpcopy;
  Const
     S1 = 'This is a normal string.';
     S2 = '';
  Var
     P : array[0..255] of char;
  begin
     if StrPCopy(P,S1)<>P then
       tstrings1_failed;
     if StrComp(P,S1)<>0 then
       tstrings1_failed;
     if StrPCopy(P,S2)<>P then
       tstrings1_failed;
     if StrComp(P,S2)<>0 then
       tstrings1_failed;
  end;


procedure tstrings1_teststrend;
  Const
     P : PChar = 'This is a PCHAR string.';
  begin
     If StrEnd(P)-P<>23 then
       tstrings1_failed;
  end;


procedure tstrings1_teststrcopy;
  Const
     P1 : PChar = 'This a test string 012345678901234567890123456789012345678901234567890123456789';
     P2 : PChar = '';
  var
     Buf : array[0..255] of char;
  begin
     if StrCopy(Buf,P1)<>Buf then
       tstrings1_failed;
     if StrComp(Buf,P1)<>0 then
       tstrings1_failed;
     if StrCopy(Buf,P2)<>Buf then
       tstrings1_failed;
     if StrComp(Buf,P2)<>0 then
       tstrings1_failed;
  end;


procedure tstrings1_teststrscanstrrscan;
  Const
    P : PChar = 'This is a PCHAR string.';
    S : Char = 's' ;
begin
  if StrComp(StrScan(P,s),'s is a PCHAR string.')<>0 then
    tstrings1_failed;
  if StrComp(StrRScan(P,s),'string.')<>0 then
    tstrings1_failed;
end;


procedure tstrings1_teststrupperstrlower;
  const
    P : PChar = 'This is a PCHAR string.@AZ[`az{';
  var
    buf: array [0..511] of Char;
    Q: PChar;
  begin
    StrCopy(buf, P);
    Q := StrUpper(buf);
    if Q <> @buf then
      tstrings1_failed;
    if strpas(buf) <> 'THIS IS A PCHAR STRING.@AZ[`AZ{' then
      tstrings1_failed;

    StrCopy(buf, P);
    Q := StrLower(buf);
    if Q <> @buf then
      tstrings1_failed;
    if strpas(buf) <> 'this is a pchar string.@az[`az{' then
      tstrings1_failed;
  end;



{$pop}

begin

{ Case tw21443.pp }
{$push}

begin

 { StrECopy(Dest,Source) is equivalent to the following:
    strcopy(Dest,Source);
    StrECopy := StrEnd(Dest);
  }
  tw21443_p1:='abcdefg';
  getmem(tw21443_p2,100);
  tw21443_p3:=strecopy(tw21443_p2,tw21443_p1);
  fillchar(tw21443_p2^,100,0);
  strcopy(tw21443_p2,tw21443_p1);
  tw21443_p4:=strend(tw21443_p2);
  if tw21443_p3<>tw21443_p4 then
    halt(1);
end;
{$pop}

{ Case tstring8.pp }
{$push}

begin
  tstring8_a := nil;
  tstring8_b := 'abc';
  if (strpos(tstring8_a,tstring8_b) <> nil) or
     (strpos(tstring8_b,tstring8_a) <> nil) or
     (strpos(tstring8_a,tstring8_a) <> nil) then
    halt(1);
end;
{$pop}

{ Case tstrcopy.pp }
{$push}

begin
  tstrcopy_test_strcopy;
end;
{$pop}

{ Case tstrings1.pp }
{$push}

begin
   write('Testing strlen ... ');
   tstrings1_teststrlen;
   writeln('Success.');
   write('Testing strcomp ... ');
   tstrings1_teststrcomp;
   writeln('Success.');
   write('Testing strlcomp ... ');
   tstrings1_teststrlcomp;
   writeln('Success.');
   write('Testing strpas ... ');
   tstrings1_teststrpas;
   writeln('Success.');
   write('Testing strcopy ... ');
   tstrings1_teststrcopy;
   writeln('Success.');
   write('Testing strpcopy ... ');
   tstrings1_teststrpcopy;
   writeln('Success.');
   write('Testing strend ... ');
   tstrings1_teststrend;
   writeln('Success.');
   write('Testing strscan/strrscan ... ');
   tstrings1_teststrscanstrrscan;
   writeln('Success.');
   write('Testing strupper/strlower ... ');
   tstrings1_teststrupperstrlower;
   writeln('Success.');
end;
{$pop}

end.
