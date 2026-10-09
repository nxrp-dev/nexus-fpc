{ Shared-RTL Win64 package manager. All mutations occur synchronously on the
  application thread; callbacks may not reenter load/unload. Native references
  are independent of explicit API references and package dependency edges. }
type
  PLoadedPackage = ^TLoadedPackage;
  PCleanup = ^TCleanup;
  TCleanup = record
    Next: PCleanup;
    Callback: TProcedure;
  end;
  TLoadedPackage = record
    Next: PLoadedPackage;
    Context: PPackageContext;
    ExplicitRefs, DependencyRefs: SizeUInt;
    Pinned, Failed, NativeHeld, Cleaning: Boolean;
    Module: TLibModule;
    Cleanups: PCleanup;
  end;
  PPointerTable = ^TPointerTable;
  TPointerTable = record
    Count: SizeUInt;
    Data: array[0..131069] of Pointer;
  end;
  PResourceRangeTable = ^TResourceRangeTable;
  TResourceRangeTable = record
    Count: SizeUInt;
    Data: array[0..65534] of record First, Last: ^PResourceStringRecord; end;
  end;
var
  LoadedPackages: PLoadedPackage;
  ManagerReady: Boolean;
  DynamicResources, DynamicResRefs: Pointer;
  AllResourceTables: Pointer; external name '_FPC_ResourceStringTables';
  AllResourceRefs: Pointer; external name '_FPC_ResStrInitTables';

function RetainNativeModule(Flags: DWord; Address: Pointer; var Module: HMODULE): LongBool;
  stdcall; external 'kernel32' name 'GetModuleHandleExW';

function FindLoaded(Context: PPackageContext): PLoadedPackage;
begin
  Result:=LoadedPackages;
  while (Result<>nil) and (Result^.Context<>Context) do Result:=Result^.Next;
end;

function FindHandle(Module: HMODULE): PLoadedPackage;
begin
  Result:=LoadedPackages;
  while (Result<>nil) and (Result^.Module.Instance<>Module) do Result:=Result^.Next;
end;

function HasSystem(Descriptor: PPackageDescriptor): Boolean;
var I: SizeInt;
begin
  for I:=0 to SizeInt(Descriptor^.UnitCount)-1 do
    if Descriptor^.UnitNames^[I]^='SYSTEM' then Exit(true);
  Result:=false;
end;

procedure RefreshResourceTables(First: PPackageContext; Skip: PPackageContext = nil);
var C: PPackageContext; R,S: PPointerTable;
    RC,SC,RI,SI: SizeUInt; NewResources,NewRefs: Pointer;
begin
  RC:=0; SC:=0; C:=First;
  while C<>nil do
    begin
      if C=Skip then begin C:=C^.NextRegistered; Continue; end;
      R:=C^.Descriptor^.ResourceStringTable; S:=C^.Descriptor^.ResStrInitTable;
      if R<>nil then Inc(RC,R^.Count);
      if S<>nil then Inc(SC,S^.Count);
      C:=C^.NextRegistered;
    end;
  GetMem(NewResources,(1+2*RC)*SizeOf(Pointer));
  try GetMem(NewRefs,(1+SC)*SizeOf(Pointer));
  except FreeMem(NewResources); raise; end;
  PPointerTable(NewResources)^.Count:=RC; PPointerTable(NewRefs)^.Count:=SC;
  RI:=0; SI:=0; C:=First;
  while C<>nil do
    begin
      if C=Skip then begin C:=C^.NextRegistered; Continue; end;
      R:=C^.Descriptor^.ResourceStringTable; S:=C^.Descriptor^.ResStrInitTable;
      if (R<>nil) and (R^.Count<>0) then
        begin
          Move(R^.Data[0],PPointerTable(NewResources)^.Data[RI],2*R^.Count*SizeOf(Pointer));
          Inc(RI,2*R^.Count);
        end;
      if (S<>nil) and (S^.Count<>0) then
        begin
          Move(S^.Data[0],PPointerTable(NewRefs)^.Data[SI],S^.Count*SizeOf(Pointer));
          Inc(SI,S^.Count);
        end;
      C:=C^.NextRegistered;
    end;
  AllResourceTables:=NewResources; AllResourceRefs:=NewRefs;
  FreeMem(DynamicResources); FreeMem(DynamicResRefs);
  DynamicResources:=NewResources; DynamicResRefs:=NewRefs;
