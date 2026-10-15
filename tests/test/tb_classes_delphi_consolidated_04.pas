{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tchlp28.pas }
{$push}
{ class helpers hide methods of the extended class }


{$ifdef fpc}
  
{$endif}

type
  tchlp28_TTest = class
    function Test: Integer;
  end;

  tchlp28_TTestHelper = class helper for tchlp28_TTest
    function Test: Integer;
  end;

function tchlp28_TTest.Test: Integer;
begin
  Result := 1;
end;

function tchlp28_TTestHelper.Test: Integer;
begin
  Result := 2;
end;

var
  tchlp28_t: tchlp28_TTest;

{$pop}

{ Case tchlp29.pas }
{$push}
{ class helpers don't hide methods of the subclasses of the extended class }


{$ifdef fpc}
  
{$endif}

type
  tchlp29_TTest = class
    function Test: Integer;
  end;

  tchlp29_TTestHelper = class helper for tchlp29_TTest
    function Test: Integer;
  end;

  tchlp29_TTestSub = class(tchlp29_TTest)
    function Test: Integer;
  end;

function tchlp29_TTest.Test: Integer;
begin
  Result := 1;
end;

function tchlp29_TTestHelper.Test: Integer;
begin
  Result := 2;
end;

function tchlp29_TTestSub.Test: Integer;
begin
  Result := 3;
end;

var
  tchlp29_t: tchlp29_TTestSub;

{$pop}

{ Case tchlp31.pas }
{$push}
{ helpers may hide virtual methods of the extended class }


{$ifdef fpc}
  
{$endif}

type
  tchlp31_TTest = class
    function Test: Integer; virtual;
  end;

  tchlp31_TTestHelper = class helper for tchlp31_TTest
    function Test: Integer;
  end;

function tchlp31_TTest.Test: Integer;
begin
  Result := 1;
end;

function tchlp31_TTestHelper.Test: Integer;
begin
  Result := 2;
end;

var
  tchlp31_t: tchlp31_TTest;

{$pop}

{ Case tclass10.pas }
{$push}

{$ifdef fpc}
  
{$endif}

type

  { c }

  tclass10_c=class
   type
     TSomeType = (st1, st2);
    function DoSomething: TSomeType;
  end;

{ c }

function tclass10_c.DoSomething: TSomeType;
begin
  Result := st1;
end;


{$pop}

{ Case tclass10a.pas }
{$push}

{$ifdef fpc}
  
{$endif}

// check that "protected" or any other section resets the section type to accept regular fields

type
  tclass10a_Tfoo=class
  private
    type
      TF = (one,two,three);
  protected
    f: TF;
  end;


{$pop}

{ Case tclass10c.pas }
{$push}

{$ifdef fpc}
  
{$endif}

// check that "protected" or any other section resets the section type to accept regular fields

type
  tclass10c_Tfoo=class
  private
    class var
      f1: Integer;
  protected
    f2: Integer;
  public
    class property pf1: Integer read f1;
    property pf2: Integer read f2;
  end;


{$pop}

{ Case tclass3.pas }
{$push}
{$ifdef fpc}
   
{$endif}
type
  tclass3_TMyComponent = class
  public
    constructor Create(k1:longint;k2: shortstring);
    destructor Destroy;override;
  end;

  tclass3_TMyComponent1 = class(tclass3_TMyComponent)
  public
    constructor Create(l1:longint;l2:shortstring);
  end;

constructor tclass3_TMyComponent.Create(k1:longint;k2:shortstring);
begin
end;

destructor tclass3_TMyComponent.Destroy;
begin
end;

constructor tclass3_TMyComponent1.Create(l1:longint;l2:shortstring);
begin
  inherited;
end;


{$pop}

{ Case tclass7.pas }
{$push}

{$ifdef fpc}
 
{$endif}

type
 tclass7_tClassA=class
  procedure DefaultHandler(var Message);override;
 end;

 tclass7_tClassB=class(tclass7_tClassA)
  procedure test(var m);message 1;
 end;

 tclass7_tClassC=class(tclass7_tClassB)
  procedure test00(var m);message 1;
 end;

var
  tclass7_counter : longint;

procedure tclass7_tClassA.DefaultHandler(var Message);
 begin
  writeln('DDDDDDDDDD');
  inc(tclass7_counter);
 end;

procedure tclass7_tClassB.test(var m);
 begin
  writeln('BBBBBBBBBB');
  inc(tclass7_counter);
  inherited;
 end;

procedure tclass7_tClassC.test00(var m);
 begin
  writeln('CCCCCCCCCC');
  inc(tclass7_counter);
  inherited;
 end;

var
 tclass7_C:tObject;
 tclass7_One:longint;

{$pop}

{ Case tclrprop.pas }
{$push}


type
  tclrprop_tc = class
  end;

  tclrprop_tcc = class of tclrprop_tc;

  tclrprop_tc1 = class
   private
    fa: tclrprop_tcc;
   published
    property pa: tclrprop_tcc read fa write fa;
  end;


{$pop}

{ Case terecs8.pas }
{$push}




// allow refence owner type for record and object static fields and class properties
type
  terecs8_TFoo = record
  class var
    FFoo: terecs8_TFoo;
  class property Foo: terecs8_TFoo read FFoo write FFoo;
  end;

  terecs8_TBar = record
  class var
    FBar: terecs8_TBar;
  class property Bar: terecs8_TBar read FBar write FBar;
  end;


{$pop}

{ Case thlp30.pas }
{$push}
{ helpers can extend type parameters if they can only be classes }


{$ifdef fpc}
  
{$endif}

type
  thlp30_TFoo<T: class> = class
  type
    THelper = class helper for T
    end;
  end;

type
  thlp30_TFooTObject = thlp30_TFoo<TObject>;


{$pop}

{ Case tisconstvalue3.pas }
{$push}


{$IFDEF FPC}
  
{$ENDIF}

type
  tisconstvalue3_TMyClass = class
  const
    PI = 3.14;
  private
    FNumber: Integer;
  public
    function DoMathAndReturn(const AValue: Integer): Integer;
  published
    property MyNumber: Integer read FNumber;
  end;

  tisconstvalue3_TClassOf = class of tisconstvalue3_TMyClass;

  function tisconstvalue3_TMyClass.DoMathAndReturn(const AValue: Integer): Integer;
  begin
    Result := FNumber * 2;
  end;

function tisconstvalue3_WorldCopy(AInput: String): String;
begin
  if IsConstValue(AInput) then
    Halt(9);

  Result := 'Hello ' + AInput;
end;

function tisconstvalue3_WorldConst(const AInput: String): String;
begin
  if IsConstValue(AInput) then
    Halt(10);

  Result := 'Hello ' + AInput;
end;

function tisconstvalue3_WorldVar(var AInput: String): String;
begin
  if IsConstValue(AInput) then
    Halt(11);

  Result := 'Hello ' + AInput;
end;

function tisconstvalue3_WorldOut(out AInput: String): String;
begin
  AInput := 'Test';
  if IsConstValue(AInput) then
    Halt(12);

  Result := 'Hello ' + AInput;
end;

var
  tisconstvalue3_MyClass: tisconstvalue3_TMyClass;
  tisconstvalue3_MyString: String;

const
  tisconstvalue3_SomeClass: TClass = tisconstvalue3_TMyClass;


{$pop}

{ Case tmoperator11.pas }
{$push}




var
  tmoperator11_i: Integer = 0;

type
  tmoperator11_TFoo = record
    class operator Initialize(var aFoo: tmoperator11_TFoo);
    procedure Foo;
  end;

class operator tmoperator11_TFoo.Initialize(var aFoo: tmoperator11_TFoo);
begin
  Inc(tmoperator11_i);
end;

procedure tmoperator11_TFoo.Foo;
begin
end;

var
  tmoperator11_f: tmoperator11_TFoo;

{$pop}

{ Case tmoperator4.pas }
{$push}




type
  tmoperator4_TR1 = record
  private
    class operator Initialize(var aR1: tmoperator4_TR1);
    class operator Finalize(var aR1: tmoperator4_TR1);
  public
    I: Integer;
  end;

  tmoperator4_TR2 = record
  private
    class operator Initialize(var aR2: tmoperator4_TR2);
    class operator Finalize(var aR2: tmoperator4_TR2);
  public
    S: string;
  end;

{ TR1 }

class operator tmoperator4_TR1.Initialize(var aR1: tmoperator4_TR1);
begin
  WriteLn('TR1.Initialize');
  aR1.I := 1;
end;

class operator tmoperator4_TR1.Finalize(var aR1: tmoperator4_TR1);
begin
  if aR1.I <> 2 then
    Halt(1);
  WriteLn('TR1.Finalize');
end;

{ TR2 }

class operator tmoperator4_TR2.Initialize(var aR2: tmoperator4_TR2);
begin
  WriteLn('TR2.Initialize');
  aR2.S := 'A';
end;

class operator tmoperator4_TR2.Finalize(var aR2: tmoperator4_TR2);
begin
  if aR2.S <> 'B' then
    Halt(2);
  WriteLn('TR2.Finalize');
end;

{ TA }

type
  tmoperator4_TA = class
  public
    F1: tmoperator4_TR1;
  end;

  tmoperator4_TB = class(tmoperator4_TA)
  public
    F2: tmoperator4_TR2;
  end;

var
  tmoperator4_O: tmoperator4_TB;

{$pop}

{ Case tmoperator7.pas }
{$push}




type
  tmoperator7_TFoo = record
  private
    class operator Initialize(var aFoo: tmoperator7_TFoo);
    class operator Finalize(var aFoo: tmoperator7_TFoo);
  public
    I: Integer;
  public class var
    InitializeCount: Integer;
    FinalizeCount: Integer;
  end;

  tmoperator7_TFooObj = object
  public
    F: tmoperator7_TFoo;
  end;

  tmoperator7_TFooArray = array of tmoperator7_TFoo;
  tmoperator7_TFooObjArray = array of tmoperator7_TFooObj;

{ TFoo }

class operator tmoperator7_TFoo.Initialize(var aFoo: tmoperator7_TFoo);
begin
  Inc(InitializeCount);
  if aFoo.I <> 0 then // for dyn array and old obj
    Halt(1);

  WriteLn('TFoo.Initialize');
  aFoo.I := 1;
end;

class operator tmoperator7_TFoo.Finalize(var aFoo: tmoperator7_TFoo);
begin
  Inc(FinalizeCount);
  if aFoo.I <> 2 then
    Halt(2);
  WriteLn('TFoo.Finalize');
end;

procedure tmoperator7_CheckFooInit(var AValue: Integer; const AExpectedInitializeCount: Integer);
begin
  if AValue <> 1 then
    Halt(3);
  AValue := 2;

  if tmoperator7_TFoo.InitializeCount <> AExpectedInitializeCount then
    Halt(4);
end;

procedure tmoperator7_CheckFooFini(const AExpectedFinalizeCount: Integer);
begin
  if tmoperator7_TFoo.FinalizeCount <> AExpectedFinalizeCount then
    Halt(5);
end;

procedure tmoperator7_FooTest;
var
  Foos, FoosSecondRef: tmoperator7_TFooArray;
  FoosObj, FoosObjSecondRef: tmoperator7_TFooObjArray;
begin
  WriteLn('=== DynArray of Records ===');

  Foos := nil;
  SetLength(Foos, 1);
  tmoperator7_CheckFooInit(Foos[0].I, 1);

  SetLength(Foos, 2);
  tmoperator7_CheckFooInit(Foos[1].I, 2);

  SetLength(Foos, 1);
  tmoperator7_CheckFooFini(1);

  SetLength(Foos, 2);
  tmoperator7_CheckFooInit(Foos[1].I, 3);

  FoosSecondRef := Foos;
  if pointer(Foos) <> pointer(FoosSecondRef) then
    Halt(5); { just to "use" FoosSecondRef... }
  SetLength(Foos, 3);
  tmoperator7_CheckFooInit(Foos[2].I, 4);

  Foos := nil;
  FoosSecondRef := nil;
  tmoperator7_CheckFooFini(6);

  WriteLn('=== DynArray of Objects ===');
  tmoperator7_TFoo.InitializeCount := 0;
  tmoperator7_TFoo.FinalizeCount := 0;

  FoosObj := nil;
  SetLength(FoosObj, 1);
  tmoperator7_CheckFooInit(FoosObj[0].F.I, 1);

  SetLength(FoosObj, 2);
  tmoperator7_CheckFooInit(FoosObj[1].F.I, 2);

  SetLength(FoosObj, 1);
  tmoperator7_CheckFooFini(1);

  SetLength(FoosObj, 2);
  tmoperator7_CheckFooInit(FoosObj[1].F.I, 3);

  FoosObjSecondRef := FoosObj;
  if pointer(FoosObj) <> pointer(FoosObjSecondRef) then
    Halt(5); { just to "use" FoosObjSecondRef... }
  SetLength(FoosObj, 3);
  tmoperator7_CheckFooInit(FoosObj[2].F.I, 4);

  FoosObj := nil;
  FoosObjSecondRef := nil;
  tmoperator7_CheckFooFini(6);
end;


{$pop}

{ Case tmoperator8.pas }
{$push}




type
  tmoperator8_TCopyState = (tmoperator8_csNone, tmoperator8_csSource, tmoperator8_csDest);
  tmoperator8_PFoo = ^tmoperator8_TFoo;
  tmoperator8_TFoo = record
  private
    class operator Initialize(var aFoo: tmoperator8_TFoo);
    class operator Finalize(var aFoo: tmoperator8_TFoo);
    class operator AddRef(var aFoo: tmoperator8_TFoo);
    class operator Copy(constref aSrc: tmoperator8_TFoo; var aDst: tmoperator8_TFoo);
  public
    CopyState: tmoperator8_TCopyState;
    Ref: Boolean;
    F, tmoperator8_Test: Integer;
  end;

  tmoperator8_TFooArray = array of tmoperator8_TFoo;

procedure tmoperator8_TestFoo(const AValue: tmoperator8_TFoo; AF, ATest: Integer; ARef: Boolean; ACopyState: tmoperator8_TCopyState);
begin
  WriteLn('    AValue.F = ', AValue.F);
  if AValue.F <> AF then
    Halt(1);
  WriteLn('    AValue.Test = ', AValue.tmoperator8_Test);
  if AValue.tmoperator8_Test <> ATest then
    Halt(2);
  WriteLn('    AValue.Ref = ', AValue.Ref);
  if AValue.Ref <> ARef then
    Halt(4);
  WriteLn('    AValue.CopyState = ', Ord(AValue.CopyState));
  if AValue.CopyState <> ACopyState then
    Halt(3);
end;

class operator tmoperator8_TFoo.Initialize(var aFoo: tmoperator8_TFoo);
begin
  WriteLn('TFoo.Initialize');
  aFoo.F := 1;
  aFoo.Ref := False;
  aFoo.tmoperator8_Test := 0;
  aFoo.CopyState := tmoperator8_csNone;
end;

class operator tmoperator8_TFoo.Finalize(var aFoo: tmoperator8_TFoo);
begin
  WriteLn('TFoo.Finalize');
  if (aFoo.F <> 2) and not ((aFoo.F = 3) and aFoo.Ref) then
    Halt(5);
  aFoo.F := 4;
end;

class operator tmoperator8_TFoo.AddRef(var aFoo: tmoperator8_TFoo);
begin
  WriteLn('TFoo.AddRef');
  aFoo.F := 3;
  aFoo.tmoperator8_Test := aFoo.tmoperator8_Test + 1;
  aFoo.Ref := True;
end;

class operator tmoperator8_TFoo.Copy(constref aSrc: tmoperator8_TFoo; var aDst: tmoperator8_TFoo);
var
  LSrc: tmoperator8_PFoo;
begin
  WriteLn('TFoo.Copy');
  LSrc := @aSrc;
  LSrc.CopyState := tmoperator8_csSource;
  aDst.CopyState := tmoperator8_csDest;
  aDst.tmoperator8_Test := aSrc.tmoperator8_Test + 1;
  aDst.F := aSrc.F;
end;

procedure tmoperator8_TestValue(Value: tmoperator8_TFoo);
begin
  writeln('  *Test without modifier:');
  tmoperator8_TestFoo(Value, 3, 1, True, tmoperator8_csNone);
end;

procedure tmoperator8_TestOut(out Value: tmoperator8_TFoo);
begin
  WriteLn('  *Test out modifier:');
  tmoperator8_TestFoo(Value, 1, 0, False, tmoperator8_csNone);
  Value.F := 2;
end;

procedure tmoperator8_TestVar(var Value: tmoperator8_TFoo);
begin
  writeln('  *Test var modifier:');
  tmoperator8_TestFoo(Value, 2, 0, False, tmoperator8_csNone);
end;

procedure tmoperator8_TestConst(const Value: tmoperator8_TFoo);
begin
  writeln('  *Test const modifier:');
  tmoperator8_TestFoo(Value, 2, 0, False, tmoperator8_csNone);
end;

procedure tmoperator8_TestConstref(constref Value: tmoperator8_TFoo);
begin
  WriteLn('  *Test constref modifier:');
  tmoperator8_TestFoo(Value, 2, 0, False, tmoperator8_csNone);
end;

procedure tmoperator8_Test;
var
  Foos: tmoperator8_TFooArray;
  Foos2: tmoperator8_TFooArray;
  A, B, C: tmoperator8_TFoo;
  i: Integer;
begin
  WriteLn('*** Test for variable copy');
  tmoperator8_TestFoo(B, 1, 0, False, tmoperator8_csNone);
  B.F := 2;
  A := B;
  tmoperator8_TestFoo(B, 2, 0, False, tmoperator8_csSource);
  tmoperator8_TestFoo(A, 2, 1, False, tmoperator8_csDest);

  WriteLn('*** Test for Copy(dyn array)');
  SetLength(Foos, 5);
  for i := 0 to 4 do
  begin
    Foos[i].F := 2;
    Foos[i].tmoperator8_Test := i;
  end;

  Foos2 := Copy(Foos);

  for i := 0 to 4 do
  begin
    tmoperator8_TestFoo(Foos[i], 2, i, False, tmoperator8_csNone);
    tmoperator8_TestFoo(Foos2[i], 3, i + 1, True, tmoperator8_csNone);
  end;

  WriteLn('*** Test for parameters modifiers');
  tmoperator8_TestValue(C);
  C.F := 2; // reset F to pass finalize before out parameter
  tmoperator8_TestOut(C);
  tmoperator8_TestVar(C);
  tmoperator8_TestConst(C);
  tmoperator8_TestConstref(C);
end;


{$pop}

{ Case tmoperator9.pas }
{$push}




type

  { TFoo }

  tmoperator9_PFoo = ^tmoperator9_TFoo;
  tmoperator9_TFoo = record
  private
    class operator Initialize(var aFoo: tmoperator9_TFoo);
    class operator Finalize(var aFoo: tmoperator9_TFoo);
  end;

{ TFoo }

var
  tmoperator9_ok_initialize: boolean = false;
  tmoperator9_ok_finalize: boolean = false;

class operator tmoperator9_TFoo.Initialize(var aFoo: tmoperator9_TFoo);
begin
  tmoperator9_ok_initialize := true;
end;

class operator tmoperator9_TFoo.Finalize(var aFoo: tmoperator9_TFoo);
begin
  tmoperator9_ok_finalize := true;
end;

var
  tmoperator9_PF: tmoperator9_PFoo;

{$pop}

{ Case toperator12.pas }
{$push}


{$ifdef FPC}
  
{$endif}

type
  toperator12_R = record
    F: Integer;
    class operator Implicit(const v: integer): toperator12_R;
  end;

class operator toperator12_R.Implicit(const v: integer): toperator12_R;
begin
  Result.F := v;
end;

var
  toperator12_x: toperator12_R;

{$pop}

{ Case toperator91.pas }
{$push}




type
  toperator91_TString80 = String[80];
  toperator91_TString90 = String[90];
  toperator91_TString40 = String[40];
  toperator91_TString100 = String[100];

  toperator91_TTest = record
    class operator Explicit(const aArg: toperator91_TTest): toperator91_TString80;
    class operator Explicit(const aArg: toperator91_TTest): toperator91_TString90;
    class operator Explicit(const aArg: toperator91_TTest): ShortString;
    class operator Implicit(const aArg: toperator91_TTest): toperator91_TString80;
    class operator Implicit(const aArg: toperator91_TTest): toperator91_TString90;
    class operator Implicit(const aArg: toperator91_TTest): ShortString;
  end;

var
  toperator91_ExplicitString80: LongInt;
  toperator91_ExplicitString90: LongInt;
  toperator91_ExplicitShortString: LongInt;
  toperator91_ImplicitString80: LongInt;
  toperator91_ImplicitString90: LongInt;
  toperator91_ImplicitShortString: LongInt;

class operator toperator91_TTest.Explicit(const aArg: toperator91_TTest): toperator91_TString80;
begin
  Writeln('TString80 Explicit');
  Inc(toperator91_ExplicitString80);
  Result := '';
end;

class operator toperator91_TTest.Explicit(const aArg: toperator91_TTest): toperator91_TString90;
begin
  Writeln('TString90 Explicit');
  Inc(toperator91_ExplicitString90);
  Result := '';
end;

class operator toperator91_TTest.Explicit(const aArg: toperator91_TTest): ShortString;
begin
  Writeln('ShortString Explicit');
  Inc(toperator91_ExplicitShortString);
  Result := '';
end;

class operator toperator91_TTest.Implicit(const aArg: toperator91_TTest): toperator91_TString80;
begin
  Writeln('TString80 Implicit');
  Inc(toperator91_ImplicitString80);
  Result := '';
end;

class operator toperator91_TTest.Implicit(const aArg: toperator91_TTest): toperator91_TString90;
begin
  Writeln('TString90 Implicit');
  Inc(toperator91_ImplicitString90);
  Result := '';
end;

class operator toperator91_TTest.Implicit(const aArg: toperator91_TTest): ShortString;
begin
  Writeln('ShortString Implicit');
  Inc(toperator91_ImplicitShortString);
  Result := '';
end;

var
  toperator91_s80: toperator91_TString80;
  toperator91_s90: toperator91_TString90;
  toperator91_s40: toperator91_TString40;
  toperator91_s100: toperator91_TString100;
  toperator91_t: toperator91_TTest;

{$pop}

{ Case tvarpropsetter1.pas }
{$push}


{$ifdef fpc}

{$endif}

{$VARPROPSETTER ON}

type
  tvarpropsetter1_TSomeClass = class
  private
    FTest: Integer;
    function GetTest: Integer;
    procedure SetTest(var AValue: Integer);
  public
    property Test: Integer read GetTest write SetTest;
  end;

{ TSomeClass }

function tvarpropsetter1_TSomeClass.GetTest: Integer;
begin
  Result := FTest;
end;

procedure tvarpropsetter1_TSomeClass.SetTest(var AValue: Integer);
begin
  FTest := AValue;
  AValue := 10;
end;

var
  tvarpropsetter1_Cl: tvarpropsetter1_TSomeClass;
  tvarpropsetter1_D: Integer;

{$pop}

begin

{ Case tchlp28.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tchlp28_t := tchlp28_TTest.Create;
  if tchlp28_t.Test <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp29.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tchlp29_t := tchlp29_TTestSub.Create;
  if tchlp29_t.Test <> 3 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tchlp31.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
  tchlp31_t := tchlp31_TTest.Create;
  if tchlp31_t.Test <> 2 then
    Halt(1);
  Writeln('ok');
end;
{$pop}

{ Case tclass10.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tclass10a.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tclass10c.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tclass3.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tclass7.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
 tclass7_One:=1;
 tclass7_C:=tclass7_tClassC.Create;
 tclass7_C.Dispatch(tclass7_One);
 tclass7_C.Destroy;
 if tclass7_counter<>3 then
  begin
    writeln('Error in class DefaultHandler for messages!');
{$ifdef VER1_0}
    halt(2);
{$else not VER1_0}
    halt(1);
{$endif not VER1_0}
  end;
end;
{$pop}

{ Case tclrprop.pas }
{$push}

begin
end;
{$pop}

{ Case terecs8.pas }
{$push}

begin
end;
{$pop}

{ Case thlp30.pas }
{$push}
{$ifdef fpc}

{$endif}
begin

end;
{$pop}

{ Case tisconstvalue3.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
begin
  if IsConstValue(tisconstvalue3_TMyClass) then
    Halt(1);

  tisconstvalue3_MyClass := tisconstvalue3_TMyClass.Create;
  try
    if IsConstValue(tisconstvalue3_MyClass) then
      Halt(3);

    if IsConstValue(tisconstvalue3_MyClass.MyNumber) then
      Halt(4);

    if not IsConstValue(tisconstvalue3_MyClass.PI) then
      Halt(5);

    if IsConstValue(tisconstvalue3_MyClass.DoMathAndReturn(5)) then
      Halt(6);

    if IsConstValue(@tisconstvalue3_MyClass) then
      Halt(7);
  finally
    tisconstvalue3_MyClass.Free;
  end;

  if IsConstValue(@tisconstvalue3_WorldCopy) then
    Halt(8);

  tisconstvalue3_WorldCopy('World');
  tisconstvalue3_WorldConst('World');
  tisconstvalue3_MyString := 'World';
  tisconstvalue3_WorldVar(tisconstvalue3_MyString);
  tisconstvalue3_WorldOut(tisconstvalue3_MyString);

  if IsConstValue(tisconstvalue3_WorldCopy('World')) then
    Halt(13);

  if IsConstValue(tisconstvalue3_MyString) then
    Halt(14);

  if IsConstValue(@tisconstvalue3_MyString) then
    Halt(15);

  UniqueString(tisconstvalue3_MyString);
  if IsConstValue(tisconstvalue3_MyString) then
    Halt(16);

  if not IsConstValue('Hello') then
    Halt(17);

  if not IsConstValue(3.14) then
    Halt(17);

  if not IsConstValue(12345) then
    Halt(18);

  if not IsConstValue(5 <> 2) then
    Halt(19);

  if not IsConstValue(5 - 5 = 0) then
    Halt(20);

  if IsConstValue(tisconstvalue3_SomeClass) then
    Halt(21);

  Writeln('Ok');
end;
{$pop}

{ Case tmoperator11.pas }
{$push}

begin
  if tmoperator11_i <> 1 then
    Halt(1);
  tmoperator11_f.Foo;
end;
{$pop}

{ Case tmoperator4.pas }
{$push}

begin
  tmoperator4_O := tmoperator4_TB.Create;

  if tmoperator4_O.F1.I <> 1 then
    Halt(3);
  if tmoperator4_O.F2.S <> 'A' then
    Halt(4);

  tmoperator4_O.F1.I := 2;
  tmoperator4_O.F2.S := 'B';

  tmoperator4_O.Free;

  WriteLn('end');
end;
{$pop}

{ Case tmoperator7.pas }
{$push}

begin
  tmoperator7_FooTest;
end;
{$pop}

{ Case tmoperator8.pas }
{$push}

begin
  tmoperator8_Test;
  WriteLn('end');
end;
{$pop}

{ Case tmoperator9.pas }
{$push}

begin
  { init rtti test }
  New(tmoperator9_PF);
  if not tmoperator9_ok_initialize then
    Halt(1);
  Dispose(tmoperator9_PF);
  if not tmoperator9_ok_finalize then
    Halt(2);

  tmoperator9_ok_initialize := false;
  tmoperator9_ok_finalize := false;

  { regular rtti test }
  GetMem(tmoperator9_PF, SizeOf(tmoperator9_TFoo));
  InitializeArray(tmoperator9_PF, TypeInfo(tmoperator9_TFoo), 1);
  if not tmoperator9_ok_initialize then
    Halt(3);
  FinalizeArray(tmoperator9_PF, TypeInfo(tmoperator9_TFoo), 1);
  if not tmoperator9_ok_finalize then
    Halt(4);
  FreeMem(tmoperator9_PF);
end;
{$pop}

{ Case toperator12.pas }
{$push}
{$ifdef FPC}

{$endif}
begin
  toperator12_x := 42;
  if toperator12_x.F <> 42 then
    halt(1);
end;
{$pop}

{ Case toperator91.pas }
{$push}

begin
  // Explicit
  toperator91_s80 := toperator91_TString80(toperator91_t);
  if toperator91_ExplicitString80 <> 1 then
    Halt(1);
  toperator91_s90 := toperator91_TString90(toperator91_t);
  if toperator91_ExplicitString90 <> 1 then
    Halt(2);
  toperator91_s40 := toperator91_TString40(toperator91_t);
  if toperator91_ImplicitShortString <> 1 then
    Halt(3);
  toperator91_s100 := toperator91_TString100(toperator91_t);
  if toperator91_ImplicitShortString <> 2 then
    Halt(4);
  // Implicit
  toperator91_s80 := toperator91_t;
  if toperator91_ImplicitShortString <> 3 then
    Halt(5);
  toperator91_s90 := toperator91_t;
  if toperator91_ImplicitShortString <> 4 then
    Halt(6);
  toperator91_s40 := toperator91_t;
  if toperator91_ImplicitShortString <> 5 then
    Halt(7);
  toperator91_s100 := toperator91_t;
  if toperator91_ImplicitShortString <> 6 then
    Halt(8);
  Writeln('ok');
end;
{$pop}

{ Case tvarpropsetter1.pas }
{$push}
{$ifdef fpc}

{$endif}
{$VARPROPSETTER ON}
begin
  tvarpropsetter1_Cl := tvarpropsetter1_TSomeClass.Create;
  tvarpropsetter1_D := 5;
  tvarpropsetter1_Cl.Test := tvarpropsetter1_D;
  if tvarpropsetter1_Cl.Test <> 5 then
    halt(1);
  if tvarpropsetter1_D <> 10 then
    halt(2);
  tvarpropsetter1_Cl.Free;
end;
{$pop}

end.
