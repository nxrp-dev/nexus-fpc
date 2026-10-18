{
    Copyright (c) 2011-2020 by Free Pascal development team

    Generate Win64-specific exception handling code (based on x86_64 code)

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
unit ncpuflw;

{$i fpcdefs.inc}

interface

  uses
    node,nflw,ncgflw,psub;

  type
    TAArch64RaiseNode=class(TCGRaiseNode)
      function Pass_1 : TNode;override;
    end;

    TAArch64OnNode=class(TCGOnNode)
      procedure Pass_Generate_Code;override;
    end;

    TAArch64TryExceptNode=class(TCGTryExceptNode)
      procedure Pass_Generate_Code;override;
    end;

    TAArch64TryFinallyNode=class(TCGTryFinallyNode)
      FinalizationProcInfo: TCGProcInfo;
      constructor Create(ALeft,ARight:TNode);override;
      constructor Create_Implicit(ALeft,ARight:TNode);override;
      function Simplify(AForInline: boolean): TNode;override;
      procedure Pass_Generate_Code;override;
      function DoGetCopy:TNode;override;
    end;

implementation

  uses
    GlobType,Globals,Verbose,Systems,FModule,
    nbas,ncal,nutils,
    symconst,SymSym,symdef,
    cgbase,cgobj,cgutils,tgobj,
    cpubase,htypechk,
    Pass_1,pass_2,
    aasmbase,aasmtai,AAsmData,aasmcpu,
    ProcInfo,cpupi,procdefutil;

  var
    EndExceptLabel: TAsmLabel;


{ taarch64raisenode }

function TAArch64RaiseNode.Pass_1 : TNode;
  var
    lStatements : TStatementNode;
    lRaiseNode : TCallNode;
  begin
    { difference from generic code is that address stack is not popped on reraise }
    if (TargetInfo.system<>system_aarch64_win64) or Assigned(Left) then
      Result:=inherited Pass_1
    else
      begin
        Result:=InternalStatements(lStatements);
        lRaiseNode:=CCallNode.CreateIntern('fpc_reraise',nil);
        include(lRaiseNode.CallNodeFlags,cnf_call_never_returns);
        AddStatement(lStatements,lRaiseNode);
      end;
end;

{ taarch64onnode }

procedure TAArch64OnNode.Pass_Generate_Code;
  var
    lExceptVarSym : TLocalVarSym;
  begin
    if (TargetInfo.system<>system_aarch64_win64) then
      begin
        inherited Pass_Generate_Code;
        exit;
      end;

    Location_Reset(Location,LOC_VOID,OS_NO);

    { RTL will put exceptobject into X0 when jumping here }
    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_FUNCTION_RESULT_REG);

    { Retrieve exception variable }
    if Assigned(ExceptSymTable) then
      lExceptVarSym:=TLocalVarSym(ExceptSymTable.SymList[0])
    else
      lExceptVarSym:=nil;

    if Assigned(lExceptVarSym) then
      begin
        lExceptVarSym.LocAlloc.Loc:=LOC_REFERENCE;
        lExceptVarSym.LocAlloc.Size:=OS_ADDR;
        TG.GetLocal(CurrentAsmData.CurrAsmList,sizeof(PInt),VoidPointerType,lExceptVarSym.LocAlloc.Reference);
        cg.A_Load_Reg_Ref(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,NR_FUNCTION_RESULT_REG,lExceptVarSym.LocAlloc.Reference);
      end;
    cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_FUNCTION_RESULT_REG);

    if Assigned(Right) then
      SecondPass(Right);

    { deallocate exception symbol }
    if Assigned(lExceptVarSym) then
      begin
        TG.UnGetLocal(CurrentAsmData.CurrAsmList,lExceptVarSym.LocAlloc.Reference);
        lExceptVarSym.LocAlloc.Loc:=LOC_INVALID;
      end;
    cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
    cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,EndExceptLabel);
  end;

{ taarch64tryfinallynode }

function ResetRegVars(var ANode: TNode; AArg: pointer): TForEachNodeResult;
  begin
    case ANode.nodetype of
      temprefn:
        make_not_regable(ANode,[]);
      calln:
        include(TProcInfo(AArg).Flags,pi_do_call);
      else
        ;
    end;
    Result:=fen_true;
  end;

