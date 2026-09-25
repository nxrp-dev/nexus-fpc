unit nxclangassembler;

{$i fpcdefs.inc}

interface

uses
  GlobType;

function NXQueueClangAssembly(const ACommand, AParameters,
  AAssemblyFile: TCmdStr; ADeleteAssemblyFile: Boolean): Boolean;
function NXDrainClangAssemblies: Boolean;
function NXClangAssemblyExitCode: LongInt;

implementation

uses
{$ifdef hasunix}
  BaseUnix, Unix,
{$endif hasunix}
{$if defined(win32) or defined(win64)}
  Windows,
{$endif}
  SysUtils, CClasses, CFileUtl;

type
  TNXClangAssemblyJob = class
  private
    FAssemblyFile: TCmdStr;
    FDeleteAssemblyFile: Boolean;
    FStarted: Boolean;
{$if defined(win32) or defined(win64)}
    FProcessHandle: THandle;
{$endif}
{$ifdef hasunix}
    FProcessID: TPid;
{$endif hasunix}
  public
    constructor Create(const ACommand, AParameters, AAssemblyFile: TCmdStr;
      ADeleteAssemblyFile: Boolean);
    destructor Destroy; override;
    function Wait: LongInt;
    procedure DeleteAssemblyFile;
  end;

  TNXClangAssemblerQueue = class
  private
    FActiveJobs: TFPObjectList;
    FExitCode: LongInt;
    FFailed: Boolean;
    FWorkerLimit: LongInt;
    function FinishFirst: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Submit(const ACommand, AParameters, AAssemblyFile: TCmdStr;
      ADeleteAssemblyFile: Boolean): Boolean;
    function Drain: Boolean;
    property ExitCode: LongInt read FExitCode;
  end;

var
  ClangAssemblerQueue: TNXClangAssemblerQueue;

constructor TNXClangAssemblyJob.Create(const ACommand, AParameters,
  AAssemblyFile: TCmdStr; ADeleteAssemblyFile: Boolean);
{$if defined(win32) or defined(win64)}
var
  CommandLine: UnicodeString;
  Executable: UnicodeString;
  ProcessInformation: TProcessInformation;
  StartupInfo: TStartupInfoW;
{$endif}
{$ifdef hasunix}
var
  Arguments: PPAnsiChar;
  CommandLine: RawByteString;
  Executable: RawByteString;
{$endif hasunix}
begin
  inherited Create;
  FAssemblyFile := AAssemblyFile;
  FDeleteAssemblyFile := ADeleteAssemblyFile;
{$if defined(win32) or defined(win64)}
  Executable := UnicodeString(ACommand);
  UniqueString(Executable);
  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.wShowWindow := 1;
  FillChar(ProcessInformation, SizeOf(ProcessInformation), 0);

  if Pos('"', ACommand) = 0 then
    CommandLine := '"' + UnicodeString(ACommand) + '"'
  else
    CommandLine := UnicodeString(ACommand);
  if AParameters <> '' then
    CommandLine := CommandLine + ' ' + UnicodeString(AParameters);
  CommandLine := CommandLine + #0;
  UniqueString(CommandLine);

  if not CreateProcessW(PWideChar(Executable), PWideChar(CommandLine),
      nil, nil, False,
      NORMAL_PRIORITY_CLASS, nil, nil, StartupInfo, ProcessInformation) then
    RaiseLastOSError;
  FProcessHandle := ProcessInformation.hProcess;
  CloseHandle(ProcessInformation.hThread);
  FStarted := True;
{$endif}
{$ifdef hasunix}
  Executable := ACommand;
  UniqueString(Executable);
  SetCodePage(Executable, DefaultFileSystemCodePage, True);
  CommandLine := UnixRequoteWithDoubleQuotes(AParameters);
  if CommandLine <> '' then
    begin
      UniqueString(CommandLine);
      SetCodePage(CommandLine, DefaultFileSystemCodePage, True);
      Arguments := StringToPPChar(PAnsiChar(CommandLine), 1);
      Arguments^ := PAnsiChar(Pointer(Executable));
    end
  else
    begin
      GetMem(Arguments, 2 * SizeOf(PAnsiChar));
      Arguments^ := PAnsiChar(Pointer(Executable));
      Arguments[1] := nil;
    end;

  FProcessID := FpFork;
  if FProcessID = 0 then
    begin
      FpExecVE(PAnsiChar(Pointer(Executable)), Arguments, EnvP);
      FpExit(127);
    end;
  FreeMem(Arguments);
  if FProcessID = -1 then
    RaiseLastOSError;
  FStarted := True;
{$endif hasunix}
end;

