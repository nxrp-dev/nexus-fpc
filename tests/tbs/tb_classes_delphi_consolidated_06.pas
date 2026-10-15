{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}

{ Case tw25081.pas }
{$push}
{ This test explicity generates overflow and range check error
  Thus, we need explicit $Q- and $R- }
{$Q-}
{$R-}



{$APPTYPE CONSOLE}

{$IFDEF FPC}
  
{$ENDIF}

type
  tw25081_TLargeCardinal = record
  public
    Low:  Cardinal;
    High: Cardinal;

    class operator Inc(const Operand: tw25081_TLargeCardinal): tw25081_TLargeCardinal;
    class operator Dec(const Operand: tw25081_TLargeCardinal): tw25081_TLargeCardinal;
  end;

{ TLargeCardinal }

class operator tw25081_TLargeCardinal.Dec(const Operand: tw25081_TLargeCardinal): tw25081_TLargeCardinal;
begin
  Result := Operand;
  Dec(Result.Low);

  if Result.Low = $FFFFFFFF then
    Dec(Result.High);
end;

class operator tw25081_TLargeCardinal.Inc(const Operand: tw25081_TLargeCardinal): tw25081_TLargeCardinal;
begin
  Result := Operand;
  Inc(Result.Low);

  if Result.Low = 0 then
    Inc(Result.High);
end;

var
  tw25081_Value: tw25081_TLargeCardinal;


{$pop}

{ Case tw25607a.pas }
{$push}


{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}

type
  tw25607a_TA = class
    constructor Create(A: Integer = 0); overload; virtual;
  end;

  tw25607a_TB = class(tw25607a_TA)
    constructor Create(A: Integer); overload; override;
  end;

  tw25607a_TClassB = class of tw25607a_TB;

var
  tw25607a_tacalled,
  tw25607a_tbcalled: boolean;

constructor tw25607a_TA.Create(A: Integer = 0);
begin
  WriteLn('TA.Create');
  tw25607a_tacalled:=true;
end;

constructor tw25607a_TB.Create(A: Integer);
begin
  WriteLn('TB.Create');
  tw25607a_tbcalled:=true;
end;

var
  tw25607a_B: tw25607a_TB;
  tw25607a_ClassB: tw25607a_TClassB;

{$pop}

{ Case tw25607b.pas }
{$push}


{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}

type
  tw25607b_TA = class
    constructor Create(A: Integer = 0); overload;
  end;

  tw25607b_TB = class(tw25607b_TA)
    constructor Create(A: Integer); overload;
  end;

  tw25607b_TClassB = class of tw25607b_TB;

var
  tw25607b_tacalled,
  tw25607b_tbcalled: boolean;

constructor tw25607b_TA.Create(A: Integer = 0);
begin
  WriteLn('TA.Create');
  tw25607b_tacalled:=true;
end;

constructor tw25607b_TB.Create(A: Integer);
begin
  WriteLn('TB.Create');
  tw25607b_tbcalled:=true;
end;

var
  tw25607b_B: tw25607b_TB;
  tw25607b_ClassB: tw25607b_TClassB;

{$pop}

{ Case tw25607c.pas }
{$push}


{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}

type
  tw25607c_T0 = class
    class procedure Foo;
  end;

  tw25607c_TA = class(tw25607c_T0)
    class procedure Foo(A: Integer = 0); overload; virtual;
  end;

  tw25607c_TB = class(tw25607c_TA)
    class procedure Foo(A: Integer); overload; override;
  end;

  tw25607c_TClassB = class of tw25607c_TB;

var
  tw25607c_t0called,
  tw25607c_tacalled,
  tw25607c_tbcalled: boolean;

class procedure tw25607c_T0.Foo();
begin
  WriteLn('T0.Foo');
  tw25607c_t0called:=true;
end;

class procedure tw25607c_TA.Foo(A: Integer = 0);
begin
  WriteLn('TA.Foo');
  tw25607c_tacalled:=true;
end;

class procedure tw25607c_TB.Foo(A: Integer);
begin
  WriteLn('TB.Foo');
  tw25607c_tbcalled:=true;
end;

var
  tw25607c_B: tw25607c_TB;
  tw25607c_ClassB: tw25607c_TClassB;

{$pop}

{ Case tw25607d.pas }
{$push}


{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}

