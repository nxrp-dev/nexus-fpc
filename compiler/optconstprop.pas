{
    Constant propagation across statements

    Copyright (c) 2005-2012 by Jeppe Johansen and Florian Klaempfl

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
unit optconstprop;

{$i fpcdefs.inc}

{ $define DEBUG_CONSTPROP}

  interface

    uses
      node;

    { does constant propagation for rootnode

      The approach is simple: It search for constant assignment statements. As soon as such
      a statement is found, the following statements are search if they contain
      a usage of the assigned variable. If this is a the case, the variable is
      replaced by the constant. This does not work across points where the
      program flow joins so e.g.

      if ... then
        ...
        a:=1;
        ...
      else
        ...
        a:=1;
        ...
      writeln(a);

      will not result in any constant propagation.
    }
    function do_optconstpropagate(var rootnode : TNode;out changed: boolean) : TNode;

  implementation

    uses
      GlobType,CDynSet,Globals,
      pass_1,ProcInfo,compinnr,
      SymSym, symconst,
      nutils, nbas, ncnv, nld, nflw, ncal, ninl,
      optbase, optutils;

    function check_written(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        result:=fen_false;

        if n.isequal(TNode(arg)) and
           ((n.flags*[nf_write,nf_modify])<>[]) then
          begin
            result:=fen_norecurse_true;
          end;
      end;


    { propagates the constant assignment passed in arg into n, it returns true if
      the search can continue with the next statement }
    function replaceBasicAssign(var n: TNode; arg: TNode; var tree_modified: boolean): boolean;
      var
        st2, oldnode: TNode;
        old: PNode;
        changed, tree_modified2, tree_modified3: boolean;
        written, tree_modified4, tree_modified5: Boolean;
      begin
        result:=true;

        if n = nil then
          exit;

        tree_modified:=false;
        tree_modified2:=false;
        tree_modified3:=false;
        tree_modified4:=false;
        tree_modified5:=false;

        { while it might be useful, to use foreach to iterate all nodes, it is safer to
          iterate manually here so we have full control how all nodes are processed }

        { We cannot analyze beyond those nodes, so we terminate to be on the safe side }
        if (n.nodetype in [addrn,derefn,asmn,casen,whilerepeatn,labeln,continuen,breakn,
                           tryexceptn,raisen,tryfinallyn,onn,loadparentfpn,loadvmtaddrn,guidconstn,rttin,addoptn,asn,goton,
                           objcselectorn,objcprotocoln,
                           arrayconstructorn,arrayconstructorrangen]) then
          exit(false)
        else if n.nodetype=assignn then
          begin
            tree_modified:=false;

            { we can propagate the constant in both branches because the evaluation order is not defined }
            result:=replaceBasicAssign(TAssignmentNode(n).right, arg, tree_modified);
            { do not use the intuitive way result:=result and replace... because this would prevent
              replaceBasicAssign being called if the result is already false }
            result:=replaceBasicAssign(TAssignmentNode(n).left, arg, tree_modified2) and result;
            tree_modified:=tree_modified or tree_modified2;

            { but we have to check if left writes to the currently searched variable ... }
            written:=foreachnodestatic(pm_postprocess, TAssignmentNode(n).left, @check_written, TAssignmentNode(arg).left);
            { ... if this is the case, we have to stop searching }
            result:=result and not(written);
          end
        else if n.isequal(TAssignmentNode(arg).left) and ((n.flags*[nf_write,nf_modify])=[]) then
          begin
            n.Free;
            n:=TAssignmentNode(arg).right.GetCopy;
            inserttypeconv_internal(n, TAssignmentNode(arg).left.resultdef);

            tree_modified:=true;
          end
        else if n.nodetype=statementn then
          result:=replaceBasicAssign(TStatementNode(n).left, arg, tree_modified)
        else if n.nodetype=forn then
          begin
            result:=replaceBasicAssign(TForNode(n).right, arg, tree_modified);
            if result then
              begin
                { play safe and set the result which is check below }
                result:=replaceBasicAssign(TForNode(n).t1, arg, tree_modified2);
                tree_modified:=tree_modified or tree_modified2;
                if result and (pi_dfaavailable in CurrentProcInfo.flags) and
                  { play safe }
                  Assigned(TForNode(n).t2.optinfo) and Assigned(TAssignmentNode(arg).left.optinfo) then
                  begin
                    CalcDefSum(TForNode(n).t2);
                    { the constant can propagate if is is not the counter variable ... }
                    if not(TAssignmentNode(arg).left.isequal(actualtargetnode(@TForNode(n).left)^)) and
                    { if it is a temprefn or its address is not taken in case of loadn }
                      ((TAssignmentNode(arg).left.nodetype=temprefn) or not(TAbstractVarSym(TLoadNode(TAssignmentNode(arg).left).symtableentry).AddrTaken)) and
                      { and no definition in the loop? }
                      not(DynSetIn(TForNode(n).t2.optinfo^.defsum,TAssignmentNode(arg).left.optinfo^.index)) then
                      begin
                        result:=replaceBasicAssign(TForNode(n).t2, arg, tree_modified3);
                        tree_modified:=tree_modified or tree_modified3;
                      end
                    else
                      result:=false;
                  end
                else
                  result:=false;
              end;
          end
        else if n.nodetype=blockn then
          begin
            changed:=false;

            st2:=TStatementNode(TBlockNode(n).statements);
            old:=@TBlockNode(n).statements;
            while Assigned(st2) do
              begin
                repeat
                  oldnode:=st2;

                  tree_modified2:=false;
                  if not replaceBasicAssign(st2, arg, tree_modified2) then
                    begin
                      old^:=st2;
                      oldnode:=nil;
                      changed:=changed or tree_modified2;
                      result:=false;
                      break;
                    end
                  else
                    old^:=st2;
                  changed:=changed or tree_modified2;
                until oldnode=st2;

                if oldnode = nil then
                  break;

                old:=@TStatementNode(st2).next;
                st2:=TStatementNode(st2).next;
              end;

            tree_modified:=changed;
          end
        else if n.nodetype=ifn then
          begin
            result:=replaceBasicAssign(TIfNode(n).left, arg, tree_modified);

            if result then
              begin
                if Assigned(TIfNode(n).t1) then
                  begin
                    { we can propagate the constant in both branches of an if statement
                      because even if the the branch writes to it, the else branch gets the
                      unmodified value }
                    result:=replaceBasicAssign(TIfNode(n).right, arg, tree_modified2);

                    { do not use the intuitive way result:=result and replace... because this would prevent
                      replaceBasicAssign being called if the result is already false }
                    result:=replaceBasicAssign(TIfNode(n).t1, arg, tree_modified3) and result;

                    tree_modified:=tree_modified or tree_modified2 or tree_modified3;
                  end
                else
                  begin
                    result:=replaceBasicAssign(TIfNode(n).right, arg, tree_modified2);
                    tree_modified:=tree_modified or tree_modified2;
                  end;
              end;
          end
        else if n.nodetype=inlinen then
          begin
            { constant inc'ed/dec'ed? }
            if (TInlineNode(n).inlinenumber=in_dec_x) or (TInlineNode(n).inlinenumber=in_inc_x) then
              begin
                if TNode(TAssignmentNode(arg).left).isequal(TCallParaNode(TInlineNode(n).left).left) and
                  { Internal Inc/Dec flags are created through a tree transformation from
                    a previous ConstProp pass.  Setting it prevents an infinite loop where
                    Inc/Dec nodes are converted into an Add/Sub tree, and then converted
                    back to Inc/Dec by the forced firstpass run }
                  not (nf_internal in n.flags) and
                  (
                    not(Assigned(TCallParaNode(TInlineNode(n).left).right)) or
                    (TCallParaNode(TCallParaNode(TInlineNode(n).left).right).left.nodetype=ordconstn)
                  ) then
                  begin
                    { if the node just being searched is inc'ed/dec'ed then replace the inc/dec
                      by add/sub and force a second replacement pass }
                    oldnode:=n;
                    n:=TInlineNode(n).getaddsub_for_incdec;
                    Include(n.flags, nf_internal);
                    oldnode.free;
                    oldnode := nil;
                    tree_modified:=true;
                    { do not continue, value changed, if further const. propagations are possible, this is done
                      by the next pass }
                    result:=false;
                    exit;
                  end;
                { inc/dec might have a side effect, so stop here for now }
                result:=false;
                exit;
              end
            else if might_have_sideeffects(n) then
              exit(false);

            result:=replaceBasicAssign(TUnaryNode(n).left, arg, tree_modified);
          end
        else if n.nodetype=calln then
          begin
            { only propagate simply variables which are regable, this means that their address is not
              taken }
            if (TAssignmentNode(arg).left.nodetype=loadn) and
              (TAbstractVarSym(TLoadNode(TAssignmentNode(arg).left).symtableentry).VarRegable in [vr_fpureg,vr_mmreg,vr_intreg]) then
              begin
                result:=replaceBasicAssign(TNode(TCallNode(n).callinitblock), arg, tree_modified);
                result:=result and replaceBasicAssign(TCallNode(n).left, arg, tree_modified2);
                result:=result and replaceBasicAssign(TCallNode(n).vmt_entry, arg, tree_modified3);
                result:=result and replaceBasicAssign(TCallNode(n).right, arg, tree_modified4);
                result:=result and replaceBasicAssign(TNode(TCallNode(n).callcleanupblock), arg, tree_modified5);
                tree_modified:=tree_modified or tree_modified2 or tree_modified3 or tree_modified4 or tree_modified5;

                { If the parameters were simplified, we may be able to simplify
                  the call node otherwise just exit to save time }
                if not tree_modified2 then
                  Exit;
              end
            else
              begin
                result:=false;
                exit;
              end;
          end
        else if n.InheritsFrom(TBinaryNode) then
          begin
            result:=replaceBasicAssign(TBinaryNode(n).left, arg, tree_modified);
            if result then
              result:=replaceBasicAssign(TBinaryNode(n).right, arg, tree_modified2);
            tree_modified:=tree_modified or tree_modified2;
          end
        else if n.InheritsFrom(TUnaryNode) then
          begin
            result:=replaceBasicAssign(TUnaryNode(n).left, arg, tree_modified);
          end;

        if tree_modified and (n.nodetype<>callparan) then
          begin
            exclude(n.transientflags,tnf_pass1_done);
            DoFirstPass(n);
          end;
      end;


    function propagate(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        l,
        st, st2, oldnode: TNode;
        old: PNode;
        a: TAssignmentNode;
        tree_mod, changed: boolean;
      begin
        result:=fen_true;

        changed:=false;
        PBoolean(arg)^:=false;

        if not Assigned(n) then
          exit;

        if n.nodetype in [calln] then
          exit(fen_norecurse_true);

        if n.nodetype=blockn then
          begin
            st:=TBlockNode(n).statements;

            while Assigned(st) and
                  (st.nodetype=statementn) and
                  Assigned(TStatementNode(st).statement) do
              begin
                if TStatementNode(st).statement.nodetype=assignn then
                  begin
                    a:=TAssignmentNode(TStatementNode(st).statement);

                    l:=a.left;

                    if ((((l.nodetype=loadn) and
                         { its address cannot have escaped the current routine }
                         not(TAbstractVarSym(TLoadNode(l).symtableentry).AddrTaken)) and
                         ((
                           (TLoadNode(l).symtableentry.typ=localvarsym) and
                           (TLoadNode(l).SymTable=CurrentProcInfo.procdef.LocalST)
                          ) or
                          ((TLoadNode(l).symtableentry.typ=paravarsym) and
                           (TLoadNode(l).SymTable=CurrentProcInfo.procdef.ParaST)
                          ) or
                          ((TLoadNode(l).symtableentry.typ=staticvarsym) and
                           (TLoadNode(l).SymTable.SymTableType=staticsymtable)
                          )
                         )) or
                        (l.nodetype = temprefn)) and
                       (is_constintnode(a.right) or
                        is_constrealnode(a.right) or
                        is_constboolnode(a.right) or
                        is_constcharnode(a.right) or
                        is_constwidecharnode(a.right) or
                        is_constwidestringnode(a.right) or
                        is_constenumnode(a.right) or
                        is_conststringnode(a.right) or
                        is_constpointernode(a.right)) then
                      begin
{$ifdef DEBUG_CONSTPROP}
                        WriteLn('******************************* propagating ***********************************');
                        printnode(Output,a);
                        WriteLn('*******************************************************************************');
{$endif DEBUG_CONSTPROP}
                        st2:=TStatementNode(TStatementNode(st).right);
                        old:=@TStatementNode(st).right;
                        while Assigned(st2) do
                          begin
                            repeat
                              oldnode:=st2;

                              { Simple assignment of constant found }
                              tree_mod:=false;
                              if not replaceBasicAssign(st2, a, tree_mod) then
                                begin
                                  old^:=st2;
                                  oldnode:=nil;
                                  changed:=changed or tree_mod;
                                  break;
                                end
                              else
                                old^:=st2;
                              changed:=changed or tree_mod;
                            until oldnode=st2;

                            if oldnode = nil then
                              break;

                            old:=@TStatementNode(st2).next;
                            st2:=TStatementNode(st2).next;
                          end;
                      end;
                  end;

                st:=TStatementNode(st).next;
              end;
          end;

        PBoolean(arg)^:=changed;
      end;


    function do_optconstpropagate(var rootnode: TNode;out changed: boolean): TNode;
      var
        iteration_changed: Boolean;
      begin
        changed:=false;
        repeat
          iteration_changed:=false;
{$ifdef DEBUG_CONSTPROP}
          WriteLn('************************ before constant propagation ***************************');
          printnode(Output,rootnode);
{$endif DEBUG_CONSTPROP}
          foreachnodestatic(pm_postandagain, rootnode, @propagate, @iteration_changed);
          changed:=changed or iteration_changed;
          if iteration_changed then
            doinlinesimplify(rootnode);
{$ifdef DEBUG_CONSTPROP}
          WriteLn('************************ after constant propagation ***************************');
          printnode(Output,rootnode);
          WriteLn('*******************************************************************************');
{$endif DEBUG_CONSTPROP}
        until not(cs_opt_level3 in CurrentSettings.OptimizerSwitches) or not(iteration_changed);
        result:=rootnode;
      end;

end.

