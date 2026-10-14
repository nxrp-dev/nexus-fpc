{ Consolidated interfaces regressions; original case IDs and assertions are retained. }
{ %VERSION=1.1 }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tw2041.pas }
{$push}



type
  tw2041_ITest = interface
    procedure Put(Key: Integer; Item: IUnknown);
    function Get(Key: Integer): IUnknown;
    property Item[Key: Integer]: IUnknown read Get write Put; default;
  end;


{$pop}

{ Case tinterface10.pas }
{$push}


{$ifdef fpc}

{$endif}

type
  tinterface10_ITest = interface(IUnknown)
    procedure DoSomething;
  end;


  tinterface10_TMyClass = class(TInterfacedObject, tinterface10_ITest)
    procedure MyDoSomething;
    procedure tinterface10_ITest.DoSomething = MyDoSomething;
  end;

var
   tinterface10_i : longint;

procedure tinterface10_TMyClass.MyDoSomething;
begin
  inc(tinterface10_i);
end;


procedure tinterface10_DoTest(const ATest: tinterface10_ITest);
begin
  ATest.DoSomething;
end;


procedure tinterface10_DoTest2(ATest: tinterface10_ITest);
begin
  ATest.DoSomething;
end;

type tinterface10_TMyClassCopy = type tinterface10_TMyClass;


var
  tinterface10_c: tinterface10_ITest;

{$pop}

{ Case tinterface8.pas }
{$push}


{$ifdef fpc}

{$endif}

type
  tinterface8_ITest = interface(IUnknown)
    procedure DoSomething;
  end;


  tinterface8_TMyClass = class(TInterfacedObject, tinterface8_ITest)
    procedure DoSomething;
  end;

var
   tinterface8_i : longint;

procedure tinterface8_TMyClass.DoSomething;
begin
  inc(tinterface8_i);
end;


procedure tinterface8_DoTest(const ATest: tinterface8_ITest);
begin
  ATest.DoSomething;
end;


procedure tinterface8_DoTest2(ATest: tinterface8_ITest);
begin
  ATest.DoSomething;
end;

type tinterface8_TMyClassCopy = type tinterface8_TMyClass;


var
  tinterface8_c: tinterface8_ITest;

{$pop}

begin

{ Case tw2041.pas }
{$push}

begin
end;
{$pop}

{ Case tinterface10.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tinterface10_i:=0;
  tinterface10_c := tinterface10_TMyClassCopy.Create;
  tinterface10_DoTest(tinterface10_c);
  tinterface10_DoTest2(tinterface10_c);
  if tinterface10_i<>2 then
    begin
       writeln('Problem with passing interfaces as parameters');
       halt(1);
    end;
end;
{$pop}

{ Case tinterface8.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tinterface8_i:=0;
  tinterface8_c := tinterface8_TMyClassCopy.Create;
  tinterface8_DoTest(tinterface8_c);
  tinterface8_DoTest2(tinterface8_c);
  if tinterface8_i<>2 then
    begin
       writeln('Problem with passing interfaces as parameters');
       halt(1);
    end;
end;
{$pop}

end.
