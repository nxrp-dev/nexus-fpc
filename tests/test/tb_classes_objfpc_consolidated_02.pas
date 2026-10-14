{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tabstract1.pas }
{$push}
{$ifdef fpc}

{$endif fpc}
type
  tabstract1_TAbstractClass = class abstract
  public
    procedure Test; virtual;
  end;

  tabstract1_TAbstractClassDescendant = class(tabstract1_TAbstractClass)
  public
    procedure Test; override;
  end;

  tabstract1_TSealedClass = class sealed
  public
    procedure Test;
  end;

procedure tabstract1_TAbstractClass.Test;
begin
end;

procedure tabstract1_TAbstractClassDescendant.Test;
begin
end;

procedure tabstract1_TSealedClass.Test;
begin
end;

var
  tabstract1_AClass: tabstract1_TAbstractClass;
  tabstract1_AClassDesc: tabstract1_TAbstractClassDescendant;
  tabstract1_SClass: tabstract1_TSealedClass;

{$pop}

{ Case tarray1.pas }
{$push}

type
   tarray1_tc1 = class
   end;

   tarray1_tc2 = class(tarray1_tc1)
   end;

   tarray1_tcoc1 = class of tarray1_tc1;
   tarray1_tcoc2 = class of tarray1_tc2;

procedure tarray1_p(const a : array of tarray1_tcoc1);

  begin
  end;


{$pop}

{ Case tarrconstr7.pas }
{$push}




