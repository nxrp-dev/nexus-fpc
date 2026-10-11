{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb0694.pp }
{$push}

{$warn 4055 off Conversion between ordinals and pointers is not portable}
type
	tb0694_PObject1 = ^tb0694_Object1;
	tb0694_Object1 = record
		field: int32;
		struct: record
			field: int64;
			ary: array[2 .. 5] of record
				x, y: int32;
				bottomAry: record
					n: SizeUint;
					items: array[3 .. 6, 4 .. 6] of uint16;
				end;
			end;
		end;
	end;

	tb0694_PTopLevelArray = ^tb0694_TopLevelArray;
	tb0694_TopLevelArray = array[1 .. 3] of tb0694_Object1;

	tb0694_TopLevelClass = class
		objs: array[1 .. 3] of tb0694_Object1;
	end;

const
	tb0694_OffsetOf3YInObject1 = PtrUint(@tb0694_PObject1(nil)^.struct.ary[3].y);
	tb0694_OffsetOf2345InObject1 = PtrUint(@tb0694_PObject1(nil)^.struct.ary[3].bottomAry.items[4, 5]);
	tb0694_OffsetOf23YInTopLevelArray = PtrUint(@tb0694_PTopLevelArray(nil)^[2].struct.ary[3].y);
	tb0694_OffsetOf2345InTopLevelArray = PtrUint(@tb0694_PTopLevelArray(nil)^[2].struct.ary[3].bottomAry.items[4, 5]);
	tb0694_OffsetOf23YInTopLevelClass = PtrUint(@tb0694_TopLevelClass(nil).objs[2].struct.ary[3].y);
	tb0694_OffsetOf2345InTopLevelClass = PtrUint(@tb0694_TopLevelClass(nil).objs[2].struct.ary[3].bottomAry.items[4, 5]);

	function tb0694_RecoverObject1From3Y(_3Y: PInt32): tb0694_PTopLevelArray;
	begin
		result := pointer(_3Y) - PtrUint(@tb0694_PObject1(nil)^.struct.ary[3].y);
	end;

	function tb0694_RecoverObject1From345(_345: PUint16): tb0694_PTopLevelArray;
	begin
		result := pointer(_345) - PtrUint(@tb0694_PObject1(nil)^.struct.ary[3].bottomAry.items[4, 5]);
	end;

	function tb0694_RecoverTopLevelArrayFrom23Y(_23Y: PInt32): tb0694_PTopLevelArray;
	begin
		result := pointer(_23Y) - PtrUint(@tb0694_PTopLevelArray(nil)^[2].struct.ary[3].y);
	end;

	function tb0694_RecoverTopLevelArrayFrom2345(_2345: PUint16): tb0694_PTopLevelArray;
	begin
		result := pointer(_2345) - PtrUint(@tb0694_PTopLevelArray(nil)^[2].struct.ary[3].bottomAry.items[4, 5]);
	end;

	function tb0694_RecoverTopLevelClassFrom23Y(_23Y: PInt32): tb0694_TopLevelClass;
	begin
		result := tb0694_TopLevelClass(pointer(_23Y) - PtrUint(@tb0694_TopLevelClass(nil).objs[2].struct.ary[3].y));
	end;

	function tb0694_RecoverTopLevelClassFrom2345(_2345: PUint16): tb0694_TopLevelClass;
	begin
		result := tb0694_TopLevelClass(pointer(_2345) - PtrUint(@tb0694_TopLevelClass(nil).objs[2].struct.ary[3].bottomAry.items[4, 5]));
	end;

var
	tb0694_o1: tb0694_Object1;
	tb0694_tla: tb0694_TopLevelArray;
	tb0694_tlc: tb0694_TopLevelClass;
	tb0694_fieldPtr, tb0694_recovered: pointer;


{$pop}

{ Case tb_class_instance_access.pp }
{$push}
{ Class constructor parameters, object fields, const references and interface storage. }

{ tw10454.pp }


type
  tb_class_instance_access_TMyObject = object
    Int: longint;
  end;

  tb_class_instance_access_TMyObject2 = object(tb_class_instance_access_TMyObject)
  end;

  tb_class_instance_access_TMyClass = class
    FByte: byte;
    Obj: tb_class_instance_access_TMyObject2;  // instance of this object is not aligned
  end;

var
  tb_class_instance_access_myclass: tb_class_instance_access_TMyClass;

