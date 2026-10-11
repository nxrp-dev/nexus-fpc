{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tstatementexpr10.pp }
{$push}
{$ModeSwitch StatementExpressions}

type
  tstatementexpr10_TS3 = String[3];
  tstatementexpr10_TS12 = String[12];

var
  tstatementexpr10_s: String;

{$pop}

{ Case tstatementexpr11.pp }
{$push}
{$ModeSwitch StatementExpressions}
var
  tstatementexpr11_sz: SizeInt;

{$pop}

{ Case tstatementexpr13.pp }
{$push}
{$ModeSwitch StatementExpressions}
var
  tstatementexpr13_s: String;

{$pop}

{ Case tstatementexpr18.pp }
{$push}
{$ModeSwitch StatementExpressions}
var
  tstatementexpr18_s: String;

{$pop}

{ Case tstatementexpr21.pp }
{$push}
{$ModeSwitch StatementExpressions}
var
  tstatementexpr21_s: String;

{$pop}

{ Case tstatementexpr25.pp }
{$push}
{$ModeSwitch StatementExpressions}
var
  tstatementexpr25_sz: SizeInt;

{$pop}

{ Case tstatementexpr3.pp }
{$push}
{$ModeSwitch StatementExpressions}
var
  tstatementexpr3_s: String;

{$pop}

{ Case tstatementexpr8.pp }
{$push}
{$ModeSwitch StatementExpressions}
var
  tstatementexpr8_s: String;

{$pop}

begin

{ Case tstatementexpr10.pp }
{$push}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr10_s := case 5 of
    0..4: tstatementexpr10_TS3('Foo');
    5: tstatementexpr10_TS12('FooBar');
    otherwise tstatementexpr10_TS3('Bar')
  end;
  WriteLn(tstatementexpr10_s);
  if (tstatementexpr10_s<>'FooBar') then Halt(1);
end;
{$pop}

{ Case tstatementexpr11.pp }
{$push}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr11_sz := sizeOf((
    case 5 of
    0: 'Foo';
    5: widestring('Bar');
    else 'FooBar'
    end
  )[1]);
  WriteLn(tstatementexpr11_sz);
  if (tstatementexpr11_sz<>2) then Halt(1);
end;
{$pop}

{ Case tstatementexpr13.pp }
{$push}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr13_s := if 0 < 1 then 'Foo' else 'Bar';
  WriteLn(tstatementexpr13_s);
  if (tstatementexpr13_s<>'Foo') then
    Halt(1);
end;
{$pop}

{ Case tstatementexpr18.pp }
{$push}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr18_s := if 0 < 1 then 'Foo' else
       if 1 < 2 then 'Bar' else
       'Baz';
  WriteLn(tstatementexpr18_s);
  if (tstatementexpr18_s<>'Foo') then
    Halt(1);
end;
{$pop}

{ Case tstatementexpr21.pp }
{$push}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr21_s := if 0 < 1 then 'Foo' else 'Bar' + 'Baz';
  WriteLn(tstatementexpr21_s);
  if (tstatementexpr21_s<>'Foo') then
    Halt(1);
end;
{$pop}

{ Case tstatementexpr25.pp }
{$push}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr25_sz := sizeOf((if 0<1 then 'Foo' else widestring('Bar'))[1]);
  WriteLn(tstatementexpr25_sz);
  if (tstatementexpr25_sz<>2) then Halt(1);
end;
{$pop}

{ Case tstatementexpr3.pp }
{$push}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr3_s := case 5 of
    0: 'Foo';
    1..9: 'Bar';
    else 'FooBar'
  end;

  WriteLn(tstatementexpr3_s);
  if (tstatementexpr3_s<>'Bar') then
    Halt(1);
end;
{$pop}

{ Case tstatementexpr8.pp }
{$push}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr8_s := case 5 of
    0: 'Foo';
    1..9: 'Bar';
    otherwise 'FooBar'
  end;

  WriteLn(tstatementexpr8_s);
  if (tstatementexpr8_s<>'Bar') then
    Halt(1);
end;
{$pop}

end.
