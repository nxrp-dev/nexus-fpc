{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tw1203.pp }
{$push}
{ Source provided for Free Pascal Bug Report 1203 }
{ Submitted by "Marco van de Voort" on  2000-10-29 }
{ e-mail: marco@freepascal.org }

type
     tw1203_someprocedureofobjectype=procedure (sender:tobject) OF OBJECT;
     tw1203_a=class
     protected
        fondisplay : tw1203_someprocedureofobjectype;
     public
        tw1203_a:longint;
     end;

     tw1203_b=class(tw1203_A)
     protected
        fondisplay : tw1203_someprocedureofobjectype;
     public
        tw1203_a:longint;
     end;


{$pop}

{ Case tw2421.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2421 }
{ Submitted by "N. Hug" on  2003-03-16 }
{ e-mail: hug__@t-online.de }


{$ifdef fpc}{$endif}

TYPE  tw2421_TTestEvent =PROCEDURE OF OBJECT;

TYPE  tw2421_TTest      =CLASS
                    FOnTest   :tw2421_TTestEvent;
                    PROPERTY OnTest:tw2421_TTestEvent READ FOnTest WRITE FOnTest;
                  END;


TYPE  tw2421_THost      =CLASS
                  PRIVATE
                    FTest :tw2421_TTest;
                    PROCEDURE DoTest;

                  PUBLIC
                    CONSTRUCTOR Create;
                  END;


PROCEDURE tw2421_THost.DoTest;
BEGIN
  // Accessing instance data results in a crash.
  // It shows that SELF is not properly set.
  IF FTest = NIL THEN begin
  END;
END;


CONSTRUCTOR tw2421_THost.Create;
BEGIN
  INHERITED;

  FTest := tw2421_TTest.Create;

  // Buggy code:
  FTest.OnTest := DoTest;

  // Non buggy alternatives:
  // FTest.OnTest  := SELF.DoTest;
  // FTest.FOnTest := DoTest;

  // Now call it.
  FTest.OnTest;
END;



VAR  tw2421_M     :tw2421_THost;


{$pop}

{ Case tw24844a.pp }
{$push}


{.$mode objfpc}


Type

 { TObj }

 tw24844a_TObj = Class
   procedure Test;
 end;

{ TObj }

procedure tw24844a_TObj.Test;
Var

 proc : procedure of object;

begin

  proc := {$IFNDEF FPC_DELPHI}@{$ENDIF}TObject.Create.Free;
  WriteLn('Expected TObject actual: ', TObject(TMethod(Proc).Data).ClassName);
  if TObject(TMethod(Proc).Data).ClassName<>'TObject' then
    halt(1);
end;

procedure tw24844a_UncompilableProc;
Var

 proc : procedure of object;

begin

  proc := {$IFNDEF FPC_DELPHI}@{$ENDIF}TObject.Create.Free; // uncompilable in FPC mode
  WriteLn('Expected TObject actual: ', TObject(TMethod(Proc).Data).ClassName);
  if TObject(TMethod(Proc).Data).ClassName<>'TObject' then
    halt(2);
end;


{$pop}

{ Case thlp46.pp }
{$push}
{ helpers can extend type parameters if they can only be records }


{$ifdef fpc}
  
{$endif}

type
  thlp46_TFoo<T: record> = class
  type
    THelper = record helper for T
    end;
  end;

  thlp46_TBar = record
    f: LongInt;
  end;

type
  thlp46_TFooTBar = thlp46_TFoo<thlp46_TBar>;


{$pop}

{ Case tprocvar16.pp }
{$push}




type tprocvar16_C = class
    class procedure Foo;
end;
class procedure tprocvar16_C.Foo; begin end;

type tprocvar16_CC = class of tprocvar16_C;

var tprocvar16_Z: procedure of object;

{$pop}

begin

{ Case tw1203.pp }
{$push}

begin
end;
{$pop}

{ Case tw2421.pp }
{$push}
{$ifdef fpc}

{$endif}
BEGIN
  tw2421_M := tw2421_THost.Create;
  tw2421_M.Free;
END;
{$pop}

{ Case tw24844a.pp }
{$push}

{$IFNDEF FPC_DELPHI}
{$ENDIF}
{$IFNDEF FPC_DELPHI}
{$ENDIF}
begin

  WriteLn('Mode: ', {$IFDEF FPC_DELPHI}'delphi'{$ELSE}'objfpc'{$ENDIF});

  tw24844a_TObj.Create.Test;
  tw24844a_UncompilableProc;

end;
{$pop}

{ Case thlp46.pp }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

{ Case tprocvar16.pp }
{$push}

begin
    tprocvar16_Z := tprocvar16_CC.Foo;
    if TMethod(tprocvar16_Z).Code <> @tprocvar16_C.Foo then
      Halt(1);
    if TMethod(tprocvar16_Z).Data <> Pointer(tprocvar16_C) then
      Halt(2);
end;
{$pop}

end.
