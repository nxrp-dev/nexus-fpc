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
unit fmodule;

{$i fpcdefs.inc}

interface

    uses
       CUtils,CClasses,CFileUtl,
       GlobType,FinPut,ogbase,FPkg,
       SymBase,SymSym,
       wpobase,
       aasmbase,AAsmData;


    const
      UNSPECIFIED_LIBRARY_NAME = '<none>';

    type
      TRecompileReason = (rr_unknown,
        rr_noppu,
        rr_sourcenewer,
        rr_build,
        rr_crcchanged,
        rr_buildcycle
      );

{$ifdef VER3_2}
      RTLString = AnsiString;
{$endif VER3_2}

      { unit options }
      TModuleOption = (mo_none,
        mo_hint_deprecated,
        mo_hint_platform,
        mo_hint_library,
        mo_hint_unimplemented,
        mo_hint_experimental,
        mo_has_deprecated_msg
      );
      TModuleOptions = set of TModuleOption;

      TLinkContainerItem=class(TLinkedListItem)
      public
         data : TPathStr;
         needlink : cardinal;
         constructor Create(const s:TPathStr;m:cardinal);
      end;

      TLinkContainer=class(TLinkedList)
         procedure add(const s : TPathStr;m:cardinal);
         function get(var m:cardinal) : TPathStr;
         function getusemask(mask:cardinal) : TPathStr;
         function find(const s:TPathStr):boolean;
      end;

      TModule = class;
      TUsedUnit = class;

      TUnitImportSym = class
        module: TModule;
        symid: LongInt;
        sym: TSymEntry;
      end;

      TUnitMapRec = record
        u        : TModule;
        { number of references }
        refs     : LongInt;
        { index in the derefmap }
        derefidx : LongInt;
      end;
      TUnitMapArray = array of TUnitMapRec;

      TDerefMapRec = record
        u           : TModule;
        { modulename, used during ppu load }
        ModuleName  : PShortString;
      end;
      TDerefMapArray = array of TDerefMapRec;

      TFinishModuleEvent = procedure(m: TModule) of object;
      TRenameModuleEvent = procedure(m: TModule; const oldname: TSymStr) of object;

      { tused_unit }

      TUsedUnit = class(TLinkedListItem)
        checksum,
        interface_checksum,
        indirect_checksum: cardinal;
        in_uses,
        in_interface    : boolean;
        u               : TModule;
        unitsym         : TUnitSym;
        dependent_added : boolean;
        constructor create(_u : TModule;intface,inuses:boolean;usym:TUnitSym);
        procedure check_hints;
      end;

      TDependentUnit = class(TLinkedListItem)
        u : TModule;
        in_interface : boolean;
        constructor create(_u : TModule; frominterface : boolean);
      end;

      { tmodule }

      TModule = class(TModuleBase)
      private
        FImportLibraryList : TFPHashObjectList;
      public
        loadedfrommodule: TModule;
        is_reset,                 { has reset been called ? }
        do_recompile,         { reset needed, done by ctask }
        do_reload,                { force reloading of the unit }
        FromPPU: boolean;         { loaded from ppu }
        ppu_discarded: boolean;         { ppu was recompiled }
        ppu_waitingfor_crc: boolean;
        SourcesAvail,            { if all sources are reachable }
        interface_compiled,       { if the interface section has been parsed/compiled/loaded, interface_crc and indirect_crc are valid }
        is_dbginfo_written,
        is_unit,
        in_interface,             { processing the interface part? }
        { allow global settings }
        in_global     : boolean;
        { Whether a mode switch is still allowed at this point in the parsing.}
        mode_switch_allowed,
        { generate pic helper which loads eip in ecx (for leave procedures) }
        requires_ecx_pic_helper,
        { generate pic helper which loads eip in ebx (for non leave procedures) }
        requires_ebx_pic_helper : boolean;
        interface_only: boolean; { interface-only macpas unit; flag does not need saving/restoring to ppu }
        mainfilepos   : TFilePosInfo;
        recompile_reason : TRecompileReason;  { the reason why the unit should be recompiled }
        crc_final: boolean;
        crc,                       { valid when crc_final=true }
        interface_crc,             { valid when interface_compiled=true }
        indirect_crc  : cardinal;  { valid when interface_compiled=true }
        headerflags   : cardinal;  { the PPU header flags }
        longversion   : cardinal;  { longer version than what fits in the ppu header }
        moduleflags   : TModuleFlags; { ppu flags that do not need to be known by just reading the ppu header }
        IsLibrary     : boolean;  { if it is a library (win32 dll) }
        IsPackage     : boolean;
        ChangeEndian : boolean;  { if the unit is loaded on a system with a different endianess than it was compiled on }
        unitmap       : TUnitMapArray; { mapping of all used units }
        unitmapsize   : LongInt;  { number of units in the map }
        derefmap      : TDerefMapArray; { mapping of all units needed for deref }
        derefmapcnt   : LongInt;  { number of units in the map }
        derefmapsize  : LongInt;  { number of units in the map }
        derefdataintflen : LongInt;
        derefdata     : TDynamicArray;
        checkforwarddefs,
        deflist,
        symlist       : TFPObjectList;
        forwardgenericdefs : TFPHashObjectList; { contains a list of specializations of a forward declared generic (the key) }
        ptrdefs       : THashSet; { list of pointerdefs created in this module so we can reuse them (not saved/restored) }
        arraydefs     : THashSet; { list of single-element-arraydefs created in this module so we can reuse them (not saved/restored) }
        procaddrdefs  : THashSet; { list of procvardefs created when getting the address of a procdef (not saved/restored) }

        ansistrdef    : tobject; { an ansistring def redefined for the current module }
        wpoinfo       : TUnitWPOInfoBase; { whole program optimization-related information that is generated during the current run for this unit }
        GlobalSymTable,           { pointer to the global symtable of this unit }
        localsymtable : TSymTable;{ pointer to the local symtable of this unit }
        GlobalMacroSymTable,           { pointer to the global macro symtable of this unit }
        localmacrosymtable : TSymTable;{ pointer to the local macro symtable of this unit }
        mainscanner   : TObject;  { scanner object used }
        Scanner       : TObject;  { scanner object used }
        ProcInfo      : TObject;  { current procedure being compiled }
        asmdata       : TObject;  { Assembler data }
        asmprefix     : PShortString;  { prefix for the smartlink asmfiles }
        publicasmsyms : TFPHashObjectList; { contains the assembler symbols which need to be exported from a package }
        externasmsyms : TFPHashObjectList; { contains the assembler symbols which are imported from another unit }
        unitimportsyms : TFPObjectList; { list of symbols (tunitimportsym) that are imported from other units }
        debuginfo     : TObject;
        _exports      : TLinkedList;
        dllscannerinputlist : TFPHashList;
        localnamespacelist,
        resourcefiles,
        linkorderedsymbols : TCmdStrList;
        linkunitofiles,
        linkunitstaticlibs,
        linkunitsharedlibs,
        linkotherofiles,           { objects,libs loaded from the source }
        linkothersharedlibs,       { using $L or $LINKLIB or import lib (for linux) }
        linkotherstaticlibs,
        linkotherframeworks  : TLinkContainer;
        mainname      : PShortString; { alternate name for "main" procedure }
        package       : TPackage;

        used_units           : TLinkedList; { list of tused_unit }
        dependent_units      : TLinkedList;

        { circular unit groups = strongly connected components }
        scc_finished: boolean; { scc is compiled = this module and all used modules even indirectly are ms_procesed
                                 Note that in a cycle ms_processed can be reached while scc_finished is still false }
        scc_root: TModule;     { valid if not scc_finished: all modules of a scc poins to their root module }
        scc_next: TModule;     { next module in same scc }
        scc_index: integer;    { dont use. used in ttask_handler.update_circular_unit_groups }
        scc_lowindex: integer; { valid if >0 and scc_finished=false.
                                 lowest scc_index reachable through used_units,
                                 all circular connected modules have the same lowindex }
        scc_onstack: boolean;  { dont use. used in ttask_handler.update_circular_unit_groups }
        class var
          ctask_fast_backtrack: boolean; { true if some cycle was detected and returning fast to ctask scheduler }
          cycle_stamp: dword;
        var
        cycle_search_stamp: dword;
        scc_tree_unfinished: boolean; { the scc or a sub scc has at least one module not ms_processed }
        other_scc_unfinished: boolean; { a sub scc has a module not ms_processed }
        scc_tree_crc_wait: TModule; { an unfinished used unit, can be indirectly used, not self }

        task: TObject;         { ctask ttask }

        localunitsearchpath,           { local searchpaths }
        localobjectsearchpath,
        localincludesearchpath,
        locallibrarysearchpath,
        localframeworksearchpath : TSearchPathList;

        moduleoptions: TModuleOptions;
        deprecatedmsg: PShortString;
        compilecount : integer;
        consume_semicolon_after_uses : Boolean;
        initfinalchecked : boolean;
        functypechecked : boolean;

        { contains a list of types that are extended by helper types; the key is
          the full name of the type and the data is a TFPObjectList of
          tobjectdef instances (the helper defs) }
        extendeddefs: TFPHashObjectList;
        { contains a list of the current topmost non-generic symbol for a
          typename of which at least one generic exists; the key is the
          non-generic typename and the data is a TFPObjectList of tgenericdummyentry
          instances whereby the last one is the current top most one }
        genericdummysyms: TFPHashObjectList;
        { contains a list of specializations for which the method bodies need
          to be generated }
        pendingspecializations : TFPHashObjectList;
        { list of attributes that are used and thus need their construction
          functions generated }
        used_rtti_attrs: TFPObjectList;

        { this contains a list of units (tmodule) that needs to be waited for until the
          unit can be finished (code generated, etc.); this is needed to handle
          specializations in circular unit usages correctly }
        waitingforunit: TFPObjectList;
        { this contains a list of all units (tmodule) that are waiting for this unit to be
          finished }
        waitingunits: TFPObjectList;

        finishstate: pointer;
        specializestate : pointer;

        namespace: PShortString; { for JVM target: corresponds to Java package name }

        { for targets that initialise typed constants via explicit assignments
          instead of by generating an initialised data section (holds typed
          constant assignments at the module level; does not have to be saved
          into the ppu file, because translated into code during compilation)
           -- actual type: tnode (but fmodule should not depend on node) }
        tcinitcode     : tobject;

        { the current extended rtti directive }
        rtti_directive : TRTTIDirective;

        {create creates a new module which name is stored in 's'. LoadedFrom
        points to the module calling it. It is nil for the first compiled
        module. This allow inheritance of all path lists. MUST pay attention
        to that when creating link.res!!!!(mazen)}
        constructor create(loadedfrom: TModule; const amodulename: string; const afilename:TPathStr;_is_unit:boolean);
        destructor Destroy;override;
        procedure reset(for_recompile: boolean);virtual;
        function StateStr: string; virtual;
        procedure checkstate; virtual;
        procedure loadlocalnamespacelist;
        procedure adddependency(callermodule:TModule; frominterface : boolean);
        procedure removedependency(callermodule:TModule);
        function hasdependency(callermodule:TModule): boolean;
        procedure flagdependent;
        function find_used_unit_compiling: TModule; // find a used module compiling/loading, even indirect
        class procedure increase_cycle_stamp;
        procedure disconnect_depending_modules; virtual;
        function is_reload_needed(du: TDependentUnit): boolean; virtual; // true if reload needed after self changed
        class var finish_module: TFinishModuleEvent;
        procedure addimportedsym(sym:TSymEntry; check_if_exists: boolean = true);
        procedure derefimportedsymbols;
        function  addusedunit(hp:TModule;inuses:boolean;usym:TUnitSym):TUsedUnit;
        function  usesmodule_in_interface(m : TModule) : boolean;
        function findusedunit(m : TModule) : TUsedUnit;
        function usedunitsloaded(interface_units: boolean; out firstwaiting : TModule): boolean;
        function nowaitingforunits(out firstwaiting : TModule) : Boolean;
        function usedunitsfinalcrc(out firstwaiting : TModule): boolean;
        procedure updatemaps;
        function  derefidx_unit(id:LongInt):LongInt;
        function  resolve_unit(id:LongInt):TModule;
        procedure allunitsused;
        procedure end_of_parsing;virtual;
        procedure setmodulename(const s:string);
        procedure AddExternalImport(const libname,symname,symmangledname:string;OrdNr: LongInt;isvar:boolean;ImportByOrdinalOnly:boolean);
        procedure add_public_asmsym(sym:TAsmSymbol);
        procedure add_public_asmsym(const name:TSymStr;bind:TAsmsymbind;typ:TAsmsymtype);
        procedure add_extern_asmsym(sym:TAsmSymbol);
        procedure add_extern_asmsym(const name:TSymStr;bind:TAsmsymbind;typ:TAsmsymtype);
        procedure remove_waitforunit_cycles;
        procedure remove_all_waitsforthisunit;
        procedure remove_from_waitingforunits(amodule : TModule);
        property ImportLibraryList : TFPHashObjectList read FImportLibraryList;
        function ToString: RTLString; override;
        procedure WriteUsedUnits(m: TModule);
      end;

    var
       main_module       : TModule;     { Main module of the program }
       CurrentModule    : TModule;     { Current module which is compiled or loaded }
       UsedUnits         : TLinkedList; { Used units for this program }
       loaded_units      : TLinkedList; { All loaded units, excluding main_module }
       unloaded_units    : TLinkedList; { Units removed from loaded_units, to be freed }
       all_modules: array of TModule;   { modules by moduleid }
       SmartLinkOFiles   : TCmdStrList; { List of .o files which are generated,
                                          used to delete them after linking }


    procedure SetCurrentModule(p:TModule);
    function Get_Module(moduleindex : LongInt) : TModule;
    function get_source_file(moduleindex,fileindex : LongInt) : TInputFile;
    procedure addloadedunit(hp:TModule);
    function find_module_from_symtable(st:TSymTable):TModule;


