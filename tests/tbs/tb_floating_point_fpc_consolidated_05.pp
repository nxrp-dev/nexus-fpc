{ Consolidated floating point regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}
uses math;

{ Case tb_floating_point_fpc_consolidated_03.pp }
{$push}
{ Consolidated floating point regressions; original case IDs and assertions are retained. }




{ Case tb0591.pp }
{$push}




procedure tb0591_TestValue(aActual, aExpected: Double);
begin
  if not SameValue(aActual, aExpected) then
    Halt(1);
end;

const
  tb0591_f1 = 2.;
  tb0591_f2 = 2.e10;
  tb0591_f3 = 2.e-10;
  tb0591_f4 = 2.e+10;
  tb0591_f5 = 2.8e10; // ensure that scanning of normal floating points is not broken


{$pop}

{ Case tw16315a.pp }
{$push}


var
  tw16315a_D: Double;

{$pop}

{ Case tw17714.pp }
{$push}


var
  tw17714_l: longint;
  tw17714_c: cardinal;
  tw17714_i: int64;
  tw17714_q: qword;
  tw17714_s: single;
  tw17714_d: double;

{$pop}

{ Case tw1792a.pp }
{$push}

var
  tw1792a_s : string;

{$pop}

{ Case tw2891.pp }
{$push}


 var
 tw2891_d: Double;
 tw2891_e: Extended;

 
{$pop}


{$pop}

{ Case tnaninf.pp }
{$push}


procedure tnaninf_DoTestSingle;
var
  val: Single;
begin
  val := NaN;
  if not(isnan(val)) then
    begin
      writeln('error single 1');
      halt(1);
    end;
  val := Infinity;
  if not(isinfinite(val)) then
    begin
      writeln('error single 2');
      halt(1);
    end;
  val := 12341234;
  if isnan(val) then
    begin
      writeln('error single 3');
      halt(1);
    end;
  val := 0;
  if isinfinite(val) then
    begin
      writeln('error single 4');
      halt(1);
    end;
  val := 12341234;
  if isinfinite(val) then
    begin
      writeln('error single 5');
      halt(1);
    end;
end;

{$ifdef FPC_HAS_TYPE_DOUBLE}
procedure tnaninf_DoTestDouble;
var
  val: Double;
begin
  val := NaN;
  if not(isnan(val)) then
    begin
      writeln('error double 1');
      halt(1);
    end;
  val := Infinity;
  if not(isinfinite(val)) then
    begin
      writeln('error double 2');
      halt(1);
    end;
  val := 12341234;
  if isnan(val) then
    begin
      writeln('error double 3');
      halt(1);
    end;
  val := 0;
  if isinfinite(val) then
    begin
      writeln('error double 4');
      halt(1);
    end;
  val := 12341234;
  if isinfinite(val) then
    begin
      writeln('error double 5');
      halt(1);
    end;
end;
{$endif}

{$ifdef FPC_HAS_TYPE_EXTENDED}
procedure tnaninf_DoTestExtended;
var
  val: Extended;
begin
  val := NaN;
  if not(isnan(val)) then
    begin
      writeln('error extended 1');
      halt(1);
    end;
  val := Infinity;
  if not(isinfinite(val)) then
    begin
      writeln('error extended 2');
      halt(1);
    end;
  val := 12341234;
  if isnan(val) then
    begin
      writeln('error extended 3');
      halt(1);
    end;
  val := 0;
  if isinfinite(val) then
    begin
      writeln('error extended 4');
      halt(1);
    end;
  val := 12341234;
  if isinfinite(val) then
    begin
      writeln('error extended 5');
      halt(1);
    end;
end;
{$endif}


{$pop}

{ Case tsincos.pp }
{$push}

var
  tsincos_s1,tsincos_s2 : single;
  tsincos_d1,tsincos_d2 : double;
  tsincos_e1,tsincos_e2 : extended;


{$pop}



begin

{ Case tb_floating_point_fpc_consolidated_03.pp }
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
begin

{ Case tb0591.pp }
{$push}

begin
  tb0591_TestValue(2., 2.0);
  tb0591_TestValue(2.e10, 2.0e10);
  tb0591_TestValue(2.e-10, 2.0e-10);
  tb0591_TestValue(2.e+10, 2.0e+10);

  tb0591_TestValue(tb0591_f1, 2.0);
  tb0591_TestValue(tb0591_f2, 2.0e10);
  tb0591_TestValue(tb0591_f3, 2.0e-10);
  tb0591_TestValue(tb0591_f4, 2.0e+10);
end;
{$pop}

{ Case tw16315a.pp }
{$push}

begin
  tw16315a_D := Infinity;
end;
{$pop}

{ Case tw17714.pp }
{$push}

