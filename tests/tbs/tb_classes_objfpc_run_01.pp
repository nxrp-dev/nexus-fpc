{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode objfpc}


{ Source group: tb_classes_objfpc_run_01.pp }
{$push}

{ Case tb0228.pp }
{$push}
{ Old file: tbs0267.pp }
{ parameters after methodpointer are wrong             OK 0.99.12b (FK) }



type
  tb0228_tprocofobject = procedure of object;
  tb0228_ttestclass = class
    procedure tb0228_somemethod;
  end;

procedure tb0228_ttestclass.tb0228_somemethod; begin end;

// the following proc won't print i2 correctly

procedure tb0228_crashproc(i1: Integer;tb0228_method: tb0228_tprocofobject; tb0228_i2: Integer);
begin
  WriteLn('i1 is :', i1);
  WriteLn('i2 is :', tb0228_i2);
  if tb0228_i2<>456 then
    Halt(1);
end;

var
  tb0228_instance: tb0228_ttestclass;
{$pop}

{ Case tb0305.pp }
{$push}


type
   tb0305_tobject2 = class
      tb0305_i : longint;
      procedure tb0305_y;
      constructor create;
      class procedure tb0305_x;
      class procedure tb0305_v;virtual;
   end;

  procedure tb0305_tobject2.tb0305_y;

    begin
        Writeln('Procedure y called');
    end;

  class procedure tb0305_tobject2.tb0305_v;

    begin
    end;

  class procedure tb0305_tobject2.tb0305_x;

    begin
       tb0305_v;
    end;

  constructor tb0305_tobject2.create;

    begin
    end;

  type
     tb0305_tclass2 = class of tb0305_tobject2;

  var
     tb0305_a : class of tb0305_tobject2;
     tb0305_object2 : tb0305_tobject2;
{$pop}

{ Case tb0356.pp }
{$push}

type
  tb0356_tc = class
    tb0356_left,tb0356_right: tb0356_tc;
    function tb0356_test(var c: tb0356_tc): boolean;
  end;

  tb0356_testfunc = function(var c: tb0356_tc):boolean of object;

  function tb0356_foreach(var c: tb0356_tc; tb0356_p: tb0356_testfunc): boolean;
    begin
      if not assigned(c) then
        exit;
    end;

  function tb0356_tc.tb0356_test(var c: tb0356_tc): boolean;
  begin
    { if you use @test, the compiler tries to get the address of the }
    { function result instead of the address of the method (JM)       }
    result := tb0356_foreach(c.tb0356_left,@self.tb0356_test);
    result := tb0356_foreach(c.tb0356_right,@self.tb0356_test) or result;
  end;
{$pop}

{ Case tb0387.pp }
{$push}
{$ifdef fpc}{$endif}
type
  tb0387_tobj1 = class
      procedure tb0387_proc1 (a: char);
  end;

  tb0387_tobj2 = class (tb0387_tobj1)
      procedure tb0387_proc1 (a: integer);overload;
  end;

procedure tb0387_tobj1.tb0387_proc1 (a: char);
begin
  write('tobj1.proc1(a:char) called: ');
  writeln (a);
end;

procedure tb0387_tobj2.tb0387_proc1 (a: integer);
begin
  write('tobj2.proc1(a:integer) called: ');
  writeln (a);
end;

var
    tb0387_obj1: tb0387_tobj1;
    tb0387_obj2: tb0387_tobj2;
{$pop}

{ Case tb0388.pp }
{$push}
{$ifdef fpc}{$endif}
type
  tb0388_tobj = class
      procedure tb0388_proc1 (a: integer);virtual;
  end;

  tb0388_tobj1 = class(tb0388_tobj)
      procedure tb0388_proc1 (a: integer);overload;override;
      procedure tb0388_proc1 (a: char);overload;
  end;

  tb0388_tobj2 = class (tb0388_tobj1)
      procedure tb0388_proc1 (a: integer);override;
  end;

procedure tb0388_tobj.tb0388_proc1 (a: integer);
begin
  write('tobj.proc1(a:integer) called: ');
  writeln (a);
end;

procedure tb0388_tobj1.tb0388_proc1 (a: integer);
begin
  write('tobj1.proc1(a:integer) called: ');
  writeln (a);
end;

