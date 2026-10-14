{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode fpc}


{ Source group: tb_char_literals_default_run_01.pas }
{$push}

{ Case tb0242.pas }
{$push}
{ Old file: tbs0283.pas }
{ bugs in constant char comparison evaluation           OK 0.99.13 (PFV) }

const tb0242_dirsep = '\';
{$pop}

{ Case tb0245.pas }
{$push}
{ Old file: tbs0286.pas }
{ #$08d not allowed as Char constant                   OK 0.99.13 (PFV) }

var
  tb0245_c : char;
{$pop}

{ Case tb0315.pas }
{$push}
{ test for const string that is a char }

const
    tb0315_c ='D';
    tb0315_d = 'AD';
    tb0315_pp : string[length(tb0315_d)] = tb0315_d;
    tb0315_p : String[length(tb0315_c)] = tb0315_c;
{$pop}

{ Case tb0337.pas }
{$push}
var
  tb0337_s : string;
{$pop}

{ Case tb0353.pas }
{$push}
const
      tb0353_c1 = widechar(0);
      tb0353_c2 = widechar(#0);
      tb0353_c3 = #123;
      tb0353_c4 = #1234;
{$pop}

{ Case tb0381.pas }
{$push}
var
   tb0381_w : widechar;
{$pop}

{ Case tb0187.pas }
{$push}
{ Old file: tbs0221.pas }
{ syntax parsing incompatibilities with tp7            OK 0.99.11 (PFV) }


var
  tb0187_r : double;
  tb0187_c : char;
{$pop}

{ Case tb0294.pas }
{$push}
{ Old file: tbs0350.pas }
{  }

var
  tb0294_c : char;
  tb0294_i : integer;
{$pop}

{ Case tb0401.pas }
{$push}
var
   tb0401_b1,tb0401_b2 : boolean;
   tb0401_c : char;
{$pop}


{$pop}

{ Source group: tb_string_literals_default_run_01.pas }
{$push}

{ Case tb0109.pas }
{$push}
{ Old file: tbs0128.pas }
{ problem with ^[                                       OK 0.99.6 (PFV) }

{ ^ followed by a letter must be interpreted differently
  depending on context }

const
   tb0109_arrowkeysorfirstletter='arrow keys '^]^r^z' or First letter.   ';
{$pop}

{ Case tb0124.pas }
{$push}
{ Old file: tbs0143.pas }
{ cannot concat string and array of char in $X+ mode    OK 0.99.7 (PFV) }



const
  tb0124_string1 : string = 'hello ';
  tb0124_string2 : array[1..5] of char = 'there';
var
  tb0124_s : string;
{$pop}

{ Case tb0568.pas }
{$push}
{ this is allowed now, even in $H- mode because '....' is handled as array in this case (FK) }
var
  tb0568_i : integer;
{$pop}

{ Case tb0634.pas }
{$push}
var
  tb0634_s, tb0634_s1, tb0634_s2, tb0634_s3, tb0634_s4: String;
{$pop}

{ Case tb0333.pas }
{$push}
{ Old file: tbs0001.pas }
{  tests a bugs in the .ascii output (#0 and too long)  OK 0.9.2 }

  const
      tb0333_teststr : string = ' '#9#255#0;
{$pop}

{ Case tb0078.pas }
{$push}
{ Old file: tbs0090.pas }
{  shows PChar comparison problem                        OK 0.99.7 (PFV) }

{$X+}
var
 tb0078_mystr : array[0..4] of char;
{$pop}


{$pop}

{ Source group: tb_string_operations_default_run_01.pas }
{$push}

{ Case tb0503.pas }
{$push}
procedure tb0503_testansi;
var
  s, q: ansistring;
begin
  s := 'hell';
  s := s+'o';
  q := '"';
  q := q+'''';
  s := s + q + s + 'abc';
  if (s <> 'hello"''helloabc') then
    halt(1);
  s := 'hell';
  s := s+'o';
  s := q+s+q;
  if (s <> '"''hello"''') then
    halt(2);
end;


procedure tb0503_testshort;
var
  s, q: shortstring;
begin
  s := 'hell';
  s := s+'o';
  q := '"';
  q := q+'''';
  s := s + q + s + 'abc';
  if (s <> 'hello"''helloabc') then
    halt(3);
  s := 'hell';
  s := s+'o';
  s := q+s+q;
  if (s <> '"''hello"''') then
    halt(4);
end;
{$pop}

{ Case tb0619.pas }
{$push}
var
  tb0619_ss: ShortString;
  tb0619_us: UnicodeString;
  tb0619_ws: WideString;
  tb0619_as: AnsiString;
  tb0619_i: LongInt;
{$pop}

{ Case tb0714.pas }
{$push}
var
  tb0714_s : string[20];
{$pop}


{$pop}

{ Source group: tb_string_conversions_fpc_run_01.pas }
{$push}

{ Case tb0413.pas }
{$push}
var
   tb0413_s : ansistring;
   tb0413_ss : shortstring;
   tb0413_as : ansistring;
   tb0413_c : char;
{$pop}

{ Case tb0441.pas }
{$push}
operator :=(tb0441_x:ShortInt)RESULT:ShortString;
  begin
    Val(RESULT,tb0441_x);
  end;

var
  tb0441_s:ShortString;
{$pop}


{$pop}

begin
  { Source group: tb_char_literals_default_run_01.pas }
  {$push}


begin
  { Case tb0242.pas }
  {$push}
begin
  if tb0242_dirsep = '/'
    then
      begin
        writeln('bug!');
        Halt(1);
      end
    else
      writeln('ok');
end;
  {$pop}

  { Case tb0245.pas }
  {$push}
begin
  tb0245_c:=#$08d;
end;
  {$pop}

  { Case tb0315.pas }
  {$push}
begin
end;
  {$pop}

  { Case tb0337.pas }
  {$push}
begin
  tb0337_s:={$ifdef fpc}'~[v]~'{$else}'~['#25']~'{$endif};
end;
  {$pop}

  { Case tb0353.pas }
  {$push}
begin
end;
  {$pop}

  { Case tb0381.pas }
  {$push}
begin
   case tb0381_w of
      'A' : ;
      'B' : ;
      #1234: ;
      #8888: ;
      #8889..#9999: ;
      'Z'..'a': ;
   end;
end;
  {$pop}

  { Case tb0187.pas }
  {$push}
begin
  tb0187_r:=1.;
  tb0187_c:=^.; { this compile in tp7, c should contain 'n'/#110 }
  if tb0187_c<>#110 then
    begin
       Writeln('FPC does not support ^. character!');
       Halt(1);
    end;
end;
  {$pop}

  { Case tb0294.pas }
  {$push}
begin
  tb0294_i:=integer(tb0294_c);
  tb0294_c:=char(tb0294_i);
end;
  {$pop}

  { Case tb0401.pas }
  {$push}
begin
   tb0401_b1:=false;
   tb0401_b2:=true;
   tb0401_c:=char(tb0401_b1 and tb0401_b2);
   if tb0401_c<>#0 then
     halt(1);
   tb0401_c:=char(tb0401_b1 or tb0401_b2);
   if tb0401_c<>#1 then
     halt(1);
   tb0401_c:=char(tb0401_b1);
   if tb0401_c<>#0 then
     halt(1);
   tb0401_c:=char(tb0401_b2);
   if tb0401_c<>#1 then
     halt(1);
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_string_literals_default_run_01.pas }
  {$push}


begin
  { Case tb0109.pas }
  {$push}
begin
   writeln(ord(^)));
end;
  {$pop}

  { Case tb0124.pas }
  {$push}
begin
  tb0124_s:=tb0124_string1+tb0124_string2;
  writeln(tb0124_string1+tb0124_string2);
end;
  {$pop}

  { Case tb0568.pas }
  {$push}
begin
  { String constants can't exceed 255 chars }
  tb0568_i:=length('12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890');
  if tb0568_i<>290 then
    halt(1);
end;
  {$pop}

  { Case tb0634.pas }
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

  { Case tb0333.pas }
  {$push}
begin
      writeln(tb0333_teststr);
      tb0333_teststr := 'gaga';
      writeln(tb0333_teststr);
      if tb0333_teststr<>'gaga' then halt(1);
end;
  {$pop}

  { Case tb0078.pas }
  {$push}
{$X+}
Begin
  if tb0078_mystr = #0#0#0#0 then
  Begin
  end;
  tb0078_mystr:=#0#0#0#0;
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_string_operations_default_run_01.pas }
  {$push}


begin
  { Case tb0503.pas }
  {$push}
begin
  tb0503_testansi;
  tb0503_testshort;
end;
  {$pop}

  { Case tb0619.pas }
  {$push}
begin
  tb0619_ss := 'Test';
  Delete(tb0619_ss, 2, 1);
  if tb0619_ss <> 'Tst' then
    Halt(1);
  Insert('Foo', tb0619_ss, 2);
  if tb0619_ss <> 'TFoost' then
    Halt(2);

  tb0619_us := 'Test';
  Delete(tb0619_us, 2, 1);
  if tb0619_us <> 'Tst' then
    Halt(3);
  Insert('Foo', tb0619_us, 2);
  if tb0619_ss <> 'TFoost' then
    Halt(4);

  tb0619_ws := 'Test';
  Delete(tb0619_ws, 2, 1);
  if tb0619_ws <> 'Tst' then
    Halt(5);
  Insert('Foo', tb0619_ws, 2);
  if tb0619_ss <> 'TFoost' then
    Halt(6);

  tb0619_as := 'Test';
  Delete(tb0619_as, 2, 1);
  if tb0619_as <> 'Tst' then
    Halt(7);
  Insert('Foo', tb0619_as, 2);
  if tb0619_ss <> 'TFoost' then
    Halt(8);

  tb0619_ss := 'Test';
  Insert(#$41, tb0619_ss, 2);
  if tb0619_ss <> 'TAest' then
    Halt(9);
end;
  {$pop}

  { Case tb0714.pas }
  {$push}
begin
  setlength(tb0714_s,21);
  if length(tb0714_s)>sizeof(tb0714_s)-1 then
    halt(1);
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_string_conversions_fpc_run_01.pas }
  {$push}


begin
  { Case tb0413.pas }
  {$push}
begin
   tb0413_as:='ansistring';
   tb0413_ss:='shortstring';
   tb0413_c:='C';
   tb0413_s:=tb0413_s+tb0413_as;
   tb0413_s:=tb0413_s+tb0413_c;
   tb0413_s:=tb0413_s+tb0413_ss;
   tb0413_s:=tb0413_s+tb0413_s;
   if tb0413_s<>'ansistringCshortstringansistringCshortstring' then
     begin
        writeln('Problem with ansistring appending');
        halt(1);
     end;
end;
  {$pop}

  { Case tb0441.pas }
  {$push}
begin
  tb0441_s:=12;
end;
  {$pop}


end;
  {$pop}

end.
