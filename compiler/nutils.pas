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
    NODE_COMPLEXITY_INF = 255;

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

    TForEachNodeFunction = function(var n: TNode; arg: pointer): TForEachNodeResult of object;
    TStaticForEachNodeFunction = function(var n: TNode; arg: pointer): TForEachNodeResult;

    function foreachnode(var n: TNode; f: TForEachNodeFunction; arg: pointer): boolean;
    function foreachnode(procmethod : TForEachProcMethod; var n: TNode; f: TForEachNodeFunction; arg: pointer): boolean;
    function foreachnodestatic(var n: TNode; f: TStaticForEachNodeFunction; arg: pointer): boolean;
    function foreachnodestatic(procmethod : TForEachProcMethod; var n: TNode; f: TStaticForEachNodeFunction; arg: pointer): boolean;

    { checks if the given node tree contains only nodes of the given type,
      if this isn't the case, an ie is thrown
    }
    procedure checktreenodetypes(n : TNode;typeset : TNodeTypeSet);

    procedure load_procvar_from_calln(var p1:TNode);
    function get_local_or_para_sym(const aname: string): TAbstractVarSym;
    function maybe_call_procvar(var p1:TNode;tponly:boolean):boolean;
    function load_high_value_node(vs:TParaVarSym):TNode;
    function load_self_node:TNode;
    function load_result_node:TNode;
    function load_safecallresult_node:TNode;
    function load_self_pointer_node:TNode;
    function load_vmt_pointer_node:TNode;
    function is_self_node(p:TNode):boolean;
    { create a tree that loads the VMT based on a self-node of an object/class/
      interface }
    function load_vmt_for_self_node(self_node: TNode): TNode;

    function node_complexity(p: TNode): cardinal;
    function node_resources_fpu(p: TNode): cardinal;
    procedure node_tree_set_filepos(var n:TNode;const filepos:TFilePosInfo);

    { tries to simplify the given node after inlining }
    procedure doinlinesimplify(var n : TNode);

    { creates an ordinal constant, optionally based on the result from a
      simplify operation: normally the type is the smallest integer type
      that can hold the value, but when inlining the "def" will be used instead,
      which was determined during an earlier typecheck pass (because the value
      may e.g. be a parameter to a call, which needs to be of the declared
      parameter type) }
    function create_simplified_ord_const(const value: TConstExprInt; def: TDef; forinline, rangecheck: boolean): TNode;

    { returns true if n is only a tree of administrative nodes
      containing no code }
    function has_no_code(n : TNode) : boolean;

    procedure propaccesslist_to_node(var p1:TNode;st:TSymTable;pl:TPropAccessList);
    function node_to_propaccesslist(p1:TNode):TPropAccessList;

    { checks whether sym is a static field and if so, translates the access
      to the appropriate node tree }
    function handle_staticfield_access(sym: TSym; var p1: TNode): boolean;

    { returns true if n is an array element access of a bitpacked array with
      elements of the which the vitsize mod 8 <> 0, or if is a field access
      with bitsize mod 8 <> 0 or bitoffset mod 8 <> 0 of an element in a
      bitpacked structure }
    function is_bitpacked_access(n: TNode): boolean;

    { creates a load of field 'fieldname' in the record/class/...
      represented by n }
    function genloadfield(n: TNode; const fieldname: string): TNode;

    { returns true, if the tree given might have side effects }
    function might_have_sideeffects(n : TNode;const flags : TMHSFlags = []) : boolean;

    { returns true, if n contains nodes which might be conditionally executed }
    function has_conditional_nodes(n : TNode) : boolean;

    { count the number of nodes in the node tree,
      rough estimation how large the tree "node" is
      If more than max nodes, returns max, so node_count(n, 10 + 1) <= 10 answers whether the tree has ≤10 nodes but avoids traversing the remaining 990. }
    function node_count(node : TNode; max : dword = High(dword)) : dword;

    function node_count_weighted(node : TNode; max : dword = High(dword)) : dword;

    { returns true, if the value described by node is constant/immutable, this approximation is safe
      if no dirty tricks like buffer overflows or pointer magic are used }
    function is_const(node : TNode) : boolean;

    { returns a pointer to the real node a node refers to,
      skipping (absolute) equal type conversions. Returning
      a pointer allows the caller to move/remove/replace this
      node
    }
    function actualtargetnode(n : PNode) : PNode;

    { moves src into dest, before doing so, right is set to nil and dest is freed.
      Because dest and src are var parameters, this can be done inline in an existing
      node tree }
    procedure replacenode(var dest,src : TNode);

    { strip off deref/addr combinations when looking for a the load node of an open array/array of const
      since there is no possibility to defined a pointer to an open array/array of const, we have not to
      take care of type casts, further, it means also that deref/addr nodes must always appear coupled
    }
    function get_open_const_array(p : TNode) : TNode;

    { excludes the flags passed in nf from the node tree passed }
    procedure node_reset_flags(p : TNode;nf : TNodeFlags; tnf : TTransientNodeFlags);

    { include or exclude cs from p.localswitches }
    procedure node_change_local_switch(p : TNode;cs : TLocalSwitch;enable : boolean);

    { returns true, if p is a node which shall be short boolean evaluated,
      if it is not an orn/andn with boolean operands, the result is undefined }
    function doshortbooleval(p : TNode) : Boolean;

    { returns true if the node has the int value l }
    function is_constintvalue(p : TNode;l : TConstExprInt) : Boolean;

    { if the node is a constant node which can be an int value, this value is returned }
    function get_int_value(p : TNode): TConstExprInt;

    { returns true if the node is an inline node of type i }
    function is_inlinefunction(p : TNode;i : TInlineNumber) : Boolean;

    { checks if p is a series of length(a) statements, if yes, they are returned
      in a and the function returns true }
    function GetStatements(p : TNode;var a : array of TStatementNode) : Boolean;

    { checks if p is a single statement, if yes, it is returned in s }
    function IsSingleStatement(p : TNode;var s : TNode) : Boolean;

    { gets the last statement in a sequence of statements/blocks }
    function GetLastStatement(p : TNode) : TNode;

    type
      TMatchProc2 = function(n1,n2 : TNode) : Boolean is nested;
      TTransformProc2 = function(n1,n2 : TNode) : TNode is nested;
      TMatchProc4 = function(n1,n2,n3,n4 : TNode) : Boolean is nested;
      TTransformProc4 = function(n1,n2,n3,n4 : TNode) : TNode is nested;

    { calls matchproc with n1 and n2 as parameters, if it returns true, transformproc is called, does the same with the nodes swapped,
      the result of transformproc is assigned to res }
    function MatchAndTransformNodesCommutative(n1,n2 : TNode;matchproc : TMatchProc2;transformproc : TTransformProc2;var res : TNode) : Boolean;

    { calls matchproc with n1, n2, n3 and n4 as parameters being considered as the leafs of commutative nodes so all 8 possible
      combinations are tested, if it returns true, transformproc is called,
      the result of transformproc is assigned to res

      this allows to find pattern like (3*a)+(3*b) and transform them into 3*(a+b)
    }
    function MatchAndTransformNodesCommutative(n1,n2,n3,n4 : TNode;matchproc : TMatchProc4;transformproc : TTransformProc4;var res : TNode) : Boolean;

    {
      resets all flags so that nf_write/nf_modify information is regenerated
    }
    procedure node_reset_pass1_write(n: TNode);

    { Returns True if n one of its children has a type that appears in TypeList }
    function has_node_of_type(n: TNode; TypeList: TNodeTypeSet): Boolean; {$IFDEF USEINLINE}inline;{$ENDIF USEINLINE}

    { returns true if n is guranteed not to return an ordinal zero }
    function node_not_zero(n : TNode) : Boolean;


