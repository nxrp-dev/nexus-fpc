{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode delphi}


{ Source group: tb_arrays_delphi_run_01.pp }
{$push}

{ Case tb0293.pp }
{$push}
{ Old file: tbs0348.pp }
{  }



type tb0293_fluparr=array[0..1000] of longint;
     tb0293_flupptr=^tb0293_fluparr;

var tb0293_flup : tb0293_flupptr;
    tb0293_flupresult : longint;
    tb0293_flupa : tb0293_fluparr;
{$pop}

{ Case tb0439.pp }
{$push}


var
  tb0439_a : array[0..32] of char;
  tb0439_p : pchar;
  tb0439_i : integer;
{$pop}

{ Case tb0464.pp }
{$push}


var
  tb0464_a1 : Array of Byte;
{$pop}

{ Case tb0646b.pp }
{$push}


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
{$ifdef fpc}{$endif}

var
 tw1709_x: array of byte;
{$pop}

{ Case tw1765.pp }
{$push}


type tw1765_mytype=array[1..2] of string;
const tw1765_myconst:tw1765_mytype=('foo','bar');

procedure tw1765_myproc(myparam:tw1765_mytype);
begin
 writeln(myparam[1],' ',myparam[2]);
end;
{$pop}

{ Case tw2291.pp }
{$push}


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

{$ifdef fpc}{$endif}
var tw2946_p:array of pchar;
    tw2946_t: ^pchar;
{$pop}


{$pop}

{ Source group: tb_arrays_delphi_run_02.pp }
{$push}

{ Case tw3048.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3048 }
{ Submitted by "GBD" on  2004-04-15 }
{ e-mail:  }

var tw3048_a ,tw3048_b : array of word;
{$pop}

{ Case tw3286.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3286 }
{ Submitted by "Frank Kintrup" on  2004-08-31 }
{ e-mail: frank.kintrup@gmx.de }

var
  tw3286_p : Pointer;
  tw3286_a : array of Integer;
{$pop}

{ Case tw3441.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3441 }
{ Submitted by "Alexey Barkovoy" on  2004-12-07 }
{ e-mail: clootie@ixbt.com }
{$IFDEF FPC}{$ENDIF}
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

{$ifdef fpc}{$endif}
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
{$ifdef fpc}{$endif}
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


{$pop}

{ Source group: tb_records_delphi_run_01.pp }
{$push}

{ Case tb0070.pp }
{$push}
{ Old file: tbf0343.pp }


type
  tb0070_tlistentry = record
    tb0070_next: ^tb0070_tlistentry;                    // delphi and fpc allows this now
    tb0070_data: Integer;
  end;
{$pop}

{ Case tb0355.pp }
{$push}


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


type
  tb0516_ta = (ea,eb);
  tb0516_tb = (tb0516_e1,tb0516_e2);
  tb0516_tr = record
    case a: byte of
      0..5: (l: longint);
      100..20: (c: cardinal);
  end;
{$pop}

{ Case tb0599.pp }
{$push}


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

type tw2187_x = record
            tw2187_s : string;
            tw2187_a : ^byte;
         end;

var tw2187_a: array [1..2] of tw2187_x;
{$pop}

{ Case tw2504.pp }
{$push}
{$ifdef fpc}{$endif}

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


{$pop}

{ Source group: tb_objects_delphi_run_01.pp }
{$push}

{ Case tb0681.pp }
{$push}


type tb0681_r = record
    var tb0681_x: Integer;
    function tb0681_foo: Integer;
end;

function tb0681_r.tb0681_foo: Integer;
begin
    result := tb0681_x
end;

var    tb0681_f: function : Integer of object;
    tb0681_z: tb0681_r = (tb0681_x:42);
{$pop}

{ Case tw14743.pp }
{$push}


type
    tw14743_parent = object
        constructor tw14743_init;
    end;

    tw14743_child = object(tw14743_parent)
        constructor tw14743_init(a : byte);reintroduce;
    end;

constructor tw14743_parent.tw14743_init;
begin
end;

constructor tw14743_child.tw14743_init(a : byte);
begin
end;
{$pop}

{ Case tw2595.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2595 }
{ Submitted by "Michalis Kamburelis" on  2003-07-24 }
{ e-mail: michalis@camelot.homedns.org }

