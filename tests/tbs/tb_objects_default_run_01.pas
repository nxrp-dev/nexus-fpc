{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode fpc}


{ Source group: tb_objects_default_run_01.pas }
{$push}

{ Case tb0025.pas }
{$push}
{ Old file: tbs0029.pas }
{  tests typeof(object type)                         OK 0.99.1 (FK) }

type
  tb0025_ta = object
    constructor tb0025_init;
    procedure tb0025_test;virtual;
  end;

  constructor tb0025_ta.tb0025_init;
    begin
    end;

  procedure tb0025_ta.tb0025_test;
    begin
    end;

var
   tb0025_p: Pointer;
{$pop}

{ Case tb0067.pas }
{$push}
{ Old file: tbs0074.pas }
{  shows MAJOR bugs when trying to compile valid code    OK 0.99.1 (PM/CEC) }

type
  tb0067_tmyobject = object
    constructor tb0067_init;
    procedure tb0067_callit; virtual;
    destructor tb0067_done; virtual;
  end;

  constructor tb0067_tmyobject.tb0067_init;
  Begin
  end;

  destructor tb0067_tmyobject.tb0067_done;
  Begin
  end;

  procedure tb0067_tmyobject.tb0067_callit;
  Begin
   WriteLn('Hello...');
  end;

  var
   tb0067_obj: tb0067_tmyobject;
{$pop}

{ Case tb0083.pas }
{$push}
{ Old file: tbs0096.pas }
{ problem with objects as parameters                    OK 0.99.6 (PM) }

type
   tb0083_tparent = object
   end;

   tb0083_pparent = ^tb0083_tparent;

   tb0083_tchild = object(tb0083_tparent)
   end;

procedure tb0083_aproc(const x : tb0083_tparent );
begin
end;

procedure tb0083_anotherproc(var x : tb0083_tparent );
begin
end;

var
   tb0083_y : tb0083_tchild;
{$pop}

{ Case tb0091.pas }
{$push}
{ Old file: tbs0107.pas }
{ shows page fault problem (run in TRUE DOS mode)       OK ??.?? }

{ PAGE FAULT PROBLEM ... TEST UNDER DOS ONLY! Not windows... }
{ -Cr -g flags                                               }

type
 tb0091_myobject = object
   constructor tb0091_init;
   procedure tb0091_v;virtual;
 end;

 constructor tb0091_myobject.tb0091_init;
 Begin
 end;

 procedure tb0091_myobject.tb0091_v;
 Begin
  WriteLn('Hello....');
 end;

var
 tb0091_my: tb0091_myobject;
{$pop}

{ Case tb0100.pas }
{$push}
{ Old file: tbs0119.pas }
{ problem with methods                                  OK 0.99.6 (FK) }

   type
     tb0100_objecta = object
       procedure tb0100_greetings;
       procedure tb0100_doit;
     end;
     tb0100_objectb = object (tb0100_objecta)
       procedure tb0100_greetings;
       procedure tb0100_doit;
     end;

   procedure tb0100_objecta.tb0100_greetings;
   begin
     writeln('  A');
   end;
   procedure tb0100_objecta.tb0100_doit;
   begin
     writeln('A ');
     tb0100_greetings;
   end;

   procedure tb0100_objectb.tb0100_greetings;
   begin
     writeln('  B');
   end;
   procedure tb0100_objectb.tb0100_doit;
   begin
     writeln('B');
     tb0100_greetings;
   end;

   var
     tb0100_a: tb0100_objecta;
     tb0100_b: tb0100_objectb;
{$pop}

{ Case tb0117.pas }
{$push}
{ Old file: tbs0137.pas }
{ Cannot assign child object variable to parent objcet type variable OK 0.99.6 }

Type tb0117_tvater = Object
                Constructor tb0117_init;
                Procedure tb0117_gehen; Virtual;
                Procedure tb0117_laufen; Virtual;
              End;

     tb0117_tsohn = Object(tb0117_tvater)
               Procedure tb0117_gehen; Virtual;
             End;

Var tb0117_v : tb0117_tvater;
    tb0117_s : tb0117_tsohn;

Constructor tb0117_tvater.tb0117_init;
Begin
End;

Procedure tb0117_tvater.tb0117_gehen;
Begin
  Writeln('langsam gehen');
End;

Procedure tb0117_tvater.tb0117_laufen;
Begin
  tb0117_gehen;
  tb0117_gehen;
End;