procedure tb0388_tobj1.tb0388_proc1 (a: char);
begin
  write('tobj1.proc1(a:char) called: ');
  writeln (a);
end;

procedure tb0388_tobj2.tb0388_proc1 (a: integer);
begin
  write('tobj2.proc1(a:integer) called: ');
  writeln (a);
end;

var
    tb0388_obj1: tb0388_tobj1;
    tb0388_obj2: tb0388_tobj2;
{$pop}

{ Case tb0389.pp }
{$push}
{$ifdef fpc}{$endif}
type
  tb0389_tobj = class
      procedure tb0389_proc1 (a: integer);overload;virtual;
      procedure tb0389_proc1 (a: extended);overload;
  end;

  tb0389_tobj1 = class(tb0389_tobj)
      procedure tb0389_proc1 (a: integer);overload;override;
      procedure tb0389_proc1 (a: char);overload;
  end;

  tb0389_tobj2 = class (tb0389_tobj1)
      procedure tb0389_proc1 (a: integer);override;
  end;

procedure tb0389_tobj.tb0389_proc1 (a: integer);
begin
  write('tobj.proc1(a:integer) called: ');
  writeln (a);
end;

procedure tb0389_tobj.tb0389_proc1 (a: extended);
begin
  write('tobj.proc1(a:extended) called: ');
  writeln (a);
end;

procedure tb0389_tobj1.tb0389_proc1 (a: integer);
begin
  write('tobj1.proc1(a:integer) called: ');
  writeln (a);
end;

procedure tb0389_tobj1.tb0389_proc1 (a: char);
begin
  write('tobj1.proc1(a:char) called: ');
  writeln (a);
end;

procedure tb0389_tobj2.tb0389_proc1 (a: integer);
begin
  write('tobj2.proc1(a:integer) called: ');
  writeln (a);
end;

var
    tb0389_obj1: tb0389_tobj1;
    tb0389_obj2: tb0389_tobj2;
{$pop}

{ Case tb0390.pp }
{$push}
{$ifdef fpc}{$endif}
type
  tb0390_tobj = class
      procedure tb0390_proc1 (a: integer);virtual;
  end;

  tb0390_tobj1 = class (tb0390_tobj)
      procedure tb0390_proc1 (a: char);overload;
  end;

  tb0390_tobj2 = class (tb0390_tobj1)
      { this will try to override tobj1.proc1 which is not
        allowed and therefor needs an error }
      procedure tb0390_proc1 (a: integer);override;
  end;

procedure tb0390_tobj.tb0390_proc1 (a: integer);
begin
end;

procedure tb0390_tobj1.tb0390_proc1 (a: char);
begin
end;

procedure tb0390_tobj2.tb0390_proc1 (a: integer);
begin
end;
{$pop}

{ Case tb0403.pp }
{$push}


type
  tclass = class
    procedure tb0403_t; virtual;
  end;

procedure tclass.tb0403_t;
begin
end;

var
  tb0403_p: codepointer;
{$pop}

{ Case tb0552.pp }
{$push}
{$ifdef FPC}

{$endif FPC}
type
  tb0552_pb1 = ^boolean;
  tb0552_pb2 = ^boolean deprecated;
  tb0552_pt = boolean deprecated;
  tb0552_o = class
  end deprecated;
  tb0552_r = record
  end deprecated;
  tb0552_p1 = procedure;stdcall;deprecated;
  tb0552_p2 = procedure deprecated;
  tb0552_p3 = tb0552_p1 deprecated;

var
  tb0552_v : tb0552_p3;
{$pop}

{ Case tb0592.pp }
{$push}

type
  tb0592_tt_stream   = record z : Pointer; end;

  tb0592_tfreetypestream = class
    tb0592_fused : Boolean;
  end;

 procedure tb0592_tt_done_stream( stream : tb0592_tt_stream );
 begin
   if stream.z = nil then exit;
   tb0592_tfreetypestream(stream.z).tb0592_fused := false;
 end;
{$pop}

{ Case tb0641.pp }
{$push}

type
  tb0641_tc = class sealed
  end;

var
  tb0641_c : tb0641_tc;

function tb0641_f : tb0641_tc;
  begin
    result:=tb0641_tc.create;
  end;
{$pop}

{ Case tw0947.pp }
{$push}


