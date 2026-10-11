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

{ Case tfloatrecs.pp }
{$push}


procedure tfloatrecs_do_error(i : longint);
  begin
    writeln('Error near ',i);
    halt(1);
  end;

var
{$ifdef FPC_HAS_TYPE_EXTENDED}
  tfloatrecs_extended_NaN,tfloatrecs_extended_Inf,tfloatrecs_extended_NInf,tfloatrecs_extended_NDenormal,tfloatrecs_extended_Denormal,tfloatrecs_extended_Zero,tfloatrecs_extended_NZero,
  tfloatrecs_extended_Positive,tfloatrecs_extended_Negative,tfloatrecs_extended_InvalidOp : extended;
{$endif FPC_HAS_TYPE_EXTENDED}
{$ifdef FPC_HAS_TYPE_DOUBLE}
  tfloatrecs_double_NaN,tfloatrecs_double_Inf,tfloatrecs_double_NInf,tfloatrecs_double_NDenormal,tfloatrecs_double_Denormal,tfloatrecs_double_Zero,tfloatrecs_double_NZero,
  tfloatrecs_double_Positive,tfloatrecs_double_Negative : double;
{$endif FPC_HAS_TYPE_DOUBLE}
{$ifdef FPC_HAS_TYPE_SINGLE}
  tfloatrecs_single_NaN,tfloatrecs_single_Inf,tfloatrecs_single_NInf,tfloatrecs_single_NDenormal,tfloatrecs_single_Denormal,tfloatrecs_single_Zero,tfloatrecs_single_NZero,
  tfloatrecs_single_Positive,tfloatrecs_single_Negative : single;
{$endif FPC_HAS_TYPE_SINGLE}


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

{ Case tfloatrecs.pp }
{$push}
{$ifdef FPC_HAS_TYPE_EXTENDED}
{$endif FPC_HAS_TYPE_EXTENDED}
{$ifdef FPC_HAS_TYPE_DOUBLE}
{$endif FPC_HAS_TYPE_DOUBLE}
{$ifdef FPC_HAS_TYPE_SINGLE}
{$endif FPC_HAS_TYPE_SINGLE}
begin
{$ifdef FPC_HAS_TYPE_EXTENDED}
  tfloatrecs_extended_NaN:=NaN;

  tfloatrecs_extended_Inf:=Infinity;

  tfloatrecs_extended_NInf:=-Infinity;

  tfloatrecs_extended_Denormal:=1234.0;
  TExtended80Rec(tfloatrecs_extended_Denormal).Exp:=0;

  tfloatrecs_extended_NDenormal:=-1234.0;
  TExtended80Rec(tfloatrecs_extended_NDenormal).Exp:=0;

  tfloatrecs_extended_Zero:=0.0;

  tfloatrecs_extended_NZero:=0.0;
  TExtended80Rec(tfloatrecs_extended_NZero).Sign:=true;

  tfloatrecs_extended_Positive:=Pi*10;

  tfloatrecs_extended_Negative:=-Pi*10;

  tfloatrecs_extended_InvalidOp:=0;
  TExtended80Rec(tfloatrecs_extended_InvalidOp).Exp:=$7fff;

  if TExtended80Rec(tfloatrecs_extended_NaN).SpecialType<>fsNaN then
    tfloatrecs_do_error(1);

  if TExtended80Rec(tfloatrecs_extended_Inf).SpecialType<>fsInf then
    tfloatrecs_do_error(2);

  if TExtended80Rec(tfloatrecs_extended_NInf).SpecialType<>fsNInf then
    tfloatrecs_do_error(3);

  if TExtended80Rec(tfloatrecs_extended_Denormal).SpecialType<>fsDenormal then
    tfloatrecs_do_error(4);

  if TExtended80Rec(tfloatrecs_extended_NDenormal).SpecialType<>fsNDenormal then
    tfloatrecs_do_error(5);

  if TExtended80Rec(tfloatrecs_extended_Zero).SpecialType<>fsZero then
    tfloatrecs_do_error(6);

  if TExtended80Rec(tfloatrecs_extended_NZero).SpecialType<>fsNZero then
    tfloatrecs_do_error(7);

  if TExtended80Rec(tfloatrecs_extended_Positive).SpecialType<>fsPositive then
    tfloatrecs_do_error(8);

  if TExtended80Rec(tfloatrecs_extended_Negative).SpecialType<>fsNegative then
    tfloatrecs_do_error(9);

  if TExtended80Rec(tfloatrecs_extended_InvalidOp).SpecialType<>fsInvalidOp then
    tfloatrecs_do_error(10);

  if TExtended80Rec(tfloatrecs_extended_Positive).Mantissa<>$7B53D14AA9C2F2C2 then
    tfloatrecs_do_error(11);

  if TExtended80Rec(tfloatrecs_extended_Positive).Fraction<>4.15926535897932384694E-0001 then
    tfloatrecs_do_error(12);

  if TExtended80Rec(tfloatrecs_extended_Positive).Exponent<>4 then
    tfloatrecs_do_error(13);

  if TExtended80Rec(tfloatrecs_extended_Positive).Sign then
    tfloatrecs_do_error(14);

  if TExtended80Rec(tfloatrecs_extended_Positive).Exp<>$4003 then
    tfloatrecs_do_error(15);

  if TExtended80Rec(tfloatrecs_extended_Negative).Mantissa<>$7B53D14AA9C2F2C2 then
    tfloatrecs_do_error(16);

  if TExtended80Rec(tfloatrecs_extended_Negative).Fraction<>-4.15926535897932384694E-0001 then
    tfloatrecs_do_error(17);

  if TExtended80Rec(tfloatrecs_extended_Negative).Exponent<>4 then
    tfloatrecs_do_error(18);

  if not(TExtended80Rec(tfloatrecs_extended_Negative).Sign) then
    tfloatrecs_do_error(19);

  if TExtended80Rec(tfloatrecs_extended_Negative).Exp<>$4003 then
    tfloatrecs_do_error(20);
{$endif FPC_HAS_TYPE_EXTENDED}

