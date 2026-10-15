{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tanonfunc33.pas }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test generic anonymous method reference }

type
  tanonfunc33_TProc<T> = reference to procedure(Arg: T);

procedure tanonfunc33_Foo;
var
  p: tanonfunc33_TProc<Integer>;
  acc: Integer;
begin
  p := procedure(Arg: Integer)
  begin
    Inc(acc, Arg);
  end;
  acc := 1;
  p(2);
  if acc <> 3 then
    halt(1);
end;


{$pop}

{ Case tanonfunc38.pas }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test generic local reference declaration }

procedure tanonfunc38_Foo;
type
  TLocalFunc<T> = reference to function(arg: T): T;
var
  F: TLocalFunc<longint>;
begin
  F := function(arg: longint): longint
    begin
      Result := arg * arg;
    end;
  if F(5) <> 25 then
    halt(1);
end;


{$pop}

{ Case tanonfunc61.pas }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test calling into overloaded routines and creating anonymous methods in them.

  Same as tanonfunc23 but with mode delphi
}

type
  tanonfunc61_tproc = reference to procedure;
  tanonfunc61_tcharproc = reference to procedure(c: char);
  tanonfunc61_tintproc = reference to procedure(i: longint);

procedure tanonfunc61_baz(p: tanonfunc61_tproc);
begin
  p();
end;

procedure tanonfunc61_bar(p: tanonfunc61_tcharproc); overload;
begin
  tanonfunc61_baz(procedure
    begin
      p('a');
    end);
end;

procedure tanonfunc61_bar(p: tanonfunc61_tintproc); overload;
begin
  tanonfunc61_baz(procedure
    begin
      p(123);
    end);
end;

procedure tanonfunc61_foo;
var
  acc: integer;
begin
  acc := 0;
  tanonfunc61_bar(procedure(c: char)
    begin
      if c = 'a' then inc(acc);
    end);
  tanonfunc61_bar(procedure(i: longint)
    begin
      if i = 123 then inc(acc);
    end);
  if acc <> 2 then halt(1);
end;


{$pop}

{ Case tanonfunc62.pas }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test calling into overloaded routines and creating anonymous methods (with no
  params) in them

  similar to tanonfunc23 and tanonfunc61 but mode Delphi and no params in tcharproc
}

type
  tanonfunc62_tproc = reference to procedure;
  tanonfunc62_tcharproc = reference to procedure;
  tanonfunc62_tintproc = reference to procedure(i: longint);

procedure tanonfunc62_baz(p: tanonfunc62_tproc);
begin
  p();
end;

procedure tanonfunc62_bar(p: tanonfunc62_tcharproc); overload;
begin
  tanonfunc62_baz(procedure
    begin
      p();
    end);
end;

procedure tanonfunc62_bar(p: tanonfunc62_tintproc); overload;
begin
  tanonfunc62_baz(procedure
    begin
      p(123);
    end);
end;

procedure tanonfunc62_foo;
var
  acc: integer;
begin
  acc := 0;
  tanonfunc62_bar(procedure{(c: char)}
    begin
      {if c = 'a' then }inc(acc);
    end);
  tanonfunc62_bar(procedure(i: longint)
    begin
      if i = 123 then inc(acc);
    end);
  if acc <> 2 then halt(1);
end;


{$pop}

{ Case tanonfunc65.pas }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test generic anonymous method reference

  same as tanonfunc34 but with mode delphi
}

type
  tanonfunc65_TProc<T> = reference to procedure(Arg: T);

procedure tanonfunc65_Foo;
var
  p: tanonfunc65_TProc<Integer>;
  acc: Integer;
begin
  p := procedure(Arg: Integer)
  begin
    Inc(acc, Arg);
  end;
  acc := 1;
  p(2);
  if acc <> 3 then
    halt(1);
end;


{$pop}

{ Case tanonfunc66.pas }
{$push}



{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}

{ test generic local reference declaration

  same as tanonfunc39 but mode delphi
}

procedure tanonfunc66_Foo;
type
  TLocalFunc<T> = reference to function(arg: T): T;
var
  F: TLocalFunc<longint>;
begin
  F := function(arg: longint): longint
    begin
      Result := arg * arg;
    end;
  if F(5) <> 25 then
    halt(1);
end;


{$pop}

begin

{ Case tanonfunc33.pas }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc33_Foo;
end;
{$pop}

{ Case tanonfunc38.pas }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc38_Foo;
end;
{$pop}

{ Case tanonfunc61.pas }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc61_foo;
end;
{$pop}

{ Case tanonfunc62.pas }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc62_foo;
end;
{$pop}

{ Case tanonfunc65.pas }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc65_Foo;
end;
{$pop}

{ Case tanonfunc66.pas }
{$push}

{$modeswitch anonymousfunctions}
{$modeswitch functionreferences}
begin
  tanonfunc66_Foo;
end;
{$pop}

end.
