unit PkgDemoTypes;
{$mode objfpc}{$H+}
interface
uses SysUtils;
type
  EPackageDemo = class(Exception);
  TPackageValue = class
    Text: string;
    destructor Destroy; override;
  end;
  IValue = interface
    ['{3620116E-507B-4775-B89C-8AA46CE13143}']
    function GetValue: LongInt;
  end;
  TManaged = record
    Text: string;
    Values: array of LongInt;
    Intf: IValue;
  end;
var
  Trace: string;
  InitCount, DestroyCount: LongInt;
resourcestring
  MessageText = 'package resource';
const
  WideText: WideString = 'package wide';
function NewObject: TPackageValue;
procedure FreeObject(Value: TPackageValue);
function NewManaged: TManaged;
procedure ClearManaged(var Value: TManaged);
procedure RaiseProbe;
function ClassAddress: Pointer;
function RTTIAddress: Pointer;
procedure BeginLog(const Filename: string);
procedure LogLine(const Value: string);
implementation
type
  TValue = class(TInterfacedObject, IValue)
    function GetValue: LongInt;
  end;
var
  LogFilename: string;
function TValue.GetValue: LongInt;
begin Result:=42; end;
destructor TPackageValue.Destroy;
begin Inc(DestroyCount); inherited Destroy; end;
function NewObject: TPackageValue;
begin
  Result:=TPackageValue.Create;
  Result.Text:=StringOfChar('p',40);
end;
procedure FreeObject(Value: TPackageValue);
begin Value.Free; end;
function NewManaged: TManaged;
begin
  Result.Text:=StringOfChar('m',100);
  SetLength(Result.Values,2);
  Result.Values[0]:=17; Result.Values[1]:=23;
  Result.Intf:=TValue.Create;
end;
procedure ClearManaged(var Value: TManaged);
begin
  Finalize(Value);
  FillChar(Value,SizeOf(Value),0);
end;
procedure RaiseProbe;
begin raise EPackageDemo.Create('typed package exception'); end;
function ClassAddress: Pointer;
begin Result:=Pointer(TPackageValue); end;
function RTTIAddress: Pointer;
begin Result:=TypeInfo(TPackageValue); end;
procedure BeginLog(const Filename: string);
var F: Text;
begin
  LogFilename:=Filename;
  Assign(F,LogFilename); Rewrite(F); Close(F);
  LogLine('init='+Trace);
end;
procedure LogLine(const Value: string);
var F: Text;
begin
  if LogFilename='' then Exit;
  Assign(F,LogFilename); Append(F);
  WriteLn(F,Value); Close(F);
end;
initialization
  Inc(InitCount);
  Trace:='B';
finalization
  LogLine('final=b');
end.
