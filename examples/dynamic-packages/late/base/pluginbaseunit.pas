unit PluginBaseUnit;
{$mode objfpc}{$H+}
{$R pluginbase.res}
interface
uses Classes, SysUtils, TypInfo, PkgContracts;
type
  TPluginComponent = class(TComponent);
  TPluginColour = (pcRed, pcGreen);
resourcestring
  PluginMessage = 'late package resource';
function PluginResource: string; cdecl; public name 'PluginResource';
function PluginEnum: PTypeInfo; cdecl; public name 'PluginEnum';
procedure PluginRaise; cdecl; public name 'PluginRaise';
implementation
function PluginResource: string; cdecl;
begin Result:=PluginMessage; end;
function PluginEnum: PTypeInfo; cdecl;
begin Result:=TypeInfo(TPluginColour); end;
procedure PluginRaise; cdecl;
begin raise EPluginCall.Create('typed late package exception'); end;
procedure ClearApplicationCallback;
begin ApplicationCallback:=nil; end;
procedure RemovedCallback;
begin raise Exception.Create('Unregistered package cleanup was called'); end;
function PluginIdentToInt(const Ident: string; var Value: LongInt): Boolean;
begin Result:=Ident='plugin-green'; if Result then Value:=1; end;
function PluginIntToIdent(Value: LongInt; var Ident: string): Boolean;
begin Result:=Value=1; if Result then Ident:='plugin-green'; end;
function PluginFindComponent(const Name: string): TComponent;
begin Inc(FindComponentCalls); Result:=nil; end;
function PluginInitComponent(Instance: TComponent; RootAncestor: TClass): Boolean;
begin Inc(InitComponentCalls); Result:=true; end;
initialization
  Inc(BaseInitializations);
  Trace:=Trace+'B';
  RegisterClass(TPluginComponent);
  RegisterClassAlias(TPluginComponent,'LatePluginAlias');
  AddEnumElementAliases(TypeInfo(TPluginColour),['late-red','late-green'],0);
  RegisterIntegerConsts(TypeInfo(TPluginColour),@PluginIdentToInt,@PluginIntToIdent);
  RegisterFindGlobalComponentProc(@PluginFindComponent);
  RegisterInitComponentHandler(TComponent,@PluginInitComponent);
  ApplicationCallback:=@PluginRaise;
  RegisterPackageCleanup(PackageModuleFromAddress(Pointer(TPluginComponent)),@ClearApplicationCallback);
  RegisterPackageCleanup(PackageModuleFromAddress(Pointer(TPluginComponent)),@RemovedCallback);
  UnregisterPackageCleanup(PackageModuleFromAddress(Pointer(TPluginComponent)),@RemovedCallback);
finalization
  Trace:=Trace+'b';
  { Intentionally rely on image-owned RTL cleanup for registrations and aliases. }
end.
