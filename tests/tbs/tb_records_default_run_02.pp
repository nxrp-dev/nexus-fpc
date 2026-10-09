{ Records regression cases; original case IDs are retained below. }

{ Case tb0369.pp }
{$push}
type
  tb0369_ptchar=^tb0369_tchar;
  tb0369_tchar=packed record
    tb0369_c : char;
  end;

function tb0369_inl(l:tb0369_ptchar):tb0369_ptchar;
begin
  inc(l);
  tb0369_inl:=l;
end;

var
  tb0369_i : longint;
  tb0369_j : tb0369_ptchar;
  tb0369_s : string;
  tb0369_error : boolean;
{$pop}

{ Case tb0481.pp }
{$push}
type
  tb0481_trec = record
    tb0481_data : longint;
  end;
  tb0481_prec = ^tb0481_trec;
{$pop}

{ Case tb0490.pp }
{$push}
type
  tb0490_trecord = record
    tb0490_l : longint;
  end;

function tb0490_test : tb0490_trecord;
  begin
  end;

procedure tb0490_p(const c);
  begin
  end;
{$pop}

{ Case tb0498.pp }
{$push}
type
  tb0498_t1 = longint;

procedure tb0498_p(t3:word);
var
  tb0498_t2 : record
    tb0498_t1 : tb0498_t1;
end;
begin
  writeln(t3);
end;
{$pop}

{ Case tb0499.pp }
{$push}
var
  tb0499_e1     : byte;

procedure tb0499_p;
var
  tb0499_r : record
    tb0499_e : (tb0499_e1,e2);
  end;

begin
  tb0499_r.tb0499_e:=tb0499_e1;
end;
{$pop}

{ Case tb0612.pp }
{$push}
type
  tb0612_trec1 = record
    tb0612_l : longint;
    tb0612_b : byte;
  end;
  tb0612_prec1 = ^tb0612_trec1;

  tb0612_trec2 = packed record
    tb0612_a1 : array[0..3] of byte;
    tb0612_b : byte;
  end;
  tb0612_prec2 = ^tb0612_trec2;
{$pop}

{ Case tb0618.pp }
{$push}
type
     tb0618_pstreamrec= ^tb0618_tstreamrec;

     tb0618_tstreamrec = Packed Record
       tb0618_objtype : byte;
       tb0618_next : tb0618_pstreamrec;
     end;

const
   tb0618_baserec : tb0618_pstreamrec= nil;

   tb0618_rtype1 : tb0618_tstreamrec = (
    tb0618_objtype : 79
   );
   tb0618_rtype2 : tb0618_tstreamrec = (
    tb0618_objtype : 80
   );

procedure tb0618_registertype(var R : tb0618_tstreamrec);
var
  tb0618_p : tb0618_pstreamrec;

begin
  tb0618_p := tb0618_baserec;
  while (tb0618_p <> nil) and (tb0618_p^.tb0618_objtype <> R.tb0618_objtype) do
    tb0618_p:=tb0618_p^.tb0618_next;
  if not assigned(tb0618_p) then
    begin
      R.tb0618_next:=tb0618_baserec;
      tb0618_baserec:=@R;
    end;
  { nothing to do here
  else
    P:=@R; }
end;
{$pop}

{ Case tw0801.pp }
{$push}
type
  tw0801_precord = ^tw0801_trecord;
  tw0801_trecord = record
  end;
var
  tw0801_x: tw0801_precord;
{$pop}

{ Case tw1073.pp }
{$push}
type tw1073_char4=array[1..4] of char;
     tw1073_t1=packed record
      tw1073_a1:tw1073_char4;
      tw1073_a2:tw1073_char4;
      tw1073_a3:tw1073_char4;
     end;
     tw1073_pt2=^tw1073_t2;
     tw1073_t2=record
      tw1073_b1:tw1073_t1;
      tw1073_b2:tw1073_char4;
      tw1073_b3:longint;
     end;
     tw1073_t3=record
      tw1073_c1:tw1073_char4;
     end;

var tw1073_s1,tw1073_s2:String;

procedure tw1073_trifich(P1,P2,P3:string; tw1073_p4:boolean);
begin
  if tw1073_p4 then WriteLn(P2+P3+'IN '+P1);
end;

var tw1073_v1:tw1073_pt2;
    tw1073_v2:tw1073_t3;
{$pop}

{ Case tw1124.pp }
{$push}
Type
      tw1124_t1 = record
       tw1124_dummy:integer;
      end;
      tw1124_t2 = record
       tw1124_dummy:string;
      end;

operator = (i1,i2:tw1124_t1) r:boolean;
begin
end;

operator = (i1,i2:tw1124_t2) r:boolean;
begin
end;
{$pop}

{ Case tw1132.pp }
{$push}
type
   tw1132_myrecordtype =
   record
      tw1132_recordelement1 : word;
      tw1132_recordelement2 : word;
   end;

var
   tw1132_myrecord : tw1132_myrecordtype;
   tw1132_mypointer1,tw1132_mypointer2 : pointer;
{$pop}

