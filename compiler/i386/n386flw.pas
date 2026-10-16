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
      function pass_1 : TNode;override;
    end;

    TI386OnNode=class(TCGOnNode)
      procedure pass_generate_code;override;
    end;

    TI386TryExceptNode=class(TCGTryExceptNode)
      procedure pass_generate_code;override;
    end;

    TI386TryFinallyNode=class(TCGTryFinallyNode)
      finalizepi: TCGProcInfo;
      constructor create(l,r:TNode);override;
      constructor create_implicit(l,r:TNode);override;
      function pass_1: TNode;override;
      function dogetcopy : TNode;override;
      function simplify(forinline: boolean): TNode;override;
      procedure pass_generate_code;override;
    end;

implementation

  uses
    CUtils,GlobType,Globals,Verbose,Systems,FModule,
    nbas,ncal,nmem,nutils,
    symconst,SymBase,SymTable,SymSym,symdef,
    cgbase,cgobj,cgcpu,cgutils,tgobj,
    cpubase,htypechk,
    parabase,paramgr,pass_1,pass_2,ncgutil,cga,
    aasmbase,aasmtai,AAsmData,aasmcpu,ProcInfo,cpupi,procdefutil;

  var
    endexceptlabel: TAsmLabel;


{ ti386raisenode }

function TI386RaiseNode.pass_1 : TNode;
  var
    statements : TStatementNode;
    raisenode : TCallNode;
  begin
    { difference from generic code is that address stack is not popped on reraise }
    if (TargetInfo.system<>system_i386_win32) or Assigned(left) then
      result:=inherited pass_1
    else
      begin
        result:=internalstatements(statements);
        raisenode:=CCallNode.createintern('fpc_reraise',nil);
        include(raisenode.callnodeflags,cnf_call_never_returns);
        addstatement(statements,raisenode);
      end;
end;

{ ti386onnode }

procedure TI386OnNode.pass_generate_code;
  var
    oldflowcontrol : TFlowControl;
    exceptvarsym : TLocalVarSym;
  begin
    if (TargetInfo.system<>system_i386_win32) then
      begin
        inherited pass_generate_code;
        exit;
      end;

    Location_Reset(location,LOC_VOID,OS_NO);

    oldflowcontrol:=flowcontrol;
    flowcontrol:=[fc_inflowcontrol];

    { RTL will put exceptobject into EAX when jumping here }
    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_FUNCTION_RESULT_REG);

    { Retrieve exception variable }
    if Assigned(excepTSymtable) then
      exceptvarsym:=TLocalVarSym(excepTSymtable.SymList[0])
    else
      exceptvarsym:=nil;

    if Assigned(exceptvarsym) then
      begin
        exceptvarsym.LocAlloc.Loc:=LOC_REFERENCE;
        exceptvarsym.LocAlloc.Size:=OS_ADDR;
        tg.GetLocal(CurrentAsmData.CurrAsmList,sizeof(PInt),VoidPointerType,exceptvarsym.LocAlloc.Reference);
        cg.A_Load_Reg_Ref(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,NR_FUNCTION_RESULT_REG,exceptvarsym.LocAlloc.Reference);
      end;
    cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_FUNCTION_RESULT_REG);

    if Assigned(right) then
      SecondPass(right);

    { deallocate exception symbol }
    if Assigned(exceptvarsym) then
      begin
        tg.UngetLocal(CurrentAsmData.CurrAsmList,exceptvarsym.LocAlloc.Reference);
        exceptvarsym.LocAlloc.Loc:=LOC_INVALID;
      end;
    cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
    cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,endexceptlabel);

    flowcontrol:=oldflowcontrol+(flowcontrol-[fc_inflowcontrol]);
  end;

{ ti386tryfinallynode }

function reset_regvars(var n: TNode; arg: pointer): TForEachNodeResult;
  begin
    case n.nodetype of
      temprefn:
        make_not_regable(n,[]);
      calln:
        include(TProcInfo(arg).flags,pi_do_call);
      else ;
    end;
    result:=fen_true;
  end;

