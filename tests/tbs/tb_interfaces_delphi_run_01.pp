{ Interfaces regression cases; original case IDs are retained below. }

{$mode delphi}

uses SysUtils;

{ Case tw11862.pp }
{$push}
{$ifdef fpc}
{$mode delphi}
{$endif}

type
  tw11862_ttesttype = (testgetchild,testparent,testparentex);

  tw11862_itest = interface(IInterface)
    ['{FE6B16A6-A898-4B09-A46E-0AAC5E0A4E14}']
    function tw11862_parent: tw11862_itest;
  end;

  tw11862_itestex = interface(tw11862_itest)
    ['{82449E91-76BE-4F4A-B873-1865042D5CAF}']
    function tw11862_parent: tw11862_itestex;
    function tw11862_getchild: tw11862_itestex;
    procedure tw11862_removechild;
  end;

  tw11862_ttest = class(TInterfacedObject, tw11862_itestex)
    function tw11862_itestex.tw11862_parent = tw11862_parentex;
    { ITest }
    function tw11862_parent: tw11862_itest;
    { ITestEx }
    function tw11862_parentex: tw11862_itestex;
    function tw11862_getchild: tw11862_itestex;
    procedure tw11862_removechild;
  end;
    { ITest }
var
  tw11862_test: tw11862_ttesttype;

function tw11862_ttest.tw11862_parent: tw11862_itest;
begin;
writeln('ttest.parent');
Result := nil;
if (tw11862_test<>testparent) then
  halt(1);
end;

    { ITestEx }

function tw11862_ttest.tw11862_parentex: tw11862_itestex;
begin;
writeln('ttest.parentex');
Result := nil;
if (tw11862_test<>testparentex) then
  halt(1);
end;

function tw11862_ttest.tw11862_getchild: tw11862_itestex;
begin;
WriteLn('TTest.GetChild');
Result := nil;
if (tw11862_test<>testgetchild) then
  halt(1);
end;

procedure tw11862_ttest.tw11862_removechild;
begin;
WriteLn('TTest.RemoveChild');
halt(1);
end;

var tw11862_e: tw11862_itestex;
    tw11862_e2: tw11862_itest;
{$pop}

{ Case tw14092.pp }
{$push}
{$mode delphi}

type
  tw14092_iintf = interface(IUnknown)
    function tw14092_getintf :tw14092_iintf;
    procedure tw14092_dosomething;
  end;

  tw14092_tobj = class(TObject)
    tw14092_fintf: tw14092_iintf;
    procedure tw14092_test1;
    procedure tw14092_test2;
  end;

  tw14092_tintf = class(TInterfacedObject,tw14092_iintf)
    function tw14092_getintf : tw14092_iintf;
    procedure tw14092_dosomething;
  end;

procedure tw14092_tobj.tw14092_test1;
begin
  tw14092_fintf.tw14092_dosomething;
end;

procedure tw14092_tobj.tw14092_test2;
begin
  tw14092_fintf.tw14092_getintf.tw14092_getintf.tw14092_dosomething;
end;

function tw14092_tintf.tw14092_getintf : tw14092_iintf;
  begin
    result:=self;
  end;

var
  tw14092_refs : Integer;

procedure tw14092_tintf.tw14092_dosomething;
  begin
    if RefCount<>tw14092_refs then
      halt(1);
    writeln(RefCount);
  end;

var
  tw14092_obj : tw14092_tobj;
{$pop}

{ Case tw2647.pp }
{$push}
{$mode Delphi}
type
  tw2647_isenslogon = interface (IDispatch)
  ['{d597bab3-5b9f-11d1-8dd2-00aa004abd5e}']
    function tw2647_logon(bstrUserName: WideString): HRESULT; stdcall; dispid 1;
    function tw2647_logoff(bstrUserName: WideString): HRESULT; stdcall; dispid 2;
    function tw2647_startshell(bstrUserName: WideString): HRESULT; stdcall; dispid 3;
    function tw2647_displaylock(bstrUserName: WideString): HRESULT; stdcall; dispid 4;
    function tw2647_displayunlock(bstrUserName: WideString): HRESULT; stdcall; dispid 5;
    function tw2647_startscreensaver(bstrUserName: WideString): HRESULT; stdcall; dispid 6;
    function tw2647_stopscreensaver(bstrUserName: WideString): HRESULT; stdcall; dispid 7;
  end;
{$pop}

{ Case tw3183a.pp }
{$push}
{$mode delphi}
type
  tw3183a_ta = interface
    function tw3183a_a: longint;
  end;

  tw3183a_tb = interface(tw3183a_ta)
    function tw3183a_a: ansistring;
  end;
{$pop}

{ Case tw8018.pp }
{$push}
{$mode delphi}

type
  tw8018_itest = interface(iunknown)
    procedure tw8018_foo(); overload;
    procedure tw8018_bar(); overload;
    procedure tw8018_foo(x: integer); overload;
    procedure tw8018_bar(x: integer); overload;
  end;

  tw8018_ttest = class(tinterfacedobject, tw8018_itest)
    procedure tw8018_foo(); overload;
    procedure tw8018_bar(); overload;
    procedure tw8018_foo(x: integer); overload;
    procedure tw8018_bar(x: integer); overload;
  end;

