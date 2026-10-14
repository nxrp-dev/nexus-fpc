{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0429.pas }
{$push}

var
  tb0429_err : boolean;

procedure tb0429_test(c:char);overload;
begin
  writeln('char');
end;
procedure tb0429_test(c:shortstring);overload;
begin
  writeln('short');
end;
procedure tb0429_test(c:ansistring);overload;
begin
  writeln('ansi');
  tb0429_err:=false;
end;

var
  tb0429_w : widestring;
  tb0429_s : ansistring;
  tb0429_i : longint;

{$pop}

{ Case tb_val_unsigned_string_widths.pas }
{$push}
{ Unsigned Val must honor destination width for every string representation. }
{$Q-}
{$R-}

procedure tb_val_unsigned_string_widths_Check(const Kind, Input: ShortString; Actual: QWord;
  Code: Integer; Expected: QWord; Valid: Boolean);
begin
  if (Valid and ((Code<>0) or (Actual<>Expected))) or
     ((not Valid) and (Code=0)) then
    begin
      writeln(Kind, ' input="', Input, '" code=', Code, ' value=', Actual);
      halt(1);
    end;
end;

procedure tb_val_unsigned_string_widths_TestByte(const Input: ShortString; Expected: QWord; Valid: Boolean);
var
  A: AnsiString;
  W: WideString;
  U: UnicodeString;
  Value: Byte;
  Code: Integer;
begin
  A:=Input;
  W:=Input;
  U:=Input;
  Val(Input,Value,Code);
  tb_val_unsigned_string_widths_Check('ShortString/Byte',Input,Value,Code,Expected,Valid);
  Val(A,Value,Code);
  tb_val_unsigned_string_widths_Check('AnsiString/Byte',Input,Value,Code,Expected,Valid);
  Val(W,Value,Code);
  tb_val_unsigned_string_widths_Check('WideString/Byte',Input,Value,Code,Expected,Valid);
  Val(U,Value,Code);
  tb_val_unsigned_string_widths_Check('UnicodeString/Byte',Input,Value,Code,Expected,Valid);
end;

procedure tb_val_unsigned_string_widths_TestWord(const Input: ShortString; Expected: QWord; Valid: Boolean);
var
  A: AnsiString;
  W: WideString;
  U: UnicodeString;
  Value: Word;
  Code: Integer;
begin
  A:=Input;
  W:=Input;
  U:=Input;
  Val(Input,Value,Code);
  tb_val_unsigned_string_widths_Check('ShortString/Word',Input,Value,Code,Expected,Valid);
  Val(A,Value,Code);
  tb_val_unsigned_string_widths_Check('AnsiString/Word',Input,Value,Code,Expected,Valid);
  Val(W,Value,Code);
  tb_val_unsigned_string_widths_Check('WideString/Word',Input,Value,Code,Expected,Valid);
  Val(U,Value,Code);
  tb_val_unsigned_string_widths_Check('UnicodeString/Word',Input,Value,Code,Expected,Valid);
end;

procedure tb_val_unsigned_string_widths_TestDWord(const Input: ShortString; Expected: QWord; Valid: Boolean);
var
  A: AnsiString;
  W: WideString;
  U: UnicodeString;
  Value: DWord;
  Code: Integer;
begin
  A:=Input;
  W:=Input;
  U:=Input;
  Val(Input,Value,Code);
  tb_val_unsigned_string_widths_Check('ShortString/DWord',Input,Value,Code,Expected,Valid);
  Val(A,Value,Code);
  tb_val_unsigned_string_widths_Check('AnsiString/DWord',Input,Value,Code,Expected,Valid);
  Val(W,Value,Code);
  tb_val_unsigned_string_widths_Check('WideString/DWord',Input,Value,Code,Expected,Valid);
  Val(U,Value,Code);
  tb_val_unsigned_string_widths_Check('UnicodeString/DWord',Input,Value,Code,Expected,Valid);
end;

procedure tb_val_unsigned_string_widths_TestQWord(const Input: ShortString; Expected: QWord; Valid: Boolean);
var
  A: AnsiString;
  W: WideString;
  U: UnicodeString;
  Value: QWord;
  Code: Integer;
begin
  A:=Input;
  W:=Input;
  U:=Input;
  Val(Input,Value,Code);
  tb_val_unsigned_string_widths_Check('ShortString/QWord',Input,Value,Code,Expected,Valid);
  Val(A,Value,Code);
  tb_val_unsigned_string_widths_Check('AnsiString/QWord',Input,Value,Code,Expected,Valid);
  Val(W,Value,Code);
  tb_val_unsigned_string_widths_Check('WideString/QWord',Input,Value,Code,Expected,Valid);
  Val(U,Value,Code);
  tb_val_unsigned_string_widths_Check('UnicodeString/QWord',Input,Value,Code,Expected,Valid);
