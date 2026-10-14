{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode objfpc}
{$modeswitch arrayoperators}

{ Source group: tb_arrays_objfpc_run_01.pas }
{$push}

{ Case tb0340.pas }
{$push}

var
  tb0340_v : tvarrec;
  tb0340_error : boolean;
procedure tb0340_p(a:array of const);
var
  tb0340_i : integer;
begin
  for tb0340_i:=low(a) to high(a) do
   with a[tb0340_i] do
    begin
      case vtype of
        vtInteger :
          begin
            writeln('Integer: ',VInteger);
            if VInteger=1000 then
             tb0340_error:=false;
          end;
        else
          writeln('Error!');
      end;
    end;
end;
{$pop}

{ Case tb0394.pas }
{$push}
{$ifdef fpc}{$endif}

var
  tb0394_err : boolean;
procedure tb0394_demo(x:array of longint);
 var
  tb0394_i:longint;
 begin
   if high(x)<>4 then
    tb0394_err:=true
   else if x[4]<>14 then
    tb0394_err:=true;
  for tb0394_i:=low(x)to high(x)do
   writeln(tb0394_i,' ',x[tb0394_i]);
 end;
var
 tb0394_y:array[10..40]of longint;
 tb0394_i:longint;
{$pop}

{ Case tb0402.pas }
{$push}

type
   tb0402_ta = array of longint;

procedure tb0402_p(i : iunknown;tb0402_a : tb0402_ta = nil);

  begin
  end;

var
   tb0402_o : tinterfacedobject;
{$pop}

{ Case tb0436.pas }
{$push}


procedure tb0436_pext(a:array of extended);
begin
end;

procedure tb0436_p(a:array of const);
begin
end;
{$pop}

{ Case tb0438.pas }
{$push}
{$ifdef fpc}{$endif}

procedure tb0438_p(tb0438_a : array of const);
  var
    tb0438_i : integer;
  begin
    for tb0438_i:=low(tb0438_a) to high(tb0438_a) do
     begin
       write(tb0438_i,': ');
       if (tb0438_a[tb0438_i].vtype=vtpchar) then
        begin
          writeln('"',tb0438_a[tb0438_i].vpchar,'"');
          if (tb0438_a[tb0438_i].vpchar<>'test') then
           begin
             writeln('Wrong string content');
             halt(1);
           end;
        end
       else
        begin
          writeln('No string type (',tb0438_a[tb0438_i].vtype,')');
          halt(1);
        end;
     end;
  end;

var
   tb0438_a : array[0..25] of char;
{$pop}

{ Case tb0581.pas }
{$push}


procedure tb0581_dirtystack;
var
  tb0581_s: shortstring;
begin
  fillchar(tb0581_s,sizeof(tb0581_s),255);
end;

procedure tb0581_test(const arr: array of const);
begin
  if arr[0].vinteger<>ord('$') then
    halt(1);
end;

procedure tb0581_doit;
begin
  tb0581_test(['$']);
end;
{$pop}

{ Case tw1351.pas }
{$push}


procedure tw1351_test(ParArr :array of const);
begin
   writeln(ParArr[0].vtype,' ',vtObject,' ',vtclass);
   if ParArr[0].vtype<>vtObject then
    halt(1);
end;
{$pop}

{ Case tw2159.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2159 }
{ Submitted by "Yakov Sudeikin" on  2002-10-03 }
{ e-mail: yashka@exebook.com }
{$ifdef fpc}{$endif}

var
 tw2159_a,tw2159_b,tw2159_c: array of string;
{$pop}

{ Case tw24410.pas }
{$push}


procedure tw24410_xx(var s:shortstring);
var tw24410_dirbuf:array[0..1321] of widechar;
begin
  s:=tw24410_dirbuf;
end;
{$pop}

{ Case tw29250.pas }
{$push}


function tw29250_comparearr(const tw29250_a,tw29250_b: array of byte; tw29250_len: integer): Boolean;
var
  tw29250_i : integer;
begin
  for tw29250_i:=0 to tw29250_len-1 do
    if tw29250_a[tw29250_i]<>tw29250_b[tw29250_i] then begin
      Result:=false;
      Exit;
    end;
  Result:=true;
end;

