{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}
uses classes;

{ Case tb_method_callbacks_delphi_run_01.pp }
{$push}
{ Assigned method pointers, event properties and procedure-of-object fields. }
{ Original case IDs and variable scopes are retained below. }





{ Case tb0455.pp }
{$push}
{$IFDEF FPC}

{$ENDIF}
type
  tb0455_hdc = Cardinal;

    tb0455_tnotifyeventa    = procedure (Sender:TObject) of object;

   tb0455_twolbrushes = class
   public
     FOnChange  :tb0455_tnotifyeventa;
     procedure Wol_Changed;
     property OnChange  :tb0455_tnotifyeventa      read FOnChange      Write FOnChange;
   end;


   tb0455_twolbetaobject = class
   public
     mylocalvar : integer;
     constructor Create(AOwner:TOBject);
   protected
     procedure DoBrushChange(Sender:TObject);
   private
     FBrush : tb0455_twolbrushes;
   end;


  procedure tb0455_twolbetaobject.DoBrushChange(Sender:TObject);
  var DC:tb0455_hdc;
  begin
    mylocalvar:=12;
    WriteLn('OK!');
  end;


  procedure tb0455_twolbrushes.WOL_Changed;
  begin
    if Assigned(FOnChange) then FOnChange(Self);
  end;




constructor tb0455_twolbetaobject.Create(AOwner:TOBject);
   begin
     Inherited Create;
     FBrush         :=tb0455_twolbrushes.Create;
     FBrush.OnChange:=DoBrushChange;
   end;


var
 tb0455_cla1: tb0455_twolbetaobject;
{$pop}

{ Case tb0477.pp }
{$push}
type
  tb0477_tproc = procedure of object;

  tb0477_ttest = class
  public
    proc: tb0477_tproc;
    constructor Create;
    procedure foo;
    procedure bar;
  end;

constructor tb0477_ttest.Create;
begin
  inherited;
  proc := nil;
end;

procedure tb0477_ttest.foo;
begin
  writeln('foo');
end;

procedure tb0477_ttest.bar;
begin
  if @proc <> nil then proc;
end;

var
  tb0477_t: tb0477_ttest;
{$pop}


{$pop}

{ Case tw2588.pp }
{$push}




type
    tw2588_TNotifyEventA    = procedure (Sender:TObject) of object;
   TWOLBetaObject = class;

   TwolBrushes = class(TPersistent)
   private
     FOnChange  :tw2588_TNotifyEventA;
   public
     property OnChange  :tw2588_TNotifyEventA      read FOnChange      Write FOnChange;
   end;


   TWOLBetaObject = class(TComponent)
   public
     constructor Create(AOwner:TComponent);
   protected
     procedure DoBrushChange(Sender:TObject);
   private
     FBrush : TWolBrushes;
   end;


  procedure TWOLBetaObject.DoBrushChange(Sender:TObject);
  var DC:longint;
  begin
  end;

constructor TWOLBetaObject.Create(AOwner:TComponent);
   begin
     FBrush         :=TWOLBrushes.Create;
     FBrush.OnChange:=DoBrushChange;
   end;



{$pop}

{ Case tw2702.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2702 }
{ Submitted by "Johannes Berg" on  2003-10-01 }
{ e-mail: johannes -at- sipsolutions -dot- de }




type
  tw2702_TDummy = class(TObject)
  end;
  tw2702_TF = class(TObject)
    function GetDummy: tw2702_TDummy; virtual; abstract;
    property dummy: tw2702_TDummy read GetDummy;
    procedure dada;
  end;

procedure tw2702_TF.dada;
begin
  if Assigned(dummy) then begin
  end;
end;



{$pop}

{ Case tw2725.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2725 }
{ Submitted by "marco" on  2003-10-08 }
{ e-mail:  }





type
  tw2725_TBitSet = class(TBits)
    constructor Create(aSize: integer);
  end;

{ TBitSet }

constructor tw2725_TBitSet.Create(aSize: integer);
begin
  inherited Create;
  Size := aSize;
end;


{$pop}

{ Case tw2958.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2958 }
{ Submitted by "Marco ( Gory Bugs Department)" on  2004-02-08 }
{ e-mail:  }




type

  tw2958_TIdHash = class(TObject);

  TIdHash32 = class(tw2958_TIdHash)
  public
    function HashValue(const ASrc: string): LongWord; overload;
    function HashValue(AStream: TStream): LongWord; overload; virtual; abstract;
  end;

  TIdHashCRC32 = class( TIdHash32 )
  public
    function HashValue( AStream: TStream ) : LongWord; override;
    function HashValue( AStream: TStream; const ABeginPos: Cardinal{=0}; const AEndPos : Cardinal{=0} ) : LongWord; overload;
  end;


function tidhash32.hashvalue(const ASrc:string):longword;

begin
end;

function tidhashCRC32.hashvalue(AStream:TStream):longword;

begin
end;

function tidhashcrc32.hashvalue(AStream:TStream;const ABeginPos: Cardinal{=0}; const AEndPos : Cardinal{=0} ) : LongWord;

begin
end;


{$pop}

{ Case tw8462.pp }
{$push}
{$ifdef fpc}{$endif}



type
  tw8462_TTestProc = function(Index: Integer): String;

  tw8462_TMyObject = class(TObject)
    procedure Test(Proc: tw8462_TTestProc); overload;
    procedure Test(Vals: TStrings); overload;
  end;

function tw8462_GetString(Index: Integer): String;
begin
  Result := '';
end;

procedure tw8462_TMyObject.Test(Proc: tw8462_TTestProc);
begin
end;

procedure tw8462_TMyObject.Test(Vals: TStrings);
begin
end;

var
  tw8462_O: tw8462_TMyObject;
  tw8462_P: tw8462_TTestProc;

{$pop}

begin

{ Case tb_method_callbacks_delphi_run_01.pp }
{$push}

{$push}
{$IFDEF FPC}
{$ENDIF}
{$pop}
{$push}
{$pop}
begin
  { Case tb0455.pp }
  {$push}
begin
 tb0455_cla1:=tb0455_twolbetaobject.create(nil);
 tb0455_cla1.FBrush.WOL_Changed;
end;
  {$pop}

  { Case tb0477.pp }
  {$push}
begin
  tb0477_t := tb0477_ttest.Create;
  tb0477_t.proc := tb0477_t.foo;
  tb0477_t.bar;
  tb0477_t.Free;
end;
  {$pop}

end;
{$pop}

{ Case tw2588.pp }
{$push}

begin
end;
{$pop}

{ Case tw2702.pp }
{$push}

begin
end;
{$pop}

{ Case tw2725.pp }
{$push}

begin
end;
{$pop}

{ Case tw2958.pp }
{$push}

begin
end;
{$pop}

{ Case tw8462.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tw8462_O.Test(tw8462_P);
  tw8462_O.Test(tw8462_GetString);
end;
{$pop}

end.
