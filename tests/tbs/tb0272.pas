{ %OPT=-Sen -vnw }
{ %RESULT=217 }

{ Old file: tbs0318.pas }

{$mode objfpc}
uses sysutils;

{ The exception is used in the raise statement, so no Note should be thrown }
var
  e  : exception;
begin
  e:=exception.create('test');
  raise e;
end.
