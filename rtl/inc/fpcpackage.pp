unit FPCPackage;

{$mode objfpc}{$H+}

{ Experimental package lifecycle. All calls are synchronous. The caller owns
  image mapping and must keep every registered descriptor mapped. }
interface

uses SysUtils;

const
  FPCPackageMagic = $4e58504b;
  FPCPackageVersion = 2;
  psUnregistered = 0;
  psChecking = 1;
  psRegistered = 2;
  psInitializing = 3;
  psActive = 4;
  psFinalized = 5;
  psFailed = 6;

type
  PPackageDescriptor = ^TPackageDescriptor;
  PPPackageDescriptor = ^PPackageDescriptor;
  PPackageContext = ^TPackageContext;
  TPackageContext = record
    Descriptor: PPackageDescriptor;
    State, InitCount, ModuleHandle: SizeUInt;
    PreviousActive, NextRegistered: PPackageContext;
  end;
  TPackageUnitNames = array[0..65534] of PShortString;
  PPackageUnitNames = ^TPackageUnitNames;
  { Each entry points to a relocation slot containing a descriptor: PE's import
    address table or a compiler-emitted local slot on ELF. }
  TPackageDependencies = array[0..65534] of PPPackageDescriptor;
  PPackageDependencies = ^TPackageDependencies;
  TPackageDescriptor = record
    Magic, Version, Size, CompilerIdentity, TargetIdentity, RTLIdentity: SizeUInt;
    Name: PShortString;
    UnitCount: SizeUInt;
    UnitNames: PPackageUnitNames;
    DependencyCount: SizeUInt;
    Dependencies: PPackageDependencies;
    InitFinalTable, ThreadvarTable, ResourceStringTable: Pointer;
    WideInitTable, ResStrInitTable: Pointer;
    Context: PPackageContext;
    ModuleHandle: PSizeUInt;
    SDKIdentity, BuildIdentity: PShortString;
    DependencyIdentities: PPackageUnitNames;
  end;
  EPackageError = SysUtils.EPackageError;

procedure RegisterPackage(Descriptor: PPackageDescriptor);
procedure InitializePackage(Descriptor: PPackageDescriptor);
procedure FinalizePackages;
procedure PreparePackageStartup(Descriptor: PPackageDescriptor);

implementation

{$if defined(win64) or (defined(linux) and defined(cpux86_64))}
uses
{$ifdef linux}
  DynLibs,
{$endif}
  Classes, TypInfo
{$ifdef win64}
  , Windows
{$else}
  , dl
{$endif}
  ;
{$endif}

type
  TUnitLifecycle = record
    Init, Fini: TProcedure;
    UnitName: PShortString;
  end;
  PUnitLifecycleTable = ^TUnitLifecycleTable;
  TUnitLifecycleTable = record
    Count, UnusedLegacyCount: SizeUInt;
    Units: array[0..65534] of TUnitLifecycle;
  end;
  PManagedInit = ^TManagedInit;
  TManagedInit = record
    Addr: Pointer;
    Data: Pointer;
  end;
  PManagedTable = ^TManagedTable;
  TManagedTable = record
    Count: SizeInt;
    Entries: array[0..65534] of PManagedInit;
  end;

var
  Registered, Active: PPackageContext;
  Startup: PPackageDescriptor;
  StartupThreadvars, StartupResources: Pointer;
  LifecycleBusy, ShuttingDown: Boolean;

{$if defined(linux) and defined(cpux86_64)}
function NativeModuleFromAddress(Address: Pointer; Retain: Boolean): HMODULE;
var Info: dl_info; Handle: Pointer;
begin
  Result:=0;
  if Address=Startup then Handle:=dlopen(nil,RTLD_NOW)
  else
    begin
      FillChar(Info,SizeOf(Info),0);
      if (dladdr(Address,@Info)=0) or (Info.dli_fname=nil) then Exit;
      Handle:=dlopen(Info.dli_fname,RTLD_NOW or RTLD_NOLOAD);
    end;
  Result:=HMODULE(Handle);
  if (Handle<>nil) and not Retain then dlclose(Handle);
end;
{$endif}

procedure ManagedTables(Descriptor: PPackageDescriptor; Initialize: Boolean);
var
  Table: PManagedTable;
  Entry: PManagedInit;
  I: SizeInt;
