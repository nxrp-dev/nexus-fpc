{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode delphi}


{ Source group: tb_classes_delphi_run_01.pp }
{$push}

{ Case tb0226.pp }
{$push}
{ Old file: tbs0264.pp }
{ methodpointer bugs                                   OK 0.99.12b (FK) }



type
    tb0226_a = class
        tb0226_c : procedure of object;

        constructor create; virtual;
        destructor destroy; override;

        procedure tb0226_e; virtual;
        procedure tb0226_f; virtual;
    end;

constructor tb0226_a.create;
begin
    tb0226_c := tb0226_e;
end;

destructor tb0226_a.destroy;
begin
end;

procedure tb0226_a.tb0226_e;
begin
    Writeln('E');
    tb0226_c := tb0226_f;
end;

procedure tb0226_a.tb0226_f;
begin
    Writeln('F');
    tb0226_c := tb0226_e;
end;

var
    tb0226_z : tb0226_a;
{$pop}

{ Case tb0273.pp }
{$push}
{ Old file: tbs0319.pp }
{  }

{$ifdef fpc}{$endif}

function tb0273_a:longint;
var
  tb0273_a : longint;
begin
  tb0273_a:=1;
end;

type
  tb0273_cl=class
    tb0273_k : longint;
    procedure tb0273_p1;
    procedure tb0273_p2;
  end;

 tb0273_o = class
       tb0273_nonsense  :string;
       procedure tb0273_flup(tb0273_nonsense:string);
     end;

 tb0273_o2 = class
       tb0273_nonsense  :string;
       procedure tb0273_flop;
       procedure tb0273_flup(tb0273_nonsense:longint);
       procedure tb0273_flup2(tb0273_flop:longint);
     end;

procedure tb0273_o.tb0273_flup(tb0273_nonsense:string);
begin
end;

procedure tb0273_o2.tb0273_flop;
begin
end;

procedure tb0273_o2.tb0273_flup(tb0273_nonsense:longint);
var
  tb0273_l : longint;
begin
  tb0273_l:=tb0273_nonsense;
end;

procedure tb0273_o2.tb0273_flup2(tb0273_flop:longint);
var
  tb0273_l : longint;
begin
  tb0273_l:=tb0273_flop;
  tb0273_flup(tb0273_flop);
end;

procedure tb0273_cl.tb0273_p1;
var
  tb0273_k : longint;
begin
end;

procedure tb0273_cl.tb0273_p2;
var
  tb0273_p1 : longint;
begin
end;
{$pop}

{ Case tb0374.pp }
{$push}

type
   tb0374_tc1 = class
      procedure tb0374_a;overload;virtual;
   end;

   tb0374_tc2 = class(tb0374_tc1)
      procedure tb0374_a;override;
   end;

procedure tb0374_tc1.tb0374_a;

  begin
  end;

procedure tb0374_tc2.tb0374_a;

  begin
  end;
{$pop}

{ Case tb0407.pp }
{$push}
{$ifdef fpc}{$endif}

var
  tb0407_err : boolean;

type
  tb0407_tc1=class(tinterfacedobject)
    constructor Create;overload;
    constructor Create(s:string);overload;
  end;

  tb0407_tc2=class(tb0407_tc1)
    constructor Create(l1,l2:longint);overload;
  end;

constructor tb0407_tc1.create;
begin
  tb0407_err:=true;
end;

constructor tb0407_tc1.create(s:string);
begin
  tb0407_err:=true;
end;

constructor tb0407_tc2.create(l1,l2:longint);
begin
  { The next line should do nothing }
  inherited;
end;

var
  tb0407_c : tb0407_tc2;
{$pop}

{ Case tb0422.pp }
{$push}
{$ifdef fpc}{$endif}

type
  tb0422_tcl = class
    function tb0422_f1 : tvarrec; virtual;
  end;

var
   tb0422_f : function : tvarrec of object;

function tb0422_tcl.tb0422_f1 : tvarrec;
begin
  fillchar(result,sizeof(result),0);
end;

procedure tb0422_p1(v : tvarrec);
  begin
  end;

var
  tb0422_c : tb0422_tcl;
{$pop}

{ Case tb0479.pp }
{$push}


var
  tb0479_err : boolean;

Type
  {copy-paste from LibX.pas}
  tb0479_xint                           = Longint;
  tb0479_xuint                          = Longword;
  tb0479_xhandle                        = Pointer;
  tb0479_xfile                          = tb0479_xhandle;
  tb0479_xfilemode                      = Set Of (
    xFileModeRead,
    xFileModeWrite
  );
  tb0479_xresult                        = tb0479_xint;

