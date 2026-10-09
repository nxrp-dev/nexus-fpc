program package_runtime_host;
{$mode objfpc}{$H+}
uses SysUtils, Windows, FPCPackage, upackageruntime, uleft, uright, uhost;
var
  Obj: TPackageObject;
  Value: TManaged;
  Caught: Boolean;
  FailHandle: THandle;
  FailedPackage: PPackageDescriptor;
procedure Check(Condition: Boolean; const Msg: string);
begin
  if not Condition then raise Exception.Create(Msg);
end;
begin
  Check((InitCount=1) and (Trace='AULRH') and UnusedReady,'initialization order: '+Trace);
  Check(ClassAddress=Pointer(TPackageObject),'class identity');
  Check(RTTIAddress=TypeInfo(TPackageObject),'RTTI identity');
  Obj:=NewObject;
  Check((Obj is TPackageObject) and (Length(Obj.Text)=40),'provider allocation');
  Obj.Free;
  Obj:=TPackageObject.Create;
  Obj.Text:=StringOfChar('h',60);
  FreeObject(Obj);
  Check(DestroyCount=2,'cross-image destruction');
  Value:=NewManaged;
  Check((Length(Value.Text)=100) and (Value.Values[1]=23) and
    (Value.Intf.GetValue=42),'managed return');
  { Release provider-created strings, arrays and interfaces in host code. }
  Finalize(Value);
  FillChar(Value,SizeOf(Value),0);
  Value.Text:=StringOfChar('h',80); SetLength(Value.Values,7);
  ClearManaged(Value);
  Caught:=false;
  try RaiseProbe; except on E: EPackageProbe do Caught:=E.Message='typed package exception'; end;
  Check(Caught,'typed exception');
  Check(MessageText='package resource','resource string');
  Check(WideText='package wide','wide-string initialization');
  FailHandle:=Windows.LoadLibraryA('pkgfail.dll');
  Check(FailHandle<>0,'map failure fixture');
  FailedPackage:=PPackageDescriptor(Windows.GetProcAddress(FailHandle,'FPC_PACKAGE_PKGFAIL'));
  Check(FailedPackage<>nil,'failure fixture descriptor');
  Check(Trace='AULRH','native loading executed initialization');
  Caught:=false;
  try
    InitializePackage(FailedPackage);
  except
    on E: EPackageProbe do Caught:=E.Message='initialization failure';
  end;
  Check(Caught and (Trace='AULRHF!f'),'package initialization rollback: '+Trace);
  Check((InitCount=1) and (FailedPackage^.Context^.InitCount=0),'rollback preserved live dependency');
  { Keep the registered descriptor mapped for this process lifetime. General
    library release/reference accounting is a later milestone. }
  WriteLn('PASS shared RTL: identity, allocation, managed values, exception, resources');
end.
