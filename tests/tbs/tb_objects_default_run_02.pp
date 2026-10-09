{ Objects regression cases; original case IDs are retained below. }

{ Case tb0368.pp }
{$push}
type
  tb0368_tproc = procedure of object;
  tb0368_trec = record
    tb0368_l1 : codeptrint;
    tb0368_l2 : ptrint;
  end;
var
  tb0368_pfn : tb0368_tproc;
{$pop}

{ Case tb0408.pp }
{$push}
{ This passes under Delphi and Borland pascal      }
{ for objects, classes don't pass, cf. /tbf/tb0125 }
type

  tb0408_tobjsymbol = object
  end;

  tb0408_tobjderivedsymbol = object(tb0408_tobjsymbol)
  end;

procedure tb0408_testobject(var t: tb0408_tobjsymbol);
begin
end;

var
 tb0408_myobject : tb0408_tobjderivedsymbol;
{$pop}

{ Case tw0760.pp }
{$push}
type tw0760_telement = object
      constructor tw0760_init;
      {something}
      destructor Free; virtual;
      destructor tw0760_done; virtual;
     end;

constructor tw0760_telement.tw0760_init;
begin
  Writeln('Init called');
end;

destructor tw0760_telement.free;
begin
  Writeln('Free used');
end;

destructor tw0760_telement.tw0760_done;
begin
  Writeln('Done used');
end;

var
  tw0760_e : tw0760_telement;
  tw0760_pe : ^tw0760_telement;
{$pop}

{ Case tw1123.pp }
{$push}
TYPE  tw1123_pobj = ^tw1123_tobj;
      tw1123_tobj = OBJECT
        tw1123_ii          : INTEGER;
        CONSTRUCTOR tw1123_init(i :INTEGER);
        DESTRUCTOR  tw1123_done;
      END;

CONSTRUCTOR tw1123_tobj.tw1123_init(i :INTEGER);
BEGIN
  tw1123_ii := i;
END;

DESTRUCTOR tw1123_tobj.tw1123_done;
BEGIN
END;

VAR   tw1123_obj  : ARRAY[1..2] OF tw1123_tobj;
{$pop}

{ Case tw12137.pp }
{$push}
{$t-}
type
  tw12137_telementvalidator = object
    tw12137_felementdef: pointer;
    tw12137_fcurcp: pointer;
    tw12137_ffailed: Boolean;
  end;

var
  tw12137_fvalidator: array of tw12137_telementvalidator;
  tw12137_i: longint;
{$pop}

{ Case tw16954.pp }
{$push}
type
   tw16954_etyp=(t1,t2,t3);

type
   tw16954_proxyobject=object
     function tw16954_isinsubrange(const typ:tw16954_etyp):boolean;static;
   end;

   tw16954_realobject=object
     tw16954_mytyp:tw16954_etyp;
     function tw16954_isinsubrange:boolean;
   end;

function tw16954_realobject.tw16954_isinsubrange: boolean;
begin
   tw16954_isinsubrange:=tw16954_proxyobject.tw16954_isinsubrange(tw16954_mytyp);
   // ^-- Error: Class isn't a parent class of the current class
   // and AV of compiler
end;

function tw16954_proxyobject.tw16954_isinsubrange(const typ: tw16954_etyp): boolean;
begin
   tw16954_isinsubrange:=typ<=t2;
end;

var tw16954_o:tw16954_realobject;
{$pop}

{ Case tw1863.pp }
{$push}
type
 tw1863_tobj =   object
  constructor tw1863_init0;
  constructor tw1863_init;
  procedure   tw1863_show;
  function    tw1863_getstr:string; virtual;
  destructor  tw1863_done;
 end;

 tw1863_tchild = object (tw1863_tobj)
   function tw1863_getstr:string; virtual;
 end;

var
  tw1863_err : boolean;

constructor tw1863_tobj.tw1863_init0;
begin
end;

constructor tw1863_tobj.tw1863_init;
begin
  tw1863_init0;
end;

function   tw1863_tobj.tw1863_getstr:string;
begin
  tw1863_getstr:='Bad';
  tw1863_err:=true;
end;

procedure  tw1863_tobj.tw1863_show;
begin
  writeln(tw1863_getstr);
end;

destructor tw1863_tobj.tw1863_done;
begin
end;

function tw1863_tchild.tw1863_getstr:string;
begin
  tw1863_getstr:='Good'
end;

var
  tw1863_obj:tw1863_tchild;
{$pop}

{ Case tw2233.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2233 }
{ Submitted by "Sergey Kosarevsky" on  2002-11-19 }
{ e-mail: netsurfer@au.ru }
Type tw2233_pguiview=^tw2233_tguiview;
     tw2233_tguiview=Object
        Constructor tw2233_init;
        Procedure tw2233_renderview;Virtual;Abstract;
     End;
Type tw2233_tguiwindow=Object(tw2233_tguiview)
        Constructor tw2233_init;
        Procedure tw2233_renderview;Virtual;
     End;
Type tw2233_tguicommoncontrol=Object(tw2233_tguiwindow)
        Constructor tw2233_init;
        Constructor tw2233_init(Param1:Longint);
     End;
Type tw2233_pguiradiogroup=^tw2233_tguiradiogroup;
     tw2233_tguiradiogroup=Object(tw2233_tguicommoncontrol)
        Constructor tw2233_init;
        Constructor tw2233_init(Param1:Longint);
        Procedure tw2233_renderview;Virtual;
     End;
var
  tw2233_err : boolean;

Constructor tw2233_tguiview.tw2233_init;
Begin
End;
Constructor tw2233_tguiwindow.tw2233_init;
Begin
   Inherited tw2233_init;
End;
Procedure tw2233_tguiwindow.tw2233_renderview;
Begin
   WriteLn('tGUIWindow.RenderView()');
End;
Constructor tw2233_tguicommoncontrol.tw2233_init;
Begin
   tw2233_init(0);
End;
Constructor tw2233_tguicommoncontrol.tw2233_init(Param1:Longint);
Begin
   Inherited tw2233_init;
End;
Constructor tw2233_tguiradiogroup.tw2233_init;
Begin
   Inherited tw2233_init;
End;
Constructor tw2233_tguiradiogroup.tw2233_init(Param1:Longint);
Begin
   Inherited tw2233_init(Param1);
End;
Procedure tw2233_tguiradiogroup.tw2233_renderview;
Begin
   Inherited tw2233_renderview;
   WriteLn('tGUIRadioGroup.RenderView()');
   tw2233_err:=false;
End;
Var tw2233_view:tw2233_pguiview;
{$pop}

{ Case tw2442.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2442 }
{ Submitted by "Louis Jean-Richard" on  2003-03-28 }
{ e-mail: Ljean_richard@compuserve.com }

TYPE
        tw2442_anobject        =
                OBJECT
                        tw2442_n       : byte;
                        PROCEDURE tw2442_a( tw2442_w : word );
                        PROCEDURE tw2442_a( c : cardinal );
                END
                ;
PROCEDURE tw2442_anobject.tw2442_a( tw2442_w : word );

        PROCEDURE tw2442_b;
        BEGIN
                WriteLn('B called (word)')
        END
        ;
BEGIN
        tw2442_n:=tw2442_w DIV 2;
        tw2442_b
END
;
PROCEDURE tw2442_anobject.tw2442_a( c : cardinal );

        PROCEDURE tw2442_b;
        BEGIN
                WriteLn('B called (cardinal)');
        writeln('error!');
        halt(1);
        END
        ;
BEGIN
        tw2442_n:=c DIV 4;
        tw2442_b
END
;
VAR
        tw2442_x       : tw2442_anobject;
        tw2442_w       : word;
{$pop}

{ Case tw3971.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3971 }
{ Submitted by "Thomas Schatzl" on  2005-05-16 }
{ e-mail:  }
type
        tw3971_tdemo1 = object
                tw3971_member1 : byte;
                tw3971_member2 : longint;

                tw3971_member7 : ^longint;
                tw3971_member3 : int64;

                tw3971_member4 : byte;
                tw3971_member5 : longint;
                //x : boolean;
                //
                tw3971_member6 : int64;
                tw3971_x : boolean;
        end;

        tw3971_tdemo = object
                tw3971_member1 : byte;
                tw3971_member5 : longint;
                tw3971_member6 : int64;
                tw3971_y : array[0..2] of tw3971_tdemo1;

                constructor tw3971_init;
                destructor Destroy;
                procedure tw3971_dosomething;
                procedure tw3971_dosomething2;
        end;
var
        tw3971_x : array[0..2] of tw3971_tdemo;

        tw3971_z : tw3971_tdemo;
        tw3971_w : tw3971_tdemo1;

constructor tw3971_tdemo.tw3971_init();
begin
        WriteLn('Create start');
        inherited;
        WriteLn('Create end');
end;

destructor tw3971_tdemo.Destroy();
begin
        WriteLn('Destroy start');
        inherited;
        WriteLn('Destroy end');
end;

procedure tw3971_tdemo.tw3971_dosomething;
begin
        WriteLn('doSomething');
end;

procedure tw3971_tdemo.tw3971_dosomething2;
begin
        WriteLn('doSomething');
end;
{$pop}

{ Case tw40496.pp }
{$push}
type

	tw40496_ttestobjfail = object
		constructor tw40496_init(
			tw40496_p1, tw40496_p2, tw40496_p3, tw40496_p4: Currency; tw40496_p5: Currency);
	end;

constructor tw40496_ttestobjfail.tw40496_init(
			tw40496_p1, tw40496_p2, tw40496_p3, tw40496_p4: Currency; tw40496_p5: Currency);
begin
  if tw40496_p1<>1 then
    halt(1);
  if tw40496_p2<>2 then
    halt(2);
  if tw40496_p3<>3 then
    halt(3);
  if tw40496_p4<>4 then
    halt(4);
  if tw40496_p5<>5 then
    halt(5);
end;

var
	tw40496_testobj	: tw40496_ttestobjfail;
{$pop}

begin
  { Case tb0368.pp }
  {$push}

  begin
tb0368_pfn:=nil;
  if (tb0368_trec(tb0368_pfn).tb0368_l1<>0) or
     (tb0368_trec(tb0368_pfn).tb0368_l2<>0) then
   begin
     writeln('Error!');
     halt(1);
   end;
  end;
  {$pop}

  { Case tb0408.pp }
  {$push}

  begin
tb0408_testobject(tb0408_myobject);
  end;
  {$pop}

  { Case tw0760.pp }
  {$push}

  begin
tw0760_e.tw0760_init;
  tw0760_e.Free;
  new(tw0760_pe,tw0760_init);
  dispose(tw0760_pe,tw0760_done);
  end;
  {$pop}

  { Case tw1123.pp }
  {$push}

  begin
tw1123_obj[1].tw1123_init(10);
  WITH tw1123_obj[2] DO tw1123_init(tw1123_obj[1].tw1123_ii + 1); (* equal Init(0+1) = wrong *)

  Writeln;
  Writeln(tw1123_obj[1].tw1123_ii:10);
  Writeln(tw1123_obj[2].tw1123_ii:10);
  if tw1123_obj[2].tw1123_ii<>11 then
   halt(1);

(* this should report 10 and 11, when ok *)
  end;
  {$pop}

  { Case tw12137.pp }
  {$push}
{$t-}
  begin
tw12137_i:=1;
  setlength(tw12137_fvalidator,5);
  writeln(ptruint(pointer(@tw12137_fvalidator[1])-pointer(@tw12137_fvalidator[0])));
  { aligned }
  tw12137_fvalidator[0].tw12137_felementdef:=@tw12137_fvalidator;
  tw12137_fvalidator[0].tw12137_fcurcp:=@tw12137_fvalidator;
  { unaligned }
  tw12137_fvalidator[1].tw12137_felementdef:=@tw12137_fvalidator;
  tw12137_fvalidator[1].tw12137_fcurcp:=@tw12137_fvalidator;
  { unaligned }
  tw12137_fvalidator[tw12137_i].tw12137_felementdef:=@tw12137_fvalidator;
  tw12137_fvalidator[tw12137_i].tw12137_fcurcp:=@tw12137_fvalidator;
  end;
  {$pop}

  { Case tw16954.pp }
  {$push}

  begin
if tw16954_proxyobject.tw16954_isinsubrange(t3) then
    halt(1);
  if not tw16954_proxyobject.tw16954_isinsubrange(t2) then
    halt(2);
  tw16954_o.tw16954_mytyp:=t3;
  if tw16954_o.tw16954_isinsubrange then
    halt(3);
  tw16954_o.tw16954_mytyp:=t1;
  if not tw16954_o.tw16954_isinsubrange then
    halt(4);
  end;
  {$pop}

  { Case tw1863.pp }
  {$push}

  begin
tw1863_obj.tw1863_init;
 tw1863_obj.tw1863_show;
 tw1863_obj.tw1863_done;
 if tw1863_err then
  halt(1);
  end;
  {$pop}

  { Case tw2233.pp }
  {$push}

  begin
tw2233_err:=true;
   tw2233_view:=New(tw2233_pguiradiogroup,tw2233_init);
   tw2233_view^.tw2233_renderview;
   if tw2233_err then
    begin
      writeln('ERROR!');
      halt(1);
    end;
  end;
  {$pop}

  { Case tw2442.pp }
  {$push}

  begin
tw2442_w:=1;
        tw2442_x.tw2442_a(tw2442_w)  { the wrong local procedure is called !!! }
  end;
  {$pop}

  { Case tw3971.pp }
  {$push}

  begin
tw3971_z.tw3971_init;
        if ((ptrint(@tw3971_z.tw3971_y)-ptrint(@tw3971_z)) mod sizeof(ptrint))<>0 then
          halt(1);
        if ((ptrint(@tw3971_z.tw3971_y[0].tw3971_member7)-ptrint(@tw3971_z)) mod sizeof(ptrint))<>0 then
          halt(1);
        tw3971_z.destroy;
        WriteLn(sizeof(tw3971_tdemo), ' ', sizeof(tw3971_tdemo1));
  end;
  {$pop}

  { Case tw40496.pp }
  {$push}

  begin
tw40496_testobj.tw40496_init(1, 2, 3, 4, 5);
  end;
  {$pop}

end.
