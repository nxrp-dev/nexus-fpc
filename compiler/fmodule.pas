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
       GlobType,FinPut,OGBase,FPkg,
       SymBase,SymSym,
       WPOBase,
       AAsmBase,AAsmData;


    const
      UnspecifiedLibraryName = '<none>';

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
         Data : TPathStr;
         NeedLink : Cardinal;
         constructor Create(const S:TPathStr;M:Cardinal);
      end;

      TLinkContainer=class(TLinkedList)
         procedure Add(const S : TPathStr;M:Cardinal);
         function Get(var M:Cardinal) : TPathStr;
         function GetUseMask(Mask:Cardinal) : TPathStr;
         function Find(const S:TPathStr):Boolean;
      end;

      TModule = class;
      TUsedUnit = class;

      TUnitImportSym = class
        Module: TModule;
        SymID: LongInt;
        Sym: TSymEntry;
      end;

      TUnitMapRec = record
        U        : TModule;
        { number of references }
        Refs     : LongInt;
        { index in the derefmap }
        DerefIdx : LongInt;
      end;
      TUnitMapArray = array of TUnitMapRec;

      TDerefMapRec = record
        U           : TModule;
        { modulename, used during ppu load }
        ModuleName  : PShortString;
      end;
      TDerefMapArray = array of TDerefMapRec;

      TFinishModuleEvent = procedure(m: TModule) of object;
      TRenameModuleEvent = procedure(m: TModule; const oldname: TSymStr) of object;

      { tused_unit }

      TUsedUnit = class(TLinkedListItem)
        Checksum,
        InterfaceChecksum,
        IndirectChecksum: Cardinal;
        InUses,
        InInterface    : Boolean;
        U               : TModule;
        UnitSym         : TUnitSym;
        DependentAdded : Boolean;
        constructor Create(AUnit : TModule;IntFace,AInUses:Boolean;USym:TUnitSym);
        procedure Check_Hints;
      end;

      TDependentUnit = class(TLinkedListItem)
        U : TModule;
        InInterface : Boolean;
        constructor Create(AUnit : TModule; FromInterface : Boolean);
      end;

      { tmodule }

      TModule = class(TModuleBase)
      private
        FImportLibraryList : TFPHashObjectList;
      public
        LoadedFromModule: TModule;
        IsReset,                 { has reset been called ? }
        DoRecompile,         { reset needed, done by ctask }
        DoReload,                { force reloading of the unit }
        FromPPU: Boolean;         { loaded from ppu }
        PPUDiscarded: Boolean;         { ppu was recompiled }
        PPUWaitingForCRC: Boolean;
        SourcesAvail,            { if all sources are reachable }
        InterfaceCompiled,       { if the interface section has been parsed/compiled/loaded, interface_crc and indirect_crc are valid }
        IsDbgInfoWritten,
        IsUnit,
        InInterface,             { processing the interface part? }
        { allow global settings }
        InGlobal     : Boolean;
        { Whether a mode switch is still allowed at this point in the parsing.}
        ModeSwitchAllowed,
        { generate pic helper which loads eip in ecx (for leave procedures) }
        RequiresECXPICHelper,
        { generate pic helper which loads eip in ebx (for non leave procedures) }
        RequiresEBXPICHelper : Boolean;
        InterfaceOnly: Boolean; { interface-only macpas unit; flag does not need saving/restoring to ppu }
        MainFilePos   : TFilePosInfo;
        RecompileReason : TRecompileReason;  { the reason why the unit should be recompiled }
        CRCFinal: Boolean;
        CRC,                       { valid when crc_final=true }
        InterfaceCRC,             { valid when interface_compiled=true }
        IndirectCRC  : Cardinal;  { valid when interface_compiled=true }
        HeaderFlags   : Cardinal;  { the PPU header flags }
        LongVersion   : Cardinal;  { longer version than what fits in the ppu header }
        ModuleFlags   : TModuleFlags; { ppu flags that do not need to be known by just reading the ppu header }
        IsLibrary     : Boolean;  { if it is a library (win32 dll) }
        IsPackage     : Boolean;
        ChangeEndian : Boolean;  { if the unit is loaded on a system with a different endianess than it was compiled on }
        UnitMap       : TUnitMapArray; { mapping of all used units }
        UnitMapSize   : LongInt;  { number of units in the map }
        DerefMap      : TDerefMapArray; { mapping of all units needed for deref }
        DerefMapCnt   : LongInt;  { number of units in the map }
        DerefMapSize  : LongInt;  { number of units in the map }
        DerefDataIntfLen : LongInt;
        DerefData     : TDynamicArray;
        CheckForwardDefs,
        DefList,
        SymList       : TFPObjectList;
        ForwardGenericDefs : TFPHashObjectList; { contains a list of specializations of a forward declared generic (the key) }
        PtrDefs       : THashSet; { list of pointerdefs created in this module so we can reuse them (not saved/restored) }
        ArrayDefs     : THashSet; { list of single-element-arraydefs created in this module so we can reuse them (not saved/restored) }
        ProcAddrDefs  : THashSet; { list of procvardefs created when getting the address of a procdef (not saved/restored) }

        AnsiStrDef    : TObject; { an ansistring def redefined for the current module }
        WPOInfo       : TUnitWPOInfoBase; { whole program optimization-related information that is generated during the current run for this unit }
        GlobalSymTable,           { pointer to the global symtable of this unit }
        LocalSymTable : TSymTable;{ pointer to the local symtable of this unit }
        GlobalMacroSymTable,           { pointer to the global macro symtable of this unit }
        LocalMacroSymTable : TSymTable;{ pointer to the local macro symtable of this unit }
        MainScanner   : TObject;  { scanner object used }
        Scanner       : TObject;  { scanner object used }
        ProcInfo      : TObject;  { current procedure being compiled }
        AsmData       : TObject;  { Assembler data }
        AsmPrefix     : PShortString;  { prefix for the smartlink asmfiles }
        PublicAsmSyms : TFPHashObjectList; { contains the assembler symbols which need to be exported from a package }
        ExternAsmSyms : TFPHashObjectList; { contains the assembler symbols which are imported from another unit }
        UnitImportSyms : TFPObjectList; { list of symbols (tunitimportsym) that are imported from other units }
        DebugInfo     : TObject;
        ExportList      : TLinkedList;
        DLLScannerInputList : TFPHashList;
        LocalNamespaceList,
        ResourceFiles,
        LinkOrderedSymbols : TCmdStrList;
        LinkUnitOFiles,
        LinkUnitStaticLibs,
        LinkUnitSharedLibs,
        LinkOtherOFiles,           { objects,libs loaded from the source }
        LinkOtherSharedLibs,       { using $L or $LINKLIB or import lib (for linux) }
        LinkOtherStaticLibs,
        LinkOtherFrameworks  : TLinkContainer;
        MainName      : PShortString; { alternate name for "main" procedure }
        Package       : TPackage;

        UsedUnitList           : TLinkedList; { list of tused_unit }
        DependentUnitList      : TLinkedList;

        { circular unit groups = strongly connected components }
        SCCFinished: Boolean; { scc is compiled = this module and all used modules even indirectly are ms_procesed
                                 Note that in a cycle ms_processed can be reached while scc_finished is still false }
        SCCRoot: TModule;     { valid if not scc_finished: all modules of a scc poins to their root module }
        SCCNext: TModule;     { next module in same scc }
        SCCIndex: Integer;    { dont use. used in ttask_handler.update_circular_unit_groups }
        SCCLowIndex: Integer; { valid if >0 and scc_finished=false.
                                 lowest scc_index reachable through used_units,
                                 all circular connected modules have the same lowindex }
        SCCOnStack: Boolean;  { dont use. used in ttask_handler.update_circular_unit_groups }
        class var
          CTask_Fast_Backtrack: Boolean; { true if some cycle was detected and returning fast to ctask scheduler }
          Cycle_Stamp: DWord;
        var
        CycleSearchStamp: DWord;
        SCCTreeUnfinished: Boolean; { the scc or a sub scc has at least one module not ms_processed }
        OtherSCCUnfinished: Boolean; { a sub scc has a module not ms_processed }
        SCCTreeCRCWait: TModule; { an unfinished used unit, can be indirectly used, not self }

        Task: TObject;         { ctask ttask }

        LocalUnitSearchPath,           { local searchpaths }
        LocalObjectSearchPath,
        LocalIncludeSearchPath,
        LocalLibrarySearchPath,
        LocalFrameworkSearchPath : TSearchPathList;

        ModuleOptions: TModuleOptions;
        DeprecatedMsg: PShortString;
        CompileCount : Integer;
        ConsumeSemicolonAfterUses : Boolean;
        InitFinalChecked : Boolean;
        FuncTypeChecked : Boolean;

        { contains a list of types that are extended by helper types; the key is
          the full name of the type and the data is a TFPObjectList of
          tobjectdef instances (the helper defs) }
        ExtendedDefs: TFPHashObjectList;
        { contains a list of the current topmost non-generic symbol for a
          typename of which at least one generic exists; the key is the
          non-generic typename and the data is a TFPObjectList of tgenericdummyentry
          instances whereby the last one is the current top most one }
        GenericDummySyms: TFPHashObjectList;
        { contains a list of specializations for which the method bodies need
          to be generated }
        PendingSpecializations : TFPHashObjectList;
        { list of attributes that are used and thus need their construction
          functions generated }
        UsedRTTIAttrs: TFPObjectList;

        { this contains a list of units (tmodule) that needs to be waited for until the
          unit can be finished (code generated, etc.); this is needed to handle
          specializations in circular unit usages correctly }
        WaitingForUnit: TFPObjectList;
        { this contains a list of all units (tmodule) that are waiting for this unit to be
          finished }
        WaitingUnits: TFPObjectList;

        FinishState: Pointer;
        SpecializeState : Pointer;


        { for targets that initialise typed constants via explicit assignments
          instead of by generating an initialised data section (holds typed
          constant assignments at the module level; does not have to be saved
          into the ppu file, because translated into code during compilation)
           -- actual type: tnode (but fmodule should not depend on node) }
        TCInitCode     : TObject;

        { the current extended rtti directive }
        RTTIDirective : TRTTIDirective;

        {create creates a new module which name is stored in 's'. LoadedFrom
        points to the module calling it. It is nil for the first compiled
        module. This allow inheritance of all path lists. MUST pay attention
        to that when creating link.res!!!!(mazen)}
        constructor Create(LoadedFrom: TModule; const AModuleName: string; const AFileName:TPathStr;AIsUnit:Boolean);
        destructor Destroy;override;
        procedure Reset(ForRecompile: Boolean);virtual;
        function StateStr: string; virtual;
        procedure CheckState; virtual;
        procedure LoadLocalNamespaceList;
        procedure AddDependency(CallerModule:TModule; FromInterface : Boolean);
        procedure RemoveDependency(CallerModule:TModule);
        function HasDependency(CallerModule:TModule): Boolean;
        procedure FlagDependent;
        function Find_Used_Unit_Compiling: TModule; // find a used module compiling/loading, even indirect
        class procedure Increase_Cycle_Stamp;
        procedure Disconnect_Depending_Modules; virtual;
        function Is_Reload_Needed(DU: TDependentUnit): Boolean; virtual; // true if reload needed after self changed
        class var Finish_Module: TFinishModuleEvent;
        procedure AddImportedSym(Sym:TSymEntry; CheckIfExists: Boolean = True);
        procedure DerefImportedSymbols;
        function  AddUsedUnit(HP:TModule;AInUses:Boolean;USym:TUnitSym):TUsedUnit;
        function  UsesModule_In_Interface(M : TModule) : Boolean;
        function FindUsedUnit(M : TModule) : TUsedUnit;
        function UsedUnitsLoaded(InterfaceUnits: Boolean; out FirstWaiting : TModule): Boolean;
        function NoWaitingForUnits(out FirstWaiting : TModule) : Boolean;
        function UsedUnitsFinalCRC(out FirstWaiting : TModule): Boolean;
        procedure UpdateMaps;
        function  DerefIdx_Unit(ID:LongInt):LongInt;
        function  Resolve_Unit(ID:LongInt):TModule;
        procedure AllUnitsUsed;
        procedure End_Of_Parsing;virtual;
        procedure SetModuleName(const S:string);
        procedure AddExternalImport(const LibName,SymName,SymMangledName:string;OrdNr: LongInt;IsVar:Boolean;ImportByOrdinalOnly:Boolean);
        procedure Add_Public_AsmSym(Sym:TAsmSymbol);
        procedure Add_Public_AsmSym(const Name:TSymStr;Bind:TAsmsymbind;Typ:TAsmsymtype);
        procedure Add_Extern_AsmSym(Sym:TAsmSymbol);
        procedure Add_Extern_AsmSym(const Name:TSymStr;Bind:TAsmsymbind;Typ:TAsmsymtype);
        procedure Remove_WaitForUnit_Cycles;
        procedure Remove_All_WaitsForThisUnit;
        procedure Remove_From_WaitingForUnits(AModule : TModule);
        property ImportLibraryList : TFPHashObjectList Read FImportLibraryList;
        function ToString: RTLString; override;
        procedure WriteUsedUnits(M: TModule);
      end;

    var
       Main_Module       : TModule;     { Main module of the program }
       CurrentModule    : TModule;     { Current module which is compiled or loaded }
       UsedUnits         : TLinkedList; { Used units for this program }
       Loaded_Units      : TLinkedList; { All loaded units, excluding main_module }
       Unloaded_Units    : TLinkedList; { Units removed from loaded_units, to be freed }
       All_Modules: array of TModule;   { modules by moduleid }
       SmartLinkOFiles   : TCmdStrList; { List of .o files which are generated,
                                          used to delete them after linking }


    procedure SetCurrentModule(P:TModule);
    function Get_Module(ModuleIndex : LongInt) : TModule;
    function Get_Source_File(ModuleIndex,FileIndex : LongInt) : TInputFile;
    procedure AddLoadedUnit(HP:TModule);
    function Find_Module_From_SymTable(ST:TSymTable):TModule;