function CopyParaSize(var ANode: TNode; AArg: pointer): TForEachNodeResult;
  begin
    case ANode.nodetype of
      calln:
        TCGProcInfo(AArg).Allocate_Push_ParaSize(TCallNode(ANode).PushedParaSize);
      else
        ;
    end;
    Result:=fen_true;
  end;

constructor TAArch64TryFinallyNode.Create(ALeft, ARight: TNode);
  begin
    inherited Create(ALeft,ARight);
    if (TargetInfo.system=system_aarch64_win64) and
      { Don't create child procedures for generic methods, their nested-like
        behavior causes compilation errors because real nested procedures
        aren't allowed for generics. Not creating them doesn't harm because
        generic node tree is discarded without generating code. }
       not (df_generic in CurrentProcInfo.ProcDef.DefOptions) then
      begin
        FinalizationProcInfo:=TCGProcInfo(CurrentProcInfo.Create_For_Outlining('$fin$',CurrentProcInfo.ProcDef.struct,potype_exceptfilter,VoidType,ARight));
        { the init/final code is messing with asm nodes, so inform the compiler about this }
        include(FinalizationProcInfo.Flags,pi_has_assembler_block);
        { Regvar optimization for symbols is suppressed when using exceptions, but
          temps may be still placed into registers. This must be fixed. }
        ForEachNodeStatic(ARight,@ResetRegVars,FinalizationProcInfo);
      end;
  end;

constructor TAArch64TryFinallyNode.Create_Implicit(ALeft, ARight: TNode);
  begin
    inherited Create_Implicit(ALeft, ARight);
    if (TargetInfo.system=system_aarch64_win64) then
      begin
        if df_generic in CurrentProcInfo.ProcDef.DefOptions then
          InternalError(2020033101);

        FinalizationProcInfo:=TCGProcInfo(CurrentProcInfo.Create_For_Outlining('$fin$',CurrentProcInfo.ProcDef.struct,potype_exceptfilter,VoidType,ARight));
        include(FinalizationProcInfo.Flags,pi_do_call);
        { the init/final code is messing with asm nodes, so inform the compiler about this }
        include(FinalizationProcInfo.Flags,pi_has_assembler_block);
      end;
  end;

function TAArch64TryFinallyNode.Simplify(AForInline: boolean): TNode;
  begin
    Result:=inherited Simplify(AForInline);
    if (TargetInfo.system<>system_aarch64_win64) then
      exit;
    if (Result=nil) then
      begin
        { actually, this is not really the right place to do a node transformation like this }
        if not(Assigned(FinalizationProcInfo.Code)) then
          begin
            FinalizationProcInfo.Code:=Right;
            ForEachNodeStatic(Right,@CopyParaSize,FinalizationProcInfo);
            Right:=CCallNode.Create(nil,TProcSym(FinalizationProcInfo.ProcDef.ProcSym),nil,nil,[],nil);
            FirstPass(Right);
            { For implicit frames, no actual code is available at this time,
              it is added later in assembler form. So store the nested procinfo
              for later use. }
            if ImplicitFrame then
              begin
                CurrentProcInfo.FinalizeProcInfo:=FinalizationProcInfo;
              end;
          end;
      end;
  end;

procedure EmitNop;
  var
    lDummyLabel: TAsmLabel;
  begin
    { To avoid optimizing away the whole thing, prepend a jumplabel with increased refcount }
    CurrentAsmData.getjumplabel(lDummyLabel);
    lDummyLabel.increfs;
    cg.A_Label(CurrentAsmData.CurrAsmList,lDummyLabel);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_NOP));
  end;

