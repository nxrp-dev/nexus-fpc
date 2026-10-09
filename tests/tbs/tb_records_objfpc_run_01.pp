{ Records regression cases; original case IDs are retained below. }

{ Case tb0282.pp }
{$push}
{ Old file: tbs0334.pp }
{  }

{$ifdef fpc}{$mode objfpc}{$endif}

type
  tb0282_tvarrec=record
    tb0282_vpointer : pointer;
  end;
var
  tb0282_r : tb0282_tvarrec;
  tb0282_b : boolean;
function tb0282_next: tb0282_tvarrec;
begin
  tb0282_next:=tb0282_r;
end;
{$pop}

{ Case tb0573.pp }
{$push}
{$mode objfpc}

type
  tb0573_tr1 = record
    tb0573_s: single;
  end;

  tb0573_tr2 = record
    case byte of
      1: (tb0573_s: single);
  end;

function tb0573_f1(tb0573_r1:tb0573_tr1): tb0573_tr1;
var
  tb0573_s: single;
begin
  tb0573_s:=tb0573_r1.tb0573_s;
  result.tb0573_s:=tb0573_s;
end;

function tb0573_f2(tb0573_r2:tb0573_tr2): tb0573_tr2;
var
  tb0573_s: single;
begin
  tb0573_s:=tb0573_r2.tb0573_s;
  result.tb0573_s:=tb0573_s;
end;

procedure tb0573_test;
var
  tb0573_r1,tb0573_r1a: tb0573_tr1;
  tb0573_r2,tb0573_r2a: tb0573_tr2;
begin
  tb0573_r1.tb0573_s:=1.0;
  tb0573_r2.tb0573_s:=2.0;
  tb0573_r1a:=tb0573_f1(tb0573_r1);
  tb0573_r2a:=tb0573_f2(tb0573_r2);
  if tb0573_r1a.tb0573_s<>1.0 then
    halt(1);
  if tb0573_r2a.tb0573_s<>2.0 then
    halt(1);
end;
{$pop}

{ Case tb0593.pp }
{$push}
{$mode objfpc}
type
  tb0593_tblocktype = (
    btNone,
    btBegin,
    btAsm,
    btEdgedBracket,
    btRoundBracket,
    btTry,
    btFinally,
    btExcept,
    btCase,
    btCaseOf,
    btCaseColon,
    btCaseElse,
    btRepeat,
    btIf,
    btIfElse,
    btClass,
    btInterface,
    btObject,
    btRecord
    );
  tb0593_tblock = record
    tb0593_typ: tb0593_tblocktype;
    tb0593_startpos: integer;
    tb0593_innerindent: integer;
    tb0593_innerstartpos: integer;
  end;
  tb0593_pblock = ^tb0593_tblock;
  tb0593_tblockstack = record
    tb0593_stack: tb0593_pblock;
    tb0593_capacity: integer;
    tb0593_top: integer;
  end;

function tb0593_topblocktype(const tb0593_stack: tb0593_tblockstack): tb0593_tblocktype;
  begin
    if tb0593_stack.tb0593_top>=0 then
      Result:=tb0593_stack.tb0593_stack[tb0593_stack.tb0593_top].tb0593_typ
    else
      Result:=btNone;
  end;
{$pop}

{ Case tw1103.pp }
{$push}
{$ifdef fpc}{$MODE OBJFPC }{$endif}
type
  tw1103_ptestrec = ^tw1103_testrec;
  tw1103_testrec = record
    tw1103_fstring  : AnsiString;
    tw1103_fint1    : Longint;
    tw1103_fint2    : Longint;
    tw1103_fretaddr : Longint;
  end;

function tw1103_getgroupinfop: tw1103_ptestrec;
var
  tw1103_s : string;
begin
  new(Result);
  tw1103_s:=' Wr';
  Result^.tw1103_fstring := 'Test' + tw1103_s;
  Result^.tw1103_fretaddr := 0;
end;

function tw1103_getgroupinfo: tw1103_testrec;
var
  tw1103_s : string;
begin
  tw1103_s:=' Wr';
  Result.tw1103_fstring := 'Test' + tw1103_s;
  Result.tw1103_fretaddr := 0;
end;

function tw1103_selectgroup: tw1103_testrec;
begin
  Result := tw1103_getgroupinfo;
