{ Classes regression cases; original case IDs are retained below. }

{ Case tw2481.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2481 }
{ Submitted by "Eero Tanskanen" on  2003-05-04 }
{ e-mail: yendor@nic.fi }

{$mode objfpc}

Type
  tw2481_tmoo = Class

    tw2481_a : Real;
    Constructor tw2481_init;

  End;

Var
  tw2481_moo : tw2481_tmoo;

  Operator := (V : Real) B : tw2481_tmoo;
  Begin
    B:=tw2481_tmoo.Create;
    B.tw2481_a := V;
  End;

{$ifdef FPC_HAS_TYPE_EXTENDED}
{ otherwise extended = real = double }
  Operator := (V : Extended) B : tw2481_tmoo;
  Begin
    B:=tw2481_tmoo.Create;
    B.tw2481_a := V;
  End;
{$endif FPC_HAS_TYPE_EXTENDED}

Constructor tw2481_tmoo.tw2481_init;
Begin

  tw2481_a := 0;

End;
{$pop}

{ Case tw24844b.pp }
{$push}
{$mode objfpc}
{.$mode delphi}

Type

 { TObj }

 tw24844b_tobj = Class
  class var
   tw24844b_a: record
    tw24844b_b: byte;
   end;
   procedure tw24844b_test;
 end;

{ TObj }

procedure tw24844b_tobj.tw24844b_test;
Var

 tw24844b_proc : procedure of object;
 tw24844b_p : pbyte;
begin
  tw24844b_a.tw24844b_b:=5;
  tw24844b_p:=@tw24844b_tobj.create.tw24844b_a.tw24844b_b;
  if tw24844b_p^<>5 then
    halt(1);
end;

procedure tw24844b_uncompilableproc;
Var

 tw24844b_proc : procedure of object;
 tw24844b_p : pbyte;
begin
  tw24844b_tobj.tw24844b_a.tw24844b_b:=6;
  tw24844b_p:=@tw24844b_tobj.create.tw24844b_a.tw24844b_b;
  if tw24844b_p^<>6 then
    halt(2);
end;
{$pop}

{ Case tw2627.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2627 }
{ Submitted by "Sergey Kosarevsky" on  2003-08-10 }
{ e-mail: netsurfer@au.ru }

{$mode objfpc}

Type tw2627_tmyclass=Class
        Procedure tw2627_dosomething;Virtual;Abstract;
        Class Procedure tw2627_process(C:tw2627_tmyclass);
     End;

Class Procedure tw2627_tmyclass.tw2627_process(C:tw2627_tmyclass);
Begin
   With C Do tw2627_dosomething;
End;
{$pop}

{ Case tw2645.pp }
{$push}
{$mode objfpc}
{$inline on}

type
  tw2645_c = class
    tw2645_l : longint;
    procedure tw2645_p;inline;
    procedure tw2645_p2;
  end;

    procedure tw2645_c.tw2645_p;inline;
    begin
      writeln(tw2645_l);
      inc(tw2645_l,10);
    end;

    procedure tw2645_c.tw2645_p2;
    begin
      tw2645_l:=10;
      tw2645_p;
      if tw2645_l<>20 then
        halt(1);
    end;

var
  tw2645_o : tw2645_c;
{$pop}

{ Case tw2651.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2651 }
{ Submitted by "Sergey Kosarevsky" on  2003-08-23 }
{ e-mail: netsurfer@au.ru }
{$mode objfpc}
{$inline on}

Type tw2651_tmyclass=Class
        Class Procedure tw2651_inlineproc;Inline;
     End;

Class Procedure tw2651_tmyclass.tw2651_inlineproc;Inline;
Begin
End;
{$pop}

{ Case tw26536.pp }
{$push}
{$MODE OBJFPC}

type
   tw26536_tbaseclass = class
      function tw26536_printself(): tw26536_tbaseclass; inline; // has to be inline for the bug to manifest
   end;

   tw26536_tsubclass = class(tw26536_tbaseclass)
   end;

