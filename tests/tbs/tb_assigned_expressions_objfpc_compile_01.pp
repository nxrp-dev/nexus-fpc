{ %norun }
{ Assigned on nested method results and Boolean equality expressions. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

{ Case tb0584.pp }
{$push}
type
  tb0584_tsomeobj = class
    function tb0584_test(tb0584_s: String): TObject;
  end;

  tb0584_tsomeotherobj = class
  public
    function GetFoo: String;
  end;

function tb0584_tsomeobj.tb0584_test(tb0584_s: String): TObject;
begin

end;

function tb0584_tsomeotherobj.GetFoo: String;
begin

end;

var
  tb0584_someobj: tb0584_tsomeobj;

procedure tb0584_test;
var
  tb0584_b: Boolean;
  tb0584_obj: tb0584_tsomeotherobj;
begin
  tb0584_b := not Assigned(tb0584_someobj.tb0584_test(tb0584_obj.GetFoo));
end;
{$pop}

{ Case tb0586.pp }
{$push}
procedure tb0586_test;
var
  tb0586_a, tb0586_b: Boolean;
  tb0586_obj: TObject;
begin
  if assigned(tb0586_obj)<>(tb0586_a=tb0586_b) then
    ;
end;
{$pop}

begin
  { Case tb0584.pp }
  {$push}
begin

end;
  {$pop}

  { Case tb0586.pp }
  {$push}
begin

end;
  {$pop}

end.
