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
      SymBase,PPU,SymType;

    type
       { tppumodule }
       TAvailableUnitFile = (auPPU,auSrc);
       TAvailableUnitFiles = set of TAvailableUnitFile;

       TPPUModule = class(TModule)
          PPUFile    : TCompilerPPUFile; { the PPU file }
          SourceFN   : TPathStr; { Source specified with "uses .. in '..'" }
          Comments   : TCmdStrList;
          NSPrefix   : TCmdStr; { Namespace prefix the unit was found with }
          constructor Create(LoadedFrom:TModule;const AModuleName: string; const AFileName:TPathStr;AIsUnit:Boolean);
          destructor Destroy;override;
          function StateStr: string; override;
          procedure CheckState; override;
          procedure Reset(ForRecompile: Boolean);override;
          procedure Re_Resolve;
          function  OpenPPUFile:Boolean;
          function  OpenPPUStream(Strm:TCStream):Boolean;
          procedure GetPPUCRC;
          function Dependent_Module_Has_Our_CRC: Boolean;
          function Dependent_Module_CRC_Mismatch: Boolean;
          procedure WritePPU;
          function LoadPPU(FromModule : TModule) : Boolean;
          function Get_Check_Uses(out CheckImplUses, CheckCRC: Boolean): Boolean;
          function ContinueLoadPPU : Boolean;
          function CanReload(out FirstWaiting: TModule; IgnoreDoReload: Boolean): Boolean;
          procedure Reload;
          function PPULoadCanContinue(out FirstWaiting: TModule): Boolean;
          function Is_Reload_Needed(Pu: TDependentUnit): Boolean; override;
          procedure Restore_State;
          procedure Store_State;
          procedure Recompile_From_Sources;
          procedure Check_Sources_For_Recompile;
          procedure Post_Load_Or_Compile(FromModule : TModule);
          procedure DiscardPPU;
          procedure SetDefGeneration;
          procedure End_Of_Parsing;override;
       private
          PackagePPUStream : TCStream; { owned while a package PPU is loaded }
          UnitImportSymsDerefs : TFPList;
         { Each time a unit's defs are (re)created, its defsgeneration is
           set to the value of a global counter, and the global counter is
           increased. We only reresolve its dependent units' defs in case
           they have been resolved only for an older generation, in order to
           avoid endless resolving loops in case of cyclic dependencies. }
          DefsGeneration : LongInt;
          StoredState: TGlobalState;

          function CheckLoadFromPackage: Boolean;
          function  OpenPPU(PPUFileTime:LongInt):Boolean;
          procedure MarkRecompileNeeded(Reason: TRecompileReason);
          function  SearchUnitFiles(LoadingModule : TModule; OnlySource:Boolean):TAvailableUnitFiles;
          function  SearchUnit(LoadingModule : TModule; OnlySource,ShortName:Boolean):TAvailableUnitFiles;
          function  LoadFromPackage:Boolean;
          procedure LoadInterface;
          procedure LoadImplementation;
          function LoadUsedUnits: Boolean;
          function LoadUsedUnitsSection: Boolean;
          function PPUCheckUsedCRCs: Boolean;
          procedure PrintComments;
          procedure QueueComment(const S:TMsgStr;V,W:LongInt);
          procedure BuildDerefUnitImportSyms;
          procedure DerefUnitImportSyms;
          procedure FreeDerefUnitImportSyms;
          procedure WriteSourceFiles;
          procedure WriteUsedUnit(Intf:Boolean);
          procedure WriteLinkContainer(var P:TLinkContainer;ID:Byte;StripPath:Boolean);
          procedure WriteDerefMap;
          procedure WriteDerefData;
          procedure WriteImportSymbols;
          procedure WriteResources;
          procedure WriteOrderedSymbols;
          procedure WriteUnitExports;
          procedure WriteUnitImportSyms;
          procedure WriteAsmSyms(Kind:TUnitAsmListType;List:TFPHashObjectList);
          procedure WriteExtraHeader;
          procedure ReadSourceFiles;
          procedure ReadLoadUnit;
          procedure ReadLinkContainer(var P:TLinkContainer);
          procedure ReadDerefMap;
          procedure ReadDerefData;
          procedure ReadImportSymbols;
          procedure ReadResources;
          procedure ReadOrderedSymbols;
          procedure ReadUnitExports;
          procedure ReadWPOFile;
          procedure ReadUnitImportSyms;
          procedure ReadAsmSyms;
          procedure ReadExtraHeader;
{$IFDEF MACRO_DIFF_HINT}
          procedure WriteUsedMacro(P:TNamedIndexItem;Arg:Pointer);
          procedure WriteUsedMacros;
          procedure ReadUsedMacros;
{$ENDIF}
       end;

    function RegisterUnit(CallerModule:TModule;const S : TIDString;const FN:string; out IsNewUnit:Boolean) : TPPUModule;


implementation

uses
  SysUtils,
  CFileUtl,
  Systems,Version,Options,
  SymTable, SymSym,
  WPOInfo,
  Scanner,
  AAsmBase,AAsmData,Ogbase,
  CompHook,
  EntFile,FPkg,FPCP,Export;


var
  CurrentDefGeneration: LongInt;

