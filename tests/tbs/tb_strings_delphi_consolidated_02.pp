{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tb_string_arguments_delphi_run_01.pp }
{$push}
{ Temporary PAnsiChar arguments and Unicode literal assignment to ShortString. }
{ Original case IDs and variable scopes are retained below. }



{ Case tb0480.pp }
{$push}
{$ifdef fpc}{$endif}

procedure tb0480_test(const tb0480_s1, tb0480_s2: PAnsiChar);
begin
  Writeln(tb0480_s1);
  Writeln(tb0480_s2);
  if ansistring(tb0480_s1)<>ansistring(tb0480_s2) then
    begin
      writeln('Error');
      halt(1);
    end;
end;

var
  tb0480_s: AnsiString;
  tb0480_p: PAnsiChar;
{$pop}

{ Case tb0600.pp }
{$push}
{$ifdef fpc}

{$endif}

var
  tb0600_s: shortstring;
{$pop}

{ Case tw10933.pp }
{$push}
var
  tw10933_s: string[3] = 'ABC';

procedure tw10933_foo(tw10933_buf: PAnsiChar; tw10933_expected: AnsiChar);
begin
  WriteLn(tw10933_buf^);
  if tw10933_buf^ <> tw10933_expected then
    Halt(1);
end;

function tw10933_classnameshort(): PShortString;
begin
  Result := @tw10933_s;
end;
{$pop}


{$pop}

{ Case tw14941a.pp }
{$push}

{$ifdef fpc}

{$endif}
{$V+}
var
   tw14941a_s    :String;

procedure tw14941a_P( tw14941a_s: OpenString);
begin
  writeln(tw14941a_s);
  if (high(tw14941a_s)<>255) or
     (tw14941a_s<>'12345') then
    halt(1);
end;


{$pop}

{ Case tw1735.pp }
{$push}

function tw1735_UpperCase(tw1735_S: string): string;
var
  i: integer;
begin
  for i := 1 to length(tw1735_s) do
    case tw1735_s[i] of
      'a' .. 'z': Dec(tw1735_s[i], 32);
//      'a' .. 'z': s[i] := chr(ord(s[i])-32);
    end;
  result := tw1735_s;
end;

var
  tw1735_s: string;

{$pop}

{ Case tw2397.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2397 }
{ Submitted by "Yakov Sudeikin" on  2003-02-23 }
{ e-mail: yashka@exebook.com }



var
 tw2397_a: array of string = nil; //Only works in Delphi

{$pop}

{ Case tw2949.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2949 }
{ Submitted by "Marco (Gory bugs department)" on  2004-02-07 }
{ e-mail:  }

{$ifdef fpc}{$endif}

TYPE
// dummy types
  tw2949_PSSL_CTX=pchar;

var
  tw2949_IdSslCtxSetVerifyDepth : procedure(ctx: tw2949_PSSL_CTX; depth: Integer); cdecl = nil;


{$pop}

{ Case tw3083.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3083 }
{ Submitted by "Martin Schreiber" on  2004-05-04 }
{ e-mail:  }


{$H+}

var
 tw3083_ar1: array of ansistring;

{$pop}

{ Case tw3328.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3328 }
{ Submitted by "Christian Iversen" on  2004-09-21 }
{ e-mail: chrivers@iversen-net.dk }




var
  tw3328_err : boolean;

Function tw3328_A(Const S1, S2: PAnsiChar): Integer; Overload;
Begin
  writeln('pansichar overload');
  tw3328_err:=false;
End;

Function tw3328_A(Const S1, S2: AnsiString): Integer; Overload;
Begin
  writeln('ansistring overload');
End;

Var
  tw3328_X : PAnsiChar;

{$pop}

{ Case tw3328a.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3328 }
{ Submitted by "Christian Iversen" on  2004-09-21 }
{ e-mail: chrivers@iversen-net.dk }




var
  tw3328a_err : boolean;

Function tw3328a_A(Const S2: AnsiString): Integer; Overload;
Begin
  writeln('ansistring overload');
  tw3328a_err:=false;
End;

Function tw3328a_A(Const S2: UnicodeString): Integer; Overload;
Begin
  writeln('unicodestring overload');
