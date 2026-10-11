{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}
uses sysutils;

{ Case tw27173.pp }
{$push}






type tw27173_a = 1..MaxInt;

var tw27173_b: tw27173_a;
    tw27173_c: integer;


{$pop}

{ Case tw31521.pp }
{$push}






var
  tw31521_X: Int64;

{$pop}

{ Case tw38122c.pp }
{$push}




 var
   tw38122c_j:integer;

{$pop}

{ Case tw39748.pp }
{$push}


type
  tw39748_glenum=word;
  tw39748_TglGetError = function(): tw39748_GLenum; cdecl;

function tw39748_test: tw39748_glenum; cdecl;
begin
  result:=42;
end;

var tw39748_glgeterror : tw39748_TGlGeterror;

{$pop}

begin

{ Case tw27173.pp }
{$push}

begin
 tw27173_b := 3;
 tw27173_c := -5 div tw27173_b;
 writeln(tw27173_c);
end;
{$pop}

{ Case tw31521.pp }
{$push}

begin
  if tw31521_X.MaxValue <> High(tw31521_X) then
    Halt(1);
  {Writeln(X.MaxValue.ToString);
  Writeln(IntToStr(High(X)));
  Readln;}
end;
{$pop}

{ Case tw38122c.pp }
{$push}

begin
  tw38122c_j:=22;
  if pinteger(@tw38122c_j)^.tostring <> '22' then
    halt(1);
end;
{$pop}

{ Case tw39748.pp }
{$push}

begin
  tw39748_glgeterror:=tw39748_test;
  if inttostr(tw39748_glgeterror)<>'42' then
    halt(1);
end;
{$pop}

end.
