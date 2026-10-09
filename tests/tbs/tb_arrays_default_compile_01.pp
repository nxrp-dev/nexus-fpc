{ Arrays regression cases; original case IDs are retained below. }
{ %NORUN }

{ Case tw38051.pp }
{$push}
const tw38051_cchr = chr(12); { Ok }

type tw38051_tcha = ord(3)..ord(12); { Ok }
type tw38051_tchz = #3..#12; { Ok }
type tw38051_tcho = char(3)..char(12);{ Ok }
type tw38051_tchr = chr(3)..chr(12); { Error: Identifier not found "chr" }

type tw38051_tarrchr = array [chr(3)..chr(12)] of char; { Ok }

var tw38051_cz : #3..#12; { Ok }
var tw38051_ch : chr(3)..chr(12); { Error: Identifier not found "chr" }

var tw38051_c : char;
{$pop}

{ Case tw38054.pp }
{$push}
const
   tw38054_l = high(ptrint);	//   2000  <-->  2100
type
   tw38054_t = array[ 1..tw38054_l ]of int8;	//   1.95  <-->  2.05  GiBy
var
   tw38054_p: ^tw38054_t;
{$pop}

begin
  { Case tw38051.pp }
  {$push}

  begin
tw38051_c:=chr(12); { Ok }
  end;
  {$pop}

  { Case tw38054.pp }
  {$push}

  begin
new(tw38054_p);
   writeln( sizeof(tw38054_p^) );
   tw38054_p^[tw38054_l]:=0;  writeln(tw38054_p^[tw38054_l])
  end;
  {$pop}

end.
