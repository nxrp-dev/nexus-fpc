{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Preserve terminal exit-status assertions while allowing later cases to run. }
procedure CheckCaseExitCode(AValue: LongInt);
begin
  if AValue <> 0 then Halt(AValue);
end;

{ Case tb_inline_string_arguments_objfpc_run_01.pas }
{$push}
{ Inline Out string elements and ShortString conversion for inline function parameters. }
{ Original case IDs and variable scopes are retained below. }


{$H+}

{ Case tw37465.pas }
{$push}
{$H+}

procedure tw37465_foo(out tw37465_c: char); inline;
begin
  tw37465_c := #32;
end;

var tw37465_s: String;
{$pop}

{ Case tw38337.pas }
{$push}
{$H+}

function tw38337_utf8length(const tw38337_s: string): PtrInt; inline;
begin
  Result:=9;
end;


var
  tw38337_v1: string;
  tw38337_s: shortstring;
  tw38337_i: Integer;
{$pop}


{$pop}

{ Case tw12233.pas }
{$push}


{$H+}

var
  tw12233_wchar: WideChar;
  tw12233_wstring: WideString;


{$pop}

{ Case tw13019.pas }
{$push}


{$H+}

const tw13019_expected : array[1..411] of byte = (
62, 143, 158, 162, 176, 227, 28, 124, 207, 207
, 12, 92, 26, 173, 164, 90, 1, 83, 2, 192
, 135, 21, 118, 9, 252, 191, 12, 28, 240, 51
, 254, 129, 199, 107, 15, 82, 56, 43, 82, 72
, 216, 56, 88, 92, 105, 2, 17, 36, 73, 132
, 224, 252, 173, 179, 106, 38, 224, 46, 70, 121
, 245, 37, 122, 114, 61, 10, 48, 74, 75, 83
, 24, 200, 13, 1, 128, 3, 45, 17, 196, 36
, 238, 12, 235, 57, 3, 50, 106, 192, 196, 184
, 112, 102, 0, 70, 24, 196, 4, 18, 130, 97
, 131, 55, 209, 12, 238, 127, 185, 135, 161, 222
, 139, 48, 181, 39, 215, 122, 167, 8, 123, 58
, 191, 227, 179, 37, 77, 16, 35, 32, 195, 72
, 200, 96, 37, 90, 65, 194, 198, 193, 128, 135
, 254, 195, 135, 80, 142, 222, 225, 201, 226, 35
, 244, 180, 0, 76, 4, 86, 96, 87, 235, 42
, 218, 119, 47, 163, 177, 225, 55, 170, 105, 2
, 34, 70, 204, 9, 66, 191, 73, 177, 6, 248
, 90, 36, 132, 183, 51, 101, 252, 250, 182, 129
, 225, 163, 131, 48, 75, 211, 105, 223, 46, 193
, 218, 74, 3, 132, 58, 16, 39, 149, 218, 24
, 201, 16, 166, 30, 78, 35, 77, 194, 148, 142
, 50, 7, 18, 198, 250, 215, 42, 70, 142, 141
, 166, 147, 112, 81, 133, 12, 68, 1, 54, 6
, 203, 113, 0, 136, 168, 65, 130, 224, 197, 216
, 43, 55, 171, 98, 177, 104, 11, 133, 2, 238
, 206, 77, 34, 82, 231, 203, 39, 175, 102, 187
, 64, 38, 170, 189, 3, 50, 90, 177, 222, 5
, 202, 139, 155, 78, 182, 7, 68, 228, 254, 108
, 217, 98, 244, 196, 149, 186, 101, 74, 212, 208
, 193, 170, 98, 18, 189, 19, 88, 251, 15, 131
, 225, 227, 151, 82, 173, 51, 48, 166, 214, 66
, 75, 219, 94, 167, 20, 111, 2, 182, 2, 102
, 66, 48, 49, 49, 97, 231, 231, 231, 157, 65
, 169, 84, 218, 218, 255, 58, 29, 60, 176, 137
, 185, 215, 207, 208, 212, 220, 138, 176, 185, 5
, 141, 97, 147, 75, 32, 194, 248, 175, 207, 249
, 246, 200, 190, 46, 102, 234, 101, 54, 253, 170
, 7, 21, 204, 251, 65, 56, 168, 45, 173, 255
, 1, 156, 162, 177, 64, 134, 27, 179, 141, 0
, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96
, 130);