Type
  tb0479_ttest = Class(TObject)
    Constructor Create(Out Result: tb0479_xresult; Const tb0479_handle: tb0479_xfile; Const tb0479_mode: tb0479_xfilemode);
  End;

  tb0479_ttest2 = Class(tb0479_ttest)
    Constructor Create(Out Result: tb0479_xresult; Const tb0479_filename: AnsiString; Const tb0479_rights: tb0479_xuint); Overload;
    Constructor Create(Out Result: tb0479_xresult; Const tb0479_filename: AnsiString; Const tb0479_mode: tb0479_xfilemode); Overload;
  End;

Constructor tb0479_ttest.Create(Out Result: tb0479_xresult; Const tb0479_handle: tb0479_xfile; Const tb0479_mode: tb0479_xfilemode);
Begin
  WriteLn('TTest Create');
End;

Constructor tb0479_ttest2.Create(Out Result: tb0479_xresult; Const tb0479_filename: AnsiString; Const tb0479_rights: tb0479_xuint);
Begin
  WriteLn('TTest2-1 Create');
End;

Constructor tb0479_ttest2.Create(Out Result: tb0479_xresult; Const tb0479_filename: AnsiString; Const tb0479_mode: tb0479_xfilemode);
Begin
  WriteLn('TTest2-2 Create');
  tb0479_err:=false;
End;

Var
  tb0479_t : tb0479_ttest;
  tb0479_c : PAnsiChar;
  tb0479_x : tb0479_xresult;
  tb0479_m : tb0479_xfilemode;
{$pop}

{ Case tb0496.pp }
{$push}

type
  tb0496_tmyclass = class
    procedure tb0496_m1;virtual;
    procedure tb0496_m2;virtual;
  end;

  tb0496_tm1 = procedure of object;

var
  tb0496_res : longint;

procedure tb0496_tmyclass.tb0496_m1;
  begin
    tb0496_res:=1;
  end;

procedure tb0496_p2(tb0496_m1 : tb0496_tm1);
  begin
    tb0496_m1;
  end;

procedure tb0496_tmyclass.tb0496_m2;
  begin
    tb0496_p2(tb0496_m1);
  end;

var
  tb0496_myclass : tb0496_tmyclass;
{$pop}

{ Case tb0577a.pp }
{$push}


const
  tb0577a_cdefaulthandler = 1;
  tb0577a_cinheritedhandler = 2;
  tb0577a_cunsupportedhandler = 3;

type
  tb0577a_tc = class
    procedure defaulthandler(var message); override;
    procedure tb0577a_handler(var message:longint); message tb0577a_cinheritedhandler;
  end;

  tb0577a_tc2 = class(tb0577a_tc)
    procedure tb0577a_handler(var message: longint);
  end;

  tb0577a_tc3 = class(tb0577a_tc2)
    procedure tb0577a_someproc(var message:tb0577a_tc3); message tb0577a_cinheritedhandler;
    procedure tb0577a_handler(var message:tb0577a_tc3); message tb0577a_cunsupportedhandler;
  end;

var
  tb0577a_glob: longint;

procedure tb0577a_tc.defaulthandler(var message);
begin
  tb0577a_glob:=tb0577a_cdefaulthandler;
end;

procedure tb0577a_tc.tb0577a_handler(var message: longint);
begin
  tb0577a_glob:=tb0577a_cinheritedhandler;
end;

procedure tb0577a_tc2.tb0577a_handler(var message: longint);
begin
  halt(1);
end;

procedure tb0577a_tc3.tb0577a_someproc(var message: tb0577a_tc3);
begin
  inherited;
end;

procedure tb0577a_tc3.tb0577a_handler(var message: tb0577a_tc3);
begin
  tb0577a_glob:=tb0577a_cunsupportedhandler;
  inherited
end;

var
  tb0577a_c: tb0577a_tc3;
{$pop}

{ Case tw11861.pp }
{$push}
{$ifdef fpc}

{$endif}

type

  { TMyObj }

  tw11861_tmyobj = class
    procedure tw11861_proc(A1 : TObject; tw11861_a2: Integer);
  end;

type
   tw11861_tproc = procedure(AObject : TObject; tw11861_a2: Integer) of object;

var tw11861_x: tw11861_tmyobj;
    tw11861_p1: tw11861_tproc;

