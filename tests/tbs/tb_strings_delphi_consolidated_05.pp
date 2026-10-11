{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tw8191.pp }
{$push}


{$APPTYPE CONSOLE}

{$ifdef fpc}
  
{$endif}

{$R+}

function tw8191_Test: Boolean;
var
  s: shortstring;
  p: PChar;
begin
  s := '1234567890';
  p := PChar(@s[1]);
  Inc(p,4);

  Result :=
   (p[-4] = '1') and
   (p[-3] = '2') and
   (p[-2] = '3') and
   (p[-1] = '4') and
   (p[ 0] = '5') and
   (p[ 1] = '6') and
   (p[ 2] = '7') and
   (p[ 3] = '8') and
   (p[ 4] = '9') and
   (p[ 5] = '0');
end;


{$pop}

{ Case tarray6.pp }
{$push}
{$ifndef macos}{$APPTYPE CONSOLE}{$endif}
{$ifdef fpc}{$endif}

procedure tarray6_wideansi;
var
  S: AnsiString = 'abcd';
  pc: PChar = 'abcd';
  ca: array [0..4] of Char = ('a', 'b', 'c', 'd', #0);
  W: WideString = 'abcd';
  pw: PWideChar = 'abcd';
  wa: array [0..4] of WideChar = ('a', 'b', 'c', 'd', #0);
begin
{$IFDEF FPC}
  ca := S;
  ca := W;
  ca := pc;
  wa := pw;
  wa := S;
  wa := W;
{$ENDIF}

  W := S;
  W := pc;
  W := ca;
  W := pw;
  W := wa;

  S := W;
  S := pc;
  S := ca;
  S := pw;
  S := wa;

  if S = pc then WriteLn('(2.1) strings are equal');
  if S = ca then WriteLn('(2.2) strings are equal');
  WriteLn;

  if W = pw then WriteLn('(3.1) wide pass');
  if W = wa then WriteLn('(3.2) wide pass');
  WriteLn;

  if S = W  then WriteLn('(4.1) wide vs ansi');
  if pc = W then WriteLn('(4.2) wide vs ansi');
  if ca = W then WriteLn('(4.3) wide vs ansi');
  if pw = S then WriteLn('(4.4) wide vs ansi');
  if wa = S then WriteLn('(4.5) wide vs ansi');
  WriteLn;
end;

procedure tarray6_wideshort;
var
  S: ShortString = 'abcd';
  pc: PChar = 'abcd';
  ca: array [0..4] of Char = ('a', 'b', 'c', 'd', #0);
  W: WideString = 'abcd';
  pw: PWideChar = 'abcd';
  wa: array [0..4] of WideChar = ('a', 'b', 'c', 'd', #0);
begin
{$IFDEF FPC}
  ca := S;
  ca := W;
  ca := pc;
  wa := pw;
  wa := S;
  wa := W;
{$ENDIF}

  W := S;
  W := pc;
  W := ca;
  W := pw;
  W := wa;

  S := W;
  S := pc;
  S := ca;
  S := pw;
  S := wa;

  if S = pc then WriteLn('(2.1) strings are equal');
  if S = ca then WriteLn('(2.2) strings are equal');
  WriteLn;

  if W = pw then WriteLn('(3.1) wide pass');
  if W = wa then WriteLn('(3.2) wide pass');
  WriteLn;

  if S = W  then WriteLn('(4.1) wide vs ansi');
  if pc = W then WriteLn('(4.2) wide vs ansi');
  if ca = W then WriteLn('(4.3) wide vs ansi');
  if pw = S then WriteLn('(4.4) wide vs ansi');
  if wa = S then WriteLn('(4.5) wide vs ansi');
  WriteLn;
end;


{$pop}

{ Case tcpstr14.pp }
{$push}

{$apptype console}
{$H+}

type
  tcpstr14_t866 = type AnsiString(866);
var
  tcpstr14_s866: tcpstr14_t866;

{$pop}

begin

{ Case tw8191.pp }
{$push}
{$APPTYPE CONSOLE}
{$ifdef fpc}

{$endif}
{$R+}
begin
  if not tw8191_Test then
    halt(1);
  WriteLn('ok');
end;
{$pop}

{ Case tarray6.pp }
{$push}
{$ifndef macos}
{$APPTYPE CONSOLE}
{$endif}
{$ifdef fpc}

{$endif}
{$IFDEF FPC}
{$ENDIF}
{$IFDEF FPC}
{$ENDIF}
begin
  tarray6_wideshort;
  tarray6_wideansi;
end;
{$pop}

{ Case tcpstr14.pp }
{$push}
{$apptype console}

{$H+}
begin
  Str(123, tcpstr14_s866);
  if StringCodePage(tcpstr14_s866) <> 866 then
    halt(1);
end;
{$pop}

end.
