{ Classes regression cases; original case IDs are retained below. }

{ Case tb0228.pp }
{$push}
{ Old file: tbs0267.pp }
{ parameters after methodpointer are wrong             OK 0.99.12b (FK) }

{$MODE objfpc}

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
{$mode objfpc}

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
{$mode objfpc}
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
{$ifdef fpc}{$mode objfpc}{$endif}
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
{$ifdef fpc}{$mode objfpc}{$endif}
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
{$ifdef fpc}{$mode objfpc}{$endif}
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
{$ifdef fpc}{$mode objfpc}{$endif}
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
{$mode objfpc}

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
  {$mode objfpc}
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
{$mode objfpc}
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
{$mode objfpc}
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
{$mode objfpc}

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

end.
