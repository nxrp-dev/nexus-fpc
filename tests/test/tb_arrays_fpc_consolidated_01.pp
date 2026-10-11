{ Consolidated arrays regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tarrconstr6.pp }
{$push}


type
  tarrconstr6_TLongIntArray = array of LongInt;

function tarrconstr6_Test(aArr: array of LongInt): Integer;
begin
  tarrconstr6_Test := 1;
end;

function tarrconstr6_Test(aArr: tarrconstr6_TLongIntArray): Integer;
begin
  tarrconstr6_Test := 2;
end;

var
  tarrconstr6_la: tarrconstr6_TLongIntArray;

{$pop}

{ Case tcmp.pp }
{$push}
const
  tcmp_err: boolean = false;

var
  tcmp_a, tcmp_b: array[0..512] of byte;

procedure tcmp_test_compare;
type
  pdword = ^cardinal;
var
  i, j, k: longint;
  l: longint;
begin
  for i := 0 to 512 do
    tcmp_a[i] := byte(i);
  for i := 0 to 256 do
    for j := 0 to 31 do
      for k := 0 to 31 do
        begin
          fillchar(tcmp_b,sizeof(tcmp_b),0);
          move(tcmp_a[j],tcmp_b[k+4],i);
          if comparebyte(tcmp_a[j],tcmp_b[k+4],i)<>0 then
            begin
              writeln('cmpbyte error 1 for (',i,',',j,',',k,')');
              halt(1);
            end;
          if comparebyte(tcmp_a[j],tcmp_b[k+4],i+1)<0 then
            begin
              writeln(tcmp_a[j+i],' ',tcmp_b[k+4+i]);
              writeln('cmpbyte error 2 for (',i,',',j,',',k,')');
              halt(2);
            end;
          if comparebyte(tcmp_b[k+4],tcmp_a[j],i+1)>0 then
            begin
              writeln(tcmp_b[k+4+i],' ',tcmp_a[j+i]);
              writeln('cmpbyte error 3 for (',i,',',j,',',k,')');
              halt(3);
            end;

          if (i and 1 = 0) then
            begin
              if compareword(tcmp_a[j],tcmp_b[k+4],i shr 1)<>0 then
                begin
                  writeln('cmpword error 4 for (',i,',',j,',',k,')');
                  halt(4);
                end;
              if compareword(tcmp_a[j],tcmp_b[k+4],i shr 1 + 1)<0 then
                begin
                  writeln('cmpword error 5 for (',i,',',j,',',k,')');
                  halt(5);
                end;
              if compareword(tcmp_b[k+4],tcmp_a[j],i shr 1 + 1)>0 then
                begin
                  writeln('cmpword error 6 for (',i,',',j,',',k,')');
                  halt(6);
                end;
            end
          else
            begin
              if compareword(tcmp_a[j],tcmp_b[k+4],(i+1) shr 1)<0 then
                begin
                  writeln('cmpword error 7 for (',i,',',j,',',k,')');
                  halt(7);
                end;
              if compareword(tcmp_b[k+4],tcmp_a[j],(i+1) shr 1)>0 then
                begin
                  writeln('cmpword error 8 for (',i,',',j,',',k,')');
                  halt(8);
                end;
            end;

          if (i and 3 = 0) then
            begin
              if comparedword(tcmp_a[j],tcmp_b[k+4],i shr 2)<>0 then
                begin
                  writeln('cmpdword error 9 for (',i,',',j,',',k,')');
                  halt(9);
                end;
              if comparedword(tcmp_a[j],tcmp_b[k+4],i shr 2 + 1)<=0 then
                begin
                  writeln(comparedword(tcmp_a[j],tcmp_b[k+4],i shr 2+1));
                  writeln(unaligned(pdword(@tcmp_a[j])^),' ',unaligned(pdword(@tcmp_b[k+4])^));
                  writeln(unaligned(pdword(@tcmp_a[j+i])^),' ',unaligned(pdword(@tcmp_b[k+4+i])^));
                  writeln(unaligned(pdword(@tcmp_a[j+i+4])^),' ',unaligned(pdword(@tcmp_b[k+4+i+4])^));
                  writeln('cmpdword error 10 for (',i,',',j,',',k,')');
                  halt(10);
                end;
              if comparedword(tcmp_b[k+4],tcmp_a[j],i shr 2 + 1)>=0 then
                begin
                  writeln(comparedword(tcmp_b[k+4],tcmp_a[j],i shr 2+1));
                  writeln(unaligned(pdword(@tcmp_b[k+4])^),' ',unaligned(pdword(@tcmp_a[j])^));
                  writeln(unaligned(pdword(@tcmp_b[k+4+i])^),' ',unaligned(pdword(@tcmp_a[j+i])^));
                  writeln(unaligned(pdword(@tcmp_b[k+4+i+4])^),' ',unaligned(pdword(@tcmp_a[j+i+4])^));
                  writeln('cmpdword error 11 for (',i,',',j,',',k,')');
                  halt(11);
                end;
            end
          else
            begin
              if comparedword(tcmp_a[j],tcmp_b[k+4],(i+3) shr 2)<0 then
                begin
                  writeln(comparedword(tcmp_a[j],tcmp_b[k+4],(i+3) shr 2));
                  writeln(unaligned(pdword(@tcmp_a[j])^),' ',unaligned(pdword(@tcmp_b[k+4])^));
                  writeln(unaligned(pdword(@tcmp_a[j+(i+3) shr 2-1])^),' ',unaligned(pdword(@tcmp_b[k+4+(i+3) shr 2-1])^));
                  writeln('cmpdword error 12 for (',i,',',j,',',k,')');
                  halt(12);
                end;
              if comparedword(tcmp_b[k+4],tcmp_a[j],(i+3) shr 2)>0 then
                begin
                  writeln(comparedword(tcmp_b[k+4],tcmp_a[j],(i+3) shr 2));
                  writeln(unaligned(pdword(@tcmp_b[k+4])^),' ',unaligned(pdword(@tcmp_a[j])^));
                  writeln(unaligned(pdword(@tcmp_b[k+4+(i+3) shr 2-1])^),' ',unaligned(pdword(@tcmp_a[j+(i+3) shr 2-1])^));
                  writeln('cmpdword error 13 for (',i,',',j,',',k,')');
                  halt(13);
                end;
            end;
        end;