implementation

    uses
      CUtils,Verbose,Globals,
      symconst,symdef,
      defcmp,defutil,
      ncon,ncnv,nld,nflw,nset,ncal,nadd,nmem,ninl,
      cpubase,cgbase,ProcInfo,
      pass_1;

    type
      ForEachNodeContext = object
        procmethod: TForEachProcMethod;
        f: TStaticForEachNodeFunction;
        arg: pointer;
        res: boolean;
        procedure perform(var n: TNode);
        procedure process_children(n: TNode);
        procedure process_casenode(n: TCaseNode);
      end;


    procedure ForEachNodeContext.perform(var n: TNode);
      var
        fr: TForEachNodeResult;
      begin
        if not Assigned(n) then
          exit;
        if procmethod=pm_preprocess then
          process_children(n);

        fr:=f(n,arg);
        res:=(fr in [fen_true, fen_norecurse_true]) or res;
        if fr in [fen_norecurse_false, fen_norecurse_true] then
          exit;

        if procmethod in [pm_postprocess,pm_postandagain] then
          begin
            process_children(n);
            if procmethod=pm_postandagain then
              begin
                fr:=f(n,arg);
                res:=(fr in [fen_true, fen_norecurse_true]) or res;
              end;
          end;
      end;


    procedure ForEachNodeContext.process_children(n: TNode);
      begin
        case n.nodetype of
          asn:
            if Assigned(TAsNode(n).call) then
              begin
                perform(TAsNode(n).call);
                exit
              end;
          calln:
            begin
              perform(TNode(TCallNode(n).callinitblock));
              perform(TCallNode(n).methodpointer);
              perform(TCallNode(n).funcretnode);
              perform(TNode(TCallNode(n).vmt_entry));
              perform(TNode(TCallNode(n).callcleanupblock));
            end;
          callparan:
            begin
              perform(TNode(TCallParaNode(n).fparainit));
              perform(TCallParaNode(n).fparacopyback);
            end;
          ifn, whilerepeatn, forn, tryexceptn:
            begin
              perform(TLoopNode(n).t1);
              perform(TLoopNode(n).t2);
            end;
          raisen, tryfinallyn:
            { frame tree/copy of finally code }
            perform(TTertiaryNode(n).third);
          tempcreaten:
            { temp. initialization code }
            if Assigned(TTempCreateNode(n).tempinfo^.tempinitcode) then
              perform(TTempCreateNode(n).tempinfo^.tempinitcode);
          casen:
            process_casenode(TCaseNode(n));
          else
            ;
        end;
        if n.inheritsfrom(TBinaryNode) then
          begin
            { first process the "payload" of statementnodes }
            perform(TBinaryNode(n).left);
            perform(TBinaryNode(n).right);
          end
        else if n.inheritsfrom(TUnaryNode) then
          perform(TUnaryNode(n).left);
      end;


    procedure ForEachNodeContext.process_casenode(n: TCaseNode);
      var
        i: SizeInt;
        block: pointer;
      begin
        for i := 0 to n.blocks.count-1 do
          begin
            block := n.blocks[i];
            if Assigned(block) then
              perform(PCaseBlock(block)^.statement);
          end;
        perform(n.elseblock);
      end;


    { Adapts foreachnodefunction to staticforeachnodefunction. }
    type
      BoundToStaticForEachNodeContext = record
        f: TForEachNodeFunction;
        arg: pointer;
      end;

    function BoundToStaticForEachNodeAdapter(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        adaptCtx: ^BoundToStaticForEachNodeContext absolute arg;
      begin
        result := adaptCtx^.f(n, adaptCtx^.arg);
      end;


    function foreachnode(procmethod : TForEachProcMethod;var n: TNode; f: TForEachNodeFunction; arg: pointer): boolean;
      var
        adaptCtx: BoundToStaticForEachNodeContext;
      begin
        adaptCtx.f := f;
        adaptCtx.arg := arg;
        result:=foreachnodestatic(procmethod,n,@BoundToStaticForEachNodeAdapter,@adaptCtx);
      end;


    function foreachnode(var n: TNode; f: TForEachNodeFunction; arg: pointer): boolean;
      begin
        result:=foreachnode(pm_postprocess,n,f,arg);
      end;


    function foreachnodestatic(procmethod : TForEachProcMethod;var n: TNode; f: TStaticForEachNodeFunction; arg: pointer): boolean;
      var
        fen: ForEachNodeContext;
      begin
        fen.procmethod := procmethod;
        fen.f := f;
        fen.arg := arg;
        fen.res := false;
        fen.perform(n);
        result := fen.res;
      end;


    function foreachnodestatic(var n: TNode; f: TStaticForEachNodeFunction; arg: pointer): boolean;
      begin
        result:=foreachnodestatic(pm_postprocess,n,f,arg);
      end;


    function do_check(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        if not(n.nodetype in PNodeTypeSet(arg)^) then
          InternalError(200610141);
        result:=fen_true;
      end;


    procedure checktreenodetypes(n : TNode;typeset : TNodeTypeSet);
      begin
        foreachnodestatic(n,@do_check,@typeset);
      end;


    procedure load_procvar_from_calln(var p1:TNode);
      var
        p2 : TNode;
      begin
        if p1.nodetype<>calln then
          InternalError(200212251);
        { was it a procvar, then we simply remove the calln and
          reuse the right }
        if Assigned(TCallNode(p1).right) then
          begin
            p2:=TCallNode(p1).right;
            TCallNode(p1).right:=nil;
          end
        else
          begin
            p2:=CLoadNode.create_procvar(TCallNode(p1).symtableprocentry,
               TProcDef(TCallNode(p1).procdefinition),TCallNode(p1).symtableproc);
            { when the methodpointer is typen we've something like:
              tobject.create. Then only the address is needed of the
              method without a self pointer }
            if Assigned(TCallNode(p1).methodpointer) and
               (TCallNode(p1).methodpointer.nodetype<>typen) then
              TLoadNode(p2).set_mp(TCallNode(p1).methodpointer.GetCopy);
          end;
        TypeCheckPass(p2);
        p1.free;
        p1:=p2;
      end;


    function maybe_call_procvar(var p1:TNode;tponly:boolean):boolean;
      var
        hp : TNode;
      begin
        result:=false;
        if not (p1.resultdef.typ in [procvardef,objectdef]) or
           (
             (p1.resultdef.typ=objectdef) and
             (
               not Is_Invokable(p1.resultdef) or
               (nf_load_procvar in p1.flags) or
               not (
                 Is_FuncRef(p1.resultdef) or
                 Invokable_Has_Argless_Invoke(TObjectDef(p1.resultdef))
               )
             )
           ) or
           (tponly and
            not(m_tp_procvar in CurrentSettings.ModeSwitches)) then
          exit;
        { ignore vecn,subscriptn }
        hp:=p1;
        repeat
          case hp.nodetype of
            vecn,
            derefn,
            typeconvn,
            subscriptn :
              hp:=TUnaryNode(hp).left;
            blockn:
              hp:=laststatement(TBlockNode(hp)).left
            else
              break;
          end;
        until false;
        { a tempref is used when it is loaded from a withsymtable }
        if (hp.nodetype in [calln,loadn,temprefn]) then
          begin
            hp:=CCallNode.create_procvar(nil,p1);
            TypeCheckPass(hp);
            p1:=hp;
            result:=true;
          end;
      end;


    function get_local_or_para_sym(const aname: string): TAbstractVarSym;
      var
        pd: TProcDef;
        ressym: TSym;
      begin
        ressym:=nil;
        result:=nil;
        { is not assigned while parsing a property }
        if not Assigned(CurrentProcInfo) then
          exit;
        { we can't use searchsym here, because the
          symtablestack is not fully setup when pass1
          is run for nested procedures }
        pd:=CurrentProcInfo.procdef;
        repeat
          ressym:=TSym(pd.LocalST.Find(aname));
          if Assigned(ressym) then
            break;
          ressym:=TSym(pd.ParaST.Find(aname));
          if Assigned(ressym) then
            break;
          { try the parent of a nested function }
          if Assigned(pd.owner.DefOwner) and
             (pd.owner.DefOwner.typ=procdef) then
            pd:=TProcDef(pd.owner.DefOwner)
          else
            break;
        until false;
        if Assigned(ressym) and
           not(ressym.typ in [localvarsym,paravarsym]) then
          InternalError(2020122604);
        result:=TAbstractVarSym(ressym);
      end;



    function load_high_value_node(vs:TParaVarSym):TNode;
      begin
        result:=gen_load_var(Get_High_Value_Sym(vs));
        TypeCheckPass(result);
      end;


    function load_self_node:TNode;
      begin
        result:=gen_load_var(get_local_or_para_sym('self'));
        if result.nodetype=loadn then
          include(TLoadNode(result).loadnodeflags,loadnf_is_self)
        else if result.nodetype<>errorn then
          InternalError(2020122603);
        TypeCheckPass(result);
      end;


    function load_result_node:TNode;
      begin
        result:=gen_load_var(get_local_or_para_sym('result'));
        TypeCheckPass(result);
      end;


    function load_safecallresult_node: TNode;
      begin
        result:=gen_load_var(get_local_or_para_sym('safecallresult'));
        TypeCheckPass(result);
      end;


    function load_self_pointer_node:TNode;
      var
        srsym : TAbstractVarSym;
      begin
        srsym:=get_local_or_para_sym('self');
        result:=gen_load_var(srsym);
        if Assigned(srsym) and
           (Is_Object(TAbstractVarSym(srsym).vardef) or Is_Record(TAbstractVarSym(srsym).vardef)) then
          begin
            if result.nodetype=loadn then
              include(TLoadNode(result).loadnodeflags,loadnf_load_addr)
            else if result.nodetype<>errorn then
              InternalError(2020122602);
          end;
        TypeCheckPass(result);
      end;


    function load_vmt_pointer_node:TNode;
      begin
        result:=gen_load_var(get_local_or_para_sym('vmt'));
        TypeCheckPass(result);
      end;


    function is_self_node(p:TNode):boolean;
      begin
        is_self_node:=(p.nodetype=loadn) and
                      (TLoadNode(p).symtableentry.typ=paravarsym) and
                      (vo_is_self in TParaVarSym(TLoadNode(p).symtableentry).VarOptions);
      end;


    function load_vmt_for_self_node(self_node: TNode): TNode;
      var
        self_resultdef: TDef;
        obj_def: TObjectDef;
        self_temp,
        vmt_temp: TTempCreateNode;
        check_self,n: TNode;
        stat: TStatementNode;
        block: TBlockNode;
        paras: TCallParaNode;
        docheck,is_typecasted_classref: boolean;
      begin
        self_resultdef:=self_node.resultdef;
        case self_resultdef.typ of
          classrefdef:
            begin
              obj_def:=TObjectDef(TClassRefDef(self_resultdef).PointedDef);
            end;
          objectdef:
            obj_def:=TObjectDef(self_resultdef);
          else
            InternalError(2015052701);
        end;
        n:=self_node;
        is_typecasted_classref:=false;
	if (n.nodetype=typeconvn) then
          begin
            while Assigned(n) and (n.nodetype=typeconvn) and (nf_explicit in TTypeConvNode(n).flags) do
              n:=TTypeConvNode(n).left;
            if Assigned(n) and (n.resultdef.typ=classrefdef) then
              is_typecasted_classref:=true;
	  end;
        if Is_ClassHelper(obj_def) then
          obj_def:=TObjectDef(TObjectDef(obj_def).ExtendedDef);
        docheck:=
          not(Is_Interface(obj_def)) and
          not(Is_CPPClass(obj_def)) and
          not(Is_ObjC_Class_Or_Protocol(obj_def)) and
          (([cs_check_object,cs_check_range]*CurrentSettings.LocalSwitches)<>[]);

        block:=nil;
        stat:=nil;
        self_temp:=nil;
        if docheck then
          begin
            { check for nil self-pointer }
            block:=internalstatements(stat);
            if Is_Object(self_resultdef) then
              begin
                self_temp:=CTempCreateNode.create_value(
                  CPointerDef.getreusable(self_resultdef),CPointerDef.getreusable(self_resultdef).Size,tt_persistent,true,
                  CAddrNode.create(self_node));
              end
            else
              self_temp:=CTempCreateNode.create_value(
                self_resultdef,self_resultdef.Size,tt_persistent,true,
                self_node);
            addstatement(stat,self_temp);

            { in case of an object, self can only be nil if it's a dereferenced
              node somehow
            }
            if not Is_Object(self_resultdef) or
               (actualtargetnode(@self_node)^.nodetype=derefn) then
              begin
                check_self:=CTempRefNode.create(self_temp);
                addstatement(stat,CIfNode.create(
                  CAddNode.create(EqualN,
                    CTypeConvNode.create_explicit(
                      check_self,
                      VoidPointerType
                    ),
                    CNilNode.create),
                  CCallNode.createintern('fpc_objecterror',nil),
                  nil)
                );
              end;
            if Is_Object(self_resultdef) then
              self_node:=CDerefNode.create(CTempRefNode.create(self_temp))
            else
              self_node:=CTempRefNode.create(self_temp)
          end;
        { in case of a classref, the "instance" is a pointer
          to pointer to a VMT and there is no vmt field }
        if is_typecasted_classref or (self_resultdef.typ=classrefdef) then
          result:=self_node
        { get the VMT field in case of a class/object }
        else if (self_resultdef.typ=objectdef) and
           Assigned(TObjectDef(self_resultdef).VMTField) then
          result:=CSubscriptNode.create(TObjectDef(self_resultdef).VMTField,self_node)
        { in case of an interface, the "instance" is a pointer to a pointer
          to a VMT -> dereference once already }
        else
          { in case of an interface/classref, the "instance" is a pointer
            to pointer to a VMT and there is no vmt field }
          result:=CDerefNode.create(
            CTypeConvNode.create_explicit(
              self_node,
              CPointerDef.getreusable(VoidPointerType)
            )
          );
        result:=CTypeConvNode.create_explicit(
          result,
          CPointerDef.getreusable(obj_def.VMT_Def));
        TypeCheckPass(result);
        if docheck then
          begin
            { add a vmt validity check }
            vmt_temp:=CTempCreateNode.create_value(result.resultdef,result.resultdef.Size,tt_persistent,true,result);
            addstatement(stat,vmt_temp);
            paras:=CCallParaNode.create(CTempRefNode.create(vmt_temp),nil);
            if cs_check_object in CurrentSettings.LocalSwitches then
              begin
                paras:=CCallParaNode.create(
                  CLoadVMTAddrNode.create(CTypeNode.create(obj_def)),
                  paras
                );
                addstatement(stat,
                  CCallNode.createintern(
                    'fpc_check_object_ext',paras
                  )
                );
              end
            else
              addstatement(stat,
                CCallNode.createintern(
                  'fpc_check_object',paras
                )
              );
            addstatement(stat,CTempDeleteNode.create_normal_temp(vmt_temp));
            addstatement(stat,CTempDeleteNode.create(self_temp));
            addstatement(stat,CTempRefNode.create(vmt_temp));
            result:=block;
          end
      end;


    { this function must return a very high value ("infinity") for   }
    { trees containing a call, the rest can be balanced more or less }
    { at will, probably best mainly in terms of required memory      }
    { accesses                                                       }
    function node_complexity(p: TNode): cardinal;

    {$ifdef x86}
      function in_const_set_complexity(cs: TSetConstNode): cardinal;
        var
          i,maxranges,lastv: cardinal;
        begin
          { maxranges value should match the logic in nx86set.pas:tx86innode.pass_generate_code.analizeset. }
          if Is_SmallSet(cs.resultdef) then
            maxranges:=3
          else if cs_opt_size in CurrentSettings.OptimizerSwitches then
            maxranges:=8
          else
            maxranges:=5;

          result:=0;
          lastv:=High(lastv)-1;
          for i:=TSetDef(cs.resultdef).SetBase to TSetDef(cs.resultdef).SetMax do
            if i in cs.value_set^ then
              begin
                if i<>lastv+1 then
                  begin
                    inc(result);
                    if result>maxranges then
                      exit(3);
                  end;
                lastv:=i;
              end;
        end;
    {$endif}

      var
        cv : cardinal;
      begin
        cv:=0;
        result:=NODE_COMPLEXITY_INF; { For early exits by default. }
        while Assigned(p) and (cv<NODE_COMPLEXITY_INF) do { break = return cv, exit = return NODE_COMPLEXITY_INF. }
          begin
            case p.nodetype of
              { floating point constants usually need loading from memory }
              realconstn:
                begin
                  inc(cv,2);
                  break;
                end;
              temprefn:
                begin
                  if (TTempRefNode(p).tempinfo^.typedef.NeedsInitTable) or
                    not(ti_may_be_in_reg in TTempRefNode(p).tempflags) then
                    inc(cv);
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
                  inc(cv);
                  break;
                end;
              loadn:
                begin
                  if Assigned(TLoadNode(p).left) then
                    inc(cv,node_complexity(TLoadNode(p).left));
                  { threadvars need a helper call }
                  if (TLoadNode(p).symtableentry.typ=staticvarsym) and
                     (vo_is_thread_var in TStaticVarSym(TLoadNode(p).symtableentry).VarOptions) then
                    inc(cv,5)
                  else if not((TLoadNode(p).symtableentry.typ in [staticvarsym,localvarsym,paravarsym,FieldVarSym]) and
                    (TAbstractVarSym(TLoadNode(p).symtableentry).VarRegable in [vr_intreg,vr_mmreg,vr_fpureg])) then
                    inc(cv);
                  if (TLoadNode(p).symtableentry.typ=paravarsym) and
                     not(TAbstractVarSym(TLoadNode(p).symtableentry).VarRegable=vr_addr) and
                     TLoadNode(p).is_addr_param_load then
                    inc(cv);
                  p:=nil; { Check for NODE_COMPLEXITY_INF and return cv. }
                end;
              subscriptn:
                begin
                  if Is_Implicit_Pointer_Object_Type(TUnaryNode(p).left.resultdef) or
                    is_bitpacked_access(p) then
                    inc(cv,2)
                  { non-packed, int. regable records cause no extra
                    overhead no overhead if the fields are aligned to register boundaries }
                  else if TStoredDef(p.resultdef).Is_IntRegable and (TSubscriptNode(p).vs.FieldOffset mod sizeof(aint)<>0) then
                    inc(cv,1);
                  p:=TUnaryNode(p).left;
                end;
              blockn:
                p:=TUnaryNode(p).left;
              callparan:
                begin
                  { call to decr? }
                  if Is_Managed_Type(TUnaryNode(p).left.resultdef) and
                     Assigned(TCallParaNode(p).parasym) and (TCallParaNode(p).parasym.VarSpez=vs_out) then
                    exit;
                  inc(cv);
                  p:=TUnaryNode(p).left;
                end;
              notn,
              derefn,
              addrn :
                begin
                  inc(cv);
                  p:=TUnaryNode(p).left;
                end;
              typeconvn:
                begin
                  { may be more complex in some cases }
                  if not(TTypeConvNode(p).retains_value_location) and
                    not((TTypeConvNode(p).convtype=tc_pointer_2_array) and (TTypeConvNode(p).left.expectloc in [LOC_CREGISTER,LOC_REGISTER,LOC_CONSTANT])) then
                    inc(cv);
                  p:=TUnaryNode(p).left;
                end;
              statementn:
                begin
                  inc(cv,node_complexity(TBinaryNode(p).left));
                  p:=TBinaryNode(p).right;
                end;
              addn,subn,orn,andn,xorn,symdifn,
              shln,shrn,
              EqualN,unequaln,gtn,gten,ltn,lten,
              assignn,vecn:
                begin
                  inc(cv,node_complexity(TBinaryNode(p).left)+1);
                  p:=TBinaryNode(p).right;
                end;
              muln:
                begin
                  inc(cv,node_complexity(TBinaryNode(p).left)+{$ifdef CPU64BITALU}4{$else}8{$endif});
                  p:=TBinaryNode(p).right;
                end;
              divn,modn,slashn:
                begin
                  inc(cv,node_complexity(TBinaryNode(p).left)+{$ifdef CPU64BITALU}10{$else}20{$endif});
                  p:=TBinaryNode(p).right;
                end;
              inn:
                begin
                  inc(cv,node_complexity(TInNode(p).left));
{$ifdef x86}
                  if TInNode(p).right.nodetype=setconstn then
                    begin
                      inc(cv,in_const_set_complexity(TSetConstNode(TInNode(p).right)));
                      break;
                    end;
{$endif x86}
                  inc(cv,3);
                  p:=TBinaryNode(p).right;
                end;
              ordconstn:
                begin
                  break;
                end;
              exitn:
                begin
                  inc(cv,2);
                  p:=TExitNode(p).left;
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
                  case TInlineNode(p).inlinenumber of
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
                        inc(cv);
                        p:=TUnaryNode(p).left;
                      end;
                    in_cos_real,
                    in_sin_real,
                    in_arctan_real,
                    in_sqrt_real,
                    in_ln_real:
                      begin
                        inc(cv,15);
                        p:=TUnaryNode(p).left;
                      end;
                    in_sqr_real:
                      begin
                        inc(cv,2);
                        p:=TUnaryNode(p).left;
                      end;
                    in_abs_long:
                      begin
                        inc(cv,3);
                        p:=TUnaryNode(p).left;
                      end;
                    in_sizeof_x,
                    in_typeof_x:
                      begin
                        inc(cv);
                        if (TInlineNode(p).left.nodetype<>typen) then
                          { get instance vmt }
                          p:=TUnaryNode(p).left
                        else
                          { type vmt = global symbol, result is }
                          { already increased above             }
                          break;
                      end;
          {$ifdef SUPPORT_MMX}
                    in_mmx_pcmpeqb..in_mmx_pcmpgtw,
          {$endif SUPPORT_MMX}
                    { load from global symbol }
                    in_typeinfo_x,
                    { load frame pointer }
                    in_get_frame,
                    in_get_caller_frame,
                    in_get_caller_addr:
                      begin
                        inc(cv);
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
                        inc(cv);
                        { rox_x has no call para node, so check for this }
                        if TUnaryNode(p).left.nodetype=callparan then
                          begin
                            { left expression }
                            inc(cv,node_complexity(TCallParaNode(TUnaryNode(p).left).left));
                            p:=TCallParaNode(TUnaryNode(p).left).right;
                            if Assigned(p) then
                              p:=TCallParaNode(p).left;
                          end
                        else
                          p:=TUnaryNode(p).left;
                      end;
                    else
                      exit;
                  end;
                end;
              else
                exit;
            end;
        end;
        if cv>NODE_COMPLEXITY_INF then
          cv:=NODE_COMPLEXITY_INF;
        result:=cv;
      end;


    { this function returns an indication how much fpu registers
      will be required.
      Note: The algorithms need to be pessimistic to prevent a
      fpu stack overflow on i386 }
    function node_resources_fpu(p: TNode): cardinal;
      var
        res1,res2,res3 : cardinal;
      begin
        result:=0;
        res1:=0;
        res2:=0;
        res3:=0;
        if p.inheritsfrom(TUnaryNode) then
          begin
            if Assigned(TUnaryNode(p).left) then
              res1:=node_resources_fpu(TUnaryNode(p).left);
            if p.inheritsfrom(TBinaryNode) then
              begin
                if Assigned(TBinaryNode(p).right) then
                  res2:=node_resources_fpu(TBinaryNode(p).right);
                if p.inheritsfrom(TTertiaryNode) and Assigned(TTertiaryNode(p).third) then
                  res3:=node_resources_fpu(TTertiaryNode(p).third)
              end;
          end;
        result:=max(max(res1,res2),res3);
        case p.nodetype of
          calln:
            { it could be a recursive call, so we never really know the number of used fpu registers }
            result:=maxfpuregs;
          realconstn,
          typeconvn,
          loadn :
            begin
              if p.expectloc in [LOC_CFPUREGISTER,LOC_FPUREGISTER] then
                result:=max(result,1);
            end;
          assignn,
          addn,subn,muln,slashn,
          EqualN,unequaln,gtn,gten,ltn,lten :
            begin
              if (TBinaryNode(p).left.expectloc in [LOC_CFPUREGISTER,LOC_FPUREGISTER]) or
                 (TBinaryNode(p).right.expectloc in [LOC_CFPUREGISTER,LOC_FPUREGISTER])then
                result:=max(result,2);
              if(p.expectloc in [LOC_CFPUREGISTER,LOC_FPUREGISTER]) then
                inc(result);
            end;
          else
            ;
        end;
      end;


    function setnodefilepos(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        result:=fen_true;
        n.fileinfo:=PFilePosInfo(arg)^;
      end;


    procedure node_tree_set_filepos(var n:TNode;const filepos:TFilePosInfo);
      begin
        foreachnodestatic(n,@setnodefilepos,@filepos);
      end;


    function callsimplify(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        hn : TNode;
        treechanged : ^boolean;
      begin
        result:=fen_false;
        if n.inheritsfrom(TLoopNode) and
           not (lnf_simplify_processing in TLoopNode(n).loopflags) then
          begin
            // Try to simplify condition
            doinlinesimplify(TLoopNode(n).left);
            // call directly second part below,
            // which might change the loopnode into
            // something else if the condition is a constant node
            include(TLoopNode(n).loopflags,lnf_simplify_processing);
            callsimplify(n,arg);
            // Be careful, n might have change node type
            if n.inheritsfrom(TLoopNode) then
              exclude(TLoopNode(n).loopflags,lnf_simplify_processing);
          end
        else
          begin
            hn:=n.simplify(true);
            if Assigned(hn) then
              begin
                treechanged := arg;
                if Assigned(treechanged) then
                  treechanged^:=true
                else
                  InternalError (201008181);
                n.free;
                n:=hn;
                TypeCheckPass(n);
              end;
          end;
      end;


    { tries to simplify the given node calling the simplify method recursively }
    procedure doinlinesimplify(var n : TNode);
      var
        treechanged : boolean;
      begin
        // Optimize if code first
        repeat
          treechanged:=false;
          foreachnodestatic(pm_postandagain,n,@callsimplify,@treechanged);
        until not(treechanged);
      end;


    function create_simplified_ord_const(const value: TConstExprInt; def: TDef; forinline, rangecheck: boolean): TNode;
      begin
        if not forinline then
          result:=genintconstnode(value)
        else
          result:=COrdConstNode.create(value,def,rangecheck);
      end;


    procedure propaccesslist_to_node(var p1:TNode;st:TSymTable;pl:TPropAccessList);
      var
        plist : PPropAccessListItem;
      begin
        plist:=pl.FirstSym;
        while Assigned(plist) do
         begin
           case plist^.SLType of
             sl_load :
               begin
                 AddSymRef(plist^.sym);
                 if not Assigned(st) then
                   st:=plist^.sym.owner;
                 if (plist^.sym.typ<>staticvarsym) then
                   begin
                     { p1 can already contain the loadnode of
                       the class variable. When there is no tree yet we
                       may need to load it for with or objects }
                     if not Assigned(p1) then
                      begin
                        case st.SymTableType of
                          withsymtable :
                            p1:=TNode(TWithSymTable(st).WithRefNode).GetCopy;
                          ObjectSymtable :
                            p1:=load_self_node;
                          else
                            ;
                        end;
                      end
                   end
                 else
                   begin
                     p1.free;
                     p1:=nil;
                   end;
                 if Assigned(p1) then
                  p1:=CSubscriptNode.create(plist^.sym,p1)
                 else
                  p1:=CLoadNode.create(plist^.sym,st);
               end;
             sl_subscript :
               begin
                 AddSymRef(plist^.sym);
                 p1:=CSubscriptNode.create(plist^.sym,p1);
               end;
             sl_typeconv :
               p1:=CTypeConvNode.create_explicit(p1,plist^.def);
             sl_absolutetype :
               begin
                 p1:=CTypeConvNode.create(p1,plist^.def);
                 include(p1.flags,nf_absolute);
               end;
             sl_vec :
               p1:=CVecNode.create(p1,COrdConstNode.create(plist^.Value,plist^.ValueDef,true));
             else
               InternalError(200110205);
           end;
           plist:=plist^.next;
         end;
      end;


    function node_to_propaccesslist(p1:TNode):TPropAccessList;
      var
        sl : TPropAccessList;

        procedure addnode(p:TNode);
        begin
          case p.nodetype of
            subscriptn :
              begin
                addnode(TSubscriptNode(p).left);
                sl.AddSym(sl_subscript,TSubscriptNode(p).vs);
              end;
            typeconvn :
              begin
                addnode(TTypeConvNode(p).left);
                if nf_absolute in TTypeConvNode(p).flags then
                  sl.AddType(sl_absolutetype,TTypeConvNode(p).totypedef)
                else
                  sl.AddType(sl_typeconv,TTypeConvNode(p).totypedef);
              end;
            vecn :
              begin
                addnode(TVecNode(p).left);
                if TVecNode(p).right.nodetype=ordconstn then
                  sl.AddConst(sl_vec,TOrdConstNode(TVecNode(p).right).Value,TVecNode(p).right.resultdef)
                else
                  begin
                    Message(parser_e_illegal_expression);
                    { recovery }
                    sl.AddConst(sl_vec,0,TVecNode(p).right.resultdef);
                  end;
             end;
            loadn :
              sl.AddSym(sl_load,TLoadNode(p).symtableentry);
            else
              InternalError(200310282);
          end;
        end;

      begin
        sl:=TPropAccessList.create;
        addnode(p1);
        result:=sl;
      end;


    function handle_staticfield_access(sym: TSym; var p1: TNode): boolean;

      function handle_generic_staticfield_access:boolean;
        var
          tmp : TStoredDef;
          pd : TProcDef;
        begin
          { in case we have a specialization inside a generic (thus the static var sym does not
            exist) we simply simulate a non static access to avoid unnecessary errors }
          if Assigned(sym.owner.DefOwner) and (df_specialization in TStoredDef(sym.owner.DefOwner).DefOptions) then
            begin
              tmp:=TStoredDef(sym.owner.DefOwner);
              while Assigned(tmp) do
                begin
                  if df_generic in tmp.DefOptions then
                    begin
                      p1.free;
                      if Assigned(CurrentProcInfo) then
                        begin
                          pd:=CurrentProcInfo.get_normal_proc.procdef;
                          if Assigned(pd) and pd.No_Self_Node then
                            p1:=CLoadVMTAddrNode.create(CTypeNode.create(pd.struct))
                          else
                            p1:=load_self_node;
                        end
                      else
                        p1:=load_self_node;
                      p1:=CSubscriptNode.create(sym,p1);
                      exit(true);
                    end;
                  tmp:=TStoredDef(tmp.owner.DefOwner);
                end;
            end;
          result:=false;
        end;

      var
        static_name: shortstring;
        srsymtable: TSymTable;
      begin
        result:=false;
        { generate access code }
        if (sp_static in sym.SymOptions) then
          begin
            result:=true;
            if handle_generic_staticfield_access then
              exit;
            static_name:=lower(Generate_Nested_Name(sym.owner,'_'))+'_'+sym.name;
            if sym.owner.DefOwner.typ=objectdef then
              SearchSym_In_Class(TObjectDef(sym.owner.DefOwner),TObjectDef(sym.owner.DefOwner),static_name,sym,srsymtable,[ssf_search_helper])
            else
              SearchSym_In_Record(TRecordDef(sym.owner.DefOwner),static_name,sym,srsymtable);
            if Assigned(sym) then
              Check_Hints(sym,sym.SymOptions,sym.DeprecatedMsg);
            p1.free;
            p1:=nil;
            { static syms are always stored as absolutevarsym to handle scope and storage properly }
            propaccesslist_to_node(p1,nil,TAbsoluteVarSym(sym).Ref);
          end;
      end;


    function is_bitpacked_access(n: TNode): boolean;
      begin
        case n.nodetype of
          vecn:
            result:=
              Is_Packed_Array(TVecNode(n).left.resultdef) and
              { only orddefs and enumdefs are actually bitpacked. Don't consider
                e.g. an access to a 3-byte record as "bitpacked", since it
                isn't }
              (TVecNode(n).left.resultdef.typ = arraydef) and
              (TArrayDef(TVecNode(n).left.resultdef).ElementDef.typ in [orddef,enumdef]) and
              not(TArrayDef(TVecNode(n).left.resultdef).ElePackedBitSize in [8,16,32,64]);
          subscriptn:
            result:=
              Is_Packed_Record_Or_Object(TSubscriptNode(n).left.resultdef) and
              { see above }
              (TSubscriptNode(n).vs.vardef.typ in [orddef,enumdef]) and
              (not(TSubscriptNode(n).vs.vardef.PackedBitSize in [8,16,32,64]) or
               (TSubscriptNode(n).vs.FieldOffset mod 8 <> 0));
          else
            result:=false;
        end;
      end;


    function genloadfield(n: TNode; const fieldname: string): TNode;
      var
        vs         : TSym;
      begin
        if not Assigned(n.resultdef) then
          TypeCheckPass(n);
        vs:=TSym(TAbstractRecordDef(n.resultdef).SymTable.find(fieldname));
        if not Assigned(vs) or
           (vs.typ<>FieldVarSym) then
          InternalError(2010061902);
        result:=CSubscriptNode.create(vs,n);
      end;


    function has_no_code(n : TNode) : boolean;
      begin
        if n=nil then
          begin
            result:=true;
            exit;
          end;
        case n.nodetype of
          nothingn:
            begin
               result:=true;
               exit;
            end;
          blockn:
            begin
              result:=has_no_code(TBlockNode(n).left);
              exit;
            end;
          statementn:
            begin
              repeat
                result:=has_no_code(TStatementNode(n).left);
                n:=TStatementNode(n).right;
              until not(result) or not Assigned(n);
              exit;
            end;
          else
            result:=false;
        end;
      end;


    function check_for_sideeffect(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        result:=fen_false;
        if (n.nodetype in [assignn,calln,asmn,finalizetempsn]) or
           ((n.nodetype=inlinen) and
            TInlineNode(n).may_have_sideeffect_norecurse
           ) or
           ((mhs_exceptions in PMHSFlags(arg)^) and
            ((n.nodetype in [derefn,vecn,divn,slashn]) or
             ((n.nodetype=subscriptn) and Is_Implicit_Pointer_Object_Type(TSubscriptNode(n).left.resultdef)) or
             ((n.nodetype in [addn,subn,muln,unaryminusn]) and (n.LocalSwitches*[cs_check_overflow,cs_check_range]<>[])) or
             { float operations could throw an exception }
             ((n.nodetype in [addn,subn,muln,slashn,unaryminusn,EqualN,unequaln,gten,gtn,lten,ltn]) and Is_Real_Or_CExtended(TUnaryNode(n).left.resultdef))
            )
           ) or
           ((n.nodetype=loadn) and
            (
             ((TLoadNode(n).symtableentry.typ=absolutevarsym) and (TAbsoluteVarSym(TLoadNode(n).symtableentry).AbsTyp=toaddr)) or
             ((TLoadNode(n).symtableentry.typ in [paravarsym,localvarsym,staticvarsym]) and
               (vo_volatile in TAbstractVarSym(TLoadNode(n).symtableentry).VarOptions)
             )
            )
           ) or
           { foreachonode does not recurse into the init code for temprefnode as this is done for
             by the tempcreatenode but the considered tree might not contain the tempcreatenode so play
             save and recurrence into the init code if there is any }
           ((n.nodetype=temprefn) and (ti_executeinitialisation in TTempRefNode(n).tempflags) and
            might_have_sideeffects(TTempRefNode(n).tempinfo^.tempinitcode,PMHSFlags(arg)^)) then
           result:=fen_norecurse_true
      end;


    function might_have_sideeffects(n : TNode; const flags : TMHSFlags) : boolean;
      begin
        result:=foreachnodestatic(n,@check_for_sideeffect,@flags);
      end;


    function check_for_conditional_nodes(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        result:=fen_false;
        { this check is not complete yet, but sufficient to cover the current use case: swapping
          of trees in expressions }
        if (n.nodetype in [ifn,whilerepeatn,forn,tryexceptn]) or
          ((n.nodetype in [orn,andn]) and Is_Boolean(n.resultdef) and doshortbooleval(n)) then
          result:=fen_norecurse_true;
      end;


    function has_conditional_nodes(n : TNode) : boolean;
      begin
        result:=foreachnodestatic(n,@check_for_conditional_nodes,nil);
      end;


    function donodecount(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        if PDWord(arg)^>0 then
          begin
            dec(PDWord(arg)^);
            result:=fen_false;
          end
        else
          result:=fen_norecurse_false;
      end;


    function node_count(node : TNode; max : dword = High(dword)) : dword;
      var
        left : dword;
      begin
        left:=max;
        foreachnodestatic(node,@donodecount,@left);
        result:=max-left;
      end;


    function donodecount_weighted(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        if PDWord(arg)^>0 then
          begin
            if not(n.nodetype in [blockn,statementn,callparan,nothingn]) then
              dec(PDWord(arg)^);
            result:=fen_false;
          end
        else
          result:=fen_norecurse_false;
      end;


    function node_count_weighted(node : TNode; max : dword = High(dword)) : dword;
      var
        left : dword;
      begin
        left:=max;
        foreachnodestatic(node,@donodecount_weighted,@left);
        result:=max-left;
      end;


    function is_const(node : TNode) : boolean;
      begin
        result:=is_constnode(node) or
          ((node.nodetype=temprefn) and (ti_const in TTempRefNode(node).tempflags)) or
          ((node.nodetype=loadn) and (TLoadNode(node).symtableentry.typ=paravarsym) and (TParaVarSym(TLoadNode(node).symtableentry).VarSpez in [vs_const,vs_constref]));
      end;


    function actualtargetnode(n : PNode) : PNode;
      begin
        result:=n;
        case n^.nodetype of
          typeconvn:
            if TTypeConvNode(n^).retains_value_location then
              result:=actualtargetnode(@TTypeConvNode(n^).left);
          else
            ;
        end;
      end;


    procedure replacenode(var dest,src : TNode);
      var
        t : TNode;
      begin
        t:=src;
        { set src nil before free'ing dest because
          src could be part of dest }
        src:=nil;
        dest.Free;
        dest:=t;
      end;


    function get_open_const_array(p : TNode) : TNode;
      begin
        result:=p;
        if (p.nodetype=derefn) and (TDerefNode(p).left.nodetype=addrn) then
          result:=get_open_const_array(TAddrNode(TDerefNode(result).left).left);
      end;

    type
      TFlagSet = record
        nf : TNodeFlags;
        tnf : TTransientNodeFlags;
      end;


    function do_node_reset_flags(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        result:=fen_false;
        n.flags:=n.flags-TFlagSet(arg^).nf;
        n.transientflags:=n.transientflags-TFlagSet(arg^).tnf;
      end;


    procedure node_reset_flags(p : TNode; nf : TNodeFlags; tnf : TTransientNodeFlags);
      var
        FlagSet: TFlagSet;
      begin
        FlagSet.nf:=nf;
        FlagSet.tnf:=tnf;
        foreachnodestatic(p,@do_node_reset_flags,@FlagSet);
      end;

    type
       TLocalSwitchChange = record
         cs : TLocalSwitch;
         enable : boolean;
       end;
       PLocalSwitchChange = ^TLocalSwitchChange;


    function do_change_local_settings(var p : TNode;plsc : pointer) : TForEachNodeResult;
      begin
        if PLocalSwitchChange(plsc)^.enable then
          include(p.LocalSwitches, PLocalSwitchChange(plsc)^.cs)
        else
          exclude(p.LocalSwitches, PLocalSwitchChange(plsc)^.cs);
        result:=fen_true;
     end;


    procedure node_change_local_switch(p : TNode;cs : TLocalSwitch;enable : boolean);
      var
        lsc : TLocalSwitchChange;
      begin
        lsc.cs:=cs;
        lsc.enable:=enable;
        foreachnodestatic(p,@do_change_local_settings,@lsc);
      end;


    function doshortbooleval(p : TNode) : Boolean;
      begin
        Result:=(p.nodetype in [orn,andn]) and ((anf_short_bool in TAddNode(p).addnodeflags) or not(cs_full_boolean_eval in p.LocalSwitches));
      end;


    function is_constintvalue(p: TNode; l: TConstExprInt): Boolean;
      begin
        Result:=is_constintnode(p) and (TOrdConstNode(p).Value=l);
      end;


    function get_int_value(p: TNode): TConstExprInt;
      begin
        case p.nodetype of
          ordconstn:
            result:=TOrdConstNode(p).Value;
          pointerconstn:
            result:=TPointerConstNode(p).Value;
          niln:
            result:=0;
          else
            InternalError(2002080202);
        end;
      end;


    function is_inlinefunction(p: TNode; i: TInlineNumber): Boolean;
      begin
        Result:=(p.nodetype=inlinen) and (TInlineNode(p).inlinenumber=i);
      end;


    { checks if p is a series of length(a) statements, if yes, they are returned
      in a and the function returns true }
    function GetStatements(p : TNode;var a : array of TStatementNode) : Boolean;
      var
        i: Integer;
      begin
        Result:=false;
        for i:=0 to high(a) do
          begin
            if not(Assigned(p)) or not(p.nodetype=statementn) then
              exit;
            a[i]:=TStatementNode(p);
            p:=TStatementNode(p).right;
          end;
        Result:=true;
      end;


    function IsSingleStatement(p: TNode; var s: TNode): Boolean;
      begin
        Result:=false;
        if Assigned(p) then
          case p.nodetype of
            blockn:
              Result:=IsSingleStatement(TBlockNode(p).statements,s);
            statementn:
              if not(Assigned(TStatementNode(p).next)) then
                begin
                  Result:=true;
                  s:=TStatementNode(p).statement;
                end;
            inlinen,
            assignn,
            calln:
              begin
                s:=p;
                Result:=true;
              end
            else
              ;
          end;
      end;


    { gets the last statement in a sequence of statements/blocks }
    function GetLastStatement(p : TNode) : TNode;
      var
        i: Integer;
      begin
        Result:=p;
        while Assigned(Result) do
          begin
            if Result.nodetype=statementn then
              begin
                if Assigned(TStatementNode(Result).next) then
                  Result:=TStatementNode(Result).next
                else if TStatementNode(Result).statement.nodetype=blockn then
                  Result:=TBlockNode(TStatementNode(Result).left).statements
                else
                  begin
                    Result:=TStatementNode(Result).statement;
                    exit;
                  end;
              end
            else if Result.nodetype=blockn then
              Result:=TBlockNode(Result).statements
            else
              exit;
          end;
      end;


    function MatchAndTransformNodesCommutative(n1,n2 : TNode;matchproc : TMatchProc2;transformproc : TTransformProc2;var res : TNode) : Boolean;
      begin
        res:=nil;
        result:=true;
        if matchproc(n1,n2) then
          res:=transformproc(n1,n2)
        else if matchproc(n2,n1) then
          res:=transformproc(n2,n1)
        else
          result:=false;
      end;


    function MatchAndTransformNodesCommutative(n1,n2,n3,n4 : TNode;matchproc : TMatchProc4;transformproc : TTransformProc4;var res : TNode) : Boolean;
      begin
        res:=nil;
        result:=true;
        if matchproc(n1,n2,n3,n4) then
          res:=transformproc(n1,n2,n3,n4)
        else if matchproc(n1,n2,n4,n3) then
          res:=transformproc(n1,n2,n4,n3)
        else if matchproc(n2,n1,n3,n4) then
          res:=transformproc(n2,n1,n3,n4)
        else if matchproc(n2,n1,n4,n3) then
          res:=transformproc(n2,n1,n4,n3)
        else if matchproc(n3,n4,n1,n2) then
          res:=transformproc(n3,n4,n1,n2)
        else if matchproc(n4,n3,n1,n2) then
          res:=transformproc(n4,n3,n1,n2)
        else if matchproc(n3,n4,n2,n1) then
          res:=transformproc(n3,n4,n2,n1)
        else if matchproc(n4,n3,n2,n1) then
          res:=transformproc(n4,n3,n2,n1)
        else
          result:=false;
      end;


     function _node_reset_pass1_write(var n: TNode; arg: pointer): TForEachNodeResult;
       begin
         Result := fen_false;
         n.flags := n.flags - [nf_write,nf_modify];
         n.transientflags := n.transientflags - [tnf_pass1_done];
         if n.nodetype = assignn then
           begin
             { Force re-evaluation of assignments so nf_modify and nf_write
               flags are correctly set. }
             n.resultdef := nil;
             Result := fen_true;
           end;
       end;


     procedure node_reset_pass1_write(n: TNode);
       begin
         foreachnodestatic(n,@_node_reset_pass1_write,nil);
       end;


     function node_in_list(var n: TNode; arg: pointer): TForEachNodeResult;
       begin
         if (n.nodetype in PNodeTypeSet(arg)^) then
           result := fen_norecurse_true
         else
           result := fen_false;
       end;


     function has_node_of_type(n: TNode; TypeList: TNodeTypeSet): Boolean;
       begin
         Result := foreachnodestatic(n, @node_in_list, @TypeList);
       end;


     function node_not_zero(n: TNode): Boolean;
       begin
         result:=(is_constintnode(n) and (get_int_value(n)<>0)) or
           ((n.resultdef.typ=orddef) and ((TOrdDef(n.resultdef).low>0) or (TOrdDef(n.resultdef).high<0))) or
           ((n.nodetype=typeconvn) and (TTypeConvNode(n).convtype=tc_int_2_int) and (n.resultdef.Size>=TTypeConvNode(n).resultdef.Size) and node_not_zero(TTypeConvNode(n).left)) or
           ((n.nodetype=orn) and (node_not_zero(TAddNode(n).left) or node_not_zero(TAddNode(n).right)));
       end;

end.
