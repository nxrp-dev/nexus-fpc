{ Inline Out string elements and ShortString conversion for inline function parameters. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}
{$H+}

{ Case tw37465.pp }
{$push}
{$H+}

procedure tw37465_foo(out tw37465_c: char); inline;
begin
  tw37465_c := #32;
end;

var tw37465_s: String;
{$pop}

{ Case tw38337.pp }
{$push}
{$H+}

function tw38337_utf8length(const tw38337_s: string): PtrInt; inline;
begin
  Result:=9;
end;


var
  tw38337_v1: string;
  tw38337_s: shortstring;
  tw38337_i: Integer;
{$pop}

begin
  { Case tw37465.pp }
  {$push}
begin
  tw37465_s:=#42;
  tw37465_foo(tw37465_s[1]);
  Writeln(ord(tw37465_s[1]));
  if ord(tw37465_s[1])<>32 then
    halt(1);
end;
  {$pop}

  { Case tw38337.pp }
  {$push}
begin
  tw38337_v1 := '123456789';
  tw38337_s := tw38337_v1;
  for tw38337_i := 1 to tw38337_utf8length(tw38337_s)-8 do begin
  end;
end;
  {$pop}

end.
