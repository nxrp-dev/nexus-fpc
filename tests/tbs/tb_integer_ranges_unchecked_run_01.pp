{ Integer narrowing, large literals and unsigned division with range checking disabled. }
{ Original case IDs and variable scopes are retained below. }

{$R-}

{ Case tb0077.pp }
{$push}
{ Old file: tbs0084.pp }
{  no more pascal type checking                          OK 0.99.1 (FK) }

{$R-}

{ Basic Pascal principles gone done the drain... !!!! }

var
 tb0077_v: word;
 tb0077_w: shortint;
 tb0077_z: byte;
 tb0077_y: integer;
{$pop}

{ Case tb0090.pp }
{$push}
{ Old file: tbs0106.pp }
{ typecasts are now ignored problem (NOT A bugs)         OK 0.99.1 }

{$R-}

{ I think this now occurs with most type casting... }
{ I think type casting is no longer considered??     }

Var
 tb0090_sel: Word;
 tb0090_sel2: byte;
{$pop}

{ Case tb0250.pp }
{$push}
{ Old file: tbs0290.pp }
{ problem with storing hex numbers in integers }

{ $R+ would give compile time errors }
{$R-}

var tb0250_i,tb0250_j : integer;
{$pop}

{ Case tb0598.pp }
{$push}
{$R-}

var
  tb0598_a: Cardinal;
  tb0598_b: QWord;
  tb0598_c1, tb0598_c2: QWord;
{$pop}

begin
  { Case tb0077.pp }
  {$push}
Begin
 tb0077_y:=64000;
 tb0077_z:=32767;
 tb0077_w:=64000;
 tb0077_v:=-1;
end;
  {$pop}

  { Case tb0090.pp }
  {$push}
Begin
 tb0090_sel:=word($7fffffff);
 tb0090_sel2:=byte($7fff);
end;
  {$pop}

  { Case tb0250.pp }
  {$push}
begin
  { the following line gives a warning and $ffff is changed to $7fff!}
  tb0250_i := $ffff;
  if tb0250_i <> $ffff then
    begin
      Writeln('i:=$ffff loads ',tb0250_i,'$7fff if i is integer !');
    end;
  tb0250_j := 65535;
  if tb0250_j <> 65535 then
    begin
      Writeln('j:=65535 loads ',tb0250_j,' if j is integer !');
    end;
  if ($ffff=65535) and (tb0250_i<>tb0250_j) then
    begin
      Writeln('i and j are different !!!');
      Halt(1);
    end;
end;
  {$pop}

  { Case tb0598.pp }
  {$push}
begin
  tb0598_a := 1000000;
  tb0598_b := 10000000000000000000;
  tb0598_c1 := tb0598_b div tb0598_a;
  tb0598_c2 := 10000000000000000000 div tb0598_a;
  Write(tb0598_c1, ' = ', tb0598_c2, ': ');
  if (tb0598_c1 <> tb0598_c2) or (tb0598_c2 <> 10000000000000) then
  begin
    Writeln('FAIL');
    halt(1);
  end
  else
    Writeln('OK');
end;
  {$pop}

end.
