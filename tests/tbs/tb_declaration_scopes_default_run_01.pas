{ Context-sensitive Self identifiers and nested unused type declarations. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0136.pas }
{$push}
{ Old file: tbs0160.pas }
{ Incompatibility with BP: Self shouldn't be a reserved word. OK 0.99.9 (PM) }

procedure tb0136_yyyy;

var self:word;

begin
end;

procedure self;

begin
end;
{$pop}

{ Case tb0248.pas }
{$push}
{ Old file: tbs0289.pas }
{ no hint/note for unused types : implemented with -vnh OK 0.99.13 (PM) }


procedure tb0248_p;
type
  tb0248_k1 = word;
begin
end;

type
  tb0248_k2 = word;
{$pop}

begin
  { Case tb0136.pas }
  {$push}
begin
end;
  {$pop}

  { Case tb0248.pas }
  {$push}
begin
end;
  {$pop}

end.