procedure TAArch64TryFinallyNode.Pass_Generate_Code;
  var
    lTryLabel,
    lEndTryLabel,
    lFinallyLabel,
    lEndFinallyLabel,
    lTempLabel,
    lOldExitLabel: TAsmLabel;
    lOldFlowControl: TFlowControl;
    lCatchFrame: boolean;
  begin
    if (TargetInfo.system<>system_aarch64_win64) then
      begin
        inherited Pass_Generate_Code;
        exit;
      end;

    Location_Reset(Location,LOC_VOID,OS_NO);

    { Do not generate a frame that catches exceptions if the only action
      would be reraising it. Doing so is extremely inefficient with SEH
      (in contrast with setjmp/longjmp exception handling) }
    lCatchFrame:=ImplicitFrame and
      (CurrentProcInfo.ProcDef.ProcCallOption=pocall_safecall);

    lOldFlowControl:=flowcontrol;
    flowcontrol:=[fc_inflowcontrol];

    lTempLabel:=nil;
    CurrentAsmData.getjumplabel(lTryLabel);
    CurrentAsmData.getjumplabel(lEndTryLabel);
    CurrentAsmData.getjumplabel(lFinallyLabel);
    CurrentAsmData.getjumplabel(lEndFinallyLabel);
    lOldExitLabel:=CurrentProcInfo.CurrExitLabel;
    if ImplicitFrame then
      CurrentProcInfo.CurrExitLabel:=lFinallyLabel;

    { Start of scope }
    { Padding with NOP is necessary here because exceptions in called
      procedures are seen at the next instruction, while CPU/OS exceptions
      like AV are seen at the current instruction.

      So in the following code

      raise_some_exception;        //(a)
      try
        pchar(nil)^:='0';          //(b)
        ...

      without NOP, exceptions (a) and (b) will be seen at the same address
      and fall into the same scope. However they should be seen in different scopes.
    }

    EmitNop;
    cg.A_Label(CurrentAsmData.CurrAsmList,lTryLabel);

    { try code }
    if Assigned(Left) then
      begin
        { fc_unwind_xx tells exit/continue/break statements to emit special
          unwind code instead of just JMP }
        if not ImplicitFrame then
          flowcontrol:=flowcontrol+[fc_catching_exceptions,fc_unwind_exit,fc_unwind_loop];
        SecondPass(Left);
        flowcontrol:=flowcontrol-[fc_catching_exceptions,fc_unwind_exit,fc_unwind_loop];
        if CodeGenError then
          exit;
      end;

    { finallylabel is only used in implicit frames as an exit point from nested try..finally
      statements, if any. To prevent finalizer from being executed twice, it must come before
      endtrylabel (bug #34772) }
    if lCatchFrame then
      begin
        CurrentAsmData.getjumplabel(lTempLabel);
        cg.A_Label(CurrentAsmData.CurrAsmList, lFinallyLabel);
        { jump over exception handler }
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lTempLabel);
        { Handle the except block first, so endtrylabel serves both
          as end of scope and as unwind target. This way it is possible to
          encode everything into a single scope record. }
        cg.A_Label(CurrentAsmData.CurrAsmList,lEndTryLabel);
        if (CurrentProcInfo.ProcDef.ProcCallOption=pocall_safecall) then
          begin
            Handle_SafeCall_Exception;
            cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lEndFinallyLabel);
          end
        else
          InternalError(2014031601);
        cg.A_Label(CurrentAsmData.CurrAsmList,lTempLabel);
      end
    else
      begin
        { same as emit_nop but using finallylabel instead of dummy }
        cg.A_Label(CurrentAsmData.CurrAsmList,lFinallyLabel);
        lFinallyLabel.increfs;
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_NOP));
        cg.A_Label(CurrentAsmData.CurrAsmList,lEndTryLabel);
      end;

    { i32913 - if the try..finally block is also inside a try..finally or
      try..except block, make a note of any Exit calls so all necessary labels
      are generated. [Kit] }
    if ((flowcontrol*[fc_exit,fc_break,fc_continue])<>[]) and (fc_inflowcontrol in lOldFlowControl) then
      lOldFlowControl:=lOldFlowControl+(flowcontrol*[fc_exit,fc_break,fc_continue]);

    flowcontrol:=[fc_inflowcontrol];
    { store the tempflags so that we can generate the finally handler later on }
    if not ImplicitFrame then
      FinalizationProcInfo.Store_TempFlags;
    { right is a call to finalizer procedure }
    SecondPass(Right);

    if CodeGenError then
      exit;

    { normal exit from safecall proc must zero the result register }
    if ImplicitFrame and (CurrentProcInfo.ProcDef.ProcCallOption=pocall_safecall) then
      cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_INT,0,NR_FUNCTION_RESULT_REG);

    cg.A_Label(CurrentAsmData.CurrAsmList,lEndFinallyLabel);

    { generate the scope record in .xdata }
    TCPUProcInfo(CurrentProcInfo).Add_Finally_Scope(lTryLabel,lEndTryLabel,
      CurrentAsmData.RefAsmSymbol(FinalizationProcInfo.ProcDef.MangledName,AT_FUNCTION),lCatchFrame);

    if ImplicitFrame then
      CurrentProcInfo.CurrExitLabel:=lOldExitLabel;
    flowcontrol:=lOldFlowControl;
  end;