var
  tw13019_i: Integer;
  tw13019_s: string;


{$pop}

{ Case tw17514.pas }
{$push}
{$ifdef fpc}
{$h+}
{$endif}

var
  tw17514_a: ansistring;
  tw17514_s: shortstring;
{$ifdef fpc}
  tw17514_u: unicodestring;
{$endif}
  tw17514_w: widestring;
  tw17514_code: Integer;


{$pop}

{ Case tw28279.pas }
{$push}




var
  tw28279_value_para_must_be_empty: boolean;

procedure tw28279_Foo1(a: AnsiString; out b: AnsiString);
begin
  WriteLn(length(a));  WriteLn(length(b));
  if tw28279_value_para_must_be_empty and
     (a<>'') then
    halt(2);
  if b<>'' then
    halt(3);
  b := 'a';
end;

procedure tw28279_Foo2(out a: AnsiString; b: AnsiString);
begin
  WriteLn(length(a));  WriteLn(length(b));
  if a<>'' then
    halt(4);
  if tw28279_value_para_must_be_empty and
     (b<>'') then
    halt(5);
  b := 'a';
end;

var tw28279_s1: AnsiString;

function tw28279_f: ansistring;
begin
  { the s1 parameter must be finalised first to prevent accidental use of
    the finalised value }
  if tw28279_s1<>'' then
    halt(1);
  tw28279_f:='a';
  tw28279_f:=tw28279_f+'b';
end;

const tw28279_x: AnsiString = 'abcde';

{$pop}

{ Case tw30082.pas }
{$push}

{$h+}

var
  tw30082_s : rawByteString;

{$pop}

{ Case tw38259.pas }
{$push}

{$inline on}

procedure tw38259_mymove(var src,dst; len: ptrint); inline;
  begin
    if len<=0 then
      exit;
  end;


function tw38259_concatansistrings(p1,p2 : pchar;length1,length2 : longint) : pchar;
var
  p : pchar;
begin
  getmem(p,length1+length2+1);
  tw38259_mymove(p1[0],p[0],length1);
  tw38259_mymove(p2[0],p[length1],length2+1);
  tw38259_concatansistrings:=p;
end;


{$pop}

{ Case tw3840.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3840 }
{ Submitted by "Alexey Barkovoy" on  2005-03-27 }
{ e-mail: clootie@ixbt.com }



const
  tw3840_sConst =  'X';

procedure tw3840_Do1(const w: PWideChar);
begin
  writeln(Widestring(w));
end;


{$pop}

{ Case tw4010.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4010 }
{ Submitted by "Adrian" on  2005-05-23 }
{ e-mail: adrian@veith-system.de }




type
  tw4010_TDynamicByteArray = array of byte;

function tw4010_MaxByte(const ar: array of byte): Integer;
var
  i: Integer;
begin
  Result:= Low(Byte);
  for i:= Low(ar) to High(ar) do
    if ar[i] > Result then Result:= ar[i];
end;

function tw4010_GenByteArray(const aStr: string): tw4010_TDynamicByteArray;
begin
	SetLength(result, Length(aStr));
	if Length(aStr) > 0 then
		Move(aStr[1], result[0], Length(aStr));
end;

var
  tw4010_ar1: tw4010_TDynamicByteArray;

{$pop}

{ Case tw4675.pas }
{$push}
{ OPT=-Sew }

{ Source provided for Free Pascal Bug Report 4675 }
{ Submitted by "Vicnent Snijders" on  2006-01-09 }
{ e-mail: vsnijders@quicknet.nl }


{$H+}

function tw4675_GotHint_WantNoHint: string;
  procedure Add(const s: string);
  begin
    Result := Result + s;
  end;
begin
  if result = 'abc' then;
  Result := '';
  Add('Test');
end;