{ With fpc 1.1 (from snapshot downloaded at 23.07.2003) this program causes compilation error  "Error: Wrong number of parameters specified"
  near the "F(1)" statement. But you can see everything is ok and there is no error.
  (Of course, this particular program would cause runtime error because F is not initialized, but it's semantically correct).
  Error is only under DELPHI and TP modes.
  Change declaration
    TFuncByObject = function(i:Integer):boolean of object;
  to
    TFuncByObject = procedure(i:Integer);
  (make procedure instead of a function) and everything will compile ok.
  Change it to
    TFuncByObject = function(i:Integer):boolean;
  (no longer "by object") and again everything will compile ok.
  It has to be "function" and "by object" to cause the bug.

  Observed with FPC under win32 and linux (i386).
}



type
  tw2595_tfuncbyobject = function(tw2595_i:Integer):boolean of object;

var tw2595_f:tw2595_tfuncbyobject;
  tw2595_i : integer;
{$pop}

{ Case tw2776.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2776 }
{ Submitted by "Vincent Snijders" on  2003-11-09 }
{ e-mail: vslist@zonnet.nl }

var
  tw2776_a: procedure of object;
{$pop}

{ Case tw31305.pp }
{$push}


type
  tw31305_tinterfacestublog = object
    tw31305_timestamp64: Int64;
    tw31305_waserror: boolean;
    tw31305_method: Pointer;
    tw31305_params: UTF8String;
    tw31305_customresults: UTF8String;
  end;

var
  tw31305_a,tw31305_b: tw31305_tinterfacestublog;
{$pop}

{ Case tw4209.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4209 }
{ Submitted by "Ivo Steinmann" on  2005-07-22 }
{ e-mail: isteinmann@bluewin.ch }



var
  tw4209_err : boolean;

type
  tw4209_xmethod = procedure of object;
  tw4209_xprocedure = procedure;

procedure tw4209_test(const Callback: tw4209_xmethod); overload;
begin
end;

procedure tw4209_test(const Callback: tw4209_xprocedure); overload;
begin
  writeln('ok');
  tw4209_err:=false;
end;

procedure tw4209_foobar;
begin
end;
{$pop}


{$pop}

{ Source group: tb_sets_delphi_run_01.pp }
{$push}

{ Case tw11288.pp }
{$push}


type
  tw11288_tenum1 = (en1, en2);
  tw11288_tenum2 = (en3, en4);

  tw11288_tset1 = set of tw11288_tenum1;
  tw11288_tset2 = set of tw11288_tenum2;

procedure tw11288_dosomethingwithset(ASet: tw11288_tset1); overload;
begin

end;

procedure tw11288_dosomethingwithset(ASet: tw11288_tset2); overload;
begin

end;
{$pop}

{ Case tw37806.pp }
{$push}


procedure tw37806_turnsetelem<tw37806_tset, tw37806_telem>(var aSet: tw37806_tset; tw37806_aelem: tw37806_telem; tw37806_aon: Boolean);
begin
  if tw37806_aon then
    Include(aSet, tw37806_aelem)
  else
    Exclude(aSet, tw37806_aelem);
end;

type
  tw37806_telem = (One, Two, Three, Four, Five);
  tw37806_tset = set of tw37806_telem;

var
  tw37806_s: tw37806_tset = [];
{$pop}

{ Case tw38497.pp }
{$push}


type
  tw38497_talphabet = (A, B, C);
  tw38497_talphabets = set of tw38497_talphabet;

  procedure tw38497_test<TEnum, TSet>(E: TEnum; tw38497_s: TSet);
  var
    tw38497_i: TEnum;
    B: Boolean;
  begin
    B := [E] <= tw38497_s;
    if E in tw38497_s then
      WriteLn(E);
    for tw38497_i := Low(TEnum) to High(TEnum) do
      if tw38497_i in tw38497_s then
      WriteLn(tw38497_i);
  end;
{$pop}

{ Case tw8172.pp }
{$push}
{$IFDEF FPC}


  {$packenum 1}
  {$packset 1}
{$ENDIF}

type
  { the flags that are sent with every message }
  tw8172_tnxmessageheaderflag = (
    {the message header is followed by a string}
    mhfErrorMessage,
    { reserved for future use }
    mhfReserved1,
    { reserved for future use }
    mhfReserved2,
    { reserved for future use }
    mhfReserved3,
    { reserved for future use }
    mhfReserved4,
    { reserved for future use }
    mhfReserved5,
    { reserved for future use }
    mhfReserved6,
    { reserved for future use }
    mhfReserved7
  );

  { set of Message flags }
  tw8172_tnxmessageheaderflags = set of tw8172_tnxmessageheaderflag;
{$pop}


{$pop}

{ Source group: tb_generics_delphi_run_01.pp }
{$push}

{ Case tw18567.pp }
{$push}


type
  tw18567_tsomerecord <TData> = record
    tw18567_data: TData;
    class operator Explicit(a: TData) : tw18567_tsomerecord <TData>;
  end;

  class operator tw18567_tsomerecord <TData>.Explicit (a: TData): tw18567_tsomerecord <TData>;
  begin

  end;
{$pop}

{ Case tw21592.pp }
{$push}


type
  tw21592_tbytesoverlay<T> = array [0..SizeOf(T) - 1] of Byte;
    { Error: Identifier not found "T" }

var
  tw21592_a : tw21592_tbytesoverlay<Byte>;
{$pop}

{ Case tw23130.pp }
{$push}


type
  tw23130_tfunction<TArgument, TResult> = function (const arg: TArgument): TResult;

  tw23130_twrapper = record
    class function tw23130_z(const arg: Integer): Boolean; static;
    class procedure tw23130_w; static;
  end;

  tw23130_twrapper2 = class
    procedure tw23130_zz(f: tw23130_tfunction<Integer, Boolean>);
  end;

class function tw23130_twrapper.tw23130_z(const arg: Integer): Boolean;
begin
  Result := arg < 0;
end;

class procedure tw23130_twrapper.tw23130_w;
begin
  with tw23130_twrapper2.Create do begin
    tw23130_zz(@tw23130_z);  { Replace with @TWrapper.Z to get rid of the error }
    Free;
  end;
end;

procedure tw23130_twrapper2.tw23130_zz(f: tw23130_tfunction<Integer, Boolean>);
begin
end;
{$pop}

{ Case tw34497b.pp }
{$push}
{$IFDEF FPC}{$ENDIF}
type
  tw34497b_tgenrec<T1, T2> = record
    tw34497b_a: T1;
    tw34497b_b: T2;
    class operator Implicit(const Rec: tw34497b_tgenrec<T1, T2>): T1;
    class operator Implicit(const Rec: tw34497b_tgenrec<T1, T2>): T2;
  end;

  class operator tw34497b_tgenrec<T1, T2>.Implicit(const Rec: tw34497b_tgenrec<T1, T2>): T1;
  begin
    Result := Rec.tw34497b_a;
  end;

  class operator tw34497b_tgenrec<T1, T2>.Implicit(const Rec: tw34497b_tgenrec<T1, T2>): T2;
  begin
    Result := Rec.tw34497b_b;
  end;
{$pop}

{ Case tw37107.pp }
{$push}
{$IFDEF FPC}{$ENDIF}

type
  tw37107_ttest<T: Record> = class(TObject)
    procedure tw37107_testit();
  end;

procedure tw37107_ttest<T>.tw37107_testit();
begin
  WriteLn('=== ', 1 div SizeOf(T));
  if SizeOf(T) > 0 then
    WriteLn('I''m reachable!')
end;
{$pop}


{$pop}

{ Source group: tb_generics_delphi_run_02.pp }
{$push}

{ Case tw20577a.pp }
{$push}
{$H+}

type

  tw20577a_tsimplehashbucket<T> = record
     tw20577a_hashcode : Integer;
     tw20577a_value : T;
  end;

  tw20577a_tsimplehashbucketarray<T> = array of tw20577a_tsimplehashbucket<T>;

  { TSimpleHash }

  tw20577a_tsimplehash<T> = class
    private
    tw20577a_fbuckets : tw20577a_tsimplehashbucketarray<T>;
  procedure tw20577a_test;
  end;

{ TSimpleHash<T> }

procedure tw20577a_tsimplehash<T>.tw20577a_test;
var
  tw20577a_oldbuckets : tw20577a_tsimplehashbucketarray<T>;
begin
  tw20577a_oldbuckets := tw20577a_fbuckets;

end;
{$pop}

{ Case tw20577b.pp }
{$push}
{$H+}

type

  tw20577b_tsimplehashbucket<T> = record
     tw20577b_hashcode : Integer;
     tw20577b_value : T;
  end;

  tw20577b_tsimplehashbucketarray<T> = array of tw20577b_tsimplehashbucket<T>;

  { TSimpleHash }

  tw20577b_tsimplehash<T> = class
  private
    type
      tw20577b_thashbucket = tw20577b_tsimplehashbucket<T>;
    var
      tw20577b_fbuckets: array of tw20577b_thashbucket;
  procedure tw20577b_test;
  end;

{ TSimpleHash<T> }

procedure tw20577b_tsimplehash<T>.tw20577b_test;
var
  tw20577b_oldbuckets : tw20577b_tsimplehashbucketarray<T>;
begin
  tw20577b_oldbuckets := tw20577b_fbuckets;

end;
{$pop}


{$pop}

{ Source group: tb_ordinal_operations_delphi_run_01.pp }
{$push}

{ Case tb0602.pp }
{$push}
{ This test explicity generates
  dec(w,2) with w=1 of unsigned type word,
  this generates range check error.
  Thus, we need an explicit $R- }
{$R-}
{$ifdef fpc}

{$endif}

procedure tb0602_test;
var
  tb0602_w: word;
  tb0602_arr: array[0..1] of word;
begin
  tb0602_arr[1]:=2;
  tb0602_w:=1;
  dec(tb0602_w,tb0602_arr[tb0602_w]);
  if cardinal(tb0602_w)<>$ffff then
    halt(1);
end;
{$pop}

{ Case tb0615.pp }
{$push}
var
  tb0615_s : set of 0..7;
{$pop}

{ Case tb0689.pp }
{$push}
{ Old file: tbf0326.pp }
{  }


const
    tb0689_anyconst = %11111;
{$pop}


{$pop}

{ Source group: tb_pointer_casts_delphi_run_01.pp }
{$push}

{ Case tb0400.pp }
{$push}
var
   tb0400_b : byte;
   tb0400_i : smallint;
   tb0400_i64 : int64;
   tb0400_q : qword;
   tb0400_p : pointer;
{$pop}

{ Case tb0423.pp }
{$push}
{$ifdef fpc}{$endif}

type
{$ifndef fpc}
  codepointer = pointer;
{$endif}
   tb0423_tmethod = record
      code : codepointer;
      data : pointer;
   end;

var
   tb0423_p : procedure(l : longint) of object;
{$pop}

{ Case tb0443.pp }
{$push}
{$ifdef fpc}

{$else}
type
  qword = int64;
{$endif}

var
   tb0443_b : byte;
   tb0443_i : smallint;
   tb0443_i64 : int64;
   tb0443_q : qword;
   tb0443_p : pointer;
{$pop}

{ Case tb0465.pp }
{$push}
var tb0465_x:pointer;
{$pop}

{ Case tb0539.pp }
{$push}
const
  tb0539_o = TObject(0);

var
  tb0539_o2 : TObject;

{$r+}
{$pop}

{ Case tb0554.pp }
{$push}
// check whether enums and integers can be casted to object references; this
// should work in Delphi mode (is Delphi compatible)

{$packenum 2}
type
  tb0554_tenum = (tb0554_a, tb0554_b, tb0554_c);

var
  tb0554_i : Word;
  tb0554_e : tb0554_tenum;
  tb0554_o : TObject;
{$pop}

{ Case tb0594.pp }
{$push}
{$ifdef fpc}

{$endif}

type
{$ifndef fpc}
  codepointer = pointer;
{$endif}
  tb0594_tc = class
    class procedure tb0594_test;
  end;

  tb0594_tp = procedure;
  tb0594_tp2 = procedure of object;

class procedure tb0594_tc.tb0594_test;
begin
end;

var
  tb0594_p: tb0594_tp;
  tb0594_p2: tb0594_tp2;
{$pop}


{$pop}

begin
  { Source group: tb_arrays_delphi_run_01.pp }
  {$push}


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


end;
  {$pop}

  { Source group: tb_arrays_delphi_run_02.pp }
  {$push}


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


end;
  {$pop}

  { Source group: tb_records_delphi_run_01.pp }
  {$push}


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


end;
  {$pop}

  { Source group: tb_objects_delphi_run_01.pp }
  {$push}


begin
  { Case tb0681.pp }
  {$push}

  begin
// EXPECTED: gets compiled
    // ACTUAL: 'Error: Incompatible types'
    tb0681_f := tb0681_z.tb0681_foo;
    if tb0681_f() <> 42 then
      Halt(1);
  end;
  {$pop}

  { Case tw2595.pp }
  {$push}

  begin
tw2595_i:=0;
  if tw2595_i=1 then
    tw2595_f(1);
  end;
  {$pop}

  { Case tw2776.pp }
  {$push}

  begin
tw2776_a:=nil;
  if assigned(tw2776_a)
    then ;
  end;
  {$pop}

  { Case tw31305.pp }
  {$push}

  begin
tw31305_a.tw31305_method := Pointer($1);
  CopyArray(@tw31305_b, @tw31305_a, TypeInfo(tw31305_tinterfacestublog), 1);
  if not Assigned(tw31305_b.tw31305_method) then
    Halt(1);
  end;
  {$pop}

  { Case tw4209.pp }
  {$push}

  begin
tw4209_err:=true;
  tw4209_test(tw4209_foobar);
  if tw4209_err then
    halt(1);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_sets_delphi_run_01.pp }
  {$push}


