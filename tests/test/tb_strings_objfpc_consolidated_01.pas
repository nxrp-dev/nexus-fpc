{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Preserve terminal exit-status assertions while allowing later cases to run. }
procedure CheckCaseExitCode(AValue: LongInt);
begin
  if AValue <> 0 then Halt(AValue);
end;

{ Case tcase0.pas }
{$push}
{$h+}

// A basic test for 'case-of-string' with embedded zeroes
var
  tcase0_s: string;
  tcase0_ss: shortstring;
  tcase0_ws: widestring;
  tcase0_us: unicodestring;
  tcase0_i: integer;


{$pop}

{ Case tcpstr7.pas }
{$push}
{$H+}
{$hints off}

procedure tcpstr7_APos(const substr: shortstring; const s: RawByteString);
begin
end;

procedure tcpstr7_APos(const Substr: RawByteString; const Source: RawByteString);
begin
end;

const
  tcpstr7_C = '\';


{$pop}

{ Case tinline9.pas }
{$push}
{$ifdef fpc}

{$inline on}
{$endif}

function tinline9_fa: ansistring;
begin
  tinline9_fa:='b';
  tinline9_fa:=result+'a';
end;

function tinline9_fb: ansistring;
begin
  tinline9_fb:='c';
  tinline9_fb:=result+'d';
end;

procedure tinline9_test(const a,b: pointer); inline;
begin
  if (ansistring(a)<>'ba') or
     (ansistring(b)<>'cd') then
    halt(1);
end;


{$pop}

{ Case tstring9.pas }
{$push}

{$ifdef fpc}{$h+}{$endif}

var
 tstring9_a: array[0..0] of char = (#0);

function tstring9_test_pchar: boolean;
var
 s: string;
 p: pchar;
begin
 p := '';
 s := '1234567890';
 s := p;
 tstring9_test_pchar := (s = '');
 if not tstring9_test_pchar then writeln('test_pchar failed');
end;

function tstring9_test_chararray: boolean;
var
 s: string;
begin
 s := '1234567890';
 s := tstring9_a;
 tstring9_test_chararray := (s = '');
 if not tstring9_test_chararray then writeln('test_chararray failed');
end;

function tstring9_test_pchar_to_widestr: boolean;
var
 s: widestring;
 p: PChar;
begin
 p := '';
 s := '1234567890';
 s := p;                         { win32: function result assign not optimized! }
 tstring9_test_pchar_to_widestr := (s = '');
 if not tstring9_test_pchar_to_widestr then writeln('test_pchar_to_widestr failed');
end;

function tstring9_test_chararray_to_widestr: boolean;
var
 s: widestring;
begin
 s := '1234567890';
 s := tstring9_a;
 tstring9_test_chararray_to_widestr := (s = '');
 if not tstring9_test_chararray_to_widestr then writeln('test_chararray_to_widestr failed');
end;


{$pop}

{ Case twrstr7.pas }
{$push}
{ from GPC test suite }




var
  twrstr7_a: array [ 0..3 ] of Byte = ( ord ( 'O' ), ord ( 'K' ), 42, 137 );

var
  twrstr7_S: String [ 255 ];


{$pop}

begin

{ Case tcase0.pas }
{$push}

{$h+}
begin
  tcase0_i:=15;

  tcase0_s:='aa'#0'bb';
  case tcase0_s of
    'aa'#0'aa' .. 'aa'#0'cc': tcase0_i:=tcase0_i and (not 1);
  end;

  tcase0_ss:='aa'#0'bb';
  case tcase0_ss of
    'aa'#0'aa' .. 'aa'#0'cc': tcase0_i:=tcase0_i and (not 2);
  end;

  tcase0_ws:='aa'#0'bb';
  case tcase0_ws of
    'aa'#0'aa' .. 'aa'#0'cc': tcase0_i:=tcase0_i and (not 4);
  end;

  tcase0_us:='aa'#0'bb';
  case tcase0_us of
    'aa'#0'aa' .. 'aa'#0'cc': tcase0_i:=tcase0_i and (not 8);
  end;

  if tcase0_i=0 then
    writeln('ok');
  CheckCaseExitCode(tcase0_i);
end;
{$pop}

{ Case tcpstr7.pas }
{$push}

{$H+}
{$hints off}
begin
  tcpstr7_APos(tcpstr7_C + '.' + tcpstr7_C, 'Test');
end;
{$pop}

{ Case tinline9.pas }
{$push}
{$ifdef fpc}

{$inline on}
{$endif}
begin
  tinline9_test(pointer(tinline9_fa()),pointer(tinline9_fb()));
end;
{$pop}

{ Case tstring9.pas }
{$push}
{$ifdef fpc}

{$h+}
{$endif}
begin
 if not tstring9_test_pchar then Halt(1);
 if not tstring9_test_chararray then Halt(2);
 if not tstring9_test_pchar_to_widestr then Halt(3);
 if not tstring9_test_chararray_to_widestr then Halt(4);
end;
{$pop}

{ Case twrstr7.pas }
{$push}

begin
  WriteStr ( twrstr7_S, twrstr7_a [ 0 ], twrstr7_a [ 1 ] );
  CheckCaseExitCode(ord(twrstr7_S <> '7975'));
end;
{$pop}

end.
