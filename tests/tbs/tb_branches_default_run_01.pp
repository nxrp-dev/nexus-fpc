{ Conditional nesting, empty statements and ordinal case labels. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0034.pp }
{$push}
{ Old file: tbs0039.pp }
{  shows the else-else problem                         OK 0.9.9 (FK) }

VAR tb0034_a : BYTE;
{$pop}

{ Case tb0036.pp }
{$push}
{ Old file: tbs0041.pp }
{  shows the if then end. problem                      OK 0.9.9 (FK) }

var
 tb0036_b1: boolean;
{$pop}

{ Case tb0057.pp }
{$push}
{ Old file: tbs0064.pp }
{  shows other types of problems with case statements   OK 0.99.1 (FK) }

var
 tb0057_i: byte;
 tb0057_j: integer;
 tb0057_c: char;
{$pop}

{ Case tb0082.pp }
{$push}
{ Old file: tbs0095.pp }
{ case with ranges starting with #0 bugs                OK 0.99.1 (FK) }

var
  tb0082_ch : char;
{$pop}

{ Case tb0712.pp }
{$push}
var
  tb0712_yy,tb0712_res : longint;
{$pop}

{ Case tw10009.pp }
{$push}
var
  tw10009_test : 2..14;
{$pop}

{ Case tw1061.pp }
{$push}
var tw1061_vlcnt:longint;
{$pop}

{ Case tw1222.pp }
{$push}
CONST
    tw1222_c1=$80000000;
    tw1222_c2=$80000001;
    tw1222_c3=$80000002;
    tw1222_c4=$80000003;
    tw1222_cm=$80000007;

VAR tw1222_v:dword;
{$pop}

begin
  { Case tb0034.pp }
  {$push}
BEGIN
  tb0034_a := 1;
  IF tb0034_a=0 THEN
    IF tb0034_a=1 THEN tb0034_a:=2
    ELSE
  ELSE tb0034_a:=3;        { "Illegal expression" }
END;
  {$pop}

  { Case tb0036.pp }
  {$push}
Begin
  begin
     If tb0036_b1 then      { illegal expression }
  end;
  while tb0036_b1 do
End;
  {$pop}

  { Case tb0057.pp }
  {$push}
Begin
  case tb0057_i of
  Ord('x'): ;
  end;
  case tb0057_j of
  Ord('x'): ;
  end;
  case tb0057_c of
  Chr(112): ;
  end;
end;
  {$pop}

  { Case tb0082.pp }
  {$push}
begin
  tb0082_ch:=#3;
  case tb0082_ch of
   #0..#31 : ;
  else
   writeln('bug');
  end;
  case tb0082_ch of
   #0,#1,#3 : ;
  else
   writeln('bug');
  end;
end;
  {$pop}

  { Case tb0712.pp }
  {$push}
begin
  tb0712_res:=0;
  tb0712_yy:=random(0)+1980;
  If (tb0712_yy<1980) or (tb0712_yy>2099) then
    tb0712_res:=1;
  if tb0712_res<>0 then
    halt(tb0712_res);

  tb0712_yy:=random(0)+2099;
  If (tb0712_yy<1980) or (tb0712_yy>2099) then
    tb0712_res:=2;
  if tb0712_res<>0 then
    halt(tb0712_res);

  tb0712_yy:=random(0)+1980;
  If (tb0712_yy<=1979) or (tb0712_yy>2099) then
    tb0712_res:=3;
  if tb0712_res<>0 then
    halt(tb0712_res);

  tb0712_yy:=random(0)+2099;
  If (tb0712_yy<1979) or (tb0712_yy>=2100) then
    tb0712_res:=4;
  if tb0712_res<>0 then
    halt(tb0712_res);
end;
  {$pop}

  { Case tw10009.pp }
  {$push}
begin
  tw10009_test:=14;
  case tw10009_test of
    2..9: halt(1);
    14: ;
  else
    halt(1);
  end;
  writeln('ok');
end;
  {$pop}

  { Case tw1061.pp }
  {$push}
begin
   tw1061_vlcnt := 10;
   case tw1061_vlcnt of
   7: writeln(7);
   12,13: begin
            writeln('Case codegeneration error!');
            halt(1);
          end;
   11:writeln(11);
   end;
end;
  {$pop}

  { Case tw1222.pp }
  {$push}
BEGIN
  tw1222_v:=tw1222_c2;
  CASE (tw1222_v AND tw1222_cm) OF
    tw1222_c1,tw1222_c2:writeln('case c1,c2');
    tw1222_c3,tw1222_c4:
    begin
      writeln('case c3,c4');
      halt(1);
    end;
  ELSE
    begin
      writeln('case failed, but it should not');
      halt(1);
    end;
  END;
END;
  {$pop}

end.
