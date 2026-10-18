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
         cLoopFlagsEqual = [lnf_backward];

    type
       TLabelNode = class;

       TLoopNode = class(TBinaryNode)
          T1,T2 : TNode;
          LoopFlags : TLoopFlags;
          constructor Create(ANodeType : TNodeType;ALeft,ARight,AT1,AT2 : TNode);virtual;
          destructor Destroy;override;
          function DoGetCopy : TNode;override;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          procedure InsertIntoList(AList : TNodeList);override;
          procedure PrintNodeTree(var AText:Text);override;
          function DoCompare(ANode: TNode): Boolean; override;
       end;

       TWhileRepeatNode = class(TLoopNode)
          { l: condition; r: body; tab: test at begin; cn: negate condition
            x,y,true,false: while loop
            x,y,false,true: repeat until loop }
          constructor Create(ALeft,ARight:TNode;ATestAtBegin,ACheckNegate:Boolean);virtual;reintroduce;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
          function Simplify(AForInline: Boolean): TNode;override;

          function InternalSimplify(AForInline: Boolean): TNode;
       end;
       TWhileRepeatNodeClass = class of TWhileRepeatNode;

       TIfNode = class(TLoopNode)
          constructor Create(ALeft,ARight,AT1 : TNode);virtual;reintroduce;
          constructor Create_Internal(ALeft,ARight,AT1 : TNode);virtual;reintroduce;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
          function Simplify(AForInline : Boolean) : TNode;override;
         private
          function InternalSimplify(AWarn: Boolean) : TNode;
       end;
       TIfNodeClass = class of TIfNode;

       TForNode = class(TLoopNode)
          { if count isn't divisible by unrolls then
            the for loop must jump to this label to get the correct
            number of executions }
          EntryLabel,
          { this is a dummy node used by the dfa to store life information for the loop iteration }
          LoopIteration : TNode;
          LoopVarNotID:cardinal;
          constructor Create(ALeft,ARight,AT1,AT2 : TNode;ABackward : Boolean);virtual;reintroduce;
          destructor Destroy;override;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
          function MakeWhileLoop : TNode;
          function Simplify(AForInline : Boolean) : TNode;override;
       end;
       TForNodeClass = class of TForNode;

       TExitNode = class(TUnaryNode)
          constructor Create(ALeft:TNode);virtual;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
          property ResultExpr : TNode read Left write Left;
       end;
       TExitNodeClass = class of TExitNode;

       TBreakNode = class(TNode)
          constructor Create;virtual;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
       end;
       TBreakNodeClass = class of TBreakNode;

       TContinueNode = class(TNode)
          constructor Create;virtual;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
       end;
       TContinueNodeClass = class of TContinueNode;

       TGotoNode = class(TNode)
       private
          FLabelNodeIdx : LongInt;
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
          LabelSym : TLabelSym;
          LabelNode : TLabelNode;
          ExceptionBlock : integer;
          constructor Create(ALabelSym : TLabelSym);virtual;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          procedure ResolvePPUIdx;override;
          function DoGetCopy : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
       end;
       TGotoNodeClass = class of TGotoNode;

       TLabelNode = class(TNode)
          ExceptionBlock : integer;
          { when copying trees, this points to the newly created copy of a label }
          CopiedTo : TLabelNode;
          LabSym : TLabelSym;
          constructor Create(ALeft:TNode;ALabSym:TLabelSym);virtual;
          destructor Destroy;override;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          function DoGetCopy : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
       end;
       TLabelNodeClass = class of TLabelNode;

       TRaiseNode = class(TTertiaryNode)
          constructor Create(ALeft,AAddress,AFrame:TNode);virtual;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
       end;
       TRaiseNodeClass = class of TRaiseNode;

       TTryExceptNode = class(TLoopNode)
          constructor Create(ALeft,ARight,AT1 : TNode);virtual;reintroduce;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
          function Simplify(AForInline: Boolean): TNode; override;
         protected
          procedure Adjust_Estimated_Stack_Size; virtual;
       end;
       TTryExceptNodeClass = class of TTryExceptNode;

       { the third node is to store a copy of the finally code for llvm:
         it needs one copy to execute in case an exception occurs, and
         one in case no exception occurs }
       TTryFinallyNode = class(TTertiaryNode)
          ImplicitFrame : Boolean;
          constructor Create(ALeft,ARight:TNode);virtual;reintroduce;
          constructor Create_Implicit(ALeft,ARight:TNode);virtual;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
          function Simplify(AForInline:Boolean): TNode;override;
       protected
          procedure Adjust_Estimated_Stack_Size; virtual;
       public
          function DoGetCopy: TNode;override;
       end;
       TTryFinallyNodeClass = class of TTryFinallyNode;

       TOnNode = class(TBinaryNode)
          ExceptSymTable : TSymTable;
          ExceptType : TObjectDef;
          constructor Create(ALeft,ARight:TNode);virtual;
          destructor Destroy;override;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
          function DoGetCopy : TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
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
    function Create_Type_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode): TNode;
    function Create_String_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode): TNode;
    function Create_Array_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode): TNode;
    function Create_Set_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode): TNode;
    function Create_Enumerator_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode;
       AEnumeratorGet, AEnumeratorMove: TProcDef; AEnumeratorCurrent: TPropertySym): TNode;
    function Create_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode): TNode;

    { converts all for nodes in the tree into while nodes,
      returns true if something was converted }
    function ConvertForLoops(var ANode : TNode) : Boolean;