procedure tw11861_foo(const AMethod1);
begin
  if pointer(AMethod1) <> pointer(@tw11861_p1) then
    halt(1);
end;

{ TMyObj }

procedure tw11861_tmyobj.tw11861_proc(A1 : TObject; tw11861_a2: Integer);
begin
end;
{$pop}

{ Case tw11896.pp }
{$push}


type
  tw11896_ttest = class(TObject)
    tw11896_a: array[0..32767] of Integer;
    procedure tw11896_x;
    procedure tw11896_y;
    procedure beforedestruction;override;
  end;

var
  tw11896_testobj: tw11896_ttest;
  tw11896_destroyed: boolean;

procedure tw11896_ttest.beforedestruction;
begin
  tw11896_destroyed:=true;
  inherited beforedestruction;
end;

procedure tw11896_ttest.tw11896_x;
begin
  Destroy;
end;

procedure tw11896_ttest.tw11896_y;
begin
  Self.Destroy;
end;

function tw11896_getusedmemory: Integer;
begin
  Result := GetHeapStatus.TotalAllocated;
end;
{$pop}

{ Case tw15391.pp }
{$push}
{$ifdef fpc}

{$endif}

type
  tw15391_funca = function : Integer of object;
  tw15391_obja = class
    function tw15391_func1: Integer;
    procedure tw15391_proc1(const Arr: Array of tw15391_funca);
  end;

var tw15391_a : tw15391_obja;

procedure tw15391_test(fa: tw15391_funca);
begin
  if fa<>tw15391_a.tw15391_func1 then
    halt(2);
end;

function tw15391_obja.tw15391_func1: Integer;
begin
  Result := 1;
end;

procedure tw15391_obja.tw15391_proc1(const Arr: Array of tw15391_funca);
begin
  if (low(arr)<>0) or
     (high(arr)<>1) or
     assigned(arr[0]) or
     (arr[1]<>tw15391_a.tw15391_func1) then
    halt(1);
end;
{$pop}

{ Case tw15415.pp }
{$push}


type
 tw15415_tmyclass = class
   tw15415_i, tw15415_i2 :LongInt;
 end;
{$pop}


{$pop}

{ Source group: tb_classes_delphi_run_02.pp }
{$push}

{ Case tw18620.pp }
{$push}


{ in delphi mode ^T in the var block of class/record/object should not create
  a forward definition which must be resolved after the type section end      }

type
  tw18620_c = class
    type
      tw18620_t = integer;
    var
      tw18620_v: ^tw18620_t;
  end;
{$pop}

{ Case tw1923.pp }
{$push}
{$ifdef fpc}{$endif}

type
tw1923_parent = class
end;

tw1923_child = class
 procedure tw1923_test;
end;

procedure tw1923_child.tw1923_test;
begin
inherited;
end;

var
  tw1923_o : tw1923_child;
{$pop}

{ Case tw2378.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2378 }
{ Submitted by "Yakov Sudeikin" on  2003-02-13 }
{ e-mail: yashka@exebook.com }



type
 tw2378_tfunc = procedure of object;

 tw2378_ttest = class
   procedure tw2378_callback;
   procedure tw2378_start;
   procedure tw2378_call(ptr: tw2378_tfunc);
 end;

procedure tw2378_ttest.tw2378_callback;
begin
end;

procedure tw2378_ttest.tw2378_call;
begin
end;

procedure tw2378_ttest.tw2378_start;
begin
 tw2378_call(tw2378_callback);
end;
{$pop}

{ Case tw2483.pp }
{$push}
{$ifdef fpc}{$endif}

type
  tw2483_tupdateproc = procedure( Self : TObject; tw2483_n : Integer ) of object;

  tw2483_tcl = class
     tw2483_fonupdate : tw2483_tupdateproc;
     procedure tw2483_handleupdate(obj:tobject;tw2483_n:integer);
     procedure tw2483_p;
   end;

procedure tw2483_tcl.tw2483_handleupdate(obj:tobject;tw2483_n:integer);
begin
  writeln(tw2483_n);
end;

procedure tw2483_tcl.tw2483_p;
begin
  tw2483_fonupdate := tw2483_handleupdate;
  tw2483_fonupdate( Self, 1 );
end;

var
  tw2483_c  : tw2483_tcl;
{$pop}

{ Case tw24844c.pp }
{$push}
{.$mode objfpc}


Type

 { TObj }

 tw24844c_tobj = Class
  class var
   tw24844c_a: record
    tw24844c_b: byte;
   end;
   procedure tw24844c_test;
 end;

