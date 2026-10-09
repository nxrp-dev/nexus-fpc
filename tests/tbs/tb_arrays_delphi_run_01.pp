{ Arrays regression cases; original case IDs are retained below. }

{ Case tb0293.pp }
{$push}
{ Old file: tbs0348.pp }
{  }

{$mode delphi}

type tb0293_fluparr=array[0..1000] of longint;
     tb0293_flupptr=^tb0293_fluparr;

var tb0293_flup : tb0293_flupptr;
    tb0293_flupresult : longint;
    tb0293_flupa : tb0293_fluparr;
{$pop}

{ Case tb0439.pp }
{$push}
{$mode delphi}

var
  tb0439_a : array[0..32] of char;
  tb0439_p : pchar;
  tb0439_i : integer;
{$pop}

{ Case tb0464.pp }
{$push}
{$mode delphi}

var
  tb0464_a1 : Array of Byte;
{$pop}

{ Case tb0646b.pp }
{$push}
{$MODE DELPHI}

procedure tb0646b_testproc;
begin
  Writeln('Hello');
end;

var
  tb0646b_arr1,
  tb0646b_arr2,
  tb0646b_arr3: array [1..10] of Byte;
{$pop}

{ Case tb0727.pp }
{$push}
{$mode delphi}
type
  tb0727_tsqldestroyptr = procedure(p: pointer); cdecl;

const
  SQLITE_TRANSIENT = pointer(1);
  SQLITE_STATIC = pointer(0);
var
  tb0727_transient_static: array[boolean] of tb0727_tsqldestroyptr = (
    SQLITE_TRANSIENT,
    SQLITE_STATIC);
{$pop}

{ Case tw11053.pp }
{$push}
{$mode delphi}

const tw11053_height = 1;
      tw11053_width = 1;

var tw11053_pix: array [0..tw11053_height-1,0..tw11053_width-1] of Integer;

procedure tw11053_main;
var
    tw11053_dx, tw11053_dy: Integer;
    tw11053_color, tw11053_digest: cardinal;
    tw11053_cx, tw11053_cy, tw11053_zx, tw11053_zy: Double;
    tw11053_scale: Double;
    tw11053_deep: Integer;

begin
  FillChar(tw11053_pix, SizeOf(tw11053_pix), $f0);
        tw11053_scale := 0.05;
        tw11053_deep := 30;
        tw11053_digest := 0;

      for tw11053_dy := 0 to tw11053_height -1 do
      begin
        tw11053_cy := (tw11053_dy - tw11053_height / 2) * tw11053_scale;
        for tw11053_dx := 0 to tw11053_width - 1 do
        begin
          tw11053_color := 0;
          tw11053_cx := (tw11053_dx - tw11053_width / 2) * tw11053_scale;

          tw11053_zx := tw11053_cx;
          tw11053_zy := tw11053_cy;

          while tw11053_zx * tw11053_zx + tw11053_zy * tw11053_zy < 1 do
          begin
            tw11053_zx := tw11053_zx * tw11053_zx - tw11053_zy * tw11053_zy + tw11053_cx;
            tw11053_zy := 2 * tw11053_zx * tw11053_zy + tw11053_cy;
            Inc( tw11053_color );
            if tw11053_color > Cardinal(tw11053_deep) then break;
          end;
          tw11053_pix[ tw11053_dy, tw11053_dx ] := tw11053_color;
        end;
      end;

  tw11053_pix[ 0, 0 ] := 80;

  tw11053_digest := 0;
  for tw11053_dy := 0 to tw11053_height -1 do for tw11053_dx := 0 to tw11053_width - 1 do tw11053_digest := tw11053_digest + tw11053_pix[tw11053_dy, tw11053_dx];

  if (tw11053_digest<>80) then
    halt(1);
end;
{$pop}

{ Case tw1408.pp }
{$push}
{$mode delphi}

type
        tw1408_booleanvoidfun = function : boolean;
        tw1408_boolean1intfun = function(tw1408_i : integer) : boolean;

var
        tw1408_af : array[1..10] of tw1408_booleanvoidfun;
        tw1408_ag : array[1..10] of tw1408_boolean1intfun;

        tw1408_b : boolean;
        tw1408_i : integer;

function tw1408_alwaystrue : boolean;
begin
        tw1408_alwaystrue := true;
