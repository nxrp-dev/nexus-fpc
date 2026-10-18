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
       GlobType,CClasses,
       symtype,symdef,SymBase;

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
    procedure read_named_type(var def:TDef;const newsym:TSym;GenericDef:TStoredDef;genericlist:TFPHashObjectList;parseprocvardir:boolean;var hadtypetoken:boolean);

    { reads any type declaration }
    procedure read_anon_type(var def : TDef;parseprocvardir:boolean;GenericDef:TStoredDef);

    { parse nested type declaration of the def (typedef) }
    procedure parse_nested_types(var def: TDef; isforwarddef,allowspecialization: boolean; currentstructstack: TFPObjectList);


    { parse hint directives (platform, deprecated, ...) for a procdef }
    procedure maybe_parse_hint_directives(pd:TProcDef);

implementation

    uses
       { common }
       CUtils,
       { global }
       Globals,tokens,Verbose,ConstExp,
       Systems,
       { symtable }
       symconst,SymSym,SymTable,symcreat,
       defutil,defcmp,
       { modules }
       FModule,
       { pass 1 }
       node,
       nset,ncnv,ncon,nld,
       { parser }
       Scanner,
       pbase,pexpr,pdecsub,pdecvar,pdecobj,pdecl,pgenutil,pparautl,procdefutil
       ;


    procedure maybe_parse_hint_directives(pd:TProcDef);
      var
        dummysymoptions : TSymOptions;
        DeprecatedMsg : PShortString;
      begin
        if Assigned(pd) then
          begin
            dummysymoptions:=pd.SymOptions;
            DeprecatedMsg:=pd.DeprecatedMsg;
          end
        else
          begin
            dummysymoptions:=[];
            DeprecatedMsg:=nil;
          end;
        while try_consume_hintdirective(dummysymoptions,DeprecatedMsg) do
          consume(_SEMICOLON);
        if Assigned(pd) then
          begin
            pd.SymOptions:=pd.SymOptions+dummysymoptions;
            if sp_has_deprecated_msg in dummysymoptions then
              pd.DeprecatedMsg:=DeprecatedMsg;
          end
        else
          StringDispose(DeprecatedMsg);
      end;


    procedure resolve_forward_types;
      var
        i: LongInt;
        tmp,
        hpd,
        def : TDef;
        srsym  : TSym;
        srsymtable : TSymTable;
        hs : string;
        fileinfo : TFilePosInfo;
      begin
        for i:=0 to CurrentModule.CheckForwardDefs.Count-1 do
          begin
            def:=TDef(CurrentModule.CheckForwardDefs[i]);
            case def.typ of
              pointerdef,
              classrefdef :
                begin
                  { classrefdef inherits from pointerdef }
                  hpd:=TAbstractPointerDef(def).PointedDef;
                  { still a forward def ? }
                  if hpd.typ=ForwardDef then
                   begin
                     { try to resolve the forward }
                     if not Assigned(TForwardDef(hpd).ToSymName) then
                       InternalError(200211201);
                     hs:=TForwardDef(hpd).ToSymName^;
                     SearchSym(upper(hs),srsym,srsymtable);
                     { we don't need the forwarddef anymore, dispose it }
                     hpd.free;
                     hpd := nil;
                     TAbstractPointerDef(def).PointedDef:=nil; { if error occurs }
                     { was a type sym found ? }
                     if Assigned(srsym) and
                        (srsym.typ=TypeSym) then
                      begin
                        if (sp_generic_dummy in srsym.SymOptions) and
                            not (TTypeSym(srsym).TypeDef.typ=undefineddef) and
                            Assigned(def.owner.DefOwner) then
                          begin
                            { is the forward def part of a specialization? }
                            tmp:=TDef(def.owner.DefOwner);
                            while not TStoredDef(tmp).Is_Specialization and Assigned(tmp.owner.DefOwner) do
                              tmp:=TDef(tmp.owner.DefOwner);
                            { if the genericdef of the specialization is the same as the
                              def the dummy points to, then update the found symbol }
                            if TStoredDef(tmp).Is_Specialization and
                                (TStoredDef(tmp).GenericDef=TTypeSym(srsym).TypeDef) then
                              srsym:=TStoredDef(tmp).TypeSym;
                          end;
                        TAbstractPointerDef(def).PointedDef:=TTypeSym(srsym).TypeDef;
                        { correctly set the generic/specialization flags and the genericdef }
                        if df_generic in TStoredDef(TAbstractPointerDef(def).PointedDef).DefOptions then
                          include(TStoredDef(def).DefOptions,df_generic);
                        if df_specialization in TStoredDef(TAbstractPointerDef(def).PointedDef).DefOptions then
                          begin
                            include(TStoredDef(def).DefOptions,df_specialization);
                            case def.typ of
                              pointerdef:
                                TStoredDef(def).GenericDef:=CPointerDef.getreusable(TStoredDef(TAbstractPointerDef(def).PointedDef).GenericDef);
                              classrefdef:
                                TStoredDef(def).GenericDef:=CClassRefDef.Create(TStoredDef(TAbstractPointerDef(def).PointedDef).GenericDef);
                              else
                                InternalError(2016120901);
                            end;
                          end;
                        { avoid wrong unused warnings web bug 801 PM }
                        inc(TTypeSym(srsym).refs);
                        { we need a class type for classrefdef }
                        if (def.typ=classrefdef) and
                           not(Is_Class(TTypeSym(srsym).TypeDef)) and
                           not(Is_ObjCClass(TTypeSym(srsym).TypeDef)) then
                          MessagePos1(def.TypeSym.fileinfo,type_e_class_type_expected,TTypeSym(srsym).TypeDef.TypeName);
                        { this could also be a generic dummy that was not
                          overridden with a specific type }
                        if (sp_generic_dummy in srsym.SymOptions) and
                            (
                              (TTypeSym(srsym).TypeDef.typ=undefineddef) or
                              (
                                { or an unspecialized generic symbol, which is
                                  the case for generics defined in non-Delphi
                                  modes }
                                TStoredDef(TTypeSym(srsym).TypeDef).Is_Generic and
                                not Defs_Belong_To_Same_Generic(def,TTypeSym(srsym).TypeDef)
                              )
                            ) then
                          begin
                            if Assigned(def.TypeSym) then
                              fileinfo:=def.TypeSym.fileinfo
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
                        TAbstractPointerDef(def).PointedDef:=GenErrorDef;
                      end;
                   end;
                end;
              objectdef :
                begin
                  { give an error as the implementation may follow in an
                    other type block which is allowed by FPC modes }
                  if not(m_fpc in CurrentSettings.ModeSwitches) and
                     (oo_is_forward in TObjectDef(def).ObjectOptions) then
                    MessagePos1(def.TypeSym.fileinfo,type_e_type_is_not_completly_defined,def.TypeName);
                  { generate specializations for generic forwarddefs }
                  if not (oo_is_forward in TObjectDef(def).ObjectOptions) and
                      TStoredDef(def).Is_Generic then
                    generate_specializations_for_forwarddef(def);
                 end;
              else
                InternalError(200811071);
            end;
          end;
        CurrentModule.CheckForwardDefs.clear;
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
    procedure parse_nested_types(var def: TDef; isforwarddef,allowspecialization: boolean; currentstructstack: TFPObjectList);
      var
        t2: TDef;
        structstackindex: LongInt;
        srsym: TSym;
        srsymtable: TSymTable;
        OldSymTableStack: TSymTableStack;
        isspecialize,
        isunitspecific : boolean;
      begin
        if Assigned(currentstructstack) then
          structstackindex:=currentstructstack.count-1
        else
          structstackindex:=-1;
        { handle types inside classes, e.g. TNode.TLongint }
        while (CurrentScanner.token=_POINT) do
          begin
             if Is_Class_Or_Object(def) or Is_Record(def) then
               begin
                 if (def.typ=objectdef) then
                   def:=Find_Real_Class_Definition(TObjectDef(def),false);
                 consume(_POINT);
                 if (structstackindex>=0) and
                    (TAbstractRecordDef(currentstructstack[structstackindex]).ObjName^=CurrentScanner.pattern) then
                   begin
                     def:=TDef(currentstructstack[structstackindex]);
                     dec(structstackindex);
                     consume(_ID);
                   end
                 else
                   begin
                     structstackindex:=-1;
                     OldSymTableStack:=SymTableStack;
                     SymTableStack:=TSymTableStack.Create;
                     SymTableStack.push(TAbstractRecordDef(def).SymTable);
                     t2:=GenErrorDef;
                     id_type(t2,isforwarddef,false,false,false,srsym,srsymtable,isspecialize,isunitspecific);
                     SymTableStack.pop(TAbstractRecordDef(def).SymTable);
                     SymTableStack.free;
                     SymTableStack:=OldSymTableStack;
                     if isspecialize or
                         (
                           (m_delphi in CurrentSettings.ModeSwitches) and
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


    function try_parse_structdef_nested_type(out def: TDef; BaseDef: TAbstractRecordDef; isfowarddef: boolean): boolean;
      var
        structdef : TDef;
        structdefstack : TFPObjectList;
      begin
         def:=nil;
         { use of current parsed object:
           classes, objects, records can be used also in themself }
         structdef:=BaseDef;
         structdefstack:=nil;
         while Assigned(structdef) and (structdef.typ in [objectdef,recorddef]) do
           begin
             if (TAbstractRecordDef(structdef).ObjName^=CurrentScanner.pattern) then
               begin
                 consume(_ID);
                 def:=structdef;
                 { we found the top-most match, now check how far down we can
                   follow }
                 structdefstack:=TFPObjectList.Create(false);
                 structdef:=BaseDef;
                 while (structdef<>def) do
                   begin
                     structdefstack.add(structdef);
                     structdef:=TAbstractRecordDef(structdef.owner.DefOwner);
                   end;
                 parse_nested_types(def,isfowarddef,true,structdefstack);
                 structdefstack.free;
                 structdefstack := nil;
                 result:=true;
                 exit;
               end;
             structdef:=TDef(TAbstractRecordDef(structdef).owner.DefOwner);
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
        t : TToken;
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
         if not allowunitsym and not (m_delphi in CurrentSettings.ModeSwitches) and (CurrentScanner.idtoken=_SPECIALIZE) then
           begin
             consume(_ID);
             is_specialize:=true;
             s:=CurrentScanner.pattern;
             sorg:=CurrentScanner.orgpattern;
             pos:=CurrentTokenPos;
           end;
         { Use the special searchsym_type that search only types }
         if not SearchSym_Type(s,srsym,srsymtable) then
           { for a good error message we need to know whether the symbol really did not exist or
             whether we found a non-type one }
           not_a_type:=SearchSym(s,srsym,srsymtable)
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
         if Assigned(srsym) and
            (srsym.typ=TypeSym) and
            ((TTypeSym(srsym).TypeDef.typ=errordef) or
            (not allowgenericsyms and
            (TTypeSym(srsym).TypeDef.typ=undefineddef) and
            not (sp_generic_para in srsym.SymOptions) and
            not (sp_explicitrename in srsym.SymOptions) and
            not Assigned(srsym.owner.DefOwner) and
            { use df_generic instead of is_generic to allow aliases in nested types as well }
            not (df_generic in TStoredDef(srsym.owner.DefOwner).DefOptions))) then
          begin
            Message1(type_e_type_is_not_completly_defined,TTypeSym(srsym).realname);
            def:=GenErrorDef;
            exit;
          end;
         { are we parsing a possible forward def ? }
         if isforwarddef and
            not(is_unit_specific) then
           begin
             def:=CForwardDef.Create(sorg,pos);
             exit;
           end;
         { unknown sym ? }
         if not Assigned(srsym) and not not_a_type then
          begin
            Message1(sym_e_id_not_found,sorg);
            def:=GenErrorDef;
            exit;
          end;
         { type sym ? }
         if not_a_type or (srsym.typ<>TypeSym) then
          begin
            Message(type_e_type_id_expected);
            def:=GenErrorDef;
            exit;
          end;
         { Give an error when referring to an errordef }
         if (TTypeSym(srsym).TypeDef.typ=errordef) then
          begin
            Message(sym_e_error_in_type_def);
            def:=GenErrorDef;
            exit;
          end;
         { In non-Delphi modes the class/record name of a generic might be used
           in the declaration of sub types without type parameters; in that case
           we need to check by name as the link from the dummy symbol to the
           current type is not yet established }
         if (sp_generic_dummy in srsym.SymOptions) and
             Assigned(CurrentStructDef) and
             (df_generic in CurrentStructDef.DefOptions) and
             (TTypeSym(srsym).TypeDef.typ=undefineddef) and
             not (m_delphi in CurrentSettings.ModeSwitches) then
           begin
             def:=Get_Generic_In_Hierarchy_By_Name(srsym,CurrentStructDef);
             if Assigned(def) then
               exit;
           end;
        def:=TTypeSym(srsym).TypeDef;
      end;


    procedure single_type(out def:TDef;options:TSingleTypeOptions);

       function handle_dummysym(sym:TSym):TDef;
         begin
           sym:=resolve_generic_dummysym(sym.name);
           if Assigned(sym) and
               not (sp_generic_dummy in sym.SymOptions) and
               (sym.typ=TypeSym) then
             result:=TTypeSym(sym).TypeDef
           else
             begin
               Message(parser_e_no_generics_as_types);
               result:=GenErrorDef;
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
         symname : TSymStr;
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
                         if Is_Managed_Type(t2) then
                           Message(parser_e_no_refcounted_typed_file);
                         def:=CFileDef.CreateTyped(t2);
                      end
                    else
                      def:=CFileType;
                 end;

               _ID:
                 begin
                   if not (m_delphi in CurrentSettings.ModeSwitches) and try_to_consume(_SPECIALIZE) then
                     begin
                       if ([stoAllowSpecialization,stoAllowTypeDef] * options = []) then
                         begin
                           Message(parser_e_no_local_para_def);

                           { try to recover }
                           while CurrentScanner.token<>_SEMICOLON do
                             consume(CurrentScanner.token);
                           def:=GenErrorDef;
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
                         InternalError(2015021301);
                       if isspecialize then
                         dospecialize:=true;
                       parse_nested_types(def,stoIsForwardDef in options,[stoAllowSpecialization,stoAllowTypeDef]*options<>[],nil);
                     end;
                 end;

               else
                 begin
                   message(type_e_type_id_expected);
                   def:=GenErrorDef;
                 end;
            end;
        until not again;
        if ([stoAllowSpecialization,stoAllowTypeDef] * options <> []) and
           (m_delphi in CurrentSettings.ModeSwitches) then
          dospecialize:=CurrentScanner.token in [_LSHARPBRACKET,_LT];
        if dospecialize and
            (def.typ=ForwardDef) then
          begin
            if not Assigned(srsym) or not (srsym.typ=TypeSym) then
              begin
                Message1(type_e_type_is_not_completly_defined,def.TypeName);
                def:=GenErrorDef;
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
            if def.typ=ForwardDef then
              def:=TTypeSym(srsym).TypeDef;
            if Assigned(srsym) then
              symname:=srsym.name
            else if Assigned(def.TypeSym) then
              begin
                symname:=def.TypeSym.name;
                srsymtable:=def.TypeSym.owner;
              end
            else if (def.typ=objectdef) then
              begin
                symname:=TObjectDef(def).ObjName^;
                if Assigned(def.owner) then
                  srsymtable:=def.owner
                else
                  srsymtable:=SymTableStack.top;
              end
            else
              symname:='';
            generate_specialization(def,isunitspecific,stoParseClassParent in options,'',symname,srsymtable);
            parse_nested_types(def,stoIsForwardDef in options,[stoAllowSpecialization,stoAllowTypeDef]*options<>[],nil);
          end
        else
          begin
            if Assigned(CurrentSpecializeDef) and (def=CurrentSpecializeDef.GenericDef) then
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
            else if Assigned(CurrentStructDef) and
                (df_specialization in CurrentStructDef.DefOptions) and
                Return_Specialization_Of_Generic(CurrentStructDef,def,t2) then
              begin
                def:=t2
              end
            else if TStoredDef(def).Is_Generic and
                not
                  (
                    parse_generic and
                    (
                      { if this is a generic parameter than it has already been checked that this is
                        a valid usage of a generic }
                      (sp_generic_para in srsym.SymOptions) or
                      (
                        (CurrentGenericDef.typ in [recorddef,objectdef]) and
                        (
                          { if both defs belong to the same generic (e.g. both are
                            subtypes) then we must allow the usage }
                          Defs_Belong_To_Same_Generic(def,CurrentGenericDef) or
                          { this is needed to correctly resolve "type Foo=SomeGeneric<T>"
                            declarations inside a generic }
                          Sym_Is_Owned_By(srsym,TAbstractRecordDef(CurrentGenericDef).SymTable)
                        )
                      )
                    )
                  )
                then
              begin
                def:=handle_dummysym(srsym);
              end
            else if (def.typ=undefineddef) and
                (sp_generic_dummy in srsym.SymOptions) then
              begin
                if parse_generic and
                    (CurrentGenericDef.typ in [recorddef,objectdef]) and
                    (Pos(upper(srsym.realname),TAbstractRecordDef(CurrentGenericDef).ObjName^)=1) then
                  begin
                    if m_delphi in CurrentSettings.ModeSwitches then
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
            else if Is_ClassHelper(def) and
                not (stoParseClassParent in options) then
              begin
                Message(parser_e_no_category_as_types);
                def:=GenErrorDef
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
          result:=(CurrentStructDef.ObjName^='') or
                  not(SymTableStack.stack^.next^.SymTable.SymTableType in [GlobalSymTable,staticsymtable,objectsymtable,recordsymtable]);
        end;

      var
        pd : TProcDef;
        oldparse_only: boolean;
        member_blocktype : TBlockType;
        hadgeneric,
        fields_allowed, is_classdef, classfields, threadvarfields: boolean;
        vdoptions: TVarDecOptions;
        rtti_attrs_def: TRTTIAttributeList;
        fldCount : Integer;
        attr_element_count : Integer;

      procedure check_unbound_attributes;
        begin
          if Assigned(rtti_attrs_def) and (rtti_attrs_def.GetAttributeCount>0) then
            Message1(parser_e_unbound_attribute,TRTTIAttribute(rtti_attrs_def.RTTIAttributes[0]).TypeSym.prettyname);
          rtti_attrs_def.free;
          rtti_attrs_def:=nil;
        end;

      begin
        { empty record declaration ? }
        if (CurrentScanner.token=_SEMICOLON) then
          Exit;

        CurrentStructDef.SymTable.CurrentVisibility:=vis_public;
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
                       CurrentStructDef.SymTable.CurrentVisibility:=vis_private;
                       include(CurrentStructDef.ObjectOptions,oo_has_private);
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
                       CurrentStructDef.SymTable.CurrentVisibility:=vis_protected;
                       include(CurrentStructDef.ObjectOptions,oo_has_protected);
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
                       CurrentStructDef.SymTable.CurrentVisibility:=vis_public;
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
                       CurrentStructDef.SymTable.CurrentVisibility:=vis_published;
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
                                  CurrentStructDef.SymTable.CurrentVisibility:=vis_strictprivate;
                                  include(CurrentStructDef.ObjectOptions,oo_has_strictprivate);
                                end;
                              _PROTECTED:
                                begin
                                  { "strict protected" is not allowed for records }
                                  Message1(parser_e_not_allowed_in_record,tokeninfo^[_STRICT].str+' '+tokeninfo^[_PROTECTED].str);
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
                                not (m_delphi in CurrentSettings.ModeSwitches) and
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
                                if not (m_delphi in CurrentSettings.ModeSwitches) then
                                  include(vdoptions,vd_check_generic);
                                if threadvarfields then
                                  include(vdoptions,vd_threadvar);
                                fldCount:=CurrentStructDef.SymTable.SymList.Count;
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
                                if Assigned(rtti_attrs_def) then
                                  begin
                                  While (attr_element_count>1) do
                                    begin
                                    TRTTIAttributeList.CopyAndBind(rtti_attrs_def,(CurrentStructDef.SymTable.SymList[fldCount] as TFieldVarSym).RTTIAttributeList);
                                    inc(fldcount);
                                    dec(attr_element_count);
                                    end;
                                  if fldCount<CurrentStructDef.SymTable.SymList.Count then
                                    TRTTIAttributeList.bind(rtti_attrs_def,(CurrentStructDef.SymTable.SymList[fldCount] as TFieldVarSym).RTTIAttributeList);
                                  end;
                              end;
                          end
                        else if member_blocktype=bt_type then
                          types_dec(true,hadgeneric, rtti_attrs_def)
                        else if member_blocktype=bt_const then
                          consts_dec(true,true,hadgeneric)
                        else
                          InternalError(201001110);
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
                if Assigned(rtti_attrs_def) then
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
                if not is_classdef and (CurrentStructDef.SymTable.CurrentVisibility <> vis_public) then
                  Message(parser_w_constructor_should_be_public);

                { only 1 class constructor is allowed }
                if is_classdef and (oo_has_class_constructor in CurrentStructDef.ObjectOptions) then
                  Message1(parser_e_only_one_class_constructor_allowed, CurrentStructDef.ObjRealName^);

                oldparse_only:=parse_only;
                parse_only:=true;
                if is_classdef then
                  pd:=class_constructor_head(CurrentStructDef)
                else
                  begin
                    pd:=constructor_head;
                    if pd.MinParaCount = 0 then
                      MessagePos(pd.ProcSym.fileinfo,parser_e_no_parameterless_constructor_in_records);
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
                if is_classdef and (oo_has_class_destructor in CurrentStructDef.ObjectOptions) then
                  Message1(parser_e_only_one_class_destructor_allowed, CurrentStructDef.ObjRealName^);

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
                if m_prefixed_attributes in CurrentSettings.ModeSwitches then
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
    function record_dec(const n:TIDString;recsym:TSym;GenericDef:TStoredDef;genericlist:TFPHashObjectList):TDef;
      var
         olddef : TDef;

      procedure set_typesym;
        begin
          if not Assigned(recsym) then
            exit;
          if TTypeSym(recsym).TypeDef=CurrentStructDef then
            exit;
          TTypeSym(recsym).TypeDef:=CurrentStructDef;
          CurrentStructDef.TypeSym:=recsym;
        end;

      procedure reset_typesym;
        begin
          if not Assigned(recsym) then
            exit;
          if TTypeSym(recsym).TypeDef<>CurrentStructDef then
            exit;
          TTypeSym(recsym).TypeDef:=olddef;
          CurrentStructDef.TypeSym:=nil;
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
         recst:=TRecordSymTable.Create(n,CurrentSettings.PackRecords,CurrentSettings.Alignment.RecordAlignMin);
         { can't use recst.realname^ instead of n, because recst.realname is
           nil in case of an empty name }
         CurrentStructDef:=CRecordDef.Create(n,recst);
         result:=CurrentStructDef;
         { insert in symtablestack }
         SymTableStack.push(recst);

         { usage of specialized type inside its generic template }
         if Assigned(GenericDef) then
           CurrentSpecializeDef:=CurrentStructDef
         { reject declaration of generic class inside generic class }
         else if Assigned(genericlist) then
           CurrentGenericDef:=CurrentStructDef;

         { nested types of specializations are specializations as well }
         if Assigned(old_current_structdef) and
             (df_specialization in old_current_structdef.DefOptions) then
           include(CurrentStructDef.DefOptions,df_specialization);
         if Assigned(old_current_structdef) and
             (df_generic in old_current_structdef.DefOptions) then
           include(CurrentStructDef.DefOptions,df_generic);

         insert_generic_parameter_types(CurrentStructDef,GenericDef,genericlist,false);
         { when we are parsing a generic already then this is a generic as
           well }
         if old_parse_generic then
           include(CurrentStructDef.DefOptions, df_generic);
         parse_generic:=(df_generic in CurrentStructDef.DefOptions);
         if parse_generic and not Assigned(CurrentGenericDef) then
           CurrentGenericDef:=CurrentStructDef;
         { in non-Delphi modes we need a strict private symbol without type
           count and type parameters in the name to simply resolving }
         maybe_insert_generic_rename_symbol(n,genericlist);
         { apply $RTTI directive to current object }
         CurrentStructDef.Apply_RTTI_Directive(CurrentModule.RTTIDirective);

         { the correct typesym<->def relationship is needed for example when
           parsing parameters that are specializations of the record, when
           using nested constants and such or when specializing the type
           itself as a pointer type }
         if Assigned(recsym) then
           olddef:=TTypeSym(recsym).TypeDef
         else
           olddef:=nil;
         set_typesym;

         if m_advanced_records in CurrentSettings.ModeSwitches then
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
                 recst.RecordAlignment:=shortint(alignment);
                 recst.ExplicitRecordAlignment:=shortint(alignment);
               end;
           end;
         { make the record size aligned (has to be done before inserting the
           parameters, because that may depend on the record's size) }
         recst.AddAlignmentPadding;

         Insert_Struct_Hidden_Paras(TRecordDef(CurrentStructDef));
         { restore symtable stack }
         SymTableStack.pop(recst);
         if TRecordDef(CurrentStructDef).Is_Packed and Is_Managed_Type(CurrentStructDef) then
           Message(type_e_no_packed_inittable);
         { restore old state }
         parse_generic:=old_parse_generic;
         CurrentStructDef:=old_current_structdef;
         CurrentGenericDef:=old_current_genericdef;
         CurrentSpecializeDef:=old_current_specializedef;
      end;


    { reads a type definition and returns a pointer to it }
    procedure read_named_type(var def:TDef;const newsym:TSym;GenericDef:TStoredDef;genericlist:TFPHashObjectList;parseprocvardir:boolean;var hadtypetoken:boolean);
      const
        SingleTypeOptionsInTypeBlock:array[Boolean] of TSingleTypeOptions = ([],[stoIsForwardDef]);
      var
        pt : TNode;
        tt2 : TDef;
        aktenumdef : TEnumDef;
        s : TIDString;
        l,v : TConstExprInt;
        oldpackrecords : LongInt;
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
           gencount : LongInt;
        begin
           old_block_type:=Block_Type;
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
               if not(Is_Integer(pt1.resultdef) and Is_Integer(pt2.resultdef)) then
                 InsertTypeConv(pt1,pt2.resultdef);
               { both must be evaluated to constants now }
               if (pt1.nodetype=ordconstn) and
                  (pt2.nodetype=ordconstn) then
                 begin
                   lv:=TOrdConstNode(pt1).Value;
                   hv:=TOrdConstNode(pt2).Value;
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
                           def:=CEnumDef.Create_Subrange(TEnumDef(pt1.resultdef),lv.svalue,hv.svalue);
                         orddef :
                           begin
                             if Is_Char(pt1.resultdef) then
                               def:=COrdDef.Create(uchar,lv,hv,true)
                             else
                               if Is_Boolean(pt1.resultdef) then
                                 def:=COrdDef.Create(pasbool1,lv,hv,true)
                               else if Is_Signed(pt1.resultdef) then
                                 def:=COrdDef.Create(Range_To_BaseType(lv,hv),lv,hv,true)
                               else
                                 def:=COrdDef.Create(Range_To_BaseType(lv,hv),lv,hv,true);
                           end;
                         else
                           InternalError(2019050527);
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
                   def:=TTypeNode(pt1).resultdef;
                   { Delphi mode specialization? }
                   if (m_delphi in CurrentSettings.ModeSwitches) then
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
                       Assigned(TTypeNode(pt1).TypeSym) and
                       (TTypeNode(pt1).TypeSym.typ=TypeSym) and
                       (sp_generic_dummy in TTypeNode(pt1).TypeSym.SymOptions) and
                       Assigned(CurrentStructDef) and
                       (
                         (
                           not (m_delphi in CurrentSettings.ModeSwitches) and
                           (TTypeSym(TTypeNode(pt1).TypeSym).TypeDef.typ=undefineddef) and
                           (df_generic in CurrentStructDef.DefOptions) and
                           (TTypeSym(TTypeNode(pt1).TypeSym).TypeDef.owner=CurrentStructDef.owner) and
                           (upper(TTypeNode(pt1).TypeSym.realname)=copy(CurrentStructDef.ObjName^,1,pos('$',CurrentStructDef.ObjName^)-1))
                         ) or (
                           { this could be a nested specialization which uses
                             the type name of a surrounding generic to
                             reference the specialization of said surrounding
                             class }
                           (df_specialization in CurrentStructDef.DefOptions) and
                           Return_Specialization_Of_Generic(CurrentStructDef,TTypeSym(TTypeNode(pt1).TypeSym).TypeDef,newdef)
                         )
                       )
                       then
                     begin
                       if Assigned(newdef) then
                         def:=newdef
                       else
                         def:=CurrentStructDef;
                       if Assigned(def) then
                         { handle nested types }
                         post_comp_expr_gendef(def)
                       else
                         def:=GenErrorDef;
                     end;
                   if dospecialize then
                     begin
                       if not Assigned(TTypeNode(pt1).TypeSym) then
                         InternalError(2025103102);
                       generate_specialization(def,false,false,name,TTypeNode(pt1).TypeSym.name,TTypeNode(pt1).TypeSym.owner);
                       { handle nested types }
                       if Assigned(def) then
                         post_comp_expr_gendef(def);
                     end
                   else
                     begin
                       if Assigned(CurrentSpecializeDef) and (def=CurrentSpecializeDef.GenericDef) then
                         begin
                           def:=CurrentSpecializeDef
                         end
                       else if (def=CurrentGenericDef) then
                         begin
                           def:=CurrentGenericDef
                         end
                       else if TStoredDef(def).Is_Generic and
                           { TODO : check once nested generics are allowed }
                           not
                             (
                               parse_generic and
                               (CurrentGenericDef.typ in [recorddef,objectdef]) and
                               (def.typ in [recorddef,objectdef]) and
                               (
                                 { if both defs belong to the same generic (e.g. both are
                                   subtypes) then we must allow the usage }
                                 Defs_Belong_To_Same_Generic(def,CurrentGenericDef) or
                                 { this is needed to correctly resolve "type Foo=SomeGeneric<T>"
                                   declarations inside a generic }
                                 (
                                   (TTypeNode(pt1).TypeSym<>nil) and
                                   Sym_Is_Owned_By(TTypeNode(pt1).TypeSym,TAbstractRecordDef(CurrentGenericDef).SymTable)
                                 )
                               )
                             )
                           then
                         begin
                           if Assigned(def.TypeSym) then
                             begin
                               if TTypeSym(def.TypeSym).TypeDef.typ<>undefineddef then
                                 { non-Delphi modes... }
                                 split_generic_name(def.TypeSym.name,genstr,gencount)
                               else
                                 genstr:=def.TypeSym.name;
                               sym:=resolve_generic_dummysym(genstr);
                             end
                           else
                             sym:=nil;
                           if Assigned(sym) and
                               not (sp_generic_dummy in sym.SymOptions) and
                               (sym.typ=TypeSym) then
                             def:=TTypeSym(sym).TypeDef
                           else
                             begin
                               Message(parser_e_no_generics_as_types);
                               def:=GenErrorDef;
                             end;
                         end
                       else if Is_ClassHelper(def) then
                         begin
                           Message(parser_e_no_category_as_types);
                           def:=GenErrorDef
                         end
                     end;
                 end
               else
                 Message(sym_e_error_in_type_def);
             end;
           pt1.free;
           pt1 := nil;
           Block_Type:=old_block_type;
        end;


      procedure set_dec;
        begin
          consume(_SET);
          consume(_OF);
          read_anon_type(tt2,true,nil);
          if Assigned(tt2) then
           begin
             case tt2.typ of
               { don't forget that min can be negativ  PM }
               enumdef :
                 if (TEnumDef(tt2).min>=0) and
                    (TEnumDef(tt2).max<=255) then
                  // !! def:=csetdef.create(tt2,tenumdef(tt2.def).min,tenumdef(tt2.def).max),true)
                  def:=CSetDef.Create(tt2,TEnumDef(tt2).min,TEnumDef(tt2).max,true)
                 else
                  Message(sym_e_ill_type_decl_set);
               orddef :
                 begin
                   if (TOrdDef(tt2).OrdType=uwidechar) then
                     begin
                     if (m_default_unicodestring in CurrentSettings.ModeSwitches) then
                       begin
                         Message(parser_w_widechar_set_reduced);
                         def:=CSetDef.Create(CAnsiCharType,TOrdDef(CAnsiCharType).low.svalue,TOrdDef(CAnsiCharType).high.svalue,true);
                       end
                     else
                       Message(sym_e_ill_type_decl_set);
                     end
                   else if (TOrdDef(tt2).OrdType<>uvoid) and
                      (TOrdDef(tt2).low>=0) then
                     // !! def:=csetdef.create(tt2,torddef(tt2.def).low,torddef(tt2.def).high),true)
                     if TOrdDef(tt2).high>int64(high(byte)) then
                       message(sym_e_ill_type_decl_set)
                     else
                       def:=CSetDef.Create(tt2,TOrdDef(tt2).low.svalue,TOrdDef(tt2).high.svalue,true)
                   else
                     Message(sym_e_ill_type_decl_set);
                 end;
               { generic parameter? }
               undefineddef:
                 { The element bounds are determined when specializing. }
                 def:=CSetDef.Create(tt2,0,255,true);
               else
                 Message(sym_e_ill_type_decl_set);
             end;
           end
          else
           def:=GenErrorDef;
        end;


      procedure pointer_dec;
        var
          sym: TSym;
        begin
          consume(_CARET);
          single_type(tt2,
              SingleTypeOptionsInTypeBlock[Block_Type=bt_type]+[stoAllowSpecialization]
            );
          { in case of e.g. var or const sections we need to especially
            check that we don't use a generic dummy symbol }
          if (Block_Type<>bt_type) and
              (tt2.typ=undefineddef) and
              Assigned(tt2.TypeSym) and
              (sp_generic_dummy in tt2.TypeSym.SymOptions) then
            begin
              sym:=resolve_generic_dummysym(tt2.TypeSym.name);
              if Assigned(sym) and
                  not (sp_generic_dummy in sym.SymOptions) and
                  (sym.typ=TypeSym) then
                tt2:=TTypeSym(sym).TypeDef
              else
                Message(parser_e_no_generics_as_types);
            end;
          { don't use cpointerdef.getreusable() here, since this is a type
            declaration (-> must create new typedef) }
          def:=CPointerDef.Create(tt2);
          if tt2.typ=ForwardDef then
            CurrentModule.CheckForwardDefs.add(def);
        end;


      procedure array_dec(Is_Packed:boolean;GenericDef:TStoredDef;genericlist:TFPHashObjectList);
        var
          isgeneric : boolean;
          lowval,
          highval   : TConstExprInt;
          IndexDef  : TDef;
          hdef      : TDef;
          arrdef    : TArrayDef;

        procedure setdefdecl(def:TDef);
          begin
            case def.typ of
              enumdef :
                begin
                  lowval:=TEnumDef(def).min;
                  highval:=TEnumDef(def).max;
                  if (m_fpc in CurrentSettings.ModeSwitches) and
                     (TEnumDef(def).HasJumps) then
                   Message(type_e_array_index_enums_with_assign_not_possible);
                  IndexDef:=def;
                end;
              orddef :
                begin
                  if TOrdDef(def).OrdType in [uchar,
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
                       IndexDef:=def;
                    end
                  else
                    Message1(parser_e_type_cant_be_used_in_array_index,def.TypeName);
                end;
              { generic parameter? }
              undefineddef:
                begin
                  lowval:=0;
                  highval:=1;
                  IndexDef:=def;
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
           arrdef:=CArrayDef.Create(0,0,S32IntType);
           consume(_ARRAY);

           { usage of specialized type inside its generic template }
           if Assigned(GenericDef) then
             CurrentSpecializeDef:=arrdef
           { reject declaration of generic class inside generic class }
           else if Assigned(genericlist) then
             CurrentGenericDef:=arrdef;
           SymTableStack.push(arrdef.SymTable);
           insert_generic_parameter_types(arrdef,GenericDef,genericlist,false);
           { there are two possibilities for the following to be true:
             * the array declaration itself is generic
             * the array is declared inside a generic
             in both cases we need "parse_generic" and "current_genericdef"
             so that e.g. specializations of another generic inside the
             current generic can be used (either inline ones or "type" ones) }
           if old_parse_generic then
             include(arrdef.DefOptions,df_generic);
           parse_generic:=(df_generic in arrdef.DefOptions);
           if parse_generic and not Assigned(CurrentGenericDef) then
             CurrentGenericDef:=old_current_genericdef;

           { open array? }
           if try_to_consume(_LECKKLAMMER) then
             begin
                { defaults }
                IndexDef:=GenErrorDef;
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
                             if (TRangeNode(pt).left.nodetype=ordconstn) and
                                (TRangeNode(pt).right.nodetype=ordconstn) then
                               begin
                                 { make both the same type or give an error. This is not
                                   done when both are integer values, because typecasting
                                   between -3200..3200 will result in a signed-unsigned
                                   conflict and give a range check error (PFV) }
                                 if not(Is_Integer(TRangeNode(pt).left.resultdef) and Is_Integer(TRangeNode(pt).left.resultdef)) then
                                   InsertTypeConv(TRangeNode(pt).left,TRangeNode(pt).right.resultdef);
                                 lowval:=TOrdConstNode(TRangeNode(pt).left).Value;
                                 highval:=TOrdConstNode(TRangeNode(pt).right).Value;
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
                                 if Is_Integer(TRangeNode(pt).left.resultdef) then
                                   Range_To_Type(lowval,highval,IndexDef)
                                 else
                                   IndexDef:=TRangeNode(pt).left.resultdef;
                               end
                             else
                               if not parse_generic then
                                 Message(type_e_cant_eval_constant_expr)
                               else
                                 { we need a valid range for debug information }
                                 Range_To_Type(lowval,highval,IndexDef);
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
                      arrdef.ElementDef:=CArrayDef.Create(lowval.svalue,highval.svalue,IndexDef);
                      { push new symtable }
                      SymTableStack.pop(arrdef.SymTable);
                      arrdef:=TArrayDef(arrdef.ElementDef);
                      SymTableStack.push(arrdef.SymTable);
                      { correctly update the generic information of the new array def }
                      insert_generic_parameter_types(arrdef,GenericDef,genericlist,false);
                      if old_parse_generic then
                        include(arrdef.DefOptions,df_generic);
                    end
                  else
                    begin
                      arrdef.LowRange:=lowval.svalue;
                      arrdef.HighRange:=highval.svalue;
                      arrdef.RangeDef:=IndexDef;
                      def:=arrdef;
                      first:=false;
                    end;
                  if Is_Packed then
                    include(arrdef.ArrayOptions,ado_IsBitPacked);
                  if isgeneric then
                    include(arrdef.ArrayOptions,ado_IsGeneric);

                  if CurrentScanner.token=_COMMA then
                    consume(_COMMA)
                  else
                    break;
                until false;
                consume(_RECKKLAMMER);
             end
           else
             begin
                if Is_Packed then
                  Message(parser_e_packed_dynamic_open_array);
                arrdef.LowRange:=0;
                arrdef.HighRange:=-1;
                arrdef.RangeDef:=SizeSIntType;
                include(arrdef.ArrayOptions,ado_IsDynamicArray);
                def:=arrdef;
             end;
           consume(_OF);
           read_anon_type(tt2,true,nil);
           { set element type of the last array definition }
           if Assigned(arrdef) then
             begin
               SymTableStack.pop(arrdef.SymTable);
               arrdef.ElementDef:=tt2;
               if Is_Packed and
                  Is_Managed_Type(tt2) then
                 Message(type_e_no_packed_inittable);
             end;
           { restore old state }
           parse_generic:=old_parse_generic;
           CurrentGenericDef:=old_current_genericdef;
           CurrentSpecializeDef:=old_current_specializedef;
        end;


        function procvar_dec(GenericDef:TStoredDef;genericlist:TFPHashObjectList;sym:TSym;doregister:boolean):TDef;
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
            pd:=CProcVarDef.Create(NormalFunctionLevel,doregister);

            if Assigned(sym) then
              begin
                pd.TypeSym:=sym;
                olddef:=TTypeSym(sym).TypeDef;
                TTypeSym(sym).TypeDef:=pd;
              end;

            { usage of specialized type inside its generic template }
            if Assigned(GenericDef) then
              CurrentSpecializeDef:=pd
            { reject declaration of generic class inside generic class }
            else if Assigned(genericlist) then
              CurrentGenericDef:=pd;
            SymTableStack.push(pd.ParaST);
            insert_generic_parameter_types(pd,GenericDef,genericlist,false);
            { there are two possibilities for the following to be true:
              * the procvar declaration itself is generic
              * the procvar is declared inside a generic
              in both cases we need "parse_generic" and "current_genericdef"
              so that e.g. specializations of another generic inside the
              current generic can be used (either inline ones or "type" ones) }
            if old_parse_generic then
              include(pd.DefOptions,df_generic);
            parse_generic:=(df_generic in pd.DefOptions);
            if parse_generic and not Assigned(CurrentGenericDef) then
              CurrentGenericDef:=old_current_genericdef;

            if CurrentScanner.token=_LKLAMMER then
              parse_parameter_dec(pd);
            if is_func then
              begin
                consume(_COLON);
                pd.ProcTypeOption:=potype_function;
                pd.ReturnDef:=result_type([stoAllowSpecialization]);
              end
            else
              pd.ProcTypeOption:=potype_procedure;
            if try_to_consume(_OF) then
              begin
                consume(_OBJECT);
                include(pd.ProcOptions,po_methodpointer);
              end
            else if (m_nested_procvars in CurrentSettings.ModeSwitches) and
                    try_to_consume(_IS) then
              begin
                consume(_NESTED);
                pd.ParaST.SymTableLevel:=NormalFunctionLevel+1;
                pd.Check_Mark_As_Nested;
              end;
            SymTableStack.pop(pd.ParaST);
            { possible proc directives }
            if parseprocvardir then
              begin
                if check_proc_directive(true) then
                  parse_proctype_directives(pd);
                { Add implicit hidden parameters and function result }
                Handle_Calling_Convention(pd,cHCCDefaultActionsIntf);
              end;
            { restore old state }
            parse_generic:=old_parse_generic;
            CurrentGenericDef:=old_current_genericdef;
            CurrentSpecializeDef:=old_current_specializedef;

            if Assigned(sym) then
              begin
                pd.TypeSym:=nil;
                TTypeSym(sym).TypeDef:=olddef;
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
         if Assigned(newsym) then
           name:=newsym.RealName
         else
           name:='';
         { type a = type ..,; syntax is allowed only with type syms and apparently helpers, see below }
         if hadtypetoken and
             (
               (CurrentScanner.token<>_ID) or
               (
                 (m_function_references in CurrentSettings.ModeSwitches) and
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
                stitem:=SymTableStack.stack;
                while Assigned(stitem) do
                  begin
                    { check records, classes and arrays because they can be specialized }
                    if stitem^.SymTable.SymTableType in [recordsymtable,ObjectSymtable,arraysymtable] then
                      begin
                        is_specialize:=is_specialize or (df_specialization in TStoredDef(stitem^.SymTable.DefOwner).DefOptions);
                        stitem:=stitem^.next;
                      end
                    else
                      break;
                  end;
                if not is_specialize then
                  aktenumdef:=CEnumDef.Create
                else
                  aktenumdef:=nil;
                repeat
                  { if it is a specialization then search the first enum member
                    and get the member owner instead of just created enumdef }
                  if not Assigned(aktenumdef) then
                    begin
                      if not SearchSym(CurrentScanner.pattern,sym,st) then
                        InternalError(202504121)
                      else if sym.typ=enumsym then
                        aktenumdef:=TEnumSym(sym).definition
                      else
                        InternalError(201101021);
                    end;
                  s:=CurrentScanner.orgpattern;
                  defpos:=CurrentTokenPos;
                  consume(_ID);
                  { allow assigning specific numbers }
                  if
                      { in fpc mode also allow := to be compatible
                        with previous 1.0.x versions }
                      ((m_fpc in CurrentSettings.ModeSwitches) and
                       try_to_consume(_ASSIGNMENT)) or
                      try_to_consume(_EQ) then
                    begin
                       oldlocalswitches:=CurrentSettings.LocalSwitches;
                       include(CurrentSettings.LocalSwitches,cs_allow_enum_calc);
                       p:=comp_expr([ef_accept_equal]);
                       CurrentSettings.LocalSwitches:=oldlocalswitches;
                       if (p.nodetype=ordconstn) then
                        begin
                          { we expect an integer or an enum of the
                            same type }
                          if Is_Integer(p.resultdef) or
                             Is_Char(p.resultdef) or
                             Equal_Defs(p.resultdef,aktenumdef) then
                           v:=TOrdConstNode(p).Value
                          else
                           IncompatibleTypes(p.resultdef,S32IntType);
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
                      if (l.svalue<low(LongInt)) or (l.svalue>high(LongInt)) then
                        if m_delphi in CurrentSettings.ModeSwitches then
                          Message(parser_w_enumeration_out_of_range)
                        else
                          Message(parser_e_enumeration_out_of_range);
                      TEnumSymTable(aktenumdef.SymTable).InsertSym(CEnumSym.Create(s,aktenumdef,LongInt(l.svalue)));
                      if not (cs_scopedenums in CurrentSettings.LocalSwitches) or
                          { also provide the global symbol for anonymous enums }
                          not Assigned(newsym) then
                        TStoredSymTable(aktenumdef.owner).InsertSym(CEnumSym.Create(s,aktenumdef,LongInt(l.svalue)));
                      CurrentTokenPos:=storepos;
                    end;
                until not try_to_consume(_COMMA);
                def:=aktenumdef;
                consume(_RKLAMMER);
              end;
            _ARRAY:
              array_dec(false,GenericDef,genericlist);
            _SET:
              set_dec;
            _CARET:
              pointer_dec;
            _RECORD:
              begin
                consume(CurrentScanner.token);
                if (CurrentScanner.idtoken=_HELPER) and (m_advanced_records in CurrentSettings.ModeSwitches) then
                  begin
                    consume(_HELPER);
                    def:=object_dec(odt_helper,name,newsym,GenericDef,genericlist,nil,ht_record);
                  end
                else
                  def:=record_dec(name,newsym,GenericDef,genericlist);
              end;
            _PACKED,
            _BITPACKED:
              begin
                bitpacking :=
                  (cs_bitpacking in CurrentSettings.LocalSwitches) or
                  (CurrentScanner.token = _BITPACKED);
                consume(CurrentScanner.token);
                if CurrentScanner.token=_ARRAY then
                  array_dec(bitpacking,GenericDef,genericlist)
                else if CurrentScanner.token=_SET then
                  set_dec
                else if CurrentScanner.token=_FILE then
                  single_type(def,[stoAllowTypeDef])
                else
                  begin
                    oldpackrecords:=CurrentSettings.PackRecords;
                    if (not bitpacking) or
                       (CurrentScanner.token in [_CLASS,_OBJECT]) then
                      CurrentSettings.PackRecords:=1
                    else
                      CurrentSettings.PackRecords:=BitAlignment;
                    case CurrentScanner.token of
                      _CLASS :
                        begin
                          consume(_CLASS);
                          def:=object_dec(odt_class,name,newsym,GenericDef,genericlist,nil,ht_none);
                        end;
                      _OBJECT :
                        begin
                          consume(_OBJECT);
                          def:=object_dec(odt_object,name,newsym,GenericDef,genericlist,nil,ht_none);
                        end;
                      else begin
                        consume(_RECORD);
                        def:=record_dec(name,newsym,GenericDef,genericlist);
                      end;
                    end;
                    CurrentSettings.PackRecords:=oldpackrecords;
                  end;
              end;
            _DISPINTERFACE :
              begin
                { need extra check here since interface is a keyword
                  in all pascal modes }
                if not(m_class in CurrentSettings.ModeSwitches) then
                  Message(parser_f_need_objfpc_or_delphi_mode);
                consume(CurrentScanner.token);
                def:=object_dec(odt_dispinterface,name,newsym,GenericDef,genericlist,nil,ht_none);
              end;
            _CLASS :
              begin
                consume(CurrentScanner.token);
                { Delphi only allows class of in type blocks }
                if (CurrentScanner.token=_OF) and
                   (
                    not(m_delphi in CurrentSettings.ModeSwitches) or
                    (Block_Type=bt_type)
                   ) then
                  begin
                    consume(_OF);
                    single_type(hdef,SingleTypeOptionsInTypeBlock[Block_Type=bt_type]);
                    if Is_Class(hdef) or
                       Is_ObjCClass(hdef) then
                      def:=CClassRefDef.Create(hdef)
                    else
                      if hdef.typ=ForwardDef then
                        begin
                          def:=CClassRefDef.Create(hdef);
                          CurrentModule.CheckForwardDefs.add(def);
                        end
                    else
                      Message1(type_e_class_or_objcclass_type_expected,hdef.TypeName);
                  end
                else
                if (CurrentScanner.idtoken=_HELPER) then
                  begin
                    consume(_HELPER);
                    def:=object_dec(odt_helper,name,newsym,GenericDef,genericlist,nil,ht_class);
                  end
                else
                  def:=object_dec(DefaultClassType,name,newsym,GenericDef,genericlist,nil,ht_none);
              end;
            _CPPCLASS :
              begin
                consume(CurrentScanner.token);
                def:=object_dec(odt_cppclass,name,newsym,GenericDef,genericlist,nil,ht_none);
              end;
            _OBJCCLASS :
              begin
                if not(m_objectivec1 in CurrentSettings.ModeSwitches) then
                  Message(parser_f_need_objc);

                consume(CurrentScanner.token);
                def:=object_dec(odt_objcclass,name,newsym,GenericDef,genericlist,nil,ht_none);
              end;
            _INTERFACE :
              begin
                { need extra check here since interface is a keyword
                  in all pascal modes }
                if not(m_class in CurrentSettings.ModeSwitches) then
                  Message(parser_f_need_objfpc_or_delphi_mode);
                consume(CurrentScanner.token);
                case CurrentSettings.InterfaceType of
                  it_interfacecom:
                    def:=object_dec(odt_interfacecom,name,newsym,GenericDef,genericlist,nil,ht_none);
                  it_interfacecorba:
                    def:=object_dec(odt_interfacecorba,name,newsym,GenericDef,genericlist,nil,ht_none);
                end;
              end;
            _OBJCPROTOCOL :
               begin
                if not(m_objectivec1 in CurrentSettings.ModeSwitches) then
                  Message(parser_f_need_objc);

                consume(CurrentScanner.token);
                def:=object_dec(odt_objcprotocol,name,newsym,GenericDef,genericlist,nil,ht_none);
               end;
            _OBJCCATEGORY :
               begin
                if not(m_objectivec1 in CurrentSettings.ModeSwitches) then
                  Message(parser_f_need_objc);

                consume(CurrentScanner.token);
                def:=object_dec(odt_objccategory,name,newsym,GenericDef,genericlist,nil,ht_none);
               end;
            _OBJECT :
              begin
                consume(CurrentScanner.token);
                def:=object_dec(odt_object,name,newsym,GenericDef,genericlist,nil,ht_none);
              end;
            _PROCEDURE,
            _FUNCTION:
              begin
                def:=procvar_dec(GenericDef,genericlist,nil,true);
              end;
            _ID:
              begin
                case CurrentScanner.idtoken of
                  _HELPER:
                    begin
                      if hadtypetoken and
                         (m_type_helpers in CurrentSettings.ModeSwitches) then
                        begin
                          { reset hadtypetoken, so that calling code knows that it should not be handled
                            as a "unique" type }
                          hadtypetoken:=false;
                          consume(_HELPER);
                          def:=object_dec(odt_helper,name,newsym,GenericDef,genericlist,nil,ht_type);
                        end
                      else
                        expr_type
                    end;
                  _REFERENCE:
                    begin
                      if CurrentSettings.ModeSwitches*[m_blocks,m_function_references]<>[] then
                        begin
                          consume(_REFERENCE);
                          consume(_TO);
                          { don't register the def as a non-cblock function
                            reference will be converted to an interface }
                          def:=procvar_dec(GenericDef,genericlist,newsym,false);
                          { could be errordef in case of a syntax error }
                          if Assigned(def) and
                             (def.typ=procvardef) then
                            begin
                              include(TProcVarDef(def).ProcOptions,po_is_function_ref);
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
              if (CurrentScanner.token=_KLAMMERAFFE) and (([m_iso,m_extpas]*CurrentSettings.ModeSwitches)<>[]) then
                begin
                  consume(_KLAMMERAFFE);
                  single_type(tt2,SingleTypeOptionsInTypeBlock[Block_Type=bt_type]);
                  def:=CPointerDef.Create(tt2);
                  if tt2.typ=ForwardDef then
                    CurrentModule.CheckForwardDefs.add(def);
                end
              else
                expr_type;
         end;

         if def=nil then
          def:=GenErrorDef;
      end;


    procedure read_anon_type(var def : TDef;parseprocvardir:boolean;GenericDef:TStoredDef);
      var
        hadtypetoken : boolean;
      begin
        hadtypetoken:=false;
        read_named_type(def,nil,GenericDef,nil,parseprocvardir,hadtypetoken);
      end;




end.
