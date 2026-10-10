{
    This file is part of the Free Pascal run time library.
    Copyright (c) 2002 by Peter Vreman,
    member of the Free Pascal development team.

    Linux (pthreads) threading support implementation

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}


{*****************************************************************************
                           Local WINApi imports
*****************************************************************************}

{$ifndef WINCE}
function TlsAlloc : DWord;
  stdcall;external KernelDLL name 'TlsAlloc';
function TlsFree(dwTlsIndex : DWord) : LongBool;
  stdcall;external KernelDLL name 'TlsFree';
{$endif WINCE}
function TlsGetValue(dwTlsIndex : DWord) : pointer;
stdcall;external KernelDLL name 'TlsGetValue';
function TlsSetValue(dwTlsIndex : DWord;lpTlsValue : pointer) : LongBool;
  stdcall;external KernelDLL name 'TlsSetValue';
function CreateThread(lpThreadAttributes : pointer;
  dwStackSize : SIZE_T; lpStartAddress : pointer;lpParameter : pointer;
  dwCreationFlags : DWord;var lpThreadId : DWord) : THandle;
  stdcall;external KernelDLL name 'CreateThread';
procedure ExitThread(dwExitCode : DWord);
  stdcall;external KernelDLL name 'ExitThread';
procedure Sleep(dwMilliseconds: DWord); stdcall;external KernelDLL name 'Sleep';
function  WinSuspendThread (threadHandle : THandle) : dword; stdcall;external KernelDLL name 'SuspendThread';
function  WinResumeThread  (threadHandle : THandle) : dword; stdcall;external KernelDLL name 'ResumeThread';
function  WinCloseHandle  (threadHandle : THandle) : dword; stdcall;external KernelDLL name 'CloseHandle';
function  TerminateThread  (threadHandle : THandle; var exitCode : dword) : boolean; stdcall;external KernelDLL name 'TerminateThread';
function  WaitForSingleObject (hHandle : THandle;Milliseconds: dword): dword; stdcall;external KernelDLL name 'WaitForSingleObject';
function  WinThreadSetPriority (threadHandle : THandle; Prio: longint): boolean; stdcall;external KernelDLL name 'SetThreadPriority';
function  WinThreadGetPriority (threadHandle : THandle): LongInt; stdcall;external KernelDLL name 'GetThreadPriority';
{$ifndef WINCE}
function WinGetCurrentThread: THandle; stdcall; external KernelDLL name 'GetCurrentThread';
function WinOpenThread(dwDesiredAccess: DWord; bInheritHandle: Boolean; dwThreadId: DWord): THandle; stdcall; external KernelDLL name 'OpenThread';
function WinIsDebuggerPresent: Boolean; stdcall; external KernelDLL name 'IsDebuggerPresent';
type
  TSetThreadDescription = function(threadHandle: THandle; lpThreadDescription: PWideChar): HResult; stdcall;
var
  WinSetThreadDescription: TSetThreadDescription;
function  CreateEvent(lpEventAttributes:pointer;bManualReset:longbool;bInitialState:longbool;lpName:PAnsiChar): THandle; stdcall; external KernelDLL name 'CreateEventA';
function  ResetEvent(hEvent:THandle):LONGBOOL; stdcall; external KernelDLL name 'ResetEvent';
function  SetEvent(hEvent:THandle):LONGBOOL; stdcall; external KernelDLL name 'SetEvent';
{$endif WINCE}

procedure WinInitCriticalSection(var cs : TRTLCriticalSection);
  stdcall;external KernelDLL name 'InitializeCriticalSection';

procedure WinDoneCriticalSection(var cs : TRTLCriticalSection);
  stdcall;external KernelDLL name 'DeleteCriticalSection';

procedure WinEnterCriticalSection(var cs : TRTLCriticalSection);
  stdcall;external KernelDLL name 'EnterCriticalSection';

procedure WinLeaveCriticalSection(var cs : TRTLCriticalSection);
  stdcall;external KernelDLL name 'LeaveCriticalSection';

CONST
   WAIT_OBJECT_0 = 0;
   WAIT_TIMEOUT = $102;

function WinTryEnterCriticalSection(var cs : TRTLCriticalSection):longint;
  stdcall;external KernelDLL name 'TryEnterCriticalSection';

