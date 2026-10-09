unit LateHost;
{$mode objfpc}{$H+}
interface
procedure RunLateDemo(Console: Boolean);
implementation
uses SysUtils, Classes, TypInfo, Windows, PkgContracts;
type
  TResourceProbe = function: string; cdecl;
  TEnumProbe = function: PTypeInfo; cdecl;
  TRaiseProbe = procedure; cdecl;
procedure Check(Value: Boolean; const Message: string);
begin if not Value then raise Exception.Create(Message+': '+Trace); end;
function Translate(Name: AnsiString; Value: RTLString; Hash: LongInt; Arg: Pointer): RTLString;
begin
  Result:='';
  if Value='late package resource' then Result:='translated late resource';
end;
procedure RunLateDemo(Console: Boolean);
var Left,Again,Right,Base,RTL: HMODULE;
    Factory: TCreatePlugin; Obj: TPluginValue;
    ResourceProbe: TResourceProbe; EnumProbe: TEnumProbe; RaiseProbe: TRaiseProbe;
    EnumInfo: PTypeInfo; Caught: Boolean; Log: Text; Filename,Kind: string;
    Component: TComponent; FindCalls,InitCalls: LongInt;
begin
  Check(IsConsole=Console,'subsystem');
  Check(Trace='C','implementation was startup-linked');
  Check(Windows.GetModuleHandleA('pluginbase.dll')=0,'base was already mapped');
  Left:=LoadPackage('pluginleft.dll');
  Again:=LoadPackage('pluginleft.dll');
  Right:=LoadPackage('pluginright.dll');
  Check((Again=Left) and (Trace='CBLR') and (BaseInitializations=1),'repeat load/diamond');
  Base:=Windows.GetModuleHandleA('pluginbase.dll');
  Check((Base<>0) and (GetClass('LatePluginAlias')<>nil),'class registration');
  { Add another alias after initialization: ownership follows the class image. }
  RegisterClassAlias(GetClass('LatePluginAlias'),'HostAddedAlias');
  Check(FindClassHInstance(GetClass('LatePluginAlias'))=Base,'class image ownership');
  Check(FindResourceHInstance(Base)=Base,'resource image ownership');
  Check(Windows.FindResourceW(Base,PWideChar(101),PWideChar(10))<>0,'package native resource');
  Factory:=TCreatePlugin(Windows.GetProcAddress(Left,'CreatePlugin'));
  Check(Assigned(Factory),'factory export');
  Obj:=Factory();
  Check((Obj is TPluginValue) and (Obj.Text=StringOfChar('L',80)),'shared contract/managed return');
  Obj.Free;
  Check((ObjectsCreated=1) and (ObjectsDestroyed=1),'cross-image destruction');
  ResourceProbe:=TResourceProbe(Windows.GetProcAddress(Base,'PluginResource'));
  EnumProbe:=TEnumProbe(Windows.GetProcAddress(Base,'PluginEnum'));
  RaiseProbe:=TRaiseProbe(Windows.GetProcAddress(Base,'PluginRaise'));
  Check(ResourceProbe()='late package resource','resource value');
  SetResourceStrings(@Translate,nil);
  Check(ResourceProbe()='translated late resource','late resource translation');
  EnumInfo:=EnumProbe();
  Check(GetEnumeratedAliasValue(EnumInfo,'late-green')=1,'RTTI registration');
  Check(Assigned(FindIntToIdent(EnumInfo)) and Assigned(FindIdentToInt(EnumInfo)),
    'integer conversion registration');
  FindCalls:=FindComponentCalls;
  FindGlobalComponent('late-probe');
  Check(FindComponentCalls=FindCalls+1,'component lookup registration');
  Component:=TComponent.Create(nil);
  try
    InitCalls:=InitComponentCalls;
    Check(InitInheritedComponent(Component,TComponent) and (InitComponentCalls=InitCalls+1),
      'component initialization override');
  finally Component.Free; end;
  Caught:=false;
  try RaiseProbe(); except on E: EPluginCall do Caught:=E.Message='typed late package exception'; end;
  Check(Caught,'typed exception');
  { Application releases all executable references before the matching unload. }
  Factory:=nil; ResourceProbe:=nil; EnumProbe:=nil; RaiseProbe:=nil;
  UnloadPackage(Left);
  Check(Trace='CBLR','repeat reference finalized early');
  UnloadPackage(Again);
  Check((Trace='CBLRl') and (Windows.GetModuleHandleA('pluginbase.dll')=Base),'live branch lost dependency');
  UnloadPackage(Right);
  Check(Trace='CBLRlrb','reverse dependency finalization');
  Check((Windows.GetModuleHandleA('pluginbase.dll')=0) and
    (Windows.GetModuleHandleA('pluginleft.dll')=0) and
    (Windows.GetModuleHandleA('pluginright.dll')=0),'native references leaked');
  Check((GetClass('LatePluginAlias')=nil) and (GetClass('HostAddedAlias')=nil),'stale class alias');
  { This lookup compares stored addresses; it must not dereference the old type. }
  Check(GetEnumeratedAliasValue(EnumInfo,'late-green')=-1,'stale RTTI alias');
  Check(not Assigned(FindIntToIdent(EnumInfo)) and not Assigned(FindIdentToInt(EnumInfo)),
    'stale integer conversion callback');
  FindCalls:=FindComponentCalls;
  FindGlobalComponent('late-probe');
  Check(FindComponentCalls=FindCalls,'stale component lookup callback');
  Component:=TComponent.Create(nil);
  try
    InitCalls:=InitComponentCalls;
    Check(not InitInheritedComponent(Component,TComponent) and (InitComponentCalls=InitCalls),
      'component initialization handler was not restored');
  finally Component.Free; end;
  EnumInfo:=nil;
  Check(ApplicationCallback=nil,'application cleanup callback');
  SetResourceStrings(@Translate,nil); { Must not visit unmapped resource tables. }
  Left:=LoadPackage('pluginleft.dll');
  Check((Trace='CBLRlrbBL') and (BaseInitializations=2),'clean reload');
  UnloadPackage(Left);
  Check(Trace='CBLRlrbBLlb','reload finalization');
  RTL:=LoadPackage('nxrtl.dll');
  UnloadPackage(RTL);
  Check(Windows.GetModuleHandleA('nxrtl.dll')=RTL,'startup owner was unpinned');
  Caught:=false;
  try UnloadPackage(RTL); except on E: EPackageError do Caught:=true; end;
  Check(Caught,'unbalanced startup unload accepted');
  if Console then Kind:='console' else Kind:='gui';
  Filename:=ParamStr(1);
  if Filename='' then Filename:=ExtractFileName(ParamStr(0))+'.log';
  Assign(Log,Filename); Rewrite(Log);
  WriteLn(Log,'PASS late '+Kind); WriteLn(Log,Trace); Close(Log);
  if Console then WriteLn('PASS late package loading, unloading and cleanup');
end;
end.
