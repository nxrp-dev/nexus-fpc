{
    Copyright (c) 2011 by Free Pascal development team

    Generate Win64-specific exception handling code

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
unit nx64flw;

{$i fpcdefs.inc}

interface

  uses
    node,nflw,ncgflw,psub;

  type
    tx64raisenode=class(tcgraisenode)
      function pass_1 : TNode;override;
    end;

    tx64onnode=class(tcgonnode)
      procedure pass_generate_code;override;
    end;

    tx64tryexceptnode=class(tcgtryexceptnode)
      procedure pass_generate_code;override;
    end;

    tx64tryfinallynode=class(tcgtryfinallynode)
      finalizepi: tcgprocinfo;
      constructor create(l,r:TNode);override;
      constructor create_implicit(l,r:TNode);override;
      function dogetcopy : TNode;override;
      function simplify(forinline: boolean): TNode;override;
      procedure pass_generate_code;override;
    end;

implementation

  uses
    globtype,globals,verbose,systems,fmodule,
    nbas,ncal,nutils,
    symconst,symsym,symdef,
    cgbase,cgobj,cgutils,tgobj,
    cpubase,htypechk,
    pass_1,pass_2,
    aasmbase,aasmtai,aasmdata,aasmcpu,
    procinfo,cpupi,procdefutil;

  var
    endexceptlabel: tasmlabel;


{ tx64raisenode }

function tx64raisenode.pass_1 : TNode;
  var
    statements : tstatementnode;
    raisenode : tcallnode;
  begin
    { difference from generic code is that address stack is not popped on reraise }
    if (TargetInfo.system<>system_x86_64_win64) or assigned(left) then
      result:=inherited pass_1
    else
      begin
        result:=internalstatements(statements);
        raisenode:=ccallnode.createintern('fpc_reraise',nil);
        include(raisenode.callnodeflags,cnf_call_never_returns);
        addstatement(statements,raisenode);
      end;
end;

{ tx64onnode }

procedure tx64onnode.pass_generate_code;
  var
    exceptvarsym : TLocalVarSym;
  begin
    if (TargetInfo.system<>system_x86_64_win64) then
      begin
        inherited pass_generate_code;
        exit;
      end;

    location_reset(location,LOC_VOID,OS_NO);

    { RTL will put exceptobject into RAX when jumping here }
    cg.a_reg_alloc(CurrentAsmData.CurrAsmList,NR_FUNCTION_RESULT_REG);

    { Retrieve exception variable }
    if assigned(excepTSymtable) then
      exceptvarsym:=TLocalVarSym(excepTSymtable.SymList[0])
    else
      exceptvarsym:=nil;

    if assigned(exceptvarsym) then
      begin
        exceptvarsym.localloc.loc:=LOC_REFERENCE;
        exceptvarsym.localloc.size:=OS_ADDR;
        tg.GetLocal(CurrentAsmData.CurrAsmList,sizeof(pint),voidpointertype,exceptvarsym.localloc.reference);
        cg.a_load_reg_ref(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,NR_FUNCTION_RESULT_REG,exceptvarsym.localloc.reference);
      end;
    cg.a_reg_dealloc(CurrentAsmData.CurrAsmList,NR_FUNCTION_RESULT_REG);

    if assigned(right) then
      SecondPass(right);

    { deallocate exception symbol }
    if assigned(exceptvarsym) then
      begin
        tg.UngetLocal(CurrentAsmData.CurrAsmList,exceptvarsym.localloc.reference);
        exceptvarsym.localloc.loc:=LOC_INVALID;
      end;
    cg.g_call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
    cg.a_jmp_always(CurrentAsmData.CurrAsmList,endexceptlabel);
  end;

{ tx64tryfinallynode }

function reset_regvars(var n: TNode; arg: pointer): foreachnoderesult;
  begin
    case n.nodetype of
      temprefn:
        make_not_regable(n,[]);
      calln:
        include(tprocinfo(arg).flags,pi_do_call);
      else
        ;
    end;
    result:=fen_true;
  end;

function copy_parasize(var n: TNode; arg: pointer): foreachnoderesult;
  begin
    case n.nodetype of
      calln:
        tcgprocinfo(arg).allocate_push_parasize(tcallnode(n).pushed_parasize);
      else
        ;
    end;
    result:=fen_true;
  end;

constructor tx64tryfinallynode.create(l, r: TNode);
  begin
    inherited create(l,r);
    if (TargetInfo.system=system_x86_64_win64) and
      { Don't create child procedures for generic methods, their nested-like
        behavior causes compilation errors because real nested procedures
        aren't allowed for generics. Not creating them doesn't harm because
        generic node tree is discarded without generating code. }
       not (df_generic in CurrentProcInfo.procdef.defoptions) then
      begin
        finalizepi:=tcgprocinfo(CurrentProcInfo.create_for_outlining('$fin$',CurrentProcInfo.procdef.struct,potype_exceptfilter,voidtype,r));
        { the init/final code is messing with asm nodes, so inform the compiler about this }
        include(finalizepi.flags,pi_has_assembler_block);
        { Regvar optimization for symbols is suppressed when using exceptions, but
          temps may be still placed into registers. This must be fixed. }
        foreachnodestatic(r,@reset_regvars,finalizepi);
      end;
  end;


constructor tx64tryfinallynode.create_implicit(l, r: TNode);
  begin
    inherited create_implicit(l, r);
    if (TargetInfo.system=system_x86_64_win64) then
      begin
        if df_generic in CurrentProcInfo.procdef.defoptions then
          InternalError(2013012501);

        finalizepi:=tcgprocinfo(CurrentProcInfo.create_for_outlining('$fin$',CurrentProcInfo.procdef.struct,potype_exceptfilter,voidtype,r));
        include(finalizepi.flags,pi_do_call);
        { the init/final code is messing with asm nodes, so inform the compiler about this }
        include(finalizepi.flags,pi_has_assembler_block);
        finalizepi.allocate_push_parasize(32);
      end;
  end;


function tx64tryfinallynode.dogetcopy: TNode;
  var
    n: tx64tryfinallynode;
  begin
    n:=tx64tryfinallynode(inherited dogetcopy);
    if TargetInfo.system=system_x86_64_win64 then
      begin
        n.finalizepi:=tcgprocinfo(cprocinfo.create(finalizepi.parent));
        n.finalizepi.force_nested;
        n.finalizepi.procdef:=create_outline_procdef('$fin$',CurrentProcInfo.procdef.struct,potype_exceptfilter,voidtype);
        n.finalizepi.entrypos:=finalizepi.entrypos;
        n.finalizepi.entryswitches:=finalizepi.entryswitches;
        n.finalizepi.exitpos:=finalizepi.exitpos;
        n.finalizepi.exitswitches:=finalizepi.exitswitches;
        n.finalizepi.flags:=finalizepi.flags;
        { node already transformed? }
        if assigned(finalizepi.code) then
          begin
            n.finalizepi.code:=finalizepi.code.getcopy;
            n.right:=ccallnode.create(nil,TProcSym(n.finalizepi.procdef.procsym),nil,nil,[],nil);
            FirstPass(n.right);
          end;
      end;
    result:=n;
  end;


function tx64tryfinallynode.simplify(forinline: boolean): TNode;
  begin
    result:=inherited simplify(forinline);
    if (TargetInfo.system<>system_x86_64_win64) then
      exit;
    if (result=nil) then
      begin
        { actually, this is not really the right place to do a node transformation like this }
        if not(assigned(finalizepi.code)) then
          begin
            finalizepi.code:=right;
            foreachnodestatic(right,@copy_parasize,finalizepi);
            right:=ccallnode.create(nil,TProcSym(finalizepi.procdef.procsym),nil,nil,[],nil);
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
    cg.a_label(CurrentAsmData.CurrAsmList,dummy);
    CurrentAsmData.CurrAsmList.concat(Taicpu.op_none(A_NOP,S_NO));
  end;


procedure tx64tryfinallynode.pass_generate_code;
  var
    trylabel,
    endtrylabel,
    finallylabel,
    endfinallylabel,
    templabel,
    oldexitlabel: tasmlabel;
    oldflowcontrol: TFlowControl;
    catch_frame: boolean;
  begin
    if (TargetInfo.system<>system_x86_64_win64) then
      begin
        inherited pass_generate_code;
        exit;
      end;

    location_reset(location,LOC_VOID,OS_NO);

    { Do not generate a frame that catches exceptions if the only action
      would be reraising it. Doing so is extremely inefficient with SEH
      (in contrast with setjmp/longjmp exception handling) }
    catch_frame:=implicitframe and
      (CurrentProcInfo.procdef.proccalloption=pocall_safecall);

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
    cg.a_label(CurrentAsmData.CurrAsmList,trylabel);

    { try code }
    if assigned(left) then
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
        cg.a_label(CurrentAsmData.CurrAsmList, finallylabel);
        { jump over exception handler }
        cg.a_jmp_always(CurrentAsmData.CurrAsmList,templabel);
        { Handle the except block first, so endtrylabel serves both
          as end of scope and as unwind target. This way it is possible to
          encode everything into a single scope record. }
        cg.a_label(CurrentAsmData.CurrAsmList,endtrylabel);
        if (CurrentProcInfo.procdef.proccalloption=pocall_safecall) then
          begin
            handle_safecall_exception;
            cg.a_jmp_always(CurrentAsmData.CurrAsmList,endfinallylabel);
          end
        else
          InternalError(2014031601);
        cg.a_label(CurrentAsmData.CurrAsmList,templabel);
      end
    else
      begin
        { same as emit_nop but using finallylabel instead of dummy }
        cg.a_label(CurrentAsmData.CurrAsmList,finallylabel);
        finallylabel.increfs;
        CurrentAsmData.CurrAsmList.concat(Taicpu.op_none(A_NOP,S_NO));
        cg.a_label(CurrentAsmData.CurrAsmList,endtrylabel);
      end;

    { i32913 - if the try..finally block is also inside a try..finally or
      try..except block, make a note of any Exit calls so all necessary labels
      are generated. [Kit] }
    if ((flowcontrol*[fc_exit,fc_break,fc_continue])<>[]) and (fc_inflowcontrol in oldflowcontrol) then
      oldflowcontrol:=oldflowcontrol+(flowcontrol*[fc_exit,fc_break,fc_continue]);

    flowcontrol:=[fc_inflowcontrol];
    { generate finally code as a separate procedure }
    if not implicitframe then
      tcgprocinfo(CurrentProcInfo).generate_exceptfilter(finalizepi);
    { right is a call to finalizer procedure }
    SecondPass(right);

    if CodeGenError then
      exit;

    { normal exit from safecall proc must zero the result register }
    if implicitframe and (CurrentProcInfo.procdef.proccalloption=pocall_safecall) then
      cg.a_load_const_reg(CurrentAsmData.CurrAsmList,OS_INT,0,NR_FUNCTION_RESULT_REG);

    cg.a_label(CurrentAsmData.CurrAsmList,endfinallylabel);

    { generate the scope record in .xdata }
    tcpuprocinfo(CurrentProcInfo).add_finally_scope(trylabel,endtrylabel,
      CurrentAsmData.RefAsmSymbol(finalizepi.procdef.mangledname,AT_FUNCTION),catch_frame);

    if implicitframe then
      CurrentProcInfo.CurrExitLabel:=oldexitlabel;
    flowcontrol:=oldflowcontrol;
  end;

{ tx64tryexceptnode }

procedure tx64tryexceptnode.pass_generate_code;
  var
    trylabel,
    exceptlabel,oldendexceptlabel,
    lastonlabel,
    exitexceptlabel,
    continueexceptlabel,
    breakexceptlabel,
    oldCurrExitLabel,
    oldContinueLabel,
    oldBreakLabel : tasmlabel;
    onlabel,
    filterlabel: tasmlabel;
    oldflowcontrol,tryflowcontrol,
    exceptflowcontrol : TFlowControl;
    hnode : TNode;
    hlist : tasmlist;
    onnodecount : tai_const;
    sym : tasmsymbol;
  label
    errorexit;
  begin
    if (TargetInfo.system<>system_x86_64_win64) then
      begin
        inherited pass_generate_code;
        exit;
      end;
    location_reset(location,LOC_VOID,OS_NO);

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
    if assigned(CurrentProcInfo.CurrBreakLabel) then
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
    cg.a_label(CurrentAsmData.CurrAsmList,trylabel);

    { control flow in try block needs no special handling,
      just make sure that target labels are outside the scope }
    SecondPass(left);
    tryflowcontrol:=flowcontrol;
    if CodeGenError then
      goto errorexit;

    { jump over except handlers }
    cg.a_jmp_always(CurrentAsmData.CurrAsmList,endexceptlabel);

    { end of scope }
    cg.a_label(CurrentAsmData.CurrAsmList,exceptlabel);

    { set control flow labels for the except block }
    { and the on statements                        }
    CurrentProcInfo.CurrExitLabel:=exitexceptlabel;
    if assigned(oldBreakLabel) then
      begin
        CurrentProcInfo.CurrContinueLabel:=continueexceptlabel;
        CurrentProcInfo.CurrBreakLabel:=breakexceptlabel;
      end;

    { i32913 - if the try..finally block is also inside a try..finally or
      try..except block, make a note of any Exit calls so all necessary labels
      are generated. [Kit] }
    if ((flowcontrol*[fc_exit,fc_break,fc_continue])<>[]) and (fc_inflowcontrol in oldflowcontrol) then
      oldflowcontrol:=oldflowcontrol+(flowcontrol*[fc_exit,fc_break,fc_continue]);

    flowcontrol:=[fc_inflowcontrol];
    { on statements }
    if assigned(right) then
      begin
        { emit filter table to a temporary asmlist }
        hlist:=TAsmList.Create;
        CurrentAsmData.getaddrlabel(filterlabel);
        new_section(hlist,sec_rodata_norel,filterlabel.name,4);
        cg.a_label(hlist,filterlabel);
        onnodecount:=tai_const.create_32bit(0);
        hlist.concat(onnodecount);

        hnode:=right;
        while assigned(hnode) do
          begin
            if hnode.nodetype<>onn then
              InternalError(2011103101);
            CurrentAsmData.getjumplabel(onlabel);
            sym:=CurrentAsmData.RefAsmSymbol(tonnode(hnode).excepttype.vmt_mangledname,AT_DATA,true);
            hlist.concat(tai_const.create_rva_sym(sym));
            hlist.concat(tai_const.create_rva_sym(onlabel));
            CurrentModule.add_extern_asmsym(sym);
            cg.a_label(CurrentAsmData.CurrAsmList,onlabel);
            SecondPass(hnode);
            inc(onnodecount.value);
            hnode:=tonnode(hnode).left;
          end;
        { add 'else' node to the filter list, too }
        if assigned(t1) then
          begin
            hlist.concat(tai_const.create_32bit(-1));
            hlist.concat(tai_const.create_rva_sym(lastonlabel));
            inc(onnodecount.value);
          end;
        { now move filter table to permanent list all at once }
        CurrentProcInfo.aktlocaldata.concatlist(hlist);
        hlist.free;
      end;

    cg.a_label(CurrentAsmData.CurrAsmList,lastonlabel);
    if assigned(t1) then
      begin
        { here we don't have to reset flowcontrol           }
        { the default and on flowcontrols are handled equal }
        SecondPass(t1);
        cg.g_call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        if (flowcontrol*[fc_exit,fc_break,fc_continue]<>[]) then
          cg.a_jmp_always(CurrentAsmData.CurrAsmList,endexceptlabel);
      end;
    exceptflowcontrol:=flowcontrol;

    if fc_exit in exceptflowcontrol then
      begin
        { do some magic for exit in the try block }
        cg.a_label(CurrentAsmData.CurrAsmList,exitexceptlabel);
        cg.g_call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        if (fc_unwind_exit in oldflowcontrol) then
          cg.g_local_unwind(CurrentAsmData.CurrAsmList,oldCurrExitLabel)
        else
          cg.a_jmp_always(CurrentAsmData.CurrAsmList,oldCurrExitLabel);
      end;

    if fc_break in exceptflowcontrol then
      begin
        cg.a_label(CurrentAsmData.CurrAsmList,breakexceptlabel);
        cg.g_call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        if (fc_unwind_loop in oldflowcontrol) then
          cg.g_local_unwind(CurrentAsmData.CurrAsmList,oldBreakLabel)
        else
          cg.a_jmp_always(CurrentAsmData.CurrAsmList,oldBreakLabel);
      end;

    if fc_continue in exceptflowcontrol then
      begin
        cg.a_label(CurrentAsmData.CurrAsmList,continueexceptlabel);
        cg.g_call(CurrentAsmData.CurrAsmList,'FPC_DONEEXCEPTION');
        if (fc_unwind_loop in oldflowcontrol) then
          cg.g_local_unwind(CurrentAsmData.CurrAsmList,oldContinueLabel)
        else
          cg.a_jmp_always(CurrentAsmData.CurrAsmList,oldContinueLabel);
      end;

    emit_nop;
    cg.a_label(CurrentAsmData.CurrAsmList,endexceptlabel);
    tcpuprocinfo(CurrentProcInfo).add_except_scope(trylabel,exceptlabel,endexceptlabel,filterlabel);

errorexit:
    { restore all saved labels }
    endexceptlabel:=oldendexceptlabel;

    { i32913 - if the try..finally block is also inside a try..finally or
      try..except block, make a note of any Exit calls so all necessary labels
      are generated. [Kit] }
    if ((flowcontrol*[fc_exit,fc_break,fc_continue])<>[]) and (fc_inflowcontrol in oldflowcontrol) then
      oldflowcontrol:=oldflowcontrol+(flowcontrol*[fc_exit,fc_break,fc_continue]);

    { restore the control flow labels }
    CurrentProcInfo.CurrExitLabel:=oldCurrExitLabel;
    if assigned(oldBreakLabel) then
      begin
        CurrentProcInfo.CurrContinueLabel:=oldContinueLabel;
        CurrentProcInfo.CurrBreakLabel:=oldBreakLabel;
      end;

    { return all used control flow statements }
    flowcontrol:=oldflowcontrol+(exceptflowcontrol +
      tryflowcontrol - [fc_inflowcontrol]);
  end;

initialization
  craisenode:=tx64raisenode;
  connode:=tx64onnode;
  ctryexceptnode:=tx64tryexceptnode;
  ctryfinallynode:=tx64tryfinallynode;
end.