{*****************************************************************************
                             Threadvar support
*****************************************************************************}

    type
      PThreadvarNode=^TThreadvarNode;
      TThreadvarNode=record
        Prev, Next: PThreadvarNode;
        Context: Pointer;
      end;

    var
      {$ifdef FPC_HAS_INDIRECT_ENTRY_INFORMATION}
      TLSKey: PDword = nil; public name '_FPC_TlsKey';
      {$else}
      TLSKeyVar: DWord = $ffffffff;
      TLSKey: PDword = @TLSKeyVar; public name '_FPC_TlsKey';
      {$endif}
      DllProcessAttachPerformed: Boolean;
      AllThreadvarsLock: TRTLCriticalSection;
      AllThreadvars: PThreadvarNode;

    procedure SysSetThreadVarContext(Context: Pointer);
    var N: PThreadvarNode; SavedError: DWord;
    begin
      SavedError:=GetLastError;
      N:=HeapAlloc(GetProcessHeap,HEAP_ZERO_MEMORY,SizeOf(N^));
      if N=nil then ThreadVarFatal;
      N^.Context:=Context;
      if not TlsSetValue(TLSKey^,N) then ThreadVarFatal;
      if IsLibrary then
        begin
          WinEnterCriticalSection(AllThreadvarsLock);
          N^.Next:=AllThreadvars;
          if N^.Next<>nil then N^.Next^.Prev:=N;
          AllThreadvars:=N;
          WinLeaveCriticalSection(AllThreadvarsLock);
        end;
      SetLastError(SavedError);
    end;

    procedure SysAllocateThreadVars; public name '_FPC_SysAllocateThreadVars';
    var SavedError: DWord;
    begin
      SavedError:=GetLastError;
      if TLSKey^=$ffffffff then ThreadVarFatal;
      if TlsGetValue(TLSKey^)=nil then
        SysSetThreadVarContext(AllocateThreadVarContext);
      SetLastError(SavedError);
    end;

    procedure SysInitTLS;
    begin
      if TLSKey^=$ffffffff then
        begin
          if IsLibrary then WinInitCriticalSection(AllThreadvarsLock);
          TLSKey^:=TlsAlloc;
          if TLSKey^=$ffffffff then ThreadVarFatal;
          InitThreadVars;
        end;
    end;

    procedure SysFiniMultithreading;
    var N, Next: PThreadvarNode;
    begin
      if TLSKey^=$ffffffff then Exit;
      TlsFree(TLSKey^);
      TLSKey^:=$ffffffff;
      ThreadVarContextProc:=nil;
      if IsLibrary then
        begin
          N:=AllThreadvars; AllThreadvars:=nil;
          while N<>nil do
            begin
              Next:=N^.Next;
              ReleaseThreadVarContext(N^.Context);
              HeapFree(GetProcessHeap,0,N);
              N:=Next;
            end;
          WinDoneCriticalSection(AllThreadvarsLock);
        end;
    end;

{$ifdef cpux86_64}
    function SysGetThreadVarContextSlow: Pointer; forward;
    function SysGetThreadVarContext: Pointer; assembler; nostackframe;
    asm
      mov TLSKey(%rip),%rdx
      mov (%rdx),%edx
      cmp $0x40,%edx
      jae .LExpansion
      mov %gs:0x1480(,%rdx,8),%rax
      test %rax,%rax
      jz .LUnallocated
      mov 16(%rax),%rax
      ret
.LExpansion:
      cmp $0x440,%edx
      jae .LUnallocated
      mov %gs:0x1780,%rax
      test %rax,%rax
      jz .LUnallocated
      mov -0x200(%rax,%rdx,8),%rax
      test %rax,%rax
      jz .LUnallocated
      mov 16(%rax),%rax
      ret
