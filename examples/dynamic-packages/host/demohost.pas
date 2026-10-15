unit DemoHost;
{$mode objfpc}{$H+}
interface
procedure RunDemo(Console: Boolean);
implementation
uses SysUtils, PkgDemoTypes, PkgDemoLeft, PkgDemoRight;
procedure Check(Condition: Boolean; const Message: string);
begin
  if not Condition then raise Exception.Create(Message);
end;
procedure RunDemo(Console: Boolean);
var
  Obj: TPackageValue;
  Value: TManaged;
  Caught: Boolean;
  Kind, FileName: string;
begin
  if Console then Kind:='console' else Kind:='gui';
  FileName:=ParamStr(1);
  if FileName='' then FileName:=ExtractFileName(ParamStr(0))+'.log';
  BeginLog(FileName);
  Check(IsConsole=Console,'subsystem startup');
  Check((InitCount=1) and (Trace='BLRH'),'initialization order: '+Trace);
  Check(ClassAddress=Pointer(TPackageValue),'class identity');
  Check(RTTIAddress=TypeInfo(TPackageValue),'RTTI identity');
  Obj:=NewObject;
  Check((Obj is TPackageValue) and (Length(Obj.Text)=40),'provider allocation');
  Obj.Free;
  Obj:=TPackageValue.Create;
  Obj.Text:=StringOfChar('h',60);
  FreeObject(Obj);
  Check(DestroyCount=2,'cross-image destruction');
  Value:=NewManaged;
  Check((Length(Value.Text)=100) and (Value.Values[1]=23) and
    (Value.Intf.GetValue=42),'managed return');
  Finalize(Value);
  FillChar(Value,SizeOf(Value),0);
  Value.Text:=StringOfChar('h',80);
  SetLength(Value.Values,7);
  ClearManaged(Value);
  Caught:=False;
  try RaiseProbe; except on E: EPackageDemo do Caught:=E.Message='typed package exception'; end;
  Check(Caught,'typed exception');
  Check(MessageText='package resource','resource string');
  Check(WideText='package wide','wide-string initialization');
  LogLine('PASS '+Kind);
  if Console then WriteLn('PASS console package host');
end;
initialization
  Trace:=Trace+'H';
finalization
  LogLine('final=h');
end.
