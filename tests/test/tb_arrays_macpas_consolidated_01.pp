{ Consolidated arrays regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode macpas}

{ Case tparray15.pp }
{$push}
{ from gpc testsuite, original name sam7.pas }

{$ifdef fpc}

{$endif}



Var
  tparray15_foo: array [ 'a'..'f' ] of Boolean = ( false, false, true, false, false, false );
  tparray15_bar: packed array [ 42..47 ] of Boolean;
  tparray15_baz: array [ '0'..'5' ] of Boolean;
  tparray15_i: Integer;


{$pop}

{ Case tparray19.pp }
{$push}


{$r-}

procedure tparray19_error(l: longint);
begin
  writeln('error near ',l);
  halt(1);
end;


procedure tparray19_test8bit;
type
  ta = -1..0;
  tb = packed array[0..999] of ta;
  tc = array[0..124] of byte;
const
  results: array[0..9] of ta = (-1,0,-1,-1,-1,0,-1,-1,-1,0);
var
  a: ta;
  b: tb;
  i,j: longint;
begin
  fillchar(b,sizeof(b),0);
  for i := low(results) to high(results) do
    begin
      b[i] := results[i];
      for j := succ(i) to high(results) do
        if b[j] <> 0 then
          tparray19_error(201);
      if b[i] <> results[i] then
        tparray19_error(202);
    end;
  if (b[0] <> results[0]) then
    tparray19_error(1);
  if (b[1] <> results[1]) then
    tparray19_error(2);
  if (b[2] <> results[2]) then
    tparray19_error(3);
  if (b[3] <> results[3]) then
    tparray19_error(4);
  if (b[4] <> results[4]) then
    tparray19_error(5);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray19_error(7);
end;


procedure tparray19_test8to16bit;
type
  ta = -3..3;
  tb = packed array[0..1000] of ta;
const
  results: array[0..5] of ta = (2,-2,1,-1,-3,1);
var
  a: ta;
  b: tb;
  i,j: longint;
begin
  fillchar(b,sizeof(b),0);
  for i := low(results) to high(results) do
    begin
      b[i] := results[i];
      for j := succ(i) to high(results) do
        if b[j] <> 0 then
          tparray19_error(211);
      if b[i] <> results[i] then
        tparray19_error(212);
    end;
  if (b[0] <> results[0]) then
    tparray19_error(11);
  if (b[1] <> results[1]) then
    tparray19_error(12);
  if (b[2] <> results[2]) then
    tparray19_error(13);
  if (b[3] <> results[3]) then
    tparray19_error(14);
  if (b[4] <> results[4]) then
    tparray19_error(15);
  if (b[5] <> results[5]) then
    tparray19_error(155);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray19_error(17);
end;


procedure tparray19_test16bit;
type
  ta = -255..255;
  tb = packed array[0..799] of ta;
  tc = array[0..899] of byte;
const
  results: array[0..4] of ta = (256-356,39,256-485,100,256-500);
var
  a: ta;
  b: tb;
  i,j: longint;
begin
  fillchar(b,sizeof(b),$ff);
  for i := low(results) to high(results) do
    begin
      b[i] := results[i];
      for j := succ(i) to high(results) do
        if b[j] <> -1 then
          tparray19_error(221);
      if b[i] <> results[i] then
        tparray19_error(222);
    end;
  if (b[0] <> results[0]) then
    tparray19_error(21);
  if (b[1] <> results[1]) then
    tparray19_error(22);
  if (b[2] <> results[2]) then
    tparray19_error(23);
  if (b[3] <> results[3]) then
    tparray19_error(24);
  if (b[4] <> results[4]) then
    tparray19_error(25);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray19_error(27);
end;


procedure tparray19_test16to24bit;
type
  ta = -1023..1023;
  tb = packed array[0..799] of ta;
  tc = array[0..1099] of byte;
const
  results: array[0..4] of ta = (1000,67-1023,853,512-1023,759);
var
  a: ta;
  b: tb;
  i,j: longint;
begin
  fillchar(b,sizeof(b),0);
  for i := low(results) to high(results) do
    begin
      b[i] := results[i];
      for j := succ(i) to high(results) do
        if b[j] <> 0 then
          tparray19_error(231);
      if b[i] <> results[i] then
        tparray19_error(232);
    end;
  if (b[0] <> results[0]) then
    tparray19_error(31);
  if (b[1] <> results[1]) then
    tparray19_error(32);
  if (b[2] <> results[2]) then
    tparray19_error(33);
  if (b[3] <> results[3]) then
    tparray19_error(34);
  if (b[4] <> results[4]) then
    tparray19_error(35);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray19_error(37);
