{ String comparison Boolean results and AnsiString concatenation in a loop. }
{ Original case IDs and variable scopes are retained below. }

uses erroru;

{ Case tb0189.pas }
{$push}
{ Old file: tbs0223.pas }
{ wrong boolean evaluation in writeln                  OK 0.99.11 (PFV) }


var tb0189_a:string;
{$pop}

{ Case tb0211.pas }
{$push}
{ Old file: tbs0250.pas }
{ error with Ansistrings and loops.                    OK 0.99.11 (PFV) }

// Removing this switch removes the bug !!
{$H+}

var tb0211_a : String;
    tb0211_p : PChar;
    tb0211_i : longint;
{$pop}

begin
  { Case tb0189.pas }
  {$push}
begin
  writeln('B:'='B:');            { debugger evaluates this to FALSE }
  if 'B:'='B:' then
    writeln('OK')
  else
    error;
  tb0189_a:='A:';
  inc(tb0189_a[1]);
  writeln(tb0189_a='B:');               { TRUE }
  if tb0189_a='B:' then
    writeln('OK')
  else
    error;
end;
  {$pop}

  { Case tb0211.pas }
  {$push}
  {$H+}
begin
  tb0211_p := 'Some sample testchar';
  tb0211_a := Ansistring(tb0211_p);
  Writeln ('A : ',tb0211_a);
  for tb0211_i:=1 to length(tb0211_a)-1 do
    begin
    tb0211_a:='Some small test';
    tb0211_a:=tb0211_a+' ansistring';
    Writeln ('A : ',tb0211_a);
    If tb0211_a<>'' then
      Writeln ('All is fine')
    else
      begin
         writeln ('Oh-oh!');
         error;
      end;
    end;
end;
  {$pop}

end.
