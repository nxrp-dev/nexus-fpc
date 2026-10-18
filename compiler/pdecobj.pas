{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Does object types for Free Pascal

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
unit pdecobj;

{$i fpcdefs.inc}

interface

    uses
      CClasses,
      GlobType,symconst,symtype,symdef;

    { parses a object declaration }
    function object_dec(ObjectType:TObjectTyp;const n:TIDString;objsym:TSym;GenericDef:TStoredDef;genericlist:TFPHashObjectList;fd : TObjectDef;HelperType:THelperType) : TObjectDef;

    { parses a (class) method declaration }
    function method_dec(astruct: TAbstractRecordDef; is_classdef: boolean;hadgeneric:boolean): TProcDef;

    function class_constructor_head(astruct: TAbstractRecordDef):TProcDef;
    function class_destructor_head(astruct: TAbstractRecordDef):TProcDef;
    function constructor_head:TProcDef;
    function destructor_head:TProcDef;
    procedure struct_property_dec(is_classproperty:boolean;var rtti_attrs_def: TRTTIAttributeList);

implementation

    uses
      SysUtils,CUtils,
      Globals,Verbose,Systems,tokens,
      SymBase,SymSym,SymTable,symcreat,defcmp,
      node,ncon,
      FModule,Scanner,
      pbase,pexpr,pdecsub,pdecvar,ptype,pdecl,pgenutil,pparautl,PPU
      ;

    const
      { Please leave this here, this module should NOT use
        these variables.
        Declaring it as string here results in an error when compiling (PFV) }
      CurrentProcInfo = 'error';

    var
      current_objectdef : TObjectDef absolute CurrentStructDef;


    procedure constr_destr_finish_head(pd: TProcDef; const astruct: TAbstractRecordDef);
      begin
        case astruct.typ of
          recorddef:
            begin
              parse_record_proc_directives(pd);
            end;
          objectdef:
            begin
              parse_object_proc_directives(pd);
            end
          else
            InternalError(2011040502);
        end;
        // We can't add hidden params here because record is not yet defined
        // and therefore record size which has influence on parameter passing rules may change too
        // look at record_dec to see where calling conventions are applied (issue #0021044).
        // The same goes for objects/classes due to the calling convention that may only be set
        // later (mantis #35233).
        handle_calling_convention(pd,hcc_default_actions_intf_struct);

        { add definition to procsym }
        proc_add_definition(pd);

        { add procdef options to objectdef options }
        if (po_virtualmethod in pd.ProcOptions) then
          include(astruct.ObjectOptions,oo_has_virtual);

        maybe_parse_hint_directives(pd);
      end;


    function class_constructor_head(astruct: TAbstractRecordDef):TProcDef;
      var
        pd : TProcDef;
      begin
        result:=nil;
        consume(_CONSTRUCTOR);
        { must be at same level as in implementation }
        parse_proc_head(CurrentStructDef,potype_class_constructor,[],nil,nil,pd);
        if not Assigned(pd) then
          begin
            consume(_SEMICOLON);
            exit;
          end;
        pd.CalcParas;
        if (pd.MaxParaCount>0) then
          Message(parser_e_no_paras_for_class_constructor);
        consume(_SEMICOLON);
        include(astruct.ObjectOptions,oo_has_class_constructor);
        include(CurrentModule.ModuleFlags,mf_classinits);
        { no return value }
        pd.ReturnDef:=VoidType;
        constr_destr_finish_head(pd,astruct);
        result:=pd;
      end;

    function constructor_head:TProcDef;
      var
        pd : TProcDef;
      begin
        result:=nil;
        consume(_CONSTRUCTOR);
        { must be at same level as in implementation }
        parse_proc_head(CurrentStructDef,potype_constructor,[],nil,nil,pd);
        if not Assigned(pd) then
          begin
            consume(_SEMICOLON);
            exit;
          end;
        consume(_SEMICOLON);
        include(CurrentStructDef.ObjectOptions,oo_has_constructor);
        { Set return type, class and record constructors return the
          created instance, helper types return the extended type,
          object constructors return boolean }
        if Is_Class(pd.struct) or
           Is_Record(pd.struct) then
          pd.ReturnDef:=pd.struct
        else
          if Is_ObjectPascal_Helper(pd.struct) then
            pd.ReturnDef:=TObjectDef(pd.struct).ExtendedDef
          else
{$ifdef CPU64bitaddr}
            pd.ReturnDef:=Bool64Type;
{$else CPU64bitaddr}
            pd.ReturnDef:=Bool32Type;
{$endif CPU64bitaddr}
        constr_destr_finish_head(pd,pd.struct);
        result:=pd;
      end;


    procedure struct_property_dec(is_classproperty:boolean;var rtti_attrs_def: TRTTIAttributeList);
      var
        p : TPropertySym;
        _deprecatedmsg: PShortString;
        _symoptions: TSymOptions;
      begin
        { check for a class, record or helper }
        if not((Is_Class_Or_Interface_Or_DispInterface(CurrentStructDef) or Is_Record(CurrentStructDef) or
                Is_ObjectPascal_Helper(CurrentStructDef)) or
               Is_Object(CurrentStructDef)) then
          Message(parser_e_syntax_error);
        consume(_PROPERTY);
        p:=read_property_dec(is_classproperty,CurrentStructDef);
        consume(_SEMICOLON);
        if try_to_consume(_DEFAULT) then
          begin
            if oo_has_default_property in CurrentStructDef.ObjectOptions then
              message(parser_e_only_one_default_property);
            include(CurrentStructDef.ObjectOptions,oo_has_default_property);
            include(p.PropOptions,ppo_defaultproperty);
            if not(ppo_hasparameters in p.PropOptions) then
              message(parser_e_property_need_paras);
            if (CurrentScanner.token=_COLON) then
              begin
                Message(parser_e_field_not_allowed_here);
                consume_all_until(_SEMICOLON);
              end;
            consume(_SEMICOLON);
          end;
        { parse possible enumerator modifier }
        if try_to_consume(_ENUMERATOR) then
          begin
            if (CurrentScanner.token = _ID) then
            begin
              if CurrentScanner.pattern='CURRENT' then
              begin
                if oo_has_enumerator_current in CurrentStructDef.ObjectOptions then
                  message(parser_e_only_one_enumerator_current);
                if not p.PropAccessList[palt_read].empty then
                begin
                  include(CurrentStructDef.ObjectOptions,oo_has_enumerator_current);
                  include(p.PropOptions,ppo_enumerator_current);
                end
                else
                  Message(parser_e_enumerator_current_is_not_valid) // property has no reader
              end
              else
                Message1(parser_e_invalid_enumerator_identifier, CurrentScanner.pattern);
              consume(CurrentScanner.token);
            end
            else
              Message(parser_e_enumerator_identifier_required);
            consume(_SEMICOLON);
          end;
        { in case of a previous error, p might not be assigned }
        if Assigned(p) then
          begin
            TRTTIAttributeList.bind(rtti_attrs_def,p.RTTIAttributeList);

            { hint directives, these can be separated by semicolons here,
              that needs to be handled here with a loop (PFV) }
            while try_consume_hintdirective(p.SymOptions,p.DeprecatedMsg) do
              Consume(_SEMICOLON);
          end
        else
          begin
            { recover from error so we can continue to parse }

            { hint directives, these can be separated by semicolons here,
              that needs to be handled here with a loop (PFV) }
            while try_consume_hintdirective(_symoptions,_deprecatedmsg) do
              Consume(_SEMICOLON);
          end;
      end;


    function class_destructor_head(astruct: TAbstractRecordDef):TProcDef;
      var
        pd : TProcDef;
      begin
        result:=nil;
        consume(_DESTRUCTOR);
        parse_proc_head(CurrentStructDef,potype_class_destructor,[],nil,nil,pd);
        if not Assigned(pd) then
          begin
            consume(_SEMICOLON);
            exit;
          end;
        pd.CalcParas;
        if (pd.MaxParaCount>0) then
          Message(parser_e_no_paras_for_class_destructor);
        consume(_SEMICOLON);
        include(astruct.ObjectOptions,oo_has_class_destructor);
        include(CurrentModule.ModuleFlags,mf_classinits);
        { no return value }
        pd.ReturnDef:=VoidType;
        constr_destr_finish_head(pd,astruct);
        result:=pd;
      end;

    function destructor_head:TProcDef;
      var
        pd : TProcDef;
      begin
        result:=nil;
        consume(_DESTRUCTOR);
        parse_proc_head(CurrentStructDef,potype_destructor,[],nil,nil,pd);
        if not Assigned(pd) then
          begin
            consume(_SEMICOLON);
            exit;
          end;
        pd.CalcParas;
        if not(pd.MaxParaCount=0) and
           (m_fpc in CurrentSettings.ModeSwitches) then
          Message(parser_e_no_paras_for_destructor);
        consume(_SEMICOLON);
        include(CurrentStructDef.ObjectOptions,oo_has_destructor);
        include(CurrentStructDef.ObjectOptions,oo_has_new_destructor);
        { no return value }
        pd.ReturnDef:=VoidType;
        constr_destr_finish_head(pd,pd.struct);
        result:=pd;
      end;


    procedure setinterfacemethodoptions;
      var
        i   : LongInt;
        def : TDef;
      begin
        include(CurrentStructDef.ObjectOptions,oo_has_virtual);
        for i:=0 to CurrentStructDef.SymTable.DefList.count-1 do
          begin
            def:=TDef(CurrentStructDef.SymTable.DefList[i]);
            if Assigned(def) and
               (def.typ=procdef) then
              begin
                include(TProcDef(def).ProcOptions,po_virtualmethod);
                TProcDef(def).ForwardDef:=false;
              end;
          end;
      end;


    procedure setobjcclassmethodoptions;
      var
        i   : LongInt;
        def : TDef;
      begin
        for i:=0 to CurrentStructDef.SymTable.DefList.count-1 do
          begin
            def:=TDef(CurrentStructDef.SymTable.DefList[i]);
            if Assigned(def) and
               (def.typ=procdef) then
              begin
                include(TProcDef(def).ProcOptions,po_virtualmethod);
              end;
          end;
      end;


    procedure handleImplementedInterface(intfdef : TObjectDef);
      begin
        if not Is_Interface(intfdef) then
          begin
             Message1(type_e_interface_type_expected,intfdef.TypeName);
             exit;
          end;
        if ([oo_is_forward,oo_is_formal] * intfdef.ObjectOptions <> []) then
          begin
             Message1(parser_e_forward_intf_declaration_must_be_resolved,intfdef.ObjRealName^);
             exit;
          end;
        if Find_Implemented_Interface(current_objectdef,intfdef)<>nil then
          Message1(sym_e_duplicate_id,intfdef.ObjName^)
        else
          current_objectdef.Register_Implemented_Interface(intfdef,true);
      end;


    procedure handleImplementedProtocol(intfdef : TObjectDef);
      begin
        intfdef:=Find_Real_Class_Definition(intfdef,false);
        case current_objectdef.ObjectType of
          odt_objcclass,
          odt_objccategory,
          odt_objcprotocol:
            if not Is_ObjCProtocol(intfdef) then
              begin
                 Message1(type_e_protocol_type_expected,intfdef.TypeName);
                 exit;
              end;
          else
            InternalError(2011010807);
        end;
        if ([oo_is_forward,oo_is_formal] * intfdef.ObjectOptions <> []) then
          begin
             Message1(parser_e_forward_intf_declaration_must_be_resolved,intfdef.ObjRealName^);
             exit;
          end;
        if Find_Implemented_Interface(current_objectdef,intfdef)<>nil then
          Message1(sym_e_duplicate_id,intfdef.ObjName^)
        else
          current_objectdef.Register_Implemented_Interface(intfdef,false);
      end;


    procedure readImplementedInterfacesAndProtocols(intf: boolean);
      var
        hdef : TDef;
      begin
        while try_to_consume(_COMMA) do
          begin
             { use single_type instead of id_type for specialize support }
             single_type(hdef,[stoAllowSpecialization,stoParseClassParent]);
             if (hdef.typ<>objectdef) then
               begin
                  if intf then
                    Message1(type_e_interface_type_expected,hdef.TypeName)
                  else
                    Message1(type_e_protocol_type_expected,hdef.TypeName);
                  continue;
               end;
             if intf then
               handleImplementedInterface(TObjectDef(hdef))
             else
               handleImplementedProtocol(TObjectDef(hdef));
          end;
      end;


    procedure readinterfaceiid;
      var
        p : TNode;
        valid : boolean;
      begin
        p:=comp_expr([ef_accept_equal]);
        if p.nodetype=stringconstn then
          begin
            StringDispose(current_objectdef.IIDStr);
            current_objectdef.IIDStr:=StringDup(TStringConstNode(p).AsRawByteString);
            valid:=String2GUID(current_objectdef.IIDStr^,current_objectdef.IIDGUID^);
            if (current_objectdef.ObjectType in [odt_interfacecom,odt_dispinterface]) and
               not valid then
              Message(parser_e_improper_guid_syntax);
            include(CurrentStructDef.ObjectOptions,oo_has_valid_guid);
          end
        else
          Message(parser_e_illegal_expression);
        p.free;
        p := nil;
      end;

    procedure get_cpp_class_external_status(od: TObjectDef);
      var
        hs: string;
      begin
        { C++ classes can be external -> all methods inside are external
         (defined at the class level instead of per method, so that you cannot
         define some methods as external and some not)
        }
        if try_to_consume(_EXTERNAL) then
          begin
            hs:='';
            if CurrentScanner.token in [_CSTRING,_CWSTRING,_CCHAR,_CWCHAR] then
              begin
                { Always add library prefix and suffix to create an uniform name }
                hs:=get_stringconst;
                if ExtractFileExt(hs)='' then
                  hs:=ChangeFileExt(hs,TargetInfo.sharedlibext);
                if Copy(hs,1,length(TargetInfo.sharedlibprefix))<>TargetInfo.sharedlibprefix then
                  hs:=TargetInfo.sharedlibprefix+hs;
              end;
            if hs<>'' then
              begin
                StringDispose(od.ImportLib);
                od.ImportLib:=StringDup(hs);
              end;
            { check if we shall use another name for the class }
            if try_to_consume(_NAME) then
              od.ObjExtName:=StringDup(get_stringconst)
            else
              od.ObjExtName:=StringDup(od.ObjRealName^);
            include(od.ObjectOptions,oo_is_external);
          end
        else
          begin
            od.ObjExtName:=StringDup(od.ObjRealName^);
          end;
      end;


    procedure get_objc_class_or_protocol_external_status(od: TObjectDef);
      begin
        { Objective-C classes can be external -> all messages inside are
          external (defined at the class level instead of per method, so
          that you cannot define some methods as external and some not)
        }
        if try_to_consume(_EXTERNAL) then
          begin
            if try_to_consume(_NAME) then
              od.ObjExtName:=StringDup(get_stringconst)
            else
              { the external name doesn't matter for formally declared
                classes, and allowing to specify one would mean that we would
                have to check it for consistency with the actual definition
                later on }
              od.ObjExtName:=StringDup(od.ObjRealName^);
            include(od.ObjectOptions,oo_is_external);
          end
        else
          od.ObjExtName:=StringDup(od.ObjRealName^);
      end;


    procedure parse_object_options;
      begin
        case current_objectdef.ObjectType of
          odt_object,odt_class:
            begin
              while true do
                begin
                  if try_to_consume(_ABSTRACT) then
                    include(CurrentStructDef.ObjectOptions,oo_is_abstract)
                  else
                  if try_to_consume(_SEALED) then
                    include(CurrentStructDef.ObjectOptions,oo_is_sealed)
                  else break;
                end;
              { don't use <=, because there's a bug in the 2.6.0 SPARC code
                generator regarding handling this expression }
              if ([oo_is_abstract, oo_is_sealed] * CurrentStructDef.ObjectOptions) = [oo_is_abstract, oo_is_sealed] then
                Message(parser_e_abstract_and_sealed_conflict);
            end;
          odt_cppclass:
            get_cpp_class_external_status(current_objectdef);
          odt_objcclass,odt_objcprotocol,odt_objccategory:
            get_objc_class_or_protocol_external_status(current_objectdef);
          odt_helper: ; // nothing
          else
            ;
        end;
      end;

    procedure parse_parent_classes;
      var
        intfchildof,
        ChildOf : TObjectDef;
        hdef : TDef;
        hasparentdefined : boolean;
      begin
        ChildOf:=nil;
        intfchildof:=nil;
        hasparentdefined:=false;

        { reads the parent class }
        if (CurrentScanner.token=_LKLAMMER) or
           Is_ObjCCategory(CurrentStructDef) then
          begin
            consume(_LKLAMMER);
            { use single_type instead of id_type for specialize support }
            single_type(hdef,[stoAllowSpecialization, stoParseClassParent]);
            if (not Assigned(hdef)) or
               (hdef.typ<>objectdef) then
              begin
                if Assigned(hdef) then
                  Message1(type_e_class_type_expected,hdef.TypeName)
                else if Is_ObjCCategory(CurrentStructDef) then
                  { a category must specify the class to extend }
                  Message(type_e_objcclass_type_expected);
              end
            else
              begin
                ChildOf:=TObjectDef(hdef);
                { a mix of class, interfaces, objects and cppclasses
                  isn't allowed }
                case current_objectdef.ObjectType of
                   odt_class:
                     if (ChildOf.ObjectType<>current_objectdef.ObjectType) then
                       begin
                          if (Is_Interface(ChildOf) and
                              Is_Class(current_objectdef)) then
                            begin
                               { we insert the interface after the child
                                 is set, see below
                               }
                               intfchildof:=ChildOf;
                               ChildOf:=Class_TObject;
                            end
                          else
                            Message(parser_e_mix_of_classes_and_objects);
                       end
                     else
                       if oo_is_sealed in ChildOf.ObjectOptions then
                         Message1(parser_e_sealed_descendant,ChildOf.TypeSymbolPrettyName)
                       else
                         ChildOf:=Find_Real_Class_Definition(ChildOf,true);
                   odt_interfacecorba,
                   odt_interfacecom:
                     begin
                       if not(Is_Interface(ChildOf)) then
                         Message(parser_e_mix_of_classes_and_objects);
                       current_objectdef.ObjectType:=ChildOf.ObjectType;
                     end;
                   odt_cppclass:
                     if not(Is_CPPClass(ChildOf)) then
                       Message(parser_e_mix_of_classes_and_objects);
                   odt_objcclass:
                     if not(Is_ObjCClass(ChildOf) or
                        Is_ObjCCategory(ChildOf)) then
                       begin
                         if Is_ObjCProtocol(ChildOf) then
                           begin
                             if not(oo_is_classhelper in CurrentStructDef.ObjectOptions) then
                               begin
                                 intfchildof:=ChildOf;
                                 ChildOf:=nil;
                                 CGMessage(parser_h_no_objc_parent);
                               end
                             else
                               { a category must specify the class to extend }
                               CGMessage(type_e_objcclass_type_expected);
                           end
                         else
                           Message(parser_e_mix_of_classes_and_objects);
                       end
                     else
                       ChildOf:=Find_Real_Class_Definition(ChildOf,true);
                   odt_objcprotocol:
                     begin
                       if not(Is_ObjCProtocol(ChildOf)) then
                         Message(parser_e_mix_of_classes_and_objects);
                       intfchildof:=ChildOf;
                       ChildOf:=nil;
                     end;

                   odt_object:
                     if not(Is_Object(ChildOf)) then
                       Message(parser_e_mix_of_classes_and_objects)
                     else
                       if oo_is_sealed in ChildOf.ObjectOptions then
                         Message1(parser_e_sealed_descendant,ChildOf.TypeName);
                   odt_dispinterface:
                     Message(parser_e_dispinterface_cant_have_parent);
                   odt_helper:
                     if not Is_ObjectPascal_Helper(ChildOf) then
                       begin
                         Message(type_e_helper_type_expected);
                         ChildOf:=nil;
                       end;
                   else
                     ;
                end;
              end;
            hasparentdefined:=true;
          end;

        { if no parent class, then a class get tobject as parent }
        if not Assigned(ChildOf) then
          begin
            case current_objectdef.ObjectType of
              odt_class:
                if current_objectdef<>Class_TObject then
                  ChildOf:=Class_TObject;
              odt_interfacecom:
                if current_objectdef<>Interface_IUnknown then
                  ChildOf:=Interface_IUnknown;
              odt_dispinterface:
                ChildOf:=Interface_IDispatch;
              odt_objcclass:
                CGMessage(parser_h_no_objc_parent);

              else
                ;
            end;
          end;

        if Assigned(ChildOf) then
          begin
            { Forbid not completly defined objects to be used as parents. This will
              also prevent circular loops of classes, because we set the forward flag
              at the start of the new definition and will reset it below after the
              parent has been set }
            if (oo_is_forward in ChildOf.ObjectOptions) then
              Message1(parser_e_forward_declaration_must_be_resolved,ChildOf.ObjRealName^)
            else if not(oo_is_formal in ChildOf.ObjectOptions) then
              current_objectdef.Set_Parent(ChildOf)
            else
              Message1(sym_e_formal_class_not_resolved,ChildOf.ObjRealName^);
          end;

        if hasparentdefined then
          begin
            if current_objectdef.ObjectType in [odt_class,odt_objcclass,odt_objcprotocol] then
              begin
                if Assigned(intfchildof) then
                  if current_objectdef.ObjectType=odt_class then
                    handleImplementedInterface(intfchildof)
                  else
                    handleImplementedProtocol(intfchildof);
                readImplementedInterfacesAndProtocols(current_objectdef.ObjectType=odt_class);
              end;
            consume(_RKLAMMER);
          end;
      end;

    procedure parse_extended_type(HelperType:THelperType);

      procedure validate_extendeddef_typehelper(var def:TDef);
        begin
          if (def.typ in [undefineddef,procvardef,procdef,
              filedef,classrefdef,abstractdef,ForwardDef,formaldef]) or
              (
                (def.typ=objectdef) and
                not (TObjectDef(def).ObjectType in ObjectTypesWithHelpers)
              ) then
            begin
              Message1(type_e_type_not_allowed_for_type_helper,def.TypeName);
              def:=GenErrorDef;
            end;
        end;

      procedure check_inheritance_record_type_helper(var def:TDef);
        var
          tmp : TStoredDef;
        begin
          if (def.typ<>errordef) and Assigned(current_objectdef.ChildOf) then
            begin
              if def<>current_objectdef.ChildOf.ExtendedDef then
                begin
                  { a type helper may extend a type alias of the type its
                    parent type helper extends }
                  tmp:=TStoredDef(def);
                  while (df_unique in tmp.DefOptions) and Assigned(TStoredDef(tmp).OrgDef) do
                    begin
                      if tmp.OrgDef=current_objectdef.ChildOf.ExtendedDef then
                        exit;
                      tmp:=TStoredDef(tmp.OrgDef);
                    end;
                  Message1(type_e_record_helper_must_extend_same_record,current_objectdef.ChildOf.ExtendedDef.TypeName);
                  def:=GenErrorDef;
                end;
            end;
        end;

      procedure check_inheritance_class_helper(var def:TDef);
        begin
          if (def.typ<>errordef) and Assigned(current_objectdef.ChildOf) then
            begin
              if (current_objectdef.ChildOf.ExtendedDef.typ<>objectdef) or
                 not (TObjectDef(current_objectdef.ChildOf.ExtendedDef).ObjectType in ObjectTypesWithHelpers) then
                InternalError(2011021101);
              if not Def_Is_Related(def,current_objectdef.ChildOf.ExtendedDef) then
                begin
                  Message1(type_e_class_helper_must_extend_subclass,current_objectdef.ChildOf.ExtendedDef.TypeName);
                  def:=GenErrorDef;
                end;
            end;
        end;

      var
        hdef: TDef;
      begin
        if not Is_ObjectPascal_Helper(CurrentStructDef) then
          InternalError(2011021103);

        consume(_FOR);
        { set extendeddef to non-Nil so that potential checks for it won't trigger
          access violations }
        current_objectdef.ExtendedDef:=GenErrorDef;
        single_type(hdef,[stoParseClassParent]);
        if not Assigned(hdef) or (hdef.typ=errordef) then
          begin
            case HelperType of
              ht_class:
                Message1(type_e_class_type_expected,hdef.TypeName);
              ht_record:
                Message(type_e_record_type_expected);
              ht_type:
                Message1(type_e_type_id_expected,hdef.TypeName);
              else
                InternalError(2019050532);
            end;
          end
        else
          begin
            case HelperType of
              ht_class:
                if (hdef.typ<>objectdef) or
                    not Is_Class(hdef) then
                  Message1(type_e_class_type_expected,hdef.TypeName)
                else
                  begin
                    { a class helper must extend the same class or a subclass
                      of the class extended by the parent class helper }
                    check_inheritance_class_helper(hdef);
                  end;
              ht_record:
                if (hdef.typ=objectdef) or
                    (
                      { primitive types are allowed for record helpers in mode
                        delphi }
                      (hdef.typ<>recorddef) and
                      not (m_delphi in CurrentSettings.ModeSwitches)
                    ) then
                  Message1(type_e_record_type_expected,hdef.TypeName)
                else
                  begin
                    if hdef.typ<>recorddef then
                      { this is a primitive type in mode delphi, so validate
                        the def }
                      validate_extendeddef_typehelper(hdef);
                    { a record helper must extend the same record as the
                      parent helper }
                    check_inheritance_record_type_helper(hdef);
                  end;
              ht_type:
                begin
                  validate_extendeddef_typehelper(hdef);
                  if (hdef.typ=objectdef) and
                      (TObjectDef(hdef).ObjectType in ObjectTypesWithHelpers) then
                    check_inheritance_class_helper(hdef)
                  else
                    { a type helper must extend the same type as the
                      parent helper }
                    check_inheritance_record_type_helper(hdef);
                end;
              else
                InternalError(2019050531);
            end;
          end;

        if Assigned(hdef) then
          current_objectdef.ExtendedDef:=hdef;
      end;

    procedure parse_guid;
      begin
        { read GUID }
        if (current_objectdef.ObjectType in [odt_interfacecom,odt_interfacecorba,odt_dispinterface]) and
           try_to_consume(_LECKKLAMMER) then
          begin
            readinterfaceiid;
            consume(_RECKKLAMMER);
          end
        else if (current_objectdef.ObjectType=odt_dispinterface) then
          message(parser_e_dispinterface_needs_a_guid);
      end;


    function method_dec(astruct: TAbstractRecordDef; is_classdef: boolean;hadgeneric:boolean): TProcDef;

      procedure chkobjc(pd: TProcDef);
        begin
          if Is_ObjC_Class_Or_Protocol(pd.struct) then
            begin
              include(pd.ProcOptions,po_objc);
            end;
        end;


      procedure chkcpp(pd:TProcDef);
          begin
            { nothing currently }
          end;

      var
        oldparse_only: boolean;
        flags : TParseProcFlags;
      begin
        case CurrentScanner.token of
          _PROCEDURE,
          _FUNCTION:
            begin
              if (astruct.SymTable.CurrentVisibility=vis_published) and
                 not(oo_can_have_published in astruct.ObjectOptions) then
                Message(parser_e_cant_have_published);

              oldparse_only:=parse_only;
              parse_only:=true;
              flags:=[];
              if is_classdef then
                include(flags,ppf_classmethod);
              if hadgeneric then
                include(flags,ppf_generic);
              result:=parse_proc_dec(flags,astruct);

              { this is for error recovery as well as forward }
              { interface mappings, i.e. mapping to a method  }
              { which isn't declared yet                      }
              if Assigned(result) then
                begin
                  parse_object_proc_directives(result);

                  { check if dispid is set }
                  if Is_DispInterface(result.struct) and not (po_dispid in result.ProcOptions) then
                    begin
                      result.DispID:=TObjectDef(result.struct).Get_Next_DispID;
                      include(result.ProcOptions, po_dispid);
                    end;

                  { all Macintosh Object Pascal methods are virtual.  }
                  { this can't be a class method, because macpas mode }
                  { has no m_class                                    }
                  if (m_mac in CurrentSettings.ModeSwitches) then
                    include(result.ProcOptions,po_virtualmethod);

                  { for record and type helpers only static class methods are
                    allowed }
                  if Is_ObjectPascal_Helper(astruct) and
                     (
                       (TObjectDef(astruct).ExtendedDef.typ<>objectdef) or
                       (TObjectDef(TObjectDef(astruct).ExtendedDef).ObjectType<>odt_class)
                     ) and
                     is_classdef and not (po_staticmethod in result.ProcOptions) then
                    MessagePos(result.fileinfo,parser_e_class_methods_only_static_in_records);

                  handle_calling_convention(result,hcc_default_actions_intf_struct);

                  { add definition to procsym }
                  proc_add_definition(result);

                  { add procdef options to objectdef options }
                  if (po_msgint in result.ProcOptions) then
                    include(astruct.ObjectOptions,oo_has_msgint);
                  if (po_msgstr in result.ProcOptions) then
                    include(astruct.ObjectOptions,oo_has_msgstr);
                  if (po_virtualmethod in result.ProcOptions) then
                    include(astruct.ObjectOptions,oo_has_virtual);

                  if result.Is_Generic then
                    astruct.SymTable.IncludeOption(sto_has_generic);

                  chkcpp(result);
                  chkobjc(result);
                end;

              maybe_parse_hint_directives(result);

              parse_only:=oldparse_only;
            end;
          _CONSTRUCTOR :
            begin
              if (astruct.SymTable.CurrentVisibility=vis_published) and
                not(oo_can_have_published in astruct.ObjectOptions) then
                Message(parser_e_cant_have_published);

              if not is_classdef and not(astruct.SymTable.CurrentVisibility in [vis_public,vis_published]) then
                Message(parser_w_constructor_should_be_public);

              if Is_Interface(astruct) then
                Message(parser_e_no_con_des_in_interfaces);

              { Objective-C does not know the concept of a constructor }
              if Is_ObjC_Class_Or_Protocol(astruct) then
                Message(parser_e_objc_no_constructor_destructor);

              if Is_ObjectPascal_Helper(astruct) then
                if is_classdef then
                  { class constructors are not allowed in class helpers }
                  Message(parser_e_no_class_constructor_in_helpers);

              { only 1 class constructor is allowed }
              if is_classdef and (oo_has_class_constructor in astruct.ObjectOptions) then
                Message1(parser_e_only_one_class_constructor_allowed, astruct.ObjRealName^);

              oldparse_only:=parse_only;
              parse_only:=true;
              if is_classdef then
                result:=class_constructor_head(CurrentStructDef)
              else
                begin
                  result:=constructor_head;
                  if Is_ObjectPascal_Helper(astruct) and
                     (TObjectDef(astruct).ExtendedDef.typ<>objectdef) and
                     (result.MinParaCount=0) then
                      { as long as parameterless constructors aren't allowed in records they
                       aren't allowed in record/type helpers either }
                    MessagePos(result.ProcSym.fileinfo,parser_e_no_parameterless_constructor_in_records);
                end;

              chkcpp(result);

              parse_only:=oldparse_only;
            end;
          _DESTRUCTOR :
            begin
              if (astruct.SymTable.CurrentVisibility=vis_published) and
                 not(oo_can_have_published in astruct.ObjectOptions) then
                Message(parser_e_cant_have_published);

              if not is_classdef then
                if (oo_has_new_destructor in astruct.ObjectOptions) then
                  Message(parser_n_only_one_destructor);

              if Is_Interface(astruct) then
                Message(parser_e_no_con_des_in_interfaces);

              { (class) destructors are not allowed in class helpers }
              if Is_ObjectPascal_Helper(astruct) then
                Message(parser_e_no_destructor_in_records);

              if not is_classdef and (astruct.SymTable.CurrentVisibility<>vis_public) then
                Message(parser_w_destructor_should_be_public);

              { Objective-C does not know the concept of a destructor }
              if Is_ObjC_Class_Or_Protocol(astruct) then
                Message(parser_e_objc_no_constructor_destructor);

              { only 1 class destructor is allowed }
              if is_classdef and (oo_has_class_destructor in astruct.ObjectOptions) then
                Message1(parser_e_only_one_class_destructor_allowed, astruct.ObjRealName^);

              oldparse_only:=parse_only;
              parse_only:=true;
              if is_classdef then
                result:=class_destructor_head(CurrentStructDef)
              else
                result:=destructor_head;

              chkcpp(result);

              parse_only:=oldparse_only;
            end;
          else
            InternalError(2011032102);
        end;
      end;


    procedure parse_object_members;

      var
        typedconstswritable: boolean;
        object_member_blocktype : TBlockType;
        hadgeneric,
        fields_allowed, is_classdef, class_fields, is_final, final_fields,
        threadvar_fields : boolean;
        vdoptions: TVarDecOptions;
        fieldlist: TFPObjectList;
        rtti_attrs_def: TRTTIAttributeList;
        attr_element_count,fldCount : Integer;
        method_def : TProcDef;

      procedure check_unbound_attributes;
        begin
          if Assigned(rtti_attrs_def) and (rtti_attrs_def.GetAttributeCount>0) then
            Message1(parser_e_unbound_attribute,TRTTIAttribute(rtti_attrs_def.RTTIAttributes[0]).TypeSym.prettyname);
          rtti_attrs_def.free;
          rtti_attrs_def:=nil;
        end;


      procedure parse_const;
        begin
          if not(current_objectdef.ObjectType in [odt_class,odt_object,odt_helper]) then
            Message(parser_e_type_var_const_only_in_records_and_classes);
          consume(_CONST);
          object_member_blocktype:=bt_const;
          final_fields:=is_final;
          is_final:=false;
        end;


      procedure parse_var(isthreadvar:boolean);
        begin
          if not(current_objectdef.ObjectType in [odt_class,odt_object,odt_helper]) then
            Message(parser_e_type_var_const_only_in_records_and_classes);
          if isthreadvar then
            consume(_THREADVAR)
          else
            consume(_VAR);
          fields_allowed:=true;
          object_member_blocktype:=bt_general;
          class_fields:=is_classdef;
          final_fields:=is_final;
          threadvar_fields:=isthreadvar;
          is_classdef:=false;
          is_final:=false;
        end;


      procedure parse_class;
        begin
          is_classdef:=false;
          { read class method/field/property }
          consume(_CLASS);
          { class modifier is only allowed for procedures, functions, }
          { constructors, destructors, fields and properties          }
          if not((CurrentScanner.token in [_FUNCTION,_PROCEDURE,_PROPERTY,_VAR,_DESTRUCTOR,_THREADVAR]) or (CurrentScanner.token=_CONSTRUCTOR)) then
            Message(parser_e_procedure_or_function_expected);

          { class properties currently can't have attributes }
          if not(CurrentScanner.token in [_FUNCTION,_PROCEDURE]) then
            check_unbound_attributes;


          if Is_Interface(CurrentStructDef) then
            Message(parser_e_no_static_method_in_interfaces)
          else
            { class methods are also allowed for Objective-C protocols }
            is_classdef:=true;
        end;


      procedure parse_visibility(vis: TVisibility; oo: TObjectOption);
        begin

          if (vis=vis_published) and
             (Is_ObjC_Class_Or_Protocol(CurrentStructDef)) then
             Message(parser_e_no_objc_published)
          else if Is_Interface(CurrentStructDef) or
             Is_ObjC_Protocol_Or_Category(CurrentStructDef) then
            Message(parser_e_no_access_specifier_in_interfaces);
          CurrentStructDef.SymTable.CurrentVisibility:=vis;
          consume(CurrentScanner.token);
          if (oo<>oo_none) then
            include(CurrentStructDef.ObjectOptions,oo);
          fields_allowed:=true;
          is_classdef:=false;
          class_fields:=false;
          threadvar_fields:=false;
          is_final:=false;
          object_member_blocktype:=bt_general;
        end;


      begin
        { empty class declaration ? }
        if (current_objectdef.ObjectType in [odt_class,odt_objcclass]) and
           (CurrentScanner.token=_SEMICOLON) then
          exit;

        { in "publishable" classes the default access type is published }
        if (oo_can_have_published in CurrentStructDef.ObjectOptions) then
          CurrentStructDef.SymTable.CurrentVisibility:=vis_published
        else
          CurrentStructDef.SymTable.CurrentVisibility:=vis_public;
        fields_allowed:=true;
        is_classdef:=false;
        class_fields:=false;
        is_final:=false;
        final_fields:=false;
        rtti_attrs_def:=nil;
        hadgeneric:=false;
        threadvar_fields:=false;
        object_member_blocktype:=bt_general;
        fieldlist:=TFPObjectList.Create(false);
        repeat
          case CurrentScanner.token of
            _TYPE :
              begin
                check_unbound_attributes;
                if not(current_objectdef.ObjectType in [odt_class,odt_object,odt_helper]) then
                  Message(parser_e_type_var_const_only_in_records_and_classes);
                consume(_TYPE);
                object_member_blocktype:=bt_type;

                if (CurrentScanner.token=_LECKKLAMMER) and (m_prefixed_attributes in CurrentSettings.ModeSwitches) then
                  begin
                    check_unbound_attributes;
                    types_dec(true,hadgeneric, rtti_attrs_def);
                  end
                else
                  { expect at least one type declaration }
                  if CurrentScanner.token<>_ID then
                    consume(_ID);
              end;
            _VAR :
              begin
                check_unbound_attributes;
                rtti_attrs_def := nil;
                parse_var(false);
                { expect at least one var declaration }
                if CurrentScanner.token<>_ID then
                  consume(_ID);
              end;
            _CONST:
              begin
                check_unbound_attributes;
                rtti_attrs_def := nil;
                parse_const;
                { expect at least one constant declaration }
                if CurrentScanner.token<>_ID then
                  consume(_ID);
              end;
            _THREADVAR :
              begin
                check_unbound_attributes;
                if not is_classdef then
                  begin
                    Message(parser_e_threadvar_must_be_class);
                    { for error recovery we enforce class fields }
                    is_classdef:=true;
                  end;
                parse_var(true);
                { expect at least one threadvar declaration }
                if CurrentScanner.token<>_ID then
                  consume(_ID);
              end;
            _ID :
              begin
                if Is_ObjCProtocol(CurrentStructDef) and
                   ((CurrentScanner.idtoken=_REQUIRED) or
                    (CurrentScanner.idtoken=_OPTIONAL)) then
                  begin
                    CurrentStructDef.SymTable.CurrentlyOptional:=(CurrentScanner.idtoken=_OPTIONAL);
                    consume(CurrentScanner.idtoken)
                  end
                else case CurrentScanner.idtoken of
                  _PRIVATE :
                    begin
                      parse_visibility(vis_private,oo_has_private);
                     end;
                   _PROTECTED :
                     begin
                       parse_visibility(vis_protected,oo_has_protected);
                     end;
                   _PUBLIC :
                     begin
                       parse_visibility(vis_public,oo_none);
                     end;
                   _PUBLISHED :
                     begin
                       parse_visibility(vis_published,oo_none);
                     end;
                   _STRICT :
                     begin
                       if Is_Interface(CurrentStructDef) or
                          Is_ObjC_Protocol_Or_Category(CurrentStructDef) then
                         Message(parser_e_no_access_specifier_in_interfaces);
                         consume(_STRICT);
                        if CurrentScanner.token=_ID then
                          begin
                            case CurrentScanner.idtoken of
                              _PRIVATE:
                                begin
                                  consume(_PRIVATE);
                                  CurrentStructDef.SymTable.CurrentVisibility:=vis_strictprivate;
                                  include(CurrentStructDef.ObjectOptions,oo_has_strictprivate);
                                end;
                              _PROTECTED:
                                begin
                                  consume(_PROTECTED);
                                  CurrentStructDef.SymTable.CurrentVisibility:=vis_strictprotected;
                                  include(CurrentStructDef.ObjectOptions,oo_has_strictprotected);
                                end;
                              else
                                message(parser_e_protected_or_private_expected);
                            end;
                          end
                        else
                          message(parser_e_protected_or_private_expected);
                        fields_allowed:=true;
                        is_classdef:=false;
                        class_fields:=false;
                        threadvar_fields:=false;
                        is_final:=false;
                        final_fields:=false;
                        object_member_blocktype:=bt_general;
                     end
                    else if (m_final_fields in CurrentSettings.ModeSwitches) and
                            (CurrentScanner.token=_ID) and
                            (CurrentScanner.idtoken=_FINAL) then
                      begin
                        { currently only supported for external classes, because
                          requires fully working DFA otherwise }
                        if (CurrentStructDef.typ<>objectdef) or
                           not(oo_is_external in TObjectDef(CurrentStructDef).ObjectOptions) then
                          Message(parser_e_final_only_external);
                        consume(_final);
                        is_final:=true;
                        if CurrentScanner.token=_CLASS then
                          parse_class;
                        if not(CurrentScanner.token in [_CONST,_VAR]) then
                          message(parser_e_final_only_const_var);
                      end
                    else
                      begin
                        if object_member_blocktype=bt_general then
                          begin
                            if (CurrentScanner.idtoken=_GENERIC) and
                                not (m_delphi in CurrentSettings.ModeSwitches) and
                                (
                                  not fields_allowed or
                                  Is_ObjectPascal_Helper(CurrentStructDef)
                                ) then
                              begin
                                if hadgeneric then
                                  Message(parser_e_procedure_or_function_expected);
                                consume(_ID);
                                hadgeneric:=true;
                                if not (CurrentScanner.token in [_PROCEDURE,_FUNCTION,_CLASS]) then
                                  Message(parser_e_procedure_or_function_expected);
                              end
                            else
                              begin
                                if Is_Interface(CurrentStructDef) or
                                   Is_ObjC_Protocol_Or_Category(CurrentStructDef) or
                                   (
                                     Is_ObjectPascal_Helper(CurrentStructDef) and
                                     not class_fields
                                   ) then
                                  Message(parser_e_no_vars_in_interfaces);

                                if (CurrentStructDef.SymTable.CurrentVisibility=vis_published) and
                                   not(oo_can_have_published in CurrentStructDef.ObjectOptions) then
                                  Message(parser_e_cant_have_published);
                                if (not fields_allowed) then
                                  Message(parser_e_field_not_allowed_here);

                                vdoptions:=[vd_object];
                                if not (m_delphi in CurrentSettings.ModeSwitches) then
                                  include(vdoptions,vd_check_generic);
                                if class_fields then
                                  include(vdoptions,vd_class);
                                if Is_Class(CurrentStructDef) then
                                  include(vdoptions,vd_canreorder);
                                if final_fields then
                                  include(vdoptions,vd_final);
                                if threadvar_fields then
                                  include(vdoptions,vd_threadvar);
                                // Record count
                                fldCount:=FieldList.Count;
                                read_record_fields(vdoptions,fieldlist,nil,hadgeneric,attr_element_count);
                                {
                                  attr_element_count returns the number of fields to which the attribute must be applied.
                                  For
                                  [someattr]
                                  a : integer;
                                  b : integer;
                                  attr_element_count returns 1. For
                                  [someattr]
                                  a, b : integer;
                                  it returns 2.
                                  Basically the number of variables before the first colon.
                                }
                                if Assigned(rtti_attrs_def) then
                                  begin
                                  { read_record_fields can read a list of fields with the same type.
                                    for the first fields, we simply copy. for the last one we bind.}
                                  While (attr_element_count>1) do
                                    begin
                                    TRTTIAttributeList.CopyAndBind(rtti_attrs_def,TFieldVarSym(fieldlist[FldCount]).RTTIAttributeList);
                                    inc(fldcount);
                                    dec(attr_element_count);
                                    end;
                                  if fldCount<FieldList.Count then
                                    TRTTIAttributeList.bind(rtti_attrs_def,TFieldVarSym(fieldlist[FldCount]).RTTIAttributeList)
                                  else
                                    rtti_attrs_def.free;
                                    rtti_attrs_def := nil;
                                  end;
                                rtti_attrs_def:=nil;
                              end;
                          end
                        else if object_member_blocktype=bt_type then
                          begin
                          check_unbound_attributes;
                          types_dec(true,hadgeneric, rtti_attrs_def)
                          end
                        else if object_member_blocktype=bt_const then
                          begin
                            check_unbound_attributes;
                            typedconstswritable:=false;
                            if final_fields then
                              begin
                                { the value of final fields cannot be changed
                                  once they've been assigned a value }
                                typedconstswritable:=cs_typed_const_writable in CurrentSettings.LocalSwitches;
                                exclude(CurrentSettings.LocalSwitches,cs_typed_const_writable);
                              end;
                            consts_dec(true,true,hadgeneric);
                            if final_fields and
                               typedconstswritable then
                              include(CurrentSettings.LocalSwitches,cs_typed_const_writable);
                          end
                        else
                          InternalError(2010011103);
                      end;
                end;
              end;
            _PROPERTY :
              begin
                struct_property_dec(is_classdef, rtti_attrs_def);
                fields_allowed:=false;
                is_classdef:=false;
              end;
            _CLASS:
                parse_class;
            _PROCEDURE,
            _FUNCTION,
            _CONSTRUCTOR,
            _DESTRUCTOR :
              begin
                method_def:=method_dec(CurrentStructDef,is_classdef,hadgeneric);
                if Assigned(rtti_attrs_def) then
                  begin
                  TRTTIAttributeList.bind(rtti_attrs_def,method_def.RTTIAttributeList);
                  rtti_attrs_def:=nil;
                  end;
                fields_allowed:=false;
                is_classdef:=false;
                hadgeneric:=false;
              end;
            _LECKKLAMMER:
              begin
                if m_prefixed_attributes in CurrentSettings.ModeSwitches then
                  parse_rttiattributes(rtti_attrs_def)
                else
                  consume(_ID);
              end;
            _END :
              begin
                check_unbound_attributes;
                consume(_END);
                break;
              end;
            else
              consume(_ID); { Give a ident expected message, like tp7 }
          end;
        until false;

        if Is_Class(CurrentStructDef) then
          TAbstractRecordSymTable(CurrentStructDef.SymTable).AddFieldList(fieldlist,true);
        fieldlist.free;
        fieldlist := nil;
      end;


    function object_dec(ObjectType:TObjectTyp;const n:TIDString;objsym:TSym;GenericDef:TStoredDef;genericlist:TFPHashObjectList;fd : TObjectDef;HelperType:THelperType) : TObjectDef;
      var
        old_current_structdef: TAbstractRecordDef;
        old_current_genericdef,
        old_current_specializedef: TStoredDef;
        old_parse_generic: boolean;
        list: TFPObjectList;
        s: TSymStr;
        st: TSymTable;
        olddef: TDef;
      begin
        old_current_structdef:=CurrentStructDef;
        old_current_genericdef:=CurrentGenericDef;
        old_current_specializedef:=CurrentSpecializeDef;
        old_parse_generic:=parse_generic;

        CurrentStructDef:=nil;
        CurrentGenericDef:=nil;
        CurrentSpecializeDef:=nil;

        { objects and class types can't be declared local }
        if not(SymTableStack.top.SymTableType in [GlobalSymTable,staticsymtable,objectsymtable,recordsymtable]) and
           not Assigned(genericlist) then
          Message(parser_e_no_local_objects);

        { reuse forward objectdef? }
        if Assigned(fd) then
          begin
            if (fd.ObjectType<>ObjectType) or ((fd.Is_Generic or fd.Is_Specialization) xor Assigned(genericlist)) then
              begin
                Message(parser_e_forward_mismatch);
                { recover }
                CurrentStructDef:=CObjectDef.Create(ObjectType,n,nil,true);
                include(CurrentStructDef.ObjectOptions,oo_is_forward);
              end
            else
              CurrentStructDef:=fd
          end
        else
          begin
            { anonym objects aren't allow (o : object a : longint; end;) }
            if n='' then
              Message(parser_f_no_anonym_objects);

            { create new class }
            CurrentStructDef:=CObjectDef.Create(ObjectType,n,nil,true);
            TObjectDef(CurrentStructDef).HelperType:=HelperType;

            { include always the forward flag, it'll be removed once the whole
              class has been parsed so that it can be used as a parent class
              of a nested class;
              Exception: for external classes this will be removed once the
              parent classes have been parsed }
            include(CurrentStructDef.ObjectOptions,oo_is_forward);

            if (cs_compilesystem in CurrentSettings.ModuleSwitches) then
              begin
                case current_objectdef.ObjectType of
                  odt_interfacecom :
                    if (CurrentStructDef.ObjName^='IUNKNOWN') then
                      Interface_IUnknown:=current_objectdef
                    else
                    if (CurrentStructDef.ObjName^='IDISPATCH') then
                      Interface_IDispatch:=current_objectdef;
                  odt_class :
                    if (CurrentStructDef.ObjName^='TOBJECT') then
                      Class_TObject:=current_objectdef;

                  else
                    ;
                end;
              end;
            if (CurrentModule.ModuleName^='OBJCBASE') then
              begin
                case current_objectdef.ObjectType of
                  odt_objcclass:
                    if (current_objectdef.ObjName^='Protocol') then
                      ObjC_ProtocolType:=current_objectdef;
                  else
                    ;
                end;
              end;
          end;

        { usage of specialized type inside its generic template }
        if Assigned(GenericDef) then
          CurrentSpecializeDef:=CurrentStructDef;
        { reject declaration of generic class inside generic class }
        if Assigned(genericlist) then
          CurrentGenericDef:=CurrentStructDef;

        { nested types of specializations are specializations as well }
        if Assigned(old_current_structdef) and
            (df_specialization in old_current_structdef.DefOptions) then
          include(CurrentStructDef.DefOptions,df_specialization);
        if Assigned(old_current_structdef) and
            (df_generic in old_current_structdef.DefOptions) then
          begin
            include(CurrentStructDef.DefOptions,df_generic);
            CurrentGenericDef:=CurrentStructDef;
          end;

        { set published flag in $M+ mode, it can also be inherited and will
          be added when the parent class set with tobjectdef.set_parent (PFV) }
        if (cs_generate_rtti in CurrentSettings.LocalSwitches) and
           (current_objectdef.ObjectType in [odt_interfacecom,odt_interfacecorba,odt_class,odt_helper]) then
          include(CurrentStructDef.ObjectOptions,oo_can_have_published);


        if ObjectType in [odt_objcclass,odt_objcprotocol,odt_objccategory] then
          parse_object_options;

        { forward def? }
        if CurrentScanner.token=_SEMICOLON then
          begin
            if Assigned(fd) then
              Message1(parser_e_type_alread_forward,n)
            else
              begin
                if Is_ObjectPascal_Helper(CurrentStructDef) then
                  consume(_FOR);
                { add to the list of definitions to check that the forward
                  is resolved. this is required for delphi mode }
                CurrentModule.CheckForwardDefs.add(CurrentStructDef);

                SymTableStack.push(CurrentStructDef.SymTable);
                insert_generic_parameter_types(CurrentStructDef,GenericDef,genericlist,false);
                { when we are parsing a generic already then this is a generic as
                  well }
                if old_parse_generic then
                  include(CurrentStructDef.DefOptions,df_generic);
                parse_generic:=(df_generic in CurrentStructDef.DefOptions);

                { *don't* add the strict private symbol for non-Delphi modes for
                  forward defs }

                SymTableStack.pop(CurrentStructDef.SymTable);
              end;
          end
        else
          begin
            { change objccategories into objcclass helpers }
            if (ObjectType=odt_objccategory) then
              begin
                current_objectdef.ObjectType:=odt_objcclass;
                include(CurrentStructDef.ObjectOptions,oo_is_classhelper);
              end;

            { include the class helper flag for Object Pascal helpers }
            if (ObjectType=odt_helper) then
              include(current_objectdef.ObjectOptions,oo_is_classhelper);

            { parse list of options (abstract / sealed) }
            if not(ObjectType in [odt_objcclass,odt_objcprotocol,odt_objccategory]) then
              parse_object_options;

            SymTableStack.push(CurrentStructDef.SymTable);
            insert_generic_parameter_types(CurrentStructDef,GenericDef,genericlist,Assigned(fd));
            { when we are parsing a generic already then this is a generic as
              well }
            if old_parse_generic then
              include(CurrentStructDef.DefOptions, df_generic);
            parse_generic:=(df_generic in CurrentStructDef.DefOptions);

            { in non-Delphi modes we need a strict private symbol without type
              count and type parameters in the name to simplify resolving }
            maybe_insert_generic_rename_symbol(n,genericlist);

            { parse list of parent classes }
            { for record helpers in mode Delphi this is not allowed }
            if not (Is_ObjectPascal_Helper(current_objectdef) and
                (m_delphi in CurrentSettings.ModeSwitches) and
                (HelperType=ht_record)) then
              parse_parent_classes;

            { for external classes we remove the external flag here already }
            if oo_is_external in current_objectdef.ObjectOptions then
              exclude(current_objectdef.ObjectOptions,oo_is_forward);

            { parse extended type for helpers }
            if Is_ObjectPascal_Helper(CurrentStructDef) then
              parse_extended_type(HelperType);

            if Is_Interface(current_objectdef) and
                Is_Interface(current_objectdef.ChildOf) and
                (oo_is_invokable in TObjectDef(current_objectdef.ChildOf).ObjectOptions) then
              include(current_objectdef.ObjectOptions,oo_is_invokable);

            { parse optional GUID for interfaces }
            parse_guid;

            { classes can handle links to themself not only inside type blocks
              but in const blocks too. Additionally this is needed to parse parameters that are
              specializations of the currently parsed type in basically everything except C++ and
              ObjC classes. To make this possible we need to set their symbols to real defs instead
              of errordef }

            if Assigned(objsym) and not (ObjectType in [odt_cppclass,odt_objccategory,odt_objcclass,odt_objcprotocol]) then
              begin
                olddef:=TTypeSym(objsym).TypeDef;
                TTypeSym(objsym).TypeDef:=CurrentStructDef;
                CurrentStructDef.TypeSym:=objsym;
              end
            else
              olddef:=nil;

            { if set explicitly, apply $RTTI directive to current object }
            if CurrentModule.RTTIDirective.clause<>rtc_none then
              CurrentStructDef.Apply_RTTI_Directive(CurrentModule.RTTIDirective)
            else
              { if not set, and class has a parent, take parent object settings }
              if (ObjectType = odt_class) and Assigned(current_objectdef.ChildOf) then
                CurrentStructDef.Apply_RTTI_Directive(current_objectdef.ChildOf.RTTI);

            { generate TObject VMT space }
            { We must insert the VMT at the start for system.tobject, and class_tobject was already set.
              The cs_compilesystem is superfluous, but we add it for safety.

            }
            if (current_objectdef=Class_TObject) and (cs_compilesystem in CurrentSettings.ModuleSwitches) then
              current_objectdef.InsertVMT;

            { parse and insert object members }
            parse_object_members;

            if Assigned(olddef) then
              begin
                TTypeSym(objsym).TypeDef:=olddef;
                CurrentStructDef.TypeSym:=nil;
              end;


            SymTableStack.pop(CurrentStructDef.SymTable);

            exclude(CurrentStructDef.ObjectOptions,oo_is_forward);
          end;

        { generate vmt space if needed }
        {
           Here we only do it for non-classes, all classes have it since they depend on TObject
           so their vmt is already created when TObject was parsed.
        }
        if not(oo_has_vmt in CurrentStructDef.ObjectOptions) and
           not(current_objectdef.ObjectType in [odt_class]) and
           not(oo_is_forward in CurrentStructDef.ObjectOptions) and
           not(parse_generic) and
           { no vmt for helpers ever }
           not Is_ObjectPascal_Helper(CurrentStructDef) and
            ([oo_has_virtual,oo_has_constructor,oo_has_destructor]*CurrentStructDef.ObjectOptions<>[])
           then
          current_objectdef.InsertVMT;

        { for implemented classes with a vmt check if there is a constructor }
        if (oo_has_vmt in CurrentStructDef.ObjectOptions) and
           not(oo_is_forward in CurrentStructDef.ObjectOptions) and
           not(oo_has_constructor in CurrentStructDef.ObjectOptions) and
           not Is_ObjC_Class_Or_Protocol(CurrentStructDef) then
          Message1(parser_w_virtual_without_constructor,CurrentStructDef.ObjRealName^);

        if Is_Interface(CurrentStructDef) or
           Is_ObjCProtocol(CurrentStructDef) then
          setinterfacemethodoptions
        else if Is_ObjCClass(CurrentStructDef) then
          setobjcclassmethodoptions;

        { we need to add this helper to the extendeddefs of the current module,
          as the global and static symtable are not pushed onto the symtable
          stack again (it will be removed when popping the symtable) }
        if Is_ObjectPascal_Helper(CurrentStructDef) and
            (current_objectdef.ExtendedDef.typ<>errordef) then
          begin
            { the topmost symtable must be a static symtable }
            st:=CurrentStructDef.owner;
            while st.SymTableType in [objectsymtable,recordsymtable] do
              st:=st.DefOwner.owner;
            if st.SymTableType in [staticsymtable,GlobalSymTable] then
              begin
                if current_objectdef.ExtendedDef.typ in [recorddef,objectdef] then
                  s:=Make_MangledName('',TAbstractRecordDef(current_objectdef.ExtendedDef).SymTable,'')
                else
                  s:=Make_MangledName('',current_objectdef.ExtendedDef.owner,current_objectdef.ExtendedDef.TypeSym.name);
                Message1(sym_d_adding_helper_for,s);
                list:=TFPObjectList(CurrentModule.ExtendedDefs.Find(s));
                if not Assigned(list) then
                  begin
                    list:=TFPObjectList.Create(false);
                    CurrentModule.ExtendedDefs.Add(s, list);
                  end;
                list.add(CurrentStructDef);
              end;
          end;
        TAbstractRecordSymTable(current_objectdef.SymTable).AddAlignmentPadding;

        { return defined objectdef }
        result:=current_objectdef;

        { restore old state }
        CurrentStructDef:=old_current_structdef;
        CurrentGenericDef:=old_current_genericdef;
        CurrentSpecializeDef:=old_current_specializedef;
        parse_generic:=old_parse_generic;
      end;

end.
