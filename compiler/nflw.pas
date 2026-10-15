{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Type checking and register allocation for nodes that influence
    the flow

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
unit nflw;

{$i fpcdefs.inc}

interface

    uses
      CClasses,
      node,cpubase,
      symconst,symtype,SymBase,symdef,SymSym,
      optloop;

    type
       { flags used by loop nodes }
       TLoopFlag = (
         { set if it is a for ... downto ... do loop }
         lnf_backward,
         { Do we need to parse childs to set var state? }
         lnf_varstate,
         { Do a test at the begin of the loop?}
         lnf_testatbegin,
         { Negate the loop test? }
         lnf_checknegate,
         { Should the value of the loop variable on exit be correct. }
         lnf_dont_mind_loopvar_on_exit,
         { Loop simplify flag }
         lnf_simplify_processing,
         { set if in a for loop the counter is not used, so an easier exit check
           can be carried out }
         lnf_counter_not_used);
       TLoopFlags = set of TLoopFlag;

    const
         { loop flags which must match to consider loop nodes equal regarding the flags }
         loopflagsequal = [lnf_backward];

    type
       TLabelNode = class;

       TLoopNode = class(TBinaryNode)
          t1,t2 : TNode;
          loopflags : TLoopFlags;
          constructor create(tt : TNodeType;l,r,_t1,_t2 : TNode);virtual;
          destructor Destroy;override;
          function dogetcopy : TNode;override;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          procedure insertintolist(l : TNodeList);override;
          procedure printnodetree(var t:text);override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeInfo(var T: Text); override;
          procedure XMLPrintNodeTree(var T: Text); override;
{$endif DEBUG_NODE_XML}
          function docompare(p: TNode): boolean; override;
       end;

       TWhileRepeatNode = class(TLoopNode)
          { l: condition; r: body; tab: test at begin; cn: negate condition
            x,y,true,false: while loop
            x,y,false,true: repeat until loop }
          constructor create(l,r:TNode;tab,cn:boolean);virtual;reintroduce;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
{$ifdef state_tracking}
          function track_state_pass(exec_known:boolean):boolean;override;
{$endif}
          function simplify(forinline: boolean): TNode;override;

          function internalsimplify(forinline: boolean): TNode;
       end;
       TWhileRepeatNodeClass = class of TWhileRepeatNode;

       TIfNode = class(TLoopNode)
          constructor create(l,r,_t1 : TNode);virtual;reintroduce;
          constructor create_internal(l,r,_t1 : TNode);virtual;reintroduce;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
          function simplify(forinline : boolean) : TNode;override;
         private
          function internalsimplify(warn: boolean) : TNode;
       end;
       TIfNodeClass = class of TIfNode;

       TForNode = class(TLoopNode)
          { if count isn't divisible by unrolls then
            the for loop must jump to this label to get the correct
            number of executions }
          entrylabel,
          { this is a dummy node used by the dfa to store life information for the loop iteration }
          loopiteration : TNode;
          loopvar_notid:cardinal;
          constructor create(l,r,_t1,_t2 : TNode;back : boolean);virtual;reintroduce;
          destructor Destroy;override;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
          function makewhileloop : TNode;
          function simplify(forinline : boolean) : TNode;override;
       end;
       TForNodeClass = class of TForNode;

       TExitNode = class(TUnaryNode)
          constructor create(l:TNode);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
          property resultexpr : TNode read left write left;
       end;
       TExitNodeClass = class of TExitNode;

       TBreakNode = class(TNode)
          constructor create;virtual;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
       end;
       TBreakNodeClass = class of TBreakNode;

       TContinueNode = class(TNode)
          constructor create;virtual;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
       end;
       TContinueNodeClass = class of TContinueNode;

       TGotoNode = class(TNode)
       private
          labelnodeidx : LongInt;
       public
          { * Set when creating the gotonode (since that's all we know at that
              point).
            * Used in pass_typecheck to find the corresponding labelnode (when a
              labelnode is created for a tlabelsym, the label assigns itself to
              the "code" field of the labelsym), which is then assigned to the
              labelnode field
            * After this, the labelsym is (and must) never be used anymore, and
              instead the labelnode must always be used. The reason is that the
              labelsym may not be owned by anything, and will be freed by the
              label node when it gets freed
            * The above is the reason why the labelsym field does not get copied
              by tgotonode.dogetcopy, but instead the copy of the labelnode gets
              tracked (both the labelnode and its goto nodes must always all be
              copied).

            The labelnode itself will not copy the labelsym either in dogetcopy.
            Instead, since the link between the gotos and the labels gets
            tracked via node tree references, the label node will generate a new
            asmlabel on the fly and the goto node will get it from there (if the
            goto node gets processed before the label node has been processed,
            it will ask the label node to generate the asmsymbol at that point).

            The original tlabelsym will get emitted only for the original
            label node. It is only actually used if there is a reference to it
            from
              * an inline assembly block. Since inline assembly blocks cannot be
                inlined at this point, it doesn't matter that this would break
                in case the node gets copied
              * global goto/label. Inlining is not supported for these, so no
                problem here either for now.
              * a load node (its symtableentry field). Since the symtableentry
                of loadnodes is always expected to be valid, we cannot do like
                with the goto nodes. Instead, we will create a new labelsym
                when performing a dogetcopy of such a load node and assign this
                labelsym to the copied labelnode (and vice versa)
          }
          labelsym : TLabelSym;
          labelnode : TLabelNode;
          exceptionblock : integer;
          constructor create(p : TLabelSym);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          procedure resolveppuidx;override;
          function dogetcopy : TNode;override;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
          function docompare(p: TNode): boolean; override;
       end;
       TGotoNodeClass = class of TGotoNode;

       TLabelNode = class(TNode)
          exceptionblock : integer;
          { when copying trees, this points to the newly created copy of a label }
          copiedto : TLabelNode;
          labsym : TLabelSym;
          constructor create(l:TNode;alabsym:TLabelSym);virtual;
          destructor Destroy;override;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          function dogetcopy : TNode;override;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
          function docompare(p: TNode): boolean; override;
       end;
       TLabelNodeClass = class of TLabelNode;

       TRaiseNode = class(TTertiaryNode)
          constructor create(l,taddr,tframe:TNode);virtual;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
       end;
       TRaiseNodeClass = class of TRaiseNode;

       TTryExceptNode = class(TLoopNode)
          constructor create(l,r,_t1 : TNode);virtual;reintroduce;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
          function simplify(forinline: boolean): TNode; override;
         protected
          procedure adjust_estimated_stack_size; virtual;
       end;
       TTryExceptNodeClass = class of TTryExceptNode;

       { the third node is to store a copy of the finally code for llvm:
         it needs one copy to execute in case an exception occurs, and
         one in case no exception occurs }
       TTryFinallyNode = class(TTertiaryNode)
          implicitframe : boolean;
          constructor create(l,r:TNode);virtual;reintroduce;
          constructor create_implicit(l,r:TNode);virtual;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
          function simplify(forinline:boolean): TNode;override;
       protected
          procedure adjust_estimated_stack_size; virtual;
       public
          function dogetcopy: TNode;override;
       end;
       TTryFinallyNodeClass = class of TTryFinallyNode;

       TOnNode = class(TBinaryNode)
          excepTSymtable : TSymTable;
          excepttype : TObjectDef;
          constructor create(l,r:TNode);virtual;
          destructor Destroy;override;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
          function dogetcopy : TNode;override;
          function docompare(p: TNode): boolean; override;
       end;
       TOnNodeClass = class of TOnNode;

    var
       CWhileRepeatNode : TWhileRepeatNodeClass=TWhileRepeatNode;
       CIfNode : TIfNodeClass = TIfNode;
       CForNode : TForNodeClass = TForNode;
       CExitNode : TExitNodeClass = TExitNode;
       CGotoNode : TGotoNodeClass = TGotoNode;
       CLabelNode : TLabelNodeClass = TLabelNode;
       CRaiseNode : TRaiseNodeClass = TRaiseNode;
       CTryExceptNode : TTryExceptNodeClass = TTryExceptNode;
       CTryFinallyNode : TTryFinallyNodeClass = TTryFinallyNode;
       COnNode : TOnNodeClass = TOnNode;
       CBreakNode : TBreakNodeClass = TBreakNode;
       CContinueNode : TContinueNodeClass = TContinueNode;

    // for-in loop helpers
    function create_type_for_in_loop(hloopvar, hloopbody, expr: TNode): TNode;
    function create_string_for_in_loop(hloopvar, hloopbody, expr: TNode): TNode;
    function create_array_for_in_loop(hloopvar, hloopbody, expr: TNode): TNode;
    function create_set_for_in_loop(hloopvar, hloopbody, expr: TNode): TNode;
    function create_enumerator_for_in_loop(hloopvar, hloopbody, expr: TNode;
       enumerator_get, enumerator_move: TProcDef; enumerator_current: TPropertySym): TNode;
    function create_for_in_loop(hloopvar, hloopbody, expr: TNode): TNode;

    { converts all for nodes in the tree into while nodes,
      returns true if something was converted }
    function ConvertForLoops(var n : TNode) : Boolean;

implementation

    uses
      GlobType,Systems,ConstExp,compinnr,
      CUtils,Verbose,Globals,PPU,
      SymTable,paramgr,defcmp,defutil,htypechk,pass_1,
      ncal,nadd,ncon,nmem,nld,ncnv,nbas,nutils,ninl,nset,ngenutil,
    {$ifdef state_tracking}
      nstate,
    {$endif}

    {$if defined(i386)}
      CPUInfo,
    {$endif defined(xtensa) or defined(i386)}
      cgbase,ProcInfo
      ;


    // for-in loop helpers

    function create_type_for_in_loop(hloopvar, hloopbody, expr: TNode): TNode;
      begin
        result:=CForNode.create(hloopvar,
          CInlineNode.create(in_low_x,false,expr.getcopy),
          CInlineNode.create(in_high_x,false,expr.getcopy),
          hloopbody,
          false);
      end;


    function create_objc_for_in_loop(hloopvar, hloopbody, expr: TNode): TNode;
      var
        mainstatement, outerloopbodystatement, innerloopbodystatement, tempstatement: TStatementNode;
        state, mutationcheck, currentamount, innerloopcounter, items, expressiontemp: TTempCreateNode;
        outerloop, innerloop, hp: TNode;
        itemsarraydef: TArrayDef;
        sym: TSym;
      begin
        { Objective-C enumerators require Objective-C 2.0 }
        if not(m_objectivec2 in CurrentSettings.ModeSwitches) then
          begin
            result:=CErrorNode.create;
            MessagePos(expr.fileinfo,parser_e_objc_enumerator_2_0);
            exit;
          end;
        { Requires the NSFastEnumeration protocol and NSFastEnumerationState
          record }
        maybeloadcocoatypes;
        if not Assigned(objc_fastenumeration) or
           not Assigned(objc_fastenumerationstate) then
          begin
            result:=CErrorNode.create;
            MessagePos(expr.fileinfo,parser_e_objc_missing_enumeration_defs);
            exit;
          end;

        (* Original code:
            for hloopvar in expression do
              <hloopbody>

          Pascal code equivalent into which it has to be transformed
          (sure would be nice if the compiler had some kind of templates ;) :
            var
              state: NSFastEnumerationState;
              expressiontemp: NSFastEnumerationProtocol;
              mutationcheck,
              currentamount,
              innerloopcounter: culong;
              { size can be increased/decreased if desired }
              items: array[1..16] of id;
            begin
              fillchar(state,sizeof(state),0);
              expressiontemp:=expression;
              repeat
                currentamount:=expressiontemp.countByEnumeratingWithState_objects_count(@state,@items,length(items));
                if currentamount=0 then
                  begin
                    { "The iterating variable is set to nil when the loop ends by
                      exhausting the source pool of objects" }
                    hloopvar:=nil;
                    break;
                  end;
                mutationcheck:=state.mutationsptr^;
                innerloopcounter:=culong(-1);
                repeat
                  { at the start so that "continue" in <loopbody> works correctly }
                  { don't use for-loop, because then the value of the iteration
                    counter is undefined on exit and we have to check it in the
                    outer repeat/until condition }
                  {$push}
                  {$r-,q-}
                  inc(innerloopcounter);
                  {$pop}
                  if innerloopcounter=currentamount then
                    break;
                  if mutationcheck<>state.mutationsptr^ then
                    { raises Objective-C exception... }
                    objc_enumerationMutation(expressiontemp);
                  hloopvar:=state.itemsPtr[innerloopcounter];
                  { if continue in loopbody -> jumps to start, increases count and checks }
                  { if break in loopbody: goes to outer repeat/until and innerloopcount
                    will be < currentamount -> stops }
                  <hloopbody>
                until false;
              { if the inner loop terminated early, "break" was used and we have
                to stop }
              { "If the loop is terminated early, the iterating variable is left
                pointing to the last iteration item." }
              until innerloopcounter<currentamount;
            end;
         *)

         result:=internalstatements(mainstatement);
         { the fast enumeration state }
         state:=CTempCreateNode.create(objc_fastenumerationstate,objc_fastenumerationstate.size,tt_persistent,false);
         TypeCheckPass(TNode(state));
         addstatement(mainstatement,state);
         { the temporary items array }
         itemsarraydef:=CArrayDef.create(1,16,u32inttype);
         itemsarraydef.elementdef:=objc_idtype;
         items:=CTempCreateNode.create(itemsarraydef,itemsarraydef.size,tt_persistent,false);
         addstatement(mainstatement,items);
         TypeCheckPass(TNode(items));
         { temp for the expression/collection through which we iterate }
         expressiontemp:=CTempCreateNode.create(objc_fastenumeration,objc_fastenumeration.size,tt_persistent,true);
         addstatement(mainstatement,expressiontemp);
         { currentamount temp (not really clean: we use ptruint instead of
           culong) }
         currentamount:=CTempCreateNode.create(ptruinttype,ptruinttype.size,tt_persistent,true);
         TypeCheckPass(TNode(currentamount));
         addstatement(mainstatement,currentamount);
         { mutationcheck temp (idem) }
         mutationcheck:=CTempCreateNode.create(ptruinttype,ptruinttype.size,tt_persistent,true);
         TypeCheckPass(TNode(mutationcheck));
         addstatement(mainstatement,mutationcheck);
         { innerloopcounter temp (idem) }
         innerloopcounter:=CTempCreateNode.create(ptruinttype,ptruinttype.size,tt_persistent,true);
         TypeCheckPass(TNode(innerloopcounter));
         addstatement(mainstatement,innerloopcounter);
         { initialise the state with 0 }
         addstatement(mainstatement,CCallNode.createinternfromunit('SYSTEM','FILLCHAR',
           CCallParaNode.create(genintconstnode(0),
             CCallParaNode.create(genintconstnode(objc_fastenumerationstate.size),
               CCallParaNode.create(CTempRefNode.create(state),nil)
             )
           )
         ));
         { this will also check whether the expression (potentially) conforms
           to the NSFastEnumeration protocol (use expr.getcopy, because the
           caller will free expr) }
         addstatement(mainstatement,CAssignmentNode.create(CTempRefNode.create(expressiontemp),expr.getcopy));

         { we add the "repeat..until" afterwards, now just create the body }
         outerloop:=internalstatements(outerloopbodystatement);
         { the countByEnumeratingWithState_objects_count call }
         hp:=CCallParaNode.create(CInlineNode.create(in_length_x,false,CTypeNode.create(itemsarraydef)),
               CCallParaNode.create(CAddrNode.create(CTempRefNode.create(items)),
                 CCallParaNode.create(CAddrNode.create(CTempRefNode.create(state)),nil)
               )
             );
         sym:=search_struct_member(objc_fastenumeration,'COUNTBYENUMERATINGWITHSTATE_OBJECTS_COUNT');
         if not Assigned(sym) or
            (sym.typ<>procsym) then
           InternalError(2010061901);
         hp:=CCallNode.create(hp,TProcSym(sym),sym.owner,CTempRefNode.create(expressiontemp),[],nil);
         addstatement(outerloopbodystatement,CAssignmentNode.create(
           CTempRefNode.create(currentamount),hp));
         { if currentamount = 0, bail out (use copy of hloopvar, because we
           have to use it again below) }
         hp:=internalstatements(tempstatement);
         addstatement(tempstatement,CAssignmentNode.create(
             hloopvar.getcopy,CNilNode.create));
         addstatement(tempstatement,CBreakNode.create);
         addstatement(outerloopbodystatement,CIfNode.create(
           CAddNode.create(equaln,CTempRefNode.create(currentamount),genintconstnode(0)),
           hp,nil));
        { initial value of mutationcheck }
        hp:=CTempRefNode.create(state);
        TypeCheckPass(hp);
        hp:=CDerefNode.create(genloadfield(hp,'MUTATIONSPTR'));
        addstatement(outerloopbodystatement,CAssignmentNode.create(
          CTempRefNode.create(mutationcheck),hp));
        { initialise innerloopcounter }
        addstatement(outerloopbodystatement,CAssignmentNode.create(
          CTempRefNode.create(innerloopcounter),COrdConstNode.create(-1,ptruinttype,false)));

        { and now the inner loop, again adding the repeat/until afterwards }
        innerloop:=internalstatements(innerloopbodystatement);
        { inc(innerloopcounter) without range/overflowchecking (because
          we go from culong(-1) to 0 during the first iteration }
        hp:=CInlineNode.create(
          in_inc_x,false,CCallParaNode.create(
            CTempRefNode.create(innerloopcounter),nil));
        hp.LocalSwitches:=hp.LocalSwitches-[cs_check_range,cs_check_overflow];
        addstatement(innerloopbodystatement,hp);
        { if innerloopcounter=currentamount then break to the outer loop }
        addstatement(innerloopbodystatement,CIfNode.create(
          CAddNode.create(equaln,
            CTempRefNode.create(innerloopcounter),
            CTempRefNode.create(currentamount)),
          CBreakNode.create,
          nil));
        { verify that the collection didn't change in the mean time }
        hp:=CTempRefNode.create(state);
        TypeCheckPass(hp);
        addstatement(innerloopbodystatement,CIfNode.create(
          CAddNode.create(unequaln,
            CTempRefNode.create(mutationcheck),
            CDerefNode.create(genloadfield(hp,'MUTATIONSPTR'))
          ),
          CCallNode.createinternfromunit('OBJC','OBJC_ENUMERATIONMUTATION',
            CCallParaNode.create(CTempRefNode.create(expressiontemp),nil)),
          nil));
        { finally: actually get the next element }
        hp:=CTempRefNode.create(state);
        TypeCheckPass(hp);
        hp:=genloadfield(hp,'ITEMSPTR');
        TypeCheckPass(hp);
        { don't simply use a vecn, because indexing a pointer won't work in
          non-FPC modes }
        if hp.resultdef.typ<>pointerdef then
          InternalError(2010061904);
        inserttypeconv(hp,
          CArrayDef.create_from_pointer(TPointerDef(hp.resultdef)));
        hp:=CVecNode.create(hp,CTempRefNode.create(innerloopcounter));
        addstatement(innerloopbodystatement,
          CAssignmentNode.create(hloopvar,hp));
        { the actual loop body! }
        addstatement(innerloopbodystatement,hloopbody);

        { create the inner repeat/until and add it to the body of the outer
          one }
        hp:=CWhileRepeatNode.create(
          { repeat .. until false }
          COrdConstNode.create(0,pasbool1type,false),innerloop,false,true);
        addstatement(outerloopbodystatement,hp);

        { create the outer repeat/until and add it to the the main body }
        hp:=CWhileRepeatNode.create(
          { repeat .. until innerloopcounter<currentamount }
          CAddNode.create(ltn,
            CTempRefNode.create(innerloopcounter),
            CTempRefNode.create(currentamount)),
          outerloop,false,true);
        addstatement(mainstatement,hp);

        { release the temps }
        addstatement(mainstatement,CTempDeleteNode.create(state));
        addstatement(mainstatement,CTempDeleteNode.create(mutationcheck));
        addstatement(mainstatement,CTempDeleteNode.create(currentamount));
        addstatement(mainstatement,CTempDeleteNode.create(innerloopcounter));
        addstatement(mainstatement,CTempDeleteNode.create(items));
        addstatement(mainstatement,CTempDeleteNode.create(expressiontemp));
      end;


    function create_string_for_in_loop(hloopvar, hloopbody, expr: TNode): TNode;
      var
        loopstatement, loopbodystatement: TStatementNode;
        loopvar, stringvar: TTempCreateNode;
        stringindex, loopbody, forloopnode, fromn, ton: TNode;
      begin
        { result is a block of statements }
        result:=internalstatements(loopstatement);

        { create a temp variable for expression }
        stringvar := CTempCreateNode.create(
          expr.resultdef,
          expr.resultdef.size,
          tt_persistent,true);

        addstatement(loopstatement,stringvar);
        addstatement(loopstatement,CAssignmentNode.create(CTempRefNode.create(stringvar),expr.getcopy));

        { create a loop counter: signed integer with size of string length }
        loopvar := CTempCreateNode.create(
          sinttype,
          sinttype.size,
          tt_persistent,true);

        addstatement(loopstatement,loopvar);

        stringindex:=CTempRefNode.create(loopvar);

        loopbody:=internalstatements(loopbodystatement);
        // for-in loop variable := string_expression[index]
        addstatement(loopbodystatement,
          CAssignmentNode.create(hloopvar, CVecNode.create(CTempRefNode.create(stringvar),stringindex)));

        { add the actual statement to the loop }
        addstatement(loopbodystatement,hloopbody);

        if TStringDef(expr.resultdef).stringtype=st_shortstring then
          begin
            fromn:=genintconstnode(1);
            ton:=CInlineNode.create(in_length_x,false,CTempRefNode.create(stringvar));
          end
        else
          begin
             fromn:=CInlineNode.createintern(in_low_x,false,CTempRefNode.create(stringvar));
             ton:= CInlineNode.create(in_high_x,false,CTempRefNode.create(stringvar));
           end;

        forloopnode:=CForNode.create(CTempRefNode.create(loopvar),
          fromn,
          ton,
          loopbody,
          false);

        addstatement(loopstatement,forloopnode);
        { free the loop counter }
        addstatement(loopstatement,CTempDeleteNode.create(loopvar));
        { free the temp variable for expression }
        addstatement(loopstatement,CTempDeleteNode.create(stringvar));
      end;


    function create_array_for_in_loop(hloopvar, hloopbody, expr: TNode): TNode;
      var
        loopstatement, loopbodystatement: TStatementNode;
        loopvar, arrayvar: TTempCreateNode;
        arrayindex, lowbound, highbound, loopbody, forloopnode, expression: TNode;
        is_string: boolean;
        tmpdef, convertdef: TDef;
        elementcount: aword;
      begin
        expression := expr;

        { result is a block of statements }
        result:=internalstatements(loopstatement);

        is_string:=ado_IsConstString in TArrayDef(expr.resultdef).arrayoptions;

        // if array element type <> loovar type then create a conversion if possible
        if compare_defs(TArrayDef(expression.resultdef).elementdef,hloopvar.resultdef,nothingn)=te_incompatible then
          begin
            tmpdef:=expression.resultdef;
            elementcount:=1;
            while Assigned(tmpdef) and (tmpdef.typ=arraydef) and
                  (TArrayDef(tmpdef).arrayoptions = []) and
                  (compare_defs(TArrayDef(tmpdef).elementdef,hloopvar.resultdef,nothingn)=te_incompatible) do
              begin
                elementcount:=elementcount*TArrayDef(tmpdef).elecount;
                tmpdef:=TArrayDef(tmpdef).elementdef;
              end;
            if Assigned(tmpdef) and (tmpdef.typ=arraydef) and (TArrayDef(tmpdef).arrayoptions = []) then
              begin
                elementcount:=elementcount*TArrayDef(tmpdef).elecount;
                convertdef:=CArrayDef.create(0,elementcount-1,s32inttype);
                TArrayDef(convertdef).elementdef:=TArrayDef(tmpdef).elementdef;
                expression:=expr.getcopy;
                expression:=CTypeConvNode.create_internal(expression,convertdef);
                TypeCheckPass(expression);
                addstatement(loopstatement,expression);
              end;
          end;

        if (node_complexity(expression) > 1) and
          not(is_open_array(expression.resultdef)) and not(is_array_of_const(expression.resultdef)) then
          begin
            { create a temp variable for expression }
            arrayvar := CTempCreateNode.create(
              expression.resultdef,
              expression.resultdef.size,
              tt_persistent,true);

            if is_string then
              begin
                lowbound:=genintconstnode(1);
                highbound:=CInlineNode.create(in_length_x,false,CTempRefNode.create(arrayvar))
              end
            else
              begin
                { Iterating through slice }
                if (expression.nodetype=vecn) and (TVecNode(expression).right.nodetype=rangen) then
                  begin
                    lowbound:=TRangeNode(TVecNode(expression).right).left.getcopy;
                    highbound:=TRangeNode(TVecNode(expression).right).right.getcopy;
                    expression:=TVecNode(expression).left.getcopy;
                  end
                else
                  begin
                    lowbound:=CInlineNode.create(in_low_x,false,CTempRefNode.create(arrayvar));
                    highbound:=CInlineNode.create(in_high_x,false,CTempRefNode.create(arrayvar));
                  end;
              end;

            addstatement(loopstatement,arrayvar);
            addstatement(loopstatement,CAssignmentNode.create(CTempRefNode.create(arrayvar),expression.getcopy));
          end
        else
          begin
            arrayvar:=nil;
            if is_string then
              begin
                lowbound:=genintconstnode(1);
                highbound:=CInlineNode.create(in_length_x,false,expression.getcopy);
              end
            else
              begin
                { Iterating through slice }
                if (expression.nodetype=vecn) and (TVecNode(expression).right.nodetype=rangen) then
                  begin
                    lowbound:=TRangeNode(TVecNode(expression).right).left.getcopy;
                    highbound:=TRangeNode(TVecNode(expression).right).right.getcopy;
                    expression:=TVecNode(expression).left.getcopy;
                  end
                else
                  begin
                    lowbound:=CInlineNode.create(in_low_x,false,expression.getcopy);
                    highbound:=CInlineNode.create(in_high_x,false,expression.getcopy);
                  end;
              end;
          end;

        { create a loop counter }
        loopvar := CTempCreateNode.create(
          TArrayDef(expression.resultdef).rangedef,
          TArrayDef(expression.resultdef).rangedef.size,
          tt_persistent,true);

        addstatement(loopstatement,loopvar);

        arrayindex:=CTempRefNode.create(loopvar);

        loopbody:=internalstatements(loopbodystatement);
        // for-in loop variable := array_expression[index]
        if Assigned(arrayvar) then
          addstatement(loopbodystatement,
            CAssignmentNode.create(hloopvar,CVecNode.create(CTempRefNode.create(arrayvar),arrayindex)))
        else
          addstatement(loopbodystatement,
            CAssignmentNode.create(hloopvar,CVecNode.create(expression.getcopy,arrayindex)));

        { add the actual statement to the loop }
        addstatement(loopbodystatement,hloopbody);

        forloopnode:=CForNode.create(CTempRefNode.create(loopvar),
          lowbound,
          highbound,
          loopbody,
          false);

        addstatement(loopstatement,forloopnode);
        { free the loop counter }
        addstatement(loopstatement,CTempDeleteNode.create(loopvar));
        { free the temp variable for expression if needed }
        if arrayvar<>nil then
          addstatement(loopstatement,CTempDeleteNode.create(arrayvar));
      end;


    function create_set_for_in_loop(hloopvar, hloopbody, expr: TNode): TNode;
      var
        loopstatement, loopbodystatement: TStatementNode;
        loopvar, setvar: TTempCreateNode;
        loopbody, forloopnode: TNode;
      begin
        // first check is set is empty and if it so then skip other processing
        if not Assigned(TSetDef(expr.resultdef).elementdef) then
          begin
            result:=CNothingNode.create;
            // free unused nodes
            hloopvar.free;
            hloopvar := nil;
            hloopbody.free;
            hloopbody := nil;
            exit;
          end;
        { result is a block of statements }
        result:=internalstatements(loopstatement);

        { create a temp variable for expression }
        setvar := CTempCreateNode.create(
          expr.resultdef,
          expr.resultdef.size,
          tt_persistent,true);

        addstatement(loopstatement,setvar);
        addstatement(loopstatement,CAssignmentNode.create(CTempRefNode.create(setvar),expr.getcopy));

        { create a loop counter }
        loopvar := CTempCreateNode.create(
          TSetDef(expr.resultdef).elementdef,
          TSetDef(expr.resultdef).elementdef.size,
          tt_persistent,true);

        addstatement(loopstatement,loopvar);

        // if loopvar in set then
        // begin
        //   hloopvar := loopvar
        //   for-in loop body
        // end

        loopbody:=CIfNode.create(
          CInNode.create(CTempRefNode.create(loopvar),CTempRefNode.create(setvar)),
          internalstatements(loopbodystatement),
          nil);

        addstatement(loopbodystatement,CAssignmentNode.create(hloopvar,CTempRefNode.create(loopvar)));
        { add the actual statement to the loop }
        addstatement(loopbodystatement,hloopbody);

        forloopnode:=CForNode.create(CTempRefNode.create(loopvar),
          CInlineNode.create(in_low_x,false,CTempRefNode.create(setvar)),
          CInlineNode.create(in_high_x,false,CTempRefNode.create(setvar)),
          loopbody,
          false);

        addstatement(loopstatement,forloopnode);
        { free the loop counter }
        addstatement(loopstatement,CTempDeleteNode.create(loopvar));
        { free the temp variable for expression }
        addstatement(loopstatement,CTempDeleteNode.create(setvar));
      end;


    function create_enumerator_for_in_loop(hloopvar, hloopbody, expr: TNode;
       enumerator_get, enumerator_move: TProcDef; enumerator_current: TPropertySym): TNode;
      var
        loopstatement, loopbodystatement: TStatementNode;
        enumvar: TTempCreateNode;
        loopbody, whileloopnode,
        enum_get, enum_move, enum_current, enum_get_params: TNode;
        propaccesslist: TPropAccessList;
        enumerator_is_class: boolean;
        enumerator_destructor: TProcDef;
      begin
        { result is a block of statements }
        result:=internalstatements(loopstatement);

        enumerator_is_class := is_class(enumerator_get.returndef);

        { create a temp variable for enumerator }
        enumvar := CTempCreateNode.create(
          enumerator_get.returndef,
          enumerator_get.returndef.size,
          tt_persistent,true);

        addstatement(loopstatement,enumvar);

        if enumerator_get.proctypeoption=potype_operator then
          begin
            enum_get_params:=CCallParaNode.create(expr.getcopy,nil);
            enum_get:=CCallNode.create(enum_get_params, TProcSym(enumerator_get.procsym), nil, nil, [],nil);
            TCallNode(enum_get).procdefinition:=enumerator_get;
            addsymref(enumerator_get.procsym,enumerator_get);
          end
        else
          enum_get:=CCallNode.create(nil, TProcSym(enumerator_get.procsym), enumerator_get.owner, expr.getcopy, [],nil);

        addstatement(loopstatement,
          CAssignmentNode.create(
            CTempRefNode.create(enumvar),
            enum_get
          ));

        loopbody:=internalstatements(loopbodystatement);
        { for-in loop variable := enumerator.current }
        if enumerator_current.getpropaccesslist(palt_read,propaccesslist) then
          begin
             case propaccesslist.firstsym^.sym.typ of
               fieldvarsym :
                 begin
                   { generate access code }
                   enum_current:=CTempRefNode.create(enumvar);
                   propaccesslist_to_node(enum_current,enumerator_current.owner,propaccesslist);
                   include(enum_current.flags,nf_isproperty);
                 end;
               procsym :
                 begin
                   { generate the method call }
                   enum_current:=CCallNode.create(nil,TProcSym(propaccesslist.firstsym^.sym),enumerator_current.owner,CTempRefNode.create(enumvar),[],nil);
                   include(enum_current.flags,nf_isproperty);
                 end
               else
                 begin
                   enum_current:=CErrorNode.create;
                   Message(type_e_mismatch);
                 end;
            end;
          end
        else
          enum_current:=CErrorNode.create;

        addstatement(loopbodystatement,
          CAssignmentNode.create(hloopvar, enum_current));

        { add the actual statement to the loop }
        addstatement(loopbodystatement,hloopbody);

        enum_move:=CCallNode.create(nil, TProcSym(enumerator_move.procsym), enumerator_move.owner, CTempRefNode.create(enumvar), [],nil);
        whileloopnode:=CWhileRepeatNode.create(enum_move,loopbody,true,false);

        if enumerator_is_class then
          begin
            { insert a try-finally and call the destructor for the enumerator in the finally section }
            enumerator_destructor:=TObjectDef(enumerator_get.returndef).find_destructor;
            if Assigned(enumerator_destructor) then
              begin
                whileloopnode:=CTryFinallyNode.create(
                  whileloopnode, // try node
                  CCallNode.create(nil,TProcSym(enumerator_destructor.procsym), // finally node
                    enumerator_destructor.procsym.owner,CTempRefNode.create(enumvar),[],nil));
              end;
            { if getenumerator <> nil then do the loop }
            whileloopnode:=CIfNode.create(
              CAddNode.create(unequaln, CTempRefNode.create(enumvar), CNilNode.create),
              whileloopnode,
              nil);
          end;

        addstatement(loopstatement, whileloopnode);

        if is_object(enumerator_get.returndef) then
          begin
            // call the object destructor too
            enumerator_destructor:=TObjectDef(enumerator_get.returndef).find_destructor;
            if Assigned(enumerator_destructor) then
              begin
                addstatement(loopstatement,
                  CCallNode.create(nil,TProcSym(enumerator_destructor.procsym),
                    enumerator_destructor.procsym.owner,CTempRefNode.create(enumvar),[],nil));
              end;
          end;

        { free the temp variable for enumerator }
        addstatement(loopstatement,CTempDeleteNode.create(enumvar));
      end;


    function create_for_in_loop(hloopvar, hloopbody, expr: TNode): TNode;
      var
        pd, movenext: TProcDef;
        helperdef: TObjectDef;
        current: TPropertySym;
        storefilepos: TFilePosInfo;
      begin
        storefilepos:=CurrentFilePos;
        CurrentFilePos:=hloopvar.fileinfo;
        if expr.nodetype=typen then
          begin
            if (expr.resultdef.typ=enumdef) and TEnumDef(expr.resultdef).has_jumps then
              begin
                result:=CErrorNode.create;
                hloopvar.free;
                hloopvar := nil;
                hloopbody.free;
                hloopbody := nil;
                MessagePos1(expr.fileinfo,parser_e_for_in_loop_cannot_be_used_for_the_type,expr.resultdef.typename);
              end
            else
              result:=create_type_for_in_loop(hloopvar, hloopbody, expr);
          end
        else
          begin
            { loop is made for an expression }
            // Objective-C uses different conventions (and it's only supported for Objective-C 2.0)
            if is_objc_class_or_protocol(hloopvar.resultdef) or
               is_objc_class_or_protocol(expr.resultdef) then
              begin
                result:=create_objc_for_in_loop(hloopvar,hloopbody,expr);
                if result.nodetype=errorn then
                  begin
                    hloopvar.free;
                    hloopvar := nil;
                    hloopbody.free;
                    hloopbody := nil;
                  end;
              end
            { "for x in [] do ..." always results in a never executed loop body }
            else if (is_array_constructor(expr.resultdef) and
                (TArrayDef(expr.resultdef).elementdef=voidtype)) then
              begin
                if Assigned(hloopbody) then
                  MessagePos(hloopbody.fileinfo,cg_w_unreachable_code);
                result:=CNothingNode.create;
              end
            else
              begin
                if is_array_constructor(expr.resultdef) then
                  TArrayConstructorNode(expr).force_type(hloopvar.resultdef);
                // search for operator first
                pd:=search_enumerator_operator(expr.resultdef, hloopvar.resultdef);
                // if there is no operator then search for class/object enumerator method
                if (pd=nil) and (expr.resultdef.typ in [objectdef,recorddef]) then
                  begin
                    { first search using the helper hierarchy }
                    if search_last_objectpascal_helper(TAbstractRecordDef(expr.resultdef),nil,helperdef) then
                      repeat
                        pd:=helperdef.search_enumerator_get;
                        helperdef:=helperdef.childof;
                      until (pd<>nil) or (helperdef=nil);
                    { we didn't find an enumerator in a helper, so search in the
                      class/record/object itself }
                    if pd=nil then
                      pd:=TAbstractRecordDef(expr.resultdef).search_enumerator_get;
                  end;
                if pd<>nil then
                  begin
                    // seach movenext and current symbols
                    movenext:=TAbstractRecordDef(pd.returndef).search_enumerator_move;
                    if movenext = nil then
                      begin
                        result:=CErrorNode.create;
                        hloopvar.free;
                        hloopvar := nil;
                        hloopbody.free;
                        hloopbody := nil;
                        MessagePos1(expr.fileinfo,sym_e_no_enumerator_move,pd.returndef.typename);
                      end
                    else
                      begin
                        current:=TPropertySym(TAbstractRecordDef(pd.returndef).search_enumerator_current);
                        if current = nil then
                          begin
                            result:=CErrorNode.create;
                            hloopvar.free;
                            hloopvar := nil;
                            hloopbody.free;
                            hloopbody := nil;
                            MessagePos1(expr.fileinfo,sym_e_no_enumerator_current,pd.returndef.typename);
                          end
                        else
                          result:=create_enumerator_for_in_loop(hloopvar, hloopbody, expr, pd, movenext, current);
                      end;
                  end
                else
                  begin
                    { prefer set if loop var could be a set var and the loop
                      expression can indeed be a set }
                    if (expr.nodetype=arrayconstructorn) and
                        (hloopvar.resultdef.typ in [enumdef,orddef]) and
                        arrayconstructor_can_be_set(expr) then
                      begin
                        expr:=arrayconstructor_to_set(expr,false);
                        TypeCheckPass(expr);
                      end;
                    case expr.resultdef.typ of
                      stringdef:
                        result:=create_string_for_in_loop(hloopvar, hloopbody, expr);
                      arraydef:
                        result:=create_array_for_in_loop(hloopvar, hloopbody, expr);
                      setdef:
                        result:=create_set_for_in_loop(hloopvar, hloopbody, expr);
                      undefineddef:
                        result:=CNothingNode.create;
                    else
                      begin
                        result:=CErrorNode.create;
                        hloopvar.free;
                        hloopvar := nil;
                        hloopbody.free;
                        hloopbody := nil;
                        MessagePos1(expr.fileinfo,sym_e_no_enumerator,expr.resultdef.typename);
                      end;
                    end;
                  end;
              end;
          end;
        CurrentFilePos:=storefilepos;
      end;


    function _ConvertForLoops(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        hp : TNode;
      begin
        Result:=fen_false;
        if n.nodetype=forn then
          begin
            Result:=fen_true;
            hp:=n;
            n:=TForNode(n).makewhileloop;
            DoFirstPass(n);
            hp.Free;
            hp := nil;
          end;
      end;


    function ConvertForLoops(var n : TNode) : boolean;
      begin
        result:=foreachnodestatic(pm_postprocess,n,@_ConvertForLoops,nil);
      end;

{****************************************************************************
                                 TLOOPNODE
*****************************************************************************}

    constructor TLoopNode.create(tt : TNodeType;l,r,_t1,_t2 : TNode);

      begin
         inherited create(tt,l,r);
         t1:=_t1;
         t2:=_t2;
         fileinfo:=l.fileinfo;
      end;

    destructor TLoopNode.Destroy;

      begin
         t1.free;
         t1 := nil;
         t2.free;
         t2 := nil;
         inherited Destroy;
      end;


    constructor TLoopNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        t1:=ppuloadnode(ppufile);
        t2:=ppuloadnode(ppufile);
        ppufile.GetSet(TPPUSet1(loopflags));
      end;


    procedure TLoopNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppuwritenode(ppufile,t1);
        ppuwritenode(ppufile,t2);
        ppufile.PutSet(TPPUSet1(loopflags));
      end;


    procedure TLoopNode.buildderefimpl;
      begin
        inherited buildderefimpl;
        if Assigned(t1) then
          t1.buildderefimpl;
        if Assigned(t2) then
          t2.buildderefimpl;
      end;


    procedure TLoopNode.derefimpl;
      begin
        inherited derefimpl;
        if Assigned(t1) then
          t1.derefimpl;
        if Assigned(t2) then
          t2.derefimpl;
      end;


    function TLoopNode.dogetcopy : TNode;

      var
         p : TLoopNode;

      begin
         p:=TLoopNode(inherited dogetcopy);
         if Assigned(t1) then
           p.t1:=t1.dogetcopy
         else
           p.t1:=nil;
         if Assigned(t2) then
           p.t2:=t2.dogetcopy
         else
           p.t2:=nil;
         p.loopflags:=loopflags;
         dogetcopy:=p;
      end;

    procedure TLoopNode.insertintolist(l : TNodeList);

      begin
      end;


    procedure TLoopNode.printnodetree(var t:text);
      begin
        write(t,PrintNodeIndention,'(');
        PrintNodeIndent;
        printnodeinfo(t);
        WriteLn(t);
        printnode(t,left);
        printnode(t,right);
        printnode(t,t1);
        printnode(t,t2);
        PrintNodeUnindent;
        WriteLn(t,PrintNodeIndention,')');
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TLoopNode.XMLPrintNodeInfo(var T: Text);
      var
        i: TLoopFlag;
        First: Boolean;
      begin
        inherited XMLPrintNodeInfo(T);

        First := True;
        for i := Low(TLoopFlag) to High(TLoopFlag) do
          if i in loopflags then
            begin
              if First then
                begin
                  Write(T, ' loopflags="', i);
                  First := False;
                end
              else
                Write(T, ',', i)
            end;
        if not First then
          Write(T, '"');
      end;

    procedure TLoopNode.XMLPrintNodeTree(var T: Text);
      begin
        Write(T, PrintNodeIndention, '<', nodetype2str[nodetype]);
        XMLPrintNodeInfo(T);
        WriteLn(T, '>');
        PrintNodeIndent;
        if Assigned(Left) then
          begin
            if nodetype = forn then
              WriteLn(T, PrintNodeIndention, '<counter>')
            else
              WriteLn(T, PrintNodeIndention, '<condition>');
            PrintNodeIndent;
            XMLPrintNode(T, Left);
            PrintNodeUnindent;
            if nodetype = forn then
              WriteLn(T, PrintNodeIndention, '</counter>')
            else
              WriteLn(T, PrintNodeIndention, '</condition>');
          end;

        if Assigned(Right) then
          begin
            case nodetype of
              ifn:
                WriteLn(T, PrintNodeIndention, '<then>');
              forn:
                WriteLn(T, PrintNodeIndention, '<first>');
              else
                WriteLn(T, PrintNodeIndention, '<right>');
            end;
            PrintNodeIndent;
            XMLPrintNode(T, Right);
            PrintNodeUnindent;
            case nodetype of
              ifn:
                WriteLn(T, PrintNodeIndention, '</then>');
              forn:
                WriteLn(T, PrintNodeIndention, '</first>');
              else
                WriteLn(T, PrintNodeIndention, '</right>');
            end;
          end;

        if Assigned(t1) then
          begin
            case nodetype of
              ifn:
                WriteLn(T, PrintNodeIndention, '<else>');
              forn:
                WriteLn(T, PrintNodeIndention, '<last>');
              else
                WriteLn(T, PrintNodeIndention, '<t1>');
            end;
            PrintNodeIndent;
            XMLPrintNode(T, t1);
            PrintNodeUnindent;
            case nodetype of
              ifn:
                WriteLn(T, PrintNodeIndention, '</else>');
              forn:
                WriteLn(T, PrintNodeIndention, '</last>');
              else
                WriteLn(T, PrintNodeIndention, '</t1>');
            end;
          end;

        if Assigned(t2) then
          begin

            if nodetype <> forn then
              begin
                WriteLn(T, PrintNodeIndention, '<loop>');
                PrintNodeIndent;
              end;

            XMLPrintNode(T, t2);

            if nodetype <> forn then
              begin
                PrintNodeUnindent;
                WriteLn(T, PrintNodeIndention, '</loop>');
              end;
          end;

        PrintNodeUnindent;
        WriteLn(T, PrintNodeIndention, '</', nodetype2str[nodetype], '>');
      end;
{$endif DEBUG_NODE_XML}

    function TLoopNode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (loopflags*loopflagsequal=TLoopNode(p).loopflags*loopflagsequal) and
          t1.isequal(TLoopNode(p).t1) and
          t2.isequal(TLoopNode(p).t2);
      end;

{****************************************************************************
                               TWHILEREPEATNODE
*****************************************************************************}

    constructor TWhileRepeatNode.create(l,r:TNode;tab,cn:boolean);
      begin
        inherited create(whilerepeatn,l,r,nil,nil);
        if tab then
          include(loopflags, lnf_testatbegin);
        if cn then
          include(loopflags,lnf_checknegate);
      end;


    function TWhileRepeatNode.pass_typecheck:TNode;
      var
         t:TUnaryNode;
      begin
         result:=nil;
         resultdef:=voidtype;

         TypeCheckPass(left);

         { tp procvar support }
         maybe_call_procvar(left,true);

         {A not node can be removed.}
         if left.nodetype=notn then
           begin
             t:=TUnaryNode(left);
             left:=TUnaryNode(left).left;
             t.left:=nil;
             t.free;
             t := nil;
             {Symdif operator, in case you are wondering:}
             loopflags:=loopflags >< [lnf_checknegate];
           end;
         { loop instruction }
         if Assigned(right) then
           TypeCheckPass(right);
         set_varstate(left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         if not(is_boolean(left.resultdef)) and
           not(is_typeparam(left.resultdef)) then
             inserttypeconv(left,pasbool1type);

         { Give warnings for code that will never be executed for
           while false do }
         if (lnf_testatbegin in loopflags) and
            (left.nodetype=ordconstn) and
            (TOrdConstNode(left).value.uvalue=0) and
            not(nf_internal in left.flags) and
            Assigned(right) then
           CGMessagePos(right.fileinfo,cg_w_unreachable_code);
      end;


    function TWhileRepeatNode.internalsimplify(forinline : boolean) : TNode;
      var
        p: TNode;
      begin
        result:=nil;
        { convert while i>0 do ... dec(i); to if i>0 then repeat ... dec(i) until i=0; ? }
        if (cs_opt_level2 in CurrentSettings.OptimizerSwitches) and
          { while loop? }
          (lnf_testatbegin in loopflags) and not(lnf_checknegate in loopflags) then
          begin
            if ((left.nodetype=gtn) and (TAddNode(left).left.nodetype=loadn) and is_constintnode(TAddNode(left).right) and
              (TOrdConstNode(TAddNode(left).right).value=0)) then
              begin
                p:=GetLastStatement(right);
                if Assigned(p) and (p.nodetype=inlinen) and (TInlineNode(p).inlinenumber=in_dec_x) and
                  TAddNode(left).left.isequal(TCallParaNode(TInlineNode(p).left).left) and
                  not(Assigned(TCallParaNode(TInlineNode(p).left).right)) then
                  begin
                    result:=CIfNode.create_internal(left.getcopy,CWhileRepeatNode.create(left,right,false,true),nil);
                    left:=nil;
                    right:=nil;
                    TWhileRepeatNode(TIfNode(result).right).left.nodetype:=equaln;
                  end;
              end
            else if not(cs_opt_size in CurrentSettings.OptimizerSwitches) and
              (node_complexity(left)<=3) then
              begin
                result:=CIfNode.create_internal(left.getcopy,CWhileRepeatNode.create(left,right,false,false),nil);
                left:=nil;
                right:=nil;
              end;
          end;
      end;


    function TWhileRepeatNode.simplify(forinline : boolean) : TNode;
      begin
        result:=internalsimplify(false);
      end;


{$ifdef prefetchnext}
    type
      PAssignmentQuery = ^TAssignmentQuery;
      TAssignmentQuery = record
        towhat: TNode;
        source: TAssignmentNode;
        statementcount: cardinal;
      end;

    function checkassignment(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        query: PAssignmentQuery absolute arg;
        temp, prederef: TNode;
      begin
        result := fen_norecurse_false;
        if (n.nodetype in [assignn,inlinen,forn,calln,whilerepeatn,casen,ifn]) then
          inc(query^.statementcount);
        { make sure there's something else in the loop besides going to the }
        { next item                                                         }
        if (query^.statementcount > 1) and
           (n.nodetype = assignn) then
          begin
            { skip type conversions of assignment target }
            temp := TAssignmentNode(n).left;
            while (temp.nodetype = typeconvn) do
              temp := TTypeConvNode(temp).left;

            { assignment to x of the while assigned(x) check? }
            if not(temp.isequal(query^.towhat)) then
              exit;

            { right hand side of assignment dereferenced field of }
            { x? (no derefn in case of class)                     }
            temp := TAssignmentNode(n).right;
            while (temp.nodetype = typeconvn) do
              temp := TTypeConvNode(temp).left;
            if (temp.nodetype <> subscriptn) then
              exit;

            prederef := TSubscriptNode(temp).left;
            temp := prederef;
            while (temp.nodetype = typeconvn) do
              temp := TTypeConvNode(temp).left;

            { see tests/test/prefetch1.pas }
            if (temp.nodetype = derefn) then
              temp := TDerefNode(temp).left
            else
              temp := prederef;

            if temp.isequal(query^.towhat) then
              begin
                query^.source := TAssignmentNode(n);
                result := fen_norecurse_true;
               end
          end
        { don't check nodes which can't contain an assignment or whose }
        { final assignment can vary a lot                              }
        else if not(n.nodetype in [calln,inlinen,casen,whilerepeatn,forn]) then
          result := fen_false;
      end;


    function findassignment(where: TNode; towhat: TNode): TAssignmentNode;
      var
        query: TAssignmentQuery;
      begin
        query.towhat := towhat;
        query.source := nil;
        query.statementcount := 0;
        if foreachnodestatic(where,@checkassignment,@query) then
          result := query.source
        else
           result := nil;
      end;
{$endif prefetchnext}


    function TWhileRepeatNode.pass_1 : TNode;
{$ifdef prefetchnext}
      var
         runnernode, prefetchcode: TNode;
         assignmentnode: TAssignmentNode;
         prefetchstatements: TStatementNode;
{$endif prefetchnext}
      begin
         result:=nil;
         expectloc:=LOC_VOID;

         FirstPass(left);
         if CodeGenError then
           exit;

         { loop instruction }
         if Assigned(right) then
           begin
              FirstPass(right);
              if CodeGenError then
                exit;
           end;

{$ifdef prefetchnext}
         { do at the end so all complex typeconversions are already }
         { converted to calln's                                     }
         if (cs_opt_level1 in CurrentSettings.OptimizerSwitches) and
            (lnf_testatbegin in loopflags) then
           begin
             { get first component of the while check }
             runnernode := left;
             while (runnernode.nodetype in [andn,orn,notn,xorn,typeconvn]) do
               runnernode := TUnaryNode(runnernode).left;
             { is it an assigned(x) check? }
             if ((runnernode.nodetype = inlinen) and
                 (TInlineNode(runnernode).inlinenumber = in_assigned_x)) or
                ((runnernode.nodetype = unequaln) and
                 (TAddNode(runnernode).right.nodetype = niln)) then
               begin
                 runnernode := TUnaryNode(runnernode).left;
                 { in case of in_assigned_x, there's a callparan in between }
                 if (runnernode.nodetype = callparan) then
                   runnernode := TCallParaNode(runnernode).left;
                 while (runnernode.nodetype = typeconvn) do
                   runnernode := TTypeConvNode(runnernode).left;
                 { is there an "x := x(^).somefield"? }
                 assignmentnode := findassignment(right,runnernode);
                 if Assigned(assignmentnode) then
                   begin
                     prefetchcode := internalstatements(prefetchstatements);
                     addstatement(prefetchstatements,geninlinenode(in_prefetch_var,false,
                       CDerefNode.create(CTypeConvNode.create(assignmentnode.right.getcopy,voidpointertype))));
                     addstatement(prefetchstatements,right);
                     right := prefetchcode;
                     TypeCheckPass(right);
                   end;
               end;
           end;
{$endif prefetchnext}
      end;

{$ifdef state_tracking}
    function TWhileRepeatNode.track_state_pass(exec_known:boolean):boolean;

    var condition:TNode;
        code:TNode;
        done:boolean;
        value:boolean;
        change:boolean;
        firsttest:boolean;
        factval:TNode;

    begin
        track_state_pass:=false;
        done:=false;
        firsttest:=true;
        {For repeat until statements, first do a pass through the code.}
        if not(lnf_testatbegin in flags) then
            begin
                code:=right.getcopy;
                if code.track_state_pass(exec_known) then
                    track_state_pass:=true;
                code.free;
                code := nil;
            end;
        repeat
            condition:=left.getcopy;
            code:=right.getcopy;
            change:=condition.track_state_pass(exec_known);
            factval:=aktstate.find_fact(left);
            if factval<>nil then
                begin
                    condition.free;
                    condition:=factval.getcopy;
                    change:=true;
                end;
            if change then
                begin
                    track_state_pass:=true;
                    {Force new resultdef pass.}
                    condition.resultdef:=nil;
                    DoTypeCheckPass(condition);
                end;
            if is_constboolnode(condition) then
                begin
                    {Try to turn a while loop into a repeat loop.}
                    if firsttest then
                        exclude(flags,testatbegin);
                    value:=(TOrdConstNode(condition).value<>0) xor checknegate;
                    if value then
                        begin
                            if code.track_state_pass(exec_known) then
                                track_state_pass:=true;
                        end
                    else
                        done:=true;
                end
            else
                begin
                    {Remove any modified variables from the state.}
                    code.track_state_pass(false);
                    done:=true;
                end;
            code.free;
            code := nil;
            condition.free;
            condition := nil;
            firsttest:=false;
        until done;
        {The loop condition is also known, for example:
         while i<10 do
            begin
                ...
            end;

         When the loop is done, we do know that i<10 = false.
        }
        condition:=left.getcopy;
        if condition.track_state_pass(exec_known) then
            begin
                track_state_pass:=true;
                {Force new resultdef pass.}
                condition.resultdef:=nil;
                DoTypeCheckPass(condition);
            end;
        if not is_constboolnode(condition) then
            aktstate.store_fact(condition,
             COrdConstNode.create(byte(checknegate),pasbool1type,true))
        else
            condition.free; // no nil needed
    end;
{$endif}

{*****************************************************************************
                               TIFNODE
*****************************************************************************}

    constructor TIfNode.create(l,r,_t1 : TNode);
      begin
         inherited create(ifn,l,r,_t1,nil);
      end;


    constructor TIfNode.create_internal(l,r,_t1 : TNode);
      begin
        create(l,r,_t1);
        include(flags,nf_internal);
      end;


  {$if ((defined(i386)) or (defined(x86_64))) or (defined(aarch64))}
    {$define HAS_MINMAX_INTRINSICS}
  {$endif defined(i386) or defined(x86_64) or defined(xtensa) or defined(aarch64)}


    function TIfNode.internalsimplify(warn: boolean) : TNode;
{$if defined(HAS_MINMAX_INTRINSICS)}
      var
        thenstmnt, elsestmnt: TNode;
        in_nr: TInlineNumber;
        paratype: TDef;
{$endif defined(HAS_MINMAX_INTRINSICS)}
      begin
        result:=nil;
        { optimize constant expressions }
        if (left.nodetype=ordconstn) then
          begin
             if TOrdConstNode(left).value.uvalue<>0 then
               begin
                  if Assigned(right) then
                    result:=right
                  else
                    result:=CNothingNode.create;
                  right:=nil;
                  if warn and Assigned(t1) and not(nf_internal in left.flags) then
                    CGMessagePos(t1.fileinfo,cg_w_unreachable_code);
               end
             else
               begin
                  if Assigned(t1) then
                    result:=t1
                  else
                    result:=CNothingNode.create;
                  t1:=nil;
                  if warn and Assigned(right) and not(nf_internal in left.flags) then
                    CGMessagePos(right.fileinfo,cg_w_unreachable_code);
               end;
          end;
{$if defined(HAS_MINMAX_INTRINSICS)}
        { use min/max intrinsic?
          convert (with <op> being <, >, >=, <=
          if a <op> b then
            x:=a
          else
            x:=b;

          and

          if a <op> b then
            x:=a;

          into appropriate min/max intrinsics

          }
        elsestmnt:=nil;
        in_nr:=Default(TInlineNumber);
        if (cs_opt_level2 in CurrentSettings.OptimizerSwitches) and
           (left.nodetype in [gtn,gten,ltn,lten]) and IsSingleStatement(right,thenstmnt) and
           ((t1=nil) or IsSingleStatement(t1,elsestmnt)) and
          (thenstmnt.nodetype=assignn) and ((t1=nil) or (elsestmnt.nodetype=assignn)) and
          not(might_have_sideeffects(left)) and
          ((t1=nil) or TAssignmentNode(thenstmnt).left.isequal(TAssignmentNode(elsestmnt).left)) and
{$if defined(i386) or defined(x86_64)}
{$ifdef i386}
          (((CurrentSettings.FPUType>=fpu_sse) and is_single(TAssignmentNode(thenstmnt).left.resultdef)) or
           ((CurrentSettings.FPUType>=fpu_sse2) and is_double(TAssignmentNode(thenstmnt).left.resultdef)) or
           ((CPUX86_HAS_CMOV in cpu_capabilities[CurrentSettings.CPUType]) and is_32bitint(TAssignmentNode(thenstmnt).left.resultdef))
          ) and
{$else i386}
          (is_single(TAssignmentNode(thenstmnt).left.resultdef) or
           is_double(TAssignmentNode(thenstmnt).left.resultdef) or
           is_32bitint(TAssignmentNode(thenstmnt).left.resultdef) or
           is_64bitint(TAssignmentNode(thenstmnt).left.resultdef)
          ) and
{$endif i386}
{$endif defined(i386) or defined(x86_64)}
{$if defined(aarch64)}
          (is_single(TAssignmentNode(thenstmnt).left.resultdef) or is_double(TAssignmentNode(thenstmnt).left.resultdef) or
           is_32bitint(TAssignmentNode(thenstmnt).left.resultdef) or is_64bitint(TAssignmentNode(thenstmnt).left.resultdef)) and
{$endif defined(aarch64)}
          (
          { the right size of the assignment in the then clause must either }

          { equal to the left ... }
           (TAssignmentNode(thenstmnt).right.isequal(TAddNode(left).left) and

            { ... and the else clause must be either not exist                 }
            { and the left side of the assignment in the then clause must be   }
            {  equal to the right operand of the comparison operator           }
            (
              ((t1=nil) and (TAssignmentNode(thenstmnt).left.isequal(TAddNode(left).right))) or

              { or the else clause exists and the right side of the assignment in the else clause }
              { must be equal to the right side of the comparison operator                        }
              (Assigned(elsestmnt) and TAssignmentNode(elsestmnt).right.isequal(TAddNode(left).right)))
           ) or
           { ... or right operand of the comparison operator }

            (TAssignmentNode(thenstmnt).right.isequal(TAddNode(left).right) and
            { ... and the else clause must be either not exist                 }
            { and the left side of the assignment in the then clause must be   }
            {  equal to the left operand of the comparison operator            }
             (
              ((t1=nil) and (TAssignmentNode(thenstmnt).left.isequal(TAddNode(left).left))) or

              { or the else clause exists and the right side of the assignment in the else clause }
              { must be equal to the left side of the comparison operator                         }
              (Assigned(elsestmnt) and TAssignmentNode(elsestmnt).right.isequal(TAddNode(left).left))
             )
           )
          ) then
          begin
            paratype:=TAssignmentNode(thenstmnt).left.resultdef;
            if ((left.nodetype in [gtn,gten]) and
              TAssignmentNode(thenstmnt).right.isequal(TAddNode(left).left)) or
              ((left.nodetype in [ltn,lten]) and
              TAssignmentNode(thenstmnt).right.isequal(TAddNode(left).right)) then
              begin
                if is_double(paratype) then
                  in_nr:=in_max_double
                else if is_single(paratype) then
                  in_nr:=in_max_single
                else if is_u32bitint(paratype) then
                  in_nr:=in_max_dword
                else if is_s32bitint(paratype) then
                  in_nr:=in_max_longint
                else if is_u64bitint(paratype) then
                  in_nr:=in_max_qword
                else if is_s64bitint(paratype) then
                  in_nr:=in_max_int64;
              end
            else
              begin
                if is_double(paratype) then
                  in_nr:=in_min_double
                else if is_single(paratype) then
                  in_nr:=in_min_single
                else if is_u32bitint(paratype) then
                  in_nr:=in_min_dword
                else if is_s32bitint(paratype) then
                  in_nr:=in_min_longint
                else if is_u64bitint(paratype) then
                  in_nr:=in_min_qword
                else if is_s64bitint(paratype) then
                  in_nr:=in_min_int64;
              end;
            { for inline nodes, the first parameter is the last one in the linked list

              Due to the defined behaviour for the min/max intrinsics that in case of a NaN
              the second parameter is taken, we have to put the else part into the second parameter
              thus pass it to the first callparanode call }
            if t1=nil then
              Result:=CAssignmentNode.create_internal(TAssignmentNode(thenstmnt).left.getcopy,
                CInlineNode.create(in_nr,false,CCallParaNode.create(TAssignmentNode(thenstmnt).left.getcopy,
                      CCallParaNode.create(TAssignmentNode(thenstmnt).right.getcopy,nil)))
                )
            else
              Result:=CAssignmentNode.create_internal(TAssignmentNode(thenstmnt).left.getcopy,
                CInlineNode.create(in_nr,false,CCallParaNode.create(TAssignmentNode(elsestmnt).right.getcopy,
                      CCallParaNode.create(TAssignmentNode(thenstmnt).right.getcopy,nil)))
                );
            node_reset_pass1_write(Result);
          end;
{$endif defined(HAS_MINMAX_INTRINSICS)}
      end;


    function TIfNode.simplify(forinline : boolean) : TNode;
      begin
        result:=internalsimplify(false);
      end;


    function TIfNode.pass_typecheck:TNode;
      begin
         result:=nil;
         resultdef:=voidtype;

         TypeCheckPass(left);

         { tp procvar support }
         maybe_call_procvar(left,true);

         { if path }
         if Assigned(right) then
           TypeCheckPass(right);
         { else path }
         if Assigned(t1) then
           TypeCheckPass(t1);
         set_varstate(left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         if not(is_boolean(left.resultdef)) and
           not(is_typeparam(left.resultdef)) then
             inserttypeconv(left,pasbool1type);

         result:=internalsimplify(not(nf_internal in flags));
      end;


    function TIfNode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_VOID;
         FirstPass(left);

         { if path }
         if Assigned(right) then
           FirstPass(right);

         { else path }
         if Assigned(t1) then
           FirstPass(t1);

         { leave if we've got an error in one of the paths }

         if CodeGenError then
           exit;
      end;


{*****************************************************************************
                              TFORNODE
*****************************************************************************}

    constructor TForNode.create(l,r,_t1,_t2 : TNode;back : boolean);

      begin
         inherited create(forn,l,r,_t1,_t2);
         if back then
           include(loopflags,lnf_backward);
         include(loopflags,lnf_testatbegin);
      end;

    destructor TForNode.Destroy;
      begin
         loopiteration.free;
         loopiteration := nil;
         inherited Destroy;
      end;

    function TForNode.simplify(forinline : boolean) : TNode;
      begin
        result:=nil;
        { Can we spare the first comparison? }
        if (t1.nodetype=ordconstn) and
           (right.nodetype=ordconstn) and
           (
            (
             (lnf_backward in loopflags) and
             (TOrdConstNode(right).value>=TOrdConstNode(t1).value)
            ) or
            (
              not(lnf_backward in loopflags) and
              (TOrdConstNode(right).value<=TOrdConstNode(t1).value)
            )
           ) then
          exclude(loopflags,lnf_testatbegin);

        if (t1.nodetype=ordconstn) and
           (right.nodetype=ordconstn) and
           (
            (
             (lnf_backward in loopflags) and
             (TOrdConstNode(right).value<TOrdConstNode(t1).value)
            ) or
            (
              not(lnf_backward in loopflags) and
              (TOrdConstNode(right).value>TOrdConstNode(t1).value)
            )
           ) then
          result:=CNothingNode.create;
      end;


    function TForNode.pass_typecheck:TNode;
      var
        res : TNode;
        rangedef: TDef;
      begin
         result:=nil;
         resultdef:=voidtype;

         { process the loopvar, from and to, varstates are already set }
         TypeCheckPass(left);
         TypeCheckPass(right);
         TypeCheckPass(t1);

         set_varstate(left,vs_written,[]);

         { Make sure that the loop var and the
           from and to values are compatible types }
         if not(m_iso in CurrentSettings.ModeSwitches) then
           rangedef:=left.resultdef
         else
           rangedef:=get_iso_range_type(left.resultdef);

         check_ranges(right.fileinfo,right,rangedef);
         inserttypeconv(right,rangedef);

         check_ranges(t1.fileinfo,t1,rangedef);
         inserttypeconv(t1,rangedef);

         if Assigned(t2) then
           TypeCheckPass(t2);
         result:=simplify(false);

         { loop unrolling }
         if not(Assigned(result)) and
           (cs_opt_loopunroll in CurrentSettings.OptimizerSwitches) and
           Assigned(t2) and
           { statements must be error free }
           not(tnf_error in t2.transientflags) then
           begin
             TypeCheckPass(t2);
             res:=t2.simplify(false);
             if Assigned(res) then
               t2:=res;
             res:=unroll_loop(self);
             if Assigned(res) then
               begin
                 TypeCheckPass(res);
                 result:=res;
                 exit;
               end;
           end;

      end;


    function TForNode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_VOID;

        FirstPass(left);
        FirstPass(right);
        FirstPass(t1);

        if Assigned(t2) then
          FirstPass(t2);
      end;


    function TForNode.makewhileloop : TNode;
      var
        ifblock,loopblock : TBlockNode;
        ifstatements,statements,loopstatements : TStatementNode;
        fromtemp,totemp : TTempCreateNode;
        do_loopvar_at_end : Boolean;
        { if the lower and/or upper bound are variable, we need a surrounding if }
        needsifblock : Boolean;
        cond : TNodeType;
        fromexpr : TNode;
        toexpr, leftcopy: TNode;
        { if the upper bound is not constant, it must be store in a temp initially }
        usetotemp : boolean;
        { if the lower bound is not constant, it must be store in a temp before calculating the upper bound }
        usefromtemp : boolean;
        storefilepos: TFilePosInfo;
        countermin, countermax: TConstExprInt;

      procedure iterate_counter(var s : TStatementNode;fw : boolean);
        var
          leftcopy: TNode;
        begin
          { get rid of nf_write etc. as the left node is now only read }
          leftcopy:=left.getcopy;
          node_reset_flags(leftcopy,[nf_modify,nf_write],[tnf_pass1_done]);

          if fw then
            addstatement(s,
              CAssignmentNode.create_internal(left.getcopy,CInlineNode.createintern(in_succ_x,false,leftcopy)))
          else
            addstatement(s,
              CAssignmentNode.create_internal(left.getcopy,CInlineNode.createintern(in_pred_x,false,leftcopy)));
        end;

      function iterate_counter_func(arg : TNode;fw : boolean) : TNode;
        begin
          if fw then
            result:=CInlineNode.createintern(in_succ_x,false,arg)
          else
            result:=CInlineNode.createintern(in_pred_x,false,arg);
        end;

      begin
        result:=nil;
        totemp:=nil;
        fromtemp:=nil;
        storefilepos:=CurrentFilePos;
        CurrentFilePos:=fileinfo;

        case left.resultdef.typ of
          enumdef:
            begin
              countermin:=TEnumDef(left.resultdef).min;
              countermax:=TEnumDef(left.resultdef).max;
            end;
          orddef:
            begin
              countermin:=TOrdDef(left.resultdef).low;
              countermax:=TOrdDef(left.resultdef).high;
            end;
          else
            InternalError(2020012601);
        end;

        { check if we can pred/succ the loop var at the end }
        do_loopvar_at_end:=(lnf_dont_mind_loopvar_on_exit in loopflags) and
          is_constnode(t1) and
          { we cannot test at the end after the pred/succ if the to value is equal to the max./min. value of the counter variable
            because we either get an overflow/underflow or the compiler removes the check as it never can be true }

          { checking just the min./max. value depending on the pure size of the counter does not work as the check might
            get optimized away
          not(not(lnf_backward in loopflags) and not(is_signed(left.resultdef)) and (get_ordinal_value(t1)=((1 shl (left.resultdef.size*8))-1))) and
          not(not(lnf_backward in loopflags) and is_signed(left.resultdef) and (get_ordinal_value(t1)=((1 shl (left.resultdef.size*8-1))-1))) and
          not((lnf_backward in loopflags) and not(is_signed(left.resultdef)) and (get_ordinal_value(t1)=0)) and
          not((lnf_backward in loopflags) and is_signed(left.resultdef) and (get_ordinal_value(t1)=(-Tconstexprint(1 shl (left.resultdef.size*8-1))))) and
          }

          not(not(lnf_backward in loopflags) and (get_ordinal_value(t1)=countermax)) and
          not((lnf_backward in loopflags) and (get_ordinal_value(t1)=countermin)) and
          { neither might the for loop contain a continue statement as continue in a while loop would skip the increment at the end
            of the loop, this could be overcome by replacing the continue statement with an pred/succ; continue sequence }
          not(has_node_of_type(t2,[continuen])) and
          { if the loop is unrolled and there is a jump into the loop,
            then we can't do the trick with incrementing the loop var only at the
            end
          }
          not(Assigned(entrylabel));

        needsifblock:=not(is_constnode(right)) or not(is_constnode(t1));

        { convert the for loop into a while loop }
        result:=internalstatements(statements);
        ifblock:=internalstatements(ifstatements);
        loopblock:=internalstatements(loopstatements);

        usefromtemp:=(might_have_sideeffects(t1) and not(is_const(right))) or (node_complexity(right)>1);
        usetotemp:=not(is_const(t1));

        if needsifblock then
          begin
            { do not generate a temp. for the from node, if it is a const, it can be copied directly since
              no side effect might change it }
            if usefromtemp then
              begin
                fromtemp:=CTempCreateNode.create(right.resultdef,right.resultdef.size,tt_persistent,true);
                { the if block might be optimized out, so we put the deletetempnode after the if-block, however,
                  this causes a long life time of the fromtemp. If the final regsync is left away, the reg. allocator
                  figures out the needed life time. As their are no loops involved between the uses of the fromtemp,
                  this does no hurt }
                fromtemp.includetempflag(ti_no_final_regsync);
                addstatement(statements,fromtemp);
                { while it would be beneficial to fold the initial reverse succ/pred into this assignment, this is
                  not possible because it might wrap around and the if check later on goes wrong }
                addstatement(statements,CAssignmentNode.create_internal(CTempRefNode.create(fromtemp),right.getcopy));
              end;

            if usetotemp then
              begin
                totemp:=CTempCreateNode.create(t1.resultdef,t1.resultdef.size,tt_persistent,true);
                addstatement(statements,totemp);
                addstatement(statements,CAssignmentNode.create_internal(CTempRefNode.create(totemp),t1.getcopy));
              end;

            if usefromtemp then
              begin
                addstatement(ifstatements,CAssignmentNode.create_internal(left.getcopy,CTempRefNode.create(fromtemp)));
                if not(do_loopvar_at_end) then
                  iterate_counter(ifstatements,lnf_backward in loopflags);
              end
            else
              begin
                if not(do_loopvar_at_end) then
                  addstatement(ifstatements,CAssignmentNode.create_internal(left.getcopy,
                    iterate_counter_func(right.getcopy,lnf_backward in loopflags)))
                else
                  addstatement(ifstatements,CAssignmentNode.create_internal(left.getcopy,right.getcopy));
              end;
          end
        else
          begin
            if not(do_loopvar_at_end) then
              addstatement(ifstatements,CAssignmentNode.create_internal(left.getcopy,
                iterate_counter_func(right.getcopy,lnf_backward in loopflags)))
            else
              addstatement(ifstatements,CAssignmentNode.create_internal(left.getcopy,right.getcopy));
          end;

        if Assigned(entrylabel) then
          addstatement(ifstatements,CGotoNode.create(TLabelNode(entrylabel).labsym));

        if not(do_loopvar_at_end) then
          iterate_counter(loopstatements,not(lnf_backward in loopflags));

        { avoid copying t2, it is used only once and it might be big }
        addstatement(loopstatements,t2);
        t2:=nil;

        if do_loopvar_at_end then
         iterate_counter(loopstatements,not(lnf_backward in loopflags));

        if do_loopvar_at_end then
          begin
            if lnf_backward in loopflags then
              cond:=ltn
            else
              cond:=gtn;
          end
        else
          begin
            if lnf_backward in loopflags then
              cond:=lten
            else
              cond:=gten;
          end;

        { get rid of nf_write etc. as the left node is now only read }
        leftcopy:=left.getcopy;
        node_reset_flags(leftcopy,[nf_modify,nf_write],[tnf_pass1_done]);

        if needsifblock then
          begin
            if usetotemp then
              toexpr:=CTempRefNode.create(totemp)
            else
              toexpr:=t1.getcopy;

            { checking against zero might improve the generated assembler,
              doing this transformation for other values is normally not beneficial }
            if do_loopvar_at_end and (lnf_backward in loopflags) and is_constintnode(toexpr) and (TOrdConstNode(toexpr).value=1) and
              (countermin<TOrdConstNode(toexpr).value) then
              begin
                TOrdConstNode(toexpr).value:=TOrdConstNode(toexpr).value-1;
                addstatement(ifstatements,CWhileRepeatNode.create(CAddNode.create_internal(equaln,leftcopy,toexpr),loopblock,false,true))
              end
            else
              addstatement(ifstatements,CWhileRepeatNode.create(CAddNode.create_internal(cond,leftcopy,toexpr),loopblock,false,true));

            if usefromtemp then
              fromexpr:=CTempRefNode.create(fromtemp)
            else
              fromexpr:=right.getcopy;

            if usetotemp then
              toexpr:=CTempRefNode.create(totemp)
            else
              toexpr:=t1.getcopy;

            if lnf_backward in loopflags then
              addstatement(statements,CIfNode.create(CAddNode.create_internal(gten,
                fromexpr,toexpr),ifblock,nil))
            else
              addstatement(statements,CIfNode.create(CAddNode.create_internal(lten,
                fromexpr,toexpr),ifblock,nil));

            if usetotemp then
              addstatement(statements,CTempDeleteNode.create(totemp));
            if usefromtemp then
              addstatement(statements,CTempDeleteNode.create(fromtemp));
          end
        else
          begin
            { is a simple comparison for equality sufficient? }
            if do_loopvar_at_end and (lnf_backward in loopflags) and (lnf_counter_not_used in loopflags) then
              addstatement(ifstatements,CWhileRepeatNode.create(CAddNode.create_internal(equaln,leftcopy,
                CAddNode.create_internal(subn,t1.getcopy,COrdConstNode.create(1,t1.resultdef,false))),loopblock,false,true))
            else
              addstatement(ifstatements,CWhileRepeatNode.create(CAddNode.create_internal(cond,leftcopy,t1.getcopy),loopblock,false,true));
            addstatement(statements,ifblock);
          end;
        CurrentFilePos:=storefilepos;
      end;


{*****************************************************************************
                             TEXITNODE
*****************************************************************************}

    constructor TExitNode.create(l:TNode);
      begin
        inherited create(exitn,l);
        if Assigned(left) then
          begin
            { add assignment to funcretsym }
            left:=CTypeConvNode.create(left,CurrentProcInfo.procdef.returndef);
            left:=CAssignmentNode.create(
              CLoadNode.create(CurrentProcInfo.procdef.funcretsym,CurrentProcInfo.procdef.funcretsym.owner),
              left);
          end;
      end;


    constructor TExitNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
      end;


    procedure TExitNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
      end;


    function TExitNode.pass_typecheck:TNode;
      var
        newstatement : TStatementNode;
        ressym: TSym;
        resdef: TDef;
      begin
        result:=nil;
        newstatement:=nil;
        if Assigned(left) then
          begin
             result:=internalstatements(newstatement);
             addstatement(newstatement,left);
             left:=nil;
          end;
        { if the function result has been migrated to the parentfpstruct,
          we have to load it back to the original location (from which the
          code generator will load it into the function result location),
          because the code to this that we add in tnodeutils.wrap_proc_body()
          gets inserted before the exit label to which this node will jump }

        if Assigned(result) then
          begin
            addstatement(newstatement,self.getcopy);
            { ensure we don't insert the function result loading code again for
              this node }
            include(newstatement.left.flags,nf_internal);
          end;
        resultdef:=voidtype;
      end;


    function TExitNode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_VOID;
         if Assigned(left) then
           InternalError(2011052801);
      end;


{*****************************************************************************
                             TBREAKNODE
*****************************************************************************}

    constructor TBreakNode.create;

      begin
        inherited create(breakn);
      end;


    function TBreakNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=voidtype;
      end;


    function TBreakNode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_VOID;
      end;


{*****************************************************************************
                             TCONTINUENODE
*****************************************************************************}

    constructor TContinueNode.create;
      begin
        inherited create(continuen);
      end;


    function TContinueNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=voidtype;
      end;


    function TContinueNode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_VOID;
      end;


{*****************************************************************************
                             TGOTONODE
*****************************************************************************}

    constructor TGotoNode.create(p : TLabelSym);
      begin
        inherited create(goton);
        exceptionblock:=Current_ExceptBlock;
        labelnode:=nil;
        labelsym:=p;
      end;


    constructor TGotoNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        labelnodeidx:=ppufile.GetLongInt;
        exceptionblock:=ppufile.GetByte;
      end;


    procedure TGotoNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        labelnodeidx:=labelnode.ppuidx;
        ppufile.PutLongInt(labelnodeidx);
        ppufile.PutByte(exceptionblock);
      end;


    procedure TGotoNode.buildderefimpl;
      begin
        inherited buildderefimpl;
      end;


    procedure TGotoNode.derefimpl;
      begin
        inherited derefimpl;
      end;


    procedure TGotoNode.resolveppuidx;
      begin
        labelnode:=TLabelNode(nodeppuidxget(labelnodeidx));
        if labelnode.nodetype<>labeln then
          InternalError(200809021);
      end;


    function TGotoNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=voidtype;
      end;


    function TGotoNode.pass_1 : TNode;
      var
        p2 : TProcInfo;
      begin
        result:=nil;
        expectloc:=LOC_VOID;

        { The labelnode can already be set when
          this node was copied }
        if not(Assigned(labelnode)) then
          begin
            { inner procedure goto? }
            if Assigned(labelsym.code) and
              ((Assigned(labelsym.owner) and (CurrentProcInfo.procdef.parast.symtablelevel=labelsym.owner.symtablelevel)) or
              { generated by the optimizer? }
               not(Assigned(labelsym.owner))) then
              labelnode:=TLabelNode(labelsym.code)
            else if ((m_non_local_goto in CurrentSettings.ModeSwitches) and
              Assigned(labelsym.owner)) or
              { nested exits don't need the non local goto switch }
              (labelsym.realname='$nestedexit') then
              begin
                if CurrentProcInfo.procdef.parast.symtablelevel>=labelsym.owner.symtablelevel then
                  begin
                    { don't mess with the exception blocks, global gotos in/out side exception blocks are not allowed }
                    if exceptionblock>0 then
                      CGMessage(cg_e_goto_inout_of_exception_block);

                    { goto across procedures using exception?
                      this is not allowed because we cannot
                      easily unwind the exception frame
                      stack
                    }
                    p2:=CurrentProcInfo;
                    while true do
                      begin
                        if ((cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and ((p2.flags*[pi_needs_implicit_finally,pi_has_implicit_finally])<>[])) or
                        ((p2.flags*[pi_uses_exceptions])<>[]) then
                          Message(cg_e_goto_across_procedures_with_exceptions_not_allowed);
                        if labelsym.owner=p2.procdef.localst then
                          break;
                        p2:=p2.parent
                      end;

                    if Assigned(labelsym.jumpbuf) then
                      begin
                        result:=CCallNode.createintern('fpc_longjmp',
                          CCallParaNode.create(COrdConstNode.create(1,sinttype,true),
                          CCallParaNode.create(CLoadNode.create(labelsym.jumpbuf,labelsym.jumpbuf.owner),
                        nil)));
                      end
                    else
                      CGMessage1(cg_e_goto_label_not_found,labelsym.realname);
                  end
                else
                  CGMessagePos(self.fileinfo,cg_e_interprocedural_goto_only_to_outer_scope_allowed);
              end
            else
              CGMessage1(cg_e_goto_label_not_found,labelsym.realname);
          end;

        { check if we don't mess with exception blocks }
        if Assigned(labelnode) and
           (exceptionblock<>labelnode.exceptionblock) then
          CGMessage(cg_e_goto_inout_of_exception_block);
      end;


   function TGotoNode.dogetcopy : TNode;
     var
       p : TGotoNode;
     begin
        p:=TGotoNode(inherited dogetcopy);
        p.exceptionblock:=exceptionblock;

        { generate labelnode if not done yet }
        if not(Assigned(labelnode)) then
          begin
            if Assigned(labelsym) and Assigned(labelsym.code) then
              labelnode:=TLabelNode(labelsym.code)
          end;

        p.labelsym:=labelsym;
        { do not copy the label node here as we do not know if the label node is part of the tree or not,
          this will be fixed after the copying in node.setuplabelnode: if the labelnode has copiedto set,
          labelnode of the goto node is update }
        if Assigned(labelnode) then
          p.labelnode:=labelnode
        else
          begin
            { don't trigger IE when there was already an error, i.e. the
              label is not defined. See tw11763 (PFV) }
            if (ErrorCount=0) and
            { don't trigger IE if it's a global goto }
               ((Assigned(labelsym.owner) and (CurrentProcInfo.procdef.parast.symtablelevel=labelsym.owner.symtablelevel)) or
               not(Assigned(labelsym.owner))) then
              InternalError(200610291);
          end;
        result:=p;
     end;


    function TGotoNode.docompare(p: TNode): boolean;
      begin
        docompare := false;
      end;


{*****************************************************************************
                             TLABELNODE
*****************************************************************************}

    constructor TLabelNode.create(l:TNode;alabsym:TLabelSym);
      begin
        inherited create(labeln);
        exceptionblock:=Current_ExceptBlock;
        labsym:=alabsym;
        { Register labelnode in labelsym }
        labsym.code:=self;
      end;


    constructor TLabelNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        exceptionblock:=ppufile.GetByte;
      end;


    destructor TLabelNode.Destroy;
      begin
        if Assigned(labsym) then
          begin
            if not Assigned(labsym.Owner) then
              labsym.Free // Free labelsym if it has no owner
            else
              if labsym.code=pointer(self) then
                begin
                  { Remove reference in labelsym, this is to prevent
                    goto's to this label }
                  labsym.code:=nil;
                end;
          end;
        inherited Destroy;
      end;


    procedure TLabelNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutByte(exceptionblock);
      end;


    procedure TLabelNode.buildderefimpl;
      begin
        inherited buildderefimpl;
      end;


    procedure TLabelNode.derefimpl;
      begin
        inherited derefimpl;
      end;


    function TLabelNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=voidtype;
      end;


    function TLabelNode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_VOID;

        if not (nf_internal in flags) then
          include(CurrentProcInfo.flags,pi_has_label);

        if (m_non_local_goto in CurrentSettings.ModeSwitches) and
            { the owner can be Nil for internal labels }
            Assigned(labsym.owner) and
          (CurrentProcInfo.procdef.parast.symtablelevel<>labsym.owner.symtablelevel) then
          CGMessage(cg_e_labels_cannot_defined_outside_declaration_scope)
      end;


   function TLabelNode.dogetcopy : TNode;
     begin
       if not(Assigned(copiedto)) then
         copiedto:=TLabelNode(inherited dogetcopy);
       copiedto.exceptionblock:=exceptionblock;

       result:=copiedto;
     end;


    function TLabelNode.docompare(p: TNode): boolean;
      begin
        docompare := false;
      end;


{*****************************************************************************
                            TRAISENODE
*****************************************************************************}

    constructor TRaiseNode.create(l,taddr,tframe:TNode);
      begin
         inherited create(raisen,l,taddr,tframe);
      end;


    function TRaiseNode.pass_typecheck:TNode;
      begin
         result:=nil;
         resultdef:=voidtype;
         if Assigned(left) then
           begin
             { first para must be a _class_ }
             TypeCheckPass(left);
             set_varstate(left,vs_read,[vsf_must_be_valid]);
             if CodeGenError then
              exit;
             if not is_class(left.resultdef) and
                not is_javaclass(left.resultdef) then
               CGMessage1(type_e_class_type_expected,left.resultdef.typename);
             { insert needed typeconvs for addr,frame }
             if Assigned(right) then
               begin
                 { addr }
                 TypeCheckPass(right);
                 set_varstate(right,vs_read,[vsf_must_be_valid]);
                 inserttypeconv(right,voidcodepointertype);

                 { frame }
                 if Assigned(third) then
                  begin
                    TypeCheckPass(third);
                    set_varstate(third,vs_read,[vsf_must_be_valid]);
                    inserttypeconv(third,voidpointertype);
                  end;
               end;
           end;
      end;


    function TRaiseNode.pass_1 : TNode;
      var
        statements : TStatementNode;
        current_addr : TLabelNode;
        raisenode : TCallNode;
      begin
        result:=internalstatements(statements);

        if Assigned(left) then
          begin
            { first para must be a class }
            FirstPass(left);
            { insert needed typeconvs for addr,frame }
            if Assigned(right) then
              begin
                { addr }
                FirstPass(right);
                { frame }
                if Assigned(third) then
                  FirstPass(third)
                else
                  third:=CPointerConstNode.Create(0,voidpointertype);
              end
            else
              begin
                third:=CInlineNode.create(in_get_frame,false,nil);
                current_addr:=CLabelNode.create(CNothingNode.create,CLabelSym.create('$raiseaddr'));
                include(current_addr.flags,nf_internal);
                addstatement(statements,current_addr);
                right:=CAddrNode.create(CLoadNode.create(current_addr.labsym,current_addr.labsym.owner));

                { raise address off by one so we are for sure inside the action area for the raise }
                if tf_use_psabieh in TargetInfo.flags then
                  right:=CAddNode.create_internal(addn,right,COrdConstNode.create(1,sizesinttype,false));
              end;

            raisenode:=CCallNode.createintern('fpc_raiseexception',
              CCallParaNode.create(third,
              CCallParaNode.create(right,
              CCallParaNode.create(left,nil)))
              );
            include(raisenode.callnodeflags,cnf_call_never_returns);
            addstatement(statements,raisenode);
          end
        else
          begin
            addstatement(statements,CCallNode.createintern('fpc_popaddrstack',nil));
            raisenode:=CCallNode.createintern('fpc_reraise',nil);
            include(raisenode.callnodeflags,cnf_call_never_returns);
            addstatement(statements,raisenode);
          end;
        left:=nil;
        right:=nil;
        third:=nil;
      end;

{*****************************************************************************
                             TTRYEXCEPTNODE
*****************************************************************************}

    constructor TTryExceptNode.create(l,r,_t1 : TNode);
      begin
         inherited create(tryexceptn,l,r,_t1,nil);
      end;


    function TTryExceptNode.pass_typecheck:TNode;
      begin
        result:=nil;
        TypeCheckPass(left);
        { on statements }
        if Assigned(right) then
          TypeCheckPass(right);
        { else block }
        if Assigned(t1) then
          TypeCheckPass(t1);
        resultdef:=voidtype;
      end;


    function TTryExceptNode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_VOID;
        FirstPass(left);
        { on statements }
        if Assigned(right) then
          FirstPass(right);
        { else block }
        if Assigned(t1) then
          FirstPass(t1);

        include(CurrentProcInfo.flags,pi_do_call);
        include(CurrentProcInfo.flags,pi_uses_exceptions);

        adjust_estimated_stack_size;
      end;


    function TTryExceptNode.simplify(forinline: boolean): TNode;
      begin
        result:=nil;
        { empty try -> can never raise exception -> do nothing }
        if has_no_code(left) then
          result:=CNothingNode.create;
      end;


    procedure TTryExceptNode.adjust_estimated_stack_size;
      begin
        inc(CurrentProcInfo.estimatedtempsize,rec_jmp_buf.size*2);
      end;


{*****************************************************************************
                           TTRYFINALLYNODE
*****************************************************************************}

    constructor TTryFinallyNode.create(l,r:TNode);
      begin
        inherited create(tryfinallyn,l,r,nil);
        third:=nil;
        implicitframe:=false;
      end;


    constructor TTryFinallyNode.create_implicit(l,r:TNode);
      begin
        inherited create(tryfinallyn,l,r,nil);
        third:=nil;
        implicitframe:=true;
      end;


    function TTryFinallyNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=voidtype;

        TypeCheckPass(left);
        // "try block" is "used"? (JM)
        set_varstate(left,vs_readwritten,[vsf_must_be_valid]);

        TypeCheckPass(right);
        // "except block" is "used"? (JM)
        set_varstate(right,vs_readwritten,[vsf_must_be_valid]);

        if Assigned(third) then
          begin
            TypeCheckPass(third);
            set_varstate(third,vs_readwritten,[vsf_must_be_valid]);
          end;
      end;


    function TTryFinallyNode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_VOID;
        FirstPass(left);

        FirstPass(right);
        if Assigned(third) then
          FirstPass(third);

        include(CurrentProcInfo.flags,pi_do_call);

        { pi_uses_exceptions is an information for the optimizer and it
          is only interested in exceptions if they appear inside the body,
          so ignore implicit frames when setting the flag }
        if not(implicitframe) then
          include(CurrentProcInfo.flags,pi_uses_exceptions);

        adjust_estimated_stack_size;
      end;


   function TTryFinallyNode.simplify(forinline : boolean): TNode;
     begin
       result:=nil;
       { if the try contains no code, we can kill
         the try and except and return only the
         finally part }
       if has_no_code(left) then
         begin
           result:=right;
           right:=nil;
         end
       { if the finally block contains no code, we can kill
         it and just return the try part }
       else if has_no_code(right) and not(Assigned(third)) and not(implicitframe) then
         begin
           result:=left;
           left:=nil;
         end;
     end;


    function TTryFinallyNode.dogetcopy: TNode;
       begin
         result:=inherited dogetcopy;
         TTryFinallyNode(result).implicitframe:=implicitframe;
       end;


    procedure TTryFinallyNode.adjust_estimated_stack_size;
      begin
        inc(CurrentProcInfo.estimatedtempsize,rec_jmp_buf.size);
      end;


{*****************************************************************************
                                TONNODE
*****************************************************************************}

    constructor TOnNode.create(l,r:TNode);
      begin
         inherited create(onn,l,r);
         excepTSymtable:=nil;
         excepttype:=nil;
      end;


    destructor TOnNode.Destroy;
      begin
        { copied nodes don't need to release the symtable }
        if Assigned(excepTSymtable) then
         excepTSymtable.free;
         excepTSymtable := nil;
        inherited Destroy;
      end;


    constructor TOnNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        excepTSymtable:=nil;
        excepttype:=nil;
      end;


    function TOnNode.dogetcopy : TNode;
      var
         n : TOnNode;
      begin
         n:=TOnNode(inherited dogetcopy);
         if Assigned(exceptsymtable) then
           n.exceptsymtable:=exceptsymtable.getcopy
         else
           n.exceptsymtable:=nil;
         n.excepttype:=excepttype;
         result:=n;
      end;


    function TOnNode.pass_typecheck:TNode;
      begin
         result:=nil;
         resultdef:=voidtype;
         if not is_class(excepttype) and
            not is_javaclass(excepttype) then
           CGMessage1(type_e_class_type_expected,excepttype.typename);
         if Assigned(left) then
           TypeCheckPass(left);
         if Assigned(right) then
           TypeCheckPass(right);
      end;


    function TOnNode.pass_1 : TNode;
      begin
         result:=nil;
         include(CurrentProcInfo.flags,pi_do_call);
         expectloc:=LOC_VOID;
         if Assigned(left) then
           FirstPass(left);

         if Assigned(right) then
           FirstPass(right);
      end;


    function TOnNode.docompare(p: TNode): boolean;
      begin
        docompare := false;
      end;

end.
