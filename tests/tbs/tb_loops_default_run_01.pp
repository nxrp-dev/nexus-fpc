{ Loop continue handling and evaluation of for-loop boundaries. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0003.pp }
{$push}
{ Old file: tbs0004.pp }
{  tests the continue instruction in the for loop      OK 0.9.2 }

var
   tb0003_i : longint;
{$pop}

{ Case tb0110.pp }
{$push}
{ Old file: tbs0129.pp }
{ endless loop with while/continue                      OK 0.99.6 (FK) }

var
 tb0110_e:boolean;
 tb0110_a:integer;
{$pop}

{ Case tb0115.pp }
{$push}
{ Old file: tbs0134.pp }
{ 'continue' keyword is buggy.                          OK 0.99.6 (FK) }

{
In this simple example, the even loop is wrong.  When continue; is called,
it should go back to the top and check the loop conditions and exit when i =
4, but continue skips checking the loop conditions and does i=5 too, then it
is odd, doesn't run the continue, and the loop terminates properly.
}


procedure tb0115_demoloop( max:integer );
var i : integer;
begin
i := 1;
while (i <= max) do
    begin
    if (i mod 2 = 0) then
        begin
        writeln('Even ',i,' of ',max);
        inc(i);
        continue;
        end;
    writeln('Odd ',i,' of ',max);
    inc(i);
    end;
end;
{$pop}

{ Case tb0131.pp }
{$push}
{ Old file: tbs0152.pp }
{ End value of loop variable must be calculated before loop variable is initialized.                              OK 0.99.11 (PM) }

{
  Shows wrong evaluation of loop boundaries. First end boundary must
  be calculated, only then Loop variable should be initialized.
  Change loop variable to J to see what should be the correct output.
}

PROCEDURE tb0131_lgrow(VAR tb0131_s : ShortString;C:CHAR;Count:WORD);

 VAR  I,J :WORD;

BEGIN
  I:=ORD(tb0131_s[0]);           { Keeping length in local data eases optimizations}
  IF I<Count THEN
     BEGIN
     Move(tb0131_s[1],tb0131_s[Count-I+1],I);
     FOR I:=1 TO Count-I DO
       tb0131_s[I]:=C;
     tb0131_s[0]:=CHR(Count);
     END;
END;

Var tb0131_s : ShortString;
{$pop}

{ Case tb0137.pp }
{$push}
{ Old file: tbs0162.pp }
{ continue in repeat ... until loop doesn't work correct OK 0.99.8 (PFV) }

var
   tb0137_i : longint;
{$pop}

begin
  { Case tb0003.pp }
  {$push}
begin
   for tb0003_i:=1 to 100 do
     begin
        writeln('Hello');
        continue;
        writeln('ohh');
        Halt(1);
     end;
end;
  {$pop}

  { Case tb0110.pp }
  {$push}
begin
 tb0110_e:=true;
 tb0110_a:=3;
 while (tb0110_a<5) and tb0110_e do begin
  tb0110_e:=false;
  write('*');
  continue;
 end;
end;
  {$pop}

  { Case tb0115.pp }
  {$push}
begin
writeln('Odd loop (continue is *not* last call):');
tb0115_demoloop(3);
writeln('Even loop (continue is last call):');
tb0115_demoloop(4);
end;
  {$pop}

  { Case tb0131.pp }
  {$push}
begin
  tb0131_s:='abcedfghij';
  writeln ('s : ',tb0131_s);
  tb0131_lgrow (tb0131_s,'1',17);
  writeln ('S : ',tb0131_s);
  if tb0131_s<>'1111111abcedfghij' then
    begin
       writeln('tbs0152 fails');
       halt(1);
    end;
end;
  {$pop}

  { Case tb0137.pp }
  {$push}
begin
   tb0137_i:=1;
   repeat
     continue;
   until tb0137_i=1;
end;
  {$pop}

end.
