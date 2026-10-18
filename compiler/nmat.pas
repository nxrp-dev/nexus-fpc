{
    Copyright (c) 2000-2005 by Florian Klaempfl

    Type checking and register allocation for math nodes

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
unit nmat;

{$i fpcdefs.inc}

interface

    uses
       TPCompilerReal,
       node,symtype;

    type
       TModDivNodeFlag = (
         mdnf_isomod
       );

       TModDivNodeFlags = set of TModDivNodeFlag;

       TModDivNode = class(TBinOpNode)
          ModDivNodeFlags : TModDivNodeFlags;
          constructor Create(ANodeType:TNodeType;ALeft,ARight : TNode); override;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Simplify(AForInline : Boolean) : TNode;override;
          function DoGetCopy : TNode;override;
         protected
          { override the following if you want to implement }
          { parts explicitely in the code generator (JM)    }
          function Use_ModDiv64BitInt_Helper: Boolean; virtual;
          function First_ModDiv64BitInt: TNode; virtual;
          function FirstOptimize: TNode; virtual;
          function First_ModDivInt: TNode; virtual;
       end;
       TModDivNodeClass = class of TModDivNode;

       TShlShrNode = class(TBinOpNode)
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Simplify(AForInline : Boolean) : TNode;override;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
          { override the following if you want to implement }
          { parts explicitely in the code generator (CEC)
            Should return nil, if everything will be handled
            in the code generator
          }
          function First_ShlShr64BitInt: TNode; virtual;
{$endif not cpu64bitalu and not cpuhighleveltarget}
       end;
       TShlShrNodeClass = class of TShlShrNode;

       TUnaryMinusNode = class(TUnaryNode)
          constructor Create(AExpr : TNode);virtual;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Simplify(AForInline : Boolean) : TNode;override;
       end;
       TUnaryMinusNodeClass = class of TUnaryMinusNode;

       TUnaryPlusNode = class(TUnaryNode)
         constructor Create(AExpr : TNode);virtual;
         function Pass_1 : TNode;override;
         function Pass_TypeCheck:TNode;override;
       end;
       TUnaryPlusNodeClass = class of TUnaryPlusNode;

       TNotNode = class(TUnaryNode)
          constructor Create(AExpr : TNode);virtual;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Simplify(AForInline : Boolean) : TNode;override;
       end;
       TNotNodeClass = class of TNotNode;

    var
       CModDivNode : TModDivNodeClass = TModDivNode;
       CShlShrNode : TShlShrNodeClass = TShlShrNode;
       CUnaryMinusNode : TUnaryMinusNodeClass = TUnaryMinusNode;
       CUnaryPlusNode : TUnaryPlusNodeClass = TUnaryPlusNode;
       CNotNode : TNotNodeClass = TNotNode;

implementation

    uses
      Systems,
      Verbose,Globals,CUtils,compinnr,
      GlobType,ConstExp,
      symconst,symdef,symcpu,
      defcmp,defutil,
      htypechk,Pass_1,
      cgbase,
      ncon,ncnv,ncal,nadd,nld,nbas,nflw,ninl,
      nutils,PPU;

{****************************************************************************
                              TMODDIVNODE
 ****************************************************************************}


    constructor TModDivNode.Create(ANodeType:TNodeType;ALeft,ARight : TNode);
      begin
        inherited Create(ANodeType, ALeft, ARight);
        ModDivNodeFlags:=[];
      end;


    constructor TModDivNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType, APPUFile);
        APPUFile.GetSet(TPPUSet1(ModDivNodeFlags));
      end;


    procedure TModDivNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutSet(TPPUSet1(ModDivNodeFlags));
      end;


    function TModDivNode.Simplify(AForInline : Boolean):TNode;
      var
        lRightValue,lLeftValue : TConstExprInt;
        lTempNode: TNode;
      begin
        Result:=nil;

        if Is_ConstIntNode(Right) then
          begin
            lRightValue:=TOrdConstNode(Right).Value;
            if lRightValue = 1 then
              begin
                case NodeType of
                  modn:
                    Result := COrdConstNode.Create(0,Left.ResultDef,true);
                  divn:
                    Result := Left.GetCopy;
                  else
                    InternalError(2019050518);
                end;
                exit;
              end;
            if lRightValue = 0 then
              begin
                { if the node is derived from a generic const parameter
                  then don't issue an error }
                if not (nf_generic_para in Flags) then
                  Message(parser_e_division_by_zero);
                { recover }
                TOrdConstNode(Right).Value := 1;
              end;
            { the following simplification is also required for correctness
              on x86, as its transformation of divisions by constants to
              multiplications and shifts does not handle -1 correctly }
            if (lRightValue=-1) and
               (NodeType=divn) then
              begin
                Result:=CUnaryMinusNode.Create(Left);
                Left:=nil;
                exit;
              end;
            if (mdnf_isomod in ModDivNodeFlags) and
              (lRightValue<=0) then
               begin
                 Message(cg_e_mod_only_defined_for_pos_quotient);
                 { recover }
                 TOrdConstNode(Right).Value := 1;
               end
            else if (lRightValue=-1) and
              (NodeType=modn) then
              begin
                Result:=COrdConstNode.Create(0,Left.ResultDef,true);
                Left:=nil;
                exit;
              end;
            if (NodeType=divn) and (Left.NodeType=divn) and Is_ConstIntNode(TModDivNode(Left).Right) and
              { we need a type and the types must be consistent }
              Assigned(ResultDef) and
              (Compare_Defs(ResultDef,Left.ResultDef,nothingn)=te_exact) then
              begin
                { re-use the current node so we get the result type right }
                Right:=CAddNode.Create_Internal(muln,Right,TModDivNode(Left).Right.GetCopy);
                lTempNode:=TModDivNode(Left).Left.GetCopy;
                Left.Free;
                Left:=lTempNode;
                Result:=GetCopy;
                Result.ResultDef:=nil;
                Result:=CTypeConvNode.Create_Internal(Result,ResultDef);
                exit;
              end;

            { pointer subtractions generate nodes dividing pointer (constants) }
            if Is_ConstIntNode(Left) or Is_ConstPointerNode(Left) then
              begin
                { load values }
                lLeftValue:=Get_Int_Value(Left);
                lRightValue:=Get_Int_Value(Right);

                case NodeType of
                  modn:
                    if mdnf_isomod in ModDivNodeFlags then
                      begin
                        if lLeftValue>=0 then
                          Result:=Create_Simplified_Ord_Const(lLeftValue mod lRightValue,ResultDef,AForInline,false)
                        else
                          if ((-lLeftValue) mod lRightValue)=0 then
                            Result:=Create_Simplified_Ord_Const((-lLeftValue) mod lRightValue,ResultDef,AForInline,false)
                          else
                            Result:=Create_Simplified_Ord_Const(lRightValue-((-lLeftValue) mod lRightValue),ResultDef,AForInline,false);
                      end
                    else
                      Result:=Create_Simplified_Ord_Const(lLeftValue mod lRightValue,ResultDef,AForInline,false);
                  divn:
                    Result:=Create_Simplified_Ord_Const(lLeftValue div lRightValue,ResultDef,AForInline,cs_check_overflow in LocalSwitches);
                  else
                    InternalError(2019050519);
                end;
             end;
          end;
      end;


    function TModDivNode.DoGetCopy: TNode;
      var
        lCopy: TModDivNode;
      begin
        lCopy:=TModDivNode(inherited DoGetCopy);
        lCopy.ModDivNodeFlags:=ModDivNodeFlags;
        Result:=lCopy;
      end;


    function TModDivNode.Use_ModDiv64BitInt_Helper: Boolean;
      begin
        { Decide whether this operand combination requires a runtime helper. }
{$if defined(cpu64bitalu) or defined(cpuhighleveltarget)}
        Result:=false;
{$else cpu64bitalu or cpuhighleveltarget}
        Result:=
          (Left.ResultDef.typ=orddef) and
          (Right.ResultDef.typ=orddef) and
          { include currency as well }
          (Is_64Bit(Left.ResultDef) or Is_64Bit(Right.ResultDef));
{$endif cpu64bitalu or cpuhighleveltarget}
      end;


    function TModDivNode.Pass_TypeCheck:TNode;
      var
        lElseBlock,
        lTempNode,lNode : TNode;
        lRightDef,lLeftDef : TOrdDef;
        lElseStatements,
        lStatements : TStatementNode;
        lResultTemp : TTempCreateNode;
        lNewDef : TOrdDef;
      begin
         Result:=nil;
         TypeCheckPass(Left);
         TypeCheckPass(Right);

         { avoid any problems with type parameters later on }
         if Is_TypeParam(Left.ResultDef) or Is_TypeParam(Right.ResultDef) then
           begin
             ResultDef:=CUndefinedType;
             exit;
           end;

         Set_VarState(Left,vs_read,[vsf_must_be_valid]);
         Set_VarState(Right,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         { tp procvar support }
         Maybe_Call_ProcVar(Left,true);
         Maybe_Call_ProcVar(Right,true);

         { allow operator overloading }
         lNode:=self;
         if IsBinaryOverloaded(lNode,[]) then
           begin
              Result:=lNode;
              exit;
           end;

         if not(nf_internal in Flags) and
            (Is_Currency(Left.ResultDef) or Is_Currency(Right.ResultDef)) then
           begin
             { Divide the stored fixed-point integers. The quotient needs its
               Currency scale restored; the remainder already has that scale. }
             InsertTypeConv(Left,S64CurrencyType);
             InsertTypeConv(Right,S64CurrencyType);
             if CodeGenError then
               exit;
             lTempNode:=CModDivNode.Create(NodeType,
               CTypeConvNode.Create_Internal(Left,S64IntType),
               CTypeConvNode.Create_Internal(Right,S64IntType));
             TModDivNode(lTempNode).ModDivNodeFlags:=ModDivNodeFlags;
             Left:=nil;
             Right:=nil;
             if NodeType=divn then
               lTempNode:=CAddNode.Create_Internal(muln,lTempNode,COrdConstNode.Create(10000,S64IntType,false));
             Result:=CTypeConvNode.Create_Internal(lTempNode,S64CurrencyType);
             TypeCheckPass(Result);
             include(Result.Flags,nf_is_currency);
             exit;
           end;

         { we need 2 orddefs always }
         if (Left.ResultDef.typ<>orddef) then
           InsertTypeConv(Left,SIntType);
         if (Right.ResultDef.typ<>orddef) then
           InsertTypeConv(Right,SIntType);
         if CodeGenError then
           exit;

         { Try only now to simply constant
           as otherwise you might create
           tconstnode with return type that are
           not compatible with tconst node
           as in bug report 21566 PM }

         Result:=Simplify(false);
         if Assigned(Result) then
           exit;

         lRightDef:=TOrdDef(Right.ResultDef);
         lLeftDef:=TOrdDef(Left.ResultDef);

         { if one operand is a cardinal and the other is a positive constant, convert the }
         { constant to a cardinal as well so we don't have to do a 64bit division (JM)    }
         { Do the same for qwords and positive constants as well, otherwise things like   }
         { "qword mod 10" are evaluated with int64 as result, which is wrong if the       }
         { "qword" was > high(int64) (JM)                                                 }
         { Additionally, do the same for cardinal/qwords and other positive types, but    }
         { always in a way that a smaller type is converted to a bigger type              }
         { (tbs/tw8870)                                                                }
         if (lRightDef.OrdType in [u8bit,u16bit,u32bit,u64bit]) and
            ((Is_ConstIntNode(Left) and
              (TOrdConstNode(Left).Value >= 0) and
              (TOrdConstNode(Left).Value <= Get_Max_Value(lRightDef))) or
             (not Is_Signed(lLeftDef) and
              (lRightDef.Size >= lLeftDef.Size))) then
           begin
             if lRightDef.Size<UIntType.Size then
               begin
                 InsertTypeConv(Left,UIntType);
                 InsertTypeConv(Right,UIntType);
               end
             else
               InsertTypeConv(Left,lRightDef);
             ResultDef:=Right.ResultDef;
           end
         else if (lLeftDef.OrdType in [u8bit,u16bit,u32bit,u64bit]) and
            ((Is_ConstIntNode(Right) and
              (TOrdConstNode(Right).Value >= 0) and
              (TOrdConstNode(Right).Value <= Get_Max_Value(lLeftDef))) or
             (not Is_Signed(lRightDef) and
              (lLeftDef.Size >= lRightDef.Size))) then
           begin
             if lLeftDef.Size<UIntType.Size then
               begin
                 InsertTypeConv(Left,UIntType);
                 InsertTypeConv(Right,UIntType);
               end
             else
               InsertTypeConv(Right,lLeftDef);
             ResultDef:=Left.ResultDef;
           end
         else

         { when there is one currency value, everything is done
           using currency }
         if (lLeftDef.OrdType=scurrency) or
            (lRightDef.OrdType=scurrency) then
           begin
             if (lLeftDef.OrdType<>scurrency) then
              InsertTypeConv(Left,S64CurrencyType);
             if (lRightDef.OrdType<>scurrency) then
              InsertTypeConv(Right,S64CurrencyType);
             ResultDef:=Left.ResultDef;
           end
         else
          { when there is one 64bit value, everything is done
            in 64bit }
          if (Is_64BitInt(Left.ResultDef) or
              Is_64BitInt(Right.ResultDef)) then
           begin
             if Is_Signed(lRightDef) or Is_Signed(lLeftDef) then
               begin
                  if (lLeftDef.OrdType<>s64bit) then
                    InsertTypeConv(Left,S64IntType);
                  if (lRightDef.OrdType<>s64bit) then
                    InsertTypeConv(Right,S64IntType);
               end
             else
               begin
                  if (lLeftDef.OrdType<>u64bit) then
                    InsertTypeConv(Left,U64IntType);
                  if (lRightDef.OrdType<>u64bit) then
                    InsertTypeConv(Right,U64IntType);
               end;
             ResultDef:=Left.ResultDef;
           end
         else
          { is there a larger than the native int? }
          if Is_OversizedInt(lLeftDef) or Is_OversizedInt(lRightDef) then
           begin
             lNewDef:=Get_Common_IntDef(lLeftDef,lRightDef,false);
             if (lLeftDef.OrdType<>lNewDef.OrdType) then
               InsertTypeConv(Left,lNewDef);
             if (lRightDef.OrdType<>lNewDef.OrdType) then
               InsertTypeConv(Right,lNewDef);
             ResultDef:=Left.ResultDef;
           end
         else
          { when mixing unsigned and signed native ints, convert everything to a larger signed type (JM) }
          if (Is_NativeUInt(lRightDef) and
              Is_Signed(lLeftDef)) or
             (Is_NativeUInt(lLeftDef) and
              Is_Signed(lRightDef)) then
           begin
              CGMessage(type_h_mixed_signed_unsigned);
              { get a signed int, larger than the native int }
              lNewDef:=Get_Common_IntDef(TOrdDef(SIntType),TOrdDef(UIntType),false);
              if (lLeftDef.OrdType<>lNewDef.OrdType) then
                InsertTypeConv(Left,lNewDef);
              if (lRightDef.OrdType<>lNewDef.OrdType) then
                InsertTypeConv(Right,lNewDef);
              ResultDef:=Left.ResultDef;
           end
         else
           begin
              { Make everything always default signed int }
              if not(lRightDef.OrdType in [TOrdDef(SIntType).OrdType,TOrdDef(UIntType).OrdType]) then
                InsertTypeConv(Right,SIntType);
              if not(lLeftDef.OrdType in [TOrdDef(SIntType).OrdType,TOrdDef(UIntType).OrdType]) then
                InsertTypeConv(Left,SIntType);
              ResultDef:=Right.ResultDef;
           end;

         Result:=Simplify(false);
         if Assigned(Result) then
           exit;

         if (NodeType=modn) and (mdnf_isomod in ModDivNodeFlags) then
           begin
             Result:=InternalStatements(lStatements);
             lElseBlock:=InternalStatements(lElseStatements);
             lResultTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);

             { right <=0? }
             AddStatement(lStatements,CIfNode.Create_Internal(CAddNode.Create_Internal(lten,Right.GetCopy,COrdConstNode.Create(0,ResultDef,false)),
               { then: result:=left mod right }
               CCallNode.CreateIntern('fpc_divbyzero',nil),
               nil
               ));

             { prepare else block }
             { result:=(-left) mod right }
             AddStatement(lElseStatements,CAssignmentNode.Create(CTempRefNode.Create(lResultTemp),CModDivNode.Create(modn,CUnaryMinusNode.Create(Left.GetCopy),Right.GetCopy)));
             { result<>0? }
             AddStatement(lElseStatements,CIfNode.Create_Internal(CAddNode.Create_Internal(unequaln,CTempRefNode.Create(lResultTemp),COrdConstNode.Create(0,ResultDef,false)),
               { then: result:=right-result }
               CAssignmentNode.Create_Internal(CTempRefNode.Create(lResultTemp),CAddNode.Create_Internal(subn,Right.GetCopy,CTempRefNode.Create(lResultTemp))),
               nil
               ));

             AddStatement(lStatements,lResultTemp);
             { if left>=0 }
             AddStatement(lStatements,CIfNode.Create_Internal(CAddNode.Create_Internal(gten,Left.GetCopy,COrdConstNode.Create(0,ResultDef,false)),
               { then: result:=left mod right }
               CAssignmentNode.Create_Internal(CTempRefNode.Create(lResultTemp),CModDivNode.Create(modn,Left.GetCopy,Right.GetCopy)),
               { else block }
               lElseBlock
               ));

             AddStatement(lStatements,CTempDeleteNode.Create_Normal_Temp(lResultTemp));
             AddStatement(lStatements,CTempRefNode.Create(lResultTemp));
           end;
      end;


    function TModDivNode.First_ModDivInt: TNode;
{$ifdef cpuneedsdivhelper}
      var
        lProcName: string[31];
      begin
        Result := nil;

        { otherwise create a call to a helper }
        if NodeType = divn then
          lProcName := 'fpc_div_'
        else
          lProcName := 'fpc_mod_';

        { only qword needs the unsigned code, the
          signed code is also used for currency }
        case TOrdDef(ResultDef).OrdType of
          u8bit:
            lProcName := lProcName + 'byte';
          s8bit:
            lProcName := lProcName + 'shortint';
          u16bit:
            lProcName := lProcName + 'word';
          s16bit:
            lProcName := lProcName + 'smallint';
          u32bit:
            lProcName := lProcName + 'dword';
          s32bit:
            lProcName := lProcName + 'longint';
          scurrency:
            lProcName := lProcName + 'currency';
          else
            InternalError(2015070501);
        end;

        Result := CCallNode.CreateIntern(lProcName,CCallParaNode.Create(Left,
          CCallParaNode.Create(Right,nil)));
        Left := nil;
        Right := nil;
        FirstPass(Result);

        if Result.ResultDef.typ<>orddef then
          InternalError(2013031701);
        if ResultDef.typ<>orddef then
          InternalError(2013031702);
        if TOrdDef(Result.ResultDef).OrdType <> TOrdDef(ResultDef).OrdType then
          InsertTypeConv(Result,ResultDef);
      end;
{$else cpuneedsdivhelper}
      begin
        Result:=nil;
      end;
{$endif cpuneedsdiv32helper}


    function TModDivNode.First_ModDiv64BitInt: TNode;
      var
        lProcName: string[31];
      begin
        Result := nil;

        { when currency is used set the result of the
          parameters to s64bit, so they are not converted }
        if nf_is_currency in Flags then
          begin
            Left.ResultDef:=S64IntType;
            Right.ResultDef:=S64IntType;
          end;

        { otherwise create a call to a helper }
        if NodeType = divn then
          lProcName := 'fpc_div_'
        else
          lProcName := 'fpc_mod_';
        { only qword needs the unsigned code, the
          signed code is also used for currency }
        if Is_Signed(ResultDef) then
          lProcName := lProcName + 'int64'
        else
          lProcName := lProcName + 'qword';

        Result := CCallNode.CreateIntern(lProcName,CCallParaNode.Create(Left,
          CCallParaNode.Create(Right,nil)));
        Left := nil;
        Right := nil;
        FirstPass(Result);
      end;


    function TModDivNode.FirstOptimize: TNode;
      var
        lPower,lShiftValue : LongInt;
        lStatements : TStatementNode;
        lTemp,lResultTemp : TTempCreateNode;
        lMaskNode : TNode;
        lInvertSign: Boolean;
      begin
        Result := nil;
        { divide/mod a number by a constant which is a power of 2? }
        if (Right.NodeType = ordconstn) and
          IsAbsPowerOf2(TOrdConstNode(Right).Value,lPower) and
{$if defined(cpu64bitalu) or defined(cpuhighleveltarget)}
          { for 64 bit, we leave the optimization to the cg }
            (not Is_Signed(ResultDef)) then
{$else cpu64bitalu or cpuhighleveltarget}
           (((NodeType=divn) and Is_OversizedOrd(ResultDef)) or
            (NodeType=modn) or
            not Is_Signed(ResultDef)) then
{$endif cpu64bitalu or cpuhighleveltarget}
          begin
            if NodeType=divn then
              begin
                if Is_Signed(ResultDef) then
                  begin
                    lInvertSign:=TOrdConstNode(Right).Value<0;
                    if Is_64BitInt(Left.ResultDef) then
                      if not (cs_opt_size in CurrentSettings.OptimizerSwitches) then
                        lShiftValue:=63
                      else
                        { the shift code is a lot bigger than the call to }
                        { the divide helper                               }
                        exit
                    else
                      lShiftValue:=Left.ResultDef.Size*8-1;

                    Result:=InternalStatements(lStatements);
                    lTemp:=CTempCreateNode.Create(Left.ResultDef,Left.ResultDef.Size,tt_persistent,true);
                    lResultTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);
                    AddStatement(lStatements,lResultTemp);
                    AddStatement(lStatements,lTemp);
                    AddStatement(lStatements,CAssignmentNode.Create(CTempRefNode.Create(lTemp),
                     Left));
                    Left:=nil;

                    { masknode is (sar(temp,shiftval) and ((1 shl power)-1))
                      for power=1 (i.e. division by 2), masknode is simply (temp shr shiftval)}
                    if lPower=1 then
                      lMaskNode:=
                        CShlShrNode.Create(shrn,
                          CTempRefNode.Create(lTemp),
                          COrdConstNode.Create(lShiftValue,U8IntType,false)
                        )
                    else
                      lMaskNode:=
                        CAddNode.Create(andn,
                          CInlineNode.Create(in_sar_x_y,false,
                            CCallParaNode.Create(COrdConstNode.Create(lShiftValue,U8IntType,false),
                            CCallParaNode.Create(CTempRefNode.Create(lTemp),nil))
                          ),
                          COrdConstNode.Create(TCGInt((QWord(1) shl lPower)-1),
                            Right.ResultDef,false)
                        );

                    if lInvertSign then
                      AddStatement(lStatements,CAssignmentNode.Create(CTempRefNode.Create(lResultTemp),
                        CUnaryMinusNode.Create(
                          CInlineNode.Create(in_sar_x_y,false,
                            CCallParaNode.Create(COrdConstNode.Create(lPower,U8IntType,false),
                            CCallParaNode.Create(CAddNode.Create(addn,CTempRefNode.Create(lTemp),
                              lMaskNode),nil
                            )))))
                      )
                    else
                      AddStatement(lStatements,CAssignmentNode.Create(CTempRefNode.Create(lResultTemp),
                        CInlineNode.Create(in_sar_x_y,false,
                          CCallParaNode.Create(COrdConstNode.Create(lPower,U8IntType,false),
                          CCallParaNode.Create(CAddNode.Create(addn,CTempRefNode.Create(lTemp),
                            lMaskNode),nil
                          ))))
                      );
                    AddStatement(lStatements,CTempDeleteNode.Create(lTemp));
                    AddStatement(lStatements,CTempDeleteNode.Create_Normal_Temp(lResultTemp));
                    AddStatement(lStatements,CTempRefNode.Create(lResultTemp));
                    Right.Free;
                    Right := nil;
                  end
                else
                  begin
                    TOrdConstNode(Right).Value:=lPower;
                    Result:=CShlShrNode.Create(shrn,Left,Right)
                  end;
              end
            else if Is_Signed(ResultDef) then    { signed modulus }
              begin
                if (cs_opt_size in CurrentSettings.OptimizerSwitches) then
                  exit;

                lShiftValue:=Left.ResultDef.Size*8-1;
                TOrdConstNode(Right).Value.uvalue:=QWord((QWord(1) shl lPower)-1);

                Result:=InternalStatements(lStatements);
                lTemp:=CTempCreateNode.Create(Left.ResultDef,Left.ResultDef.Size,tt_persistent,true);
                lResultTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);
                AddStatement(lStatements,lResultTemp);
                AddStatement(lStatements,lTemp);
                AddStatement(lStatements,CAssignmentNode.Create(CTempRefNode.Create(lTemp),Left));
                { mask:=sar(left,sizeof(left)*8-1) and ((1 shl power)-1); }
                if lPower=1 then
                  lMaskNode:=
                    CShlShrNode.Create(shrn,
                      CTempRefNode.Create(lTemp),
                      COrdConstNode.Create(lShiftValue,U8IntType,false)
                    )
                else
                  lMaskNode:=
                    CAddNode.Create(andn,
                      CInlineNode.Create(in_sar_x_y,false,
                        CCallParaNode.Create(COrdConstNode.Create(lShiftValue,U8IntType,false),
                        CCallParaNode.Create(CTempRefNode.Create(lTemp),nil))
                      ),
                      COrdConstNode.Create(TCGInt((QWord(1) shl lPower)-1),
                        Right.ResultDef,false)
                    );
                AddStatement(lStatements,CAssignmentNode.Create(CTempRefNode.Create(lResultTemp),lMaskNode));

                { result:=((left+mask) and right)-mask; }
                AddStatement(lStatements,CAssignmentNode.Create(CTempRefNode.Create(lResultTemp),
                  CAddNode.Create(subn,
                    CAddNode.Create(andn,
                      Right,
                      CAddNode.Create(addn,
                        CTempRefNode.Create(lTemp),
                        CTempRefNode.Create(lResultTemp))),
                  CTempRefNode.Create(lResultTemp))
                ));

                AddStatement(lStatements,CTempDeleteNode.Create(lTemp));
                AddStatement(lStatements,CTempDeleteNode.Create_Normal_Temp(lResultTemp));
                AddStatement(lStatements,CTempRefNode.Create(lResultTemp));
              end
            else
              begin
                TOrdConstNode(Right).Value.uvalue:=QWord((QWord(1) shl lPower)-1);
                Result := CAddNode.Create(andn,Left,Right);
              end;
            { left and right are reused }
            Left := nil;
            Right := nil;
            FirstPass(Result);
            exit;
          end;
      end;


    function TModDivNode.Pass_1 : TNode;
      begin
         Result:=nil;
         FirstPass(Left);
         FirstPass(Right);
         if CodeGenError then
           exit;

         { Try to optimize mod/div }
         Result := FirstOptimize;
         if Assigned(Result) then
           exit;

         { 64bit }
         if Use_ModDiv64BitInt_Helper then
           begin
             Result := First_ModDiv64BitInt;
             if Assigned(Result) then
               exit;
             ExpectLoc:=LOC_REGISTER;
           end
         else
           begin
             Result := First_ModDivInt;
             if Assigned(Result) then
               exit;
           end;
         ExpectLoc:=LOC_REGISTER;
      end;