Procedure tb0117_tsohn.tb0117_gehen;
Begin
  Writeln('schnell gehen');
End;
{$pop}

{ Case tb0123.pas }
{$push}
{ Old file: tbs0142.pas }
{ sizeof(object) is not tp7 compatible when no constructor is used OK 0.99.9 (PM) }

{$PACKRECORDS 1}

type
tb0123_time = object
  tb0123_h,tb0123_m,tb0123_s:byte;
end;

var tb0123_ot:tb0123_time;
 tb0123_l : longint;
{$pop}

{ Case tb0135.pas }
{$push}
{ Old file: tbs0159.pas }
{ Invalid virtual functions - should compile            OK 0.99.7 (FK) }

Type tb0135_tparent = Object
       Procedure tb0135_someproc;
       end;

     tb0135_tchild = Object(tb0135_tparent)
       Procedure tb0135_someproc; virtual;
       end;

       Procedure tb0135_tparent.tb0135_someproc;
       Begin
       end;

      procedure tb0135_tchild.tb0135_someproc;
      Begin
      end;
{$pop}

{ Case tb0181.pas }
{$push}
{ Old file: tbs0214.pas }
{ bugs for static methods                               OK 0.99.11 (PM) }

{ Note: I've cut a lot out of this program, it did originally have
        constructors, destructors and instanced objects, but this
        is the minimum required to produce the problem, and I think
        that this should work, unless I've misunderstood the use of
        the static keyword. }
Type
   tb0181_tobjecttype1 = Object
      Procedure tb0181_setup; static;
      Procedure tb0181_weird; static;
   End;

Procedure tb0181_tobjecttype1.tb0181_setup;
   Begin
   End;

Procedure tb0181_tobjecttype1.tb0181_weird;
   Begin
   End;
{$pop}

{ Case tb0182.pas }
{$push}
{ Old file: tbs0215.pas }
{ more bugs with static methods                        OK 0.99.11 (PM) }

{ allow static keyword }
{ submitted by Andrew Wilson }

Type
   tb0182_py=^tb0182_y;
   tb0182_y=Object
      tb0182_a : LongInt;
      tb0182_p : tb0182_py; static;
      Constructor tb0182_init(NewA:LongInt);
      Procedure tb0182_staticmethod; static;
      Procedure tb0182_virtualmethod; virtual;
   End;

Constructor tb0182_y.tb0182_init(NewA:LongInt);
   Begin
      tb0182_a:=NewA;
      tb0182_p:=@self;
   End;

Procedure tb0182_y.tb0182_staticmethod;
   Begin
      Writeln(tb0182_p^.tb0182_a);    // Compiler complains about using A.
      tb0182_p^.tb0182_virtualmethod; // Same with the virtual method.
      With tb0182_p^ do begin
         Writeln(tb0182_a);    // These two seem to compile, but I
         tb0182_virtualmethod; // can't get them to work. It seems to
      End;              // be the same problem as last time, so
   End;                 // I'll check it again when I get the
                        // new snapshot.
Procedure tb0182_y.tb0182_virtualmethod;
   Begin
      Writeln('VirtualMethod ',tb0182_a);
   End;

var tb0182_t1,tb0182_t2 :  tb0182_py;
{$pop}

{ Case tb0221.pas }
{$push}
{ Old file: tbs0260.pas }
{ problem with VMT generation if non virtual method has a virtual overload                        OK 0.99.12 (PM) }

  type
      tb0221_obj1 = object
        tb0221_st : string;
      constructor tb0221_init;
      procedure tb0221_writeit;
      end;

      tb0221_obj2 = object(tb0221_obj1)
      procedure tb0221_writeit;virtual;
      end;

      tb0221_obj3 = object(tb0221_obj2)
        tb0221_l : longint;
      end;

      constructor tb0221_obj1.tb0221_init;
        begin
        end;

      procedure tb0221_obj1.tb0221_writeit;
        begin
        end;

      procedure tb0221_obj2.tb0221_writeit;
        begin
        end;
{$pop}

