{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tstatementexpr12.pp }
{$push}

{$ModeSwitch StatementExpressions}
var
  tstatementexpr12_counter: Integer;

function tstatementexpr12_Foo: String;
begin
  Inc(tstatementexpr12_Counter);
  Result := 'Foo';
end;

function tstatementexpr12_Bar: String;
begin
  Inc(tstatementexpr12_Counter);
  Result := 'Bar';
end;

var
  tstatementexpr12_s: String;

{$pop}

{ Case tstatementexpr26.pp }
{$push}

{$ModeSwitch StatementExpressions}

function tstatementexpr26_ConditionalThrow(doRaise: Boolean): String;
begin
  Result := 'Foo';
  if doRaise then raise TObject.Create;
end;

var
  tstatementexpr26_s: String;

{$pop}

{ Case tstatementexpr28.pp }
{$push}
{$H+}
{$ModeSwitch StatementExpressions}

const
  tstatementexpr28_aUnicodeString = UnicodeString('Foo');

var
  tstatementexpr28_s: UnicodeString;

{$pop}

{ Case tstatementexpr33.pp }
{$push}
{ nested statement expressions }
{$H+}
{$ModeSwitch StatementExpressions}

function tstatementexpr33_Twice(const tstatementexpr33_s: String): String;
begin
  Result := tstatementexpr33_s + tstatementexpr33_s;
end;

var
  tstatementexpr33_i: Integer;
  tstatementexpr33_s: String;

{$pop}

{ Case tstatementexpr35.pp }
{$push}
{ optional semicolons before end, exhaustive boolean case }
{$H+}
{$ModeSwitch StatementExpressions}

function tstatementexpr35_ConditionalThrow(doRaise: Boolean): String;
begin
  Result := 'Foo';
  if doRaise then raise TObject.Create;
end;

var
  tstatementexpr35_s: String;
  tstatementexpr35_b: Boolean;

{$pop}

{ Case tstatementexpr6.pp }
{$push}
{$H+}
{$ModeSwitch StatementExpressions}
var
  tstatementexpr6_s, tstatementexpr6_c: String;

{$pop}

begin

{ Case tstatementexpr12.pp }
{$push}

{$ModeSwitch StatementExpressions}
begin
  tstatementexpr12_s := if 0<1 then tstatementexpr12_Foo else tstatementexpr12_Bar;
  WriteLn(tstatementexpr12_Counter, ': ', tstatementexpr12_s);
  if tstatementexpr12_Counter<>1 then
    Halt(1);
  if tstatementexpr12_s <> 'Foo' then
    Halt(2);
end;
{$pop}

{ Case tstatementexpr26.pp }
{$push}

{$ModeSwitch StatementExpressions}
begin
  tstatementexpr26_s := try tstatementexpr26_ConditionalThrow(False) except 'Error' end;
  WriteLn(tstatementexpr26_s);
  if (tstatementexpr26_s<>'Foo') then
    Halt(1);
  tstatementexpr26_s := try tstatementexpr26_ConditionalThrow(True) except 'Error' end;
  WriteLn(tstatementexpr26_s);
  if (tstatementexpr26_s<>'Error') then
    Halt(2);
  tstatementexpr26_s := try tstatementexpr26_ConditionalThrow(True) except on o: TObject do 'TObject' else 'Error' end;
  WriteLn(tstatementexpr26_s);
  if (tstatementexpr26_s<>'TObject') then
    Halt(3);
end;
{$pop}

{ Case tstatementexpr28.pp }
{$push}

{$H+}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr28_s:= if false then tstatementexpr28_aUnicodeString else '';
  if tstatementexpr28_s<>'' then
    Halt(1);
end;
{$pop}

{ Case tstatementexpr33.pp }
{$push}

{$H+}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr33_i := 2;
  tstatementexpr33_s := case tstatementexpr33_i of
    1: 'One';
    2: if Odd(tstatementexpr33_i) then 'OddTwo' else 'EvenTwo';
    else 'Other'
  end;
  WriteLn(tstatementexpr33_s);
  if tstatementexpr33_s<>'EvenTwo' then
    Halt(1);

  tstatementexpr33_s := tstatementexpr33_Twice(if tstatementexpr33_i > 1 then 'A' else 'B');
  WriteLn(tstatementexpr33_s);
  if tstatementexpr33_s<>'AA' then
    Halt(2);

  tstatementexpr33_s := if tstatementexpr33_i = 2 then case tstatementexpr33_i of 2: 'Two'; else 'NotTwo' end else 'Else';
  WriteLn(tstatementexpr33_s);
  if tstatementexpr33_s<>'Two' then
    Halt(3);

  tstatementexpr33_i := (if tstatementexpr33_i = 2 then 10 else 20) + 1;
  WriteLn(tstatementexpr33_i);
  if tstatementexpr33_i<>11 then
    Halt(4);
end;
{$pop}

{ Case tstatementexpr35.pp }
{$push}

{$H+}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr35_s := try tstatementexpr35_ConditionalThrow(True) except 'Error'; end;
  if tstatementexpr35_s<>'Error' then
    Halt(1);
  tstatementexpr35_s := try tstatementexpr35_ConditionalThrow(True) except on o: TObject do 'TObject'; else 'Error'; end;
  if tstatementexpr35_s<>'TObject' then
    Halt(2);
  tstatementexpr35_b := True;
  tstatementexpr35_s := case tstatementexpr35_b of
    False: 'F';
    True: 'T'
  end;
  if tstatementexpr35_s<>'T' then
    Halt(3);
  tstatementexpr35_s := case 3 of
    1: 'One';
    else 'Other';
  end;
  if tstatementexpr35_s<>'Other' then
    Halt(4);
end;
{$pop}

{ Case tstatementexpr6.pp }
{$push}

{$H+}
{$ModeSwitch StatementExpressions}
begin
  tstatementexpr6_c:='Bar';
  tstatementexpr6_s := case tstatementexpr6_c of
    'Foo': 'Foo';
    'Bar': 'Bar';
    else 'FooBar'
  end;

  WriteLn(tstatementexpr6_s);
  if (tstatementexpr6_s<>'Bar') then
    Halt(1);
end;
{$pop}

end.