{****************************************************************************
                                TPPUMODULE
 ****************************************************************************}

    constructor TPPUModule.Create(LoadedFrom:TModule;const AModuleName: string; const AFileName:TPathStr;AIsUnit:Boolean);
      begin
        inherited Create(LoadedFrom,AModuleName,AFileName,AIsUnit);
        PPUFile:=nil;
        SourceFN:=AFileName;
        UnitImportSymsDerefs:=TFPList.Create;
      end;


    destructor TPPUModule.Destroy;
      begin
        DiscardPPU;
        Comments.Free;
        Comments:=nil;
        { all derefs allocated with new
          are dispose'd inside this method }
        FreeDerefUnitImportSyms;
        UnitImportSymsDerefs.Free;
        UnitImportSymsDerefs:=nil;
        inherited Destroy;
      end;

    function TPPUModule.StateStr: string;
      begin
        Result:=inherited StateStr;
        if State<>ms_load then Exit;
        if PPUWaitingForCRC then
          Result:=Result+',waitcrc'
        else if InterfaceCompiled then
          Result:=Result+',interface_compiled'
        else
          Result:=Result+',waitintf';
      end;

    procedure TPPUModule.CheckState;
      begin
        if State=ms_load then

        else
          inherited CheckState;
      end;

    procedure TPPUModule.Reset(ForRecompile : Boolean);
      begin
        LoadedFromModule:=nil;
        PPUWaitingForCRC:=False;
        DiscardPPU;
        FreeDerefUnitImportSyms;
        UnitImportSymsDerefs.Free;
        UnitImportSymsDerefs:=TFPList.Create;
        inherited Reset(ForRecompile);
      end;

    procedure TPPUModule.Re_Resolve;

      begin
        Message1(unit_u_reresolving_unit,ModuleName^);
        if TStoredSymTable(GlobalSymTable).Is_Deref_Built then
          TStoredSymTable(GlobalSymTable).Deref(False);
        if TStoredSymTable(GlobalSymTable).Is_DerefImpl_Built then
          TStoredSymTable(GlobalSymTable).DerefImpl(False);
        if Assigned(LocalSymTable) then
          begin
            { we have only builderef(impl)'d the registered symbols of
              the localsymtable -> also only deref those again }
            if TStoredSymTable(LocalSymTable).Is_Deref_Built then
              TStoredSymTable(LocalSymTable).Deref(True);
            if TStoredSymTable(LocalSymTable).Is_DerefImpl_Built then
              TStoredSymTable(LocalSymTable).DerefImpl(True);
          end;
        DerefImportedSymbols;
        if Assigned(WPOInfo) then
          begin
            TUnitWPOInfo(WPOInfo).Deref;
            TUnitWPOInfo(WPOInfo).DerefImpl;
          end;

        { all dependent units were already flagged recursively for reload }
        DefsGeneration:=CurrentDefGeneration;
      end;


    procedure TPPUModule.QueueComment(const S:TMsgStr;V,W:LongInt);
    begin
      if Comments = nil then
        Comments := TCmdStrList.Create;
      Comments.Insert(S);
    end;

    procedure TPPUModule.PrintComments;
    var
      Comment: string;
    begin
      if Comments = nil then
        Exit;
      { comments are inserted in reverse order }
      repeat
        Comment := Comments.GetLast;
        if Length(Comment) = 0 then
          Exit;
        Do_Comment(VNormal, Comment);
      until False;
    end;

    function TPPUModule.OpenPPUFile:Boolean;
      var
        PPUFileTime : LongInt;
      begin
        OpenPPUFile:=False;
        Message1(unit_t_ppu_loading,PPUFileName,@QueueComment);
      { Get ppufile time (also check if the file exists) }
        PPUFileTime:=GetNamedFileTime(PPUFileName);
        if PPUFileTime=-1 then
         Exit;
      { Open the ppufile }
        Message1(unit_u_ppu_name,PPUFileName);
        PPUFile:=TCompilerPPUFile.Create(PPUFileName);
        if not PPUFile.OpenFile then
         begin
           DiscardPPU;
           Message(unit_u_ppu_file_too_short);
           Exit;
         end;
        Result:=OpenPPU(PPUFileTime);
      end;


    function TPPUModule.OpenPPUStream(Strm:TCStream):Boolean;
      begin
        Result:=False;
      { Open the ppufile }
        Message1(unit_u_ppu_name,PPUFileName);
        PPUFile:=TCompilerPPUFile.Create(PPUFileName);
        if not PPUFile.OpenStream(Strm) then
         begin
           DiscardPPU;
           Message(unit_u_ppu_file_too_short);
           Exit;
         end;
        Result:=OpenPPU(-1);
      end;


    function TPPUModule.OpenPPU(PPUFileTime:LongInt):Boolean;

      function CheckHeader: Boolean;
        var
          Psi: PSystemInfo;
          system_name: ShortString;
        begin
          Result:=False;
          { check for a valid PPU file }
            if not PPUFile.CheckPPUId then
             begin
               Message(unit_u_ppu_invalid_header,@QueueComment);
               Exit;
             end;
          { check for allowed PPU versions }
            if not (PPUFile.GetVersion = CurrentPPUVersion) then
             begin
               Message2(unit_u_ppu_invalid_version,ToStr(PPUFile.GetVersion),ToStr(CurrentPPUVersion),@QueueComment);
               Exit;
             end;
          { check the target processor }
            if TSystemCPU(PPUFile.Header.Common.CPU)<>TargetCPU then
             begin
               Message1(unit_u_ppu_invalid_processor,CPU2Str[Ord(TSystemCPU(PPUFile.Header.Common.CPU))],@QueueComment);
               Exit;
             end;
          { check target }
            if TSystem(PPUFile.Header.Common.Target)<>TargetInfo.System then
             begin
               Psi:=TargetInfos[Ord(TSystem(PPUFile.Header.Common.Target))];
               if Assigned(Psi) then
                 system_name:=Psi^.ShortName
               else
                 system_name:='invalid ('+ToStr(PPUFile.Header.Common.Target)+')';
               Message1(unit_u_ppu_invalid_target,system_name,@QueueComment);
               Exit;
             end;
           Result:=True;
        end;

      function CheckExtraHeader: Boolean;
        begin
          Result:=False;
          if PPUFile.ReadEntry<>IBExtraHeader then
            begin
              Message(unit_u_ppu_invalid_header);
              Exit;
            end;
          ReadExtraHeader;
          if (LongVersion<>CurrentPPULongVersion) or
             not PPUFile.EndOfEntry then
            begin
              Message2(unit_u_ppu_invalid_long_version,ToStr(LongVersion),ToStr(CurrentPPULongVersion),@QueueComment);
              Exit;
            end;

          if {$ifdef symansistr}not{$endif}(mf_symansistr in ModuleFlags) then
            begin
              Message(unit_u_ppu_symansistr_mismatch,@QueueComment);
              Exit;
            end;
           { Every unit, including released RTL/package units, must match the
             compiler invocation's default text model. }
           if (mf_unicode_default in ModuleFlags) <> CompilerWide_Unicode_Strings then
             begin
               Comment(VNormal,
                 'PPU default text model does not match this compiler invocation');
               Exit;
             end;
          { A profiling build may use an ordinary PPU, producing deliberately
            gapped coverage. An ordinary build must never reuse an instrumented
            PPU because that would retain profiler hooks. }
          if (ModuleName^<>'SYSINIT') and
             (ModuleName^<>'OBJPAS') and
             not(mf_release in ModuleFlags) and
             not(mf_system_unit in ModuleFlags) and
             (mf_nexus_profile in ModuleFlags) and
             not(cs_nexus_profile in CurrentSettings.ModuleSwitches) then
            begin
              Comment(VNormal,
                'PPU profiling state does not match the current Nexus profiling build');
              Exit;
            end;
          Result:=True;
        end;

      begin
        OpenPPU:=False;
        if not CheckHeader or
           not CheckExtraHeader then
          begin
            DiscardPPU;
            Exit;
          end;

      { Load values for easier access }
        HeaderFlags:=PPUFile.Header.Common.Flags;
        CRC:=PPUFile.Header.Checksum;
        CRCFinal:=True;
        InterfaceCRC:=PPUFile.Header.InterfaceChecksum;
        IndirectCRC:=PPUFile.Header.IndirectChecksum;
        ChangeEndian:=PPUFile.ChangeEndian;
      { Show Debug info }
        if PPUFileTime<>-1 then
          Message1(unit_u_ppu_time,FileTimeString(PPUFileTime))
        else
          Message1(unit_u_ppu_time,'unknown');
        Message1(unit_u_ppu_flags,ToStr(HeaderFlags));
        Message1(unit_u_ppu_crc,HexStr(PPUFile.Header.Checksum,8));
        Message1(unit_u_ppu_crc,HexStr(PPUFile.Header.InterfaceChecksum,8)+' (intfc)');
        Message1(unit_u_ppu_crc,HexStr(PPUFile.Header.IndirectChecksum,8)+' (indc)');
        Comment(VUsed,'Number of definitions: '+ToStr(PPUFile.Header.DefListSize));
        Comment(VUsed,'Number of symbols: '+ToStr(PPUFile.Header.SymListSize));
        OpenPPU:=True;
      end;


    function TPPUModule.SearchUnitFiles(LoadingModule : TModule; OnlySource:Boolean):TAvailableUnitFiles;
      var
        Found : TAvailableUnitFiles;
      begin
        Found:=SearchUnit(LoadingModule,OnlySource,False);
        if (Found=[]) and
           (Ft83 in AllowedFilenameTransFormations) and
           (Length(ModuleName^)>8) then
           Found:=SearchUnit(LoadingModule,OnlySource,True);
        SearchUnitFiles:=Found;
      end;

    function TPPUModule.SearchUnit(LoadingModule : TModule; OnlySource,ShortName:Boolean):TAvailableUnitFiles;
      var
         SinglePathString,
         FileName : TCmdStr;

         Function UnitExists(const Ext:string;var FoundFile:TCmdStr;const Prefix:TCmdStr):Boolean;
         var
           S : TCmdStr;
         begin
           if CheckVerbosity(VTried) then
             Message1(unit_t_unitsearch,SinglePathString+FileName+Ext);
           S:=FileName+Ext;
           if Prefix<>'' then
             S:=Prefix+'.'+S;
           UnitExists:=FindFile(S,SinglePathString,True,FoundFile);
         end;

         Function PPUSearchPath(const S,Prefix:TCmdStr):Boolean;
         var
           Found : Boolean;
           HS,
           NewName : TCmdStr;
         begin
           Found:=False;
           SinglePathString:=FixPath(S,False);
         { Check for PPU file }
           Found:=UnitExists(TargetInfo.UnitExt,HS,Prefix);
           if Found then
            Begin
              SetFileName(HS,False);
              if Prefix<>'' then
                begin
                  NewName:=Prefix+'.'+RealModuleName^;
                  StringDispose(RealModuleName);
                  RealModuleName:=StringDup(NewName);
                  StringDispose(ModuleName);
                  ModuleName:=StringDup(Upper(NewName));
                end;
              Found:=OpenPPUFile;
            End;
           PPUSearchPath:=Found;
         end;

         Function SourceSearchPath(const S,Prefix:TCmdStr):Boolean;
         var
           Found   : Boolean;
           HS,
           NewName : TCmdStr;
         begin
           Found:=False;
           SinglePathString:=FixPath(S,False);
         { Check for Sources }
           PPUFile:=nil;
           RecompileReason:=rr_noppu;
         { Check for Pascal source }
           Found:=UnitExists(SourceExt,HS,Prefix);
           if not Found and
              ((m_mac in CurrentSettings.ModeSwitches) or
               (tf_p_ext_support in TargetInfo.Flags)) then
            begin
              { Check for .p, if mode is macpas}
              Found:=UnitExists(PExt,HS,Prefix);
            end;
           MainSource:='';
           if Found then
            begin
              SourcesAvail:=True;
              { Load Filenames when found }
              MainSource:=HS;
              SetFileName(HS,False);
              if Prefix<>'' then
                begin
                  NewName:=Prefix+'.'+RealModuleName^;
                  StringDispose(RealModuleName);
                  RealModuleName:=StringDup(NewName);
                  StringDispose(ModuleName);
                  ModuleName:=StringDup(Upper(NewName));
                end;
            end
           else
            SourcesAvail:=False;
           SourceSearchPath:=Found;
         end;

         Function SearchPath(const S,Prefix:TCmdStr):TAvailableUnitFiles;
         var
           Found : TAvailableUnitFiles;
         begin
           { First check for a ppu, then for the source }
           Found:=[];
           if not OnlySource then
             if PPUSearchPath(S,Prefix) then
               Include(Found,auPPU);
           if Found=[] then
             if SourceSearchPath(S,Prefix) then
              Include(Found,auSrc);
           SearchPath:=Found;
         end;

         Function SearchPathList(List:TSearchPathList;const Prefix:TCmdStr):TAvailableUnitFiles;
         var
           HP : TCmdStrListItem;
           Found : TAvailableUnitFiles;
         begin
           Found:=[];
           HP:=TCmdStrListItem(List.First);
           while Assigned(HP) do
            begin
              Found:=SearchPath(HP.Str,Prefix);
              if Found<>[] then
               Break;
              HP:=TCmdStrListItem(HP.Next);
            end;
           SearchPathList:=Found;
         end;

         function SearchPPUPaths(const Prefix:TCmdStr):Boolean;
         begin
           Result:=PPUSearchPath('.',Prefix);
           if (not Result) and (OutputPath<>'') then
            Result:=PPUSearchPath(OutputPath,Prefix);
           if (not Result) and Assigned(Main_Module) and (Main_Module.Path<>'')  then
            Result:=PPUSearchPath(Main_Module.Path,Prefix);
         end;

         function SearchSourcePaths(const Prefix:TCmdStr):TAvailableUnitFiles;
         begin
           Result:=[];
           if SourceSearchPath('.',Prefix) then
              Include(Result,auSrc);
           if (Result=[]) and Assigned(Main_Module) and (Main_Module.Path<>'') then
             if SourceSearchPath(Main_Module.Path,Prefix) then
              Include(Result,auSrc);
           if (Result=[]) and Assigned(LoadingModule) then
             Result:=SearchPathList(LoadingModule.LocalUnitSearchPath,Prefix);
           if (Result=[]) then
             Result:=SearchPathList(UnitSearchPath,Prefix);
         end;

         function SearchNamespaceList(const Prefixes:TCmdStrList): TAvailableUnitFiles;
         var
           NSItem : TCmdStrListItem;
           Res : TAvailableUnitFiles;
         begin
           Res:=[];
           NSItem:=TCmdStrListItem(Prefixes.First);
           while Assigned(NSItem) do
             begin
               if not OnlySource then
                 begin
                   if SearchPPUPaths(NSItem.Str) then
                     Include(Res,auPPU);
                   if Res<>[] then
                     Break;
                 end;
               Res:=SearchSourcePaths(NSItem.Str);
               if Res<>[] then
                 Break;
               NSItem:=TCmdStrListItem(NSItem.Next);
             end;
           if Assigned(NSItem) then
             NSPrefix:=NSItem.Str;
           Result:=Res;
         end;


       var
         Fnd : TAvailableUnitFiles;
         HS : TPathStr;
       begin
         Fnd:=[];
         if ShortName then
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
         if not OnlySource then
           if SearchPPUPaths('') then
             Include(Fnd,auPPU);
         if (Fnd=[]) and (SourceFN<>'') then
          begin
            { the full filename is specified so we can't use here the
              searchpath (PFV) }
            if CheckVerbosity(VTried) then
              Message1(unit_t_unitsearch,ChangeFileExt(SourceFN,SourceExt));
            if FindFile(ChangeFileExt(SourceFN,SourceExt),'',True,HS) then
              Include(Fnd,auSrc);
            if (Fnd=[]) and
               ((m_mac in CurrentSettings.ModeSwitches) or
                (tf_p_ext_support in TargetInfo.Flags)) then
             begin
               if CheckVerbosity(VTried) then
                 Message1(unit_t_unitsearch,ChangeFileExt(SourceFN,PExt));
               if FindFile(ChangeFileExt(SourceFN,PExt),'',True,HS) then
                Include(Fnd,auSrc)
             end;
            if [auSrc]=Fnd then
             begin
               SourcesAvail:=True;
               {$IFDEF DEBUG_PPU_CYCLES}
               WriteLn('PPUALGO tppumodule.search_unit only sources, no ppu -> ',ModuleName^,' old=',State,' new=',ms_compile);
               {$ENDIF}
               State:=ms_compile;
               RecompileReason:=rr_noppu;
               MainSource:=HS;
               SetFileName(HS,False);
             end;
          end;
         if Fnd=[] then
           begin
             Fnd:=SearchSourcePaths('');
             // current_namespacelist is set to the current module's namespacelist.
             if (Fnd=[]) and Assigned(CurrentNamespaceList) and (CurrentNamespaceList.Count>0) then
               Fnd:=SearchNameSpaceList(CurrentNamespaceList);
             if (Fnd=[]) and (NamespaceList.Count>0) then
               Fnd:=SearchNameSpaceList(NamespaceList);
           end;
         SearchUnit:=Fnd;
      end;

    function TPPUModule.LoadFromPackage: Boolean;
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
        Pkg : PPackageEntry;
        PkgUnit : PContainedUnit;
        I,Idx : LongInt;
      begin
        Result:=False;
        for I:=0 to PackageList.Count-1 do
          begin
            Pkg:=PPackageEntry(PackageList[I]);
            if not Assigned(Pkg^.Package) then
              InternalError(2013053103);
            Idx:=Pkg^.Package.ContainedModules.FindIndexOf(ModuleName^);
            if Idx>=0 then
              begin
                { the unit is part of this package }
                PkgUnit:=PContainedUnit(Pkg^.Package.ContainedModules[Idx]);
                if not Assigned(PkgUnit^.Module) then
                  PkgUnit^.Module:=Self;
                { ToDo: check whether we really don't need this anymore }
                {filename:=pkgunit^.ppufile;
                if not SearchPathList(unitsearchpath) then
                  exit};
                PackagePPUStream:=TPCPPackage(Pkg^.Package).GetModuleStream(Self);
                if not Assigned(PackagePPUStream) then
                  InternalError(2015103002);
                if not OpenPPUStream(PackagePPUStream) then
                  Exit;
                Package:=Pkg^.Package;
                Message2(unit_u_loading_from_package,ModuleName^,Pkg^.Package.PackageName^);

                { Package PPUs use the same resumable dependency loading as
                  ordinary PPUs. Dependencies need not be ready yet. }
                State:=ms_load;
                FromPPU:=True;
                LoadInterface;

                Result:=True;
                Break;
              end;
          end;
      end;


    procedure TPPUModule.BuildDerefUnitImportSyms;
      { called by writeppu }
      var
        I : LongInt;
        Deref : PDeref;
        ImportSym: TUnitImportSym;
      begin
        UnitImportSymsDerefs.Capacity:=UnitImportSymsDerefs.Count+UnitImportSyms.Count;
        for I:=0 to UnitImportSyms.Count-1 do
          begin
            ImportSym:=TUnitImportSym(UnitImportSyms[I]);
            New(Deref);
            Deref^.Build(ImportSym.Sym);
            UnitImportSymsDerefs.Add(Deref);
          end;
      end;


    procedure TPPUModule.DerefUnitImportSyms;
      { called at end of loading a ppu }
      var
        I : LongInt;
        Sym : TSym;
      begin
        UnitImportSyms.Capacity:=UnitImportSyms.Count+UnitImportSymsDerefs.Count;
        for I:=0 to UnitImportSymsDerefs.Count-1 do
          begin
            Sym:=TSym(PDeref(UnitImportSymsDerefs[I])^.Resolve);
            AddImportedSym(Sym,False);
          end;
      end;

    procedure TPPUModule.FreeDerefUnitImportSyms;
      var
        I : LongInt;
        Deref : PDeref;
      begin
        for I:=0 to UnitImportSymsDerefs.Count-1 do
          begin
            Deref:=PDeref(UnitImportSymsDerefs[I]);
            System.Dispose(Deref);
          end;
      end;

{**********************************
    PPU Reading/Writing Helpers
***********************************}

{$IFDEF MACRO_DIFF_HINT}
    var
      IsInitial: Boolean;

    procedure TPPUModule.WriteUsedMacro(P:TNamedIndexItem;Arg:Pointer);
      begin
        if TMacro(P).IsUsed or IsInitial then
          begin
            PPUFile.PutString(P.Name);
            PPUFile.PutBoolean(IsInitial);
            PPUFile.PutBoolean(TMacro(P).IsUsed);
          end;
      end;

    procedure TPPUModule.WriteUsedMacros;
      var
        OldCRC : Boolean;
      begin
        OldCRC:=PPUFile.DoCRC;
        PPUFile.DoCRC:=False;
        IsInitial:= True;
        InitialMacroSymTable.ForEach(@WriteUsedMacro,nil);
        IsInitial:= False;
        if Assigned(GlobalMacroSymTable) then
          GlobalMacroSymTable.ForEach(@WriteUsedMacro,nil);
        LocalMacroSymTable.ForEach(@WriteUsedMacro,nil);
        PPUFile.WriteEntry(IBUsedMacros);
        PPUFile.DoCRC:=OldCRC;
      end;
{$ENDIF}

    procedure TPPUModule.WriteSourceFiles;
      var
        HP  : TInputFile;
        IFile : SizeInt;
        OldCRC : Boolean;
      begin
      { write the used source files }
        OldCRC:=PPUFile.DoCRC;
        PPUFile.DoCRC:=False;
      { write source files directly in good order }
        for IFile:=0 to SourceFiles.NFiles-1 do
          begin
            HP:=SourceFiles.Files[IFile];
            PPUFile.PutString(HP.IncPath+HP.Name);
            PPUFile.PutLongInt(HP.GetFileTime);
         end;
        PPUFile.WriteEntry(IBSourceFiles);
        PPUFile.DoCRC:=OldCRC;
      end;


    procedure TPPUModule.WriteUsedUnit(Intf:Boolean);
      var
        HP : TUsedUnit;
        OldCRC : Boolean;
        U: TModule;
      begin
        { write a reference for each used unit }
        HP:=TUsedUnit(UsedUnitList.First);
        while Assigned(HP) do
         begin
           if HP.InInterface=Intf then
             begin
               U:=HP.U;
               PPUFile.PutString(U.RealModuleName^);
               { the checksum should not affect the crc of this unit ! (PFV) }
               OldCRC:=PPUFile.DoCRC;
               PPUFile.DoCRC:=False;
               HP.Checksum:=U.CRC;
               HP.InterfaceChecksum:=U.InterfaceCRC;
               HP.IndirectChecksum:=U.IndirectCRC;
               PPUFile.PutLongInt(LongInt(HP.Checksum));
               PPUFile.PutLongInt(LongInt(HP.InterfaceChecksum));
               PPUFile.PutLongInt(LongInt(HP.IndirectChecksum));
               PPUFile.DoCRC:=OldCRC;
               { Combine all indirect checksums from units used by this unit.
                 The indirect_crc contains the classes+records of this unit as well. }
               if Intf then
                 PPUFile.IndirectCRC:=UpdateCRC32(PPUFile.IndirectCRC,U.IndirectCRC,SizeOf(U.IndirectCRC));
             end;
           HP:=TUsedUnit(HP.Next);
         end;
        PPUFile.WriteEntry(IBLoadUnit);
      end;


    procedure TPPUModule.WriteLinkContainer(var P:TLinkContainer;ID:Byte;StripPath:Boolean);
      var
        HContainer : TLinkContainer;
        S : TPathStr;
        Mask : Cardinal;
      begin
        HContainer:=TLinkContainer.Create;
        while not P.Empty do
         begin
           S:=P.Get(Mask);
           if StripPath then
            PPUFile.PutString(ExtractFileName(S))
           else
            PPUFile.PutString(S);
           PPUFile.PutLongInt(Mask);
           HContainer.Add(S,Mask);
         end;
        PPUFile.WriteEntry(ID);
        P.Free;
        P:=HContainer;
      end;


    procedure TPPUModule.WriteDerefMap;
      var
        I : LongInt;
        OldCRC : Boolean;
      begin
        { This does not influence crc }
        OldCRC:=PPUFile.DoCRC;
        PPUFile.DoCRC:=False;
        { The unit map used for resolving }
        PPUFile.PutLongInt(DerefMapCnt);
        for I:=0 to DerefMapCnt-1 do
          begin
            if not Assigned(DerefMap[I].U) then
              InternalError(2005011512);
            PPUFile.PutString(DerefMap[I].U.ModuleName^)
          end;
        PPUFile.WriteEntry(IBDerefMap);
        PPUFile.DoCRC:=OldCRC;
      end;


    procedure TPPUModule.WriteDerefData;
      var
        OldCRC : Boolean;
        Len,HLen : LongInt;
        Buf : array[0..1023] of Byte;
      begin
        if LongWord(DerefDataIntfLen)>DerefData.Size then
          InternalError(200310223);
        DerefData.Seek(0);
        { Write interface data }
        Len:=DerefDataIntfLen;
        while (Len>0) do
          begin
            if Len>1024 then
              HLen:=1024
            else
              HLen:=Len;
            DerefData.Read(Buf,HLen);
            PPUFile.PutData(Buf,HLen);
            Dec(Len,HLen);
          end;
        { Write implementation data, this does not influence crc }
        OldCRC:=PPUFile.DoCRC;
        PPUFile.DoCRC:=False;
        Len:=DerefData.Size-DerefDataIntfLen;
        while (Len>0) do
          begin
            if Len>1024 then
              HLen:=1024
            else
              HLen:=Len;
            DerefData.Read(Buf,HLen);
            PPUFile.PutData(Buf,HLen);
            Dec(Len,HLen);
          end;
        if DerefData.Pos<>DerefData.Size then
          InternalError(200310224);
        PPUFile.DoCRC:=OldCRC;
        PPUFile.WriteEntry(IBDerefData);
      end;


    procedure TPPUModule.WriteImportSymbols;
      var
        I,J : LongInt;
        ImportLibrary : TImportLibrary;
        ImportSymbol  : TImportSymbol;
      begin
        for I:=0 to ImportLibraryList.Count-1 do
          begin
            ImportLibrary:=TImportLibrary(ImportLibraryList[I]);
            PPUFile.PutString(ImportLibrary.Name);
            PPUFile.PutLongInt(ImportLibrary.ImportSymbolList.Count);
            for J:=0 to ImportLibrary.ImportSymbolList.Count-1 do
              begin
                ImportSymbol:=TImportSymbol(ImportLibrary.ImportSymbolList[J]);
                PPUFile.PutString(ImportSymbol.Name);
                PPUFile.PutString(ImportSymbol.MangledName);
                PPUFile.PutLongInt(ImportSymbol.OrdNr);
                PPUFile.PutByte(Byte(ImportSymbol.IsVar));
              end;
          end;
        PPUFile.WriteEntry(IBImportSymbols);
      end;


    procedure TPPUModule.WriteResources;
      var
        Res : TCmdStrListItem;
      begin
        Res:=TCmdStrListItem(ResourceFiles.First);
        while Res<>nil do
          begin
            PPUFile.PutString(Res.FPStr);
            Res:=TCmdStrListItem(Res.Next);
          end;
        PPUFile.WriteEntry(IBResources);
      end;


    procedure TPPUModule.WriteOrderedSymbols;
      var
        Res : TCmdStrListItem;
      begin
        Res:=TCmdStrListItem(LinkOrderedSymbols.First);
        while Res<>nil do
          begin
            PPUFile.PutString(Res.FPStr);
            Res:=TCmdStrListItem(Res.Next);
          end;
        PPUFile.WriteEntry(IBOrderedSymbols);
      end;


    procedure TPPUModule.WriteUnitExports;
      var
        HP : TExportedItem;
        Option : TExportOption;
        Flags : Byte;
      begin
        { Optional metadata: units without exports retain the existing format. }
        if not (TargetInfo.System in (systems_windows+systems_linux)) or
           not Assigned(ExportList.First) then
          Exit;
        HP:=TExportedItem(ExportList.First);
        while Assigned(HP) do
          begin
            PPUFile.PutString(HP.Name^);
            PPUFile.PutString(HP.InternalName);
            PPUFile.PutLongInt(HP.Index);
            Flags:=0;
            for Option:=Low(TExportOption) to High(TExportOption) do
              if Option in HP.Options then
                Flags:=Flags or (1 shl Ord(Option));
            PPUFile.PutByte(Flags);
            PPUFile.PutByte(Ord(HP.is_var));
            HP:=TExportedItem(HP.Next);
          end;
        PPUFile.WriteEntry(IBUnitExports);
      end;


    procedure TPPUModule.WriteUnitImportSyms;
      var
        I : LongInt;
      begin
        PPUFile.PutLongInt(UnitImportSymsDerefs.Count);
        for I:=0 to UnitImportSymsDerefs.Count-1 do
          PPUFile.PutDeref(PDeref(UnitImportSymsDerefs[I])^);
        PPUFile.WriteEntry(IBUnitImportSyms);
      end;


    procedure TPPUModule.WriteAsmSyms(Kind:TUnitAsmListType;List:TFPHashObjectList);
      var
        I : LongInt;
        Sym : TAsmSymbol;
      begin
        PPUFile.PutByte(Ord(Kind));
        PPUFile.PutLongInt(List.Count);
        for I:=0 to List.Count-1 do
          begin
            Sym:=TAsmSymbol(List[I]);
            PPUFile.PutString(Sym.Name);
            PPUFile.PutByte(Ord(Sym.Bind));
            PPUFile.PutByte(Ord(Sym.Typ));
          end;
        PPUFile.WriteEntry(IBAsmSymbols);
      end;

    procedure TPPUModule.WriteExtraHeader;
      var
        OldDoCRC: Boolean;
      begin
        { create unit flags }
        if Do_Release then
          Include(ModuleFlags,mf_release);
        if Assigned(LocalSymTable) then
          Include(ModuleFlags,mf_local_symtable);
        if cs_checkpointer_called in CurrentSettings.ModuleSwitches then
          Include(ModuleFlags,mf_checkpointer_called);
        if cs_compilesystem in CurrentSettings.ModuleSwitches then
          Include(ModuleFlags,mf_system_unit);
        if cs_nexus_profile in CurrentSettings.ModuleSwitches then
          Include(ModuleFlags,mf_nexus_profile);
         if CompilerWide_Unicode_Strings then
           Include(ModuleFlags,mf_unicode_default);


{$ifdef symansistr}
        Include(ModuleFlags,mf_symansistr);
{$endif}

        OldDoCRC:=PPUFile.DoCRC;
        PPUFile.DoCRC:=False;
        PPUFile.PutLongInt(LongInt(CurrentPPULongVersion));
        PPUFile.PutSet(TPPUSet4(ModuleFlags));
        PPUFile.WriteEntry(IBExtraHeader);
        PPUFile.DoCRC:=OldDoCRC;
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

    procedure TPPUModule.ReadUsedMacros;
      var
        HS : string;
        Mac : TMacro;
        WasInitialSource,
        WasUsed : Boolean;
      {Reads macros which was defined or used when the module was compiled.
       This is done when a ppu file is open, before it possibly is parsed.}
      begin
        while not PPUFile.EndOfEntry do
         begin
           HS:=PPUFile.GetString;
           WasInitialSource:=PPUFile.GetBoolean;
           WasUsed:=PPUFile.GetBoolean;
           Mac:=TMacro(InitialMacroSymTable.Find(HS));
           if Assigned(Mac) then
             begin
{$ifndef EXTDEBUG}
           { if we don't have the sources why tell }
              if SourcesAvail then
{$endif ndef EXTDEBUG}
               if (not WasInitialSource) and WasUsed then
                Message2(unit_h_cond_not_set_in_last_compile,HS,MainSource^);
             end
           else { not assigned }
             if WasInitialSource and
                WasUsed then
              Message2(unit_h_cond_set_in_last_compile,HS,MainSource^);
         end;
      end;
{$ENDIF}

    procedure TPPUModule.ReadSourceFiles;
      var
        Temp,HS       : string;
        IncPath      : string;
        temp_dir      : TCmdStr;
        main_dir      : TCmdStr;
        Found,
        is_main       : Boolean;
        OrgFileTime,
        source_time   : LongInt;
        HP            : TInputFile;
      begin
        SourcesAvail:=not(mf_release in ModuleFlags);
        is_main:=True;
        main_dir:='';
        while not PPUFile.EndOfEntry do
         begin
           HS:=SetDirSeparators(PPUFile.GetString);
           IncPath:=ExtractFilePath(HS);
           OrgFileTime:=PPUFile.GetLongInt;
           temp_dir:='';
           if SourcesAvail then
             begin
               if (HeaderFlags and UfInLibrary)<>0 then
                begin
                  SourcesAvail:=False;
                  Temp:=' library';
                end
               else if Pos('Macro ',HS)=1 then
                begin
                  { we don't want to find this file }
                  { but there is a problem with file indexing !! }
                  Temp:='';
                end
               else
                begin
                  { check the date of the source files:
                     1 path of sourcefn
                     2 path of ppu
                     3 path of main source
                     4 current dir
                     5 include/unit path }
                  Found:=False;
                  if SourceFN<>'' then
                  begin
                    temp_dir:=ExtractFilePath(SetDirSeparators(SourceFN));
                    Source_Time:=GetNamedFileTime(temp_dir+HS);
                    if Source_Time<>-1 then
                      HS:=temp_dir+HS;
                  end else
                    Source_Time:=-1;
                  if Source_Time=-1 then
                    begin
                      Source_Time:=GetNamedFileTime(Path+HS);
                      if Source_Time<>-1 then
                        HS:=Path+HS
                      else
                       if not(is_main) then
                        begin
                          Source_Time:=GetNamedFileTime(main_dir+HS);
                          if Source_Time<>-1 then
                            HS:=main_dir+HS;
                        end;
                    end;
                  if Source_Time=-1 then
                    Source_Time:=GetNamedFileTime(HS);
                  if (Source_Time=-1) then
                    begin
                      if is_main then
                        Found:=UnitSearchPath.FindFile(HS,True,temp_dir)
                      else
                        Found:=IncludeSearchPath.FindFile(HS,True,temp_dir);
                      if Found then
                       begin
                         Source_Time:=GetNamedFileTime(temp_dir);
                         if Source_Time<>-1 then
                          HS:=temp_dir;
                       end;
                    end;
                  if Source_Time<>-1 then
                    begin
                      if is_main then
                        main_dir:=ExtractFilePath(HS);
                      Temp:=' time '+FileTimeString(source_time);
                      if (OrgFileTime<>-1) and
                         (source_time<>OrgFileTime) then
                        begin
                          {$IFDEF DEBUG_PPU_CYCLES}
                          WriteLn('PPUALGO tppumodule.readsourcefiles sourcechanged ',ModuleName^,' old=',State,' new=',ms_compile);
                          {$ENDIF}
                          State:=ms_compile;
                          RecompileReason:=rr_sourcenewer;
                          Message2(unit_u_source_modified,HS,PPUFileName,@QueueComment);
                          Temp:=Temp+' *';
                        end;
                    end
                  else
                    begin
                      SourcesAvail:=False;
                      Temp:=' not found';
                    end;
                  HP:=TDOSInputFile.Create(HS);
                  HP.IncPath:=IncPath;
                  { the indexing is wrong here PM }
                  SourceFiles.Register_File(HP);
                end;
             end
           else
             begin
               { still register the source module for proper error messages
                 since source_avail for the module is still false, this should not hurt }
               SourceFiles.Register_File(TDOSInputFile.Create(HS));

               Temp:=' not available';
             end;
           if is_main then
             begin
               MainSource:=HS;
             end;
           Message1(unit_u_ppu_source,HS+Temp,@QueueComment);
           is_main:=False;
         end;
      { check if we want to rebuild every unit, only if the sources are
        available }
        if Do_Build and SourcesAvail then
          begin
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tppumodule.readsourcefiles do_build ',ModuleName^,' old=',State,' new=',ms_compile);
            {$ENDIF}
            State:=ms_compile;
            RecompileReason:=rr_build;
          end;
      end;


    procedure TPPUModule.ReadLoadUnit;
      var
        HS : string;
        Pu : TUsedUnit;
        HP : TPPUModule;
        IndChecksum,
        IntfChecksum,
        Checksum : Cardinal;
        IsNew : Boolean;

      begin
        while not PPUFile.EndOfEntry do
         begin
           HS:=PPUFile.GetString;
           Checksum:=Cardinal(PPUFile.GetLongInt);
           IntfChecksum:=Cardinal(PPUFile.GetLongInt);
           IndChecksum:=Cardinal(PPUFile.GetLongInt);
           { set the state of this unit before registering, this is
             needed for a correct circular dependency check }
           HP:=RegisterUnit(Self,HS,'',IsNew);
           if IsNew then
             UsedUnits.Concat(TUsedUnit.Create(HP,InInterface,True,nil));
           Pu:=FindUsedUnit(HP);
           if Pu=nil then
             Pu:=AddUsedUnit(HP,False,nil);
           Pu.Checksum:=Checksum;
           Pu.InterfaceChecksum:=IntfChecksum;
           Pu.IndirectChecksum:=IndChecksum;
         end;
        InInterface:=False;
      end;


    procedure TPPUModule.ReadLinkContainer(var P:TLinkContainer);
      var
        S : string;
        M : LongInt;
      begin
        while not PPUFile.EndOfEntry do
         begin
           S:=PPUFile.GetString;
           M:=PPUFile.GetLongInt;
           P.Add(S,M);
         end;
      end;


    procedure TPPUModule.ReadDerefMap;
      var
        I : LongInt;
      begin
        { Load unit map used for resolving }
        DerefMapSize:=PPUFile.GetLongInt;
        DerefMapCnt:=DerefMapSize;
        SetLength(DerefMap,DerefMapSize);
        for I:=0 to DerefMapSize-1 do
          DerefMap[I].ModuleName:=PPUFile.GetPShortString;
      end;


    procedure TPPUModule.ReadDerefData;
      var
        Len,HLen : LongInt;
        Buf : array[0..1023] of Byte;
      begin
        Len:=PPUFile.EntrySize;
        while (Len>0) do
          begin
            if Len>1024 then
              HLen:=1024
            else
              HLen:=Len;
            PPUFile.GetData(Buf,HLen);
            DerefData.Write(Buf,HLen);
            Dec(Len,HLen);
          end;
      end;


    procedure TPPUModule.ReadImportSymbols;
      var
        J,
        ExtSymCnt   : LongInt;
        ImportLibrary  : TImportLibrary;
        ExtSymName  : string;
        ExtSymMangledName : string;
        ExtSymOrdNr : LongInt;
        ExtSymIsVar : Boolean;
      begin
        while not PPUFile.EndOfEntry do
          begin
            ImportLibrary:=TImportLibrary.Create(ImportLibraryList,PPUFile.GetString);
            ExtSymCnt:=PPUFile.GetLongInt;
            for J:=0 to ExtSymCnt-1 do
              begin
                ExtSymName:=PPUFile.GetString;
                ExtSymMangledName:=PPUFile.GetString;
                ExtSymOrdNr:=PPUFile.GetLongInt;
                ExtSymIsVar:=(PPUFile.GetByte<>0);
                TImportSymbol.Create(ImportLibrary.ImportSymbolList,ExtSymName,
                  ExtSymMangledName,ExtSymOrdNr,ExtSymIsVar);
              end;
          end;
      end;


    procedure TPPUModule.ReadResources;
      begin
        while not PPUFile.EndOfEntry do
          ResourceFiles.Insert(PPUFile.GetString);
      end;


    procedure TPPUModule.ReadOrderedSymbols;
      begin
        while not PPUFile.EndOfEntry do
          LinkOrderedSymbols.Concat(PPUFile.GetString);
      end;


    procedure TPPUModule.ReadUnitExports;
      var
        HP : TExportedItem;
        Option : TExportOption;
        Flags : Byte;
      begin
        while not PPUFile.EndOfEntry do
          begin
            HP:=TExportedItem.Create;
            HP.Name:=StringDup(PPUFile.GetString);
            HP.InternalName:=PPUFile.GetString;
            HP.Index:=PPUFile.GetLongInt;
            Flags:=PPUFile.GetByte;
            for Option:=Low(TExportOption) to High(TExportOption) do
              if Flags and (1 shl Ord(Option))<>0 then
                Include(HP.Options,Option);
            HP.is_var:=PPUFile.GetByte<>0;
            ExportList.Concat(HP);
          end;
      end;


    procedure TPPUModule.ReadWPOFile;
      var
        OrgWPOFileName: string;
        OrgWPOFileTime: LongInt;
      begin
        { check whether we are using the same wpo feedback input file as when
          this unit was compiled (same file name and file date)
        }
        OrgWPOFileName:=PPUFile.GetString;
        OrgWPOFileTime:=PPUFile.GetLongInt;
        if (ExtractFileName(OrgWPOFileName)<>ExtractFileName(WPOFeedbackInput)) or
           (OrgWPOFileTime<>GetNamedFileTime(OrgWPOFileName)) then
          { make sure we don't throw away a precompiled unit if the user simply
            forgot to specify the right wpo feedback file
          }
          Message3(unit_e_different_wpo_file,PPUFileName,OrgWPOFileName,FileTimeString(OrgWPOFileTime));
      end;


    procedure TPPUModule.ReadUnitImportSyms;
      var
        C,I : LongInt;
        Deref : PDeref;
      begin
        C:=PPUFile.GetLongInt;
        for I:=0 to C-1 do
          begin
            New(Deref);
            PPUFile.GetDeref(Deref^);
            UnitImportSymsDerefs.Add(Deref);
          end;
      end;


    procedure TPPUModule.ReadAsmSyms;
      var
        C,I : LongInt;
        Name : TSymStr;
        Bind : TAsmsymbind;
        Typ : TAsmsymtype;
        List : TFPHashObjectList;
      begin
        case TUnitAsmListType(PPUFile.GetByte) of
          ualt_public:
            List:=PublicAsmSyms;
          ualt_extern:
            List:=ExternAsmSyms;
        end;
        C:=PPUFile.GetLongInt;
        for I:=0 to C-1 do
          begin
            Name:=PPUFile.GetString;
            Bind:=TAsmsymbind(PPUFile.GetByte);
            Typ:=TAsmsymtype(PPUFile.GetByte);
            TAsmSymbol.Create(List,Name,Bind,Typ);
          end;
      end;


    procedure TPPUModule.ReadExtraHeader;
      begin
        LongVersion:=Cardinal(PPUFile.GetLongInt);
        PPUFile.GetSet(TPPUSet4(ModuleFlags));
      end;


    procedure TPPUModule.LoadInterface;
      var
        B : Byte;
        NewModuleName : string;
      begin
       { read interface part }
         repeat
           B:=PPUFile.ReadEntry;
           case B of
             IBModuleName :
               begin
                 NewModuleName:=PPUFile.GetString;
                 if (cs_check_unit_name in CurrentSettings.GlobalSwitches) and
                    (Upper(NewModuleName)<>ModuleName^) then
                   Message2(unit_f_unit_name_error,RealModuleName^,NewModuleName);
                 StringDispose(ModuleName);
                 StringDispose(RealModuleName);
                 ModuleName:=StringDup(Upper(NewModuleName));
                 RealModuleName:=StringDup(NewModuleName);
               end;
             IBExtraHeader:
               begin
                 ReadExtraHeader;
               end;
             IBFeatures :
               begin
                 PPUFile.GetSet(TPPUSet4(Features));
               end;
             IBModuleOptions:
               begin
                 PPUFile.GetSet(TPPUSet1(ModuleOptions));
                 if mo_has_deprecated_msg in ModuleOptions then
                   begin
                     StringDispose(DeprecatedMsg);
                     DeprecatedMsg:=PPUFile.GetPShortString;
                   end;
               end;
             IBSourceFiles :
               ReadSourceFiles;
{$IFDEF MACRO_DIFF_HINT}
             IBUsedMacros :
               ReadUsedMacros;
{$ENDIF}
             IBLoadUnit :
               ReadLoadUnit;
             IBLinkUnitOFiles :
               ReadLinkContainer(LinkUnitOFiles);
             IBLinkUnitStaticLibs :
               ReadLinkContainer(LinkUnitStaticLibs);
             IBLinkUnitSharedLibs :
               ReadLinkContainer(LinkUnitSharedLibs);
             IBLinkOtherOFiles :
               ReadLinkContainer(LinkOtherOFiles);
             IBLinkOtherStaticLibs :
               ReadLinkContainer(LinkOtherStaticLibs);
             IBLinkOtherSharedLibs :
               ReadLinkContainer(LinkOtherSharedLibs);
             IBLinkOtherFrameworks :
               ReadLinkContainer(LinkOtherFrameworks);
             IBMainName:
               begin
                 MainName:=PPUFile.GetPShortString;
                 if (MainAliasName<>DefaultMainAliasName) then
                   Message1(scan_w_multiple_main_name_overrides,MainAliasName);
                 MainAliasName:=MainName^;
               end;
             IBImportSymbols :
               ReadImportSymbols;
             IBDerefMap :
               ReadDerefMap;
             IBDerefData :
               ReadDerefData;
             IBResources:
               ReadResources;
             IBOrderedSymbols:
               ReadOrderedSymbols;
             IBUnitExports:
               ReadUnitExports;
             IBWPOFile:
               ReadWPOFile;
             IBEndInterface :
               Break;
           else
             Message1(unit_f_ppu_invalid_entry,ToStr(B));
           end;
           { we can already stop when we know that we must recompile }
           if State=ms_compile then
             Exit;
         until False;
      end;


    procedure TPPUModule.LoadImplementation;
      var
        B : Byte;
      begin
         { read implementation part }
         repeat
           B:=PPUFile.ReadEntry;
           case B of
             IBLoadUnit :
               ReadLoadUnit;
             IBAsmSymbols :
               ReadAsmSyms;
             IBUnitImportSyms:
               ReadUnitImportSyms;
             IBEndImplementation :
               Break;
           else
             Message1(unit_f_ppu_invalid_entry,ToStr(B));
           end;
         until False;
      end;


    procedure TPPUModule.WritePPU;
      var
        LIndex: LongInt;
        LAsmSymbols: TFPHashObjectList;
        LSymbol: TAsmSymbol;
      begin
         { A System unit built with a contradictory Char alias must never
           receive a PPU bearing the invocation's text-model flag. }
         if (cs_compilesystem in CurrentSettings.ModuleSwitches) and
            (Search_System_Type('CHAR').TypeDef.Size <>
             1+Ord(CompilerWide_Unicode_Strings)) then
           Comment(VFatal,'System.Char width does not match this compiler invocation''s default text model');

         Message1(unit_u_ppu_write,RealModuleName^);

         { create unit flags }
         { create new ppufile }
         PPUFile:=TCompilerPPUFile.Create(PPUFileName);
         if not PPUFile.CreateFile then
          Message(unit_f_ppu_cannot_write);


         { extra header (sub version, module flags) }
         WriteExtraHeader;
         { the unitname }
         PPUFile.PutString(RealModuleName^);
         PPUFile.WriteEntry(IBModuleName);

         PPUFile.PutSet(TPPUSet1(ModuleOptions));
         if mo_has_deprecated_msg in ModuleOptions then
           PPUFile.PutString(DeprecatedMsg^);
         PPUFile.WriteEntry(IBModuleOptions);

         { write the alternate main procedure name if any }
         if Assigned(MainName) then
           begin
             PPUFile.PutString(MainName^);
             PPUFile.WriteEntry(IBMainName);
           end;

         if cs_compilesystem in CurrentSettings.ModuleSwitches then
           begin
             PPUFile.PutSet(TPPUSet4(Features));
             PPUFile.WriteEntry(IBFeatures);
           end;

         WriteSourceFiles;
{$IFDEF MACRO_DIFF_HINT}
         WriteUsedMacros;
{$ENDIF}

         { write interface uses }
         WriteUsedUnit(True);

         { write the objectfiles and libraries that come for this unit,
           preserve the containers because they are still needed to load
           the link.res.
            All doesn't depend on the crc! It doesn't matter
           if a unit is in a .o or .a file }
         PPUFile.DoCRC:=False;
         { write after source files, so that we know whether or not the compiler
           will recompile the unit when checking whether the correct wpo file is
           used (if it will recompile the unit anyway, it doesn't matter)
         }
         if (WPOFeedbackInput<>'') then
           begin
             PPUFile.PutString(WPOFeedbackInput);
             PPUFile.PutLongInt(GetNamedFileTime(WPOFeedbackInput));
             PPUFile.WriteEntry(IBWPOFile);
           end;
         WriteLinkContainer(LinkUnitOFiles,IBLinkUnitOFiles,True);
         WriteLinkContainer(LinkUnitStaticLibs,IBLinkUnitStaticLibs,True);
         WriteLinkContainer(LinkUnitSharedLibs,IBLinkUnitSharedLibs,True);
         WriteLinkContainer(LinkOtherOFiles,IBLinkOtherOFiles,False);
         WriteLinkContainer(LinkOtherStaticLibs,IBLinkOtherStaticLibs,True);
         WriteLinkContainer(LinkOtherSharedLibs,IBLinkOtherSharedLibs,True);
         WriteLinkContainer(LinkOtherFrameworks,IBLinkOtherFrameworks,True);
         WriteImportSymbols;
         WriteResources;
         WriteOrderedSymbols;
         WriteUnitExports;
         PPUFile.DoCRC:=True;

         { generate implementation deref data, the interface deref data is
           already generated when calculating the interface crc }
         if (cs_compilesystem in CurrentSettings.ModuleSwitches) then
           begin
             TStoredSymTable(GlobalSymTable).BuildDeref;
             DerefDataIntfLen:=DerefData.Size;
           end
         else
           { the unit may have been re-resolved, in which case the current
             position in derefdata is not necessarily at the end }
            DerefData.Seek(DerefData.Size);
         TStoredSymTable(GlobalSymTable).BuildDerefImpl;
         TUnitWPOInfo(WPOInfo).BuildDeref;
         TUnitWPOInfo(WPOInfo).BuildDerefImpl;

         if Assigned(GlobalMacroSymTable) and (GlobalMacroSymTable.SymList.Count > 0) then
            begin
              TStoredSymTable(GlobalMacroSymTable).BuildDeref;
              TStoredSymTable(GlobalMacroSymTable).BuildDerefImpl;
            end;

         if mf_local_symtable in ModuleFlags then
           TStoredSymTable(LocalSymTable).BuildDeref_Registered;
         BuildDerefUnitImportSyms;
         WriteDerefMap;
         WriteDerefData;

         PPUFile.WriteEntry(IBEndInterface);

         { write the symtable entries }
         TStoredSymTable(GlobalSymTable).PPUWrite(PPUFile);

         if Assigned(GlobalMacroSymTable) and (GlobalMacroSymTable.SymList.Count > 0) then
           begin
             PPUFile.PutByte(Byte(True));
             PPUFile.WriteEntry(IBExportedMacros);
             TStoredSymTable(GlobalMacroSymTable).PPUWrite(PPUFile);
           end
         else
           begin
             PPUFile.PutByte(Byte(False));
             PPUFile.WriteEntry(IBExportedMacros);
           end;

         { everything after this doesn't affect the crc }
         PPUFile.DoCRC:=False;

         { write implementation uses }
         WriteUsedUnit(False);

         { Calls and procedure addresses introduced by inlining or code
           generation need the same package import lookup as parsed calls. }
         if tf_supports_packages in TargetInfo.Flags then
           begin
             LAsmSymbols:=TAsmData(AsmData).AsmSymbolDict;
             for LIndex:=0 to LAsmSymbols.Count-1 do
               begin
                 LSymbol:=TAsmSymbol(LAsmSymbols[LIndex]);
                 if LSymbol.Typ<>AT_FUNCTION then
                   Continue;
                 case LSymbol.Bind of
                   AB_EXTERNAL:
                     Add_Extern_AsmSym(LSymbol);
                   else
                     ;
                 end;
               end;
           end;

         { write all public assembler symbols }
         WriteAsmSyms(ualt_public,PublicAsmSyms);

         { write all external assembler symbols }
         WriteAsmSyms(ualt_extern,ExternAsmSyms);

         { write all symbols imported from another unit }
         WriteUnitImportSyms;

         { end of implementation }
         PPUFile.WriteEntry(IBEndImplementation);

         { write static symtable
           needed for local debugging of unit functions }
         if mf_local_symtable in ModuleFlags then
           TStoredSymTable(LocalSymTable).PPUWrite(PPUFile);

         { write whole program optimisation-related information }
         TUnitWPOInfo(WPOInfo).PPUWrite(PPUFile);

         { the last entry ibend is written automatically }

         { flush to be sure }
         PPUFile.Flush;

         { save crc in current module also }
         if not CRCFinal then
           begin
             CRCFinal:=True;
             CRC:=PPUFile.CRC;
           end;
         { create and write header }
         { Note: the interface_crc and indirect_crc were computed in getppucrc
                 after the interface was compiled. The implementation must *not* effect them. }
         PPUFile.Header.Common.Size:=PPUFile.Size;
         PPUFile.Header.Checksum:=CRC;
         PPUFile.Header.InterfaceChecksum:=InterfaceCRC;
         PPUFile.Header.IndirectChecksum:=IndirectCRC;
         PPUFile.Header.Common.Compiler:=WordVersion;
         PPUFile.Header.Common.CPU:=Word(TargetCPU);
         PPUFile.Header.Common.Target:=Word(TargetInfo.System);
         PPUFile.Header.Common.Flags:=HeaderFlags;
         PPUFile.Header.DefListSize:=CurrentModule.DefList.Count;
         PPUFile.Header.SymListSize:=CurrentModule.SymList.Count;
         PPUFile.WriteHeader;


         DiscardPPU;
      end;


    procedure TPPUModule.GetPPUCRC;
      begin
         { create new ppufile }
         PPUFile:=TCompilerPPUFile.Create(PPUFileName);
         PPUFile.CRCOnly:=True;
         if not PPUFile.CreateFile then
           Message(unit_f_ppu_cannot_write);

{$ifdef DEBUG_GENERATE_INTERFACE_PPU}
        if PPUFile.WritingInterfacePPU then
          PPUFile.CRCOnly:=False;
{$endif DEBUG_GENERATE_INTERFACE_PPU}
         { extra header (sub version, module flags) }
         WriteExtraHeader;

         { the unitname }
         PPUFile.PutString(RealModuleName^);
         PPUFile.WriteEntry(IBModuleName);

         PPUFile.PutSet(TPPUSet1(ModuleOptions));
         if mo_has_deprecated_msg in ModuleOptions then
           PPUFile.PutString(DeprecatedMsg^);
         PPUFile.WriteEntry(IBModuleOptions);

         { the interface units affect the crc }
         WriteUsedUnit(True);

         { deref data of interface that affect the crc }
         DerefData.Reset;
         TStoredSymTable(GlobalSymTable).BuildDeref;
         DerefDataIntfLen:=DerefData.Size;
         WriteDerefMap;
         WriteDerefData;

         PPUFile.WriteEntry(IBEndInterface);

         { write the symtable entries }
         TStoredSymTable(GlobalSymTable).PPUWrite(PPUFile);

         if Assigned(GlobalMacroSymTable) and (GlobalMacroSymTable.SymList.Count > 0) then
           begin
             PPUFile.PutByte(Byte(True));
             PPUFile.WriteEntry(IBExportedMacros);
             TStoredSymTable(GlobalMacroSymTable).PPUWrite(PPUFile);
           end
         else
           begin
             PPUFile.PutByte(Byte(False));
             PPUFile.WriteEntry(IBExportedMacros);
           end;

         { save crc  }
         CRC:=PPUFile.CRC;
         if InInterface then
           begin
             { Note: the interface_crc and indirect_crc are not affected by the implementation }
             InterfaceCRC:=PPUFile.InterfaceCRC;
             IndirectCRC:=PPUFile.IndirectCRC;
           end;
         { end of implementation, to generate a correct ppufile
           for ppudump when using DEBUG_GENERATE_INTERFACE_PPU define }
         PPUFile.WriteEntry(IBEndImplementation);


         { create and write header, this will only be used
           for debugging purposes }
         PPUFile.Header.Common.Size:=PPUFile.Size;
         PPUFile.Header.Checksum:=CRC;
         PPUFile.Header.InterfaceChecksum:=InterfaceCRC;
         PPUFile.Header.IndirectChecksum:=IndirectCRC;
         PPUFile.Header.Common.Compiler:=WordVersion;
         PPUFile.Header.Common.CPU:=Word(TargetCPU);
         PPUFile.Header.Common.Target:=Word(TargetInfo.System);
         PPUFile.Header.Common.Flags:=HeaderFlags;
         PPUFile.WriteHeader;

         DiscardPPU;
      end;

    function TPPUModule.Dependent_Module_Has_Our_CRC: Boolean;
      { returns true, if any dependent module has crc for this module }
      var
        Pu: TDependentUnit;
        M: FModule.TModule;
      begin
        Pu:=TDependentUnit(DependentUnitList.First);
        while Assigned(Pu) do
          begin
            M:=Pu.U;
            if M.FromPPU or (M.State in [ms_compiled,ms_processed]) then
              Exit(True);
            Pu:=TDependentUnit(Pu.Next);
          end;
        Result:=False;
      end;

    function TPPUModule.Dependent_Module_CRC_Mismatch: Boolean;
      { called after an interface crc or crc was computed.
        Checks if any dependent module needs a recompile.
        The compile goes back to the ctask scheduler which recompiles. }
      var
        Pu: TDependentUnit;
        M: TPPUModule;
        UU: TUsedUnit;
        CheckCRC, UsedByInterface: Boolean;
      begin
        Result:=False;
        if not InterfaceCompiled then
          InternalError(2026033101);
        Pu:=TDependentUnit(DependentUnitList.First);
        while Assigned(Pu) do
          begin
            M:=TPPUModule(Pu.U);
            UsedByInterface:=Pu.InInterface;
            Pu:=TDependentUnit(Pu.Next);
            if not M.FromPPU then
              begin
                if UsedByInterface then
                  begin
                    if not M.InterfaceCompiled then Continue;
                  end
                else
                  { uses by implementation }
                  case M.State of
                  ms_compiling_waitfinish,
                  ms_compiled_waitcrc:
                    ; { m has crc of its impl uses }
                  ms_compiled,
                  ms_processed:
                    InternalError(2026033111);
                  else
                    Continue; { m does not yet have its impl uses crc }
                  end;
              end;

            CheckCRC:=CRCFinal and (M.FromPPU or (M.State in [ms_compiled,ms_processed]));
            UU:=TUsedUnit(M.UsedUnitList.First);
            while Assigned(UU) do
              begin
                if (UU.U=Self)
                    and ( (InterfaceCRC<>UU.InterfaceChecksum)
                        or (IndirectCRC<>UU.IndirectChecksum)
                        or (CheckCRC and (CRC<>UU.Checksum) ) ) then
                  begin
                    Result:=True;
                    {$IFDEF DEBUG_PPU_CYCLES}
                    WriteLn('PPUALGO tppumodule.dependent_module_crc_mismatch ',ModuleName^,' used by ',BoolToStr(UU.InInterface,'interface','implementation'),' of "',M.ModuleName^,'" old=',M.StateStr,' new=',ms_compile);
                    {$ENDIF}
                    M.MarkRecompileNeeded(rr_crcchanged);
                  end;
                UU:=TUsedUnit(UU.Next);
              end;
          end;
      end;

    function TPPUModule.LoadUsedUnits: Boolean;
      { self is a ppu (or in a package) }
      begin
        Result:=True;
        if CurrentModule<>Self then
          InternalError(200212284);

        if not InterfaceCompiled then
        begin
          { load the used units from interface }
          InInterface:=True;
          if not LoadUsedUnitsSection then
            Exit(False); { e.g. fail or some used unit interface is not ready }
          if CurrentModule<>Self then
            InternalError(2026022317);
          { ok, now load the interface of this unit }
          if CurrentModule<>Self then
            InternalError(200208187);
          DefList.Count:=PPUFile.Header.DefListSize;
          SymList.Count:=PPUFile.Header.SymListSize;
          GlobalSymTable:=TGlobalSymTable.Create(RealModuleName^,ModuleID);
          TStoredSymTable(GlobalSymTable).PPULoad(PPUFile);

          if PPUFile.ReadEntry<>IBExportedMacros then
            Message(unit_f_ppu_read_error);
          if Boolean(PPUFile.GetByte) then
            begin
              GlobalMacroSymTable:=TMacroSymTable.Create(True);
              TStoredSymTable(GlobalMacroSymTable).PPULoad(PPUFile)
            end;

          InterfaceCompiled:=True;

          { read the implementation part, containing
            the implementation uses and ObjData }
          InInterface:=False;
          LoadImplementation;
        end;

        { now only read the implementation uses }
        if not PPUWaitingForCRC then
        begin
          if not LoadUsedUnitsSection then
            Exit(False); { fail or some used unit interface is not ready }
          if CurrentModule<>Self then
            InternalError(2026022316);
        end;

        if not PPUWaitingForCRC then
          begin
            PPUWaitingForCRC:=True;

            { load implementation symtable }
            if mf_local_symtable in ModuleFlags then
              begin
                LocalSymTable:=TStaticSymTable.Create(RealModuleName^,ModuleID);
                TStaticSymTable(LocalSymTable).PPULoad(PPUFile);
              end;

            { we can now dereference all pointers to the implementation parts }
            TStoredSymTable(GlobalSymTable).DerefImpl(False);
            { we've just loaded the localsymtable from the ppu file, so everything
              in it was registered by definition (otherwise it wouldn't have been in
              there) }
            if Assigned(LocalSymTable) then
              TStoredSymTable(LocalSymTable).DerefImpl(False);

            Remove_WaitForUnit_Cycles;

          end;

        { the implementation uses were just connected,
          the scc_tree_crc_wait is outdated.
          If all used units are compiled, continue.
          otherwise some used units might still change }
        if Find_Used_Unit_Compiling<>nil then
          Exit(False);

        { check that all used units have their crc and checksums match }
        if not PPUCheckUsedCRCs then
          Exit(False);
        PPUWaitingForCRC:=False;

        DerefUnitImportSyms;

        { read whole program optimisation-related information }
        WPOInfo:=TUnitWPOInfo.PPULoad(PPUFile);
        TUnitWPOInfo(WPOInfo).Deref;
        TUnitWPOInfo(WPOInfo).DerefImpl;

        Remove_All_WaitsForThisUnit;

        State:=ms_compiled;
      end;

    function TPPUModule.LoadUsedUnitsSection: Boolean;
      var
        Pu: TUsedUnit;
        IntfCRCValid, CRCValid: Boolean;
      begin
        Result:=True;
        Pu:=TUsedUnit(UsedUnitList.First);
        while Assigned(Pu) do
        begin
          if Pu.InInterface=InInterface then
          begin
            { adddependency before loadppu for invalid cycle test }
            if not Pu.DependentAdded then
            begin
              Pu.U.AddDependency(Self,InInterface);
              Pu.DependentAdded:=True;
            end;

            TPPUModule(Pu.U).LoadPPU(Self);
            { if this unit is scheduled for compilation or compiled we can stop }
            if State<>ms_load then
            begin
              {$IFDEF DEBUG_PPU_CYCLES}
              WriteLn('tppumodule.load_usedunits_section STOPPED ',ModuleName^,' ',StateStr);
              {$ENDIF}
              Exit(False);
            end;
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tppumodule.load_usedunits_section ',ModuleName^,' (',StateStr,') ',BoolToStr(InInterface,'interface','implementation'),' uses "',Pu.U.ModuleName^,'" state=',Pu.U.StateStr);
            {$ENDIF}

            { check crc(s) if recompile is needed.
              Currently ppus wait for a pas to be compiled, because a ppu cannot
              use only the interface of a pas.
              If an unit of a cycle is recompiled, the whole cycle is recompiled.

              If this ppu was compiled with -Ur only check interface_crc, not crc }
            CRCValid:=(not Pu.U.DoReload) and Pu.U.CRCFinal;
            IntfCRCValid:=(not Pu.U.DoReload) and Pu.U.InterfaceCompiled;

            if (IntfCRCValid and
                     ((Pu.U.InterfaceCRC<>Pu.InterfaceChecksum) or
                      (Pu.U.IndirectCRC<>Pu.IndirectChecksum)))
                or (CRCValid and
                  {$IFNDEF DisableUrCRC}
                  (not (mf_release in ModuleFlags)) and
                  {$ENDIF}
                  (Pu.U.CRC<>Pu.Checksum)
                 ) then
            begin
              Message2(unit_u_recompile_crc_change,RealModuleName^,Pu.U.PPUFileName,@QueueComment);
              {$IFDEF DEBUG_PPU_CYCLES}
              WriteLn('PPUALGO tppumodule.load_usedunits_section ',ModuleName^,' ',BoolToStr(InInterface,'interface','implementation'),' uses "',Pu.U.ModuleName^,'" old=',StateStr,' new=',ms_compile);
              {$ENDIF}
              MarkRecompileNeeded(rr_crcchanged);
              Exit(False);
            end;

            if Pu.U.DoReload
                or (not Pu.U.InterfaceCompiled)
                or CTask_Fast_Backtrack then
            begin
              { this used unit is delayed
                Important: do not break, load the remaining uses section, so the scheduler
                           has more information about cycles }
              {$IFDEF DEBUG_PPU_CYCLES}
              WriteLn('PPUALGO tppumodule.load_usedunits_section ',ModuleName^,' ',BoolToStr(InInterface,'interface','implementation'),' uses "',Pu.U.ModuleName^,'", state=',Pu.U.StateStr,', waiting ...');
              {$ENDIF}
              CTask_Fast_Backtrack:=True;
              Result:=False;
            end;
          end;
          Pu:=TUsedUnit(Pu.Next);
        end;
      end;

    function TPPUModule.PPUCheckUsedCRCs: Boolean;
    // check crcs
    var
      Pu: TUsedUnit;
    begin
      Result:=False;
      Pu:=TUsedUnit(UsedUnitList.First);
      while Assigned(Pu) do
      begin
        if Pu.U.CRCFinal then
        begin
          if (Pu.U.InterfaceCRC<>Pu.InterfaceChecksum)
              or (Pu.U.IndirectCRC<>Pu.IndirectChecksum)
              or (Pu.U.CRC<>Pu.Checksum) then
          begin
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tppumodule.ppu_check_used_crcs ',ModuleName^,' interface uses "',Pu.U.ModuleName^,'" old=',StateStr,' new=',ms_compile);
            {$ENDIF}
            MarkRecompileNeeded(rr_crcchanged);
            Exit;
          end;
        end else begin
          { waiting for crc }
          Exit;
        end;
        Pu:=TUsedUnit(Pu.Next);
      end;

      Result:=True;
    end;

    function TPPUModule.PPULoadCanContinue(out FirstWaiting: TModule): Boolean;
    var
      Pu: TUsedUnit;
    begin
      Result:=False;
      FirstWaiting:=nil;
      if State<>ms_load then
        InternalError(2026020610);

      if DoReload and not InterfaceCompiled then
        Exit(True);

      if PPUWaitingForCRC and (SCCTreeCRCWait<>nil) then
        begin
          FirstWaiting:=SCCTreeCRCWait;
          Exit; { the final load step needs all used units and their used units }
        end;

      Pu:=TUsedUnit(UsedUnitList.First);
      while Assigned(Pu) do
      begin
        if Pu.InInterface or InterfaceCompiled then
        begin
          if Pu.U.DoReload
              or not Pu.U.InterfaceCompiled
              or (PPUWaitingForCRC and not Pu.U.CRCFinal
                 {$IFNDEF DisableUrCRC}and not (mf_release in ModuleFlags){$ENDIF} ) then
          begin
            FirstWaiting:=Pu.U;
            Exit;
          end;
        end;
        Pu:=TUsedUnit(Pu.Next);
      end;
      Result:=True;
    end;

    function TPPUModule.Is_Reload_Needed(Pu: TDependentUnit): Boolean;
      begin
        if Pu.U.State=ms_load then
          Result:=Pu.U.PPUWaitingForCRC
                or (Pu.InInterface and Pu.U.InterfaceCompiled)
        else
          Result:=inherited Is_Reload_Needed(Pu);
      end;

    procedure TPPUModule.Restore_State;
      begin
        SetCurrentModule(Self);
        if StoredState<>nil then
          StoredState.Restore;
      end;

    procedure TPPUModule.Store_State;
      begin
        if StoredState=nil then
          StoredState:=TGlobalState.Create(True)
        else
          StoredState.Save(True);
      end;

    procedure TPPUModule.SetDefGeneration;
      begin
        DefsGeneration:=CurrentDefGeneration;
        Inc(CurrentDefGeneration);
      end;

    procedure TPPUModule.End_Of_Parsing;
      begin
        { free ppu }
        DiscardPPU;

        inherited End_Of_Parsing;
      end;

    { Returns true if the module was loaded from package }
    function TPPUModule.CheckLoadFromPackage : Boolean;

      begin
        { try to load it as a package unit first }
        Result:=(PackageList.Count>0) and LoadFromPackage;
        if Result then
          begin
            DoReload:=False;
            { add the unit to the used units list of the program }
            UsedUnits.Concat(TUsedUnit.Create(Self,True,False,nil));
          end;
      end;

    procedure TPPUModule.Recompile_From_Sources;

      var
        WasInterfaceCompiled: Boolean;
      begin
        SetCurrentModule(Self);
        Check_Sources_For_Recompile;

        {$IFDEF DEBUG_PPU_CYCLES}
        WriteLn('PPUALGO tppumodule.recompile_from_sources ',ModuleName^,' old=',StateStr,' new=',ms_compile);
        {$ENDIF}
        WasInterfaceCompiled:=InterfaceCompiled;
        { disconnect used modules }
        Disconnect_Depending_Modules;
        if FromPPU then
          PPUDiscarded:=True;
        { Flag modules to reload }
        FlagDependent;
        { Reset stack, parser, scanner, etc }
        if not FromPPU then
          End_Of_Parsing;
        { Reset the module }
        Reset(True);

        { mark this module for recompilation }
        State:=ms_compile;
        if WasInterfaceCompiled then
          SetDefGeneration;
      end;

    procedure TPPUModule.Check_Sources_For_Recompile;
      var
        Pu: TUsedUnit;
      begin
        { recompile the unit or give a fatal error if sources not available }
        if not SourcesAvail then
         begin
           SearchUnitFiles(LoadedFromModule,True);
           if not SourcesAvail then
            begin
              PrintComments;
              if RecompileReason=rr_noppu then
                begin
                  Pu:=TUsedUnit(LoadedFromModule.UsedUnitList.First);
                  while Assigned(Pu) do
                    begin
                      if Pu.U=Self then
                        Break;
                      Pu:=TUsedUnit(Pu.Next);
                    end;
                  if Assigned(Pu) and Assigned(Pu.UnitSym) then
                    MessagePos2(Pu.UnitSym.FileInfo,unit_f_cant_find_ppu,RealModuleName^,LoadedFromModule.RealModuleName^)
                  else
                    Message2(unit_f_cant_find_ppu,RealModuleName^,LoadedFromModule.RealModuleName^);
                end
              else
                Message1(unit_f_cant_compile_unit,RealModuleName^);
            end;
         end;
        { we found the sources, we do not need the verbose messages anymore }
        if Comments <> nil then
        begin
          Comments.Free;
          Comments:=nil;
        end;
      end;

    procedure TPPUModule.MarkRecompileNeeded(Reason: TRecompileReason);
      begin
        {$IFDEF DEBUG_PPU_CYCLES}
        WriteLn('PPUALGO tppumodule.mark_recompile_needed ',ModuleName^,' old=',StateStr,' new=',ms_compile);
        {$ENDIF}
        RecompileReason:=Reason;
        DoRecompile:=True;
        DoReload:=True;
        State:=ms_compile;
      end;

    procedure TPPUModule.Post_Load_Or_Compile(FromModule : TModule);
      begin
        if InInterface then
          InternalError(200212283);

        { reopen the old module }
      end;

    function TPPUModule.LoadPPU(FromModule : TModule) : Boolean;
      const
        ImplIntf : array[Boolean] of string[15]=('implementation','interface');
      var
        SavedCurrentModule: TModule;
      begin
        Result:=False;

        {$IFDEF DEBUG_PPU_CYCLES}
        WriteLn('PPUALGO tppumodule.loadppu START ',ModuleName^,' (',StateStr,') used by "',FromModule.ModuleName^,'" (',FromModule.StateStr,')');
        {$ENDIF}

        Message3(unit_u_load_unit,FromModule.ModuleName^,
                 ImplIntf[FromModule.InInterface],
                 ModuleName^);

        if DoReload then
          Exit; { reload needed. see scheduler }

        if State>ms_registered then
          Exit(InterfaceCompiled); { loading has already started or is finished }

        if PPUDiscarded then
          Exit; { the ppu crc didn't match and this module was reset, don't load the ppu }

        if CTask_Fast_Backtrack then
          Exit; { return to scheduler }

        LoadedFromModule:=FromModule;

        SavedCurrentModule:=CurrentModule;
        SetCurrentModule(Self);

        if CheckLoadFromPackage then
        begin
          Result:=ContinueLoadPPU;
          SetCurrentModule(SavedCurrentModule);
          {$IFDEF DEBUG_PPU_CYCLES}
          WriteLn('PPUALGO tppumodule.loadppu from package: ',ModuleName^,' (',StateStr,') used by "',FromModule.ModuleName^,'" (',FromModule.StateStr,')');
          {$ENDIF}
          Exit;
        end;


        { search ppu file }
        Message1(unit_u_loading_unit,ModuleName^);
        if auPPU in SearchUnitFiles(FromModule,False) then
        begin
          State:=ms_load;
          FromPPU:=True;
          LoadInterface;
        end
        else begin
          {$IFDEF DEBUG_PPU_CYCLES}
          WriteLn('PPUALGO tppumodule.try_load_ppufile ',ModuleName^,' no ppu found old=',StateStr,' new=',ms_compile);
          {$ENDIF}
          { recompile_reason is already set by search_unit_files }
          State:=ms_compile;
        end;

        Result:=ContinueLoadPPU;

        SetCurrentModule(SavedCurrentModule);
      end;

    function TPPUModule.Get_Check_Uses(out CheckImplUses, CheckCRC: Boolean): Boolean;
      begin
        CheckImplUses:=False;
        CheckCRC:=False;
        if not InterfaceCompiled then
          Exit(False);
        Result:=True;

        { if implementation was parsed then implementation uses must be checked too }
        if State=ms_load then
          CheckImplUses:=PPUWaitingForCRC
        else if FromPPU then
          CheckImplUses:=True
        else
          CheckImplUses:=State in [ms_compiling_waitfinish..ms_compiled,ms_processed];

        { if the crc(s) of used unit are known }
        CheckCRC:={$IFNDEF DisableUrCRC}not (mf_release in ModuleFlags) and{$ENDIF}
                   (FromPPU or (State in [ms_load,ms_compiled,ms_processed]));
      end;

    function TPPUModule.ContinueLoadPPU: Boolean;
      var
        SavedCurrentModule: TModule;
      begin
        Result:=False;
        SavedCurrentModule:=CurrentModule;

        Restore_State;

        if DoReload then
          InternalError(2026021017);

        if State=ms_load then
        begin
          if LoadUsedUnits then
          begin
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tppumodule.continueloadppu ',ModuleName^,' finished state=',StateStr);
            {$ENDIF}
            Message1(unit_u_finished_loading_unit,ModuleName^);
          end else if State=ms_load then
          begin
            {$IFDEF DEBUG_PPU_CYCLES}
            WriteLn('PPUALGO tppumodule.continueloadppu ',ModuleName^,' delay state=',StateStr);
            {$ENDIF}
            Store_State;
            { loading unfinished or reset, restore current_module }
            SetCurrentModule(SavedCurrentModule);
            Exit;
          end else if State<>ms_compile then
            InternalError(2026020510);
        end;

        { PPU is not needed anymore }
        if Assigned(PPUFile) then
          DiscardPPU;

        if State=ms_compiled then
        begin
          Result:=True;
          Post_Load_Or_Compile(LoadedFromModule);
        end else if State=ms_compile then
          MarkRecompileNeeded(RecompileReason);

        { finished or recompile: no need to store state }
        FreeAndNil(StoredState);

        { we are back, restore current_module }
        SetCurrentModule(SavedCurrentModule);
      end;

    function TPPUModule.CanReload(out FirstWaiting: TModule; IgnoreDoReload: Boolean): Boolean;
      var
        CheckImplUses, CheckCRC: Boolean;
        Pu: TUsedUnit;
      begin
        FirstWaiting:=nil;
        if not Get_Check_Uses(CheckImplUses, CheckCRC) then
          Exit(True);

        Pu:=TUsedUnit(UsedUnitList.First);
        while Assigned(Pu) do
        begin
          if Pu.InInterface or CheckImplUses then
          begin
            if not Pu.U.InterfaceCompiled
                or (Pu.U.DoReload and not IgnoreDoReload) then
            begin
              FirstWaiting:=Pu.U;
              Exit(False);
            end;
          end;
          Pu:=TUsedUnit(Pu.Next);
        end;
        Result:=True;
      end;

    procedure TPPUModule.Reload;
      var
        FirstWaiting: TModule;
      begin
        if not DoReload then
          InternalError(2026021015);

        if State in [ms_compiled,ms_processed] then
        begin
          WriteLn('tppumodule.reload_module ',ModuleName^,' ',StateStr);
          InternalError(2026022410);
        end;

        if not CanReload(FirstWaiting,True) then
        begin
          if DoReload then
          begin
            WriteLn('tppumodule.reload_module ',ModuleName^,' ',StateStr,' RELOAD FAILED');
            InternalError(2026022413);
          end;
          Exit;
        end;

        {$IFDEF DEBUG_PPU_CYCLES}
        WriteLn('PPUALGO tppumodule.reload ',ModuleName^,' ',StateStr,' RELOADING');
        {$ENDIF}
        Message(unit_u_forced_reload);
        DoReload:=False;
        SetCurrentModule(Self);
        Re_Resolve;
      end;

    procedure TPPUModule.DiscardPPU;
      begin
        { PPU is not needed anymore }
        if not Assigned(PPUFile) then
          Exit;
        PPUFile.CloseFile;
        PPUFile.Free;
        PPUFile:=nil;
        FreeAndNil(PackagePPUStream);
      end;

{*****************************************************************************
                               RegisterUnit
*****************************************************************************}


    function RegisterUnit(CallerModule:TModule;const S : TIDString;const FN:string; out IsNewUnit:Boolean) : TPPUModule;

          function FindCycle(AFile, SearchFor: TPPUModule; var Cycle: TFPList): Boolean;
          var
            AParent: TDependentUnit;
          begin
            { check already visited }
            if AFile.CycleSearchStamp=TPPUModule.Cycle_Stamp then
              Exit(False);
            AFile.CycleSearchStamp:=TPPUModule.Cycle_Stamp; { mark visited }

            if AFile=SearchFor then
            begin
              { unit cycle found }
              if Cycle=nil then Cycle:=TFPList.Create;
              Cycle.Add(AFile);
              //Writeln('exit at ',aFile.modulename^,' callermodule=',callermodule.modulename^,' in_interface=',callermodule.in_interface);
              Exit(True);
            end;

            AParent:=TDependentUnit(AFile.DependentUnitList.First);
            While Assigned(AParent) do
            begin
              //writeln('Registering ',Callermodule.modulename^,': checking cyclic dependency of ',aFile.modulename^, ' on ',aParent.u.modulename^);
              if AParent.InInterface then
              begin
                // writeln('Registering ',Callermodule.get_modulename,': checking cyclic dependency of ',aFile.get_modulename, ' on ',aparent.u.get_modulename);
                if FindCycle(TPPUModule(AParent.U),SearchFor,Cycle) then
                begin
                  //Writeln('Cycle found, exit at ',aParent.u.modulename^,' uses ',aFile.modulename^);
                  Cycle.Add(AFile);
                  Exit(True);
                end;
              end;
              AParent:=TDependentUnit(AParent.Next);
            end;
            Result:=False;
          end;

      var
        Ups   : TIDString;
        HP    : TPPUModule;
        Cycle : TFPList;

      begin
        { Info }
        Ups:=Upper(S);

        { search all loaded units, skip program/library }
        HP:=TPPUModule(Loaded_Units.First);
        while Assigned(HP) and ((HP.ModuleName^<>Ups) or not HP.IsUnit) do
          HP:=TPPUModule(HP.Next);

        IsNewUnit:=not Assigned(HP);
        if IsNewUnit then
        begin
          { the unit is not in the loaded units,
            we create an entry and register the unit }
          Message1(unit_u_registering_new_unit,Ups);
          HP:=TPPUModule.Create(CallerModule,S,FN,True);
          AddLoadedUnit(HP);
        end
        else if CallerModule.InInterface then
        begin
          { check for a cycle }
          Cycle:=nil;
          try
            TModule.Increase_Cycle_Stamp;
            if FindCycle(TPPUModule(CallerModule),HP,Cycle) then
            begin
              Message2(unit_f_circular_unit_reference,CallerModule.RealModuleName^,HP.RealModuleName^);
            end;
          finally
            Cycle.Free;
          end;
        end;

        { return }
        RegisterUnit:=HP;
      end;

end.
