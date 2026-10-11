{ Consolidated floating point regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb0191.pp }
{$push}
{ Old file: tbs0225.pp }
{ Sigsegv when run with range checks on open arrays    OK 0.99.11 (PFV) }

 



{$R+}

  function tb0191_erwwert(const feld: array of LongInt):extended;
   var tb0191_i: LongInt;
   begin
    Result:=0;
    for tb0191_i:=low(feld) to high(feld)
        do begin
            writeln(tb0191_i);  // gives "0"
            Result:=Result+feld[tb0191_i];
           end;          //^^^^^^^ there occurs the segfault (216)
                         //        on the first loop
    Result:=Result/(high(feld)-low(feld)+1);
   end;

 var tb0191_werte: array[0..299] of LongInt;
     tb0191_i: LongInt;

 
{$pop}

{ Case tw1133.pp }
{$push}

type
   tw1133_float = double;


function tw1133_ConvertRealToPixel(Axis     : integer;
                            HelpReal : real) : real;

   begin   { function ConvertRealToPixel }
      tw1133_ConvertRealToPixel := HelpReal;
   end;    { function ConvertRealToPixel }


var
   tw1133_HelpFloat1,tw1133_HelpFloat2,tw1133_HelpFloat3  : tw1133_float;
   tw1133_SegmentStartPos        : tw1133_float;
   tw1133_SegmentLength          : tw1133_float;



{$pop}

{ Case tw29930.pp }
{$push}

{$H+}

var
  tw29930_a : extended;
  tw29930_d : longint;

{$pop}

{ Case tw3207.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3207 }
{ Submitted by "Marc Weustink" on  2004-07-11 }
{ e-mail: marc@freepascal.org }




function tw3207_CheckReal: Real;
begin
  Result := 1/2;
end;

function tw3207_CheckDouble: Double;
begin
  Result := 1/2;
end;

function tw3207_CheckExtended: Extended;
begin
  Result := 1/2;
end;

var
  tw3207_n: Integer;


{$pop}

{ Case tw3217.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3217 }
{ Submitted by "C Western" on  2004-07-18 }
{ e-mail: mftq75@dsl.pipex.com }

function tw3217_TT(I:Integer):Double;
begin
  Result := (I+0.2)*(I+0.3)+(I+0.5);
end;

function tw3217_T(I:Integer):Double;
begin
  Result := (I+0.2)*(I+0.3)*tw3217_TT(I)+(I+0.5)*tw3217_TT(I-1);
end;

function tw3217_H(K, Kp: Integer): Double;
begin
  Result := tw3217_T(K)+tw3217_T(K+3);
end;

function tw3217_M(K, Kp, P, PP: Integer): Double;
begin
  Result := tw3217_H(K, Kp);
  if P = 0 then begin
    if PP <> 0 then
      Result := (Result + PP*tw3217_H(K, -Kp))/Sqrt(2.0);
  end else if PP = 0 then
    Result := (Result + P*tw3217_H(-K, Kp))/Sqrt(2.0)
  else
    Result := (Result + PP*tw3217_H(K, -Kp)
                      + p*tw3217_H(-K, Kp)
                      + PP*p*tw3217_H(-K,-Kp)
               )/2;
end;


{$pop}

{ Case tw41270.pp }
{$push}



{$OPTIMIZATION OFF}
{$OPTIMIZATION REGVAR}

var
  tw41270_arr: array [0..3] of Double;

procedure tw41270_mdtgen(n: Integer; var alu: Double);
var
  nsr, ind, i, j: Integer;
  sumrowi, h, s: Double;
  palu, t, pp: PDouble;
  singular : Boolean;
begin
  palu := @alu;
  pp := @alu;
  nsr := n*sizeof(Double);
  getmem(t, nsr);
  for i:=1 to n do
  begin
    for j:=1 to n do;
    ind:=1;
    h := random;
    singular := false;
    sumrowi := palu[ind];
  end;

  s:=0.0;
  i:=0;
  h:=s+palu[i+i+0]; // <- ACCESS VIOLATION:  addsd xmm0,[rax*8+rax]
  freemem(t, nsr)
end;


{$pop}

begin

{ Case tb0191.pp }
{$push}

{$R+}
begin
  //init the array
  for tb0191_i:=0 to 299  do
    tb0191_werte[tb0191_i]:=random(5);

  //and do something with it
  writeln(tb0191_erwwert(tb0191_werte):6:5);
 end;
{$pop}

{ Case tw1133.pp }
{$push}

begin
   tw1133_SegmentStartPos := 0.5;
   tw1133_SegmentLength := 0.5;
   tw1133_HelpFloat1 := tw1133_SegmentStartPos - tw1133_SegmentLength / 2;
   tw1133_HelpFloat2 := tw1133_ConvertRealToPixel(1,tw1133_HelpFloat1);
   writeln('Function result = ',tw1133_HelpFloat2,'  This is OK');

   tw1133_HelpFloat3 := tw1133_ConvertRealToPixel(1,tw1133_SegmentStartPos - tw1133_SegmentLength / 2);
   writeln('Function result = ',tw1133_HelpFloat3,'  THIS IS WRONG !');
   if tw1133_HelpFloat2<>tw1133_HelpFloat3 then
    begin
      Writeln('ERROR!');
      Halt(1);
    end;
end;
{$pop}

{ Case tw29930.pp }
{$push}

{$H+}
begin
  tw29930_a := -1;
  tw29930_d := (round(tw29930_a*512) div 180) and 1023;
  writeln(tw29930_d);
  if tw29930_d<>1022 then
    halt(1);

  tw29930_d := (round(tw29930_a*512) div 180);
  while (tw29930_d<0) do tw29930_d := tw29930_d+1024;
  writeln(tw29930_d);
  if tw29930_d<>1022 then
    halt(1);
end;
{$pop}

{ Case tw3207.pp }
{$push}

begin
  for tw3207_n := 1 to 1000 do tw3207_CheckReal;

  for tw3207_n := 1 to 1000 do tw3207_CheckDouble;

  for tw3207_n := 1 to 1000 do tw3207_CheckExtended;
end;
{$pop}

{ Case tw3217.pp }
{$push}

begin
  WriteLn(tw3217_M(3,3,1,-1)-tw3217_M(3,3,1,-1));
end;
{$pop}

{ Case tw41270.pp }
{$push}

{$OPTIMIZATION OFF}
{$OPTIMIZATION REGVAR}
begin
  tw41270_mdtgen(2, tw41270_arr[0]);
  WriteLn('ok');
end;
{$pop}

end.
