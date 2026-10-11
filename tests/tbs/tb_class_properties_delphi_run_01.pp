{ Indexed class properties and untyped Const arguments passed from properties. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

{ Case tb0346.pp }
{$push}
type
tb0346_aclass=class
 private
  tb0346_aa:longint;
  procedure tb0346_bb(index:integer;tb0346_value:longint);
 public
  property tb0346_cc:longint index 1 read tb0346_aa write tb0346_bb;
end;
procedure tb0346_aclass.tb0346_bb(index:integer;tb0346_value:longint);
 begin
  tb0346_aa:=tb0346_value;
 end;
var
 tb0346_c:tb0346_aclass;
{$pop}

{ Case tb0475.pp }
{$push}
type
  tb0475_to1 = class
     tb0475_fp : longint;
     property tb0475_p : longint read tb0475_fp write tb0475_fp;
  end;

procedure tb0475_p(const tb0475_v);
  begin
  end;

var
  tb0475_a : pchar;
  tb0475_o1 : tb0475_to1;
{$pop}

begin
  { Case tb0346.pp }
  {$push}
begin
 tb0346_c:=tb0346_aclass.Create;
 tb0346_c.tb0346_cc:=1;
 writeln(tb0346_c.tb0346_cc);
end;
  {$pop}

  { Case tb0475.pp }
  {$push}
begin
  tb0475_o1:=tb0475_to1.create;
  tb0475_p(tb0475_a[0]);
  tb0475_p(tb0475_o1.tb0475_p);
  tb0475_o1.free;
end;
  {$pop}

end.
