{ Consolidated integers regressions; original case IDs and assertions are retained. }
{ %OPT=-O2 }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0607.pp }
{$push}


var
  tb0607_a,tb0607_b: longword;
  tb0607_i: int64;
  tb0607_l1, tb0607_l2: longword;

{$pop}

{ Case tw26534b.pp }
{$push}

// Opt.level: -O2
{$inline on}


procedure tw26534b_redirect( p: pointer );
begin
end;

procedure tw26534b_inlined( var R: byte ); inline;
begin
  tw26534b_redirect(@R);
end;

var
  tw26534b_a: byte;

{$pop}

{ Case tw34653.pp }
{$push}

var tw34653_d: LongInt;

{$pop}

{ Case tw40269.pp }
{$push}

var
	tw40269_a, tw40269_b: int32;
	tw40269_x, tw40269_y: byte;

{$pop}

{ Case tw9209.pp }
{$push}


procedure tw9209_Proc1(tw9209_i: integer);
begin
  if tw9209_i = 1 then
    Inc(tw9209_i);
end;

procedure tw9209_Proc2;
begin
  writeln('Test failed!');
  Halt(1);
end;

var
  tw9209_i, tw9209_j: integer;


{$pop}

begin

{ Case tb0607.pp }
{$push}

begin
  tb0607_a:=1;
  tb0607_b:=123456;
  tb0607_i:= (tb0607_a-tb0607_b) div 10;
  tb0607_l1:=longword(tb0607_i);
  tb0607_l2:=longword((tb0607_a-tb0607_b) div 10);
  writeln(tb0607_l1);
  writeln(tb0607_l2);
  if tb0607_l1<>tb0607_l2 then
    halt(1);
end;
{$pop}

{ Case tw26534b.pp }
{$push}
{$inline on}
begin
  tw26534b_inlined(tw26534b_a); // ie2006111510
end;
{$pop}

{ Case tw34653.pp }
{$push}

begin
    WriteLn;

    tw34653_d := 828;
    if ((tw34653_d mod 2) = 0) xor ((tw34653_d < 0) and ((tw34653_d mod 3) = 0)) then
      WriteLn('YES')
    else
      begin
        WriteLn('NO');
        halt(1);
      end;

    if ((tw34653_d mod 2) = 0) xor ((tw34653_d < 0) and ((tw34653_d mod 3) = 0)) then
        WriteLn('YES')
    else
      begin
        WriteLn('NO');
        halt(1);
      end;
end;
{$pop}

{ Case tw40269.pp }
{$push}

begin
	tw40269_x := PtrUint(@tw40269_a) mod 32;
	tw40269_y := PtrUint(@tw40269_b) mod 32;
	writeln(tw40269_x, ' ', tw40269_y);
end;
{$pop}

{ Case tw9209.pp }
{$push}

begin
  if (tw9209_i = 0) and (tw9209_j = 0) then
    tw9209_Proc1(tw9209_i)
  else
    tw9209_Proc2;
  writeln('Test OK.');
end;
{$pop}

end.
