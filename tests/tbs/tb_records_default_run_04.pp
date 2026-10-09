{ Records regression cases; original case IDs are retained below. }

{ Case tw33222.pp }
{$push}
var
  tw33222_hl : record
    tw33222_hashnext : pqword;
  end;
  tw33222_fs : dword;
  tw33222_sr : record
    tw33222_slot : dword;
  end;

procedure tw33222_p;
begin
  tw33222_hl.tw33222_hashnext[tw33222_sr.tw33222_slot] := (qword(tw33222_fs) shl 32) or dword(tw33222_hl.tw33222_hashnext[tw33222_sr.tw33222_slot]);
end;
{$pop}

{ Case tw33417.pp }
{$push}
type
  tw33417_tflags = bitpacked record // Flags
    tw33417_bit0,tw33417_bit1,tw33417_bit2,tw33417_bit3,tw33417_bit4,tw33417_bit5,tw33417_bit6,tw33417_bit7 : boolean;
  end;

var
  tw33417_gflags : tw33417_tflags;
  tw33417_i : byte;

procedure tw33417_p(pflags : tw33417_tflags);

var
  tw33417_flags : tw33417_tflags;
begin
  tw33417_flags:=tw33417_gflags;
  if tw33417_flags.tw33417_bit5 then
    tw33417_i:=1;
  if pflags.tw33417_bit5 then
    tw33417_i:=1;
  if tw33417_gflags.tw33417_bit5 then
    tw33417_i:=1;
  if not tw33417_flags.tw33417_bit6 then
    tw33417_i:=1;
  if not pflags.tw33417_bit6 then
    tw33417_i:=1;
  if not tw33417_gflags.tw33417_bit6 then
    tw33417_i:=1;
end;
{$pop}

{ Case tw34971.pp }
{$push}
type
  tw34971_t1 = -1..1;
  tw34971_t2 = -4..3;
  tw34971_t3 = -3..4;
type
  tw34971_r1 = bitpacked record
    tw34971_f: tw34971_t1;
  end;

  tw34971_r2 = bitpacked record
    tw34971_f: tw34971_t2;
  end;

  tw34971_r3 = bitpacked record
   tw34971_f: tw34971_t3;
  end;
{$pop}

{ Case tw36156.pp }
{$push}
type
  tw36156_tbitsize = -7..7;
  tw36156_tfpdbgvaluesize = bitpacked record
    tw36156_size: Int64;
    tw36156_bitsize: tw36156_tbitsize;
  end;

const
  tw36156_gcfpdbgvaluesize: tw36156_tfpdbgvaluesize = (tw36156_size: $7FFFFFFF; tw36156_bitsize: 2);
{$pop}

{ Case tw36934.pp }
{$push}
type
  tw36934_tpointf = record
    tw36934_x,tw36934_y: single;
  end;

procedure tw36934_test(pt1, pt2, pt3,
  tw36934_pt4: tw36934_tpointf; tw36934_texture: tobject; tw36934_tex1, tw36934_tex2, tw36934_tex3, tw36934_tex4: tw36934_tpointf);
begin
  if pt1.tw36934_x<>1.0 then
    halt(1);
  if pt1.tw36934_y<>2.0 then
    halt(2);
  if pt2.tw36934_x<>3.0 then
    halt(3);
  if pt2.tw36934_y<>4.0 then
    halt(4);
  if pt3.tw36934_x<>5.0 then
    halt(5);
  if pt3.tw36934_y<>6.0 then
    halt(6);
  if tw36934_pt4.tw36934_x<>7.0 then
    halt(7);
  if tw36934_pt4.tw36934_y<>8.0 then
    halt(8);
  if tw36934_texture<>nil then
    halt(9);
  if tw36934_tex1.tw36934_x<>9.0 then
    halt(9);
  if tw36934_tex1.tw36934_y<>10.0 then
    halt(10);
  if tw36934_tex2.tw36934_x<>11.0 then
    halt(11);
  if tw36934_tex2.tw36934_y<>12.0 then
    halt(12);
  if tw36934_tex3.tw36934_x<>13.0 then
    halt(13);
  if tw36934_tex3.tw36934_y<>14.0 then
    halt(14);
  if tw36934_tex4.tw36934_x<>15.0 then
    halt(15);
  if tw36934_tex4.tw36934_y<>16.0 then
    halt(16);
end;

var
  tw36934_p1,tw36934_p2,tw36934_p3,tw36934_p4,tw36934_t1,tw36934_t2,tw36934_t3,tw36934_t4: tw36934_tpointf;
{$pop}

{ Case tw36934a.pp }
{$push}
type
  tw36934a_tpointf = record
    tw36934a_x,tw36934a_y: double;
  end;

