{ %opt=-Sew -vw }
{ Warning-free result aliases, implemented abstract methods and open-array Out parameters. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

{ Case tb0376.pas }
{$push}
function tb0376_f: longint;
var
   tb0376_a: longint absolute result;
begin
   tb0376_a := 5;
end;
{$pop}

{ Case tb0424.pas }
{$push}
{ This tests that implemented abstract methods do not cause any warnings }
type
  tb0424_tmyclass = class
   procedure tb0424_myabstract; virtual; abstract;
  end;

  tb0424_tmyclass2 = class(tb0424_tmyclass)
   procedure tb0424_myabstract ; override;
  end;


  procedure tb0424_tmyclass2.tb0424_myabstract;
   begin
   end;


var
 tb0424_cla : tb0424_tmyclass2;
{$pop}

{ Case tb0534.pas }
{$push}
procedure tb0534_test(out tb0534_l: array of char);
begin
  writeln(length(tb0534_l));
end;
{$pop}

begin
  { Case tb0376.pas }
  {$push}
begin
  if tb0376_f<>5 then
   begin
     writeln('error!');
     halt(1);
   end;
end;
  {$pop}

  { Case tb0424.pas }
  {$push}
Begin
 tb0424_cla := tb0424_tmyclass2.create;
end;
  {$pop}

  { Case tb0534.pas }
  {$push}
begin
end;
  {$pop}

end.
