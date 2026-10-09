{ Classes regression cases; original case IDs are retained below. }

{ Case tb0226.pp }
{$push}
{ Old file: tbs0264.pp }
{ methodpointer bugs                                   OK 0.99.12b (FK) }

{$MODE DELPHI}

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

{$ifdef fpc}{$mode delphi}{$endif}

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
{$mode delphi}
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
{$ifdef fpc}{$mode delphi}{$endif}

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
{$ifdef fpc}{$mode delphi}{$endif}

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
{$mode delphi}

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
{$mode delphi}
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
{$mode delphi}

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
{$mode delphi}
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
{$mode delphi}

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
{$mode delphi}
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
{$mode delphi}

type
 tw15415_tmyclass = class
   tw15415_i, tw15415_i2 :LongInt;
 end;
{$pop}

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

end.
