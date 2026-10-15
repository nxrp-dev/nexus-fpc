{
    Copyright (c) 1998-2008 by Florian Klaempfl

    Handles the parsing and loading of the modules (ppufiles)

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
unit pmodules;

{$i fpcdefs.inc}

interface

uses FModule;

    function proc_unit(curr: TModule):boolean;
    function parse_unit_interface_declarations(curr : TModule) : boolean;
    function proc_unit_implementation(curr: TModule):boolean;
    function proc_package(curr: TModule) : boolean;
    function finish_package(curr: TModule) : boolean;
    function proc_program(curr: TModule; IsLibrary : boolean) : boolean;
    function proc_program_declarations(curr : TModule; IsLibrary : boolean) : boolean;
    function finish_compile_unit(module:TModule): boolean;
    function finish_unit(module:TModule): boolean;

implementation

    uses
       SysUtils,
       GlobType,Systems,tokens,
       CUtils,CFileUtl,CClasses,CompHook,
       Globals,Verbose,FinPut,fppu,GlobStat,FPCP,FPkg,
       symconst,SymBase,symtype,symdef,SymSym,SymTable,defutil,symcreat,
       wpoinfo,
       aasmtai,AAsmData,aasmbase,aasmcpu,
       cgbase,ngenutil,
       nbas,nutils,ncgutil,
       link,assemble,import,export,gendef,ppu,CompRsrc,DbgBase,
       CResStr,ProcInfo,
       objcgutl,
       PkgUtil,NXPackageFile,
       wpobase,
       Scanner,pbase,pexpr,psystem,psub,pgenutil,pparautl,ncgvmt,ncgrtti,
       CPUInfo;


    procedure create_objectfile(curr : TModule);
      var
        DLLScanner      : TDLLScanner;
        s               : string;
        KeepShared      : TCmdStrList;
      begin
        { try to create import entries from system dlls }
        if (tf_has_dllscanner in TargetInfo.flags) and
           (not curr.linkOtherSharedLibs.Empty) then
         begin
           { Init DLLScanner }
           if Assigned(CDLLScanner[Ord(TargetInfo.system)]) then
            DLLScanner:=CDLLScanner[Ord(TargetInfo.system)].Create
           else
            InternalError(200104121);
           KeepShared:=TCmdStrList.Create;
           { Walk all shared libs }
           While not curr.linkOtherSharedLibs.Empty do
            begin
              S:=curr.linkOtherSharedLibs.Getusemask(link_always);
              if not DLLScanner.scan(s) then
               KeepShared.Concat(s);
            end;
           DLLscanner.Free;
           DLLscanner := nil;
           { Recreate import section }
           if (TargetInfo.system=system_i386_win32) then
            begin
              if Assigned(CurrentAsmData.asmlists[al_imports]) then
               CurrentAsmData.asmlists[al_imports].clear
              else
               CurrentAsmData.asmlists[al_imports]:=TAsmList.Create;
              importlib.generatelib;
            end;
           { Readd the not processed files }
           while not KeepShared.Empty do
            begin
              s:=KeepShared.GetFirst;
              curr.linkOtherSharedLibs.add(s,link_always);
            end;
           KeepShared.Free;
           KeepShared := nil;
         end;

        { allow a target-specific pass over all assembler code (used by LLVM
          to insert type definitions }
        CNodeUtils.InsertObjectInfo;

        { Start and end module debuginfo, at least required for stabs
          to insert n_sourcefile lines }
        if (cs_debuginfo in CurrentSettings.ModuleSwitches) or
           (cs_use_lineinfo in CurrentSettings.GlobalSwitches) then
          CurrentDebugInfo.insertmoduleinfo;

        { create the .s file and assemble it }
        if not(create_smartlink_library) or not(tf_no_objectfiles_when_smartlinking in TargetInfo.flags) then
          GenerateAsm(false);

        { Also create a smartlinked version ? }
        if create_smartlink_library then
         begin
           GenerateAsm(true);
           if (af_needar in TargetAsm.flags) and
              DrainClangAssemblerQueue then
             Linker.MakeStaticLibrary;
         end;

        { resource files }
        CompileResourceFiles;
      end;


    procedure insertobjectfile(curr : TModule);
    { Insert the used object file for this unit in the used list for this unit }
      begin
        curr.linkunitofiles.add(ExtractFileName(curr.ObjFileName),link_static);
        curr.headerflags:=curr.headerflags or uf_static_linked;

        if create_smartlink_library then
          begin
            curr.linkunitstaticlibs.add(curr.StaticLibFileName ,link_smart);
            curr.headerflags:=curr.headerflags or uf_smart_linked;
          end;
        if cs_lto in CurrentSettings.ModuleSwitches then
          begin
            curr.linkunitofiles.add(ChangeFileExt(curr.ObjFileName,LTOExt),link_lto);
            curr.headerflags:=curr.headerflags or uf_lto_linked;
          end;
      end;


    procedure create_dwarf_frame;
      begin
        { Dwarf conflicts with smartlinking in separate .a files }
        if create_smartlink_library then
          exit;
        { Call frame information }
        { MWE: we write our own info, so dwarf asm support is not really needed }
        { if (af_supports_dwarf in target_asm.flags) and }
        { CFI is currently broken for Darwin }
        if not(TargetInfo.system in systems_darwin) and
           (
            (tf_needs_dwarf_cfi in TargetInfo.flags) or
            (TargetDbg.id in [dbg_dwarf3, dbg_dwarf4, dbg_dwarf5])
           ) then
          begin
            CurrentAsmData.asmlists[al_dwarf_frame].Free;
            CurrentAsmData.asmlists[al_dwarf_frame] := TAsmList.create;
            CurrentAsmData.asmcfi.generate_code(CurrentAsmData.asmlists[al_dwarf_frame]);
          end;
      end;

    Function CheckResourcesUsed(curr : TModule) : boolean;
      var
        hp           : TUsedUnit;
        found        : Boolean;
      begin
        CheckResourcesUsed:=tf_has_winlike_resources in TargetInfo.flags;
        if not CheckResourcesUsed then exit;

        hp:=TUsedUnit(UsedUnits.first);
        found:=mf_has_resourcefiles in curr.moduleflags;
        while Assigned(hp) and not found do
          begin
            found:=not Assigned(hp.u.package) and (mf_has_resourcefiles in hp.u.moduleflags);
            hp:=TUsedUnit(hp.next);
          end;
        CheckResourcesUsed:=found;
      end;

    function AddUnit(curr : TModule; const s:string; addasused:boolean = true): TPPUModule;
      var
        hp : TPPUModule;
        unitsym : TUnitSym;
        isnew : boolean;
        uu: TUsedUnit;

      begin
        { load unit }
        hp:=registerunit(curr,s,'',isnew);
        if isnew then
          UsedUnits.concat(TUsedUnit.create(hp,true,addasused,nil));
        hp.adddependency(curr,curr.in_interface); { adddependency before loadppu for invalid cycle test }
        hp.loadppu(curr);
        TModule.finish_module(hp);

        { add to symtable stack }
        if Assigned(hp.GlobalSymTable) then
          SymTableStack.push(hp.GlobalSymTable);
        if (m_mac in CurrentSettings.ModeSwitches) and
            Assigned(hp.GlobalMacroSymTable) then
          MacroSymTableStack.push(hp.GlobalMacroSymTable);
        { insert unitsym }
        unitsym:=CUnitSym.create(hp.ModuleName^,hp);
        inc(unitsym.refs);
        TAbstractUnitSymTable(curr.localsymtable).insertunit(unitsym);
        if addasused then
        begin
          { add to used units }
          uu:=curr.addusedunit(hp,false,unitsym);
          uu.dependent_added:=true;
        end;
        result:=hp;
      end;

    function maybeloadvariantsunit(curr : TModule) : boolean;
      var
        hp : TModule;
        addsystemnamespace : Boolean;
      begin
        result:=true;
        { Do we need the variants unit? Skip this
          for VarUtils unit for bootstrapping }
        if not(mf_uses_variants in curr.moduleflags) or
           (curr.ModuleName^='VARUTILS') or
           (curr.ModuleName^='SYSTEM.VARUTILS') then
          exit;
        { Variants unit already loaded? }
        hp:=TModule(loaded_units.first);
        while Assigned(hp) do
          begin
            if (hp.ModuleName^='VARIANTS') or (hp.ModuleName^='SYSTEM.VARIANTS') then
              exit;
            hp:=TModule(hp.next);
          end;
        { Variants unit is not loaded yet, load it now }
        Message(parser_w_implicit_uses_of_variants_unit);
        addsystemnamespace:=NamespaceList.Find('System')=Nil;
        if addsystemnamespace then
          NamespaceList.concat('System');
        result:=AddUnit(curr,'variants').state in [ms_compiled,ms_processed];
        if addsystemnamespace then
          NamespaceList.Remove('System');
      end;


    function MaybeRemoveResUnit(curr : TModule) : boolean;
      var
        resources_used : boolean;
        hp : TModule;
        uu : TUsedUnit;
        unitname : shortstring;
      begin
        { We simply remove the unit from:
           - usedunit list, so that things like init/finalization table won't
              contain references to this unit
           - loaded_units list, so that the unit object file doesn't get linked
             with the executable. }
        { Note: on windows we always need resources! }
        resources_used:=(TargetInfo.system in systems_all_windows)
                         or CheckResourcesUsed(curr);
        if (not resources_used) and (tf_has_winlike_resources in TargetInfo.flags) then
          begin
            { resources aren't used, so we don't need this unit }
            if TargetRes.id=res_ext then
              unitname:='FPEXTRES'
            else
              unitname:='FPINTRES';
            Message1(unit_u_unload_resunit,unitname);
            { find the module }
            hp:=TModule(loaded_units.first);
            while Assigned(hp) do
              begin
                if hp.is_unit and (hp.ModuleName^=unitname) then break;
                hp:=TModule(hp.next);
              end;
            if not Assigned(hp) then
              InternalError(200801071);
            { Imported resource support belongs to its package. Removing that
              module would invalidate the provider's dependency closure. }
            if Assigned(hp.package) then
              exit(resources_used);
            { find its tused_unit in the global list }
            uu:=TUsedUnit(UsedUnits.first);
            while Assigned(uu) do
              begin
                if uu.u=hp then break;
                uu:=TUsedUnit(uu.next);
              end;
            if not Assigned(uu) then
              InternalError(200801072);
           { remove the tused_unit }
            UsedUnits.Remove(uu);
            uu.Free;
            // Remove from local list
            uu:=TUsedUnit(curr.used_units.first);
            while Assigned(uu) do
              begin
                if uu.u=hp then break;
                uu:=TUsedUnit(uu.next);
              end;
            if not Assigned(uu) then
              InternalError(2024020701);
            curr.used_units.Remove(uu);
            uu.Free;
            uu := nil;
           { remove the module }
            loaded_units.Remove(hp);
            unloaded_units.Concat(hp);
          end;
        MaybeRemoveResUnit:=resources_used;
      end;


    procedure checksystemcharwidth;
      begin
        { The PPU's text-model flag cannot prove that System.Char was
          declared with the matching width. }
        if search_system_type('CHAR').typedef.size <>
           1+Ord(CompilerWide_Unicode_Strings) then
          Comment(VFatal,'System.Char width does not match this compiler invocation''s default text model');
      end;


    function loadsystemunit(curr : TModule) : boolean;
      var
        state: TGlobalState;
        sys : TModule;

      begin
        Result:=False;
        { we are going to rebuild the symtablestack, clear it first }
        SymTableStack.clear;
        MacroSymTableStack.clear;

        { macro symtable }
        MacroSymTableStack.push(initialmacrosymtable);

        { are we compiling the system unit? }
        if (cs_compilesystem in CurrentSettings.ModuleSwitches) then
         begin
           systemunit:=TGlobalSymTable(curr.localsymtable);
           { create system defines }
           create_intern_types;
           create_intern_symbols;
           { Set the owner of errorsym and errortype to symtable to
             prevent crashes when accessing .owner }
           generrorsym.owner:=systemunit;
           generrordef.owner:=systemunit;
           exit;
         end;

        { insert the system unit, it is always the first. Load also the
          internal types from the system unit }
        Sys:=AddUnit(curr,'system');
        Result:=Assigned(Sys) and (Sys.State in [ms_processed,ms_compiled]);
        systemunit:=TGlobalSymTable(SymTableStack.top);

        { load_intern_types resets the scanner... }
        CurrentScanner.tempcloseinputfile;
        state:=TGlobalState.create(false);
        load_intern_types;
        state.restore;
        FreeAndNil(state);
        CurrentScanner.tempopeninputfile;
        if Result then
          checksystemcharwidth;

        { Set the owner of errorsym and errortype to symtable to
          prevent crashes when accessing .owner }
        generrorsym.owner:=systemunit;
        generrordef.owner:=systemunit;
        { default the extended RTTI options to that of TObject }
        if Assigned(class_tobject) then
          CurrentModule.rtti_directive.options:=class_tobject.rtti.options;
      end;


    { load default units, like language mode units
      Return true if all units were loaded, no recompilation needed. }
    function loaddefaultunits(curr :TModule) : boolean;

      var
        profileunit : TPPUModule;
        profilesym : TUnitSym;
        isnew : boolean;

      Procedure CheckAddUnit(s: string);

        var
          OK : boolean;
          m : TModule;

        begin
          m:=AddUnit(curr,s,true);
          OK:=Assigned(m) and (m.state in [ms_processed,ms_compiled]);
          if not ok then
            Message2(unit_f_cant_find_ppu,s,curr.RealModuleName^);
          Result:=ok and Result;
        end;

      begin
        Result:=True;
        { Units only required for main module }
        if not(curr.is_unit) then
         begin
           { Heaptrc unit, load heaptrace before any other units especially objpas }
           if (cs_use_heaptrc in CurrentSettings.GlobalSwitches) then
             CheckAddUnit('heaptrc');
           { Valgrind requires c memory manager }
           if (cs_gdb_valgrind in CurrentSettings.GlobalSwitches) or
              (([cs_sanitize_address]*CurrentSettings.ModuleSwitches)<>[]) then
             CheckAddUnit('cmem');
           { Lineinfo unit }
           if (cs_use_lineinfo in CurrentSettings.GlobalSwitches) then begin
             case TargetDbg.id of
               dbg_stabs:
                 CheckAddUnit('lineinfo');
               dbg_stabx:
                 CheckAddUnit('lnfogdb');
               else
                 CheckAddUnit('lnfodwrf');
             end;
           end;
           { Which kind of resource support?
             Note: if resources aren't used this unit will be removed later,
             otherwise we need it here since it must be loaded quite early }
           if (tf_has_winlike_resources in TargetInfo.flags) then
             if TargetRes.id=res_ext then
               CheckAddUnit('fpextres')
             else
               CheckAddUnit('fpintres');
         end
        else if (cs_checkpointer in CurrentSettings.LocalSwitches) then
          CheckAddUnit('heaptrc');
        { Objpas unit? }
        if m_objpas in CurrentSettings.ModeSwitches then
          CheckAddUnit('objpas');

        { The profiling runtime can require a source rebuild, including when a
          cached dependency changes. Register it as an implicit uses entry so
          loadunits and the normal sequential continuation can finish it. The
          synchronous AddUnit path only supports loading already usable PPUs. }
        if not curr.is_unit and not curr.IsLibrary and
           (TargetInfo.system=system_x86_64_win64) and
           (cs_nexus_profile in CurrentSettings.ModuleSwitches) then
          begin
            profileunit:=registerunit(curr,'nxprofilerruntime','',isnew);
            if isnew then
              UsedUnits.concat(TUsedUnit.create(profileunit,false,true,nil));
            profilesym:=CUnitSym.create('NXPROFILERRUNTIME',nil);
            inc(profilesym.refs);
            curr.addusedunit(profileunit,true,profilesym);
          end;

        { Macpas unit? }
        if m_mac in CurrentSettings.ModeSwitches then
          CheckAddUnit('macpas');

        if m_iso in CurrentSettings.ModeSwitches then
          CheckAddUnit('iso7185');

        if m_extpas in CurrentSettings.ModeSwitches then
          begin
            { basic procedures for Extended Pascal are for now provided by the iso unit }
            CheckAddUnit('iso7185');
            CheckAddUnit('extpas');
          end;

        { blocks support? }
        if m_blocks in CurrentSettings.ModeSwitches then
          CheckAddUnit('blockrtl');

        { Objective-C support unit? }
        if (m_objectivec1 in CurrentSettings.ModeSwitches) then
          begin
            { interface to Objective-C run time }
            CheckAddUnit('objc');
            loadobjctypes;
            { NSObject }
            if not(curr.is_unit) or
               (curr.ModuleName^<>'OBJCBASE') then
              CheckAddUnit('objcbase');
          end;
      end;

    { Load units provided on the command line
      Return true if all units were loaded, no recompilation needed. }
    function loadautounits(curr: TModule) : boolean;

      Procedure CheckAddUnit(s: string);

        var
          OK : boolean;
          m : TModule;

        begin
          m:=AddUnit(curr,s,true);
          OK:=Assigned(m) and (m.state in [ms_compiled,ms_processed]);
          Result:=ok and Result;
        end;

      var
        hs,s : string;
      begin
        Result:=True;
        hs:=AutoloadUnits;
        repeat
          s:=GetToken(hs,',');
          if s='' then
            break;
          CheckAddUnit(s);
        until false;
      end;

    procedure parseusesclause(curr: TModule; iscontains:boolean=false);

      var
         s,sorg  : AnsiString;
         fn      : string;
         pu  : TUsedUnit;
         hp2     : TModule;
         unitsym : TUnitSym;
         filepos : TFilePosInfo;
         isnew : boolean;


      begin
        if iscontains then
          consume(_ID)
        else
          consume(_USES);
        repeat
          s:=CurrentScanner.pattern;
          sorg:=CurrentScanner.orgpattern;
          filepos:=CurrentTokenPos;
          consume(_ID);
          while CurrentScanner.token=_POINT do
            begin
              consume(_POINT);
              s:=s+'.'+CurrentScanner.pattern;
              sorg:=sorg+'.'+CurrentScanner.orgpattern;
              consume(_ID);
            end;
          { support "<unit> in '<file>'" construct }
          fn:='';
          if try_to_consume(_OP_IN) then
            fn:=FixFileName(get_stringconst);
          { Give a warning if lineinfo is loaded }
          if s='LINEINFO' then
            begin
              Message(parser_w_no_lineinfo_use_switch);
              if (TargetDbg.id=dbg_dwarf3) then
               s := 'LNFODWRF';
             sorg := s;
            end;
          { Give a warning if objpas is loaded }
          if s='OBJPAS' then
           Message(parser_w_no_objpas_use_mode);
          { Using the unit itself is not possible }
          if (s<>curr.ModuleName^) then
           begin
             { check if the unit is already used }
             hp2:=nil;
             pu:=TUsedUnit(curr.used_units.first);
             while Assigned(pu) do
              begin
                if (pu.u.ModuleName^=s) then
                 begin
                   hp2:=pu.u;
                   break;
                 end;
                pu:=TUsedUnit(pu.next);
              end;
             if not Assigned(hp2) then
               begin
               hp2:=registerunit(curr,sorg,fn,isnew);
               if isnew then
                 UsedUnits.concat(TUsedUnit.create(hp2,curr.in_interface,true,nil));
               end
             else
               Message1(sym_e_duplicate_id,s);
             { Create unitsym, we need to use the name as specified, we
               can not use the modulename because that can be different
               when -Un is used }
             CurrentTokenPos:=filepos;
             unitsym:=CUnitSym.create(sorg,nil);
             { the current module uses the unit hp2 }
             curr.addusedunit(hp2,true,unitsym);
           end
          else
           Message1(sym_e_duplicate_id,s);
          if CurrentScanner.token=_COMMA then
           begin
             CurrentScanner.pattern:='';
             consume(_COMMA);
           end
          else
           break;
        until false;
      end;

    function loadunits(curr: TModule; frominterface : boolean) : boolean;

      var
        pu  : TUsedUnit;
        state: TGlobalState;
        lu : TModule;

        procedure restorestate;
          begin
            state.restore;
            if Assigned(CurrentScanner) and (CurrentModule.Scanner=CurrentScanner) then
              begin
                if Assigned(CurrentScanner.inputfile) then
                  CurrentScanner.tempopeninputfile;
              end;
            state.free;
            state := nil;
          end;

      begin
        Result:=true;
        CurrentScanner.tempcloseinputfile;
        state:=TGlobalState.create(false);

        { reset verbosity (otherwise the used units would use curr's pmessage) }
        CurrentSettings.PMessage:=nil;
        RestoreLocalVerbosity(nil);

        { Load the units }
        pu:=TUsedUnit(curr.used_units.first);
        while Assigned(pu) do
          begin
            lu:=pu.u;
            { Only load the units that are in the current
              (interface/implementation) uses clause }
            if pu.in_uses and
               (pu.in_interface=frominterface) then
             begin
               { adddependency before loadppu for invalid cycle test }
               if not pu.dependent_added then
               begin
                 pu.dependent_added:=true;
                 lu.adddependency(curr,frominterface);
               end;
               { always call loadppu for the cycle test }
               TPPUModule(lu).loadppu(curr);
               if not (curr.state in [ms_compile,ms_compiling_wait,ms_compiling_waitintf,ms_compiling_waitimpl]) then
               begin
                 {$IFDEF DEBUG_PPU_CYCLES}
                 WriteLn('loadunits STOPPED ',curr.ModuleName^,' ',curr.StateStr);
                 {$ENDIF}
                 Result:=false;
                 break;
               end;
               if not lu.interface_compiled or lu.do_reload or TModule.ctask_fast_backtrack then
               begin
                 { an used unit is delayed
                   Important: do not break, load the remaining uses section, so the scheduler
                              has more information about cycles }
                 {$IFDEF DEBUG_PPU_CYCLES}
                 WriteLn('PPUALGO loadunits ',curr.ModuleName^,' ',curr.StateStr,' ',BoolToStr(pu.in_interface,'interface','implementation'),' uses "',pu.u.ModuleName^,'", state=',pu.u.StateStr,', waiting ...');
                 {$ENDIF}
                 TModule.ctask_fast_backtrack:=true;
                 Result:=false;
               end;
               { check hints }
               pu.check_hints;
             end;
            pu:=TUsedUnit(pu.next);
          end;

        Restorestate;
      end;

     {
       Connect loaded units: check crc and add to symbol tables.
       this can only be called after all units were actually loaded!
     }

     procedure connect_loaded_units(_module : TModule; preservest:TSymTable);

     var
       pu  : TUsedUnit;
       sorg   : AnsiString;
       unitsymtable: TAbstractUnitSymTable;

     begin
       // writeln(_module.get_modulename,': Connecting units');
       pu:=TUsedUnit(_module.used_units.first);
       while Assigned(pu) do
         begin
         {
         Writeln('Connect : ',Assigned(_module.modulename), ' ', assigned(pu.u), ' ' ,assigned(pu.u.modulename));
         if assigned(pu.u) then
           begin
             if assigned(pu.u.modulename) then
               Writeln(_module.modulename^,': Examining connect of file ',pu._fn,' (',pu.u.modulename^,')')
             else
               Writeln(_module.modulename^,': Examining connect of file ',pu._fn);

           end
         else
           Writeln(_module.modulename^,': Examining unit without module... ');
         }
         if not (pu.in_uses and
            (pu.in_interface=_module.in_interface)) then
           begin
//           writeln('Must not connect ',pu.u.modulename^,' (pu.in_interface: ',pu.in_interface,' <> module.in_interface',_module.in_interface,')');
           end
         else
           begin
//           writeln('Must connect ',pu.u.modulename^,'(sym: ',pu.unitsym.realname,')');
           { save crc values }
           pu.checksum:=pu.u.crc;
           pu.interface_checksum:=pu.u.interface_crc;
           pu.indirect_checksum:=pu.u.indirect_crc;
           if TPPUModule(pu.u).nsprefix<>'' then
             begin
               { use the name as declared in the uses section for -Un }
               sorg:=TPPUModule(pu.u).nsprefix+'.'+pu.unitsym.realname;
               { update unitsym now that we have access to the full name }
               pu.unitsym.free;
               pu.unitsym:=CUnitSym.create(sorg,pu.u);
             end
           else
             begin
               { connect unitsym to the module }
               pu.unitsym.module:=pu.u;
               pu.unitsym.RegisterSym;
             end;
           {
             Add the unit symbol in the current symtable.
             localsymtable will be nil after the interface uses clause is parsed and the local symtable
             is moved to the global.
           }
           if Assigned(_module.localsymtable) then
             unitsymtable:=TAbstractUnitSymTable(_module.localsymtable)
           else
             unitsymtable:=TAbstractUnitSymTable(_module.GlobalSymTable);
           // Writeln('Adding used unit sym ',pu.unitsym.realName,' to table ',unitsymtable.get_name);
           unitsymtable.insertunit(pu.unitsym);
           { add to symtable stack }
           // Writeln('Adding used unit symtable ',pu.u.globalsymtable.name^,' (',pu.u.globalsymtable.DefList.Count, ' defs) to stack');
           if Assigned(preservest) then
             SymTableStack.pushafter(pu.u.GlobalSymTable,preservest)
           else
             SymTableStack.push(pu.u.GlobalSymTable);
           if (m_mac in CurrentSettings.ModeSwitches) and
              Assigned(pu.u.GlobalMacroSymTable) then
             MacroSymTableStack.push(pu.u.GlobalMacroSymTable);

           end;
         pu:=TUsedUnit(pu.next);
         end;
       // writeln(_module.get_modulename,': Done Connecting units');
     end;



     procedure reset_all_defs(curr: TModule);
       begin
         if Assigned(curr.wpoinfo) then
           curr.wpoinfo.resetdefs;
       end;


    procedure free_localsymtables(st:TSymTable);
      var
        i   : LongInt;
        def : TStoredDef;
        pd  : TProcDef;
      begin
        for i:=0 to st.DefList.Count-1 do
          begin
            def:=TStoredDef(st.DefList[i]);
            if def.typ=procdef then
              begin
                pd:=TProcDef(def);
                if Assigned(pd.localst) and
                   (pd.localst.symtabletype<>staticsymtable) and
                   not(po_inline in pd.procoptions) then
                  begin
                    free_localsymtables(pd.localst);
                    pd.localst.free;
                    pd.localst:=nil;
                  end;
                pd.freeimplprocdefinfo;
                pd.done_paraloc_info(calleeside);
              end;
          end;
      end;


    procedure free_unregistered_localsymtable_elements(curr : TModule);
      procedure remove_from_procdeflist(adef: TDef);
        var
          i: Integer;
          childdef: TDef;
        begin
          if adef=nil then exit;
          if (adef.typ in [objectdef, recorddef]) and (adef is TAbstractRecordDef) then
            begin
              if TAbstractRecordDef(adef).SymTable<>nil then
                for i:=0 to TAbstractRecordDef(adef).SymTable.DefList.Count-1 do
                  begin
                    childdef:=TDef(TAbstractRecordDef(adef).SymTable.DefList[i]);
                    remove_from_procdeflist(childdef);
                  end;
            end
          else
            if adef.typ=procdef then
              begin
                TProcSym(TProcDef(adef).procsym).ProcdefList.Remove(adef);
                if TProcDef(adef).localst<>nil then
                  for i:=0 to TProcDef(adef).localst.DefList.Count-1 do
                    begin
                      childdef:=TDef(TProcDef(adef).localst.DefList[i]);
                      remove_from_procdeflist(childdef);
                    end;
              end;
        end;

      var
        i: LongInt;
        def: TDef;
        sym: TSym;
      begin
        for i:=curr.localsymtable.deflist.count-1 downto 0 do
          begin
            def:=TDef(curr.localsymtable.deflist[i]);
            { since commit 48986 deflist might have NIL entries }
            if not Assigned(def) then
              continue;
            { this also frees def, as the defs are owned by the symtable }
            if not def.IsRegistered and
               not(df_not_registered_no_free in def.defoptions) then
              begin
                { if it's a procdef, unregister it from its procsym first,
                  unless that sym hasn't been registered either (it's possible
                  to have one overload in the interface and another in the
                  implementation) }
                remove_from_procdeflist(def);
                curr.localsymtable.deletedef(def);
              end;
          end;
        { from high to low so we hopefully have moves of less data }
        for i:=curr.localsymtable.symlist.count-1 downto 0 do
          begin
            sym:=TSym(curr.localsymtable.symlist[i]);
            { this also frees sym, as the symbols are owned by the symtable }
            if not sym.IsRegistered then
              curr.localsymtable.DeleteSym(sym);
          end;
      end;


    procedure setupglobalswitches;
      begin
        if (cs_create_pic in CurrentSettings.ModuleSwitches) then
          begin
            def_system_macro('FPC_PIC');
            def_system_macro('PIC');
          end;
      end;


    function create_main_proc(const name:TSymStr;potype:TProcTypeOption;st:TSymTable):TCGProcInfo;
      var
        ps  : TProcSym;
        pd  : TProcDef;
      begin
        { there should be no current_procinfo available }
        if Assigned(CurrentProcInfo) then
         InternalError(200304275);
        {Generate a procsym for main}
        ps:=CProcSym.create('$'+name);
        { always register the symbol }
        ps.RegisterSym;
        { main are always used }
        inc(ps.refs);
        st.insertsym(ps);
        pd:=TProcDef(CNodeUtils.create_main_procdef(TargetInfo.cprefix+name,potype,ps));
        { We don't need a local symtable, change it into the static symtable }
        if not (potype in [potype_mainstub,potype_pkgstub,potype_libmainstub]) then
          begin
            pd.localst.free;
            pd.localst:=st;
          end
        else if (potype=potype_pkgstub) and
            (TargetInfo.system in systems_all_windows) then
          pd.proccalloption:=pocall_stdcall
        else
          pd.proccalloption:=pocall_cdecl;
        handle_calling_convention(pd,hcc_default_actions_impl);
        { set procinfo and current_procinfo.procdef }
        result:=TCGProcInfo(CProcInfo.create(nil));
        result.procdef:=pd;
        { main proc does always a call e.g. to init system unit }
        if potype<>potype_pkgstub then
          include(result.flags,pi_do_call);
      end;


    procedure release_main_proc(curr: TModule; pi:TCGProcInfo);
      begin
        { remove localst as it was replaced by staticsymtable }
        pi.procdef.localst:=nil;
        { remove procinfo }
        curr.ProcInfo:=nil;
        pi.free;
        pi:=nil;
      end;



    { Insert _GLOBAL_OFFSET_TABLE_ symbol if system uses it }

    procedure maybe_load_got(curr: TModule);
{$if defined(i386)}
       var
         gotvarsym : TStaticVarSym;
{$endif i386 or sparcgen}
      begin
{$if defined(i386)}
         if (cs_create_pic in CurrentSettings.ModuleSwitches) and
            (tf_pic_uses_got in TargetInfo.flags) then
           begin
             { insert symbol for got access in assembler code}
             gotvarsym:=CStaticVarSym.create('_GLOBAL_OFFSET_TABLE_',
                          vs_value,voidpointertype,[vo_is_external]);
             gotvarsym.set_mangledname('_GLOBAL_OFFSET_TABLE_');
             curr.localsymtable.insertsym(gotvarsym);
             { avoid unnecessary warnings }
             gotvarsym.varstate:=vs_read;
             gotvarsym.refs:=1;
           end;
{$endif i386 or sparcgen}
      end;

    function gen_implicit_initfinal(curr: TModule; flag:TModuleFlag;st:TSymTable):TCGProcInfo;
      begin
        { create procdef }
        case flag of
          mf_init :
            begin
              result:=create_main_proc(make_mangledname('',curr.localsymtable,'init_implicit$'),potype_unitinit,st);
              result.procdef.aliasnames.concat(make_mangledname('INIT$',curr.localsymtable,''));
            end;
          mf_finalize :
            begin
              result:=create_main_proc(make_mangledname('',curr.localsymtable,'finalize_implicit$'),potype_unitfinalize,st);
              result.procdef.aliasnames.concat(make_mangledname('FINALIZE$',curr.localsymtable,''));
              if (not curr.is_unit) then
                result.procdef.aliasnames.concat('PASCALFINALIZE');
            end;
          else
            InternalError(200304253);
        end;
        result.code:=CNothingNode.create;
      end;


    procedure copy_macro(p:TObject; arg:pointer);
      begin
        TModule(arg).GlobalMacroSymTable.insertsym(TMacro(p).getcopy);
      end;

    function try_consume_hintdirective(var moduleopt:TModuleOptions; var deprecatedmsg:PShortString):boolean;
      var
        deprecated_seen,
        last_is_deprecated:boolean;
      begin
        try_consume_hintdirective:=false;
        deprecated_seen:=false;
        repeat
          last_is_deprecated:=false;
          case CurrentScanner.idtoken of
            _LIBRARY :
              begin
                include(moduleopt,mo_hint_library);
                try_consume_hintdirective:=true;
              end;
            _DEPRECATED :
              begin
                { allow deprecated only once }
                if deprecated_seen then
                  break;
                include(moduleopt,mo_hint_deprecated);
                try_consume_hintdirective:=true;
                last_is_deprecated:=true;
                deprecated_seen:=true;
              end;
            _EXPERIMENTAL :
              begin
                include(moduleopt,mo_hint_experimental);
                try_consume_hintdirective:=true;
              end;
            _PLATFORM :
              begin
                include(moduleopt,mo_hint_platform);
                try_consume_hintdirective:=true;
              end;
            _UNIMPLEMENTED :
              begin
                include(moduleopt,mo_hint_unimplemented);
                try_consume_hintdirective:=true;
              end;
            else
              break;
          end;
          consume(CurrentScanner.token);
          { handle deprecated message }
          if ((CurrentScanner.token=_CSTRING) or (CurrentScanner.token=_CCHAR)) and last_is_deprecated then
            begin
              if deprecatedmsg<>nil then
                InternalError(201001221);
              if CurrentScanner.token=_CSTRING then
                deprecatedmsg:=StringDup(CurrentScanner.cstringpattern)
              else
                deprecatedmsg:=StringDup(CurrentScanner.pattern);
              consume(CurrentScanner.token);
              include(moduleopt,mo_has_deprecated_msg);
            end;
        until false;
      end;



type
    TFinishState=record
      InitializationProcedure:TCGProcInfo;
      FinalizationProcedure:TCGProcInfo;
    end;
    PFinishState=^TFinishState;



    function proc_unit_implementation(curr: TModule):boolean;

      var
        InitializationProcedure,
        FinalizationProcedure : TCGProcInfo;
        finishstate:PFinishState;


      begin
        result:=true;
        InitializationProcedure:=nil;
        FinalizationProcedure:=nil;
        finishstate:=nil;

        SetCurrentModule(curr);

        { We get here only after used modules were loaded }
        connect_loaded_units(curr,curr.GlobalSymTable);

        { All units are read, now give them a number }
        curr.updatemaps;

        { Consume the semicolon if needed.
          At this point the units in the uses clause have at least been parsed
          and are connected, and conditional compilation expressions can
          use the symbols from those units }
        if curr.consume_semicolon_after_uses then
          begin
            consume(_SEMICOLON);
            curr.consume_semicolon_after_uses:=false;
          end;

        { further, changing the globalsymtable is not allowed anymore }
        curr.GlobalSymTable.sealed:=true;
        SymTableStack.push(curr.localsymtable);

        if not curr.interface_only then
          begin
            Message1(parser_u_parsing_implementation,curr.ModuleName^);
            if curr.in_interface then
              InternalError(200212285);

            { Compile the unit }
            InitializationProcedure:=create_main_proc(make_mangledname('',curr.localsymtable,'init$'),potype_unitinit,curr.localsymtable);
            InitializationProcedure.procdef.aliasnames.concat(make_mangledname('INIT$',curr.localsymtable,''));
            InitializationProcedure.parse_body;
            { save file pos for debuginfo }
            curr.mainfilepos:=InitializationProcedure.entrypos;

            { parse finalization section }
            if CurrentScanner.token=_FINALIZATION then
              begin
                { Compile the finalize }
                FinalizationProcedure:=create_main_proc(make_mangledname('',curr.localsymtable,'finalize$'),potype_unitfinalize,curr.localsymtable);
                FinalizationProcedure.procdef.aliasnames.concat(make_mangledname('FINALIZE$',curr.localsymtable,''));
                FinalizationProcedure.parse_body;
              end
          end;

        { remove all units that we are waiting for that are already waiting for
          us => breaking up cycles }
        curr.remove_waitforunit_cycles;

        result:=curr.waitingforunit.count=0;

        { save all information that is needed for finishing the unit }
        New(finishstate);
        finishstate^.InitializationProcedure:=InitializationProcedure;
        finishstate^.FinalizationProcedure:=FinalizationProcedure;
        curr.finishstate:=finishstate;

        if result then
          result:=finish_compile_unit(curr)
        else
          curr.state:=ms_compiling_waitfinish;
      end;

    function parse_unit_interface_declarations(curr : TModule) : boolean;

      begin
        result:=true;
        SetCurrentModule(curr);

        { update the symtable }
        connect_loaded_units(curr,nil);

        { We must do this again, because units can have been added to the list while another task was being handled }
        curr.updatemaps;

        { consume the semicolon after maps have been updated else conditional compiling expressions
          might cause internal errors, see tw8611 }

        if curr.consume_semicolon_after_uses then
          begin
            consume(_SEMICOLON);
            curr.consume_semicolon_after_uses:=false;
          end;
        { now push our own symtable }
        SymTableStack.push(curr.GlobalSymTable);
        { Dump stack
          Write(curr.modulename^);
          symtablestack.dump;
          }

        { ... parse the declarations }
        Message1(parser_u_parsing_interface,curr.RealModuleName^);

        read_interface_declarations;


        { Export macros defined in the interface for macpas. The macros
          are put in the globalmacrosymtable that will only be used by other
          units. The current unit continues to use the localmacrosymtable }

        if (m_mac in CurrentSettings.ModeSwitches) then
          begin
            curr.GlobalMacroSymTable:=TMacroSymTable.create(true);
            curr.localmacrosymtable.SymList.ForEachCall(@copy_macro,curr);
          end;

        { leave when we got an error }
        if (ErrorCount>0) and not status.SkipError then
          begin
            Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
            status.SkipError:=true;
            SymTableStack.pop(curr.GlobalSymTable);
            curr.state:=ms_moduleerror;
{$ifdef DEBUG_NODE_XML}
            XMLFinalizeNodeFile('unit');
{$endif DEBUG_NODE_XML}
            exit(false);
          end;

        { Our interface is compiled, generate interface CRC and switch to implementation }
        if ErrorCount=0 then
          TPPUModule(curr).getppucrc;
        curr.in_interface:=false;
        curr.interface_compiled:=true;

        { Parse the implementation section }
        if (m_mac in CurrentSettings.ModeSwitches) and try_to_consume(_END) then
          curr.interface_only:=true
        else
          curr.interface_only:=false;

        parse_only:=false;

        { create static symbol table }
        curr.localsymtable:=TStaticSymTable.create(curr.RealModuleName^,curr.ModuleID);


        { Insert _GLOBAL_OFFSET_TABLE_ symbol if system uses it }
        maybe_load_got(curr);
        if not curr.interface_only then
          begin
            consume(_IMPLEMENTATION);
            Message1(unit_u_loading_implementation_units,curr.ModuleName^);
            { Read the implementation units }
            if CurrentScanner.token=_USES then
              begin
              parseusesclause(curr);
              if not loadunits(curr,false) or TModule.ctask_fast_backtrack then
                curr.state:=ms_compiling_waitimpl;
              { do not consume the semicolon yet, because the units in the uses clause
                may not yet be loaded and conditional compilation expressions may
                depend on symbols from those units }
              curr.consume_semicolon_after_uses:=True;
              end
            else
              curr.consume_semicolon_after_uses:=False;
          end;

        if curr.state in [ms_compiled,ms_processed] then
           begin
           // Writeln('Popping global symtable ?');
           SymTableStack.pop(curr.GlobalSymTable);
           end;

        if (ErrorCount=0) and TPPUModule(curr).dependent_module_crc_mismatch then
          { a dependent module needs recompile }
          curr.state:=ms_compiling_waitimpl;

        { Can we continue compiling ? }
        result:=curr.state<>ms_compiling_waitimpl;
        if result then
          result:=proc_unit_implementation(curr);
      end;

    function proc_unit(curr: TModule):boolean;
      var
         main_file: TInputFile;
         s1,s2  : ^string; {Saves stack space}
         unitname : AnsiString;
         unitname8 : string[8];
         feature : TFeature;
         load_ok : boolean;

      begin
         result:=true;

         if m_mac in CurrentSettings.ModeSwitches then
           curr.mode_switch_allowed:= false;

         consume(_UNIT);
         if curr.IsInitial then
          Status.IsExe:=false;

         unitname:=CurrentScanner.orgpattern;
         consume(_ID);
         while CurrentScanner.token=_POINT do
           begin
             consume(_POINT);
             unitname:=unitname+'.'+CurrentScanner.orgpattern;
             consume(_ID);
           end;

         { create filenames and unit name }
         main_file := CurrentScanner.inputfile;
         while Assigned(main_file.next) do
           main_file := main_file.next;

         new(s1);
         s1^:=curr.ModuleName^;
         curr.SetFileName(main_file.path+main_file.name,true);
         curr.SetModuleName(unitname);

{$ifdef DEBUG_NODE_XML}
         XMLInitializeNodeFile('unit', unitname);
{$endif DEBUG_NODE_XML}

         { check for system unit }
         new(s2);
         s2^:=upper(ChangeFileExt(ExtractFileName(main_file.name),''));
         unitname8:=copy(curr.ModuleName^,1,8);
         if (cs_check_unit_name in CurrentSettings.GlobalSwitches) and
            (
             not(
                 (curr.ModuleName^=s2^) or
                 (
                  (length(curr.ModuleName^)>8) and
                  (unitname8=s2^)
                 )
                )
             or
             (
              (length(s1^)>8) and
              (s1^<>curr.ModuleName^)
             )
            ) then
           Message2(unit_e_illegal_unit_name,curr.RealModuleName^,s1^);
         if (curr.ModuleName^='SYSTEM') then
           include(CurrentSettings.ModuleSwitches,cs_compilesystem);
         dispose(s2);
         dispose(s1);

         if (TargetInfo.system in systems_unit_program_exports) then
           exportlib.preparelib(curr.RealModuleName^);

         { parse hint directives }
         try_consume_hintdirective(curr.moduleoptions, curr.deprecatedmsg);

         consume(_SEMICOLON);

         { handle the global switches, do this before interface, because after interface has been
           read, all following directives are parsed as well }
         setupglobalswitches;

         { generate now the global symboltable,
           define first as local to overcome dependency conflicts }
         curr.localsymtable:=TGlobalSymTable.create(curr.ModuleName^,curr.ModuleID);

         { insert unitsym of this unit to prevent other units having
           the same name }
         TAbstractUnitSymTable(curr.localsymtable).insertunit(CUnitSym.create(curr.RealModuleName^,curr));

         { load default system unit, it must be loaded before interface is parsed
           else we cannot use e.g. feature switches before the next real token }
         if curr.IsInitial then
           Load_Packages;
         load_ok:=loadsystemunit(curr);

         { system unit is loaded, now insert feature defines }
         for feature:=low(TFeature) to high(TFeature) do
           if feature in Features then
             def_system_macro('FPC_HAS_FEATURE_'+FeatureStr[feature]);

         consume(_INTERFACE);

         { global switches are read, so further changes aren't allowed  }
         curr.in_global:=false;

         message1(unit_u_loading_interface_units,curr.ModuleName^);

         { update status }
         status.CurrentModule:=curr.RealModuleName^;

         { maybe turn off m_objpas if we are compiling objpas }
         if (curr.ModuleName^='OBJPAS') then
           exclude(CurrentSettings.ModeSwitches,m_objpas);

         { maybe turn off m_mac if we are compiling macpas }
         if (curr.ModuleName^='MACPAS') then
           exclude(CurrentSettings.ModeSwitches,m_mac);

         parse_only:=true;

         { load default units, like language mode units }
         if not(cs_compilesystem in CurrentSettings.ModuleSwitches) then
           load_ok:=loaddefaultunits(curr) and load_ok;

         { insert qualifier for the system unit (allows system.writeln) }
         if not(cs_compilesystem in CurrentSettings.ModuleSwitches) and
            (CurrentScanner.token=_USES) then
           begin
             // We do this as late as possible.
             if Assigned(curr) then
               curr.Loadlocalnamespacelist
             else
               CurrentNamespaceList:=Nil;
             parseusesclause(curr);
             load_ok:=loadunits(curr,true) and load_ok and not TModule.ctask_fast_backtrack;
             { has it been compiled at a higher level ?}
             if curr.state in [ms_compiled,ms_processed] then
               begin
                 Message1(parser_u_already_compiled,curr.RealModuleName^);
                 exit;
               end;

             curr.consume_semicolon_after_uses:=true;
           end
         else
           curr.consume_semicolon_after_uses:=false;

         { move the global symtable from the temporary local to global }
         CurrentModule.GlobalSymTable:=CurrentModule.localsymtable;
         CurrentModule.localsymtable:=nil;

         { Now we check if we can continue. }

         if not load_ok then
           curr.state:=ms_compiling_waitintf;

         { create whole program optimisation information (may already be
           updated in the interface, e.g., in case of classrefdef typed
           constants }
         curr.wpoinfo:=TUnitWPOInfo.create;

         { Can we continue compiling ? }
         result:=curr.state<>ms_compiling_waitintf;
         if result then
           result:=parse_unit_interface_declarations(curr);
      end;

    procedure module_is_done(curr: TModule);inline;
      begin
        dispose(PFinishState(curr.finishstate));
        curr.finishstate:=nil;
      end;

    function finish_compile_unit(module: TModule): boolean;

      function is_assembler_generated:boolean;
      var
        hal : TAsmListType;
      begin
        result:=false;
        if ErrorCount=0 then
          begin
            for hal:=low(TAsmListType) to high(TAsmListType) do
              if not CurrentAsmData.asmlists[hal].empty then
                begin
                  result:=true;
                  exit;
                end;
          end;
      end;

      var
{$ifdef EXTDEBUG}
        store_crc,
{$endif EXTDEBUG}
        force_init_final : boolean;
        InitializationProcedure,
        FinalizationProcedure : TCGProcInfo;
        ag , wait_dep: boolean;
        finishstate : TFinishState;
        old_module, wait_m: TModule;
      begin
         result:=true;
         { curr is now module }

         old_module:=CurrentModule;
         SetCurrentModule(module);

         if not Assigned(module.finishstate) then
           InternalError(2012091801);
         finishstate:=PFinishState(module.finishstate)^;

         FinalizationProcedure:=finishstate.FinalizationProcedure;
         InitializationProcedure:=finishstate.InitializationProcedure;

         { Generate specializations of objectdefs methods }
         generate_specialization_procs;

         { generate construction functions for all attributes in the unit:
           this must be done before writing the VMTs because
           during VMT writing  the extended field info is written }

         generate_attr_constrs(CurrentModule.used_rtti_attrs);

         { Generate VMTs }
         if ErrorCount=0 then
           begin
             write_vmts(module.GlobalSymTable,true);
             write_vmts(module.localsymtable,false);
           end;

         { add implementations for synthetic method declarations added by
           the compiler }
         add_synthetic_method_implementations(module.GlobalSymTable);
         add_synthetic_method_implementations(module.localsymtable);

         { if the unit contains ansi/widestrings, initialization and
           finalization code must be forced }
         force_init_final:=TGlobalSymTable(module.GlobalSymTable).needs_init_final or
                           TStaticSymTable(module.localsymtable).needs_init_final;

         { should we force unit initialization? }
         { this is a hack, but how can it be done better ? }
         { Now the sole purpose of this is to change 'init' to 'init_implicit',
           is it needed at all? (Sergei) }
         { it's needed in case cnodeutils.force_init = true }
         if (force_init_final or CNodeUtils.force_init) and
            (
              not Assigned(InitializationProcedure) or
              has_no_code(InitializationProcedure.code)
            ) then
           begin
             { first release the not used init procinfo }
             if Assigned(InitializationProcedure) then
               begin
                 release_proc_symbol(InitializationProcedure.procdef);
                 release_main_proc(module,InitializationProcedure);
               end;
             InitializationProcedure:=gen_implicit_initfinal(module,mf_init,module.localsymtable);
           end;
         if (force_init_final or CNodeUtils.force_final) and
            (
              not Assigned(FinalizationProcedure) or
              has_no_code(FinalizationProcedure.code)
            ) then
           begin
             { first release the not used finalize procinfo }
             if Assigned(FinalizationProcedure) then
               begin
                 release_proc_symbol(FinalizationProcedure.procdef);
                 release_main_proc(module,FinalizationProcedure);
               end;
             FinalizationProcedure:=gen_implicit_initfinal(module,mf_finalize,module.localsymtable);
           end;

         { Now both init and finalize bodies are read and it is known
           which variables are used in both init and finalize we can now
           generate the code. This is required to prevent putting a variable in
           a register that is also used in the finalize body (PFV) }
         if Assigned(InitializationProcedure) then
           begin
             if (force_init_final or CNodeUtils.force_init) or
                not(has_no_code(InitializationProcedure.code)) then
               begin
                 InitializationProcedure.code:=CNodeUtils.wrap_proc_body(InitializationProcedure.procdef,InitializationProcedure.code);
                 InitializationProcedure.generate_code_tree;
                 include(module.moduleflags,mf_init);
               end
             else
               release_proc_symbol(InitializationProcedure.procdef);
             InitializationProcedure.resetprocdef;
             release_main_proc(module,InitializationProcedure);
           end;
         if Assigned(FinalizationProcedure) then
           begin
             if force_init_final or
                CNodeUtils.force_init or
                not(has_no_code(FinalizationProcedure.code)) then
               begin
                 FinalizationProcedure.code:=CNodeUtils.wrap_proc_body(FinalizationProcedure.procdef,FinalizationProcedure.code);
                 FinalizationProcedure.generate_code_tree;
                 include(module.moduleflags,mf_finalize);
               end
             else
               release_proc_symbol(FinalizationProcedure.procdef);
             FinalizationProcedure.resetprocdef;
             release_main_proc(module,FinalizationProcedure);
           end;

         SymTableStack.pop(module.localsymtable);
         SymTableStack.pop(module.GlobalSymTable);

         { the last char should always be a point }
         { Do not attempt to read next token after dot,
           there may be a #0 when the unit was finished in a separate stage }
         consume_last_dot;

         { reset wpo flags for all defs }
         reset_all_defs(module);

         if (ErrorCount=0) then
           begin
             { tests, if all (interface) forwards are resolved }
             TStoredSymTable(module.GlobalSymTable).check_forwards;
             { check if all private fields are used }
             TStoredSymTable(module.GlobalSymTable).allprivatesused;

             { test static symtable }
             TStoredSymTable(module.localsymtable).allsymbolsused;
             TStoredSymTable(module.localsymtable).allprivatesused;
             TStoredSymTable(module.localsymtable).check_forwards;
             TStoredSymTable(module.localsymtable).checklabels;

             { used units }
             module.allunitsused;
           end;

         { leave when we got an error }
         if (ErrorCount>0) and not status.SkipError then
          begin
            Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
            status.SkipError:=true;
            module_is_done(module);
            module.state:=ms_moduleerror;
{$ifdef DEBUG_NODE_XML}
            XMLFinalizeNodeFile('unit');
{$endif DEBUG_NODE_XML}
            SetCurrentModule(old_module);
            exit(false);
          end;

         { if an Objective-C module, generate rtti and module info }
         MaybeGenerateObjectiveCImageInfo(module.GlobalSymTable,module.localsymtable);

         { do we need to add the variants unit? }
         maybeloadvariantsunit(module);

         { generate rtti/init tables }
         write_persistent_type_info(module.GlobalSymTable,true);
         write_persistent_type_info(module.localsymtable,false);

         { Tables }
         CNodeUtils.InsertThreadvars;

         { Resource strings }
         GenerateResourceStrings;

         { Widestring typed constants }
         CNodeUtils.InsertWideInits;

         { Resourcestring references }
         CNodeUtils.InsertResStrInits;

         { generate debuginfo }
         if (cs_debuginfo in CurrentSettings.ModuleSwitches) then
           CurrentDebugInfo.inserttypeinfo;

         { Linux unit aliases must be emitted before implementation symbols
           are released, and become part of the unit's cached object file. }
         if (TargetInfo.system in systems_linux) and Assigned(module._exports.first) then
           exportlib.generatelib;

         { generate imports }
         if module.ImportLibraryList.Count>0 then
           importlib.generatelib;

         { insert own objectfile, or say that it's in a library
           (no check for an .o when loading) }
         ag:=is_assembler_generated;
         if ag then
           insertobjectfile(module)
         else
           begin
             module.headerflags:=module.headerflags or uf_no_link;
             exclude(module.moduleflags,mf_has_stabs_debuginfo);
             exclude(module.moduleflags,mf_has_dwarf_debuginfo);
           end;

         if ag then
           begin
             { create callframe info }
             create_dwarf_frame;
             { assemble }
             create_objectfile(module);
           end;

        { remove all waits for this unit }
        module.remove_all_waitsforthisunit;

        { compute CRC }
        if ErrorCount=0 then
          begin
          wait_m:=module.find_used_unit_compiling;
          wait_dep:=TPPUModule(module).dependent_module_has_our_crc;
          if (wait_m<>nil) or wait_dep then
            begin
              { Some used units are still compiling, so their CRCs can change
                OR some dependent module waits for checking this module's CRC
                   (e.g. this module was recompiled and a ppu is waiting).
                Compute the final CRC of this module and wait.
                Needed for compiling circular dependent units. }
              {$IFDEF Debug_FreeParseMem}
              WriteLn('finish_compile_unit ',module.RealModuleName^,' waiting for used unit CRCs...');
              {$ENDIF}
              TPPUModule(module).getppucrc;
              module.crc_final:=true;
              module.state:=ms_compiled_waitcrc;
              SetCurrentModule(old_module);
              exit(false);
            end;
          end;
        SetCurrentModule(old_module);

        result:=finish_unit(module);
      end;

    function finish_unit(module: TModule): boolean;

      var
{$ifdef EXTDEBUG}
        store_crc,
{$endif EXTDEBUG}
        store_interface_crc,
        store_indirect_crc : cardinal;
{$ifdef debug_devirt}
        i : LongInt;
{$endif}
        HStatus : TFPCHeapStatus;
        old_module: TModule;

      begin
        {$IFDEF Debug_FreeParseMem}
        WriteLn('finish_unit ',module.RealModuleName^,' write ppu and free mem...');
        {$ENDIF}
        result:=ErrorCount=0;

        old_module:=CurrentModule;
        SetCurrentModule(module);

        { Write out the ppufile after the object file has been created }
        store_interface_crc:=module.interface_crc;
        store_indirect_crc:=module.indirect_crc;
{$ifdef EXTDEBUG}
        store_crc:=module.crc;
{$endif EXTDEBUG}
        if result then
          TPPUModule(module).writeppu;

        if not(cs_compilesystem in CurrentSettings.ModuleSwitches) then
          begin
            if store_interface_crc<>module.interface_crc then
              Message1(unit_u_interface_crc_changed,module.PPUFileName);
            if store_indirect_crc<>module.indirect_crc then
              Message1(unit_u_indirect_crc_changed,module.PPUFileName);
          end;
{$ifdef EXTDEBUG}
        if not(cs_compilesystem in CurrentSettings.ModuleSwitches) then
          if (store_crc<>module.crc) then
            Message1(unit_u_implementation_crc_changed,module.PPUFileName);
{$endif EXTDEBUG}

        { release unregistered defs/syms from the localsymtable }
        free_unregistered_localsymtable_elements(module);
        { release local symtables that are not needed anymore }
        free_localsymtables(module.GlobalSymTable);
        free_localsymtables(module.localsymtable);

        { leave when we got an error }
        if (ErrorCount>0) then
          begin
            if not status.SkipError then
              begin
                Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
                status.SkipError:=true;
              end;
            module_is_done(module);
            module.state := ms_moduleerror;
{$ifdef DEBUG_NODE_XML}
            XMLFinalizeNodeFile('unit');
{$endif DEBUG_NODE_XML}
            SetCurrentModule(old_module);
            exit;
          end;

{$ifdef debug_devirt}
        { print out all instantiated class/object types }
        WriteLn('constructed object/class/classreftypes in ',module.RealModuleName^);
        for i := 0 to module.wpoinfo.createdobjtypes.count-1 do
          begin
            write('  ',TDef(module.wpoinfo.createdobjtypes[i]).GetTypeName);
            case TDef(module.wpoinfo.createdobjtypes[i]).typ of
              objectdef:
                case TObjectDef(module.wpoinfo.createdobjtypes[i]).objecttype of
                  odt_object:
                    WriteLn(' (object)');
                  odt_class:
                    WriteLn(' (class)');
                  else
                    InternalError(2008101103);
                end;
              else
                InternalError(2008101104);
            end;
          end;

        for i := 0 to module.wpoinfo.createdclassrefobjtypes.count-1 do
          begin
            write('  Class Of ',TDef(module.wpoinfo.createdclassrefobjtypes[i]).GetTypeName);
            case TDef(module.wpoinfo.createdclassrefobjtypes[i]).typ of
              objectdef:
                case TObjectDef(module.wpoinfo.createdclassrefobjtypes[i]).objecttype of
                  odt_class:
                    WriteLn(' (classrefdef)');
                  else
                    InternalError(2008101105);
                end
              else
                InternalError(2008101102);
            end;
          end;
{$endif debug_devirt}

        Message1(unit_u_finished_compiling,module.ModuleName^);

        module_is_done(module);
        module.end_of_parsing;

{$ifdef DEBUG_NODE_XML}
        XMLFinalizeNodeFile('unit');
{$endif DEBUG_NODE_XML}
        if ((status.verbosity and VStatus)<>0) then
        begin
          {$IF defined(Debug_FreeParseMem)}
          WriteLn('finish_unit ',module.RealModuleName^,' wrote ppu and freed mem.');
          {$ENDIF}
          HStatus:=GetFPCHeapStatus;
          WriteLn(DStr(HStatus.CurrHeapUsed shr 10),'/',DStr(HStatus.CurrHeapSize shr 10),' Kb Used');
        end;

        module.state:=ms_compiled;

        SetCurrentModule(old_module);
      end;

    function proc_package(curr: TModule) : boolean;
      var
        main_file : TInputFile;
        module_name: AnsiString;
        feature : TFeature;
      begin
         Result:=True;
         Status.IsPackage:=true;
         Status.IsExe:=true;
         parse_only:=false;
         {InitializationProcedure:=nil;
         FinalizationProcedure:=nil;}

         if not (tf_supports_packages in TargetInfo.flags) then
           begin
             message1(parser_e_packages_not_supported,TargetInfo.name);
             curr.state:=ms_moduleerror;
             status.SkipError:=true;
             exit(false);
           end;

         if not RelocSectionSetExplicitly then
           RelocSection:=true;

         { get correct output names }
         main_file := CurrentScanner.inputfile;
         while Assigned(main_file.next) do
           main_file := main_file.next;

         curr.SetFileName(main_file.path+main_file.name,true);

         { consume _PACKAGE word }
         consume(_ID);

         module_name:=CurrentScanner.orgpattern;
         consume(_ID);
         while CurrentScanner.token=_POINT do
           begin
             consume(_POINT);
             module_name:=module_name+'.'+CurrentScanner.orgpattern;
             consume(_ID);
           end;

         curr.setmodulename(module_name);
         curr.IsPackage:=true;
         if OutputFileName='' then
           curr.SharedLibFileName:=ExtractFilePath(curr.SharedLibFileName)+
             module_name+NexusPackageLibraryExtension;
         exportlib.preparelib(module_name);

         if tf_library_needs_pic in TargetInfo.flags then
           include(CurrentSettings.ModuleSwitches,cs_create_pic);

         { setup things using the switches, do this before the semicolon, because after the semicolon has been
           read, all following directives are parsed as well }

         setupglobalswitches;

{$ifdef DEBUG_NODE_XML}
         XMLInitializeNodeFile('package', module_name);
{$endif DEBUG_NODE_XML}

         consume(_SEMICOLON);

         { global switches are read, so further changes aren't allowed }
         curr.in_global:=false;

         { set implementation flag }
         curr.in_interface:=false;
         curr.interface_compiled:=true;

         { insert after the unit symbol tables the static symbol table }
         { of the program                                             }
         curr.localsymtable:=TStaticSymTable.create(curr.RealModuleName^,curr.ModuleID);

         { ensure that no packages are picked up from the options }
         PackageList.clear;

         { There should always be a requires, except for the system package. So we load here }
         if Assigned(curr) then
           curr.Loadlocalnamespacelist
         else
           CurrentNamespaceList:=Nil;

         {Read the packages used by the package we compile.}
         if (CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_REQUIRES) then
           begin
             { consume _REQUIRES word }
             consume(_ID);
             while true do
               begin
                 if CurrentScanner.token=_ID then
                   begin
                     module_name:=CurrentScanner.orgpattern;
                     consume(_ID);
                     while CurrentScanner.token=_POINT do
                       begin
                         consume(_POINT);
                         module_name:=module_name+'.'+CurrentScanner.orgpattern;
                         consume(_ID);
                       end;
                     Add_Package(module_name,false,true);
                   end
                 else
                   consume(_ID);
                 if CurrentScanner.token=_COMMA then
                   consume(_COMMA)
                 else
                   break;
               end;
             consume(_SEMICOLON);
           end;

         { now load all packages, so that we can determine whether a unit is
           already provided by one of the loaded packages }
         Load_Packages;

         if PackageList.Count>0 then
           begin
             { this means the SYSTEM unit *must* be part of one of the required
               packages, so load it }
             AddUnit(curr,'system',false);
             systemunit:=TGlobalSymTable(SymTableStack.top);
             load_intern_types;
             checksystemcharwidth;
             { system unit is loaded, now insert feature defines }
             for feature:=low(TFeature) to high(TFeature) do
               if feature in Features then
                 def_system_macro('FPC_HAS_FEATURE_'+FeatureStr[feature]);
           end;

         { Register contained units before yielding to the existing scheduler. }
         curr.consume_semicolon_after_uses:=false;
         if (CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_CONTAINS) then
           begin
             { Cached contained units can dereference built-in types while
               loading their dependencies, before finish_package is reached. }
             if not Assigned(systemunit) then
               loadsystemunit(curr);
             parseusesclause(curr,true);
             loadunits(curr,false);
             curr.consume_semicolon_after_uses:=true;
           end;
         curr.state:=ms_compiling_wait;
         result:=false;
      end;

    function finish_package(curr: TModule) : boolean;
      var
        hp,hp2 : TModule;
        pkg : TPCPPackage;
        main_procinfo : TCGProcInfo;
        force_init_final : boolean;
        uu : TUsedUnit;
        pentry : PPackageEntry;
        i : LongInt;
      begin
         result:=true;
         SetCurrentModule(curr);
         main_procinfo:=nil;
         { A package without requirements can provide System itself. }
         hp:=TModule(loaded_units.first);
         while Assigned(hp) do
           begin
             if (hp.ModuleName^='SYSTEM') and not Assigned(systemunit) then
               begin
                 systemunit:=TGlobalSymTable(hp.GlobalSymTable);
                 load_intern_types;
                 checksystemcharwidth;
               end;
             hp:=TModule(hp.next);
           end;
         if not Assigned(systemunit) then
           Comment(VFatal,'Package '+curr.RealModuleName^+' does not contain or require the System unit');
         pkg:=TPCPPackage.create(curr.RealModuleName^);
         { All units are read, now give them a number }
         curr.updatemaps;
         connect_loaded_units(curr,nil);
         if curr.consume_semicolon_after_uses then
           begin
             consume(_SEMICOLON);
             curr.consume_semicolon_after_uses:=false;
           end;

         hp:=TModule(loaded_units.first);
         while Assigned(hp) do
           begin
             if (hp<>curr) and not Assigned(hp.package) then
               begin
                 if mf_package_deny in hp.moduleflags then
                   message1(package_e_unit_deny_package,hp.RealModuleName^);
                 { part of the package's used, aka contained units? }
                 uu:=TUsedUnit(curr.used_units.first);
                 while Assigned(uu) do
                   begin
                     if uu.u=hp then
                       break;
                     uu:=TUsedUnit(uu.next);
                   end;
                 if not Assigned(uu) then
                   message2(package_n_implicit_unit_import,hp.RealModuleName^,curr.RealModuleName^);
               end;
             { was this unit listed as a contained unit? If so => error }
             if (hp<>curr) and Assigned(hp.package) then
               begin
                 uu:=TUsedUnit(curr.used_units.first);
                 while Assigned(uu) do
                   begin
                     if uu.u=hp then
                       break;
                     uu:=TUsedUnit(uu.next);
                   end;
                 if Assigned(uu) then
                   message2(package_e_unit_already_contained_in_package,hp.RealModuleName^,hp.package.RealPackageName^);
               end;
             hp:=TModule(hp.next);
           end;

         {Insert the name of the main program into the symbol table.}
         if curr.RealModuleName^<>'' then
           TAbstractUnitSymTable(curr.localsymtable).insertunit(CUnitSym.create(curr.RealModuleName^,curr));

         Message1(parser_u_parsing_implementation,curr.MainSource);

         SymTableStack.push(curr.localsymtable);

         { create whole program optimisation information }
         curr.wpoinfo:=TUnitWPOInfo.create;

         { should we force unit initialization? }
         force_init_final:=TStaticSymTable(curr.localsymtable).needs_init_final;
         if force_init_final or CNodeUtils.force_init then
           {InitializationProcedure:=gen_implicit_initfinal(mf_init,curr.localsymtable)};

         { Add symbol to the exports section for win32 so smartlinking a
           DLL will include the edata section }
         if Assigned(exportlib) and
            (TargetInfo.system=system_i386_win32) and
            (mf_has_exports in curr.moduleflags) then
           CurrentAsmData.asmlists[al_procedures].concat(TAIConst.createname(make_mangledname('EDATA',curr.localsymtable,''),0));

         { all labels must be defined before generating code }
         if ErrorCount=0 then
           TStoredSymTable(curr.localsymtable).checklabels;

         SymTableStack.pop(curr.localsymtable);

         { consume the last point }
         consume(_END);
         consume(_POINT);

         if (ErrorCount=0) then
           begin
             { test static symtable }
             TStoredSymTable(curr.localsymtable).allsymbolsused;
             TStoredSymTable(curr.localsymtable).allprivatesused;
             TStoredSymTable(curr.localsymtable).check_forwards;

             { Note: all contained units are considered as used }
           end;

         if TargetInfo.system in systems_all_windows then
           begin
             SymTableStack.push(curr.localsymtable);
             main_procinfo:=create_main_proc('_PkgEntryPoint',potype_pkgstub,curr.localsymtable);
             main_procinfo.procdef.aliasnames.concat('_DLLMainCRTStartup');
             main_procinfo.code:=generate_pkg_stub(main_procinfo.procdef);
             main_procinfo.generate_code;
             SymTableStack.pop(curr.localsymtable);
           end;

{$ifdef DEBUG_NODE_XML}
         XMLFinalizeNodeFile('package');
{$endif DEBUG_NODE_XML}

         { leave when we got an error }
         if (ErrorCount>0) and not status.SkipError then
           begin
             Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
             status.SkipError:=true;
             curr.state:=ms_moduleerror;
             pkg.free;
             pkg := nil;
             exit(false);
           end;

         { remove all unused units, this happens when units are removed
           from the uses clause in the source and the ppu was already being loaded }
         hp:=TModule(loaded_units.first);
         while Assigned(hp) do
          begin
            hp2:=hp;
            hp:=TModule(hp.next);
            if Assigned(hp2.package) then
              Add_Package_Unit_Ref(hp2.package);
            if hp2.is_unit and
               not Assigned(hp2.GlobalSymTable) then
              loaded_units.remove(hp2);
          end;

         exportlib.ignoreduplicates:=true;

         if TargetInfo.system in [system_x86_64_win64,system_x86_64_linux] then
           begin
             CNodeUtils.InsertInitFinalTable(curr);
             CNodeUtils.InsertThreadvarTablesTable;
             CNodeUtils.InsertResourceTablesTable;
             CNodeUtils.InsertWideInitsTablesTable;
             CNodeUtils.InsertResStrTablesTable;
             Emit_Package_Descriptor;
             if TargetInfo.system=system_x86_64_linux then
               begin
                 CNodeUtils.InsertResourceInfo(CheckResourcesUsed(curr));
                 export.exportname('FPC_RESLOCATION',[eo_name]);
               end;
           end;

         { force exports }
         uu:=TUsedUnit(UsedUnits.first);
         while Assigned(uu) do
           begin
             if not Assigned(systemunit) and (uu.u.ModuleName^='SYSTEM') then
               begin
                 systemunit:=TGlobalSymTable(uu.u.GlobalSymTable);
                 load_intern_types;
                 checksystemcharwidth;
               end;
             if not Assigned(uu.u.package) then
               Export_Unit(uu.u);

             uu:=TUsedUnit(uu.next);
           end;

         { generate debuginfo }
         if (cs_debuginfo in CurrentSettings.ModuleSwitches) then
           CurrentDebugInfo.inserttypeinfo;

         exportlib.generatelib;

         exportlib.ignoreduplicates:=false;

         { create import libraries for all packages }
         if PackageList.count>0 then
           CreateImportLibFromExternals;

         { generate imports }
         if curr.ImportLibraryList.Count>0 then
           importlib.generatelib;

         { Reference all DEBUGINFO sections from the main .fpc section }
         if (cs_debuginfo in CurrentSettings.ModuleSwitches) then
           CurrentDebugInfo.referencesections(CurrentAsmData.asmlists[al_procedures]);

         { we add all loaded units that are not part of a package to the
           package; this includes units in the "contains" section as well
           as implicitly imported ones }
         hp:=TModule(loaded_units.first);
         while Assigned(hp) do
          begin
            if (hp<>curr) then
              begin
                if not Assigned(hp.package) then
                  begin
                    pkg.AddUnit(hp);
                    Check_For_Indirect_Package_Usages(hp.used_units);
                  end
                else
                  begin
                    pentry:=PPackageEntry(PackageList.find(hp.package.PackageName^));
                    if not Assigned(pentry) then
                      InternalError(2015112301);
                    pkg.Add_Required_Package(hp.package);
                  end;
              end;
            hp:=TModule(hp.next);
          end;

         { A declared dependency also owns initialization/lifetime work
           when none of its units contributed a referenced symbol. }
         for i:=0 to PackageList.count-1 do
           begin
             pentry:=PPackageEntry(PackageList[i]);
             if pentry^.direct then
               pkg.Add_Required_Package(pentry^.package);
           end;
         pkg.InitModuleInfo(curr);

         { Metadata is part of the package object before native linking. }
         pkg.SavePCP;

         { insert own objectfile }
         insertobjectfile(curr);

         { assemble and link }
         create_objectfile(curr);

         { We might need the symbols info if not using
           the default do_extractsymbolinfo
           which is a dummy function PM }
         NeedSymbolInfo:=Do_ExtractSymbolInfo<>@Def_ExtractSymbolInfo;
         { release all local symtables that are not needed anymore }
         if (not NeedSymbolInfo) then
           free_localsymtables(curr.localsymtable);

         { leave when we got an error }
         if (ErrorCount>0) and not status.SkipError then
          begin
            Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
            status.SkipError:=true;
            curr.state:=ms_moduleerror;
            pkg.free;
            pkg := nil;
            exit(false);
          end;

         if (not curr.is_unit) then
           begin
             { create the executable when we are at level 1 }
             if (curr.IsInitial) then
               begin
                 { create global resource file by collecting all resource files }
                 CollectResourceFiles;
                 { write .def file }
                 if (cs_link_deffile in CurrentSettings.GlobalSwitches) then
                   deffile.writefile;

                 if DrainClangAssemblerQueue then
                   begin
                     { The sequential continuation still visits the package
                       after linking. Remove its dependency edges before freeing
                       their modules, as proc_create_executable does. }
                     curr.used_units.free;
                     curr.used_units:=TLinkedList.Create;
                     { insert all .o files from all loaded units and
                       unload the units, we don't need them anymore.
                       Keep the curr because that is still needed }
                     hp:=TModule(loaded_units.first);
                     while Assigned(hp) do
                      begin
                        { only link in those units which should become part of this
                          package }
                        if not Assigned(hp.package) then
                          linker.AddModuleFiles(hp);
                        hp2:=TModule(hp.next);
                        if (hp<>curr) and
                           (not NeedSymbolInfo) then
                          begin
                            loaded_units.remove(hp);
                            hp.free;
                            hp := nil;
                          end;
                        hp:=hp2;
                      end;
                     { add the library of directly used packages }
                     Add_Package_Libs(linker);
                     { and now link the package library }
                     linker.MakeSharedLibrary
                   end
               end;

             { Give Fatal with error count for linker errors }
             if (ErrorCount>0) and not status.SkipError then
              begin
                Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
                status.SkipError:=true;
                curr.state:=ms_moduleerror;
                result:=false;
              end;

             pkg.free;
             pkg := nil;
          end;
         if result then
           begin
             curr.crc_final:=true;
             curr.state:=ms_compiled;
           end;
      end;

    procedure proc_create_executable(curr, sysinitmod: TModule; IsLibrary : boolean);

      var
        program_uses_checkpointer : boolean;
        hp,hp2 : TModule;

      begin
            { create global resource file by collecting all resource files }
            CollectResourceFiles;
            { write .def file }
            if (cs_link_deffile in CurrentSettings.GlobalSwitches) then
             deffile.writefile;
            if not DrainClangAssemblerQueue then
              exit;
            { link SysInit (if any) first, to have behavior consistent with
              assembler startup files }
            if Assigned(sysinitmod) then
              linker.AddModuleFiles(sysinitmod);
            { Does any unit use checkpointer function }
            program_uses_checkpointer:=false;
            { before freeing modules, free used_units }
            curr.used_units.free;
            curr.used_units:=TLinkedList.Create;
            { insert all .o files from all loaded units and
              unload the units, we don't need them anymore.
              Keep the curr because that is still needed }
            hp:=TModule(loaded_units.first);
            while Assigned(hp) do
             begin
               if (hp<>sysinitmod) and not Assigned(hp.package) then
                 begin
                   linker.AddModuleFiles(hp);
                   if mf_checkpointer_called in hp.moduleflags then
                     program_uses_checkpointer:=true;
                 end;
               hp2:=TModule(hp.next);
               if Assigned(hp.package) then
                 Add_Package_Unit_Ref(hp.package);
               if (hp<>curr) and
                  (not NeedSymbolInfo) then
                 begin
                   loaded_units.remove(hp);
                   hp.free;
                   hp := nil;
                 end;
               hp:=hp2;
             end;
            { free also unneeded units we didn't free before }
            if not NeedSymbolInfo then
              unloaded_units.Clear;
            { Does any unit use checkpointer function }
            if program_uses_checkpointer then
              Message1(link_w_program_uses_checkpointer,curr.ModuleName^);

            { add all directly used packages as libraries }
            Add_Package_Libs(linker);
            { finally we can create an executable }
            if curr.IsLibrary then
              linker.MakeSharedLibrary
            else
              linker.MakeExecutable;

            { collect all necessary information for whole-program optimization }
            wpoinfomanager.extractwpoinfofromprogram;

      end;

    procedure proc_program_after_parsing(curr : TModule; IsLibrary : boolean);

      var
        sysinitmod, hp,hp2 : TModule;
        resources_used : boolean;

      begin
        sysinitmod:=nil;
        hp:=nil;
        hp2:=nil;
        resources_used:=false;

  {$ifdef DEBUG_NODE_XML}
        if IsLibrary then
          XMLFinalizeNodeFile('library')
        else
          XMLFinalizeNodeFile('program');
  {$endif DEBUG_NODE_XML}

        { reset wpo flags for all defs }
        reset_all_defs(curr);

        if (ErrorCount=0) then
          begin
            { test static symtable }
            TStoredSymTable(curr.localsymtable).allsymbolsused;
            TStoredSymTable(curr.localsymtable).allprivatesused;
            TStoredSymTable(curr.localsymtable).check_forwards;

            curr.allunitsused;
          end;

        { leave when we got an error }
        if (ErrorCount>0) and not status.SkipError then
          begin
            Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
            status.SkipError:=true;
            curr.state:=ms_moduleerror;
            exit;
          end;

        { remove all unused units, this happens when units are removed
          from the uses clause in the source and the ppu was already being loaded }
        hp:=TModule(loaded_units.first);
        while Assigned(hp) do
         begin
           hp2:=hp;
           hp:=TModule(hp.next);
           if hp2.is_unit and
              not Assigned(hp2.GlobalSymTable) then
               begin
                 loaded_units.remove(hp2);
                 unloaded_units.concat(hp2);
               end;
         end;

        { do we need to add the variants unit? }
        maybeloadvariantsunit(curr);

        { Now that everything has been compiled we know if we need resource
          support. If not, remove the unit. }
        resources_used:=MaybeRemoveResUnit(curr);

        linker.initsysinitunitname;
        if (TargetInfo.system in [system_x86_64_win64,system_x86_64_linux]) and
           Assigned(find_module_from_symtable(systemunit).package) then
          linker.sysinitunit:='sysinitpkg';
        if TargetInfo.system in systems_internal_sysinit then
        begin
          { add start/halt unit }
          sysinitmod:=AddUnit(curr,linker.sysinitunit);
        end
        else
          sysinitmod:=nil;

        CNodeUtils.InsertThreadvars;

        { generate rtti/init tables }
        write_persistent_type_info(curr.localsymtable,false);

        { if an Objective-C module, generate rtti and module info }
        MaybeGenerateObjectiveCImageInfo(nil,curr.localsymtable);

        { generate debuginfo }
        if (cs_debuginfo in CurrentSettings.ModuleSwitches) then
          CurrentDebugInfo.inserttypeinfo;

        if IsLibrary or (TargetInfo.system in systems_unit_program_exports) then
          exportlib.generatelib;

        { Reference all DEBUGINFO sections from the main .fpc section }
        if (cs_debuginfo in CurrentSettings.ModuleSwitches) then
          CurrentDebugInfo.referencesections(CurrentAsmData.asmlists[al_procedures]);

        { Resource strings }
        GenerateResourceStrings;

        { Windows widestring needing initialization }
        CNodeUtils.InsertWideInits;

        { Resourcestring references (const foo:string=someresourcestring) }
        CNodeUtils.InsertResStrInits;

        { insert Tables and StackLength }
        CNodeUtils.InsertInitFinalTable(curr);
        CNodeUtils.InsertThreadvarTablesTable;
        CNodeUtils.InsertResourceTablesTable;
        CNodeUtils.InsertWideInitsTablesTable;
        CNodeUtils.InsertResStrTablesTable;
        CNodeUtils.InsertMemorySizes;

        if (TargetInfo.system in [system_x86_64_win64,system_x86_64_linux]) and
           Assigned(find_module_from_symtable(systemunit).package) then
          Emit_Package_Descriptor;

        { Insert symbol to resource info }
        CNodeUtils.InsertResourceInfo(resources_used);

        { create callframe info }
        create_dwarf_frame;

        { create import library for all packages }
        if PackageList.count>0 then
          CreateImportLibFromExternals;

        { generate imports }
        if curr.ImportLibraryList.Count>0 then
          importlib.generatelib;

        { insert own objectfile }
        insertobjectfile(curr);

        { assemble and link }
        create_objectfile(curr);

        { We might need the symbols info if not using
          the default do_extractsymbolinfo
          which is a dummy function PM }
        NeedSymbolInfo:=
          (Do_ExtractSymbolInfo<>@Def_ExtractSymbolInfo) or
          ((CurrentSettings.GenWPOptimizerSwitches*WPOptimizationsNeedingAllUnitInfo)<>[]);

        { release all local symtables that are not needed anymore }
        if (not NeedSymbolInfo) then
          free_localsymtables(curr.localsymtable);

        { leave when we got an error }
        if (ErrorCount>0) and not status.SkipError then
          begin
            Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
            status.SkipError:=true;
            curr.state:=ms_moduleerror;
            exit;
          end;
        { create the executable when we are at level 1 }

        if (not curr.is_unit) and (curr.IsInitial) then
          proc_create_executable(curr,sysinitmod,IsLibrary);

        { Give Fatal with error count for linker errors }
        if (ErrorCount>0) and not status.SkipError then
         begin
           Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
           status.SkipError:=true;
         end;

        curr.crc_final:=true;
        curr.state:=ms_compiled;

      end;

    function proc_program_declarations(curr : TModule; IsLibrary : boolean) : boolean;

      var
        initpd    : TProcDef;
        FinalizationProcedure,
        InitializationProcedure,
        main_procinfo : TCGProcInfo;
        force_init_final : boolean;

      begin
        result:=true;
        main_procinfo:=nil;
        InitializationProcedure:=nil;
        FinalizationProcedure:=nil;

        SetCurrentModule(curr);

        { All units are read, now give them a number }
        curr.updatemaps;

        connect_loaded_units(curr,nil);

        { consume the semicolon after maps have been updated else conditional compiling expressions
          might cause internal errors, see tw8611 }
        if curr.consume_semicolon_after_uses then
          begin
            consume(_SEMICOLON);
            curr.consume_semicolon_after_uses:=false;
          end;

        {Insert the name of the main program into the symbol table.}
        if curr.RealModuleName^<>'' then
          TAbstractUnitSymTable(curr.localsymtable).insertunit(CUnitSym.create(curr.RealModuleName^,curr));

        Message1(parser_u_parsing_implementation,curr.MainSource);

        SymTableStack.push(curr.localsymtable);


        { Insert _GLOBAL_OFFSET_TABLE_ symbol if system uses it }
        maybe_load_got(curr);

        { create whole program optimisation information }
        curr.wpoinfo:=TUnitWPOInfo.create;

        { The program initialization needs an alias, so it can be called
          from the bootstrap code.}
        if IsLibrary then
         begin
           initpd:=nil;
           { ToDo: other systems that use indirect entry info, but check back with Windows! }
           { we need to call FPC_LIBMAIN in sysinit which in turn will call PascalMain -> create dummy stub }
           if TargetInfo.system in systems_darwin then
             begin
               main_procinfo:=create_main_proc(make_mangledname('sysinitcallthrough',curr.localsymtable,'stub'),potype_libmainstub,curr.localsymtable);
               call_through_new_name(main_procinfo.procdef,TargetInfo.cprefix+'FPC_LIBMAIN');
               initpd:=main_procinfo.procdef;
               main_procinfo.free;
               main_procinfo := nil;
             end;

           main_procinfo:=create_main_proc(make_mangledname('',curr.localsymtable,MainAliasName),potype_proginit,curr.localsymtable);
           { Win32 startup code needs a single name }
           if not(TargetInfo.system in systems_darwin) then
             main_procinfo.procdef.aliasnames.concat('PASCALMAIN')
           else
             main_procinfo.procdef.aliasnames.concat(TargetInfo.Cprefix+'PASCALMAIN');

           if not(TargetInfo.system in systems_darwin) then
             initpd:=main_procinfo.procdef;

           CNodeUtils.RegisterModuleInitFunction(initpd);
         end
        else if (TargetInfo.system in systems_darwin) then
          begin
            { create a stub with the name of the desired main routine, with
              the same signature as the C "main" function, and call through to
              FPC_SYSTEMMAIN, which will initialise everything based on its
              parameters. This function cannot be in the system unit, because
              its name can be configured on the command line (for use with e.g.
              SDL, where the main function should be called SDL_main) }
            main_procinfo:=create_main_proc(MainAliasName,potype_mainstub,curr.localsymtable);
            call_through_new_name(main_procinfo.procdef,TargetInfo.cprefix+'FPC_SYSTEMMAIN');
            main_procinfo.free;
            { now create the PASCALMAIN routine (which will be called from
              FPC_SYSTEMMAIN) }
            main_procinfo:=create_main_proc('PASCALMAIN',potype_proginit,curr.localsymtable);
          end
        else
          begin
            main_procinfo:=create_main_proc(MainAliasName,potype_proginit,curr.localsymtable);
            main_procinfo.procdef.aliasnames.concat('PASCALMAIN');
          end;
        main_procinfo.parse_body;
        { save file pos for debuginfo }
        curr.mainfilepos:=main_procinfo.entrypos;

        { finalize? }
        if CurrentScanner.token=_FINALIZATION then
          begin
             { Parse the finalize }
             FinalizationProcedure:=create_main_proc(make_mangledname('',curr.localsymtable,'finalize$'),potype_unitfinalize,curr.localsymtable);
             FinalizationProcedure.procdef.aliasnames.insert(make_mangledname('FINALIZE$',curr.localsymtable,''));
             FinalizationProcedure.procdef.aliasnames.concat('PASCALFINALIZE');
             FinalizationProcedure.parse_body;
          end;

        { Generate specializations of objectdefs methods }
        if ErrorCount=0 then
          generate_specialization_procs;

        { generate construction functions for all attributes in the program }
        { before write_vmts that assume attributes for methods is ready }
        generate_attr_constrs(curr.used_rtti_attrs);

        { Generate VMTs }
        if ErrorCount=0 then
          write_vmts(curr.localsymtable,false);

        { add implementations for synthetic method declarations added by
          the compiler }
        add_synthetic_method_implementations(curr.localsymtable);

        { should we force unit initialization? }
        force_init_final:=TStaticSymTable(curr.localsymtable).needs_init_final;
        if force_init_final or CNodeUtils.force_init then
          InitializationProcedure:=gen_implicit_initfinal(curr,mf_init,curr.localsymtable);

        { Add symbol to the exports section for win32 so smartlinking a
          DLL will include the edata section }
        if Assigned(exportlib) and
           (TargetInfo.system=system_i386_win32) and
           (mf_has_exports in curr.moduleflags) then
          CurrentAsmData.asmlists[al_procedures].concat(TAIConst.createname(make_mangledname('EDATA',curr.localsymtable,''),0));

        if (force_init_final or CNodeUtils.force_final) and
           (
             not Assigned(FinalizationProcedure)
             or has_no_code(FinalizationProcedure.code)
           ) then
          begin
            { first release the not used finalize procinfo }
            if Assigned(FinalizationProcedure) then
              begin
                release_proc_symbol(FinalizationProcedure.procdef);
                release_main_proc(curr,FinalizationProcedure);
              end;
            FinalizationProcedure:=gen_implicit_initfinal(curr,mf_finalize,curr.localsymtable);
          end;

         { the finalization routine of libraries is generic (and all libraries need to }
         { be finalized, so they can finalize any units they use                       }
         { Place in "pure assembler" list so that the llvm assembler writer
           directly emits the generated directives }
         if (IsLibrary) then
           CNodeUtils.RegisterModuleFiniFunction(search_system_proc('fpc_lib_exit'));

        { all labels must be defined before generating code }
        if ErrorCount=0 then
          TStoredSymTable(curr.localsymtable).checklabels;

        { See remark in unit init/final }
        main_procinfo.generate_code_tree;
        main_procinfo.resetprocdef;
        release_main_proc(curr,main_procinfo);
        if Assigned(InitializationProcedure) then
          begin
            { initialization can be implicit only }
            include(curr.moduleflags,mf_init);
            InitializationProcedure.code:=CNodeUtils.wrap_proc_body(InitializationProcedure.procdef,InitializationProcedure.code);
            InitializationProcedure.generate_code;
            InitializationProcedure.resetprocdef;
            release_main_proc(curr,InitializationProcedure);
          end;
        if Assigned(FinalizationProcedure) then
          begin
            if force_init_final or
               CNodeUtils.force_init or
               not(has_no_code(FinalizationProcedure.code)) then
              begin
                FinalizationProcedure.code:=CNodeUtils.wrap_proc_body(FinalizationProcedure.procdef,FinalizationProcedure.code);
                FinalizationProcedure.generate_code_tree;
                include(curr.moduleflags,mf_finalize);
              end;
            FinalizationProcedure.resetprocdef;
            release_main_proc(curr,FinalizationProcedure);
          end;

        SymTableStack.pop(curr.localsymtable);

        { consume the last point }
        consume(_POINT);


        proc_program_after_parsing(curr,IsLibrary);


      end;

    procedure proc_library_header(curr: TModule);
      var
        program_name : AnsiString;

      begin
        consume(_LIBRARY);
        program_name:=CurrentScanner.orgpattern;
        consume(_ID);
        while CurrentScanner.token=_POINT do
         begin
           consume(_POINT);
           program_name:=program_name+'.'+CurrentScanner.orgpattern;
           consume(_ID);
         end;
        curr.setmodulename(program_name);
        curr.IsLibrary:=true;
        exportlib.preparelib(program_name);

        if tf_library_needs_pic in TargetInfo.flags then
         begin
           include(CurrentSettings.ModuleSwitches,cs_create_pic);
           { also set create_pic for all unit compilation }
           include(InitSettings.ModuleSwitches,cs_create_pic);
         end;

        { setup things using the switches, do this before the semicolon, because after the semicolon has been
         read, all following directives are parsed as well }
        setupglobalswitches;

        {$ifdef DEBUG_NODE_XML}
        XMLInitializeNodeFile('library', program_name);
        {$endif DEBUG_NODE_XML}
      end;

    type
      TProgramParam = record
        name : AnsiString;
        nr : dword;
      end;
      TProgramParamArray = array of TProgramParam;

      procedure proc_program_header(curr: TModule; out sc : TProgramParamArray);

        var
          program_name : AnsiString;
          paramnum : integer;

        begin
          sc:=nil;
          consume(_PROGRAM);
          program_name:=CurrentScanner.orgpattern;
          consume(_ID);
          while CurrentScanner.token=_POINT do
            begin
              consume(_POINT);
              program_name:=program_name+'.'+CurrentScanner.orgpattern;
              consume(_ID);
            end;
          curr.setmodulename(program_name);
          if (TargetInfo.system in systems_unit_program_exports) then
            exportlib.preparelib(program_name);
          if CurrentScanner.token=_LKLAMMER then
            begin
               consume(_LKLAMMER);
               paramnum:=1;
               repeat
                 if m_isolike_program_para in CurrentSettings.ModeSwitches then
                   begin
                     if (CurrentScanner.pattern<>'INPUT') and (CurrentScanner.pattern<>'OUTPUT') then
                       begin
                         { the symtablestack is not setup here, so text must be created later on }
                         SetLength(sc,length(sc)+1);
                         with sc[high(sc)] do
                           begin
                             name:=CurrentScanner.pattern;
                             nr:=paramnum;
                           end;
                         inc(paramnum);
                       end;
                   end;
                 consume(_ID);
               until not try_to_consume(_COMMA);
               consume(_RKLAMMER);
            end;

          { setup things using the switches, do this before the semicolon, because after the semicolon has been
            read, all following directives are parsed as well }
          setupglobalswitches;


{$ifdef DEBUG_NODE_XML}
          XMLInitializeNodeFile('program', program_name);
{$endif DEBUG_NODE_XML}
        end;

    function proc_program(curr: TModule; IsLibrary : boolean) : boolean;

      var
         main_file : TInputFile;
         consume_semicolon_after_loaded : boolean;
         ps : TProgramParaSym;
         textsym : TTypeSym;
         sc : TProgramParamArray;
         i : LongInt;
         feature : TFeature;
         load_ok : boolean;

      begin
         result:=true;
         Status.IsLibrary:=IsLibrary;
         Status.IsPackage:=false;
         Status.IsExe:=true;
         parse_only:=false;
         consume_semicolon_after_loaded:=false;

         { make the compiler happy and avoid an uninitialized variable warning on Setlength(sc,length(sc)+1); }
         sc:=nil;

         { DLL defaults to create reloc info }
         if IsLibrary or (TargetInfo.system in [system_aarch64_win64]) then
           begin
             if not RelocSectionSetExplicitly then
               RelocSection:=true;
           end;

         { get correct output names }
         main_file := CurrentScanner.inputfile;
         while Assigned(main_file.next) do
           main_file := main_file.next;

         curr.SetFileName(main_file.path+main_file.name,true);

         if IsLibrary then
           begin
             proc_library_header(curr);
             consume_semicolon_after_loaded:=true;
           end
         else if CurrentScanner.token=_PROGRAM then
           { is there an program head ? }
           begin
             proc_program_header(curr,sc);
             consume_semicolon_after_loaded:=true;
           end
         else
           begin
             if (TargetInfo.system in systems_unit_program_exports) then
               exportlib.preparelib(curr.RealModuleName^);

             { setup things using the switches }
             setupglobalswitches;

{$ifdef DEBUG_NODE_XML}
             XMLInitializeNodeFile('program', curr.RealModuleName^);
{$endif DEBUG_NODE_XML}
           end;

         { load all packages, so we know whether a unit is contained inside a
           package or not }
         Load_Packages;

         { set implementation flag }
         curr.in_interface:=false;
         curr.interface_compiled:=true;

         { insert after the unit symbol tables the static symbol table
           of the program                                              }
         curr.localsymtable:=TStaticSymTable.create(curr.RealModuleName^,curr.ModuleID);

         { load system unit }
         load_ok:=loadsystemunit(curr);

         { consume the semicolon now that the system unit is loaded }
         if consume_semicolon_after_loaded then
           consume(_SEMICOLON);

         { global switches are read, so further changes aren't allowed }
         curr.in_global:=false;

         { system unit is loaded, now insert feature defines }
         for feature:=low(TFeature) to high(TFeature) do
           if feature in Features then
             def_system_macro('FPC_HAS_FEATURE_'+FeatureStr[feature]);

         { load standard units, e.g objpas,profile unit }
         load_ok:=loaddefaultunits(curr) and load_ok;

         { Load units provided on the command line }
         load_ok:=loadautounits(curr) and load_ok;

         { insert iso program parameters }
         if length(sc)>0 then
           begin
             textsym:=search_system_type('TEXT');
             if not(Assigned(textsym)) then
               InternalError(2013011201);
             for i:=0 to high(sc) do
               begin
                 ps:=CProgramParaSym.create(sc[i].name,sc[i].nr);
                 curr.localsymtable.insertsym(ps,true);
               end;
           end;

         { Load the units used by the program we compile. }
         if CurrentScanner.token=_USES then
           begin
             // We can do this here: if there is no uses then the namespace directive makes no sense.
             if Assigned(curr) then
               curr.Loadlocalnamespacelist
             else
               CurrentNamespaceList:=Nil;
             parseusesclause(curr);
             curr.consume_semicolon_after_uses:=true;
           end
         else begin
           curr.consume_semicolon_after_uses:=false;
           if TModule.ctask_fast_backtrack then
             load_ok:=false; { some used units are not fully compiled }
         end;

         { Also load compiler-injected dependencies when there is no uses clause. }
         load_ok:=loadunits(curr,false) and load_ok;

         if curr.IsInitial then
           load_ok:=false; { delay program, so ctask can finish all units }
         if not load_ok then
           curr.state:=ms_compiling_wait;

         { Can we continue compiling ? }

         result:=curr.state<>ms_compiling_wait;
         if result then
           result:=proc_program_declarations(curr,IsLibrary)
      end;

end.