{ TObj }

procedure tw24844c_tobj.tw24844c_test;
Var

 tw24844c_proc : procedure of object;
 tw24844c_p : pbyte;
begin
  tw24844c_a.tw24844c_b:=5;
  tw24844c_p:=@tw24844c_tobj.create.tw24844c_a.tw24844c_b;
  if tw24844c_p^<>5 then
    halt(1);
end;

procedure tw24844c_uncompilableproc;
Var

 tw24844c_proc : procedure of object;
 tw24844c_p : pbyte;
begin
  tw24844c_tobj.tw24844c_a.tw24844c_b:=6;
  tw24844c_p:=@tw24844c_tobj.create.tw24844c_a.tw24844c_b;
  if tw24844c_p^<>6 then
    halt(2);
end;
{$pop}

{ Case tw2503.pp }
{$push}


type
 tw2503_thyperpupertext = class
    Procedure tw2503_hyper; OVERLOAD;
    Procedure tw2503_hyper(n: integer); OVERLOAD;
  end;

Procedure tw2503_thyperpupertext.tw2503_hyper(n: integer);
begin
end;

Procedure tw2503_thyperpupertext.tw2503_hyper;
begin
end;
{$pop}

{ Case tw2669.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2669 }
{ Submitted by "marco" on  2003-09-06 }
{ e-mail: marco+web@freepascal.org }


Type
   tw2669_tpop3nextproc = procedure of object;
   tw2669_t1= class
            procedure tw2669_server; virtual;
            procedure tw2669_run; virtual;
            procedure tw2669_connect; virtual;
   end;

   tw2669_t2=class
         tw2669_f1 : tw2669_t1;
         procedure tw2669_exec(p:tw2669_tpop3nextproc);
         procedure tw2669_callexec;
         constructor create;
         end;

procedure tw2669_t1.tw2669_server;

begin
 writeln('server');
end;

procedure tw2669_t1.tw2669_run;

begin
 writeln('run');
end;

procedure tw2669_t1.tw2669_connect;

begin
 writeln('connect');
end;

constructor tw2669_t2.create;

begin
  inherited create;
  tw2669_f1:=tw2669_t1.create;
end;

procedure tw2669_t2.tw2669_exec(p:tw2669_tpop3nextproc);

begin
 writeln('in exec');
 p;
end;

procedure tw2669_t2.tw2669_callexec;

begin
 writeln('callexec');
 tw2669_exec(tw2669_f1.tw2669_server);
 tw2669_exec(tw2669_f1.tw2669_run);
 tw2669_exec(tw2669_f1.tw2669_connect);
end;

var tw2669_c1 : tw2669_t2;
{$pop}

{ Case tw2704.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2704 }
{ Submitted by "Johannes Berg" on  2003-10-01 }
{ e-mail: johannes -at- sipsolutions -dot- de }



type
  tw2704_ttest = class
    constructor Create; virtual; abstract;
  end;
{$pop}

{ Case tw2708.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2708 }
{ Submitted by "Johannes Berg" on  2003-10-02 }
{ e-mail: johannes -at- sipsolutions -dot- de }


type
  tw2708_ta = class
    procedure tw2708_a; overload; virtual; abstract;
    procedure tw2708_a(const s:string); overload;
  end;

procedure tw2708_ta.tw2708_a(const s:string);
begin
end;
{$pop}

{ Case tw2728.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2728 }
{ Submitted by "marco (the gory bugs department)" on  2003-10-09 }
{ e-mail:  }

type tw2728_baseclass = class end;
     tw2728_tbaseclass= class of tw2728_baseclass;

function tw2728_test (c : tw2728_tbaseclass):longint;

var tw2728_o :tobject;

begin
  tw2728_o:=tobject(c);   // illegal type conversion here
end;
{$pop}

{ Case tw2729.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2729 }
{ Submitted by "marco (the gory bugs department)" on  2003-10-09 }
{ e-mail:  }


type
  tw2729_tbla= class(tobject)
    tw2729_l : longint;
    class function tw2729_bla:tw2729_tbla;
    function tw2729_get : longint;virtual;
    procedure tw2729_doset;
 end;

procedure tw2729_tbla.tw2729_doset;
  begin
     tw2729_l:=$12345678;
  end;

function tw2729_tbla.tw2729_get : longint;
  begin
    result:=tw2729_l;
  end;