.LUnallocated:
      jmp SysGetThreadVarContextSlow
    end;
{$endif}

    function {$ifdef cpux86_64}SysGetThreadVarContextSlow{$else}SysGetThreadVarContext{$endif}: Pointer;
    var N: PThreadvarNode; SavedError: DWord;
    begin
      SavedError:=GetLastError;
      N:=TlsGetValue(TLSKey^);
      if N=nil then
        begin
          SysAllocateThreadVars;
          N:=TlsGetValue(TLSKey^);
          InitThread($1000000);
        end;
      SetLastError(SavedError);
      Result:=N^.Context;
    end;

    procedure SysReleaseThreadVars;
    var N: PThreadvarNode;
    begin
      if TLSKey^=$ffffffff then Exit;
      N:=TlsGetValue(TLSKey^);
      if N=nil then Exit;
      TlsSetValue(TLSKey^,nil);
      if IsLibrary then
        begin
          WinEnterCriticalSection(AllThreadvarsLock);
          if N^.Next<>nil then N^.Next^.Prev:=N^.Prev;
          if N^.Prev<>nil then N^.Prev^.Next:=N^.Next
          else AllThreadvars:=N^.Next;
          WinLeaveCriticalSection(AllThreadvarsLock);
        end;
      ReleaseThreadVarContext(N^.Context);
      HeapFree(GetProcessHeap,0,N);
    end;


{*****************************************************************************
                            Thread starting
*****************************************************************************}

    type
      pthreadinfo = ^tthreadinfo;
      tthreadinfo = record
        f : tthreadfunc;
        p : pointer;
        stklen : ptruint;
      end;

    function ThreadMain(param : pointer) : Longint; stdcall;
      var
        ti : tthreadinfo;
      begin
        { Copy parameter to local data }
        ti:=pthreadinfo(param)^;

        { Handle all possible threadvar models:
          - dynamic threadvars: initialized either in DllMain,
            or upon accessing the threadvar ThreadID;
          - static threadvars+TLS callback: initialized in TLS callback;
          - static threadvars, no callback: ThreadID remains 0 and
            initialization happens here. }
        if ThreadID=TThreadID(0) then
          begin
            InitThread(ti.stklen);
{$ifndef wince}
{$ifdef win32}
            if Assigned(SetThreadStackGuarantee) then
{$endif win32}
              SetThreadStackGuaranteeTo(StackMargin);
{$endif wince}
          end;

        dispose(pthreadinfo(param));

        { Start thread function }
{$ifdef DEBUG_MT}
        writeln('Jumping to thread function of thread ',Win32GetCurrentThreadId);
{$endif DEBUG_MT}
{$if defined(FPC_USE_WIN64_SEH) or defined(FPC_USE_WIN32_SEH)}
        { use special 'top-level' exception handler around the thread function }
        ThreadMain:=main_wrapper(ti.p,pointer(ti.f));
{$else FPC_USE_WIN64_SEH}
        ThreadMain:=ti.f(ti.p);
{$endif FPC_USE_WIN64_SEH or FPC_USE_WIN32_SEH}
      end;


    function SysBeginThread(sa : Pointer;stacksize : ptruint;
                         ThreadFunction : tthreadfunc;p : pointer;
                         creationFlags : dword;var ThreadId : TThreadID) : TThreadID;
      var
        ti : pthreadinfo;
        _threadid : dword;
      begin
{$ifdef DEBUG_MT}
        writeln('Creating new thread');
{$endif DEBUG_MT}
        { Initialize multithreading if not done }
        SysInitTLS;
        if not IsMultiThread then
          begin
           { lazy initialize thread support }
            LazyInitThreading;
            IsMultiThread:=true;
          end;

        { the only way to pass data to the newly created thread
          in a MT safe way, is to use the heap }
        new(ti);
        ti^.f:=ThreadFunction;
        ti^.p:=p;
        ti^.stklen:=stacksize;
{$ifdef DEBUG_MT}
        writeln('Starting new thread');
{$endif DEBUG_MT}
        _threadid:=0;
        SysBeginThread:=CreateThread(sa,stacksize,@ThreadMain,ti,creationflags,_threadid);

        { creation failed? if yes, we dispose the parameter record }
        if SysBeginThread=0 then
          begin
{$ifdef DEBUG_MT}
            writeln('Thread creation failed');
{$endif DEBUG_MT}
            dispose(ti);
          end;

        ThreadID:=_threadid;
      end;


    procedure SysEndThread(ExitCode : DWord);
      begin
        DoneThread;
        ExitThread(ExitCode);
      end;


    procedure SysThreadSwitch;
    begin
      Sleep(0);
    end;


    function  SysSuspendThread (threadHandle : TThreadID) : dword;
    begin
      SysSuspendThread:=WinSuspendThread(threadHandle);
    end;


    function  SysResumeThread  (threadHandle : TThreadID) : dword;
    begin
      SysResumeThread:=WinResumeThread(threadHandle);
    end;


    function  SysKillThread (threadHandle : TThreadID) : dword;
    var exitCode : dword;
    begin
      if not TerminateThread (threadHandle, exitCode) then
        SysKillThread := GetLastError
      else
        SysKillThread := 0;
    end;

    function  SysCloseThread (threadHandle : TThreadID) : dword;
    begin
      SysCloseThread:=winCloseHandle(threadHandle);
    end;

    function  SysWaitForThreadTerminate (threadHandle : TThreadID; TimeoutMs : longint) : dword;
    begin
      // shouldn't this be a msgwait in case the thread creates "Windows"  See comment in waitforsingle?
      if timeoutMs = 0 then dec (timeoutMs);  // $ffffffff is INFINITE
      // does waiting on thread require cowait too ?
      SysWaitForThreadTerminate := WaitForSingleObject(threadHandle, TimeoutMs);
    end;


    function  SysThreadSetPriority (threadHandle : TThreadID; Prio: longint): boolean;            {-15..+15, 0=normal}
    begin
      SysThreadSetPriority:=WinThreadSetPriority(threadHandle,Prio);
    end;


    function  SysThreadGetPriority (threadHandle : TThreadID): longint;
    begin
      SysThreadGetPriority:=WinThreadGetPriority(threadHandle);
    end;

    function  SysGetCurrentThreadId : TThreadID;
    begin
      SysGetCurrentThreadId:=Win32GetCurrentThreadId;
    end;

