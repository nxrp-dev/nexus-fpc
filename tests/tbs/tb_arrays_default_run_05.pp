{ Arrays regression cases; original case IDs are retained below. }

{ Case tw3320.pp }
{$push}
var
  tw3320_a,tw3320_b:array of integer;
  tw3320_i :integer;
  tw3320_err : boolean;
{$pop}

{ Case tw3612.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3612 }
{ Submitted by "Alexey Barkovoy" on  2005-01-30 }
{ e-mail: clootie@ixbt.com }
var
  tw3612_str: array[0..200] of WideChar;
  tw3612_w: PWideChar;
  tw3612_s: String;
{$pop}

{ Case tw36157.pp }
{$push}
type
  tw36157_tenum = (EnVal1, EnVal2, EnVal3, EnVal4);
  tw36157_tset = set of tw36157_tenum;
  tw36157_tbitpacksetarray2 = bitpacked array [0..1, 0..2] of tw36157_tset;
const
  tw36157_gcbitpacksetarray2 : tw36157_tbitpacksetarray2 = (([EnVal3, EnVal1], [], [EnVal3]), ([],[EnVal1,EnVal2],[EnVal1]));
{$pop}

{ Case tw39897.pp }
{$push}
var
  tw39897_a,tw39897_b : array of longint;
{$pop}

{ Case tw4115.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4115 }
{ Submitted by "Alexey Chernobayev" on  2005-06-25 }
{ e-mail: alexch@caravan.ru }
var
  tw4115_a: array [WideChar] of Char;
  tw4115_w: WideChar;
{$pop}

{ Case tw4496.pp }
{$push}
type
  //BoolDeriv = Boolean; //gives no internal error
  tw4496_boolderiv = false..true;

var
  tw4496_a: array[tw4496_boolderiv] of char;
{$pop}

{ Case tw4616.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4616 }
{ Submitted by "Simon Felix" on  2005-12-18 }
{ e-mail: de@royalinc.ath.cx }
var
  tw4616_t:array[0..128] of widechar;
{$pop}

{ Case tw6960.pp }
{$push}
function tw6960_somefunc(var Res: array of Double): Integer;
begin
  // do something
  writeln(High(Res));
end;

var
  tw6960_d: Double;
  tw6960_darr: array[1..3] of Double;
{$pop}

{ Case tw7143.pp }
{$push}
var tw7143_a,tw7143_b: array[0..99] of byte;
    tw7143_i: integer;
    tw7143_c: byte;
{$pop}

begin
  { Case tw3320.pp }
  {$push}

  begin
setlength(tw3320_a,3);
  tw3320_a[0]:=1;
  tw3320_a[1]:=2;
  tw3320_a[2]:=3;
  tw3320_b:=tw3320_a;
  writeln('len b= ',length(tw3320_b)); // output is 3: OK
  if length(tw3320_b)<>3 then
    tw3320_err:=true;
  setlength(tw3320_a,0);
  writeln('len a= ',length(tw3320_a)); // output is 0: OK
  if length(tw3320_a)<>0 then
    tw3320_err:=true;
  for tw3320_i:=1 to length(tw3320_b) do writeln(tw3320_b[tw3320_i-1]); // output is 1: BAD
  writeln('len b= ',length(tw3320_b)); // output is 1: BAD, must be 3
  if length(tw3320_b)<>3 then
    tw3320_err:=true;
  if tw3320_err then
    halt(1);
  end;
  {$pop}

  { Case tw3612.pp }
  {$push}

  begin
tw3612_str:= 'abcdefgh';
  tw3612_w:= tw3612_str;
  tw3612_s:= tw3612_w;
  WriteLn(tw3612_s);
  tw3612_w:= tw3612_str + 2;
  tw3612_s:= tw3612_w;
  WriteLn(tw3612_s); // will output "bcdefgh" instead of "cdefgh"
  if tw3612_s<>'cdefgh' then
    halt(1);
  end;
  {$pop}

  { Case tw36157.pp }
  {$push}

  begin
if tw36157_gcbitpacksetarray2[0,0]<>[EnVal3, EnVal1] then
    halt(1);
  if tw36157_gcbitpacksetarray2[0,2]<>[EnVal3] then
    halt(2);
  if tw36157_gcbitpacksetarray2[1,1]<>[EnVal1,EnVal2] then
    halt(3);
  end;
  {$pop}

  { Case tw39897.pp }
  {$push}

  begin
tw39897_b:=nil;
  SetLength(tw39897_a,5);
  tw39897_a[1]:=1234;
  DynArrayAssign(pointer(tw39897_b),pointer(tw39897_a),TypeInfo(tw39897_a));
  if (length(tw39897_b)<>5) or (tw39897_b[1]<>1234) then
    halt(1);
  end;
  {$pop}

  { Case tw4115.pp }
  {$push}

  begin
tw4115_a['a'] := 'b'; // Ok
  tw4115_w := 'c';

  tw4115_a[tw4115_w] := 'd';
  end;
  {$pop}

  { Case tw4496.pp }
  {$push}

  begin
tw4496_a[true] := 'a'; //ierror 99080501 here
  end;
  {$pop}

  { Case tw4616.pp }
  {$push}

  begin
//works as expected
  //t:='ab';

  //works as expected
  //t:=char(65)+'ab';

  //doesn't result in 'Aab' (result is 'A',#4190)
  //t:=widechar(65)+'ab';

  //this crashes the compiler
  tw4616_t:=widechar(65)+'abc';
  end;
  {$pop}

  { Case tw6960.pp }
  {$push}

  begin
tw6960_somefunc(tw6960_d); // Delphi accepts this, FPC does not
  tw6960_somefunc(tw6960_darr); // OK
  end;
  {$pop}

  { Case tw7143.pp }
  {$push}

  begin
for tw7143_i:=0 to 99 do tw7143_a[tw7143_i]:=tw7143_i;
tw7143_b:=tw7143_a;

writeln('The same:',comparedword(tw7143_a[0],tw7143_b[0],25));
writeln('All other results should be negative.');

for tw7143_i:=0 to 99 do
  begin
  tw7143_c:=tw7143_b[tw7143_i];
  tw7143_b[tw7143_i]:=200;
  writeln(tw7143_i:3,' ',comparedword(tw7143_a[0],tw7143_b[0],25));
  tw7143_b[tw7143_i]:=tw7143_c;
  end;
  end;
  {$pop}

end.
