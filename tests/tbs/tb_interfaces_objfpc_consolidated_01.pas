{ Consolidated interfaces regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb0396.pas }
{$push}
{$ifdef fpc}{$endif}
type
   tb0396_to2 = interface
     function bufwrite(eat : boolean = true) : integer;stdcall;
   end;


{$pop}

{ Case tb_interfaces_objfpc_run_01.pas }
{$push}
{ Interfaces regression cases; original case IDs are retained below. }

{ Case tb0351.pas }
{$push}

type
   tb0351_i = interface;

   tb0351_i = interface
   end;
{$pop}

{ Case tb0372.pas }
{$push}
{$ifdef fpc}{$endif}
{$J+}

type
   tb0372_imyinterface = interface
      // this program isn't supposed to run so the guid doesn't matter }
      ['{00000000-0000-0000-0000-000000000000}']
      procedure tb0372_p;
   end;

const
   tb0372_iid_imyinterface = tb0372_imyinterface;
   tb0372_iid2 : tguid = '{00000000-0000-0000-0000-000000000000}';

var
   tb0372_g : tguid;
{$pop}

{ Case tb0375.pas }
{$push}
{$ifdef fpc}{$endif}

type
   tb0375_i1 = interface
      procedure tb0375_intfp;
   end;

   tb0375_tc1 = class(tinterfacedobject,tb0375_i1)
      procedure tb0375_i1.tb0375_intfp = tb0375_p;
      procedure tb0375_p;
   end;

procedure tb0375_tc1.tb0375_p;

  begin
  end;
{$pop}

{ Case tb0459.pas }
{$push}

Type
  tb0459_imyinterface = Interface
    Function tb0459_myfunc : Integer;
  end;

  tb0459_tmyclass = Class(TInterfacedObject,tb0459_imyinterface)
    Function tb0459_myotherfunction : Integer;
    // The following fails in FPC.
    Function tb0459_imyinterface.tb0459_myfunc = tb0459_myotherfunction;
  end;

Function tb0459_tmyclass.tb0459_myotherfunction : Integer;

begin
  Result:=23;
end;

Var
  tb0459_a : tb0459_tmyclass;
  tb0459_m : tb0459_imyinterface;
  tb0459_i : Integer;
{$pop}

{ Case tw1825.pas }
{$push}


{ Source provided for Free Pascal Bug Report 1825 }
{ Submitted by "marcov" on  2002-02-19 }
{ e-mail: marco@freepascal.org }

Type
    tw1825_ienummoniker = Interface (IUnknown)
       ['{00000102-0000-0000-C000-000000000046}']
       End;
{$pop}

{ Case tw25269.pas }
{$push}


type
  tw25269_imyinterface = interface
    procedure tw25269_test(a, b: Integer);
  end;
  tw25269_tmybaseclass = class(TInterfacedObject, tw25269_imyinterface)
    procedure tw25269_test(a, b: Integer); virtual; abstract;
  end;
  tw25269_tdescendent = class(tw25269_tmybaseclass)
    procedure tw25269_test(a, b: Integer); override;
  end;

var
  tw25269_global_a, tw25269_global_b: Integer;

procedure tw25269_tdescendent.tw25269_test(a, b: Integer);
begin
  tw25269_global_a := a;
  tw25269_global_b := b;
end;

var
  tw25269_q: tw25269_imyinterface;
{$pop}


{$pop}

{ Case tw19180.pas }
{$push}


{$H+}


type

  tw19180_IGMGetFileName = interface(IUnknown)
    ['{D3ECCB42-A563-4cc4-B375-79931031ECBA}']
    function GetFileName: String; stdcall;
    property FileName: String read GetFileName;
  end;


  tw19180_IGMGetHandle = interface(IUnknown)
    ['{5BB45961-15A9-11d5-A5E4-00E0987755DD}']
    function GetHandle: THandle; stdcall;
    property Handle: THandle read GetHandle;
  end;


  { TImplementor }

  tw19180_TImplementor = class(TObject, tw19180_IGMGetFileName, tw19180_IGMGetHandle)
   protected
    FController: Tobject;

   public
    constructor Create(const AController: TObject);

    function QueryInterface(constref IID: TGUID; out Intf): HResult; virtual; {$ifdef windows}stdcall{$else}cdecl{$endif};
    function _AddRef: LongInt; virtual; {$ifdef windows}stdcall{$else}cdecl{$endif};
    function _Release: LongInt; virtual; {$ifdef windows}stdcall{$else}cdecl{$endif};

    function GetHandle: THandle; stdcall;
    function GetFileName: String; stdcall;
  end;

  { TDelegator }

  tw19180_TDelegator = class(TInterfacedObject, tw19180_IGMGetFileName) // IGMGetHandle
   protected
    FImplementor: tw19180_TImplementor;
    FGetFileName: tw19180_IGMGetFileName;

   public
    constructor Create;
    destructor Destroy;

    //
    // This crashes
    //
    property Implementor: tw19180_TImplementor read FImplementor implements tw19180_IGMGetFileName;

    //
    // This works
    //
    //property Implementor: IGMGetFileName read FGetFileName implements IGMGetFileName;

    //
    // This is what i really need
    //
    //property Implementor: TImplementor read FImplementor implements IGMGetFileName, IGMGetHandle;
  end;


