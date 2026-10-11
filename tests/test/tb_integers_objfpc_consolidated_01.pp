{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tanonfunc12.pp }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test anonymous function in global scope }

type
  tanonfunc12_tproc = reference to procedure;

var
  tanonfunc12_i: longint;
  tanonfunc12_p: tanonfunc12_tproc;

{$pop}

{ Case tanonfunc13.pp }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test variable capture }

type
  tanonfunc13_tintproc = reference to procedure(x: longint);

var
  tanonfunc13_acc: longint;

function tanonfunc13_foo(z: longint): tanonfunc13_tintproc;
var
  y: integer;
begin
  y := 100;
  result := procedure(x: longint) begin
    tanonfunc13_acc := x + y + z;
  end;
end;

var
  tanonfunc13_p: tanonfunc13_tintproc;

{$pop}

{ Case tanonfunc18.pp }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test independent state when multiple functions are created }

type
  tanonfunc18_TIntFunc = reference to function: Integer;

function tanonfunc18_Foo: tanonfunc18_TIntFunc;
var
  tanonfunc18_i: Integer;
begin
  Result := function: Integer
  begin
    Result := tanonfunc18_i;
    Inc(tanonfunc18_i);
  end;
  tanonfunc18_i := 100;
end;

var
  tanonfunc18_F1, tanonfunc18_F2: tanonfunc18_TIntFunc;
  tanonfunc18_i: Integer;

{$pop}

{ Case tanonfunc23.pp }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test calling into overloaded routines and creating anonymous methods in them }

type
  tanonfunc23_tproc = reference to procedure;
  tanonfunc23_tcharproc = reference to procedure(c: char);
  tanonfunc23_tintproc = reference to procedure(i: longint);

procedure tanonfunc23_baz(p: tanonfunc23_tproc);
begin
  p();
end;

procedure tanonfunc23_bar(p: tanonfunc23_tcharproc); overload;
begin
  tanonfunc23_baz(procedure
    begin
      p('a');
    end);
end;

procedure tanonfunc23_bar(p: tanonfunc23_tintproc); overload;
begin
  tanonfunc23_baz(procedure
    begin
      p(123);
    end);
end;

procedure tanonfunc23_foo;
var
  acc: integer;
begin
  acc := 0;
  tanonfunc23_bar(procedure(c: char)
    begin
      if c = 'a' then inc(acc);
    end);
  tanonfunc23_bar(procedure(i: longint)
    begin
      if i = 123 then inc(acc);
    end);
  if acc <> 2 then halt(1);
end;


{$pop}

{ Case tanonfunc27.pp }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test accessing a captured variable from both a nested procedure and an anonymous function }

type
  tanonfunc27_tproc = reference to procedure;

procedure tanonfunc27_foo;
var
  i: Integer;

  procedure inner;
  begin
    inc(i, 20);
  end;

begin
  i := 100;
  tanonfunc27_tproc(
    procedure begin
      inc(i, 3);
    end)();
  inner;
  if i <> 123 then
    halt(1);
end;


{$pop}

{ Case tanonfunc30.pp }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test calling named function nested within an an anonymous method }

type
  tanonfunc30_TIntFunc = reference to function: Integer;

function tanonfunc30_Foo: tanonfunc30_TIntFunc;
begin
  Result := function: Integer
  var x: Integer;

    procedure bar;
    begin
      Inc(x, 2);
    end;

  begin
    x := 1;
    bar;
    Result := x;
  end;
end;


{$pop}

begin

{ Case tanonfunc12.pp }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc12_p := procedure
  begin
    tanonfunc12_i := 123;
  end;
  tanonfunc12_p();
  if tanonfunc12_i <> 123 then
    halt(1);
end;
{$pop}

{ Case tanonfunc13.pp }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc13_p := tanonfunc13_foo(20);
  tanonfunc13_p(3);
  if tanonfunc13_acc <> 123 then
    halt(1);
end;
{$pop}

{ Case tanonfunc18.pp }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc18_F1 := tanonfunc18_Foo();
  tanonfunc18_F2 := tanonfunc18_Foo();
  for tanonfunc18_i := 0 to 4 do
    tanonfunc18_F1();
  for tanonfunc18_i := 0 to 9 do
    if tanonfunc18_F1() <> tanonfunc18_F2() + 5 then
      halt(1);
end;
{$pop}

{ Case tanonfunc23.pp }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc23_foo;
end;
{$pop}

{ Case tanonfunc27.pp }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc27_foo;
end;
{$pop}

{ Case tanonfunc30.pp }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  if tanonfunc30_foo()() <> 3 then
    halt(1);
end;
{$pop}

end.