procedure tw29250_printarr(const tw29250_a: array of byte);
var
  tw29250_i : integer;
begin
  for tw29250_i:=0 to length(tw29250_a)-1 do write(tw29250_a[tw29250_i],' ');
  writeln;
end;

const
  tw29250_size_cnt = 8;
  tw29250_size_inc = 20;
  tw29250_size_dec = 4;

var
  tw29250_a: array of byte;
  tw29250_b: array of byte;
  tw29250_i: integer;
  tw29250_r: integer;
{$pop}

{ Case tw32645.pas }
{$push}


var tw32645_myarray : array ['a'..'z'] of integer; //operator is not overloaded 'char' - 'char'
//var myarray : array ['a'..'zz'] of integer; //signal 291
//var myarray : array ['a'..'z'*5] of integer; //signal 291

procedure tw32645_myproc (tw32645_myarray: array of integer);
begin
  if high(tw32645_myarray)<>25 then
    halt(1);
end;
{$pop}

{ Case tw34055.pas }
{$push}


 type
  tw34055_tdos_fieldnames = (
                      Dos_Signature, // ord = 0
                      Dos_OffsetToNewExecutable // ord = 1
                    );

const
  tw34055_dosfieldlabelsb : array[tw34055_tdos_fieldnames]
                        of pwidechar =
  (
    'DOS signature',
    'offset to new executable'
  );

  tw34055_d : ppwidechar = @tw34055_dosfieldlabelsb[Dos_OffsetToNewExecutable];
{$pop}


{$pop}

{ Source group: tb_arrays_objfpc_run_02.pas }
{$push}

{ Case tw3621.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3621 }
{ Submitted by "Thomas Schatzl" on  2005-02-01 }
{ e-mail:  }

type
        tw3621_tfourcc=array[0..3] of char;

FUNCTION comp(f1, f2:tw3621_tfourcc):boolean;
BEGIN
  comp:=((f1[0]=f2[0]) AND (f1[1]=f2[1]) AND (f1[2]=f2[2]) AND (f1[3]=f2[3]));
END;
{$pop}

{ Case tw36389.pas }
{$push}
{$inline on}

function tw36389_correct(TempInt: integer; tw36389_value: word): word; inline;
begin
 if TempInt = 32768 then
   Result := tw36389_value - TempInt
  else
   Result := 65536 - tw36389_value;
end;

procedure tw36389_p;
var
 tw36389_arr: array of word;
 tw36389_temp: integer;
begin
 SetLength(tw36389_arr,1);
 tw36389_temp:= 42;
 tw36389_arr[0] := tw36389_correct(tw36389_temp, tw36389_arr[0]);
end;
{$pop}

{ Case tw37272a.pas }
{$push}
{ note: there is a tw37272b in webtbf }



type
  tw37272a_ta1 = array of integer;

procedure tw37272a_test(A: integer; const tw37272a_b: tw37272a_ta1 = []);
begin end;
{$pop}

{ Case tw4219.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4219 }
{ Submitted by "Marijn Kruisselbrink" on  2005-07-25 }
{ e-mail: mkruisselbrink@hexis.nl }



procedure tw4219_f1(const tw4219_p: array of const);
begin
  write('f1:');
  writeln(tw4219_p[0].VType);
  if tw4219_p[0].VType<>vtInteger then
    halt(1);
end;

procedure tw4219_f2(const tw4219_p: array of TVarRec);
begin
  write('f2:');
  writeln(tw4219_p[0].VType);
  if tw4219_p[0].VType<>vtInteger then
    halt(1);
end;

var
  tw4219_p: array of TVarRec;
{$pop}

{ Case tw4599.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4599 }
{ Submitted by "Sam" on  2005-12-14 }
{ e-mail: sam_herzog@yahoo.com }



procedure tw4599_trace(_level:byte;tw4599__msg:String;tw4599__params:array of const);
var
  tw4599_i : integer;
begin
    tw4599_i:=SizeOf(tw4599__params);
end;
{$pop}


{$pop}

{ Source group: tb_arrays_objfpc_run_03.pas }
{$push}

{ Case tw14388.pas }
{$push}
{$H+}

type
  tw14388_tid4 = array[0..3] of char;

function tw14388_getid: tw14388_tid4;
begin
  result:=#1#3#5#9;
