{ %FAIL }
{ Old file: tbf0314.pas }
{  }

procedure p(var b);
begin
end;

var
  s : string;
begin
  p(@s[1]);
end.
