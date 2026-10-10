{ String concatenation, insertion, deletion and bounded short-string lengths. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0503.pp }
{$push}
procedure tb0503_testansi;
var
  s, q: ansistring;
begin
  s := 'hell';
  s := s+'o';
  q := '"';
  q := q+'''';
  s := s + q + s + 'abc';
  if (s <> 'hello"''helloabc') then
    halt(1);
  s := 'hell';
  s := s+'o';
  s := q+s+q;
  if (s <> '"''hello"''') then
    halt(2);
end;


procedure tb0503_testshort;
var
  s, q: shortstring;
begin
  s := 'hell';
  s := s+'o';
  q := '"';
  q := q+'''';
  s := s + q + s + 'abc';
  if (s <> 'hello"''helloabc') then
    halt(3);
  s := 'hell';
  s := s+'o';
  s := q+s+q;
  if (s <> '"''hello"''') then
    halt(4);
end;
{$pop}

{ Case tb0619.pp }
{$push}
var
  tb0619_ss: ShortString;
  tb0619_us: UnicodeString;
  tb0619_ws: WideString;
  tb0619_as: AnsiString;
  tb0619_i: LongInt;
{$pop}

{ Case tb0714.pp }
{$push}
var
  tb0714_s : string[20];
{$pop}

begin
  { Case tb0503.pp }
  {$push}
begin
  tb0503_testansi;
  tb0503_testshort;
end;
  {$pop}

  { Case tb0619.pp }
  {$push}
begin
  tb0619_ss := 'Test';
  Delete(tb0619_ss, 2, 1);
  if tb0619_ss <> 'Tst' then
    Halt(1);
  Insert('Foo', tb0619_ss, 2);
  if tb0619_ss <> 'TFoost' then
    Halt(2);

  tb0619_us := 'Test';
  Delete(tb0619_us, 2, 1);
  if tb0619_us <> 'Tst' then
    Halt(3);
  Insert('Foo', tb0619_us, 2);
  if tb0619_ss <> 'TFoost' then
    Halt(4);

  tb0619_ws := 'Test';
  Delete(tb0619_ws, 2, 1);
  if tb0619_ws <> 'Tst' then
    Halt(5);
  Insert('Foo', tb0619_ws, 2);
  if tb0619_ss <> 'TFoost' then
    Halt(6);

  tb0619_as := 'Test';
  Delete(tb0619_as, 2, 1);
  if tb0619_as <> 'Tst' then
    Halt(7);
  Insert('Foo', tb0619_as, 2);
  if tb0619_ss <> 'TFoost' then
    Halt(8);

  tb0619_ss := 'Test';
  Insert(#$41, tb0619_ss, 2);
  if tb0619_ss <> 'TAest' then
    Halt(9);
end;
  {$pop}

  { Case tb0714.pp }
  {$push}
begin
  setlength(tb0714_s,21);
  if length(tb0714_s)>sizeof(tb0714_s)-1 then
    halt(1);
end;
  {$pop}

end.
