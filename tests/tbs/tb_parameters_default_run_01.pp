{ Ordinal arguments, forward overloads, string parameters and untyped constants. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0010.pp }
{$push}
{ Old file: tbs0013.pp }
{  }

procedure tb0010_test(w : word);

  begin
  end;
{$pop}

{ Case tb0214.pp }
{$push}
{ Old file: tbs0253.pp }
{ problem with overloaded procedures and forward       OK 0.99.11 (PFV) }

procedure tb0214_test(w : word);forward;

procedure tb0214_test(a : string);
begin
   Writeln(a);
   tb0214_test(20);
end;

procedure tb0214_test(w :word);
begin
   writeln(w);
end;
{$pop}

{ Case tb0232.pp }
{$push}
{ Old file: tbs0272.pp }
{ No error issued if wrong parameter in function inside a second function OK 0.99.13 (PFV) }

function tb0232_astring(tb0232_s :string) : string;

begin
  tb0232_astring:='Test string'+tb0232_s;
end;

procedure tb0232_testvar(var tb0232_s : string);
begin
  writeln('testvar s is "',tb0232_s,'"');
end;

procedure tb0232_testconst(const tb0232_s : string);
begin
  writeln('testconst s is "',tb0232_s,'"');
end;

procedure tb0232_testvalue(tb0232_s : string);
begin
  writeln('testvalue s is "',tb0232_s,'"');
end;

const
  tb0232_s : string = 'test';
  tb0232_conststr = 'Const test';
{$pop}

{ Case tb0476.pp }
{$push}
const
  tb0476_e = 'as';

procedure tb0476_p(const tb0476_p);
  begin
    if pchar(@tb0476_p)^<>'a' then
      begin
        writeln('error');
        halt(1);
      end;
  end;
{$pop}

{ Case tb0470.pp }
{$push}
procedure tb0470_proc1(p1,p2,p3,p4,p5,p6,p7,p8,p9,p10,p11,p12,p13,p14,p15,p16,p17,p18,p19,p20 : longint);
  begin
  end;

procedure tb0470_proc2;
  var
    tb0470_l : dword;
  begin
    tb0470_l:=$deadbeef;
    tb0470_proc1(1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20);
    if tb0470_l<>$deadbeef then
      begin
        writeln('error');
        halt(1);
      end;
  end;
{$pop}

begin
  { Case tb0010.pp }
  {$push}
begin
   tb0010_test(1234);
end;
  {$pop}

  { Case tb0214.pp }
  {$push}
begin
  tb0214_test('test');
  tb0214_test(32);
end;
  {$pop}

  { Case tb0232.pp }
  {$push}
begin
  tb0232_testvalue(tb0232_astring('e'));
  tb0232_testconst(tb0232_astring(tb0232_s));
  tb0232_testconst(tb0232_conststr);
end;
  {$pop}

  { Case tb0476.pp }
  {$push}
begin
  tb0476_p(tb0476_e[1]);
end;
  {$pop}

  { Case tb0470.pp }
  {$push}
begin
  tb0470_proc2;
end;
  {$pop}

end.