begin
  { Case tw11288.pp }
  {$push}

  begin
tw11288_dosomethingwithset([en1]);
  end;
  {$pop}

  { Case tw37806.pp }
  {$push}

  begin
tw37806_turnsetelem<tw37806_tset, tw37806_telem>(tw37806_s, Two, True);
  tw37806_turnsetelem<tw37806_tset, tw37806_telem>(tw37806_s, Five, True);
  if not((Two in tw37806_s) and (Five in tw37806_s)) then
    Halt(1);
    //WriteLn('does not work');
  end;
  {$pop}

  { Case tw38497.pp }
  {$push}

  begin
tw38497_test<tw38497_talphabet, tw38497_talphabets>(A, [A, B]);
  end;
  {$pop}

  { Case tw8172.pp }
  {$push}
{$IFDEF FPC}
{$packenum 1}
{$packset 1}
{$ENDIF}
  begin
if SizeOf(tw8172_tnxmessageheaderflag)<>1 then
    halt(1);
  WriteLn(SizeOf(tw8172_tnxmessageheaderflag)); // should be 1, is 1
  WriteLn(SizeOf(tw8172_tnxmessageheaderflags)); // should be 1, is 4
  if SizeOf(tw8172_tnxmessageheaderflags)<>1 then
    halt(1);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_generics_delphi_run_01.pp }
  {$push}


