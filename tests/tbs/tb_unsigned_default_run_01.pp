{ Unsigned integer conversions, formatting, parsing, comparisons and case labels. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0081.pp }
{$push}
{ Old file: tbs0093.pp }
{ Two Cardinal type bugs                                0K 0.99.1 (FK/MvC) }

{ Two cardinal type bugs }
var
  tb0081_c : cardinal;
  tb0081_l : longint;
  tb0081_b : byte;
  tb0081_s : shortint;
  tb0081_w : word;
{$pop}

{ Case tb0088.pp }
{$push}
{ Old file: tbs0104.pp }
{ cardinal greater than $7fffffff aren't written        OK 0.99.1 (FK) }

{ Two cardinal type bugs }
var
  tb0088_c : cardinal;
{$pop}

{ Case tb0199.pp }
{$push}
{ Old file: tbs0235.pp }
{ Val(cardinal) bugs                                    OK 0.99.11 (JM) }

var tb0199_s:string;
    tb0199_w:cardinal;
    tb0199_code:word;
{$pop}

{ Case tb0204.pp }
{$push}
{ Old file: tbs0240.pp }
{ Problems with larges value is case statements        OK 0.99.11 (FK) }

var tb0204_curfilecrc32f : cardinal{Longint};
    tb0204_checkthis : String;
{$pop}

{ Case tb0447a.pp }
{$push}
var
  tb0447a_a : cardinal;
  tb0447a_b : longint;
{$pop}

{ Case tb0358.pp }
{$push}
type
  tb0358___u64 = 0..High(Int64); // Create unsigned Int64 (with 63 bits)
{$pop}

begin
  { Case tb0081.pp }
  {$push}
begin
  tb0081_b:=123;
  tb0081_w:=tb0081_s;
  tb0081_l:=tb0081_b;
  tb0081_c:=tb0081_b;         {generates movzbl %eax,%edx instead of movzbl %al,%edx}

  tb0081_c:=123;
  writeln(tb0081_c);   {Shows '0' outline right! instead of '123' outlined left}
  tb0081_c:=$7fffffff;
  writeln(tb0081_c);   {Shows '0' outline right! instead of '123' outlined left}
end;
  {$pop}

  { Case tb0088.pp }
  {$push}
begin
  tb0088_c:=$80000000;
  writeln(tb0088_c);
  tb0088_c:=$80001234;
  writeln(tb0088_c);
  tb0088_c:=$ffffffff;
  writeln(tb0088_c);
end;
  {$pop}

  { Case tb0199.pp }
  {$push}
begin
    tb0199_s:='192';
    val(tb0199_s,tb0199_w,tb0199_code);
    if tb0199_code<>0 then
        begin
           writeln('Error');
           halt(1);
        end
    else
        writeln(tb0199_w);
end;
  {$pop}

  { Case tb0204.pp }
  {$push}
BEGIN
  tb0204_curfilecrc32f := $C5CAF43C;
  tb0204_checkthis := '';
  Case tb0204_curfilecrc32f of
    $F3DC2AF0 :  tb0204_checkthis := ' First ';
    $27BF798B :  tb0204_checkthis := ' Second ';
    $7BA5BB19 :  tb0204_checkthis := ' Third';
    $FA246A81 :  tb0204_checkthis := ' Forth';
    $8A00B508 :  tb0204_checkthis := ' Fifth';
    $C5CAF43C :  tb0204_checkthis := ' Sixth';
  End;
  Writeln( tb0204_checkthis );
  If tb0204_checkthis<>' Sixth' then halt(1);
END;
  {$pop}

  { Case tb0447a.pp }
  {$push}
begin
  tb0447a_a := 0;
  tb0447a_b := -1;
  if tb0447a_a > tb0447a_b then
    writeln ('OK')
  else
    halt(1);
end;
  {$pop}

  { Case tb0358.pp }
  {$push}
begin
end;
  {$pop}

end.
