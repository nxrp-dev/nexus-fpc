{ Procedure-variable calls and routine address comparisons. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0028.pp }
{$push}
{ Old file: tbs0032.pp }
{  tests for a bugs with the stack                      OK 0.9.9 }

var
   tb0028_p : procedure(w : word);

  procedure tb0028_pp(w :word);
    begin
       Writeln(w);
    end;
{$pop}

{ Case tb0158.pp }
{$push}
{ Old file: tbs0189.pp }
{ cant compare addresses of function variables !! As tbs0188 FPC syntax problem see source (PM) }

var tb0158_m: procedure;

procedure tb0158_test;
begin
end;

procedure tb0158_test2;
begin
end;
{$pop}

begin
  { Case tb0028.pp }
  {$push}
begin
   tb0028_p:=@tb0028_pp;
   tb0028_p(1234);
end;
  {$pop}

  { Case tb0158.pp }
  {$push}
begin
 if @tb0158_test <> @tb0158_test2 then
   writeln('different!')
 else
   writeln('error');
 tb0158_m:=@tb0158_test;

 { here also the syntax was wrong !! }
 {  @m <> @test have different types !! }
 if tb0158_m <> @tb0158_test then
   writeln('error');
end;
  {$pop}

end.