{ tw0934.pp }

 Type
      tb_class_instance_access_t = class(TObject)
       f1,f2:dword;
       constructor Init(p1, p2:dword);
      end;

 constructor tb_class_instance_access_t.Init(p1, p2:dword);
 begin
  f1:=p1; f2:=p2;
 end;
 var tb_class_instance_access_ti:tb_class_instance_access_t;

{ tw1207.pp }


type
  tb_class_instance_access_aclasstype = class
    prop : integer;
  end;

procedure tb_class_instance_access_trychange (const tb_class_instance_access_aclass : tb_class_instance_access_aclasstype);
begin
  tb_class_instance_access_aclass.prop := 5;
end;

var
  tb_class_instance_access_aclass : tb_class_instance_access_aclasstype;

{ tw10831.pp }


type
  tb_class_instance_access_TForm = class(TInterfacedObject)
    a : array[0..1000000] of byte;
  end;

  tb_class_instance_access_TMyForm = class(tb_class_instance_access_TForm, IInterface)
  end;

var
  tb_class_instance_access_i : IInterface;


{$pop}

{ Case tb_static_procvars_objfpc.pp }
{$push}
{ ObjFPC static class method addresses from instance and global scopes. }

{ tw30936.pp }


type
  tb_static_procvars_objfpc_TImplicitStaticProc = class
  public type
    TProcedure = procedure;
  private
    class procedure MyProc; static;
  public
    constructor Create;
  end;

{ TTest }

constructor tb_static_procvars_objfpc_TImplicitStaticProc.Create;
var
  tb_static_procvars_objfpc_aProc: TProcedure;
begin
  tb_static_procvars_objfpc_aProc := @MyProc;
  tb_static_procvars_objfpc_aProc;
end;

class procedure tb_static_procvars_objfpc_TImplicitStaticProc.MyProc;
begin
  Writeln('OK');
end;

{ tw30936b.pp }


type
  tb_static_procvars_objfpc_TExplicitStaticProc = class
  public type
    TProcedure = procedure;
  private
    class procedure MyProc; static;
  public
    constructor Create;
  end;

{ TTest }

constructor tb_static_procvars_objfpc_TExplicitStaticProc.Create;
begin
end;

class procedure tb_static_procvars_objfpc_TExplicitStaticProc.MyProc;
begin
  Writeln('OK');
end;

var
  tb_static_procvars_objfpc_aProc: TProcedure;


{$pop}

{ Case tw0873a.pp }
{$push}


// Compile it using the Delphi extensions
// directive.

type
    tw0873a_TObjectB = class
      private
        procedure SetValue(v: integer);
      public
        fx: integer;
        Constructor Create;
        Destructor Destroy;
        property x: integer read fx write SetValue;
    end;

var
    tw0873a_Obj: tw0873a_TObjectB;

Constructor tw0873a_TObjectB.Create;
begin
    fx := 0;
end;

Destructor tw0873a_TObjectB.Destroy;
begin
end;

procedure tw0873a_TObjectB.SetValue(v: integer);
begin
    fx := v + 2;
end;


{$pop}

{ Case tw10493.pp }
{$push}



type
  tw10493_TStringArray = array of String;

  tw10493_TBug = class
  private
    fSA: tw10493_TStringArray;
  published
    property SA: tw10493_TStringArray read fSA write fSA;
  end;


{$pop}

{ Case tw14403.pp }
{$push}
{$R+}


type
  tw14403_TDummyShapeTree = class
    function ShapesCount(const OnlyActive, OnlyVisible, OnlyCollidable: boolean): Cardinal; virtual; abstract;
  end;

  tw14403_TDummyShapeTreeGroup = class(tw14403_TDummyShapeTree)
  public
    Child: tw14403_TDummyShapeTree;

    function ShapesCount(const OnlyActive, OnlyVisible, OnlyCollidable: boolean): Cardinal; override;
  end;

  tw14403_TDummyShape = class(tw14403_TDummyShapeTree)
  public
    function ShapesCount(const OnlyActive, OnlyVisible, OnlyCollidable: boolean): Cardinal; override;
  end;

function tw14403_TDummyShape.ShapesCount(
  const OnlyActive, OnlyVisible, OnlyCollidable: boolean): Cardinal;
begin
  Result := 1;
end;

function tw14403_TDummyShapeTreeGroup.ShapesCount(
  const OnlyActive, OnlyVisible, OnlyCollidable: boolean): Cardinal;
var
  I: Integer;
  Something: Cardinal;