var
  tw0947_last,tw0947_lastt2 : integer;

type
  tw0947_t1 = class
    procedure tw0947_somemethod(Param: Integer); virtual;
  end;

  tw0947_t2 = class(tw0947_t1)
    procedure tw0947_somemethod(Param: Integer); override;
    procedure tw0947_inheritedmethod(Param: Integer);
    destructor Destroy; override;
  end;

procedure tw0947_t1.tw0947_somemethod(Param: Integer);
begin
  tw0947_last:=Param;
  writeln('T1 ', Param);
end;

procedure tw0947_t2.tw0947_inheritedmethod(Param: Integer);
begin
  inherited tw0947_somemethod(Param);
end;

procedure tw0947_t2.tw0947_somemethod(Param: Integer);
begin
  tw0947_lastt2:=param;
  writeln('T2 ', Param);
end;

destructor tw0947_t2.Destroy;
begin
  tw0947_somemethod(3);
  inherited tw0947_somemethod(2);
  inherited Destroy;
end;

var
  tw0947_a: tw0947_t2;
{$pop}

{ Case tb0298.pp }
{$push}

type
   tb0298_tobject1 = class
      readl : longint;
      function readl2 : longint;
      procedure writel(ll : longint);
      procedure writel2(ll : longint);
      property l : longint read readl write writel;
      property l2 : longint read readl2 write writel2;
   end;

procedure tb0298_tobject1.writel(ll : longint);

  begin
  end;

procedure tb0298_tobject1.writel2(ll : longint);

  begin
  end;

function tb0298_tobject1.readl2 : longint;

  begin
  end;

var
   tb0298_object1 : tb0298_tobject1;
   tb0298_i : longint;
{$pop}

{ Case tb0306.pp }
{$push}


type
   tb0306_tobject2 = class
      constructor create;
      function rname : string;
      procedure wname(const s : string);
      property name : string read rname write wname;
   end;

   tb0306_tclass2 = class of tb0306_tobject2;

var
   tb0306_o2 : tb0306_tobject2;
   tb0306_c2 : tb0306_tclass2;

constructor tb0306_tobject2.create;

  begin
     inherited create;
  end;

procedure tb0306_tobject2.wname(const s : string);

  begin
  end;

function tb0306_tobject2.rname : string;

  begin
  end;
{$pop}

{ Case tb0405.pp }
{$push}
{$ifdef fpc}{$endif}

var
  tb0405_err : boolean;

type
  tb0405_tc1=class
    constructor Create;overload;
  end;

  tb0405_tc2=class(tb0405_tc1)
    constructor Create(l:longint=0);overload;
  end;

constructor tb0405_tc1.create;
begin
  writeln('tc1.create()');
end;

constructor tb0405_tc2.create(l:longint);
begin
  writeln('tc2.create()');
  tb0405_err:=false;
end;

var
  tb0405_c : tb0405_tc2;
{$pop}

{ Case tb0299.pp }
{$push}
type
   tb0299_tmyclass = class of tmyobject;

   tmyobject = class
   end;

{ only a stupid test routine }
function tb0299_getanchestor(tb0299_c : System.TClass) : System.TClass;

  var
     tb0299_l : longint;

  begin
     tb0299_getanchestor:=tobject;
     tb0299_l:=tb0299_l+1;
  end;

var
   tb0299_classref : System.TClass;
   tb0299_myclassref : tb0299_tmyclass;

const
   tb0299_constclassref1 : System.TClass = tobject;
   tb0299_constclassref2 : System.TClass = nil;
   tb0299_constclassref3 : System.TClass = tobject;
{$pop}


{$pop}

{ Source group: tb_classes_objfpc_run_02.pp }
{$push}

{ Case tw10757.pp }
{$push}


type
  tw10757_ta = class
    tw10757_t: array of Double;
  end;

var
  tw10757_a: tw10757_ta;

function tw10757_p:tw10757_ta;
begin
  Result := tw10757_a;
end;

function tw10757_m: Double;
begin
  Result := 300;
end;

var
  tw10757_i: Integer;
{$pop}

{ Case tw12242a.pp }
{$push}


type
  tw12242a_tc = class
    class procedure tw12242a_a; cdecl; static;
    class procedure tw12242a_b; cdecl; static;
    procedure tw12242a_c;
  end;

