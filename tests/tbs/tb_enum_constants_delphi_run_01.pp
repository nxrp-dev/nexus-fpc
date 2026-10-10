{ Enumeration aliases and constant ordinal casts in Delphi mode. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

{ Case tb0360.pp }
{$push}
type
  tb0360_e = (
    tb0360_ptrace_singlestep = 9,
    tb0360_pt_step = tb0360_ptrace_singlestep
  );
{$pop}

{ Case tb0370.pp }
{$push}
type
   tb0370_tenum = (tb0370_e1,tb0370_e2,tb0370_e3);

const
   tb0370_e256 = tb0370_tenum(256);
{$pop}

begin
  { Case tb0360.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0370.pp }
  {$push}
begin
end;
  {$pop}

end.
