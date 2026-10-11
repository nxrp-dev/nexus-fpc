{ Consolidated integer-codegen-default regression cases; original IDs and assertions are retained. }
{$mode fpc}

{ Case tw0802.pp }
{$push}
function tw0802_testf (tw0802_a:byte;tw0802_b:integer;tw0802_c:char):char;
  begin
    tw0802_testf:=tw0802_c;
  end;
{$pop}

{ Case tw1046.pp }
{$push}
procedure tw1046_test2(tw1046_self : longint);
begin
 writeln(tw1046_self);
end;
{$pop}

{ Case tw10863.pp }
{$push}
function tw10863_f(tw10863_b,tw10863_c,tw10863_d : boolean) : longint;
 begin
   tw10863_f:=ord(tw10863_b);
 end;

procedure tw10863_test;
var
 tw10863_b,tw10863_c : boolean;

begin
 tw10863_b:=true;
 tw10863_c:=false;
 tw10863_b:=1<>tw10863_f(tw10863_b,not(tw10863_b),tw10863_c);
 tw10863_c:=true;
 if (tw10863_b) then
   halt(1);
 writeln(tw10863_c);
end;
{$pop}

{ Case tw12237.pp }
{$push}
function tw12237_f: longint; safecall;
begin
  tw12237_f:=-2;
end;
{$pop}

{ Case tw17458.pp }
{$push}
function tw17458_tailrecfibonacci(const tw17458_n: Byte): QWord;

  function tw17458_innerfibo(const tw17458_n: Byte; const tw17458_r1,tw17458_r2: QWord): QWord; inline;
  begin
    case tw17458_n of
      0: tw17458_innerfibo := tw17458_r1;
      1: tw17458_innerfibo := tw17458_r2;
      else tw17458_innerfibo := tw17458_innerfibo(tw17458_n - 1,tw17458_r2,tw17458_r1 + tw17458_r2);
    end;
  end;

begin
  tw17458_tailrecfibonacci := tw17458_innerfibo(tw17458_n,0,1);
end;
{$pop}

{ Case tw17836.pp }
{$push}
var
    tw17836_w,tw17836_w1: int64;
{$pop}

{ Case tw1936.pp }
{$push}
var
   tw1936_x,tw1936_y,tw1936_x1,tw1936_y1,tw1936_x2,tw1936_y2,tw1936_style: byte;
{$pop}

{ Case tw2028.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2028 }
{ Submitted by "Han Wentao" on  2002-07-04 }
{ e-mail: hanwentao@cnnb.net }
{$INLINE ON}
function tw2028_max(tw2028_a,tw2028_b:Byte):Byte; inline;
begin
  if tw2028_a>tw2028_b then
    tw2028_max:=tw2028_a
  else
    tw2028_max:=tw2028_b;
end;

var
 tw2028_l1,  tw2028_l2 : longint;
{$pop}

{ Case tw20821.pp }
{$push}
var
  tw20821_b : byte;
{$pop}

{ Case tw20998.pp }
{$push}
var
  tw20998_i : int64;
  tw20998_j, tw20998_k: longint;
{$pop}

{ Case tw21029.pp }
{$push}
{$r+}
{$inline on}

function tw21029_f(tw21029_y : byte) : byte; inline;
begin
  tw21029_f:=byte(not tw21029_y);
end;
{$pop}

begin
  { Case tw0802.pp }
  {$push}

begin
  writeln('"',tw0802_testf(0,-1,'A'),'"');
end;
  {$pop}

  { Case tw1046.pp }
  {$push}

begin
  tw1046_test2(1);
end;
  {$pop}

  { Case tw10863.pp }
  {$push}

begin
  tw10863_test;
end;
  {$pop}

  { Case tw12237.pp }
  {$push}

begin
  if (tw12237_f<>-2) then
    halt(1);
end;
  {$pop}

  { Case tw17458.pp }
  {$push}

begin
  if tw17458_tailrecfibonacci(10)<>55 then
    halt(1);
end;
  {$pop}

  { Case tw17836.pp }
  {$push}

begin
    tw17836_w1:=-1;
    tw17836_w:=tw17836_w1 div (int64(1) shl 33);
    system.writeln(tw17836_w);
    if tw17836_w<>0 then
      halt(1);
    tw17836_w:=tw17836_w1 div (int64(1) shl 32);
    system.writeln(tw17836_w);
    if tw17836_w<>0 then
      halt(2);
    tw17836_w:=tw17836_w1 div (int64(1) shl 31);
    system.writeln(tw17836_w);
    if tw17836_w<>0 then
      halt(3);
    tw17836_w:=tw17836_w1 div (int64(1) shl 5);
    system.writeln(tw17836_w);
    if tw17836_w<>0 then
      halt(4);
    end;
  {$pop}

  { Case tw1936.pp }
  {$push}

begin
   tw1936_x := 4;
   tw1936_y := 5;
   tw1936_x1 := 3;
   tw1936_x2 := 5;
   tw1936_y1 := 4;
   tw1936_y2 := 6;
   tw1936_style := 7;

   if ((tw1936_style=0) and (tw1936_x in [tw1936_x1..tw1936_x2]) and (tw1936_y in [tw1936_y1..tw1936_y2]))
   or ((tw1936_style=6) and (tw1936_x in [succ(tw1936_x1)..pred(tw1936_x2)]) and (tw1936_y in [tw1936_y1+3..pred(tw1936_y2)]))
   or ((tw1936_style <> 0) and (tw1936_style <> 6) and  (tw1936_x in [succ(tw1936_x1)..pred(tw1936_x2)]) and (tw1936_y in [succ(tw1936_y1)..pred(tw1936_y2)]))
   then
   begin
      writeln ('OK');
   end
   else
   begin
     writeln('ERROR');
     halt(1);
   end;
end;
  {$pop}

  { Case tw2028.pp }
  {$push}
{$inline on}
begin
  tw2028_l1:=tw2028_max(1,2);
  tw2028_l2:=tw2028_max(2,1);
  if tw2028_l1 <> 2 then
   begin
     WriteLn('Error!');
     halt(1);
   end;
  if tw2028_l2 <> 2 then
   begin
     WriteLn('Error!');
     halt(1);
   end;
end;
  {$pop}

  { Case tw20821.pp }
  {$push}

begin
  tw20821_b:=170;
  if tw20821_b<>Byte(#%10101010) then
    halt(1);
  if tw20821_b<>Byte(%10101010) then
    halt(1);
  if tw20821_b<>%10101010 then
    halt(1);
  WriteLn('Ok');
end;
  {$pop}

  { Case tw20998.pp }
  {$push}

begin
  tw20998_k:=64;
  for tw20998_j:=6400 to 6464 do
    begin
      tw20998_i:=tw20998_j;
      if (tw20998_i div 64) <> (tw20998_i div tw20998_k) then
        halt(1);
    end;
  tw20998_i:=6500;
  tw20998_i:=tw20998_i div 65;
  if tw20998_i<>100 then
    halt(1);
  for tw20998_j:=-6400 downto -6464 do
    begin
      tw20998_i:=tw20998_j;
      if (tw20998_i div 64) <> (tw20998_i div tw20998_k) then
        halt(2);
    end;
  writeln('ok');
end;
  {$pop}

  { Case tw21029.pp }
  {$push}
{$R+}
{$inline on}
BEGIN
  if tw21029_f(1)<>254 then
    halt(1);
END;
  {$pop}

end.