implementation

    uses
      SysUtils,Globals,
      Verbose,Systems,
      Scanner,DbgBase,
      ProcInfo,SymDef,SymType;

{$ifdef MEMDEBUG}
    var
      MemSymTable : TMemDebug;
{$endif}

{*****************************************************************************
                             Global Functions
*****************************************************************************}

    function Find_Module_From_SymTable(ST:TSymTable):TModule;
      begin
        Result:=Get_Module(ST.ModuleID);
      end;

    procedure SetCurrentModule(P:TModule);

      begin
        { save the state of the scanner }
        if Assigned(CurrentScanner) then
          CurrentScanner.TempCloseInputFile;
        { set new module }
        CurrentModule:=P;
        { restore previous module settings }
        Fillchar(CurrentFilePos,SizeOf(CurrentFilePos),0);
        if Assigned(CurrentModule) then
          begin
            CurrentAsmData:=TAsmData(CurrentModule.AsmData);
            CurrentDebugInfo:=TDebugInfo(CurrentModule.DebugInfo);
            { restore scanner and file positions }
            Set_Current_Scanner(TScannerFile(CurrentModule.Scanner));
            if Assigned(CurrentScanner) then
              begin
                CurrentScanner.TempOpenInputFile;
                CurrentScanner.GetTokenPos;
                Parser_Current_File:=CurrentScanner.InputFile.Name;
              end
            else
              begin
                CurrentFilePos.ModuleIndex:=CurrentModule.ModuleID;
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


    function Get_Module(ModuleIndex : LongInt) : TModule;
      begin
        if ModuleIndex>=Length(All_Modules) then
          Result:=nil
        else
          Result:=All_Modules[ModuleIndex];
      end;


    function Get_Source_File(ModuleIndex,FileIndex : LongInt) : TInputFile;
      var
        HP : TModule;
      begin
        HP:=Get_Module(ModuleIndex);
        if Assigned(HP) then
          Get_Source_File:=HP.SourceFiles.Get_File(FileIndex)
        else
          Get_Source_File:=nil;
      end;


    procedure AddLoadedUnit(HP:TModule);
      begin
        Loaded_Units.Concat(HP);
      end;


