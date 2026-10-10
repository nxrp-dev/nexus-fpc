{ Floating-point Write formatting and Comp output. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0096.pp }
{$push}
{ Old file: tbs0114.pp }
{ writeln problem (by Pavel Ozerski)                    OK 0.99.1 (PFV) }
{$pop}

{ Case tb0097.pp }
{$push}
{ Old file: tbs0115.pp }
{ missing writeln for comp data type                    OK 0.99.6 (FK) }

var
   tb0097_c : comp;
{$pop}

{ Case tb0134.pp }
{$push}
{ Old file: tbs0157.pp }
{ Invalid compilation and also crashes                  OK 0.99.7 (PFV) }

{ this should be rejected because we only accept integer args }

var tb0134_x,tb0134_y:real;
{$pop}

begin
  { Case tb0096.pp }
  {$push}
begin
 write{ln}(0.997:0:2);
end;
  {$pop}

  { Case tb0097.pp }
  {$push}
begin
   tb0097_c:=1234;
   writeln(tb0097_c);
   {readln(c);}
   tb0097_c:=-258674;
   writeln(tb0097_c);
end;
  {$pop}

  { Case tb0134.pp }
  {$push}
begin
tb0134_x:=5.6;
tb0134_y:=45.789;
write(tb0134_y:2:3,tb0134_x:3:4);
{write(y:3.2,x:5.2);}
end;
  {$pop}

end.