end;



{$pop}

{ Case tfillchr.pp }
{$push}
const
  tfillchr_err: boolean = false;

var
  tfillchr_a: array[0..512] of byte;

procedure tfillchr_test_fillchar;
var
  i, j: longint;
  k: byte;
  l: longint;
begin
  for i := 0 to 512 do
    begin
      tfillchr_a[i] := 255;
    end;
  { lengths }
  for i := 0 to 256 do
    { alignments }
    for j := 0 to 31 do
      { values }
      for k := 0 to 1 do
        begin
          fillchar(tfillchr_a[j+4],i,k);
          { check whether we didn't write a byte too early }
          for l := 0 to j+3 do
            begin
              if tfillchr_a[l] <> 255 then
                begin
                  writeln('Fillchar test error 1');
                  tfillchr_err := true;
                  halt(1);
                end;
              tfillchr_a[l] := 255;
            end;
          { check whether the actual values were written correctly }
          for l := j+4 to j+i+3 do
            begin
              if tfillchr_a[l] <> k then
                begin
                  writeln('Fillchar test error 2');
                  tfillchr_err := true;
                  halt(1);
                end;
              tfillchr_a[l] := 255;
            end;
          { check whether we didn't write past the end }
          for l := j+i+4 to 512 do
            begin
              if tfillchr_a[l] <> 255 then
                begin
                  writeln('Fillchar test error 3');
                  tfillchr_err := true;
                  halt(1);
                end;
              tfillchr_a[l] := 255;
            end;
        end;
end;


{$pop}

{ Case tparray11.pp }
{$push}
{$bitpacking on}

{ from gpc testsuite (sam7.pas) }



Var
  tparray11_foo: array [ 'a'..'f' ] of Boolean = ( false, false, true, false, false, false );
  tparray11_bar: packed array [ 42..47 ] of Boolean;
  tparray11_baz: array [ '0'..'5' ] of Boolean;
  tparray11_i: Integer;


{$pop}

{ Case tparray16.pp }
{$push}
{ from gpc tests, original name pack4.pas }

{$ifdef fpc}
{$bitpacking on}
{$endif fpc}



Var
  tparray16_foo: array [ 1..7 ] of Boolean;
  tparray16_bar: packed array [ 1..3 ] of Boolean;
  tparray16_i: Integer;
  tparray16_temp: Boolean;


{$pop}

begin

{ Case tarrconstr6.pp }
{$push}

begin
  tarrconstr6_la := Nil;
  if tarrconstr6_Test([]) <> 1 then
    Halt(1);
  if tarrconstr6_Test([1, 2, 3]) <> 1 then
    Halt(2);
  if tarrconstr6_Test(tarrconstr6_TLongIntArray.Create(1, 2, 3)) <> 2 then
    Halt(3);
  if tarrconstr6_Test(tarrconstr6_la) <> 2 then
    Halt(4);
end;
{$pop}

{ Case tcmp.pp }
{$push}

begin
  tcmp_test_compare;
end;
{$pop}

{ Case tfillchr.pp }
{$push}

begin
  tfillchr_test_fillchar;
  if tfillchr_err then
    halt(1);
end;
{$pop}

{ Case tparray11.pp }
{$push}
{$bitpacking on}
begin
  pack ( tparray11_foo, 'a', tparray11_bar );
  unpack ( tparray11_bar, tparray11_baz, '0' );
  for tparray11_i:= 0 to 5 do
    if tparray11_bar [ 42 + tparray11_i ] <> tparray11_baz [ chr ( ord('0')+ tparray11_i ) ] then
      tparray11_foo [ 'c' ]:= false;
  if tparray11_foo [ 'c' ] and tparray11_bar [ 44 ] then
    writeln ( 'OK' )
  else
    begin
      writeln ( 'failed ', tparray11_foo [ 'c' ], ' ', tparray11_bar [ 44 ] );
      halt(1);
    end;
end;
{$pop}

{ Case tparray16.pp }
{$push}
{$ifdef fpc}
{$bitpacking on}
{$endif fpc}
begin
  for tparray16_i:= 1 to 3 do
    tparray16_bar [ tparray16_i ]:= true;
  for tparray16_i:= 1 to 7 do
    tparray16_foo [ tparray16_i ]:= false;
  tparray16_foo [ 4 ]:= true;
  tparray16_foo [ 5 ]:= true;
  pack ( tparray16_foo, 3, tparray16_bar );
  if tparray16_bar [ 3 ] and tparray16_bar [ 2 ] and not tparray16_bar [ 1 ] then
    begin
      for tparray16_i:= 1 to 3 do
        begin
          tparray16_temp:= not tparray16_bar [ tparray16_i ];
          tparray16_bar [ tparray16_i ]:= tparray16_temp;
        end { for };
      unpack ( tparray16_bar, tparray16_foo, 5 );
      if not tparray16_foo [ 1 ] and not tparray16_foo [ 2 ] and not tparray16_foo [ 3 ] and tparray16_foo [ 4 ]
         and tparray16_foo [ 5 ] and not tparray16_foo [ 6 ] and not tparray16_foo [ 7 ] then
        writeln ( 'OK' )
      else
        begin
          write ( 'failed: foo =' );
          for tparray16_i:= 1 to 7 do
            write ( ' ', tparray16_foo [ tparray16_i ] );
          writeln;
          halt(1);
        end { else };
    end { if }
  else
    begin
      write ( 'failed: bar =' );
      for tparray16_i:= 1 to 3 do
        write ( ' ', tparray16_bar [ tparray16_i ] );
      writeln;
      halt(1);
    end { else };
end;
{$pop}

end.
