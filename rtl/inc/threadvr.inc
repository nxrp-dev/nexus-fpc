{
    This file is part of the Free Pascal run time library.
    Copyright (c) 1999-2000 by Michael Van Canneyt
    member of the Free Pascal development team

    Threadvar support, platform independent part

    See the file COPYING.FPC, included in this distribution,
    for details about the copyright.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

 **********************************************************************}


{*****************************************************************************
                           Threadvar support
*****************************************************************************}

{ Compiler ABI: descriptors contain an owner pointer and native-sized offset.
  Owners and tables are emitted by ngenutil. No inline variable storage exists. }
type
  PThreadVarOwner = ^TThreadVarOwner;
  PThreadVarDescriptor = ^TThreadVarDescriptor;
  TThreadVarDescriptor = record
    Owner: PThreadVarOwner;
    Offset: SizeUInt;
  end;
  PThreadVarEntry = ^TThreadVarEntry;
  PPThreadVarEntry = ^PThreadVarEntry;
  TThreadVarEntry = record
    Descriptor: PThreadVarDescriptor;
    Size, Alignment: SizeUInt;
  end;
  PThreadVarTables = ^TThreadVarTables;
  TThreadVarTables = record
    Count: SizeUInt;
    Tables: array[0..65534] of PPThreadVarEntry;
  end;
  TThreadVarOwner = record
    Tables: PThreadVarTables;
    Index, Size, Alignment: SizeUInt;
    MainBlock: Pointer; { debugger view of the main context, never separate storage }
  end;
  PThreadVarBlock = ^TThreadVarBlock;
  TThreadVarBlock = record
    Raw, Data: Pointer;
    Allocated, Size: SizeUInt;
  end;
  PThreadVarBlocks = ^TThreadVarBlocks;
  TThreadVarBlocks = array[0..(MaxInt div SizeOf(TThreadVarBlock))-1] of TThreadVarBlock;
  PThreadVarContext = ^TThreadVarContext;
  TThreadVarContext = record
    Blocks: PThreadVarBlocks;
    Capacity: SizeUInt;
    Resolving: Boolean;
  end;

var
  MainThreadVarContext: TThreadVarContext;
  NextThreadVarIndex: SizeUInt;
{$ifndef FPC_HAS_INDIRECT_ENTRY_INFORMATION}
  ThreadvarTablesTable: TThreadVarTables; external name 'FPC_THREADVARTABLES';
{$endif}

procedure ThreadVarFatal;
begin
  { A bootstrap failure cannot allocate an exception or re-enter threadvars. }
{$ifdef windows}
  ExitProcess(226);
{$else}
  FpExit(226);
{$endif}
end;

{$if defined(linux) and not defined(FPC_USE_LIBC)}
{ The ordinary syscall wrappers write Pascal errno on failure. These allocation
  calls must also work before the block containing errno has been allocated. }
{$ifdef cpux86_64}
function ThreadVarMMap(Size: SizeUInt): Pointer; assembler; nostackframe;
asm
  movq Size,%rsi
  xorq %rdi,%rdi
  movq $3,%rdx
  movq $0x22,%r10
  movq $-1,%r8
  xorq %r9,%r9
  movq $syscall_nr_mmap,%rax
  syscall
end;
{$endif}
{$ifdef cpuaarch64}
function ThreadVarMMap(Size: SizeUInt): Pointer; assembler; nostackframe;
asm
  mov x1,x0
  mov x0,#0
  mov x2,#3
  mov x3,#0x22
  mov x4,#-1
  mov x5,#0
  mov x8,#syscall_nr_mmap
  svc #0
end;
{$endif}
{$ifdef cpui386}
function ThreadVarRawMMap(Args: Pointer): Pointer; assembler; nostackframe;
asm
  pushl %ebx
  movl Args,%ebx
  movl $syscall_nr_mmap,%eax
  int $0x80
  popl %ebx
end;
function ThreadVarMMap(Size: SizeUInt): Pointer;
var Args: array[0..5] of SizeUInt;
begin
  Args[0]:=0; Args[1]:=Size; Args[2]:=3;
  Args[3]:=$22; Args[4]:=High(SizeUInt); Args[5]:=0;
  Result:=ThreadVarRawMMap(@Args);
end;
{$endif}
{$endif}

