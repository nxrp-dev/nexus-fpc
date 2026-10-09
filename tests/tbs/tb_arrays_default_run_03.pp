{ Arrays regression cases; original case IDs are retained below. }

{ Case tb0494.pp }
{$push}
{ the test checks only if the syntax is possible }
var
  tb0494_ca : array[0..1000] of char;
  tb0494_p1 : pchar;
{$pop}

{ Case tb0529.pp }
{$push}
{ It tests conversion from "array of char" to "array of PChar" }

function tb0529_dotest(params: array of PChar): string;
var
  tb0529_i: integer;
  tb0529_res: string;
begin
  tb0529_res:='';
  for tb0529_i:=Low(params) to High(params) do
    tb0529_res:=tb0529_res + params[tb0529_i];
  tb0529_dotest:=tb0529_res;
end;

var
  tb0529_s: string;
{$pop}

{ Case tb0541.pp }
{$push}
const
  tb0541_teststr: widestring = 'Test';

var
  tb0541_buf: array[0..10] of widechar;
  tb0541_s: widestring;
{$pop}

{ Case tb0555.pp }
{$push}
function tb0555_dotest(params: array of PWideChar): WideString;
var
  tb0555_i: integer;
  tb0555_res: WideString;
begin
  tb0555_res:='';
  for tb0555_i:=Low(params) to High(params) do
    tb0555_res:=tb0555_res + params[tb0555_i];
  tb0555_dotest:=tb0555_res;
end;

var
  tb0555_s: WideString;
{$pop}

{ Case tb0708.pp }
{$push}
procedure tb0708_fillsomeqwords;
var
	tb0708_q: array[0 .. 9] of uint64;
	tb0708_rep: int32;
begin
	for tb0708_rep := 1 to 128 * 1024 * 1024 do
		FillQWord(tb0708_q, length(tb0708_q), 1234);
end;
{$pop}

{ Case tw0852.pp }
{$push}
type
  tw0852_tfloat80array = array [0..1000000] of Extended;

procedure tw0852_addfloat80proc(var Vector1; const Vector2; tw0852_count: Integer);
var
  tw0852_i: Integer;
begin
  for tw0852_i:=0 to tw0852_count - 1 do
    tw0852_tfloat80array(Vector1)[tw0852_i]:=tw0852_tfloat80array(Vector1)[tw0852_i] + tw0852_tfloat80array(Vector2)[tw0852_i];
end;
{$pop}

{ Case tw0879.pp }
{$push}
TYPE
        tw0879_ta      = ARRAY[3..8] OF word;
VAR
        tw0879_aa      : ^tw0879_ta;
        tw0879_i       : word;
{$pop}

{ Case tw0881.pp }
{$push}
TYPE
    tw0881_byteset     = SET OF 0..7;
    tw0881_booleanarray    = ARRAY[0..HIGH(word) DIV 8] OF tw0881_byteset;
    tw0881_booleanarraypointer = ^tw0881_booleanarray;

PROCEDURE tw0881_setbooleanarray(  CONST p     : tw0881_booleanarraypointer;
                            CONST index : word );
BEGIN
    INCLUDE(p^[index DIV 8],index MOD 8)
END;
{$pop}

{ Case tw1275.pp }
{$push}
var
  tw1275_sizes:array [1..3] of int64;
  tw1275_i:integer;

function tw1275_count:int64;
var
  tw1275_c:int64;
begin
  tw1275_c:=1;

  writeln(tw1275_c);
  tw1275_count:=tw1275_c;
end;
{$pop}

{ Case tw14307.pp }
{$push}
var
  tw14307_buf: array[0..3] of widechar;
  tw14307_s: string;
{$pop}

{ Case tw14812.pp }
{$push}
type
  tw14812_stdstrlong = string;

procedure tw14812_packstr // Convert string to packed array
   ( InStr: tw14812_stdstrlong;
    var tw14812_outarr: packed array of char);
var
  tw14812_i: longint;
begin
  if (low(tw14812_outarr)<>0) or
     (high(tw14812_outarr)<>5) then
    halt(1);
  if (instr<>'abc') then
    halt(2);
  for tw14812_i:=1 to length(instr) do
    tw14812_outarr[tw14812_i-1]:=instr[tw14812_i];
end;

var
  tw14812_a: packed array[5..10] of char;
{$pop}

{ Case tw1567.pp }
{$push}
procedure tw1567_hallo(a:array of word);
begin
   writeln(a[0],' ',a[1],' ',a[2]);
   if (a[0]<>999) or
      (a[1]<>999) or
      (a[2]<>999) then
    halt(1);
end;
{$pop}

begin
  { Case tb0494.pp }
  {$push}

  begin
tb0494_p1:=nil;
  if (tb0494_ca-tb0494_p1)=0 then
    halt(1);
  tb0494_p1:=tb0494_ca;
  end;
  {$pop}

  { Case tb0529.pp }
  {$push}

  begin
tb0529_s:=tb0529_dotest(['1', '2', '3']);
  if tb0529_s <> '123' then begin
    writeln('Test failed. S=', tb0529_s);
    Halt(1);
  end;
  end;
  {$pop}

  { Case tb0541.pp }
  {$push}

  begin
Move(tb0541_teststr[1], tb0541_buf[0], (Length(tb0541_teststr) + 1)*SizeOf(widechar));
  tb0541_s:=tb0541_buf;
  writeln(tb0541_s);
  tb0541_buf[0]:=#0;
  tb0541_s:=tb0541_buf;
  end;
  {$pop}

  { Case tb0555.pp }
  {$push}

  begin
tb0555_s:=tb0555_dotest(['аб', 'вг', 'де']);
  if tb0555_s <> 'абвгде' then begin
    writeln('Test failed. S=', tb0555_s);
    Halt(1);
  end;
  end;
  {$pop}

  { Case tb0708.pp }
  {$push}

  begin
tb0708_fillsomeqwords;
  end;
  {$pop}

  { Case tw0879.pp }
  {$push}

  begin
NEW(tw0879_aa);
   FOR tw0879_i:=LOW(tw0879_aa^) TO HIGH(tw0879_aa^) DO
     tw0879_aa^[tw0879_i]:=0;
  end;
  {$pop}

  { Case tw1275.pp }
  {$push}

  begin
tw1275_i:=1;
    tw1275_sizes[tw1275_i]:=tw1275_count();
    writeln(tw1275_sizes[tw1275_i]);
  end;
  {$pop}

  { Case tw14307.pp }
  {$push}

  begin
tw14307_buf[0]:='A';
  tw14307_buf[1]:='B';
  tw14307_buf[2]:='C';
  tw14307_buf[3]:=#0;

  tw14307_s:=Copy(tw14307_buf, 2, MaxInt);
  if tw14307_s = 'BC' then
    writeln('OK')
  else begin
    writeln('FAILED: ', tw14307_s);
    Halt(1);
  end;
  end;
  {$pop}

  { Case tw14812.pp }
  {$push}

  begin
tw14812_packstr('abc',tw14812_a);
  if (tw14812_a[5]<>'a') or
     (tw14812_a[6]<>'b') or
     (tw14812_a[7]<>'c') then
    halt(1);
  end;
  {$pop}

  { Case tw1567.pp }
  {$push}

  begin
tw1567_hallo([999,999,999]);
  end;
  {$pop}

end.