end;


{$pop}

{ Case tw0797b.pas }
{$push}

{$INLINE ON}

var
  tw0797b_s2 : string;
  tw0797b_j : longint;

  procedure tw0797b_Tst(s: ShortString;var tw0797b_j : longint); inline;
  var
    i : longint;
  begin
    s:=s + ' Yes';
    i:=5;
    tw0797b_j:=tw0797b_j+i;
    WriteLn(s);
    tw0797b_s2:=s;
  end;

{$pop}

{ Case tw0935.pas }
{$push}
{$inline on}

procedure tw0935_test(v:boolean);

 procedure notice(s:string);inline;
 begin
 writeln(s);
 end;

begin
if v then notice('this string vanishes.');
writeln('"test" main body executed.');
end;




{$pop}

{ Case tw1348.pas }
{$push}
type tw1348_mitem=array[0..8] of string[16];
     tw1348_tstr16=string[16];

const tw1348_chdiv:array[0..8] of string
      =('Eclipse','Elongation','Occultation','Conjonction',' Lever',
        'Satellites',' Binaire',' Visibilit‚','Courbe');
const tw1348_ch:array[0..8] of integer=
       (0,1,2,3,4,5,6,7,8);
var
  tw1348_Error : boolean;

Procedure tw1348_affmenu(const Rr:array of string);
 var i,j:integer;
 Begin
  i:=0;j:=high(Rr);writeln(j);
  {rr[j div 2]:='Modif';}
   while (i<=j) do
    begin
     writeln(length(RR[i]));
     writeln(Rr[i]);inc(i);
    end;
  if RR[6]<>' Binaire' then
   tw1348_Error:=true;
End;

Procedure tw1348_affint(const Rr:array of integer);
 var i,j:integer;
 Begin
  i:=0;j:=high(Rr);writeln(j);
    while (i<=j) do
    begin
    writeln(Rr[i]);inc(i);
    end;
End;


Procedure tw1348_affm(Rr:tw1348_tstr16);
Begin
  writeln(Rr);
End;


{$pop}

{ Case tw1416.pas }
{$push}
var tw1416_s:ansistring;

{$pop}

{ Case tw1430.pas }
{$push}
{ Source provided for Free Pascal Bug Report 1430 }
{ Submitted by "Keith R. Bolson" on  2001-03-07 }
{ e-mail: krbolson@visi.com }



PROCEDURE tw1430_DoType( b :BOOLEAN; t,f: STRING);
BEGIN
  IF b THEN writeln(t) ELSE writeln(f);
  if b then
    halt(1);
END;

VAR
  tw1430_ax, tw1430_ay: Char;


{$pop}

{ Case tw14740.pas }
{$push}
var
  tw14740_w: widestring;
  tw14740_u: unicodestring;
  tw14740_pw: pwidechar;
  tw14740_pu: punicodechar;
  tw14740_p: pchar;

{$pop}

{ Case tw14941.pas }
{$push}

{$V+}
var
   tw14941_s    :String;

procedure tw14941_P( tw14941_s: OpenString);
begin
  writeln(tw14941_s);
  if (high(tw14941_s)<>255) or
     (tw14941_s<>'12345') then
    halt(1);
end;


{$pop}

{ Case tw16130.pas }
{$push}
var
  tw16130_S :String;

{$pop}

{ Case tw16377.pas }
{$push}

const
  tw16377_S: string = '123';
var
  tw16377_I: Integer;
  tw16377_P: PChar;

{$pop}

