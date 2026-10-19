{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generates nodes for routines that need compiler support

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
unit pinline;

{$i fpcdefs.inc}

interface

    uses
      symtype,
      node,
      Globals;

    function New_Dispose_Statement(AIsNew:Boolean) : TNode;
    function New_Function : TNode;

    function Inline_SetLength : TNode;
    function Inline_SetString : TNode;
    function Inline_Initialize : TNode;
    function Inline_Finalize : TNode;
    function Inline_Copy : TNode;
    function Inline_Insert : TNode;
    function Inline_Delete : TNode;
    function Inline_Concat : TNode;


implementation

    uses
       { global }
       GlobType,tokens,Verbose,ConstExp,
       Systems,compinnr,
       { symtable }
       SymBase,symconst,symdef,SymSym,SymTable,defutil,
       { pass 1 }
       Pass_1,htypechk,
       ncal,nmem,ncnv,ninl,ncon,nld,nbas,ngenutil,nutils,
       { parser }
       Scanner,
       pbase,pexpr;


    function New_Dispose_Statement(AIsNew:Boolean) : TNode;
      var
        lNewStatement : TStatementNode;
        lTemp         : TTempCreateNode;
        lPara         : TCallParaNode;
        lNode,lNode2     : TNode;
        lAgain    : Boolean; { dummy for do_proc_call }
        lDestructorName : TIDString;
        lSym      : TSym;
        lClassDef   : TObjectDef;
        lCallFlags : TCallNodeFlag;
        lDestructorPosition,
        lStoredPosition : TFilePosInfo;
        lVariantDesc : PVariantRecDesc;
        lFound : Boolean;
        lVariantSelectSym : TFieldVarSym;

      procedure ReadVariantRecordConstants;
        var
          lIndex,lIndexJ : LongInt;
        begin
          if (([m_iso]*CurrentSettings.ModeSwitches)<>[]) and (Is_Record(TPointerDef(lNode.resultdef).PointedDef)) then
            begin
              lVariantDesc:=TRecordDef(TPointerDef(lNode.resultdef).PointedDef).VariantRecDesc;
              while (CurrentScanner.FToken=_COMMA) and Assigned(lVariantDesc) do
                begin
                  Consume(_COMMA);
                  lNode2:=Factor(false,[]);
                  DoTypeCheckPass(lNode2);
                  if lNode2.nodetype=ordconstn then
                    begin
                      lFound:=false;
                      { we do not have dynamic dfa, so avoid warning on variantselectsymbol below }
                      lVariantSelectSym:=nil;
                      for lIndex:=0 to high(lVariantDesc^.branches) do
                        begin
                          for lIndexJ:=0 to high(lVariantDesc^.branches[lIndex].values) do
                            if lVariantDesc^.branches[lIndex].values[lIndexJ]=TOrdConstNode(lNode2).Value then
                              begin
                                lFound:=true;
                                lVariantSelectSym:=TFieldVarSym(lVariantDesc^.VariantSelector);
                                lVariantDesc:=lVariantDesc^.branches[lIndex].NestedVariant;
                                break;
                              end;
                          if lFound then
                            break;
                        end;
                      if lFound then
                        begin
                          if AIsNew then
                            begin
                              { if no tag-field is given, do not create an assignment statement for it }
                              if Assigned(lVariantSelectSym) then
                                { setup variant selector }
                                AddStatement(lNewStatement,CAssignmentNode.Create(
                                    CSubscriptNode.Create(lVariantSelectSym,
                                      CDerefNode.Create(CTempRefNode.Create(lTemp))),
                                    lNode2));
                            end;
                        end
                      else
                        Message(parser_e_illegal_expression);
                    end
                  else
                    Message(parser_e_illegal_expression);
                end;
              end;
        end;

      begin
        Consume(_LKLAMMER);
        lNode:=CompExpr([efAcceptEqual]);
        { calc return type }
        if AIsNew then
          begin
            Set_VarState(lNode,vs_written,[]);
            Valid_For_Var(lNode,true);
          end
        else
          Set_VarState(lNode,vs_readwritten,[vsf_must_be_valid]);
        if (m_mac in CurrentSettings.ModeSwitches) and
           Is_Class(lNode.resultdef) then
          begin
            lClassDef:=TObjectDef(lNode.resultdef);

            { make sure we call ObjPas.TObject.Create/Free and not a random }
            { create/free method in a macpas descendent object (since those }
            { are not supposed to be called automatically when you call     }
            { new/dispose)                                                  }
            while Assigned(lClassDef.ChildOf) do
              lClassDef := lClassDef.ChildOf;
            if AIsNew then
              begin
                lSym:=Search_Struct_Member(lClassDef,'CREATE');
                lNode2 := CLoadVMTAddrNode.Create(CTypeNode.Create(lNode.resultdef));
              end
            else
              begin
                lSym:=Search_Struct_Member(lClassDef,'FREE');
                lNode2 := lNode;
             end;

            if not(Assigned(lSym)) then
              begin
                 lNode.free;
                 lNode := nil;
                 if AIsNew then
                   lNode2.free;
                   lNode2 := nil;
                 New_Dispose_Statement := CErrorNode.Create;
                 ConsumeAllUntil(_RKLAMMER);
                 Consume(_RKLAMMER);
                 exit;
              end;

            DoMemberRead(lClassDef,false,lSym,lNode2,lAgain,[],nil);

            { we need the real called method }
            DoTypeCheckPass(lNode2);

            if (lNode2.nodetype=calln) and
               Assigned(TCallNode(lNode2).ProcDefinition) then
              begin
                if AIsNew then
                  begin
                    if (TCallNode(lNode2).ProcDefinition.ProcTypeOption<>potype_constructor) then
                      Message(parser_e_expr_have_to_be_constructor_call);
                    lNode2.resultdef:=lNode.resultdef;
                    lNode2:=CAssignmentNode.Create(lNode,lNode2);
                    TypeCheckPass(lNode2);
                  end
                else
                  begin
                   { Free is not a destructor
                    if (tcallnode(p2).procdefinition.proctypeoption<>potype_destructor) then
                      Message(parser_e_expr_have_to_be_destructor_call);
                   }
                  end
              end
            else
              InternalError(2005061202);
            New_Dispose_Statement := lNode2;
          end
        { constructor,destructor specified }
        else if (([m_mac,m_iso]*CurrentSettings.ModeSwitches)=[]) and
                TryToConsume(_COMMA) then
          begin
            { extended syntax of new and dispose }
            { function styled new is handled in factor }
            { destructors have no parameters }
            lDestructorName:=CurrentScanner.FPattern;
            lDestructorPosition:=CurrentTokenPos;
            Consume(_ID);

            if Is_TypeParam(lNode.resultdef) then
              begin
                 lNode.free;
                 lNode:=Factor(false,[]);
                 lNode.free;
                 lNode := nil;
                 Consume(_RKLAMMER);
                 New_Dispose_Statement:=CNothingNode.Create;
                 exit;
              end;

            if (lNode.resultdef.typ<>pointerdef) then
              begin
                 Message1(type_e_pointer_type_expected,lNode.resultdef.TypeName);
                 lNode.free;
                 lNode:=Factor(false,[]);
                 lNode.free;
                 lNode := nil;
                 Consume(_RKLAMMER);
                 New_Dispose_Statement:=CErrorNode.Create;
                 exit;
              end;
            { first parameter must be an object or class }
            if TPointerDef(lNode.resultdef).PointedDef.typ<>objectdef then
              begin
                 Message(parser_e_pointer_to_class_expected);
                 lNode.free;
                 lNode := nil;
                 New_Dispose_Statement:=Factor(false,[]);
                 ConsumeAllUntil(_RKLAMMER);
                 Consume(_RKLAMMER);
                 exit;
              end;
            { check, if the first parameter is a pointer to a _class_ }
            lClassDef:=TObjectDef(TPointerDef(lNode.resultdef).PointedDef);
            if Is_Class(lClassDef) then
              begin
                 Message(parser_e_no_new_or_dispose_for_classes);
                 New_Dispose_Statement:=Factor(false,[]);
                 ConsumeAllUntil(_RKLAMMER);
                 Consume(_RKLAMMER);
                 exit;
              end;
            { search cons-/destructor, also in parent classes }
            lStoredPosition:=CurrentTokenPos;
            CurrentTokenPos:=lDestructorPosition;
            lSym:=Search_Struct_Member(lClassDef,lDestructorName);
            CurrentTokenPos:=lStoredPosition;

            { the second parameter of new/dispose must be a call }
            { to a cons-/destructor                              }
            if (not Assigned(lSym)) or (lSym.typ<>ProcSym) then
              begin
                 if AIsNew then
                  Message(parser_e_expr_have_to_be_constructor_call)
                 else
                  Message(parser_e_expr_have_to_be_destructor_call);
                 lNode.free;
                 lNode := nil;
                 New_Dispose_Statement:=CErrorNode.Create;
              end
            else
              begin
                { For new(var,constructor) we need to take a copy because
                  p is also used in the assignment below }
                if AIsNew then
                  begin
                    lNode2:=CDerefNode.Create(lNode.GetCopy);
                    include(TDerefNode(lNode2).DerefNodeFlags,drnf_no_checkpointer);
                  end
                else
                  lNode2:=CDerefNode.Create(lNode);
                DoTypeCheckPass(lNode2);
                if AIsNew then
                  lCallFlags:=cnf_new_call
                else
                  lCallFlags:=cnf_dispose_call;
                if AIsNew then
                  DoMemberRead(lClassDef,false,lSym,lNode2,lAgain,[lCallFlags],nil)
                else
                  begin
                    if not(m_fpc in CurrentSettings.ModeSwitches) then
                      DoMemberRead(lClassDef,false,lSym,lNode2,lAgain,[lCallFlags],nil)
                    else
                      begin
                        lNode2:=CCallNode.Create(nil,TProcSym(lSym),lSym.owner,lNode2,[lCallFlags],nil);
                        { support dispose(p,done()); }
                        if TryToConsume(_LKLAMMER) then
                          begin
                            if not TryToConsume(_RKLAMMER) then
                              begin
                                Message(parser_e_no_paras_for_destructor);
                                ConsumeAllUntil(_RKLAMMER);
                                Consume(_RKLAMMER);
                              end;
                          end;
                      end;
                  end;

                { we need the real called method }
                DoTypeCheckPass(lNode2);

                if (lNode2.nodetype=calln) and
                   Assigned(TCallNode(lNode2).ProcDefinition) then
                  begin
                    if AIsNew then
                     begin
                       if (TCallNode(lNode2).ProcDefinition.ProcTypeOption<>potype_constructor) then
                         Message(parser_e_expr_have_to_be_constructor_call);
                       lNode2.resultdef:=lNode.resultdef;
                       lNode2:=CAssignmentNode.Create(lNode,lNode2);
                     end
                    else
                     begin
                       if (TCallNode(lNode2).ProcDefinition.ProcTypeOption<>potype_destructor) then
                         Message(parser_e_expr_have_to_be_destructor_call);
                     end;
                  end
                else
                  begin
                    if AIsNew then
                      CGMessage(parser_e_expr_have_to_be_constructor_call)
                    else
                      CGMessage(parser_e_expr_have_to_be_destructor_call);
                  end;

                Result:=lNode2;
              end;
          end
        else
          begin
             if (lNode.resultdef.typ<>pointerdef) then
               Begin
                 if Is_TypeParam(lNode.resultdef) then
                   begin
                      lNode.free;
                      lNode := nil;
                      Consume(_RKLAMMER);
                      New_Dispose_Statement:=CNothingNode.Create;
                      exit;
                   end
                 else
                   begin
                     Message1(type_e_pointer_type_expected,lNode.resultdef.TypeName);
                     New_Dispose_Statement:=CErrorNode.Create;
                   end;
               end
             else
               begin
                  if (TPointerDef(lNode.resultdef).PointedDef.typ=objectdef) and
                     (oo_has_vmt in TObjectDef(TPointerDef(lNode.resultdef).PointedDef).ObjectOptions) then
                    Message(parser_w_use_extended_syntax_for_objects);
                  if (TPointerDef(lNode.resultdef).PointedDef.typ=orddef) and
                     (TOrdDef(TPointerDef(lNode.resultdef).PointedDef).OrdType=uvoid) then
                    begin
                      if m_delphi in CurrentSettings.ModeSwitches then
                       Message(parser_w_no_new_dispose_on_void_pointers)
                      else
                       Message(parser_e_no_new_dispose_on_void_pointers);
                    end;

                  { create statements with call to getmem+initialize or
                    finalize+freemem }
                  New_Dispose_Statement:=InternalStatements(lNewStatement);

                  if AIsNew then
                   begin
                     { create temp for result }
                     lTemp := CTempCreateNode.Create(lNode.resultdef,lNode.resultdef.Size,tt_persistent,true);
                     AddStatement(lNewStatement,lTemp);

                     { create call to fpc_getmem }
                     lPara := CCallParaNode.Create(COrdConstNode.Create
                         (TPointerDef(lNode.resultdef).PointedDef.Size,PtrUIntType,true),nil);
                     AddStatement(lNewStatement,CAssignmentNode.Create(
                         CTempRefNode.Create(lTemp),
                         CCallNode.CreateIntern('fpc_getmem',lPara)));

                     { create call to fpc_initialize }
                     if Is_Managed_Type(TPointerDef(lNode.resultdef).PointedDef) or
                       ((m_isolike_io in CurrentSettings.ModeSwitches) and (TPointerDef(lNode.resultdef).PointedDef.typ=filedef)) then
                       AddStatement(lNewStatement,CNodeUtils.Initialize_Data_Node(CDerefNode.Create(CTempRefNode.Create(lTemp)),false));

                     { copy the temp to the destination }
                     AddStatement(lNewStatement,CAssignmentNode.Create(
                         lNode,
                         CTempRefNode.Create(lTemp)));

                     ReadVariantRecordConstants;

                     { release temp }
                     AddStatement(lNewStatement,CTempDeleteNode.Create(lTemp));
                   end
                  else
                   begin
                     lTemp:=nil;
                     { create call to fpc_finalize }
                     if Is_Managed_Type(TPointerDef(lNode.resultdef).PointedDef) then
                       if Might_Have_SideEffects(lNode) then
                         begin
                           { ensure that p gets evaluated only once, in case it is e.g. a call }
                           lTemp:=CTempCreateNode.Create_Value(lNode.resultdef,lNode.resultdef.Size,tt_persistent,true,lNode);
                           AddStatement(lNewStatement,lTemp);
                           AddStatement(lNewStatement,CNodeUtils.Finalize_Data_Node(CDerefNode.Create(CTempRefNode.Create(lTemp))));
                         end
                       else
                         AddStatement(lNewStatement,CNodeUtils.Finalize_Data_Node(CDerefNode.Create(lNode.GetCopy)));

                     ReadVariantRecordConstants;

                     { create call to fpc_freemem }
                     if not Assigned(lTemp) then
                       lPara := CCallParaNode.Create(lNode,nil)
                     else
                       lPara := CCallParaNode.Create(CTempRefNode.Create(lTemp),nil);
                     AddStatement(lNewStatement,CCallNode.CreateIntern('fpc_freemem',lPara));
                     if Assigned(lTemp) then
                       AddStatement(lNewStatement,CTempDeleteNode.Create(lTemp));
                   end;
               end;
          end;
        Consume(_RKLAMMER);
      end;


    function New_Function : TNode;
      var
        lNode1,lNode2  : TNode;
        lClassDef : TObjectDef;
        lSym    : TSym;
        lSymTable : TSymTable;
        lAgain  : Boolean; { dummy for do_proc_call }
      begin
        Consume(_LKLAMMER);
        lNode1:=Factor(false,[]);
        if lNode1.nodetype<>typen then
         begin
           Message(type_e_type_id_expected);
           ConsumeAllUntil(_RKLAMMER);
           Consume(_RKLAMMER);
           lNode1.free;
           lNode1 := nil;
           New_Function:=CErrorNode.Create;
           exit;
         end;

        if (lNode1.resultdef.typ<>pointerdef) then
         begin
           Message1(type_e_pointer_type_expected,lNode1.resultdef.TypeName);
           ConsumeAllUntil(_RKLAMMER);
           Consume(_RKLAMMER);
           lNode1.free;
           lNode1 := nil;
           New_Function:=CErrorNode.Create;
           exit;
         end;

        if TryToConsume(_RKLAMMER) then
          begin
            if (TPointerDef(lNode1.resultdef).PointedDef.typ=objectdef) and
               (oo_has_vmt in TObjectDef(TPointerDef(lNode1.resultdef).PointedDef).ObjectOptions)  then
              Message(parser_w_use_extended_syntax_for_objects);

            if lNode1.nodetype=typen then
              TTypeNode(lNode1).allowed:=true;

            lNode1:=CInlineNode.Create(in_new_x,false,lNode1);
          end
        else
          begin
            Consume(_COMMA);
            if TPointerDef(lNode1.resultdef).PointedDef.typ<>objectdef then
             begin
               Message(parser_e_pointer_to_class_expected);
               ConsumeAllUntil(_RKLAMMER);
               Consume(_RKLAMMER);
               lNode1.free;
               lNode1 := nil;
               New_Function:=CErrorNode.Create;
               exit;
             end;
            lClassDef:=TObjectDef(TPointerDef(lNode1.resultdef).PointedDef);
            { use the objectdef for loading the VMT }
            lNode2:=lNode1;
            lNode1:=CTypeNode.Create(TPointerDef(lNode1.resultdef).PointedDef);
            DoTypeCheckPass(lNode1);
            { search the constructor also in the symbol tables of
              the parents }
            AfterAssignment:=false;
            SearchSym_In_Class(lClassDef,lClassDef,CurrentScanner.FPattern,lSym,lSymTable,[ssf_search_helper]);
            Consume(_ID);
            DoMemberRead(lClassDef,false,lSym,lNode1,lAgain,[cnf_new_call],nil);
            { we need to know which procedure is called }
            DoTypeCheckPass(lNode1);
            if not(
                   (lNode1.nodetype=calln) and
                   Assigned(TCallNode(lNode1).ProcDefinition) and
                   (TCallNode(lNode1).ProcDefinition.ProcTypeOption=potype_constructor)
                  ) then
              Message(parser_e_expr_have_to_be_constructor_call);
            { constructors return boolean, update resultdef to return
              the pointer to the object }
            lNode1.resultdef:=lNode2.resultdef;
            lNode2.free;
            lNode2 := nil;
            Consume(_RKLAMMER);
          end;
        New_Function:=lNode1;
      end;


    function Inline_SetLength : TNode;
      var
        lParas: TNode;
      begin
        Consume(_LKLAMMER);
        lParas:=ParseParas(false,false,_RKLAMMER);
        Consume(_RKLAMMER);
        if not Assigned(lParas) then
         begin
           Result:=CErrorNode.Create;
           CGMessage1(parser_e_wrong_parameter_size,'SetLength');
           exit;
         end;
        Result:=CInlineNode.Create(in_setlength_x,false,lParas);
      end;


    function Inline_SetString : TNode;
      var
        lParas, lStringPara, lPCharPara: TNode;
        lProcName: String;
        lCallPara: TStringEncoding;
      begin
        Consume(_LKLAMMER);
        lParas:=ParseParas(false,false,_RKLAMMER);
        Consume(_RKLAMMER);
        lProcName:='';
        if Assigned(lParas) and
           Assigned(TCallParaNode(lParas).right) and
           Assigned(TCallParaNode(TCallParaNode(lParas).right).right) then
          begin
            DoTypeCheckPass(TCallParaNode(TCallParaNode(lParas).right).left);
            DoTypeCheckPass(TCallParaNode(TCallParaNode(TCallParaNode(lParas).right).right).left);
            lPCharPara:=TCallParaNode(TCallParaNode(lParas).right).left;
            lStringPara:=TCallParaNode(TCallParaNode(TCallParaNode(lParas).right).right).left;
            if lStringPara.resultdef.typ=stringdef then
              begin
                { if there are three parameters and the first parameter
                  ( = paras.right.right) is an ansistring, add a codepage
                  parameter }
                if Is_AnsiString(lStringPara.resultdef) then
                  begin
                    lCallPara:=TStringDef(lStringPara.resultdef).encoding;
                    if (lCallPara=Globals.CP_NONE) then
                      lCallPara:=0;
                    lParas:=CCallParaNode.Create(GenIntConstNode(lCallPara),lParas);
                  end;
                lProcName:='fpc_setstring_'+TStringDef(lStringPara.resultdef).StringTypName;
                { decide which version to call based on the second parameter }
                if not Is_ShortString(lStringPara.resultdef) then
                  if Is_PWideChar(lPCharPara.resultdef) or
                     Is_WideChar(lPCharPara.resultdef) or
                     ((lPCharPara.resultdef.typ=arraydef) and
                      Is_WideChar(TArrayDef(lPCharPara.resultdef).ElementDef)) then
                    lProcName:=lProcName+'_pwidechar'
                  else
                    lProcName:=lProcName+'_pansichar';
              end;
          end;
        { default version (for error message) in case of missing or wrong
          parameters }
        if lProcName='' then
          if m_default_unicodestring in CurrentSettings.ModeSwitches then
            lProcName:='fpc_setstring_unicodestr_pwidechar'
          else if m_default_ansistring in CurrentSettings.ModeSwitches then
            lProcName:='fpc_setstring_ansistr_pansichar'
          else
            lProcName:='fpc_setstring_shortstr';
        Result:=CCallNode.CreateIntern(lProcName,lParas)
      end;


    function InlineInitFinal(AIsInit: Boolean): TNode;
      var
        lNewBlock,
        lParas   : TNode;
        lNewPara,
        lDestParaNode,
        lParaNode     : TCallParaNode;
      begin
        { for easy exiting if something goes wrong }
        Result := CErrorNode.Create;

        Consume(_LKLAMMER);
        lParas:=ParseParas(false,false,_RKLAMMER);
        Consume(_RKLAMMER);
        lParaNode:=TCallParaNode(lParas);

        if not Assigned(lParas) or
           (Assigned(lParaNode.right) and
            Assigned(TCallParaNode(lParaNode.right).right)) then
         begin
           if AIsInit then
             CGMessage1(parser_e_wrong_parameter_size,'Initialize')
           else
             CGMessage1(parser_e_wrong_parameter_size,'Finalize');
           exit;
         end;

        { 2 arguments? }
        if Assigned(lParaNode.right) then
         begin
           lDestParaNode:=TCallParaNode(lParaNode.right);
           { create call to fpc_initialize/finalize_array }
           lNewPara:=CCallParaNode.Create(CTypeConvNode.Create
                     (lParaNode.left,S32IntType),
                  CCallParaNode.Create(CAddrNode.Create_Internal
                     (CRTTINode.Create(TStoredDef(lDestParaNode.left.resultdef),initrtti,rdt_normal)),
                  CCallParaNode.Create(CAddrNode.Create_Internal
                     (lDestParaNode.left),nil)));
           if AIsInit then
             lNewBlock:=CCallNode.CreateIntern('fpc_initialize_array',lNewPara)
           else
             lNewBlock:=CCallNode.CreateIntern('fpc_finalize_array',lNewPara);
           lDestParaNode.left:=nil;
         end
        else
         begin
           if AIsInit then
             lNewBlock:=CNodeUtils.Initialize_Data_Node(lParaNode.left,true)
           else
             lNewBlock:=CNodeUtils.Finalize_Data_Node(lParaNode.left);
         end;
        lParaNode.left:=nil;
        lParas.free;
        lParas := nil;
        Result.free;
        Result:=lNewBlock;
      end;


    function Inline_Initialize : TNode;
      begin
        Result:=InlineInitFinal(true);
      end;


    function Inline_Finalize : TNode;
      begin
        Result:=InlineInitFinal(false);
      end;


    function InlineCopyInsertDelete(ANumber:TInlineNumber;const AName:String;ACheckEmpty:Boolean) : TNode;
      var
        lParas   : TNode;
        { for easy exiting if something goes wrong }
      begin
        Result := CErrorNode.Create;

        Consume(_LKLAMMER);
        lParas:=ParseParas(false,false,_RKLAMMER);
        Consume(_RKLAMMER);
        if not Assigned(lParas) and ACheckEmpty then
          begin
            CGMessage1(parser_e_wrong_parameter_size,AName);
            exit;
          end;
        Result.free;
        Result:=CInlineNode.Create(ANumber,false,lParas);
      end;


    function Inline_Copy: TNode;
      begin
        Result:=InlineCopyInsertDelete(in_copy_x,'Copy',false);
      end;


    function Inline_Insert: TNode;
      begin
        Result:=InlineCopyInsertDelete(in_insert_x_y_z,'Insert',false);
      end;


    function Inline_Delete: TNode;
      begin
        Result:=InlineCopyInsertDelete(in_delete_x_y_z,'Delete',false);
      end;


    function Inline_Concat: TNode;
      begin
        Result:=InlineCopyInsertDelete(in_concat_x,'Concat',false);
      end;


end.