end;

procedure tw1103_p;
begin
  tw1103_selectgroup;
end;

procedure tw1103_destroystack;
var
  tw1103_s : shortstring;
  tw1103_p : pchar;
  tw1103_i : longint;
begin
  for tw1103_i:=0 to 255 do
   tw1103_s[tw1103_i]:=#$90;
  getmem(tw1103_p,sizeof(tw1103_testrec));
  for tw1103_i:=0 to sizeof(tw1103_testrec)-1 do
   tw1103_p[tw1103_i]:=#$ff;
  freemem(tw1103_p);
end;

var
  tw1103_p1 : tw1103_ptestrec;
{$pop}

{ Case tw1409.pp }
{$push}
{$MODE objfpc}
type
  tw1409_tpoint = record
    tw1409_x, tw1409_y: Integer;
  end;

procedure tw1409_test(const Args: array of tw1409_tpoint);
begin
{$ifndef VER1_0}
  writeln(length(Args));
  if length(Args)<>2 then
   halt(1);
{$endif VER1_0}
  writeln(high(Args));
  if high(Args)<>1 then
   halt(1);
  writeln(Args[0].tw1409_x,',',Args[0].tw1409_y);
  if (Args[0].tw1409_x<>10) or (Args[0].tw1409_y<>20) then
   halt(1);
  writeln(Args[1].tw1409_x,',',Args[1].tw1409_y);
  if (Args[1].tw1409_x<>30) or (Args[1].tw1409_y<>40) then
   halt(1);
end;

const
  tw1409_p1: tw1409_tpoint = (tw1409_x: 10; tw1409_y: 20);
  tw1409_p2: tw1409_tpoint = (tw1409_x: 30; tw1409_y: 40);
{$pop}

{ Case tw17283.pp }
{$push}
{$mode objfpc}

  type
    tw17283_tr_32=packed record
      case integer of
      1: (words: array [0..1] of word);
      2: (low,high: word);
      end;
(*
  procedure f_ref(var l,h:word);
  begin
    l:=1;
    h:=2;
    end;

  function f_test1:longint;
  begin
    result:=$12345678;
    f_ref(tr_32(result).words[0],tr_32(result).words[1]);
    end;

  function f_test2:longint;
  begin
    result:=$12345678;
    f_ref(tr_32(result).low,tr_32(result).high);
    end;

  function f_test3:longint;
  var
    q: longint;
  begin
    q:=$12345678;
    f_ref(tr_32(q).words[0],tr_32(q).words[1]);
    result:=q;
    end;
*)
  function tw17283_f_test4:longint;
  var
    tw17283_q: longint;
  begin
    tw17283_q:=$12345678;
    tw17283_tr_32(tw17283_q).words[0]:=1;
    tw17283_tr_32(tw17283_q).words[1]:=2;
    result:=tw17283_q;
    end;

  var
    tw17283_l,tw17283_q: longint;
{$pop}

{ Case tw17862.pp }
{$push}
{$mode objfpc}
type
 tw17862_tfield = record
   tw17862_a,tw17862_b,tw17862_c: byte;
 end;
 tw17862_tarray = bitpacked array[0..3] of tw17862_tfield;

procedure tw17862_test(var tw17862_a: tw17862_tfield);
begin
  if tw17862_a.tw17862_a<>3 then
    halt(1);
  if tw17862_a.tw17862_b<>4 then
    halt(2);
  if tw17862_a.tw17862_c<>5 then
    halt(3);
end;

var
  tw17862_a: tw17862_tarray;
{$pop}

{ Case tw2514.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2514 }
{ Submitted by "Andreas Horst" on  2003-05-28 }
{ e-mail: AndyHorst@web.de }
{$mode objfpc}
type tw2514_trgb=record
 tw2514_trgb2hsl: record
 tw2514_r,tw2514_g,tw2514_b : extended;
 tw2514_l,tw2514_h,tw2514_s : extended;
 end;
 end;

 tw2514_thsl=record end;

