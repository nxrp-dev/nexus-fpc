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

    function new_dispose_statement(is_new:boolean) : TNode;
    function new_function : TNode;

    function inline_setlength : TNode;
    function inline_setstring : TNode;
    function inline_initialize : TNode;
    function inline_finalize : TNode;
    function inline_copy : TNode;
    function inline_insert : TNode;
    function inline_delete : TNode;
    function inline_concat : TNode;


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


    function new_dispose_statement(is_new:boolean) : TNode;
      var
        newstatement : TStatementNode;
        temp         : TTempCreateNode;
        para         : TCallParaNode;
        p,p2     : TNode;
        again    : boolean; { dummy for do_proc_call }
        destructorname : TIDString;
        sym      : TSym;
        classh   : TObjectDef;
        callflag : TCallNodeFlag;
        destructorpos,
        storepos : TFilePosInfo;
        variantdesc : PVariantRecDesc;
        found : boolean;
        variantselectsymbol : TFieldVarSym;

      procedure ReadVariantRecordConstants;
        var
          i,j : LongInt;
        begin
          if (([m_iso,m_extpas]*CurrentSettings.ModeSwitches)<>[]) and (Is_Record(TPointerDef(p.resultdef).PointedDef)) then
            begin
              variantdesc:=TRecordDef(TPointerDef(p.resultdef).PointedDef).VariantRecDesc;
              while (CurrentScanner.token=_COMMA) and Assigned(variantdesc) do
                begin
                  consume(_COMMA);
                  p2:=factor(false,[]);
                  DoTypeCheckPass(p2);
                  if p2.nodetype=ordconstn then
                    begin
                      found:=false;
                      { we do not have dynamic dfa, so avoid warning on variantselectsymbol below }
                      variantselectsymbol:=nil;
                      for i:=0 to high(variantdesc^.branches) do
                        begin
                          for j:=0 to high(variantdesc^.branches[i].values) do
                            if variantdesc^.branches[i].values[j]=TOrdConstNode(p2).Value then
                              begin
                                found:=true;
                                variantselectsymbol:=TFieldVarSym(variantdesc^.VariantSelector);
                                variantdesc:=variantdesc^.branches[i].NestedVariant;
                                break;
                              end;
                          if found then
                            break;
                        end;
                      if found then
                        begin
                          if is_new then
                            begin
                              { if no tag-field is given, do not create an assignment statement for it }
                              if Assigned(variantselectsymbol) then
                                { setup variant selector }
                                AddStatement(newstatement,CAssignmentNode.Create(
                                    CSubscriptNode.Create(variantselectsymbol,
                                      CDerefNode.Create(CTempRefNode.Create(temp))),
                                    p2));
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
        consume(_LKLAMMER);
        p:=comp_expr([ef_accept_equal]);
        { calc return type }
        if is_new then
          begin
            set_varstate(p,vs_written,[]);
            valid_for_var(p,true);
          end
        else
          set_varstate(p,vs_readwritten,[vsf_must_be_valid]);
        if (m_mac in CurrentSettings.ModeSwitches) and
           Is_Class(p.resultdef) then
          begin
            classh:=TObjectDef(p.resultdef);

            { make sure we call ObjPas.TObject.Create/Free and not a random }
            { create/free method in a macpas descendent object (since those }
            { are not supposed to be called automatically when you call     }
            { new/dispose)                                                  }
            while Assigned(classh.ChildOf) do
              classh := classh.ChildOf;
            if is_new then
              begin
                sym:=Search_Struct_Member(classh,'CREATE');
                p2 := CLoadVMTAddrNode.Create(CTypeNode.Create(p.resultdef));
              end
            else
              begin
                sym:=Search_Struct_Member(classh,'FREE');
                p2 := p;
             end;

            if not(Assigned(sym)) then
              begin
                 p.free;
                 p := nil;
                 if is_new then
                   p2.free;
                   p2 := nil;
                 new_dispose_statement := CErrorNode.Create;
                 consume_all_until(_RKLAMMER);
                 consume(_RKLAMMER);
                 exit;
              end;

            do_member_read(classh,false,sym,p2,again,[],nil);

            { we need the real called method }
            DoTypeCheckPass(p2);

            if (p2.nodetype=calln) and
               Assigned(TCallNode(p2).ProcDefinition) then
              begin
                if is_new then
                  begin
                    if (TCallNode(p2).ProcDefinition.ProcTypeOption<>potype_constructor) then
                      Message(parser_e_expr_have_to_be_constructor_call);
                    p2.resultdef:=p.resultdef;
                    p2:=CAssignmentNode.Create(p,p2);
                    TypeCheckPass(p2);
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
            new_dispose_statement := p2;
          end
        { constructor,destructor specified }
        else if (([m_mac,m_iso,m_extpas]*CurrentSettings.ModeSwitches)=[]) and
                try_to_consume(_COMMA) then
          begin
            { extended syntax of new and dispose }
            { function styled new is handled in factor }
            { destructors have no parameters }
            destructorname:=CurrentScanner.pattern;
            destructorpos:=CurrentTokenPos;
            consume(_ID);

            if Is_TypeParam(p.resultdef) then
              begin
                 p.free;
                 p:=factor(false,[]);
                 p.free;
                 p := nil;
                 consume(_RKLAMMER);
                 new_dispose_statement:=CNothingNode.Create;
                 exit;
              end;

            if (p.resultdef.typ<>pointerdef) then
              begin
                 Message1(type_e_pointer_type_expected,p.resultdef.TypeName);
                 p.free;
                 p:=factor(false,[]);
                 p.free;
                 p := nil;
                 consume(_RKLAMMER);
                 new_dispose_statement:=CErrorNode.Create;
                 exit;
              end;
            { first parameter must be an object or class }
            if TPointerDef(p.resultdef).PointedDef.typ<>objectdef then
              begin
                 Message(parser_e_pointer_to_class_expected);
                 p.free;
                 p := nil;
                 new_dispose_statement:=factor(false,[]);
                 consume_all_until(_RKLAMMER);
                 consume(_RKLAMMER);
                 exit;
              end;
            { check, if the first parameter is a pointer to a _class_ }
            classh:=TObjectDef(TPointerDef(p.resultdef).PointedDef);
            if Is_Class(classh) then
              begin
                 Message(parser_e_no_new_or_dispose_for_classes);
                 new_dispose_statement:=factor(false,[]);
                 consume_all_until(_RKLAMMER);
                 consume(_RKLAMMER);
                 exit;
              end;
            { search cons-/destructor, also in parent classes }
            storepos:=CurrentTokenPos;
            CurrentTokenPos:=destructorpos;
            sym:=Search_Struct_Member(classh,destructorname);
            CurrentTokenPos:=storepos;

            { the second parameter of new/dispose must be a call }
            { to a cons-/destructor                              }
            if (not Assigned(sym)) or (sym.typ<>ProcSym) then
              begin
                 if is_new then
                  Message(parser_e_expr_have_to_be_constructor_call)
                 else
                  Message(parser_e_expr_have_to_be_destructor_call);
                 p.free;
                 p := nil;
                 new_dispose_statement:=CErrorNode.Create;
              end
            else
              begin
                { For new(var,constructor) we need to take a copy because
                  p is also used in the assignment below }
                if is_new then
                  begin
                    p2:=CDerefNode.Create(p.GetCopy);
                    include(TDerefNode(p2).DerefNodeFlags,drnf_no_checkpointer);
                  end
                else
                  p2:=CDerefNode.Create(p);
                DoTypeCheckPass(p2);
                if is_new then
                  callflag:=cnf_new_call
                else
                  callflag:=cnf_dispose_call;
                if is_new then
                  do_member_read(classh,false,sym,p2,again,[callflag],nil)
                else
                  begin
                    if not(m_fpc in CurrentSettings.ModeSwitches) then
                      do_member_read(classh,false,sym,p2,again,[callflag],nil)
                    else
                      begin
                        p2:=CCallNode.Create(nil,TProcSym(sym),sym.owner,p2,[callflag],nil);
                        { support dispose(p,done()); }
                        if try_to_consume(_LKLAMMER) then
                          begin
                            if not try_to_consume(_RKLAMMER) then
                              begin
                                Message(parser_e_no_paras_for_destructor);
                                consume_all_until(_RKLAMMER);
                                consume(_RKLAMMER);
                              end;
                          end;
                      end;
                  end;

                { we need the real called method }
                DoTypeCheckPass(p2);

                if (p2.nodetype=calln) and
                   Assigned(TCallNode(p2).ProcDefinition) then
                  begin
                    if is_new then
                     begin
                       if (TCallNode(p2).ProcDefinition.ProcTypeOption<>potype_constructor) then
                         Message(parser_e_expr_have_to_be_constructor_call);
                       p2.resultdef:=p.resultdef;
                       p2:=CAssignmentNode.Create(p,p2);
                     end
                    else
                     begin
                       if (TCallNode(p2).ProcDefinition.ProcTypeOption<>potype_destructor) then
                         Message(parser_e_expr_have_to_be_destructor_call);
                     end;
                  end
                else
                  begin
                    if is_new then
                      CGMessage(parser_e_expr_have_to_be_constructor_call)
                    else
                      CGMessage(parser_e_expr_have_to_be_destructor_call);
                  end;

                result:=p2;
              end;
          end
        else
          begin
             if (p.resultdef.typ<>pointerdef) then
               Begin
                 if Is_TypeParam(p.resultdef) then
                   begin
                      p.free;
                      p := nil;
                      consume(_RKLAMMER);
                      new_dispose_statement:=CNothingNode.Create;
                      exit;
                   end
                 else
                   begin
                     Message1(type_e_pointer_type_expected,p.resultdef.TypeName);
                     new_dispose_statement:=CErrorNode.Create;
                   end;
               end
             else
               begin
                  if (TPointerDef(p.resultdef).PointedDef.typ=objectdef) and
                     (oo_has_vmt in TObjectDef(TPointerDef(p.resultdef).PointedDef).ObjectOptions) then
                    Message(parser_w_use_extended_syntax_for_objects);
                  if (TPointerDef(p.resultdef).PointedDef.typ=orddef) and
                     (TOrdDef(TPointerDef(p.resultdef).PointedDef).OrdType=uvoid) then
                    begin
                      if m_delphi in CurrentSettings.ModeSwitches then
                       Message(parser_w_no_new_dispose_on_void_pointers)
                      else
                       Message(parser_e_no_new_dispose_on_void_pointers);
                    end;

                  { create statements with call to getmem+initialize or
                    finalize+freemem }
                  new_dispose_statement:=InternalStatements(newstatement);

                  if is_new then
                   begin
                     { create temp for result }
                     temp := CTempCreateNode.Create(p.resultdef,p.resultdef.Size,tt_persistent,true);
                     AddStatement(newstatement,temp);

                     { create call to fpc_getmem }
                     para := CCallParaNode.Create(COrdConstNode.Create
                         (TPointerDef(p.resultdef).PointedDef.Size,PtrUIntType,true),nil);
                     AddStatement(newstatement,CAssignmentNode.Create(
                         CTempRefNode.Create(temp),
                         CCallNode.CreateIntern('fpc_getmem',para)));

                     { create call to fpc_initialize }
                     if Is_Managed_Type(TPointerDef(p.resultdef).PointedDef) or
                       ((m_isolike_io in CurrentSettings.ModeSwitches) and (TPointerDef(p.resultdef).PointedDef.typ=filedef)) then
                       AddStatement(newstatement,CNodeUtils.Initialize_Data_Node(CDerefNode.Create(CTempRefNode.Create(temp)),false));

                     { copy the temp to the destination }
                     AddStatement(newstatement,CAssignmentNode.Create(
                         p,
                         CTempRefNode.Create(temp)));

                     ReadVariantRecordConstants;

                     { release temp }
                     AddStatement(newstatement,CTempDeleteNode.Create(temp));
                   end
                  else
                   begin
                     temp:=nil;
                     { create call to fpc_finalize }
                     if Is_Managed_Type(TPointerDef(p.resultdef).PointedDef) then
                       if Might_Have_SideEffects(p) then
                         begin
                           { ensure that p gets evaluated only once, in case it is e.g. a call }
                           temp:=CTempCreateNode.Create_Value(p.resultdef,p.resultdef.Size,tt_persistent,true,p);
                           AddStatement(newstatement,temp);
                           AddStatement(newstatement,CNodeUtils.Finalize_Data_Node(CDerefNode.Create(CTempRefNode.Create(temp))));
                         end
                       else
                         AddStatement(newstatement,CNodeUtils.Finalize_Data_Node(CDerefNode.Create(p.GetCopy)));

                     ReadVariantRecordConstants;

                     { create call to fpc_freemem }
                     if not Assigned(temp) then
                       para := CCallParaNode.Create(p,nil)
                     else
                       para := CCallParaNode.Create(CTempRefNode.Create(temp),nil);
                     AddStatement(newstatement,CCallNode.CreateIntern('fpc_freemem',para));
                     if Assigned(temp) then
                       AddStatement(newstatement,CTempDeleteNode.Create(temp));
                   end;
               end;
          end;
        consume(_RKLAMMER);
      end;


    function new_function : TNode;
      var
        p1,p2  : TNode;
        classh : TObjectDef;
        srsym    : TSym;
        srsymtable : TSymTable;
        again  : boolean; { dummy for do_proc_call }
      begin
        consume(_LKLAMMER);
        p1:=factor(false,[]);
        if p1.nodetype<>typen then
         begin
           Message(type_e_type_id_expected);
           consume_all_until(_RKLAMMER);
           consume(_RKLAMMER);
           p1.free;
           p1 := nil;
           new_function:=CErrorNode.Create;
           exit;
         end;

        if (p1.resultdef.typ<>pointerdef) then
         begin
           Message1(type_e_pointer_type_expected,p1.resultdef.TypeName);
           consume_all_until(_RKLAMMER);
           consume(_RKLAMMER);
           p1.free;
           p1 := nil;
           new_function:=CErrorNode.Create;
           exit;
         end;

        if try_to_consume(_RKLAMMER) then
          begin
            if (TPointerDef(p1.resultdef).PointedDef.typ=objectdef) and
               (oo_has_vmt in TObjectDef(TPointerDef(p1.resultdef).PointedDef).ObjectOptions)  then
              Message(parser_w_use_extended_syntax_for_objects);

            if p1.nodetype=typen then
              TTypeNode(p1).allowed:=true;

            p1:=CInlineNode.Create(in_new_x,false,p1);
          end
        else
          begin
            consume(_COMMA);
            if TPointerDef(p1.resultdef).PointedDef.typ<>objectdef then
             begin
               Message(parser_e_pointer_to_class_expected);
               consume_all_until(_RKLAMMER);
               consume(_RKLAMMER);
               p1.free;
               p1 := nil;
               new_function:=CErrorNode.Create;
               exit;
             end;
            classh:=TObjectDef(TPointerDef(p1.resultdef).PointedDef);
            { use the objectdef for loading the VMT }
            p2:=p1;
            p1:=CTypeNode.Create(TPointerDef(p1.resultdef).PointedDef);
            DoTypeCheckPass(p1);
            { search the constructor also in the symbol tables of
              the parents }
            afterassignment:=false;
            SearchSym_In_Class(classh,classh,CurrentScanner.pattern,srsym,srsymtable,[ssf_search_helper]);
            consume(_ID);
            do_member_read(classh,false,srsym,p1,again,[cnf_new_call],nil);
            { we need to know which procedure is called }
            DoTypeCheckPass(p1);
            if not(
                   (p1.nodetype=calln) and
                   Assigned(TCallNode(p1).ProcDefinition) and
                   (TCallNode(p1).ProcDefinition.ProcTypeOption=potype_constructor)
                  ) then
              Message(parser_e_expr_have_to_be_constructor_call);
            { constructors return boolean, update resultdef to return
              the pointer to the object }
            p1.resultdef:=p2.resultdef;
            p2.free;
            p2 := nil;
            consume(_RKLAMMER);
          end;
        new_function:=p1;
      end;


    function inline_setlength : TNode;
      var
        paras: TNode;
      begin
        consume(_LKLAMMER);
        paras:=parse_paras(false,false,_RKLAMMER);
        consume(_RKLAMMER);
        if not Assigned(paras) then
         begin
           result:=CErrorNode.Create;
           CGMessage1(parser_e_wrong_parameter_size,'SetLength');
           exit;
         end;
        result:=CInlineNode.Create(in_setlength_x,false,paras);
      end;


    function inline_setstring : TNode;
      var
        paras, strpara, pcharpara: TNode;
        procname: string;
        cp: TStringEncoding;
      begin
        consume(_LKLAMMER);
        paras:=parse_paras(false,false,_RKLAMMER);
        consume(_RKLAMMER);
        procname:='';
        if Assigned(paras) and
           Assigned(TCallParaNode(paras).right) and
           Assigned(TCallParaNode(TCallParaNode(paras).right).right) then
          begin
            DoTypeCheckPass(TCallParaNode(TCallParaNode(paras).right).left);
            DoTypeCheckPass(TCallParaNode(TCallParaNode(TCallParaNode(paras).right).right).left);
            pcharpara:=TCallParaNode(TCallParaNode(paras).right).left;
            strpara:=TCallParaNode(TCallParaNode(TCallParaNode(paras).right).right).left;
            if strpara.resultdef.typ=stringdef then
              begin
                { if there are three parameters and the first parameter
                  ( = paras.right.right) is an ansistring, add a codepage
                  parameter }
                if Is_AnsiString(strpara.resultdef) then
                  begin
                    cp:=TStringDef(strpara.resultdef).encoding;
                    if (cp=Globals.CP_NONE) then
                      cp:=0;
                    paras:=CCallParaNode.Create(GenIntConstNode(cp),paras);
                  end;
                procname:='fpc_setstring_'+TStringDef(strpara.resultdef).StringTypName;
                { decide which version to call based on the second parameter }
                if not Is_ShortString(strpara.resultdef) then
                  if Is_PWideChar(pcharpara.resultdef) or
                     Is_WideChar(pcharpara.resultdef) or
                     ((pcharpara.resultdef.typ=arraydef) and
                      Is_WideChar(TArrayDef(pcharpara.resultdef).ElementDef)) then
                    procname:=procname+'_pwidechar'
                  else
                    procname:=procname+'_pansichar';
              end;
          end;
        { default version (for error message) in case of missing or wrong
          parameters }
        if procname='' then
          if m_default_unicodestring in CurrentSettings.ModeSwitches then
            procname:='fpc_setstring_unicodestr_pwidechar'
          else if m_default_ansistring in CurrentSettings.ModeSwitches then
            procname:='fpc_setstring_ansistr_pansichar'
          else
            procname:='fpc_setstring_shortstr';
        result:=CCallNode.CreateIntern(procname,paras)
      end;


    function inline_initfinal(isinit: boolean): TNode;
      var
        newblock,
        paras   : TNode;
        npara,
        destppn,
        ppn     : TCallParaNode;
      begin
        { for easy exiting if something goes wrong }
        result := CErrorNode.Create;

        consume(_LKLAMMER);
        paras:=parse_paras(false,false,_RKLAMMER);
        consume(_RKLAMMER);
        ppn:=TCallParaNode(paras);

        if not Assigned(paras) or
           (Assigned(ppn.right) and
            Assigned(TCallParaNode(ppn.right).right)) then
         begin
           if isinit then
             CGMessage1(parser_e_wrong_parameter_size,'Initialize')
           else
             CGMessage1(parser_e_wrong_parameter_size,'Finalize');
           exit;
         end;

        { 2 arguments? }
        if Assigned(ppn.right) then
         begin
           destppn:=TCallParaNode(ppn.right);
           { create call to fpc_initialize/finalize_array }
           npara:=CCallParaNode.Create(CTypeConvNode.Create
                     (ppn.left,S32IntType),
                  CCallParaNode.Create(CAddrNode.Create_Internal
                     (CRTTINode.Create(TStoredDef(destppn.left.resultdef),initrtti,rdt_normal)),
                  CCallParaNode.Create(CAddrNode.Create_Internal
                     (destppn.left),nil)));
           if isinit then
             newblock:=CCallNode.CreateIntern('fpc_initialize_array',npara)
           else
             newblock:=CCallNode.CreateIntern('fpc_finalize_array',npara);
           destppn.left:=nil;
         end
        else
         begin
           if isinit then
             newblock:=CNodeUtils.Initialize_Data_Node(ppn.left,true)
           else
             newblock:=CNodeUtils.Finalize_Data_Node(ppn.left);
         end;
        ppn.left:=nil;
        paras.free;
        paras := nil;
        result.free;
        result:=newblock;
      end;


    function inline_initialize : TNode;
      begin
        result:=inline_initfinal(true);
      end;


    function inline_finalize : TNode;
      begin
        result:=inline_initfinal(false);
      end;


    function inline_copy_insert_delete(nr:TInlineNumber;const name:string;checkempty:boolean) : TNode;
      var
        paras   : TNode;
        { for easy exiting if something goes wrong }
      begin
        result := CErrorNode.Create;

        consume(_LKLAMMER);
        paras:=parse_paras(false,false,_RKLAMMER);
        consume(_RKLAMMER);
        if not Assigned(paras) and checkempty then
          begin
            CGMessage1(parser_e_wrong_parameter_size,name);
            exit;
          end;
        result.free;
        result:=CInlineNode.Create(nr,false,paras);
      end;


    function inline_copy: TNode;
      begin
        result:=inline_copy_insert_delete(in_copy_x,'Copy',false);
      end;


    function inline_insert: TNode;
      begin
        result:=inline_copy_insert_delete(in_insert_x_y_z,'Insert',false);
      end;


    function inline_delete: TNode;
      begin
        result:=inline_copy_insert_delete(in_delete_x_y_z,'Delete',false);
      end;


    function inline_concat: TNode;
      begin
        result:=inline_copy_insert_delete(in_concat_x,'Concat',false);
      end;


end.