function tw4675_GotNoHint_OK: string;
var
  a: string;
  procedure Add(const s: string);
  begin
    a:= a+ s;
  end;
begin
  a:='';
  Add('Test');
  Result:=a;
end;

function tw4675_GotNoHint_WantHint: string;
var
  a: string;
  procedure Add(const s: string);
  begin
    a:= a+ s;
  end;
begin
  Add('Test');
  Result:=a;
end;


{$pop}

{ Case tw4763.pas }
{$push}
{H+}

var
  tw4763_W: WideString;

{$pop}

begin

{ Case tb_inline_string_arguments_objfpc_run_01.pas }
{$push}

{$H+}
{$push}
{$H+}
{$pop}
{$push}
{$H+}
{$pop}
begin
  { Case tw37465.pas }
  {$push}
begin
  tw37465_s:=#42;
  tw37465_foo(tw37465_s[1]);
  Writeln(ord(tw37465_s[1]));
  if ord(tw37465_s[1])<>32 then
    halt(1);
end;
  {$pop}

  { Case tw38337.pas }
  {$push}
begin
  tw38337_v1 := '123456789';
  tw38337_s := tw38337_v1;
  for tw38337_i := 1 to tw38337_utf8length(tw38337_s)-8 do begin
  end;
end;
  {$pop}

end;
{$pop}

{ Case tw12233.pas }
{$push}

{$H+}
begin
  tw12233_wchar := 'a';
  tw12233_wstring := 'badc';
  writeln(Pos(tw12233_wchar, tw12233_wstring));
end;
{$pop}

{ Case tw13019.pas }
{$push}

{$H+}
begin
  tw13019_s :=
  '>'#143#158#162#176#227#28'|'#207#207#12'\'#26#173#164'Z'#1'S'#2#192#135#21
  +'v'#9#252#191#12#28#240'3'#254#129#199'k'#15'R8+RH'#216'8X\i'#2#17'$I'#132
  +#224#252#173#179'j&'#224'.Fy'#245'%zr='#10'0JKS'#24#200#13#1#128#3'-'#17#196
  +'$'#238#12#235'9'#3'2j'#192#196#184'pf'#0'F'#24#196#4#18#130'a'#131'7'#209#12
  +#238''#185#135#161#222#139'0'#181''''#215'z'#167#8'{:'#191#227#179'%M'#16'#'
  +' '#195'H'#200'`%ZA'#194#198#193#128#135#254#195#135'P'#142#222#225#201#226
  +'#'#244#180#0'L'#4'V`W'#235'*'#218'w/'#163#177#225'7'#170'i'#2'"F'#204#9'B'
  +#191'I'#177#6#248'Z$'#132#183'3e'#252#250#182#129#225#163#131'0K'#211'i'#223
  +'.'#193#218'J'#3#132':'#16''''#149#218#24#201#16#166#30'N#M'#194#148#142'2'#7
  +#18#198#250#215'*F'#142#141#166#147'pQ'#133#12'D'#1'6'#6#203'q'#0#136#168'A'
  +#130#224#197#216'+7'#171'b'#177'h'#11#133#2#238#206'M"R'#231#203''''#175'f'
  +#187'@&'#170#189#3'2Z'#177#222#5#202#139#155'N'#182#7'D'#228#254'l'#217'b'
  +#244#196#149#186'eJ'#212#208#193#170'b'#18#189#19'X'#251#15#131#225#227#151
  +'R'#173'30'#166#214'BK'#219'^'#167#20'o'#2#182#2'fB011a'#231#231#231#157'A'
  +#169'T'#218#218#255':'#29'<'#176#137#185#215#207#208#212#220#138#176#185#5
  +#141'a'#147'K '#194#248#175#207#249#246#200#190'.f'#234'e6'#253#170#7#21#204
  +#251'A8'#168'-'#173#255#1#156#162#177'@'#134#27#179#141#0#0#0#0'IEND'#174'B`'
  +#130;
  for tw13019_i := 1 to length(tw13019_s) do
    if (ord(tw13019_s[tw13019_i])<>tw13019_expected[tw13019_i]) then
    begin
      writeln('Different at index ',tw13019_i, ', expected #', tw13019_expected[tw13019_i],', got #', ord(tw13019_s[tw13019_i]));
      halt(1);
    end;
