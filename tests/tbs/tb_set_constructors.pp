{ Variable set ranges, enumeration sets, inclusion, exclusion and bounds. }

{ tb0056.pp }
{  shows problem with ranges in sets for variables      OK 0.99.7 (PFV) }

{ may also crash/do weird error messages with the compiler }
var
 min: char;
 max: char;
 i: char;

{ tb0064.pp }
{  shows missing include and exclude from rtl           OK 0.99.6 (MVC) }

type
  myenum = (YES,NO,MAYBE);
var
 myvar:set of myenum;

{ tb0076.pp }
{  shows missing "dynamic" set constructor               OK 0.99.7 (PFV) }

var
   s1 : set of char;
   c1,c2,c3 : char;

{ tb0092.pp }
{ syntax error not detected when using a set as pointer OK 0.99.1 (FK) }

Type T = (aa,bb,cc,dd,ee,ff,gg,hh);
     Tset = set of t;

Var a: Tset;

{ tb0111.pp }
{ in [..#255] problem                                   OK 0.99.6 (PFV) }

var
  c : char;

{ tb0544.pp }
type SomeType = ( SomeElem );

const ElemSet = [ SomeElem ];

var
  b  : boolean;

{ tb0661.pp }
var
  s: set of 3..40;

begin
  { tb0056.pp }
  min:='c';
  max:='z';
  if i in [min..max] then
  Begin
  end;

  { tb0064.pp }
  Begin
   Include(myvar,Yes);
   Exclude(myvar,No);
  end;

  { tb0076.pp }
  s1:=[c1..c2,c3];

  { tb0092.pp }
  Begin
    If (aa in a) Then begin end;
    {it seems that correct code is generated, but the syntax is wrong}
  end;

  { tb0111.pp }
  c:=#91;
  if c in [#64..#255] then
   writeln('boe');
  c:=#32;
  if c in [#64..#255] then
   writeln('boe');

  { tb0544.pp }
  b:=(SomeElem in ElemSet);
  writeln(b);
  b:=(SomeElem in (ElemSet + []));
  writeln(b);
  if not b then
    halt(1);

  { tb0661.pp }
  if (low(s)<>3) or
     (high(s)<>40) then
    halt(1);
end.
