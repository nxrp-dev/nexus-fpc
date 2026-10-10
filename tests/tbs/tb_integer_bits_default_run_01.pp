{ Zero-count shifts, multiplication by one and high-byte extraction. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0431.pp }
{$push}
{ the smallest falling test I ever found PM }
{ the code generated a shll #0,%edx on i386
  which was bad but harmless...
  but on m68K it generated a asl.l #0,%d2
  which is not correct ... }

const
  tb0431_has_errors : boolean = false;
var
  tb0431_x : longint;
{$pop}

{ Case tb0473.pp }
{$push}
const
  tb0473_w = $5000;
{$pop}

{ Case tb0399.pp }
{$push}
procedure tb0399_error;
  begin
     writeln('Problem with octal constants');
     halt(1);
  end;
{$pop}

begin
  { Case tb0431.pp }
  {$push}
begin
  tb0431_x:=5;
  tb0431_x:=tb0431_x*1;
  if tb0431_x<>5 then
    tb0431_has_errors:=true;
  tb0431_x:=5;
  tb0431_x:=tb0431_x shl 0;
  if tb0431_x<>5 then
    tb0431_has_errors:=true;
  tb0431_x:=5;
  tb0431_x:=tb0431_x shr 0;
  if tb0431_x<>5 then
    tb0431_has_errors:=true;
  if tb0431_has_errors then
    halt(1);
end;
  {$pop}

  { Case tb0473.pp }
  {$push}
begin
  writeln(hi(tb0473_w));
  if hi(tb0473_w)<>$50 then
    begin
      writeln('Error!');
      halt(1);
    end;
end;
  {$pop}

  { Case tb0399.pp }
  {$push}
begin
   if 8<>&10 then
     tb0399_error;
   if 1<>&1 then
     tb0399_error;
   if 64<>&100 then
     tb0399_error;
   if 33<>&41 then
     tb0399_error;
   if 33<>&41 then
     tb0399_error;
   if 12345678<>&57060516 then
     tb0399_error;
end;
  {$pop}

end.
