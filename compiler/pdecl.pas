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
      tpcompilerreal,
    { common }
      cclasses,
      { global }
      globtype,
      { symtable }
      symsym,symdef,symtype,
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
    function parse_forward_declaration(sym:TSym;gentypename,genorgtypename:tidstring;genericdef:TDef;generictypelist:tfphashobjectlist;out newtype:TTypeSym):TDef;

implementation

    uses
       SysUtils,
       { common }
       cutils,
       { global }
       globals,tokens,verbose,widestr,constexp,
       systems,aasmdata,fmodule,compinnr,
       { symtable }
       symconst,symbase,symcpu,symcreat,defutil,defcmp,symtable,symutil,
       { pass 1 }
       ninl,ncon,nobj,ngenutil,nld,nmem,ncal,pass_1,
       { parser }
       scanner,
       pbase,pexpr,ptype,ptconst,pdecsub,pdecvar,pdecobj,pgenutil,pparautl,
       procdefutil,
       { cpu-information }
       cpuinfo
       ;

    function is_system_custom_attribute_descendant(def:TDef):boolean;
    begin
      if not assigned(class_tcustomattribute) then
        class_tcustomattribute:=TObjectDef(search_system_type('TCUSTOMATTRIBUTE').typedef);
      Result:=def_is_related(def,class_tcustomattribute);
    end;

    function readconstant(const orgname:string;const filepos:TFilePosInfo; out nodetype: TNodeType):TConstSym;
      var
        hp : TConstSym;
        p : TNode;
        ps : PConstSet;
        pd : pbestreal;
        pg : pguid;
        sp : pchar;
        pw : tcompilerwidestring;
        storetokenpos : TFilePosInfo;
      begin
        readconstant:=nil;
        if orgname='' then
         internalerror(9584582);
        hp:=nil;
        p:=comp_expr([ef_accept_equal]);
        nodetype:=p.nodetype;
        storetokenpos:=CurrentTokenPos;
        CurrentTokenPos:=filepos;
        case p.nodetype of
           ordconstn:
             begin
               if p.resultdef.typ=pointerdef then
                 hp:=cconstsym.create_ordptr(orgname,constpointer,tordconstnode(p).value.uvalue,p.resultdef)
               else
                 hp:=cconstsym.create_ord(orgname,constord,tordconstnode(p).value,p.resultdef);
             end;
           stringconstn:
             begin
               if is_wide_or_unicode_string(p.resultdef) then
                 begin
                   initwidestring(pw);
                   copywidestring(tstringconstnode(p).valuews,pw);
                   hp:=cconstsym.create_wstring(orgname,constwstring,pw);
                 end
               else
                 begin
                   getmem(sp,tstringconstnode(p).len+1);
                   sp[tstringconstnode(p).len]:=#0;
                   if tstringconstnode(p).len>0 then
                     move(tstringconstnode(p).valueas[0],sp^,tstringconstnode(p).len+1);
                   { if a non-default ansistring code page has been specified,
                     keep it }
                   if is_ansistring(p.resultdef) and
                      (TStringDef(p.resultdef).encoding<>0) then
                     hp:=cconstsym.create_string(orgname,conststring,sp,tstringconstnode(p).len,p.resultdef)
                   else
                     hp:=cconstsym.create_string(orgname,conststring,sp,tstringconstnode(p).len,nil);
                 end;
             end;
           realconstn :
             begin
                new(pd);
                pd^:=trealconstnode(p).value_real;
                hp:=cconstsym.create_ptr(orgname,constreal,pd,p.resultdef);
             end;
           setconstn :
             begin
               new(ps);
               if assigned(tsetconstnode(p).value_set) then
                 ps^:=tsetconstnode(p).value_set^
               else
                 ps^:=[];
               hp:=cconstsym.create_ptr(orgname,constset,ps,p.resultdef);
             end;
           pointerconstn :
             begin
               hp:=cconstsym.create_ordptr(orgname,constpointer,tpointerconstnode(p).value,p.resultdef);
             end;
           niln :
             begin
               hp:=cconstsym.create_ord(orgname,constnil,0,p.resultdef);
             end;
           typen :
             begin
               if is_interface(p.resultdef) then
                begin
                  if assigned(TObjectDef(p.resultdef).iidguid) then
                   begin
                     new(pg);
                     pg^:=TObjectDef(p.resultdef).iidguid^;
                     hp:=cconstsym.create_ptr(orgname,constguid,pg,p.resultdef);
                   end
                  else
                   Message1(parser_e_interface_has_no_guid,TObjectDef(p.resultdef).objrealname^);
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
               case tinlinenode(p).inlinenumber of
                 in_sizeof_x:
                   begin
                     hp:=cconstsym.create_ord(orgname,constord,1,p.resultdef);
                   end;
                 in_bitsizeof_x:
                   begin
                     hp:=cconstsym.create_ord(orgname,constord,8,p.resultdef);
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
                 hp:=cconstsym.create_ord(orgname,constnil,0,p.resultdef)
               else
                 Message(parser_e_illegal_expression);
             end;
        end;
        { transfer generic param flag from node to symbol }
        if nf_generic_para in p.flags then
          begin
            include(hp.symoptions,sp_generic_const);
            include(hp.symoptions,sp_generic_para);
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
         flags : thccflags;
         dummysymoptions : TSymOptions;
         deprecatedmsg : pshortstring;
         storetokenpos,filepos : TFilePosInfo;
         nodetype : TNodeType;
         old_block_type : TBlockType;
         first,
         isgeneric,
         expect_directive,
         skip_initialiser : boolean;
         varspez : TVarSpez;
         asmtype : tasmlisttype;
      begin
         old_block_type:=block_type;
         block_type:=bt_const;
         had_generic:=false;
         first:=true;
         repeat
           orgname:=CurrentScanner.orgpattern;
           filepos:=CurrentTokenPos;
           isgeneric:=not (m_delphi in CurrentSettings.modeswitches) and (CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_GENERIC);
           consume(_ID);
           case CurrentScanner.token of

             _EQ:
                begin
                   consume(_EQ);
                   sym:=readconstant(orgname,filepos,nodetype);
                   { Support hint directives }
                   dummysymoptions:=[];
                   deprecatedmsg:=nil;
                   try_consume_hintdirective(dummysymoptions,deprecatedmsg);
                   if assigned(sym) then
                     begin
                       sym.symoptions:=sym.symoptions+dummysymoptions;
                       sym.deprecatedmsg:=deprecatedmsg;
                       sym.visibility:=symtablestack.top.currentvisibility;
                       symtablestack.top.insertsym(sym);
                       sym.RegisterSym;
                     end
                   else
                     stringdispose(deprecatedmsg);
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
                   block_type:=bt_const_type;
                   consume(_COLON);
                   read_anon_type(hdef,false,nil);
                   block_type:=bt_const;
                   { create symbol }
                   storetokenpos:=CurrentTokenPos;
                   CurrentTokenPos:=filepos;
                   if not (cs_typed_const_writable in CurrentSettings.localswitches) then
                     begin
                       varspez:=vs_const;
                       asmtype:=al_rotypedconsts;
                     end
                   else
                     begin
                       varspez:=vs_value;
                       asmtype:=al_typedconsts;
                     end;
                   { if we are dealing with structure const then we need to handle it as a
                     structure static variable: create a symbol in unit symtable and a reference
                     to it from the structure or linking will fail }
                   if symtablestack.top.symtabletype in [recordsymtable,ObjectSymtable] then
                     begin
                       { note: we keep hdef so that we might at least read the
                               constant data correctly for error recovery }
                       check_allowed_for_var_or_const(hdef,false);
                       sym:=cfieldvarsym.create(orgname,varspez,hdef,[]);
                       symtablestack.top.insertsym(sym);
                       sym:=make_field_static(symtablestack.top,TFieldVarSym(sym));
                     end
                   else
                     begin
                       sym:=cstaticvarsym.create(orgname,varspez,hdef,[]);
                       sym.visibility:=symtablestack.top.currentvisibility;
                       symtablestack.top.insertsym(sym);
                     end;
                   sym.RegisterSym;
                   CurrentTokenPos:=storetokenpos;
                   skip_initialiser:=false;
                   { Anonymous proctype definitions can have proc directives }
                   if (
                         (hdef.typ=procvardef) or
                         is_funcref(hdef)
                       ) and
                       (hdef.typesym=nil) then
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
                 ((m_final_fields in CurrentSettings.modeswitches) and
                  (CurrentScanner.idtoken=_FINAL))));
         block_type:=old_block_type;
      end;


    procedure label_dec;
      var
        labelsym : TLabelSym;
      begin
         consume(_LABEL);
         if not(cs_support_goto in CurrentSettings.moduleswitches) then
           Message(sym_e_goto_and_label_not_supported);
         repeat
           if not(CurrentScanner.token in [_ID,_INTCONST]) then
             consume(_ID)
           else
             begin
                if CurrentScanner.token=_ID then
                  labelsym:=clabelsym.create(CurrentScanner.orgpattern)
                else
                  begin
                    { strip leading 0's in iso mode }
                    if (([m_iso,m_extpas]*CurrentSettings.modeswitches)<>[]) then
                      while (length(CurrentScanner.pattern)>1) and (CurrentScanner.pattern[1]='0') do
                        delete(CurrentScanner.pattern,1,1);
                    labelsym:=clabelsym.create(CurrentScanner.pattern);
                  end;

                symtablestack.top.insertsym(labelsym);
                if m_non_local_goto in CurrentSettings.modeswitches then
                  begin
                    if symtablestack.top.symtabletype=localsymtable then
                      begin
                        labelsym.jumpbuf:=clocalvarsym.create('LABEL$_'+labelsym.name,vs_value,rec_jmp_buf,[]);
                        symtablestack.top.insertsym(labelsym.jumpbuf);
                      end
                    else
                      begin
                        labelsym.jumpbuf:=cstaticvarsym.create('LABEL$_'+labelsym.name,vs_value,rec_jmp_buf,[]);
                        symtablestack.top.insertsym(labelsym.jumpbuf);
                        cnodeutils.insertbssdata(TStaticVarSym(labelsym.jumpbuf));
                      end;
                    include(labelsym.jumpbuf.symoptions,sp_internal);
                    { the buffer will be setup later, but avoid a hint }
                    TAbstractVarSym(labelsym.jumpbuf).varstate:=vs_written;
                  end;
                consume(CurrentScanner.token);
             end;
           if CurrentScanner.token<>_SEMICOLON then consume(_COMMA);
         until not(CurrentScanner.token in [_ID,_INTCONST]);
         consume(_SEMICOLON);
      end;

    function find_create_constructor(objdef:TObjectDef):tsymentry;
      begin
         while assigned(objdef) do
           begin
             result:=objdef.symtable.Find('CREATE');
             if assigned(result) then
               exit;
             objdef:=objdef.childof;
           end;
         // A class without a constructor called 'create'?!?
         internalerror(2012111101);
      end;

    procedure parse_rttiattributes(var rtti_attrs_def:TRTTIAttributeList);

      function read_attr_paras:TNode;
        var
          old_block_type : TBlockType;
        begin
          if try_to_consume(_LKLAMMER) then
            begin
              { we only want constants here }
              old_block_type:=block_type;
              block_type:=bt_const;
              result:=parse_paras(false,false,_RKLAMMER);
              block_type:=old_block_type;
              consume(_RKLAMMER);
            end
          else
            result:=nil;
        end;

      var
        p,paran,pcalln,ptmp : TNode;
        ecnt : longint;
        i,pcount : sizeint;
        paras : array of TNode;
        od : TObjectDef;
        constrsym : tsymentry;
        typesym : TTypeSym;
        parasok : boolean;
      begin
        consume(_LECKKLAMMER);

        repeat
          { Parse attribute type }
          p:=factor(false,[ef_type_only,ef_check_attr_suffix]);
          if p.nodetype=typen then
            begin
              typesym:=TTypeSym(ttypenode(p).typesym);
              od:=TObjectDef(ttypenode(p).typedef);

              { Check if the attribute class is related to TCustomAttribute }
              if not is_system_custom_attribute_descendant(od) then
                begin
                  incompatibletypes(od,class_tcustomattribute);
                  read_attr_paras.free; // no nil needed
                  continue;
                end;

              paran:=read_attr_paras;

              { Search the tprocdef of the constructor which has to be called. }
              constrsym:=find_create_constructor(od);
              if constrsym.typ<>procsym then
                internalerror(2018102301);

              pcalln:=ccallnode.create(paran,TProcSym(constrsym),od.symtable,cloadvmtaddrnode.create(p),[cnf_no_convert_procvar],nil);
              p:=nil;
              ecnt:=errorcount;
              TypeCheckPass(pcalln);

              if (pcalln.nodetype=calln) and assigned(tcallnode(pcalln).procdefinition) and not CodeGenError then
                begin
                  { TODO: once extended RTTI for methods is supported, reject a
                          constructor if it doesn't have extended RTTI enabled }

                  { collect the parameters of the call node as there might be
                    compile time type conversions (e.g. a Byte parameter being
                    passed a value > 255) }
                  paran:=tcallnode(pcalln).left;

                  { only count visible parameters (thankfully open arrays are not
                    supported, otherwise we'd need to handle those as well) }
                  parasok:=true;
                  paras:=nil;
                  if assigned(paran) then
                    begin
                      ptmp:=paran;
                      pcount:=0;
                      while assigned(ptmp) do
                        begin
                          if not (vo_is_hidden_para in tcallparanode(ptmp).parasym.varoptions) then
                            inc(pcount);
                          ptmp:=tcallparanode(ptmp).right;
                        end;
                      setlength(paras,pcount);
                      ptmp:=paran;
                      pcount:=0;
                      while assigned(ptmp) do
                        begin
                          if not (vo_is_hidden_para in tcallparanode(ptmp).parasym.varoptions) then
                            begin
                              if not is_constnode(tcallparanode(ptmp).left) then
                                begin
                                  parasok:=false;
                                  messagepos(tcallparanode(ptmp).left.fileinfo,type_e_constant_expr_expected);
                                end;
                              paras[high(paras)-pcount]:=tcallparanode(ptmp).left.getcopy;
                              inc(pcount);
                            end;
                          ptmp:=tcallparanode(ptmp).right;
                        end;
                    end;

                  if parasok then
                    begin
                      { Add attribute to attribute list which will be added
                        to the property which is defined next. }
                      if not assigned(rtti_attrs_def) then
                        rtti_attrs_def:=TRTTIAttributeList.create;
                      rtti_attrs_def.addattribute(typesym,tcallnode(pcalln).procdefinition,pcalln,paras);
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
                if errorcount=ecnt then
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


    function parse_forward_declaration(sym:TSym;gentypename,genorgtypename:tidstring;genericdef:TDef;generictypelist:tfphashobjectlist;out newtype:TTypeSym):TDef;
      var
        wasforward : boolean;
        objecttype : TObjectTyp;
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
           (assigned(TTypeSym(sym).typedef)) and
           is_implicit_pointer_object_type(TTypeSym(sym).typedef) and
           (oo_is_forward in TObjectDef(TTypeSym(sym).typedef).objectoptions) then
         begin
           wasforward:=true;
           objecttype:=odt_none;
           case CurrentScanner.token of
             _CLASS :
               objecttype:=default_class_type;
             _INTERFACE :
               case CurrentSettings.interfacetype of
                 it_interfacecom:
                   objecttype:=odt_interfacecom;
                 it_interfacecorba:
                   objecttype:=odt_interfacecorba;
                 it_interfacejava:
                   objecttype:=odt_interfacejava;
               end;
             _DISPINTERFACE :
               objecttype:=odt_dispinterface;
             _OBJCCLASS,
             _OBJCCATEGORY :
               objecttype:=odt_objcclass;
             _OBJCPROTOCOL :
               objecttype:=odt_objcprotocol;
             else
               internalerror(200811072);
           end;
           consume(CurrentScanner.token);
           if assigned(genericdef) then
             gendef:=TStoredDef(genericdef)
           else
             { determine the generic def in case we are in a nested type
               of a specialization }
             gendef:=determine_generic_def(gentypename);
           { we can ignore the result, the definition is modified }
           object_dec(objecttype,genorgtypename,newtype,gendef,generictypelist,TObjectDef(TTypeSym(sym).typedef),ht_none);
           if wasforward and
             (TObjectDef(TTypeSym(sym).typedef).objecttype<>objecttype) then
             Message1(type_e_forward_interface_type_does_not_match,TObjectDef(TTypeSym(sym).typedef).GetTypeName);
           newtype:=TTypeSym(sym);
           result:=newtype.typedef;
         end
        else
          begin
            message1(parser_h_type_redef,genorgtypename);
            result:=generrordef;
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
        i, firstcamelend: longint;
        inferresult: boolean;
      begin
        if TDef(def).typ<>procdef then
          exit;
        pd:=TProcDef(def);
        if not(po_msgstr in pd.procoptions) then
          internalerror(2019082401);
        firstcamelend:=length(pd.messageinf.str^);
        for i:=1 to length(pd.messageinf.str^) do
          if pd.messageinf.str^[i] in ['A'..'Z'] then
            begin
              firstcamelend:=pred(i);
              break;
            end;
        case copy(pd.messageinf.str^,1,firstcamelend) of
          'alloc',
          'new':
             inferresult:=po_classmethod in pd.procoptions;
          'autorelease',
          'init',
          'retain',
          'self':
             inferresult:=not(po_classmethod in pd.procoptions);
          else
            inferresult:=false;
        end;
        if inferresult and
           def_is_related(TDef(pd.procsym.owner.defowner),pd.returndef) then
          include(pd.procoptions,po_objc_related_result_type);
      end;

    procedure types_dec(in_structure: boolean;out had_generic:boolean;var rtti_attrs_def: TRTTIAttributeList);

      procedure finalize_class_external_status(od: TObjectDef);
        begin
          if  [oo_is_external,oo_is_forward] <= od.objectoptions then
            begin
              { formal definition: x = objcclass external; }
              exclude(od.objectoptions,oo_is_forward);
              include(od.objectoptions,oo_is_formal);
            end;
        end;

      var
         typename,orgtypename,
         gentypename,genorgtypename : TIDString;
         newtype  : TTypeSym;
         dummysym,
         sym      : TSym;
         hdef,
         hdef2    : TDef;
         defpos,storetokenpos : TFilePosInfo;
         old_block_type : TBlockType;
         old_checkforwarddefs: TFPObjectList;
         flags : thccflags;
         setdummysym,
         first,
         isgeneric,
         isunique,
         istyperenaming : boolean;
         generictypelist : tfphashobjectlist;
         localgenerictokenbuf : tdynamicarray;
         p:TNode;
         gendef : TStoredDef;
         s : shortstring;
         i : longint;
{$ifdef x86}
         segment_register: string;
{$endif x86}
      begin
         old_block_type:=block_type;
         { save unit container of forward declarations -
           we can be inside nested class type block }
         old_checkforwarddefs:=CurrentModule.checkforwarddefs;
         CurrentModule.checkforwarddefs:=TFPObjectList.Create(false);
         block_type:=bt_type;
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
           if m_prefixed_attributes in CurrentSettings.modeswitches then
             while CurrentScanner.token=_LECKKLAMMER do
               parse_rttiattributes(rtti_attrs_def);

           { fpc generic declaration? }
           if first then
             had_generic:=not(m_delphi in CurrentSettings.modeswitches) and try_to_consume(_GENERIC);
           isgeneric:=had_generic;

           typename:=CurrentScanner.pattern;
           orgtypename:=CurrentScanner.orgpattern;
           consume(_ID);

           { delphi generic declaration? }
           if (m_delphi in CurrentSettings.modeswitches) then
             isgeneric:=CurrentScanner.token=_LSHARPBRACKET;

           { Generic type declaration? }
           if isgeneric then
             begin
               if assigned(CurrentGenericDef) then
                 Message(parser_f_no_generic_inside_generic);

               consume(_LSHARPBRACKET);
               generictypelist:=parse_generic_parameters(true);
               consume(_RSHARPBRACKET);

               str(generictypelist.Count,s);
               gentypename:=typename+'$'+s;
               genorgtypename:=orgtypename+'$'+s;
             end
           else
             begin
               gentypename:=typename;
               genorgtypename:=orgtypename;
             end;

           consume(_EQ);

           { support 'ttype=type word' syntax }
           isunique:=try_to_consume(_TYPE);

           { MacPas object model is more like Delphi's than like TP's, but }
           { uses the object keyword instead of class                      }
           if (m_mac in CurrentSettings.modeswitches) and
              (CurrentScanner.token = _OBJECT) then
             CurrentScanner.token := _CLASS;

           { Start recording a generic template }
           if assigned(generictypelist) then
             begin
               localgenerictokenbuf:=tdynamicarray.create(256);
               CurrentScanner.startrecordtokens(localgenerictokenbuf);
             end;

           { is the type already defined? -- must be in the current symtable,
             not in a nested symtable or one higher up the stack -> don't
             use searchsym & friends! }
           sym:=TSym(symtablestack.top.find(gentypename));
           newtype:=nil;
           { found a symbol with this name? }
           if assigned(sym) then
            begin
              if (sym.typ=typesym) and
                 { this should not be a symbol that was created by a generic
                   that was declared earlier }
                 not (
                   (TTypeSym(sym).typedef.typ=undefineddef) and
                   (sp_generic_dummy in sym.symoptions)
                 ) then
               begin
                 hdef:=parse_forward_declaration(sym,gentypename,genorgtypename,nil,generictypelist,newtype);
               end;
            end;
           { no old type reused ? Then insert this new type }
           if not assigned(newtype) then
            begin
              if isgeneric then
                begin
                  { we are not freeing the type parameters, so register them }
                  for i:=0 to generictypelist.count-1 do
                    begin
                       TStoredSym(generictypelist[i]).RegisterSym;
                       if TStoredSym(generictypelist[i]).typ=typesym then
                         TStoredDef(TTypeSym(generictypelist[i]).typedef).RegisterDef;
                    end;
                end;

              { insert the new type first with an errordef, so that
                referencing the type before it's really set it
                will give an error (PFV) }
              hdef:=generrordef;
              gendef:=nil;
              storetokenpos:=CurrentTokenPos;
              if isgeneric then
                begin
                  { for generics we need to check whether a non-generic type
                    already exists and if not we need to insert a symbol with
                    the non-generic name (available in (org)typename) that is a
                    undefineddef, so that inline specializations can be used }
                  sym:=TSym(symtablestack.top.Find(typename));
                  if not assigned(sym) then
                    begin
                      sym:=ctypesym.create(orgtypename,cundefineddef.create(true));
                      Include(sym.symoptions,sp_generic_dummy);
                      TTypeSym(sym).typedef.typesym:=sym;
                      sym.visibility:=symtablestack.top.currentvisibility;
                      { add as dummy symbol before adding it to the symtable stack }
                      add_generic_dummysym(sym,typename);
                      symtablestack.top.insertsym(sym);
                      TTypeSym(sym).typedef.owner:=sym.owner;
                    end
                  else
                    { this is not allowed in non-Delphi modes }
                    if not (m_delphi in CurrentSettings.modeswitches) then
                      Message1(sym_e_duplicate_id,genorgtypename)
                    else
                      begin
                        { we need to find this symbol even if it's a variable or
                          something else when doing an inline specialization }
                        Include(sym.symoptions,sp_generic_dummy);
                        add_generic_dummysym(sym,'');
                      end;
                end
              else
                begin
                  if assigned(sym) and (sym.typ=typesym) and
                      (TTypeSym(sym).typedef.typ=undefineddef) and
                      (sp_generic_dummy in sym.symoptions) then
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
              if not assigned(newtype) then
                begin
                  newtype:=ctypesym.create(genorgtypename,hdef);
                  newtype.visibility:=symtablestack.top.currentvisibility;
                  symtablestack.top.insertsym(newtype);
                end;
              CurrentTokenPos:=defpos;
              CurrentTokenPos:=storetokenpos;
              { read the type definition }
              read_named_type(hdef,newtype,gendef,generictypelist,false,isunique);
              { update the definition of the type }
              if assigned(hdef) then
                begin
                  if assigned(hdef.typesym) then
                    begin
                      istyperenaming:=true;
                      include(newtype.symoptions,sp_explicitrename);
                    end;
                  if isunique then
                    begin
                      if is_objc_class_or_protocol(hdef) or
                         is_java_class_or_interface(hdef) then
                        Message(parser_e_unique_unsupported);

                      if is_object(hdef) or
                         is_class_or_interface_or_dispinterface(hdef) then
                        begin
                          { just create a copy that is a child of the original class class type; this is
                            Delphi-compatible }
                          hdef2:=TStoredDef(hdef).getcopy;
                          TObjectDef(hdef2).childof:=TObjectDef(hdef);
                          TStoredDef(hdef2).orgdef:=TStoredDef(hdef);
                          hdef:=hdef2;
                        end
                      else
                        begin
                          hdef2:=TStoredDef(hdef).getcopy;
                          TStoredDef(hdef2).orgdef:=TStoredDef(hdef);
                          hdef:=hdef2;
                          { check if it is an ansistring(codepage) declaration }
                          if is_ansistring(hdef) and try_to_consume(_LKLAMMER) then
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
                                  if (tordconstnode(p).value<0) or (tordconstnode(p).value>65535) then
                                    begin
                                      Message(parser_e_invalid_codepage);
                                      tordconstnode(p).value:=0;
                                    end;
                                  TStringDef(hdef).encoding:=int64(tordconstnode(p).value);
                                end;
                              p.free;
                              p := nil;
                            end;
                          if (hdef.typ in [pointerdef,classrefdef]) and
                             (TAbstractPointerDef(hdef).pointeddef.typ=forwarddef) then
                            CurrentModule.checkforwarddefs.add(hdef);
                        end;

                      include(hdef.defoptions,df_unique);

                      { update object's real name for better error messages }
                      if hdef is TAbstractRecordDef then
                        TAbstractRecordDef(hdef).setobjrealname(newtype.RealName);
                    end;
                  if not assigned(hdef.typesym) then
                    begin
                      hdef.typesym:=newtype;
                      if sp_generic_dummy in newtype.symoptions then
                        add_generic_dummysym(newtype,'');
                    end;
                end;
              { in non-Delphi modes we need a reference to the generic def
                without the generic suffix, so it can be found easily when
                parsing method implementations }
              if isgeneric and assigned(sym) and
                  not (m_delphi in CurrentSettings.modeswitches) and
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
                    not (po_is_function_ref in TAbstractProcDef(hdef).procoptions)
                  ) then
                hdef.RegisterDef;
              { KAZ: handle TGUID declaration in system unit }
              if (cs_compilesystem in CurrentSettings.moduleswitches) and
                 assigned(hdef) and
                 (hdef.typ=recorddef) then
                begin
                  if not assigned(rec_tguid) and
                     (gentypename='TGUID') and
                     (hdef.size=16) then
                    rec_tguid:=TRecordDef(hdef)
                  else if not assigned(rec_jmp_buf) and
                     (gentypename='JMP_BUF') then
                    rec_jmp_buf:=TRecordDef(hdef)
                  else if not assigned(rec_exceptaddr) and
                     (gentypename='TEXCEPTADDR') then
                    rec_exceptaddr:=TRecordDef(hdef);
                end;
            end;
           if assigned(hdef) then
            begin
              case hdef.typ of
                pointerdef :
                  begin
                    try_consume_hintdirective(newtype.symoptions,newtype.deprecatedmsg);
                    consume(_SEMICOLON);
{$ifdef x86}

  {$if defined(i386)}
                    if try_to_consume(_FAR) then
                     begin
                       tcpupointerdef(hdef).x86pointertyp:=x86pt_near_fs;
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
                               'CS': tcpupointerdef(hdef).x86pointertyp:=x86pt_near_cs;
                               'DS': tcpupointerdef(hdef).x86pointertyp:=x86pt_near_ds;
                               'SS': tcpupointerdef(hdef).x86pointertyp:=x86pt_near_ss;
                               'ES': tcpupointerdef(hdef).x86pointertyp:=x86pt_near_es;
                               'FS': tcpupointerdef(hdef).x86pointertyp:=x86pt_near_fs;
                               'GS': tcpupointerdef(hdef).x86pointertyp:=x86pt_near_gs;
                               else
                                 Message(asmr_e_invalid_register);
                             end;
                           end
                         else
                           tcpupointerdef(hdef).x86pointertyp:=x86pt_near;
                         consume(_SEMICOLON);
                       end;
{$endif x86}
                  end;
                procvardef :
                  begin
                    { in case of type renaming, don't parse proc directives }
                    if istyperenaming then
                      begin
                        try_consume_hintdirective(newtype.symoptions,newtype.deprecatedmsg);
                        consume(_SEMICOLON);
                      end
                    else
                     begin
                       if not check_proc_directive(true) then
                         begin
                           try_consume_hintdirective(newtype.symoptions,newtype.deprecatedmsg);
                           consume(_SEMICOLON);
                         end;
                       parse_proctype_directives(TProcVarDef(hdef));
                       if po_is_function_ref in TProcVarDef(hdef).procoptions then
                         begin
                           if not (m_function_references in CurrentSettings.modeswitches) and
                               not (po_is_block in TProcVarDef(hdef).procoptions) then
                             messagepos(storetokenpos,sym_e_error_in_type_def)
                           else
                             begin
                               if setdummysym then
                                 dummysym:=sym
                               else
                                 dummysym:=nil;
                               adjust_funcref(hdef,newtype,dummysym);
                             end;
                           if CurrentScanner.replay_stack_depth=0 then
                             hdef.RegisterDef;
                         end;
                       if hdef.typ=procvardef then
                         flags:=hcc_default_actions_intf
                       else
                         flags:=hcc_default_actions_intf_struct;
                       handle_calling_convention(hdef,flags);
                       if (hdef.typ=procvardef) and (po_is_function_ref in TProcVarDef(hdef).procoptions) then
                         begin
                           if (po_is_block in TProcVarDef(hdef).procoptions) and
                              not (TProcVarDef(hdef).proccalloption in [pocall_cdecl,pocall_mwpascal]) then
                             message(type_e_cblock_callconv);
                         end;
                       if try_consume_hintdirective(newtype.symoptions,newtype.deprecatedmsg) then
                         consume(_SEMICOLON);
                     end;
                  end;
                objectdef :
                  begin
                    if is_funcref(hdef) then
                      begin
                        if not check_proc_directive(true) then
                          begin
                            try_consume_hintdirective(newtype.symoptions,newtype.deprecatedmsg);
                            consume(_SEMICOLON);
                          end;
                        parse_proctype_directives(hdef);
                        if try_consume_hintdirective(newtype.symoptions,newtype.deprecatedmsg) then
                          consume(_SEMICOLON);
                      end
                    else
                      begin
                        try_consume_hintdirective(newtype.symoptions,newtype.deprecatedmsg);
                        consume(_SEMICOLON);
                      end;

                    { change a forward and external class declaration into
                      formal external definition, so the compiler does not
                      expect an real definition later }
                    if is_objc_class_or_protocol(hdef) or
                       is_java_class_or_interface(hdef) then
                      finalize_class_external_status(TObjectDef(hdef));

                    { Build VMT indexes, skip for type renaming and forward classes }
                    if not istyperenaming and
                       not(oo_is_forward in TObjectDef(hdef).objectoptions) then
                      if not (oo_inherits_not_specialized in TObjectDef(hdef).objectoptions) then
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
                    if is_objc_class_or_protocol(hdef) and
                       (not is_objccategory(hdef) or
                        assigned(TObjectDef(hdef).childof)) then
                      begin
                        TObjectDef(hdef).finish_objc_data;
                        TObjectDef(hdef).symtable.DefList.ForEachCall(@pd_set_objc_related_result,nil);
                      end;

                    if is_cppclass(hdef) then
                      TObjectDef(hdef).finish_cpp_data;
                  end;
                recorddef :
                  begin
                    try_consume_hintdirective(newtype.symoptions,newtype.deprecatedmsg);
                    consume(_SEMICOLON);
                  end;
                else
                  begin
                    try_consume_hintdirective(newtype.symoptions,newtype.deprecatedmsg);
                    consume(_SEMICOLON);
                  end;
              end;

              { if we have a real type definition or a unique type we may bind
                attributes to this def }
              if not istyperenaming or isunique then
                TRTTIAttributeList.bind(rtti_attrs_def,TStoredDef(hdef).RTTIAttributeList);

              if df_generic in hdef.defoptions then
                { flag parent symtables that they now contain a generic }
                hdef.owner.includeoption(sto_has_generic);
            end;

           if isgeneric and (not(hdef.typ in [objectdef,recorddef,arraydef,procvardef])
               or is_objectpascal_helper(hdef)) then
             begin
               newtype.typedef:=generrordef;
               message(parser_e_cant_create_generics_of_this_type);
             end;

           { Stop recording a generic template }
           if assigned(generictypelist) then
             begin
               CurrentScanner.stoprecordtokens;
               TStoredDef(hdef).generictokenbuf:=localgenerictokenbuf;
               { Generic is never a type renaming }
               hdef.typesym:=newtype;
               { reusing a forward declared type also reuses the type parameters,
                 so free them if they haven't been used }
               for i:=0 to generictypelist.count-1 do
                 begin
                   if (TStoredSym(generictypelist[i]).typ=typesym) and
                       not TTypeSym(generictypelist[i]).typedef.IsRegistered then
                     FreeAndNil(TTypeSym(generictypelist[i]).typedef);
                   if not TStoredSym(generictypelist[i]).IsRegistered then
                     TStoredSym(generictypelist[i]).free; // no nil needed
                 end;
               generictypelist.free;
               generictypelist := nil;
             end;

           if not (m_delphi in CurrentSettings.modeswitches) and
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
           if assigned(rtti_attrs_def) and (rtti_attrs_def.GetAttributeCount>0) then
             Message1(parser_e_unbound_attribute,TRTTIAttribute(rtti_attrs_def.RTTIAttributes[0]).typesym.prettyname);

 {$ifdef DEBUG_NODE_XML}
          if Assigned(hdef) then
            hdef.XMLPrintDef(newtype);
 {$endif DEBUG_NODE_XML}

         until ((CurrentScanner.token<>_ID) and (CurrentScanner.token<>_LECKKLAMMER)) or
               (in_structure and
                ((CurrentScanner.idtoken in [_PRIVATE,_PROTECTED,_PUBLIC,_PUBLISHED,_STRICT]) or
                 ((m_final_fields in CurrentSettings.modeswitches) and
                  (CurrentScanner.idtoken=_FINAL))));
         { resolve type block forward declarations and restore a unit
           container for them }
         resolve_forward_types;
         CurrentModule.checkforwarddefs.free;
         CurrentModule.checkforwarddefs:=old_checkforwarddefs;
         block_type:=old_block_type;
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
         if not(symtablestack.top.symtabletype in [staticsymtable,globalsymtable]) then
           message(parser_e_property_only_sgr);
         old_block_type:=block_type;
         block_type:=bt_const;
         repeat
           read_property_dec(false, nil);
           consume(_SEMICOLON);
         until CurrentScanner.token<>_ID;
         block_type:=old_block_type;
      end;


    procedure threadvar_dec(out had_generic:boolean);
    { parses thread variable declarations and inserts them in }
    { the top symbol table of symtablestack                }
      begin
        consume(_THREADVAR);
        if not(symtablestack.top.symtabletype in [staticsymtable,globalsymtable]) then
          message(parser_e_threadvars_only_sg);
        if f_threading in features then
          read_var_decls([vd_threadvar,vd_check_generic],had_generic)
        else
          begin
            Message1(parser_f_unsupported_feature,featurestr[f_threading]);
            read_var_decls([vd_check_generic],had_generic);
          end;
      end;


    procedure resourcestring_dec(out had_generic:boolean);
      var
         orgname : TIDString;
         p : TNode;
         dummysymoptions : TSymOptions;
         deprecatedmsg : pshortstring;
         storetokenpos,filepos : TFilePosInfo;
         old_block_type : TBlockType;
         sp : pchar;
         sym : TSym;
         first,
         isgeneric : boolean;
         pw : tcompilerwidestring;

      begin
         consume(_RESOURCESTRING);
         if not(symtablestack.top.symtabletype in [staticsymtable,globalsymtable]) then
           message(parser_e_resourcestring_only_sg);
         first:=true;
         had_generic:=false;
         old_block_type:=block_type;
         block_type:=bt_const;
         repeat
           orgname:=CurrentScanner.orgpattern;
           filepos:=CurrentTokenPos;
           isgeneric:=not (m_delphi in CurrentSettings.modeswitches) and (CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_GENERIC);
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
                                if not is_systemunit_unicode then
                                  begin
                                  getmem(sp,2);
                                  sp[0]:=chr(tordconstnode(p).value.svalue);
                                  sp[1]:=#0;
                                  sym:=cconstsym.create_string(orgname,constresourcestring,sp,1,nil);
                                  end
                                else
                                  begin
                                  initwidestring(pw);
                                  setlengthwidestring(pw,1);
                                  pw.data[0]:=tordconstnode(p).value.svalue;
                                  sym:=cconstsym.create_wstring(orgname,constwresourcestring,pw);
                                  end;
                             end
                           else
                             Message(parser_e_illegal_expression);
                        end;
                      stringconstn:
                        with Tstringconstnode(p) do
                          begin
                             if not is_systemunit_unicode  then
                               begin
                               if cst_type in [cst_widestring,cst_unicodestring] then
                                 changestringtype(getansistringdef);
                               getmem(sp,len+1);
                               sp[len]:=#0;
                               if len>0 then
                                 move(valueas[0],sp^,len);
                               sym:=cconstsym.create_string(orgname,constresourcestring,sp,len,nil);
                               end
                             else
                               begin
                               // For unicode rtl, resourcestrings are unicodestrings
                               if cst_type in [cst_conststring,cst_longstring, cst_shortstring,cst_ansistring] then
                                 changestringtype(cunicodestringtype);
                               initwidestring(pw);
                               copywidestring(valuews,pw);
                               sym:=cconstsym.create_wstring(orgname,constwresourcestring,pw);
                               end;
                          end;
                      else
                        Message(parser_e_illegal_expression);
                   end;
                   CurrentTokenPos:=storetokenpos;
                   { Support hint directives }
                   dummysymoptions:=[];
                   deprecatedmsg:=nil;
                   try_consume_hintdirective(dummysymoptions,deprecatedmsg);
                   if assigned(sym) then
                     begin
                       sym.symoptions:=sym.symoptions+dummysymoptions;
                       sym.deprecatedmsg:=deprecatedmsg;
                       symtablestack.top.insertsym(sym);
                     end
                   else
                     stringdispose(deprecatedmsg);
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
         block_type:=old_block_type;
      end;

end.
