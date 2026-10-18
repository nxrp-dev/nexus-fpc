{ %fail }

type
  p_int = procedure (var i : smallint);

procedure testl(var i : longint);
begin
  i:=$ffff;
end;


var
  p : p_int;
  r : packed record
        i,j : smallint;
      end;

begin
  p:=@testl;
  r.j:=5;
  p(r.i);
  if r.j<>5 then
    begin
      writeln('Wrong code overwrites j');
      halt(1);
    end;
end.