var
  tw8018_i : integer;
  tw8018_err : boolean;

procedure tw8018_ttest.tw8018_foo(); overload; begin writeln('#'); tw8018_i:=1; end;
procedure tw8018_ttest.tw8018_foo(x: integer); overload; begin writeln('##'); tw8018_i:=2; end;
procedure tw8018_ttest.tw8018_bar(); overload; begin writeln('###'); tw8018_i:=3; end;
procedure tw8018_ttest.tw8018_bar(x: integer); overload; begin writeln('####'); tw8018_i:=4; end;

var
  tw8018_t: tw8018_itest;
  tw8018_a: integer;
{$pop}

{ Case tb0571.pp }
{$push}
{$ifdef fpc}
{$mode delphi}
{$endif fpc}

{ Some (delphi) applications expect that the QueryInterface method is invoked as first
  priority to query for an interface and GetInterface as 2nd priority }

type
  tb0571_itest = interface
     ['{E80B0A2E-96ED-4F38-A6AC-E4E0B59F27F3}']
  end;

  tb0571_ttest = class(TObject, IUnknown, tb0571_itest)
  private
    tb0571_refcount: integer;
  public
    function QueryInterface(constref iid : tguid;out obj) : Hresult;{$IFNDEF WINDOWS}cdecl{$else}stdcall{$ENDIF};
    function _AddRef : longint;{$IFNDEF WINDOWS}cdecl{$else}stdcall{$ENDIF};
    function _Release : longint;{$IFNDEF WINDOWS}cdecl{$else}stdcall{$ENDIF};
  end;

var
  tb0571_called: Boolean = False;

function tb0571_ttest.QueryInterface(constref IID: TGUID; out Obj): Hresult; {$IFNDEF WINDOWS}cdecl{$else}stdcall{$ENDIF};
begin
  tb0571_called := true;
  if getinterface(iid,obj) then
   result:=S_OK
  else
   result:=longint(E_NOINTERFACE);
end;

function tb0571_ttest._AddRef : longint;{$IFNDEF WINDOWS}cdecl{$else}stdcall{$ENDIF};
begin
  Inc(tb0571_refcount);
  result := tb0571_refcount;
end;

function tb0571_ttest._Release : longint;{$IFNDEF WINDOWS}cdecl{$else}stdcall{$ENDIF};
begin
  Dec(tb0571_refcount);
  result := tb0571_refcount;
end;

var
  tb0571_r: tb0571_ttest;
  tb0571_i: tb0571_itest;

procedure tb0571_get(out obj: tb0571_itest);
begin
  obj := tb0571_r as tb0571_itest;
end;
{$pop}

begin
  { Case tw11862.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw11862_e := tw11862_ttest.Create;
  WriteLn('Calling GetChild');
  tw11862_test:=testgetchild;
  tw11862_e.tw11862_getchild();
  tw11862_test:=testparentex;
  tw11862_e.tw11862_parent;
  tw11862_test:=testparent;
  tw11862_e2:=tw11862_e;
  tw11862_e2.tw11862_parent;
  WriteLn('Stop');
  end;
  {$pop}

  { Case tw14092.pp }
  {$push}

  begin
tw14092_obj:=tw14092_tobj.create;
  tw14092_obj.tw14092_fintf:=tw14092_tintf.create;
  tw14092_refs:=1;
  tw14092_obj.tw14092_test1;
  tw14092_refs:=3;
  tw14092_obj.tw14092_test2;
  tw14092_obj.free;
  writeln('ok');
  end;
  {$pop}

  { Case tw8018.pp }
  {$push}

  begin
tw8018_t := tw8018_ttest.create();
  tw8018_t.tw8018_foo();
  if tw8018_i<>1 then
    tw8018_err:=true;
  tw8018_t.tw8018_foo(tw8018_a);
  if tw8018_i<>2 then
    tw8018_err:=true;
  tw8018_t.tw8018_bar();
  if tw8018_i<>3 then
    tw8018_err:=true;
  tw8018_t.tw8018_bar(tw8018_a);
  if tw8018_i<>4 then
    tw8018_err:=true;
  tw8018_t := nil;
  if tw8018_err then
    halt(1);
  end;
  {$pop}

  { Case tb0571.pp }
  {$push}
{$mode delphi}
begin
  tb0571_r := tb0571_ttest.Create;
  tb0571_r._AddRef;

  if not supports(tb0571_r, tb0571_itest, tb0571_i) or not tb0571_called or (tb0571_r.tb0571_refcount<>2) then
    Halt(1);
  tb0571_called := false;
  tb0571_i := nil;

  tb0571_get(tb0571_i);
  if (tb0571_i=nil) or not tb0571_called or (tb0571_r.tb0571_refcount<>2) then
    Halt(1);
  tb0571_i := nil;

  tb0571_r._Release;
end;
  {$pop}

end.