procedure tw36934a_test(pt1, pt2, pt3,
  tw36934a_pt4: tw36934a_tpointf; tw36934a_texture: tobject; tw36934a_tex1, tw36934a_tex2, tw36934a_tex3, tw36934a_tex4: tw36934a_tpointf);
begin
  if pt1.tw36934a_x<>1.0 then
    halt(1);
  if pt1.tw36934a_y<>2.0 then
    halt(2);
  if pt2.tw36934a_x<>3.0 then
    halt(3);
  if pt2.tw36934a_y<>4.0 then
    halt(4);
  if pt3.tw36934a_x<>5.0 then
    halt(5);
  if pt3.tw36934a_y<>6.0 then
    halt(6);
  if tw36934a_pt4.tw36934a_x<>7.0 then
    halt(7);
  if tw36934a_pt4.tw36934a_y<>8.0 then
    halt(8);
  if tw36934a_texture<>nil then
    halt(9);
  if tw36934a_tex1.tw36934a_x<>9.0 then
    halt(9);
  if tw36934a_tex1.tw36934a_y<>10.0 then
    halt(10);
  if tw36934a_tex2.tw36934a_x<>11.0 then
    halt(11);
  if tw36934a_tex2.tw36934a_y<>12.0 then
    halt(12);
  if tw36934a_tex3.tw36934a_x<>13.0 then
    halt(13);
  if tw36934a_tex3.tw36934a_y<>14.0 then
    halt(14);
  if tw36934a_tex4.tw36934a_x<>15.0 then
    halt(15);
  if tw36934a_tex4.tw36934a_y<>16.0 then
    halt(16);
end;

var
  tw36934a_p1,tw36934a_p2,tw36934a_p3,tw36934a_p4,tw36934a_t1,tw36934a_t2,tw36934a_t3,tw36934a_t4: tw36934a_tpointf;
{$pop}

{ Case tw36934b.pp }
{$push}
type
  tw36934b_tpointf = record
    tw36934b_x,tw36934b_y,tw36934b_z,tw36934b_v,tw36934b_u: single;
  end;

procedure tw36934b_test(pt1, pt2, pt3: tw36934b_tpointf);
begin
  if pt1.tw36934b_x<>1.0 then
    halt(1);
  if pt1.tw36934b_y<>2.0 then
    halt(2);
  if pt1.tw36934b_z<>3.0 then
    halt(3);
  if pt1.tw36934b_u<>4.0 then
    halt(4);
  if pt1.tw36934b_v<>5.0 then
    halt(5);
  if pt2.tw36934b_x<>6.0 then
    halt(6);
  if pt2.tw36934b_y<>7.0 then
    halt(7);
  if pt2.tw36934b_z<>8.0 then
    halt(8);
  if pt2.tw36934b_u<>9.0 then
    halt(9);
  if pt2.tw36934b_v<>10.0 then
    halt(10);
  if pt3.tw36934b_x<>11.0 then
    halt(11);
  if pt3.tw36934b_y<>12.0 then
    halt(12);
  if pt3.tw36934b_z<>13.0 then
    halt(13);
  if pt3.tw36934b_u<>14.0 then
    halt(14);
  if pt3.tw36934b_v<>15.0 then
    halt(15);
end;

var
  tw36934b_p1,tw36934b_p2,tw36934b_p3,tw36934b_p4,tw36934b_t1,tw36934b_t2,tw36934b_t3,tw36934b_t4: tw36934b_tpointf;
{$pop}

{ Case tw37780.pp }
{$push}
type
  tw37780_ptestrec = ^tw37780_ttestrec;
  tw37780_ttestrec = record
    tw37780_val: Integer;
    tw37780_next: tw37780_ptestrec;
  end;

var
  tw37780_tr: tw37780_ttestrec;
{$pop}

{ Case tw40252.pp }
{$push}
type
  tw40252_tlazloggerlogenabled = record end;

procedure tw40252_test(Log : tw40252_tlazloggerlogenabled; const tw40252_s : string);
begin
  writeln('Test: ',tw40252_s);
end;

procedure tw40252_testv(var Log : tw40252_tlazloggerlogenabled; const tw40252_s : string);
begin
  writeln('Testv: ',tw40252_s);
end;

procedure tw40252_debuglnstack(LogEnabled: tw40252_tlazloggerlogenabled; const tw40252_s: string);
begin
  tw40252_test(LogEnabled, tw40252_s);
  tw40252_testv(LogEnabled, tw40252_s);
end;

var
  tw40252_le : tw40252_tlazloggerlogenabled;
{$pop}

{ Case tw4104.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4104 }
{ Submitted by "Daniël Mantione" on  2005-06-22 }
{ e-mail: daniel@freepascal.org }

type tw4104_junk=record
       tw4104_data:ansistring;
     end;

operator :=(x:longint) result:tw4104_junk;

begin
  str(x,result.tw4104_data);
end;