end;

var
  tw14388_chunkid: tw14388_tid4;
{$pop}

{ Case tw33696.pas }
{$push}
{$H+}
type
  tw33696_ternary = (F, U, T);

  operator and (const a,b:tw33696_ternary):tw33696_ternary;inline;
    const tw33696_lookupand:array[tw33696_ternary,tw33696_ternary] of tw33696_ternary =
                    ((F,F,F),(F,U,U),(F,U,T));
  begin
    Result:= tw33696_lookupand[a,b];
  end;

  operator or (const a,b:tw33696_ternary):tw33696_ternary;inline;
    const tw33696_lookupor:array[tw33696_ternary,tw33696_ternary] of tw33696_ternary =
                   ((F,U,T),(U,U,T),(T,T,T));
  begin
    Result := tw33696_lookupor[a,b];
  end;

  operator not (const a:tw33696_ternary):tw33696_ternary;inline;
    const tw33696_lookupnot:array[tw33696_ternary] of tw33696_ternary =(T,U,F);
  begin
     Result:= tw33696_lookupnot[a];
  end;
{$pop}

{ Case tw37062.pas }
{$push}
{$H+}

Var
  tw37062_lout : array of Byte;
  tw37062_llength, tw37062_lssize : integer;
{$pop}

{ Case tw4239.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4239 }
{ Submitted by "Lars" on  2005-07-30 }
{ e-mail: L@z505.com }

{$H+}

var
  tw4239_myproc: array of procedure(s:string);

procedure tw4239_testing(s:string);
begin
  writeln(s);
end;
{$pop}


{$pop}

{ Source group: tb_arrays_objfpc_run_04.pas }
{$push}

{ Case tw30463.pas }
{$push}

{$modeswitch arrayoperators}
procedure tw30463_p1;
  var
    tw30463_a: array of Integer;
    tw30463_i: integer;
  begin
    tw30463_a := [];
    tw30463_a := tw30463_a + tw30463_a;
    tw30463_a := Concat(tw30463_a,[123456789]);
    tw30463_a := tw30463_a + [6];
    tw30463_a := tw30463_a + tw30463_a;

    if tw30463_a[0]<>123456789 then
      Halt(1);
    if tw30463_a[High(tw30463_a)]<>6 then
      Halt(1);
  end;

procedure tw30463_p2;
  var
    tw30463_a, tw30463_b, tw30463_c: array of Integer;

    tw30463_i: integer;
  begin
    tw30463_a := [];
    tw30463_a := tw30463_a + tw30463_a + tw30463_a;
    tw30463_a := Concat(tw30463_a,[123456789],[8]);
    tw30463_a := tw30463_a + [6] + tw30463_a;
    tw30463_a := tw30463_a + tw30463_a + tw30463_a;
    tw30463_b:=copy(tw30463_a);
    tw30463_c:=tw30463_b+tw30463_a;

    if tw30463_c[0]<>123456789 then
      Halt(1);
    if tw30463_c[High(tw30463_c)]<>8 then
      Halt(1);
    if tw30463_c[High(tw30463_c)-1]<>123456789 then
      Halt(1);
  end;
{$pop}

{ Case tw41087.pas }
{$push}
{ Strange bug while concatenating TBytes arrays }


{$modeswitch arrayoperators}

type
  tw41087_tbytes = array of Byte;

function tw41087_u8(v: Byte): tw41087_tbytes;
begin
  SetLength(Result, 1);
  Result[0] := v;
end;

var
  tw41087_r: tw41087_tbytes;
{$pop}

{ Case tw41798.pas }
{$push}
{ Failure in multiple-array concatenation }


{$modeswitch arrayoperators}

type
  tw41798_tintarr = array of PtrInt;

var
  tw41798_x, tw41798_y: tw41798_tintarr;
{$pop}


{$pop}

{ Source group: tb_dynamic_arrays_objfpc_run_01.pas }
{$push}

{ Case tb0411.pas }
{$push}
type
   tb0411_ta = array of longint;

function tb0411_f : tb0411_ta;
  begin
     setlength(result,10);
  end;
{$pop}

{ Case tb0457.pas }
{$push}
Type
  tb0457_ta = array of Integer;