end;

procedure ClearImageResources(Descriptor: PPackageDescriptor);
var Table: PResourceRangeTable; I: SizeInt; Entry: PResourceStringRecord;
begin
  Table:=Descriptor^.ResourceStringTable;
  if Table=nil then Exit;
  for I:=0 to SizeInt(Table^.Count)-1 do
    begin
      Entry:=Table^.Data[I].First^;
      Inc(Entry); { First record is the unit name. }
      while Entry<Table^.Data[I].Last^ do
        begin Entry^.CurrentValue:=''; Inc(Entry); end;
    end;
end;

procedure RemoveRegistrations(P: PLoadedPackage);
begin
  UnRegisterModuleClasses(P^.Module.Instance);
  UnregisterModuleTypeInfo(P^.Module.Instance);
  ClearImageResources(P^.Context^.Descriptor);
end;

procedure RunCleanups(P: PLoadedPackage; var Failure: string);
var C: PCleanup; Callback: TProcedure;
begin
  while P^.Cleanups<>nil do
    begin
      C:=P^.Cleanups; P^.Cleanups:=C^.Next;
      Callback:=C^.Callback; Dispose(C);
      try Callback();
      except on E: Exception do
        begin
          if Failure<>'' then Failure:=Failure+'; ';
          Failure:=Failure+E.ClassName+': '+E.Message;
        end;
        else Failure:=Failure+'; non-Exception object raised during package cleanup';
      end;
    end;
end;

procedure ManagePackageCleanup(Module: HMODULE; Callback: TProcedure; Add: Boolean);
var P: PLoadedPackage; C: PCleanup; Link: ^PCleanup;
begin
  P:=FindHandle(Module);
  if (P=nil) or P^.Failed or not Assigned(Callback) then
    raise EPackageError.Create('Invalid package cleanup owner or callback');
  if Add and (ShuttingDown or P^.Cleaning or (P^.Context^.State=psFinalized)) then
    raise EPackageError.Create('Package is shutting down');
  Link:=@P^.Cleanups;
  while Link^<>nil do
    begin
      if Pointer(Link^^.Callback)=Pointer(Callback) then
        begin
          if not Add then begin C:=Link^; Link^:=C^.Next; Dispose(C); end;
          Exit;
        end;
      Link:=@Link^^.Next;
    end;
  if Add then
    begin New(C); C^.Callback:=Callback; C^.Next:=P^.Cleanups; P^.Cleanups:=C; end;
end;

procedure AddLoaded(C: PPackageContext; Pinned: Boolean);
var P: PLoadedPackage; Handle: HMODULE;
begin
  New(P); FillChar(P^,SizeOf(P^),0);
  try
    P^.Context:=C; P^.Pinned:=Pinned;
    Handle:=C^.ModuleHandle;
    if not Pinned then
      begin
        if not RetainNativeModule(4,C^.Descriptor,Handle) then
          raise EPackageError.Create('Cannot retain package image');
        P^.NativeHeld:=true;
      end;
    P^.Module.Instance:=Handle; P^.Module.CodeInstance:=Handle;
    P^.Module.DataInstance:=Handle; P^.Module.ResInstance:=Handle;
    P^.Module.Next:=LibModuleList; LibModuleList:=@P^.Module;
    P^.Next:=LoadedPackages; LoadedPackages:=P;
  except Dispose(P); raise; end;
end;

procedure ChangeDependencyRefs(P: PLoadedPackage; Increment: Boolean);
var I: SizeInt; Dependency: PLoadedPackage; D: PPackageDescriptor;
begin
  D:=P^.Context^.Descriptor;
  for I:=0 to SizeInt(D^.DependencyCount)-1 do
    begin
      Dependency:=FindLoaded(D^.Dependencies^[I]^^.Context);
      if Dependency=nil then raise EPackageError.Create('Unmanaged package dependency');
      if Increment then Inc(Dependency^.DependencyRefs)
      else Dec(Dependency^.DependencyRefs);
    end;
