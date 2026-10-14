{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}
uses sysutils;

{ Case tw30570.pas }
{$push}


{$IFDEF FPC}
  
{$ENDIF}
{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

{$r+}



type
  tw30570_TSomeClass = class
  public
    procedure LoadSomething;
  end;

  tw30570_TA = class
  private
    FSomeObject: tw30570_TSomeClass;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    property SomeObject: tw30570_TSomeClass read FSomeObject;
  end;

var
  tw30570_i: longint;
  tw30570_order: array[1..4] of longint;

procedure tw30570_TSomeClass.LoadSomething;
begin
  raise Exception.Create('An exception loading something');
end;

constructor tw30570_TA.Create;
begin
  tw30570_order[tw30570_i]:=1;
  inc(tw30570_i);
  WriteLn(1);
  inherited Create;
end;

destructor tw30570_TA.Destroy;
begin
  tw30570_order[tw30570_i]:=2;
  inc(tw30570_i);
  WriteLn(2);
  inherited Destroy;
end;

procedure tw30570_TA.AfterConstruction;
begin
  tw30570_order[tw30570_i]:=3;
  inc(tw30570_i);
  WriteLn(3);
  FSomeObject := tw30570_TSomeClass.Create;
  FSomeObject.LoadSomething;
end;

procedure tw30570_TA.BeforeDestruction;
begin
  tw30570_order[tw30570_i]:=4;
  inc(tw30570_i);
  WriteLn(4);
  FSomeObject.Free;
end;

var
  tw30570_VA: tw30570_TA;
  tw30570_ok: boolean;

{$pop}

{ Case tw3997.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3997 }
{ Submitted by "Dominique Louis" on  2005-05-21 }
{ e-mail: Dominique@SavageSoftware.com.au }




{$APPTYPE CONSOLE}



type
  tw3997_TMyNotifyEvent =  procedure of object;

  tw3997_TMyBaseWindow = class( TObject )
  private
    FOnRender: tw3997_TMyNotifyEvent;
  public
    property OnRender: tw3997_TMyNotifyEvent read FOnRender write FOnRender;
  end;

  tw3997_TBaseInterface = class( TObject )
  protected
    procedure Render; virtual; abstract;
  public
    MainWindow : tw3997_TMyBaseWindow;
    constructor Create;
    destructor Destroy; override;
    procedure ResetInputManager;
  end;

  tw3997_TMyInterface = class( tw3997_TBaseInterface )
  protected
    procedure Render; override;
  end;


{ TBaseInterface }
constructor tw3997_TBaseInterface.Create;
begin
  inherited;
  WriteLn( 'TBaseInterface.Create' );
  MainWindow := tw3997_TMyBaseWindow.Create;
  ResetInputManager;
end;

destructor tw3997_TBaseInterface.Destroy;
begin
  MainWindow.Free;
  inherited;
end;

procedure tw3997_TBaseInterface.ResetInputManager;
begin
  WriteLn( 'ResetInputManager' );
  MainWindow.OnRender := Render;
end;

{ TMyInterface }
procedure tw3997_TMyInterface.Render;
begin
  WriteLn( 'Rendering' );
end;

var
  tw3997_MyInterface : tw3997_TMyInterface;


{$pop}

{ Case terecs6.pas }
{$push}



{$apptype console}


type
  terecs6_TFoo = record
    F: Integer;
    class operator Explicit(terecs6_a: terecs6_TFoo): Integer;
    class operator Implicit(terecs6_a: terecs6_TFoo): Integer;
    class operator Equal(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
    class operator NotEqual(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
    class operator In(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
    class operator GreaterThan(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
    class operator GreaterThanOrEqual(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
    class operator LessThan(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
    class operator LessThanOrEqual(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
    class operator Add(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
    class operator Subtract(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
    class operator Multiply(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
    class operator Divide(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
    class operator IntDivide(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
    class operator Modulus(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
    class operator LeftShift(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
    class operator RightShift(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
    class operator LogicalOr(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
    class operator LogicalAnd(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
    class operator LogicalXor(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
    class operator LogicalNot(terecs6_a: terecs6_TFoo): terecs6_TFoo;
    class operator BitwiseOr(terecs6_a, terecs6_b: terecs6_TFoo): terecs6_TFoo;
    class operator BitwiseAnd(terecs6_a, terecs6_b: terecs6_TFoo): terecs6_TFoo;
    class operator BitwiseXor(terecs6_a, terecs6_b: terecs6_TFoo): terecs6_TFoo;
    class operator Inc(terecs6_a: terecs6_TFoo): terecs6_TFoo;
    class operator Dec(terecs6_a: terecs6_TFoo): terecs6_TFoo;
    class operator Negative(terecs6_a: terecs6_TFoo): terecs6_TFoo;
    class operator Positive(terecs6_a: terecs6_TFoo): terecs6_TFoo;
 end;

class operator terecs6_TFoo.Explicit(terecs6_a: terecs6_TFoo): Integer;
begin
  // to check the difference with implicit
  Result := terecs6_a.F + 1;
end;

class operator terecs6_TFoo.Implicit(terecs6_a: terecs6_TFoo): Integer;
begin
  Result := terecs6_a.F;
end;

class operator terecs6_TFoo.Equal(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
begin
  Result := terecs6_a.F = terecs6_b.F;
end;

class operator terecs6_TFoo.NotEqual(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
begin
  Result := terecs6_a.F <> terecs6_b.F;
end;

class operator terecs6_TFoo.In(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
begin
  Result := terecs6_a.F in [0..terecs6_b.F];
end;

class operator terecs6_TFoo.GreaterThan(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
begin
  Result := terecs6_a.F > terecs6_b.F;
end;

class operator terecs6_TFoo.GreaterThanOrEqual(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
begin
  Result := terecs6_a.F >= terecs6_b.F;
end;

class operator terecs6_TFoo.LessThan(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
begin
  Result := terecs6_a.F < terecs6_b.F;
end;

class operator terecs6_TFoo.LessThanOrEqual(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
begin
  Result := terecs6_a.F <= terecs6_b.F;
end;

class operator terecs6_TFoo.Add(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
begin
  Result := terecs6_a.F + terecs6_b.F;
end;

class operator terecs6_TFoo.Subtract(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
begin
  Result := terecs6_a.F - terecs6_b.F;
end;

class operator terecs6_TFoo.Multiply(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
begin
  Result := terecs6_a.F * terecs6_b.F;
end;

class operator terecs6_TFoo.Divide(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
begin
  Result := Round(terecs6_a.F / terecs6_b.F);
end;

class operator terecs6_TFoo.IntDivide(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
begin
  Result := terecs6_a.F div terecs6_b.F;
end;

class operator terecs6_TFoo.Modulus(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
begin
  Result := terecs6_a.F mod terecs6_b.F;
end;

class operator terecs6_TFoo.LeftShift(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
begin
  Result := terecs6_a.F shl terecs6_b.F;
end;

class operator terecs6_TFoo.RightShift(terecs6_a, terecs6_b: terecs6_TFoo): Integer;
begin
  Result := terecs6_a.F shr terecs6_b.F;
end;

class operator terecs6_TFoo.LogicalOr(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
begin
  Result := (terecs6_a.F or terecs6_b.F) <> 0;
end;

class operator terecs6_TFoo.LogicalAnd(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
begin
  Result := (terecs6_a.F and terecs6_b.F) <> 0;
end;

class operator terecs6_TFoo.LogicalXor(terecs6_a, terecs6_b: terecs6_TFoo): Boolean;
begin
  Result := (terecs6_a.F xor terecs6_b.F) <> 0;
end;

class operator terecs6_TFoo.LogicalNot(terecs6_a: terecs6_TFoo): terecs6_TFoo;
begin
  Result.F := not terecs6_a.F;
end;

class operator terecs6_TFoo.BitwiseOr(terecs6_a, terecs6_b: terecs6_TFoo): terecs6_TFoo;
begin
  Result.F := terecs6_a.F or terecs6_b.F;
end;

class operator terecs6_TFoo.BitwiseAnd(terecs6_a, terecs6_b: terecs6_TFoo): terecs6_TFoo;
begin
  Result.F := terecs6_a.F and terecs6_b.F;
end;

class operator terecs6_TFoo.BitwiseXor(terecs6_a, terecs6_b: terecs6_TFoo): terecs6_TFoo;
begin
  Result.F := terecs6_a.F xor terecs6_b.F;
end;

class operator terecs6_TFoo.Inc(terecs6_a: terecs6_TFoo): terecs6_TFoo;
begin
  Result.F := terecs6_a.F + 1;
end;

class operator terecs6_TFoo.Dec(terecs6_a: terecs6_TFoo): terecs6_TFoo;
begin
  Result.F := terecs6_a.F - 1;
end;

class operator terecs6_TFoo.Negative(terecs6_a: terecs6_TFoo): terecs6_TFoo;
begin
  Result.F := -terecs6_a.F;
end;

class operator terecs6_TFoo.Positive(terecs6_a: terecs6_TFoo): terecs6_TFoo;
begin
  // to check that operator is called change the result value
  Result.F := terecs6_a.F+1;
end;

var
  terecs6_a, terecs6_b: terecs6_TFoo;
  terecs6_i: integer;

{$pop}

begin

{ Case tw30570.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
{$IFDEF MSWINDOWS}
{$APPTYPE CONSOLE}
{$ENDIF}
{$r+}
begin
  tw30570_i:=1;
  tw30570_ok:=false;
  try
    tw30570_VA := tw30570_TA.Create;
  except
    if tw30570_order[1]<>1 then
      halt(1);
    if tw30570_order[2]<>3 then
      halt(2);
    if tw30570_order[3]<>4 then
      halt(3);
    if tw30570_order[4]<>2 then
      halt(4);
    if tw30570_i<>5 then
      halt(5);
    if assigned(tw30570_va) then
      halt(6);
    tw30570_ok:=true;
  end;
  if not tw30570_ok then
    halt(7);
end;
{$pop}

{ Case tw3997.pas }
{$push}

{$APPTYPE CONSOLE}
begin
  tw3997_MyInterface := tw3997_TMyInterface.Create;

  tw3997_MyInterface.Render;

  tw3997_MyInterface.Free;
end;
{$pop}

{ Case terecs6.pas }
{$push}

{$apptype console}
begin
  terecs6_a.F := 1;
  terecs6_b.F := 2;
  if terecs6_a = terecs6_b then
    halt(1);
  if not (terecs6_a <> terecs6_b) then
    halt(2);
  if not (terecs6_a in terecs6_b) then
    halt(3);
  if (terecs6_b in terecs6_a) then
    halt(4);
  if terecs6_a > terecs6_b then
    halt(5);
  if terecs6_a >= terecs6_b then
    halt(6);
  if not (terecs6_a < terecs6_b) then
    halt(7);
  if not (terecs6_a <= terecs6_b) then
    halt(8);
  if terecs6_a * terecs6_b <> 2 then
    halt(9);
  if terecs6_a / terecs6_b <> 0 then
    halt(10);
  if terecs6_a div terecs6_b <> 0 then
    halt(11);
  if terecs6_a mod terecs6_b <> 1 then
    halt(12);
  if terecs6_a shl terecs6_b <> 4 then
    halt(13);
  if terecs6_b shr terecs6_a <> 1 then
    halt(14);
  if terecs6_a + terecs6_b <> 3 then
    halt(15);
  if terecs6_a - terecs6_b <> -1 then
    halt(16);
  if not (terecs6_a or terecs6_b) then
    halt(17);
  if terecs6_a and terecs6_b then
    halt(18);
  if not (terecs6_a xor terecs6_b) then
    halt(19);
  if (not terecs6_a).F <> (not 1) then
    halt(20);
{ bitwise operators current does not work if logical are defined
  if (a or b).F <> (a.F or b.F) then
    halt(21);
  if (a and b).F <> (a.F and b.F) then
    halt(22);
  if (a xor b).F <> (a.F xor b.F) then
    halt(23);
}
  inc(terecs6_a);
  if terecs6_a.F <> 2 then
    halt(24);
  dec(terecs6_b);
  if terecs6_b.F <> 1 then
    halt(25);
  terecs6_i := terecs6_b;
  if terecs6_i <> 1 then
    halt(26);
  if Integer(terecs6_b) <> 2 then
    halt(27);
  terecs6_b := -terecs6_b;
  if terecs6_b.F <> -1 then
    halt(28);
  terecs6_b := +terecs6_b;
  if terecs6_b.F <> 0 then
    halt(29);
  WriteLn('ok');
end;
{$pop}

end.
