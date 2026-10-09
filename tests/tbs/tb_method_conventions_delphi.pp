{ Static Delphi class methods, CDecl headers, SafeCall functions and Deprecated methods. }

{$mode delphi}
uses Classes, SysUtils;

{ tw10998.pp }
{$mode delphi}

type
  TMyClass = class
  public
    class procedure StaticCall; static;
  end;

class procedure TMyClass.StaticCall;
begin
  WriteLn('Static method was called!');
end;

{ tw12242.pp }
{
 staticbug.pas

 With FPC 2.2.2:

 staticbug.lpr(24,31) Error: function header doesn't match the previous declaration "class TMyController.doClose(Pointer, Pointer, Pointer);CDecl"
}

{$mode delphi}

type

  { TMyController }

  TMyController = class
  public
    class procedure doClose(_self: Pointer; _cmd: Pointer; sender: Pointer); cdecl; static;
  end;

class procedure TMyController.doClose(_self: Pointer; _cmd: Pointer; sender: Pointer); cdecl; static;
begin
end;

{ tw8523.pp }
{$MODE DELPHI}

type
TDADataTable =class(TObject)
public
function GetAsCurrency(Index: integer): Currency;safecall;
end;

function TDADataTable.GetAsCurrency(Index: integer): Currency;
begin
Result:=0;
end;

{ tw3265.pp }
{$MODE Delphi}
type
  TTest = class (TObject)
    procedure Test; deprecated;
  end;

procedure TTest.Test;
begin
end;

begin
  { tw10998.pp }
  TMyClass.StaticCall;
  ;
end.