{****************************************************************************
                              TSHLSHRNODE
 ****************************************************************************}

    function TShlShrNode.Simplify(AForInline : Boolean):TNode;
      var
        lLeftValue, lRightValue, lMask : TConstExprInt;
        lRangeDef: TDef;
        lSize: LongInt;
      begin
        Result:=nil;
        { constant folding }
        if Is_ConstIntNode(Right) then
          begin
            if AForInline then
              begin
                case ResultDef.Size of
                  1,2,4:
                    lRightValue:=TOrdConstNode(Right).Value and Byte($1f);
                  8:
                    lRightValue:=TOrdConstNode(Right).Value and Byte($3f);
                  else
                    InternalError(2013122302);
                end;
              end
            else
              lRightValue:=TOrdConstNode(Right).Value;
            if Is_ConstIntNode(Left) then
               begin
                 lLeftValue:=TOrdConstNode(Left).Value;
                 GetRangeDefMaskSize(ResultDef, lRangeDef, lMask, lSize);
                 { shr is an unsigned operation, so cut off upper bits }
                 if AForInline then
                   lLeftValue:=lLeftValue and lMask;
                 case NodeType of
                    shrn:
                      lLeftValue:=lLeftValue shr lRightValue;
                    shln:
                      lLeftValue:=lLeftValue shl lRightValue;
                    else
                      InternalError(2019050517);
                 end;
                 { discard shifted-out bits (shl never triggers overflow/range errors) }
                 if AForInline and
                    (NodeType=shln) then
                   lLeftValue:=lLeftValue and lMask;
                 Result:=Create_Simplified_Ord_Const(lLeftValue,ResultDef,AForInline,false);
               end
            else if lRightValue=0 then
              begin
                Result:=Left;
                Left:=nil;
              end
            { optimize "a shl n1 shl n2" and "a shr n1 shr n2" }
            else if (NodeType=Left.NodeType) and Is_ConstIntNode(TShlShrNode(Left).Right) and
              { do not overflow the variable being shifted }
              (TOrdConstNode(Right).Value+TOrdConstNode(TShlShrNode(Left).Right).Value<TShlShrNode(Left).Left.ResultDef.Size*8) then
              begin
                Result:=Left;
                Left:=nil;
                TOrdConstNode(TShlShrNode(Result).Right).Value:=TOrdConstNode(TShlShrNode(Result).Right).Value+TOrdConstNode(Right).Value;
              end;
          end
        else if Is_ConstIntNode(Left) then
          begin
            lLeftValue:=TOrdConstNode(Left).Value;
            if AForInline then
              begin
                GetRangeDefMaskSize(ResultDef, lRangeDef, lMask, lSize);
                lLeftValue:=lLeftValue and lMask;
              end;
            { '0 shl x' and '0 shr x' are 0 }
            if (lLeftValue=0) and
               ((cs_opt_level4 in CurrentSettings.OptimizerSwitches) or
                not Might_Have_SideEffects(Right)) then
              Result:=COrdConstNode.Create(0,ResultDef,true);
          end;
      end;


    function TShlShrNode.Pass_TypeCheck:TNode;
      var
         lNode : TNode;
      begin
         Result:=nil;
         TypeCheckPass(Left);
         TypeCheckPass(Right);

         { avoid any problems with type parameters later on }
         if Is_TypeParam(Left.ResultDef) or Is_TypeParam(Right.ResultDef) then
           begin
             ResultDef:=CUndefinedType;
             exit;
           end;

         Set_VarState(Right,vs_read,[vsf_must_be_valid]);
         Set_VarState(Left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         { tp procvar support }
         Maybe_Call_ProcVar(Left,true);
         Maybe_Call_ProcVar(Right,true);

         { allow operator overloading }
         lNode:=self;
         if IsBinaryOverloaded(lNode,[]) then
           begin
              Result:=lNode;
              exit;
           end;

           begin
             { calculations for ordinals < 32 bit have to be done in
               32 bit for backwards compatibility. That way 'shl 33' is
               the same as 'shl 1'. It's ugly but compatible with delphi/tp/gcc }
             if (not Is_64Bit(Left.ResultDef)) and
                (TOrdDef(Left.ResultDef).OrdType<>u32bit) then
               begin
                 { keep signedness of original type }
                 if Is_Signed(Left.ResultDef) then
                   begin
{$if defined(cpu64bitalu) or defined(cpu32bitalu)}
                     InsertTypeConv(Left,S32IntType)
{$else}
                     InternalError(2013031301);
{$endif}
                   end
                 else
                   begin
{$if defined(cpu64bitalu) or defined(cpu32bitalu)}
                     InsertTypeConv(Left,U32IntType);
{$else}
                     InternalError(2013031302);
{$endif}
                   end
               end;

             InsertTypeConv(Right,SIntType);
           end;

         ResultDef:=Left.ResultDef;

         Result:=Simplify(false);
         if Assigned(Result) then
           exit;
      end;


{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
    function TShlShrNode.First_ShlShr64BitInt: TNode;
      var
        lProcName: string[31];
      begin
        Result := nil;
        { Normally already done below, but called again,
          just in case it is called directly }
        FirstPass(Left);
        { otherwise create a call to a helper }
        if Is_Signed(Left.ResultDef) then
          lProcName:='int64'
        else
          lProcName:='qword';
        if NodeType = shln then
          lProcName := 'fpc_shl_'+lProcName
        else
          lProcName := 'fpc_shr_'+lProcName;
        { this order of parameters works at least for the arm,
          however it should work for any calling conventions (FK) }
        Result := CCallNode.CreateIntern(lProcName,CCallParaNode.Create(Right,
          CCallParaNode.Create(Left,nil)));
        Left := nil;
        Right := nil;
        FirstPass(Result);
      end;
{$endif not cpu64bitalu and not cpuhighleveltarget}


    function TShlShrNode.Pass_1 : TNode;
      begin
         Result:=nil;
         FirstPass(Left);
         FirstPass(Right);
         if CodeGenError then
           exit;

         ExpectLoc:=LOC_REGISTER;
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         { 64 bit ints have their own shift handling }
         if Is_64Bit(Left.ResultDef) then
           Result := First_ShlShr64BitInt;
{$endif not cpu64bitalu and not cpuhighleveltarget}
      end;


{****************************************************************************
                            TUNARYMINUSNODE
 ****************************************************************************}

    constructor TUnaryMinusNode.Create(AExpr : TNode);
      begin
        inherited Create(unaryminusn,AExpr);
      end;


    function TUnaryMinusNode.Simplify(AForInline : Boolean):TNode;
      begin
        Result:=nil;
        { constant folding }
        if Is_ConstIntNode(Left) then
          begin
             Result:=Create_Simplified_Ord_Const(-TOrdConstNode(Left).Value,ResultDef,AForInline,cs_check_overflow in LocalSwitches);
             exit;
          end;
        if Is_ConstRealNode(Left) then
          begin
             TRealConstNode(Left).NegateValue;
             Result:=Left;
             Left:=nil;
             exit;
          end;
        if Is_Real(Left.ResultDef) then
          begin
            {
              -(left-right) => right-left

              As this result in -(1.0-1.0)=0.0 instead of 0.0, this is only valid in fastmath mode
            }
            if (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (Left.NodeType=subn) then
              begin
                Result:=CAddNode.Create(subn,TAddNode(Left).Right.GetCopy,TAddNode(Left).Left.GetCopy);
                exit;
              end;

            {
              -(-left*right) or -(left*-right) => right*left

              this operation is always valid as reals do not use a two's complement representation for negative
              numbers, -real means just flip the sign bit
            }
            if (Left.NodeType=muln) and ((TAddNode(Left).Left.NodeType=unaryminusn)) then
              begin
                Result:=CAddNode.Create(muln,TUnaryMinusNode(TAddNode(Left).Left).Left.GetCopy,TAddNode(Left).Right.GetCopy);
                exit;
              end;
            if (Left.NodeType=muln) and ((TAddNode(Left).Right.NodeType=unaryminusn)) then
              begin
                Result:=CAddNode.Create(muln,TAddNode(Left).Left.GetCopy,TUnaryMinusNode(TAddNode(Left).Right).Left.GetCopy);
                exit;
              end;

            {
              -(-left/right) or -(left/-right) => right/left

              this operation is always valid as reals do not use a two's complement representation for negative
              numbers, -real means just flip the sign bit
            }
            if (Left.NodeType=slashn) and ((TAddNode(Left).Left.NodeType=unaryminusn)) then
              begin
                Result:=CAddNode.Create(slashn,TUnaryMinusNode(TAddNode(Left).Left).Left.GetCopy,TAddNode(Left).Right.GetCopy);
                exit;
              end;
            if (Left.NodeType=slashn) and ((TAddNode(Left).Right.NodeType=unaryminusn)) then
              begin
                Result:=CAddNode.Create(slashn,TAddNode(Left).Left.GetCopy,TUnaryMinusNode(TAddNode(Left).Right).Left.GetCopy);
                exit;
              end;

            { --node => node
              this operation is always valid as reals do not use a two's complement representation for negative
              numbers, -real means just flip the sign bit
            }
            if Left.NodeType=unaryminusn then
              begin
                Result:=TUnaryNode(Left).Left.GetCopy;
                exit;
              end;
          end
        { transform -(x+1) or -(1+x) into not(x) }
        else if Is_Integer(Left.ResultDef) and Is_Signed(Left.ResultDef) and (Left.NodeType=addn) and ((LocalSwitches*[cs_check_overflow,cs_check_range])=[]) then
          begin
            if Is_ConstIntNode(TAddNode(Left).Right) and (TOrdConstNode(TAddNode(Left).Right).Value=1) then
              begin
                Result:=CNotNode.Create(TAddNode(Left).Left.GetCopy);
                exit;
              end
            else if Is_ConstIntNode(TAddNode(Left).Left) and (TOrdConstNode(TAddNode(Left).Left).Value=1) then
              begin
                Result:=CNotNode.Create(TAddNode(Left).Right.GetCopy);
                exit;
              end;
          end;
      end;


    function TUnaryMinusNode.Pass_TypeCheck : TNode;
      var
         lNode : TNode;
      begin
         Result:=nil;
         TypeCheckPass(Left);

         { avoid any problems with type parameters later on }
         if Is_TypeParam(Left.ResultDef) then
           begin
             ResultDef:=CUndefinedType;
             exit;
           end;

         Set_VarState(Left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         Result:=Simplify(false);
         if Assigned(Result) then
           exit;

         ResultDef:=Left.ResultDef;
         if Is_Currency(Left.ResultDef) then
           begin
             { negating a currency value does not change its scaling, so the
               result is scaled exactly like the operand }
             if nf_is_currency in Left.Flags then
               Include(Flags,nf_is_currency);
           end
         else if Left.ResultDef.typ=floatdef then
           begin
             if not(TFloatDef(Left.ResultDef).FloatType in [s64comp,s64currency]) and
               (cs_excessprecision in CurrentSettings.LocalSwitches) then
               begin
                 InsertTypeConv(Left,PBestRealType^);
                 ResultDef:=Left.ResultDef
               end;
           end
         else if Is_OversizedOrd(Left.ResultDef) then
           begin
             if Is_64Bit(Left.ResultDef) then
               InsertTypeConv(Left,S64IntType)
             else if Is_32Bit(Left.ResultDef) then
               InsertTypeConv(Left,S32IntType)
             else if Is_16Bit(Left.ResultDef) then
               InsertTypeConv(Left,S16IntType)
             else
               InternalError(2013040701);
             ResultDef:=Left.ResultDef;
           end
         else if (Left.ResultDef.typ=orddef) then
           begin
             InsertTypeConv(Left,SIntType);
             ResultDef:=Left.ResultDef
           end
         else
           begin
             { allow operator overloading }
             lNode:=self;
             if IsUnaryOverloaded(lNode,[]) then
               begin
                  Result:=lNode;
                  exit;
               end;

             CGMessage(type_e_mismatch);
           end;
      end;

    { generic code     }
    { overridden by:   }
    {   i386           }
    function TUnaryMinusNode.Pass_1 : TNode;
      begin
        Result:=nil;
        FirstPass(Left);
        if CodeGenError then
          exit;

        if (Left.ResultDef.typ=floatdef) then
          ExpectLoc:=LOC_FPUREGISTER
        else if (Left.ResultDef.typ=orddef) then
          ExpectLoc:=LOC_REGISTER;
      end;

{****************************************************************************
                             TUNARYPLUSNODE
 ****************************************************************************}

    constructor TUnaryPlusNode.Create(AExpr: TNode);
      begin
        inherited Create(unaryplusn,AExpr);
      end;

    function TUnaryPlusNode.Pass_1: TNode;
      begin
        Result:=nil;
        { can never happen because all the conversions happen
          in pass_typecheck }
        InternalError(201012250);
      end;

    function TUnaryPlusNode.Pass_TypeCheck: TNode;
      var
        lNode:TNode;
      begin
        Result:=nil;
        TypeCheckPass(Left);

        { avoid any problems with type parameters later on }
        if Is_TypeParam(Left.ResultDef) then
          begin
            ResultDef:=CUndefinedType;
            exit;
          end;

        Set_VarState(Left,vs_read,[vsf_must_be_valid]);
        if CodeGenError then
          exit;

        if Is_ConstIntNode(Left) or
           Is_ConstRealNode(Left) or
           (Left.ResultDef.typ=floatdef) or
           Is_Currency(Left.ResultDef)
        then
          begin
            Result:=Left;
            Left:=nil;
          end
        else if Is_OversizedOrd(Left.ResultDef) then
          begin
            if Is_64Bit(Left.ResultDef) then
              InsertTypeConv(Left,S64IntType)
            else if Is_32Bit(Left.ResultDef) then
              InsertTypeConv(Left,S32IntType)
            else if Is_16Bit(Left.ResultDef) then
              InsertTypeConv(Left,S16IntType)
            else
              InternalError(2013040702);
            Result:=Left;
            Left:=nil;
          end
        else if (Left.ResultDef.typ=orddef) then
          begin
            InsertTypeConv(Left,SIntType);
            Result:=Left;
            Left:=nil;
          end
        else
          begin
            { allow operator overloading }
            lNode:=self;
            if IsUnaryOverloaded(lNode,[]) then
              begin
                Result:=lNode;
                exit;
             end;

             CGMessage(type_e_mismatch);
           end;
      end;


{****************************************************************************
                               TNOTNODE
 ****************************************************************************}

    const
      cBooleanReverse:array[ltn..unequaln] of TNodeType=(
        gten,gtn,lten,ltn,unequaln,EqualN
      );

    constructor TNotNode.Create(AExpr : TNode);
      begin
         inherited Create(notn,AExpr);
      end;


    function TNotNode.Simplify(AForInline : Boolean):TNode;
      var
        lValue : TConstExprInt;
        lNode : TNode;
        lDef : TDef;
      begin
        Result:=nil;
        { Try optimizing ourself away }
        if Left.NodeType=notn then
          begin
            { Double not. Remove both }
            Result:=TNotNode(Left).Left;
            TNotNode(Left).Left:=nil;
            exit;
          end;

        if (Left.NodeType in [ltn,lten,EqualN,unequaln,gtn,gten]) then
         begin
           { Not of boolean expression. Turn around the operator and remove
             the not. This is not allowed for sets with the gten/lten,
             because there is no ltn/gtn support }
           if (TAddNode(Left).Left.ResultDef.typ<>setdef) or
              (Left.NodeType in [EqualN,unequaln]) then
            begin
              Result:=Left;
              Left.NodeType:=cBooleanReverse[Left.NodeType];
              Left:=nil;
              exit;
            end;
         end;

        { constant folding }
        if (Left.NodeType=ordconstn) and
          (Left.ResultDef.typ=orddef) then
          begin
             lValue:=TOrdConstNode(Left).Value;
             lDef:=Left.ResultDef;
             if not Calc_Not_OrdValue(lValue,lDef) then
               CGMessage(type_e_mismatch);
             { not-nodes are not range checked by the code generator -> also
               don't range check while inlining; the resultdef is a bit tricky
               though: the node's resultdef gets changed in most cases compared
               to left, but the not-operation itself is carried out in the code
               generator using the size of left
               }
             if not(AForInline) then
               lNode:=COrdConstNode.Create(lValue,lDef,false)
             else
               begin
                 { cut off the value if necessary }
                 lNode:=COrdConstNode.Create(lValue,Left.ResultDef,false);
                 { now convert to node's resultdef }
                 InsertTypeConv_Explicit(lNode,lDef);
               end;
             Result:=lNode;
             exit;
          end;
      end;


    function TNotNode.Pass_TypeCheck : TNode;
      var
         lNode : TNode;
      begin
         Result:=nil;
         TypeCheckPass(Left);

         { avoid any problems with type parameters later on }
         if Is_TypeParam(Left.ResultDef) then
           begin
             ResultDef:=CUndefinedType;
             exit;
           end;

         Set_VarState(Left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         { tp procvar support }
         Maybe_Call_ProcVar(Left,true);

         ResultDef:=Left.ResultDef;

         Result:=Simplify(false);
         if Assigned(Result) then
           exit;

         if Is_Boolean(ResultDef) then
           begin
           end
         else
{$ifndef cpu64bitaddr}
           if Is_64BitInt(Left.ResultDef) then
             begin
             end
         else
{$endif not cpu64bitaddr}
           if Is_Integer(Left.ResultDef) then
             begin
             end
         else
           begin
             { allow operator overloading }
             lNode:=self;
             if IsUnaryOverloaded(lNode,[]) then
               begin
                  Result:=lNode;
                  exit;
               end;

             CGMessage(type_e_mismatch);
           end;
      end;


    function TNotNode.Pass_1 : TNode;
      begin
         Result:=nil;
         FirstPass(Left);
         if CodeGenError then
           exit;

         ExpectLoc:=Left.ExpectLoc;
         if Is_Boolean(ResultDef) then
           begin
             if (ExpectLoc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_CREGISTER]) then
               ExpectLoc:=LOC_REGISTER;
             { xtensa has boolean registers which are treated as flags but they
               are not used for boolean expressions }
{$if defined(cpuflags)}
             if Left.ExpectLoc<>LOC_JUMP then
               ExpectLoc:=LOC_FLAGS;
{$endif defined(cpuflags) and not(defined(xtensa)}
           end
         else
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
           if Is_64Bit(Left.ResultDef) then
             begin
                if (ExpectLoc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_CREGISTER]) then
                  ExpectLoc:=LOC_REGISTER;
             end
         else
{$endif not cpu64bitalu and not cpuhighleveltarget}
           if Is_Integer(Left.ResultDef) then
             ExpectLoc:=LOC_REGISTER;
      end;


end.