{****************************************************************************
                             TLinkContainerItem
 ****************************************************************************}

    constructor TLinkContainerItem.Create(const S:TPathStr;M:Cardinal);
      begin
        inherited Create;
        Data:=S;
        NeedLink:=M;
      end;


{****************************************************************************
                           TLinkContainer
 ****************************************************************************}

    procedure TLinkContainer.Add(const S : TPathStr;M:Cardinal);
      begin
        inherited Concat(TLinkContainerItem.Create(S,M));
      end;


    function TLinkContainer.Get(var M:Cardinal) : TPathStr;
      var
        P : TLinkContainerItem;
      begin
        P:=TLinkContainerItem(inherited GetFirst);
        if P=nil then
         begin
           Get:='';
           M:=0;
         end
        else
         begin
           Get:=P.Data;
           M:=P.NeedLink;
           P.Free;
           P := nil;
         end;
      end;


    function TLinkContainer.GetUseMask(Mask:Cardinal) : TPathStr;
      var
         P : TLinkContainerItem;
         Found : Boolean;
      begin
        Found:=False;
        repeat
          P:=TLinkContainerItem(inherited GetFirst);
          if P=nil then
           begin
             GetUseMask:='';
             Exit;
           end;
          GetUseMask:=P.Data;
          Found:=(P.NeedLink and Mask)<>0;
          P.Free;
          P := nil;
        until Found;
      end;


    function TLinkContainer.Find(const S:TPathStr):Boolean;
      var
        NewNode : TLinkContainerItem;
      begin
        Find:=False;
        NewNode:=TLinkContainerItem(First);
        while Assigned(NewNode) do
         begin
           if NewNode.Data=S then
            begin
              Find:=True;
              Exit;
            end;
           NewNode:=TLinkContainerItem(NewNode.Next);
         end;
      end;


{****************************************************************************
                              TUSED_UNIT
 ****************************************************************************}

    constructor TUsedUnit.Create(AUnit : TModule;IntFace,AInUses:Boolean;USym:TUnitSym);
      begin
        U:=AUnit;
        InInterface:=IntFace;
        InUses:=AInUses;
        UnitSym:=USym;
        if AUnit.State in [ms_load,ms_compiled_waitcrc,ms_compiled,ms_processed] then
          Checksum:=U.CRC
        else
          Checksum:=0;
        if AUnit.InterfaceCompiled then
         begin
           InterfaceChecksum:=U.InterfaceCRC;
           IndirectChecksum:=U.IndirectCRC;
         end
        else
         begin
           InterfaceChecksum:=0;
           IndirectChecksum:=0;
         end;
      end;


    procedure TUsedUnit.Check_Hints;
      var
        UName: PShortString;
      begin
        UName:=U.RealModuleName;
        if mo_hint_deprecated in U.ModuleOptions then
          if (mo_has_deprecated_msg in U.ModuleOptions) and (U.DeprecatedMsg <> nil) then
            MessagePos2(UnitSym.FileInfo,sym_w_deprecated_unit_with_msg,UName^,U.DeprecatedMsg^)
          else
            MessagePos1(UnitSym.FileInfo,sym_w_deprecated_unit,UName^);
        if mo_hint_experimental in U.ModuleOptions then
          MessagePos1(UnitSym.FileInfo,sym_w_experimental_unit,UName^);
        if mo_hint_platform in U.ModuleOptions then
          MessagePos1(UnitSym.FileInfo,sym_w_non_portable_unit,UName^);
        if mo_hint_library in U.ModuleOptions then
          MessagePos1(UnitSym.FileInfo,sym_w_library_unit,UName^);
        if mo_hint_unimplemented in U.ModuleOptions then
          MessagePos1(UnitSym.FileInfo,sym_w_non_implemented_unit,UName^);
      end;


{****************************************************************************
                            TDENPENDENT_UNIT
 ****************************************************************************}

    constructor TDependentUnit.Create(AUnit: TModule; FromInterface: Boolean);
      begin
         U:=AUnit;
         InInterface:=FromInterface;
      end;