class function tw2729_tbla.tw2729_bla:tw2729_tbla;

  begin
    result:=Create;
  end;

var
  tw2729_bla : tw2729_tbla;
{$pop}

{ Case tw3038.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3038 }
{ Submitted by "Marco (Gory Bugs Department)" on  2004-04-03 }
{ e-mail:  }


type tw3038_dasso     = class
                 procedure tw3038_bla; virtual; abstract;
                end;
    dmyasso    = class(tw3038_dasso)
                  procedure tw3038_bla; override;
                end;
    dnextasso = class(dmyasso)
                   procedure tw3038_bla; override;
                end;
    tw3038_classfamily= class of tw3038_dasso;

procedure dmyasso.tw3038_bla;
begin
end;

procedure dnextasso.tw3038_bla;
begin
end;

const tw3038_cmyclass : array[0..1] of tw3038_classfamily =(dmyasso,dnextasso);

var tw3038_vmyclass : array[0..1] of tw3038_classfamily =(dmyasso,dnextasso);
{$pop}


{$pop}

{ Source group: tb_classes_delphi_run_04.pp }
{$push}

{ Case tb0595.pp }
{$push}
{$h+}

type
  tb0595_tc = class
    class procedure tb0595_test; static;
  end;

  tb0595_tp = procedure;

var
  tb0595_global: longint;

  class procedure tb0595_tc.tb0595_test;
    begin
      tb0595_global:=1;
    end;

var
  tb0595_p: tb0595_tp;
{$pop}

{ Case tw2220.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2220 }
{ Submitted by "marco" on  2002-11-06 }
{ e-mail: marcov@freepascal.org }
{$H+}
{$ifdef fpc}{$endif}
// NO OUTPUT, GDB SHOWS SIGSEGV IN DECR_REF

type tw2220_bla=class
        tw2220_freceivebuffer : array[0..4095] of char;
        tw2220_flastresponse  : String;
        procedure tw2220_themethod;
        end;

procedure tw2220_bla.tw2220_themethod;
        var tw2220_i : longint;
        begin
         tw2220_i:=12;
         tw2220_flastresponse:=copy(tw2220_freceivebuffer,1,tw2220_i-1);
         writeln('point 1: ',tw2220_flastresponse);
        end;

var tw2220_x : tw2220_bla;
{$pop}


{$pop}

{ Source group: tb_class_properties_delphi_run_01.pp }
{$push}

{ Case tb0346.pp }
{$push}
type
tb0346_aclass=class
 private
  tb0346_aa:longint;
  procedure tb0346_bb(index:integer;tb0346_value:longint);
 public
  property tb0346_cc:longint index 1 read tb0346_aa write tb0346_bb;
end;
procedure tb0346_aclass.tb0346_bb(index:integer;tb0346_value:longint);
 begin
  tb0346_aa:=tb0346_value;
 end;
var
 tb0346_c:tb0346_aclass;
{$pop}

{ Case tb0475.pp }
{$push}
type
  tb0475_to1 = class
     tb0475_fp : longint;
     property tb0475_p : longint read tb0475_fp write tb0475_fp;
  end;

procedure tb0475_p(const tb0475_v);
  begin
  end;

var
  tb0475_a : pchar;
  tb0475_o1 : tb0475_to1;
{$pop}


{$pop}

begin
  { Source group: tb_classes_delphi_run_01.pp }
  {$push}


begin
  { Case tb0226.pp }
  {$push}

  begin
