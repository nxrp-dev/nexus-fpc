{ Component construction after NewInstance and construction of owned components. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

uses Classes;

{ Case tb0280.pp }
{$push}
{ Old file: tbs0332.pp }
{  }

var
  tb0280_o: TComponent;
{$pop}

{ Case tb0285.pp }
{$push}
{ Old file: tbs0337.pp }
{  }

type
  tb0285_tmycomponent = class(TComponent)
    tb0285_aaaaaaaaaa: TComponent;
    tb0285_b: TComponent;
  private
  public
    constructor Create(tb0285_aowner: TComponent); override;
  end;


constructor tb0285_tmycomponent.Create(tb0285_aowner: TComponent);
begin
  inherited Create(tb0285_aowner);
  tb0285_aaaaaaaaaa := TComponent.Create(Self);
end;

var
  tb0285_mycomponent: tb0285_tmycomponent;
{$pop}

begin
  { Case tb0280.pp }
  {$push}
begin
    tb0280_o := TComponent(TComponent.NewInstance);
    tb0280_o.Create(nil);
    tb0280_o.Free;
  end;
  {$pop}

  { Case tb0285.pp }
  {$push}
begin
  tb0285_mycomponent := tb0285_tmycomponent.Create(nil);
end;
  {$pop}

end.
