{ Classes regression cases; original case IDs are retained below. }

{ Case tw3263.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3263 }
{ Submitted by "Frank Kintrup" on  2004-08-20 }
{ e-mail: frank.kintrup@gmx.de }
{$MODE Delphi}
type
  tw3263_tancestor = class (TObject)
    constructor Create; virtual; overload;
  end;

type
  tw3263_tderived = class (tw3263_tancestor)
    constructor Create; override; overload;
    constructor Create(aParam : Integer); overload;
  end;

var
  tw3263_err : boolean;

constructor tw3263_tancestor.Create;
begin
  writeln('TAnscestor.Create');
  tw3263_err:=false;
end;

constructor tw3263_tderived.Create;
begin
  writeln('TDerived.Create');
  inherited Create;  // Calls TAncestor.Create
end;

constructor tw3263_tderived.Create(aParam : Integer);
begin
  // Should call virtual TDerived.Create
  // Compiler stops here "Illegal expression"
  writeln('TDerived.Create(aParam)');
  Create;
end;

var tw3263_d : tw3263_tderived;
{$pop}

{ Case tw3768.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3786 }
{ Submitted by "drf" on  2005-03-14 }
{ e-mail: drfuchs@yahoo.com }

{$mode delphi}

type
  tw3768_funky_class=class;
  tw3768_base_class=class
    procedure tw3768_proc(f:tw3768_funky_class);virtual;
  end;
  tw3768_subclass2=class(tw3768_base_class)
    procedure tw3768_proc(f:tw3768_funky_class);override;
  end;
  tw3768_subclass3=class(tw3768_base_class)
    procedure tw3768_proc(f:tw3768_funky_class);override;
  end;
  tw3768_funky_class=class
    procedure tw3768_proc(p:tw3768_base_class);overload;virtual;
    procedure tw3768_proc(p:tw3768_subclass2);overload;virtual;
    procedure tw3768_proc(p:tw3768_subclass3);overload;virtual;
  end;
  tw3768_funky_subclass=class(tw3768_funky_class)
    procedure tw3768_proc(p:tw3768_subclass3);override;
    procedure tw3768_proc(p:tw3768_subclass2); override;
  end;

procedure tw3768_base_class.tw3768_proc(f:tw3768_funky_class); begin end;
procedure tw3768_subclass2.tw3768_proc(f:tw3768_funky_class); begin end;
procedure tw3768_subclass3.tw3768_proc(f:tw3768_funky_class); begin end;

procedure tw3768_funky_class.tw3768_proc(p:tw3768_base_class); begin end;
procedure tw3768_funky_class.tw3768_proc(p:tw3768_subclass2); begin end;
procedure tw3768_funky_class.tw3768_proc(p:tw3768_subclass3); begin end;

procedure tw3768_funky_subclass.tw3768_proc(p:tw3768_subclass2); begin end;
procedure tw3768_funky_subclass.tw3768_proc(p:tw3768_subclass3); begin end;
{$pop}

{ Case tw5896.pp }
{$push}
{$mode delphi}
type
  tw5896_tc1 = class
    procedure tw5896_p;virtual;abstract;
  end;

  tw5896_tc2 = class(tw5896_tc1)
    procedure tw5896_p;override;
  end;

procedure tw5896_tc2.tw5896_p;
  begin
    inherited;
  end;

var
  tw5896_c2 : tw5896_tc2;
{$pop}

{ Case tw8150a.pp }
{$push}
{$ifdef fpc}
{$mode delphi}
{$endif}

type
  tw8150a_tc = class
    tw8150a_a : longint;
    class procedure tw8150a_classmethod;
    procedure tw8150a_method;
  end;

  tw8150a_ttc = class of tw8150a_tc;

var
  tw8150a_l : longint;

class procedure tw8150a_tc.tw8150a_classmethod;
begin
  if tw8150a_l <> 1 then
    halt(1);
  tw8150a_l := 2;
end;

procedure tw8150a_tc.tw8150a_method;
begin
end;

var
  tw8150a_c: tw8150a_ttc;
{$pop}

{ Case tw8150d.pp }
{$push}
{$IFDEF FPC}
  {$mode delphi}
{$ENDIF}

type
  tw8150d_tmyobject = class
    tw8150d_x: Integer;
    class procedure tw8150d_foo; virtual;
    procedure tw8150d_bar; virtual;
  end;

  tw8150d_tmyobject2 = class(tw8150d_tmyobject)
    class procedure tw8150d_foo; override;
    procedure tw8150d_bar; override;
  end;

  tw8150d_tmyclass = class of tw8150d_tmyobject;

{ TMyObject }

procedure tw8150d_tmyobject.tw8150d_bar;
begin
  WriteLn('Bar ', Integer(Pointer(Self)),' ', tw8150d_x);
end;

class procedure tw8150d_tmyobject.tw8150d_foo;
begin
  WriteLn('Foo');
end;

{ TMyObject2 }

procedure tw8150d_tmyobject2.tw8150d_bar;
begin
  if (tw8150d_x <> 3) then
    halt(1);
  WriteLn('2Bar ', Integer(Pointer(Self)),' ', tw8150d_x);
end;

class procedure tw8150d_tmyobject2.tw8150d_foo;
begin
  WriteLn('2Foo');
end;

var
  tw8150d_myclass : tw8150d_tmyclass = tw8150d_tmyobject2;
{$pop}

{ Case tw9176.pp }
{$push}
{$ifdef fpc}
{$mode delphi}
{$endif}

type tw9176_tbla=class
      procedure tw9176_bla;
      procedure tw9176_blabla;
     end;

procedure tw9176_tbla.tw9176_bla;
begin
end;

procedure tw9176_tbla.tw9176_blabla;
 procedure tw9176_bla;
 begin
 end;
begin
 tw9176_bla;
end;
{$pop}

begin
  { Case tw3263.pp }
  {$push}

  begin
tw3263_err:=true;
  tw3263_d := tw3263_tderived.Create(0);
  if tw3263_err then
    halt(1);
  end;
  {$pop}

  { Case tw5896.pp }
  {$push}

  begin
tw5896_c2:=tw5896_tc2.create;
  tw5896_c2.tw5896_p;
  tw5896_c2.free;
  end;
  {$pop}

  { Case tw8150a.pp }
  {$push}
{$ifdef fpc}
{$endif}
  begin
tw8150a_c := tw8150a_tc;
  tw8150a_l := 1;
  with tw8150a_c do
    tw8150a_classmethod;
  if tw8150a_l <> 2 then
    halt(2);
  end;
  {$pop}

  { Case tw8150d.pp }
  {$push}
{$IFDEF FPC}
{$ENDIF}
  begin
with tw8150d_myclass do begin
    tw8150d_foo; // should work

    with Create do try // should work
      tw8150d_x := 3; // should work
      tw8150d_bar; // should work
    finally
      Free; // should work
    end;

    tw8150d_foo; // should work

// x := 1; // should not be allowed
// Bar; // should not be allowed
// Free; // should not be allowed
  end;
  end;
  {$pop}

end.
