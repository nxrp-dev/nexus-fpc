{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb_class_methods_objfpc.pp }
{$push}
{ Class method declarations: virtual, abstract, stdcall and strict visibility. }

{ tb0166.pp }
{ calling specifications aren't allowed in class declarations, this should be allowed                                OK 0.99.11  (PM) }


type
   tb_class_methods_objfpc_to1 = class
       function GetCaps1 : Longint;virtual;abstract;
       function GetCaps2 : Longint;virtual;stdcall;
       function GetCaps : Longint;virtual;stdcall;abstract;
   end;

function tb_class_methods_objfpc_to1.GetCaps2 : Longint;stdcall;
begin
end;

{ tb0303.pp }


type
   tb_class_methods_objfpc_tclass1 = class
      procedure a;virtual;
      procedure b;virtual;
   end;

   tb_class_methods_objfpc_tclass2 = class(tb_class_methods_objfpc_tclass1)
      procedure a;override;
      procedure b;override;
      procedure c;virtual;
   end;

  procedure tb_class_methods_objfpc_tclass1.a;

    begin
    end;

  procedure tb_class_methods_objfpc_tclass1.b;

    begin
    end;

  procedure tb_class_methods_objfpc_tclass2.a;

    begin
    end;

  procedure tb_class_methods_objfpc_tclass2.b;

    begin
    end;

  procedure tb_class_methods_objfpc_tclass2.c;

    begin
    end;

{ tb0493.pp }


type
  tb_class_methods_objfpc_tobject1 = class
  strict protected
    spro : integer;
  strict private
    spriv : integer;
  public
    procedure p1;
  end;

  tb_class_methods_objfpc_tobject2 = class(tb_class_methods_objfpc_tobject1)
    procedure p2;
  end;

procedure tb_class_methods_objfpc_tobject1.p1;
  begin
    spro:=1;
    spriv:=2;
  end;

procedure tb_class_methods_objfpc_tobject2.p2;
  begin
    spro:=3;
  end;

var
  tb_class_methods_objfpc_o1 : tb_class_methods_objfpc_tobject1;
  tb_class_methods_objfpc_o2 : tb_class_methods_objfpc_tobject2;


{$pop}

{ Case tw24844.pp }
{$push}



{.$mode delphi}

Type

 { TObj }

 tw24844_TObj = Class
   procedure Test;
 end;

{ TObj }

procedure tw24844_TObj.Test;
Var

 proc : procedure of object;

begin

  proc := {$IFNDEF FPC_DELPHI}@{$ENDIF}TObject.Create.Free;
  WriteLn('Expected TObject actual: ', TObject(TMethod(Proc).Data).ClassName);
  if TObject(TMethod(Proc).Data).ClassName<>'TObject' then
    halt(1);
end;

procedure tw24844_UncompilableProc;
Var

 proc : procedure of object;

begin

  proc := {$IFNDEF FPC_DELPHI}@{$ENDIF}TObject.Create.Free; // uncompilable in FPC mode
  WriteLn('Expected TObject actual: ', TObject(TMethod(Proc).Data).ClassName);
  if TObject(TMethod(Proc).Data).ClassName<>'TObject' then
    halt(2);
end;


{$pop}

{ Case tb0189.pp }
{$push}


type
  tb0189_c = class(TObject)
    type
      a = longint;
  end;


{$pop}

{ Case tcse4.pp }
{$push}

type
  tcse4_tr = record
    data1 : longint;
    data2 : longint;
  end;

  tcse4_tc = class
    r : ^tcse4_tr;
    function f : longint;
  end;

function tcse4_tc.f : longint;
  begin
    result:=r^.data1+r^.data2*r^.data1;
    r^.data1:=r^.data2*r^.data1;

    if assigned(r) and (r^.data1=r^.data2) then
      writeln(':)');
  end;


{$pop}

{ Case tpredsucc1.pp }
{$push}


type
  tpredsucc1_tmyclass = class
    i : integer;
    function GetI : Integer;
    procedure SetI(const _i : Integer);
    property i1 : integer read GetI write SetI;
    property i2 : integer read i write i;
  end;


function tpredsucc1_tmyclass.GetI : Integer;
  begin
    Result:=i;
  end;

procedure tpredsucc1_tmyclass.SetI(const _i : Integer);
  begin
    i:=_i;
  end;

var
  tpredsucc1_myclass : tpredsucc1_tmyclass;


{$pop}

begin

{ Case tb_class_methods_objfpc.pp }
{$push}



begin
  { tb0493.pp }
  tb_class_methods_objfpc_o1:=tb_class_methods_objfpc_tobject1.create;
  tb_class_methods_objfpc_o2:=tb_class_methods_objfpc_tobject2.create;
  tb_class_methods_objfpc_o1.free;
  tb_class_methods_objfpc_o2.free;
end;
{$pop}

{ Case tw24844.pp }
{$push}

{$IFNDEF FPC_DELPHI}
{$ENDIF}
{$IFNDEF FPC_DELPHI}
{$ENDIF}
begin

  WriteLn('Mode: ', {$IFDEF FPC_DELPHI}'delphi'{$ELSE}'objfpc'{$ENDIF});

  tw24844_TObj.Create.Test;
  tw24844_UncompilableProc;

end;
{$pop}

{ Case tb0189.pp }
{$push}

begin
end;
{$pop}

{ Case tcse4.pp }
{$push}

begin
end;
{$pop}

{ Case tpredsucc1.pp }
{$push}

begin
  tpredsucc1_myclass:=tpredsucc1_tmyclass.create;
  tpredsucc1_myclass.i1:=1;

  tpredsucc1_myclass.i1:=pred(tpredsucc1_myclass.i1);
  tpredsucc1_myclass.i1:=succ(tpredsucc1_myclass.i1);

  tpredsucc1_myclass.i2:=pred(tpredsucc1_myclass.i2);
  tpredsucc1_myclass.i2:=succ(tpredsucc1_myclass.i2);

  if tpredsucc1_myclass.i<>1 then
    halt(1);

  tpredsucc1_myclass.free;

  writeln('ok');
end;
{$pop}

end.
