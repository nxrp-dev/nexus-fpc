{ Variable set ranges, enumeration sets, inclusion, exclusion and bounds. }

{ tb0056.pas }
{  shows problem with ranges in sets for variables      OK 0.99.7 (PFV) }

{ may also crash/do weird error messages with the compiler }
var
 min: char;
 max: char;
 i: char;

{ tb0064.pas }
{  shows missing include and exclude from rtl           OK 0.99.6 (MVC) }

type
  myenum = (YES,NO,MAYBE);
var
 myvar:set of myenum;

{ tb0076.pas }
{  shows missing "dynamic" set constructor               OK 0.99.7 (PFV) }

var
   s1 : set of char;
   c1,c2,c3 : char;

{ tb0092.pas }
{ syntax error not detected when using a set as pointer OK 0.99.1 (FK) }

Type T = (aa,bb,cc,dd,ee,ff,gg,hh);
     Tset = set of t;

Var a: Tset;

{ tb0111.pas }
{ in [..#255] problem                                   OK 0.99.6 (PFV) }

var
  c : char;

{ tb0544.pas }
type SomeType = ( SomeElem );

const ElemSet = [ SomeElem ];

var
  b  : boolean;

{ tb0661.pas }
var
  s: set of 3..40;

begin
  { tb0056.pas }
  min:='c';
  max:='z';
  if i in [min..max] then
  Begin
  end;

  { tb0064.pas }
  Begin
   Include(myvar,Yes);
   Exclude(myvar,No);
  end;

  { tb0076.pas }
  s1:=[c1..c2,c3];

  { tb0092.pas }
  Begin
    If (aa in a) Then begin end;
    {it seems that correct code is generated, but the syntax is wrong}
  end;

  { tb0111.pas }
  c:=#91;
  if c in [#64..#255] then
   writeln('boe');
  c:=#32;
  if c in [#64..#255] then
   writeln('boe');

  { tb0544.pas }
  b:=(SomeElem in ElemSet);
  writeln(b);
  b:=(SomeElem in (ElemSet + []));
  writeln(b);
  if not b then
    halt(1);

  { tb0661.pas }
  if (low(s)<>3) or
     (high(s)<>40) then
    halt(1);
end.
