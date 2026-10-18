{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Type checking and register allocation for set/case nodes

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
unit nset;

{$i fpcdefs.inc}

interface

    uses
       SysUtils,CClasses,ConstExp,
       node,GlobType,Globals,
       aasmbase,ncon,nflw,symtype;

    type
       TLabelType = (ltOrdinal, ltConstString);

       PCaseLabel = ^TCaseLabel;
       TCaseLabel = record
          { unique blockid }
          BlockID : LongInt;
          { left and right tree node }
          Less,
          Greater : PCaseLabel;

          LabelLabel : TAsmLabel;

          { range type }
          case LabelType : TLabelType of
            ltOrdinal:
            (
              LowValue,
              HighValue       : TConstExprInt;
            );
            ltConstString:
            (
              LowString,
              HighString   : TStringConstNode;
            );
       end;

       PCaseBlock = ^TCaseBlock;
       TCaseBlock = record
          { label (only used in pass_generate_code) }
          BlockLabel : TAsmLabel;

          { shortcut - set to true if blocklabel isn't actually unique to the
            case block due to one of the following conditions:
            - if the node contains a jump, then the label is set to that jump's destination,
            - if the node is empty, the label is set to the end label. }
          Shortcut: Boolean;

          StatementLabel : TLabelNode;
          { instructions }
          Statement  : TNode;
       end;

       TSetElementNode = class(TBinaryNode)
          constructor Create(ALeft,ARight : TNode);virtual;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
       end;
       TSetElementNodeClass = class of TSetElementNode;

       TInNode = class(TBinOpNode)
          constructor Create(ALeft,ARight : TNode);virtual;reintroduce;
          function Pass_TypeCheck:TNode;override;
          function Simplify(AForInline : Boolean):TNode;override;
          function Pass_1 : TNode;override;
       end;
       TInNodeClass = class of TInNode;

       TRangeNode = class(TBinaryNode)
          constructor Create(ALeft,ARight : TNode);virtual;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
       end;
       TRangeNodeClass = class of TRangeNode;

       TCaseNode = class(TUnaryNode)
        strict private
          { Number of labels }
          FLabelCnt: Cardinal;
          { Number of individual values checked, counting each value in a range
           individually (e.g. 0..2 counts as 3). }
          FLabelCoverage: QWord;
          FCountsUpToDate: Boolean;

          function GetLabelCnt: Cardinal;
          function GetLabelCoverage: QWord;
          procedure UpdateCoverage;
          procedure CheckOrdinalCoverage;
        public
          Blocks    : TFPList;
          ElseBlock : TNode;

          constructor Create(ALeft:TNode);virtual;
          destructor Destroy;override;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          function DoGetCopy : TNode;override;
          procedure PrintNodeTree(var AText:text);override;
          procedure InsertIntoList(AList : TNodeList);override;
          function Pass_TypeCheck:TNode;override;
          function Pass_1 : TNode;override;
          function Simplify(AForInline:Boolean):TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
          procedure AddLabel(ABlockID:LongInt;const ALowValue,AHighValue : TConstExprInt); overload;
          procedure AddLabel(ABlockID:LongInt;ALowString,AHighString : TStringConstNode); overload;
          procedure AddBlock(ABlockID:LongInt;AStatement:TNode);
          procedure AddElseBlock(AStatement:TNode);

          property LabelCnt: Cardinal read GetLabelCnt;
          { returns one less than the covered case range, so that it
            does not overflow for a fully covered qword range }
          property LabelCoverage: QWord read GetLabelCoverage;
         protected
          FLabels    : PCaseLabel;
         public
          property Labels: PCaseLabel read FLabels;
       end;
       TCaseNodeClass = class of TCaseNode;

    var
       CSetElementNode : TSetElementNodeClass = TSetElementNode;
       CInNode : TInNodeClass = TInNode;
       CRangeNode : TRangeNodeClass = TRangeNode;
       CCaseNode : TCaseNodeClass = TCaseNode;

    { searches the highest label }
    function Case_Get_Max(ARoot : PCaseLabel) : TConstExprInt;
    { searches the lowest label }
    function Case_Get_Min(ARoot : PCaseLabel) : TConstExprInt;


implementation

    uses
      Verbose,CUtils,
      symconst,symdef,SymSym,SymTable,defutil,defcmp,
      htypechk,Pass_1,
      nadd,nbas,ncal,ncnv,nld,nutils,
      cgbase;


{*****************************************************************************
                           TSETELEMENTNODE
*****************************************************************************}

    constructor TSetElementNode.Create(ALeft,ARight : TNode);

      begin
         inherited Create(setelementn,ALeft,ARight);
      end;


    function TSetElementNode.Pass_TypeCheck:TNode;
      begin
         Result:=nil;
         TypeCheckPass(Left);
         if Assigned(Right) then
          TypeCheckPass(Right);
         Set_VarState(Left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
          exit;

         ResultDef:=Left.ResultDef;
      end;


    function TSetElementNode.Pass_1 : TNode;

      begin
         Result:=nil;
         FirstPass(Left);
         if Assigned(Right) then
          FirstPass(Right);
         if CodeGenError then
          exit;

         ExpectLoc:=Left.ExpectLoc;
      end;


{*****************************************************************************
                              TINNODE
*****************************************************************************}

    constructor TInNode.Create(ALeft,ARight : TNode);
      begin
         inherited Create(inn,ALeft,ARight);
      end;


    function TInNode.Pass_TypeCheck:TNode;

      var
        lNode : TNode;

        function CreateSetConst(ASetDef : TSetDef) : PConstSet;
        var
          lConstSet : PConstSet;
          lIndex : LongInt;
        begin
          new(lConstSet);
          case ASetDef.ElementDef.typ of
            enumdef :
              begin
                for lIndex := 0 to TEnumDef(ASetDef.ElementDef).SymTable.SymList.Count - 1 do
                  begin
                    include(lConstSet^,TEnumSym(TEnumDef(ASetDef.ElementDef).SymTable.SymList[lIndex]).Value);
                  end;
              end;
            orddef :
              begin
                for lIndex:=Int64(TOrdDef(ASetDef.ElementDef).low) to Int64(TOrdDef(ASetDef.ElementDef).high) do
                  include(lConstSet^,lIndex);
              end;
            else
              InternalError(2019050516);
          end;
          CreateSetConst:=lConstSet;
        end;

      begin
         Result:=nil;

         ResultDef:=PasBool1Type;
         TypeCheckPass(Right);
         Set_VarState(Right,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
          exit;

         { Convert array constructor first to set }
         if Is_Array_Constructor(Right.ResultDef) then
          begin
            ArrayConstructor_To_Set(Right);
            if CodeGenError then
             exit;
          end;

         TypeCheckPass(Left);
         Set_VarState(Left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         if not Assigned(Left.ResultDef) then
           InternalError(20021126);

         { avoid any problems with type parameters later on }
         if Is_TypeParam(Left.ResultDef) or Is_TypeParam(Right.ResultDef) then
           begin
             ResultDef:=CUndefinedType;
             exit;
           end;

         lNode:=self;
         if IsBinaryOverloaded(lNode,[]) then
           begin
             Result:=lNode;
             exit;
           end;

         if Right.ResultDef.typ<>setdef then
           CGMessage(sym_e_set_expected);

         if CodeGenError then
           exit;

         if not Is_Ordinal(Left.ResultDef) or (Left.ResultDef.Size > U32IntType.Size) then
           begin
             CGMessage(type_h_in_range_check);
             if Is_Signed(Left.ResultDef) then
               InsertTypeConv(Left,S32IntType)
             else
               InsertTypeConv(Left,U32IntType);
           end
         else if Assigned(TSetDef(Right.ResultDef).ElementDef) and
                 not(Is_Integer(TSetDef(Right.ResultDef).ElementDef) and
                     Is_Integer(Left.ResultDef)) then
            { Type conversion to check things like 'char in set_of_byte'. }
            { Can't use is_subequal because that will fail for            }
            { 'widechar in set_of_char'                                   }
            { Can't use the type conversion for integers because then     }
            { "longint in set_of_byte" will give a range check error      }
            { instead of false                                            }
            InsertTypeConv(Left,TSetDef(Right.ResultDef).ElementDef);

         { empty set then return false }
         if not Assigned(TSetDef(Right.ResultDef).ElementDef) or
            ((Right.NodeType = setconstn) and
             (TNormalSet(TSetConstNode(Right).ValueSet^) = [])) then
          begin
            lNode:=COrdConstNode.Create(0,PasBool1Type,false);
            TypeCheckPass(lNode);
            Result:=lNode;
            exit;
          end;

         Result:=Simplify(false);
      end;


    function TInNode.Simplify(AForInline : Boolean):TNode;
      var
        lNode : TNode;
      begin
         Result:=nil;

         { constant evaluation }
         if (Left.NodeType=ordconstn) then
           begin
             if (Right.NodeType=setconstn) then
               begin
                 { tordconstnode.value is int64 -> signed -> the expression }
                 { below will be converted to longint on 32 bit systems due }
                 { to the rule above -> will give range check error if      }
                 { value > high(longint) if we don't take the signedness    }
                 { into account                                             }
                 if TOrdConstNode(Left).Value.signed then
                   lNode:=COrdConstNode.Create(Byte(TOrdConstNode(Left).Value.svalue in TSetConstNode(Right).ValueSet^),
                     PasBool1Type,true)
                 else
                   lNode:=COrdConstNode.Create(Byte(TOrdConstNode(Left).Value.uvalue in TSetConstNode(Right).ValueSet^),
                     PasBool1Type,true);
                 TypeCheckPass(lNode);
                 Result:=lNode;
                 exit;
               end
             else
               begin
                 if (TOrdConstNode(Left).Value<Int64(TSetDef(Right.ResultDef).SetBase)) or
                    (TOrdConstNode(Left).Value>Int64(TSetDef(Right.ResultDef).SetMax)) then
                   begin
                     lNode:=COrdConstNode.Create(0, PasBool1Type, true);
                     TypeCheckPass(lNode);
                     Result:=lNode;
                     exit;
                   end;
               end;
           end
         { a in [a] => true, if a has no side effects }
         else if (Right.NodeType=addn) and
           (TAddNode(Right).Left.NodeType=setconstn) and
           (TSetConstNode(TAddNode(Right).Left).elements=0) and
           (TAddNode(Right).Right.NodeType=setelementn) and
           (TSetElementNode(TAddNode(Right).Right).Right=nil) and
           ((TSetElementNode(TAddNode(Right).Right).Left.IsEqual(Left)) or
            (
              (TSetElementNode(TAddNode(Right).Right).Left.NodeType=typeconvn) and
              (TTypeConvNode(TSetElementNode(TAddNode(Right).Right).Left).Left.IsEqual(Left))
            )
           ) and
           not(Might_Have_SideEffects(Left,[mhs_exceptions])) then
           begin
             lNode:=COrdConstNode.Create(1, PasBool1Type, true);
             TypeCheckPass(lNode);
             Result:=lNode;
             exit;
           end
         { ... in [] is always false }
         else if Is_EmptySet(Right) and
           not(Might_Have_SideEffects(Left,[mhs_exceptions])) then
           begin
             lNode:=COrdConstNode.Create(1, PasBool1Type, false);
             TypeCheckPass(lNode);
             Result:=lNode;
             exit;
           end;
      end;


    function TInNode.Pass_1 : TNode;
      begin
         Result:=nil;
         ExpectLoc:=LOC_REGISTER;

         FirstPass(Right);
         FirstPass(Left);
         if CodeGenError then
           exit;
      end;


{*****************************************************************************
                              TRANGENODE
*****************************************************************************}

    constructor TRangeNode.Create(ALeft,ARight : TNode);
      var
        lValue: string;
      begin
         { if right is char and left is string then
           right should be treated as one-symbol string }
         if Is_ConstStringNode(ALeft) and Is_ConstCharNode(ARight) then
           begin
             lValue := char(TOrdConstNode(ARight).Value.uvalue) + ''#0;
             ARight.free;
             ARight := CStringConstNode.CreateStr(lValue);
             DoTypeCheckPass(ARight);
           end;
         inherited Create(rangen,ALeft,ARight);
      end;


    function TRangeNode.Pass_TypeCheck : TNode;
      begin
         Result:=nil;
         TypeCheckPass(Left);
         TypeCheckPass(Right);
         Set_VarState(Left,vs_read,[vsf_must_be_valid]);
         Set_VarState(Right,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;
         { both types must be compatible }
         if not (nf_generic_para in Left.Flags) and not (nf_generic_para in Right.Flags) and
           (Compare_Defs(Left.ResultDef,Right.ResultDef,Left.NodeType)=te_incompatible) then
           IncompatibleTypes(Left.ResultDef,Right.ResultDef);
         { check if only when its a constant set and
           ignore range nodes which are generic parameter derived }
         if not (nf_generic_para in Flags) and (Left.NodeType=ordconstn) and (Right.NodeType=ordconstn) then
          begin
            { upper limit must be greater or equal than lower limit }
            if (TOrdConstNode(Left).Value>TOrdConstNode(Right).Value) and
               ((TOrdConstNode(Left).Value<0) or (TOrdConstNode(Right).Value>=0)) then
              CGMessage(parser_e_upper_lower_than_lower);
          end;
        ResultDef:=Left.ResultDef;
      end;


    function TRangeNode.Pass_1 : TNode;
      begin
         Result:=nil;
         FirstPass(Left);
         FirstPass(Right);
         if CodeGenError then
           exit;
        ExpectLoc:=Left.ExpectLoc;
      end;


{*****************************************************************************
                              Case Helpers
*****************************************************************************}

    { labels is the number of case-labels, while cases includes each individual
      value in a range (e.g. "0..2" counts as 3) }
    procedure CountCaseLabels(ARoot : PCaseLabel; out ALabelCount, ACaseCount: LongInt);

      procedure Count(ALabel : PCaseLabel);
        begin
           inc(ALabelCount);
           inc(ACaseCount, (ALabel^.HighValue.svalue - ALabel^.LowValue.svalue) + 1);
           if Assigned(ALabel^.Less) then
             Count(ALabel^.Less);
           if Assigned(ALabel^.Greater) then
             Count(ALabel^.Greater);
        end;

      begin
        ALabelCount:=0;
        ACaseCount:=0;
        Count(ARoot);
      end;


    function Case_Get_Max(ARoot : PCaseLabel) : TConstExprInt;
      var
         lCaseLabel : PCaseLabel;
      begin
         lCaseLabel:=ARoot;
         while Assigned(lCaseLabel^.Greater) do
           lCaseLabel:=lCaseLabel^.Greater;
         Case_Get_Max:=lCaseLabel^.HighValue;
      end;


    function Case_Get_Min(ARoot : PCaseLabel) : TConstExprInt;
      var
         lCaseLabel : PCaseLabel;
      begin
         lCaseLabel:=ARoot;
         while Assigned(lCaseLabel^.Less) do
           lCaseLabel:=lCaseLabel^.Less;
         Case_Get_Min:=lCaseLabel^.LowValue;
      end;

    procedure DeleteCaseLabels(ALabel : PCaseLabel);

      begin
         if Assigned(ALabel^.Greater) then
           DeleteCaseLabels(ALabel^.Greater);
         if Assigned(ALabel^.Less) then
           DeleteCaseLabels(ALabel^.Less);
         if (ALabel^.LabelType = ltConstString) then
           begin
             FreeAndNil(ALabel^.LowString);
             FreeAndNil(ALabel^.HighString);
           end;
         dispose(ALabel);
      end;

    function CopyCaseLabel(ALabel : PCaseLabel) : PCaseLabel;

      var
         lCopy : PCaseLabel;

      begin
         new(lCopy);
         lCopy^:=ALabel^;
         if (ALabel^.LabelType = ltConstString) then
           begin
             lCopy^.LowString := TStringConstNode(ALabel^.LowString.GetCopy);
             lCopy^.HighString := TStringConstNode(ALabel^.HighString.GetCopy);
           end;
         if Assigned(ALabel^.Greater) then
           lCopy^.Greater:=CopyCaseLabel(ALabel^.Greater);
         if Assigned(ALabel^.Less) then
           lCopy^.Less:=CopyCaseLabel(ALabel^.Less);
         CopyCaseLabel:=lCopy;
      end;


    procedure PPUWriteCaseLabel(APPUFile:TCompilerPPUFile;ALabel : PCaseLabel);
      var
        lTag : Byte;
      begin
        APPUFile.PutBoolean(ALabel^.LabelType = ltConstString);
        if (ALabel^.LabelType = ltConstString) then
          begin
            ALabel^.LowString.PPUWrite(APPUFile);
            ALabel^.HighString.PPUWrite(APPUFile);
          end
        else
          begin
            APPUFile.PutExprInt(ALabel^.LowValue);
            APPUFile.PutExprInt(ALabel^.HighValue);
          end;

        APPUFile.PutLongInt(ALabel^.BlockID);
        lTag:=ord(Assigned(ALabel^.Greater)) or (ord(Assigned(ALabel^.Less)) shl 1);
        APPUFile.PutByte(lTag);
        if Assigned(ALabel^.Greater) then
          PPUWriteCaseLabel(APPUFile,ALabel^.Greater);
        if Assigned(ALabel^.Less) then
          PPUWriteCaseLabel(APPUFile,ALabel^.Less);
      end;


    function PPULoadCaseLabel(APPUFile:TCompilerPPUFile):PCaseLabel;
      var
        lTag : Byte;
        lLabel : PCaseLabel;
      begin
        new(lLabel);
        if APPUFile.GetBoolean then
          begin
            lLabel^.LabelType := ltConstString;
            lLabel^.LowString := CStringConstNode.PPULoad(stringconstn,APPUFile);
            lLabel^.HighString := CStringConstNode.PPULoad(stringconstn,APPUFile);
          end
        else
          begin
            lLabel^.LabelType := ltOrdinal;

            lLabel^.LowValue:=APPUFile.GetExprInt;
            lLabel^.HighValue:=APPUFile.GetExprInt;
          end;

        lLabel^.BlockID:=APPUFile.GetLongInt;
        lTag:=APPUFile.GetByte;
        if (lTag and 1)=1 then
         lLabel^.Greater:=PPULoadCaseLabel(APPUFile)
        else
         lLabel^.Greater:=nil;
        if (lTag and 2)=2 then
         lLabel^.Less:=PPULoadCaseLabel(APPUFile)
        else
         lLabel^.Less:=nil;
        PPULoadCaseLabel:=lLabel;
      end;


{*****************************************************************************
                              TCASENODE
*****************************************************************************}

    constructor TCaseNode.Create(ALeft:TNode);
      begin
         inherited Create(casen,ALeft);
         FLabels:=nil;
         Blocks:=TFPList.Create;
         ElseBlock:=nil;
      end;


    destructor TCaseNode.Destroy;
      var
        lIndex : LongInt;
        lCaseBlock : PCaseBlock;
      begin
         ElseBlock.free;
         ElseBlock := nil;
         DeleteCaseLabels(FLabels);
         for lIndex:=0 to Blocks.Count-1 do
           begin
             FreeAndNil(PCaseBlock(Blocks[lIndex])^.Statement);
             lCaseBlock:=PCaseBlock(Blocks[lIndex]);
             dispose(lCaseBlock);
           end;
         Blocks.free;
         Blocks := nil;
         inherited Destroy;
      end;


    constructor TCaseNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      var
        lCount,lIndex : LongInt;
      begin
        inherited PPULoad(ANodeType,APPUFile);
        ElseBlock:=PPULoadNode(APPUFile);
        lCount:=APPUFile.GetLongInt();
        Blocks:=TFPList.Create;
        for lIndex:=0 to lCount-1 do
          AddBlock(lIndex,PPULoadNode(APPUFile));
        FLabels:=PPULoadCaseLabel(APPUFile);
        { we don't save/restore the label counts, but recalculate them if needed }
        FCountsUpToDate:=false;
      end;


    procedure TCaseNode.PPUWrite(APPUFile:TCompilerPPUFile);
      var
        lIndex : LongInt;
      begin
        inherited PPUWrite(APPUFile);
        PPUWriteNode(APPUFile,ElseBlock);
        APPUFile.PutLongInt(Blocks.Count);
        for lIndex:=0 to Blocks.Count-1 do
          PPUWriteNode(APPUFile,PCaseBlock(Blocks[lIndex])^.Statement);
        PPUWriteCaseLabel(APPUFile,FLabels);
        { we don't save/restore the label counts, but recalculate them if needed }
      end;


    procedure TCaseNode.BuildDerefImpl;
      var
        lIndex : Integer;
      begin
        inherited BuildDerefImpl;
        if Assigned(ElseBlock) then
          ElseBlock.BuildDerefImpl;
        for lIndex:=0 to Blocks.Count-1 do
          PCaseBlock(Blocks[lIndex])^.Statement.BuildDerefImpl;
      end;


    procedure TCaseNode.DerefImpl;
      var
        lIndex : Integer;
      begin
        inherited DerefImpl;
        if Assigned(ElseBlock) then
          ElseBlock.DerefImpl;
        for lIndex:=0 to Blocks.Count-1 do
          PCaseBlock(Blocks[lIndex])^.Statement.DerefImpl;
      end;


    function TCaseNode.Pass_TypeCheck : TNode;
      var
        lIndex : Integer;
      begin
        Result:=nil;

        DoTypeCheckPass(Left);

        for lIndex:=0 to Blocks.Count-1 do
          TypeCheckPass(PCaseBlock(Blocks[lIndex])^.Statement);

        if Assigned(ElseBlock) then
          TypeCheckPass(ElseBlock);

        ResultDef:=VoidType;
        Result:=Simplify(false);
      end;


    type
      TLinkedListCaseLabelItem = class(TLinkedListItem)
        FCaseLabel: PCaseLabel;
        constructor Create(ACaseLabel: PCaseLabel);
      end;

    constructor TLinkedListCaseLabelItem.Create(ACaseLabel: PCaseLabel);
      begin
        inherited Create;
        FCaseLabel:=ACaseLabel;
      end;


    function TCaseNode.Pass_1 : TNode;
      var
         lIndex: Integer;
         lThenBlockNode, lElseBlockNode, lIfNode,lTempCleanup : TNode;
         lCaseExprTemp : TTempCreateNode;
         lIfBlock, lInitBlock: TBlockNode;
         lStatement: TStatementNode;

      procedure AddLabelToBlockIDList(AList: TFPObjectList; ALabel: PCaseLabel);
        begin
          if not Assigned(ALabel) then
            exit;
          if not Assigned(AList[ALabel^.BlockID]) then
            AList[ALabel^.BlockID]:=TFPObjectList.Create(true);
          TFPObjectList(AList[ALabel^.BlockID]).add(TLinkedListCaseLabelItem.Create(ALabel));
          AddLabelToBlockIDList(AList,ALabel^.Less);
          AddLabelToBlockIDList(AList,ALabel^.Greater);
        end;

      function OrderLabelsByBlockID: TFPObjectList;
        begin
          Result:=TFPObjectList.Create(true);
          Result.Count:=Blocks.Count;
          AddLabelToBlockIDList(Result,FLabels);
        end;

      function MakeIfBlock(AElseBlock : TNode): TNode;
        var
          lIndex, lLabelIndex: LongInt;
          lCheck: TAddNode;
          lNewCheck: ^TAddNode;
          lBlockList, lLabelList: TFPObjectList;
          lLabelItem: PCaseLabel;
        begin
          Result:=AElseBlock;
          lBlockList:=OrderLabelsByBlockID;
          { in reverse order so that the case options at the start of the case
            statement are evaluated first, as they presumably are the most
            common }
          for lIndex:=lBlockList.Count-1 downto 0 do
            begin
              lLabelList:=TFPObjectList(lBlockList[lIndex]);
              lCheck:=nil;
              for lLabelIndex:=0 to lLabelList.Count-1 do
                begin
                  if Assigned(lCheck) then
                    begin
                      lCheck:=CAddNode.Create(orn,lCheck,nil);
                      lNewCheck:=@lCheck.Right
                    end
                  else
                    lNewCheck:=@lCheck;
                  lLabelItem:=TLinkedListCaseLabelItem(lLabelList[lLabelIndex]).FCaseLabel;
                  lNewCheck^:=CAddNode.Create(EqualN,Left.GetCopy,lLabelItem^.LowString.GetCopy);
                  if (lLabelItem^.LowString.FullCompare(lLabelItem^.HighString)<>0) then
                    begin
                      lNewCheck^.NodeType:=gten;
                      lNewCheck^:=CAddNode.Create(
                        andn,lNewCheck^,CAddNode.Create(
                          lten,Left.GetCopy,lLabelItem^.HighString.GetCopy));
                    end;
                end;
              Result:=CIfNode.Create(lCheck,
                PCaseBlock(Blocks[lIndex])^.Statement,Result);
              PCaseBlock(Blocks[lIndex])^.Statement:=nil;
            end;
          { will free its elements too because of create(true) }
          lBlockList.free;
          lBlockList := nil;
          TypeCheckPass(Result);
        end;

      begin
         Result:=nil;
         lInitBlock:=nil;
         lTempCleanup:=nil;
         ExpectLoc:=LOC_VOID;

         { only do in pass_1, so that simplify can run first and
             1) possibly simplify the case node without triggering a warning
             2) possibly give a compile-time error if not all cases are handled
                in ISO/Extended Pascal mode }
         if Is_Ordinal(Left.ResultDef) then
           CheckOrdinalCoverage;

         { ideally this would be in simplify, but then checkordinalcoverage can
           false positives about case statements not handling all cases }
         if Assigned(ElseBlock) and
            Has_No_Code(ElseBlock) then
           begin
             ElseBlock.free;
             ElseBlock:=nil;
           end;

         { evaluates the case expression }
         FirstPass(Left);
         Set_VarState(Left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         { Load caseexpr into temp var if complex. }
         { No need to do this for ordinal, because }
         { in that case caseexpr is generated once }
         if (FLabels^.LabelType = ltConstString) and (not Valid_For_Addr(Left, false)) and
           (Blocks.Count > 0) then
           begin
             lInitBlock := InternalStatements(lStatement);
             lCaseExprTemp :=
               CTempCreateNode.Create(
                 Left.ResultDef, Left.ResultDef.Size, tt_persistent, true);
             lTempCleanup := CTempDeleteNode.Create(lCaseExprTemp);
             TypeCheckPass(TNode(lCaseExprTemp));

             AddStatement(lStatement, lCaseExprTemp);
             AddStatement(
               lStatement, CAssignmentNode.Create(
                 CTempRefNode.Create(lCaseExprTemp), Left));

             Left := CTempRefNode.Create(lCaseExprTemp);
             TypeCheckPass(Left);
           end;

         { first case }
         for lIndex:=0 to Blocks.Count-1 do
           FirstPass(PCaseBlock(Blocks[lIndex])^.Statement);

         { may be handle else tree }
         if Assigned(ElseBlock) then
           begin
             FirstPass(ElseBlock);

             { kill case? }
             if Blocks.Count=0 then
               begin
                 Result:=ElseBlock;
                 ElseBlock:=nil;
                 exit;
               end;
           end
         else
           if Blocks.Count=0 then
             begin
               Result:=CNothingNode.Create;
               exit;
             end;

         if (FLabels^.LabelType = ltConstString) then
           begin
             lIfNode:=MakeIfBlock(ElseBlock);

             if Assigned(lInitBlock) then
               FirstPass(TNode(lInitBlock));

             lIfBlock:=InternalStatements(lStatement);

             if Assigned(lInitBlock) then
               AddStatement(lStatement, lInitBlock);
             AddStatement(lStatement,lIfNode);
             if Assigned(lTempCleanup) then
               AddStatement(lStatement,lTempCleanup);
             Result:=lIfBlock;
             ElseBlock:= nil;
             exit;
           end;

         if Is_Boolean(Left.ResultDef) then
           begin
             case Blocks.Count of
               2:
                 begin
                   if Boolean(QWord(FLabels^.LowValue))=false then
                     begin
                       lThenBlockNode:=PCaseBlock(Blocks[FLabels^.Greater^.BlockID])^.Statement;
                       lElseBlockNode:=PCaseBlock(Blocks[FLabels^.BlockID])^.Statement;
                       PCaseBlock(Blocks[FLabels^.Greater^.BlockID])^.Statement:=nil;
                     end
                   else
                     begin
                       lThenBlockNode:=PCaseBlock(Blocks[FLabels^.BlockID])^.Statement;
                       lElseBlockNode:=PCaseBlock(Blocks[FLabels^.Less^.BlockID])^.Statement;
                       PCaseBlock(Blocks[FLabels^.Less^.BlockID])^.Statement:=nil;
                     end;
                   PCaseBlock(Blocks[FLabels^.BlockID])^.Statement:=nil;
                 end;
               1:
                 begin
                   if FLabels^.LowValue=FLabels^.HighValue then
                     begin
                       if Boolean(QWord(FLabels^.LowValue))=false then
                         begin
                           lThenBlockNode:=ElseBlock;
                           lElseBlockNode:=PCaseBlock(Blocks[FLabels^.BlockID])^.Statement;
                         end
                       else
                         begin
                           lThenBlockNode:=PCaseBlock(Blocks[FLabels^.BlockID])^.Statement;
                           lElseBlockNode:=ElseBlock;
                         end;
                       PCaseBlock(Blocks[FLabels^.BlockID])^.Statement:=nil;
                       ElseBlock:=nil;
                     end
                   else
                     begin
                       Result:=PCaseBlock(Blocks[FLabels^.BlockID])^.Statement;
                       PCaseBlock(Blocks[FLabels^.BlockID])^.Statement:=nil;
                       ElseBlock:=nil;
                       exit;
                     end;
                 end;
             else
               InternalError(200805031);
           end;
           Result:=CIfNode.Create(Left,lThenBlockNode,lElseBlockNode);
           Left:=nil;
           exit;
         end;
       { convert single case branch into if-statement }
       if (FLabels^.Greater=nil) and (FLabels^.Less=nil) then
         if FLabels^.LabelType=ltOrdinal then
           begin
             if FLabels^.LowValue=FLabels^.HighValue then
               begin
                 Result:=CIfNode.Create_Internal(
                   CAddNode.Create_Internal(EqualN,Left.GetCopy,COrdConstNode.Create(FLabels^.LowValue,Left.ResultDef,false)),
                   PCaseBlock(Blocks[FLabels^.BlockID])^.Statement,ElseBlock);
               end
             else if not(Might_Have_SideEffects(Left,[mhs_exceptions])) and (Node_Complexity(Left)<=1) then
               begin
                 Result:=CIfNode.Create_Internal(
                   CAddNode.Create_Internal(andn,
                     CAddNode.Create_Internal(gten,Left.GetCopy,COrdConstNode.Create(FLabels^.LowValue,Left.ResultDef,false)),
                     CAddNode.Create_Internal(lten,Left.GetCopy,COrdConstNode.Create(FLabels^.HighValue,Left.ResultDef,false))
                   ),
                   PCaseBlock(Blocks[FLabels^.BlockID])^.Statement,ElseBlock);
               end
             else
               begin
                 lInitBlock:=InternalStatements(lStatement);
                 lCaseExprTemp:=CTempCreateNode.Create(
                   Left.ResultDef,Left.ResultDef.Size,tt_persistent,true);
                 lTempCleanup:=CTempDeleteNode.Create(lCaseExprTemp);
                 TypeCheckPass(TNode(lCaseExprTemp));

                 AddStatement(lStatement,lCaseExprTemp);
                 AddStatement(lStatement,CAssignmentNode.Create(
                   CTempRefNode.Create(lCaseExprTemp),Left.GetCopy));

                 Left:=CTempRefNode.Create(lCaseExprTemp);
                 TypeCheckPass(Left);

                 AddStatement(lStatement,CIfNode.Create_Internal(
                   CAddNode.Create_Internal(andn,
                     CAddNode.Create_Internal(gten,Left.GetCopy,COrdConstNode.Create(FLabels^.LowValue,Left.ResultDef,false)),
                     CAddNode.Create_Internal(lten,Left.GetCopy,COrdConstNode.Create(FLabels^.HighValue,Left.ResultDef,false))
                   ),
                   PCaseBlock(Blocks[FLabels^.BlockID])^.Statement,ElseBlock));
                 AddStatement(lStatement,lTempCleanup);
                 Result:=lInitBlock;
               end;
             ElseBlock:=nil;
             PCaseBlock(Blocks[FLabels^.BlockID])^.Statement:=nil;
             exit;
           end;
        end;


    function TCaseNode.Simplify(AForInline:Boolean):TNode;
      var
        lTempLabel: PCaseLabel;
      begin
        Result:=nil;
        if Left.NodeType=ordconstn then
          begin
            lTempLabel:=FLabels;
            { check all case labels until we find one that fits }
            while Assigned(lTempLabel) do
              begin
                if (lTempLabel^.LowValue<=TOrdConstNode(Left).Value) and
                    (lTempLabel^.HighValue>=TOrdConstNode(Left).Value) then
                  begin
                    if lTempLabel^.BlockID>=Blocks.Count then
                      InternalError(2014022101);
                    Result:=PCaseBlock(Blocks[lTempLabel^.BlockID])^.Statement;
                    if not Assigned(Result) then
                      InternalError(2014022102);
                    Result:=Result.GetCopy;
                    exit;
                  end;

                if lTempLabel^.HighValue<TOrdConstNode(Left).Value then
                  lTempLabel:=lTempLabel^.Greater
                else
                  lTempLabel:=lTempLabel^.Less;
              end;
            { no label did match; use the else block if available }
            if Assigned(ElseBlock) then
              Result:=ElseBlock.GetCopy
            else
              begin
                if ([m_iso,m_extpas]*CurrentSettings.ModeSwitches)<>[] then
                  CGMessage1(cg_e_case_missing_value,ToStr(TOrdConstNode(Left).Value))
                else
                  CGMessage(cg_w_case_incomplete);
                { no else block, so there is no code to execute at all }
                Result:=CNothingNode.Create;
              end;
          end;
      end;


    function TCaseNode.DoGetCopy : TNode;
      var
         lCopy : TCaseNode;
         lIndex : LongInt;
      begin
         lCopy:=TCaseNode(inherited DoGetCopy);
         if Assigned(ElseBlock) then
           lCopy.ElseBlock:=ElseBlock.DoGetCopy
         else
           lCopy.ElseBlock:=nil;
         if Assigned(FLabels) then
           lCopy.FLabels:=CopyCaseLabel(FLabels)
         else
           lCopy.FLabels:=nil;
         if Assigned(Blocks) then
           begin
             lCopy.Blocks:=TFPList.Create;
             for lIndex:=0 to Blocks.Count-1 do
               begin
                 if not Assigned(Blocks[lIndex]) then
                   InternalError(200411302);
                 lCopy.AddBlock(lIndex,PCaseBlock(Blocks[lIndex])^.Statement.DoGetCopy);
               end;
           end
         else
           lCopy.Blocks:=nil;
         lCopy.FCountsUpToDate:=FCountsUpToDate;
         lCopy.FLabelCnt:=FLabelCnt;
         lCopy.FLabelCoverage:=FLabelCoverage;
         DoGetCopy:=lCopy;
      end;


    procedure TCaseNode.PrintNodeTree(var AText: text);
      var
        lIndex : LongInt;
      begin
        write(AText,PrintNodeIndention,'(');
        PrintNodeIndent;
        PrintNodeInfo(AText);
        WriteLn(AText);
        PrintNode(AText,Left);
        lIndex:=0;
        for lIndex:=0 to Blocks.Count-1 do
          begin
            WriteLn(AText,PrintNodeIndention,'(caseblock blockid: ',lIndex);
            PrintNodeIndent;
            PrintNode(AText,PCaseBlock(Blocks[lIndex])^.Statement);
            PrintNodeUnindent;
            WriteLn(AText,PrintNodeIndention,')');
          end;
        if Assigned(ElseBlock) then
          begin
            WriteLn(AText,PrintNodeIndention,'(else: ',lIndex);
            PrintNodeIndent;
            PrintNode(AText,ElseBlock);
            PrintNodeUnindent;
            WriteLn(AText,PrintNodeIndention,')');
          end;
        PrintNodeUnindent;
        WriteLn(AText,PrintNodeIndention,')');
      end;


    procedure TCaseNode.InsertIntoList(AList : TNodeList);
      begin
      end;


    function CaseLabelsEqual(ALabel1,ALabel2: PCaseLabel): Boolean;
      begin
        Result :=
          (not Assigned(ALabel1) and not Assigned(ALabel2)) or
          (Assigned(ALabel1) and Assigned(ALabel2) and
           (ALabel1^.LowValue = ALabel2^.LowValue) and
           (ALabel1^.HighValue = ALabel2^.HighValue) and
           { the rest of the fields don't matter for equality (JM) }
           CaseLabelsEqual(ALabel1^.Less,ALabel2^.Less) and
           CaseLabelsEqual(ALabel1^.Greater,ALabel2^.Greater))
      end;


    function CaseBlocksEqual(ABlocks1,ABlocks2:TFPList): Boolean;
      var
        lIndex : LongInt;
      begin
        Result:=false;
        if ABlocks1.Count<>ABlocks2.Count then
          exit;
        for lIndex:=0 to ABlocks1.Count-1 do
          begin
            if not PCaseBlock(ABlocks1[lIndex])^.Statement.IsEqual(PCaseBlock(ABlocks2[lIndex])^.Statement) then
              exit;
          end;
        Result:=true;
      end;


    function TCaseNode.DoCompare(ANode: TNode): Boolean;
      begin
        Result :=
          inherited DoCompare(ANode) and
          CaseLabelsEqual(FLabels,TCaseNode(ANode).FLabels) and
          CaseBlocksEqual(Blocks,TCaseNode(ANode).Blocks) and
          ElseBlock.IsEqual(TCaseNode(ANode).ElseBlock);
      end;


    procedure TCaseNode.AddBlock(ABlockID:LongInt;AStatement:TNode);
      var
        lCaseBlock : PCaseBlock;
      begin
        new(lCaseBlock);
        fillchar(lCaseBlock^,sizeof(lCaseBlock^),0);
        lCaseBlock^.Statement:=AStatement;
        if ABlockID>=Blocks.Count then
          Blocks.Count:=ABlockID+1;
        Blocks[ABlockID]:=lCaseBlock;
      end;


    procedure TCaseNode.AddElseBlock(AStatement:TNode);
      begin
        ElseBlock:=AStatement;
      end;


    function TCaseNode.GetLabelCnt: Cardinal;
      begin
        if not FCountsUpToDate then
          UpdateCoverage;
        Result:=FLabelCnt;
      end;


    function TCaseNode.GetLabelCoverage: QWord;
      begin
        if not FCountsUpToDate then
          UpdateCoverage;
        Result:=FLabelCoverage;
      end;


    procedure TCaseNode.UpdateCoverage;

      var
        lIsOrdinal, lFirst: Boolean;

      procedure Count(ALabel : PCaseLabel);
        begin
           inc(FLabelCnt);
           if lIsOrdinal then
             begin
               FLabelCoverage:=FLabelCoverage + (ALabel^.HighValue - ALabel^.LowValue);
               { ensure we don't overflow in case it covers the
                 full range of qword }
               if not lFirst then
                 inc(FLabelCoverage);
               lFirst:=false;
             end;
           if Assigned(ALabel^.Less) then
             Count(ALabel^.Less);
           if Assigned(ALabel^.Greater) then
             Count(ALabel^.Greater);
        end;

      begin
        lIsOrdinal:=Is_Ordinal(Left.ResultDef);
        FLabelCnt:=0;
        FLabelCoverage:=0;
        lFirst:=true;
        Count(FLabels);
        FCountsUpToDate:=true;
      end;


    procedure TCaseNode.CheckOrdinalCoverage;

      function OrdDefSpansFullRange(ADef: TOrdDef): Boolean;
        var
          lPackedBitSize: Cardinal;
          lDummy: LongInt;
          lValue: QWord;
        begin
          Result:=false;
          lPackedBitSize:=ADef.PackedBitSize;
          if ((lPackedBitSize mod 8) <> 0) or
             not IsPowerOf2(lPackedBitSize div 8,lDummy) then
            exit;
          dec(lPackedBitSize);
          if Is_Signed(ADef) then
            begin
{$push}{$q-}
              if ADef.low<>(-(Int64(1) shl lPackedBitSize)) then
                exit;
              if ADef.high<>((Int64(1) shl lPackedBitSize)-1) then
                exit;
{$pop}
            end
          else
            begin
              if ADef.low<>0 then
                exit;
              lValue:=QWord(1) shl lPackedBitSize;
              lValue:=(lValue-1)+lValue;
              if ADef.high<>lValue then
                exit;
            end;
          Result:=true;
        end;

      var
        lLowValue, lHighValue, lTypeCount: TConstExprInt;
      begin
        { Check label type coverage for enumerations and small types }
        GetRange(Left.ResultDef,lLowValue,lHighValue);
        { low/high value of c-style booleans are not suitable for calculating their "type count" }
        if Is_CBool(Left.ResultDef) then
          lTypeCount:=1
        else
          lTypeCount:=lHighValue-lLowValue;
        if not Assigned(ElseBlock) then
          begin
            { unless cs_check_all_case_coverage is set, only check for enums, booleans and
              subrange types different from the default ones }
            if (cs_check_all_case_coverage in CurrentSettings.LocalSwitches) or
               (Is_Enum(Left.ResultDef) or
                Is_Boolean(Left.ResultDef) or
                not OrdDefSpansFullRange(TOrdDef(Left.ResultDef))) and
               (LabelCoverage<lTypeCount) then
              begin
                { labels for some values of the operand are missing, and no else block is present }
                CGMessage(cg_w_case_incomplete);
                { in Standard/Extended Pascal, this is a dynamic violation error if it actually happens }
                if ([m_extpas,m_iso]*CurrentSettings.ModeSwitches)<>[] then
                  begin
                    ElseBlock:=CCallNode.CreateIntern('fpc_rangeerror',nil);
                    TypeCheckPass(ElseBlock);
                  end;
              end
          end
        else if LabelCoverage=lTypeCount then
          begin
            { labels for all values of the operand are present, but an extra else block is present }
            MessagePos(ElseBlock.FileInfo, cg_w_unreachable_code);
          end;
      end;


    procedure TCaseNode.AddLabel(ABlockID:LongInt;const ALowValue,AHighValue : TConstExprInt);
      var
        lCaseLabel : PCaseLabel;

        function InsertLabel(var ALabel : PCaseLabel):PCaseLabel;
          begin
             if ALabel=nil then
               begin
                 ALabel:=lCaseLabel;
                 Result:=ALabel;
               end
             else
              if (ALabel^.LowValue>lCaseLabel^.LowValue) and
                 (ALabel^.LowValue>lCaseLabel^.HighValue) then
                begin
                  if (lCaseLabel^.BlockID = ALabel^.BlockID) and
                     (ALabel^.LowValue = lCaseLabel^.HighValue + 1) then
                    begin
                      ALabel^.LowValue := lCaseLabel^.LowValue;
                      dispose(lCaseLabel);
                      Result:=ALabel;
                    end
                  else
                    Result:=InsertLabel(ALabel^.Less)
                end
             else
               if (ALabel^.HighValue<lCaseLabel^.LowValue) and
                  (ALabel^.HighValue<lCaseLabel^.HighValue) then
                 begin
                    if (lCaseLabel^.BlockID = ALabel^.BlockID) and
                       (ALabel^.HighValue+1 = lCaseLabel^.LowValue) then
                      begin
                        ALabel^.HighValue := lCaseLabel^.HighValue;
                        dispose(lCaseLabel);
                        Result:=ALabel;
                      end
                    else
                      Result:=InsertLabel(ALabel^.Greater);
                 end
             else
               begin
                 dispose(lCaseLabel);
                 Message(parser_e_double_caselabel);
                 Result:=nil;
               end
          end;

      begin
        new(lCaseLabel);
        fillchar(lCaseLabel^,sizeof(TCaseLabel),0);
        lCaseLabel^.BlockID:=ABlockID;
        lCaseLabel^.LabelType:=ltOrdinal;
        lCaseLabel^.LowValue:=ALowValue;
        lCaseLabel^.HighValue:=AHighValue;
        InsertLabel(FLabels);
        FCountsUpToDate:=false;
      end;

    procedure TCaseNode.AddLabel(ABlockID: LongInt; ALowString, AHighString: TStringConstNode);

      var
        lCaseLabel : PCaseLabel;

      function InsertLabel(var ALabel : PCaseLabel) : PCaseLabel;
        begin
          if not Assigned(ALabel) then
            begin
              ALabel := lCaseLabel;
              Result := ALabel;
            end
          else
            if (ALabel^.LowString.FullCompare(lCaseLabel^.HighString) > 0) then
              Result := InsertLabel(ALabel^.Less)
          else
            if (ALabel^.HighString.FullCompare(lCaseLabel^.LowString) < 0) then
              Result := InsertLabel(ALabel^.Greater)
          else
            begin
              FreeAndNil(lCaseLabel^.LowString);
              FreeAndNil(lCaseLabel^.HighString);
              dispose(lCaseLabel);
              Message(parser_e_double_caselabel);
              Result:=nil;
            end;
        end;

      begin
        new(lCaseLabel);
        fillchar(lCaseLabel^, sizeof(TCaseLabel), 0);
        lCaseLabel^.BlockID := ABlockID;
        lCaseLabel^.LabelType := ltConstString;

        lCaseLabel^.LowString := TStringConstNode(ALowString.GetCopy);
        lCaseLabel^.HighString := TStringConstNode(AHighString.GetCopy);

        InsertLabel(FLabels);
      end;

end.
