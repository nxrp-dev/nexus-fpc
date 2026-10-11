{ Consolidated variants regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}
uses variants;

{ Case tb0655.pp }
{$push}




var
  tb0655_s8: Int8 = $12;
  tb0655_u8: UInt8 = $98;
  tb0655_s16: Int16 = $1234;
  tb0655_u16: UInt16 = $9876;
  tb0655_s32: Int32 = $12345768;
  tb0655_u32: UInt32 = $98765432;
  tb0655_s64: Int64 = $1234567812345678;
  tb0655_u64: UInt64 = UInt64($9876543298765432);
  tb0655_v: Variant;
  tb0655_ov: OleVariant;

{$pop}

{ Case tb_variants_default_run_01.pp }
{$push}
{ Variant scalar conversions, Boolean control flow and array creation. }
{ Original case IDs and variable scopes are retained below. }



{ Case tb0410.pp }
{$push}
procedure tb0410_p1(tb0410_f : single);
  begin
  end;

procedure tb0410_p2(tb0410_l : longint);
  begin
  end;

var
   tb0410_v : variant;
   tb0410_l : longint;
{$pop}

{ Case tb0487.pp }
{$push}
var
  tb0487_v : variant;
  tb0487_i : longint;
{$pop}

{ Case tb0492.pp }
{$push}
var
  tb0492_v: Variant;
{$pop}

{ Case tb0520.pp }
{$push}
var
  tb0520_w : widestring;
  tb0520_v : variant;
  tb0520_a : ansistring;
{$pop}

{ Case tb0536.pp }
{$push}
var tb0536_dt : TDateTime;
    tb0536_v : variant;
    tb0536_s : String;
{$pop}

{ Case tb0537.pp }
{$push}
var
  tb0537_d: array of variant;
  tb0537_v: variant;
{$pop}


{$pop}

{ Case tw10495.pp }
{$push}

var
  tw10495_tmp: OleVariant;
  tw10495_a: OleVariant;
  tw10495_b: OleVariant;

{$pop}

{ Case tw12151.pp }
{$push}

var
  tw12151_Values: OleVariant;
  tw12151_mTempNames: string;

{$pop}

{ Case tw32539.pp }
{$push}

var
  tw32539_v : variant;


{$pop}

{ Case tw3700.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3700 }
{ Submitted by "Roman" on  2005-02-26 }
{ e-mail: roman@csltd.com.ua }

var
  tw3700_v : olevariant;
  tw3700_b : boolean;

{$pop}

{ Case tw3953a.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3953 }
{ Submitted by "Jesus Reyes A." on  2005-05-08 }
{ e-mail: jesusrmx@yahoo.com.mx }


var
  tw3953a_A,tw3953a_B: Variant;

{$pop}

{ Case tw3953b.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3953 }
{ Submitted by "Jesus Reyes A." on  2005-05-08 }
{ e-mail: jesusrmx@yahoo.com.mx }


var
  tw3953b_A,tw3953b_B: Variant;

{$pop}

{ Case tw9098.pp }
{$push}


var
  tw9098_v: variant;
  tw9098_i: longint;

{$pop}

begin

{ Case tb0655.pp }
{$push}

begin
  tb0655_v := tb0655_s8;
  if VarType(tb0655_v) <> varShortInt then
    Halt(1);
  if Int8(tb0655_v) <> tb0655_s8 then
    Halt(2);

  tb0655_v := tb0655_u8;
  if VarType(tb0655_v) <> varByte then
    Halt(3);
  if UInt8(tb0655_v) <> tb0655_u8 then
    Halt(4);

  tb0655_v := tb0655_s16;
  if VarType(tb0655_v) <> varSmallInt then
    Halt(5);
  if Int16(tb0655_v) <> tb0655_s16 then
    Halt(6);

  tb0655_v := tb0655_u16;
  if VarType(tb0655_v) <> varWord then
    Halt(7);
  if UInt16(tb0655_v) <> tb0655_u16 then
    Halt(8);

  tb0655_v := tb0655_s32;
  if VarType(tb0655_v) <> varInteger then
    Halt(9);
  if Int32(tb0655_v) <> tb0655_s32 then
    Halt(10);

  tb0655_v := tb0655_u32;
  if VarType(tb0655_v) <> varLongWord then
    Halt(11);
  if UInt32(tb0655_v) <> tb0655_u32 then
    Halt(12);

  tb0655_v := tb0655_s64;
  if VarType(tb0655_v) <> varInt64 then
    Halt(13);
  if Int64(tb0655_v) <> tb0655_s64 then
    Halt(14);

  tb0655_v := tb0655_u64;
  if VarType(tb0655_v) <> varUInt64 then
    Halt(15);
  if UInt64(tb0655_v) <> tb0655_u64 then
    Halt(16);

  { OleVariant has slightly different behaviour to Variant }
  tb0655_ov := tb0655_s8;
  if VarType(tb0655_ov) <> varInteger then
    Halt(17);
  if Int8(tb0655_ov) <> tb0655_s8 then
    Halt(18);

  tb0655_ov := tb0655_u8;
  if VarType(tb0655_ov) <> varInteger then
    Halt(19);
  if UInt8(tb0655_ov) <> tb0655_u8 then
    Halt(20);

  tb0655_ov := tb0655_s16;
  if VarType(tb0655_ov) <> varInteger then
    Halt(21);
  if Int16(tb0655_ov) <> tb0655_s16 then
    Halt(22);

  tb0655_ov := tb0655_u16;
  if VarType(tb0655_ov) <> varInteger then
    Halt(23);
  if UInt16(tb0655_ov) <> tb0655_u16 then
    Halt(24);

  tb0655_ov := tb0655_s32;
  if VarType(tb0655_ov) <> varInteger then
    Halt(25);
  if Int32(tb0655_ov) <> tb0655_s32 then
    Halt(26);

  tb0655_ov := tb0655_u32;
  if VarType(tb0655_ov) <> varInteger then
    Halt(27);
  { ! }
  if UInt32(Int32(tb0655_ov)) <> tb0655_u32 then
    Halt(28);

  tb0655_ov := tb0655_s64;
  if VarType(tb0655_ov) <> varInt64 then
    Halt(29);
  if Int64(tb0655_ov) <> tb0655_s64 then
    Halt(30);

  tb0655_ov := tb0655_u64;
  if VarType(tb0655_ov) <> varUInt64 then
    Halt(31);
  if UInt64(tb0655_ov) <> tb0655_u64 then
    Halt(32);
