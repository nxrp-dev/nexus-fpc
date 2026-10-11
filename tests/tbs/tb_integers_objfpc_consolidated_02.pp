{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses sysutils;

{ Case tb0713.pp }
{$push}


{$Q+}



{$pop}

{ Case tb_integer_checks_objfpc_consolidated_01.pp }
{$push}
{ Consolidated integer checks regressions; original case IDs and assertions are retained. }




{ Case tb0162.pp }
{$push}
{ Old file: tbs0193.pp }
{ overflow checking for 8 and 16 bit operations wrong }





var
  tb0162_has_errors: boolean;

procedure tb0162_doerror(tb0162_l: longint);
begin
  writeln('error near ',tb0162_l);
  tb0162_has_errors:=true;
end;

{$R-}
{$Q+}
var tb0162_i: integer;
    tb0162_b: byte;
    tb0162_l: longint;
    tb0162_c: cardinal;
    tb0162_n: int64;
    tb0162_q: qword;

{$pop}

{ Case tw22744.pp }
{$push}
{ Original test is about $Q option only,
  so we explicitly disabled $R,
  adding a new tw22744b.pp }

{$R-}




var
  tw22744_i,tw22744_j,tw22744_l : longint;
const
  tw22744_exception_seen : boolean = false;


{$pop}

{ Case tw22744b.pp }
{$push}
{ The original test is about $Q option only,
  ifor which we explicitly disabled $R.
  Here use both $Q and $R,
  as 64-bit CPU rather generate range check errors
  on that code. }




var
  tw22744b_i,tw22744b_j,tw22744b_l : longint;
const
  tw22744b_exception_seen : boolean = false;


{$pop}


{$pop}

{ Case tw15438.pp }
{$push}






function tw15438_InlineSwapEndian(const AValue: QWord): QWord;inline;
  begin
    result := (qword(SwapEndian(lo(avalue))) shl 32) or SwapEndian(hi(avalue));
  end;

var
    tw15438_q : QWord;

procedure tw15438_Check;
begin
    tw15438_q := $0102030405060708;
    tw15438_q := tw15438_InlineSwapEndian(tw15438_q);
end;


{$pop}

{ Case tw3534.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3534 }
{ Submitted by "Mattias Gaertner" on  2005-01-08 }
{ e-mail: mattias@freepascal.org }


{$H+}



var
  tw3534_i: SmallInt;

{$pop}

{ Case tw7104.pp }
{$push}


{$H+}



function tw7104_count: integer;
begin
  result := 5;
end;

var
  tw7104_i: Integer;


{$pop}

begin

{ Case tb0713.pp }
{$push}

{$Q+}
begin
  writeln(Int64.MinValue+Int64(Random(0)));
end;
{$pop}

{ Case tb_integer_checks_objfpc_consolidated_01.pp }
{$push}

{$push}
{$R-}
{$Q+}
{$pop}
{$push}
{$R-}
{$pop}
{$push}
{$pop}
begin

{ Case tb0162.pp }
{$push}

{$R-}
{$Q+}
begin
  tb0162_has_errors:=false;
  tb0162_i := 32767;
  tb0162_i := tb0162_i + 15;
  tb0162_b := 255;
  tb0162_b := tb0162_b + 18;
  tb0162_b := 255;
  tb0162_b := tb0162_b * 8;
  tb0162_b := 255;
  tb0162_b := tb0162_b * 17;

{ 64 bit cpus do all calculations in 64 bit so longint and cardinal can't overflow }
{$ifndef CPU64}
  tb0162_l := high(longint);
  try
    tb0162_l := tb0162_l+1;
    tb0162_doerror(1);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(2);
  end;

  tb0162_l := low(longint);
  try
    tb0162_l := tb0162_l-1;
    tb0162_doerror(3);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(4);
  end;

  tb0162_l := low(longint);
  try
    tb0162_l := tb0162_l*2;
    tb0162_doerror(5);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(6);
  end;

  tb0162_l := high(longint) div 2;
  try
    tb0162_l := tb0162_l*3;
    tb0162_doerror(7);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(8);
  end;

  tb0162_l := low(longint);
  try
    tb0162_l := tb0162_l div -1;
    tb0162_doerror(9);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(10);
  end;

  tb0162_l := low(longint);
  try
    tb0162_l := -tb0162_l;
    tb0162_doerror(109);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(110);
  end;

  tb0162_c := high(cardinal);
  try
    tb0162_c := tb0162_c+1;
    tb0162_doerror(11);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(12);
  end;

  tb0162_c := high(cardinal) div 2;
  try
    tb0162_c := tb0162_c*3;
    tb0162_doerror(13);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(14);
  end;

  tb0162_c := high(cardinal);
  try
    tb0162_c := tb0162_c*high(cardinal);
    tb0162_doerror(15);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(16);
  end;

{$endif CPU64}

{$ifdef fpc}

  tb0162_n := high(int64);
  try
    tb0162_n := tb0162_n+1;
    tb0162_doerror(17);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(18);
  end;

  tb0162_n := low(int64);
  try
    tb0162_n := tb0162_n-1;
    tb0162_doerror(19);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(20);
  end;

  tb0162_n := 0;
  try
    tb0162_n := tb0162_n-1;
  except
    on eintoverflow do
      tb0162_doerror(39);
  end;


  tb0162_n := low(int64);
  try
    tb0162_n := tb0162_n*2;
    tb0162_doerror(21);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(22);
  end;

  tb0162_n := high(int64) div 2;
  try
    tb0162_n := tb0162_n*3;
    tb0162_doerror(23);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(24);
  end;


  tb0162_q := 0;
  try
    tb0162_q := tb0162_q-1;
    tb0162_doerror(25);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(26);
  end;


  tb0162_q := qword(high(qword));
  try
    tb0162_q := tb0162_q+1;
    tb0162_doerror(27);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(28);
  end;

  tb0162_q := qword(high(qword)) div qword(2);
  try
    tb0162_q := tb0162_q*qword(3);
    tb0162_doerror(29);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(30);
  end;

  tb0162_q := high(qword);
  try
    tb0162_q := tb0162_q*high(qword);
    tb0162_doerror(31);
  except
    on eintoverflow do
      ;
    else
      tb0162_doerror(32);
  end;

{$endif fpc}
  if tb0162_has_errors then
    halt(1);
End;
{$pop}

{ Case tw22744.pp }
{$push}
{$R-}

begin
  {$Q+}
  tw22744_i:=$78000000;
  tw22744_j:=$20000000;
  tw22744_l:=tw22744_i-tw22744_j;
  {$push} {$q-}
  tw22744_l:=tw22744_i+tw22744_j; {$pop}
  try
  {$push} {$q-}
  tw22744_l:=tw22744_i+tw22744_j{$pop};
  except on E : Exception do
    begin
      writeln('Simple {$Pop} exception ',E.Message);
      tw22744_exception_seen:=true;
    end;
  end;
  try
  {$q-} {$push}
  tw22744_l:=tw22744_i+tw22744_j{$q+}{$push};
  tw22744_l:=0;
  {$pop}
  {$pop}
  except on E : Exception do
    begin
      writeln('Convoluted {$Q+}{$Push} Exception ',E.Message);
      tw22744_exception_seen:=true;
    end;
  end;
  if tw22744_exception_seen then
    begin
      writeln('This test failed');
      halt(1);
    end;
end;
{$pop}

{ Case tw22744b.pp }
{$push}

begin
  {$Q+,R+}
  tw22744b_i:=$78000000;
  tw22744b_j:=$20000000;
  tw22744b_l:=tw22744b_i-tw22744b_j;
  {$push} {$q-,r-}
  tw22744b_l:=tw22744b_i+tw22744b_j; {$pop}
  try
  {$push} {$q-,r-}
  tw22744b_l:=tw22744b_i+tw22744b_j{$pop};
  except on E : Exception do
    begin
      writeln('Simple {$Pop} exception ',E.Message);
      tw22744b_exception_seen:=true;
    end;
  end;
  try
  {$q-,r-} {$push}
  tw22744b_l:=tw22744b_i+tw22744b_j{$q+,r+}{$push};
  tw22744b_l:=0;
  {$pop}
  {$pop}
  except on E : Exception do
    begin
      writeln('Convoluted {$Q+,R+}{$Push} Exception ',E.Message);
      tw22744b_exception_seen:=true;
    end;
  end;
  if tw22744b_exception_seen then
    begin
      writeln('This test failed');
      halt(1);
    end;
end;
{$pop}

end;
{$pop}

{ Case tw15438.pp }
{$push}

begin
    tw15438_q:=0;
    tw15438_Check;
    if tw15438_q <> $0807060504030201 then begin
        writeln(format('failed Swap - expected $0807060504030201, got %x',[tw15438_q]));
        halt(1);
    end;
end;
{$pop}

{ Case tw3534.pp }
{$push}

{$H+}
begin
  tw3534_i:=-3;
  writeln(IntToStr(tw3534_i));
  if IntToStr(tw3534_i)<>'-3' then
    halt(1);
end;
{$pop}

{ Case tw7104.pp }
{$push}

{$H+}
begin
  for tw7104_i := 0 to tw7104_count-1 do begin
    writeln(tw7104_i);
    if FileExists('asdkjasdjalsj') then;

    if tw7104_i>5 then halt(1);
  end;
end;
{$pop}

end.