{ Case tb0264.pas }
{$push}
{ Old file: tbs0307.pas }
{ "with object_type" doesn't work correctly!           OK 0.99.13 (?) }

type
  tb0264_tobj = object
    tb0264_l: longint;
    constructor tb0264_init;
    procedure tb0264_setv(v: longint);
    destructor tb0264_done;
  end;

constructor tb0264_tobj.tb0264_init;
begin
  tb0264_l := 0;
end;

procedure tb0264_tobj.tb0264_setv(v: longint);
begin
  tb0264_l := v;
end;

destructor tb0264_tobj.tb0264_done;
begin
end;

var tb0264_t: tb0264_tobj;
{$pop}


{$pop}

{ Source group: tb_objects_default_run_02.pas }
{$push}

{ Case tb0368.pas }
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

{ Case tb0408.pas }
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

{ Case tw0760.pas }
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

{ Case tw1123.pas }
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

{ Case tw12137.pas }
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

{ Case tw16954.pas }
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

{ Case tw1863.pas }
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

{ Case tw2233.pas }
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

{ Case tw2442.pas }
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

{ Case tw3971.pas }
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

{ Case tw40496.pas }
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


{$pop}

{ Source group: tb_object_methods_default_run_01.pas }
{$push}

{ Case tb0018.pas }
{$push}
{ Old file: tbs0022.pas }
{  tests getting the address of a method               OK 0.9.3 }

type
   tb0018_tobject = object
      procedure tb0018_x;
      constructor tb0018_c;
   end;

procedure tb0018_a;

  begin
  end;

procedure tb0018_tobject.tb0018_x;

  begin
  end;

constructor tb0018_tobject.tb0018_c;

  begin
  end;

var
   tb0018_p : codepointer;
{$pop}

{ Case tb0019.pas }
{$push}
{ Old file: tbs0023.pas }
{  tests handling of self pointer in nested methods    OK 0.9.3 }

type
   tb0019_tobject = object
      tb0019_a : longint;
      procedure tb0019_t1;
      procedure tb0019_t2;virtual;
      constructor tb0019_init;
   end;

procedure tb0019_tobject.tb0019_t1;

  procedure tb0019_nested1;

    begin
       writeln;
       tb0019_a:=1;
    end;

  begin
  end;

procedure tb0019_tobject.tb0019_t2;

  procedure tb0019_nested1;

    begin
       writeln;
       tb0019_a:=1;
    end;

  begin
  end;

constructor tb0019_tobject.tb0019_init;

  procedure tb0019_nested1;

    begin
       writeln;
       tb0019_a:=1;
    end;

  begin
  end;
{$pop}

{ Case tb0040.pas }
{$push}
{ Old file: tbs0045.pas }
{  shows problem with virtual private methods (might not be a true bugs but more of an incompatibility?) the compiler warns now if there is a private and virtual method }


TYPE
  tb0040_tmyexample =object
  public
   constructor tb0040_init;
   destructor tb0040_done; virtual;
  private
   procedure tb0040_mytest;virtual;       { syntax error --> should give only a
warning ? }
  end;

  constructor tb0040_tmyexample.tb0040_init;
  begin
  end;

  destructor tb0040_tmyexample.tb0040_done;
  Begin
  end;

  procedure tb0040_tmyexample.tb0040_mytest;
  begin
  end;
{$pop}

{ Case tb0404.pas }
{$push}
type
  tb0404_g = object
    public
      tb0404_b:procedure;
    { the 1.1 compiler parses the next "public" as a procdirective of the preceding procedure }
    public
      constructor tb0404_init;
  end;

  constructor tb0404_g.tb0404_init;
    begin
      tb0404_b:=nil;
    end;
{$pop}

{ Case tb0458.pas }
{$push}
type tb0458_smallword=word;

Type  tb0458_localheader     = Record
        Time          : Longint;
      End;

Type tb0458_pkzipobject = Object
       Buf         : longint;

       Constructor ZIPInit;
       Procedure FindFirstEntry;   Virtual;
     End; {PkzipObject}

     tb0458_pkzipptr = ^tb0458_pkzipobject;


Constructor tb0458_pkzipobject.ZIPInit;
Begin
End;


Procedure tb0458_pkzipobject.FindFirstEntry;
var tb0458_localheaderbuf: tb0458_localheader ABSOLUTE buf;
Begin
  tb0458_localheaderbuf.Time:=12341234;
End;

var
  tb0458_o : tb0458_pkzipobject;
{$pop}


{$pop}

begin
  { Source group: tb_objects_default_run_01.pas }
  {$push}


begin
  { Case tb0025.pas }
  {$push}

  begin
tb0025_p := pointer(TypeOf(tb0025_ta));
  end;
  {$pop}

  { Case tb0067.pas }
  {$push}

  begin
tb0067_obj.tb0067_init;
    tb0067_obj.tb0067_callit;
{    obj.done;}
  end;
  {$pop}

  { Case tb0083.pas }
  {$push}

  begin
tb0083_aproc(tb0083_y);
      tb0083_anotherproc(tb0083_y);
  end;
  {$pop}

  { Case tb0091.pas }
  {$push}

  begin
tb0091_my.tb0091_init;
 tb0091_my.tb0091_v;
  end;
  {$pop}

  { Case tb0100.pas }
  {$push}

  begin
tb0100_a.tb0100_doit;
     tb0100_b.tb0100_doit;
     writeln; writeln('Now doing it directly:');
     tb0100_a.tb0100_greetings;
     tb0100_b.tb0100_greetings;
  end;
  {$pop}

  { Case tb0117.pas }
  {$push}

  begin
tb0117_v.tb0117_init;
  tb0117_s.tb0117_init;
  tb0117_v.tb0117_laufen;
  Writeln;
  tb0117_s.tb0117_laufen;
  Writeln;
  tb0117_v := tb0117_s;
  tb0117_v.tb0117_gehen;
  end;
  {$pop}

  { Case tb0123.pas }
  {$push}
{$PACKRECORDS 1}
  begin
tb0123_l:=SizeOf(tb0123_ot);
  end;
  {$pop}

  { Case tb0181.pas }
  {$push}

  begin
tb0181_tobjecttype1.tb0181_setup;
   tb0181_tobjecttype1.tb0181_weird;
   tb0181_tobjecttype1.tb0181_weird; // GPFs before exiting "Weird"
   Writeln('THE END.');
  end;
  {$pop}

  { Case tb0182.pas }
  {$push}

  begin
New(tb0182_t1,tb0182_init(1));
  New(tb0182_t2,tb0182_init(2));
  tb0182_t1^.tb0182_virtualmethod;
  tb0182_t2^.tb0182_virtualmethod;
  tb0182_y.tb0182_staticmethod;
  tb0182_t1^.tb0182_staticmethod;
  tb0182_t2^.tb0182_staticmethod;
  end;
  {$pop}

  { Case tb0264.pas }
  {$push}

  begin
tb0264_t.tb0264_init;
  with tb0264_t do
    tb0264_setv(5);
  writeln(tb0264_t.tb0264_l, ' (should be 5!)');
  if tb0264_t.tb0264_l<>5 then
    Halt(1);
  tb0264_t.tb0264_done;
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_objects_default_run_02.pas }
  {$push}


