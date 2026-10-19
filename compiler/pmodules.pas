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

    function ProcUnit(AModule: TModule):Boolean;
    function ParseUnitInterfaceDeclarations(AModule : TModule) : Boolean;
    function ProcUnitImplementation(AModule: TModule):Boolean;
    function ProcPackage(AModule: TModule) : Boolean;
    function FinishPackage(AModule: TModule) : Boolean;
    function ProcProgram(AModule: TModule; AIsLibrary : Boolean) : Boolean;
    function ProcProgramDeclarations(AModule : TModule; AIsLibrary : Boolean) : Boolean;
    function FinishCompileUnit(AModule:TModule): Boolean;
    function FinishUnit(AModule:TModule): Boolean;

implementation

    uses
       SysUtils,
       GlobType,Systems,tokens,
       CUtils,CFileUtl,CClasses,CompHook,
       Globals,Verbose,FinPut,FPPU,GlobStat,FPCP,FPkg,
       symconst,SymBase,symtype,symdef,SymSym,SymTable,defutil,symcreat,
       WPOInfo,
       aasmtai,AAsmData,aasmbase,aasmcpu,
       cgbase,ngenutil,
       nbas,nutils,ncgutil,
       link,assemble,import,export,gendef,PPU,CompRsrc,DbgBase,
       CResStr,ProcInfo,
       objcgutl,
       PkgUtil,NXPackageFile,
       wpobase,
       Scanner,pbase,pexpr,psystem,psub,pgenutil,pparautl,ncgvmt,ncgrtti,
       CPUInfo;


    procedure CreateObjectFile(AModule : TModule);
      var
        lDLLScanner      : TDLLScanner;
        lName               : String;
        lKeepShared      : TCmdStrList;
        lImageResourcesUsed : Boolean;
      begin
        if not PrepareModuleResources then Exit;
        if not AModule.IsUnit then
        begin
          if not PrepareImageResources(lImageResourcesUsed) then Exit;
          CNodeUtils.InsertResourceInfo(lImageResourcesUsed);
        end;
        { try to create import entries from system dlls }
        if (tf_has_dllscanner in TargetInfo.flags) and
           (not AModule.LinkOtherSharedLibs.Empty) then
         begin
           { Init DLLScanner }
           if Assigned(CDLLScanner[Ord(TargetInfo.system)]) then
            lDLLScanner:=CDLLScanner[Ord(TargetInfo.system)].Create
           else
            InternalError(200104121);
           lKeepShared:=TCmdStrList.Create;
           { Walk all shared libs }
           While not AModule.LinkOtherSharedLibs.Empty do
            begin
              lName:=AModule.LinkOtherSharedLibs.GetUseMask(link_always);
              if not lDLLScanner.scan(lName) then
               lKeepShared.Concat(lName);
            end;
           lDLLScanner.Free;
           lDLLScanner := nil;
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
           while not lKeepShared.Empty do
            begin
              lName:=lKeepShared.GetFirst;
              AModule.LinkOtherSharedLibs.add(lName,link_always);
            end;
           lKeepShared.Free;
           lKeepShared := nil;
         end;

        { allow a target-specific pass over all assembler code (used by LLVM
          to insert type definitions }
        CNodeUtils.InsertObjectInfo;

        { Emit module debug information. }
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
           if (af_needar in TargetAsm.flags) then
             Linker.MakeStaticLibrary;
         end;

        if ErrorCount=0 then PublishResourceFiles;
      end;


    procedure InsertObjectFile(AModule : TModule);
    { Insert the used object file for this unit in the used list for this unit }
      begin
        AModule.LinkUnitOFiles.add(ExtractFileName(AModule.ObjFileName),link_static);
        AModule.HeaderFlags:=AModule.HeaderFlags or UfStaticLinked;

        if create_smartlink_library then
          begin
            AModule.LinkUnitStaticLibs.add(AModule.StaticLibFileName ,link_smart);
            AModule.HeaderFlags:=AModule.HeaderFlags or UfSmartLinked;
          end;
        if cs_lto in CurrentSettings.ModuleSwitches then
          begin
            AModule.LinkUnitOFiles.add(ChangeFileExt(AModule.ObjFileName,LTOExt),link_lto);
            AModule.HeaderFlags:=AModule.HeaderFlags or UfLTOLinked;
          end;
      end;


    procedure CreateDwarfFrame;
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
            CurrentAsmData.asmlists[al_dwarf_frame] := TAsmList.Create;
            CurrentAsmData.asmcfi.Generate_Code(CurrentAsmData.asmlists[al_dwarf_frame]);
          end;
      end;

    Function CheckResourcesUsed(AModule : TModule) : Boolean;
      var
        lUsedUnit           : TUsedUnit;
        lFound        : Boolean;
      begin
        CheckResourcesUsed:=tf_has_winlike_resources in TargetInfo.flags;
        if not CheckResourcesUsed then exit;

        lUsedUnit:=TUsedUnit(UsedUnits.first);
        lFound:=mf_has_resourcefiles in AModule.ModuleFlags;
        while Assigned(lUsedUnit) and not lFound do
          begin
            lFound:=not Assigned(lUsedUnit.u.package) and (mf_has_resourcefiles in lUsedUnit.u.ModuleFlags);
            lUsedUnit:=TUsedUnit(lUsedUnit.next);
          end;
        CheckResourcesUsed:=lFound;
      end;

    function AddUnit(AModule : TModule; const AName:String; AAddAsUsed:Boolean = true): TPPUModule;
      var
        lModule : TPPUModule;
        lUnitSym : TUnitSym;
        lIsNew : Boolean;
        lUsedUnit: TUsedUnit;

      begin
        { load unit }
        lModule:=RegisterUnit(AModule,AName,'',lIsNew);
        if lIsNew then
          UsedUnits.concat(TUsedUnit.Create(lModule,true,AAddAsUsed,nil));
        lModule.AddDependency(AModule,AModule.InInterface); { adddependency before loadppu for invalid cycle test }
        lModule.LoadPPU(AModule);
        TModule.Finish_Module(lModule);

        { add to symtable stack }
        if Assigned(lModule.GlobalSymTable) then
          SymTableStack.push(lModule.GlobalSymTable);
        if (m_mac in CurrentSettings.ModeSwitches) and
            Assigned(lModule.GlobalMacroSymTable) then
          MacroSymTableStack.push(lModule.GlobalMacroSymTable);
        { insert unitsym }
        lUnitSym:=CUnitSym.Create(lModule.ModuleName^,lModule);
        inc(lUnitSym.refs);
        TAbstractUnitSymTable(AModule.LocalSymTable).InsertUnit(lUnitSym);
        if AAddAsUsed then
        begin
          { add to used units }
          lUsedUnit:=AModule.AddUsedUnit(lModule,false,lUnitSym);
          lUsedUnit.DependentAdded:=true;
        end;
        Result:=lModule;
      end;

    function MaybeLoadVariantsUnit(AModule : TModule) : Boolean;
      var
        lModule : TModule;
        lAddSystemNamespace : Boolean;
      begin
        Result:=true;
        { Do we need the variants unit? Skip this
          for VarUtils unit for bootstrapping }
        if not(mf_uses_variants in AModule.ModuleFlags) or
           (AModule.ModuleName^='VARUTILS') or
           (AModule.ModuleName^='SYSTEM.VARUTILS') then
          exit;
        { Variants unit already loaded? }
        lModule:=TModule(Loaded_Units.first);
        while Assigned(lModule) do
          begin
            if (lModule.ModuleName^='VARIANTS') or (lModule.ModuleName^='SYSTEM.VARIANTS') then
              exit;
            lModule:=TModule(lModule.next);
          end;
        { Variants unit is not loaded yet, load it now }
        Message(parser_w_implicit_uses_of_variants_unit);
        lAddSystemNamespace:=NamespaceList.Find('System')=Nil;
        if lAddSystemNamespace then
          NamespaceList.concat('System');
        Result:=AddUnit(AModule,'variants').state in [ms_compiled,ms_processed];
        if lAddSystemNamespace then
          NamespaceList.Remove('System');
      end;


    function MaybeRemoveResUnit(AModule : TModule) : Boolean;
      var
        lResourcesUsed : Boolean;
        lModule : TModule;
        lUsedUnit : TUsedUnit;
        lUnitName : shortstring;
      begin
        { We simply remove the unit from:
           - usedunit list, so that things like init/finalization table won't
              contain references to this unit
           - loaded_units list, so that the unit object file doesn't get linked
             with the executable. }
        { Note: on windows we always need resources! }
        lResourcesUsed:=(TargetInfo.system in systems_all_windows)
                         or CheckResourcesUsed(AModule);
        if (not lResourcesUsed) and (tf_has_winlike_resources in TargetInfo.flags) then
          begin
            { resources aren't used, so we don't need this unit }
            lUnitName:='FPINTRES';
            Message1(unit_u_unload_resunit,lUnitName);
            { find the module }
            lModule:=TModule(Loaded_Units.first);
            while Assigned(lModule) do
              begin
                if lModule.IsUnit and (lModule.ModuleName^=lUnitName) then break;
                lModule:=TModule(lModule.next);
              end;
            if not Assigned(lModule) then
              InternalError(200801071);
            { Imported resource support belongs to its package. Removing that
              module would invalidate the provider's dependency closure. }
            if Assigned(lModule.package) then
              exit(lResourcesUsed);
            { find its tused_unit in the global list }
            lUsedUnit:=TUsedUnit(UsedUnits.first);
            while Assigned(lUsedUnit) do
              begin
                if lUsedUnit.u=lModule then break;
                lUsedUnit:=TUsedUnit(lUsedUnit.next);
              end;
            if not Assigned(lUsedUnit) then
              InternalError(200801072);
           { remove the tused_unit }
            UsedUnits.Remove(lUsedUnit);
            lUsedUnit.Free;
            // Remove from local list
            lUsedUnit:=TUsedUnit(AModule.UsedUnitList.first);
            while Assigned(lUsedUnit) do
              begin
                if lUsedUnit.u=lModule then break;
                lUsedUnit:=TUsedUnit(lUsedUnit.next);
              end;
            if not Assigned(lUsedUnit) then
              InternalError(2024020701);
            AModule.UsedUnitList.Remove(lUsedUnit);
            lUsedUnit.Free;
            lUsedUnit := nil;
           { remove the module }
            Loaded_Units.Remove(lModule);
            Unloaded_Units.Concat(lModule);
          end;
        MaybeRemoveResUnit:=lResourcesUsed;
      end;


    procedure CheckSystemCharWidth;
      begin
        { The PPU's text-model flag cannot prove that System.Char was
          declared with the matching width. }
        if Search_System_Type('CHAR').TypeDef.Size <>
           1+Ord(CompilerWide_Unicode_Strings) then
          Comment(VFatal,'System.Char width does not match this compiler invocation''s default text model');
      end;


    function LoadSystemUnit(AModule : TModule) : Boolean;
      var
        lState: TGlobalState;
        lSystemModule : TModule;

      begin
        Result:=False;
        { we are going to rebuild the symtablestack, clear it first }
        SymTableStack.clear;
        MacroSymTableStack.clear;

        { macro symtable }
        MacroSymTableStack.push(InitialMacroSymTable);

        { are we compiling the system unit? }
        if (cs_compilesystem in CurrentSettings.ModuleSwitches) then
         begin
           SystemUnit:=TGlobalSymTable(AModule.LocalSymTable);
           { create system defines }
           CreateInternTypes;
           CreateInternSymbols;
           { Set the owner of errorsym and errortype to symtable to
             prevent crashes when accessing .owner }
           GenErrorSym.owner:=SystemUnit;
           GenErrorDef.owner:=SystemUnit;
           exit;
         end;

        { insert the system unit, it is always the first. Load also the
          internal types from the system unit }
        lSystemModule:=AddUnit(AModule,'system');
        Result:=Assigned(lSystemModule) and (lSystemModule.State in [ms_processed,ms_compiled]);
        SystemUnit:=TGlobalSymTable(SymTableStack.top);

        { load_intern_types resets the scanner... }
        CurrentScanner.TempCloseInputFile;
        lState:=TGlobalState.Create(false);
        LoadInternTypes;
        lState.restore;
        FreeAndNil(lState);
        CurrentScanner.TempOpenInputFile;
        if Result then
          CheckSystemCharWidth;

        { Set the owner of errorsym and errortype to symtable to
          prevent crashes when accessing .owner }
        GenErrorSym.owner:=SystemUnit;
        GenErrorDef.owner:=SystemUnit;
        { default the extended RTTI options to that of TObject }
        if Assigned(Class_TObject) then
          CurrentModule.RTTIDirective.options:=Class_TObject.RTTI.options;
      end;


    { load default units, like language mode units
      Return true if all units were loaded, no recompilation needed. }
    function LoadDefaultUnits(AModule :TModule) : Boolean;

      procedure RegisterRuntimeUnit(const AName: String);
        var
          lModule: TPPUModule;
          lUnitSym: TUnitSym;
          lIsNew: Boolean;
        begin
          lModule:=RegisterUnit(AModule,AName,'',lIsNew);
          if lIsNew then
            UsedUnits.concat(TUsedUnit.Create(lModule,false,true,nil));
          lUnitSym:=CUnitSym.Create(lModule.ModuleName^,nil);
          inc(lUnitSym.refs);
          AModule.AddUsedUnit(lModule,true,lUnitSym);
        end;

      Procedure CheckAddUnit(AName: String);

        var
          lOK : Boolean;
          lModule : TModule;

        begin
          lModule:=AddUnit(AModule,AName,true);
          lOK:=Assigned(lModule) and (lModule.state in [ms_processed,ms_compiled]);
          if not lOK then
            Message2(unit_f_cant_find_ppu,AName,AModule.RealModuleName^);
          Result:=lOK and Result;
        end;

      begin
        Result:=True;
        { Units only required for main module }
        if not(AModule.IsUnit) then
         begin
           { Heaptrc unit, load heaptrace before any other units especially objpas }
           if (cs_use_heaptrc in CurrentSettings.GlobalSwitches) then
             RegisterRuntimeUnit('heaptrc');
           { Valgrind requires c memory manager }
           if (cs_gdb_valgrind in CurrentSettings.GlobalSwitches) or
              (([cs_sanitize_address]*CurrentSettings.ModuleSwitches)<>[]) then
             CheckAddUnit('cmem');
           { Lineinfo unit }
           if (cs_use_lineinfo in CurrentSettings.GlobalSwitches) then begin
             CheckAddUnit('lnfodwrf');
           end;
           { Which kind of resource support?
             Note: if resources aren't used this unit will be removed later,
             otherwise we need it here since it must be loaded quite early }
           if (tf_has_winlike_resources in TargetInfo.flags) then
             CheckAddUnit('fpintres');
         end
        else if (cs_checkpointer in CurrentSettings.LocalSwitches) then
          CheckAddUnit('heaptrc');
        { Objpas unit? }
        if m_objpas in CurrentSettings.ModeSwitches then
          CheckAddUnit('objpas');

        { Optional runtimes can require a source rebuild. Register them as
          implicit uses entries for loadunits and sequential continuation. }
        if not AModule.IsUnit and not AModule.IsLibrary and
           (TargetInfo.system=system_x86_64_win64) and
           (cs_nexus_profile in CurrentSettings.ModuleSwitches) then
          RegisterRuntimeUnit('nxprofilerruntime');

        { Macpas unit? }
        if m_mac in CurrentSettings.ModeSwitches then
          CheckAddUnit('macpas');

        if m_iso in CurrentSettings.ModeSwitches then
          CheckAddUnit('iso7185');

        { blocks support? }
        if m_blocks in CurrentSettings.ModeSwitches then
          CheckAddUnit('blockrtl');

        { Objective-C support unit? }
        if (m_objectivec1 in CurrentSettings.ModeSwitches) then
          begin
            { interface to Objective-C run time }
            CheckAddUnit('objc');
            LoadObjCTypes;
            { NSObject }
            if not(AModule.IsUnit) or
               (AModule.ModuleName^<>'OBJCBASE') then
              CheckAddUnit('objcbase');
          end;
      end;

    { Load units provided on the command line
      Return true if all units were loaded, no recompilation needed. }
    function LoadAutoUnits(AModule: TModule) : Boolean;

      Procedure CheckAddUnit(AName: String);

        var
          lOK : Boolean;
          lModule : TModule;

        begin
          lModule:=AddUnit(AModule,AName,true);
          lOK:=Assigned(lModule) and (lModule.state in [ms_compiled,ms_processed]);
          Result:=lOK and Result;
        end;

      var
        lAutoUnits,lName : String;
      begin
        Result:=True;
        lAutoUnits:=AutoloadUnits;
        repeat
          lName:=GetToken(lAutoUnits,',');
          if lName='' then
            break;
          CheckAddUnit(lName);
        until false;
      end;

    procedure ParseUsesClause(AModule: TModule; AIsContains:Boolean=false);

      var
         lName,lOriginalName  : AnsiString;
         lFileName      : String;
         lUsedUnit  : TUsedUnit;
         lNextModule     : TModule;
         lUnitSym : TUnitSym;
         lFilePos : TFilePosInfo;
         lIsNew : Boolean;


      begin
        if AIsContains then
          Consume(_ID)
        else
          Consume(_USES);
        repeat
          lName:=CurrentScanner.FPattern;
          lOriginalName:=CurrentScanner.FOrgPattern;
          lFilePos:=CurrentTokenPos;
          Consume(_ID);
          while CurrentScanner.FToken=_POINT do
            begin
              Consume(_POINT);
              lName:=lName+'.'+CurrentScanner.FPattern;
              lOriginalName:=lOriginalName+'.'+CurrentScanner.FOrgPattern;
              Consume(_ID);
            end;
          { support "<unit> in '<file>'" construct }
          lFileName:='';
          if TryToConsume(_OP_IN) then
            lFileName:=FixFileName(GetStringConst);
          { Give a warning if lineinfo is loaded }
          if lName='LINEINFO' then
            begin
              Message(parser_w_no_lineinfo_use_switch);
              if (TargetDbg.id=dbg_dwarf3) then
               lName := 'LNFODWRF';
             lOriginalName := lName;
            end;
          { Give a warning if objpas is loaded }
          if lName='OBJPAS' then
           Message(parser_w_no_objpas_use_mode);
          { Using the unit itself is not possible }
          if (lName<>AModule.ModuleName^) then
           begin
             { check if the unit is already used }
             lNextModule:=nil;
             lUsedUnit:=TUsedUnit(AModule.UsedUnitList.first);
             while Assigned(lUsedUnit) do
              begin
                if (lUsedUnit.u.ModuleName^=lName) then
                 begin
                   lNextModule:=lUsedUnit.u;
                   break;
                 end;
                lUsedUnit:=TUsedUnit(lUsedUnit.next);
              end;
             if not Assigned(lNextModule) then
               begin
               lNextModule:=RegisterUnit(AModule,lOriginalName,lFileName,lIsNew);
               if lIsNew then
                 UsedUnits.concat(TUsedUnit.Create(lNextModule,AModule.InInterface,true,nil));
               end
             else
               Message1(sym_e_duplicate_id,lName);
             { Create unitsym, we need to use the name as specified, we
               can not use the modulename because that can be different
               when -Un is used }
             CurrentTokenPos:=lFilePos;
             lUnitSym:=CUnitSym.Create(lOriginalName,nil);
             { the current module uses the unit hp2 }
             AModule.AddUsedUnit(lNextModule,true,lUnitSym);
           end
          else
           Message1(sym_e_duplicate_id,lName);
          if CurrentScanner.FToken=_COMMA then
           begin
             CurrentScanner.FPattern:='';
             Consume(_COMMA);
           end
          else
           break;
        until false;
      end;

    function LoadUnits(AModule: TModule; AFromInterface : Boolean) : Boolean;

      var
        lUsedUnit  : TUsedUnit;
        lState: TGlobalState;
        lLoadedModule : TModule;

        procedure RestoreState;
          begin
            lState.restore;
            if Assigned(CurrentScanner) and (CurrentModule.Scanner=CurrentScanner) then
              begin
                if Assigned(CurrentScanner.FInputFile) then
                  CurrentScanner.TempOpenInputFile;
              end;
            lState.free;
            lState := nil;
          end;

      begin
        Result:=true;
        CurrentScanner.TempCloseInputFile;
        lState:=TGlobalState.Create(false);

        { reset verbosity (otherwise the used units would use curr's pmessage) }
        CurrentSettings.PMessage:=nil;
        RestoreLocalVerbosity(nil);

        { Load the units }
        lUsedUnit:=TUsedUnit(AModule.UsedUnitList.first);
        while Assigned(lUsedUnit) do
          begin
            lLoadedModule:=lUsedUnit.u;
            { Only load the units that are in the current
              (interface/implementation) uses clause }
            if lUsedUnit.InUses and
               (lUsedUnit.InInterface=AFromInterface) then
             begin
               { adddependency before loadppu for invalid cycle test }
               if not lUsedUnit.DependentAdded then
               begin
                 lUsedUnit.DependentAdded:=true;
                 lLoadedModule.AddDependency(AModule,AFromInterface);
               end;
               { always call loadppu for the cycle test }
               TPPUModule(lLoadedModule).LoadPPU(AModule);
               if not (AModule.state in [ms_compile,ms_compiling_wait,ms_compiling_waitintf,ms_compiling_waitimpl]) then
               begin
                 {$IFDEF DEBUG_PPU_CYCLES}
                 WriteLn('loadunits STOPPED ',AModule.ModuleName^,' ',AModule.StateStr);
                 {$ENDIF}
                 Result:=false;
                 break;
               end;
               if not lLoadedModule.InterfaceCompiled or lLoadedModule.DoReload or TModule.CTask_Fast_Backtrack then
               begin
                 { an used unit is delayed
                   Important: do not break, load the remaining uses section, so the scheduler
                              has more information about cycles }
                 {$IFDEF DEBUG_PPU_CYCLES}
                 WriteLn('PPUALGO loadunits ',AModule.ModuleName^,' ',AModule.StateStr,' ',BoolToStr(lUsedUnit.InInterface,'interface','implementation'),' uses "',lUsedUnit.u.ModuleName^,'", state=',lUsedUnit.u.StateStr,', waiting ...');
                 {$ENDIF}
                 TModule.CTask_Fast_Backtrack:=true;
                 Result:=false;
               end;
               { check hints }
               lUsedUnit.Check_Hints;
             end;
            lUsedUnit:=TUsedUnit(lUsedUnit.next);
          end;

        RestoreState;
      end;

     {
       Connect loaded units: check crc and add to symbol tables.
       this can only be called after all units were actually loaded!
     }

     procedure ConnectLoadedUnits(AModule : TModule; APreserveSymTable:TSymTable);

     var
       lUsedUnit  : TUsedUnit;
       lOriginalName   : AnsiString;
       lUnitSymTable: TAbstractUnitSymTable;

     begin
       // writeln(_module.get_modulename,': Connecting units');
       lUsedUnit:=TUsedUnit(AModule.UsedUnitList.first);
       while Assigned(lUsedUnit) do
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
         if not (lUsedUnit.InUses and
            (lUsedUnit.InInterface=AModule.InInterface)) then
           begin
//           writeln('Must not connect ',pu.u.modulename^,' (pu.in_interface: ',pu.in_interface,' <> module.in_interface',_module.in_interface,')');
           end
         else
           begin
//           writeln('Must connect ',pu.u.modulename^,'(sym: ',pu.unitsym.realname,')');
           { save crc values }
           lUsedUnit.checksum:=lUsedUnit.u.crc;
           lUsedUnit.InterfaceChecksum:=lUsedUnit.u.InterfaceCRC;
           lUsedUnit.IndirectChecksum:=lUsedUnit.u.IndirectCRC;
           if TPPUModule(lUsedUnit.u).NSPrefix<>'' then
             begin
               { use the name as declared in the uses section for -Un }
               lOriginalName:=TPPUModule(lUsedUnit.u).NSPrefix+'.'+lUsedUnit.UnitSym.realname;
               { update unitsym now that we have access to the full name }
               lUsedUnit.UnitSym.free;
               lUsedUnit.UnitSym:=CUnitSym.Create(lOriginalName,lUsedUnit.u);
             end
           else
             begin
               { connect unitsym to the module }
               lUsedUnit.UnitSym.module:=lUsedUnit.u;
               lUsedUnit.UnitSym.RegisterSym;
             end;
           {
             Add the unit symbol in the current symtable.
             localsymtable will be nil after the interface uses clause is parsed and the local symtable
             is moved to the global.
           }
           if Assigned(AModule.LocalSymTable) then
             lUnitSymTable:=TAbstractUnitSymTable(AModule.LocalSymTable)
           else
             lUnitSymTable:=TAbstractUnitSymTable(AModule.GlobalSymTable);
           // Writeln('Adding used unit sym ',pu.unitsym.realName,' to table ',unitsymtable.get_name);
           lUnitSymTable.InsertUnit(lUsedUnit.UnitSym);
           { add to symtable stack }
           // Writeln('Adding used unit symtable ',pu.u.globalsymtable.name^,' (',pu.u.globalsymtable.DefList.Count, ' defs) to stack');
           if Assigned(APreserveSymTable) then
             SymTableStack.PushAfter(lUsedUnit.u.GlobalSymTable,APreserveSymTable)
           else
             SymTableStack.push(lUsedUnit.u.GlobalSymTable);
           if (m_mac in CurrentSettings.ModeSwitches) and
              Assigned(lUsedUnit.u.GlobalMacroSymTable) then
             MacroSymTableStack.push(lUsedUnit.u.GlobalMacroSymTable);

           end;
         lUsedUnit:=TUsedUnit(lUsedUnit.next);
         end;
       // writeln(_module.get_modulename,': Done Connecting units');
     end;



     procedure ResetAllDefs(AModule: TModule);
       begin
         if Assigned(AModule.WPOInfo) then
           AModule.WPOInfo.resetdefs;
       end;


    procedure FreeLocalSymTables(ASymTable:TSymTable);
      var
        lIndex   : LongInt;
        lDef : TStoredDef;
        lProcDef  : TProcDef;
      begin
        for lIndex:=0 to ASymTable.DefList.Count-1 do
          begin
            lDef:=TStoredDef(ASymTable.DefList[lIndex]);
            if lDef.typ=procdef then
              begin
                lProcDef:=TProcDef(lDef);
                if Assigned(lProcDef.LocalST) and
                   (lProcDef.LocalST.SymTableType<>staticsymtable) and
                   not(po_inline in lProcDef.ProcOptions) then
                  begin
                    FreeLocalSymTables(lProcDef.LocalST);
                    lProcDef.LocalST.free;
                    lProcDef.LocalST:=nil;
                  end;
                lProcDef.FreeImplProcDefInfo;
                lProcDef.Done_ParaLoc_Info(calleeside);
              end;
          end;
      end;


    procedure FreeUnregisteredLocalSymTableElements(AModule : TModule);
      procedure RemoveFromProcDefList(ADef: TDef);
        var
          lIndex: Integer;
          lChildDef: TDef;
        begin
          if ADef=nil then exit;
          if (ADef.typ in [objectdef, recorddef]) and (ADef is TAbstractRecordDef) then
            begin
              if TAbstractRecordDef(ADef).SymTable<>nil then
                for lIndex:=0 to TAbstractRecordDef(ADef).SymTable.DefList.Count-1 do
                  begin
                    lChildDef:=TDef(TAbstractRecordDef(ADef).SymTable.DefList[lIndex]);
                    RemoveFromProcDefList(lChildDef);
                  end;
            end
          else
            if ADef.typ=procdef then
              begin
                TProcSym(TProcDef(ADef).ProcSym).ProcdefList.Remove(ADef);
                if TProcDef(ADef).LocalST<>nil then
                  for lIndex:=0 to TProcDef(ADef).LocalST.DefList.Count-1 do
                    begin
                      lChildDef:=TDef(TProcDef(ADef).LocalST.DefList[lIndex]);
                      RemoveFromProcDefList(lChildDef);
                    end;
              end;
        end;

      var
        lIndex: LongInt;
        lDef: TDef;
        lSym: TSym;
      begin
        for lIndex:=AModule.LocalSymTable.DefList.count-1 downto 0 do
          begin
            lDef:=TDef(AModule.LocalSymTable.DefList[lIndex]);
            { since commit 48986 deflist might have NIL entries }
            if not Assigned(lDef) then
              continue;
            { this also frees def, as the defs are owned by the symtable }
            if not lDef.IsRegistered and
               not(df_not_registered_no_free in lDef.DefOptions) then
              begin
                { if it's a procdef, unregister it from its procsym first,
                  unless that sym hasn't been registered either (it's possible
                  to have one overload in the interface and another in the
                  implementation) }
                RemoveFromProcDefList(lDef);
                AModule.LocalSymTable.DeleteDef(lDef);
              end;
          end;
        { from high to low so we hopefully have moves of less data }
        for lIndex:=AModule.LocalSymTable.SymList.count-1 downto 0 do
          begin
            lSym:=TSym(AModule.LocalSymTable.SymList[lIndex]);
            { this also frees sym, as the symbols are owned by the symtable }
            if not lSym.IsRegistered then
              AModule.LocalSymTable.DeleteSym(lSym);
          end;
      end;


    procedure SetupGlobalSwitches;
      begin
        if (cs_create_pic in CurrentSettings.ModuleSwitches) then
          begin
            Def_System_Macro('FPC_PIC');
            Def_System_Macro('PIC');
          end;
      end;


    function CreateMainProc(const AName:TSymStr;AProcType:TProcTypeOption;ASymTable:TSymTable):TCGProcInfo;
      var
        lProcSym  : TProcSym;
        lProcDef  : TProcDef;
      begin
        { there should be no current_procinfo available }
        if Assigned(CurrentProcInfo) then
         InternalError(200304275);
        {Generate a procsym for main}
        lProcSym:=CProcSym.Create('$'+AName);
        { always register the symbol }
        lProcSym.RegisterSym;
        { main are always used }
        inc(lProcSym.refs);
        ASymTable.InsertSym(lProcSym);
        lProcDef:=TProcDef(CNodeUtils.Create_Main_ProcDef(TargetInfo.cprefix+AName,AProcType,lProcSym));
        { We don't need a local symtable, change it into the static symtable }
        if not (AProcType in [potype_mainstub,potype_pkgstub,potype_libmainstub]) then
          begin
            lProcDef.LocalST.free;
            lProcDef.LocalST:=ASymTable;
          end
        else if (AProcType=potype_pkgstub) and
            (TargetInfo.system in systems_all_windows) then
          lProcDef.ProcCallOption:=pocall_stdcall
        else
          lProcDef.ProcCallOption:=pocall_cdecl;
        Handle_Calling_Convention(lProcDef,cHCCDefaultActionsImpl);
        { set procinfo and current_procinfo.procdef }
        Result:=TCGProcInfo(CProcInfo.Create(nil));
        Result.procdef:=lProcDef;
        { main proc does always a call e.g. to init system unit }
        if AProcType<>potype_pkgstub then
          include(Result.flags,pi_do_call);
      end;


    procedure ReleaseMainProc(AModule: TModule; AProcInfo:TCGProcInfo);
      begin
        { remove localst as it was replaced by staticsymtable }
        AProcInfo.procdef.LocalST:=nil;
        { remove procinfo }
        AModule.ProcInfo:=nil;
        AProcInfo.free;
        AProcInfo:=nil;
      end;



    { Insert _GLOBAL_OFFSET_TABLE_ symbol if system uses it }

    procedure MaybeLoadGOT(AModule: TModule);
{$if defined(i386)}
       var
         lGOTVarSym : TStaticVarSym;
{$endif i386 or sparcgen}
      begin
{$if defined(i386)}
         if (cs_create_pic in CurrentSettings.ModuleSwitches) and
            (tf_pic_uses_got in TargetInfo.flags) then
           begin
             { insert symbol for got access in assembler code}
             lGOTVarSym:=CStaticVarSym.Create('_GLOBAL_OFFSET_TABLE_',
                          vs_value,VoidPointerType,[vo_is_external]);
             lGOTVarSym.Set_MangledName('_GLOBAL_OFFSET_TABLE_');
             AModule.LocalSymTable.InsertSym(lGOTVarSym);
             { avoid unnecessary warnings }
             lGOTVarSym.VarState:=vs_read;
             lGOTVarSym.refs:=1;
           end;
{$endif i386 or sparcgen}
      end;

    function GenImplicitInitFinal(AModule: TModule; AFlag:TModuleFlag;ASymTable:TSymTable):TCGProcInfo;
      begin
        { create procdef }
        case AFlag of
          mf_init :
            begin
              Result:=CreateMainProc(Make_MangledName('',AModule.LocalSymTable,'init_implicit$'),potype_unitinit,ASymTable);
              Result.procdef.AliasNames.concat(Make_MangledName('INIT$',AModule.LocalSymTable,''));
            end;
          mf_finalize :
            begin
              Result:=CreateMainProc(Make_MangledName('',AModule.LocalSymTable,'finalize_implicit$'),potype_unitfinalize,ASymTable);
              Result.procdef.AliasNames.concat(Make_MangledName('FINALIZE$',AModule.LocalSymTable,''));
              if (not AModule.IsUnit) then
                Result.procdef.AliasNames.concat('PASCALFINALIZE');
            end;
          else
            InternalError(200304253);
        end;
        Result.code:=CNothingNode.Create;
      end;


    procedure CopyMacro(AObject:TObject; AData:Pointer);
      begin
        TModule(AData).GlobalMacroSymTable.InsertSym(TMacro(AObject).GetCopy);
      end;

    function TryConsumeHintDirective(var AModuleOpt:TModuleOptions; var ADeprecatedMsg:PShortString):Boolean;
      var
        lDeprecatedSeen,
        lLastIsDeprecated:Boolean;
      begin
        TryConsumeHintDirective:=false;
        lDeprecatedSeen:=false;
        repeat
          lLastIsDeprecated:=false;
          case CurrentScanner.FIDToken of
            _LIBRARY :
              begin
                include(AModuleOpt,mo_hint_library);
                TryConsumeHintDirective:=true;
              end;
            _DEPRECATED :
              begin
                { allow deprecated only once }
                if lDeprecatedSeen then
                  break;
                include(AModuleOpt,mo_hint_deprecated);
                TryConsumeHintDirective:=true;
                lLastIsDeprecated:=true;
                lDeprecatedSeen:=true;
              end;
            _EXPERIMENTAL :
              begin
                include(AModuleOpt,mo_hint_experimental);
                TryConsumeHintDirective:=true;
              end;
            _PLATFORM :
              begin
                include(AModuleOpt,mo_hint_platform);
                TryConsumeHintDirective:=true;
              end;
            _UNIMPLEMENTED :
              begin
                include(AModuleOpt,mo_hint_unimplemented);
                TryConsumeHintDirective:=true;
              end;
            else
              break;
          end;
          Consume(CurrentScanner.FToken);
          { handle deprecated message }
          if ((CurrentScanner.FToken=_CSTRING) or (CurrentScanner.FToken=_CCHAR)) and lLastIsDeprecated then
            begin
              if ADeprecatedMsg<>nil then
                InternalError(201001221);
              if CurrentScanner.FToken=_CSTRING then
                ADeprecatedMsg:=StringDup(CurrentScanner.FCStringPattern)
              else
                ADeprecatedMsg:=StringDup(CurrentScanner.FPattern);
              Consume(CurrentScanner.FToken);
              include(AModuleOpt,mo_has_deprecated_msg);
            end;
        until false;
      end;



type
    TFinishState=record
      InitializationProcedure:TCGProcInfo;
      FinalizationProcedure:TCGProcInfo;
    end;
    PFinishState=^TFinishState;



    function ProcUnitImplementation(AModule: TModule):Boolean;

      var
        lInitializationProcedure,
        lFinalizationProcedure : TCGProcInfo;
        lFinishState:PFinishState;


      begin
        Result:=true;
        lInitializationProcedure:=nil;
        lFinalizationProcedure:=nil;
        lFinishState:=nil;

        SetCurrentModule(AModule);

        { We get here only after used modules were loaded }
        ConnectLoadedUnits(AModule,AModule.GlobalSymTable);

        { All units are read, now give them a number }
        AModule.UpdateMaps;

        { Consume the semicolon if needed.
          At this point the units in the uses clause have at least been parsed
          and are connected, and conditional compilation expressions can
          use the symbols from those units }
        if AModule.ConsumeSemicolonAfterUses then
          begin
            Consume(_SEMICOLON);
            AModule.ConsumeSemicolonAfterUses:=false;
          end;

        { further, changing the globalsymtable is not allowed anymore }
        AModule.GlobalSymTable.sealed:=true;
        SymTableStack.push(AModule.LocalSymTable);

        if not AModule.InterfaceOnly then
          begin
            Message1(parser_u_parsing_implementation,AModule.ModuleName^);
            if AModule.InInterface then
              InternalError(200212285);

            { Compile the unit }
            lInitializationProcedure:=CreateMainProc(Make_MangledName('',AModule.LocalSymTable,'init$'),potype_unitinit,AModule.LocalSymTable);
            lInitializationProcedure.procdef.AliasNames.concat(Make_MangledName('INIT$',AModule.LocalSymTable,''));
            lInitializationProcedure.Parse_Body;
            { save file pos for debuginfo }
            AModule.MainFilePos:=lInitializationProcedure.EntryPos;

            { parse finalization section }
            if CurrentScanner.FToken=_FINALIZATION then
              begin
                { Compile the finalize }
                lFinalizationProcedure:=CreateMainProc(Make_MangledName('',AModule.LocalSymTable,'finalize$'),potype_unitfinalize,AModule.LocalSymTable);
                lFinalizationProcedure.procdef.AliasNames.concat(Make_MangledName('FINALIZE$',AModule.LocalSymTable,''));
                lFinalizationProcedure.Parse_Body;
              end
          end;

        { remove all units that we are waiting for that are already waiting for
          us => breaking up cycles }
        AModule.Remove_WaitForUnit_Cycles;

        Result:=AModule.WaitingForUnit.count=0;

        { save all information that is needed for finishing the unit }
        New(lFinishState);
        lFinishState^.InitializationProcedure:=lInitializationProcedure;
        lFinishState^.FinalizationProcedure:=lFinalizationProcedure;
        AModule.FinishState:=lFinishState;

        if Result then
          Result:=FinishCompileUnit(AModule)
        else
          AModule.state:=ms_compiling_waitfinish;
      end;

    function ParseUnitInterfaceDeclarations(AModule : TModule) : Boolean;

      begin
        Result:=true;
        SetCurrentModule(AModule);

        { update the symtable }
        ConnectLoadedUnits(AModule,nil);

        { We must do this again, because units can have been added to the list while another task was being handled }
        AModule.UpdateMaps;

        { consume the semicolon after maps have been updated else conditional compiling expressions
          might cause internal errors, see tw8611 }

        if AModule.ConsumeSemicolonAfterUses then
          begin
            Consume(_SEMICOLON);
            AModule.ConsumeSemicolonAfterUses:=false;
          end;
        { now push our own symtable }
        SymTableStack.push(AModule.GlobalSymTable);
        { Dump stack
          Write(curr.modulename^);
          symtablestack.dump;
          }

        { ... parse the declarations }
        Message1(parser_u_parsing_interface,AModule.RealModuleName^);

        Read_Interface_Declarations;


        { Export macros defined in the interface for macpas. The macros
          are put in the globalmacrosymtable that will only be used by other
          units. The current unit continues to use the localmacrosymtable }

        if (m_mac in CurrentSettings.ModeSwitches) then
          begin
            AModule.GlobalMacroSymTable:=TMacroSymTable.Create(true);
            AModule.LocalMacroSymTable.SymList.ForEachCall(@CopyMacro,AModule);
          end;

        { leave when we got an error }
        if (ErrorCount>0) and not status.SkipError then
          begin
            Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
            status.SkipError:=true;
            SymTableStack.pop(AModule.GlobalSymTable);
            AModule.state:=ms_moduleerror;
            exit(false);
          end;

        { Our interface is compiled, generate interface CRC and switch to implementation }
        if ErrorCount=0 then
          TPPUModule(AModule).GetPPUCRC;
        AModule.InInterface:=false;
        AModule.InterfaceCompiled:=true;

        { Parse the implementation section }
        if (m_mac in CurrentSettings.ModeSwitches) and TryToConsume(_END) then
          AModule.InterfaceOnly:=true
        else
          AModule.InterfaceOnly:=false;

        ParseOnly:=false;

        { create static symbol table }
        AModule.LocalSymTable:=TStaticSymTable.Create(AModule.RealModuleName^,AModule.ModuleID);


        { Insert _GLOBAL_OFFSET_TABLE_ symbol if system uses it }
        MaybeLoadGOT(AModule);
        if not AModule.InterfaceOnly then
          begin
            Consume(_IMPLEMENTATION);
            Message1(unit_u_loading_implementation_units,AModule.ModuleName^);
            { Read the implementation units }
            if CurrentScanner.FToken=_USES then
              begin
              ParseUsesClause(AModule);
              if not LoadUnits(AModule,false) or TModule.CTask_Fast_Backtrack then
                AModule.state:=ms_compiling_waitimpl;
              { do not consume the semicolon yet, because the units in the uses clause
                may not yet be loaded and conditional compilation expressions may
                depend on symbols from those units }
              AModule.ConsumeSemicolonAfterUses:=True;
              end
            else
              AModule.ConsumeSemicolonAfterUses:=False;
          end;

        if AModule.state in [ms_compiled,ms_processed] then
           begin
           // Writeln('Popping global symtable ?');
           SymTableStack.pop(AModule.GlobalSymTable);
           end;

        if (ErrorCount=0) and TPPUModule(AModule).Dependent_Module_CRC_Mismatch then
          { a dependent module needs recompile }
          AModule.state:=ms_compiling_waitimpl;

        { Can we continue compiling ? }
        Result:=AModule.state<>ms_compiling_waitimpl;
        if Result then
          Result:=ProcUnitImplementation(AModule);
      end;

    function ProcUnit(AModule: TModule):Boolean;
      var
         lMainFile: TInputFile;
         lString1,lString2  : ^String; {Saves stack space}
         lUnitName : AnsiString;
         lUnitName8 : String[8];
         lFeature : TFeature;
         lLoadOK : Boolean;

      begin
         Result:=true;

         if m_mac in CurrentSettings.ModeSwitches then
           AModule.ModeSwitchAllowed:= false;

         Consume(_UNIT);
         if AModule.IsInitial then
          Status.IsExe:=false;

         lUnitName:=CurrentScanner.FOrgPattern;
         Consume(_ID);
         while CurrentScanner.FToken=_POINT do
           begin
             Consume(_POINT);
             lUnitName:=lUnitName+'.'+CurrentScanner.FOrgPattern;
             Consume(_ID);
           end;

         { create filenames and unit name }
         lMainFile := CurrentScanner.FInputFile;
         while Assigned(lMainFile.next) do
           lMainFile := lMainFile.next;

         new(lString1);
         lString1^:=AModule.ModuleName^;
         AModule.SetFileName(lMainFile.path+lMainFile.name,true);
         AModule.SetModuleName(lUnitName);


         { check for system unit }
         new(lString2);
         lString2^:=upper(ChangeFileExt(ExtractFileName(lMainFile.name),''));
         lUnitName8:=copy(AModule.ModuleName^,1,8);
         if (cs_check_unit_name in CurrentSettings.GlobalSwitches) and
            (
             not(
                 (AModule.ModuleName^=lString2^) or
                 (
                  (length(AModule.ModuleName^)>8) and
                  (lUnitName8=lString2^)
                 )
                )
             or
             (
              (length(lString1^)>8) and
              (lString1^<>AModule.ModuleName^)
             )
            ) then
           Message2(unit_e_illegal_unit_name,AModule.RealModuleName^,lString1^);
         if (AModule.ModuleName^='SYSTEM') then
           include(CurrentSettings.ModuleSwitches,cs_compilesystem);
         dispose(lString2);
         dispose(lString1);

         if (TargetInfo.system in systems_unit_program_exports) then
           exportlib.preparelib(AModule.RealModuleName^);

         { parse hint directives }
         TryConsumeHintDirective(AModule.ModuleOptions, AModule.DeprecatedMsg);

         Consume(_SEMICOLON);

         { handle the global switches, do this before interface, because after interface has been
           read, all following directives are parsed as well }
         SetupGlobalSwitches;

         { generate now the global symboltable,
           define first as local to overcome dependency conflicts }
         AModule.LocalSymTable:=TGlobalSymTable.Create(AModule.ModuleName^,AModule.ModuleID);

         { insert unitsym of this unit to prevent other units having
           the same name }
         TAbstractUnitSymTable(AModule.LocalSymTable).InsertUnit(CUnitSym.Create(AModule.RealModuleName^,AModule));

         { load default system unit, it must be loaded before interface is parsed
           else we cannot use e.g. feature switches before the next real token }
         if AModule.IsInitial then
           Load_Packages;
         lLoadOK:=LoadSystemUnit(AModule);

         { system unit is loaded, now insert feature defines }
         for lFeature:=low(TFeature) to high(TFeature) do
           if lFeature in Features then
             Def_System_Macro('FPC_HAS_FEATURE_'+FeatureStr[lFeature]);

         Consume(_INTERFACE);

         { global switches are read, so further changes aren't allowed  }
         AModule.InGlobal:=false;

         message1(unit_u_loading_interface_units,AModule.ModuleName^);

         { update status }
         status.CurrentModule:=AModule.RealModuleName^;

         { maybe turn off m_objpas if we are compiling objpas }
         if (AModule.ModuleName^='OBJPAS') then
           exclude(CurrentSettings.ModeSwitches,m_objpas);

         { maybe turn off m_mac if we are compiling macpas }
         if (AModule.ModuleName^='MACPAS') then
           exclude(CurrentSettings.ModeSwitches,m_mac);

         ParseOnly:=true;

         { load default units, like language mode units }
         if not(cs_compilesystem in CurrentSettings.ModuleSwitches) then
           lLoadOK:=LoadDefaultUnits(AModule) and lLoadOK;

         { insert qualifier for the system unit (allows system.writeln) }
         if not(cs_compilesystem in CurrentSettings.ModuleSwitches) and
            (CurrentScanner.FToken=_USES) then
           begin
             // We do this as late as possible.
             if Assigned(AModule) then
               AModule.LoadLocalNamespaceList
             else
               CurrentNamespaceList:=Nil;
             ParseUsesClause(AModule);
             lLoadOK:=LoadUnits(AModule,true) and lLoadOK and not TModule.CTask_Fast_Backtrack;
             { has it been compiled at a higher level ?}
             if AModule.state in [ms_compiled,ms_processed] then
               begin
                 Message1(parser_u_already_compiled,AModule.RealModuleName^);
                 exit;
               end;

             AModule.ConsumeSemicolonAfterUses:=true;
           end
         else
           AModule.ConsumeSemicolonAfterUses:=false;

         { move the global symtable from the temporary local to global }
         CurrentModule.GlobalSymTable:=CurrentModule.LocalSymTable;
         CurrentModule.LocalSymTable:=nil;

         { Now we check if we can continue. }

         if not lLoadOK then
           AModule.state:=ms_compiling_waitintf;

         { create whole program optimisation information (may already be
           updated in the interface, e.g., in case of classrefdef typed
           constants }
         AModule.WPOInfo:=TUnitWPOInfo.Create;

         { Can we continue compiling ? }
         Result:=AModule.state<>ms_compiling_waitintf;
         if Result then
           Result:=ParseUnitInterfaceDeclarations(AModule);
      end;

    procedure ModuleIsDone(AModule: TModule);inline;
      begin
        dispose(PFinishState(AModule.FinishState));
        AModule.FinishState:=nil;
      end;

    function FinishCompileUnit(AModule: TModule): Boolean;

      function IsAssemblerGenerated:Boolean;
      var
        lAsmListType : TAsmListType;
      begin
        Result:=false;
        if ErrorCount=0 then
          begin
            for lAsmListType:=low(TAsmListType) to high(TAsmListType) do
              if not CurrentAsmData.asmlists[lAsmListType].empty then
                begin
                  Result:=true;
                  exit;
                end;
          end;
      end;

      var
{$ifdef EXTDEBUG}
        lStoredCRC,
{$endif EXTDEBUG}
        lForceInitFinal : Boolean;
        lInitializationProcedure,
        lFinalizationProcedure : TCGProcInfo;
        lAsmGenerated , lWaitDependency: Boolean;
        lFinishState : TFinishState;
        lOldModule, lWaitModule: TModule;
      begin
         Result:=true;
         { curr is now module }

         lOldModule:=CurrentModule;
         SetCurrentModule(AModule);

         if not Assigned(AModule.FinishState) then
           InternalError(2012091801);
         lFinishState:=PFinishState(AModule.FinishState)^;

         lFinalizationProcedure:=lFinishState.FinalizationProcedure;
         lInitializationProcedure:=lFinishState.InitializationProcedure;

         { Generate specializations of objectdefs methods }
         GenerateSpecializationProcs;

         { generate construction functions for all attributes in the unit:
           this must be done before writing the VMTs because
           during VMT writing  the extended field info is written }

         Generate_Attr_Constrs(CurrentModule.UsedRTTIAttrs);

         { Generate VMTs }
         if ErrorCount=0 then
           begin
             Write_VMTs(AModule.GlobalSymTable,true);
             Write_VMTs(AModule.LocalSymTable,false);
           end;

         { add implementations for synthetic method declarations added by
           the compiler }
         Add_Synthetic_Method_Implementations(AModule.GlobalSymTable);
         Add_Synthetic_Method_Implementations(AModule.LocalSymTable);

         { if the unit contains ansi/widestrings, initialization and
           finalization code must be forced }
         lForceInitFinal:=TGlobalSymTable(AModule.GlobalSymTable).Needs_Init_Final or
                           TStaticSymTable(AModule.LocalSymTable).Needs_Init_Final;

         { should we force unit initialization? }
         { this is a hack, but how can it be done better ? }
         { Now the sole purpose of this is to change 'init' to 'init_implicit',
           is it needed at all? (Sergei) }
         { it's needed in case cnodeutils.force_init = true }
         if (lForceInitFinal or CNodeUtils.Force_Init) and
            (
              not Assigned(lInitializationProcedure) or
              Has_No_Code(lInitializationProcedure.code)
            ) then
           begin
             { first release the not used init procinfo }
             if Assigned(lInitializationProcedure) then
               begin
                 Release_Proc_Symbol(lInitializationProcedure.procdef);
                 ReleaseMainProc(AModule,lInitializationProcedure);
               end;
             lInitializationProcedure:=GenImplicitInitFinal(AModule,mf_init,AModule.LocalSymTable);
           end;
         if (lForceInitFinal or CNodeUtils.Force_Final) and
            (
              not Assigned(lFinalizationProcedure) or
              Has_No_Code(lFinalizationProcedure.code)
            ) then
           begin
             { first release the not used finalize procinfo }
             if Assigned(lFinalizationProcedure) then
               begin
                 Release_Proc_Symbol(lFinalizationProcedure.procdef);
                 ReleaseMainProc(AModule,lFinalizationProcedure);
               end;
             lFinalizationProcedure:=GenImplicitInitFinal(AModule,mf_finalize,AModule.LocalSymTable);
           end;

         { Now both init and finalize bodies are read and it is known
           which variables are used in both init and finalize we can now
           generate the code. This is required to prevent putting a variable in
           a register that is also used in the finalize body (PFV) }
         if Assigned(lInitializationProcedure) then
           begin
             if (lForceInitFinal or CNodeUtils.Force_Init) or
                not(Has_No_Code(lInitializationProcedure.code)) then
               begin
                 lInitializationProcedure.code:=CNodeUtils.Wrap_Proc_Body(lInitializationProcedure.procdef,lInitializationProcedure.code);
                 lInitializationProcedure.Generate_Code_Tree;
                 include(AModule.ModuleFlags,mf_init);
               end
             else
               Release_Proc_Symbol(lInitializationProcedure.procdef);
             lInitializationProcedure.ResetProcDef;
             ReleaseMainProc(AModule,lInitializationProcedure);
           end;
         if Assigned(lFinalizationProcedure) then
           begin
             if lForceInitFinal or
                CNodeUtils.Force_Init or
                not(Has_No_Code(lFinalizationProcedure.code)) then
               begin
                 lFinalizationProcedure.code:=CNodeUtils.Wrap_Proc_Body(lFinalizationProcedure.procdef,lFinalizationProcedure.code);
                 lFinalizationProcedure.Generate_Code_Tree;
                 include(AModule.ModuleFlags,mf_finalize);
               end
             else
               Release_Proc_Symbol(lFinalizationProcedure.procdef);
             lFinalizationProcedure.ResetProcDef;
             ReleaseMainProc(AModule,lFinalizationProcedure);
           end;

         SymTableStack.pop(AModule.LocalSymTable);
         SymTableStack.pop(AModule.GlobalSymTable);

         { the last char should always be a point }
         { Do not attempt to read next token after dot,
           there may be a #0 when the unit was finished in a separate stage }
         ConsumeLastDot;

         { reset wpo flags for all defs }
         ResetAllDefs(AModule);

         if (ErrorCount=0) then
           begin
             { tests, if all (interface) forwards are resolved }
             TStoredSymTable(AModule.GlobalSymTable).Check_Forwards;
             { check if all private fields are used }
             TStoredSymTable(AModule.GlobalSymTable).AllPrivatesUsed;

             { test static symtable }
             TStoredSymTable(AModule.LocalSymTable).AllSymbolsUsed;
             TStoredSymTable(AModule.LocalSymTable).AllPrivatesUsed;
             TStoredSymTable(AModule.LocalSymTable).Check_Forwards;
             TStoredSymTable(AModule.LocalSymTable).CheckLabels;

             { used units }
             AModule.AllUnitsUsed;
           end;

         { leave when we got an error }
         if (ErrorCount>0) and not status.SkipError then
          begin
            Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
            status.SkipError:=true;
            ModuleIsDone(AModule);
            AModule.state:=ms_moduleerror;
            SetCurrentModule(lOldModule);
            exit(false);
          end;

         { if an Objective-C module, generate rtti and module info }
         MaybeGenerateObjectiveCImageInfo(AModule.GlobalSymTable,AModule.LocalSymTable);

         { do we need to add the variants unit? }
         MaybeLoadVariantsUnit(AModule);

         { generate rtti/init tables }
         Write_Persistent_Type_Info(AModule.GlobalSymTable,true);
         Write_Persistent_Type_Info(AModule.LocalSymTable,false);

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
         if (TargetInfo.system in systems_linux) and Assigned(AModule.ExportList.first) then
           exportlib.generatelib;

         { generate imports }
         if AModule.ImportLibraryList.Count>0 then
           importlib.generatelib;

         { insert own objectfile, or say that it's in a library
           (no check for an .o when loading) }
         if not PrepareModuleResources then
           begin
             SetCurrentModule(lOldModule);
             exit(false);
           end;
         lAsmGenerated:=IsAssemblerGenerated;
         if not lAsmGenerated then PublishResourceFiles;
         if lAsmGenerated then
           InsertObjectFile(AModule)
         else
           begin
             AModule.HeaderFlags:=AModule.HeaderFlags or UfNoLink;
             exclude(AModule.ModuleFlags,mf_has_dwarf_debuginfo);
           end;

         if lAsmGenerated then
           begin
             { create callframe info }
             CreateDwarfFrame;
             { assemble }
             CreateObjectFile(AModule);
           end;

        { remove all waits for this unit }
        AModule.Remove_All_WaitsForThisUnit;

        { compute CRC }
        if ErrorCount=0 then
          begin
          lWaitModule:=AModule.Find_Used_Unit_Compiling;
          lWaitDependency:=TPPUModule(AModule).Dependent_Module_Has_Our_CRC;
          if (lWaitModule<>nil) or lWaitDependency then
            begin
              { Some used units are still compiling, so their CRCs can change
                OR some dependent module waits for checking this module's CRC
                   (e.g. this module was recompiled and a ppu is waiting).
                Compute the final CRC of this module and wait.
                Needed for compiling circular dependent units. }
              {$IFDEF Debug_FreeParseMem}
              WriteLn('finish_compile_unit ',AModule.RealModuleName^,' waiting for used unit CRCs...');
              {$ENDIF}
              TPPUModule(AModule).GetPPUCRC;
              AModule.CRCFinal:=true;
              AModule.state:=ms_compiled_waitcrc;
              SetCurrentModule(lOldModule);
              exit(false);
            end;
          end;
        SetCurrentModule(lOldModule);

        Result:=FinishUnit(AModule);
      end;

    function FinishUnit(AModule: TModule): Boolean;

      var
{$ifdef EXTDEBUG}
        lStoredCRC,
{$endif EXTDEBUG}
        lStoredInterfaceCRC,
        lStoredIndirectCRC : Cardinal;
{$ifdef debug_devirt}
        lIndex : LongInt;
{$endif}
        lHStatus : TFPCHeapStatus;
        lOldModule: TModule;

      begin
        {$IFDEF Debug_FreeParseMem}
        WriteLn('finish_unit ',AModule.RealModuleName^,' write ppu and free mem...');
        {$ENDIF}
        Result:=ErrorCount=0;

        lOldModule:=CurrentModule;
        SetCurrentModule(AModule);

        { Write out the ppufile after the object file has been created }
        lStoredInterfaceCRC:=AModule.InterfaceCRC;
        lStoredIndirectCRC:=AModule.IndirectCRC;
{$ifdef EXTDEBUG}
        lStoredCRC:=AModule.crc;
{$endif EXTDEBUG}
        if Result then
        begin
          TPPUModule(AModule).WritePPU;
          CommitResourceFiles(AModule);
        end;

        if not(cs_compilesystem in CurrentSettings.ModuleSwitches) then
          begin
            if lStoredInterfaceCRC<>AModule.InterfaceCRC then
              Message1(unit_u_interface_crc_changed,AModule.PPUFileName);
            if lStoredIndirectCRC<>AModule.IndirectCRC then
              Message1(unit_u_indirect_crc_changed,AModule.PPUFileName);
          end;
{$ifdef EXTDEBUG}
        if not(cs_compilesystem in CurrentSettings.ModuleSwitches) then
          if (lStoredCRC<>AModule.crc) then
            Message1(unit_u_implementation_crc_changed,AModule.PPUFileName);
{$endif EXTDEBUG}

        { release unregistered defs/syms from the localsymtable }
        FreeUnregisteredLocalSymTableElements(AModule);
        { release local symtables that are not needed anymore }
        FreeLocalSymTables(AModule.GlobalSymTable);
        FreeLocalSymTables(AModule.LocalSymTable);

        { leave when we got an error }
        if (ErrorCount>0) then
          begin
            if not status.SkipError then
              begin
                Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
                status.SkipError:=true;
              end;
            ModuleIsDone(AModule);
            AModule.state := ms_moduleerror;
            SetCurrentModule(lOldModule);
            exit;
          end;

{$ifdef debug_devirt}
        { print out all instantiated class/object types }
        WriteLn('constructed object/class/classreftypes in ',AModule.RealModuleName^);
        for lIndex := 0 to AModule.WPOInfo.createdobjtypes.count-1 do
          begin
            write('  ',TDef(AModule.WPOInfo.createdobjtypes[lIndex]).GetTypeName);
            case TDef(AModule.WPOInfo.createdobjtypes[lIndex]).typ of
              objectdef:
                case TObjectDef(AModule.WPOInfo.createdobjtypes[lIndex]).ObjectType of
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

        for lIndex := 0 to AModule.WPOInfo.createdclassrefobjtypes.count-1 do
          begin
            write('  Class Of ',TDef(AModule.WPOInfo.createdclassrefobjtypes[lIndex]).GetTypeName);
            case TDef(AModule.WPOInfo.createdclassrefobjtypes[lIndex]).typ of
              objectdef:
                case TObjectDef(AModule.WPOInfo.createdclassrefobjtypes[lIndex]).ObjectType of
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

        Message1(unit_u_finished_compiling,AModule.ModuleName^);

        ModuleIsDone(AModule);
        AModule.End_Of_Parsing;

        if ((status.verbosity and VStatus)<>0) then
        begin
          {$IF defined(Debug_FreeParseMem)}
          WriteLn('finish_unit ',AModule.RealModuleName^,' wrote ppu and freed mem.');
          {$ENDIF}
          lHStatus:=GetFPCHeapStatus;
          WriteLn(DStr(lHStatus.CurrHeapUsed shr 10),'/',DStr(lHStatus.CurrHeapSize shr 10),' Kb Used');
        end;

        AModule.state:=ms_compiled;

        SetCurrentModule(lOldModule);
      end;

    function ProcPackage(AModule: TModule) : Boolean;
      var
        lMainFile : TInputFile;
        lModuleName: AnsiString;
        lFeature : TFeature;
      begin
         Result:=True;
         Status.IsPackage:=true;
         Status.IsExe:=true;
         ParseOnly:=false;
         {InitializationProcedure:=nil;
         FinalizationProcedure:=nil;}

         if not (tf_supports_packages in TargetInfo.flags) then
           begin
             message1(parser_e_packages_not_supported,TargetInfo.name);
             AModule.state:=ms_moduleerror;
             status.SkipError:=true;
             exit(false);
           end;

         if not RelocSectionSetExplicitly then
           RelocSection:=true;

         { get correct output names }
         lMainFile := CurrentScanner.FInputFile;
         while Assigned(lMainFile.next) do
           lMainFile := lMainFile.next;

         AModule.SetFileName(lMainFile.path+lMainFile.name,true);

         { consume _PACKAGE word }
         Consume(_ID);

         lModuleName:=CurrentScanner.FOrgPattern;
         Consume(_ID);
         while CurrentScanner.FToken=_POINT do
           begin
             Consume(_POINT);
             lModuleName:=lModuleName+'.'+CurrentScanner.FOrgPattern;
             Consume(_ID);
           end;

         AModule.SetModuleName(lModuleName);
         AModule.IsPackage:=true;
         if OutputFileName='' then
           AModule.SharedLibFileName:=ExtractFilePath(AModule.SharedLibFileName)+
             lModuleName+NexusPackageLibraryExtension;
         exportlib.preparelib(lModuleName);

         if tf_library_needs_pic in TargetInfo.flags then
           include(CurrentSettings.ModuleSwitches,cs_create_pic);

         { setup things using the switches, do this before the semicolon, because after the semicolon has been
           read, all following directives are parsed as well }

         SetupGlobalSwitches;


         Consume(_SEMICOLON);

         { global switches are read, so further changes aren't allowed }
         AModule.InGlobal:=false;

         { set implementation flag }
         AModule.InInterface:=false;
         AModule.InterfaceCompiled:=true;

         { insert after the unit symbol tables the static symbol table }
         { of the program                                             }
         AModule.LocalSymTable:=TStaticSymTable.Create(AModule.RealModuleName^,AModule.ModuleID);

         { ensure that no packages are picked up from the options }
         PackageList.clear;

         { There should always be a requires, except for the system package. So we load here }
         if Assigned(AModule) then
           AModule.LoadLocalNamespaceList
         else
           CurrentNamespaceList:=Nil;

         {Read the packages used by the package we compile.}
         if (CurrentScanner.FToken=_ID) and (CurrentScanner.FIDToken=_REQUIRES) then
           begin
             { consume _REQUIRES word }
             Consume(_ID);
             while true do
               begin
                 if CurrentScanner.FToken=_ID then
                   begin
                     lModuleName:=CurrentScanner.FOrgPattern;
                     Consume(_ID);
                     while CurrentScanner.FToken=_POINT do
                       begin
                         Consume(_POINT);
                         lModuleName:=lModuleName+'.'+CurrentScanner.FOrgPattern;
                         Consume(_ID);
                       end;
                     Add_Package(lModuleName,false,true);
                   end
                 else
                   Consume(_ID);
                 if CurrentScanner.FToken=_COMMA then
                   Consume(_COMMA)
                 else
                   break;
               end;
             Consume(_SEMICOLON);
           end;

         { now load all packages, so that we can determine whether a unit is
           already provided by one of the loaded packages }
         Load_Packages;

         if PackageList.Count>0 then
           begin
             { this means the SYSTEM unit *must* be part of one of the required
               packages, so load it }
             AddUnit(AModule,'system',false);
             SystemUnit:=TGlobalSymTable(SymTableStack.top);
             LoadInternTypes;
             CheckSystemCharWidth;
             { system unit is loaded, now insert feature defines }
             for lFeature:=low(TFeature) to high(TFeature) do
               if lFeature in Features then
                 Def_System_Macro('FPC_HAS_FEATURE_'+FeatureStr[lFeature]);
           end;

         { Register contained units before yielding to the existing scheduler. }
         AModule.ConsumeSemicolonAfterUses:=false;
         if (CurrentScanner.FToken=_ID) and (CurrentScanner.FIDToken=_CONTAINS) then
           begin
             { Cached contained units can dereference built-in types while
               loading their dependencies, before finish_package is reached. }
             if not Assigned(SystemUnit) then
               LoadSystemUnit(AModule);
             ParseUsesClause(AModule,true);
             LoadUnits(AModule,false);
             AModule.ConsumeSemicolonAfterUses:=true;
           end;
         AModule.state:=ms_compiling_wait;
         Result:=false;
      end;

    function FinishPackage(AModule: TModule) : Boolean;
      var
        lModule,lNextModule : TModule;
        lPackage : TPCPPackage;
        lMainProcInfo : TCGProcInfo;
        lForceInitFinal : Boolean;
        lUsedUnit : TUsedUnit;
        lPackageEntry : PPackageEntry;
        lIndex : LongInt;
      begin
         Result:=true;
         SetCurrentModule(AModule);
         lMainProcInfo:=nil;
         { A package without requirements can provide System itself. }
         lModule:=TModule(Loaded_Units.first);
         while Assigned(lModule) do
           begin
             if (lModule.ModuleName^='SYSTEM') and not Assigned(SystemUnit) then
               begin
                 SystemUnit:=TGlobalSymTable(lModule.GlobalSymTable);
                 LoadInternTypes;
                 CheckSystemCharWidth;
               end;
             lModule:=TModule(lModule.next);
           end;
         if not Assigned(SystemUnit) then
           Comment(VFatal,'Package '+AModule.RealModuleName^+' does not contain or require the System unit');
         lPackage:=TPCPPackage.Create(AModule.RealModuleName^);
         { All units are read, now give them a number }
         AModule.UpdateMaps;
         ConnectLoadedUnits(AModule,nil);
         if AModule.ConsumeSemicolonAfterUses then
           begin
             Consume(_SEMICOLON);
             AModule.ConsumeSemicolonAfterUses:=false;
           end;

         lModule:=TModule(Loaded_Units.first);
         while Assigned(lModule) do
           begin
             if (lModule<>AModule) and not Assigned(lModule.package) then
               begin
                 if mf_package_deny in lModule.ModuleFlags then
                   message1(package_e_unit_deny_package,lModule.RealModuleName^);
                 { part of the package's used, aka contained units? }
                 lUsedUnit:=TUsedUnit(AModule.UsedUnitList.first);
                 while Assigned(lUsedUnit) do
                   begin
                     if lUsedUnit.u=lModule then
                       break;
                     lUsedUnit:=TUsedUnit(lUsedUnit.next);
                   end;
                 if not Assigned(lUsedUnit) then
                   message2(package_n_implicit_unit_import,lModule.RealModuleName^,AModule.RealModuleName^);
               end;
             { was this unit listed as a contained unit? If so => error }
             if (lModule<>AModule) and Assigned(lModule.package) then
               begin
                 lUsedUnit:=TUsedUnit(AModule.UsedUnitList.first);
                 while Assigned(lUsedUnit) do
                   begin
                     if lUsedUnit.u=lModule then
                       break;
                     lUsedUnit:=TUsedUnit(lUsedUnit.next);
                   end;
                 if Assigned(lUsedUnit) then
                   message2(package_e_unit_already_contained_in_package,lModule.RealModuleName^,lModule.package.RealPackageName^);
               end;
             lModule:=TModule(lModule.next);
           end;

         {Insert the name of the main program into the symbol table.}
         if AModule.RealModuleName^<>'' then
           TAbstractUnitSymTable(AModule.LocalSymTable).InsertUnit(CUnitSym.Create(AModule.RealModuleName^,AModule));

         Message1(parser_u_parsing_implementation,AModule.MainSource);

         SymTableStack.push(AModule.LocalSymTable);

         { create whole program optimisation information }
         AModule.WPOInfo:=TUnitWPOInfo.Create;

         { should we force unit initialization? }
         lForceInitFinal:=TStaticSymTable(AModule.LocalSymTable).Needs_Init_Final;
         if lForceInitFinal or CNodeUtils.Force_Init then
           {InitializationProcedure:=gen_implicit_initfinal(mf_init,curr.localsymtable)};

         { Add symbol to the exports section for win32 so smartlinking a
           DLL will include the edata section }
         if Assigned(exportlib) and
            (TargetInfo.system=system_i386_win32) and
            (mf_has_exports in AModule.ModuleFlags) then
           CurrentAsmData.asmlists[al_procedures].concat(TAIConst.createname(Make_MangledName('EDATA',AModule.LocalSymTable,''),0));

         { all labels must be defined before generating code }
         if ErrorCount=0 then
           TStoredSymTable(AModule.LocalSymTable).CheckLabels;

         SymTableStack.pop(AModule.LocalSymTable);

         { consume the last point }
         Consume(_END);
         Consume(_POINT);

         if (ErrorCount=0) then
           begin
             { test static symtable }
             TStoredSymTable(AModule.LocalSymTable).AllSymbolsUsed;
             TStoredSymTable(AModule.LocalSymTable).AllPrivatesUsed;
             TStoredSymTable(AModule.LocalSymTable).Check_Forwards;

             { Note: all contained units are considered as used }
           end;

         if TargetInfo.system in systems_all_windows then
           begin
             SymTableStack.push(AModule.LocalSymTable);
             lMainProcInfo:=CreateMainProc('_PkgEntryPoint',potype_pkgstub,AModule.LocalSymTable);
             lMainProcInfo.procdef.AliasNames.concat('_DLLMainCRTStartup');
             lMainProcInfo.code:=Generate_Pkg_Stub(lMainProcInfo.procdef);
             lMainProcInfo.Generate_Code;
             SymTableStack.pop(AModule.LocalSymTable);
           end;


         { leave when we got an error }
         if (ErrorCount>0) and not status.SkipError then
           begin
             Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
             status.SkipError:=true;
             AModule.state:=ms_moduleerror;
             lPackage.free;
             lPackage := nil;
             exit(false);
           end;

         { remove all unused units, this happens when units are removed
           from the uses clause in the source and the ppu was already being loaded }
         lModule:=TModule(Loaded_Units.first);
         while Assigned(lModule) do
          begin
            lNextModule:=lModule;
            lModule:=TModule(lModule.next);
            if Assigned(lNextModule.package) then
              Add_Package_Unit_Ref(lNextModule.package);
            if lNextModule.IsUnit and
               not Assigned(lNextModule.GlobalSymTable) then
              Loaded_Units.remove(lNextModule);
          end;

         exportlib.ignoreduplicates:=true;

         if TargetInfo.system in [system_x86_64_win64,system_x86_64_linux] then
           begin
             CNodeUtils.InsertInitFinalTable(AModule);
             CNodeUtils.InsertThreadvarTablesTable;
             CNodeUtils.InsertResourceTablesTable;
             CNodeUtils.InsertWideInitsTablesTable;
             CNodeUtils.InsertResStrTablesTable;
             Emit_Package_Descriptor;
             if TargetInfo.system=system_x86_64_linux then
               begin
                 export.exportname('FPC_RESLOCATION',[eo_name]);
               end;
           end;

         { force exports }
         lUsedUnit:=TUsedUnit(UsedUnits.first);
         while Assigned(lUsedUnit) do
           begin
             if not Assigned(SystemUnit) and (lUsedUnit.u.ModuleName^='SYSTEM') then
               begin
                 SystemUnit:=TGlobalSymTable(lUsedUnit.u.GlobalSymTable);
                 LoadInternTypes;
                 CheckSystemCharWidth;
               end;
             if not Assigned(lUsedUnit.u.package) then
               Export_Unit(lUsedUnit.u);

             lUsedUnit:=TUsedUnit(lUsedUnit.next);
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
         if AModule.ImportLibraryList.Count>0 then
           importlib.generatelib;

         { Reference all DEBUGINFO sections from the main .fpc section }
         if (cs_debuginfo in CurrentSettings.ModuleSwitches) then
           CurrentDebugInfo.referencesections(CurrentAsmData.asmlists[al_procedures]);

         { we add all loaded units that are not part of a package to the
           package; this includes units in the "contains" section as well
           as implicitly imported ones }
         lModule:=TModule(Loaded_Units.first);
         while Assigned(lModule) do
          begin
            if (lModule<>AModule) then
              begin
                if not Assigned(lModule.package) then
                  begin
                    lPackage.AddUnit(lModule);
                    Check_For_Indirect_Package_Usages(lModule.UsedUnitList);
                  end
                else
                  begin
                    lPackageEntry:=PPackageEntry(PackageList.find(lModule.package.PackageName^));
                    if not Assigned(lPackageEntry) then
                      InternalError(2015112301);
                    lPackage.Add_Required_Package(lModule.package);
                  end;
              end;
            lModule:=TModule(lModule.next);
          end;

         { A declared dependency also owns initialization/lifetime work
           when none of its units contributed a referenced symbol. }
         for lIndex:=0 to PackageList.count-1 do
           begin
             lPackageEntry:=PPackageEntry(PackageList[lIndex]);
             if lPackageEntry^.direct then
               lPackage.Add_Required_Package(lPackageEntry^.package);
           end;
         lPackage.InitModuleInfo(AModule);

         { Metadata is part of the package object before native linking. }
         lPackage.SavePCP;

         { insert own objectfile }
         InsertObjectFile(AModule);

         { assemble and link }
         CreateObjectFile(AModule);

         { We might need the symbols info if not using
           the default do_extractsymbolinfo
           which is a dummy function PM }
         NeedSymbolInfo:=Do_ExtractSymbolInfo<>@Def_ExtractSymbolInfo;
         { release all local symtables that are not needed anymore }
         if (not NeedSymbolInfo) then
           FreeLocalSymTables(AModule.LocalSymTable);

         { leave when we got an error }
         if (ErrorCount>0) and not status.SkipError then
          begin
            Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
            status.SkipError:=true;
            AModule.state:=ms_moduleerror;
            lPackage.free;
            lPackage := nil;
            exit(false);
          end;

         if (not AModule.IsUnit) then
           begin
             { create the executable when we are at level 1 }
             if (AModule.IsInitial) then
               begin
                 { write .def file }
                 if (cs_link_deffile in CurrentSettings.GlobalSwitches) then
                   deffile.writefile;

                 { The sequential continuation still visits the package
                   after linking. Remove its dependency edges before freeing
                   their modules, as proc_create_executable does. }
                 AModule.UsedUnitList.free;
                 AModule.UsedUnitList:=TLinkedList.Create;
                 { insert all .o files from all loaded units and
                   unload the units, we don't need them anymore.
                   Keep the curr because that is still needed }
                 lModule:=TModule(Loaded_Units.first);
                 while Assigned(lModule) do
                  begin
                    { only link in those units which should become part of this
                      package }
                    if not Assigned(lModule.package) then
                      linker.AddModuleFiles(lModule);
                    lNextModule:=TModule(lModule.next);
                    if (lModule<>AModule) and
                       (not NeedSymbolInfo) then
                      begin
                        Loaded_Units.remove(lModule);
                        lModule.free;
                        lModule := nil;
                      end;
                    lModule:=lNextModule;
                  end;
                 { add the library of directly used packages }
                 Add_Package_Libs(linker);
                 { and now link the package library }
                 linker.MakeSharedLibrary
               end;

             { Give Fatal with error count for linker errors }
             if (ErrorCount>0) and not status.SkipError then
              begin
                Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
                status.SkipError:=true;
                AModule.state:=ms_moduleerror;
                Result:=false;
              end;

             lPackage.free;
             lPackage := nil;
          end;
         if Result then
           begin
             AModule.CRCFinal:=true;
             AModule.state:=ms_compiled;
           end;
      end;

    procedure ProcCreateExecutable(AModule, ASystemInitModule: TModule; AIsLibrary : Boolean);

      var
        lProgramUsesCheckPointer : Boolean;
        lModule,lNextModule : TModule;

      begin
            { write .def file }
            if (cs_link_deffile in CurrentSettings.GlobalSwitches) then
             deffile.writefile;
            { link SysInit (if any) first, to have behavior consistent with
              assembler startup files }
            if Assigned(ASystemInitModule) then
              linker.AddModuleFiles(ASystemInitModule);
            { Does any unit use checkpointer function }
            lProgramUsesCheckPointer:=false;
            { before freeing modules, free used_units }
            AModule.UsedUnitList.free;
            AModule.UsedUnitList:=TLinkedList.Create;
            { insert all .o files from all loaded units and
              unload the units, we don't need them anymore.
              Keep the curr because that is still needed }
            lModule:=TModule(Loaded_Units.first);
            while Assigned(lModule) do
             begin
               if (lModule<>ASystemInitModule) and not Assigned(lModule.package) then
                 begin
                   linker.AddModuleFiles(lModule);
                   if mf_checkpointer_called in lModule.ModuleFlags then
                     lProgramUsesCheckPointer:=true;
                 end;
               lNextModule:=TModule(lModule.next);
               if Assigned(lModule.package) then
                 Add_Package_Unit_Ref(lModule.package);
               if (lModule<>AModule) and
                  (not NeedSymbolInfo) then
                 begin
                   Loaded_Units.remove(lModule);
                   lModule.free;
                   lModule := nil;
                 end;
               lModule:=lNextModule;
             end;
            { free also unneeded units we didn't free before }
            if not NeedSymbolInfo then
              Unloaded_Units.Clear;
            { Does any unit use checkpointer function }
            if lProgramUsesCheckPointer then
              Message1(link_w_program_uses_checkpointer,AModule.ModuleName^);

            { add all directly used packages as libraries }
            Add_Package_Libs(linker);
            { finally we can create an executable }
            if AModule.IsLibrary then
              linker.MakeSharedLibrary
            else
              linker.MakeExecutable;

            { collect all necessary information for whole-program optimization }
            wpoinfomanager.extractwpoinfofromprogram;

      end;

    procedure ProcProgramAfterParsing(AModule : TModule; AIsLibrary : Boolean);

      var
        lSystemInitModule, lModule,lNextModule : TModule;
        lResourcesUsed : Boolean;

      begin
        lSystemInitModule:=nil;
        lModule:=nil;
        lNextModule:=nil;
        lResourcesUsed:=false;


        { reset wpo flags for all defs }
        ResetAllDefs(AModule);

        if (ErrorCount=0) then
          begin
            { test static symtable }
            TStoredSymTable(AModule.LocalSymTable).AllSymbolsUsed;
            TStoredSymTable(AModule.LocalSymTable).AllPrivatesUsed;
            TStoredSymTable(AModule.LocalSymTable).Check_Forwards;

            AModule.AllUnitsUsed;
          end;

        { leave when we got an error }
        if (ErrorCount>0) and not status.SkipError then
          begin
            Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
            status.SkipError:=true;
            AModule.state:=ms_moduleerror;
            exit;
          end;

        { remove all unused units, this happens when units are removed
          from the uses clause in the source and the ppu was already being loaded }
        lModule:=TModule(Loaded_Units.first);
        while Assigned(lModule) do
         begin
           lNextModule:=lModule;
           lModule:=TModule(lModule.next);
           if lNextModule.IsUnit and
              not Assigned(lNextModule.GlobalSymTable) then
               begin
                 Loaded_Units.remove(lNextModule);
                 Unloaded_Units.concat(lNextModule);
               end;
         end;

        { do we need to add the variants unit? }
        MaybeLoadVariantsUnit(AModule);

        { Now that everything has been compiled we know if we need resource
          support. If not, remove the unit. }
        lResourcesUsed:=MaybeRemoveResUnit(AModule);

        linker.initsysinitunitname;
        if (TargetInfo.system in [system_x86_64_win64,system_x86_64_linux]) and
           Assigned(Find_Module_From_SymTable(SystemUnit).package) then
          linker.sysinitunit:='sysinitpkg';
        if TargetInfo.system in systems_internal_sysinit then
        begin
          { add start/halt unit }
          lSystemInitModule:=AddUnit(AModule,linker.sysinitunit);
        end
        else
          lSystemInitModule:=nil;

        CNodeUtils.InsertThreadvars;

        { generate rtti/init tables }
        Write_Persistent_Type_Info(AModule.LocalSymTable,false);

        { if an Objective-C module, generate rtti and module info }
        MaybeGenerateObjectiveCImageInfo(nil,AModule.LocalSymTable);

        { generate debuginfo }
        if (cs_debuginfo in CurrentSettings.ModuleSwitches) then
          CurrentDebugInfo.inserttypeinfo;

        if AIsLibrary or (TargetInfo.system in systems_unit_program_exports) then
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
        CNodeUtils.InsertInitFinalTable(AModule);
        CNodeUtils.InsertThreadvarTablesTable;
        CNodeUtils.InsertResourceTablesTable;
        CNodeUtils.InsertWideInitsTablesTable;
        CNodeUtils.InsertResStrTablesTable;
        CNodeUtils.InsertMemorySizes;

        if (TargetInfo.system in [system_x86_64_win64,system_x86_64_linux]) and
           Assigned(Find_Module_From_SymTable(SystemUnit).package) then
          Emit_Package_Descriptor;

        { create callframe info }
        CreateDwarfFrame;

        { create import library for all packages }
        if PackageList.count>0 then
          CreateImportLibFromExternals;

        { generate imports }
        if AModule.ImportLibraryList.Count>0 then
          importlib.generatelib;

        { insert own objectfile }
        InsertObjectFile(AModule);

        { assemble and link }
        CreateObjectFile(AModule);

        { We might need the symbols info if not using
          the default do_extractsymbolinfo
          which is a dummy function PM }
        NeedSymbolInfo:=
          (Do_ExtractSymbolInfo<>@Def_ExtractSymbolInfo) or
          ((CurrentSettings.GenWPOptimizerSwitches*WPOptimizationsNeedingAllUnitInfo)<>[]);

        { release all local symtables that are not needed anymore }
        if (not NeedSymbolInfo) then
          FreeLocalSymTables(AModule.LocalSymTable);

        { leave when we got an error }
        if (ErrorCount>0) and not status.SkipError then
          begin
            Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
            status.SkipError:=true;
            AModule.state:=ms_moduleerror;
            exit;
          end;
        { create the executable when we are at level 1 }

        if (not AModule.IsUnit) and (AModule.IsInitial) then
          ProcCreateExecutable(AModule,lSystemInitModule,AIsLibrary);

        { Give Fatal with error count for linker errors }
        if (ErrorCount>0) and not status.SkipError then
         begin
           Message1(unit_f_errors_in_unit,ToStr(ErrorCount));
           status.SkipError:=true;
         end;

        AModule.CRCFinal:=true;
        AModule.state:=ms_compiled;

      end;

    function ProcProgramDeclarations(AModule : TModule; AIsLibrary : Boolean) : Boolean;

      var
        lInitPD    : TProcDef;
        lFinalizationProcedure,
        lInitializationProcedure,
        lMainProcInfo : TCGProcInfo;
        lForceInitFinal : Boolean;

      begin
        Result:=true;
        lMainProcInfo:=nil;
        lInitializationProcedure:=nil;
        lFinalizationProcedure:=nil;

        SetCurrentModule(AModule);

        { All units are read, now give them a number }
        AModule.UpdateMaps;

        ConnectLoadedUnits(AModule,nil);

        { consume the semicolon after maps have been updated else conditional compiling expressions
          might cause internal errors, see tw8611 }
        if AModule.ConsumeSemicolonAfterUses then
          begin
            Consume(_SEMICOLON);
            AModule.ConsumeSemicolonAfterUses:=false;
          end;

        {Insert the name of the main program into the symbol table.}
        if AModule.RealModuleName^<>'' then
          TAbstractUnitSymTable(AModule.LocalSymTable).InsertUnit(CUnitSym.Create(AModule.RealModuleName^,AModule));

        Message1(parser_u_parsing_implementation,AModule.MainSource);

        SymTableStack.push(AModule.LocalSymTable);


        { Insert _GLOBAL_OFFSET_TABLE_ symbol if system uses it }
        MaybeLoadGOT(AModule);

        { create whole program optimisation information }
        AModule.WPOInfo:=TUnitWPOInfo.Create;

        { The program initialization needs an alias, so it can be called
          from the bootstrap code.}
        if AIsLibrary then
         begin
           lInitPD:=nil;
           { ToDo: other systems that use indirect entry info, but check back with Windows! }
           { we need to call FPC_LIBMAIN in sysinit which in turn will call PascalMain -> create dummy stub }
           if TargetInfo.system in systems_darwin then
             begin
               lMainProcInfo:=CreateMainProc(Make_MangledName('sysinitcallthrough',AModule.LocalSymTable,'stub'),potype_libmainstub,AModule.LocalSymTable);
               Call_Through_New_Name(lMainProcInfo.procdef,TargetInfo.cprefix+'FPC_LIBMAIN');
               lInitPD:=lMainProcInfo.procdef;
               lMainProcInfo.free;
               lMainProcInfo := nil;
             end;

           lMainProcInfo:=CreateMainProc(Make_MangledName('',AModule.LocalSymTable,MainAliasName),potype_proginit,AModule.LocalSymTable);
           { Win32 startup code needs a single name }
           if not(TargetInfo.system in systems_darwin) then
             lMainProcInfo.procdef.AliasNames.concat('PASCALMAIN')
           else
             lMainProcInfo.procdef.AliasNames.concat(TargetInfo.Cprefix+'PASCALMAIN');

           if not(TargetInfo.system in systems_darwin) then
             lInitPD:=lMainProcInfo.procdef;

           CNodeUtils.RegisterModuleInitFunction(lInitPD);
         end
        else if (TargetInfo.system in systems_darwin) then
          begin
            { create a stub with the name of the desired main routine, with
              the same signature as the C "main" function, and call through to
              FPC_SYSTEMMAIN, which will initialise everything based on its
              parameters. This function cannot be in the system unit, because
              its name can be configured on the command line (for use with e.g.
              SDL, where the main function should be called SDL_main) }
            lMainProcInfo:=CreateMainProc(MainAliasName,potype_mainstub,AModule.LocalSymTable);
            Call_Through_New_Name(lMainProcInfo.procdef,TargetInfo.cprefix+'FPC_SYSTEMMAIN');
            lMainProcInfo.free;
            { now create the PASCALMAIN routine (which will be called from
              FPC_SYSTEMMAIN) }
            lMainProcInfo:=CreateMainProc('PASCALMAIN',potype_proginit,AModule.LocalSymTable);
          end
        else
          begin
            lMainProcInfo:=CreateMainProc(MainAliasName,potype_proginit,AModule.LocalSymTable);
            lMainProcInfo.procdef.AliasNames.concat('PASCALMAIN');
          end;
        lMainProcInfo.Parse_Body;
        { save file pos for debuginfo }
        AModule.MainFilePos:=lMainProcInfo.EntryPos;

        { finalize? }
        if CurrentScanner.FToken=_FINALIZATION then
          begin
             { Parse the finalize }
             lFinalizationProcedure:=CreateMainProc(Make_MangledName('',AModule.LocalSymTable,'finalize$'),potype_unitfinalize,AModule.LocalSymTable);
             lFinalizationProcedure.procdef.AliasNames.insert(Make_MangledName('FINALIZE$',AModule.LocalSymTable,''));
             lFinalizationProcedure.procdef.AliasNames.concat('PASCALFINALIZE');
             lFinalizationProcedure.Parse_Body;
          end;

        { Generate specializations of objectdefs methods }
        if ErrorCount=0 then
          GenerateSpecializationProcs;

        { generate construction functions for all attributes in the program }
        { before write_vmts that assume attributes for methods is ready }
        Generate_Attr_Constrs(AModule.UsedRTTIAttrs);

        { Generate VMTs }
        if ErrorCount=0 then
          Write_VMTs(AModule.LocalSymTable,false);

        { add implementations for synthetic method declarations added by
          the compiler }
        Add_Synthetic_Method_Implementations(AModule.LocalSymTable);

        { should we force unit initialization? }
        lForceInitFinal:=TStaticSymTable(AModule.LocalSymTable).Needs_Init_Final;
        if lForceInitFinal or CNodeUtils.Force_Init then
          lInitializationProcedure:=GenImplicitInitFinal(AModule,mf_init,AModule.LocalSymTable);

        { Add symbol to the exports section for win32 so smartlinking a
          DLL will include the edata section }
        if Assigned(exportlib) and
           (TargetInfo.system=system_i386_win32) and
           (mf_has_exports in AModule.ModuleFlags) then
          CurrentAsmData.asmlists[al_procedures].concat(TAIConst.createname(Make_MangledName('EDATA',AModule.LocalSymTable,''),0));

        if (lForceInitFinal or CNodeUtils.Force_Final) and
           (
             not Assigned(lFinalizationProcedure)
             or Has_No_Code(lFinalizationProcedure.code)
           ) then
          begin
            { first release the not used finalize procinfo }
            if Assigned(lFinalizationProcedure) then
              begin
                Release_Proc_Symbol(lFinalizationProcedure.procdef);
                ReleaseMainProc(AModule,lFinalizationProcedure);
              end;
            lFinalizationProcedure:=GenImplicitInitFinal(AModule,mf_finalize,AModule.LocalSymTable);
          end;

         { the finalization routine of libraries is generic (and all libraries need to }
         { be finalized, so they can finalize any units they use                       }
         { Place in "pure assembler" list so that the llvm assembler writer
           directly emits the generated directives }
         if (AIsLibrary) then
           CNodeUtils.RegisterModuleFiniFunction(Search_System_Proc('fpc_lib_exit'));

        { all labels must be defined before generating code }
        if ErrorCount=0 then
          TStoredSymTable(AModule.LocalSymTable).CheckLabels;

        { See remark in unit init/final }
        lMainProcInfo.Generate_Code_Tree;
        lMainProcInfo.ResetProcDef;
        ReleaseMainProc(AModule,lMainProcInfo);
        if Assigned(lInitializationProcedure) then
          begin
            { initialization can be implicit only }
            include(AModule.ModuleFlags,mf_init);
            lInitializationProcedure.code:=CNodeUtils.Wrap_Proc_Body(lInitializationProcedure.procdef,lInitializationProcedure.code);
            lInitializationProcedure.Generate_Code;
            lInitializationProcedure.ResetProcDef;
            ReleaseMainProc(AModule,lInitializationProcedure);
          end;
        if Assigned(lFinalizationProcedure) then
          begin
            if lForceInitFinal or
               CNodeUtils.Force_Init or
               not(Has_No_Code(lFinalizationProcedure.code)) then
              begin
                lFinalizationProcedure.code:=CNodeUtils.Wrap_Proc_Body(lFinalizationProcedure.procdef,lFinalizationProcedure.code);
                lFinalizationProcedure.Generate_Code_Tree;
                include(AModule.ModuleFlags,mf_finalize);
              end;
            lFinalizationProcedure.ResetProcDef;
            ReleaseMainProc(AModule,lFinalizationProcedure);
          end;

        SymTableStack.pop(AModule.LocalSymTable);

        { consume the last point }
        Consume(_POINT);


        ProcProgramAfterParsing(AModule,AIsLibrary);


      end;

    procedure ProcLibraryHeader(AModule: TModule);
      var
        lProgramName : AnsiString;

      begin
        Consume(_LIBRARY);
        lProgramName:=CurrentScanner.FOrgPattern;
        Consume(_ID);
        while CurrentScanner.FToken=_POINT do
         begin
           Consume(_POINT);
           lProgramName:=lProgramName+'.'+CurrentScanner.FOrgPattern;
           Consume(_ID);
         end;
        AModule.SetModuleName(lProgramName);
        AModule.IsLibrary:=true;
        exportlib.preparelib(lProgramName);

        if tf_library_needs_pic in TargetInfo.flags then
         begin
           include(CurrentSettings.ModuleSwitches,cs_create_pic);
           { also set create_pic for all unit compilation }
           include(InitSettings.ModuleSwitches,cs_create_pic);
         end;

        { setup things using the switches, do this before the semicolon, because after the semicolon has been
         read, all following directives are parsed as well }
        SetupGlobalSwitches;

      end;

    type
      TProgramParam = record
        Name : AnsiString;
        Number : DWord;
      end;
      TProgramParamArray = array of TProgramParam;

      procedure ProcProgramHeader(AModule: TModule; out AProgramParams : TProgramParamArray);

        var
          lProgramName : AnsiString;
          lParamNum : Integer;

        begin
          AProgramParams:=nil;
          Consume(_PROGRAM);
          lProgramName:=CurrentScanner.FOrgPattern;
          Consume(_ID);
          while CurrentScanner.FToken=_POINT do
            begin
              Consume(_POINT);
              lProgramName:=lProgramName+'.'+CurrentScanner.FOrgPattern;
              Consume(_ID);
            end;
          AModule.SetModuleName(lProgramName);
          if (TargetInfo.system in systems_unit_program_exports) then
            exportlib.preparelib(lProgramName);
          if CurrentScanner.FToken=_LKLAMMER then
            begin
               Consume(_LKLAMMER);
               lParamNum:=1;
               repeat
                 if m_isolike_program_para in CurrentSettings.ModeSwitches then
                   begin
                     if (CurrentScanner.FPattern<>'INPUT') and (CurrentScanner.FPattern<>'OUTPUT') then
                       begin
                         { the symtablestack is not setup here, so text must be created later on }
                         SetLength(AProgramParams,length(AProgramParams)+1);
                         with AProgramParams[high(AProgramParams)] do
                           begin
                             Name:=CurrentScanner.FPattern;
                             Number:=lParamNum;
                           end;
                         inc(lParamNum);
                       end;
                   end;
                 Consume(_ID);
               until not TryToConsume(_COMMA);
               Consume(_RKLAMMER);
            end;

          { setup things using the switches, do this before the semicolon, because after the semicolon has been
            read, all following directives are parsed as well }
          SetupGlobalSwitches;


        end;

    function ProcProgram(AModule: TModule; AIsLibrary : Boolean) : Boolean;

      var
         lMainFile : TInputFile;
         lConsumeSemicolonAfterLoaded : Boolean;
         lProgramParaSym : TProgramParaSym;
         lTextSym : TTypeSym;
         lProgramParams : TProgramParamArray;
         lIndex : LongInt;
         lFeature : TFeature;
         lLoadOK : Boolean;

      begin
         Result:=true;
         Status.IsLibrary:=AIsLibrary;
         Status.IsPackage:=false;
         Status.IsExe:=true;
         ParseOnly:=false;
         lConsumeSemicolonAfterLoaded:=false;

         { make the compiler happy and avoid an uninitialized variable warning on Setlength(sc,length(sc)+1); }
         lProgramParams:=nil;

         { DLL defaults to create reloc info }
         if AIsLibrary or (TargetInfo.system in [system_aarch64_win64]) then
           begin
             if not RelocSectionSetExplicitly then
               RelocSection:=true;
           end;

         { get correct output names }
         lMainFile := CurrentScanner.FInputFile;
         while Assigned(lMainFile.next) do
           lMainFile := lMainFile.next;

         AModule.SetFileName(lMainFile.path+lMainFile.name,true);

         if AIsLibrary then
           begin
             ProcLibraryHeader(AModule);
             lConsumeSemicolonAfterLoaded:=true;
           end
         else if CurrentScanner.FToken=_PROGRAM then
           { is there an program head ? }
           begin
             ProcProgramHeader(AModule,lProgramParams);
             lConsumeSemicolonAfterLoaded:=true;
           end
         else
           begin
             if (TargetInfo.system in systems_unit_program_exports) then
               exportlib.preparelib(AModule.RealModuleName^);

             { setup things using the switches }
             SetupGlobalSwitches;

           end;

         { load all packages, so we know whether a unit is contained inside a
           package or not }
         Load_Packages;

         { set implementation flag }
         AModule.InInterface:=false;
         AModule.InterfaceCompiled:=true;

         { insert after the unit symbol tables the static symbol table
           of the program                                              }
         AModule.LocalSymTable:=TStaticSymTable.Create(AModule.RealModuleName^,AModule.ModuleID);

         { load system unit }
         lLoadOK:=LoadSystemUnit(AModule);

         { consume the semicolon now that the system unit is loaded }
         if lConsumeSemicolonAfterLoaded then
           Consume(_SEMICOLON);

         { global switches are read, so further changes aren't allowed }
         AModule.InGlobal:=false;

         { system unit is loaded, now insert feature defines }
         for lFeature:=low(TFeature) to high(TFeature) do
           if lFeature in Features then
             Def_System_Macro('FPC_HAS_FEATURE_'+FeatureStr[lFeature]);

         { load standard units, e.g objpas,profile unit }
         lLoadOK:=LoadDefaultUnits(AModule) and lLoadOK;

         { Load units provided on the command line }
         lLoadOK:=LoadAutoUnits(AModule) and lLoadOK;

         { insert iso program parameters }
         if length(lProgramParams)>0 then
           begin
             lTextSym:=Search_System_Type('TEXT');
             if not(Assigned(lTextSym)) then
               InternalError(2013011201);
             for lIndex:=0 to high(lProgramParams) do
               begin
                 lProgramParaSym:=CProgramParaSym.Create(lProgramParams[lIndex].Name,lProgramParams[lIndex].Number);
                 AModule.LocalSymTable.InsertSym(lProgramParaSym,true);
               end;
           end;

         { Load the units used by the program we compile. }
         if CurrentScanner.FToken=_USES then
           begin
             // We can do this here: if there is no uses then the namespace directive makes no sense.
             if Assigned(AModule) then
               AModule.LoadLocalNamespaceList
             else
               CurrentNamespaceList:=Nil;
             ParseUsesClause(AModule);
             AModule.ConsumeSemicolonAfterUses:=true;
           end
         else begin
           AModule.ConsumeSemicolonAfterUses:=false;
           if TModule.CTask_Fast_Backtrack then
             lLoadOK:=false; { some used units are not fully compiled }
         end;

         { Also load compiler-injected dependencies when there is no uses clause. }
         lLoadOK:=LoadUnits(AModule,false) and lLoadOK;

         if AModule.IsInitial then
           lLoadOK:=false; { delay program, so ctask can finish all units }
         if not lLoadOK then
           AModule.state:=ms_compiling_wait;

         { Can we continue compiling ? }

         Result:=AModule.state<>ms_compiling_wait;
         if Result then
           Result:=ProcProgramDeclarations(AModule,AIsLibrary)
      end;

end.
