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
      pass_1,
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
          TCallNode(n).inlinelevel:=PtrUInt(arg);
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
            sym:=TLoadNode(n).symtableentry;
            if sym.typ=staticvarsym then
              begin
                if FindUnitSymTable(TLoadNode(n).SymTable).ModuleID<>CurrentModule.ModuleID then
                  CurrentModule.AddImportedSym(sym);
              end
            else if (sym.typ=constsym) and (TConstSym(sym).ConstTyp in [constwresourcestring,constresourcestring]) then
              begin
                if TLoadNode(n).symtableentry.owner.ModuleID<>CurrentModule.ModuleID then
                  CurrentModule.AddImportedSym(sym);
              end;
          end
        else if (n.nodetype=calln) then
          begin
            if (Assigned(TCallNode(n).procdefinition)) and
               (TCallNode(n).procdefinition.typ=procdef) and
               (FindUnitSymTable(TCallNode(n).procdefinition.owner).ModuleID<>CurrentModule.ModuleID) then
              CurrentModule.AddImportedSym(TProcDef(TCallNode(n).procdefinition).ProcSym);
          end;
      end;


    function redoalinaparams(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        result:=fen_false;
        if n.nodetype=calln then
          begin
            { re-init varargs paraloc that may have been invalidated by inlining }
            if Assigned(TCallNode(n).varargsparas) then
              ParaManager.Create_VarArgs_ParaLoc_Info(TCallNode(n).procdefinition,callerside,TCallNode(n).varargsparas);
            TCallNode(n).order_parameters;
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
        if not(_n.nodetype=calln) or not(po_inline in TCallNode(_n).procdefinition.ProcOptions) then
          exit;
        callnode:=TCallNode(_n);

        if not(callnode.doinlining) then
          begin
            if not(po_compilerproc in callnode.procdefinition.ProcOptions) then
              Message1(cg_n_no_inline,TProcDef(callnode.procdefinition).CustomProcName([pno_proctypeoption, pno_paranames,pno_ownername, pno_noclassmarker, pno_prettynames]));
            exit;
          end;

        if not(Assigned(TProcDef(callnode.procdefinition).InliningInfo) and
          Assigned(TProcDef(callnode.procdefinition).InliningInfo^.code)) then
          InternalError(200412021);

        callnode.inlinelocals:=TFPObjectList.create(true);

        { inherit flags }
        CurrentProcInfo.flags:=CurrentProcInfo.flags+
          ((callnode.procdefinition as TProcDef).InliningInfo^.flags*inherited_inlining_flags);

        { Create new code block for inlining }
        inlineblock:=internalstatements(callnode.inlineinitstatement);
        { make sure that valid_for_assign() returns false for this block
          (otherwise assigning values to the block will result in assigning
           values to the inlined function's result) }
        include(inlineblock.flags,nf_no_lvalue);
        inlinecleanupblock:=internalstatements(callnode.inlinecleanupstatement);

        if Assigned(callnode.callinitblock) then
          addstatement(callnode.inlineinitstatement,callnode.callinitblock.GetCopy);

        { replace complex parameters with temps }
        callnode.createinlineparas;

        { create a copy of the body and replace parameter loads with the parameter values }
        body:=TProcDef(callnode.procdefinition).InliningInfo^.code.GetCopy;
        foreachnodestatic(pm_postprocess,body,@ removeusercodeflag,nil);
        foreachnodestatic(pm_postprocess,body,@importglobalsyms,nil);
        foreachnodestatic(pm_postprocess,body,@setinlinelevel,pointer(callnode.inlinelevel+1));
        foreachnode(pm_preprocess,body,@callnode.replaceparaload,@callnode.fileinfo);

        { Concat the body and finalization parts }
        addstatement(callnode.inlineinitstatement,body);
        addstatement(callnode.inlineinitstatement,inlinecleanupblock);
        inlinecleanupblock:=nil;

        if Assigned(callnode.callcleanupblock) then
          addstatement(callnode.inlineinitstatement,callnode.callcleanupblock.GetCopy);

        { the last statement of the new inline block must return the
          location and type of the function result.
          This is not needed when the result is not used, also the tempnode is then
          already destroyed  by a tempdelete in the callcleanupblock tree }
        if not Is_Void(callnode.resultdef) and
           (cnf_return_value_used in callnode.callnodeflags) then
          begin
            if Assigned(callnode.funcretnode) then
              addstatement(callnode.inlineinitstatement,callnode.funcretnode.GetCopy)
            else
              begin
                para:=TCallParaNode(callnode.left);
                while Assigned(para) do
                  begin
                    if (vo_is_hidden_para in para.parasym.VarOptions) and
                       (vo_is_funcret in para.parasym.VarOptions) then
                      begin
                        addstatement(callnode.inlineinitstatement,para.left.GetCopy);
                        break;
                      end;
                    para:=TCallParaNode(para.right);
                  end;
              end;
          end;

        TypeCheckPass(TNode(inlineblock));
        doinlinesimplify(TNode(inlineblock));
        FirstPass(TNode(inlineblock));
        _n:=inlineblock;

        { if the function result is used then verify that the blocknode
          returns the same result type as the original callnode }
        if (cnf_return_value_used in callnode.callnodeflags) and
           not(Equal_Defs(_n.resultdef,callnode.resultdef)) then
          InternalError(200709171);

        { free the temps for the locals }
        callnode.inlinelocals.free;
        callnode.inlinelocals:=nil;
        callnode.inlineinitstatement:=nil;
        callnode.inlinecleanupstatement:=nil;

        n:=callnode.optimize_funcret_assignment(inlineblock);
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
        if (cnf_return_value_used in callnode.callnodeflags) and
           (nf_is_currency in callnode.flags) then
          include(_n.flags,nf_is_currency);

        PBoolean(arg)^:=true;

{$ifdef EXTDEBUG_INLINE}
        WriteLn;
        WriteLn('**************************************************************************************************************');
        WriteLn('************************** Inlined ',TProcDef(callnode.procdefinition).MangledName,'**************************');
        WriteLn('**************************************************************************************************************');
{$endif EXTDEBUG_INLINE}
      end;


    procedure do_optinline(var rootnode: TNode;out changed: boolean);
      begin
        changed:=false;
{$ifdef EXTDEBUG_INLINE}
        WriteLn('************************ Tree before inlining ******************************');
        printnode(rootnode);
        WriteLn('****************************************************************************');
{$endif EXTDEBUG_INLINE}
        foreachnodestatic(pm_postprocess, rootnode, @doinline, @changed);
        if changed then
          begin
            doinlinesimplify(rootnode);
            { after inlining, call nodes in the tree may have parameters
              whose subtrees now contain additional calls (e.g. fpc_shortstr_sint
              from an inlined str() call). The parent call nodes need their
              parameter analysis redone to recalculate parameter ordering and
              stack tainting info, otherwise parameters may be evaluated in the
              wrong order corrupting already pushed stack parameters }
            foreachnodestatic(pm_postprocess,rootnode,@redoalinaparams,nil);
{$ifdef EXTDEBUG_INLINE}
            WriteLn('************************ Tree after inlining ******************************');
            printnode(rootnode);
            WriteLn('****************************************************************************');
{$endif EXTDEBUG_INLINE}
          end;
      end;

end.

