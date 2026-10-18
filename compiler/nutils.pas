{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Type checking and register allocation for inline nodes

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
unit nutils;

{$i fpcdefs.inc}
{$modeswitch nestedprocvars}

interface

  uses
    GlobType,ConstExp,
    symtype,SymSym,SymBase,SymTable,
    node,compinnr,
    nbas;

  const
    cNodeComplexityInf = 255;

  type
    { resultdef of functions that process on all nodes in a (sub)tree }
    TForEachNodeResult = (
      { false, continue recursion }
      fen_false,
      { false, stop recursion }
      fen_norecurse_false,
      { true, continue recursion }
      fen_true,
      { true, stop recursion }
      fen_norecurse_true
    );

    TForEachProcMethod = ({ children are processed before the parent node }
                          pm_preprocess,
                          { children are processed after the parent node }
                          pm_postprocess,
                          { children are processed after the parent node and
                            then the parent node is processed again }
                          pm_postandagain);


    TMHSFlag = (
      { exceptions (overflow, sigfault etc.) are considered as side effect }
      mhs_exceptions
    );
    TMHSFlags = set of TMHSFlag;
    PMHSFlags = ^TMHSFlags;

    TForEachNodeFunction = function(var n: TNode; arg: Pointer): TForEachNodeResult of object;
    TStaticForEachNodeFunction = function(var n: TNode; arg: Pointer): TForEachNodeResult;

    function ForEachNode(var ANode: TNode; AFunction: TForEachNodeFunction; AArg: Pointer): Boolean;
    function ForEachNode(AProcMethod : TForEachProcMethod; var ANode: TNode; AFunction: TForEachNodeFunction; AArg: Pointer): Boolean;
    function ForEachNodeStatic(var ANode: TNode; AFunction: TStaticForEachNodeFunction; AArg: Pointer): Boolean;
    function ForEachNodeStatic(AProcMethod : TForEachProcMethod; var ANode: TNode; AFunction: TStaticForEachNodeFunction; AArg: Pointer): Boolean;

    { checks if the given node tree contains only nodes of the given type,
      if this isn't the case, an ie is thrown
    }
    procedure CheckTreeNodeTypes(ANode : TNode;ATypeSet : TNodeTypeSet);

    procedure Load_ProcVar_From_CallN(var ANode:TNode);
    function Get_Local_Or_Para_Sym(const AName: string): TAbstractVarSym;
    function Maybe_Call_ProcVar(var ANode:TNode;ATPOnly:Boolean):Boolean;
    function Load_High_Value_Node(AVarSym:TParaVarSym):TNode;
    function Load_Self_Node:TNode;
    function Load_Result_Node:TNode;
    function Load_SafeCallResult_Node:TNode;
    function Load_Self_Pointer_Node:TNode;
    function Load_VMT_Pointer_Node:TNode;
    function Is_Self_Node(ANode:TNode):Boolean;
    { create a tree that loads the VMT based on a self-node of an object/class/
      interface }
    function Load_VMT_For_Self_Node(ASelfNode: TNode): TNode;

    function Node_Complexity(ANode: TNode): Cardinal;
    function Node_Resources_FPU(ANode: TNode): Cardinal;
    procedure Node_Tree_Set_FilePos(var ANode:TNode;const AFilePos:TFilePosInfo);

    { tries to simplify the given node after inlining }
    procedure DoInlineSimplify(var ANode : TNode);

    { creates an ordinal constant, optionally based on the result from a
      simplify operation: normally the type is the smallest integer type
      that can hold the value, but when inlining the "def" will be used instead,
      which was determined during an earlier typecheck pass (because the value
      may e.g. be a parameter to a call, which needs to be of the declared
      parameter type) }
    function Create_Simplified_Ord_Const(const AValue: TConstExprInt; ADef: TDef; AForInline, ARangeCheck: Boolean): TNode;

    { returns true if n is only a tree of administrative nodes
      containing no code }
    function Has_No_Code(ANode : TNode) : Boolean;

    procedure PropAccessList_To_Node(var ANode:TNode;ASymTable:TSymTable;APropAccessList:TPropAccessList);
    function Node_To_PropAccessList(ANode:TNode):TPropAccessList;

    { checks whether sym is a static field and if so, translates the access
      to the appropriate node tree }
    function Handle_StaticField_Access(ASym: TSym; var ANode: TNode): Boolean;

    { returns true if n is an array element access of a bitpacked array with
      elements of the which the vitsize mod 8 <> 0, or if is a field access
      with bitsize mod 8 <> 0 or bitoffset mod 8 <> 0 of an element in a
      bitpacked structure }
    function Is_BitPacked_Access(ANode: TNode): Boolean;

    { creates a load of field 'fieldname' in the record/class/...
      represented by n }
    function GenLoadField(ANode: TNode; const AFieldName: string): TNode;

    { returns true, if the tree given might have side effects }
    function Might_Have_SideEffects(ANode : TNode;const AFlags : TMHSFlags = []) : Boolean;

    { returns true, if n contains nodes which might be conditionally executed }
    function Has_Conditional_Nodes(ANode : TNode) : Boolean;

    { count the number of nodes in the node tree,
      rough estimation how large the tree "node" is
      If more than max nodes, returns max, so node_count(n, 10 + 1) <= 10 answers whether the tree has ≤10 nodes but avoids traversing the remaining 990. }
    function Node_Count(ANode : TNode; AMax : DWord = High(DWord)) : DWord;

    function Node_Count_Weighted(ANode : TNode; AMax : DWord = High(DWord)) : DWord;

    { returns true, if the value described by node is constant/immutable, this approximation is safe
      if no dirty tricks like buffer overflows or pointer magic are used }
    function Is_Const(ANode : TNode) : Boolean;

    { returns a pointer to the real node a node refers to,
      skipping (absolute) equal type conversions. Returning
      a pointer allows the caller to move/remove/replace this
      node
    }
    function ActualTargetNode(ANode : PNode) : PNode;

    { moves src into dest, before doing so, right is set to nil and dest is freed.
      Because dest and src are var parameters, this can be done inline in an existing
      node tree }
    procedure ReplaceNode(var ADest,ASrc : TNode);

    { strip off deref/addr combinations when looking for a the load node of an open array/array of const
      since there is no possibility to defined a pointer to an open array/array of const, we have not to
      take care of type casts, further, it means also that deref/addr nodes must always appear coupled
    }
    function Get_Open_Const_Array(ANode : TNode) : TNode;

    { excludes the flags passed in nf from the node tree passed }
    procedure Node_Reset_Flags(ANode : TNode;ANodeFlags : TNodeFlags; ATransientFlags : TTransientNodeFlags);

    { include or exclude cs from p.localswitches }
    procedure Node_Change_Local_Switch(ANode : TNode;ASwitch : TLocalSwitch;AEnable : Boolean);

    { returns true, if p is a node which shall be short boolean evaluated,
      if it is not an orn/andn with boolean operands, the result is undefined }
    function DoShortBoolEval(ANode : TNode) : Boolean;

    { returns true if the node has the int value l }
    function Is_ConstIntValue(ANode : TNode;AValue : TConstExprInt) : Boolean;

    { if the node is a constant node which can be an int value, this value is returned }
    function Get_Int_Value(ANode : TNode): TConstExprInt;

    { returns true if the node is an inline node of type i }
    function Is_InlineFunction(ANode : TNode;AInlineNumber : TInlineNumber) : Boolean;

    { checks if p is a series of length(a) statements, if yes, they are returned
      in a and the function returns true }
    function GetStatements(ANode : TNode;var AStatements : array of TStatementNode) : Boolean;

    { checks if p is a single statement, if yes, it is returned in s }
    function IsSingleStatement(ANode : TNode;var AStatement : TNode) : Boolean;

    { gets the last statement in a sequence of statements/blocks }
    function GetLastStatement(ANode : TNode) : TNode;

    type
      TMatchProc2 = function(n1,n2 : TNode) : Boolean is nested;
      TTransformProc2 = function(n1,n2 : TNode) : TNode is nested;
      TMatchProc4 = function(n1,n2,n3,n4 : TNode) : Boolean is nested;
      TTransformProc4 = function(n1,n2,n3,n4 : TNode) : TNode is nested;

    { calls matchproc with n1 and n2 as parameters, if it returns true, transformproc is called, does the same with the nodes swapped,
      the result of transformproc is assigned to res }
    function MatchAndTransformNodesCommutative(ANode1,ANode2 : TNode;AMatchProc : TMatchProc2;ATransformProc : TTransformProc2;var AResult : TNode) : Boolean;

    { calls matchproc with n1, n2, n3 and n4 as parameters being considered as the leafs of commutative nodes so all 8 possible
      combinations are tested, if it returns true, transformproc is called,
      the result of transformproc is assigned to res

      this allows to find pattern like (3*a)+(3*b) and transform them into 3*(a+b)
    }
    function MatchAndTransformNodesCommutative(ANode1,ANode2,ANode3,ANode4 : TNode;AMatchProc : TMatchProc4;ATransformProc : TTransformProc4;var AResult : TNode) : Boolean;

    {
      resets all flags so that nf_write/nf_modify information is regenerated
    }
    procedure Node_Reset_Pass1_Write(ANode: TNode);

    { Returns True if n one of its children has a type that appears in TypeList }
    function Has_Node_Of_Type(ANode: TNode; ATypeList: TNodeTypeSet): Boolean; {$IFDEF USEINLINE}inline;{$ENDIF USEINLINE}

    { returns true if n is guranteed not to return an ordinal zero }
    function Node_Not_Zero(ANode : TNode) : Boolean;


implementation

    uses
      CUtils,Verbose,Globals,
      symconst,symdef,
      defcmp,defutil,
      ncon,ncnv,nld,nflw,nset,ncal,nadd,nmem,ninl,
      cpubase,cgbase,ProcInfo,
      Pass_1;

    type
      TForEachNodeContext = object
        FProcMethod: TForEachProcMethod;
        FFunction: TStaticForEachNodeFunction;
        FArg: Pointer;
        FResult: Boolean;
        procedure Perform(var ANode: TNode);
        procedure ProcessChildren(ANode: TNode);
        procedure ProcessCaseNode(ANode: TCaseNode);
      end;


    procedure TForEachNodeContext.Perform(var ANode: TNode);
      var
        lResult: TForEachNodeResult;
      begin
        if not Assigned(ANode) then
          exit;
        if FProcMethod=pm_preprocess then
          ProcessChildren(ANode);

        lResult:=FFunction(ANode,FArg);
        FResult:=(lResult in [fen_true, fen_norecurse_true]) or FResult;
        if lResult in [fen_norecurse_false, fen_norecurse_true] then
          exit;

        if FProcMethod in [pm_postprocess,pm_postandagain] then
          begin
            ProcessChildren(ANode);
            if FProcMethod=pm_postandagain then
              begin
                lResult:=FFunction(ANode,FArg);
                FResult:=(lResult in [fen_true, fen_norecurse_true]) or FResult;
              end;
          end;
      end;


    procedure TForEachNodeContext.ProcessChildren(ANode: TNode);
      begin
        case ANode.NodeType of
          asn:
            if Assigned(TAsNode(ANode).call) then
              begin
                Perform(TAsNode(ANode).call);
                exit
              end;
          calln:
            begin
              Perform(TNode(TCallNode(ANode).CallInitBlock));
              Perform(TCallNode(ANode).MethodPointer);
              Perform(TCallNode(ANode).FuncRetNode);
              Perform(TNode(TCallNode(ANode).VMTEntry));
              Perform(TNode(TCallNode(ANode).CallCleanupBlock));
            end;
          callparan:
            begin
              Perform(TNode(TCallParaNode(ANode).FParaInit));
              Perform(TCallParaNode(ANode).FParaCopyBack);
            end;
          ifn, whilerepeatn, forn, tryexceptn:
            begin
              Perform(TLoopNode(ANode).t1);
              Perform(TLoopNode(ANode).t2);
            end;
          raisen, tryfinallyn:
            { frame tree/copy of finally code }
            Perform(TTertiaryNode(ANode).Third);
          tempcreaten:
            { temp. initialization code }
            if Assigned(TTempCreateNode(ANode).TempInfo^.TempInitCode) then
              Perform(TTempCreateNode(ANode).TempInfo^.TempInitCode);
          casen:
            ProcessCaseNode(TCaseNode(ANode));
          else
            ;
        end;
        if ANode.inheritsfrom(TBinaryNode) then
          begin
            { first process the "payload" of statementnodes }
            Perform(TBinaryNode(ANode).Left);
            Perform(TBinaryNode(ANode).Right);
          end
        else if ANode.inheritsfrom(TUnaryNode) then
          Perform(TUnaryNode(ANode).Left);
      end;


    procedure TForEachNodeContext.ProcessCaseNode(ANode: TCaseNode);
      var
        lIndex: SizeInt;
        lBlock: Pointer;
      begin
        for lIndex := 0 to ANode.Blocks.count-1 do
          begin
            lBlock := ANode.Blocks[lIndex];
            if Assigned(lBlock) then
              Perform(PCaseBlock(lBlock)^.statement);
          end;
        Perform(ANode.ElseBlock);
      end;


    { Adapts foreachnodefunction to staticforeachnodefunction. }
    type
      TBoundToStaticForEachNodeContext = record
        FunctionPtr: TForEachNodeFunction;
        Arg: Pointer;
      end;

    function BoundToStaticForEachNodeAdapter(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      var
        lAdapterContext: ^TBoundToStaticForEachNodeContext absolute AArg;
      begin
        Result := lAdapterContext^.FunctionPtr(ANode, lAdapterContext^.Arg);
      end;


    function ForEachNode(AProcMethod : TForEachProcMethod;var ANode: TNode; AFunction: TForEachNodeFunction; AArg: Pointer): Boolean;
      var
        lAdapterContext: TBoundToStaticForEachNodeContext;
      begin
        lAdapterContext.FunctionPtr := AFunction;
        lAdapterContext.Arg := AArg;
        Result:=ForEachNodeStatic(AProcMethod,ANode,@BoundToStaticForEachNodeAdapter,@lAdapterContext);
      end;


    function ForEachNode(var ANode: TNode; AFunction: TForEachNodeFunction; AArg: Pointer): Boolean;
      begin
        Result:=ForEachNode(pm_postprocess,ANode,AFunction,AArg);
      end;


    function ForEachNodeStatic(AProcMethod : TForEachProcMethod;var ANode: TNode; AFunction: TStaticForEachNodeFunction; AArg: Pointer): Boolean;
      var
        lContext: TForEachNodeContext;
      begin
        lContext.FProcMethod := AProcMethod;
        lContext.FFunction := AFunction;
        lContext.FArg := AArg;
        lContext.FResult := false;
        lContext.Perform(ANode);
        Result := lContext.FResult;
      end;


    function ForEachNodeStatic(var ANode: TNode; AFunction: TStaticForEachNodeFunction; AArg: Pointer): Boolean;
      begin
        Result:=ForEachNodeStatic(pm_postprocess,ANode,AFunction,AArg);
      end;


    function CheckNodeTypes(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      begin
        if not(ANode.NodeType in PNodeTypeSet(AArg)^) then
          InternalError(200610141);
        Result:=fen_true;
      end;


    procedure CheckTreeNodeTypes(ANode : TNode;ATypeSet : TNodeTypeSet);
      begin
        ForEachNodeStatic(ANode,@CheckNodeTypes,@ATypeSet);
      end;


    procedure Load_ProcVar_From_CallN(var ANode:TNode);
      var
        lNode : TNode;
      begin
        if ANode.NodeType<>calln then
          InternalError(200212251);
        { was it a procvar, then we simply remove the calln and
          reuse the right }
        if Assigned(TCallNode(ANode).Right) then
          begin
            lNode:=TCallNode(ANode).Right;
            TCallNode(ANode).Right:=nil;
          end
        else
          begin
            lNode:=CLoadNode.Create_ProcVar(TCallNode(ANode).SymTableProcEntry,
               TProcDef(TCallNode(ANode).ProcDefinition),TCallNode(ANode).SymTableProc);
            { when the methodpointer is typen we've something like:
              tobject.create. Then only the address is needed of the
              method without a self pointer }
            if Assigned(TCallNode(ANode).MethodPointer) and
               (TCallNode(ANode).MethodPointer.NodeType<>typen) then
              TLoadNode(lNode).Set_MP(TCallNode(ANode).MethodPointer.GetCopy);
          end;
        TypeCheckPass(lNode);
        ANode.free;
        ANode:=lNode;
      end;


    function Maybe_Call_ProcVar(var ANode:TNode;ATPOnly:Boolean):Boolean;
      var
        lNode : TNode;
      begin
        Result:=false;
        if not (ANode.ResultDef.typ in [procvardef,objectdef]) or
           (
             (ANode.ResultDef.typ=objectdef) and
             (
               not Is_Invokable(ANode.ResultDef) or
               (nf_load_procvar in ANode.Flags) or
               not (
                 Is_FuncRef(ANode.ResultDef) or
                 Invokable_Has_Argless_Invoke(TObjectDef(ANode.ResultDef))
               )
             )
           ) or
           (ATPOnly and
            not(m_tp_procvar in CurrentSettings.ModeSwitches)) then
          exit;
        { ignore vecn,subscriptn }
        lNode:=ANode;
        repeat
          case lNode.NodeType of
            vecn,
            derefn,
            typeconvn,
            subscriptn :
              lNode:=TUnaryNode(lNode).Left;
            blockn:
              lNode:=LastStatement(TBlockNode(lNode)).Left
            else
              break;
          end;
        until false;
        { a tempref is used when it is loaded from a withsymtable }
        if (lNode.NodeType in [calln,loadn,temprefn]) then
          begin
            lNode:=CCallNode.Create_ProcVar(nil,ANode);
            TypeCheckPass(lNode);
            ANode:=lNode;
            Result:=true;
          end;
      end;


    function Get_Local_Or_Para_Sym(const AName: string): TAbstractVarSym;
      var
        lProcDef: TProcDef;
        lResultSym: TSym;
      begin
        lResultSym:=nil;
        Result:=nil;
        { is not assigned while parsing a property }
        if not Assigned(CurrentProcInfo) then
          exit;
        { we can't use searchsym here, because the
          symtablestack is not fully setup when pass1
          is run for nested procedures }
        lProcDef:=CurrentProcInfo.procdef;
        repeat
          lResultSym:=TSym(lProcDef.LocalST.Find(AName));
          if Assigned(lResultSym) then
            break;
          lResultSym:=TSym(lProcDef.ParaST.Find(AName));
          if Assigned(lResultSym) then
            break;
          { try the parent of a nested function }
          if Assigned(lProcDef.Owner.DefOwner) and
             (lProcDef.Owner.DefOwner.typ=procdef) then
            lProcDef:=TProcDef(lProcDef.Owner.DefOwner)
          else
            break;
        until false;
        if Assigned(lResultSym) and
           not(lResultSym.typ in [localvarsym,paravarsym]) then
          InternalError(2020122604);
        Result:=TAbstractVarSym(lResultSym);
      end;



    function Load_High_Value_Node(AVarSym:TParaVarSym):TNode;
      begin
        Result:=Gen_Load_Var(Get_High_Value_Sym(AVarSym));
        TypeCheckPass(Result);
      end;


    function Load_Self_Node:TNode;
      begin
        Result:=Gen_Load_Var(Get_Local_Or_Para_Sym('self'));
        if Result.NodeType=loadn then
          include(TLoadNode(Result).LoadNodeFlags,loadnf_is_self)
        else if Result.NodeType<>errorn then
          InternalError(2020122603);
        TypeCheckPass(Result);
      end;


    function Load_Result_Node:TNode;
      begin
        Result:=Gen_Load_Var(Get_Local_Or_Para_Sym('result'));
        TypeCheckPass(Result);
      end;


    function Load_SafeCallResult_Node: TNode;
      begin
        Result:=Gen_Load_Var(Get_Local_Or_Para_Sym('safecallresult'));
        TypeCheckPass(Result);
      end;


    function Load_Self_Pointer_Node:TNode;
      var
        lSymbol : TAbstractVarSym;
      begin
        lSymbol:=Get_Local_Or_Para_Sym('self');
        Result:=Gen_Load_Var(lSymbol);
        if Assigned(lSymbol) and
           (Is_Object(TAbstractVarSym(lSymbol).vardef) or Is_Record(TAbstractVarSym(lSymbol).vardef)) then
          begin
            if Result.NodeType=loadn then
              include(TLoadNode(Result).LoadNodeFlags,loadnf_load_addr)
            else if Result.NodeType<>errorn then
              InternalError(2020122602);
          end;
        TypeCheckPass(Result);
      end;


    function Load_VMT_Pointer_Node:TNode;
      begin
        Result:=Gen_Load_Var(Get_Local_Or_Para_Sym('vmt'));
        TypeCheckPass(Result);
      end;


    function Is_Self_Node(ANode:TNode):Boolean;
      begin
        Is_Self_Node:=(ANode.NodeType=loadn) and
                      (TLoadNode(ANode).SymTableEntry.typ=paravarsym) and
                      (vo_is_self in TParaVarSym(TLoadNode(ANode).SymTableEntry).VarOptions);
      end;


    function Load_VMT_For_Self_Node(ASelfNode: TNode): TNode;
      var
        lSelfResultDef: TDef;
        lObjectDef: TObjectDef;
        lSelfTemp,
        lVMTTemp: TTempCreateNode;
        lCheckSelf,lNode: TNode;
        lStatement: TStatementNode;
        lBlock: TBlockNode;
        lParams: TCallParaNode;
        lDoCheck,lIsTypeCastedClassRef: Boolean;
      begin
        lSelfResultDef:=ASelfNode.ResultDef;
        case lSelfResultDef.typ of
          classrefdef:
            begin
              lObjectDef:=TObjectDef(TClassRefDef(lSelfResultDef).PointedDef);
            end;
          objectdef:
            lObjectDef:=TObjectDef(lSelfResultDef);
          else
            InternalError(2015052701);
        end;
        lNode:=ASelfNode;
        lIsTypeCastedClassRef:=false;
	if (lNode.NodeType=typeconvn) then
          begin
            while Assigned(lNode) and (lNode.NodeType=typeconvn) and (nf_explicit in TTypeConvNode(lNode).Flags) do
              lNode:=TTypeConvNode(lNode).Left;
            if Assigned(lNode) and (lNode.ResultDef.typ=classrefdef) then
              lIsTypeCastedClassRef:=true;
	  end;
        if Is_ClassHelper(lObjectDef) then
          lObjectDef:=TObjectDef(TObjectDef(lObjectDef).ExtendedDef);
        lDoCheck:=
          not(Is_Interface(lObjectDef)) and
          not(Is_CPPClass(lObjectDef)) and
          not(Is_ObjC_Class_Or_Protocol(lObjectDef)) and
          (([cs_check_object,cs_check_range]*CurrentSettings.LocalSwitches)<>[]);

        lBlock:=nil;
        lStatement:=nil;
        lSelfTemp:=nil;
        if lDoCheck then
          begin
            { check for nil self-pointer }
            lBlock:=InternalStatements(lStatement);
            if Is_Object(lSelfResultDef) then
              begin
                lSelfTemp:=CTempCreateNode.Create_Value(
                  CPointerDef.getreusable(lSelfResultDef),CPointerDef.getreusable(lSelfResultDef).Size,tt_persistent,true,
                  CAddrNode.Create(ASelfNode));
              end
            else
              lSelfTemp:=CTempCreateNode.Create_Value(
                lSelfResultDef,lSelfResultDef.Size,tt_persistent,true,
                ASelfNode);
            AddStatement(lStatement,lSelfTemp);

            { in case of an object, self can only be nil if it's a dereferenced
              node somehow
            }
            if not Is_Object(lSelfResultDef) or
               (ActualTargetNode(@ASelfNode)^.NodeType=derefn) then
              begin
                lCheckSelf:=CTempRefNode.Create(lSelfTemp);
                AddStatement(lStatement,CIfNode.Create(
                  CAddNode.Create(EqualN,
                    CTypeConvNode.Create_Explicit(
                      lCheckSelf,
                      VoidPointerType
                    ),
                    CNilNode.Create),
                  CCallNode.CreateIntern('fpc_objecterror',nil),
                  nil)
                );
              end;
            if Is_Object(lSelfResultDef) then
              ASelfNode:=CDerefNode.Create(CTempRefNode.Create(lSelfTemp))
            else
              ASelfNode:=CTempRefNode.Create(lSelfTemp)
          end;
        { in case of a classref, the "instance" is a pointer
          to pointer to a VMT and there is no vmt field }
        if lIsTypeCastedClassRef or (lSelfResultDef.typ=classrefdef) then
          Result:=ASelfNode
        { get the VMT field in case of a class/object }
        else if (lSelfResultDef.typ=objectdef) and
           Assigned(TObjectDef(lSelfResultDef).VMTField) then
          Result:=CSubscriptNode.Create(TObjectDef(lSelfResultDef).VMTField,ASelfNode)
        { in case of an interface, the "instance" is a pointer to a pointer
          to a VMT -> dereference once already }
        else
          { in case of an interface/classref, the "instance" is a pointer
            to pointer to a VMT and there is no vmt field }
          Result:=CDerefNode.Create(
            CTypeConvNode.Create_Explicit(
              ASelfNode,
              CPointerDef.getreusable(VoidPointerType)
            )
          );
        Result:=CTypeConvNode.Create_Explicit(
          Result,
          CPointerDef.getreusable(lObjectDef.VMT_Def));
        TypeCheckPass(Result);
        if lDoCheck then
          begin
            { add a vmt validity check }
            lVMTTemp:=CTempCreateNode.Create_Value(Result.ResultDef,Result.ResultDef.Size,tt_persistent,true,Result);
            AddStatement(lStatement,lVMTTemp);
            lParams:=CCallParaNode.Create(CTempRefNode.Create(lVMTTemp),nil);
            if cs_check_object in CurrentSettings.LocalSwitches then
              begin
                lParams:=CCallParaNode.Create(
                  CLoadVMTAddrNode.Create(CTypeNode.Create(lObjectDef)),
                  lParams
                );
                AddStatement(lStatement,
                  CCallNode.CreateIntern(
                    'fpc_check_object_ext',lParams
                  )
                );
              end
            else
              AddStatement(lStatement,
                CCallNode.CreateIntern(
                  'fpc_check_object',lParams
                )
              );
            AddStatement(lStatement,CTempDeleteNode.Create_Normal_Temp(lVMTTemp));
            AddStatement(lStatement,CTempDeleteNode.Create(lSelfTemp));
            AddStatement(lStatement,CTempRefNode.Create(lVMTTemp));
            Result:=lBlock;
          end
      end;


    { this function must return a very high value ("infinity") for   }
    { trees containing a call, the rest can be balanced more or less }
    { at will, probably best mainly in terms of required memory      }
    { accesses                                                       }
    function Node_Complexity(ANode: TNode): Cardinal;

    {$ifdef x86}
      function ConstSetComplexity(ASetNode: TSetConstNode): Cardinal;
        var
          lIndex,lMaxRanges,lLastValue: Cardinal;
        begin
          { maxranges value should match the logic in nx86set.pas:tx86innode.pass_generate_code.analizeset. }
          if Is_SmallSet(ASetNode.ResultDef) then
            lMaxRanges:=3
          else if cs_opt_size in CurrentSettings.OptimizerSwitches then
            lMaxRanges:=8
          else
            lMaxRanges:=5;

          Result:=0;
          lLastValue:=High(lLastValue)-1;
          for lIndex:=TSetDef(ASetNode.ResultDef).SetBase to TSetDef(ASetNode.ResultDef).SetMax do
            if lIndex in ASetNode.ValueSet^ then
              begin
                if lIndex<>lLastValue+1 then
                  begin
                    inc(Result);
                    if Result>lMaxRanges then
                      exit(3);
                  end;
                lLastValue:=lIndex;
              end;
        end;
    {$endif}

      var
        lComplexity : Cardinal;
      begin
        lComplexity:=0;
        Result:=cNodeComplexityInf; { For early exits by default. }
        while Assigned(ANode) and (lComplexity<cNodeComplexityInf) do { break = return cv, exit = return NODE_COMPLEXITY_INF. }
          begin
            case ANode.NodeType of
              { floating point constants usually need loading from memory }
              realconstn:
                begin
                  inc(lComplexity,2);
                  break;
                end;
              temprefn:
                begin
                  if (TTempRefNode(ANode).TempInfo^.TypeDef.NeedsInitTable) or
                    not(ti_may_be_in_reg in TTempRefNode(ANode).TempFlags) then
                    inc(lComplexity);
                  break;
                end;
              rttin,
              setconstn,
              stringconstn,
              loadvmtaddrn,
              { main reason for the next one: we can't take the address of }
              { loadparentfpnode, so replacing it by a temp which is the   }
              { address of this node's location and then dereferencing     }
              { doesn't work. If changed, check whether tbs/tw0935      }
              { still works with nodeinlining (JM)                         }
              loadparentfpn:
                begin
                  inc(lComplexity);
                  break;
                end;
              loadn:
                begin
                  if Assigned(TLoadNode(ANode).Left) then
                    inc(lComplexity,Node_Complexity(TLoadNode(ANode).Left));
                  { threadvars need a helper call }
                  if (TLoadNode(ANode).SymTableEntry.typ=staticvarsym) and
                     (vo_is_thread_var in TStaticVarSym(TLoadNode(ANode).SymTableEntry).VarOptions) then
                    inc(lComplexity,5)
                  else if not((TLoadNode(ANode).SymTableEntry.typ in [staticvarsym,localvarsym,paravarsym,FieldVarSym]) and
                    (TAbstractVarSym(TLoadNode(ANode).SymTableEntry).VarRegable in [vr_intreg,vr_mmreg,vr_fpureg])) then
                    inc(lComplexity);
                  if (TLoadNode(ANode).SymTableEntry.typ=paravarsym) and
                     not(TAbstractVarSym(TLoadNode(ANode).SymTableEntry).VarRegable=vr_addr) and
                     TLoadNode(ANode).Is_Addr_Param_Load then
                    inc(lComplexity);
                  ANode:=nil; { Check for NODE_COMPLEXITY_INF and return cv. }
                end;
              subscriptn:
                begin
                  if Is_Implicit_Pointer_Object_Type(TUnaryNode(ANode).Left.ResultDef) or
                    Is_BitPacked_Access(ANode) then
                    inc(lComplexity,2)
                  { non-packed, int. regable records cause no extra
                    overhead no overhead if the fields are aligned to register boundaries }
                  else if TStoredDef(ANode.ResultDef).Is_IntRegable and (TSubscriptNode(ANode).FieldSym.FieldOffset mod sizeof(aint)<>0) then
                    inc(lComplexity,1);
                  ANode:=TUnaryNode(ANode).Left;
                end;
              blockn:
                ANode:=TUnaryNode(ANode).Left;
              callparan:
                begin
                  { call to decr? }
                  if Is_Managed_Type(TUnaryNode(ANode).Left.ResultDef) and
                     Assigned(TCallParaNode(ANode).ParaSym) and (TCallParaNode(ANode).ParaSym.VarSpez=vs_out) then
                    exit;
                  inc(lComplexity);
                  ANode:=TUnaryNode(ANode).Left;
                end;
              notn,
              derefn,
              addrn :
                begin
                  inc(lComplexity);
                  ANode:=TUnaryNode(ANode).Left;
                end;
              typeconvn:
                begin
                  { may be more complex in some cases }
                  if not(TTypeConvNode(ANode).Retains_Value_Location) and
                    not((TTypeConvNode(ANode).ConvType=tc_pointer_2_array) and (TTypeConvNode(ANode).Left.expectloc in [LOC_CREGISTER,LOC_REGISTER,LOC_CONSTANT])) then
                    inc(lComplexity);
                  ANode:=TUnaryNode(ANode).Left;
                end;
              statementn:
                begin
                  inc(lComplexity,Node_Complexity(TBinaryNode(ANode).Left));
                  ANode:=TBinaryNode(ANode).Right;
                end;
              addn,subn,orn,andn,xorn,symdifn,
              shln,shrn,
              EqualN,unequaln,gtn,gten,ltn,lten,
              assignn,vecn:
                begin
                  inc(lComplexity,Node_Complexity(TBinaryNode(ANode).Left)+1);
                  ANode:=TBinaryNode(ANode).Right;
                end;
              muln:
                begin
                  inc(lComplexity,Node_Complexity(TBinaryNode(ANode).Left)+{$ifdef CPU64BITALU}4{$else}8{$endif});
                  ANode:=TBinaryNode(ANode).Right;
                end;
              divn,modn,slashn:
                begin
                  inc(lComplexity,Node_Complexity(TBinaryNode(ANode).Left)+{$ifdef CPU64BITALU}10{$else}20{$endif});
                  ANode:=TBinaryNode(ANode).Right;
                end;
              inn:
                begin
                  inc(lComplexity,Node_Complexity(TInNode(ANode).Left));
{$ifdef x86}
                  if TInNode(ANode).Right.NodeType=setconstn then
                    begin
                      inc(lComplexity,ConstSetComplexity(TSetConstNode(TInNode(ANode).Right)));
                      break;
                    end;
{$endif x86}
                  inc(lComplexity,3);
                  ANode:=TBinaryNode(ANode).Right;
                end;
              ordconstn:
                begin
                  break;
                end;
              exitn:
                begin
                  inc(lComplexity,2);
                  ANode:=TExitNode(ANode).Left;
                end;
              tempcreaten,
              tempdeleten,
              pointerconstn,
              nothingn,
              niln:
                break;
              inlinen:
                begin
                  { this code assumes that the inline node has   }
                  { already been firstpassed, and consequently   }
                  { that inline nodes which are transformed into }
                  { calls already have been transformed          }
                  case TInlineNode(ANode).InlineNumber of
                    in_lo_qword,
                    in_hi_qword,
                    in_lo_long,
                    in_hi_long,
                    in_lo_word,
                    in_hi_word,
                    in_length_x,
                    in_assigned_x,
                    in_pred_x,
                    in_succ_x,
                    in_round_real,
                    in_trunc_real,
                    in_int_real,
                    in_frac_real,
                    in_pi_real,
                    in_abs_real,
                    in_aligned_x,
                    in_unaligned_x,
                    in_volatile_x,
                    in_prefetch_var:
                      begin
                        inc(lComplexity);
                        ANode:=TUnaryNode(ANode).Left;
                      end;
                    in_cos_real,
                    in_sin_real,
                    in_arctan_real,
                    in_sqrt_real,
                    in_ln_real:
                      begin
                        inc(lComplexity,15);
                        ANode:=TUnaryNode(ANode).Left;
                      end;
                    in_sqr_real:
                      begin
                        inc(lComplexity,2);
                        ANode:=TUnaryNode(ANode).Left;
                      end;
                    in_abs_long:
                      begin
                        inc(lComplexity,3);
                        ANode:=TUnaryNode(ANode).Left;
                      end;
                    in_sizeof_x,
                    in_typeof_x:
                      begin
                        inc(lComplexity);
                        if (TInlineNode(ANode).Left.NodeType<>typen) then
                          { get instance vmt }
                          ANode:=TUnaryNode(ANode).Left
                        else
                          { type vmt = global symbol, result is }
                          { already increased above             }
                          break;
                      end;
                    { load from global symbol }
                    in_typeinfo_x,
                    { load frame pointer }
                    in_get_frame,
                    in_get_caller_frame,
                    in_get_caller_addr:
                      begin
                        inc(lComplexity);
                        break;
                      end;

                    in_ror_x,
                    in_ror_x_y,
                    in_rol_x,
                    in_rol_x_y,
                    in_inc_x,
                    in_dec_x,
                    in_include_x_y,
                    in_exclude_x_y,
                    in_assert_x_y :
                      begin
                        { operation (add, sub, or, and }
                        inc(lComplexity);
                        { rox_x has no call para node, so check for this }
                        if TUnaryNode(ANode).Left.NodeType=callparan then
                          begin
                            { left expression }
                            inc(lComplexity,Node_Complexity(TCallParaNode(TUnaryNode(ANode).Left).Left));
                            ANode:=TCallParaNode(TUnaryNode(ANode).Left).Right;
                            if Assigned(ANode) then
                              ANode:=TCallParaNode(ANode).Left;
                          end
                        else
                          ANode:=TUnaryNode(ANode).Left;
                      end;
                    else
                      exit;
                  end;
                end;
              else
                exit;
            end;
        end;
        if lComplexity>cNodeComplexityInf then
          lComplexity:=cNodeComplexityInf;
        Result:=lComplexity;
      end;


    { this function returns an indication how much fpu registers
      will be required.
      Note: The algorithms need to be pessimistic to prevent a
      fpu stack overflow on i386 }
    function Node_Resources_FPU(ANode: TNode): Cardinal;
      var
        lResources1,lResources2,lResources3 : Cardinal;
      begin
        Result:=0;
        lResources1:=0;
        lResources2:=0;
        lResources3:=0;
        if ANode.inheritsfrom(TUnaryNode) then
          begin
            if Assigned(TUnaryNode(ANode).Left) then
              lResources1:=Node_Resources_FPU(TUnaryNode(ANode).Left);
            if ANode.inheritsfrom(TBinaryNode) then
              begin
                if Assigned(TBinaryNode(ANode).Right) then
                  lResources2:=Node_Resources_FPU(TBinaryNode(ANode).Right);
                if ANode.inheritsfrom(TTertiaryNode) and Assigned(TTertiaryNode(ANode).Third) then
                  lResources3:=Node_Resources_FPU(TTertiaryNode(ANode).Third)
              end;
          end;
        Result:=max(max(lResources1,lResources2),lResources3);
        case ANode.NodeType of
          calln:
            { it could be a recursive call, so we never really know the number of used fpu registers }
            Result:=maxfpuregs;
          realconstn,
          typeconvn,
          loadn :
            begin
              if ANode.expectloc in [LOC_CFPUREGISTER,LOC_FPUREGISTER] then
                Result:=max(Result,1);
            end;
          assignn,
          addn,subn,muln,slashn,
          EqualN,unequaln,gtn,gten,ltn,lten :
            begin
              if (TBinaryNode(ANode).Left.expectloc in [LOC_CFPUREGISTER,LOC_FPUREGISTER]) or
                 (TBinaryNode(ANode).Right.expectloc in [LOC_CFPUREGISTER,LOC_FPUREGISTER])then
                Result:=max(Result,2);
              if(ANode.expectloc in [LOC_CFPUREGISTER,LOC_FPUREGISTER]) then
                inc(Result);
            end;
          else
            ;
        end;
      end;


    function SetNodeFilePos(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      begin
        Result:=fen_true;
        ANode.FileInfo:=PFilePosInfo(AArg)^;
      end;


    procedure Node_Tree_Set_FilePos(var ANode:TNode;const AFilePos:TFilePosInfo);
      begin
        ForEachNodeStatic(ANode,@SetNodeFilePos,@AFilePos);
      end;


    function CallSimplify(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      var
        lNode : TNode;
        lTreeChanged : ^Boolean;
      begin
        Result:=fen_false;
        if ANode.inheritsfrom(TLoopNode) and
           not (lnf_simplify_processing in TLoopNode(ANode).LoopFlags) then
          begin
            // Try to simplify condition
            DoInlineSimplify(TLoopNode(ANode).Left);
            // call directly second part below,
            // which might change the loopnode into
            // something else if the condition is a constant node
            include(TLoopNode(ANode).LoopFlags,lnf_simplify_processing);
            CallSimplify(ANode,AArg);
            // Be careful, n might have change node type
            if ANode.inheritsfrom(TLoopNode) then
              exclude(TLoopNode(ANode).LoopFlags,lnf_simplify_processing);
          end
        else
          begin
            lNode:=ANode.Simplify(true);
            if Assigned(lNode) then
              begin
                lTreeChanged := AArg;
                if Assigned(lTreeChanged) then
                  lTreeChanged^:=true
                else
                  InternalError (201008181);
                ANode.free;
                ANode:=lNode;
                TypeCheckPass(ANode);
              end;
          end;
      end;


    { tries to simplify the given node calling the simplify method recursively }
    procedure DoInlineSimplify(var ANode : TNode);
      var
        lTreeChanged : Boolean;
      begin
        // Optimize if code first
        repeat
          lTreeChanged:=false;
          ForEachNodeStatic(pm_postandagain,ANode,@CallSimplify,@lTreeChanged);
        until not(lTreeChanged);
      end;


    function Create_Simplified_Ord_Const(const AValue: TConstExprInt; ADef: TDef; AForInline, ARangeCheck: Boolean): TNode;
      begin
        if not AForInline then
          Result:=GenIntConstNode(AValue)
        else
          Result:=COrdConstNode.Create(AValue,ADef,ARangeCheck);
      end;


    procedure PropAccessList_To_Node(var ANode:TNode;ASymTable:TSymTable;APropAccessList:TPropAccessList);
      var
        lPropItem : PPropAccessListItem;
      begin
        lPropItem:=APropAccessList.FirstSym;
        while Assigned(lPropItem) do
         begin
           case lPropItem^.SLType of
             sl_load :
               begin
                 AddSymRef(lPropItem^.sym);
                 if not Assigned(ASymTable) then
                   ASymTable:=lPropItem^.sym.Owner;
                 if (lPropItem^.sym.typ<>staticvarsym) then
                   begin
                     { p1 can already contain the loadnode of
                       the class variable. When there is no tree yet we
                       may need to load it for with or objects }
                     if not Assigned(ANode) then
                      begin
                        case ASymTable.SymTableType of
                          withsymtable :
                            ANode:=TNode(TWithSymTable(ASymTable).WithRefNode).GetCopy;
                          ObjectSymtable :
                            ANode:=Load_Self_Node;
                          else
                            ;
                        end;
                      end
                   end
                 else
                   begin
                     ANode.free;
                     ANode:=nil;
                   end;
                 if Assigned(ANode) then
                  ANode:=CSubscriptNode.Create(lPropItem^.sym,ANode)
                 else
                  ANode:=CLoadNode.Create(lPropItem^.sym,ASymTable);
               end;
             sl_subscript :
               begin
                 AddSymRef(lPropItem^.sym);
                 ANode:=CSubscriptNode.Create(lPropItem^.sym,ANode);
               end;
             sl_typeconv :
               ANode:=CTypeConvNode.Create_Explicit(ANode,lPropItem^.def);
             sl_absolutetype :
               begin
                 ANode:=CTypeConvNode.Create(ANode,lPropItem^.def);
                 include(ANode.Flags,nf_absolute);
               end;
             sl_vec :
               ANode:=CVecNode.Create(ANode,COrdConstNode.Create(lPropItem^.Value,lPropItem^.ValueDef,true));
             else
               InternalError(200110205);
           end;
           lPropItem:=lPropItem^.next;
         end;
      end;


    function Node_To_PropAccessList(ANode:TNode):TPropAccessList;
      var
        lPropAccessList : TPropAccessList;

        procedure AddNode(ANode:TNode);
        begin
          case ANode.NodeType of
            subscriptn :
              begin
                AddNode(TSubscriptNode(ANode).Left);
                lPropAccessList.AddSym(sl_subscript,TSubscriptNode(ANode).FieldSym);
              end;
            typeconvn :
              begin
                AddNode(TTypeConvNode(ANode).Left);
                if nf_absolute in TTypeConvNode(ANode).Flags then
                  lPropAccessList.AddType(sl_absolutetype,TTypeConvNode(ANode).ToTypeDef)
                else
                  lPropAccessList.AddType(sl_typeconv,TTypeConvNode(ANode).ToTypeDef);
              end;
            vecn :
              begin
                AddNode(TVecNode(ANode).Left);
                if TVecNode(ANode).Right.NodeType=ordconstn then
                  lPropAccessList.AddConst(sl_vec,TOrdConstNode(TVecNode(ANode).Right).Value,TVecNode(ANode).Right.ResultDef)
                else
                  begin
                    Message(parser_e_illegal_expression);
                    { recovery }
                    lPropAccessList.AddConst(sl_vec,0,TVecNode(ANode).Right.ResultDef);
                  end;
             end;
            loadn :
              lPropAccessList.AddSym(sl_load,TLoadNode(ANode).SymTableEntry);
            else
              InternalError(200310282);
          end;
        end;

      begin
        lPropAccessList:=TPropAccessList.Create;
        AddNode(ANode);
        Result:=lPropAccessList;
      end;


    function Handle_StaticField_Access(ASym: TSym; var ANode: TNode): Boolean;

      function HandleGenericStaticFieldAccess:Boolean;
        var
          lTempDef : TStoredDef;
          lProcDef : TProcDef;
        begin
          { in case we have a specialization inside a generic (thus the static var sym does not
            exist) we simply simulate a non static access to avoid unnecessary errors }
          if Assigned(ASym.Owner.DefOwner) and (df_specialization in TStoredDef(ASym.Owner.DefOwner).DefOptions) then
            begin
              lTempDef:=TStoredDef(ASym.Owner.DefOwner);
              while Assigned(lTempDef) do
                begin
                  if df_generic in lTempDef.DefOptions then
                    begin
                      ANode.free;
                      if Assigned(CurrentProcInfo) then
                        begin
                          lProcDef:=CurrentProcInfo.Get_Normal_Proc.procdef;
                          if Assigned(lProcDef) and lProcDef.No_Self_Node then
                            ANode:=CLoadVMTAddrNode.Create(CTypeNode.Create(lProcDef.struct))
                          else
                            ANode:=Load_Self_Node;
                        end
                      else
                        ANode:=Load_Self_Node;
                      ANode:=CSubscriptNode.Create(ASym,ANode);
                      exit(true);
                    end;
                  lTempDef:=TStoredDef(lTempDef.Owner.DefOwner);
                end;
            end;
          Result:=false;
        end;

      var
        lStaticName: ShortString;
        lSymTable: TSymTable;
      begin
        Result:=false;
        { generate access code }
        if (sp_static in ASym.SymOptions) then
          begin
            Result:=true;
            if HandleGenericStaticFieldAccess then
              exit;
            lStaticName:=lower(Generate_Nested_Name(ASym.Owner,'_'))+'_'+ASym.name;
            if ASym.Owner.DefOwner.typ=objectdef then
              SearchSym_In_Class(TObjectDef(ASym.Owner.DefOwner),TObjectDef(ASym.Owner.DefOwner),lStaticName,ASym,lSymTable,[ssf_search_helper])
            else
              SearchSym_In_Record(TRecordDef(ASym.Owner.DefOwner),lStaticName,ASym,lSymTable);
            if Assigned(ASym) then
              Check_Hints(ASym,ASym.SymOptions,ASym.DeprecatedMsg);
            ANode.free;
            ANode:=nil;
            { static syms are always stored as absolutevarsym to handle scope and storage properly }
            PropAccessList_To_Node(ANode,nil,TAbsoluteVarSym(ASym).Ref);
          end;
      end;


    function Is_BitPacked_Access(ANode: TNode): Boolean;
      begin
        case ANode.NodeType of
          vecn:
            Result:=
              Is_Packed_Array(TVecNode(ANode).Left.ResultDef) and
              { only orddefs and enumdefs are actually bitpacked. Don't consider
                e.g. an access to a 3-byte record as "bitpacked", since it
                isn't }
              (TVecNode(ANode).Left.ResultDef.typ = arraydef) and
              (TArrayDef(TVecNode(ANode).Left.ResultDef).ElementDef.typ in [orddef,enumdef]) and
              not(TArrayDef(TVecNode(ANode).Left.ResultDef).ElePackedBitSize in [8,16,32,64]);
          subscriptn:
            Result:=
              Is_Packed_Record_Or_Object(TSubscriptNode(ANode).Left.ResultDef) and
              { see above }
              (TSubscriptNode(ANode).FieldSym.vardef.typ in [orddef,enumdef]) and
              (not(TSubscriptNode(ANode).FieldSym.vardef.PackedBitSize in [8,16,32,64]) or
               (TSubscriptNode(ANode).FieldSym.FieldOffset mod 8 <> 0));
          else
            Result:=false;
        end;
      end;


    function GenLoadField(ANode: TNode; const AFieldName: string): TNode;
      var
        lVarSym         : TSym;
      begin
        if not Assigned(ANode.ResultDef) then
          TypeCheckPass(ANode);
        lVarSym:=TSym(TAbstractRecordDef(ANode.ResultDef).SymTable.find(AFieldName));
        if not Assigned(lVarSym) or
           (lVarSym.typ<>FieldVarSym) then
          InternalError(2010061902);
        Result:=CSubscriptNode.Create(lVarSym,ANode);
      end;


    function Has_No_Code(ANode : TNode) : Boolean;
      begin
        if ANode=nil then
          begin
            Result:=true;
            exit;
          end;
        case ANode.NodeType of
          nothingn:
            begin
               Result:=true;
               exit;
            end;
          blockn:
            begin
              Result:=Has_No_Code(TBlockNode(ANode).Left);
              exit;
            end;
          statementn:
            begin
              repeat
                Result:=Has_No_Code(TStatementNode(ANode).Left);
                ANode:=TStatementNode(ANode).Right;
              until not(Result) or not Assigned(ANode);
              exit;
            end;
          else
            Result:=false;
        end;
      end;


    function CheckForSideEffect(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      begin
        Result:=fen_false;
        if (ANode.NodeType in [assignn,calln,asmn,finalizetempsn]) or
           ((ANode.NodeType=inlinen) and
            TInlineNode(ANode).May_Have_SideEffect_NoRecurse
           ) or
           ((mhs_exceptions in PMHSFlags(AArg)^) and
            ((ANode.NodeType in [derefn,vecn,divn,slashn]) or
             ((ANode.NodeType=subscriptn) and Is_Implicit_Pointer_Object_Type(TSubscriptNode(ANode).Left.ResultDef)) or
             ((ANode.NodeType in [addn,subn,muln,unaryminusn]) and (ANode.LocalSwitches*[cs_check_overflow,cs_check_range]<>[])) or
             { float operations could throw an exception }
             ((ANode.NodeType in [addn,subn,muln,slashn,unaryminusn,EqualN,unequaln,gten,gtn,lten,ltn]) and Is_Real_Or_CExtended(TUnaryNode(ANode).Left.ResultDef))
            )
           ) or
           ((ANode.NodeType=loadn) and
            (
             ((TLoadNode(ANode).SymTableEntry.typ=absolutevarsym) and (TAbsoluteVarSym(TLoadNode(ANode).SymTableEntry).AbsTyp=toaddr)) or
             ((TLoadNode(ANode).SymTableEntry.typ in [paravarsym,localvarsym,staticvarsym]) and
               (vo_volatile in TAbstractVarSym(TLoadNode(ANode).SymTableEntry).VarOptions)
             )
            )
           ) or
           { foreachonode does not recurse into the init code for temprefnode as this is done for
             by the tempcreatenode but the considered tree might not contain the tempcreatenode so play
             save and recurrence into the init code if there is any }
           ((ANode.NodeType=temprefn) and (ti_executeinitialisation in TTempRefNode(ANode).TempFlags) and
            Might_Have_SideEffects(TTempRefNode(ANode).TempInfo^.TempInitCode,PMHSFlags(AArg)^)) then
           Result:=fen_norecurse_true
      end;


    function Might_Have_SideEffects(ANode : TNode; const AFlags : TMHSFlags) : Boolean;
      begin
        Result:=ForEachNodeStatic(ANode,@CheckForSideEffect,@AFlags);
      end;


    function CheckForConditionalNodes(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      begin
        Result:=fen_false;
        { this check is not complete yet, but sufficient to cover the current use case: swapping
          of trees in expressions }
        if (ANode.NodeType in [ifn,whilerepeatn,forn,tryexceptn]) or
          ((ANode.NodeType in [orn,andn]) and Is_Boolean(ANode.ResultDef) and DoShortBoolEval(ANode)) then
          Result:=fen_norecurse_true;
      end;


    function Has_Conditional_Nodes(ANode : TNode) : Boolean;
      begin
        Result:=ForEachNodeStatic(ANode,@CheckForConditionalNodes,nil);
      end;


    function DoNodeCount(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      begin
        if PDWord(AArg)^>0 then
          begin
            dec(PDWord(AArg)^);
            Result:=fen_false;
          end
        else
          Result:=fen_norecurse_false;
      end;


    function Node_Count(ANode : TNode; AMax : DWord = High(DWord)) : DWord;
      var
        lRemaining : DWord;
      begin
        lRemaining:=AMax;
        ForEachNodeStatic(ANode,@DoNodeCount,@lRemaining);
        Result:=AMax-lRemaining;
      end;


    function CountNodeWeighted(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      begin
        if PDWord(AArg)^>0 then
          begin
            if not(ANode.NodeType in [blockn,statementn,callparan,nothingn]) then
              dec(PDWord(AArg)^);
            Result:=fen_false;
          end
        else
          Result:=fen_norecurse_false;
      end;


    function Node_Count_Weighted(ANode : TNode; AMax : DWord = High(DWord)) : DWord;
      var
        lRemaining : DWord;
      begin
        lRemaining:=AMax;
        ForEachNodeStatic(ANode,@CountNodeWeighted,@lRemaining);
        Result:=AMax-lRemaining;
      end;


    function Is_Const(ANode : TNode) : Boolean;
      begin
        Result:=Is_ConstNode(ANode) or
          ((ANode.NodeType=temprefn) and (ti_const in TTempRefNode(ANode).TempFlags)) or
          ((ANode.NodeType=loadn) and (TLoadNode(ANode).SymTableEntry.typ=paravarsym) and (TParaVarSym(TLoadNode(ANode).SymTableEntry).VarSpez in [vs_const,vs_constref]));
      end;


    function ActualTargetNode(ANode : PNode) : PNode;
      begin
        Result:=ANode;
        case ANode^.NodeType of
          typeconvn:
            if TTypeConvNode(ANode^).Retains_Value_Location then
              Result:=ActualTargetNode(@TTypeConvNode(ANode^).Left);
          else
            ;
        end;
      end;


    procedure ReplaceNode(var ADest,ASrc : TNode);
      var
        lNode : TNode;
      begin
        lNode:=ASrc;
        { set src nil before free'ing dest because
          src could be part of dest }
        ASrc:=nil;
        ADest.Free;
        ADest:=lNode;
      end;


    function Get_Open_Const_Array(ANode : TNode) : TNode;
      begin
        Result:=ANode;
        if (ANode.NodeType=derefn) and (TDerefNode(ANode).Left.NodeType=addrn) then
          Result:=Get_Open_Const_Array(TAddrNode(TDerefNode(Result).Left).Left);
      end;

    type
      TFlagSet = record
        NodeFlags : TNodeFlags;
        TransientFlags : TTransientNodeFlags;
      end;


    function ResetNodeFlags(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      begin
        Result:=fen_false;
        ANode.Flags:=ANode.Flags-TFlagSet(AArg^).NodeFlags;
        ANode.TransientFlags:=ANode.TransientFlags-TFlagSet(AArg^).TransientFlags;
      end;


    procedure Node_Reset_Flags(ANode : TNode; ANodeFlags : TNodeFlags; ATransientFlags : TTransientNodeFlags);
      var
        lFlagSet: TFlagSet;
      begin
        lFlagSet.NodeFlags:=ANodeFlags;
        lFlagSet.TransientFlags:=ATransientFlags;
        ForEachNodeStatic(ANode,@ResetNodeFlags,@lFlagSet);
      end;

    type
       TLocalSwitchChange = record
         Switch : TLocalSwitch;
         Enable : Boolean;
       end;
       PLocalSwitchChange = ^TLocalSwitchChange;


    function ChangeLocalSettings(var ANode : TNode;ASwitchChange : Pointer) : TForEachNodeResult;
      begin
        if PLocalSwitchChange(ASwitchChange)^.Enable then
          include(ANode.LocalSwitches, PLocalSwitchChange(ASwitchChange)^.Switch)
        else
          exclude(ANode.LocalSwitches, PLocalSwitchChange(ASwitchChange)^.Switch);
        Result:=fen_true;
     end;


    procedure Node_Change_Local_Switch(ANode : TNode;ASwitch : TLocalSwitch;AEnable : Boolean);
      var
        lSwitchChange : TLocalSwitchChange;
      begin
        lSwitchChange.Switch:=ASwitch;
        lSwitchChange.Enable:=AEnable;
        ForEachNodeStatic(ANode,@ChangeLocalSettings,@lSwitchChange);
      end;


    function DoShortBoolEval(ANode : TNode) : Boolean;
      begin
        Result:=(ANode.NodeType in [orn,andn]) and ((anf_short_bool in TAddNode(ANode).AddNodeFlags) or not(cs_full_boolean_eval in ANode.LocalSwitches));
      end;


    function Is_ConstIntValue(ANode: TNode; AValue: TConstExprInt): Boolean;
      begin
        Result:=Is_ConstIntNode(ANode) and (TOrdConstNode(ANode).Value=AValue);
      end;


    function Get_Int_Value(ANode: TNode): TConstExprInt;
      begin
        case ANode.NodeType of
          ordconstn:
            Result:=TOrdConstNode(ANode).Value;
          pointerconstn:
            Result:=TPointerConstNode(ANode).Value;
          niln:
            Result:=0;
          else
            InternalError(2002080202);
        end;
      end;


    function Is_InlineFunction(ANode: TNode; AInlineNumber: TInlineNumber): Boolean;
      begin
        Result:=(ANode.NodeType=inlinen) and (TInlineNode(ANode).InlineNumber=AInlineNumber);
      end;


    { checks if p is a series of length(a) statements, if yes, they are returned
      in a and the function returns true }
    function GetStatements(ANode : TNode;var AStatements : array of TStatementNode) : Boolean;
      var
        lIndex: Integer;
      begin
        Result:=false;
        for lIndex:=0 to high(AStatements) do
          begin
            if not(Assigned(ANode)) or not(ANode.NodeType=statementn) then
              exit;
            AStatements[lIndex]:=TStatementNode(ANode);
            ANode:=TStatementNode(ANode).Right;
          end;
        Result:=true;
      end;


    function IsSingleStatement(ANode: TNode; var AStatement: TNode): Boolean;
      begin
        Result:=false;
        if Assigned(ANode) then
          case ANode.NodeType of
            blockn:
              Result:=IsSingleStatement(TBlockNode(ANode).statements,AStatement);
            statementn:
              if not(Assigned(TStatementNode(ANode).next)) then
                begin
                  Result:=true;
                  AStatement:=TStatementNode(ANode).statement;
                end;
            inlinen,
            assignn,
            calln:
              begin
                AStatement:=ANode;
                Result:=true;
              end
            else
              ;
          end;
      end;


    { gets the last statement in a sequence of statements/blocks }
    function GetLastStatement(ANode : TNode) : TNode;
      var
        lIndex: Integer;
      begin
        Result:=ANode;
        while Assigned(Result) do
          begin
            if Result.NodeType=statementn then
              begin
                if Assigned(TStatementNode(Result).next) then
                  Result:=TStatementNode(Result).next
                else if TStatementNode(Result).statement.NodeType=blockn then
                  Result:=TBlockNode(TStatementNode(Result).Left).statements
                else
                  begin
                    Result:=TStatementNode(Result).statement;
                    exit;
                  end;
              end
            else if Result.NodeType=blockn then
              Result:=TBlockNode(Result).statements
            else
              exit;
          end;
      end;


    function MatchAndTransformNodesCommutative(ANode1,ANode2 : TNode;AMatchProc : TMatchProc2;ATransformProc : TTransformProc2;var AResult : TNode) : Boolean;
      begin
        AResult:=nil;
        Result:=true;
        if AMatchProc(ANode1,ANode2) then
          AResult:=ATransformProc(ANode1,ANode2)
        else if AMatchProc(ANode2,ANode1) then
          AResult:=ATransformProc(ANode2,ANode1)
        else
          Result:=false;
      end;


    function MatchAndTransformNodesCommutative(ANode1,ANode2,ANode3,ANode4 : TNode;AMatchProc : TMatchProc4;ATransformProc : TTransformProc4;var AResult : TNode) : Boolean;
      begin
        AResult:=nil;
        Result:=true;
        if AMatchProc(ANode1,ANode2,ANode3,ANode4) then
          AResult:=ATransformProc(ANode1,ANode2,ANode3,ANode4)
        else if AMatchProc(ANode1,ANode2,ANode4,ANode3) then
          AResult:=ATransformProc(ANode1,ANode2,ANode4,ANode3)
        else if AMatchProc(ANode2,ANode1,ANode3,ANode4) then
          AResult:=ATransformProc(ANode2,ANode1,ANode3,ANode4)
        else if AMatchProc(ANode2,ANode1,ANode4,ANode3) then
          AResult:=ATransformProc(ANode2,ANode1,ANode4,ANode3)
        else if AMatchProc(ANode3,ANode4,ANode1,ANode2) then
          AResult:=ATransformProc(ANode3,ANode4,ANode1,ANode2)
        else if AMatchProc(ANode4,ANode3,ANode1,ANode2) then
          AResult:=ATransformProc(ANode4,ANode3,ANode1,ANode2)
        else if AMatchProc(ANode3,ANode4,ANode2,ANode1) then
          AResult:=ATransformProc(ANode3,ANode4,ANode2,ANode1)
        else if AMatchProc(ANode4,ANode3,ANode2,ANode1) then
          AResult:=ATransformProc(ANode4,ANode3,ANode2,ANode1)
        else
          Result:=false;
      end;


     function ResetNodePass1Write(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
       begin
         Result := fen_false;
         ANode.Flags := ANode.Flags - [nf_write,nf_modify];
         ANode.TransientFlags := ANode.TransientFlags - [tnf_pass1_done];
         if ANode.NodeType = assignn then
           begin
             { Force re-evaluation of assignments so nf_modify and nf_write
               flags are correctly set. }
             ANode.ResultDef := nil;
             Result := fen_true;
           end;
       end;


     procedure Node_Reset_Pass1_Write(ANode: TNode);
       begin
         ForEachNodeStatic(ANode,@ResetNodePass1Write,nil);
       end;


     function Node_In_List(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
       begin
         if (ANode.NodeType in PNodeTypeSet(AArg)^) then
           Result := fen_norecurse_true
         else
           Result := fen_false;
       end;


     function Has_Node_Of_Type(ANode: TNode; ATypeList: TNodeTypeSet): Boolean;
       begin
         Result := ForEachNodeStatic(ANode, @Node_In_List, @ATypeList);
       end;


     function Node_Not_Zero(ANode: TNode): Boolean;
       begin
         Result:=(Is_ConstIntNode(ANode) and (Get_Int_Value(ANode)<>0)) or
           ((ANode.ResultDef.typ=orddef) and ((TOrdDef(ANode.ResultDef).low>0) or (TOrdDef(ANode.ResultDef).high<0))) or
           ((ANode.NodeType=typeconvn) and (TTypeConvNode(ANode).ConvType=tc_int_2_int) and (ANode.ResultDef.Size>=TTypeConvNode(ANode).ResultDef.Size) and Node_Not_Zero(TTypeConvNode(ANode).Left)) or
           ((ANode.NodeType=orn) and (Node_Not_Zero(TAddNode(ANode).Left) or Node_Not_Zero(TAddNode(ANode).Right)));
       end;

end.
