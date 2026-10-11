{ Consolidated string-cases-objfpc regression cases; original IDs and assertions are retained. }
{$mode objfpc}
{$H+}
{$modeswitch nestedprocvars}
{$modeswitch advancedrecords}

{ Case tw10753a.pp }
{$push}
{$ifdef fpc}{$H+}{$endif}

const tw10753a_buf: array[0..5] of char = 'abcdef';

function tw10753a_foo(const tw10753a_a: string): string;
begin
 SetLength(result, 6);
 Move(tw10753a_buf, result[1], sizeof(tw10753a_buf));
 if tw10753a_a <> '1234567890' then
 begin
   writeln('Failed: ', tw10753a_a);
   Halt(1);
 end
 else
   writeln('ok');
end;

procedure tw10753a_test_proc(var tw10753a_a: string);
var
 tw10753a_s: string;
begin
{ Don't call UniqueString(s) here because it makes the compiler assume
 that address of s is taken, and assignment s := foo(s) is not optimized }
 tw10753a_s := tw10753a_a;            // refcount=2
 tw10753a_a := 'whatever';   // modify source -> s.refcount becomes 1
 writeln('before: ', tw10753a_s);
 tw10753a_s := tw10753a_foo(tw10753a_s);
 writeln(tw10753a_s);
end;

var
 tw10753a_s: string;
{$pop}

{ Case tw1501.pp }
{$push}
function tw1501_uper1(const tw1501_pwd:AnsiString):AnsiString;
begin
        Result := UpCase(tw1501_pwd);
        Exit;
end;

function tw1501_uper2(const tw1501_pwd:AnsiString):AnsiString;
begin
        Exit(UpCase(tw1501_pwd));
end;
{$pop}

{ Case tw15207.pp }
{$push}
{$H+}

type
  tw15207_enumtest = (e1, e2);

function tw15207_test: Boolean; inline;
var
  tw15207_e: tw15207_enumtest;
  tw15207_s: String;
begin
  tw15207_e := e1;
  WriteStr(tw15207_s, tw15207_e);
  result:=tw15207_s='e1';
end;

procedure tw15207_testproc;
begin
  if not tw15207_test then
    halt(1);
end;
{$pop}

{ Case tw1856.pp }
{$push}
{$ifdef fpc}

{$endif}

type
 tw1856_tflowitem = class
  tw1856_text: string; //replace with "shortstring" and the crash goes away
 end;

 tw1856_tflow = array of tw1856_tflowitem;

 tw1856_tflow2 = array of array of tw1856_tflowitem;

var
 tw1856_flow: tw1856_tflow;
 tw1856_flow2 : tw1856_tflow2;
{$pop}

{ Case tw18702.pp }
{$push}
{$H+}
{$modeswitch nestedprocvars}

type
  tw18702_tgetsqltextproc = function() : string is nested;

procedure tw18702_testsqlfieldtype(tw18702_agetsqltextproc: tw18702_tgetsqltextproc);
var
  tw18702_i          : byte;
  tw18702_s: string;
begin
  for tw18702_i := 0 to 9 do
    begin
    tw18702_s := tw18702_agetsqltextproc();
    if tw18702_s<>'hello' then
      begin
      writeln('Failed');
      halt(tw18702_i+1);
      end;
    end;
end;

procedure tw18702_testsqlclob;

  function tw18702_getsqltext() : string;
  begin
    result := 'hello';
  end;

begin
  tw18702_testsqlfieldtype(@tw18702_getsqltext);
end;
{$pop}

{ Case tw22669.pp }
{$push}
{$ifdef fpc}
  {$H+}
{$else}
  {$APPTYPE CONSOLE}
{$endif}

var tw22669_buf:array[1..11] of widechar;
  tw22669_s:ansistring;
{$pop}

{ Case tw29460.pp }
{$push}
{$H+}
{$modeswitch advancedrecords}

operator = (tw29460_z1: LongInt; tw29460_z2 : ansistring) tw29460_b : boolean;
begin
  tw29460_b := false;
end;

var
  tw29460_i: longint;
  tw29460_s: string;
{$pop}

{ Case tw30572.pp }
{$push}
{$h+}
{$inline on}

var
  tw30572_s: String;

  function tw30572_testwincptoutf8(const tw30572_s: string): string;
  begin
    if pointer(tw30572_s)=pointer(result) then
      halt(1);
    Result := tw30572_s; // Result is now invalid
    SetCodePage(RawByteString(Result), CP_ACP, False);
  end;

  function tw30572_test: string; inline;
  var
    tw30572_s: String;
  begin
    tw30572_s := 'test';
    result:=tw30572_s+'a';
    Result := tw30572_testwincptoutf8(Result);
  end;
{$pop}

{ Case tw3212.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3212 }
{ Submitted by "Marc Weustink" on  2004-07-15 }
{ e-mail: marc@freepascal.org }

{$H+}

const
  tw3212_c1: String = 'bla';

procedure tw3212_x;
const
  tw3212_c: String = 'bla';
begin
  tw3212_c:='bla';
  tw3212_c:='bla'+tw3212_c;
  WriteLN('"',tw3212_c,'"');
  if tw3212_c<>'blabla' then
    halt(1);
end;
{$pop}

{ Case tw3423.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3423 }
{ Submitted by "Bram Kuijvenhoven" on  2004-12-02 }
{ e-mail: kuifware@hotmail.com }
{$H+}

var
  tw3423_a:ansistring;
  tw3423_s:shortstring;
{$pop}

