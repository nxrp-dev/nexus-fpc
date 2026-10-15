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
    FModule,fpkg,link,CStreams,CClasses;

  procedure createimportlibfromexternals;
  Function RewritePPU(const PPUFn:String;OutStream:TCStream):Boolean;
  procedure export_unit(u:TModule);
  procedure load_packages;
  procedure add_package(const name:string;ignoreduplicates:boolean;direct:boolean);
  procedure add_package_unit_ref(package:TPackage);
  procedure add_package_libs(l:TLinker);
  procedure check_for_indirect_package_usages(modules:TLinkedList);
  procedure emit_package_descriptor;

implementation

  uses
    SysUtils,
    GlobType,Systems,version,
    CUtils,
    Globals,Verbose,
    aasmbase,AAsmData,aasmcnst,aasmtai,
    symtype,symconst,SymSym,symdef,SymBase,SymTable,
    psub,pdecsub,
    ppu,entfile,fpcp,nxartifactid,
    export;

  procedure emit_package_descriptor;
    var
      b: TTAITypedConstBuilder;
      d: TDef;
      u: TModule;
      entry: PPackageEntry;
      i,unitcount,depcount: LongInt;
      name: TSymStr;

    procedure start;
      begin
        b:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_make_dead_strippable]);
        b.begin_anonymous_record('',8,8,8);
      end;

    procedure finish(const s: TSymStr; section: TAsmSectiontype);
      begin
        d:=b.end_anonymous_record;
        CurrentAsmData.asmlists[al_globals].ConcatList(b.get_final_asmlist(
          CurrentAsmData.DefineAsmSymbol(s,AB_GLOBAL,AT_DATA,d),d,section,s,8));
        b.free;
      end;

    procedure number(n: Int64);
      begin
        b.emit_tai(TAIConst.create_sizeint(n),sizeuinttype);
      end;

    procedure address(const s: TSymStr);
      begin
        b.emit_tai(TAIConst.createname(s,0),voidpointertype);
      end;

    begin
      { Layout matches rtl/inc/fpcpackage.pas. The experimental targets are
        currently 64 bit; every field occupies one native word. }
      if not (TargetInfo.system in [system_x86_64_win64,system_x86_64_linux]) then exit;
      start;
      for i:=1 to 6 do number(0);
      finish('FPC_PACKAGE_CONTEXT',sec_data);
      start;
      number(0);
      finish('FPC_PACKAGE_HANDLE',sec_data);
      start;
      unitcount:=0;
      u:=TModule(loaded_units.first);
      while Assigned(u) do
        begin
          if u.is_unit and not Assigned(u.package) then
            begin
              b.emit_pooled_shortstring_const_ref(u.ModuleName^);
              inc(unitcount);
            end;
          u:=TModule(u.next);
        end;
      { Retain a valid address even for an empty owned-unit list. }
      if unitcount=0 then number(0);
      finish('FPC_PACKAGE_UNITS',sec_rodata);
      if TargetInfo.system=system_x86_64_linux then
        begin
          { ELF resolves these local slots directly. Keep the descriptor's
            pointer-to-pointer ABI without manufacturing PE import symbols. }
          start;
          for i:=0 to PackageList.count-1 do
            begin
              entry:=PPackageEntry(PackageList[i]);
              if entry^.direct then
                address('FPC_PACKAGE_'+entry^.package.packagename^);
            end;
          number(0);
          finish('FPC_PACKAGE_DEPENDENCY_SLOTS',sec_rodata);
        end;
      start;
      depcount:=0;
      for i:=0 to PackageList.count-1 do
        begin
          entry:=PPackageEntry(PackageList[i]);
          if not entry^.direct then continue;
          name:='FPC_PACKAGE_'+entry^.package.packagename^;
          if TargetInfo.system=system_x86_64_linux then
            b.emit_tai(TAIConst.createname('FPC_PACKAGE_DEPENDENCY_SLOTS',depcount*8),voidpointertype)
          else
            begin
              CurrentModule.addexternalimport(entry^.package.pplfilename,
                name,name+suffix_indirect,0,true,false);
              b.emit_tai(TAIConst.create_sym(
                CurrentAsmData.RefAsmSymbol(name,AT_DATA,true)),voidpointertype);
            end;
          inc(depcount);
        end;
      if depcount=0 then number(0);
      finish('FPC_PACKAGE_DEPENDENCIES',sec_rodata);
      start;
      for i:=0 to PackageList.count-1 do
        begin
          entry:=PPackageEntry(PackageList[i]);
          if entry^.direct then
            b.emit_pooled_shortstring_const_ref(entry^.package.buildidentity);
        end;
      if depcount=0 then number(0);
      finish('FPC_PACKAGE_DEPENDENCY_IDS',sec_rodata);
      start;
      number($4e58504b);
      number(4);
      number(21*8);
      number(NexusCompilerIdentity(CurrentPPUVersion,WordVersion,CurrentPPULongVersion));
      number(ord(TargetInfo.system));
      number(find_module_from_symtable(systemunit).crc);
      b.emit_pooled_shortstring_const_ref(CurrentModule.ModuleName^);
      number(unitcount);
      address('FPC_PACKAGE_UNITS');
      number(depcount);
      address('FPC_PACKAGE_DEPENDENCIES');
      address('INITFINAL');
      address('FPC_THREADVARTABLES');
      address('FPC_RESOURCESTRINGTABLES');
      address('FPC_WIDEINITTABLES');
      address('FPC_RESSTRINITTABLES');
      address('FPC_PACKAGE_CONTEXT');
      address('FPC_PACKAGE_HANDLE');
      b.emit_pooled_shortstring_const_ref(Package_SDK_Identity);
      b.emit_pooled_shortstring_const_ref(current_package_build_identity);
      address('FPC_PACKAGE_DEPENDENCY_IDS');
      if CurrentModule.IsPackage then
        name:='FPC_PACKAGE_'+CurrentModule.ModuleName^
      else
        name:='FPC_PACKAGE_ROOT';
      finish(name,sec_rodata);
      if CurrentModule.IsPackage then
        begin
          export.exportname(name,[eo_name]);
          start;
          address(name);
          finish('FPC_PACKAGE_INFO',sec_rodata);
          export.exportname('FPC_PACKAGE_INFO',[eo_name]);
        end;
    end;

  procedure procexport(const s : string);
    var
      hp : TExportedItem;
    begin
      hp:=TExportedItem.create;
      hp.name:=StringDup(s);
      hp.options:=hp.options+[eo_name];
      exportlib.exportprocedure(hp);
    end;


  procedure varexport(const s : string);
    var
      hp : TExportedItem;
    begin
      hp:=TExportedItem.create;
      hp.name:=StringDup(s);
      hp.options:=hp.options+[eo_name];
      exportlib.exportvar(hp);
    end;


  procedure exportprocsym(sym:TProcSym;SymTable:TSymTable);
    var
      i : LongInt;
      pd : TProcDef;
    begin
      for i:=0 to TProcSym(sym).ProcdefList.Count-1 do
        begin
          pd:=TProcDef(TProcSym(sym).procdeflist[i]);
          if not(pd.proccalloption in [pocall_internproc]) and
              not (df_generic in pd.defoptions) and
              ((pd.procoptions*[po_external])=[]) and
              (
                (SymTable.symtabletype in [GlobalSymTable,recordsymtable,objectsymtable]) or
                (
                  (SymTable.symtabletype=staticsymtable) and
                  (
                    ([po_public,po_has_public_name]*pd.procoptions<>[]) or
                    (df_has_global_ref in pd.defoptions)
                  )
                )
              ) then
            begin
              exportallprocdefnames(TProcSym(sym),pd,[eo_name,eo_no_sym_name]);
            end;
        end;
    end;


  procedure exportabstractrecorddef(def:TAbstractRecordDef;SymTable:TSymTable); forward;


  procedure exportabstractrecordsymproc(sym:tobject;arg:pointer);
    begin
      case TSym(sym).typ of
        typesym:
          begin
            case TTypeSym(sym).typedef.typ of
              objectdef,
              recorddef:
                exportabstractrecorddef(TAbstractRecordDef(TTypeSym(sym).typedef),TSymTable(arg));
              else
                ;
            end;
          end;
        procsym:
          begin
            { don't export methods of interfaces }
            if is_interface(TDef(TAbstractRecordSymTable(arg).defowner)) then
              exit;
            exportprocsym(TProcSym(sym),TSymTable(arg));
          end;
        staticvarsym:
          begin
            varexport(TSym(sym).mangledname);
          end;
        else
          ;
      end;
    end;


  procedure exportname(const s:TSymStr);
    var
      hp : TExportedItem;
    begin
      hp:=TExportedItem.create;
      hp.name:=StringDup(s);
      hp.options:=hp.options+[eo_name];
      exportlib.exportvar(hp);
    end;


  procedure exportabstractrecorddef(def:TAbstractRecordDef;SymTable:TSymTable);
    begin
      { for cross unit type aliases this might happen }
      if def.owner<>SymTable then
        exit;
      { don't export generics or their nested types }
      if df_generic in def.defoptions then
        exit;
      def.SymTable.SymList.ForEachCall(@exportabstractrecordsymproc,def.SymTable);
      if def.typ=objectdef then
        begin
          if (oo_has_vmt in TObjectDef(def).objectoptions) then
            exportname(TObjectDef(def).vmt_mangledname);
          if is_interface(def) then
            begin
              if Assigned(TObjectDef(def).iidguid) then
                exportname(make_mangledname('IID',def.owner,def.objname^));
              exportname(make_mangledname('IIDSTR',def.owner,def.objname^));
            end;
        end;
    end;


  procedure export_typedef(def:TDef;SymTable:TSymTable;global:boolean);
    begin
      if not (global or is_class(def)) or
          ([df_internal,df_generic]*def.defoptions<>[]) or
          { happens with type renaming declarations ("abc = xyz") }
          (def.owner<>SymTable) then
        exit;
      if ds_rtti_table_written in def.defstates then
        exportname(def.RTTIMangledName(fullrtti));
      if (ds_init_table_written in def.defstates) and
          def.NeedsSeparateInitRTTI then
        exportname(def.RTTIMangledName(initrtti));
      case def.typ of
        recorddef,
        objectdef:
          exportabstractrecorddef(TAbstractRecordDef(def),SymTable);
        else
          ;
      end;
    end;


  procedure insert_export(sym : TObject;arg:pointer);
    var
      isglobal,
      publiconly : boolean;
    begin
      publiconly:=TSymTable(arg).symtabletype=staticsymtable;
      isglobal:=TSymTable(arg).symtabletype=GlobalSymTable;
      case TSym(sym).typ of
        { ignore: }
        unitsym,
        syssym,
        namespacesym,
        propertysym,
        enumsym:
          ;
        constsym:
          begin
            if TConstSym(sym).consttyp=constresourcestring then
              varexport(make_mangledname('RESSTR',TSym(sym).owner,TSym(sym).name));
          end;
        typesym:
          begin
            export_typedef(TTypeSym(sym).typedef,TSymTable(arg),isglobal);
          end;
        procsym:
          begin
            exportprocsym(TProcSym(sym),TSymTable(arg));
          end;
        staticvarsym:
          begin
            if publiconly and ([vo_is_public,vo_has_global_ref]*TStaticVarSym(sym).varoptions=[]) then
              exit;
            varexport(TSym(sym).mangledname);
          end;
        absolutevarsym:
          ;
        else
          begin
            //writeln('unknown: ',TSym(sym).typ);
            InternalError(2016080501);
          end;
      end;
    end;


  procedure export_unit(u: TModule);
    var
      i : LongInt;
      sym : TAsmSymbol;
    begin
      u.GlobalSymTable.symlist.ForEachCall(@insert_export,u.GlobalSymTable);
      { check localsymtable for exports too to get public symbols }
      u.localsymtable.symlist.ForEachCall(@insert_export,u.localsymtable);

      { Callable names retained for inline implementation helpers must remain
        exported even when a cached unit no longer has their local procsym.
        Public records can contain anonymous managed types with no typesym.
        Their emitted metadata is nevertheless referenced by consumer cleanup
        code, so include the unit's globally visible RTTI/init symbols. }
      for i:=0 to u.publicasmsyms.count-1 do
        begin
          sym:=TAsmSymbol(u.publicasmsyms[i]);
          if (sym.bind=AB_GLOBAL) and (sym.typ=AT_FUNCTION) then
            procexport(sym.name)
          else if (sym.bind=AB_GLOBAL) and (sym.typ=AT_DATA) and
             ((copy(sym.name,1,5)='RTTI_') or (copy(sym.name,1,5)='INIT_')) then
            varexport(sym.name);
        end;

      { create special exports }
      if mf_init in u.moduleflags then
        procexport(make_mangledname('INIT$',u.GlobalSymTable,''));
      if mf_finalize in u.moduleflags then
        procexport(make_mangledname('FINALIZE$',u.GlobalSymTable,''));
      if mf_threadvars in u.moduleflags then
        varexport(make_mangledname('THREADVARLIST',u.GlobalSymTable,''));
      if mf_has_resourcestrings in u.moduleflags then
        begin
          varexport(CTAITypedConstBuilder.get_vectorized_dead_strip_section_symbol_start('RESSTR',u.localsymtable,[]).name);
          varexport(CTAITypedConstBuilder.get_vectorized_dead_strip_section_symbol_end('RESSTR',u.localsymtable,[]).name);
        end;

      if not (TargetInfo.system in systems_indirect_var_imports) then
        for i:=0 to u.publicasmsyms.count-1 do
          begin
            sym:=TAsmSymbol(u.publicasmsyms[i]);
            if sym.bind=AB_INDIRECT then
              varexport(sym.name);
          end;
    end;

  Function RewritePPU(const PPUFn:String;OutStream:TCStream):Boolean;
    Var
      MakeStatic : Boolean;
    Var
      buffer : array[0..$1fff] of byte;
      inppu,
      outppu : TPPUFile;
      b,
      untilb : byte;
      l,m    : LongInt;
      ext,
      s      : string;
      ppuversion,ppulongversion : dword;
    begin
      Result:=false;
      MakeStatic:=False;
      inppu:=TPPUFile.create(PPUFn);
      if not inppu.openfile then
       begin
         inppu.free;
         inppu := nil;
         Comment(VError,'Could not open : '+PPUFn);
         Exit;
       end;
    { Check the ppufile }
      if not inppu.CheckPPUId then
       begin
         inppu.free;
         inppu := nil;
         Comment(VError,'Expected NexusFPC NXU unit signature in '+PPUFn+'; rebuild with NexusFPC');
         Exit;
       end;
      ppuversion:=inppu.getversion;
      if ppuversion<>CurrentPPUVersion then
       begin
         inppu.free;
         inppu := nil;
         Comment(VError,'Wrong PPU Version '+ToStr(ppuversion)+' in '+PPUFn);
         Exit;
       end;
    { Already a lib? }
      if (inppu.header.common.flags and uf_in_library)<>0 then
       begin
         inppu.free;
         inppu := nil;
         Comment(VError,'PPU is already in a library : '+PPUFn);
         Exit;
       end;
    { We need a static linked unit, but we also accept those without .o file }
      if (inppu.header.common.flags and (uf_static_linked or uf_no_link))=0 then
       begin
         inppu.free;
         inppu := nil;
         Comment(VError,'PPU is not static linked : '+PPUFn);
         Exit;
       end;
    { Create the new ppu }
      outppu:=TPPUFile.create(PPUFn);
      outppu.createstream(OutStream);
    { Create new header, with the new flags }
      outppu.header:=inppu.header;
      outppu.header.common.flags:=outppu.header.common.flags or uf_in_library;
      if MakeStatic then
       outppu.header.common.flags:=outppu.header.common.flags or uf_static_linked
      else
       outppu.header.common.flags:=outppu.header.common.flags or uf_shared_linked;
    { read until the object files are found }
      untilb:=iblinkunitofiles;
      repeat
        b:=inppu.readentry;
        if b in [ibendinterface,ibend] then
         begin
           inppu.free;
           inppu := nil;
           outppu.free;
           outppu := nil;
           Comment(VError,'No files to be linked found : '+PPUFn);
           Exit;
         end;
        if b<>untilb then
         begin
           if b=ibextraheader then
             begin
               ppulongversion:=cardinal(inppu.getlongint);
               if ppulongversion<>CurrentPPULongVersion then
                 begin
                   inppu.free;
                   outppu.free;
                   Comment(VError,'Wrong NexusFPC PPU Long Version in '+PPUFn);
                   exit;
                 end;
               outppu.putlongint(LongInt(ppulongversion));
             end;
           repeat
             inppu.getdatabuf(buffer,sizeof(buffer),l);
             outppu.putdata(buffer,l);
           until l<sizeof(buffer);
           outppu.writeentry(b);
         end;
      until (b=untilb);
    { we have now reached the section for the files which need to be added,
      now add them to the list }
      case b of
        iblinkunitofiles :
          begin
            { add all o files, and save the entry when not creating a static
              library to keep staticlinking possible }
            while not inppu.endofentry do
             begin
               s:=inppu.getstring;
               m:=inppu.getlongint;
               if not MakeStatic then
                begin
                  outppu.putstring(s);
                  outppu.putlongint(m);
                end;
               CurrentModule.linkotherofiles.add(s,link_always);
             end;
            if not MakeStatic then
             outppu.writeentry(b);
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
         outppu.putstring('imp'+CurrentModule.RealModuleName^);
         outppu.putlongint(link_static);
         outppu.writeentry(iblinkunitstaticlibs)
       end
      else
       begin
         outppu.putstring('imp'+CurrentModule.RealModuleName^);
         outppu.putlongint(link_shared);
         outppu.writeentry(iblinkunitsharedlibs);
       end;
    { read all entries until the end and write them also to the new ppu }
      repeat
        b:=inppu.readentry;
      { don't write ibend, that's written automatically }
        if b<>ibend then
         begin
           if b=iblinkothersharedlibs then
             begin
               while not inppu.endofentry do
                 begin
                   s:=inppu.getstring;
                   m:=inppu.getlongint;

                   outppu.putstring(s);
                   outppu.putlongint(m);

                   { strip lib prefix }
                   if copy(s,1,3)='lib' then
                     delete(s,1,3);
                   ext:=ExtractFileExt(s);
                   if ext<>'' then
                     delete(s,length(s)-length(ext)+1,length(ext));

                   CurrentModule.linkOtherSharedLibs.add(s,link_always);
                 end;
             end
           else
             repeat
               inppu.getdatabuf(buffer,sizeof(buffer),l);
               outppu.putdata(buffer,l);
             until l<sizeof(buffer);
           outppu.writeentry(b);
         end;
      until b=ibend;
    { write the last stuff and close }
      outppu.flush;
      outppu.writeheader;
      outppu.free;
      outppu := nil;
      inppu.free;
      inppu := nil;
      Result:=True;
    end;


  procedure load_packages;
    var
      active : TFPList;
      owners : TFPHashList;
      i,j : LongInt;
      entry : PPackageEntry;
      owner : TPackage;
      name : string;

    procedure load_package(entry:PPackageEntry);
      var
        i : LongInt;
        required : PPackageEntry;
        pcp : TPCPPackage;
        chain : AnsiString;
        buildingpackage : boolean;
      begin
        buildingpackage:=Assigned(CurrentModule) and CurrentModule.IsPackage;
        if (active.IndexOf(entry)>=0) or
           (buildingpackage and (upper(entry^.realpkgname)=CurrentModule.ModuleName^)) then
          begin
            chain:='';
            if buildingpackage then
              chain:=CurrentModule.RealModuleName^+' -> ';
            for i:=0 to active.count-1 do
              chain:=chain+PPackageEntry(active[i])^.realpkgname+' -> ';
            Comment(VFatal,'Circular package dependency: '+chain+entry^.realpkgname);
          end;
        if Assigned(entry^.package) then
          exit;
        active.Add(entry);
        try
          Comment(VInfo,'Loading package: '+entry^.realpkgname);
          pcp:=TPCPPackage.create(entry^.realpkgname);
          { Give the package list ownership even if loading aborts. }
          entry^.package:=pcp;
          pcp.loadpcp;
          for i:=0 to pcp.requiredpackages.count-1 do
            begin
              add_package(pcp.requiredpackages.NameOfIndex(i),true,false);
              required:=PPackageEntry(PackageList.Find(upper(pcp.requiredpackages.NameOfIndex(i))));
              load_package(required);
              if PShortString(pcp.requiredidentities.Find(upper(pcp.requiredpackages.NameOfIndex(i))))^<>
                 required^.package.buildidentity then
                Comment(VFatal,'Package dependency build differs: '+
                  pcp.realpackagename^+' requires '+required^.realpkgname);
              pcp.requiredpackages[i]:=required^.package;
            end;
        finally
          active.Delete(active.count-1);
        end;
      end;

    begin
      if not (tf_supports_packages in TargetInfo.flags) then
        exit;
      active:=TFPList.Create;
      owners:=TFPHashList.Create;
      try
        i:=0;
        while i<PackageList.count do
          begin
            load_package(PPackageEntry(PackageList[i]));
            inc(i);
          end;
        { Check the complete closure before unit lookup can choose a provider. }
        for i:=0 to PackageList.count-1 do
          begin
            entry:=PPackageEntry(PackageList[i]);
            for j:=0 to entry^.package.containedmodules.count-1 do
              begin
                name:=upper(entry^.package.containedmodules.NameOfIndex(j));
                owner:=TPackage(owners.Find(name));
                if Assigned(owner) then
                  Comment(VFatal,'Unit '+name+' is contained in both packages '+
                    owner.realpackagename^+' and '+entry^.package.realpackagename^);
                owners.Add(name,entry^.package);
              end;
          end;
      finally
        owners.Free;
        active.Free;
      end;
    end;


  procedure add_package(const name:string;ignoreduplicates:boolean;direct:boolean);
    var
      entry : PPackageEntry;
      key : string;
    begin
      key:=upper(name);
      entry:=PPackageEntry(PackageList.Find(key));
      if Assigned(entry) then
        begin
          if not ignoreduplicates then
            Message1(package_e_duplicate_package,name);
          entry^.direct:=entry^.direct or direct;
          exit;
        end;
      new(entry);
      entry^.package:=nil;
      entry^.realpkgname:=name;
      entry^.usedunits:=0;
      entry^.direct:=direct;
      PackageList.add(key,entry);
    end;


  procedure add_package_unit_ref(package: TPackage);
    var
      pkgentry : PPackageEntry;
    begin
      pkgentry:=PPackageEntry(PackageList.find(package.packagename^));
      if not Assigned(pkgentry) then
        InternalError(2015100302);
      inc(pkgentry^.usedunits);
    end;


  procedure add_package_libs(l:TLinker);
    var
      pkgentry : PPackageEntry;
      i : LongInt;
      pkgname : TPathStr;
    begin
      if TargetInfo.system in systems_indirect_var_imports then
        { we're using import libraries anyway }
        exit;
      for i:=0 to PackageList.count-1 do
        begin
          pkgentry:=PPackageEntry(PackageList[i]);
          if (pkgentry^.usedunits>0) or pkgentry^.direct then
            begin
              //writeln('package used: ',pkgentry^.realpkgname);
              pkgname:=pkgentry^.package.pplfilename;
              { GNU/LLD exact-name lookup preserves the .nxpl dependency name. }
              pkgname:=':'+pkgname;
              l.sharedlibfiles.concat(pkgname);
            end
          else
            {writeln('ignoring package: ',pkgentry^.realpkgname)};
        end;
    end;


  procedure check_for_indirect_package_usages(modules:TLinkedList);
    var
      uu : TUsedUnit;
      pentry : PPackageEntry;
    begin
      uu:=TUsedUnit(modules.first);
      while Assigned(uu) do
        begin
          if Assigned(uu.u.package) then
            begin
              pentry:=PPackageEntry(PackageList.find(uu.u.package.packagename^));
              if not Assigned(pentry) then
                InternalError(2015112304);
              if not pentry^.direct then
                Message2(package_w_unit_from_indirect_package,uu.u.RealModuleName^,uu.u.package.realpackagename^);
            end;

          uu:=TUsedUnit(uu.Next);
        end;
    end;


  procedure createimportlibfromexternals;
    type
      TCacheEntry=record
        pkg:TPackage;
        sym:TAsmSymbol;
      end;
      PCacheEntry=^TCacheEntry;
    var
      cache : TFPHashList;
      alreadyloaded : TFPObjectList;


      function findpackagewithsym(symname:TSymStr):TCacheEntry;
        var
          i,j : LongInt;
          pkgentry : PPackageEntry;
          unitentry : PContainedUnit;
        begin
          for i:=0 to PackageList.count-1 do
            begin
              pkgentry:=PPackageEntry(PackageList[i]);
              for j:=0 to pkgentry^.package.containedmodules.count-1 do
                begin
                  unitentry:=PContainedUnit(pkgentry^.package.containedmodules[j]);
                  if not Assigned(unitentry^.module) then
                    { the unit is not loaded }
                    continue;
                  result.sym:=TAsmSymbol(TModule(unitentry^.module).publicasmsyms.find(symname));
                  if Assigned(result.sym) then
                    begin
                      { completely ignore other external symbols }
                      if result.sym.bind in [ab_external,ab_weak_external] then
                        begin
                          result.sym:=nil;
                          continue;
                        end;
                      { only accept global symbols of the used unit }
                      if result.sym.bind<>ab_global then
                        begin
                          result.sym:=nil;
                          result.pkg:=nil;
                        end
                      else
                        result.pkg:=pkgentry^.package;
                      exit;
                    end;
                end;
            end;
          result.sym:=nil;
          result.pkg:=nil;
        end;


    procedure processasmsyms(symlist:TFPHashObjectList);
      var
        i,j,k : LongInt;
        sym : TAsmSymbol;
        cacheentry : PCacheEntry;
        psym : TSymEntry;
        pd : TProcDef;
        found : boolean;
        impname,symname : TSymStr;
        suffixidx : LongInt;
      begin
        for i:=0 to symlist.count-1 do
          begin
            sym:=TAsmSymbol(symlist[i]);
            if not (sym.bind in [ab_external,ab_external_indirect]) then
              continue;

            { remove the indirect suffix }
            symname:=sym.name;
            if sym.bind=ab_external_indirect then
              begin
                suffixidx:=pos(suffix_indirect,symname);
                if suffixidx=length(symname)-length(suffix_indirect)+1 then
                  symname:=copy(symname,1,suffixidx-1)
                else
                  InternalError(2016062401);
              end;

            { did we already import the symbol? }
            cacheentry:=PCacheEntry(cache.find(symname));
            if Assigned(cacheentry) then
              continue;

            { was the symbol already imported in the previous pass? }
            found:=false;
            for j:=0 to alreadyloaded.count-1 do
              begin
                psym:=TSymEntry(alreadyloaded[j]);
                case psym.typ of
                  procsym:
                    for k:=0 to TProcSym(psym).procdeflist.count-1 do
                      begin
                        pd:=TProcDef(TProcSym(psym).procdeflist[k]);
                        if pd.has_alias_name(symname) or
                            (
                              ([po_external,po_has_importdll]*pd.procoptions=[po_external,po_has_importdll]) and
                              (symname=proc_get_importname(pd))
                            ) then
                          begin
                            found:=true;
                            break;
                          end;
                      end;
                  staticvarsym:
                    if TStaticVarSym(psym).mangledname=symname then
                      found:=true;
                  constsym:
                    begin
                      if TConstSym(psym).consttyp<>constresourcestring then
                        InternalError(2016072202);
                      if make_mangledname('RESSTR',psym.owner,psym.name)=symname then
                        found:=true;
                    end;
                  else
                    InternalError(2014101003);
                end;
                if found then
                  break;
              end;
            if found then begin
              { add a dummy entry }
              new(cacheentry);
              cacheentry^.pkg:=nil;
              cacheentry^.sym:=sym;
              cache.add(symname,cacheentry);
              continue;
            end;

            new(cacheentry);
            cacheentry^:=findpackagewithsym(symname);
            cache.add(symname,cacheentry);

            { use cacheentry^.sym instead of sym, because for the later typ
              is always at_none in case of an external symbol }
            if Assigned(cacheentry^.pkg) then
              begin
                impname:=symname;
                if cacheentry^.sym.typ=AT_DATA then
                  { import as the $indirect symbol if it as a variable }
                  impname:=symname+suffix_indirect;
                CurrentModule.addexternalimport(cacheentry^.pkg.pplfilename,symname,impname,0,cacheentry^.sym.typ=at_data,false);
              end;
          end;
      end;


    procedure import_proc_symbol(pd:TProcDef;pkg:TPackage);
      var
        item : TCmdStrListItem;
      begin
        item := TCmdStrListItem(pd.aliasnames.first);
        if not Assigned(item) then
          { at least import the mangled name }
          CurrentModule.addexternalimport(pkg.pplfilename,pd.mangledname,pd.mangledname,0,false,false);
        while Assigned(item) do
          begin
            CurrentModule.addexternalimport(pkg.pplfilename,item.str,item.str,0,false,false);
            item := TCmdStrListItem(item.next);
          end;
       end;


    procedure processimportedsyms(syms:TFPObjectList);
      { syms is a list of tunitimportsym }
      var
        i,j,k,l : LongInt;
        pkgentry : PPackageEntry;
        sym : TSymEntry;
        srsymtable : TSymTable;
        module : TModule;
        unitentry : PContainedUnit;
        name : TSymStr;
        pd : TProcDef;
      begin
        for i:=0 to syms.count-1 do
          begin
            sym:=TUnitImportSym(syms[i]).sym;
            if not (sym.typ in [staticvarsym,procsym,constsym]) or
                (
                  (sym.typ=constsym) and
                  (TConstSym(sym).consttyp<>constresourcestring)
                ) then
              continue;
            if alreadyloaded.indexof(sym)>=0 then
              continue;
            { determine the unit of the symbol }
            srsymtable:=sym.owner;
            while not (srsymtable.symtabletype in [staticsymtable,GlobalSymTable]) do
              srsymtable:=srsymtable.defowner.owner;
            module:=TModule(loaded_units.first);
            while Assigned(module) do
              begin
                if (module.GlobalSymTable=srsymtable) or (module.localsymtable=srsymtable) then
                  break;
                module:=TModule(module.next);
              end;
            if not Assigned(module) then
              InternalError(2014101001);
            if (uf_in_library and module.headerflags)=0 then
              { unit is not part of a package, so no need to handle it }
              continue;
            { loaded by a package? }
            for j:=0 to PackageList.count-1 do
              begin
                pkgentry:=PPackageEntry(PackageList[j]);
                for k:=0 to pkgentry^.package.containedmodules.count-1 do
                  begin
                    unitentry:=PContainedUnit(pkgentry^.package.containedmodules[k]);
                    if unitentry^.module=module then
                      begin
                        case sym.typ of
                          constsym:
                            begin
                              if TConstSym(sym).consttyp<>constresourcestring then
                                InternalError(2016072201);
                              name:=make_mangledname('RESSTR',sym.owner,sym.name);
                              CurrentModule.addexternalimport(pkgentry^.package.pplfilename,name,name+suffix_indirect,0,true,false);
                            end;
                          staticvarsym:
                            begin
                              name:=TStaticVarSym(sym).mangledname;
                              CurrentModule.addexternalimport(pkgentry^.package.pplfilename,name,name+suffix_indirect,0,true,false);
                            end;
                          procsym:
                            begin
                              for l:=0 to TProcSym(sym).procdeflist.count-1 do
                                begin
                                  pd:=TProcDef(TProcSym(sym).procdeflist[l]);
                                  if [po_external,po_has_importdll]*pd.procoptions=[po_external,po_has_importdll] then
                                    { if we use an external procedure of another unit we
                                      need to import it ourselves from the correct library }
                                    import_external_proc(pd)
                                  else
                                    import_proc_symbol(pd,pkgentry^.package);
                                end;
                            end;
                          else
                            InternalError(2014101002);
                        end;
                        alreadyloaded.add(sym);
                      end;
                  end;
              end;
          end;
      end;


    var
      module : TModule;
      i : LongInt;
      libname : TCmdStr;
    begin
      cache:=TFPHashList.create;
      { check each external asm symbol of each unit of the package whether it is
        contained in the unit of a loaded package (and thus an import entry
        is needed) }
      alreadyloaded:=TFPObjectList.create(false);

      { first pass to find all symbols that were not loaded by asm name }
      module:=TModule(loaded_units.first);
      while Assigned(module) do
        begin
          if not Assigned(module.package) then
            processimportedsyms(module.unitimportsyms);
          if (TargetInfo.system=system_x86_64_linux) and Assigned(module.package) then
            begin
              { Declarations imported from a packaged unit may still reference
                native libraries. Preserve its $LINKLIB requirements without
                linking the package's unit objects into this image. }
              while not module.linkothersharedlibs.empty do
                begin
                  libname:=module.linkothersharedlibs.GetUseMask(link_always);
                  if libname<>'' then
                    CurrentModule.linkothersharedlibs.add(libname,link_always);
                end;
            end;
          module:=TModule(module.next);
        end;

      { second pass to find all symbols that were loaded by asm name }
      module:=TModule(loaded_units.first);
      while Assigned(module) do
        begin
          if not Assigned(module.package) then
            begin
              processasmsyms(module.externasmsyms);
              { A program has no unit file in which to preserve references
                introduced during code generation. Inspect its live symbols
                as well as those retained for compiled/cached units. }
              if Assigned(module.asmdata) then
                processasmsyms(TAsmData(module.asmdata).AsmSymbolDict);
            end;
          module:=TModule(module.next);
        end;

      alreadyloaded.free;
      alreadyloaded := nil;
      for i:=0 to cache.count-1 do
        dispose(PCacheEntry(cache[i]));
      cache.free;
      cache := nil;
    end;


end.

