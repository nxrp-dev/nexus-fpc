{
    Loop optimization

    Copyright (c) 2005 by Florian Klaempfl

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
unit optloop;

{$i fpcdefs.inc}


  interface

    uses
      node;

    function unroll_loop(node : TNode) : TNode;
    function OptimizeInductionVariables(node : TNode) : boolean;
    function optimize_record_writes(var n: TNode): boolean;
    function OptimizeForLoop(var node : TNode) : boolean;

  implementation

    uses
      CClasses,CUtils,compinnr,CDynSet,
      GlobType,Globals,ConstExp,
{$ifdef i386}
      CPUInfo,
{$endif i386}
      Verbose,
      SymBase,symconst,symdef,SymSym,symtype,
      defutil,
      nutils,
      nadd,nbas,nflw,ncon,ninl,ncal,nld,nmem,ncnv,
      ncgmem,
      Pass_1,
      optbase,optutils,
      ProcInfo;

    function number_unrolls(node : TNode) : cardinal;
      var
        nodeCount : cardinal;
      begin
        { calculate how often a loop shall be unrolled.

          The term (60*ord(node_count_weighted(node)<15)) is used to get small loops  unrolled more often as
          the counter management takes more time in this case. }
{$ifdef i386}
        { multiply by 2 for CPUs with a long pipeline }
        if CurrentSettings.OptimizeCPUType in [cpu_Pentium4] then
          begin
            { See the common branch below for an explanation. }
            nodeCount:=Node_Count_Weighted(node,41);
            number_unrolls:=round((60+(60*ord(nodeCount<15)))/max(nodeCount,1))
          end
        else
{$endif i386}
          begin
            { If nodeCount >= 15, numerator will be 30,
              and the largest number (starting from 15) that makes sense as its denominator
              (the smallest number that gives number_unrolls = 1) is 21 = trunc(30/1.5+1),
              so there's no point in counting for more than 21 nodes.
              "Long pipeline" variant above is the same with numerator=60 and max denominator = 41. }
            nodeCount:=Node_Count_Weighted(node,21);
            number_unrolls:=round((30+(60*ord(nodeCount<15)))/max(nodeCount,1));
          end;

        if number_unrolls=0 then
          number_unrolls:=1;
      end;

    type
      TReplaceInfo = record
        node : TNode;
        value : TConstExprInt;
      end;
      PReplaceInfo = ^TReplaceInfo;

    function checkcontrollflowstatements(var n:TNode; arg: pointer): TForEachNodeResult;
      begin
        if n.nodetype in [breakn,continuen,goton,labeln,exitn,raisen] then
          result:=fen_norecurse_true
        else
          result:=fen_false;
      end;


    function replaceloadnodes(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        if n.IsEqual(PReplaceInfo(arg)^.node) then
          begin
            if n.flags*[nf_modify,nf_write,nf_address_taken]<>[] then
              InternalError(2012090402);
            n.free;
            n:=COrdConstNode.Create(PReplaceInfo(arg)^.Value,PReplaceInfo(arg)^.node.resultdef,false);
            DoFirstPass(n);
          end;
        result:=fen_false;
      end;


    function unroll_loop(node : TNode) : TNode;
      var
        unrolls,i : cardinal;
        counts : qword;
        unrollstatement,newforstatement : TStatementNode;
        unrollblock : TBlockNode;
        getridoffor : boolean;
        replaceinfo : TReplaceInfo;
        hascontrollflowstatements : boolean;
      begin
        result:=nil;
        if (cs_opt_size in CurrentSettings.OptimizerSwitches) then
          exit;
        if ErrorCount<>0 then
          exit;
        if not(node.nodetype in [forn]) then
          exit;
        unrolls:=number_unrolls(TForNode(node).t2);
        if (unrolls>1) and
          ((TForNode(node).left.nodetype<>loadn) or
           { the address of the counter variable might be taken if it is passed by constref to a
             subroutine, so really check if it is not taken }
           ((TForNode(node).left.nodetype=loadn) and (TLoadNode(TForNode(node).left).SymTableEntry is TAbstractVarSym) and
            not(TAbstractVarSym(TLoadNode(TForNode(node).left).SymTableEntry).AddrTaken) and
            not(TAbstractVarSym(TLoadNode(TForNode(node).left).SymTableEntry).DifferentScope))
           ) then
          begin
            { number of executions known? }
            if (TForNode(node).right.nodetype=ordconstn) and (TForNode(node).t1.nodetype=ordconstn) then
              begin
                if lnf_backward in TForNode(node).LoopFlags then
                  counts:=TOrdConstNode(TForNode(node).right).Value-TOrdConstNode(TForNode(node).t1).Value+1
                else
                  counts:=TOrdConstNode(TForNode(node).t1).Value-TOrdConstNode(TForNode(node).right).Value+1;

                hascontrollflowstatements:=ForEachNodeStatic(TForNode(node).t2,@checkcontrollflowstatements,nil);

                { don't unroll more than we need,

                  multiply unroll by two here because we can get rid
                  of the counter variable completely and replace it by a constant
                  if unrolls=counts }
                if unrolls*2>=counts then
                  unrolls:=counts;

                { create block statement }
                unrollblock:=InternalStatements(unrollstatement);

                { can we get rid completly of the for ? }
                getridoffor:=(unrolls=counts) and not(hascontrollflowstatements) and
                  { Macpas allows assignments to the for-variables, so we cannot get rid of the for }
                  not(m_mac in CurrentSettings.ModeSwitches);

                if getridoffor then
                  begin
                    replaceinfo.node:=TForNode(node).left;
                    replaceinfo.Value:=TOrdConstNode(TForNode(node).right).Value;
                  end
                else
                  { we consider currently unrolling not beneficial, if we cannot get rid of the for completely, this
                    might change if a more sophisticated heuristics is used (FK) }
                  exit;

                { let's unroll (and rock of course) }
                for i:=1 to unrolls do
                  begin
                    { create and insert copy of the statement block }
                    AddStatement(unrollstatement,TForNode(node).t2.GetCopy);

                    { set and insert entry label? }
                    if (counts mod unrolls<>0) and
                      ((counts mod unrolls)=unrolls-i) then
                      begin
                        TForNode(node).EntryLabel:=CLabelNode.Create(CNothingNode.Create,CLabelSym.Create('$optunrol'));
                        AddStatement(unrollstatement,TForNode(node).EntryLabel);
                      end;

                    if getridoffor then
                      begin
                        ForEachNodeStatic(TNode(unrollstatement),@replaceloadnodes,@replaceinfo);
                        if lnf_backward in TForNode(node).LoopFlags then
                          replaceinfo.Value:=replaceinfo.Value-1
                        else
                          replaceinfo.Value:=replaceinfo.Value+1;
                      end
                    else
                      begin
                        { for itself increases at the last iteration }
                        if i<unrolls then
                          begin
                            { insert incr/decrementation of counter var }
                            if lnf_backward in TForNode(node).LoopFlags then
                              AddStatement(unrollstatement,
                                GenInlineNode(in_dec_x,false,CCallParaNode.Create(TForNode(node).left.GetCopy,nil)))
                            else
                              AddStatement(unrollstatement,
                                GenInlineNode(in_inc_x,false,CCallParaNode.Create(TForNode(node).left.GetCopy,nil)));
                          end;
                       end;
                  end;
                { can we get rid of the for statement? }
                if getridoffor then
                  begin
                    { create block statement }
                    result:=InternalStatements(newforstatement);
                    AddStatement(newforstatement,unrollblock);
                    DoInlineSimplify(result);
                  end;
              end
            else
              begin
                { unrolling is a little bit more tricky if we don't know the
                  loop count at compile time, but the solution is to use a jump table
                  which is indexed by "loop count mod unrolls" at run time and which
                  jumps then at the appropriate place inside the loop. Because
                  a module division is expensive, we can use only unroll counts dividable
                  by 2 }
                case unrolls of
                  1..2:
                    ;
                  3:
                    unrolls:=2;
                  4..7:
                    unrolls:=4;
                  { unrolls>4 already make no sense imo, but who knows (FK) }
                  8..15:
                    unrolls:=8;
                  16..31:
                    unrolls:=16;
                  32..63:
                    unrolls:=32;
                  64..$7fff:
                    unrolls:=64;
                  else
                    exit;
                end;
                { we don't handle this yet }
                exit;
              end;
            if not(Assigned(result)) then
              begin
                TForNode(node).t2.free;
                TForNode(node).t2:=unrollblock;
              end;
          end;
      end;


    function checkcontinue(var n:TNode; arg: pointer): TForEachNodeResult;
      begin
        if n.nodetype=continuen then
          result:=fen_norecurse_true
        else
          result:=fen_false;
      end;


    function is_loop_invariant(loop : TNode;Expr : TNode) : boolean;
      begin
        result:=Is_ConstNode(Expr);
        case Expr.nodetype of
          loadn:
            begin
              if (pi_dfaavailable in CurrentProcInfo.flags) and
                Assigned(loop.optinfo) and
                Assigned(Expr.optinfo) and
                not(Expr.IsEqual(TForNode(loop).left)) then
                { no aliasing? }
                result:=(([nf_write,nf_modify]*Expr.flags)=[]) and not(TAbstractVarSym(TLoadNode(Expr).SymTableEntry).AddrTaken) and
                { no definition in the loop? }
                  not(DynSetIn(TForNode(loop).t2.optinfo^.defsum,Expr.optinfo^.Index));
            end;
          vecn:
            begin
              result:=((TVecNode(Expr).left.nodetype=loadn) or is_loop_invariant(loop,TVecNode(Expr).left)) and
                is_loop_invariant(loop,TVecNode(Expr).right);
            end;
          typeconvn:
            result:=is_loop_invariant(loop,TTypeConvNode(Expr).left);
          addn,subn:
            result:=is_loop_invariant(loop,TAddNode(Expr).left) and is_loop_invariant(loop,TAddNode(Expr).right);
          else
            ;
        end;
      end;


    type
      TOptimizeInductionVariablesContext = object
        currforloop : TForNode;
        initcode,
        calccode,
        deletecode : TBlockNode;
        initcodestatements,
        calccodestatements,
        deletecodestatements: TStatementNode;
        ninductions : sizeint;
        inductions : array of record
          temp : TTempCreateNode;
          Expr : TNode;
        end;
        changedforloop,
        containsnestedforloop,
        docalcatend : boolean;
        function findpreviousstrengthreduction(var n: TNode): boolean;
        procedure addinduction(temp : TTempCreateNode; Expr : TNode);
        function dostrengthreductiontest(var n: TNode): TForEachNodeResult;
        procedure optimizeinductionvariablessingleforloop(var n: TNode);
      end;


    function TOptimizeInductionVariablesContext.findpreviousstrengthreduction(var n: TNode): boolean;
      var
        i : LongInt;
        hp : TNode;
      begin
        result:=false;
        for i:=0 to ninductions-1 do
          begin
            { do we already maintain one expression? }
            if inductions[i].Expr.IsEqual(n) then
              begin
                case n.nodetype of
                  muln:
                    hp:=CTempRefNode.Create(inductions[i].temp);
                  vecn:
                    hp:=CTypeConvNode.Create_Internal(CDerefNode.Create(CTempRefNode.Create(inductions[i].temp)),n.resultdef);
                  else
                    InternalError(200809211);
                end;
                n.free;
                n:=hp;
                exit(true);
              end;
          end;
      end;


    procedure TOptimizeInductionVariablesContext.addinduction(temp : TTempCreateNode; Expr : TNode);
      begin
        if not Assigned(initcode) then
          begin
            initcode:=InternalStatements(initcodestatements);
            calccode:=InternalStatements(calccodestatements);
            deletecode:=InternalStatements(deletecodestatements);
            docalcatend:=not(Assigned(currforloop.EntryLabel)) and
              not(ForEachNodeStatic(currforloop.t2,@checkcontinue,nil));
          end;
        if ninductions>=length(inductions) then
          SetLength(inductions,4+ninductions+ninductions shr 1);
        inductions[ninductions].temp:=temp;
        inductions[ninductions].Expr:=Expr;
        inc(ninductions);
      end;


    { checks if the strength of n can be reduced, currforloop is the tforloop being considered }
    function TOptimizeInductionVariablesContext.dostrengthreductiontest(var n: TNode): TForEachNodeResult;
      var
        tempnode,startvaltemp : TTempCreateNode;
        dummy : LongInt;
        nn : TNode;
        nt : TNodeType;
        nflags : TNodeFlags;
      begin
        result:=fen_false;
        nflags:=n.flags;
        case n.nodetype of
          forn:
            { inform for loop search routine, that it needs to search more deeply }
            containsnestedforloop:=true;
          muln:
            begin
              if (TAddNode(n).right.nodetype=loadn) and
                TAddNode(n).right.IsEqual(currforloop.left) and
                { plain read of the loop variable? }
                not(nf_write in TAddNode(n).right.flags) and
                not(nf_modify in TAddNode(n).right.flags) and
                is_loop_invariant(currforloop,TAddNode(n).left) then
                TAddNode(n).SwapLeftRight;

              if (TAddNode(n).left.nodetype=loadn) and
                TAddNode(n).left.IsEqual(currforloop.left) and
                { plain read of the loop variable? }
                not(nf_write in TAddNode(n).left.flags) and
                not(nf_modify in TAddNode(n).left.flags) and
                is_loop_invariant(currforloop,TAddNode(n).right) then
                begin
                  changedforloop:=true;
                  { did we use the same expression before already? }
                  if not(findpreviousstrengthreduction(n)) then
                    begin
                      tempnode:=CTempCreateNode.Create(n.resultdef,n.resultdef.Size,tt_persistent,
                        TStoredDef(n.resultdef).Is_IntRegable or TStoredDef(n.resultdef).Is_FPURegable);
                      addinduction(tempnode,n);

                      if lnf_backward in currforloop.LoopFlags then
                        AddStatement(calccodestatements,
                          GenInlineNode(in_dec_x,false,
                          CCallParaNode.Create(CTempRefNode.Create(tempnode),CCallParaNode.Create(TAddNode(n).right.GetCopy,nil))))
                      else
                        AddStatement(calccodestatements,
                          GenInlineNode(in_inc_x,false,
                          CCallParaNode.Create(CTempRefNode.Create(tempnode),CCallParaNode.Create(TAddNode(n).right.GetCopy,nil))));

                      AddStatement(initcodestatements,tempnode);
                      nn:=currforloop.right.GetCopy;
                      { If the calculation is not performed at the end
                        it is needed to adjust the starting value }
                      if not docalcatend then
                        begin
                          if lnf_backward in currforloop.LoopFlags then
                            nt:=addn
                          else
                            nt:=subn;
                          nn:=CAddNode.Create_Internal(nt,nn,
                             COrdConstNode.Create(1,nn.resultdef,false));
                        end;
                      AddStatement(initcodestatements,CAssignmentNode.Create(CTempRefNode.Create(tempnode),
                          CAddNode.Create(muln,nn,
                            TAddNode(n).right.GetCopy)
                          )
                        );

                      { finally replace the node by a temp. ref }
                      n:=CTempRefNode.Create(tempnode);

                      { ... and add a temp. release node }
                      AddStatement(deletecodestatements,CTempDeleteNode.Create(tempnode));
                    end;
                  { set types }
                  DoFirstPass(n);
                  result:=fen_norecurse_false;
                end;
            end;
          vecn:
            begin
              { is the index the counter variable? }
              if not(Is_Special_Array(TVecNode(n).left.resultdef)) and
                not(Is_Packed_Array(TVecNode(n).left.resultdef)) and
                (TVecNode(n).right.IsEqual(currforloop.left) or
                 { fpc usually creates a type cast to access an array }
                 ((TVecNode(n).right.nodetype=typeconvn) and
                  TTypeConvNode(TVecNode(n).right).left.IsEqual(currforloop.left)
                 )
                ) and
                { plain read of the loop variable? }
                not(nf_write in TVecNode(n).right.flags) and
                not(nf_modify in TVecNode(n).right.flags) and
                { direct array access? }
                ((TVecNode(n).left.nodetype=loadn) or
                { ... or loop invariant expression? }
                is_loop_invariant(currforloop,TVecNode(n).right))

                { removing the multiplication is only worth the
                  effort if it's not a simple shift }
                and not(IsPowerOf2(TCGVecNode(n).Get_Mul_Size,dummy))

                then
                begin
                  changedforloop:=true;
                  { did we use the same expression before already? }
                  if not(findpreviousstrengthreduction(n)) then
                    begin
                      tempnode:=CTempCreateNode.Create(VoidPointerType,VoidPointerType.Size,tt_persistent,true);
                      addinduction(tempnode,n);

                      if lnf_backward in currforloop.LoopFlags then
                        AddStatement(calccodestatements,
                          CInlineNode.CreateIntern(in_dec_x,false,
                          CCallParaNode.Create(CTempRefNode.Create(tempnode),CCallParaNode.Create(
                          COrdConstNode.Create(TCGVecNode(n).Get_Mul_Size,SizeUIntType,false),nil))))
                      else
                        AddStatement(calccodestatements,
                          CInlineNode.CreateIntern(in_inc_x,false,
                          CCallParaNode.Create(CTempRefNode.Create(tempnode),CCallParaNode.Create(
                          COrdConstNode.Create(TCGVecNode(n).Get_Mul_Size,SizeUIntType,false),nil))));

                      AddStatement(initcodestatements,tempnode);

                      startvaltemp:=MaybeReplaceWithTemp(currforloop.right,initcode,initcodestatements,currforloop.right.resultdef.Size,true);
                      nn:=CAddrNode.Create(
                          CVecNode.Create(TVecNode(n).left.GetCopy,CTypeConvNode.Create_Internal(currforloop.right.GetCopy,TVecNode(n).right.resultdef))
                        );
                      { If the calculation is not performed at the end
                        it is needed to adjust the starting value }
                      if not docalcatend then
                        begin
                          if lnf_backward in currforloop.LoopFlags then
                            nt:=addn
                          else
                            nt:=subn;
                          nn:=CAddNode.Create_Internal(nt,
                             CTypeConvNode.Create_Internal(nn,VoidPointerType),
                             COrdConstNode.Create(TCGVecNode(n).Get_Mul_Size,SizeUIntType,false));
                        end;
                      AddStatement(initcodestatements,CAssignmentNode.Create(CTempRefNode.Create(tempnode),nn));

                      { finally replace the node by a temp. ref }
                      n:=CTypeConvNode.Create_Internal(CDerefNode.Create(CTempRefNode.Create(tempnode)),n.resultdef);

                      { ... and add a temp. release node }
                      if startvaltemp<>nil then
                        AddStatement(deletecodestatements,CTempDeleteNode.Create(startvaltemp));
                      AddStatement(deletecodestatements,CTempDeleteNode.Create(tempnode));
                    end;
                  { Copy the nf_write,nf_modify flags to the new deref node of the temp.
                    Otherwise assignments to vector elements will be removed. }
                  if nflags*[nf_write,nf_modify]<>[] then
                    begin
                      if (n.nodetype<>typeconvn) or (TTypeConvNode(n).left.nodetype<>derefn) then
                        InternalError(2021091501);
                      TTypeConvNode(n).left.flags:=TTypeConvNode(n).left.flags+nflags*[nf_write,nf_modify];
                    end;
                  { set types }
                  DoFirstPass(n);
                  result:=fen_norecurse_false;
                end;
            end;
          else
            ;
        end;
      end;


    function dostrengthreductiontest_callback(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        result:=TOptimizeInductionVariablesContext(arg^).dostrengthreductiontest(n);
      end;


    procedure TOptimizeInductionVariablesContext.optimizeinductionvariablessingleforloop(var n: TNode);
      var
        loopcode : TBlockNode;
        loopcodestatements,
        newcodestatements : TStatementNode;
        newfor,oldn : TNode;
      begin
        { do we have DFA available? }
        if pi_dfaavailable in CurrentProcInfo.flags then
          begin
            CalcDefSum(TForNode(n).t2);
          end;
        currforloop:=TForNode(n);
        initcode:=nil;
        calccode:=nil;
        deletecode:=nil;
        initcodestatements:=nil;
        calccodestatements:=nil;
        deletecodestatements:=nil;
        ninductions:=0;
        docalcatend:=false;
        { find all expressions being candidates for strength reduction
          and replace them }
        ForEachNodeStatic(pm_postprocess,n,@dostrengthreductiontest_callback,@self);

        { clue everything together }
        if Assigned(initcode) then
          begin
            DoFirstPass(TNode(initcode));
            DoFirstPass(TNode(calccode));
            DoFirstPass(TNode(deletecode));
            { create a new for node, the old one will be released by the compiler }
            oldn:=n;
            newfor:=CForNode.Create(TForNode(oldn).left,TForNode(oldn).right,TForNode(oldn).t1,TForNode(oldn).t2,lnf_backward in TForNode(oldn).LoopFlags);
            TForNode(oldn).left:=nil;
            TForNode(oldn).right:=nil;
            TForNode(oldn).t1:=nil;
            TForNode(oldn).t2:=nil;

            loopcode:=InternalStatements(loopcodestatements);
            if not docalcatend then
              AddStatement(loopcodestatements,calccode);
            AddStatement(loopcodestatements,TForNode(newfor).t2);
            if docalcatend then
              AddStatement(loopcodestatements,calccode);
            TForNode(newfor).t2:=loopcode;
            DoFirstPass(newfor);

            n:=InternalStatements(newcodestatements);
            oldn.Free;
            oldn := nil;
            AddStatement(newcodestatements,initcode);
            AddStatement(newcodestatements,newfor);
            AddStatement(newcodestatements,deletecode);
          end;
      end;


    function optimizeinductionvariablessingleforloop_static(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        ctx : ^TOptimizeInductionVariablesContext absolute arg;
      begin
        Result:=fen_false;
        if n.nodetype<>forn then
          exit;
        ctx^.containsnestedforloop:=false;
        ctx^.optimizeinductionvariablessingleforloop(n);
        { can we avoid further searching? }
        if not(ctx^.containsnestedforloop) then
          Result:=fen_norecurse_false;
      end;


    function OptimizeInductionVariables(node : TNode) : boolean;
      var
        ctx : TOptimizeInductionVariablesContext;
      begin
        Result:=false;
        if not(pi_dfaavailable in CurrentProcInfo.flags) then
          exit;
        ctx.changedforloop:=false;
        ForEachNodeStatic(pm_postprocess,node,@optimizeinductionvariablessingleforloop_static,@ctx);
        Result:=ctx.changedforloop;
      end;


    function recorddirectaccess(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        result:=fen_false;
        case n.nodetype of
          subscriptn:
            if (TSubscriptNode(n).left.nodetype=loadn) and
              (TLoadNode(TSubscriptNode(n).left).SymTableEntry=TSymEntry(arg)) then
              { It's fine if the record is loaded to access a single field }
              result:=fen_norecurse_false;
          loadn:
            if (TLoadNode(n).SymTableEntry=TSymEntry(arg)) then
              result:=fen_norecurse_true;
          else
            ;
        end;
      end;


    type
      TFieldTempPair = class(TLinkedListItem)
        BaseSymbol: TAbstractVarSym;
        Field: TFieldVarSym;
        TempCreate: TTempCreateNode;
        InitialRead: Boolean;
        FieldRead: Boolean;
        FieldWritten: Boolean;
        Score: LongInt;
        FirstDepth: Integer;
      end;

      PRecordData = ^TRecordData;
      TRecordData = record
        BaseSymbol: TAbstractVarSym;
        Fields: TLinkedList;
        Depth: Integer;
      end;

    function recordloopfindrefs(var n: TNode; arg: pointer): TForEachNodeResult; forward;

    { Needed as we can't reference recordloopfindrefs directly within itself }
    function recordloopfindrefs_recursive(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        result:=recordloopfindrefs(n, arg);
      end;

    function recordloopfindrefs(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        ThisTemp: TFieldTempPair;
      begin
        case n.nodetype of
          subscriptn:
            if (TSubscriptNode(n).left.nodetype=loadn) and
              (TLoadNode(TSubscriptNode(n).left).SymTableEntry=PRecordData(arg)^.BaseSymbol) and
              { Needs to be a basic type }
              not Is_String(TSubscriptNode(n).FieldSym.vardef) and
              not Is_Object(TSubscriptNode(n).FieldSym.vardef) and
              not Is_Managed_Type(TSubscriptNode(n).FieldSym.vardef) and
              (
                (
                  TStoredDef(TSubscriptNode(n).FieldSym.vardef).Is_IntRegable and
                  (TSubscriptNode(n).FieldSym.vardef.Size<=sizeof(aint))
                ) or
                TStoredDef(TSubscriptNode(n).FieldSym.vardef).Is_FPURegable or
                (
                  Is_Vector(TStoredDef(TSubscriptNode(n).FieldSym.vardef)) and
                  Fits_In_MM_Register(TStoredDef(TSubscriptNode(n).FieldSym.vardef))
                )
              ) then
              begin
                { See if we've defined this field already }
                ThisTemp:=TFieldTempPair(PRecordData(arg)^.Fields.First);
                while Assigned(ThisTemp) do
                  begin
                    if (ThisTemp.BaseSymbol=PRecordData(arg)^.BaseSymbol) and
                      (ThisTemp.Field=TSubscriptNode(n).FieldSym) then
                      Break;
                    ThisTemp:=TFieldTempPair(ThisTemp.Next);
                  end;

                if not Assigned(ThisTemp) then
                  begin
                    ThisTemp:=TFieldTempPair.Create;
                    ThisTemp.BaseSymbol:=PRecordData(arg)^.BaseSymbol;
                    ThisTemp.Field:=TSubscriptNode(n).FieldSym;
                    ThisTemp.TempCreate:=CTempCreateNode.Create(TSubscriptNode(n).FieldSym.vardef,TSubscriptNode(n).FieldSym.vardef.Size,tt_persistent,True);
                    ThisTemp.InitialRead:=(nf_modify in TLoadNode(TSubscriptNode(n).left).flags) or not (nf_write in TLoadNode(TSubscriptNode(n).left).flags);
                    ThisTemp.FieldWritten:=False;
                    ThisTemp.Score:=0;
                    ThisTemp.FirstDepth:=PRecordData(arg)^.Depth;
                    if not Assigned(PRecordData(arg)^.Fields.Last) then
                      PRecordData(arg)^.Fields.Insert(ThisTemp)
                    else
                      PRecordData(arg)^.Fields.InsertAfter(ThisTemp,PRecordData(arg)^.Fields.Last);
                  end;

                { A write is worth 1.5 times as much as a read under the scoring system }
                if TLoadNode(TSubscriptNode(n).left).flags*[nf_write,nf_modify]<>[] then
                  begin
                    ThisTemp.FieldWritten:=True;
                    Inc(ThisTemp.Score,3);
                    if nf_modify in TLoadNode(TSubscriptNode(n).left).flags then
                      begin
                        ThisTemp.FieldRead:=True;
                        Inc(ThisTemp.Score,2);
                      end;
                  end
                else
                  begin
                    ThisTemp.FieldRead:=True;
                    Inc(ThisTemp.Score,2);
                  end;

                result:=fen_true;
                Exit;
              end;
          else
            if n.InheritsFrom(TLoopNode) then
              begin
                if ForEachNodeStatic(pm_postprocess, TLoopNode(n).left, @recordloopfindrefs_recursive, arg) then
                  result:=fen_true;

                { Writes inside loops may not get executed, so we need to read an initial value to be safe,
                  hence the incrementation of Depth prior to analysing the right and t1 nodes }
                Inc(PRecordData(arg)^.Depth);
                if ForEachNodeStatic(pm_postprocess, TLoopNode(n).right, @recordloopfindrefs_recursive, arg) then
                  result:=fen_true;
                if ForEachNodeStatic(pm_postprocess, TLoopNode(n).t1, @recordloopfindrefs_recursive, arg) then
                  result:=fen_true;

                Dec(PRecordData(arg)^.Depth);
              end;
        end;
        result:=fen_false;
      end;


    function recordloopreplacerefs(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        ThisTemp: TFieldTempPair;
        NewNode: TNode;
      begin
        case n.nodetype of
          subscriptn:
            if (TSubscriptNode(n).left.nodetype=loadn) and
              (TLoadNode(TSubscriptNode(n).left).SymTableEntry.typ in [localvarsym, paravarsym]) then
              begin
                { See if this field has been defined }
                ThisTemp:=TFieldTempPair(PRecordData(arg)^.Fields.First);
                while Assigned(ThisTemp) do
                  begin
                    if (ThisTemp.BaseSymbol=TLoadNode(TSubscriptNode(n).left).SymTableEntry) and
                      (ThisTemp.Field=TSubscriptNode(n).FieldSym) then
                      Break;
                    ThisTemp:=TFieldTempPair(ThisTemp.Next);
                  end;

                if not Assigned(ThisTemp) then
                  begin
                    { The field should not be replaced }
                    result:=fen_norecurse_false;
                    Exit;
                  end;

                { Now actually replace the node }
                NewNode:=CTempRefNode.Create(ThisTemp.TempCreate);
                NewNode.fileinfo:=n.fileinfo;
                NewNode.flags:=NewNode.flags+(TLoadNode(TSubscriptNode(n).left).flags*[nf_write,nf_modify]);
                n.Free;
                n:=NewNode;
                n.Pass_TypeCheck;
                result:=fen_true;
                Exit;
              end;
          else
            ;
        end;
        result:=fen_false;
      end;


    { Estimate a per-platform register limit to prevent too much register pressure. }
    const
{$if defined(i386)}
      RECORD_TEMP_LIMIT = 3;
{$elseif defined(aarch64)}
      RECORD_TEMP_LIMIT = 15;
{$else}
      RECORD_TEMP_LIMIT = 7;
{$endif}

    function discount_temprefs(var n:TNode; arg: pointer): TForEachNodeResult;
      begin
        if n.nodetype=temprefn then
          begin
            Dec(PInteger(arg)^);
            result:=fen_norecurse_true;
          end
        else
          result:=fen_false;
      end;


    function _optimize_record_writes(var n:TNode; arg: pointer): TForEachNodeResult;
      var
        X, Y, SymCount: Integer;
        MinScore: LongInt;
        CurrentSym: TSym;
        RecordData: TRecordData;
        AbortRecord: Boolean;
        NewBlock: TBlockNode;
        NewWrapper: TStatementNode;
        ThisTemp, NextTemp: TFieldTempPair;
        NewCopy, NewNode: TNode;
        record_limit: Integer;
      begin
        result:=fen_false;
        record_limit:=RECORD_TEMP_LIMIT;

        { Record promotion }
        if (n.nodetype=whilerepeatn) and
          not (nf_internal in n.flags) then
          begin
            if ForEachNodeStatic(pm_postprocess,n,@discount_temprefs,@record_limit) and
              (record_limit<=0) then
              { Likely no free registers }
              Exit;

            RecordData.Fields:=nil;
            { Check to see if local record-types can have individual fields
              promoted to registers }
            if CurrentProcInfo.procdef.LocalST.SymTableType = LocalSymTable then
              begin
                RecordData.Fields:=TLinkedList.Create;
                SymCount:=CurrentProcInfo.procdef.LocalST.SymList.Count-1;
                for X:=0 to SymCount do
                  begin
                    CurrentSym:=TSym(CurrentProcInfo.procdef.LocalST.SymList[X]);
                    if (CurrentSym.typ=localvarsym) and
                      { Don't optimise records whose address has been taken,
                        since there may be some multithreaded access going on }
                      (TAbstractVarSym(CurrentSym).VarSymAccess*[vsa_addr_taken,vsa_different_scope]=[]) then
                      begin

                        if Is_Record(TAbstractVarSym(CurrentSym).vardef) then
                          begin
                            { TODO: Support unions in a limited fashion later }
                            if TRecordDef(TAbstractVarSym(CurrentSym).vardef).IsUnion then
                              Continue;

                            { Ignore records with only a single field, but
                              note they may be regable }
                            if (TRecordDef(TAbstractVarSym(CurrentSym).vardef).SymTable.SymList.Count <= 1) then
                              begin
                                Dec(record_limit);
                                Continue;
                              end;

                            AbortRecord:=False;
                            { Make sure an absolute variable doesn't alias to it }
                            for Y:=0 to SymCount do
                              if (X<>Y) and
                                (TSym(CurrentProcInfo.procdef.LocalST.SymList[X]).typ=absolutevarsym) and
                                (TAbsoluteVarSym(CurrentProcInfo.procdef.LocalST.SymList[X]).AbsTyp=tovar) and
                                (TAbsoluteVarSym(CurrentProcInfo.procdef.LocalST.SymList[X]).Ref.FirstSym^.SLType=sl_load) and
                                (TAbsoluteVarSym(CurrentProcInfo.procdef.LocalST.SymList[X]).Ref.FirstSym^.sym=CurrentSym) then
                                begin
                                  { Don't take any chances }
                                  AbortRecord:=True;
                                  Break;
                                end;

                            if AbortRecord then
                              Continue;

                            { Check to see that the symbol isn't directly accessed as one }
                            if ForEachNodeStatic(pm_postprocess, n, @recorddirectaccess, CurrentSym) then
                              Continue;

                            RecordData.BaseSymbol:=TAbstractVarSym(CurrentSym);
                            RecordData.Depth:=0;

                            ForEachNodeStatic(pm_postprocess, n, @recordloopfindrefs, @RecordData);
                          end
                        else if
                          (
                            TStoredDef(TAbstractVarSym(CurrentSym).vardef).Is_IntRegable and
                            (TAbstractVarSym(CurrentSym).vardef.Size<=sizeof(aint))
                          ) or
                          TStoredDef(TAbstractVarSym(CurrentSym).vardef).Is_FPURegable or
                          (
                            Is_Vector(TStoredDef(TAbstractVarSym(CurrentSym).vardef)) and
                            Fits_In_MM_Register(TStoredDef(TAbstractVarSym(CurrentSym).vardef))
                          ) then
                          begin
                            if ForEachNodeStatic(pm_postprocess, n, @recorddirectaccess, CurrentSym) then
                              { This simple type is likely to become a register, so reduce the limit }
                              Dec(record_limit);
                          end;
                      end;
                  end;

                if (RecordData.Fields.Count > 0) and
                  { If record_limit has gone negative, it may be that there are
                    too many potential regable variables that aren't records,
                    and in extreme cases the count may still be negative even
                    if all of the non-record variables are discounted }
                  (RecordData.Fields.Count + record_limit > 0) then
                  begin
                    { If we have too many record fields to potentially optimise,
                      start excluding ones that give a low return }
                    while (RecordData.Fields.Count > record_limit) do
                      begin
                        MinScore:=$7FFFFFFF;
                        NextTemp:=nil;

                        ThisTemp:=TFieldTempPair(RecordData.Fields.First);
                        while Assigned(ThisTemp) do
                          begin
                            if (ThisTemp.Score<MinScore) then
                              begin
                                NextTemp:=ThisTemp;
                                MinScore:=ThisTemp.Score;
                              end;

                            ThisTemp:=TFieldTempPair(ThisTemp.Next);
                          end;

                        if not Assigned(NextTemp) then
                          { No more temps }
                          Break;

                        TFieldTempPair(NextTemp).TempCreate.Free;
                        RecordData.Fields.Remove(NextTemp);
                      end;

                    { Now that inefficient ones have been removed, replace the subscript nodes }
                    if (RecordData.Fields.Count > 0) and
                      ForEachNodeStatic(pm_postprocess, n, @recordloopreplacerefs, @RecordData) then
                      begin
                        { Since the loop has had temprefs inserted, put
                          the relevant tempcreates and tempdeletes before
                          and after it. }
                        NewBlock:=InternalStatements(NewWrapper);
                        ThisTemp:=TFieldTempPair(RecordData.Fields.First);
                        while Assigned(ThisTemp) do
                          begin
                            ThisTemp.TempCreate.fileinfo:=n.fileinfo;
                            AddStatement(NewWrapper, ThisTemp.TempCreate);
                            if ThisTemp.InitialRead or (ThisTemp.FirstDepth<>0) then
                              begin
                                NewNode:=CAssignmentNode.Create_Internal( { Suppress uninitialized value warning }
                                  CTempRefNode.Create(
                                    ThisTemp.TempCreate
                                  ),
                                  CSubscriptNode.Create(
                                    ThisTemp.Field,
                                    CLoadNode.Create(ThisTemp.BaseSymbol,CurrentProcInfo.procdef.LocalST)
                                  )
                                );
                                NewNode.fileinfo:=n.fileinfo;
                                AddStatement(NewWrapper,NewNode);
                              end;
                            ThisTemp:=TFieldTempPair(ThisTemp.Next);
                          end;

                        { If NewCopy is assigned, then it contains a block
                          created during a previous iteration of this
                          function's for-loop, which includes the original
                          loop node, so insert that instead }
                        NewCopy:=n.GetCopy();
                        Node_Reset_Flags(NewCopy,[],[tnf_pass1_done]);
                        Include(NewCopy.flags, nf_internal); { Prevents this simplification pass from happening again }
                        AddStatement(NewWrapper, NewCopy);

                        ThisTemp:=TFieldTempPair(RecordData.Fields.Last);
                        while Assigned(ThisTemp) do
                          begin
                            if ThisTemp.FieldWritten then
                              begin
                                { Write the value back to the record }

                                NewNode:=CAssignmentNode.Create(
                                  CSubscriptNode.Create(
                                    ThisTemp.Field,
                                    CLoadNode.Create(ThisTemp.BaseSymbol,CurrentProcInfo.procdef.LocalST)
                                  ),
                                  CTempRefNode.Create(
                                    ThisTemp.TempCreate
                                  )
                                );
                                NewNode.Pass_TypeCheck;
                                NewNode.fileinfo:=n.fileinfo;
                                AddStatement(NewWrapper, NewNode);
                              end
                            else
                              { Might produce a more efficient temp }
                              ThisTemp.TempCreate.TempFlags:=ThisTemp.TempCreate.TempFlags+[ti_const];

                            NewNode:=CTempDeleteNode.Create(ThisTemp.TempCreate);
                            NewNode.fileinfo:=n.fileinfo;
                            AddStatement(NewWrapper, NewNode);
                            ThisTemp:=TFieldTempPair(ThisTemp.Previous);
                          end;

                        n.Free;
                        n:=NewBlock;
                        n.Pass_TypeCheck;
                        Result:=fen_true;

                        { Keep track of the old block in case more than one
                          local record appears in the loop }
                      end;
                  end;
              end;

            RecordData.Fields.Free;
          end;
      end;

    function optimize_record_writes(var n: TNode): boolean;
      begin
        Result:=ForEachNodeStatic(pm_preprocess,n,@_optimize_record_writes,nil);
      end;


    type
      TOptimizeForLoopContext = object
        changedforloop : boolean;
      end;

    function OptimizeForLoop_iterforloops(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        Result:=fen_false;
        if (n.nodetype=forn) and
          not(lnf_backward in TForNode(n).LoopFlags) and
          (lnf_dont_mind_loopvar_on_exit in TForNode(n).LoopFlags) and
          Is_ConstIntNode(TForNode(n).right) and
          (([cs_check_overflow,cs_check_range]*n.LocalSwitches)=[]) and
          (([cs_check_overflow,cs_check_range]*TForNode(n).left.LocalSwitches)=[]) and
          ((TForNode(n).left.nodetype=loadn) and (TLoadNode(TForNode(n).left).SymTableEntry is TAbstractVarSym) and
            not(TAbstractVarSym(TLoadNode(TForNode(n).left).SymTableEntry).AddrTaken) and
            not(TAbstractVarSym(TLoadNode(TForNode(n).left).SymTableEntry).DifferentScope)) then
          begin
            { do we have DFA available? }
            if pi_dfaavailable in CurrentProcInfo.flags then
              begin
                CalcUseSum(TForNode(n).t2);
                CalcDefSum(TForNode(n).t2);
              end
            else
              InternalError(2017122801);
            if not(Assigned(TForNode(n).left.optinfo)) then
              exit;
            if not(DynSetIn(TForNode(n).t2.optinfo^.usesum,TForNode(n).left.optinfo^.Index)) and
              not(DynSetIn(TForNode(n).t2.optinfo^.defsum,TForNode(n).left.optinfo^.Index))  then
              begin
                { convert the loop from i:=a to b into i:=b-a+1 to 1 as this simplifies the
                  abort condition }
                include(TForNode(n).LoopFlags,lnf_backward);
                TForNode(n).right:=CTypeConvNode.Create_Internal(
                  CAddNode.Create_Internal(addn,CAddNode.Create_Internal(subn,
                    TForNode(n).t1,TForNode(n).right),
                    COrdConstNode.Create(1,TForNode(n).left.resultdef,false)),
                  TForNode(n).left.resultdef);
                TForNode(n).t1:=COrdConstNode.Create(1,TForNode(n).left.resultdef,false);
                include(TForNode(n).LoopFlags,lnf_counter_not_used);
                exclude(n.transientflags,tnf_pass1_done);
                DoFirstPass(n);
                TOptimizeForLoopContext(arg^).changedforloop:=true;
              end;
          end;
      end;


    function OptimizeForLoop(var node : TNode) : boolean;
      var
        ctx : TOptimizeForLoopContext;
      begin
        ctx.changedforloop:=false;
        if pi_dfaavailable in CurrentProcInfo.flags then
          ForEachNodeStatic(pm_postprocess,node,@OptimizeForLoop_iterforloops,@ctx);
        Result:=ctx.changedforloop;
      end;

end.

