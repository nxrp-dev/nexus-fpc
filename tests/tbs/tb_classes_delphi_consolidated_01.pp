{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}
uses sysutils;

{ Case tb_class_inheritance_delphi_run_01.pp }
{$push}
{ Inherited overload dispatch, class-reference Is checks and repeated object destruction. }
{ Original case IDs and variable scopes are retained below. }





{ Case tb0577.pp }
{$push}
type
  tb0577_tc = class
    procedure tb0577_test(tb0577_b: byte);virtual;overload;
  end;

  tb0577_tc2 = class(tb0577_tc)
   strict protected
    procedure tb0577_test(tb0577_b: byte; tb0577_l: longint = 1234);virtual;overload;
   public
    procedure tb0577_test(tb0577_l: longint);virtual;overload;
  end;

  tb0577_tc3 = class(tb0577_tc2)
    procedure tb0577_test(tb0577_b: byte);override;overload;
  end;

var
  tb0577_glob: longint;

  procedure tb0577_tc.tb0577_test(tb0577_b: byte);
    begin
      tb0577_glob:=2;
    end;

  procedure tb0577_tc2.tb0577_test(tb0577_l: longint);
    begin
      tb0577_glob:=1;
    end;

  procedure tb0577_tc2.tb0577_test(tb0577_b: byte; tb0577_l: longint = 1234);
    begin
      tb0577_glob:=3;
    end;

  procedure tb0577_tc3.tb0577_test(tb0577_b: byte);
    begin
      inherited;
    end;

var
  tb0577_c: tb0577_tc;
{$pop}

{ Case tb0203.pp }
{$push}
{ Old file: tbs0239.pp }
{ No warning for uninitialized class in IS statements  OK 0.99.11 (PM) }
   type
     tb0203_ttest=class
     end;
     tb0203_ttest2 = class(tb0203_ttest)
     end;
     tb0203_ttestclass=class of tb0203_ttest;
   var
     tb0203_i,tb0203_j:tb0203_ttest;
     tb0203_tt:tclass;
{$pop}

