{ %fail }

{ Old file: tbs0133.pas }
{ object type declaration not 100% compatible with TP7 }

type
  t=object
     f : longint;
     procedure p;
     g : longint;  { Not allowed in BP7 }
  end;

  procedure t.p;
  begin
  end;

  begin
  end.

