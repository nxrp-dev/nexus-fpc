{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode iso}

{ Case tisorec1.pas }
{$push}

type
  tisorec1_tr = record
    l : longint;
    case i : integer of
      1 : (s : array[0..255] of char);
      2 : (n : integer);
      3 : (w : word; case j : integer of
        1 : (t : array[0..255] of char);
        2 : (a : integer);
        );
  end;
  tisorec1_pr = ^tisorec1_tr;

var
  tisorec1_r : tisorec1_pr;

{$pop}

{ Case tisorec4.pas }
{$push}

type
  tisorec4_tr = record
    l : longint;
    case integer of
      1 : (s : array[0..255] of char);
      2 : (n : integer);
      3 : (w : word; case j : integer of
        1 : (t : array[0..255] of char);
        2 : (a : integer);
        );
  end;
  tisorec4_pr = ^tisorec4_tr;

var
  tisorec4_r : tisorec4_pr;

{$pop}

{ Case tisorec5.pas }
{$push}

type
  tisorec5_tr = record
    l : longint;
    case i : integer of
      1 : (s : array[0..255] of char);
      2 : (n : integer);
      3 : (w : word; case j : integer of
        1 : (t : array[0..255] of char);
        2 : (a : integer);
        );
  end;
  tisorec5_pr = ^tisorec5_tr;

var
  tisorec5_r : tisorec5_pr;

{$pop}

begin

{ Case tisorec1.pas }
{$push}

begin
  new(tisorec1_r,3,2);
  if tisorec1_r^.i<>3 then
    halt(1);
  if tisorec1_r^.j<>2 then
    halt(1);
  dispose(tisorec1_r);
  writeln('ok');
end;
{$pop}

{ Case tisorec4.pas }
{$push}

begin
  new(tisorec4_r,3,2);
  if tisorec4_r^.j<>2 then
    halt(1);
  dispose(tisorec4_r);
  writeln('ok');
end;
{$pop}

{ Case tisorec5.pas }
{$push}

begin
  new(tisorec5_r,3,2);
  if tisorec5_r^.i<>3 then
    halt(1);
  if tisorec5_r^.j<>2 then
    halt(1);
  dispose(tisorec5_r,3,2);
  writeln('ok');
end;
{$pop}

end.
