{ %FAIL }
{ Old file: tbf0347.pas }
{  }

{$mode delphi}

type x = ^longint;

var y:x;

begin
 y [5]:=5;
end.