{ Case tw35590.pp }
{$push}
{$inline on}
{$h+}
  function tw35590_slow: integer; inline;
  begin result := 1; end;

  function tw35590_shigh( const tw35590_s: string): integer; inline;
  begin result := Length(tw35590_s); end;

  procedure tw35590_insert2( const tw35590_substr: string; var tw35590_s: string; index: integer);
  begin insert( tw35590_substr, tw35590_s, index); end;

  function tw35590_replacechars(const tw35590_s, tw35590_substr: string): string;
  var tw35590_i: integer;
  begin
    result := tw35590_s;
    // ok with sHigh(s) or with non-inlined sHigh(result)
    for tw35590_i := tw35590_shigh(result) downto tw35590_slow() do begin
      delete( result, tw35590_i, 1);
      tw35590_insert2( tw35590_substr, result, tw35590_i); // ok with (unwrapped) insert( subStr, result, i)
    end;
  end; // Error: Internal error 200405231

  procedure tw35590_test1;
  var tw35590_s, tw35590_newchar, tw35590_r: ansistring;
  begin
    tw35590_s := 'old'; tw35590_newchar := 'Replace';
    tw35590_r := tw35590_replacechars( tw35590_s, tw35590_newchar);
  end;
{$pop}

{ Case tw4533.pp }
{$push}
{$openstrings+}
procedure tw4533_t(out tw4533_s: shortstring);
begin
  writeln(high(tw4533_s));
  if high(tw4533_s) <> 4 then
    halt(1);
end;

var
  tw4533_s: string[4];
{$pop}

{ Case tw4566.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4566 }
{ Submitted by "Vincent Snijders" on  2005-12-04 }
{ e-mail: vsnijders@quicknet.nl }
{$H+}

var
  tw4566_s: string;
{$pop}

{ Case tw8580.pp }
{$push}
{$H+}

type
  tw8580_tutf8char = String[7];

var
  tw8580_t: widestring;
  tw8580_utf8char: tw8580_tutf8char;
{$pop}

begin
  { Case tw10753a.pp }
  {$push}
{$H+}
begin
 tw10753a_s := '1234567890';
 UniqueString(tw10753a_s);
 tw10753a_test_proc(tw10753a_s);
end;
  {$pop}

  { Case tw1501.pp }
  {$push}

begin
  writeln('test', tw1501_uper1('test'));
  writeln('test', tw1501_uper2('test'));
  if tw1501_uper1('test')<>'TEST' then
   begin
     writeln('ERROR in Uper1!');
     halt(1);
   end;
  if tw1501_uper2('test')<>'TEST' then
   begin
     writeln('ERROR in Uper2!');
     halt(1);
   end;
end;
  {$pop}

  { Case tw15207.pp }
  {$push}
{$H+}
begin
  tw15207_testproc;
end;
  {$pop}

  { Case tw1856.pp }
  {$push}

begin
 setlength(tw1856_flow, 10);
 setlength(tw1856_flow, 1);
 tw1856_flow[0]:=tw1856_tflowitem.Create;

 { release }
 setlength(tw1856_flow, 0);

 setlength(tw1856_flow2, 10, 20);
 setlength(tw1856_flow2, 0);

 writeln('no crash');
end;
  {$pop}

  { Case tw18702.pp }
  {$push}
{$H+}
begin
  tw18702_testsqlclob;
end;
  {$pop}

  { Case tw22669.pp }
  {$push}
{$H+}
begin
  tw22669_buf:='isnotempty';
  tw22669_s:='test';
  StringToWideChar(tw22669_s,@tw22669_buf[1],10);
  tw22669_s:=widestring(pwidechar(@tw22669_buf[1]));
  if tw22669_s<>'test' then
    halt(1);
  tw22669_s:='0123456789';
  StringToWideChar(tw22669_s,@tw22669_buf[1],10);
  tw22669_s:=widestring(pwidechar(@tw22669_buf[1]));
  if tw22669_s<>'012345678' then
    halt(2);
 end;
  {$pop}

  { Case tw29460.pp }
  {$push}
{$H+}
begin
  if tw29460_i = tw29460_s then
    halt(1);
  writeln('ok');
end;
  {$pop}

  { Case tw30572.pp }
  {$push}
{$H+}
{$inline on}
begin
  tw30572_s := tw30572_test;
end;
  {$pop}

  { Case tw3212.pp }
  {$push}
{$H+}
begin
  tw3212_x;
  tw3212_x;
end;
  {$pop}

  { Case tw3423.pp }
  {$push}
{$H+}
begin

  tw3423_a:='';
  tw3423_s:='';
  tw3423_a:=tw3423_a+tw3423_s;

end;
  {$pop}

  { Case tw35590.pp }
  {$push}
{$H+}
{$inline on}
begin
tw35590_test1;
end;
  {$pop}

  { Case tw4533.pp }
  {$push}
{$openstrings+}
begin
  tw4533_t(tw4533_s);
end;
  {$pop}

  { Case tw4566.pp }
  {$push}
{$H+}
begin
  //accidentally use #1310 instead of #13#10
  tw4566_s := 'Message Text' + #1310 + #1310 + 'More Text';
end;
  {$pop}

  { Case tw8580.pp }
  {$push}
{$H+}
begin
  tw8580_t := 'test';
  tw8580_utf8char := tw8580_tutf8char(tw8580_t);
  writeln(tw8580_utf8char);
end;
  {$pop}

end.
