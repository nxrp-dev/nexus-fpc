{ Arrays regression cases; original case IDs are retained below. }

{ Case tb0186.pp }
{$push}
{ Old file: tbs0220.pp }
{ array of char overloading problem with strings        OK 0.99.11 (PFV) }

type
  tb0186_a = array[1..100] of char;

var
  tb0186_a1 : tb0186_a;
  tb0186_s : string;
{$pop}

{ Case tb0233.pp }
{$push}
{ Old file: tbs0273.pp }
{ small array pushing to array of char procedure is wrong OK 0.99.13 (PFV) }

Var tb0233_chararray : Array[1..4] Of Char;

    tb0233_s : String;
{$pop}

{ Case tb0260.pp }
{$push}
{ Old file: tbs0303.pp }
{ One more InternalError(10) out of register !         OK 0.99.13 (FK) }

  type
    tb0260_intarray = array[1..1000,0..1] of longint;

  procedure tb0260_test;
   var
     tb0260_ar : tb0260_intarray;
     tb0260_i : longint;
  procedure local;
   begin
    tb0260_i:=4;
    tb0260_ar[tb0260_i,0]:=56;
    tb0260_ar[tb0260_i-1,0]:=pred(tb0260_ar[tb0260_i,0]);
   end;
  begin
    local;
  end;
{$pop}

{ Case tb0288.pp }
{$push}
{ Old file: tbs0340.pp }
{  }

{$packenum 1}
type
  tb0288_t = (a,b,c,d,e);

const tb0288_arr:  array[0..4] of tb0288_t = (a,b,c,d,e);

var
  tb0288_x: byte;
{$pop}

{ Case tb0321.pp }
{$push}
{ this test program test allocation of large pieces of stack }
{ this is especially necessary for win32                     }

procedure tb0321_p1(tb0321_a : array of byte);

  var
     tb0321_i : longint;

  begin
     for tb0321_i:=0 to high(tb0321_a) do
       tb0321_a[tb0321_i]:=0;
  end;

procedure tb0321_p2;

  var
     tb0321_a : array[0..20000] of byte;
     tb0321_i : longint;

  begin
     for tb0321_i:=0 to high(tb0321_a) do
       tb0321_a[tb0321_i]:=0;
  end;

procedure tb0321_p3;

  var
     tb0321_a : array[0..200000] of byte;
     tb0321_i : longint;

  begin
     for tb0321_i:=0 to high(tb0321_a) do
       tb0321_a[tb0321_i]:=0;
  end;

var
   tb0321_a : array[0..10000] of byte;
{$pop}

{ Case tb0327.pp }
{$push}
type tb0327_ta = array[1..1,1..100] of integer;

procedure tb0327_t(tb0327_a: tb0327_ta);
begin
end;

var tb0327_a: tb0327_ta;
{$pop}

{ Case tb0363.pp }
{$push}
procedure tb0363_p1(const tb0363_a:array of byte);
var
  tb0363_l : longint;
begin
  tb0363_l:=length(tb0363_a);
  writeln('openarray length: ',tb0363_l);
  if tb0363_l<>9 then
   halt(1);
end;

var
  tb0363_a : array[2..10] of byte;
  tb0363_l : longint;
{$pop}

{ Case tb0392.pp }
{$push}
var
  tb0392_l: longint;
  tb0392_a: array[0..1] of char;
{$pop}

{ Case tb0418.pp }
{$push}
procedure tb0418_array_test(b: integer; tb0418_parr: array of word; tb0418_c: integer);
begin
end;
{$pop}

{ Case tb0419.pp }
{$push}
var
  tb0419_nc : integer;
  tb0419_test_w : word;

procedure tb0419_array_test(b: integer; tb0419_parr: array of word; tb0419_c: integer);cdecl;
begin
  tb0419_nc:=tb0419_c;
  tb0419_test_w:=tb0419_parr[2];
end;
{$pop}

