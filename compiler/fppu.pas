{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements the first loading and searching of the modules

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
unit fppu;

{$i fpcdefs.inc}


interface

    uses
      CMsgs,Verbose,
      CUtils,CClasses,CStreams,
      GlobType,Globals,GlobStat,FPCHash,FinPut,FModule,
      SymBase,ppu,symtype;

    type
       { tppumodule }
       TAvailableUnitFile = (auPPU,auSrc);
       TAvailableUnitFiles = set of TAvailableUnitFile;

       TPPUModule = class(TModule)
          ppufile    : TCompilerPPUFile; { the PPU file }
          sourcefn   : TPathStr; { Source specified with "uses .. in '..'" }
          comments   : TCmdStrList;
          nsprefix   : TCmdStr; { Namespace prefix the unit was found with }
          constructor create(LoadedFrom:TModule;const amodulename: string; const afilename:TPathStr;_is_unit:boolean);
          destructor Destroy;override;
          function StateStr: string; override;
          procedure checkstate; override;
          procedure reset(for_recompile: boolean);override;
          procedure re_resolve;
          function  openppufile:boolean;
          function  openppustream(strm:TCStream):boolean;
          procedure getppucrc;
          function dependent_module_has_our_crc: boolean;
          function dependent_module_crc_mismatch: boolean;
          procedure writeppu;
          function loadppu(from_module : TModule) : boolean;
          function get_check_uses(out check_impl_uses, check_crc: boolean): boolean;
          function continueloadppu : boolean;
          function canreload(out firstwaiting: TModule; ignore_do_reload: boolean): boolean;
          procedure reload;
          function ppuloadcancontinue(out firstwaiting: TModule): boolean;
          function is_reload_needed(pu: TDependentUnit): boolean; override;
          procedure restore_state;
          procedure store_state;
          procedure recompile_from_sources;
          procedure check_sources_for_recompile;
          procedure post_load_or_compile(from_module : TModule);
          procedure discardppu;
          procedure setdefgeneration;
          procedure end_of_parsing;override;
       private
          packageppustream : TCStream; { owned while a package PPU is loaded }
          unitimportsymsderefs : TFPList;
         { Each time a unit's defs are (re)created, its defsgeneration is
           set to the value of a global counter, and the global counter is
           increased. We only reresolve its dependent units' defs in case
           they have been resolved only for an older generation, in order to
           avoid endless resolving loops in case of cyclic dependencies. }
          defsgeneration : LongInt;
          stored_state: TGlobalState;

          function check_loadfrompackage: boolean;
          function  openppu(ppufiletime:LongInt):boolean;
          procedure mark_recompile_needed(reason: TRecompileReason);
          function  search_unit_files(loaded_from : TModule; onlysource:boolean):TAvailableUnitFiles;
          function  search_unit(loaded_from : TModule; onlysource,shortname:boolean):TAvailableUnitFiles;
          function  loadfrompackage:boolean;
          procedure load_interface;
          procedure load_implementation;
          function load_usedunits: boolean;
          function load_usedunits_section: boolean;
          function ppu_check_used_crcs: boolean;
          procedure printcomments;
          procedure queuecomment(const s:TMsgStr;v,w:LongInt);
          procedure buildderefunitimportsyms;
          procedure derefunitimportsyms;
          procedure freederefunitimportsyms;
          procedure writesourcefiles;
          procedure writeusedunit(intf:boolean);
          procedure writelinkcontainer(var p:TLinkContainer;id:byte;strippath:boolean);
          procedure writederefmap;
          procedure writederefdata;
          procedure writeImportSymbols;
          procedure writeResources;
          procedure writeOrderedSymbols;
          procedure writeUnitExports;
          procedure writeunitimportsyms;
          procedure writeasmsyms(kind:TUnitAsmListType;list:TFPHashObjectList);
          procedure writeextraheader;
          procedure readsourcefiles;
          procedure readloadunit;
          procedure readlinkcontainer(var p:TLinkContainer);
          procedure readderefmap;
          procedure readderefdata;
          procedure readImportSymbols;
          procedure readResources;
          procedure readOrderedSymbols;
          procedure readUnitExports;
          procedure readwpofile;
          procedure readunitimportsyms;
          procedure readasmsyms;
          procedure readextraheader;
{$IFDEF MACRO_DIFF_HINT}
          procedure writeusedmacro(p:TNamedIndexItem;arg:pointer);
          procedure writeusedmacros;
          procedure readusedmacros;
{$ENDIF}
       end;

    function registerunit(callermodule:TModule;const s : TIDString;const fn:string; out is_new:boolean) : TPPUModule;


implementation

uses
  SysUtils,
  CFileUtl,
  Systems,version,options,
  SymTable, SymSym,
  wpoinfo,
  Scanner,
  aasmbase,AAsmData,ogbase,
  CompHook,
  entfile,FPkg,FPCP,export;


var
  currentdefgeneration: LongInt;

{****************************************************************************
                                TPPUMODULE
 ****************************************************************************}

    constructor TPPUModule.create(LoadedFrom:TModule;const amodulename: string; const afilename:TPathStr;_is_unit:boolean);
      begin
        inherited create(LoadedFrom,amodulename,afilename,_is_unit);
        ppufile:=nil;
        sourcefn:=afilename;
        unitimportsymsderefs:=TFPList.create;
      end;


    destructor TPPUModule.Destroy;
      begin
        discardppu;
        comments.free;
        comments:=nil;
        { all derefs allocated with new
          are dispose'd inside this method }
        freederefunitimportsyms;
        unitimportsymsderefs.free;
        unitimportsymsderefs:=nil;
        inherited Destroy;
      end;

    function TPPUModule.StateStr: string;
      begin
        Result:=inherited StateStr;
        if state<>ms_load then exit;
        if ppu_waitingfor_crc then
          Result:=Result+',waitcrc'
        else if interface_compiled then
          Result:=Result+',interface_compiled'
        else
          Result:=Result+',waitintf';
      end;

    procedure TPPUModule.checkstate;
      begin
        if state=ms_load then

        else
          inherited checkstate;
      end;

    procedure TPPUModule.reset(for_recompile : boolean);
      begin
        loadedfrommodule:=nil;
        ppu_waitingfor_crc:=false;
        discardppu;
        freederefunitimportsyms;
        unitimportsymsderefs.free;
        unitimportsymsderefs:=TFPList.create;
        inherited reset(for_recompile);
      end;

    procedure TPPUModule.re_resolve;

      begin
        Message1(unit_u_reresolving_unit,ModuleName^);
        if TStoredSymTable(GlobalSymTable).is_deref_built then
          TStoredSymTable(GlobalSymTable).deref(false);
        if TStoredSymTable(GlobalSymTable).is_derefimpl_built then
          TStoredSymTable(GlobalSymTable).derefimpl(false);
        if Assigned(localsymtable) then
          begin
            { we have only builderef(impl)'d the registered symbols of
              the localsymtable -> also only deref those again }
            if TStoredSymTable(localsymtable).is_deref_built then
              TStoredSymTable(localsymtable).deref(true);
            if TStoredSymTable(localsymtable).is_derefimpl_built then
              TStoredSymTable(localsymtable).derefimpl(true);
          end;
        derefimportedsymbols;
        if Assigned(wpoinfo) then
          begin
            TUnitWPOInfo(wpoinfo).deref;
            TUnitWPOInfo(wpoinfo).derefimpl;
          end;

        { all dependent units were already flagged recursively for reload }
        defsgeneration:=currentdefgeneration;
      end;


    procedure TPPUModule.queuecomment(const s:TMsgStr;v,w:LongInt);
    begin
      if comments = nil then
        comments := TCmdStrList.create;
      comments.insert(s);
    end;

    procedure TPPUModule.printcomments;
    var
      comment: string;
    begin
      if comments = nil then
        exit;
      { comments are inserted in reverse order }
      repeat
        comment := comments.getlast;
        if length(comment) = 0 then
          exit;
        Do_Comment(VNormal, comment);
      until false;
    end;

    function TPPUModule.openppufile:boolean;
      var
        ppufiletime : LongInt;
      begin
        openppufile:=false;
        Message1(unit_t_ppu_loading,PPUFileName,@queuecomment);
      { Get ppufile time (also check if the file exists) }
        ppufiletime:=getnamedfiletime(PPUFileName);
        if ppufiletime=-1 then
         exit;
      { Open the ppufile }
        Message1(unit_u_ppu_name,PPUFileName);
        ppufile:=TCompilerPPUFile.create(PPUFileName);
        if not ppufile.openfile then
         begin
           discardppu;
           Message(unit_u_ppu_file_too_short);
           exit;
         end;
        result:=openppu(ppufiletime);
      end;


    function TPPUModule.openppustream(strm:TCStream):boolean;
      begin
        result:=false;
      { Open the ppufile }
        Message1(unit_u_ppu_name,PPUFileName);
        ppufile:=TCompilerPPUFile.create(PPUFileName);
        if not ppufile.openstream(strm) then
         begin
           discardppu;
           Message(unit_u_ppu_file_too_short);
           exit;
         end;
        result:=openppu(-1);
      end;


    function TPPUModule.openppu(ppufiletime:LongInt):boolean;

      function checkheader: boolean;
        var
          psi: PSystemInfo;
          system_name: shortstring;
        begin
          result:=false;
          { check for a valid PPU file }
            if not ppufile.CheckPPUId then
             begin
               Message(unit_u_ppu_invalid_header,@queuecomment);
               exit;
             end;
          { check for allowed PPU versions }
            if not (ppufile.getversion = CurrentPPUVersion) then
             begin
               Message2(unit_u_ppu_invalid_version,ToStr(ppufile.getversion),ToStr(CurrentPPUVersion),@queuecomment);
               exit;
             end;
          { check the target processor }
            if TSystemCPU(ppufile.header.common.cpu)<>TargetCPU then
             begin
               Message1(unit_u_ppu_invalid_processor,cpu2str[Ord(TSystemCPU(ppufile.header.common.cpu))],@queuecomment);
               exit;
             end;
          { check target }
            if TSystem(ppufile.header.common.target)<>TargetInfo.system then
             begin
               psi:=targetinfos[Ord(TSystem(ppufile.header.common.target))];
               if Assigned(psi) then
                 system_name:=psi^.shortname
               else
                 system_name:='invalid ('+ToStr(ppufile.header.common.target)+')';
               Message1(unit_u_ppu_invalid_target,system_name,@queuecomment);
               exit;
             end;
           result:=true;
        end;

      function checkextraheader: boolean;
        begin
          result:=false;
          if ppufile.readentry<>ibextraheader then
            begin
              Message(unit_u_ppu_invalid_header);
              exit;
            end;
          readextraheader;
          if (longversion<>CurrentPPULongVersion) or
             not ppufile.EndOfEntry then
            begin
              Message2(unit_u_ppu_invalid_long_version,ToStr(longversion),ToStr(CurrentPPULongVersion),@queuecomment);
              exit;
            end;

          if {$ifdef symansistr}not{$endif}(mf_symansistr in moduleflags) then
            begin
              Message(unit_u_ppu_symansistr_mismatch,@queuecomment);
              exit;
            end;
           { Every unit, including released RTL/package units, must match the
             compiler invocation's default text model. }
           if (mf_unicode_default in moduleflags) <> CompilerWide_Unicode_Strings then
             begin
               Comment(VNormal,
                 'PPU default text model does not match this compiler invocation');
               exit;
             end;
          { A profiling build may use an ordinary PPU, producing deliberately
            gapped coverage. An ordinary build must never reuse an instrumented
            PPU because that would retain profiler hooks. }
          if (ModuleName^<>'SYSINIT') and
             (ModuleName^<>'OBJPAS') and
             not(mf_release in moduleflags) and
             not(mf_system_unit in moduleflags) and
             (mf_nexus_profile in moduleflags) and
             not(cs_nexus_profile in CurrentSettings.ModuleSwitches) then
            begin
              Comment(VNormal,
                'PPU profiling state does not match the current Nexus profiling build');
              exit;
            end;
          result:=true;
        end;

      begin
        openppu:=false;
        if not checkheader or
           not checkextraheader then
          begin
            discardppu;
            exit;
          end;

      { Load values for easier access }
        headerflags:=ppufile.header.common.flags;
        crc:=ppufile.header.checksum;
        crc_final:=true;
        interface_crc:=ppufile.header.interface_checksum;
        indirect_crc:=ppufile.header.indirect_checksum;
        ChangeEndian:=ppufile.ChangeEndian;
      { Show Debug info }
        if ppufiletime<>-1 then
          Message1(unit_u_ppu_time,FileTimeString(ppufiletime))
        else
          Message1(unit_u_ppu_time,'unknown');
        Message1(unit_u_ppu_flags,ToStr(headerflags));
        Message1(unit_u_ppu_crc,HexStr(ppufile.header.checksum,8));
        Message1(unit_u_ppu_crc,HexStr(ppufile.header.interface_checksum,8)+' (intfc)');
        Message1(unit_u_ppu_crc,HexStr(ppufile.header.indirect_checksum,8)+' (indc)');
        Comment(VUsed,'Number of definitions: '+ToStr(ppufile.header.deflistsize));
        Comment(VUsed,'Number of symbols: '+ToStr(ppufile.header.symlistsize));
        openppu:=true;
      end;


    function TPPUModule.search_unit_files(loaded_from : TModule; onlysource:boolean):TAvailableUnitFiles;
      var
        found : TAvailableUnitFiles;
      begin
        found:=search_unit(loaded_from,onlysource,false);
        if (found=[]) and
           (ft83 in AllowedFilenameTransFormations) and
           (length(ModuleName^)>8) then
           found:=search_unit(loaded_from,onlysource,true);
        search_unit_files:=found;
      end;

    function TPPUModule.search_unit(loaded_from : TModule; onlysource,shortname:boolean):TAvailableUnitFiles;
      var
         singlepathstring,
         FileName : TCmdStr;

         Function UnitExists(const ext:string;var foundfile:TCmdStr;const prefix:TCmdStr):boolean;
         var
           s : TCmdStr;
         begin
           if CheckVerbosity(VTried) then
             Message1(unit_t_unitsearch,Singlepathstring+FileName+ext);
           s:=FileName+ext;
           if prefix<>'' then
             s:=prefix+'.'+s;
           UnitExists:=FindFile(s,Singlepathstring,true,foundfile);
         end;

         Function PPUSearchPath(const s,prefix:TCmdStr):boolean;
         var
           found : boolean;
           hs,
           newname : TCmdStr;
         begin
           Found:=false;
           singlepathstring:=FixPath(s,false);
         { Check for PPU file }
           Found:=UnitExists(TargetInfo.unitext,hs,prefix);
           if Found then
            Begin
              SetFileName(hs,false);
              if prefix<>'' then
                begin
                  newname:=prefix+'.'+RealModuleName^;
                  StringDispose(RealModuleName);
                  RealModuleName:=StringDup(newname);
                  StringDispose(ModuleName);
                  ModuleName:=StringDup(upper(newname));
                end;
              Found:=openppufile;
            End;
           PPUSearchPath:=Found;
         end;

         Function SourceSearchPath(const s,prefix:TCmdStr):boolean;
         var
           found   : boolean;
           hs,
           newname : TCmdStr;
         begin
           Found:=false;
           singlepathstring:=FixPath(s,false);
         { Check for Sources }
           ppufile:=nil;
           recompile_reason:=rr_noppu;
         { Check for Pascal source }
           Found:=UnitExists(SourceExt,hs,prefix);
           if not Found and
              ((m_mac in CurrentSettings.ModeSwitches) or
               (tf_p_ext_support in TargetInfo.flags)) then
            begin
              { Check for .p, if mode is macpas}
              Found:=UnitExists(pext,hs,prefix);
            end;
           MainSource:='';
           if Found then
            begin
              SourcesAvail:=true;
              { Load Filenames when found }
              MainSource:=hs;
              SetFileName(hs,false);
              if prefix<>'' then
                begin
                  newname:=prefix+'.'+RealModuleName^;
                  StringDispose(RealModuleName);
                  RealModuleName:=StringDup(newname);
                  StringDispose(ModuleName);
                  ModuleName:=StringDup(upper(newname));
                end;
            end
           else
            SourcesAvail:=false;
           SourceSearchPath:=Found;
         end;

         Function SearchPath(const s,prefix:TCmdStr):TAvailableUnitFiles;
         var
           found : TAvailableUnitFiles;
         begin
           { First check for a ppu, then for the source }
           found:=[];
           if not onlysource then
             if PPUSearchPath(s,prefix) then
               Include(found,auPPU);
           if found=[] then
             if SourceSearchPath(s,prefix) then
              Include(found,auSrc);
           SearchPath:=found;
         end;

         Function SearchPathList(list:TSearchPathList;const prefix:TCmdStr):TAvailableUnitFiles;
         var
           hp : TCmdStrListItem;
           found : TAvailableUnitFiles;
         begin
           found:=[];
           hp:=TCmdStrListItem(list.First);
           while Assigned(hp) do
            begin
              found:=SearchPath(hp.Str,prefix);
              if found<>[] then
               break;
              hp:=TCmdStrListItem(hp.next);
            end;
           SearchPathList:=found;
         end;

         function SearchPPUPaths(const prefix:TCmdStr):boolean;
         begin
           result:=PPUSearchPath('.',prefix);
           if (not result) and (OutputPath<>'') then
            result:=PPUSearchPath(OutputPath,prefix);
           if (not result) and Assigned(main_module) and (main_module.Path<>'')  then
            result:=PPUSearchPath(main_module.Path,prefix);
         end;

         function SearchSourcePaths(const prefix:TCmdStr):TAvailableUnitFiles;
         begin
           result:=[];
           if SourceSearchPath('.',prefix) then
              include(Result,auSrc);
           if (result=[]) and Assigned(main_module) and (main_module.Path<>'') then
             if SourceSearchPath(main_module.Path,prefix) then
              include(Result,auSrc);
           if (result=[]) and Assigned(loaded_from) then
             result:=SearchPathList(loaded_from.LocalUnitSearchPath,prefix);
           if (result=[]) then
             result:=SearchPathList(UnitSearchPath,prefix);
         end;

         function SearchNamespaceList(const prefixes:TCmdStrList): TAvailableUnitFiles;
         var
           nsitem : TCmdStrListItem;
           res : TAvailableUnitFiles;
         begin
           res:=[];
           nsitem:=TCmdStrListItem(prefixes.first);
           while Assigned(nsitem) do
             begin
               if not onlysource then
                 begin
                   if SearchPPUPaths(nsitem.str) then
                     Include(res,auPPU);
                   if res<>[] then
                     break;
                 end;
               res:=SearchSourcePaths(nsitem.str);
               if res<>[] then
                 break;
               nsitem:=TCmdStrListItem(nsitem.next);
             end;
           if Assigned(nsitem) then
             nsprefix:=nsitem.str;
           result:=res;
         end;


       var
         fnd : TAvailableUnitFiles;
         hs : TPathStr;
       begin
         fnd:=[];
         if shortname then
           FileName:=FixFileName(Copy(RealModuleName^,1,8))
         else
           FileName:=FixFileName(RealModuleName^);
         { try to find unit
            1. look for ppu in cwd
            2. look for ppu in outputpath if set, this is tp7 compatible (PFV)
            3. look for ppu in maindir
            4. look for the specified source file (from the uses line)
            5. look for source in cwd
            6. look for source in maindir
            7. local unit pathlist
            8. global unit pathlist
            9. for each default namespace:
                  repeat 1 - 3 and 5 - 8 with namespace as prefix }
         if not onlysource then
           if SearchPPUPaths('') then
             include(fnd,auPPU);
         if (fnd=[]) and (sourcefn<>'') then
          begin
            { the full filename is specified so we can't use here the
              searchpath (PFV) }
            if CheckVerbosity(VTried) then
              Message1(unit_t_unitsearch,ChangeFileExt(sourcefn,SourceExt));
            if FindFile(ChangeFileExt(sourcefn,SourceExt),'',true,hs) then
              include(fnd,auSrc);
            if (fnd=[]) and
               ((m_mac in CurrentSettings.ModeSwitches) or
                (tf_p_ext_support in TargetInfo.flags)) then
             begin
               if CheckVerbosity(VTried) then
                 Message1(unit_t_unitsearch,ChangeFileExt(sourcefn,pext));
               if FindFile(ChangeFileExt(sourcefn,pext),'',true,hs) then
                include(fnd,auSrc)
             end;
            if [auSrc]=fnd then
             begin
               SourcesAvail:=true;
               {$IFDEF DEBUG_PPU_CYCLES}
               WriteLn('PPUALGO tppumodule.search_unit only sources, no ppu -> ',ModuleName^,' old=',state,' new=',ms_compile);
               {$ENDIF}
               state:=ms_compile;
               recompile_reason:=rr_noppu;
               MainSource:=hs;
               SetFileName(hs,false);
             end;
          end;
         if fnd=[] then
           begin
             fnd:=SearchSourcePaths('');
             // current_namespacelist is set to the current module's namespacelist.
             if (fnd=[]) and Assigned(CurrentNamespaceList) and (CurrentNamespaceList.count>0) then
               fnd:=SearchNameSpaceList(CurrentNamespaceList);
             if (fnd=[]) and (NamespaceList.count>0) then
               fnd:=SearchNameSpaceList(NamespaceList);
           end;
         search_unit:=fnd;
      end;

    function TPPUModule.loadfrompackage: boolean;
      (*var
        singlepathstring,
        filename : TCmdStr;

        Function UnitExists(const ext:string;var foundfile:TCmdStr):boolean;
          begin
            if CheckVerbosity(V_Tried) then
              Message1(unit_t_unitsearch,Singlepathstring+filename);
            UnitExists:=FindFile(FileName,Singlepathstring,true,foundfile);
          end;

        Function PPUSearchPath(const s:TCmdStr):boolean;
          var
            found : boolean;
            hs    : TCmdStr;
          begin
            Found:=false;
            singlepathstring:=FixPath(s,false);
          { Check for PPU file }
            Found:=UnitExists(target_info.unitext,hs);
            if Found then
             Begin
               SetFileName(hs,false);
               //Found:=OpenPPU;
             End;
            PPUSearchPath:=Found;
          end;

        Function SearchPathList(list:TSearchPathList):boolean;
          var
            hp : TCmdStrListItem;
            found : boolean;
          begin
            found:=false;
            hp:=TCmdStrListItem(list.First);
            while assigned(hp) do
             begin
               found:=PPUSearchPath(hp.Str);
               if found then
                break;
               hp:=TCmdStrListItem(hp.next);
             end;
            SearchPathList:=found;
          end;*)

      var
        pkg : PPackageEntry;
        pkgunit : PContainedUnit;
        i,idx : LongInt;
      begin
        result:=false;
        for i:=0 to PackageList.count-1 do
          begin
            pkg:=PPackageEntry(PackageList[i]);
            if not Assigned(pkg^.package) then
              InternalError(2013053103);
            idx:=pkg^.package.ContainedModules.FindIndexOf(ModuleName^);
            if idx>=0 then
              begin
                { the unit is part of this package }
                pkgunit:=PContainedUnit(pkg^.package.ContainedModules[idx]);
                if not Assigned(pkgunit^.module) then
                  pkgunit^.module:=self;
                { ToDo: check whether we really don't need this anymore }
                {filename:=pkgunit^.ppufile;
                if not SearchPathList(unitsearchpath) then
                  exit};
                packageppustream:=TPCPPackage(pkg^.package).GetModuleStream(self);
                if not Assigned(packageppustream) then
                  InternalError(2015103002);
                if not openppustream(packageppustream) then
                  exit;
                package:=pkg^.package;
                Message2(unit_u_loading_from_package,ModuleName^,pkg^.package.PackageName^);

                { Package PPUs use the same resumable dependency loading as
                  ordinary PPUs. Dependencies need not be ready yet. }
                state:=ms_load;
                FromPPU:=true;
                load_interface;

                result:=true;
                break;
              end;
          end;
      end;


    procedure TPPUModule.buildderefunitimportsyms;
      { called by writeppu }
      var
        i : LongInt;
        deref : PDeref;
        importsym: TUnitImportSym;
      begin
        unitimportsymsderefs.capacity:=unitimportsymsderefs.count+unitimportsyms.count;
        for i:=0 to unitimportsyms.count-1 do
          begin
            importsym:=TUnitImportSym(unitimportsyms[i]);
            new(deref);
            deref^.build(importsym.sym);
            unitimportsymsderefs.add(deref);
          end;
      end;


    procedure TPPUModule.derefunitimportsyms;
      { called at end of loading a ppu }
      var
        i : LongInt;
        sym : TSym;
      begin
        unitimportsyms.capacity:=unitimportsyms.count+unitimportsymsderefs.count;
        for i:=0 to unitimportsymsderefs.count-1 do
          begin
            sym:=TSym(PDeref(unitimportsymsderefs[i])^.resolve);
            addimportedsym(sym,false);
          end;
      end;

    procedure TPPUModule.freederefunitimportsyms;
      var
        i : LongInt;
        deref : PDeref;
      begin
        for i:=0 to unitimportsymsderefs.count-1 do
          begin
            deref:=PDeref(unitimportsymsderefs[i]);
            system.dispose(deref);
          end;
      end;

{**********************************
    PPU Reading/Writing Helpers
***********************************}

{$IFDEF MACRO_DIFF_HINT}
    var
      IsInitial: Boolean;

    procedure TPPUModule.writeusedmacro(p:TNamedIndexItem;arg:pointer);
      begin
        if TMacro(p).is_used or IsInitial then
          begin
            ppufile.putstring(p.name);
            ppufile.putboolean(IsInitial);
            ppufile.putboolean(TMacro(p).is_used);
          end;
      end;

    procedure TPPUModule.writeusedmacros;
      var
        oldcrc : boolean;
      begin
        oldcrc:=ppufile.DoCRC;
        ppufile.DoCRC:=false;
        IsInitial:= true;
        initialmacrosymtable.foreach(@writeusedmacro,nil);
        IsInitial:= false;
        if Assigned(GlobalMacroSymTable) then
          GlobalMacroSymTable.foreach(@writeusedmacro,nil);
        localmacrosymtable.foreach(@writeusedmacro,nil);
        ppufile.writeentry(ibusedmacros);
        ppufile.DoCRC:=oldcrc;
      end;
{$ENDIF}

    procedure TPPUModule.writesourcefiles;
      var
        hp  : TInputFile;
        ifile : sizeint;
        oldcrc : boolean;
      begin
      { write the used source files }
        oldcrc:=ppufile.DoCRC;
        ppufile.DoCRC:=false;
      { write source files directly in good order }
        for ifile:=0 to SourceFiles.nfiles-1 do
          begin
            hp:=SourceFiles.files[ifile];
            ppufile.putstring(hp.IncPath+hp.name);
            ppufile.putlongint(hp.GetFileTime);
         end;
        ppufile.writeentry(ibsourcefiles);
        ppufile.DoCRC:=oldcrc;
      end;


    procedure TPPUModule.writeusedunit(intf:boolean);
      var
        hp : TUsedUnit;
        oldcrc : boolean;
        u: TModule;
      begin
        { write a reference for each used unit }
        hp:=TUsedUnit(used_units.first);
        while Assigned(hp) do
         begin
           if hp.in_interface=intf then
             begin
               u:=hp.u;
               ppufile.putstring(u.RealModuleName^);
               { the checksum should not affect the crc of this unit ! (PFV) }
               oldcrc:=ppufile.DoCRC;
               ppufile.DoCRC:=false;
               hp.checksum:=u.crc;
               hp.interface_checksum:=u.interface_crc;
               hp.indirect_checksum:=u.indirect_crc;
               ppufile.putlongint(LongInt(hp.checksum));
               ppufile.putlongint(LongInt(hp.interface_checksum));
               ppufile.putlongint(LongInt(hp.indirect_checksum));
               ppufile.DoCRC:=oldcrc;
               { Combine all indirect checksums from units used by this unit.
                 The indirect_crc contains the classes+records of this unit as well. }
               if intf then
                 ppufile.indirect_crc:=UpdateCRC32(ppufile.indirect_crc,u.indirect_crc,sizeof(u.indirect_crc));
             end;
           hp:=TUsedUnit(hp.next);
         end;
        ppufile.writeentry(ibloadunit);
      end;


    procedure TPPUModule.writelinkcontainer(var p:TLinkContainer;id:byte;strippath:boolean);
      var
        hcontainer : TLinkContainer;
        s : TPathStr;
        mask : cardinal;
      begin
        hcontainer:=TLinkContainer.Create;
        while not p.empty do
         begin
           s:=p.get(mask);
           if strippath then
            ppufile.putstring(ExtractFileName(s))
           else
            ppufile.putstring(s);
           ppufile.putlongint(mask);
           hcontainer.add(s,mask);
         end;
        ppufile.writeentry(id);
        p.Free;
        p:=hcontainer;
      end;


    procedure TPPUModule.writederefmap;
      var
        i : LongInt;
        oldcrc : boolean;
      begin
        { This does not influence crc }
        oldcrc:=ppufile.DoCRC;
        ppufile.DoCRC:=false;
        { The unit map used for resolving }
        ppufile.putlongint(derefmapcnt);
        for i:=0 to derefmapcnt-1 do
          begin
            if not Assigned(derefmap[i].u) then
              InternalError(2005011512);
            ppufile.putstring(derefmap[i].u.ModuleName^)
          end;
        ppufile.writeentry(ibderefmap);
        ppufile.DoCRC:=oldcrc;
      end;


    procedure TPPUModule.writederefdata;
      var
        oldcrc : boolean;
        len,hlen : LongInt;
        buf : array[0..1023] of byte;
      begin
        if LongWord(derefdataintflen)>derefdata.size then
          InternalError(200310223);
        derefdata.seek(0);
        { Write interface data }
        len:=derefdataintflen;
        while (len>0) do
          begin
            if len>1024 then
              hlen:=1024
            else
              hlen:=len;
            derefdata.read(buf,hlen);
            ppufile.putdata(buf,hlen);
            dec(len,hlen);
          end;
        { Write implementation data, this does not influence crc }
        oldcrc:=ppufile.DoCRC;
        ppufile.DoCRC:=false;
        len:=derefdata.size-derefdataintflen;
        while (len>0) do
          begin
            if len>1024 then
              hlen:=1024
            else
              hlen:=len;
            derefdata.read(buf,hlen);
            ppufile.putdata(buf,hlen);
            dec(len,hlen);
          end;
        if derefdata.pos<>derefdata.size then
          InternalError(200310224);
        ppufile.DoCRC:=oldcrc;
        ppufile.writeentry(ibderefdata);
      end;


    procedure TPPUModule.writeImportSymbols;
      var
        i,j : LongInt;
        ImportLibrary : TImportLibrary;
        ImportSymbol  : TImportSymbol;
      begin
        for i:=0 to ImportLibraryList.Count-1 do
          begin
            ImportLibrary:=TImportLibrary(ImportLibraryList[i]);
            ppufile.putstring(ImportLibrary.Name);
            ppufile.putlongint(ImportLibrary.ImportSymbolList.Count);
            for j:=0 to ImportLibrary.ImportSymbolList.Count-1 do
              begin
                ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList[j]);
                ppufile.putstring(ImportSymbol.Name);
                ppufile.putstring(ImportSymbol.MangledName);
                ppufile.putlongint(ImportSymbol.OrdNr);
                ppufile.putbyte(byte(ImportSymbol.IsVar));
              end;
          end;
        ppufile.writeentry(ibImportSymbols);
      end;


    procedure TPPUModule.writeResources;
      var
        res : TCmdStrListItem;
      begin
        res:=TCmdStrListItem(ResourceFiles.First);
        while res<>nil do
          begin
            ppufile.putstring(res.FPStr);
            res:=TCmdStrListItem(res.Next);
          end;
        ppufile.writeentry(ibresources);
      end;


    procedure TPPUModule.writeOrderedSymbols;
      var
        res : TCmdStrListItem;
      begin
        res:=TCmdStrListItem(linkorderedsymbols.First);
        while res<>nil do
          begin
            ppufile.putstring(res.FPStr);
            res:=TCmdStrListItem(res.Next);
          end;
        ppufile.writeentry(iborderedsymbols);
      end;


    procedure TPPUModule.writeUnitExports;
      var
        hp : TExportedItem;
        option : TExportOption;
        flags : byte;
      begin
        { Optional metadata: units without exports retain the existing format. }
        if not (TargetInfo.system in (systems_windows+systems_linux)) or
           not Assigned(_exports.first) then
          exit;
        hp:=TExportedItem(_exports.first);
        while Assigned(hp) do
          begin
            ppufile.putstring(hp.name^);
            ppufile.putstring(hp.internalname);
            ppufile.putlongint(hp.index);
            flags:=0;
            for option:=low(TExportOption) to high(TExportOption) do
              if option in hp.options then
                flags:=flags or (1 shl ord(option));
            ppufile.putbyte(flags);
            ppufile.putbyte(ord(hp.is_var));
            hp:=TExportedItem(hp.next);
          end;
        ppufile.writeentry(ibunitexports);
      end;


    procedure TPPUModule.writeunitimportsyms;
      var
        i : LongInt;
      begin
        ppufile.putlongint(unitimportsymsderefs.count);
        for i:=0 to unitimportsymsderefs.count-1 do
          ppufile.putderef(PDeref(unitimportsymsderefs[i])^);
        ppufile.writeentry(ibunitimportsyms);
      end;


    procedure TPPUModule.writeasmsyms(kind:TUnitAsmListType;list:TFPHashObjectList);
      var
        i : LongInt;
        sym : TAsmSymbol;
      begin
        ppufile.putbyte(ord(kind));
        ppufile.putlongint(list.count);
        for i:=0 to list.count-1 do
          begin
            sym:=TAsmSymbol(list[i]);
            ppufile.putstring(sym.Name);
            ppufile.putbyte(ord(sym.bind));
            ppufile.putbyte(ord(sym.typ));
          end;
        ppufile.writeentry(ibasmsymbols);
      end;

    procedure TPPUModule.writeextraheader;
      var
        old_docrc: boolean;
      begin
        { create unit flags }
        if Do_Release then
          include(moduleflags,mf_release);
        if Assigned(localsymtable) then
          include(moduleflags,mf_local_symtable);
        if cs_checkpointer_called in CurrentSettings.ModuleSwitches then
          include(moduleflags,mf_checkpointer_called);
        if cs_compilesystem in CurrentSettings.ModuleSwitches then
          include(moduleflags,mf_system_unit);
        if cs_nexus_profile in CurrentSettings.ModuleSwitches then
          include(moduleflags,mf_nexus_profile);
         if CompilerWide_Unicode_Strings then
           include(moduleflags,mf_unicode_default);


{$ifdef symansistr}
        include(moduleflags,mf_symansistr);
{$endif}

        old_docrc:=ppufile.DoCRC;
        ppufile.DoCRC:=false;
        ppufile.putlongint(LongInt(CurrentPPULongVersion));
        ppufile.putset(TPPUSet4(moduleflags));
        ppufile.writeentry(ibextraheader);
        ppufile.DoCRC:=old_docrc;
      end;


{$IFDEF MACRO_DIFF_HINT}

{
  Define MACRO_DIFF_HINT for the whole compiler (and ppudump)
  to turn this facility on. Also the hint messages defined
  below must be commented in in the msg/errore.msg file.

  There is some problems with this, thats why it is shut off:

  At the first compilation, consider a macro which is not initially
  defined, but it is used (e g the check that it is undefined is true).
  Since it do not exist, there is no macro object where the is_used
  flag can be set. Later on when the macro is defined, and the ppu
  is opened, the check cannot detect this.

  Also, in which macro object should this flag be set ? It cant be set
  for macros in the initialmacrosymboltable since this table is shared
  between different files.
}

    procedure TPPUModule.readusedmacros;
      var
        hs : string;
        mac : TMacro;
        was_initial,
        was_used : boolean;
      {Reads macros which was defined or used when the module was compiled.
       This is done when a ppu file is open, before it possibly is parsed.}
      begin
        while not ppufile.endofentry do
         begin
           hs:=ppufile.getstring;
           was_initial:=ppufile.getboolean;
           was_used:=ppufile.getboolean;
           mac:=TMacro(initialmacrosymtable.Find(hs));
           if Assigned(mac) then
             begin
{$ifndef EXTDEBUG}
           { if we don't have the sources why tell }
              if SourcesAvail then
{$endif ndef EXTDEBUG}
               if (not was_initial) and was_used then
                Message2(unit_h_cond_not_set_in_last_compile,hs,MainSource^);
             end
           else { not assigned }
             if was_initial and
                was_used then
              Message2(unit_h_cond_set_in_last_compile,hs,MainSource^);
         end;
      end;
{$ENDIF}

    procedure TPPUModule.readsourcefiles;
      var
        temp,hs       : string;
        IncPath      : string;
        temp_dir      : TCmdStr;
        main_dir      : TCmdStr;
        found,
        is_main       : boolean;
        orgfiletime,
        source_time   : LongInt;
        hp            : TInputFile;
      begin
        SourcesAvail:=not(mf_release in moduleflags);
        is_main:=true;
        main_dir:='';
        while not ppufile.endofentry do
         begin
           hs:=SetDirSeparators(ppufile.getstring);
           IncPath:=ExtractFilePath(hs);
           orgfiletime:=ppufile.getlongint;
           temp_dir:='';
           if SourcesAvail then
             begin
               if (headerflags and uf_in_library)<>0 then
                begin
                  SourcesAvail:=false;
                  temp:=' library';
                end
               else if pos('Macro ',hs)=1 then
                begin
                  { we don't want to find this file }
                  { but there is a problem with file indexing !! }
                  temp:='';
                end
               else
                begin
                  { check the date of the source files:
                     1 path of sourcefn
                     2 path of ppu
                     3 path of main source
                     4 current dir
                     5 include/unit path }
                  found:=false;
                  if sourcefn<>'' then
                  begin
                    temp_dir:=ExtractFilePath(SetDirSeparators(sourcefn));
                    Source_Time:=GetNamedFileTime(temp_dir+hs);
                    if Source_Time<>-1 then
                      hs:=temp_dir+hs;
                  end else
                    Source_Time:=-1;
                  if Source_Time=-1 then
                    begin
                      Source_Time:=GetNamedFileTime(path+hs);
                      if Source_Time<>-1 then
                        hs:=path+hs
                      else
                       if not(is_main) then
                        begin
                          Source_Time:=GetNamedFileTime(main_dir+hs);
                          if Source_Time<>-1 then
                            hs:=main_dir+hs;
                        end;
                    end;
                  if Source_Time=-1 then
                    Source_Time:=GetNamedFileTime(hs);
                  if (Source_Time=-1) then
                    begin
                      if is_main then
                        found:=UnitSearchPath.FindFile(hs,true,temp_dir)
                      else
                        found:=IncludeSearchPath.FindFile(hs,true,temp_dir);
                      if found then
                       begin
                         Source_Time:=GetNamedFileTime(temp_dir);
                         if Source_Time<>-1 then
                          hs:=temp_dir;
                       end;
                    end;
                  if Source_Time<>-1 then
                    begin
                      if is_main then
                        main_dir:=ExtractFilePath(hs);
                      temp:=' time '+FileTimeString(source_time);
                      if (orgfiletime<>-1) and
                         (source_time<>orgfiletime) then
                        begin
                          {$IFDEF DEBUG_PPU_CYCLES}
                          WriteLn('PPUALGO tppumodule.readsourcefiles sourcechanged ',ModuleName^,' old=',state,' new=',ms_compile);
                          {$ENDIF}
                          state:=ms_compile;
                          recompile_reason:=rr_sourcenewer;
                          Message2(unit_u_source_modified,hs,PPUFileName,@queuecomment);
                          temp:=temp+' *';
                        end;
                    end
                  else
                    begin
                      SourcesAvail:=false;
                      temp:=' not found';
                    end;
                  hp:=TDOSInputFile.create(hs);
                  hp.IncPath:=IncPath;
                  { the indexing is wrong here PM }
                  SourceFiles.Register_File(hp);
                end;
             end
           else
             begin
               { still register the source module for proper error messages
                 since source_avail for the module is still false, this should not hurt }
               SourceFiles.Register_File(TDOSInputFile.create(hs));

               temp:=' not available';
             end;
           if is_main then
             begin
               MainSource:=hs;
             end;
           Message1(unit_u_ppu_source,hs+temp,@queuecomment);
           is_main:=false;
         end;
      { check if we want to rebuild every unit, only if the sources are
        available }
        if Do_Build and SourcesAvail then
          begin
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tppumodule.readsourcefiles do_build ',ModuleName^,' old=',state,' new=',ms_compile);
            {$ENDIF}
            state:=ms_compile;
            recompile_reason:=rr_build;
          end;
      end;


    procedure TPPUModule.readloadunit;
      var
        hs : string;
        pu : TUsedUnit;
        hp : TPPUModule;
        indchecksum,
        intfchecksum,
        checksum : cardinal;
        isnew : boolean;

      begin
        while not ppufile.endofentry do
         begin
           hs:=ppufile.getstring;
           checksum:=cardinal(ppufile.getlongint);
           intfchecksum:=cardinal(ppufile.getlongint);
           indchecksum:=cardinal(ppufile.getlongint);
           { set the state of this unit before registering, this is
             needed for a correct circular dependency check }
           hp:=registerunit(self,hs,'',isnew);
           if isnew then
             UsedUnits.Concat(TUsedUnit.create(hp,in_interface,true,nil));
           pu:=findusedunit(hp);
           if pu=nil then
             pu:=addusedunit(hp,false,nil);
           pu.checksum:=checksum;
           pu.interface_checksum:=intfchecksum;
           pu.indirect_checksum:=indchecksum;
         end;
        in_interface:=false;
      end;


    procedure TPPUModule.readlinkcontainer(var p:TLinkContainer);
      var
        s : string;
        m : LongInt;
      begin
        while not ppufile.endofentry do
         begin
           s:=ppufile.getstring;
           m:=ppufile.getlongint;
           p.add(s,m);
         end;
      end;


    procedure TPPUModule.readderefmap;
      var
        i : LongInt;
      begin
        { Load unit map used for resolving }
        derefmapsize:=ppufile.getlongint;
        derefmapcnt:=derefmapsize;
        SetLength(derefmap,derefmapsize);
        for i:=0 to derefmapsize-1 do
          derefmap[i].ModuleName:=ppufile.getpshortstring;
      end;


    procedure TPPUModule.readderefdata;
      var
        len,hlen : LongInt;
        buf : array[0..1023] of byte;
      begin
        len:=ppufile.entrysize;
        while (len>0) do
          begin
            if len>1024 then
              hlen:=1024
            else
              hlen:=len;
            ppufile.getdata(buf,hlen);
            derefdata.write(buf,hlen);
            dec(len,hlen);
          end;
      end;


    procedure TPPUModule.readImportSymbols;
      var
        j,
        extsymcnt   : LongInt;
        ImportLibrary  : TImportLibrary;
        extsymname  : string;
        extsymmangledname : string;
        extsymordnr : LongInt;
        extsymisvar : boolean;
      begin
        while not ppufile.endofentry do
          begin
            ImportLibrary:=TImportLibrary.Create(ImportLibraryList,ppufile.getstring);
            extsymcnt:=ppufile.getlongint;
            for j:=0 to extsymcnt-1 do
              begin
                extsymname:=ppufile.getstring;
                extsymmangledname:=ppufile.getstring;
                extsymordnr:=ppufile.getlongint;
                extsymisvar:=(ppufile.getbyte<>0);
                TImportSymbol.Create(ImportLibrary.ImportSymbolList,extsymname,
                  extsymmangledname,extsymordnr,extsymisvar);
              end;
          end;
      end;


    procedure TPPUModule.readResources;
      begin
        while not ppufile.endofentry do
          resourcefiles.Insert(ppufile.getstring);
      end;


    procedure TPPUModule.readOrderedSymbols;
      begin
        while not ppufile.endofentry do
          linkorderedsymbols.Concat(ppufile.getstring);
      end;


    procedure TPPUModule.readUnitExports;
      var
        hp : TExportedItem;
        option : TExportOption;
        flags : byte;
      begin
        while not ppufile.endofentry do
          begin
            hp:=TExportedItem.create;
            hp.name:=StringDup(ppufile.getstring);
            hp.internalname:=ppufile.getstring;
            hp.index:=ppufile.getlongint;
            flags:=ppufile.getbyte;
            for option:=low(TExportOption) to high(TExportOption) do
              if flags and (1 shl ord(option))<>0 then
                include(hp.options,option);
            hp.is_var:=ppufile.getbyte<>0;
            _exports.concat(hp);
          end;
      end;


    procedure TPPUModule.readwpofile;
      var
        orgwpofilename: string;
        orgwpofiletime: LongInt;
      begin
        { check whether we are using the same wpo feedback input file as when
          this unit was compiled (same file name and file date)
        }
        orgwpofilename:=ppufile.getstring;
        orgwpofiletime:=ppufile.getlongint;
        if (extractfilename(orgwpofilename)<>extractfilename(WPOFeedbackInput)) or
           (orgwpofiletime<>GetNamedFileTime(orgwpofilename)) then
          { make sure we don't throw away a precompiled unit if the user simply
            forgot to specify the right wpo feedback file
          }
          message3(unit_e_different_wpo_file,PPUFileName,orgwpofilename,FileTimeString(orgwpofiletime));
      end;


    procedure TPPUModule.readunitimportsyms;
      var
        c,i : LongInt;
        deref : PDeref;
      begin
        c:=ppufile.getlongint;
        for i:=0 to c-1 do
          begin
            new(deref);
            ppufile.getderef(deref^);
            unitimportsymsderefs.add(deref);
          end;
      end;


    procedure TPPUModule.readasmsyms;
      var
        c,i : LongInt;
        name : TSymStr;
        bind : TAsmsymbind;
        typ : TAsmsymtype;
        list : TFPHashObjectList;
      begin
        case TUnitAsmListType(ppufile.getbyte) of
          ualt_public:
            list:=publicasmsyms;
          ualt_extern:
            list:=externasmsyms;
        end;
        c:=ppufile.getlongint;
        for i:=0 to c-1 do
          begin
            name:=ppufile.getstring;
            bind:=TAsmsymbind(ppufile.getbyte);
            typ:=TAsmsymtype(ppufile.getbyte);
            TAsmSymbol.Create(list,name,bind,typ);
          end;
      end;


    procedure TPPUModule.readextraheader;
      begin
        longversion:=cardinal(ppufile.getlongint);
        ppufile.getset(TPPUSet4(moduleflags));
      end;


    procedure TPPUModule.load_interface;
      var
        b : byte;
        newmodulename : string;
      begin
       { read interface part }
         repeat
           b:=ppufile.readentry;
           case b of
             ibjvmnamespace :
               begin
                 namespace:=ppufile.getpshortstring;
               end;
             ibmodulename :
               begin
                 newmodulename:=ppufile.getstring;
                 if (cs_check_unit_name in CurrentSettings.GlobalSwitches) and
                    (upper(newmodulename)<>ModuleName^) then
                   Message2(unit_f_unit_name_error,RealModuleName^,newmodulename);
                 StringDispose(ModuleName);
                 StringDispose(RealModuleName);
                 ModuleName:=StringDup(upper(newmodulename));
                 RealModuleName:=StringDup(newmodulename);
               end;
             ibextraheader:
               begin
                 readextraheader;
               end;
             ibfeatures :
               begin
                 ppufile.getset(TPPUSet4(Features));
               end;
             ibmoduleoptions:
               begin
                 ppufile.getset(TPPUSet1(moduleoptions));
                 if mo_has_deprecated_msg in moduleoptions then
                   begin
                     StringDispose(deprecatedmsg);
                     deprecatedmsg:=ppufile.getpshortstring;
                   end;
               end;
             ibsourcefiles :
               readsourcefiles;
{$IFDEF MACRO_DIFF_HINT}
             ibusedmacros :
               readusedmacros;
{$ENDIF}
             ibloadunit :
               readloadunit;
             iblinkunitofiles :
               readlinkcontainer(LinkUnitOFiles);
             iblinkunitstaticlibs :
               readlinkcontainer(LinkUnitStaticLibs);
             iblinkunitsharedlibs :
               readlinkcontainer(LinkUnitSharedLibs);
             iblinkotherofiles :
               readlinkcontainer(LinkotherOFiles);
             iblinkotherstaticlibs :
               readlinkcontainer(LinkotherStaticLibs);
             iblinkothersharedlibs :
               readlinkcontainer(LinkotherSharedLibs);
             iblinkotherframeworks :
               readlinkcontainer(LinkOtherFrameworks);
             ibmainname:
               begin
                 mainname:=ppufile.getpshortstring;
                 if (MainAliasName<>DefaultMainAliasName) then
                   Message1(scan_w_multiple_main_name_overrides,MainAliasName);
                 MainAliasName:=mainname^;
               end;
             ibImportSymbols :
               readImportSymbols;
             ibderefmap :
               readderefmap;
             ibderefdata :
               readderefdata;
             ibresources:
               readResources;
             iborderedsymbols:
               readOrderedSymbols;
             ibunitexports:
               readUnitExports;
             ibwpofile:
               readwpofile;
             ibendinterface :
               break;
           else
             Message1(unit_f_ppu_invalid_entry,ToStr(b));
           end;
           { we can already stop when we know that we must recompile }
           if state=ms_compile then
             exit;
         until false;
      end;


    procedure TPPUModule.load_implementation;
      var
        b : byte;
      begin
         { read implementation part }
         repeat
           b:=ppufile.readentry;
           case b of
             ibloadunit :
               readloadunit;
             ibasmsymbols :
               readasmsyms;
             ibunitimportsyms:
               readunitimportsyms;
             ibendimplementation :
               break;
           else
             Message1(unit_f_ppu_invalid_entry,ToStr(b));
           end;
         until false;
      end;


    procedure TPPUModule.writeppu;
      var
        lIndex: LongInt;
        lAsmSymbols: TFPHashObjectList;
        lSymbol: TAsmSymbol;
      begin
         { A System unit built with a contradictory Char alias must never
           receive a PPU bearing the invocation's text-model flag. }
         if (cs_compilesystem in CurrentSettings.ModuleSwitches) and
            (search_system_type('CHAR').typedef.size <>
             1+Ord(CompilerWide_Unicode_Strings)) then
           Comment(VFatal,'System.Char width does not match this compiler invocation''s default text model');

         Message1(unit_u_ppu_write,RealModuleName^);

         { create unit flags }
         { create new ppufile }
         ppufile:=TCompilerPPUFile.create(PPUFileName);
         if not ppufile.createfile then
          Message(unit_f_ppu_cannot_write);


         { extra header (sub version, module flags) }
         writeextraheader;

         { first the (JVM) namespace }
         if Assigned(namespace) then
           begin
             ppufile.putstring(namespace^);
             ppufile.writeentry(ibjvmnamespace);
           end;
         { the unitname }
         ppufile.putstring(RealModuleName^);
         ppufile.writeentry(ibmodulename);

         ppufile.putset(TPPUSet1(moduleoptions));
         if mo_has_deprecated_msg in moduleoptions then
           ppufile.putstring(deprecatedmsg^);
         ppufile.writeentry(ibmoduleoptions);

         { write the alternate main procedure name if any }
         if Assigned(mainname) then
           begin
             ppufile.putstring(mainname^);
             ppufile.writeentry(ibmainname);
           end;

         if cs_compilesystem in CurrentSettings.ModuleSwitches then
           begin
             ppufile.putset(TPPUSet4(Features));
             ppufile.writeentry(ibfeatures);
           end;

         writesourcefiles;
{$IFDEF MACRO_DIFF_HINT}
         writeusedmacros;
{$ENDIF}

         { write interface uses }
         writeusedunit(true);

         { write the objectfiles and libraries that come for this unit,
           preserve the containers because they are still needed to load
           the link.res.
            All doesn't depend on the crc! It doesn't matter
           if a unit is in a .o or .a file }
         ppufile.DoCRC:=false;
         { write after source files, so that we know whether or not the compiler
           will recompile the unit when checking whether the correct wpo file is
           used (if it will recompile the unit anyway, it doesn't matter)
         }
         if (WPOFeedbackInput<>'') then
           begin
             ppufile.putstring(WPOFeedbackInput);
             ppufile.putlongint(getnamedfiletime(WPOFeedbackInput));
             ppufile.writeentry(ibwpofile);
           end;
         writelinkcontainer(linkunitofiles,iblinkunitofiles,true);
         writelinkcontainer(linkunitstaticlibs,iblinkunitstaticlibs,true);
         writelinkcontainer(linkunitsharedlibs,iblinkunitsharedlibs,true);
         writelinkcontainer(linkotherofiles,iblinkotherofiles,false);
         writelinkcontainer(linkotherstaticlibs,iblinkotherstaticlibs,true);
         writelinkcontainer(linkothersharedlibs,iblinkothersharedlibs,true);
         writelinkcontainer(linkotherframeworks,iblinkotherframeworks,true);
         writeImportSymbols;
         writeResources;
         writeOrderedSymbols;
         writeUnitExports;
         ppufile.DoCRC:=true;

         { generate implementation deref data, the interface deref data is
           already generated when calculating the interface crc }
         if (cs_compilesystem in CurrentSettings.ModuleSwitches) then
           begin
             TStoredSymTable(GlobalSymTable).buildderef;
             derefdataintflen:=derefdata.size;
           end
         else
           { the unit may have been re-resolved, in which case the current
             position in derefdata is not necessarily at the end }
            derefdata.seek(derefdata.size);
         TStoredSymTable(GlobalSymTable).buildderefimpl;
         TUnitWPOInfo(wpoinfo).buildderef;
         TUnitWPOInfo(wpoinfo).buildderefimpl;

         if Assigned(GlobalMacroSymTable) and (GlobalMacroSymTable.SymList.count > 0) then
            begin
              TStoredSymTable(GlobalMacroSymTable).buildderef;
              TStoredSymTable(GlobalMacroSymTable).buildderefimpl;
            end;

         if mf_local_symtable in moduleflags then
           TStoredSymTable(localsymtable).buildderef_registered;
         buildderefunitimportsyms;
         writederefmap;
         writederefdata;

         ppufile.writeentry(ibendinterface);

         { write the symtable entries }
         TStoredSymTable(GlobalSymTable).ppuwrite(ppufile);

         if Assigned(GlobalMacroSymTable) and (GlobalMacroSymTable.SymList.count > 0) then
           begin
             ppufile.putbyte(byte(true));
             ppufile.writeentry(ibexportedmacros);
             TStoredSymTable(GlobalMacroSymTable).ppuwrite(ppufile);
           end
         else
           begin
             ppufile.putbyte(byte(false));
             ppufile.writeentry(ibexportedmacros);
           end;

         { everything after this doesn't affect the crc }
         ppufile.DoCRC:=false;

         { write implementation uses }
         writeusedunit(false);

         { Calls and procedure addresses introduced by inlining or code
           generation need the same package import lookup as parsed calls. }
         if tf_supports_packages in TargetInfo.flags then
           begin
             lAsmSymbols:=TAsmData(asmdata).AsmSymbolDict;
             for lIndex:=0 to lAsmSymbols.Count-1 do
               begin
                 lSymbol:=TAsmSymbol(lAsmSymbols[lIndex]);
                 if lSymbol.typ<>AT_FUNCTION then
                   continue;
                 case lSymbol.bind of
                   AB_EXTERNAL:
                     add_extern_asmsym(lSymbol);
                   else
                     ;
                 end;
               end;
           end;

         { write all public assembler symbols }
         writeasmsyms(ualt_public,publicasmsyms);

         { write all external assembler symbols }
         writeasmsyms(ualt_extern,externasmsyms);

         { write all symbols imported from another unit }
         writeunitimportsyms;

         { end of implementation }
         ppufile.writeentry(ibendimplementation);

         { write static symtable
           needed for local debugging of unit functions }
         if mf_local_symtable in moduleflags then
           TStoredSymTable(localsymtable).ppuwrite(ppufile);

         { write whole program optimisation-related information }
         TUnitWPOInfo(wpoinfo).ppuwrite(ppufile);

         { the last entry ibend is written automatically }

         { flush to be sure }
         ppufile.flush;

         { save crc in current module also }
         if not crc_final then
           begin
             crc_final:=true;
             crc:=ppufile.crc;
           end;
         { create and write header }
         { Note: the interface_crc and indirect_crc were computed in getppucrc
                 after the interface was compiled. The implementation must *not* effect them. }
         ppufile.header.common.size:=ppufile.size;
         ppufile.header.checksum:=crc;
         ppufile.header.interface_checksum:=interface_crc;
         ppufile.header.indirect_checksum:=indirect_crc;
         ppufile.header.common.compiler:=WordVersion;
         ppufile.header.common.cpu:=word(TargetCPU);
         ppufile.header.common.target:=word(TargetInfo.system);
         ppufile.header.common.flags:=headerflags;
         ppufile.header.deflistsize:=CurrentModule.deflist.count;
         ppufile.header.symlistsize:=CurrentModule.symlist.count;
         ppufile.writeheader;


         discardppu;
      end;


    procedure TPPUModule.getppucrc;
      begin
         { create new ppufile }
         ppufile:=TCompilerPPUFile.create(PPUFileName);
         ppufile.crc_only:=true;
         if not ppufile.createfile then
           Message(unit_f_ppu_cannot_write);

{$ifdef DEBUG_GENERATE_INTERFACE_PPU}
        if ppufile.writing_interface_ppu then
          ppufile.crc_only:=false;
{$endif DEBUG_GENERATE_INTERFACE_PPU}
         { extra header (sub version, module flags) }
         writeextraheader;

         { first the (JVM) namespace }
         if Assigned(namespace) then
           begin
             ppufile.putstring(namespace^);
             ppufile.writeentry(ibjvmnamespace);
           end;

         { the unitname }
         ppufile.putstring(RealModuleName^);
         ppufile.writeentry(ibmodulename);

         ppufile.putset(TPPUSet1(moduleoptions));
         if mo_has_deprecated_msg in moduleoptions then
           ppufile.putstring(deprecatedmsg^);
         ppufile.writeentry(ibmoduleoptions);

         { the interface units affect the crc }
         writeusedunit(true);

         { deref data of interface that affect the crc }
         derefdata.reset;
         TStoredSymTable(GlobalSymTable).buildderef;
         derefdataintflen:=derefdata.size;
         writederefmap;
         writederefdata;

         ppufile.writeentry(ibendinterface);

         { write the symtable entries }
         TStoredSymTable(GlobalSymTable).ppuwrite(ppufile);

         if Assigned(GlobalMacroSymTable) and (GlobalMacroSymTable.SymList.count > 0) then
           begin
             ppufile.putbyte(byte(true));
             ppufile.writeentry(ibexportedmacros);
             TStoredSymTable(GlobalMacroSymTable).ppuwrite(ppufile);
           end
         else
           begin
             ppufile.putbyte(byte(false));
             ppufile.writeentry(ibexportedmacros);
           end;

         { save crc  }
         crc:=ppufile.crc;
         if in_interface then
           begin
             { Note: the interface_crc and indirect_crc are not affected by the implementation }
             interface_crc:=ppufile.interface_crc;
             indirect_crc:=ppufile.indirect_crc;
           end;
         { end of implementation, to generate a correct ppufile
           for ppudump when using DEBUG_GENERATE_INTERFACE_PPU define }
         ppufile.writeentry(ibendimplementation);


         { create and write header, this will only be used
           for debugging purposes }
         ppufile.header.common.size:=ppufile.size;
         ppufile.header.checksum:=crc;
         ppufile.header.interface_checksum:=interface_crc;
         ppufile.header.indirect_checksum:=indirect_crc;
         ppufile.header.common.compiler:=WordVersion;
         ppufile.header.common.cpu:=word(TargetCPU);
         ppufile.header.common.target:=word(TargetInfo.system);
         ppufile.header.common.flags:=headerflags;
         ppufile.writeheader;

         discardppu;
      end;

    function TPPUModule.dependent_module_has_our_crc: boolean;
      { returns true, if any dependent module has crc for this module }
      var
        pu: TDependentUnit;
        m: FModule.TModule;
      begin
        pu:=TDependentUnit(dependent_units.First);
        while Assigned(pu) do
          begin
            m:=pu.u;
            if m.FromPPU or (m.state in [ms_compiled,ms_processed]) then
              exit(true);
            pu:=TDependentUnit(pu.Next);
          end;
        Result:=false;
      end;

    function TPPUModule.dependent_module_crc_mismatch: boolean;
      { called after an interface crc or crc was computed.
        Checks if any dependent module needs a recompile.
        The compile goes back to the ctask scheduler which recompiles. }
      var
        pu: TDependentUnit;
        m: TPPUModule;
        uu: TUsedUnit;
        check_crc, used_by_interface: boolean;
      begin
        Result:=false;
        if not interface_compiled then
          InternalError(2026033101);
        pu:=TDependentUnit(dependent_units.First);
        while Assigned(pu) do
          begin
            m:=TPPUModule(pu.u);
            used_by_interface:=pu.in_interface;
            pu:=TDependentUnit(pu.Next);
            if not m.FromPPU then
              begin
                if used_by_interface then
                  begin
                    if not m.interface_compiled then continue;
                  end
                else
                  { uses by implementation }
                  case m.state of
                  ms_compiling_waitfinish,
                  ms_compiled_waitcrc:
                    ; { m has crc of its impl uses }
                  ms_compiled,
                  ms_processed:
                    InternalError(2026033111);
                  else
                    continue; { m does not yet have its impl uses crc }
                  end;
              end;

            check_crc:=crc_final and (m.FromPPU or (m.state in [ms_compiled,ms_processed]));
            uu:=TUsedUnit(m.used_units.First);
            while Assigned(uu) do
              begin
                if (uu.u=self)
                    and ( (interface_crc<>uu.interface_checksum)
                        or (indirect_crc<>uu.indirect_checksum)
                        or (check_crc and (crc<>uu.checksum) ) ) then
                  begin
                    Result:=true;
                    {$IFDEF DEBUG_PPU_CYCLES}
                    WriteLn('PPUALGO tppumodule.dependent_module_crc_mismatch ',ModuleName^,' used by ',BoolToStr(uu.in_interface,'interface','implementation'),' of "',m.ModuleName^,'" old=',m.StateStr,' new=',ms_compile);
                    {$ENDIF}
                    m.mark_recompile_needed(rr_crcchanged);
                  end;
                uu:=TUsedUnit(uu.Next);
              end;
          end;
      end;

    function TPPUModule.load_usedunits: boolean;
      { self is a ppu (or in a package) }
      begin
        Result:=true;
        if CurrentModule<>self then
          InternalError(200212284);

        if not interface_compiled then
        begin
          { load the used units from interface }
          in_interface:=true;
          if not load_usedunits_section then
            exit(false); { e.g. fail or some used unit interface is not ready }
          if CurrentModule<>self then
            InternalError(2026022317);
          { ok, now load the interface of this unit }
          if CurrentModule<>self then
            InternalError(200208187);
          deflist.count:=ppufile.header.deflistsize;
          symlist.count:=ppufile.header.symlistsize;
          GlobalSymTable:=TGlobalSymTable.create(RealModuleName^,ModuleID);
          TStoredSymTable(GlobalSymTable).ppuload(ppufile);

          if ppufile.readentry<>ibexportedmacros then
            Message(unit_f_ppu_read_error);
          if boolean(ppufile.getbyte) then
            begin
              GlobalMacroSymTable:=TMacroSymTable.Create(true);
              TStoredSymTable(GlobalMacroSymTable).ppuload(ppufile)
            end;

          interface_compiled:=true;

          { read the implementation part, containing
            the implementation uses and ObjData }
          in_interface:=false;
          load_implementation;
        end;

        { now only read the implementation uses }
        if not ppu_waitingfor_crc then
        begin
          if not load_usedunits_section then
            exit(false); { fail or some used unit interface is not ready }
          if CurrentModule<>self then
            InternalError(2026022316);
        end;

        if not ppu_waitingfor_crc then
          begin
            ppu_waitingfor_crc:=true;

            { load implementation symtable }
            if mf_local_symtable in moduleflags then
              begin
                localsymtable:=TStaticSymTable.create(RealModuleName^,ModuleID);
                TStaticSymTable(localsymtable).ppuload(ppufile);
              end;

            { we can now dereference all pointers to the implementation parts }
            TStoredSymTable(GlobalSymTable).derefimpl(false);
            { we've just loaded the localsymtable from the ppu file, so everything
              in it was registered by definition (otherwise it wouldn't have been in
              there) }
            if Assigned(localsymtable) then
              TStoredSymTable(localsymtable).derefimpl(false);

            remove_waitforunit_cycles;

          end;

        { the implementation uses were just connected,
          the scc_tree_crc_wait is outdated.
          If all used units are compiled, continue.
          otherwise some used units might still change }
        if find_used_unit_compiling<>nil then
          exit(false);

        { check that all used units have their crc and checksums match }
        if not ppu_check_used_crcs then
          exit(false);
        ppu_waitingfor_crc:=false;

        derefunitimportsyms;

        { read whole program optimisation-related information }
        wpoinfo:=TUnitWPOInfo.ppuload(ppufile);
        TUnitWPOInfo(wpoinfo).deref;
        TUnitWPOInfo(wpoinfo).derefimpl;

        remove_all_waitsforthisunit;

        state:=ms_compiled;
      end;

    function TPPUModule.load_usedunits_section: boolean;
      var
        pu: TUsedUnit;
        IntfCRCValid, CRCValid: Boolean;
      begin
        Result:=true;
        pu:=TUsedUnit(used_units.first);
        while Assigned(pu) do
        begin
          if pu.in_interface=in_interface then
          begin
            { adddependency before loadppu for invalid cycle test }
            if not pu.dependent_added then
            begin
              pu.u.adddependency(self,in_interface);
              pu.dependent_added:=true;
            end;

            TPPUModule(pu.u).loadppu(self);
            { if this unit is scheduled for compilation or compiled we can stop }
            if state<>ms_load then
            begin
              {$IFDEF DEBUG_PPU_CYCLES}
              WriteLn('tppumodule.load_usedunits_section STOPPED ',ModuleName^,' ',StateStr);
              {$ENDIF}
              exit(false);
            end;
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tppumodule.load_usedunits_section ',ModuleName^,' (',StateStr,') ',BoolToStr(in_interface,'interface','implementation'),' uses "',pu.u.ModuleName^,'" state=',pu.u.StateStr);
            {$ENDIF}

            { check crc(s) if recompile is needed.
              Currently ppus wait for a pas to be compiled, because a ppu cannot
              use only the interface of a pas.
              If an unit of a cycle is recompiled, the whole cycle is recompiled.

              If this ppu was compiled with -Ur only check interface_crc, not crc }
            CRCValid:=(not pu.u.do_reload) and pu.u.crc_final;
            IntfCRCValid:=(not pu.u.do_reload) and pu.u.interface_compiled;

            if (IntfCRCValid and
                     ((pu.u.interface_crc<>pu.interface_checksum) or
                      (pu.u.indirect_crc<>pu.indirect_checksum)))
                or (CRCValid and
                  {$IFNDEF DisableUrCRC}
                  (not (mf_release in moduleflags)) and
                  {$ENDIF}
                  (pu.u.crc<>pu.checksum)
                 ) then
            begin
              Message2(unit_u_recompile_crc_change,RealModuleName^,pu.u.PPUFileName,@queuecomment);
              {$IFDEF DEBUG_PPU_CYCLES}
              WriteLn('PPUALGO tppumodule.load_usedunits_section ',ModuleName^,' ',BoolToStr(in_interface,'interface','implementation'),' uses "',pu.u.ModuleName^,'" old=',StateStr,' new=',ms_compile);
              {$ENDIF}
              mark_recompile_needed(rr_crcchanged);
              exit(false);
            end;

            if pu.u.do_reload
                or (not pu.u.interface_compiled)
                or ctask_fast_backtrack then
            begin
              { this used unit is delayed
                Important: do not break, load the remaining uses section, so the scheduler
                           has more information about cycles }
              {$IFDEF DEBUG_PPU_CYCLES}
              WriteLn('PPUALGO tppumodule.load_usedunits_section ',ModuleName^,' ',BoolToStr(in_interface,'interface','implementation'),' uses "',pu.u.ModuleName^,'", state=',pu.u.StateStr,', waiting ...');
              {$ENDIF}
              ctask_fast_backtrack:=true;
              Result:=false;
            end;
          end;
          pu:=TUsedUnit(pu.next);
        end;
      end;

    function TPPUModule.ppu_check_used_crcs: boolean;
    // check crcs
    var
      pu: TUsedUnit;
    begin
      Result:=false;
      pu:=TUsedUnit(used_units.first);
      while Assigned(pu) do
      begin
        if pu.u.crc_final then
        begin
          if (pu.u.interface_crc<>pu.interface_checksum)
              or (pu.u.indirect_crc<>pu.indirect_checksum)
              or (pu.u.crc<>pu.checksum) then
          begin
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tppumodule.ppu_check_used_crcs ',ModuleName^,' interface uses "',pu.u.ModuleName^,'" old=',StateStr,' new=',ms_compile);
            {$ENDIF}
            mark_recompile_needed(rr_crcchanged);
            exit;
          end;
        end else begin
          { waiting for crc }
          exit;
        end;
        pu:=TUsedUnit(pu.next);
      end;

      Result:=true;
    end;

    function TPPUModule.ppuloadcancontinue(out firstwaiting: TModule): boolean;
    var
      pu: TUsedUnit;
    begin
      Result:=false;
      firstwaiting:=nil;
      if state<>ms_load then
        InternalError(2026020610);

      if do_reload and not interface_compiled then
        exit(true);

      if ppu_waitingfor_crc and (scc_tree_crc_wait<>nil) then
        begin
          firstwaiting:=scc_tree_crc_wait;
          exit; { the final load step needs all used units and their used units }
        end;

      pu:=TUsedUnit(used_units.first);
      while Assigned(pu) do
      begin
        if pu.in_interface or interface_compiled then
        begin
          if pu.u.do_reload
              or not pu.u.interface_compiled
              or (ppu_waitingfor_crc and not pu.u.crc_final
                 {$IFNDEF DisableUrCRC}and not (mf_release in moduleflags){$ENDIF} ) then
          begin
            firstwaiting:=pu.u;
            exit;
          end;
        end;
        pu:=TUsedUnit(pu.next);
      end;
      Result:=true;
    end;

    function TPPUModule.is_reload_needed(pu: TDependentUnit): boolean;
      begin
        if pu.u.state=ms_load then
          Result:=pu.u.ppu_waitingfor_crc
                or (pu.in_interface and pu.u.interface_compiled)
        else
          Result:=inherited is_reload_needed(pu);
      end;

    procedure TPPUModule.restore_state;
      begin
        SetCurrentModule(self);
        if stored_state<>nil then
          stored_state.restore;
      end;

    procedure TPPUModule.store_state;
      begin
        if stored_state=nil then
          stored_state:=TGlobalState.Create(true)
        else
          stored_state.save(true);
      end;

    procedure TPPUModule.setdefgeneration;
      begin
        defsgeneration:=currentdefgeneration;
        inc(currentdefgeneration);
      end;

    procedure TPPUModule.end_of_parsing;
      begin
        { free ppu }
        discardppu;

        inherited end_of_parsing;
      end;

    { Returns true if the module was loaded from package }
    function TPPUModule.check_loadfrompackage : boolean;

      begin
        { try to load it as a package unit first }
        Result:=(PackageList.count>0) and loadfrompackage;
        if Result then
          begin
            do_reload:=false;
            { add the unit to the used units list of the program }
            UsedUnits.concat(TUsedUnit.create(self,true,false,nil));
          end;
      end;

    procedure TPPUModule.recompile_from_sources;

      var
        was_interfaced_compiled: Boolean;
      begin
        SetCurrentModule(self);
        check_sources_for_recompile;

        {$IFDEF DEBUG_PPU_CYCLES}
        WriteLn('PPUALGO tppumodule.recompile_from_sources ',ModuleName^,' old=',StateStr,' new=',ms_compile);
        {$ENDIF}
        was_interfaced_compiled:=interface_compiled;
        { disconnect used modules }
        disconnect_depending_modules;
        if FromPPU then
          ppu_discarded:=true;
        { Flag modules to reload }
        flagdependent;
        { Reset stack, parser, scanner, etc }
        if not FromPPU then
          end_of_parsing;
        { Reset the module }
        reset(true);

        { mark this module for recompilation }
        state:=ms_compile;
        if was_interfaced_compiled then
          setdefgeneration;
      end;

    procedure TPPUModule.check_sources_for_recompile;
      var
        pu: TUsedUnit;
      begin
        { recompile the unit or give a fatal error if sources not available }
        if not SourcesAvail then
         begin
           search_unit_files(loadedfrommodule,true);
           if not SourcesAvail then
            begin
              printcomments;
              if recompile_reason=rr_noppu then
                begin
                  pu:=TUsedUnit(loadedfrommodule.used_units.first);
                  while Assigned(pu) do
                    begin
                      if pu.u=self then
                        break;
                      pu:=TUsedUnit(pu.next);
                    end;
                  if Assigned(pu) and Assigned(pu.unitsym) then
                    MessagePos2(pu.unitsym.fileinfo,unit_f_cant_find_ppu,RealModuleName^,loadedfrommodule.RealModuleName^)
                  else
                    Message2(unit_f_cant_find_ppu,RealModuleName^,loadedfrommodule.RealModuleName^);
                end
              else
                Message1(unit_f_cant_compile_unit,RealModuleName^);
            end;
         end;
        { we found the sources, we do not need the verbose messages anymore }
        if comments <> nil then
        begin
          comments.free;
          comments:=nil;
        end;
      end;

    procedure TPPUModule.mark_recompile_needed(reason: TRecompileReason);
      begin
        {$IFDEF DEBUG_PPU_CYCLES}
        WriteLn('PPUALGO tppumodule.mark_recompile_needed ',ModuleName^,' old=',StateStr,' new=',ms_compile);
        {$ENDIF}
        recompile_reason:=reason;
        do_recompile:=true;
        do_reload:=true;
        state:=ms_compile;
      end;

    procedure TPPUModule.post_load_or_compile(from_module : TModule);
      begin
        if in_interface then
          InternalError(200212283);

        { reopen the old module }
      end;

    function TPPUModule.loadppu(from_module : TModule) : boolean;
      const
        ImplIntf : array[boolean] of string[15]=('implementation','interface');
      var
        old_module: TModule;
      begin
        Result:=false;

        {$IFDEF DEBUG_PPU_CYCLES}
        WriteLn('PPUALGO tppumodule.loadppu START ',ModuleName^,' (',StateStr,') used by "',from_module.ModuleName^,'" (',from_module.StateStr,')');
        {$ENDIF}

        Message3(unit_u_load_unit,from_module.ModuleName^,
                 ImplIntf[from_module.in_interface],
                 ModuleName^);

        if do_reload then
          exit; { reload needed. see scheduler }

        if state>ms_registered then
          exit(interface_compiled); { loading has already started or is finished }

        if ppu_discarded then
          exit; { the ppu crc didn't match and this module was reset, don't load the ppu }

        if ctask_fast_backtrack then
          exit; { return to scheduler }

        loadedfrommodule:=from_module;

        old_module:=CurrentModule;
        SetCurrentModule(self);

        if check_loadfrompackage then
        begin
          Result:=continueloadppu;
          SetCurrentModule(old_module);
          {$IFDEF DEBUG_PPU_CYCLES}
          WriteLn('PPUALGO tppumodule.loadppu from package: ',ModuleName^,' (',StateStr,') used by "',from_module.ModuleName^,'" (',from_module.StateStr,')');
          {$ENDIF}
          exit;
        end;


        { search ppu file }
        Message1(unit_u_loading_unit,ModuleName^);
        if auPPU in search_unit_files(from_module,false) then
        begin
          state:=ms_load;
          FromPPU:=true;
          load_interface;
        end
        else begin
          {$IFDEF DEBUG_PPU_CYCLES}
          WriteLn('PPUALGO tppumodule.try_load_ppufile ',ModuleName^,' no ppu found old=',StateStr,' new=',ms_compile);
          {$ENDIF}
          { recompile_reason is already set by search_unit_files }
          state:=ms_compile;
        end;

        Result:=continueloadppu;

        SetCurrentModule(old_module);
      end;

    function TPPUModule.get_check_uses(out check_impl_uses, check_crc: boolean): boolean;
      begin
        check_impl_uses:=false;
        check_crc:=false;
        if not interface_compiled then
          exit(false);
        Result:=true;

        { if implementation was parsed then implementation uses must be checked too }
        if state=ms_load then
          check_impl_uses:=ppu_waitingfor_crc
        else if FromPPU then
          check_impl_uses:=true
        else
          check_impl_uses:=state in [ms_compiling_waitfinish..ms_compiled,ms_processed];

        { if the crc(s) of used unit are known }
        check_crc:={$IFNDEF DisableUrCRC}not (mf_release in moduleflags) and{$ENDIF}
                   (FromPPU or (state in [ms_load,ms_compiled,ms_processed]));
      end;

    function TPPUModule.continueloadppu: boolean;
      var
        old_module: TModule;
      begin
        Result:=false;
        old_module:=CurrentModule;

        restore_state;

        if do_reload then
          InternalError(2026021017);

        if state=ms_load then
        begin
          if load_usedunits then
          begin
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tppumodule.continueloadppu ',ModuleName^,' finished state=',StateStr);
            {$ENDIF}
            Message1(unit_u_finished_loading_unit,ModuleName^);
          end else if state=ms_load then
          begin
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tppumodule.continueloadppu ',ModuleName^,' delay state=',StateStr);
            {$ENDIF}
            store_state;
            { loading unfinished or reset, restore current_module }
            SetCurrentModule(old_module);
            exit;
          end else if state<>ms_compile then
            InternalError(2026020510);
        end;

        { PPU is not needed anymore }
        if Assigned(ppufile) then
          discardppu;

        if state=ms_compiled then
        begin
          Result:=true;
          post_load_or_compile(loadedfrommodule);
        end else if state=ms_compile then
          mark_recompile_needed(recompile_reason);

        { finished or recompile: no need to store state }
        FreeAndNil(stored_state);

        { we are back, restore current_module }
        SetCurrentModule(old_module);
      end;

    function TPPUModule.canreload(out firstwaiting: TModule; ignore_do_reload: boolean): boolean;
      var
        check_impl_uses, check_crc: Boolean;
        pu: TUsedUnit;
      begin
        firstwaiting:=nil;
        if not get_check_uses(check_impl_uses, check_crc) then
          exit(true);

        pu:=TUsedUnit(used_units.first);
        while Assigned(pu) do
        begin
          if pu.in_interface or check_impl_uses then
          begin
            if not pu.u.interface_compiled
                or (pu.u.do_reload and not ignore_do_reload) then
            begin
              firstwaiting:=pu.u;
              exit(false);
            end;
          end;
          pu:=TUsedUnit(pu.next);
        end;
        Result:=true;
      end;

    procedure TPPUModule.reload;
      var
        firstwaiting: TModule;
      begin
        if not do_reload then
          InternalError(2026021015);

        if state in [ms_compiled,ms_processed] then
        begin
          WriteLn('tppumodule.reload_module ',ModuleName^,' ',StateStr);
          InternalError(2026022410);
        end;

        if not canreload(firstwaiting,true) then
        begin
          if do_reload then
          begin
            WriteLn('tppumodule.reload_module ',ModuleName^,' ',StateStr,' RELOAD FAILED');
            InternalError(2026022413);
          end;
          exit;
        end;

        {$IFDEF DEBUG_PPU_CYCLES}
        WriteLn('PPUALGO tppumodule.reload ',ModuleName^,' ',StateStr,' RELOADING');
        {$ENDIF}
        Message(unit_u_forced_reload);
        do_reload:=false;
        SetCurrentModule(self);
        re_resolve;
      end;

    procedure TPPUModule.discardppu;
      begin
        { PPU is not needed anymore }
        if not Assigned(ppufile) then
          exit;
        ppufile.closefile;
        ppufile.free;
        ppufile:=nil;
        FreeAndNil(packageppustream);
      end;

{*****************************************************************************
                               RegisterUnit
*****************************************************************************}


    function registerunit(callermodule:TModule;const s : TIDString;const fn:string; out is_new:boolean) : TPPUModule;

          function FindCycle(aFile, SearchFor: TPPUModule; var Cycle: TFPList): boolean;
          var
            aParent: TDependentUnit;
          begin
            { check already visited }
            if aFile.cycle_search_stamp=TPPUModule.cycle_stamp then
              exit(false);
            aFile.cycle_search_stamp:=TPPUModule.cycle_stamp; { mark visited }

            if aFile=SearchFor then
            begin
              { unit cycle found }
              if Cycle=nil then Cycle:=TFPList.Create;
              Cycle.Add(aFile);
              //Writeln('exit at ',aFile.modulename^,' callermodule=',callermodule.modulename^,' in_interface=',callermodule.in_interface);
              exit(true);
            end;

            aParent:=TDependentUnit(aFile.dependent_units.First);
            While Assigned(aParent) do
            begin
              //writeln('Registering ',Callermodule.modulename^,': checking cyclic dependency of ',aFile.modulename^, ' on ',aParent.u.modulename^);
              if aParent.in_interface then
              begin
                // writeln('Registering ',Callermodule.get_modulename,': checking cyclic dependency of ',aFile.get_modulename, ' on ',aparent.u.get_modulename);
                if FindCycle(TPPUModule(aParent.u),SearchFor,Cycle) then
                begin
                  //Writeln('Cycle found, exit at ',aParent.u.modulename^,' uses ',aFile.modulename^);
                  Cycle.Add(aFile);
                  exit(true);
                end;
              end;
              aParent:=TDependentUnit(aParent.Next);
            end;
            Result:=false;
          end;

      var
        ups   : TIDString;
        hp    : TPPUModule;
        cycle : TFPList;

      begin
        { Info }
        ups:=upper(s);

        { search all loaded units, skip program/library }
        hp:=TPPUModule(loaded_units.first);
        while Assigned(hp) and ((hp.ModuleName^<>ups) or not hp.is_unit) do
          hp:=TPPUModule(hp.next);

        is_new:=not Assigned(hp);
        if is_new then
        begin
          { the unit is not in the loaded units,
            we create an entry and register the unit }
          Message1(unit_u_registering_new_unit,ups);
          hp:=TPPUModule.create(callermodule,s,fn,true);
          addloadedunit(hp);
        end
        else if callermodule.in_interface then
        begin
          { check for a cycle }
          Cycle:=nil;
          try
            TModule.increase_cycle_stamp;
            if FindCycle(TPPUModule(CallerModule),hp,Cycle) then
            begin
              Message2(unit_f_circular_unit_reference,callermodule.RealModuleName^,hp.RealModuleName^);
            end;
          finally
            Cycle.Free;
          end;
        end;

        { return }
        registerunit:=hp;
      end;

end.