function copy_parasize(var n: TNode; arg: pointer): TForEachNodeResult;
  begin
    if n.nodetype=calln then
        TCGProcInfo(arg).allocate_push_parasize(TCallNode(n).pushed_parasize);
    result:=fen_true;
  end;

constructor TI386TryFinallyNode.create(l, r: TNode);
  begin
    inherited create(l,r);
    if (TargetInfo.system<>system_i386_win32) or
      { Don't create child procedures for generic methods, their nested-like
        behavior causes compilation errors because real nested procedures
        aren't allowed for generics. Not creating them doesn't harm because
        generic node tree is discarded without generating code. }
      (df_generic in CurrentProcInfo.procdef.DefOptions)
      then
      exit;
    finalizepi:=TCGProcInfo(CurrentProcInfo.create_for_outlining('$fin$',CurrentProcInfo.procdef.struct,potype_exceptfilter,VoidType,r));
    { Regvar optimization for symbols is suppressed when using exceptions, but
      temps may be still placed into registers. This must be fixed. }
    foreachnodestatic(r,@reset_regvars,finalizepi);
    include(finalizepi.flags,pi_has_assembler_block);
    include(finalizepi.flags,pi_do_call);
    include(finalizepi.flags,pi_uses_exceptions);
  end;

constructor TI386TryFinallyNode.create_implicit(l, r: TNode);
  begin
    inherited create_implicit(l, r);
    if (TargetInfo.system<>system_i386_win32) then
      exit;

    { safecall procedures can handle implicit finalization as part of "except" flow }
    if implicitframe and (CurrentProcInfo.procdef.ProcCallOption=pocall_safecall) then
      exit;

    if df_generic in CurrentProcInfo.procdef.DefOptions then
      InternalError(2013012501);

    finalizepi:=TCGProcInfo(CurrentProcInfo.create_for_outlining('$fin$',CurrentProcInfo.procdef.struct,potype_exceptfilter,VoidType,r));
    include(finalizepi.flags,pi_has_assembler_block);
    include(finalizepi.flags,pi_do_call);
    include(finalizepi.flags,pi_uses_exceptions);
  end;


function TI386TryFinallyNode.pass_1: TNode;
  var
    selfsym: TParaVarSym;
  begin
    result:=inherited pass_1;
    if (TargetInfo.system=system_i386_win32) then
      begin
        { safecall method will access 'self' from except block -> make it non-regable }
        if implicitframe and (CurrentProcInfo.procdef.ProcCallOption=pocall_safecall) and
          Is_Class(CurrentProcInfo.procdef.struct) then
          begin
            selfsym:=TParaVarSym(CurrentProcInfo.procdef.ParaST.Find('self'));
            if (selfsym=nil) or (selfsym.typ<>paravarsym) then
              InternalError(2011123102);
            selfsym.VarRegable:=vr_none;
          end;
      end;
  end;

function TI386TryFinallyNode.dogetcopy: TNode;
  var
    n: TI386TryFinallyNode;
  begin
    n:=TI386TryFinallyNode(inherited dogetcopy);
    if TargetInfo.system=system_i386_win32 then
      begin
        n.finalizepi:=TCGProcInfo(CProcInfo.create(finalizepi.parent));
        n.finalizepi.force_nested;
        n.finalizepi.procdef:=Create_Outline_ProcDef('$fin$',CurrentProcInfo.procdef.struct,potype_exceptfilter,VoidType);
        n.finalizepi.entrypos:=finalizepi.entrypos;
        n.finalizepi.entryswitches:=finalizepi.entryswitches;
        n.finalizepi.exitpos:=finalizepi.exitpos;
        n.finalizepi.exitswitches:=finalizepi.exitswitches;
        n.finalizepi.flags:=finalizepi.flags;
        { node already transformed? }
        if Assigned(finalizepi.code) then
          begin
            n.finalizepi.code:=finalizepi.code.GetCopy;
            n.right:=CCallNode.create(nil,TProcSym(n.finalizepi.procdef.ProcSym),nil,nil,[],nil);
            FirstPass(n.right);
          end;
      end;
    result:=n;
  end;