End;

Var
  tw3328a_X : PAnsiChar;

{$pop}

{ Case tw3572.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3572 }
{ Submitted by "Lukas Gebauer" on  2005-01-18 }
{ e-mail: gebauerl@mlp.cz }



function tw3572_x(value: string): string;
begin
  result := Value;
  result := result;
end;

var
  tw3572_s: string;

{$pop}

{ Case tw4277.pp }
{$push}

{$J-}

const
  tw4277_RFCMonthNames : Array[1..12] of String = (
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');


{$pop}

{ Case tw4390.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4390 }
{ Submitted by "Benjamin Rosseaux" on  2005-09-28 }
{ e-mail: benjamin@0ok.de }

{$IFDEF FPC}
 
{$ENDIF}

PROCEDURE tw4390_WriteToFile(CONST Buf;Size:INTEGER);
var
  s : shortstring;
BEGIN
  move(Buf,s[1],size);
  s[0]:=chr(size);
//  writeln('Writing: "',s,'"');
  if s<>'TEST' then
    halt(1);
END;


{$pop}

begin

{ Case tb_string_arguments_delphi_run_01.pp }
{$push}

{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$pop}
begin
  { Case tb0480.pp }
  {$push}
begin
  tb0480_s := 'Test';
  tb0480_p := PAnsiChar(tb0480_s);
  tb0480_test(PAnsiChar('String:'+tb0480_s+';'), PAnsiChar('String:'+tb0480_s+';'));
  tb0480_test(PAnsiChar('String:'+tb0480_p+';'), PAnsiChar('String:'+tb0480_p+';'));
end;
  {$pop}

  { Case tb0600.pp }
  {$push}
begin
  tb0600_s:=#$1234;
end;
  {$pop}

  { Case tw10933.pp }
  {$push}
begin
  tw10933_foo(@tw10933_classnameshort()^[1], 'A');
  tw10933_foo(@tw10933_classnameshort()^[2], 'B');
  tw10933_foo(@tw10933_classnameshort()^[3], 'C');
end;
  {$pop}

end;
{$pop}

{ Case tw14941a.pp }
{$push}
{$ifdef fpc}

{$endif}
{$V+}
begin
  tw14941a_P('12345');
  tw14941a_s:='12345';
  tw14941a_p(tw14941a_s);
  {Won't compile.
  FPC or Turbo Pascal mode:  Internal error 200405241
  Delphi mode:  Signal 291.  Save files and restart IDE.  (Can't save.)}
end;
{$pop}

{ Case tw1735.pp }
{$push}

begin
  tw1735_s := 'abcdef';
  writeln(tw1735_uppercase(tw1735_s));
  writeln(tw1735_s);
  if (tw1735_s <> 'abcdef') then
    halt(1);
end;
{$pop}

{ Case tw2397.pp }
{$push}

begin
 tw2397_a := nil; //works in FPC and Delphi
end;
{$pop}

{ Case tw2949.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tw3083.pp }
{$push}

{$H+}
begin
 setlength(tw3083_ar1,1);
 tw3083_ar1[0]:= 'abc';
 tw3083_ar1:= nil;          //av!
end;
{$pop}

{ Case tw3328.pp }
{$push}

Begin
  tw3328_err:=true;
  tw3328_A(tw3328_X, '');
  if tw3328_err then
    halt(1);
End;
{$pop}

{ Case tw3328a.pp }
{$push}

Begin
  tw3328a_err:=true;
  tw3328a_A(tw3328a_X);
  if tw3328a_err then
    halt(1);
End;
{$pop}

{ Case tw3572.pp }
{$push}

begin
  tw3572_s := 'ahoy!';
  writeln(tw3572_x(tw3572_s));
  if tw3572_x(tw3572_s)<>tw3572_s then
    halt(1);
end;
{$pop}

{ Case tw4277.pp }
{$push}

{$J-}
begin
  writeln(tw4277_RFCMonthNames[10]);
end;
{$pop}

{ Case tw4390.pp }
{$push}
{$IFDEF FPC}

{$ENDIF}
BEGIN
 tw4390_WriteToFile('TEST',4);
END;
{$pop}

end.