procedure tw4104_write_junk(const tw4104_data:array of tw4104_junk);

var tw4104_i:cardinal;

begin
  for tw4104_i:=low(tw4104_data) to high(tw4104_data) do
   begin
     write(tw4104_data[tw4104_i].tw4104_data);
     write('<-->');
     writeln(Pchar(tw4104_data[tw4104_i].tw4104_data));
   end;
end;
{$pop}

{ Case tw41460.pp }
{$push}
{$T-}

type
   tw41460_trecord = record
     tw41460_first: word;
     tw41460_second: word;
   end;
   tw41460_precord = ^tw41460_trecord;

var
   tw41460_res, tw41460_res2, tw41460_res3 : PtrInt;
   tw41460_rec : tw41460_trecord;
{$pop}

{ Case tw41460a.pp }
{$push}
{$T+}
{ In T+ mode, i.e. type pointer mode,
  the difference between two pointers of the same type
  is divided by the byte size of that type }
type
   tw41460a_trecord = record
     tw41460a_first: word;
     tw41460a_second: word;
   end;
   tw41460a_precord = ^tw41460a_trecord;

var
   tw41460a_res, tw41460a_res_nil : PtrInt;
   tw41460a_rec : tw41460a_trecord;
{$pop}

begin
  { Case tw33222.pp }
  {$push}

  begin
tw33222_fs:=$12341234;
  tw33222_sr.tw33222_slot:=0;
  getmem(tw33222_hl.tw33222_hashnext,sizeof(qword));
  tw33222_hl.tw33222_hashnext[tw33222_sr.tw33222_slot]:=$1eadbeef00000000;
  tw33222_p;
  if tw33222_hl.tw33222_hashnext[tw33222_sr.tw33222_slot]<>$1234123400000000 then
    halt(1);
  freemem(tw33222_hl.tw33222_hashnext);
  writeln('ok');
  end;
  {$pop}

  { Case tw33417.pp }
  {$push}

  begin
tw33417_gflags.tw33417_bit4:=false;
  tw33417_gflags.tw33417_bit5:=false;
  tw33417_gflags.tw33417_bit6:=true;
  tw33417_i:=0;
  tw33417_p(tw33417_gflags);
  if tw33417_i<>0 then
    halt(tw33417_i)
  else
    writeln('ok');
  end;
  {$pop}

  { Case tw34971.pp }
  {$push}

  begin
if bitsizeof(tw34971_r1.tw34971_f)<>2 then
    halt(1);
  if bitsizeof(tw34971_r2.tw34971_f)<>3 then
    halt(2);
  if bitsizeof(tw34971_r3.tw34971_f)<>4 then
    halt(3);
  end;
  {$pop}

  { Case tw36156.pp }
  {$push}

  begin
writeln(hexstr(tw36156_gcfpdbgvaluesize.tw36156_size,16));
  writeln(tw36156_gcfpdbgvaluesize.tw36156_bitsize);
  if tw36156_gcfpdbgvaluesize.tw36156_size<>$7fffffff then
    halt(1);
  end;
  {$pop}

  { Case tw36934.pp }
  {$push}

  begin
tw36934_p1.tw36934_x:=1.0;
  tw36934_p1.tw36934_y:=2.0;
  tw36934_p2.tw36934_x:=3.0;
  tw36934_p2.tw36934_y:=4.0;
  tw36934_p3.tw36934_x:=5.0;
  tw36934_p3.tw36934_y:=6.0;
  tw36934_p4.tw36934_x:=7.0;
  tw36934_p4.tw36934_y:=8.0;
  tw36934_t1.tw36934_x:=9.0;
  tw36934_t1.tw36934_y:=10.0;
  tw36934_t2.tw36934_x:=11.0;
  tw36934_t2.tw36934_y:=12.0;
  tw36934_t3.tw36934_x:=13.0;
  tw36934_t3.tw36934_y:=14.0;
  tw36934_t4.tw36934_x:=15.0;
  tw36934_t4.tw36934_y:=16.0;
  tw36934_test(tw36934_p1,tw36934_p2,tw36934_p3,tw36934_p4,nil,tw36934_t1,tw36934_t2,tw36934_t3,tw36934_t4);
  end;
  {$pop}

  { Case tw36934a.pp }
  {$push}

  begin