end;
{$pop}

{ Case tb_variants_default_run_01.pp }
{$push}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tb0410.pp }
  {$push}
begin
   tb0410_v:=1;
   tb0410_p1(tb0410_v);
   tb0410_p2(tb0410_v);
   tb0410_l:=tb0410_v;
end;
  {$pop}

  { Case tb0487.pp }
  {$push}
begin
  tb0487_v:=true;
  if not(tb0487_v) then
    halt(1);
  while not(tb0487_v) do
    halt(1);
  tb0487_i:=1;
  repeat
    if tb0487_i>1 then
      halt(1);
    inc(tb0487_i);
  until tb0487_v;
  writeln('ok');
end;
  {$pop}

  { Case tb0492.pp }
  {$push}
begin
  tb0492_v := VarArrayCreate([0, 1], varVariant);
end;
  {$pop}

  { Case tb0520.pp }
  {$push}
begin
  tb0520_a:='';
  tb0520_w:='';
  tb0520_v:='asdf';
  pos(tb0520_a,tb0520_v);
  pos(tb0520_w,tb0520_v);
  pos(tb0520_v,tb0520_v);
  pos(tb0520_v,tb0520_a);
  pos(tb0520_v,tb0520_w);
  pos(tb0520_v,tb0520_v);
end;
  {$pop}

  { Case tb0536.pp }
  {$push}
begin
  tb0536_dt := 40000;
  tb0536_v := tb0536_dt;
  tb0536_s := tb0536_v;
  // It should return the date, depending on the localisation settings
  if tb0536_s = '40000' then halt(1);
end;
  {$pop}

  { Case tb0537.pp }
  {$push}
begin
  tb0537_v:=tb0537_d;
  tb0537_d:=tb0537_v;
end;
  {$pop}

end;
{$pop}

{ Case tw10495.pp }
{$push}

begin
  tw10495_tmp:=VarArrayCreate([0,2], varVariant);
  tw10495_a:=1234;
  tw10495_b:=4321;
  tw10495_tmp[0]:=tw10495_a;
  tw10495_tmp[1]:=tw10495_b;
  tw10495_a:=tw10495_tmp[0];
  tw10495_b:=tw10495_tmp[1];
  if tw10495_a<>1234 then
    halt(1);
  if tw10495_b<>4321 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tw12151.pp }
{$push}

begin
  tw12151_Values := VarArrayCreate([0, 0], varVariant);
  //this row will cause runtime error
  tw12151_Values[0] := VarArrayCreate([0, 1], varByte);
end;
{$pop}

{ Case tw32539.pp }
{$push}

begin
  tw32539_v:=1.5;
  tw32539_v:=sqr(tw32539_v);
  if tw32539_v<>1.5*1.5 then
    halt(1);
  tw32539_v:=-tw32539_v;
  tw32539_v:=abs(tw32539_v);
  if tw32539_v<>1.5*1.5 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tw3700.pp }
{$push}

begin
  tw3700_b:=VarIsArray(tw3700_V);
end;
{$pop}

{ Case tw3953a.pp }
{$push}

begin
  tw3953a_A := True;
  tw3953a_B := True;
  if tw3953a_A=tw3953a_B then
    WriteLn('A and B are equal')
  else
    begin
      WriteLn('A and B are NOT equal');
      halt(1);
    end;
end;
{$pop}

{ Case tw3953b.pp }
{$push}

begin
  tw3953b_A := NULL;
  tw3953b_B := NULL;
  if tw3953b_A=tw3953b_B then
    WriteLn('A and B are equal')
  else
    begin
      WriteLn('A and B are NOT equal');
      halt(1);
    end;
end;
{$pop}

{ Case tw9098.pp }
{$push}

begin
  tw9098_v:=VarArrayOf([1, True, '123']);
  for tw9098_i:=VarArrayLowBound(tw9098_v, 1) to VarArrayHighBound(tw9098_v, 1) do
    Writeln(tw9098_v[tw9098_i]);

  VarArrayRedim(tw9098_v, -1);

  tw9098_v:=VarArrayOf([]);
  if VarType(tw9098_v) <> 8204 then begin
    writeln('Wrong vartype: ', VarType(tw9098_v));
    Halt(1);
  end;

  if VarArrayHighBound(tw9098_v, 1) <> -1 then begin
    writeln('Wrong high bound: ', VarArrayHighBound(tw9098_v, 1));
    Halt(2);
  end;
end;
{$pop}

end.