{****************************************************************************
                                  TMODULE
 ****************************************************************************}

    constructor TModule.Create(LoadedFrom: TModule; const AModuleName: string; const AFileName:TPathStr;AIsUnit:Boolean);
      var
        N:string;
        FN:TPathStr;
        OldModuleCount, I: SizeInt;
        NewModuleCount: Integer;
      begin
        LoadedFromModule:=LoadedFrom;
        if AModuleName='' then
          N:=ChangeFileExt(ExtractFileName(AFileName),'')
        else
          N:=AModuleName;
        if AFileName='' then
          FN:=AModuleName
        else
          FN:=AFileName;
        { Programs have the name 'Program' to don't conflict with dup id's }
        if AIsUnit then
         inherited Create(AModuleName)
        else
         inherited Create('Program');
        MainSource:=FN;

        OldModuleCount:=Length(All_Modules);
        if ModuleID>=OldModuleCount then
          begin
            if OldModuleCount<32 then
              NewModuleCount:=32
            else
              NewModuleCount:=OldModuleCount*2;
            SetLength(All_Modules,NewModuleCount);
            for I:=OldModuleCount to NewModuleCount-1 do
              All_Modules[I]:=nil;
          end;
        All_Modules[ModuleID]:=Self;

        AsmPrefix:=StringDup(FixFileName(N));
        SetFileName(FN,True);
        LocalUnitSearchPath:=TSearchPathList.Create;
        LocalObjectSearchPath:=TSearchPathList.Create;
        LocalIncludeSearchPath:=TSearchPathList.Create;
        LocalLibrarySearchPath:=TSearchPathList.Create;
        LocalFrameworkSearchPath:=TSearchPathList.Create;
        UsedUnitList:=TLinkedList.Create;
        DependentUnitList:=TLinkedList.Create;
        LocalNamespaceList:=TCmdStrList.Create;
        ResourceFiles:=TCmdStrList.Create;
        LinkOrderedSymbols:=TCmdStrList.Create;
        LinkUnitOFiles:=TLinkContainer.Create;
        LinkUnitStaticLibs:=TLinkContainer.Create;
        LinkUnitSharedLibs:=TLinkContainer.Create;
        LinkOtherOFiles:=TLinkContainer.Create;
        LinkOtherStaticLibs:=TLinkContainer.Create;
        LinkOtherSharedLibs:=TLinkContainer.Create;
        LinkOtherFrameworks:=TLinkContainer.Create;
        MainName:=nil;
        FImportLibraryList:=TFPHashObjectList.Create(True);
        CRCFinal:=False;
        CRC:=0;
        InterfaceCRC:=0;
        IndirectCRC:=0;
        HeaderFlags:=0;
        LongVersion:=0;
        ModuleFlags:=[];
        Scanner:=nil;
        UnitMap:=nil;
        UnitMapSize:=0;
        DerefMap:=nil;
        DerefMapSize:=0;
        DerefMapCnt:=0;
        DerefData:=TDynamicArray.Create(1024);
        DerefDataIntfLen:=0;
        DefList:=TFPObjectList.Create(False);
        SymList:=TFPObjectList.Create(False);
        PtrDefs:=THashSet.Create(64,True,False);
        ArrayDefs:=THashSet.Create(64,True,False);
        ProcAddrDefs:=THashSet.Create(64,True,False);

        AnsiStrDef:=nil;
        WPOInfo:=nil;
        CheckForwardDefs:=TFPObjectList.Create(False);
        ForwardGenericDefs:=TFPHashObjectList.Create(True);
        ExtendedDefs:=TFPHashObjectList.Create(True);
        GenericDummySyms:=TFPHashObjectList.Create(True);
        PendingSpecializations:=TFPHashObjectList.Create(False);
        WaitingForUnit:=TFPObjectList.Create(False);
        WaitingUnits:=TFPObjectList.Create(False);
        UsedRTTIAttrs:=TFPObjectList.Create(False);
        GlobalSymTable:=nil;
        LocalSymTable:=nil;
        GlobalMacroSymTable:=nil;
        LocalMacroSymTable:=nil;
        DoReload:=False;
        SourcesAvail:=True;
        MainFilePos.Line:=0;
        MainFilePos.Column:=0;
        MainFilePos.FileIndex:=0;
        RecompileReason:=rr_unknown;
        InInterface:=True;
        InGlobal:=True;
        IsUnit:=AIsUnit;
        IsLibrary:=False;
        IsPackage:=False;
        ChangeEndian:=False;
        IsDbgInfoWritten:=False;
        ModeSwitchAllowed:= True;
        ModuleOptions:=[];
        DeprecatedMsg:=nil;
        TCInitCode:=nil;
        ExportList:=TLinkedList.Create;
        DLLScannerInputList:=TFPHashList.Create;
        AsmData:=CAsmData.Create(ModuleName);
        UnitImportSyms:=TFPObjectList.Create(True);
        PublicAsmSyms:=TFPHashObjectList.Create(True);
        ExternAsmSyms:=TFPHashObjectList.Create(True);
        InitDebugInfo(Self,False);
      end;


    destructor TModule.Destroy;
      var
        I : LongInt;
        CurrentDebugInfoReset : Boolean;
      begin
        UnitMap:=nil;
        if Assigned(DerefMap) then
          begin
            for I:=0 to DerefMapCnt-1 do
              StringDispose(DerefMap[I].ModuleName);
          end;
        DerefMap:=nil;
        if Assigned(ExportList) then
          FreeAndNil(ExportList);
        if Assigned(DLLScannerInputList) then
          FreeAndNil(DLLScannerInputList);
        if Assigned(LocalNamespaceList) then
          FreeAndNil(LocalNamespaceList);
        if Assigned(Scanner) then
          begin
            { also update current_scanner if it was pointing
              to this module }
            if CurrentScanner=TScannerFile(Scanner) then
              Set_Current_Scanner(nil);
            FreeAndNil(Scanner);
          end;
        if Assigned(AsmData) then
          begin
            if CurrentAsmData=AsmData then
              CurrentAsmData:=nil;
             AsmData.Free;
             AsmData := nil;
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
        DoneDebugInfo(Self,CurrentDebugInfoReset);
        UsedUnitList.Free;
        UsedUnitList := nil;
        DependentUnitList.Free;
        DependentUnitList := nil;
        ResourceFiles.Free;
        ResourceFiles := nil;
        LinkOrderedSymbols.Free;
        LinkOrderedSymbols := nil;
        LinkUnitOFiles.Free;
        LinkUnitOFiles := nil;
        LinkUnitStaticLibs.Free;
        LinkUnitStaticLibs := nil;
        LinkUnitSharedLibs.Free;
        LinkUnitSharedLibs := nil;
        LinkOtherOFiles.Free;
        LinkOtherOFiles := nil;
        LinkOtherStaticLibs.Free;
        LinkOtherStaticLibs := nil;
        LinkOtherSharedLibs.Free;
        LinkOtherSharedLibs := nil;
        LinkOtherFrameworks.Free;
        LinkOtherFrameworks := nil;
        StringDispose(MainName);
        ExternAsmSyms.Free;
        ExternAsmSyms := nil;
        PublicAsmSyms.Free;
        PublicAsmSyms := nil;
        UnitImportSyms.Free;
        UnitImportSyms := nil;
        FImportLibraryList.Free;
        FImportLibraryList := nil;
        ExtendedDefs.Free;
        ExtendedDefs := nil;
        GenericDummySyms.Free;
        GenericDummySyms := nil;
        PendingSpecializations.Free;
        PendingSpecializations := nil;
        WaitingForUnit.Free;
        WaitingForUnit := nil;
        WaitingUnits.Free;
        WaitingUnits := nil;
        UsedRTTIAttrs.Free;
        UsedRTTIAttrs := nil;
        StringDispose(AsmPrefix);
        StringDispose(DeprecatedMsg);
        TCInitCode.Free;
        TCInitCode := nil;
        LocalUnitSearchPath.Free;
        LocalUnitSearchPath := nil;
        LocalObjectSearchPath.Free;
        LocalObjectSearchPath := nil;
        LocalIncludeSearchPath.Free;
        LocalIncludeSearchPath := nil;
        LocalLibrarySearchPath.Free;
        LocalLibrarySearchPath := nil;
        LocalFrameworkSearchPath.Free;
        LocalFrameworkSearchPath := nil;
{$ifdef MEMDEBUG}
        MemSymTable.Start;
{$endif}
        DerefData.Free;
        DerefData := nil;
        if Assigned(DefList) then
          begin
            for I:=0 to DefList.Count-1 do
              if Assigned(DefList[I]) and
                 (TDef(DefList[I]).RegisteredInModule=Self) then
                TDef(DefList[I]).RegisteredInModule:=nil;
            DefList.Free;
            DefList := nil;
          end;
        SymList.Free;
        SymList := nil;
        PtrDefs.Free;
        PtrDefs := nil;
        ArrayDefs.Free;
        ArrayDefs := nil;
        ProcAddrDefs.Free;
        ProcAddrDefs := nil;

        AnsiStrDef:=nil;
        WPOInfo.Free;
        WPOInfo := nil;
        CheckForwardDefs.Free;
        CheckForwardDefs := nil;
        ForwardGenericDefs.Free;
        ForwardGenericDefs := nil;
        GlobalSymTable.Free;
        GlobalSymTable := nil;
        LocalSymTable.Free;
        LocalSymTable := nil;
        GlobalMacroSymTable.Free;
        GlobalMacroSymTable := nil;
        LocalMacroSymTable.Free;
        LocalMacroSymTable := nil;

        Task:=nil;
        All_Modules[ModuleID]:=nil;
{$ifdef MEMDEBUG}
        MemSymTable.Stop;
{$endif}
        inherited Destroy;
      end;


    procedure TModule.Reset(ForRecompile: Boolean);
      var
        I   : LongInt;
        CurrentDebugInfoReset : Boolean;
        M : TModule;
      begin
        IsReset:=True;
        DoRecompile:=False;
        FromPPU:=False;
        if Assigned(Scanner) then
          begin
            { also update current_scanner if it was pointing
              to this module }
            if CurrentScanner=TScannerFile(Scanner) then
              Set_Current_Scanner(nil);
            FreeAndNil(Scanner);
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
        if Assigned(AsmData) then
          begin
            if CurrentAsmData=AsmData then
              CurrentAsmData:=nil;
            AsmData.Free;
            AsmData:=nil;
          end;
        DoneDebugInfo(Self,CurrentDebugInfoReset);
        GlobalSymTable.Free;
        GlobalSymTable:=nil;
        LocalSymTable.Free;
        LocalSymTable:=nil;
        GlobalMacroSymTable.Free;
        GlobalMacroSymTable:=nil;
        LocalMacroSymTable.Free;
        LocalMacroSymTable:=nil;
        DefList.Free;
        DefList:=TFPObjectList.Create(False);
        SymList.Free;
        SymList:=TFPObjectList.Create(False);
        PtrDefs.Free;
        PtrDefs:=THashSet.Create(64,True,False);
        ArrayDefs.Free;
        ArrayDefs:=THashSet.Create(64,True,False);
        ProcAddrDefs.Free;
        ProcAddrDefs:=THashSet.Create(64,True,False);

        AnsiStrDef:=nil;
        WPOInfo.Free;
        WPOInfo:=nil;
        CheckForwardDefs.Free;
        CheckForwardDefs:=TFPObjectList.Create(False);
        ForwardGenericDefs.Free;
        ForwardGenericDefs:=TFPHashObjectList.Create(True);
        PublicAsmSyms.Free;
        PublicAsmSyms:=TFPHashObjectList.Create(True);
        ExternAsmSyms.Free;
        ExternAsmSyms:=TFPHashObjectList.Create(True);
        UnitImportSyms.Free;
        UnitImportSyms:=TFPObjectList.Create(True);
        DerefData.Free;
        DerefData:=TDynamicArray.Create(1024);
        UnitMap:=nil;
        if Assigned(DerefMap) then
          begin
            for I:=0 to DerefMapCnt-1 do
              StringDispose(DerefMap[I].ModuleName);
          end;
        DerefMap:=nil;
        UnitMapSize:=0;
        DerefMapSize:=0;
        DerefMapCnt:=0;
        DerefDataIntfLen:=0;
        SourceFiles.Free;
        SourceFiles:=TInputFileManager.Create;
        AsmData:=CAsmData.Create(ModuleName);
        if CurrentModule=Self then
          CurrentAsmData:=TAsmData(AsmData);
        InitDebugInfo(Self,CurrentDebugInfoReset);
        ExportList.Free;
        ExportList:=TLinkedList.Create;
        DLLScannerInputList.Free;
        DLLScannerInputList:=TFPHashList.Create;
        { During reload, the list of used units cannot change.
          It can only change while recompiling.
          Because the used_units is used in loops in the load cycle(s) which
          can recurse into the same unit due to circular dependencies,
          we do not destroy the list, we only update the contents.
          As a result the loop variable does not get reset during the loop.
          For recompile, we recreate the list }
        if ForRecompile then
          begin
          UsedUnitList.Free;
          UsedUnitList:=TLinkedList.Create;
          end;
        // keep dependent_units
        ResourceFiles.Free;
        ResourceFiles:=TCmdStrList.Create;
        LinkOrderedSymbols.Free;
        LinkOrderedSymbols:=TCmdStrList.Create;
        PendingSpecializations.Free;
        PendingSpecializations:=TFPHashObjectList.Create(False);
        GenericDummySyms.Free;
        GenericDummySyms := TFPHashObjectList.Create(True);
        ExtendedDefs.Free;
        ExtendedDefs:=TFPHashObjectList.Create(True);
        if Assigned(WaitingForUnit) and
          (WaitingForUnit.Count<>0) then
           begin
           Write(Self.ModuleName^, ' is reset while still waiting for units: ');
           for I:=0 to WaitingForUnit.Count-1 do
             begin
             M:=TModule(WaitingForUnit.Items[I]);
             Write(M.ModuleName^,' (state:',M.State,') ');
             end;
           WriteLn;
           InternalError(2016070501);
           end;
        WaitingForUnit.Free;
        WaitingForUnit:=TFPObjectList.Create(False);
        LinkUnitOFiles.Free;
        LinkUnitOFiles:=TLinkContainer.Create;
        LinkUnitStaticLibs.Free;
        LinkUnitStaticLibs:=TLinkContainer.Create;
        LinkUnitSharedLibs.Free;
        LinkUnitSharedLibs:=TLinkContainer.Create;
        LinkOtherOFiles.Free;
        LinkOtherOFiles:=TLinkContainer.Create;
        LinkOtherStaticLibs.Free;
        LinkOtherStaticLibs:=TLinkContainer.Create;
        LinkOtherSharedLibs.Free;
        LinkOtherSharedLibs:=TLinkContainer.Create;
        LinkOtherFrameworks.Free;
        LinkOtherFrameworks:=TLinkContainer.Create;
        StringDispose(MainName);
        FImportLibraryList.Free;
        FImportLibraryList:=TFPHashObjectList.Create;
        DoReload:=False;
        InterfaceCompiled:=False;
        InInterface:=True;
        InGlobal:=True;
        ModeSwitchAllowed:=True;
        StringDispose(DeprecatedMsg);
        TCInitCode.Free;
        TCInitCode:=nil;
        LocalUnitSearchPath.Free;
        LocalUnitSearchPath:=TSearchPathList.Create;
        LocalObjectSearchPath.Free;
        LocalObjectSearchPath:=TSearchPathList.Create;
        LocalIncludeSearchPath.Free;
        LocalIncludeSearchPath:=TSearchPathList.Create;
        LocalLibrarySearchPath.Free;
        LocalLibrarySearchPath:=TSearchPathList.Create;
        LocalFrameworkSearchPath.Free;
        LocalFrameworkSearchPath:=TSearchPathList.Create;
        ModuleOptions:=[];
        IsDbgInfoWritten:=False;
        CRCFinal:=False;
        CRC:=0;
        InterfaceCRC:=0;
        IndirectCRC:=0;
        HeaderFlags:=0;
        LongVersion:=0;
        ModuleFlags:=[];
        MainFilePos.Line:=0;
        MainFilePos.Column:=0;
        MainFilePos.FileIndex:=0;
        RecompileReason:=rr_unknown;
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

    procedure TModule.LoadLocalNamespaceList;

      var
        NSItem : TCmdStrListItem;

      begin
        // Copying local namespace list
        if PreModule_NamespaceList.Count>0 then
          begin
          NSItem:=TCmdStrListItem(PreModule_NamespaceList.First);
          while Assigned(NSItem) do
            begin
            LocalNamespaceList.Concat(NSItem.Str);
            NSItem:=TCmdStrListItem(NSItem.Next);
            end;
          PreModule_NamespaceList.Clear;
          end;
        CurrentNamespaceList:=LocalNamespaceList;
      end;


    procedure TModule.AddDependency(CallerModule: TModule; FromInterface: Boolean);
      begin
        if HasDependency(CallerModule) then Exit;
        if IsUnit then
          Message2(unit_u_add_depend_to,CallerModule.ModuleName^,ModuleName^);

        { dependent_units is needed by the invalid cycle test,
          using the program is an invalid cycle as well }
        DependentUnitList.Concat(TDependentUnit.Create(CallerModule,FromInterface));

        if CallerModule.SCCFinished then
          InternalError(2026022202);
      end;

    procedure TModule.RemoveDependency(CallerModule: TModule);
      var
        DU, NextDU: TDependentUnit;
      begin
        DU:=TDependentUnit(DependentUnitList.First);
        while Assigned(DU) do
        begin
          NextDU:=TDependentUnit(DU.Next);
          if DU.U=CallerModule then
            DependentUnitList.Remove(DU);
          DU:=NextDU;
        end;
      end;

    function TModule.HasDependency(CallerModule: TModule): Boolean;
      var
        DU: TDependentUnit;
      begin
        DU:=TDependentUnit(DependentUnitList.First);
        while Assigned(DU) do
        begin
          if DU.U=CallerModule then
            Exit(True);
          DU:=TDependentUnit(DU.Next);
        end;
        Result:=False;
      end;

    procedure TModule.FlagDependent;
      var
        DM : TDependentUnit;
        M , BM: TModule;

      begin
        { flag all units that depend on this unit for reloading }
        if not InterfaceCompiled then Exit;

        DM:=TDependentUnit(DependentUnitList.First);
        while Assigned(DM) do
        begin
          M:=DM.U;
          if M.State in [ms_compiled,ms_processed] then
          begin
            { Inconsistency: ms_compiled must only be set when all depending units (even indirect)
                are complete aka wait for crc or higher }
            WriteLn('tmodule.flagdependent ',ModuleName^,' state=',StateStr,', is used by ',BoolToStr(DM.InInterface,'interface','implementation'),' of ',M.ModuleName^,' ',M.StateStr);
            BM:=Find_Used_Unit_Compiling;
            if BM<>nil then
              WriteLn('tmodule.flagdependent ',ModuleName^,' is using (indirectly) ',BM.ModuleName^,' ',BM.StateStr)
            else
              WriteLn('tmodule.flagdependent ',ModuleName^,' is not using any incomplete unit.');
            BM:=M.Find_Used_Unit_Compiling;
            if BM<>nil then
              WriteLn('tmodule.flagdependent ',M.ModuleName^,' is using (indirectly) ',BM.ModuleName^,' ',BM.StateStr)
            else
              WriteLn('tmodule.flagdependent ',M.ModuleName^,' is not using any incomplete unit.');

            WriteUsedUnits(Self);
            WriteUsedUnits(M);

            InternalError(2026022510);
          end;
          if not M.DoReload and Is_Reload_Needed(DM) then
          begin
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tmodule.flagdependent ',ModuleName^,' state=',StateStr,', is used by ',BoolToStr(DM.InInterface,'interface','implementation'),' of ',M.ModuleName^,' ',M.StateStr);
            {$ENDIF}
            M.DoReload:=True;
            Message1(unit_u_flag_for_reload,M.ModuleName^);
            { We have to flag the units that depend on this unit even
              though it didn't change, because they might also
              indirectly depend on the unit that did change (e.g.,
              in case rgobj, rgx86 and rgcpu have been compiled
              already, and then rgobj is recompiled for some reason
              -> rgx86 is re-reresolved, but the vmtentries of trgcpu
              must also be re-resolved, because they will also contain
              pointers to procdefs in the old trgobj (in case of a
              recompile, all old defs are freed) }
            M.FlagDependent;
          end;
          DM:=TDependentUnit(DM.Next);
        end;
      end;

    function TModule.Find_Used_Unit_Compiling: TModule;

        function FindCompiling(M: TModule): TModule;
        var
          UU: TUsedUnit;
        begin
          Result:=nil;
          if M.CycleSearchStamp=TModule.Cycle_Stamp then
            Exit; // already visited
          M.CycleSearchStamp:=TModule.Cycle_Stamp;

          if M<>Self then
            if M.DoReload then
              Exit(M)
            else
              case M.State of
                ms_load:
                  if M.PPUWaitingForCRC then
                    // check used units
                  else
                    Exit(M);
                ms_compiled_waitcrc:
                  ; // check used units
                ms_compiled, ms_processed:
                  Exit;
              else
                Exit(M);
              end;

          UU:=TUsedUnit(M.UsedUnitList.First);
          while UU<>nil do
            begin
              Result:=FindCompiling(UU.U);
              if Result<>nil then Exit;
              UU:=TUsedUnit(UU.Next);
            end;
        end;

      begin
        Increase_Cycle_Stamp;
        Result:=FindCompiling(Self);
      end;

    class procedure TModule.Increase_Cycle_Stamp;
      begin
        if Cycle_Stamp=High(Integer) then
          InternalError(2026022203);
        Inc(Cycle_Stamp);
      end;

    function TModule.StateStr: string;
      begin
        Str(State,Result);
        if DoRecompile then
          Result:='do_recompile,'+Result;
        if DoReload then
          Result:='do_reload,'+Result;
      end;

    procedure TModule.CheckState;
      begin
        // Note: ms_load is checked in tppumodule.checkstate

        if InterfaceCompiled then
        begin
          if State in [ms_registered,ms_compile,ms_compiling_wait,ms_compiling_waitintf] then
          begin
            WriteLn('tmodule.checkstate ',ModuleName^,' ',StateStr,' interface_compiled=true');
            InternalError(2026021912);
          end;
        end else begin
          if State in [ms_compiling_waitimpl,ms_compiling_waitfinish,ms_compiled_waitcrc,ms_compiled,ms_processed] then
          begin
            WriteLn('tmodule.checkstate ',ModuleName^,' ',StateStr,' interface_compiled=false');
            InternalError(2026021911);
          end;
        end;

        if CRCFinal then
        begin
          if State in [ms_registered,ms_compile,ms_compiling_wait,ms_compiling_waitintf,
            ms_compiling_waitimpl,ms_compiling_waitfinish] then
          begin
            WriteLn('tmodule.checkstate ',ModuleName^,' ',StateStr,' crc_final=true');
            InternalError(2026021910);
          end;
        end else begin
          if State in [ms_compiled_waitcrc,ms_compiled,ms_processed] then
          begin
            WriteLn('tmodule.checkstate ',ModuleName^,' ',StateStr,' crc_final=false');
            InternalError(2026021909);
          end;
        end;
      end;

    procedure TModule.Disconnect_Depending_Modules;
      var
        UU: TUsedUnit;
      begin
        UU:=TUsedUnit(UsedUnitList.First);
        while Assigned(UU) do
          begin
            UU.U.RemoveDependency(Self);
            UU.DependentAdded:=False;
            UU:=TUsedUnit(UU.Next);
          end;
      end;

    function TModule.Is_Reload_Needed(DU: TDependentUnit): Boolean;
      { du.u is a module using this unit }
      begin
        Result:=(DU.U.State in [ms_compiling_waitfinish,ms_compiled_waitcrc,ms_compiled,ms_processed])
             or (DU.InInterface and DU.U.InterfaceCompiled);
        { Note: see also the override in fppu.tppumodule }
      end;

    procedure TModule.AddImportedSym(Sym: TSymEntry; CheckIfExists: Boolean);
      var
        ImportSym: TUnitImportSym;
        Module: TModule;
        ASymTable: TSymTable;
        I: Integer;
      begin
        if CheckIfExists then
        begin
          for I:=0 to UnitImportSyms.Count-1 do
            if TUnitImportSym(UnitImportSyms[I]).Sym=Sym then
              Exit;
        end;

        ASymTable:=Sym.Owner;
        Module:=Get_Module(ASymTable.ModuleID);
        if Module=nil then
        begin
          WriteLn('tmodule.find_unitimportsymbol missing moduleid=',ASymTable.ModuleID);
          InternalError(2026022622);
        end;

        if (Sym.SymID>=Module.SymList.Count) then
          InternalError(2026022617);
        if Sym<>TSymEntry(Module.SymList[Sym.SymID]) then
        begin
          WriteLn('tmodule.addimportedsym ',ModuleName^,' ',StateStr,' ',Sym.RealName,' ',Sym.SymID,' MISMATCH');
          InternalError(2026022611);
        end;

        ImportSym:=TUnitImportSym.Create;
        ImportSym.Sym:=Sym;
        ImportSym.Module:=Module;
        ImportSym.SymID:=Sym.SymID;
        UnitImportSyms.Add(ImportSym);
      end;

    procedure TModule.DerefImportedSymbols;
      var
        I: Integer;
        ImportSym: TUnitImportSym;
        Module: TModule;
      begin
        for I:=0 to UnitImportSyms.Count-1 do
          begin
            ImportSym:=TUnitImportSym(UnitImportSyms[I]);
            Module:=ImportSym.Module;
            if (ImportSym.SymID>=Module.SymList.Count) then
              InternalError(2026022618);
            ImportSym.Sym:=TSymEntry(Module.SymList[ImportSym.SymID]);
          end;
      end;

    function TModule.AddUsedUnit(HP:TModule;AInUses:Boolean;USym:TUnitSym):TUsedUnit;
      var
        PU : TUsedUnit;
      begin
        PU:=TUsedUnit.Create(HP,InInterface,AInUses,USym);
        UsedUnitList.Concat(PU);
        AddUsedUnit:=PU;
      end;

    function TModule.UsedUnitsLoaded(InterfaceUnits : Boolean; out FirstWaiting : TModule): Boolean;
      var
        UU: TUsedUnit;
        OK: Boolean;
      begin
        Result:=True;
        FirstWaiting:=nil;
        UU:=TUsedUnit(UsedUnitList.First);
        while Assigned(UU) do
        begin
          if UU.InInterface=InterfaceUnits then
          begin
            OK:=UU.U.InterfaceCompiled and not UU.U.DoReload;
            {$IFDEF DEBUG_CTASK_VERBOSE}
            WriteLn('  ',ToString,' checking state of ', UU.U.ToString,' : ',UU.U.StateStr,' : ',OK);
            UU.U.CheckState;
            {$ENDIF}
            if not OK then
            begin
              Result:=False;
              FirstWaiting:=UU.U;
              {$IFNDEF DEBUG_CTASK_VERBOSE}
              Break;
              {$ENDIF}
            end;
          end;
          UU:=TUsedUnit(UU.Next);
        end;
      end;

    function TModule.NoWaitingForUnits(out FirstWaiting : TModule): Boolean;

      begin
        FirstWaiting:=nil;
        Result:=WaitingForUnit.Count=0;
        If not Result then
          FirstWaiting:=TModule(WaitingForUnit[0]);
      end;

    function TModule.UsedUnitsFinalCRC(out FirstWaiting: TModule): Boolean;
      { return a used unit, that has not yet computed its crc }

      begin
        FirstWaiting:=SCCTreeCRCWait;
        Result:=FirstWaiting=nil;
      end;

    function TModule.UsesModule_In_Interface(M: TModule): Boolean;

      var
        U : TUsedUnit;

      begin
        Result:=False;
        U:=TUsedUnit(UsedUnitList.First);
        while Assigned(U) do
          begin
          if (U.U=M) then
            Exit(U.InInterface) ;
          U:=TUsedUnit(U.Next);
          end;
      end;

    function TModule.FindUsedUnit(M: TModule): TUsedUnit;
      var
        U : TUsedUnit;

      begin
        Result:=nil;
        U:=TUsedUnit(UsedUnitList.First);
        while Assigned(U) do
          begin
          if U.U=M then
            Exit(U);
          U:=TUsedUnit(U.Next);
          end;
      end;

    procedure TModule.UpdateMaps;
      var
        OldMapSize : LongInt;
        HP  : TModule;
        I   : LongInt;
      begin
        { Extend unitmap }
        OldMapSize:=UnitMapSize;
        UnitMapSize:=Loaded_Units.Count+1;
        SetLength(UnitMap,UnitMapSize);

        { Extend Derefmap }
        OldMapSize:=DerefMapSize;
        DerefMapSize:=Loaded_Units.Count+1;
        SetLength(DerefMap,DerefMapSize);
        { Add all units to unitmap }
        HP:=TModule(Loaded_Units.First);
        if HP=nil then Exit;
        I:=HP.ModuleID;
        while Assigned(HP) do
          begin
            if HP.ModuleID>=UnitMapSize then
              InternalError(2005011513);
            { Verify old entries }
            if (I<OldMapSize) then
              begin
                if (HP.ModuleID<>I) or
                   (UnitMap[HP.ModuleID].U<>HP) then
                  InternalError(200501156);
              end
            else
              begin
                UnitMap[HP.ModuleID].U:=HP;
                UnitMap[HP.ModuleID].DerefIdx:=-1;
              end;
            Inc(I);
            HP:=TModule(HP.Next);
          end;
      end;



    function TModule.DerefIdx_Unit(ID:LongInt):LongInt;
      begin
        if ID>=UnitMapSize then
          InternalError(2005011511);
        if UnitMap[ID].DerefIdx=-1 then
          begin
            UnitMap[ID].DerefIdx:=DerefMapCnt;
            Inc(DerefMapCnt);
            DerefMap[UnitMap[ID].DerefIdx].U:=UnitMap[ID].U;
          end;
        if UnitMap[ID].DerefIdx>=DerefMapSize then
          InternalError(2005011514);
        Result:=UnitMap[ID].DerefIdx;
      end;


    function TModule.Resolve_Unit(ID:LongInt):TModule;
      var
        HP : TModule;
      begin
        if ID>=DerefMapSize then
          begin
            WriteLn('tmodule.resolve_unit ',ModuleName^,' ',StateStr,' id=',ID,' derefmapsize=',DerefMapSize);
            InternalError(200306231);
          end;
        Result:=DerefMap[ID].U;
        if not Assigned(Result) then
          begin
            if not Assigned(DerefMap[ID].ModuleName) or
               (DerefMap[ID].ModuleName^='') then
              InternalError(200501159);
            HP:=TModule(Loaded_Units.First);
            while Assigned(HP) do
              begin
                { only check for units. The main program is also
                  as a unit in the loaded_units list. We simply need
                  to ignore this entry (PFV) }
                if HP.IsUnit and
                   (HP.ModuleName^=DerefMap[ID].ModuleName^) then
                  Break;
                HP:=TModule(HP.Next);
              end;
            if not Assigned(HP) then
              InternalError(2005011510);
            DerefMap[ID].U:=HP;
            Result:=HP;
          end;
      end;


    procedure TModule.AllUnitsUsed;
      var
        PU : TUsedUnit;
      begin
        PU:=TUsedUnit(UsedUnitList.First);
        while Assigned(PU) do
          begin
            if Assigned(PU.U.GlobalSymTable) then
              begin
                if UnitMap[PU.U.ModuleID].U<>PU.U then
                  InternalError(200501157);
                { Give a note when the unit is not referenced, skip
                  this is for units with an initialization/finalization }
                if (UnitMap[PU.U.ModuleID].Refs=0) and
                   PU.InUses and
                   ((PU.U.ModuleFlags * [mf_init,mf_finalize])=[]) then
                  CGMessagePos2(PU.UnitSym.FileInfo,sym_n_unit_not_used,PU.U.RealModuleName^,RealModuleName^);
              end;
            PU:=TUsedUnit(PU.Next);
          end;
      end;

    procedure TModule.End_Of_Parsing;
      begin
        { free asmdata }
        if Assigned(AsmData) then
          begin
            AsmData.Free;
            AsmData:=nil;
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
            SymTableStack.Free;
            SymTableStack:=nil;
          end;
        if Assigned(MacroSymTableStack) then
          begin
            MacroSymTableStack.Free;
            MacroSymTableStack:=nil;
          end;
        WaitingForUnit.Free;
        WaitingForUnit:=nil;
        LocalMacroSymTable.Free;
        LocalMacroSymTable:=nil;
        PtrDefs.Free;
        PtrDefs:=nil;
        ArrayDefs.Free;
        ArrayDefs:=nil;
        ProcAddrDefs.Free;
        ProcAddrDefs:=nil;

        CheckForwardDefs.Free;
        CheckForwardDefs:=nil;
        TCInitCode.Free;
        TCInitCode:=nil;
        LocalUnitSearchPath.Free;
        LocalUnitSearchPath:=nil;
        LocalObjectSearchPath.Free;
        LocalObjectSearchPath:=nil;
        LocalIncludeSearchPath.Free;
        LocalIncludeSearchPath:=nil;
        LocalLibrarySearchPath.Free;
        LocalLibrarySearchPath:=nil;
        LocalFrameworkSearchPath.Free;
        LocalFrameworkSearchPath:=nil;
      end;


    procedure TModule.SetModuleName(const S:string);
      begin
        StringDispose(ModuleName);
        StringDispose(RealModuleName);
        ModuleName:=StringDup(Upper(S));
        RealModuleName:=StringDup(S);
        { also update asmlibrary names }
        CurrentAsmData.Name:=ModuleName;
      end;


    procedure TModule.AddExternalImport(const LibName, SymName, SymMangledName: string; OrdNr: LongInt; IsVar: Boolean;
      ImportByOrdinalOnly: Boolean);
      var
        ImportLibrary,OtherIL : TImportLibrary;
        ImportSymbol  : TImportSymbol;
        I : LongInt;
      begin
        ImportLibrary:=TImportLibrary(ImportLibraryList.Find(LibName));
        if not Assigned(ImportLibrary) then
          ImportLibrary:=TImportLibrary.Create(ImportLibraryList,LibName);
        ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList.Find(SymName));
        if not Assigned(ImportSymbol) then
          begin
            { Check that the same name does not exist in another library }
            { If it does and the same mangled name is used, issue a warning }
            if ImportLibraryList.Count>1 then
              for I:=0 To ImportLibraryList.Count-1 do
                begin
                  OtherIL:=TImportLibrary(ImportLibraryList.Items[I]);
                  ImportSymbol:=TImportSymbol(OtherIL.ImportSymbolList.Find(SymName));
                  if Assigned(ImportSymbol) then
                    begin
                      if ImportSymbol.MangledName=SymMangledName then
                        begin
                          CGMessage3(sym_w_library_overload,SymName,LibName,OtherIL.Name);
                          Break;
                        end;
                    end;
                end;
            if not ImportByOrdinalOnly then
              { negative ordinal number indicates import by name with ordinal number as hint }
              OrdNr:=-OrdNr;
            ImportSymbol:=TImportSymbol.Create(ImportLibrary.ImportSymbolList,
              SymName,SymMangledName,OrdNr,IsVar);
          end;
      end;


    procedure TModule.Add_Public_AsmSym(Sym:TAsmSymbol);
      begin
        Add_Public_AsmSym(Sym.Name,Sym.Bind,Sym.Typ);
      end;


    procedure TModule.Add_Public_AsmSym(const Name:TSymStr;Bind:TAsmsymbind;Typ:TAsmsymtype);
      var
        Sym : TAsmSymbol;
      begin
        { ToDo: check for AB_GLOBAL, AB_EXTERNAL? }
        Sym:=TAsmSymbol(PublicAsmSyms.Find(Name));
        if Assigned(Sym) then
          begin
            if (Sym.Bind<>Bind) or (Sym.Typ<>Typ) then
              InternalError(2016070101);
            Exit;
          end;
        TAsmSymbol.Create(PublicAsmSyms,Name,Bind,Typ);
      end;


    procedure TModule.Add_Extern_AsmSym(Sym:TAsmSymbol);
      begin
        Add_Extern_AsmSym(Sym.Name,Sym.Bind,Sym.Typ);
      end;


    procedure TModule.Add_Extern_AsmSym(const Name:TSymStr;Bind:TAsmsymbind;Typ:TAsmsymtype);
      var
        Sym : TAsmSymbol;
      begin
        { ToDo: check for AB_EXTERNAL? }
        Sym:=TAsmSymbol(ExternAsmSyms.Find(Name));
        if Assigned(Sym) then
          begin
            if (Sym.Bind<>Bind) or (Sym.Typ<>Typ) then
              InternalError(2016070102);
            Exit;
          end;
        TAsmSymbol.Create(ExternAsmSyms,Name,Bind,Typ);
      end;

    procedure TModule.Remove_WaitForUnit_Cycles;

        function Search(M: TModule): Boolean;
        var
          I: Integer;
        begin
          Result:=False;
          if M=Self then Exit(True);
          if M.CycleSearchStamp=TModule.Cycle_Stamp then Exit;
          M.CycleSearchStamp:=TModule.Cycle_Stamp;
          if not Assigned(M.WaitingUnits) then Exit;
          for I:=M.WaitingUnits.Count-1 downto 0 do
            if Search(TModule(M.WaitingUnits[I])) then
              Exit(True);
        end;

      var
        WaitingModule: TModule;
        I: Integer;
      begin
        if not Assigned(WaitingUnits) then Exit;
        TModule.Increase_Cycle_Stamp;
        for I:=WaitingUnits.Count-1 downto 0 do
          begin
            WaitingModule:=TModule(WaitingUnits[I]);
            if Search(WaitingModule) then
              begin
                WaitingUnits.Delete(I);
                WaitingModule.Remove_From_WaitingForUnits(Self);
                TModule.Increase_Cycle_Stamp;
              end;
          end;
      end;

    procedure TModule.Remove_All_WaitsForThisUnit;
      var
        I: Integer;
        WaitingModule: TModule;
      begin
        if not Assigned(WaitingUnits) then Exit;
        for I:=0 to WaitingUnits.Count-1 do
          begin
            WaitingModule:=TModule(WaitingUnits[I]);
            WaitingModule.Remove_From_WaitingForUnits(Self);
          end;
        WaitingUnits.Clear;
      end;

    procedure TModule.Remove_From_WaitingForUnits(AModule: TModule);
    begin
      // It can be nil after when this is called after end_of_parsing was called.
      if Assigned(WaitingForUnit) then
        WaitingForUnit.Remove(AModule);
    end;

    function TModule.ToString: RTLString;
      begin
        // Assigned self so we can detect nil.
        if Assigned(ModuleName) then
          Result:='('+ModuleName^+')'
        else
         Result:='(<'+IntToStr(PtrInt(Self))+'>)';
        // Possibly add some state ?
      end;

    procedure TModule.WriteUsedUnits(M: TModule);
    var
      UU: TUsedUnit;
    begin
      if M=nil then Exit;
      WriteLn('tmodule.WriteUsedUnits ',M.ModuleName^,' ',M.StateStr);
      WriteLn('  interface uses:');
      UU:=TUsedUnit(M.UsedUnitList.First);
      while Assigned(UU) do
        begin
          if UU.InInterface then
            WriteLn('  ',UU.U.ModuleName^,' ',UU.U.StateStr);
          UU:=TUsedUnit(UU.Next);
        end;
      WriteLn('  implementation uses:');
      UU:=TUsedUnit(M.UsedUnitList.First);
      while Assigned(UU) do
        begin
          if not UU.InInterface then
            WriteLn('  ',UU.U.ModuleName^,' ',UU.U.StateStr);
          UU:=TUsedUnit(UU.Next);
        end;
    end;


initialization
{$ifdef MEMDEBUG}
  MemSymTable:=TMemDebug.Create('Symtables');
  MemSymTable.Stop;
{$endif MEMDEBUG}

finalization
{$ifdef MEMDEBUG}
  MemSymTable.Free;
  MemSymTable := nil;
{$endif MEMDEBUG}

end.