begin
  { Case tw21592.pp }
  {$push}

  begin
if sizeof(tw21592_a)<>1 then
    halt(1);
  writeln('ok');
  end;
  {$pop}

  { Case tw37107.pp }
  {$push}
{$IFDEF FPC}
{$ENDIF}
  begin
tw37107_ttest<Char>.Create().tw37107_testit();
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_generics_delphi_run_02.pp }
  {$push}


begin

end;
  {$pop}

  { Source group: tb_ordinal_operations_delphi_run_01.pp }
  {$push}


begin
  { Case tb0602.pp }
  {$push}
{$R-}
begin
  tb0602_test;
end;
  {$pop}

  { Case tb0615.pp }
  {$push}
begin
  if sizeof(tb0615_s)<>1 then
    halt(1);
  writeln('ok');
end;
  {$pop}

  { Case tb0689.pp }
  {$push}
begin
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_pointer_casts_delphi_run_01.pp }
  {$push}


begin
  { Case tb0400.pp }
  {$push}
begin
   tb0400_p:=pointer(tb0400_b);
   tb0400_p:=pointer(tb0400_i);
   tb0400_p:=pointer(tb0400_i64);
   tb0400_p:=pointer(tb0400_q);
end;
  {$pop}

  { Case tb0423.pp }
  {$push}
