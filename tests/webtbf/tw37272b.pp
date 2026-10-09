{ %FAIL }

program tw37272b;

{ note: there is a tw37272a in tbs/tb_arrays_objfpc_run_02.pp }

{$mode objfpc}

type
  TA1 = array of integer;

procedure Test(A: integer; const B: TA1 = [1]);
begin end;

begin
  Test(1, []);
  Test(1);
end.
