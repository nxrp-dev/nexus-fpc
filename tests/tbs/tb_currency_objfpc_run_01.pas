{ Currency multiplication/division and negation scaling in mixed expressions. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

{ Case tw38717.pas }
{$push}
{$H+}

var
  tw38717_c: Currency;
  tw38717_r, tw38717_d: Currency;
{$pop}

{ Case tw41865b.pas }
{$push}
{ negating a Currency value must not change its scaling }


var
  tw41865b_c: currency;
  tw41865b_d: double;
{$pop}

begin
  { Case tw38717.pas }
  {$push}
begin
  tw38717_c := 1234.56;
  tw38717_r := 4;
  tw38717_d := 2;
  tw38717_c := tw38717_c * tw38717_r / tw38717_d;
  Writeln(tw38717_c);
end;
  {$pop}

  { Case tw41865b.pas }
  {$push}
begin
  tw41865b_c := 10;
  if -tw41865b_c <> -10 then
    Halt(1);
  if -tw41865b_c + 1 <> -9 then
    Halt(2);
  if 1 + -tw41865b_c <> -9 then
    Halt(3);
  if -tw41865b_c - 1 <> -11 then
    Halt(4);
  if -tw41865b_c * 2 <> -20 then
    Halt(5);
  tw41865b_d := -tw41865b_c;
  if tw41865b_d <> -10 then
    Halt(6);
  if not (-tw41865b_c = -10) then
    Halt(7);
  WriteLn('ok');
end;
  {$pop}

end.