end;


procedure tparray19_test32bit;
type
  ta = -((1 shl 18)-1)..(1 shl 18) - 1;
  tb = packed array[0..799] of ta;
  tc = array[0..1899] of byte;
const
  results: array[0..4] of ta = ($0002F687,$00032222-(1 shl 18),$000178EE,$000057970-(1 shl 18),$0007E1D2-(1 shl 18));
var
  a: ta;
  b: tb;
  i,j: longint;
begin
  fillchar(b,sizeof(b),$00);
  for i := low(results) to high(results) do
    begin
      b[i] := results[i];
      for j := succ(i) to high(results) do
        if b[j] <> 0 then
          tparray19_error(241);
      if b[i] <> results[i] then
        tparray19_error(242);
    end;
  if (b[0] <> results[0]) then
    tparray19_error(41);
  if (b[1] <> results[1]) then
    tparray19_error(42);
  if (b[2] <> results[2]) then
    tparray19_error(43);
  if (b[3] <> results[3]) then
    tparray19_error(44);
  if (b[4] <> results[4]) then
    tparray19_error(45);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray19_error(47);
end;


procedure tparray19_test32to40bit;
type
  ta = -$3fffffff..$3fffffff;
  tb = packed array[0..799] of ta;
  tc = array[0..3099] of byte;
const
  results: array[0..4] of ta = ($3fffffff-$71567851,$3fffffff-$56789ABD,$3fffffff-$50F11178,$39D68DDC,$3fffffff-$6C7A5A7);
var
  a: ta;
  b: tb;
  i,j: longint;
begin
  fillchar(b,sizeof(b),0);
  for i := low(results) to high(results) do
    begin
      b[i] := results[i];
      for j := succ(i) to high(results) do
        if b[j] <> 0 then
          tparray19_error(251);
      if b[i] <> results[i] then
        tparray19_error(252);
    end;
  if (b[0] <> results[0]) then
    tparray19_error(51);
  if (b[1] <> results[1]) then
    tparray19_error(52);
  if (b[2] <> results[2]) then
    tparray19_error(53);
  if (b[3] <> results[3]) then
    tparray19_error(54);
  if (b[4] <> results[4]) then
    tparray19_error(55);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray19_error(57);
end;


{$pop}

{ Case tparray3.pp }
{$push}


type
  tparray3_tba = array[0..7] of boolean;
  tparray3_tkeymap = packed array[0..3] of tparray3_tba;

procedure tparray3_test(var b: tparray3_tba);
begin
end;

var
  tparray3_km: tparray3_tkeymap;
  tparray3_i: longint;
  tparray3_a: tparray3_tba;

{$pop}

{ Case tparray5.pp }
{$push}


{$r-}

procedure tparray5_error(l: longint);
begin
  writeln('error near ',l);
  halt(1);
end;

procedure tparray5_test8bit;
type
  ta = 0..1;
  tb = packed array[0..999] of ta;
  tc = array[0..124] of byte;
const
{$ifdef ENDIAN_BIG}
  results: array[0..9] of ta = (1,0,1,0,1,0,1,0,1,0);
{$else}
  results: array[0..9] of ta = (0,1,0,1,0,1,0,1,0,1);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  fillchar(b,sizeof(b),$AA);
  if (b[0] <> results[0]) then
    tparray5_error(1);
  if (b[1] <> results[1]) then
    tparray5_error(2);
  if (b[2] <> results[2]) then
    tparray5_error(3);
  if (b[3] <> results[3]) then
    tparray5_error(4);
  if (b[4] <> results[4]) then
    tparray5_error(5);
//  if (b[600] <> 1) then
//    error(6);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray5_error(7);
//  i := 500;
//  if (b[i] <> 1) then
//    error(8);
end;


procedure tparray5_test8to16bit;
type
  ta = 0..7;
  tb = packed array[0..1000] of ta;
