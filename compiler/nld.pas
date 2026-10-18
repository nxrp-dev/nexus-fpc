{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Type checking and register allocation for load/assignment nodes

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
unit nld;

{$i fpcdefs.inc}

interface

    uses
       node,
       symconst,SymBase,symtype,SymSym,symdef;

    type
       Trttidatatype = (rdt_normal,rdt_ord2str,rdt_str2ord);

       TLoadNodeFlags = (
         loadnf_is_self,
         { tell the load node the address of the symbol into the location, i.e. location^ must
           be used to access the symbol
           this is for example needed to load self for objects }
         loadnf_load_addr,
         loadnf_inherited,
         { the loadnode is generated internally and a varspez=vs_const should be ignore,
           this requires that the parameter is actually passed by value
           Be really careful when using this flag! }
         loadnf_isinternal_ignoreconst,

         loadnf_only_uninitialized_hint
        );

       TLoadNode = class(TUnaryNode)
       protected
          FProcDef : TProcDef;
          FProcDefDeref : TDeref;
          function Handle_ThreadVar_Access: TNode; virtual;
       public
          LoadNodeFlags : set of TLoadNodeFlags;
          SymTableEntry : TSym;
          SymTableEntryDeref : TDeref;
          SymTable : TSymTable;
          constructor Create(ASym : TSym;ASymTable : TSymTable);virtual;
          constructor Create_ProcVar(ASym : TSym;AProcDef:TProcDef;ASymTable : TSymTable);virtual;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          procedure Set_MP(ANode:TNode);
          function  Is_Addr_Param_Load:Boolean;virtual;
          function  DoGetCopy : TNode;override;
          function  Pass_1 : TNode;override;
          function  Pass_TypeCheck:TNode;override;
          procedure Mark_Write;override;
          function  DoCompare(ANode: TNode): Boolean; override;
          procedure PrintNodeData(var AText:text);override;
          procedure SetProcDef(AProcDef : TProcDef;AForFuncRef:Boolean);
          property ProcDef: TProcDef read FProcDef;
       end;
       TLoadNodeClass = class of TLoadNode;

       { different assignment types }
       TAssignType = (at_normal,at_plus,at_minus,at_star,at_slash);

       TAssignmentNodeFlag = (
         anf_assign_done_in_right
       );

       TAssignmentNodeFlags = set of TAssignmentNodeFlag;

       TAssignmentNode = class(TBinaryNode)
         protected
          function Direct_ShortString_Assignment: Boolean; virtual;
         public
          AssignmentNodeFlags : TAssignmentNodeFlags;
          AssignType : TAssignType;
          constructor Create(ALeft,ARight : TNode);virtual;
          { no checks for validity of assignment }
          constructor Create_Internal(ALeft,ARight : TNode);virtual;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          function DoGetCopy : TNode;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Simplify(AForInline : Boolean) : TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
       end;
       TAssignmentNodeClass = class of TAssignmentNode;

       TArrayConstructorRangeNode = class(TBinaryNode)
          constructor Create(ALeft,ARight : TNode);virtual;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
       end;
       TArrayConstructorRangeNodeClass = class of TArrayConstructorRangeNode;

       TArrayConstructorNodeFlag = (
         acnf_allow_array_constructor,
         acnf_forcevaria,
         acnf_novariaallowed
       );

       TArrayConstructorNodeFlags = set of TArrayConstructorNodeFlag;

       TArrayConstructorNode = class(TBinaryNode)
          ArrayConstructorNodeFlags : TArrayConstructorNodeFlags;
         private
          function HasRangeNode:Boolean;
         protected
          procedure WrapManagedVarRec(var ANode : TNode);virtual;abstract;
         public
          constructor Create(ALeft,ARight : TNode);virtual;
          constructor PPULoad(ANodeType : TNodeType;APPUFile : TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile : TCompilerPPUFile);override;
          function DoGetCopy : TNode;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
          procedure Force_Type(ADef:TDef);
          procedure Insert_TypeConvs;
          function isempty : Boolean;
       end;
       TArrayConstructorNodeClass = class of TArrayConstructorNode;

       TTypeNode = class(TNode)
          Allowed : Boolean;
          HelperAllowed : Boolean;
          TypeDef : TDef;
          TypeDefDeref : TDeref;
          TypeSym : TSym;
          TypeSymDeref : TDeref;
          constructor Create(ADef:TDef);virtual;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function  DoGetCopy : TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
       end;
       TTypeNodeClass = class of TTypeNode;

       TRTTINode = class(TNode)
          L1,L2  : LongInt;
          RTTIType : TRTTIType;
          RTTIDef : TStoredDef;
          RTTIDefDeref : TDeref;
          RTTIDataType : TRTTIDataType;
          constructor Create(ADef:TStoredDef;ARTTIType:TRTTIType;ARTTIDataType:TRTTIDataType);virtual;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          function  DoGetCopy : TNode;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
       end;
       TRTTINodeClass = class of TRTTINode;

    var
       CLoadNode : TLoadNodeClass = TLoadNode;
       CAssignmentNode : TAssignmentNodeClass = TAssignmentNode;
       CArrayConstructorRangeNode : TArrayConstructorRangeNodeClass = TArrayConstructorRangeNode;
       CArrayConstructorNode : TArrayConstructorNodeClass = TArrayConstructorNode;
       CTypeNode : TTypeNodeClass = TTypeNode;
       CRTTINode : TRTTINodeClass = TRTTINode;

       { Current assignment node }
       AktAssignmentNode : TAssignmentNode;

       { Create a node tree to load a variable if symbol is assigned, otherwise an error node.
         Generates an internalerror if called for an absolutevarsym of the "tovar" kind (those
         are only supported for expansion in the parser) }
       function Gen_Load_Var(ASym: TAbstractVarSym): TNode;

implementation

    uses
      Verbose,GlobType,Globals,Systems,ConstExp,compinnr,
      PPU,
      SymTable,
      defutil,defcmp,
      CPUInfo,
      htypechk,Pass_1,ProcInfo,paramgr,
      nbas,ncon,nflw,ninl,ncnv,nmem,ncal,nutils,
      cgbase,
      optloadmodifystore,wpobase
      ;


    function Gen_Load_Var(ASym: TAbstractVarSym): TNode;
      begin
        Result:=nil;
        if Assigned(ASym) then
          begin
            if (ASym.Typ<>absolutevarsym) or
               (TAbsoluteVarSym(ASym).AbsTyp<>tovar) then
              begin
                Result:=CLoadNode.Create(ASym,ASym.owner);
              end
            else
              InternalError(2020122601);
          end
        else
          begin
            Result:=CErrorNode.Create;
            CGMessage(parser_e_illegal_expression);
          end;
      end;


{*****************************************************************************
                             TLOADNODE
*****************************************************************************}

    function TLoadNode.Handle_ThreadVar_Access: TNode;
      begin
        { nothing special by default }
        Result:=nil;
      end;


    constructor TLoadNode.Create(ASym : TSym;ASymTable : TSymTable);
      begin
         inherited Create(loadn,nil);
         if not Assigned(ASym) then
          InternalError(200108121);
         SymTableEntry:=ASym;
         SymTable:=ASymTable;
         FProcDef:=nil;
      end;


    constructor TLoadNode.Create_ProcVar(ASym : TSym;AProcDef:TProcDef;ASymTable : TSymTable);
      begin
         inherited Create(loadn,nil);
         if not Assigned(ASym) then
          InternalError(200108122);
         SymTableEntry:=ASym;
         SymTable:=ASymTable;
         FProcDef:=AProcDef;
      end;


    constructor TLoadNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetDeref(SymTableEntryDeref);
        SymTable:=nil;
        APPUFile.GetDeref(FProcDefDeref);
        APPUFile.GetSet(TPPUSet1(LoadNodeFlags));
      end;


    procedure TLoadNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutDeref(SymTableEntryDeref);
        APPUFile.PutDeref(FProcDefDeref);
        APPUFile.PutSet(TPPUSet1(LoadNodeFlags));
      end;


    procedure TLoadNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        SymTableEntryDeref.Build(SymTableEntry);
        FProcDefDeref.Build(FProcDef);
      end;


    procedure TLoadNode.DerefImpl;
      begin
        inherited DerefImpl;
        SymTableEntry:=TSym(SymTableEntryDeref.resolve);
        SymTable:=SymTableEntry.owner;
        FProcDef:=TProcDef(FProcDefDeref.resolve);
      end;


    procedure TLoadNode.Set_MP(ANode:TNode);
      begin
        { typen nodes should not be set }
        if ANode.NodeType=typen then
          InternalError(200301042);
        Left:=ANode;
      end;


    function TLoadNode.DoGetCopy : TNode;
      var
         lCopy : TLoadNode;
         lOriginalLabel,
         lLabelCopy : TLabelNode;
      begin
         lCopy:=TLoadNode(inherited DoGetCopy);
         lCopy.SymTable:=SymTable;
         lCopy.SymTableEntry:=SymTableEntry;
         lCopy.FProcDef:=FProcDef;
         lCopy.LoadNodeFlags:=LoadNodeFlags;
         if SymTableEntry.Typ=labelsym then
           begin
             { see the comments for the tgotonode.labelsym field }
             lOriginalLabel:=TLabelNode(TLabelSym(SymTableEntry).code);
             lLabelCopy:=TLabelNode(lOriginalLabel.DoGetCopy);
             if not Assigned(lLabelCopy.LabSym) then
               begin
                 if not Assigned(lOriginalLabel.LabSym) then
                   InternalError(2019091301);
                 lLabelCopy.LabSym:=CLabelSym.Create('$copiedlabelfrom$'+lOriginalLabel.LabSym.RealName);
                 lLabelCopy.LabSym.code:=lLabelCopy;
               end;
             lCopy.SymTableEntry:=lLabelCopy.LabSym;
           end;
         Result:=lCopy;
      end;


    function TLoadNode.Is_Addr_Param_Load:Boolean;
      begin
        Result:=(SymTable.SymTableType=parasymtable) and
                (SymTableEntry.Typ=paravarsym) and
                not(vo_has_local_copy in TParaVarSym(SymTableEntry).VarOptions) and
                not(loadnf_load_addr in LoadNodeFlags) and
                ParaManager.Push_Addr_Param(TParaVarSym(SymTableEntry).VarSpez,TParaVarSym(SymTableEntry).vardef,TProcDef(SymTable.DefOwner).ProcCallOption);
      end;


    function TLoadNode.Pass_TypeCheck:TNode;
      begin
         Result:=nil;
         case SymTableEntry.Typ of
           absolutevarsym :
             ResultDef:=TAbsoluteVarSym(SymTableEntry).vardef;
           constsym:
             begin
               if TConstSym(SymTableEntry).ConstTyp=constresourcestring then
                 ResultDef:=GetAnsiStringDef
               else if TConstSym(SymTableEntry).ConstTyp=constwresourcestring then
                 ResultDef:=CUnicodeStringType
               else
                 InternalError(22799);
             end;
           staticvarsym :
             begin
               TAbstractVarSym(SymTableEntry).IncRefCountBy(1);
               { static variables referenced in procedures or from finalization,
                 variable needs to be in memory.
                 It is too hard and the benefit is too small to detect whether a
                 variable is only used in the finalization to add support for it (PFV) }
               if Assigned(CurrentProcInfo) and
                  (SymTable.SymTableType=staticsymtable) and
                  (
                    (SymTable.SymTableLevel<>CurrentProcInfo.ProcDef.LocalST.SymTableLevel) or
                    (CurrentProcInfo.ProcDef.ProcTypeOption=potype_unitfinalize)
                  ) then
                 Make_Not_Regable(self,[ra_different_scope]);
               ResultDef:=TAbstractVarSym(SymTableEntry).vardef;
               if vo_is_thread_var in TStaticVarSym(SymTableEntry).VarOptions then
                 Result:=Handle_ThreadVar_Access;
             end;
           paravarsym,
           localvarsym :
             begin
               TAbstractVarSym(SymTableEntry).IncRefCountBy(1);
               ResultDef:=TAbstractVarSym(SymTableEntry).vardef;
               { Nested variable? The we need to load the framepointer of
                 the parent procedure }
               if Assigned(CurrentProcInfo) and
                  (SymTable.SymTableType in [LocalSymTable,parasymtable]) and
                  (SymTable.SymTableLevel<>CurrentProcInfo.ProcDef.ParaST.SymTableLevel) then
                 begin
                   if Assigned(Left) then
                     InternalError(200309289);
                   Left:=CLoadParentFPNode.Create(TProcDef(SymTable.DefOwner),lpf_forload);
                   CurrentProcInfo.Set_Needs_ParentFP(TProcDef(SymTable.DefOwner).ParaST.SymTableLevel);
                   { reference this as a captured symbol }
                   CurrentProcInfo.Add_Captured_Sym(SymTableEntry,ResultDef,FileInfo);
                   { reference in nested procedures, variable needs to be in memory }
                   { and behaves as if its address escapes its parent block         }
                   Make_Not_Regable(self,[ra_different_scope]);
                 end
               { if this is a nested function and it uses the Self parameter then
                 consider this as captured as well (needed for anonymous functions) }
               else if Assigned(CurrentProcInfo) and
                   (vo_is_self in TAbstractVarSym(SymTableEntry).VarOptions) and
                   (SymTable.SymTableLevel>NormalFunctionLevel) then
                 CurrentProcInfo.Add_Captured_Sym(SymTableEntry,ResultDef,FileInfo);

               { e.g. self for objects is passed as var-parameter on the caller
                 side, but on the callee-side we use it as a pointer ->
                 adjust }
               if (loadnf_load_addr in LoadNodeFlags) then
                 ResultDef:=CPointerDef.getreusable(ResultDef);

               if (vo_is_self in TAbstractVarSym(SymTableEntry).VarOptions) and (ResultDef=ObjC_IDType) and
                 (po_classmethod in TProcDef(SymTableEntry.owner.DefOwner).ProcOptions) then
                 ResultDef:=CClassRefDef.Create(TProcDef(SymTableEntry.owner.DefOwner).struct)
             end;
           ProcSym :
             begin
               { Return the first procdef. In case of overloaded
                 procdefs the matching procdef will be choosen
                 when the expected procvardef is known, see get_information
                 in htypechk.pas (PFV) }
               if not Assigned(FProcDef) then
                 FProcDef:=TProcDef(TProcSym(SymTableEntry).ProcdefList[0])
               else if po_kylixlocal in FProcDef.ProcOptions then
                 CGMessage(type_e_cant_take_address_of_local_subroutine);

               { the result is a fprocdef, addrn and proc_to_procvar
                 typeconvn need this as resultdef so they know
                 that the address needs to be returned }
               ResultDef:=FProcDef;

               if Is_Nested_PD(FProcDef) and Is_Nested_PD(CurrentProcInfo.ProcDef) then
                 CurrentProcInfo.Set_Needs_ParentFP(TProcDef(FProcDef.owner.DefOwner).ParaST.SymTableLevel);

               { process methodpointer/framepointer }
               if Assigned(Left) then
                 begin
                   TypeCheckPass(Left);
                   if (po_classmethod in FProcDef.ProcOptions) and
                      Is_Class(Left.ResultDef) and
                      (Left.NodeType<>niln) then
                     begin
                       Left:=CLoadVMTAddrNode.Create(Left);
                       TypeCheckPass(Left);
                     end
                 end;

               { we can't know what will happen with this function pointer, so
                 we have to assume it will be used to create an instance of this
                 type }
               if FProcDef.WPO_May_Create_Instance(Left) then
                 begin
                   if wpoinfomanager.symbol_live_in_currentproc(TDef(SymTable.DefOwner)) then
                     begin
                       if Assigned(Left) then
                         TObjectDef(Left.ResultDef).RegisterCreatedObjectType
                       else
                         TObjectDef(FProcDef.owner.DefOwner).RegisterCreatedObjectType;
                     end;
                 end;
             end;
           labelsym:
             begin
               TLabelSym(SymTableEntry).used:=true;
               ResultDef:=VoidType;
             end;
           else
             InternalError(200104141);
         end;

         { Currency variables are scaled by 10000 when stored }
         if Is_Currency(ResultDef) then
           Include(Flags, nf_is_currency);
      end;

    procedure TLoadNode.Mark_Write;

    begin
      include(Flags,nf_write);
    end;

    function TLoadNode.Pass_1 : TNode;
      begin
         Result:=nil;
         expectloc:=LOC_REFERENCE;

         case SymTableEntry.Typ of
            absolutevarsym :
              ;
            constsym:
              begin
                if TConstSym(SymTableEntry).ConstTyp in [constresourcestring,constwresourcestring] then
                  expectloc:=LOC_CREFERENCE;
              end;
            staticvarsym,
            localvarsym,
            paravarsym :
              begin
                if Assigned(Left) then
                  FirstPass(Left);
                if not Is_Addr_Param_Load and
                   TAbstractVarSym(SymTableEntry).Is_RegVar(Is_Addr_Param_Load) then
                  expectloc:=TVarRegable2TCGLoc[TAbstractVarSym(SymTableEntry).VarRegable]
                else
                  if (TAbstractVarSym(SymTableEntry).VarSpez=vs_const) then
                    expectloc:=LOC_CREFERENCE;
                { call to get address of threadvar }
                if (vo_is_thread_var in TAbstractVarSym(SymTableEntry).VarOptions) then
                  begin
                    include(CurrentProcInfo.Flags,pi_do_call);
                    include(CurrentProcInfo.Flags,pi_uses_threadvar);
                  end;
              end;
            ProcSym :
              begin
                { initialise left for nested procs if necessary (this won't need
                  to pass true for the forfuncref parameter, cause code that would
                  need that wouldn't have been reworked before it reaches pass_1) }
                if (m_nested_procvars in CurrentSettings.ModeSwitches) then
                  SetProcDef(FProcDef,false);
                { method pointer or nested proc ? }
                if Assigned(Left) then
                  begin
                     expectloc:=LOC_CREGISTER;
                     FirstPass(Left);
                  end;
              end;
            labelsym :
              begin
                if not Assigned(TLabelSym(SymTableEntry).AsmBlockLabel) and
                   not Assigned(TLabelSym(SymTableEntry).code) then
                  Message(parser_e_label_outside_proc);
              end
            else
              InternalError(200104143);
         end;
      end;


    function TLoadNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          (SymTableEntry = TLoadNode(ANode).SymTableEntry) and
          (FProcDef = TLoadNode(ANode).FProcDef) and
          (SymTable = TLoadNode(ANode).SymTable);
      end;


    procedure TLoadNode.PrintNodeData(var AText:text);
      begin
        inherited PrintNodeData(AText);
        write(AText,PrintNodeIndention,'symbol = ',SymTableEntry.name);
        if SymTableEntry.Typ=ProcSym then
          write(AText,PrintNodeIndention,'procdef = ',FProcDef.MangledName);
        WriteLn(AText,'');
      end;


    procedure TLoadNode.SetProcDef(AProcDef : TProcDef;AForFuncRef:Boolean);
      begin
        FProcDef:=AProcDef;
        ResultDef:=AProcDef;
        { nested procedure? }
        if Assigned(AProcDef) and
           Is_Nested_PD(AProcDef) and
           not AForFuncRef and
           (
             not (po_anonymous in AProcDef.ProcOptions) or
             (po_delphi_nested_cc in AProcDef.ProcOptions)
           ) then
          begin
            if not(m_nested_procvars in CurrentSettings.ModeSwitches) then
              CGMessage(type_e_cant_take_address_of_local_subroutine)
            else
              begin
                { parent frame pointer pointer as "self" }
                Left.free;
                Left:=CLoadParentFPNode.Create(TProcDef(AProcDef.owner.DefOwner),lpf_forpara);
                TypeCheckPass(Left);
              end;
          end
        { we should never go from nested to non-nested (except for an anonymous
          function which might have been changed to a global function or a
          method) }
        else if Assigned(Left) and
                (Left.NodeType=loadparentfpn) then
          begin
            if po_anonymous in AProcDef.ProcOptions then
              begin
                Left.free;
                Left:=nil;
              end
            else
              InternalError(2010072201);
          end;
      end;

{*****************************************************************************
                             TASSIGNMENTNODE
*****************************************************************************}

    function TAssignmentNode.Direct_ShortString_Assignment: Boolean;
      begin
        Result:=
          Is_Char(Right.ResultDef) or
          (Right.ResultDef.Typ=stringdef);
      end;


    constructor TAssignmentNode.Create(ALeft,ARight : TNode);

      begin
         inherited Create(assignn,ALeft,ARight);
         AssignmentNodeFlags:=[];
         AssignType:=at_normal;
         if ARight.NodeType = typeconvn then
           TTypeConvNode(ARight).WarnPointerToSigned:=false;
      end;


    constructor TAssignmentNode.Create_Internal(ALeft, ARight: TNode);
      begin
        Create(ALeft,ARight);
        include(Flags,nf_internal);
      end;


    constructor TAssignmentNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetSet(TPPUSet1(AssignmentNodeFlags));
        AssignType:=TAssignType(APPUFile.GetByte);
      end;


    procedure TAssignmentNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutSet(TPPUSet1(AssignmentNodeFlags));
        APPUFile.PutByte(Byte(AssignType));
      end;


    function TAssignmentNode.DoGetCopy : TNode;

      var
         lCopy : TAssignmentNode;

      begin
         lCopy:=TAssignmentNode(inherited DoGetCopy);
         lCopy.AssignmentNodeFlags:=AssignmentNodeFlags;
         lCopy.AssignType:=AssignType;
         Result:=lCopy;
      end;


    function TAssignmentNode.Simplify(AForInline : Boolean) : TNode;
      begin
        Result:=nil;
        { assignment nodes can perform several floating point }
        { type conversions directly, so no typeconversions    }
        { are inserted in those cases. When inlining, a       }
        { variable may be replaced by a constant which can be }
        { converted at compile time, so check for this case   }
        if Is_Real(Left.ResultDef) and
           Is_Real(Right.ResultDef) and
           Is_ConstRealNode(Right) and
           not Equal_Defs(Right.ResultDef,Left.ResultDef) then
          InsertTypeConv(Right,Left.ResultDef);
        { Perform simple optimizations when -O2 and the dedicated
          cs_opt_use_load_modify_store optimization pass is not enabled. }
        if (cs_opt_use_load_modify_store in supported_optimizerswitches) and
           (cs_opt_level2 in CurrentSettings.OptimizerSwitches) and
           not (cs_opt_use_load_modify_store in CurrentSettings.OptimizerSwitches) then
          Result:=try_opt_assignmentnode(self);
      end;


    function TAssignmentNode.Pass_TypeCheck:TNode;
      var
        lNode : TNode;
        lUsesHelper : Boolean;
        lOldAssignmentNode : TAssignmentNode;
      begin
        Result:=nil;
        ResultDef:=VoidType;

        { must be made unique }
        Set_Unique(Left);

        TypeCheckPass(Left);

        Left.Mark_Write;

        { PI. This is needed to return correct resultdef of add nodes for ansistrings
          rawbytestring return needs to be replaced by left.resultdef }
        lOldAssignmentNode:=AktAssignmentNode;
        AktAssignmentNode:=self;
        TypeCheckPass(Right);
        AktAssignmentNode:=lOldAssignmentNode;

        Set_VarState(Right,vs_read,[vsf_must_be_valid]);
        Set_VarState(Left,vs_written,[]);
        if CodeGenError then
          exit;

        { just in case the typecheckpass of right optimized something here }
        if anf_assign_done_in_right in AssignmentNodeFlags then
          begin
            Result:=Right;
            Right:=nil;
            exit;
          end;

        { tp procvar support, when we don't expect a procvar
          then we need to call the procvar }
        if (Left.ResultDef.Typ<>procvardef) and
            not Is_Invokable(Left.ResultDef) then
          Maybe_Call_ProcVar(Right,true);

        { assignments to formaldefs and open arrays aren't allowed }
        if Is_Open_Array(Left.ResultDef) or Is_Array_Of_Const(Left.ResultDef) then
          begin
            CGMessage(type_e_assignment_not_allowed);
            Result:=CErrorNode.Create;
            exit;
          end
        else if (Left.ResultDef.Typ=formaldef) then
          CGMessage(type_e_assignment_not_allowed);


        { test if node can be assigned, properties are allowed }
        if not(nf_internal in Flags) then
          if not Valid_For_Assignment(Left,true) then
            { errors can in situations that cause the compiler to run out of
              memory, such as assigning to an implicit pointer-to-array
              converted node (that array is 2^31 or 2^63 bytes large) }
            exit;

        { assigning nil or [] to a dynamic array clears the array }
        if Is_Dynamic_Array(Left.ResultDef) and
            (
              (Right.NodeType=niln) or
              (
                (Right.NodeType=arrayconstructorn) and
                (Right.ResultDef.Typ=arraydef) and
                (TArrayDef(Right.ResultDef).ElementDef=VoidType) and
                TArrayConstructorNode(Right).isempty
              )
            ) then
         begin
           { remove property flag to avoid errors, see comments for }
           { tf_winlikewidestring assignments below                 }
           exclude(Left.Flags,nf_isproperty);
           { generate a setlength node so it can be intercepted by
             target-specific code }
           Result:=CInlineNode.Create(in_setlength_x,false,
             CCallParaNode.Create(GenIntConstNode(0),
               CCallParaNode.Create(Left,nil)));
           Left:=nil;
           exit;
         end;

        { shortstring helpers can do the conversion directly,
          so treat them separately }
        if (Is_ShortString(Left.ResultDef)) then
         begin
           { insert typeconv, except for chars that are handled in
             secondpass and except for ansi/wide string that can
             be converted immediately }
           if not Direct_ShortString_Assignment then
             InsertTypeConv(Right,Left.ResultDef);
           if Right.ResultDef.Typ=stringdef then
            begin
              lUsesHelper:=true;
              { convert constant strings to shortstrings. But
                skip empty constant strings, that will be handled
                in secondpass }
              if (Right.NodeType=stringconstn) then
                begin
                  { verify if range fits within shortstring }
                  { just emit a warning, delphi gives an    }
                  { error, only if the type definition of   }
                  { of the string is less  < 255 characters }
                  if not Is_Open_String(Left.ResultDef) and
                     (TStringConstNode(Right).Len > TStringDef(Left.ResultDef).Len) then
                     CGMessage(type_w_string_too_long);
                  InsertTypeConv(Right,Left.ResultDef);
                  if (Right.NodeType=stringconstn) and
                     (TStringConstNode(Right).Len=0) then
                    lUsesHelper:=false;
                end
              else if (TStringDef(Right.ResultDef).StringType in [st_unicodestring,st_widestring]) then
                Message2(type_w_implicit_string_cast_loss,Right.ResultDef.TypeName,Left.ResultDef.TypeName);
             { rest is done in pass 1 (JM) }
             if lUsesHelper then
               exit;
            end
         end
        { floating point assignments can also perform the conversion directly }
        else if Is_Real(Left.ResultDef) and Is_Real(Right.ResultDef) and
                not Is_ConstRealNode(Right)

{$ifdef x86}
                { the assignment node code can't convert a double in an }
                { sse register to an extended value in memory more      }
                { efficiently than a type conversion node, so don't     }
                { bother implementing support for that                  }
                and (Use_VectorFPU(Left.ResultDef) or not(Use_VectorFPU(Right.ResultDef)))
{$endif}

        then
          begin
            if not(nf_internal in Flags) then
              Check_Ranges(FileInfo,Right,Left.ResultDef);
          end
        else
          begin
            { check if the assignment may cause a range check error }
            if not(nf_internal in Flags) then
              Check_Ranges(FileInfo,Right,Left.ResultDef);

            { beginners might be confused about an error message like
              Incompatible types: got "untyped" expected "LongInt"
              when trying to assign the result of a procedure, so give
              a better error message, see also #19122 }
            if (Left.ResultDef.Typ<>procvardef) and
                not Is_Invokable(Left.ResultDef) and
              (Right.NodeType=calln) and Is_Void(Right.ResultDef) then
              CGMessage(type_e_procedures_return_no_value)
            else
              begin
                if nf_internal in Flags then
                  InsertTypeConv_Internal(Right,Left.ResultDef)
                else
                  InsertTypeConv(Right,Left.ResultDef);

                { If assigning to a currency type, we need to make sure the
                  value is correctly scaled }
                if (nf_is_currency in Left.Flags) and
                  not (nf_is_currency in Right.Flags) then
                  begin
                    Right:=CTypeConvNode.Create(Right,Right.ResultDef);
                    Include(Right.Flags,nf_is_currency);

                    { Force an explicit conversion so the scalar is generated }
                    if S64CurrencyType.Typ=floatdef then
                      TTypeConvNode(Right).ConvType:=tc_real_2_real
                    else
                      TTypeConvNode(Right).ConvType:=tc_int_2_int;
                    TypeCheckPass(Right);
                  end;
              end;
          end;

        { call helpers for interface }
        if Is_InterfaceCOM_Or_DispInterface(Left.ResultDef) then
         begin
	   { Normal interface assignments are handled by the generic refcount incr/decr }
           if not Def_Is_Related(Right.ResultDef,Left.ResultDef) then
             begin
               { remove property flag to avoid errors, see comments for }
               { tf_winlikewidestring assignments below                 }
               exclude(Left.Flags,nf_isproperty);
               lNode:=
                 CCallParaNode.Create(
                   CGUIDConstNode.Create(TObjectDef(Left.ResultDef).IIDGUID^),
                 CCallParaNode.Create(
                   CTypeConvNode.Create_Internal(Right,VoidPointerType),
                 CCallParaNode.Create(
                   CTypeConvNode.Create_Internal(Left,VoidPointerType),
                   nil)));
               Result:=CCallNode.CreateIntern('fpc_intf_assign_by_iid',lNode);
               Left:=nil;
               Right:=nil;
               exit;
             end;
         end;

        { check if local proc/func is assigned to procvar }
        if Right.ResultDef.Typ=procvardef then
          Test_Local_To_ProcVar(TProcVarDef(Right.ResultDef),Left.ResultDef);
      end;


    function TAssignmentNode.Pass_1 : TNode;

      function TempReturnFromCall:Boolean;
        var
          lNode:TNode;
        begin
          Result:=false;
          if not Is_Managed_Type(Right.ResultDef) then
            exit;
          lNode:=Right;
          while Assigned(lNode) do
            begin
              case lNode.NodeType of
              blockn:
                lNode:=TBlockNode(lNode).Left;
              statementn:
                if Assigned(TStatementNode(lNode).Right) then
                  lNode:=TStatementNode(lNode).Right
                else
                  lNode:=TStatementNode(lNode).Left;
              else
                break;
              end;
            end;
          if not Assigned(lNode) then
            InternalError(2024111101);
          if (lNode.NodeType=calln) and Assigned(TCallNode(lNode).FuncRetNode) then
            lNode:=TCallNode(lNode).FuncRetNode;
          Result:=(lNode.NodeType=temprefn) and (nf_is_funcret in lNode.Flags);
        end;

      var
        lNode: TNode;
        lOldAssignmentNode : TAssignmentNode;
        lDef: TDef;
        lHelperName: string;
        lNeedRTTI: Boolean;
      begin
         Result:=nil;
         expectloc:=LOC_VOID;

         FirstPass(Left);

         { Optimize the reuse of the destination of the assignment in left.
           Allow the use of the left inside the tree generated on the right.
           This is especially useful for string routines where the destination
           is pushed as a parameter. Using the final destination of left directly
           save a temp allocation and copy of data (PFV) }
         lOldAssignmentNode:=AktAssignmentNode;
         AktAssignmentNode:=self;
         FirstPass(Right);
         AktAssignmentNode:=lOldAssignmentNode;
         if anf_assign_done_in_right in AssignmentNodeFlags then
           begin
             Result:=Right;
             Right:=nil;
             exit;
           end;

         if CodeGenError then
           exit;

         { assignment to refcounted variable -> inc/decref }
         if Is_Managed_Type(Left.ResultDef) then
           include(CurrentProcInfo.Flags,pi_do_call);

         lNeedRTTI:=false;

        if (Is_ShortString(Left.ResultDef)) then
          begin
           if Right.ResultDef.Typ=stringdef then
            begin
              if (Right.NodeType<>stringconstn) or
                 (TStringConstNode(Right).Len<>0) then
               begin
                 { remove property flag to avoid errors, see comments for }
                 { tf_winlikewidestring assignments below                 }
                 exclude(Left.Flags, nf_isproperty);
                 lNode:=CCallParaNode.Create
                       (Right,
                  CCallParaNode.Create(Left,nil));
                 Result:=CCallNode.CreateIntern('fpc_'+TStringDef(Right.ResultDef).StringTypName+'_to_shortstr',lNode);
                 FirstPass(Result);
                 Left:=nil;
                 Right:=nil;
               end;
            end;
            exit;
           end
        { call helpers for composite types containing automated types }
        else if Is_Managed_Type(Left.ResultDef) and
            (Left.ResultDef.Typ in [arraydef,objectdef,recorddef]) and
            not Is_InterfaceCOM_Or_DispInterface(Left.ResultDef) and
            not Is_Dynamic_Array(Left.ResultDef) and
            not Is_Const(Left) then
         begin
           lNode:=CCallParaNode.Create(CAddrNode.Create_Internal(
                  CRTTINode.Create(TStoredDef(Left.ResultDef),initrtti,rdt_normal)),
               CCallParaNode.Create(CTypeConvNode.Create_Internal(
                 CAddrNode.Create_Internal(Left),VoidPointerType),
               CCallParaNode.Create(CTypeConvNode.Create_Internal(
                 CAddrNode.Create_Internal(Right),VoidPointerType),
               nil)));
           if TempReturnFromCall then
             Result:=CCallNode.CreateIntern('fpc_copy_with_move_semantics_proc',lNode)
           else
             Result:=CCallNode.CreateIntern('fpc_copy_proc',lNode);
           FirstPass(Result);
           Left:=nil;
           Right:=nil;
           exit;
         end
        { call helpers for variant, they can contain non ref. counted types like
          vararrays which must be really copied }
        else if (Left.ResultDef.Typ=variantdef) and
            not(Is_Const(Left)) then
         begin
           { remove property flag to avoid errors, see comments for }
           { tf_winlikewidestring assignments below                 }
           exclude(Left.Flags,nf_isproperty);
           lDef:=Search_System_Type('TVARDATA').TypeDef;
           lNode:=CCallParaNode.Create(CTypeConvNode.Create_Internal(
                 Right,lDef),
               CCallParaNode.Create(CTypeConvNode.Create_Internal(
                 Left,lDef),
               nil));
           Result:=CCallNode.CreateIntern('fpc_variant_copy',lNode);
           FirstPass(Result);
           Left:=nil;
           Right:=nil;
           exit;
         end
        else if not(Is_Const(Left)) then
          begin
            { call helpers for pointer-sized managed types }
            if Is_WideString(Left.ResultDef) then
              lHelperName:='fpc_widestr_assign'
            else if Is_AnsiString(Left.ResultDef) then
              lHelperName:='fpc_ansistr_assign'
            else if Is_UnicodeString(Left.ResultDef) then
              lHelperName:='fpc_unicodestr_assign'
            else if Is_InterfaceCOM_Or_DispInterface(Left.ResultDef) then
              lHelperName:='fpc_intf_assign'
            else if Is_Dynamic_Array(Left.ResultDef) then
              begin
                lHelperName:='fpc_dynarray_assign';
                lNeedRTTI:=true;
              end
            else
              exit;
          end
        else
          exit;

        { The first argument of these procedures is a var parameter. Properties cannot     }
        { be passed to var or out parameters, because in that case setters/getters are not }
        { used. Further, if we would allow it in case there are no getters or setters, you }
        { would need source changes in case these are introduced later on, thus defeating  }
        { part of the transparency advantages of properties. In this particular case,      }
        { however:                                                                         }
        {   a) if there is a setter, this code will not be used since then the assignment  }
        {      will be converted to a procedure call                                       }
        {   b) the getter is irrelevant, because fpc_widestr_assign must always decrease   }
        {      the refcount of the field to which we are writing                           }
        {   c) source code changes are not required if a setter is added/removed, because  }
        {      this transformation is handled at compile time                              }
        {  -> we can remove the nf_isproperty flag (if any) from left, so that in case it  }
        {     is a property which refers to a field without a setter call, we will not get }
        {     an error about trying to pass a property as a var parameter                  }
        exclude(Left.Flags,nf_isproperty);
        lNode:=CCallParaNode.Create(CTypeConvNode.Create_Internal(Right,VoidPointerType),
            CCallParaNode.Create(CTypeConvNode.Create_Internal(Left,VoidPointerType),
            nil));
        if lNeedRTTI then
          lNode:=CCallParaNode.Create(
            CAddrNode.Create_Internal(
              CRTTINode.Create(TStoredDef(Left.ResultDef),initrtti,rdt_normal)),
            lNode);
        Result:=CCallNode.CreateIntern(lHelperName,lNode);
        FirstPass(Result);
        Left:=nil;
        Right:=nil;
      end;


    function TAssignmentNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          (AssignType = TAssignmentNode(ANode).AssignType);
      end;





{*****************************************************************************
                           TARRAYCONSTRUCTORRANGENODE
*****************************************************************************}

    constructor TArrayConstructorRangeNode.Create(ALeft,ARight : TNode);

      begin
         inherited Create(arrayconstructorrangen,ALeft,ARight);
      end;

    function TArrayConstructorRangeNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        TypeCheckPass(Left);
        TypeCheckPass(Right);
        Set_VarState(Left,vs_read,[vsf_must_be_valid]);
        Set_VarState(Right,vs_read,[vsf_must_be_valid]);
        if CodeGenError then
         exit;
        ResultDef:=Left.ResultDef;
      end;


    function TArrayConstructorRangeNode.Pass_1 : TNode;
      begin
        Result:=nil;
        CGMessage(parser_e_illegal_expression);
      end;


{****************************************************************************
                            TARRAYCONSTRUCTORNODE
*****************************************************************************}

    constructor TArrayConstructorNode.Create(ALeft,ARight : TNode);
      begin
         inherited Create(arrayconstructorn,ALeft,ARight);
         ArrayConstructorNodeFlags:=[];
      end;


    constructor TArrayConstructorNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetSet(TPPUSet1(ArrayConstructorNodeFlags));
      end;


    procedure TArrayConstructorNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutSet(TPPUSet1(ArrayConstructorNodeFlags));
      end;


    function TArrayConstructorNode.DoGetCopy : TNode;
      var
         lCopy : TArrayConstructorNode;
      begin
         lCopy:=TArrayConstructorNode(inherited DoGetCopy);
         lCopy.ArrayConstructorNodeFlags:=ArrayConstructorNodeFlags;
         Result:=lCopy;
      end;


    function TArrayConstructorNode.HasRangeNode:Boolean;
      var
        lNode : TArrayConstructorNode;
      begin
        Result:=false;
        lNode:=self;
        while Assigned(lNode) do
          begin
            if Assigned(lNode.Left) and (lNode.Left.NodeType=arrayconstructorrangen) then
              begin
                Result:=true;
                break;
              end;
            lNode:=TArrayConstructorNode(lNode.Right);
          end;
      end;


    function TArrayConstructorNode.isempty:Boolean;
      begin
        Result:=not(Assigned(Left)) and not(Assigned(Right));
      end;


    function TArrayConstructorNode.Pass_TypeCheck:TNode;
      var
        lDef  : TDef;
        lElementNode    : TArrayConstructorNode;
        lLength   : LongInt;
        lDifferentTypes,
        lVariantArray : Boolean;
        lEqualType    : TEqualType;
        lNodeType : TNodeType;
      begin
        Result:=nil;

      { are we allowing array constructor? Then convert it to a set.
        Do this only if we didn't convert the arrayconstructor yet. This
        is needed for the cases where the resultdef is forced for a second
        run }
        if not (acnf_allow_array_constructor in ArrayConstructorNodeFlags) or HasRangeNode then
         begin
           lElementNode:=TArrayConstructorNode(GetCopy);
           ArrayConstructor_To_Set(TNode(lElementNode));
           Result:=lElementNode;
           exit;
         end;

      { only pass left tree, right tree contains next construct if any }
        lDef:=nil;
        lNodeType:=errorn;
        lLength:=0;
        lVariantArray:=false;
        lDifferentTypes:=false;
        if Assigned(Left) then
         begin
           lElementNode:=self;
           while Assigned(lElementNode) do
            begin
              TypeCheckPass(lElementNode.Left);
              Set_VarState(lElementNode.Left,vs_read,[vsf_must_be_valid]);
              if (lDef=nil) then
                begin
                  lDef:=lElementNode.Left.ResultDef;
                  lNodeType:=lElementNode.Left.NodeType;
                end
              else
               begin
                 { If we got a niln we don't know the type yet and need to take the
                   type of the next array element.
                   This is to handle things like [nil,tclass,tclass], see also tw8371 (PFV) }
                 if lNodeType=niln then
                   begin
                     lEqualType:=Compare_Defs(lElementNode.Left.ResultDef,lDef,lNodeType);
                     if lEqualType>te_incompatible then
                       begin
                         lDef:=lElementNode.Left.ResultDef;
                         lNodeType:=lElementNode.Left.NodeType;
                       end;
                   end
                 else
                   lEqualType:=Compare_Defs(lDef,lElementNode.Left.ResultDef,lElementNode.Left.NodeType);
                 { the element is not compatible with the previous element
                   which means the constructor is array of const }
                 if lEqualType=te_incompatible then
                   lDifferentTypes:=true;
                 if (not lVariantArray) and (lEqualType<te_equal) then
                   begin
                     { If both are integers we need to take the type that can hold both
                       defs }
                     if Is_Integer(lDef) and Is_Integer(lElementNode.Left.ResultDef) then
                       begin
                         if Is_In_Limit(lDef,lElementNode.Left.ResultDef) then
                           lDef:=lElementNode.Left.ResultDef;
                       end
                     else
                       if (acnf_novariaallowed in ArrayConstructorNodeFlags) then
                         lVariantArray:=true;
                   end;
               end;
              inc(lLength);
              lElementNode:=TArrayConstructorNode(lElementNode.Right);
            end;
         end;
         { Set the type of empty or varia arrays to void. Also
           do this if the type is array of const/open array
           because those can't be used with setelementdef }
         if not Assigned(lDef) or
            lVariantArray or
            Is_Array_Of_Const(lDef) or
            Is_Open_Array(lDef) then
           lDef:=VoidType;
         ResultDef:=CArrayDef.Create(0,lLength-1,S32IntType);
         include(TArrayDef(ResultDef).ArrayOptions,ado_IsConstructor);
         if lVariantArray then
           include(TArrayDef(ResultDef).ArrayOptions,ado_IsVariant);
         if lDifferentTypes then
           include(TArrayDef(ResultDef).ArrayOptions,ado_IsArrayOfConst);
         TArrayDef(ResultDef).ElementDef:=lDef;
      end;


    procedure TArrayConstructorNode.Force_Type(ADef:TDef);
      var
        lElementNode : TArrayConstructorNode;
      begin
        TArrayDef(ResultDef).ElementDef:=ADef;
        include(TArrayDef(ResultDef).ArrayOptions,ado_IsConstructor);
        exclude(TArrayDef(ResultDef).ArrayOptions,ado_IsVariant);
        if Assigned(Left) then
         begin
           lElementNode:=self;
           while Assigned(lElementNode) do
            begin
              InsertTypeConv(lElementNode.Left,ADef);
              lElementNode:=TArrayConstructorNode(lElementNode.Right);
            end;
         end;
      end;


    procedure TArrayConstructorNode.Insert_TypeConvs;
      var
        lElementNode        : TArrayConstructorNode;
        lDoVariant : Boolean;
      begin
        lDoVariant:=(acnf_forcevaria in ArrayConstructorNodeFlags) or (ado_isvariant in TArrayDef(ResultDef).ArrayOptions);
        { only pass left tree, right tree contains next construct if any }
        if Assigned(Left) then
         begin
           lElementNode:=self;
           while Assigned(lElementNode) do
            begin
              TypeCheckPass(lElementNode.Left);
              { Insert typeconvs for array of const }
              if lDoVariant then
                { at this time C varargs are no longer an arrayconstructornode }
                Insert_VarArgsTypeConv(lElementNode.Left,false);
              lElementNode:=TArrayConstructorNode(lElementNode.Right);
            end;
         end;
      end;


    function TArrayConstructorNode.Pass_1 : TNode;
      var
        lElementNode : TArrayConstructorNode;
        lDoVariant:Boolean;
      begin
        lDoVariant:=(acnf_forcevaria in ArrayConstructorNodeFlags) or (ado_isvariant in TArrayDef(ResultDef).ArrayOptions);
        Result:=nil;
        { Insert required type convs, this must be
          done in pass 1, because the call must be
          typecheckpassed already }
        if Assigned(Left) then
          begin
            Insert_TypeConvs;
            { call firstpass for all nodes }
            lElementNode:=self;
            while Assigned(lElementNode) do
              begin
                if lElementNode.Left<>nil then
                  begin
                    {This check is pessimistic; a call will happen depending
                     on the location in which the elements will be found in
                     pass 2.}
                    if not lDoVariant then
                      include(CurrentProcInfo.Flags,pi_do_call);
                    FirstPass(lElementNode.Left);
                  end;
                lElementNode:=TArrayConstructorNode(lElementNode.Right);
              end;
          end;
        { set the elementdef to the correct type in case of a variant array }
        if lDoVariant then
          TArrayDef(ResultDef).ElementDef:=Search_System_Type('TVARREC').TypeDef;
        expectloc:=LOC_CREFERENCE;

        inc(CurrentProcInfo.EstimatedTempSize,(TArrayDef(ResultDef).HighRange+1)*TArrayDef(ResultDef).ElementDef.Size);
      end;


    function TArrayConstructorNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare:=inherited DoCompare(ANode);
      end;


{*****************************************************************************
                              TTYPENODE
*****************************************************************************}

    constructor TTypeNode.Create(ADef:TDef);
      begin
         inherited Create(typen);
         TypeDef:=ADef;
         TypeSym:=ADef.TypeSym;
         Allowed:=false;
         HelperAllowed:=false;
      end;


    constructor TTypeNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetDeref(TypeDefDeref);
        APPUFile.GetDeref(TypeSymDeref);
        Allowed:=APPUFile.GetBoolean;
        HelperAllowed:=APPUFile.GetBoolean;
      end;


    procedure TTypeNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutDeref(TypeDefDeref);
        APPUFile.PutDeref(TypeSymDeref);
        APPUFile.PutBoolean(Allowed);
        APPUFile.PutBoolean(HelperAllowed);
      end;


    procedure TTypeNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        TypeDefDeref.Build(TypeDef);
        TypeSymDeref.Build(TypeSym);
      end;


    procedure TTypeNode.DerefImpl;
      begin
        inherited DerefImpl;
        TypeDef:=TDef(TypeDefDeref.resolve);
        TypeSym:=TSym(TypeSymDeref.resolve);
      end;


    function TTypeNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=TypeDef;
        { check if it's valid }
        if TypeDef.Typ = errordef then
          CGMessage(parser_e_illegal_expression);
      end;


    function TTypeNode.Pass_1 : TNode;
      begin
         Result:=nil;
         expectloc:=LOC_VOID;
         { a typenode can't generate code, so we give here
           an error. Else it'll be an abstract error in pass_generate_code.
           Only when the allowed flag is set we don't generate
           an error }
         if not Allowed then
           CGMessage(parser_e_no_type_not_allowed_here);
         if not HelperAllowed and Is_ObjectPascal_Helper(TypeDef) then
           CGMessage(parser_e_no_category_as_types);
      end;


    function TTypeNode.DoGetCopy : TNode;
      var
         lCopy : TTypeNode;
      begin
         lCopy:=TTypeNode(inherited DoGetCopy);
         lCopy.Allowed:=Allowed;
         lCopy.TypeDef:=TypeDef;
         lCopy.TypeSym:=TypeSym;
         lCopy.HelperAllowed:=HelperAllowed;
         Result:=lCopy;
      end;


    function TTypeNode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          (TypeDef=TTypeNode(ANode).TypeDef) and
          (TypeSym=TTypeNode(ANode).TypeSym) and
          (Allowed=TTypeNode(ANode).Allowed) and
          (HelperAllowed=TTypeNode(ANode).HelperAllowed);
      end;


{*****************************************************************************
                              TRTTINODE
*****************************************************************************}


    constructor TRTTINode.Create(ADef:TStoredDef;ARTTIType:TRTTIType;ARTTIDataType:TRTTIDataType);
      begin
         inherited Create(rttin);
         RTTIDef:=ADef;
         RTTIType:=ARTTIType;
         RTTIDataType:=ARTTIDataType;
      end;


    constructor TRTTINode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetDeref(RTTIDefDeref);
        RTTIType:=TRTTIType(APPUFile.GetByte);
        RTTIDataType:=TRTTIDataType(APPUFile.GetByte);
      end;


    procedure TRTTINode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutDeref(RTTIDefDeref);
        APPUFile.PutByte(Byte(RTTIType));
        APPUFile.PutByte(Byte(RTTIDataType));
      end;


    procedure TRTTINode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        RTTIDefDeref.Build(RTTIDef);
      end;


    procedure TRTTINode.DerefImpl;
      begin
        inherited DerefImpl;
        RTTIDef:=TStoredDef(RTTIDefDeref.resolve);
      end;


    function TRTTINode.DoGetCopy : TNode;
      var
         lCopy : TRTTINode;
      begin
         lCopy:=TRTTINode(inherited DoGetCopy);
         lCopy.RTTIDef:=RTTIDef;
         lCopy.RTTIType:=RTTIType;
         lCopy.RTTIDataType:=RTTIDataType;
         Result:=lCopy;
      end;


    function TRTTINode.Pass_TypeCheck:TNode;
      begin
        { rtti information will be returned as a void pointer }
        Result:=nil;
        ResultDef:=VoidPointerType;
      end;


    function TRTTINode.Pass_1 : TNode;
      begin
        Result:=nil;
        expectloc:=LOC_CREFERENCE;
      end;


    function TRTTINode.DoCompare(ANode: TNode): Boolean;
      begin
        DoCompare :=
          inherited DoCompare(ANode) and
          (RTTIDef = TRTTINode(ANode).RTTIDef) and
          (RTTIType = TRTTINode(ANode).RTTIType) and
          (RTTIDataType = TRTTINode(ANode).RTTIDataType);
      end;

end.
