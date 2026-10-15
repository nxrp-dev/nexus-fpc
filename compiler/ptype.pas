{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Does parsing types for Free Pascal

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
unit ptype;

{$i fpcdefs.inc}

interface

    uses
       globtype,cclasses,
       symtype,symdef,symbase;

    type
      TSingleTypeOption=(
        stoIsForwardDef,          { foward declaration         }
        stoAllowTypeDef,          { allow type definitions     }
        stoAllowSpecialization,   { allow type specialization  }
        stoParseClassParent       { parse of parent class type }
      );
      TSingleTypeOptions=set of TSingleTypeOption;

    procedure resolve_forward_types;

    { reads a string, file type or a type identifier }
    procedure single_type(out def:TDef;options:TSingleTypeOptions);
    { ... but rejects types that cannot be returned from functions }
    function result_type(options:TSingleTypeOptions):TDef;

    { reads any type declaration, where the resulting type will get name as type identifier }
    procedure read_named_type(var def:TDef;const newsym:TSym;genericdef:TStoredDef;genericlist:tfphashobjectlist;parseprocvardir:boolean;var hadtypetoken:boolean);

    { reads any type declaration }
    procedure read_anon_type(var def : TDef;parseprocvardir:boolean;genericdef:TStoredDef);

    { parse nested type declaration of the def (typedef) }
    procedure parse_nested_types(var def: TDef; isforwarddef,allowspecialization: boolean; currentstructstack: tfpobjectlist);


    { parse hint directives (platform, deprecated, ...) for a procdef }
    procedure maybe_parse_hint_directives(pd:TProcDef);

implementation

    uses
       { common }
       cutils,
       { global }
       globals,tokens,verbose,constexp,
       systems,
       { symtable }
       symconst,symsym,symtable,symcreat,
       defutil,defcmp,
       { modules }
       fmodule,
       { pass 1 }
       node,
       nset,ncnv,ncon,nld,
       { parser }
       scanner,
       pbase,pexpr,pdecsub,pdecvar,pdecobj,pdecl,pgenutil,pparautl,procdefutil
       ;


    procedure maybe_parse_hint_directives(pd:TProcDef);
      var
        dummysymoptions : TSymOptions;
        deprecatedmsg : pshortstring;
      begin
        if assigned(pd) then
          begin
            dummysymoptions:=pd.symoptions;
            deprecatedmsg:=pd.deprecatedmsg;
          end
        else
          begin
            dummysymoptions:=[];
            deprecatedmsg:=nil;
          end;
        while try_consume_hintdirective(dummysymoptions,deprecatedmsg) do
          consume(_SEMICOLON);
        if assigned(pd) then
          begin
            pd.symoptions:=pd.symoptions+dummysymoptions;
            if sp_has_deprecated_msg in dummysymoptions then
              pd.deprecatedmsg:=deprecatedmsg;
          end
        else
          stringdispose(deprecatedmsg);
      end;


    procedure resolve_forward_types;
      var
        i: longint;
        tmp,
        hpd,
        def : TDef;
        srsym  : TSym;
        srsymtable : TSymTable;
        hs : string;
        fileinfo : TFilePosInfo;
      begin
        for i:=0 to CurrentModule.checkforwarddefs.Count-1 do
          begin
            def:=TDef(CurrentModule.checkforwarddefs[i]);
            case def.typ of
              pointerdef,
              classrefdef :
                begin
                  { classrefdef inherits from pointerdef }
                  hpd:=TAbstractPointerDef(def).pointeddef;
                  { still a forward def ? }
                  if hpd.typ=forwarddef then
                   begin
                     { try to resolve the forward }
                     if not assigned(TForwardDef(hpd).tosymname) then
                       internalerror(200211201);
                     hs:=TForwardDef(hpd).tosymname^;
                     searchsym(upper(hs),srsym,srsymtable);
                     { we don't need the forwarddef anymore, dispose it }
                     hpd.free;
                     hpd := nil;
                     TAbstractPointerDef(def).pointeddef:=nil; { if error occurs }
                     { was a type sym found ? }
                     if assigned(srsym) and
                        (srsym.typ=typesym) then
                      begin
                        if (sp_generic_dummy in srsym.symoptions) and
                            not (TTypeSym(srsym).typedef.typ=undefineddef) and
                            assigned(def.owner.defowner) then
                          begin
                            { is the forward def part of a specialization? }
                            tmp:=TDef(def.owner.defowner);
                            while not TStoredDef(tmp).is_specialization and assigned(tmp.owner.defowner) do
                              tmp:=TDef(tmp.owner.defowner);
                            { if the genericdef of the specialization is the same as the
                              def the dummy points to, then update the found symbol }
                            if TStoredDef(tmp).is_specialization and
                                (TStoredDef(tmp).genericdef=TTypeSym(srsym).typedef) then
                              srsym:=TStoredDef(tmp).typesym;
                          end;
                        TAbstractPointerDef(def).pointeddef:=TTypeSym(srsym).typedef;
                        { correctly set the generic/specialization flags and the genericdef }
                        if df_generic in TStoredDef(TAbstractPointerDef(def).pointeddef).defoptions then
                          include(TStoredDef(def).defoptions,df_generic);
                        if df_specialization in TStoredDef(TAbstractPointerDef(def).pointeddef).defoptions then
                          begin
                            include(TStoredDef(def).defoptions,df_specialization);
                            case def.typ of
                              pointerdef:
                                TStoredDef(def).genericdef:=cpointerdef.getreusable(TStoredDef(TAbstractPointerDef(def).pointeddef).genericdef);
                              classrefdef:
                                TStoredDef(def).genericdef:=cclassrefdef.create(TStoredDef(TAbstractPointerDef(def).pointeddef).genericdef);
                              else
                                internalerror(2016120901);
                            end;
                          end;
                        { avoid wrong unused warnings web bug 801 PM }
                        inc(TTypeSym(srsym).refs);
                        { we need a class type for classrefdef }
                        if (def.typ=classrefdef) and
                           not(is_class(TTypeSym(srsym).typedef)) and
                           not(is_objcclass(TTypeSym(srsym).typedef)) and
                           not(is_javaclass(TTypeSym(srsym).typedef)) then
                          MessagePos1(def.typesym.fileinfo,type_e_class_type_expected,TTypeSym(srsym).typedef.typename);
                        { this could also be a generic dummy that was not
                          overridden with a specific type }
                        if (sp_generic_dummy in srsym.symoptions) and
                            (
                              (TTypeSym(srsym).typedef.typ=undefineddef) or
                              (
                                { or an unspecialized generic symbol, which is
                                  the case for generics defined in non-Delphi
                                  modes }
                                TStoredDef(TTypeSym(srsym).typedef).is_generic and
                                not defs_belong_to_same_generic(def,TTypeSym(srsym).typedef)
                              )
                            ) then
                          begin
                            if assigned(def.typesym) then
                              fileinfo:=def.typesym.fileinfo
                            else
                              { this is the case for inline pointer declarations }
                              fileinfo:=srsym.fileinfo;
                            MessagePos(fileinfo,parser_e_no_generics_as_types);
                          end;
                      end
                     else
                      begin
                        Message1(sym_e_forward_type_not_resolved,hs);
                        { try to recover }
                        TAbstractPointerDef(def).pointeddef:=generrordef;
                      end;
                   end;
                end;
              objectdef :
                begin
                  { give an error as the implementation may follow in an
                    other type block which is allowed by FPC modes }
                  if not(m_fpc in CurrentSettings.modeswitches) and
                     (oo_is_forward in TObjectDef(def).objectoptions) then
                    MessagePos1(def.typesym.fileinfo,type_e_type_is_not_completly_defined,def.typename);
                  { generate specializations for generic forwarddefs }
                  if not (oo_is_forward in TObjectDef(def).objectoptions) and
                      TStoredDef(def).is_generic then
                    generate_specializations_for_forwarddef(def);
                 end;
              else
                internalerror(200811071);
            end;
          end;
        CurrentModule.checkforwarddefs.clear;
      end;


    procedure id_type(var def : TDef;isforwarddef,checkcurrentrecdef,allowgenericsyms,allowunitsym:boolean;out srsym:TSym;out srsymtable:TSymTable;out is_specialize,is_unit_specific:boolean); forward;


    { def is the outermost type in which other types have to be searched

      isforward indicates whether the current definition can be a forward definition

      if assigned, currentstructstack is a list of tabstractrecorddefs that, from
      last to first, are child types of def that are not yet visible via the
      normal symtable searching routines because they are types that are currently
      being parsed (so using id_type on them after pushing def on the
      symtablestack would result in errors because they'd come back as errordef)
    }
    procedure parse_nested_types(var def: TDef; isforwarddef,allowspecialization: boolean; currentstructstack: tfpobjectlist);
      var
        t2: TDef;
        structstackindex: longint;
        srsym: TSym;
        srsymtable: TSymTable;
        oldsymtablestack: TSymTableStack;
        isspecialize,
        isunitspecific : boolean;
      begin
        if assigned(currentstructstack) then
          structstackindex:=currentstructstack.count-1
        else
          structstackindex:=-1;
        { handle types inside classes, e.g. TNode.TLongint }
        while (CurrentScanner.token=_POINT) do
          begin
             if is_class_or_object(def) or is_record(def) or is_java_class_or_interface(def) then
               begin
                 if (def.typ=objectdef) then
                   def:=find_real_class_definition(TObjectDef(def),false);
                 consume(_POINT);
                 if (structstackindex>=0) and
                    (TAbstractRecordDef(currentstructstack[structstackindex]).objname^=CurrentScanner.pattern) then
                   begin
                     def:=TDef(currentstructstack[structstackindex]);
                     dec(structstackindex);
                     consume(_ID);
                   end
                 else
                   begin
                     structstackindex:=-1;
                     oldsymtablestack:=symtablestack;
                     symtablestack:=TSymTableStack.create;
                     symtablestack.push(TAbstractRecordDef(def).symtable);
                     t2:=generrordef;
                     id_type(t2,isforwarddef,false,false,false,srsym,srsymtable,isspecialize,isunitspecific);
                     symtablestack.pop(TAbstractRecordDef(def).symtable);
                     symtablestack.free;
                     symtablestack:=oldsymtablestack;
                     if isspecialize or
                         (
                           (m_delphi in CurrentSettings.modeswitches) and
                           (CurrentScanner.token=_LSHARPBRACKET)
                         ) then
                       begin
                         if not allowspecialization then
                           Message(parser_e_no_local_para_def);
                         generate_specialization(t2,isunitspecific,false,'',srsym.name,srsymtable);
                       end;
                     def:=t2;
                   end;
               end
             else
               break;
          end;
      end;


    function try_parse_structdef_nested_type(out def: TDef; basedef: TAbstractRecordDef; isfowarddef: boolean): boolean;
      var
        structdef : TDef;
        structdefstack : tfpobjectlist;
      begin
         def:=nil;
         { use of current parsed object:
           classes, objects, records can be used also in themself }
         structdef:=basedef;
         structdefstack:=nil;
         while assigned(structdef) and (structdef.typ in [objectdef,recorddef]) do
           begin
             if (TAbstractRecordDef(structdef).objname^=CurrentScanner.pattern) then
               begin
                 consume(_ID);
                 def:=structdef;
                 { we found the top-most match, now check how far down we can
                   follow }
                 structdefstack:=tfpobjectlist.create(false);
                 structdef:=basedef;
                 while (structdef<>def) do
                   begin
                     structdefstack.add(structdef);
                     structdef:=TAbstractRecordDef(structdef.owner.defowner);
                   end;
                 parse_nested_types(def,isfowarddef,true,structdefstack);
                 structdefstack.free;
                 structdefstack := nil;
                 result:=true;
                 exit;
               end;
             structdef:=TDef(TAbstractRecordDef(structdef).owner.defowner);
           end;
         result:=false;
      end;

    procedure id_type(var def : TDef;isforwarddef,checkcurrentrecdef,allowgenericsyms,allowunitsym:boolean;out srsym:TSym;out srsymtable:TSymTable;out is_specialize,is_unit_specific:boolean);
    { reads a type definition }
    { to a appropriating tdef, s gets the name of   }
    { the type to allow name mangling          }
      var
        not_a_type : boolean;
        pos : TFilePosInfo;
        s,sorg : TIDString;
        t : ttoken;
      begin
         srsym:=nil;
         srsymtable:=nil;
         is_specialize:=false;
         is_unit_specific:=false;
         s:=CurrentScanner.pattern;
         sorg:=CurrentScanner.orgpattern;
         pos:=CurrentTokenPos;
         { use of current parsed object:
           classes, objects, records can be used also in themself }
         if checkcurrentrecdef and
            try_parse_structdef_nested_type(def,CurrentStructDef,isforwarddef) then
           exit;
         if not allowunitsym and not (m_delphi in CurrentSettings.modeswitches) and (CurrentScanner.idtoken=_SPECIALIZE) then
           begin
             consume(_ID);
             is_specialize:=true;
             s:=CurrentScanner.pattern;
             sorg:=CurrentScanner.orgpattern;
             pos:=CurrentTokenPos;
           end;
         { Use the special searchsym_type that search only types }
         if not searchsym_type(s,srsym,srsymtable) then
           { for a good error message we need to know whether the symbol really did not exist or
             whether we found a non-type one }
           not_a_type:=searchsym(s,srsym,srsymtable)
         else
           not_a_type:=false;
         { handle unit specification like System.Writeln }
         if allowunitsym then
           is_unit_specific:=try_consume_unitsym(srsym,srsymtable,t,[cuf_consume_id,cuf_allow_specialize],is_specialize,s)
         else
           begin
             t:=_ID;
             is_unit_specific:=false;
           end;
         consume(t);
         if not_a_type then
           begin
             { reset the symbol and symtable to not leak any unexpected values }
             srsym:=nil;
             srsymtable:=nil;
           end;
         { Types are first defined with an error def before assigning
           the real type so check if it's an errordef. if so then
           give an error. Only check for typesyms in the current symbol
           table as forwarddef are not resolved directly }
         if assigned(srsym) and
            (srsym.typ=typesym) and
            ((TTypeSym(srsym).typedef.typ=errordef) or
            (not allowgenericsyms and
            (TTypeSym(srsym).typedef.typ=undefineddef) and
            not (sp_generic_para in srsym.symoptions) and
            not (sp_explicitrename in srsym.symoptions) and
            not assigned(srsym.owner.defowner) and
            { use df_generic instead of is_generic to allow aliases in nested types as well }
            not (df_generic in TStoredDef(srsym.owner.defowner).defoptions))) then
          begin
            Message1(type_e_type_is_not_completly_defined,TTypeSym(srsym).realname);
            def:=generrordef;
            exit;
          end;
         { are we parsing a possible forward def ? }
         if isforwarddef and
            not(is_unit_specific) then
           begin
             def:=cforwarddef.create(sorg,pos);
             exit;
           end;
         { unknown sym ? }
         if not assigned(srsym) and not not_a_type then
          begin
            Message1(sym_e_id_not_found,sorg);
            def:=generrordef;
            exit;
          end;
         { type sym ? }
         if not_a_type or (srsym.typ<>typesym) then
          begin
            Message(type_e_type_id_expected);
            def:=generrordef;
            exit;
          end;
         { Give an error when referring to an errordef }
         if (TTypeSym(srsym).typedef.typ=errordef) then
          begin
            Message(sym_e_error_in_type_def);
            def:=generrordef;
            exit;
          end;
         { In non-Delphi modes the class/record name of a generic might be used
           in the declaration of sub types without type parameters; in that case
           we need to check by name as the link from the dummy symbol to the
           current type is not yet established }
         if (sp_generic_dummy in srsym.symoptions) and
             assigned(CurrentStructDef) and
             (df_generic in CurrentStructDef.defoptions) and
             (TTypeSym(srsym).typedef.typ=undefineddef) and
             not (m_delphi in CurrentSettings.modeswitches) then
           begin
             def:=get_generic_in_hierarchy_by_name(srsym,CurrentStructDef);
             if assigned(def) then
               exit;
           end;
        def:=TTypeSym(srsym).typedef;
      end;


    procedure single_type(out def:TDef;options:TSingleTypeOptions);

       function handle_dummysym(sym:TSym):TDef;
         begin
           sym:=resolve_generic_dummysym(sym.name);
           if assigned(sym) and
               not (sp_generic_dummy in sym.symoptions) and
               (sym.typ=typesym) then
             result:=TTypeSym(sym).typedef
           else
             begin
               Message(parser_e_no_generics_as_types);
               result:=generrordef;
             end;
         end;

       var
         t2 : TDef;
         isunitspecific,
         isspecialize,
         dospecialize,
         again : boolean;
         srsym : TSym;
         srsymtable : TSymTable;
         symname : tsymstr;
       begin
         dospecialize:=false;
         isunitspecific:=false;
         srsymtable:=nil;
         srsym:=nil;
         repeat
           again:=false;
             case CurrentScanner.token of
               _STRING:
                 string_dec(def,stoAllowTypeDef in options);
               _FILE:
                 begin
                    consume(_FILE);
                    if (CurrentScanner.token=_OF) then
                      begin
                         if not(stoAllowTypeDef in options) then
                           Message(parser_e_no_local_para_def);
                         consume(_OF);
                         single_type(t2,[stoAllowTypeDef]);
                         if is_managed_type(t2) then
                           Message(parser_e_no_refcounted_typed_file);
                         def:=cfiledef.createtyped(t2);
                      end
                    else
                      def:=cfiletype;
                 end;

               _ID:
                 begin
                   if not (m_delphi in CurrentSettings.modeswitches) and try_to_consume(_SPECIALIZE) then
                     begin
                       if ([stoAllowSpecialization,stoAllowTypeDef] * options = []) then
                         begin
                           Message(parser_e_no_local_para_def);

                           { try to recover }
                           while CurrentScanner.token<>_SEMICOLON do
                             consume(CurrentScanner.token);
                           def:=generrordef;
                         end
                       else
                         begin
                           dospecialize:=true;
                           again:=true;
                         end;
                     end
                   else
                     begin
                       id_type(def,stoIsForwardDef in options,true,true,not dospecialize or ([stoAllowSpecialization,stoAllowTypeDef]*options=[]),srsym,srsymtable,isspecialize,isunitspecific);
                       if isspecialize and dospecialize then
                         internalerror(2015021301);
                       if isspecialize then
                         dospecialize:=true;
                       parse_nested_types(def,stoIsForwardDef in options,[stoAllowSpecialization,stoAllowTypeDef]*options<>[],nil);
                     end;
                 end;

               else
                 begin
                   message(type_e_type_id_expected);
                   def:=generrordef;
                 end;
            end;
        until not again;
        if ([stoAllowSpecialization,stoAllowTypeDef] * options <> []) and
           (m_delphi in CurrentSettings.modeswitches) then
          dospecialize:=CurrentScanner.token in [_LSHARPBRACKET,_LT];
        if dospecialize and
            (def.typ=forwarddef) then
          begin
            if not assigned(srsym) or not (srsym.typ=typesym) then
              begin
                Message1(type_e_type_is_not_completly_defined,def.typename);
                def:=generrordef;
                dospecialize:=false;
              end;
          end;
        { recover from error? }
        if def.typ=errordef then
          begin
            while (CurrentScanner.token<>_SEMICOLON) and (CurrentScanner.token<>_RKLAMMER) do
              consume(CurrentScanner.token);
          end
        else if dospecialize then
          begin
            if def.typ=forwarddef then
              def:=TTypeSym(srsym).typedef;
            if assigned(srsym) then
              symname:=srsym.name
            else if assigned(def.typesym) then
              begin
                symname:=def.typesym.name;
                srsymtable:=def.typesym.owner;
              end
            else if (def.typ=objectdef) then
              begin
                symname:=TObjectDef(def).objname^;
                if assigned(def.owner) then
                  srsymtable:=def.owner
                else
                  srsymtable:=symtablestack.top;
              end
            else
              symname:='';
            generate_specialization(def,isunitspecific,stoParseClassParent in options,'',symname,srsymtable);
            parse_nested_types(def,stoIsForwardDef in options,[stoAllowSpecialization,stoAllowTypeDef]*options<>[],nil);
          end
        else
          begin
            if assigned(CurrentSpecializeDef) and (def=CurrentSpecializeDef.genericdef) then
              begin
                def:=CurrentSpecializeDef
              end
            else if (def=CurrentGenericDef) then
              begin
                def:=CurrentGenericDef
              end
            { when parsing a nested specialization in non-Delphi mode it might
              use the name of the topmost generic without type paramaters, thus
              def will contain the generic definition, but we need a reference
              to the specialization of that generic }
            { TODO : only in non-Delphi modes? }
            else if assigned(CurrentStructDef) and
                (df_specialization in CurrentStructDef.defoptions) and
                return_specialization_of_generic(CurrentStructDef,def,t2) then
              begin
                def:=t2
              end
            else if TStoredDef(def).is_generic and
                not
                  (
                    parse_generic and
                    (
                      { if this is a generic parameter than it has already been checked that this is
                        a valid usage of a generic }
                      (sp_generic_para in srsym.symoptions) or
                      (
                        (CurrentGenericDef.typ in [recorddef,objectdef]) and
                        (
                          { if both defs belong to the same generic (e.g. both are
                            subtypes) then we must allow the usage }
                          defs_belong_to_same_generic(def,CurrentGenericDef) or
                          { this is needed to correctly resolve "type Foo=SomeGeneric<T>"
                            declarations inside a generic }
                          sym_is_owned_by(srsym,TAbstractRecordDef(CurrentGenericDef).symtable)
                        )
                      )
                    )
                  )
                then
              begin
                def:=handle_dummysym(srsym);
              end
            else if (def.typ=undefineddef) and
                (sp_generic_dummy in srsym.symoptions) then
              begin
                if parse_generic and
                    (CurrentGenericDef.typ in [recorddef,objectdef]) and
                    (Pos(upper(srsym.realname),TAbstractRecordDef(CurrentGenericDef).objname^)=1) then
                  begin
                    if m_delphi in CurrentSettings.modeswitches then
                      begin
                        def:=handle_dummysym(srsym);
                      end
                    else
                      def:=CurrentGenericDef;
                  end
                else
                  begin
                    def:=handle_dummysym(srsym);
                  end;
              end
            else if is_classhelper(def) and
                not (stoParseClassParent in options) then
              begin
                Message(parser_e_no_category_as_types);
                def:=generrordef
              end
          end;
      end;


    function result_type(options:TSingleTypeOptions):TDef;
      begin
        single_type(result,options);
        { file types cannot be function results }
        if result.typ=filedef then
          message(parser_e_illegal_function_result);
      end;

    procedure parse_record_members(recsym:TSym);

      function IsAnonOrLocal: Boolean;
        begin
          result:=(CurrentStructDef.objname^='') or
                  not(symtablestack.stack^.next^.symtable.symtabletype in [globalsymtable,staticsymtable,objectsymtable,recordsymtable]);
        end;

      var
        pd : TProcDef;
        oldparse_only: boolean;
        member_blocktype : TBlockType;
        hadgeneric,
        fields_allowed, is_classdef, classfields, threadvarfields: boolean;
        vdoptions: tvar_dec_options;
        rtti_attrs_def: TRTTIAttributeList;
        fldCount : Integer;
        attr_element_count : Integer;

      procedure check_unbound_attributes;
        begin
          if assigned(rtti_attrs_def) and (rtti_attrs_def.GetAttributeCount>0) then
            Message1(parser_e_unbound_attribute,TRTTIAttribute(rtti_attrs_def.RTTIAttributes[0]).typesym.prettyname);
          rtti_attrs_def.free;
          rtti_attrs_def:=nil;
        end;

      begin
        { empty record declaration ? }
        if (CurrentScanner.token=_SEMICOLON) then
          Exit;

        CurrentStructDef.symtable.currentvisibility:=vis_public;
        fields_allowed:=true;
        is_classdef:=false;
        hadgeneric:=false;
        classfields:=false;
        threadvarfields:=false;
        member_blocktype:=bt_general;
        rtti_attrs_def := nil;
        repeat
          case CurrentScanner.token of
            _TYPE :
              begin
                check_unbound_attributes;
                consume(_TYPE);
                member_blocktype:=bt_type;

                { local and anonymous records can not have inner types. skip top record symtable }
                if IsAnonOrLocal then
                  Message(parser_e_no_types_in_local_anonymous_records);
              end;
            _VAR :
              begin
                check_unbound_attributes;
                consume(_VAR);
                fields_allowed:=true;
                member_blocktype:=bt_general;
                classfields:=is_classdef;
                threadvarfields:=false;
                is_classdef:=false;
              end;
            _THREADVAR :
              begin
                check_unbound_attributes;
                if not is_classdef then
                  begin
                    message(parser_e_threadvar_must_be_class);
                    { for error recovery we enforce class fields }
                    is_classdef:=true;
                  end;
                consume(_THREADVAR);
                fields_allowed:=true;
                member_blocktype:=bt_general;
                classfields:=is_classdef;
                threadvarfields:=true;
                is_classdef:=false;
              end;
            _CONST:
              begin
                check_unbound_attributes;
                consume(_CONST);
                member_blocktype:=bt_const;

                { local and anonymous records can not have constants. skip top record symtable }
                if IsAnonOrLocal then
                  Message(parser_e_no_consts_in_local_anonymous_records);
              end;
            _ID, _CASE, _OPERATOR :
              begin
                case CurrentScanner.idtoken of
                  _PRIVATE :
                    begin
                      check_unbound_attributes;
                       consume(_PRIVATE);
                       CurrentStructDef.symtable.currentvisibility:=vis_private;
                       include(CurrentStructDef.objectoptions,oo_has_private);
                       fields_allowed:=true;
                       is_classdef:=false;
                       classfields:=false;
                       threadvarfields:=false;
                       member_blocktype:=bt_general;
                     end;
                   _PROTECTED :
                     begin
                       check_unbound_attributes;
                       Message1(parser_e_not_allowed_in_record,tokeninfo^[_PROTECTED].str);
                       consume(_PROTECTED);
                       CurrentStructDef.symtable.currentvisibility:=vis_protected;
                       include(CurrentStructDef.objectoptions,oo_has_protected);
                       fields_allowed:=true;
                       is_classdef:=false;
                       classfields:=false;
                       threadvarfields:=false;
                       member_blocktype:=bt_general;
                     end;
                   _PUBLIC :
                     begin
                       check_unbound_attributes;
                       consume(_PUBLIC);
                       CurrentStructDef.symtable.currentvisibility:=vis_public;
                       fields_allowed:=true;
                       is_classdef:=false;
                       classfields:=false;
                       threadvarfields:=false;
                       member_blocktype:=bt_general;
                     end;
                   _PUBLISHED :
                     begin
                       check_unbound_attributes;
                       Message(parser_e_no_record_published);
                       consume(_PUBLISHED);
                       CurrentStructDef.symtable.currentvisibility:=vis_published;
                       fields_allowed:=true;
                       is_classdef:=false;
                       classfields:=false;
                       threadvarfields:=false;
                       member_blocktype:=bt_general;
                     end;
                   _STRICT :
                     begin
                        consume(_STRICT);
                        if CurrentScanner.token=_ID then
                          begin
                            case CurrentScanner.idtoken of
                              _PRIVATE:
                                begin
                                  consume(_PRIVATE);
                                  CurrentStructDef.symtable.currentvisibility:=vis_strictprivate;
                                  include(CurrentStructDef.objectoptions,oo_has_strictprivate);
                                end;
                              _PROTECTED:
                                begin
                                  { "strict protected" is not allowed for records }
                                  Message1(parser_e_not_allowed_in_record,tokeninfo^[_STRICT].str+' '+tokeninfo^[_PROTECTED].str);
                                  consume(_PROTECTED);
                                  CurrentStructDef.symtable.currentvisibility:=vis_strictprotected;
                                  include(CurrentStructDef.objectoptions,oo_has_strictprotected);
                                end;
                              else
                                message(parser_e_protected_or_private_expected);
                            end;
                          end
                        else
                          message(parser_e_protected_or_private_expected);
                        fields_allowed:=true;
                        is_classdef:=false;
                        classfields:=false;
                        threadvarfields:=false;
                        member_blocktype:=bt_general;
                     end
                    else
                    if is_classdef and (CurrentScanner.idtoken=_OPERATOR) then
                      begin
                        check_unbound_attributes;
                        pd:=parse_record_method_dec(CurrentStructDef,is_classdef,false);
                        fields_allowed:=false;
                        is_classdef:=false;
                      end
                    else
                      begin
                        if member_blocktype=bt_general then
                          begin
                            if (CurrentScanner.idtoken=_GENERIC) and
                                not (m_delphi in CurrentSettings.modeswitches) and
                                not fields_allowed then
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
                                if (not fields_allowed)and(CurrentScanner.idtoken<>_CASE) then
                                  Message(parser_e_field_not_allowed_here);
                                vdoptions:=[vd_record];
                                if classfields then
                                  include(vdoptions,vd_class);
                                if not (m_delphi in CurrentSettings.modeswitches) then
                                  include(vdoptions,vd_check_generic);
                                if threadvarfields then
                                  include(vdoptions,vd_threadvar);
                                fldCount:=CurrentStructDef.symtable.SymList.Count;
                                read_record_fields(vdoptions,nil,nil,hadgeneric,attr_element_count);
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
                                if assigned(rtti_attrs_def) then
                                  begin
                                  While (attr_element_count>1) do
                                    begin
                                    TRTTIAttributeList.copyandbind(rtti_attrs_def,(CurrentStructDef.symtable.SymList[fldCount] as TFieldVarSym).RTTIAttributeList);
                                    inc(fldcount);
                                    dec(attr_element_count);
                                    end;
                                  if fldCount<CurrentStructDef.symtable.SymList.Count then
                                    TRTTIAttributeList.bind(rtti_attrs_def,(CurrentStructDef.symtable.SymList[fldCount] as TFieldVarSym).RTTIAttributeList);
                                  end;
                              end;
                          end
                        else if member_blocktype=bt_type then
                          types_dec(true,hadgeneric, rtti_attrs_def)
                        else if member_blocktype=bt_const then
                          consts_dec(true,true,hadgeneric)
                        else
                          internalerror(201001110);
                      end;
                end;
              end;
            _PROPERTY :
              begin
                if IsAnonOrLocal then
                  Message(parser_e_no_properties_in_local_anonymous_records);
                struct_property_dec(is_classdef, rtti_attrs_def);
                fields_allowed:=false;
                is_classdef:=false;
              end;
            _CLASS:
              begin
                check_unbound_attributes;
                is_classdef:=false;
                { read class method/field/property }
                consume(_CLASS);
                { class modifier is only allowed for procedures, functions, }
                { constructors, destructors, fields and properties          }
                if (hadgeneric and not (CurrentScanner.token in [_FUNCTION,_PROCEDURE])) or
                    (not hadgeneric and (not ((CurrentScanner.token in [_FUNCTION,_PROCEDURE,_PROPERTY,_VAR,_DESTRUCTOR,_OPERATOR,_THREADVAR]) or (CurrentScanner.token=_CONSTRUCTOR)) and
                   not((CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_OPERATOR)))) then
                  Message(parser_e_procedure_or_function_expected);

                if IsAnonOrLocal then
                  Message(parser_e_no_class_in_local_anonymous_records);

                is_classdef:=true;
              end;
            _PROCEDURE,
            _FUNCTION:
              begin
                if IsAnonOrLocal then
                  Message(parser_e_no_methods_in_local_anonymous_records);
                pd:=parse_record_method_dec(CurrentStructDef,is_classdef,hadgeneric);
                if assigned(rtti_attrs_def) then
                  begin
                  TRTTIAttributeList.bind(rtti_attrs_def,pd.RTTIAttributeList);
                  rtti_attrs_def:=Nil;
                  end;
                hadgeneric:=false;
                fields_allowed:=false;
                is_classdef:=false;
              end;
            _CONSTRUCTOR :
              begin
                check_unbound_attributes;
                if IsAnonOrLocal then
                  Message(parser_e_no_methods_in_local_anonymous_records);
                if not is_classdef and (CurrentStructDef.symtable.currentvisibility <> vis_public) then
                  Message(parser_w_constructor_should_be_public);

                { only 1 class constructor is allowed }
                if is_classdef and (oo_has_class_constructor in CurrentStructDef.objectoptions) then
                  Message1(parser_e_only_one_class_constructor_allowed, CurrentStructDef.objrealname^);

                oldparse_only:=parse_only;
                parse_only:=true;
                if is_classdef then
                  pd:=class_constructor_head(CurrentStructDef)
                else
                  begin
                    pd:=constructor_head;
                    if pd.minparacount = 0 then
                      MessagePos(pd.procsym.fileinfo,parser_e_no_parameterless_constructor_in_records);
                  end;

                parse_only:=oldparse_only;
                fields_allowed:=false;
                is_classdef:=false;
              end;
            _DESTRUCTOR :
              begin
                check_unbound_attributes;
                if IsAnonOrLocal then
                  Message(parser_e_no_methods_in_local_anonymous_records);
                if not is_classdef then
                  Message(parser_e_no_destructor_in_records);

                { only 1 class destructor is allowed }
                if is_classdef and (oo_has_class_destructor in CurrentStructDef.objectoptions) then
                  Message1(parser_e_only_one_class_destructor_allowed, CurrentStructDef.objrealname^);

                oldparse_only:=parse_only;
                parse_only:=true;
                if is_classdef then
                  pd:=class_destructor_head(CurrentStructDef)
                else
                  pd:=destructor_head;

                parse_only:=oldparse_only;
                fields_allowed:=false;
                is_classdef:=false;
              end;
            _LECKKLAMMER:
              begin
                if m_prefixed_attributes in CurrentSettings.modeswitches then
                  parse_rttiattributes(rtti_attrs_def)
                else
                  consume(_ID);
              end;
            _END :
              begin
                consume(_END);
                break;
              end;
            else
              consume(_ID); { Give a ident expected message, like tp7 }
          end;
        until false;
      end;

    { reads a record declaration }
    function record_dec(const n:tidstring;recsym:TSym;genericdef:TStoredDef;genericlist:tfphashobjectlist):TDef;
      var
         olddef : TDef;

      procedure set_typesym;
        begin
          if not assigned(recsym) then
            exit;
          if TTypeSym(recsym).typedef=CurrentStructDef then
            exit;
          TTypeSym(recsym).typedef:=CurrentStructDef;
          CurrentStructDef.typesym:=recsym;
        end;

      procedure reset_typesym;
        begin
          if not assigned(recsym) then
            exit;
          if TTypeSym(recsym).typedef<>CurrentStructDef then
            exit;
          TTypeSym(recsym).typedef:=olddef;
          CurrentStructDef.typesym:=nil;
        end;

      var
         old_current_structdef: TAbstractRecordDef;
         old_current_genericdef,
         old_current_specializedef: TStoredDef;
         old_parse_generic: boolean;
         recst: TRecordSymTable;
         hadgendummy : boolean;
         alignment: Integer;
         dummyattrelcount : Integer;
      begin
         old_current_structdef:=CurrentStructDef;
         old_current_genericdef:=CurrentGenericDef;
         old_current_specializedef:=CurrentSpecializeDef;
         old_parse_generic:=parse_generic;

         CurrentGenericDef:=nil;
         CurrentSpecializeDef:=nil;
         { create recdef }
         recst:=TRecordSymTable.create(n,CurrentSettings.packrecords,CurrentSettings.alignment.recordalignmin);
         { can't use recst.realname^ instead of n, because recst.realname is
           nil in case of an empty name }
         CurrentStructDef:=crecorddef.create(n,recst);
         result:=CurrentStructDef;
         { insert in symtablestack }
         symtablestack.push(recst);

         { usage of specialized type inside its generic template }
         if assigned(genericdef) then
           CurrentSpecializeDef:=CurrentStructDef
         { reject declaration of generic class inside generic class }
         else if assigned(genericlist) then
           CurrentGenericDef:=CurrentStructDef;

         { nested types of specializations are specializations as well }
         if assigned(old_current_structdef) and
             (df_specialization in old_current_structdef.defoptions) then
           include(CurrentStructDef.defoptions,df_specialization);
         if assigned(old_current_structdef) and
             (df_generic in old_current_structdef.defoptions) then
           include(CurrentStructDef.defoptions,df_generic);

         insert_generic_parameter_types(CurrentStructDef,genericdef,genericlist,false);
         { when we are parsing a generic already then this is a generic as
           well }
         if old_parse_generic then
           include(CurrentStructDef.defoptions, df_generic);
         parse_generic:=(df_generic in CurrentStructDef.defoptions);
         if parse_generic and not assigned(CurrentGenericDef) then
           CurrentGenericDef:=CurrentStructDef;
         { in non-Delphi modes we need a strict private symbol without type
           count and type parameters in the name to simply resolving }
         maybe_insert_generic_rename_symbol(n,genericlist);
         { apply $RTTI directive to current object }
         CurrentStructDef.apply_rtti_directive(CurrentModule.rtti_directive);

         { the correct typesym<->def relationship is needed for example when
           parsing parameters that are specializations of the record, when
           using nested constants and such or when specializing the type
           itself as a pointer type }
         if assigned(recsym) then
           olddef:=TTypeSym(recsym).typedef
         else
           olddef:=nil;
         set_typesym;

         if m_advanced_records in CurrentSettings.modeswitches then
           begin
             parse_record_members(recsym);
           end
         else
           begin
             read_record_fields([vd_record],nil,nil,hadgendummy,dummyattrelcount);
             consume(_END);
            end;

         reset_typesym;

         if (CurrentScanner.token=_ID) and (CurrentScanner.pattern='ALIGN') then
           begin
             consume(_ID);
             alignment:=get_intconst.svalue;
             { "(alignment and not $7F) = 0" means it's between 0 and 127, and
               PopCnt = 1 for powers of 2 }
             if ((alignment and not $7F) <> 0) or (PopCnt(Byte(alignment))<>1) then
               message(scanner_e_illegal_alignment_directive)
             else
               begin
                 recst.recordalignment:=shortint(alignment);
                 recst.explicitrecordalignment:=shortint(alignment);
               end;
           end;
         { make the record size aligned (has to be done before inserting the
           parameters, because that may depend on the record's size) }
         recst.addalignmentpadding;
         { don't keep track of procdefs in a separate list, because the
           compiler may add additional procdefs (e.g. property wrappers for
           the jvm backend) }
         insert_struct_hidden_paras(TRecordDef(CurrentStructDef));
         { restore symtable stack }
         symtablestack.pop(recst);
         if TRecordDef(CurrentStructDef).is_packed and is_managed_type(CurrentStructDef) then
           Message(type_e_no_packed_inittable);
         { restore old state }
         parse_generic:=old_parse_generic;
         CurrentStructDef:=old_current_structdef;
         CurrentGenericDef:=old_current_genericdef;
         CurrentSpecializeDef:=old_current_specializedef;
      end;


    { reads a type definition and returns a pointer to it }
    procedure read_named_type(var def:TDef;const newsym:TSym;genericdef:TStoredDef;genericlist:tfphashobjectlist;parseprocvardir:boolean;var hadtypetoken:boolean);
      const
        SingleTypeOptionsInTypeBlock:array[Boolean] of TSingleTypeOptions = ([],[stoIsForwardDef]);
      var
        pt : TNode;
        tt2 : TDef;
        aktenumdef : TEnumDef;
        s : TIDString;
        l,v : TConstExprInt;
        oldpackrecords : longint;
        defpos,storepos : TFilePosInfo;
        name: TIDString;

        procedure expr_type;
        var
           pt1,pt2 : TNode;
           lv,hv   : TConstExprInt;
           old_block_type : TBlockType;
           dospecialize : boolean;
           newdef  : TDef;
           sym     : TSym;
           genstr  : string;
           gencount : longint;
        begin
           old_block_type:=block_type;
           dospecialize:=false;
           { use of current parsed object:
             classes, objects, records can be used also in themself }
           if (CurrentScanner.token=_ID) then
             if try_parse_structdef_nested_type(def,CurrentStructDef,false) then
               exit;
           { we can't accept a equal in type }
           pt1:=comp_expr([ef_type_only]);
           if try_to_consume(_POINTPOINT) then
             begin
               { get high value of range }
               pt2:=comp_expr([]);
               { make both the same type or give an error. This is not
                 done when both are integer values, because typecasting
                 between -3200..3200 will result in a signed-unsigned
                 conflict and give a range check error (PFV) }
               if not(is_integer(pt1.resultdef) and is_integer(pt2.resultdef)) then
                 inserttypeconv(pt1,pt2.resultdef);
               { both must be evaluated to constants now }
               if (pt1.nodetype=ordconstn) and
                  (pt2.nodetype=ordconstn) then
                 begin
                   lv:=tordconstnode(pt1).value;
                   hv:=tordconstnode(pt2).value;
                   { Check bounds }
                   if hv<lv then
                     message(parser_e_upper_lower_than_lower)
                   else if (lv.signed and (lv.svalue<0)) and (not hv.signed and (hv.uvalue>qword(high(int64)))) then
                     message(type_e_cant_eval_constant_expr)
                   else
                     begin
                       { All checks passed, create the new def }
                       case pt1.resultdef.typ of
                         enumdef :
                           def:=cenumdef.create_subrange(TEnumDef(pt1.resultdef),lv.svalue,hv.svalue);
                         orddef :
                           begin
                             if is_char(pt1.resultdef) then
                               def:=corddef.create(uchar,lv,hv,true)
                             else
                               if is_boolean(pt1.resultdef) then
                                 def:=corddef.create(pasbool1,lv,hv,true)
                               else if is_signed(pt1.resultdef) then
                                 def:=corddef.create(range_to_basetype(lv,hv),lv,hv,true)
                               else
                                 def:=corddef.create(range_to_basetype(lv,hv),lv,hv,true);
                           end;
                         else
                           internalerror(2019050527);
                       end;
                     end;
                 end
               else
                 Message(sym_e_error_in_type_def);
               pt2.free;
               pt2 := nil;
             end
           else
             begin
               { a simple type renaming or generic specialization }
               if (pt1.nodetype=typen) then
                 begin
                   def:=ttypenode(pt1).resultdef;
                   { Delphi mode specialization? }
                   if (m_delphi in CurrentSettings.modeswitches) then
                     dospecialize:=CurrentScanner.token=_LSHARPBRACKET
                   else
                     begin
                       dospecialize:=false;
                       { in non-Delphi modes we might get a inline specialization
                         without "specialize" or "<T>" of the same type we're
                         currently parsing, so we need to handle that special }
                       newdef:=nil;
                     end;
                   if not dospecialize and
                       assigned(ttypenode(pt1).typesym) and
                       (ttypenode(pt1).typesym.typ=typesym) and
                       (sp_generic_dummy in ttypenode(pt1).typesym.symoptions) and
                       assigned(CurrentStructDef) and
                       (
                         (
                           not (m_delphi in CurrentSettings.modeswitches) and
                           (TTypeSym(ttypenode(pt1).typesym).typedef.typ=undefineddef) and
                           (df_generic in CurrentStructDef.defoptions) and
                           (TTypeSym(ttypenode(pt1).typesym).typedef.owner=CurrentStructDef.owner) and
                           (upper(ttypenode(pt1).typesym.realname)=copy(CurrentStructDef.objname^,1,pos('$',CurrentStructDef.objname^)-1))
                         ) or (
                           { this could be a nested specialization which uses
                             the type name of a surrounding generic to
                             reference the specialization of said surrounding
                             class }
                           (df_specialization in CurrentStructDef.defoptions) and
                           return_specialization_of_generic(CurrentStructDef,TTypeSym(ttypenode(pt1).typesym).typedef,newdef)
                         )
                       )
                       then
                     begin
                       if assigned(newdef) then
                         def:=newdef
                       else
                         def:=CurrentStructDef;
                       if assigned(def) then
                         { handle nested types }
                         post_comp_expr_gendef(def)
                       else
                         def:=generrordef;
                     end;
                   if dospecialize then
                     begin
                       if not assigned(ttypenode(pt1).typesym) then
                         internalerror(2025103102);
                       generate_specialization(def,false,false,name,ttypenode(pt1).typesym.name,ttypenode(pt1).typesym.owner);
                       { handle nested types }
                       if assigned(def) then
                         post_comp_expr_gendef(def);
                     end
                   else
                     begin
                       if assigned(CurrentSpecializeDef) and (def=CurrentSpecializeDef.genericdef) then
                         begin
                           def:=CurrentSpecializeDef
                         end
                       else if (def=CurrentGenericDef) then
                         begin
                           def:=CurrentGenericDef
                         end
                       else if TStoredDef(def).is_generic and
                           { TODO : check once nested generics are allowed }
                           not
                             (
                               parse_generic and
                               (CurrentGenericDef.typ in [recorddef,objectdef]) and
                               (def.typ in [recorddef,objectdef]) and
                               (
                                 { if both defs belong to the same generic (e.g. both are
                                   subtypes) then we must allow the usage }
                                 defs_belong_to_same_generic(def,CurrentGenericDef) or
                                 { this is needed to correctly resolve "type Foo=SomeGeneric<T>"
                                   declarations inside a generic }
                                 (
                                   (ttypenode(pt1).typesym<>nil) and
                                   sym_is_owned_by(ttypenode(pt1).typesym,TAbstractRecordDef(CurrentGenericDef).symtable)
                                 )
                               )
                             )
                           then
                         begin
                           if assigned(def.typesym) then
                             begin
                               if TTypeSym(def.typesym).typedef.typ<>undefineddef then
                                 { non-Delphi modes... }
                                 split_generic_name(def.typesym.name,genstr,gencount)
                               else
                                 genstr:=def.typesym.name;
                               sym:=resolve_generic_dummysym(genstr);
                             end
                           else
                             sym:=nil;
                           if assigned(sym) and
                               not (sp_generic_dummy in sym.symoptions) and
                               (sym.typ=typesym) then
                             def:=TTypeSym(sym).typedef
                           else
                             begin
                               Message(parser_e_no_generics_as_types);
                               def:=generrordef;
                             end;
                         end
                       else if is_classhelper(def) then
                         begin
                           Message(parser_e_no_category_as_types);
                           def:=generrordef
                         end
                     end;
                 end
               else
                 Message(sym_e_error_in_type_def);
             end;
           pt1.free;
           pt1 := nil;
           block_type:=old_block_type;
        end;


      procedure set_dec;
        begin
          consume(_SET);
          consume(_OF);
          read_anon_type(tt2,true,nil);
          if assigned(tt2) then
           begin
             case tt2.typ of
               { don't forget that min can be negativ  PM }
               enumdef :
                 if (TEnumDef(tt2).min>=0) and
                    (TEnumDef(tt2).max<=255) then
                  // !! def:=csetdef.create(tt2,tenumdef(tt2.def).min,tenumdef(tt2.def).max),true)
                  def:=csetdef.create(tt2,TEnumDef(tt2).min,TEnumDef(tt2).max,true)
                 else
                  Message(sym_e_ill_type_decl_set);
               orddef :
                 begin
                   if (TOrdDef(tt2).ordtype=uwidechar) then
                     begin
                     if (m_default_unicodestring in CurrentSettings.modeswitches) then
                       begin
                         Message(parser_w_widechar_set_reduced);
                         def:=csetdef.create(cansichartype,TOrdDef(cansichartype).low.svalue,TOrdDef(cansichartype).high.svalue,true);
                       end
                     else
                       Message(sym_e_ill_type_decl_set);
                     end
                   else if (TOrdDef(tt2).ordtype<>uvoid) and
                      (TOrdDef(tt2).low>=0) then
                     // !! def:=csetdef.create(tt2,torddef(tt2.def).low,torddef(tt2.def).high),true)
                     if TOrdDef(tt2).high>int64(high(byte)) then
                       message(sym_e_ill_type_decl_set)
                     else
                       def:=csetdef.create(tt2,TOrdDef(tt2).low.svalue,TOrdDef(tt2).high.svalue,true)
                   else
                     Message(sym_e_ill_type_decl_set);
                 end;
               { generic parameter? }
               undefineddef:
                 { The element bounds are determined when specializing. }
                 def:=csetdef.create(tt2,0,255,true);
               else
                 Message(sym_e_ill_type_decl_set);
             end;
           end
          else
           def:=generrordef;
        end;


      procedure pointer_dec;
        var
          sym: TSym;
        begin
          consume(_CARET);
          single_type(tt2,
              SingleTypeOptionsInTypeBlock[block_type=bt_type]+[stoAllowSpecialization]
            );
          { in case of e.g. var or const sections we need to especially
            check that we don't use a generic dummy symbol }
          if (block_type<>bt_type) and
              (tt2.typ=undefineddef) and
              assigned(tt2.typesym) and
              (sp_generic_dummy in tt2.typesym.symoptions) then
            begin
              sym:=resolve_generic_dummysym(tt2.typesym.name);
              if assigned(sym) and
                  not (sp_generic_dummy in sym.symoptions) and
                  (sym.typ=typesym) then
                tt2:=TTypeSym(sym).typedef
              else
                Message(parser_e_no_generics_as_types);
            end;
          { don't use cpointerdef.getreusable() here, since this is a type
            declaration (-> must create new typedef) }
          def:=cpointerdef.create(tt2);
          if tt2.typ=forwarddef then
            CurrentModule.checkforwarddefs.add(def);
        end;


      procedure array_dec(is_packed:boolean;genericdef:TStoredDef;genericlist:tfphashobjectlist);
        var
          isgeneric : boolean;
          lowval,
          highval   : TConstExprInt;
          indexdef  : TDef;
          hdef      : TDef;
          arrdef    : TArrayDef;

        procedure setdefdecl(def:TDef);
          begin
            case def.typ of
              enumdef :
                begin
                  lowval:=TEnumDef(def).min;
                  highval:=TEnumDef(def).max;
                  if (m_fpc in CurrentSettings.modeswitches) and
                     (TEnumDef(def).has_jumps) then
                   Message(type_e_array_index_enums_with_assign_not_possible);
                  indexdef:=def;
                end;
              orddef :
                begin
                  if TOrdDef(def).ordtype in [uchar,
                    u8bit,
                    s8bit,s16bit,
{$if defined(cpu32bitaddr) or defined(cpu64bitaddr)}
                    u16bit,s32bit,
{$endif defined(cpu32bitaddr) or defined(cpu64bitaddr)}
{$ifdef cpu64bitaddr}
                    u32bit,s64bit,
{$endif cpu64bitaddr}
                    pasbool1,pasbool8,pasbool16,pasbool32,pasbool64,
                    bool8bit,bool16bit,bool32bit,bool64bit,
                    uwidechar] then
                    begin
                       lowval:=TOrdDef(def).low;
                       highval:=TOrdDef(def).high;
                       indexdef:=def;
                    end
                  else
                    Message1(parser_e_type_cant_be_used_in_array_index,def.typename);
                end;
              { generic parameter? }
              undefineddef:
                begin
                  lowval:=0;
                  highval:=1;
                  indexdef:=def;
                  isgeneric:=true;
                end;
              else
                Message(sym_e_error_in_type_def);
            end;
          end;

        var
          old_current_genericdef,
          old_current_specializedef: TStoredDef;
          first,
          old_parse_generic: boolean;
        begin
           old_current_genericdef:=CurrentGenericDef;
           old_current_specializedef:=CurrentSpecializeDef;
           old_parse_generic:=parse_generic;

           CurrentGenericDef:=nil;
           CurrentSpecializeDef:=nil;
           first:=true;
           arrdef:=carraydef.create(0,0,s32inttype);
           consume(_ARRAY);

           { usage of specialized type inside its generic template }
           if assigned(genericdef) then
             CurrentSpecializeDef:=arrdef
           { reject declaration of generic class inside generic class }
           else if assigned(genericlist) then
             CurrentGenericDef:=arrdef;
           symtablestack.push(arrdef.symtable);
           insert_generic_parameter_types(arrdef,genericdef,genericlist,false);
           { there are two possibilities for the following to be true:
             * the array declaration itself is generic
             * the array is declared inside a generic
             in both cases we need "parse_generic" and "current_genericdef"
             so that e.g. specializations of another generic inside the
             current generic can be used (either inline ones or "type" ones) }
           if old_parse_generic then
             include(arrdef.defoptions,df_generic);
           parse_generic:=(df_generic in arrdef.defoptions);
           if parse_generic and not assigned(CurrentGenericDef) then
             CurrentGenericDef:=old_current_genericdef;

           { open array? }
           if try_to_consume(_LECKKLAMMER) then
             begin
                { defaults }
                indexdef:=generrordef;
                isgeneric:=false;
                { use defaults which don't overflow the compiler }
                lowval:=0;
                highval:=0;
                repeat
                  { read the expression and check it, check apart if the
                    declaration is an enum declaration because that needs to
                    be parsed by readtype (PFV) }
                  if CurrentScanner.token=_LKLAMMER then
                   begin
                     read_anon_type(hdef,true,nil);
                     setdefdecl(hdef);
                   end
                  else
                   begin
                     pt:=expr(true);
                     isgeneric:=false;
                     if pt.nodetype=typen then
                       setdefdecl(pt.resultdef)
                     else
                       begin
                         if pt.nodetype=rangen then
                           begin
                             if nf_generic_para in pt.flags then
                               isgeneric:=true;
                             { pure ordconstn expressions can be checked for
                               generics as well, but don't give an error in case
                               of parsing a generic if that isn't yet the case }
                             if (trangenode(pt).left.nodetype=ordconstn) and
                                (trangenode(pt).right.nodetype=ordconstn) then
                               begin
                                 { make both the same type or give an error. This is not
                                   done when both are integer values, because typecasting
                                   between -3200..3200 will result in a signed-unsigned
                                   conflict and give a range check error (PFV) }
                                 if not(is_integer(trangenode(pt).left.resultdef) and is_integer(trangenode(pt).left.resultdef)) then
                                   inserttypeconv(trangenode(pt).left,trangenode(pt).right.resultdef);
                                 lowval:=tordconstnode(trangenode(pt).left).value;
                                 highval:=tordconstnode(trangenode(pt).right).value;
                                 if highval<lowval then
                                  begin
                                    { ignore error if node is generic param }
                                    if not (nf_generic_para in pt.flags) then
                                      Message(parser_e_array_lower_less_than_upper_bound);
                                    highval:=lowval;
                                  end
                                 else if (lowval<int64(low(asizeint))) or
                                         (highval>high(asizeint)) then
                                   begin
                                     Message(parser_e_array_range_out_of_bounds);
                                     lowval :=0;
                                     highval:=0;
                                   end;
                                 if is_integer(trangenode(pt).left.resultdef) then
                                   range_to_type(lowval,highval,indexdef)
                                 else
                                   indexdef:=trangenode(pt).left.resultdef;
                               end
                             else
                               if not parse_generic then
                                 Message(type_e_cant_eval_constant_expr)
                               else
                                 { we need a valid range for debug information }
                                 range_to_type(lowval,highval,indexdef);
                           end
                         else
                           Message(sym_e_error_in_type_def)
                       end;
                     pt.free;
                     pt := nil;
                   end;

                  { if we are not at the first dimension, add the new array
                    as element of the existing array, otherwise modify the existing array }
                  if not(first) then
                    begin
                      arrdef.elementdef:=carraydef.create(lowval.svalue,highval.svalue,indexdef);
                      { push new symtable }
                      symtablestack.pop(arrdef.symtable);
                      arrdef:=TArrayDef(arrdef.elementdef);
                      symtablestack.push(arrdef.symtable);
                      { correctly update the generic information of the new array def }
                      insert_generic_parameter_types(arrdef,genericdef,genericlist,false);
                      if old_parse_generic then
                        include(arrdef.defoptions,df_generic);
                    end
                  else
                    begin
                      arrdef.lowrange:=lowval.svalue;
                      arrdef.highrange:=highval.svalue;
                      arrdef.rangedef:=indexdef;
                      def:=arrdef;
                      first:=false;
                    end;
                  if is_packed then
                    include(arrdef.arrayoptions,ado_IsBitPacked);
                  if isgeneric then
                    include(arrdef.arrayoptions,ado_IsGeneric);

                  if CurrentScanner.token=_COMMA then
                    consume(_COMMA)
                  else
                    break;
                until false;
                consume(_RECKKLAMMER);
             end
           else
             begin
                if is_packed then
                  Message(parser_e_packed_dynamic_open_array);
                arrdef.lowrange:=0;
                arrdef.highrange:=-1;
                arrdef.rangedef:=sizesinttype;
                include(arrdef.arrayoptions,ado_IsDynamicArray);
                def:=arrdef;
             end;
           consume(_OF);
           read_anon_type(tt2,true,nil);
           { set element type of the last array definition }
           if assigned(arrdef) then
             begin
               symtablestack.pop(arrdef.symtable);
               arrdef.elementdef:=tt2;
               if is_packed and
                  is_managed_type(tt2) then
                 Message(type_e_no_packed_inittable);
             end;
           { restore old state }
           parse_generic:=old_parse_generic;
           CurrentGenericDef:=old_current_genericdef;
           CurrentSpecializeDef:=old_current_specializedef;
        end;


        function procvar_dec(genericdef:TStoredDef;genericlist:tfphashobjectlist;sym:TSym;doregister:boolean):TDef;
          var
            is_func:boolean;
            pd:TProcVarDef;
            old_current_genericdef,
            old_current_specializedef: TStoredDef;
            old_parse_generic: boolean;
            olddef : TDef;
          begin
            old_current_genericdef:=CurrentGenericDef;
            old_current_specializedef:=CurrentSpecializeDef;
            old_parse_generic:=parse_generic;

            CurrentGenericDef:=nil;
            CurrentSpecializeDef:=nil;
            olddef:=nil;

            is_func:=(CurrentScanner.token=_FUNCTION);
            if CurrentScanner.token in [_FUNCTION,_PROCEDURE] then
              consume(CurrentScanner.token)
            else
              consume(_FUNCTION);
            pd:=cprocvardef.create(normal_function_level,doregister);

            if assigned(sym) then
              begin
                pd.typesym:=sym;
                olddef:=TTypeSym(sym).typedef;
                TTypeSym(sym).typedef:=pd;
              end;

            { usage of specialized type inside its generic template }
            if assigned(genericdef) then
              CurrentSpecializeDef:=pd
            { reject declaration of generic class inside generic class }
            else if assigned(genericlist) then
              CurrentGenericDef:=pd;
            symtablestack.push(pd.parast);
            insert_generic_parameter_types(pd,genericdef,genericlist,false);
            { there are two possibilities for the following to be true:
              * the procvar declaration itself is generic
              * the procvar is declared inside a generic
              in both cases we need "parse_generic" and "current_genericdef"
              so that e.g. specializations of another generic inside the
              current generic can be used (either inline ones or "type" ones) }
            if old_parse_generic then
              include(pd.defoptions,df_generic);
            parse_generic:=(df_generic in pd.defoptions);
            if parse_generic and not assigned(CurrentGenericDef) then
              CurrentGenericDef:=old_current_genericdef;

            if CurrentScanner.token=_LKLAMMER then
              parse_parameter_dec(pd);
            if is_func then
              begin
                consume(_COLON);
                pd.proctypeoption:=potype_function;
                pd.returndef:=result_type([stoAllowSpecialization]);
              end
            else
              pd.proctypeoption:=potype_procedure;
            if try_to_consume(_OF) then
              begin
                consume(_OBJECT);
                include(pd.procoptions,po_methodpointer);
              end
            else if (m_nested_procvars in CurrentSettings.modeswitches) and
                    try_to_consume(_IS) then
              begin
                consume(_NESTED);
                pd.parast.symtablelevel:=normal_function_level+1;
                pd.check_mark_as_nested;
              end;
            symtablestack.pop(pd.parast);
            { possible proc directives }
            if parseprocvardir then
              begin
                if check_proc_directive(true) then
                  parse_proctype_directives(pd);
                { Add implicit hidden parameters and function result }
                handle_calling_convention(pd,hcc_default_actions_intf);
              end;
            { restore old state }
            parse_generic:=old_parse_generic;
            CurrentGenericDef:=old_current_genericdef;
            CurrentSpecializeDef:=old_current_specializedef;

            if assigned(sym) then
              begin
                pd.typesym:=nil;
                TTypeSym(sym).typedef:=olddef;
              end;

            result:=pd;
          end;

      var
        p  : TNode;
        hdef : TDef;
        enumdupmsg, first, is_specialize : boolean;
        oldlocalswitches : TLocalSwitches;
        bitpacking: boolean;
        stitem: PSymTableStackItem;
        sym: TSym;
        st: TSymTable;
      begin
         def:=nil;
         v:=0;
         l:=0;
         if assigned(newsym) then
           name:=newsym.RealName
         else
           name:='';
         { type a = type ..,; syntax is allowed only with type syms and apparently helpers, see below }
         if hadtypetoken and
             (
               (CurrentScanner.token<>_ID) or
               (
                 (m_function_references in CurrentSettings.modeswitches) and
                 (CurrentScanner.idtoken=_REFERENCE)
               )
             ) and
             (CurrentScanner.token<>_STRING) and (CurrentScanner.token<>_FILE) then
           consume(_ID);
         case CurrentScanner.token of
            _STRING,_FILE:
              begin
                if hadtypetoken then
                  single_type(def,[])
                else
                  single_type(def,[stoAllowTypeDef]);
              end;
           _LKLAMMER:
              begin
                consume(_LKLAMMER);
                first:=true;
                { allow negativ value_str }
                l:=int64(-1);
                enumdupmsg:=false;
                { check that we are not adding an enum from specialization
                  we can't just use current_specializedef because of inner types
                  like specialize array of record }
                is_specialize:=false;
                stitem:=symtablestack.stack;
                while assigned(stitem) do
                  begin
                    { check records, classes and arrays because they can be specialized }
                    if stitem^.symtable.symtabletype in [recordsymtable,ObjectSymtable,arraysymtable] then
                      begin
                        is_specialize:=is_specialize or (df_specialization in TStoredDef(stitem^.symtable.defowner).defoptions);
                        stitem:=stitem^.next;
                      end
                    else
                      break;
                  end;
                if not is_specialize then
                  aktenumdef:=cenumdef.create
                else
                  aktenumdef:=nil;
                repeat
                  { if it is a specialization then search the first enum member
                    and get the member owner instead of just created enumdef }
                  if not assigned(aktenumdef) then
                    begin
                      if not searchsym(CurrentScanner.pattern,sym,st) then
                        internalerror(202504121)
                      else if sym.typ=enumsym then
                        aktenumdef:=TEnumSym(sym).definition
                      else
                        internalerror(201101021);
                    end;
                  s:=CurrentScanner.orgpattern;
                  defpos:=CurrentTokenPos;
                  consume(_ID);
                  { allow assigning specific numbers }
                  if
                      { in fpc mode also allow := to be compatible
                        with previous 1.0.x versions }
                      ((m_fpc in CurrentSettings.modeswitches) and
                       try_to_consume(_ASSIGNMENT)) or
                      try_to_consume(_EQ) then
                    begin
                       oldlocalswitches:=CurrentSettings.localswitches;
                       include(CurrentSettings.localswitches,cs_allow_enum_calc);
                       p:=comp_expr([ef_accept_equal]);
                       CurrentSettings.localswitches:=oldlocalswitches;
                       if (p.nodetype=ordconstn) then
                        begin
                          { we expect an integer or an enum of the
                            same type }
                          if is_integer(p.resultdef) or
                             is_char(p.resultdef) or
                             equal_defs(p.resultdef,aktenumdef) then
                           v:=tordconstnode(p).value
                          else
                           IncompatibleTypes(p.resultdef,s32inttype);
                        end
                       else
                        Message(parser_e_illegal_expression);
                       p.free;
                       p := nil;
                       { please leave that a note, allows type save }
                       { declarations in the win32 units ! }
                       if (not first) and (v<=l) and (not enumdupmsg) then
                        begin
                          Message(parser_n_duplicate_enum);
                          enumdupmsg:=true;
                        end;
                       l:=v;
                    end
                  else
                    inc(l.svalue);
                  first:=false;
                  { don't generate enum members if this is a specialization because aktenumdef is copied from the generic type }
                  if not is_specialize then
                    begin
                      storepos:=CurrentTokenPos;
                      CurrentTokenPos:=defpos;
                      if (l.svalue<low(longint)) or (l.svalue>high(longint)) then
                        if m_delphi in CurrentSettings.modeswitches then
                          Message(parser_w_enumeration_out_of_range)
                        else
                          Message(parser_e_enumeration_out_of_range);
                      TEnumSymTable(aktenumdef.symtable).insertsym(cenumsym.create(s,aktenumdef,longint(l.svalue)));
                      if not (cs_scopedenums in CurrentSettings.localswitches) or
                          { also provide the global symbol for anonymous enums }
                          not assigned(newsym) then
                        TStoredSymTable(aktenumdef.owner).insertsym(cenumsym.create(s,aktenumdef,longint(l.svalue)));
                      CurrentTokenPos:=storepos;
                    end;
                until not try_to_consume(_COMMA);
                def:=aktenumdef;
                consume(_RKLAMMER);
              end;
            _ARRAY:
              array_dec(false,genericdef,genericlist);
            _SET:
              set_dec;
            _CARET:
              pointer_dec;
            _RECORD:
              begin
                consume(CurrentScanner.token);
                if (CurrentScanner.idtoken=_HELPER) and (m_advanced_records in CurrentSettings.modeswitches) then
                  begin
                    consume(_HELPER);
                    def:=object_dec(odt_helper,name,newsym,genericdef,genericlist,nil,ht_record);
                  end
                else
                  def:=record_dec(name,newsym,genericdef,genericlist);
              end;
            _PACKED,
            _BITPACKED:
              begin
                bitpacking :=
                  (cs_bitpacking in CurrentSettings.localswitches) or
                  (CurrentScanner.token = _BITPACKED);
                consume(CurrentScanner.token);
                if CurrentScanner.token=_ARRAY then
                  array_dec(bitpacking,genericdef,genericlist)
                else if CurrentScanner.token=_SET then
                  set_dec
                else if CurrentScanner.token=_FILE then
                  single_type(def,[stoAllowTypeDef])
                else
                  begin
                    oldpackrecords:=CurrentSettings.packrecords;
                    if (not bitpacking) or
                       (CurrentScanner.token in [_CLASS,_OBJECT]) then
                      CurrentSettings.packrecords:=1
                    else
                      CurrentSettings.packrecords:=bit_alignment;
                    case CurrentScanner.token of
                      _CLASS :
                        begin
                          consume(_CLASS);
                          def:=object_dec(odt_class,name,newsym,genericdef,genericlist,nil,ht_none);
                        end;
                      _OBJECT :
                        begin
                          consume(_OBJECT);
                          def:=object_dec(odt_object,name,newsym,genericdef,genericlist,nil,ht_none);
                        end;
                      else begin
                        consume(_RECORD);
                        def:=record_dec(name,newsym,genericdef,genericlist);
                      end;
                    end;
                    CurrentSettings.packrecords:=oldpackrecords;
                  end;
              end;
            _DISPINTERFACE :
              begin
                { need extra check here since interface is a keyword
                  in all pascal modes }
                if not(m_class in CurrentSettings.modeswitches) then
                  Message(parser_f_need_objfpc_or_delphi_mode);
                consume(CurrentScanner.token);
                def:=object_dec(odt_dispinterface,name,newsym,genericdef,genericlist,nil,ht_none);
              end;
            _CLASS :
              begin
                consume(CurrentScanner.token);
                { Delphi only allows class of in type blocks }
                if (CurrentScanner.token=_OF) and
                   (
                    not(m_delphi in CurrentSettings.modeswitches) or
                    (block_type=bt_type)
                   ) then
                  begin
                    consume(_OF);
                    single_type(hdef,SingleTypeOptionsInTypeBlock[block_type=bt_type]);
                    if is_class(hdef) or
                       is_objcclass(hdef) or
                       is_javaclass(hdef) then
                      def:=cclassrefdef.create(hdef)
                    else
                      if hdef.typ=forwarddef then
                        begin
                          def:=cclassrefdef.create(hdef);
                          CurrentModule.checkforwarddefs.add(def);
                        end
                    else
                      Message1(type_e_class_or_objcclass_type_expected,hdef.typename);
                  end
                else
                if (CurrentScanner.idtoken=_HELPER) then
                  begin
                    consume(_HELPER);
                    def:=object_dec(odt_helper,name,newsym,genericdef,genericlist,nil,ht_class);
                  end
                else
                  def:=object_dec(default_class_type,name,newsym,genericdef,genericlist,nil,ht_none);
              end;
            _CPPCLASS :
              begin
                consume(CurrentScanner.token);
                def:=object_dec(odt_cppclass,name,newsym,genericdef,genericlist,nil,ht_none);
              end;
            _OBJCCLASS :
              begin
                if not(m_objectivec1 in CurrentSettings.modeswitches) then
                  Message(parser_f_need_objc);

                consume(CurrentScanner.token);
                def:=object_dec(odt_objcclass,name,newsym,genericdef,genericlist,nil,ht_none);
              end;
            _INTERFACE :
              begin
                { need extra check here since interface is a keyword
                  in all pascal modes }
                if not(m_class in CurrentSettings.modeswitches) then
                  Message(parser_f_need_objfpc_or_delphi_mode);
                consume(CurrentScanner.token);
                case CurrentSettings.interfacetype of
                  it_interfacecom:
                    def:=object_dec(odt_interfacecom,name,newsym,genericdef,genericlist,nil,ht_none);
                  it_interfacecorba:
                    def:=object_dec(odt_interfacecorba,name,newsym,genericdef,genericlist,nil,ht_none);
                  it_interfacejava:
                    def:=object_dec(odt_interfacejava,name,newsym,genericdef,genericlist,nil,ht_none);
                end;
              end;
            _OBJCPROTOCOL :
               begin
                if not(m_objectivec1 in CurrentSettings.modeswitches) then
                  Message(parser_f_need_objc);

                consume(CurrentScanner.token);
                def:=object_dec(odt_objcprotocol,name,newsym,genericdef,genericlist,nil,ht_none);
               end;
            _OBJCCATEGORY :
               begin
                if not(m_objectivec1 in CurrentSettings.modeswitches) then
                  Message(parser_f_need_objc);

                consume(CurrentScanner.token);
                def:=object_dec(odt_objccategory,name,newsym,genericdef,genericlist,nil,ht_none);
               end;
            _OBJECT :
              begin
                consume(CurrentScanner.token);
                def:=object_dec(odt_object,name,newsym,genericdef,genericlist,nil,ht_none);
              end;
            _PROCEDURE,
            _FUNCTION:
              begin
                def:=procvar_dec(genericdef,genericlist,nil,true);
              end;
            _ID:
              begin
                case CurrentScanner.idtoken of
                  _HELPER:
                    begin
                      if hadtypetoken and
                         (m_type_helpers in CurrentSettings.modeswitches) then
                        begin
                          { reset hadtypetoken, so that calling code knows that it should not be handled
                            as a "unique" type }
                          hadtypetoken:=false;
                          consume(_HELPER);
                          def:=object_dec(odt_helper,name,newsym,genericdef,genericlist,nil,ht_type);
                        end
                      else
                        expr_type
                    end;
                  _REFERENCE:
                    begin
                      if CurrentSettings.modeswitches*[m_blocks,m_function_references]<>[] then
                        begin
                          consume(_REFERENCE);
                          consume(_TO);
                          { don't register the def as a non-cblock function
                            reference will be converted to an interface }
                          def:=procvar_dec(genericdef,genericlist,newsym,false);
                          { could be errordef in case of a syntax error }
                          if assigned(def) and
                             (def.typ=procvardef) then
                            begin
                              include(TProcVarDef(def).procoptions,po_is_function_ref);
                            end;
                        end
                      else
                        expr_type;
                    end;
                  else
                    expr_type;
                end;
              end
            else
              if (CurrentScanner.token=_KLAMMERAFFE) and (([m_iso,m_extpas]*CurrentSettings.modeswitches)<>[]) then
                begin
                  consume(_KLAMMERAFFE);
                  single_type(tt2,SingleTypeOptionsInTypeBlock[block_type=bt_type]);
                  def:=cpointerdef.create(tt2);
                  if tt2.typ=forwarddef then
                    CurrentModule.checkforwarddefs.add(def);
                end
              else
                expr_type;
         end;

         if def=nil then
          def:=generrordef;
      end;


    procedure read_anon_type(var def : TDef;parseprocvardir:boolean;genericdef:TStoredDef);
      var
        hadtypetoken : boolean;
      begin
        hadtypetoken:=false;
        read_named_type(def,nil,genericdef,nil,parseprocvardir,hadtypetoken);
      end;




end.