begin
  Table:=Descriptor^.WideInitTable;
  if Table<>nil then
    for I:=0 to Table^.Count-1 do
      begin
        Entry:=Table^.Entries[I];
        while Entry^.Addr<>nil do
          begin
            if Initialize then
              PWideString(Entry^.Addr)^:=WideString(Entry^.Data)
            else
              PWideString(Entry^.Addr)^:='';
            Inc(Entry);
          end;
      end;
  Table:=Descriptor^.ResStrInitTable;
  if Table<>nil then
    for I:=0 to Table^.Count-1 do
      begin
        Entry:=Table^.Entries[I];
        while Entry^.Addr<>nil do
          begin
            if Initialize then
              PAnsiString(Entry^.Addr)^:=PResourceStringRecord(Entry^.Data)^.CurrentValue
            else
              PAnsiString(Entry^.Addr)^:='';
            Inc(Entry);
          end;
      end;
end;

procedure RegisterPackage(Descriptor: PPackageDescriptor);
var
  Context, Other: PPackageContext;
  I, J: SizeInt;
begin
  if (Descriptor=nil) or (Descriptor^.Magic<>FPCPackageMagic) or
     (Descriptor^.Version<>FPCPackageVersion) or
     (Descriptor^.Size<>SizeOf(TPackageDescriptor)) then
    raise EPackageError.Create('Unsupported package descriptor');
  if (Descriptor^.Name=nil) or (Descriptor^.Context=nil) or
     (Descriptor^.InitFinalTable=nil) or (Descriptor^.ModuleHandle=nil) or
     (Descriptor^.UnitCount>65535) or (Descriptor^.DependencyCount>65535) or
     ((Descriptor^.UnitCount<>0) and (Descriptor^.UnitNames=nil)) or
     ((Descriptor^.DependencyCount<>0) and (Descriptor^.Dependencies=nil)) then
    raise EPackageError.Create('Incomplete package descriptor');
  Context:=Descriptor^.Context;
  if Context^.State=psChecking then
    raise EPackageError.Create('Package dependency cycle: '+Descriptor^.Name^);
  if Context^.State<>psUnregistered then
    begin
      if Context^.Descriptor<>Descriptor then
        raise EPackageError.Create('Package context belongs to another image');
      Exit;
    end;
  for I:=0 to SizeInt(Descriptor^.UnitCount)-1 do
    begin
      if Descriptor^.UnitNames^[I]=nil then
        raise EPackageError.Create('Missing package unit name');
      for J:=0 to I-1 do
        if Descriptor^.UnitNames^[I]^=Descriptor^.UnitNames^[J]^ then
          raise EPackageError.Create('Repeated package unit name');
    end;
  if PUnitLifecycleTable(Descriptor^.InitFinalTable)^.Count>65535 then
    raise EPackageError.Create('Invalid package lifecycle table');
  Context^.Descriptor:=Descriptor;
  Context^.State:=psChecking;
  try
    for I:=0 to SizeInt(Descriptor^.DependencyCount)-1 do
      begin
        if Descriptor^.Dependencies^[I]=nil then
          raise EPackageError.Create('Missing package dependency');
        RegisterPackage(Descriptor^.Dependencies^[I]^);
        if (Descriptor^.DependencyIdentities<>nil) and
           (Descriptor^.Dependencies^[I]^^.BuildIdentity<>nil) and
           ((Descriptor^.DependencyIdentities^[I]=nil) or
            (Descriptor^.DependencyIdentities^[I]^<>Descriptor^.Dependencies^[I]^^.BuildIdentity^)) then
          raise EPackageError.Create('Package dependency build differs: '+Descriptor^.Name^);
      end;
    { Dependencies may have registered new owners while this descriptor was
      being checked. Recheck this image against the complete registered set. }
    Other:=Registered;
    while Other<>nil do
      begin
        if (Other^.Descriptor^.CompilerIdentity<>Descriptor^.CompilerIdentity) or
           (Other^.Descriptor^.TargetIdentity<>Descriptor^.TargetIdentity) or
           (Other^.Descriptor^.RTLIdentity<>Descriptor^.RTLIdentity) then
          raise EPackageError.Create('Incompatible package build: '+Descriptor^.Name^);
        if (Other^.Descriptor^.SDKIdentity<>nil) and (Descriptor^.SDKIdentity<>nil) and
           (Other^.Descriptor^.SDKIdentity^<>Descriptor^.SDKIdentity^) then
          raise EPackageError.Create('Incompatible package SDK: '+Descriptor^.Name^);
        if Other^.Descriptor^.Name^=Descriptor^.Name^ then
          raise EPackageError.Create('Duplicate package image: '+Descriptor^.Name^);
        for I:=0 to SizeInt(Descriptor^.UnitCount)-1 do
          for J:=0 to SizeInt(Other^.Descriptor^.UnitCount)-1 do
            if Descriptor^.UnitNames^[I]^=Other^.Descriptor^.UnitNames^[J]^ then
              raise EPackageError.Create('Duplicate package unit: '+Descriptor^.UnitNames^[I]^);
        Other:=Other^.NextRegistered;
      end;
  except
    Context^.State:=psUnregistered;
    Context^.Descriptor:=nil;
    raise;
  end;
{$if defined(linux) and defined(cpux86_64)}
  if Startup<>nil then
    begin
      Descriptor^.ModuleHandle^:=NativeModuleFromAddress(Descriptor,false);
      if Descriptor^.ModuleHandle^=0 then
        begin
          Context^.State:=psUnregistered;
          Context^.Descriptor:=nil;
          raise EPackageError.Create('Cannot identify package image');
        end;
    end;
{$endif}
  Context^.ModuleHandle:=Descriptor^.ModuleHandle^;
  Context^.NextRegistered:=Registered;
  Registered:=Context;
  Context^.State:=psRegistered;
