{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tcpstr12.pp }
{$push}


// check that 'test' constants assigned to ansistring variables have different codepage


type
  tcpstr12_cp866 = type AnsiString(866);
var
  tcpstr12_A: tcpstr12_cp866;
  tcpstr12_B: AnsiString;

{$pop}

{ Case tcpstr22.pp }
{$push}




type
  tcpstr22_cp1251string = type AnsiString(1251);

// --- all string types ---
procedure tcpstr22_test_overload1(const s: AnsiString); overload;
begin
end;
procedure tcpstr22_test_overload1(const s: UTF8String); overload;
begin
  halt(1);
end;
procedure tcpstr22_test_overload1(const s: tcpstr22_cp1251string); overload;
begin
  halt(1);
end;
procedure tcpstr22_test_overload1(const s: unicodestring); overload;
begin
  halt(1);
end;
procedure tcpstr22_test_overload1(const s: widestring); overload;
begin
  halt(1);
end;
procedure tcpstr22_test_overload1(const s: ShortString); overload;
begin
  halt(1);
end;
// --- no AnsiString ---
procedure tcpstr22_test_overload2(const s: UTF8String); overload;
begin
end;
procedure tcpstr22_test_overload2(const s: tcpstr22_cp1251string); overload;
begin
  halt(2);
end;
procedure tcpstr22_test_overload2(const s: unicodestring); overload;
begin
  halt(2);
end;
procedure tcpstr22_test_overload2(const s: widestring); overload;
begin
  halt(2);
end;
procedure tcpstr22_test_overload2(const s: ShortString); overload;
begin
  halt(2);
end;
// --- no AnsiString, UTF8String ---
procedure tcpstr22_test_overload3(const s: tcpstr22_cp1251string); overload;
begin
end;
procedure tcpstr22_test_overload3(const s: unicodestring); overload;
begin
  halt(3);
end;
procedure tcpstr22_test_overload3(const s: widestring); overload;
begin
  halt(3);
end;
procedure tcpstr22_test_overload3(const s: ShortString); overload;
begin
  halt(3);