begin
  { Case tb0368.pas }
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

  { Case tb0408.pas }
  {$push}

  begin
tb0408_testobject(tb0408_myobject);
  end;
  {$pop}

  { Case tw0760.pas }
  {$push}

  begin
tw0760_e.tw0760_init;
  tw0760_e.Free;
  new(tw0760_pe,tw0760_init);
  dispose(tw0760_pe,tw0760_done);
  end;
  {$pop}

  { Case tw1123.pas }
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

  { Case tw12137.pas }
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

  { Case tw16954.pas }
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

  { Case tw1863.pas }
  {$push}

  begin
tw1863_obj.tw1863_init;
 tw1863_obj.tw1863_show;
 tw1863_obj.tw1863_done;
 if tw1863_err then
  halt(1);
  end;
  {$pop}

  { Case tw2233.pas }
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

  { Case tw2442.pas }
  {$push}

  begin
tw2442_w:=1;
        tw2442_x.tw2442_a(tw2442_w)  { the wrong local procedure is called !!! }
  end;
  {$pop}

  { Case tw3971.pas }
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

  { Case tw40496.pas }
  {$push}

  begin
tw40496_testobj.tw40496_init(1, 2, 3, 4, 5);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_object_methods_default_run_01.pas }
  {$push}


begin
  { Case tb0018.pas }
  {$push}
begin
   tb0018_p:=@tb0018_a;
   tb0018_p:=@tb0018_tobject.tb0018_x;
   tb0018_p:=@tb0018_tobject.tb0018_c;
end;
  {$pop}

  { Case tb0019.pas }
  {$push}
begin
end;
  {$pop}

  { Case tb0040.pas }
  {$push}
Begin
end;
  {$pop}

  { Case tb0404.pas }
  {$push}
begin
end;
  {$pop}

  { Case tb0458.pas }
  {$push}
begin
  tb0458_o.ZIPInit;
  tb0458_o.FindFirstEntry;
  if tb0458_o.Buf<>12341234 then
    begin
      writeln('error');
      halt(1);
    end;
End;
  {$pop}


end;
  {$pop}

end.