begin
  Result := 0;
  for I := 0 to 1 do
  begin
    Result := Result + Child.ShapesCount(OnlyActive, OnlyVisible, OnlyCollidable);
  end;
end;

var
  tw14403_G: tw14403_TDummyShapeTreeGroup;

{$pop}

{ Case tw1935.pp }
{$push}

{$ifdef fpc}
  
{$endif}

type
        tw1935_TCls = class
                public
                        procedure build (a, b, tw1935_c: LongInt);overload;
                        procedure build (a, b, tw1935_c, d: LongInt);overload;
                end;

const
    tw1935_err : boolean=true;

procedure tw1935_TCls.build (a, b, tw1935_c: LongInt);

        procedure subproc;
        begin
                writeln ('a, b, c');
        tw1935_err:=false;
        end;

begin
        subproc;
end;

procedure tw1935_TCls.build (a, b, tw1935_c, d: LongInt);

        procedure subproc;
        begin
                writeln ('a, b, c, d');
        end;

begin
end;

var
        tw1935_C: tw1935_TCls;


{$pop}

{ Case tw21811.pp }
{$push}

type
  tw21811_TC1 = class
  strict protected
    procedure P;
  end;

  tw21811_TH1 = class helper for tw21811_TC1
  public
    procedure Q;
  end;

var
  tw21811_b: boolean;

procedure tw21811_TC1.P;
  begin
    tw21811_b:=true;
  end;

procedure tw21811_TH1.Q;
  begin
    inherited P;
  end;

var
  tw21811_c: tw21811_tc1;

{$pop}

{ Case tw2480.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2480 }
{ Submitted by "Sergey Kosarevsky" on  2003-05-01 }
{ e-mail: netsurfer@au.ru }


Type tw2480_tSingleton=Class
       Private
        _Instance:tw2480_tSingleton;Static;
       Public
        Constructor Init;
        Class Function Instance:tw2480_tSingleton;
     End;

class Function tw2480_tSingleton.Instance:tw2480_tSingleton;
Begin
   If _Instance=Nil Then _Instance:=tw2480_tSingleton.Init;
   Exit(_Instance);
End;

Constructor tw2480_tSingleton.Init;
Begin
End;


{$pop}

{ Case tw2859.pp }
{$push}
{$ifdef fpc}{$H+}{$endif}

type
  tw2859_TMyClass = class
  public
    constructor Create;
    procedure Assign(v:pointer);virtual;
  end;

var
  tw2859_i : longint;

constructor tw2859_TMyClass.Create;
begin
  writeln('TMyClass.Create');
  inc(tw2859_i);
end;

procedure tw2859_TMyClass.Assign(v:pointer);
begin
end;

function tw2859_CreateMyClass: tw2859_TMyClass;
begin
  Result:=tw2859_TMyClass.Create;
end;

var
  tw2859_Item: tw2859_TMyClass;

{$pop}

{ Case tw29491.pp }
{$push}


{$H+}

type
  tw29491_TCallback = procedure of object;

  TTestObject = class (TObject)
  public
    class procedure Test;
  end;

class procedure TTestObject.Test;
begin
  writeln(Self.ClassName); // Self should point to TTestObject (class)
  if Self.ClassName<>'TTestObject' then
    halt(1);
end;

var
  tw29491_Callback: tw29491_TCallback;
  tw29491_O: TTestObject;

{$pop}

{ Case tw29923.pp }
{$push}


{$r+}

type
  tw29923_tc = class
    f: longint;
    procedure test;
  end;

procedure tw29923_tc.test;

procedure nest;
var
  l1: longint;
begin
  f:=-1;
  l1:=-1;
  dec(f,l1*120);
end;

begin
  nest;
end;

var
  tw29923_c: tw29923_tc;

{$pop}

{ Case tw3168.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3168 }
{ Submitted by "Henri Gourvest" on  2004-06-15 }
{ e-mail: hgourvest@progdigy.com }


type
  tw3168_TClazz = class
  private
    f: procedure(x: Integer); cdecl;
  public
    x: integer;
  end;


{$pop}

{ Case tw3435.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3435 }
{ Submitted by "Michalis Kamburelis" on  2004-12-06 }
{ e-mail: michalis@camelot.homedns.org }


