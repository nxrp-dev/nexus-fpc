{ Records regression cases; original case IDs are retained below. }

{ Case tb0070.pp }
{$push}
{ Old file: tbf0343.pp }

{$mode delphi}
type
  tb0070_tlistentry = record
    tb0070_next: ^tb0070_tlistentry;                    // delphi and fpc allows this now
    tb0070_data: Integer;
  end;
{$pop}

{ Case tb0355.pp }
{$push}
{$mode delphi}

const
  tb0355_csv_internal = 10;

type
  tb0355_ptyperec = ^tb0355_ttyperec;
  tb0355_ttyperec = record
    tb0355_atypeid: Word;
  end;

function tb0355_changetype(newtype: tb0355_ptyperec): Pointer;

begin
  if NewType.tb0355_atypeid = tb0355_csv_internal then
  begin
  end;
end;
{$pop}

{ Case tb0516.pp }
{$push}
{$mode delphi}

type
  tb0516_ta = (ea,eb);
  tb0516_tb = (e1,e2);
  tb0516_tr = record
    case a: byte of
      0..5: (l: longint);
      100..20: (c: cardinal);
  end;
{$pop}

{ Case tb0599.pp }
{$push}
{$mode delphi}

type
     tb0599_tvector2=record
      case byte of
       0:(x,y:single);
       1:(u,v:single);
       2:(s,t:single);
       3:(xy:array[0..1] of single);
       4:(uv:array[0..1] of single);
       5:(st:array[0..1] of single);
     end;

function tb0599_vector2length(const v:tb0599_tvector2):single;
begin
 result:=sqrt(sqr(v.x)+sqr(v.y));
end;

function tb0599_vector2sub(const tb0599_v1,tb0599_v2:tb0599_tvector2):tb0599_tvector2;
begin
 result.x:=tb0599_v1.x-tb0599_v2.x;
 result.y:=tb0599_v1.y-tb0599_v2.y;
end;

function tb0599_vector2dist(const tb0599_v1,tb0599_v2:tb0599_tvector2):single;
begin
 result:=tb0599_vector2length(tb0599_vector2sub(tb0599_v2,tb0599_v1));
end;

var
  tb0599_v1, tb0599_v2: tb0599_tvector2;
{$pop}

{ Case tw2187.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2187 }
{ Submitted by "Artur Kornilowicz" on  2002-10-18 }
{ e-mail: arturk@math.uwb.edu.pl }
{$mode delphi}
type tw2187_x = record
            tw2187_s : string;
            tw2187_a : ^byte;
         end;

var tw2187_a: array [1..2] of tw2187_x;
{$pop}

{ Case tw2504.pp }
{$push}
{$ifdef fpc}{$mode delphi}{$endif}

type
  tw2504_brec = record
    tw2504_fu: Function:Longint;
  end;

var
  tw2504_a : Longint;
  tw2504_b : tw2504_brec;

function tw2504_f1:longint;
begin
  result:=10;
end;
{$pop}

{ Case tw29372.pp }
{$push}
{$MODE DELPHI}
type
  tw29372_tr1 = record
    tw29372_a, tw29372_b, tw29372_c: Int64;
    constructor Create(_A, _B, _C: Int64);
  end;

  tw29372_tr2 = record
    tw29372_d, tw29372_e, tw29372_f: Int64;
    constructor Create(_D, _E, _F: Int64);
  end;

  constructor tw29372_tr1.Create(_A, _B, _C: Int64);
  begin
    tw29372_a := _A;
    tw29372_b := _B;
    tw29372_c := _C;
  end;

  constructor tw29372_tr2.Create(_D, _E, _F: Int64);
  begin
    tw29372_d := _D;
    tw29372_e := _E;
    tw29372_f := _F;
  end;

{ Note: unlike in the file attached at #29372 we use "const" both times to
        trigger the error on x86_64 as well }
procedure tw29372_foo(const _1: tw29372_tr1; const tw29372__2: tw29372_tr2);
begin
  if _1.tw29372_a <> 1 then
    Halt(1);
  if _1.tw29372_b <> 2 then
    Halt(2);
  if _1.tw29372_c <> 3 then
    Halt(3);
  if tw29372__2.tw29372_d <> 4 then
    Halt(2);
  if tw29372__2.tw29372_e <> 5 then
    Halt(5);
  if tw29372__2.tw29372_f <> 6 then
    Halt(6);
end;
{$pop}

{ Case tw3777.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3777 }
{ Submitted by "David Fuchs" on  2005-03-12 }
{ e-mail: drfuchs@yahoo.com }
{$mode delphi}
{$T+}
type
  tw3777_mytype = record
   tw3777_myfield: ^PChar;
   end;

procedure tw3777_fyl_use_ptrs(var f: tw3777_mytype; var myparm);
begin
  f.tw3777_myfield := addr(myparm);
end;
{$pop}

{ Case tw9128.pp }
{$push}
{$MODE delphi}

type
  tw9128_timageformat = (ifIndex8, ifA8R8G8B8);

  tw9128_timagedata = packed record
    tw9128_width: Integer;
    tw9128_height: Integer;
    tw9128_format: tw9128_timageformat;
    tw9128_size: Integer;
    tw9128_bits: Pointer;
    tw9128_palette: Pointer;
  end;

  tw9128_tdynarray = array of tw9128_timagedata;

procedure tw9128_modimage(var Img: tw9128_timagedata);
begin
  Img.tw9128_width := 128;
  Img.tw9128_height := 128;
end;

procedure tw9128_arraystuff(const Arr: tw9128_tdynarray);
var
  tw9128_i: Integer;
begin
  for tw9128_i := 0 to High(Arr) do
    tw9128_modimage(Arr[tw9128_i]);
end;

var
  tw9128_myarr: tw9128_tdynarray;
{$pop}

begin
  { Case tb0599.pp }
  {$push}

  begin
tb0599_v1.x:=2.0;
  tb0599_v1.y:=3.0;
  tb0599_v2.x:=5.0;
  tb0599_v2.y:=7.0;
  if trunc(tb0599_vector2dist(tb0599_v1,tb0599_v2))<>5 then
    halt(1);
  end;
  {$pop}

  { Case tw2504.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw2504_b.tw2504_fu:=tw2504_f1;
//  a:=b.fu(); // works well
  tw2504_a:=tw2504_b.tw2504_fu;   // causes "Error: incompatible types"
  writeln(tw2504_a);
  if tw2504_a<>10 then
   halt(1);
  end;
  {$pop}

  { Case tw29372.pp }
  {$push}

  begin
tw29372_foo(tw29372_tr1.Create(1, 2, 3), tw29372_tr2.Create(4,5,6));
  end;
  {$pop}

  { Case tw9128.pp }
  {$push}

  begin
SetLength(tw9128_myarr, 5);
  tw9128_arraystuff(tw9128_myarr);
  end;
  {$pop}

end.
