{ Nested recursion and local routine names within overloaded parents. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0014.pp }
{$push}
{ Old file: tbs0017.pp }
{  }

const
      tb0014_nextoptpass : longint = 0;
  procedure tb0014_init;

    const
       tb0014_endofparas : boolean = false;

    procedure tb0014_getparastring;

      procedure tb0014_nextopt;

        begin
           tb0014_endofparas:=true;
           tb0014_getparastring;
           inc(tb0014_nextoptpass);
           tb0014_init;
        end;

      begin
       if not tb0014_endofparas then
         tb0014_nextopt;
      end;

    begin
         tb0014_getparastring;
    end;
{$pop}

{ Case tb0314.pp }
{$push}
{ this program shows a possible problem
  of name mangling in FPC  (PM) }
  procedure tb0314_test;

    function tb0314_a : longint;
      begin
         tb0314_a:=1;
      end;

    begin
       writeln('a = ',tb0314_a);
    end;

  procedure tb0314_test(tb0314_b : byte);

    function tb0314_a : longint;
      begin
         tb0314_a:=2;
      end;

    begin
       writeln('b = ',tb0314_b);
       writeln('a = ',tb0314_a);
    end;

  type tb0314_a = word;

  function tb0314_test_(tb0314_b : tb0314_a) : longint;
    begin
      tb0314_test_:=tb0314_b;
    end;
{$pop}

begin
  { Case tb0014.pp }
  {$push}
begin
   tb0014_init;
   if tb0014_nextoptpass<>1 then Halt(1);
end;
  {$pop}

  { Case tb0314.pp }
  {$push}
begin
   tb0314_test(1);
   tb0314_test;
   tb0314_test(4);
end;
  {$pop}

end.