type
  tw3435_TSomeLongLongLongTypeName = 0..1;

  tw3435_TSomeClass = class
  public
    constructor Create(
      Param1 : tw3435_TSomeLongLongLongTypeName;
      Param2 : tw3435_TSomeLongLongLongTypeName;
      Param3 : tw3435_TSomeLongLongLongTypeName;
      Param4 : tw3435_TSomeLongLongLongTypeName;
      Param5 : tw3435_TSomeLongLongLongTypeName;
      Param6 : tw3435_TSomeLongLongLongTypeName;
      Param7 : tw3435_TSomeLongLongLongTypeName;
      Param8 : tw3435_TSomeLongLongLongTypeName;
      Param9 : tw3435_TSomeLongLongLongTypeName;
      Param10: tw3435_TSomeLongLongLongTypeName;
      Param11: tw3435_TSomeLongLongLongTypeName;
      Param12: tw3435_TSomeLongLongLongTypeName;
      Param13: tw3435_TSomeLongLongLongTypeName;
      Param14: tw3435_TSomeLongLongLongTypeName;
      Param15: tw3435_TSomeLongLongLongTypeName;
      Param16: tw3435_TSomeLongLongLongTypeName;
      Param17: tw3435_TSomeLongLongLongTypeName;
      Param18: tw3435_TSomeLongLongLongTypeName;
      Param19: tw3435_TSomeLongLongLongTypeName);
    constructor Create(
      Param1 : tw3435_TSomeLongLongLongTypeName;
      Param2 : tw3435_TSomeLongLongLongTypeName;
      Param3 : tw3435_TSomeLongLongLongTypeName;
      Param4 : tw3435_TSomeLongLongLongTypeName;
      Param5 : tw3435_TSomeLongLongLongTypeName;
      Param6 : tw3435_TSomeLongLongLongTypeName;
      Param7 : tw3435_TSomeLongLongLongTypeName;
      Param8 : tw3435_TSomeLongLongLongTypeName;
      Param9 : tw3435_TSomeLongLongLongTypeName;
      Param10: tw3435_TSomeLongLongLongTypeName;
      Param11: tw3435_TSomeLongLongLongTypeName;
      Param12: tw3435_TSomeLongLongLongTypeName;
      Param13: tw3435_TSomeLongLongLongTypeName;
      Param14: tw3435_TSomeLongLongLongTypeName;
      Param15: tw3435_TSomeLongLongLongTypeName;
      Param16: tw3435_TSomeLongLongLongTypeName;
      Param17: tw3435_TSomeLongLongLongTypeName;
      Param18: tw3435_TSomeLongLongLongTypeName;
      Param19: tw3435_TSomeLongLongLongTypeName;
      Param20: tw3435_TSomeLongLongLongTypeName);
  end;

constructor tw3435_TSomeClass.Create(
  Param1 : tw3435_TSomeLongLongLongTypeName;
  Param2 : tw3435_TSomeLongLongLongTypeName;
  Param3 : tw3435_TSomeLongLongLongTypeName;
  Param4 : tw3435_TSomeLongLongLongTypeName;
  Param5 : tw3435_TSomeLongLongLongTypeName;
  Param6 : tw3435_TSomeLongLongLongTypeName;
  Param7 : tw3435_TSomeLongLongLongTypeName;
  Param8 : tw3435_TSomeLongLongLongTypeName;
  Param9 : tw3435_TSomeLongLongLongTypeName;
  Param10: tw3435_TSomeLongLongLongTypeName;
  Param11: tw3435_TSomeLongLongLongTypeName;
  Param12: tw3435_TSomeLongLongLongTypeName;
  Param13: tw3435_TSomeLongLongLongTypeName;
  Param14: tw3435_TSomeLongLongLongTypeName;
  Param15: tw3435_TSomeLongLongLongTypeName;
  Param16: tw3435_TSomeLongLongLongTypeName;
  Param17: tw3435_TSomeLongLongLongTypeName;
  Param18: tw3435_TSomeLongLongLongTypeName;
  Param19: tw3435_TSomeLongLongLongTypeName);

  procedure Nested(
  Param1 : tw3435_TSomeLongLongLongTypeName;
  Param2 : tw3435_TSomeLongLongLongTypeName;
  Param3 : tw3435_TSomeLongLongLongTypeName;
  Param4 : tw3435_TSomeLongLongLongTypeName;
  Param5 : tw3435_TSomeLongLongLongTypeName;
  Param6 : tw3435_TSomeLongLongLongTypeName;
  Param7 : tw3435_TSomeLongLongLongTypeName;
  Param8 : tw3435_TSomeLongLongLongTypeName;
  Param9 : tw3435_TSomeLongLongLongTypeName;
  Param10: tw3435_TSomeLongLongLongTypeName;
  Param11: tw3435_TSomeLongLongLongTypeName;
  Param12: tw3435_TSomeLongLongLongTypeName;
  Param13: tw3435_TSomeLongLongLongTypeName;
  Param14: tw3435_TSomeLongLongLongTypeName;
  Param15: tw3435_TSomeLongLongLongTypeName;
  Param16: tw3435_TSomeLongLongLongTypeName;
  Param17: tw3435_TSomeLongLongLongTypeName;
  Param18: tw3435_TSomeLongLongLongTypeName;
  Param19: tw3435_TSomeLongLongLongTypeName;
  Param20: tw3435_TSomeLongLongLongTypeName);
  begin
  end;