end;

procedure StartPackageManager;
var C: PPackageContext; P: PLoadedPackage;
begin
  C:=Registered;
  while C<>nil do begin AddLoaded(C,true); C:=C^.NextRegistered; end;
  P:=LoadedPackages;
  while P<>nil do begin ChangeDependencyRefs(P,true); P:=P^.Next; end;
  RefreshResourceTables(Registered);
  ManagerReady:=true;
end;

procedure UnlinkContext(C: PPackageContext);
var Link: ^PPackageContext;
begin
  Link:=@Registered;
  while (Link^<>nil) and (Link^<>C) do Link:=@Link^^.NextRegistered;
  if Link^=C then Link^:=C^.NextRegistered;
  Link:=@Active;
  while (Link^<>nil) and (Link^<>C) do Link:=@Link^^.PreviousActive;
  if Link^=C then Link^:=C^.PreviousActive;
  C^.NextRegistered:=nil; C^.PreviousActive:=nil;
  C^.State:=psUnregistered; C^.Descriptor:=nil;
end;

procedure DisposeLoaded(P: PLoadedPackage);
var Link: ^PLoadedPackage; ModuleLink: ^PLibModule; C: PCleanup;
begin
  Link:=@LoadedPackages;
  while (Link^<>nil) and (Link^<>P) do Link:=@Link^^.Next;
  if Link^=P then Link^:=P^.Next;
  ModuleLink:=@LibModuleList;
  while (ModuleLink^<>nil) and (ModuleLink^<>@P^.Module) do ModuleLink:=@ModuleLink^^.Next;
  if ModuleLink^=@P^.Module then ModuleLink^:=P^.Module.Next;
  while P^.Cleanups<>nil do begin C:=P^.Cleanups; P^.Cleanups:=C^.Next; Dispose(C); end;
  Dispose(P);
end;

procedure CheckNewOwner(C: PPackageContext);
var D: PPackageDescriptor; T: PPointerTable; I: SizeInt;
begin
  D:=C^.Descriptor;
  if (D^.SDKIdentity=nil) or (D^.SDKIdentity^='') or
     (D^.BuildIdentity=nil) or (D^.BuildIdentity^='') or
     (D^.DependencyIdentities=nil) then
    raise EPackageError.Create('Late loading requires SDK package build identities');
  T:=D^.ThreadvarTable;
  if T<>nil then
    for I:=0 to SizeInt(T^.Count)-1 do
      if (T^.Data[I]<>nil) and (PPointer(T^.Data[I])^<>nil) then
        raise EPackageError.Create('Late-loaded package introduces threadvar storage: '+D^.Name^);
end;

procedure FinalizeManagedOwner(P: PLoadedPackage; var Failure: string);
var C: PPackageContext;
begin
  C:=P^.Context;
  P^.Cleaning:=true;
  RunCleanups(P,Failure);
  while C^.InitCount<>0 do
    try FinalizeOne(C);
    except on E: Exception do
      begin
        if Failure<>'' then Failure:=Failure+'; ';
        Failure:=Failure+E.ClassName+': '+E.Message;
      end;
      else Failure:=Failure+'; non-Exception object raised during package finalization';
    end;
  try
    ManagedTables(C^.Descriptor,false);
    RemoveRegistrations(P);
  except on E: Exception do
    begin
      if Failure<>'' then Failure:=Failure+'; ';
      Failure:=Failure+E.ClassName+': '+E.Message;
    end;
    else Failure:=Failure+'; non-Exception object raised during registry cleanup';
  end;
  C^.State:=psFinalized;
end;

function LoadRuntimePackage(const Name: string): HMODULE;
var Handle: HMODULE; Info: PPPackageDescriptor; D: PPackageDescriptor;
    SavedRegistered,SavedActive,C,Next: PPackageContext;
    P: PLoadedPackage; Filename: UnicodeString; Failure,CleanupFailure: string;
    NewOwners: array of PLoadedPackage; I,OwnerCount: SizeInt; EdgesAdded: SizeInt;
