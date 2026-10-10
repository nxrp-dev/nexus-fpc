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

end.
