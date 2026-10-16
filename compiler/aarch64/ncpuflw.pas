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
      function pass_1 : TNode;override;
    end;

    TAArch64OnNode=class(TCGOnNode)
      procedure pass_generate_code;override;
    end;

    TAArch64TryExceptNode=class(TCGTryExceptNode)
      procedure pass_generate_code;override;
    end;

    TAArch64TryFinallyNode=class(TCGTryFinallyNode)
      finalizepi: TCGProcInfo;
      constructor create(l,r:TNode);override;
      constructor create_implicit(l,r:TNode);override;
      function simplify(forinline: boolean): TNode;override;
      procedure pass_generate_code;override;
      function dogetcopy:TNode;override;
    end;

implementation

  uses
    GlobType,Globals,Verbose,Systems,FModule,
    nbas,ncal,nutils,
    symconst,SymSym,symdef,
    cgbase,cgobj,cgutils,tgobj,
    cpubase,htypechk,
    pass_1,pass_2,
    aasmbase,aasmtai,AAsmData,aasmcpu,
    ProcInfo,cpupi,procdefutil;

  var
    endexceptlabel: TAsmLabel;


{ taarch64raisenode }

function TAArch64RaiseNode.pass_1 : TNode;
  var
    statements : TStatementNode;
    raisenode : TCallNode;
  begin
    { difference from generic code is that address stack is not popped on reraise }
    if (TargetInfo.system<>system_aarch64_win64) or Assigned(left) then
      result:=inherited pass_1
    else
      begin
        result:=internalstatements(statements);
        raisenode:=CCallNode.createintern('fpc_reraise',nil);
        include(raisenode.callnodeflags,cnf_call_never_returns);
        addstatement(statements,raisenode);
      end;
end;

{ taarch64onnode }

procedure TAArch64OnNode.pass_generate_code;
  var
    exceptvarsym : TLocalVarSym;
  begin
    if (TargetInfo.system<>system_aarch64_win64) then
      begin
        inherited pass_generate_code;
        exit;
      end;

    Location_Reset(location,LOC_VOID,OS_NO);

    { RTL will put exceptobject into X0 when jumping here }
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
  end;

{ taarch64tryfinallynode }

function reset_regvars(var n: TNode; arg: pointer): TForEachNodeResult;
  begin
    case n.nodetype of
      temprefn:
        make_not_regable(n,[]);
      calln:
        include(TProcInfo(arg).flags,pi_do_call);
      else
        ;
    end;
    result:=fen_true;
  end;

function copy_parasize(var n: TNode; arg: pointer): TForEachNodeResult;
  begin
    case n.nodetype of
      calln:
        TCGProcInfo(arg).allocate_push_parasize(TCallNode(n).pushed_parasize);
      else
        ;
    end;
    result:=fen_true;
  end;

constructor TAArch64TryFinallyNode.create(l, r: TNode);
  begin
    inherited create(l,r);
    if (TargetInfo.system=system_aarch64_win64) and
      { Don't create child procedures for generic methods, their nested-like
        behavior causes compilation errors because real nested procedures
        aren't allowed for generics. Not creating them doesn't harm because
        generic node tree is discarded without generating code. }
       not (df_generic in CurrentProcInfo.procdef.DefOptions) then
      begin
        finalizepi:=TCGProcInfo(CurrentProcInfo.create_for_outlining('$fin$',CurrentProcInfo.procdef.struct,potype_exceptfilter,VoidType,r));
        { the init/final code is messing with asm nodes, so inform the compiler about this }
        include(finalizepi.flags,pi_has_assembler_block);
        { Regvar optimization for symbols is suppressed when using exceptions, but
          temps may be still placed into registers. This must be fixed. }
        foreachnodestatic(r,@reset_regvars,finalizepi);
      end;
  end;

constructor TAArch64TryFinallyNode.create_implicit(l, r: TNode);
  begin
    inherited create_implicit(l, r);
    if (TargetInfo.system=system_aarch64_win64) then
      begin
        if df_generic in CurrentProcInfo.procdef.DefOptions then
          InternalError(2020033101);

        finalizepi:=TCGProcInfo(CurrentProcInfo.create_for_outlining('$fin$',CurrentProcInfo.procdef.struct,potype_exceptfilter,VoidType,r));
        include(finalizepi.flags,pi_do_call);
        { the init/final code is messing with asm nodes, so inform the compiler about this }
        include(finalizepi.flags,pi_has_assembler_block);
      end;
  end;