{ TImplementor }

constructor tw19180_TImplementor.Create(const AController: TObject);
begin
  FController := AController;
end;

function tw19180_TImplementor.QueryInterface(constref IID: TGUID; out Intf): HResult; {$ifdef windows}stdcall{$else}cdecl{$endif};
var PIUnkController: IUnknown;
begin
  if GetInterface(IID, Intf) then Result := S_OK else
   if (FController <> nil) and FController.GetInterface(IUnknown, PIUnkController) then
    Result := PIUnkController.QueryInterface(IID, Intf) else Result := E_NOINTERFACE;
end;

function tw19180_TImplementor._AddRef: LongInt; {$ifdef windows}stdcall{$else}cdecl{$endif};
var PIUnkController: IUnknown;
begin
  if (FController <> nil) and FController.GetInterface(IUnknown, PIUnkController) then
   Result := PIUnkController._AddRef
end;

function tw19180_TImplementor._Release: LongInt; {$ifdef windows}stdcall{$else}cdecl{$endif};
var PIUnkController: IUnknown;
begin
  if (FController <> nil) and FController.GetInterface(IUnknown, PIUnkController) then
   Result := PIUnkController._Release
end;

function tw19180_TImplementor.GetHandle: THandle; stdcall;
begin
  Result := 0;
end;

function tw19180_TImplementor.GetFileName: String; stdcall;
begin
  Result := '';
end;


{ TDelegator }

constructor tw19180_TDelegator.Create;
begin
  FImplementor := tw19180_TImplementor.Create(Self);
  FGetFileName := FImplementor;
end;

destructor tw19180_TDelegator.Destroy;
begin
  FImplementor.Free;;
end;


var tw19180_PIUnk: IUnknown; tw19180_PIGetFileNAme: tw19180_IGMGetFileName;

{$pop}

{ Case tw19182.pas }
{$push}

{$h+}

type
  tw19182_IGMGetHandle = interface(IUnknown)
    ['{5BB45961-15A9-11d5-A5E4-00E0987755DD}']
    function GetHandle: THandle; stdcall;
    property Handle: THandle read GetHandle;
  end;

  tw19182_IGMGetFileName = interface(IUnknown)
    ['{D3ECCB42-A563-4cc4-B375-79931031ECBA}']
    function GetFileName: String; stdcall;
    property FileName: String read GetFileName;
  end;

  tw19182_IGMGetSetFileName = Interface(tw19182_IGMGetFileName)
    ['{ECFB879F-86F6-41a3-A685-0C899A2B5BCA}']
    procedure SetFileName(const Value: String); stdcall;
    property FileName: String read GetFileName write SetFileName;
  end;


  { TImplementor }

  tw19182_TImplementor = class(TObject, tw19182_IGMGetHandle, tw19182_IGMGetFileName, tw19182_IGMGetSetFileName)
   protected
    FController: Tobject;

   public
    constructor Create(const AController: TObject);

    function QueryInterface(constref IID: TGUID; out Intf): HResult; virtual; {$ifdef windows}stdcall{$else}cdecl{$endif};
    function _AddRef: LongInt; virtual; {$ifdef windows}stdcall{$else}cdecl{$endif};
    function _Release: LongInt; virtual; {$ifdef windows}stdcall{$else}cdecl{$endif};

    function GetHandle: THandle; stdcall;
    function GetFileName: String; stdcall;
    procedure SetFileName(const Value: String); stdcall;
  end;


  { TIntfDelegator }

  tw19182_TIntfDelegator = class(TInterfacedObject, tw19182_IGMGetFileName, tw19182_IGMGetSetFileName)
   protected
    FImplementor: tw19182_TImplementor;
    FGetSetFileName: tw19182_IGMGetSetFileName;

   public
    constructor Create;
    destructor Destroy; override;

    //
    // This would be nice. NOTE: IGMGetFileName is derived from IGMGetSetFileName!
    //
    property Implementor: tw19182_IGMGetSetFileName read FGetSetFileName implements tw19182_IGMGetFileName, tw19182_IGMGetSetFileName;
  end;


  { TObjDelegator }

  tw19182_TObjDelegator = class(TInterfacedObject, tw19182_IGMGetHandle, tw19182_IGMGetFileName, tw19182_IGMGetSetFileName)
   protected
    FImplementor: tw19182_TImplementor;

   public
    constructor Create;
    destructor Destroy; override;

    //
    // This would be really smart!
    //
    property Implementor: tw19182_TImplementor read FImplementor implements tw19182_IGMGetHandle, tw19182_IGMGetFileName, tw19182_IGMGetSetFileName;
  end;