function ThreadVarAlloc(Size: SizeUInt): Pointer;
begin
{$ifdef windows}
  Result:=HeapAlloc(GetProcessHeap,0,Size);
{$else}
{$if defined(linux) and not defined(FPC_USE_LIBC)}
  Result:=ThreadVarMMap(Size);
  if PtrUInt(Result)>=PtrUInt(-4095) then Result:=nil;
{$else}
  Result:=Fpmmap(nil,Size,3,MAP_PRIVATE+MAP_ANONYMOUS,-1,0);
  if Result=Pointer(-1) then Result:=nil;
{$endif}
{$endif}
  if Result=nil then ThreadVarFatal;
  FillChar(Result^,Size,0);
end;

procedure ThreadVarFree(P: Pointer; Size: SizeUInt);
begin
  if P=nil then Exit;
{$ifdef windows}
  HeapFree(GetProcessHeap,0,P);
{$else}
  Fpmunmap(P,Size);
{$endif}
end;

function CurrentThreadVarContext: PThreadVarContext;
begin
  if Assigned(ThreadVarContextProc) then
    Result:=ThreadVarContextProc()
  else
    Result:=@MainThreadVarContext;
end;

procedure RegisterThreadVarOwner(Owner: PThreadVarOwner);
var I, A, N: SizeUInt; Entry: PThreadVarEntry;
begin
  if Owner^.Index<>0 then Exit;
  { Registration is performed on the startup/lifecycle thread before publishing
    an image. Existing thread managers need no new synchronization protocol. }
  if IsMultiThread then ThreadVarFatal;
  N:=0; Owner^.Alignment:=SizeOf(Pointer);
  for I:=0 to Owner^.Tables^.Count-1 do
    begin
      Entry:=Owner^.Tables^.Tables[I]^;
      while Entry^.Descriptor<>nil do
        begin
          A:=Entry^.Alignment;
          if A<SizeOf(Pointer) then A:=SizeOf(Pointer);
          if A>Owner^.Alignment then Owner^.Alignment:=A;
          if (A and (A-1))<>0 then ThreadVarFatal;
          if N>High(SizeUInt)-A then ThreadVarFatal;
          N:=(N+A-1) and not(A-1);
          Entry^.Descriptor^.Offset:=N;
          if Entry^.Size>High(SizeUInt)-N then ThreadVarFatal;
          Inc(N,Entry^.Size);
          Inc(Entry);
        end;
    end;
  Owner^.Size:=N;
  if NextThreadVarIndex=High(SizeUInt)-1 then ThreadVarFatal;
  Inc(NextThreadVarIndex);
  Owner^.Index:=NextThreadVarIndex;
end;

procedure RegisterThreadVarTables(Tables: Pointer);
var T: PThreadVarTables; I: SizeUInt; Entry: PThreadVarEntry;
begin
  T:=Tables;
  if (T=nil) or (T^.Count=0) then Exit;
  for I:=0 to T^.Count-1 do
    begin
      Entry:=T^.Tables[I]^;
      if Entry^.Descriptor<>nil then RegisterThreadVarOwner(Entry^.Descriptor^.Owner);
    end;
end;

function AllocateThreadVarContext: Pointer;
begin
  Result:=ThreadVarAlloc(SizeOf(TThreadVarContext));
end;

procedure ReleaseThreadVarContext(Context: Pointer);
var C: PThreadVarContext; I: SizeUInt;
begin
  C:=Context;
  if C=nil then Exit;
  if C^.Capacity<>0 then
    for I:=0 to C^.Capacity-1 do
      ThreadVarFree(C^.Blocks^[I].Raw,C^.Blocks^[I].Allocated);
  ThreadVarFree(C^.Blocks,C^.Capacity*SizeOf(TThreadVarBlock));
  if C=@MainThreadVarContext then FillChar(C^,SizeOf(C^),0)
  else ThreadVarFree(C,SizeOf(C^));
end;

function fpc_threadvar_addr(Descriptor: Pointer): Pointer; compilerproc;
var D: PThreadVarDescriptor; Owner: PThreadVarOwner; C: PThreadVarContext;
    Blocks: PThreadVarBlocks; Capacity: SizeUInt; B: PThreadVarBlock;
