{ Consolidated floating point regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tarray7.pas }
{$push}


{This test checks for open array functionality.}

function tarray7_average(const row:array of integer):real;

var tarray7_i:longint;
    temp:real;

begin
  temp:=Row[0];
  for tarray7_i:=1 to high(row) do
    temp:=temp+row[tarray7_i];
  tarray7_average:=temp/(high(row)+1);
end;

procedure tarray7_uppercase(var u:array of char);

var tarray7_i:longint;

begin
  for tarray7_i:=low(u) to high(u) do
    u[tarray7_i]:=upcase(u[tarray7_i]);
end;

var tarray7_a:array[-1000..1000] of integer;
    tarray7_b:Pinteger;
    tarray7_c:array of integer;
    tarray7_d:array[1..10] of char;
    tarray7_e:Pchar;
    tarray7_f:string;
    tarray7_g:ansistring;
    tarray7_i:longint;
    tarray7_s:string[31];


{$pop}

{ Case tnest1.pas }
{$push}
{$inline on}

procedure tnest1_test(l1, l2: longint; var l3: longint);

var
  a1: cardinal;
  d1, d2: double;
  a2: cardinal;

  procedure nested; inline;
    begin
      l1:=1;
      l2:=2;
      l3:=5;
      d1:=3.0;
      d2:=4.0;
    end;

begin
  a1:=$deadbeef;
  a2:=$cafe0000;
  nested;
  if a1<>$deadbeef then
    halt(1);
  if a2<>$cafe0000 then
    halt(2);
  if l1<>1 then
    halt(3);
  if l2<>2 then
    halt(4);
  if d1<>3.0 then
    halt(5);
  if d2<>4.0 then
    halt(6);
  if l3<>5 then
    halt(7);
end;

var
  tnest1_a3: longint;

{$pop}

{ Case trstr8.pas }
{$push}
{ from GPC test suite }



type trstr8_TString = String;

procedure trstr8_foo (const v : double);
var s : trstr8_TString;
begin
  repeat
    WriteStr (s, '', v : 0);
    ReadStr (s, s);
  until (s = '') or (s <> '');
  if s = ' 4.2E+001' then writeln ('OK') else writeln ('failed "', s,'"')
end;


{$pop}

{ Case tstrreal1.pas }
{$push}
const
  tstrreal1_s: array[0..16] of string[13] =
    ('99999.900000',
     '99999.990000',
     '99999.999000',
     '99999.999900',
     '99999.999990',
     '99999.999999',
     '100000.000000',
     '100000.000000',
     '100000.000000',
     '100000.000000',
     '100000.000000',
     '100000.000000',
     '100000.000000',
     '100000.000000',
     '100000.000000',
     '100000.000000',
     '100000.000000');

var
  tstrreal1_e,tstrreal1_e2,tstrreal1_e3: double;
  tstrreal1_s2: string;
  tstrreal1_c: longint;


{$pop}

{ Case tstrreal2.pas }
{$push}
const
  tstrreal2_s: array[1..21] of string =
    ('10.00000000000000000',
     '1.00000000000000000',
{$ifdef FPC_HAS_TYPE_EXTENDED}
     '0.10000000000000000',
{$else FPC_HAS_TYPE_EXTENDED}
     '0.10000000000000001',
{$endif FPC_HAS_TYPE_EXTENDED}
     '0.01000000000000000',
     '0.00100000000000000',
     '0.00010000000000000',
     '0.00001000000000000',
     '0.00000100000000000',
     '0.00000010000000000',
     '0.00000001000000000',
     '0.00000000100000000',
     '0.00000000010000000',
     '0.00000000001000000',
     '0.00000000000100000',
     '0.00000000000010000',
     '0.00000000000001000',
     '0.00000000000000100',
     '0.00000000000000010',
     '0.00000000000000001',
     '0.00000000000000000',
     '0.00000000000000000');

var
  tstrreal2_e: extended;
  tstrreal2_c: longint;
  tstrreal2_s2: string;
  tstrreal2_lenadjust: longint;

{$pop}

begin

{ Case tarray7.pas }
{$push}