var
  tw12242a_ok: boolean;

class procedure tw12242a_tc.tw12242a_a; cdecl; static;
begin
  writeln('a');
  tw12242a_ok:=true;
end;

class procedure tw12242a_tc.tw12242a_b; cdecl; static;
begin
  tw12242a_a;
end;

procedure tw12242a_tc.tw12242a_c;
begin
  tw12242a_a;
end;

var
  tw12242a_c: tw12242a_tc;
{$pop}

{ Case tw1283.pp }
{$push}

 type
     tw1283_t = class(tobject)
      constructor tw1283_init;
     end;

 constructor tw1283_t.tw1283_init;
 begin
  fail; { constructor will return NULL in ESI now, which is OK }
 end;

 type
     tw1283_c = class(tobject)
      procedure tw1283_p;
     end;

 procedure tw1283_c.tw1283_p;
  var tw1283_i:tw1283_t;
 begin
  tw1283_i:=tw1283_t.tw1283_init;
  if tw1283_i<>nil then
    begin
       writeln('Problem with saving a non assigned self');
       halt(1);
    end;
  { returned is NULL in ESI, and AfterConstructor is attempted to call by
    referencing an invalid VMT via ESI}
 end;

 var tw1283_i:tw1283_c;
{$pop}

{ Case tw1573.pp }
{$push}


type
        tw1573_tcheck=class(TObject);

var
        tw1573_vla : tw1573_tcheck;
        tw1573_vlb : TObject;

procedure tw1573_aa(const ParXX :array of TObject);
begin
        // writeln(cardinal(ParXX[0]),' ', cardinal(ParXX[1]));
        if (ParXX[0]<>tw1573_vla) or (ParXX[1]<>tw1573_vlb) then
          begin
             writeln('error');
             halt(1);
          end;
end;
{$pop}

{ Case tw1798.pp }
{$push}
{$ifdef fpc}{$endif}

type

tw1798_tgraphiccontrol = class
end;

tw1798_tbutton = class
end;

tw1798_tbitbtn = class(tw1798_tbutton)
private
published
end;

tw1798_tspeedbutton = class(tw1798_tgraphiccontrol)
published
end;

tw1798_tmybutton = class(tw1798_tbitbtn);

const tw1798_myconst = 1;
{$pop}

{ Case tw18443.pp }
{$push}

type
  tw18443_tbase = class
    function tw18443_print: String; virtual;
  end;

  tw18443_tdesc1 = class(tw18443_tbase)
    function tw18443_print: String; override;
  end;

  tw18443_tdesc2 = class(tw18443_tbase)
    function tw18443_print: String; override;
  end;

function tw18443_tbase.tw18443_print: String;
begin
  Result := 'Base';
end;

function tw18443_tdesc1.tw18443_print: String;
begin
  Result := inherited + '-Desc1';
end;

function tw18443_tdesc2.tw18443_print: String;
begin
  Result := inherited tw18443_print + '-Desc2';
end;
{$pop}

{ Case tw2198.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2198 }
{ Submitted by "Sebastian Günther" on  2002-10-23 }
{ e-mail: sg@freepascal.org }



type
  tw2198_ttest = class
    procedure tw2198_x;
    procedure tw2198_x(i: Integer);
  end;

procedure tw2198_ttest.tw2198_x;
const tw2198_s = 'Test1';
begin
  writeln(tw2198_s);
end;

procedure tw2198_ttest.tw2198_x(i: Integer);
const tw2198_s = 'Test2';
begin
  writeln(tw2198_s);
end;

var
  tw2198_t : tw2198_ttest;
{$pop}

{ Case tw22869.pp }
{$push}


type
  tw22869_tc = class
    procedure tw22869_test; virtual;
  end;

  tw22869_trec = record
    tw22869_c: tw22869_tc;
  end;

procedure tw22869_tc.tw22869_test;
begin
end;

procedure tw22869_doit(tw22869_r: tw22869_trec);
begin
  tw22869_r.tw22869_c.tw22869_test;
end;

var
  tw22869_r: tw22869_trec;
  tw22869_c: tw22869_tc;
{$pop}