{$ifdef FPC_HAS_TYPE_DOUBLE}
  tfloatrecs_double_NaN:=NaN;

  tfloatrecs_double_Inf:=Infinity;

  tfloatrecs_double_NInf:=-Infinity;

  tfloatrecs_double_Denormal:=1234.0;
  TDoubleRec(tfloatrecs_double_Denormal).Exp:=0;

  tfloatrecs_double_NDenormal:=-1234.0;
  TDoubleRec(tfloatrecs_double_NDenormal).Exp:=0;

  tfloatrecs_double_Zero:=0.0;

  tfloatrecs_double_NZero:=0.0;
  TDoubleRec(tfloatrecs_double_NZero).Sign:=true;

  tfloatrecs_double_Positive:=Pi*10;

  tfloatrecs_double_Negative:=-Pi*10;

  if TDoubleRec(tfloatrecs_double_NaN).SpecialType<>fsNaN then
    tfloatrecs_do_error(101);

  if TDoubleRec(tfloatrecs_double_Inf).SpecialType<>fsInf then
    tfloatrecs_do_error(102);

  if TDoubleRec(tfloatrecs_double_NInf).SpecialType<>fsNInf then
    tfloatrecs_do_error(103);

  if TDoubleRec(tfloatrecs_double_Denormal).SpecialType<>fsDenormal then
    tfloatrecs_do_error(104);

  if TDoubleRec(tfloatrecs_double_NDenormal).SpecialType<>fsNDenormal then
    tfloatrecs_do_error(105);

  if TDoubleRec(tfloatrecs_double_Zero).SpecialType<>fsZero then
    tfloatrecs_do_error(106);

  if TDoubleRec(tfloatrecs_double_NZero).SpecialType<>fsNZero then
    tfloatrecs_do_error(107);

  if TDoubleRec(tfloatrecs_double_Positive).SpecialType<>fsPositive then
    tfloatrecs_do_error(108);

  if TDoubleRec(tfloatrecs_double_Negative).SpecialType<>fsNegative then
    tfloatrecs_do_error(109);

  if TDoubleRec(tfloatrecs_double_Positive).Mantissa<>$000F6A7A2955385E then
    tfloatrecs_do_error(111);

  if TDoubleRec(tfloatrecs_double_Positive).Fraction<>4.15926535897931159980E-0001 then
    tfloatrecs_do_error(112);

  if TDoubleRec(tfloatrecs_double_Positive).Exponent<>4 then
    tfloatrecs_do_error(113);

  if TDoubleRec(tfloatrecs_double_Positive).Sign then
    tfloatrecs_do_error(114);

  if TDoubleRec(tfloatrecs_double_Positive).Exp<>$403 then
    tfloatrecs_do_error(115);

  if TDoubleRec(tfloatrecs_double_Negative).Mantissa<>$000F6A7A2955385E then
    tfloatrecs_do_error(116);

  if TDoubleRec(tfloatrecs_double_Negative).Fraction<>-4.15926535897931159980E-0001 then
    tfloatrecs_do_error(117);

  if TDoubleRec(tfloatrecs_double_Negative).Exponent<>4 then
    tfloatrecs_do_error(118);

  if not(TDoubleRec(tfloatrecs_double_Negative).Sign) then
    tfloatrecs_do_error(119);

  if TDoubleRec(tfloatrecs_double_Negative).Exp<>$403 then
    tfloatrecs_do_error(120);
{$endif FPC_HAS_TYPE_DOUBLE}