end;
// --- no AnsiString, UTF8String, AnsiString(codepage) ---
procedure tcpstr22_test_overload4(const s: unicodestring); overload;
begin
end;
{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
procedure tcpstr22_test_overload4(const s: widestring); overload;
begin
  halt(4);
end;
{$endif}
procedure tcpstr22_test_overload4(const s: ShortString); overload;
begin
  halt(4);
end;
// --- no AnsiString, UTF8String, AnsiString(codepage), UnicodeString ---
procedure tcpstr22_test_overload5(const s: widestring); overload;
begin
end;
procedure tcpstr22_test_overload5(const s: ShortString); overload;
begin
  halt(5);
end;

var
  tcpstr22_A: AnsiString;

{$pop}

{ Case tcpstr23.pp }
{$push}




type
  tcpstr23_cp1251string = type AnsiString(1251);

// --- all string types ---
procedure tcpstr23_test_overload1(const tcpstr23_s: ShortString); overload;
begin
end;
procedure tcpstr23_test_overload1(const tcpstr23_s: UTF8String); overload;
begin
  halt(1);
end;
procedure tcpstr23_test_overload1(const tcpstr23_s: AnsiString); overload;
begin
  halt(1);
end;
procedure tcpstr23_test_overload1(const tcpstr23_s: tcpstr23_cp1251string); overload;
begin
  halt(1);
end;
procedure tcpstr23_test_overload1(const tcpstr23_s: unicodestring); overload;
begin
  halt(1);
end;
{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
procedure tcpstr23_test_overload1(const tcpstr23_s: widestring); overload;
begin
  halt(1);
end;
{$endif}
// --- no ShortString ---
procedure tcpstr23_test_overload2(const tcpstr23_s: UTF8String); overload;
begin
end;
procedure tcpstr23_test_overload2(const tcpstr23_s: AnsiString); overload;
begin
  halt(2);
end;
procedure tcpstr23_test_overload2(const tcpstr23_s: tcpstr23_cp1251string); overload;
begin
  halt(2);
end;
procedure tcpstr23_test_overload2(const tcpstr23_s: unicodestring); overload;
begin
  halt(2);
end;
{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
procedure tcpstr23_test_overload2(const tcpstr23_s: widestring); overload;
begin
  halt(2);
end;
{$endif}
// --- no ShortString, UTF8String ---
procedure tcpstr23_test_overload3(const tcpstr23_s: AnsiString); overload;
begin
end;
procedure tcpstr23_test_overload3(const tcpstr23_s: tcpstr23_cp1251string); overload;
begin
  halt(3);
end;
procedure tcpstr23_test_overload3(const tcpstr23_s: unicodestring); overload;
begin
  halt(3);
end;
{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
procedure tcpstr23_test_overload3(const tcpstr23_s: widestring); overload;
begin
  halt(3);
end;
{$endif}
// --- no ShortString, UTF8String, AnsiString ---
procedure tcpstr23_test_overload4(const tcpstr23_s: tcpstr23_cp1251string); overload;
begin
end;
procedure tcpstr23_test_overload4(const tcpstr23_s: unicodestring); overload;
begin
  halt(4);
end;
{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
procedure tcpstr23_test_overload4(const tcpstr23_s: widestring); overload;
begin
  halt(4);
end;
// --- no ShortString, UTF8String, AnsiString, AnsiString(codepage) ---
procedure tcpstr23_test_overload5(const tcpstr23_s: unicodestring); overload;
begin
end;
procedure tcpstr23_test_overload5(const tcpstr23_s: widestring); overload;
begin
  halt(5);
end;
{$endif}

var
  tcpstr23_S: ShortString;

{$pop}

{ Case tcpstr26.pp }
{$push}
{$ifdef fpc}

{$endif}

procedure tcpstr26_test(p: pchar); overload;
begin
  writeln('pchar');
end;

procedure tcpstr26_test(p: pwidechar); overload;
begin
  writeln('pwidechar');
  halt(1);
end;


{$pop}

{ Case tcpstr26b.pp }
{$push}
{$ifdef fpc}

{$endif}

procedure tcpstr26b_test(p: pansichar); overload;
begin
  writeln('pchar');
end;

procedure tcpstr26b_test(p: pwidechar); overload;
begin
  writeln('pwidechar');
  halt(1);
end;


{$pop}

{ Case tgenfunc2.pp }
{$push}
{ test syntax of a global generic function in mode delphi }





function tgenfunc2_Add<T>(aLeft, aRight: T): T;
begin
  Result := aLeft + aRight;
end;


{$pop}

{ Case trtti3.pp }
{$push}


var
   trtti3_a,trtti3_c1,trtti3_c2 : ansistring;
   trtti3_aa : array[1..10] of ansistring;
   trtti3_i : longint;


{$pop}

begin

{ Case tcpstr12.pp }
{$push}

begin
  tcpstr12_B := 'test';
//  if StringCodePage(B) <> DefaultSystemCodePage then
//    halt(1);
  tcpstr12_A := 'test';
  if StringCodePage(tcpstr12_A) <> 866 then
    halt(2);
end;
{$pop}

{ Case tcpstr22.pp }
{$push}

{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
{$endif}
begin
  tcpstr22_test_overload1(tcpstr22_A);
  tcpstr22_test_overload2(tcpstr22_A);
  tcpstr22_test_overload3(tcpstr22_A);
  tcpstr22_test_overload4(tcpstr22_A);
  tcpstr22_test_overload5(tcpstr22_A);
end;
{$pop}

{ Case tcpstr23.pp }
{$push}

{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
{$endif}
{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
{$endif}
{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
{$endif}
{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
{$endif}
begin
  tcpstr23_test_overload1(tcpstr23_S);
  tcpstr23_test_overload2(tcpstr23_S);
  tcpstr23_test_overload3(tcpstr23_S);
  tcpstr23_test_overload4(tcpstr23_S);
{$ifndef FPC_WIDESTRING_EQUAL_UNICODESTRING}
  tcpstr23_test_overload5(tcpstr23_S);
{$endif}
end;
{$pop}

{ Case tcpstr26.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tcpstr26_test('a');
end;
{$pop}

{ Case tcpstr26b.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tcpstr26b_test(#$1234);
end;
{$pop}

{ Case tgenfunc2.pp }
{$push}

begin
  if tgenfunc2_Add<LongInt>(2, 3) <> 5 then
    Halt(1);
  if tgenfunc2_Add<String>('Hello', 'World') <> 'HelloWorld' then
    Halt(2);
end;
{$pop}

{ Case trtti3.pp }
{$push}

begin
   trtti3_c1:='Hello ';
   trtti3_c2:=' world';
   trtti3_a:=trtti3_c1+trtti3_c2;
   finalize(trtti3_a);
   if length(trtti3_a)<>0 then
     begin
       writeln('length of a: ',length(trtti3_a),' instead of 0');
       halt(1);
     end;
   for trtti3_i:=1 to 10 do
     trtti3_aa[trtti3_i]:=trtti3_c1+trtti3_c2;
   finalize(trtti3_aa[1],10);
   for trtti3_i:=1 to 10 do
     if length(trtti3_aa[trtti3_i])<>0 then
       begin
         writeln('error at element: ',trtti3_i,' contents: ''',trtti3_aa[trtti3_i],'''  instead of ''''');
         halt(1);
       end;
end;
{$pop}

end.
