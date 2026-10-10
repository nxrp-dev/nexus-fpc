{ Out-parameter modeswitch directive spellings. }
{ Original case IDs are retained below. }

{ Case tb0549.pp }
{$push}
{$modeswitch out+}
procedure tb0549_p(out o);
  begin
  end;
{$pop}

{ Case tb0550.pp }
{$push}
{$modeswitch out}
procedure tb0550_p(out o);
  begin
  end;
{$pop}

begin
end.