function TI386TryFinallyNode.simplify(forinline: boolean): TNode;
  begin
    result:=inherited simplify(forinline);
    if (TargetInfo.system<>system_i386_win32) then
      exit;

    { actually, this is not really the right place to do a node transformation like this }
    if (result=nil) and Assigned(finalizepi) and (not(Assigned(finalizepi.code))) then
      begin
        finalizepi.code:=right;
        foreachnodestatic(right,@copy_parasize,finalizepi);
        right:=CCallNode.create(nil,TProcSym(finalizepi.procdef.ProcSym),nil,nil,[],nil);
        FirstPass(right);
        { For implicit frames, no actual code is available at this time,
          it is added later in assembler form. So store the nested procinfo
          for later use. }
        if implicitframe then
          begin
            CurrentProcInfo.finalize_procinfo:=finalizepi;
          end;
      end;
  end;


procedure emit_scope_start(handler,data: TAsmSymbol);
  var
    href: TReference;
    hreg: TRegister;
  begin
    hreg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
    Reference_Reset_Base(href,hreg,0,CTempPosInvalid,sizeof(PInt),[]);
    href.Segment:=NR_FS;
    emit_reg_reg(A_XOR,S_L,hreg,hreg);
    emit_sym(A_PUSH,S_L,data);
    emit_reg(A_PUSH,S_L,NR_FRAME_POINTER_REG);
    emit_sym(A_PUSH,S_L,handler);
    emit_ref(A_PUSH,S_L,href);
    emit_reg_ref(A_MOV,S_L,NR_ESP,href);
  end;

procedure emit_scope_end;
  var
    href: TReference;
    hreg,hreg2: TRegister;
  begin
    hreg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
    hreg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
    Reference_Reset_Base(href,hreg,0,CTempPosInvalid,sizeof(PInt),[]);
    href.Segment:=NR_FS;
    emit_reg_reg(A_XOR,S_L,hreg,hreg);
    emit_reg(A_POP,S_L,hreg2);
    emit_const_reg(A_ADD,S_L,3*sizeof(PInt),NR_ESP);
    emit_reg_ref(A_MOV,S_L,hreg2,href);
  end;