tw36934a_p1.tw36934a_x:=1.0;
  tw36934a_p1.tw36934a_y:=2.0;
  tw36934a_p2.tw36934a_x:=3.0;
  tw36934a_p2.tw36934a_y:=4.0;
  tw36934a_p3.tw36934a_x:=5.0;
  tw36934a_p3.tw36934a_y:=6.0;
  tw36934a_p4.tw36934a_x:=7.0;
  tw36934a_p4.tw36934a_y:=8.0;
  tw36934a_t1.tw36934a_x:=9.0;
  tw36934a_t1.tw36934a_y:=10.0;
  tw36934a_t2.tw36934a_x:=11.0;
  tw36934a_t2.tw36934a_y:=12.0;
  tw36934a_t3.tw36934a_x:=13.0;
  tw36934a_t3.tw36934a_y:=14.0;
  tw36934a_t4.tw36934a_x:=15.0;
  tw36934a_t4.tw36934a_y:=16.0;
  tw36934a_test(tw36934a_p1,tw36934a_p2,tw36934a_p3,tw36934a_p4,nil,tw36934a_t1,tw36934a_t2,tw36934a_t3,tw36934a_t4);
  end;
  {$pop}

  { Case tw36934b.pp }
  {$push}

  begin
tw36934b_p1.tw36934b_x:=1.0;
  tw36934b_p1.tw36934b_y:=2.0;
  tw36934b_p1.tw36934b_z:=3.0;
  tw36934b_p1.tw36934b_u:=4.0;
  tw36934b_p1.tw36934b_v:=5.0;
  tw36934b_p2.tw36934b_x:=6.0;
  tw36934b_p2.tw36934b_y:=7.0;
  tw36934b_p2.tw36934b_z:=8.0;
  tw36934b_p2.tw36934b_u:=9.0;
  tw36934b_p2.tw36934b_v:=10.0;
  tw36934b_p3.tw36934b_x:=11.0;
  tw36934b_p3.tw36934b_y:=12.0;
  tw36934b_p3.tw36934b_z:=13.0;
  tw36934b_p3.tw36934b_u:=14.0;
  tw36934b_p3.tw36934b_v:=15.0;
  tw36934b_test(tw36934b_p1,tw36934b_p2,tw36934b_p3);
  end;
  {$pop}

  { Case tw37780.pp }
  {$push}

  begin
tw37780_tr.tw37780_val := 6;
  tw37780_tr.tw37780_next := nil;
  if (tw37780_tr.tw37780_val = 10) or ((tw37780_tr.tw37780_val = 5) and (tw37780_tr.tw37780_next^.tw37780_val = 5)) then
    Writeln('OK');
  end;
  {$pop}

  { Case tw40252.pp }
  {$push}

  begin
tw40252_debuglnstack(tw40252_le,'Test string');
  end;
  {$pop}

  { Case tw4104.pp }
  {$push}

  begin
tw4104_write_junk([1,2]);
  end;
  {$pop}

  { Case tw41460.pp }
  {$push}
{$T-}
  begin
{$ifndef SKIP_CONST_POINTER}
   tw41460_res := @(tw41460_precord(nil)^.tw41460_second) - @(tw41460_precord(nil)^.tw41460_first);
   writeln('Offset of Second field inside TRecord is ',tw41460_res);
   if (tw41460_res<2) then
     begin
       writeln('Offset of second field is smaller than size of first field');
       halt(1);
     end;
{$else SKIP_CONST_POINTER}
   tw41460_res:=2;
{$endif SKIP_CONST_POINTER}
   tw41460_res2 := @(tw41460_precord(@tw41460_rec)^.tw41460_second) - @(tw41460_precord(@tw41460_rec)^.tw41460_first);
   writeln('Offset of Second field inside TRecord is ',tw41460_res2);
   if (tw41460_res2<2) then
     begin
       writeln('Offset of second field is smaller than size of first field');
       halt(2);
     end;
   if (tw41460_res<>tw41460_res2) then
     begin
       writeln('Inconsistent results for Offset of second field between constant and non-constant pointers');
       halt(3);
     end;
   tw41460_res3 := @(tw41460_rec.tw41460_second) - @(tw41460_rec.tw41460_first);
   if (tw41460_res3<2) then
     begin
       writeln('Offset of second field is smaller than size of first field');
       halt(4);
     end;
   if (tw41460_res<>tw41460_res3) then
     begin
       writeln('Inconsistent results for Offset of second field between constant and non-constant pointers');
       halt(5);
     end;
  end;
  {$pop}

  { Case tw41460a.pp }
  {$push}
{$T+}
  begin
tw41460a_res := @(tw41460a_precord(@tw41460a_rec)^.tw41460a_second) - @(tw41460a_precord(@tw41460a_rec)^.tw41460a_first);
   writeln('Number of word fields between Second and First is ',tw41460a_res);
   if (tw41460a_res<>1) then
     begin
       writeln('Error in typed pointer arithmetics');
       halt(1);
     end;
   tw41460a_res_nil := @(tw41460a_precord(nil)^.tw41460a_second) - @(tw41460a_precord(nil)^.tw41460a_first);
   writeln('Number of word fields between Second and First is ',tw41460a_res_nil);
   if (tw41460a_res_nil<>1) then
     begin
       writeln('Error in constant typed pointer arithmetics');
       halt(2);
     end;
  end;
  {$pop}

end.
