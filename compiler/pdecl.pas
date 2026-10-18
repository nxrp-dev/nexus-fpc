{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Does declaration (but not type) parsing for Free Pascal

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
unit pdecl;

{$i fpcdefs.inc}

interface

    uses
      TPCompilerReal,
    { common }
      CClasses,
      { global }
      GlobType,
      { symtable }
      SymSym,symdef,symtype,
      { pass_1 }
      node;

    function  readconstant(const orgname:string;const filepos:TFilePosInfo; out nodetype: TNodeType):TConstSym;

    procedure const_dec(out had_generic:boolean);
    procedure consts_dec(in_structure, allow_typed_const: boolean;out had_generic:boolean);
    procedure label_dec;
    procedure type_dec(out had_generic:boolean);
    procedure types_dec(in_structure: boolean;out had_generic:boolean;var rtti_attrs_def: TRTTIAttributeList);
    procedure var_dec(out had_generic:boolean);
    procedure threadvar_dec(out had_generic:boolean);
    procedure property_dec;
    procedure resourcestring_dec(out had_generic:boolean);
    procedure parse_rttiattributes(var rtti_attrs_def:TRTTIAttributeList);
    function parse_forward_declaration(sym:TSym;gentypename,genorgtypename:TIDString;GenericDef:TDef;generictypelist:TFPHashObjectList;out newtype:TTypeSym):TDef;

implementation

    uses
       SysUtils,
       { common }
       CUtils,
       { global }
       Globals,tokens,Verbose,WideStr,ConstExp,
       Systems,AAsmData,FModule,compinnr,
       { symtable }
       symconst,SymBase,symcpu,symcreat,defutil,defcmp,SymTable,symutil,
       { pass 1 }
       ninl,ncon,nobj,ngenutil,nld,nmem,ncal,pass_1,
       { parser }
       Scanner,
       pbase,pexpr,ptype,ptconst,pdecsub,pdecvar,pdecobj,pgenutil,pparautl,
       procdefutil,
       { cpu-information }
       CPUInfo
       ;

    function is_system_custom_attribute_descendant(def:TDef):boolean;
    begin
      if not Assigned(Class_TCustomAttribute) then
        Class_TCustomAttribute:=TObjectDef(Search_System_Type('TCUSTOMATTRIBUTE').typedef);
      Result:=Def_Is_Related(def,Class_TCustomAttribute);
    end;

    function readconstant(const orgname:string;const filepos:TFilePosInfo; out nodetype: TNodeType):TConstSym;
      var
        hp : TConstSym;
        p : TNode;
        ps : PConstSet;
        pd : PBestReal;
        pg : PGUID;
        sp : pchar;
        pw : TCompilerWideString;
        storetokenpos : TFilePosInfo;
      begin
        readconstant:=nil;
        if orgname='' then
         InternalError(9584582);
        hp:=nil;
        p:=comp_expr([ef_accept_equal]);
        nodetype:=p.nodetype;
        storetokenpos:=CurrentTokenPos;
        CurrentTokenPos:=filepos;
        case p.nodetype of
           ordconstn:
             begin
               if p.resultdef.typ=pointerdef then
                 hp:=CConstSym.Create_OrdPtr(orgname,constpointer,TOrdConstNode(p).Value.uvalue,p.resultdef)
               else
                 hp:=CConstSym.Create_Ord(orgname,constord,TOrdConstNode(p).Value,p.resultdef);
             end;
           stringconstn:
             begin
               if Is_Wide_Or_Unicode_String(p.resultdef) then
                 begin
                   InitWideString(pw);
                   CopyWideString(TStringConstNode(p).ValueWS,pw);
                   hp:=CConstSym.Create_WString(orgname,constwstring,pw);
                 end
               else
                 begin
                   GetMem(sp,TStringConstNode(p).len+1);
                   sp[TStringConstNode(p).len]:=#0;
                   if TStringConstNode(p).len>0 then
                     move(TStringConstNode(p).valueas[0],sp^,TStringConstNode(p).len+1);
                   { if a non-default ansistring code page has been specified,
                     keep it }
                   if Is_AnsiString(p.resultdef) and
                      (TStringDef(p.resultdef).encoding<>0) then
                     hp:=CConstSym.Create_String(orgname,conststring,sp,TStringConstNode(p).len,p.resultdef)
                   else
                     hp:=CConstSym.Create_String(orgname,conststring,sp,TStringConstNode(p).len,nil);
                 end;
             end;
           realconstn :
             begin
                new(pd);
                pd^:=TRealConstNode(p).value_real;
                hp:=CConstSym.Create_Ptr(orgname,constreal,pd,p.resultdef);
             end;
           setconstn :
             begin
               new(ps);
               if Assigned(TSetConstNode(p).value_set) then
                 ps^:=TSetConstNode(p).value_set^
               else
                 ps^:=[];
               hp:=CConstSym.Create_Ptr(orgname,constset,ps,p.resultdef);
             end;
           pointerconstn :
             begin
               hp:=CConstSym.Create_OrdPtr(orgname,constpointer,TPointerConstNode(p).Value,p.resultdef);
             end;
           niln :
             begin
               hp:=CConstSym.Create_Ord(orgname,constnil,0,p.resultdef);
             end;
           typen :
             begin
               if Is_Interface(p.resultdef) then
                begin
                  if Assigned(TObjectDef(p.resultdef).IIDGUID) then
                   begin
                     new(pg);
                     pg^:=TObjectDef(p.resultdef).IIDGUID^;
                     hp:=CConstSym.Create_Ptr(orgname,constguid,pg,p.resultdef);
                   end
                  else
                   Message1(parser_e_interface_has_no_guid,TObjectDef(p.resultdef).ObjRealName^);
                end
               else
                Message(parser_e_illegal_expression);
             end;
           inlinen:
             begin
               { this situation only happens if a intrinsic is parsed that has a
                 generic type as its argument. As we don't know certain
                 information about the final type yet, we need to use safe
                 values (mostly 0, except for (Bit)SizeOf()) }
               if not parse_generic then
                 Message(parser_e_cannot_evaluate_expression_at_compile_time);
               case TInlineNode(p).inlinenumber of
                 in_sizeof_x:
                   begin
                     hp:=CConstSym.Create_Ord(orgname,constord,1,p.resultdef);
                   end;
                 in_bitsizeof_x:
                   begin
                     hp:=CConstSym.Create_Ord(orgname,constord,8,p.resultdef);
                   end;
                 { add other cases here if necessary }
                 else
                   Message(parser_e_illegal_expression);
               end;
             end;
           else
             begin
               { the node is from a generic parameter constant and is
                 untyped so we need to pass a placeholder constant
                 instead of givng an error }
               if nf_generic_para in p.flags then
                 hp:=CConstSym.Create_Ord(orgname,constnil,0,p.resultdef)
               else
                 Message(parser_e_illegal_expression);
             end;
        end;
        { transfer generic param flag from node to symbol }
        if nf_generic_para in p.flags then
          begin
            include(hp.SymOptions,sp_generic_const);
            include(hp.SymOptions,sp_generic_para);
          end;
        CurrentTokenPos:=storetokenpos;
        p.free;
        p := nil;
        readconstant:=hp;
      end;

    procedure const_dec(out had_generic:boolean);
      begin
        consume(_CONST);
        consts_dec(false,true,had_generic);
      end;

    procedure consts_dec(in_structure, allow_typed_const: boolean;out had_generic:boolean);
      var
         orgname : TIDString;
         hdef : TDef;
         sym : TSym;
         flags : THCCFlags;
         dummysymoptions : TSymOptions;
         DeprecatedMsg : PShortString;
         storetokenpos,filepos : TFilePosInfo;
         nodetype : TNodeType;
         old_block_type : TBlockType;
         first,
         isgeneric,
         expect_directive,
         skip_initialiser : boolean;
         VarSpez : TVarSpez;
         asmtype : TAsmListType;
      begin
         old_block_type:=Block_Type;
         Block_Type:=bt_const;
         had_generic:=false;
         first:=true;
         repeat
           orgname:=CurrentScanner.orgpattern;
           filepos:=CurrentTokenPos;
           isgeneric:=not (m_delphi in CurrentSettings.ModeSwitches) and (CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_GENERIC);
           consume(_ID);
           case CurrentScanner.token of

             _EQ:
                begin
                   consume(_EQ);
                   sym:=readconstant(orgname,filepos,nodetype);
                   { Support hint directives }
                   dummysymoptions:=[];
                   DeprecatedMsg:=nil;
                   try_consume_hintdirective(dummysymoptions,DeprecatedMsg);
                   if Assigned(sym) then
                     begin
                       sym.SymOptions:=sym.SymOptions+dummysymoptions;
                       sym.DeprecatedMsg:=DeprecatedMsg;
                       sym.visibility:=SymTableStack.top.CurrentVisibility;
                       SymTableStack.top.InsertSym(sym);
                       sym.RegisterSym;
                     end
                   else
                     StringDispose(DeprecatedMsg);
                   consume(_SEMICOLON);
                end;

             _COLON:
                begin
                   if not allow_typed_const then
                     begin
                       Message(parser_e_no_typed_const);
                       consume_all_until(_SEMICOLON);
                     end;
                   { set the blocktype first so a consume also supports a
                     caret, to support const s : ^string = nil }
                   Block_Type:=bt_const_type;
                   consume(_COLON);
                   read_anon_type(hdef,false,nil);
                   Block_Type:=bt_const;
                   { create symbol }
                   storetokenpos:=CurrentTokenPos;
                   CurrentTokenPos:=filepos;
                   if not (cs_typed_const_writable in CurrentSettings.LocalSwitches) then
                     begin
                       VarSpez:=vs_const;
                       asmtype:=al_rotypedconsts;
                     end
                   else
                     begin
                       VarSpez:=vs_value;
                       asmtype:=al_typedconsts;
                     end;
                   { if we are dealing with structure const then we need to handle it as a
                     structure static variable: create a symbol in unit symtable and a reference
                     to it from the structure or linking will fail }
                   if SymTableStack.top.SymTableType in [recordsymtable,ObjectSymtable] then
                     begin
                       { note: we keep hdef so that we might at least read the
                               constant data correctly for error recovery }
                       check_allowed_for_var_or_const(hdef,false);
                       sym:=CFieldVarSym.create(orgname,VarSpez,hdef,[]);
                       SymTableStack.top.InsertSym(sym);
                       sym:=Make_Field_Static(SymTableStack.top,TFieldVarSym(sym));
                     end
                   else
                     begin
                       sym:=CStaticVarSym.create(orgname,VarSpez,hdef,[]);
                       sym.visibility:=SymTableStack.top.CurrentVisibility;
                       SymTableStack.top.InsertSym(sym);
                     end;
                   sym.RegisterSym;
                   CurrentTokenPos:=storetokenpos;
                   skip_initialiser:=false;
                   { Anonymous proctype definitions can have proc directives }
                   if (
                         (hdef.typ=procvardef) or
                         Is_FuncRef(hdef)
                       ) and
                       (hdef.TypeSym=nil) then
                    begin
                      { Either "procedure; stdcall" or "procedure stdcall" }
                      expect_directive:=try_to_consume(_SEMICOLON);
                      if check_proc_directive(true) then
                        parse_proctype_directives(hdef)
                      else if expect_directive then
                       begin
                         Message(parser_e_proc_directive_expected);
                         skip_initialiser:=true;
                       end;
                      { add default calling convention }
                      if hdef.typ=procvardef then
                        flags:=hcc_default_actions_intf
                      else
                        flags:=hcc_default_actions_intf_struct;
                      handle_calling_convention(hdef,flags);
                    end;
                   { Parse the initialiser }
                   if not skip_initialiser then
                    begin
                      consume(_EQ);
                      read_typed_const(CurrentAsmData.asmlists[asmtype],TStaticVarSym(sym),in_structure);
                    end;
                end;

              else
                if not first and isgeneric and (CurrentScanner.token in [_PROCEDURE,_FUNCTION,_CLASS]) then
                  begin
                    had_generic:=true;
                    break;
                  end
                else
                  { generate an error }
                  consume(_EQ);
           end;

           first:=false;
         until (CurrentScanner.token<>_ID) or
               (in_structure and
                ((CurrentScanner.idtoken in [_PRIVATE,_PROTECTED,_PUBLIC,_PUBLISHED,_STRICT]) or
                 ((m_final_fields in CurrentSettings.ModeSwitches) and
                  (CurrentScanner.idtoken=_FINAL))));
         Block_Type:=old_block_type;
      end;


    procedure label_dec;
      var
        labelsym : TLabelSym;
      begin
         consume(_LABEL);
         if not(cs_support_goto in CurrentSettings.ModuleSwitches) then
           Message(sym_e_goto_and_label_not_supported);
         repeat
           if not(CurrentScanner.token in [_ID,_INTCONST]) then
             consume(_ID)
           else
             begin
                if CurrentScanner.token=_ID then
                  labelsym:=CLabelSym.create(CurrentScanner.orgpattern)
                else
                  begin
                    { strip leading 0's in iso mode }
                    if (([m_iso,m_extpas]*CurrentSettings.ModeSwitches)<>[]) then
                      while (length(CurrentScanner.pattern)>1) and (CurrentScanner.pattern[1]='0') do
                        delete(CurrentScanner.pattern,1,1);
                    labelsym:=CLabelSym.create(CurrentScanner.pattern);
                  end;

                SymTableStack.top.InsertSym(labelsym);
                if m_non_local_goto in CurrentSettings.ModeSwitches then
                  begin
                    if SymTableStack.top.SymTableType=LocalSymTable then
                      begin
                        labelsym.JumpBuf:=CLocalVarSym.create('LABEL$_'+labelsym.name,vs_value,Rec_Jmp_Buf,[]);
                        SymTableStack.top.InsertSym(labelsym.JumpBuf);
                      end
                    else
                      begin
                        labelsym.JumpBuf:=CStaticVarSym.create('LABEL$_'+labelsym.name,vs_value,Rec_Jmp_Buf,[]);
                        SymTableStack.top.InsertSym(labelsym.JumpBuf);
                        CNodeUtils.insertbssdata(TStaticVarSym(labelsym.JumpBuf));
                      end;
                    include(labelsym.JumpBuf.SymOptions,sp_internal);
                    { the buffer will be setup later, but avoid a hint }
                    TAbstractVarSym(labelsym.JumpBuf).VarState:=vs_written;
                  end;
                consume(CurrentScanner.token);
             end;
           if CurrentScanner.token<>_SEMICOLON then consume(_COMMA);
         until not(CurrentScanner.token in [_ID,_INTCONST]);
         consume(_SEMICOLON);
      end;

    function find_create_constructor(objdef:TObjectDef):TSymEntry;
      begin
         while Assigned(objdef) do
           begin
             result:=objdef.SymTable.Find('CREATE');
             if Assigned(result) then
               exit;
             objdef:=objdef.ChildOf;
           end;
         // A class without a constructor called 'create'?!?
         InternalError(2012111101);
      end;

    procedure parse_rttiattributes(var rtti_attrs_def:TRTTIAttributeList);

      function read_attr_paras:TNode;
        var
          old_block_type : TBlockType;
        begin
          if try_to_consume(_LKLAMMER) then
            begin
              { we only want constants here }
              old_block_type:=Block_Type;
              Block_Type:=bt_const;
              result:=parse_paras(false,false,_RKLAMMER);
              Block_Type:=old_block_type;
              consume(_RKLAMMER);
            end
          else
            result:=nil;
        end;

      var
        p,paran,pcalln,ptmp : TNode;
        ecnt : LongInt;
        i,pcount : sizeint;
        paras : array of TNode;
        od : TObjectDef;
        constrsym : TSymEntry;
        TypeSym : TTypeSym;
        parasok : boolean;
      begin
        consume(_LECKKLAMMER);

        repeat
          { Parse attribute type }
          p:=factor(false,[ef_type_only,ef_check_attr_suffix]);
          if p.nodetype=typen then
            begin
              TypeSym:=TTypeSym(TTypeNode(p).TypeSym);
              od:=TObjectDef(TTypeNode(p).typedef);

              { Check if the attribute class is related to TCustomAttribute }
              if not is_system_custom_attribute_descendant(od) then
                begin
                  IncompatibleTypes(od,Class_TCustomAttribute);
                  read_attr_paras.free; // no nil needed
                  continue;
                end;

              paran:=read_attr_paras;

              { Search the tprocdef of the constructor which has to be called. }
              constrsym:=find_create_constructor(od);
              if constrsym.typ<>ProcSym then
                InternalError(2018102301);

              pcalln:=CCallNode.create(paran,TProcSym(constrsym),od.SymTable,CLoadVMTAddrNode.create(p),[cnf_no_convert_procvar],nil);
              p:=nil;
              ecnt:=ErrorCount;
              TypeCheckPass(pcalln);

              if (pcalln.nodetype=calln) and Assigned(TCallNode(pcalln).procdefinition) and not CodeGenError then
                begin
                  { TODO: once extended RTTI for methods is supported, reject a
                          constructor if it doesn't have extended RTTI enabled }

                  { collect the parameters of the call node as there might be
                    compile time type conversions (e.g. a Byte parameter being
                    passed a value > 255) }
                  paran:=TCallNode(pcalln).left;

                  { only count visible parameters (thankfully open arrays are not
                    supported, otherwise we'd need to handle those as well) }
                  parasok:=true;
                  paras:=nil;
                  if Assigned(paran) then
                    begin
                      ptmp:=paran;
                      pcount:=0;
                      while Assigned(ptmp) do
                        begin
                          if not (vo_is_hidden_para in TCallParaNode(ptmp).parasym.VarOptions) then
                            inc(pcount);
                          ptmp:=TCallParaNode(ptmp).right;
                        end;
                      SetLength(paras,pcount);
                      ptmp:=paran;
                      pcount:=0;
                      while Assigned(ptmp) do
                        begin
                          if not (vo_is_hidden_para in TCallParaNode(ptmp).parasym.VarOptions) then
                            begin
                              if not is_constnode(TCallParaNode(ptmp).left) then
                                begin
                                  parasok:=false;
                                  messagepos(TCallParaNode(ptmp).left.fileinfo,type_e_constant_expr_expected);
                                end;
                              paras[high(paras)-pcount]:=TCallParaNode(ptmp).left.GetCopy;
                              inc(pcount);
                            end;
                          ptmp:=TCallParaNode(ptmp).right;
                        end;
                    end;

                  if parasok then
                    begin
                      { Add attribute to attribute list which will be added
                        to the property which is defined next. }
                      if not Assigned(rtti_attrs_def) then
                        rtti_attrs_def:=TRTTIAttributeList.create;
                      rtti_attrs_def.AddAttribute(TypeSym,TCallNode(pcalln).procdefinition,pcalln,paras);
                    end
                  else
                    begin
                      { cleanup }
                      pcalln.free;
                      pcalln := nil;
                      for i:=0 to high(paras) do
                        FreeAndNil(paras[i]);
                    end;
                end
              else begin
                { provide *some* error in case there hasn't been one }
                if ErrorCount=ecnt then
                  message(parser_e_illegal_expression);
                pcalln.free;
                pcalln := nil;
              end;
            end
          else
            begin
              Message(type_e_type_id_expected);
              { try to recover by nevertheless reading the parameters (if any) }
              read_attr_paras.free; // no nil needed
            end;

          p.free;
          p := nil;
        until not try_to_consume(_COMMA);

        consume(_RECKKLAMMER);
      end;


    function parse_forward_declaration(sym:TSym;gentypename,genorgtypename:TIDString;GenericDef:TDef;generictypelist:TFPHashObjectList;out newtype:TTypeSym):TDef;
      var
        wasforward : boolean;
        ObjectType : TObjectTyp;
        gendef : TStoredDef;
      begin
        newtype:=nil;
        wasforward:=false;
        if ((CurrentScanner.token=_CLASS) or
            (CurrentScanner.token=_INTERFACE) or
            (CurrentScanner.token=_DISPINTERFACE) or
            (CurrentScanner.token=_OBJCCLASS) or
            (CurrentScanner.token=_OBJCPROTOCOL) or
            (CurrentScanner.token=_OBJCCATEGORY)) and
           (Assigned(TTypeSym(sym).typedef)) and
           Is_Implicit_Pointer_Object_Type(TTypeSym(sym).typedef) and
           (oo_is_forward in TObjectDef(TTypeSym(sym).typedef).ObjectOptions) then
         begin
           wasforward:=true;
           ObjectType:=odt_none;
           case CurrentScanner.token of
             _CLASS :
               ObjectType:=DefaultClassType;
             _INTERFACE :
               case CurrentSettings.InterfaceType of
                 it_interfacecom:
                   ObjectType:=odt_interfacecom;
                 it_interfacecorba:
                   ObjectType:=odt_interfacecorba;

               end;
             _DISPINTERFACE :
               ObjectType:=odt_dispinterface;
             _OBJCCLASS,
             _OBJCCATEGORY :
               ObjectType:=odt_objcclass;
             _OBJCPROTOCOL :
               ObjectType:=odt_objcprotocol;
             else
               InternalError(200811072);
           end;
           consume(CurrentScanner.token);
           if Assigned(GenericDef) then
             gendef:=TStoredDef(GenericDef)
           else
             { determine the generic def in case we are in a nested type
               of a specialization }
             gendef:=determine_generic_def(gentypename);
           { we can ignore the result, the definition is modified }
           object_dec(ObjectType,genorgtypename,newtype,gendef,generictypelist,TObjectDef(TTypeSym(sym).typedef),ht_none);
           if wasforward and
             (TObjectDef(TTypeSym(sym).typedef).ObjectType<>ObjectType) then
             Message1(type_e_forward_interface_type_does_not_match,TObjectDef(TTypeSym(sym).typedef).GetTypeName);
           newtype:=TTypeSym(sym);
           result:=newtype.typedef;
         end
        else
          begin
            message1(parser_h_type_redef,genorgtypename);
            result:=GenErrorDef;
          end;
      end;

    { From http://clang.llvm.org/docs/LanguageExtensions.html#objective-c-features :
      To determine whether a method has an inferred related result type, the first word in the camel-case selector
      (e.g., “init” in “initWithObjects”) is considered, and the method will have a related result type if its return
      type is compatible with the type of its class and if:
        * the first word is "alloc" or "new", and the method is a class method, or
        * the first word is "autorelease", "init", "retain", or "self", and the method is an instance method.

      If a method with a related result type is overridden by a subclass method, the subclass method must also return
      a type that is compatible with the subclass type.
    }
    procedure pd_set_objc_related_result(def: tobject; para: pointer);
      var
        pd: TProcDef;
        i, firstcamelend: LongInt;
        inferresult: boolean;
      begin
        if TDef(def).typ<>procdef then
          exit;
        pd:=TProcDef(def);
        if not(po_msgstr in pd.ProcOptions) then
          InternalError(2019082401);
        firstcamelend:=length(pd.MessageInf.str^);
        for i:=1 to length(pd.MessageInf.str^) do
          if pd.MessageInf.str^[i] in ['A'..'Z'] then
            begin
              firstcamelend:=pred(i);
              break;
            end;
        case copy(pd.MessageInf.str^,1,firstcamelend) of
          'alloc',
          'new':
             inferresult:=po_classmethod in pd.ProcOptions;
          'autorelease',
          'init',
          'retain',
          'self':
             inferresult:=not(po_classmethod in pd.ProcOptions);
          else
            inferresult:=false;
        end;
        if inferresult and
           Def_Is_Related(TDef(pd.ProcSym.owner.DefOwner),pd.ReturnDef) then
          include(pd.ProcOptions,po_objc_related_result_type);
      end;

    procedure types_dec(in_structure: boolean;out had_generic:boolean;var rtti_attrs_def: TRTTIAttributeList);

      procedure finalize_class_external_status(od: TObjectDef);
        begin
          if  [oo_is_external,oo_is_forward] <= od.ObjectOptions then
            begin
              { formal definition: x = objcclass external; }
              exclude(od.ObjectOptions,oo_is_forward);
              include(od.ObjectOptions,oo_is_formal);
            end;
        end;

      var
         TypeName,orgtypename,
         gentypename,genorgtypename : TIDString;
         newtype  : TTypeSym;
         DummySym,
         sym      : TSym;
         hdef,
         hdef2    : TDef;
         defpos,storetokenpos : TFilePosInfo;
         old_block_type : TBlockType;
         old_checkforwarddefs: TFPObjectList;
         flags : THCCFlags;
         setdummysym,
         first,
         isgeneric,
         isunique,
         istyperenaming : boolean;
         generictypelist : TFPHashObjectList;
         localgenerictokenbuf : TDynamicArray;
         p:TNode;
         gendef : TStoredDef;
         s : shortstring;
         i : LongInt;
{$ifdef x86}
         segment_register: string;
{$endif x86}
      begin
         old_block_type:=Block_Type;
         { save unit container of forward declarations -
           we can be inside nested class type block }
         old_checkforwarddefs:=CurrentModule.CheckForwardDefs;
         CurrentModule.CheckForwardDefs:=TFPObjectList.Create(false);
         Block_Type:=bt_type;
         hdef:=nil;
         first:=true;
         had_generic:=false;
         storetokenpos:=Default(TFilePosInfo);
         repeat
           defpos:=CurrentTokenPos;
           istyperenaming:=false;
           setdummysym:=false;
           generictypelist:=nil;
           localgenerictokenbuf:=nil;

           { class attribute definitions? }
           if m_prefixed_attributes in CurrentSettings.ModeSwitches then
             while CurrentScanner.token=_LECKKLAMMER do
               parse_rttiattributes(rtti_attrs_def);

           { fpc generic declaration? }
           if first then
             had_generic:=not(m_delphi in CurrentSettings.ModeSwitches) and try_to_consume(_GENERIC);
           isgeneric:=had_generic;

           TypeName:=CurrentScanner.pattern;
           orgtypename:=CurrentScanner.orgpattern;
           consume(_ID);

           { delphi generic declaration? }
           if (m_delphi in CurrentSettings.ModeSwitches) then
             isgeneric:=CurrentScanner.token=_LSHARPBRACKET;

           { Generic type declaration? }
           if isgeneric then
             begin
               if Assigned(CurrentGenericDef) then
                 Message(parser_f_no_generic_inside_generic);

               consume(_LSHARPBRACKET);
               generictypelist:=parse_generic_parameters(true);
               consume(_RSHARPBRACKET);

               str(generictypelist.Count,s);
               gentypename:=TypeName+'$'+s;
               genorgtypename:=orgtypename+'$'+s;
             end
           else
             begin
               gentypename:=TypeName;
               genorgtypename:=orgtypename;
             end;

           consume(_EQ);

           { support 'ttype=type word' syntax }
           isunique:=try_to_consume(_TYPE);

           { MacPas object model is more like Delphi's than like TP's, but }
           { uses the object keyword instead of class                      }
           if (m_mac in CurrentSettings.ModeSwitches) and
              (CurrentScanner.token = _OBJECT) then
             CurrentScanner.token := _CLASS;

           { Start recording a generic template }
           if Assigned(generictypelist) then
             begin
               localgenerictokenbuf:=TDynamicArray.create(256);
               CurrentScanner.startrecordtokens(localgenerictokenbuf);
             end;

           { is the type already defined? -- must be in the current symtable,
             not in a nested symtable or one higher up the stack -> don't
             use searchsym & friends! }
           sym:=TSym(SymTableStack.top.find(gentypename));
           newtype:=nil;
           { found a symbol with this name? }
           if Assigned(sym) then
            begin
              if (sym.typ=TypeSym) and
                 { this should not be a symbol that was created by a generic
                   that was declared earlier }
                 not (
                   (TTypeSym(sym).typedef.typ=undefineddef) and
                   (sp_generic_dummy in sym.SymOptions)
                 ) then
               begin
                 hdef:=parse_forward_declaration(sym,gentypename,genorgtypename,nil,generictypelist,newtype);
               end;
            end;
           { no old type reused ? Then insert this new type }
           if not Assigned(newtype) then
            begin
              if isgeneric then
                begin
                  { we are not freeing the type parameters, so register them }
                  for i:=0 to generictypelist.count-1 do
                    begin
                       TStoredSym(generictypelist[i]).RegisterSym;
                       if TStoredSym(generictypelist[i]).typ=TypeSym then
                         TStoredDef(TTypeSym(generictypelist[i]).typedef).RegisterDef;
                    end;
                end;

              { insert the new type first with an errordef, so that
                referencing the type before it's really set it
                will give an error (PFV) }
              hdef:=GenErrorDef;
              gendef:=nil;
              storetokenpos:=CurrentTokenPos;
              if isgeneric then
                begin
                  { for generics we need to check whether a non-generic type
                    already exists and if not we need to insert a symbol with
                    the non-generic name (available in (org)typename) that is a
                    undefineddef, so that inline specializations can be used }
                  sym:=TSym(SymTableStack.top.Find(TypeName));
                  if not Assigned(sym) then
                    begin
                      sym:=CTypeSym.create(orgtypename,CUndefinedDef.create(true));
                      Include(sym.SymOptions,sp_generic_dummy);
                      TTypeSym(sym).typedef.TypeSym:=sym;
                      sym.visibility:=SymTableStack.top.CurrentVisibility;
                      { add as dummy symbol before adding it to the symtable stack }
                      add_generic_dummysym(sym,TypeName);
                      SymTableStack.top.InsertSym(sym);
                      TTypeSym(sym).typedef.owner:=sym.owner;
                    end
                  else
                    { this is not allowed in non-Delphi modes }
                    if not (m_delphi in CurrentSettings.ModeSwitches) then
                      Message1(sym_e_duplicate_id,genorgtypename)
                    else
                      begin
                        { we need to find this symbol even if it's a variable or
                          something else when doing an inline specialization }
                        Include(sym.SymOptions,sp_generic_dummy);
                        add_generic_dummysym(sym,'');
                      end;
                end
              else
                begin
                  if Assigned(sym) and (sym.typ=TypeSym) and
                      (TTypeSym(sym).typedef.typ=undefineddef) and
                      (sp_generic_dummy in sym.SymOptions) then
                    begin
                      { this is a symbol that was added by an earlier generic
                        declaration, reuse it }
                      newtype:=TTypeSym(sym);
                      newtype.typedef:=hdef;
                      { use the correct casing }
                      newtype.RealName:=genorgtypename;
                      sym:=nil;
                    end;

                  { determine the generic def in case we are in a nested type
                    of a specialization }
                  gendef:=determine_generic_def(gentypename);
                end;
              { insert a new type if we don't reuse an existing symbol }
              if not Assigned(newtype) then
                begin
                  newtype:=CTypeSym.create(genorgtypename,hdef);
                  newtype.visibility:=SymTableStack.top.CurrentVisibility;
                  SymTableStack.top.InsertSym(newtype);
                end;
              CurrentTokenPos:=defpos;
              CurrentTokenPos:=storetokenpos;
              { read the type definition }
              read_named_type(hdef,newtype,gendef,generictypelist,false,isunique);
              { update the definition of the type }
              if Assigned(hdef) then
                begin
                  if Assigned(hdef.TypeSym) then
                    begin
                      istyperenaming:=true;
                      include(newtype.SymOptions,sp_explicitrename);
                    end;
                  if isunique then
                    begin
                      if Is_ObjC_Class_Or_Protocol(hdef) then
                        Message(parser_e_unique_unsupported);

                      if Is_Object(hdef) or
                         Is_Class_Or_Interface_Or_DispInterface(hdef) then
                        begin
                          { just create a copy that is a child of the original class class type; this is
                            Delphi-compatible }
                          hdef2:=TStoredDef(hdef).GetCopy;
                          TObjectDef(hdef2).ChildOf:=TObjectDef(hdef);
                          TStoredDef(hdef2).OrgDef:=TStoredDef(hdef);
                          hdef:=hdef2;
                        end
                      else
                        begin
                          hdef2:=TStoredDef(hdef).GetCopy;
                          TStoredDef(hdef2).OrgDef:=TStoredDef(hdef);
                          hdef:=hdef2;
                          { check if it is an ansistring(codepage) declaration }
                          if Is_AnsiString(hdef) and try_to_consume(_LKLAMMER) then
                            begin
                              p:=comp_expr([ef_accept_equal]);
                              consume(_RKLAMMER);
                              if not is_constintnode(p) then
                                begin
                                  Message(parser_e_illegal_expression);
                                  { error recovery }
                                end
                              else
                                begin
                                  if (TOrdConstNode(p).Value<0) or (TOrdConstNode(p).Value>65535) then
                                    begin
                                      Message(parser_e_invalid_codepage);
                                      TOrdConstNode(p).Value:=0;
                                    end;
                                  TStringDef(hdef).encoding:=int64(TOrdConstNode(p).Value);
                                end;
                              p.free;
                              p := nil;
                            end;
                          if (hdef.typ in [pointerdef,classrefdef]) and
                             (TAbstractPointerDef(hdef).PointedDef.typ=ForwardDef) then
                            CurrentModule.CheckForwardDefs.add(hdef);
                        end;

                      include(hdef.DefOptions,df_unique);

                      { update object's real name for better error messages }
                      if hdef is TAbstractRecordDef then
                        TAbstractRecordDef(hdef).SetObjRealName(newtype.RealName);
                    end;
                  if not Assigned(hdef.TypeSym) then
                    begin
                      hdef.TypeSym:=newtype;
                      if sp_generic_dummy in newtype.SymOptions then
                        add_generic_dummysym(newtype,'');
                    end;
                end;
              { in non-Delphi modes we need a reference to the generic def
                without the generic suffix, so it can be found easily when
                parsing method implementations }
              if isgeneric and Assigned(sym) and
                  not (m_delphi in CurrentSettings.ModeSwitches) and
                  (TTypeSym(sym).typedef.typ=undefineddef) then
                begin
                  { don't free the undefineddef as the defids rely on the count
                    of the defs in the def list of the module}
                  TTypeSym(sym).typedef:=hdef;
                  setdummysym:=true;
                end;
              newtype.typedef:=hdef;
              { ensure that the type is registered when no specialization is
                currently done }
              if (CurrentScanner.replay_stack_depth=0) and
                  (
                    (hdef.typ<>procvardef) or
                    not (po_is_function_ref in TAbstractProcDef(hdef).ProcOptions)
                  ) then
                hdef.RegisterDef;
              { KAZ: handle TGUID declaration in system unit }
              if (cs_compilesystem in CurrentSettings.ModuleSwitches) and
                 Assigned(hdef) and
                 (hdef.typ=recorddef) then
                begin
                  if not Assigned(Rec_TGUID) and
                     (gentypename='TGUID') and
                     (hdef.Size=16) then
                    Rec_TGUID:=TRecordDef(hdef)
                  else if not Assigned(Rec_Jmp_Buf) and
                     (gentypename='JMP_BUF') then
                    Rec_Jmp_Buf:=TRecordDef(hdef)
                  else if not Assigned(Rec_ExceptAddr) and
                     (gentypename='TEXCEPTADDR') then
                    Rec_ExceptAddr:=TRecordDef(hdef);
                end;
            end;
           if Assigned(hdef) then
            begin
              case hdef.typ of
                pointerdef :
                  begin
                    try_consume_hintdirective(newtype.SymOptions,newtype.DeprecatedMsg);
                    consume(_SEMICOLON);
{$ifdef x86}

  {$if defined(i386)}
                    if try_to_consume(_FAR) then
                     begin
                       TCPUPointerDef(hdef).X86PointerTyp:=x86pt_near_fs;
                       consume(_SEMICOLON);
                     end
                    else
  {$endif}
                      if try_to_consume(_NEAR) then
                       begin
                         if CurrentScanner.token <> _SEMICOLON then
                           begin
                             segment_register:=get_stringconst;
                             case UpCase(segment_register) of
                               'CS': TCPUPointerDef(hdef).X86PointerTyp:=x86pt_near_cs;
                               'DS': TCPUPointerDef(hdef).X86PointerTyp:=x86pt_near_ds;
                               'SS': TCPUPointerDef(hdef).X86PointerTyp:=x86pt_near_ss;
                               'ES': TCPUPointerDef(hdef).X86PointerTyp:=x86pt_near_es;
                               'FS': TCPUPointerDef(hdef).X86PointerTyp:=x86pt_near_fs;
                               'GS': TCPUPointerDef(hdef).X86PointerTyp:=x86pt_near_gs;
                               else
                                 Message(asmr_e_invalid_register);
                             end;
                           end
                         else
                           TCPUPointerDef(hdef).X86PointerTyp:=x86pt_near;
                         consume(_SEMICOLON);
                       end;
{$endif x86}
                  end;
                procvardef :
                  begin
                    { in case of type renaming, don't parse proc directives }
                    if istyperenaming then
                      begin
                        try_consume_hintdirective(newtype.SymOptions,newtype.DeprecatedMsg);
                        consume(_SEMICOLON);
                      end
                    else
                     begin
                       if not check_proc_directive(true) then
                         begin
                           try_consume_hintdirective(newtype.SymOptions,newtype.DeprecatedMsg);
                           consume(_SEMICOLON);
                         end;
                       parse_proctype_directives(TProcVarDef(hdef));
                       if po_is_function_ref in TProcVarDef(hdef).ProcOptions then
                         begin
                           if not (m_function_references in CurrentSettings.ModeSwitches) and
                               not (po_is_block in TProcVarDef(hdef).ProcOptions) then
                             messagepos(storetokenpos,sym_e_error_in_type_def)
                           else
                             begin
                               if setdummysym then
                                 DummySym:=sym
                               else
                                 DummySym:=nil;
                               Adjust_FuncRef(hdef,newtype,DummySym);
                             end;
                           if CurrentScanner.replay_stack_depth=0 then
                             hdef.RegisterDef;
                         end;
                       if hdef.typ=procvardef then
                         flags:=hcc_default_actions_intf
                       else
                         flags:=hcc_default_actions_intf_struct;
                       handle_calling_convention(hdef,flags);
                       if (hdef.typ=procvardef) and (po_is_function_ref in TProcVarDef(hdef).ProcOptions) then
                         begin
                           if (po_is_block in TProcVarDef(hdef).ProcOptions) and
                              not (TProcVarDef(hdef).ProcCallOption in [pocall_cdecl,pocall_mwpascal]) then
                             message(type_e_cblock_callconv);
                         end;
                       if try_consume_hintdirective(newtype.SymOptions,newtype.DeprecatedMsg) then
                         consume(_SEMICOLON);
                     end;
                  end;
                objectdef :
                  begin
                    if Is_FuncRef(hdef) then
                      begin
                        if not check_proc_directive(true) then
                          begin
                            try_consume_hintdirective(newtype.SymOptions,newtype.DeprecatedMsg);
                            consume(_SEMICOLON);
                          end;
                        parse_proctype_directives(hdef);
                        if try_consume_hintdirective(newtype.SymOptions,newtype.DeprecatedMsg) then
                          consume(_SEMICOLON);
                      end
                    else
                      begin
                        try_consume_hintdirective(newtype.SymOptions,newtype.DeprecatedMsg);
                        consume(_SEMICOLON);
                      end;

                    { change a forward and external class declaration into
                      formal external definition, so the compiler does not
                      expect an real definition later }
                    if Is_ObjC_Class_Or_Protocol(hdef) then
                      finalize_class_external_status(TObjectDef(hdef));

                    { Build VMT indexes, skip for type renaming and forward classes }
                    if not istyperenaming and
                       not(oo_is_forward in TObjectDef(hdef).ObjectOptions) then
                      if not (oo_inherits_not_specialized in TObjectDef(hdef).ObjectOptions) then
                        build_vmt(TObjectDef(hdef))
                      else
                      { update the procdevs to add hidden self param }
                      insert_struct_hidden_paras(TObjectDef(hdef));

                    { In case of an objcclass, verify that all methods have a message
                      name set. We only check this now, because message names can be set
                      during the protocol (interface) mapping. At the same time, set the
                      mangled names (these depend on the "external" name of the class),
                      and mark private fields of external classes as "used" (to avoid
                      bogus notes about them being unused)
                    }
                    { watch out for crashes in case of errors }
                    if Is_ObjC_Class_Or_Protocol(hdef) and
                       (not Is_ObjCCategory(hdef) or
                        Assigned(TObjectDef(hdef).ChildOf)) then
                      begin
                        TObjectDef(hdef).Finish_ObjC_Data;
                        TObjectDef(hdef).SymTable.DefList.ForEachCall(@pd_set_objc_related_result,nil);
                      end;

                    if Is_CPPClass(hdef) then
                      TObjectDef(hdef).Finish_CPP_Data;
                  end;
                recorddef :
                  begin
                    try_consume_hintdirective(newtype.SymOptions,newtype.DeprecatedMsg);
                    consume(_SEMICOLON);
                  end;
                else
                  begin
                    try_consume_hintdirective(newtype.SymOptions,newtype.DeprecatedMsg);
                    consume(_SEMICOLON);
                  end;
              end;

              { if we have a real type definition or a unique type we may bind
                attributes to this def }
              if not istyperenaming or isunique then
                TRTTIAttributeList.bind(rtti_attrs_def,TStoredDef(hdef).RTTIAttributeList);

              if df_generic in hdef.DefOptions then
                { flag parent symtables that they now contain a generic }
                hdef.owner.IncludeOption(sto_has_generic);
            end;

           if isgeneric and (not(hdef.typ in [objectdef,recorddef,arraydef,procvardef])
               or Is_ObjectPascal_Helper(hdef)) then
             begin
               newtype.typedef:=GenErrorDef;
               message(parser_e_cant_create_generics_of_this_type);
             end;

           { Stop recording a generic template }
           if Assigned(generictypelist) then
             begin
               CurrentScanner.stoprecordtokens;
               TStoredDef(hdef).GenericTokenBuf:=localgenerictokenbuf;
               { Generic is never a type renaming }
               hdef.TypeSym:=newtype;
               { reusing a forward declared type also reuses the type parameters,
                 so free them if they haven't been used }
               for i:=0 to generictypelist.count-1 do
                 begin
                   if (TStoredSym(generictypelist[i]).typ=TypeSym) and
                       not TTypeSym(generictypelist[i]).typedef.IsRegistered then
                     FreeAndNil(TTypeSym(generictypelist[i]).typedef);
                   if not TStoredSym(generictypelist[i]).IsRegistered then
                     TStoredSym(generictypelist[i]).free; // no nil needed
                 end;
               generictypelist.free;
               generictypelist := nil;
             end;

           if not (m_delphi in CurrentSettings.ModeSwitches) and
               (CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_GENERIC) then
             begin
               had_generic:=true;
               consume(_ID);
               if CurrentScanner.token in [_PROCEDURE,_FUNCTION,_CLASS] then
                 break;
             end
           else
             had_generic:=false;
           first:=false;
           if Assigned(rtti_attrs_def) and (rtti_attrs_def.GetAttributeCount>0) then
             Message1(parser_e_unbound_attribute,TRTTIAttribute(rtti_attrs_def.RTTIAttributes[0]).TypeSym.prettyname);


         until ((CurrentScanner.token<>_ID) and (CurrentScanner.token<>_LECKKLAMMER)) or
               (in_structure and
                ((CurrentScanner.idtoken in [_PRIVATE,_PROTECTED,_PUBLIC,_PUBLISHED,_STRICT]) or
                 ((m_final_fields in CurrentSettings.ModeSwitches) and
                  (CurrentScanner.idtoken=_FINAL))));
         { resolve type block forward declarations and restore a unit
           container for them }
         resolve_forward_types;
         CurrentModule.CheckForwardDefs.free;
         CurrentModule.CheckForwardDefs:=old_checkforwarddefs;
         Block_Type:=old_block_type;
      end;


    { reads a type declaration to the symbol table }
    procedure type_dec(out had_generic:boolean);
      var
        rtti_attrs_def: TRTTIAttributeList;
      begin
        consume(_TYPE);
        rtti_attrs_def := nil;
        types_dec(false,had_generic,rtti_attrs_def);
        rtti_attrs_def.free;
        rtti_attrs_def := nil;
      end;


    procedure var_dec(out had_generic:boolean);
    { parses variable declarations and inserts them in }
    { the top symbol table of symtablestack         }
      begin
        consume(_VAR);
        read_var_decls([vd_check_generic],had_generic);
      end;


    procedure property_dec;
    { parses a global property (fpc mode feature) }
      var
         old_block_type: TBlockType;
      begin
         consume(_PROPERTY);
         if not(SymTableStack.top.SymTableType in [staticsymtable,GlobalSymTable]) then
           message(parser_e_property_only_sgr);
         old_block_type:=Block_Type;
         Block_Type:=bt_const;
         repeat
           read_property_dec(false, nil);
           consume(_SEMICOLON);
         until CurrentScanner.token<>_ID;
         Block_Type:=old_block_type;
      end;


    procedure threadvar_dec(out had_generic:boolean);
    { parses thread variable declarations and inserts them in }
    { the top symbol table of symtablestack                }
      begin
        consume(_THREADVAR);
        if not(SymTableStack.top.SymTableType in [staticsymtable,GlobalSymTable]) then
          message(parser_e_threadvars_only_sg);
        if f_threading in Features then
          read_var_decls([vd_threadvar,vd_check_generic],had_generic)
        else
          begin
            Message1(parser_f_unsupported_feature,FeatureStr[f_threading]);
            read_var_decls([vd_check_generic],had_generic);
          end;
      end;


    procedure resourcestring_dec(out had_generic:boolean);
      var
         orgname : TIDString;
         p : TNode;
         dummysymoptions : TSymOptions;
         DeprecatedMsg : PShortString;
         storetokenpos,filepos : TFilePosInfo;
         old_block_type : TBlockType;
         sp : pchar;
         sym : TSym;
         first,
         isgeneric : boolean;
         pw : TCompilerWideString;

      begin
         consume(_RESOURCESTRING);
         if not(SymTableStack.top.SymTableType in [staticsymtable,GlobalSymTable]) then
           message(parser_e_resourcestring_only_sg);
         first:=true;
         had_generic:=false;
         old_block_type:=Block_Type;
         Block_Type:=bt_const;
         repeat
           orgname:=CurrentScanner.orgpattern;
           filepos:=CurrentTokenPos;
           isgeneric:=not (m_delphi in CurrentSettings.ModeSwitches) and (CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_GENERIC);
           consume(_ID);
           case CurrentScanner.token of
             _EQ:
                begin
                   consume(_EQ);
                   p:=comp_expr([ef_accept_equal]);
                   storetokenpos:=CurrentTokenPos;
                   CurrentTokenPos:=filepos;
                   sym:=nil;
                   case p.nodetype of
                      ordconstn:
                        begin
                           if is_constcharnode(p) then
                             begin
                                if not Is_SystemUnit_Unicode then
                                  begin
                                  GetMem(sp,2);
                                  sp[0]:=chr(TOrdConstNode(p).Value.svalue);
                                  sp[1]:=#0;
                                  sym:=CConstSym.Create_String(orgname,constresourcestring,sp,1,nil);
                                  end
                                else
                                  begin
                                  InitWideString(pw);
                                  SetLengthWideString(pw,1);
                                  pw.data[0]:=TOrdConstNode(p).Value.svalue;
                                  sym:=CConstSym.Create_WString(orgname,constwresourcestring,pw);
                                  end;
                             end
                           else
                             Message(parser_e_illegal_expression);
                        end;
                      stringconstn:
                        with TStringConstNode(p) do
                          begin
                             if not Is_SystemUnit_Unicode  then
                               begin
                               if cst_type in [cst_widestring,cst_unicodestring] then
                                 changestringtype(GetAnsiStringDef);
                               GetMem(sp,len+1);
                               sp[len]:=#0;
                               if len>0 then
                                 move(valueas[0],sp^,len);
                               sym:=CConstSym.Create_String(orgname,constresourcestring,sp,len,nil);
                               end
                             else
                               begin
                               // For unicode rtl, resourcestrings are unicodestrings
                               if cst_type in [cst_conststring,cst_longstring, cst_shortstring,cst_ansistring] then
                                 changestringtype(CUnicodeStringType);
                               InitWideString(pw);
                               CopyWideString(ValueWS,pw);
                               sym:=CConstSym.Create_WString(orgname,constwresourcestring,pw);
                               end;
                          end;
                      else
                        Message(parser_e_illegal_expression);
                   end;
                   CurrentTokenPos:=storetokenpos;
                   { Support hint directives }
                   dummysymoptions:=[];
                   DeprecatedMsg:=nil;
                   try_consume_hintdirective(dummysymoptions,DeprecatedMsg);
                   if Assigned(sym) then
                     begin
                       sym.SymOptions:=sym.SymOptions+dummysymoptions;
                       sym.DeprecatedMsg:=DeprecatedMsg;
                       SymTableStack.top.InsertSym(sym);
                     end
                   else
                     StringDispose(DeprecatedMsg);
                   consume(_SEMICOLON);
                   p.free;
                   p := nil;
                end;
              else
                if not first and isgeneric and
                    (CurrentScanner.token in [_PROCEDURE, _FUNCTION, _CLASS]) then
                  begin
                    had_generic:=true;
                    break;
                  end
                else
                  consume(_EQ);
           end;
           first:=false;
         until CurrentScanner.token<>_ID;
         Block_Type:=old_block_type;
      end;

end.
