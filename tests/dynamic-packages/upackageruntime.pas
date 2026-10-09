unit upackageruntime;
{$mode objfpc}{$H+}
interface
uses SysUtils;
type
  EPackageProbe = class(Exception);
  TPackageObject = class
    Text: string;
    destructor Destroy; override;
  end;
  IValue = interface
    ['{3C6C1AE6-0C50-4D92-9C85-A47B034D4437}']
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
  UnusedReady: Boolean;
resourcestring
  MessageText = 'package resource';
const
  WideText: WideString = 'package wide';
function NewObject: TPackageObject;
procedure FreeObject(Value: TPackageObject);
function NewManaged: TManaged;
procedure ClearManaged(var Value: TManaged);
procedure RaiseProbe;
function ClassAddress: Pointer;
function RTTIAddress: Pointer;
function Initializations: LongInt; cdecl; public name 'NX_RuntimeInitializations';
implementation
type
  TValue = class(TInterfacedObject, IValue)
    function GetValue: LongInt;
  end;
function TValue.GetValue: LongInt;
begin Result:=42; end;
destructor TPackageObject.Destroy;
begin Inc(DestroyCount); inherited Destroy; end;
function NewObject: TPackageObject;
begin
  Result:=TPackageObject.Create;
  Result.Text:=StringOfChar('p',40);
end;
procedure FreeObject(Value: TPackageObject);
begin Value.Free; end;
function NewManaged: TManaged;
begin
  Result.Text:=StringOfChar('m',100);
  SetLength(Result.Values,2); Result.Values[0]:=17; Result.Values[1]:=23;
  Result.Intf:=TValue.Create;
end;
procedure ClearManaged(var Value: TManaged);
begin
  Finalize(Value);
  FillChar(Value,SizeOf(Value),0);
end;
procedure RaiseProbe;
begin raise EPackageProbe.Create('typed package exception'); end;
function ClassAddress: Pointer;
begin Result:=Pointer(TPackageObject); end;
function RTTIAddress: Pointer;
begin Result:=TypeInfo(TPackageObject); end;
function Initializations: LongInt; cdecl;
begin Result:=InitCount; end;
initialization
  Inc(InitCount);
  Trace:='A';
finalization
  WriteLn('FINAL A');
  Flush(Output);
end.
