{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode fpc}


{ Source group: tb_records_default_run_02.pp }
{$push}

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


{$pop}

{ Source group: tb_records_default_run_03.pp }
{$push}

{ Case tw15357.pp }
{$push}
type
  tw15357_ttype = packed record
    tw15357_a: byte;
    tw15357_b: byte;
    tw15357_c: longword;
  end;

  tw15357_ttypecontainer = packed record
    tw15357_r: tw15357_ttype;
    tw15357_b1,tw15357_b2: byte;
  end;

function tw15357_make: tw15357_ttype;
begin
  tw15357_make.tw15357_a:=1;
  tw15357_make.tw15357_b:=2;
  tw15357_make.tw15357_c:=$12345678;
end;

var
  tw15357_id: tw15357_ttypecontainer;
{$pop}

{ Case tw1850.pp }
{$push}
{ Source provided for Free Pascal Bug Report 1850 }
{ Submitted by "Sebastian Günther" on  2002-03-06 }
{ e-mail: sg@freepascal.org }
type
  tw1850_tmyrecord = record
    tw1850_a, tw1850_b: Integer;
  end;
var
  tw1850_r: tw1850_tmyrecord;
{$pop}

{ Case tw1915.pp }
{$push}
{
    This program demonstrates a set inclusion test bug.
    (After two days passed to track down a very perverse program error....)
    (By Louis Jean-Ruichard)
}
TYPE
    tw1915_eattr   = ( e0, e1, e2, e3, e4, e5, e6, e7 );
    tw1915_entityp = ^tw1915_entity;
    tw1915_entity  =
            RECORD
                tw1915_attr    : SET OF tw1915_eattr;
            END;
VAR
    tw1915_ep  : tw1915_entityp;
    tw1915_e   : tw1915_entity;
{$pop}

{ Case tw2758.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2758 }
{ Submitted by "marco" on  2003-10-31 }
{ e-mail:  }
Type
  tw2758_sigcontextrec=record end;
  tw2758_signalhandler   = Procedure(Sig : Longint);cdecl;
  tw2758_psignalhandler  = ^tw2758_signalhandler;
  tw2758_tsigaction = procedure(Sig: Longint; tw2758_sigcontext: tw2758_sigcontextrec);cdecl;

tw2758_sigactionrec = packed record  // this is temporary for the migration
    tw2758_sa_handler : tw2758_signalhandler;
  end;

procedure tw2758_signaltorunerror(Sig: Longint; tw2758_sigcontext: tw2758_sigcontextrec);cdecl;
begin end;  // tsigaction style

var tw2758_r : tw2758_sigactionrec;
{$pop}

{ Case tw27634.pp }
{$push}
type
  tw27634_mbhelpptr = pointer;
  tw27634_menurecord = record end;
  tw27634_menuitemsptr = pointer;
  tw27634_menuiconhandle = pointer;
  tw27634_menuref = pointer;
  tw27634_int16 = word;
  tw27634_int32 = longint;
  tw27634_osstatus = tw27634_int32;
  tw27634_str255 = ShortString;

 function tw27634_macmenuadditeminternal
        ( var tw27634_themenurecord           : tw27634_menurecord;
              tw27634_themenuorsubmenuid      : tw27634_int32;
              tw27634_theoptbeforeitemindex   : tw27634_int32;
          var tw27634_themenuref              : tw27634_menuref;
          var tw27634_theitemsptr             : tw27634_menuitemsptr;
        const tw27634_theitemstr              : tw27634_str255;
              tw27634_theitemiconhandle       : tw27634_menuiconhandle;
              tw27634_theenableflag           : boolean;
              tw27634_thecheckflag            : boolean;
              tw27634_thecommandchar          : char;
              tw27634_thecommandmodifiers     : tw27634_int16;
              tw27634_theitemcmdid            : tw27634_int32;
        const tw27634_theitemappstr           : AnsiString;
          var tw27634_thenewitemindex         : tw27634_int32): tw27634_osstatus;