{ TImplementor }

constructor tw19182_TImplementor.Create(const AController: TObject);
begin
  FController := AController;
end;

function tw19182_TImplementor.QueryInterface(constref IID: TGUID; out Intf): HResult; {$ifdef windows}stdcall{$else}cdecl{$endif};
var PIUnkController: IUnknown;
begin
  if GetInterface(IID, Intf) then Result := S_OK else
   if (FController <> nil) and FController.GetInterface(IUnknown, PIUnkController) then
    Result := PIUnkController.QueryInterface(IID, Intf) else Result := E_NOINTERFACE;
end;

function tw19182_TImplementor._AddRef: LongInt; {$ifdef windows}stdcall{$else}cdecl{$endif};
var PIUnkController: IUnknown;
begin
  if (FController <> nil) and FController.GetInterface(IUnknown, PIUnkController) then
   Result := PIUnkController._AddRef
end;

function tw19182_TImplementor._Release: LongInt; {$ifdef windows}stdcall{$else}cdecl{$endif};
var PIUnkController: IUnknown;
begin
  if (FController <> nil) and FController.GetInterface(IUnknown, PIUnkController) then
   Result := PIUnkController._Release
end;

function tw19182_TImplementor.GetHandle: THandle; stdcall;
begin
  writeln('TImplementor.GetHandle');
  Result := 0;
end;

function tw19182_TImplementor.GetFileName: String; stdcall;
begin
  writeln('TImplementor.GetFileName');
  Result := '';
end;

procedure tw19182_TImplementor.SetFileName(const Value: String); stdcall;
begin
  writeln('TImplementor.SetFileName');
end;


{ TIntfDelegator }

constructor tw19182_TIntfDelegator.Create;
begin
  FImplementor := tw19182_TImplementor.Create(Self);
  FGetSetFileName := FImplementor;
end;

destructor tw19182_TIntfDelegator.Destroy;
begin
  FImplementor.Free;
  inherited Destroy;
end;


{ TObjDelegator }

constructor tw19182_TObjDelegator.Create;
begin
  FImplementor := tw19182_TImplementor.Create(Self);
end;

destructor tw19182_TObjDelegator.Destroy;
begin
  FImplementor.Free;
  inherited Destroy;
end;


var
  tw19182_PIUnk: IUnknown;
  tw19182_PIGetFileNAme: tw19182_IGMGetFileName;
  tw19182_PIGetSetFileName: tw19182_IGMGetSetFileName;
  tw19182_obj: tw19182_TObjDelegator;

{$pop}

{ Case tw2649.pas }
{$push}

type
  tw2649_IADsDisp = dispinterface
    ['{FD8256D0-FD15-11CE-ABC4-02608C9E7553}']
    property Name: WideString readonly dispid 2;
    property Class_: WideString readonly dispid 3;
    property GUID: WideString readonly dispid 4;
    property ADsPath: WideString readonly dispid 5;
    property Parent: WideString readonly dispid 6;
    property Schema: WideString readonly dispid 7;
    procedure GetInfo; dispid 8;
    procedure SetInfo; dispid 9;
    function  Get(const bstrName: WideString): OleVariant; dispid 10;
    procedure Put(const bstrName: WideString; vProp: OleVariant); dispid 11;
    function  GetEx(const bstrName: WideString): OleVariant; dispid 12;
    procedure PutEx(lnControlCode: Integer; const bstrName: WideString; vProp: OleVariant); dispid 13;
    procedure GetInfoEx(vProperties: OleVariant; lnReserved: Integer); dispid 14;
  end;


{$pop}

{ Case tw9306a.pas }
{$push}


type
  tw9306a_IIntf = interface
    function Foo(const S: string): string;
  end;

  tw9306a_IIntf2 = interface(tw9306a_IIntf)
    function Foo(const S: string): Integer;
  end;

  tw9306a_TIntf = class(TInterfacedObject, tw9306a_IIntf)
  protected
    { IIntf }
    function Foo(const S: string): string;
  end;

  tw9306a_TIntf2 = class(tw9306a_TIntf, tw9306a_IIntf2)
  public
    { IIntf2 }
    function Foo(const S: string): Integer; overload;
  end;