implementation

    uses
      SysUtils,Globals,
      Verbose,Systems,
      Scanner,DbgBase,
      ProcInfo,symdef,symtype;

{$ifdef MEMDEBUG}
    var
      memsymtable : TMemDebug;
{$endif}

{*****************************************************************************
                             Global Functions
*****************************************************************************}

    function find_module_from_symtable(st:TSymTable):TModule;
      begin
        result:=Get_Module(st.ModuleID);
      end;

    procedure SetCurrentModule(p:TModule);

      begin
        { save the state of the scanner }
        if Assigned(CurrentScanner) then
          CurrentScanner.tempcloseinputfile;
        { set new module }
        CurrentModule:=p;
        { restore previous module settings }
        Fillchar(CurrentFilePos,sizeof(CurrentFilePos),0);
        if Assigned(CurrentModule) then
          begin
            CurrentAsmData:=TAsmData(CurrentModule.asmdata);
            CurrentDebugInfo:=TDebugInfo(CurrentModule.debuginfo);
            { restore scanner and file positions }
            Set_Current_Scanner(TScannerFile(CurrentModule.Scanner));
            if Assigned(CurrentScanner) then
              begin
                CurrentScanner.tempopeninputfile;
                CurrentScanner.gettokenpos;
                Parser_Current_File:=CurrentScanner.inputfile.name;
              end
            else
              begin
                CurrentFilePos.moduleindex:=CurrentModule.ModuleID;
                Parser_Current_File:='';
              end;
          end
        else
          begin
            CurrentAsmData:=nil;
            Set_Current_Scanner(nil);
            CurrentDebugInfo:=nil;
          end;
      end;


    function Get_Module(moduleindex : LongInt) : TModule;
      begin
        if moduleindex>=length(all_modules) then
          result:=nil
        else
          result:=all_modules[moduleindex];
      end;


    function get_source_file(moduleindex,fileindex : LongInt) : TInputFile;
      var
        hp : TModule;
      begin
        hp:=Get_Module(moduleindex);
        if Assigned(hp) then
          get_source_file:=hp.SourceFiles.Get_File(fileindex)
        else
          get_source_file:=nil;
      end;


    procedure addloadedunit(hp:TModule);
      begin
        loaded_units.concat(hp);
      end;


