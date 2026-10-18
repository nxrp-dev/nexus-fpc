{
    Replaces calls by inline code

    Copyright (c) 1998-2026 by Florian Klaempfl and others

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

unit optcall;

{$i fpcdefs.inc}

{ $define EXTDEBUG_INLINE}

  interface

    uses
      node;

    procedure do_optinline(var rootnode : TNode;out changed: boolean);

  implementation

    uses
      CClasses,
      Verbose,Globals,
      defutil,defcmp,
      symconst,symtype,symdef,SymSym,
      parabase,paramgr,
      ProcInfo,
      nutils,
      FModule,
      Pass_1,
      nbas,ncal,nld;

    { this procedure removes the user code flag because it prevents optimizations }
    function removeusercodeflag(var n : TNode; arg : pointer) : TForEachNodeResult;
      begin
        result:=fen_false;
        if nf_usercode_entry in n.flags then
          begin
            exclude(n.flags,nf_usercode_entry);
            result:=fen_norecurse_true;
          end;
      end;


    function setinlinelevel(var n:TNode; arg:pointer):TForEachNodeResult;
      begin
        if n.nodetype=calln then
          TCallNode(n).InlineLevel:=PtrUInt(arg);
        result:=fen_false;
      end;


    { reference symbols that are imported from another unit }
    function importglobalsyms(var n:TNode; arg:pointer):TForEachNodeResult;
      var
        sym : TSym;
      begin
        result:=fen_false;
        if n.nodetype=loadn then
          begin
            sym:=TLoadNode(n).SymTableEntry;
            if sym.typ=staticvarsym then
              begin
                if FindUnitSymTable(TLoadNode(n).SymTable).ModuleID<>CurrentModule.ModuleID then
                  CurrentModule.AddImportedSym(sym);
              end
            else if (sym.typ=constsym) and (TConstSym(sym).ConstTyp in [constwresourcestring,constresourcestring]) then
              begin
                if TLoadNode(n).SymTableEntry.owner.ModuleID<>CurrentModule.ModuleID then
                  CurrentModule.AddImportedSym(sym);
              end;
          end
        else if (n.nodetype=calln) then
          begin
            if (Assigned(TCallNode(n).ProcDefinition)) and
               (TCallNode(n).ProcDefinition.typ=procdef) and
               (FindUnitSymTable(TCallNode(n).ProcDefinition.owner).ModuleID<>CurrentModule.ModuleID) then
              CurrentModule.AddImportedSym(TProcDef(TCallNode(n).ProcDefinition).ProcSym);
          end;
      end;


    function redoalinaparams(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        result:=fen_false;
        if n.nodetype=calln then
          begin
            { re-init varargs paraloc that may have been invalidated by inlining }
            if Assigned(TCallNode(n).VarArgsParas) then
              ParaManager.Create_VarArgs_ParaLoc_Info(TCallNode(n).ProcDefinition,callerside,TCallNode(n).VarArgsParas);
            TCallNode(n).Order_Parameters;
          end;
      end;


    function doinline(var _n: TNode; arg: pointer): TForEachNodeResult;
      var
        n,
        body : TNode;
        para : TCallParaNode;
        inlineblock,
        inlinecleanupblock : TBlockNode;
        callnode: TCallNode;
      begin
        result:=fen_false;
        if not(_n.nodetype=calln) or not(po_inline in TCallNode(_n).ProcDefinition.ProcOptions) then
          exit;
        callnode:=TCallNode(_n);

        if not(callnode.DoInlining) then
          begin
            if not(po_compilerproc in callnode.ProcDefinition.ProcOptions) then
              Message1(cg_n_no_inline,TProcDef(callnode.ProcDefinition).CustomProcName([pno_proctypeoption, pno_paranames,pno_ownername, pno_noclassmarker, pno_prettynames]));
            exit;
          end;

        if not(Assigned(TProcDef(callnode.ProcDefinition).InliningInfo) and
          Assigned(TProcDef(callnode.ProcDefinition).InliningInfo^.code)) then
          InternalError(200412021);

        callnode.InlineLocals:=TFPObjectList.Create(true);

        { inherit flags }
        CurrentProcInfo.flags:=CurrentProcInfo.flags+
          ((callnode.ProcDefinition as TProcDef).InliningInfo^.flags*Inherited_Inlining_Flags);

        { Create new code block for inlining }
        inlineblock:=InternalStatements(callnode.InlineInitStatement);
        { make sure that valid_for_assign() returns false for this block
          (otherwise assigning values to the block will result in assigning
           values to the inlined function's result) }
        include(inlineblock.flags,nf_no_lvalue);
        inlinecleanupblock:=InternalStatements(callnode.InlineCleanupStatement);

        if Assigned(callnode.CallInitBlock) then
          AddStatement(callnode.InlineInitStatement,callnode.CallInitBlock.GetCopy);

        { replace complex parameters with temps }
        callnode.CreateInlineParas;

        { create a copy of the body and replace parameter loads with the parameter values }
        body:=TProcDef(callnode.ProcDefinition).InliningInfo^.code.GetCopy;
        ForEachNodeStatic(pm_postprocess,body,@ removeusercodeflag,nil);
        ForEachNodeStatic(pm_postprocess,body,@importglobalsyms,nil);
        ForEachNodeStatic(pm_postprocess,body,@setinlinelevel,pointer(callnode.InlineLevel+1));
        ForEachNode(pm_preprocess,body,@callnode.ReplaceParaLoad,@callnode.fileinfo);

        { Concat the body and finalization parts }
        AddStatement(callnode.InlineInitStatement,body);
        AddStatement(callnode.InlineInitStatement,inlinecleanupblock);
        inlinecleanupblock:=nil;

        if Assigned(callnode.CallCleanupBlock) then
          AddStatement(callnode.InlineInitStatement,callnode.CallCleanupBlock.GetCopy);

        { the last statement of the new inline block must return the
          location and type of the function result.
          This is not needed when the result is not used, also the tempnode is then
          already destroyed  by a tempdelete in the callcleanupblock tree }
        if not Is_Void(callnode.resultdef) and
           (cnf_return_value_used in callnode.CallNodeFlags) then
          begin
            if Assigned(callnode.FuncRetNode) then
              AddStatement(callnode.InlineInitStatement,callnode.FuncRetNode.GetCopy)
            else
              begin
                para:=TCallParaNode(callnode.left);
                while Assigned(para) do
                  begin
                    if (vo_is_hidden_para in para.ParaSym.VarOptions) and
                       (vo_is_funcret in para.ParaSym.VarOptions) then
                      begin
                        AddStatement(callnode.InlineInitStatement,para.left.GetCopy);
                        break;
                      end;
                    para:=TCallParaNode(para.right);
                  end;
              end;
          end;

        TypeCheckPass(TNode(inlineblock));
        DoInlineSimplify(TNode(inlineblock));
        FirstPass(TNode(inlineblock));
        _n:=inlineblock;

        { if the function result is used then verify that the blocknode
          returns the same result type as the original callnode }
        if (cnf_return_value_used in callnode.CallNodeFlags) and
           not(Equal_Defs(_n.resultdef,callnode.resultdef)) then
          InternalError(200709171);

        { free the temps for the locals }
        callnode.InlineLocals.free;
        callnode.InlineLocals:=nil;
        callnode.InlineInitStatement:=nil;
        callnode.InlineCleanupStatement:=nil;

        n:=callnode.Optimize_FuncRet_Assignment(inlineblock);
        if Assigned(n) then
          begin
            inlineblock.free;
            inlineblock:=nil;
            _n:=n;
          end;

        { the inlined block takes the place of the call node, so it has to
          inherit its currency scaling state: without it, the enclosing
          taddnode sees an operand that is no longer marked as scaled and
          taddnode.do_currency_corrections applies the 10000 scalar a second
          time }
        if (cnf_return_value_used in callnode.CallNodeFlags) and
           (nf_is_currency in callnode.flags) then
          include(_n.flags,nf_is_currency);

        PBoolean(arg)^:=true;

{$ifdef EXTDEBUG_INLINE}
        WriteLn;
        WriteLn('**************************************************************************************************************');
        WriteLn('************************** Inlined ',TProcDef(callnode.ProcDefinition).MangledName,'**************************');
        WriteLn('**************************************************************************************************************');
{$endif EXTDEBUG_INLINE}
      end;


    procedure do_optinline(var rootnode: TNode;out changed: boolean);
      begin
        changed:=false;
{$ifdef EXTDEBUG_INLINE}
        WriteLn('************************ Tree before inlining ******************************');
        PrintNode(rootnode);
        WriteLn('****************************************************************************');
{$endif EXTDEBUG_INLINE}
        ForEachNodeStatic(pm_postprocess, rootnode, @doinline, @changed);
        if changed then
          begin
            DoInlineSimplify(rootnode);
            { after inlining, call nodes in the tree may have parameters
              whose subtrees now contain additional calls (e.g. fpc_shortstr_sint
              from an inlined str() call). The parent call nodes need their
              parameter analysis redone to recalculate parameter ordering and
              stack tainting info, otherwise parameters may be evaluated in the
              wrong order corrupting already pushed stack parameters }
            ForEachNodeStatic(pm_postprocess,rootnode,@redoalinaparams,nil);
{$ifdef EXTDEBUG_INLINE}
            WriteLn('************************ Tree after inlining ******************************');
            PrintNode(rootnode);
            WriteLn('****************************************************************************');
{$endif EXTDEBUG_INLINE}
          end;
      end;

end.

