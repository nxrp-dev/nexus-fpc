{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit exports some help routines for the type checking

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
unit htypechk;

{$i fpcdefs.inc}

interface

    uses
      SysUtils,CClasses,CMsgs,tokens,
      node,GlobType,compinnr,
      symconst,symtype,symdef,SymSym,SymBase,
      pgentype;

    type
      TSupportedOpOverload = (op_unary, op_binary);
      Ttok2nodeRec=record
        Tok : TToken;
        Nod : TNodeType;
        Inr : TInlineNumber;
        SupportedOpOverloads: set of TSupportedOpOverload;
      end;

      Ttok2opRec=record
        Tok : TToken;
        ManagementOperator : TManagementOperator;
      end;

      PCandidate = ^TCandidate;
      TCandidate = object
         Next         : PCandidate;
         Data         : TProcDef;
         WrongParaIdx,
         FirstParaIdx : Integer;
         TECount : array[te_convert_operator .. te_exact] of Integer; { should be signed }
         OrdinalDistanceLo : UInt64;
         OrdinalDistanceHi,OrdinalDistanceSecondary : UInt32; { “hi” allows summing many uint64s, “secondary” allows tie-break corrections. }
         Invalid : Boolean;
{$ifndef DISABLE_FAST_OVERLOAD_PATCH}
         SavedValidity : Boolean;
{$endif}
         WrongParaNr : Byte;
         procedure Increment_Ordinal_Distance(ADistance: UInt64);
      end;

      TCallCandidatesFlag =
      (
        cc_ignorevisibility,cc_allowdefaultparas,cc_objcidcall,cc_explicitunit,cc_searchhelpers,cc_anoninherited
      );
      TCallCandidatesFlags = set of TCallCandidatesFlag;

      TCallCandidates = object
      private
        FProcSym     : TProcSym;
        FProcSymTable : TSymTable;
        FOperator    : TToken;
        FCandidateProcs    : PCandidate;
        FProcCnt    : Integer;
        FParaNode   : TNode;
        FParaLength : smallint;
        FAllowVariant : Boolean;
        FParaAnonSyms : TFPList;
        procedure CollectOverloadsInStruct(AStructDef:TAbstractRecordDef;AProcDefOverloadList:TFPObjectList;AFlags:TCallCandidatesFlags;ASpecializationContext:TSpecializationContext);
        procedure CollectOverloadsInUnits(AProcDefOverloadList:TFPObjectList; AFlags:TCallCandidatesFlags;ASpecializationContext:TSpecializationContext);
        procedure CreateCandidateList(AFlags:TCallCandidatesFlags;ASpecializationContext:TSpecializationContext);
        procedure CalcDistance(ARootSymTable:TSymTable;AFlags:TCallCandidatesFlags);
        function  ProcAdd(ASymTable:TSymTable;AProcDef:TProcDef):PCandidate;
      public
        constructor Init(ASym:TProcSym;ASymTable:TSymTable;AParaNode:TNode;AFlags:TCallCandidatesFlags;ASpecializationContext:TSpecializationContext);
        constructor Init_Operator(AOperator:TToken;AParaNode:TNode);
        destructor Done;
        procedure List(AAll:Boolean);
{$ifdef EXTDEBUG}
        procedure Dump_Info(ALevel:LongInt);
{$endif EXTDEBUG}
        procedure Get_Information;
        function  Choose_Best(var ABestProcDef:TAbstractProcDef; ASingleVariant: Boolean):Integer;
        procedure Find_Wrong_Para;
        property  Count:Integer read FProcCnt;
        { list of symbols for anonymous types required for implicit specializations;
          these should be handed over to the picked procdef, otherwise they'll be
          freed by tcallcandidates }
        property ParaAnonSyms:TFPList read FParaAnonSyms;
      end;

    type
      TRegableInfoFlag = (
         // can be put in a register if it's the address of a var/out/const parameter
         ra_addr_regable,
         { orthogonal to above flag: the address of the node is taken and may
           possibly escape the block in which this node is declared (e.g. a
           local variable is passed as var parameter to another procedure)
         }
         ra_addr_taken,
         { variable is accessed in a different scope }
         ra_different_scope);
      TRegableInfoFlags = set of TRegableInfoFlag;

    const
      cTok2NodeCount=27;
      Tok2Node:array[1..cTok2NodeCount] of TTok2NodeRec=(
        (Tok:_PLUS       ;Nod:addn     ;Inr:in_none ;SupportedOpOverloads:[op_unary,op_binary]),
        (Tok:_MINUS      ;Nod:subn     ;Inr:in_none ;SupportedOpOverloads:[op_unary,op_binary]),
        (Tok:_STAR       ;Nod:muln     ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_SLASH      ;Nod:slashn   ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_EQ         ;Nod:EqualN   ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_GT         ;Nod:gtn      ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_LT         ;Nod:ltn      ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_GTE        ;Nod:gten     ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_LTE        ;Nod:lten     ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_SYMDIF     ;Nod:symdifn  ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_STARSTAR   ;Nod:starstarn;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_OP_AS      ;Nod:asn      ;Inr:in_none ;SupportedOpOverloads:[]),
        (Tok:_OP_IN      ;Nod:inn      ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_OP_IS      ;Nod:isn      ;Inr:in_none ;SupportedOpOverloads:[]),
        (Tok:_OP_OR      ;Nod:orn      ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_OP_AND     ;Nod:andn     ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_OP_DIV     ;Nod:divn     ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_OP_NOT     ;Nod:notn     ;Inr:in_none ;SupportedOpOverloads:[op_unary]),
        (Tok:_OP_MOD     ;Nod:modn     ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_OP_SHL     ;Nod:shln     ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_OP_SHR     ;Nod:shrn     ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_OP_XOR     ;Nod:xorn     ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_ASSIGNMENT ;Nod:assignn  ;Inr:in_none ;SupportedOpOverloads:[op_unary]),
        (Tok:_OP_EXPLICIT;Nod:assignn  ;Inr:in_none ;SupportedOpOverloads:[op_unary]),
        (Tok:_NE         ;Nod:unequaln ;Inr:in_none ;SupportedOpOverloads:[op_binary]),
        (Tok:_OP_INC     ;Nod:inlinen  ;Inr:in_inc_x;SupportedOpOverloads:[op_unary]),
        (Tok:_OP_DEC     ;Nod:inlinen  ;Inr:in_dec_x;SupportedOpOverloads:[op_unary])
      );

      cTok2OpCount=4;
      Tok2Op: array[1..cTok2OpCount] of TTok2OpRec=(
        (Tok:_OP_INITIALIZE; ManagementOperator: mop_initialize),
        (Tok:_OP_FINALIZE  ; ManagementOperator: mop_finalize),
        (Tok:_OP_ADDREF    ; ManagementOperator: mop_addref),
        (Tok:_OP_COPY      ; ManagementOperator: mop_copy)
      );

    function Node2OpStr(ANodeType:TNodeType):String;
    function Token2ManagementOperator(AOpToken:TToken):TManagementOperator;

    { check operator args and result type }

    type
      TOverloadCheckFlag = (
        ocf_check_non_overloadable, { also check operators that are (currently) considered as
                                      not overloadable (e.g. the "+" operator for dynamic arrays
                                      if modeswitch arrayoperators is active) }
        ocf_check_only              { only check whether the operator is overloaded, but don't
                                      modify the passed in node (return true if the operator is
                                      overloaded, false otherwise) }
      );
      TOverloadCheckFlags = set of TOverloadCheckFlag;

    function IsBinaryOperatorOverloadable(ATreeType:TNodeType;ALeftDef:TDef;ALeftNodeType:TNodeType;ARightDef:TDef;ARightNodeType:TNodeType) : Boolean;
    function IsOperatorAcceptable(AProcDef : TProcDef; AOpToken : TToken) : Boolean;
    function IsUnaryOverloaded(var ANode : TNode;AOverloadFlags:TOverloadCheckFlags) : Boolean;
    function IsBinaryOverloaded(var ANode : TNode;AOverloadFlags:TOverloadCheckFlags) : Boolean;

    { Register Allocation }
    procedure Make_Not_Regable(ANode : TNode; AHow: TRegableInfoFlags);

    { procvar handling }
    function  Is_Proc2ProcVar_Load(ANode:TNode;out ARealProcDef:TProcDef):Boolean;
    { returns whether a node represents a load of the function result node via
      the function name (so it could also be a recursive call to the function
      in case there or no parameters, or the function could be passed as
      procvar }
    function  Is_Ambiguous_FuncRet_Load(ANode: TNode; out AOwningProcDef: TProcDef): Boolean;
    procedure Test_Local_To_ProcVar(AFromDef:TProcVarDef;AToDef:TDef);

    { sets varsym varstate field correctly }
    type
      TVarStateFlag = (vsf_must_be_valid,vsf_use_hints,vsf_use_hint_for_string_result);
      TVarStateFlags = set of TVarStateFlag;
    procedure Set_VarState(ANode:TNode;ANewState:TVarState;AVarStateFlags:TVarStateFlags);

    { sets the callunique flag, if the node is a vecn, }
    { takes care of type casts etc.                 }
    procedure Set_Unique(ANode : TNode);

    function  Valid_For_Formal_Var(ANode : TNode; AReportErrors: Boolean) : Boolean;
    function  Valid_For_Formal_ConstRef(ANode : TNode; AReportErrors: Boolean) : Boolean;
    function  Valid_For_Formal_Const(ANode : TNode; AReportErrors: Boolean) : Boolean;
    function  Valid_For_Var(ANode:TNode; AReportErrors: Boolean):Boolean;
    function  Valid_For_Assignment(ANode:TNode; AReportErrors: Boolean):Boolean;
    function  Valid_For_LoopVar(ANode:TNode; AReportErrors: Boolean):Boolean;
    function  Valid_For_Addr(ANode : TNode; AReportErrors: Boolean) : Boolean;

    function AllowEnumOp(ANodeType:TNodeType):Boolean;

    procedure Check_Ranges(const ALocation: TFilePosInfo; ASource: TNode; ADestDef: TDef);

    { returns whether the def may be used in the Default() intrinsic; static
      arrays, records and objects are checked recursively }
    function Is_Valid_For_Default(ADef:TDef):Boolean;

    procedure UninitializedVariableMessage(APosition : TFilePosInfo;AWarning,ALocal,AManaged : Boolean;AName : TMsgStr);

implementation

    uses
       Systems,ConstExp,Globals,
       CUtils,Verbose,
       SymTable,symutil,
       defutil,defcmp,
       nbas,ncnv,nld,nmem,ncal,nmat,ninl,nutils,ProcInfo,
       pgenutil
       ;

    type
      TValidAssign=(ValidProperty,ValidVoid,ValidConst,ValidAddr,ValidPacked,ValidRange);
      TValidAssigns=set of TValidAssign;


    { keep these two in sync! }
    const
      cNonCommutativeOpTokens=[_OP_SHL,_OP_SHR,_OP_DIV,_OP_MOD,_STARSTAR,_SLASH,_MINUS];
      cNonCommutativeOpNodes=[shln,shrn,divn,modn,starstarn,slashn,subn];


    function Node2OpStr(ANodeType:TNodeType):String;
      var
        lIndex : Integer;
      begin
        Result:='<unknown>';
        for lIndex:=1 to cTok2NodeCount do
          if Tok2Node[lIndex].Nod=ANodeType then
            begin
              Result:=tokeninfo^[Tok2Node[lIndex].Tok].str;
              break;
            end;
       end;


    function Token2ManagementOperator(AOpToken:TToken):TManagementOperator;
      var
        lIndex : Integer;
      begin
        Result:=mop_none;
        for lIndex:=1 to cTok2OpCount do
          if Tok2Op[lIndex].Tok=AOpToken then
            begin
              Result:=Tok2Op[lIndex].ManagementOperator;
              break;
            end;
      end;


    function IsBinaryOperatorOverloadable(ATreeType:TNodeType;ALeftDef:TDef;ALeftNodeType:TNodeType;ARightDef:TDef;ARightNodeType:TNodeType) : Boolean;

        function InternalCheck(ATreeType:TNodeType;ALeftDef:TDef;ALeftNodeType:TNodeType;ARightDef:TDef;ARightNodeType:TNodeType;var AAllowed:Boolean):Boolean;
        const
          cIdentityOperators=[EqualN,unequaln];
          cOrderTheoreticOperators=cIdentityOperators+[ltn,lten,gtn,gten];
          cArithmeticOperators=[addn,subn,muln,divn,modn];
          cRationalOperators=[addn,subn,muln,slashn];
          cNumericalOperators=cArithmeticOperators+[slashn];
          cPointerArithmeticOperators=[addn,subn];
          cLogicalOperators=[andn,orn,xorn];
          cBitManipulationOperators=cLogicalOperators+[shln,shrn];
          cSetSetOperators=cIdentityOperators+[addn,subn,muln,symdifn]+
            cOrderTheoreticOperators;
          cElementSetOperators=[inn];
          cStringComparisonOperators=cOrderTheoreticOperators;
          cStringManipulationOperators=[addn];
          cStringOperators =
            cStringComparisonOperators+cStringManipulationOperators;
        begin
          InternalCheck:=true;

          { Reject the cases permitted by the default interpretation (DI). }
          case ALeftDef.typ of
            formaldef,
            recorddef,
            variantdef :
              begin
                AAllowed:=true;
              end;
            enumdef:
              begin
                AAllowed:=not (
                           (
                             Is_Set(ARightDef) and
                             (ATreeType in cElementSetOperators)
                           ) or
                           (
                             Is_Enum(ARightDef) and
                             (ATreeType in (cOrderTheoreticOperators+[addn, subn]))
                           ) or
                           (
                             { for enum definitions, see tbs/tw22860.pas }
                             Is_Integer(ARightDef) and
                             (ATreeType in (cOrderTheoreticOperators+cBitManipulationOperators+cArithmeticOperators))
                           )
                         );
              end;
            setdef:
              begin
                AAllowed:=not (
                           (
                             Is_Set(ARightDef) and
                             (ATreeType in (cSetSetOperators+cIdentityOperators))
                           ) or
                           (
                             { This clause is a hack but it’s due to a hack somewhere
                               else---while set + element is not permitted by DI, it
                               seems to be used when a set is constructed inline }
                             (ARightDef.typ in [enumdef,orddef]) and
                             (ATreeType=addn)
                           )
                         );
              end;
            orddef, floatdef:
              begin
                AAllowed:=not (
                           (
                             (ARightDef.typ in [orddef,floatdef]) and
                             (ATreeType in cOrderTheoreticOperators)
                           ) or
                           (
                             (m_mac in CurrentSettings.ModeSwitches) and
                             Is_StringLike(ARightDef) and
                             (ALeftDef.typ=orddef) and
                             (ATreeType in cStringComparisonOperators)) or
                             { c.f. $(source)\tests\tmacpas5.pas }
                             (
                               (ARightDef.typ=setdef) and
                               (ALeftDef.typ=orddef) and
                               (ATreeType in cElementSetOperators)
                             )
                            { This clause may be too restrictive---not all types under
                              orddef have a corresponding set type; despite this the
                              restriction should be very unlikely to become
                              a practical obstacle, and can be relaxed by simply
                              adding an extra check on TOrdDef(rd).ordtype }
                           );

                { Note that Currency can be under either orddef or floatdef;
                  when it’s under floatdef, is_currency() implies is_float();
                  when it’s under orddef, is_currency() does NOT imply
                  is_integer(). }
                if AAllowed then
                  begin
                    if Is_AnyChar(ALeftDef) then
                      AAllowed:=not (
                                 Is_StringLike(ARightDef) and
                                 (ATreeType in cStringOperators)
                               )
                    else if Is_Boolean(ALeftDef) then
                      AAllowed:=not (
                                 Is_Boolean(ARightDef) and
                                 (ATreeType in cLogicalOperators)
                               )
                    else if Is_Integer(ALeftDef) or
                        (
                          (ALeftDef.typ=orddef) and
                          Is_Currency(ALeftDef)
                        { Here ld is Currency but behaves like an integer }
                        ) then
                      AAllowed:=not (
                                 (
                                   (
                                     Is_Integer(ARightDef) or
                                     (
                                       (ARightDef.typ=orddef) and
                                       Is_Currency(ARightDef)
                                     )
                                   ) and
                                   (ATreeType in (cBitManipulationOperators+cNumericalOperators))
                                 ) or
                                 (
                                   Is_FPU(ARightDef) and
                                   (ATreeType in cRationalOperators)
                                 ) or
                                 (
                                   { When an integer type is used as the first operand in
                                     pointer arithmetic, DI doesn’t accept minus as the
                                     operator (Currency can’t be used in pointer
                                     arithmetic even if it’s under orddef)  }
                                   Is_Integer(ALeftDef) and
                                   (ARightDef.typ=pointerdef) and
                                   (ATreeType in cPointerArithmeticOperators-[subn])
                                 )
                               )
                    else  { is_fpu(ld) = True }
                      AAllowed:=not (
                                 (
                                   Is_FPU(ARightDef) or
                                   Is_Integer(ARightDef) or
                                   Is_Currency(ARightDef)
                                 ) and
                                 (ATreeType in cRationalOperators)
                               );
                  end;
              end;
            procvardef :
              begin
                if (ARightDef.typ in [pointerdef,procdef,procvardef]) then
                 begin
                   AAllowed:=false;
                   exit;
                 end;
                AAllowed:=true;
              end;
            pointerdef :
              begin
                { DI permits pointer arithmetic for pointer + pointer, pointer -
                  integer, pointer - pointer, but not for pointer + pointer.
                  The last case is only valid in DI when both sides are
                  stringlike. }

                if Is_StringLike(ALeftDef) then
                  if Is_StringLike(ARightDef) then
                    { DI in this case permits string operations and pointer
                      arithmetic. }
                    AAllowed:=not (ATreeType in (cStringOperators+cPointerArithmeticOperators))
                  else if ARightDef.typ = pointerdef then
                    { DI in this case permits minus for pointer arithmetic and
                      order-theoretic operators for pointer comparison. }
                    AAllowed:=not (
                               ATreeType in (
                                 cPointerArithmeticOperators-[addn]+
                                 cOrderTheoreticOperators
                               )
                             )
                  else if Is_Integer(ARightDef) then
                    { DI in this case permits pointer arithmetic. }
                    AAllowed:=not (ATreeType in cPointerArithmeticOperators)
                  else
                    AAllowed:=true
                else
                  AAllowed:=not (
                             (
                               Is_Integer(ARightDef) and
                               (ATreeType in cPointerArithmeticOperators)
                             ) or
                             (
                               (ARightDef.typ=pointerdef) and
                               (
                                 ATreeType in (
                                   cPointerArithmeticOperators-[addn]+
                                   cOrderTheoreticOperators
                                 )
                               )
                             ) or
                             (
                               (ALeftNodeType=niln) and
                               ((ARightDef.typ in [procvardef,procdef,classrefdef]) or
                                (Is_Dynamic_Array(ARightDef))) and
                               (ATreeType in cIdentityOperators)
                             ) or
                             (
                               Is_Implicit_Pointer_Object_Type(ARightDef) and
                               (ATreeType in cIdentityOperators)
                             )
                           );
              end;
            arraydef :
              begin
                { not vector }
                if (cs_support_vectors in CurrentSettings.GlobalSwitches) and
                   Is_Vector(ALeftDef) then
                 begin
                   AAllowed:=false;
                   exit;
                 end;

                if Is_StringLike(ALeftDef) and
                    (
                      (
                        (
                          Is_StringLike(ARightDef) or
                          (ARightNodeType = niln)
                        ) and
                        (ATreeType in cStringOperators)
                      ) or
                      (
                        Is_Integer(ARightDef) and
                        (ATreeType in cPointerArithmeticOperators)
                      ) or
                      (
                        (
                          Is_PChar(ARightDef) or
                          Is_PWideChar(ARightDef)) and
                          (ATreeType in cPointerArithmeticOperators) and
                          (TPointerDef(ARightDef).PointedDef=TArrayDef(ALeftDef).ElementDef
                        )
                      )
                    ) then
                  begin
                    AAllowed:=false;
                    exit;
                  end;

                { dynamic array compare with niln }
                if Is_Dynamic_Array(ALeftDef) and
                    (ATreeType in cIdentityOperators) then
                  if Is_Dynamic_Array(ARightDef) or
                      (ARightNodeType=niln) then
                    begin
                      AAllowed:=false;
                      exit;
                    end;

                 { <dyn. array> + <dyn. array> is handled by the compiler }
                 if (m_array_operators in CurrentSettings.ModeSwitches) and
                     (ATreeType=addn) and
                     (Is_Dynamic_Array(ALeftDef) or Is_Array_Constructor(ALeftDef)) and
                     (Is_Dynamic_Array(ARightDef) or Is_Array_Constructor(ARightDef)) then
                    begin
                      AAllowed:=false;
                      exit;
                    end;

                AAllowed:=true;
              end;
            objectdef :
              begin
                { <> and = are defined for implicit pointer object types }
                AAllowed:=not (
                           Is_Implicit_Pointer_Object_Type(ALeftDef) and
                           (
                             (
                               Is_Implicit_Pointer_Object_Type(ARightDef) or
                               (ARightDef.typ=pointerdef) or
                               (ARightNodeType=niln)
                             )
                           ) and
                           (ATreeType in cIdentityOperators)
                         );
              end;
            stringdef :
              begin
                AAllowed:=not (
                           Is_StringLike(ARightDef) and
                           (ATreeType in cStringOperators)
                         );
              end;
            else
              InternalCheck:=false;
          end;
        end;

      begin
        { power ** is always possible }
        Result:=ATreeType=starstarn;
        if not Result then
          begin
            if not InternalCheck(ATreeType,ALeftDef,ALeftNodeType,ARightDef,ARightNodeType,Result) and
                not (ATreeType in cNonCommutativeOpNodes) then
              InternalCheck(ATreeType,ARightDef,ARightNodeType,ALeftDef,ALeftNodeType,Result)
          end;
      end;


    function IsUnaryOperatorOverloadable(ATreeType:TNodeType;AInlineNumber:TInlineNumber;ALeftDef:TDef) : Boolean;
      begin
        Result:=false;
        case ATreeType of
          subn,
          addn,
          unaryminusn,
          unaryplusn,
          inlinen:
            begin
              { only Inc, Dec inline functions are supported for now, so skip check inlinenumber }

              if (ALeftDef.typ in [orddef,enumdef,floatdef]) then
                exit;


              Result:=true;
            end;

          notn :
            begin
              if ALeftDef.typ = orddef then exit;


              Result:=true;
            end;
          else
            ;
        end;
      end;


    function IsOperatorAcceptable(AProcDef : TProcDef; AOpToken : TToken) : Boolean;
      var
        lLeftDef,lRightDef : TDef;
        lIndex : LongInt;
        lEqualType : TEqualType;
        lConversion : TConvertType;
        lCompareDefOptions : TCompareDefsOptions;
        lProcDef : TProcDef;
        lOldCount,
        lCount: LongInt;
        lSym : TSym;
        lParaSym : TParaVarSym absolute lSym;
      begin
        Result:=false;
        lCount := AProcDef.ParaST.SymList.count;

        lOldCount:=lCount;
        while lCount > 0 do
          begin
            lSym:=TSym(AProcDef.ParaST.SymList[lCount-1]);
            if lSym.typ<>paravarsym then
              begin
                dec(lCount);
              end
            else if Is_Boolean(lParaSym.vardef) then
              begin
                if lParaSym.name='RANGECHECK' then
                  begin
                    Include(lParaSym.VarOptions, vo_is_hidden_para);
                    Include(lParaSym.VarOptions, vo_is_range_check);
                    Dec(lCount);
                  end
                else if lParaSym.name='OVERFLOWCHECK' then
                  begin
                    Include(lParaSym.VarOptions, vo_is_hidden_para);
                    Include(lParaSym.VarOptions, vo_is_overflow_check);
                    Dec(lCount);
                  end
                else
                  break;
              end
            else
              break;
          end;
        if lCount<>lOldCount then
          AProcDef.CalcParas;

        case lCount of
          1 : begin
                lLeftDef:=TParaVarSym(AProcDef.ParaST.SymList[0]).vardef;
                { assignment is a special case }
                if AOpToken in [_ASSIGNMENT,_OP_EXPLICIT] then
                  begin
                    lCompareDefOptions:=[];
                    if AOpToken=_OP_EXPLICIT then
                      include(lCompareDefOptions,cdo_explicit);
                    lEqualType:=Compare_Defs_Ext(lLeftDef,AProcDef.ReturnDef,nothingn,lConversion,lProcDef,lCompareDefOptions);
                    Result:=
                      (lEqualType=te_exact) or
                      (lEqualType=te_incompatible);
                  end
                else
                { enumerator is a special case too }
                if AOpToken=_OP_ENUMERATOR then
                  begin
                    Result:=
                      Is_Class_Or_Interface_Or_Object(AProcDef.ReturnDef) or
                      Is_Record(AProcDef.ReturnDef);
                    if Result then
                      begin
                        if not Assigned(TAbstractRecordDef(AProcDef.ReturnDef).Search_Enumerator_Move) then
                          begin
                            Message1(sym_e_no_enumerator_move, AProcDef.ReturnDef.TypeName);
                            Result:=false;
                          end;
                        if not Assigned(TAbstractRecordDef(AProcDef.ReturnDef).Search_Enumerator_Current) then
                          begin
                            Message1(sym_e_no_enumerator_current,AProcDef.ReturnDef.TypeName);
                            Result:=false;
                          end;
                      end;
                  end
                else
                  begin
                    for lIndex:=1 to cTok2NodeCount do
                      if Tok2Node[lIndex].Tok=AOpToken then
                        begin
                          Result:=
                            (op_unary in Tok2Node[lIndex].SupportedOpOverloads) and
                            IsUnaryOperatorOverloadable(Tok2Node[lIndex].Nod,Tok2Node[lIndex].Inr,lLeftDef);
                          break;
                        end;
                    { Inc, Dec operators are valid if only result type is the same as argument type }
                    if Result and (AOpToken in [_OP_INC,_OP_DEC]) then
                      Result:=AProcDef.ReturnDef=lLeftDef;
                  end;
              end;
          2 : begin
                lLeftDef:=TParaVarSym(AProcDef.ParaST.SymList[0]).vardef;
                lRightDef:=TParaVarSym(AProcDef.ParaST.SymList[1]).vardef;
                for lIndex:=1 to cTok2NodeCount do
                  if Tok2Node[lIndex].Tok=AOpToken then
                    begin
                      Result:=
                        (op_binary in Tok2Node[lIndex].SupportedOpOverloads) and
                        IsBinaryOperatorOverloadable(Tok2Node[lIndex].Nod,lLeftDef,nothingn,lRightDef,nothingn);
                      break;
                    end;
              end;
        end;
      end;


    function IsUnaryOverloaded(var ANode : TNode;AOverloadFlags:TOverloadCheckFlags) : Boolean;
      var
        lLeftDef      : TDef;
        lOpToken : TToken;
        lOperatorProcDef  : TProcDef;
        lParaNode     : TCallParaNode;
        lCandidates : TCallCandidates;
        lCandidateCount : Integer;
        lInlineNumber: TInlineNumber;
      begin
        Result:=false;
        lOperatorProcDef:=nil;

        { load easier access variables }
        lLeftDef:=TUnaryNode(ANode).left.resultdef;

        { if we are dealing with inline function then get the function }
        if ANode.nodetype=inlinen then
          lInlineNumber:=TInlineNode(ANode).InlineNumber
        else
          lInlineNumber:=in_none;

        if not (ocf_check_non_overloadable in AOverloadFlags) and not IsUnaryOperatorOverloadable(ANode.nodetype,lInlineNumber,lLeftDef) then
          exit;

        { operator overload is possible }
        Result:=not (ocf_check_only in AOverloadFlags);

        lOpToken:=NOTOKEN;
        case ANode.nodetype of
           notn:
             lOpToken:=_OP_NOT;
           unaryminusn:
             lOpToken:=_MINUS;
           unaryplusn:
             lOpToken:=_PLUS;
           inlinen:
             case lInlineNumber of
                in_inc_x:
                  lOpToken:=_OP_INC;
                in_dec_x:
                  lOpToken:=_OP_DEC;
                else
                  ;
             end;
           else
             ;
        end;
        if (lOpToken=NOTOKEN) then
          begin
            if not (ocf_check_only in AOverloadFlags) then
              begin
                CGMessage(parser_e_operator_not_overloaded);
                ANode:=CNothingNode.Create;
              end;
            exit;
          end;

        { generate parameter nodes }
        { for inline nodes just copy existent callparanode }
        if (ANode.nodetype=inlinen) and (TInlineNode(ANode).left.nodetype=callparan) then
          lParaNode:=TCallParaNode(TInlineNode(ANode).left.GetCopy)
        else
          begin
            lParaNode:=CCallParaNode.Create(TUnaryNode(ANode).left.GetCopy,nil);
            lParaNode.Get_ParaType;
          end;
        lCandidates.Init_Operator(lOpToken,lParaNode);

        { stop when there are no operators found }
        if lCandidates.count=0 then
          begin
            lCandidates.Done;
            lParaNode.free;
            lParaNode := nil;
            if not (ocf_check_only in AOverloadFlags) then
              begin
                CGMessage2(parser_e_operator_not_overloaded_2,lLeftDef.TypeName,arraytokeninfo[lOpToken].str);
                ANode:=CNothingNode.Create;
              end;
            exit;
          end;

        { Retrieve information about the candidates }
        lCandidates.Get_Information;
{$ifdef EXTDEBUG}
        { Display info when multiple candidates are found }
        lCandidates.Dump_Info(VDebug);
{$endif EXTDEBUG}
        lCandidateCount:=lCandidates.Choose_Best(TAbstractProcDef(lOperatorProcDef),false);

        { exit when no overloads are found }
        if lCandidateCount=0 then
          begin
            lCandidates.Done;
            lParaNode.free;
            lParaNode := nil;
            if not (ocf_check_only in AOverloadFlags) then
              begin
                CGMessage2(parser_e_operator_not_overloaded_2,lLeftDef.TypeName,arraytokeninfo[lOpToken].str);
                ANode:=CNothingNode.Create;
              end;
            exit;
          end;

        { Multiple candidates left? }
        if (lCandidateCount>1) and not (ocf_check_only in AOverloadFlags) then
          begin
            CGMessage(type_e_cant_choose_overload_function);
{$ifdef EXTDEBUG}
            lCandidates.Dump_Info(VHint);
{$else EXTDEBUG}
            lCandidates.List(false);
{$endif EXTDEBUG}
            { we'll just use the first candidate to make the
              call }
          end;
        lCandidates.Done;

        if ocf_check_only in AOverloadFlags then
          begin
            lParaNode.free;
            lParaNode := nil;
            Result:=true;
            exit;
          end;

        AddSymRef(lOperatorProcDef.ProcSym,lOperatorProcDef);

        { the nil as symtable signs firstcalln that this is
          an overloaded operator }
        ANode:=CCallNode.Create(lParaNode,TProcSym(lOperatorProcDef.ProcSym),nil,nil,[],nil);

        { we already know the procdef to use, so it can
          skip the overload choosing in callnode.pass_typecheck }
        TCallNode(ANode).ProcDefinition:=lOperatorProcDef;
      end;


    function IsBinaryOverloaded(var ANode : TNode;AOverloadFlags:TOverloadCheckFlags) : Boolean;
      var
        lRightDef,lLeftDef   : TDef;
        lOpToken : TToken;
        lOperatorProcDef  : TProcDef;
        lTempNode      : TNode;
        lParaNode     : TCallParaNode;
        lIndex,lCandidateCount : SizeInt;

        function SearchOperator(AOpToken:TToken;AGenerateError:Boolean): Integer;
          var
            lCandidates : TCallCandidates;
          begin
            { generate parameter nodes }
            lParaNode:=CCallParaNode.Create(TBinaryNode(ANode).right.GetCopy,CCallParaNode.Create(TBinaryNode(ANode).left.GetCopy,nil));
            lParaNode.Get_ParaType;
            lCandidates.Init_Operator(AOpToken,lParaNode);

            { for commutative operators we can swap arguments and try again }
            if (lCandidates.count=0) and
               not(AOpToken in cNonCommutativeOpTokens) then
              begin
                lCandidates.Done;
                ReverseParameters(lParaNode);
                { reverse compare operators }
                case AOpToken of
                  _LT:
                    AOpToken:=_GTE;
                  _GT:
                    AOpToken:=_LTE;
                  _LTE:
                    AOpToken:=_GT;
                  _GTE:
                    AOpToken:=_LT;
                  else
                    ;
                end;
                lCandidates.Init_Operator(AOpToken,lParaNode);
              end;

            { stop when there are no operators found }
            Result:=lCandidates.count;
            if (Result=0) and AGenerateError then
              begin
                CGMessage(parser_e_operator_not_overloaded);
                lCandidates.Done;
                lParaNode.free;
                lParaNode:=nil;
                exit;
              end;

            if (Result>0) then
              begin
                { Retrieve information about the candidates }
                lCandidates.Get_Information;
        {$ifdef EXTDEBUG}
                { Display info when multiple candidates are found }
                lCandidates.Dump_Info(VDebug);
        {$endif EXTDEBUG}
                Result:=lCandidates.Choose_Best(TAbstractProcDef(lOperatorProcDef),false);
              end;

            { exit when no overloads are found }
            if (Result=0) and AGenerateError then
              begin
                CGMessage3(parser_e_operator_not_overloaded_3,lLeftDef.GetTypeName,arraytokeninfo[AOpToken].str,lRightDef.GetTypeName);
                lCandidates.Done;
                lParaNode.free;
                lParaNode:=nil;
                exit;
              end;

            { Multiple candidates left? }
            if Result>1 then
              begin
                CGMessage(type_e_cant_choose_overload_function);
    {$ifdef EXTDEBUG}
                lCandidates.Dump_Info(VHint);
    {$else EXTDEBUG}
                lCandidates.List(false);
    {$endif EXTDEBUG}
                { we'll just use the first candidate to make the
                  call }
              end;
            lCandidates.Done;
          end;

      begin
        IsBinaryOverloaded:=false;
        lOperatorProcDef:=nil;
        lParaNode:=nil;

        { load easier access variables }
        lLeftDef:=TBinaryNode(ANode).left.resultdef;
        lRightDef:=TBinaryNode(ANode).right.resultdef;
        if not (ocf_check_non_overloadable in AOverloadFlags) and
            not IsBinaryOperatorOverloadable(ANode.nodetype,lLeftDef,TBinaryNode(ANode).left.nodetype,lRightDef,TBinaryNode(ANode).right.nodetype) then
          exit;

        { operator overload is possible }
        { if we only check for the existence of the overload, then we assume that
          it is not overloaded }
        Result:=not (ocf_check_only in AOverloadFlags);

        lOpToken:=NOTOKEN;
        for lIndex:=1 to cTok2NodeCount do
          if (ANode.nodetype=Tok2Node[lIndex].Nod) and (op_binary in Tok2Node[lIndex].SupportedOpOverloads) then
            begin
              lOpToken:=Tok2Node[lIndex].Tok;
              break;
            end;
        if lOpToken=NOTOKEN then
          begin
            if not (ocf_check_only in AOverloadFlags) then
              begin
                CGMessage(parser_e_operator_not_overloaded);
                ANode:=CNothingNode.Create;
              end;
            exit;
          end;

        lCandidateCount:=SearchOperator(lOpToken,(lOpToken<>_NE) and not (ocf_check_only in AOverloadFlags));

        { no operator found for "<>" then search for "=" operator }
        if (lCandidateCount=0) and (lOpToken=_NE) and not (ocf_check_only in AOverloadFlags) then
          begin
            lParaNode.free;
            lParaNode:=nil;
            lOperatorProcDef:=nil;
            lOpToken:=_EQ;
            lCandidateCount:=SearchOperator(lOpToken,true);
          end;

        if (lCandidateCount=0) then
          begin
            lParaNode.free;
            lParaNode := nil;
            if not (ocf_check_only in AOverloadFlags) then
              ANode:=CNothingNode.Create;
            exit;
          end;

        if ocf_check_only in AOverloadFlags then
          begin
            lParaNode.free;
            lParaNode := nil;
            Result:=true;
            exit;
          end;

        AddSymRef(lOperatorProcDef.ProcSym,lOperatorProcDef);

        { the nil as symtable signs firstcalln that this is
          an overloaded operator }
        lTempNode:=CCallNode.Create(lParaNode,TProcSym(lOperatorProcDef.ProcSym),nil,nil,[],nil);

        { we already know the procdef to use, so it can
          skip the overload choosing in callnode.pass_typecheck }
        TCallNode(lTempNode).ProcDefinition:=lOperatorProcDef;

        { if we found "=" operator for "<>" expression then use it
          together with "not" }
        if (ANode.nodetype=unequaln) and (lOpToken=_EQ) then
          lTempNode:=CNotNode.Create(lTempNode);
        ANode:=lTempNode;
      end;


{****************************************************************************
                          Register Calculation
****************************************************************************}

    { marks an lvalue as "unregable" }
    procedure MakeNotRegableIntern(ANode : TNode; AHow: TRegableInfoFlags; ARecordsOnly: Boolean);
      var
        lHighSym: TAbstractVarSym;
      begin
        if ra_addr_taken in AHow then
          include(ANode.flags,nf_address_taken);
        repeat
          case ANode.nodetype of
            subscriptn:
              begin
                ARecordsOnly:=true;
                ANode:=TSubscriptNode(ANode).left;
              end;
            vecn:
              begin
                { if there's an implicit dereference, we can stop (just like
                  when there is an actual derefn) }
                if ((TVecNode(ANode).left.resultdef.typ=arraydef) and
                    not Is_Special_Array(TVecNode(ANode).left.resultdef)) or
                   ((TVecNode(ANode).left.resultdef.typ=stringdef) and
                    (TStringDef(TVecNode(ANode).left.resultdef).StringType in [st_shortstring,st_longstring])) then
                  ANode:=TVecNode(ANode).left
                else
                  break;
              end;
            typeconvn :
               begin
                 { implicit dereference -> stop }
                 if (TTypeConvNode(ANode).ConvType=tc_pointer_2_array) then
                   break;
                 if (TTypeConvNode(ANode).resultdef.typ=recorddef) then
                   ARecordsOnly:=false;
                 ANode:=TTypeConvNode(ANode).left;
               end;
            loadn :
              begin
                if (TLoadNode(ANode).SymTableEntry.typ in [staticvarsym,localvarsym,paravarsym]) then
                  begin
                    if (ra_addr_taken in AHow) then
                      TAbstractVarSym(TLoadNode(ANode).SymTableEntry).AddrTaken:=true;
                    if (ra_different_scope in AHow) then
                      begin
                        TAbstractVarSym(TLoadNode(ANode).SymTableEntry).DifferentScope:=true;
                        { Hidden bounds can be loaded only during code generation.
                          Reserve their frame location before allocating the parent. }
                        if TLoadNode(ANode).SymTableEntry.typ=paravarsym then
                          begin
                            lHighSym:=Get_High_Value_Sym(TParaVarSym(TLoadNode(ANode).SymTableEntry));
                            if Assigned(lHighSym) then
                              begin
                                lHighSym.DifferentScope:=true;
                                lHighSym.VarRegable:=vr_none;
                              end;
                          end;
                      end;
                    if (TAbstractVarSym(TLoadNode(ANode).SymTableEntry).VarRegable <> vr_none) and
                       ((not ARecordsOnly) or
                        (TAbstractVarSym(TLoadNode(ANode).SymTableEntry).vardef.typ = recorddef)) then
                      if (TLoadNode(ANode).SymTableEntry.typ = paravarsym) and
                         (ra_addr_regable in AHow) then
                        TAbstractVarSym(TLoadNode(ANode).SymTableEntry).VarRegable:=vr_addr
                      else
                        TAbstractVarSym(TLoadNode(ANode).SymTableEntry).VarRegable:=vr_none;
                  end;
                break;
              end;
            temprefn :
              begin
                if (ra_addr_taken in AHow) then
                  TTempRefNode(ANode).IncludeTempFlag(ti_addr_taken);
                if (ti_may_be_in_reg in TTempRefNode(ANode).TempFlags) and
                   ((not ARecordsOnly) or
                    (TTempRefNode(ANode).TempInfo^.TypeDef.typ = recorddef)) then
                  TTempRefNode(ANode).ExcludeTempFlag(ti_may_be_in_reg);
                break;
              end;
            else
              break;
          end;
        until false;
      end;

    procedure Make_Not_Regable(ANode : TNode; AHow: TRegableInfoFlags);
      begin
        MakeNotRegableIntern(ANode,AHow,false);
      end;


{****************************************************************************
                          Subroutine Handling
****************************************************************************}

    function Is_Proc2ProcVar_Load(ANode:TNode;out ARealProcDef:TProcDef):Boolean;
      begin
        Result:=false;
        { remove voidpointer typecast for tp procvars }
        if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
            (m_mac_procvar in CurrentSettings.ModeSwitches)) and
           (ANode.nodetype=typeconvn) and
           Is_VoidPointer(ANode.resultdef) then
          ANode:=TUnaryNode(ANode).left;
        Result:=(ANode.nodetype=typeconvn) and
                (TTypeConvNode(ANode).ConvType=tc_proc_2_procvar);
        if Result then
          ARealProcDef:=TProcDef(TTypeConvNode(ANode).left.resultdef);
      end;


    function Is_Ambiguous_FuncRet_Load(ANode: TNode; out AOwningProcDef: TProcDef): Boolean;
      begin
        Result:=false;
        { the funcret is an absolutevarsym, which gets converted into a type
          conversion node of the loadnode of the actual function result. Its
          resulttype is obviously the same as that of the real function result }
        if (ANode.nodetype=typeconvn) and
              (ANode.resultdef=TTypeConvNode(ANode).left.resultdef) then
          ANode:=TTypeConvNode(ANode).left;
        if (ANode.nodetype=loadn) and
           (TLoadNode(ANode).SymTableEntry.typ in [absolutevarsym,localvarsym,paravarsym]) and
           ([vo_is_funcret,vo_is_result] * TAbstractVarSym(TLoadNode(ANode).SymTableEntry).VarOptions = [vo_is_funcret]) then
         begin
           AOwningProcDef:=TProcDef(TLoadNode(ANode).SymTableEntry.owner.DefOwner);
           Result:=true;
         end;
      end;


    { local routines can't be assigned to procvars }
    procedure Test_Local_To_ProcVar(AFromDef:TProcVarDef;AToDef:TDef);
      begin
         if not(m_nested_procvars in CurrentSettings.ModeSwitches) and
            (AFromDef.ParaST.SymTableLevel>NormalFunctionLevel) and
            not (po_anonymous in AFromDef.ProcOptions) and
            (AToDef.typ=procvardef) and
            (TProcVarDef(AToDef).ParaST.SymTableLevel <= NormalFunctionLevel) then
           CGMessage(type_e_cannot_local_proc_to_procvar);
      end;


    procedure UninitializedVariableMessage(APosition : TFilePosInfo;AWarning,ALocal,AManaged : Boolean;AName : TMsgStr);
      const
        cUninitializedMessages : array[false..true,false..true,false..true] of dword = (
            (
              (sym_h_uninitialized_variable,sym_h_uninitialized_managed_variable),
              (sym_h_uninitialized_local_variable,sym_h_uninitialized_managed_local_variable)
            ),
            (
              (sym_w_uninitialized_variable,sym_w_uninitialized_managed_variable),
              (sym_w_uninitialized_local_variable,sym_w_uninitialized_managed_local_variable)
            )
          );
      begin
        CGMessagePos1(APosition,cUninitializedMessages[AWarning,ALocal,AManaged],AName);
      end;


    procedure Set_VarState(ANode:TNode;ANewState:TVarState;AVarStateFlags:TVarStateFlags);
      const
        cVarStateTransitions: array[TVarState,TVarState] of TVarState = (
          { vs_none -> ... }
          (vs_none,vs_declared,vs_initialised,vs_read,vs_read_not_warned,vs_referred_not_inited,vs_written,vs_readwritten),
          { vs_declared -> ... }
          (vs_none,vs_declared,vs_initialised,vs_read,vs_read_not_warned,vs_referred_not_inited,vs_written,vs_readwritten),
          { vs_initialised -> ... }
          (vs_none,vs_initialised,vs_initialised,vs_read,vs_read,vs_read,vs_written,vs_readwritten),
          { vs_read -> ... }
          (vs_none,vs_read,vs_read,vs_read,vs_read,vs_read,vs_readwritten,vs_readwritten),
          { vs_read_not_warned -> ... }
          (vs_none,vs_read_not_warned,vs_read,vs_read,vs_read_not_warned,vs_read_not_warned,vs_readwritten,vs_readwritten),
          { vs_referred_not_inited }
          (vs_none,vs_referred_not_inited,vs_read,vs_read,vs_read_not_warned,vs_referred_not_inited,vs_written,vs_readwritten),
          { vs_written -> ... }
          (vs_none,vs_written,vs_written,vs_readwritten,vs_readwritten,vs_written,vs_written,vs_readwritten),
          { vs_readwritten -> ... }
          (vs_none,vs_readwritten,vs_readwritten,vs_readwritten,vs_readwritten,vs_readwritten,vs_readwritten,vs_readwritten));
      var
        lVarSym : TAbstractVarSym;
      begin
        { make sure we can still warn about uninitialised use after high(v), @v etc }
        if (ANewState = vs_read) and
           not(vsf_must_be_valid in AVarStateFlags) then
          ANewState := vs_referred_not_inited;

        while Assigned(ANode) do
         begin
           case ANode.nodetype of
             derefn:
               begin
                 if (TDerefNode(ANode).left.nodetype=temprefn) and
                    Assigned(TTempRefNode(TDerefNode(ANode).left).TempInfo^.withnode) then
                   ANode:=TTempRefNode(TDerefNode(ANode).left).TempInfo^.withnode
                 else
                   break;
               end;
             typeconvn :
               begin
                 case TTypeConvNode(ANode).ConvType of
                   tc_cchar_2_pchar,
                   tc_cstring_2_pchar,
                   tc_array_2_pointer :
                     exclude(AVarStateFlags,vsf_must_be_valid);
                   tc_pchar_2_string,
                   tc_pointer_2_array :
                     begin
                       include(AVarStateFlags,vsf_must_be_valid);
                       { when a pointer is used for array access, the
                         pointer itself is read and never written }
                       ANewState := vs_read;
                     end;
                   else
                     ;
               end;
                 ANode:=TUnaryNode(ANode).left;
               end;
             subscriptn :
               begin
                 if Is_Implicit_Pointer_Object_Type(TUnaryNode(ANode).left.resultdef) then
                   ANewState := vs_read;
                 ANode:=TUnaryNode(ANode).left;
               end;
             vecn:
               begin
                 Set_VarState(TBinaryNode(ANode).right,vs_read,[vsf_must_be_valid]);
                 { dyn. arrays and dyn. strings are read }
                 if Is_Implicit_Array_Pointer(TUnaryNode(ANode).left.resultdef) then
                   ANewState:=vs_read;
                 if (ANewState in [vs_read,vs_readwritten]) or
                    not(TUnaryNode(ANode).left.resultdef.typ in [stringdef,arraydef]) then
                   include(AVarStateFlags,vsf_must_be_valid)
                 else if (ANewState = vs_written) then
                   exclude(AVarStateFlags,vsf_must_be_valid);
                 ANode:=TUnaryNode(ANode).left;
               end;
             { do not parse calln }
             calln :
               break;
             loadn :
               begin
                 { the methodpointer/framepointer is read }
                 if Assigned(TUnaryNode(ANode).left) then
                   Set_VarState(TUnaryNode(ANode).left,vs_read,[vsf_must_be_valid]);
                 if (TLoadNode(ANode).SymTableEntry.typ in [localvarsym,paravarsym,staticvarsym]) then
                   begin
                     lVarSym:=TAbstractVarSym(TLoadNode(ANode).SymTableEntry);
                     { this check requires proper data flow analysis... }
(*                     if (hsym.varspez=vs_final) and
                        (hsym.varstate in [vs_written,vs_readwritten]) and
                        (newstate in [vs_written,vs_readwritten]) then
                       CGMessagePos1(p.fileinfo,sym_e_final_write_once); *)
                     if (vsf_must_be_valid in AVarStateFlags) and
                        (lVarSym.VarState in [vs_declared,vs_read_not_warned,vs_referred_not_inited]) then
                       begin
                         { Give warning/note for uninitialized locals }
                         if Assigned(lVarSym.owner) and
                            not(vo_is_external in lVarSym.VarOptions) and
                            (lVarSym.owner.SymTableType in [parasymtable,LocalSymTable,staticsymtable]) and
                            ((lVarSym.owner=CurrentProcInfo.procdef.LocalST) or
                             (lVarSym.owner=CurrentProcInfo.procdef.ParaST)) then
                           begin
                             if vsf_use_hints in AVarStateFlags then
                               include(TLoadNode(ANode).LoadNodeFlags,loadnf_only_uninitialized_hint);
                             if not(cs_opt_nodedfa in CurrentSettings.OptimizerSwitches) then
                               begin
                                 if (vo_is_funcret in lVarSym.VarOptions) then
                                   begin
                                     { An uninitialized function Result of a managed type needs special handling.
                                       When passing it as a var parameter a warning need to be emitted, since a user
                                       may expect Result to be empty (nil) by default as it happens with local vars
                                       of a managed type. But this is not true for Result and may lead to serious issues.

                                       The only exception is SetLength(Result, ?) for a string Result. A user always
                                       expects undefined contents of the string after calling SetLength(). In such
                                       case a hint need to be emitted.
                                     }
                                     if Is_Managed_Type(lVarSym.vardef) then
                                       if not ( Is_String(lVarSym.vardef) and (vsf_use_hint_for_string_result in AVarStateFlags) ) then
                                         exclude(AVarStateFlags,vsf_use_hints);

                                     if vsf_use_hints in AVarStateFlags then
                                       begin
                                         if Is_Managed_Type(lVarSym.vardef) then
                                           CGMessagePos(ANode.fileinfo,sym_h_managed_function_result_uninitialized)
                                         else
                                           CGMessagePos(ANode.fileinfo,sym_h_function_result_uninitialized);
                                       end
                                     else
                                       begin
                                         if Is_Managed_Type(lVarSym.vardef) then
                                           CGMessagePos(ANode.fileinfo,sym_w_managed_function_result_uninitialized)
                                         else
                                          CGMessagePos(ANode.fileinfo,sym_w_function_result_uninitialized);
                                       end;
                                   end
                                 else
                                   begin
                                     UninitializedVariableMessage(ANode.fileinfo,

                                       not(vsf_use_hints in AVarStateFlags),
                                       TLoadNode(ANode).SymTable.SymTableType=LocalSymTable,
                                       Is_Managed_Type(TLoadNode(ANode).resultdef),
                                       lVarSym.realname);
                                   end;
                               end;
                           end
                         else if (ANewState = vs_read) then
                           ANewState := vs_read_not_warned;
                       end;
                     lVarSym.VarState := cVarStateTransitions[lVarSym.VarState,ANewState];
                   end;
                 case ANewState of
                   vs_written:
                     include(TLoadNode(ANode).flags,nf_write);
                   vs_readwritten:
                     if not(nf_write in TLoadNode(ANode).flags) then
                       include(TLoadNode(ANode).flags,nf_modify);
                   else
                     ;
                 end;
                 break;
               end;
             addrn:
               break;
             callparan :
               InternalError(200310081);
             else
               break;
           end;{case }
         end;
      end;


    procedure Set_Unique(ANode : TNode);
      begin
        while Assigned(ANode) do
         begin
           case ANode.nodetype of
             vecn:
               begin
                 include(TVecNode(ANode).VecNodeFlags,vnf_callunique);
                 break;
               end;
             typeconvn,
             subscriptn,
             derefn:
               ANode:=TUnaryNode(ANode).left;
             else
               break;
           end;
         end;
      end;


    function  ValidForAssign(ANode:TNode;AOptions:TValidAssigns; AReportErrors: Boolean):Boolean;
      var
        lTypeConvs: TFPObjectList;
        lNode2,
        lNode : TNode;
        lGotString,
        lGotSubscript,
        lGotRecord,
        lGotVec,
        lGotTypeConv : Boolean;
        lFromDef,
        lToDef    : TDef;
        lErrorMessage,
        lTemp     : LongInt;

        function ConstAccessOK(AVarSym: TAbstractVarSym): Boolean;
          begin
            Result:=false;
            { allow p^:= constructions with p is const parameter }
            if (ValidConst in AOptions) or
              ((lNode.nodetype=loadn) and
               (loadnf_isinternal_ignoreconst in TLoadNode(lNode).LoadNodeFlags)) then
              Result:=true
            { final (class) fields can only be initialised in the (class) constructors of
              class in which they have been declared (not in descendent constructors) }
            else if AVarSym.VarSpez=vs_final then
              begin
                if (CurrentProcInfo.procdef.owner=AVarSym.owner) then
                  if AVarSym.typ=staticvarsym then
                    Result:=CurrentProcInfo.procdef.ProcTypeOption=potype_class_constructor
                  else
                    Result:=CurrentProcInfo.procdef.ProcTypeOption=potype_constructor;
                if not Result and
                   AReportErrors then
                  CGMessagePos(lNode.fileinfo,type_e_invalid_final_assignment);
              end
            else
              if AReportErrors then
                CGMessagePos(lNode.fileinfo,type_e_no_assign_to_const);
          end;


        procedure MaybeResetTypeConvs;
          var
            lIndex: LongInt;
          begin
            if Assigned(lTypeConvs) then
              begin
                if not AReportErrors and
                   not Result then
                  for lIndex:=0 to lTypeConvs.Count-1 do
                    TTypeConvNode(lTypeConvs[lIndex]).AssignmentSide:=false;
                lTypeConvs.free;
                lTypeConvs := nil;
              end;
          end;


      begin
        if ValidConst in AOptions then
          lErrorMessage:=type_e_variable_id_expected
        else if ValidProperty in AOptions then
          lErrorMessage:=type_e_argument_cant_be_assigned
        else
          lErrorMessage:=type_e_no_addr_of_constant;
        Result:=false;
        lGotSubscript:=false;
        lGotVec:=false;
        lGotRecord:=false;
        lGotString:=false;
        lGotTypeConv:=false;
        lNode:=ANode;
        if not(ValidVoid in AOptions) and
           Is_Void(lNode.resultdef) then
         begin
           if AReportErrors then
             CGMessagePos(lNode.fileinfo,lErrorMessage);
           exit;
         end;
        lTypeConvs:=nil;
        while Assigned(lNode) do
         begin
           { property allowed? calln has a property check itself }
           if (nf_isproperty in lNode.flags) then
             begin
               { check return type }
               case lNode.resultdef.typ of
                 recorddef :
                   lGotRecord:=true;
                 stringdef :
                   lGotString:=true;
                 else
                   ;
               end;
               if (ValidProperty in AOptions) then
                 begin
                   { don't allow writing to calls that will create
                     temps like calls that return a structure and we
                     are assigning to a member }
                   if (ValidConst in AOptions) or
                      (
                       { allowing assignments to typecasted properties
                           a) is Delphi-incompatible
                           b) causes problems in case the getter is a function
                              (because then the result of the getter is
                               typecasted to this type, and then we "assign" to
                               this typecasted function result) -> always
                               disallow, since property accessors should be
                               transparently changeable to functions at all
                               times
                       }
                       not(lGotTypeConv) and
                       not(lGotSubscript and lGotRecord) and
                       not(lGotString and lGotVec) and
                       not(nf_no_lvalue in lNode.flags)
                      ) then
                     Result:=true
                   else
                     if AReportErrors then
                       CGMessagePos(lNode.fileinfo,lErrorMessage);
                 end
               else
                 begin
                   { 1. if it returns a pointer and we've found a deref,
                     2. if it returns a class and a subscription or with is found
                     3. if the address is needed of a field (subscriptn, vecn) }
                   if (lGotString and lGotVec) or
                      (
                       (ValidAddr in AOptions) and
                       (lNode.nodetype in [subscriptn,vecn])
                      ) then
                     Result:=true
                   else
                     if AReportErrors then
                       CGMessagePos(lNode.fileinfo,lErrorMessage);
                 end;
               MaybeResetTypeConvs;
               exit;
             end;
           case lNode.nodetype of
             temprefn :
               begin
                 ValidForAssign := not(ti_readonly in TTempRefNode(lNode).TempFlags);
                 MaybeResetTypeConvs;
                 exit;
               end;
             derefn :
               begin
                 { dereference -> always valid }
                 ValidForAssign:=true;
                 MaybeResetTypeConvs;
                 exit;
               end;
             typeconvn :
               begin
                 lGotTypeConv:=true;
                 { typecast sizes must match, exceptions:
                   - implicit typecast made by absolute
                   - from formaldef
                   - from void
                   - from/to open array
                   - typecast from pointer to array }
                 lFromDef:=TTypeConvNode(lNode).left.resultdef;
                 lToDef:=lNode.resultdef;
                 { typeconversions on the assignment side must keep
                   left.location the same }
                 TTypeConvNode(lNode).AssignmentSide:=true;
                 if not Assigned(lTypeConvs) then
                   lTypeConvs:=TFPObjectList.Create(false);
                 lTypeConvs.add(lNode);
                 if not((nf_absolute in TTypeConvNode(lNode).flags) or
                        TTypeConvNode(lNode).Target_Specific_General_TypeConv or
                        ((nf_explicit in lNode.flags) and
                         TTypeConvNode(lNode).Target_Specific_Explicit_TypeConv) or
                        (lFromDef.typ=formaldef) or
                        Is_Void(lFromDef) or
                        Is_Open_Array(lFromDef) or
                        Is_Open_Array(lToDef) or
                        ((lFromDef.typ=pointerdef) and (lToDef.typ=arraydef)) or
                        (Def_Is_Related(lFromDef,lToDef))) then
                  begin
                    if (lFromDef.Size<>lToDef.Size) then
                      begin
                        { A cast to a smaller type cannot use a register variable. }
                        if lToDef.Size<lFromDef.Size then
                          Make_Not_Regable(lNode,[ra_addr_regable])
                        else
                          if AReportErrors then
                            CGMessagePos2(lNode.fileinfo,type_e_typecast_wrong_size_for_assignment,ToStr(lFromDef.Size),ToStr(lToDef.Size));
                      end

                  end;

                 { don't allow assignments to typeconvs that need special code }
                 if not(lGotSubscript or lGotVec) and
                    not(TTypeConvNode(lNode).Assign_Allowed) then
                   begin
                     if AReportErrors then
                       CGMessagePos(lNode.fileinfo,lErrorMessage);
                     MaybeResetTypeConvs;
                     exit;
                   end;
                 case lNode.resultdef.typ of
                   arraydef :
                     begin
                       { pointer -> array conversion is done then we need to see it
                         as a deref, because a ^ is then not required anymore }
                       if TTypeConvNode(lNode).ConvType=tc_pointer_2_array then
                         begin
                           ValidForAssign:=true;
                           MaybeResetTypeConvs;
                           exit
                         end;
                     end;
                   else
                     ;
                 end;
                 lNode:=TTypeConvNode(lNode).left;
               end;
             vecn :
               begin
                 if (TVecNode(lNode).right.nodetype=rangen) and
                    not(ValidRange in AOptions) then
                  begin
                    if AReportErrors then
                      CGMessagePos(TVecNode(lNode).right.fileinfo,parser_e_illegal_expression);
                    MaybeResetTypeConvs;
                    exit;
                  end;
                 if { only check for first (= outermost) vec node }
                    not lGotVec and
                    not(ValidPacked in AOptions) and
                    (TVecNode(lNode).left.resultdef.typ = arraydef) and
                    (ado_IsBitPacked in TArrayDef(TVecNode(lNode).left.resultdef).ArrayOptions) and
                    ((TArrayDef(TVecNode(lNode).left.resultdef).ElePackedBitSize mod 8 <> 0) or
                     (Is_Ordinal(TArrayDef(TVecNode(lNode).left.resultdef).ElementDef) and
                      not IsPowerOf2(TArrayDef(TVecNode(lNode).left.resultdef).ElePackedBitSize div 8,lTemp))) then
                   begin
                     if AReportErrors then
                       if (ValidProperty in AOptions) then
                         CGMessagePos(lNode.fileinfo,parser_e_packed_element_no_loop)
                       else
                         CGMessagePos(lNode.fileinfo,parser_e_packed_element_no_var_addr);
                     MaybeResetTypeConvs;
                     exit;
                   end;
                 lGotVec:=true;
                 { accesses to dyn. arrays override read only access in delphi
                   -- now also in FPC, because the elements of a dynamic array
                      returned by a function can also be changed, or you can
                      assign the dynamic array to a variable and then change
                      its elements anyway }
                 if Is_Dynamic_Array(TUnaryNode(lNode).left.resultdef) then
                   begin
                     Result:=true;
                     MaybeResetTypeConvs;
                     exit;
                   end;
                 lNode:=TUnaryNode(lNode).left;
               end;
             asn :
               begin
                 { asn can't be assigned directly, it returns the value in a register instead
                   of reference. }
                 if not(lGotSubscript or lGotVec) then
                   begin
                     if AReportErrors then
                       CGMessagePos(lNode.fileinfo,lErrorMessage);
                     MaybeResetTypeConvs;
                     exit;
                   end;
                 lNode:=TUnaryNode(lNode).left;
               end;
             subscriptn :
               begin
                 { only check first (= outermost) subscriptn }
                 if not lGotSubscript and
                    not(ValidPacked in AOptions) and
                    Is_Packed_Record_Or_Object(TSubscriptNode(lNode).left.resultdef) and
                    ((TSubscriptNode(lNode).FieldSym.FieldOffset mod 8 <> 0) or
                     (Is_Ordinal(TSubscriptNode(lNode).resultdef) and
                      not IsPowerOf2(TSubscriptNode(lNode).resultdef.PackedBitSize div 8,lTemp)))  then
                   begin
                     if AReportErrors then
                       if (ValidProperty in AOptions) then
                         CGMessagePos(lNode.fileinfo,parser_e_packed_element_no_loop)
                       else
                         CGMessagePos(lNode.fileinfo,parser_e_packed_element_no_var_addr);
                     MaybeResetTypeConvs;
                     exit;
                   end;
                 { check for final fields }
                 if (TSubscriptNode(lNode).FieldSym.VarSpez=vs_final) and
                    not ConstAccessOK(TSubscriptNode(lNode).FieldSym) then
                   begin
                     MaybeResetTypeConvs;
                     exit;
                   end;
                 { if we assign something to a field of a record that is not
                   regable, then then the record can't be kept in a regvar,
                   because we will force the record into memory for this
                   subscript operation (to a temp location, so the assignment
                   will happen to the temp and be lost) }
                 if not lGotSubscript and
                    not lGotVec and
                    not TStoredDef(lNode.resultdef).Is_IntRegable then
                   Make_Not_Regable(lNode,[ra_addr_regable]);

                 lGotSubscript:=true;
                 { loop counter? }
                 if not(ValidConst in AOptions) and
                    (vo_is_loop_counter in TSubscriptNode(lNode).FieldSym.VarOptions) then
                   begin
                     if AReportErrors then
                       CGMessage1(parser_e_illegal_assignment_to_count_var,TSubscriptNode(lNode).FieldSym.realname);
                     MaybeResetTypeConvs;
                     exit;
                   end;
                 { implicit pointer object types result in dereferencing }
                 lNode:=TSubscriptNode(lNode).left;
                 if Is_Implicit_Pointer_Object_Type(lNode.resultdef) or
                    (lNode.resultdef.typ=classrefdef) then
                   begin
                     ValidForAssign:=true;
                     MaybeResetTypeConvs;
                     exit
                   end;
               end;
             muln,
             divn,
             andn,
             xorn,
             orn,
             notn,
             subn,
             addn :
               begin
                 { Temp strings are stored in memory, for compatibility with
                   delphi only }
                 if (m_delphi in CurrentSettings.ModeSwitches) and
                    ((ValidAddr in AOptions) or
                     (ValidConst in AOptions)) and
                    (lNode.resultdef.typ=stringdef) then
                   Result:=true
                 else
                  if AReportErrors then
                   CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);
                 MaybeResetTypeConvs;
                 exit;
               end;
             niln,
             pointerconstn :
               begin
                 { this is an implicit dereference, so it is valid for assign }
                 if lNode.resultdef.typ=arraydef then
                   begin
                     ValidForAssign:=true;
                     MaybeResetTypeConvs;
                     exit;
                   end;

                 if AReportErrors then
                   CGMessagePos(lNode.fileinfo,type_e_no_assign_to_addr);
                 MaybeResetTypeConvs;
                 exit;
               end;
             ordconstn,
             realconstn :
               begin
                 { these constants will be passed by value }
                 if AReportErrors then
                   CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);
                 MaybeResetTypeConvs;
                 exit;
               end;
             arrayconstructorn,
             setconstn,
             stringconstn,
             guidconstn :
               begin
                 { these constants will be passed by reference }
                 if ValidConst in AOptions then
                   Result:=true
                 else
                   if AReportErrors then
                     CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);
                 MaybeResetTypeConvs;
                 exit;
               end;
             addrn :
               begin
                 if AReportErrors then
                   CGMessagePos(lNode.fileinfo,type_e_no_assign_to_addr);
                 MaybeResetTypeConvs;
                 exit;
               end;
             blockn,
             calln :
               begin
                 if ((lNode.nodetype=calln) and not(Is_Void(lNode.resultdef))) or
                    (nf_no_lvalue in lNode.flags) then
                   begin
                     { Temp strings are stored in memory, for compatibility with
                       delphi only }
                     if (m_delphi in CurrentSettings.ModeSwitches) and
                        (ValidAddr in AOptions) and
                        (lNode.resultdef.typ=stringdef) then
                       Result:=true
                     else
                       if ([ValidConst,ValidAddr] * AOptions = [ValidConst]) then
                         Result:=true
                     else
                      if AReportErrors then
                       CGMessagePos(lNode.fileinfo,lErrorMessage);
                     MaybeResetTypeConvs;
                     exit;
                   end
                 else if lNode.nodetype=blockn then
                   begin
                     lNode2:=TBlockNode(lNode).statements;
                     if Assigned(lNode2) then
                       begin
                         if lNode2.nodetype<>statementn then
                           InternalError(2006110801);
                         while Assigned(TStatementNode(lNode2).Next) do
                           lNode2:=TStatementNode(lNode2).Next;
                         lNode:=TStatementNode(lNode2).statement;
                       end
                     else
                       begin
                         if AReportErrors then
                          CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);
                         MaybeResetTypeConvs;
                         exit;
                       end;
                   end
                 else
                   begin
                     if AReportErrors then
                      CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);
                     MaybeResetTypeConvs;
                     exit;
                   end;
               end;
             inlinen :
               begin
                 { recurse so volatile(non-lvalue):=... gives a proper error instead of IE 200203272 }
                 if TInlineNode(lNode).InlineNumber in [in_unaligned_x,in_aligned_x,in_volatile_x] then
                   begin
                     lNode:=TCallParaNode(TInlineNode(lNode).left).left;
                     continue;
                   end;
                 if ((ValidConst in AOptions) and
                     (TInlineNode(lNode).InlineNumber in [in_typeof_x])) then
                   Result:=true
                 else
                   if AReportErrors then
                    CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);
                 MaybeResetTypeConvs;
                 exit;
               end;
             nothingn :
               begin
                 { generics can generate nothing nodes, just allow everything }
                 if df_generic in CurrentProcInfo.procdef.DefOptions then
                   Result:=true
                 else if AReportErrors then
                   CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);

                 MaybeResetTypeConvs;
                 exit;
               end;
             loadn :
               begin
                 case TLoadNode(lNode).SymTableEntry.typ of
                   absolutevarsym,
                   staticvarsym,
                   localvarsym,
                   paravarsym :
                     begin
                       { loop counter? }
                       if not(ValidConst in AOptions) and
                          (vo_is_loop_counter in TAbstractVarSym(TLoadNode(lNode).SymTableEntry).VarOptions) then
                         begin
                           if AReportErrors then
                             CGMessage1(parser_e_illegal_assignment_to_count_var,TLoadNode(lNode).SymTableEntry.realname);
                           MaybeResetTypeConvs;
                           exit;
                         end;
                       { read-only variable? }
                       if (TAbstractVarSym(TLoadNode(lNode).SymTableEntry).VarSpez in [vs_const,vs_constref,vs_final]) then
                        begin
                          Result:=ConstAccessOK(TAbstractVarSym(TLoadNode(lNode).SymTableEntry));
                          MaybeResetTypeConvs;
                          exit;
                        end;
                       Result:=true;
                       MaybeResetTypeConvs;
                       exit;
                     end;
                   ProcSym :
                     begin
                       if (ValidConst in AOptions) then
                         Result:=true
                       else
                         if AReportErrors then
                          CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);
                       MaybeResetTypeConvs;
                       exit;
                     end;
                   labelsym :
                     begin
                       if (ValidAddr in AOptions) then
                         Result:=true
                       else
                         if AReportErrors then
                          CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);
                       MaybeResetTypeConvs;
                       exit;
                     end;
                   constsym:
                     begin
                       if (TConstSym(TLoadNode(lNode).SymTableEntry).ConstTyp in [constresourcestring,constwresourcestring]) and
                         (ValidAddr in AOptions) then
                         Result:=true
                       else
                         if AReportErrors then
                          CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);
                       MaybeResetTypeConvs;
                       exit;
                     end;
                   else
                     begin
                       if AReportErrors then
                        CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);
                       MaybeResetTypeConvs;
                       exit;
                     end;
                 end;
               end;
             else
               begin
                 if AReportErrors then
                  CGMessagePos(lNode.fileinfo,type_e_variable_id_expected);
                 MaybeResetTypeConvs;
                 exit;
               end;
            end;
         end;
         MaybeResetTypeConvs;
      end;


    function  Valid_For_Var(ANode:TNode; AReportErrors: Boolean):Boolean;
      begin
        Valid_For_Var:=ValidForAssign(ANode,[ValidRange],AReportErrors);
      end;


    function  Valid_For_Formal_Var(ANode : TNode; AReportErrors: Boolean) : Boolean;
      begin
        Valid_For_Formal_Var:=ValidForAssign(ANode,[ValidVoid,ValidRange],AReportErrors);
      end;


    function  Valid_For_Formal_ConstRef(ANode : TNode; AReportErrors: Boolean) : Boolean;
      begin
        Valid_For_Formal_ConstRef:=(ANode.resultdef.typ=formaldef) or
          ValidForAssign(ANode,[ValidVoid,ValidRange],AReportErrors);
      end;


    function  Valid_For_Formal_Const(ANode : TNode; AReportErrors: Boolean) : Boolean;
      begin
        Valid_For_Formal_Const:=(ANode.resultdef.typ=formaldef) or
          ValidForAssign(ANode,[ValidVoid,ValidConst,ValidProperty,ValidRange],AReportErrors);
      end;


    function  Valid_For_Assignment(ANode:TNode; AReportErrors: Boolean):Boolean;
      begin
        Valid_For_Assignment:=ValidForAssign(ANode,[ValidProperty,ValidPacked],AReportErrors);
      end;


    function  Valid_For_LoopVar(ANode:TNode; AReportErrors: Boolean):Boolean;
      begin
        Valid_For_LoopVar:=ValidForAssign(ANode,[ValidProperty],AReportErrors);
      end;


    function  Valid_For_Addr(ANode : TNode; AReportErrors: Boolean) : Boolean;
      begin
        Result:=ValidForAssign(ANode,[ValidConst,ValidAddr,ValidVoid],AReportErrors);
      end;


    procedure VarParaAllowed(var AEqualType:TEqualType;AFromDef,AToDef:TDef; AFromNode: TNode);
      begin
        { Note: eq must be already valid, it will only be updated! }
        case AToDef.typ of
          formaldef :
            begin
              { all types can be passed to a formaldef,
                but it is not the prefered way }
              if not Is_ConstNode(AFromNode) then
                AEqualType:=te_convert_l6
              else
                AEqualType:=te_incompatible;
            end;
          arraydef :
            begin
              if Is_Open_Array(AToDef) then
                begin
                  if Is_Dynamic_Array(AFromDef) and
                     Equal_Defs(TArrayDef(AFromDef).ElementDef,TArrayDef(AToDef).ElementDef) then
                    AEqualType:=te_convert_l2
                  else
                    if Equal_Defs(AFromDef,TArrayDef(AToDef).ElementDef) then
                      AEqualType:=te_convert_l3;
                end;
            end;
          pointerdef :
            begin
              { an implicit pointer conversion is allowed }
              if (AFromDef.typ=pointerdef) then
                AEqualType:=te_convert_l1;
            end;
          stringdef :
            begin
              { all shortstrings are allowed, size is not important }
              if Is_ShortString(AFromDef) and
                 Is_ShortString(AToDef) then
                AEqualType:=te_equal;
            end;
          objectdef :
            begin
              { child objects can be also passed }
              { in non-delphi mode, otherwise    }
              { they must match exactly, except  }
              { if they are objects              }
              if (AFromDef.typ=objectdef) and
                 (
                  (TObjectDef(AFromDef).ObjectType=odt_object) and
                  (TObjectDef(AToDef).ObjectType=odt_object)
                 ) and
                 (Def_Is_Related(TObjectDef(AFromDef),TObjectDef(AToDef))) then
                AEqualType:=te_convert_l1;
            end;
          filedef :
            begin
              { an implicit file conversion is also allowed }
              { from a typed file to an untyped one           }
              if (AFromDef.typ=filedef) and
                 (TFileDef(AFromDef).FileTyp = ft_typed) and
                 (TFileDef(AToDef).FileTyp = ft_untyped) then
                AEqualType:=te_convert_l1;
            end;
          else
            ;
        end;
      end;


    procedure ParaAllowed(var AEqualType:TEqualType;ANode:TCallParaNode;AToDef:TDef);
      var
        lCallNode: TArrayConstructorNode;
        lRealProcDef: TProcDef;
        lTempEqualType: TEqualType;
      begin
        { Note: eq must be already valid, it will only be updated! }
        case AToDef.typ of
          stringdef :
            begin
              { to support ansi/long/wide strings in a proper way }
              { string and string[10] are assumed as equal }
              { when searching the correct overloaded procedure   }
              if (ANode.resultdef.typ=stringdef) and
                 (TStringDef(AToDef).StringType=TStringDef(ANode.resultdef).StringType) and
                 (TStringDef(AToDef).encoding=TStringDef(ANode.resultdef).encoding) then
                AEqualType:=te_equal
            end;
          formaldef,
          setdef :
            begin
              { set can also be a not yet converted array constructor }
              if (ANode.resultdef.typ=arraydef) and
                 Is_Array_Constructor(ANode.resultdef) and
                 not Is_Variant_Array(ANode.resultdef) then
                AEqualType:=te_equal;
            end;
          procvardef :
            begin
              lTempEqualType:=te_incompatible;
              { in tp/macpas mode proc -> procvar is allowed }
              if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                  (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                 (ANode.left.nodetype=calln) then
                lTempEqualType:=Proc_To_ProcVar_Equal(TProcDef(TCallNode(ANode.left).ProcDefinition),TProcVarDef(AToDef),false);
              if (lTempEqualType=te_incompatible) and
                 (m_nested_procvars in CurrentSettings.ModeSwitches) and
                 Is_Proc2ProcVar_Load(ANode.left,lRealProcDef) then
                lTempEqualType:=Proc_To_ProcVar_Equal(lRealProcDef,TProcVarDef(AToDef),false);
              if (lTempEqualType=te_incompatible) and
                 (m_mac in CurrentSettings.ModeSwitches) and
                 Is_Ambiguous_FuncRet_Load(ANode.left,lRealProcDef) then
                lTempEqualType:=Proc_To_ProcVar_Equal(lRealProcDef,TProcVarDef(AToDef),false);
              if lTempEqualType<>te_incompatible then
                AEqualType:=lTempEqualType;
            end;
          objectdef :
            begin
              lTempEqualType:=te_incompatible;
              { in tp/macpas mode proc -> funcref is allowed }
              if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                  (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                 (ANode.left.nodetype=calln) and
                 Is_Invokable(AToDef) then
                lTempEqualType:=Proc_To_FuncRef_Conv(TProcDef(TCallNode(ANode.left).ProcDefinition),TObjectDef(AToDef));
              if lTempEqualType<>te_incompatible then
                AEqualType:=lTempEqualType;
            end;
          arraydef :
            begin
              { an arrayconstructor of proccalls may have to be converted to
                an array of procvars }
              if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                  (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                 (TArrayDef(AToDef).ElementDef.typ=procvardef) and
                 Is_Array_Constructor(ANode.resultdef) and
                 not Is_Variant_Array(ANode.resultdef) then
                begin
                  lCallNode:=TArrayConstructorNode(ANode.left);
                  if Assigned(lCallNode.left) then
                    begin
                      AEqualType:=te_exact;
                      while Assigned(lCallNode) and
                            (AEqualType<>te_incompatible) do
                        begin
                          if (lCallNode.left.nodetype=calln) then
                            lTempEqualType:=Proc_To_ProcVar_Equal(TProcDef(TCallNode(lCallNode.left).ProcDefinition),TProcVarDef(TArrayDef(AToDef).ElementDef),false)
                          else
                            lTempEqualType:=Compare_Defs(lCallNode.left.resultdef,TArrayDef(AToDef).ElementDef,lCallNode.left.nodetype);
                          if lTempEqualType<AEqualType then
                            AEqualType:=lTempEqualType;
                          lCallNode:=TArrayConstructorNode(lCallNode.right);
                        end;
                    end
                end;
            end;
          else
            ;
        end;
      end;


    function AllowEnumOp(ANodeType:TNodeType):Boolean;
      begin
        Result:=(ANodeType in [EqualN,unequaln,ltn,lten,gtn,gten]) or
                ((cs_allow_enum_calc in CurrentSettings.LocalSwitches) and
                 (ANodeType in [addn,subn]));
      end;


    procedure TCandidate.Increment_Ordinal_Distance(ADistance: UInt64);
      begin
      {$push} {$q-,r-} inc(OrdinalDistanceLo,ADistance); {$pop}
        if OrdinalDistanceLo<ADistance then
          inc(OrdinalDistanceHi); { Carry. }
      end;


{****************************************************************************
                           TCallCandidates
****************************************************************************}

    constructor TCallCandidates.Init(ASym:TProcSym;ASymTable:TSymTable;AParaNode:TNode;AFlags:TCallCandidatesFlags;ASpecializationContext:TSpecializationContext);
      begin
        if not Assigned(ASym) then
          InternalError(200411015);
        FOperator:=NOTOKEN;
        FProcSym:=ASym;
        FProcSymTable:=ASymTable;
        FParanode:=AParaNode;
        CreateCandidateList(AFlags,ASpecializationContext);
      end;


    constructor TCallCandidates.Init_Operator(AOperator:TToken;AParaNode:TNode);
      begin
        FOperator:=AOperator;
        FProcSym:=nil;
        FProcSymTable:=nil;
        FParanode:=AParaNode;
        CreateCandidateList([],nil);
      end;


    destructor TCallCandidates.Done;
      var
        lNextCandidate,
        lCandidate : PCandidate;
        lProcSym : TProcSym;
        lIndex : LongInt;
        lSym : TSym;
      begin
        { free any symbols for anonymous parameter types that we're used for
          specialization when no specialization was picked }
        TFPList.FreeAndNilObjects(FParaAnonSyms);
        lCandidate:=FCandidateProcs;
        while Assigned(lCandidate) do
         begin
           lNextCandidate:=lCandidate^.Next;
           { free those procdef specializations that are not owned (thus were discarded) }
           if lCandidate^.Data.Is_Specialization and not lCandidate^.Data.IsRegistered then
             begin
               { also remove the procdef from its symbol's procdeflist }
               lProcSym:=TProcSym(lCandidate^.Data.ProcSym);
               for lIndex:=0 to lProcSym.procdeflist.count-1 do
                 begin
                   if lProcSym.procdeflist[lIndex]=lCandidate^.Data then
                     begin
                       lProcSym.procdeflist.delete(lIndex);
                       break;
                     end;
                 end;
               FreeAndNil(lCandidate^.Data);
             end;
           dispose(lCandidate);
           lCandidate:=lNextCandidate;
         end;
      end;


    procedure TCallCandidates.CollectOverloadsInStruct(AStructDef:TAbstractRecordDef;AProcDefOverloadList:TFPObjectList;AFlags:TCallCandidatesFlags;ASpecializationContext:TSpecializationContext);

      var
        lChangedHierarchy : Boolean;

      function ProcessProcSym(ASym:TProcSym; out AFoundAnything: Boolean):Boolean;
        var
          lIndexJ  : Integer;
          lProcDef : TProcDef;
        begin
          { add all definitions }
          Result:=false;
          AFoundAnything:=false;
          { try to specialize the procsym }
          if ASym.Could_Be_Implicitly_Specialized and
            try_implicit_specialization(ASym,FParaNode,AProcDefOverloadList,FParaAnonSyms,TSym(FProcSym),Result) then
            AFoundAnything:=true;
          for lIndexJ:=0 to ASym.ProcdefList.Count-1 do
            begin
              lProcDef:=TProcDef(ASym.ProcdefList[lIndexJ]);
              if not finalize_specialization(lProcDef,ASpecializationContext) then
                continue;
              { in case of anonymous inherited, only match procdefs identical
                to the current one (apart from hidden parameters), rather than
                anything compatible to the parameters -- except in case of
                the presence of a messagestr/int, in which case those have to
                match exactly }
              if cc_anoninherited in AFlags then
                if po_msgint in CurrentProcInfo.procdef.ProcOptions then
                  begin
                    if not(po_msgint in lProcDef.ProcOptions) or
                       (lProcDef.MessageInf.i<>CurrentProcInfo.procdef.MessageInf.i) then
                      continue
                  end
                else if po_msgstr in CurrentProcInfo.procdef.ProcOptions then
                  begin
                    if not(po_msgstr in lProcDef.ProcOptions) or
                       (lProcDef.MessageInf.str^<>CurrentProcInfo.procdef.MessageInf.str^) then
                      continue
                  end
                else if (Compare_Paras(CurrentProcInfo.procdef.paras,lProcDef.paras,cp_all,[cpo_ignorehidden])<te_equal) then
                  continue;
              AFoundAnything:=true;
              { Store first procsym found }
              if not Assigned(FProcSym) then
                FProcSym:=TProcSym(ASym);
              if po_overload in lProcDef.ProcOptions then
                Result:=true;
              { if the hierarchy had been changed we need to check for duplicates }
              if not lChangedHierarchy or (AProcDefOverloadList.IndexOf(lProcDef)<0) then
                AProcDefOverloadList.Add(lProcDef);
            end;
        end;

      function ProcessHelper(AHashedID:THashedIDString;AHelperDef:TObjectDef):Boolean;
        var
          lSym : TSym;
          lHasOverload,lFoundAnything : Boolean;
        begin
          Result:=false;
          lSym:=nil;
          lHasOverload:=false;
          while Assigned(AHelperDef) do
            begin
              lSym:=TSym(AHelperDef.SymTable.FindWithHash(AHashedID));
              if Assigned(lSym) and
                  { Delphi allows hiding a property by a procedure with the same name }
                  (lSym.typ=ProcSym) and
                  (TProcSym(lSym).procdeflist.count>0) then
                begin
                  lHasOverload:=ProcessProcSym(TProcSym(lSym),lFoundAnything);
                  { when there is no explicit overload we stop searching }
                  if lFoundAnything and
                     not lHasOverload then
                    break;
                end;
              AHelperDef:=AHelperDef.ChildOf;
            end;
          if not lHasOverload and Assigned(lSym) then
            exit(true);
        end;

      var
        lSym      : TSym;
        lHashedID   : THashedIDString;
        lHasOverload,
        lFoundAnything : Boolean;
        lExtendedDef : TAbstractRecordDef;
        lHelperDef  : TObjectDef;
        lHelperList : TFPObjectList;
        lIndex : Integer;
      begin
        if FOperator=NOTOKEN then
          lHashedID.id:=FProcSym.name
        else
          lHashedID.id:=Overloaded_Names[FOperator];
        lHasOverload:=false;
        lExtendedDef:=nil;
        lChangedHierarchy:=false;
        while Assigned(AStructDef) do
         begin
           { first search in helpers for this type }
           if ((AStructDef.typ=recorddef) or
                 (
                   (AStructDef.typ=objectdef) and
                   (TObjectDef(AStructDef).ObjectType in ObjectTypesWithHelpers)
                 )
               )
               and (cc_searchhelpers in AFlags) then
             begin
               if m_multi_helpers in CurrentSettings.ModeSwitches then
                 begin
                   lHelperList:=Get_ObjectPascal_Helpers(AStructDef);
                   if Assigned(lHelperList) and (lHelperList.count>0) then
                     begin
                       lIndex:=lHelperList.count-1;
                       repeat
                         lHelperDef:=TObjectDef(lHelperList[lIndex]);
                         if (lHelperDef.owner.SymTableType in [staticsymtable,GlobalSymTable]) or
                            Is_Visible_For_Object(lHelperDef.TypeSym,lHelperDef) then
                              if ProcessHelper(lHashedID,lHelperDef) then
                                exit;
                         dec(lIndex);
                       until (lIndex<0);
                     end;
                 end
               else if Search_Last_ObjectPascal_Helper(AStructDef,nil,lHelperDef) and ProcessHelper(lHashedID,lHelperDef) then
                  exit;
             end;
           { now search in the type itself }
           lSym:=TSym(AStructDef.SymTable.FindWithHash(lHashedID));
           if Assigned(lSym) and
              { Delphi allows hiding a property by a procedure with the same name }
              (lSym.typ=ProcSym) then
             begin
               lHasOverload:=ProcessProcSym(TProcSym(lSym),lFoundAnything);
               { when there is no explicit overload we stop searching }
               if lFoundAnything and
                  not lHasOverload then
                 break;
             end;
           if Is_ObjectPascal_Helper(AStructDef) and
              (
                (TObjectDef(AStructDef).ExtendedDef.typ=recorddef) or
                (
                  (TObjectDef(AStructDef).ExtendedDef.typ=objectdef) and
                  (TObjectDef(TObjectDef(AStructDef).ExtendedDef).ObjectType in ObjectTypesWithHelpers)
                )
              ) then
             begin
               { remember the first extendeddef of the hierarchy }
               if not Assigned(lExtendedDef) then
                 lExtendedDef:=TAbstractRecordDef(TObjectDef(AStructDef).ExtendedDef);
               { search methods in the extended type as well }
               lSym:=TProcSym(TAbstractRecordDef(TObjectDef(AStructDef).ExtendedDef).SymTable.FindWithHash(lHashedID));
               if Assigned(lSym) and
                  { Delphi allows hiding a property by a procedure with the same name }
                  (lSym.typ=ProcSym) and
                  (TProcSym(lSym).procdeflist.count>0) then
                 begin
                   lHasOverload:=ProcessProcSym(TProcSym(lSym),lFoundAnything);
                   { when there is no explicit overload we stop searching }
                   if lFoundAnything and
                      not lHasOverload then
                     break;
                 end;
             end;
           { next parent }
           if (AStructDef.typ=objectdef) then
             AStructDef:=TObjectDef(AStructDef).ChildOf
           else
             AStructDef:=nil;
           { switch over to the extended def's hierarchy }
           if not Assigned(AStructDef) and Assigned(lExtendedDef) then
             begin
               AStructDef:=lExtendedDef;
               lExtendedDef:=nil;
               lChangedHierarchy:=true;
             end;
         end;
      end;


    procedure TCallCandidates.CollectOverloadsInUnits(AProcDefOverloadList:TFPObjectList; AFlags:TCallCandidatesFlags;ASpecializationContext:TSpecializationContext);
      var
        lIndexJ          : Integer;
        lProcDef         : TProcDef;
        lSymTable : TSymTable;
        lSym      : TSym;
        lCheckStack : PSymTableStackItem;
        lHashedID   : THashedIDString;
        lFoundAnything,
        lHasOverload : Boolean;
      begin
        { we search all overloaded operator definitions in the symtablestack. The found
          entries are only added to the procs list and not the procsym, because
          the list can change in every situation }
        if FOperator=NOTOKEN then
          begin
            if not (cc_objcidcall in AFlags) then
              lHashedID.id:=FProcSym.name
            else
              lHashedID.id:=ClassHelperPrefix+FProcSym.name;
          end
        else
          lHashedID.id:=Overloaded_Names[FOperator];

        lCheckStack:=SymTableStack.stack;
        if Assigned(FProcSymTable) then
          begin
            while Assigned(lCheckStack) and
                  (lCheckStack^.SymTable<>FProcSymTable) do
              lCheckStack:=lCheckStack^.Next;
          end;
        while Assigned(lCheckStack) do
          begin
            lSymTable:=lCheckStack^.SymTable;
            { if the unit in which the routine has to be searched has been
              specified explicitly, stop searching after its symtable(s) have
              been checked (can be both the static and the global symtable
              in case it's the current unit itself) }
            if (cc_explicitunit in AFlags) and
               (FProcSymTable.SymTableType in [GlobalSymTable,staticsymtable]) and
               (lSymTable.ModuleID<>FProcSymTable.ModuleID) then
              break;
            if (lSymTable.SymTableType in [LocalSymTable,staticsymtable,GlobalSymTable]) and
                (
                  (FOperator=NOTOKEN) or
                  (sto_has_operator in lSymTable.TableOptions)
                )
               then
              begin
                lSym:=TSym(lSymTable.FindWithHash(lHashedID));
                if Assigned(lSym) and
                   (lSym.typ=ProcSym) and
                   (
                     (TProcSym(lSym).procdeflist.count>0) or
                     (sp_generic_dummy in lSym.SymOptions)
                   ) then
                  begin
                    { add all definitions }
                    lHasOverload:=false;
                    lFoundAnything:=false;
                    if TProcSym(lSym).Could_Be_Implicitly_Specialized then
                      lFoundAnything:=try_implicit_specialization(lSym,FParaNode,AProcDefOverloadList,FParaAnonSyms,TSym(FProcSym),lHasOverload);
                    for lIndexJ:=0 to TProcSym(lSym).ProcdefList.Count-1 do
                      begin
                        lProcDef:=TProcDef(TProcSym(lSym).ProcdefList[lIndexJ]);
                        if not finalize_specialization(lProcDef,ASpecializationContext) then
                          continue;
                        { Store first procsym found }
                        if not Assigned(FProcSym) then
                          FProcSym:=TProcSym(lSym);
                        if po_overload in lProcDef.ProcOptions then
                          lHasOverload:=true;
                        AProcDefOverloadList.Add(lProcDef);
                        lFoundAnything:=true;
                      end;
                    { when there is no explicit overload we stop searching,
                      except for Objective-C methods called via id }
                    if lFoundAnything and
                       not lHasOverload and
                       not (cc_objcidcall in AFlags) then
                      break;
                  end;
              end;
            lCheckStack:=lCheckStack^.Next
          end;
      end;


    procedure TCallCandidates.CreateCandidateList(AFlags:TCallCandidatesFlags;ASpecializationContext:TSpecializationContext);
      var
        lIndexJ     : Integer;
        lProcDef    : TProcDef;
        lCandidate    : PCandidate;
        lParaNode    : TCallParaNode;
        lFound,
        lAdded : Boolean;
        lSymTable    : TSymTable;
        lContextStructDef : TAbstractRecordDef;
        lProcDefOverloadList : TFPObjectList;
        lCompareParaOptions : TCompareParasOptions;
      begin
        FCandidateProcs:=nil;

        { Find all available overloads for this procsym }
        lProcDefOverloadList:=TFPObjectList.Create(false);
        if not (cc_objcidcall in AFlags) and
           (FOperator=NOTOKEN) and
           (FProcSym.owner.SymTableType in [objectsymtable,recordsymtable]) then
          CollectOverloadsInStruct(TAbstractRecordDef(FProcSym.owner.DefOwner),lProcDefOverloadList,AFlags,ASpecializationContext)
        else
        if (FOperator<>NOTOKEN) then
          begin
            { check operands and if they contain records then search in records,
              then search in unit }
            lParaNode:=TCallParaNode(FParaNode);
            while Assigned(lParaNode) do
              begin
                if (lParaNode.resultdef.typ=recorddef) and
                    (sto_has_operator in TAbstractRecordDef(lParaNode.resultdef).SymTable.TableOptions) then
                  CollectOverloadsInStruct(TAbstractRecordDef(lParaNode.resultdef),lProcDefOverloadList,AFlags,ASpecializationContext);
                lParaNode:=TCallParaNode(lParaNode.right);
              end;
            CollectOverloadsInUnits(lProcDefOverloadList,AFlags,ASpecializationContext);
          end
        else
          CollectOverloadsInUnits(lProcDefOverloadList,AFlags,ASpecializationContext);

        { determine length of parameter list.
          for operators also enable the variant-operators if
          a variant parameter is passed }
        FParalength:=0;
        FAllowVariant:=(FOperator=NOTOKEN);
        lParaNode:=TCallParaNode(FParaNode);
        while Assigned(lParaNode) do
          begin
            if (lParaNode.resultdef.typ=variantdef) then
              FAllowVariant:=true;
            inc(FParalength);
            lParaNode:=TCallParaNode(lParaNode.right);
          end;

        { when the class passed is defined in this unit we
          need to use the scope of that class. This is a trick
          that can be used to access protected members in other
          units. At least kylix supports it this way (PFV) }
        if Assigned(FProcSymTable) and
           (
            (FProcSymTable.SymTableType in [ObjectSymtable,recordsymtable]) or
            ((FProcSymTable.SymTableType=withsymtable) and
             (FProcSymTable.DefOwner.typ in [objectdef,recorddef]))
           ) and
           (FProcSymTable.DefOwner.owner.SymTableType in [GlobalSymTable,staticsymtable,objectsymtable,recordsymtable]) and
           FProcSymTable.DefOwner.owner.IsCurrentUnit then
          lContextStructDef:=TAbstractRecordDef(FProcSymTable.DefOwner)
        else
          lContextStructDef:=CurrentStructDef;

        { symtable is needed later to calculate the distance }
        if Assigned(FProcSym) then
          lSymTable:=FProcSym.Owner
        else
          lSymTable:=nil;
        { Process all found overloads }
        for lIndexJ:=0 to lProcDefOverloadList.Count-1 do
          begin
            lProcDef:=TProcDef(lProcDefOverloadList[lIndexJ]);
            lAdded:=false;

            { only when the # of parameter are supported by the procedure and
              it is visible }
{$ifdef DISABLE_FAST_OVERLOAD_PATCH}
            if (FParalength>=lProcDef.MinParaCount) and
{$else}
            if (lProcDef.SeenMarker<>Pointer(@Self)) and (FParalength>=lProcDef.MinParaCount) and
{$endif}
               (
                (
                 (cc_allowdefaultparas in AFlags) and
                 (
                  (FParalength<=lProcDef.MaxParaCount) or
                  (po_varargs in lProcDef.ProcOptions)
                 )
                ) or
                (
                 not (cc_allowdefaultparas in AFlags) and
                 (FParalength=lProcDef.MaxParaCount)
                )
               ) and
               (
                (cc_ignorevisibility in AFlags) or
                (
                  lProcDef.Is_Specialization and not Assigned(lProcDef.owner) and
                  (
                    not (lProcDef.GenericDef.owner.SymTableType in [objectsymtable,recordsymtable]) or
                    Is_Visible_For_Object(TProcDef(lProcDef.GenericDef),lContextStructDef)
                  )
                ) or
                (
                  Assigned(lProcDef.owner) and
                  (
                    not (lProcDef.owner.SymTableType in [objectsymtable,recordsymtable]) or
                    Is_Visible_For_Object(lProcDef,lContextStructDef)
                  )
                )
               ) then
              begin
                { don't add duplicates, only compare visible parameters for the user }
                lCompareParaOptions:=[cpo_ignorehidden];
                if (po_compilerproc in lProcDef.ProcOptions) then
                  lCompareParaOptions:=lCompareParaOptions+[cpo_compilerproc];
                if (po_rtlproc in lProcDef.ProcOptions) then
                  lCompareParaOptions:=lCompareParaOptions+[cpo_rtlproc];
                lFound:=false;
                lCandidate:=FCandidateProcs;
{$ifdef DISABLE_FAST_OVERLOAD_PATCH}
                while Assigned(lCandidate) do
                  begin
                    if (Compare_Paras(lCandidate^.Data.paras,lProcDef.paras,cp_value_equal_const,lCompareParaOptions)>=te_equal) and
                       (not(po_objc in lProcDef.ProcOptions) or
                        (lProcDef.MessageInf.str^=lCandidate^.Data.MessageInf.str^)) then
                      begin
                        lFound:=true;
                        break;
                      end;
                    lCandidate:=lCandidate^.Next;
                  end;
{$endif}
                if not lFound then
                  begin
                    ProcAdd(lSymTable,lProcDef);
                    lAdded:=true;
{$ifndef DISABLE_FAST_OVERLOAD_PATCH}
                    lProcDef.SeenMarker:=Pointer(@Self);
{$endif}
                  end;
              end;

            { we need to remove all specializations that were not used from their
              procsyms as no code must be generated for them (if they are used
              later on they'll be added like the ones that were used now) }
            if not lAdded and Assigned(ASpecializationContext) and not lProcDef.IsRegistered then
              begin
                if TProcSym(lProcDef.ProcSym).procdeflist.extract(lProcDef)<>lProcDef then
                  InternalError(20150828);
                lProcDef.free;
                lProcDef := nil;
              end;
          end;
{$ifndef DISABLE_FAST_OVERLOAD_PATCH}
        {cleanup modified duplicate pd markers}
        lCandidate := FCandidateProcs;
        while Assigned(lCandidate) do begin
          lCandidate^.Data.SeenMarker := nil;
          lCandidate := lCandidate^.Next;
        end;
{$endif}

        CalcDistance(lSymTable,AFlags);

        lProcDefOverloadList.Free;
        lProcDefOverloadList := nil;
      end;


    procedure TCallCandidates.CalcDistance(ARootSymTable: TSymTable; AFlags:TCallCandidatesFlags);
      var
        lProcDef:TProcDef;
        lCandidate:PCandidate;
        lSymTable: TSymTable;
      begin
        { Give a small penalty for overloaded methods not defined in the
          current class/unit }
        lSymTable:=nil;
        if (cc_objcidcall in AFlags) or
           not Assigned(ARootSymTable) or
           not Assigned(ARootSymTable.DefOwner) or
           (ARootSymTable.DefOwner.typ<>objectdef) then
          lSymTable:=ARootSymTable
        else
          repeat
            { In case of a method, st_root is the symtable of the first found
              procsym with the called method's name, but this procsym may not
              contain any of the overloads that match the used parameters (which
              are the procdefs that have been collected as candidates) -> walk
              up the class hierarchy and look for the first class that actually
              defines at least one of the candidate procdefs.

              The reason is that we will penalise methods in other classes/
              symtables, so if we pick a symtable that does not contain any of
              the candidates, this won't help with picking the best/
              most-inner-scoped one (since all of them will be penalised) }
            lCandidate:=FCandidateProcs;

            { the current class contains one of the candidates? }
            while Assigned(lCandidate) do
              begin
                lProcDef:=lCandidate^.Data;
                if lProcDef.owner=ARootSymTable then
                  begin
                    { yes -> choose this class }
                    lSymTable:=ARootSymTable;
                    break;
                  end;
                lCandidate:=lCandidate^.Next;
              end;

            { None found -> go to parent class }
            if not Assigned(lSymTable) then
              begin
                if not Assigned(ARootSymTable.DefOwner) then
                  InternalError(201605301);

                { no more parent class -> take current class as root anyway
                  (could maybe happen in case of a class helper?) }
                if not Assigned(TObjectDef(ARootSymTable.DefOwner).ChildOf) then
                  begin
                    lSymTable:=ARootSymTable;
                    break;
                  end;

                ARootSymTable:=TObjectDef(ARootSymTable.DefOwner).ChildOf.SymTable;
              end;
          until Assigned(lSymTable);

        lCandidate:=FCandidateProcs;
        {  when calling Objective-C methods via id.method, then the found
           procsym will be inside an arbitrary ObjectSymtable, and we don't
           want to give the methods of that particular objcclass precedence
           over other methods, so instead check against the symtable in
           which this objcclass is defined }
        if cc_objcidcall in AFlags then
          lSymTable:=lSymTable.DefOwner.owner;
        while Assigned(lCandidate) do
          begin
            lProcDef:=lCandidate^.Data;

            if lSymTable<>lProcDef.owner then
              lCandidate^.Increment_Ordinal_Distance(1);

            lCandidate:=lCandidate^.Next;
          end;
      end;


    function TCallCandidates.ProcAdd(ASymTable:TSymTable;AProcDef:TProcDef):PCandidate;
      var
        lDefaultParaCount : Integer;
      begin
        { generate new candidate entry }
        new(Result);
        fillchar(Result^,sizeof(TCandidate),0);
        Result^.Data:=AProcDef;
        Result^.Next:=FCandidateProcs;
        FCandidateProcs:=Result;
        inc(FProccnt);
        { Find last parameter, skip all default parameters
          that are not passed. Ignore this skipping for varargs }
        Result^.FirstParaIdx:=AProcDef.paras.count-1;
        if not(po_varargs in AProcDef.ProcOptions) then
         begin
           { ignore hidden parameters }
           while (Result^.FirstParaIdx>=0) and (vo_is_hidden_para in TParaVarSym(AProcDef.paras[Result^.FirstParaIdx]).VarOptions) do
             dec(Result^.FirstParaIdx);
           lDefaultParaCount:=AProcDef.MaxParaCount-FParalength;
           if lDefaultParaCount>0 then
             begin
               if lDefaultParaCount>Result^.FirstParaIdx+1 then
                 InternalError(200401141);
               dec(Result^.FirstParaIdx,lDefaultParaCount);
             end;
         end;
      end;


    procedure TCallCandidates.List(AAll:Boolean);
      var
        lCandidate : PCandidate;
      begin
        lCandidate:=FCandidateProcs;
        while Assigned(lCandidate) do
         begin
           if AAll or
              (not lCandidate^.Invalid) then
             MessagePos1(lCandidate^.Data.fileinfo,sym_h_param_list,lCandidate^.Data.FullProcName(false));
           lCandidate:=lCandidate^.Next;
         end;
      end;


{$ifdef EXTDEBUG}
    procedure TCallCandidates.Dump_Info(ALevel:LongInt);

        function ParaTreeStr(ANode:TCallParaNode):String;
        begin
          Result:='';
          while Assigned(ANode) do
           begin
             if Result<>'' then
              Result:=','+Result;
             Result:=ANode.resultdef.TypeName+Result;
             ANode:=TCallParaNode(ANode.right);
           end;
        end;

      var
        lCandidate : PCandidate;
        lIndex  : Integer;
        lCurrentParaSym : TParaVarSym;
      begin
        if not CheckVerbosity(ALevel) then
         exit;
        Comment(ALevel+VLineInfo,'Overloaded callnode: '+FProcSym.name+'('+ParaTreeStr(TCallParaNode(FParaNode))+')');
        lCandidate:=FCandidateProcs;
        while Assigned(lCandidate) do
         begin
           Comment(ALevel,'  '+lCandidate^.Data.FullProcName(false));
           if (lCandidate^.Invalid) then
            Comment(ALevel,'   invalid')
           else
            begin
              Comment(ALevel,'   ex: '+ToStr(lCandidate^.TECount[te_exact])+
                          ' eq: '+ToStr(lCandidate^.TECount[te_equal])+
                          ' l1: '+ToStr(lCandidate^.TECount[te_convert_l1])+
                          ' l2: '+ToStr(lCandidate^.TECount[te_convert_l2])+
                          ' l3: '+ToStr(lCandidate^.TECount[te_convert_l3])+
                          ' l4: '+ToStr(lCandidate^.TECount[te_convert_l4])+
                          ' l5: '+ToStr(lCandidate^.TECount[te_convert_l5])+
                          ' l6: '+ToStr(lCandidate^.TECount[te_convert_l6])+
                          ' oper: '+ToStr(lCandidate^.TECount[te_convert_operator])+
                          ' ordhi: '+ToStr(lCandidate^.OrdinalDistanceHi)+
                          ' ordlo: '+ToStr(lCandidate^.OrdinalDistanceLo)+
                          ' ord2: '+ToStr(lCandidate^.OrdinalDistanceSecondary));
              { Print parameters in left-right order }
              for lIndex:=0 to lCandidate^.Data.paras.count-1 do
               begin
                 lCurrentParaSym:=TParaVarSym(lCandidate^.Data.paras[lIndex]);
                 if not(vo_is_hidden_para in lCurrentParaSym.VarOptions) then
                   Comment(ALevel,'    - '+lCurrentParaSym.vardef.TypeName+' : '+EqualTypeName[lCurrentParaSym.EqVal]);
               end;
            end;
           lCandidate:=lCandidate^.Next;
         end;
      end;
{$endif EXTDEBUG}


    procedure TCallCandidates.Get_Information;
      var
        lCandidate       : PCandidate;
        lCurrentParaSym : TParaVarSym;
        lParaIndex,lFPPrecisionDistance : Integer;
        lCurrentParaNr : Word;
        lFromObjectDef,
        lToObjectDef   : TObjectDef;
        lFromDef,
        lToDef   : TDef;
        lCurrentParaNode,
        lParaNode       : TCallParaNode;
        lEqualType,
        lMinEqualType    : TEqualType;
        lConversionType : TConvertType;
        lTempProcDef,
        lOperatorProcDef   : TProcDef;
        lReleaseCurrentParaNode, lCheckValidVar : Boolean;
        lCompareDefOptions : TCompareDefsOptions;
        lNode : TNode;

        function FPPrecisionScore(ADef: TDef): Integer;
          begin
            if Is_Extended(ADef) then
              Result:=4
            else if Is_Double(ADef) then
              Result:=2
            else
              Result:=1;
          end;

      begin
        lCompareDefOptions:=[cdo_check_operator];
        if FAllowVariant then
          include(lCompareDefOptions,cdo_allow_variant);
        { process all procs }
        lCandidate:=FCandidateProcs;
        while Assigned(lCandidate) do
         begin
           { We compare parameters in reverse order (right to left),
             the firstpara is already pointing to the last parameter
             were we need to start comparing }
           lCurrentParaNr:=FParalength;
           lParaIndex:=lCandidate^.FirstParaIdx;
           while (lParaIndex>=0) and (vo_is_hidden_para in TParaVarSym(lCandidate^.Data.paras[lParaIndex]).VarOptions) do
             dec(lParaIndex);
           lParaNode:=TCallParaNode(FParaNode);
           while Assigned(lParaNode) and ((lParaIndex>=0) or (po_varargs in lCandidate^.Data.ProcOptions)) do
            begin
              if lParaIndex<0 then
                lCurrentParaSym:=nil
              else
                lCurrentParaSym:=TParaVarSym(lCandidate^.Data.paras[lParaIndex]);
              { currpt can be changed from loadn to calln when a procvar
                is passed. This is to prevent that the change is permanent }
              lCurrentParaNode:=lParaNode;
              lReleaseCurrentParaNode:=false;
              { Should we check if the callparanode.left is valid for var }
              lCheckValidVar:=true;
              { retrieve current parameter definitions to compares }
              lEqualType:=te_incompatible;
              lFromDef:=lCurrentParaNode.resultdef;
              if Assigned(lCurrentParaSym) then
                lToDef:=lCurrentParaSym.vardef
              else
                lToDef:=nil;
              if not(Assigned(lFromDef)) then
               InternalError(200212091);
              if not(
                     Assigned(lToDef) or
                     ((po_varargs in lCandidate^.Data.ProcOptions) and
                      (lCurrentParaNr>lCandidate^.Data.MinParaCount))
                    ) then
               InternalError(200212092);

              { Convert tp procvars when not expecting a procvar }
             if Assigned(lToDef) and
                (lCurrentParaNode.left.resultdef.typ=procvardef) and
                not(lToDef.typ in [procvardef,formaldef]) and
                { if it doesn't require any parameters }
                (TProcVarDef(lCurrentParaNode.left.resultdef).MinParaCount=0) and
                { Only convert to call when there is no overload or the return type
                  is compatible with the expected type. }
                (
                 (count=1) or
                 (Compare_Defs_Ext(TProcVarDef(lCurrentParaNode.left.resultdef).ReturnDef,lToDef,nothingn,lConversionType,lOperatorProcDef,[])>te_incompatible)
                ) then
               begin
                 lReleaseCurrentParaNode:=true;
                 lCurrentParaNode:=TCallParaNode(lParaNode.GetCopy);
                 if Maybe_Call_ProcVar(lCurrentParaNode.left,true) then
                   begin
                     lCurrentParaNode.resultdef:=lCurrentParaNode.left.resultdef;
                     lFromDef:=lCurrentParaNode.left.resultdef;
                   end;
               end;

             { If we expect a procvar and the left is loadnode that
               returns a procdef we need to find the correct overloaded
               procdef that matches the expected procvar. The loadnode
               temporary returned the first procdef (PFV) }
             if Assigned(lToDef) and
                (
                   (lToDef.typ=procvardef) or
                   Is_FuncRef(lToDef)
                ) and
                (lCurrentParaNode.left.nodetype=loadn) and
                (lCurrentParaNode.left.resultdef.typ=procdef) then
               begin
                 if lToDef.typ=procvardef then
                   lTempProcDef:=TProcSym(TLoadNode(lCurrentParaNode.left).SymTableEntry).Find_ProcDef_ByProcVarDef(TProcVarDef(lToDef))
                 else
                   lTempProcDef:=TProcSym(TLoadNode(lCurrentParaNode.left).SymTableEntry).Find_ProcDef_ByFuncRefDef(TObjectDef(lToDef));
                 if Assigned(lTempProcDef) then
                   begin
                     TLoadNode(lCurrentParaNode.left).SetProcDef(lTempProcDef,lToDef.typ<>procvardef);
                     lCurrentParaNode.resultdef:=lCurrentParaNode.left.resultdef;
                     lFromDef:=lCurrentParaNode.left.resultdef;
                   end;
               end;

             { same as above, but for the case that we have a proc-2-procvar
               conversion together with a load }
             if Assigned(lToDef) and
                (
                   (lToDef.typ=procvardef) or
                   Is_FuncRef(lToDef)
                ) and
                (lCurrentParaNode.left.nodetype=typeconvn) and
                (TTypeConvNode(lCurrentParaNode.left).ConvType=tc_proc_2_procvar) and
                (TTypeConvNode(lCurrentParaNode.left).ToTypeDef=VoidType) and
                not (nf_explicit in lCurrentParaNode.left.flags) and
                (TTypeConvNode(lCurrentParaNode.left).left.nodetype=loadn) and
                (TTypeConvNode(lCurrentParaNode.left).left.resultdef.typ=procdef) then
               begin
                 if lToDef.typ=procvardef then
                   lTempProcDef:=TProcSym(TLoadNode(TTypeConvNode(lCurrentParaNode.left).left).SymTableEntry).Find_ProcDef_ByProcVarDef(TProcVarDef(lToDef))
                 else
                   lTempProcDef:=TProcSym(TLoadNode(TTypeConvNode(lCurrentParaNode.left).left).SymTableEntry).Find_ProcDef_ByFuncRefDef(TObjectDef(lToDef));
                 if Assigned(lTempProcDef) then
                   begin
                     TLoadNode(TTypeConvNode(lCurrentParaNode.left).left).SetProcDef(lTempProcDef,lToDef.typ<>procvardef);
                     TTypeConvNode(lCurrentParaNode.left).ToTypeDef:=CProcVarDef.GetReusableProcAddr(lTempProcDef,pc_normal);
                     TTypeConvNode(lCurrentParaNode.left).resultdef:=TTypeConvNode(lCurrentParaNode.left).ToTypeDef;
                     lFromDef:=TTypeConvNode(lCurrentParaNode.left).resultdef;
                   end;
               end;

              { varargs are always equal, but not exact }
              if (po_varargs in lCandidate^.Data.ProcOptions) and
                 (lCurrentParaNr>lCandidate^.Data.MinParaCount) and
                 not Is_Array_Of_Const(lFromDef) and
                 not Is_Array_Constructor(lFromDef) then
                lEqualType:=te_equal
              else
              { same definition -> exact }
               if (lFromDef=lToDef) then
                 lEqualType:=te_exact
              else
              { for value and const parameters check if a integer is constant or
                included in other integer -> equal and calc ordinal_distance }
               if Assigned(lCurrentParaSym) and
                  not(lCurrentParaSym.VarSpez in [vs_var,vs_out]) and
                  Is_Integer(lFromDef) and
                  Is_Integer(lToDef) and
                  Is_In_Limit(lFromDef,lToDef) then
                 begin
                   lEqualType:=te_equal;
                   { is_in_limit(def_from, def_to) means that def_from.low >= def_to.low and def_from.high <= def_to.high. }
                   lCandidate^.Increment_Ordinal_Distance(TOrdDef(lFromDef).low-TOrdDef(lToDef).low);
                   lCandidate^.Increment_Ordinal_Distance(TOrdDef(lToDef).high-TOrdDef(lFromDef).high);
                   { Give wrong sign a small penalty, this is need to get a difference
                     from word->[longword,longint] }
                   if (Is_Signed(lFromDef)<>Is_Signed(lToDef)) then
                     inc(lCandidate^.OrdinalDistanceSecondary);
                 end
              else
              { for value and const parameters check precision of real, give
                penalty for loosing of precision. var and out parameters must match exactly }
               if Assigned(lCurrentParaSym) and
                  not(lCurrentParaSym.VarSpez in [vs_var,vs_out]) and
                  Is_Real_Or_CExtended(lFromDef) and
                  Is_Real_Or_CExtended(lToDef) then
                 begin
                   lEqualType:=te_equal;
                   lFPPrecisionDistance:=FPPrecisionScore(lToDef)-FPPrecisionScore(lFromDef);
                   { penalty for shrinking of precision }
                   if lFPPrecisionDistance<0 then
                     lFPPrecisionDistance:=16*-lFPPrecisionDistance;
                   lCandidate^.Increment_Ordinal_Distance(lFPPrecisionDistance);
                 end
              else
              { related object parameters also need to determine the distance between the current
                object and the object we are comparing with. var and out parameters must match exactly }
               if Assigned(lCurrentParaSym) and
                  Assigned(lToDef) and
                  not(lCurrentParaSym.VarSpez in [vs_var,vs_out]) and
                  (lFromDef.typ=objectdef) and
                  (lToDef.typ=objectdef) and
                  (TObjectDef(lFromDef).ObjectType=TObjectDef(lToDef).ObjectType) and
                  Def_Is_Related(TObjectDef(lFromDef),TObjectDef(lToDef)) then
                 begin
                   lEqualType:=te_convert_l1;
                   lCheckValidVar:=false;
                   { resolve anonymous external class definitions }
                   lFromObjectDef:=Find_Real_Class_Definition(TObjectDef(lFromDef),false);
                   lToObjectDef:=Find_Real_Class_Definition(TObjectDef(lToDef),false);
                   while Assigned(lFromObjectDef) do
                     begin
                       if lFromObjectDef=lToObjectDef then
                         break;
                       lCandidate^.Increment_Ordinal_Distance(1);
                       lFromObjectDef:=lFromObjectDef.ChildOf;
                     end;
                 end
               { compare_defs_ext compares sets and array constructors very poorly because
                 it has too little information. So we do explicitly a detailed comparison,
                 see also bug #11288 (FK)
               }
               else if Assigned(lToDef) and (lToDef.typ=setdef) and Is_Array_Constructor(lCurrentParaNode.left.resultdef) then
                 begin
                   lNode:=lCurrentParaNode.left.GetCopy;
                   ArrayConstructor_To_Set(lNode);
                   lEqualType:=Compare_Defs_Ext(lNode.resultdef,lToDef,lNode.nodetype,lConversionType,lOperatorProcDef,lCompareDefOptions);
                   lCheckValidVar:=false;
                   lNode.free;
                   lNode := nil;
                 end
              else if Is_Open_Array(lToDef) and
                      Is_Class_Or_Interface_Or_DispInterface_Or_ObjC(TArrayDef(lToDef).ElementDef) and
                      Is_Array_Constructor(lCurrentParaNode.left.resultdef) and
                      Assigned(TArrayConstructorNode(lCurrentParaNode.left).left) then
                begin
                  { ensure that [nil] can be converted to "array of tobject",
                    because if we just try to convert "array of pointer" to
                    "array of tobject", we get type conversion errors in
                    non-Delphi modes }
                  lNode:=lCurrentParaNode.left;
                  lMinEqualType:=te_exact;
                  repeat
                    if TArrayConstructorNode(lNode).left.nodetype=arrayconstructorrangen then
                      lEqualType:=te_incompatible
                    else
                      lEqualType:=Compare_Defs_Ext(TArrayConstructorNode(lNode).left.resultdef,TArrayDef(lToDef).ElementDef,TArrayConstructorNode(lNode).left.nodetype,lConversionType,lOperatorProcDef,lCompareDefOptions);
                    if lEqualType<lMinEqualType then
                      lMinEqualType:=lEqualType;
                    if lEqualType=te_incompatible then
                      break;
                    lNode:=TArrayConstructorNode(lNode).right;
                  until not Assigned(lNode);
                  lEqualType:=lMinEqualType;
                  lCheckValidVar:=false;
                end
              else
              { generic type comparison }
               begin
                 if (lCandidate^.Data.ProcOptions*[po_rtlproc,po_compilerproc]=[]) and
                    Is_AnsiString(lFromDef) and
                    Is_AnsiString(lToDef) and
                    (TStringDef(lFromDef).encoding<>TStringDef(lToDef).encoding) and
                    (lCurrentParaSym.VarSpez in [vs_var,vs_out]) then
                    begin
                      lEqualType:=te_convert_l1; // don't allow to pass different ansistring types to each-other
                      lCheckValidVar:=false;
                    end
                 else
                   lEqualType:=Compare_Defs_Ext(lFromDef,lToDef,lCurrentParaNode.left.nodetype,lConversionType,lOperatorProcDef,lCompareDefOptions);

                 { when the types are not equal we need to check
                   some special case for parameter passing }
                 if (lEqualType<te_equal) then
                  begin
                    if lCurrentParaSym.VarSpez in [vs_var,vs_out] then
                      begin
                        { para requires an equal type so the previous found
                          match was not good enough, reset to incompatible }
                        lEqualType:=te_incompatible;
                        VarParaAllowed(lEqualType,lCurrentParaNode.resultdef,lCurrentParaSym.vardef,lCurrentParaNode.left);
                        lCheckValidVar:=false;
                      end
                    else
                      ParaAllowed(lEqualType,lCurrentParaNode,lToDef);
                  end;
               end;

              { univ parameters match if the size matches (don't override the
                comparison result if it was ok, since a match based on the
                "univ" character is the lowest possible match) }
                if (lEqualType=te_incompatible) and
                   lCurrentParaSym.UnivPara and
                   Is_Valid_Univ_Para_Type(lFromDef) and
                   (lFromDef.Size=lToDef.Size) then
                  lEqualType:=te_convert_l5;

               { when a procvar was changed to a call an exact match is
                downgraded to equal. This way an overload call with the
                procvar is choosen. See tb_procvar_calls_delphi, case tb0471 (PFV) }
              if (lParaNode<>lCurrentParaNode) and (lEqualType=te_exact) then
                lEqualType:=te_equal;
              { if var or out parameter type but paranode not is_valid_for_var }
              if lCheckValidVar and Assigned(lCurrentParaSym) and (lCurrentParaSym.VarSpez in [vs_var,vs_out]) and not Valid_For_Var(lCurrentParaNode.left,false)
                 and Assigned(lToDef) and (lToDef.typ<>formaldef) and not Is_Open_Array(lToDef) then
                lEqualType:=te_incompatible;

              { increase correct counter }
              if lEqualType<>te_incompatible then
                inc(lCandidate^.TECount[lEqualType])
              else
                lCandidate^.Invalid:=true;

              { stop checking when an incompatible parameter is found }
              if lCandidate^.Invalid then
               begin
                 { store the current parameter info for
                   a nice error message when no procedure is found }
                 lCandidate^.WrongParaIdx:=lParaIndex;
                 lCandidate^.WrongParaNr:=lCurrentParaNr;
                 break;
               end;

{$ifdef EXTDEBUG}
              { store equal in node tree for dump }
              if Assigned(lCurrentParaSym) then
                lCurrentParaSym.EqVal:=lEqualType;
{$endif EXTDEBUG}

              { maybe release temp currpt }
              if lReleaseCurrentParaNode then
               begin
                 lCurrentParaNode.free;
                 lCurrentParaNode := nil;
               end;

              { next parameter in the call tree }
              lParaNode:=TCallParaNode(lParaNode.right);

              { next parameter for definition, only goto next para
                if we're out of the varargs }
              if not(po_varargs in lCandidate^.Data.ProcOptions) or
                 (lCurrentParaNr<=lCandidate^.Data.MaxParaCount) then
               begin
                 { Ignore vs_hidden parameters }
                 repeat
                   dec(lParaIndex);
                 until (lParaIndex<0) or not(vo_is_hidden_para in TParaVarSym(lCandidate^.Data.paras[lParaIndex]).VarOptions);
               end;
              dec(lCurrentParaNr);
            end;
           if not(lCandidate^.Invalid) and
              (Assigned(lParaNode) or (lParaIndex>=0) or (lCurrentParaNr<>0)) then
             InternalError(200212141);
           { next candidate }
           lCandidate:=lCandidate^.Next;
         end;
      end;


    function GetVariantEqualType(ADef: TDef): TVariantEqualType;
      const
        cVariantOrdDefClasses: array[TOrdType] of TVariantEqualType =
          (tve_incompatible,tve_byte,tve_word,tve_cardinal,tve_chari64,tve_incompatible,
           tve_shortint,tve_smallint,tve_longint,tve_chari64,tve_incompatible,
           tve_boolformal,tve_boolformal,tve_boolformal,tve_boolformal,tve_boolformal,
           tve_boolformal,tve_boolformal,tve_boolformal,tve_boolformal,
           tve_chari64,tve_chari64,tve_dblcurrency,tve_incompatible);
        cVariantFloatDefClasses: array[TFloatType] of TVariantEqualType =
          (tve_single,tve_dblcurrency,tve_extended,tve_extended,
           tve_dblcurrency,tve_dblcurrency);
        cVariantStringDefClasses: array[TStringType] of TVariantEqualType =
          (tve_sstring,tve_astring,tve_astring,tve_wstring,tve_ustring);
      begin
        case ADef.typ of
          orddef:
            begin
              Result:=cVariantOrdDefClasses[TOrdDef(ADef).OrdType];
            end;
          floatdef:
            begin
              Result:=cVariantFloatDefClasses[TFloatDef(ADef).FloatType];
            end;
          stringdef:
            begin
              Result:=cVariantStringDefClasses[TStringDef(ADef).StringType];
            end;
          formaldef:
            begin
              Result:=tve_boolformal;
            end;
          else
            begin
              Result:=tve_incompatible;
            end;
        end
      end;




    function IsBetterCandidate(ACurrentCandidate,ABestCandidate:PCandidate):Integer;
      begin
        {
          Return values:
            > 0 when currpd is better than bestpd
            < 0 when bestpd is better than currpd
            = 0 when both are equal

          To choose the best candidate we use the following order:
          - Incompatible flag
          - (Smaller) Number of convert operator parameters.
          - (Smaller) Number of convertlevel 2 parameters.
          - (Smaller) Number of convertlevel 1 parameters.
          - (Bigger) Number of exact parameters.
          - (Smaller) Number of equal parameters.
          - (Smaller) Total of ordinal distance. For example, the distance of a word
            to a byte is 65535-255=65280.
        }
        if ABestCandidate^.Invalid or ACurrentCandidate^.Invalid then
          exit(ord(ABestCandidate^.Invalid)-ord(ACurrentCandidate^.Invalid)); { 1 if bestpd^.invalid, -1 if currpd^.invalid, 0 if both. }
        { less operator parameters? }
        IsBetterCandidate:=(ABestCandidate^.TECount[te_convert_operator]-ACurrentCandidate^.TECount[te_convert_operator]);
        if IsBetterCandidate<>0 then
          exit;
        { less cl6 parameters? }
        IsBetterCandidate:=ABestCandidate^.TECount[te_convert_l6]-ACurrentCandidate^.TECount[te_convert_l6];
        if IsBetterCandidate<>0 then
          exit;
        { less cl5 parameters? }
        IsBetterCandidate:=ABestCandidate^.TECount[te_convert_l5]-ACurrentCandidate^.TECount[te_convert_l5];
        if IsBetterCandidate<>0 then
          exit;
        { less cl4 parameters? }
        IsBetterCandidate:=ABestCandidate^.TECount[te_convert_l4]-ACurrentCandidate^.TECount[te_convert_l4];
        if IsBetterCandidate<>0 then
          exit;
        { less cl3 parameters? }
        IsBetterCandidate:=ABestCandidate^.TECount[te_convert_l3]-ACurrentCandidate^.TECount[te_convert_l3];
        if IsBetterCandidate<>0 then
          exit;
        { less cl2 parameters? }
        IsBetterCandidate:=ABestCandidate^.TECount[te_convert_l2]-ACurrentCandidate^.TECount[te_convert_l2];
        if IsBetterCandidate<>0 then
          exit;
        { less cl1 parameters? }
        IsBetterCandidate:=ABestCandidate^.TECount[te_convert_l1]-ACurrentCandidate^.TECount[te_convert_l1];
        if IsBetterCandidate<>0 then
          exit;
        { more exact parameters? }
        IsBetterCandidate:=ACurrentCandidate^.TECount[te_exact]-ABestCandidate^.TECount[te_exact];
        if IsBetterCandidate<>0 then
          exit;
        { less equal parameters? }
        IsBetterCandidate:=ABestCandidate^.TECount[te_equal]-ACurrentCandidate^.TECount[te_equal];
        if IsBetterCandidate<>0 then
          exit;
        { if a specialization is better than a non-specialization then
          the non-generic always wins }
        if m_implicit_function_specialization in CurrentSettings.ModeSwitches then
          begin
            IsBetterCandidate:=ord(ABestCandidate^.Data.Is_Specialization)-ord(ACurrentCandidate^.Data.Is_Specialization); { 1 if bestpd^.data.is_specialization and not currpd^.data.is_specialization, -1 if the reverse, 0 if same is_specialization. }
            if IsBetterCandidate<>0 then
              exit;
          end;
        { smaller ordinal distance? }
        IsBetterCandidate:=int32(ABestCandidate^.OrdinalDistanceHi)-int32(ACurrentCandidate^.OrdinalDistanceHi); { >0 if currpd^.ordinal_distance_hi < bestpd^.ordinal_distance_hi. }
        if IsBetterCandidate<>0 then
          exit;
        if ACurrentCandidate^.OrdinalDistanceLo<>ABestCandidate^.OrdinalDistanceLo then
          exit(2*ord(ACurrentCandidate^.OrdinalDistanceLo<ABestCandidate^.OrdinalDistanceLo)-1); { 1 if currpd^.ordinal_distance_lo < bestpd^.ordinal_distance_lo, -1 if the reverse. }
        IsBetterCandidate:=int32(ABestCandidate^.OrdinalDistanceSecondary)-int32(ACurrentCandidate^.OrdinalDistanceSecondary); { >0 if currpd^.ordinal_distance_secondary < bestpd^.ordinal_distance_secondary. }
      end;


{ Delphi precedence rules extracted from test programs. Only valid if passing
  a variant parameter to overloaded procedures expecting exactly one parameter.

  single > (char, currency, int64, shortstring, ansistring, widestring, unicodestring, extended, double)
  double/currency > (char, int64, shortstring, ansistring, widestring, unicodestring, extended)
  extended > (char, int64, shortstring, ansistring, widestring, unicodestring)
  longint/cardinal > (int64, shortstring, ansistring, widestring, unicodestring, extended, double, single, char, currency)
  smallint > (longint, int64, shortstring, ansistring, widestring, unicodestring, extended, double single, char, currency);
  word > (longint, cardinal, int64, shortstring, ansistring, widestring, unicodestring, extended, double single, char, currency);
  shortint > (longint, smallint, int64, shortstring, ansistring, widestring, unicodestring, extended, double, single, char, currency)
  byte > (longint, cardinal, word, smallint, int64, shortstring, ansistring, widestring, unicodestring, extended, double, single, char, currency);
  boolean/formal > (char, int64, shortstring, ansistring, widestring, unicodestring)
  widestring > (char, int64, shortstring, ansistring, unicodestring)
  unicodestring > (char, int64, shortstring, ansistring)
  ansistring > (char, int64, shortstring)
  shortstring > (char, int64)

  Relations not mentioned mean that they conflict: no decision possible }

    function IsBetterCandidateSingleVariant(ACurrentCandidate,ABestCandidate:PCandidate):Integer;

      function CalculateRelation(const ACurrentVariantClass, ABestVariantClass, ATestVariantClass:
          TVariantEqualType; const AConflictingVariantClasses: TVariantEqualTypes):Integer;
        begin
          { if (bestvcl=conflictvcl) or
               (currvcl=conflictvcl) then
              result:=0
            else if (bestvcl=testvcl) then
              result:=-1
            else result:=1 }
          Result:=1-2*ord(ABestVariantClass=ATestVariantClass)+
                  ord(ACurrentVariantClass in AConflictingVariantClasses)-ord(ABestVariantClass in AConflictingVariantClasses);
        end;


        function GetFirstRealParaIdx(ACandidate: PCandidate): Integer;
          begin
            { can be different for currpd and bestpd in case of overloaded }
            { functions, e.g. lowercase():char and lowercase():shortstring }
            { (depending on the calling convention and parameter order)    }
            Result:=ACandidate^.FirstParaIdx;
            while (Result>=0) and (vo_is_hidden_para in TParaVarSym(ACandidate^.Data.paras[Result]).VarOptions) do
              dec(Result);
            if (vo_is_hidden_para in TParaVarSym(ACandidate^.Data.paras[Result]).VarOptions) then
              InternalError(2006122803);
          end;

      var
        lCurrentParaSym, lBestParaSym: TParaVarSym;
        lCurrentVariantClass, lBestVariantClass: TVariantEqualType;
      begin
        {
          Return values:
            > 0 when currpd is better than bestpd
            < 0 when bestpd is better than currpd
            = 0 when both are equal
        }
        lCurrentParaSym:=TParaVarSym(ACurrentCandidate^.Data.paras[GetFirstRealParaIdx(ACurrentCandidate)]);
        lBestParaSym:=TParaVarSym(ABestCandidate^.Data.paras[GetFirstRealParaIdx(ABestCandidate)]);

        { if one of the parameters is a regular variant, fall back to the }
        { default algorithm                                               }
        if (lCurrentParaSym.vardef.typ = variantdef) or
           (lBestParaSym.vardef.typ = variantdef) then
          begin
            Result:=IsBetterCandidate(ACurrentCandidate,ABestCandidate);
            exit;
          end;

        lCurrentVariantClass:=GetVariantEqualType(lCurrentParaSym.vardef);
        lBestVariantClass:=GetVariantEqualType(lBestParaSym.vardef);

        { sanity check }
        Result:=-5;

        { if both are the same, there is a conflict }
        if (lCurrentVariantClass=lBestVariantClass) then
          Result:=0
        { if one of the two cannot be used as variant, the other is better }
        else if (lBestVariantClass=tve_incompatible) then
          Result:=1
        else if (lCurrentVariantClass=tve_incompatible) then
          Result:=-1
        { boolean and formal are better than chari64str, but conflict with }
        { everything else                                                  }
        else if (lCurrentVariantClass=tve_boolformal) or
                (lBestVariantClass=tve_boolformal) then
          if (lCurrentVariantClass=tve_boolformal) then
            Result:=ord(lBestVariantClass in [tve_chari64,tve_sstring,tve_astring,tve_wstring,tve_ustring])
          else
            Result:=-ord(lCurrentVariantClass in [tve_chari64,tve_sstring,tve_astring,tve_wstring,tve_ustring])
        { byte is better than everything else (we assume both aren't byte, }
        { since there's only one parameter and that one can't be the same) }
        else if (lCurrentVariantClass=tve_byte) or
                (lBestVariantClass=tve_byte) then
          Result:=CalculateRelation(lCurrentVariantClass,lBestVariantClass,tve_byte,[tve_shortint])
        { shortint conflicts with word and cardinal, but is better than    }
        { everything else but byte (which has already been handled)        }
        else if (lCurrentVariantClass=tve_shortint) or
                (lBestVariantClass=tve_shortint) then
          Result:=CalculateRelation(lCurrentVariantClass,lBestVariantClass,tve_shortint,[tve_word, tve_cardinal])
        { word conflicts with smallint, but is better than everything else }
        { but shortint and byte (which has already been handled)           }
        else if (lCurrentVariantClass=tve_word) or
                (lBestVariantClass=tve_word) then
          Result:=CalculateRelation(lCurrentVariantClass,lBestVariantClass,tve_word,[tve_smallint])
        { smallint conflicts with cardinal, but is better than everything  }
        { which has not yet been tested                                    }
        else if (lCurrentVariantClass=tve_smallint) or
                (lBestVariantClass=tve_smallint) then
          Result:=CalculateRelation(lCurrentVariantClass,lBestVariantClass,tve_smallint,[tve_cardinal])
        { cardinal conflicts with each longint and is better than everything }
        { which has not yet been tested                                      }
        else if (lCurrentVariantClass=tve_cardinal) or
                (lBestVariantClass=tve_cardinal) then
          Result:=CalculateRelation(lCurrentVariantClass,lBestVariantClass,tve_cardinal,[tve_longint])
        { longint is better than everything which has not yet been tested }
        else if (lCurrentVariantClass=tve_longint) or
                (lBestVariantClass=tve_longint) then
          { if bestvcl=tve_longint then
              result:=-1
            else
              result:=1 }
          Result:=1-2*ord(lBestVariantClass=tve_longint)
        { single is better than everything left }
        else if (lCurrentVariantClass=tve_single) or
                (lBestVariantClass=tve_single) then
          Result:=1-2*ord(lBestVariantClass=tve_single)
        { double/comp/currency are better than everything left, and conflict }
        { with each other (but that's already tested)                        }
        else if (lCurrentVariantClass=tve_dblcurrency) or
                (lBestVariantClass=tve_dblcurrency) then
          Result:=1-2*ord(lBestVariantClass=tve_dblcurrency)
        { extended is better than everything left }
        else if (lCurrentVariantClass=tve_extended) or
                (lBestVariantClass=tve_extended) then
          Result:=1-2*ord(lBestVariantClass=tve_extended)
        { widestring is better than everything left }
        else if (lCurrentVariantClass=tve_wstring) or
                (lBestVariantClass=tve_wstring) then
          Result:=1-2*ord(lBestVariantClass=tve_wstring)
        { unicodestring is better than everything left }
        else if (lCurrentVariantClass=tve_ustring) or
                (lBestVariantClass=tve_ustring) then
          Result:=1-2*ord(lBestVariantClass=tve_ustring)
        { ansistring is better than everything left }
        else if (lCurrentVariantClass=tve_astring) or
                (lBestVariantClass=tve_astring) then
          Result:=1-2*ord(lBestVariantClass=tve_astring)
        { shortstring is better than everything left }
        else if (lCurrentVariantClass=tve_sstring) or
                (lBestVariantClass=tve_sstring) then
          Result:=1-2*ord(lBestVariantClass=tve_sstring);

        { all possibilities should have been checked now }
        if (Result=-5) then
          InternalError(2006122805);
      end;



{$ifdef DISABLE_FAST_OVERLOAD_PATCH}

    function TCallCandidates.Choose_Best(var ABestProcDef:TAbstractProcDef; ASingleVariant: Boolean):Integer;
      var
        lProcDef: TProcDef;
        lBestCandidateStart,
        lCandidate            : PCandidate;
        lProcDefCount,
        lResult           : Integer;
      begin
        {
          Returns the number of candidates left and the
          first candidate is returned in pdbest
        }
        { Setup the first procdef as best, only count it as a result
          when it is valid }
        ABestProcDef:=FCandidateProcs^.Data;
        if FCandidateProcs^.Invalid then
         lProcDefCount:=0
        else
         lProcDefCount:=1;
        if Assigned(FCandidateProcs^.Next) then
         begin
           lBestCandidateStart:=FCandidateProcs;
           lCandidate:=FCandidateProcs^.Next;
           while Assigned(lCandidate) do
            begin
              if not ASingleVariant then
                lResult:=IsBetterCandidate(lCandidate,lBestCandidateStart)
              else
                lResult:=IsBetterCandidateSingleVariant(lCandidate,lBestCandidateStart);
              if (lResult>0) then
               begin
                 { hp is better, flag all procs to be incompatible }
                 while (lBestCandidateStart<>lCandidate) do
                  begin
                    lBestCandidateStart^.Invalid:=true;
                    lBestCandidateStart:=lBestCandidateStart^.Next;
                  end;
                 { besthpstart is already set to hp }
                 ABestProcDef:=lBestCandidateStart^.Data;
                 lProcDefCount:=1;
               end
              else
               if (lResult<0) then
                begin
                  { besthpstart is better, flag current hp to be incompatible }
                  lCandidate^.Invalid:=true;
                end
              else
               begin
                 { res=0, both are valid }
                 if not lCandidate^.Invalid then
                   inc(lProcDefCount);
               end;
              lCandidate:=lCandidate^.Next;
            end;
         end;

        Result:=lProcDefCount;
      end;


{$else}

    function CompareByOldSortOutCheck(ACandidate,ABestCandidate:PCandidate):Integer;
      var lCompareParaOptions : TCompareParasOptions;
      begin
        { don't add duplicates, only compare visible parameters for the user }
        lCompareParaOptions:=[cpo_ignorehidden];
        if (po_compilerproc in ABestCandidate^.Data.ProcOptions) then
          lCompareParaOptions:=lCompareParaOptions+[cpo_compilerproc];
        if (po_rtlproc in ABestCandidate^.Data.ProcOptions) then
          lCompareParaOptions:=lCompareParaOptions+[cpo_rtlproc];

        CompareByOldSortOutCheck := 0; // can't decide, bestpd probably wasn't sorted out in unpatched
        if (Compare_Paras(ACandidate^.Data.paras,ABestCandidate^.Data.paras,cp_value_equal_const,lCompareParaOptions)>=te_equal) and
          (not(po_objc in ABestCandidate^.Data.ProcOptions) or (ABestCandidate^.Data.MessageInf.str^=ACandidate^.Data.MessageInf.str^)) then
          CompareByOldSortOutCheck := 1; // bestpd was sorted out before patch

        { for implicit specializations non-generics should take precedence so
          when comparing a specialization to a non-specialization mark as undecided
          and it will be re-evaluated in is_better_candidate }
        if (m_implicit_function_specialization in CurrentSettings.ModeSwitches)
          and (ACandidate^.Data.Is_Specialization <> ABestCandidate^.Data.Is_Specialization) then
          CompareByOldSortOutCheck:=0;
     end;

    function DecideRestart(ACandidate,ABestCandidate:PCandidate) : Boolean;
      begin
        DecideRestart := false;
        if Assigned(ABestCandidate) then
          begin
            { don't restart if bestpd is marked invalid already }
            if not ABestCandidate^.Invalid then
              DecideRestart := CompareByOldSortOutCheck(ACandidate,ABestCandidate)<>0;
        end;
      end;


    procedure SaveValidity(ACandidate : PCandidate);
      begin
        while Assigned(ACandidate) do
          begin
            ACandidate^.SavedValidity := ACandidate^.Invalid;
            ACandidate := ACandidate^.Next;
          end;
      end;


    procedure RestoreValidity(ACandidate : PCandidate);
      begin
        while Assigned(ACandidate) do begin
          ACandidate^.Invalid := ACandidate^.SavedValidity;
          ACandidate := ACandidate^.Next;
        end;
      end;


    function TCallCandidates.Choose_Best(var ABestProcDef:TAbstractProcDef; ASingleVariant: Boolean):Integer;
      var
        lProcDef: TProcDef;
        lBestCandidateStart,
        lCandidate,lCandidate2        : PCandidate;
        lProcDefCount,
        lResult           : Integer;
        lRestart : Boolean;
      begin
        lResult:=0;
        {
          Returns the number of candidates left and the
          first candidate is returned in pdbest
        }
       if not(Assigned(FCandidateProcs)) then
         begin
           Choose_Best := 0;
           exit;
         end;

        ABestProcDef:=FCandidateProcs^.Data;
        if FCandidateProcs^.Invalid then
          lProcDefCount:=0
        else
          lProcDefCount:=1;

        if Assigned(FCandidateProcs^.Next) then
         begin
           SaveValidity(FCandidateProcs);
           lRestart := false;
           { keep restarting, until there wasn't a sorted-out besthpstart }
           repeat
             lBestCandidateStart:=FCandidateProcs;
             ABestProcDef:=FCandidateProcs^.Data;
             if lRestart then
               begin
                 RestoreValidity(FCandidateProcs);
                 lRestart := false;
               end;
             { Setup the first procdef as best, only count it as a result
               when it is valid }
             if lBestCandidateStart^.Invalid then
               lProcDefCount:=0
             else
               lProcDefCount:=1;
             lCandidate:=FCandidateProcs^.Next;
             while Assigned(lCandidate) and not(lRestart) do
               begin
                 lRestart := DecideRestart(lCandidate,lBestCandidateStart);
                 if not lRestart then
                   begin
                   if lBestCandidateStart^.Invalid then lResult := 1
                   else if lCandidate^.Invalid then lResult := -1
                   else if not ASingleVariant then
                     lResult:=IsBetterCandidate(lCandidate,lBestCandidateStart)
                   else
                     lResult:=IsBetterCandidateSingleVariant(lCandidate,lBestCandidateStart);
                 end;
                 if lRestart then
                   begin
                     { mark the sorted out invalid globally }
                     lBestCandidateStart^.SavedValidity := true;
                   end
                 else if (lResult>0) then
                   begin
                     { hp is better, flag all procs to be incompatible }
                     while (lBestCandidateStart<>lCandidate) do
                       begin
                         lBestCandidateStart^.Invalid:=true;
                         lBestCandidateStart:=lBestCandidateStart^.Next;
                       end;
                     { besthpstart is already set to hp }
                     ABestProcDef:=lBestCandidateStart^.Data;
                     if lBestCandidateStart^.Invalid then
                       lProcDefCount:=0
                     else
                       lProcDefCount:=1;
                   end
                 else if (lResult<0) then
                   begin
                    { besthpstart is better, flag current hp to be incompatible }
                    lCandidate^.Invalid:=true;
                   end
                 else
                   begin
                     { res=0, both are valid }
                     if not lCandidate^.Invalid then
                       inc(lProcDefCount);
                   end;
                 lCandidate:=lCandidate^.Next;
               end;
           until not(lRestart);
         end;

        { check the alternate choices if they would have been sorted out before patch... }

        { note we have procadded the candidates, so order is reversed procadd order here.
          this was also used above: each sorted-out always has an "outsorter" counterpart
          deeper down the next chain
        }

        { for the initial implementation, let's first do some more consistency checking}
        lResult := 0;
        lCandidate := FCandidateProcs;
        while Assigned(lCandidate) do
          begin
            if not(lCandidate^.Invalid) then
              inc(lResult);
            lCandidate := lCandidate^.Next;
          end;
        if (lResult<>lProcDefCount) then
          InternalError(202002161);

        { check all valid choices for sortout }
        lProcDefCount := 0;
        lCandidate := FCandidateProcs;
        while Assigned(lCandidate) do
          begin
            if not(lCandidate^.Invalid) then
              begin
                lCandidate2 := lCandidate^.Next;
                while Assigned(lCandidate2) do begin
                  if CompareByOldSortOutCheck(lCandidate2,lCandidate)<>0 then
                    begin
                      lCandidate^.Invalid := true;
                      lCandidate2 := nil;
                    end
                  else
                    lCandidate2:=lCandidate2^.Next;
                end;
                if not(lCandidate^.Invalid) then
                  begin
                    inc(lProcDefCount);
                    { check for the impossible event bestpd had become invalid}
                    if (lProcDefCount=1) and (lCandidate^.Data<>ABestProcDef) then
                      InternalError(202002162);
                  end;
              end;
            lCandidate := lCandidate^.Next;
          end;


        Result:=lProcDefCount;
      end;

{$endif}





    procedure TCallCandidates.Find_Wrong_Para;
      var
        lCurrentParaNr : smallint;
        lCandidate : PCandidate;
        lParaNode : TCallParaNode;
        lWrongPara : TParaVarSym;
      begin
        { Only process the first overloaded procdef }
        lCandidate:=FCandidateProcs;
        { Find callparanode corresponding to the argument }
        lParaNode:=TCallParaNode(FParanode);
        lCurrentParaNr:=FParalength;
        while Assigned(lParaNode) and
              (lCurrentParaNr>lCandidate^.WrongParaNr) do
         begin
           lParaNode:=TCallParaNode(lParaNode.right);
           dec(lCurrentParaNr);
         end;
        if (lCurrentParaNr<>lCandidate^.WrongParaNr) or
           not Assigned(lParaNode) then
          InternalError(200212094);
        { Show error message, when it was a var or out parameter
          guess that it is a missing typeconv }
        lWrongPara:=TParaVarSym(lCandidate^.Data.paras[lCandidate^.WrongParaIdx]);
        if lWrongPara.VarSpez in [vs_var,vs_out] then
          begin
            { Maybe passing the correct type but passing a const to var parameter }
            if (Compare_Defs(lParaNode.resultdef,lWrongPara.vardef,lParaNode.nodetype)<>te_incompatible) and
               not Valid_For_Var(lParaNode.left,true) then
              CGMessagePos(lParaNode.left.fileinfo,type_e_variable_id_expected)
            else
              CGMessagePos3(lParaNode.left.fileinfo,parser_e_call_by_ref_without_typeconv,ToStr(lCandidate^.WrongParaNr),
                FullTypeName(lParaNode.left.resultdef,lWrongPara.vardef),
                FullTypeName(lWrongPara.vardef,lParaNode.left.resultdef))
          end
        else
          begin
            CGMessagePos3(lParaNode.left.fileinfo,type_e_wrong_parameter_type,ToStr(lCandidate^.WrongParaNr),
              FullTypeName(lParaNode.left.resultdef,lWrongPara.vardef),
              FullTypeName(lWrongPara.vardef,lParaNode.left.resultdef));
          end;
      end;


    procedure Check_Ranges(const ALocation: TFilePosInfo; ASource: TNode; ADestDef: TDef);
      begin
        if not(cs_check_ordinal_size in CurrentSettings.LocalSwitches) then
          exit;
        { check if the assignment may cause a range check error }
        { if its not explicit, and only if the values are       }
        { ordinals, enumdef and floatdef                        }
        if Assigned(ADestDef) and
          (ADestDef.typ in [enumdef,orddef,floatdef]) and
          not Is_Boolean(ADestDef) and
          Assigned(ASource.resultdef) and
          (ASource.resultdef.typ in [enumdef,orddef,floatdef]) and
          not Is_Boolean(ASource.resultdef) and
          not Is_ConstRealNode(ASource) and
          { constants are handled via regular range checking }
          (ASource.nodetype<>ordconstn) then
         begin
           if ((ADestDef.Size < ASource.resultdef.Size) and
               { s80real and sc80real have a different size but the same precision }
               not((ADestDef.typ=floatdef) and
                   (ASource.resultdef.typ=floatdef) and
                   (TFloatDef(ASource.resultdef).FloatType in [s80real,sc80real]) and
                   (TFloatDef(ADestDef).FloatType in [s80real,sc80real]))) or
              ((ADestDef.typ<>floatdef) and
               (ASource.resultdef.typ<>floatdef) and
               not Is_In_Limit(ASource.resultdef,ADestDef)) then
             begin
               if (cs_check_range in CurrentSettings.LocalSwitches) then
                 MessagePos(ALocation,type_w_smaller_possible_range_check)
               else
                 MessagePos(ALocation,type_h_smaller_possible_range_check);
             end;
         end;
      end;

    function Is_Valid_For_Default(ADef:TDef):Boolean;

      function IsValidRecordOrObject(ADef:TAbstractRecordDef):Boolean;
        var
          lSym : TSym;
          lIndex : LongInt;
        begin
          for lIndex:=0 to ADef.SymTable.SymList.count-1 do
            begin
              lSym:=TSym(ADef.SymTable.SymList[lIndex]);
              if not Is_Normal_FieldVarSym(lSym) then
                continue;
              if not Is_Valid_For_Default(TFieldVarSym(lSym).vardef) then
                begin
                  Result:=false;
                  exit;
                end;
            end;
          Result:=true;
        end;

      begin
        case ADef.typ of
          recorddef:
            Result:=IsValidRecordOrObject(TAbstractRecordDef(ADef));
          objectdef:
            if Is_Implicit_Pointer_Object_Type(ADef) then
              Result:=true
            else
              if Is_Object(ADef) then
                Result:=IsValidRecordOrObject(TAbstractRecordDef(ADef))
              else
                Result:=false;
          arraydef:
            if not (ado_isdynamicarray in TArrayDef(ADef).ArrayOptions) then
              Result:=Is_Valid_For_Default(TArrayDef(ADef).ElementDef)
            else
              Result:=true;
          formaldef,
          abstractdef,
          filedef:
            Result:=false;
          else
            Result:=true;
        end;
      end;


end.
