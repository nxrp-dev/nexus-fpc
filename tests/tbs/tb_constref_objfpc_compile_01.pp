{ %norun }
{ Untyped Const and ConstRef forwarding and default ConstRef strings. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

{ Case tb0656.pp }
{$push}
procedure tb0656_test1(const tb0656_aarg);
begin
end;

procedure tb0656_test2(const tb0656_aarg);
begin
  tb0656_test1(tb0656_aarg);
end;

procedure tb0656_test3(constref tb0656_aarg);
begin
end;

procedure tb0656_test4(constref tb0656_aarg);
begin
  tb0656_test3(tb0656_aarg);
end;
{$pop}

{ Case tw29992.pp }
{$push}
procedure tw29992_test(constref tw29992_aparam: String = 'def_param');
begin
  writeln(tw29992_aparam);
end;
{$pop}

begin
  { Case tb0656.pp }
  {$push}
begin

end;
  {$pop}

  { Case tw29992.pp }
  {$push}
begin
end;
  {$pop}

end.