type
  tw25607d_T0 = class
    class procedure Foo;
  end;

  tw25607d_TA = class(tw25607d_T0)
    class procedure Foo(A: Integer = 0); overload;
  end;

  tw25607d_TB = class(tw25607d_TA)
    class procedure Foo(A: Integer); overload;
  end;

  tw25607d_TClassB = class of tw25607d_TB;

var
  tw25607d_t0called,
  tw25607d_tacalled,
  tw25607d_tbcalled: boolean;

class procedure tw25607d_T0.Foo();
begin
  WriteLn('T0.Foo');
  tw25607d_t0called:=true;
end;

class procedure tw25607d_TA.Foo(A: Integer = 0);
begin
  WriteLn('TA.Foo');
  tw25607d_tacalled:=true;
end;

class procedure tw25607d_TB.Foo(A: Integer);
begin
  WriteLn('TB.Foo');
  tw25607d_tbcalled:=true;
end;

var
  tw25607d_B: tw25607d_TB;
  tw25607d_ClassB: tw25607d_TClassB;

{$pop}

{ Case tw25607e.pas }
{$push}


{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}

type
  tw25607e_T0 = class
    procedure Foo;
  end;

  tw25607e_TA = class(tw25607e_T0)
    procedure Foo(A: Integer = 0); overload; virtual;
  end;

  tw25607e_TB = class(tw25607e_TA)
    procedure Foo(A: Integer); overload; override;
  end;

  tw25607e_TClassB = class of tw25607e_TB;

var
  tw25607e_t0called,
  tw25607e_tacalled,
  tw25607e_tbcalled: boolean;

procedure tw25607e_T0.Foo();
begin
  WriteLn('T0.Foo');
  tw25607e_t0called:=true;
end;

procedure tw25607e_TA.Foo(A: Integer = 0);
begin
  WriteLn('TA.Foo');
  tw25607e_tacalled:=true;
end;

procedure tw25607e_TB.Foo(A: Integer);
begin
  WriteLn('TB.Foo');
  tw25607e_tbcalled:=true;
end;

var
  tw25607e_B: tw25607e_TB;
  tw25607e_ClassB: tw25607e_TClassB;

{$pop}

{ Case tw25607f.pas }
{$push}


{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}

type
  tw25607f_T0 = class
    procedure Foo;
  end;

  tw25607f_TA = class(tw25607f_T0)
    procedure Foo(A: Integer = 0); overload;
  end;

  tw25607f_TB = class(tw25607f_TA)
    procedure Foo(A: Integer); overload;
  end;

  tw25607f_TClassB = class of tw25607f_TB;

var
  tw25607f_t0called,
  tw25607f_tacalled,
  tw25607f_tbcalled: boolean;

procedure tw25607f_T0.Foo();
begin
  WriteLn('T0.Foo');
  tw25607f_t0called:=true;
end;

procedure tw25607f_TA.Foo(A: Integer = 0);
begin
  WriteLn('TA.Foo');
  tw25607f_tacalled:=true;
end;

procedure tw25607f_TB.Foo(A: Integer);
begin
  WriteLn('TB.Foo');
  tw25607f_tbcalled:=true;
end;

var
  tw25607f_B: tw25607f_TB;
  tw25607f_ClassB: tw25607f_TClassB;

{$pop}

begin

{ Case tw25081.pas }
{$push}
{$Q-}
{$R-}
{$APPTYPE CONSOLE}
{$IFDEF FPC}

{$ENDIF}
begin
  tw25081_Value.Low  := $FFFFFFFF;
  tw25081_Value.High := 0;

  Inc(tw25081_Value);

  if (tw25081_Value.Low <> 0) or (tw25081_Value.High <> 1) then
    Halt(1);

  Dec(tw25081_Value);

  if (tw25081_Value.Low <> $FFFFFFFF) or (tw25081_Value.High <> 0) then
    Halt(1);
end;
{$pop}

{ Case tw25607a.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}
begin
  tw25607a_B := tw25607a_TB.Create; // TA.Create (VMT is not used
                  // compiler can determine) -- in Delphi;
                  // In FPC, because TB.Create is used, we
                  // call TB.Create
  if tw25607a_tacalled then
    halt(1);
  if not tw25607a_tbcalled then
    halt(2);
  tw25607a_tbcalled:=false;

  tw25607a_B.Create; // call TB.Create because of VMT rules
  tw25607a_B.Free;
  if tw25607a_tacalled then
    halt(3);
  if not tw25607a_tbcalled then
    halt(4);
  tw25607a_tbcalled:=false;

  tw25607a_ClassB := tw25607a_TB;
  tw25607a_B := tw25607a_ClassB.Create; // call TB.Create because of VMT rules
  tw25607a_B.Free;
  if tw25607a_tacalled then
    halt(5);
  if not tw25607a_tbcalled then
    halt(6);
