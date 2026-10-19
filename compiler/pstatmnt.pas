{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Does the parsing of the statements

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
unit pstatmnt;

{$i fpcdefs.inc}

interface

    uses
      tokens,node;


    function StatementBlock(AStartToken : TToken) : TNode;

    { parses an if-, case- or try-expression, if modeswitch statementexpressions is enabled }
    function StatementExpr(var ANode : TNode) : Boolean;

    { reads an assembler block }
    function AssemblerBlock : TNode;


implementation

    uses
       { common }
       CUtils,CClasses,
       { global }
       GlobType,Globals,Verbose,ConstExp,
       Systems,
       { aasm }
       cpubase,aasmtai,AAsmData,aasmbase,
       { symtable }
       symconst,SymBase,symtype,symdef,SymSym,SymTable,defutil,defcmp,
       paramgr,
       { pass 1 }
       Pass_1,htypechk,
       nutils,ngenutil,nbas,ncal,nmem,nset,ncnv,ncon,nld,nflw,ninl,
       { parser }
       Scanner,
       pbase,ptype,pexpr,
       { codegen }
       ProcInfo,cgbase,
       { assembler reader }
       rabase,
       { scanner }
       Switches;


    function Statement : TNode;forward;


    function IsAnonymousProcDef(ADef : TDef) : Boolean;
      begin
        Result:=Assigned(ADef) and
                (ADef.typ=procdef) and
                (po_anonymous in TProcDef(ADef).ProcOptions);
      end;


    { returns the common type of olddef and the type of branchtree,
      oldtree is the node that determines the type }
    function BranchType(AOldDef : TDef; ABranchTree : TNode; var AOldTree : TNode) : TDef;

      function CommonAncestor(AClass1,AClass2 : TObjectDef; var AAncestor : TDef) : Boolean;
        var
          lCurrent, lCheck : TObjectDef;
        begin
          Result:=false;
          lCurrent:=AClass1;
          while Assigned(lCurrent) do
            begin
              lCheck:=AClass2;
              while Assigned(lCheck) do
                begin
                  if lCheck=lCurrent then
                    begin
                      Result:=true;
                      AAncestor:=lCurrent;
                      exit;
                    end;
                  lCheck:=lCheck.ChildOf;
                end;
              lCurrent:=lCurrent.ChildOf;
            end;
        end;

      var
        lBranchDef : TDef;
        lComparison : TEqualType;
      begin
        if not Assigned(ABranchTree) or
            not Assigned(ABranchTree.resultdef) or
            (ABranchTree.resultdef.typ=errordef) then
          exit(AOldDef);

        lBranchDef:=ABranchTree.resultdef;
        if not Assigned(AOldDef) then
          begin
            AOldTree:=ABranchTree;
            exit(lBranchDef);
          end;

        { anonymous functions get their type when the statement expression
          is converted to a procvar or function reference, see ncnv }
        if IsAnonymousProcDef(AOldDef) then
          exit(AOldDef);
        if IsAnonymousProcDef(lBranchDef) then
          begin
            AOldTree:=ABranchTree;
            exit(lBranchDef);
          end;

        { combining string/char types }
        if Is_AnyChar(AOldDef) and Is_String(lBranchDef) then
          Result:=lBranchDef
        else if Is_WideString(lBranchDef) or Is_WideString(AOldDef) or
                ((Is_AnsiString(AOldDef) or Is_CharArray(AOldDef)) and Is_WideChar(lBranchDef)) then
          Result:=CWideStringType
        else if Is_UnicodeString(lBranchDef) or Is_UnicodeString(AOldDef) then
          Result:=CUnicodeStringType
        else if Is_Char(AOldDef) and Is_WideChar(lBranchDef) then
          Result:=CWideCharType
        { constant strings: use longest }
        else if Is_CharArray(AOldDef) and Is_CharArray(lBranchDef) then
          begin
            Result:=AOldDef;
            if TArrayDef(AOldDef).EleCount<TArrayDef(lBranchDef).EleCount then
              Result:=lBranchDef;
          end
        { shortstrings: use longest }
        else if Is_ShortString(AOldDef) and Is_ShortString(lBranchDef) then
          begin
            Result:=AOldDef;
            if TStringDef(AOldDef).len<TStringDef(lBranchDef).len then
              Result:=lBranchDef;
          end
        { combine with variant results in a variant }
        else if (AOldDef.typ=variantdef) or (lBranchDef.typ=variantdef) then
          Result:=CVariantType
        else if (AOldDef.typ=objectdef) and (lBranchDef.typ=objectdef) and
                CommonAncestor(TObjectDef(AOldDef),TObjectDef(lBranchDef),Result) then
          { result set by commonancestor }
        else
          begin
            { combine to biggest }
            Result:=AOldDef;
            lComparison:=Compare_Defs(AOldDef,lBranchDef,AOldTree.nodetype);
            if (lComparison<te_equal) and
                (lComparison>Compare_Defs(lBranchDef,AOldDef,ABranchTree.nodetype)) then
              Result:=lBranchDef;
          end;

        if Result<>AOldDef then
          AOldTree:=ABranchTree;
      end;


    { creates a temp for the result of a statement expression block }
    function CreateStmtExprBlock(AResultDef : TDef; out AStatements : TStatementNode;
        out AResultVar : TTempCreateNode) : TNode;
      begin
        Result:=InternalStatements(AStatements);
        AResultVar:=CTempCreateNode.Create(AResultDef,AResultDef.Size,tt_persistent,
                                          not IsAnonymousProcDef(AResultDef));
        AddStatement(AStatements,AResultVar);
      end;


    procedure FinishStmtExprBlock(AStatements : TStatementNode;
        AResultVar : TTempCreateNode; AValueNode : TNode);
      begin
        AddStatement(AStatements,AValueNode);
        AddStatement(AStatements,CTempDeleteNode.Create_Normal_Temp(AResultVar));
        AddStatement(AStatements,CTempRefNode.Create(AResultVar));
      end;


    function IfStmtExpr : TNode;
      var
        lCondition, lIfBranch, lElseBranch, lTypeNode : TNode;
        lStatements : TStatementNode;
        lResultVar : TTempCreateNode;
        lResultDef : TDef;
      begin
        Consume(_IF);
        lCondition:=CompExpr([efAcceptEqual]);
        Consume(_THEN);
        lIfBranch:=Expr(true);
        Consume(_ELSE);
        lElseBranch:=Expr(true);

        lTypeNode:=nil;
        lResultDef:=BranchType(nil,lIfBranch,lTypeNode);
        lResultDef:=BranchType(lResultDef,lElseBranch,lTypeNode);
        if not Assigned(lResultDef) then
          begin
            { errors have already been reported }
            lCondition.free;
            lIfBranch.free;
            lElseBranch.free;
            Result:=CErrorNode.Create;
            exit;
          end;
        Result:=CreateStmtExprBlock(lResultDef,lStatements,lResultVar);
        if IsAnonymousProcDef(lResultDef) then
          FinishStmtExprBlock(lStatements,lResultVar,CIfNode.Create(lCondition,lIfBranch,lElseBranch))
        else
          FinishStmtExprBlock(lStatements,lResultVar,
            CIfNode.Create(lCondition,
              CAssignmentNode.Create(CTempRefNode.Create(lResultVar),lIfBranch),
              CAssignmentNode.Create(CTempRefNode.Create(lResultVar),lElseBranch)));
        exit;
      end;

    function IfStatement : TNode;
      var
        lCondition, lIfBranch, lElseBranch : TNode;
      begin
        Consume(_IF);
        lCondition:=CompExpr([efAcceptEqual]);
        Consume(_THEN);

        if not(CurrentScanner.FToken in cEndTokens) then
          lIfBranch:=Statement
        else
          lIfBranch:=nil;

        if TryToConsume(_ELSE) then
          lElseBranch:=Statement
        else
          lElseBranch:=nil;
        Result:=CIfNode.Create(lCondition,lIfBranch,lElseBranch);
      end;

    { creates a block (list) of statements, til the next END token }
    function StatementsTilEnd : TNode;

      var
         lFirst,lLast : TStatementNode;

      begin
         lFirst:=nil;
         lLast:=nil;
         while CurrentScanner.FToken<>_END do
           begin
              if lFirst=nil then
                begin
                   lLast:=CStatementNode.Create(Statement,nil);
                   lFirst:=lLast;
                end
              else
                begin
                   lLast.right:=CStatementNode.Create(Statement,nil);
                   lLast:=TStatementNode(lLast.right);
                end;
              if not TryToConsume(_SEMICOLON) then
                break;
              ConsumeEmptyStats;
           end;
         Consume(_END);
         StatementsTilEnd:=CBlockNode.Create(lFirst);
         if Assigned(lFirst) then
           StatementsTilEnd.fileinfo:=lFirst.fileinfo;
      end;


    { parses "case <expr> of" }
    function ReadCaseHead(out ACaseDef : TDef; out ACaseDefError, ACaseOfString : Boolean) : TCaseNode;
      var
        lCaseExpr : TNode;
      begin
        Consume(_CASE);
        lCaseExpr:=CompExpr([efAcceptEqual]);
        { determines result type }
        DoTypeCheckPass(lCaseExpr);
        { variants must be accepted, but first they must be converted to integer }
        if lCaseExpr.resultdef.typ=variantdef then
          begin
            lCaseExpr:=CTypeConvNode.Create_Internal(lCaseExpr,SIntType);
            DoTypeCheckPass(lCaseExpr);
          end;
        Set_VarState(lCaseExpr,vs_read,[vsf_must_be_valid]);
        ACaseDefError:=false;
        ACaseDef:=lCaseExpr.resultdef;
        { case of string must be rejected in Delphi and MacPas modes. }
        ACaseOfString :=
          ([m_delphi, m_mac] * CurrentSettings.ModeSwitches = []) and
          Is_String(ACaseDef);

        if (not Assigned(ACaseDef)) or
            ( not(Is_Ordinal(ACaseDef)) and (not ACaseOfString) ) then
        begin
          CGMessage(type_e_ordinal_or_string_expr_expected);
          { create a valid tree }
          lCaseExpr.free;
          lCaseExpr:=COrdConstNode.Create(0,U32IntType,false);
          { set error flag so no rangechecks are done }
          ACaseDefError:=true;
         end;
        { Create casenode }
        Result:=CCaseNode.Create(lCaseExpr);
        Consume(_OF);
      end;


    { parses the labels of one case block, including the colon }
    procedure ReadCaseLabels(ACaseNode : TCaseNode; ACaseDef : TDef; ABlockID : LongInt;
        ACaseDefError, ACaseOfString : Boolean);
      var
        lNode : TNode;
        lLowValue,lHighValue : TConstExprInt;
        lLowStringNode,lHighStringNode : TStringConstNode;
      begin
        repeat
          lNode:=Expr(true);
          if Is_WideChar(ACaseDef) then
            begin
              if (lNode.nodetype=rangen) then
                begin
                  TRangeNode(lNode).left:=CTypeConvNode.Create(TRangeNode(lNode).left,CWideCharType);
                  TRangeNode(lNode).right:=CTypeConvNode.Create(TRangeNode(lNode).right,CWideCharType);
                  DoTypeCheckPass(TRangeNode(lNode).left);
                  DoTypeCheckPass(TRangeNode(lNode).right);
                end
              else
                begin
                  lNode:=CTypeConvNode.Create(lNode,CWideCharType);
                  DoTypeCheckPass(lNode);
                end;
            end
          else
            begin
              if Is_Char(ACaseDef) and Is_WideChar(lNode.resultdef) then
                begin
                  if (lNode.nodetype=ordconstn) then
                    begin
                      lNode:=CTypeConvNode.Create(lNode,CAnsiCharType);
                      DoTypeCheckPass(lNode);
                    end
                  else if (lNode.nodetype=rangen) then
                    begin
                      TRangeNode(lNode).left:=CTypeConvNode.Create(TRangeNode(lNode).left,CAnsiCharType);
                      TRangeNode(lNode).right:=CTypeConvNode.Create(TRangeNode(lNode).right,CAnsiCharType);
                      DoTypeCheckPass(TRangeNode(lNode).left);
                      DoTypeCheckPass(TRangeNode(lNode).right);
                    end;
                end;
            end;
          lLowValue:=0;
          lHighValue:=0;
          lLowStringNode:=nil;
          lHighStringNode:=nil;
          if (lNode.nodetype=rangen) then
            begin
              { range }

              { type check for string case statements }
              if ACaseOfString and
                Is_ConstString_Or_ConstCharNode(TRangeNode(lNode).left) and
                Is_ConstString_Or_ConstCharNode(TRangeNode(lNode).right) then
              begin
                { we need stringconstnodes, even if expression contains single chars }
                lLowStringNode := Get_String_Value(TRangeNode(lNode).left, TStringDef(ACaseDef));
                lHighStringNode := Get_String_Value(TRangeNode(lNode).right, TStringDef(ACaseDef));
                if lLowStringNode.FullCompare(lHighStringNode) > 0 then
                  CGMessage(parser_e_case_lower_less_than_upper_bound);
              end

              { type checking for ordinal case statements }
              else if (not ACaseOfString) and
                Is_Subequal(ACaseDef, TRangeNode(lNode).left.resultdef) and
                Is_Subequal(ACaseDef, TRangeNode(lNode).right.resultdef) then
                begin
                  lLowValue:=Get_Ordinal_Value(TRangeNode(lNode).left);
                  lHighValue:=Get_Ordinal_Value(TRangeNode(lNode).right);
                  if lLowValue>lHighValue then
                    CGMessage(parser_e_case_lower_less_than_upper_bound);
                  if not ACaseDefError then
                    begin
                      AdaptRange(ACaseDef,lLowValue,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                      AdaptRange(ACaseDef,lHighValue,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                    end;
                end
              else
                CGMessage(parser_e_case_mismatch);

              if ACaseOfString then
                ACaseNode.AddLabel(ABlockID,lLowStringNode,lHighStringNode)
              else
                ACaseNode.AddLabel(ABlockID,lLowValue,lHighValue);
            end
          else
            begin
              { single value }

              { type check for string / ordinal case statements }
              if (ACaseOfString and (not Is_ConstString_Or_ConstCharNode(lNode))) or
                ((not ACaseOfString) and (not Is_Subequal(ACaseDef, lNode.resultdef))) then
                CGMessage(parser_e_case_mismatch);

              if ACaseOfString then
                begin
                  lLowStringNode:=Get_String_Value(lNode, TStringDef(ACaseDef));
                  ACaseNode.AddLabel(ABlockID,lLowStringNode,lLowStringNode);
                end
              else
                begin
                  lLowValue:=Get_Ordinal_Value(lNode);
                  if not ACaseDefError then
                    AdaptRange(ACaseDef,lLowValue,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                  ACaseNode.AddLabel(ABlockID,lLowValue,lLowValue);
                end;
            end;

          lNode.free;
          lNode := nil;
          lLowStringNode.free;
          lLowStringNode := nil;
          lHighStringNode.free;
          lHighStringNode := nil;

          if CurrentScanner.FToken=_COMMA then
            Consume(_COMMA)
          else
            break;
        until false;
        Consume(_COLON);
      end;


    procedure ConsumeCaseElse;
      begin
        if ([m_iso]*CurrentSettings.ModeSwitches)<>[] then
          Consume(_OTHERWISE)
        else if not TryToConsume(_ELSE) then
          Consume(_OTHERWISE);
      end;


    function CaseStatement : TNode;
      var
        lCaseDef : TDef;
        lBlockID : LongInt;
        lCaseDefError, lCaseOfString : Boolean;
        lCaseNode : TCaseNode;
      begin
        lCaseNode:=ReadCaseHead(lCaseDef,lCaseDefError,lCaseOfString);

        { Parse all case blocks }
        lBlockID:=0;
        repeat
          { maybe an instruction has more case labels }
          ReadCaseLabels(lCaseNode,lCaseDef,lBlockID,lCaseDefError,lCaseOfString);

          { add instruction block }
          lCaseNode.AddBlock(lBlockID,Statement);

          { next block }
          inc(lBlockID);

          if not(CurrentScanner.FToken in [_ELSE,_OTHERWISE,_END]) then
            Consume(_SEMICOLON);
        until (CurrentScanner.FToken in [_ELSE,_OTHERWISE,_END]);

        if (CurrentScanner.FToken in [_ELSE,_OTHERWISE]) then
          begin
            ConsumeCaseElse;
            lCaseNode.AddElseBlock(StatementsTilEnd);
          end
        else
          Consume(_END);

        Result:=lCaseNode;
      end;


    function CaseStmtExpr : TNode;
      var
        lCaseDef : TDef;
        lBlockID : LongInt;
        lCaseDefError, lCaseOfString : Boolean;
        lCaseNode : TCaseNode;
        lResultDef : TDef;
        lTypeNode : TNode;
        lIndex : LongInt;
        lStatements : TStatementNode;
        lResultVar : TTempCreateNode;

      function ReadBranch : TNode;
        begin
          Result:=Expr(true);
          lResultDef:=BranchType(lResultDef,Result,lTypeNode);
        end;

      { true if the case labels cover all values of the case expression }
      function IsExhaustive : Boolean;
        var
          lLowValue,lHighValue,lTypeCount : TConstExprInt;
        begin
          if lCaseDefError then
            exit(true);
          if lCaseOfString then
            exit(false);
          GetRange(lCaseDef,lLowValue,lHighValue);
          { low/high value of c-style booleans are not suitable for calculating their "type count" }
          if Is_CBool(lCaseDef) then
            exit(false);

          lTypeCount:=lHighValue-lLowValue;
          Result:=not (lCaseNode.LabelCoverage<lTypeCount);
        end;

      begin
        lResultDef:=nil;
        lTypeNode:=nil;
        lCaseNode:=ReadCaseHead(lCaseDef,lCaseDefError,lCaseOfString);

        { Parse all case branches }
        lBlockID:=0;
        repeat
          ReadCaseLabels(lCaseNode,lCaseDef,lBlockID,lCaseDefError,lCaseOfString);
          lCaseNode.AddBlock(lBlockID,ReadBranch);
          inc(lBlockID);

          if not(CurrentScanner.FToken in [_ELSE,_OTHERWISE,_END]) then
            Consume(_SEMICOLON);
        until (CurrentScanner.FToken in [_ELSE,_OTHERWISE,_END]);

        if (CurrentScanner.FToken in [_ELSE,_OTHERWISE]) then
          begin
            ConsumeCaseElse;
            lCaseNode.AddElseBlock(ReadBranch);
            TryToConsume(_SEMICOLON);
            Consume(_END);
          end
        else
          begin
            Consume(_END);
            if not IsExhaustive then
              Message(parser_e_stmt_expr_requires_else);
          end;

        if not Assigned(lResultDef) then
          begin
            { errors have already been reported }
            lCaseNode.free;
            Result:=CErrorNode.Create;
            exit;
          end;
        Result:=CreateStmtExprBlock(lResultDef,lStatements,lResultVar);
        if not IsAnonymousProcDef(lResultDef) then
          begin
            for lIndex:=0 to lCaseNode.Blocks.count-1 do
              PCaseBlock(lCaseNode.Blocks[lIndex])^.Statement:=CAssignmentNode.Create(
                CTempRefNode.Create(lResultVar),PCaseBlock(lCaseNode.Blocks[lIndex])^.Statement);
            if Assigned(lCaseNode.ElseBlock) then
              lCaseNode.ElseBlock:=CAssignmentNode.Create(CTempRefNode.Create(lResultVar),lCaseNode.ElseBlock);
          end;
        FinishStmtExprBlock(lStatements,lResultVar,lCaseNode);
      end;


    function RepeatStatement : TNode;

      var
         lFirst,lLast,lCondition : TNode;

      begin
         Consume(_REPEAT);

         lFirst:=nil;
         lLast:=nil;
         while CurrentScanner.FToken<>_UNTIL do
           begin
              if lFirst=nil then
                begin
                   lLast:=CStatementNode.Create(Statement,nil);
                   lFirst:=lLast;
                end
              else
                begin
                   TStatementNode(lLast).right:=CStatementNode.Create(Statement,nil);
                   lLast:=TStatementNode(lLast).right;
                end;
              if not TryToConsume(_SEMICOLON) then
                break;
              ConsumeEmptyStats;
           end;
         Consume(_UNTIL);

         lFirst:=CBlockNode.Create(lFirst);
         lCondition:=CompExpr([efAcceptEqual]);
         Result:=CWhileRepeatNode.Create(lCondition,lFirst,false,true);
      end;


    function WhileStatement : TNode;

      var
         lCondition,lBody : TNode;

      begin
         Consume(_WHILE);
         lCondition:=CompExpr([efAcceptEqual]);
         Consume(_DO);
         lBody:=Statement;
         Result:=CWhileRepeatNode.Create(lCondition,lBody,true,false);
      end;

    { a helper function which is used both by "with" and "for-in loop" nodes }
    function SkipNodesBeforeLoad(ANode: TNode): TNode;
      begin
        { ignore nodes that don't add instructions in the tree }
        while Assigned(ANode) and
           { equal type conversions }
           (
            (ANode.nodetype=typeconvn) and
            (TTypeConvNode(ANode).ConvType=tc_equal)
           ) or
           { constant array index }
           (
            (ANode.nodetype=vecn) and
            (TVecNode(ANode).right.nodetype=ordconstn)
           ) do
          ANode:=TUnaryNode(ANode).left;
        Result:=ANode;
      end;

    function ForStatement : TNode;

        procedure CheckRange(ANode:TNode; AForDef: TDef);
          begin
            if (ANode.nodetype=ordconstn) and
               (AForDef.typ<>errordef) and
               { the node was derived from a generic parameter so ignore range check }
               not(nf_generic_para in ANode.flags) then
              AdaptRange(AForDef,TOrdConstNode(ANode).Value,false,false,true);
          end;

        function ForLoopCreate(ALoopVar: TNode): TNode;
          var
             lNode,
             lBlock,
             lTo,lFrom : TNode;
             lBackward : Boolean;
             lLoopVarSym : TAbstractVarSym;
          begin
             { Check loop variable }
             lLoopVarSym:=nil;

             { variable must be an ordinal, int64 is not allowed for 32bit targets }
             if (
                 not(Is_Ordinal(ALoopVar.resultdef))
    {$if not defined(cpu64bitaddr) and not defined(cpu64bitalu)}
                 or Is_64BitInt(ALoopVar.resultdef)
    {$endif not cpu64bitaddr and not cpu64bitalu}
               ) and
               (ALoopVar.resultdef.typ<>undefineddef)
               then
               begin
                 MessagePos(ALoopVar.fileinfo,type_e_ordinal_expr_expected);
                 ALoopVar.resultdef:=GenErrorDef;
               end;

             lNode:=ALoopVar;
              while Assigned(lNode) and
                    (lNode.nodetype=typeconvn) and
                    (TTypeConvNode(lNode).ConvType=tc_equal) do
               begin
                 lNode:=TUnaryNode(lNode).left;
               end;

             if Assigned(lNode) and
                (lNode.nodetype=loadn) then
               begin
                 case TLoadNode(lNode).SymTableEntry.typ of
                   staticvarsym,
                   localvarsym,
                   paravarsym :
                     begin
                       { we need a simple loadn:
                           1. The load must be in a global symtable or
                               in the same level as the para of the current proc.
                           2. value variables (no const,out or var)
                           3. No threadvar, readonly or typedconst
                       }
                       if (
                           (TLoadNode(lNode).SymTable.SymTableLevel=MainProgramLevel) or
                           (TLoadNode(lNode).SymTable.SymTableLevel=CurrentProcInfo.procdef.ParaST.SymTableLevel)
                          ) and
                          (TAbstractVarSym(TLoadNode(lNode).SymTableEntry).VarSpez=vs_value) and
                          ([vo_is_thread_var,vo_is_typed_const] * TAbstractVarSym(TLoadNode(lNode).SymTableEntry).VarOptions=[]) then
                         begin
                           { Assigning for-loop variable is allowed in MacPas }
                           if not(m_mac in CurrentSettings.ModeSwitches) then
                             begin
                               if not Assigned(lLoopVarSym) then
                                 lLoopVarSym:=TAbstractVarSym(TLoadNode(lNode).SymTableEntry);
                               include(lLoopVarSym.VarOptions,vo_is_loop_counter);
                             end;
                         end
                       else
                         begin
                            MessagePos(lNode.fileinfo,type_e_illegal_count_var);
                         end;
                     end;
                   else
                     MessagePos(lNode.fileinfo,type_e_illegal_count_var);
                 end;
               end
             else
               MessagePos(ALoopVar.fileinfo,type_e_illegal_count_var);

             lFrom:=CompExpr([efAcceptEqual]);

             if TryToConsume(_DOWNTO) then
               lBackward:=true
             else
               begin
                 Consume(_TO);
                 lBackward:=false;
               end;

             lTo:=CompExpr([efAcceptEqual]);
             Consume(_DO);

             { Check if the constants fit in the range }
             CheckRange(lFrom,ALoopVar.resultdef);
             CheckRange(lTo,ALoopVar.resultdef);

             { first set the varstate for from and to, so
               uses of loopvar in those expressions will also
               trigger a warning when it is not used yet. This
               needs to be done before the instruction block is
               parsed to have a valid hloopvar }
             TypeCheckPass(lFrom);
             Set_VarState(lFrom,vs_read,[vsf_must_be_valid]);
             TypeCheckPass(lTo);
             Set_VarState(lTo,vs_read,[vsf_must_be_valid]);
             TypeCheckPass(ALoopVar);
             { in two steps, because vs_readwritten may turn on vsf_must_be_valid }
             { for some subnodes                                                  }
             Set_VarState(ALoopVar,vs_written,[]);
             Set_VarState(ALoopVar,vs_read,[vsf_must_be_valid]);

             { ... now the instruction block }
             lBlock:=Statement;

             { variable is not used for loop counter anymore }
             if Assigned(lLoopVarSym) then
               exclude(lLoopVarSym.VarOptions,vo_is_loop_counter);

             Result:=CForNode.Create(ALoopVar,lFrom,lTo,lBlock,lBackward);

             { only in tp and mac pascal mode, we care about the value of the loop counter on loop exit

               I am not sure though, if this is the right rule, at least in delphi the loop counter is undefined
               on loop exit, we assume the same in all FPC modes }
             if ([m_objfpc,m_fpc,m_delphi]*CurrentSettings.ModeSwitches)<>[] then
               Include(TForNode(Result).LoopFlags,lnf_dont_mind_loopvar_on_exit);
          end;


          function ForInLoopCreate(ALoopVar: TNode): TNode;
            var
              lEnumerableExpr,lLoopBody,lNode: TNode;
              lLoopVarSym: TAbstractVarSym;
            begin
              lNode:=SkipNodesBeforeLoad(ALoopVar);
              if Assigned(lNode)and(lNode.nodetype=loadn) then
                begin
                  lLoopVarSym:=TAbstractVarSym(TLoadNode(lNode).SymTableEntry);
                  include(lLoopVarSym.VarOptions,vo_is_loop_counter);
                end
              else
                lLoopVarSym:=nil;

              lEnumerableExpr:=CompExpr([efAcceptEqual]);

              Consume(_DO);

              Set_VarState(ALoopVar,vs_written,[]);
              Set_VarState(ALoopVar,vs_read,[vsf_must_be_valid]);

              lLoopBody:=Statement;
              if Assigned(lLoopVarSym) then
                exclude(lLoopVarSym.VarOptions,vo_is_loop_counter);
              Result:=Create_For_In_Loop(ALoopVar,lLoopBody,lEnumerableExpr);

              lEnumerableExpr.free;
              lEnumerableExpr := nil;
            end;


      var
         lLoopVar: TNode;
      begin
         { parse loop header }
         Consume(_FOR);

         lLoopVar:=Factor(false,[]);
         Valid_For_LoopVar(lLoopVar,true);

         if TryToConsume(_ASSIGNMENT) then
           Result:=ForLoopCreate(lLoopVar)
         else if TryToConsume(_IN) then
           Result:=ForInLoopCreate(lLoopVar)
         else
           begin
             Consume(_ASSIGNMENT); // fail
             Result:=CErrorNode.Create;
           end;
      end;


    function ParseWithStatement : TNode;

      var
         lNode   : TNode;
         lIndex   : LongInt;
         lSymTable  : TSymTable;
         lBlock : TBlockNode;
         lStatement : TStatementNode;
         lCallTempNode,
         lTempNode : TTempCreateNode;
         lValueNode,
         lLoadNode,
         lRefNode  : TNode;
         lDef : TDef;
         lHelperDef : TObjectDef;
         lHasImplicitDeref : Boolean;
         lWithSymTableList : TFPObjectList;

         procedure PushObjChild(AWithDef,AObjectDef:TObjectDef);
         var
           lParentHelperDef : TObjectDef;
         begin
           if not Assigned(AObjectDef) then
             exit;
           PushObjChild(AWithDef,AObjectDef.ChildOf);
           { we need to look for helpers that were defined for the parent
             class as well }
           Search_Last_ObjectPascal_Helper(AObjectDef,CurrentStructDef,lParentHelperDef);
           { push the symtables of the helper's parents in reverse order }
           if Assigned(lParentHelperDef) then
             PushObjChild(AWithDef,lParentHelperDef.ChildOf);
           { keep the original tobjectdef as owner, because that is used for
             visibility of the symtable }
           lSymTable:=TWithSymTable.Create(AWithDef,AObjectDef.SymTable.SymList,lRefNode.GetCopy);
           SymTableStack.push(lSymTable);
           lWithSymTableList.add(lSymTable);
           { push the symtable of the helper }
           if Assigned(lParentHelperDef) then
             begin
               lSymTable:=TWithSymTable.Create(AWithDef,lParentHelperDef.SymTable.SymList,lRefNode.GetCopy);
               SymTableStack.push(lSymTable);
               lWithSymTableList.add(lSymTable);
             end;
         end;


      begin
         lCallTempNode:=nil;
         lNode:=CompExpr([efAcceptEqual]);
         DoTypeCheckPass(lNode);

         if (lNode.nodetype=vecn) and
            (vnf_memseg in TVecNode(lNode).VecNodeFlags) then
           CGMessage(parser_e_no_with_for_variable_in_other_segments);

         { "with procvar" can never mean anything, so always try
           to call it in case it returns a record/object/... }
         Maybe_Call_ProcVar(lNode,false);

         if (lNode.resultdef.typ in [objectdef,recorddef,classrefdef]) or
           ((lNode.resultdef.typ=undefineddef) and (df_generic in CurrentProcInfo.procdef.DefOptions)) then
          begin
            lBlock:=nil;
            lValueNode:=nil;
            lTempNode:=nil;

            lLoadNode:=SkipNodesBeforeLoad(lNode);
            if (lLoadNode.nodetype=loadn) and
               (
                (TLoadNode(lLoadNode).SymTable=CurrentProcInfo.procdef.LocalST) or
                (TLoadNode(lLoadNode).SymTable=CurrentProcInfo.procdef.ParaST) or
                (TLoadNode(lLoadNode).SymTable.SymTableType in [staticsymtable,GlobalSymTable])
               ) and
               { MacPas objects are mapped to classes, and the MacPas compilers
                 interpret with-statements with MacPas objects the same way
                 as records (the object referenced by the with-statement
                 must remain constant)
               }
               not(Is_Class(lLoadNode.resultdef) and
                   (m_mac in CurrentSettings.ModeSwitches)) then
              begin
                { simple load, we can reference direct }
                lRefNode:=lNode;
              end
            else
              begin
                { complex load, load in temp first }
                lBlock:=InternalStatements(lStatement);
                { when we can't take the address of p, load it in a temp }
                { since we may need its address later on                 }
                if not Valid_For_Addr(lNode,false) then
                  begin
                    lCallTempNode:=CTempCreateNode.Create(lNode.resultdef,lNode.resultdef.Size,tt_persistent,true);
                    AddStatement(lStatement,lCallTempNode);
                    AddStatement(lStatement,CAssignmentNode.Create(
                        CTempRefNode.Create(lCallTempNode),
                        lNode));
                    lNode:=CTempRefNode.Create(lCallTempNode);
                    TypeCheckPass(lNode);
                  end;
                { several object types have implicit dereferencing }

                lHasImplicitDeref:=
                  Is_Implicit_Pointer_Object_Type(lNode.resultdef) or
                  (lNode.resultdef.typ=classrefdef);
                if lHasImplicitDeref then
                  lDef:=lNode.resultdef
                else
                  lDef:=CPointerDef.Create(lNode.resultdef);
                { load address of the value in a temp }
                lTempNode:=CTempCreateNode.Create_WithNode(lDef,sizeof(PInt),tt_persistent,true,lNode);
                TypeCheckPass(TNode(lTempNode));
                lValueNode:=lNode;
                lRefNode:=CTempRefNode.Create(lTempNode);
                fillchar(lRefNode.fileinfo,sizeof(TFilePosInfo),0);
                { add address call for valuenode and deref for refnode if this
                  is not done implicitly }
                if not lHasImplicitDeref then
                  begin
                    lValueNode:=CAddrNode.Create_Internal_NoMark(lValueNode);
                    include(TAddrNode(lValueNode).AddrNodeFlags,anf_typedaddr);
                    lRefNode:=CDerefNode.Create(lRefNode);
                    fillchar(lRefNode.fileinfo,sizeof(TFilePosInfo),0);
                  end;
                AddStatement(lStatement,lTempNode);
                AddStatement(lStatement,CAssignmentNode.Create(
                    CTempRefNode.Create(lTempNode),
                    lValueNode));
                TypeCheckPass(lRefNode);
              end;
            { Note: the symtable of the helper is pushed after the following
                    "case", the symtables of the helper's parents are passed in
                    the "case" branches }
            lWithSymTableList:=TFPObjectList.Create(true);
            case lNode.resultdef.typ of
              objectdef :
                begin
                   { do we have a helper for this type? }
                   Search_Last_ObjectPascal_Helper(TAbstractRecordDef(lNode.resultdef),CurrentStructDef,lHelperDef);
                   { push symtables of all parents in reverse order }
                   PushObjChild(TObjectDef(lNode.resultdef),TObjectDef(lNode.resultdef).ChildOf);
                   { push symtables of all parents of the helper in reverse order }
                   if Assigned(lHelperDef) then
                     PushObjChild(lHelperDef,lHelperDef.ChildOf);
                   { push object symtable }
                   lSymTable:=TWithSymTable.Create(TObjectDef(lNode.resultdef),TObjectDef(lNode.resultdef).SymTable.SymList,lRefNode);
                   SymTableStack.push(lSymTable);
                   lWithSymTableList.add(lSymTable);
                 end;
              classrefdef :
                begin
                   { do we have a helper for this type? }
                   Search_Last_ObjectPascal_Helper(TObjectDef(TClassRefDef(lNode.resultdef).PointedDef),CurrentStructDef,lHelperDef);
                   { push symtables of all parents in reverse order }
                   PushObjChild(TObjectDef(TClassRefDef(lNode.resultdef).PointedDef),TObjectDef(TClassRefDef(lNode.resultdef).PointedDef).ChildOf);
                   { push symtables of all parents of the helper in reverse order }
                   if Assigned(lHelperDef) then
                     PushObjChild(lHelperDef,lHelperDef.ChildOf);
                   { push object symtable }
                   lSymTable:=TWithSymTable.Create(TObjectDef(TClassRefDef(lNode.resultdef).PointedDef),TObjectDef(TClassRefDef(lNode.resultdef).PointedDef).SymTable.SymList,lRefNode);
                   SymTableStack.push(lSymTable);
                   lWithSymTableList.add(lSymTable);
                end;
              recorddef :
                begin
                   { do we have a helper for this type? }
                   Search_Last_ObjectPascal_Helper(TAbstractRecordDef(lNode.resultdef),CurrentStructDef,lHelperDef);
                   { push symtables of all parents of the helper in reverse order }
                   if Assigned(lHelperDef) then
                     PushObjChild(lHelperDef,lHelperDef.ChildOf);
                   { push record symtable }
                   lSymTable:=TWithSymTable.Create(TRecordDef(lNode.resultdef),TRecordDef(lNode.resultdef).SymTable.SymList,lRefNode);
                   SymTableStack.push(lSymTable);
                   lWithSymTableList.add(lSymTable);
                end;
              undefineddef :
                begin
                   if not(df_generic in CurrentProcInfo.procdef.DefOptions) then
                     InternalError(2012122802);
                   lHelperDef:=nil;
                   { push record symtable }
                   lSymTable:=TWithSymTable.Create(lNode.resultdef,nil,lRefNode);
                   SymTableStack.push(lSymTable);
                   lWithSymTableList.add(lSymTable);
                end;
              else
                InternalError(200601271);
            end;

            { push helper symtable }
            if Assigned(lHelperDef) then
              begin
                lSymTable:=TWithSymTable.Create(lHelperDef,lHelperDef.SymTable.SymList,lRefNode.GetCopy);
                SymTableStack.push(lSymTable);
                lWithSymTableList.add(lSymTable);
              end;

            if TryToConsume(_COMMA) then
              lNode:=ParseWithStatement()
            else
              begin
                Consume(_DO);
                if CurrentScanner.FToken<>_SEMICOLON then
                  lNode:=Statement
                else
                  lNode:=CNothingNode.Create;
              end;

            { remove symtables in reverse order from the stack }
            for lIndex:=lWithSymTableList.count-1 downto 0 do
              SymTableStack.pop(TSymTable(lWithSymTableList[lIndex]));
            lWithSymTableList.free;
            lWithSymTableList := nil;

            { Finalize complex withnode with destroy of temp }
            if Assigned(lBlock) then
             begin
               AddStatement(lStatement,lNode);
               if Assigned(lTempNode) then
                 AddStatement(lStatement,CTempDeleteNode.Create(lTempNode));
               if Assigned(lCallTempNode) then
                 AddStatement(lStatement,CTempDeleteNode.Create(lCallTempNode));
               lNode:=lBlock;
             end;
            Result:=lNode;
          end
         else
          begin
            Message1(parser_e_false_with_expr,lNode.resultdef.GetTypeName);
            lNode.free;
            lNode := nil;
            { try to recover from error }
            if TryToConsume(_COMMA) then
             begin
               lLoadNode:=ParseWithStatement();
               if (lLoadNode=nil) then; { remove warning about unused }
             end
            else
             begin
               Consume(_DO);
               { ignore all }
               if CurrentScanner.FToken<>_SEMICOLON then
                Statement;
             end;
            Result:=CErrorNode.Create;
          end;
      end;


    function WithStatement : TNode;
      begin
         Consume(_WITH);
         WithStatement:=ParseWithStatement();
      end;


    function RaiseStatement : TNode;
      var
         lNode,lObjectNode,lAddressNode,lFrameNode : TNode;
      begin
         lObjectNode:=nil;
         lAddressNode:=nil;
         lFrameNode:=nil;
         Consume(_RAISE);
         if not(CurrentScanner.FToken in cEndTokens) then
           begin
              { object }
              lObjectNode:=CompExpr([efAcceptEqual]);
              if TryToConsume(_AT) then
                begin
                   lAddressNode:=CompExpr([efAcceptEqual]);
                   if TryToConsume(_COMMA) then
                     lFrameNode:=CompExpr([efAcceptEqual]);
                end;
           end
         else
           begin
              if (Block_Type<>bt_except) then
                Message(parser_e_no_reraise_possible);
           end;
         if (po_noreturn in CurrentProcInfo.procdef.ProcOptions) and (ExceptBlockCounter=0) then
           Message(parser_e_raise_with_noreturn_not_allowed);
         lNode:=CRaiseNode.Create(lObjectNode,lAddressNode,lFrameNode);
         RaiseStatement:=lNode;
      end;


    procedure CheckExceptTypeValid(var ADef: TDef);
      begin
        if not (Is_Class(ADef) or (ADef.typ=errordef)) then
          begin
            Message1(type_e_class_type_expected,ADef.TypeName);
            ADef:=GenErrorDef;
          end;
      end;


    { parses "on [name:] type do" and pushes the exception symtable }
    procedure ReadOnHead(out AExceptType : TDef; out AExceptSymTable : TSymTable);
      var
        lLocalSym : TLocalVarSym;
        lObjectName,lObjectRealName : TIDString;
        lSearchSym : TSym;
        lSearchSymTable : TSymTable;
        lToken : TToken;
        lUnitFound : Boolean;
      begin
        AExceptType:=GenErrorDef;
        AExceptSymTable:=nil;
        Consume(_ON);
        if CurrentScanner.FToken=_ID then
          begin
            lObjectName:=CurrentScanner.FPattern;
            lObjectRealName:=CurrentScanner.FOrgPattern;
            { can't use consume_sym here, because we need already
              to check for the colon }
            SearchSym(lObjectName,lSearchSym,lSearchSymTable);
            Consume(_ID);
            { is a explicit name for the exception given ? }
            if TryToConsume(_COLON) then
              begin
                SingleType(AExceptType,[]);
                CheckExceptTypeValid(AExceptType);
                lLocalSym:=CLocalVarSym.Create(lObjectRealName,vs_value,AExceptType,[]);
              end
            else
              begin
                { check if type is valid, must be done here because
                  with "e: Exception" the e is not necessary }

                { support unit.identifier }
                lToken:=NOTOKEN;
                lUnitFound:=TryConsumeUnitSymNoSpecialize(lSearchSym,lSearchSymTable,lToken,[],lObjectName);
                if lSearchSym=nil then
                  begin
                    IdentifierNotFound(lObjectRealName);
                    lSearchSym:=GenErrorSym;
                  end;
                if lUnitFound then
                  Consume(lToken);
                { check if type is valid, must be done here because
                  with "e: Exception" the e is not necessary }
                if (lSearchSym.typ=TypeSym) then
                  begin
                    AExceptType:=TTypeSym(lSearchSym).TypeDef;
                    ParseNestedTypes(AExceptType,false,false,nil);
                    CheckExceptTypeValid(AExceptType);
                  end
                else
                  begin
                    Message(type_e_type_id_expected);
                    AExceptType:=GenErrorDef;
                  end;

                { create dummy symbol so we don't need a special
                  case in ncgflw, and so that we always know the
                  type }
                lLocalSym:=CLocalVarSym.Create('$exceptsym',vs_value,AExceptType,[]);
              end;
            AExceptSymTable:=TSTTExceptSymTable.Create;
            AExceptSymTable.DefOwner:=CurrentProcInfo.procdef;
            AExceptSymTable.InsertSym(lLocalSym);
            SymTableStack.push(AExceptSymTable);
          end
        else
          Consume(_ID);
        Consume(_DO);
      end;


    { appends the on node hp to the list p_specific and pops the exception symtable }
    procedure AddOnNode(ANode : TNode; AExceptType : TDef; AExceptSymTable : TSymTable;
        var ASpecific, ALast : TNode);
      begin
         if AExceptType.typ=errordef then
           begin
              ANode.free;
              ANode:=CErrorNode.Create;
           end;
         if ASpecific=nil then
           begin
              ALast:=ANode;
              ASpecific:=ALast;
           end
         else
           begin
              TOnNode(ALast).left:=ANode;
              ALast:=TOnNode(ALast).left;
           end;
         { set the informations }
         { only if the creation of the onnode was successful, it's possible}
         { that last and hp are errornodes (JM)                            }
         if ALast.nodetype = onn then
           begin
             TOnNode(ALast).ExceptType:=TObjectDef(AExceptType);
             TOnNode(ALast).ExceptSymTable:=AExceptSymTable;
           end;
         { remove exception symtable }
         if Assigned(AExceptSymTable) then
           begin
             SymTableStack.pop(AExceptSymTable);
             if ALast.nodetype <> onn then
               begin
                 AExceptSymTable.free;
                 AExceptSymTable := nil;
               end;
           end;
      end;


    function TryStatement : TNode;
      var
        lTryBlock,lFinallyBlock,lFirst,lLast,
        lDefault,lSpecific,lNode : TNode;
        lExceptType : TDef;
        lOldBlockType : TBlockType;
        lExceptSymTable : TSymTable;
        lOldCurrentExceptBlock: Integer;
        lTryFilePos : TFilePosInfo;
      begin
        lDefault:=nil;
        lSpecific:=nil;
        lLast:=nil;

        { read statements to try }
        Consume(_TRY);
        lTryFilePos:=CurrentFilePos;
        lFirst:=nil;
        inc(ExceptBlockCounter);
        lOldCurrentExceptBlock := Current_ExceptBlock;
        Current_ExceptBlock := ExceptBlockCounter;
        lOldBlockType := Block_Type;
        Block_Type := bt_body;

        while (CurrentScanner.FToken<>_FINALLY) and (CurrentScanner.FToken<>_EXCEPT) do
          begin
            if lFirst=nil then
              begin
                lLast:=CStatementNode.Create(Statement,nil);
                lFirst:=lLast;
              end
            else
              begin
                TStatementNode(lLast).right:=CStatementNode.Create(Statement,nil);
                lLast:=TStatementNode(lLast).right;
              end;
            if not TryToConsume(_SEMICOLON) then
              break;
            ConsumeEmptyStats;
          end;
        lTryBlock:=CBlockNode.Create(lFirst);

        if TryToConsume(_FINALLY) then
          begin
            inc(ExceptBlockCounter);
            Current_ExceptBlock := ExceptBlockCounter;
            lFinallyBlock:=StatementsTilEnd;
            Result:=CTryFinallyNode.Create(lTryBlock,lFinallyBlock);
            Result.fileinfo:=lTryFilePos;
          end
        else
          begin
            Consume(_EXCEPT);
            Block_Type:=bt_except;
            inc(ExceptBlockCounter);
            Current_ExceptBlock := ExceptBlockCounter;
            if (CurrentScanner.FIDToken=_ON) then
              { on: catch specific exceptions }
              begin
                lLast:=nil;
                repeat
                  ReadOnHead(lExceptType,lExceptSymTable);
                  lNode:=COnNode.Create(nil,Statement);
                  AddOnNode(lNode,lExceptType,lExceptSymTable,lSpecific,lLast);
                  if not TryToConsume(_SEMICOLON) then
                    break;
                  ConsumeEmptyStats;
                until (CurrentScanner.FToken in [_END,_ELSE]);
                if TryToConsume(_ELSE) then
                  lDefault:=StatementsTilEnd
                else
                  Consume(_END);
              end
            else
              lDefault:=StatementsTilEnd;

            Result:=CTryExceptNode.Create(lTryBlock,lSpecific,lDefault);
          end;
        Block_Type:=lOldBlockType;
        Current_ExceptBlock := lOldCurrentExceptBlock;
      end;


    function TryStmtExpr : TNode;
      var
        lResultDef : TDef;
        lTypeNode : TNode;

      function ReadBranch : TNode;
        begin
          Result:=Expr(true);
          lResultDef:=BranchType(lResultDef,Result,lTypeNode);
        end;

      { wraps the expressions of all on-branches into assignments to temp }
      procedure UpdateOnNodeAssignment(ATemp : TTempCreateNode; AOnNode : TNode);
        begin
          while Assigned(AOnNode) and (AOnNode.nodetype=onn) do
            begin
              TOnNode(AOnNode).right:=CAssignmentNode.Create(CTempRefNode.Create(ATemp),TOnNode(AOnNode).right);
              AOnNode:=TOnNode(AOnNode).left;
            end;
        end;

      var
        lTryBlock,lFinallyBlock,
        lDefault,lSpecific,lLast,lNode : TNode;
        lExceptType : TDef;
        lOldBlockType : TBlockType;
        lExceptSymTable : TSymTable;
        lOldCurrentExceptBlock: Integer;
        lTryNode : TTryExceptNode;
        lStatements : TStatementNode;
        lResultVar : TTempCreateNode;
      begin
        lDefault:=nil;
        lSpecific:=nil;
        lLast:=nil;
        lResultDef:=nil;
        lTypeNode:=nil;

        { read expression to try }
        Consume(_TRY);
        inc(ExceptBlockCounter);
        lOldCurrentExceptBlock := Current_ExceptBlock;
        Current_ExceptBlock := ExceptBlockCounter;
        lOldBlockType := Block_Type;
        Block_Type := bt_body;

        lTryBlock:=ReadBranch;

        if TryToConsume(_FINALLY) then
          begin
            Message(parser_e_stmt_expr_no_finally);
            { recover }
            inc(ExceptBlockCounter);
            Current_ExceptBlock := ExceptBlockCounter;
            lFinallyBlock:=StatementsTilEnd;
            lTryBlock.free;
            lFinallyBlock.free;
            Block_Type:=lOldBlockType;
            Current_ExceptBlock := lOldCurrentExceptBlock;
            Result:=CErrorNode.Create;
            exit;
          end;

        Consume(_EXCEPT);
        Block_Type:=bt_except;
        inc(ExceptBlockCounter);
        Current_ExceptBlock := ExceptBlockCounter;
        if (CurrentScanner.FIDToken=_ON) then
          { on: catch specific exceptions }
          begin
            repeat
              ReadOnHead(lExceptType,lExceptSymTable);
              if lExceptType.typ=errordef then
                { the on node is replaced by an error node, don't use it for the result type }
                lNode:=COnNode.Create(nil,Expr(true))
              else
                lNode:=COnNode.Create(nil,ReadBranch);
              AddOnNode(lNode,lExceptType,lExceptSymTable,lSpecific,lLast);
              if not TryToConsume(_SEMICOLON) then
                break;
              ConsumeEmptyStats;
            until (CurrentScanner.FToken in [_END,_ELSE]);
            if TryToConsume(_ELSE) then
              begin
                { else: catch the other exceptions }
                lDefault:=ReadBranch;
                TryToConsume(_SEMICOLON);
                Consume(_END);
              end
            else
              begin
                Consume(_END);
                Message(parser_e_stmt_expr_requires_else);
              end;
          end
        else
          begin
            { default: catch all exceptions }
            lDefault:=ReadBranch;
            TryToConsume(_SEMICOLON);
            Consume(_END);
          end;
        Block_Type:=lOldBlockType;
        Current_ExceptBlock := lOldCurrentExceptBlock;

        lTryNode:=TTryExceptNode(CTryExceptNode.Create(lTryBlock,lSpecific,lDefault));
        if not Assigned(lResultDef) then
          begin
            { errors have already been reported }
            lTryNode.free;
            Result:=CErrorNode.Create;
            exit;
          end;
        Result:=CreateStmtExprBlock(lResultDef,lStatements,lResultVar);
        if not IsAnonymousProcDef(lResultDef) then
          begin
            lTryNode.left:=CAssignmentNode.Create(CTempRefNode.Create(lResultVar),lTryNode.left);
            UpdateOnNodeAssignment(lResultVar,lTryNode.right);
            if Assigned(lTryNode.t1) then
              lTryNode.t1:=CAssignmentNode.Create(CTempRefNode.Create(lResultVar),lTryNode.t1);
          end;
        FinishStmtExprBlock(lStatements,lResultVar,lTryNode);
      end;


    function StatementExpr(var ANode : TNode) : Boolean;
      begin
        if not (m_statement_expressions in CurrentSettings.ModeSwitches) then
          exit(false);
        Result:=true;
        case CurrentScanner.FToken of
          _IF:
            ANode:=IfStmtExpr;
          _CASE:
            ANode:=CaseStmtExpr;
          _TRY:
            ANode:=TryStmtExpr;
          else
            Result:=false;
        end;
      end;


    function ParseAsmStatement : TNode;
      var
        lAsmNode : TAsmNode;
        lRegister     : TRegister;
        lAsmReader : TBaseAsmReader;
        lEntryPos : TFilePosInfo;
        lAsmList : TAsmList;
      begin
         Inside_Asm_Statement:=true;
         lAsmNode:=nil;
         lAsmList:=nil;

         { apply all switch changes as the assembler readers doesn't do so }
         FlushPendingSwitchesState;

         if Assigned(asmmodeinfos[Ord(CurrentSettings.AsmMode)]) then
           begin
             lAsmReader:=asmmodeinfos[Ord(CurrentSettings.AsmMode)]^.CAsmReader.Create;
             lEntryPos:=CurrentFilePos;
             lAsmList:=lAsmReader.assemble as TAsmList;
             if (not lAsmList.empty) then
               begin
                 { mark boundaries of assembler block, this is necessary for optimizer }
                 lAsmList.insert(TAIMarker.Create(mark_asmblockstart));
                 lAsmList.concat(TAIMarker.Create(mark_asmblockend));
               end;
             lAsmNode:=CAsmNode.Create(lAsmList);
             lAsmNode.fileinfo:=lEntryPos;
             lAsmReader.free;
             lAsmReader := nil;
           end
         else
           Message(parser_f_assembler_reader_not_supported);

         { Mark procedure that it has assembler blocks }
         include(CurrentProcInfo.flags,pi_has_assembler_block);

         { Read first the _ASM statement }
         Consume(_ASM);

         { Force an empty register list for pure assembler routines,
           so that pass2 won't allocate volatile registers for them. }
         if (po_assembler in CurrentProcInfo.procdef.ProcOptions) then
           Include(lAsmNode.AsmNodeFlags,asmnf_has_registerlist);

         { END is read, got a list of changed registers? }
         if TryToConsume(_LECKKLAMMER) then
           begin
             if CurrentScanner.FToken<>_RECKKLAMMER then
              begin
                if po_assembler in CurrentProcInfo.procdef.ProcOptions then
                  Message(parser_w_register_list_ignored);
                repeat
                  { it's possible to specify the modified registers }
                  if CurrentScanner.FToken=_CSTRING then
                    lRegister:=std_regnum_search(lower(CurrentScanner.FCStringPattern))
                  else if CurrentScanner.FToken=_CCHAR then
                    lRegister:=std_regnum_search(lower(CurrentScanner.FPattern))
                  else
                    lRegister:=NR_NO;
                  { is_extra_reg is not exported on all architectures from cpubase }
                  if lRegister<>NR_NO then
                    begin
                      if not(po_assembler in CurrentProcInfo.procdef.ProcOptions) and Assigned(lAsmList) then
                        begin
                          lAsmList.Insert(TAIRegAlloc.alloc(lRegister,nil));
                          lAsmList.Insert(TAIRegAlloc.markused(lRegister));
                          lAsmList.Concat(TAIRegAlloc.dealloc(lRegister,nil));
                        end;
                    end
                  else
                    Message(asmr_e_invalid_register);
                  if CurrentScanner.FToken=_CCHAR then
                    Consume(_CCHAR)
                  else
                    Consume(_CSTRING);
                  if not TryToConsume(_COMMA) then
                    break;
                until false;
                Include(lAsmNode.AsmNodeFlags,asmnf_has_registerlist);
              end;
             Consume(_RECKKLAMMER);
           end;

         Inside_Asm_Statement:=false;
         ParseAsmStatement:=lAsmNode;
      end;


    { Old Turbo Pascal INLINE(data/data/...) }
    function TPInlineStatement : TNode;
      var
        lConstType : TAIConstType;

      function EvalIntConst: ASizeInt;
        var
          lConstValue : TConstExprInt;
          lDef: TDef;
        begin
          lConstValue:=GetIntConst;
          case lConstType of
            aitconst_8bit:
              lDef:=S8IntType;
            aitconst_16bit:
              lDef:=S16IntType;
            else
              lDef:=SizeSIntType;
          end;
          if lConstValue.uvalue>Get_Max_Value(lDef).uvalue then
            lDef:=Get_Unsigned_IntType(lDef);
          AdaptRange(lDef,lConstValue,rc_implicit);
          Result:=lConstValue.svalue;
        end;

      var
        lCurrentLine : LongInt;
        lDataValue : ASizeInt;
        lAsmList : TAsmList;
        lAsmNode : TAsmNode;
        lSym : TSym;
        lSymTable : TSymTable;
        lName : TSymStr;
        lAsmConst : TAIConst;
        lNesting : Integer;
        lTokenBuf : TDynamicArray;
      begin
        Consume(_INLINE);
        Consume(_LKLAMMER);
        lAsmList:=TAsmList.Create;
        lAsmNode:=CAsmNode.Create(lAsmList);
        lAsmNode.fileinfo:=CurrentFilePos;
        lTokenBuf:=TDynamicArray.Create(16);
        lCurrentLine:=0;
        { Parse data blocks }
        repeat
          { Record one data block for further replaying.
            This is needed  since / is used as a data block delimiter and cause troubles
            with constant evaluation which is allowed inside a data block. }
          lTokenBuf.reset;
          CurrentScanner.StartRecordTokens(lTokenBuf);
          lNesting:=0;
          while CurrentScanner.FToken<>_SLASH do
            begin
              case CurrentScanner.FToken of
                _LKLAMMER:
                  inc(lNesting);
                _RKLAMMER:
                  begin
                    dec(lNesting);
                    if lNesting<0 then
                      break;
                  end;
                _SEMICOLON:
                  Consume(_RKLAMMER); { error }
                else
                  ; {no action}
              end;
              Consume(CurrentScanner.FToken);
            end;
          CurrentScanner.StopRecordTokens;
          { Set the current token to ; to make the constant evaluator happy }
          CurrentScanner.FToken:=_SEMICOLON;
          { Parse recorded tokens }
          CurrentScanner.StartReplayTokens(lTokenBuf);

          if lCurrentLine<>CurrentFilePos.line then
            begin
              lAsmList.concat(TAIForceLine.Create);
              lCurrentLine:=CurrentFilePos.line;
            end;

          { Data size override }
          if TryToConsume(_GT) then
            lConstType:=aitconst_16bit
          else
            if TryToConsume(_LT) then
              lConstType:=aitconst_8bit
            else
              lConstType:=aitconst_128bit; { default size }
          lSym:=nil;
          if CurrentScanner.FToken=_ID then
            begin
              if SearchSym(CurrentScanner.FPattern,lSym,lSymTable) then
                begin
                  if lSym.typ in [staticvarsym,localvarsym,paravarsym] then
                    begin
                      { Address of the static symbol or base offset for local symbols }
                      Consume(_ID);
                      if (lSym.typ=staticvarsym) and not (lConstType in [aitconst_128bit,aitconst_ptr]) then
                        Message1(type_e_integer_expr_expected,lSym.name);
                      { Additional offset }
                      if CurrentScanner.FToken in [_PLUS,_MINUS] then
                        lDataValue:=EvalIntConst
                      else
                        lDataValue:=0;
                      if lSym.typ=staticvarsym then
                        lName:=lSym.MangledName
                      else
                        lName:=lSym.name;
                      lAsmConst:=TAIConst.Createname(lName,lDataValue);
                      if lConstType=aitconst_128bit then
                        lAsmConst.consttype:=aitconst_ptr
                      else
                        lAsmConst.consttype:=lConstType;
                      { For a local symbol it is needed to generate a constant with the symbols's stack offset.
                        The stack offset is unavailable rigth now and will be resolved later in tcgasmnode.pass_generate_code.
                        Set sym.bind:=AB_NONE to indicate that this is a local symbol. }
                      if lSym.typ<>staticvarsym then
                        lAsmConst.sym.bind:=AB_NONE;
                      lAsmList.concat(lAsmConst);
                    end
                  else
                    if lSym.typ=constsym then
                      lSym:=nil
                    else
                      begin
                        Consume(_ID);
                        Message(asmr_e_wrong_sym_type);
                      end;
                end;
            end;

          if lSym=nil then
            begin
              { Integer constant expression }
              lDataValue:=EvalIntConst;
              case lConstType of
                aitconst_8bit:
                  lAsmList.concat(TAIConst.Create_8bit(lDataValue));
                aitconst_16bit:
                  lAsmList.concat(TAIConst.Create_16bit(lDataValue));
                else
                  if lDataValue<$100 then
                    lAsmList.concat(TAIConst.Create_8bit(lDataValue))
                  else
                    lAsmList.concat(TAIConst.Create_sizeint(lDataValue));
              end;
            end;

          if not TryToConsume(_SEMICOLON) then
            Consume(_RKLAMMER); {error}
        until lNesting<0;
        lTokenBuf.free;
        lTokenBuf := nil;
        { mark boundaries of assembler block, this is necessary for optimizer }
        lAsmList.insert(TAIMarker.Create(mark_asmblockstart));
        lAsmList.concat(TAIMarker.Create(mark_asmblockend));
        { Mark procedure that it has assembler blocks }
        include(CurrentProcInfo.flags,pi_has_assembler_block);
        { Assume the function result is always used }
        if Assigned(CurrentProcInfo.procdef.FuncRetSym) then
          CurrentProcInfo.procdef.FuncRetSym.IncRefCount;
        Result:=lAsmNode;
      end;


    function Statement : TNode;
      var
         lNode,
         lStatement,
         lCodeNode       : TNode;
         lFilePos    : TFilePosInfo;
         lSearchSym      : TSym;
         lSearchSymTable : TSymTable;
         lName          : TIDString;
      begin
         lFilePos:=CurrentTokenPos;
         lCodeNode:=nil;
         case CurrentScanner.FToken of
           _GOTO :
             begin
                if not(cs_support_goto in CurrentSettings.ModuleSwitches) then
                  Message(sym_e_goto_and_label_not_supported);
                Consume(_GOTO);
                if (CurrentScanner.FToken<>_INTCONST) and (CurrentScanner.FToken<>_ID) then
                  begin
                    Message(sym_e_label_not_found);
                    lCodeNode:=CErrorNode.Create;
                  end
                else
                  begin
                     if CurrentScanner.FToken=_ID then
                       begin
                         lSearchSym:=nil;
                         lSearchSymTable:=nil;
                         ConsumeSym(lSearchSym,lSearchSymTable);
                       end
                     else
                      begin
                        if CurrentScanner.FToken<>_INTCONST then
                          InternalError(201008021);

                        { strip leading 0's in iso mode }
                        if (([m_iso]*CurrentSettings.ModeSwitches)<>[]) then
                          while (length(CurrentScanner.FPattern)>1) and (CurrentScanner.FPattern[1]='0') do
                            delete(CurrentScanner.FPattern,1,1);

                        SearchSym(CurrentScanner.FPattern,lSearchSym,lSearchSymTable);
                        if lSearchSym=nil then
                          begin
                            IdentifierNotFound(CurrentScanner.FPattern);
                            lSearchSym:=GenErrorSym;
                            lSearchSymTable:=nil;
                          end;
                        Consume(CurrentScanner.FToken);
                      end;

                     if lSearchSym.typ<>labelsym then
                       begin
                          Message(sym_e_id_is_no_label_id);
                          lCodeNode:=CErrorNode.Create;
                       end
                     else
                       begin
                         { goto outside the current scope? }
                         if lSearchSym.owner<>CurrentProcInfo.procdef.LocalST then
                           begin
                             { allowed? }
                             if not(m_non_local_goto in CurrentSettings.ModeSwitches) then
                               Message(parser_e_goto_outside_proc);
                             include(CurrentProcInfo.flags,pi_has_global_goto);
                             if Is_Nested_PD(CurrentProcInfo.procdef) then
                               CurrentProcInfo.Set_Needs_ParentFP(lSearchSym.owner.SymTableLevel);
                           end;
                         lCodeNode:=CGotoNode.Create(TLabelSym(lSearchSym));
                         TGotoNode(lCodeNode).LabelSym:=TLabelSym(lSearchSym);
                         { set flag that this label is used }
                         TLabelSym(lSearchSym).used:=true;
                       end;
                  end;
             end;
           _BEGIN :
             begin
               lCodeNode:=StatementBlock(_BEGIN);
               Include(TBlockNode(lCodeNode).BlockNodeFlags, bnf_strippable);
             end;
           _IF :
             lCodeNode:=IfStatement;
           _CASE :
             lCodeNode:=CaseStatement;
           _REPEAT :
             lCodeNode:=RepeatStatement;
           _WHILE :
             lCodeNode:=WhileStatement;
           _FOR :
             lCodeNode:=ForStatement;
           _WITH :
             lCodeNode:=WithStatement;
           _TRY :
             lCodeNode:=TryStatement;
           _RAISE :
             lCodeNode:=RaiseStatement;
           { semicolons,else until and end are ignored }
           _SEMICOLON,
           _ELSE,
           _UNTIL,
           _END:
             lCodeNode:=CNothingNode.Create;
           _FAIL :
             begin
                if (CurrentProcInfo.procdef.ProcTypeOption<>potype_constructor) then
                  Message(parser_e_fail_only_in_constructor);
                Consume(_FAIL);
                lCodeNode:=CNodeUtils.Call_Fail_Node;
             end;
           _ASM :
             begin
               if ParseGeneric then
                 Message(parser_e_no_assembler_in_generic);
               lCodeNode:=ParseAsmStatement;
             end;
           _PLUS:
             begin
               Message(parser_e_syntax_error);
               Consume(_PLUS);
             end;
           _INLINE:
             begin
               lCodeNode:=TPInlineStatement;
             end;
           _EOF :
             if CurrentScanner.FHadMultilineString then
               Message2(scan_f_unterminated_multiline_string,
                        ToStr(CurrentScanner.FMultilineStartLine),
                        ToStr(CurrentScanner.FMultilineStartColumn))
             else
               Message(scan_f_end_of_file);
         else
           begin
             { don't typecheck yet, because that will also simplify, which may
               result in not detecting certain kinds of syntax errors --
               see mantis #15594 }
             lNode:=Expr(false);
             { save the current_scanner.pattern here for latter usage, the label could be "000",
               even if we read an expression, the current_scanner.pattern is still valid if it's really
               a label (FK)
               if you want to mess here, take care of
               tests/tbs/tw3546.pas
             }
             lName:=CurrentScanner.FPattern;

             { When a colon follows a intconst then transform it into a label }
             if (lNode.nodetype=ordconstn) and
                TryToConsume(_COLON) then
              begin
                { in iso mode, 0003: is equal to 3: }
                if (([m_iso]*CurrentSettings.ModeSwitches)<>[]) then
                  SearchSym(ToStr(TOrdConstNode(lNode).Value),lSearchSym,lSearchSymTable)
                else
                  SearchSym(lName,lSearchSym,lSearchSymTable);
                lNode.free;
                lNode := nil;

                if Assigned(lSearchSym) and
                   (lSearchSym.typ=labelsym) then
                 begin
                   if TLabelSym(lSearchSym).defined then
                     Message(sym_e_label_already_defined);
                   if SymTableStack.top.SymTableLevel<>lSearchSymTable.SymTableLevel then
                     begin
                       include(CurrentProcInfo.flags,pi_has_interproclabel);
                       if (CurrentProcInfo.procdef.ProcTypeOption in [potype_unitinit,potype_unitfinalize]) then
                         Message(sym_e_interprocgoto_into_init_final_code_not_allowed);
                     end;

                   TLabelSym(lSearchSym).defined:=true;
                   lNode:=CLabelNode.Create(nil,TLabelSym(lSearchSym));
                   TLabelSym(lSearchSym).code:=lNode;
                 end
                else
                 begin
                   Message1(sym_e_label_used_and_not_defined,lName);
                   lNode:=CNothingNode.Create;
                 end;
              end;

             if lNode.nodetype=labeln then
               begin
                 if not(CurrentScanner.FToken in cEndTokens) then
                   begin
                     lStatement:=Statement();
                     TypeCheckPass(lStatement);
                     lNode:=CBlockNode.Create(CStatementNode.Create(lNode,CStatementNode.Create(lStatement,nil)));
                     Include(TBlockNode(lNode).BlockNodeFlags, bnf_strippable);
                   end;
               end
             else
               { change a load of a procvar to a call. this is also
                 supported in fpc mode }
               if lNode.nodetype in [vecn,derefn,typeconvn,subscriptn,loadn] then
                 Maybe_Call_ProcVar(lNode,false);

             { blockn support because a read/write is changed into a blocknode
               with a separate statement for each read/write operation (JM)
               the same is true for val() if the third parameter is not 32 bit

               goto nodes are created by the compiler for non local exit statements, so
               include them as well
             }
             if not(lNode.nodetype in [nothingn,errorn,calln,ifn,assignn,breakn,inlinen,
                                   continuen,labeln,blockn,exitn,goton]) or
                ((lNode.nodetype=inlinen) and
                 not TInlineNode(lNode).May_Ignore_Result) or
                ((lNode.nodetype=calln) and
                 (Assigned(TCallNode(lNode).ProcDefinition)) and
                 (TCallNode(lNode).ProcDefinition.ProcTypeOption=potype_operator)) then
               Message(parser_e_illegal_expression);

             if not Assigned(lNode.resultdef) then
               DoTypeCheckPass(lNode);

             { Specify that we don't use the value returned by the call.
               This is used for :
                - dispose of temp stack space
                - dispose on FPU stack
                - extended syntax checking }
             if (lNode.nodetype=calln) then
               begin
                 exclude(TCallNode(lNode).CallNodeFlags,cnf_return_value_used);

                 { in $x- state, the function result must not be ignored }
                 if not(cs_extsyntax in CurrentSettings.ModuleSwitches) and
                    not(Is_Void(lNode.resultdef)) and
                    { can be nil in case there was an error in the expression }
                    Assigned(TCallNode(lNode).ProcDefinition) and
                    { allow constructor calls to drop the result if they are
                      called as instance methods instead of class methods }
                    not(
                      (TCallNode(lNode).ProcDefinition.ProcTypeOption=potype_constructor) and
                      Is_Class_Or_Object(TProcDef(TCallNode(lNode).ProcDefinition).struct) and
                      Assigned(TCallNode(lNode).MethodPointer) and
                      (TNode(TCallNode(lNode).MethodPointer).resultdef.typ=objectdef)
                    ) then
                   Message(parser_e_illegal_expression);
               end;

             lCodeNode:=lNode;
           end;
         end;
         if Assigned(lCodeNode) then
           begin
             TypeCheckPass(lCodeNode);
             lCodeNode.fileinfo:=lFilePos;
           end;
         Statement:=lCodeNode;
      end;


    function StatementBlock(AStartToken : TToken) : TNode;

      var
         lFirst,lLast : TNode;
         lFilePos : TFilePosInfo;

      begin
         lFirst:=nil;
         lLast:=nil;
         lFilePos:=CurrentTokenPos;
         Consume(AStartToken);

         while not((CurrentScanner.FToken=_END) or (CurrentScanner.FToken=_FINALIZATION)) do
           begin
              if lFirst=nil then
                begin
                   lLast:=CStatementNode.Create(Statement,nil);
                   lFirst:=lLast;
                end
              else
                begin
                   TStatementNode(lLast).right:=CStatementNode.Create(Statement,nil);
                   lLast:=TStatementNode(lLast).right;
                end;
              if ((CurrentScanner.FToken=_END) or (CurrentScanner.FToken=_FINALIZATION)) then
                break
              else
                begin
                   { if no semicolon, then error and go on }
                   if CurrentScanner.FToken<>_SEMICOLON then
                     begin
                        Consume(_SEMICOLON);
                        ConsumeAllUntil(_SEMICOLON);
                     end;
                   Consume(_SEMICOLON);
                end;
              ConsumeEmptyStats;
           end;

         { don't consume the finalization token, it is consumed when
           reading the finalization block, but allow it only after
           an initialization ! }
         if (AStartToken<>_INITIALIZATION) or (CurrentScanner.FToken<>_FINALIZATION) then
           Consume(_END);

         lLast:=CBlockNode.Create(lFirst);
         lLast.fileinfo:=lFilePos;
         StatementBlock:=lLast;
      end;


    function AssemblerBlock : TNode;
      var
        lNode : TNode;
        lLocalCount : LongInt;
        lSearchSym : TSym;
      begin
         if ParseGeneric then
           message(parser_e_no_assembler_in_generic);

         { Rename the funcret so that recursive calls are possible }
         if not Is_Void(CurrentProcInfo.procdef.ReturnDef) then
           begin
             lSearchSym:=TSym(CurrentProcInfo.procdef.LocalST.Find(CurrentProcInfo.procdef.ProcSym.name));
             if Assigned(lSearchSym) then
               lSearchSym.realname:='$hiddenresult';
           end;

         { delphi uses register calling for assembler methods }
         if (m_delphi in CurrentSettings.ModeSwitches) and
            (po_assembler in CurrentProcInfo.procdef.ProcOptions) and
            not(po_hascallingconvention in CurrentProcInfo.procdef.ProcOptions) then
           CurrentProcInfo.procdef.ProcCallOption:=pocall_register;

         { force the asm statement }
         if CurrentScanner.FToken<>_ASM then
           Consume(_ASM);
         include(CurrentProcInfo.flags,pi_is_assembler);
         lNode:=ParseAsmStatement;

         if (po_assembler in CurrentProcInfo.procdef.ProcOptions) then
           begin
             { set the framepointer to esp for assembler functions when the
               following conditions are met:
               - if the are no local variables and parameters (except the allocated result)
               - no reference to the result variable (refcount<=1)
               - result is not stored as parameter
               - target processor has optional frame pointer save
                 (vm, i386, vm only currently)
             }
             lLocalCount:=TAbstractLocalSymTable(CurrentProcInfo.procdef.ParaST).Count_Locals;
             if (CurrentProcInfo.procdef.LocalST.SymTableType=LocalSymTable) then
               inc(lLocalCount,TAbstractLocalSymTable(CurrentProcInfo.procdef.LocalST).Count_Locals);
             if (lLocalCount=0) and
                not (CurrentProcInfo.procdef.owner.SymTableType in [ObjectSymtable,recordsymtable]) and
                (not Assigned(CurrentProcInfo.procdef.FuncRetSym) or
                 (TAbstractVarSym(CurrentProcInfo.procdef.FuncRetSym).refs<=1)) and
                not (df_generic in CurrentProcInfo.procdef.DefOptions) and
                not(ParaManager.Ret_In_Param(CurrentProcInfo.procdef.ReturnDef,CurrentProcInfo.procdef)) then
               begin
                 { Only need to set the framepointer, the locals will
                   be inserted with the correct reference in tcgasmnode.pass_generate_code }
                 CurrentProcInfo.FramePointer:=NR_STACK_POINTER_REG;
               end;
           end;

        { Flag the result as assigned when it is returned in a
          register.
        }
        if Assigned(CurrentProcInfo.procdef.FuncRetSym) and
            not (df_generic in CurrentProcInfo.procdef.DefOptions) and
           (not ParaManager.Ret_In_Param(CurrentProcInfo.procdef.ReturnDef,CurrentProcInfo.procdef)) then
          TAbstractVarSym(CurrentProcInfo.procdef.FuncRetSym).VarState:=vs_initialised;

        { because the END is already read we need to get the
          last_endtoken_filepos here (PFV) }
        LastEndTokenFilePos:=CurrentTokenPos;

        AssemblerBlock:=lNode;
      end;

end.