function TAArch64TryFinallyNode.simplify(forinline: boolean): TNode;
  begin
    result:=inherited simplify(forinline);
    if (TargetInfo.system<>system_aarch64_win64) then
      exit;
    if (result=nil) then
      begin
        { actually, this is not really the right place to do a node transformation like this }
        if not(Assigned(finalizepi.code)) then
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
  end;

procedure emit_nop;
  var
    dummy: TAsmLabel;
  begin
    { To avoid optimizing away the whole thing, prepend a jumplabel with increased refcount }
    CurrentAsmData.getjumplabel(dummy);
    dummy.increfs;
    cg.A_Label(CurrentAsmData.CurrAsmList,dummy);
    CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_NOP));
  end;

procedure TAArch64TryFinallyNode.pass_generate_code;
  var
    trylabel,
    endtrylabel,
    finallylabel,
    endfinallylabel,
    templabel,
    oldexitlabel: TAsmLabel;
    oldflowcontrol: TFlowControl;
    catch_frame: boolean;
  begin
    if (TargetInfo.system<>system_aarch64_win64) then
      begin
        inherited pass_generate_code;
        exit;
      end;

    Location_Reset(location,LOC_VOID,OS_NO);

    { Do not generate a frame that catches exceptions if the only action
      would be reraising it. Doing so is extremely inefficient with SEH
      (in contrast with setjmp/longjmp exception handling) }
    catch_frame:=implicitframe and
      (CurrentProcInfo.procdef.ProcCallOption=pocall_safecall);

    oldflowcontrol:=flowcontrol;
    flowcontrol:=[fc_inflowcontrol];

    templabel:=nil;
    CurrentAsmData.getjumplabel(trylabel);
    CurrentAsmData.getjumplabel(endtrylabel);
    CurrentAsmData.getjumplabel(finallylabel);
    CurrentAsmData.getjumplabel(endfinallylabel);
    oldexitlabel:=CurrentProcInfo.CurrExitLabel;
    if implicitframe then
      CurrentProcInfo.CurrExitLabel:=finallylabel;

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

    emit_nop;
    cg.A_Label(CurrentAsmData.CurrAsmList,trylabel);

    { try code }
    if Assigned(left) then
      begin
        { fc_unwind_xx tells exit/continue/break statements to emit special
          unwind code instead of just JMP }
        if not implicitframe then
          flowcontrol:=flowcontrol+[fc_catching_exceptions,fc_unwind_exit,fc_unwind_loop];
        SecondPass(left);
        flowcontrol:=flowcontrol-[fc_catching_exceptions,fc_unwind_exit,fc_unwind_loop];
        if CodeGenError then
          exit;
      end;

    { finallylabel is only used in implicit frames as an exit point from nested try..finally
      statements, if any. To prevent finalizer from being executed twice, it must come before
      endtrylabel (bug #34772) }
    if catch_frame then
      begin
        CurrentAsmData.getjumplabel(templabel);
        cg.A_Label(CurrentAsmData.CurrAsmList, finallylabel);
        { jump over exception handler }
        cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,templabel);
        { Handle the except block first, so endtrylabel serves both
          as end of scope and as unwind target. This way it is possible to
          encode everything into a single scope record. }
        cg.A_Label(CurrentAsmData.CurrAsmList,endtrylabel);
        if (CurrentProcInfo.procdef.ProcCallOption=pocall_safecall) then
          begin
            handle_safecall_exception;
            cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,endfinallylabel);
          end
        else
          InternalError(2014031601);
        cg.A_Label(CurrentAsmData.CurrAsmList,templabel);
      end
    else
      begin
        { same as emit_nop but using finallylabel instead of dummy }
        cg.A_Label(CurrentAsmData.CurrAsmList,finallylabel);
        finallylabel.increfs;
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_NOP));
        cg.A_Label(CurrentAsmData.CurrAsmList,endtrylabel);
      end;

    { i32913 - if the try..finally block is also inside a try..finally or
      try..except block, make a note of any Exit calls so all necessary labels
      are generated. [Kit] }
    if ((flowcontrol*[fc_exit,fc_break,fc_continue])<>[]) and (fc_inflowcontrol in oldflowcontrol) then
      oldflowcontrol:=oldflowcontrol+(flowcontrol*[fc_exit,fc_break,fc_continue]);

    flowcontrol:=[fc_inflowcontrol];
    { store the tempflags so that we can generate the finally handler later on }
    if not implicitframe then
      finalizepi.store_tempflags;
    { right is a call to finalizer procedure }
    SecondPass(right);

    if CodeGenError then
      exit;

    { normal exit from safecall proc must zero the result register }
    if implicitframe and (CurrentProcInfo.procdef.ProcCallOption=pocall_safecall) then
      cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_INT,0,NR_FUNCTION_RESULT_REG);

    cg.A_Label(CurrentAsmData.CurrAsmList,endfinallylabel);

    { generate the scope record in .xdata }
    TCPUProcInfo(CurrentProcInfo).add_finally_scope(trylabel,endtrylabel,
      CurrentAsmData.RefAsmSymbol(finalizepi.procdef.MangledName,AT_FUNCTION),catch_frame);

    if implicitframe then
      CurrentProcInfo.CurrExitLabel:=oldexitlabel;
    flowcontrol:=oldflowcontrol;
  end;