begin
  {Integer stuff.}

  {First try it with a static array.}
  for tarray7_i:=low(tarray7_a) to high(tarray7_a) do
    tarray7_a[tarray7_i]:=tarray7_i xor 99;
  str(tarray7_average(tarray7_a):4:3,tarray7_s);
  if tarray7_s<>'-0.046' then
    halt(1);
  str(tarray7_average(tarray7_a[-1000..0]):4:3,tarray7_s);
  if tarray7_s<>'-502.203' then
    halt(2);
  str(tarray7_average(tarray7_a[0..1000]):4:3,tarray7_s);
  if tarray7_s<>'502.209' then
    halt(3);

  {Now try it with a heap block.}
  getmem(tarray7_b,2001*sizeof(integer));
  for tarray7_i:=-1000 to 1000 do
    tarray7_b[tarray7_i+1000]:=tarray7_i xor 99;
  str(tarray7_average(tarray7_b[0..2000]):4:3,tarray7_s);
  if tarray7_s<>'-0.046' then
    halt(4);
  dispose(tarray7_b);

  {And now try it with a dynamic array.}
  setlength(tarray7_c,2001);
  for tarray7_i:=-1000 to 1000 do
    tarray7_c[tarray7_i+1000]:=tarray7_i xor 99;
  str(tarray7_average(tarray7_c):4:3,tarray7_s);
  if tarray7_s<>'-0.046' then
    halt(5);
  str(tarray7_average(tarray7_c[0..1000]):4:3,tarray7_s);
  if tarray7_s<>'-502.203' then
    halt(6);
  str(tarray7_average(tarray7_c[1000..2000]):4:3,tarray7_s);
  if tarray7_s<>'502.209' then
    halt(7);
  setlength(tarray7_c,0);

  {Character stuff.}

  {First with a static array.}
  tarray7_d:='abcdefghij';
  tarray7_uppercase(tarray7_d);
  if tarray7_d<>'ABCDEFGHIJ' then
    halt(8);

  {Now with a heap block.}
  getmem(tarray7_e,10);
  move(tarray7_d,tarray7_e^,10);
  tarray7_uppercase(tarray7_e[0..9]);
  move(tarray7_e^,tarray7_d,10);
  if tarray7_d<>'ABCDEFGHIJ' then
    halt(9);
  dispose(tarray7_e);

  {Then a shortstring.}
  tarray7_f:='abcdefghij';
  tarray7_uppercase(tarray7_f[1..10]);
  if tarray7_f<>'ABCDEFGHIJ' then
    halt(10);

  {And finish with an ansistring.}
  tarray7_g:='abcdefghij';
  tarray7_uppercase(tarray7_g[1..10]);
  if tarray7_g<>'ABCDEFGHIJ' then
    halt(11);
end;
{$pop}

{ Case tnest1.pas }
{$push}
{$inline on}
begin
  tnest1_a3:=1;
  tnest1_test(5,6,tnest1_a3);
end;
{$pop}

{ Case trstr8.pas }
{$push}

begin
  trstr8_foo (42)
end;
{$pop}

{ Case tstrreal1.pas }
{$push}

begin
  tstrreal1_e := 100000.0;
  tstrreal1_e2 := 0.1;
  tstrreal1_c := 0;
  repeat
    tstrreal1_e3 := tstrreal1_e-tstrreal1_e2;
    str(tstrreal1_e3:0:6,tstrreal1_s2);
    writeln(tstrreal1_s2);
    if tstrreal1_s2 <> tstrreal1_s[tstrreal1_c] then
      begin
        writeln('  Error, should be ',tstrreal1_s[tstrreal1_c]);
        halt(1);
      end;
    tstrreal1_e2 := tstrreal1_e2 /10.0;
    inc(tstrreal1_c);
  until tstrreal1_e2 < 1e-17;
end;
{$pop}

{ Case tstrreal2.pas }
{$push}
{$ifdef FPC_HAS_TYPE_EXTENDED}
{$else FPC_HAS_TYPE_EXTENDED}
{$endif FPC_HAS_TYPE_EXTENDED}
begin
  if sizeof(extended) = 8 then
    tstrreal2_lenadjust := 0
  else
    tstrreal2_lenadjust := 0;
  tstrreal2_e := 10.0;
  for tstrreal2_c := 1 to 21 do
    begin
      str(tstrreal2_e:0:17,tstrreal2_s2);
      writeln(tstrreal2_s2);
      if tstrreal2_s2 <> copy(tstrreal2_s[tstrreal2_c],1,length(tstrreal2_s[tstrreal2_c])-tstrreal2_lenadjust) then
        begin
          writeln('  Error, should be ',copy(tstrreal2_s[tstrreal2_c],1,length(tstrreal2_s[tstrreal2_c])-tstrreal2_lenadjust));
          halt(1);
        end;
      tstrreal2_e := tstrreal2_e / 10.0;
    end;
end;
{$pop}

end.