begin
end;

 function tw27634_mbmenuadditeminternal
        ( var tw27634_themenurecord           : tw27634_menurecord;
              tw27634_themenuorsubmenuid      : tw27634_int32;
              tw27634_theoptbeforeitemindex   : tw27634_int32;
          var tw27634_themenuref              : tw27634_menuref;
          var tw27634_theitemsptr             : tw27634_menuitemsptr;
        const tw27634_theitemstr              : tw27634_str255;
              tw27634_theitemiconhandle       : tw27634_menuiconhandle;
              tw27634_theenableflag           : boolean;
              tw27634_thecheckflag            : boolean;
              tw27634_thecommandchar          : char;
              tw27634_thecommandglyph         : tw27634_int16; { unused here }
              tw27634_thecommandmodifiers     : tw27634_int16;
              tw27634_theitemcmdid            : tw27634_int32;
        const tw27634_theitemappstr           : AnsiString;
              tw27634_theitemhelpptr          : tw27634_mbhelpptr; { unused here }
          var tw27634_thenewitemindex         : tw27634_int32): tw27634_osstatus;
      var
        tw27634_theerr                        : tw27634_osstatus;
    begin
      tw27634_theitemsptr                     := nil;
      tw27634_thenewitemindex                 := 0;
      tw27634_theerr                          := tw27634_macmenuadditeminternal
        ( tw27634_themenurecord, tw27634_themenuorsubmenuid, tw27634_theoptbeforeitemindex, tw27634_themenuref, tw27634_theitemsptr,
          tw27634_theitemstr, tw27634_theitemiconhandle, tw27634_theenableflag, tw27634_thecheckflag, tw27634_thecommandchar,
          tw27634_thecommandmodifiers, tw27634_theitemcmdid, tw27634_theitemappstr, tw27634_thenewitemindex);
      tw27634_mbmenuadditeminternal           := tw27634_theerr
    end;

var
  tw27634_themenurecord: tw27634_menurecord;
  tw27634_themenuref: tw27634_menuref;
  tw27634_theitemsptr: tw27634_menuitemsptr;
  tw27634_thenewitemindex: tw27634_int32;
{$pop}

{ Case tw28007.pp }
{$push}
type

  tw28007_tpackedbool = bitpacked record
    tw28007_b0: Boolean;
    tw28007_b1: Boolean;
    tw28007_b2: Boolean;
    tw28007_b3: Boolean;
    tw28007_b4: Boolean;
    tw28007_b5: Boolean;
    tw28007_b6: Boolean;
    tw28007_b7: Boolean;
  end;

var
  tw28007_b: ByteBool;
  tw28007_packedbool: tw28007_tpackedbool;
{$pop}

{ Case tw28927.pp }
{$push}
type
  tw28927_trecord1 = record
  end align 16;

  tw28927_trecord2 = record
  end align 8;

  tw28927_trecord3 = record
  end align 4;

  tw28927_trecord1outer = record
    tw28927_b : Byte;
    tw28927_record1 : tw28927_trecord1;
  end;

  tw28927_trecord2outer = record
    tw28927_b : Byte;
    tw28927_record2 : tw28927_trecord2;
  end;

  tw28927_trecord3outer = record
    tw28927_b : Byte;
    tw28927_record3 : tw28927_trecord3;
  end;

var
  tw28927_record1outer : tw28927_trecord1outer;
  tw28927_record2outer : tw28927_trecord2outer;
  tw28927_record3outer : tw28927_trecord3outer;
{$pop}

{ Case tw2976.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2976 }
{ Submitted by "Soeren Haastrup" on  2004-02-17 }
{ e-mail: haastrupsoeren@hotmail.com }
Type tw2976_vector=array[1..2] of double;

     tw2976_pair=record
           tw2976_v1:double;
           tw2976_v2:tw2976_vector;
          end;

operator := (tw2976_x:shortint) r:tw2976_pair;
var tw2976_i:longint;
Begin
    r.tw2976_v1:=tw2976_x;
    for tw2976_i:=1 to 2 do r.tw2976_v2[tw2976_i]:=0;
End;

operator := (tw2976_x:double) r:tw2976_pair;
var tw2976_i:longint;
Begin
    r.tw2976_v1:=tw2976_x;
    for tw2976_i:=1 to 2 do r.tw2976_v2[tw2976_i]:=0;
End;

{
operator + (x:double;p:pair) r:pair; // Marked
var i:longint;
Begin
 r.v1:=x+p.v1;
 for i:=1 to 2 do r.v2[i]:=p.v2[i];
End;
}