const
  SomeConstant1: array[0..1]of Integer = (0, 1);
  SomeConstant2: array[0..1]of Integer = (0, 1);
begin
end;

constructor tw3435_TSomeClass.Create(
  Param1 : tw3435_TSomeLongLongLongTypeName;
  Param2 : tw3435_TSomeLongLongLongTypeName;
  Param3 : tw3435_TSomeLongLongLongTypeName;
  Param4 : tw3435_TSomeLongLongLongTypeName;
  Param5 : tw3435_TSomeLongLongLongTypeName;
  Param6 : tw3435_TSomeLongLongLongTypeName;
  Param7 : tw3435_TSomeLongLongLongTypeName;
  Param8 : tw3435_TSomeLongLongLongTypeName;
  Param9 : tw3435_TSomeLongLongLongTypeName;
  Param10: tw3435_TSomeLongLongLongTypeName;
  Param11: tw3435_TSomeLongLongLongTypeName;
  Param12: tw3435_TSomeLongLongLongTypeName;
  Param13: tw3435_TSomeLongLongLongTypeName;
  Param14: tw3435_TSomeLongLongLongTypeName;
  Param15: tw3435_TSomeLongLongLongTypeName;
  Param16: tw3435_TSomeLongLongLongTypeName;
  Param17: tw3435_TSomeLongLongLongTypeName;
  Param18: tw3435_TSomeLongLongLongTypeName;
  Param19: tw3435_TSomeLongLongLongTypeName;
  Param20: tw3435_TSomeLongLongLongTypeName);
const
  SomeConstant1: array[0..1]of Integer = (0, 1);
  SomeConstant2: array[0..1]of Integer = (0, 1);

  procedure Nested(
  Param1 : tw3435_TSomeLongLongLongTypeName;
  Param2 : tw3435_TSomeLongLongLongTypeName;
  Param3 : tw3435_TSomeLongLongLongTypeName;
  Param4 : tw3435_TSomeLongLongLongTypeName;
  Param5 : tw3435_TSomeLongLongLongTypeName;
  Param6 : tw3435_TSomeLongLongLongTypeName;
  Param7 : tw3435_TSomeLongLongLongTypeName;
  Param8 : tw3435_TSomeLongLongLongTypeName;
  Param9 : tw3435_TSomeLongLongLongTypeName;
  Param10: tw3435_TSomeLongLongLongTypeName;
  Param11: tw3435_TSomeLongLongLongTypeName;
  Param12: tw3435_TSomeLongLongLongTypeName;
  Param13: tw3435_TSomeLongLongLongTypeName;
  Param14: tw3435_TSomeLongLongLongTypeName;
  Param15: tw3435_TSomeLongLongLongTypeName;
  Param16: tw3435_TSomeLongLongLongTypeName;
  Param17: tw3435_TSomeLongLongLongTypeName;
  Param18: tw3435_TSomeLongLongLongTypeName;
  Param19: tw3435_TSomeLongLongLongTypeName;
  Param20: tw3435_TSomeLongLongLongTypeName);
  begin
  end;

begin
end;


{$pop}

{ Case tw3457.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3457 }
{ Submitted by "Ales Katona (Almindor)" on  2004-12-19 }
{ e-mail: ales@chello.sk }


{$inline on}

type tw3457_TTest = class
      private
       procedure testit; inline;
      public // error is reported here
       constructor Create;
     end;

       procedure tw3457_TTest.testit; inline;
       begin
       end;

       constructor tw3457_TTest.Create;
       begin
       end;


{$pop}

{ Case tw37423.pp }
{$push}




{ bug is only triggered when inlining is on }
{$INLINE on}