function tw2514_trgb2hsl(tw2514_rgb:tw2514_trgb):tw2514_thsl;
var tw2514_maxcolor,tw2514_mincolor:Extended;
begin
  with tw2514_rgb,tw2514_trgb2hsl do begin
    if tw2514_r<0 then tw2514_r:=0;
    if tw2514_r>1 then tw2514_r:=1;
    if tw2514_g<0 then tw2514_g:=0;
    if tw2514_g>1 then tw2514_g:=1;
    if tw2514_b<0 then tw2514_b:=0;
    if tw2514_b>1 then tw2514_b:=1;
    if tw2514_r<tw2514_g then begin
      tw2514_mincolor:=tw2514_r;
      tw2514_maxcolor:=tw2514_g;
    end else begin
      tw2514_mincolor:=tw2514_g;
      tw2514_maxcolor:=tw2514_r;
    end;
    if tw2514_b<tw2514_mincolor then
      tw2514_mincolor:=tw2514_b;
    if tw2514_b>tw2514_maxcolor then
      tw2514_maxcolor:=tw2514_b;
    if tw2514_maxcolor=tw2514_mincolor then begin
      tw2514_l:=tw2514_maxcolor;
      tw2514_s:=0;
      tw2514_h:=0;
      Exit;
    end;
    tw2514_l:=(tw2514_maxcolor+tw2514_mincolor)/2;
    if tw2514_l<0.5 then
      tw2514_s:=(tw2514_maxcolor-tw2514_mincolor)/(tw2514_maxcolor+tw2514_mincolor)
    else
      tw2514_s:=(tw2514_maxcolor-tw2514_mincolor)/(2-tw2514_maxcolor-tw2514_mincolor);
    if tw2514_r=tw2514_maxcolor then tw2514_h:=(tw2514_g-tw2514_b)/(tw2514_maxcolor-tw2514_mincolor);
    if tw2514_g=tw2514_maxcolor then tw2514_h:=2+(tw2514_b-tw2514_r)/(tw2514_maxcolor-tw2514_mincolor);
    if tw2514_b=tw2514_maxcolor then tw2514_h:=4+(tw2514_r-tw2514_g)/(tw2514_maxcolor-tw2514_mincolor);
  end
end;

var
  tw2514_rgb : tw2514_trgb;
  tw2514_i : longint;
{$pop}

{ Case tw25895.pp }
{$push}
{$MODE OBJFPC}

type
   tw25895_tdummy = record end;

function tw25895_foo(): tw25895_tdummy;
begin
   Result := Default(tw25895_tdummy);
end; // Fatal: Internal error 2010053111
{$pop}

{ Case tw29547.pp }
{$push}
{$mode objfpc}

type
    tw29547_point2d = record
      tw29547_x, tw29547_y: Single;
    end;

    tw29547_line = record
        tw29547_start : tw29547_point2d;
        tw29547_endp : tw29547_point2d;
    end;

function tw29547_linefrom(p1, p2: tw29547_point2d): tw29547_line;
begin
    result.tw29547_start := p1;
    result.tw29547_endp := p2;
end;

procedure tw29547_main();
var
    tw29547_l: tw29547_line;
    tw29547_pt1, tw29547_pt2: tw29547_point2d;
begin
    tw29547_pt1.tw29547_x := 1.0;
    tw29547_pt2.tw29547_x := 2.0;
    tw29547_l := tw29547_linefrom(tw29547_pt1, tw29547_pt2);
    if (tw29547_l.tw29547_start.tw29547_x<>1.0) or
       (tw29547_l.tw29547_endp.tw29547_x<>2.0) then
      halt(1);
end;
{$pop}

{ Case tw29933.pp }
{$push}
{$mode objfpc}

type
  tw29933_tpoint =
{$ifndef FPC_REQUIRES_PROPER_ALIGNMENT}
  packed
{$endif FPC_REQUIRES_PROPER_ALIGNMENT}
  record
    tw29933_x : Longint;
    tw29933_y : Longint;
  end;

function tw29933_point(tw29933_x,tw29933_y : Integer) : tw29933_tpoint; inline;
begin
  tw29933_point.tw29933_x:=tw29933_x;
  tw29933_point.tw29933_y:=tw29933_y;
end;

procedure tw29933_test(p: tw29933_tpoint);
begin
  if (p.tw29933_x<>6) or
     (p.tw29933_y<>4) then
    halt(1)
end;

var
  tw29933_pt: tw29933_tpoint;
  tw29933_indent, tw29933_secondy: longint;
{$pop}

