unit PackageNative;
{$mode objfpc}{$H+}
interface
uses SysUtils;
function PackageFileName(const Stem: string): string;
function NativePackageHandle(const Name: string): HMODULE;
function PackageSymbol(Handle: HMODULE; const Name: string): Pointer;
function PackageResourceExists(Handle: HMODULE; ID: Word): Boolean;
implementation
uses {$ifdef windows}Windows{$else}dl{$endif};
function PackageFileName(const Stem: string): string;
begin
{$ifdef windows}
  Result:=Stem+'.dll';
{$else}
  Result:='lib'+Stem+'.so';
{$endif}
end;
function NativePackageHandle(const Name: string): HMODULE;
begin
{$ifdef windows}
  Result:=Windows.GetModuleHandleA(PAnsiChar(Name));
{$else}
  Result:=HMODULE(dlopen(PAnsiChar(Name),RTLD_NOW or RTLD_NOLOAD));
  if Result<>0 then dlclose(Pointer(Result));
{$endif}
end;
function PackageSymbol(Handle: HMODULE; const Name: string): Pointer;
begin
  Result:=System.GetProcAddress(Handle,Name);
end;
function PackageResourceExists(Handle: HMODULE; ID: Word): Boolean;
begin
  Result:=System.FindResource(Handle,PAnsiChar(PtrUInt(ID)),PAnsiChar(10))<>0;
end;
end.
