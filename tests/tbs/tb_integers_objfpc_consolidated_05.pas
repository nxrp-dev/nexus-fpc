{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses sysutils;

{ Case tw30948.pas }
{$push}





{ Explicitly disable range and overflow checking }
{$R-}
{$Q-}

procedure tw30948_Add64x2(HA,LA,HB,LB: QWord; out HR,LR: QWord); inline;
begin
  Inc(LA,LB);
  LR := LA;
  HR := HA + HB + Ord(LA < LB);
end;

procedure tw30948_test;
  var XHA, XLA, XLB, HA1, LA1, LB1, HA2, LA2, LB2 : QWord;
begin
  XHA := QWord((Random($100000000) shl 32) or Random($100000000));
  XLA := QWord((Random($100000000) shl 32) or Random($100000000));
  XLB := QWord((Random($100000000) shl 32) or Random($100000000));

  // the bug appears only when the sum "XLA + XLB" produces a carry
  XLA := XLA or QWord($8000000000000000);
  XLB := XLB or QWord($8000000000000000);

  HA1 := XHA;
  LA1 := XLA;
  LB1 := XLB;
  tw30948_Add64x2(HA1,LA1,0,LB1,HA1,LA1);
  Writeln('LA1:HA1 = $' + IntToHex(LA1,16) + ':$' + IntToHex(HA1,16)); // OK

  HA2 := XHA;
  LA2 := XLA;
  LB2 := XLB;
  tw30948_Add64x2(HA2,LB2,0,LA2,HA2,LA2);
  Writeln('LA2:HA2 = $' + IntToHex(LA2,16) + ':$' + IntToHex(HA2,16)); // wrong

  if HA1 <> HA2 then
    begin
      Writeln('HA1 and HA2 are not equal!');
      halt(1);
    end;
end;


{$pop}

{ Case ttryfin5.pas }
{$push}



var
  ttryfin5_counter: integer;

{ flow control statements in try..except must not bypass finally code of outer try..finally }
{ test 1: 'exit' in 'try' block }
procedure ttryfin5_test;
 begin
   try
     try
       inc(ttryfin5_counter);
       exit;
     except
     end;
   finally
     inc(ttryfin5_counter);
   end;
 end;

{ test 2: 'exit' in 'except' block }
procedure ttryfin5_test2;
begin
  try
    try
      raise exception.create('catch me');
    except
      inc(ttryfin5_counter);
      exit;
    end;
  finally
    inc(ttryfin5_counter);
  end;
end;

{ test 3: 'exit' in 'on' statement }
procedure ttryfin5_test3;
begin
  try
    try
      raise exception.create('catch me');
    except
      on E: Exception do
      begin
        inc(ttryfin5_counter);
        exit;
      end;
    end;
  finally
    inc(ttryfin5_counter);
  end;
end;

{ test 4: 'continue' in try..except nested in loop nested in try..finally
           in this case the control stays within protected region
           (Mantis #28584)  }
procedure ttryfin5_test4;
var
  i: integer;
begin
  try
    for i:=0 to 2 do
    begin
      try
        inc(ttryfin5_counter);
        raise exception.create('catch me');
      except
        continue;
      end;
    end;
  finally
    inc(ttryfin5_counter);
  end;
end;

{ test 5: same as above but with 'break' statement instead }
procedure ttryfin5_test5;
var
  i: integer;
begin
  try
    for i:=0 to 15 do
    begin
      try
        inc(ttryfin5_counter);
        raise exception.create('catch me');
      except
        if i=2 then
          break;
      end;
    end;
    inc(ttryfin5_counter);
  finally
    inc(ttryfin5_counter);
  end;
end;




{$pop}

{ Case tinline8.pas }
{$push}
{$ifdef fpc}

{$inline on}
{$endif}



var tinline8_a: longint;

function tinline8_f(l: longint): longint; inline;
var
  l1,l2,l3: longint;
begin
  result:=123456;
  if (l > 10) then
    exit;
  result:=30;
  for l1 := 1 to 10 do
    for l2 := 1 to 100 do
  ;
  result := 40;
  for l3 := 1 to 10 do;
end;


procedure tinline8_test;
var
  l: longint;
begin
  l:= tinline8_f(tinline8_a);
  if (l<>123456) then
    halt(1);
end;


procedure tinline8_test2;
var
  l: longint;
begin
  try
  finally
    l:= tinline8_f(tinline8_a);
    if (l<>123456) then
      halt(1);
  end;
end;


procedure tinline8_inl2; inline;
begin
  try
  except on exception do ;
  end
end;



{$pop}

{ Case trange2.pas }
{$push}


{$r+}

var
  trange2_l: longint;
  trange2_c: cardinal;
  trange2_n: longint;

{$pop}

begin

{ Case tw30948.pas }
{$push}

{$R-}
{$Q-}
begin
  tw30948_test;
end;
{$pop}

{ Case ttryfin5.pas }
{$push}

begin
  ttryfin5_counter:=0;
  ttryfin5_test;
  if ttryfin5_counter<>2 then
    Halt(1);

  ttryfin5_counter:=0;
  ttryfin5_test2;
  if ttryfin5_counter<>2 then
    Halt(2);

  ttryfin5_counter:=0;
  ttryfin5_test3;
  if ttryfin5_counter<>2 then
    Halt(3);

  ttryfin5_counter:=0;
  ttryfin5_test4;
  if ttryfin5_counter<>4 then
    Halt(4);

  ttryfin5_counter:=0;
  ttryfin5_test5;
  if ttryfin5_counter<>5 then
    Halt(5);
end;
{$pop}

{ Case tinline8.pas }
{$push}
{$ifdef fpc}

{$inline on}
{$endif}
begin
  tinline8_a:=20;
  tinline8_test;
  tinline8_test2;
  tinline8_inl2
end;
{$pop}

{ Case trange2.pas }
{$push}

{$r+}
begin
  trange2_n := 0;
  trange2_l := -1;
  try
    trange2_c := trange2_l;
  except
    writeln('caught 1!');
    inc(trange2_n);
  end;
  trange2_c := cardinal($ffffffff);
  try
    trange2_l := trange2_c;
  except
    writeln('caught 2!');
    inc(trange2_n);
  end;
  if trange2_n <> 2 then
    begin
      writeln('Still problems with range checking between longint/cardinal');
      halt(1);
    end;
end;
{$pop}

end.
