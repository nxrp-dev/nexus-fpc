{ Integer conversions, alignment expressions and comparisons with range checking enabled. }
{ Original case IDs and variable scopes are retained below. }

{$R+}

{ Case tb0085.pp }
{$push}
{ Old file: tbs0099.pp }
{ wrong assembler code is genereatoed for range check   OK 0.99.1 (?) }


{$R+}
var tb0085_w:word;
    tb0085_s:Shortint;
{$pop}

{ Case tb0102.pp }
{$push}
{ Old file: tbs0121.pp }
{ cardinal -> byte conversion not work (and crashes)    OK 0.99.6 (FK) }

{$R+}
var

  tb0102_c : cardinal;
  tb0102_i : integer;
  tb0102_w : word;
  tb0102_b : byte;
  tb0102_si : shortint;
{$pop}

{ Case tb0343.pp }
{$push}
{$R+}
var
 tb0343_i : int64;
{$pop}

{ Case tb0362.pp }
{$push}
{$R+}

type
  tb0362_size_t = Cardinal;

function tb0362_cmsg_align(len: tb0362_size_t): tb0362_size_t;
begin
  tb0362_cmsg_align := (len + SizeOf(tb0362_size_t) - 1) and (not (SizeOf(tb0362_size_t) - 1));
end;
{$pop}

{ Case tb0447.pp }
{$push}
{$R+}
var
  tb0447_a : cardinal;
  tb0447_b : longint;
{$pop}

{ Case tb0533.pp }
{$push}
{$r+}

const
  tb0533_q: qword = 18446744073709551615;

var
  tb0533_i: int64;
  tb0533_code: longint;
{$pop}

{ Case tb0344.pp }
{$push}
{$R+}
var
  tb0344_s : string;
  tb0344_error : boolean;
{$pop}

{ Case tb0574.pp }
{$push}
{$r+}
{$q+}
var
  tb0574_i1,tb0574_i2 : int64;
{$pop}

{ Case tb0658.pp }
{$push}
{$r+,q+}

procedure tb0658_test(tb0658_i: int64);
begin
  if (tb0658_i>0) and (tb0658_i<$1fff) then
    halt(1);
end;
{$pop}

begin
  { Case tb0085.pp }
  {$push}
begin
  tb0085_w := tb0085_s;
end;
  {$pop}

  { Case tb0102.pp }
  {$push}
begin
  tb0102_w:=tb0102_c;
  tb0102_i:=tb0102_c;
  tb0102_b:=tb0102_c;
  tb0102_b:=tb0102_si;
end;
  {$pop}

  { Case tb0343.pp }
  {$push}
begin
  tb0343_i:=high(cardinal);
end;
  {$pop}

  { Case tb0362.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0447.pp }
  {$push}
begin
  tb0447_a := 0;
  tb0447_b := -1;
  if tb0447_a > tb0447_b then
    writeln ('OK')
  else
    halt(1);
end;
  {$pop}

  { Case tb0533.pp }
  {$push}
{$R+}
begin
  val('18446744073709551615',tb0533_i,tb0533_code);
  if (tb0533_code = 0) then
    halt(1);
  val('-9223372036854775808',tb0533_i,tb0533_code);
  if (tb0533_code <> 0) or
     (tb0533_i <> low(int64)) then
    halt(2);
  val('9223372036854775807',tb0533_i,tb0533_code);
  if (tb0533_code <> 0) or
     (tb0533_i <> high(int64)) then
    halt(3);
  val('$8000000000000000',tb0533_i,tb0533_code);
  if (tb0533_code <> 0) or
     (tb0533_i <> low(int64)) then
    halt(4);
end;
  {$pop}

  { Case tb0344.pp }
  {$push}
{$R+}
begin
  tb0344_error:=false;
  str(high(int64),tb0344_s);
  if tb0344_s<>'9223372036854775807' then
   begin
     writeln('high(int64) error!: "',tb0344_s,'"');
     tb0344_error:=true;
   end;
  str(low(int64),tb0344_s);
  if tb0344_s<>'-9223372036854775808' then
   begin
     writeln('low(int64) error!: "',tb0344_s,'"');
     tb0344_error:=true;
   end;
{$ifdef fpc}
  str(high(qword),tb0344_s);
  if tb0344_s<>'18446744073709551615' then
   begin
     writeln('high(qword) error!: "',tb0344_s,'"');
     tb0344_error:=true;
   end;
  str(low(qword),tb0344_s);
  if tb0344_s<>'0' then
   begin
     writeln('low(qword) error!: "',tb0344_s,'"');
     tb0344_error:=true;
   end;
{$endif}
  if tb0344_error then
   halt(1);
end;
  {$pop}

  { Case tb0574.pp }
  {$push}
{$R+,Q+}
begin
  tb0574_i1:=$100000000;
  tb0574_i2:=$800000000;
  inc(tb0574_i1,tb0574_i2);
  if tb0574_i1<>$900000000 then
    halt(1);
  writeln('ok');
end;
  {$pop}

  { Case tb0658.pp }
  {$push}
{$R+,Q+}
begin
  tb0658_test(0);
end;
  {$pop}

end.