{ Case tw36381.pp }
{$push}
{$mode objfpc}

type
  tw36381_tvec2 = record
    tw36381_x, tw36381_y: single;
  end;

function tw36381_viewtoworld (tw36381_x, tw36381_y: single): tw36381_tvec2; overload;
begin
  result.tw36381_x := tw36381_x;
  result.tw36381_y := tw36381_y;
end;

function tw36381_viewtoworld (tw36381_pt: tw36381_tvec2): tw36381_tvec2; overload; inline;
begin
  result := tw36381_viewtoworld(tw36381_pt.tw36381_x, tw36381_pt.tw36381_y);
end;

var
  tw36381_pt: tw36381_tvec2;
{$pop}

begin
  { Case tb0282.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tb0282_r.tb0282_vpointer:=@tb0282_b;
  { The result of next is loaded and a value is assigned }
  with tb0282_next do
   boolean(tb0282_vpointer^) := true;
  if not tb0282_b then
   writeln('Error with assigning to function result');
  end;
  {$pop}

  { Case tb0573.pp }
  {$push}

  begin
tb0573_test;
  end;
  {$pop}

  { Case tw1103.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw1103_destroystack;
  tw1103_p;
  tw1103_p1:=tw1103_getgroupinfop;
  dispose(tw1103_p1);
  end;
  {$pop}

  { Case tw1409.pp }
  {$push}
{$ifndef VER1_0}
{$endif VER1_0}
  begin
tw1409_test([tw1409_p1,tw1409_p2]);
  end;
  {$pop}

  { Case tw17283.pp }
  {$push}

  begin
(*
    l:=f_test1;
    if (tr_32(l).low<>1) or
       (tr_32(l).high<>2) then
      halt(1);

    l:=f_test2;
    if (tr_32(l).low<>1) or
       (tr_32(l).high<>2) then
      halt(2);

    q:=$12345678;
    f_ref(tr_32(q).words[0],tr_32(q).words[1]);
    if (tr_32(q).low<>1) or
       (tr_32(q).high<>2) then
      halt(3);

    q:=$12345678;
    f_ref(tr_32(q).low,tr_32(q).high);
    if (tr_32(q).low<>1) or
       (tr_32(q).high<>2) then
      halt(4);

    l:=f_test3;
    if (tr_32(l).low<>1) or
       (tr_32(l).high<>2) then
      halt(5);
*)
    tw17283_l:=tw17283_f_test4;
    if (tw17283_tr_32(tw17283_l).low<>1) or
       (tw17283_tr_32(tw17283_l).high<>2) then
      halt(6);
  end;
  {$pop}

  { Case tw17862.pp }
  {$push}

  begin
tw17862_a[1].tw17862_a:=3;
  tw17862_a[1].tw17862_b:=4;
  tw17862_a[1].tw17862_c:=5;
  tw17862_test(tw17862_a[1]);
  end;
  {$pop}

  { Case tw2514.pp }
  {$push}

  begin
fillchar(tw2514_rgb,sizeof(tw2514_rgb),0);
  for tw2514_i:=0 to 100 do
    tw2514_trgb2hsl(tw2514_rgb);
  end;
  {$pop}

  { Case tw25895.pp }
  {$push}

  begin
tw25895_foo();
  end;
  {$pop}

  { Case tw29547.pp }
  {$push}

  begin
tw29547_main();
  end;
  {$pop}

  { Case tw29933.pp }
  {$push}
{$ifndef FPC_REQUIRES_PROPER_ALIGNMENT}
{$endif FPC_REQUIRES_PROPER_ALIGNMENT}
  begin
tw29933_indent:=5;
  tw29933_secondy:=2;
  tw29933_test(tw29933_point(tw29933_indent+1,tw29933_secondy+2));
  end;
  {$pop}

  { Case tw36381.pp }
  {$push}

  begin
tw36381_pt.tw36381_x:=1.0;
  tw36381_pt.tw36381_y:=2.0;
  // ERROR: Internal error 2009112601
  tw36381_pt := tw36381_viewtoworld(tw36381_pt);
  if tw36381_pt.tw36381_x<>1.0 then
    halt(1);
  if tw36381_pt.tw36381_y<>2.0 then
    halt(2);
  end;
  {$pop}

end.
