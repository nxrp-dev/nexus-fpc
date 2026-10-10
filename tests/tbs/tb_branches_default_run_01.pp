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

end.
