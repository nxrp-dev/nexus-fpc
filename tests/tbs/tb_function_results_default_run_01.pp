{ Nested assignment to function results and explicit integer/string Exit values. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0044.pp }
{$push}
{ Old file: tbs0050.pp }
{  can't set a function result in a nested procedure of a function OK 0.99.7 (PM) }

function tb0044_append : Boolean;

      procedure tb0044_doappend;
        begin
           tb0044_append := true;
        end;

begin
   tb0044_append:=False;
   tb0044_doappend;
end;
{$pop}

{ Case tb0103.pp }
{$push}
{ Old file: tbs0122.pp }
{ exit() gives a warning that the result is not set     OK 0.99.6 (FK) }


function tb0103_f:longint;
begin
  exit(1);
end;
{$pop}

{ Case tb0256.pp }
{$push}
{ Old file: tbs0296.pp }
{ exit(string) does not work (web form bugs 613)        OK 0.99.13 (PM) }


function tb0256_test : string;

  begin
    tb0256_test:='This should not be printed';
    exit('this should be printed');
  end;
{$pop}

{ Case tb0416.pp }
{$push}
function tb0416_f: string;

  procedure tb0416_t;
    begin
      tb0416_f := 'test';
    end;

begin
  tb0416_t;
end;
{$pop}

begin
  { Case tb0044.pp }
  {$push}
begin
  If not tb0044_append then
    begin
       Writeln('TBS0050 fails');
       Halt(1);
    end;
end;
  {$pop}

  { Case tb0103.pp }
  {$push}
begin
  writeln(tb0103_f);
end;
  {$pop}

  { Case tb0256.pp }
  {$push}
begin
  writeln(tb0256_test);
  if tb0256_test<>'this should be printed' then
    Halt(1);
end;
  {$pop}

  { Case tb0416.pp }
  {$push}
begin
  if tb0416_f <> 'test' then
    begin
      writeln('error!');
      halt(1);
    end;
end;
  {$pop}

end.
