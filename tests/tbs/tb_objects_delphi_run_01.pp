{ Objects regression cases; original case IDs are retained below. }

{ Case tb0681.pp }
{$push}
{$Mode Delphi}

type tb0681_r = record
    var tb0681_x: Integer;
    function tb0681_foo: Integer;
end;

function tb0681_r.tb0681_foo: Integer;
begin
    result := tb0681_x
end;

var    tb0681_f: function : Integer of object;
    tb0681_z: tb0681_r = (tb0681_x:42);
{$pop}

{ Case tw14743.pp }
{$push}
{$mode delphi}

type
    tw14743_parent = object
        constructor tw14743_init;
    end;

    tw14743_child = object(tw14743_parent)
        constructor tw14743_init(a : byte);reintroduce;
    end;

constructor tw14743_parent.tw14743_init;
begin
end;

constructor tw14743_child.tw14743_init(a : byte);
begin
end;
{$pop}

{ Case tw2595.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2595 }
{ Submitted by "Michalis Kamburelis" on  2003-07-24 }
{ e-mail: michalis@camelot.homedns.org }

{ With fpc 1.1 (from snapshot downloaded at 23.07.2003) this program causes compilation error  "Error: Wrong number of parameters specified"
  near the "F(1)" statement. But you can see everything is ok and there is no error.
  (Of course, this particular program would cause runtime error because F is not initialized, but it's semantically correct).
  Error is only under DELPHI and TP modes.
  Change declaration
    TFuncByObject = function(i:Integer):boolean of object;
  to
    TFuncByObject = procedure(i:Integer);
  (make procedure instead of a function) and everything will compile ok.
  Change it to
    TFuncByObject = function(i:Integer):boolean;
  (no longer "by object") and again everything will compile ok.
  It has to be "function" and "by object" to cause the bug.

  Observed with FPC under win32 and linux (i386).
}

{$mode DELPHI}

type
  tw2595_tfuncbyobject = function(tw2595_i:Integer):boolean of object;

var tw2595_f:tw2595_tfuncbyobject;
  tw2595_i : integer;
{$pop}

{ Case tw2776.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2776 }
{ Submitted by "Vincent Snijders" on  2003-11-09 }
{ e-mail: vslist@zonnet.nl }
{$mode delphi}
var
  tw2776_a: procedure of object;
{$pop}

{ Case tw31305.pp }
{$push}
{$MODE DELPHI}

type
  tw31305_tinterfacestublog = object
    tw31305_timestamp64: Int64;
    tw31305_waserror: boolean;
    tw31305_method: Pointer;
    tw31305_params: UTF8String;
    tw31305_customresults: UTF8String;
  end;

var
  tw31305_a,tw31305_b: tw31305_tinterfacestublog;
{$pop}

{ Case tw4209.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4209 }
{ Submitted by "Ivo Steinmann" on  2005-07-22 }
{ e-mail: isteinmann@bluewin.ch }

{$mode delphi}

var
  tw4209_err : boolean;

type
  tw4209_xmethod = procedure of object;
  tw4209_xprocedure = procedure;

procedure tw4209_test(const Callback: tw4209_xmethod); overload;
begin
end;

procedure tw4209_test(const Callback: tw4209_xprocedure); overload;
begin
  writeln('ok');
  tw4209_err:=false;
end;

procedure tw4209_foobar;
begin
end;
{$pop}

begin
  { Case tb0681.pp }
  {$push}

  begin
// EXPECTED: gets compiled
    // ACTUAL: 'Error: Incompatible types'
    tb0681_f := tb0681_z.tb0681_foo;
    if tb0681_f() <> 42 then
      Halt(1);
  end;
  {$pop}

  { Case tw2595.pp }
  {$push}

  begin
tw2595_i:=0;
  if tw2595_i=1 then
    tw2595_f(1);
  end;
  {$pop}

  { Case tw2776.pp }
  {$push}

  begin
tw2776_a:=nil;
  if assigned(tw2776_a)
    then ;
  end;
  {$pop}

  { Case tw31305.pp }
  {$push}

  begin
tw31305_a.tw31305_method := Pointer($1);
  CopyArray(@tw31305_b, @tw31305_a, TypeInfo(tw31305_tinterfacestublog), 1);
  if not Assigned(tw31305_b.tw31305_method) then
    Halt(1);
  end;
  {$pop}

  { Case tw4209.pp }
  {$push}

  begin
tw4209_err:=true;
  tw4209_test(tw4209_foobar);
  if tw4209_err then
    halt(1);
  end;
  {$pop}

end.
