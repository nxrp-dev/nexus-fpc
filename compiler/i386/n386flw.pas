{
    Copyright (c) 2011 by Free Pascal development team

    Generate Win32-specific exception handling code

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
unit n386flw;

{$i fpcdefs.inc}

interface

  uses
    node,nflw,ncgflw,psub;

  type
    TI386RaiseNode=class(TCGRaiseNode)
      function Pass_1 : TNode;override;
    end;

    TI386OnNode=class(TCGOnNode)
      procedure Pass_Generate_Code;override;
    end;

    TI386TryExceptNode=class(TCGTryExceptNode)
      procedure Pass_Generate_Code;override;
    end;

    TI386TryFinallyNode=class(TCGTryFinallyNode)
      FinalizationProcInfo: TCGProcInfo;
      constructor Create(ALeft,ARight:TNode);override;
      constructor Create_Implicit(ALeft,ARight:TNode);override;
      function Pass_1: TNode;override;
      function DoGetCopy : TNode;override;
      function Simplify(AForInline: boolean): TNode;override;
      procedure Pass_Generate_Code;override;
    end;

implementation

  uses
    CUtils,GlobType,Globals,Verbose,Systems,FModule,
    nbas,ncal,nmem,nutils,
    symconst,SymBase,SymTable,SymSym,symdef,
    cgbase,cgobj,cgcpu,cgutils,tgobj,
    cpubase,htypechk,
    parabase,paramgr,Pass_1,pass_2,ncgutil,cga,
    aasmbase,aasmtai,AAsmData,aasmcpu,ProcInfo,cpupi,procdefutil;

  var
    EndExceptLabel: TAsmLabel;


{ ti386raisenode }

function TI386RaiseNode.Pass_1 : TNode;
  var
    lStatements : TStatementNode;
    lRaiseNode : TCallNode;
  begin
    { difference from generic code is that address stack is not popped on reraise }
    if (TargetInfo.system<>system_i386_win32) or Assigned(Left) then
      Result:=inherited Pass_1
    else
      begin
        Result:=InternalStatements(lStatements);
        lRaiseNode:=CCallNode.CreateIntern('fpc_reraise',nil);
        include(lRaiseNode.CallNodeFlags,cnf_call_never_returns);
        AddStatement(lStatements,lRaiseNode);
      end;
end;

{ ti386onnode }

procedure TI386OnNode.Pass_Generate_Code;
  var
    lOldFlowControl : TFlowControl;
    lExceptVarSym : TLocalVarSym;
  begin
    if (TargetInfo.system<>system_i386_win32) then
      begin
        inherited Pass_Generate_Code;
        exit;
      end;

    Location_Reset(Location,LOC_VOID,OS_NO);

    lOldFlowControl:=flowcontrol;
    flowcontrol:=[fc_inflowcontrol];

    { RTL will put exceptobject into EAX when jumping here }
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

    flowcontrol:=lOldFlowControl+(flowcontrol-[fc_inflowcontrol]);
  end;

{ ti386tryfinallynode }

function ResetRegVars(var ANode: TNode; AArg: pointer): TForEachNodeResult;
  begin
    case ANode.nodetype of
      temprefn:
        Make_Not_Regable(ANode,[]);
      calln:
        include(TProcInfo(AArg).Flags,pi_do_call);
      else ;
    end;
    Result:=fen_true;
  end;

function CopyParaSize(var ANode: TNode; AArg: pointer): TForEachNodeResult;
  begin
    if ANode.nodetype=calln then
        TCGProcInfo(AArg).Allocate_Push_ParaSize(TCallNode(ANode).PushedParaSize);
    Result:=fen_true;
  end;

constructor TI386TryFinallyNode.Create(ALeft, ARight: TNode);
  begin
    inherited Create(ALeft,ARight);
    if (TargetInfo.system<>system_i386_win32) or
      { Don't create child procedures for generic methods, their nested-like
        behavior causes compilation errors because real nested procedures
        aren't allowed for generics. Not creating them doesn't harm because
        generic node tree is discarded without generating code. }
      (df_generic in CurrentProcInfo.ProcDef.DefOptions)
      then
      exit;
    FinalizationProcInfo:=TCGProcInfo(CurrentProcInfo.Create_For_Outlining('$fin$',CurrentProcInfo.ProcDef.struct,potype_exceptfilter,VoidType,ARight));
    { Regvar optimization for symbols is suppressed when using exceptions, but
      temps may be still placed into registers. This must be fixed. }
    ForEachNodeStatic(ARight,@ResetRegVars,FinalizationProcInfo);
    include(FinalizationProcInfo.Flags,pi_has_assembler_block);
    include(FinalizationProcInfo.Flags,pi_do_call);
    include(FinalizationProcInfo.Flags,pi_uses_exceptions);
  end;

constructor TI386TryFinallyNode.Create_Implicit(ALeft, ARight: TNode);
  begin
    inherited Create_Implicit(ALeft, ARight);
    if (TargetInfo.system<>system_i386_win32) then
      exit;

    { safecall procedures can handle implicit finalization as part of "except" flow }
    if ImplicitFrame and (CurrentProcInfo.ProcDef.ProcCallOption=pocall_safecall) then
      exit;

    if df_generic in CurrentProcInfo.ProcDef.DefOptions then
      InternalError(2013012501);

    FinalizationProcInfo:=TCGProcInfo(CurrentProcInfo.Create_For_Outlining('$fin$',CurrentProcInfo.ProcDef.struct,potype_exceptfilter,VoidType,ARight));
    include(FinalizationProcInfo.Flags,pi_has_assembler_block);
    include(FinalizationProcInfo.Flags,pi_do_call);
    include(FinalizationProcInfo.Flags,pi_uses_exceptions);
  end;


function TI386TryFinallyNode.Pass_1: TNode;
  var
    lSelfSym: TParaVarSym;
  begin
    Result:=inherited Pass_1;
    if (TargetInfo.system=system_i386_win32) then
      begin
        { safecall method will access 'self' from except block -> make it non-regable }
        if ImplicitFrame and (CurrentProcInfo.ProcDef.ProcCallOption=pocall_safecall) and
          Is_Class(CurrentProcInfo.ProcDef.struct) then
          begin
            lSelfSym:=TParaVarSym(CurrentProcInfo.ProcDef.ParaST.Find('self'));
            if (lSelfSym=nil) or (lSelfSym.typ<>paravarsym) then
              InternalError(2011123102);
            lSelfSym.VarRegable:=vr_none;
          end;
      end;
  end;

function TI386TryFinallyNode.DoGetCopy: TNode;
  var
    lNode: TI386TryFinallyNode;
  begin
    lNode:=TI386TryFinallyNode(inherited DoGetCopy);
    if TargetInfo.system=system_i386_win32 then
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

function TI386TryFinallyNode.Simplify(AForInline: boolean): TNode;
  begin
    Result:=inherited Simplify(AForInline);
    if (TargetInfo.system<>system_i386_win32) then
      exit;

    { actually, this is not really the right place to do a node transformation like this }
    if (Result=nil) and Assigned(FinalizationProcInfo) and (not(Assigned(FinalizationProcInfo.Code))) then
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


procedure EmitScopeStart(AHandler,AData: TAsmSymbol);
  var
    lReference: TReference;
    lReg: TRegister;
  begin
    lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
    Reference_Reset_Base(lReference,lReg,0,CTempPosInvalid,sizeof(PInt),[]);
    lReference.Segment:=NR_FS;
    emit_reg_reg(A_XOR,S_L,lReg,lReg);
    emit_sym(A_PUSH,S_L,AData);
    emit_reg(A_PUSH,S_L,NR_FRAME_POINTER_REG);
    emit_sym(A_PUSH,S_L,AHandler);
    emit_ref(A_PUSH,S_L,lReference);
    emit_reg_ref(A_MOV,S_L,NR_ESP,lReference);
  end;

procedure EmitScopeEnd;
  var
    lReference: TReference;
    lReg,lReg2: TRegister;
  begin
    lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
    lReg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
    Reference_Reset_Base(lReference,lReg,0,CTempPosInvalid,sizeof(PInt),[]);
    lReference.Segment:=NR_FS;
    emit_reg_reg(A_XOR,S_L,lReg,lReg);
    emit_reg(A_POP,S_L,lReg2);
    emit_const_reg(A_ADD,S_L,3*sizeof(PInt),NR_ESP);
    emit_reg_ref(A_MOV,S_L,lReg2,lReference);
  end;

procedure TI386TryFinallyNode.Pass_Generate_Code;
  var
    lFinallyLabel,
    lExceptLabel,
    lSafeCallLabel,
    lEndFinallyLabel,
    lExitFinallyLabel,
    lContinueFinallyLabel,
    lBreakFinallyLabel,
    lOldCurrExitLabel,
    lOldContinueLabel,
    lOldBreakLabel : TAsmLabel;
    lOldFlowControl,lTryFlowControl : TFlowControl;
    lIsSafeCall: boolean;
    lSymbol : TAsmSymbol;
  begin
    if (TargetInfo.system<>system_i386_win32) then
      begin
        inherited Pass_Generate_Code;
        exit;
      end;
    Location_Reset(Location,LOC_VOID,OS_NO);
    lTryFlowControl:=[];
    lOldBreakLabel:=nil;
    lOldContinueLabel:=nil;
    lContinueFinallyLabel:=nil;
    lBreakFinallyLabel:=nil;
    lExceptLabel:=nil;
    lSafeCallLabel:=nil;
    lIsSafeCall:=ImplicitFrame and (CurrentProcInfo.ProcDef.ProcCallOption=pocall_safecall);

    { check if child nodes do a break/continue/exit }
    lOldFlowControl:=flowcontrol;
    flowcontrol:=[fc_inflowcontrol];
    CurrentAsmData.getjumplabel(lFinallyLabel);
    CurrentAsmData.getjumplabel(lEndFinallyLabel);

    { the finally block must catch break, continue and exit }
    { statements                                            }
    lOldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
    if ImplicitFrame then
      lExitFinallyLabel:=lFinallyLabel
    else
      CurrentAsmData.getjumplabel(lExitFinallyLabel);
    CurrentProcInfo.CurrExitLabel:=lExitFinallyLabel;
    if Assigned(CurrentProcInfo.CurrBreakLabel) then
      begin
        lOldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
        lOldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
        if ImplicitFrame then
          begin
            lBreakFinallyLabel:=lFinallyLabel;
            lContinueFinallyLabel:=lFinallyLabel;
          end
        else
          begin
            CurrentAsmData.getjumplabel(lBreakFinallyLabel);
            CurrentAsmData.getjumplabel(lContinueFinallyLabel);
          end;
        CurrentProcInfo.CurrContinueLabel:=lContinueFinallyLabel;
        CurrentProcInfo.CurrBreakLabel:=lBreakFinallyLabel;
      end;

    { Start of scope }
    if lIsSafeCall then
      begin
        with cg.rg[R_INTREGISTER] do
          UsedInProc:=UsedInProc+[RS_EBX,RS_ESI,RS_EDI];

        CurrentAsmData.getjumplabel(lExceptLabel);
        lSymbol:=CurrentAsmData.RefAsmSymbol('__FPC_except_safecall',AT_FUNCTION);
        EmitScopeStart(
          lSymbol,
          lExceptLabel
        );
        CurrentModule.Add_Extern_AsmSym(lSymbol);
      end
    else
      begin
        lSymbol:=CurrentAsmData.RefAsmSymbol('__FPC_finally_handler',AT_FUNCTION);
        EmitScopeStart(
          lSymbol,
          CurrentAsmData.RefAsmSymbol(FinalizationProcInfo.ProcDef.MangledName,AT_FUNCTION)
        );
        CurrentModule.Add_Extern_AsmSym(lSymbol);
      end;

    { try code }
    if Assigned(Left) then
      begin
        SecondPass(Left);
        lTryFlowControl:=flowcontrol;
        if CodeGenError then
          exit;
      end;

    { don't generate line info for internal cleanup }
    CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoStart));

    cg.A_Label(CurrentAsmData.CurrAsmList,lFinallyLabel);
    EmitScopeEnd;
    if lIsSafeCall then
      begin
        CurrentAsmData.getjumplabel(lSafeCallLabel);
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lSafeCallLabel);
        { RTL handler will jump here on exception }
        cg.A_Label(CurrentAsmData.CurrAsmList,lExceptLabel);
        Handle_SafeCall_Exception;
        cg.A_Label(CurrentAsmData.CurrAsmList,lSafeCallLabel);
      end;

    { end cleanup }
    CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoEnd));

    { generate finally code as a separate procedure }
    { !!! this resets flowcontrol, how to check flow away? }
    if not ImplicitFrame then
      TCGProcInfo(CurrentProcInfo).Generate_ExceptFilter(FinalizationProcInfo);

    flowcontrol:=[fc_inflowcontrol];
    { right is a call to finalizer procedure }
    SecondPass(Right);

    { goto is allowed if it stays inside the finally block,
      this is checked using the exception block number }
    if (flowcontrol-[fc_gotolabel])<>[fc_inflowcontrol] then
      CGMessage(cg_e_control_flow_outside_finally);
    if CodeGenError then
      exit;

    { don't generate line info for internal cleanup }
    CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoStart));

    if not ImplicitFrame then
      begin
        if lTryFlowControl*[fc_exit,fc_break,fc_continue]<>[] then
          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lEndFinallyLabel);
        { do some magic for exit,break,continue in the try block }
        if fc_exit in lTryFlowControl then
          begin
            cg.A_Label(CurrentAsmData.CurrAsmList,lExitFinallyLabel);
            cg.G_Call(CurrentAsmData.CurrAsmList,'_FPC_leave');
            cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldCurrExitLabel);
          end;
        if fc_break in lTryFlowControl then
          begin
            cg.A_Label(CurrentAsmData.CurrAsmList,lBreakFinallyLabel);
            cg.G_Call(CurrentAsmData.CurrAsmList,'_FPC_leave');
            cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldBreakLabel);
          end;
        if fc_continue in lTryFlowControl then
          begin
            cg.A_Label(CurrentAsmData.CurrAsmList,lContinueFinallyLabel);
            cg.G_Call(CurrentAsmData.CurrAsmList,'_FPC_leave');
            cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldContinueLabel);
          end;
      end;
    cg.A_Label(CurrentAsmData.CurrAsmList,lEndFinallyLabel);

    { end cleanup }
    CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoEnd));

    CurrentProcInfo.CurrExitLabel:=lOldCurrExitLabel;
    if Assigned(CurrentProcInfo.CurrBreakLabel) then
      begin
        CurrentProcInfo.CurrContinueLabel:=lOldContinueLabel;
        CurrentProcInfo.CurrBreakLabel:=lOldBreakLabel;
      end;
    flowcontrol:=lOldFlowControl+(lTryFlowControl-[fc_inflowcontrol]);
  end;