{ Case tw2069.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2069 }
{ Submitted by "Sergey Kosarevsky" on  2002-08-07 }
{ e-mail: netsurfer@au.ru }
Const tw2069_WhiteSpace = [' ',#0,#1,#2,#3,#4,#5,#6,#7,#8,#9,#10,#11,#12,#13,#14,#15,#16,#17,#18,#19,#20,#21,#22,#23,#24,#25,#26,#27,#28,#29,#30,#31];

Function tw2069_Trim(Const S:String):String;
Var Ofs,Len:Integer;
Begin
   Len:=Length(S);
   While (Len>0) And
         (S[Len] In tw2069_WhiteSpace) Do Dec(Len);
   Ofs:=1;
   While (Ofs<=Len) And
         (S[Ofs] In tw2069_WhiteSpace) Do Inc(Ofs);
   Exit(Copy(S,Ofs,1+Len-Ofs));
End;


{$pop}

{ Case tw2163.pas }
{$push}

type tw2163_oo2 = pchar;

var tw2163_a: tw2163_oo2;

function tw2163_len(tw2163_a:pchar):longint;
begin
  tw2163_len:=-1;
end;


{$pop}

{ Case tw2250.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2250 }
{ Submitted by "Konstantin Seiler" on  2002-12-04 }
{ e-mail: list@kseiler.de }
procedure tw2250_stringbug;
var env:ansistring;
  procedure addenv(s:ansistring);
  begin
  // Uncomment next line and everything works as expected.
  //writeln(length(env));
      if length(env)=0 then env:=s
                       else env:=env+'|'+s;
  end;

begin
  env:='';
  addenv('first');
  addenv('second');
  addenv('third');
  // It should write "first|second|third",
  // but only writes "third".
  writeln(env);
  if env<>'first|second|third' then
   begin
     writeln('ERROR!');
     halt(1);
   end;
end;


{$pop}

{ Case tw22936.pas }
{$push}


var
  tw22936_s: ansistring;
  tw22936_i : integer;


{$pop}

{ Case tw2294.pas }
{$push}
{$H+}
const tw2294_trap : pchar = 'boese Falle';
var  tw2294_s : ansistring;

{$pop}

{ Case tw23136.pas }
{$push}
var
 tw23136_ws:widestring;
 tw23136_s:string;

{$pop}

{ Case tw23744.pas }
{$push}
var
  tw23744_S:String[16];
  tw23744_C:Char = '?';
  tw23744_inss: string = 'abc';

{$pop}

{ Case tw2388.pas }
{$push}


var
  tw2388_err : boolean;

procedure tw2388_check(const s:string;b:boolean);
begin
  writeln(s,b);
  if not b then
    begin
      tw2388_err:=true;
      writeln('error!');
    end;
end;

Var tw2388_SS : ShortString;
    tw2388_AS : AnsiString;


{$pop}

{ Case tw2473.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2473 }
{ Submitted by "julien" on  2003-04-25 }
{ e-mail: jfiiz@aol.com }

function tw2473_afunc (line : ansistring; var i : qword)  : qword;
begin
  if (i>length(line[i])) then
    writeln('hello');
  tw2473_afunc:=0;
end;


{$pop}

{ Case tw25332.pas }
{$push}

{mode delphiunicode}

const tw25332_r: rawbytestring = 'abc';

{$pop}

{ Case tw2540.pas }
{$push}
var
  tw2540_C : Char;
  tw2540_S : AnsiString;

{$pop}

{ Case tw2765.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2765 }
{ Submitted by "Michael Van Canneyt" on  2003-11-04 }
{ e-mail: michael.vancanneyt‚wisa.be }


var
  tw2765_P : PWideChar;
  tw2765_PA : PChar;
  tw2765_S,tw2765_T : AnsiString;


{$pop}

{ Case tw28372.pas }
{$push}
var
  tw28372_s: string;
  tw28372_res: boolean;

{$pop}

{ Case tw2975.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2975 }
{ Submitted by "Michalis Kamburelis" on  2004-02-15 }
{ e-mail: michalis@camelot.homedns.org }
procedure tw2975_p;
const
  t:array[0..0]of AnsiString = ('blah');
begin
 Writeln('''', t[0], '''');
  if t[0]='' then
    halt(1);
end;


{$pop}

{ Case tw30007.pas }
{$push}


{$r+}

function tw30007_LinesToText(Lines: array of String): String;
begin
end;

var
  tw30007_SomeLines: array of String;

{$pop}

{ Case tw3174.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3174 }
{ Submitted by "C Western" on  2004-06-19 }
{ e-mail: mftq75@dsl.pipex.com }


procedure tw3174_Mumble(s: PChar);
begin
  WriteLn(s^);
  if s^<>'A' then
    halt(1);
end;


{$pop}

{ Case tw32034.pas }
{$push}


{$H-}

var
  tw32034_s: String;

{$pop}

{ Case tw3328b.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3328 }
{ Submitted by "Christian Iversen" on  2004-09-21 }
{ e-mail: chrivers@iversen-net.dk }


var
  tw3328b_err : boolean;

Function tw3328b_A(Const S2: AnsiString): Integer; Overload;
Begin
  writeln('ansistring overload');
  tw3328b_err:=false;
End;

Function tw3328b_A(Const S2: UnicodeString): Integer; Overload;
Begin
  writeln('unicodestring overload');
End;

Var
  tw3328b_X : PAnsiChar;

{$pop}

{ Case tw3523.pas }
{$push}
type
  tw3523_tstr255 = string[255];

procedure tw3523_ttt(i1:integer;s1:tw3523_tstr255;b1:byte;i2:integer;
  i3:integer;i4:integer;c1:char;s2,s3,s4,s5:tw3523_tstr255);

begin
     if (i1 <> 1) or
        (s1 <> 'test1') or
        (b1 <> 1) or
        (i2 <> 2) or
        (i3 <> 3) or
        (i4 <> 4) or
        (c1 <> 'A') or
        (s2 <> 'test2') or
        (s3 <> 'test3') or
        (s4 <> 'test4') or
        (s5 <> 'test5') then
      halt(1);
end;


{$pop}

{ Case tw3554.pas }
{$push}
{$R+}

function tw3554_d(a,b:string):Integer;
begin
  tw3554_d := Ord(a[1])-Ord(b[1]);
end;

var
  tw3554_c: SmallInt;
  tw3554_ch : char;

{$pop}

{ Case tw40894.pas }
{$push}

{$ZEROBASEDSTRINGS ON}
{$H+} // make sure it is AnsiString, not ShortString
{$R+}

Var
  tw40894_I: Integer;
  tw40894_S: String;

{$pop}

{ Case tw4162.pas }
{$push}

Var
  tw4162_S: ansistring;
  tw4162_SS: shortstring;

{$pop}

{ Case tw4272.pas }
{$push}
procedure tw4272_go(const w: widestring);overload;
begin
writeln('wide: ',w);
end;

procedure tw4272_go(const w: shortstring);overload;
begin
writeln('short: ',w);
end;

var
  tw4272_s: ansistring;

{$pop}

{ Case tw4427.pas }
{$push}
{$inline on}

procedure tw4427_test(p: pchar);
begin
  if pchar(p)^ <> 'a' then
    halt(1);
end;

procedure tw4427_test(const p); inline;
begin
  tw4427_test(pchar(@p));
end;


{$pop}

{ Case tw4925.pas }
{$push}
var
  tw4925_s : string;

{$pop}

{ Case tw8049.pas }
{$push}


{$Q+}

const tw8049_s:array[0..31] of char='Hell* world';
	  tw8049_index:longint=-6;

var tw8049_c:char;
    tw8049_p,tw8049_q:Pchar;


{$pop}

{ Case tw8321.pas }
{$push}
{ Explicitly disable range and overflow checks for this test }

{$Q-}
{$R-}


var
 tw8321_A: byte;
 tw8321_w : word;
 tw8321_B,tw8321_B2: cardinal;
 tw8321_s  : string;
 tw8321_p : pointer;
 tw8321_err : boolean;

{$pop}

{ Case tw8838.pas }
{$push}
var
  tw8838_c,tw8838_u: char;
  tw8838_s,tw8838_t: string[6];

{$pop}

{ Case tw9187.pas }
{$push}
var
 tw9187_wstr1: widestring;

procedure tw9187_testproc(const avalue: widestring);
begin
 tw9187_wstr1:= avalue;
end;

var
  tw9187_i: longint;
  tw9187_w2: widestring;


{$pop}

{ Case tw9190.pas }
{$push}
var
  tw9190_wstr1: widestring;
  tw9190_i: longint;
  tw9190_w2,tw9190_w3: widestring;

procedure tw9190_testproc2(w: widestring);
begin
  tw9190_wstr1:=w;
end;

procedure tw9190_testproc1(const w: widestring);
begin
  tw9190_w2:='';
  tw9190_testproc2(w);
  if pointer(w)<>pointer(tw9190_wstr1) then begin
    writeln('Test failed!');
    Halt(1);
  end;
  if w<>tw9190_w3 then begin
    writeln('Test failed!');
    Halt(1);
  end;
end;


{$pop}

{ Case tw9897.pas }
{$push}


var
  tw9897_AText : WideString;
  tw9897_AWideChar: PWideChar;


{$pop}

begin

{ Case tb0429.pas }
{$push}

begin
  tb0429_err:=true;
  { this should choosse the ansistring version }
  tb0429_w:='';
  for tb0429_i:=1 to 300 do tb0429_w:=tb0429_w+'.';
  tb0429_test(tb0429_w);
  if tb0429_err then
   begin
     writeln('Wrong lowercase Error!');
     halt(1);
   end;

   { check if ansistring pos() call is not broken }
   tb0429_s:='';
   for tb0429_i:=1 to 300 do tb0429_s:=tb0429_s+'.';
   tb0429_s:=tb0429_s+'test';
   if pos('test',tb0429_s)<>301 then
    begin
      writeln('Pos(ansistring) Error!');
      halt(1);
    end;

end;
{$pop}

{ Case tb_val_unsigned_string_widths.pas }
{$push}
{$Q-}
{$R-}
begin
  tb_val_unsigned_string_widths_TestByte('0',0,true);
  tb_val_unsigned_string_widths_TestByte('255',High(Byte),true);
  tb_val_unsigned_string_widths_TestByte('256',0,false);
  tb_val_unsigned_string_widths_TestByte('$FF',High(Byte),true);
  tb_val_unsigned_string_widths_TestByte('$100',0,false);
  tb_val_unsigned_string_widths_TestByte('&377',High(Byte),true);
  tb_val_unsigned_string_widths_TestByte('&400',0,false);
  tb_val_unsigned_string_widths_TestByte('%11111111',High(Byte),true);
  tb_val_unsigned_string_widths_TestByte('%100000000',0,false);
  tb_val_unsigned_string_widths_TestByte('+255',High(Byte),true);
  tb_val_unsigned_string_widths_TestByte('-1',0,false);
  tb_val_unsigned_string_widths_TestByte('',0,false);
  tb_val_unsigned_string_widths_TestByte('12z',0,false);
  tb_val_unsigned_string_widths_TestWord('0',0,true);
  tb_val_unsigned_string_widths_TestWord('65535',High(Word),true);
  tb_val_unsigned_string_widths_TestWord('65536',0,false);
  tb_val_unsigned_string_widths_TestWord('$FFFF',High(Word),true);
  tb_val_unsigned_string_widths_TestWord('$10000',0,false);
  tb_val_unsigned_string_widths_TestWord('&177777',High(Word),true);
  tb_val_unsigned_string_widths_TestWord('&200000',0,false);
  tb_val_unsigned_string_widths_TestWord('%1111111111111111',High(Word),true);
  tb_val_unsigned_string_widths_TestWord('%10000000000000000',0,false);
  tb_val_unsigned_string_widths_TestWord('+65535',High(Word),true);
  tb_val_unsigned_string_widths_TestWord('-1',0,false);
  tb_val_unsigned_string_widths_TestWord('',0,false);
  tb_val_unsigned_string_widths_TestWord('12z',0,false);
  tb_val_unsigned_string_widths_TestDWord('0',0,true);
  tb_val_unsigned_string_widths_TestDWord('4294967295',High(DWord),true);
  tb_val_unsigned_string_widths_TestDWord('4294967296',0,false);
  tb_val_unsigned_string_widths_TestDWord('$FFFFFFFF',High(DWord),true);
  tb_val_unsigned_string_widths_TestDWord('$100000000',0,false);
  tb_val_unsigned_string_widths_TestDWord('&37777777777',High(DWord),true);
  tb_val_unsigned_string_widths_TestDWord('&40000000000',0,false);
  tb_val_unsigned_string_widths_TestDWord('%11111111111111111111111111111111',High(DWord),true);
  tb_val_unsigned_string_widths_TestDWord('%100000000000000000000000000000000',0,false);
  tb_val_unsigned_string_widths_TestDWord('+4294967295',High(DWord),true);
  tb_val_unsigned_string_widths_TestDWord('-1',0,false);
  tb_val_unsigned_string_widths_TestDWord('',0,false);
  tb_val_unsigned_string_widths_TestDWord('12z',0,false);
  tb_val_unsigned_string_widths_TestQWord('0',0,true);
  tb_val_unsigned_string_widths_TestQWord('18446744073709551615',High(QWord),true);
  tb_val_unsigned_string_widths_TestQWord('18446744073709551616',0,false);
  tb_val_unsigned_string_widths_TestQWord('$FFFFFFFFFFFFFFFF',High(QWord),true);
  tb_val_unsigned_string_widths_TestQWord('$10000000000000000',0,false);
  tb_val_unsigned_string_widths_TestQWord('&1777777777777777777777',High(QWord),true);
  tb_val_unsigned_string_widths_TestQWord('&2000000000000000000000',0,false);
  tb_val_unsigned_string_widths_TestQWord('%1111111111111111111111111111111111111111111111111111111111111111',High(QWord),true);
  tb_val_unsigned_string_widths_TestQWord('%10000000000000000000000000000000000000000000000000000000000000000',0,false);
  tb_val_unsigned_string_widths_TestQWord('+18446744073709551615',High(QWord),true);
  tb_val_unsigned_string_widths_TestQWord('-1',0,false);
  tb_val_unsigned_string_widths_TestQWord('',0,false);
  tb_val_unsigned_string_widths_TestQWord('12z',0,false);
end;
{$pop}

{ Case tw0797b.pas }
{$push}
{$INLINE ON}
begin
   tw0797b_s2:='Before inline';
   tw0797b_j:=5;
   tw0797b_Tst('Hello Hello Hello',tw0797b_j);
   if (tw0797b_s2<>'Hello Hello Hello Yes') or (tw0797b_j<>10) then
     begin
       if (tw0797b_s2<>'Hello Hello Hello Yes') then
         writeln('s2 = ',tw0797b_s2);
       if (tw0797b_j<>10) then
         writeln('j = ',tw0797b_s2);
       halt(1);
     end;
end;
{$pop}

{ Case tw0935.pas }
{$push}
{$inline on}
begin
writeln('testing with True...');
tw0935_test(true);
writeln;
writeln('testing with False...');
tw0935_test(false);
end;
{$pop}

{ Case tw1348.pas }
{$push}

Begin
 tw1348_affm(tw1348_chdiv[8]);
 tw1348_affint(tw1348_ch);
 writeln('suite');
 tw1348_affmenu(tw1348_chdiv);
 writeln('Fin');
 if tw1348_Error then
  begin
    writeln('ERROR!');
    halt(1);
  end;
End;
{$pop}

{ Case tw1416.pas }
{$push}

begin
  tw1416_s:='TeSt....10........20........30'+
  '........40........50'+
  '........60........70........80'+
  '........90.......100'+
  '.......110.......120.......130'+
  '.......140.......150'+
  '.......160.......170.......180'+
  '.......190.......200'+
  '.......210.......220.......230'+
  '.......240.......250'+
  '.......260.......270.......280'+
  '.......290.......300';
  writeln(tw1416_s);
  writeln(upcase(tw1416_s));
  writeln(lowercase(tw1416_s));
  if (length(upcase(tw1416_s))<length(tw1416_s)) or (length(lowercase(tw1416_s))<length(tw1416_s)) then
   begin
     writeln('ERROR');
     halt(1);
   end;
end;
{$pop}

{ Case tw1430.pas }
{$push}

BEGIN
  tw1430_ax := 'X';  tw1430_ay := 'Y';
  tw1430_DoType( ( ([tw1430_ax, tw1430_ay] * ['A','C','D']) <> []), 'yes', 'no');
END;
{$pop}

{ Case tw14740.pas }
{$push}

begin
  tw14740_pw:='abc'#0'def';
  setstring(tw14740_w,tw14740_pw,7);
  if tw14740_w<>'abc'#0'def' then
    halt(1);
  tw14740_w:='';

  tw14740_pu:='abc'#0'def';
  setstring(tw14740_u,tw14740_pu,7);
  if tw14740_u<>'abc'#0'def' then
    halt(2);
  tw14740_u:='';

  tw14740_p:='abc'#0'def';
  setstring(tw14740_w,tw14740_p,7);
  if tw14740_w<>'abc'#0'def' then
    halt(3);

  setstring(tw14740_u,tw14740_p,7);
  if tw14740_u<>'abc'#0'def' then
    halt(4);
end;
{$pop}

{ Case tw14941.pas }
{$push}
{$V+}
begin
  tw14941_P('12345');
  tw14941_s:='12345';
  tw14941_p(tw14941_s);
  {Won't compile.
  FPC or Turbo Pascal mode:  Internal error 200405241
  Delphi mode:  Signal 291.  Save files and restart IDE.  (Can't save.)}
end;
{$pop}

{ Case tw16130.pas }
{$push}

begin
  tw16130_S := 'H';
  case tw16130_S of
    'HH','H': WriteLn('1');
  end;
  tw16130_S := 'HH';
  case tw16130_S of
    'HH': WriteLn('2');
  end;
  case tw16130_S of
    'HH','H': WriteLn('3');
  end;
  case tw16130_S of
    'H','HH': WriteLn('4');
  end;
  tw16130_S := 'A';
  case tw16130_S of
    'HH': WriteLn('2');
  end;
  case tw16130_S of
    'HH','H': WriteLn('3');
  end;
  case tw16130_S of
    'H','HH': WriteLn('4');
  end;
end;
{$pop}

{ Case tw16377.pas }
{$push}

begin
  {$RANGECHECKS ON}
  tw16377_P := PChar(@tw16377_S[2]);
  tw16377_I := -1;
  if (tw16377_P[-1]<>'1') or
     (tw16377_P[tw16377_I]<>'1') then
   halt(1);
end;
{$pop}

{ Case tw2069.pas }
{$push}

Begin
End;
{$pop}

{ Case tw2163.pas }
{$push}

begin
  tw2163_a:='0123456789';
  if length(tw2163_a)<>10 then
   begin
     writeln('Error!');
     halt(1);
   end;
end;
{$pop}

{ Case tw2250.pas }
{$push}

begin
  tw2250_stringbug;
end;
{$pop}

{ Case tw22936.pas }
{$push}

begin
  tw22936_s := 'abc';

  tw22936_i:=1;

  if low(tw22936_s)<>tw22936_i then
    halt(1);

  if high(tw22936_s)<>3 then
    halt(1);

  tw22936_i:=0;

{$ZEROBASEDSTRINGS ON}
  if low(tw22936_s)<>tw22936_i then
    halt(1);

  if high(tw22936_s)<>2 then
    halt(1);

  if tw22936_s[0]<>'a' then
    halt(1);
{$ZEROBASEDSTRINGS OFF}
  writeln('ok');
end;
{$pop}

{ Case tw2294.pas }
{$push}
{$H+}
begin
   tw2294_s:='Dies ist eine ';
   tw2294_s:=tw2294_s+'boese Falle';  { see .Ll4: }
   tw2294_s:=tw2294_s+'.';            { see .Ll5: }
   writeln(tw2294_s);
end;
{$pop}

{ Case tw23136.pas }
{$push}

begin
  tw23136_s:='Aajsljaklsja'[1];
  if tw23136_s<>'A' then
    halt(1);

  tw23136_ws:=#1234#134#312[1];
  if tw23136_ws<>#1234 then
    halt(1);

  writeln('ok');
end;
{$pop}

{ Case tw23744.pas }
{$push}

begin
  tw23744_S:='DefineTestString';
  Insert(tw23744_C,tw23744_S,20);
  if (length(tw23744_s)>16) or
     (tw23744_s<>'DefineTestString') then
    halt(1);
  insert(tw23744_inss,tw23744_s,20);
  if (length(tw23744_s)>16) or
     (tw23744_s<>'DefineTestString') then
    halt(2);
end;
{$pop}

{ Case tw2388.pas }
{$push}

Begin
  tw2388_SS := 'asdf';
  tw2388_AS := 'asdf';
  tw2388_Check('SS         > '''': ', tw2388_SS > '');
  tw2388_Check('Length(SS) >  0: '  , Length(tw2388_SS) > 0);
  tw2388_Check('AS         > '''': ', tw2388_AS > '');
  tw2388_Check('Length(AS) >  0: '  , Length(tw2388_AS) > 0);
  if tw2388_err then
    halt(1);
End;
{$pop}

{ Case tw2473.pas }
{$push}

begin
end;
{$pop}

{ Case tw25332.pas }
{$push}

begin
  if (stringcodepage(tw25332_r) <> CP_ACP) and
     (stringcodepage(tw25332_r) <> DefaultSystemCodePage) then
    halt(1);
end;
{$pop}

{ Case tw2540.pas }
{$push}

begin
  tw2540_S := '';
  SetLength(tw2540_S,1);
  tw2540_S[1] := '?';
  SetLength(tw2540_S,2);
  tw2540_S[2] := '?';
  if (tw2540_s <> '??') then
    halt(1);

  tw2540_S := '';
  tw2540_S := tw2540_S + '?';
  tw2540_S := tw2540_S + '?';
  if (tw2540_s <> '??') then
    halt(1);
end;
{$pop}

{ Case tw2765.pas }
{$push}

begin
  tw2765_S:='SomeThing';
  tw2765_P:=PWideChar(tw2765_S);
  tw2765_PA:=PChar(Pointer(tw2765_P));
  Writeln('P : ',tw2765_PA);
  tw2765_T:=WideCharToString(tw2765_P);
  Writeln('T : ',tw2765_T);
end;
{$pop}

{ Case tw28372.pas }
{$push}

begin
  tw28372_res:=false;
  tw28372_s:='Tes 1';
  case tw28372_s of
  'Tes 1','Tes 2','Tes 3': tw28372_res:=true;
  end;
  if not tw28372_res then
    halt(1);

  tw28372_res:=false;
  tw28372_s:='Tes 2';
  case tw28372_s of
  'Tes 1','Tes 2','Tes 3': tw28372_res:=true;
  end;
  if not tw28372_res then
    halt(2);

  tw28372_res:=false;
  tw28372_s:='Tes 3';
  case tw28372_s of
  'Tes 1','Tes 2','Tes 3': tw28372_res:=true;
  end;
  if not tw28372_res then
    halt(3);
end;
{$pop}

{ Case tw2975.pas }
{$push}

begin
 tw2975_p;
 tw2975_p;
end;
{$pop}

{ Case tw30007.pas }
{$push}
{$r+}
begin
  SetLength(tw30007_SomeLines,1);
  tw30007_LinesToText(tw30007_SomeLines); // <-- ok
  SetLength(tw30007_SomeLines,0);
  tw30007_LinesToText(tw30007_SomeLines); // <-- range error
end;
{$pop}

{ Case tw3174.pas }
{$push}

begin
  tw3174_Mumble('A');
end;
{$pop}

{ Case tw32034.pas }
{$push}
{$H-}
begin
  for tw32034_s in (['1char','2chars']) do begin
    WriteLn(tw32034_s);
    if (tw32034_s <> '1char') and (tw32034_s <> '2chars') then
      Halt(1);
  end;
end;
{$pop}

{ Case tw3328b.pas }
{$push}

Begin
  tw3328b_err:=true;
  tw3328b_A(tw3328b_X);
  if tw3328b_err then
    halt(1);
End;
{$pop}

{ Case tw3523.pas }
{$push}

begin
tw3523_ttt(1,'test1',1,2,3,4,'A','test2','test3','test4','test5');
end;
{$pop}

{ Case tw3554.pas }
{$push}
{$R+}
begin
  tw3554_ch:='A';
  tw3554_c := Byte(tw3554_ch)-Byte('B');
  WriteLn(tw3554_c);
  WriteLn(tw3554_d('a','b'));
end;
{$pop}

{ Case tw40894.pas }
{$push}
{$ZEROBASEDSTRINGS ON}
{$H+}
{$R+}
Begin
  tw40894_S := 'abc';
  WriteLn(Length(tw40894_S));
  For tw40894_I := High(tw40894_S) Downto Low(tw40894_S) Do
    WriteLn(tw40894_I, ' ---> ', tw40894_S[tw40894_I]);
End;
{$pop}

{ Case tw4162.pas }
{$push}

Begin
  tw4162_SS := 'find';
  SetLength(tw4162_S, 300);
  tw4162_S := tw4162_S + tw4162_SS;
  Writeln(Pos(tw4162_SS, tw4162_S)); // This will not find the occurance of 'find'
  if pos(tw4162_ss,tw4162_s)<>301 then
    halt(1);
End;
{$pop}

{ Case tw4272.pas }
{$push}

begin
  tw4272_s:='test';
  tw4272_go(tw4272_s); //-->compiler can not determine which overloaded function to call
end;
{$pop}

{ Case tw4427.pas }
{$push}
{$inline on}
begin
  tw4427_test('abc');
end;
{$pop}

{ Case tw4925.pas }
{$push}

begin
  tw4925_s:='asdf';
   if not(''<tw4925_s) then
     halt(1);
end;
{$pop}

{ Case tw8049.pas }
{$push}
{$Q+}
begin
  tw8049_p:=tw8049_s;
  tw8049_q:=tw8049_p-tw8049_index;
  writeln('Hello ',tw8049_q);
end;
{$pop}

{ Case tw8321.pas }
{$push}
{$Q-}
{$R-}
begin
 tw8321_B := $ffffffed;
 tw8321_B2 := $fffffffd;
  tw8321_p:=POinter(tw8321_B-tw8321_B2);
 Str(tw8321_B-tw8321_B2,tw8321_s);
 writeln(tw8321_s);
 if tw8321_s<>'-16' then
   tw8321_err:=true;

 tw8321_W:=65535;
 tw8321_A:=20;
 Str(tw8321_a * tw8321_w - 256000000,tw8321_s);
 tw8321_p:=POinter(tw8321_a * tw8321_w - 256000000);
 writeln(tw8321_s);
{$ifdef cpu64}
 if tw8321_s<>'18446744073454862316' then
{$else cpu64}
 if tw8321_s<>'-254689300' then
{$endif cpu64}
  tw8321_err:=true;


  if tw8321_err then
    halt(1);

end;
{$pop}

{ Case tw8838.pas }
{$push}

begin
  tw8838_c := 'x';
  tw8838_u := UpCase(tw8838_c);
  tw8838_s := UpCase(tw8838_c);
  tw8838_t := tw8838_u;
  writeln('c = "',tw8838_c,'"');
  writeln('u = "',tw8838_u,'"');
  writeln('s = "',tw8838_s,'"');
  writeln('t = "',tw8838_t,'"');
  if (tw8838_s='') or (tw8838_t='') then
    halt(1);
end;
{$pop}

{ Case tw9187.pas }
{$push}

begin
 setlength(tw9187_w2, 200000);
 for tw9187_i:=1 to length(tw9187_w2) do
   tw9187_w2[tw9187_i]:=Chr(tw9187_i mod $60 + $20);
 tw9187_wstr1:=tw9187_w2;
 tw9187_testproc(tw9187_wstr1);
 if tw9187_wstr1<>tw9187_w2 then begin
   writeln('Test failed!');
   Halt(1);
 end;
 writeln('Test OK.');
end;
{$pop}

{ Case tw9190.pas }
{$push}

begin
  setlength(tw9190_w2, 100000);
  for tw9190_i:=1 to length(tw9190_w2) do
    tw9190_w2[tw9190_i]:=WideChar(Chr(tw9190_i mod $60 + $20));
  tw9190_w3:=tw9190_w2;
  tw9190_wstr1:=tw9190_w2;
  tw9190_testproc1(tw9190_wstr1);
end;
{$pop}

{ Case tw9897.pas }
{$push}

begin
  tw9897_AText := '';
  tw9897_AWideChar := PWideChar(tw9897_AText);
  if PWord(tw9897_AWideChar)^<>0 then
    begin
      writeln(PWord(tw9897_AWideChar)^);
     halt(1);
    end;
end;
{$pop}

end.
