{ Consolidated enumerations regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tcase2.pas }
{$push}
type
  tcase2_days = (tcase2_sun,tcase2_mon,tcase2_tue,tcase2_wed,tcase2_thu,tcase2_fri,tcase2_sat);
  tcase2_workdays = tcase2_mon..tcase2_fri;

procedure tcase2_t(tcase2_d: tcase2_workdays);
  begin
     case tcase2_d of
        tcase2_mon: writeln('monday');
        tcase2_thu: writeln('thursday');
     else
        writeln('error');
     end;
  end;

var
   tcase2_d: tcase2_workdays;


{$pop}

{ Case tenum1.pas }
{$push}
type
  tenum1_days = (tenum1_mon,tenum1_tue,tenum1_wed,tenum1_thu,tenum1_fri,tenum1_sat,tenum1_sun);
  tenum1_weekend = tenum1_sat..tenum1_sun;

procedure tenum1_t2(day: tenum1_weekend);
begin
  if day = tenum1_sat then
    writeln('ok')
  else writeln('error');
end;


{$pop}

{ Case tparray12.pas }
{$push}
{$packenum 2}
type
  tparray12_tenum = (tparray12_ea,tparray12_eb,tparray12_ec,tparray12_ed,tparray12_ee,tparray12_ef:=255);
  tparray12_tb = array[1..16] of byte;
const
  tparray12_res: array[1..6] of byte = (0,1,2,3,4,255);
var
  tparray12_a: bitpacked array[1..16] of tparray12_tenum;
  tparray12_i: longint;

{$pop}

{ Case tpushpop1.pas }
{$push}


type
{$MinEnumSize 1}
  tpushpop1_TTest1 = (tpushpop1_t1One, tpushpop1_t1Two, tpushpop1_t1Three);
{$push}
{$MinEnumSize 2}
  tpushpop1_TTest2 = (tpushpop1_t2One, tpushpop1_t2Two, tpushpop1_t2Three);
{$pop}
  tpushpop1_TTest3 = (tpushpop1_t3One, tpushpop1_t3Two, tpushpop1_t3Three);


{$pop}

{ Case tpushpop4.pas }
{$push}


type
{$MinEnumSize 1}
  tpushpop4_TTest1 = (tpushpop4_t1One, tpushpop4_t1Two, tpushpop4_t1Three);
{$pushopt}
{$MinEnumSize 2}
  tpushpop4_TTest2 = (tpushpop4_t2One, tpushpop4_t2Two, tpushpop4_t2Three);
{$popopt}
  tpushpop4_TTest3 = (tpushpop4_t3One, tpushpop4_t3Two, tpushpop4_t3Three);


{$pop}

begin

{ Case tcase2.pas }
{$push}

begin
   tcase2_d := tcase2_thu;
   tcase2_t(tcase2_d);
end;
{$pop}

{ Case tenum1.pas }
{$push}

begin
  tenum1_t2(tenum1_sat);
end;
{$pop}

{ Case tparray12.pas }
{$push}
{$packenum 2}
begin
  writeln(sizeof(tparray12_a));
  tparray12_a[1]:=tparray12_ea;
  tparray12_a[2]:=tparray12_eb;
  tparray12_a[3]:=tparray12_ec;
  tparray12_a[6]:=tparray12_ef;
  tparray12_a[5]:=tparray12_ee;
  tparray12_i:=4;
  tparray12_a[tparray12_i]:=tparray12_ed;
  for tparray12_i := 1 to 6 do
    begin writeln(tparray12_tb(tparray12_a)[tparray12_i]);
    if (tparray12_tb(tparray12_a)[tparray12_i] <> tparray12_res[tparray12_i]) then
      halt(1); end;
end;
{$pop}

{ Case tpushpop1.pas }
{$push}
{$MinEnumSize 1}
{$push}
{$MinEnumSize 2}
{$pop}
begin
  if SizeOf(tpushpop1_TTest1) <> 1 then
    Halt(1);
  if SizeOf(tpushpop1_TTest2) <> 2 then
    Halt(2);
  if SizeOf(tpushpop1_TTest3) <> 1 then
    Halt(3);
  Writeln('ok');
end;
{$pop}

{ Case tpushpop4.pas }
{$push}
{$MinEnumSize 1}
{$pushopt}
{$MinEnumSize 2}
{$popopt}
begin
  if SizeOf(tpushpop4_TTest1) <> 1 then
    Halt(1);
  if SizeOf(tpushpop4_TTest2) <> 2 then
    Halt(2);
  if SizeOf(tpushpop4_TTest3) <> 1 then
    Halt(3);
  Writeln('ok');
end;
{$pop}

end.