end;
{$pop}

{ Case tw25607b.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}
begin
  tw25607b_B := tw25607b_TB.Create; // TA.Create (VMT is not used
                  // compiler can determine)
  if not tw25607b_tacalled then
    halt(1);
  if tw25607b_tbcalled then
    halt(2);
  tw25607b_tacalled:=false;

  tw25607b_B.Create; // call TA.Create because of VMT rules
  tw25607b_B.Free;
  if not tw25607b_tacalled then
    halt(3);
  if tw25607b_tbcalled then
    halt(4);
  tw25607b_tacalled:=false;

  tw25607b_ClassB := tw25607b_TB;
  tw25607b_B := tw25607b_ClassB.Create; // call TA.Create because of VMT rules
  tw25607b_B.Free;
  if not tw25607b_tacalled then
    halt(5);
  if tw25607b_tbcalled then
    halt(6);
  tw25607b_tacalled:=false;
end;
{$pop}

{ Case tw25607c.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}
begin
  tw25607c_TB.Foo; // call TA.Foo (VMT is not used, compiler can determine) -- on Delphi
          // on FPC: call TB.Foo because virtual method and VMT specified
  if tw25607c_t0called then
    halt(1);
  if tw25607c_tacalled then
    halt(2);
  if not tw25607c_tbcalled then
    halt(3);
  tw25607c_tbcalled:=false;

  tw25607c_B := tw25607c_TB.Create;
  tw25607c_B.Foo; // call TB.Foo because of VMT rules
  tw25607c_B.Free;
  if tw25607c_t0called then
    halt(4);
  if tw25607c_tacalled then
    halt(5);
  if not tw25607c_tbcalled then
    halt(6);
  tw25607c_tbcalled:=false;

  tw25607c_ClassB := tw25607c_TB;
  tw25607c_ClassB.Foo; // call TB.Foo because of VMT rules
  if tw25607c_t0called then
    halt(7);
  if tw25607c_tacalled then
    halt(8);
  if not tw25607c_tbcalled then
    halt(9);
  tw25607c_tbcalled:=false;
end;
{$pop}

{ Case tw25607d.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}
begin
  tw25607d_TB.Foo; // call TA.Foo (VMT is not used, compiler can determine)
  if tw25607d_t0called then
    halt(1);
  if not tw25607d_tacalled then
    halt(2);
  if tw25607d_tbcalled then
    halt(3);
  tw25607d_tacalled:=false;

  tw25607d_B := tw25607d_TB.Create;
  tw25607d_B.Foo; // call TA.Foo because of VMT rules
  tw25607d_B.Free;
  if tw25607d_t0called then
    halt(4);
  if not tw25607d_tacalled then
    halt(5);
  if tw25607d_tbcalled then
    halt(6);
  tw25607d_tacalled:=false;

  tw25607d_ClassB := tw25607d_TB;
  tw25607d_ClassB.Foo; // call TA.Foo because of VMT rules
  if tw25607d_t0called then
    halt(7);
  if not tw25607d_tacalled then
    halt(8);
  if tw25607d_tbcalled then
    halt(9);
end;
{$pop}

{ Case tw25607e.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}
begin
  tw25607e_B := tw25607e_TB.Create;
  tw25607e_B.Foo; // call TB.Foo because of VMT rules
  tw25607e_B.Free;
  if tw25607e_t0called then
    halt(1);
  if tw25607e_tacalled then
    halt(2);
  if not tw25607e_tbcalled then
    halt(3);
end;
{$pop}

{ Case tw25607f.pas }
{$push}
{$IFDEF FPC}

{$ENDIF}
{$APPTYPE CONSOLE}
begin
  tw25607f_B := tw25607f_TB.Create;
  tw25607f_B.Foo; // call TA.Foo because of VMT rules
  tw25607f_B.Free;
  if tw25607f_t0called then
    halt(1);
  if not tw25607f_tacalled then
    halt(2);
  if tw25607f_tbcalled then
    halt(3);
end;
{$pop}

end.