end;

procedure Activate(Descriptor: PPackageDescriptor);
var
  I: SizeInt;
  Context: PPackageContext;
  Table: PUnitLifecycleTable;
  OwnsSystem: Boolean;
begin
  Context:=Descriptor^.Context;
  if Context^.State=psActive then Exit;
  if Context^.State<>psRegistered then
    raise EPackageError.Create('Package cannot be initialized: '+Descriptor^.Name^);
  for I:=0 to SizeInt(Descriptor^.DependencyCount)-1 do
    Activate(Descriptor^.Dependencies^[I]^);
  Context^.PreviousActive:=Active;
  Active:=Context;
  Context^.State:=psInitializing;
  Table:=Descriptor^.InitFinalTable;
  OwnsSystem:=(Table^.Count<>0) and (Table^.Units[0].UnitName<>nil) and
    (UpperCase(Table^.Units[0].UnitName^)='SYSTEM');
  if not OwnsSystem then ManagedTables(Descriptor,true);
  for I:=0 to SizeInt(Table^.Count)-1 do
    begin
      if Assigned(Table^.Units[I].Init) then Table^.Units[I].Init();
      Context^.InitCount:=I+1;
      if OwnsSystem and (I=0) then ManagedTables(Descriptor,true);
    end;
  Context^.State:=psActive;
end;

procedure FinalizeOne(Context: PPackageContext);
var
  Table: PUnitLifecycleTable;
begin
  Table:=Context^.Descriptor^.InitFinalTable;
  while Context^.InitCount<>0 do
    begin
      Dec(Context^.InitCount);
      if Assigned(Table^.Units[Context^.InitCount].Fini) then
        Table^.Units[Context^.InitCount].Fini();
    end;
end;

{$if defined(win64) or (defined(linux) and defined(cpux86_64))}
{$i fpcpackageloader.inc}
{$endif}

procedure InitializePackage(Descriptor: PPackageDescriptor);
var
  Saved, Context: PPackageContext;
begin
  if LifecycleBusy or ShuttingDown then
    raise EPackageError.Create('Nested package lifecycle operation');
  LifecycleBusy:=true;
  try
  RegisterPackage(Descriptor);
  Saved:=Active;
  try
    Activate(Descriptor);
  except
    while Active<>Saved do
      begin
        Context:=Active;
        { Continue rollback even if user finalization raises. The initialization
          exception remains active and is re-raised after cleanup. }
        while Context^.InitCount<>0 do
          try
            FinalizeOne(Context);
          except
          end;
        ManagedTables(Context^.Descriptor,false);
        Active:=Context^.PreviousActive;
        Context^.PreviousActive:=nil;
        Context^.State:=psRegistered;
      end;
    raise;
  end;
  finally
    LifecycleBusy:=false;
  end;
end;

procedure FinalizePackages;
var
  Context: PPackageContext;
