{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case talign.pas }
{$push}
var
  talign_p: pointer;
  talign_u: ptruint;
  talign_i: cardinal;

{$pop}

{ Case tseg.pas }
{$push}
{ Part of System unit testsuit        }
{ Carl Eric Codere Copyright (c) 2002 }


{$ifdef CPUI8086}
const
  tseg_seg_should_be_zero = false;
{$else}
const
  tseg_seg_should_be_zero = true;
{$endif}

const
 tseg_cst : integer = 0;
var
 tseg_variable : integer;

procedure tseg_fail;
 begin
  WriteLn('Failure!');
  halt(1);
 end;

procedure tseg_test_cseg;
 begin
   Write('Testing CSeg()...');
   if ((cseg <> 0) and tseg_seg_should_be_zero) or
      ((cseg=0) and not tseg_seg_should_be_zero) then
     tseg_fail
   else
     WriteLn('Success!');
 end;

procedure tseg_test_dseg;
 begin
   Write('Testing DSeg()...');
   if ((dseg <> 0) and tseg_seg_should_be_zero) or
      ((dseg=0) and not tseg_seg_should_be_zero) then
     tseg_fail
   else
     WriteLn('Success!');
 end;

procedure tseg_test_sseg;
 begin
   Write('Testing SSeg()...');
   if ((sseg <> 0) and tseg_seg_should_be_zero) or
      ((sseg=0) and not tseg_seg_should_be_zero) then
     tseg_fail
   else
     WriteLn('Success!');
 end;

procedure tseg_test_seg;
 var
   x : longint;
   _result : boolean;
 begin
   _result := true;
   Write('Testing Seg()...');
   if ((seg(x) <> 0) and tseg_seg_should_be_zero) or
      ((seg(x)=0) and not tseg_seg_should_be_zero) then
     _result := false;
   if ((seg(tseg_cst) <> 0) and tseg_seg_should_be_zero) or
      ((seg(tseg_cst)=0) and not tseg_seg_should_be_zero) then
     _result := false;
   if ((seg(tseg_variable) <> 0) and tseg_seg_should_be_zero) or
      ((seg(tseg_variable)=0) and not tseg_seg_should_be_zero) then
     _result := false;
   if not _result then
     tseg_fail
   else
     WriteLn('Success!');
 end;


{$pop}

{ Case tumul64x64_128.pas }
{$push}
var
  tumul64x64_128_s1,tumul64x64_128_s2,tumul64x64_128_dl,tumul64x64_128_dh: qword;

{$pop}

begin

{ Case talign.pas }
{$push}

begin
  talign_p:=pointer(1);
  for talign_i:=0 to 15 do
    if align(talign_p+talign_i,16)<>pointer(16) then
      halt(1);
  talign_p:=pointer(41);
  for talign_i:=0 to 39 do
    if align(talign_p+talign_i,40)<>pointer(80) then
      halt(2);
  talign_p:=pointer(1);
  for talign_i:=0 to 40 do
    if align(talign_p+talign_i,41)<pointer(41) then
      halt(3);
  talign_p:=pointer(42);
  for talign_i:=0 to 40 do
    if align(talign_p+talign_i,41)<>pointer(82) then
      halt(4);

  talign_u:=1;
  for talign_i:=0 to 15 do
    if align(talign_u+talign_i,16)<>16 then
      halt(101);
  talign_u:=41;
  for talign_i:=0 to 39 do
    if align(talign_u+talign_i,40)<>80 then
      halt(102);
  talign_u:=1;
  for talign_i:=0 to 40 do
    if align(talign_u+talign_i,41)<>41 then
      halt(103);
  talign_u:=42;
  for talign_i:=0 to 40 do
    if align(talign_u+talign_i,41)<>82 then
      halt(4);
end;
{$pop}

{ Case tseg.pas }
{$push}
{$ifdef CPUI8086}
{$else}
{$endif}
Begin
  tseg_test_cseg;
  tseg_test_dseg;
  tseg_test_seg;
  tseg_test_sseg;
end;
{$pop}

{ Case tumul64x64_128.pas }
{$push}

begin
  tumul64x64_128_s1:=1;
  tumul64x64_128_s2:=1;
  tumul64x64_128_dl:=UMul64x64_128(tumul64x64_128_s1,tumul64x64_128_s2,tumul64x64_128_dh);
  if (tumul64x64_128_dl<>1) or (tumul64x64_128_dh<>0) then
    halt(1);

  tumul64x64_128_s1:=$4000000000000001;
  tumul64x64_128_s2:=$4000000000000001;
  tumul64x64_128_dl:=UMul64x64_128(tumul64x64_128_s1,tumul64x64_128_s2,tumul64x64_128_dh);
  if (tumul64x64_128_dl<>qword($8000000000000001)) or (tumul64x64_128_dh<>$1000000000000000) then
    halt(2);

  tumul64x64_128_s1:=qword($ffffffffffffffff);
  tumul64x64_128_s2:=qword($ffffffffffffffff);
  tumul64x64_128_dl:=UMul64x64_128(tumul64x64_128_s1,tumul64x64_128_s2,tumul64x64_128_dh);
  if (tumul64x64_128_dl<>$0000000000000001) or (tumul64x64_128_dh<>qword($FFFFFFFFFFFFFFFE)) then
    halt(3);
end;
{$pop}

end.
