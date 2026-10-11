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

end.