begin
  if LifecycleBusy then raise EPackageError.Create('Nested package lifecycle operation');
  ShuttingDown:=true;
  while Active<>nil do
    begin
      Context:=Active;
{$if defined(win64) or (defined(linux) and defined(cpux86_64))}
      BeforePackageFinalization(Context);
{$endif}
      { Keep an interrupted owner on the stack. FinalizeOne advances before each
        callback, so a subsequent shutdown attempt resumes the remaining prefix. }
      FinalizeOne(Context);
      ManagedTables(Context^.Descriptor,false);
{$if defined(win64) or (defined(linux) and defined(cpux86_64))}
      AfterPackageFinalization(Context);
{$endif}
      Active:=Context^.PreviousActive;
      Context^.PreviousActive:=nil;
      Context^.State:=psFinalized;
    end;
  FreeMem(StartupThreadvars); StartupThreadvars:=nil;
  FreeMem(StartupResources); StartupResources:=nil;
{$if defined(win64) or (defined(linux) and defined(cpux86_64))}
  ShutdownPackageManager;
{$endif}
  ShuttingDown:=false;
end;

procedure InitializeStartup;
begin
{$if defined(win64) or (defined(linux) and defined(cpux86_64))}
  StartPackageManager;
{$endif}
  InitializePackage(Startup);
end;

{$if defined(win64) or (defined(linux) and defined(cpux86_64))}
procedure PrepareStartupMetadata(var Info: TEntryInformation);
type
  PTable = ^TTable;
  TTable = record
    Count: SizeUInt;
    Data: array[0..131069] of Pointer;
  end;
var
  Context: PPackageContext;
  Threads, Resources, T, R: PTable;
  ThreadCount, ResourceCount, ThreadIndex, ResourceIndex: SizeUInt;
begin
  RegisterPackage(Startup);
  ThreadCount:=0; ResourceCount:=0;
  Context:=Registered;
  while Context<>nil do
    begin
      T:=Context^.Descriptor^.ThreadvarTable;
      R:=Context^.Descriptor^.ResourceStringTable;
      if T<>nil then Inc(ThreadCount,T^.Count);
      if R<>nil then Inc(ResourceCount,R^.Count);
      Context:=Context^.NextRegistered;
    end;
  GetMem(StartupThreadvars,(ThreadCount+1)*SizeOf(Pointer));
  GetMem(StartupResources,(2*ResourceCount+1)*SizeOf(Pointer));
  Threads:=StartupThreadvars; Threads^.Count:=ThreadCount;
  Resources:=StartupResources; Resources^.Count:=ResourceCount;
  ThreadIndex:=0; ResourceIndex:=0;
  Context:=Registered;
  while Context<>nil do
    begin
      T:=Context^.Descriptor^.ThreadvarTable;
      R:=Context^.Descriptor^.ResourceStringTable;
      if (T<>nil) and (T^.Count<>0) then
        begin
          Move(T^.Data[0],Threads^.Data[ThreadIndex],T^.Count*SizeOf(Pointer));
          Inc(ThreadIndex,T^.Count);
        end;
      if (R<>nil) and (R^.Count<>0) then
        begin
          Move(R^.Data[0],Resources^.Data[ResourceIndex],R^.Count*2*SizeOf(Pointer));
          Inc(ResourceIndex,R^.Count*2);
        end;
      Context:=Context^.NextRegistered;
    end;
  Info.ThreadvarTablesTable:=Threads;
  Info.ResourceStringTables:=Resources;
end;
{$endif}

procedure PreparePackageStartup(Descriptor: PPackageDescriptor);
begin
  if Startup<>nil then
    raise EPackageError.Create('Package startup already configured');
  Startup:=Descriptor;
{$if defined(win64) or (defined(linux) and defined(cpux86_64))}
  PackagePrepareProc:=@PrepareStartupMetadata;
  PackageInitializeProc:=@InitializeStartup;
  PackageFinalizeProc:=@FinalizePackages;
  PackageLoadProc:=@LoadRuntimePackage;
  PackageUnloadProc:=@UnloadRuntimePackage;
  PackageCleanupProc:=@ManagePackageCleanup;
{$ifdef linux}
  PackageAddressProc:=@ManagedModuleFromAddress;
{$endif}
{$else}
  raise EPackageError.Create('Package startup requires a supported package target');
{$endif}
end;

end.