end;

function tw1408_maybetrue(q : integer) : boolean;
begin
        tw1408_maybetrue := (q = 0);
end;
{$pop}

{ Case tw1709.pp }
{$push}
{$ifdef fpc}{$mode delphi}{$endif}

var
 tw1709_x: array of byte;
{$pop}

{ Case tw1765.pp }
{$push}
{$mode delphi}

type tw1765_mytype=array[1..2] of string;
const tw1765_myconst:tw1765_mytype=('foo','bar');

procedure tw1765_myproc(myparam:tw1765_mytype);
begin
 writeln(myparam[1],' ',myparam[2]);
end;
{$pop}

{ Case tw2291.pp }
{$push}
{$mode delphi}

procedure tw2291_error1(a, b: array of string);
begin
end;

procedure tw2291_error2(a, b: array of byte);
begin
end;
{$pop}

{ Case tw2892.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2892 }
{ Submitted by "Eric Grange" on  2004-01-12 }
{ e-mail: egrange@glscene.org }

{$mode delphi}

type
   tw2892_taffinevector = array [0..2] of Single;
   tw2892_tvector = array [0..3] of Single;

function tw2892_vectormake(const v : tw2892_taffinevector; tw2892_w : Single = 0) : tw2892_tvector; overload;
begin
end;

function tw2892_vectormake(const x, y, z: Single; tw2892_w : Single = 0) : tw2892_tvector; overload;
begin
end;

var
   tw2892_avec : tw2892_taffinevector;
   tw2892_vec : tw2892_tvector;
{$pop}

{ Case tw2946.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2946 }
{ Submitted by "Marco (Gory Bugs Department)" on  2004-02-06 }
{ e-mail:  }

{$ifdef fpc}{$mode Delphi}{$endif}
var tw2946_p:array of pchar;
    tw2946_t: ^pchar;
{$pop}

begin
  { Case tb0293.pp }
  {$push}

  begin
tb0293_flup:=@tb0293_flupa;
  tb0293_flupresult:=tb0293_flup[5];
  end;
  {$pop}

  { Case tb0439.pp }
  {$push}

  begin
tb0439_p:=tb0439_a+tb0439_i;
  end;
  {$pop}

  { Case tb0464.pp }
  {$push}

  begin
SetLength(tb0464_a1,2);
  tb0464_a1[0]:=65;
  tb0464_a1[1]:=66;
  WriteLn(AnsiString(tb0464_a1));
  end;
  {$pop}

  { Case tb0646b.pp }
  {$push}

  begin
Move(tb0646b_testproc, tb0646b_arr1, 10);
  Move((@tb0646b_testproc)^, tb0646b_arr2, 10);
  Move(@tb0646b_testproc^, tb0646b_arr3, 10);
  if (CompareByte(tb0646b_arr1, tb0646b_arr2, 10) <> 0) or
     (CompareByte(tb0646b_arr2, tb0646b_arr3, 10) <> 0) then
  begin
    Writeln('Error!');
    Halt(1);
  end
  else
    Writeln('Ok!');
  end;
  {$pop}

  { Case tw11053.pp }
  {$push}

  begin
tw11053_main;
  end;
  {$pop}

  { Case tw1408.pp }
  {$push}

  begin
for tw1408_i := 1 to 10 do begin
                tw1408_af[tw1408_i] := tw1408_alwaystrue;
                tw1408_ag[tw1408_i] := tw1408_maybetrue;
        end;

        tw1408_b := tw1408_af[1]; { can be fixed by using b := af[1]() }
        tw1408_b := tw1408_ag[1](0);
  end;
  {$pop}

  { Case tw1709.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
// This should free the dynamic array
  tw1709_x := nil;
  end;
  {$pop}

  { Case tw1765.pp }
  {$push}

  begin
tw1765_myproc(tw1765_myconst);
  end;
  {$pop}

  { Case tw2291.pp }
  {$push}

  begin
tw2291_error1(['abc'], ['xyz']);
 tw2291_error2([1,2,3,4], [2,1,0]);
  end;
  {$pop}

  { Case tw2892.pp }
  {$push}

  begin
tw2892_vec:=tw2892_vectormake(tw2892_avec);
  end;
  {$pop}

  { Case tw2946.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw2946_p:=pointer(tw2946_t);
  end;
  {$pop}

end.