var
  tw9306a_erridx : longint;

{ TIntf }

function tw9306a_TIntf.Foo(const S: string): string;
begin
  writeln('TIntf.Foo: ',S);
  if tw9306a_erridx=0 then
    tw9306a_erridx:=1;
  result:=S;
end;

{ TIntf2 }

function tw9306a_TIntf2.Foo(const S: string): Integer;
begin
  writeln('TIntf2.Foo: ',S);
  if tw9306a_erridx=1 then
    tw9306a_erridx:=2;
  result:=0;
end;

var
  tw9306a_i1 : tw9306a_IIntf;
  tw9306a_i2 : tw9306a_IIntf2;

{$pop}

begin

{ Case tb0396.pas }
{$push}
{$ifdef fpc}

{$endif}
begin
end;
{$pop}

{ Case tb_interfaces_objfpc_run_01.pas }
{$push}
{$push}

{$pop}
{$push}
{$ifdef fpc}

{$endif}
{$J+}
{$pop}
{$push}
{$ifdef fpc}

{$endif}
{$pop}
{$push}

{$pop}
{$push}

{$pop}
{$push}

{$pop}
begin
  { Case tb0372.pas }
  {$push}
{$ifdef fpc}
{$endif}
{$J+}
  begin
tb0372_g:=tb0372_imyinterface;
   tb0372_g:=tb0372_iid_imyinterface;
   tb0372_g:=tb0372_iid2;
   tb0372_iid2:=tb0372_iid_imyinterface;
  end;
  {$pop}

  { Case tb0459.pas }
  {$push}

  begin
tb0459_a:=tb0459_tmyclass.Create;
  tb0459_m:=tb0459_a;
  tb0459_i:=tb0459_m.tb0459_myfunc;
  If (tb0459_i<>23) then
    begin
    Writeln('Error calling interface');
    Halt(1);
    end;
  end;
  {$pop}

  { Case tw25269.pas }
  {$push}

  begin
tw25269_q := tw25269_tdescendent.Create;
  tw25269_q.tw25269_test(18, 42);
  if (tw25269_global_a <> 18) or (tw25269_global_b <> 42) then
    halt(1);
  Writeln('Ok!');
  end;
  {$pop}

end;
{$pop}

{ Case tw19180.pas }
{$push}

{$H+}
{$ifdef windows}
{$else}
{$endif}
{$ifdef windows}
{$else}
{$endif}
{$ifdef windows}
{$else}
{$endif}
{$ifdef windows}
{$else}
{$endif}
{$ifdef windows}
{$else}
{$endif}
{$ifdef windows}
{$else}
{$endif}
begin
  tw19180_PIUnk := tw19180_TDelegator.Create;
  tw19180_PIUnk.QueryInterface(tw19180_IGMGetFileName, tw19180_PIGetFileNAme);
end;
{$pop}

{ Case tw19182.pas }
{$push}

{$h+}
{$ifdef windows}
{$else}
{$endif}
{$ifdef windows}
{$else}
{$endif}
{$ifdef windows}
{$else}
{$endif}
{$ifdef windows}
{$else}
{$endif}
{$ifdef windows}
{$else}
{$endif}
{$ifdef windows}
{$else}
{$endif}
begin
  tw19182_PIUnk := tw19182_TIntfDelegator.Create;
  tw19182_PIUnk.QueryInterface(tw19182_IGMGetFileName, tw19182_PIGetFileName);
  tw19182_PIGetFileName.GetFileName;
  tw19182_PIUnk.QueryInterface(tw19182_IGMGetSetFileName, tw19182_PIGetSetFileName);
  tw19182_PIGetSetFileName.SetFileName('');

  tw19182_obj := tw19182_TObjDelegator.Create;
  (tw19182_obj as tw19182_IGMGetFileName).GetFileName;
  (tw19182_obj as tw19182_IGMGetSetFileName).SetFileName('');
  (tw19182_obj as tw19182_IGMGetHandle).GetHandle;
end;
{$pop}

{ Case tw2649.pas }
{$push}

begin
end;
{$pop}

{ Case tw9306a.pas }
{$push}

begin
  tw9306a_erridx:=0;

  tw9306a_i1:=tw9306a_TIntf2.Create;
  tw9306a_i1.Foo('1234');

  tw9306a_i2:=tw9306a_TIntf2.Create;
  tw9306a_i2.Foo('1234');
  if tw9306a_erridx<>2 then
    begin
      writeln('Error');
      halt(1);
    end;
end;
{$pop}

end.
