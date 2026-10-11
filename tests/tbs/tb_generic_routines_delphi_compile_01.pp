{ %norun }
{ Generic routine overloads and typed generic default arguments. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

{ Case tw35670b.pp }
{$push}
procedure tw35670b_dothis<T>(tw35670b_msg: T);
begin
end;

procedure tw35670b_dothis(tw35670b_msg: TObject);
begin
end;
{$pop}

{ Case tw37380.pp }
{$push}
function tw37380_gtest<T>(tw37380_a: T; tw37380_b: T = T(1)): T;
begin
  Result := tw37380_a + tw37380_b;
end;

function tw37380_foobar(tw37380_a: Single; tw37380_b: Single = Single(1)): Single;
begin
  Result := tw37380_a + tw37380_b;
end;
{$pop}

{ Case tw38083.pp }
{$push}
procedure tw38083_test<T>(tw38083_a: T; tw38083_b: Boolean); overload;
  begin

  end;

  procedure tw38083_test(tw38083_a: String); overload;
  begin
    tw38083_test<String>(tw38083_a, True);
  end;
{$pop}

begin
  { Case tw35670b.pp }
  {$push}
begin

end;
  {$pop}

  { Case tw37380.pp }
  {$push}
begin
  WriteLn(tw37380_gtest<Single>(2, 1));
  WriteLn(tw37380_foobar(2));
end;
  {$pop}

  { Case tw38083.pp }
  {$push}
begin

end;
  {$pop}

end.