begin
   tb0423_tmethod(tb0423_p).data:=nil;
end;
  {$pop}

  { Case tb0443.pp }
  {$push}
begin
   tb0443_p:=pointer(tb0443_b);
   tb0443_p:=pointer(tb0443_i);
   tb0443_p:=pointer(tb0443_i64);
   tb0443_p:=pointer(tb0443_q);
end;
  {$pop}

  { Case tb0465.pp }
  {$push}
begin
  tb0465_x:=0;
  tb0465_x:=pointer(0);
end;
  {$pop}

  { Case tb0539.pp }
  {$push}
{$R+}
begin
  tb0539_o2:=tb0539_o;
end;
  {$pop}

  { Case tb0554.pp }
  {$push}
begin
  tb0554_o := TObject(tb0554_e);
  tb0554_o := TObject(tb0554_i);
  tb0554_i := Word(tb0554_o);
  tb0554_e := tb0554_tenum(tb0554_o);
end;
  {$pop}

  { Case tb0594.pp }
  {$push}
begin
  tb0594_p:=tb0594_tp(tb0594_tc.tb0594_test);
  tb0594_p2:=tb0594_tc.tb0594_test;
  if codepointer(@tb0594_p)<>tmethod(tb0594_p2).code then
    halt(1);
end;
  {$pop}


end;
  {$pop}

end.
