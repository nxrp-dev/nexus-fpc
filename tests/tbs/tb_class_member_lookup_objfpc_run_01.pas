{ Private inherited overloads and protected members in With lookup across units. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

uses ub0386, ub0391;

{ Case tb0386.pas }
{$push}
type
  tb0386_tobj2 = class (tobj1)
      { this will try to override tobj.proc1, it should not
        see tobj1.proc1 }
      procedure proc1 (a: integer);override;
  end;

procedure tb0386_tobj2.proc1 (a: integer);
begin
end;
{$pop}

{ Case tb0391.pas }
{$push}
type
  tb0391_tc1 = class
    procedure p1(l:longint);
    procedure p2;
  end;

procedure tb0391_tc1.p1(l:longint);
begin
  writeln('longint: ',l);
end;


procedure tb0391_tc1.p2;
var
  tb0391_c2 : tc2;
begin
  tb0391_c2:=tc2.create;
  { the next code should take tc1.p1(longint) as the tc2.p1 can not
    be seen from here! }
  with tb0391_c2 do
   p1(100);
  tb0391_c2.free;
end;


var
  tb0391_c1 : tb0391_tc1;
{$pop}

begin
  { Case tb0386.pas }
  {$push}
begin
end;
  {$pop}

  { Case tb0391.pas }
  {$push}
begin
  tb0391_c1:=tb0391_tc1.create;
  tb0391_c1.p2;
  tb0391_c1.free;
end;
  {$pop}

end.
