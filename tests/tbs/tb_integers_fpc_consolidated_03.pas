{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}
uses math;

{ Case tw0869.pas }
{$push}


var
 tw0869_i,tw0869_resultado,tw0869_exponente:integer;

{$pop}

{ Case tw0937.pas }
{$push}



var
 tw0937_result,tw0937_number,tw0937_exponent : integer;

{$pop}

{ Case tw15453a.pas }
{$push}


var
  tw15453a_Result, tw15453a_Remainder: SmallInt;

{$pop}

{ Case tw16108.pas }
{$push}

var
  tw16108_i: longint;
  tw16108_ires: longint;
  tw16108_qres: int64;

{$pop}

{ Case tw3900.pas }
{$push}
{$Q+}

var tw3900_s1,tw3900_s2:byte;

{$pop}

begin

{ Case tw0869.pas }
{$push}

begin
 tw0869_exponente := 3;
 tw0869_resultado := -1 ** tw0869_exponente;
 writeln (tw0869_resultado);
 if tw0869_resultado<>-1 then
   Halt(1);
 tw0869_exponente := 4;
 tw0869_resultado := -(1 ** tw0869_exponente);
 writeln (tw0869_resultado);
 if tw0869_resultado<>-1 then
   Halt(1);
 tw0869_resultado := (-1) ** tw0869_exponente;
 writeln (tw0869_resultado);
 if tw0869_resultado<>1 then
   Halt(1);
 tw0869_i:=1;
 tw0869_resultado := - tw0869_i ** tw0869_exponente;
 writeln (tw0869_resultado);
 if tw0869_resultado<>-1 then
   Halt(1);
 tw0869_resultado := -1 ** tw0869_exponente;
 writeln (tw0869_resultado);
 if tw0869_resultado<>-1 then
   Halt(1);
end;
{$pop}

{ Case tw0937.pas }
{$push}

begin
 tw0937_number := 0;
 tw0937_exponent := 6;
 tw0937_result := tw0937_number ** tw0937_exponent;
 write (tw0937_result);
 if tw0937_result<>0 then
   begin
     Writeln(' 0 ** 6 should be equal to 0');
     Halt(1);
   end;
end;
{$pop}

{ Case tw15453a.pas }
{$push}

begin
  tw15453a_Result := -9 div 5;
  tw15453a_Remainder := -9 mod 5;
  writeln(tw15453a_result,' - ',tw15453a_remainder);
  if (tw15453a_result<>-1) or
     (tw15453a_remainder<>-4) then
    halt(1);
end;
{$pop}

{ Case tw16108.pas }
{$push}

begin
  randomize;
  for tw16108_i:=1 to 100 do
    begin
      tw16108_ires:=randomrange(-4,-7);
      if (tw16108_ires<-7) or
         (tw16108_ires>=-4) then
        halt(1);
      tw16108_ires:=randomrange(-7,-4);
      if (tw16108_ires<-7) or
         (tw16108_ires>=-4) then
        halt(2);
      tw16108_ires:=randomrange(10,-3);
      if (tw16108_ires<-3) or
         (tw16108_ires>=10) then
        halt(3);
      tw16108_ires:=randomrange(-3,10);
      if (tw16108_ires<-3) or
         (tw16108_ires>=10) then
        halt(4);
      tw16108_ires:=randomrange(5,10);
      if (tw16108_ires<5) or
         (tw16108_ires>=10) then
        halt(5);
      tw16108_ires:=randomrange(10,5);
      if (tw16108_ires<5) or
         (tw16108_ires>=10) then
        halt(6);

      tw16108_qres:=randomrange(low(int64)+1,low(int64)+10);
      if (tw16108_qres<low(int64)+1) or
         (tw16108_qres>=low(int64)+10) then
        halt(7);
      tw16108_qres:=randomrange(low(int64)+10,low(int64)+1);
      if (tw16108_qres<low(int64)+1) or
         (tw16108_qres>=low(int64)+10) then
        halt(8);
      tw16108_qres:=randomrange(int64(10),int64(-3));
      if (tw16108_qres<-3) or
         (tw16108_qres>=10) then
        halt(3);
      tw16108_qres:=randomrange(int64(-3),int64(10));
      if (tw16108_qres<-3) or
         (tw16108_qres>=10) then
        halt(4);
      tw16108_qres:=randomrange(int64(5),int64(10));
      if (tw16108_qres<5) or
         (tw16108_qres>=10) then
        halt(5);
      tw16108_qres:=randomrange(int64(10),int64(5));
      if (tw16108_qres<5) or
         (tw16108_qres>=10) then
        halt(6);
    end;
end;
{$pop}

{ Case tw3900.pas }
{$push}
{$Q+}
begin
tw3900_s1:=2;
tw3900_s2:=77;
writeln(0-min(tw3900_s1,tw3900_s2));
end;
{$pop}

end.
