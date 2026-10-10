{ Writable typed constants and named platform-warning directives. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0382.pp }
{$push}
{$J+}
const
  tb0382_w1 : word = 1;
{$pop}

{ Case tb0491.pp }
{$push}
{$WARN SYMBOL_PLATFORM OFF}
{$pop}

begin
  { Case tb0382.pp }
  {$push}
{$J+}
begin
  tb0382_w1:=2;
end;
  {$pop}

  { Case tb0491.pp }
  {$push}
{$WARN SYMBOL_PLATFORM OFF}
begin
end;
  {$pop}

end.
