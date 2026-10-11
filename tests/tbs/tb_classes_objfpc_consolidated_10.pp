{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}
uses sysutils;

{ Case tw30706.pp }
{$push}
{$H+}



type
  tw30706_TMyMethod = procedure (A: Integer) of object;

  tw30706_TMyClass = class
    class procedure Foo(A: Integer);
  end;

class procedure tw30706_TMyClass.Foo(A: Integer);
begin
  Writeln('Got int ', A);
end;

procedure tw30706_CallMethod(M: tw30706_TMyMethod);
begin
  M(123);
end;


{$pop}

{ Case tw34380.pp }
{$push}
{ Code extracted from fpc-image fpcolhash unit }





type
  tw34380_PColHashMainNode = ^tw34380_TColHashMainNode;
  tw34380_TColHashMainNode = packed record
    childs : array[0..16] of pointer; { can be either another MainNode or a SubNode }
  end;

  tw34380_TFPColorHashTable = class (TObject)
    function AllocateMainNode : tw34380_PColHashMainNode;
  end;

function tw34380_TFPColorHashTable.AllocateMainNode : tw34380_PColHashMainNode;
var tmp : tw34380_PColHashMainNode;
    i : byte;
begin
  Result:=nil;
  tmp:=getmem(sizeof(tw34380_TColHashMainNode));
  if tmp=nil then raise Exception.Create('Out of memory');
  for i:=0 to high(tmp^.childs) do
    tmp^.childs[i]:=nil;
  Result:=tmp;
end;


{$pop}

{ Case tcall1.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{  By Carl Eric Codere                                           }
{****************************************************************}
{ NODE TESTED : secondcalln()                                    }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondtypeconv()                               }
{                 secondtryexcept()                              }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS: This tests secondcalln(), genentrycode() and          }
{ genexitcode().                                                 }
{                                                                }
{                                                                }
{****************************************************************}


{$ifdef fpc}{$endif}


{
class:
  class constructor
   1a  - success
   1b  - failure
  2 class destructor
  3 class method
  4 virtual method
  5 abstract method
  6 static method
object:
  object constructor
  7a  - success
  7b  - failure
  8 object destructor
  9 method
  10 virtual method
standard:
  11 function
  12 procedure
  13 procedure variable

modifiers:
  no parameters                    1a  1b
  parameters
     - const                       1a
     - value                       1a
     - variable                    1a
     - mixed                       1a

  explicit self parameter
  operator directive
  assembler directive
  interrupt directive
  inline directive
  cdecl directive
  pascal directive
  safecall directive
  stdcall directive
  oldfpcall directive
  register directive
}

const
  tcall1_GLOBAL_RESULT = $55;

var
 tcall1_globalresult : integer;
 tcall1_failed : boolean;