const
{$ifdef ENDIAN_BIG}
{ 010 110 100 101 101 001 011 010 010 11010010110100101101001011010 }

  results: array[0..5] of ta = (2,6,4,5,5,1);
{$else}
{ (memory layout is different but equivalent with starting at end }
{ 01011010010110100101101001011 010 010 110 100 101 101 001 011 010 }
  results: array[0..5] of ta = (2,3,1,5,5,4);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  fillchar(b,sizeof(b),$5A);
  if (b[0] <> results[0]) then
    tparray5_error(11);
  if (b[1] <> results[1]) then
    tparray5_error(12);
  if (b[2] <> results[2]) then
    tparray5_error(13);
  if (b[3] <> results[3]) then
    tparray5_error(14);
  if (b[4] <> results[4]) then
    tparray5_error(15);
  if (b[5] <> results[5]) then
    tparray5_error(155);
//  if (b[600] <> 2) then
//    error(16);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray5_error(17);
//  i := 500;
//  if (b[i] <> 5) then
//    error(18);
end;


procedure tparray5_test16bit;
type
  ta = 0..511;
  tb = packed array[0..799] of ta;
  tc = array[0..899] of byte;
const
{$ifdef ENDIAN_BIG}
  { 010110100 111011001 011010011 101100101 101001110 110010110 100111011 001011010 0111011001011010011101100101101001110110 }
  results: array[0..4] of ta = ($5A*2,$76 * 4 + 1,$69 * 2 + 1,$B2 * 2 + 1,$A7 * 2);
{$else}
  { algorithm: cut bit string in 16 bit chunks, byteswap, take 9 bits from right to left per chunck, continuing at the right of the next chunck if the previous one is used up }
  { 001011010 100111011 110010110 101001110 101100101 011 0101101001110110010110100111011001011010011101100101101001110110 }

  results: array[0..4] of ta = ($2D*2,$9D*2+1,$CB*2,$A7*2,$B2*2+1);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  for i := 0 to high(tc) div 2 do
    begin
      tc(b)[i*2] := $5A;
      tc(b)[i*2+1] := $76;
    end;
  if (b[0] <> results[0]) then
    tparray5_error(21);
  if (b[1] <> results[1]) then
    tparray5_error(22);
  if (b[2] <> results[2]) then
    tparray5_error(23);
  if (b[3] <> results[3]) then
    tparray5_error(24);
  if (b[4] <> results[4]) then
    tparray5_error(25);
//  if (b[600] <> $76 * 2) then
//    error(26);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray5_error(27);
//  i := 500;
//  if (b[i] <> $A7 * 2) then
//    error(28);
end;

procedure tparray5_test16to24bit;
type
  ta = 0..2047;
  tb = packed array[0..799] of ta;
  tc = array[0..1099] of byte;
const
{$ifdef ENDIAN_BIG}
  results: array[0..4] of ta = ($5A * 8 + 3,$B2 * 8 + 6,$9D * 8 + 4,$B4 * 8 + 7,$65 * 8 + 5);
{$else}
  {  %11001011010 01101001110 00111011001  01100101101 10110100111 011101100 0111011001011010 0111011001011010 0111011001011010 }
  results: array[0..4] of ta = ($0000065A,$0000034E,$000001D9,$0000032D,$000005A7);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  for i := 0 to high(tc) div 2 do
    begin
      tc(b)[i*2] := $5A;
      tc(b)[i*2+1] := $76;
    end;
  if (b[0] <> results[0]) then
    tparray5_error(31);
  if (b[1] <> results[1]) then
    tparray5_error(32);
  if (b[2] <> results[2]) then
    tparray5_error(33);
  if (b[3] <> results[3]) then
    tparray5_error(34);
  if (b[4] <> results[4]) then
    tparray5_error(35);
//  if (b[600] <> $76 * 8 + 2) then
//    error(36);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray5_error(37);
//  i := 500;
//  if (b[i] <> $65 * 8 + 5) then
//    error(38);
end;


procedure tparray5_test32bit;
type
  ta = 0..(1 shl 19) - 1;
  tb = packed array[0..799] of ta;
  tc = array[0..1899] of byte;
const
{$ifdef ENDIAN_BIG}
  results: array[0..4] of ta = ($5A76*8+2, $D3B2*8+6,$9D96*8+4,$ECB4*8+7,$65A7*8+3);
{$else}
  {  0100111011001011010 0110100111011001011  0010110100111011001 0110010110100111011 1110110010110100111 0  01110110010110100111011001011010 01110110010110100111011001011010 01110110010110100111011001011010 01110110010110100111011001011010 01110110010110100111011001011010 01110110010110100111011001011010}
  results: array[0..4] of ta = ($0002765A,$00034ECB,$000169D9,$00032D3B,$000765A7);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  for i := 0 to high(tc) div 2 do
    begin
      tc(b)[i*2] := $5A;
      tc(b)[i*2+1] := $76;
    end;
  if (b[0] <> results[0]) then
    tparray5_error(41);
  if (b[1] <> results[1]) then
    tparray5_error(42);
  if (b[2] <> results[2]) then
    tparray5_error(43);
  if (b[3] <> results[3]) then
    tparray5_error(44);
  if (b[4] <> results[4]) then
    tparray5_error(45);
//  if (b[600] <> $765A*8+3) then
//    error(46);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray5_error(47);
//  i := 500;
//  if (b[i] <> $65a7*8+3) then
//    error(48);
end;

{
  write(hexstr(%1110110010110100111011001011010 ,8),',$');
  write(hexstr(%1101100101101001110110010110100 ,8),',$');
  write(hexstr(%1011001011010011101100101101001 ,8),',$');
  write(hexstr(%0110010110100111011001011010011 ,8),',$');
  writeln(hexstr(%1100101101001110110010110100111 ,8));
}


procedure tparray5_test32to40bit;
type
  ta = 0..$7fffffff;
  tb = packed array[0..799] of ta;
  tc = array[0..3099] of byte;
const
{$ifdef ENDIAN_BIG}
  results: array[0..4] of ta = ($5A765A7*8+3,$2D3B2D3*8+5,$969D969*8+6,$CB4ECB4*8+7,$65A765A*8+3);
{$else}
{
1110110010110100111011001011010 1101100101101001110110010110100 1011001011010011101100101101001 0110010110100111011001011010011 1100101101001110110010110100111 1001011010011101100101101001110 011101
}
  results: array[0..4] of ta = ($765A765A,$6CB4ECB4,$5969D969,$32D3B2D3,$65A765A7);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  for i := 0 to high(tc) div 2 do
    begin
      tc(b)[i*2] := $5A;
      tc(b)[i*2+1] := $76;
    end;
  if (b[0] <> results[0]) then
    tparray5_error(51);
  if (b[1] <> results[1]) then
    tparray5_error(52);
  if (b[2] <> results[2]) then
    tparray5_error(53);
  if (b[3] <> results[3]) then
    tparray5_error(54);
  if (b[4] <> results[4]) then
    tparray5_error(55);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray5_error(57);
//  i := 500;
//  if (b[i] <> $65A765A*8+3) then
//    error(58);
end;


{$pop}

{ Case tparray6.pp }
{$push}


{$r-}

procedure tparray6_error(l: longint);
begin
  writeln('error near ',l);
  halt(1);
end;

procedure tparray6_test8bit;
type
  ta = 0..1;
  tb = packed array[0..999] of ta;
  tc = array[0..124] of byte;
const
{$ifdef ENDIAN_BIG}
  results: array[0..9] of ta = (1,0,1,0,1,0,1,0,1,0);
{$else}
  results: array[0..9] of ta = (0,1,0,1,0,1,0,1,0,1);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  b[0] := results[0];
  b[1] := results[1];
  b[2] := results[2];
  b[3] := results[3];
  b[4] := results[4];
  b[5] := results[5];
  b[6] := results[6];
  b[7] := results[7];
  b[8] := results[8];
  b[9] := results[9];
  if (b[0] <> results[0]) then
    tparray6_error(1);
  if (b[1] <> results[1]) then
    tparray6_error(2);
  if (b[2] <> results[2]) then
    tparray6_error(3);
  if (b[3] <> results[3]) then
    tparray6_error(4);
  if (b[4] <> results[4]) then
    tparray6_error(5);
//  if (b[600] <> 1) then
//    error(6);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray6_error(7);
//  i := 500;
//  if (b[i] <> 1) then
//    error(8);
end;


procedure tparray6_test8to16bit;
type
  ta = 0..7;
  tb = packed array[0..1000] of ta;
const
{$ifdef ENDIAN_BIG}
{ 010 110 100 101 101 001 011 010 010 11010010110100101101001011010 }

  results: array[0..5] of ta = (2,6,4,5,5,1);
{$else}
{ (memory layout is different but equivalent with starting at end }
{ 01011010010110100101101001011 010 010 110 100 101 101 001 011 010 }
  results: array[0..5] of ta = (2,3,1,5,5,4);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  b[0] := results[0];
  b[1] := results[1];
  b[2] := results[2];
  b[3] := results[3];
  b[4] := results[4];
  b[5] := results[5];
  if (b[0] <> results[0]) then
    tparray6_error(11);
  if (b[1] <> results[1]) then
    tparray6_error(12);
  if (b[2] <> results[2]) then
    tparray6_error(13);
  if (b[3] <> results[3]) then
    tparray6_error(14);
  if (b[4] <> results[4]) then
    tparray6_error(15);
  if (b[5] <> results[5]) then
    tparray6_error(155);
//  if (b[600] <> 2) then
//    error(16);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray6_error(17);
//  i := 500;
//  if (b[i] <> 5) then
//    error(18);
end;


procedure tparray6_test16bit;
type
  ta = 0..511;
  tb = packed array[0..799] of ta;
  tc = array[0..899] of byte;
const
{$ifdef ENDIAN_BIG}
  { 010110100 111011001 011010011 101100101 101001110 110010110 100111011 001011010 0111011001011010011101100101101001110110 }
  results: array[0..4] of ta = ($5A*2,$76 * 4 + 1,$69 * 2 + 1,$B2 * 2 + 1,$A7 * 2);
{$else}
  { algorithm: cut bit string in 16 bit chunks, byteswap, take 9 bits from right to left per chunck, continuing at the right of the next chunck if the previous one is used up }
  { 001011010 100111011 110010110 101001110 101100101 011 0101101001110110010110100111011001011010011101100101101001110110 }

  results: array[0..4] of ta = ($2D*2,$9D*2+1,$CB*2,$A7*2,$B2*2+1);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  b[0] := results[0];
  b[1] := results[1];
  b[2] := results[2];
  b[3] := results[3];
  b[4] := results[4];
  if (b[0] <> results[0]) then
    tparray6_error(21);
  if (b[1] <> results[1]) then
    tparray6_error(22);
  if (b[2] <> results[2]) then
    tparray6_error(23);
  if (b[3] <> results[3]) then
    tparray6_error(24);
  if (b[4] <> results[4]) then
    tparray6_error(25);
//  if (b[600] <> $76 * 2) then
//    error(26);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray6_error(27);
//  i := 500;
//  if (b[i] <> $A7 * 2) then
//    error(28);
end;

procedure tparray6_test16to24bit;
type
  ta = 0..2047;
  tb = packed array[0..799] of ta;
  tc = array[0..1099] of byte;
const
{$ifdef ENDIAN_BIG}
  results: array[0..4] of ta = ($5A * 8 + 3,$B2 * 8 + 6,$9D * 8 + 4,$B4 * 8 + 7,$65 * 8 + 5);
{$else}
  {  %11001011010 01101001110 00111011001  01100101101 10110100111 011101100 0111011001011010 0111011001011010 0111011001011010 }
  results: array[0..4] of ta = ($0000065A,$0000034E,$000001D9,$0000032D,$000005A7);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  b[0] := results[0];
  b[1] := results[1];
  b[2] := results[2];
  b[3] := results[3];
  b[4] := results[4];
  if (b[0] <> results[0]) then
    tparray6_error(31);
  if (b[1] <> results[1]) then
    tparray6_error(32);
  if (b[2] <> results[2]) then
    tparray6_error(33);
  if (b[3] <> results[3]) then
    tparray6_error(34);
  if (b[4] <> results[4]) then
    tparray6_error(35);
//  if (b[600] <> $76 * 8 + 2) then
//    error(36);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray6_error(37);
//  i := 500;
//  if (b[i] <> $65 * 8 + 5) then
//    error(38);
end;


procedure tparray6_test32bit;
type
  ta = 0..(1 shl 19) - 1;
  tb = packed array[0..799] of ta;
  tc = array[0..1899] of byte;
const
{$ifdef ENDIAN_BIG}
  results: array[0..4] of ta = ($5A76*8+2, $D3B2*8+6,$9D96*8+4,$ECB4*8+7,$65A7*8+3);
{$else}
  {  0100111011001011010 0110100111011001011  0010110100111011001 0110010110100111011 1110110010110100111 0  01110110010110100111011001011010 01110110010110100111011001011010 01110110010110100111011001011010 01110110010110100111011001011010 01110110010110100111011001011010 01110110010110100111011001011010}
  results: array[0..4] of ta = ($0002765A,$00034ECB,$000169D9,$00032D3B,$000765A7);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  b[0] := results[0];
  b[1] := results[1];
  b[2] := results[2];
  b[3] := results[3];
  b[4] := results[4];
  if (b[0] <> results[0]) then
    tparray6_error(41);
  if (b[1] <> results[1]) then
    tparray6_error(42);
  if (b[2] <> results[2]) then
    tparray6_error(43);
  if (b[3] <> results[3]) then
    tparray6_error(44);
  if (b[4] <> results[4]) then
    tparray6_error(45);
//  if (b[600] <> $765A*8+3) then
//    error(46);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray6_error(47);
//  i := 500;
//  if (b[i] <> $65a7*8+3) then
//    error(48);
end;

{
  write(hexstr(%1110110010110100111011001011010 ,8),',$');
  write(hexstr(%1101100101101001110110010110100 ,8),',$');
  write(hexstr(%1011001011010011101100101101001 ,8),',$');
  write(hexstr(%0110010110100111011001011010011 ,8),',$');
  writeln(hexstr(%1100101101001110110010110100111 ,8));
}


procedure tparray6_test32to40bit;
type
  ta = 0..$7fffffff;
  tb = packed array[0..799] of ta;
  tc = array[0..3099] of byte;
const
{$ifdef ENDIAN_BIG}
  results: array[0..4] of ta = ($5A765A7*8+3,$2D3B2D3*8+5,$969D969*8+6,$CB4ECB4*8+7,$65A765A*8+3);
{$else}
{
1110110010110100111011001011010 1101100101101001110110010110100 1011001011010011101100101101001 0110010110100111011001011010011 1100101101001110110010110100111 1001011010011101100101101001110 011101
}
  results: array[0..4] of ta = ($765A765A,$6CB4ECB4,$5969D969,$32D3B2D3,$65A765A7);
{$endif}
var
  a: ta;
  b: tb;
  i: longint;
begin
  b[0] := results[0];
  b[1] := results[1];
  b[2] := results[2];
  b[3] := results[3];
  b[4] := results[4];
  if (b[0] <> results[0]) then
    tparray6_error(51);
  if (b[1] <> results[1]) then
    tparray6_error(52);
  if (b[2] <> results[2]) then
    tparray6_error(53);
  if (b[3] <> results[3]) then
    tparray6_error(54);
  if (b[4] <> results[4]) then
    tparray6_error(55);
  for i := low(results) to high(results) do
    if b[i] <> results[i] then
      tparray6_error(57);
//  i := 500;
//  if (b[i] <> $65A765A*8+3) then
//    error(58);
end;


{$pop}

begin

{ Case tparray15.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  pack ( tparray15_foo, 'a', tparray15_bar );
  unpack ( tparray15_bar, tparray15_baz, '0' );
  for tparray15_i:= 0 to 5 do
    if tparray15_bar [ 42 + tparray15_i ] <> tparray15_baz [ chr(ord('0')+ tparray15_i) ] then
      tparray15_foo [ 'c' ]:= false;
  if tparray15_foo [ 'c' ] and tparray15_bar [ 44 ] then
    writeln ( 'OK' )
  else
    begin
      writeln ( 'failed ', tparray15_foo [ 'c' ], ' ', tparray15_bar [ 44 ] );
      halt(1)
    end
end;
{$pop}

{ Case tparray19.pp }
{$push}

{$r-}
begin
  tparray19_test8bit;
  tparray19_test8to16bit;
  tparray19_test16bit;
  tparray19_test16to24bit;
  tparray19_test32bit;
  tparray19_test32to40bit;
end;
{$pop}

{ Case tparray3.pp }
{$push}

begin
  tparray3_i := 1;
  fillchar(tparray3_a,sizeof(tparray3_a),0);
  tparray3_km[tparray3_i] := tparray3_a;
end;
{$pop}

{ Case tparray5.pp }
{$push}

{$r-}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
begin
  tparray5_test8bit;
  tparray5_test8to16bit;
  tparray5_test16bit;
  tparray5_test16to24bit;
  tparray5_test32bit;
  tparray5_test32to40bit;
end;
{$pop}

{ Case tparray6.pp }
{$push}

{$r-}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
{$ifdef ENDIAN_BIG}
{$else}
{$endif}
begin
  tparray6_test8bit;
  tparray6_test8to16bit;
  tparray6_test16bit;
  tparray6_test16to24bit;
  tparray6_test32bit;
  tparray6_test32to40bit;
end;
{$pop}

end.