implementation

    uses
      GlobType,Systems,ConstExp,compinnr,
      CUtils,Verbose,Globals,PPU,
      SymTable,paramgr,defcmp,defutil,htypechk,Pass_1,
      ncal,nadd,ncon,nmem,nld,ncnv,nbas,nutils,ninl,nset,ngenutil,

    {$if defined(i386)}
      CPUInfo,
    {$endif defined(xtensa) or defined(i386)}
      cgbase,ProcInfo
      ;


    // for-in loop helpers

    function Create_Type_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode): TNode;
      begin
        Result:=CForNode.Create(ALoopVar,
          CInlineNode.Create(in_low_x,false,AExpr.GetCopy),
          CInlineNode.Create(in_high_x,false,AExpr.GetCopy),
          ALoopBody,
          false);
      end;


    function CreateObjCForInLoop(ALoopVar, ALoopBody, AExpr: TNode): TNode;
      var
        lMainStatement, lOuterLoopBodyStatement, lInnerLoopBodyStatement, lTempStatement: TStatementNode;
        lState, lMutationCheck, lCurrentAmount, lInnerLoopCounter, lItems, lExpressionTemp: TTempCreateNode;
        lOuterLoop, lInnerLoop, lNode: TNode;
        lItemsArrayDef: TArrayDef;
        lSym: TSym;
      begin
        { Objective-C enumerators require Objective-C 2.0 }
        if not(m_objectivec2 in CurrentSettings.ModeSwitches) then
          begin
            Result:=CErrorNode.Create;
            MessagePos(AExpr.FileInfo,parser_e_objc_enumerator_2_0);
            exit;
          end;
        { Requires the NSFastEnumeration protocol and NSFastEnumerationState
          record }
        MaybeLoadCocoaTypes;
        if not Assigned(ObjC_FastEnumeration) or
           not Assigned(ObjC_FastEnumerationState) then
          begin
            Result:=CErrorNode.Create;
            MessagePos(AExpr.FileInfo,parser_e_objc_missing_enumeration_defs);
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

         Result:=InternalStatements(lMainStatement);
         { the fast enumeration state }
         lState:=CTempCreateNode.Create(ObjC_FastEnumerationState,ObjC_FastEnumerationState.Size,tt_persistent,false);
         TypeCheckPass(TNode(lState));
         AddStatement(lMainStatement,lState);
         { the temporary items array }
         lItemsArrayDef:=CArrayDef.Create(1,16,U32IntType);
         lItemsArrayDef.ElementDef:=ObjC_IDType;
         lItems:=CTempCreateNode.Create(lItemsArrayDef,lItemsArrayDef.Size,tt_persistent,false);
         AddStatement(lMainStatement,lItems);
         TypeCheckPass(TNode(lItems));
         { temp for the expression/collection through which we iterate }
         lExpressionTemp:=CTempCreateNode.Create(ObjC_FastEnumeration,ObjC_FastEnumeration.Size,tt_persistent,true);
         AddStatement(lMainStatement,lExpressionTemp);
         { currentamount temp (not really clean: we use ptruint instead of
           culong) }
         lCurrentAmount:=CTempCreateNode.Create(PtrUIntType,PtrUIntType.Size,tt_persistent,true);
         TypeCheckPass(TNode(lCurrentAmount));
         AddStatement(lMainStatement,lCurrentAmount);
         { mutationcheck temp (idem) }
         lMutationCheck:=CTempCreateNode.Create(PtrUIntType,PtrUIntType.Size,tt_persistent,true);
         TypeCheckPass(TNode(lMutationCheck));
         AddStatement(lMainStatement,lMutationCheck);
         { innerloopcounter temp (idem) }
         lInnerLoopCounter:=CTempCreateNode.Create(PtrUIntType,PtrUIntType.Size,tt_persistent,true);
         TypeCheckPass(TNode(lInnerLoopCounter));
         AddStatement(lMainStatement,lInnerLoopCounter);
         { initialise the state with 0 }
         AddStatement(lMainStatement,CCallNode.CreateInternFromUnit('SYSTEM','FILLCHAR',
           CCallParaNode.Create(GenIntConstNode(0),
             CCallParaNode.Create(GenIntConstNode(ObjC_FastEnumerationState.Size),
               CCallParaNode.Create(CTempRefNode.Create(lState),nil)
             )
           )
         ));
         { this will also check whether the expression (potentially) conforms
           to the NSFastEnumeration protocol (use expr.getcopy, because the
           caller will free expr) }
         AddStatement(lMainStatement,CAssignmentNode.Create(CTempRefNode.Create(lExpressionTemp),AExpr.GetCopy));

         { we add the "repeat..until" afterwards, now just create the body }
         lOuterLoop:=InternalStatements(lOuterLoopBodyStatement);
         { the countByEnumeratingWithState_objects_count call }
         lNode:=CCallParaNode.Create(CInlineNode.Create(in_length_x,false,CTypeNode.Create(lItemsArrayDef)),
               CCallParaNode.Create(CAddrNode.Create(CTempRefNode.Create(lItems)),
                 CCallParaNode.Create(CAddrNode.Create(CTempRefNode.Create(lState)),nil)
               )
             );
         lSym:=Search_Struct_Member(ObjC_FastEnumeration,'COUNTBYENUMERATINGWITHSTATE_OBJECTS_COUNT');
         if not Assigned(lSym) or
            (lSym.typ<>ProcSym) then
           InternalError(2010061901);
         lNode:=CCallNode.Create(lNode,TProcSym(lSym),lSym.Owner,CTempRefNode.Create(lExpressionTemp),[],nil);
         AddStatement(lOuterLoopBodyStatement,CAssignmentNode.Create(
           CTempRefNode.Create(lCurrentAmount),lNode));
         { if currentamount = 0, bail out (use copy of hloopvar, because we
           have to use it again below) }
         lNode:=InternalStatements(lTempStatement);
         AddStatement(lTempStatement,CAssignmentNode.Create(
             ALoopVar.GetCopy,CNilNode.Create));
         AddStatement(lTempStatement,CBreakNode.Create);
         AddStatement(lOuterLoopBodyStatement,CIfNode.Create(
           CAddNode.Create(EqualN,CTempRefNode.Create(lCurrentAmount),GenIntConstNode(0)),
           lNode,nil));
        { initial value of mutationcheck }
        lNode:=CTempRefNode.Create(lState);
        TypeCheckPass(lNode);
        lNode:=CDerefNode.Create(GenLoadField(lNode,'MUTATIONSPTR'));
        AddStatement(lOuterLoopBodyStatement,CAssignmentNode.Create(
          CTempRefNode.Create(lMutationCheck),lNode));
        { initialise innerloopcounter }
        AddStatement(lOuterLoopBodyStatement,CAssignmentNode.Create(
          CTempRefNode.Create(lInnerLoopCounter),COrdConstNode.Create(-1,PtrUIntType,false)));

        { and now the inner loop, again adding the repeat/until afterwards }
        lInnerLoop:=InternalStatements(lInnerLoopBodyStatement);
        { inc(innerloopcounter) without range/overflowchecking (because
          we go from culong(-1) to 0 during the first iteration }
        lNode:=CInlineNode.Create(
          in_inc_x,false,CCallParaNode.Create(
            CTempRefNode.Create(lInnerLoopCounter),nil));
        lNode.LocalSwitches:=lNode.LocalSwitches-[cs_check_range,cs_check_overflow];
        AddStatement(lInnerLoopBodyStatement,lNode);
        { if innerloopcounter=currentamount then break to the outer loop }
        AddStatement(lInnerLoopBodyStatement,CIfNode.Create(
          CAddNode.Create(EqualN,
            CTempRefNode.Create(lInnerLoopCounter),
            CTempRefNode.Create(lCurrentAmount)),
          CBreakNode.Create,
          nil));
        { verify that the collection didn't change in the mean time }
        lNode:=CTempRefNode.Create(lState);
        TypeCheckPass(lNode);
        AddStatement(lInnerLoopBodyStatement,CIfNode.Create(
          CAddNode.Create(unequaln,
            CTempRefNode.Create(lMutationCheck),
            CDerefNode.Create(GenLoadField(lNode,'MUTATIONSPTR'))
          ),
          CCallNode.CreateInternFromUnit('OBJC','OBJC_ENUMERATIONMUTATION',
            CCallParaNode.Create(CTempRefNode.Create(lExpressionTemp),nil)),
          nil));
        { finally: actually get the next element }
        lNode:=CTempRefNode.Create(lState);
        TypeCheckPass(lNode);
        lNode:=GenLoadField(lNode,'ITEMSPTR');
        TypeCheckPass(lNode);
        { don't simply use a vecn, because indexing a pointer won't work in
          non-FPC modes }
        if lNode.ResultDef.typ<>pointerdef then
          InternalError(2010061904);
        InsertTypeConv(lNode,
          CArrayDef.Create_From_Pointer(TPointerDef(lNode.ResultDef)));
        lNode:=CVecNode.Create(lNode,CTempRefNode.Create(lInnerLoopCounter));
        AddStatement(lInnerLoopBodyStatement,
          CAssignmentNode.Create(ALoopVar,lNode));
        { the actual loop body! }
        AddStatement(lInnerLoopBodyStatement,ALoopBody);

        { create the inner repeat/until and add it to the body of the outer
          one }
        lNode:=CWhileRepeatNode.Create(
          { repeat .. until false }
          COrdConstNode.Create(0,PasBool1Type,false),lInnerLoop,false,true);
        AddStatement(lOuterLoopBodyStatement,lNode);

        { create the outer repeat/until and add it to the the main body }
        lNode:=CWhileRepeatNode.Create(
          { repeat .. until innerloopcounter<currentamount }
          CAddNode.Create(ltn,
            CTempRefNode.Create(lInnerLoopCounter),
            CTempRefNode.Create(lCurrentAmount)),
          lOuterLoop,false,true);
        AddStatement(lMainStatement,lNode);

        { release the temps }
        AddStatement(lMainStatement,CTempDeleteNode.Create(lState));
        AddStatement(lMainStatement,CTempDeleteNode.Create(lMutationCheck));
        AddStatement(lMainStatement,CTempDeleteNode.Create(lCurrentAmount));
        AddStatement(lMainStatement,CTempDeleteNode.Create(lInnerLoopCounter));
        AddStatement(lMainStatement,CTempDeleteNode.Create(lItems));
        AddStatement(lMainStatement,CTempDeleteNode.Create(lExpressionTemp));
      end;


    function Create_String_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode): TNode;
      var
        lLoopStatement, lLoopBodyStatement: TStatementNode;
        lLoopVar, lStringVar: TTempCreateNode;
        lStringIndex, lLoopBody, lForLoopNode, lFromNode, lToNode: TNode;
      begin
        { result is a block of statements }
        Result:=InternalStatements(lLoopStatement);

        { create a temp variable for expression }
        lStringVar := CTempCreateNode.Create(
          AExpr.ResultDef,
          AExpr.ResultDef.Size,
          tt_persistent,true);

        AddStatement(lLoopStatement,lStringVar);
        AddStatement(lLoopStatement,CAssignmentNode.Create(CTempRefNode.Create(lStringVar),AExpr.GetCopy));

        { create a loop counter: signed integer with size of string length }
        lLoopVar := CTempCreateNode.Create(
          SIntType,
          SIntType.Size,
          tt_persistent,true);

        AddStatement(lLoopStatement,lLoopVar);

        lStringIndex:=CTempRefNode.Create(lLoopVar);

        lLoopBody:=InternalStatements(lLoopBodyStatement);
        // for-in loop variable := string_expression[index]
        AddStatement(lLoopBodyStatement,
          CAssignmentNode.Create(ALoopVar, CVecNode.Create(CTempRefNode.Create(lStringVar),lStringIndex)));

        { add the actual statement to the loop }
        AddStatement(lLoopBodyStatement,ALoopBody);

        if TStringDef(AExpr.ResultDef).StringType=st_shortstring then
          begin
            lFromNode:=GenIntConstNode(1);
            lToNode:=CInlineNode.Create(in_length_x,false,CTempRefNode.Create(lStringVar));
          end
        else
          begin
             lFromNode:=CInlineNode.CreateIntern(in_low_x,false,CTempRefNode.Create(lStringVar));
             lToNode:= CInlineNode.Create(in_high_x,false,CTempRefNode.Create(lStringVar));
           end;

        lForLoopNode:=CForNode.Create(CTempRefNode.Create(lLoopVar),
          lFromNode,
          lToNode,
          lLoopBody,
          false);

        AddStatement(lLoopStatement,lForLoopNode);
        { free the loop counter }
        AddStatement(lLoopStatement,CTempDeleteNode.Create(lLoopVar));
        { free the temp variable for expression }
        AddStatement(lLoopStatement,CTempDeleteNode.Create(lStringVar));
      end;


    function Create_Array_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode): TNode;
      var
        lLoopStatement, lLoopBodyStatement: TStatementNode;
        lLoopVar, lArrayVar: TTempCreateNode;
        lArrayIndex, lLowBound, lHighBound, lLoopBody, lForLoopNode, lExpression: TNode;
        lIsString: Boolean;
        lTempDef, lConvertDef: TDef;
        lElementCount: aword;
      begin
        lExpression := AExpr;

        { result is a block of statements }
        Result:=InternalStatements(lLoopStatement);

        lIsString:=ado_IsConstString in TArrayDef(AExpr.ResultDef).ArrayOptions;

        // if array element type <> loovar type then create a conversion if possible
        if Compare_Defs(TArrayDef(lExpression.ResultDef).ElementDef,ALoopVar.ResultDef,nothingn)=te_incompatible then
          begin
            lTempDef:=lExpression.ResultDef;
            lElementCount:=1;
            while Assigned(lTempDef) and (lTempDef.typ=arraydef) and
                  (TArrayDef(lTempDef).ArrayOptions = []) and
                  (Compare_Defs(TArrayDef(lTempDef).ElementDef,ALoopVar.ResultDef,nothingn)=te_incompatible) do
              begin
                lElementCount:=lElementCount*TArrayDef(lTempDef).EleCount;
                lTempDef:=TArrayDef(lTempDef).ElementDef;
              end;
            if Assigned(lTempDef) and (lTempDef.typ=arraydef) and (TArrayDef(lTempDef).ArrayOptions = []) then
              begin
                lElementCount:=lElementCount*TArrayDef(lTempDef).EleCount;
                lConvertDef:=CArrayDef.Create(0,lElementCount-1,S32IntType);
                TArrayDef(lConvertDef).ElementDef:=TArrayDef(lTempDef).ElementDef;
                lExpression:=AExpr.GetCopy;
                lExpression:=CTypeConvNode.Create_Internal(lExpression,lConvertDef);
                TypeCheckPass(lExpression);
                AddStatement(lLoopStatement,lExpression);
              end;
          end;

        if (Node_Complexity(lExpression) > 1) and
          not(Is_Open_Array(lExpression.ResultDef)) and not(Is_Array_Of_Const(lExpression.ResultDef)) then
          begin
            { create a temp variable for expression }
            lArrayVar := CTempCreateNode.Create(
              lExpression.ResultDef,
              lExpression.ResultDef.Size,
              tt_persistent,true);

            if lIsString then
              begin
                lLowBound:=GenIntConstNode(1);
                lHighBound:=CInlineNode.Create(in_length_x,false,CTempRefNode.Create(lArrayVar))
              end
            else
              begin
                { Iterating through slice }
                if (lExpression.NodeType=vecn) and (TVecNode(lExpression).Right.NodeType=rangen) then
                  begin
                    lLowBound:=TRangeNode(TVecNode(lExpression).Right).Left.GetCopy;
                    lHighBound:=TRangeNode(TVecNode(lExpression).Right).Right.GetCopy;
                    lExpression:=TVecNode(lExpression).Left.GetCopy;
                  end
                else
                  begin
                    lLowBound:=CInlineNode.Create(in_low_x,false,CTempRefNode.Create(lArrayVar));
                    lHighBound:=CInlineNode.Create(in_high_x,false,CTempRefNode.Create(lArrayVar));
                  end;
              end;

            AddStatement(lLoopStatement,lArrayVar);
            AddStatement(lLoopStatement,CAssignmentNode.Create(CTempRefNode.Create(lArrayVar),lExpression.GetCopy));
          end
        else
          begin
            lArrayVar:=nil;
            if lIsString then
              begin
                lLowBound:=GenIntConstNode(1);
                lHighBound:=CInlineNode.Create(in_length_x,false,lExpression.GetCopy);
              end
            else
              begin
                { Iterating through slice }
                if (lExpression.NodeType=vecn) and (TVecNode(lExpression).Right.NodeType=rangen) then
                  begin
                    lLowBound:=TRangeNode(TVecNode(lExpression).Right).Left.GetCopy;
                    lHighBound:=TRangeNode(TVecNode(lExpression).Right).Right.GetCopy;
                    lExpression:=TVecNode(lExpression).Left.GetCopy;
                  end
                else
                  begin
                    lLowBound:=CInlineNode.Create(in_low_x,false,lExpression.GetCopy);
                    lHighBound:=CInlineNode.Create(in_high_x,false,lExpression.GetCopy);
                  end;
              end;
          end;

        { create a loop counter }
        lLoopVar := CTempCreateNode.Create(
          TArrayDef(lExpression.ResultDef).RangeDef,
          TArrayDef(lExpression.ResultDef).RangeDef.Size,
          tt_persistent,true);

        AddStatement(lLoopStatement,lLoopVar);

        lArrayIndex:=CTempRefNode.Create(lLoopVar);

        lLoopBody:=InternalStatements(lLoopBodyStatement);
        // for-in loop variable := array_expression[index]
        if Assigned(lArrayVar) then
          AddStatement(lLoopBodyStatement,
            CAssignmentNode.Create(ALoopVar,CVecNode.Create(CTempRefNode.Create(lArrayVar),lArrayIndex)))
        else
          AddStatement(lLoopBodyStatement,
            CAssignmentNode.Create(ALoopVar,CVecNode.Create(lExpression.GetCopy,lArrayIndex)));

        { add the actual statement to the loop }
        AddStatement(lLoopBodyStatement,ALoopBody);

        lForLoopNode:=CForNode.Create(CTempRefNode.Create(lLoopVar),
          lLowBound,
          lHighBound,
          lLoopBody,
          false);

        AddStatement(lLoopStatement,lForLoopNode);
        { free the loop counter }
        AddStatement(lLoopStatement,CTempDeleteNode.Create(lLoopVar));
        { free the temp variable for expression if needed }
        if lArrayVar<>nil then
          AddStatement(lLoopStatement,CTempDeleteNode.Create(lArrayVar));
      end;


    function Create_Set_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode): TNode;
      var
        lLoopStatement, lLoopBodyStatement: TStatementNode;
        lLoopVar, lSetVar: TTempCreateNode;
        lLoopBody, lForLoopNode: TNode;
      begin
        // first check is set is empty and if it so then skip other processing
        if not Assigned(TSetDef(AExpr.ResultDef).ElementDef) then
          begin
            Result:=CNothingNode.Create;
            // free unused nodes
            ALoopVar.free;
            ALoopVar := nil;
            ALoopBody.free;
            ALoopBody := nil;
            exit;
          end;
        { result is a block of statements }
        Result:=InternalStatements(lLoopStatement);

        { create a temp variable for expression }
        lSetVar := CTempCreateNode.Create(
          AExpr.ResultDef,
          AExpr.ResultDef.Size,
          tt_persistent,true);

        AddStatement(lLoopStatement,lSetVar);
        AddStatement(lLoopStatement,CAssignmentNode.Create(CTempRefNode.Create(lSetVar),AExpr.GetCopy));

        { create a loop counter }
        lLoopVar := CTempCreateNode.Create(
          TSetDef(AExpr.ResultDef).ElementDef,
          TSetDef(AExpr.ResultDef).ElementDef.Size,
          tt_persistent,true);

        AddStatement(lLoopStatement,lLoopVar);

        // if loopvar in set then
        // begin
        //   hloopvar := loopvar
        //   for-in loop body
        // end

        lLoopBody:=CIfNode.Create(
          CInNode.Create(CTempRefNode.Create(lLoopVar),CTempRefNode.Create(lSetVar)),
          InternalStatements(lLoopBodyStatement),
          nil);

        AddStatement(lLoopBodyStatement,CAssignmentNode.Create(ALoopVar,CTempRefNode.Create(lLoopVar)));
        { add the actual statement to the loop }
        AddStatement(lLoopBodyStatement,ALoopBody);

        lForLoopNode:=CForNode.Create(CTempRefNode.Create(lLoopVar),
          CInlineNode.Create(in_low_x,false,CTempRefNode.Create(lSetVar)),
          CInlineNode.Create(in_high_x,false,CTempRefNode.Create(lSetVar)),
          lLoopBody,
          false);

        AddStatement(lLoopStatement,lForLoopNode);
        { free the loop counter }
        AddStatement(lLoopStatement,CTempDeleteNode.Create(lLoopVar));
        { free the temp variable for expression }
        AddStatement(lLoopStatement,CTempDeleteNode.Create(lSetVar));
      end;


    function Create_Enumerator_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode;
       AEnumeratorGet, AEnumeratorMove: TProcDef; AEnumeratorCurrent: TPropertySym): TNode;
      var
        lLoopStatement, lLoopBodyStatement: TStatementNode;
        lEnumVar: TTempCreateNode;
        lLoopBody, lWhileLoopNode,
        lEnumGet, lEnumMove, lEnumCurrent, lEnumGetParams: TNode;
        lPropAccessList: TPropAccessList;
        lEnumeratorIsClass: Boolean;
        lEnumeratorDestructor: TProcDef;
      begin
        { result is a block of statements }
        Result:=InternalStatements(lLoopStatement);

        lEnumeratorIsClass := Is_Class(AEnumeratorGet.ReturnDef);

        { create a temp variable for enumerator }
        lEnumVar := CTempCreateNode.Create(
          AEnumeratorGet.ReturnDef,
          AEnumeratorGet.ReturnDef.Size,
          tt_persistent,true);

        AddStatement(lLoopStatement,lEnumVar);

        if AEnumeratorGet.ProcTypeOption=potype_operator then
          begin
            lEnumGetParams:=CCallParaNode.Create(AExpr.GetCopy,nil);
            lEnumGet:=CCallNode.Create(lEnumGetParams, TProcSym(AEnumeratorGet.ProcSym), nil, nil, [],nil);
            TCallNode(lEnumGet).ProcDefinition:=AEnumeratorGet;
            AddSymRef(AEnumeratorGet.ProcSym,AEnumeratorGet);
          end
        else
          lEnumGet:=CCallNode.Create(nil, TProcSym(AEnumeratorGet.ProcSym), AEnumeratorGet.Owner, AExpr.GetCopy, [],nil);

        AddStatement(lLoopStatement,
          CAssignmentNode.Create(
            CTempRefNode.Create(lEnumVar),
            lEnumGet
          ));

        lLoopBody:=InternalStatements(lLoopBodyStatement);
        { for-in loop variable := enumerator.current }
        if AEnumeratorCurrent.GetPropAccessList(palt_read,lPropAccessList) then
          begin
             case lPropAccessList.FirstSym^.Sym.typ of
               FieldVarSym :
                 begin
                   { generate access code }
                   lEnumCurrent:=CTempRefNode.Create(lEnumVar);
                   PropAccessList_To_Node(lEnumCurrent,AEnumeratorCurrent.Owner,lPropAccessList);
                   include(lEnumCurrent.Flags,nf_isproperty);
                 end;
               ProcSym :
                 begin
                   { generate the method call }
                   lEnumCurrent:=CCallNode.Create(nil,TProcSym(lPropAccessList.FirstSym^.Sym),AEnumeratorCurrent.Owner,CTempRefNode.Create(lEnumVar),[],nil);
                   include(lEnumCurrent.Flags,nf_isproperty);
                 end
               else
                 begin
                   lEnumCurrent:=CErrorNode.Create;
                   Message(type_e_mismatch);
                 end;
            end;
          end
        else
          lEnumCurrent:=CErrorNode.Create;

        AddStatement(lLoopBodyStatement,
          CAssignmentNode.Create(ALoopVar, lEnumCurrent));

        { add the actual statement to the loop }
        AddStatement(lLoopBodyStatement,ALoopBody);

        lEnumMove:=CCallNode.Create(nil, TProcSym(AEnumeratorMove.ProcSym), AEnumeratorMove.Owner, CTempRefNode.Create(lEnumVar), [],nil);
        lWhileLoopNode:=CWhileRepeatNode.Create(lEnumMove,lLoopBody,true,false);

        if lEnumeratorIsClass then
          begin
            { insert a try-finally and call the destructor for the enumerator in the finally section }
            lEnumeratorDestructor:=TObjectDef(AEnumeratorGet.ReturnDef).Find_Destructor;
            if Assigned(lEnumeratorDestructor) then
              begin
                lWhileLoopNode:=CTryFinallyNode.Create(
                  lWhileLoopNode, // try node
                  CCallNode.Create(nil,TProcSym(lEnumeratorDestructor.ProcSym), // finally node
                    lEnumeratorDestructor.ProcSym.Owner,CTempRefNode.Create(lEnumVar),[],nil));
              end;
            { if getenumerator <> nil then do the loop }
            lWhileLoopNode:=CIfNode.Create(
              CAddNode.Create(unequaln, CTempRefNode.Create(lEnumVar), CNilNode.Create),
              lWhileLoopNode,
              nil);
          end;

        AddStatement(lLoopStatement, lWhileLoopNode);

        if Is_Object(AEnumeratorGet.ReturnDef) then
          begin
            // call the object destructor too
            lEnumeratorDestructor:=TObjectDef(AEnumeratorGet.ReturnDef).Find_Destructor;
            if Assigned(lEnumeratorDestructor) then
              begin
                AddStatement(lLoopStatement,
                  CCallNode.Create(nil,TProcSym(lEnumeratorDestructor.ProcSym),
                    lEnumeratorDestructor.ProcSym.Owner,CTempRefNode.Create(lEnumVar),[],nil));
              end;
          end;

        { free the temp variable for enumerator }
        AddStatement(lLoopStatement,CTempDeleteNode.Create(lEnumVar));
      end;


    function Create_For_In_Loop(ALoopVar, ALoopBody, AExpr: TNode): TNode;
      var
        lProcDef, lMoveNext: TProcDef;
        lHelperDef: TObjectDef;
        lCurrentProperty: TPropertySym;
        lSavedFilePos: TFilePosInfo;
      begin
        lSavedFilePos:=CurrentFilePos;
        CurrentFilePos:=ALoopVar.FileInfo;
        if AExpr.NodeType=typen then
          begin
            if (AExpr.ResultDef.typ=enumdef) and TEnumDef(AExpr.ResultDef).HasJumps then
              begin
                Result:=CErrorNode.Create;
                ALoopVar.free;
                ALoopVar := nil;
                ALoopBody.free;
                ALoopBody := nil;
                MessagePos1(AExpr.FileInfo,parser_e_for_in_loop_cannot_be_used_for_the_type,AExpr.ResultDef.TypeName);
              end
            else
              Result:=Create_Type_For_In_Loop(ALoopVar, ALoopBody, AExpr);
          end
        else
          begin
            { loop is made for an expression }
            // Objective-C uses different conventions (and it's only supported for Objective-C 2.0)
            if Is_ObjC_Class_Or_Protocol(ALoopVar.ResultDef) or
               Is_ObjC_Class_Or_Protocol(AExpr.ResultDef) then
              begin
                Result:=CreateObjCForInLoop(ALoopVar,ALoopBody,AExpr);
                if Result.NodeType=errorn then
                  begin
                    ALoopVar.free;
                    ALoopVar := nil;
                    ALoopBody.free;
                    ALoopBody := nil;
                  end;
              end
            { "for x in [] do ..." always results in a never executed loop body }
            else if (Is_Array_Constructor(AExpr.ResultDef) and
                (TArrayDef(AExpr.ResultDef).ElementDef=VoidType)) then
              begin
                if Assigned(ALoopBody) then
                  MessagePos(ALoopBody.FileInfo,cg_w_unreachable_code);
                Result:=CNothingNode.Create;
              end
            else
              begin
                if Is_Array_Constructor(AExpr.ResultDef) then
                  TArrayConstructorNode(AExpr).Force_Type(ALoopVar.ResultDef);
                // search for operator first
                lProcDef:=Search_Enumerator_Operator(AExpr.ResultDef, ALoopVar.ResultDef);
                // if there is no operator then search for class/object enumerator method
                if (lProcDef=nil) and (AExpr.ResultDef.typ in [objectdef,recorddef]) then
                  begin
                    { first search using the helper hierarchy }
                    if Search_Last_ObjectPascal_Helper(TAbstractRecordDef(AExpr.ResultDef),nil,lHelperDef) then
                      repeat
                        lProcDef:=lHelperDef.Search_Enumerator_Get;
                        lHelperDef:=lHelperDef.ChildOf;
                      until (lProcDef<>nil) or (lHelperDef=nil);
                    { we didn't find an enumerator in a helper, so search in the
                      class/record/object itself }
                    if lProcDef=nil then
                      lProcDef:=TAbstractRecordDef(AExpr.ResultDef).Search_Enumerator_Get;
                  end;
                if lProcDef<>nil then
                  begin
                    // seach movenext and current symbols
                    lMoveNext:=TAbstractRecordDef(lProcDef.ReturnDef).Search_Enumerator_Move;
                    if lMoveNext = nil then
                      begin
                        Result:=CErrorNode.Create;
                        ALoopVar.free;
                        ALoopVar := nil;
                        ALoopBody.free;
                        ALoopBody := nil;
                        MessagePos1(AExpr.FileInfo,sym_e_no_enumerator_move,lProcDef.ReturnDef.TypeName);
                      end
                    else
                      begin
                        lCurrentProperty:=TPropertySym(TAbstractRecordDef(lProcDef.ReturnDef).Search_Enumerator_Current);
                        if lCurrentProperty = nil then
                          begin
                            Result:=CErrorNode.Create;
                            ALoopVar.free;
                            ALoopVar := nil;
                            ALoopBody.free;
                            ALoopBody := nil;
                            MessagePos1(AExpr.FileInfo,sym_e_no_enumerator_current,lProcDef.ReturnDef.TypeName);
                          end
                        else
                          Result:=Create_Enumerator_For_In_Loop(ALoopVar, ALoopBody, AExpr, lProcDef, lMoveNext, lCurrentProperty);
                      end;
                  end
                else
                  begin
                    { prefer set if loop var could be a set var and the loop
                      expression can indeed be a set }
                    if (AExpr.NodeType=arrayconstructorn) and
                        (ALoopVar.ResultDef.typ in [enumdef,orddef]) and
                        ArrayConstructor_Can_Be_Set(AExpr) then
                      begin
                        AExpr:=ArrayConstructor_To_Set(AExpr,false);
                        TypeCheckPass(AExpr);
                      end;
                    case AExpr.ResultDef.typ of
                      stringdef:
                        Result:=Create_String_For_In_Loop(ALoopVar, ALoopBody, AExpr);
                      arraydef:
                        Result:=Create_Array_For_In_Loop(ALoopVar, ALoopBody, AExpr);
                      setdef:
                        Result:=Create_Set_For_In_Loop(ALoopVar, ALoopBody, AExpr);
                      undefineddef:
                        Result:=CNothingNode.Create;
                    else
                      begin
                        Result:=CErrorNode.Create;
                        ALoopVar.free;
                        ALoopVar := nil;
                        ALoopBody.free;
                        ALoopBody := nil;
                        MessagePos1(AExpr.FileInfo,sym_e_no_enumerator,AExpr.ResultDef.TypeName);
                      end;
                    end;
                  end;
              end;
          end;
        CurrentFilePos:=lSavedFilePos;
      end;


    function ConvertForLoopsNode(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      var
        lNode : TNode;
      begin
        Result:=fen_false;
        if ANode.NodeType=forn then
          begin
            Result:=fen_true;
            lNode:=ANode;
            ANode:=TForNode(ANode).MakeWhileLoop;
            DoFirstPass(ANode);
            lNode.Free;
            lNode := nil;
          end;
      end;


    function ConvertForLoops(var ANode : TNode) : Boolean;
      begin
        Result:=ForEachNodeStatic(pm_postprocess,ANode,@ConvertForLoopsNode,nil);
      end;

{****************************************************************************
                                 TLOOPNODE
*****************************************************************************}

    constructor TLoopNode.Create(ANodeType : TNodeType;ALeft,ARight,AT1,AT2 : TNode);

      begin
         inherited Create(ANodeType,ALeft,ARight);
         T1:=AT1;
         T2:=AT2;
         FileInfo:=ALeft.FileInfo;
      end;

    destructor TLoopNode.Destroy;

      begin
         T1.free;
         T1 := nil;
         T2.free;
         T2 := nil;
         inherited Destroy;
      end;


    constructor TLoopNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        T1:=PPULoadNode(APPUFile);
        T2:=PPULoadNode(APPUFile);
        APPUFile.GetSet(TPPUSet1(LoopFlags));
      end;


    procedure TLoopNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        PPUWriteNode(APPUFile,T1);
        PPUWriteNode(APPUFile,T2);
        APPUFile.PutSet(TPPUSet1(LoopFlags));
      end;


    procedure TLoopNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        if Assigned(T1) then
          T1.BuildDerefImpl;
        if Assigned(T2) then
          T2.BuildDerefImpl;
      end;


    procedure TLoopNode.DerefImpl;
      begin
        inherited DerefImpl;
        if Assigned(T1) then
          T1.DerefImpl;
        if Assigned(T2) then
          T2.DerefImpl;
      end;


    function TLoopNode.DoGetCopy : TNode;

      var
         lCopy : TLoopNode;

      begin
         lCopy:=TLoopNode(inherited DoGetCopy);
         if Assigned(T1) then
           lCopy.T1:=T1.DoGetCopy
         else
           lCopy.T1:=nil;
         if Assigned(T2) then
           lCopy.T2:=T2.DoGetCopy
         else
           lCopy.T2:=nil;
         lCopy.LoopFlags:=LoopFlags;
         DoGetCopy:=lCopy;
      end;

    procedure TLoopNode.InsertIntoList(AList : TNodeList);

      begin
      end;


    procedure TLoopNode.PrintNodeTree(var AText:Text);
      begin
        write(AText,PrintNodeIndention,'(');
        PrintNodeIndent;
        PrintNodeInfo(AText);
        WriteLn(AText);
        PrintNode(AText,Left);
        PrintNode(AText,Right);
        PrintNode(AText,T1);
        PrintNode(AText,T2);
        PrintNodeUnindent;
        WriteLn(AText,PrintNodeIndention,')');
      end;


    function TLoopNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          (LoopFlags*cLoopFlagsEqual=TLoopNode(ANode).LoopFlags*cLoopFlagsEqual) and
          T1.IsEqual(TLoopNode(ANode).T1) and
          T2.IsEqual(TLoopNode(ANode).T2);
      end;

{****************************************************************************
                               TWHILEREPEATNODE
*****************************************************************************}

    constructor TWhileRepeatNode.Create(ALeft,ARight:TNode;ATestAtBegin,ACheckNegate:Boolean);
      begin
        inherited Create(whilerepeatn,ALeft,ARight,nil,nil);
        if ATestAtBegin then
          include(LoopFlags, lnf_testatbegin);
        if ACheckNegate then
          include(LoopFlags,lnf_checknegate);
      end;


    function TWhileRepeatNode.Pass_TypeCheck:TNode;
      var
         lNode:TUnaryNode;
      begin
         Result:=nil;
         ResultDef:=VoidType;

         TypeCheckPass(Left);

         { tp procvar support }
         Maybe_Call_ProcVar(Left,true);

         {A not node can be removed.}
         if Left.NodeType=notn then
           begin
             lNode:=TUnaryNode(Left);
             Left:=TUnaryNode(Left).Left;
             lNode.Left:=nil;
             lNode.free;
             lNode := nil;
             {Symdif operator, in case you are wondering:}
             LoopFlags:=LoopFlags >< [lnf_checknegate];
           end;
         { loop instruction }
         if Assigned(Right) then
           TypeCheckPass(Right);
         set_varstate(Left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         if not(Is_Boolean(Left.ResultDef)) and
           not(Is_TypeParam(Left.ResultDef)) then
             InsertTypeConv(Left,PasBool1Type);

         { Give warnings for code that will never be executed for
           while false do }
         if (lnf_testatbegin in LoopFlags) and
            (Left.NodeType=ordconstn) and
            (TOrdConstNode(Left).Value.uvalue=0) and
            not(nf_internal in Left.Flags) and
            Assigned(Right) then
           CGMessagePos(Right.FileInfo,cg_w_unreachable_code);
      end;


    function TWhileRepeatNode.InternalSimplify(AForInline : Boolean) : TNode;
      var
        lNode: TNode;
      begin
        Result:=nil;
        { convert while i>0 do ... dec(i); to if i>0 then repeat ... dec(i) until i=0; ? }
        if (cs_opt_level2 in CurrentSettings.OptimizerSwitches) and
          { while loop? }
          (lnf_testatbegin in LoopFlags) and not(lnf_checknegate in LoopFlags) then
          begin
            if ((Left.NodeType=gtn) and (TAddNode(Left).Left.NodeType=loadn) and Is_ConstIntNode(TAddNode(Left).Right) and
              (TOrdConstNode(TAddNode(Left).Right).Value=0)) then
              begin
                lNode:=GetLastStatement(Right);
                if Assigned(lNode) and (lNode.NodeType=inlinen) and (TInlineNode(lNode).InlineNumber=in_dec_x) and
                  TAddNode(Left).Left.IsEqual(TCallParaNode(TInlineNode(lNode).Left).Left) and
                  not(Assigned(TCallParaNode(TInlineNode(lNode).Left).Right)) then
                  begin
                    Result:=CIfNode.Create_Internal(Left.GetCopy,CWhileRepeatNode.Create(Left,Right,false,true),nil);
                    Left:=nil;
                    Right:=nil;
                    TWhileRepeatNode(TIfNode(Result).Right).Left.NodeType:=EqualN;
                  end;
              end
            else if not(cs_opt_size in CurrentSettings.OptimizerSwitches) and
              (Node_Complexity(Left)<=3) then
              begin
                Result:=CIfNode.Create_Internal(Left.GetCopy,CWhileRepeatNode.Create(Left,Right,false,false),nil);
                Left:=nil;
                Right:=nil;
              end;
          end;
      end;


    function TWhileRepeatNode.Simplify(AForInline : Boolean) : TNode;
      begin
        Result:=InternalSimplify(false);
      end;


{$ifdef prefetchnext}
    type
      PAssignmentQuery = ^TAssignmentQuery;
      TAssignmentQuery = record
        ToWhat: TNode;
        Source: TAssignmentNode;
        StatementCount: cardinal;
      end;

    function CheckAssignment(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      var
        lQuery: PAssignmentQuery absolute AArg;
        lTemp, lPreDeref: TNode;
      begin
        Result := fen_norecurse_false;
        if (ANode.NodeType in [assignn,inlinen,forn,calln,whilerepeatn,casen,ifn]) then
          inc(lQuery^.StatementCount);
        { make sure there's something else in the loop besides going to the }
        { next item                                                         }
        if (lQuery^.StatementCount > 1) and
           (ANode.NodeType = assignn) then
          begin
            { skip type conversions of assignment target }
            lTemp := TAssignmentNode(ANode).Left;
            while (lTemp.NodeType = typeconvn) do
              lTemp := TTypeConvNode(lTemp).Left;

            { assignment to x of the while assigned(x) check? }
            if not(lTemp.IsEqual(lQuery^.ToWhat)) then
              exit;

            { right hand side of assignment dereferenced field of }
            { x? (no derefn in case of class)                     }
            lTemp := TAssignmentNode(ANode).Right;
            while (lTemp.NodeType = typeconvn) do
              lTemp := TTypeConvNode(lTemp).Left;
            if (lTemp.NodeType <> subscriptn) then
              exit;

            lPreDeref := TSubscriptNode(lTemp).Left;
            lTemp := lPreDeref;
            while (lTemp.NodeType = typeconvn) do
              lTemp := TTypeConvNode(lTemp).Left;

            { see tests/test/prefetch1.pas }
            if (lTemp.NodeType = derefn) then
              lTemp := TDerefNode(lTemp).Left
            else
              lTemp := lPreDeref;

            if lTemp.IsEqual(lQuery^.ToWhat) then
              begin
                lQuery^.Source := TAssignmentNode(ANode);
                Result := fen_norecurse_true;
               end
          end
        { don't check nodes which can't contain an assignment or whose }
        { final assignment can vary a lot                              }
        else if not(ANode.NodeType in [calln,inlinen,casen,whilerepeatn,forn]) then
          Result := fen_false;
      end;


    function FindAssignment(AWhere: TNode; AToWhat: TNode): TAssignmentNode;
      var
        lQuery: TAssignmentQuery;
      begin
        lQuery.ToWhat := AToWhat;
        lQuery.Source := nil;
        lQuery.StatementCount := 0;
        if ForEachNodeStatic(AWhere,@CheckAssignment,@lQuery) then
          Result := lQuery.Source
        else
           Result := nil;
      end;
{$endif prefetchnext}


    function TWhileRepeatNode.Pass_1 : TNode;
{$ifdef prefetchnext}
      var
         lRunnerNode, lPrefetchCode: TNode;
         lAssignmentNode: TAssignmentNode;
         lPrefetchStatements: TStatementNode;
{$endif prefetchnext}
      begin
         Result:=nil;
         ExpectLoc:=LOC_VOID;

         FirstPass(Left);
         if CodeGenError then
           exit;

         { loop instruction }
         if Assigned(Right) then
           begin
              FirstPass(Right);
              if CodeGenError then
                exit;
           end;

{$ifdef prefetchnext}
         { do at the end so all complex typeconversions are already }
         { converted to calln's                                     }
         if (cs_opt_level1 in CurrentSettings.OptimizerSwitches) and
            (lnf_testatbegin in LoopFlags) then
           begin
             { get first component of the while check }
             lRunnerNode := Left;
             while (lRunnerNode.NodeType in [andn,orn,notn,xorn,typeconvn]) do
               lRunnerNode := TUnaryNode(lRunnerNode).Left;
             { is it an assigned(x) check? }
             if ((lRunnerNode.NodeType = inlinen) and
                 (TInlineNode(lRunnerNode).InlineNumber = in_assigned_x)) or
                ((lRunnerNode.NodeType = unequaln) and
                 (TAddNode(lRunnerNode).Right.NodeType = niln)) then
               begin
                 lRunnerNode := TUnaryNode(lRunnerNode).Left;
                 { in case of in_assigned_x, there's a callparan in between }
                 if (lRunnerNode.NodeType = callparan) then
                   lRunnerNode := TCallParaNode(lRunnerNode).Left;
                 while (lRunnerNode.NodeType = typeconvn) do
                   lRunnerNode := TTypeConvNode(lRunnerNode).Left;
                 { is there an "x := x(^).somefield"? }
                 lAssignmentNode := FindAssignment(Right,lRunnerNode);
                 if Assigned(lAssignmentNode) then
                   begin
                     lPrefetchCode := InternalStatements(lPrefetchStatements);
                     AddStatement(lPrefetchStatements,GenInlineNode(in_prefetch_var,false,
                       CDerefNode.Create(CTypeConvNode.Create(lAssignmentNode.Right.GetCopy,VoidPointerType))));
                     AddStatement(lPrefetchStatements,Right);
                     Right := lPrefetchCode;
                     TypeCheckPass(Right);
                   end;
               end;
           end;
{$endif prefetchnext}
      end;


{*****************************************************************************
                               TIFNODE
*****************************************************************************}

    constructor TIfNode.Create(ALeft,ARight,AT1 : TNode);
      begin
         inherited Create(ifn,ALeft,ARight,AT1,nil);
      end;


    constructor TIfNode.Create_Internal(ALeft,ARight,AT1 : TNode);
      begin
        Create(ALeft,ARight,AT1);
        include(Flags,nf_internal);
      end;


  {$if ((defined(i386)) or (defined(x86_64))) or (defined(aarch64))}
    {$define HAS_MINMAX_INTRINSICS}
  {$endif defined(i386) or defined(x86_64) or defined(xtensa) or defined(aarch64)}


    function TIfNode.InternalSimplify(AWarn: Boolean) : TNode;
{$if defined(HAS_MINMAX_INTRINSICS)}
      var
        lThenStatement, lElseStatement: TNode;
        lInlineNumber: TInlineNumber;
        lParaType: TDef;
{$endif defined(HAS_MINMAX_INTRINSICS)}
      begin
        Result:=nil;
        { optimize constant expressions }
        if (Left.NodeType=ordconstn) then
          begin
             if TOrdConstNode(Left).Value.uvalue<>0 then
               begin
                  if Assigned(Right) then
                    Result:=Right
                  else
                    Result:=CNothingNode.Create;
                  Right:=nil;
                  if AWarn and Assigned(T1) and not(nf_internal in Left.Flags) then
                    CGMessagePos(T1.FileInfo,cg_w_unreachable_code);
               end
             else
               begin
                  if Assigned(T1) then
                    Result:=T1
                  else
                    Result:=CNothingNode.Create;
                  T1:=nil;
                  if AWarn and Assigned(Right) and not(nf_internal in Left.Flags) then
                    CGMessagePos(Right.FileInfo,cg_w_unreachable_code);
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
        lElseStatement:=nil;
        lInlineNumber:=Default(TInlineNumber);
        if (cs_opt_level2 in CurrentSettings.OptimizerSwitches) and
           (Left.NodeType in [gtn,gten,ltn,lten]) and IsSingleStatement(Right,lThenStatement) and
           ((T1=nil) or IsSingleStatement(T1,lElseStatement)) and
          (lThenStatement.NodeType=assignn) and ((T1=nil) or (lElseStatement.NodeType=assignn)) and
          not(Might_Have_SideEffects(Left)) and
          ((T1=nil) or TAssignmentNode(lThenStatement).Left.IsEqual(TAssignmentNode(lElseStatement).Left)) and
{$if defined(i386) or defined(x86_64)}
{$ifdef i386}
          (((CurrentSettings.FPUType>=fpu_sse) and Is_Single(TAssignmentNode(lThenStatement).Left.ResultDef)) or
           ((CurrentSettings.FPUType>=fpu_sse2) and Is_Double(TAssignmentNode(lThenStatement).Left.ResultDef)) or
           ((CPUX86_HAS_CMOV in cpu_capabilities[CurrentSettings.CPUType]) and Is_32BitInt(TAssignmentNode(lThenStatement).Left.ResultDef))
          ) and
{$else i386}
          (Is_Single(TAssignmentNode(lThenStatement).Left.ResultDef) or
           Is_Double(TAssignmentNode(lThenStatement).Left.ResultDef) or
           Is_32BitInt(TAssignmentNode(lThenStatement).Left.ResultDef) or
           Is_64BitInt(TAssignmentNode(lThenStatement).Left.ResultDef)
          ) and
{$endif i386}
{$endif defined(i386) or defined(x86_64)}
{$if defined(aarch64)}
          (Is_Single(TAssignmentNode(lThenStatement).Left.ResultDef) or Is_Double(TAssignmentNode(lThenStatement).Left.ResultDef) or
           Is_32BitInt(TAssignmentNode(lThenStatement).Left.ResultDef) or Is_64BitInt(TAssignmentNode(lThenStatement).Left.ResultDef)) and
{$endif defined(aarch64)}
          (
          { the right size of the assignment in the then clause must either }

          { equal to the left ... }
           (TAssignmentNode(lThenStatement).Right.IsEqual(TAddNode(Left).Left) and

            { ... and the else clause must be either not exist                 }
            { and the left side of the assignment in the then clause must be   }
            {  equal to the right operand of the comparison operator           }
            (
              ((T1=nil) and (TAssignmentNode(lThenStatement).Left.IsEqual(TAddNode(Left).Right))) or

              { or the else clause exists and the right side of the assignment in the else clause }
              { must be equal to the right side of the comparison operator                        }
              (Assigned(lElseStatement) and TAssignmentNode(lElseStatement).Right.IsEqual(TAddNode(Left).Right)))
           ) or
           { ... or right operand of the comparison operator }

            (TAssignmentNode(lThenStatement).Right.IsEqual(TAddNode(Left).Right) and
            { ... and the else clause must be either not exist                 }
            { and the left side of the assignment in the then clause must be   }
            {  equal to the left operand of the comparison operator            }
             (
              ((T1=nil) and (TAssignmentNode(lThenStatement).Left.IsEqual(TAddNode(Left).Left))) or

              { or the else clause exists and the right side of the assignment in the else clause }
              { must be equal to the left side of the comparison operator                         }
              (Assigned(lElseStatement) and TAssignmentNode(lElseStatement).Right.IsEqual(TAddNode(Left).Left))
             )
           )
          ) then
          begin
            lParaType:=TAssignmentNode(lThenStatement).Left.ResultDef;
            if ((Left.NodeType in [gtn,gten]) and
              TAssignmentNode(lThenStatement).Right.IsEqual(TAddNode(Left).Left)) or
              ((Left.NodeType in [ltn,lten]) and
              TAssignmentNode(lThenStatement).Right.IsEqual(TAddNode(Left).Right)) then
              begin
                if Is_Double(lParaType) then
                  lInlineNumber:=in_max_double
                else if Is_Single(lParaType) then
                  lInlineNumber:=in_max_single
                else if Is_U32BitInt(lParaType) then
                  lInlineNumber:=in_max_dword
                else if Is_S32BitInt(lParaType) then
                  lInlineNumber:=in_max_longint
                else if Is_U64BitInt(lParaType) then
                  lInlineNumber:=in_max_qword
                else if Is_S64BitInt(lParaType) then
                  lInlineNumber:=in_max_int64;
              end
            else
              begin
                if Is_Double(lParaType) then
                  lInlineNumber:=in_min_double
                else if Is_Single(lParaType) then
                  lInlineNumber:=in_min_single
                else if Is_U32BitInt(lParaType) then
                  lInlineNumber:=in_min_dword
                else if Is_S32BitInt(lParaType) then
                  lInlineNumber:=in_min_longint
                else if Is_U64BitInt(lParaType) then
                  lInlineNumber:=in_min_qword
                else if Is_S64BitInt(lParaType) then
                  lInlineNumber:=in_min_int64;
              end;
            { for inline nodes, the first parameter is the last one in the linked list

              Due to the defined behaviour for the min/max intrinsics that in case of a NaN
              the second parameter is taken, we have to put the else part into the second parameter
              thus pass it to the first callparanode call }
            if T1=nil then
              Result:=CAssignmentNode.Create_Internal(TAssignmentNode(lThenStatement).Left.GetCopy,
                CInlineNode.Create(lInlineNumber,false,CCallParaNode.Create(TAssignmentNode(lThenStatement).Left.GetCopy,
                      CCallParaNode.Create(TAssignmentNode(lThenStatement).Right.GetCopy,nil)))
                )
            else
              Result:=CAssignmentNode.Create_Internal(TAssignmentNode(lThenStatement).Left.GetCopy,
                CInlineNode.Create(lInlineNumber,false,CCallParaNode.Create(TAssignmentNode(lElseStatement).Right.GetCopy,
                      CCallParaNode.Create(TAssignmentNode(lThenStatement).Right.GetCopy,nil)))
                );
            Node_Reset_Pass1_Write(Result);
          end;
{$endif defined(HAS_MINMAX_INTRINSICS)}
      end;


    function TIfNode.Simplify(AForInline : Boolean) : TNode;
      begin
        Result:=InternalSimplify(false);
      end;


    function TIfNode.Pass_TypeCheck:TNode;
      begin
         Result:=nil;
         ResultDef:=VoidType;

         TypeCheckPass(Left);

         { tp procvar support }
         Maybe_Call_ProcVar(Left,true);

         { if path }
         if Assigned(Right) then
           TypeCheckPass(Right);
         { else path }
         if Assigned(T1) then
           TypeCheckPass(T1);
         set_varstate(Left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         if not(Is_Boolean(Left.ResultDef)) and
           not(Is_TypeParam(Left.ResultDef)) then
             InsertTypeConv(Left,PasBool1Type);

         Result:=InternalSimplify(not(nf_internal in Flags));
      end;


    function TIfNode.Pass_1 : TNode;
      begin
         Result:=nil;
         ExpectLoc:=LOC_VOID;
         FirstPass(Left);

         { if path }
         if Assigned(Right) then
           FirstPass(Right);

         { else path }
         if Assigned(T1) then
           FirstPass(T1);

         { leave if we've got an error in one of the paths }

         if CodeGenError then
           exit;
      end;


{*****************************************************************************
                              TFORNODE
*****************************************************************************}

    constructor TForNode.Create(ALeft,ARight,AT1,AT2 : TNode;ABackward : Boolean);

      begin
         inherited Create(forn,ALeft,ARight,AT1,AT2);
         if ABackward then
           include(LoopFlags,lnf_backward);
         include(LoopFlags,lnf_testatbegin);
      end;

    destructor TForNode.Destroy;
      begin
         LoopIteration.free;
         LoopIteration := nil;
         inherited Destroy;
      end;

    function TForNode.Simplify(AForInline : Boolean) : TNode;
      begin
        Result:=nil;
        { Can we spare the first comparison? }
        if (T1.NodeType=ordconstn) and
           (Right.NodeType=ordconstn) and
           (
            (
             (lnf_backward in LoopFlags) and
             (TOrdConstNode(Right).Value>=TOrdConstNode(T1).Value)
            ) or
            (
              not(lnf_backward in LoopFlags) and
              (TOrdConstNode(Right).Value<=TOrdConstNode(T1).Value)
            )
           ) then
          exclude(LoopFlags,lnf_testatbegin);

        if (T1.NodeType=ordconstn) and
           (Right.NodeType=ordconstn) and
           (
            (
             (lnf_backward in LoopFlags) and
             (TOrdConstNode(Right).Value<TOrdConstNode(T1).Value)
            ) or
            (
              not(lnf_backward in LoopFlags) and
              (TOrdConstNode(Right).Value>TOrdConstNode(T1).Value)
            )
           ) then
          Result:=CNothingNode.Create;
      end;


    function TForNode.Pass_TypeCheck:TNode;
      var
        lResultNode : TNode;
        lRangeDef: TDef;
      begin
         Result:=nil;
         ResultDef:=VoidType;

         { process the loopvar, from and to, varstates are already set }
         TypeCheckPass(Left);
         TypeCheckPass(Right);
         TypeCheckPass(T1);

         set_varstate(Left,vs_written,[]);

         { Make sure that the loop var and the
           from and to values are compatible types }
         if not(m_iso in CurrentSettings.ModeSwitches) then
           lRangeDef:=Left.ResultDef
         else
           lRangeDef:=Get_Iso_Range_Type(Left.ResultDef);

         check_ranges(Right.FileInfo,Right,lRangeDef);
         InsertTypeConv(Right,lRangeDef);

         check_ranges(T1.FileInfo,T1,lRangeDef);
         InsertTypeConv(T1,lRangeDef);

         if Assigned(T2) then
           TypeCheckPass(T2);
         Result:=Simplify(false);

         { loop unrolling }
         if not(Assigned(Result)) and
           (cs_opt_loopunroll in CurrentSettings.OptimizerSwitches) and
           Assigned(T2) and
           { statements must be error free }
           not(tnf_error in T2.TransientFlags) then
           begin
             TypeCheckPass(T2);
             lResultNode:=T2.Simplify(false);
             if Assigned(lResultNode) then
               T2:=lResultNode;
             lResultNode:=unroll_loop(self);
             if Assigned(lResultNode) then
               begin
                 TypeCheckPass(lResultNode);
                 Result:=lResultNode;
                 exit;
               end;
           end;

      end;


    function TForNode.Pass_1 : TNode;
      begin
        Result:=nil;
        ExpectLoc:=LOC_VOID;

        FirstPass(Left);
        FirstPass(Right);
        FirstPass(T1);

        if Assigned(T2) then
          FirstPass(T2);
      end;


    function TForNode.MakeWhileLoop : TNode;
      var
        lIfBlock,lLoopBlock : TBlockNode;
        lIfStatements,lStatements,lLoopStatements : TStatementNode;
        lFromTemp,lToTemp : TTempCreateNode;
        lLoopVarAtEnd : Boolean;
        { if the lower and/or upper bound are variable, we need a surrounding if }
        lNeedsIfBlock : Boolean;
        lCondition : TNodeType;
        lFromExpr : TNode;
        lToExpr, lLeftCopy: TNode;
        { if the upper bound is not constant, it must be store in a temp initially }
        lUseToTemp : Boolean;
        { if the lower bound is not constant, it must be store in a temp before calculating the upper bound }
        lUseFromTemp : Boolean;
        lSavedFilePos: TFilePosInfo;
        lCounterMin, lCounterMax: TConstExprInt;

      procedure IterateCounter(var AStatement : TStatementNode;AForward : Boolean);
        var
          lLeftCopy: TNode;
        begin
          { get rid of nf_write etc. as the left node is now only read }
          lLeftCopy:=Left.GetCopy;
          Node_Reset_Flags(lLeftCopy,[nf_modify,nf_write],[tnf_pass1_done]);

          if AForward then
            AddStatement(AStatement,
              CAssignmentNode.Create_Internal(Left.GetCopy,CInlineNode.CreateIntern(in_succ_x,false,lLeftCopy)))
          else
            AddStatement(AStatement,
              CAssignmentNode.Create_Internal(Left.GetCopy,CInlineNode.CreateIntern(in_pred_x,false,lLeftCopy)));
        end;

      function IterateCounterFunc(AArg : TNode;AForward : Boolean) : TNode;
        begin
          if AForward then
            Result:=CInlineNode.CreateIntern(in_succ_x,false,AArg)
          else
            Result:=CInlineNode.CreateIntern(in_pred_x,false,AArg);
        end;

      begin
        Result:=nil;
        lToTemp:=nil;
        lFromTemp:=nil;
        lSavedFilePos:=CurrentFilePos;
        CurrentFilePos:=FileInfo;

        case Left.ResultDef.typ of
          enumdef:
            begin
              lCounterMin:=TEnumDef(Left.ResultDef).min;
              lCounterMax:=TEnumDef(Left.ResultDef).max;
            end;
          orddef:
            begin
              lCounterMin:=TOrdDef(Left.ResultDef).low;
              lCounterMax:=TOrdDef(Left.ResultDef).high;
            end;
          else
            InternalError(2020012601);
        end;

        { check if we can pred/succ the loop var at the end }
        lLoopVarAtEnd:=(lnf_dont_mind_loopvar_on_exit in LoopFlags) and
          Is_ConstNode(T1) and
          { we cannot test at the end after the pred/succ if the to value is equal to the max./min. value of the counter variable
            because we either get an overflow/underflow or the compiler removes the check as it never can be true }

          { checking just the min./max. value depending on the pure size of the counter does not work as the check might
            get optimized away
          not(not(lnf_backward in loopflags) and not(is_signed(left.resultdef)) and (get_ordinal_value(t1)=((1 shl (left.resultdef.size*8))-1))) and
          not(not(lnf_backward in loopflags) and is_signed(left.resultdef) and (get_ordinal_value(t1)=((1 shl (left.resultdef.size*8-1))-1))) and
          not((lnf_backward in loopflags) and not(is_signed(left.resultdef)) and (get_ordinal_value(t1)=0)) and
          not((lnf_backward in loopflags) and is_signed(left.resultdef) and (get_ordinal_value(t1)=(-Tconstexprint(1 shl (left.resultdef.size*8-1))))) and
          }

          not(not(lnf_backward in LoopFlags) and (Get_Ordinal_Value(T1)=lCounterMax)) and
          not((lnf_backward in LoopFlags) and (Get_Ordinal_Value(T1)=lCounterMin)) and
          { neither might the for loop contain a continue statement as continue in a while loop would skip the increment at the end
            of the loop, this could be overcome by replacing the continue statement with an pred/succ; continue sequence }
          not(Has_Node_Of_Type(T2,[continuen])) and
          { if the loop is unrolled and there is a jump into the loop,
            then we can't do the trick with incrementing the loop var only at the
            end
          }
          not(Assigned(EntryLabel));

        lNeedsIfBlock:=not(Is_ConstNode(Right)) or not(Is_ConstNode(T1));

        { convert the for loop into a while loop }
        Result:=InternalStatements(lStatements);
        lIfBlock:=InternalStatements(lIfStatements);
        lLoopBlock:=InternalStatements(lLoopStatements);

        lUseFromTemp:=(Might_Have_SideEffects(T1) and not(Is_Const(Right))) or (Node_Complexity(Right)>1);
        lUseToTemp:=not(Is_Const(T1));

        if lNeedsIfBlock then
          begin
            { do not generate a temp. for the from node, if it is a const, it can be copied directly since
              no side effect might change it }
            if lUseFromTemp then
              begin
                lFromTemp:=CTempCreateNode.Create(Right.ResultDef,Right.ResultDef.Size,tt_persistent,true);
                { the if block might be optimized out, so we put the deletetempnode after the if-block, however,
                  this causes a long life time of the fromtemp. If the final regsync is left away, the reg. allocator
                  figures out the needed life time. As their are no loops involved between the uses of the fromtemp,
                  this does no hurt }
                lFromTemp.IncludeTempFlag(ti_no_final_regsync);
                AddStatement(lStatements,lFromTemp);
                { while it would be beneficial to fold the initial reverse succ/pred into this assignment, this is
                  not possible because it might wrap around and the if check later on goes wrong }
                AddStatement(lStatements,CAssignmentNode.Create_Internal(CTempRefNode.Create(lFromTemp),Right.GetCopy));
              end;

            if lUseToTemp then
              begin
                lToTemp:=CTempCreateNode.Create(T1.ResultDef,T1.ResultDef.Size,tt_persistent,true);
                AddStatement(lStatements,lToTemp);
                AddStatement(lStatements,CAssignmentNode.Create_Internal(CTempRefNode.Create(lToTemp),T1.GetCopy));
              end;

            if lUseFromTemp then
              begin
                AddStatement(lIfStatements,CAssignmentNode.Create_Internal(Left.GetCopy,CTempRefNode.Create(lFromTemp)));
                if not(lLoopVarAtEnd) then
                  IterateCounter(lIfStatements,lnf_backward in LoopFlags);
              end
            else
              begin
                if not(lLoopVarAtEnd) then
                  AddStatement(lIfStatements,CAssignmentNode.Create_Internal(Left.GetCopy,
                    IterateCounterFunc(Right.GetCopy,lnf_backward in LoopFlags)))
                else
                  AddStatement(lIfStatements,CAssignmentNode.Create_Internal(Left.GetCopy,Right.GetCopy));
              end;
          end
        else
          begin
            if not(lLoopVarAtEnd) then
              AddStatement(lIfStatements,CAssignmentNode.Create_Internal(Left.GetCopy,
                IterateCounterFunc(Right.GetCopy,lnf_backward in LoopFlags)))
            else
              AddStatement(lIfStatements,CAssignmentNode.Create_Internal(Left.GetCopy,Right.GetCopy));
          end;

        if Assigned(EntryLabel) then
          AddStatement(lIfStatements,CGotoNode.Create(TLabelNode(EntryLabel).LabSym));

        if not(lLoopVarAtEnd) then
          IterateCounter(lLoopStatements,not(lnf_backward in LoopFlags));

        { avoid copying t2, it is used only once and it might be big }
        AddStatement(lLoopStatements,T2);
        T2:=nil;

        if lLoopVarAtEnd then
         IterateCounter(lLoopStatements,not(lnf_backward in LoopFlags));

        if lLoopVarAtEnd then
          begin
            if lnf_backward in LoopFlags then
              lCondition:=ltn
            else
              lCondition:=gtn;
          end
        else
          begin
            if lnf_backward in LoopFlags then
              lCondition:=lten
            else
              lCondition:=gten;
          end;

        { get rid of nf_write etc. as the left node is now only read }
        lLeftCopy:=Left.GetCopy;
        Node_Reset_Flags(lLeftCopy,[nf_modify,nf_write],[tnf_pass1_done]);

        if lNeedsIfBlock then
          begin
            if lUseToTemp then
              lToExpr:=CTempRefNode.Create(lToTemp)
            else
              lToExpr:=T1.GetCopy;

            { checking against zero might improve the generated assembler,
              doing this transformation for other values is normally not beneficial }
            if lLoopVarAtEnd and (lnf_backward in LoopFlags) and Is_ConstIntNode(lToExpr) and (TOrdConstNode(lToExpr).Value=1) and
              (lCounterMin<TOrdConstNode(lToExpr).Value) then
              begin
                TOrdConstNode(lToExpr).Value:=TOrdConstNode(lToExpr).Value-1;
                AddStatement(lIfStatements,CWhileRepeatNode.Create(CAddNode.Create_Internal(EqualN,lLeftCopy,lToExpr),lLoopBlock,false,true))
              end
            else
              AddStatement(lIfStatements,CWhileRepeatNode.Create(CAddNode.Create_Internal(lCondition,lLeftCopy,lToExpr),lLoopBlock,false,true));

            if lUseFromTemp then
              lFromExpr:=CTempRefNode.Create(lFromTemp)
            else
              lFromExpr:=Right.GetCopy;

            if lUseToTemp then
              lToExpr:=CTempRefNode.Create(lToTemp)
            else
              lToExpr:=T1.GetCopy;

            if lnf_backward in LoopFlags then
              AddStatement(lStatements,CIfNode.Create(CAddNode.Create_Internal(gten,
                lFromExpr,lToExpr),lIfBlock,nil))
            else
              AddStatement(lStatements,CIfNode.Create(CAddNode.Create_Internal(lten,
                lFromExpr,lToExpr),lIfBlock,nil));

            if lUseToTemp then
              AddStatement(lStatements,CTempDeleteNode.Create(lToTemp));
            if lUseFromTemp then
              AddStatement(lStatements,CTempDeleteNode.Create(lFromTemp));
          end
        else
          begin
            { is a simple comparison for equality sufficient? }
            if lLoopVarAtEnd and (lnf_backward in LoopFlags) and (lnf_counter_not_used in LoopFlags) then
              AddStatement(lIfStatements,CWhileRepeatNode.Create(CAddNode.Create_Internal(EqualN,lLeftCopy,
                CAddNode.Create_Internal(subn,T1.GetCopy,COrdConstNode.Create(1,T1.ResultDef,false))),lLoopBlock,false,true))
            else
              AddStatement(lIfStatements,CWhileRepeatNode.Create(CAddNode.Create_Internal(lCondition,lLeftCopy,T1.GetCopy),lLoopBlock,false,true));
            AddStatement(lStatements,lIfBlock);
          end;
        CurrentFilePos:=lSavedFilePos;
      end;


{*****************************************************************************
                             TEXITNODE
*****************************************************************************}

    constructor TExitNode.Create(ALeft:TNode);
      begin
        inherited Create(exitn,ALeft);
        if Assigned(Left) then
          begin
            { add assignment to funcretsym }
            Left:=CTypeConvNode.Create(Left,CurrentProcInfo.procdef.ReturnDef);
            Left:=CAssignmentNode.Create(
              CLoadNode.Create(CurrentProcInfo.procdef.FuncRetSym,CurrentProcInfo.procdef.FuncRetSym.Owner),
              Left);
          end;
      end;


    constructor TExitNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
      end;


    procedure TExitNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
      end;


    function TExitNode.Pass_TypeCheck:TNode;
      var
        lNewStatement : TStatementNode;
        lResultSym: TSym;
        lResultDef: TDef;
      begin
        Result:=nil;
        lNewStatement:=nil;
        if Assigned(Left) then
          begin
             Result:=InternalStatements(lNewStatement);
             AddStatement(lNewStatement,Left);
             Left:=nil;
          end;
        { if the function result has been migrated to the parentfpstruct,
          we have to load it back to the original location (from which the
          code generator will load it into the function result location),
          because the code to this that we add in tnodeutils.wrap_proc_body()
          gets inserted before the exit label to which this node will jump }

        if Assigned(Result) then
          begin
            AddStatement(lNewStatement,self.GetCopy);
            { ensure we don't insert the function result loading code again for
              this node }
            include(lNewStatement.Left.Flags,nf_internal);
          end;
        ResultDef:=VoidType;
      end;


    function TExitNode.Pass_1 : TNode;
      begin
         Result:=nil;
         ExpectLoc:=LOC_VOID;
         if Assigned(Left) then
           InternalError(2011052801);
      end;


{*****************************************************************************
                             TBREAKNODE
*****************************************************************************}

    constructor TBreakNode.Create;

      begin
        inherited Create(breakn);
      end;


    function TBreakNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=VoidType;
      end;


    function TBreakNode.Pass_1 : TNode;
      begin
        Result:=nil;
        ExpectLoc:=LOC_VOID;
      end;


{*****************************************************************************
                             TCONTINUENODE
*****************************************************************************}

    constructor TContinueNode.Create;
      begin
        inherited Create(continuen);
      end;


    function TContinueNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=VoidType;
      end;


    function TContinueNode.Pass_1 : TNode;
      begin
        Result:=nil;
        ExpectLoc:=LOC_VOID;
      end;


{*****************************************************************************
                             TGOTONODE
*****************************************************************************}

    constructor TGotoNode.Create(ALabelSym : TLabelSym);
      begin
        inherited Create(goton);
        ExceptionBlock:=Current_ExceptBlock;
        LabelNode:=nil;
        LabelSym:=ALabelSym;
      end;


    constructor TGotoNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        FLabelNodeIdx:=APPUFile.GetLongInt;
        ExceptionBlock:=APPUFile.GetByte;
      end;


    procedure TGotoNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        FLabelNodeIdx:=LabelNode.PPUIdx;
        APPUFile.PutLongInt(FLabelNodeIdx);
        APPUFile.PutByte(ExceptionBlock);
      end;


    procedure TGotoNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
      end;


    procedure TGotoNode.DerefImpl;
      begin
        inherited DerefImpl;
      end;


    procedure TGotoNode.ResolvePPUIdx;
      begin
        LabelNode:=TLabelNode(NodePPUIdxGet(FLabelNodeIdx));
        if LabelNode.NodeType<>labeln then
          InternalError(200809021);
      end;


    function TGotoNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=VoidType;
      end;


    function TGotoNode.Pass_1 : TNode;
      var
        lProcInfo : TProcInfo;
      begin
        Result:=nil;
        ExpectLoc:=LOC_VOID;

        { The labelnode can already be set when
          this node was copied }
        if not(Assigned(LabelNode)) then
          begin
            { inner procedure goto? }
            if Assigned(LabelSym.code) and
              ((Assigned(LabelSym.Owner) and (CurrentProcInfo.procdef.ParaST.SymTableLevel=LabelSym.Owner.SymTableLevel)) or
              { generated by the optimizer? }
               not(Assigned(LabelSym.Owner))) then
              LabelNode:=TLabelNode(LabelSym.code)
            else if ((m_non_local_goto in CurrentSettings.ModeSwitches) and
              Assigned(LabelSym.Owner)) or
              { nested exits don't need the non local goto switch }
              (LabelSym.realname='$nestedexit') then
              begin
                if CurrentProcInfo.procdef.ParaST.SymTableLevel>=LabelSym.Owner.SymTableLevel then
                  begin
                    { don't mess with the exception blocks, global gotos in/out side exception blocks are not allowed }
                    if ExceptionBlock>0 then
                      CGMessage(cg_e_goto_inout_of_exception_block);

                    { goto across procedures using exception?
                      this is not allowed because we cannot
                      easily unwind the exception frame
                      stack
                    }
                    lProcInfo:=CurrentProcInfo;
                    while true do
                      begin
                        if ((cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and ((lProcInfo.Flags*[pi_needs_implicit_finally,pi_has_implicit_finally])<>[])) or
                        ((lProcInfo.Flags*[pi_uses_exceptions])<>[]) then
                          Message(cg_e_goto_across_procedures_with_exceptions_not_allowed);
                        if LabelSym.Owner=lProcInfo.procdef.LocalST then
                          break;
                        lProcInfo:=lProcInfo.Parent
                      end;

                    if Assigned(LabelSym.JumpBuf) then
                      begin
                        Result:=CCallNode.CreateIntern('fpc_longjmp',
                          CCallParaNode.Create(COrdConstNode.Create(1,SIntType,true),
                          CCallParaNode.Create(CLoadNode.Create(LabelSym.JumpBuf,LabelSym.JumpBuf.Owner),
                        nil)));
                      end
                    else
                      CGMessage1(cg_e_goto_label_not_found,LabelSym.realname);
                  end
                else
                  CGMessagePos(self.FileInfo,cg_e_interprocedural_goto_only_to_outer_scope_allowed);
              end
            else
              CGMessage1(cg_e_goto_label_not_found,LabelSym.realname);
          end;

        { check if we don't mess with exception blocks }
        if Assigned(LabelNode) and
           (ExceptionBlock<>LabelNode.ExceptionBlock) then
          CGMessage(cg_e_goto_inout_of_exception_block);
      end;


   function TGotoNode.DoGetCopy : TNode;
     var
       lCopy : TGotoNode;
     begin
        lCopy:=TGotoNode(inherited DoGetCopy);
        lCopy.ExceptionBlock:=ExceptionBlock;

        { generate labelnode if not done yet }
        if not(Assigned(LabelNode)) then
          begin
            if Assigned(LabelSym) and Assigned(LabelSym.code) then
              LabelNode:=TLabelNode(LabelSym.code)
          end;

        lCopy.LabelSym:=LabelSym;
        { do not copy the label node here as we do not know if the label node is part of the tree or not,
          this will be fixed after the copying in node.setuplabelnode: if the labelnode has copiedto set,
          labelnode of the goto node is update }
        if Assigned(LabelNode) then
          lCopy.LabelNode:=LabelNode
        else
          begin
            { don't trigger IE when there was already an error, i.e. the
              label is not defined. See tw11763 (PFV) }
            if (ErrorCount=0) and
            { don't trigger IE if it's a global goto }
               ((Assigned(LabelSym.Owner) and (CurrentProcInfo.procdef.ParaST.SymTableLevel=LabelSym.Owner.SymTableLevel)) or
               not(Assigned(LabelSym.Owner))) then
              InternalError(200610291);
          end;
        Result:=lCopy;
     end;


    function TGotoNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare := false;
      end;


{*****************************************************************************
                             TLABELNODE
*****************************************************************************}

    constructor TLabelNode.Create(ALeft:TNode;ALabSym:TLabelSym);
      begin
        inherited Create(labeln);
        ExceptionBlock:=Current_ExceptBlock;
        LabSym:=ALabSym;
        { Register labelnode in labelsym }
        LabSym.code:=self;
      end;


    constructor TLabelNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        ExceptionBlock:=APPUFile.GetByte;
      end;


    destructor TLabelNode.Destroy;
      begin
        if Assigned(LabSym) then
          begin
            if not Assigned(LabSym.Owner) then
              LabSym.Free // Free labelsym if it has no owner
            else
              if LabSym.code=Pointer(self) then
                begin
                  { Remove reference in labelsym, this is to prevent
                    goto's to this label }
                  LabSym.code:=nil;
                end;
          end;
        inherited Destroy;
      end;


    procedure TLabelNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutByte(ExceptionBlock);
      end;


    procedure TLabelNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
      end;


    procedure TLabelNode.DerefImpl;
      begin
        inherited DerefImpl;
      end;


    function TLabelNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=VoidType;
      end;


    function TLabelNode.Pass_1 : TNode;
      begin
        Result:=nil;
        ExpectLoc:=LOC_VOID;

        if not (nf_internal in Flags) then
          include(CurrentProcInfo.Flags,pi_has_label);

        if (m_non_local_goto in CurrentSettings.ModeSwitches) and
            { the owner can be Nil for internal labels }
            Assigned(LabSym.Owner) and
          (CurrentProcInfo.procdef.ParaST.SymTableLevel<>LabSym.Owner.SymTableLevel) then
          CGMessage(cg_e_labels_cannot_defined_outside_declaration_scope)
      end;


   function TLabelNode.DoGetCopy : TNode;
     begin
       if not(Assigned(CopiedTo)) then
         CopiedTo:=TLabelNode(inherited DoGetCopy);
       CopiedTo.ExceptionBlock:=ExceptionBlock;

       Result:=CopiedTo;
     end;


    function TLabelNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare := false;
      end;


{*****************************************************************************
                            TRAISENODE
*****************************************************************************}

    constructor TRaiseNode.Create(ALeft,AAddress,AFrame:TNode);
      begin
         inherited Create(raisen,ALeft,AAddress,AFrame);
      end;


    function TRaiseNode.Pass_TypeCheck:TNode;
      begin
         Result:=nil;
         ResultDef:=VoidType;
         if Assigned(Left) then
           begin
             { first para must be a _class_ }
             TypeCheckPass(Left);
             set_varstate(Left,vs_read,[vsf_must_be_valid]);
             if CodeGenError then
              exit;
             if not Is_Class(Left.ResultDef) then
               CGMessage1(type_e_class_type_expected,Left.ResultDef.TypeName);
             { insert needed typeconvs for addr,frame }
             if Assigned(Right) then
               begin
                 { addr }
                 TypeCheckPass(Right);
                 set_varstate(Right,vs_read,[vsf_must_be_valid]);
                 InsertTypeConv(Right,VoidCodePointerType);

                 { frame }
                 if Assigned(Third) then
                  begin
                    TypeCheckPass(Third);
                    set_varstate(Third,vs_read,[vsf_must_be_valid]);
                    InsertTypeConv(Third,VoidPointerType);
                  end;
               end;
           end;
      end;


    function TRaiseNode.Pass_1 : TNode;
      var
        lStatements : TStatementNode;
        lCurrentAddress : TLabelNode;
        lRaiseNode : TCallNode;
      begin
        Result:=InternalStatements(lStatements);

        if Assigned(Left) then
          begin
            { first para must be a class }
            FirstPass(Left);
            { insert needed typeconvs for addr,frame }
            if Assigned(Right) then
              begin
                { addr }
                FirstPass(Right);
                { frame }
                if Assigned(Third) then
                  FirstPass(Third)
                else
                  Third:=CPointerConstNode.Create(0,VoidPointerType);
              end
            else
              begin
                Third:=CInlineNode.Create(in_get_frame,false,nil);
                lCurrentAddress:=CLabelNode.Create(CNothingNode.Create,CLabelSym.Create('$raiseaddr'));
                include(lCurrentAddress.Flags,nf_internal);
                AddStatement(lStatements,lCurrentAddress);
                Right:=CAddrNode.Create(CLoadNode.Create(lCurrentAddress.LabSym,lCurrentAddress.LabSym.Owner));

                { raise address off by one so we are for sure inside the action area for the raise }
                if tf_use_psabieh in TargetInfo.Flags then
                  Right:=CAddNode.Create_Internal(addn,Right,COrdConstNode.Create(1,SizeSIntType,false));
              end;

            lRaiseNode:=CCallNode.CreateIntern('fpc_raiseexception',
              CCallParaNode.Create(Third,
              CCallParaNode.Create(Right,
              CCallParaNode.Create(Left,nil)))
              );
            include(lRaiseNode.CallNodeFlags,cnf_call_never_returns);
            AddStatement(lStatements,lRaiseNode);
          end
        else
          begin
            AddStatement(lStatements,CCallNode.CreateIntern('fpc_popaddrstack',nil));
            lRaiseNode:=CCallNode.CreateIntern('fpc_reraise',nil);
            include(lRaiseNode.CallNodeFlags,cnf_call_never_returns);
            AddStatement(lStatements,lRaiseNode);
          end;
        Left:=nil;
        Right:=nil;
        Third:=nil;
      end;

{*****************************************************************************
                             TTRYEXCEPTNODE
*****************************************************************************}

    constructor TTryExceptNode.Create(ALeft,ARight,AT1 : TNode);
      begin
         inherited Create(tryexceptn,ALeft,ARight,AT1,nil);
      end;


    function TTryExceptNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        TypeCheckPass(Left);
        { on statements }
        if Assigned(Right) then
          TypeCheckPass(Right);
        { else block }
        if Assigned(T1) then
          TypeCheckPass(T1);
        ResultDef:=VoidType;
      end;


    function TTryExceptNode.Pass_1 : TNode;
      begin
        Result:=nil;
        ExpectLoc:=LOC_VOID;
        FirstPass(Left);
        { on statements }
        if Assigned(Right) then
          FirstPass(Right);
        { else block }
        if Assigned(T1) then
          FirstPass(T1);

        include(CurrentProcInfo.Flags,pi_do_call);
        include(CurrentProcInfo.Flags,pi_uses_exceptions);

        Adjust_Estimated_Stack_Size;
      end;


    function TTryExceptNode.Simplify(AForInline: Boolean): TNode;
      begin
        Result:=nil;
        { empty try -> can never raise exception -> do nothing }
        if Has_No_Code(Left) then
          Result:=CNothingNode.Create;
      end;


    procedure TTryExceptNode.Adjust_Estimated_Stack_Size;
      begin
        inc(CurrentProcInfo.EstimatedTempSize,Rec_Jmp_Buf.Size*2);
      end;


{*****************************************************************************
                           TTRYFINALLYNODE
*****************************************************************************}

    constructor TTryFinallyNode.Create(ALeft,ARight:TNode);
      begin
        inherited Create(tryfinallyn,ALeft,ARight,nil);
        Third:=nil;
        ImplicitFrame:=false;
      end;


    constructor TTryFinallyNode.Create_Implicit(ALeft,ARight:TNode);
      begin
        inherited Create(tryfinallyn,ALeft,ARight,nil);
        Third:=nil;
        ImplicitFrame:=true;
      end;


    function TTryFinallyNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=VoidType;

        TypeCheckPass(Left);
        // "try block" is "used"? (JM)
        set_varstate(Left,vs_readwritten,[vsf_must_be_valid]);

        TypeCheckPass(Right);
        // "except block" is "used"? (JM)
        set_varstate(Right,vs_readwritten,[vsf_must_be_valid]);

        if Assigned(Third) then
          begin
            TypeCheckPass(Third);
            set_varstate(Third,vs_readwritten,[vsf_must_be_valid]);
          end;
      end;


    function TTryFinallyNode.Pass_1 : TNode;
      begin
        Result:=nil;
        ExpectLoc:=LOC_VOID;
        FirstPass(Left);

        FirstPass(Right);
        if Assigned(Third) then
          FirstPass(Third);

        include(CurrentProcInfo.Flags,pi_do_call);

        { pi_uses_exceptions is an information for the optimizer and it
          is only interested in exceptions if they appear inside the body,
          so ignore implicit frames when setting the flag }
        if not(ImplicitFrame) then
          include(CurrentProcInfo.Flags,pi_uses_exceptions);

        Adjust_Estimated_Stack_Size;
      end;


   function TTryFinallyNode.Simplify(AForInline : Boolean): TNode;
     begin
       Result:=nil;
       { if the try contains no code, we can kill
         the try and except and return only the
         finally part }
       if Has_No_Code(Left) then
         begin
           Result:=Right;
           Right:=nil;
         end
       { if the finally block contains no code, we can kill
         it and just return the try part }
       else if Has_No_Code(Right) and not(Assigned(Third)) and not(ImplicitFrame) then
         begin
           Result:=Left;
           Left:=nil;
         end;
     end;


    function TTryFinallyNode.DoGetCopy: TNode;
       begin
         Result:=inherited DoGetCopy;
         TTryFinallyNode(Result).ImplicitFrame:=ImplicitFrame;
       end;


    procedure TTryFinallyNode.Adjust_Estimated_Stack_Size;
      begin
        inc(CurrentProcInfo.EstimatedTempSize,Rec_Jmp_Buf.Size);
      end;


{*****************************************************************************
                                TONNODE
*****************************************************************************}

    constructor TOnNode.Create(ALeft,ARight:TNode);
      begin
         inherited Create(onn,ALeft,ARight);
         ExceptSymTable:=nil;
         ExceptType:=nil;
      end;


    destructor TOnNode.Destroy;
      begin
        { copied nodes don't need to release the symtable }
        if Assigned(ExceptSymTable) then
         ExceptSymTable.free;
         ExceptSymTable := nil;
        inherited Destroy;
      end;


    constructor TOnNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        ExceptSymTable:=nil;
        ExceptType:=nil;
      end;


    function TOnNode.DoGetCopy : TNode;
      var
         lCopy : TOnNode;
      begin
         lCopy:=TOnNode(inherited DoGetCopy);
         if Assigned(ExceptSymTable) then
           lCopy.ExceptSymTable:=ExceptSymTable.GetCopy
         else
           lCopy.ExceptSymTable:=nil;
         lCopy.ExceptType:=ExceptType;
         Result:=lCopy;
      end;


    function TOnNode.Pass_TypeCheck:TNode;
      begin
         Result:=nil;
         ResultDef:=VoidType;
         if not Is_Class(ExceptType) then
           CGMessage1(type_e_class_type_expected,ExceptType.TypeName);
         if Assigned(Left) then
           TypeCheckPass(Left);
         if Assigned(Right) then
           TypeCheckPass(Right);
      end;


    function TOnNode.Pass_1 : TNode;
      begin
         Result:=nil;
         include(CurrentProcInfo.Flags,pi_do_call);
         ExpectLoc:=LOC_VOID;
         if Assigned(Left) then
           FirstPass(Left);

         if Assigned(Right) then
           FirstPass(Right);
      end;


    function TOnNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare := false;
      end;

end.