function tw26536_tbaseclass.tw26536_printself(): tw26536_tbaseclass; inline;
begin
   Writeln(PtrUInt(Self));
   Result := nil;
   Writeln(PtrUInt(Self)); // prints 0!
   if not assigned(self) then
     halt(1);
end;

procedure tw26536_noop(var Dummy: tw26536_tbaseclass);
begin
end;

var
   tw26536_instance, tw26536_variable: tw26536_tbaseclass;
   tw26536_res: longint;
{$pop}

{ Case tw27414.pp }
{$push}
{$mode objfpc}

type

 tw27414_tproc = procedure(const aparam : string);

 tw27414_tobj = class
   class procedure tw27414_proc(const aparam : string); static;
 end;

var
  tw27414_s: string;

class procedure tw27414_tobj.tw27414_proc(const aparam : string);
begin
  tw27414_s:=aparam;
end;

var
 tw27414_p : tw27414_tproc;
{$pop}

{ Case tw2788.pp }
{$push}
{$mode objfpc}

Type tw2788_tlobject=Class;

Type tw2788_tlobject=Class
     End;
{$pop}

{ Case tw28454.pp }
{$push}
{$mode objfpc}

type
  tw28454_tc = class(tinterfacedobject)
    tw28454_l: longint;
    constructor create(f: longint);
  end;

constructor tw28454_tc.create(f: longint);
  begin
    tw28454_l:=f;
  end;

procedure tw28454_test(out tw28454_i1,tw28454_i2: iinterface; tw28454_k3,tw28454_k4,tw28454_k5,tw28454_k6,tw28454_k7,tw28454_k8: longint; out tw28454_i9,tw28454_i10: iinterface); stdcall;
begin
  tw28454_i1:=tw28454_tc.create(1);
  tw28454_i2:=tw28454_tc.create(2);
  tw28454_i9:=tw28454_tc.create(9);
  tw28454_i10:=tw28454_tc.create(10);
end;

var
  tw28454_i1,tw28454_i2,tw28454_i9,tw28454_i10: iinterface;
{$pop}

{ Case tw3778.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3778 }
{ Submitted by "David Fuchs" on  2005-03-13 }
{ e-mail: drfuchs@yahoo.com }

{$mode objfpc}

type
  tw3778_a_class=class
    procedure tw3778_a_method;
    function tw3778_a_virtual_method:tw3778_a_class; virtual;
    end;
  tw3778_a_container=class
    tw3778_a_field:tw3778_a_class;
    end;

var
  tw3778_already_called: boolean;
  tw3778_glob: tw3778_a_class;
  tw3778_container_array: array[0..255] of tw3778_a_container;
        tw3778_error : boolean;

function tw3778_a_function:byte;
begin
  if tw3778_already_called then
    begin
      writeln('This can not possibly happen!');
      tw3778_error:=true;
    end;
  tw3778_a_function:=255;
  tw3778_already_called:=true;
end;

function tw3778_a_class.tw3778_a_virtual_method:tw3778_a_class;
begin
  tw3778_a_virtual_method:=self;
end;

procedure tw3778_a_class.tw3778_a_method;
begin
  {this statement somehow compiles into TWO calls to a_function!}
  tw3778_glob:=tw3778_container_array[tw3778_a_function].tw3778_a_field.tw3778_a_virtual_method;
end;
{$pop}

{ Case tw4278.pp }
{$push}
{$mode objfpc}

var
  tw4278_err : boolean;

type
  tw4278_ta = class
  end;
  tw4278_tb = class(tw4278_ta)
  end;
  tw4278_tc = class(tw4278_tb)
  end;

procedure tw4278_test(const A: tw4278_ta); overload;
begin
end;

procedure tw4278_test(const B: tw4278_tb); overload;
begin
  writeln('ok');
  tw4278_err:=false;
end;

var
  tw4278_x : tw4278_tc;
{$pop}

{ Case tw7643.pp }
{$push}
{$mode objfpc}