{$ifndef WINCE}
    { following method is supported on older Windows versions AND currently only supported method by GDB }
    procedure RaiseMSVCExceptionMethod(threadHandle: TThreadID; const ThreadName: AnsiString);
    const
      MS_VC_EXCEPTION: DWord = $406D1388;
    type
      THREADNAME_INFO = record
        dwType: DWord; // Must be 0x1000.
        szName: PAnsiChar; // Pointer to name (in user addr space).
        dwThreadID: DWord; // Thread ID (-1=caller thread).
        dwFlags: DWord; // Reserved for future use, must be zero.
      end;
    var
      thrdinfo: THREADNAME_INFO;
    begin
      thrdinfo.dwType:=$1000;
      thrdinfo.szName:=@ThreadName[1];
      thrdinfo.dwThreadID:=threadHandle;
      thrdinfo.dwFlags:=0;
      try
        RaiseException(MS_VC_EXCEPTION, 0, SizeOf(thrdinfo) div SizeOf(PtrUInt), @thrdinfo);
      except
        {do nothing}
      end;
    end;

    { following method needs at least Windows 10 version 1607 or Windows Server 2016 }
    procedure SetThreadDescriptionMethod(threadHandle: TThreadID; const ThreadName: UnicodeString);
    var
      thrdhandle: THandle;
      ClosingNeeded: Boolean;
    begin
      if threadHandle=TThreadID(-1) then
      begin
        thrdhandle:=WinGetCurrentThread;
        ClosingNeeded:=False;
      end
      else
      begin
        thrdhandle:=WinOpenThread($0400, False, threadHandle);
        ClosingNeeded:=True;
      end;

      WinSetThreadDescription(thrdhandle, @ThreadName[1]);

      if ClosingNeeded then
      begin
        CloseHandle(thrdhandle);
      end;
    end;
{$endif WINCE}

    procedure SysSetThreadDebugNameA(threadHandle: TThreadID; const ThreadName: AnsiString);
    begin
{$ifndef WINCE}
      if ThreadName = '' then
        Exit;

      if WinIsDebuggerPresent then
      begin
        RaiseMSVCExceptionMethod(threadHandle, ThreadName);
      end;

      if Assigned(WinSetThreadDescription) then
      begin
        SetThreadDescriptionMethod(threadHandle, UnicodeString(ThreadName));
      end;
{$else WINCE}
      {$Warning SetThreadDebugNameA needs to be implemented}
{$endif WINCE}
    end;

    procedure SysSetThreadDebugNameU(threadHandle: TThreadID; const ThreadName: UnicodeString);
    begin
{$ifndef WINCE}
      if ThreadName = '' then
        Exit;

      if WinIsDebuggerPresent then
      begin
        RaiseMSVCExceptionMethod(threadHandle, AnsiString(ThreadName));
      end;

      if Assigned(WinSetThreadDescription) then
      begin
        SetThreadDescriptionMethod(threadHandle, ThreadName);
      end;
{$else WINCE}
      {$Warning SetThreadDebugNameU needs to be implemented}
{$endif WINCE}
    end;

