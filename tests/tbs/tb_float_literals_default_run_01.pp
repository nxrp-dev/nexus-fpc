{ Floating-point formatting, fractional parts, rounding and scientific literals. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0054.pp }
{$push}
{ Old file: tbs0061.pp }
{  shows wrong errors when compiling (NOT A bugs)        OK 0.99.1 }

var
   tb0054_r : double;
   tb0054_s : string;
{$pop}

{ Case tb0058.pp }
{$push}
{ Old file: tbs0065.pp }
{  shows that frac() doesn't work correctly.            OK 0.99.1 (PFV) }

{ Program to demonstrate the Frac function. }

Var tb0058_r : Real;
{$pop}

{ Case tb0059.pp }
{$push}
{ Old file: tbs0066.pp }
{  shows that Round doesn't work correctly. (NOT A bugs) OK 0.99.1 }

{ Program to demonstrate the Round function. }
{$pop}

{ Case tb0566.pp }
{$push}
var
 tb0566_d1,tb0566_d2,tb0566_d3 : extended;
 tb0566_err: longint;
{$pop}

begin
  { Case tb0054.pp }
  {$push}
begin
   tb0054_r:=1234.0;
   str(tb0054_r,tb0054_s);
end;
  {$pop}

  { Case tb0058.pp }
  {$push}
begin
  Writeln (Frac (123.456):0:3);  { Prints  O.456 }
  Writeln (Frac (-123.456):0:3); { Prints -O.456 }
end;
  {$pop}

  { Case tb0059.pp }
  {$push}
begin
  Writeln (Round(123.456));  { Prints 124  }
  Writeln (Round(-123.456)); { Prints -124 }
  Writeln (Round(12.3456));  { Prints 12   }
  Writeln (Round(-12.3456)); { Prints -12  }
end;
  {$pop}

  { Case tb0566.pp }
  {$push}
begin
 tb0566_d1:=105;
 tb0566_d2:=1.05e2;
 if (tb0566_d1<>tb0566_d2) then
   halt(1);
end;
  {$pop}

end.
