{ Interfaces regression cases; original case IDs are retained below. }

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

end.