{ Case tw22878.pp }
{$push}

    type
        tw22878_t0= record
            tw22878_p: pointer;
        end;
        tw22878_t1= packed record
            tw22878_u16: word;
            tw22878_data: tw22878_t0;
        end;

        tw22878_td= class
            function tw22878_return: tw22878_t1;
        end;
            function tw22878_td.tw22878_return: tw22878_t1;
            begin
              tw22878_return.tw22878_u16:=1;
              tw22878_return.tw22878_data.tw22878_p:=pointer(2);
            end;
var
  tw22878_c: tw22878_td;
  tw22878_r: tw22878_t1;
{$pop}

{ Case tw2328.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2328 }
{ Submitted by "Pavel V. Ozerski" on  2003-01-20 }
{ e-mail: ozerski@list.ru }
{$ifdef fpc}

{$endif}
type
 tw2328_tclassa=class
  procedure DefaultHandler(var Message);override;
 end;
procedure tw2328_tclassa.DefaultHandler(var Message);
 begin
  inherited //;
 end;
{$pop}

{ Case tw24536.pp }
{$push}
{$ifdef fpc}{$endif}
type
  tw24536_tmyclass = class
    procedure tw24536_myabstractmethod; virtual; abstract;
    procedure tw24536_myabstractmethod2; virtual; abstract;
  end;

  tw24536_tmyclass2 = class(tw24536_tmyclass)
  end;

var
  tw24536_foo,tw24536_foo2: CodePointer;
{$pop}

{ Case tw2454.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2454 }
{ Submitted by "Nikolay Nikolov" on  2003-04-06 }
{ e-mail: nickysn1983@netscape.net }


Type
  tw2454_tfunclass = Class(TObject)
    tw2454_data : Integer;
    Class Procedure tw2454_funproc(q : tw2454_tfunclass);
  End;

Class Procedure tw2454_tfunclass.tw2454_funproc(q : tw2454_tfunclass);

Begin
  Writeln(q.tw2454_data);
  With q Do
  Begin
    Writeln(q.tw2454_data);

    Writeln(tw2454_data); { fpc 1.1 says: Error: Only class methods can be accessed in class methods

    this is a bug, because 'data' actually means 'q.data' due to the 'with' statement,
    (this can be seen if you make this a normal method by removing the 'Class' keyword
    and running the program, it will writeln q.data, not self.data)
    so it shouldn't cause an error
    }
  End;
End;

Var
  tw2454_c1, tw2454_c2 : tw2454_tfunclass;
{$pop}


{$pop}

{ Source group: tb_classes_objfpc_run_04.pp }
{$push}

{ Case tw8028.pp }
{$push}

{$inline on}

type
  tw8028_ttest = procedure of object;

  tw8028_tmyrecord = record
    tw8028_test: tw8028_ttest;
  end;

  tw8028_tmyobject = class
    procedure tw8028_test;
  end;

function tw8028_tmyrecordmake(const tw8028_test: tw8028_ttest): tw8028_tmyrecord; inline;
begin
  Result.tw8028_test := tw8028_test;
end;

procedure tw8028_tmyobject.tw8028_test;
begin
  tw8028_tmyrecordmake(nil);
end;
{$pop}

{ Case tw9919.pp }
{$push}


type
  tw9919_tform1 = class
    function tw9919_crash(n:integer):real;
  end;

function tw9919_tform1.tw9919_crash(n:integer):real;
begin
  case n of
  0: Result:=0;
  1..100: Result:=tw9919_crash(n-1)+tw9919_crash(n-1);
  end;
end;

var
  tw9919_f : tw9919_tform1;
{$pop}


{$pop}

{ Source group: tb_classes_objfpc_run_05.pp }
{$push}

{ Case tw0868.pp }
{$push}

{$H+}
type
  tw0868_ttreedata = record
    tw0868_key: String;
    tw0868_data: Integer;
  end;

  tw0868_tnode = class
    tw0868_data: tw0868_ttreedata;
  end;

  tw0868_tstrintdic = class
    tw0868_fnode: tw0868_tnode;
    destructor Destroy; override;
    procedure tw0868_add(const tw0868_key: String; tw0868_data: Integer);
  end;

destructor tw0868_tstrintdic.Destroy;
begin
  tw0868_fnode.Free;
  inherited Destroy;
end;

