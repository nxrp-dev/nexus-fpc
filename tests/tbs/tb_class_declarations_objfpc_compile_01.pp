{ %norun }
{ Class option-set operations and coexistence of class and instance destructors. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

{ Case tb0585.pp }
{$push}
type
  tb0585_tobjectoptions = set of (tb0585_oo_is_external, tb0585_oo_is_forward, tb0585_oo_is_formal);

  tb0585_tobjectdef = class
    tb0585_objectoptions: tb0585_tobjectoptions;
  end;

procedure tb0585_finalize_class_external_status(tb0585_od: tb0585_tobjectdef);
  begin
    if  [tb0585_oo_is_external,tb0585_oo_is_forward] <= tb0585_od.tb0585_objectoptions then
      begin
        { formal definition: x = objcclass external; }
        exclude(tb0585_od.tb0585_objectoptions,tb0585_oo_is_forward);
        include(tb0585_od.tb0585_objectoptions,tb0585_oo_is_formal);
      end;
  end;
{$pop}

{ Case tb0679.pp }
{$push}
type
  tb0679_ta = class
  public
    class destructor Destroy;
    destructor Destroy; override;
  end;

class destructor tb0679_ta.Destroy;
begin
end;

destructor tb0679_ta.Destroy;
begin
  inherited;
end;

var
  tb0679_a: tb0679_ta;
{$pop}

begin
  { Case tb0585.pp }
  {$push}
begin

end;
  {$pop}

  { Case tb0679.pp }
  {$push}
begin
  tb0679_a := tb0679_ta.Create;
  tb0679_a.Free;
end;
  {$pop}

end.
