{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Type checking and simplification for add nodes

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
unit nadd;

{$i fpcdefs.inc}
{$modeswitch nestedprocvars}

{ define addstringopt}

interface

    uses
      TPCompilerReal,
      node,symtype;

    type
       TAddNodeFlag = (
         anf_has_pointerdiv,
         { the node shall be short boolean evaluated, this flag has priority over localswitches }
         anf_short_bool
       );

       TAddNodeFlags = set of TAddNodeFlag;

       TAddNode = class(TBinOpNode)
       private
          FResultRealDefDeref: TDeref;
          function PassTypeCheckInternal:TNode;
          function DoCurrencyCorrections: TNode;
       public
          ResultRealDef : TDef;
          AddNodeFlags : TAddNodeFlags;
          constructor Create(ANodeType : TNodeType;ALeft,ARight : TNode);override;
          constructor Create_Internal(ANodeType:TNodeType;ALeft,ARight:TNode);
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function Simplify(AForInline: Boolean) : TNode;override;
          function DoGetCopy : TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
          procedure PrintNodeData(var AText:Text);override;
         protected
          { override the following if you want to implement }
          { parts explicitely in the code generator (JM)    }
          function First_AddString: TNode; virtual;
          function First_AddSet: TNode; virtual;
          function First_AddDynArray : TNode; virtual;
          { only implements "muln" nodes, the rest always has to be done in }
          { the code generator for performance reasons (JM)                 }
          function First_Add64BitInt: TNode; virtual;
          function First_AddPointer: TNode; virtual;
          function First_CmpPointer: TNode; virtual;

          { override and return false if you can handle 32x32->64 }
          { bit multiplies directly in your code generator. If    }
          { this function is overridden to return false, you can  }
          { get multiplies with left/right both s32bit or u32bit, }
          { and resultdef of the muln s64bit or u64bit           }
          function Use_Generic_Mul32To64: Boolean; virtual;

          { override and return false if code generator can handle }
          { full 64 bit multiplies.                                }
          function Use_Generic_Mul64Bit: Boolean; virtual;

{$ifdef cpuneedsmulhelper}
          { override to customize to decide if the code generator }
          { can handle a given multiply node directly, or it needs helpers }
          function Use_Mul_Helper: Boolean; virtual;
{$endif cpuneedsmulhelper}

          { shall be overridden if the target cpu supports
            an fma instruction
          }
          function Use_FMA : Boolean; virtual;
       private
          { checks whether a muln can be calculated as a 32bit }
          { * 32bit -> 64 bit                                  }
          function TryMakeMul32To64: Boolean;

          { Match against the ranges, i.e.:
            var a:1..10;
            begin
              if a>0 then
                ...
            always evaluates to true. (DM)
          }
          function CompareDisjointRanges(var AComparisonResult : Boolean) : Boolean;

          { tries to replace the current node by a fma node }
          function TryFMA(ALeftDef,ARightDef : TDef) : TNode;
       end;
       TAddNodeClass = class of TAddNode;

    var
       { caddnode is used to create nodes of the add type }
       { the virtual constructor allows to assign         }
       { another class type to caddnode => processor      }
       { specific node types can be created               }
       CAddNode : TAddNodeClass = TAddNode;

implementation

    uses
      SysUtils,
      GlobType,Systems,ConstExp,compinnr,
      CUtils,Verbose,Globals,WideStr,
      tokens,
      symconst,symdef,SymSym,symcpu,SymTable,defutil,defcmp,
      cgbase,
      htypechk,Pass_1,
      nld,nbas,nmat,ncnv,ncon,nset,nopt,ncal,ninl,nmem,nutils,
      CPUInfo,
      PPU;

const
    cBestRealLayoutCheck = 1 div Ord(SizeOf(BestRealRec) = SizeOf(BestReal));
    cSwapRelation: array [ltn..unequaln] of TNodeType=(gtn, gten, ltn, lten, EqualN, unequaln);

{*****************************************************************************
                                TADDNODE
*****************************************************************************}

{$maxfpuregisters 0}

    function GetBestReal(ADef1,ADef2 : TDef) : TDef;
      const
        cFloatWeight : array[TFloatType] of Byte =
          (2,3,4,5,0,1);
      begin
        if ADef1.typ=floatdef then
          begin
            Result:=ADef1;
            if ADef2.typ=floatdef then
              begin
                { when a comp or currency is used, use always the
                  best float type to calculate the result }
                if (TFloatDef(ADef1).FloatType in [s64comp,s64currency]) or
                  (TFloatDef(ADef2).FloatType in [s64comp,s64currency]) or
                  (cs_excessprecision in CurrentSettings.LocalSwitches) then
                  Result:=PBestRealType^
                else
                  if cFloatWeight[TFloatDef(ADef2).FloatType]>cFloatWeight[TFloatDef(ADef1).FloatType] then
                    Result:=ADef2;
              end;
          end
        else if ADef2.typ=floatdef then
          Result:=ADef2
        else InternalError(200508061);
      end;


    constructor TAddNode.Create(ANodeType : TNodeType;ALeft,ARight : TNode);
      begin
         inherited Create(ANodeType,ALeft,ARight);
         AddNodeFlags:=[];
      end;

    constructor TAddNode.Create_Internal(ANodeType:TNodeType;ALeft,ARight:TNode);
      begin
        Create(ANodeType,ALeft,ARight);
        include(Flags,nf_internal);
      end;


    constructor TAddNode.PPULoad(ANodeType: TNodeType; APPUFile: TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType, APPUFile);
        APPUFile.GetSet(TPPUSet1(AddNodeFlags));
        APPUFile.GetDeref(FResultRealDefDeref);
      end;


    procedure TAddNode.PPUWrite(APPUFile: TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutSet(TPPUSet1(AddNodeFlags));
        APPUFile.PutDeref(FResultRealDefDeref);
      end;


    procedure TAddNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        FResultRealDefDeref.Build(ResultRealDef);
      end;


    procedure TAddNode.DerefImpl;
      begin
        inherited DerefImpl;
        ResultRealDef:=TDef(FResultRealDefDeref.resolve);
      end;


    function TAddNode.CompareDisjointRanges(var AComparisonResult : Boolean) : Boolean;
      var
        lNode          : TNode;
        lRealDef     : TDef;
        lValue           : TConstExprInt;
      begin
        Result:=false;
        { check for comparison with known result because the ranges of the operands don't overlap }
        if (Is_ConstIntNode(Right) and (Left.ResultDef.typ=orddef) and
            { don't ignore type checks }
            Is_Subequal(Right.ResultDef,Left.ResultDef)) or
           (Is_ConstIntNode(Left) and (Right.ResultDef.typ=orddef) and
            { don't ignore type checks }
            Is_Subequal(Left.ResultDef,Right.ResultDef)) then
           begin
             if Is_ConstIntNode(Right) then
               begin
                 lNode:=Left;
                 lValue:=TOrdConstNode(Right).Value;
               end
             else
               begin
                 lNode:=Right;
                 lValue:=TOrdConstNode(Left).Value;
               end;

             lRealDef:=lNode.ResultDef;
             { stop with finding the real def when we either encounter
                a) an explicit type conversion (then the value has to be
                   re-interpreted)
                b) an "absolute" type conversion (also requires
                   re-interpretation)
             }
             while (lNode.NodeType=typeconvn) and
                   ([nf_internal,nf_explicit,nf_absolute] * lNode.Flags = []) do
               begin
                 lNode:=TTypeConvNode(lNode).Left;
                 lRealDef:=lNode.ResultDef;
               end;
             { could become an errordef in case of errors }
             if lRealDef.typ<>orddef then
               exit;
             if Is_ConstIntNode(Left) then
               with TOrdDef(lRealDef) do
                 case NodeType of
                  ltn:
                    if lValue<low then
                      begin
                        Result:=true;
                        AComparisonResult:=true;
                      end
                    else if lValue>=high then
                      begin
                        Result:=true;
                        AComparisonResult:=false;
                      end;
                  lten:
                    if lValue<=low then
                      begin
                        Result:=true;
                        AComparisonResult:=true;
                      end
                    else if lValue>high then
                      begin
                        Result:=true;
                        AComparisonResult:=false;
                      end;
                  gtn:
                    if lValue<=low then
                      begin
                        Result:=true;
                        AComparisonResult:=false;
                      end
                    else if lValue>high then
                      begin
                        Result:=true;
                        AComparisonResult:=true;
                      end;
                  gten :
                    if lValue<low then
                      begin
                        Result:=true;
                        AComparisonResult:=false;
                      end
                    else if lValue>=high then
                      begin
                        Result:=true;
                        AComparisonResult:=true;
                      end;
                  EqualN:
                    if (lValue<low) or (lValue>high) then
                      begin
                        Result:=true;
                        AComparisonResult:=false;
                      end;
                  unequaln:
                    if (lValue<low) or (lValue>high) then
                      begin
                        Result:=true;
                        AComparisonResult:=true;
                      end;
                  else
                    ;
                 end
             else
               with TOrdDef(lRealDef) do
                 case NodeType of
                  ltn:
                    if high<lValue then
                      begin
                        Result:=true;
                        AComparisonResult:=true;
                      end
                    else if low>=lValue then
                      begin
                        Result:=true;
                        AComparisonResult:=false;
                      end;
                  lten:
                    if high<=lValue then
                      begin
                        Result:=true;
                        AComparisonResult:=true;
                      end
                    else if low>lValue then
                      begin
                        Result:=true;
                        AComparisonResult:=false;
                      end;
                  gtn:
                    if high<=lValue then
                      begin
                        Result:=true;
                        AComparisonResult:=false;
                      end
                    else if low>lValue then
                      begin
                        Result:=true;
                        AComparisonResult:=true;
                      end;
                  gten:
                    if high<lValue then
                      begin
                        Result:=true;
                        AComparisonResult:=false;
                      end
                    else if low>=lValue then
                      begin
                        Result:=true;
                        AComparisonResult:=true;
                      end;
                  EqualN:
                    if (lValue<low) or (lValue>high) then
                      begin
                        Result:=true;
                        AComparisonResult:=false;
                      end;
                  unequaln:
                    if (lValue<low) or (lValue>high) then
                      begin
                        Result:=true;
                        AComparisonResult:=true;
                      end;
                  else
                    ;
                 end;
           end;
      end;


    function TAddNode.Simplify(AForInline : Boolean) : TNode;

      function IsRangeTest(ALeftNode, ARightNode: TAddNode; out AValue: TNode; var ALeftConstant,ARightConstant: TConstExprInt): Boolean;
        const
          cIsUpperTest: array[ltn..gten] of Boolean = (true,true,false,false);
          cInclusiveAdjust: array[Boolean,Boolean,ltn..gten] of Integer = (((-1,0,1,0),
                                                                            (1,0,-1,0)),
                                                                           ((0,-1,0,1),
                                                                            (0,1,0,-1)));
        var
          lSwapLeft, lSwapRight, lInvertedRange: Boolean;
          lRightValueNode: TNode;
          lTempValue: TConstExprInt;
        begin
          Result:=false;
          lSwapLeft:=false;
          lSwapRight:=false;

          if ALeftNode.Left.NodeType=ordconstn then
            begin
              lSwapLeft:=true;
              ALeftConstant:=TOrdConstNode(ALeftNode.Left).Value;
              AValue:=ALeftNode.Right;
            end
          else if ALeftNode.Right.NodeType=ordconstn then
            begin
              ALeftConstant:=TOrdConstNode(ALeftNode.Right).Value;
              AValue:=ALeftNode.Left;
            end
          else
            exit;

          if ARightNode.Left.NodeType=ordconstn then
            begin
              lSwapLeft:=true;
              ARightConstant:=TOrdConstNode(ARightNode.Left).Value;
              lRightValueNode:=ARightNode.Right;
            end
          else if ARightNode.Right.NodeType=ordconstn then
            begin
              ARightConstant:=TOrdConstNode(ARightNode.Right).Value;
              lRightValueNode:=ARightNode.Left;
            end
          else
            exit;

          if not AValue.IsEqual(lRightValueNode) then
            exit;

          { This is based on De Morgan's theorem, namely that
            "A and B" = "not ((not A) or (not B))" }
          lInvertedRange:=(NodeType=orn);
          if lInvertedRange then
            begin
              lSwapLeft:=not lSwapLeft;
              lSwapRight:=not lSwapRight;
            end;

          { this could be simplified too, but probably never happens }
          if (cIsUpperTest[ALeftNode.NodeType] xor lSwapLeft)=(cIsUpperTest[ARightNode.NodeType] xor lSwapRight) then
            exit;

          ALeftConstant:=ALeftConstant+cInclusiveAdjust[lInvertedRange,lSwapLeft,ALeftNode.NodeType];
          ARightConstant:=ARightConstant+cInclusiveAdjust[lInvertedRange,lSwapRight,ARightNode.NodeType];

          if cIsUpperTest[ALeftNode.NodeType] xor lSwapLeft then
            begin
              lTempValue:=ALeftConstant;
              ALeftConstant:=ARightConstant;
              ARightConstant:=lTempValue;
            end;

          if ALeftConstant>ARightConstant then
            exit;

          Result:=true;
        end;


      function TryHandleLengthZero(ALeft,ARight : TNode; ANodeType : TNodeType; var AResultNode : TNode) : Boolean;
        var
          lSwapNode : TNode;
        begin
          Result:=false;
          { Attempt to handle Length(S) = 0, <> 0, > 0, < 0, >= 0, <= 0. }
          if not (ANodeType in [EqualN,unequaln,ltn,lten,gtn,gten]) then
            exit;
          if not Is_InlineFunction(ALeft,in_length_x) then
            if Is_InlineFunction(ARight,in_length_x) then
              begin
                ANodeType:=cSwapRelation[ANodeType];
                lSwapNode:=ALeft;
                ALeft:=ARight;
                ARight:=lSwapNode;
              end
            else
              exit;
          if not Is_ConstIntValue(ARight,0) or Is_ShortString(TInlineNode(ALeft).Left.ResultDef) then
            exit;

          { Length = 0, <> 0, > 0, <= 0 are reduced to Length = 0. }
          if ANodeType in [EqualN,unequaln,gtn,lten] then
            begin
              { “pointer(L.left) = nil”. Steal L.left instead of getcopy, zero a bit later. }
              AResultNode:=CAddNode.Create_Internal(EqualN,CTypeConvNode.Create_Internal(TInlineNode(ALeft).Left,VoidPointerType),
                 CPointerConstNode.Create(0,VoidPointerType));

              { COM widestrings have 32-bit lengths, and can explicitly have 0 while being non-nil. }
              if Is_WideString(TInlineNode(ALeft).Left.ResultDef) and (tf_winlikewidestring in TargetInfo.Flags) then
                begin
                  { Expand to “(pointer(L.left) = nil) or (PUint32(L.left)[-1] = 0)”. }
                  AResultNode:=CAddNode.Create_Internal(orn,
                      AResultNode,
                      CAddNode.Create_Internal(EqualN,
                        CTypeConvNode.Create_Internal(
                          CDerefNode.Create(
                            CAddNode.Create_Internal(subn,CTypeConvNode.Create_Internal(TInlineNode(ALeft).Left.GetCopy,VoidPointerType),
                              COrdConstNode.Create(sizeof(uint32),PtrUIntType,false))
                          ),U32IntType
                        ),
                        COrdConstNode.Create(0,U32IntType,false))
                    );
                  include(TAddNode(AResultNode).AddNodeFlags,anf_short_bool);
                end;
              TInlineNode(ALeft).Left:=nil; { Was stolen inside resn, and no longer of interest. }

              { resn now checks for Length = 0. For Length <> 0, invert. }
              if ANodeType in [unequaln,gtn] then
                AResultNode:=CNotNode.Create(AResultNode);
              exit(true);
            end;

          { Warn on Length < 0 and Length >= 0. }
          if not (tnf_pass1_done in ALeft.TransientFlags) then { ...Only once. }
            if ANodeType=gten then
              Message(type_w_comparison_always_true)
            else
              Message(type_w_comparison_always_false);

          { Length < 0 is always false, Length >= 0 is always true. }
          if not Might_Have_SideEffects(TInlineNode(ALeft).Left) then { Could somehow remove the check but keep the F() even in Length(F()) >= 0... }
            begin
              AResultNode:=COrdConstNode.Create(ord(ANodeType=gten),ResultDef,true);
              exit(true);
            end;
        end;


      function GetCopyAndTypeCheck: TNode;
        begin
          Result:=GetCopy;
          Result.ResultDef:=nil;
          Result:=CTypeConvNode.Create_Internal(Result,ResultDef);
          DoTypeCheckPass(Result);
        end;


      function IsAndOrAndNot(ANode1,ANode2,ANode3,ANode4 : TNode): Boolean;
        begin
          Result:=(ANode4.NodeType=notn) and
            TNotNode(ANode4).Left.IsEqual(ANode2);
        end;


      function TransformAndOrAndNot(ANode1,ANode2,ANode3,ANode4 : TNode): TNode;
        begin
          Result:=CAddNode.Create_Internal(xorn,ANode3.GetCopy,
            CAddNode.Create_Internal(andn,CAddNode.Create_Internal(xorn,ANode3.GetCopy,ANode1.GetCopy),ANode2.GetCopy));
        end;


      function SwapRightWithLeftRight : TNode;
        var
          lNode : TNode;
        begin
          lNode:=Right;
          Right:=TAddNode(Left).Right;
          TAddNode(Left).Right:=lNode;
          Left:=Left.Simplify(AForInline);
          if ResultDef.typ<>pointerdef then
            begin
              { ensure that the constant is not expanded to a larger type due to overflow,
                but this is only useful if no pointer operation is done }
              Left:=CTypeConvNode.Create_Internal(Left,ResultDef);
              DoTypeCheckPass(Left);
            end;
          Result:=GetCopyAndTypeCheck;
        end;


      function SwapRightWithLeftLeft : TNode;
        var
          lNode,lNode2 : TNode;
        begin
          { keep the order of val+const else pointer and string operations might cause an error }
          lNode:=TAddNode(Left).Left;
          TAddNode(Left).Left:=TAddNode(Left).Right;
          TAddNode(Left).Right:=Right;
          Left.ResultDef:=nil;
          DoTypeCheckPass(Left);
          lNode2:=Left.Simplify(AForInline);
          if Assigned(lNode2) then
            Left:=lNode2;
          if ResultDef.typ<>pointerdef then
            begin
              { ensure that the constant is not expanded to a larger type due to overflow,
                but this is only useful if no pointer operation is done }
              Left:=CTypeConvNode.Create_Internal(Left,ResultDef);
              DoTypeCheckPass(Left);
            end
          else if TPointerDef(ResultDef).PointedDef.Size>1 then
          { the constants were already multiplied by the pointer element size }
            Left:=CModDivNode.Create(divn,Left,COrdConstNode.Create(TPointerDef(ResultDef).PointedDef.Size,Left.ResultDef,false));
          Right:=Left;
          Left:=lNode;
          Result:=GetCopyAndTypeCheck;
        end;


      function SwapLeftWithRightRight : TNode;
        var
          lNode,lNode2 : TNode;
        begin
          { keep the order of val+const else string operations might cause an error }
          lNode:=TAddNode(Right).Right;

          TAddNode(Right).Right:=TAddNode(Right).Left;
          TAddNode(Right).Left:=Left;

          Right.ResultDef:=nil;
          DoTypeCheckPass(Right);
          lNode2:=Right.Simplify(AForInline);
          if Assigned(lNode2) then
            Right:=lNode2;
          if ResultDef.typ<>pointerdef then
            begin
              { ensure that the constant is not expanded to a larger type due to overflow,
                but this is only useful if no pointer operation is done }
              Right:=CTypeConvNode.Create_Internal(Right,ResultDef);
              DoTypeCheckPass(Right);
            end;
          Left:=Right;
          Right:=lNode;
          Result:=GetCopyAndTypeCheck;
        end;


      function SwapLeftWithRightLeft : TNode;
        var
          lNode: TNode;
        begin
          lNode:=Left;
          Left:=TAddNode(Right).Left;
          TAddNode(Right).Left:=lNode;
          Right:=Right.Simplify(false);
          Result:=GetCopyAndTypeCheck;
        end;


      function TryVariableShiftPair(ALeftInput, ARightInput: TNode; ABitSize: ASizeInt): Boolean;
        begin
          Result:=(ARightInput.NodeType=subn) and
            Is_ConstIntNode(TAddNode(ARightInput).Left) and
            (TOrdConstNode(TAddNode(ARightInput).Left).Value=ABitSize) and
            not Might_Have_SideEffects(ALeftInput) and
            TAddNode(ARightInput).Right.IsEqual(ALeftInput);
        end;


      function CheckRotateOptimization(AStandardOp, AReverseOp: TInlineNumber): TNode;
        var
          lBitSize: ASizeInt;
        begin
          Result:=nil;
          if Is_Integer(TShlShrNode(Left).Left.ResultDef) and
            { Avoid using custom integers due to the risk of unusual sizes and
              undesired effects in, say, bitpacked records. [Kit] }
            (TOrdDef(TShlShrNode(Left).Left.ResultDef).OrdType<>customint) and
            not Might_Have_SideEffects(TShlShrNode(Left).Left) and
            TShlShrNode(Left).Left.IsEqual(TShlShrNode(Right).Left) then
            begin
              lBitSize:=TShlShrNode(Left).Left.ResultDef.Size*8;

              { Check for constants first }
              if (
                  Is_ConstIntNode(TShlShrNode(Left).Right) and
                  (TOrdConstNode(TShlShrNode(Left).Right).Value>0) and
                  Is_ConstIntNode(TShlShrNode(Right).Right) and
                  (TOrdConstNode(TShlShrNode(Right).Right).Value>0) and
                  (TOrdConstNode(TShlShrNode(Right).Right).Value=lBitSize-TOrdConstNode(TShlShrNode(Left).Right).Value)
                ) or
                  { Try (X op1 Y) or (X op2 (S-Y)) for variable rotation}
                  TryVariableShiftPair(TShlShrNode(Left).Right, TShlShrNode(Right).Right, lBitSize) then
                begin
                  Result:=CInlineNode.Create(AStandardOp,false,
                    CCallParaNode.Create(TShlShrNode(Left).PruneKeepRight(),
                    CCallParaNode.Create(TShlShrNode(Left).PruneKeepLeft(),nil)));
                  Exit;
                end;

              { Try (X op1 (S-Y)) or (X op2 Y) for variable rotation }
              if TryVariableShiftPair(TShlShrNode(Right).Right, TShlShrNode(Left).Right, lBitSize) then
                begin
                  Result:=CInlineNode.Create(AReverseOp,false,
                    CCallParaNode.Create(TShlShrNode(Right).PruneKeepRight(),
                    CCallParaNode.Create(TShlShrNode(Right).PruneKeepLeft(),nil)));
                  Exit;
                end;
            end;
        end;


      var
        lAddNode: TAddNode;
        lResultNode,lLeftValueNode,lLeftTarget,lRightTarget,lValue1Conversion,lValue2Conversion: TNode;
        lLeftNodeType,lRightNodeType,lNewNodeType : TNodeType;
        lDef,
        lRightDef,lLeftDef   , lIntType: TDef;
        lRightValue,lLeftValue,lValue : TConstExprInt;
        lRightRealValue,lLeftRealValue : BestReal;
        lWideString1,lWideString2 : TCompilerWideString;
        lConcatStrings : Boolean;
        lChar1,lChar2   : array[0..1] of char;
        lString1,lString2,lTempString   : PChar;
        lLength1,lLength2   : LongInt;
        lResultSet : TConstSet;
        lComparisonResult,
        lValueInRange       : Boolean;
        lRightConstant, lLeftConstant  : TConstExprInt;
        lValue2Pointer, lConst2Pointer, lConst1Pointer, lValue1Pointer: PNode;
        lPointer1,lPointer2: TConstPtrUInt;
      begin
        Result:=DoCurrencyCorrections;
        if Assigned(Result) then
          Exit;

        lLength1:=0;
        lLength2:=0;
        lString1:=nil;
        lString2:=nil;

        { load easier access variables }
        lRightDef:=Right.ResultDef;
        lLeftDef:=Left.ResultDef;
        lRightNodeType:=Right.NodeType;
        lLeftNodeType:=Left.NodeType;

        if (NodeType = slashn) and
           (((lRightNodeType = ordconstn) and
             (TOrdConstNode(Right).Value = 0)) or
            ((lRightNodeType = realconstn) and
             (TRealConstNode(Right).ValueReal = 0.0))) then
          begin
            if Floating_Point_Range_Check_Error then
               begin
                 Result:=CRealConstNode.Create(1,PBestRealType^);
                 Message(parser_e_division_by_zero);
                 exit;
               end;
          end;

        { both are int constants }
        if  (
             Is_ConstIntNode(Left) and
             Is_ConstIntNode(Right)
            ) or
            (
             Is_ConstBoolNode(Left) and
             Is_ConstBoolNode(Right) and
             (NodeType in [slashn,ltn,lten,gtn,gten,EqualN,unequaln,andn,xorn,orn])
            ) or
            (
             Is_ConstEnumNode(Left) and
             Is_ConstEnumNode(Right) and
             (AllowEnumOp(NodeType) or (nf_internal in Flags))
            ) or
            (
             (lLeftNodeType in [pointerconstn,niln]) and
             Is_ConstIntNode(Right) and
             (NodeType in [addn,subn])
            ) or
            (
             (lRightNodeType in [pointerconstn,niln]) and
             Is_ConstIntNode(Left) and
             (NodeType=addn)
            ) or
            (
             (lLeftNodeType in [pointerconstn,niln]) and
             (lRightNodeType in [pointerconstn,niln]) and
             (NodeType in [ltn,lten,gtn,gten,EqualN,unequaln,subn])
            ) or
            (
             (lLeftNodeType = ordconstn) and (lLeftDef.typ = orddef) and Is_Currency(lLeftDef) and
             (lRightNodeType = ordconstn) and (lRightDef.typ = orddef) and Is_Currency(lRightDef)
            ) then
          begin
             lResultNode:=nil;

             { load values }
             lLeftValue:=Get_Int_Value(Left);
             lRightValue:=Get_Int_Value(Right);

             { Fix the currency scaling if, out of left and right, the
               nf_is_currency flag is set, but not for both }
             if (nf_is_currency in Left.Flags) and
               not (nf_is_currency in Right.Flags) then
               lRightValue:=lRightValue*10000
             else if (nf_is_currency in Right.Flags) and
               not (nf_is_currency in Left.Flags) then
               lLeftValue:=lLeftValue*10000;

             { type checking already took care of multiplying      }
             { integer constants with pointeddef.size if necessary }
             case NodeType of
               addn :
                 begin
                   lValue:=lLeftValue+lRightValue;
                   if lValue.overflow then
                     begin
                       Message(parser_e_arithmetic_operation_overflow);
                       { Recover }
                       lResultNode:=GenIntConstNode(0)
                     end
                   else if Is_ConstPointerNode(Left) or Is_ConstPointerNode(Right) then
                     lResultNode:=CPointerConstNode.Create(QWord(lValue),ResultDef)
                   else
                     begin
                       if Is_Integer(lLeftDef) then
                         lResultNode:=Create_Simplified_Ord_Const(lValue,ResultDef,AForInline,cs_check_overflow in LocalSwitches)
                       else
                         lResultNode:=COrdConstNode.Create(lValue,ResultDef,(lLeftDef.typ<>enumdef));
                     end;

                   if Is_Currency(ResultDef) then
                     Include(lResultNode.Flags,nf_is_currency);
                 end;
               subn :
                 begin
                   lValue:=lLeftValue-lRightValue;
                   if lValue.overflow then
                     begin
                       Message(parser_e_arithmetic_operation_overflow);
                       { Recover }
                       lResultNode:=GenIntConstNode(0)
                     end
                   else if (lLeftNodeType=pointerconstn) then
                     { pointer-pointer results in an integer }
                     if (lRightNodeType=pointerconstn) then
                       begin
                         if (cs_typed_addresses in CurrentSettings.LocalSwitches) and
                            (TPointerDef(lRightDef).PointedDef.Size>1) and
                            not(anf_has_pointerdiv in AddNodeFlags) then
                           InternalError(2008030101);
                         lResultNode:=CPointerConstNode.Create(QWord(lValue),ResultDef)
                       end
                     else
                       lResultNode:=CPointerConstNode.Create(QWord(lValue),ResultDef)
                   else
                     begin
                       if Is_Integer(lLeftDef) then
                         lResultNode:=Create_Simplified_Ord_Const(lValue,ResultDef,AForInline,cs_check_overflow in LocalSwitches)
                       else
                         lResultNode:=COrdConstNode.Create(lValue,ResultDef,(lLeftDef.typ<>enumdef));
                     end;

                   if Is_Currency(ResultDef) then
                     Include(lResultNode.Flags,nf_is_currency);
                 end;
               muln :
                 begin
                   lValue:=lLeftValue*lRightValue;
                   if lValue.overflow then
                     begin
                       message(parser_e_arithmetic_operation_overflow);
                       { Recover }
                       lResultNode:=GenIntConstNode(0)
                     end
                   else
                     begin
                       { If both are currency, we have to remove one of the
                         scalars}
                       if Is_Currency(ResultDef) then
                         begin
                           lValue:=lValue div 10000;

                           if not (nf_is_currency in Flags) then
                             { We have to remove both scalars in this case }
                             lValue:=lValue div 10000;
                         end;

                       lResultNode:=Create_Simplified_Ord_Const(lValue,ResultDef,AForInline,cs_check_overflow in LocalSwitches);

                       if Is_Currency(ResultDef) then
                         Include(lResultNode.Flags,nf_is_currency);
                     end;
                 end;
               xorn :
                 begin
                   if Is_Integer(lLeftDef) then
                     lResultNode:=Create_Simplified_Ord_Const(lLeftValue xor lRightValue,ResultDef,AForInline,false)
                   else
                     lResultNode:=COrdConstNode.Create(lLeftValue xor lRightValue,ResultDef,true);

                   if Is_Currency(ResultDef) then
                     Include(lResultNode.Flags,nf_is_currency);
                 end;
               orn :
                 begin
                   if Is_Integer(lLeftDef) then
                     lResultNode:=Create_Simplified_Ord_Const(lLeftValue or lRightValue,ResultDef,AForInline,false)
                   else
                     lResultNode:=COrdConstNode.Create(lLeftValue or lRightValue,ResultDef,true);

                   if Is_Currency(ResultDef) then
                     Include(lResultNode.Flags,nf_is_currency);
                 end;
               andn :
                 begin
                   if Is_Integer(lLeftDef) then
                     lResultNode:=Create_Simplified_Ord_Const(lLeftValue and lRightValue,ResultDef,AForInline,false)
                   else
                     lResultNode:=COrdConstNode.Create(lLeftValue and lRightValue,ResultDef,true);

                   if Is_Currency(ResultDef) then
                     Include(lResultNode.Flags,nf_is_currency);
                 end;
               ltn :
                 lResultNode:=COrdConstNode.Create(ord(lLeftValue<lRightValue),PasBool1Type,true);
               lten :
                 lResultNode:=COrdConstNode.Create(ord(lLeftValue<=lRightValue),PasBool1Type,true);
               gtn :
                 lResultNode:=COrdConstNode.Create(ord(lLeftValue>lRightValue),PasBool1Type,true);
               gten :
                 lResultNode:=COrdConstNode.Create(ord(lLeftValue>=lRightValue),PasBool1Type,true);
               EqualN :
                 lResultNode:=COrdConstNode.Create(ord(lLeftValue=lRightValue),PasBool1Type,true);
               unequaln :
                 lResultNode:=COrdConstNode.Create(ord(lLeftValue<>lRightValue),PasBool1Type,true);
               slashn :
                 begin
                   { int/int becomes a real }
                   lRightRealValue:=lRightValue;
                   lLeftRealValue:=lLeftValue;

                   { With currency, we may have to apply a scalar.  If both
                     are currency, the scalars cancel out and are not required }
                   if (nf_is_currency in Left.Flags) and
                     not (nf_is_currency in Right.Flags) then
                     lLeftRealValue:=lLeftRealValue/BestReal(10000.0)
                   else if (nf_is_currency in Right.Flags) and
                     not (nf_is_currency in Left.Flags) then
                     lRightRealValue:=lRightRealValue/BestReal(10000.0);

                   lResultNode:=CRealConstNode.Create(lLeftRealValue/lRightRealValue,ResultRealDef);
                 end;
               else
                 InternalError(2008022101);
             end;
             Result:=lResultNode;
             exit;
          end
        else if CompareDisjointRanges(lComparisonResult) then
          begin
            if lComparisonResult then
              lResultNode:=COrdConstNode.Create(1,PasBool1Type,true)
            else
              lResultNode:=COrdConstNode.Create(0,PasBool1Type,true);
            { don't do this optimization, if the variable expression might
              have a side effect }
            if (Is_ConstIntNode(Left) and Might_Have_SideEffects(Right)) or
              (Is_ConstIntNode(Right) and Might_Have_SideEffects(Left)) then
              lResultNode.free // no nil needed
            else
              Result:=lResultNode;
            exit;
          end;

        { For operations that follow the commutative law, put integer constants on the right }
        if (NodeType in [addn,orn,xorn,andn,muln]) and
          Is_ConstIntNode(Left) and (Is_Integer(Right.ResultDef) or Is_Pointer(Right.ResultDef)) then
          SwapLeftRight;

        { Add,Sub,Mul,Or,Xor,Andn with constant 0, 1 or -1?  }
        if Is_ConstIntNode(Right) and (Is_Integer(lLeftDef) or Is_Pointer(lLeftDef)) then
          begin
            if (TOrdConstNode(Right).Value = 0) and (NodeType in [addn,subn,orn,xorn,andn,muln]) then
              begin
                case NodeType of
                  addn,subn,orn,xorn:
                    Result := PruneKeepLeft();
                  andn,muln:
                    begin
                      if (cs_opt_level4 in CurrentSettings.OptimizerSwitches) or
                         not Might_Have_SideEffects(Left) then
                        Result:=COrdConstNode.Create(0,ResultDef,true);
                    end
                  else
                    ;
                end;
              end

            else if (TOrdConstNode(Right).Value = 1) and (NodeType=muln) then
              { insert type conversion in case it is a 32*32 to 64 bit multiplication optimization,
                the type conversion does not hurt because it is normally removed later on
              }
              Result := CTypeConvNode.Create_Internal(PruneKeepLeft(),ResultDef)

            { try to fold
                          op                         op
                         /  \                       /  \
                       op  const1       or        op  const1
                      /  \                       /  \
                  const2 val                   val const2
            }
            else if (Left.NodeType=NodeType) and
              { there might be a mul operation e.g. longint*longint => int64 in this case
                we cannot do this optimization, see e.g. tests/tbs/tw36587.pas on arm }
              (Compare_Defs(ResultDef,lLeftDef,nothingn)=te_exact) then
              begin
                if Is_ConstIntNode(TAddNode(Left).Left) then
                  begin
                    case Left.NodeType of
                      xorn,
                      addn,
                      andn,
                      orn,
                      muln:
                        Result:=SwapRightWithLeftRight;
                      else
                        ;
                    end;
                  end
                else if Is_ConstIntNode(TAddNode(Left).Right) then
                  begin
                    case Left.NodeType of
                      xorn,
                      addn,
                      andn,
                      orn,
                      muln:
                        Result:=SwapRightWithLeftLeft;
                      else
                        ;
                    end;
                  end
              end;

            if Assigned(Result) then
              exit;

            { multiplication by -1? Convert it into an unary minus if the other conversions before failed, don't do
              it before the folding above, see #40448 }
            if (TOrdConstNode(Right).Value = -1) and (NodeType=muln) then
              Result := CTypeConvNode.Create_Internal(CUnaryMinusNode.Create(PruneKeepLeft()),lLeftDef);

            if Assigned(Result) then
              exit;
          end;

        { Deal with anti-commutative subtraction }
        if (NodeType = subn) then
          begin
            { transform -1-x into not(x) }
            if Is_Signed(lRightDef) and Is_ConstIntNode(Left) and (TOrdConstNode(Left).Value=-1)  then
              begin
                Result:=CNotNode.Create(Right.GetCopy);
                exit;
              end

            { change "0 - val" to "-val" }
            else if Is_ConstIntNode(Left) and (Is_Integer(Right.ResultDef) or Is_Pointer(Right.ResultDef)) then
              begin
                if (TOrdConstNode(Left).Value = 0) then
                  Result := CTypeConvNode.Create_Internal(CUnaryMinusNode.Create(Right.GetCopy),Right.ResultDef);
              end

            { change "nil - val" to "-val" }
            else if (Left.NodeType=niln) and Is_Pointer(Right.ResultDef) then
              Result := CTypeConvNode.Create_Internal(CUnaryMinusNode.Create(CTypeConvNode.Create_Internal(Right.GetCopy,ResultDef)),ResultDef)

            { convert n - n mod const into n div const*const }
            else if (Right.NodeType=modn) and Is_ConstIntNode(TModDivNode(Right).Right) and
              (Left.IsEqual(TModDivNode(Right).Left)) and not(Might_Have_SideEffects(Left)) { and
	      not(cs_check_overflow in localswitches) } then
              begin
                Result:=CAddNode.Create(muln,CModDivNode.Create(divn,Left,TModDivNode(Right).Right.GetCopy),TModDivNode(Right).Right);
                Left:=nil;
                TModDivNode(Right).Right:=nil;
                exit;
              end

            { transform -x-1 into not(x) }
            else if Is_Signed(lLeftDef) and Is_ConstIntNode(Right) and (TOrdConstNode(Right).Value=1) and (Left.NodeType=unaryminusn) then
              begin
                Result:=CNotNode.Create(TUnaryMinusNode(Left).Left.GetCopy);
                exit;
              end;
          end;

      { both real constants ? }
        if (lLeftNodeType=realconstn) and (lRightNodeType=realconstn) then
          begin
             lLeftRealValue:=TRealConstNode(Left).ValueReal;
             lRightRealValue:=TRealConstNode(Right).ValueReal;
             case NodeType of
                addn :
                  begin
                    lResultNode:=CRealConstNode.Create(lLeftRealValue+lRightRealValue,ResultRealDef);
                    if nf_is_currency in Flags then
                      include(lResultNode.Flags,nf_is_currency);
                  end;
                subn :
                  begin
                    lResultNode:=CRealConstNode.Create(lLeftRealValue-lRightRealValue,ResultRealDef);
                    if nf_is_currency in Flags then
                      include(lResultNode.Flags,nf_is_currency);
                  end;
                muln :
                  begin
                    if (nf_is_currency in Flags) then
                      begin
                        if (nf_is_currency in Left.Flags) and
                          (nf_is_currency in Right.Flags) then
                          begin
                            { Need to remove one of the scalars }
                            lRightRealValue:=lRightRealValue/BestReal(10000.0);
                            if not (nf_is_currency in Flags) then
                              { Make that both }
                              lLeftRealValue:=lLeftRealValue/BestReal(10000.0);
                          end
                        else if not (nf_is_currency in Left.Flags) and
                          not (nf_is_currency in Right.Flags) then
                          begin
                            { We actually lack a scalar - try to scale
                              the smallest to minimise precision errors }
                            if (Abs(lRightRealValue) > Abs(lLeftRealValue)) then
                              lLeftRealValue:=lLeftRealValue*BestReal(10000.0)
                            else
                              lRightRealValue:=lRightRealValue*BestReal(10000.0);
                          end;
                      end
                    else
                      begin
                        { Clear any scalars }
                        if (nf_is_currency in Left.Flags) then
                          lLeftRealValue:=lLeftRealValue/BestReal(10000.0);
                        if (nf_is_currency in Right.Flags) then
                          lRightRealValue:=lRightRealValue/BestReal(10000.0);
                      end;

                    lResultNode:=CRealConstNode.Create(lLeftRealValue*lRightRealValue,ResultRealDef);
                    if nf_is_currency in Flags then
                      include(lResultNode.Flags,nf_is_currency);
                  end;
                starstarn:
                  begin
                    if lLeftRealValue<0 then
                     begin
                       Message(parser_e_invalid_float_operation);
                       lResultNode:=CRealConstNode.Create(0,ResultRealDef);
                     end
                    else if lLeftRealValue=0 then
                      lResultNode:=CRealConstNode.Create(1.0,ResultRealDef)
                    else
                      lResultNode:=CRealConstNode.Create(Exp(Ln(lLeftRealValue)*lRightRealValue),ResultRealDef);
                  end;
                slashn :
                  begin
                    if (nf_is_currency in Flags) and
                      (nf_is_currency in Left.Flags) and
                      (nf_is_currency in Right.Flags) then
                      begin
                        { Need to put one of the scalars back }
                        lResultNode:=CRealConstNode.Create((lLeftRealValue/lRightRealValue)*BestReal(10000.0),ResultRealDef);
                        Include(lResultNode.Flags,nf_is_currency);
                      end
                    else
                      begin
                        lResultNode:=CRealConstNode.Create(lLeftRealValue/lRightRealValue,ResultRealDef);

                        if (nf_is_currency in Left.Flags) and
                          not (nf_is_currency in Right.Flags) then
                          include(lResultNode.Flags,nf_is_currency);
                      end;
                  end;
                ltn :
                  lResultNode:=COrdConstNode.Create(ord(lLeftRealValue<lRightRealValue),PasBool1Type,true);
                lten :
                  lResultNode:=COrdConstNode.Create(ord(lLeftRealValue<=lRightRealValue),PasBool1Type,true);
                gtn :
                  lResultNode:=COrdConstNode.Create(ord(lLeftRealValue>lRightRealValue),PasBool1Type,true);
                gten :
                  lResultNode:=COrdConstNode.Create(ord(lLeftRealValue>=lRightRealValue),PasBool1Type,true);
                EqualN :
                  lResultNode:=COrdConstNode.Create(ord(lLeftRealValue=lRightRealValue),PasBool1Type,true);
                unequaln :
                  lResultNode:=COrdConstNode.Create(ord(lLeftRealValue<>lRightRealValue),PasBool1Type,true);
                else
                  InternalError(2008022102);
             end;
             Result:=lResultNode;
             exit;
          end;

        if Is_Real(ResultDef) then
          begin
            if (NodeType=addn) then
              begin
                { -left+right => right-left,
                  this operation is always valid }
                if (Left.NodeType=unaryminusn) then
                  begin
                    lResultNode := TUnaryMinusNode(Left).PruneKeepLeft();
                    Result:=CAddNode.Create(subn,PruneKeepRight(),lResultNode);
                    exit;
                  end;

                { left+(-right) => left-right,
                  this operation is always valid }
                if (Right.NodeType=unaryminusn) then
                  begin
                    lResultNode := TUnaryMinusNode(Right).PruneKeepLeft();
                    Result:=CAddNode.Create(subn,PruneKeepLeft(),lResultNode);
                    exit;
                  end;
              end;

            { left-(-right) => left+right,
              this operation is always valid }
            if (NodeType=subn) and (Right.NodeType=unaryminusn) then
              begin
                lResultNode := TUnaryMinusNode(Right).PruneKeepLeft();
                Result:=CAddNode.Create(addn,PruneKeepLeft(),lResultNode);
                exit;
              end;

            { (-left)*(-right) => left*right, and
              (-left)/(-right) => left/right,
              these operations are always valid }
            if (NodeType in [muln,slashn]) and (Left.NodeType=unaryminusn) and (Right.NodeType=unaryminusn) then
              begin
                lResultNode := TUnaryMinusNode(Right).PruneKeepLeft();
                Result:=CAddNode.Create(NodeType,TUnaryMinusNode(Left).PruneKeepLeft(),lResultNode);
                exit;
              end;

            { optimize operations with real constants, but only if fast math is switched on as
              the operations could change e.g. the sign of 0 so they cannot be optimized always
            }
            if Is_Real(ResultDef) then
              begin
                if lLeftNodeType=realconstn then
                  begin
                    if (TRealConstNode(Left).ValueReal=0) and (NodeType in [addn,muln,subn,slashn]) then
                      begin
                        case NodeType of
                          addn:
                            begin
                              { -0.0+(+0.0)=+0.0 so we cannot carry out this optimization if no fastmath is passed }
                              if not(cs_opt_fastmath in CurrentSettings.OptimizerSwitches) then
                                begin
                                  Result:=PruneKeepRight();
                                  exit;
                                end;
                            end;
                          slashn,
                          muln:
                            if not(Might_Have_SideEffects(Right,[mhs_exceptions])) then
                              begin
                                Result:=PruneKeepLeft;
                                exit;
                              end;
                          subn:
                            begin
                              lResultNode := PruneKeepRight();
                              Result:=CTypeConvNode.Create_Internal(CUnaryMinusNode.Create(lResultNode),lRightDef);
                              exit;
                            end;
                          else
                            InternalError(2020060801);
                        end;
                      end
                    else if (TRealConstNode(Left).ValueReal=1) and (NodeType=muln) then
                      begin
                        Result:=Right.GetCopy;
                        exit;
                      end
                    else if (TRealConstNode(Left).ValueReal=2) and (NodeType=muln) and not(Might_Have_SideEffects(Right,[mhs_exceptions])) and
                      (Node_Complexity(Right)<=1) then
                      begin
                        Result:=CAddNode.Create_Internal(addn,Right.GetCopy,Right.GetCopy);
                        exit;
                      end;
                  end
                else if lRightNodeType=realconstn then
                  begin
                    if (TRealConstNode(Right).ValueReal=0) and (NodeType in [addn,muln,subn]) then
                      begin
                        case NodeType of
                          subn,
                          addn:
                            begin
                              Result:=Left.GetCopy;
                              exit;
                            end;
                          muln:
                            if not(Might_Have_SideEffects(Left,[mhs_exceptions])) then
                              begin
                                Result:=Right.GetCopy;
                                exit;
                              end;
                          else
                            InternalError(2020060802);
                        end;
                      end
                    else if (TRealConstNode(Right).ValueReal=1) and (NodeType in [muln,slashn]) then
                      begin
                        Result:=Left.GetCopy;
                        exit;
                      end
                    else if (TRealConstNode(Right).ValueReal=2) and (NodeType=muln) and not(Might_Have_SideEffects(Left,[mhs_exceptions])) and
                      (Node_Complexity(Left)<=1) then
                      begin
                        Result:=CAddNode.Create_Internal(addn,Left.GetCopy,Left.GetCopy);
                        exit;
                      end;
                  end
                { optimize a/a and a-a }
                else if ((NodeType in [subn,slashn]) and ([cs_opt_fastmath,cs_opt_level2]*CurrentSettings.OptimizerSwitches=[cs_opt_fastmath,cs_opt_level2])) and
                  Left.IsEqual(Right) and not(Might_Have_SideEffects(Left,[mhs_exceptions])) then
                  begin
                    case NodeType of
                      subn:
                        Result:=CRealConstNode.Create(0,lLeftDef);
                      slashn:
                        Result:=CRealConstNode.Create(1,lLeftDef);
                      else
                        InternalError(2020060901);
                    end;
                  end;
              end;
          end;

        { replace .../const by a multiplication, but only if fastmath is enabled or
          the division is done by a power of 2, do not mess with special floating point values like Inf etc.

          do this after constant folding to avoid unnecessary precision loss if
          an slash expresion would be first converted into a multiplication and later
          folded }
        if (NodeType=slashn) and
          { do not mess with currency and comp types }
          (not(Is_Currency(lRightDef)) and
           not((lRightDef.typ=floatdef) and
               (TFloatDef(lRightDef).FloatType=s64comp)
              )
          ) and
          (((cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (lRightNodeType=ordconstn)) or
           ((cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (lRightNodeType=realconstn) and
            (Is_Number_Float(TRealConstNode(Right).ValueReal) and (TRealConstNode(Right).ValueReal<>0))
           ) or
           ((lRightNodeType=realconstn) and
            (Is_Number_Float(TRealConstNode(Right).ValueReal) and (TRealConstNode(Right).ValueReal<>0)) and
            (BestRealRec(TRealConstNode(Right).ValueReal).Mantissa(True)=BestRealHiddenBit)
           )
          ) then
          case lRightNodeType of
            ordconstn:
              begin
                { the normal code handles div/0 }
                if (TOrdConstNode(Right).Value<>0) then
                  begin
                    NodeType:=muln;
                    lResultNode:=CRealConstNode.Create(1/TOrdConstNode(Right).Value,ResultDef);
                    Right.free;
                    Right:=lResultNode;
                    exit;
                  end;
              end;
            realconstn:
              begin
                NodeType:=muln;
                TRealConstNode(Right).ValueReal:=1.0/TRealConstNode(Right).ValueReal;
                exit;
              end;
            else
              ;
          end;
        { first, we handle widestrings, so we can check later for }
        { stringconstn only                                       }

        { widechars are converted above to widestrings too }
        { this isn't ver y efficient, but I don't think    }
        { that it does matter that much (FK)               }
        if (lLeftNodeType=stringconstn) and (lRightNodeType=stringconstn) and
          (TStringConstNode(Left).ConstStringType in [cst_widestring,cst_unicodestring]) and
          (TStringConstNode(Right).ConstStringType in [cst_widestring,cst_unicodestring]) then
          begin
             InitWideString(lWideString1);
             InitWideString(lWideString2);
             CopyWideString(TStringConstNode(Left).ValueWS,lWideString1);
             CopyWideString(TStringConstNode(Right).ValueWS,lWideString2);
             case NodeType of
                addn :
                  begin
                     ConcatWideStrings(lWideString1,lWideString2);
                     lResultNode:=CStringConstNode.CreateUniStr(lWideString1);
                  end;
                ltn :
                  lResultNode:=COrdConstNode.Create(Byte(CompareWideStrings(lWideString1,lWideString2)<0),PasBool1Type,true);
                lten :
                  lResultNode:=COrdConstNode.Create(Byte(CompareWideStrings(lWideString1,lWideString2)<=0),PasBool1Type,true);
                gtn :
                  lResultNode:=COrdConstNode.Create(Byte(CompareWideStrings(lWideString1,lWideString2)>0),PasBool1Type,true);
                gten :
                  lResultNode:=COrdConstNode.Create(Byte(CompareWideStrings(lWideString1,lWideString2)>=0),PasBool1Type,true);
                EqualN :
                  lResultNode:=COrdConstNode.Create(Byte(CompareWideStrings(lWideString1,lWideString2)=0),PasBool1Type,true);
                unequaln :
                  lResultNode:=COrdConstNode.Create(Byte(CompareWideStrings(lWideString1,lWideString2)<>0),PasBool1Type,true);
                else
                  InternalError(2008022103);
             end;
             DoneWideString(lWideString1);
             DoneWideString(lWideString2);
             Result:=lResultNode;
             exit;
          end;

        { concatenating strings ? }
        lConcatStrings:=false;

        if (lLeftNodeType=ordconstn) and (lRightNodeType=ordconstn) and
           Is_Char(lLeftDef) and Is_Char(lRightDef) then
          begin
             lChar1[0]:=char(Int64(TOrdConstNode(Left).Value));
             lChar1[1]:=#0;
             lLength1:=1;
             lChar2[0]:=char(Int64(TOrdConstNode(Right).Value));
             lChar2[1]:=#0;
             lLength2:=1;
             lString1:=@lChar1[0];
             lString2:=@lChar2[0];
             lConcatStrings:=true;
          end
        else if (lLeftNodeType=stringconstn) and (lRightNodeType=ordconstn) and Is_Char(lRightDef) then
          begin
             lLength1:=TStringConstNode(Left).len;
             lString1:=TStringConstNode(Left).AsConstPChar;
             lChar2[0]:=char(Int64(TOrdConstNode(Right).Value));
             lChar2[1]:=#0;
             lString2:=@lChar2[0];
             lLength2:=1;
             lConcatStrings:=true;
          end
        else if (lLeftNodeType=ordconstn) and (lRightNodeType=stringconstn) and Is_Char(lLeftDef) then
          begin
             lChar1[0]:=char(Int64(TOrdConstNode(Left).Value));
             lChar1[1]:=#0;
             lLength1:=1;
             lString1:=@lChar1[0];
             lString2:=TStringConstNode(Right).AsConstPChar;
             lLength2:=TStringConstNode(Right).len;
             lConcatStrings:=true;
          end
        else if (lLeftNodeType=stringconstn) and (lRightNodeType=stringconstn) then
          begin
             lString1:=TStringConstNode(Left).AsConstPChar;
             lLength1:=TStringConstNode(Left).len;
             lString2:=TStringConstNode(Right).AsConstPChar;
             lLength2:=TStringConstNode(Right).len;
             lConcatStrings:=true;
          end;
        if lConcatStrings then
          begin
             case NodeType of
                addn :
                  begin
                    lTempString:=ConcatAnsiStrings(lString1,lString2,lLength1,lLength2);
                    lResultNode:=CStringConstNode.CreatePChar(lTempString,lLength1+lLength2,nil);
                    FreeMem(lTempString);
                    TypeCheckPass(lResultNode);
                    if not Is_AnsiString(ResultDef) or
                       (TStringDef(ResultDef).encoding<>Globals.CP_NONE) then
                      TStringConstNode(lResultNode).ChangeStringType(ResultDef)
                    else
                      TStringConstNode(lResultNode).ChangeStringType(GetAnsiStringDef)
                  end;
                ltn :
                  lResultNode:=COrdConstNode.Create(Byte(CompareAnsiStrings(lString1,lString2,lLength1,lLength2)<0),PasBool1Type,true);
                lten :
                  lResultNode:=COrdConstNode.Create(Byte(CompareAnsiStrings(lString1,lString2,lLength1,lLength2)<=0),PasBool1Type,true);
                gtn :
                  lResultNode:=COrdConstNode.Create(Byte(CompareAnsiStrings(lString1,lString2,lLength1,lLength2)>0),PasBool1Type,true);
                gten :
                  lResultNode:=COrdConstNode.Create(Byte(CompareAnsiStrings(lString1,lString2,lLength1,lLength2)>=0),PasBool1Type,true);
                EqualN :
                  lResultNode:=COrdConstNode.Create(Byte(CompareAnsiStrings(lString1,lString2,lLength1,lLength2)=0),PasBool1Type,true);
                unequaln :
                  lResultNode:=COrdConstNode.Create(Byte(CompareAnsiStrings(lString1,lString2,lLength1,lLength2)<>0),PasBool1Type,true);
                else
                  InternalError(2008022104);
             end;
             Result:=lResultNode;
             exit;
          end;

        { set constant evaluation }
        if (Right.NodeType=setconstn) and
           not Assigned(TSetConstNode(Right).Left) and
           (Left.NodeType=setconstn) and
           not Assigned(TSetConstNode(Left).Left) then
          begin
             case NodeType of
               addn :
                 begin
                   lResultSet:=TSetConstNode(Right).ValueSet^ + TSetConstNode(Left).ValueSet^;
                   lResultNode:=CSetConstNode.Create(@lResultSet,ResultDef);
                 end;
                muln :
                  begin
                    lResultSet:=TSetConstNode(Right).ValueSet^ * TSetConstNode(Left).ValueSet^;
                    lResultNode:=CSetConstNode.Create(@lResultSet,ResultDef);
                  end;
               subn :
                  begin
                    lResultSet:=TSetConstNode(Left).ValueSet^ - TSetConstNode(Right).ValueSet^;
                            lResultNode:=CSetConstNode.Create(@lResultSet,ResultDef);
                  end;
               symdifn :
                  begin
                    lResultSet:=TSetConstNode(Right).ValueSet^ >< TSetConstNode(Left).ValueSet^;
                        lResultNode:=CSetConstNode.Create(@lResultSet,ResultDef);
                  end;
               unequaln :
                  begin
                    lValueInRange:=TSetConstNode(Right).ValueSet^ <> TSetConstNode(Left).ValueSet^;
                    lResultNode:=COrdConstNode.Create(Byte(lValueInRange),PasBool1Type,true);
                  end;
               EqualN :
                  begin
                    lValueInRange:=TSetConstNode(Right).ValueSet^ = TSetConstNode(Left).ValueSet^;
                    lResultNode:=COrdConstNode.Create(Byte(lValueInRange),PasBool1Type,true);
                  end;
               lten :
                  begin
                    lValueInRange:=TSetConstNode(Left).ValueSet^ <= TSetConstNode(Right).ValueSet^;
                    lResultNode:=COrdConstNode.Create(Byte(lValueInRange),PasBool1Type,true);
                  end;
               gten :
                  begin
                    lValueInRange:=TSetConstNode(Left).ValueSet^ >= TSetConstNode(Right).ValueSet^;
                    lResultNode:=COrdConstNode.Create(Byte(lValueInRange),PasBool1Type,true);
                  end;
                else
                  InternalError(2008022105);
             end;
             Result:=lResultNode;
             exit;
          end;

        { in case of expressions having no side effect, we can simplify boolean expressions
          containing constants }
        if Is_Boolean(lLeftDef) and Is_Boolean(lRightDef) then
          begin
            if Is_ConstBoolNode(Left) then
              begin
                if ((NodeType=andn) and (TOrdConstNode(Left).Value<>0)) or
                  ((NodeType=orn) and (TOrdConstNode(Left).Value=0)) or
                  ((NodeType=xorn) and (TOrdConstNode(Left).Value=0)) then
                  begin
                    Result := PruneKeepRight();
                    exit;
                  end
                else if not(Might_Have_SideEffects(Right)) and
                  (((NodeType=orn) and (TOrdConstNode(Left).Value<>0)) or
                  ((NodeType=andn) and (TOrdConstNode(Left).Value=0))) then
                  begin
                    Result := PruneKeepLeft();
                    exit;
                  end
                else if ((NodeType=xorn) and (TOrdConstNode(Left).Value<>0)) then
                  begin
                    Result := CNotNode.Create(PruneKeepRight());
                    exit;
                  end
              end
            else if Is_ConstBoolNode(Right) then
              begin
                if ((NodeType=andn) and (TOrdConstNode(Right).Value<>0)) or
                  ((NodeType=orn) and (TOrdConstNode(Right).Value=0)) or
                  ((NodeType=xorn) and (TOrdConstNode(Right).Value=0)) then
                  begin
                    Result := PruneKeepLeft();
                    exit;
                  end
                else if not(Might_Have_SideEffects(Left)) and
                  (((NodeType=orn) and (TOrdConstNode(Right).Value<>0)) or
                   ((NodeType=andn) and (TOrdConstNode(Right).Value=0))) then
                  begin
                    Result := PruneKeepRight();
                    exit;
                  end
                else if ((NodeType=xorn) and (TOrdConstNode(Right).Value<>0)) then
                  begin
                    Result := CNotNode.Create(PruneKeepLeft());
                    exit;
                  end
              end;
          end;

        { optimize @<proc>=/<>@<proc>,
          such code might appear in generic specializations }
        if (NodeType in [EqualN,unequaln]) and
          (Left.NodeType=typeconvn) and (Is_VoidPointer(Left.ResultDef)) and (TTypeConvNode(Left).Left.NodeType=typeconvn) and
          (TTypeConvNode(TTypeConvNode(Left).Left).ConvType=tc_proc_2_procvar) and
          (TTypeConvNode(TTypeConvNode(Left).Left).Left.NodeType=loadn) and
          (TTypeConvNode(TTypeConvNode(Left).Left).Left.ResultDef.typ=procdef) and
          Left.IsEqual(Right) then
          begin
            Result:=COrdConstNode.Create(ord(NodeType=EqualN),ResultDef,false);
            exit;
          end;

        { check if
           typeinfo(<type1>)=/<>typeinfo(<type2>)
          can be evaluated at compile time
        }
        lLeftTarget:=ActualTargetNode(@Left)^;
        lRightTarget:=ActualTargetNode(@Right)^;
        if (NodeType in [EqualN,unequaln]) and (lLeftTarget.NodeType=inlinen) and (lRightTarget.NodeType=inlinen) and
          (TInlineNode(lLeftTarget).InlineNumber=in_typeinfo_x) and (TInlineNode(lRightTarget).InlineNumber=in_typeinfo_x) and
          not (TInlineNode(lLeftTarget).Left.ResultDef.typ in [undefineddef,errordef]) and
          not (TInlineNode(lRightTarget).Left.ResultDef.typ in [undefineddef,errordef]) then
          begin
            case NodeType of
              EqualN:
                Result:=COrdConstNode.Create(ord(TInlineNode(lLeftTarget).Left.ResultDef=TInlineNode(lRightTarget).Left.ResultDef),ResultDef,false);
              unequaln:
                Result:=COrdConstNode.Create(ord(TInlineNode(lLeftTarget).Left.ResultDef<>TInlineNode(lRightTarget).Left.ResultDef),ResultDef,false);
              else
                InternalError(2020092901);
            end;
            exit;
          end;

        if Is_ConstPointerNode(Left) and Is_ConstPointerNode(Right) then
          begin
            lPointer1:=0;
            lPointer2:=0;
            if Left.NodeType=pointerconstn then
              lPointer1:=TPointerConstNode(Left).Value;
            if Right.NodeType=pointerconstn then
              lPointer2:=TPointerConstNode(Right).Value;
            case NodeType of
              EqualN:
                Result:=COrdConstNode.Create(ord(lPointer1=lPointer2),Bool8Type,false);
              unequaln:
                Result:=COrdConstNode.Create(ord(lPointer1<>lPointer2),Bool8Type,false);
              gtn:
                Result:=COrdConstNode.Create(ord(lPointer1>lPointer2),Bool8Type,false);
              ltn:
                Result:=COrdConstNode.Create(ord(lPointer1<lPointer2),Bool8Type,false);
              gten:
                Result:=COrdConstNode.Create(ord(lPointer1>=lPointer2),Bool8Type,false);
              lten:
                Result:=COrdConstNode.Create(ord(lPointer1<=lPointer2),Bool8Type,false);
              else
                InternalError(2020100101);
            end;
            exit;
          end;

        { slow simplifications and/or more sophisticated transformations which might make debugging harder }
        if cs_opt_level2 in CurrentSettings.OptimizerSwitches then
          begin
            if NodeType in [addn,muln,subn] then
              begin
                { convert a+const1-const2 into a+const1+(-const2) so it is folded later on }
                if (Left.NodeType=addn) and
                  (NodeType=subn) and
                  (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (lRightNodeType=realconstn) and (TAddNode(Left).Right.NodeType=realconstn) and
                  (Compare_Defs(ResultDef,lLeftDef,nothingn)=te_exact) then
                  begin
                    Result:=GetCopy;
                    Result.NodeType:=addn;
                    TAddNode(Result).Right:=CUnaryMinusNode.Create(TAddNode(Result).Right);
                    exit;
                  end;

                { convert a-const1+const2 into a+(-const1)+const2 so it is folded later on }
                if (Left.NodeType=subn) and
                  (NodeType=addn) and
                  (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (lRightNodeType=realconstn) and (TAddNode(Left).Right.NodeType=realconstn) and
                  (Compare_Defs(ResultDef,lLeftDef,nothingn)=te_exact) then
                  begin
                    Result:=GetCopy;
                    TAddNode(Result).Left.NodeType:=addn;
                    TAddNode(TAddNode(Result).Left).Right:=CUnaryMinusNode.Create(TAddNode(TAddNode(Result).Left).Right);
                    exit;
                  end;

                { try to fold
                            op
                           /  \
                         op  const1
                        /  \
                      val const2

                  while operating on strings or reals
                }
                if (Left.NodeType=NodeType) and
                  (((NodeType=addn) and ((lRightNodeType=stringconstn) or Is_ConstCharNode(Right)) and ((TAddNode(Left).Right.NodeType=stringconstn) or Is_ConstCharNode(TAddNode(Left).Right))) or
                   ((NodeType in [addn,muln,subn]) and (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (lRightNodeType=realconstn) and (TAddNode(Left).Right.NodeType=realconstn))
                  ) and
                  (Compare_Defs(ResultDef,lLeftDef,nothingn)=te_exact) then
                  begin
                    { SwapRightWithLeftLeft moves the nodes around in way that we need to insert a minus
                      on left.right: a-b-c becomes b-c-a so we
                      need
                      1) insert a minus before b
                      2) make the current node an add node, see below
                    }
                    if NodeType=subn then
                      begin
                        TAddNode(Left).Right:=CUnaryMinusNode.Create(TAddNode(Left).Right);
                        DoTypeCheckPass(TAddNode(Left).Right);
                      end;
                    Result:=SwapRightWithLeftLeft;
                    if NodeType=subn then
                      begin
                        Result.NodeType:=addn;
                        DoTypeCheckPass(Result);
                      end;
                    exit;
                  end;

                { try to fold
                              op
                             /  \
                         const1  op
                                /  \
                            const2 val

                  while operating on strings or reals
                }
                if (Right.NodeType=NodeType) and
                  (((NodeType=addn) and ((lLeftNodeType=stringconstn) or Is_ConstCharNode(Left)) and ((TAddNode(Right).Left.NodeType=stringconstn) or Is_ConstCharNode(TAddNode(Right).Left))) or
                   ((NodeType in [addn,muln]) and (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (lLeftNodeType=realconstn) and (TAddNode(Right).Left.NodeType=realconstn))
                  ) and
                  (Compare_Defs(ResultDef,lRightDef,nothingn)=te_exact) then
                  begin
                    Result:=SwapLeftWithRightRight;
                    exit;
                  end;

                {
                  reorder string expressions with parentheses:
                  (s1+(s2+(s3+s4...))) into s1+s2+s3+s4 ...
                  so fpc_*_concat_multi can be used efficiently
                }
                lAddNode:=Self;
                while (lAddNode.Right.NodeType=lAddNode.NodeType) and (lAddNode.ResultDef.typ=stringdef) and
                  (Compare_Defs(lAddNode.ResultDef,lAddNode.Right.ResultDef,nothingn)=te_exact) and
                  (Compare_Defs(lAddNode.ResultDef,lAddNode.Left.ResultDef,nothingn)=te_exact) and
                  (Compare_Defs(lAddNode.ResultDef,TAddNode(lAddNode.Right).Left.ResultDef,nothingn)=te_exact) and
                  (Compare_Defs(lAddNode.ResultDef,TAddNode(lAddNode.Right).Right.ResultDef,nothingn)=te_exact) do
                  begin
                    lResultNode:=lAddNode.Left;
                    lAddNode.Left:=lAddNode.Right;
                    lAddNode.Right:=TAddNode(lAddNode.Left).Right;
                    TAddNode(lAddNode.Left).Right:=TAddNode(lAddNode.Left).Left;
                    TAddNode(lAddNode.Left).Left:=lResultNode;
                    lAddNode:=TAddNode(lAddNode.Left);
                  end;
              end;

            { the comparison is might be expensive and the nodes are usually only
              equal if some previous optimizations were done so don't check
              this simplification always
            }
            if Is_Boolean(lLeftDef) and Is_Boolean(lRightDef) then
              begin
                { transform unsigned comparisons of (v>=x) and (v<=y)
                  into (v-x)<=(y-x)
                }
                if (NodeType in [andn,orn]) and
                   (Left.NodeType in [ltn,lten,gtn,gten]) and
                   (Right.NodeType in [ltn,lten,gtn,gten]) and
                   (not Might_Have_SideEffects(Left)) and
                   (not Might_Have_SideEffects(Right)) and
                   IsRangeTest(TAddNode(Left),TAddNode(Right),lLeftValueNode,lLeftConstant,lRightConstant) and
                   { avoid optimization being applied to (<string. var > charconst1) and (<string. var < charconst2) }
                   (lLeftValueNode.ResultDef.typ in [orddef,enumdef]) then
                  begin
                    lDef:=Get_Unsigned_IntType(lLeftValueNode.ResultDef);
                    lLeftValueNode:=CTypeConvNode.Create_Internal(lLeftValueNode.GetCopy,lDef);

                    { If the condition is of the inverted form (v<x) or (v>y),
                      we have to invert the conditional result as well, since
                      the above nodes return True for if v is within the range
                      (we're merging "not ((v-x)<=(y-x))" into "(v-x)>(y-x)") }
                    if (NodeType=orn) then
                      lNewNodeType:=gtn
                    else
                      lNewNodeType:=lten;

                    Result:=CAddNode.Create_Internal(lNewNodeType,
                              CTypeConvNode.Create_Internal(CAddNode.Create_Internal(subn,lLeftValueNode,COrdConstNode.Create(lLeftConstant,lDef,false)),lDef),
                              COrdConstNode.Create(lRightConstant-lLeftConstant,lDef,false));

                    exit;
                  end;

                {
                  (v1=const1) and (v2=const2)
                    can be converted into
                  ((v1 xor const1) or (v2 xor const2))=0
                }
                if (NodeType=andn) and
                   (Left.NodeType=EqualN) and
                   (Right.NodeType=EqualN) and
                   (not Might_Have_SideEffects(Left)) and
                   (not Might_Have_SideEffects(Right,[mhs_exceptions])) and
                   (Is_ConstIntNode(TAddNode(Left).Left) or Is_ConstIntNode(TAddNode(Left).Right) or
                    Is_ConstPointerNode(TAddNode(Left).Left) or Is_ConstPointerNode(TAddNode(Left).Right) or
                    Is_ConstCharNode(TAddNode(Left).Left) or Is_ConstCharNode(TAddNode(Left).Right)) and
                   (Is_ConstIntNode(TAddNode(Right).Left) or Is_ConstIntNode(TAddNode(Right).Right) or
                    Is_ConstPointerNode(TAddNode(Right).Left) or Is_ConstPointerNode(TAddNode(Right).Right) or
                    Is_ConstCharNode(TAddNode(Right).Left) or Is_ConstCharNode(TAddNode(Right).Right)) then
                   begin
                     if Is_ConstNode(TAddNode(Left).Left) then
                       begin
                         lValue1Pointer:=@TAddNode(Left).Right;
                         lConst1Pointer:=@TAddNode(Left).Left;
                       end
                     else
                       begin
                         lValue1Pointer:=@TAddNode(Left).Left;
                         lConst1Pointer:=@TAddNode(Left).Right;
                       end;
                     if Is_ConstNode(TAddNode(Right).Left) then
                       begin
                         lValue2Pointer:=@TAddNode(Right).Right;
                         lConst2Pointer:=@TAddNode(Right).Left;
                       end
                     else
                       begin
                         lValue2Pointer:=@TAddNode(Right).Left;
                         lConst2Pointer:=@TAddNode(Right).Right;
                       end;
                     if lValue1Pointer^.ResultDef.Size=lValue2Pointer^.ResultDef.Size then
                       begin
                         case lValue1Pointer^.ResultDef.Size of
                           1:
                             lIntType:=U8IntType;
                           2:
                             lIntType:=U16IntType;
                           4:
                             lIntType:=U32IntType;
                           8:
                             lIntType:=U64IntType;
                           else
                             InternalError(2020060101);
                         end;

                         { Assigned compares procvar values. Preserve that
                           meaning in the casts introduced by this rewrite. }
                         lValue1Conversion:=CTypeConvNode.Create_Internal(lValue1Pointer^.GetCopy,lIntType);
                         lValue1Conversion.Flags:=lValue1Conversion.Flags+(Left.Flags*[nf_load_procvar]);
                         lValue2Conversion:=CTypeConvNode.Create_Internal(lValue2Pointer^.GetCopy,lIntType);
                         lValue2Conversion.Flags:=lValue2Conversion.Flags+(Right.Flags*[nf_load_procvar]);
                         Result:=CAddNode.Create_Internal(EqualN,
                           CAddNode.Create_Internal(orn,
                             CAddNode.Create_Internal(xorn,lValue1Conversion,
                               CTypeConvNode.Create_Internal(lConst1Pointer^.GetCopy,lIntType)),
                             CAddNode.Create_Internal(xorn,lValue2Conversion,
                               CTypeConvNode.Create_Internal(lConst2Pointer^.GetCopy,lIntType))
                           ),
                           COrdConstNode.Create(0,lIntType,false));
                       end;
                   end;
                { even when short circuit boolean evaluation is active, this
                  optimization cannot be performed in case the node has
                  side effects, because this can change the result (e.g., in an
                  or-node that calls the same function twice and first returns
                  false and then true because of a global state change }
                if Left.IsEqual(Right) and not Might_Have_SideEffects(Left) then
                  begin
                    case NodeType of
                      andn,orn:
                        begin
                          Result:=PruneKeepLeft();
                          exit;
                        end;
                      {
                      xorn:
                        begin
                          result:=cordconstnode.create(0,resultdef,true);
                          exit;
                        end;
                      }
                      else
                        ;
                    end;
                  end
                { short to full boolean evaluation possible and useful? }
                else if not(Might_Have_SideEffects(Right,[mhs_exceptions])) and DoShortBoolEval(Self) then
                  begin
                    case NodeType of
                      andn,orn:
                        begin
                          { full boolean evaluation is only useful if the nodes are not too complex and if no jumps must be converted,
                            further, we need to know the expectloc }
                          if (Node_Complexity(Right)<=2) and
                            not(Left.ExpectLoc in [LOC_JUMP,LOC_INVALID]) and not(Right.ExpectLoc in [LOC_JUMP,LOC_INVALID]) then
                            begin
                              { we need to copy the whole tree to force another pass_1 }
                              include(LocalSwitches,cs_full_boolean_eval);
                              exclude(AddNodeFlags,anf_short_bool);
                              Result:=GetCopy;
                              exit;
                            end;
                        end;
                      else
                        ;
                    end;
                  end
              end;

            if Is_Integer(lLeftDef) and Is_Integer(lRightDef) then
              begin
                if (cs_opt_level3 in CurrentSettings.OptimizerSwitches) and
                   Left.IsEqual(Right) and not Might_Have_SideEffects(Left) then
                  begin
                    case NodeType of
                      andn,orn:
                        begin
                          Result:=PruneKeepLeft();
                          exit;
                        end;
                      xorn,
                      subn,
                      unequaln,
                      ltn,
                      gtn:
                        begin
                          Result:=COrdConstNode.Create(0,ResultDef,true);
                          exit;
                        end;
                      EqualN,
                      lten,
                      gten:
                        begin
                          Result:=COrdConstNode.Create(1,ResultDef,true);
                          exit;
                        end;
                      else
                        ;
                    end;
                  end
                else if TryHandleLengthZero(Left,Right,NodeType,Result) then
                  exit
                   ;
              end;

            {
              compile x < length(arr) as x <= high(arr)
              compile x >= length(arr) as x > high(arr)

              tested by tests/tbs/tw40292.pas
            }
            if (NodeType in [ltn,gten]) and
              (Right.NodeType=inlinen) and (TInlineNode(Right).InlineNumber=in_length_x) and
              ((Is_Dynamic_Array(TInlineNode(Right).Left.ResultDef)) or
               (Is_Open_Array(TInlineNode(Right).Left.ResultDef))
              ) then
              begin
                case NodeType of
                  ltn:
                    Result:=CAddNode.Create(lten,Left,CInlineNode.Create(in_high_x,false,TInlineNode(Right).Left));
                  gten:
                    Result:=CAddNode.Create(gtn,Left,CInlineNode.Create(in_high_x,false,TInlineNode(Right).Left));
                  else
                    InternalError(2024041701);
                end;
                Left:=nil;
                TInlineNode(Right).Left:=nil;
                exit;
              end;

            {
              compile length(arr) > x as high(arr) >= x
              compile length(arr) <= x as high(arr) < x

              tested by tests/tbs/tw40292.pas
            }
            if (NodeType in [lten,gtn]) and
              (Left.NodeType=inlinen) and (TInlineNode(Left).InlineNumber=in_length_x) and
              ((Is_Dynamic_Array(TInlineNode(Left).Left.ResultDef)) or
               (Is_Open_Array(TInlineNode(Left).Left.ResultDef))
              ) then
              begin
                case NodeType of
                  gtn:
                    Result:=CAddNode.Create(gten,CInlineNode.Create(in_high_x,false,TInlineNode(Left).Left),Right);
                  lten:
                    Result:=CAddNode.Create(ltn,CInlineNode.Create(in_high_x,false,TInlineNode(Left).Left),Right);
                  else
                    InternalError(2024041701);
                end;
                Right:=nil;
                TInlineNode(Left).Left:=nil;
                exit;
              end;

            { using sqr(x) for reals instead of x*x might reduces register pressure and/or
              memory accesses while sqr(<real>) has no drawback }
            if
               (NodeType=muln) and
               Is_Real(lLeftDef) and Is_Real(lRightDef) and
               Left.IsEqual(Right) and
               not(Might_Have_SideEffects(Left)) then
              begin
                Result:=CInlineNode.Create(in_sqr_real,false,PruneKeepLeft());
                InsertTypeConv(Result,ResultDef);
                exit;
              end;
{$ifdef cpurox}
            { optimize (i shl x) or (i shr (bitsizeof(i)-x)) into rol(x,i) (and different flavours with shl/shr swapped etc.) }
            if (NodeType in [addn,orn]) { add also works here }
{$ifndef cpu64bitalu}
               and (lLeftDef.typ=orddef) and
               not(TOrdDef(lLeftDef).OrdType in [s64bit,u64bit,scurrency])
{$endif cpu64bitalu}
              then
              begin
                if (Left.NodeType=shln) and (Right.NodeType=shrn) then
                  begin
                    Result:=CheckRotateOptimization(in_rol_x_y,in_ror_x_y);
                    if Assigned(Result) then
                      Exit;
                  end
                else if (Left.NodeType=shrn) and (Right.NodeType=shln) then
                  begin
                    Result:=CheckRotateOptimization(in_ror_x_y,in_rol_x_y);
                    if Assigned(Result) then
                      Exit;
                  end
              end;
{$endif cpurox}
            { optimize

                (a and b) or (c and not(b))

                into

                c xor ((c xor a) and b)
            }
            if (NodeType=orn) and
             (lLeftDef.typ=orddef) and
             (Left.NodeType=andn) and
             (Right.NodeType=andn) and
             (not(Is_Boolean(ResultDef)) or not(Might_Have_SideEffects(Self,[mhs_exceptions])) or not(DoShortBoolEval(Self))) and
             { this test is not needed but it speeds up the test and allows to bail out early }
             ((TAddNode(Left).Left.NodeType=notn) or (TAddNode(Left).Right.NodeType=notn) or
              (TAddNode(Right).Left.NodeType=notn) or (TAddNode(Right).Right.NodeType=notn)
             ) and
             not(Might_Have_SideEffects(Self)) then
             begin
               if MatchAndTransformNodesCommutative(TAddNode(Left).Left,TAddNode(Left).Right,TAddNode(Right).Left,TAddNode(Right).Right,
                 @IsAndOrAndNot,@TransformAndOrAndNot,Result) then
                 exit;
             end;
            { optimize tests for a single bit:
              (a and one_bit_mask_const) = <> one_bit_mask_const

              into

              (a and one_bit_mask_const) <> = 0
            }
            if (NodeType in [EqualN,unequaln]) then
              begin
                if (lLeftNodeType=andn) and (lRightNodeType=ordconstn) then
                  begin
                    lResultNode:=Left;
                    lRightConstant:=TOrdConstNode(Right).Value;
                  end
                else
                  if (lRightNodeType=andn) and (lLeftNodeType=ordconstn) then
                    begin
                      lResultNode:=Right;
                      lRightConstant:=TOrdConstNode(Left).Value;
                    end
                  else
                    begin
                      lResultNode:=nil;
                      lRightConstant:=0;
                    end;
                { using cr.uvalue is fine as we are interested only in the bit pattern }
                if (lResultNode<>nil) and (PopCnt(lRightConstant.uvalue) = 1) then
                  begin
                    if Is_ConstIntNode(TAddNode(lResultNode).Left) then
                      lLeftValueNode:=TAddNode(lResultNode).Left
                    else
                      if Is_ConstIntNode(TAddNode(lResultNode).Right) then
                        lLeftValueNode:=TAddNode(lResultNode).Right
                      else
                        lLeftValueNode:=nil;
                    if (lLeftValueNode<>nil) and (TOrdConstNode(lLeftValueNode).Value=lRightConstant) then
                      begin
                        if NodeType=EqualN then
                          lNewNodeType:=unequaln
                        else
                          lNewNodeType:=EqualN;
                        Result:=CAddNode.Create(lNewNodeType,lResultNode,COrdConstNode.Create(0,lLeftValueNode.ResultDef,false));
                        Include(TransientFlags,tnf_do_not_execute);
                        if lResultNode=Left then
                          Left:=nil
                        else
                          Right:=nil;
                        exit;
                      end;
                  end;
              end;
          end;
      end;


    function TAddNode.DoGetCopy: TNode;
      var
        lAddNode: TAddNode;
      begin
        lAddNode:=TAddNode(inherited DoGetCopy);
        lAddNode.AddNodeFlags:=AddNodeFlags;
        lAddNode.ResultRealDef:=ResultRealDef;
        Result:=lAddNode;
      end;


    function TAddNode.DoCompare(ANode: TNode): Boolean;
      begin
        Result:=
          inherited DoCompare(ANode) and
          Equal_Defs(TAddNode(ANode).ResultRealDef,ResultRealDef);
      end;


    procedure TAddNode.PrintNodeData(var AText: Text);
      var
        lIndex: TAddNodeFlag;
        lFirst: Boolean;
      begin
        write(AText,PrintNodeIndention,'addnodeflags = [');
        lFirst:=true;
        for lIndex:=low(TAddNodeFlag) to high(TAddNodeFlag) do
          if lIndex in AddNodeFlags then
            begin
              if not(lFirst) then
                write(AText,',')
              else
                lFirst:=false;
              write(AText, lIndex);
            end;
        WriteLn(AText,']');
        inherited PrintNodeData(AText);
      end;


    function TAddNode.Pass_TypeCheck:TNode;
      begin
        { This function is small to keep the stack small for recursive of
          large + operations }
        TypeCheckPass(Left);
        TypeCheckPass(Right);
        Result:=PassTypeCheckInternal;
      end;


    function TAddNode.PassTypeCheckInternal:TNode;
      var
        lNode          : TNode;
        lRightDef,lLeftDef,lNodeDef    : TDef;
        lFieldSym        : TFieldVarSym;
        lLeftLow,lLeftHigh,
        lRightLow,lRightHigh  : TConstExprInt;
        lStringType     : TStringType;
        lComparisonResult,
        lValueInRange           : Boolean;
        lLeftNodeType,lRightNodeType       : TNodeType;
        lOldNodeType          : TNodeType;

        function MaybeCastOrdConst(var ANode: TNode; ADef: TDef): Boolean;
          begin
            Result:=(TOrdConstNode(ANode).Value>=TOrdDef(ADef).low) and
              (TOrdConstNode(ANode).Value<=TOrdDef(ADef).high);
            if Result then
              InsertTypeConv(ANode,ADef);
          end;

        function MaybeConvertToInsert:TNode;

          function ElementCount(AArrayConstructor: TArrayConstructorNode):ASizeInt;
            begin
              Result:=0;
              while Assigned(AArrayConstructor) do
                begin
                  if AArrayConstructor.NodeType=arrayconstructorrangen then
                    InternalError(2018052501);
                  inc(Result);
                  AArrayConstructor:=TArrayConstructorNode(TArrayConstructorNode(AArrayConstructor).Right);
                end;
            end;

          var
            lElement : TNode;
            lPara : TCallParaNode;
            lIsLeftArrayConstructor,
            lIsRightArrayConstructor : Boolean;
            lIndex : ASizeInt;
          begin
            Result:=nil;

            lIsLeftArrayConstructor:=Left.NodeType=arrayconstructorn;
            lIsRightArrayConstructor:=Right.NodeType=arrayconstructorn;

            if not Assigned(AktAssignmentNode) or
                (AktAssignmentNode.Right<>Self) or
                not(
                  lIsLeftArrayConstructor or
                  lIsRightArrayConstructor
                ) or
                not(
                  Left.IsEqual(AktAssignmentNode.Left) or
                  Right.IsEqual(AktAssignmentNode.Left)
                ) or
                not Valid_For_Var(AktAssignmentNode.Left,false) or
                (lIsLeftArrayConstructor and (ElementCount(TArrayConstructorNode(Left))>1)) or
                (lIsRightArrayConstructor and (ElementCount(TArrayConstructorNode(Right))>1)) then
              exit;

            if lIsLeftArrayConstructor then
              begin
                lIndex:=0;
                lElement:=TArrayConstructorNode(Left).Left;
                TArrayConstructorNode(Left).Left:=nil;
              end
            else
              begin
                lIndex:=high(ASizeInt);
                lElement:=TArrayConstructorNode(Right).Left;
                TArrayConstructorNode(Right).Left:=nil;
              end;

            { we use the fact that insert() caps the index to avoid a copy }
            lPara:=CCallParaNode.Create(
                    COrdConstNode.Create(lIndex,SizeSIntType,false),
                    CCallParaNode.Create(
                      AktAssignmentNode.Left.GetCopy,
                      CCallParaNode.Create(
                        lElement,nil)));

            Result:=CInlineNode.Create(in_insert_x_y_z,false,lPara);
            include(AktAssignmentNode.AssignmentNodeFlags,anf_assign_done_in_right);
          end;

      begin
         Result:=nil;
         lRightLow:=0;
         lLeftLow:=0;
         lRightHigh:=0;
         lLeftHigh:=0;

         { avoid any problems with type parameters later on }
         if Is_TypeParam(Left.ResultDef) or Is_TypeParam(Right.ResultDef) then
           begin
             ResultDef:=CUndefinedType;
             exit;
           end;

         { both left and right need to be valid }
         Set_VarState(Left,vs_read,[vsf_must_be_valid]);
         Set_VarState(Right,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         { tp procvar support. Omit for converted assigned() nodes }
         if not (nf_load_procvar in Flags) then
           begin
             Maybe_Call_ProcVar(Left,true);
             Maybe_Call_ProcVar(Right,true);
           end
         else
           if not (NodeType in [EqualN,unequaln]) then
             InternalError(2013091601);

         { allow operator overloading }
         lNode:=Self;

         if Is_Array_Constructor(Left.ResultDef) or Is_Array_Constructor(Right.ResultDef) then
           begin
             { check whether there is a suitable operator for the array constructor
               (but only if the "+" array operator isn't used), if not fall back to sets }
             if (
                   (NodeType<>addn) or
                   not (m_array_operators in CurrentSettings.ModeSwitches) or
                   (Is_Array_Constructor(Left.ResultDef) and not Is_Dynamic_Array(Right.ResultDef)) or
                   (not Is_Dynamic_Array(Left.ResultDef) and Is_Array_Constructor(Right.ResultDef))
                 ) and
                 not IsBinaryOverloaded(lNode,[ocf_check_only]) then
               begin
                 if Is_Array_Constructor(Left.ResultDef) then
                   begin
                     ArrayConstructor_To_Set(Left);
                     TypeCheckPass(Left);
                   end;
                 if Is_Array_Constructor(Right.ResultDef) then
                   begin
                     ArrayConstructor_To_Set(Right);
                     TypeCheckPass(Right);
                   end;
               end;
           end;

         if Is_Dynamic_Array(Left.ResultDef) and Is_Dynamic_Array(Right.ResultDef) and
             (NodeType=addn) and
             (m_array_operators in CurrentSettings.ModeSwitches) and
             IsBinaryOverloaded(lNode,[ocf_check_non_overloadable,ocf_check_only]) then
           message3(parser_w_operator_overloaded_hidden_3,Left.ResultDef.TypeName,arraytokeninfo[_PLUS].str,Right.ResultDef.TypeName);

         if IsBinaryOverloaded(lNode,[]) then
           begin
              Result:=lNode;
              exit;
           end;
         { Stop checking when an error was found in the operator checking }
         if CodeGenError then
           begin
             Result:=CErrorNode.Create;
             exit;
           end;

         { Kylix allows enum+ordconstn in an enum type declaration, we need to do
           the conversion here before the constant folding }
         if (m_delphi in CurrentSettings.ModeSwitches) and
            (blocktype in [bt_type,bt_const_type,bt_var_type]) then
          begin
            if (Left.ResultDef.typ=enumdef) and
               (Right.ResultDef.typ=orddef) then
             begin
               { insert explicit typecast to default signed int }
               Left:=CTypeConvNode.Create_Internal(Left,SIntType);
               TypeCheckPass(Left);
             end
            else
             if (Left.ResultDef.typ=orddef) and
                (Right.ResultDef.typ=enumdef) then
              begin
                { insert explicit typecast to default signed int }
                Right:=CTypeConvNode.Create_Internal(Right,SIntType);
                TypeCheckPass(Right);
              end;
          end;

        { is one a real float, then both need to be floats, this
          need to be done before the constant folding so constant
          operation on a float and int are also handled }
{$ifdef x86}
        { use extended as default real type only when the x87 fpu is used }
  {$if defined(i386)}
        if not(CurrentSettings.FPUType=fpu_x87) then
          ResultRealDef:=S64FloatType
        else
          ResultRealDef:=PBestRealType^;
  {$endif i386}
  {$ifdef x86_64}
        { x86-64 has no x87 only mode, so use always double as default }
        ResultRealDef:=S64FloatType;
  {$endif x86_6}
{$else not x86}
        ResultRealDef:=PBestRealType^;
{$endif not x86}

        if (Right.ResultDef.typ=floatdef) or (Left.ResultDef.typ=floatdef) then
         begin
           { when both floattypes are already equal then use that
             floattype for results }
           if (Right.ResultDef.typ=floatdef) and
              (Left.ResultDef.typ=floatdef) and
              (TFloatDef(Left.ResultDef).FloatType=TFloatDef(Right.ResultDef).FloatType) and
              not(TFloatDef(Left.ResultDef).FloatType in [s64comp,s64currency]) then
             begin
               if cs_excessprecision in CurrentSettings.LocalSwitches then
                 begin
                   ResultRealDef:=PBestRealType^;
                   InsertTypeConv(Right,ResultRealDef);
                   InsertTypeConv(Left,ResultRealDef);
                 end
               else
                 ResultRealDef:=Left.ResultDef
             end
           { when there is a currency type then use currency, but
             only when currency is defined as float }
           else
            if (Is_Currency(Right.ResultDef) or
                Is_Currency(Left.ResultDef)) and
               ((S64CurrencyType.typ = floatdef) or
                (NodeType <> slashn)) then
             begin
               ResultRealDef:=S64CurrencyType;
               if (NodeType = muln) then
                 begin
                   { See if we can minimise any unnecessary scaling that might
                     cause precision problems }
                   if (nf_is_currency in Right.Flags) then
                     begin
                       if (nf_is_currency in Left.Flags) then
                         begin
                           InsertTypeConv(Right,ResultRealDef);
                           InsertTypeConv(Left,ResultRealDef);
                         end
                       else
                         begin
                           InsertTypeConv(Right,ResultRealDef);
                           InsertTypeConv_Internal(Left,ResultRealDef)
                         end;
                     end
                   else
                     begin
                       if (nf_is_currency in Left.Flags) then
                         begin
                           InsertTypeConv_Internal(Right,ResultRealDef);
                           InsertTypeConv(Left,ResultRealDef);
                         end
                       else
                         begin
                           InsertTypeConv(Right,ResultRealDef);
                           InsertTypeConv(Left,ResultRealDef);
                         end;
                     end;
                 end
               else
                 begin
                   InsertTypeConv(Right,ResultRealDef);
                   InsertTypeConv(Left,ResultRealDef);
                 end;
             end
           else
            begin
              ResultRealDef:=GetBestReal(Left.ResultDef,Right.ResultDef);
              InsertTypeConv(Right,ResultRealDef);
              InsertTypeConv(Left,ResultRealDef);
            end;
         end;

        { If both operands are constant and there is a unicodestring
          or unicodestring then convert everything to unicodestring }
        if Is_ConstNode(Right) and Is_ConstNode(Left) and
           (Is_UnicodeString(Right.ResultDef) or
            Is_UnicodeString(Left.ResultDef)) then
          begin
            InsertTypeConv(Right,CUnicodeStringType);
            InsertTypeConv(Left,CUnicodeStringType);
          end;

        { If both operands are constant and there is a widechar
          or widestring then convert everything to widestring. This
          allows constant folding like char+widechar }
        if Is_ConstNode(Right) and Is_ConstNode(Left) and
           (Is_WideString(Right.ResultDef) or
            Is_WideString(Left.ResultDef) or
            Is_WideChar(Right.ResultDef) or
            Is_WideChar(Left.ResultDef)) then
          begin
            InsertTypeConv(Right,CWideStringType);
            InsertTypeConv(Left,CWideStringType);
          end;

        { load easier access variables }
        lRightDef:=Right.ResultDef;
        lLeftDef:=Left.ResultDef;
        lRightNodeType:=Right.NodeType;
        lLeftNodeType:=Left.NodeType;

         { 4 character constant strings are compatible with orddef }
         { in macpas mode (become cardinals)                       }
         if (m_mac in CurrentSettings.ModeSwitches) and
            { only allow for comparisons, additions etc are }
            { normally program errors                       }
            (NodeType in [ltn,lten,gtn,gten,unequaln,EqualN]) and
            (((lLeftNodeType=stringconstn) and
              (TStringConstNode(Left).len=4) and
              (lRightDef.typ=orddef)) or
             ((lRightNodeType=stringconstn) and
              (TStringConstNode(Right).len=4) and
              (lLeftDef.typ=orddef))) then
           begin
             if (lRightNodeType=stringconstn) then
               begin
                 InsertTypeConv(Right,U32IntType);
                 lRightNodeType:=Right.NodeType;
                 lRightDef:=Right.ResultDef;
               end
             else
               begin
                 InsertTypeConv(Left,U32IntType);
                 lLeftNodeType:=Left.NodeType;
                 lLeftDef:=Left.ResultDef;
               end;
           end;

         { but an int/int gives real/real! }
         if (NodeType=slashn) and not(Is_Vector(Left.ResultDef)) and not(Is_Vector(Right.ResultDef)) then
          begin
            if Is_Currency(Left.ResultDef) and
               Is_Currency(Right.ResultDef) then
              { In case of currency, converting to float means dividing by 10000 }
              { However, since this is already a division, both divisions by     }
              { 10000 are eliminated when we divide the results -> we can skip   }
              { them.                                                            }
              if S64CurrencyType.typ = floatdef then
                begin
                  { there's no s64comptype or so, how do we avoid the type conversion?
                  left.resultdef := s64comptype;
                  right.resultdef := s64comptype; }
                end
              else
                begin
                  Left.ResultDef := S64IntType;
                  Right.ResultDef := S64IntType;
                end;
            InsertTypeConv(Right,ResultRealDef);
            InsertTypeConv(Left,ResultRealDef);
          end

         { if both are orddefs then check sub types }
         else if (lLeftDef.typ=orddef) and (lRightDef.typ=orddef) then
           begin
              { set for & and | operations in macpas mode: they only work on }
              { booleans, and always short circuit evaluation                }
              if (anf_short_bool in AddNodeFlags) then
                begin
                  if not Is_Boolean(lLeftDef) then
                    begin
                      InsertTypeConv(Left,PasBool1Type);
                      lLeftDef := Left.ResultDef;
                    end;
                  if not Is_Boolean(lRightDef) then
                    begin
                      InsertTypeConv(Right,PasBool1Type);
                      lRightDef := Right.ResultDef;
                    end;
                end;

             { 2 booleans? }
             if (Is_Boolean(lLeftDef) and Is_Boolean(lRightDef)) then
              begin
                case NodeType of
                  xorn,
                  andn,
                  orn:
                    begin
                      { in case of xor or 'and' with cbool: convert both to Pascal bool and then
                        perform the xor/and to prevent issues with "longbool(1) and/xor
                        longbool(2)" }
                      if (Is_CBool(lLeftDef) or Is_CBool(lRightDef)) and
                         (NodeType in [xorn,andn]) then
                        begin
                          ResultDef:=nil;
                          if Is_CBool(lLeftDef) then
                            begin
                              Left:=CTypeConvNode.Create(Left,PasBool8Type);
                              TTypeConvNode(Left).ConvType:=tc_bool_2_bool;
                              FirstPass(Left);
                              if not Is_CBool(lRightDef) or
                                 (lLeftDef.Size>=lRightDef.Size) then
                                ResultDef:=lLeftDef;
                            end;
                          if Is_CBool(lRightDef) then
                            begin
                              Right:=CTypeConvNode.Create(Right,PasBool8Type);
                              TTypeConvNode(Right).ConvType:=tc_bool_2_bool;
                              FirstPass(Right);
                              if not Assigned(ResultDef) then
                                ResultDef:=lRightDef;
                            end;
                          Result:=CTypeConvNode.Create_Explicit(CAddNode.Create(NodeType,Left,Right),ResultDef);
                          TTypeConvNode(Result).ConvType:=tc_bool_2_bool;
                          Left:=nil;
                          Right:=nil;
                          exit;
                        end;
                      { Make sides equal to the largest boolean }
                      if (TOrdDef(Left.ResultDef).Size>TOrdDef(Right.ResultDef).Size) or
                        (Is_CBool(Left.ResultDef) and not Is_CBool(Right.ResultDef)) then
                        begin
                          Right:=CTypeConvNode.Create_Internal(Right,Left.ResultDef);
                          TTypeConvNode(Right).ConvType:=tc_bool_2_bool;
                          TypeCheckPass(Right);
                        end
                      else if (TOrdDef(Left.ResultDef).Size<TOrdDef(Right.ResultDef).Size) or
                        (not Is_CBool(Left.ResultDef) and Is_CBool(Right.ResultDef)) then
                        begin
                          Left:=CTypeConvNode.Create_Internal(Left,Right.ResultDef);
                          TTypeConvNode(Left).ConvType:=tc_bool_2_bool;
                          TypeCheckPass(Left);
                        end;
                    end;
                  ltn,
                  lten,
                  gtn,
                  gten:
                    begin
                      { convert both to pasbool to perform the comparison (so
                        that longbool(4) = longbool(2), since both represent
                        "true" }
                      InsertTypeConv(Left,PasBool1Type);
                      InsertTypeConv(Right,PasBool1Type);
                    end;
                  unequaln,
                  EqualN:
                    begin
                      { Remove any compares with constants }
                      if (Left.NodeType=ordconstn) then
                        begin
                          lNode:=Right;
                          lValueInRange:=(TOrdConstNode(Left).Value<>0);
                          lOldNodeType:=NodeType;
                          Right:=nil;
                          if (not(lValueInRange) and (lOldNodeType=EqualN)) or
                             (lValueInRange and (lOldNodeType=unequaln)) then
                           begin
                             lNode:=CNotNode.Create(lNode);
                           end;
                          Result:=lNode;
                          exit;
                        end;
                      if (Right.NodeType=ordconstn) then
                        begin
                          lNode:=Left;
                          lValueInRange:=(TOrdConstNode(Right).Value<>0);
                          lOldNodeType:=NodeType;
                          Left:=nil;
                          if (not(lValueInRange) and (lOldNodeType=EqualN)) or
                             (lValueInRange and (lOldNodeType=unequaln)) then
                           begin
                             lNode:=CNotNode.Create(lNode);
                           end;
                          Result:=lNode;
                          exit;
                        end;
                      { Delphi-compatibility: convert both to pasbool to
                        perform the equality comparison }
                      InsertTypeConv(Left,PasBool1Type);
                      InsertTypeConv(Right,PasBool1Type);
                    end;
                  else
                    begin
                      CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
                      Result:=CNothingNode.Create;
                      exit;
                    end;
                end;
              end
             { Both are chars? }
             else if Is_Char(lRightDef) and Is_Char(lLeftDef) then
               begin
                 if NodeType=addn then
                  begin
                    ResultDef:=CShortStringType;
                    if not(Is_ConstCharNode(Left) and Is_ConstCharNode(Right)) then
                     begin
                       InsertTypeConv(Left,CShortStringType);
{$ifdef addstringopt}
                       lNode := genaddsstringcharoptnode(Self);
                       Result := lNode;
                       exit;
{$endif addstringopt}
                     end
                  end
                else if not(NodeType in [ltn,lten,gtn,gten,unequaln,EqualN]) then
                  begin
                    CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
                    Result:=CNothingNode.Create;
                    exit;
                  end;
               end
             { There is a widechar? }
             else if Is_WideChar(lRightDef) or Is_WideChar(lLeftDef) then
               begin
                 { widechar+widechar gives unicodestring }
                 if NodeType=addn then
                   begin
                     InsertTypeConv(Left,CUnicodeStringType);
                     if (TOrdDef(lRightDef).OrdType<>uwidechar) then
                       InsertTypeConv(Right,CWideCharType);
                     ResultDef:=CUnicodeStringType;
                   end
                 else
                   begin
                     if (TOrdDef(lLeftDef).OrdType<>uwidechar) then
                       InsertTypeConv(Left,CWideCharType);
                     if (TOrdDef(lRightDef).OrdType<>uwidechar) then
                       InsertTypeConv(Right,CWideCharType);
                   end;
               end
             { is there a currency type ? }
             else if ((TOrdDef(lRightDef).OrdType=scurrency) or (TOrdDef(lLeftDef).OrdType=scurrency)) then
               begin
                 if (NodeType=muln) and
                   { Is only one currency? }
                   (
                     (TOrdDef(lLeftDef).OrdType=scurrency) xor (TOrdDef(lRightDef).OrdType=scurrency)
                   ) then
                   begin
                     { Don't actually set the nf_is_currency flag, as it doesn't
                       need scaling }
                     if (TOrdDef(lLeftDef).OrdType<>scurrency) then
                       begin
                         Left:=CTypeConvNode.Create_Internal(Left,S64CurrencyType);
                         TypeCheckPass(Left);
                       end
                     else
                       begin
                         Right:=CTypeConvNode.Create_Internal(Right,S64CurrencyType);
                         TypeCheckPass(Right);
                       end;
                   end
                 else
                   begin
                     if (TOrdDef(lLeftDef).OrdType<>scurrency) then
                       InsertTypeConv(Left,S64CurrencyType);
                     if (TOrdDef(lRightDef).OrdType<>scurrency) then
                       InsertTypeConv(Right,S64CurrencyType);
                   end;
               end
             { leave some constant integer expressions alone in case the
               resultdef of the integer types doesn't influence the outcome,
               because the forced type conversions below can otherwise result
               in unexpected results (such as high(qword)<high(int64) returning
               true because high(qword) gets converted to int64) }
             else if Is_Integer(lLeftDef) and Is_Integer(lRightDef) and
                     (lLeftNodeType=ordconstn) and (lRightNodeType=ordconstn) and
                     (NodeType in [EqualN,unequaln,gtn,gten,ltn,lten]) then
               begin
               end
             { "and" does't care about the sign of integers }
             { "xor", "or" and compares don't need extension to native int }
             { size either as long as both values are signed or unsigned   }
             { "xor" and "or" also don't care about the sign if the values }
             { occupy an entire register                                   }
             { don't do it if either type is 64 bit (except for "and"),    }
             { since in that case we can't safely find a "common" type     }
             else if Is_Integer(lLeftDef) and Is_Integer(lRightDef) and
                     ((NodeType=andn) or
                      ((NodeType in [orn,xorn,EqualN,unequaln,gtn,gten,ltn,lten]) and
                        not Is_64BitInt(lLeftDef) and not Is_64BitInt(lRightDef) and
                       (Is_Signed(lLeftDef)=Is_Signed(lRightDef)))) then
               begin
                 { Delphi-compatible: prefer unsigned type for "and", when the
                   unsigned type is bigger than the signed one, and also bigger
                   than min(native_int, 32-bit) }
                 if (Is_OversizedInt(lRightDef) or Is_NativeInt(lRightDef) or Is_32BitInt(lRightDef)) and
                    (lRightDef.Size>=lLeftDef.Size) and
                    not Is_Signed(lRightDef) and Is_Signed(lLeftDef) then
                      InsertTypeConv_Internal(Left,lRightDef)
                 else if (Is_OversizedInt(lLeftDef) or Is_NativeInt(lLeftDef) or Is_32BitInt(lLeftDef)) and
                    (lLeftDef.Size>=lRightDef.Size) and
                    not Is_Signed(lLeftDef) and Is_Signed(lRightDef) then
                      InsertTypeConv_Internal(Right,lLeftDef)
                 else
                   begin
                     { not to left right.resultdef, because that may
                       cause a range error if left and right's def don't
                       completely overlap }
                     lNodeDef:=Get_Common_IntDef(TOrdDef(lLeftDef),TOrdDef(lRightDef),true);
                     InsertTypeConv(Left,lNodeDef);
                     InsertTypeConv(Right,lNodeDef);
                   end;
               end
             { don't extend (sign-mismatched) comparisons if either side is a constant
               whose value is within range of opposite side }
             else if Is_Integer(lLeftDef) and Is_Integer(lRightDef) and
                     (NodeType in [EqualN,unequaln,gtn,gten,ltn,lten]) and
                     (Is_Signed(lLeftDef)<>Is_Signed(lRightDef)) and
                     (
                       ((lLeftNodeType=ordconstn) and MaybeCastOrdConst(Left,lRightDef)) or
                       ((lRightNodeType=ordconstn) and MaybeCastOrdConst(Right,lLeftDef))
                     ) then
               begin
                 { done here }
               end
             { is there a signed 64 bit type ? }
             else if ((TOrdDef(lRightDef).OrdType=s64bit) or (TOrdDef(lLeftDef).OrdType=s64bit)) then
               begin
                  if (TOrdDef(lLeftDef).OrdType<>s64bit) then
                   InsertTypeConv(Left,S64IntType);
                  if (TOrdDef(lRightDef).OrdType<>s64bit) then
                   InsertTypeConv(Right,S64IntType);
               end
             { is there a unsigned 64 bit type ? }
             else if ((TOrdDef(lRightDef).OrdType=u64bit) or (TOrdDef(lLeftDef).OrdType=u64bit)) then
               begin
                  if (TOrdDef(lLeftDef).OrdType<>u64bit) then
                   InsertTypeConv(Left,U64IntType);
                  if (TOrdDef(lRightDef).OrdType<>u64bit) then
                   InsertTypeConv(Right,U64IntType);
               end
             { is there a larger int? }
             else if Is_OversizedInt(lRightDef) or Is_OversizedInt(lLeftDef) then
               begin
                 lNodeDef:=Get_Common_IntDef(TOrdDef(lLeftDef),TOrdDef(lRightDef),false);
                 InsertTypeConv(Right,lNodeDef);
                 InsertTypeConv(Left,lNodeDef);
               end
             { is there a native unsigned int? }
             else if Is_NativeUInt(lRightDef) or Is_NativeUInt(lLeftDef) then
               begin
                 { convert positive constants to uinttype }
                 if (not Is_NativeUInt(lLeftDef)) and
                    Is_ConstIntNode(Left) and
                    (TOrdConstNode(Left).Value >= 0) then
                   InsertTypeConv(Left,UIntType);
                 if (not Is_NativeUInt(lRightDef)) and
                    Is_ConstIntNode(Right) and
                    (TOrdConstNode(Right).Value >= 0) then
                   InsertTypeConv(Right,UIntType);
                 { when one of the operand is signed or the operation is subn then perform
                   the operation in a larger signed type, can't use rd/ld here because there
                   could be already typeconvs inserted.
                   This is compatible with the code below for other unsigned types (PFV) }
                 if Is_Signed(Left.ResultDef) or
                    Is_Signed(Right.ResultDef) or
                    ((NodeType=subn)

                    ) then
                   begin
                     if NodeType<>subn then
                       CGMessage(type_h_mixed_signed_unsigned);
                     { mark as internal in case added for a subn, so }
                     { ttypeconvnode.simplify can remove the larger  }
                     { typecast again if semantically correct. Even  }
                     { if we could detect that here already, we      }
                     { mustn't do it here because that would change  }
                     { overload choosing behaviour etc. The code in  }
                     { ncnv.pas is run after that is already decided }
                     if (not Is_Signed(Left.ResultDef) and
                         not Is_Signed(Right.ResultDef)) or
                        (NodeType in [orn,xorn]) then
                       include(Flags,nf_internal);
                     { get next larger signed int type }
                     lNodeDef:=Get_Common_IntDef(TOrdDef(SIntType),TOrdDef(UIntType),false);
                     InsertTypeConv(Left,lNodeDef);
                     InsertTypeConv(Right,lNodeDef);
                   end
                 else
                   begin
                     if not Is_NativeUInt(Left.ResultDef) then
                       InsertTypeConv(Left,UIntType);
                     if not Is_NativeUInt(Right.ResultDef) then
                       InsertTypeConv(Right,UIntType);
                   end;
               end
             { generic ord conversion is sinttype }
             else
               begin
                 { When there is a signed type or there is a minus operation
                   or in TP mode for 16-bit CPUs
                   we convert to signed int. Otherwise (both are unsigned) we keep
                   the result also unsigned. This is compatible with Delphi (PFV) }
                 if Is_Signed(lLeftDef) or
                    Is_Signed(lRightDef) or
                    (([m_iso,m_extpas]*CurrentSettings.ModeSwitches)<>[]) or

                    (NodeType=subn) then
                   begin
                     InsertTypeConv(Right,SIntType);
                     InsertTypeConv(Left,SIntType);
                   end
                 else
                   begin
                     InsertTypeConv(Right,UIntType);
                     InsertTypeConv(Left,UIntType);
                   end;
               end;
           end

         { if both are floatdefs, conversion is already done before constant folding }
         else if (lLeftDef.typ=floatdef) then
           begin
             if not(NodeType in [addn,subn,muln,slashn,EqualN,unequaln,ltn,lten,gtn,gten]) then
               CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
           end

         { left side a setdef, must be before string processing,
           else array constructor can be seen as array of char (PFV) }
         else if (lLeftDef.typ=setdef) then
          begin
             if not(NodeType in [addn,subn,symdifn,muln,EqualN,unequaln,lten,gten]) then
              CGMessage(type_e_set_operation_unknown);
             { right must either be a set or a set element }
             if (lRightDef.typ<>setdef) and
                (lRightNodeType<>setelementn) then
               CGMessage(type_e_mismatch)
             { Make operands the same setdef. If one's elementtype fits   }
             { entirely inside the other's, pick the one with the largest }
             { range.  Otherwise create a new setdef with a range which   }
             { can contain both.                                          }
             else if not(Equal_Defs(lLeftDef,lRightDef)) then
              begin
                { note: ld cannot be an empty set with elementdef=nil in }
                { case right is not a set, arrayconstructor_to_set takes }
                { care of that                                           }

                { 1: rd is a set with an assigned elementdef, and ld is    }
                {    either an empty set without elementdef or a set whose }
                {    elementdef fits in rd's elementdef -> convert to rd   }
                if ((lRightDef.typ=setdef) and
                    Assigned(TSetDef(lRightDef).ElementDef) and
                    (not Assigned(TSetDef(lLeftDef).ElementDef) or
                     Is_In_Limit(lLeftDef,lRightDef))) then
                  InsertTypeConv(Left,lRightDef)
                { 2: rd is either an empty set without elementdef or a set }
                {    whose elementdef fits in ld's elementdef, or a set    }
                {    element whose def fits in ld's elementdef -> convert  }
                {    to ld. ld's elementdef can't be nil here, is caught   }
                {    previous case and "note:" above                       }
                else if ((lRightDef.typ=setdef) and
                         (not Assigned(TSetDef(lRightDef).ElementDef) or
                          Is_In_Limit(lRightDef,lLeftDef))) or
                        ((lRightDef.typ<>setdef) and
                         Is_In_Limit(lRightDef,TSetDef(lLeftDef).ElementDef)) then
                   if (lRightDef.typ=setdef) then
                    InsertTypeConv(Right,lLeftDef)
                  else
                    InsertTypeConv(Right,TSetDef(lLeftDef).ElementDef)
                { 3: otherwise create setdef which encompasses both, taking }
                {    into account empty sets without elementdef             }
                else
                  begin
                    if Assigned(TSetDef(lLeftDef).ElementDef) then
                      begin
                        lLeftLow:=TSetDef(lLeftDef).SetLow;
                        lLeftHigh:=TSetDef(lLeftDef).SetMax;
                      end;
                    if (lRightDef.typ=setdef) then
                      if Assigned(TSetDef(lRightDef).ElementDef) then
                        begin
                          lRightLow:=TSetDef(lRightDef).SetLow;
                          lRightHigh:=TSetDef(lRightDef).SetMax;
                        end
                      else
                        begin
                          { ld's elementdef must have been valid }
                          lRightLow:=lLeftLow;
                          lRightHigh:=lLeftHigh;
                        end
                    else
                      GetRange(lRightDef,lRightLow,lRightHigh);
                    if not Assigned(TSetDef(lLeftDef).ElementDef) then
                      begin
                        lLeftLow:=lRightLow;
                        lLeftHigh:=lRightHigh;
                      end;
                    lNodeDef:=CSetDef.Create(TSetDef(lLeftDef).ElementDef,min(lLeftLow,lRightLow).svalue,max(lLeftHigh,lRightHigh).svalue,true);
                    InsertTypeConv(Left,lNodeDef);
                    if (lRightDef.typ=setdef) then
                      InsertTypeConv(Right,lNodeDef)
                    else
                       InsertTypeConv(Right,TSetDef(lNodeDef).ElementDef);
                  end;
              end;
          end
         { pointer comparison and subtraction }
         else if (
                  (lRightDef.typ=pointerdef) and (lLeftDef.typ=pointerdef)
                 ) or
                 { compare/add pchar to variable (not stringconst) char arrays
                   by addresses like BP/Delphi }
                 (
                  (NodeType in [EqualN,unequaln,subn,addn]) and
                  (
                   ((Is_PChar(lLeftDef) or (lLeftNodeType=niln)) and Is_CharArray(lRightDef) and (lRightNodeType<>stringconstn)) or
                   ((Is_PChar(lRightDef) or (lRightNodeType=niln)) and Is_CharArray(lLeftDef) and (lLeftNodeType<>stringconstn))
                  )
                 ) then
          begin
            { convert char array to pointer }
            if Is_CharArray(lRightDef) then
              begin
                InsertTypeConv(Right,CharPointerType);
                lRightDef:=Right.ResultDef;
              end
            else if Is_CharArray(lLeftDef) then
              begin
                InsertTypeConv(Left,CharPointerType);
                lLeftDef:=Left.ResultDef;
              end;

            case NodeType of
               EqualN,unequaln :
                 begin
                    if Is_VoidPointer(Right.ResultDef) then
                      InsertTypeConv(Right,Left.ResultDef)
                    else if Is_VoidPointer(Left.ResultDef) then
                      InsertTypeConv(Left,Right.ResultDef)
                    else if not(Equal_Defs(lLeftDef,lRightDef)) then
                      IncompatibleTypes(lLeftDef,lRightDef);
                 end;
               ltn,lten,gtn,gten:
                 begin
                    if (cs_extsyntax in CurrentSettings.ModuleSwitches) or
                       (nf_internal in Flags) then
                     begin
                       if Is_VoidPointer(Right.ResultDef) then
                        InsertTypeConv(Right,Left.ResultDef)
                       else if Is_VoidPointer(Left.ResultDef) then
                        InsertTypeConv(Left,Right.ResultDef)
                       else if not (
                           { in Delphi two different pointer types can be compared
                             if either $POINTERMATH is currently enabled or if
                             both pointer defs were declared with $POINTERMATH
                             enabled }
                           (m_delphi in CurrentSettings.ModeSwitches) and
                           (lLeftDef.typ=pointerdef) and
                           (lRightDef.typ=pointerdef) and
                           (
                             (cs_pointermath in CurrentSettings.LocalSwitches) or
                             (
                               TPointerDef(lLeftDef).HasPointerMath and
                               TPointerDef(lRightDef).HasPointerMath
                             )
                           )
                         ) and not(Equal_Defs(lLeftDef,lRightDef)) then
                        IncompatibleTypes(lLeftDef,lRightDef);
                     end
                    else
                     CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
                 end;
               subn:
                 begin
                    if (cs_extsyntax in CurrentSettings.ModuleSwitches) or
                       (nf_internal in Flags) then
                      begin
                        if Is_VoidPointer(Right.ResultDef) then
                        begin
                          if Is_Big_Untyped_AddrNode(Right) then
                            CGMessage1(type_w_untyped_arithmetic_unportable,Node2OpStr(NodeType));
                          InsertTypeConv(Right,Left.ResultDef)
                        end
                        else if Is_VoidPointer(Left.ResultDef) then
                          InsertTypeConv(Left,Right.ResultDef)
                        else if not(Equal_Defs(lLeftDef,lRightDef)) then
                          IncompatibleTypes(lLeftDef,lRightDef);
                      end
                    else
                      CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);

                    if not(anf_has_pointerdiv in AddNodeFlags) and
                      (TPointerDef(lRightDef).PointedDef.Size>1) then
                      begin
                        lNode:=GetCopy;
                        include(TAddNode(lNode).AddNodeFlags, anf_has_pointerdiv);
                        Result:=CModDivNode.Create(divn,lNode,
                          COrdConstNode.Create(TPointerDef(lRightDef).PointedDef.Size,TPointerDef(lRightDef).Pointer_Subtraction_Result_Type,false));
                      end;
                    ResultDef:=TPointerDef(lRightDef).Pointer_Subtraction_Result_Type;
                    exit;
                 end;
               else
                 CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
            end;
          end

         { is one of the operands a string?,
           chararrays are also handled as strings (after conversion), also take
           care of chararray+chararray and chararray+char.
           Note: Must be done after pointerdef+pointerdef has been checked, else
           pchar is converted to string }
         else if (lRightDef.typ=stringdef) or
                 (lLeftDef.typ=stringdef) or
                 { stringconstn's can be arraydefs }
                 (lLeftNodeType=stringconstn) or
                 (lRightNodeType=stringconstn) or
                 ((Is_PChar(lRightDef) or Is_CharArray(lRightDef) or Is_Char(lRightDef) or Is_Open_CharArray(lRightDef) or
                   Is_PWideChar(lRightDef) or Is_WideCharArray(lRightDef) or Is_WideChar(lRightDef) or Is_Open_WideCharArray(lRightDef)) and
                  (Is_PChar(lLeftDef) or Is_CharArray(lLeftDef) or Is_Char(lLeftDef) or Is_Open_CharArray(lLeftDef) or
                   Is_PWideChar(lLeftDef) or Is_WideCharArray(lLeftDef) or Is_WideChar(lLeftDef) or Is_Open_WideCharArray(lLeftDef))) then
          begin
            if (NodeType in [addn,EqualN,unequaln,lten,gten,ltn,gtn]) then
              begin
                { Is there a unicodestring? }
                if Is_UnicodeString(lRightDef) or Is_UnicodeString(lLeftDef) or
                   ((m_default_unicodestring in CurrentSettings.ModeSwitches) and
                    (cs_refcountedstrings in CurrentSettings.LocalSwitches) and
                    (
                     Is_PWideChar(lRightDef) or Is_WideCharArray(lRightDef) or Is_Open_WideCharArray(lRightDef) or (lLeftNodeType = stringconstn) or
                     Is_PWideChar(lLeftDef) or Is_WideCharArray(lLeftDef) or Is_Open_WideCharArray(lLeftDef) or (lRightNodeType = stringconstn)
                    )
                   ) then
                  lStringType:=st_unicodestring
                else
                { Is there a widestring? }
                  if Is_WideString(lRightDef) or Is_WideString(lLeftDef) or
                     Is_PWideChar(lRightDef) or Is_WideCharArray(lRightDef) or Is_WideChar(lRightDef) or Is_Open_WideCharArray(lRightDef) or
                     Is_PWideChar(lLeftDef) or Is_WideCharArray(lLeftDef) or Is_WideChar(lLeftDef) or Is_Open_WideCharArray(lLeftDef) then
                    lStringType:=st_widestring
                else
                  if Is_AnsiString(lRightDef) or Is_AnsiString(lLeftDef) or
                     ((cs_refcountedstrings in CurrentSettings.LocalSwitches) and
                     //todo: Move some of this to longstring's then they are implemented?
                      (
                       Is_PChar(lRightDef) or (Is_CharArray(lRightDef) and (lRightDef.Size > 255)) or Is_Open_CharArray(lRightDef) or (lLeftNodeType = stringconstn) or
                       Is_PChar(lLeftDef) or (Is_CharArray(lLeftDef) and (lLeftDef.Size > 255)) or Is_Open_CharArray(lLeftDef) or (lRightNodeType = stringconstn)
                      )
                     ) then
                    lStringType:=st_ansistring
                else
                  if Is_LongString(lRightDef) or Is_LongString(lLeftDef) then
                    lStringType:=st_longstring
                else
                  begin
                    { TODO: todo: add a warning/hint here if one converting a too large array}
                    { nodes is PChar, array [with size > 255] or OpenArrayOfChar.
                      Note: Delphi halts with error if "array [0..xx] of char"
                           is assigned to ShortString and string length is less
                           then array size }
                    lStringType:= st_shortstring;
                  end;

                // Now convert nodes to common string type
                case lStringType of
                  st_widestring :
                    begin
                      if not(Is_WideString(lRightDef)) then
                        InsertTypeConv(Right,CWideStringType);
                      if not(Is_WideString(lLeftDef)) then
                        InsertTypeConv(Left,CWideStringType);
                    end;
                  st_unicodestring :
                    begin
                      if not(Is_UnicodeString(lRightDef)) then
                        InsertTypeConv(Right,CUnicodeStringType);
                      if not(Is_UnicodeString(lLeftDef)) then
                        InsertTypeConv(Left,CUnicodeStringType);
                    end;
                  st_ansistring :
                    begin
                      { use same code page if possible (don't force same code
                        page in case both are ansistrings with code page <>
                        CP_NONE, since then data loss can occur: the ansistring
                        helpers will convert them at run time to an encoding
                        that can represent both encodings) }
                      if Is_AnsiString(lLeftDef) and
                         (TStringDef(lLeftDef).encoding<>0) and
                         (TStringDef(lLeftDef).encoding<>Globals.CP_NONE) and
                         (not Is_AnsiString(lRightDef) or
                          (TStringDef(lRightDef).encoding=0) or
                          (TStringDef(lRightDef).encoding=Globals.CP_NONE)) then
                        InsertTypeConv(Right,lLeftDef)
                      else if Is_AnsiString(lRightDef) and
                         (TStringDef(lRightDef).encoding<>0) and
                         (TStringDef(lRightDef).encoding<>Globals.CP_NONE) and
                         (not Is_AnsiString(lLeftDef) or
                          (TStringDef(lLeftDef).encoding=0) or
                          (TStringDef(lLeftDef).encoding=Globals.CP_NONE)) then
                        InsertTypeConv(Left,lRightDef)
                      else
                        begin
                          if not Is_AnsiString(lLeftDef) then
                            InsertTypeConv(Left,GetAnsiStringDef);
                          if not Is_AnsiString(lRightDef) then
                            InsertTypeConv(Right,GetAnsiStringDef);
                        end;
                    end;
                  st_longstring :
                    begin
                      if not(Is_LongString(lRightDef)) then
                        InsertTypeConv(Right,CLongStringType);
                      if not(Is_LongString(lLeftDef)) then
                        InsertTypeConv(Left,CLongStringType);
                     end;
                   st_shortstring :
                     begin
                       if not(Is_ShortString(lLeftDef)) then
                         InsertTypeConv(Left,CShortStringType);
                       { don't convert char, that can be handled by the optimized node }
                       if not(Is_ShortString(lRightDef) or Is_Char(lRightDef)) then
                         InsertTypeConv(Right,CShortStringType);
                     end;
                end;
              end
            else
              CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
          end

         { implicit pointer object type comparison }
         else if Is_Implicit_Pointer_Object_Type(lRightDef) or Is_Implicit_Pointer_Object_Type(lLeftDef) then
          begin
            if (NodeType in [EqualN,unequaln]) then
              begin
                if Is_Implicit_Pointer_Object_Type(lRightDef) and Is_Implicit_Pointer_Object_Type(lLeftDef) then
                 begin
                   if Def_Is_Related(TObjectDef(lRightDef),TObjectDef(lLeftDef)) then
                    InsertTypeConv(Right,Left.ResultDef)
                   else
                    InsertTypeConv(Left,Right.ResultDef);
                 end
                else if Is_Implicit_Pointer_Object_Type(lRightDef) then
                  InsertTypeConv(Left,Right.ResultDef)
                else
                  InsertTypeConv(Right,Left.ResultDef);
              end
            else
              CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
          end

         else if (lRightDef.typ=classrefdef) and (lLeftDef.typ=classrefdef) then
          begin
            if (NodeType in [EqualN,unequaln]) then
              begin
                if Def_Is_Related(TObjectDef(TClassRefDef(lRightDef).PointedDef),
                        TObjectDef(TClassRefDef(lLeftDef).PointedDef)) then
                  InsertTypeConv(Right,Left.ResultDef)
                else
                  InsertTypeConv(Left,Right.ResultDef);
              end
            else
              CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
          end

         { allow comparison with nil pointer }
         else if Is_Implicit_Pointer_Object_Type(lRightDef) or (lRightDef.typ=classrefdef) then
          begin
            if (NodeType in [EqualN,unequaln]) then
              InsertTypeConv(Left,Right.ResultDef)
            else
              CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
          end

         else if Is_Implicit_Pointer_Object_Type(lLeftDef) or (lLeftDef.typ=classrefdef) then
          begin
            if (NodeType in [EqualN,unequaln]) then
              InsertTypeConv(Right,Left.ResultDef)
            else
              CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
          end

       { support procvar=nil,procvar<>nil }
         else if ((lLeftDef.typ=procvardef) and (lRightNodeType=niln)) or
                 ((lRightDef.typ=procvardef) and (lLeftNodeType=niln)) then
          begin
            if not(NodeType in [EqualN,unequaln]) then
              CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
            { find proc field in methodpointer record }
            lFieldSym:=TFieldVarSym(TRecordDef(MethodPointerType).SymTable.Find('proc'));
            if not Assigned(lFieldSym) then
              InternalError(200412043);
            { For methodpointers compare only tmethodpointer.proc }
            if (lRightDef.typ=procvardef) and
               (not TProcVarDef(lRightDef).Is_AddressOnly) then
              begin
                Right:=CSubscriptNode.Create(
                           lFieldSym,
                           CTypeConvNode.Create_Internal(Right,MethodPointerType));
                TypeCheckPass(Right);
               end;
            if (lLeftDef.typ=procvardef) and
               (not TProcVarDef(lLeftDef).Is_AddressOnly) then
              begin
                Left:=CSubscriptNode.Create(
                          lFieldSym,
                          CTypeConvNode.Create_Internal(Left,MethodPointerType));
                TypeCheckPass(Left);
              end;
            if lLeftNodeType=niln then
              InsertTypeConv_Explicit(Left,Right.ResultDef)
            else
              InsertTypeConv_Explicit(Right,Left.ResultDef)
          end

         { <dyn. array>+<dyn. array> ? }
         else if (NodeType=addn) and (Is_Dynamic_Array(lLeftDef) or Is_Dynamic_Array(lRightDef)) then
           begin
              { empty array to add? }
              if (Right.NodeType=arrayconstructorn) and (TArrayConstructorNode(Right).Left=nil) then
                begin
                  Result:=Left;
                  Left:=nil;
                  exit;
                end
              else if (Left.NodeType=arrayconstructorn) and (TArrayConstructorNode(Left).Left=nil) then
                begin
                  Result:=Right;
                  Right:=nil;
                  exit;
                end
              else
                begin
                  Result:=MaybeConvertToInsert;
                  if Assigned(Result) then
                    exit;
                  if not(Is_Dynamic_Array(lLeftDef)) then
                    InsertTypeConv(Left,lRightDef);
                  if not(Is_Dynamic_Array(lRightDef)) then
                    InsertTypeConv(Right,lLeftDef);
                end;
           end

        { support dynamicarray=nil,dynamicarray<>nil }
         else if (Is_Dynamic_Array(lLeftDef) and (lRightNodeType=niln)) or
                 (Is_Dynamic_Array(lRightDef) and (lLeftNodeType=niln)) or
                 (Is_Dynamic_Array(lLeftDef) and Is_Dynamic_Array(lRightDef)) then
          begin
            if not(NodeType in [EqualN,unequaln]) then
              CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
            if lLeftNodeType=niln then
              InsertTypeConv_Explicit(Left,Right.ResultDef)
            else
              InsertTypeConv_Explicit(Right,Left.ResultDef)
          end

         { vector support, this must be before the zero based array
           check }
         else if (cs_support_vectors in CurrentSettings.GlobalSwitches) and
                 Fits_In_MM_Register(lLeftDef) and
                 Fits_In_MM_Register(lRightDef) and
                 Equal_Defs(lLeftDef,lRightDef) then
            begin
              if not(NodeType in [addn,subn,xorn,orn,andn,muln,slashn]) then
                CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
              { both defs must be equal, so taking left or right as resultdef doesn't matter }
              ResultDef:=To_HWVectorDef(Left.ResultDef,false);
            end

         { this is a little bit dangerous, also the left type }
         { pointer to should be checked! This broke the mmx support      }
         else if (lRightDef.typ=pointerdef) or
                 (Is_Zero_Based_Array(lRightDef) and (lRightNodeType<>stringconstn)) then
          begin
            if Is_Zero_Based_Array(lRightDef) then
              begin
                ResultDef:=CPointerDef.getreusable(TArrayDef(lRightDef).ElementDef);
                InsertTypeConv(Right,ResultDef);
              end
            else
              ResultDef:=Right.ResultDef;
            InsertTypeConv(Left,TPointerDef(Right.ResultDef).Pointer_Arithmetic_Int_Type);
            if NodeType=addn then
              begin
                if (lRightNodeType=niln) then
                  CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,'NIL');
                if (not(cs_extsyntax in CurrentSettings.ModuleSwitches) and not(nf_internal in Flags))  or
                   (not (Is_PChar(lRightDef) or Is_CharArray(lRightDef) or Is_Open_CharArray(lRightDef) or Is_WideChar(lRightDef) or Is_WideCharArray(lRightDef) or Is_Open_WideCharArray(lRightDef)) and
                    not(cs_pointermath in CurrentSettings.LocalSwitches) and
                    not((lRightDef.typ=pointerdef) and TPointerDef(lRightDef).HasPointerMath)) then
                  CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
                if (lRightDef.typ=pointerdef) and
                   (TPointerDef(lRightDef).PointedDef.Size>1) then
                   begin
                     Left:=CAddNode.Create(muln,Left,
                       COrdConstNode.Create(TPointerDef(lRightDef).PointedDef.Size,TPointerDef(Right.ResultDef).Pointer_Arithmetic_Int_Type,true));
                     TypeCheckPass(Left);
                   end;
              end
            else
              CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
          end

         else if (lLeftDef.typ=pointerdef) or
                 (Is_Zero_Based_Array(lLeftDef) and (lLeftNodeType<>stringconstn)) then
           begin
             if Is_Zero_Based_Array(lLeftDef) then
               begin
                  ResultDef:=CPointerDef.getreusable(TArrayDef(lLeftDef).ElementDef);
                  InsertTypeConv(Left,ResultDef);
               end
             else
               ResultDef:=Left.ResultDef;

             InsertTypeConv(Right,TPointerDef(Left.ResultDef).Pointer_Arithmetic_Int_Type);
             if NodeType in [addn,subn] then
               begin
                 if (lLeftNodeType=niln) then
                   CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),'NIL',lRightDef.TypeName);
                 if (not(cs_extsyntax in CurrentSettings.ModuleSwitches) and not(nf_internal in Flags)) or
                   (not (Is_PChar(lLeftDef) or Is_CharArray(lLeftDef) or Is_Open_CharArray(lLeftDef) or Is_WideChar(lLeftDef) or Is_WideCharArray(lLeftDef) or Is_Open_WideCharArray(lLeftDef)) and
                    not(cs_pointermath in CurrentSettings.LocalSwitches) and
                    not((lLeftDef.typ=pointerdef) and TPointerDef(lLeftDef).HasPointerMath)) then
                   CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
                 if (lLeftDef.typ=pointerdef) then
                 begin
                   if Is_Big_Untyped_AddrNode(Left) then
                     CGMessage1(type_w_untyped_arithmetic_unportable,Node2OpStr(NodeType));
                   if (TPointerDef(lLeftDef).PointedDef.Size>1) then
                   begin
                     Right:=CAddNode.Create(muln,Right,
                       COrdConstNode.Create(TPointerDef(lLeftDef).PointedDef.Size,TPointerDef(Left.ResultDef).Pointer_Arithmetic_Int_Type,true));
                     TypeCheckPass(Right);
                   end
                 end else
                   if Is_Zero_Based_Array(lLeftDef) and
                      (TArrayDef(lLeftDef).ElementDef.Size>1) then
                     begin
                       Right:=CAddNode.Create(muln,Right,
                         COrdConstNode.Create(TArrayDef(lLeftDef).ElementDef.Size,TPointerDef(Left.ResultDef).Pointer_Arithmetic_Int_Type,true));
                       TypeCheckPass(Right);
                     end;
               end
             else
               CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
           end

         else if (lRightDef.typ=procvardef) and
                 (lLeftDef.typ=procvardef) and
                 Equal_Defs(lRightDef,lLeftDef) then
          begin
            if (NodeType in [EqualN,unequaln]) then
              begin
                if TProcVarDef(lRightDef).Is_AddressOnly then
                  begin
                    InsertTypeConv_Internal(Right,VoidCodePointerType);
                    InsertTypeConv_Internal(Left,VoidCodePointerType);
                  end
                else
                  begin
                    { find proc field in methodpointer record }
                    lFieldSym:=TFieldVarSym(TRecordDef(MethodPointerType).SymTable.Find('proc'));
                    if not Assigned(lFieldSym) then
                      InternalError(2004120405);
                    { Compare tmehodpointer(left).proc }
                    Right:=CSubscriptNode.Create(
                                 lFieldSym,
                                 CTypeConvNode.Create_Internal(Right,MethodPointerType));
                    TypeCheckPass(Right);
                    Left:=CSubscriptNode.Create(
                                 lFieldSym,
                                 CTypeConvNode.Create_Internal(Left,MethodPointerType));
                     TypeCheckPass(Left);
                  end;
              end
            else
              CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
          end

         { enums }
         else if (lLeftDef.typ=enumdef) and (lRightDef.typ=enumdef) then
          begin
            if AllowEnumOp(NodeType) or (nf_internal in Flags) then
              InsertTypeConv(Right,Left.ResultDef)
            else
              CGMessage3(type_e_operator_not_supported_for_types,Node2OpStr(NodeType),lLeftDef.TypeName,lRightDef.TypeName);
          end

         { generic conversion, this is for error recovery }
         else
          begin
            InsertTypeConv(Left,SIntType);
            InsertTypeConv(Right,SIntType);
          end;

         if CompareDisjointRanges(lComparisonResult) and not(nf_internal in Flags) then
           begin
             if lComparisonResult then
               CGMessage(type_w_comparison_always_true)
             else
               CGMessage(type_w_comparison_always_false);
           end;

         { set resultdef if not already done }
         if not Assigned(ResultDef) then
          begin
             case NodeType of
                ltn,lten,gtn,gten,EqualN,unequaln :
                  ResultDef:=PasBool1Type;
                slashn :
                  ResultDef:=ResultRealDef;
                addn:
                  begin
                    { for strings, return is always a 255 char string }
                    if Is_ShortString(Left.ResultDef) then
                      ResultDef:=CShortStringType
                    else
                    { for ansistrings set resultdef to assignment left node
                      if it is an assignment and left node expects ansistring }
                    if Is_AnsiString(Left.ResultDef) and
                       Assigned(AktAssignmentNode) and
                       (AktAssignmentNode.Right=Self) and
                       Is_AnsiString(AktAssignmentNode.Left.ResultDef) then
                      ResultDef:=AktAssignmentNode.Left.ResultDef
                    else
                      ResultDef:=Left.ResultDef;
                  end;
                else
                  ResultDef:=Left.ResultDef;
             end;
          end;

         Result:=DoCurrencyCorrections;

         if not(CodeGenError) and
            not Assigned(Result) then
           begin
             if not (nf_internal in Flags) and
               (nf_is_currency in Left.Flags) and
               (nf_is_currency in Right.Flags) and
               (NodeType in [addn,subn,muln]) then
               Include(Flags,nf_is_currency);

             Result:=Simplify(false);
           end;
      end;


    function TAddNode.DoCurrencyCorrections: TNode;
      var
        lNode: TNode;
        lProcName: string[31];
      begin
        Result:=nil;
        lNode:=nil;
        { when the result is currency we need some extra code to make sure
           the comparisons are scaled properly. this should not be done when
           a muln or slashn node is created internally }
        if not(nf_internal in Flags) and
          { Can't go by the node's resultdef in the case of comparisons }
          (
            Is_Currency(Left.ResultDef) or
            Is_Currency(Right.ResultDef)
          ) then
          begin
            case NodeType of
              slashn :
                if (
                    (nf_is_currency in Flags) and
                    { Equivalence... both true or both false }
                    not ((nf_is_currency in Left.Flags) xor (nf_is_currency in Right.Flags))
                  ) then
                  begin
                    { slashn will only work with floats }
                    Exclude(Flags,nf_is_currency);
                    Include(Flags,nf_internal); { Prevent recursion }
                    lNode:=CAddNode.Create_Internal(muln,GetCopy,CRealConstNode.Create_Currency_Scalar(S64CurrencyType));
                    include(lNode.Flags,nf_is_currency);
                    Result:=lNode;
                  end
                else if not (nf_is_currency in Flags) then
                  begin
                    if (
                      not (nf_is_currency in Left.Flags) and
                      (nf_is_currency in Right.Flags)
                    ) then
                      begin
                        { Put a multiplier on the left side }
                        Left:=CAddNode.Create_Internal(muln,Left,CRealConstNode.Create_Currency_Scalar(S64CurrencyType));
                        include(Left.Flags,nf_is_currency);
                        TypeCheckPass(Left);
                      end
                    else if (
                        (nf_is_currency in Left.Flags) and
                        not (nf_is_currency in Right.Flags)
                      ) then
                      { All the scalars are correct, so mark it so }
                      Include(Flags,nf_is_currency);
                  end;

              muln :
                if (nf_is_currency in Flags) then
                  begin
                    if (nf_is_currency in Left.Flags) and (nf_is_currency in Right.Flags) then
                      begin
                        if S64CurrencyType.typ=floatdef then
                          begin
                            { Probably a Currency constant with a fractional component }
                            if (Right.NodeType=realconstn) and (nf_internal in Right.Flags) then
                              begin
                                Left:=CAddNode.Create_Internal(slashn,Left,CRealConstNode.Create_Currency_Scalar(S64CurrencyType));
                                DoTypeCheckPass(Left);
                              end
                            else
                              begin
                                Right:=CAddNode.Create_Internal(slashn,Right,CRealConstNode.Create_Currency_Scalar(S64CurrencyType));
                                DoTypeCheckPass(Right);
                              end;
                          end
                        else
                          begin
                            { Probably a Currency constant with a fractional component }
                            if (Right.NodeType=realconstn) and (nf_internal in Right.Flags) then
                              begin
                                Left:=CModDivNode.Create(divn,Left,COrdConstNode.Create_Currency_Scalar(S64CurrencyType));
                                Include(Left.Flags,nf_internal);
                                DoTypeCheckPass(Left);
                              end
                            else
                              begin
                                Right:=CModDivNode.Create(divn,Right,COrdConstNode.Create_Currency_Scalar(S64CurrencyType));
                                Include(Right.Flags,nf_internal);
                                DoTypeCheckPass(Right);
                              end;
                          end;

                        { We need to force a re-evaluation }
                        Result:=GetCopy;
                      end
                    else if not (nf_is_currency in Left.Flags) and not (nf_is_currency in Right.Flags) then
                      begin
                        Result:=GetCopy;
                        { Prevent recursion }
                        Include(Result.Flags,nf_internal);

                        if S64CurrencyType.typ=floatdef then
                          lNode:=CAddNode.Create_Internal(muln,Result,CRealConstNode.Create_Currency_Scalar(S64CurrencyType))
                        else
                          lNode:=CAddNode.Create_Internal(muln,Result,COrdConstNode.Create_Currency_Scalar(S64CurrencyType));
                        { Because the multiplication doubles up on the currency scalar, dividing
                          removes only one and hence the result is still scaled }
                        Include(lNode.Flags,nf_is_currency);
                        Result:=lNode;
                      end;
                  end
                else
                  begin
                    if S64CurrencyType.typ=floatdef then
                      begin
                        { if left is a currency integer constant, we can get rid of the factor 10000 }
                        { int64(...) causes a cast on currency, so it is the currency value multiplied by 10000 }
                        if (Left.NodeType=realconstn) and (Is_Currency(Left.ResultDef)) and (nf_is_currency in Left.Flags) and ((Trunc(TRealConstNode(Left).ValueReal) mod 10000)=0) then
                          begin
                            { trealconstnode expects that value_real and value_currency contain valid values }
                            TRealConstNode(Left).ValueReal:=TRealConstNode(Left).ValueReal/BestReal(10000.0);
                            TRealConstNode(Left).SetCurrencyValue(TRealConstNode(Left).ValueReal);
                            Exclude(Left.Flags,nf_is_currency);
                            Include(Flags,nf_is_currency);

                            { We need to force a re-evaluation }
                            lNode:=GetCopy;
                          end
                        { or if right is an integer constant, we can get rid of its factor 10000 }
                        else if (Right.NodeType=realconstn) and (Is_Currency(Right.ResultDef)) and (nf_is_currency in Right.Flags) and ((Trunc(TRealConstNode(Right).ValueReal) mod 10000)=0) then
                          begin
                            { trealconstnode expects that value and value_currency contain valid values }
                            TRealConstNode(Right).ValueReal:=TRealConstNode(Right).ValueReal/BestReal(10000.0);
                            TRealConstNode(Right).SetCurrencyValue(TRealConstNode(Right).ValueReal);
                            Exclude(Right.Flags,nf_is_currency);
                            Include(Flags,nf_is_currency);

                            { We need to force a re-evaluation }
                            lNode:=GetCopy;
                          end
                        else if (nf_is_currency in Left.Flags) xor (nf_is_currency in Right.Flags) then
                          begin
                            { If one is scaled and one isn't, then the result is scaled }
                            Include(Flags,nf_is_currency);
                          end
                        else if (nf_is_currency in Left.Flags) and (nf_is_currency in Right.Flags) then
                          begin
                            Include(Flags,nf_is_currency);
                            Right:=CAddNode.Create_Internal(slashn,Right,CRealConstNode.Create_Currency_Scalar(S64CurrencyType));
                            { Because the multiplication doubles up on the currency scalar, dividing
                              removes only one and hence the result is still scaled }
                            DoTypeCheckPass(Right);

                            { We need to force a re-evaluation }
                            lNode:=GetCopy;
                          end;
                      end
                    else
                      begin
                        { if left is a currency integer constant, we can get rid of the factor 10000 }
                        if (Left.NodeType=ordconstn) and (Is_Currency(Left.ResultDef)) and (nf_is_currency in Left.Flags) and ((TOrdConstNode(Left).Value mod 10000)=0) then
                          begin
                            TOrdConstNode(Left).Value:=TOrdConstNode(Left).Value div 10000;
                            Exclude(Left.Flags,nf_is_currency);
                            Include(Flags,nf_is_currency);

                            { We need to force a re-evaluation }
                            lNode:=GetCopy;
                          end
                        { or if right is an integer constant, we can get rid of its factor 10000 }
                        else if (Right.NodeType=ordconstn) and (Is_Currency(Right.ResultDef)) and (nf_is_currency in Right.Flags) and ((TOrdConstNode(Right).Value mod 10000)=0) then
                          begin
                            TOrdConstNode(Right).Value:=TOrdConstNode(Right).Value div 10000;
                            Exclude(Right.Flags,nf_is_currency);
                            Include(Flags,nf_is_currency);

                            { We need to force a re-evaluation }
                            lNode:=GetCopy;
                          end

                        else if (Right.NodeType=muln) and Is_Currency(Right.ResultDef) and (nf_is_currency in Right.Flags) and
                          { do not test swapped here as the internal conversions are only create as "var."*"10000" }
                          Is_Currency(TAddNode(Right).Right.ResultDef) and (TAddNode(Right).Right.NodeType=ordconstn) and (TOrdConstNode(TAddNode(Right).Right).Value=10000) and
                          Is_Currency(TAddNode(Right).Left.ResultDef) and not (nf_is_currency in TAddNode(Right).Left.Flags) and (TAddNode(Right).Left.NodeType=typeconvn) then
                          begin
                            lNode:=TAddNode(Right).Left.GetCopy;
                            Right.free;
                            Right:=lNode;

                            { We need to force a re-evaluation }
                            lNode:=GetCopy;
                          end
                        else if (Left.NodeType=muln) and Is_Currency(Left.ResultDef) and
                          { do not test swapped here as the internal conversions are only create as "var."*"10000" }
                          Is_Currency(TAddNode(Left).Right.ResultDef) and (TAddNode(Left).Right.NodeType=ordconstn) and (TOrdConstNode(TAddNode(Left).Right).Value=10000) and
                          Is_Currency(TAddNode(Left).Left.ResultDef) and not (nf_is_currency in TAddNode(Left).Left.Flags) and (TAddNode(Left).Left.NodeType=typeconvn) then
                          begin
                            lNode:=TAddNode(Left).Left.GetCopy;
                            Left.free;
                            Left:=lNode;

                            { We need to force a re-evaluation }
                            lNode:=GetCopy;
                          end
                        else if (nf_is_currency in Left.Flags) xor (nf_is_currency in Right.Flags) then
                          begin
                            { If one is scaled and one isn't, then the result is scaled }
                            Include(Flags,nf_is_currency);
                          end
                        else if (nf_is_currency in Left.Flags) and (nf_is_currency in Right.Flags) then
                          begin
                            { The Int64-based Currency implementation (used e.g. on
                              Win64, where x87 extended types are not supported) can
                              NOT be safely done as a plain 64-bit "multiply, then
                              divide by 10000": both operands here are already scaled
                              by 10000, so their raw product can overflow a 64-bit
                              integer even for operands that are themselves well
                              within Currency's legal range (e.g. 9500000.0004 *
                              10000). Route through a helper that computes the
                              product and the rescaling division using a full
                              128-bit intermediate result, instead of building
                              generic muln+divn nodes that truncate to 64 bits
                              in between.
                            }
                            lProcName := 'fpc_mul_currency';
                            if cs_check_overflow in CurrentSettings.LocalSwitches then
                              lProcName := lProcName + '_checkoverflow';
                            lNode:=CCallNode.CreateIntern(lProcName,CCallParaNode.Create(Right,CCallParaNode.Create(Left,nil)));
                            Include(lNode.Flags,nf_is_currency);
                            Left:=nil;
                            Right:=nil;
                          end;
                      end;

                    Result:=lNode;
                  end;
              addn,
              subn,
              ltn,
              lten,
              gtn,
              gten,
              EqualN,
              unequaln:
                { Correct absence of nf_is_currency flag in addn and subn }
                if not
                  (
                    (nf_is_currency in Left.Flags) and
                    (nf_is_currency in Right.Flags)
                  ) then
                  begin
                    { Sort out problems with only one side being scaled }
                    if not (nf_is_currency in Right.Flags) then
                      begin
                        if S64CurrencyType.typ = floatdef then
                          Right:=CAddNode.Create_Internal(muln,Right,CRealConstNode.Create_Currency_Scalar(S64CurrencyType))
                        else
                          Right:=CAddNode.Create_Internal(muln,Right,COrdConstNode.Create_Currency_Scalar(S64CurrencyType));
                        Include(Right.Flags,nf_is_currency);
                        TypeCheckPass(Right);
                        FirstPass(Right);
                        Include(Right.Flags,nf_is_currency);
                      end;
                    if not (nf_is_currency in Left.Flags) then
                      begin
                        if S64CurrencyType.typ = floatdef then
                          Left:=CAddNode.Create_Internal(muln,Left,CRealConstNode.Create_Currency_Scalar(S64CurrencyType))
                        else
                          Left:=CAddNode.Create_Internal(muln,Left,COrdConstNode.Create_Currency_Scalar(S64CurrencyType));
                        Include(Left.Flags,nf_is_currency);
                        TypeCheckPass(Left);
                        FirstPass(Left);
                        Include(Left.Flags,nf_is_currency);
                      end;
                  end;
              else
                ;
            end;
          end;
      end;


    function TAddNode.First_AddString: TNode;
      var
        lNode: TNode;
        lNewStatement : TStatementNode;
        lTempNode : TTempCreateNode;
        lCompareFunctionName: string;
        lPara: TCallParaNode;
      begin
        Result:=nil;
        { when we get here, we are sure that both the left and the right }
        { node are both strings of the same stringtype (JM)              }
        case NodeType of
          addn:
            begin
              if (Left.NodeType=stringconstn) and (TStringConstNode(Left).len=0) then
                begin
                  Result:=Right;
                  Left.free;
                  Left:=nil;
                  Right:=nil;
                  exit;
                end;
              if (Right.NodeType=stringconstn) and (TStringConstNode(Right).len=0) then
                begin
                  Result:=Left;
                  Left:=nil;
                  Right.free;
                  Right:=nil;
                  exit;
                end;
              { create the call to the concat routine both strings as arguments }
              if Assigned(AktAssignmentNode) and
                  (AktAssignmentNode.Right=Self) and
                  (
                    (AktAssignmentNode.Left.ResultDef=ResultDef) or
                    (
                      Is_ShortString(AktAssignmentNode.Left.ResultDef) and
                      Is_ShortString(ResultDef)
                    )
                  ) and
                  Valid_For_Var(AktAssignmentNode.Left,false) then
                begin
                  lPara:=CCallParaNode.Create(
                          Right,
                          CCallParaNode.Create(
                            Left,
                            CCallParaNode.Create(AktAssignmentNode.Left.GetCopy,nil)
                          )
                        );
                  if Is_AnsiString(ResultDef) then
                    lPara:=CCallParaNode.Create(
                            COrdConstNode.Create(
                              { don't use getparaencoding(), we have to know
                                when the result is rawbytestring }
                              TStringDef(ResultDef).encoding,
                              U16IntType,
                              true
                            ),
                            lPara
                          );
                  Result:=CCallNode.CreateIntern(
                            'fpc_'+TStringDef(ResultDef).StringTypName+'_concat',
                            lPara
                          );
                  include(AktAssignmentNode.AssignmentNodeFlags,anf_assign_done_in_right);
                  FirstPass(Result);
                end
              else
                begin
                  Result:=InternalStatements(lNewStatement);
                  lTempNode:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);
                  AddStatement(lNewStatement,lTempNode);
                  lPara:=CCallParaNode.Create(
                          Right,
                          CCallParaNode.Create(
                            Left,
                            CCallParaNode.Create(CTempRefNode.Create(lTempNode),nil)
                          )
                        );
                  if Is_AnsiString(ResultDef) then
                    lPara:=CCallParaNode.Create(
                            COrdConstNode.Create(
                              { don't use getparaencoding(), we have to know
                                when the result is rawbytestring }
                              TStringDef(ResultDef).encoding,
                              U16IntType,
                              true
                            ),
                            lPara
                          );
                  AddStatement(
                    lNewStatement,
                    CCallNode.CreateIntern(
                      'fpc_'+TStringDef(ResultDef).StringTypName+'_concat',
                      lPara
                    )
                  );
                  AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTempNode));
                  AddStatement(lNewStatement,CTempRefNode.Create(lTempNode));
                end;
              { we reused the arguments }
              Left := nil;
              Right := nil;
            end;
          ltn,lten,gtn,gten,EqualN,unequaln :
            begin
              { generate better code for comparison with empty string, we
                only need to compare the length with 0 }
              if (NodeType in [EqualN,unequaln,gtn,gten,ltn,lten]) and
                 (((Left.NodeType=stringconstn) and (TStringConstNode(Left).len=0)) or
                  ((Right.NodeType=stringconstn) and (TStringConstNode(Right).len=0))) then
                begin
                  { switch so that the constant is always on the right }
                  if Left.NodeType = stringconstn then
                    begin
                      lNode := Left;
                      Left := Right;
                      Right := lNode;
                      NodeType:=cSwapRelation[NodeType];
                    end;
                  if Is_ShortString(Left.ResultDef) or
                     (NodeType in [gtn,gten,ltn,lten]) then
                    { compare the length with 0 }
                    Result := CAddNode.Create(NodeType,
                      CInlineNode.Create(in_length_x,false,Left),
                      COrdConstNode.Create(0,S8IntType,false))
                  else { nodetype in [equaln,unequaln] }
                    begin
                      if Is_WideString(Left.ResultDef) and (tf_winlikewidestring in TargetInfo.Flags) then
                        begin
                          { windows like widestrings requires that we also check the length }
                          Result:=CInlineNode.Create(in_length_x,false,Left);
                          { and compare its result with 0 }
                          Result:=CAddNode.Create(EqualN,Result,COrdConstNode.Create(0,S8IntType,false));
                          if NodeType=unequaln then
                            Result:=CNotNode.Create(Result);
                        end
                      else
                        begin
                          { compare the pointer with nil (for ansistrings etc), }
                          { faster than getting the length (JM)                 }
                          Result:= CAddNode.Create(NodeType,
                            CTypeConvNode.Create_Internal(Left,VoidPointerType),
                            CPointerConstNode.Create(0,VoidPointerType));
                        end;
                    end;
                  { left is reused }
                  Left := nil;
                  { right isn't }
                  Right.free;
                  Right := nil;
                  exit;
                end;
              { no string constant -> call compare routine }
              lCompareFunctionName := 'fpc_'+TStringDef(Left.ResultDef).StringTypName+'_compare';
              { for equality checks use optimized version }
              if NodeType in [EqualN,unequaln] then
                lCompareFunctionName := lCompareFunctionName + '_equal';

              Result := CCallNode.CreateIntern(lCompareFunctionName,
                CCallParaNode.Create(Right,CCallParaNode.Create(Left,nil)));
              { and compare its result with 0 according to the original operator }
              Result := CAddNode.Create(NodeType,Result,
                COrdConstNode.Create(0,S8IntType,false));
              Left := nil;
              Right := nil;
            end;
          else
            InternalError(2019050520);
        end;
      end;


    function TAddNode.First_AddSet : TNode;

      procedure CallVarSetHelper(const ANode : string);
        var
          lNewStatement : TStatementNode;
          lTemp    : TTempCreateNode;
        begin
          { directly load the result set into the assignee if possible }
          if Assigned(AktAssignmentNode) and
              (AktAssignmentNode.Right=Self) and
              (AktAssignmentNode.Left.ResultDef=ResultDef) and
              Valid_For_Var(AktAssignmentNode.Left,false) then
            begin
              Result:=CCallNode.CreateIntern(ANode,
                CCallParaNode.Create(COrdConstNode.Create(ResultDef.Size,SIntType,false),
                CCallParaNode.Create(AktAssignmentNode.Left.GetCopy,
                CCallParaNode.Create(Right,
                CCallParaNode.Create(Left,nil))))
              );

              { remove reused parts from original node }
              Left:=nil;
              Right:=nil;

              include(AktAssignmentNode.AssignmentNodeFlags,anf_assign_done_in_right);
              FirstPass(Result);
            end
          else
            begin
              { add two var sets }
              Result:=InternalStatements(lNewStatement);

              { create temp for result }
              lTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);
              AddStatement(lNewStatement,lTemp);

              AddStatement(lNewStatement,CCallNode.CreateIntern(ANode,
                CCallParaNode.Create(COrdConstNode.Create(ResultDef.Size,SIntType,false),
                CCallParaNode.Create(CTempRefNode.Create(lTemp),
                CCallParaNode.Create(Right,
                CCallParaNode.Create(Left,nil)))))
              );

              { remove reused parts from original node }
              Left:=nil;
              Right:=nil;
              { the last statement should return the value as
                location and type, this is done be referencing the
                temp and converting it first from a persistent temp to
                normal temp }
              AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTemp));
              AddStatement(lNewStatement,CTempRefNode.Create(lTemp));
            end;
        end;

      var
        lProcName: string[31];
        lTempNode: TNode;
        lNewStatement : TStatementNode;
        lTemp    : TTempCreateNode;
        lNoTemp: Boolean;
      begin
        Result:=nil;

        case NodeType of
          EqualN,unequaln,lten,gten:
            begin
              case NodeType of
                EqualN,unequaln:
                  lProcName := 'fpc_varset_comp_sets';
                lten,gten:
                  begin
                    lProcName := 'fpc_varset_contains_sets';
                    { (left >= right) = (right <= left) }
                    if NodeType = gten then
                      begin
                        lTempNode := Left;
                        Left := Right;
                        Right := lTempNode;
                      end;
                    end;
                  else
                    InternalError(2013112911);
                end;
                Result := CCallNode.CreateInternRes(lProcName,
                  CCallParaNode.Create(COrdConstNode.Create(Left.ResultDef.Size,SIntType,false),
                  CCallParaNode.Create(Right,
                  CCallParaNode.Create(Left,nil))),ResultDef);
                { left and right are reused as parameters }
                Left := nil;
                Right := nil;
                { for an unequaln, we have to negate the result of comp_sets }
                if NodeType = unequaln then
                  Result := CNotNode.Create(Result);
            end;
          addn:
            begin
              { can we directly write into the result? }
              lNoTemp:=Assigned(AktAssignmentNode) and
                (AktAssignmentNode.Right=Self) and
                (AktAssignmentNode.Left.ResultDef=Self.ResultDef) and
                Valid_For_Var(AktAssignmentNode.Left,false);

              { optimize first loading of a set }
              if (Right.NodeType=setelementn) and
                  not(Assigned(TSetElementNode(Right).Right)) and
                  Is_EmptySet(Left) then
                begin
                  { adjust for set base }
                  TSetElementNode(Right).Left:=CAddNode.Create(subn,
                    CTypeConvNode.Create_Internal(TSetElementNode(Right).Left,SIntType),
                    COrdConstNode.Create(TSetDef(ResultDef).SetBase,SIntType,false));

                  if lNoTemp then
                    begin
                      Result:=CCallNode.CreateIntern('fpc_varset_create_element',
                        CCallParaNode.Create(AktAssignmentNode.Left.GetCopy,
                        CCallParaNode.Create(COrdConstNode.Create(ResultDef.Size,SIntType,false),
                        CCallParaNode.Create(TSetElementNode(Right).Left,nil))));
                      include(AktAssignmentNode.AssignmentNodeFlags,anf_assign_done_in_right);
                    end
                  else
                    begin
                      Result:=InternalStatements(lNewStatement);

                      { create temp for result }
                      lTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);
                      AddStatement(lNewStatement,lTemp);

                      AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_varset_create_element',
                        CCallParaNode.Create(CTempRefNode.Create(lTemp),
                        CCallParaNode.Create(COrdConstNode.Create(ResultDef.Size,SIntType,false),
                        CCallParaNode.Create(TSetElementNode(Right).Left,nil))))
                      );

                      { the last statement should return the value as
                        location and type, this is done be referencing the
                        temp and converting it first from a persistent temp to
                        normal temp }
                      AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTemp));
                      AddStatement(lNewStatement,CTempRefNode.Create(lTemp));
                    end;
                  TSetElementNode(Right).Left:=nil;
                end
              else
                begin
                  if Right.NodeType=setelementn then
                    begin
                      if lNoTemp then
                        begin
                          { add a range or a single element? }
                          if Assigned(TSetElementNode(Right).Right) then
                            begin
                              { adjust for set base }
                              TSetElementNode(Right).Left:=CAddNode.Create(subn,
                                CTypeConvNode.Create_Internal(TSetElementNode(Right).Left,SIntType),
                                COrdConstNode.Create(TSetDef(ResultDef).SetBase,SIntType,false));

                              { adjust for set base }
                              TSetElementNode(Right).Right:=CAddNode.Create(subn,
                                CTypeConvNode.Create_Internal(TSetElementNode(Right).Right,SIntType),
                                COrdConstNode.Create(TSetDef(ResultDef).SetBase,SIntType,false));

                              Result:=CCallNode.CreateIntern('fpc_varset_set_range',
                                CCallParaNode.Create(COrdConstNode.Create(ResultDef.Size,SIntType,false),
                                CCallParaNode.Create(TSetElementNode(Right).Right,
                                CCallParaNode.Create(TSetElementNode(Right).Left,
                                CCallParaNode.Create(AktAssignmentNode.Left.GetCopy,
                                CCallParaNode.Create(Left,nil))))));
                            end
                          else
                            begin
                              { s:=s+[element]; ? }
                              if Left.IsEqual(AktAssignmentNode.Left) then
                                Result:=CInlineNode.CreateIntern(in_include_x_y,false,CCallParaNode.Create(AktAssignmentNode.Left.GetCopy,
                                  CCallParaNode.Create(CTypeConvNode.Create_Internal(TSetElementNode(Right).Left,TSetDef(ResultDef).ElementDef),nil)))
                              else
                                begin
                                  { adjust for set base }
                                  TSetElementNode(Right).Left:=CAddNode.Create(subn,
                                    CTypeConvNode.Create_Internal(TSetElementNode(Right).Left,SIntType),
                                    COrdConstNode.Create(TSetDef(ResultDef).SetBase,SIntType,false));

                                  Result:=CCallNode.CreateIntern('fpc_varset_set',
                                    CCallParaNode.Create(COrdConstNode.Create(ResultDef.Size,SIntType,false),
                                    CCallParaNode.Create(CTypeConvNode.Create_Internal(TSetElementNode(Right).Left,SIntType),
                                    CCallParaNode.Create(AktAssignmentNode.Left.GetCopy,
                                    CCallParaNode.Create(Left,nil)))));
                                end;
                            end;

                          include(AktAssignmentNode.AssignmentNodeFlags,anf_assign_done_in_right);
                        end
                      else
                        begin
                          { adjust for set base }
                          TSetElementNode(Right).Left:=CAddNode.Create(subn,
                            CTypeConvNode.Create_Internal(TSetElementNode(Right).Left,SIntType),
                            COrdConstNode.Create(TSetDef(ResultDef).SetBase,SIntType,false));

                          Result:=InternalStatements(lNewStatement);

                          { create temp for result }
                          lTemp:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);
                          AddStatement(lNewStatement,lTemp);

                          { add a range or a single element? }
                          if Assigned(TSetElementNode(Right).Right) then
                            begin
                              { adjust for set base }
                              TSetElementNode(Right).Right:=CAddNode.Create(subn,
                                CTypeConvNode.Create_Internal(TSetElementNode(Right).Right,SIntType),
                                COrdConstNode.Create(TSetDef(ResultDef).SetBase,SIntType,false));
                              AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_varset_set_range',
                                CCallParaNode.Create(COrdConstNode.Create(ResultDef.Size,SIntType,false),
                                CCallParaNode.Create(TSetElementNode(Right).Right,
                                CCallParaNode.Create(TSetElementNode(Right).Left,
                                CCallParaNode.Create(CTempRefNode.Create(lTemp),
                                CCallParaNode.Create(Left,nil))))))
                              );
                            end
                          else
                            AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_varset_set',
                              CCallParaNode.Create(COrdConstNode.Create(ResultDef.Size,SIntType,false),
                              CCallParaNode.Create(CTypeConvNode.Create_Internal(TSetElementNode(Right).Left,SIntType),
                              CCallParaNode.Create(CTempRefNode.Create(lTemp),
                              CCallParaNode.Create(Left,nil)))))
                            );
                          { the last statement should return the value as
                            location and type, this is done be referencing the
                            temp and converting it first from a persistent temp to
                            normal temp }
                          AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTemp));
                          AddStatement(lNewStatement,CTempRefNode.Create(lTemp));
                        end;
                      { remove reused parts from original node }
                      TSetElementNode(Right).Right:=nil;
                      TSetElementNode(Right).Left:=nil;
                      Left:=nil;
                    end
                  else
                    CallVarSetHelper('fpc_varset_add_sets');
                end
            end;
          subn:
            CallVarSetHelper('fpc_varset_sub_sets');
          symdifn:
            CallVarSetHelper('fpc_varset_symdif_sets');
          muln:
            CallVarSetHelper('fpc_varset_mul_sets');
          else
            InternalError(200609241);
        end;
      end;


    function TAddNode.First_AddDynArray : TNode;
      var
        lNewStatement : TStatementNode;
        lTempNode (*,tempnode2*) : TTempCreateNode;
        lPara: TCallParaNode;
      begin
        Result:=nil;
        { when we get here, we are sure that both the left and the right }
        { node are both strings of the same stringtype (JM)              }
        case NodeType of
          addn:
            begin
              if (Left.NodeType=arrayconstructorn) and (TArrayConstructorNode(Left).isempty) then
                begin
                  Result:=Right;
                  Left.free;
                  Left:=nil;
                  Right:=nil;
                  exit;
                end;
              if (Right.NodeType=arrayconstructorn) and (TArrayConstructorNode(Right).isempty) then
                begin
                  Result:=Left;
                  Left:=nil;
                  Right.free;
                  Right:=nil;
                  exit;
                end;
              { create the call to the concat routine both strings as arguments }
              if Assigned(AktAssignmentNode) and
                  (AktAssignmentNode.Right=Self) and
                  (AktAssignmentNode.Left.ResultDef=ResultDef) and
                  Valid_For_Var(AktAssignmentNode.Left,false) then
                begin
                  lPara:=CCallParaNode.Create(
                          CTypeConvNode.Create_Internal(Right,VoidCodePointerType),
                        CCallParaNode.Create(
                          CTypeConvNode.Create_Internal(Left,VoidCodePointerType),
                        CCallParaNode.Create(
                          CAddrNode.Create_Internal(CRTTINode.Create(TStoredDef(ResultDef),initrtti,rdt_normal)),
                        CCallParaNode.Create(
                          CTypeConvNode.Create_Internal(AktAssignmentNode.Left.GetCopy,VoidCodePointerType),nil)
                        )));
                  Result:=CCallNode.CreateIntern(
                            'fpc_dynarray_concat',
                            lPara
                          );
                  include(AktAssignmentNode.AssignmentNodeFlags,anf_assign_done_in_right);
                  FirstPass(Result);
                end
              else
                begin
                  Result:=InternalStatements(lNewStatement);
                  lTempNode:=CTempCreateNode.Create(ResultDef,ResultDef.Size,tt_persistent,true);
                  AddStatement(lNewStatement,lTempNode);
                  lPara:=CCallParaNode.Create(
                          CTypeConvNode.Create_Internal(Right,VoidCodePointerType),
                        CCallParaNode.Create(
                          CTypeConvNode.Create_Internal(Left,VoidCodePointerType),
                        CCallParaNode.Create(
                          CAddrNode.Create_Internal(CRTTINode.Create(TStoredDef(ResultDef),initrtti,rdt_normal)),
                        CCallParaNode.Create(
                          CTypeConvNode.Create_Internal(CTempRefNode.Create(lTempNode),VoidCodePointerType),nil)
                        )));
                  AddStatement(
                    lNewStatement,
                    CCallNode.CreateIntern(
                      'fpc_dynarray_concat',
                      lPara
                    )
                  );
                  AddStatement(lNewStatement,CTempDeleteNode.Create_Normal_Temp(lTempNode));
                  AddStatement(lNewStatement,CTempRefNode.Create(lTempNode));
                end;
              { we reused the arguments }
              Left := nil;
              Right := nil;
            end;
          unequaln,EqualN:
            ExpectLoc:=LOC_FLAGS;
          else
            InternalError(2018030301);
          end;
      end;


    function TAddNode.Use_Generic_Mul32To64: Boolean;
      begin
        Result := true;
      end;


    function TAddNode.Use_Generic_Mul64Bit: Boolean;
      begin
        Result := true;
      end;


    function TAddNode.TryMakeMul32To64: Boolean;

      function CanBe32BitInt(AValue: TConstExprInt; out ACanBeSignedConst, ACanBeUnsignedConst: Boolean): Boolean;
        begin
          Result := ((AValue >= Int64(low(LongInt))) and (AValue <= Int64(high(LongInt)))) or
                    ((AValue >= QWord(low(Cardinal))) and (AValue <= QWord(high(Cardinal))));
          ACanBeSignedConst:=AValue<=Int64(high(LongInt));
          ACanBeUnsignedConst:=AValue>=0;
        end;

      function Is32BitOrdConst(ANode: TNode; out ACanBeSignedConst, ACanBeUnsignedConst: Boolean): Boolean;
        begin
          ACanBeSignedConst:=false;
          ACanBeUnsignedConst:=false;
          Result := (ANode.NodeType = ordconstn) and
                    CanBe32BitInt(TOrdConstNode(ANode).Value, ACanBeSignedConst, ACanBeUnsignedConst);
        end;

      function Is32To64TypeConv(ANode: TNode): Boolean;
        begin
          Result := (ANode.NodeType = typeconvn) and
                    Is_Integer(TTypeConvNode(ANode).Left.ResultDef) and
                    not Is_64Bit(TTypeConvNode(ANode).Left.ResultDef);
        end;

      var
        lTempNode: TNode;
        lLeftOriginallySigned,
        lCanBeSignedConst, lCanBeUnsignedConst, lSwapped: Boolean;
      begin
        Result := false;
        lSwapped := false;
        { make sure that if there is a constant, that it's on the right }
        if Left.NodeType = ordconstn then
          begin
            SwapLeftRight;
            lSwapped := true;
          end;
        if Is32To64TypeConv(Left) then
          begin
            lLeftOriginallySigned:=Is_Signed(TTypeConvNode(Left).Left.ResultDef);
            if ((Is32BitOrdConst(Right,lCanBeSignedConst, lCanBeUnsignedConst) and
                 ((lLeftOriginallySigned and lCanBeSignedConst) or
                  (not lLeftOriginallySigned and lCanBeUnsignedConst))) or
                (Is32To64TypeConv(Right) and
                  ((lLeftOriginallySigned =
                    Is_Signed(TTypeConvNode(Right).Left.ResultDef)) or
                   (lLeftOriginallySigned and
                    (TOrdDef(TTypeConvNode(Right).Left.ResultDef).OrdType in [u8bit,u16bit]))))) then
              begin
                lTempNode := TTypeConvNode(Left).Left;
                TTypeConvNode(Left).Left := nil;
                Left.free;
                Left := lTempNode;
                if (Right.NodeType = typeconvn) then
                  begin
                    lTempNode := TTypeConvNode(Right).Left;
                    TTypeConvNode(Right).Left := nil;
                    Right.free;
                    Right := lTempNode;
                  end;
                if (Is_Signed(Left.ResultDef)) then
                  begin
                    InsertTypeConv_Internal(Left,S32IntType);
                    InsertTypeConv_Internal(Right,S32IntType);
                  end
                else
                  begin
                    InsertTypeConv_Internal(Left,U32IntType);
                    InsertTypeConv_Internal(Right,U32IntType);
                  end;
                FirstPass(Left);
                FirstPass(Right);
                Result := true;
              end;
          end;
        { pass_Typecheck caches left/right type and resultdef, so restore the
          original order }
        if not Result and lSwapped then
          SwapLeftRight;
      end;


    function TAddNode.Use_FMA : Boolean;
      begin
        Result:=false;
      end;


    function TAddNode.TryFMA(ALeftDef,ARightDef : TDef) : TNode;
      var
        lInlineNumber : TInlineNumber;
      begin
        Result:=nil;
        if (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and
          Use_FMA and
          (NodeType in [addn,subn]) and
          (ARightDef.typ=floatdef) and (ALeftDef.typ=floatdef) and
          (Is_Single(ARightDef) or Is_Double(ARightDef)) and
          Equal_Defs(ARightDef,ALeftDef) and
          { transforming a*b+c into fma(a,b,c) makes only sense if c can be
            calculated easily. Consider a*b+c*d which results in

            fmul
            fmul
            fadd

            and in

            fmul
            fma

            when using the fma optimization. On a super scalar architecture, the first instruction
            sequence requires clock_cycles(fmul)+clock_cycles(fadd) clock cycles because the fmuls can be executed in parallel.
            The second sequence requires clock_cycles(fmul)+clock_cycles(fma) because the fma has to wait for the
            result of the fmul. Since typically clock_cycles(fma)>clock_cycles(fadd) applies, the first sequence is better.
          }
          (((Left.NodeType=muln) and (Node_Complexity(Right)<3)) or
           ((Right.NodeType=muln) and (Node_Complexity(Left)<3)) or
           ((Left.NodeType=inlinen) and
            (TInlineNode(Left).InlineNumber=in_sqr_real) and
             (Node_Complexity(Right)<3)) or
           ((Right.NodeType=inlinen) and
            (TInlineNode(Right).InlineNumber=in_sqr_real) and
            (Node_Complexity(Left)<3))
          ) then
          begin
            case TFloatDef(ALeftDef).FloatType of
              S32Real:
               lInlineNumber:=in_fma_single;
              S64Real:
               lInlineNumber:=in_fma_double;
              s80real:
               lInlineNumber:=in_fma_extended;
              else
                InternalError(2014042601);
            end;
            if Left.NodeType=muln then
              begin
                if NodeType=subn then
                  Result:=CInlineNode.Create(lInlineNumber,false,CCallParaNode.Create(CUnaryMinusNode.Create(Right),
                    CCallParaNode.Create(TAddNode(Left).Right,
                    CCallParaNode.Create(TAddNode(Left).Left,nil
                    ))))
                else
                  Result:=CInlineNode.Create(lInlineNumber,false,CCallParaNode.Create(Right,
                    CCallParaNode.Create(TAddNode(Left).Right,
                    CCallParaNode.Create(TAddNode(Left).Left,nil
                    ))));
                Right:=nil;
                TAddNode(Left).Right:=nil;
                TAddNode(Left).Left:=nil;
              end
            else if Right.NodeType=muln then
              begin
                if NodeType=subn then
                  Result:=CInlineNode.Create(lInlineNumber,false,CCallParaNode.Create(Left,
                    CCallParaNode.Create(CUnaryMinusNode.Create(TAddNode(Right).Right),
                    CCallParaNode.Create(TAddNode(Right).Left,nil
                    ))))
                else
                  Result:=CInlineNode.Create(lInlineNumber,false,CCallParaNode.Create(Left,
                    CCallParaNode.Create(TAddNode(Right).Right,
                    CCallParaNode.Create(TAddNode(Right).Left,nil
                    ))));
                Left:=nil;
                TAddNode(Right).Right:=nil;
                TAddNode(Right).Left:=nil;
              end
            else if (Left.NodeType=inlinen) and (TInlineNode(Left).InlineNumber=in_sqr_real) then
              begin
                if Node_Complexity(TInlineNode(Left).Left)=0 then
                  begin
                    if NodeType=subn then
                      Result:=CInlineNode.Create(lInlineNumber,false,CCallParaNode.Create(CUnaryMinusNode.Create(Right),
                        CCallParaNode.Create(TInlineNode(Left).Left.GetCopy,
                        CCallParaNode.Create(TInlineNode(Left).Left.GetCopy,nil
                        ))))
                    else
                      Result:=CInlineNode.Create(lInlineNumber,false,CCallParaNode.Create(Right,
                        CCallParaNode.Create(TInlineNode(Left).Left.GetCopy,
                        CCallParaNode.Create(TInlineNode(Left).Left.GetCopy,nil
                        ))));
                    Right:=nil;
                  end;
              end
            { we get here only if right is a sqr node }
            else if (Right.NodeType=inlinen) and (TInlineNode(Right).InlineNumber=in_sqr_real) then
              begin
                if Node_Complexity(TInlineNode(Right).Left)=0 then
                  begin
                    if NodeType=subn then
                      Result:=CInlineNode.Create(lInlineNumber,false,CCallParaNode.Create(Left,
                        CCallParaNode.Create(CUnaryMinusNode.Create(TInlineNode(Right).Left.GetCopy),
                        CCallParaNode.Create(TInlineNode(Right).Left.GetCopy,nil
                        ))))
                    else
                      Result:=CInlineNode.Create(lInlineNumber,false,CCallParaNode.Create(Left,
                        CCallParaNode.Create(TInlineNode(Right).Left.GetCopy,
                        CCallParaNode.Create(TInlineNode(Right).Left.GetCopy,nil
                        ))));
                    Left:=nil;
                  end;
              end;
          end;
      end;


    function TAddNode.First_Add64BitInt: TNode;
      var
        lProcName: string[31];
        lPower: LongInt;
      begin
        Result := nil;
        { create helper calls mul }
        if NodeType <> muln then
          exit;

        { make sure that if there is a constant, that it's on the right }
        if Left.NodeType = ordconstn then
          SwapLeftRight;

        { can we use a shift instead of a mul? }
        if not (cs_check_overflow in CurrentSettings.LocalSwitches) and
           (Right.NodeType = ordconstn) and
           IsPowerOf2(TOrdConstNode(Right).Value,lPower) then
          begin
            TOrdConstNode(Right).Value := lPower;
            Result := CShlShrNode.Create(shln,Left,Right);
            { left and right are reused }
            Left := nil;
            Right := nil;
            { return firstpassed new node }
            exit;
          end;

        if TryMakeMul32To64 then
          begin
            { this uses the same criteria for signedness as the 32 to 64-bit mul
              handling in the i386 code generator }
            if Is_Signed(Left.ResultDef) and Is_Signed(Right.ResultDef) then
              lProcName := 'fpc_mul_longint_to_int64'
            else
              lProcName := 'fpc_mul_dword_to_qword';

            Right := CCallParaNode.Create(Right,CCallParaNode.Create(Left,nil));
            Result := CCallNode.CreateIntern(lProcName,Right);
            Left := nil;
            Right := nil;
          end
        else
          begin
            { can full 64-bit multiplication be handled inline? }
            if not Use_Generic_Mul64Bit then
              begin
                { generic handling replaces this node with call to fpc_mul_int64,
                  whose result is int64 }
                if Is_Currency(ResultDef) then
                  ResultDef:=S64IntType;
                exit;
              end;

            { when currency is used set the result of the
              parameters to s64bit, so they are not converted }
            if Is_Currency(ResultDef) then
              begin
                Left.ResultDef:=S64IntType;
                Right.ResultDef:=S64IntType;
              end;

            { otherwise, create the parameters for the helper }
            Right :=   CCallParaNode.Create(Right,CCallParaNode.Create(Left,nil));
            Left := nil;
            { only qword needs the unsigned code, the
              signed code is also used for currency }
            if Is_Signed(ResultDef) then
              lProcName := 'fpc_mul_int64'
            else
              lProcName := 'fpc_mul_qword';
            if cs_check_overflow in CurrentSettings.LocalSwitches then
              lProcName := lProcName + '_checkoverflow';

            Result := CCallNode.CreateIntern(lProcName,Right);
            Right := nil;
          end;
      end;


    function TAddNode.First_AddPointer: TNode;
      begin
        Result:=nil;
        ExpectLoc:=LOC_REGISTER;
      end;


    function TAddNode.First_CmpPointer: TNode;
      begin
        Result:=nil;
        ExpectLoc:=LOC_FLAGS;
      end;



{$ifdef cpuneedsmulhelper}
    function TAddNode.Use_Mul_Helper: Boolean;
      begin
        Result:=(NodeType=muln) and
                not(TOrdDef(ResultDef).OrdType in [u8bit,s8bit
                ]);
      end;
{$endif cpuneedsmulhelper}


    function TAddNode.Pass_1 : TNode;

      function isconstsetfewelements(ANode : TNode) : Boolean;
        begin
          Result:=(ANode.NodeType=setconstn) and (TSetConstNode(ANode).elements<=4);
        end;

      var
{$ifdef addstringopt}
        lStringOptNode: TNode;
{$endif addstringopt}
         lRightDef,lLeftDef   : TDef;
         lIndex,lIndex2    : LongInt;
         lLeftNodeType,lRightNodeType   : TNodeType;
{$ifdef cpuneedsmulhelper}
         lProcName : string[32];
{$endif cpuneedsmulhelper}
        lTempNode,lVarSetNode: TNode;
        lMultiplyNode : TAddNode;
        lConstSetNode : TSetConstNode;
        lTryCreateInNodes : Boolean;
      begin
         Result:=nil;
         { Can we optimize multiple string additions into a single call?
           This need to be done on a complete tree to detect the multiple
           add nodes and is therefor done before the subtrees are processed }
         if canbemultistringadd(Self) then
           begin
             Result:=genmultistringadd(Self);
             exit;
           end;

         { Can we optimize multiple dyn. array additions into a single call?
           This need to be done on a complete tree to detect the multiple
           add nodes and is therefor done before the subtrees are processed }
         if (m_array_operators in CurrentSettings.ModeSwitches) and canbemultidynarrayadd(Self) then
           begin
             Result:=genmultidynarrayadd(Self);
             exit;
           end;

         { typical set tests like (s*[const. set])<>/=[] can be converted into an or'ed chain of in tests
           for var sets if const. set contains only a few elements }
         if (cs_opt_level1 in CurrentSettings.OptimizerSwitches) and (NodeType in [unequaln,EqualN]) and (Left.ResultDef.typ=setdef) and not(Is_SmallSet(Left.ResultDef)) then
           begin
             lTryCreateInNodes:=false;
             lMultiplyNode:=nil;
             if (Is_EmptySet(Right) and (Left.NodeType=muln) and
                 (isconstsetfewelements(TAddNode(Left).Right) or isconstsetfewelements(TAddNode(Left).Left))) then
               begin
                 lTryCreateInNodes:=true;
                 lMultiplyNode:=TAddNode(Left);
               end
             else if (Is_EmptySet(Left) and (Right.NodeType=muln) and
               (isconstsetfewelements(TAddNode(Right).Right) or isconstsetfewelements(TAddNode(Right).Left))) then
               begin
                 lTryCreateInNodes:=true;
                 lMultiplyNode:=TAddNode(Right);
               end;

             if lTryCreateInNodes then
               begin
                 lConstSetNode:=nil;
                 lVarSetNode:=nil;
                 if isconstsetfewelements(lMultiplyNode.Right) then
                   begin
                     lConstSetNode:=TSetConstNode(lMultiplyNode.Right);
                     lVarSetNode:=lMultiplyNode.Left;
                   end
                 else
                   begin
                     lConstSetNode:=TSetConstNode(lMultiplyNode.Left);
                     lVarSetNode:=lMultiplyNode.Right;
                   end;
                 { the node is copied so it might have no side effects, if the complexity is too, cse should fix it, so
                   do not check complexity }
                 if not(Might_Have_SideEffects(lVarSetNode)) then
                   begin
                     Result:=nil;
                     for lIndex:=low(TConstSet) to high(TConstSet) do
                       if lIndex in lConstSetNode.ValueSet^ then
                         begin
                           lTempNode:=CInNode.Create(COrdConstNode.Create(lIndex,TSetDef(lConstSetNode.ResultDef).ElementDef,false),lVarSetNode.GetCopy);
                           if Assigned(Result) then
                             Result:=CAddNode.Create_Internal(orn,Result,lTempNode)
                           else
                             Result:=lTempNode;
                         end;
                     if NodeType=EqualN then
                       Result:=CNotNode.Create(Result);
                     exit;
                   end;
               end;
           end;

        { get rid of adding empty sets generated by set constructors (s+([]+[..]))

          this needs to be done before firstpass, else the set additions get already converted into calls }
        if (ResultDef.typ=setdef) and (NodeType=addn) and (Right.NodeType=addn) and (Is_EmptySet(TAddNode(Right).Left)) then
          begin
            Result:=CAddNode.Create(addn,Left,TAddNode(Right).Right);
            Left:=nil;
            TAddNode(Right).Right:=nil;
            exit;
          end;

         { first do the two subtrees }
         FirstPass(Left);
         FirstPass(Right);

         if CodeGenError then
           exit;

         { load easier access variables }
         lRightDef:=Right.ResultDef;
         lLeftDef:=Left.ResultDef;
         lRightNodeType:=Right.NodeType;
         lLeftNodeType:=Left.NodeType;

         { int/int gives real/real! }
         if NodeType=slashn then
           begin
             ExpectLoc:=LOC_FPUREGISTER;
           end

         { if both are orddefs then check sub types }
         else if (lLeftDef.typ=orddef) and (lRightDef.typ=orddef) then
           begin
             { optimize multiplication by a power of 2 }
             if not(cs_check_overflow in CurrentSettings.LocalSwitches) and
                (NodeType = muln) and
                not Is_Currency(ResultDef) and
                (((Left.NodeType = ordconstn) and
                  IsPowerOf2(TOrdConstNode(Left).Value,lIndex)) or
                 ((Right.NodeType = ordconstn) and
                  IsPowerOf2(TOrdConstNode(Right).Value,lIndex2))) then
               begin
                 { it could be that we are converting a 32x32 -> 64 multiplication:
                   in this case, we have to restore the type conversion }
                 InsertTypeConv_Internal(Left,ResultDef);
                 InsertTypeConv_Internal(Right,ResultDef);
                 if ((Left.NodeType = ordconstn) and
                     IsPowerOf2(TOrdConstNode(Left).Value,lIndex)) then
                   begin
                     TOrdConstNode(Left).Value := lIndex;
                     Result := CShlShrNode.Create(shln,Right,Left);
                   end
                 else
                   begin
                     TOrdConstNode(Right).Value := lIndex2;
                     Result := CShlShrNode.Create(shln,Left,Right);
                   end;
                 Result.ResultDef := ResultDef;
                 Left := nil;
                 Right := nil;
                 exit;
               end;

           { 2 booleans ? }
             if Is_Boolean(lLeftDef) and Is_Boolean(lRightDef) then
              begin
                if DoShortBoolEval(Self) then
                  ExpectLoc:=LOC_JUMP
                else
                 begin
                   if NodeType in [ltn,lten,gtn,gten,EqualN,unequaln] then
                     ExpectLoc:=LOC_FLAGS
                   else
                     ExpectLoc:=LOC_REGISTER;
                 end;
              end
             else
             { Both are chars? only convert to shortstrings for addn }
              if Is_Char(lLeftDef) then
               begin
                 if NodeType=addn then
                  InternalError(200103291);
                 ExpectLoc:=LOC_FLAGS;
               end
             else if (NodeType=muln) and
                Is_64BitInt(ResultDef) and
                not Use_Generic_Mul32To64 and
                TryMakeMul32To64 then
               begin
                 { if the code generator can handle 32 to 64-bit muls,
                   we're done here }
                 ExpectLoc:=LOC_REGISTER;
               end
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              { is there a 64 bit type ? }
             else if (TOrdDef(lLeftDef).OrdType in [s64bit,u64bit,scurrency]) then
               begin
                 Result := First_Add64BitInt;
                 if Assigned(Result) then
                   exit;
                  if NodeType in [addn,subn,muln,andn,orn,xorn] then
                    ExpectLoc:=LOC_REGISTER
                  else
                    ExpectLoc:=LOC_JUMP;
               end
{$endif not(cpu64bitalu) and not(cpuhighleveltarget)}
             { generic 32bit conversion }
             else
               begin
{$ifdef cpuneedsmulhelper}
                 if Use_Mul_Helper then
                   begin
                     Result := nil;

                     case TOrdDef(ResultDef).OrdType of
                       s8bit:
                         lProcName := 'fpc_mul_shortint';
                       u8bit:
                         lProcName := 'fpc_mul_byte';
                       s16bit:
                         lProcName := 'fpc_mul_integer';
                       u16bit:
                         lProcName := 'fpc_mul_word';
                       s32bit:
                         lProcName := 'fpc_mul_longint';
                       u32bit:
                         lProcName := 'fpc_mul_dword';
                       else
                         InternalError(2011022301);
                     end;
                     if cs_check_overflow in CurrentSettings.LocalSwitches then
                       lProcName:=lProcName+'_checkoverflow';
                     Result := CCallNode.CreateIntern(lProcName,
                       CCallParaNode.Create(Right,
                       CCallParaNode.Create(Left,nil)));
                     Left := nil;
                     Right := nil;
                     FirstPass(Result);
                     exit;
                   end;
{$endif cpuneedsmulhelper}
                  if NodeType in [addn,subn,muln,andn,orn,xorn] then
                    ExpectLoc:=LOC_REGISTER
{$if not defined(cpuhighleveltarget)}
                  else if TOrdDef(lLeftDef).Size>sizeof(aint) then
                    ExpectLoc:=LOC_JUMP
{$endif}
                  else
                    ExpectLoc:=LOC_FLAGS;
              end;
           end

         { left side a setdef, must be before string processing,
           else array constructor can be seen as array of char (PFV) }
         else if (lLeftDef.typ=setdef) then
           begin
             { small sets are handled inline by the compiler.
               small set doesn't have support for adding ranges }
             if Is_SmallSet(lLeftDef) and
                not(
                    (Right.NodeType=setelementn) and
                    Assigned(TSetElementNode(Right).Right)
                   ) then
               begin
                 if NodeType in [ltn,lten,gtn,gten,EqualN,unequaln] then
                   ExpectLoc:=LOC_FLAGS
                 else
                   ExpectLoc:=LOC_REGISTER;
               end
             else
               begin
                 Result := First_AddSet;
                 if Assigned(Result) then
                   exit;
                 ExpectLoc:=LOC_CREFERENCE;
               end;
           end

         { compare pchar by addresses like BP/Delphi }
         else if Is_PChar(lLeftDef) then
           begin
             if NodeType in [addn,subn,muln,andn,orn,xorn] then
               Result:=First_AddPointer
             else
               Result:=First_CmpPointer;
           end

         { is one of the operands a string }
         else if (lLeftDef.typ=stringdef) then
            begin
              if Is_WideString(lLeftDef) then
                begin
                   { this is only for add, the comparison is handled later }
                   ExpectLoc:=LOC_REGISTER;
                end
              else if Is_UnicodeString(lLeftDef) then
                begin
                   { this is only for add, the comparison is handled later }
                   ExpectLoc:=LOC_REGISTER;
                end
              else if Is_AnsiString(lLeftDef) then
                begin
                   { this is only for add, the comparison is handled later }
                   ExpectLoc:=LOC_REGISTER;
                end
              else if Is_LongString(lLeftDef) then
                begin
                   { this is only for add, the comparison is handled later }
                   ExpectLoc:=LOC_REFERENCE;
                end
              else
                begin
{$ifdef addstringopt}
                   { can create a call which isn't handled by callparatemp }
                   if canbeaddsstringcharoptnode(Self) then
                     begin
                       lStringOptNode := genaddsstringcharoptnode(Self);
                       Pass_1 := lStringOptNode;
                       exit;
                     end
                   else
{$endif addstringopt}
                     begin
                       { Fix right to be shortstring }
                       if Is_Char(Right.ResultDef) then
                        begin
                          InsertTypeConv(Right,CShortStringType);
                          FirstPass(Right);
                        end;
                     end;
{$ifdef addstringopt}
                   { can create a call which isn't handled by callparatemp }
                   if canbeaddsstringcsstringoptnode(Self) then
                     begin
                       lStringOptNode := genaddsstringcsstringoptnode(Self);
                       Pass_1 := lStringOptNode;
                       exit;
                     end;
{$endif addstringopt}
                end;
             { otherwise, let addstring convert everything }
              Result := First_AddString;
              exit;
           end

         { is one a real float ? }
         else if (lRightDef.typ=floatdef) or (lLeftDef.typ=floatdef) then
            begin
              if NodeType in [addn,subn,muln,andn,orn,xorn] then
                ExpectLoc:=LOC_FPUREGISTER
              else
                ExpectLoc:=LOC_FLAGS;

              Result:=TryFMA(lLeftDef,lRightDef);
              if Assigned(Result) then
                exit;
            end

         { pointer comparison and subtraction }
         else if (lLeftDef.typ=pointerdef) then
            begin
              if NodeType in [addn,subn,muln,andn,orn,xorn] then
                Result:=First_AddPointer
              else
                Result:=First_CmpPointer;
           end

         else if Is_Implicit_Pointer_Object_Type(lLeftDef) then
            begin
              if lLeftDef.Size>sizeof(aint) then
                ExpectLoc:=LOC_JUMP
              else
                ExpectLoc:=LOC_FLAGS;
            end

         else if (lLeftDef.typ=classrefdef) then
            begin
              if lLeftDef.Size>sizeof(aint) then
                ExpectLoc:=LOC_JUMP
              else
                ExpectLoc:=LOC_FLAGS;
            end

         { support procvar=nil,procvar<>nil }
         else if ((lLeftDef.typ=procvardef) and (lRightNodeType=niln)) or
                 ((lRightDef.typ=procvardef) and (lLeftNodeType=niln)) then
            begin
              if (lLeftDef.typ=procvardef) and (TProcVarDef(lLeftDef).Size>sizeof(aint)) or
                 (lRightDef.typ=procvardef) and (TProcVarDef(lRightDef).Size>sizeof(aint)) then
                ExpectLoc:=LOC_JUMP
              else
                ExpectLoc:=LOC_FLAGS;
            end


         else if (lRightDef.typ=pointerdef) or (lLeftDef.typ=pointerdef) then
            begin
              Result:=First_AddPointer;
            end

         else  if (lRightDef.typ=procvardef) and
                  (lLeftDef.typ=procvardef) and
                  Equal_Defs(lRightDef,lLeftDef) then
           begin
             if TProcVarDef(lLeftDef).Size>sizeof(aint) then
               ExpectLoc:=LOC_JUMP
             else
               ExpectLoc:=LOC_FLAGS;
           end

         else if (lLeftDef.typ=enumdef) then
           begin
              if TEnumDef(lLeftDef).Size>sizeof(aint) then
                ExpectLoc:=LOC_JUMP
              else
                ExpectLoc:=LOC_FLAGS;
           end


         else if Is_Dynamic_Array(lLeftDef) or Is_Dynamic_Array(lRightDef) then
           begin
             Result:=First_AddDynArray;
             exit;
           end
         { the general solution is to convert to 32 bit int }
         else
           begin
             ExpectLoc:=LOC_REGISTER;
           end;
      end;


end.
