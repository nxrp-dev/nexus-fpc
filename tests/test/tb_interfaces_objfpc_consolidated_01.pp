{ Consolidated interfaces regressions; original case IDs and assertions are retained. }
{ %SKIPTARGET=macos }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tinterface1.pp }
{$push}

{ On macos it crashes when run.}


type
  tinterface1_IInterface = interface(IUnknown)
     procedure mydo;
  end;

  tinterface1_TMyClass = class(TInterfacedObject, tinterface1_IInterface)
     procedure mydo;virtual;
  end;

  tinterface1_TMyClass2 = class(tinterface1_TMyClass)
     tinterface1_i : integer;
  end;

var
   tinterface1_l : longint;

procedure tinterface1_tmyclass.mydo;

  begin
     tinterface1_l:=1;
  end;

var
  tinterface1_c: tinterface1_TMyClass;
  tinterface1_i: tinterface1_IInterface;
  tinterface1_c2 : tinterface1_TMyClass;


{$pop}

{ Case tinterface5.pp }
{$push}

{ On macos it crashes when run.}


type
  tinterface5_IInterface = interface(IUnknown)
     procedure mydo;
  end;

  tinterface5_TMyClass = class(TInterfacedObject, tinterface5_IInterface)
     procedure mydo;virtual;
  end;

  tinterface5_TMyClass2 = class(tinterface5_TMyClass)
     i : integer;
  end;

  tinterface5_TMyClass3 = class
    private
      fi: tinterface5_IInterface;
    public
      property intf: tinterface5_IInterface read fi write fi;
  end;



var
   tinterface5_l : longint;

procedure tinterface5_tmyclass.mydo;

  begin
     tinterface5_l:=1;
  end;

var
  tinterface5_c: tinterface5_TMyClass;
  tinterface5_c2 : tinterface5_TMyClass;
  tinterface5_c3 : tinterface5_TMyClass3;


{$pop}

{ Case tinterface7.pp }
{$push}

{ On macos it crashes when run.}


type
  tinterface7_IInterface = interface(IUnknown)
     procedure mydo;
  end;

  tinterface7_TMyClass = class(TInterfacedObject, tinterface7_IInterface)
     procedure mydo;virtual;
  end;

  tinterface7_TMyClass2 = class(tinterface7_TMyClass)
     tinterface7_i : integer;
  end;

  tinterface7_TMyClass2Copy = type tinterface7_TMyClass2;

var
   tinterface7_l : longint;

procedure tinterface7_tmyclass.mydo;

  begin
     tinterface7_l:=1;
  end;

var
  tinterface7_c: tinterface7_TMyClass;
  tinterface7_i: tinterface7_IInterface;
  tinterface7_c2 : tinterface7_TMyClass;


{$pop}

begin

{ Case tinterface1.pp }
{$push}

begin
  tinterface1_c := tinterface1_TMyClass.Create;
  tinterface1_i := tinterface1_c;
  tinterface1_l:=0;
  tinterface1_i.mydo;
  if tinterface1_l<>1 then
    halt(1);
  tinterface1_c2 := tinterface1_TMyClass2.Create;
  tinterface1_i := tinterface1_c2;
  tinterface1_l:=0;
  tinterface1_i.mydo;
  if tinterface1_l<>1 then
    halt(1);
end;
{$pop}

{ Case tinterface5.pp }
{$push}

begin
  tinterface5_c := tinterface5_TMyClass.Create;
  tinterface5_c3 := tinterface5_TMyClass3.Create;
  tinterface5_c3.intf := tinterface5_c;
  tinterface5_l:=0;
  tinterface5_c3.intf.mydo;
  if tinterface5_l<>1 then
    halt(1);
  tinterface5_c2 := tinterface5_TMyClass2.Create;
  tinterface5_c3.intf := tinterface5_c2;
  tinterface5_l:=0;
  tinterface5_c3.intf.mydo;
  if tinterface5_l<>1 then
    halt(1);
  tinterface5_c3.free;
end;
{$pop}

{ Case tinterface7.pp }
{$push}

begin
  tinterface7_c := tinterface7_TMyClass.Create;
  tinterface7_i := tinterface7_c;
  tinterface7_l:=0;
  tinterface7_i.mydo;
  if tinterface7_l<>1 then
    halt(1);
  tinterface7_c2 := tinterface7_TMyClass2Copy.Create;
  tinterface7_i := tinterface7_c2;
  tinterface7_l:=0;
  tinterface7_i.mydo;
  if tinterface7_l<>1 then
    halt(1);
end;
{$pop}

end.