var
  tb0457_a,tb0457_b : tb0457_ta;
  tb0457_i,tb0457_j : Integer;
{$pop}


{$pop}

begin
  { Source group: tb_arrays_objfpc_run_01.pas }
  {$push}


begin
  { Case tb0340.pas }
  {$push}

  begin
tb0340_error:=true;
  tb0340_v.vtype:=vtInteger;
  tb0340_v.VInteger:=1000;
  tb0340_p(tb0340_v);
  if tb0340_error then
   Halt(1);
  end;
  {$pop}

  { Case tb0394.pas }
  {$push}
{$ifdef fpc}
{$endif}
  begin
for tb0394_i:=10 to 40 do
  tb0394_y[tb0394_i]:=tb0394_i;
 tb0394_demo(slice(tb0394_y,5));
 if tb0394_err then
  begin
    writeln('ERROR!');
    halt(1);
  end;
  end;
  {$pop}

  { Case tb0402.pas }
  {$push}

  begin
tb0402_p(tb0402_o);
  end;
  {$pop}

  { Case tb0436.pas }
  {$push}

  begin
tb0436_p([0.0]);
  tb0436_p([pi]);
  tb0436_pext([0.0]);
  end;
  {$pop}

  { Case tb0438.pas }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tb0438_a:='test';
   tb0438_p([tb0438_a,tb0438_a]);
  end;
  {$pop}

  { Case tb0581.pas }
  {$push}

  begin
tb0581_dirtystack;
  tb0581_doit;
  end;
  {$pop}

  { Case tw1351.pas }
  {$push}

  begin
tw1351_test([TObject.Create]);
  end;
  {$pop}

  { Case tw2159.pas }
  {$push}
{$ifdef fpc}
{$endif}
  begin
setlength(tw2159_a, 2);
 tw2159_a[0] := 'asd';
 tw2159_a[1] := 'qwe';
 tw2159_b := copy(tw2159_a);
 tw2159_c := copy(tw2159_a, 1, 1);
 if tw2159_b[0]<>'asd' then
  begin
    writeln('Error 1');
    halt(1);
  end;
 if tw2159_b[1]<>'qwe' then
  begin
    writeln('Error 2');
    halt(1);
  end;
 if tw2159_c[0]<>'qwe' then
  begin
    writeln('Error 3');
    halt(1);
  end;
  end;
  {$pop}

  { Case tw29250.pas }
  {$push}

  begin
SetLength(tw29250_a, tw29250_size_cnt);
  for tw29250_i:=0 to length(tw29250_a)-1 do tw29250_a[tw29250_i]:=$F0+tw29250_i;

  // test decrease size
  // match, by less size
  tw29250_b:=tw29250_a;
  SetLength(tw29250_b, tw29250_size_dec);
  if not tw29250_comparearr(tw29250_a,tw29250_b,length(tw29250_b))  then
    halt(1);

  // test same size/copy
  // full match
  tw29250_b:=tw29250_a;
  SetLength(tw29250_b, length(tw29250_b));
  if not tw29250_comparearr(tw29250_a,tw29250_b,length(tw29250_b)) then
    halt(1);

  // test increase size
  // first part must match, last part must be zero
  tw29250_b:=tw29250_a;
  SetLength(tw29250_b, tw29250_size_inc);
  if not tw29250_comparearr(tw29250_a,tw29250_b,length(tw29250_a)) then
    halt(1);
  tw29250_r:=1;
  for tw29250_i:=length(tw29250_a) to length(tw29250_b)-1 do
    if tw29250_b[tw29250_i]<>0 then begin tw29250_r:=0; halt(1) end;
  writeln('ok');
  end;
  {$pop}

  { Case tw32645.pas }
  {$push}

  begin
tw32645_myproc(tw32645_myarray);
  end;
  {$pop}

  { Case tw34055.pas }
  {$push}

  begin
if tw34055_d<>@tw34055_dosfieldlabelsb[Dos_OffsetToNewExecutable] then
    halt(1);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_arrays_objfpc_run_02.pas }
  {$push}


begin
  { Case tw3621.pas }
  {$push}

  begin
comp('ABCD', 'DEFG');
  end;
  {$pop}

  { Case tw37272a.pas }
  {$push}

  begin
