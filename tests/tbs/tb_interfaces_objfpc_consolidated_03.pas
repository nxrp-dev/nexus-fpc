{ Consolidated interfaces regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tw29086.pas }
{$push}


{$h+}

type
  tw29086_ITestInt = interface
    function GetN(a:Integer):Integer;
    function GetX(a:Integer):Integer;
  end;

  { TIntTest }

  tw29086_TIntTest = class(TInterfacedObject,tw29086_ITestInt)
    function GetN(a: Integer): Integer;
    function GetX(a: Integer): Integer;
  end;

  tw29086_TIntTestVal = record
    FTestInt : tw29086_ITestInt;
  end;

  tw29086_TIntTestFunc = function(a:Integer):Integer of object;

  tw29086_TIntTestInclude = class
    FValue : tw29086_TIntTestVal;
  end;

  tw29086_ttestobj = object
    a, b : tw29086_TIntTestFunc;
  end;

var
  tw29086_inttest : tw29086_TIntTest;
  tw29086_inttestvalinc : tw29086_TIntTestInclude;
  tw29086_x : tw29086_ttestobj;

{ TIntTest }

function tw29086_TIntTest.GetN(a: Integer): Integer;
begin
  Result:=a+1;
end;

function tw29086_TIntTest.GetX(a: Integer): Integer;
begin
  Result:=a+2;
end;



{$pop}

{ Case tb0111.pas }
{$push}
{$ifdef fpc}{$endif}

type
   tb0111_imyinterface2 = interface
      procedure p;
   end;

const
   tb0111_iid_imyinterface2 = tb0111_imyinterface2;


{$pop}

{ Case tb_interfaces_objfpc_consolidated_02.pas }
{$push}
{ Consolidated interfaces regressions; original case IDs and assertions are retained. }



{ Case tinterface2.pas }
{$push}

{$ifdef fpc}

{$endif}

type
  tb_interfaces_objfpc_consolidated_02_tinterface2_ITest = interface(IUnknown)
    procedure DoSomething;
  end;


  tb_interfaces_objfpc_consolidated_02_tinterface2_TMyClass = class(TInterfacedObject, tb_interfaces_objfpc_consolidated_02_tinterface2_ITest)
    procedure DoSomething;
  end;

var
   tb_interfaces_objfpc_consolidated_02_tinterface2_i : longint;

procedure tb_interfaces_objfpc_consolidated_02_tinterface2_TMyClass.DoSomething;
begin
  inc(tb_interfaces_objfpc_consolidated_02_tinterface2_i);
end;


procedure tb_interfaces_objfpc_consolidated_02_tinterface2_DoTest(const ATest: tb_interfaces_objfpc_consolidated_02_tinterface2_ITest);
begin
  ATest.DoSomething;
end;


procedure tb_interfaces_objfpc_consolidated_02_tinterface2_DoTest2(ATest: tb_interfaces_objfpc_consolidated_02_tinterface2_ITest);
begin
  ATest.DoSomething;
end;


var
  tb_interfaces_objfpc_consolidated_02_tinterface2_c: tb_interfaces_objfpc_consolidated_02_tinterface2_ITest;

{$pop}

{ Case tintfcdecl1.pas }
{$push}


{$H+}

type
  tb_interfaces_objfpc_consolidated_02_tintfcdecl1_IcdeclIntf = interface
  ['{3C409C8B-3A15-44B2-B22D-6BAA2071CAAD}']
    function DoSomething : longint; cdecl;
  end;

  { TcdeclClass }

  tb_interfaces_objfpc_consolidated_02_tintfcdecl1_TcdeclClass = class(TInterfacedObject,tb_interfaces_objfpc_consolidated_02_tintfcdecl1_IcdeclIntf)
  private
    FCounter: integer;
  public
    function DoSomething : longint; cdecl;
  end;

{ TcdeclClass }

function tb_interfaces_objfpc_consolidated_02_tintfcdecl1_TcdeclClass.DoSomething: longint; cdecl;
begin
  inc(FCounter);
  result := FCounter;
end;

var
  tb_interfaces_objfpc_consolidated_02_tintfcdecl1_js: tb_interfaces_objfpc_consolidated_02_tintfcdecl1_TcdeclClass;
  tb_interfaces_objfpc_consolidated_02_tintfcdecl1_ji: tb_interfaces_objfpc_consolidated_02_tintfcdecl1_IcdeclIntf;
  tb_interfaces_objfpc_consolidated_02_tintfcdecl1_i: longint;

{$pop}

{ Case tintfcdecl2.pas }
{$push}


{$H+}

type
  tb_interfaces_objfpc_consolidated_02_tintfcdecl2_IcdeclIntf = interface
  ['{3C409C8B-3A15-44B2-B22D-6BAA2071CAAD}']
    function DoSomething : longint; cdecl;
  end;

  { TcdeclClass }

  tb_interfaces_objfpc_consolidated_02_tintfcdecl2_TcdeclClass = class(TInterfacedObject,tb_interfaces_objfpc_consolidated_02_tintfcdecl2_IcdeclIntf)
  private
    FCounter: integer;
  public
    function DoSomething : longint; cdecl; virtual;
  end;

