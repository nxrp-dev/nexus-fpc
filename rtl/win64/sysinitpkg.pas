unit SysInitPkg;

{$mode objfpc}

interface

implementation

uses FPCPackage, SysUtils;

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
function GetStdHandle(Kind: LongInt): QWord; stdcall; external 'kernel32' name 'GetStdHandle';
function WriteFile(Handle: QWord; Buffer: Pointer; Count: DWord; var Written: DWord;
  Overlapped: Pointer): LongBool; stdcall; external 'kernel32' name 'WriteFile';
procedure OutputDebugString(Text: PAnsiChar); stdcall; external 'kernel32' name 'OutputDebugStringA';
procedure ExitProcess(Code: DWord); stdcall; external 'kernel32' name 'ExitProcess';

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

procedure StartupFailure(const Message: AnsiString);
var Text: AnsiString; Written: DWord;
begin
  { Unit initialization and RTL text I/O may not yet be available. }
  Text:='Package startup failed: '+Message+#13#10;
  WriteFile(GetStdHandle(-12),PAnsiChar(Text),Length(Text),Written,nil);
  OutputDebugString(PAnsiChar(Text));
  ExitProcess(217);
end;

procedure Start(Console: Boolean);
begin
  SysInstance:=GetModuleHandle(nil);
  ImageHandle:=SysInstance;
  IsConsole:=Console;
  try
    PreparePackageStartup(@Root);
    PreparePackageHost(Info);
  except
    on E: Exception do StartupFailure(E.ClassName+': '+E.Message);
    else StartupFailure('Non-Exception object during package preparation');
  end;
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
