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
      inherited_inlining_flags : TProcInfoFlags =
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
          nestedprocs : TLinkedList;
          { required alignment for this stackframe }
          fstackalignment : LongInt;
       public
          { pointer to parent in nested procedures }
          parent : TProcInfo;
          { the definition of the routine itself }
          procdef : TProcDef;
          { nested implicit finalization procedure, used for platform-specific
            exception handling }
          finalize_procinfo : TProcInfo;
          { file location of begin of procedure }
          entrypos  : TFilePosInfo;
          { file location of end of procedure }
          exitpos   : TFilePosInfo;
          { local switches at begin of procedure }
          entryswitches : TLocalSwitches;
          { local switches at end of procedure }
          exitswitches  : TLocalSwitches;

          { Size of the parameters on the stack }
          para_stack_size : PInt;

          { Offset of temp after para/local are allocated }
          tempstart : LongInt;

          { some collected informations about the procedure
            see pi_xxxx constants above
          }
          flags : TProcInfoFlags;

          { register used as frame pointer }
          framepointer : TRegister;

          { register containing currently the got }
          got : TRegister;
          CurrGOTLabel : TAsmLabel;

          { register containing the tlsoffset }
          tlsoffset : TRegister;
          { reference label for tls addresses }
          tlslabel : TAsmLabel;

          { Holds the reference used to store all saved registers. }
          save_regs_ref : TReference;

          { Last assembler instruction of procedure prologue }
          endprologue_ai : TLinkedListItem;

          { Amount of stack adjustment after all alignments }
          final_localsize : LongInt;

          { Labels for TRUE/FALSE condition, BREAK and CONTINUE }
          CurrBreakLabel,
          CurrContinueLabel : TAsmLabel;

          { label to leave the sub routine }
          CurrExitLabel : TAsmLabel;

          { label for nested exits }
          nestedexitlabel : TLabelSym;

          { The code for the routine itself, excluding entry and
            exit code. This is a linked list of tai classes.
          }
          aktproccode : TAsmList;
          { Data (like jump tables) that belongs to this routine }
          AktLocalData : TAsmList;

          { Nexus profiler object metadata for this physical procedure. The
            section is made associative with the procedure's COMDAT leader
            when the generated procedure lists are committed. }
          nexus_profile_descsym : TAsmSymbol;
          nexus_profile_endlabel : TAsmLabel;
          nexus_profile_section : TAISection;

          { max. of space need for parameters }
          maxpushedparasize : SizeInt;

          { some architectures need to know a stack size before the first compilation pass
            estimatedtempsize contains an estimated value how big temps will get }
          estimatedtempsize : LongInt;

          { is this a constructor that calls another constructor on itself
            (either inherited, or another constructor of the same class)?
            Requires different entry code for some targets. }
          ConstructorCallingConstructor: boolean;

          { true, if an FPU instruction has been generated which could raise an exception and where the flags
            need to be checked explicitly like on RISC-V or certain ARM architectures }
          FPUExceptionCheckNeeded : Boolean;

          { local symbols and defs referenced by global functions; these need
            to be exported in case the function gets inlined }
          localrefsyms : TFPObjectList;
          localrefdefs : TFPObjectList;

          { Registers saved by the current procedure - useful for peephole optimizers }
          saved_regs_int,
          saved_regs_address,
          saved_regs_mm: TCPURegisterSet;

          constructor create(aparent:TProcInfo);virtual;
          destructor Destroy;override;

          procedure allocate_push_parasize(size:LongInt);

          function calc_stackframe_size:LongInt;virtual;abstract;

          { Set the address of the first temp, can be used to allocate
            space for pushing parameters }
          procedure set_first_temp_offset;virtual;

          { Generate parameter information }
          procedure generate_parameter_info;virtual;

          { Allocate got register }
          procedure allocate_got_register(list: TAsmList);virtual;

          { Allocate tls register }
          procedure allocate_tls_register(list: TAsmList);virtual;

          { get frame pointer }
          procedure init_framepointer; virtual;

          { Destroy the entire procinfo tree, starting from the outermost parent }
          procedure destroy_tree;

          function get_first_nestedproc: TProcInfo;
          function has_nestedprocs: boolean;
          function get_normal_proc: TProcInfo;
          procedure addnestedproc(child: TProcInfo);
          function find_nestedproc_by_pd(pd:TProcDef):TProcInfo;

          procedure add_local_ref_sym(sym:TSym);
          procedure export_local_ref_syms;
          procedure add_local_ref_def(def:TDef);
          procedure export_local_ref_defs;

          procedure Add_Captured_Sym(sym:TSym;def:TDef;const fileinfo:TFilePosInfo);

          function create_for_outlining(const basesymname: string; astruct: TAbstractRecordDef; potype: TProcTypeOption; resultdef: TDef; entrynodeinfo: TNode): TProcInfo;

          { Add to parent's list of nested procedures even if parent is a 'main' procedure }
          procedure force_nested;

          { Get the required alignment for the current stack frame }
          property stackalignment: LongInt read fstackalignment;
          { Update the required alignment for the current stack frame based
            on the current value and the new required alignment }
          procedure updatestackalignment(alignment: LongInt);
          { Specific actions after the code has been generated }
          procedure postprocess_code; virtual;

          { set exception handling info }
          procedure set_eh_info; virtual;

          procedure setup_eh; virtual;
          procedure finish_eh; virtual;
          { called to insert needed eh info into the entry code }
          procedure start_eh(list : TAsmList); virtual;
          { called to insert needed eh info into the exit code }
          procedure end_eh(list : TAsmList); virtual;
          { Mark the parentfp as used for the current nested procedure.
            Mark the parentfp as used and set pio_nested_access for all parent
            procedures until parent_level }
          procedure set_needs_parentfp(parent_level: byte);
       end;
       TProcInfoClass = class of TProcInfo;

    var
       CProcInfo : TProcInfoClass;
       { information about the current sub routine being parsed (@var(pprocinfo))}
       CurrentProcInfo : TProcInfo;

    function nexus_profile_proc_eligible(pi: TProcInfo): boolean;

implementation

    uses
      Globals,CUtils,Systems,Verbose,FModule,
      procdefutil;

    function nexus_profile_proc_eligible(pi: TProcInfo): boolean;
      begin
        result:=Assigned(pi) and Assigned(pi.procdef) and
          (TargetInfo.system=system_x86_64_win64) and
          (cs_nexus_profile in CurrentSettings.ModuleSwitches) and
          Assigned(CurrentModule) and
          Assigned(Main_Module) and
          not Main_Module.IsLibrary and
          (CurrentModule.ModuleName^<>'NXPROFILE') and
          (CurrentModule.ModuleName^<>'NXPROFILERRUNTIME') and
          not(po_assembler in pi.procdef.ProcOptions) and
          not(po_nostackframe in pi.procdef.ProcOptions) and
          not(po_interrupt in pi.procdef.ProcOptions) and
          (pi.procdef.ProcTypeOption<>potype_exceptfilter);
      end;

{****************************************************************************
                                 TProcInfo
****************************************************************************}

    constructor TProcInfo.create(aparent:TProcInfo);
      begin
        parent:=aparent;
        procdef:=nil;
        para_stack_size:=0;
        fstackalignment:=TargetInfo.stackalign;
        flags:=[];
        init_framepointer;
        framepointer:=NR_FRAME_POINTER_REG;
        maxpushedparasize:=0;
        { asmlists }
        aktproccode:=TAsmList.Create;
        AktLocalData:=TAsmList.Create;
        nexus_profile_descsym:=nil;
        nexus_profile_endlabel:=nil;
        nexus_profile_section:=nil;
        Reference_Reset(save_regs_ref,sizeof(aint),[]);
        { labels }
        CurrentAsmData.getjumplabel(CurrExitLabel);
        CurrentAsmData.getjumplabel(CurrGOTLabel);
        CurrBreakLabel:=nil;
        CurrContinueLabel:=nil;
        if Assigned(parent) and (parent.procdef.ParaST.SymTableLevel>=NormalFunctionLevel) then
          parent.addnestedproc(Self);
      end;

    procedure TProcInfo.force_nested;
      begin
        if Assigned(parent) and (parent.procdef.ParaST.SymTableLevel<NormalFunctionLevel) then
          parent.addnestedproc(Self);
      end;

    destructor TProcInfo.Destroy;
      begin
         nestedprocs.free;
         nestedprocs := nil;
         aktproccode.free;
         aktproccode := nil;
         AktLocalData.free;
         AktLocalData := nil;
         localrefsyms.free;
         localrefsyms := nil;
         localrefdefs.free;
         localrefdefs := nil;
      end;

    procedure TProcInfo.destroy_tree;
      var
        hp: TProcInfo;
      begin
        hp:=Self;
        while Assigned(hp.parent) do
          hp:=hp.parent;
        hp.Free;
        hp := nil;
      end;

    procedure TProcInfo.addnestedproc(child: TProcInfo);
      begin
        if nestedprocs=nil then
          nestedprocs:=TLinkedList.Create;
        nestedprocs.insert(child);
      end;

    function TProcInfo.find_nestedproc_by_pd(pd:TProcDef):TProcInfo;
      var
        pi : TProcInfo;
      begin
        if not Assigned(nestedprocs) then
          exit(nil);
        pi:=TProcInfo(nestedprocs.first);
        while Assigned(pi) do
          begin
            if pi.procdef=pd then
              exit(pi);
            pi:=TProcInfo(pi.next);
          end;
        result:=nil;
      end;

    procedure TProcInfo.updatestackalignment(alignment: LongInt);
      begin
        fstackalignment:=max(fstackalignment,alignment);
      end;

    function TProcInfo.get_first_nestedproc: TProcInfo;
      begin
        if Assigned(nestedprocs) then
          result:=TProcInfo(nestedprocs.first)
        else
          result:=nil;
      end;

    function TProcInfo.has_nestedprocs: boolean;
      begin
        result:=Assigned(nestedprocs) and (nestedprocs.count>0);
      end;

    function TProcInfo.get_normal_proc: TProcInfo;
      begin
        result:=self;
        while Assigned(result.parent) and (result.procdef.ParaST.SymTableLevel>NormalFunctionLevel) do
          result:=result.parent;
      end;

    procedure TProcInfo.add_local_ref_sym(sym:TSym);
      begin
        if not Assigned(localrefsyms) then
          localrefsyms:=TFPObjectList.create(false);
        if localrefsyms.indexof(sym)<0 then
          localrefsyms.add(sym);
      end;

    procedure TProcInfo.export_local_ref_syms;
      var
        i : LongInt;
        sym : TSym;
      begin
        if not Assigned(localrefsyms) then
          exit;
        for i:=0 to localrefsyms.count-1 do
          begin
            sym:=TSym(localrefsyms[i]);
            if sym.typ<>staticvarsym then
              InternalError(2019110901);
            include(TStaticVarSym(sym).VarOptions,vo_has_global_ref);
          end;
      end;

    procedure TProcInfo.add_local_ref_def(def:TDef);
      begin
        if not Assigned(localrefdefs) then
          localrefdefs:=TFPObjectList.create(false);
        if localrefdefs.indexof(def)<0 then
          localrefdefs.add(def);
      end;

    procedure TProcInfo.export_local_ref_defs;
      var
        i : LongInt;
        def : TDef;
        lAlias: TCmdStrListItem;
      begin
        if not Assigned(localrefdefs) then
          exit;
        for i:=0 to localrefdefs.count-1 do
          begin
            def:=TDef(localrefdefs[i]);
            if def.typ<>symconst.procdef then
              InternalError(2019111801);
            include(TProcDef(def).DefOptions,df_has_global_ref);
            { An inline body retains the referenced definition even when its
              implementation-only procsym is not loaded from a cached unit.
              Preserve its callable names independently for package exports. }
            if not (df_generic in def.DefOptions) and
               not (po_external in TProcDef(def).ProcOptions) and
               (TProcDef(def).ProcCallOption<>pocall_internproc) then
              begin
                CurrentModule.Add_Public_AsmSym(TProcDef(def).MangledName,AB_GLOBAL,AT_FUNCTION);
                lAlias:=TCmdStrListItem(TProcDef(def).AliasNames.first);
                while Assigned(lAlias) do
                  begin
                    CurrentModule.Add_Public_AsmSym(lAlias.str,AB_GLOBAL,AT_FUNCTION);
                    lAlias:=TCmdStrListItem(lAlias.next);
                  end;
              end;
          end;
      end;

    procedure TProcInfo.Add_Captured_Sym(sym:TSym;def:TDef;const fileinfo:TFilePosInfo);
      begin
        procdef.Add_Captured_Sym(sym,def,fileinfo);
      end;

    function TProcInfo.create_for_outlining(const basesymname: string; astruct: TAbstractRecordDef; potype: TProcTypeOption; resultdef: TDef; entrynodeinfo: TNode): TProcInfo;
      begin
        result:=CProcInfo.create(self);
        result.force_nested;
        result.procdef:=Create_Outline_ProcDef(basesymname,astruct,potype,resultdef);
        result.entrypos:=entrynodeinfo.fileinfo;
        result.entryswitches:=entrynodeinfo.LocalSwitches;
        result.exitpos:=CurrentFilePos; // filepos of last node?
        result.exitswitches:=CurrentSettings.LocalSwitches; // localswitches of last node?
      end;

    procedure TProcInfo.allocate_push_parasize(size:LongInt);
      begin
        if size>maxpushedparasize then
          maxpushedparasize:=size;
      end;

    procedure TProcInfo.set_first_temp_offset;
      begin
      end;

    procedure TProcInfo.generate_parameter_info;
      begin
        { generate callee paraloc register info, it initialises the size that
          is allocated on the stack }
        procdef.Init_ParaLoc_Info(calleeside);
        para_stack_size:=procdef.CalleeArgAreaSize;
      end;

    procedure TProcInfo.allocate_got_register(list: TAsmList);
      begin
        { most os/cpu combo's don't use this yet, so not yet abstract }
      end;

    procedure TProcInfo.allocate_tls_register(list : TAsmList);
      begin
      end;


    procedure TProcInfo.init_framepointer;
      begin
        { most targets use a constant, but some have a typed constant that must
          be initialized }
      end;


    procedure TProcInfo.postprocess_code;
      begin
        { no action by default }
      end;


    procedure TProcInfo.set_eh_info;
      begin
        { default code is in tcgprocinfo }
      end;


    procedure TProcInfo.setup_eh;
      begin
        { no action by default }
      end;


    procedure TProcInfo.finish_eh;
      begin
        { no action by default }
      end;


    procedure TProcInfo.start_eh(list: TAsmList);
      begin
        { no action by default }
      end;


    procedure TProcInfo.end_eh(list: TAsmList);
      begin
        { no action by default }
      end;


    procedure TProcInfo.set_needs_parentfp(parent_level: byte);
      var
        pi : TProcInfo;
        p : TParaVarSym;
      begin
        if procdef.ParaST.SymTableLevel<=NormalFunctionLevel then
          InternalError(2020050302);
        if procdef.ParaST.SymTableLevel<=parent_level then
          exit;
        if parent_level<NormalFunctionLevel then
          parent_level:=NormalFunctionLevel;
        { Mark parentfp as used for the current proc }
        pi:=Self;
        TParaVarSym(pi.procdef.ParentFPSym).VarState:=vs_read;
        { Set both parentfp is used and pio_nested_access for all parent procs until parent_level }
        while pi.procdef.ParaST.SymTableLevel>parent_level do
          begin
            pi:=pi.parent;
            if pi.procdef.ParaST.SymTableLevel>NormalFunctionLevel then
              begin
                p:=TParaVarSym(pi.procdef.ParentFPSym);
                p.VarState:=vs_read;
                { parentfp is accessed from a nested routine.
                  Must be in the memory. }
                p.VarRegable:=vr_none;
              end;
            include(pi.procdef.ImplProcOptions,pio_nested_access);
          end;
      end;

end.
