{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tcpstr24.pp }
{$push}
{$codepage utf8}


type
  tcpstr24_str866 = type ansistring(866);
const
  tcpstr24_x = utf8string('abcdef');
  tcpstr24_y = utf8string('®†◊√');
  tcpstr24_z = tcpstr24_str866('abc');

procedure tcpstr24_test(const tcpstr24_x: shortstring);
begin
  writeln('shortstring!');
  halt(1);
end;

procedure tcpstr24_test(const tcpstr24_x: rawbytestring; cp: tsystemcodepage);
begin
  writeln('ansistring(',stringcodepage(tcpstr24_x),')');
  if stringcodepage(tcpstr24_x)<>cp then
    halt(2);
end;


{$pop}

{ Case tcpstr28.pp }
{$push}


{$codepage utf8}

const
  tcpstr28_Test = '𝄞𤽜';
  tcpstr28_UTF8Test = UTF8String(tcpstr28_Test);
  tcpstr28_UTF16Test = UnicodeString(tcpstr28_Test);

var
  tcpstr28_utf8str: UTF8String = tcpstr28_Test;
  tcpstr28_utf16str: UnicodeString = tcpstr28_Test;


{$pop}

{ Case tcpstr8.pp }
{$push}

{$CODEPAGE UTF8}
// file encoding is UTF8
type
  tcpstr8_CP866String = type AnsiString(866);
  tcpstr8_CP1251String = type AnsiString(1251);

procedure tcpstr8_WriteString(const s: RawByteString);
begin
  Write(StringCodePage(s), ' : ');
  WriteLn(s);
end;

var
  tcpstr8_u1: UTF8String;
  tcpstr8_s1: tcpstr8_CP1251String;
  tcpstr8_s2: tcpstr8_CP866String;

{$pop}

{ Case tutf82.pp }
{$push}
{$codepage utf8}
var
  tutf82_w : widestring;

{$pop}

begin

{ Case tcpstr24.pp }
{$push}
{$codepage utf8}
begin
  tcpstr24_test(tcpstr24_x,CP_UTF8);
  tcpstr24_test(tcpstr24_y,CP_UTF8);
  tcpstr24_test(tcpstr24_z,866);
end;
{$pop}

{ Case tcpstr28.pp }
{$push}
{$codepage utf8}
begin
  if Length(tcpstr28_UTF8Test) <> 8 then
    Halt(1);
  if Length(tcpstr28_utf8str) <> 8 then
    Halt(1);
  if Length(tcpstr28_UTF16Test) <> 4 then
    Halt(1);
  if Length(tcpstr28_utf16str) <> 4 then
    Halt(1);
end;
{$pop}

{ Case tcpstr8.pp }
{$push}
{$CODEPAGE UTF8}
begin
  tcpstr8_u1 := 'мама';
  tcpstr8_s1 := tcpstr8_u1;
  tcpstr8_u1 := ' мыла';
  tcpstr8_s2 := tcpstr8_u1;
  tcpstr8_u1 := ' раму';
  tcpstr8_s2 := tcpstr8_s1 + tcpstr8_u1 + tcpstr8_s2;
  tcpstr8_WriteString(tcpstr8_s2);
end;
{$pop}

{ Case tutf82.pp }
{$push}
{$codepage utf8}
begin
  tutf82_w:='äüö';
  if (ord(tutf82_w[1])<>$e4) or
    (ord(tutf82_w[2])<>$fc) or
    (ord(tutf82_w[3])<>$f6) then
    halt(1);
  writeln('ok');
end;
{$pop}

end.