{*****************************************************************************
                          Delphi/Win32 compatibility
*****************************************************************************}

procedure SySInitCriticalSection(var cs);
begin
  WinInitCriticalSection(PRTLCriticalSection(@cs)^);
end;


procedure SysDoneCriticalSection(var cs);
begin
  WinDoneCriticalSection(PRTLCriticalSection(@cs)^);
end;


procedure SysEnterCriticalSection(var cs);
begin
  WinEnterCriticalSection(PRTLCriticalSection(@cs)^);
end;

function SysTryEnterCriticalSection(var cs):longint;
begin
  result:=WinTryEnterCriticalSection(PRTLCriticalSection(@cs)^);
end;

procedure SySLeaveCriticalSection(var cs);
begin
  WinLeaveCriticalSection(PRTLCriticalSection(@cs)^);
end;


Const
  wrSignaled = 0;
  wrTimeout  = 1;
  wrAbandoned= 2;
  wrError    = 3;

function intBasicEventCreate(EventAttributes : Pointer;
AManualReset,InitialState : Boolean;const Name : ansistring):pEventState;
begin
  Result := PEventState(CreateEvent(EventAttributes, AManualReset, InitialState,Pointer(Name)));
end;

procedure intbasiceventdestroy(state:peventstate);

begin
  closehandle(THandle(state));
end;

procedure intbasiceventResetEvent(state:peventstate);

begin
  ResetEvent(THandle(state))
end;

procedure intbasiceventSetEvent(state:peventstate);

begin
  SetEvent(THandle(state));
end;

function FirstCoWaitForMultipleHandles(dwFlags, dwTimeout: DWORD; cHandles: uint32; pHandles: PWOHandleArray; out lpdwindex: DWORD): HRESULT; stdcall; forward;

var
  Ole32Dll: THandle = 0; { Unloaded at win32 & win64 system_exit. }
  CoWaitForMultipleHandlesImpl: function(dwFlags, dwTimeout: DWORD; cHandles: uint32; pHandles: PWOHandleArray; out lpdwindex: DWORD): HRESULT; stdcall
    = @FirstCoWaitForMultipleHandles;

function FirstCoWaitForMultipleHandles(dwFlags, dwTimeout: DWORD; cHandles: uint32; pHandles: PWOHandleArray; out lpdwindex: DWORD): HRESULT; stdcall;
var
  LocalOle32Dll: THandle;
begin
  if Ole32Dll = 0 then
  begin
    LocalOle32Dll := WinLoadLibraryW('ole32.dll');
    if InterlockedCompareExchange(Pointer(Ole32Dll), Pointer(LocalOle32Dll), nil) <> nil then
      WinFreeLibrary(LocalOle32Dll);
  end;
  CodePointer(CoWaitForMultipleHandlesImpl) := WinGetProcAddress(Ole32Dll, 'CoWaitForMultipleHandles');
  Result := CoWaitForMultipleHandlesImpl(dwFlags, dwTimeout, cHandles, pHandles, lpdwindex);
end;

function CoWaitForMultipleHandles(dwFlags, dwTimeout: DWORD; cHandles: uint32; pHandles: PWOHandleArray; out lpdwindex: DWORD): HRESULT;
begin
  Result := CoWaitForMultipleHandlesImpl(dwFlags, dwTimeout, cHandles, pHandles, lpdwindex);
end;

function intbasiceventWaitFor(Timeout : Cardinal;state:peventstate;UseCOMWait: Boolean = False) : longint;
const COWAIT_DEFAULT = 0;
      RPC_S_CALLPENDING = HRESULT($80010115);
var SignaledIndex : DWORD;
begin
   if UseComWait Then
     case CoWaitForMultipleHandles(COWAIT_DEFAULT, Timeout, 1, PWOHandleArray(@state), SignaledIndex) of
       S_OK: Result := wrSignaled;
       RPC_S_CALLPENDING: Result := wrTimeout;
       else Result := wrError;
     end
   else
     case WaitForSingleObject(THandle(state), Timeout) of
       WAIT_OBJECT_0: Result := wrSignaled;
       WAIT_TIMEOUT: Result := wrTimeout;
       else result := wrError; { WAIT_FAILED or any other value. Note that only mutex waits can return WAIT_ABANDONED. }
     end;