{

[nickysn@dhcppc1 inline_bug]$ fpc inline_bug
Free Pascal Compiler version 3.2.0 [2020/06/21] for x86_64
Copyright (c) 1993-2020 by Florian Klaempfl and others
Target OS: Linux for x86-64
Compiling inline_bug.pas
Linking inline_bug
/usr/bin/ld: inline_bug.o: in function `P$INLINE_BUG$_$TMODULE_$__$$_DOSTUFF':
inline_bug.pas:(.text.n_p$inline_bug$_$tmodule_$__$$_dostuff+0x59): undefined reference to `.Lj62'
inline_bug.pas(69,1) Error: Error while linking
inline_bug.pas(69,1) Fatal: There were 1 errors compiling module, stopping
Fatal: Compilation aborted
Error: /usr/bin/ppcx64 returned an error exitcode

}

type
  tw37423_TSample = class
  private
    function GetContainsData: Boolean; inline;
  public
    property ContainsData: Boolean read GetContainsData;
  end;
  tw37423_TSampleList = class
  private
    FSampleList: array [1..10] of tw37423_TSample;
    function GetSample(Index: Integer): tw37423_TSample; inline;
  public
    constructor Create;
    property Sample[Index: Integer]: tw37423_TSample read GetSample; default;
  end;
  tw37423_TModule = class
  private
    FSamples: tw37423_TSampleList;
  public
    constructor Create;
    procedure DoStuff;
  end;

function tw37423_TSample.GetContainsData: Boolean; inline;
begin
  Result := False;
end;

constructor tw37423_TSampleList.Create;
var
  I: Integer;
begin
  for I := 1 to 10 do
    FSampleList[I] := tw37423_TSample.Create;
end;

function tw37423_TSampleList.GetSample(Index: Integer): tw37423_TSample; inline;
begin
  if (Index < Low(FSampleList)) or (Index > High(FSampleList)) then
    raise TObject.Create;
  Result := FSampleList[Index];
end;

constructor tw37423_TModule.Create;
begin
  FSamples := tw37423_TSampleList.Create;
end;

procedure tw37423_TModule.DoStuff;
var
  I: Integer;
begin
  for I := 1 to 10 do
    if FSamples[I].ContainsData then
      begin
        Writeln('!!!');
        halt(1);
      end;
end;

var
  tw37423_Module: tw37423_TModule;

{$pop}

{ Case tw3841.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3841 }
{ Submitted by "Joost v.d. Sluis" on  2005-03-28 }
{ e-mail:  }


type tw3841_TMyClass = Class(TObject)
     private
       Function GetInte : Integer;
     public
       property Inte : Integer read GetInte;
     end;

var tw3841_buf     : longint;
    tw3841_MyClass : tw3841_TMyClass;

function tw3841_TMyClass.GetInte : integer;
begin
  Result := 1010;
end;


{$pop}

{ Case tw40745.pp }
{$push}


type
  tw40745_TSetOfChar = set of char;
  tw40745_TMyObject=class
    class function Method(setofchar: tw40745_TSetOfChar): Boolean; inline;
  end;

class function tw40745_TMyObject.Method(setofchar: tw40745_TSetOfChar): Boolean;
var sym: char=#0;
begin
  Result:=sym in setofchar;
end;


{$pop}

{ Case tw9139.pp }
{$push}
{$H+}
{.$define second_test}

type
  tw9139_TTestClass = class of tw9139_TTestBase;

  tw9139_TTestBase = class(TObject)
  public
    class function ClassMetadataStr: string;
    class function InternalMetadataStr: string; virtual;
  end;

  tw9139_TTestImpl = class(tw9139_TTestBase)
  public
    class function InternalMetadataStr: string; override;
  end;

class function tw9139_TTestBase.ClassMetadataStr: string;
var
  VMetadataMethod, VParentMetadataMethod: function: string of object;
{$ifdef second_test}
  VClass: tw9139_TTestClass;
{$endif}
begin
  if Self <> tw9139_TTestBase then
  begin
    writeln('pass 1');
    VMetadataMethod := @InternalMetadataStr;
    writeln('pass 2');
{$ifndef second_test}
    VParentMetadataMethod := @tw9139_TTestClass(ClassParent).InternalMetadataStr;
{$else}
    VClass := tw9139_TTestClass(ClassParent);
    writeln('pass 2.1');
    VParentMetadataMethod := @VClass.InternalMetadataStr;
{$endif}
    writeln('pass 3');
    if TMethod(VMetadataMethod).Code <> TMethod(VParentMetadataMethod).Code then
      begin
        Result := VParentMetadataMethod();
        writeln('result: ',result);
        if Result<>'parent meth' then
          halt(1);
      end
    else
      halt(2);
    writeln('pass 4');
  end else
    Result := 'base result';