end;
{$pop}

{ Case tw17514.pas }
{$push}
{$ifdef fpc}

{$h+}
{$endif}
{$ifdef fpc}
{$endif}
begin
  tw17514_code := 0;
  tw17514_a := 'foo bar';
  delete(tw17514_a, 4, maxint);
  if tw17514_a <> 'foo' then
    tw17514_code := tw17514_code or 1;
  tw17514_s := 'foo bar';
  delete(tw17514_s, 4, maxint);
  if tw17514_s <> 'foo' then
    tw17514_code := tw17514_code or 2;
  tw17514_w := 'foo bar';
  delete(tw17514_w, 4, maxint);
  if tw17514_w <> 'foo' then
    tw17514_code := tw17514_code or 4;
{$ifdef fpc}
  tw17514_u := 'foo bar';
  delete(tw17514_u, 4, maxint);
  if tw17514_u <> 'foo' then
    tw17514_code := tw17514_code or 8;
{$endif}
  CheckCaseExitCode(tw17514_code);
end;
{$pop}

{ Case tw28279.pas }
{$push}

begin
  tw28279_value_para_must_be_empty:=true;

  tw28279_s1 := copy(tw28279_x,2,3)+'x';
  tw28279_Foo1(tw28279_s1,tw28279_s1);

  tw28279_s1 := copy(tw28279_x,2,3)+'x';
  tw28279_Foo2(tw28279_s1,tw28279_s1);

  tw28279_value_para_must_be_empty:=false;
  tw28279_s1 := copy(tw28279_x,2,3)+'x';
  tw28279_Foo1(tw28279_f,tw28279_s1);

  tw28279_s1 := copy(tw28279_x,2,3)+'x';
  tw28279_Foo2(tw28279_s1,tw28279_f);
end;
{$pop}

{ Case tw30082.pas }
{$push}

{$h+}
begin
 tw30082_s:='REGISTER'+'DATA';
 writeln(stringcodepage(tw30082_s));
 if stringcodepage(tw30082_s)<>0 then
   halt(1);
 tw30082_s:=tw30082_s+'NAME';
 writeln(stringcodepage(tw30082_s));
 if (stringcodepage(tw30082_s)<>0) and
    (stringcodepage(tw30082_s)<>DefaultSystemCodePage) then
   halt(2);
end;
{$pop}

{ Case tw38259.pas }
{$push}

{$inline on}
begin
end;
{$pop}

{ Case tw3840.pas }
{$push}

begin
  tw3840_Do1(tw3840_sConst); //Error: Incompatible type for arg no. 1: Got "Char", expected "PWideChar"
  tw3840_Do1('W');    //Error: Incompatible type for arg no. 1: Got "Char", expected "PWideChar"
  tw3840_Do1('WW');   // SUCCEEDED
end;
{$pop}

{ Case tw4010.pas }
{$push}

begin
  tw4010_ar1:= tw4010_GenByteArray('foo');
  tw4010_MaxByte(tw4010_ar1);
  tw4010_MaxByte(tw4010_GenByteArray('foo')); // compiler stops here
end;
{$pop}

{ Case tw4675.pas }
{$push}

{$H+}
begin
  writeln(tw4675_GotHint_WantNoHint);
  writeln(tw4675_GotNoHint_OK);
  writeln(tw4675_GotNoHint_WantHint);
end;
{$pop}

{ Case tw4763.pas }
{$push}

begin
  tw4763_W := '123456';
  if Length(tw4763_W)<>6 then
    begin
      WriteLn('Test1 Failed, it''s ', Length(tw4763_W));
      halt(1);
    end
  else
    WriteLn('Test1 Passed');

  SetLength(tw4763_W, 6);
  if Length(tw4763_W)<>6 then
    begin
      WriteLn('Test2 Failed, it''s ', Length(tw4763_W));
      halt(1);
    end
  else
    WriteLn('Test2 Passed');
end;
{$pop}

end.
