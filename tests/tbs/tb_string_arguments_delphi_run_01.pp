{ Temporary PAnsiChar arguments and Unicode literal assignment to ShortString. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

{ Case tb0480.pp }
{$push}
{$ifdef fpc}{$endif}

procedure tb0480_test(const tb0480_s1, tb0480_s2: PAnsiChar);
begin
  Writeln(tb0480_s1);
  Writeln(tb0480_s2);
  if ansistring(tb0480_s1)<>ansistring(tb0480_s2) then
    begin
      writeln('Error');
      halt(1);
    end;
end;

var
  tb0480_s: AnsiString;
  tb0480_p: PAnsiChar;
{$pop}

{ Case tb0600.pp }
{$push}
{$ifdef fpc}

{$endif}

var
  tb0600_s: shortstring;
{$pop}

{ Case tw10933.pp }
{$push}
var
  tw10933_s: string[3] = 'ABC';

procedure tw10933_foo(tw10933_buf: PAnsiChar; tw10933_expected: AnsiChar);
begin
  WriteLn(tw10933_buf^);
  if tw10933_buf^ <> tw10933_expected then
    Halt(1);
end;

function tw10933_classnameshort(): PShortString;
begin
  Result := @tw10933_s;
end;
{$pop}

begin
  { Case tb0480.pp }
  {$push}
begin
  tb0480_s := 'Test';
  tb0480_p := PAnsiChar(tb0480_s);
  tb0480_test(PAnsiChar('String:'+tb0480_s+';'), PAnsiChar('String:'+tb0480_s+';'));
  tb0480_test(PAnsiChar('String:'+tb0480_p+';'), PAnsiChar('String:'+tb0480_p+';'));
end;
  {$pop}

  { Case tb0600.pp }
  {$push}
begin
  tb0600_s:=#$1234;
end;
  {$pop}

  { Case tw10933.pp }
  {$push}
begin
  tw10933_foo(@tw10933_classnameshort()^[1], 'A');
  tw10933_foo(@tw10933_classnameshort()^[2], 'B');
  tw10933_foo(@tw10933_classnameshort()^[3], 'C');
end;
  {$pop}

end.