destructor TNXClangAssemblyJob.Destroy;
begin
  if FStarted then
    Wait;
  inherited Destroy;
end;

function TNXClangAssemblyJob.Wait: LongInt;
{$if defined(win32) or defined(win64)}
var
  ExitStatus: DWord;
{$endif}
begin
  if not FStarted then
    Exit(0);
{$if defined(win32) or defined(win64)}
  if WaitForSingleObject(FProcessHandle, INFINITE) = WAIT_FAILED then
    RaiseLastOSError;
  if not GetExitCodeProcess(FProcessHandle, ExitStatus) then
    RaiseLastOSError;
  CloseHandle(FProcessHandle);
  FProcessHandle := 0;
  Result := LongInt(ExitStatus);
{$endif}
{$ifdef hasunix}
  Result := WaitProcess(FProcessID);
  FProcessID := 0;
{$endif hasunix}
  FStarted := False;
end;

procedure TNXClangAssemblyJob.DeleteAssemblyFile;
begin
  if FDeleteAssemblyFile then
    SysUtils.DeleteFile(FAssemblyFile);
end;

constructor TNXClangAssemblerQueue.Create;
begin
  inherited Create;
  FActiveJobs := TFPObjectList.Create(True);
  FWorkerLimit := System.CPUCount;
  if FWorkerLimit < 1 then
    FWorkerLimit := 1;
end;

destructor TNXClangAssemblerQueue.Destroy;
begin
  Drain;
  FActiveJobs.Free;
  inherited Destroy;
end;

function TNXClangAssemblerQueue.FinishFirst: Boolean;
var
  ExitStatus: LongInt;
  Job: TNXClangAssemblyJob;
begin
  Job := TNXClangAssemblyJob(FActiveJobs[0]);
  ExitStatus := Job.Wait;
  if ExitStatus = 0 then
    Job.DeleteAssemblyFile
  else if not FFailed then
    begin
      FFailed := True;
      FExitCode := ExitStatus;
    end;
  FActiveJobs.Delete(0);
  Result := ExitStatus = 0;
end;

function TNXClangAssemblerQueue.Submit(const ACommand, AParameters,
  AAssemblyFile: TCmdStr; ADeleteAssemblyFile: Boolean): Boolean;
var
  Job: TNXClangAssemblyJob;
begin
  if FFailed then
    Exit(False);
  if FActiveJobs.Count >= FWorkerLimit then
    if not FinishFirst then
      Exit(False);

  Job := TNXClangAssemblyJob.Create(ACommand, AParameters, AAssemblyFile,
    ADeleteAssemblyFile);
  FActiveJobs.Add(Job);
  Result := True;
end;

function TNXClangAssemblerQueue.Drain: Boolean;
begin
  while FActiveJobs.Count > 0 do
    FinishFirst;
  Result := not FFailed;
end;

function NXQueueClangAssembly(const ACommand, AParameters,
  AAssemblyFile: TCmdStr; ADeleteAssemblyFile: Boolean): Boolean;
begin
  if not Assigned(ClangAssemblerQueue) then
    ClangAssemblerQueue := TNXClangAssemblerQueue.Create;
  Result := ClangAssemblerQueue.Submit(ACommand, AParameters, AAssemblyFile,
    ADeleteAssemblyFile);
end;

function NXDrainClangAssemblies: Boolean;
begin
  if Assigned(ClangAssemblerQueue) then
    Result := ClangAssemblerQueue.Drain
  else
    Result := True;
end;

function NXClangAssemblyExitCode: LongInt;
begin
  if Assigned(ClangAssemblerQueue) then
    Result := ClangAssemblerQueue.ExitCode
  else
    Result := 0;
end;

finalization
  ClangAssemblerQueue.Free;

end.