{ TcdeclClass }

function tb_interfaces_objfpc_consolidated_02_tintfcdecl2_TcdeclClass.DoSomething: longint; cdecl;
begin
  inc(FCounter);
  result := FCounter;
end;

var
  tb_interfaces_objfpc_consolidated_02_tintfcdecl2_js: tb_interfaces_objfpc_consolidated_02_tintfcdecl2_TcdeclClass;
  tb_interfaces_objfpc_consolidated_02_tintfcdecl2_ji: tb_interfaces_objfpc_consolidated_02_tintfcdecl2_IcdeclIntf;
  tb_interfaces_objfpc_consolidated_02_tintfcdecl2_i: longint;

{$pop}


{$pop}

{ Case tinterface3.pas }
{$push}


type
  tinterface3_IMyInterface = interface
    function f : longint;
    procedure p(a : longint);
    property x : longint read f write p;
  end;


{$pop}

begin

{ Case tw29086.pas }
{$push}

{$h+}
begin
  tw29086_inttest:=tw29086_TIntTest.Create;
  tw29086_inttestvalinc:=tw29086_TIntTestInclude.Create;
  tw29086_inttestvalinc.FValue.FTestInt:=tw29086_inttest;
  tw29086_x.a := @tw29086_inttestvalinc.FValue.FTestInt.GetN;
  tw29086_x.b := @tw29086_inttestvalinc.FValue.FTestInt.GetX;
  writeln(tw29086_x.a(1));
  writeln(tw29086_x.b(1));
end;
{$pop}

{ Case tb0111.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tb_interfaces_objfpc_consolidated_02.pas }
{$push}

{$push}
{$ifdef fpc}
{$endif}
{$pop}
{$push}
{$H+}
{$pop}
{$push}
{$H+}
{$pop}
begin

{ Case tinterface2.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tb_interfaces_objfpc_consolidated_02_tinterface2_i:=0;
  tb_interfaces_objfpc_consolidated_02_tinterface2_c := tb_interfaces_objfpc_consolidated_02_tinterface2_TMyClass.Create;
  tb_interfaces_objfpc_consolidated_02_tinterface2_DoTest(tb_interfaces_objfpc_consolidated_02_tinterface2_c);
  tb_interfaces_objfpc_consolidated_02_tinterface2_DoTest2(tb_interfaces_objfpc_consolidated_02_tinterface2_c);
  if tb_interfaces_objfpc_consolidated_02_tinterface2_i<>2 then
    begin
       writeln('Problem with passing interfaces as parameters');
       halt(1);
    end;
end;
{$pop}

{ Case tintfcdecl1.pas }
{$push}

{$H+}
begin
  tb_interfaces_objfpc_consolidated_02_tintfcdecl1_js := tb_interfaces_objfpc_consolidated_02_tintfcdecl1_TcdeclClass.Create;

  tb_interfaces_objfpc_consolidated_02_tintfcdecl1_i := tb_interfaces_objfpc_consolidated_02_tintfcdecl1_js.DoSomething;

  tb_interfaces_objfpc_consolidated_02_tintfcdecl1_ji := tb_interfaces_objfpc_consolidated_02_tintfcdecl1_IcdeclIntf(tb_interfaces_objfpc_consolidated_02_tintfcdecl1_js);
  tb_interfaces_objfpc_consolidated_02_tintfcdecl1_i := tb_interfaces_objfpc_consolidated_02_tintfcdecl1_ji.DoSomething;

  if tb_interfaces_objfpc_consolidated_02_tintfcdecl1_i <> 2 then halt(1);
end;
{$pop}

{ Case tintfcdecl2.pas }
{$push}

{$H+}
begin
  tb_interfaces_objfpc_consolidated_02_tintfcdecl2_js := tb_interfaces_objfpc_consolidated_02_tintfcdecl2_TcdeclClass.Create;

  tb_interfaces_objfpc_consolidated_02_tintfcdecl2_i := tb_interfaces_objfpc_consolidated_02_tintfcdecl2_js.DoSomething;

  tb_interfaces_objfpc_consolidated_02_tintfcdecl2_ji := tb_interfaces_objfpc_consolidated_02_tintfcdecl2_IcdeclIntf(tb_interfaces_objfpc_consolidated_02_tintfcdecl2_js);
  tb_interfaces_objfpc_consolidated_02_tintfcdecl2_i := tb_interfaces_objfpc_consolidated_02_tintfcdecl2_ji.DoSomething;

  if tb_interfaces_objfpc_consolidated_02_tintfcdecl2_i <> 2 then halt(1);
end;
{$pop}

end;
{$pop}

{ Case tinterface3.pas }
{$push}

begin
end;
{$pop}

end.
