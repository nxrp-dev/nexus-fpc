unit SysInitPkg;

{$mode objfpc}

interface

implementation

uses FPCPackage;

var
  SysInstance: QWord;
  { The legacy resource adapter is linked into this image and expects this
    pointer. It must resolve to this image's handle, not shared System data. }
  ResourceInstance: PQWord = @SysInstance; public name '_FPC_SysInstance';
  TlsKeyVar: DWord = $ffffffff;
  InitFinalTable: record end; external name 'INITFINAL';
  ThreadvarTablesTable: record end; external name 'FPC_THREADVARTABLES';
  WideInitTables: record end; external name 'FPC_WIDEINITTABLES';
  ResStrInitTables: record end; external name 'FPC_RESSTRINITTABLES';
  ResourceStringTables: record end; external name 'FPC_RESOURCESTRINGTABLES';
  Root: TPackageDescriptor; external name 'FPC_PACKAGE_ROOT';
  ImageHandle: SizeUInt; external name 'FPC_PACKAGE_HANDLE';

procedure ExeEntry(constref Info: TEntryInformation); external name '_FPC_EXE_Entry';
procedure PascalMain; external name 'PASCALMAIN';
function GetModuleHandle(Name: PChar): QWord; stdcall; external 'kernel32' name 'GetModuleHandleA';

const
  Info: TEntryInformation = (
    InitFinalTable: @InitFinalTable;
    ThreadvarTablesTable: @ThreadvarTablesTable;
    ResourceStringTables: @ResourceStringTables;
    ResStrInitTables: @ResStrInitTables;
    ResLocation: nil;
    PascalMain: @PascalMain;
    valgrind_used: false;
    OS: (TlsKeyAddr: @TlsKeyVar; SysInstance: @SysInstance; WideInitTables: @WideInitTables)
  );

procedure Start(Console: Boolean);
begin
  SysInstance:=GetModuleHandle(nil);
  ImageHandle:=SysInstance;
  IsConsole:=Console;
  PreparePackageStartup(@Root);
  PreparePackageHost(Info);
  ExeEntry(Info);
end;

procedure ConsoleStart; stdcall; public name '_mainCRTStartup';
begin
  Start(true);
end;

procedure GUIStart; stdcall; public name '_WinMainCRTStartup';
begin
  Start(false);
end;

end.