operator + (p:tw2976_pair;tw2976_x:double) r:tw2976_pair;
var tw2976_i:longint;
Begin
 r.tw2976_v1:=p.tw2976_v1+tw2976_x;
 for tw2976_i:=1 to 2 do r.tw2976_v2[tw2976_i]:=p.tw2976_v2[tw2976_i];
End;

operator + (p1,p2:tw2976_pair) r:tw2976_pair;
var tw2976_i:longint;
Begin
 r.tw2976_v1:=p1.tw2976_v1+p2.tw2976_v1;
 for tw2976_i:=1 to 2 do r.tw2976_v2[tw2976_i]:=p1.tw2976_v2[tw2976_i]+p2.tw2976_v2[tw2976_i];
End;

var tw2976_a,tw2976_b:tw2976_pair;
{$pop}

{ Case tw30208.pp }
{$push}
var tw30208_r: bitpacked record
    tw30208_a, tw30208_b: boolean;
    end;
{$pop}

{ Case tw30240.pp }
{$push}
type
  tw30240_ttestcase = record
    tw30240_group: char;
    tw30240_dividend, tw30240_divider: int64;   // source
    tw30240_quotient, tw30240_remainder: int64; // expected result
  end;

const
  tw30240_test_cases: array [0..40] of tw30240_ttestcase =(
    // #30240
    ( tw30240_group:'-'; tw30240_dividend: 2000000000000; tw30240_divider: 2000000000001; tw30240_quotient: 0; tw30240_remainder: 2000000000000 ),
    //.Lbig_divisor (with carry at the end)
    ( tw30240_group:'a'; tw30240_dividend: 8375316585208858139; tw30240_divider:-7333902439715991;    tw30240_quotient:-1141;      tw30240_remainder: 7333901492912408 ),
    ( tw30240_group:'a'; tw30240_dividend: 7056323922322693051; tw30240_divider:-2740063521509;       tw30240_quotient:-2575240;   tw30240_remainder: 2739191855891 ),
    ( tw30240_group:'a'; tw30240_dividend: 8271196811549967915; tw30240_divider: 25285028838;         tw30240_quotient: 327118345; tw30240_remainder: 24786134805 ),
    ( tw30240_group:'a'; tw30240_dividend: 3431221233848454052; tw30240_divider:-3431221234088342633; tw30240_quotient: 0;         tw30240_remainder: 3431221233848454052 ),
    ( tw30240_group:'a'; tw30240_dividend:-8585295120939781742; tw30240_divider:-23751612046;         tw30240_quotient: 361461575; tw30240_remainder:-22003649292 ),
    ( tw30240_group:'a'; tw30240_dividend:-6683243686137656212; tw30240_divider: 40354827467772;      tw30240_quotient:-165611;    tw30240_remainder:-40354372467520 ),
    ( tw30240_group:'a'; tw30240_dividend:-6963003432881308676; tw30240_divider:-1740750858595018939; tw30240_quotient: 3;         tw30240_remainder:-1740750857096251859 ),
    ( tw30240_group:'a'; tw30240_dividend: 3589102502730131736; tw30240_divider: 2718092484398;       tw30240_quotient: 1320448;   tw30240_remainder: 2717891761432 ),
    ( tw30240_group:'a'; tw30240_dividend:-9069664486668623813; tw30240_divider:-177626955280;        tw30240_quotient: 51060180;  tw30240_remainder:-177219873413 ),
    ( tw30240_group:'a'; tw30240_dividend:-8708789282907437996; tw30240_divider:-280928686587236007;  tw30240_quotient: 30;        tw30240_remainder:-280928685290357786 ),
    //.Lbig_divisor (without carry)
    ( tw30240_group:'b'; tw30240_dividend:-5478163896315828857; tw30240_divider:-9281215814;          tw30240_quotient: 590242055; tw30240_remainder:-1361971087 ),
    ( tw30240_group:'b'; tw30240_dividend: 7101201960831283575; tw30240_divider: 9474016311;          tw30240_quotient: 749545042; tw30240_remainder: 7094103513 ),
    ( tw30240_group:'b'; tw30240_dividend: 3960011864586540874; tw30240_divider:-2123266079007095486; tw30240_quotient:-1;         tw30240_remainder: 1836745785579445388 ),
    ( tw30240_group:'b'; tw30240_dividend: 6707823169352057382; tw30240_divider:-7764081918;          tw30240_quotient:-863955743; tw30240_remainder: 7173502308 ),
    ( tw30240_group:'b'; tw30240_dividend: 5698168712416449358; tw30240_divider: 4542747269964;       tw30240_quotient: 1254344;   tw30240_remainder: 930820725742 ),
    ( tw30240_group:'b'; tw30240_dividend: 3759351913822964708; tw30240_divider:-56344208198167;      tw30240_quotient:-66721;     tw30240_remainder: 9998633064301 ),
    ( tw30240_group:'b'; tw30240_dividend:-7764588773457981677; tw30240_divider: 27146308080993374;   tw30240_quotient:-286;       tw30240_remainder:-744662293876713 ),
    ( tw30240_group:'b'; tw30240_dividend:-5098584499810065147; tw30240_divider:-1033450244405508;    tw30240_quotient: 4933;      tw30240_remainder:-574444157694183 ),
    ( tw30240_group:'b'; tw30240_dividend: 7767592121360637078; tw30240_divider:-2706907408679000905; tw30240_quotient:-2;         tw30240_remainder: 2353777304002635268 ),
    ( tw30240_group:'b'; tw30240_dividend: 3900260326859439920; tw30240_divider:-4529352981664096387; tw30240_quotient: 0;         tw30240_remainder: 3900260326859439920 ),
    //.Ltwo_divs
    ( tw30240_group:'c'; tw30240_dividend:-3189721586398362144; tw30240_divider:-477575983;  tw30240_quotient: 6678982402;    tw30240_remainder:-323510978 ),
    ( tw30240_group:'c'; tw30240_dividend:-6272627659376899240; tw30240_divider:-365611917;  tw30240_quotient: 17156518613;   tw30240_remainder:-231788119 ),
    ( tw30240_group:'c'; tw30240_dividend: 8347107135342446860; tw30240_divider: 1114829022; tw30240_quotient: 7487342875;    tw30240_remainder: 627528610 ),
    ( tw30240_group:'c'; tw30240_dividend: 7002068931434460610; tw30240_divider: 404820846;  tw30240_quotient: 17296710385;   tw30240_remainder: 361774900 ),
    ( tw30240_group:'c'; tw30240_dividend: 8293431318282107842; tw30240_divider:-718398042;  tw30240_quotient:-11544340092;   tw30240_remainder: 7207978 ),
    ( tw30240_group:'c'; tw30240_dividend:-6808260689000200821; tw30240_divider:-1501534265; tw30240_quotient: 4534202680;    tw30240_remainder:-525370621 ),
    ( tw30240_group:'c'; tw30240_dividend: 7674745939185655069; tw30240_divider:-1699384892; tw30240_quotient:-4516190520;    tw30240_remainder: 104031229 ),
    ( tw30240_group:'c'; tw30240_dividend: 6431190513421618316; tw30240_divider: 3333080;    tw30240_quotient: 1929503796315; tw30240_remainder: 18116 ),
    ( tw30240_group:'c'; tw30240_dividend: 2124140687535160173; tw30240_divider: 37711397;   tw30240_quotient: 56326226459;   tw30240_remainder: 27906950 ),
    ( tw30240_group:'c'; tw30240_dividend:-3811970536696094994; tw30240_divider:-43355849;   tw30240_quotient: 87922866801;   tw30240_remainder:-24825945 ),
    // one division
    ( tw30240_group:'d'; tw30240_dividend:-569298819287740717;  tw30240_divider: 623930358;  tw30240_quotient:-912439684;  tw30240_remainder:-596213845 ),
    ( tw30240_group:'d'; tw30240_dividend: 990400595808799715;  tw30240_divider:-1625588531; tw30240_quotient:-609256633;  tw30240_remainder: 768323592 ),
    ( tw30240_group:'d'; tw30240_dividend:-580252789917085737;  tw30240_divider:-354226044;  tw30240_quotient: 1638086187; tw30240_remainder:-165031509 ),
    ( tw30240_group:'d'; tw30240_dividend: 1933675428811294466; tw30240_divider: 1189844258; tw30240_quotient: 1625150027; tw30240_remainder: 796799500 ),
    ( tw30240_group:'d'; tw30240_dividend: 548675153951135484;  tw30240_divider:-335038546;  tw30240_quotient:-1637647848; tw30240_remainder: 97186476 ),
    ( tw30240_group:'d'; tw30240_dividend:-844891682720642266;  tw30240_divider: 1058118666; tw30240_quotient:-798484810;  tw30240_remainder:-742178806 ),
    ( tw30240_group:'d'; tw30240_dividend:-759434744728515761;  tw30240_divider:-733407613;  tw30240_quotient: 1035487948; tw30240_remainder:-495567637 ),
    ( tw30240_group:'d'; tw30240_dividend: 13655828961120164;   tw30240_divider: 15582697;   tw30240_quotient: 876345664;  tw30240_remainder: 11744356 ),
    ( tw30240_group:'d'; tw30240_dividend: 14609195521567996;   tw30240_divider:-38440672;   tw30240_quotient:-380045268;  tw30240_remainder: 29227900 ),
    ( tw30240_group:'d'; tw30240_dividend:-402022804788005296;  tw30240_divider:-254071284;  tw30240_quotient: 1582322875; tw30240_remainder:-234183796 )
  );