{ ti386tryexceptnode }

procedure TI386TryExceptNode.Pass_Generate_Code;
  var
    lExceptLabel,lOldEndExceptLabel,
    lLastOnLabel,
    lExitExceptLabel,
    lContinueExceptLabel,
    lBreakExceptLabel,
    lExitTryLabel,
    lContinueTryLabel,
    lBreakTryLabel,
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
    if (TargetInfo.system<>system_i386_win32) then
      begin
        inherited Pass_Generate_Code;
        exit;
      end;
    Location_Reset(Location,LOC_VOID,OS_NO);

    lExceptFlowControl:=[];
    lBreakExceptLabel:=nil;
    lContinueExceptLabel:=nil;
    lBreakTryLabel:=nil;
    lContinueTryLabel:=nil;

    lOldFlowControl:=flowcontrol;
    flowcontrol:=[fc_inflowcontrol];
    { this can be called recursively }
    lOldBreakLabel:=nil;
    lOldContinueLabel:=nil;
    lOldEndExceptLabel:=EndExceptLabel;

    { Win32 SEH unwinding does not preserve registers. Indicate that they are
      going to be destroyed. }
    cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,[RS_EAX,RS_EBX,RS_ECX,RS_EDX,RS_ESI,RS_EDI]);
    cg.DeallocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,[RS_EAX,RS_EBX,RS_ECX,RS_EDX,RS_ESI,RS_EDI]);

    { save the old labels for control flow statements }
    lOldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
    if Assigned(CurrentProcInfo.CurrBreakLabel) then
      begin
        lOldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
        lOldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
      end;

    { get new labels for the control flow statements }
    CurrentAsmData.getjumplabel(lExitTryLabel);
    CurrentAsmData.getjumplabel(lExitExceptLabel);
    if Assigned(CurrentProcInfo.CurrBreakLabel) then
      begin
        CurrentAsmData.getjumplabel(lBreakTryLabel);
        CurrentAsmData.getjumplabel(lContinueTryLabel);
        CurrentAsmData.getjumplabel(lBreakExceptLabel);
        CurrentAsmData.getjumplabel(lContinueExceptLabel);
      end;

    CurrentAsmData.getjumplabel(lExceptLabel);
    CurrentAsmData.getjumplabel(EndExceptLabel);
    CurrentAsmData.getjumplabel(lLastOnLabel);
    lFilterLabel:=nil;

    { start of scope }
    if Assigned(Right) then
      begin
        CurrentAsmData.getaddrlabel(lFilterLabel);
        lSymbol:=CurrentAsmData.RefAsmSymbol('__FPC_on_handler',AT_FUNCTION);
        EmitScopeStart(
          lSymbol,
          lFilterLabel);
        CurrentModule.Add_Extern_AsmSym(lSymbol);
      end
    else
      begin
        lSymbol:=CurrentAsmData.RefAsmSymbol('__FPC_except_handler',AT_FUNCTION);
        EmitScopeStart(
          lSymbol,
          lExceptLabel);
        CurrentModule.Add_Extern_AsmSym(lSymbol);
      end;

    { set control flow labels for the try block }
    CurrentProcInfo.CurrExitLabel:=lExitTryLabel;
    if Assigned(lOldBreakLabel) then
      begin
        CurrentProcInfo.CurrContinueLabel:=lContinueTryLabel;
        CurrentProcInfo.CurrBreakLabel:=lBreakTryLabel;
      end;

    SecondPass(Left);
    lTryFlowControl:=flowcontrol;
    if CodeGenError then
      goto errorexit;

    EmitScopeEnd;
    { jump over except handlers }
    cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,EndExceptLabel);

    if fc_exit in lTryFlowControl then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,lExitTryLabel);
        EmitScopeEnd;
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldCurrExitLabel);
      end;
    if fc_break in lTryFlowControl then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,lBreakTryLabel);
        EmitScopeEnd;
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldBreakLabel);
      end;
    if fc_continue in lTryFlowControl then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,lContinueTryLabel);
        EmitScopeEnd;
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldContinueLabel);
      end;

    { target for catch-all handler }
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
        new_section(lList,sec_rodata,lFilterLabel.name,4);
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
            lList.concat(TAIConst.create_sym(lSymbol));
            lList.concat(TAIConst.create_sym(lOnLabel));
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
            lList.concat(TAIConst.create_sym(lLastOnLabel));
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
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldCurrExitLabel);
      end;

    if fc_break in lExceptFlowControl then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,lBreakExceptLabel);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldBreakLabel);
      end;

    if fc_continue in lExceptFlowControl then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,lContinueExceptLabel);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldContinueLabel);
      end;

    cg.A_Label(CurrentAsmData.CurrAsmList,EndExceptLabel);

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
  CRaiseNode:=TI386RaiseNode;
  COnNode:=TI386OnNode;
  CTryExceptNode:=TI386TryExceptNode;
  CTryFinallyNode:=TI386TryFinallyNode;
end.