procedure tw0868_tstrintdic.tw0868_add(const tw0868_key: String; tw0868_data: Integer);
var
  tw0868_t: tw0868_ttreedata;
begin
  tw0868_t.tw0868_key:=tw0868_key;
  tw0868_t.tw0868_data:=tw0868_data;
  tw0868_fnode:=tw0868_tnode.Create;
  tw0868_fnode.tw0868_data:=tw0868_t;
end;

procedure tw0868_test;
var
  tw0868_sd: tw0868_tstrintdic;
begin
  tw0868_sd:=tw0868_tstrintdic.Create;
  try
    tw0868_sd.tw0868_add('asdf', 2);
  finally
    tw0868_sd.Free;
  end;
end;
{$pop}

{ Case tw22864.pp }
{$push}
{$H+}

type
  tw22864_tonidentifierfound = function(): integer of object;
  tw22864_ttest=class
    tw22864_onidentifierfound: tw22864_tonidentifierfound;
    tw22864_foundproc: pointer;
    function tw22864_testm():integer;
  end;
  tw22864_ttest2=class
    function tw22864_testmm(Params:tw22864_ttest;var tw22864_c,tw22864_d,tw22864_e:integer):boolean;
  end;

function tw22864_ttest.tw22864_testm():integer;
  begin

  end;

function tw22864_ttest2.tw22864_testmm(Params:tw22864_ttest;var tw22864_c,tw22864_d,tw22864_e:integer):boolean;
var tw22864_k,tw22864_l:integer;

  function tw22864_testm2(Params1:tw22864_ttest;var tw22864_m,tw22864_n:integer):boolean;
  var tw22864_a,tw22864_b:integer;
  begin
    if (Params.tw22864_onidentifierfound<>@Params.tw22864_testm) then halt(1);
    if (Params.tw22864_foundproc<>pointer($deadbeef)) then halt(1);
  end;

begin
  tw22864_testm2(Params,tw22864_k,tw22864_l);
end;

var
  tw22864_test : tw22864_ttest;
  tw22864_test2 : tw22864_ttest2;
  tw22864_c,tw22864_d,tw22864_e : integer;
{$pop}

{ Case tw30923.pp }
{$push}
{$H+}

Type
  tw30923_qstringlisth = class(TObject) end;

function tw30923_qstringlist_size(handle: tw30923_qstringlisth): Integer; cdecl;
begin
  Result := 1;
end;

procedure tw30923_qstringlist_at(handle: tw30923_qstringlisth; tw30923_retval: PWideString; tw30923_i: Integer); cdecl;
begin

end;

procedure tw30923_test;
Var
  tw30923_aqstringlisth : tw30923_qstringlisth;
  tw30923_awidestring : WideString;
  tw30923_i : Integer;
begin
  For tw30923_i := 0 To tw30923_qstringlist_size(tw30923_aqstringlisth) - 1  do
    tw30923_qstringlist_at(tw30923_aqstringlisth, @tw30923_awidestring, tw30923_i);
end;

Var
  tw30923_i : Integer;
{$pop}


{$pop}

{ Source group: tb_nil_references_objfpc_run_01.pp }
{$push}

{ Case tb0329.pp }
{$push}
var
   tb0329_o : tobject;
{$pop}

{ Case tb0331.pp }
{$push}

{ tests assignments and compare }

var
   tb0331_o1,tb0331_o2 : tobject;
{$pop}

{ Case tb0350.pp }
{$push}
var
   tb0350_a : longint absolute 0;
{$pop}


{$pop}

begin
  { Source group: tb_classes_objfpc_run_01.pp }
  {$push}


begin
  { Case tb0228.pp }
  {$push}

  begin
tb0228_instance := tb0228_ttestclass.Create;
  tb0228_crashproc(123, @tb0228_instance.tb0228_somemethod, 456);
  end;
  {$pop}

  { Case tb0305.pp }
  {$push}

  begin