begin
  if LifecycleBusy or ShuttingDown then raise EPackageError.Create('Nested package lifecycle operation');
  if not ManagerReady then raise EPackageError.Create('Package runtime is not ready');
  if (Startup^.SDKIdentity=nil) or (Startup^.SDKIdentity^='') then
    raise EPackageError.Create('Late loading requires an SDK-built host');
  if Name='' then raise EPackageError.Create('Empty package filename');
  { A bare name is relative to the EXE, never to the process current directory. }
  if ExtractFilePath(Name)='' then Filename:=UnicodeString(ExtractFilePath(ParamStr(0))+Name)
  else Filename:=UnicodeString(ExpandFileName(Name));
  LifecycleBusy:=true; Handle:=0; EdgesAdded:=0;
  SavedRegistered:=Registered; SavedActive:=Active;
  try
    try
      Handle:=Windows.LoadLibraryExW(PWideChar(Filename),0,$100 or $200 or $800);
      if Handle=0 then raise EPackageError.CreateFmt('Cannot load package %s (Windows error %d)',[Name,Windows.GetLastError]);
      Info:=PPPackageDescriptor(Windows.GetProcAddress(Handle,'FPC_PACKAGE_INFO'));
      if Info=nil then raise EPackageError.Create('Missing package descriptor: '+Name);
      D:=Info^;
      RegisterPackage(D);
      C:=Registered; OwnerCount:=0;
      while C<>SavedRegistered do
        begin CheckNewOwner(C); Inc(OwnerCount); C:=C^.NextRegistered; end;
      { Allocate bookkeeping before taking native holds. }
      SetLength(NewOwners,OwnerCount);
      I:=0;
      C:=Registered;
      while C<>SavedRegistered do
        begin
          AddLoaded(C,false);
          NewOwners[I]:=FindLoaded(C); Inc(I);
          C:=C^.NextRegistered;
        end;
      for I:=0 to High(NewOwners) do
        begin ChangeDependencyRefs(NewOwners[I],true); Inc(EdgesAdded); end;
      P:=FindLoaded(D^.Context);
      if (P=nil) or P^.Failed then raise EPackageError.Create('Package image is unavailable after a lifecycle failure');
      RefreshResourceTables(Registered);
      Activate(D);
      Inc(P^.ExplicitRefs);
      Result:=P^.Module.Instance;
    except
      on E: Exception do Failure:=E.ClassName+': '+E.Message;
      else Failure:='Non-Exception object raised during package loading';
    end;
    { The original exception has been destroyed while all images are mapped. }
    if Failure<>'' then
      begin
        while Active<>SavedActive do
          begin
            C:=Active; P:=FindLoaded(C);
            if P<>nil then FinalizeManagedOwner(P,CleanupFailure);
            Active:=C^.PreviousActive; C^.PreviousActive:=nil;
          end;
        { Also clean registrations from the failing initialization unit. }
        for I:=0 to High(NewOwners) do
          if (NewOwners[I]<>nil) and (NewOwners[I]^.Context^.State<>psFinalized) then
            FinalizeManagedOwner(NewOwners[I],CleanupFailure);
        if CleanupFailure='' then
          try RefreshResourceTables(SavedRegistered);
          except
            on E: Exception do CleanupFailure:=E.ClassName+': '+E.Message;
            else CleanupFailure:='Cannot restore resource tables';
          end;
        if CleanupFailure<>'' then
          begin
            for I:=0 to High(NewOwners) do
              if NewOwners[I]<>nil then
                begin NewOwners[I]^.Failed:=true; NewOwners[I]^.Context^.State:=psFailed; end;
            C:=Registered;
            while C<>SavedRegistered do
              begin C^.State:=psFailed; C:=C^.NextRegistered; end;
            { Keep the initial loader reference too: it retains any dependency
              for which bookkeeping allocation failed. }
            Handle:=0;
            Failure:=Failure+'; cleanup failed, images retained: '+CleanupFailure;
          end
        else
          begin
            for I:=0 to EdgesAdded-1 do ChangeDependencyRefs(NewOwners[I],false);
            C:=Registered;
            while C<>SavedRegistered do begin Next:=C^.NextRegistered; UnlinkContext(C); C:=Next; end;
            for I:=0 to High(NewOwners) do
              begin
                P:=NewOwners[I];
                if P=nil then Continue;
                if P^.NativeHeld then Windows.FreeLibrary(P^.Module.Instance);
                DisposeLoaded(P);
              end;
          end;
        raise EPackageError.Create(Failure);
      end;
  finally
    if Handle<>0 then Windows.FreeLibrary(Handle);
    LifecycleBusy:=false;
  end;
