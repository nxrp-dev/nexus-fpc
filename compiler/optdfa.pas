{
    DFA

    Copyright (c) 2007 by Florian Klaempfl

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

{ $define DEBUG_DFA}

{ this unit implements routines to perform dfa }
unit optdfa;

{$i fpcdefs.inc}

  interface

    uses
      node,optutils;

    type
      TDFABuilder = class
      protected
        procedure CreateLifeInfo(node : TNode;map : TIndexedNodeSet);
      public
        resultnode : TNode;
        nodemap : TIndexedNodeSet;
        { reset all dfa info, this is required before creating dfa info
          if the tree has been changed without updating dfa }
        procedure resetdfainfo(node : TNode);

        procedure createdfainfo(node : TNode);
        procedure redodfainfo(node : TNode);
        destructor Destroy;override;
      end;

    procedure CheckAndWarn(code : TNode;nodetosearch : TNode);

  implementation

    uses
      GlobType,CDynSet,
      Systems,
      ConstExp,
      Verbose,
      symconst,symdef,SymSym,
      defutil,
      ProcInfo,
      nutils,htypechk,
      nbas,nflw,ncal,nset,nld,nadd,
      optbase;


    (*
    function initnodes(var n:tnode; arg: pointer) : foreachnoderesult;
      begin
        { node worth to add? }
        if (node_complexity(n)>1) and (tstoreddef(n.resultdef).is_intregable or tstoreddef(n.resultdef).is_fpuregable) then
          begin
            plists(arg)^.nodelist.Add(n);
            plists(arg)^.locationlist.Add(@n);
            result:=fen_false;
          end
        else
          result:=fen_norecurse_false;
      end;
    *)

    {
      x:=f;         read: [f]

      while x do    read: []

        a:=b;       read: [a,b,d]  def: [a]       life:  read*def=[a]
          c:=d;     read: [a,d]    def: [a,c]     life:  read*def=[a]
            e:=a;   read: [a]      def: [a,c,e]   life:  read*def=[a]


      function f(b,d,x : type) : type;

        begin
          while x do        alive: b,d,x
            begin
              a:=b;         alive: b,d,x
              c:=d;         alive: a,d,x
              e:=a+c;       alive: a,c,x
              dec(x);       alive: c,e,x
            end;
          result:=c+e;      alive: c,e
        end;                alive: result

    }

    type
      TDFAInfo = record
        use : PDFASet;
        def : PDFASet;
        map : TIndexedNodeSet
      end;
      PDFAInfo = ^TDFAInfo;

    function AddDefUse(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        case n.nodetype of
          tempcreaten:
            begin
              if Assigned(TTempCreateNode(n).tempinfo^.tempinitcode) then
                begin
                  PDFAInfo(arg)^.map.Add(n);
                  DynSetInclude(PDFAInfo(arg)^.def^,n.optinfo^.Index);
                end;
            end;
          temprefn,
          loadn:
            begin
              PDFAInfo(arg)^.map.Add(n);
              if nf_modify in n.flags then
                begin
                  DynSetInclude(PDFAInfo(arg)^.use^,n.optinfo^.Index);
                  DynSetInclude(PDFAInfo(arg)^.def^,n.optinfo^.Index)
                end
              else if nf_write in n.flags then
                DynSetInclude(PDFAInfo(arg)^.def^,n.optinfo^.Index)
              else
                DynSetInclude(PDFAInfo(arg)^.use^,n.optinfo^.Index);
            end;
          else
            ;
        end;
        result:=fen_false;
      end;


    function ResetProcessing(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        exclude(n.transientflags,tnf_processing);
        { dfa works only on normalized trees, so do not recurse into expressions, because
          ResetProcessing eats a significant amount of time of CheckAndWarn

          the following set contains (hopefully) most of the expression nodes }
        if n.nodetype in [calln,inlinen,assignn,callparan,andn,addn,orn,subn,muln,divn,slashn,notn,EqualN,unequaln,gtn,ltn,lten,gten,loadn,
          typeconvn,vecn,subscriptn,addrn,derefn] then
          result:=fen_norecurse_false
        else
          result:=fen_false;
      end;


    function ResetDFA(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        if Assigned(n.optinfo) then
          begin
            with n.optinfo^ do
              begin
                life:=nil;
                def:=nil;
                use:=nil;
                defsum:=nil;
              end;
          end;
        result:=fen_false;
      end;


    procedure TDFABuilder.CreateLifeInfo(node : TNode;map : TIndexedNodeSet);

      var
        changed : boolean;

      procedure CreateInfo(node : TNode);

        { update life entry of a node with l, set changed if this changes
          life info for the node
        }
        procedure updatelifeinfo(n : TNode;const l : TDFASet);
          begin
            if not DynSetNotEqual(l,n.optinfo^.life) then
              exit;
{$ifdef DEBUG_DFA}
            if not(changed) then
              begin
                WriteLn('Another DFA pass caused by: ',nodetype2str[n.nodetype],'(',n.fileinfo.line,',',n.fileinfo.column,')');
                write('  Life info set was:     ');PrintDynSet(Output,n.optinfo^.life);WriteLn;
                write('  Life info set will be: ');PrintDynSet(Output,l);WriteLn;
              end;
{$endif DEBUG_DFA}

            changed:=true;
            n.optinfo^.life:=l;
          end;

        procedure calclife(n : TNode);
          var
            l : TDFASet;
          begin
            if Assigned(n.successor) then
              begin
                { ensure we can access optinfo }
                DynSetDiff(l,n.successor.optinfo^.life,n.optinfo^.def);
                DynSetIncludeSet(l,n.optinfo^.use);
                DynSetIncludeSet(l,n.optinfo^.life);
              end
            else
              begin
                l:=n.optinfo^.use;
                DynSetIncludeSet(l,n.optinfo^.life);
              end;
            updatelifeinfo(n,l);
          end;

        var
          dfainfo : TDFAInfo;
          l : TDFASet;
          save: TDFASet;
          lv, hv: TConstExprInt;
          i : LongInt;
          counteruse_after_loop : boolean;
        begin
          if node=nil then
            exit;

          { ensure we've already optinfo set }
          node.allocoptinfo;

          if tnf_processing in node.transientflags then
            exit;
          include(node.transientflags,tnf_processing);

          if Assigned(node.successor) then
            CreateInfo(node.successor);

          { life:=succesorlive-definition+use }

          case node.nodetype of
            whilerepeatn:
              begin
                { analyze the loop condition }
                if not(Assigned(node.optinfo^.def)) and
                   not(Assigned(node.optinfo^.use)) then
                  begin
                    dfainfo.use:=@node.optinfo^.use;
                    dfainfo.def:=@node.optinfo^.def;
                    dfainfo.map:=map;
                    foreachnodestatic(pm_postprocess,TWhileRepeatNode(node).left,@AddDefUse,@dfainfo);
                  end;

                { NB: this node should typically have empty def set }
                if Assigned(node.successor) then
                  DynSetDiff(l,node.successor.optinfo^.life,node.optinfo^.def)
                else if Assigned(resultnode) then
                  DynSetDiff(l,resultnode.optinfo^.life,node.optinfo^.def)
                else
                  l:=nil;

                { for repeat..until, node use set in included at the end of loop }
                if not (lnf_testatbegin in TWhileRepeatNode(node).loopflags) then
                  DynSetIncludeSet(l,node.optinfo^.use);

                DynSetIncludeSet(l,node.optinfo^.life);

                save:=node.optinfo^.life;
                { to process body correctly, we need life info in place (because
                  whilerepeatnode is successor of its body). }
                node.optinfo^.life:=l;

                { now process the body }
                CreateInfo(TWhileRepeatNode(node).right);

                { restore, to prevent infinite recursion via changed flag }
                node.optinfo^.life:=save;

                { for while loops, node use set is included at the beginning of loop }
                l:=TWhileRepeatNode(node).right.optinfo^.life;
                if lnf_testatbegin in TWhileRepeatNode(node).loopflags then
                  begin
                    DynSetIncludeSet(l,node.optinfo^.use);
                    { ... loop body could be skipped, so include life info of the successor node }
                    if Assigned(node.successor) then
                      DynSetIncludeSet(l,node.successor.optinfo^.life);
                  end;

                UpdateLifeInfo(node,l);

                { ... and a second iteration for fast convergence }
                CreateInfo(TWhileRepeatNode(node).right);
              end;

            forn:
              begin
                {
                  left: loopvar
                  right: from
                  t1: to
                  t2: body
                }
                node.allocoptinfo;
                TForNode(node).loopiteration.allocoptinfo;
                if not(Assigned(node.optinfo^.def)) and
                   not(Assigned(node.optinfo^.use)) then
                  begin
                    dfainfo.use:=@node.optinfo^.use;
                    dfainfo.def:=@node.optinfo^.def;
                    dfainfo.map:=map;
                    foreachnodestatic(pm_postprocess,TForNode(node).left,@AddDefUse,@dfainfo);
                    foreachnodestatic(pm_postprocess,TForNode(node).right,@AddDefUse,@dfainfo);
                    foreachnodestatic(pm_postprocess,TForNode(node).t1,@AddDefUse,@dfainfo);
                  end;

                { create life for the body }
                CreateInfo(TForNode(node).t2);

                { is the counter living after the loop?

                  if left is a record element, it might not be tracked by dfa, so
                  optinfo might not be assigned
                }
                counteruse_after_loop:=Assigned(TForNode(node).left.optinfo) and Assigned(node.successor) and
                  DynSetIn(node.successor.optinfo^.life,TForNode(node).left.optinfo^.Index);

                if counteruse_after_loop then
                  begin
                    { if yes, then we should warn }
                    { !!!!!! }
                  end
                else
                  Include(TForNode(node).loopflags,lnf_dont_mind_loopvar_on_exit);

                { first update the dummy node }

                { get the life of the loop block }
                l:=copy(TForNode(node).t2.optinfo^.life);

                { take care of the successor }
                if Assigned(node.successor) then
                  DynSetIncludeSet(l,node.successor.optinfo^.life);

                { the counter variable is living as well inside the for loop

                  if left is a record element, it might not be tracked by dfa, so
                  optinfo might not be assigned
                }
                if Assigned(TForNode(node).left.optinfo) then
                  DynSetInclude(l,TForNode(node).left.optinfo^.Index);

                { force block node life info }
                UpdateLifeInfo(TForNode(node).loopiteration,l);

                { now update the for node itself }

                { get the life of the loop block }
                l:=copy(TForNode(node).t2.optinfo^.life);

                { take care of the successor as it's possible that we don't have one execution of the body }
                if (not(TForNode(node).right.nodetype=ordconstn) or not(TForNode(node).t1.nodetype=ordconstn)) and
                  Assigned(node.successor) then
                  DynSetIncludeSet(l,node.successor.optinfo^.life);

                {
                  the counter variable is not living at the entry of the for node

                  if left is a record element, it might not be tracked by dfa, so
                    optinfo might not be assigned
                }
                if Assigned(TForNode(node).left.optinfo) then
                  DynSetExclude(l,TForNode(node).left.optinfo^.Index);

                { ... but it could be that left/right use it, so do this after
                  removing the def of the counter variable }
                DynSetIncludeSet(l,node.optinfo^.use);

                UpdateLifeInfo(node,l);

                { ... and a second iteration for fast convergence }
                CreateInfo(TForNode(node).t2);
              end;

            temprefn,
            loadn,
            typeconvn,
            derefn,
            assignn:
              begin
                if not(Assigned(node.optinfo^.def)) and
                  not(Assigned(node.optinfo^.use)) then
                  begin
                    dfainfo.use:=@node.optinfo^.use;
                    dfainfo.def:=@node.optinfo^.def;
                    dfainfo.map:=map;
                    foreachnodestatic(pm_postprocess,node,@AddDefUse,@dfainfo);
                  end;
                calclife(node);
              end;

            statementn:
              begin
                { nested statement }
                CreateInfo(TStatementNode(node).statement);
                { propagate info }
                node.optinfo^.life:=TStatementNode(node).successor.optinfo^.life;
              end;

            blockn:
              begin
                CreateInfo(TBlockNode(node).statements);
                { ensure that we don't remove life info }
                l:=node.optinfo^.life;
                if Assigned(node.successor) then
                  DynSetIncludeSet(l,node.successor.optinfo^.life);
                UpdateLifeInfo(node,l);
              end;

            ifn:
              begin
                { get information from cond. expression }
                if not(Assigned(node.optinfo^.def)) and
                   not(Assigned(node.optinfo^.use)) then
                  begin
                    dfainfo.use:=@node.optinfo^.use;
                    dfainfo.def:=@node.optinfo^.def;
                    dfainfo.map:=map;
                    foreachnodestatic(pm_postprocess,TIfNode(node).left,@AddDefUse,@dfainfo);
                  end;

                { create life info for then and else node }
                CreateInfo(TIfNode(node).right);
                CreateInfo(TIfNode(node).t1);

                { ensure that we don't remove life info }
                l:=node.optinfo^.life;

                { get life info from then branch }
                if Assigned(TIfNode(node).right) then
                  DynSetIncludeSet(l,TIfNode(node).right.optinfo^.life)
                else if Assigned(node.successor) then
                  DynSetIncludeSet(l,node.successor.optinfo^.life);

                { get life info from else branch }
                if Assigned(TIfNode(node).t1) then
                  DynSetIncludeSet(l,TIfNode(node).t1.optinfo^.life)
                else if Assigned(node.successor) then
                  DynSetIncludeSet(l,node.successor.optinfo^.life);

                { remove def info from the cond. expression }
                DynSetExcludeSet(l,TIfNode(node).optinfo^.def);

                { add use info from the cond. expression }
                DynSetIncludeSet(l,TIfNode(node).optinfo^.use);

                { finally, update the life info of the node }
                UpdateLifeInfo(node,l);
              end;

            casen:
              begin
                { get information from "case" expression }
                if not(Assigned(node.optinfo^.def)) and
                   not(Assigned(node.optinfo^.use)) then
                  begin
                    dfainfo.use:=@node.optinfo^.use;
                    dfainfo.def:=@node.optinfo^.def;
                    dfainfo.map:=map;
                    foreachnodestatic(pm_postprocess,TCaseNode(node).left,@AddDefUse,@dfainfo);
                  end;

                { create life info for block and else nodes }
                for i:=0 to TCaseNode(node).blocks.count-1 do
                  CreateInfo(PCaseBlock(TCaseNode(node).blocks[i])^.statement);

                CreateInfo(TCaseNode(node).elseblock);

                { ensure that we don't remove life info }
                l:=node.optinfo^.life;

                { get life info from case branches }
                for i:=0 to TCaseNode(node).blocks.count-1 do
                  DynSetIncludeSet(l,PCaseBlock(TCaseNode(node).blocks[i])^.statement.optinfo^.life);

                { get life info from else branch or the successor }
                if Assigned(TCaseNode(node).elseblock) then
                  DynSetIncludeSet(l,TCaseNode(node).elseblock.optinfo^.life)
                else if Assigned(node.successor) then
                  begin
                    if Is_Ordinal(TCaseNode(node).left.resultdef) then
                      begin
                        GetRange(TCaseNode(node).left.resultdef,lv,hv);
                        if TCaseNode(node).labelcoverage<(hv-lv) then
                          DynSetIncludeSet(l,node.successor.optinfo^.life);
                      end
                    else
                      DynSetIncludeSet(l,node.successor.optinfo^.life);
                  end;

                { add use info from the "case" expression }
                DynSetIncludeSet(l,TCaseNode(node).optinfo^.use);

                { finally, update the life info of the node }
                UpdateLifeInfo(node,l);
              end;

            exitn:
              begin
                { in case of inlining, an exit node can have a successor, in this case, we do not have to
                  use the faked resultnode }
                if Assigned(node.successor) then
                  begin
                    l:=node.optinfo^.life;
                    DynSetIncludeSet(l,node.successor.optinfo^.life);
                    UpdateLifeInfo(node,l);
                  end
                else if Assigned(resultnode) and (resultnode.nodetype<>nothingn) then
                  begin
                    if not(Assigned(node.optinfo^.def)) and
                       not(Assigned(node.optinfo^.use)) then
                      begin
                        if Assigned(TExitNode(node).left) then
                          begin
{                           this should never happen as
                            texitnode.pass_typecheck converts the left node into a separate node already

                             node.optinfo^.def:=resultnode.optinfo^.def;

                            dfainfo.use:=@node.optinfo^.use;
                            dfainfo.def:=@node.optinfo^.def;
                            dfainfo.map:=map;
                            foreachnodestatic(pm_postprocess,texitnode(node).left,@AddDefUse,@dfainfo);
                            calclife(node); }
                            InternalError(2020122901);
                          end
                        else
                          begin
                            { get info from faked resultnode }
                            node.optinfo^.use:=resultnode.optinfo^.use;
                            node.optinfo^.life:=node.optinfo^.use;
                            changed:=true;
                          end;
                      end;
                  end;
              end;

            tempcreaten,
            asn,
            inlinen,
            calln:
              begin
                if not(Assigned(node.optinfo^.def)) and
                  not(Assigned(node.optinfo^.use)) then
                  begin
                    dfainfo.use:=@node.optinfo^.use;
                    dfainfo.def:=@node.optinfo^.def;
                    dfainfo.map:=map;
                    foreachnodestatic(pm_postprocess,node,@AddDefUse,@dfainfo);
                  end;
                calclife(node);
              end;

            labeln,
            tempdeleten,
            nothingn,
            continuen,
            goton,
            breakn:
              begin
                calclife(node);
              end;
            else
              InternalError(2007050502);
          end;
        end;

      var
        runs : integer;
      begin
        runs:=0;
        repeat
          inc(runs);
          changed:=false;
          CreateInfo(node);
          foreachnodestatic(pm_postprocess,node,@ResetProcessing,nil);
          { the result node is not reached by foreachnodestatic }
          exclude(resultnode.transientflags,tnf_processing);
{$ifdef DEBUG_DFA}
          PrintIndexedNodeSet(Output,map);
          PrintDFAInfo(Output,node);
{$endif DEBUG_DFA}
        until not(changed);
{$ifdef DEBUG_DFA}
        WriteLn('DFA solver iterations: ',runs);
{$endif DEBUG_DFA}
      end;


    { reset all dfa info, this is required before creating dfa info
      if the tree has been changed without updating dfa }
    procedure TDFABuilder.resetdfainfo(node : TNode);
      begin
        nodemap.Free;
        nodemap:=nil;
        resultnode.Free;
        resultnode:=nil;
        foreachnodestatic(pm_postprocess,node,@ResetDFA,nil);
      end;


    procedure TDFABuilder.createdfainfo(node : TNode);
      var
        dfarec : TDFAInfo;
      begin
        if not(Assigned(nodemap)) then
          nodemap:=TIndexedNodeSet.Create;

        { create a fake node using the result which will be the last node }
        if not(Is_Void(CurrentProcInfo.procdef.ReturnDef)) then
          begin
            if CurrentProcInfo.procdef.ProcTypeOption=potype_constructor then
              resultnode:=load_self_node
            else if (CurrentProcInfo.procdef.ProcCallOption=pocall_safecall) and
              (tf_safecall_exceptions in TargetInfo.flags) then
              resultnode:=load_safecallresult_node
            else
              resultnode:=load_result_node;
            resultnode.allocoptinfo;
            dfarec.use:=@resultnode.optinfo^.use;
            dfarec.def:=@resultnode.optinfo^.def;
            dfarec.map:=nodemap;
            AddDefUse(resultnode,@dfarec);
            resultnode.optinfo^.life:=resultnode.optinfo^.use;
          end
        else
          begin
            resultnode:=CNothingNode.create;
            resultnode.allocoptinfo;
          end;

        { add control flow information }
        SetNodeSucessors(node,resultnode);

        { now, collect life information }
        CreateLifeInfo(node,nodemap);
      end;


    procedure TDFABuilder.redodfainfo(node: TNode);
      begin
        resetdfainfo(node);
        createdfainfo(node);
        include(CurrentProcInfo.flags,pi_dfaavailable);
      end;


    destructor TDFABuilder.Destroy;
      begin
        Resultnode.free;
        Resultnode := nil;
        nodemap.free;
        nodemap := nil;
        inherited Destroy;
      end;

    type
      { helper structure to be able to pass more than one variable to the iterator function }
      TSearchNodeInfo = record
        nodetosearch : TNode;
        { this contains a list of all file locations where a warning was thrown already,
          the same location might appear multiple times because nodes might have been copied }
        warnedfilelocs : array of TFilePosInfo;
      end;

      PSearchNodeInfo = ^TSearchNodeInfo;

    { searches for a given node n and warns if the node is found as being uninitialized. If a node is
      found, searching is stopped so each call issues only one warning/hint }
    function SearchNode(var n: TNode; arg: pointer): TForEachNodeResult;

      function WarnedForLocation(f : TFilePosInfo) : boolean;
        var
          i : LongInt;
        begin
          result:=true;
          for i:=0 to high(PSearchNodeInfo(arg)^.warnedfilelocs) do
            with PSearchNodeInfo(arg)^.warnedfilelocs[i] do
              begin
                if (f.column=column) and (f.fileindex=fileindex) and (f.line=line) and (f.moduleindex=moduleindex) then
                  exit;
              end;
          result:=false;
        end;


      procedure AddFilepos(const f : TFilePosInfo);
        begin
          SetLength(PSearchNodeInfo(arg)^.warnedfilelocs,length(PSearchNodeInfo(arg)^.warnedfilelocs)+1);
          PSearchNodeInfo(arg)^.warnedfilelocs[high(PSearchNodeInfo(arg)^.warnedfilelocs)]:=f;
        end;


      { Checks if the symbol is a candidate for a warning.
        Emit warning/note for living locals, result and parameters, but only about the current
        symtables }
      function SymbolCandidateForWarningOrHint(sym : TAbstractNormalVarSym) : Boolean;
        begin
          Result:=(((sym.owner=CurrentProcInfo.procdef.LocalST) and
                    (CurrentProcInfo.procdef.LocalST.SymTableLevel=sym.owner.SymTableLevel)
                   ) or
                   ((sym.owner=CurrentProcInfo.procdef.ParaST) and
                    (sym.typ=paravarsym) and
                    (CurrentProcInfo.procdef.ParaST.SymTableLevel=sym.owner.SymTableLevel) and
                    { all parameters except out parameters are initialized by the caller }
                    (TParaVarSym(sym).VarSpez=vs_out)
                   ) or
                   ((vo_is_funcret in sym.VarOptions) and
                    (CurrentProcInfo.procdef.ParaST.SymTableLevel=sym.owner.SymTableLevel)
                   )
                  ) and
                  not(vo_is_external in sym.VarOptions) and
                  not sym.InParentFPStruct and
                  not(vo_is_internal in sym.VarOptions);
        end;

      var
        varsym : TAbstractNormalVarSym;
        methodpointer,
        hpt : TNode;
      begin
        result:=fen_false;
        case n.nodetype of
          callparan:
            begin
              { do not warn about variables passed by var, just issue a hint, this
                is a workaround for old code e.g. using fillchar }
              if Assigned(TCallParaNode(n).parasym) and (TCallParaNode(n).parasym.VarSpez in [vs_var,vs_out]) then
                begin
                  hpt:=TCallParaNode(n).left;
                  while Assigned(hpt) and (hpt.nodetype in [subscriptn,vecn,typeconvn]) do
                    hpt:=TUnaryNode(hpt).left;
                  if Assigned(hpt) and (hpt.nodetype=loadn) and not(WarnedForLocation(hpt.fileinfo)) and
                    SymbolCandidateForWarningOrHint(TAbstractNormalVarSym(TLoadNode(hpt).symtableentry)) and
                    PSearchNodeInfo(arg)^.nodetosearch.isequal(hpt) then
                    begin
                      { issue only a hint for var, when encountering the node passed as out, we need only to stop searching }
                      if TCallParaNode(n).parasym.VarSpez=vs_var then
                        UninitializedVariableMessage(hpt.fileinfo,false,
                          TLoadNode(hpt).SymTable.SymTableType=LocalSymTable,
                          Is_Managed_Type(TLoadNode(hpt).resultdef),
                          TLoadNode(hpt).symtableentry.RealName);
                      AddFilepos(hpt.fileinfo);
                      result:=fen_norecurse_true;
                    end
                end;
            end;
          orn,
          andn:
            begin
              { take care of short boolean evaluation: if the expression to be search is found in left,
                we do not need to search right }
              if foreachnodestatic(pm_postprocess,TAddNode(n).left,@optdfa.SearchNode,arg) or
                foreachnodestatic(pm_postprocess,TAddNode(n).right,@optdfa.SearchNode,arg) then
                result:=fen_norecurse_true
              else
                result:=fen_norecurse_false;
            end;
          calln:
            begin
              methodpointer:=TCallNode(n).methodpointer;
              if Assigned(methodpointer) and (methodpointer.nodetype<>typen) then
               begin
                  { Remove all postfix operators }
                  hpt:=methodpointer;
                  while Assigned(hpt) and (hpt.nodetype in [subscriptn,vecn]) do
                    hpt:=TUnaryNode(hpt).left;

                 { skip (absolute and other simple) type conversions -- only now,
                   because the checks above have to take type conversions into
                   e.g. class reference types account }
                 hpt:=actualtargetnode(@hpt)^;

                  { R.Init then R will be initialized by the constructor,
                    Also allow it for simple loads }
                  if (TCallNode(n).procdefinition.ProcTypeOption=potype_constructor) or
                     (PSearchNodeInfo(arg)^.nodetosearch.isequal(hpt) and
                      (((methodpointer.resultdef.typ=objectdef) and
                        not(oo_has_virtual in TObjectDef(methodpointer.resultdef).ObjectOptions)) or
                       (methodpointer.resultdef.typ=recorddef)
                      )
                     ) then
                    begin
                      { don't warn about the method pointer }
                      AddFilepos(hpt.fileinfo);

                      if not(foreachnodestatic(pm_postprocess,TCallNode(n).left,@optdfa.SearchNode,arg)) then
                        foreachnodestatic(pm_postprocess,TCallNode(n).right,@optdfa.SearchNode,arg);
                      result:=fen_norecurse_true
                    end;
                 end;
            end;
          loadn:
            begin
              if (TLoadNode(n).symtableentry.typ in [localvarsym,paravarsym,staticvarsym]) and
                PSearchNodeInfo(arg)^.nodetosearch.isequal(n) and ((nf_modify in n.flags) or not(nf_write in n.flags)) then
                begin
                  varsym:=TAbstractNormalVarSym(TLoadNode(n).symtableentry);

                  if Assigned(varsym.owner) and SymbolCandidateForWarningOrHint(varsym) then
                    begin
                      if (vo_is_funcret in varsym.VarOptions) and not(WarnedForLocation(n.fileinfo)) then
                        begin
                          if Is_Managed_Type(varsym.vardef) then
                            MessagePos(n.fileinfo,sym_w_managed_function_result_uninitialized)
                          else
                            MessagePos(n.fileinfo,sym_w_function_result_uninitialized);
                          AddFilepos(n.fileinfo);
                          result:=fen_norecurse_true;
                        end
                      else
                        begin
                          { typed consts are initialized, further, warn only once per location }
                          if not (vo_is_typed_const in varsym.VarOptions) and not(WarnedForLocation(n.fileinfo)) then
                            begin
                              UninitializedVariableMessage(n.fileinfo,true,varsym.typ=localvarsym,Is_Managed_Type(varsym.vardef),varsym.realname);
                              AddFilepos(n.fileinfo);
                              result:=fen_norecurse_true;
                            end;
                        end;
                    end
                end;
            end;
          else
            ;
        end;
      end;


    procedure CheckAndWarn(code : TNode;nodetosearch : TNode);

      var
        SearchNodeInfo : TSearchNodeInfo;

      function DoCheck(node : TNode) : boolean;
        var
          i : LongInt;
          touchesnode : Boolean;

        procedure MaybeDoCheck(n : TNode);inline;
          begin
            Result:=Result or DoCheck(n);
          end;

        procedure MaybeSearchIn(n : TNode);
          begin
            if touchesnode then
              Result:=Result or foreachnodestatic(pm_postprocess,n,@SearchNode,@SearchNodeInfo);
          end;

        begin
          result:=false;

          if node=nil then
            exit;

          if tnf_processing in node.transientflags then
            exit;
          include(node.transientflags,tnf_processing);

          if not(Assigned(node.optinfo)) or not(DynSetIn(node.optinfo^.life,nodetosearch.optinfo^.Index)) then
            exit;

          { we do not need this info always, so try to safe some time here, CheckAndWarn
            takes a lot of time anyways }
          if not(node.nodetype in [statementn,blockn]) then
            touchesnode:=DynSetIn(node.optinfo^.use,nodetosearch.optinfo^.Index) or
              DynSetIn(node.optinfo^.def,nodetosearch.optinfo^.Index)
          else
            touchesnode:=false;

          case node.nodetype of
            whilerepeatn:
              begin
                MaybeSearchIn(TWhileRepeatNode(node).left);
                MaybeDoCheck(TWhileRepeatNode(node).right);
              end;

            forn:
              begin
                MaybeSearchIn(TForNode(node).right);
                MaybeSearchIn(TForNode(node).t1);
                MaybeDoCheck(TForNode(node).t2);
              end;

            statementn:
              MaybeDoCheck(TStatementNode(node).statement);

            blockn:
              MaybeDoCheck(TBlockNode(node).statements);

            ifn:
              begin
                MaybeSearchIn(TIfNode(node).left);
                MaybeDoCheck(TIfNode(node).right);
                MaybeDoCheck(TIfNode(node).t1);
              end;

            casen:
              begin
                MaybeSearchIn(TCaseNode(node).left);
                for i:=0 to TCaseNode(node).blocks.count-1 do
                  MaybeDoCheck(PCaseBlock(TCaseNode(node).blocks[i])^.statement);

                MaybeDoCheck(TCaseNode(node).elseblock);
              end;

            { we are aware of the following nodes so if new node types are added to the compiler
              and pop up in the search, the ie below kicks in as a reminder }
            exitn:
              begin
                MaybeSearchIn(TExitNode(node).left);
                { exit uses the resultnode implicitly, so searching for a matching node is
                  useless, if we reach the exit node and found the living node not in left, then
                  it can be only the resultnode

                  successor might be assigned in case of an inlined exit node, in this case we do not warn about an unassigned
                  result as this had happened already when the routine has been compiled }
                if not(Assigned(node.successor)) and not(Result) and not(Is_Void(CurrentProcInfo.procdef.ReturnDef)) and
                  not(Assigned(TExitNode(node).resultexpr)) and
                  { don't warn about constructors }
                  not(CurrentProcInfo.procdef.ProcTypeOption in [potype_class_constructor,potype_constructor]) then
                  begin
                    if Is_Managed_Type(CurrentProcInfo.procdef.ReturnDef) then
                      MessagePos(node.fileinfo,sym_w_managed_function_result_uninitialized)
                    else
                      MessagePos(node.fileinfo,sym_w_function_result_uninitialized);

                    SetLength(SearchNodeInfo.warnedfilelocs,length(SearchNodeInfo.warnedfilelocs)+1);
                    SearchNodeInfo.warnedfilelocs[high(SearchNodeInfo.warnedfilelocs)]:=node.fileinfo;
                  end
              end;
            { could be the implicitly generated load node for the result }
            labeln,
            loadn,
            assignn,
            calln,
            temprefn,
            typeconvn,
            inlinen,
            tempcreaten,
            tempdeleten:
              MaybeSearchIn(node);
            nothingn,
            continuen,
            goton,
            breakn:
              ;
            else
              InternalError(2013111301);
          end;

          { if already a warning has been issued, then stop }
          if Result then
            exit;

          if Assigned(node.successor) then
            MaybeDoCheck(node.successor);
        end;

      begin
        SearchNodeInfo.nodetosearch:=nodetosearch;
        DoCheck(code);
        foreachnodestatic(pm_postprocess,code,@ResetProcessing,nil);
      end;


end.