{$ifdef FPC_HAS_TYPE_DOUBLE}
  tfloatrecs_single_NaN:=NaN;

  tfloatrecs_single_Inf:=Infinity;

  tfloatrecs_single_NInf:=-Infinity;

  tfloatrecs_single_Denormal:=1234.0;
  TSingleRec(tfloatrecs_single_Denormal).Exp:=0;

  tfloatrecs_single_NDenormal:=-1234.0;
  TSingleRec(tfloatrecs_single_NDenormal).Exp:=0;

  tfloatrecs_single_Zero:=0.0;

  tfloatrecs_single_NZero:=0.0;
  TSingleRec(tfloatrecs_single_NZero).Sign:=true;

  tfloatrecs_single_Positive:=Pi*10;

  tfloatrecs_single_Negative:=-Pi*10;

  if TSingleRec(tfloatrecs_single_NaN).SpecialType<>fsNaN then
    tfloatrecs_do_error(201);

  if TSingleRec(tfloatrecs_single_Inf).SpecialType<>fsInf then
    tfloatrecs_do_error(202);

  if TSingleRec(tfloatrecs_single_NInf).SpecialType<>fsNInf then
    tfloatrecs_do_error(203);

  if TSingleRec(tfloatrecs_single_Denormal).SpecialType<>fsDenormal then
    tfloatrecs_do_error(204);

  if TSingleRec(tfloatrecs_single_NDenormal).SpecialType<>fsNDenormal then
    tfloatrecs_do_error(205);

  if TSingleRec(tfloatrecs_single_Zero).SpecialType<>fsZero then
    tfloatrecs_do_error(206);

  if TSingleRec(tfloatrecs_single_NZero).SpecialType<>fsNZero then
    tfloatrecs_do_error(207);

  if TSingleRec(tfloatrecs_single_Positive).SpecialType<>fsPositive then
    tfloatrecs_do_error(208);

  if TSingleRec(tfloatrecs_single_Negative).SpecialType<>fsNegative then
    tfloatrecs_do_error(209);

  if TSingleRec(tfloatrecs_single_Positive).Mantissa<>$7b53d1 then
    tfloatrecs_do_error(211);

  if TSingleRec(tfloatrecs_single_Positive).Fraction<>4.15925979614257812500E-0001 then
    tfloatrecs_do_error(212);

  if TSingleRec(tfloatrecs_single_Positive).Exponent<>4 then
    tfloatrecs_do_error(213);

  if TSingleRec(tfloatrecs_single_Positive).Sign then
    tfloatrecs_do_error(214);

  if TSingleRec(tfloatrecs_single_Positive).Exp<>$83 then
    tfloatrecs_do_error(215);

  if TSingleRec(tfloatrecs_single_Negative).Mantissa<>$7b53d1 then
    tfloatrecs_do_error(216);

  if TSingleRec(tfloatrecs_single_Negative).Fraction<>-4.15925979614257812500E-0001 then
    tfloatrecs_do_error(217);

  if TSingleRec(tfloatrecs_single_Negative).Exponent<>4 then
    tfloatrecs_do_error(218);

  if not(TSingleRec(tfloatrecs_single_Negative).Sign) then
    tfloatrecs_do_error(219);

  if TSingleRec(tfloatrecs_single_Negative).Exp<>$83 then
    tfloatrecs_do_error(220);
{$endif FPC_HAS_TYPE_DOUBLE}

  writeln('ok');
end;
{$pop}

end.