procedure TI386TryFinallyNode.pass_generate_code;
  var
    finallylabel,
    exceptlabel,
    safecalllabel,
    endfinallylabel,
    exitfinallylabel,
    continuefinallylabel,
    breakfinallylabel,
    oldCurrExitLabel,
    oldContinueLabel,
    oldBreakLabel : TAsmLabel;
    oldflowcontrol,tryflowcontrol : TFlowControl;
    is_safecall: boolean;
    sym : TAsmSymbol;
  begin
    if (TargetInfo.system<>system_i386_win32) then
      begin
        inherited pass_generate_code;
        exit;
      end;
    Location_Reset(location,LOC_VOID,OS_NO);
    tryflowcontrol:=[];
    oldBreakLabel:=nil;
    oldContinueLabel:=nil;
    continuefinallylabel:=nil;
    breakfinallylabel:=nil;
    exceptlabel:=nil;
    safecalllabel:=nil;
    is_safecall:=implicitframe and (CurrentProcInfo.procdef.ProcCallOption=pocall_safecall);

    { check if child nodes do a break/continue/exit }
    oldflowcontrol:=flowcontrol;
    flowcontrol:=[fc_inflowcontrol];
    CurrentAsmData.getjumplabel(finallylabel);
    CurrentAsmData.getjumplabel(endfinallylabel);

    { the finally block must catch break, continue and exit }
    { statements                                            }
    oldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
    if implicitframe then
      exitfinallylabel:=finallylabel
    else
      CurrentAsmData.getjumplabel(exitfinallylabel);
    CurrentProcInfo.CurrExitLabel:=exitfinallylabel;
    if Assigned(CurrentProcInfo.CurrBreakLabel) then
      begin
        oldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
        oldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
        if implicitframe then
          begin
            breakfinallylabel:=finallylabel;
            continuefinallylabel:=finallylabel;
          end
        else
          begin
            CurrentAsmData.getjumplabel(breakfinallylabel);
            CurrentAsmData.getjumplabel(continuefinallylabel);
          end;
        CurrentProcInfo.CurrContinueLabel:=continuefinallylabel;
        CurrentProcInfo.CurrBreakLabel:=breakfinallylabel;
      end;

    { Start of scope }
    if is_safecall then
      begin
        with cg.rg[R_INTREGISTER] do
          UsedInProc:=UsedInProc+[RS_EBX,RS_ESI,RS_EDI];

        CurrentAsmData.getjumplabel(exceptlabel);
        sym:=CurrentAsmData.RefAsmSymbol('__FPC_except_safecall',AT_FUNCTION);
        emit_scope_start(
          sym,
          exceptlabel
        );
        CurrentModule.Add_Extern_AsmSym(sym);
      end
    else
      begin
        sym:=CurrentAsmData.RefAsmSymbol('__FPC_finally_handler',AT_FUNCTION);
        emit_scope_start(
          sym,
          CurrentAsmData.RefAsmSymbol(finalizepi.procdef.MangledName,AT_FUNCTION)
        );
        CurrentModule.Add_Extern_AsmSym(sym);
      end;

    { try code }
    if Assigned(left) then
      begin
        SecondPass(left);
        tryflowcontrol:=flowcontrol;
        if CodeGenError then
          exit;
      end;

    { don't generate line info for internal cleanup }
    CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoStart));

    cg.A_Label(CurrentAsmData.CurrAsmList,finallylabel);
    emit_scope_end;
    if is_safecall then
      begin
        CurrentAsmData.getjumplabel(safecalllabel);
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,safecalllabel);
        { RTL handler will jump here on exception }
        cg.A_Label(CurrentAsmData.CurrAsmList,exceptlabel);
        handle_safecall_exception;
        cg.A_Label(CurrentAsmData.CurrAsmList,safecalllabel);
      end;

    { end cleanup }
    CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoEnd));

    { generate finally code as a separate procedure }
    { !!! this resets flowcontrol, how to check flow away? }
    if not implicitframe then
      TCGProcInfo(CurrentProcInfo).generate_exceptfilter(finalizepi);

    flowcontrol:=[fc_inflowcontrol];
    { right is a call to finalizer procedure }
    SecondPass(right);

    { goto is allowed if it stays inside the finally block,
      this is checked using the exception block number }
    if (flowcontrol-[fc_gotolabel])<>[fc_inflowcontrol] then
      CGMessage(cg_e_control_flow_outside_finally);
    if CodeGenError then
      exit;

    { don't generate line info for internal cleanup }
    CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoStart));

    if not implicitframe then
      begin
        if tryflowcontrol*[fc_exit,fc_break,fc_continue]<>[] then
          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,endfinallylabel);
        { do some magic for exit,break,continue in the try block }
        if fc_exit in tryflowcontrol then
          begin
            cg.A_Label(CurrentAsmData.CurrAsmList,exitfinallylabel);
            cg.G_Call(CurrentAsmData.CurrAsmList,'_FPC_leave');
            cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldCurrExitLabel);
          end;
        if fc_break in tryflowcontrol then
          begin
            cg.A_Label(CurrentAsmData.CurrAsmList,breakfinallylabel);
            cg.G_Call(CurrentAsmData.CurrAsmList,'_FPC_leave');
            cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldBreakLabel);
          end;
        if fc_continue in tryflowcontrol then
          begin
            cg.A_Label(CurrentAsmData.CurrAsmList,continuefinallylabel);
            cg.G_Call(CurrentAsmData.CurrAsmList,'_FPC_leave');
            cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldContinueLabel);
          end;
      end;
    cg.A_Label(CurrentAsmData.CurrAsmList,endfinallylabel);

    { end cleanup }
    CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoEnd));

    CurrentProcInfo.CurrExitLabel:=oldCurrExitLabel;
    if Assigned(CurrentProcInfo.CurrBreakLabel) then
      begin
        CurrentProcInfo.CurrContinueLabel:=oldContinueLabel;
        CurrentProcInfo.CurrBreakLabel:=oldBreakLabel;
      end;
    flowcontrol:=oldflowcontrol+(tryflowcontrol-[fc_inflowcontrol]);
  end;