begin
  tw17714_l:=-12345;
  tw17714_c:=56789;
  tw17714_i:=-56789;
  tw17714_q:=12345;

  tw17714_s:=tw17714_l;
  if tw17714_s<>-12345 then
    halt(1);
  tw17714_s:=tw17714_c;
  if tw17714_s<>56789 then
    halt(2);
  tw17714_s:=tw17714_i;
  if tw17714_s<>-56789 then
    halt(3);
  tw17714_s:=tw17714_q;
  if tw17714_s<>12345 then
    halt(4);

  tw17714_d:=tw17714_l;
  if tw17714_d<>-12345 then
    halt(5);
  tw17714_d:=tw17714_c;
  if tw17714_d<>56789 then
    halt(6);
  tw17714_d:=tw17714_i;
  if tw17714_d<>-56789 then
    halt(7);
  tw17714_d:=tw17714_q;
  if tw17714_d<>12345 then
    halt(8);
end;
{$pop}

{ Case tw1792a.pp }
{$push}

Begin
{$ifdef FPC_HAS_TYPE_EXTENDED}
 str(intpower(2,63):25,tw1792a_s);
 if tw1792a_s<>' 9.2233720368547758E+0018' then
   begin
     WriteLn(intpower(2,63));
     halt(1);
   end;
{$endif FPC_HAS_TYPE_EXTENDED}

{$ifdef FPC_HAS_TYPE_DOUBLE}
 str(double(intpower(2,63)):22,tw1792a_s);
{$ifdef FPC_HAS_TYPE_EXTENDED}
 if tw1792a_s<>' 9.22337203685478E+018' then
{$else FPC_HAS_TYPE_EXTENDED}
 if tw1792a_s<>' 9.22337203685478E+018' then
{$endif FPC_HAS_TYPE_EXTENDED}
   begin
     WriteLn(double(intpower(2,63)));
     halt(1);
   end;
{$endif FPC_HAS_TYPE_DOUBLE}
end;
{$pop}

{ Case tw2891.pp }
{$push}

begin
 tw2891_d := 0;
 tw2891_e := 0;

 tw2891_d := Min(tw2891_d, tw2891_e);
 end;
{$pop}

end;
{$pop}

{ Case tnaninf.pp }
{$push}
{$ifdef FPC_HAS_TYPE_DOUBLE}
{$endif}
{$ifdef FPC_HAS_TYPE_EXTENDED}
{$endif}
begin
  tnaninf_DoTestSingle;
{$ifdef FPC_HAS_TYPE_DOUBLE}
  tnaninf_DoTestDouble;
{$endif}
{$ifdef FPC_HAS_TYPE_EXTENDED}
  tnaninf_DoTestExtended;
{$endif}
end;
{$pop}

{ Case tsincos.pp }
{$push}

begin
  sincos(0,tsincos_s1,tsincos_s2);
  sincos(0,tsincos_d1,tsincos_d2);
  sincos(0,tsincos_e1,tsincos_e2);
  if not(SameValue(tsincos_s1,0)) then
    halt(1);
  if not(SameValue(tsincos_s2,1)) then
    halt(2);
  if not(SameValue(tsincos_d1,0)) then
    halt(3);
  if not(SameValue(tsincos_d2,1)) then
    halt(4);
  if not(SameValue(tsincos_e1,0)) then
    halt(5);
  if not(SameValue(tsincos_e2,1)) then
    halt(6);

  sincos(pi,tsincos_s1,tsincos_s2);
  sincos(pi,tsincos_d1,tsincos_d2);
  sincos(pi,tsincos_e1,tsincos_e2);
  if not(SameValue(tsincos_s1,0)) then
    halt(7);
  if not(SameValue(tsincos_s2,-1)) then
    halt(8);
  if not(SameValue(tsincos_d1,0)) then
    halt(9);
  if not(SameValue(tsincos_d2,-1)) then
    halt(10);
  if not(SameValue(tsincos_e1,0)) then
    halt(11);
  if not(SameValue(tsincos_e2,-1)) then
    halt(12);

  { ArcCos relies on ArcTan2 edge cases. }
  tsincos_s1:=arccos(single(1));
  if tsincos_s1<>0 then
    halt(13);
  tsincos_s1:=arccos(single(-1));
  if not SameValue(tsincos_s1,single(pi)) then
    halt(14);
  tsincos_d1:=arccos(double(1));
  if tsincos_d1<>0 then
    halt(15);
  tsincos_d1:=arccos(double(-1));
  if not SameValue(tsincos_d1,double(pi)) then
    halt(16);
  tsincos_e1:=arccos(extended(1));
  if tsincos_e1<>0 then
    halt(17);
  tsincos_e1:=arccos(extended(-1));
  if not SameValue(tsincos_e1,extended(pi),1e-12) then
    halt(18);
  writeln('ok');
end;
{$pop}



end.