end;

class function tw9139_TTestBase.InternalMetadataStr: string;
begin
  Result := 'parent meth';
end;

class function tw9139_TTestImpl.InternalMetadataStr: string;
begin
  Result := 'some stuff';
end;

var
  tw9139_VTestClass: tw9139_TTestClass;

{$pop}

begin

{ Case tb0694.pp }
{$push}

{$warn 4055 off Conversion between ordinals and pointers is not portable}
begin
	tb0694_tlc := nil;
	try
		tb0694_fieldPtr := @tb0694_o1.struct.ary[3].y;
		tb0694_recovered := tb0694_RecoverObject1From3Y(tb0694_fieldPtr);
		if tb0694_recovered <> @tb0694_o1 then
		begin
			writeln('@o1 = ', HexStr(@tb0694_o1), ', @o1.struct.ary[3].y = ', HexStr(tb0694_fieldPtr), ', recovered = ', HexStr(tb0694_recovered));
			halt(1);
		end;

		tb0694_fieldPtr := @tb0694_o1.struct.ary[3].bottomAry.items[4, 5];
		tb0694_recovered := tb0694_RecoverObject1From345(tb0694_fieldPtr);
		if tb0694_recovered <> @tb0694_o1 then
		begin
			writeln('@o1 = ', HexStr(@tb0694_o1), ', @o1.struct.ary[3].bottomAry.items[4, 5] = ', HexStr(tb0694_fieldPtr), ', recovered = ', HexStr(tb0694_recovered));
			halt(2);
		end;

		tb0694_fieldPtr := @tb0694_tla[2].struct.ary[3].y;
		tb0694_recovered := tb0694_RecoverTopLevelArrayFrom23Y(tb0694_fieldPtr);
		if tb0694_recovered <> @tb0694_tla then
		begin
			writeln('@tla = ', HexStr(@tb0694_tla), ', @tla[2].struct.ary[3].y = ', HexStr(tb0694_fieldPtr), ', recovered = ', HexStr(tb0694_recovered));
			halt(3);
		end;

		tb0694_fieldPtr := @tb0694_tla[2].struct.ary[3].bottomAry.items[4, 5];
		tb0694_recovered := tb0694_RecoverTopLevelArrayFrom2345(tb0694_fieldPtr);
		if tb0694_recovered <> @tb0694_tla then
		begin
			writeln('@tla = ', HexStr(@tb0694_tla), ', @tla[2].struct.ary[3].bottomAry.items[4, 5] = ', HexStr(tb0694_fieldPtr), ', recovered = ', HexStr(tb0694_recovered));
			halt(4);
		end;

		tb0694_tlc := tb0694_TopLevelClass.Create;
		tb0694_fieldPtr := @tb0694_tlc.objs[2].struct.ary[3].y;
		tb0694_recovered := tb0694_RecoverTopLevelClassFrom23Y(tb0694_fieldPtr);
		if tb0694_recovered <> pointer(tb0694_tlc) then
		begin
			writeln('tlc = ', HexStr(tb0694_tlc), ', @tlc.objs[2].struct.ary[3].y = ', HexStr(tb0694_fieldPtr), ', recovered = ', HexStr(tb0694_recovered));
			halt(5);
		end;

		tb0694_fieldPtr := @tb0694_tlc.objs[2].struct.ary[3].bottomAry.items[4, 5];
		tb0694_recovered := tb0694_RecoverTopLevelClassFrom2345(tb0694_fieldPtr);
		if tb0694_recovered <> pointer(tb0694_tlc) then
		begin
			writeln('tlc = ', HexStr(tb0694_tlc), ', @tlc.objs[2].struct.ary[3].bottomAry.items[4, 5] = ', HexStr(tb0694_fieldPtr), ', recovered = ', HexStr(tb0694_recovered));
			halt(6);
		end;

		writeln('ok');
	finally
		tb0694_tlc.Free;
	end;
end;
{$pop}

{ Case tb_class_instance_access.pp }
{$push}