end;

procedure ReleaseUnused(P: PLoadedPackage);
var Dependencies: array of PLoadedPackage; D: PPackageDescriptor;
    I: SizeInt; Failure: string; Handle: HMODULE;
begin
  if P^.Pinned or P^.Failed or (P^.ExplicitRefs<>0) or (P^.DependencyRefs<>0) then Exit;
  D:=P^.Context^.Descriptor;
  SetLength(Dependencies,D^.DependencyCount);
  for I:=0 to High(Dependencies) do Dependencies[I]:=FindLoaded(D^.Dependencies^[I]^^.Context);
  FinalizeManagedOwner(P,Failure);
  if Failure<>'' then
    begin
      P^.Failed:=true; P^.Context^.State:=psFailed;
      raise EPackageError.Create('Package finalization failed; image retained: '+Failure);
    end;
  try RefreshResourceTables(Registered,P^.Context);
  except
    P^.Failed:=true; P^.Context^.State:=psFailed;
    raise;
  end;
  UnlinkContext(P^.Context);
  Handle:=P^.Module.Instance;
  if not Windows.FreeLibrary(Handle) then
    begin
      P^.Failed:=true;
      P^.Context^.Descriptor:=D; P^.Context^.State:=psFailed;
      P^.Context^.NextRegistered:=Registered; Registered:=P^.Context;
      raise EPackageError.Create('Cannot release native package image');
    end;
  DisposeLoaded(P);
  { Keep each edge until its turn: another branch can share that dependency. }
  for I:=High(Dependencies) downto 0 do
    begin
      Dec(Dependencies[I]^.DependencyRefs);
      try ReleaseUnused(Dependencies[I]);
      except on E: Exception do
        begin
          if Failure<>'' then Failure:=Failure+'; ';
          Failure:=Failure+E.Message;
        end;
      end;
    end;
  if Failure<>'' then raise EPackageError.Create(Failure);
end;

procedure UnloadRuntimePackage(Module: HMODULE);
var P: PLoadedPackage;
begin
  if LifecycleBusy or ShuttingDown then raise EPackageError.Create('Nested package lifecycle operation');
  P:=FindHandle(Module);
  if (P=nil) or P^.Failed or (P^.ExplicitRefs=0) then
    raise EPackageError.Create('UnloadPackage has no matching successful LoadPackage');
  LifecycleBusy:=true;
  try Dec(P^.ExplicitRefs); ReleaseUnused(P);
  finally LifecycleBusy:=false; end;
end;

procedure BeforePackageFinalization(C: PPackageContext);
var P: PLoadedPackage; Failure: string;
begin
  P:=FindLoaded(C);
  if P=nil then Exit;
  P^.Cleaning:=true;
  RunCleanups(P,Failure);
  if Failure<>'' then raise EPackageError.Create(Failure);
end;

procedure AfterPackageFinalization(C: PPackageContext);
var P: PLoadedPackage;
begin
  P:=FindLoaded(C);
  if (P<>nil) and not HasSystem(C^.Descriptor) then RemoveRegistrations(P);
end;

procedure ShutdownPackageManager;
begin
  ManagerReady:=false;
  { Native references deliberately survive process shutdown, after finalization.
    In particular no return address may be unmapped with the shared RTL. }
  while LoadedPackages<>nil do DisposeLoaded(LoadedPackages);
  FreeMem(DynamicResources); DynamicResources:=nil;
  FreeMem(DynamicResRefs); DynamicResRefs:=nil;
end;
