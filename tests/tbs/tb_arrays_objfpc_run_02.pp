{ Arrays regression cases; original case IDs are retained below. }

{ Case tw3621.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3621 }
{ Submitted by "Thomas Schatzl" on  2005-02-01 }
{ e-mail:  }
{$MODE OBJFPC}
type
        tw3621_tfourcc=array[0..3] of char;

FUNCTION comp(f1, f2:tw3621_tfourcc):boolean;
BEGIN
  comp:=((f1[0]=f2[0]) AND (f1[1]=f2[1]) AND (f1[2]=f2[2]) AND (f1[3]=f2[3]));
END;
{$pop}

{ Case tw36389.pp }
{$push}
{$inline on}
{$mode objfpc}
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

{ Case tw37272a.pp }
{$push}
{ note: there is a tw37272b in webtbf }

{$mode objfpc}

type
  tw37272a_ta1 = array of integer;

procedure tw37272a_test(A: integer; const tw37272a_b: tw37272a_ta1 = []);
begin end;
{$pop}

{ Case tw4219.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4219 }
{ Submitted by "Marijn Kruisselbrink" on  2005-07-25 }
{ e-mail: mkruisselbrink@hexis.nl }

{$mode objfpc}

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

{ Case tw4599.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4599 }
{ Submitted by "Sam" on  2005-12-14 }
{ e-mail: sam_herzog@yahoo.com }

{$mode objfpc}

procedure tw4599_trace(_level:byte;tw4599__msg:String;tw4599__params:array of const);
var
  tw4599_i : integer;
begin
    tw4599_i:=SizeOf(tw4599__params);
end;
{$pop}

begin
  { Case tw3621.pp }
  {$push}

  begin
comp('ABCD', 'DEFG');
  end;
  {$pop}

  { Case tw37272a.pp }
  {$push}

  begin
tw37272a_test(1, []);
  tw37272a_test(1);
  end;
  {$pop}

  { Case tw4219.pp }
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

end.