{****************************************************************************
                             TLinkContainerItem
 ****************************************************************************}

    constructor TLinkContainerItem.Create(const s:TPathStr;m:cardinal);
      begin
        inherited Create;
        data:=s;
        needlink:=m;
      end;


{****************************************************************************
                           TLinkContainer
 ****************************************************************************}

    procedure TLinkContainer.add(const s : TPathStr;m:cardinal);
      begin
        inherited concat(TLinkContainerItem.Create(s,m));
      end;


    function TLinkContainer.get(var m:cardinal) : TPathStr;
      var
        p : TLinkContainerItem;
      begin
        p:=TLinkContainerItem(inherited GetFirst);
        if p=nil then
         begin
           get:='';
           m:=0;
         end
        else
         begin
           get:=p.data;
           m:=p.needlink;
           p.free;
           p := nil;
         end;
      end;


    function TLinkContainer.getusemask(mask:cardinal) : TPathStr;
      var
         p : TLinkContainerItem;
         found : boolean;
      begin
        found:=false;
        repeat
          p:=TLinkContainerItem(inherited GetFirst);
          if p=nil then
           begin
             getusemask:='';
             exit;
           end;
          getusemask:=p.data;
          found:=(p.needlink and mask)<>0;
          p.free;
          p := nil;
        until found;
      end;


    function TLinkContainer.find(const s:TPathStr):boolean;
      var
        newnode : TLinkContainerItem;
      begin
        find:=false;
        newnode:=TLinkContainerItem(First);
        while Assigned(newnode) do
         begin
           if newnode.data=s then
            begin
              find:=true;
              exit;
            end;
           newnode:=TLinkContainerItem(newnode.next);
         end;
      end;


{****************************************************************************
                              TUSED_UNIT
 ****************************************************************************}

    constructor TUsedUnit.create(_u : TModule;intface,inuses:boolean;usym:TUnitSym);
      begin
        u:=_u;
        in_interface:=intface;
        in_uses:=inuses;
        unitsym:=usym;
        if _u.state in [ms_load,ms_compiled_waitcrc,ms_compiled,ms_processed] then
          checksum:=u.crc
        else
          checksum:=0;
        if _u.interface_compiled then
         begin
           interface_checksum:=u.interface_crc;
           indirect_checksum:=u.indirect_crc;
         end
        else
         begin
           interface_checksum:=0;
           indirect_checksum:=0;
         end;
      end;


    procedure TUsedUnit.check_hints;
      var
        uname: PShortString;
      begin
        uname:=u.RealModuleName;
        if mo_hint_deprecated in u.moduleoptions then
          if (mo_has_deprecated_msg in u.moduleoptions) and (u.deprecatedmsg <> nil) then
            MessagePos2(unitsym.fileinfo,sym_w_deprecated_unit_with_msg,uname^,u.deprecatedmsg^)
          else
            MessagePos1(unitsym.fileinfo,sym_w_deprecated_unit,uname^);
        if mo_hint_experimental in u.moduleoptions then
          MessagePos1(unitsym.fileinfo,sym_w_experimental_unit,uname^);
        if mo_hint_platform in u.moduleoptions then
          MessagePos1(unitsym.fileinfo,sym_w_non_portable_unit,uname^);
        if mo_hint_library in u.moduleoptions then
          MessagePos1(unitsym.fileinfo,sym_w_library_unit,uname^);
        if mo_hint_unimplemented in u.moduleoptions then
          MessagePos1(unitsym.fileinfo,sym_w_non_implemented_unit,uname^);
      end;


{****************************************************************************
                            TDENPENDENT_UNIT
 ****************************************************************************}

    constructor TDependentUnit.create(_u: TModule; frominterface: boolean);
      begin
         u:=_u;
         in_interface:=frominterface;
      end;


