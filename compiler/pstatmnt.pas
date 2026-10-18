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


    function statement_block(starttoken : TToken) : TNode;

    { parses an if-, case- or try-expression, if modeswitch statementexpressions is enabled }
    function statement_expr(var p1 : TNode) : boolean;

    { reads an assembler block }
    function assembler_block : TNode;


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


    function statement : TNode;forward;


    function is_anonymous_procdef(def : TDef) : boolean;
      begin
        result:=Assigned(def) and
                (def.typ=procdef) and
                (po_anonymous in TProcDef(def).ProcOptions);
      end;


    { returns the common type of olddef and the type of branchtree,
      oldtree is the node that determines the type }
    function branch_type(olddef : TDef; branchtree : TNode; var oldtree : TNode) : TDef;

      function commonancestor(c1,c2 : TObjectDef; var a : TDef) : boolean;
        var
          curr, check : TObjectDef;
        begin
          result:=false;
          curr:=c1;
          while Assigned(curr) do
            begin
              check:=c2;
              while Assigned(check) do
                begin
                  if check=curr then
                    begin
                      result:=true;
                      a:=curr;
                      exit;
                    end;
                  check:=check.ChildOf;
                end;
              curr:=curr.ChildOf;
            end;
        end;

      var
        branchdef : TDef;
        cmp : TEqualType;
      begin
        if not Assigned(branchtree) or
            not Assigned(branchtree.resultdef) or
            (branchtree.resultdef.typ=errordef) then
          exit(olddef);

        branchdef:=branchtree.resultdef;
        if not Assigned(olddef) then
          begin
            oldtree:=branchtree;
            exit(branchdef);
          end;

        { anonymous functions get their type when the statement expression
          is converted to a procvar or function reference, see ncnv }
        if is_anonymous_procdef(olddef) then
          exit(olddef);
        if is_anonymous_procdef(branchdef) then
          begin
            oldtree:=branchtree;
            exit(branchdef);
          end;

        { combining string/char types }
        if Is_AnyChar(olddef) and Is_String(branchdef) then
          result:=branchdef
        else if Is_WideString(branchdef) or Is_WideString(olddef) or
                ((Is_AnsiString(olddef) or Is_CharArray(olddef)) and Is_WideChar(branchdef)) then
          result:=CWideStringType
        else if Is_UnicodeString(branchdef) or Is_UnicodeString(olddef) then
          result:=CUnicodeStringType
        else if Is_Char(olddef) and Is_WideChar(branchdef) then
          result:=CWideCharType
        { constant strings: use longest }
        else if Is_CharArray(olddef) and Is_CharArray(branchdef) then
          begin
            result:=olddef;
            if TArrayDef(olddef).EleCount<TArrayDef(branchdef).EleCount then
              result:=branchdef;
          end
        { shortstrings: use longest }
        else if Is_ShortString(olddef) and Is_ShortString(branchdef) then
          begin
            result:=olddef;
            if TStringDef(olddef).len<TStringDef(branchdef).len then
              result:=branchdef;
          end
        { combine with variant results in a variant }
        else if (olddef.typ=variantdef) or (branchdef.typ=variantdef) then
          result:=CVariantType
        else if (olddef.typ=objectdef) and (branchdef.typ=objectdef) and
                commonancestor(TObjectDef(olddef),TObjectDef(branchdef),result) then
          { result set by commonancestor }
        else
          begin
            { combine to biggest }
            result:=olddef;
            cmp:=Compare_Defs(olddef,branchdef,oldtree.nodetype);
            if (cmp<te_equal) and
                (cmp>Compare_Defs(branchdef,olddef,branchtree.nodetype)) then
              result:=branchdef;
          end;

        if result<>olddef then
          oldtree:=branchtree;
      end;


    { creates a temp for the result of a statement expression block }
    function create_stmt_expr_block(resdef : TDef; out statements : TStatementNode;
        out resultvar : TTempCreateNode) : TNode;
      begin
        result:=InternalStatements(statements);
        resultvar:=CTempCreateNode.Create(resdef,resdef.Size,tt_persistent,
                                          not is_anonymous_procdef(resdef));
        AddStatement(statements,resultvar);
      end;


    procedure finish_stmt_expr_block(statements : TStatementNode;
        resultvar : TTempCreateNode; valuenode : TNode);
      begin
        AddStatement(statements,valuenode);
        AddStatement(statements,CTempDeleteNode.Create_Normal_Temp(resultvar));
        AddStatement(statements,CTempRefNode.Create(resultvar));
      end;


    function if_stmt_expr : TNode;
      var
        ex, if_a, else_a, typenode : TNode;
        statements : TStatementNode;
        resultvar : TTempCreateNode;
        resdef : TDef;
      begin
        consume(_IF);
        ex:=comp_expr([ef_accept_equal]);
        consume(_THEN);
        if_a:=expr(true);
        consume(_ELSE);
        else_a:=expr(true);

        typenode:=nil;
        resdef:=branch_type(nil,if_a,typenode);
        resdef:=branch_type(resdef,else_a,typenode);
        if not Assigned(resdef) then
          begin
            { errors have already been reported }
            ex.free;
            if_a.free;
            else_a.free;
            result:=CErrorNode.Create;
            exit;
          end;
        result:=create_stmt_expr_block(resdef,statements,resultvar);
        if is_anonymous_procdef(resdef) then
          finish_stmt_expr_block(statements,resultvar,CIfNode.Create(ex,if_a,else_a))
        else
          finish_stmt_expr_block(statements,resultvar,
            CIfNode.Create(ex,
              CAssignmentNode.Create(CTempRefNode.Create(resultvar),if_a),
              CAssignmentNode.Create(CTempRefNode.Create(resultvar),else_a)));
        exit;
      end;

    function if_statement : TNode;
      var
        ex, if_a, else_a : TNode;
      begin
        consume(_IF);
        ex:=comp_expr([ef_accept_equal]);
        consume(_THEN);

        if not(CurrentScanner.token in endtokens) then
          if_a:=statement
        else
          if_a:=nil;

        if try_to_consume(_ELSE) then
          else_a:=statement
        else
          else_a:=nil;
        result:=CIfNode.Create(ex,if_a,else_a);
      end;

    { creates a block (list) of statements, til the next END token }
    function statements_til_end : TNode;

      var
         first,last : TStatementNode;

      begin
         first:=nil;
         last:=nil;
         while CurrentScanner.token<>_END do
           begin
              if first=nil then
                begin
                   last:=CStatementNode.Create(statement,nil);
                   first:=last;
                end
              else
                begin
                   last.right:=CStatementNode.Create(statement,nil);
                   last:=TStatementNode(last.right);
                end;
              if not try_to_consume(_SEMICOLON) then
                break;
              consume_emptystats;
           end;
         consume(_END);
         statements_til_end:=CBlockNode.Create(first);
         if Assigned(first) then
           statements_til_end.fileinfo:=first.fileinfo;
      end;


    { parses "case <expr> of" }
    function read_case_head(out casedef : TDef; out casedeferror, caseofstring : boolean) : TCaseNode;
      var
        caseexpr : TNode;
      begin
        consume(_CASE);
        caseexpr:=comp_expr([ef_accept_equal]);
        { determines result type }
        DoTypeCheckPass(caseexpr);
        { variants must be accepted, but first they must be converted to integer }
        if caseexpr.resultdef.typ=variantdef then
          begin
            caseexpr:=CTypeConvNode.Create_Internal(caseexpr,SIntType);
            DoTypeCheckPass(caseexpr);
          end;
        set_varstate(caseexpr,vs_read,[vsf_must_be_valid]);
        casedeferror:=false;
        casedef:=caseexpr.resultdef;
        { case of string must be rejected in Delphi and MacPas modes. }
        caseofstring :=
          ([m_delphi, m_mac] * CurrentSettings.ModeSwitches = []) and
          Is_String(casedef);

        if (not Assigned(casedef)) or
            ( not(Is_Ordinal(casedef)) and (not caseofstring) ) then
        begin
          CGMessage(type_e_ordinal_or_string_expr_expected);
          { create a valid tree }
          caseexpr.free;
          caseexpr:=COrdConstNode.Create(0,U32IntType,false);
          { set error flag so no rangechecks are done }
          casedeferror:=true;
         end;
        { Create casenode }
        result:=CCaseNode.Create(caseexpr);
        consume(_OF);
      end;


    { parses the labels of one case block, including the colon }
    procedure read_case_labels(casenode : TCaseNode; casedef : TDef; BlockID : LongInt;
        casedeferror, caseofstring : boolean);
      var
        p : TNode;
        hl1,hl2 : TConstExprInt;
        sl1,sl2 : TStringConstNode;
      begin
        repeat
          p:=expr(true);
          if Is_WideChar(casedef) then
            begin
              if (p.nodetype=rangen) then
                begin
                  TRangeNode(p).left:=CTypeConvNode.Create(TRangeNode(p).left,CWideCharType);
                  TRangeNode(p).right:=CTypeConvNode.Create(TRangeNode(p).right,CWideCharType);
                  DoTypeCheckPass(TRangeNode(p).left);
                  DoTypeCheckPass(TRangeNode(p).right);
                end
              else
                begin
                  p:=CTypeConvNode.Create(p,CWideCharType);
                  DoTypeCheckPass(p);
                end;
            end
          else
            begin
              if Is_Char(casedef) and Is_WideChar(p.resultdef) then
                begin
                  if (p.nodetype=ordconstn) then
                    begin
                      p:=CTypeConvNode.Create(p,CAnsiCharType);
                      DoTypeCheckPass(p);
                    end
                  else if (p.nodetype=rangen) then
                    begin
                      TRangeNode(p).left:=CTypeConvNode.Create(TRangeNode(p).left,CAnsiCharType);
                      TRangeNode(p).right:=CTypeConvNode.Create(TRangeNode(p).right,CAnsiCharType);
                      DoTypeCheckPass(TRangeNode(p).left);
                      DoTypeCheckPass(TRangeNode(p).right);
                    end;
                end;
            end;
          hl1:=0;
          hl2:=0;
          sl1:=nil;
          sl2:=nil;
          if (p.nodetype=rangen) then
            begin
              { range }

              { type check for string case statements }
              if caseofstring and
                Is_ConstString_Or_ConstCharNode(TRangeNode(p).left) and
                Is_ConstString_Or_ConstCharNode(TRangeNode(p).right) then
              begin
                { we need stringconstnodes, even if expression contains single chars }
                sl1 := Get_String_Value(TRangeNode(p).left, TStringDef(casedef));
                sl2 := Get_String_Value(TRangeNode(p).right, TStringDef(casedef));
                if sl1.FullCompare(sl2) > 0 then
                  CGMessage(parser_e_case_lower_less_than_upper_bound);
              end

              { type checking for ordinal case statements }
              else if (not caseofstring) and
                Is_Subequal(casedef, TRangeNode(p).left.resultdef) and
                Is_Subequal(casedef, TRangeNode(p).right.resultdef) then
                begin
                  hl1:=Get_Ordinal_Value(TRangeNode(p).left);
                  hl2:=Get_Ordinal_Value(TRangeNode(p).right);
                  if hl1>hl2 then
                    CGMessage(parser_e_case_lower_less_than_upper_bound);
                  if not casedeferror then
                    begin
                      AdaptRange(casedef,hl1,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                      AdaptRange(casedef,hl2,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                    end;
                end
              else
                CGMessage(parser_e_case_mismatch);

              if caseofstring then
                casenode.AddLabel(BlockID,sl1,sl2)
              else
                casenode.AddLabel(BlockID,hl1,hl2);
            end
          else
            begin
              { single value }

              { type check for string / ordinal case statements }
              if (caseofstring and (not Is_ConstString_Or_ConstCharNode(p))) or
                ((not caseofstring) and (not Is_Subequal(casedef, p.resultdef))) then
                CGMessage(parser_e_case_mismatch);

              if caseofstring then
                begin
                  sl1:=Get_String_Value(p, TStringDef(casedef));
                  casenode.AddLabel(BlockID,sl1,sl1);
                end
              else
                begin
                  hl1:=Get_Ordinal_Value(p);
                  if not casedeferror then
                    AdaptRange(casedef,hl1,false,false,cs_check_range in CurrentSettings.LocalSwitches);
                  casenode.AddLabel(BlockID,hl1,hl1);
                end;
            end;

          p.free;
          p := nil;
          sl1.free;
          sl1 := nil;
          sl2.free;
          sl2 := nil;

          if CurrentScanner.token=_COMMA then
            consume(_COMMA)
          else
            break;
        until false;
        consume(_COLON);
      end;


    procedure consume_case_else;
      begin
        if ([m_iso,m_extpas]*CurrentSettings.ModeSwitches)<>[] then
          consume(_OTHERWISE)
        else if not try_to_consume(_ELSE) then
          consume(_OTHERWISE);
      end;


    function case_statement : TNode;
      var
        casedef : TDef;
        BlockID : LongInt;
        casedeferror, caseofstring : boolean;
        casenode : TCaseNode;
      begin
        casenode:=read_case_head(casedef,casedeferror,caseofstring);

        { Parse all case blocks }
        BlockID:=0;
        repeat
          { maybe an instruction has more case labels }
          read_case_labels(casenode,casedef,BlockID,casedeferror,caseofstring);

          { add instruction block }
          casenode.AddBlock(BlockID,statement);

          { next block }
          inc(BlockID);

          if not(CurrentScanner.token in [_ELSE,_OTHERWISE,_END]) then
            consume(_SEMICOLON);
        until (CurrentScanner.token in [_ELSE,_OTHERWISE,_END]);

        if (CurrentScanner.token in [_ELSE,_OTHERWISE]) then
          begin
            consume_case_else;
            casenode.AddElseBlock(statements_til_end);
          end
        else
          consume(_END);

        result:=casenode;
      end;


    function case_stmt_expr : TNode;
      var
        casedef : TDef;
        BlockID : LongInt;
        casedeferror, caseofstring : boolean;
        casenode : TCaseNode;
        resdef : TDef;
        typenode : TNode;
        i : LongInt;
        statements : TStatementNode;
        resultvar : TTempCreateNode;

      function read_branch : TNode;
        begin
          result:=expr(true);
          resdef:=branch_type(resdef,result,typenode);
        end;

      { true if the case labels cover all values of the case expression }
      function is_exhaustive : boolean;
        var
          lv,hv,typcount : TConstExprInt;
        begin
          if casedeferror then
            exit(true);
          if caseofstring then
            exit(false);
          GetRange(casedef,lv,hv);
          { low/high value of c-style booleans are not suitable for calculating their "type count" }
          if Is_CBool(casedef) then
            exit(false);

          typcount:=hv-lv;
          result:=not (casenode.LabelCoverage<typcount);
        end;

      begin
        resdef:=nil;
        typenode:=nil;
        casenode:=read_case_head(casedef,casedeferror,caseofstring);

        { Parse all case branches }
        BlockID:=0;
        repeat
          read_case_labels(casenode,casedef,BlockID,casedeferror,caseofstring);
          casenode.AddBlock(BlockID,read_branch);
          inc(BlockID);

          if not(CurrentScanner.token in [_ELSE,_OTHERWISE,_END]) then
            consume(_SEMICOLON);
        until (CurrentScanner.token in [_ELSE,_OTHERWISE,_END]);

        if (CurrentScanner.token in [_ELSE,_OTHERWISE]) then
          begin
            consume_case_else;
            casenode.AddElseBlock(read_branch);
            try_to_consume(_SEMICOLON);
            consume(_END);
          end
        else
          begin
            consume(_END);
            if not is_exhaustive then
              Message(parser_e_stmt_expr_requires_else);
          end;

        if not Assigned(resdef) then
          begin
            { errors have already been reported }
            casenode.free;
            result:=CErrorNode.Create;
            exit;
          end;
        result:=create_stmt_expr_block(resdef,statements,resultvar);
        if not is_anonymous_procdef(resdef) then
          begin
            for i:=0 to casenode.Blocks.count-1 do
              PCaseBlock(casenode.Blocks[i])^.statement:=CAssignmentNode.Create(
                CTempRefNode.Create(resultvar),PCaseBlock(casenode.Blocks[i])^.statement);
            if Assigned(casenode.ElseBlock) then
              casenode.ElseBlock:=CAssignmentNode.Create(CTempRefNode.Create(resultvar),casenode.ElseBlock);
          end;
        finish_stmt_expr_block(statements,resultvar,casenode);
      end;


    function repeat_statement : TNode;

      var
         first,last,p_e : TNode;

      begin
         consume(_REPEAT);

         first:=nil;
         last:=nil;
         while CurrentScanner.token<>_UNTIL do
           begin
              if first=nil then
                begin
                   last:=CStatementNode.Create(statement,nil);
                   first:=last;
                end
              else
                begin
                   TStatementNode(last).right:=CStatementNode.Create(statement,nil);
                   last:=TStatementNode(last).right;
                end;
              if not try_to_consume(_SEMICOLON) then
                break;
              consume_emptystats;
           end;
         consume(_UNTIL);

         first:=CBlockNode.Create(first);
         p_e:=comp_expr([ef_accept_equal]);
         result:=CWhileRepeatNode.Create(p_e,first,false,true);
      end;


    function while_statement : TNode;

      var
         p_e,p_a : TNode;

      begin
         consume(_WHILE);
         p_e:=comp_expr([ef_accept_equal]);
         consume(_DO);
         p_a:=statement;
         result:=CWhileRepeatNode.Create(p_e,p_a,true,false);
      end;

    { a helper function which is used both by "with" and "for-in loop" nodes }
    function skip_nodes_before_load(p: TNode): TNode;
      begin
        { ignore nodes that don't add instructions in the tree }
        while Assigned(p) and
           { equal type conversions }
           (
            (p.nodetype=typeconvn) and
            (TTypeConvNode(p).ConvType=tc_equal)
           ) or
           { constant array index }
           (
            (p.nodetype=vecn) and
            (TVecNode(p).right.nodetype=ordconstn)
           ) do
          p:=TUnaryNode(p).left;
        result:=p;
      end;

    function for_statement : TNode;

        procedure check_range(hp:TNode; fordef: TDef);
          begin
            if (hp.nodetype=ordconstn) and
               (fordef.typ<>errordef) and
               { the node was derived from a generic parameter so ignore range check }
               not(nf_generic_para in hp.flags) then
              AdaptRange(fordef,TOrdConstNode(hp).Value,false,false,true);
          end;

        function for_loop_create(hloopvar: TNode): TNode;
          var
             hp,
             hblock,
             hto,hfrom : TNode;
             backward : boolean;
             loopvarsym : TAbstractVarSym;
          begin
             { Check loop variable }
             loopvarsym:=nil;

             { variable must be an ordinal, int64 is not allowed for 32bit targets }
             if (
                 not(Is_Ordinal(hloopvar.resultdef))
    {$if not defined(cpu64bitaddr) and not defined(cpu64bitalu)}
                 or Is_64BitInt(hloopvar.resultdef)
    {$endif not cpu64bitaddr and not cpu64bitalu}
               ) and
               (hloopvar.resultdef.typ<>undefineddef)
               then
               begin
                 MessagePos(hloopvar.fileinfo,type_e_ordinal_expr_expected);
                 hloopvar.resultdef:=GenErrorDef;
               end;

             hp:=hloopvar;
              while Assigned(hp) and
                    (hp.nodetype=typeconvn) and
                    (TTypeConvNode(hp).ConvType=tc_equal) do
               begin
                 hp:=TUnaryNode(hp).left;
               end;

             if Assigned(hp) and
                (hp.nodetype=loadn) then
               begin
                 case TLoadNode(hp).SymTableEntry.typ of
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
                           (TLoadNode(hp).SymTable.SymTableLevel=MainProgramLevel) or
                           (TLoadNode(hp).SymTable.SymTableLevel=CurrentProcInfo.procdef.ParaST.SymTableLevel)
                          ) and
                          (TAbstractVarSym(TLoadNode(hp).SymTableEntry).VarSpez=vs_value) and
                          ([vo_is_thread_var,vo_is_typed_const] * TAbstractVarSym(TLoadNode(hp).SymTableEntry).VarOptions=[]) then
                         begin
                           { Assigning for-loop variable is allowed in MacPas }
                           if not(m_mac in CurrentSettings.ModeSwitches) then
                             begin
                               if not Assigned(loopvarsym) then
                                 loopvarsym:=TAbstractVarSym(TLoadNode(hp).SymTableEntry);
                               include(loopvarsym.VarOptions,vo_is_loop_counter);
                             end;
                         end
                       else
                         begin
                            MessagePos(hp.fileinfo,type_e_illegal_count_var);
                         end;
                     end;
                   else
                     MessagePos(hp.fileinfo,type_e_illegal_count_var);
                 end;
               end
             else
               MessagePos(hloopvar.fileinfo,type_e_illegal_count_var);

             hfrom:=comp_expr([ef_accept_equal]);

             if try_to_consume(_DOWNTO) then
               backward:=true
             else
               begin
                 consume(_TO);
                 backward:=false;
               end;

             hto:=comp_expr([ef_accept_equal]);
             consume(_DO);

             { Check if the constants fit in the range }
             check_range(hfrom,hloopvar.resultdef);
             check_range(hto,hloopvar.resultdef);

             { first set the varstate for from and to, so
               uses of loopvar in those expressions will also
               trigger a warning when it is not used yet. This
               needs to be done before the instruction block is
               parsed to have a valid hloopvar }
             TypeCheckPass(hfrom);
             set_varstate(hfrom,vs_read,[vsf_must_be_valid]);
             TypeCheckPass(hto);
             set_varstate(hto,vs_read,[vsf_must_be_valid]);
             TypeCheckPass(hloopvar);
             { in two steps, because vs_readwritten may turn on vsf_must_be_valid }
             { for some subnodes                                                  }
             set_varstate(hloopvar,vs_written,[]);
             set_varstate(hloopvar,vs_read,[vsf_must_be_valid]);

             { ... now the instruction block }
             hblock:=statement;

             { variable is not used for loop counter anymore }
             if Assigned(loopvarsym) then
               exclude(loopvarsym.VarOptions,vo_is_loop_counter);

             result:=CForNode.Create(hloopvar,hfrom,hto,hblock,backward);

             { only in tp and mac pascal mode, we care about the value of the loop counter on loop exit

               I am not sure though, if this is the right rule, at least in delphi the loop counter is undefined
               on loop exit, we assume the same in all FPC modes }
             if ([m_objfpc,m_fpc,m_delphi]*CurrentSettings.ModeSwitches)<>[] then
               Include(TForNode(Result).LoopFlags,lnf_dont_mind_loopvar_on_exit);
          end;


          function for_in_loop_create(hloopvar: TNode): TNode;
            var
              expr,hloopbody,hp: TNode;
              loopvarsym: TAbstractVarSym;
            begin
              hp:=skip_nodes_before_load(hloopvar);
              if Assigned(hp)and(hp.nodetype=loadn) then
                begin
                  loopvarsym:=TAbstractVarSym(TLoadNode(hp).SymTableEntry);
                  include(loopvarsym.VarOptions,vo_is_loop_counter);
                end
              else
                loopvarsym:=nil;

              expr:=comp_expr([ef_accept_equal]);

              consume(_DO);

              set_varstate(hloopvar,vs_written,[]);
              set_varstate(hloopvar,vs_read,[vsf_must_be_valid]);

              hloopbody:=statement;
              if Assigned(loopvarsym) then
                exclude(loopvarsym.VarOptions,vo_is_loop_counter);
              result:=Create_For_In_Loop(hloopvar,hloopbody,expr);

              expr.free;
              expr := nil;
            end;


      var
         hloopvar: TNode;
      begin
         { parse loop header }
         consume(_FOR);

         hloopvar:=factor(false,[]);
         valid_for_loopvar(hloopvar,true);

         if try_to_consume(_ASSIGNMENT) then
           result:=for_loop_create(hloopvar)
         else if try_to_consume(_IN) then
           result:=for_in_loop_create(hloopvar)
         else
           begin
             consume(_ASSIGNMENT); // fail
             result:=CErrorNode.Create;
           end;
      end;


    function _with_statement : TNode;

      var
         p   : TNode;
         i   : LongInt;
         st  : TSymTable;
         newblock : TBlockNode;
         newstatement : TStatementNode;
         calltempnode,
         tempnode : TTempCreateNode;
         valuenode,
         hp,
         refnode  : TNode;
         hdef : TDef;
         helperdef : TObjectDef;
         hasimplicitderef : boolean;
         withsymtablelist : TFPObjectList;

         procedure pushobjchild(withdef,obj:TObjectDef);
         var
           parenthelperdef : TObjectDef;
         begin
           if not Assigned(obj) then
             exit;
           pushobjchild(withdef,obj.ChildOf);
           { we need to look for helpers that were defined for the parent
             class as well }
           Search_Last_ObjectPascal_Helper(obj,CurrentStructDef,parenthelperdef);
           { push the symtables of the helper's parents in reverse order }
           if Assigned(parenthelperdef) then
             pushobjchild(withdef,parenthelperdef.ChildOf);
           { keep the original tobjectdef as owner, because that is used for
             visibility of the symtable }
           st:=TWithSymTable.Create(withdef,obj.SymTable.SymList,refnode.GetCopy);
           SymTableStack.push(st);
           withsymtablelist.add(st);
           { push the symtable of the helper }
           if Assigned(parenthelperdef) then
             begin
               st:=TWithSymTable.Create(withdef,parenthelperdef.SymTable.SymList,refnode.GetCopy);
               SymTableStack.push(st);
               withsymtablelist.add(st);
             end;
         end;


      begin
         calltempnode:=nil;
         p:=comp_expr([ef_accept_equal]);
         DoTypeCheckPass(p);

         if (p.nodetype=vecn) and
            (vnf_memseg in TVecNode(p).VecNodeFlags) then
           CGMessage(parser_e_no_with_for_variable_in_other_segments);

         { "with procvar" can never mean anything, so always try
           to call it in case it returns a record/object/... }
         Maybe_Call_ProcVar(p,false);

         if (p.resultdef.typ in [objectdef,recorddef,classrefdef]) or
           ((p.resultdef.typ=undefineddef) and (df_generic in CurrentProcInfo.procdef.DefOptions)) then
          begin
            newblock:=nil;
            valuenode:=nil;
            tempnode:=nil;

            hp:=skip_nodes_before_load(p);
            if (hp.nodetype=loadn) and
               (
                (TLoadNode(hp).SymTable=CurrentProcInfo.procdef.LocalST) or
                (TLoadNode(hp).SymTable=CurrentProcInfo.procdef.ParaST) or
                (TLoadNode(hp).SymTable.SymTableType in [staticsymtable,GlobalSymTable])
               ) and
               { MacPas objects are mapped to classes, and the MacPas compilers
                 interpret with-statements with MacPas objects the same way
                 as records (the object referenced by the with-statement
                 must remain constant)
               }
               not(Is_Class(hp.resultdef) and
                   (m_mac in CurrentSettings.ModeSwitches)) then
              begin
                { simple load, we can reference direct }
                refnode:=p;
              end
            else
              begin
                { complex load, load in temp first }
                newblock:=InternalStatements(newstatement);
                { when we can't take the address of p, load it in a temp }
                { since we may need its address later on                 }
                if not valid_for_addr(p,false) then
                  begin
                    calltempnode:=CTempCreateNode.Create(p.resultdef,p.resultdef.Size,tt_persistent,true);
                    AddStatement(newstatement,calltempnode);
                    AddStatement(newstatement,CAssignmentNode.Create(
                        CTempRefNode.Create(calltempnode),
                        p));
                    p:=CTempRefNode.Create(calltempnode);
                    TypeCheckPass(p);
                  end;
                { several object types have implicit dereferencing }

                hasimplicitderef:=
                  Is_Implicit_Pointer_Object_Type(p.resultdef) or
                  (p.resultdef.typ=classrefdef);
                if hasimplicitderef then
                  hdef:=p.resultdef
                else
                  hdef:=CPointerDef.Create(p.resultdef);
                { load address of the value in a temp }
                tempnode:=CTempCreateNode.Create_WithNode(hdef,sizeof(PInt),tt_persistent,true,p);
                TypeCheckPass(TNode(tempnode));
                valuenode:=p;
                refnode:=CTempRefNode.Create(tempnode);
                fillchar(refnode.fileinfo,sizeof(TFilePosInfo),0);
                { add address call for valuenode and deref for refnode if this
                  is not done implicitly }
                if not hasimplicitderef then
                  begin
                    valuenode:=CAddrNode.Create_Internal_NoMark(valuenode);
                    include(TAddrNode(valuenode).AddrNodeFlags,anf_typedaddr);
                    refnode:=CDerefNode.Create(refnode);
                    fillchar(refnode.fileinfo,sizeof(TFilePosInfo),0);
                  end;
                AddStatement(newstatement,tempnode);
                AddStatement(newstatement,CAssignmentNode.Create(
                    CTempRefNode.Create(tempnode),
                    valuenode));
                TypeCheckPass(refnode);
              end;
            { Note: the symtable of the helper is pushed after the following
                    "case", the symtables of the helper's parents are passed in
                    the "case" branches }
            withsymtablelist:=TFPObjectList.Create(true);
            case p.resultdef.typ of
              objectdef :
                begin
                   { do we have a helper for this type? }
                   Search_Last_ObjectPascal_Helper(TAbstractRecordDef(p.resultdef),CurrentStructDef,helperdef);
                   { push symtables of all parents in reverse order }
                   pushobjchild(TObjectDef(p.resultdef),TObjectDef(p.resultdef).ChildOf);
                   { push symtables of all parents of the helper in reverse order }
                   if Assigned(helperdef) then
                     pushobjchild(helperdef,helperdef.ChildOf);
                   { push object symtable }
                   st:=TWithSymTable.Create(TObjectDef(p.resultdef),TObjectDef(p.resultdef).SymTable.SymList,refnode);
                   SymTableStack.push(st);
                   withsymtablelist.add(st);
                 end;
              classrefdef :
                begin
                   { do we have a helper for this type? }
                   Search_Last_ObjectPascal_Helper(TObjectDef(TClassRefDef(p.resultdef).PointedDef),CurrentStructDef,helperdef);
                   { push symtables of all parents in reverse order }
                   pushobjchild(TObjectDef(TClassRefDef(p.resultdef).PointedDef),TObjectDef(TClassRefDef(p.resultdef).PointedDef).ChildOf);
                   { push symtables of all parents of the helper in reverse order }
                   if Assigned(helperdef) then
                     pushobjchild(helperdef,helperdef.ChildOf);
                   { push object symtable }
                   st:=TWithSymTable.Create(TObjectDef(TClassRefDef(p.resultdef).PointedDef),TObjectDef(TClassRefDef(p.resultdef).PointedDef).SymTable.SymList,refnode);
                   SymTableStack.push(st);
                   withsymtablelist.add(st);
                end;
              recorddef :
                begin
                   { do we have a helper for this type? }
                   Search_Last_ObjectPascal_Helper(TAbstractRecordDef(p.resultdef),CurrentStructDef,helperdef);
                   { push symtables of all parents of the helper in reverse order }
                   if Assigned(helperdef) then
                     pushobjchild(helperdef,helperdef.ChildOf);
                   { push record symtable }
                   st:=TWithSymTable.Create(TRecordDef(p.resultdef),TRecordDef(p.resultdef).SymTable.SymList,refnode);
                   SymTableStack.push(st);
                   withsymtablelist.add(st);
                end;
              undefineddef :
                begin
                   if not(df_generic in CurrentProcInfo.procdef.DefOptions) then
                     InternalError(2012122802);
                   helperdef:=nil;
                   { push record symtable }
                   st:=TWithSymTable.Create(p.resultdef,nil,refnode);
                   SymTableStack.push(st);
                   withsymtablelist.add(st);
                end;
              else
                InternalError(200601271);
            end;

            { push helper symtable }
            if Assigned(helperdef) then
              begin
                st:=TWithSymTable.Create(helperdef,helperdef.SymTable.SymList,refnode.GetCopy);
                SymTableStack.push(st);
                withsymtablelist.add(st);
              end;

            if try_to_consume(_COMMA) then
              p:=_with_statement()
            else
              begin
                consume(_DO);
                if CurrentScanner.token<>_SEMICOLON then
                  p:=statement
                else
                  p:=CNothingNode.Create;
              end;

            { remove symtables in reverse order from the stack }
            for i:=withsymtablelist.count-1 downto 0 do
              SymTableStack.pop(TSymTable(withsymtablelist[i]));
            withsymtablelist.free;
            withsymtablelist := nil;

            { Finalize complex withnode with destroy of temp }
            if Assigned(newblock) then
             begin
               AddStatement(newstatement,p);
               if Assigned(tempnode) then
                 AddStatement(newstatement,CTempDeleteNode.Create(tempnode));
               if Assigned(calltempnode) then
                 AddStatement(newstatement,CTempDeleteNode.Create(calltempnode));
               p:=newblock;
             end;
            result:=p;
          end
         else
          begin
            Message1(parser_e_false_with_expr,p.resultdef.GetTypeName);
            p.free;
            p := nil;
            { try to recover from error }
            if try_to_consume(_COMMA) then
             begin
               hp:=_with_statement();
               if (hp=nil) then; { remove warning about unused }
             end
            else
             begin
               consume(_DO);
               { ignore all }
               if CurrentScanner.token<>_SEMICOLON then
                statement;
             end;
            result:=CErrorNode.Create;
          end;
      end;


    function with_statement : TNode;
      begin
         consume(_WITH);
         with_statement:=_with_statement();
      end;


    function raise_statement : TNode;
      var
         p,pobj,paddr,pframe : TNode;
      begin
         pobj:=nil;
         paddr:=nil;
         pframe:=nil;
         consume(_RAISE);
         if not(CurrentScanner.token in endtokens) then
           begin
              { object }
              pobj:=comp_expr([ef_accept_equal]);
              if try_to_consume(_AT) then
                begin
                   paddr:=comp_expr([ef_accept_equal]);
                   if try_to_consume(_COMMA) then
                     pframe:=comp_expr([ef_accept_equal]);
                end;
           end
         else
           begin
              if (Block_Type<>bt_except) then
                Message(parser_e_no_reraise_possible);
           end;
         if (po_noreturn in CurrentProcInfo.procdef.ProcOptions) and (ExceptBlockCounter=0) then
           Message(parser_e_raise_with_noreturn_not_allowed);
         p:=CRaiseNode.Create(pobj,paddr,pframe);
         raise_statement:=p;
      end;


    procedure check_except_type_valid(var def: TDef);
      begin
        if not (Is_Class(def) or (def.typ=errordef)) then
          begin
            Message1(type_e_class_type_expected,def.TypeName);
            def:=GenErrorDef;
          end;
      end;


    { parses "on [name:] type do" and pushes the exception symtable }
    procedure read_on_head(out ot : TDef; out ExceptSymTable : TSymTable);
      var
        sym : TLocalVarSym;
        ObjName,ObjRealName : TIDString;
        srsym : TSym;
        srsymtable : TSymTable;
        t : TToken;
        unit_found : boolean;
      begin
        ot:=GenErrorDef;
        ExceptSymTable:=nil;
        consume(_ON);
        if CurrentScanner.token=_ID then
          begin
            ObjName:=CurrentScanner.pattern;
            ObjRealName:=CurrentScanner.orgpattern;
            { can't use consume_sym here, because we need already
              to check for the colon }
            SearchSym(ObjName,srsym,srsymtable);
            consume(_ID);
            { is a explicit name for the exception given ? }
            if try_to_consume(_COLON) then
              begin
                single_type(ot,[]);
                check_except_type_valid(ot);
                sym:=CLocalVarSym.Create(ObjRealName,vs_value,ot,[]);
              end
            else
              begin
                { check if type is valid, must be done here because
                  with "e: Exception" the e is not necessary }

                { support unit.identifier }
                t:=NOTOKEN;
                unit_found:=try_consume_unitsym_no_specialize(srsym,srsymtable,t,[],ObjName);
                if srsym=nil then
                  begin
                    identifier_not_found(ObjRealName);
                    srsym:=GenErrorSym;
                  end;
                if unit_found then
                  consume(t);
                { check if type is valid, must be done here because
                  with "e: Exception" the e is not necessary }
                if (srsym.typ=TypeSym) then
                  begin
                    ot:=TTypeSym(srsym).TypeDef;
                    parse_nested_types(ot,false,false,nil);
                    check_except_type_valid(ot);
                  end
                else
                  begin
                    Message(type_e_type_id_expected);
                    ot:=GenErrorDef;
                  end;

                { create dummy symbol so we don't need a special
                  case in ncgflw, and so that we always know the
                  type }
                sym:=CLocalVarSym.Create('$exceptsym',vs_value,ot,[]);
              end;
            ExceptSymTable:=TSTTExceptSymTable.Create;
            ExceptSymTable.DefOwner:=CurrentProcInfo.procdef;
            ExceptSymTable.InsertSym(sym);
            SymTableStack.push(ExceptSymTable);
          end
        else
          consume(_ID);
        consume(_DO);
      end;


    { appends the on node hp to the list p_specific and pops the exception symtable }
    procedure add_on_node(hp : TNode; ot : TDef; ExceptSymTable : TSymTable;
        var p_specific, last : TNode);
      begin
         if ot.typ=errordef then
           begin
              hp.free;
              hp:=CErrorNode.Create;
           end;
         if p_specific=nil then
           begin
              last:=hp;
              p_specific:=last;
           end
         else
           begin
              TOnNode(last).left:=hp;
              last:=TOnNode(last).left;
           end;
         { set the informations }
         { only if the creation of the onnode was successful, it's possible}
         { that last and hp are errornodes (JM)                            }
         if last.nodetype = onn then
           begin
             TOnNode(last).ExceptType:=TObjectDef(ot);
             TOnNode(last).ExceptSymTable:=ExceptSymTable;
           end;
         { remove exception symtable }
         if Assigned(ExceptSymTable) then
           begin
             SymTableStack.pop(ExceptSymTable);
             if last.nodetype <> onn then
               begin
                 ExceptSymTable.free;
                 ExceptSymTable := nil;
               end;
           end;
      end;


    function try_statement : TNode;
      var
        p_try_block,p_finally_block,first,last,
        p_default,p_specific,hp : TNode;
        ot : TDef;
        old_block_type : TBlockType;
        ExceptSymTable : TSymTable;
        oldcurrent_exceptblock: integer;
        filepostry : TFilePosInfo;
      begin
        p_default:=nil;
        p_specific:=nil;
        last:=nil;

        { read statements to try }
        consume(_TRY);
        filepostry:=CurrentFilePos;
        first:=nil;
        inc(ExceptBlockCounter);
        oldcurrent_exceptblock := Current_ExceptBlock;
        Current_ExceptBlock := ExceptBlockCounter;
        old_block_type := Block_Type;
        Block_Type := bt_body;

        while (CurrentScanner.token<>_FINALLY) and (CurrentScanner.token<>_EXCEPT) do
          begin
            if first=nil then
              begin
                last:=CStatementNode.Create(statement,nil);
                first:=last;
              end
            else
              begin
                TStatementNode(last).right:=CStatementNode.Create(statement,nil);
                last:=TStatementNode(last).right;
              end;
            if not try_to_consume(_SEMICOLON) then
              break;
            consume_emptystats;
          end;
        p_try_block:=CBlockNode.Create(first);

        if try_to_consume(_FINALLY) then
          begin
            inc(ExceptBlockCounter);
            Current_ExceptBlock := ExceptBlockCounter;
            p_finally_block:=statements_til_end;
            result:=CTryFinallyNode.Create(p_try_block,p_finally_block);
            result.fileinfo:=filepostry;
          end
        else
          begin
            consume(_EXCEPT);
            Block_Type:=bt_except;
            inc(ExceptBlockCounter);
            Current_ExceptBlock := ExceptBlockCounter;
            if (CurrentScanner.idtoken=_ON) then
              { on: catch specific exceptions }
              begin
                last:=nil;
                repeat
                  read_on_head(ot,ExceptSymTable);
                  hp:=COnNode.Create(nil,statement);
                  add_on_node(hp,ot,ExceptSymTable,p_specific,last);
                  if not try_to_consume(_SEMICOLON) then
                    break;
                  consume_emptystats;
                until (CurrentScanner.token in [_END,_ELSE]);
                if try_to_consume(_ELSE) then
                  p_default:=statements_til_end
                else
                  consume(_END);
              end
            else
              p_default:=statements_til_end;

            result:=CTryExceptNode.Create(p_try_block,p_specific,p_default);
          end;
        Block_Type:=old_block_type;
        Current_ExceptBlock := oldcurrent_exceptblock;
      end;


    function try_stmt_expr : TNode;
      var
        resdef : TDef;
        typenode : TNode;

      function read_branch : TNode;
        begin
          result:=expr(true);
          resdef:=branch_type(resdef,result,typenode);
        end;

      { wraps the expressions of all on-branches into assignments to temp }
      procedure update_onnode_assignment(temp : TTempCreateNode; onnode : TNode);
        begin
          while Assigned(onnode) and (onnode.nodetype=onn) do
            begin
              TOnNode(onnode).right:=CAssignmentNode.Create(CTempRefNode.Create(temp),TOnNode(onnode).right);
              onnode:=TOnNode(onnode).left;
            end;
        end;

      var
        p_try_block,p_finally_block,
        p_default,p_specific,last,hp : TNode;
        ot : TDef;
        old_block_type : TBlockType;
        ExceptSymTable : TSymTable;
        oldcurrent_exceptblock: integer;
        trynode : TTryExceptNode;
        statements : TStatementNode;
        resultvar : TTempCreateNode;
      begin
        p_default:=nil;
        p_specific:=nil;
        last:=nil;
        resdef:=nil;
        typenode:=nil;

        { read expression to try }
        consume(_TRY);
        inc(ExceptBlockCounter);
        oldcurrent_exceptblock := Current_ExceptBlock;
        Current_ExceptBlock := ExceptBlockCounter;
        old_block_type := Block_Type;
        Block_Type := bt_body;

        p_try_block:=read_branch;

        if try_to_consume(_FINALLY) then
          begin
            Message(parser_e_stmt_expr_no_finally);
            { recover }
            inc(ExceptBlockCounter);
            Current_ExceptBlock := ExceptBlockCounter;
            p_finally_block:=statements_til_end;
            p_try_block.free;
            p_finally_block.free;
            Block_Type:=old_block_type;
            Current_ExceptBlock := oldcurrent_exceptblock;
            result:=CErrorNode.Create;
            exit;
          end;

        consume(_EXCEPT);
        Block_Type:=bt_except;
        inc(ExceptBlockCounter);
        Current_ExceptBlock := ExceptBlockCounter;
        if (CurrentScanner.idtoken=_ON) then
          { on: catch specific exceptions }
          begin
            repeat
              read_on_head(ot,ExceptSymTable);
              if ot.typ=errordef then
                { the on node is replaced by an error node, don't use it for the result type }
                hp:=COnNode.Create(nil,expr(true))
              else
                hp:=COnNode.Create(nil,read_branch);
              add_on_node(hp,ot,ExceptSymTable,p_specific,last);
              if not try_to_consume(_SEMICOLON) then
                break;
              consume_emptystats;
            until (CurrentScanner.token in [_END,_ELSE]);
            if try_to_consume(_ELSE) then
              begin
                { else: catch the other exceptions }
                p_default:=read_branch;
                try_to_consume(_SEMICOLON);
                consume(_END);
              end
            else
              begin
                consume(_END);
                Message(parser_e_stmt_expr_requires_else);
              end;
          end
        else
          begin
            { default: catch all exceptions }
            p_default:=read_branch;
            try_to_consume(_SEMICOLON);
            consume(_END);
          end;
        Block_Type:=old_block_type;
        Current_ExceptBlock := oldcurrent_exceptblock;

        trynode:=TTryExceptNode(CTryExceptNode.Create(p_try_block,p_specific,p_default));
        if not Assigned(resdef) then
          begin
            { errors have already been reported }
            trynode.free;
            result:=CErrorNode.Create;
            exit;
          end;
        result:=create_stmt_expr_block(resdef,statements,resultvar);
        if not is_anonymous_procdef(resdef) then
          begin
            trynode.left:=CAssignmentNode.Create(CTempRefNode.Create(resultvar),trynode.left);
            update_onnode_assignment(resultvar,trynode.right);
            if Assigned(trynode.t1) then
              trynode.t1:=CAssignmentNode.Create(CTempRefNode.Create(resultvar),trynode.t1);
          end;
        finish_stmt_expr_block(statements,resultvar,trynode);
      end;


    function statement_expr(var p1 : TNode) : boolean;
      begin
        if not (m_statement_expressions in CurrentSettings.ModeSwitches) then
          exit(false);
        result:=true;
        case CurrentScanner.token of
          _IF:
            p1:=if_stmt_expr;
          _CASE:
            p1:=case_stmt_expr;
          _TRY:
            p1:=try_stmt_expr;
          else
            result:=false;
        end;
      end;


    function _asm_statement : TNode;
      var
        asmstat : TAsmNode;
        reg     : TRegister;
        asmreader : TBaseAsmReader;
        EntryPos : TFilePosInfo;
        hl : TAsmList;
      begin
         Inside_Asm_Statement:=true;
         asmstat:=nil;
         hl:=nil;

         { apply all switch changes as the assembler readers doesn't do so }
         FlushPendingSwitchesState;

         if Assigned(asmmodeinfos[Ord(CurrentSettings.AsmMode)]) then
           begin
             asmreader:=asmmodeinfos[Ord(CurrentSettings.AsmMode)]^.CAsmReader.Create;
             EntryPos:=CurrentFilePos;
             hl:=asmreader.assemble as TAsmList;
             if (not hl.empty) then
               begin
                 { mark boundaries of assembler block, this is necessary for optimizer }
                 hl.insert(TAIMarker.Create(mark_asmblockstart));
                 hl.concat(TAIMarker.Create(mark_asmblockend));
               end;
             asmstat:=CAsmNode.Create(hl);
             asmstat.fileinfo:=EntryPos;
             asmreader.free;
             asmreader := nil;
           end
         else
           Message(parser_f_assembler_reader_not_supported);

         { Mark procedure that it has assembler blocks }
         include(CurrentProcInfo.flags,pi_has_assembler_block);

         { Read first the _ASM statement }
         consume(_ASM);

         { Force an empty register list for pure assembler routines,
           so that pass2 won't allocate volatile registers for them. }
         if (po_assembler in CurrentProcInfo.procdef.ProcOptions) then
           Include(asmstat.AsmNodeFlags,asmnf_has_registerlist);

         { END is read, got a list of changed registers? }
         if try_to_consume(_LECKKLAMMER) then
           begin
             if CurrentScanner.token<>_RECKKLAMMER then
              begin
                if po_assembler in CurrentProcInfo.procdef.ProcOptions then
                  Message(parser_w_register_list_ignored);
                repeat
                  { it's possible to specify the modified registers }
                  if CurrentScanner.token=_CSTRING then
                    reg:=std_regnum_search(lower(CurrentScanner.cstringpattern))
                  else if CurrentScanner.token=_CCHAR then
                    reg:=std_regnum_search(lower(CurrentScanner.pattern))
                  else
                    reg:=NR_NO;
                  { is_extra_reg is not exported on all architectures from cpubase }
                  if reg<>NR_NO then
                    begin
                      if not(po_assembler in CurrentProcInfo.procdef.ProcOptions) and Assigned(hl) then
                        begin
                          hl.Insert(TAIRegAlloc.alloc(reg,nil));
                          hl.Insert(TAIRegAlloc.markused(reg));
                          hl.Concat(TAIRegAlloc.dealloc(reg,nil));
                        end;
                    end
                  else
                    Message(asmr_e_invalid_register);
                  if CurrentScanner.token=_CCHAR then
                    consume(_CCHAR)
                  else
                    consume(_CSTRING);
                  if not try_to_consume(_COMMA) then
                    break;
                until false;
                Include(asmstat.AsmNodeFlags,asmnf_has_registerlist);
              end;
             consume(_RECKKLAMMER);
           end;

         Inside_Asm_Statement:=false;
         _asm_statement:=asmstat;
      end;


    { Old Turbo Pascal INLINE(data/data/...) }
    function tp_inline_statement : TNode;
      var
        actype : TAIConstType;

      function eval_intconst: asizeint;
        var
          cv : TConstExprInt;
          def: TDef;
        begin
          cv:=get_intconst;
          case actype of
            aitconst_8bit:
              def:=S8IntType;
            aitconst_16bit:
              def:=S16IntType;
            else
              def:=SizeSIntType;
          end;
          if cv.uvalue>Get_Max_Value(def).uvalue then
            def:=Get_Unsigned_IntType(def);
          AdaptRange(def,cv,rc_implicit);
          result:=cv.svalue;
        end;

      var
        cur_line : LongInt;
        w : asizeint;
        hl : TAsmList;
        asmstat : TAsmNode;
        sym : TSym;
        SymTable : TSymTable;
        s : TSymStr;
        ac : TAIConst;
        nesting : integer;
        tokenbuf : TDynamicArray;
      begin
        consume(_INLINE);
        consume(_LKLAMMER);
        hl:=TAsmList.Create;
        asmstat:=CAsmNode.Create(hl);
        asmstat.fileinfo:=CurrentFilePos;
        tokenbuf:=TDynamicArray.Create(16);
        cur_line:=0;
        { Parse data blocks }
        repeat
          { Record one data block for further replaying.
            This is needed  since / is used as a data block delimiter and cause troubles
            with constant evaluation which is allowed inside a data block. }
          tokenbuf.reset;
          CurrentScanner.startrecordtokens(tokenbuf);
          nesting:=0;
          while CurrentScanner.token<>_SLASH do
            begin
              case CurrentScanner.token of
                _LKLAMMER:
                  inc(nesting);
                _RKLAMMER:
                  begin
                    dec(nesting);
                    if nesting<0 then
                      break;
                  end;
                _SEMICOLON:
                  consume(_RKLAMMER); { error }
                else
                  ; {no action}
              end;
              consume(CurrentScanner.token);
            end;
          CurrentScanner.stoprecordtokens;
          { Set the current token to ; to make the constant evaluator happy }
          CurrentScanner.token:=_SEMICOLON;
          { Parse recorded tokens }
          CurrentScanner.startreplaytokens(tokenbuf,false);

          if cur_line<>CurrentFilePos.line then
            begin
              hl.concat(TAIForceLine.Create);
              cur_line:=CurrentFilePos.line;
            end;

          { Data size override }
          if try_to_consume(_GT) then
            actype:=aitconst_16bit
          else
            if try_to_consume(_LT) then
              actype:=aitconst_8bit
            else
              actype:=aitconst_128bit; { default size }
          sym:=nil;
          if CurrentScanner.token=_ID then
            begin
              if SearchSym(CurrentScanner.pattern,sym,SymTable) then
                begin
                  if sym.typ in [staticvarsym,localvarsym,paravarsym] then
                    begin
                      { Address of the static symbol or base offset for local symbols }
                      consume(_ID);
                      if (sym.typ=staticvarsym) and not (actype in [aitconst_128bit,aitconst_ptr]) then
                        Message1(type_e_integer_expr_expected,sym.name);
                      { Additional offset }
                      if CurrentScanner.token in [_PLUS,_MINUS] then
                        w:=eval_intconst
                      else
                        w:=0;
                      if sym.typ=staticvarsym then
                        s:=sym.MangledName
                      else
                        s:=sym.name;
                      ac:=TAIConst.Createname(s,w);
                      if actype=aitconst_128bit then
                        ac.consttype:=aitconst_ptr
                      else
                        ac.consttype:=actype;
                      { For a local symbol it is needed to generate a constant with the symbols's stack offset.
                        The stack offset is unavailable rigth now and will be resolved later in tcgasmnode.pass_generate_code.
                        Set sym.bind:=AB_NONE to indicate that this is a local symbol. }
                      if sym.typ<>staticvarsym then
                        ac.sym.bind:=AB_NONE;
                      hl.concat(ac);
                    end
                  else
                    if sym.typ=constsym then
                      sym:=nil
                    else
                      begin
                        consume(_ID);
                        Message(asmr_e_wrong_sym_type);
                      end;
                end;
            end;

          if sym=nil then
            begin
              { Integer constant expression }
              w:=eval_intconst;
              case actype of
                aitconst_8bit:
                  hl.concat(TAIConst.Create_8bit(w));
                aitconst_16bit:
                  hl.concat(TAIConst.Create_16bit(w));
                else
                  if w<$100 then
                    hl.concat(TAIConst.Create_8bit(w))
                  else
                    hl.concat(TAIConst.Create_sizeint(w));
              end;
            end;

          if not try_to_consume(_SEMICOLON) then
            consume(_RKLAMMER); {error}
        until nesting<0;
        tokenbuf.free;
        tokenbuf := nil;
        { mark boundaries of assembler block, this is necessary for optimizer }
        hl.insert(TAIMarker.Create(mark_asmblockstart));
        hl.concat(TAIMarker.Create(mark_asmblockend));
        { Mark procedure that it has assembler blocks }
        include(CurrentProcInfo.flags,pi_has_assembler_block);
        { Assume the function result is always used }
        if Assigned(CurrentProcInfo.procdef.FuncRetSym) then
          CurrentProcInfo.procdef.FuncRetSym.IncRefCount;
        result:=asmstat;
      end;


    function statement : TNode;
      var
         p,
         astatement,
         code       : TNode;
         filepos    : TFilePosInfo;
         srsym      : TSym;
         srsymtable : TSymTable;
         s          : TIDString;
      begin
         filepos:=CurrentTokenPos;
         code:=nil;
         case CurrentScanner.token of
           _GOTO :
             begin
                if not(cs_support_goto in CurrentSettings.ModuleSwitches) then
                  Message(sym_e_goto_and_label_not_supported);
                consume(_GOTO);
                if (CurrentScanner.token<>_INTCONST) and (CurrentScanner.token<>_ID) then
                  begin
                    Message(sym_e_label_not_found);
                    code:=CErrorNode.Create;
                  end
                else
                  begin
                     if CurrentScanner.token=_ID then
                       begin
                         srsym:=nil;
                         srsymtable:=nil;
                         consume_sym(srsym,srsymtable);
                       end
                     else
                      begin
                        if CurrentScanner.token<>_INTCONST then
                          InternalError(201008021);

                        { strip leading 0's in iso mode }
                        if (([m_iso,m_extpas]*CurrentSettings.ModeSwitches)<>[]) then
                          while (length(CurrentScanner.pattern)>1) and (CurrentScanner.pattern[1]='0') do
                            delete(CurrentScanner.pattern,1,1);

                        SearchSym(CurrentScanner.pattern,srsym,srsymtable);
                        if srsym=nil then
                          begin
                            identifier_not_found(CurrentScanner.pattern);
                            srsym:=GenErrorSym;
                            srsymtable:=nil;
                          end;
                        consume(CurrentScanner.token);
                      end;

                     if srsym.typ<>labelsym then
                       begin
                          Message(sym_e_id_is_no_label_id);
                          code:=CErrorNode.Create;
                       end
                     else
                       begin
                         { goto outside the current scope? }
                         if srsym.owner<>CurrentProcInfo.procdef.LocalST then
                           begin
                             { allowed? }
                             if not(m_non_local_goto in CurrentSettings.ModeSwitches) then
                               Message(parser_e_goto_outside_proc);
                             include(CurrentProcInfo.flags,pi_has_global_goto);
                             if Is_Nested_PD(CurrentProcInfo.procdef) then
                               CurrentProcInfo.Set_Needs_ParentFP(srsym.owner.SymTableLevel);
                           end;
                         code:=CGotoNode.Create(TLabelSym(srsym));
                         TGotoNode(code).LabelSym:=TLabelSym(srsym);
                         { set flag that this label is used }
                         TLabelSym(srsym).used:=true;
                       end;
                  end;
             end;
           _BEGIN :
             begin
               code:=statement_block(_BEGIN);
               Include(TBlockNode(code).BlockNodeFlags, bnf_strippable);
             end;
           _IF :
             code:=if_statement;
           _CASE :
             code:=case_statement;
           _REPEAT :
             code:=repeat_statement;
           _WHILE :
             code:=while_statement;
           _FOR :
             code:=for_statement;
           _WITH :
             code:=with_statement;
           _TRY :
             code:=try_statement;
           _RAISE :
             code:=raise_statement;
           { semicolons,else until and end are ignored }
           _SEMICOLON,
           _ELSE,
           _UNTIL,
           _END:
             code:=CNothingNode.Create;
           _FAIL :
             begin
                if (CurrentProcInfo.procdef.ProcTypeOption<>potype_constructor) then
                  Message(parser_e_fail_only_in_constructor);
                consume(_FAIL);
                code:=CNodeUtils.Call_Fail_Node;
             end;
           _ASM :
             begin
               if parse_generic then
                 Message(parser_e_no_assembler_in_generic);
               code:=_asm_statement;
             end;
           _PLUS:
             begin
               Message(parser_e_syntax_error);
               consume(_PLUS);
             end;
           _INLINE:
             begin
               code:=tp_inline_statement;
             end;
           _EOF :
             if CurrentScanner.had_multiline_string then
               Message2(scan_f_unterminated_multiline_string,
                        ToStr(CurrentScanner.multiline_start_line),
                        ToStr(CurrentScanner.multiline_start_column))
             else
               Message(scan_f_end_of_file);
         else
           begin
             { don't typecheck yet, because that will also simplify, which may
               result in not detecting certain kinds of syntax errors --
               see mantis #15594 }
             p:=expr(false);
             { save the current_scanner.pattern here for latter usage, the label could be "000",
               even if we read an expression, the current_scanner.pattern is still valid if it's really
               a label (FK)
               if you want to mess here, take care of
               tests/tbs/tw3546.pas
             }
             s:=CurrentScanner.pattern;

             { When a colon follows a intconst then transform it into a label }
             if (p.nodetype=ordconstn) and
                try_to_consume(_COLON) then
              begin
                { in iso mode, 0003: is equal to 3: }
                if (([m_iso,m_extpas]*CurrentSettings.ModeSwitches)<>[]) then
                  SearchSym(ToStr(TOrdConstNode(p).Value),srsym,srsymtable)
                else
                  SearchSym(s,srsym,srsymtable);
                p.free;
                p := nil;

                if Assigned(srsym) and
                   (srsym.typ=labelsym) then
                 begin
                   if TLabelSym(srsym).defined then
                     Message(sym_e_label_already_defined);
                   if SymTableStack.top.SymTableLevel<>srsymtable.SymTableLevel then
                     begin
                       include(CurrentProcInfo.flags,pi_has_interproclabel);
                       if (CurrentProcInfo.procdef.ProcTypeOption in [potype_unitinit,potype_unitfinalize]) then
                         Message(sym_e_interprocgoto_into_init_final_code_not_allowed);
                     end;

                   TLabelSym(srsym).defined:=true;
                   p:=CLabelNode.Create(nil,TLabelSym(srsym));
                   TLabelSym(srsym).code:=p;
                 end
                else
                 begin
                   Message1(sym_e_label_used_and_not_defined,s);
                   p:=CNothingNode.Create;
                 end;
              end;

             if p.nodetype=labeln then
               begin
                 if not(CurrentScanner.token in endtokens) then
                   begin
                     astatement:=statement();
                     TypeCheckPass(astatement);
                     p:=CBlockNode.Create(CStatementNode.Create(p,CStatementNode.Create(astatement,nil)));
                     Include(TBlockNode(p).BlockNodeFlags, bnf_strippable);
                   end;
               end
             else
               { change a load of a procvar to a call. this is also
                 supported in fpc mode }
               if p.nodetype in [vecn,derefn,typeconvn,subscriptn,loadn] then
                 Maybe_Call_ProcVar(p,false);

             { blockn support because a read/write is changed into a blocknode
               with a separate statement for each read/write operation (JM)
               the same is true for val() if the third parameter is not 32 bit

               goto nodes are created by the compiler for non local exit statements, so
               include them as well
             }
             if not(p.nodetype in [nothingn,errorn,calln,ifn,assignn,breakn,inlinen,
                                   continuen,labeln,blockn,exitn,goton]) or
                ((p.nodetype=inlinen) and
                 not TInlineNode(p).May_Ignore_Result) or
                ((p.nodetype=calln) and
                 (Assigned(TCallNode(p).ProcDefinition)) and
                 (TCallNode(p).ProcDefinition.ProcTypeOption=potype_operator)) then
               Message(parser_e_illegal_expression);

             if not Assigned(p.resultdef) then
               DoTypeCheckPass(p);

             { Specify that we don't use the value returned by the call.
               This is used for :
                - dispose of temp stack space
                - dispose on FPU stack
                - extended syntax checking }
             if (p.nodetype=calln) then
               begin
                 exclude(TCallNode(p).CallNodeFlags,cnf_return_value_used);

                 { in $x- state, the function result must not be ignored }
                 if not(cs_extsyntax in CurrentSettings.ModuleSwitches) and
                    not(Is_Void(p.resultdef)) and
                    { can be nil in case there was an error in the expression }
                    Assigned(TCallNode(p).ProcDefinition) and
                    { allow constructor calls to drop the result if they are
                      called as instance methods instead of class methods }
                    not(
                      (TCallNode(p).ProcDefinition.ProcTypeOption=potype_constructor) and
                      Is_Class_Or_Object(TProcDef(TCallNode(p).ProcDefinition).struct) and
                      Assigned(TCallNode(p).MethodPointer) and
                      (TNode(TCallNode(p).MethodPointer).resultdef.typ=objectdef)
                    ) then
                   Message(parser_e_illegal_expression);
               end;

             code:=p;
           end;
         end;
         if Assigned(code) then
           begin
             TypeCheckPass(code);
             code.fileinfo:=filepos;
           end;
         statement:=code;
      end;


    function statement_block(starttoken : TToken) : TNode;

      var
         first,last : TNode;
         filepos : TFilePosInfo;

      begin
         first:=nil;
         last:=nil;
         filepos:=CurrentTokenPos;
         consume(starttoken);

         while not((CurrentScanner.token=_END) or (CurrentScanner.token=_FINALIZATION)) do
           begin
              if first=nil then
                begin
                   last:=CStatementNode.Create(statement,nil);
                   first:=last;
                end
              else
                begin
                   TStatementNode(last).right:=CStatementNode.Create(statement,nil);
                   last:=TStatementNode(last).right;
                end;
              if ((CurrentScanner.token=_END) or (CurrentScanner.token=_FINALIZATION)) then
                break
              else
                begin
                   { if no semicolon, then error and go on }
                   if CurrentScanner.token<>_SEMICOLON then
                     begin
                        consume(_SEMICOLON);
                        consume_all_until(_SEMICOLON);
                     end;
                   consume(_SEMICOLON);
                end;
              consume_emptystats;
           end;

         { don't consume the finalization token, it is consumed when
           reading the finalization block, but allow it only after
           an initialization ! }
         if (starttoken<>_INITIALIZATION) or (CurrentScanner.token<>_FINALIZATION) then
           consume(_END);

         last:=CBlockNode.Create(first);
         last.fileinfo:=filepos;
         statement_block:=last;
      end;


    function assembler_block : TNode;
      var
        p : TNode;
        locals : LongInt;
        srsym : TSym;
      begin
         if parse_generic then
           message(parser_e_no_assembler_in_generic);

         { Rename the funcret so that recursive calls are possible }
         if not Is_Void(CurrentProcInfo.procdef.ReturnDef) then
           begin
             srsym:=TSym(CurrentProcInfo.procdef.LocalST.Find(CurrentProcInfo.procdef.ProcSym.name));
             if Assigned(srsym) then
               srsym.realname:='$hiddenresult';
           end;

         { delphi uses register calling for assembler methods }
         if (m_delphi in CurrentSettings.ModeSwitches) and
            (po_assembler in CurrentProcInfo.procdef.ProcOptions) and
            not(po_hascallingconvention in CurrentProcInfo.procdef.ProcOptions) then
           CurrentProcInfo.procdef.ProcCallOption:=pocall_register;

         { force the asm statement }
         if CurrentScanner.token<>_ASM then
           consume(_ASM);
         include(CurrentProcInfo.flags,pi_is_assembler);
         p:=_asm_statement;

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
             locals:=TAbstractLocalSymTable(CurrentProcInfo.procdef.ParaST).Count_Locals;
             if (CurrentProcInfo.procdef.LocalST.SymTableType=LocalSymTable) then
               inc(locals,TAbstractLocalSymTable(CurrentProcInfo.procdef.LocalST).Count_Locals);
             if (locals=0) and
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
        last_endtoken_filepos:=CurrentTokenPos;

        assembler_block:=p;
      end;

end.