type

  tcall1_tclass1 = class
    constructor create_none;               { class constructor }
    constructor create_value(tcall1_l:longint;tcall1_b: byte);
    constructor create_var(var tcall1_l:longint;var tcall1_b: byte);
    constructor create_const(const tcall1_l:longint; const tcall1_b: byte);
    constructor create_mixed(var tcall1_a: byte; tcall1_b: byte; var tcall1_c: byte; const tcall1_d: byte);
  end;

  tcall1_tclass2 = class
    constructor create_none;               { class constructor }
  public
    tcall1_b: array[1..{$ifdef cpu16}32763{$else}$66666666{$endif}] of byte;
  end;


  constructor tcall1_tclass1.create_none;
   begin
     Inherited create;
     tcall1_globalresult:=tcall1_GLOBAL_RESULT;
   end;


  constructor tcall1_tclass1.create_value(tcall1_l:longint;tcall1_b: byte);
   begin
     Inherited create;
     tcall1_globalresult:=tcall1_b;
   end;

  constructor tcall1_tclass1.create_var(var tcall1_l:longint;var tcall1_b: byte);
    begin
     Inherited create;
      tcall1_b:=tcall1_GLOBAL_RESULT;
    end;

  constructor tcall1_tclass1.create_const(const tcall1_l:longint; const tcall1_b: byte);
    begin
     Inherited create;
      tcall1_globalresult := tcall1_GLOBAL_RESULT;
    end;

  constructor tcall1_tclass1.create_mixed(var tcall1_a: byte; tcall1_b: byte; var tcall1_c: byte; const tcall1_d: byte);
    begin
     Inherited create;
      tcall1_globalresult := tcall1_GLOBAL_RESULT;
    end;



  constructor tcall1_tclass2.create_none;
   begin
     Inherited create;
     { the next line will normally not be reached, else
       it's a failure }
     tcall1_globalresult:=0;
   end;



procedure tcall1_fail;
begin
  WriteLn('Failure.');
  halt(1);
end;


function tcall1_myheaperrornil(size : longint): integer;
  begin
    tcall1_myheaperrornil:=1;
  end;

function tcall1_myheaperrorexception(size : longint): integer;
  begin
    tcall1_myheaperrorexception:=0;
  end;

var
 tcall1_class_none: tcall1_tclass1;
 tcall1_class_value: tcall1_tclass1;
 tcall1_class_var: tcall1_tclass1;
 tcall1_class_const: tcall1_tclass1;
 tcall1_class_mixed: tcall1_tclass1;
 tcall1_class_none_fail : tcall1_tclass2;
 tcall1_a,tcall1_b,tcall1_c,tcall1_d: byte;
 tcall1_l:longint;

{$pop}

begin

{ Case tw30706.pp }
{$push}

{$H+}
begin
  tw30706_CallMethod({$ifdef FPC_OBJFPC} @ {$endif} tw30706_TMyClass(nil).Foo);
end;
{$pop}

{ Case tw34380.pp }
{$push}

begin
end;
{$pop}

{ Case tcall1.pp }
{$push}
{$ifdef fpc}

{$endif}
{$ifdef cpu16}
{$else}
{$endif}
Begin
  { reset test variables }
  tcall1_globalresult := 0;
  tcall1_failed := false;

  write('class constructor testing...');
  { secondcalln : class constructor success }
  tcall1_class_none:=tcall1_tclass1.create_none;
  if tcall1_globalresult <> tcall1_GLOBAL_RESULT then
    tcall1_failed:= true;

  tcall1_globalresult := 0;
  tcall1_class_value:=tcall1_tclass1.create_value(0,tcall1_GLOBAL_RESULT);
  if tcall1_globalresult <> tcall1_GLOBAL_RESULT then
    tcall1_failed:= true;

  tcall1_globalresult := 0;
  tcall1_b:=0;
  tcall1_class_var:=tcall1_tclass1.create_var(tcall1_l,tcall1_b);
  tcall1_globalresult:=tcall1_b;
  if tcall1_globalresult <> tcall1_GLOBAL_RESULT then
    tcall1_failed:= true;


  tcall1_globalresult := 0;
  tcall1_b:=tcall1_GLOBAL_RESULT;
  tcall1_class_const:=tcall1_tclass1.create_const(tcall1_l,tcall1_b);
  if tcall1_globalresult <> tcall1_GLOBAL_RESULT then
    tcall1_failed:= true;

  tcall1_globalresult := 0;
  tcall1_b:=0;
  tcall1_a:=0;
  tcall1_c:=0;
  tcall1_d:=tcall1_GLOBAL_RESULT;
  tcall1_class_mixed:=tcall1_tclass1.create_mixed(tcall1_a,tcall1_b,tcall1_c,tcall1_d);
  if tcall1_globalresult <> tcall1_GLOBAL_RESULT then
    tcall1_failed:= true;

{$ifdef dummy}
  tcall1_globalresult := tcall1_GLOBAL_RESULT;
  { secondcalln : class constructor failure, when getmem returns 0,
    that will call class_help_fail and abort class construction }
  heaperror := @tcall1_myheaperrornil;
  try
    tcall1_class_none_fail:=tcall1_tclass2.create_none;
   except
   on EOutOfMemory do tcall1_globalresult:=0;
   end;
  if tcall1_globalresult <> tcall1_GLOBAL_RESULT then
    tcall1_failed:= true;

  { secondcalln : class constructor failure, getmem gives a runtime error
    that will be translated to a exception and the exception shall be catched
    here }
  tcall1_globalresult := 0;
  heaperror := @tcall1_myheaperrorexception;
  try
    tcall1_class_none_fail:=tcall1_tclass2.create_none;
   except
   on EOutOfMemory do tcall1_globalresult:=tcall1_GLOBAL_RESULT;
   end;
  if tcall1_globalresult <> tcall1_GLOBAL_RESULT then
    tcall1_failed:= true;
{$endif dummy}

  if tcall1_failed then
    tcall1_fail
  else
    WriteLn('Passed!');

end;
{$pop}

end.