{ ti386tryexceptnode }

procedure TI386TryExceptNode.pass_generate_code;
  var
    exceptlabel,oldendexceptlabel,
    lastonlabel,
    exitexceptlabel,
    continueexceptlabel,
    breakexceptlabel,
    exittrylabel,
    continuetrylabel,
    breaktrylabel,
    oldCurrExitLabel,
    oldContinueLabel,
    oldBreakLabel : TAsmLabel;
    onlabel,
    filterlabel: TAsmLabel;
    oldflowcontrol,tryflowcontrol,
    exceptflowcontrol : TFlowControl;
    hnode : TNode;
    hlist : TAsmList;
    onnodecount : TAIConst;
    sym : TAsmSymbol;
  label
    errorexit;
  begin
    if (TargetInfo.system<>system_i386_win32) then
      begin
        inherited pass_generate_code;
        exit;
      end;
    Location_Reset(location,LOC_VOID,OS_NO);

    exceptflowcontrol:=[];
    breakexceptlabel:=nil;
    continueexceptlabel:=nil;
    breaktrylabel:=nil;
    continuetrylabel:=nil;

    oldflowcontrol:=flowcontrol;
    flowcontrol:=[fc_inflowcontrol];
    { this can be called recursively }
    oldBreakLabel:=nil;
    oldContinueLabel:=nil;
    oldendexceptlabel:=endexceptlabel;

    { Win32 SEH unwinding does not preserve registers. Indicate that they are
      going to be destroyed. }
    cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,[RS_EAX,RS_EBX,RS_ECX,RS_EDX,RS_ESI,RS_EDI]);
    cg.DeallocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,[RS_EAX,RS_EBX,RS_ECX,RS_EDX,RS_ESI,RS_EDI]);

    { save the old labels for control flow statements }
    oldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
    if Assigned(CurrentProcInfo.CurrBreakLabel) then
      begin
        oldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
        oldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
      end;

    { get new labels for the control flow statements }
    CurrentAsmData.getjumplabel(exittrylabel);
    CurrentAsmData.getjumplabel(exitexceptlabel);
    if Assigned(CurrentProcInfo.CurrBreakLabel) then
      begin
        CurrentAsmData.getjumplabel(breaktrylabel);
        CurrentAsmData.getjumplabel(continuetrylabel);
        CurrentAsmData.getjumplabel(breakexceptlabel);
        CurrentAsmData.getjumplabel(continueexceptlabel);
      end;

    CurrentAsmData.getjumplabel(exceptlabel);
    CurrentAsmData.getjumplabel(endexceptlabel);
    CurrentAsmData.getjumplabel(lastonlabel);
    filterlabel:=nil;

    { start of scope }
    if Assigned(right) then
      begin
        CurrentAsmData.getaddrlabel(filterlabel);
        sym:=CurrentAsmData.RefAsmSymbol('__FPC_on_handler',AT_FUNCTION);
        emit_scope_start(
          sym,
          filterlabel);
        CurrentModule.Add_Extern_AsmSym(sym);
      end
    else
      begin
        sym:=CurrentAsmData.RefAsmSymbol('__FPC_except_handler',AT_FUNCTION);
        emit_scope_start(
          sym,
          exceptlabel);
        CurrentModule.Add_Extern_AsmSym(sym);
      end;

    { set control flow labels for the try block }
    CurrentProcInfo.CurrExitLabel:=exittrylabel;
    if Assigned(oldBreakLabel) then
      begin
        CurrentProcInfo.CurrContinueLabel:=continuetrylabel;
        CurrentProcInfo.CurrBreakLabel:=breaktrylabel;
      end;

    SecondPass(left);
    tryflowcontrol:=flowcontrol;
    if CodeGenError then
      goto errorexit;

    emit_scope_end;
    { jump over except handlers }
    cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,endexceptlabel);

    if fc_exit in tryflowcontrol then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,exittrylabel);
        emit_scope_end;
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldCurrExitLabel);
      end;
    if fc_break in tryflowcontrol then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,breaktrylabel);
        emit_scope_end;
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldBreakLabel);
      end;
    if fc_continue in tryflowcontrol then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,continuetrylabel);
        emit_scope_end;
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldContinueLabel);
      end;

    { target for catch-all handler }
    cg.A_Label(CurrentAsmData.CurrAsmList,exceptlabel);

    { set control flow labels for the except block }
    { and the on statements                        }
    CurrentProcInfo.CurrExitLabel:=exitexceptlabel;
    if Assigned(oldBreakLabel) then
      begin
        CurrentProcInfo.CurrContinueLabel:=continueexceptlabel;
        CurrentProcInfo.CurrBreakLabel:=breakexceptlabel;
      end;

    flowcontrol:=[fc_inflowcontrol];
    { on statements }
    if Assigned(right) then
      begin
        { emit filter table to a temporary asmlist }
        hlist:=TAsmList.Create;
        new_section(hlist,sec_rodata,filterlabel.name,4);
        cg.A_Label(hlist,filterlabel);
        onnodecount:=TAIConst.create_32bit(0);
        hlist.concat(onnodecount);

        hnode:=right;
        while Assigned(hnode) do
          begin
            if hnode.nodetype<>onn then
              InternalError(2011103101);
            CurrentAsmData.getjumplabel(onlabel);
            sym:=CurrentAsmData.RefAsmSymbol(TOnNode(hnode).excepttype.VMT_MangledName,AT_DATA,true);
            hlist.concat(TAIConst.create_sym(sym));
            hlist.concat(TAIConst.create_sym(onlabel));
            CurrentModule.Add_Extern_AsmSym(sym);
            cg.A_Label(CurrentAsmData.CurrAsmList,onlabel);
            SecondPass(hnode);
            inc(onnodecount.Value);
            hnode:=TOnNode(hnode).left;
          end;
        { add 'else' node to the filter list, too }
        if Assigned(t1) then
          begin
            hlist.concat(TAIConst.create_32bit(-1));
            hlist.concat(TAIConst.create_sym(lastonlabel));
            inc(onnodecount.Value);
          end;
        { now move filter table to permanent list all at once }
        CurrentProcInfo.AktLocalData.ConcatList(hlist);
        hlist.free;
      end;

    cg.A_Label(CurrentAsmData.CurrAsmList,lastonlabel);
    if Assigned(t1) then
      begin
        { here we don't have to reset flowcontrol           }
        { the default and on flowcontrols are handled equal }
        SecondPass(t1);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        if (flowcontrol*[fc_exit,fc_break,fc_continue]<>[]) then
          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,endexceptlabel);
      end;
    exceptflowcontrol:=flowcontrol;

    if fc_exit in exceptflowcontrol then
      begin
        { do some magic for exit in the try block }
        cg.A_Label(CurrentAsmData.CurrAsmList,exitexceptlabel);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldCurrExitLabel);
      end;

    if fc_break in exceptflowcontrol then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,breakexceptlabel);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldBreakLabel);
      end;

    if fc_continue in exceptflowcontrol then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,continueexceptlabel);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldContinueLabel);
      end;

    cg.A_Label(CurrentAsmData.CurrAsmList,endexceptlabel);

errorexit:
    { restore all saved labels }
    endexceptlabel:=oldendexceptlabel;

    { restore the control flow labels }
    CurrentProcInfo.CurrExitLabel:=oldCurrExitLabel;
    if Assigned(oldBreakLabel) then
      begin
        CurrentProcInfo.CurrContinueLabel:=oldContinueLabel;
        CurrentProcInfo.CurrBreakLabel:=oldBreakLabel;
      end;

    { return all used control flow statements }
    flowcontrol:=oldflowcontrol+(exceptflowcontrol +
      tryflowcontrol - [fc_inflowcontrol]);
  end;

initialization
  CRaiseNode:=TI386RaiseNode;
  COnNode:=TI386OnNode;
  CTryExceptNode:=TI386TryExceptNode;
  CTryFinallyNode:=TI386TryFinallyNode;
end.