begin
  { tw10454.pp }
  tb_class_instance_access_myclass:=tb_class_instance_access_TMyClass.Create;
    tb_class_instance_access_myclass.obj.int:=1; // Crash due to unaligned data access
    tb_class_instance_access_myclass.Free;
  ;

  { tw0934.pp }
  tb_class_instance_access_ti:=tb_class_instance_access_t.Init(1,2);
   writeln(tb_class_instance_access_ti.f1, ', ', tb_class_instance_access_ti.f2); // prints garbage instead of t2
   if tb_class_instance_access_ti.f2<>2 then
     Halt(1);
  ;

  { tw1207.pp }
  tb_class_instance_access_aclass := tb_class_instance_access_AClassType.Create;
    try
      tb_class_instance_access_trychange (tb_class_instance_access_aclass)
    finally
      tb_class_instance_access_aclass.free;
    end;
  ;

  { tw10831.pp }
  tb_class_instance_access_i:=tb_class_instance_access_TMyForm.Create;
  ;
end;
{$pop}

{ Case tb_static_procvars_objfpc.pp }
{$push}


begin
  { tw30936.pp }
  tb_static_procvars_objfpc_TImplicitStaticProc.Create;
  ;

  { tw30936b.pp }
  tb_static_procvars_objfpc_aProc := @tb_static_procvars_objfpc_TExplicitStaticProc.MyProc;
    tb_static_procvars_objfpc_aProc;
  ;
end;
{$pop}

{ Case tw0873a.pp }
{$push}

begin
    writeln('This will be printed');
    tw0873a_Obj := tw0873a_TObjectB.Create;
    writeln('This won''t.');
end;
{$pop}

{ Case tw10493.pp }
{$push}

begin

end;
{$pop}

{ Case tw14403.pp }
{$push}
{$R+}

begin
  tw14403_G := tw14403_TDummyShapeTreeGroup.Create;
  tw14403_G.Child := tw14403_TDummyShape.Create;
  Writeln(tw14403_G.ShapesCount(true, true, false));
  tw14403_G.Free;
end;
{$pop}

{ Case tw1935.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
        tw1935_C := tw1935_TCls.create;
        tw1935_C.build (1, 2, 3);
    if tw1935_err then
     halt(1);
end;
{$pop}

{ Case tw21811.pp }
{$push}

begin
  tw21811_b:=false;
  tw21811_c:=tw21811_tc1.create;
  tw21811_c.q;
  tw21811_c.free;
  if not tw21811_b then
    halt(1);
end;
{$pop}

{ Case tw2480.pp }
{$push}

Begin
End;
{$pop}

{ Case tw2859.pp }
{$push}
{$ifdef fpc}

{$H+}
{$endif}
begin
  tw2859_CreateMyClass.Assign(nil);
  if tw2859_i<>1 then
    begin
      writeln('Error!');
      halt(1);
    end;
end;
{$pop}

{ Case tw29491.pp }
{$push}

{$H+}
begin
  tw29491_O := TTestObject.Create;
  tw29491_Callback := @tw29491_O.Test;
  tw29491_Callback();
  tw29491_O.Free;
end;
{$pop}

{ Case tw29923.pp }
{$push}

{$r+}
begin
  tw29923_c:=tw29923_tc.create;
  tw29923_c.test;
  tw29923_c.free;
end;
{$pop}

{ Case tw3168.pp }
{$push}

begin
end;
{$pop}

{ Case tw3435.pp }
{$push}

begin
end;
{$pop}

{ Case tw3457.pp }
{$push}

{$inline on}
begin
end;
{$pop}

{ Case tw37423.pp }
{$push}

{$INLINE on}
begin
  tw37423_Module := tw37423_TModule.Create;
  tw37423_Module.DoStuff;
end;
{$pop}

{ Case tw3841.pp }
{$push}

begin
  tw3841_MyClass.Create;
  move(tw3841_MyClass.inte,tw3841_buf,sizeof(longint));
end;
{$pop}

{ Case tw40745.pp }
{$push}

begin
  tw40745_TMyObject.Method([]);
end;
{$pop}

{ Case tw9139.pp }
{$push}

{$H+}
{$ifdef second_test}
{$endif}
{$ifndef second_test}
{$else}
{$endif}
begin
  tw9139_VTestClass := tw9139_TTestBase;
  writeln('TTestBase result:');
  writeln(tw9139_VTestClass.ClassMetadataStr);
  writeln;
  tw9139_VTestClass := tw9139_TTestImpl;
  writeln('TTestImpl result:');
  writeln(tw9139_VTestClass.ClassMetadataStr);
end;
{$pop}

end.
