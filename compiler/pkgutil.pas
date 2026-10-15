{
    Copyright (c) 2013-2016 by Free Pascal Development Team

    This unit implements basic parts of the package system

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

 ****************************************************************************
}

unit pkgutil;

{$i fpcdefs.inc}

interface

  uses
    FModule,FPkg,Link,CStreams,CClasses;

  procedure CreateImportLibFromExternals;
  Function RewritePPU(const PPUFn:String;OutStream:TCStream):Boolean;
  procedure Export_Unit(U:TModule);
  procedure Load_Packages;
  procedure Add_Package(const Name:string;IgnoreDuplicates:Boolean;Direct:Boolean);
  procedure Add_Package_Unit_Ref(Package:TPackage);
  procedure Add_Package_Libs(L:TLinker);
  procedure Check_For_Indirect_Package_Usages(Modules:TLinkedList);
  procedure Emit_Package_Descriptor;

implementation

  uses
    SysUtils,
    GlobType,Systems,Version,
    CUtils,
    Globals,Verbose,
    AAsmBase,AAsmData,AAsmCnst,AAsmTai,
    SymType,SymConst,SymSym,SymDef,SymBase,SymTable,
    PSub,PDecSub,
    PPU,EntFile,FPCP,NXArtifactID,
    Export;

  procedure Emit_Package_Descriptor;
    var
      B: TTAITypedConstBuilder;
      D: TDef;
      U: TModule;
      Entry: PPackageEntry;
      I,UnitCount,DepCount: LongInt;
      Name: TSymStr;

    procedure Start;
      begin
        B:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_make_dead_strippable]);
        B.begin_anonymous_record('',8,8,8);
      end;

    procedure Finish(const S: TSymStr; Section: TAsmSectiontype);
      begin
        D:=B.end_anonymous_record;
        CurrentAsmData.AsmLists[al_globals].ConcatList(B.get_final_asmlist(
          CurrentAsmData.DefineAsmSymbol(S,AB_GLOBAL,AT_DATA,D),D,Section,S,8));
        B.Free;
      end;

    procedure Number(N: Int64);
      begin
        B.emit_tai(TAIConst.create_sizeint(N),SizeUIntType);
      end;

    procedure Address(const S: TSymStr);
      begin
        B.emit_tai(TAIConst.CreateName(S,0),VoidPointerType);
      end;

    begin
      { Layout matches rtl/inc/fpcpackage.pas. The experimental targets are
        currently 64 bit; every field occupies one native word. }
      if not (TargetInfo.System in [system_x86_64_win64,system_x86_64_linux]) then Exit;
      Start;
      for I:=1 to 6 do Number(0);
      Finish('FPC_PACKAGE_CONTEXT',sec_data);
      Start;
      Number(0);
      Finish('FPC_PACKAGE_HANDLE',sec_data);
      Start;
      UnitCount:=0;
      U:=TModule(Loaded_Units.First);
      while Assigned(U) do
        begin
          if U.is_unit and not Assigned(U.Package) then
            begin
              B.emit_pooled_shortstring_const_ref(U.ModuleName^);
              Inc(UnitCount);
            end;
          U:=TModule(U.Next);
        end;
      { Retain a valid address even for an empty owned-unit list. }
      if UnitCount=0 then Number(0);
      Finish('FPC_PACKAGE_UNITS',sec_rodata);
      if TargetInfo.System=system_x86_64_linux then
        begin
          { ELF resolves these local slots directly. Keep the descriptor's
            pointer-to-pointer ABI without manufacturing PE import symbols. }
          Start;
          for I:=0 to PackageList.Count-1 do
            begin
              Entry:=PPackageEntry(PackageList[I]);
              if Entry^.Direct then
                Address('FPC_PACKAGE_'+Entry^.Package.PackageName^);
            end;
          Number(0);
          Finish('FPC_PACKAGE_DEPENDENCY_SLOTS',sec_rodata);
        end;
      Start;
      DepCount:=0;
      for I:=0 to PackageList.Count-1 do
        begin
          Entry:=PPackageEntry(PackageList[I]);
          if not Entry^.Direct then Continue;
          Name:='FPC_PACKAGE_'+Entry^.Package.PackageName^;
          if TargetInfo.System=system_x86_64_linux then
            B.emit_tai(TAIConst.CreateName('FPC_PACKAGE_DEPENDENCY_SLOTS',DepCount*8),VoidPointerType)
          else
            begin
              CurrentModule.AddExternalImport(Entry^.Package.PPLFileName,
                Name,Name+suffix_indirect,0,True,False);
              B.emit_tai(TAIConst.create_sym(
                CurrentAsmData.RefAsmSymbol(Name,AT_DATA,True)),VoidPointerType);
            end;
          Inc(DepCount);
        end;
      if DepCount=0 then Number(0);
      Finish('FPC_PACKAGE_DEPENDENCIES',sec_rodata);
      Start;
      for I:=0 to PackageList.Count-1 do
        begin
          Entry:=PPackageEntry(PackageList[I]);
          if Entry^.Direct then
            B.emit_pooled_shortstring_const_ref(Entry^.Package.BuildIdentity);
        end;
      if DepCount=0 then Number(0);
      Finish('FPC_PACKAGE_DEPENDENCY_IDS',sec_rodata);
      Start;
      Number($4e58504b);
      Number(4);
      Number(21*8);
      Number(NexusCompilerIdentity(CurrentPPUVersion,WordVersion,CurrentPPULongVersion));
      Number(Ord(TargetInfo.System));
      Number(find_module_from_symtable(SystemUnit).CRC);
      B.emit_pooled_shortstring_const_ref(CurrentModule.ModuleName^);
      Number(UnitCount);
      Address('FPC_PACKAGE_UNITS');
      Number(DepCount);
      Address('FPC_PACKAGE_DEPENDENCIES');
      Address('INITFINAL');
      Address('FPC_THREADVARTABLES');
      Address('FPC_RESOURCESTRINGTABLES');
      Address('FPC_WIDEINITTABLES');
      Address('FPC_RESSTRINITTABLES');
      Address('FPC_PACKAGE_CONTEXT');
      Address('FPC_PACKAGE_HANDLE');
      B.emit_pooled_shortstring_const_ref(Package_SDK_Identity);
      B.emit_pooled_shortstring_const_ref(Current_Package_Build_Identity);
      Address('FPC_PACKAGE_DEPENDENCY_IDS');
      if CurrentModule.IsPackage then
        Name:='FPC_PACKAGE_'+CurrentModule.ModuleName^
      else
        Name:='FPC_PACKAGE_ROOT';
      Finish(Name,sec_rodata);
      if CurrentModule.IsPackage then
        begin
          Export.ExportName(Name,[eo_name]);
          Start;
          Address(Name);
          Finish('FPC_PACKAGE_INFO',sec_rodata);
          Export.ExportName('FPC_PACKAGE_INFO',[eo_name]);
        end;
    end;

  procedure ProcExport(const S : string);
    var
      HP : TExportedItem;
    begin
      HP:=TExportedItem.Create;
      HP.Name:=StringDup(S);
      HP.Options:=HP.Options+[eo_name];
      ExportLib.ExportProcedure(HP);
    end;


  procedure VarExport(const S : string);
    var
      HP : TExportedItem;
    begin
      HP:=TExportedItem.Create;
      HP.Name:=StringDup(S);
      HP.Options:=HP.Options+[eo_name];
      ExportLib.ExportVar(HP);
    end;


  procedure ExportProcSym(Sym:TProcSym;SymTable:TSymTable);
    var
      I : LongInt;
      PD : TProcDef;
    begin
      for I:=0 to TProcSym(Sym).ProcDefList.Count-1 do
        begin
          PD:=TProcDef(TProcSym(Sym).ProcDefList[I]);
          if not(PD.ProcCallOption in [pocall_internproc]) and
              not (df_generic in PD.DefOptions) and
              ((PD.ProcOptions*[po_external])=[]) and
              (
                (SymTable.SymTableType in [GlobalSymTable,RecordSymTable,ObjectSymTable]) or
                (
                  (SymTable.SymTableType=StaticSymTable) and
                  (
                    ([po_public,po_has_public_name]*PD.ProcOptions<>[]) or
                    (df_has_global_ref in PD.DefOptions)
                  )
                )
              ) then
            begin
              ExportAllProcDefNames(TProcSym(Sym),PD,[eo_name,eo_no_sym_name]);
            end;
        end;
    end;


  procedure ExportAbstractRecordDef(Def:TAbstractRecordDef;SymTable:TSymTable); forward;


  procedure ExportAbstractRecordSymProc(Sym:TObject;Arg:Pointer);
    begin
      case TSym(Sym).Typ of
        TypeSym:
          begin
            case TTypeSym(Sym).TypeDef.Typ of
              ObjectDef,
              RecordDef:
                ExportAbstractRecordDef(TAbstractRecordDef(TTypeSym(Sym).TypeDef),TSymTable(Arg));
              else
                ;
            end;
          end;
        ProcSym:
          begin
            { don't export methods of interfaces }
            if is_interface(TDef(TAbstractRecordSymTable(Arg).DefOwner)) then
              Exit;
            ExportProcSym(TProcSym(Sym),TSymTable(Arg));
          end;
        StaticVarSym:
          begin
            VarExport(TSym(Sym).MangledName);
          end;
        else
          ;
      end;
    end;


  procedure ExportName(const S:TSymStr);
    var
      HP : TExportedItem;
    begin
      HP:=TExportedItem.Create;
      HP.Name:=StringDup(S);
      HP.Options:=HP.Options+[eo_name];
      ExportLib.ExportVar(HP);
    end;


  procedure ExportAbstractRecordDef(Def:TAbstractRecordDef;SymTable:TSymTable);
    begin
      { for cross unit type aliases this might happen }
      if Def.Owner<>SymTable then
        Exit;
      { don't export generics or their nested types }
      if df_generic in Def.DefOptions then
        Exit;
      Def.SymTable.SymList.ForEachCall(@ExportAbstractRecordSymProc,Def.SymTable);
      if Def.Typ=ObjectDef then
        begin
          if (oo_has_vmt in TObjectDef(Def).ObjectOptions) then
            ExportName(TObjectDef(Def).vmt_mangledname);
          if is_interface(Def) then
            begin
              if Assigned(TObjectDef(Def).IIDGUID) then
                ExportName(make_mangledname('IID',Def.Owner,Def.ObjName^));
              ExportName(make_mangledname('IIDSTR',Def.Owner,Def.ObjName^));
            end;
        end;
    end;


  procedure ExportTypeDef(Def:TDef;SymTable:TSymTable;Global:Boolean);
    begin
      if not (Global or is_class(Def)) or
          ([df_internal,df_generic]*Def.DefOptions<>[]) or
          { happens with type renaming declarations ("abc = xyz") }
          (Def.Owner<>SymTable) then
        Exit;
      if ds_rtti_table_written in Def.DefStates then
        ExportName(Def.RTTIMangledName(FullRTTI));
      if (ds_init_table_written in Def.DefStates) and
          Def.NeedsSeparateInitRTTI then
        ExportName(Def.RTTIMangledName(InitRTTI));
      case Def.Typ of
        RecordDef,
        ObjectDef:
          ExportAbstractRecordDef(TAbstractRecordDef(Def),SymTable);
        else
          ;
      end;
    end;


  procedure InsertExport(Sym : TObject;Arg:Pointer);
    var
      IsGlobal,
      PublicOnly : Boolean;
    begin
      PublicOnly:=TSymTable(Arg).SymTableType=StaticSymTable;
      IsGlobal:=TSymTable(Arg).SymTableType=GlobalSymTable;
      case TSym(Sym).Typ of
        { ignore: }
        UnitSym,
        SysSym,
        NamespaceSym,
        PropertySym,
        EnumSym:
          ;
        ConstSym:
          begin
            if TConstSym(Sym).ConstTyp=ConstResourceString then
              VarExport(make_mangledname('RESSTR',TSym(Sym).Owner,TSym(Sym).Name));
          end;
        TypeSym:
          begin
            ExportTypeDef(TTypeSym(Sym).TypeDef,TSymTable(Arg),IsGlobal);
          end;
        ProcSym:
          begin
            ExportProcSym(TProcSym(Sym),TSymTable(Arg));
          end;
        StaticVarSym:
          begin
            if PublicOnly and ([vo_is_public,vo_has_global_ref]*TStaticVarSym(Sym).VarOptions=[]) then
              Exit;
            VarExport(TSym(Sym).MangledName);
          end;
        AbsoluteVarSym:
          ;
        else
          begin
            //writeln('unknown: ',TSym(sym).typ);
            InternalError(2016080501);
          end;
      end;
    end;


  procedure Export_Unit(U: TModule);
    var
      I : LongInt;
      Sym : TAsmSymbol;
    begin
      U.GlobalSymTable.SymList.ForEachCall(@InsertExport,U.GlobalSymTable);
      { check localsymtable for exports too to get public symbols }
      U.LocalSymTable.SymList.ForEachCall(@InsertExport,U.LocalSymTable);

      { Callable names retained for inline implementation helpers must remain
        exported even when a cached unit no longer has their local procsym.
        Public records can contain anonymous managed types with no typesym.
        Their emitted metadata is nevertheless referenced by consumer cleanup
        code, so include the unit's globally visible RTTI/init symbols. }
      for I:=0 to U.PublicAsmSyms.Count-1 do
        begin
          Sym:=TAsmSymbol(U.PublicAsmSyms[I]);
          if (Sym.Bind=AB_GLOBAL) and (Sym.Typ=AT_FUNCTION) then
            ProcExport(Sym.Name)
          else if (Sym.Bind=AB_GLOBAL) and (Sym.Typ=AT_DATA) and
             ((Copy(Sym.Name,1,5)='RTTI_') or (Copy(Sym.Name,1,5)='INIT_')) then
            VarExport(Sym.Name);
        end;

      { create special exports }
      if mf_init in U.ModuleFlags then
        ProcExport(make_mangledname('INIT$',U.GlobalSymTable,''));
      if mf_finalize in U.ModuleFlags then
        ProcExport(make_mangledname('FINALIZE$',U.GlobalSymTable,''));
      if mf_threadvars in U.ModuleFlags then
        VarExport(make_mangledname('THREADVARLIST',U.GlobalSymTable,''));
      if mf_has_resourcestrings in U.ModuleFlags then
        begin
          VarExport(CTAITypedConstBuilder.get_vectorized_dead_strip_section_symbol_start('RESSTR',U.LocalSymTable,[]).Name);
          VarExport(CTAITypedConstBuilder.get_vectorized_dead_strip_section_symbol_end('RESSTR',U.LocalSymTable,[]).Name);
        end;

      if not (TargetInfo.System in systems_indirect_var_imports) then
        for I:=0 to U.PublicAsmSyms.Count-1 do
          begin
            Sym:=TAsmSymbol(U.PublicAsmSyms[I]);
            if Sym.Bind=AB_INDIRECT then
              VarExport(Sym.Name);
          end;
    end;

  Function RewritePPU(const PPUFn:String;OutStream:TCStream):Boolean;
    Var
      MakeStatic : Boolean;
    Var
      Buffer : array[0..$1fff] of Byte;
      InPPU,
      OutPPU : TPPUFile;
      B,
      UntilB : Byte;
      L,M    : LongInt;
      Ext,
      S      : string;
      PPUVersion,PPULongVersion : DWORD;
    begin
      Result:=False;
      MakeStatic:=False;
      InPPU:=TPPUFile.Create(PPUFn);
      if not InPPU.OpenFile then
       begin
         InPPU.Free;
         InPPU := nil;
         Comment(VError,'Could not open : '+PPUFn);
         Exit;
       end;
    { Check the ppufile }
      if not InPPU.CheckPPUId then
       begin
         InPPU.Free;
         InPPU := nil;
         Comment(VError,'Expected NexusFPC NXU unit signature in '+PPUFn+'; rebuild with NexusFPC');
         Exit;
       end;
      PPUVersion:=InPPU.GetVersion;
      if PPUVersion<>CurrentPPUVersion then
       begin
         InPPU.Free;
         InPPU := nil;
         Comment(VError,'Wrong PPU Version '+ToStr(PPUVersion)+' in '+PPUFn);
         Exit;
       end;
    { Already a lib? }
      if (InPPU.Header.Common.Flags and UfInLibrary)<>0 then
       begin
         InPPU.Free;
         InPPU := nil;
         Comment(VError,'PPU is already in a library : '+PPUFn);
         Exit;
       end;
    { We need a static linked unit, but we also accept those without .o file }
      if (InPPU.Header.Common.Flags and (UfStaticLinked or UfNoLink))=0 then
       begin
         InPPU.Free;
         InPPU := nil;
         Comment(VError,'PPU is not static linked : '+PPUFn);
         Exit;
       end;
    { Create the new ppu }
      OutPPU:=TPPUFile.Create(PPUFn);
      OutPPU.CreateStream(OutStream);
    { Create new header, with the new flags }
      OutPPU.Header:=InPPU.Header;
      OutPPU.Header.Common.Flags:=OutPPU.Header.Common.Flags or UfInLibrary;
      if MakeStatic then
       OutPPU.Header.Common.Flags:=OutPPU.Header.Common.Flags or UfStaticLinked
      else
       OutPPU.Header.Common.Flags:=OutPPU.Header.Common.Flags or UfSharedLinked;
    { read until the object files are found }
      UntilB:=IBLinkUnitOFiles;
      repeat
        B:=InPPU.ReadEntry;
        if B in [IBEndInterface,IBEnd] then
         begin
           InPPU.Free;
           InPPU := nil;
           OutPPU.Free;
           OutPPU := nil;
           Comment(VError,'No files to be linked found : '+PPUFn);
           Exit;
         end;
        if B<>UntilB then
         begin
           if B=IBExtraHeader then
             begin
               PPULongVersion:=Cardinal(InPPU.GetLongInt);
               if PPULongVersion<>CurrentPPULongVersion then
                 begin
                   InPPU.Free;
                   OutPPU.Free;
                   Comment(VError,'Wrong NexusFPC PPU Long Version in '+PPUFn);
                   Exit;
                 end;
               OutPPU.PutLongInt(LongInt(PPULongVersion));
             end;
           repeat
             InPPU.GetDataBuf(Buffer,SizeOf(Buffer),L);
             OutPPU.PutData(Buffer,L);
           until L<SizeOf(Buffer);
           OutPPU.WriteEntry(B);
         end;
      until (B=UntilB);
    { we have now reached the section for the files which need to be added,
      now add them to the list }
      case B of
        IBLinkUnitOFiles :
          begin
            { add all o files, and save the entry when not creating a static
              library to keep staticlinking possible }
            while not InPPU.EndOfEntry do
             begin
               S:=InPPU.GetString;
               M:=InPPU.GetLongInt;
               if not MakeStatic then
                begin
                  OutPPU.PutString(S);
                  OutPPU.PutLongInt(M);
                end;
               CurrentModule.LinkOtherOFiles.Add(S,link_always);
             end;
            if not MakeStatic then
             OutPPU.WriteEntry(B);
          end;
    {    iblinkunitstaticlibs :
          begin
            AddToLinkFiles(ExtractLib(inppu.getstring));
            if not inppu.endofentry then
             begin
               repeat
                 inppu.getdatabuf(buffer^,bufsize,l);
                 outppu.putdata(buffer^,l);
               until l<bufsize;
               outppu.writeentry(b);
             end;
           end; }
      end;
    { just add a new entry with the new lib }
      if MakeStatic then
       begin
         OutPPU.PutString('imp'+CurrentModule.RealModuleName^);
         OutPPU.PutLongInt(link_static);
         OutPPU.WriteEntry(IBLinkUnitStaticLibs)
       end
      else
       begin
         OutPPU.PutString('imp'+CurrentModule.RealModuleName^);
         OutPPU.PutLongInt(link_shared);
         OutPPU.WriteEntry(IBLinkUnitSharedLibs);
       end;
    { read all entries until the end and write them also to the new ppu }
      repeat
        B:=InPPU.ReadEntry;
      { don't write ibend, that's written automatically }
        if B<>IBEnd then
         begin
           if B=IBLinkOtherSharedLibs then
             begin
               while not InPPU.EndOfEntry do
                 begin
                   S:=InPPU.GetString;
                   M:=InPPU.GetLongInt;

                   OutPPU.PutString(S);
                   OutPPU.PutLongInt(M);

                   { strip lib prefix }
                   if Copy(S,1,3)='lib' then
                     Delete(S,1,3);
                   Ext:=ExtractFileExt(S);
                   if Ext<>'' then
                     Delete(S,Length(S)-Length(Ext)+1,Length(Ext));

                   CurrentModule.LinkOtherSharedLibs.Add(S,link_always);
                 end;
             end
           else
             repeat
               InPPU.GetDataBuf(Buffer,SizeOf(Buffer),L);
               OutPPU.PutData(Buffer,L);
             until L<SizeOf(Buffer);
           OutPPU.WriteEntry(B);
         end;
      until B=IBEnd;
    { write the last stuff and close }
      OutPPU.Flush;
      OutPPU.WriteHeader;
      OutPPU.Free;
      OutPPU := nil;
      InPPU.Free;
      InPPU := nil;
      Result:=True;
    end;


  procedure Load_Packages;
    var
      Active : TFPList;
      Owners : TFPHashList;
      I,J : LongInt;
      Entry : PPackageEntry;
      Owner : TPackage;
      Name : string;

    procedure LoadPackage(Entry:PPackageEntry);
      var
        I : LongInt;
        Required : PPackageEntry;
        PCP : TPCPPackage;
        Chain : AnsiString;
        BuildingPackage : Boolean;
      begin
        BuildingPackage:=Assigned(CurrentModule) and CurrentModule.IsPackage;
        if (Active.IndexOf(Entry)>=0) or
           (BuildingPackage and (Upper(Entry^.RealPkgName)=CurrentModule.ModuleName^)) then
          begin
            Chain:='';
            if BuildingPackage then
              Chain:=CurrentModule.RealModuleName^+' -> ';
            for I:=0 to Active.Count-1 do
              Chain:=Chain+PPackageEntry(Active[I])^.RealPkgName+' -> ';
            Comment(VFatal,'Circular package dependency: '+Chain+Entry^.RealPkgName);
          end;
        if Assigned(Entry^.Package) then
          Exit;
        Active.Add(Entry);
        try
          Comment(VInfo,'Loading package: '+Entry^.RealPkgName);
          PCP:=TPCPPackage.Create(Entry^.RealPkgName);
          { Give the package list ownership even if loading aborts. }
          Entry^.Package:=PCP;
          PCP.LoadPCP;
          for I:=0 to PCP.RequiredPackages.Count-1 do
            begin
              Add_Package(PCP.RequiredPackages.NameOfIndex(I),True,False);
              Required:=PPackageEntry(PackageList.Find(Upper(PCP.RequiredPackages.NameOfIndex(I))));
              LoadPackage(Required);
              if PShortString(PCP.RequiredIdentities.Find(Upper(PCP.RequiredPackages.NameOfIndex(I))))^<>
                 Required^.Package.BuildIdentity then
                Comment(VFatal,'Package dependency build differs: '+
                  PCP.RealPackageName^+' requires '+Required^.RealPkgName);
              PCP.RequiredPackages[I]:=Required^.Package;
            end;
        finally
          Active.Delete(Active.Count-1);
        end;
      end;

    begin
      if not (tf_supports_packages in TargetInfo.Flags) then
        Exit;
      Active:=TFPList.Create;
      Owners:=TFPHashList.Create;
      try
        I:=0;
        while I<PackageList.Count do
          begin
            LoadPackage(PPackageEntry(PackageList[I]));
            Inc(I);
          end;
        { Check the complete closure before unit lookup can choose a provider. }
        for I:=0 to PackageList.Count-1 do
          begin
            Entry:=PPackageEntry(PackageList[I]);
            for J:=0 to Entry^.Package.ContainedModules.Count-1 do
              begin
                Name:=Upper(Entry^.Package.ContainedModules.NameOfIndex(J));
                Owner:=TPackage(Owners.Find(Name));
                if Assigned(Owner) then
                  Comment(VFatal,'Unit '+Name+' is contained in both packages '+
                    Owner.RealPackageName^+' and '+Entry^.Package.RealPackageName^);
                Owners.Add(Name,Entry^.Package);
              end;
          end;
      finally
        Owners.Free;
        Active.Free;
      end;
    end;


  procedure Add_Package(const Name:string;IgnoreDuplicates:Boolean;Direct:Boolean);
    var
      Entry : PPackageEntry;
      Key : string;
    begin
      Key:=Upper(Name);
      Entry:=PPackageEntry(PackageList.Find(Key));
      if Assigned(Entry) then
        begin
          if not IgnoreDuplicates then
            Message1(package_e_duplicate_package,Name);
          Entry^.Direct:=Entry^.Direct or Direct;
          Exit;
        end;
      New(Entry);
      Entry^.Package:=nil;
      Entry^.RealPkgName:=Name;
      Entry^.UsedUnits:=0;
      Entry^.Direct:=Direct;
      PackageList.Add(Key,Entry);
    end;


  procedure Add_Package_Unit_Ref(Package: TPackage);
    var
      PkgEntry : PPackageEntry;
    begin
      PkgEntry:=PPackageEntry(PackageList.Find(Package.PackageName^));
      if not Assigned(PkgEntry) then
        InternalError(2015100302);
      Inc(PkgEntry^.UsedUnits);
    end;


  procedure Add_Package_Libs(L:TLinker);
    var
      PkgEntry : PPackageEntry;
      I : LongInt;
      PkgName : TPathStr;
    begin
      if TargetInfo.System in systems_indirect_var_imports then
        { we're using import libraries anyway }
        Exit;
      for I:=0 to PackageList.Count-1 do
        begin
          PkgEntry:=PPackageEntry(PackageList[I]);
          if (PkgEntry^.UsedUnits>0) or PkgEntry^.Direct then
            begin
              //writeln('package used: ',pkgentry^.realpkgname);
              PkgName:=PkgEntry^.Package.PPLFileName;
              { GNU/LLD exact-name lookup preserves the .nxpl dependency name. }
              PkgName:=':'+PkgName;
              L.SharedLibFiles.Concat(PkgName);
            end
          else
            {writeln('ignoring package: ',pkgentry^.realpkgname)};
        end;
    end;


  procedure Check_For_Indirect_Package_Usages(Modules:TLinkedList);
    var
      UU : TUsedUnit;
      PEntry : PPackageEntry;
    begin
      UU:=TUsedUnit(Modules.First);
      while Assigned(UU) do
        begin
          if Assigned(UU.U.Package) then
            begin
              PEntry:=PPackageEntry(PackageList.Find(UU.U.Package.PackageName^));
              if not Assigned(PEntry) then
                InternalError(2015112304);
              if not PEntry^.Direct then
                Message2(package_w_unit_from_indirect_package,UU.U.RealModuleName^,UU.U.Package.RealPackageName^);
            end;

          UU:=TUsedUnit(UU.Next);
        end;
    end;


  procedure CreateImportLibFromExternals;
    type
      TCacheEntry=record
        Pkg:TPackage;
        Sym:TAsmSymbol;
      end;
      PCacheEntry=^TCacheEntry;
    var
      Cache : TFPHashList;
      AlreadyLoaded : TFPObjectList;


      function FindPackageWithSym(SymName:TSymStr):TCacheEntry;
        var
          I,J : LongInt;
          PkgEntry : PPackageEntry;
          UnitEntry : PContainedUnit;
        begin
          for I:=0 to PackageList.Count-1 do
            begin
              PkgEntry:=PPackageEntry(PackageList[I]);
              for J:=0 to PkgEntry^.Package.ContainedModules.Count-1 do
                begin
                  UnitEntry:=PContainedUnit(PkgEntry^.Package.ContainedModules[J]);
                  if not Assigned(UnitEntry^.Module) then
                    { the unit is not loaded }
                    Continue;
                  Result.Sym:=TAsmSymbol(TModule(UnitEntry^.Module).PublicAsmSyms.Find(SymName));
                  if Assigned(Result.Sym) then
                    begin
                      { completely ignore other external symbols }
                      if Result.Sym.Bind in [ab_external,ab_weak_external] then
                        begin
                          Result.Sym:=nil;
                          Continue;
                        end;
                      { only accept global symbols of the used unit }
                      if Result.Sym.Bind<>ab_global then
                        begin
                          Result.Sym:=nil;
                          Result.Pkg:=nil;
                        end
                      else
                        Result.Pkg:=PkgEntry^.Package;
                      Exit;
                    end;
                end;
            end;
          Result.Sym:=nil;
          Result.Pkg:=nil;
        end;


    procedure ProcessAsmSyms(SymList:TFPHashObjectList);
      var
        I,J,K : LongInt;
        Sym : TAsmSymbol;
        CacheEntry : PCacheEntry;
        PSym : TSymEntry;
        PD : TProcDef;
        Found : Boolean;
        ImpName,SymName : TSymStr;
        SuffixIdx : LongInt;
      begin
        for I:=0 to SymList.Count-1 do
          begin
            Sym:=TAsmSymbol(SymList[I]);
            if not (Sym.Bind in [ab_external,ab_external_indirect]) then
              Continue;

            { remove the indirect suffix }
            SymName:=Sym.Name;
            if Sym.Bind=ab_external_indirect then
              begin
                SuffixIdx:=Pos(suffix_indirect,SymName);
                if SuffixIdx=Length(SymName)-Length(suffix_indirect)+1 then
                  SymName:=Copy(SymName,1,SuffixIdx-1)
                else
                  InternalError(2016062401);
              end;

            { did we already import the symbol? }
            CacheEntry:=PCacheEntry(Cache.Find(SymName));
            if Assigned(CacheEntry) then
              Continue;

            { was the symbol already imported in the previous pass? }
            Found:=False;
            for J:=0 to AlreadyLoaded.Count-1 do
              begin
                PSym:=TSymEntry(AlreadyLoaded[J]);
                case PSym.Typ of
                  ProcSym:
                    for K:=0 to TProcSym(PSym).ProcDefList.Count-1 do
                      begin
                        PD:=TProcDef(TProcSym(PSym).ProcDefList[K]);
                        if PD.has_alias_name(SymName) or
                            (
                              ([po_external,po_has_importdll]*PD.ProcOptions=[po_external,po_has_importdll]) and
                              (SymName=proc_get_importname(PD))
                            ) then
                          begin
                            Found:=True;
                            Break;
                          end;
                      end;
                  StaticVarSym:
                    if TStaticVarSym(PSym).MangledName=SymName then
                      Found:=True;
                  ConstSym:
                    begin
                      if TConstSym(PSym).ConstTyp<>ConstResourceString then
                        InternalError(2016072202);
                      if make_mangledname('RESSTR',PSym.Owner,PSym.Name)=SymName then
                        Found:=True;
                    end;
                  else
                    InternalError(2014101003);
                end;
                if Found then
                  Break;
              end;
            if Found then begin
              { add a dummy entry }
              New(CacheEntry);
              CacheEntry^.Pkg:=nil;
              CacheEntry^.Sym:=Sym;
              Cache.Add(SymName,CacheEntry);
              Continue;
            end;

            New(CacheEntry);
            CacheEntry^:=FindPackageWithSym(SymName);
            Cache.Add(SymName,CacheEntry);

            { use cacheentry^.sym instead of sym, because for the later typ
              is always at_none in case of an external symbol }
            if Assigned(CacheEntry^.Pkg) then
              begin
                ImpName:=SymName;
                if CacheEntry^.Sym.Typ=AT_DATA then
                  { import as the $indirect symbol if it as a variable }
                  ImpName:=SymName+suffix_indirect;
                CurrentModule.AddExternalImport(CacheEntry^.Pkg.PPLFileName,SymName,ImpName,0,CacheEntry^.Sym.Typ=at_data,False);
              end;
          end;
      end;


    procedure ImportProcSymbol(PD:TProcDef;Pkg:TPackage);
      var
        Item : TCmdStrListItem;
      begin
        Item := TCmdStrListItem(PD.AliasNames.First);
        if not Assigned(Item) then
          { at least import the mangled name }
          CurrentModule.AddExternalImport(Pkg.PPLFileName,PD.MangledName,PD.MangledName,0,False,False);
        while Assigned(Item) do
          begin
            CurrentModule.AddExternalImport(Pkg.PPLFileName,Item.Str,Item.Str,0,False,False);
            Item := TCmdStrListItem(Item.Next);
          end;
       end;


    procedure ProcessImportedSyms(Syms:TFPObjectList);
      { syms is a list of tunitimportsym }
      var
        I,J,K,L : LongInt;
        PkgEntry : PPackageEntry;
        Sym : TSymEntry;
        SRSymTable : TSymTable;
        Module : TModule;
        UnitEntry : PContainedUnit;
        Name : TSymStr;
        PD : TProcDef;
      begin
        for I:=0 to Syms.Count-1 do
          begin
            Sym:=TUnitImportSym(Syms[I]).Sym;
            if not (Sym.Typ in [StaticVarSym,ProcSym,ConstSym]) or
                (
                  (Sym.Typ=ConstSym) and
                  (TConstSym(Sym).ConstTyp<>ConstResourceString)
                ) then
              Continue;
            if AlreadyLoaded.IndexOf(Sym)>=0 then
              Continue;
            { determine the unit of the symbol }
            SRSymTable:=Sym.Owner;
            while not (SRSymTable.SymTableType in [StaticSymTable,GlobalSymTable]) do
              SRSymTable:=SRSymTable.DefOwner.Owner;
            Module:=TModule(Loaded_Units.First);
            while Assigned(Module) do
              begin
                if (Module.GlobalSymTable=SRSymTable) or (Module.LocalSymTable=SRSymTable) then
                  Break;
                Module:=TModule(Module.Next);
              end;
            if not Assigned(Module) then
              InternalError(2014101001);
            if (UfInLibrary and Module.HeaderFlags)=0 then
              { unit is not part of a package, so no need to handle it }
              Continue;
            { loaded by a package? }
            for J:=0 to PackageList.Count-1 do
              begin
                PkgEntry:=PPackageEntry(PackageList[J]);
                for K:=0 to PkgEntry^.Package.ContainedModules.Count-1 do
                  begin
                    UnitEntry:=PContainedUnit(PkgEntry^.Package.ContainedModules[K]);
                    if UnitEntry^.Module=Module then
                      begin
                        case Sym.Typ of
                          ConstSym:
                            begin
                              if TConstSym(Sym).ConstTyp<>ConstResourceString then
                                InternalError(2016072201);
                              Name:=make_mangledname('RESSTR',Sym.Owner,Sym.Name);
                              CurrentModule.AddExternalImport(PkgEntry^.Package.PPLFileName,Name,Name+suffix_indirect,0,True,False);
                            end;
                          StaticVarSym:
                            begin
                              Name:=TStaticVarSym(Sym).MangledName;
                              CurrentModule.AddExternalImport(PkgEntry^.Package.PPLFileName,Name,Name+suffix_indirect,0,True,False);
                            end;
                          ProcSym:
                            begin
                              for L:=0 to TProcSym(Sym).ProcDefList.Count-1 do
                                begin
                                  PD:=TProcDef(TProcSym(Sym).ProcDefList[L]);
                                  if [po_external,po_has_importdll]*PD.ProcOptions=[po_external,po_has_importdll] then
                                    { if we use an external procedure of another unit we
                                      need to import it ourselves from the correct library }
                                    import_external_proc(PD)
                                  else
                                    ImportProcSymbol(PD,PkgEntry^.Package);
                                end;
                            end;
                          else
                            InternalError(2014101002);
                        end;
                        AlreadyLoaded.Add(Sym);
                      end;
                  end;
              end;
          end;
      end;


    var
      Module : TModule;
      I : LongInt;
      LibName : TCmdStr;
    begin
      Cache:=TFPHashList.Create;
      { check each external asm symbol of each unit of the package whether it is
        contained in the unit of a loaded package (and thus an import entry
        is needed) }
      AlreadyLoaded:=TFPObjectList.Create(False);

      { first pass to find all symbols that were not loaded by asm name }
      Module:=TModule(Loaded_Units.First);
      while Assigned(Module) do
        begin
          if not Assigned(Module.Package) then
            ProcessImportedSyms(Module.UnitImportSyms);
          if (TargetInfo.System=system_x86_64_linux) and Assigned(Module.Package) then
            begin
              { Declarations imported from a packaged unit may still reference
                native libraries. Preserve its $LINKLIB requirements without
                linking the package's unit objects into this image. }
              while not Module.LinkOtherSharedLibs.Empty do
                begin
                  LibName:=Module.LinkOtherSharedLibs.GetUseMask(link_always);
                  if LibName<>'' then
                    CurrentModule.LinkOtherSharedLibs.Add(LibName,link_always);
                end;
            end;
          Module:=TModule(Module.Next);
        end;

      { second pass to find all symbols that were loaded by asm name }
      Module:=TModule(Loaded_Units.First);
      while Assigned(Module) do
        begin
          if not Assigned(Module.Package) then
            begin
              ProcessAsmSyms(Module.ExternAsmSyms);
              { A program has no unit file in which to preserve references
                introduced during code generation. Inspect its live symbols
                as well as those retained for compiled/cached units. }
              if Assigned(Module.AsmData) then
                ProcessAsmSyms(TAsmData(Module.AsmData).AsmSymbolDict);
            end;
          Module:=TModule(Module.Next);
        end;

      AlreadyLoaded.Free;
      AlreadyLoaded := nil;
      for I:=0 to Cache.Count-1 do
        Dispose(PCacheEntry(Cache[I]));
      Cache.Free;
      Cache := nil;
    end;


end.