function TAArch64TryFinallyNode.DoGetCopy: TNode;
  var
    lNode : TAArch64TryFinallyNode;
  begin
    lNode:=TAArch64TryFinallyNode(inherited DoGetCopy);
    if (TargetInfo.system=system_aarch64_win64) then
      begin
        lNode.FinalizationProcInfo:=TCGProcInfo(CProcInfo.Create(FinalizationProcInfo.Parent));
        lNode.FinalizationProcInfo.Force_Nested;
        lNode.FinalizationProcInfo.ProcDef:=Create_Outline_ProcDef('$fin$',CurrentProcInfo.ProcDef.struct,potype_exceptfilter,VoidType);
        lNode.FinalizationProcInfo.EntryPos:=FinalizationProcInfo.EntryPos;
        lNode.FinalizationProcInfo.EntrySwitches:=FinalizationProcInfo.EntrySwitches;
        lNode.FinalizationProcInfo.ExitPos:=FinalizationProcInfo.ExitPos;
        lNode.FinalizationProcInfo.ExitSwitches:=FinalizationProcInfo.ExitSwitches;
        lNode.FinalizationProcInfo.Flags:=FinalizationProcInfo.Flags;
        { node already transformed? }
        if Assigned(FinalizationProcInfo.Code) then
          begin
            lNode.FinalizationProcInfo.Code:=FinalizationProcInfo.Code.GetCopy;
            lNode.Right:=CCallNode.Create(nil,TProcSym(lNode.FinalizationProcInfo.ProcDef.ProcSym),nil,nil,[],nil);
            FirstPass(lNode.Right);
          end;
      end;
    Result:=lNode;
  end;


{ taarch64tryexceptnode }