tb0226_z := tb0226_a.create;
    tb0226_z.tb0226_c;
    tb0226_z.tb0226_c;
    tb0226_z.tb0226_c;
    tb0226_z.free;
  end;
  {$pop}

  { Case tb0407.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tb0407_err:=false;
  tb0407_c:=tb0407_tc2.create(1,1);
  tb0407_c.free;
  if tb0407_err then
   begin
     writeln('Error!');
     halt(1);
   end;
  end;
  {$pop}

  { Case tb0422.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tb0422_c:=tb0422_tcl.create;
   tb0422_f:=tb0422_c.tb0422_f1;
   tb0422_p1(tb0422_f);
  end;
  {$pop}

  { Case tb0479.pp }
  {$push}

  begin
tb0479_err:=true;
  tb0479_c := 'Foo';
  tb0479_t := tb0479_ttest2.Create(tb0479_x, tb0479_c, tb0479_m);
  if tb0479_err then
    halt(1);
  end;
  {$pop}

  { Case tb0496.pp }
  {$push}

  begin
tb0496_res:=longint($deadbeef);
  tb0496_myclass:=tb0496_tmyclass.create;
  tb0496_myclass.tb0496_m2;
  tb0496_myclass.free;
  if tb0496_res<>1 then
    halt(1);
  writeln('ok');
  end;
  {$pop}

  { Case tb0577a.pp }
  {$push}

  begin
tb0577a_c:=tb0577a_tc3.create;
  tb0577a_c.tb0577a_someproc(tb0577a_c);
  if tb0577a_glob<>tb0577a_cinheritedhandler then
    halt(2);
  tb0577a_c.tb0577a_handler(tb0577a_c);
  if tb0577a_glob<>tb0577a_cdefaulthandler then
    halt(3);
  end;
  {$pop}

  { Case tw11861.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw11861_x := tw11861_tmyobj.Create;
  tw11861_p1 := tw11861_x.tw11861_proc;
  tw11861_foo(tw11861_p1);
  end;
  {$pop}

  { Case tw11896.pp }
  {$push}

  begin
tw11896_testobj := tw11896_ttest.create;
  tw11896_destroyed:=false;
  tw11896_testobj.tw11896_x;
  if not tw11896_destroyed then
    halt(1);

  tw11896_destroyed:=false;
  tw11896_testobj := tw11896_ttest.create;
  tw11896_testobj.tw11896_y;
  if not tw11896_destroyed then
    halt(2);
  end;
  {$pop}

  { Case tw15391.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw15391_a := tw15391_obja.Create;
  tw15391_a.tw15391_proc1([nil,tw15391_a.tw15391_func1]);
  tw15391_test(tw15391_a.tw15391_func1);
  tw15391_a.free;
  end;
  {$pop}

  { Case tw15415.pp }
  {$push}

  begin
if ptruint(@tw15415_tmyclass(pointer(5)).tw15415_i2)<>(5+sizeof(pointer){$IFDEF FPC_HAS_FEATURE_MONITOR}*2{$ENDIF FPC_HAS_FEATURE_MONITOR}+4) then
   halt(1);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_classes_delphi_run_02.pp }
  {$push}


begin
  { Case tw1923.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw1923_o:=tw1923_child.create;
  tw1923_o.tw1923_test;
  tw1923_o.free;
  end;
  {$pop}

  { Case tw2483.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw2483_c:=tw2483_tcl.create;
  tw2483_c.tw2483_p;
  end;
  {$pop}

  { Case tw24844c.pp }
  {$push}

  begin
WriteLn('Mode: ', {$IFDEF FPC_DELPHI}'delphi'{$ELSE}'objfpc'{$ENDIF});

  tw24844c_tobj.Create.tw24844c_test;
  tw24844c_uncompilableproc;
  end;
  {$pop}

  { Case tw2669.pp }
  {$push}

  begin
writeln('start');
  tw2669_c1:=tw2669_t2.create;
  writeln('after create');
  tw2669_c1.tw2669_callexec;
  writeln('end');
  end;
  {$pop}

  { Case tw2729.pp }
  {$push}

  begin
tw2729_bla:=tw2729_tbla.tw2729_bla;
  tw2729_bla.tw2729_doset;
  if tw2729_bla.tw2729_get<>$12345678 then
    begin
      writeln('Problem');
      halt(1);
    end;
  tw2729_bla.free;
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_classes_delphi_run_04.pp }
  {$push}


begin
  { Case tb0595.pp }
  {$push}

  begin
tb0595_p:=tb0595_tp(tb0595_tc.tb0595_test);
  tb0595_p();
  if tb0595_global<>1 then
    halt(1);
  end;
  {$pop}

  { Case tw2220.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw2220_x:=tw2220_bla.create;
  tw2220_x.tw2220_freceivebuffer:='test string is wrong!';
  tw2220_x.tw2220_themethod;
  writeln('point 2');
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_class_properties_delphi_run_01.pp }
  {$push}


begin
  { Case tb0346.pp }
  {$push}
begin
 tb0346_c:=tb0346_aclass.Create;
 tb0346_c.tb0346_cc:=1;
 writeln(tb0346_c.tb0346_cc);
end;
  {$pop}

  { Case tb0475.pp }
  {$push}
begin
  tb0475_o1:=tb0475_to1.create;
  tb0475_p(tb0475_a[0]);
  tb0475_p(tb0475_o1.tb0475_p);
  tb0475_o1.free;
end;
  {$pop}


end;
  {$pop}

end.
