{ Assigned method pointers, event properties and procedure-of-object fields. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

uses Classes;

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

end.
