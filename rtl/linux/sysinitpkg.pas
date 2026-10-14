unit SysInitPkg;

{$mode objfpc}{$H+}
{$define FPC_PACKAGE_STARTUP}
{$linklib c}

interface

{$i si_intf.inc}

implementation

uses FPCPackage, SysUtils;

{$i sysnr.inc}
{$i si_impl.inc}

var
  Root: TPackageDescriptor; external name 'FPC_PACKAGE_ROOT';

procedure HostEntry(constref Info: TEntryInformation); external name 'FPC_SysEntry';
function NativeWrite(FD: LongInt; Buffer: Pointer; Count: SizeUInt): SizeInt;
  cdecl; external 'c' name 'write';
procedure NativeExit(Code: LongInt); cdecl; external 'c' name '_exit';

procedure SysEntry(constref Entry: TEntryInformation);
var Info: TEntryInformation; Text: AnsiString;
begin
  Info:=Entry;
  try
    PreparePackageStartup(@Root);
    PreparePackageHost(Info);
  except
    on E: Exception do
      begin
        Text:='Package startup failed: '+E.ClassName+': '+E.Message+#10;
        NativeWrite(2,Pointer(Text),Length(Text));
        NativeExit(217);
      end;
    else NativeExit(217);
  end;
  HostEntry(Info);
end;

{ Use the existing glibc executable entry and halt ABI. Pascal activation runs
  from main, after ld.so and libc startup have completed. }
{$i si_c.inc}

end.
