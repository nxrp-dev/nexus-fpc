{ Consolidated interfaces regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tw18610.pp }
{$push}


{$H+}

type
  tw18610_IInt = interface
    procedure Test;
  end;

  tw18610_TParent = class
  private
    type
      TChild = class(TInterfacedObject, tw18610_IInt)
      public
        procedure Test;
      end;
  end;

procedure tw18610_TParent.TChild.Test;
begin
end;



{$pop}

{ Case tw2727.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2727 }
{ Submitted by "marco (the gory bugs department)" on  2003-10-08 }
{ e-mail:  }




type
  tw2727_IPersistenceCapable = interface
    ['{A7F3DA50-93BF-4EAF-B40C-8F5020E5D890}']
    function GetSelf: TObject;
    property Self: TObject read GetSelf;
  end;

  tw2727_TPersistenceCapable = class(TInterfacedObject, tw2727_IPersistenceCapable)
   function GetSelf: TObject;
   function nonsense:boolean;
  end;

function tw2727_TPersistenceCapable.GetSelf: TObject;
begin
  result:=nil;
end;

function tw2727_TPersistenceCapable.nonsense:boolean;
{this works fine if it isn't a method....}

var
  lSource: tw2727_IPersistenceCapable;

begin
     result:=(lSource.Self is tw2727_TPersistenceCapable)
end;



{$pop}

{ Case tw3183.pp }
{$push}
{$ifdef fpc}{$endif}

type
  tw3183_IA=interface
   function copy:String;
  end;

  tw3183_IB=interface(tw3183_IA)
   function copy:integer;
  end;


{$pop}

{ Case tw3489.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3489 }
{ Submitted by "Danny Milosavljevic" on  2004-12-28 }
{ e-mail: danny_milo@yahoo.com }


{$ifdef fpc}{$endif}

var
  tw3489_err : boolean;

type
  tw3489_IGtkObject = interface
    ['{C4741871-56EB-4A5C-BDC8-018992345B24}']
    procedure Destroy1();
  end;
  tw3489_IGtkWidget = interface(tw3489_IGtkObject)
    ['{210BF9BD-232D-43D5-9ECA-94B8AB2734E5}']

     procedure Destroy1();
     procedure Show();
     procedure Hide();
  end;

  tw3489_DGtkObject = class(TInterfacedObject, tw3489_IGtkObject, IInterface)
  public
     procedure Destroy1();
  end;

  tw3489_DGtkWidget = class(tw3489_DGtkObject, tw3489_IGtkWidget, tw3489_IGtkObject, IInterface)
  public
    constructor CreateWrapped(a:Pointer);
     procedure Destroy1();
     procedure Show();
     procedure Hide();
  end;

procedure tw3489_DGtkObject.Destroy1();
begin
end;

constructor tw3489_DGtkWidget.CreateWrapped(a:Pointer);
begin
end;

procedure tw3489_DGtkWidget.Destroy1();
begin
end;

procedure tw3489_DGtkWidget.Show();
begin
  Writeln('Show');
  tw3489_err:=false;
end;

procedure tw3489_DGtkWidget.Hide();
begin
  Writeln('Hide');
end;

var
  tw3489_w: tw3489_IGtkWidget;

{$pop}

{ Case tw35233.pp }
{$push}
//
// Submitted by:
//
// Gerrit Moeller
// [private]@gm-software.de
// www.gm-software.de
//

 // <- Without delphi mode the parser correctly issues an error if stdcall is not repeated
               // in overriding method (see below).



type

  tw35233_ISomeMethod = interface(IUnknown)
    ['{DBFB482B-76FB-4DB7-A321-1001755B1F9E}']
    function SomeMethod(const AIntArg: Integer; const AStrArg: WideString): IUnknown; stdcall;
  end;


  tw35233_TBaseClassImpl = class(TInterfacedObject, tw35233_ISomeMethod)
   public
    function SomeMethod(const AIntArg: Integer; const AStrArg: WideString): IUnknown; virtual; stdcall;
  end;


  tw35233_TDerivedClassImpl = class(tw35233_TBaseClassImpl)
  public
   //
   // In delphi mode it is not necessary to repeat stdcall calling convention in the overriding method.
   // But the compiler then generates a call stack with another calling convention for the overriding method!
   // If you call the overriding method through an interface this crashes (SIGSEV) since it is supposed to be stdcall!
   // Repeating the calling convention in the overriding method fixes the crash.
   //
   function SomeMethod(const AIntArg: Integer; const AStrArg: WideString): IUnknown; override; // stdcall; // <- uncommenting stdcall fixes the crash
  end;


function tw35233_TBaseClassImpl.SomeMethod(const AIntArg: Integer; const AStrArg: WideString): IUnknown; stdcall;
begin
  // Arguments corrupt here due to call stack mismatch!
  Result := nil; // <- SIGSEV crash here due to call stack mismatch!
end;

function tw35233_TDerivedClassImpl.SomeMethod(const AIntArg: Integer; const AStrArg: WideString): IUnknown;
begin
  // Arguments corrupt here due to call stack mismatch!
 Result := inherited SomeMethod(AIntArg, AStrArg);
end;


procedure tw35233_Main;
var methodIntf: tw35233_ISomeMethod; unk: IUnknown;
begin
  methodIntf := tw35233_TDerivedClassImpl.Create;
  unk := methodIntf.SomeMethod(100, 'Some string contents');
end;



{$pop}

{ Case tw3583.pp }
{$push}

type
  tw3583_IGUserData = interface(IInvokable)
    ['{35377B66-6B1B-11D9-8827-00055DDDEA00}']
    (* userdata *)
    function GetUserData(key: UTF8String): IInterface;
    procedure SetUserData(key: UTF8String; const v: IInterface);

    function GetUserDataVariant(key: UTF8String): Variant;
    procedure SetUserDataVariant(key: UTF8String; const v: Variant);

    property UserData[key: UTF8String]: IInterface read GetUserData write SetUserData;
  end;

{$pop}

{ Case tw4950.pp }
{$push}
// This code is provided bt Leandro Conde [leandor@gmail.com]
// to demonstrate a problem with function redirection in interfaces
// in the FPC compiler version 2.0.2
//
// In the real implementation is used to provide a set of data type
// conversion functions: From<Type> and To<Type>.
// In that scenario, the IBase contains functions specific por <Type>,
// and the Derived are the <From> and <To> parts.





var
  tw4950_cnt : longint;

type
  // It really doesn't matters what this interface contains,
  // is just represent some functionality set that is provided
  // with two complementary sets of implementations.
  tw4950_IBase = interface
    ['{6CEA50E0-1844-405F-9B6F-2E9D50BE6EFC}']
    function Base1(const Arg1: string; const Arg2: Double): Boolean;
    function Base2(const Arg1: TDateTime; const Arg2: Single): Boolean;
    function Base3(const Arg1: WideString; const Arg2: Integer): Boolean;
  end;

  // Derived 1 to provide an IBase with a specific functionality when used from IDerived1
  tw4950_IDerived1 = interface (tw4950_IBase)
    ['{3DC49E1B-9A52-499E-8BCD-E1BA160329C9}']
    function Derived1Specific(Arg1: Integer): Integer;
  end;

  // Derived 2 to provide an IBase with a complementary functionality when used from IDerived2
  tw4950_IDerived2 = interface (tw4950_IBase)
    ['{E44DF3BC-75C8-4284-928B-DE3162347C21}']
    function Derived2Specific(Arg1: Integer): Integer;
  end;

  // Just for runtime testing purposes
  tw4950_ITestCase = interface
    ['{C608134F-2F9A-44A4-8932-F169EF40E177}']
    function Derived1: tw4950_IDerived1;
    function Derived2: tw4950_IDerived2;
  end;

type
  // Implementing all the above stuff
  tw4950_TTestCase = class(TInterfacedObject, tw4950_IDerived1, tw4950_IDerived2, tw4950_ITestCase )
  protected
    // methods from IBase in IDerived1 redirected to one function set:
    function tw4950_IDerived1.Base1 = Derived1_Base1;
    function tw4950_IDerived1.Base2 = Derived1_Base2;
    function tw4950_IDerived1.Base3 = Derived1_Base3;
    // this is the function set for IBase in IDerived1
    function Derived1_Base1(const Arg1: string; const Arg2: Double): Boolean;
    function Derived1_Base2(const Arg1: TDateTime; const Arg2: Single): Boolean;
    function Derived1_Base3(const Arg1: WideString; const Arg2: Integer): Boolean;
    // specifics from IDerived1
    function Derived1Specific(Arg1: Integer): Integer;
  protected
    // methods from IBase in IDerived2 redirected to the other function set:
    function tw4950_IDerived2.Base1 = Derived2_Base1;
    function tw4950_IDerived2.Base2 = Derived2_Base2;
    function tw4950_IDerived2.Base3 = Derived2_Base3;
    // this is the function set for IBase in IDerived2
    function Derived2_Base1(const Arg1: string; const Arg2: Double): Boolean;
    function Derived2_Base2(const Arg1: TDateTime; const Arg2: Single): Boolean;
    function Derived2_Base3(const Arg1: WideString; const Arg2: Integer): Boolean;
    // specifics from IDerived2
    function Derived2Specific(Arg1: Integer): Integer;
  protected // this is not essential, just for testing in runtime ITestCase
    function Derived1: tw4950_IDerived1;
    function Derived2: tw4950_IDerived2;
  end;

{ TTestCase }

function tw4950_TTestCase.Derived1_Base1(const Arg1: string; const Arg2: Double): Boolean;
begin
  Result := True;
  writeln('1:',arg1,arg2);
  inc(tw4950_cnt);
end;

function tw4950_TTestCase.Derived1_Base2(const Arg1: TDateTime; const Arg2: Single): Boolean;
begin
  Result := True;
end;

function tw4950_TTestCase.Derived1_Base3(const Arg1: WideString; const Arg2: Integer): Boolean;
begin
  Result := True;
end;

function tw4950_TTestCase.Derived1Specific(Arg1: Integer): Integer;
begin
  Result := Arg1;
end;

function tw4950_TTestCase.Derived2_Base1(const Arg1: string; const Arg2: Double): Boolean;
begin
  Result := True;
  writeln('2:',arg1,arg2);
  inc(tw4950_cnt);
end;

function tw4950_TTestCase.Derived2_Base2(const Arg1: TDateTime; const Arg2: Single): Boolean;
begin
  Result := True;
end;

function tw4950_TTestCase.Derived2_Base3(const Arg1: WideString; const Arg2: Integer): Boolean;
begin
  Result := True;
end;

function tw4950_TTestCase.Derived2Specific(Arg1: Integer): Integer;
begin
  Result := Arg1;
end;

function tw4950_TTestCase.Derived1: tw4950_IDerived1;
begin
  Result := Self;
end;

function tw4950_TTestCase.Derived2: tw4950_IDerived2;
begin
  Result := Self;
end;

var
  tw4950_TestCase: tw4950_ITestCase;

{$pop}

{ Case tw9306b.pp }
{$push}


type
  tw9306b_IIntf = interface
    function Foo(const S: string): string;
  end;

  tw9306b_IIntf2 = interface(tw9306b_IIntf)
    function Foo(const S: string): Integer;
  end;

  tw9306b_TIntf = class(TInterfacedObject, tw9306b_IIntf)
  protected
    { IIntf }
    function Foo(const S: string): string;
  end;

  tw9306b_TIntf2 = class(tw9306b_TIntf, tw9306b_IIntf2)
  public
    { IIntf2 }
    function Foo(const S: string): Integer; overload;
  end;

var
  tw9306b_erridx : longint;

{ TIntf }

function tw9306b_TIntf.Foo(const S: string): string;
begin
  writeln('TIntf.Foo: ',S);
  if tw9306b_erridx=0 then
    tw9306b_erridx:=1;
  result:=S;
end;

{ TIntf2 }

function tw9306b_TIntf2.Foo(const S: string): Integer;
begin
  writeln('TIntf2.Foo: ',S);
  if tw9306b_erridx=1 then
    tw9306b_erridx:=2;
  result:=0;
end;

var
  tw9306b_i1 : tw9306b_IIntf;
  tw9306b_i2 : tw9306b_IIntf2;

{$pop}

begin

{ Case tw18610.pp }
{$push}

{$H+}
begin
end;
{$pop}

{ Case tw2727.pp }
{$push}

begin
end;
{$pop}

{ Case tw3183.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tw3489.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tw3489_err:=true;
  tw3489_w := tw3489_DGtkWidget.CreateWrapped(nil);
  tw3489_w.Show();
  if tw3489_err then
    halt(1);
end;
{$pop}

{ Case tw35233.pp }
{$push}

begin
  tw35233_Main;
end;
{$pop}

{ Case tw3583.pp }
{$push}

begin
end;
{$pop}

{ Case tw4950.pp }
{$push}

begin
  tw4950_TestCase := tw4950_TTestCase.Create;

  tw4950_TestCase.Derived1.Base1('called from derived1', 3.14159);
  tw4950_TestCase.Derived2.Base1('called from derived2', 2.7178);
  if tw4950_cnt<>2 then
    halt(1);
end;
{$pop}

{ Case tw9306b.pp }
{$push}

begin
  tw9306b_erridx:=0;

  tw9306b_i1:=tw9306b_TIntf2.Create;
  tw9306b_i1.Foo('1234');

  tw9306b_i2:=tw9306b_TIntf2.Create;
  tw9306b_i2.Foo('1234');
  if tw9306b_erridx<>2 then
    begin
      writeln('Error');
      halt(1);
    end;
end;
{$pop}

end.
