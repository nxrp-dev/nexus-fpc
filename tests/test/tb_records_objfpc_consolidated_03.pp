{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case toperator11.pp }
{$push}


{$H+}
{$apptype console}

type
  toperator11_TFoo = record
    F: Integer;
  end;

operator Inc(toperator11_a: toperator11_TFoo): toperator11_TFoo;
begin
  Result.F := toperator11_a.F + 1;
end;

operator Dec(toperator11_a: toperator11_TFoo): toperator11_TFoo;
begin
  Result.F := toperator11_a.F - 1;
end;

operator :=(toperator11_a: toperator11_TFoo): Integer;
begin
  Result := toperator11_a.F;
end;

operator explicit(toperator11_a: toperator11_TFoo): Integer;
begin
  Result := toperator11_a.F + 1;
end;

var
  toperator11_a: toperator11_TFoo;
  toperator11_i: Integer;

{$pop}

{ Case toperator8.pp }
{$push}



{$apptype console}

type
  toperator8_TFoo = record
    F: Integer;
  end;

  toperator8_TBar = record
    F: Integer;
  end;

var
  toperator8_Test: Integer = 0;

operator =(const toperator8_F1, toperator8_F2: toperator8_TFoo): Boolean;
begin
  Result := toperator8_F1.F = toperator8_F2.F;
  toperator8_Test := 1;
end;

operator <>(const toperator8_F1, toperator8_F2: toperator8_TFoo): Boolean;
begin
  Result := toperator8_F1.F <> toperator8_F2.F;
  toperator8_Test := 2;
end;

operator =(const toperator8_F1, toperator8_F2: toperator8_TBar): Boolean;
begin
  Result := toperator8_F1.F = toperator8_F2.F;
  toperator8_Test := 3;
end;

var
  toperator8_F1, toperator8_F2: toperator8_TFoo;
  toperator8_B1, toperator8_B2: toperator8_TBar;

{$pop}

{ Case toperator9.pp }
{$push}


// Check IN operator support

{$H+}
{$apptype console}

type
  toperator9_TFoo = record
    F: Integer;
  end;

operator in(const I: Integer; const toperator9_Foo: toperator9_TFoo): Boolean;
begin
  Result := toperator9_Foo.F = I;
end;

var
  toperator9_Foo: toperator9_TFoo;

{$pop}

begin

{ Case toperator11.pp }
{$push}

{$H+}
{$apptype console}
begin
  toperator11_a.F := 1;
  inc(toperator11_a);
  if toperator11_a.F <> 2 then
    halt(1);
  dec(toperator11_a);
  if toperator11_a.F <> 1 then
    halt(2);
  toperator11_i := toperator11_a;
  if toperator11_i <> 1 then
    halt(3);
  if Integer(toperator11_a) <> 2 then
    halt(4);
  WriteLn('ok');
end;
{$pop}

{ Case toperator8.pp }
{$push}

{$apptype console}
begin
  toperator8_F1.F := 1;
  toperator8_F2.F := 2;
  if toperator8_F1 = toperator8_F2 then
    halt(1);
  if toperator8_Test <> 1 then
    halt(2);
  toperator8_F2.F := 1;
  if toperator8_F1 <> toperator8_F2 then
    halt(3);
  if toperator8_Test <> 2 then
    halt(4);
  toperator8_B1.F := 1;
  toperator8_B2.F := 2;
  if toperator8_B1 = toperator8_B2 then
    halt(5);
  if toperator8_Test <> 3 then
    halt(6);
  toperator8_B2.F := 1;
  if toperator8_B1 <> toperator8_B2 then
    halt(7);
  WriteLn('ok');
end;
{$pop}

{ Case toperator9.pp }
{$push}

{$H+}
{$apptype console}
begin
  toperator9_Foo.F := 1;
  if not (1 in toperator9_Foo) then
    halt(1);
  if 2 in toperator9_Foo then
    halt(2);
  WriteLn('ok');
end;
{$pop}

end.