end;

function intRTLEventCreate: PRTLEvent;
begin
  Result := PRTLEVENT(CreateEvent(nil, false, false, nil));
end;

procedure intRTLEventDestroy(AEvent: PRTLEvent);
begin
  CloseHandle(THANDLE(AEvent));
end;

procedure intRTLEventSetEvent(AEvent: PRTLEvent);
begin
  SetEvent(THANDLE(AEvent));
end;

procedure intRTLEventResetEvent(AEvent: PRTLEvent);
begin
  ResetEvent(THANDLE(AEvent));
end;

procedure intRTLEventWaitFor(AEvent: PRTLEvent);
const
  INFINITE=dword(-1);
begin
  WaitForSingleObject(THANDLE(AEvent), INFINITE);
end;

procedure intRTLEventWaitForTimeout(AEvent: PRTLEvent;timeout : longint);
begin
  WaitForSingleObject(THANDLE(AEvent), timeout);
end;


Procedure InitSystemThreads;public name '_FPC_InitSystemThreads';
var
  WinThreadManager : TThreadManager;
{$ifndef WINCE}
  KernelHandle : THandle;
{$endif}
begin
  With WinThreadManager do
    begin
    InitManager            :=Nil;
    DoneManager            :=Nil;
    BeginThread            :=@SysBeginThread;
    EndThread              :=@SysEndThread;
    SuspendThread          :=@SysSuspendThread;
    ResumeThread           :=@SysResumeThread;
    KillThread             :=@SysKillThread;
    ThreadSwitch           :=@SysThreadSwitch;
    CloseThread            :=@SysCloseThread;
    WaitForThreadTerminate :=@SysWaitForThreadTerminate;
    ThreadSetPriority      :=@SysThreadSetPriority;
    ThreadGetPriority      :=@SysThreadGetPriority;
    GetCurrentThreadId     :=@SysGetCurrentThreadId;
    SetThreadDebugNameA    :=@SysSetThreadDebugNameA;
    SetThreadDebugNameU    :=@SysSetThreadDebugNameU;
    InitCriticalSection    :=@SysInitCriticalSection;
    DoneCriticalSection    :=@SysDoneCriticalSection;
    EnterCriticalSection   :=@SysEnterCriticalSection;
    TryEnterCriticalSection:=@SysTryEnterCriticalSection;
    LeaveCriticalSection   :=@SysLeaveCriticalSection;
    SetThreadVarContext    :=@SysSetThreadVarContext;
    GetThreadVarContext    :=@SysGetThreadVarContext;
    AllocateThreadVars     :=@SysAllocateThreadVars;
    ReleaseThreadVars      :=@SysReleaseThreadVars;
    BasicEventCreate       :=@intBasicEventCreate;
    BasicEventDestroy      :=@intBasicEventDestroy;
    BasicEventResetEvent   :=@intBasicEventResetEvent;
    BasicEventSetEvent     :=@intBasicEventSetEvent;
    BasiceventWaitFor      :=@intBasiceventWaitFor;
    RTLEventCreate         :=@intRTLEventCreate;
    RTLEventDestroy        :=@intRTLEventDestroy;
    RTLEventSetEvent       :=@intRTLEventSetEvent;
    RTLEventResetEvent     :=@intRTLEventResetEvent;
    RTLEventWaitFor        :=@intRTLEventWaitFor;
    RTLEventWaitForTimeout :=@intRTLEventWaitForTimeout;
    end;
  SetThreadManager(WinThreadManager);
  ThreadID := GetCurrentThreadID;
{$ifndef FPC_USE_TLS_DIRECTORY}
  if IsLibrary then
{$endif}
    SysInitTLS;

{$ifndef WINCE}
  KernelHandle:=GetModuleHandle(KernelDLL);
{$endif}

{$ifndef WINCE}
  if KernelHandle<>0 then
  begin
    WinSetThreadDescription:=TSetThreadDescription(WinGetProcAddress(KernelHandle, 'SetThreadDescription'));
  end;
{$endif WINCE}
end;