function TAArch64TryFinallyNode.dogetcopy: TNode;
  var
    n : TAArch64TryFinallyNode;
  begin
    n:=TAArch64TryFinallyNode(inherited dogetcopy);
    if (TargetInfo.system=system_aarch64_win64) then
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


{ taarch64tryexceptnode }

procedure TAArch64TryExceptNode.pass_generate_code;
  var
    trylabel,
    exceptlabel,oldendexceptlabel,
    lastonlabel,
    exitexceptlabel,
    continueexceptlabel,
    breakexceptlabel,
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
    if (TargetInfo.system<>system_aarch64_win64) then
      begin
        inherited pass_generate_code;
        exit;
      end;
    Location_Reset(location,LOC_VOID,OS_NO);

    oldflowcontrol:=flowcontrol;
    exceptflowcontrol:=[];
    continueexceptlabel:=nil;
    breakexceptlabel:=nil;

    include(flowcontrol,fc_inflowcontrol);
    { this can be called recursively }
    oldBreakLabel:=nil;
    oldContinueLabel:=nil;
    oldendexceptlabel:=endexceptlabel;

    { save the old labels for control flow statements }
    oldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
    CurrentAsmData.getjumplabel(exitexceptlabel);
    if Assigned(CurrentProcInfo.CurrBreakLabel) then
      begin
        oldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
        oldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
        CurrentAsmData.getjumplabel(breakexceptlabel);
        CurrentAsmData.getjumplabel(continueexceptlabel);
      end;

    CurrentAsmData.getjumplabel(exceptlabel);
    CurrentAsmData.getjumplabel(endexceptlabel);
    CurrentAsmData.getjumplabel(lastonlabel);
    filterlabel:=nil;

    { start of scope }
    CurrentAsmData.getjumplabel(trylabel);
    emit_nop;
    cg.A_Label(CurrentAsmData.CurrAsmList,trylabel);

    { control flow in try block needs no special handling,
      just make sure that target labels are outside the scope }
    SecondPass(left);
    tryflowcontrol:=flowcontrol;
    if CodeGenError then
      goto errorexit;

    { jump over except handlers }
    cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,endexceptlabel);

    { end of scope }
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
        CurrentAsmData.getaddrlabel(filterlabel);
        new_section(hlist,sec_rodata_norel,filterlabel.name,4);
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
            hlist.concat(TAIConst.create_rva_sym(sym));
            hlist.concat(TAIConst.create_rva_sym(onlabel));
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
            hlist.concat(TAIConst.create_rva_sym(lastonlabel));
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
        if (fc_unwind_exit in oldflowcontrol) then
          cg.G_Local_Unwind(CurrentAsmData.CurrAsmList,oldCurrExitLabel)
        else
          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldCurrExitLabel);
      end;

    if fc_break in exceptflowcontrol then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,breakexceptlabel);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        if (fc_unwind_loop in oldflowcontrol) then
          cg.G_Local_Unwind(CurrentAsmData.CurrAsmList,oldBreakLabel)
        else
          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldBreakLabel);
      end;

    if fc_continue in exceptflowcontrol then
      begin
        cg.A_Label(CurrentAsmData.CurrAsmList,continueexceptlabel);
        cg.G_Call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        if (fc_unwind_loop in oldflowcontrol) then
          cg.G_Local_Unwind(CurrentAsmData.CurrAsmList,oldContinueLabel)
        else
          cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,oldContinueLabel);
      end;

    emit_nop;
    cg.A_Label(CurrentAsmData.CurrAsmList,endexceptlabel);
    TCPUProcInfo(CurrentProcInfo).add_except_scope(trylabel,exceptlabel,endexceptlabel,filterlabel);

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
  CRaiseNode:=TAArch64RaiseNode;
  COnNode:=TAArch64OnNode;
  CTryExceptNode:=TAArch64TryExceptNode;
  CTryFinallyNode:=TAArch64TryFinallyNode;
end.