{ Case tw1223.pp }
{$push}
{ Source provided for Free Pascal Bug Report 1223 }
{ Submitted by "Denis Yarkovoy" on  2000-11-03 }
{ e-mail: gunky9@geocities.com }
 Type
      tw1223_tpoint = record
       tw1223_x, tw1223_y : integer;
      end;

 operator + (const p1, p2:tw1223_tpoint) p : tw1223_tpoint;
 begin
  p.tw1223_x:=p1.tw1223_x+p2.tw1223_x;
  p.tw1223_y:=p1.tw1223_y+p2.tw1223_y;
 end;

 var tw1223_d,tw1223_d1:tw1223_tpoint;
{$pop}

begin
  { Case tb0369.pp }
  {$push}

  begin
tb0369_error:=false;
  tb0369_s:='012345789';
  tb0369_j:=@tb0369_s[1];
  for tb0369_i:=1to 8 do
   begin
     writeln(tb0369_inl(tb0369_j)^.tb0369_c);
     If (tb0369_inl(tb0369_j)^.tb0369_c<>tb0369_s[tb0369_i+1]) Then
      tb0369_error:=true;
     inc(tb0369_j);
   end;
  if tb0369_error then
   begin
     writeln('Error!');
     halt(1);
   end;
  end;
  {$pop}

  { Case tb0481.pp }
  {$push}

  begin
writeln(longint(@tb0481_prec(0)^.tb0481_data));
  end;
  {$pop}

  { Case tb0490.pp }
  {$push}

  begin
tb0490_p(tb0490_test);
  end;
  {$pop}

  { Case tb0498.pp }
  {$push}

  begin
tb0498_p(10);
  end;
  {$pop}

  { Case tb0612.pp }
  {$push}

  begin
if ptruint(@tb0612_trec1(nil^).tb0612_b)<>4 then
    halt(1);
  if ptruint(@tb0612_prec1(nil)^.tb0612_b)<>4 then
    halt(2);
  if ptruint(@tb0612_trec2(nil^).tb0612_b)<>4 then
    halt(3);
  if ptruint(@tb0612_prec2(nil)^.tb0612_b)<>4 then
    halt(4);
  end;
  {$pop}

  { Case tb0618.pp }
  {$push}

  begin
tb0618_registertype(tb0618_rtype1);
  tb0618_registertype(tb0618_rtype2);
  end;
  {$pop}

  { Case tw0801.pp }
  {$push}

  begin
New(tw0801_x);
  Dispose(tw0801_x);
  end;
  {$pop}

  { Case tw1073.pp }
  {$push}

  begin
new(tw1073_v1);
  tw1073_s1 := 'abc';
  tw1073_s2 := 'def';
  with  tw1073_v1^ do
    begin
      tw1073_b1.tw1073_a1 := '1234';
      tw1073_b1.tw1073_a2 := '5678';
      tw1073_b1.tw1073_a3 := 'ghij';
      tw1073_b2 := '0000';
      tw1073_b3 := longint(tw1073_char4('9999'));
    end;
  tw1073_v2.tw1073_c1 := 'wxyz';
  tw1073_trifich(tw1073_s1+tw1073_s2,
          tw1073_v1^.tw1073_b1.tw1073_a1+tw1073_v1^.tw1073_b1.tw1073_a2+tw1073_v1^.tw1073_b1.tw1073_a3+tw1073_v1^.tw1073_b2+tw1073_char4(tw1073_v1^.tw1073_b3)+#13#10,
          tw1073_v1^.tw1073_b1.tw1073_a1+tw1073_v1^.tw1073_b1.tw1073_a2+tw1073_v1^.tw1073_b1.tw1073_a3+tw1073_v2.tw1073_c1+tw1073_char4(tw1073_v1^.tw1073_b3)+#13#10,true);
  end;
  {$pop}

  { Case tw1132.pp }
  {$push}

  begin
with tw1132_myrecord do
   begin
      { next statement crashes the compiler }
      tw1132_mypointer1 := addr(tw1132_recordelement2);

      { next statement is OK }
      tw1132_mypointer2 := addr(tw1132_myrecord.tw1132_recordelement2);
   end;
  if tw1132_mypointer1<>tw1132_mypointer2 then
   begin
     Writeln('Error with addr() and with statement');
     halt(1);
   end;
  end;
  {$pop}

  { Case tw1223.pp }
  {$push}

  begin
tw1223_d.tw1223_x:=5;tw1223_d.tw1223_y:=34;
  tw1223_d1.tw1223_x:=6;tw1223_d1.tw1223_y:=-50;
  tw1223_d:=tw1223_d+tw1223_d1;
  if (tw1223_d.tw1223_x<>11) or (tw1223_d.tw1223_y<>-16) then
    begin
      Writeln('Error is operator overloading');
      Halt(1);
    end
  else
    Writeln('Operator overloading works correctly');
  end;
  {$pop}

end.