type
  tw7643_tmethod = procedure of object;

  tw7643_tdummy = class
    procedure tw7643_method;
  end;

  tw7643_tr=record
    tw7643_i1,tw7643_i2 : longint;
  end;
  tw7643_pr=^tw7643_tr;

procedure tw7643_tdummy.tw7643_method;
begin
end;

procedure tw7643_dosomething(tw7643_method: tw7643_tmethod);
begin
end;

var
  tw7643_dummy: tw7643_tdummy;
  tw7643_r : tw7643_tr;
  tw7643_i : longint;
{$pop}

begin
  { Case tw2481.pp }
  {$push}
{$ifdef FPC_HAS_TYPE_EXTENDED}
{$endif FPC_HAS_TYPE_EXTENDED}
  begin
tw2481_moo := tw2481_tmoo.tw2481_init;
  tw2481_moo := 0.2;
  end;
  {$pop}

  { Case tw24844b.pp }
  {$push}

  begin
WriteLn('Mode: ', {$IFDEF FPC_DELPHI}'delphi'{$ELSE}'objfpc'{$ENDIF});

  tw24844b_tobj.Create.tw24844b_test;
  tw24844b_uncompilableproc;
  end;
  {$pop}

  { Case tw2645.pp }
  {$push}
{$inline on}
  begin
tw2645_o:=tw2645_c.create;
  tw2645_o.tw2645_p2;
  tw2645_o.free;
  end;
  {$pop}

  { Case tw2651.pp }
  {$push}
{$inline on}
  begin
tw2651_tmyclass.tw2651_inlineproc;
  end;
  {$pop}

  { Case tw26536.pp }
  {$push}

  begin
tw26536_instance := tw26536_tsubclass.Create();
   tw26536_variable := nil;

   tw26536_noop(tw26536_variable); // this call is important for the bug to manifest
   tw26536_variable := tw26536_instance;
   // object being invoked has to be cast to a different type for the bug to manifest
   // return value has to be assigned to the variable being used as "self"
   tw26536_variable := tw26536_tsubclass(tw26536_variable).tw26536_printself();

   tw26536_instance.Free();
  end;
  {$pop}

  { Case tw27414.pp }
  {$push}

  begin
tw27414_p := @tw27414_tobj.tw27414_proc;
  tw27414_p('abc');
  if tw27414_s<>'abc' then
    halt(1);
  end;
  {$pop}

  { Case tw28454.pp }
  {$push}

  begin
tw28454_test(tw28454_i1,tw28454_i2,3,4,5,6,7,8,tw28454_i9,tw28454_i10);
  if (tw28454_i1 as tw28454_tc).tw28454_l<>1 then
    halt(1);
  if (tw28454_i2 as tw28454_tc).tw28454_l<>2 then
    halt(2);
  if (tw28454_i9 as tw28454_tc).tw28454_l<>9 then
    halt(3);
  if (tw28454_i10 as tw28454_tc).tw28454_l<>10 then
    halt(4);
  end;
  {$pop}

  { Case tw3778.pp }
  {$push}

  begin
tw3778_already_called:=false;
        tw3778_glob:=tw3778_a_class.create;
        tw3778_container_array[255]:=tw3778_a_container.create;
        tw3778_container_array[255].tw3778_a_field:=tw3778_glob;
        tw3778_glob.tw3778_a_method;
        if tw3778_error then
          halt(1);
  end;
  {$pop}

  { Case tw4278.pp }
  {$push}

  begin
tw4278_err:=true;
  tw4278_test(tw4278_x);
  if tw4278_err then
    halt(1);
  end;
  {$pop}

  { Case tw7643.pp }
  {$push}

  begin
tw7643_i:=ptrint(@tw7643_pr(nil)^.tw7643_i2);
{  Dummy := nil;
  DoSomething(@Dummy.Method);}
  tw7643_dosomething(@tw7643_tdummy(nil).tw7643_method);
  end;
  {$pop}

end.