var
  tw30240_i, tw30240_errors: integer;
  tw30240_vq, tw30240_vr: int64;
{$pop}

{ Case tw3064.pp }
{$push}
type
  tw3064_r1 = packed record
    tw3064_b : byte;
    tw3064_l : longint;
  end;

  tw3064_r2 = record
    tw3064_b : byte;
    tw3064_l : longint;
  end;

 {$a-}
  tw3064_r3 = record
    tw3064_b : byte;
    tw3064_l : longint;
  end;

 {$a+}
  tw3064_r4 = record
    tw3064_b : byte;
    tw3064_l : longint;
  end;
{$pop}

{ Case tw32811.pp }
{$push}
type
  tw32811_pnode = ^tw32811_node;
  tw32811_node = record
    tw32811_i: integer;
    tw32811_left: tw32811_pnode;
    tw32811_right: tw32811_pnode;
  end;

procedure tw32811_insert(var t: tw32811_pnode; tw32811_i: integer);
begin
  if t = nil then
    begin
      new(t);
      t^.tw32811_i := tw32811_i;
      t^.tw32811_left := nil;
      t^.tw32811_right := nil;
    end
  else
    if tw32811_i < t^.tw32811_i
      then tw32811_insert(t^.tw32811_left, tw32811_i)
      else tw32811_insert(t^.tw32811_right, tw32811_i);