procedure TAArch64TryExceptNode.Pass_Generate_Code;
  var
    lTryLabel,
    lExceptLabel,lOldEndExceptLabel,
    lLastOnLabel,
    lExitExceptLabel,
    lContinueExceptLabel,
    lBreakExceptLabel,
    lOldCurrExitLabel,
    lOldContinueLabel,
    lOldBreakLabel : TAsmLabel;
    lOnLabel,
    lFilterLabel: TAsmLabel;
    lOldFlowControl,lTryFlowControl,
    lExceptFlowControl : TFlowControl;
    lNode : TNode;
    lList : TAsmList;
    lOnNodeCount : TAIConst;
    lSymbol : TAsmSymbol;
  label
    errorexit;
  begin
    if (TargetInfo.system<>system_aarch64_win64) then
      begin
        inherited Pass_Generate_Code;
        exit;
      end;
    Location_Reset(Location,LOC_VOID,OS_NO);

    lOldFlowControl:=flowcontrol;
    lExceptFlowControl:=[];
    lContinueExceptLabel:=nil;
    lBreakExceptLabel:=nil;

    include(flowcontrol,fc_inflowcontrol);
    { this can be called recursively }
    lOldBreakLabel:=nil;
    lOldContinueLabel:=nil;
    lOldEndExceptLabel:=EndExceptLabel;

    { save the old labels for control flow statements }
    lOldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
    CurrentAsmData.getjumplabel(lExitExceptLabel);
    if Assigned(CurrentProcInfo.CurrBreakLabel) then
      begin
        lOldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
        lOldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
        CurrentAsmData.getjumplabel(lBreakExceptLabel);
        CurrentAsmData.getjumplabel(lContinueExceptLabel);
      end;

    CurrentAsmData.getjumplabel(lExceptLabel);
    CurrentAsmData.getjumplabel(EndExceptLabel);
    CurrentAsmData.getjumplabel(lLastOnLabel);
    lFilterLabel:=nil;

    { start of scope }
    CurrentAsmData.getjumplabel(lTryLabel);
    EmitNop;
    cg.A_Label(CurrentAsmData.CurrAsmList,lTryLabel);

    { control flow in try block needs no special handling,
      just make sure that target labels are outside the scope }
    SecondPass(Left);
    lTryFlowControl:=flowcontrol;
    if CodeGenError then
      goto errorexit;

    { jump over except handlers }
    cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,EndExceptLabel);

    { end of scope }
    cg.A_Label(CurrentAsmData.CurrAsmList,lExceptLabel);

    { set control flow labels for the except block }
    { and the on statements                        }
    CurrentProcInfo.CurrExitLabel:=lExitExceptLabel;
    if Assigned(lOldBreakLabel) then
      begin
        CurrentProcInfo.CurrContinueLabel:=lContinueExceptLabel;
        CurrentProcInfo.CurrBreakLabel:=lBreakExceptLabel;
      end;

    flowcontrol:=[fc_inflowcontrol];
    { on statements }
    if Assigned(Right) then
      begin
        { emit filter table to a temporary asmlist }
        lList:=TAsmList.Create;
        CurrentAsmData.getaddrlabel(lFilterLabel);
        new_section(lList,sec_rodata_norel,lFilterLabel.name,4);
        cg.A_Label(lList,lFilterLabel);
        lOnNodeCount:=TAIConst.create_32bit(0);
        lList.concat(lOnNodeCount);

        lNode:=Right;
        while Assigned(lNode) do
          begin
            if lNode.nodetype<>onn then
              InternalError(2011103101);
            CurrentAsmData.getjumplabel(lOnLabel);
            lSymbol:=CurrentAsmData.RefAsmSymbol(TOnNode(lNode).ExceptType.VMT_MangledName,AT_DATA,true);
            lList.concat(TAIConst.create_rva_sym(lSymbol));
            lList.concat(TAIConst.create_rva_sym(lOnLabel));
            CurrentModule.Add_Extern_AsmSym(lSymbol);
            cg.A_Label(CurrentAsmData.CurrAsmList,lOnLabel);
            SecondPass(lNode);
            inc(lOnNodeCount.Value);
            lNode:=TOnNode(lNode).Left;
          end;
        { add 'else' node to the filter list, too }
        if Assigned(t1) then
          begin
            lList.concat(TAIConst.create_32bit(-1));
            lList.concat(TAIConst.create_rva_sym(lLastOnLabel));
            inc(lOnNodeCount.Value);
          end;
        { now move filter table to permanent list all at once }
        CurrentProcInfo.AktLocalData.ConcatList(lList);
        lList.free;
      end;

    cg.A_Label(CurrentAsmData.CurrAsmList,lLastOnLabel);
    if Assigned(t1) then
      begin
        { here we don't have to reset flowcontrol           }
        { the default and on flowcontrols are handled equal }
        SecondPass(t1);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        if (flowcontrol*[fc_exit,fc_break,fc_continue]<>[]) then
          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,EndExceptLabel);
      end;
    lExceptFlowControl:=flowcontrol;

    if fc_exit in lExceptFlowControl then
      begin
        { do some magic for exit in the try block }
        cg.A_Label(CurrentAsmData.CurrAsmList,lExitExceptLabel);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        if (fc_unwind_exit in lOldFlowControl) then
          cg.G_Local_Unwind(CurrentAsmData.CurrAsmList,lOldCurrExitLabel)
        else
          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldCurrExitLabel);
      end;

    if fc_break in lExceptFlowControl then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,lBreakExceptLabel);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        if (fc_unwind_loop in lOldFlowControl) then
          cg.G_Local_Unwind(CurrentAsmData.CurrAsmList,lOldBreakLabel)
        else
          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldBreakLabel);
      end;

    if fc_continue in lExceptFlowControl then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,lContinueExceptLabel);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        if (fc_unwind_loop in lOldFlowControl) then
          cg.G_Local_Unwind(CurrentAsmData.CurrAsmList,lOldContinueLabel)
        else
          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldContinueLabel);
      end;

    EmitNop;
    cg.A_Label(CurrentAsmData.CurrAsmList,EndExceptLabel);
    TCPUProcInfo(CurrentProcInfo).Add_Except_Scope(lTryLabel,lExceptLabel,EndExceptLabel,lFilterLabel);

errorexit:
    { restore all saved labels }
    EndExceptLabel:=lOldEndExceptLabel;

    { restore the control flow labels }
    CurrentProcInfo.CurrExitLabel:=lOldCurrExitLabel;
    if Assigned(lOldBreakLabel) then
      begin
        CurrentProcInfo.CurrContinueLabel:=lOldContinueLabel;
        CurrentProcInfo.CurrBreakLabel:=lOldBreakLabel;
      end;

    { return all used control flow statements }
    flowcontrol:=lOldFlowControl+(lExceptFlowControl +
      lTryFlowControl - [fc_inflowcontrol]);
  end;

initialization
  CRaiseNode:=TAArch64RaiseNode;
  COnNode:=TAArch64OnNode;
  CTryExceptNode:=TAArch64TryExceptNode;
  CTryFinallyNode:=TAArch64TryFinallyNode;
end.

