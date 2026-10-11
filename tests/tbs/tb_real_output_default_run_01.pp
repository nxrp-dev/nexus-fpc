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

{ Case tw0810.pp }
{$push}
var tw0810_i:byte;
    tw0810_e:extended;
    tw0810_s:string;
{$pop}

{ Case tw1104.pp }
{$push}
var
  tw1104_r1,tw1104_r2 : extended;
  tw1104_code : integer;
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

  { Case tw0810.pp }
  {$push}
begin
tw0810_e:=103; (*1003,100003,1000003*)
for tw0810_i:=0 to 17 do
    begin
    str(tw0810_e:0:tw0810_i,tw0810_s);
    writeln(tw0810_s);
    end;

end;
  {$pop}

  { Case tw1104.pp }
  {$push}
begin
  val('.',tw1104_r1,tw1104_code);
  if tw1104_r1<>0.0 then
   writeln('error with val(".")');
  val('.E',tw1104_r2,tw1104_code);
  if tw1104_r2<>0.0 then
   writeln('error with val(".E")');
  if (tw1104_r1<>0.0) or (tw1104_r2<>0.0) then
   halt(1);
end;
  {$pop}

end.