end;
{$pop}


{$pop}

{ Source group: tb_records_default_run_04.pp }
{$push}

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


{$pop}

{ Source group: tb_records_default_run_05.pp }
{$push}

{ Case tw41460c.pp }
{$push}
{$T-}
{ In T- mode, i.e. not in typed pointer mode,
  the difference between two pointers of the same type
  is divided by number of bytes between the two pointers }

type
   tw41460c_trecord = record
     tw41460c_first: word;
     tw41460c_second: qword;
   end;
   tw41460c_precord = ^tw41460c_trecord;

var
   tw41460c_res,tw41460c_res2 : PtrInt;
   tw41460c_rec : tw41460c_trecord;
{$pop}

{ Case tw41460d.pp }
{$push}
{$T-}

type
   tw41460d_trecord = record
     tw41460d_first: byte;
     tw41460d_second: byte;
     tw41460d_third: byte;
     tw41460d_fourth: byte;
   end;
   tw41460d_precord = ^tw41460d_trecord;

var
   tw41460d_res, tw41460d_res2, tw41460d_res3 : PtrInt;
   tw41460d_rec : tw41460d_trecord;
{$pop}

{ Case tw41743.pp }
{$push}
type
  tw41743_trecord = record
    tw41743_w1,tw41743_w2,tw41743_w3,tw41743_w4 : word;
  end;

var
  tw41743_w1 : word;
  tw41743_b1 : byte;
  tw41743_rec : tw41743_trecord;
  tw41743_errorcount : longint;
{$pop}

{ Case tw4624.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4624 }
{ Submitted by "benoit sanchez" on  2005-12-20 }
{ e-mail: sanchez@clipper.ens.fr }
type tw4624_number=record
  tw4624_value:boolean;
end;

operator div (tw4624_a,b:tw4624_number) c:tw4624_number;
begin
  c.tw4624_value:=true;
end;

var tw4624_a:tw4624_number;
{$pop}


{$pop}

begin
  { Source group: tb_records_default_run_02.pp }
  {$push}


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


end;
  {$pop}

  { Source group: tb_records_default_run_03.pp }
  {$push}


