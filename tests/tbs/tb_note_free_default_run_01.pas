{ %opt=-Sen -vn }
{ No unused-variable notes for public variables or With accesses to indexed records. }
{ Original case IDs and variable scopes are retained below. }

{$mode fpc}

{ Case tb0271.pas }
{$push}
{ Old file: tbs0317.pas }

{ This shouldn't give a warning, because it can be used in another program }
var
  tb0271_exportedc : longint;cvar;public;
{$pop}

{ Case tb0287.pas }
{$push}
{ Old file: tbs0339.pas }

type
  tb0287_rec=record
    tb0287_x,tb0287_y : longint;
  end;
var
  tb0287_r : array[1..10] of tb0287_rec;
  tb0287_i : longint;
{$pop}

begin
  { Case tb0271.pas }
  {$push}
begin
  tb0271_exportedc:=0;
end;
  {$pop}

  { Case tb0287.pas }
  {$push}
begin
  tb0287_i:=1;
  with tb0287_r[tb0287_i] do
   begin
     tb0287_x:=1;
     tb0287_y:=1;
   end;
  with tb0287_r[tb0287_i] do
   begin
     writeln(tb0287_x,tb0287_y);
   end;
end;
  {$pop}

end.