tw37272a_test(1, []);
  tw37272a_test(1);
  end;
  {$pop}

  { Case tw4219.pas }
  {$push}

  begin
setlength(tw4219_p, 1);
  tw4219_p[0].VType := vtInteger;
  tw4219_p[0].VInteger := 0;

  tw4219_f1(tw4219_p);
  tw4219_f2(tw4219_p);
  writeln('ok');
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_arrays_objfpc_run_03.pas }
  {$push}


begin
  { Case tw14388.pas }
  {$push}

  begin
tw14388_chunkid:=#1#3#5#9;
  if tw14388_getid=tw14388_chunkid then
    writeln('ok')
  else
    halt(1);
  end;
  {$pop}

  { Case tw33696.pas }
  {$push}

  begin
// works as expected
  writeln('AND');write(F and F);write(F and U);
  writeln(F and T);write(U and F);write(U and U);
  writeln(U and T);write(T and F);write(T and U);
  writeln(T and T);
  writeln;
  //works as expected
  writeln('OR');write(F or F);write(F or U);
  writeln(F or T);write(U or F);write(U or U);
  writeln(U or T);write(T or F);write(T or U);
  writeln(T or T);
  writeln;
  // this fails, but compiles and runs w/o error indication.
  // and renders the wrong results
  writeln('NOT');
  writeln(not F);// prints -1 unstead of T, it does not pick the overload!
  writeln(not U);// prints -2 instead of U, it does not pick the overload!
  writeln(not T);// prints -3 instead of F, it does not pick the overload!
  // which makes this next construct impossible while the compiler suggests it's legal.
  {
   writeln(T and not F);
  }
  end;
  {$pop}

  { Case tw37062.pas }
  {$push}

  begin
SetLength(tw37062_lout, 1+tw37062_llength+1+4+4+2+4+4+2+tw37062_lssize+2);
  end;
  {$pop}

  { Case tw4239.pas }
  {$push}

  begin
setlength(tw4239_myproc,1);
  tw4239_myproc[0]:=@tw4239_testing;
  tw4239_myproc[0]('Test me');
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_arrays_objfpc_run_04.pas }
  {$push}

{$modeswitch arrayoperators}
{$modeswitch arrayoperators}
{$modeswitch arrayoperators}
begin
  { Case tw30463.pas }
  {$push}

  begin
tw30463_p1;
  tw30463_p2;
  writeln('ok');
  end;
  {$pop}

  { Case tw41087.pas }
  {$push}

  begin
{ three function results in one + chain must not alias the last one }
  tw41087_r := tw41087_u8($11) + tw41087_u8($22) + tw41087_u8($33);
  if (Length(tw41087_r) <> 3) or (tw41087_r[0] <> $11) or (tw41087_r[1] <> $22) or (tw41087_r[2] <> $33) then
    halt(1);
  end;
  {$pop}

  { Case tw41798.pas }
  {$push}

  begin
tw41798_x := [1, 2];
  { the two literal temps must not alias the last one }
  tw41798_y := tw41798_x + [3, 4] + [5, 6];
  if (Length(tw41798_y) <> 6) or
     (tw41798_y[0] <> 1) or (tw41798_y[1] <> 2) or (tw41798_y[2] <> 3) or
     (tw41798_y[3] <> 4) or (tw41798_y[4] <> 5) or (tw41798_y[5] <> 6) then
    halt(1);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_dynamic_arrays_objfpc_run_01.pas }
  {$push}


begin
  { Case tb0411.pas }
  {$push}
begin
   tb0411_f[1]:=1;
end;
  {$pop}

  { Case tb0457.pas }
  {$push}
begin
  Setlength(tb0457_a,10);
  For tb0457_i:=0 to 9 do
      tb0457_a[tb0457_i]:=tb0457_i;
  tb0457_b:=Copy(tb0457_a,3,6);
  if High(tb0457_b)<>5 then
    begin
      writeln('Error 1');
      halt(1);
    end;
  For tb0457_i:=0 to High(tb0457_b) do
    if tb0457_b[tb0457_i]<>tb0457_i+3 then
      begin
        writeln('Error 2');
        halt(1);
      end;
end;
  {$pop}


end;
  {$pop}

end.