{ Case tb0174.pp }
{$push}
{ Old file: tbs0207.pp }
{ a class destructor doesn't release the memory        OK 0.99.11 (FK) }



 var tb0174_i : longint;
{$pop}


{$pop}

{ Case tw13639.pp }
{$push}


{$IFDEF FPC}
  
{$ENDIF}



type
  tw13639_Tb = array of byte;
  tw13639_int = integer;
  tw13639_TMeS = class
    private
     FD: tw13639_Tb;
     Fp: Integer;
    public
     constructor Create(cty: tw13639_int);
     procedure Write(const Buffer: tw13639_TB; Offset: tw13639_int; Count: tw13639_int); overload;
     procedure Write(Buffer: PAnsiChar; Offset: tw13639_int; Count: tw13639_int); overload;
  end;

constructor tw13639_TMeS.Create(cty: tw13639_int);
begin
  inherited Create;
  SetLength(FD, cty);
end;

procedure tw13639_TMeS.Write(Buffer: PAnsiChar; Offset: tw13639_int; Count: tw13639_int);
begin
  Move(Buffer[Offset], PAnsiChar(@FD[FP])^, Count);
  Inc(FP, Count);
end;

procedure tw13639_TMeS.Write(const Buffer: tw13639_TB; Offset: tw13639_int; Count: tw13639_int);
begin
  Write(PAnsiChar(@Buffer[0]), Offset, Count);
end;

var tw13639_vmes:tw13639_tmes;

const  tw13639_vac:string='test1 copy string';
       tw13639_vtb:string='test2 copy bytes 10';

var
  tw13639_s: string;

{$pop}

{ Case tw25004.pp }
{$push}






type
  tw25004_TExpression = class(TObject)
  end;

  tw25004_TLiteralInteger = class(tw25004_TExpression)
  public
    Value: integer;

    constructor Create(Value: integer); virtual;
    function ToString(): string; override;
  end;

  tw25004_TVariableReference = class(tw25004_TExpression)
  public
    Identifier: string;

    constructor Create(const Identifier: string); virtual;
    function ToString(): string; override;
  end;

  tw25004_TBinaryOperator = (tw25004_boAdd, tw25004_boGreaterThan);

  tw25004_TBinaryOperatorExpression = class(tw25004_TExpression)
  protected
    function OperatorToString(Operator_: tw25004_TBinaryOperator): string;
  public
    Operator_: tw25004_TBinaryOperator;
    Left: tw25004_TExpression;
    Right: tw25004_TExpression;

    constructor Create(Operator_: tw25004_TBinaryOperator; Left: tw25004_TExpression; Right: tw25004_TExpression); virtual;
    destructor Destroy(); override;
    function ToString(): string; override;
  end;

  tw25004_TExpressionBuilder = record
  public
    Expression: tw25004_TExpression;

    class operator  Implicit(Operand: tw25004_TExpression): tw25004_TExpressionBuilder;
    class operator  Implicit(Value: integer): tw25004_TExpressionBuilder;
    class operator  Add(const Left: tw25004_TExpressionBuilder; const Right: tw25004_TExpressionBuilder): tw25004_TExpressionBuilder;
    class operator  GreaterThan(const Left: tw25004_TExpressionBuilder; const Right: tw25004_TExpressionBuilder): tw25004_TExpressionBuilder;
  end;

  { TLiteralInteger }

  constructor tw25004_TLiteralInteger.Create(Value: integer);
  begin
    inherited Create();

    Self.Value := Value;
  end;

  function tw25004_TLiteralInteger.ToString(): string;
  begin
    Result := IntToStr(Value);
  end;

  { TVariableReference }

  constructor tw25004_TVariableReference.Create(const Identifier: string);
  begin
    inherited Create();

    Self.Identifier := Identifier;
  end;

  function tw25004_TVariableReference.ToString(): string;
  begin
    Result := Identifier;
  end;

  { TBinaryOperatorExpression }

  constructor tw25004_TBinaryOperatorExpression.Create(Operator_: tw25004_TBinaryOperator; Left, Right: tw25004_TExpression);
  begin
    inherited Create();

    Self.Operator_ := Operator_;
    Self.Left := Left;
    Self.Right := Right;
  end;

  destructor tw25004_TBinaryOperatorExpression.Destroy();
  begin
    Left.Free();
    Right.Free();

    inherited Destroy();
  end;

  function tw25004_TBinaryOperatorExpression.OperatorToString(Operator_: tw25004_TBinaryOperator): string;
  begin
    case Operator_ of
      tw25004_boAdd:
        Result := '+';
      tw25004_boGreaterThan:
        Result := '>';
      else
        raise Exception.Create('Unknown operator');
    end;
  end;

  function tw25004_TBinaryOperatorExpression.ToString(): string;
  begin
    Result := Left.ToString() + ' ' + OperatorToString(Operator_) + ' ' + Right.ToString();
  end;

  { TExpressionBuilder }

  class operator tw25004_TExpressionBuilder.Add(const Left: tw25004_TExpressionBuilder; const Right: tw25004_TExpressionBuilder): tw25004_TExpressionBuilder;
  begin
    Result := tw25004_TBinaryOperatorExpression.Create(tw25004_boAdd, Left.Expression, Right.Expression);
  end;

  class operator tw25004_TExpressionBuilder.Implicit(Operand: tw25004_TExpression): tw25004_TExpressionBuilder;
  begin
    Result.Expression := Operand;
  end;

  class operator tw25004_TExpressionBuilder.GreaterThan(const Left: tw25004_TExpressionBuilder; const Right: tw25004_TExpressionBuilder): tw25004_TExpressionBuilder;
  begin
    Result := tw25004_TBinaryOperatorExpression.Create(tw25004_boGreaterThan, Left.Expression,
      Right.Expression);
  end;

  class operator tw25004_TExpressionBuilder.Implicit(Value: integer): tw25004_TExpressionBuilder;
  begin
    Result := tw25004_TLiteralInteger.Create(Value);
  end;

var
  tw25004_Variable1: tw25004_TExpressionBuilder;
  tw25004_Variable2: tw25004_TExpressionBuilder;
  tw25004_Formula: tw25004_TExpressionBuilder;

{$pop}

{ Case tw3499.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3499 }
{ Submitted by "Bart Tierens" on  2005-01-02 }
{ e-mail: svg@deds.nl }


{$ifdef fpc}{$endif}



var
  tw3499_err : boolean;

type
  tw3499_TProcedure = procedure of object;
  Class1 = class
  public
    proc: tw3499_TProcedure;
    procedure p(const aproc: tw3499_TProcedure);
  end;
  Class2 = class
  public
    procedure d();
  end;

procedure Class1.p(const aproc: tw3499_TProcedure);
begin
  proc := aproc;
end;

procedure Class2.d();
begin
  writeLn('procedure called');
  tw3499_err:=false;
end;

var
  tw3499_c: Class1;
  tw3499_e: Class2;

{$pop}

begin

{ Case tb_class_inheritance_delphi_run_01.pp }
{$push}

{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tb0577.pp }
  {$push}
begin
  tb0577_c:=tb0577_tc3.create;
  tb0577_c.tb0577_test(byte(4));
  if tb0577_glob<>2 then
    halt(1);
end;
  {$pop}

  { Case tb0203.pp }
  {$push}
begin
     tb0203_tt:=tb0203_ttest;
     tb0203_i:=tb0203_ttest.create;
     tb0203_j:=tb0203_ttest2.create;
     Writeln('tt is a class of ttest initialized by "tt:=ttest"');
     Writeln('i is a ttest class initialized by "i:=ttest.create"');
     Writeln('j is a ttest class initialized by "j:=ttest2.create"');
     writeln('i is tobject ',tb0203_i is tobject);
     if not(tb0203_i is tobject) then
       Halt(1);
     writeln('i is tt ',tb0203_i is tb0203_tt);
     if not(tb0203_i is tb0203_tt) then
       Halt(1);
     writeln('i is ttest ',tb0203_i is tb0203_ttest);
     if not(tb0203_i is tb0203_ttest) then
       Halt(1);
     writeln('i is ttest2 ',tb0203_i is tb0203_ttest2);
     if (tb0203_i is tb0203_ttest2) then
       Halt(1);
     writeln('j is tobject ',tb0203_j is tobject);
     if not(tb0203_j is tobject) then
       Halt(1);
     writeln('j is tt ',tb0203_j is tb0203_tt);
     if not(tb0203_j is tb0203_tt) then
       Halt(1);
     writeln('j is ttest ',tb0203_j is tb0203_ttest);
     if not(tb0203_j is tb0203_ttest) then
       Halt(1);
     writeln('j is ttest2 ',tb0203_j is tb0203_ttest2);
     if not(tb0203_j is tb0203_ttest2) then
       Halt(1);
   end;
  {$pop}

  { Case tb0174.pp }
  {$push}
begin
   for tb0174_i:=1 to 100 do
     tobject.create.free;
end;
  {$pop}

end;
{$pop}

{ Case tw13639.pp }
{$push}
{$IFDEF FPC}

{$ENDIF}
begin
   tw13639_vmes:=tw13639_tmes.Create(16);
   tw13639_vmes.write(Pansichar(tw13639_vac),1,10);
   tw13639_vmes.Write(tw13639_tb(tw13639_vtb),10,5);
   writeln('"',string(tw13639_vmes.FD),'"');
   tw13639_s:=pchar(tw13639_vmes.fd);
   if (tw13639_s<>'est1 copy  byte') then
     halt(1);
end;
{$pop}

{ Case tw25004.pp }
{$push}

begin
  tw25004_Variable1 := tw25004_TVariableReference.Create('a');
  tw25004_Variable2 := tw25004_TVariableReference.Create('b');
  tw25004_Formula := tw25004_Variable1 + 1 > 5 + tw25004_Variable2;
  if tw25004_Formula.Expression.ToString() <> 'a + 1 > 5 + b' then
    halt(1);
  tw25004_Formula.Expression.Free();
end;
{$pop}

{ Case tw3499.pp }
{$push}
{$ifdef fpc}

{$endif}
begin
  tw3499_err:=true;
  tw3499_c := Class1.create();
  tw3499_e := Class2.create();
  tw3499_c.p(tw3499_e.d);
  tw3499_c.proc;
  if tw3499_err then
    halt(1);
end;
{$pop}

end.
