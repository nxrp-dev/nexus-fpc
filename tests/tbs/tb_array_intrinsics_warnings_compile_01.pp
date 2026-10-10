{ %opt=-Sew -vw }
{ %norun }
{ Array/scalar intrinsics and indexed Text-file assignment without warnings. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0521.pp }
{$push}
procedure tb0521_p;
  var
    c : char;
    w : widechar;
    a : array[0..1] of longint;
    i : integer;
    e : (e1,e2,e3);
  begin
    writeln(length(c));
    writeln(length(w));
    writeln(length(a));
    writeln(low(i));
    writeln(high(i));
    writeln(ord(low(e)));
    writeln(ord(high(e)));
    writeln(low(a));
    writeln(high(a));
  end;
{$pop}

{ Case tb0542.pp }
{$push}
procedure tb0542_t;
var
  f:array[1..10] of text;
begin
  assign(f[1],paramstr(0));
end;
{$pop}

begin
  { Case tb0521.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0542.pp }
  {$push}
begin
  tb0542_t;
end;
  {$pop}

end.