{****************************************************************************
                                  TMODULE
 ****************************************************************************}

    constructor TModule.create(loadedfrom: TModule; const amodulename: string; const afilename:TPathStr;_is_unit:boolean);
      var
        n:string;
        fn:TPathStr;
        old_mod_cnt, i: SizeInt;
        new_mod_cnt: Integer;
      begin
        loadedfrommodule:=LoadedFrom;
        if amodulename='' then
          n:=ChangeFileExt(ExtractFileName(afilename),'')
        else
          n:=amodulename;
        if afilename='' then
          fn:=amodulename
        else
          fn:=afilename;
        { Programs have the name 'Program' to don't conflict with dup id's }
        if _is_unit then
         inherited create(amodulename)
        else
         inherited create('Program');
        MainSource:=fn;

        old_mod_cnt:=length(all_modules);
        if ModuleID>=old_mod_cnt then
          begin
            if old_mod_cnt<32 then
              new_mod_cnt:=32
            else
              new_mod_cnt:=old_mod_cnt*2;
            SetLength(all_modules,new_mod_cnt);
            for i:=old_mod_cnt to new_mod_cnt-1 do
              all_modules[i]:=nil;
          end;
        all_modules[ModuleID]:=self;

        asmprefix:=StringDup(FixFileName(n));
        setfilename(fn,true);
        localunitsearchpath:=TSearchPathList.Create;
        localobjectsearchpath:=TSearchPathList.Create;
        localincludesearchpath:=TSearchPathList.Create;
        locallibrarysearchpath:=TSearchPathList.Create;
        localframeworksearchpath:=TSearchPathList.Create;
        used_units:=TLinkedList.Create;
        dependent_units:=TLinkedList.Create;
        localnamespacelist:=TCmdStrList.Create;
        resourcefiles:=TCmdStrList.Create;
        linkorderedsymbols:=TCmdStrList.Create;
        linkunitofiles:=TLinkContainer.Create;
        linkunitstaticlibs:=TLinkContainer.Create;
        linkunitsharedlibs:=TLinkContainer.Create;
        linkotherofiles:=TLinkContainer.Create;
        linkotherstaticlibs:=TLinkContainer.Create;
        linkothersharedlibs:=TLinkContainer.Create;
        linkotherframeworks:=TLinkContainer.Create;
        mainname:=nil;
        FImportLibraryList:=TFPHashObjectList.Create(true);
        crc_final:=false;
        crc:=0;
        interface_crc:=0;
        indirect_crc:=0;
        headerflags:=0;
        longversion:=0;
        moduleflags:=[];
        Scanner:=nil;
        unitmap:=nil;
        unitmapsize:=0;
        derefmap:=nil;
        derefmapsize:=0;
        derefmapcnt:=0;
        derefdata:=TDynamicArray.Create(1024);
        derefdataintflen:=0;
        deflist:=TFPObjectList.Create(false);
        symlist:=TFPObjectList.Create(false);
        ptrdefs:=THashSet.Create(64,true,false);
        arraydefs:=THashSet.Create(64,true,false);
        procaddrdefs:=THashSet.Create(64,true,false);

        ansistrdef:=nil;
        wpoinfo:=nil;
        checkforwarddefs:=TFPObjectList.Create(false);
        forwardgenericdefs:=TFPHashObjectList.Create(true);
        extendeddefs:=TFPHashObjectList.Create(true);
        genericdummysyms:=TFPHashObjectList.create(true);
        pendingspecializations:=TFPHashObjectList.create(false);
        waitingforunit:=TFPObjectList.create(false);
        waitingunits:=TFPObjectList.create(false);
        used_rtti_attrs:=TFPObjectList.create(false);
        GlobalSymTable:=nil;
        localsymtable:=nil;
        GlobalMacroSymTable:=nil;
        localmacrosymtable:=nil;
        do_reload:=false;
        SourcesAvail:=true;
        mainfilepos.line:=0;
        mainfilepos.column:=0;
        mainfilepos.fileindex:=0;
        recompile_reason:=rr_unknown;
        in_interface:=true;
        in_global:=true;
        is_unit:=_is_unit;
        IsLibrary:=false;
        IsPackage:=false;
        ChangeEndian:=false;
        is_dbginfo_written:=false;
        mode_switch_allowed:= true;
        moduleoptions:=[];
        deprecatedmsg:=nil;
        namespace:=nil;
        tcinitcode:=nil;
        _exports:=TLinkedList.Create;
        dllscannerinputlist:=TFPHashList.Create;
        asmdata:=casmdata.create(ModuleName);
        unitimportsyms:=TFPObjectList.Create(true);
        publicasmsyms:=TFPHashObjectList.Create(true);
        externasmsyms:=TFPHashObjectList.Create(true);
        InitDebugInfo(self,false);
      end;


    destructor TModule.Destroy;
      var
        i : LongInt;
        current_debuginfo_reset : boolean;
      begin
        unitmap:=nil;
        if Assigned(derefmap) then
          begin
            for i:=0 to derefmapcnt-1 do
              StringDispose(derefmap[i].ModuleName);
          end;
        derefmap:=nil;
        if Assigned(_exports) then
          freeandnil(_exports);
        if Assigned(dllscannerinputlist) then
          freeandnil(dllscannerinputlist);
        if Assigned(localnamespacelist) then
          freeandnil(localnamespacelist);
        if Assigned(Scanner) then
          begin
            { also update current_scanner if it was pointing
              to this module }
            if CurrentScanner=TScannerFile(Scanner) then
              Set_Current_Scanner(nil);
            freeandnil(Scanner);
          end;
        if Assigned(asmdata) then
          begin
            if CurrentAsmData=asmdata then
              CurrentAsmData:=nil;
             asmdata.free;
             asmdata := nil;
          end;
        if Assigned(ProcInfo) then
          begin
            if CurrentProcInfo=TProcInfo(ProcInfo) then
              begin
                CurrentProcInfo:=nil;
                CurrentStructDef:=nil;
                CurrentGenericDef:=nil;
                CurrentSpecializeDef:=nil;
              end;
            { release procinfo tree }
            TProcInfo(ProcInfo).destroy_tree;
            ProcInfo := nil;
          end;
        DoneDebugInfo(self,current_debuginfo_reset);
        used_units.free;
        used_units := nil;
        dependent_units.free;
        dependent_units := nil;
        resourcefiles.Free;
        resourcefiles := nil;
        linkorderedsymbols.Free;
        linkorderedsymbols := nil;
        linkunitofiles.Free;
        linkunitofiles := nil;
        linkunitstaticlibs.Free;
        linkunitstaticlibs := nil;
        linkunitsharedlibs.Free;
        linkunitsharedlibs := nil;
        linkotherofiles.Free;
        linkotherofiles := nil;
        linkotherstaticlibs.Free;
        linkotherstaticlibs := nil;
        linkothersharedlibs.Free;
        linkothersharedlibs := nil;
        linkotherframeworks.Free;
        linkotherframeworks := nil;
        StringDispose(mainname);
        externasmsyms.Free;
        externasmsyms := nil;
        publicasmsyms.Free;
        publicasmsyms := nil;
        unitimportsyms.Free;
        unitimportsyms := nil;
        FImportLibraryList.Free;
        FImportLibraryList := nil;
        extendeddefs.Free;
        extendeddefs := nil;
        genericdummysyms.free;
        genericdummysyms := nil;
        pendingspecializations.free;
        pendingspecializations := nil;
        waitingforunit.free;
        waitingforunit := nil;
        waitingunits.free;
        waitingunits := nil;
        used_rtti_attrs.free;
        used_rtti_attrs := nil;
        StringDispose(asmprefix);
        StringDispose(deprecatedmsg);
        StringDispose(namespace);
        tcinitcode.free;
        tcinitcode := nil;
        localunitsearchpath.Free;
        localunitsearchpath := nil;
        localobjectsearchpath.free;
        localobjectsearchpath := nil;
        localincludesearchpath.free;
        localincludesearchpath := nil;
        locallibrarysearchpath.free;
        locallibrarysearchpath := nil;
        localframeworksearchpath.free;
        localframeworksearchpath := nil;
{$ifdef MEMDEBUG}
        memsymtable.start;
{$endif}
        derefdata.free;
        derefdata := nil;
        if Assigned(deflist) then
          begin
            for i:=0 to deflist.Count-1 do
              if Assigned(deflist[i]) and
                 (TDef(deflist[i]).registered_in_module=self) then
                TDef(deflist[i]).registered_in_module:=nil;
            deflist.free;
            deflist := nil;
          end;
        symlist.free;
        symlist := nil;
        ptrdefs.free;
        ptrdefs := nil;
        arraydefs.free;
        arraydefs := nil;
        procaddrdefs.free;
        procaddrdefs := nil;

        ansistrdef:=nil;
        wpoinfo.free;
        wpoinfo := nil;
        checkforwarddefs.free;
        checkforwarddefs := nil;
        forwardgenericdefs.free;
        forwardgenericdefs := nil;
        GlobalSymTable.free;
        GlobalSymTable := nil;
        localsymtable.free;
        localsymtable := nil;
        GlobalMacroSymTable.free;
        GlobalMacroSymTable := nil;
        localmacrosymtable.free;
        localmacrosymtable := nil;

        task:=nil;
        all_modules[ModuleID]:=nil;
{$ifdef MEMDEBUG}
        memsymtable.stop;
{$endif}
        inherited Destroy;
      end;


    procedure TModule.reset(for_recompile: boolean);
      var
        i   : LongInt;
        current_debuginfo_reset : boolean;
        m : TModule;
      begin
        is_reset:=true;
        do_recompile:=false;
        FromPPU:=false;
        if Assigned(Scanner) then
          begin
            { also update current_scanner if it was pointing
              to this module }
            if CurrentScanner=TScannerFile(Scanner) then
              Set_Current_Scanner(nil);
            freeandnil(Scanner);
          end;
        if Assigned(ProcInfo) then
          begin
            if CurrentProcInfo=TProcInfo(ProcInfo) then
              begin
                CurrentProcInfo:=nil;
                CurrentStructDef:=nil;
                CurrentGenericDef:=nil;
                CurrentSpecializeDef:=nil;
              end;
            { release procinfo tree }
            TProcInfo(ProcInfo).destroy_tree;
          end;
        if Assigned(asmdata) then
          begin
            if CurrentAsmData=asmdata then
              CurrentAsmData:=nil;
            asmdata.free;
            asmdata:=nil;
          end;
        DoneDebugInfo(self,current_debuginfo_reset);
        GlobalSymTable.free;
        GlobalSymTable:=nil;
        localsymtable.free;
        localsymtable:=nil;
        GlobalMacroSymTable.free;
        GlobalMacroSymTable:=nil;
        localmacrosymtable.free;
        localmacrosymtable:=nil;
        deflist.free;
        deflist:=TFPObjectList.Create(false);
        symlist.free;
        symlist:=TFPObjectList.Create(false);
        ptrdefs.free;
        ptrdefs:=THashSet.Create(64,true,false);
        arraydefs.free;
        arraydefs:=THashSet.Create(64,true,false);
        procaddrdefs.free;
        procaddrdefs:=THashSet.Create(64,true,false);

        ansistrdef:=nil;
        wpoinfo.free;
        wpoinfo:=nil;
        checkforwarddefs.free;
        checkforwarddefs:=TFPObjectList.Create(false);
        forwardgenericdefs.free;
        forwardgenericdefs:=TFPHashObjectList.Create(true);
        publicasmsyms.free;
        publicasmsyms:=TFPHashObjectList.Create(true);
        externasmsyms.free;
        externasmsyms:=TFPHashObjectList.Create(true);
        unitimportsyms.free;
        unitimportsyms:=TFPObjectList.Create(true);
        derefdata.free;
        derefdata:=TDynamicArray.Create(1024);
        unitmap:=nil;
        if Assigned(derefmap) then
          begin
            for i:=0 to derefmapcnt-1 do
              StringDispose(derefmap[i].ModuleName);
          end;
        derefmap:=nil;
        unitmapsize:=0;
        derefmapsize:=0;
        derefmapcnt:=0;
        derefdataintflen:=0;
        SourceFiles.free;
        SourceFiles:=TInputFileManager.create;
        asmdata:=casmdata.create(ModuleName);
        if CurrentModule=self then
          CurrentAsmData:=TAsmData(asmdata);
        InitDebugInfo(self,current_debuginfo_reset);
        _exports.free;
        _exports:=TLinkedList.create;
        dllscannerinputlist.free;
        dllscannerinputlist:=TFPHashList.create;
        { During reload, the list of used units cannot change.
          It can only change while recompiling.
          Because the used_units is used in loops in the load cycle(s) which
          can recurse into the same unit due to circular dependencies,
          we do not destroy the list, we only update the contents.
          As a result the loop variable does not get reset during the loop.
          For recompile, we recreate the list }
        if for_recompile then
          begin
          used_units.free;
          used_units:=TLinkedList.Create;
          end;
        // keep dependent_units
        resourcefiles.Free;
        resourcefiles:=TCmdStrList.Create;
        linkorderedsymbols.Free;
        linkorderedsymbols:=TCmdStrList.Create;
        pendingspecializations.free;
        pendingspecializations:=TFPHashObjectList.create(false);
        genericdummysyms.Free;
        genericdummysyms := TFPHashObjectList.create(true);
        extendeddefs.Free;
        extendeddefs:=TFPHashObjectList.Create(true);
        if Assigned(waitingforunit) and
          (waitingforunit.count<>0) then
           begin
           Write(Self.ModuleName^, ' is reset while still waiting for units: ');
           for I:=0 to waitingforunit.Count-1 do
             begin
             M:=TModule(waitingforunit.Items[i]);
             write(m.ModuleName^,' (state:',M.state,') ');
             end;
           WriteLn;
           InternalError(2016070501);
           end;
        waitingforunit.free;
        waitingforunit:=TFPObjectList.create(false);
        linkunitofiles.Free;
        linkunitofiles:=TLinkContainer.Create;
        linkunitstaticlibs.Free;
        linkunitstaticlibs:=TLinkContainer.Create;
        linkunitsharedlibs.Free;
        linkunitsharedlibs:=TLinkContainer.Create;
        linkotherofiles.Free;
        linkotherofiles:=TLinkContainer.Create;
        linkotherstaticlibs.Free;
        linkotherstaticlibs:=TLinkContainer.Create;
        linkothersharedlibs.Free;
        linkothersharedlibs:=TLinkContainer.Create;
        linkotherframeworks.Free;
        linkotherframeworks:=TLinkContainer.Create;
        StringDispose(mainname);
        FImportLibraryList.Free;
        FImportLibraryList:=TFPHashObjectList.Create;
        do_reload:=false;
        interface_compiled:=false;
        in_interface:=true;
        in_global:=true;
        mode_switch_allowed:=true;
        StringDispose(deprecatedmsg);
        StringDispose(namespace);
        tcinitcode.free;
        tcinitcode:=nil;
        localunitsearchpath.Free;
        localunitsearchpath:=TSearchPathList.Create;
        localobjectsearchpath.free;
        localobjectsearchpath:=TSearchPathList.Create;
        localincludesearchpath.free;
        localincludesearchpath:=TSearchPathList.Create;
        locallibrarysearchpath.free;
        locallibrarysearchpath:=TSearchPathList.Create;
        localframeworksearchpath.free;
        localframeworksearchpath:=TSearchPathList.Create;
        moduleoptions:=[];
        is_dbginfo_written:=false;
        crc_final:=false;
        crc:=0;
        interface_crc:=0;
        indirect_crc:=0;
        headerflags:=0;
        longversion:=0;
        moduleflags:=[];
        mainfilepos.line:=0;
        mainfilepos.column:=0;
        mainfilepos.fileindex:=0;
        recompile_reason:=rr_unknown;
        {
          The following fields should not
          be reset:
           mainsource
           state
           loaded_from
           ppu_discarded
           sources_avail
           compilecount
        }
      end;

    procedure TModule.loadlocalnamespacelist;

      var
        nsitem : TCmdStrListItem;

      begin
        // Copying local namespace list
        if PreModule_NamespaceList.Count>0 then
          begin
          nsitem:=TCmdStrListItem(PreModule_NamespaceList.First);
          while Assigned(nsItem) do
            begin
            localnamespacelist.Concat(nsitem.Str);
            nsItem:=TCmdStrListItem(nsitem.Next);
            end;
          PreModule_NamespaceList.Clear;
          end;
        CurrentNamespaceList:=localnamespacelist;
      end;


    procedure TModule.adddependency(callermodule: TModule; frominterface: boolean);
      begin
        if hasdependency(callermodule) then exit;
        if is_unit then
          Message2(unit_u_add_depend_to,callermodule.ModuleName^,ModuleName^);

        { dependent_units is needed by the invalid cycle test,
          using the program is an invalid cycle as well }
        dependent_units.concat(TDependentUnit.create(callermodule,frominterface));

        if callermodule.scc_finished then
          InternalError(2026022202);
      end;

    procedure TModule.removedependency(callermodule: TModule);
      var
        du, nextdu: TDependentUnit;
      begin
        du:=TDependentUnit(dependent_units.First);
        while Assigned(du) do
        begin
          nextdu:=TDependentUnit(du.Next);
          if du.u=callermodule then
            dependent_units.Remove(du);
          du:=nextdu;
        end;
      end;

    function TModule.hasdependency(callermodule: TModule): boolean;
      var
        du: TDependentUnit;
      begin
        du:=TDependentUnit(dependent_units.First);
        while Assigned(du) do
        begin
          if du.u=callermodule then
            exit(true);
          du:=TDependentUnit(du.Next);
        end;
        Result:=false;
      end;

    procedure TModule.flagdependent;
      var
        dm : TDependentUnit;
        m , bm: TModule;

      begin
        { flag all units that depend on this unit for reloading }
        if not interface_compiled then exit;

        dm:=TDependentUnit(dependent_units.first);
        while Assigned(dm) do
        begin
          m:=dm.u;
          if m.state in [ms_compiled,ms_processed] then
          begin
            { Inconsistency: ms_compiled must only be set when all depending units (even indirect)
                are complete aka wait for crc or higher }
            WriteLn('tmodule.flagdependent ',ModuleName^,' state=',StateStr,', is used by ',BoolToStr(dm.in_interface,'interface','implementation'),' of ',m.ModuleName^,' ',m.StateStr);
            bm:=find_used_unit_compiling;
            if bm<>nil then
              WriteLn('tmodule.flagdependent ',ModuleName^,' is using (indirectly) ',bm.ModuleName^,' ',bm.StateStr)
            else
              WriteLn('tmodule.flagdependent ',ModuleName^,' is not using any incomplete unit.');
            bm:=m.find_used_unit_compiling;
            if bm<>nil then
              WriteLn('tmodule.flagdependent ',m.ModuleName^,' is using (indirectly) ',bm.ModuleName^,' ',bm.StateStr)
            else
              WriteLn('tmodule.flagdependent ',m.ModuleName^,' is not using any incomplete unit.');

            WriteUsedUnits(self);
            WriteUsedUnits(m);

            InternalError(2026022510);
          end;
          if not m.do_reload and is_reload_needed(dm) then
          begin
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tmodule.flagdependent ',ModuleName^,' state=',StateStr,', is used by ',BoolToStr(dm.in_interface,'interface','implementation'),' of ',m.ModuleName^,' ',m.StateStr);
            {$ENDIF}
            m.do_reload:=true;
            Message1(unit_u_flag_for_reload,m.ModuleName^);
            { We have to flag the units that depend on this unit even
              though it didn't change, because they might also
              indirectly depend on the unit that did change (e.g.,
              in case rgobj, rgx86 and rgcpu have been compiled
              already, and then rgobj is recompiled for some reason
              -> rgx86 is re-reresolved, but the vmtentries of trgcpu
              must also be re-resolved, because they will also contain
              pointers to procdefs in the old trgobj (in case of a
              recompile, all old defs are freed) }
            m.flagdependent;
          end;
          dm:=TDependentUnit(dm.next);
        end;
      end;

    function TModule.find_used_unit_compiling: TModule;

        function find_compiling(m: TModule): TModule;
        var
          uu: TUsedUnit;
        begin
          Result:=nil;
          if m.cycle_search_stamp=TModule.cycle_stamp then
            exit; // already visited
          m.cycle_search_stamp:=TModule.cycle_stamp;

          if m<>self then
            if m.do_reload then
              exit(m)
            else
              case m.state of
                ms_load:
                  if m.ppu_waitingfor_crc then
                    // check used units
                  else
                    exit(m);
                ms_compiled_waitcrc:
                  ; // check used units
                ms_compiled, ms_processed:
                  exit;
              else
                exit(m);
              end;

          uu:=TUsedUnit(m.used_units.first);
          while uu<>nil do
            begin
              Result:=find_compiling(uu.u);
              if Result<>nil then exit;
              uu:=TUsedUnit(uu.Next);
            end;
        end;

      begin
        increase_cycle_stamp;
        Result:=find_compiling(self);
      end;

    class procedure TModule.increase_cycle_stamp;
      begin
        if cycle_stamp=high(integer) then
          InternalError(2026022203);
        inc(cycle_stamp);
      end;

    function TModule.StateStr: string;
      begin
        str(state,Result);
        if do_recompile then
          Result:='do_recompile,'+Result;
        if do_reload then
          Result:='do_reload,'+Result;
      end;

    procedure TModule.checkstate;
      begin
        // Note: ms_load is checked in tppumodule.checkstate

        if interface_compiled then
        begin
          if state in [ms_registered,ms_compile,ms_compiling_wait,ms_compiling_waitintf] then
          begin
            WriteLn('tmodule.checkstate ',ModuleName^,' ',StateStr,' interface_compiled=true');
            InternalError(2026021912);
          end;
        end else begin
          if state in [ms_compiling_waitimpl,ms_compiling_waitfinish,ms_compiled_waitcrc,ms_compiled,ms_processed] then
          begin
            WriteLn('tmodule.checkstate ',ModuleName^,' ',StateStr,' interface_compiled=false');
            InternalError(2026021911);
          end;
        end;

        if crc_final then
        begin
          if state in [ms_registered,ms_compile,ms_compiling_wait,ms_compiling_waitintf,
            ms_compiling_waitimpl,ms_compiling_waitfinish] then
          begin
            WriteLn('tmodule.checkstate ',ModuleName^,' ',StateStr,' crc_final=true');
            InternalError(2026021910);
          end;
        end else begin
          if state in [ms_compiled_waitcrc,ms_compiled,ms_processed] then
          begin
            WriteLn('tmodule.checkstate ',ModuleName^,' ',StateStr,' crc_final=false');
            InternalError(2026021909);
          end;
        end;
      end;

    procedure TModule.disconnect_depending_modules;
      var
        uu: TUsedUnit;
      begin
        uu:=TUsedUnit(used_units.first);
        while Assigned(uu) do
          begin
            uu.u.removedependency(self);
            uu.dependent_added:=false;
            uu:=TUsedUnit(uu.next);
          end;
      end;

    function TModule.is_reload_needed(du: TDependentUnit): boolean;
      { du.u is a module using this unit }
      begin
        Result:=(du.u.state in [ms_compiling_waitfinish,ms_compiled_waitcrc,ms_compiled,ms_processed])
             or (du.in_interface and du.u.interface_compiled);
        { Note: see also the override in fppu.tppumodule }
      end;

    procedure TModule.addimportedsym(sym: TSymEntry; check_if_exists: boolean);
      var
        importsym: TUnitImportSym;
        module: TModule;
        asymtable: TSymTable;
        i: Integer;
      begin
        if check_if_exists then
        begin
          for i:=0 to unitimportsyms.Count-1 do
            if TUnitImportSym(unitimportsyms[i]).sym=sym then
              exit;
        end;

        asymtable:=sym.owner;
        module:=Get_Module(asymtable.ModuleID);
        if module=nil then
        begin
          WriteLn('tmodule.find_unitimportsymbol missing moduleid=',asymtable.ModuleID);
          InternalError(2026022622);
        end;

        if (sym.SymId>=module.symlist.Count) then
          InternalError(2026022617);
        if sym<>TSymEntry(module.symlist[sym.SymId]) then
        begin
          WriteLn('tmodule.addimportedsym ',ModuleName^,' ',StateStr,' ',Sym.RealName,' ',Sym.SymId,' MISMATCH');
          InternalError(2026022611);
        end;

        importsym:=TUnitImportSym.Create;
        importsym.sym:=sym;
        importsym.module:=module;
        importsym.symid:=sym.SymId;
        unitimportsyms.Add(importsym);
      end;

    procedure TModule.derefimportedsymbols;
      var
        i: Integer;
        importsym: TUnitImportSym;
        module: TModule;
      begin
        for i:=0 to unitimportsyms.Count-1 do
          begin
            importsym:=TUnitImportSym(unitimportsyms[i]);
            module:=importsym.module;
            if (importsym.SymId>=module.symlist.Count) then
              InternalError(2026022618);
            importsym.sym:=TSymEntry(module.symlist[importsym.symid]);
          end;
      end;

    function TModule.addusedunit(hp:TModule;inuses:boolean;usym:TUnitSym):TUsedUnit;
      var
        pu : TUsedUnit;
      begin
        pu:=TUsedUnit.create(hp,in_interface,inuses,usym);
        used_units.concat(pu);
        addusedunit:=pu;
      end;

    function TModule.usedunitsloaded(interface_units : boolean; out firstwaiting : TModule): boolean;
      var
        uu: TUsedUnit;
        ok: Boolean;
      begin
        Result:=true;
        firstwaiting:=nil;
        uu:=TUsedUnit(used_units.First);
        while Assigned(uu) do
        begin
          if uu.in_interface=interface_units then
          begin
            ok:=uu.u.interface_compiled and not uu.u.do_reload;
            {$IFDEF DEBUG_CTASK_VERBOSE}
            WriteLn('  ',ToString,' checking state of ', uu.u.ToString,' : ',uu.u.StateStr,' : ',ok);
            uu.u.checkstate;
            {$ENDIF}
            if not ok then
            begin
              Result:=false;
              firstwaiting:=uu.u;
              {$IFNDEF DEBUG_CTASK_VERBOSE}
              break;
              {$ENDIF}
            end;
          end;
          uu:=TUsedUnit(uu.Next);
        end;
      end;

    function TModule.nowaitingforunits(out firstwaiting : TModule): Boolean;

      begin
        firstwaiting:=nil;
        Result:=waitingforunit.count=0;
        If not Result then
          firstwaiting:=TModule(waitingforunit[0]);
      end;

    function TModule.usedunitsfinalcrc(out firstwaiting: TModule): boolean;
      { return a used unit, that has not yet computed its crc }

      begin
        firstwaiting:=scc_tree_crc_wait;
        Result:=firstwaiting=nil;
      end;

    function TModule.usesmodule_in_interface(m: TModule): boolean;

      var
        u : TUsedUnit;

      begin
        result:=False;
        u:=TUsedUnit(used_units.First);
        while Assigned(u) do
          begin
          if (u.u=m) then
            exit(u.in_interface) ;
          u:=TUsedUnit(u.next);
          end;
      end;

    function TModule.findusedunit(m: TModule): TUsedUnit;
      var
        u : TUsedUnit;

      begin
        result:=nil;
        u:=TUsedUnit(used_units.First);
        while Assigned(u) do
          begin
          if u.u=m then
            exit(u);
          u:=TUsedUnit(u.next);
          end;
      end;

    procedure TModule.updatemaps;
      var
        oldmapsize : LongInt;
        hp  : TModule;
        i   : LongInt;
      begin
        { Extend unitmap }
        oldmapsize:=unitmapsize;
        unitmapsize:=loaded_units.count+1;
        SetLength(unitmap,unitmapsize);

        { Extend Derefmap }
        oldmapsize:=derefmapsize;
        derefmapsize:=loaded_units.count+1;
        SetLength(derefmap,derefmapsize);
        { Add all units to unitmap }
        hp:=TModule(loaded_units.first);
        if hp=nil then exit;
        i:=hp.ModuleID;
        while Assigned(hp) do
          begin
            if hp.ModuleID>=unitmapsize then
              InternalError(2005011513);
            { Verify old entries }
            if (i<oldmapsize) then
              begin
                if (hp.ModuleID<>i) or
                   (unitmap[hp.ModuleID].u<>hp) then
                  InternalError(200501156);
              end
            else
              begin
                unitmap[hp.ModuleID].u:=hp;
                unitmap[hp.ModuleID].derefidx:=-1;
              end;
            inc(i);
            hp:=TModule(hp.next);
          end;
      end;



    function TModule.derefidx_unit(id:LongInt):LongInt;
      begin
        if id>=unitmapsize then
          InternalError(2005011511);
        if unitmap[id].derefidx=-1 then
          begin
            unitmap[id].derefidx:=derefmapcnt;
            inc(derefmapcnt);
            derefmap[unitmap[id].derefidx].u:=unitmap[id].u;
          end;
        if unitmap[id].derefidx>=derefmapsize then
          InternalError(2005011514);
        result:=unitmap[id].derefidx;
      end;


    function TModule.resolve_unit(id:LongInt):TModule;
      var
        hp : TModule;
      begin
        if id>=derefmapsize then
          begin
            WriteLn('tmodule.resolve_unit ',ModuleName^,' ',StateStr,' id=',id,' derefmapsize=',derefmapsize);
            InternalError(200306231);
          end;
        result:=derefmap[id].u;
        if not Assigned(result) then
          begin
            if not Assigned(derefmap[id].ModuleName) or
               (derefmap[id].ModuleName^='') then
              InternalError(200501159);
            hp:=TModule(loaded_units.first);
            while Assigned(hp) do
              begin
                { only check for units. The main program is also
                  as a unit in the loaded_units list. We simply need
                  to ignore this entry (PFV) }
                if hp.is_unit and
                   (hp.ModuleName^=derefmap[id].ModuleName^) then
                  break;
                hp:=TModule(hp.next);
              end;
            if not Assigned(hp) then
              InternalError(2005011510);
            derefmap[id].u:=hp;
            result:=hp;
          end;
      end;


    procedure TModule.allunitsused;
      var
        pu : TUsedUnit;
      begin
        pu:=TUsedUnit(used_units.first);
        while Assigned(pu) do
          begin
            if Assigned(pu.u.GlobalSymTable) then
              begin
                if unitmap[pu.u.ModuleID].u<>pu.u then
                  InternalError(200501157);
                { Give a note when the unit is not referenced, skip
                  this is for units with an initialization/finalization }
                if (unitmap[pu.u.ModuleID].refs=0) and
                   pu.in_uses and
                   ((pu.u.moduleflags * [mf_init,mf_finalize])=[]) then
                  CGMessagePos2(pu.unitsym.fileinfo,sym_n_unit_not_used,pu.u.RealModuleName^,RealModuleName^);
              end;
            pu:=TUsedUnit(pu.next);
          end;
      end;

    procedure TModule.end_of_parsing;
      begin
        { free asmdata }
        if Assigned(asmdata) then
          begin
            asmdata.free;
            asmdata:=nil;
          end;

        { free scanner }
        if Assigned(Scanner) then
          begin
            if CurrentScanner=TScannerFile(Scanner) then
              Set_Current_Scanner(nil);
            FreeAndNil(Scanner);
            Scanner:=nil;
          end;

        { free symtable stack }
        if Assigned(SymTableStack) then
          begin
            SymTableStack.free;
            SymTableStack:=nil;
          end;
        if Assigned(MacroSymTableStack) then
          begin
            MacroSymTableStack.free;
            MacroSymTableStack:=nil;
          end;
        waitingforunit.free;
        waitingforunit:=nil;
        localmacrosymtable.free;
        localmacrosymtable:=nil;
        ptrdefs.free;
        ptrdefs:=nil;
        arraydefs.free;
        arraydefs:=nil;
        procaddrdefs.free;
        procaddrdefs:=nil;

        checkforwarddefs.free;
        checkforwarddefs:=nil;
        tcinitcode.free;
        tcinitcode:=nil;
        localunitsearchpath.free;
        localunitsearchpath:=nil;
        localobjectsearchpath.free;
        localobjectsearchpath:=nil;
        localincludesearchpath.free;
        localincludesearchpath:=nil;
        locallibrarysearchpath.free;
        locallibrarysearchpath:=nil;
        localframeworksearchpath.free;
        localframeworksearchpath:=nil;
      end;


    procedure TModule.setmodulename(const s:string);
      begin
        StringDispose(ModuleName);
        StringDispose(RealModuleName);
        ModuleName:=StringDup(upper(s));
        RealModuleName:=StringDup(s);
        { also update asmlibrary names }
        CurrentAsmData.name:=ModuleName;
      end;


    procedure TModule.AddExternalImport(const libname, symname, symmangledname: string; OrdNr: LongInt; isvar: boolean;
      ImportByOrdinalOnly: boolean);
      var
        ImportLibrary,OtherIL : TImportLibrary;
        ImportSymbol  : TImportSymbol;
        i : LongInt;
      begin
        ImportLibrary:=TImportLibrary(ImportLibraryList.Find(libname));
        if not Assigned(ImportLibrary) then
          ImportLibrary:=TImportLibrary.Create(ImportLibraryList,libname);
        ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList.Find(symname));
        if not Assigned(ImportSymbol) then
          begin
            { Check that the same name does not exist in another library }
            { If it does and the same mangled name is used, issue a warning }
            if ImportLibraryList.Count>1 then
              for i:=0 To ImportLibraryList.Count-1 do
                begin
                  OtherIL:=TImportLibrary(ImportLibraryList.Items[i]);
                  ImportSymbol:=TImportSymbol(OtherIL.ImportSymbolList.Find(symname));
                  if Assigned(ImportSymbol) then
                    begin
                      if ImportSymbol.MangledName=symmangledname then
                        begin
                          CGMessage3(sym_w_library_overload,symname,libname,OtherIL.Name);
                          break;
                        end;
                    end;
                end;
            if not ImportByOrdinalOnly then
              { negative ordinal number indicates import by name with ordinal number as hint }
              OrdNr:=-OrdNr;
            ImportSymbol:=TImportSymbol.Create(ImportLibrary.ImportSymbolList,
              symname,symmangledname,OrdNr,isvar);
          end;
      end;


    procedure TModule.add_public_asmsym(sym:TAsmSymbol);
      begin
        add_public_asmsym(sym.name,sym.bind,sym.typ);
      end;


    procedure TModule.add_public_asmsym(const name:TSymStr;bind:TAsmsymbind;typ:TAsmsymtype);
      var
        sym : TAsmSymbol;
      begin
        { ToDo: check for AB_GLOBAL, AB_EXTERNAL? }
        sym:=TAsmSymbol(publicasmsyms.find(name));
        if Assigned(sym) then
          begin
            if (sym.bind<>bind) or (sym.typ<>typ) then
              InternalError(2016070101);
            exit;
          end;
        TAsmSymbol.create(publicasmsyms,name,bind,typ);
      end;


    procedure TModule.add_extern_asmsym(sym:TAsmSymbol);
      begin
        add_extern_asmsym(sym.name,sym.bind,sym.typ);
      end;


    procedure TModule.add_extern_asmsym(const name:TSymStr;bind:TAsmsymbind;typ:TAsmsymtype);
      var
        sym : TAsmSymbol;
      begin
        { ToDo: check for AB_EXTERNAL? }
        sym:=TAsmSymbol(externasmsyms.find(name));
        if Assigned(sym) then
          begin
            if (sym.bind<>bind) or (sym.typ<>typ) then
              InternalError(2016070102);
            exit;
          end;
        TAsmSymbol.create(externasmsyms,name,bind,typ);
      end;

    procedure TModule.remove_waitforunit_cycles;

        function search(m: TModule): boolean;
        var
          i: Integer;
        begin
          Result:=false;
          if m=self then exit(true);
          if m.cycle_search_stamp=TModule.cycle_stamp then exit;
          m.cycle_search_stamp:=TModule.cycle_stamp;
          if not Assigned(m.waitingunits) then exit;
          for i:=m.waitingunits.Count-1 downto 0 do
            if search(TModule(m.waitingunits[i])) then
              exit(true);
        end;

      var
        waitingmodule: TModule;
        i: Integer;
      begin
        if not Assigned(waitingunits) then exit;
        TModule.increase_cycle_stamp;
        for i:=waitingunits.Count-1 downto 0 do
          begin
            waitingmodule:=TModule(waitingunits[i]);
            if search(waitingmodule) then
              begin
                waitingunits.delete(i);
                waitingmodule.remove_from_waitingforunits(self);
                TModule.increase_cycle_stamp;
              end;
          end;
      end;

    procedure TModule.remove_all_waitsforthisunit;
      var
        i: Integer;
        waitingmodule: TModule;
      begin
        if not Assigned(waitingunits) then exit;
        for i:=0 to waitingunits.count-1 do
          begin
            waitingmodule:=TModule(waitingunits[i]);
            waitingmodule.remove_from_waitingforunits(self);
          end;
        waitingunits.Clear;
      end;

    procedure TModule.remove_from_waitingforunits(amodule: TModule);
    begin
      // It can be nil after when this is called after end_of_parsing was called.
      if Assigned(waitingforunit) then
        waitingforunit.remove(amodule);
    end;

    function TModule.ToString: RTLString;
      begin
        // Assigned self so we can detect nil.
        if Assigned(ModuleName) then
          Result:='('+ModuleName^+')'
        else
         Result:='(<'+IntToStr(ptrint(self))+'>)';
        // Possibly add some state ?
      end;

    procedure TModule.WriteUsedUnits(m: TModule);
    var
      uu: TUsedUnit;
    begin
      if m=nil then exit;
      WriteLn('tmodule.WriteUsedUnits ',m.ModuleName^,' ',m.StateStr);
      WriteLn('  interface uses:');
      uu:=TUsedUnit(m.used_units.First);
      while Assigned(uu) do
        begin
          if uu.in_interface then
            WriteLn('  ',uu.u.ModuleName^,' ',uu.u.StateStr);
          uu:=TUsedUnit(uu.Next);
        end;
      WriteLn('  implementation uses:');
      uu:=TUsedUnit(m.used_units.First);
      while Assigned(uu) do
        begin
          if not uu.in_interface then
            WriteLn('  ',uu.u.ModuleName^,' ',uu.u.StateStr);
          uu:=TUsedUnit(uu.Next);
        end;
    end;


initialization
{$ifdef MEMDEBUG}
  memsymtable:=TMemDebug.create('Symtables');
  memsymtable.stop;
{$endif MEMDEBUG}

finalization
{$ifdef MEMDEBUG}
  memsymtable.free;
  memsymtable := nil;
{$endif MEMDEBUG}

end.
