{ Overload resolution for assigned procedure variables and empty function parameter lists. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

{ Case tb0384.pp }
{$push}
var
  tb0384_count : longint;

procedure tb0384_p1(tb0384_w:word);overload;
begin
  writeln('word');
  tb0384_count:=tb0384_count or 1;
end;

procedure tb0384_p1(tb0384_l:longint);overload;
begin
  writeln('longint');
  tb0384_count:=tb0384_count or 2;
end;

var
  tb0384_f1 : procedure(tb0384_l:longint);
  tb0384_f2 : procedure(tb0384_w:word);
{$pop}

{ Case tb0354.pp }
{$push}
type
   tb0354_a = function ( ) : boolean;
{$pop}

begin
  { Case tb0384.pp }
  {$push}
begin
  tb0384_f1:=tb0384_p1;
  tb0384_f2:=tb0384_p1;
  tb0384_f1(1);
  tb0384_f2(1);
  if tb0384_count<>3 then
   begin
     writeln('ERROR!');
     halt(1);
   end;
end;
  {$pop}

  { Case tb0354.pp }
  {$push}
begin
end;
  {$pop}

end.
