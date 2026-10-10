{ Control-character literals, long literal lengths and string concatenation. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0109.pp }
{$push}
{ Old file: tbs0128.pp }
{ problem with ^[                                       OK 0.99.6 (PFV) }

{ ^ followed by a letter must be interpreted differently
  depending on context }

const
   tb0109_arrowkeysorfirstletter='arrow keys '^]^r^z' or First letter.   ';
{$pop}

{ Case tb0124.pp }
{$push}
{ Old file: tbs0143.pp }
{ cannot concat string and array of char in $X+ mode    OK 0.99.7 (PFV) }



const
  tb0124_string1 : string = 'hello ';
  tb0124_string2 : array[1..5] of char = 'there';
var
  tb0124_s : string;
{$pop}

{ Case tb0568.pp }
{$push}
{ this is allowed now, even in $H- mode because '....' is handled as array in this case (FK) }
var
  tb0568_i : integer;
{$pop}

{ Case tb0634.pp }
{$push}
var
  tb0634_s, tb0634_s1, tb0634_s2, tb0634_s3, tb0634_s4: String;
{$pop}

begin
  { Case tb0109.pp }
  {$push}
begin
   writeln(ord(^)));
end;
  {$pop}

  { Case tb0124.pp }
  {$push}
begin
  tb0124_s:=tb0124_string1+tb0124_string2;
  writeln(tb0124_string1+tb0124_string2);
end;
  {$pop}

  { Case tb0568.pp }
  {$push}
begin
  { String constants can't exceed 255 chars }
  tb0568_i:=length('12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890');
  if tb0568_i<>290 then
    halt(1);
end;
  {$pop}

  { Case tb0634.pp }
  {$push}
begin
  tb0634_s := Concat('Hello', ' ', 'World');
  if tb0634_s <> 'Hello World' then
    Halt(1);
  tb0634_s := Concat('Hello');
  if tb0634_s <> 'Hello' then
    Halt(2);
  tb0634_s1 := 'Hello';
  tb0634_s2 := 'Free';
  tb0634_s3 := 'Pascal';
  tb0634_s4 := 'World';
  tb0634_s := Concat(tb0634_s1, ' ', tb0634_s2, ' ', tb0634_s3, ' ', tb0634_s4);
  if tb0634_s <> 'Hello Free Pascal World' then
    Halt(3);
  tb0634_s := Concat(Concat(tb0634_s1, ' ', tb0634_s2), ' ', Concat(tb0634_s3, ' ', tb0634_s4));
  if tb0634_s <> 'Hello Free Pascal World' then
    Halt(4);
  Writeln('ok');
end;
  {$pop}

end.