type
  tarrconstr7_TTest = class(TInterfacedObject, IInterface)
    function _AddRef : longint;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    function _Release : longint;{$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
  end;

var
  tarrconstr7_gRefCount: LongInt = 0;

function tarrconstr7_TTest._AddRef: LongInt; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  Result := inherited _AddRef;
  tarrconstr7_gRefCount := Result;
end;

function tarrconstr7_TTest._Release: LongInt; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
begin
  Result := inherited _Release;
  tarrconstr7_gRefCount := Result;
end;

procedure tarrconstr7_TestArrConstr(const aIntf: IInterface);
var
  a: array of IInterface;
begin
  a := [aIntf];
  a := Nil;
end;

procedure tarrconstr7_Test;
var
  t: IInterface;
  c: LongInt;
begin
  t := tarrconstr7_TTest.Create;

  c := tarrconstr7_gRefCount;
  tarrconstr7_TestArrConstr(t);
  if tarrconstr7_gRefCount <> c then
    Halt(1);
end;


{$pop}

{ Case tchlp59.pas }
{$push}




type
  tchlp59_TTest = class
    function Test: LongInt; virtual;
  end;

  tchlp59_TTestSub = class(tchlp59_TTest)
    function Test: LongInt; override;
  end;

  tchlp59_TTestHelper = class helper for tchlp59_TTest
    function Test: LongInt;
  end;

function tchlp59_TTestHelper.Test: LongInt;
begin
  Result := inherited Test * 10;
end;

function tchlp59_TTestSub.Test: LongInt;
begin
  Result := 2;
end;

function tchlp59_TTest.Test: LongInt;
begin
  Result := 1;
end;

var
  tchlp59_t: tchlp59_TTest;

{$pop}

{ Case tclass1.pas }
{$push}


type
   tclass1_to1 = class
      constructor create;
      procedure afterconstruction;override;
   end;

   tclass1_to2 = class(tclass1_to1)
      constructor create;
      procedure afterconstruction;override;
   end;

var
   tclass1_i : longint;

   constructor tclass1_to1.create;

     begin
        writeln('to1.create');
        inherited create;
        if tclass1_i<>1000 then
          halt(1);
        tclass1_i:=2000;
     end;

   constructor tclass1_to2.create;

     begin
        writeln('to2.create');
        if tclass1_i<>3000 then
          halt(1);
        tclass1_i:=1000;
        inherited create;
        tclass1_i:=4000;
     end;

   procedure tclass1_to1.afterconstruction;

     begin
        writeln('to1.afterconstruction');
        if tclass1_i<>2000 then
          halt(1);
        tclass1_i:=3000;
     end;

   procedure tclass1_to2.afterconstruction;

     begin
        writeln('to2.afterconstruction');
        if tclass1_i<>4000 then
          halt(1);
        tclass1_i:=5000;
     end;

var
   tclass1_o1 : tclass1_to1;
   tclass1_o2 : tclass1_to2;

{$pop}

{ Case tclass2.pas }
{$push}


type
   tclass2_to1 = class
      destructor destroy;override;
      procedure beforedestruction;override;
   end;

   tclass2_to2 = class(tclass2_to1)
      destructor destroy;override;
      procedure beforedestruction;override;
   end;

var
   tclass2_i : longint;

   destructor tclass2_to1.destroy;

     begin
        writeln('to1.destroy');
        if tclass2_i<>2000 then
          halt(1);
        tclass2_i:=3000;
        inherited destroy;
     end;

   procedure tclass2_to1.beforedestruction;

     begin
        writeln('to1.beforedestruction');
        if tclass2_i<>1000 then
          halt(1);
        tclass2_i:=2000;
     end;

   destructor tclass2_to2.destroy;

     begin
        writeln('to2.destroy');
        if tclass2_i<>4000 then
          halt(1);
        tclass2_i:=2000;
        inherited destroy;
        tclass2_i:=5000;
     end;

   procedure tclass2_to2.beforedestruction;

     begin
        writeln('to2.beforedestruction');
        if tclass2_i<>3000 then
          halt(1);
        tclass2_i:=4000;
     end;

var
   tclass2_o1 : tclass2_to1;
   tclass2_o2 : tclass2_to2;

{$pop}

{ Case thlp45.pas }
{$push}
{ this tests that the correct method is called if a helper overloads an
  existing function and calls the original one recursively }


{$H+}

type
  thlp45_TTest = class
    function Test(aRecurse: Boolean; aTest: String): Integer;
  end;

  thlp45_TTestHelper = class helper for thlp45_TTest
    function Test(aRecurse: Boolean; aTest: array of String): Integer; overload;
  end;

function thlp45_TTest.Test(aRecurse: Boolean; aTest: String): Integer;
begin
  Result := 1;
end;

function thlp45_TTestHelper.Test(aRecurse: Boolean; aTest: array of String): Integer;
begin
  if aRecurse then
    Result := Test(False, aTest[0])
  else
    Result := 2;
end;

var
  thlp45_t: thlp45_TTest;
  thlp45_res: Integer;

{$pop}

{ Case tobject4.pas }
{$push}

type
  tobject4_to1 = class
    a1 : array[0..100] of byte;
    s1 : ansistring;
    a2 : array[0..100] of byte;
    s2 : ansistring;
    s3 : ansistring;
  end;

var
  tobject4_o1 : tobject4_to1;


{$pop}

{ Case tsealed4.pas }
{$push}
{$ifdef fpc}

{$endif}

type
  tsealed4_TAbstractClass = class abstract abstract abstract
  public
  end;

  tsealed4_TSealedClass = class sealed sealed sealed
  public
  end;

{$pop}

begin

{ Case tabstract1.pas }
{$push}
{$ifdef fpc}

{$endif fpc}
begin
  tabstract1_AClass := tabstract1_TAbstractClass.Create;
  tabstract1_AClass.Test;
  tabstract1_AClass.Free;

  tabstract1_AClassDesc:= tabstract1_TAbstractClassDescendant.Create;
  tabstract1_AClassDesc.Test;
  tabstract1_AClassDesc.Free;

  tabstract1_SClass := tabstract1_TSealedClass.Create;
  tabstract1_SClass.Test;
  tabstract1_SClass.Free;
end;
{$pop}

{ Case tarray1.pas }
{$push}

begin
   tarray1_p([tarray1_tc2]);
end;
{$pop}

{ Case tarrconstr7.pas }
{$push}

{$IFNDEF WINDOWS}
{$ELSE}
{$ENDIF}
{$IFNDEF WINDOWS}
{$ELSE}
{$ENDIF}
{$IFNDEF WINDOWS}
{$ELSE}
{$ENDIF}
{$IFNDEF WINDOWS}
{$ELSE}
{$ENDIF}
begin
  tarrconstr7_Test;
  if tarrconstr7_gRefCount <> 0 then
    Halt(2);
end;
{$pop}

{ Case tchlp59.pas }
{$push}

begin
  tchlp59_t := tchlp59_TTestSub.Create;
  if tchlp59_t.Test <> 20 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tclass1.pas }
{$push}

begin
   tclass1_i:=1000;
   tclass1_o1:=tclass1_to1.create;
   tclass1_o2:=tclass1_to2.create;
   if tclass1_i<>5000 then
     halt(1);
   tclass1_o1.destroy;
   writeln('ok');
end;
{$pop}

{ Case tclass2.pas }
{$push}

begin
   tclass2_o1:=tclass2_to1.create;
   tclass2_o2:=tclass2_to2.create;
   tclass2_i:=1000;
   tclass2_o1.destroy;
   tclass2_o2.destroy;
   if tclass2_i<>5000 then
     halt(1);
   writeln('ok');
end;
{$pop}

{ Case thlp45.pas }
{$push}

{$H+}
begin
  thlp45_t := thlp45_TTest.Create;
  thlp45_res := thlp45_t.Test(True, ['Test']);
  Writeln('t.Test: ', thlp45_res);
  if thlp45_res <> 1 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tobject4.pas }
{$push}

begin
  tobject4_o1:=tobject4_to1.create;
  tobject4_o1.destroy;
end;
{$pop}

{ Case tsealed4.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

end.