begin
  D:=Descriptor; Owner:=D^.Owner;
  if Owner^.Index=0 then RegisterThreadVarOwner(Owner);
  if Owner^.Index=High(SizeUInt) then ThreadVarFatal;
  C:=CurrentThreadVarContext;
  if C^.Resolving then ThreadVarFatal;
  if Owner^.Index>=C^.Capacity then
    begin
      C^.Resolving:=true;
      if Owner^.Index>(High(SizeUInt) div SizeOf(TThreadVarBlock))-16 then ThreadVarFatal;
      Capacity:=Owner^.Index+16;
      Blocks:=ThreadVarAlloc(Capacity*SizeOf(TThreadVarBlock));
      if C^.Capacity<>0 then Move(C^.Blocks^,Blocks^,C^.Capacity*SizeOf(TThreadVarBlock));
      ThreadVarFree(C^.Blocks,C^.Capacity*SizeOf(TThreadVarBlock));
      C^.Blocks:=Blocks; C^.Capacity:=Capacity;
      C^.Resolving:=false;
    end;
  B:=@C^.Blocks^[Owner^.Index];
  if B^.Data=nil then
    begin
      C^.Resolving:=true;
      if Owner^.Size>High(SizeUInt)-Owner^.Alignment then ThreadVarFatal;
      B^.Allocated:=Owner^.Size+Owner^.Alignment;
      B^.Raw:=ThreadVarAlloc(B^.Allocated);
      B^.Data:=Pointer((PtrUInt(B^.Raw)+Owner^.Alignment-1) and not(Owner^.Alignment-1));
      B^.Size:=Owner^.Size;
      C^.Resolving:=false;
      if C=@MainThreadVarContext then Owner^.MainBlock:=B^.Data;
    end;
  Result:=PByte(B^.Data)+D^.Offset;
end;

procedure ReleaseThreadVarTables(Tables: Pointer);
var T: PThreadVarTables; I: SizeUInt; Entry: PThreadVarEntry;
    Owner: PThreadVarOwner; C: PThreadVarContext; B: PThreadVarBlock;
begin
  T:=Tables;
  if (T=nil) or (T^.Count=0) then Exit;
  C:=CurrentThreadVarContext;
  for I:=0 to T^.Count-1 do
    begin
      Entry:=T^.Tables[I]^;
      if Entry^.Descriptor=nil then Continue;
      Owner:=Entry^.Descriptor^.Owner;
      if (Owner^.Index=0) or (Owner^.Index=High(SizeUInt)) then Continue;
      if IsMultiThread then ThreadVarFatal;
      if Owner^.Index<C^.Capacity then
        begin
          B:=@C^.Blocks^[Owner^.Index];
          ThreadVarFree(B^.Raw,B^.Allocated);
          FillChar(B^,SizeOf(B^),0);
        end;
      { A separate native loader reference may keep the image mapped. The next
        managed activation still needs a fresh identity and zeroed storage. }
      Owner^.Index:=0;
      Owner^.MainBlock:=nil;
    end;
end;

function IsThreadVarPointer(P: Pointer): Boolean;
var C: PThreadVarContext; I: SizeUInt; B: PThreadVarBlock;
begin
  Result:=false;
  C:=CurrentThreadVarContext;
  if C^.Capacity=0 then Exit;
  for I:=0 to C^.Capacity-1 do
    begin
      B:=@C^.Blocks^[I];
      if (B^.Data<>nil) and (PtrUInt(P)>=PtrUInt(B^.Data)) and
         (PtrUInt(P)-PtrUInt(B^.Data)<B^.Size) then Exit(true);
    end;
end;

procedure InitThreadVars;
begin
{$ifdef FPC_HAS_INDIRECT_ENTRY_INFORMATION}
  RegisterThreadVarTables(EntryInformation.ThreadvarTablesTable);
{$else}
  RegisterThreadVarTables(@ThreadvarTablesTable);
{$endif}
  { Adopt the existing context. No variable address changes here. }
  CurrentTM.SetThreadVarContext(@MainThreadVarContext);
  ThreadVarContextProc:=CurrentTM.GetThreadVarContext;
{$if defined(FPC_HAS_FEATURE_HEAP) and not defined(HAS_MEMORYMANAGER)}
  RelocateHeap;
{$endif}
end;
