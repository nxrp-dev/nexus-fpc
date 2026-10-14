{ Consolidated integers regressions; original case IDs and assertions are retained. }
{ %OPT=-Sew -vw -Oodfa }
{ %NORUN }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tw11846a.pas }
{$push}



function tw11846a_Test(a: integer): boolean;
var
  i: Integer;
begin
  for i:=1 to 2 do
    Result:=true;
end;


{$pop}

{ Case tw11846b.pas }
{$push}



function tw11846b_Test(a: integer): boolean;
var
  i: Integer;
begin
  for i:=2 to 1 do
    Result:=true;
  Result:=true;
end;


{$pop}

{ Case tw11849.pas }
{$push}



procedure tw11849_GiveMe(out i: integer);
begin
  i:=0;
end;

function tw11849_Test(a: integer): integer;
var
  i: integer;
begin
  tw11849_GiveMe(i);
  Result:=i;
end;



{$pop}

begin

{ Case tw11846a.pas }
{$push}

begin
end;
{$pop}

{ Case tw11846b.pas }
{$push}

begin
end;
{$pop}

{ Case tw11849.pas }
{$push}

begin
end;
{$pop}

end.