begin
  { Case tw15357.pp }
  {$push}

  begin
tw15357_id.tw15357_b1:=123;
  tw15357_id.tw15357_b2:=234;
  tw15357_id.tw15357_r := tw15357_make();
  if tw15357_id.tw15357_r.tw15357_a<>1 then
    halt(1);
  if tw15357_id.tw15357_r.tw15357_b<>2 then
    halt(2);
  if tw15357_id.tw15357_r.tw15357_c<>$12345678 then
    halt(3);
  if tw15357_id.tw15357_b1<>123 then
    halt(4);
  if tw15357_id.tw15357_b2<>234 then
    halt(5);
  end;
  {$pop}

  { Case tw1850.pp }
  {$push}

  begin
with tw1850_r do;
  end;
  {$pop}

  { Case tw1915.pp }
  {$push}

  begin
tw1915_e.tw1915_attr:=[e2,e4,e7,e1,e0];
    WITH tw1915_e DO
            IF ([e1,e0] <= tw1915_attr)
            THEN Writeln('A1: [e1,e0] is included in attr')
    ;
    New(tw1915_ep);
    tw1915_ep^.tw1915_attr:=[e2,e4,e7,e1,e0];
    WITH tw1915_ep^ DO
            IF ([e1,e0] <= tw1915_attr)
            THEN Writeln('A2: [e1,e0] is included in attr')
            ELSE
             begin
              Writeln('A2 statement incorrectly executed');
              Halt(1);
             end;
    ;
  end;
  {$pop}

  { Case tw2758.pp }
  {$push}

  begin
tw2758_r.tw2758_sa_handler:=tw2758_signalhandler(@tw2758_signaltorunerror);
  end;
  {$pop}

  { Case tw27634.pp }
  {$push}

  begin
tw27634_mbmenuadditeminternal(tw27634_themenurecord,1,2,tw27634_themenuref,tw27634_theitemsptr,'abc',nil,true,false,'b',3,4,5,'def',nil,tw27634_thenewitemindex);
  end;
  {$pop}

  { Case tw28007.pp }
  {$push}

  begin
(*
    - OK on x86, x86_64 compiler
    - ERROR on cross arm compiler
    - OK on cross arm compiler if we do typecast:
        B := ByteBool(PackedBool.b0);
                                                    *)

  tw28007_b := tw28007_packedbool.tw28007_b0;
  end;
  {$pop}

  { Case tw28927.pp }
  {$push}

  begin
if PtrUInt(@tw28927_record1outer.tw28927_record1) mod 16<>0 then
    halt(1);
  if PtrUInt(@tw28927_record2outer.tw28927_record2) mod 8<>0 then
    halt(2);
  if PtrUInt(@tw28927_record3outer.tw28927_record3) mod 4<>0 then
    halt(3);
  writeln('ok');
  end;
  {$pop}

  { Case tw2976.pp }
  {$push}

  begin
//main

tw2976_a:=2;            //ok
tw2976_b:=tw2976_a+tw2976_a;          //ok
tw2976_a:=2+tw2976_b;          // ups?
  end;
  {$pop}

  { Case tw30208.pp }
  {$push}

  begin
tw30208_r.tw30208_a := true;
    tw30208_r.tw30208_b := false;
    if not tw30208_r.tw30208_b then
      writeln('ok')
    else
      halt(1);
  end;
  {$pop}

  { Case tw30240.pp }
  {$push}

  begin
tw30240_errors := 0;
  for tw30240_i := low(tw30240_test_cases) to high(tw30240_test_cases) do
    begin
      tw30240_vq := tw30240_test_cases[tw30240_i].tw30240_dividend div tw30240_test_cases[tw30240_i].tw30240_divider;
      tw30240_vr := tw30240_test_cases[tw30240_i].tw30240_dividend mod tw30240_test_cases[tw30240_i].tw30240_divider;
      if tw30240_vq*tw30240_test_cases[tw30240_i].tw30240_divider+tw30240_vr=tw30240_test_cases[tw30240_i].tw30240_dividend then
        if tw30240_vq=tw30240_test_cases[tw30240_i].tw30240_quotient then
          if tw30240_vr=tw30240_test_cases[tw30240_i].tw30240_remainder then
            continue;
      inc(tw30240_errors);
      writeln('Error [',tw30240_test_cases[tw30240_i].tw30240_group,']: ',tw30240_test_cases[tw30240_i].tw30240_dividend,'/',tw30240_test_cases[tw30240_i].tw30240_divider);
      writeln('  q=',tw30240_vq,' r=',tw30240_vr);
      writeln('  expected q=',tw30240_test_cases[tw30240_i].tw30240_quotient,' r=',tw30240_test_cases[tw30240_i].tw30240_remainder);
    end;
  if tw30240_errors=0 then
    writeln('Pass')
  else
    begin
      writeln('Fail (',tw30240_errors,' errors)');
      halt(1);
    end;
  end;
  {$pop}

  { Case tw3064.pp }
  {$push}
{$a-}
{$a+}
  begin
