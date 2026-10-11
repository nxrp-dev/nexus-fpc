{ Consolidated objects regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb0252.pp }
{$push}
{ Old file: tbs0292.pp }
{ objects not finalized when disposed                  OK 0.99.13 (FK) }



type
  tb0252_pobj = ^tb0252_tobj;
  tb0252_tobj = object
    a: ansistring;
    constructor init(tb0252_s: ansistring);
    destructor done;
  end;

  tb0252_PAnsiRec = ^tb0252_TAnsiRec;
  tb0252_TAnsiRec = Packed Record
    Maxlen,
    len,
    ref   : Longint;
    First : Char;
  end;

const tb0252_firstoff = sizeof(tb0252_tansirec)-1;

var tb0252_o: tb0252_pobj;
    tb0252_t: ansistring;

constructor tb0252_tobj.init(tb0252_s: ansistring);
begin
  a := tb0252_s;
end;

destructor tb0252_tobj.done;
begin
end;

const
  tb0252_s : string = ' with suffix';
var
  tb0252_refbefore : longint;

{$pop}

{ Case tw0965.pp }
{$push}

{$ifdef fpc}{$endif}

type
  tw0965_pobj = ^tw0965_tobj;
  tw0965_tobj = object
    public
      constructor init;
      destructor done; virtual;

      procedure proc1 (a: integer);overload; virtual;
      procedure proc1 (a: double);overload; virtual;
  end;

  tw0965_pobj2 = ^tw0965_tobj2;
  tw0965_tobj2 = object (tw0965_tobj)
      procedure proc1 (a: integer);overload;virtual;
  end;

var
  tw0965_error : boolean;

constructor tw0965_tobj.init;
begin
end;

destructor tw0965_tobj.done;
begin
end;

procedure tw0965_tobj.proc1 (a: integer);
begin
write('tobj.proc1(a:integer) called: ');
writeln (a);
end;

procedure tw0965_tobj.proc1 (a: double);
begin
write('tobj.proc1(a:double) called: ');
writeln (a);
tw0965_error:=false;
end;

procedure tw0965_tobj2.proc1 (a: integer);
begin
write('tobj2.proc1(a:integer) called: ');
writeln (a);
end;

var
    tw0965_obj1: tw0965_pobj;
    tw0965_obj2: tw0965_pobj2;


{$pop}

{ Case tw40957.pp }
{$push}



//{$OPTIMIZATION NODFA}
//{$OPTIMIZATION NOFORLOOP}

type
  tw40957_TObj = object
    tw40957_arr: array [0..512] of byte;
    constructor init;
    destructor done; virtual;
  end;

const
  tw40957_cnt=44;

var
  tw40957_arr: array[0..tw40957_cnt] of tw40957_TObj;
  tw40957_i: int32;

constructor tw40957_TObj.init;
begin
end;

destructor tw40957_TObj.done;
begin
end;


{$pop}

{ Case tw9095.pp }
{$push}


type
    tw9095_ta = byte;
    tw9095_pa = ^byte;
    tw9095_panother = tw9095_pa;

type
    tw9095_tRec = record
        a : tw9095_ta;
        p : tw9095_panother;
    end;

    tw9095_tNestedObj = object
        arec : tw9095_tRec;
        p : tw9095_panother;
    end;

    tw9095_tChildObj = object(tw9095_tNestedObj)
        dummy : byte;
    end;

type

    tw9095_tObj = object
        arec : tw9095_tRec;
        aobj : tw9095_tNestedObj;
        achild : tw9095_tChildObj;

        property a_rec : byte read arec.a;
        property a_obj : byte read aobj.arec.a;
        property p_obj : tw9095_pa read aobj.p;
        property dummy_child : byte read achild.dummy;
        property a_child : byte read achild.arec.a;
{ Error: Unknown record field identifier "arec" ^
            Error: Unknown record field identifier "a" ^
}
        property p_child : tw9095_pa read achild.p;
{ Error: Unknown record field identifier "p" ^
}
    end;

var
  tw9095_Obj : tw9095_tObj;


{$pop}

begin

{ Case tb0252.pp }
{$push}

begin
  tb0252_t:='test'+tb0252_s;
  tb0252_refbefore:=tb0252_pansirec(pointer(tb0252_t)-tb0252_firstoff)^.ref;
  writeln('refcount before init: ',tb0252_pansirec(pointer(tb0252_t)-tb0252_firstoff)^.ref);
  new(tb0252_o,init(tb0252_t));
  writeln('refcount after init: ',tb0252_pansirec(pointer(tb0252_t)-tb0252_firstoff)^.ref);
  dispose(tb0252_o,done);
  writeln('refcount after done: ',tb0252_pansirec(pointer(tb0252_t)-tb0252_firstoff)^.ref);
  if tb0252_refbefore<>tb0252_pansirec(pointer(tb0252_t)-tb0252_firstoff)^.ref then
    Halt(1);
end;
{$pop}

{ Case tw0965.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
tw0965_error:=true;
    new (tw0965_obj1, init);
    new (tw0965_obj2, init);
    tw0965_obj2^.proc1 (444.5555);
if tw0965_error then
 halt(1);

end;
{$pop}

{ Case tw40957.pp }
{$push}

{$OPTIMIZATION NODFA}
{$OPTIMIZATION NOFORLOOP}
begin
  for tw40957_i:=0 to tw40957_cnt do tw40957_arr[tw40957_i].init;
  for tw40957_i:=0 to tw40957_cnt do tw40957_arr[tw40957_i].done; // AV here in run-time
end;
{$pop}

{ Case tw9095.pp }
{$push}

begin
  tw9095_Obj.achild.p:=tw9095_panother($deadbeef);
  if tw9095_Obj.p_child<>tw9095_panother($deadbeef) then
    halt(1);
  writeln('ok');
end;
{$pop}

end.
