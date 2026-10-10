{ Interrupt routine calls and external/public routine aliases. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0257.pp }
{$push}
{ Old file: tbs0297.pp }
{ calling of interrupt procedure allowed but wrong code generated OK 0.99.13 (PM) }

procedure tb0257_int;interrupt;
begin
end;
{$pop}

{ Case tb0613.pp }
{$push}
procedure TestProc1; external;
procedure TestProc2; pascal; external;

procedure Ext_TestProc1; public name 'TestProc1';
begin
end;

procedure Ext_TestProc2; pascal; public name 'TestProc2';
begin
end;
{$pop}

begin
  { Case tb0257.pp }
  {$push}
begin
  tb0257_int;
end;
  {$pop}

  { Case tb0613.pp }
  {$push}
begin
  TestProc1;
  TestProc2;
end;
  {$pop}

end.