if (sizeof(tw3064_r1)<>sizeof(tw3064_r3)) or (sizeof(tw3064_r2)<>sizeof(tw3064_r4)) then
    halt(1);
  writeln('ok');
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_records_default_run_04.pp }
  {$push}


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


end;
  {$pop}

  { Source group: tb_records_default_run_05.pp }
  {$push}


begin
  { Case tw41460c.pp }
  {$push}
{$T-}
  begin
tw41460c_res := @(tw41460c_precord(@tw41460c_rec)^.tw41460c_second) - @(tw41460c_precord(@tw41460c_rec)^.tw41460c_first);
   writeln('Offset of Second field inside TRecord is ',tw41460c_res);
   if (tw41460c_res<2) then
     begin
       writeln('Offset of second field is smaller than size of first field');
       halt(1);
     end;
   tw41460c_res2 := @(tw41460c_precord(nil)^.tw41460c_second) - @(tw41460c_precord(nil)^.tw41460c_first);
   writeln('Offset of Second field inside TRecord  using constant pointers is ',tw41460c_res2);
   if (tw41460c_res2<2) then
     begin
       writeln('Offset of second field is smaller than size of first field');
       halt(2);
     end;
   if (tw41460c_res2<>tw41460c_res) then
     begin
       writeln('Inconsistent result for offset of second field');
       halt(3);
     end;
  end;
  {$pop}

  { Case tw41460d.pp }
  {$push}
{$T-}
  begin
tw41460d_res := @(tw41460d_precord(nil)^.tw41460d_fourth) - @(tw41460d_precord(nil)^.tw41460d_first);
   writeln('Offset of Fourth field inside TRecord is ',tw41460d_res);
   if (tw41460d_res<3) then
     begin
       writeln('Offset of Fourth field is smaller than size of first field');
       halt(1);
     end;
   tw41460d_res2 := @(tw41460d_precord(@tw41460d_rec)^.tw41460d_fourth) - @(tw41460d_precord(@tw41460d_rec)^.tw41460d_first);
   writeln('Offset of Fourth field inside TRecord is ',tw41460d_res2);
   if (tw41460d_res2<3) then
     begin
       writeln('Offset of Fourth field is smaller than size of first field');
       halt(2);
     end;
   if (tw41460d_res<>tw41460d_res2) then
     begin
       writeln('Inconsistent results for Offset of Fourth field between constant and non-constant pointers');
       halt(3);
     end;
   tw41460d_res3 := @(tw41460d_rec.tw41460d_fourth) - @(tw41460d_rec.tw41460d_first);
   if (tw41460d_res3<3) then
     begin
       writeln('Offset of Fourth field is smaller than size of first field');
       halt(4);
     end;
   if (tw41460d_res<>tw41460d_res3) then
     begin
       writeln('Inconsistent results for Offset of Fourth field between constant and non-constant pointers');
       halt(5);
     end;
  end;
  {$pop}

  { Case tw41743.pp }
  {$push}

  begin
tw41743_errorcount:=0;
  tw41743_b1:=$57;
  tw41743_w1:=$2D57;
  tw41743_rec.tw41743_w1:=tw41743_w1;
  if (byte(tw41743_rec.tw41743_w1)<>tw41743_b1) then
    inc(tw41743_errorcount,3);
  if (tw41743_rec.tw41743_w1=tw41743_b1) then
    inc(tw41743_errorcount,4);
  halt(tw41743_errorcount);
  end;
  {$pop}

  { Case tw4624.pp }
  {$push}

  begin
tw4624_a:=tw4624_a div tw4624_a;
  end;
  {$pop}


end;
  {$pop}

end.
