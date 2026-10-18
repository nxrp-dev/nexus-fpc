{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Information about the current procedure that is being compiled

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
unit procinfo;

{$i fpcdefs.inc}

  interface

    uses
      { common }
      CClasses,
      { global }
      GlobType,
      { symtable }
      symconst,symtype,symdef,SymSym,
      node,
      { aasm }
      cpubase,cgbase,cgutils,
      aasmbase,aasmtai,AAsmData;

    const
      Inherited_Inlining_Flags : TProcInfoFlags =
        [pi_do_call,
         { the stack frame can't be removed in this case }
         pi_has_assembler_block,
         pi_uses_exceptions];


    type
       TSavedLabels = array[Boolean] of TAsmLabel;

       { This object gives information on the current routine being
         compiled.
       }
       TProcInfo = class(TLinkedListItem)
       private
          { list to store the procinfo's of the nested procedures }
          FNestedProcs : TLinkedList;
          { required alignment for this stackframe }
          FStackAlignment : LongInt;
       public
          { pointer to parent in nested procedures }
          Parent : TProcInfo;
          { the definition of the routine itself }
          ProcDef : TProcDef;
          { nested implicit finalization procedure, used for platform-specific
            exception handling }
          FinalizeProcInfo : TProcInfo;
          { file location of begin of procedure }
          EntryPos  : TFilePosInfo;
          { file location of end of procedure }
          ExitPos   : TFilePosInfo;
          { local switches at begin of procedure }
          EntrySwitches : TLocalSwitches;
          { local switches at end of procedure }
          ExitSwitches  : TLocalSwitches;

          { Size of the parameters on the stack }
          ParaStackSize : PInt;

          { Offset of temp after para/local are allocated }
          TempStart : LongInt;

          { some collected informations about the procedure
            see pi_xxxx constants above
          }
          Flags : TProcInfoFlags;

          { register used as frame pointer }
          FramePointer : TRegister;

          { register containing currently the got }
          GOT : TRegister;
          CurrGOTLabel : TAsmLabel;

          { register containing the tlsoffset }
          TLSOffset : TRegister;
          { reference label for tls addresses }
          TLSLabel : TAsmLabel;

          { Holds the reference used to store all saved registers. }
          SaveRegsRef : TReference;

          { Last assembler instruction of procedure prologue }
          EndPrologueAI : TLinkedListItem;

          { Amount of stack adjustment after all alignments }
          FinalLocalSize : LongInt;

          { Labels for TRUE/FALSE condition, BREAK and CONTINUE }
          CurrBreakLabel,
          CurrContinueLabel : TAsmLabel;

          { label to leave the sub routine }
          CurrExitLabel : TAsmLabel;

          { label for nested exits }
          NestedExitLabel : TLabelSym;

          { The code for the routine itself, excluding entry and
            exit code. This is a linked list of tai classes.
          }
          AktProcCode : TAsmList;
          { Data (like jump tables) that belongs to this routine }
          AktLocalData : TAsmList;

          { Nexus profiler object metadata for this physical procedure. The
            section is made associative with the procedure's COMDAT leader
            when the generated procedure lists are committed. }
          NexusProfileDescSym : TAsmSymbol;
          NexusProfileEndLabel : TAsmLabel;
          NexusProfileSection : TAISection;

          { max. of space need for parameters }
          MaxPushedParaSize : SizeInt;

          { some architectures need to know a stack size before the first compilation pass
            estimatedtempsize contains an estimated value how big temps will get }
          EstimatedTempSize : LongInt;

          { is this a constructor that calls another constructor on itself
            (either inherited, or another constructor of the same class)?
            Requires different entry code for some targets. }
          ConstructorCallingConstructor: boolean;

          { true, if an FPU instruction has been generated which could raise an exception and where the flags
            need to be checked explicitly like on RISC-V or certain ARM architectures }
          FPUExceptionCheckNeeded : Boolean;

          { local symbols and defs referenced by global functions; these need
            to be exported in case the function gets inlined }
          LocalRefSyms : TFPObjectList;
          LocalRefDefs : TFPObjectList;

          { Registers saved by the current procedure - useful for peephole optimizers }
          SavedRegsInt,
          SavedRegsAddress,
          SavedRegsMM: TCPURegisterSet;

          constructor Create(AParent:TProcInfo);virtual;
          destructor Destroy;override;

          procedure Allocate_Push_ParaSize(ASize:LongInt);

          function Calc_StackFrame_Size:LongInt;virtual;abstract;

          { Set the address of the first temp, can be used to allocate
            space for pushing parameters }
          procedure Set_First_Temp_Offset;virtual;

          { Generate parameter information }
          procedure Generate_Parameter_Info;virtual;

          { Allocate got register }
          procedure Allocate_GOT_Register(AList: TAsmList);virtual;

          { Allocate tls register }
          procedure Allocate_TLS_Register(AList: TAsmList);virtual;

          { get frame pointer }
          procedure Init_FramePointer; virtual;

          { Destroy the entire procinfo tree, starting from the outermost parent }
          procedure Destroy_Tree;

          function Get_First_NestedProc: TProcInfo;
          function Has_NestedProcs: boolean;
          function Get_Normal_Proc: TProcInfo;
          procedure AddNestedProc(AChild: TProcInfo);
          function Find_NestedProc_By_PD(AProcDef:TProcDef):TProcInfo;

          procedure Add_Local_Ref_Sym(ASym:TSym);
          procedure Export_Local_Ref_Syms;
          procedure Add_Local_Ref_Def(ADef:TDef);
          procedure Export_Local_Ref_Defs;

          procedure Add_Captured_Sym(ASym:TSym;ADef:TDef;const AFileInfo:TFilePosInfo);

          function Create_For_Outlining(const ABaseSymName: string; AStruct: TAbstractRecordDef; AProcType: TProcTypeOption; AResultDef: TDef; AEntryNodeInfo: TNode): TProcInfo;

          { Add to parent's list of nested procedures even if parent is a 'main' procedure }
          procedure Force_Nested;

          { Get the required alignment for the current stack frame }
          property StackAlignment: LongInt read FStackAlignment;
          { Update the required alignment for the current stack frame based
            on the current value and the new required alignment }
          procedure UpdateStackAlignment(AAlignment: LongInt);
          { Specific actions after the code has been generated }
          procedure PostProcess_Code; virtual;

          { set exception handling info }
          procedure Set_EH_Info; virtual;

          procedure Setup_EH; virtual;
          procedure Finish_EH; virtual;
          { called to insert needed eh info into the entry code }
          procedure Start_EH(AList : TAsmList); virtual;
          { called to insert needed eh info into the exit code }
          procedure End_EH(AList : TAsmList); virtual;
          { Mark the parentfp as used for the current nested procedure.
            Mark the parentfp as used and set pio_nested_access for all parent
            procedures until parent_level }
          procedure Set_Needs_ParentFP(AParentLevel: byte);
       end;
       TProcInfoClass = class of TProcInfo;

    var
       CProcInfo : TProcInfoClass;
       { information about the current sub routine being parsed (@var(pprocinfo))}
       CurrentProcInfo : TProcInfo;

    function Nexus_Profile_Proc_Eligible(AProcInfo: TProcInfo): boolean;

implementation

    uses
      Globals,CUtils,Systems,Verbose,FModule,
      procdefutil;

    function Nexus_Profile_Proc_Eligible(AProcInfo: TProcInfo): boolean;
      begin
        Result:=Assigned(AProcInfo) and Assigned(AProcInfo.ProcDef) and
          (TargetInfo.system=system_x86_64_win64) and
          (cs_nexus_profile in CurrentSettings.ModuleSwitches) and
          Assigned(CurrentModule) and
          Assigned(Main_Module) and
          not Main_Module.IsLibrary and
          (CurrentModule.ModuleName^<>'NXPROFILE') and
          (CurrentModule.ModuleName^<>'NXPROFILERRUNTIME') and
          not(po_assembler in AProcInfo.ProcDef.ProcOptions) and
          not(po_nostackframe in AProcInfo.ProcDef.ProcOptions) and
          not(po_interrupt in AProcInfo.ProcDef.ProcOptions) and
          (AProcInfo.ProcDef.ProcTypeOption<>potype_exceptfilter);
      end;

{****************************************************************************
                                 TProcInfo
****************************************************************************}

    constructor TProcInfo.Create(AParent:TProcInfo);
      begin
        Parent:=AParent;
        ProcDef:=nil;
        ParaStackSize:=0;
        FStackAlignment:=TargetInfo.stackalign;
        Flags:=[];
        Init_FramePointer;
        FramePointer:=NR_FRAME_POINTER_REG;
        MaxPushedParaSize:=0;
        { asmlists }
        AktProcCode:=TAsmList.Create;
        AktLocalData:=TAsmList.Create;
        NexusProfileDescSym:=nil;
        NexusProfileEndLabel:=nil;
        NexusProfileSection:=nil;
        Reference_Reset(SaveRegsRef,sizeof(aint),[]);
        { labels }
        CurrentAsmData.getjumplabel(CurrExitLabel);
        CurrentAsmData.getjumplabel(CurrGOTLabel);
        CurrBreakLabel:=nil;
        CurrContinueLabel:=nil;
        if Assigned(Parent) and (Parent.ProcDef.ParaST.SymTableLevel>=NormalFunctionLevel) then
          Parent.AddNestedProc(Self);
      end;

    procedure TProcInfo.Force_Nested;
      begin
        if Assigned(Parent) and (Parent.ProcDef.ParaST.SymTableLevel<NormalFunctionLevel) then
          Parent.AddNestedProc(Self);
      end;

    destructor TProcInfo.Destroy;
      begin
         FNestedProcs.free;
         FNestedProcs := nil;
         AktProcCode.free;
         AktProcCode := nil;
         AktLocalData.free;
         AktLocalData := nil;
         LocalRefSyms.free;
         LocalRefSyms := nil;
         LocalRefDefs.free;
         LocalRefDefs := nil;
      end;

    procedure TProcInfo.Destroy_Tree;
      var
        lProcInfo: TProcInfo;
      begin
        lProcInfo:=Self;
        while Assigned(lProcInfo.Parent) do
          lProcInfo:=lProcInfo.Parent;
        lProcInfo.Free;
        lProcInfo := nil;
      end;

    procedure TProcInfo.AddNestedProc(AChild: TProcInfo);
      begin
        if FNestedProcs=nil then
          FNestedProcs:=TLinkedList.Create;
        FNestedProcs.insert(AChild);
      end;

    function TProcInfo.Find_NestedProc_By_PD(AProcDef:TProcDef):TProcInfo;
      var
        lProcInfo : TProcInfo;
      begin
        if not Assigned(FNestedProcs) then
          exit(nil);
        lProcInfo:=TProcInfo(FNestedProcs.first);
        while Assigned(lProcInfo) do
          begin
            if lProcInfo.ProcDef=AProcDef then
              exit(lProcInfo);
            lProcInfo:=TProcInfo(lProcInfo.Next);
          end;
        Result:=nil;
      end;

    procedure TProcInfo.UpdateStackAlignment(AAlignment: LongInt);
      begin
        FStackAlignment:=max(FStackAlignment,AAlignment);
      end;

    function TProcInfo.Get_First_NestedProc: TProcInfo;
      begin
        if Assigned(FNestedProcs) then
          Result:=TProcInfo(FNestedProcs.first)
        else
          Result:=nil;
      end;

    function TProcInfo.Has_NestedProcs: boolean;
      begin
        Result:=Assigned(FNestedProcs) and (FNestedProcs.count>0);
      end;

    function TProcInfo.Get_Normal_Proc: TProcInfo;
      begin
        Result:=self;
        while Assigned(Result.Parent) and (Result.ProcDef.ParaST.SymTableLevel>NormalFunctionLevel) do
          Result:=Result.Parent;
      end;

    procedure TProcInfo.Add_Local_Ref_Sym(ASym:TSym);
      begin
        if not Assigned(LocalRefSyms) then
          LocalRefSyms:=TFPObjectList.Create(false);
        if LocalRefSyms.indexof(ASym)<0 then
          LocalRefSyms.add(ASym);
      end;

    procedure TProcInfo.Export_Local_Ref_Syms;
      var
        lIndex : LongInt;
        lSym : TSym;
      begin
        if not Assigned(LocalRefSyms) then
          exit;
        for lIndex:=0 to LocalRefSyms.count-1 do
          begin
            lSym:=TSym(LocalRefSyms[lIndex]);
            if lSym.typ<>staticvarsym then
              InternalError(2019110901);
            include(TStaticVarSym(lSym).VarOptions,vo_has_global_ref);
          end;
      end;

    procedure TProcInfo.Add_Local_Ref_Def(ADef:TDef);
      begin
        if not Assigned(LocalRefDefs) then
          LocalRefDefs:=TFPObjectList.Create(false);
        if LocalRefDefs.indexof(ADef)<0 then
          LocalRefDefs.add(ADef);
      end;

    procedure TProcInfo.Export_Local_Ref_Defs;
      var
        lIndex : LongInt;
        lDef : TDef;
        lAlias: TCmdStrListItem;
      begin
        if not Assigned(LocalRefDefs) then
          exit;
        for lIndex:=0 to LocalRefDefs.count-1 do
          begin
            lDef:=TDef(LocalRefDefs[lIndex]);
            if lDef.typ<>symconst.ProcDef then
              InternalError(2019111801);
            include(TProcDef(lDef).DefOptions,df_has_global_ref);
            { An inline body retains the referenced definition even when its
              implementation-only procsym is not loaded from a cached unit.
              Preserve its callable names independently for package exports. }
            if not (df_generic in lDef.DefOptions) and
               not (po_external in TProcDef(lDef).ProcOptions) and
               (TProcDef(lDef).ProcCallOption<>pocall_internproc) then
              begin
                CurrentModule.Add_Public_AsmSym(TProcDef(lDef).MangledName,AB_GLOBAL,AT_FUNCTION);
                lAlias:=TCmdStrListItem(TProcDef(lDef).AliasNames.first);
                while Assigned(lAlias) do
                  begin
                    CurrentModule.Add_Public_AsmSym(lAlias.str,AB_GLOBAL,AT_FUNCTION);
                    lAlias:=TCmdStrListItem(lAlias.Next);
                  end;
              end;
          end;
      end;

    procedure TProcInfo.Add_Captured_Sym(ASym:TSym;ADef:TDef;const AFileInfo:TFilePosInfo);
      begin
        ProcDef.Add_Captured_Sym(ASym,ADef,AFileInfo);
      end;

    function TProcInfo.Create_For_Outlining(const ABaseSymName: string; AStruct: TAbstractRecordDef; AProcType: TProcTypeOption; AResultDef: TDef; AEntryNodeInfo: TNode): TProcInfo;
      begin
        Result:=CProcInfo.Create(self);
        Result.Force_Nested;
        Result.ProcDef:=Create_Outline_ProcDef(ABaseSymName,AStruct,AProcType,AResultDef);
        Result.EntryPos:=AEntryNodeInfo.fileinfo;
        Result.EntrySwitches:=AEntryNodeInfo.LocalSwitches;
        Result.ExitPos:=CurrentFilePos; // filepos of last node?
        Result.ExitSwitches:=CurrentSettings.LocalSwitches; // localswitches of last node?
      end;

    procedure TProcInfo.Allocate_Push_ParaSize(ASize:LongInt);
      begin
        if ASize>MaxPushedParaSize then
          MaxPushedParaSize:=ASize;
      end;

    procedure TProcInfo.Set_First_Temp_Offset;
      begin
      end;

    procedure TProcInfo.Generate_Parameter_Info;
      begin
        { generate callee paraloc register info, it initialises the size that
          is allocated on the stack }
        ProcDef.Init_ParaLoc_Info(calleeside);
        ParaStackSize:=ProcDef.CalleeArgAreaSize;
      end;

    procedure TProcInfo.Allocate_GOT_Register(AList: TAsmList);
      begin
        { most os/cpu combo's don't use this yet, so not yet abstract }
      end;

    procedure TProcInfo.Allocate_TLS_Register(AList : TAsmList);
      begin
      end;


    procedure TProcInfo.Init_FramePointer;
      begin
        { most targets use a constant, but some have a typed constant that must
          be initialized }
      end;


    procedure TProcInfo.PostProcess_Code;
      begin
        { no action by default }
      end;


    procedure TProcInfo.Set_EH_Info;
      begin
        { default code is in tcgprocinfo }
      end;


    procedure TProcInfo.Setup_EH;
      begin
        { no action by default }
      end;


    procedure TProcInfo.Finish_EH;
      begin
        { no action by default }
      end;


    procedure TProcInfo.Start_EH(AList: TAsmList);
      begin
        { no action by default }
      end;


    procedure TProcInfo.End_EH(AList: TAsmList);
      begin
        { no action by default }
      end;


    procedure TProcInfo.Set_Needs_ParentFP(AParentLevel: byte);
      var
        lProcInfo : TProcInfo;
        lParaVarSym : TParaVarSym;
      begin
        if ProcDef.ParaST.SymTableLevel<=NormalFunctionLevel then
          InternalError(2020050302);
        if ProcDef.ParaST.SymTableLevel<=AParentLevel then
          exit;
        if AParentLevel<NormalFunctionLevel then
          AParentLevel:=NormalFunctionLevel;
        { Mark parentfp as used for the current proc }
        lProcInfo:=Self;
        TParaVarSym(lProcInfo.ProcDef.ParentFPSym).VarState:=vs_read;
        { Set both parentfp is used and pio_nested_access for all parent procs until parent_level }
        while lProcInfo.ProcDef.ParaST.SymTableLevel>AParentLevel do
          begin
            lProcInfo:=lProcInfo.Parent;
            if lProcInfo.ProcDef.ParaST.SymTableLevel>NormalFunctionLevel then
              begin
                lParaVarSym:=TParaVarSym(lProcInfo.ProcDef.ParentFPSym);
                lParaVarSym.VarState:=vs_read;
                { parentfp is accessed from a nested routine.
                  Must be in the memory. }
                lParaVarSym.VarRegable:=vr_none;
              end;
            include(lProcInfo.ProcDef.ImplProcOptions,pio_nested_access);
          end;
      end;

end.
