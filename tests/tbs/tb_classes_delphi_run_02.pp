{ Classes regression cases; original case IDs are retained below. }

{ Case tw18620.pp }
{$push}
{$mode Delphi}

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
{$ifdef fpc}{$mode delphi}{$endif}

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

{$mode delphi}

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
{$ifdef fpc}{$mode delphi}{$endif}

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
{$mode delphi}

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
{$mode delphi}

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

{$mode Delphi}
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

{$mode delphi}

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

{$mode delphi}
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
{$mode delphi}
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
{$mode delphi}

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
{$mode delphi}

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

end.