{ Case tb0420.pp }
{$push}
procedure tb0420_array_test(b: integer; tb0420_parr: array of word; tb0420_c: integer);cdecl;
begin
end;

var
 tb0420_a: array[1..12] of word;
{$pop}

{ Case tb0446.pp }
{$push}
var
  tb0446_a : array[0..9] of char;
  tb0446_pc : pchar;
{$pop}

begin
  { Case tb0186.pp }
  {$push}

  begin
tb0186_a1[1]:='1';tb0186_a1[2]:='2';tb0186_a1[3]:='3';
  tb0186_a1[4]:='4';tb0186_a1[5]:='5';tb0186_a1[6]:='6';
  tb0186_a1[7]:='7';tb0186_a1[8]:='8';tb0186_a1[9]:='9';
  tb0186_a1[10]:='0';tb0186_a1[11]:='1';
  tb0186_s:=Copy(tb0186_a1,1,10);
  if tb0186_s<>'1234567890' then halt(1);
  writeln('ok');
  end;
  {$pop}

  { Case tb0233.pp }
  {$push}

  begin
tb0233_chararray:='BUG?';
 tb0233_s:=tb0233_chararray;
 WriteLn(tb0233_s);         { * This is O.K. * }
 WriteLn(tb0233_chararray); { * GENERAL PROTECTION FAULT. * }
 if tb0233_chararray<>'BUG?' then
   begin
     Writeln('Error comparing charaay to constant string');
     Halt(1);
   end;
  end;
  {$pop}

  { Case tb0260.pp }
  {$push}

  begin
tb0260_test;
  end;
  {$pop}

  { Case tb0288.pp }
  {$push}
{$packenum 1}
  begin
tb0288_x := 0;
  writeln(ord(tb0288_arr[tb0288_x]),' ',ord(tb0288_arr[tb0288_x+1]),' ',ord(tb0288_arr[tb0288_x+2]),' ',ord(tb0288_arr[tb0288_x+3]),' ',ord(tb0288_arr[tb0288_x+4]));
  for tb0288_x:=0 to 4 do
   if ord(tb0288_arr[tb0288_x])<>tb0288_x then
    begin
      writeln('error in {$packenum 1}');
      halt(1);
    end;
  end;
  {$pop}

  { Case tb0321.pp }
  {$push}

  begin
tb0321_p1(tb0321_a);
   tb0321_p2;
   tb0321_p3;
  end;
  {$pop}

  { Case tb0327.pp }
  {$push}

  begin
tb0327_t(tb0327_a);
  end;
  {$pop}

  { Case tb0363.pp }
  {$push}

  begin
tb0363_l:=length(tb0363_a);
  writeln('length of a ',tb0363_l);
  if tb0363_l<>9 then
   halt(1);

  tb0363_p1(tb0363_a);
  end;
  {$pop}

  { Case tb0392.pp }
  {$push}

  begin
tb0392_l := 50;
  str(tb0392_l,tb0392_a);
  if tb0392_a <> '50' then
    begin
      writeln('error');
      halt(1);
    end;
  end;
  {$pop}

  { Case tb0418.pp }
  {$push}

  begin
tb0418_array_test(0,[12,33,45],0);
  end;
  {$pop}

  { Case tb0419.pp }
  {$push}

  begin
tb0419_nc:=5;
  tb0419_test_w:=$abcd;
  tb0419_array_test(0,[1,2,3,4],56);
  if (tb0419_nc<>56) or (tb0419_test_w<>3) then
    begin
      Writeln('Wrong code generated');
    end;
  end;
  {$pop}

  { Case tb0420.pp }
  {$push}

  begin
tb0420_array_test(0,tb0420_a,0);
  end;
  {$pop}

  { Case tb0446.pp }
  {$push}

  begin
tb0446_a:='1';
  if tb0446_a=nil then
   halt(1);
  tb0446_pc:=@tb0446_a;
  if tb0446_pc<>'1' then
   halt(1);
  writeln('OK')
  end;
  {$pop}

end.
