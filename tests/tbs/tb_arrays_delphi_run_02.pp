{ Arrays regression cases; original case IDs are retained below. }

{ Case tw3048.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3048 }
{ Submitted by "GBD" on  2004-04-15 }
{ e-mail:  }
{$mode delphi}
var tw3048_a ,tw3048_b : array of word;
{$pop}

{ Case tw3286.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3286 }
{ Submitted by "Frank Kintrup" on  2004-08-31 }
{ e-mail: frank.kintrup@gmx.de }
{$mode delphi}
var
  tw3286_p : Pointer;
  tw3286_a : array of Integer;
{$pop}

{ Case tw3441.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3441 }
{ Submitted by "Alexey Barkovoy" on  2004-12-07 }
{ e-mail: clootie@ixbt.com }
{$IFDEF FPC}{$MODE DELPHI}{$ENDIF}
procedure tw3441_arrayofcharstest(const tw3441_a: PChar; tw3441_b: PWideChar);
begin
  Writeln(tw3441_a, tw3441_b^); // just do something
end;

procedure tw3441_arrayofconsttest(const Args: array of const);
begin
  Writeln(High(Args)); // just do something
end;

var
  tw3441_a: array[0..5] of Char;
  tw3441_b: array[0..5] of WideChar;
{$pop}

{ Case tw3491.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3491 }
{ Submitted by "Marek Mauder" on  2004-12-29 }
{ e-mail: pentar@seznam.cz }

{$ifdef fpc}{$mode delphi}{$endif}
type
  tw3491_tenum = (
    e0 = 10,
    e1 = 11,
    e2 = 12,
    e3 = 15);
  {errorgen.pas(9,27) Error: enums with assignments can't be used as array index}
  tw3491_tenumarray = array[tw3491_tenum] of Byte;
{$pop}

{ Case tw7227.pp }
{$push}
{$ifdef fpc}{$mode delphi}{$endif}
type
 tw7227_pdouble = ^Double;

function tw7227_checkvalues(tw7227_values : array of tw7227_pdouble) : boolean;
var tw7227_i : integer;
begin
 Result := True;
 for tw7227_i := Low(tw7227_values) to High(tw7227_values) do
  if tw7227_values[tw7227_i]^ = 0 then
    Result := False;
end;

var tw7227_values : array of tw7227_pdouble;
    tw7227_i : integer;
{$pop}

{ Case tw8148.pp }
{$push}
{$IFDEF FPC}
  {$mode delphi}
{$ENDIF}

procedure tw8148_test(a: ansistring);
begin
end;

var
  tw8148_code : Integer;
  tw8148_d : Double;
  tw8148_s : Array[byte] of Char;
  tw8148_s2 : Array[0..100] of Char;
{$pop}

begin
  { Case tw3048.pp }
  {$push}

  begin
if tw3048_a<>tw3048_b then writeln('ok');
  end;
  {$pop}

  { Case tw3286.pp }
  {$push}

  begin
SetLength(tw3286_a, 10);
  tw3286_p := tw3286_a;
  end;
  {$pop}

  { Case tw3441.pp }
  {$push}
{$IFDEF FPC}
{$ENDIF}
  begin
tw3441_a[0]:= 'a'; tw3441_a[1]:= #0;
  tw3441_b[0]:= 'b'; tw3441_b[1]:= #0;
  tw3441_arrayofcharstest(tw3441_a, tw3441_b); // This compiles
  tw3441_arrayofconsttest(['a', tw3441_a, tw3441_b]); //_2.pas(19,29) Error: Incompatible types: got "Array[0..5] Of WideChar" expected "^Char"
  end;
  {$pop}

  { Case tw3491.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
{writes 6}
  WriteLn(SizeOf(tw3491_tenumarray));
  if SizeOf(tw3491_tenumarray)<>6 then
    halt(1);
  end;
  {$pop}

  { Case tw7227.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
SetLength(tw7227_values, 5);
 for tw7227_i := 0 to High(tw7227_values) do
 begin
  New(tw7227_values[tw7227_i]);
  tw7227_values[tw7227_i]^ := tw7227_i+1;
 end;

 for tw7227_i := 0 to High(tw7227_values) do
   writeln(tw7227_values[tw7227_i]^);

 if tw7227_checkvalues(tw7227_values) then
   WriteLn('OK')
 else
   writeln('not OK');
  end;
  {$pop}

  { Case tw8148.pp }
  {$push}
{$IFDEF FPC}
{$ENDIF}
  begin
tw8148_s := '123';
  tw8148_s2 := '123';
  tw8148_test(tw8148_s);
  Val(tw8148_s, tw8148_d, tw8148_code); // compiles only in delphi
  if (abs(tw8148_d-123.0) > 0.00001) then
    halt(1);
  Val(PChar(@tw8148_s), tw8148_d, tw8148_code); // compiles in both delphi and FPC
  if (abs(tw8148_d-123.0) > 0.00001) then
    halt(1);
  Val(tw8148_s2, tw8148_d, tw8148_code); // compiles only in delphi
  if (abs(tw8148_d-123.0) > 0.00001) then
    halt(1);
  writeln('ok');
  end;
  {$pop}

end.
