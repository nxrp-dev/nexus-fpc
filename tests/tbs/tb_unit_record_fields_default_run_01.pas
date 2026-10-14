{ Variant-record tags and object enumeration fields declared in helper units. }
{ Original case IDs and variable scopes are retained below. }

uses ub0308, ub0313;

{ Case tb0308.pas }
{$push}
var
     tb0308_r : tr;
{$pop}

{ Case tb0313.pas }
{$push}
var
  tb0313_arec : rec;
{$pop}

begin
  { Case tb0308.pas }
  {$push}
begin
     tb0308_r.a:=x;
     if tb0308_r.a=x then
       begin
          with tb0308_r do
            if a=y then
              ;
       end;
  end;
  {$pop}

  { Case tb0313.pas }
  {$push}
begin
  tb0313_arec.nrs:=one;
  if tb0313_arec.nrs<>one then
    begin
       Writeln('Error with enums inside objects');
       Halt(1);
    end;
end;
  {$pop}

end.
