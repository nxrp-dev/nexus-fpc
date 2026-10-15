{ Constant conditions and byte loop counters with ErrorU failure reporting. }
{ Original case IDs and variable scopes are retained below. }

uses erroru;

{ Case tb0004.pas }
{$push}
{ Old file: tbs0005.pas }
{  tests the if 1=1 then ... bugs                       OK 0.9.2 }
{$pop}

{ Case tb0006.pas }
{$push}
{ Old file: tbs0007.pas }
{  tests the infinity loop when using byte counter     OK 0.9.2 }

var
   tb0006_count : byte;
   tb0006_test : longint;
{$pop}

begin
  { Case tb0004.pas }
  {$push}
begin
  if 1=1 then
    begin
      Writeln('OK');
    end;
  if 1<>1 then
    begin
      Error;
    end;
end;
  {$pop}

  { Case tb0006.pas }
  {$push}
begin
   tb0006_test:=0;
   for tb0006_count:=1 to 127 do
     begin
        inc(tb0006_test);
        writeln(tb0006_count,'. loop');
        if tb0006_test>127 then
          Error;
     end;
end;
  {$pop}

end.
