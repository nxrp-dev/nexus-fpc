{ Consolidated classes regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode delphi}
uses classes,sysutils;

{ Case tb_method_conventions_delphi.pas }
{$push}
{ Static Delphi class methods, CDecl headers, SafeCall functions and Deprecated methods. }




{ tw10998.pas }


type
  tb_method_conventions_delphi_TMyClass = class
  public
    class procedure StaticCall; static;
  end;

class procedure tb_method_conventions_delphi_TMyClass.StaticCall;
begin
  WriteLn('Static method was called!');
end;

{ tw12242.pas }
{
 staticbug.pas

 With FPC 2.2.2:

 staticbug.lpr(24,31) Error: function header doesn't match the previous declaration "class TMyController.doClose(Pointer, Pointer, Pointer);CDecl"
}



type

  { TMyController }

  tb_method_conventions_delphi_TMyController = class
  public
    class procedure doClose(_self: Pointer; _cmd: Pointer; sender: Pointer); cdecl; static;
  end;

class procedure tb_method_conventions_delphi_TMyController.doClose(_self: Pointer; _cmd: Pointer; sender: Pointer); cdecl; static;
begin
end;

{ tw8523.pas }


type
tb_method_conventions_delphi_TDADataTable =class(TObject)
public
function GetAsCurrency(Index: integer): Currency;safecall;
end;

function tb_method_conventions_delphi_TDADataTable.GetAsCurrency(Index: integer): Currency;
begin
Result:=0;
end;

{ tw3265.pas }

type
  tb_method_conventions_delphi_TTest = class (TObject)
    procedure Test; deprecated;
  end;

procedure tb_method_conventions_delphi_TTest.Test;
begin
end;


{$pop}

{ Case tw16820.pas }
{$push}
{$ifdef fpc}
{$H+}
{$endif}



type

  { TForm1 }

  tw16820_TForm1 = class
  private
    { private declarations }
  public
    { public declarations }
    procedure test;
  end;

  tw16820_FNType = function(A, B: integer): integer;
var
  tw16820_Form1: tw16820_TForm1;

function tw16820_Add23(A, B: integer; C: cardinal): integer; overload; forward;
function tw16820_Add23(A, B: integer): integer; overload; forward;

const
  tw16820_FPArray: tw16820_FNType = tw16820_Add23;

function tw16820_Add23(A, B: integer; C: cardinal): integer; overload;
  begin
    Result := A + B + C;
    halt(1);
  end;

function tw16820_Add23(A, B: integer): integer; overload;
  begin
    Result := A - B;
  end;

{ TForm1 }

procedure tw16820_TForm1.test;
  var
    a, b: integer;
  begin
    a := 3;
    b := 4;
    writeln(tw16820_FParray(a, b));
end;

var
  tw16820_f: tw16820_tform1;

{$pop}

{ Case tw26993.pas }
{$push}






type

  { TExtendedTestCase }

  tw26993_TExtendedTestCase = record
  private
    FValue: extended;
  public
    property Value: extended read FValue write FValue;
    class operator Add(v1, v2: tw26993_TExtendedTestCase): tw26993_TExtendedTestCase;
    class operator Multiply(v1, v2: tw26993_TExtendedTestCase): tw26993_TExtendedTestCase;
  end;


{ TExtendedTestCase }

class operator tw26993_TExtendedTestCase.Add(v1, v2: tw26993_TExtendedTestCase): tw26993_TExtendedTestCase;
begin
  Result.Value := v1.Value + v2.Value;
end;

class operator tw26993_TExtendedTestCase.Multiply(v1, v2: tw26993_TExtendedTestCase):
tw26993_TExtendedTestCase;
begin
  Result.Value := v1.Value * v2.Value;
end;

var
  tw26993_e1,tw26993_e2,tw26993_e3: tw26993_textendedtestcase;

{$pop}

{ Case tw26993a.pas }
{$push}






type

  { TExtendedTestCase }

  tw26993a_TExtendedTestCase = record
  private
    FValue: extended;
    dummy: array[0..5] of byte;
  public
    property Value: extended read FValue write FValue;
    class operator Add(v1, v2: tw26993a_TExtendedTestCase): tw26993a_TExtendedTestCase;
    class operator Multiply(v1, v2: tw26993a_TExtendedTestCase): tw26993a_TExtendedTestCase;
  end;


{ TExtendedTestCase }

class operator tw26993a_TExtendedTestCase.Add(v1, v2: tw26993a_TExtendedTestCase): tw26993a_TExtendedTestCase;
begin
  Result.Value := v1.Value + v2.Value;
end;

class operator tw26993a_TExtendedTestCase.Multiply(v1, v2: tw26993a_TExtendedTestCase):
tw26993a_TExtendedTestCase;
begin
  Result.Value := v1.Value * v2.Value;
end;

var
  tw26993a_e1,tw26993a_e2,tw26993a_e3: tw26993a_textendedtestcase;

{$pop}

begin

{ Case tb_method_conventions_delphi.pas }
{$push}





begin
  { tw10998.pas }
  tb_method_conventions_delphi_TMyClass.StaticCall;
  ;
end;
{$pop}

{ Case tw16820.pas }
{$push}
{$ifdef fpc}

{$H+}
{$endif}
begin
  tw16820_f:=tw16820_tform1.create;
  tw16820_f.test;
  tw16820_f.free;
end;
{$pop}

{ Case tw26993.pas }
{$push}

begin
  tw26993_e1.fvalue:=2.0;
  tw26993_e2.fvalue:=3.0;
  tw26993_e3:=tw26993_e1+tw26993_e2;
  if (tw26993_e3*tw26993_e2).fvalue<>15.0 then
    halt(1);

end;
{$pop}

{ Case tw26993a.pas }
{$push}

begin
  tw26993a_e1.fvalue:=2.0;
  tw26993a_e2.fvalue:=3.0;
  tw26993a_e3:=tw26993a_e1+tw26993a_e2;
  if (tw26993a_e3*tw26993a_e2).fvalue<>15.0 then
    halt(1);

end;
{$pop}

end.
