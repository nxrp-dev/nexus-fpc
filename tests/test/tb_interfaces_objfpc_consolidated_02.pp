{ Consolidated interfaces regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tinterface2.pp }
{$push}

{$ifdef fpc}

{$endif}

type
  tinterface2_ITest = interface(IUnknown)
    procedure DoSomething;
  end;


  tinterface2_TMyClass = class(TInterfacedObject, tinterface2_ITest)
    procedure DoSomething;
  end;

var
   tinterface2_i : longint;

procedure tinterface2_TMyClass.DoSomething;
begin
  inc(tinterface2_i);
end;


procedure tinterface2_DoTest(const ATest: tinterface2_ITest);
begin
  ATest.DoSomething;
end;


procedure tinterface2_DoTest2(ATest: tinterface2_ITest);
begin
  ATest.DoSomething;
end;


var
  tinterface2_c: tinterface2_ITest;

{$pop}

{ Case tintfcdecl1.pp }
{$push}


{$H+}

type
  tintfcdecl1_IcdeclIntf = interface
  ['{3C409C8B-3A15-44B2-B22D-6BAA2071CAAD}']
    function DoSomething : longint; cdecl;
  end;

  { TcdeclClass }

  tintfcdecl1_TcdeclClass = class(TInterfacedObject,tintfcdecl1_IcdeclIntf)
  private
    FCounter: integer;
  public
    function DoSomething : longint; cdecl;
  end;

{ TcdeclClass }

function tintfcdecl1_TcdeclClass.DoSomething: longint; cdecl;
begin
  inc(FCounter);
  result := FCounter;
end;

var
  tintfcdecl1_js: tintfcdecl1_TcdeclClass;
  tintfcdecl1_ji: tintfcdecl1_IcdeclIntf;
  tintfcdecl1_i: longint;

{$pop}

{ Case tintfcdecl2.pp }
{$push}


{$H+}

type
  tintfcdecl2_IcdeclIntf = interface
  ['{3C409C8B-3A15-44B2-B22D-6BAA2071CAAD}']
    function DoSomething : longint; cdecl;
  end;

  { TcdeclClass }

  tintfcdecl2_TcdeclClass = class(TInterfacedObject,tintfcdecl2_IcdeclIntf)
  private
    FCounter: integer;
  public
    function DoSomething : longint; cdecl; virtual;
  end;

{ TcdeclClass }

function tintfcdecl2_TcdeclClass.DoSomething: longint; cdecl;
begin
  inc(FCounter);
  result := FCounter;
end;

var
  tintfcdecl2_js: tintfcdecl2_TcdeclClass;
  tintfcdecl2_ji: tintfcdecl2_IcdeclIntf;
  tintfcdecl2_i: longint;

{$pop}

begin

{ Case tinterface2.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tinterface2_i:=0;
  tinterface2_c := tinterface2_TMyClass.Create;
  tinterface2_DoTest(tinterface2_c);
  tinterface2_DoTest2(tinterface2_c);
  if tinterface2_i<>2 then
    begin
       writeln('Problem with passing interfaces as parameters');
       halt(1);
    end;
end;
{$pop}

{ Case tintfcdecl1.pp }
{$push}

{$H+}
begin
  tintfcdecl1_js := tintfcdecl1_TcdeclClass.Create;

  tintfcdecl1_i := tintfcdecl1_js.DoSomething;

  tintfcdecl1_ji := tintfcdecl1_IcdeclIntf(tintfcdecl1_js);
  tintfcdecl1_i := tintfcdecl1_ji.DoSomething;

  if tintfcdecl1_i <> 2 then halt(1);
end;
{$pop}

{ Case tintfcdecl2.pp }
{$push}

{$H+}
begin
  tintfcdecl2_js := tintfcdecl2_TcdeclClass.Create;

  tintfcdecl2_i := tintfcdecl2_js.DoSomething;

  tintfcdecl2_ji := tintfcdecl2_IcdeclIntf(tintfcdecl2_js);
  tintfcdecl2_i := tintfcdecl2_ji.DoSomething;

  if tintfcdecl2_i <> 2 then halt(1);
end;
{$pop}

end.