tb0305_a:=tb0305_tobject2;
   tb0305_a.tb0305_x;
   tb0305_tobject2.tb0305_x;
   tb0305_object2:=tb0305_tobject2.create;
   tb0305_object2:=tb0305_a.create;
  end;
  {$pop}

  { Case tb0387.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tb0387_obj1:=tb0387_tobj1.create;
  tb0387_obj2:=tb0387_tobj2.create;

  tb0387_obj2.tb0387_proc1 ('a');
  end;
  {$pop}

  { Case tb0388.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tb0388_obj1:=tb0388_tobj1.create;
  tb0388_obj2:=tb0388_tobj2.create;

  tb0388_obj2.tb0388_proc1 (100);
  tb0388_obj2.tb0388_proc1 ('a');
  end;
  {$pop}

  { Case tb0389.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tb0389_obj1:=tb0389_tobj1.create;
  tb0389_obj2:=tb0389_tobj2.create;

  tb0389_obj2.tb0389_proc1 (100);
  tb0389_obj2.tb0389_proc1 ('a');
  tb0389_obj2.tb0389_proc1 (123.456);
  end;
  {$pop}

  { Case tb0403.pp }
  {$push}

  begin
tb0403_p := @tclass.tb0403_t;
  end;
  {$pop}

  { Case tb0641.pp }
  {$push}

  begin
tb0641_c:=tb0641_tc.create;
  if not(tb0641_c is tb0641_tc) then
    halt(1);
  if not(tb0641_f is tb0641_tc) then
    halt(1);
  writeln('ok');;
  end;
  {$pop}

  { Case tw0947.pp }
  {$push}

  begin
tw0947_last:=0;
  tw0947_lastt2:=0;
  tw0947_a:=tw0947_t2.Create;
  tw0947_a.tw0947_somemethod(1); { Ok }
  if tw0947_lastt2<>1 then
    Halt(1);
  tw0947_a.tw0947_inheritedmethod(4); { Ok }
  if tw0947_last<>4 then
    Halt(1);
  tw0947_a.Free; { error }
  if tw0947_last<>2 then
    Halt(1);
  if tw0947_lastt2<>3 then
    Halt(1);
  Writeln('Bug with calling inherited in destructors solved');
  end;
  {$pop}

  { Case tb0298.pp }
  {$push}
begin
   tb0298_object1:=tb0298_tobject1.create;
   tb0298_i:=tb0298_object1.l;
   tb0298_i:=tb0298_object1.l2;
   tb0298_object1.l:=123;
end;
  {$pop}

  { Case tb0306.pp }
  {$push}
begin
   tb0306_o2:=tb0306_tobject2.create;
   tb0306_o2.name:='1234';
   writeln(tb0306_o2.name);
   tb0306_o2.destroy;
   tb0306_c2:=tb0306_tobject2;
   tb0306_o2:=tb0306_c2.create;
   tb0306_o2.destroy;
end;
  {$pop}

  { Case tb0405.pp }
  {$push}
begin
  tb0405_err:=true;
  tb0405_c:=tb0405_tc2.create();
  tb0405_c.free;
  if tb0405_err then
   begin
     writeln('Error!');
     halt(1);
   end;
end;
  {$pop}

  { Case tb0299.pp }
  {$push}
begin
   { simple test }
   tb0299_classref:=tb0299_classref;
   { more difficult }
   tb0299_classref:=tb0299_myclassref;
   tb0299_classref:=tobject;
   tb0299_myclassref:=tmyobject;

   tb0299_classref:=tb0299_getanchestor(tb0299_myclassref);
   if (upcase(tb0299_constclassref1.classname)<>'TOBJECT') or
     (tb0299_constclassref2<>nil) or
     (upcase(tb0299_myclassref.classname)<>'TMYOBJECT') or
     (upcase(tb0299_classref.classname)<>'TOBJECT') then
     begin
        writeln('Error');
        halt(1);
     end;
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_classes_objfpc_run_02.pp }
  {$push}


begin
  { Case tw10757.pp }
  {$push}

  begin
tw10757_a := tw10757_ta.Create;
  SetLength(tw10757_p.tw10757_t,2);
  tw10757_p.tw10757_t[0] := 70;
  tw10757_p.tw10757_t[1] := 80;
  tw10757_i := 0;
  while (tw10757_i < Length(tw10757_p.tw10757_t)) and (tw10757_m > tw10757_p.tw10757_t[tw10757_i]) do
    Inc(tw10757_i);
  if (tw10757_i<>2) then
    halt(1);
  end;
  {$pop}

  { Case tw12242a.pp }
  {$push}

  begin
tw12242a_ok:=false;
  tw12242a_tc.tw12242a_b;
  if not tw12242a_ok then
    halt(1);
  tw12242a_ok:=false;
  tw12242a_c:=tw12242a_tc.create;
  tw12242a_c.tw12242a_c;
  tw12242a_c.free;
  if not tw12242a_ok then
    halt(2);
  end;
  {$pop}

  { Case tw1283.pp }
  {$push}

  begin
tw1283_i:=tw1283_c.create; tw1283_i.tw1283_p;
  end;
  {$pop}

  { Case tw1573.pp }
  {$push}

  begin
tw1573_vlb := TObject.Create;
        tw1573_vla := tw1573_tcheck.Create;
        tw1573_aa([tw1573_vla,tw1573_vlb]);
  end;
  {$pop}

  { Case tw2198.pp }
  {$push}

  begin
tw2198_t:=tw2198_ttest.create;
  tw2198_t.tw2198_x;
  tw2198_t.tw2198_x(1);
  tw2198_t.free;
  end;
  {$pop}

  { Case tw22869.pp }
  {$push}

  begin
tw22869_c:=tw22869_tc.create;
  tw22869_r.tw22869_c:=tw22869_c;
  tw22869_doit(tw22869_r);
  tw22869_c.free;
  end;
  {$pop}

  { Case tw22878.pp }
  {$push}

  begin
tw22878_c:=tw22878_td.create;
  tw22878_r:=tw22878_c.tw22878_return;
  if tw22878_r.tw22878_u16<>1 then
    halt(1);
  if tw22878_r.tw22878_data.tw22878_p<>pointer(2) then
    halt(2);
  end;
  {$pop}

  { Case tw24536.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw24536_foo := @tw24536_tmyclass.tw24536_myabstractmethod;
  tw24536_foo2 := @tw24536_tmyclass.tw24536_myabstractmethod2;
  if tw24536_foo=tw24536_foo2 then
    Halt(1);
  tw24536_foo2 := @tw24536_tmyclass2.tw24536_myabstractmethod;
  if tw24536_foo<>tw24536_foo2 then
    Halt(2);
  end;
  {$pop}

  { Case tw2454.pp }
  {$push}

  begin
tw2454_c1 := tw2454_tfunclass.Create;
  tw2454_c2 := tw2454_tfunclass.Create;
  tw2454_c1.tw2454_data := 5;
  tw2454_c2.tw2454_data := 7;
  tw2454_c1.tw2454_funproc(tw2454_c2);
  tw2454_c1.Destroy;
  tw2454_c2.Destroy;
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_classes_objfpc_run_04.pp }
  {$push}


begin
  { Case tw9919.pp }
  {$push}

  begin
tw9919_f:=tw9919_tform1.create;
  writeln(tw9919_f.tw9919_crash(15));
  tw9919_f.Free;
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_classes_objfpc_run_05.pp }
  {$push}


begin
  { Case tw0868.pp }
  {$push}

  begin
tw0868_test;
  write('Test for bug 868 completed.');
  {readln;}
  end;
  {$pop}

  { Case tw22864.pp }
  {$push}

  begin
tw22864_test:=tw22864_ttest.Create;
  tw22864_test.tw22864_onidentifierfound:=@tw22864_test.tw22864_testm;
  tw22864_test.tw22864_foundproc:=pointer($deadbeef);
  tw22864_test2:=tw22864_ttest2.Create;
  tw22864_test2.tw22864_testmm(tw22864_test,tw22864_c,tw22864_d,tw22864_e);
  tw22864_test.Free;
  tw22864_test2.Free;
  writeln('ok');
  end;
  {$pop}

  { Case tw30923.pp }
  {$push}

  begin
tw30923_test;
  tw30923_i := 0;
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_nil_references_objfpc_run_01.pp }
  {$push}


begin
  { Case tb0329.pp }
  {$push}
begin
   if assigned(tb0329_o) then
     halt(1);
end;
  {$pop}

  { Case tb0331.pp }
  {$push}
begin
   tb0331_o1:=nil;
   tb0331_o2:=tb0331_o1;
   if tb0331_o2<>nil then
     halt(1);
end;
  {$pop}

  { Case tb0350.pp }
  {$push}
begin
   if @tb0350_a<>nil then
     halt(1);
end;
  {$pop}


end;
  {$pop}

end.
