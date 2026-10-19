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

    procedure ResolveForwardTypes;

    { reads a string, file type or a type identifier }
    procedure SingleType(out ADef:TDef;AOptions:TSingleTypeOptions);
    { ... but rejects types that cannot be returned from functions }
    function ResultType(AOptions:TSingleTypeOptions):TDef;

    { reads any type declaration, where the resulting type will get name as type identifier }
    procedure ReadNamedType(var ADef:TDef;const ANewSym:TSym;AGenericDef:TStoredDef;AGenericList:TFPHashObjectList;AParseProcVarDir:Boolean;var AHadTypeToken:Boolean);

    { reads any type declaration }
    procedure ReadAnonType(var ADef : TDef;AParseProcVarDir:Boolean;AGenericDef:TStoredDef);

    { parse nested type declaration of the def (typedef) }
    procedure ParseNestedTypes(var ADef: TDef; AIsForwardDef,AAllowSpecialization: Boolean; ACurrentStructStack: TFPObjectList);


    { parse hint directives (platform, deprecated, ...) for a procdef }
    procedure MaybeParseHintDirectives(AProcDef:TProcDef);

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


    procedure MaybeParseHintDirectives(AProcDef:TProcDef);
      var
        lDummySymOptions : TSymOptions;
        lDeprecatedMsg : PShortString;
      begin
        if Assigned(AProcDef) then
          begin
            lDummySymOptions:=AProcDef.SymOptions;
            lDeprecatedMsg:=AProcDef.DeprecatedMsg;
          end
        else
          begin
            lDummySymOptions:=[];
            lDeprecatedMsg:=nil;
          end;
        while TryConsumeHintDirective(lDummySymOptions,lDeprecatedMsg) do
          Consume(_SEMICOLON);
        if Assigned(AProcDef) then
          begin
            AProcDef.SymOptions:=AProcDef.SymOptions+lDummySymOptions;
            if sp_has_deprecated_msg in lDummySymOptions then
              AProcDef.DeprecatedMsg:=lDeprecatedMsg;
          end
        else
          StringDispose(lDeprecatedMsg);
      end;


    procedure ResolveForwardTypes;
      var
        lIndex: LongInt;
        lTempDef,
        lProcDef,
        lDef : TDef;
        lSearchSym  : TSym;
        lSearchSymTable : TSymTable;
        lTypeName : String;
        lFileInfo : TFilePosInfo;
      begin
        for lIndex:=0 to CurrentModule.CheckForwardDefs.Count-1 do
          begin
            lDef:=TDef(CurrentModule.CheckForwardDefs[lIndex]);
            case lDef.typ of
              pointerdef,
              classrefdef :
                begin
                  { classrefdef inherits from pointerdef }
                  lProcDef:=TAbstractPointerDef(lDef).PointedDef;
                  { still a forward def ? }
                  if lProcDef.typ=ForwardDef then
                   begin
                     { try to resolve the forward }
                     if not Assigned(TForwardDef(lProcDef).ToSymName) then
                       InternalError(200211201);
                     lTypeName:=TForwardDef(lProcDef).ToSymName^;
                     SearchSym(upper(lTypeName),lSearchSym,lSearchSymTable);
                     { we don't need the forwarddef anymore, dispose it }
                     lProcDef.free;
                     lProcDef := nil;
                     TAbstractPointerDef(lDef).PointedDef:=nil; { if error occurs }
                     { was a type sym found ? }
                     if Assigned(lSearchSym) and
                        (lSearchSym.typ=TypeSym) then
                      begin
                        if (sp_generic_dummy in lSearchSym.SymOptions) and
                            not (TTypeSym(lSearchSym).TypeDef.typ=undefineddef) and
                            Assigned(lDef.owner.DefOwner) then
                          begin
                            { is the forward def part of a specialization? }
                            lTempDef:=TDef(lDef.owner.DefOwner);
                            while not TStoredDef(lTempDef).Is_Specialization and Assigned(lTempDef.owner.DefOwner) do
                              lTempDef:=TDef(lTempDef.owner.DefOwner);
                            { if the genericdef of the specialization is the same as the
                              def the dummy points to, then update the found symbol }
                            if TStoredDef(lTempDef).Is_Specialization and
                                (TStoredDef(lTempDef).GenericDef=TTypeSym(lSearchSym).TypeDef) then
                              lSearchSym:=TStoredDef(lTempDef).TypeSym;
                          end;
                        TAbstractPointerDef(lDef).PointedDef:=TTypeSym(lSearchSym).TypeDef;
                        { correctly set the generic/specialization flags and the genericdef }
                        if df_generic in TStoredDef(TAbstractPointerDef(lDef).PointedDef).DefOptions then
                          include(TStoredDef(lDef).DefOptions,df_generic);
                        if df_specialization in TStoredDef(TAbstractPointerDef(lDef).PointedDef).DefOptions then
                          begin
                            include(TStoredDef(lDef).DefOptions,df_specialization);
                            case lDef.typ of
                              pointerdef:
                                TStoredDef(lDef).GenericDef:=CPointerDef.getreusable(TStoredDef(TAbstractPointerDef(lDef).PointedDef).GenericDef);
                              classrefdef:
                                TStoredDef(lDef).GenericDef:=CClassRefDef.Create(TStoredDef(TAbstractPointerDef(lDef).PointedDef).GenericDef);
                              else
                                InternalError(2016120901);
                            end;
                          end;
                        { avoid wrong unused warnings web bug 801 PM }
                        inc(TTypeSym(lSearchSym).refs);
                        { we need a class type for classrefdef }
                        if (lDef.typ=classrefdef) and
                           not(Is_Class(TTypeSym(lSearchSym).TypeDef)) and
                           not(Is_ObjCClass(TTypeSym(lSearchSym).TypeDef)) then
                          MessagePos1(lDef.TypeSym.fileinfo,type_e_class_type_expected,TTypeSym(lSearchSym).TypeDef.TypeName);
                        { this could also be a generic dummy that was not
                          overridden with a specific type }
                        if (sp_generic_dummy in lSearchSym.SymOptions) and
                            (
                              (TTypeSym(lSearchSym).TypeDef.typ=undefineddef) or
                              (
                                { or an unspecialized generic symbol, which is
                                  the case for generics defined in non-Delphi
                                  modes }
                                TStoredDef(TTypeSym(lSearchSym).TypeDef).Is_Generic and
                                not Defs_Belong_To_Same_Generic(lDef,TTypeSym(lSearchSym).TypeDef)
                              )
                            ) then
                          begin
                            if Assigned(lDef.TypeSym) then
                              lFileInfo:=lDef.TypeSym.fileinfo
                            else
                              { this is the case for inline pointer declarations }
                              lFileInfo:=lSearchSym.fileinfo;
                            MessagePos(lFileInfo,parser_e_no_generics_as_types);
                          end;
                      end
                     else
                      begin
                        Message1(sym_e_forward_type_not_resolved,lTypeName);
                        { try to recover }
                        TAbstractPointerDef(lDef).PointedDef:=GenErrorDef;
                      end;
                   end;
                end;
              objectdef :
                begin
                  { give an error as the implementation may follow in an
                    other type block which is allowed by FPC modes }
                  if not(m_fpc in CurrentSettings.ModeSwitches) and
                     (oo_is_forward in TObjectDef(lDef).ObjectOptions) then
                    MessagePos1(lDef.TypeSym.fileinfo,type_e_type_is_not_completly_defined,lDef.TypeName);
                  { generate specializations for generic forwarddefs }
                  if not (oo_is_forward in TObjectDef(lDef).ObjectOptions) and
                      TStoredDef(lDef).Is_Generic then
                    GenerateSpecializationsForForwardDef(lDef);
                 end;
              else
                InternalError(200811071);
            end;
          end;
        CurrentModule.CheckForwardDefs.clear;
      end;


    procedure IDType(var ADef : TDef;AIsForwardDef,ACheckCurrentRecDef,AAllowGenericSyms,AAllowUnitSym:Boolean;out ASym:TSym;out ASymTable:TSymTable;out AIsSpecialize,AIsUnitSpecific:Boolean); forward;


    { def is the outermost type in which other types have to be searched

      isforward indicates whether the current definition can be a forward definition

      if assigned, currentstructstack is a list of tabstractrecorddefs that, from
      last to first, are child types of def that are not yet visible via the
      normal symtable searching routines because they are types that are currently
      being parsed (so using id_type on them after pushing def on the
      symtablestack would result in errors because they'd come back as errordef)
    }
    procedure ParseNestedTypes(var ADef: TDef; AIsForwardDef,AAllowSpecialization: Boolean; ACurrentStructStack: TFPObjectList);
      var
        lDef: TDef;
        lStructStackIndex: LongInt;
        lSearchSym: TSym;
        lSearchSymTable: TSymTable;
        lOldSymTableStack: TSymTableStack;
        lIsSpecialize,
        lIsUnitSpecific : Boolean;
      begin
        if Assigned(ACurrentStructStack) then
          lStructStackIndex:=ACurrentStructStack.count-1
        else
          lStructStackIndex:=-1;
        { handle types inside classes, e.g. TNode.TLongint }
        while (CurrentScanner.FToken=_POINT) do
          begin
             if Is_Class_Or_Object(ADef) or Is_Record(ADef) then
               begin
                 if (ADef.typ=objectdef) then
                   ADef:=Find_Real_Class_Definition(TObjectDef(ADef),false);
                 Consume(_POINT);
                 if (lStructStackIndex>=0) and
                    (TAbstractRecordDef(ACurrentStructStack[lStructStackIndex]).ObjName^=CurrentScanner.FPattern) then
                   begin
                     ADef:=TDef(ACurrentStructStack[lStructStackIndex]);
                     dec(lStructStackIndex);
                     Consume(_ID);
                   end
                 else
                   begin
                     lStructStackIndex:=-1;
                     lOldSymTableStack:=SymTableStack;
                     SymTableStack:=TSymTableStack.Create;
                     SymTableStack.push(TAbstractRecordDef(ADef).SymTable);
                     lDef:=GenErrorDef;
                     IDType(lDef,AIsForwardDef,false,false,false,lSearchSym,lSearchSymTable,lIsSpecialize,lIsUnitSpecific);
                     SymTableStack.pop(TAbstractRecordDef(ADef).SymTable);
                     SymTableStack.free;
                     SymTableStack:=lOldSymTableStack;
                     if lIsSpecialize or
                         (
                           (m_delphi in CurrentSettings.ModeSwitches) and
                           (CurrentScanner.FToken=_LSHARPBRACKET)
                         ) then
                       begin
                         if not AAllowSpecialization then
                           Message(parser_e_no_local_para_def);
                         GenerateSpecialization(lDef,lIsUnitSpecific,false,'',lSearchSym.name,lSearchSymTable);
                       end;
                     ADef:=lDef;
                   end;
               end
             else
               break;
          end;
      end;


    function TryParseStructDefNestedType(out ADef: TDef; ABaseDef: TAbstractRecordDef; AIsForwardDef: Boolean): Boolean;
      var
        lStructDef : TDef;
        lStructDefStack : TFPObjectList;
      begin
         ADef:=nil;
         { use of current parsed object:
           classes, objects, records can be used also in themself }
         lStructDef:=ABaseDef;
         lStructDefStack:=nil;
         while Assigned(lStructDef) and (lStructDef.typ in [objectdef,recorddef]) do
           begin
             if (TAbstractRecordDef(lStructDef).ObjName^=CurrentScanner.FPattern) then
               begin
                 Consume(_ID);
                 ADef:=lStructDef;
                 { we found the top-most match, now check how far down we can
                   follow }
                 lStructDefStack:=TFPObjectList.Create(false);
                 lStructDef:=ABaseDef;
                 while (lStructDef<>ADef) do
                   begin
                     lStructDefStack.add(lStructDef);
                     lStructDef:=TAbstractRecordDef(lStructDef.owner.DefOwner);
                   end;
                 ParseNestedTypes(ADef,AIsForwardDef,true,lStructDefStack);
                 lStructDefStack.free;
                 lStructDefStack := nil;
                 Result:=true;
                 exit;
               end;
             lStructDef:=TDef(TAbstractRecordDef(lStructDef).owner.DefOwner);
           end;
         Result:=false;
      end;

    procedure IDType(var ADef : TDef;AIsForwardDef,ACheckCurrentRecDef,AAllowGenericSyms,AAllowUnitSym:Boolean;out ASym:TSym;out ASymTable:TSymTable;out AIsSpecialize,AIsUnitSpecific:Boolean);
    { reads a type definition }
    { to a appropriating tdef, s gets the name of   }
    { the type to allow name mangling          }
      var
        lNotAType : Boolean;
        lPos : TFilePosInfo;
        lPattern,lOrgPattern : TIDString;
        lToken : TToken;
      begin
         ASym:=nil;
         ASymTable:=nil;
         AIsSpecialize:=false;
         AIsUnitSpecific:=false;
         lPattern:=CurrentScanner.FPattern;
         lOrgPattern:=CurrentScanner.FOrgPattern;
         lPos:=CurrentTokenPos;
         { use of current parsed object:
           classes, objects, records can be used also in themself }
         if ACheckCurrentRecDef and
            TryParseStructDefNestedType(ADef,CurrentStructDef,AIsForwardDef) then
           exit;
         if not AAllowUnitSym and not (m_delphi in CurrentSettings.ModeSwitches) and (CurrentScanner.FIDToken=_SPECIALIZE) then
           begin
             Consume(_ID);
             AIsSpecialize:=true;
             lPattern:=CurrentScanner.FPattern;
             lOrgPattern:=CurrentScanner.FOrgPattern;
             lPos:=CurrentTokenPos;
           end;
         { Use the special searchsym_type that search only types }
         if not SearchSym_Type(lPattern,ASym,ASymTable) then
           { for a good error message we need to know whether the symbol really did not exist or
             whether we found a non-type one }
           lNotAType:=SearchSym(lPattern,ASym,ASymTable)
         else
           lNotAType:=false;
         { handle unit specification like System.Writeln }
         if AAllowUnitSym then
           AIsUnitSpecific:=TryConsumeUnitSym(ASym,ASymTable,lToken,[cufConsumeID,cufAllowSpecialize],AIsSpecialize,lPattern)
         else
           begin
             lToken:=_ID;
             AIsUnitSpecific:=false;
           end;
         Consume(lToken);
         if lNotAType then
           begin
             { reset the symbol and symtable to not leak any unexpected values }
             ASym:=nil;
             ASymTable:=nil;
           end;
         { Types are first defined with an error def before assigning
           the real type so check if it's an errordef. if so then
           give an error. Only check for typesyms in the current symbol
           table as forwarddef are not resolved directly }
         if Assigned(ASym) and
            (ASym.typ=TypeSym) and
            ((TTypeSym(ASym).TypeDef.typ=errordef) or
            (not AAllowGenericSyms and
            (TTypeSym(ASym).TypeDef.typ=undefineddef) and
            not (sp_generic_para in ASym.SymOptions) and
            not (sp_explicitrename in ASym.SymOptions) and
            not Assigned(ASym.owner.DefOwner) and
            { use df_generic instead of is_generic to allow aliases in nested types as well }
            not (df_generic in TStoredDef(ASym.owner.DefOwner).DefOptions))) then
          begin
            Message1(type_e_type_is_not_completly_defined,TTypeSym(ASym).realname);
            ADef:=GenErrorDef;
            exit;
          end;
         { are we parsing a possible forward def ? }
         if AIsForwardDef and
            not(AIsUnitSpecific) then
           begin
             ADef:=CForwardDef.Create(lOrgPattern,lPos);
             exit;
           end;
         { unknown sym ? }
         if not Assigned(ASym) and not lNotAType then
          begin
            Message1(sym_e_id_not_found,lOrgPattern);
            ADef:=GenErrorDef;
            exit;
          end;
         { type sym ? }
         if lNotAType or (ASym.typ<>TypeSym) then
          begin
            Message(type_e_type_id_expected);
            ADef:=GenErrorDef;
            exit;
          end;
         { Give an error when referring to an errordef }
         if (TTypeSym(ASym).TypeDef.typ=errordef) then
          begin
            Message(sym_e_error_in_type_def);
            ADef:=GenErrorDef;
            exit;
          end;
         { In non-Delphi modes the class/record name of a generic might be used
           in the declaration of sub types without type parameters; in that case
           we need to check by name as the link from the dummy symbol to the
           current type is not yet established }
         if (sp_generic_dummy in ASym.SymOptions) and
             Assigned(CurrentStructDef) and
             (df_generic in CurrentStructDef.DefOptions) and
             (TTypeSym(ASym).TypeDef.typ=undefineddef) and
             not (m_delphi in CurrentSettings.ModeSwitches) then
           begin
             ADef:=Get_Generic_In_Hierarchy_By_Name(ASym,CurrentStructDef);
             if Assigned(ADef) then
               exit;
           end;
        ADef:=TTypeSym(ASym).TypeDef;
      end;


    procedure SingleType(out ADef:TDef;AOptions:TSingleTypeOptions);

       function HandleDummySym(ASym:TSym):TDef;
         begin
           ASym:=ResolveGenericDummySym(ASym.name);
           if Assigned(ASym) and
               not (sp_generic_dummy in ASym.SymOptions) and
               (ASym.typ=TypeSym) then
             Result:=TTypeSym(ASym).TypeDef
           else
             begin
               Message(parser_e_no_generics_as_types);
               Result:=GenErrorDef;
             end;
         end;

       var
         lDef : TDef;
         lIsUnitSpecific,
         lIsSpecialize,
         lDoSpecialize,
         lAgain : Boolean;
         lSearchSym : TSym;
         lSearchSymTable : TSymTable;
         lSymName : TSymStr;
       begin
         lDoSpecialize:=false;
         lIsUnitSpecific:=false;
         lSearchSymTable:=nil;
         lSearchSym:=nil;
         repeat
           lAgain:=false;
             case CurrentScanner.FToken of
               _STRING:
                 StringDec(ADef,stoAllowTypeDef in AOptions);
               _FILE:
                 begin
                    Consume(_FILE);
                    if (CurrentScanner.FToken=_OF) then
                      begin
                         if not(stoAllowTypeDef in AOptions) then
                           Message(parser_e_no_local_para_def);
                         Consume(_OF);
                         SingleType(lDef,[stoAllowTypeDef]);
                         if Is_Managed_Type(lDef) then
                           Message(parser_e_no_refcounted_typed_file);
                         ADef:=CFileDef.CreateTyped(lDef);
                      end
                    else
                      ADef:=CFileType;
                 end;

               _ID:
                 begin
                   if not (m_delphi in CurrentSettings.ModeSwitches) and TryToConsume(_SPECIALIZE) then
                     begin
                       if ([stoAllowSpecialization,stoAllowTypeDef] * AOptions = []) then
                         begin
                           Message(parser_e_no_local_para_def);

                           { try to recover }
                           while CurrentScanner.FToken<>_SEMICOLON do
                             Consume(CurrentScanner.FToken);
                           ADef:=GenErrorDef;
                         end
                       else
                         begin
                           lDoSpecialize:=true;
                           lAgain:=true;
                         end;
                     end
                   else
                     begin
                       IDType(ADef,stoIsForwardDef in AOptions,true,true,not lDoSpecialize or ([stoAllowSpecialization,stoAllowTypeDef]*AOptions=[]),lSearchSym,lSearchSymTable,lIsSpecialize,lIsUnitSpecific);
                       if lIsSpecialize and lDoSpecialize then
                         InternalError(2015021301);
                       if lIsSpecialize then
                         lDoSpecialize:=true;
                       ParseNestedTypes(ADef,stoIsForwardDef in AOptions,[stoAllowSpecialization,stoAllowTypeDef]*AOptions<>[],nil);
                     end;
                 end;

               else
                 begin
                   message(type_e_type_id_expected);
                   ADef:=GenErrorDef;
                 end;
            end;
        until not lAgain;
        if ([stoAllowSpecialization,stoAllowTypeDef] * AOptions <> []) and
           (m_delphi in CurrentSettings.ModeSwitches) then
          lDoSpecialize:=CurrentScanner.FToken in [_LSHARPBRACKET,_LT];
        if lDoSpecialize and
            (ADef.typ=ForwardDef) then
          begin
            if not Assigned(lSearchSym) or not (lSearchSym.typ=TypeSym) then
              begin
                Message1(type_e_type_is_not_completly_defined,ADef.TypeName);
                ADef:=GenErrorDef;
                lDoSpecialize:=false;
              end;
          end;
        { recover from error? }
        if ADef.typ=errordef then
          begin
            while (CurrentScanner.FToken<>_SEMICOLON) and (CurrentScanner.FToken<>_RKLAMMER) do
              Consume(CurrentScanner.FToken);
          end
        else if lDoSpecialize then
          begin
            if ADef.typ=ForwardDef then
              ADef:=TTypeSym(lSearchSym).TypeDef;
            if Assigned(lSearchSym) then
              lSymName:=lSearchSym.name
            else if Assigned(ADef.TypeSym) then
              begin
                lSymName:=ADef.TypeSym.name;
                lSearchSymTable:=ADef.TypeSym.owner;
              end
            else if (ADef.typ=objectdef) then
              begin
                lSymName:=TObjectDef(ADef).ObjName^;
                if Assigned(ADef.owner) then
                  lSearchSymTable:=ADef.owner
                else
                  lSearchSymTable:=SymTableStack.top;
              end
            else
              lSymName:='';
            GenerateSpecialization(ADef,lIsUnitSpecific,stoParseClassParent in AOptions,'',lSymName,lSearchSymTable);
            ParseNestedTypes(ADef,stoIsForwardDef in AOptions,[stoAllowSpecialization,stoAllowTypeDef]*AOptions<>[],nil);
          end
        else
          begin
            if Assigned(CurrentSpecializeDef) and (ADef=CurrentSpecializeDef.GenericDef) then
              begin
                ADef:=CurrentSpecializeDef
              end
            else if (ADef=CurrentGenericDef) then
              begin
                ADef:=CurrentGenericDef
              end
            { when parsing a nested specialization in non-Delphi mode it might
              use the name of the topmost generic without type paramaters, thus
              def will contain the generic definition, but we need a reference
              to the specialization of that generic }
            { TODO : only in non-Delphi modes? }
            else if Assigned(CurrentStructDef) and
                (df_specialization in CurrentStructDef.DefOptions) and
                Return_Specialization_Of_Generic(CurrentStructDef,ADef,lDef) then
              begin
                ADef:=lDef
              end
            else if TStoredDef(ADef).Is_Generic and
                not
                  (
                    ParseGeneric and
                    (
                      { if this is a generic parameter than it has already been checked that this is
                        a valid usage of a generic }
                      (sp_generic_para in lSearchSym.SymOptions) or
                      (
                        (CurrentGenericDef.typ in [recorddef,objectdef]) and
                        (
                          { if both defs belong to the same generic (e.g. both are
                            subtypes) then we must allow the usage }
                          Defs_Belong_To_Same_Generic(ADef,CurrentGenericDef) or
                          { this is needed to correctly resolve "type Foo=SomeGeneric<T>"
                            declarations inside a generic }
                          Sym_Is_Owned_By(lSearchSym,TAbstractRecordDef(CurrentGenericDef).SymTable)
                        )
                      )
                    )
                  )
                then
              begin
                ADef:=HandleDummySym(lSearchSym);
              end
            else if (ADef.typ=undefineddef) and
                (sp_generic_dummy in lSearchSym.SymOptions) then
              begin
                if ParseGeneric and
                    (CurrentGenericDef.typ in [recorddef,objectdef]) and
                    (Pos(upper(lSearchSym.realname),TAbstractRecordDef(CurrentGenericDef).ObjName^)=1) then
                  begin
                    if m_delphi in CurrentSettings.ModeSwitches then
                      begin
                        ADef:=HandleDummySym(lSearchSym);
                      end
                    else
                      ADef:=CurrentGenericDef;
                  end
                else
                  begin
                    ADef:=HandleDummySym(lSearchSym);
                  end;
              end
            else if Is_ClassHelper(ADef) and
                not (stoParseClassParent in AOptions) then
              begin
                Message(parser_e_no_category_as_types);
                ADef:=GenErrorDef
              end
          end;
      end;


    function ResultType(AOptions:TSingleTypeOptions):TDef;
      begin
        SingleType(Result,AOptions);
        { file types cannot be function results }
        if Result.typ=filedef then
          message(parser_e_illegal_function_result);
      end;

    procedure ParseRecordMembers(ARecordSym:TSym);

      function IsAnonOrLocal: Boolean;
        begin
          Result:=(CurrentStructDef.ObjName^='') or
                  not(SymTableStack.stack^.next^.SymTable.SymTableType in [GlobalSymTable,staticsymtable,objectsymtable,recordsymtable]);
        end;

      var
        lProcDef : TProcDef;
        lOldParseOnly: Boolean;
        lMemberBlockType : TBlockType;
        lHadGeneric,
        lFieldsAllowed, lIsClassDef, lClassFields, lThreadVarFields: Boolean;
        lVarDecOptions: TVarDecOptions;
        lRTTIAttrsDef: TRTTIAttributeList;
        lFieldCount : Integer;
        lAttrElementCount : Integer;

      procedure CheckUnboundAttributes;
        begin
          if Assigned(lRTTIAttrsDef) and (lRTTIAttrsDef.GetAttributeCount>0) then
            Message1(parser_e_unbound_attribute,TRTTIAttribute(lRTTIAttrsDef.RTTIAttributes[0]).TypeSym.prettyname);
          lRTTIAttrsDef.free;
          lRTTIAttrsDef:=nil;
        end;

      begin
        { empty record declaration ? }
        if (CurrentScanner.FToken=_SEMICOLON) then
          Exit;

        CurrentStructDef.SymTable.CurrentVisibility:=vis_public;
        lFieldsAllowed:=true;
        lIsClassDef:=false;
        lHadGeneric:=false;
        lClassFields:=false;
        lThreadVarFields:=false;
        lMemberBlockType:=bt_general;
        lRTTIAttrsDef := nil;
        repeat
          case CurrentScanner.FToken of
            _TYPE :
              begin
                CheckUnboundAttributes;
                Consume(_TYPE);
                lMemberBlockType:=bt_type;

                { local and anonymous records can not have inner types. skip top record symtable }
                if IsAnonOrLocal then
                  Message(parser_e_no_types_in_local_anonymous_records);
              end;
            _VAR :
              begin
                CheckUnboundAttributes;
                Consume(_VAR);
                lFieldsAllowed:=true;
                lMemberBlockType:=bt_general;
                lClassFields:=lIsClassDef;
                lThreadVarFields:=false;
                lIsClassDef:=false;
              end;
            _THREADVAR :
              begin
                CheckUnboundAttributes;
                if not lIsClassDef then
                  begin
                    message(parser_e_threadvar_must_be_class);
                    { for error recovery we enforce class fields }
                    lIsClassDef:=true;
                  end;
                Consume(_THREADVAR);
                lFieldsAllowed:=true;
                lMemberBlockType:=bt_general;
                lClassFields:=lIsClassDef;
                lThreadVarFields:=true;
                lIsClassDef:=false;
              end;
            _CONST:
              begin
                CheckUnboundAttributes;
                Consume(_CONST);
                lMemberBlockType:=bt_const;

                { local and anonymous records can not have constants. skip top record symtable }
                if IsAnonOrLocal then
                  Message(parser_e_no_consts_in_local_anonymous_records);
              end;
            _ID, _CASE, _OPERATOR :
              begin
                case CurrentScanner.FIDToken of
                  _PRIVATE :
                    begin
                      CheckUnboundAttributes;
                       Consume(_PRIVATE);
                       CurrentStructDef.SymTable.CurrentVisibility:=vis_private;
                       include(CurrentStructDef.ObjectOptions,oo_has_private);
                       lFieldsAllowed:=true;
                       lIsClassDef:=false;
                       lClassFields:=false;
                       lThreadVarFields:=false;
                       lMemberBlockType:=bt_general;
                     end;
                   _PROTECTED :
                     begin
                       CheckUnboundAttributes;
                       Message1(parser_e_not_allowed_in_record,tokeninfo^[_PROTECTED].str);
                       Consume(_PROTECTED);
                       CurrentStructDef.SymTable.CurrentVisibility:=vis_protected;
                       include(CurrentStructDef.ObjectOptions,oo_has_protected);
                       lFieldsAllowed:=true;
                       lIsClassDef:=false;
                       lClassFields:=false;
                       lThreadVarFields:=false;
                       lMemberBlockType:=bt_general;
                     end;
                   _PUBLIC :
                     begin
                       CheckUnboundAttributes;
                       Consume(_PUBLIC);
                       CurrentStructDef.SymTable.CurrentVisibility:=vis_public;
                       lFieldsAllowed:=true;
                       lIsClassDef:=false;
                       lClassFields:=false;
                       lThreadVarFields:=false;
                       lMemberBlockType:=bt_general;
                     end;
                   _PUBLISHED :
                     begin
                       CheckUnboundAttributes;
                       Message(parser_e_no_record_published);
                       Consume(_PUBLISHED);
                       CurrentStructDef.SymTable.CurrentVisibility:=vis_published;
                       lFieldsAllowed:=true;
                       lIsClassDef:=false;
                       lClassFields:=false;
                       lThreadVarFields:=false;
                       lMemberBlockType:=bt_general;
                     end;
                   _STRICT :
                     begin
                        Consume(_STRICT);
                        if CurrentScanner.FToken=_ID then
                          begin
                            case CurrentScanner.FIDToken of
                              _PRIVATE:
                                begin
                                  Consume(_PRIVATE);
                                  CurrentStructDef.SymTable.CurrentVisibility:=vis_strictprivate;
                                  include(CurrentStructDef.ObjectOptions,oo_has_strictprivate);
                                end;
                              _PROTECTED:
                                begin
                                  { "strict protected" is not allowed for records }
                                  Message1(parser_e_not_allowed_in_record,tokeninfo^[_STRICT].str+' '+tokeninfo^[_PROTECTED].str);
                                  Consume(_PROTECTED);
                                  CurrentStructDef.SymTable.CurrentVisibility:=vis_strictprotected;
                                  include(CurrentStructDef.ObjectOptions,oo_has_strictprotected);
                                end;
                              else
                                message(parser_e_protected_or_private_expected);
                            end;
                          end
                        else
                          message(parser_e_protected_or_private_expected);
                        lFieldsAllowed:=true;
                        lIsClassDef:=false;
                        lClassFields:=false;
                        lThreadVarFields:=false;
                        lMemberBlockType:=bt_general;
                     end
                    else
                    if lIsClassDef and (CurrentScanner.FIDToken=_OPERATOR) then
                      begin
                        CheckUnboundAttributes;
                        lProcDef:=ParseRecordMethodDec(CurrentStructDef,lIsClassDef,false);
                        lFieldsAllowed:=false;
                        lIsClassDef:=false;
                      end
                    else
                      begin
                        if lMemberBlockType=bt_general then
                          begin
                            if (CurrentScanner.FIDToken=_GENERIC) and
                                not (m_delphi in CurrentSettings.ModeSwitches) and
                                not lFieldsAllowed then
                              begin
                                if lHadGeneric then
                                  Message(parser_e_procedure_or_function_expected);
                                Consume(_ID);
                                lHadGeneric:=true;
                                if not (CurrentScanner.FToken in [_PROCEDURE,_FUNCTION,_CLASS]) then
                                  Message(parser_e_procedure_or_function_expected);
                              end
                            else
                              begin
                                if (not lFieldsAllowed)and(CurrentScanner.FIDToken<>_CASE) then
                                  Message(parser_e_field_not_allowed_here);
                                lVarDecOptions:=[vdRecord];
                                if lClassFields then
                                  include(lVarDecOptions,vdClass);
                                if not (m_delphi in CurrentSettings.ModeSwitches) then
                                  include(lVarDecOptions,vdCheckGeneric);
                                if lThreadVarFields then
                                  include(lVarDecOptions,vdThreadVar);
                                lFieldCount:=CurrentStructDef.SymTable.SymList.Count;
                                ReadRecordFields(lVarDecOptions,nil,nil,lHadGeneric,lAttrElementCount);
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
                                if Assigned(lRTTIAttrsDef) then
                                  begin
                                  While (lAttrElementCount>1) do
                                    begin
                                    TRTTIAttributeList.CopyAndBind(lRTTIAttrsDef,(CurrentStructDef.SymTable.SymList[lFieldCount] as TFieldVarSym).RTTIAttributeList);
                                    inc(lFieldCount);
                                    dec(lAttrElementCount);
                                    end;
                                  if lFieldCount<CurrentStructDef.SymTable.SymList.Count then
                                    TRTTIAttributeList.bind(lRTTIAttrsDef,(CurrentStructDef.SymTable.SymList[lFieldCount] as TFieldVarSym).RTTIAttributeList);
                                  end;
                              end;
                          end
                        else if lMemberBlockType=bt_type then
                          TypesDec(true,lHadGeneric, lRTTIAttrsDef)
                        else if lMemberBlockType=bt_const then
                          ConstsDec(true,true,lHadGeneric)
                        else
                          InternalError(201001110);
                      end;
                end;
              end;
            _PROPERTY :
              begin
                if IsAnonOrLocal then
                  Message(parser_e_no_properties_in_local_anonymous_records);
                StructPropertyDec(lIsClassDef, lRTTIAttrsDef);
                lFieldsAllowed:=false;
                lIsClassDef:=false;
              end;
            _CLASS:
              begin
                CheckUnboundAttributes;
                lIsClassDef:=false;
                { read class method/field/property }
                Consume(_CLASS);
                { class modifier is only allowed for procedures, functions, }
                { constructors, destructors, fields and properties          }
                if (lHadGeneric and not (CurrentScanner.FToken in [_FUNCTION,_PROCEDURE])) or
                    (not lHadGeneric and (not ((CurrentScanner.FToken in [_FUNCTION,_PROCEDURE,_PROPERTY,_VAR,_DESTRUCTOR,_OPERATOR,_THREADVAR]) or (CurrentScanner.FToken=_CONSTRUCTOR)) and
                   not((CurrentScanner.FToken=_ID) and (CurrentScanner.FIDToken=_OPERATOR)))) then
                  Message(parser_e_procedure_or_function_expected);

                if IsAnonOrLocal then
                  Message(parser_e_no_class_in_local_anonymous_records);

                lIsClassDef:=true;
              end;
            _PROCEDURE,
            _FUNCTION:
              begin
                if IsAnonOrLocal then
                  Message(parser_e_no_methods_in_local_anonymous_records);
                lProcDef:=ParseRecordMethodDec(CurrentStructDef,lIsClassDef,lHadGeneric);
                if Assigned(lRTTIAttrsDef) then
                  begin
                  TRTTIAttributeList.bind(lRTTIAttrsDef,lProcDef.RTTIAttributeList);
                  lRTTIAttrsDef:=Nil;
                  end;
                lHadGeneric:=false;
                lFieldsAllowed:=false;
                lIsClassDef:=false;
              end;
            _CONSTRUCTOR :
              begin
                CheckUnboundAttributes;
                if IsAnonOrLocal then
                  Message(parser_e_no_methods_in_local_anonymous_records);
                if not lIsClassDef and (CurrentStructDef.SymTable.CurrentVisibility <> vis_public) then
                  Message(parser_w_constructor_should_be_public);

                { only 1 class constructor is allowed }
                if lIsClassDef and (oo_has_class_constructor in CurrentStructDef.ObjectOptions) then
                  Message1(parser_e_only_one_class_constructor_allowed, CurrentStructDef.ObjRealName^);

                lOldParseOnly:=ParseOnly;
                ParseOnly:=true;
                if lIsClassDef then
                  lProcDef:=ClassConstructorHead(CurrentStructDef)
                else
                  begin
                    lProcDef:=ConstructorHead;
                    if lProcDef.MinParaCount = 0 then
                      MessagePos(lProcDef.ProcSym.fileinfo,parser_e_no_parameterless_constructor_in_records);
                  end;

                ParseOnly:=lOldParseOnly;
                lFieldsAllowed:=false;
                lIsClassDef:=false;
              end;
            _DESTRUCTOR :
              begin
                CheckUnboundAttributes;
                if IsAnonOrLocal then
                  Message(parser_e_no_methods_in_local_anonymous_records);
                if not lIsClassDef then
                  Message(parser_e_no_destructor_in_records);

                { only 1 class destructor is allowed }
                if lIsClassDef and (oo_has_class_destructor in CurrentStructDef.ObjectOptions) then
                  Message1(parser_e_only_one_class_destructor_allowed, CurrentStructDef.ObjRealName^);

                lOldParseOnly:=ParseOnly;
                ParseOnly:=true;
                if lIsClassDef then
                  lProcDef:=ClassDestructorHead(CurrentStructDef)
                else
                  lProcDef:=DestructorHead;

                ParseOnly:=lOldParseOnly;
                lFieldsAllowed:=false;
                lIsClassDef:=false;
              end;
            _LECKKLAMMER:
              begin
                if m_prefixed_attributes in CurrentSettings.ModeSwitches then
                  ParseRTTIAttributes(lRTTIAttrsDef)
                else
                  Consume(_ID);
              end;
            _END :
              begin
                Consume(_END);
                break;
              end;
            else
              Consume(_ID); { Give a ident expected message, like tp7 }
          end;
        until false;
      end;

    { reads a record declaration }
    function RecordDec(const AName:TIDString;ARecordSym:TSym;AGenericDef:TStoredDef;AGenericList:TFPHashObjectList):TDef;
      var
         lOldDef : TDef;

      procedure SetTypeSym;
        begin
          if not Assigned(ARecordSym) then
            exit;
          if TTypeSym(ARecordSym).TypeDef=CurrentStructDef then
            exit;
          TTypeSym(ARecordSym).TypeDef:=CurrentStructDef;
          CurrentStructDef.TypeSym:=ARecordSym;
        end;

      procedure ResetTypeSym;
        begin
          if not Assigned(ARecordSym) then
            exit;
          if TTypeSym(ARecordSym).TypeDef<>CurrentStructDef then
            exit;
          TTypeSym(ARecordSym).TypeDef:=lOldDef;
          CurrentStructDef.TypeSym:=nil;
        end;

      var
         lOldCurrentStructDef: TAbstractRecordDef;
         lOldCurrentGenericDef,
         lOldCurrentSpecializeDef: TStoredDef;
         lOldParseGeneric: Boolean;
         lRecordSymTable: TRecordSymTable;
         lHadGenDummy : Boolean;
         lAlignment: Integer;
         lDummyAttrElementCount : Integer;
      begin
         lOldCurrentStructDef:=CurrentStructDef;
         lOldCurrentGenericDef:=CurrentGenericDef;
         lOldCurrentSpecializeDef:=CurrentSpecializeDef;
         lOldParseGeneric:=ParseGeneric;

         CurrentGenericDef:=nil;
         CurrentSpecializeDef:=nil;
         { create recdef }
         lRecordSymTable:=TRecordSymTable.Create(AName,CurrentSettings.PackRecords,CurrentSettings.Alignment.RecordAlignMin);
         { can't use recst.realname^ instead of n, because recst.realname is
           nil in case of an empty name }
         CurrentStructDef:=CRecordDef.Create(AName,lRecordSymTable);
         Result:=CurrentStructDef;
         { insert in symtablestack }
         SymTableStack.push(lRecordSymTable);

         { usage of specialized type inside its generic template }
         if Assigned(AGenericDef) then
           CurrentSpecializeDef:=CurrentStructDef
         { reject declaration of generic class inside generic class }
         else if Assigned(AGenericList) then
           CurrentGenericDef:=CurrentStructDef;

         { nested types of specializations are specializations as well }
         if Assigned(lOldCurrentStructDef) and
             (df_specialization in lOldCurrentStructDef.DefOptions) then
           include(CurrentStructDef.DefOptions,df_specialization);
         if Assigned(lOldCurrentStructDef) and
             (df_generic in lOldCurrentStructDef.DefOptions) then
           include(CurrentStructDef.DefOptions,df_generic);

         InsertGenericParameterTypes(CurrentStructDef,AGenericDef,AGenericList,false);
         { when we are parsing a generic already then this is a generic as
           well }
         if lOldParseGeneric then
           include(CurrentStructDef.DefOptions, df_generic);
         ParseGeneric:=(df_generic in CurrentStructDef.DefOptions);
         if ParseGeneric and not Assigned(CurrentGenericDef) then
           CurrentGenericDef:=CurrentStructDef;
         { in non-Delphi modes we need a strict private symbol without type
           count and type parameters in the name to simply resolving }
         MaybeInsertGenericRenameSymbol(AName,AGenericList);
         { apply $RTTI directive to current object }
         CurrentStructDef.Apply_RTTI_Directive(CurrentModule.RTTIDirective);

         { the correct typesym<->def relationship is needed for example when
           parsing parameters that are specializations of the record, when
           using nested constants and such or when specializing the type
           itself as a pointer type }
         if Assigned(ARecordSym) then
           lOldDef:=TTypeSym(ARecordSym).TypeDef
         else
           lOldDef:=nil;
         SetTypeSym;

         if m_advanced_records in CurrentSettings.ModeSwitches then
           begin
             ParseRecordMembers(ARecordSym);
           end
         else
           begin
             ReadRecordFields([vdRecord],nil,nil,lHadGenDummy,lDummyAttrElementCount);
             Consume(_END);
            end;

         ResetTypeSym;

         if (CurrentScanner.FToken=_ID) and (CurrentScanner.FPattern='ALIGN') then
           begin
             Consume(_ID);
             lAlignment:=GetIntConst.svalue;
             { "(alignment and not $7F) = 0" means it's between 0 and 127, and
               PopCnt = 1 for powers of 2 }
             if ((lAlignment and not $7F) <> 0) or (PopCnt(Byte(lAlignment))<>1) then
               message(scanner_e_illegal_alignment_directive)
             else
               begin
                 lRecordSymTable.RecordAlignment:=shortint(lAlignment);
                 lRecordSymTable.ExplicitRecordAlignment:=shortint(lAlignment);
               end;
           end;
         { make the record size aligned (has to be done before inserting the
           parameters, because that may depend on the record's size) }
         lRecordSymTable.AddAlignmentPadding;

         Insert_Struct_Hidden_Paras(TRecordDef(CurrentStructDef));
         { restore symtable stack }
         SymTableStack.pop(lRecordSymTable);
         if TRecordDef(CurrentStructDef).Is_Packed and Is_Managed_Type(CurrentStructDef) then
           Message(type_e_no_packed_inittable);
         { restore old state }
         ParseGeneric:=lOldParseGeneric;
         CurrentStructDef:=lOldCurrentStructDef;
         CurrentGenericDef:=lOldCurrentGenericDef;
         CurrentSpecializeDef:=lOldCurrentSpecializeDef;
      end;


    { reads a type definition and returns a pointer to it }
    procedure ReadNamedType(var ADef:TDef;const ANewSym:TSym;AGenericDef:TStoredDef;AGenericList:TFPHashObjectList;AParseProcVarDir:Boolean;var AHadTypeToken:Boolean);
      const
        cSingleTypeOptionsInTypeBlock:array[Boolean] of TSingleTypeOptions = ([],[stoIsForwardDef]);
      var
        lNode : TNode;
        lTypeDef : TDef;
        lEnumDef : TEnumDef;
        lMemberName : TIDString;
        lEnumValue,lExplicitEnumValue : TConstExprInt;
        lOldPackRecords : LongInt;
        lDefPos,lSavedPos : TFilePosInfo;
        lName: TIDString;

        procedure ExprType;
        var
           lLeftNode,lRightNode : TNode;
           lLowValue,lHighValue   : TConstExprInt;
           lOldBlockType : TBlockType;
           lDoSpecialize : Boolean;
           lNewDef  : TDef;
           lSym     : TSym;
           lGenericString  : String;
           lGenericCount : LongInt;
        begin
           lOldBlockType:=Block_Type;
           lDoSpecialize:=false;
           { use of current parsed object:
             classes, objects, records can be used also in themself }
           if (CurrentScanner.FToken=_ID) then
             if TryParseStructDefNestedType(ADef,CurrentStructDef,false) then
               exit;
           { we can't accept a equal in type }
           lLeftNode:=CompExpr([efTypeOnly]);
           if TryToConsume(_POINTPOINT) then
             begin
               { get high value of range }
               lRightNode:=CompExpr([]);
               { make both the same type or give an error. This is not
                 done when both are integer values, because typecasting
                 between -3200..3200 will result in a signed-unsigned
                 conflict and give a range check error (PFV) }
               if not(Is_Integer(lLeftNode.resultdef) and Is_Integer(lRightNode.resultdef)) then
                 InsertTypeConv(lLeftNode,lRightNode.resultdef);
               { both must be evaluated to constants now }
               if (lLeftNode.nodetype=ordconstn) and
                  (lRightNode.nodetype=ordconstn) then
                 begin
                   lLowValue:=TOrdConstNode(lLeftNode).Value;
                   lHighValue:=TOrdConstNode(lRightNode).Value;
                   { Check bounds }
                   if lHighValue<lLowValue then
                     message(parser_e_upper_lower_than_lower)
                   else if (lLowValue.signed and (lLowValue.svalue<0)) and (not lHighValue.signed and (lHighValue.uvalue>qword(high(Int64)))) then
                     message(type_e_cant_eval_constant_expr)
                   else
                     begin
                       { All checks passed, create the new def }
                       case lLeftNode.resultdef.typ of
                         enumdef :
                           ADef:=CEnumDef.Create_Subrange(TEnumDef(lLeftNode.resultdef),lLowValue.svalue,lHighValue.svalue);
                         orddef :
                           begin
                             if Is_Char(lLeftNode.resultdef) then
                               ADef:=COrdDef.Create(uchar,lLowValue,lHighValue,true)
                             else
                               if Is_Boolean(lLeftNode.resultdef) then
                                 ADef:=COrdDef.Create(pasbool1,lLowValue,lHighValue,true)
                               else if Is_Signed(lLeftNode.resultdef) then
                                 ADef:=COrdDef.Create(Range_To_BaseType(lLowValue,lHighValue),lLowValue,lHighValue,true)
                               else
                                 ADef:=COrdDef.Create(Range_To_BaseType(lLowValue,lHighValue),lLowValue,lHighValue,true);
                           end;
                         else
                           InternalError(2019050527);
                       end;
                     end;
                 end
               else
                 Message(sym_e_error_in_type_def);
               lRightNode.free;
               lRightNode := nil;
             end
           else
             begin
               { a simple type renaming or generic specialization }
               if (lLeftNode.nodetype=typen) then
                 begin
                   ADef:=TTypeNode(lLeftNode).resultdef;
                   { Delphi mode specialization? }
                   if (m_delphi in CurrentSettings.ModeSwitches) then
                     lDoSpecialize:=CurrentScanner.FToken=_LSHARPBRACKET
                   else
                     begin
                       lDoSpecialize:=false;
                       { in non-Delphi modes we might get a inline specialization
                         without "specialize" or "<T>" of the same type we're
                         currently parsing, so we need to handle that special }
                       lNewDef:=nil;
                     end;
                   if not lDoSpecialize and
                       Assigned(TTypeNode(lLeftNode).TypeSym) and
                       (TTypeNode(lLeftNode).TypeSym.typ=TypeSym) and
                       (sp_generic_dummy in TTypeNode(lLeftNode).TypeSym.SymOptions) and
                       Assigned(CurrentStructDef) and
                       (
                         (
                           not (m_delphi in CurrentSettings.ModeSwitches) and
                           (TTypeSym(TTypeNode(lLeftNode).TypeSym).TypeDef.typ=undefineddef) and
                           (df_generic in CurrentStructDef.DefOptions) and
                           (TTypeSym(TTypeNode(lLeftNode).TypeSym).TypeDef.owner=CurrentStructDef.owner) and
                           (upper(TTypeNode(lLeftNode).TypeSym.realname)=copy(CurrentStructDef.ObjName^,1,pos('$',CurrentStructDef.ObjName^)-1))
                         ) or (
                           { this could be a nested specialization which uses
                             the type name of a surrounding generic to
                             reference the specialization of said surrounding
                             class }
                           (df_specialization in CurrentStructDef.DefOptions) and
                           Return_Specialization_Of_Generic(CurrentStructDef,TTypeSym(TTypeNode(lLeftNode).TypeSym).TypeDef,lNewDef)
                         )
                       )
                       then
                     begin
                       if Assigned(lNewDef) then
                         ADef:=lNewDef
                       else
                         ADef:=CurrentStructDef;
                       if Assigned(ADef) then
                         { handle nested types }
                         PostCompExprGenDef(ADef)
                       else
                         ADef:=GenErrorDef;
                     end;
                   if lDoSpecialize then
                     begin
                       if not Assigned(TTypeNode(lLeftNode).TypeSym) then
                         InternalError(2025103102);
                       GenerateSpecialization(ADef,false,false,lName,TTypeNode(lLeftNode).TypeSym.name,TTypeNode(lLeftNode).TypeSym.owner);
                       { handle nested types }
                       if Assigned(ADef) then
                         PostCompExprGenDef(ADef);
                     end
                   else
                     begin
                       if Assigned(CurrentSpecializeDef) and (ADef=CurrentSpecializeDef.GenericDef) then
                         begin
                           ADef:=CurrentSpecializeDef
                         end
                       else if (ADef=CurrentGenericDef) then
                         begin
                           ADef:=CurrentGenericDef
                         end
                       else if TStoredDef(ADef).Is_Generic and
                           { TODO : check once nested generics are allowed }
                           not
                             (
                               ParseGeneric and
                               (CurrentGenericDef.typ in [recorddef,objectdef]) and
                               (ADef.typ in [recorddef,objectdef]) and
                               (
                                 { if both defs belong to the same generic (e.g. both are
                                   subtypes) then we must allow the usage }
                                 Defs_Belong_To_Same_Generic(ADef,CurrentGenericDef) or
                                 { this is needed to correctly resolve "type Foo=SomeGeneric<T>"
                                   declarations inside a generic }
                                 (
                                   (TTypeNode(lLeftNode).TypeSym<>nil) and
                                   Sym_Is_Owned_By(TTypeNode(lLeftNode).TypeSym,TAbstractRecordDef(CurrentGenericDef).SymTable)
                                 )
                               )
                             )
                           then
                         begin
                           if Assigned(ADef.TypeSym) then
                             begin
                               if TTypeSym(ADef.TypeSym).TypeDef.typ<>undefineddef then
                                 { non-Delphi modes... }
                                 SplitGenericName(ADef.TypeSym.name,lGenericString,lGenericCount)
                               else
                                 lGenericString:=ADef.TypeSym.name;
                               lSym:=ResolveGenericDummySym(lGenericString);
                             end
                           else
                             lSym:=nil;
                           if Assigned(lSym) and
                               not (sp_generic_dummy in lSym.SymOptions) and
                               (lSym.typ=TypeSym) then
                             ADef:=TTypeSym(lSym).TypeDef
                           else
                             begin
                               Message(parser_e_no_generics_as_types);
                               ADef:=GenErrorDef;
                             end;
                         end
                       else if Is_ClassHelper(ADef) then
                         begin
                           Message(parser_e_no_category_as_types);
                           ADef:=GenErrorDef
                         end
                     end;
                 end
               else
                 Message(sym_e_error_in_type_def);
             end;
           lLeftNode.free;
           lLeftNode := nil;
           Block_Type:=lOldBlockType;
        end;


      procedure SetDec;
        begin
          Consume(_SET);
          Consume(_OF);
          ReadAnonType(lTypeDef,true,nil);
          if Assigned(lTypeDef) then
           begin
             case lTypeDef.typ of
               { don't forget that min can be negativ  PM }
               enumdef :
                 if (TEnumDef(lTypeDef).min>=0) and
                    (TEnumDef(lTypeDef).max<=255) then
                  // !! def:=csetdef.create(tt2,tenumdef(tt2.def).min,tenumdef(tt2.def).max),true)
                  ADef:=CSetDef.Create(lTypeDef,TEnumDef(lTypeDef).min,TEnumDef(lTypeDef).max,true)
                 else
                  Message(sym_e_ill_type_decl_set);
               orddef :
                 begin
                   if (TOrdDef(lTypeDef).OrdType=uwidechar) then
                     begin
                     if (m_default_unicodestring in CurrentSettings.ModeSwitches) then
                       begin
                         Message(parser_w_widechar_set_reduced);
                         ADef:=CSetDef.Create(CAnsiCharType,TOrdDef(CAnsiCharType).low.svalue,TOrdDef(CAnsiCharType).high.svalue,true);
                       end
                     else
                       Message(sym_e_ill_type_decl_set);
                     end
                   else if (TOrdDef(lTypeDef).OrdType<>uvoid) and
                      (TOrdDef(lTypeDef).low>=0) then
                     // !! def:=csetdef.create(tt2,torddef(tt2.def).low,torddef(tt2.def).high),true)
                     if TOrdDef(lTypeDef).high>Int64(high(Byte)) then
                       message(sym_e_ill_type_decl_set)
                     else
                       ADef:=CSetDef.Create(lTypeDef,TOrdDef(lTypeDef).low.svalue,TOrdDef(lTypeDef).high.svalue,true)
                   else
                     Message(sym_e_ill_type_decl_set);
                 end;
               { generic parameter? }
               undefineddef:
                 { The element bounds are determined when specializing. }
                 ADef:=CSetDef.Create(lTypeDef,0,255,true);
               else
                 Message(sym_e_ill_type_decl_set);
             end;
           end
          else
           ADef:=GenErrorDef;
        end;


      procedure PointerDec;
        var
          lSym: TSym;
        begin
          Consume(_CARET);
          SingleType(lTypeDef,
              cSingleTypeOptionsInTypeBlock[Block_Type=bt_type]+[stoAllowSpecialization]
            );
          { in case of e.g. var or const sections we need to especially
            check that we don't use a generic dummy symbol }
          if (Block_Type<>bt_type) and
              (lTypeDef.typ=undefineddef) and
              Assigned(lTypeDef.TypeSym) and
              (sp_generic_dummy in lTypeDef.TypeSym.SymOptions) then
            begin
              lSym:=ResolveGenericDummySym(lTypeDef.TypeSym.name);
              if Assigned(lSym) and
                  not (sp_generic_dummy in lSym.SymOptions) and
                  (lSym.typ=TypeSym) then
                lTypeDef:=TTypeSym(lSym).TypeDef
              else
                Message(parser_e_no_generics_as_types);
            end;
          { don't use cpointerdef.getreusable() here, since this is a type
            declaration (-> must create new typedef) }
          ADef:=CPointerDef.Create(lTypeDef);
          if lTypeDef.typ=ForwardDef then
            CurrentModule.CheckForwardDefs.add(ADef);
        end;


      procedure ArrayDec(AIsPacked:Boolean;AGenericDef:TStoredDef;AGenericList:TFPHashObjectList);
        var
          lIsGeneric : Boolean;
          lLowValue,
          lHighValue   : TConstExprInt;
          lIndexDef  : TDef;
          lDef      : TDef;
          lArrayDef    : TArrayDef;

        procedure SetDefDecl(AIndexType:TDef);
          begin
            case AIndexType.typ of
              enumdef :
                begin
                  lLowValue:=TEnumDef(AIndexType).min;
                  lHighValue:=TEnumDef(AIndexType).max;
                  if (m_fpc in CurrentSettings.ModeSwitches) and
                     (TEnumDef(AIndexType).HasJumps) then
                   Message(type_e_array_index_enums_with_assign_not_possible);
                  lIndexDef:=AIndexType;
                end;
              orddef :
                begin
                  if TOrdDef(AIndexType).OrdType in [uchar,
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
                       lLowValue:=TOrdDef(AIndexType).low;
                       lHighValue:=TOrdDef(AIndexType).high;
                       lIndexDef:=AIndexType;
                    end
                  else
                    Message1(parser_e_type_cant_be_used_in_array_index,AIndexType.TypeName);
                end;
              { generic parameter? }
              undefineddef:
                begin
                  lLowValue:=0;
                  lHighValue:=1;
                  lIndexDef:=AIndexType;
                  lIsGeneric:=true;
                end;
              else
                Message(sym_e_error_in_type_def);
            end;
          end;

        var
          lOldCurrentGenericDef,
          lOldCurrentSpecializeDef: TStoredDef;
          lFirst,
          lOldParseGeneric: Boolean;
        begin
           lOldCurrentGenericDef:=CurrentGenericDef;
           lOldCurrentSpecializeDef:=CurrentSpecializeDef;
           lOldParseGeneric:=ParseGeneric;

           CurrentGenericDef:=nil;
           CurrentSpecializeDef:=nil;
           lFirst:=true;
           lArrayDef:=CArrayDef.Create(0,0,S32IntType);
           Consume(_ARRAY);

           { usage of specialized type inside its generic template }
           if Assigned(AGenericDef) then
             CurrentSpecializeDef:=lArrayDef
           { reject declaration of generic class inside generic class }
           else if Assigned(AGenericList) then
             CurrentGenericDef:=lArrayDef;
           SymTableStack.push(lArrayDef.SymTable);
           InsertGenericParameterTypes(lArrayDef,AGenericDef,AGenericList,false);
           { there are two possibilities for the following to be true:
             * the array declaration itself is generic
             * the array is declared inside a generic
             in both cases we need "parse_generic" and "current_genericdef"
             so that e.g. specializations of another generic inside the
             current generic can be used (either inline ones or "type" ones) }
           if lOldParseGeneric then
             include(lArrayDef.DefOptions,df_generic);
           ParseGeneric:=(df_generic in lArrayDef.DefOptions);
           if ParseGeneric and not Assigned(CurrentGenericDef) then
             CurrentGenericDef:=lOldCurrentGenericDef;

           { open array? }
           if TryToConsume(_LECKKLAMMER) then
             begin
                { defaults }
                lIndexDef:=GenErrorDef;
                lIsGeneric:=false;
                { use defaults which don't overflow the compiler }
                lLowValue:=0;
                lHighValue:=0;
                repeat
                  { read the expression and check it, check apart if the
                    declaration is an enum declaration because that needs to
                    be parsed by readtype (PFV) }
                  if CurrentScanner.FToken=_LKLAMMER then
                   begin
                     ReadAnonType(lDef,true,nil);
                     SetDefDecl(lDef);
                   end
                  else
                   begin
                     lNode:=Expr(true);
                     lIsGeneric:=false;
                     if lNode.nodetype=typen then
                       SetDefDecl(lNode.resultdef)
                     else
                       begin
                         if lNode.nodetype=rangen then
                           begin
                             if nf_generic_para in lNode.flags then
                               lIsGeneric:=true;
                             { pure ordconstn expressions can be checked for
                               generics as well, but don't give an error in case
                               of parsing a generic if that isn't yet the case }
                             if (TRangeNode(lNode).left.nodetype=ordconstn) and
                                (TRangeNode(lNode).right.nodetype=ordconstn) then
                               begin
                                 { make both the same type or give an error. This is not
                                   done when both are integer values, because typecasting
                                   between -3200..3200 will result in a signed-unsigned
                                   conflict and give a range check error (PFV) }
                                 if not(Is_Integer(TRangeNode(lNode).left.resultdef) and Is_Integer(TRangeNode(lNode).left.resultdef)) then
                                   InsertTypeConv(TRangeNode(lNode).left,TRangeNode(lNode).right.resultdef);
                                 lLowValue:=TOrdConstNode(TRangeNode(lNode).left).Value;
                                 lHighValue:=TOrdConstNode(TRangeNode(lNode).right).Value;
                                 if lHighValue<lLowValue then
                                  begin
                                    { ignore error if node is generic param }
                                    if not (nf_generic_para in lNode.flags) then
                                      Message(parser_e_array_lower_less_than_upper_bound);
                                    lHighValue:=lLowValue;
                                  end
                                 else if (lLowValue<Int64(low(asizeint))) or
                                         (lHighValue>high(asizeint)) then
                                   begin
                                     Message(parser_e_array_range_out_of_bounds);
                                     lLowValue :=0;
                                     lHighValue:=0;
                                   end;
                                 if Is_Integer(TRangeNode(lNode).left.resultdef) then
                                   Range_To_Type(lLowValue,lHighValue,lIndexDef)
                                 else
                                   lIndexDef:=TRangeNode(lNode).left.resultdef;
                               end
                             else
                               if not ParseGeneric then
                                 Message(type_e_cant_eval_constant_expr)
                               else
                                 { we need a valid range for debug information }
                                 Range_To_Type(lLowValue,lHighValue,lIndexDef);
                           end
                         else
                           Message(sym_e_error_in_type_def)
                       end;
                     lNode.free;
                     lNode := nil;
                   end;

                  { if we are not at the first dimension, add the new array
                    as element of the existing array, otherwise modify the existing array }
                  if not(lFirst) then
                    begin
                      lArrayDef.ElementDef:=CArrayDef.Create(lLowValue.svalue,lHighValue.svalue,lIndexDef);
                      { push new symtable }
                      SymTableStack.pop(lArrayDef.SymTable);
                      lArrayDef:=TArrayDef(lArrayDef.ElementDef);
                      SymTableStack.push(lArrayDef.SymTable);
                      { correctly update the generic information of the new array def }
                      InsertGenericParameterTypes(lArrayDef,AGenericDef,AGenericList,false);
                      if lOldParseGeneric then
                        include(lArrayDef.DefOptions,df_generic);
                    end
                  else
                    begin
                      lArrayDef.LowRange:=lLowValue.svalue;
                      lArrayDef.HighRange:=lHighValue.svalue;
                      lArrayDef.RangeDef:=lIndexDef;
                      ADef:=lArrayDef;
                      lFirst:=false;
                    end;
                  if AIsPacked then
                    include(lArrayDef.ArrayOptions,ado_IsBitPacked);
                  if lIsGeneric then
                    include(lArrayDef.ArrayOptions,ado_IsGeneric);

                  if CurrentScanner.FToken=_COMMA then
                    Consume(_COMMA)
                  else
                    break;
                until false;
                Consume(_RECKKLAMMER);
             end
           else
             begin
                if AIsPacked then
                  Message(parser_e_packed_dynamic_open_array);
                lArrayDef.LowRange:=0;
                lArrayDef.HighRange:=-1;
                lArrayDef.RangeDef:=SizeSIntType;
                include(lArrayDef.ArrayOptions,ado_IsDynamicArray);
                ADef:=lArrayDef;
             end;
           Consume(_OF);
           ReadAnonType(lTypeDef,true,nil);
           { set element type of the last array definition }
           if Assigned(lArrayDef) then
             begin
               SymTableStack.pop(lArrayDef.SymTable);
               lArrayDef.ElementDef:=lTypeDef;
               if AIsPacked and
                  Is_Managed_Type(lTypeDef) then
                 Message(type_e_no_packed_inittable);
             end;
           { restore old state }
           ParseGeneric:=lOldParseGeneric;
           CurrentGenericDef:=lOldCurrentGenericDef;
           CurrentSpecializeDef:=lOldCurrentSpecializeDef;
        end;


        function ProcVarDec(AGenericDef:TStoredDef;AGenericList:TFPHashObjectList;ASym:TSym;ADoRegister:Boolean):TDef;
          var
            lIsFunction:Boolean;
            lProcVarDef:TProcVarDef;
            lOldCurrentGenericDef,
            lOldCurrentSpecializeDef: TStoredDef;
            lOldParseGeneric: Boolean;
            lOldDef : TDef;
          begin
            lOldCurrentGenericDef:=CurrentGenericDef;
            lOldCurrentSpecializeDef:=CurrentSpecializeDef;
            lOldParseGeneric:=ParseGeneric;

            CurrentGenericDef:=nil;
            CurrentSpecializeDef:=nil;
            lOldDef:=nil;

            lIsFunction:=(CurrentScanner.FToken=_FUNCTION);
            if CurrentScanner.FToken in [_FUNCTION,_PROCEDURE] then
              Consume(CurrentScanner.FToken)
            else
              Consume(_FUNCTION);
            lProcVarDef:=CProcVarDef.Create(NormalFunctionLevel,ADoRegister);

            if Assigned(ASym) then
              begin
                lProcVarDef.TypeSym:=ASym;
                lOldDef:=TTypeSym(ASym).TypeDef;
                TTypeSym(ASym).TypeDef:=lProcVarDef;
              end;

            { usage of specialized type inside its generic template }
            if Assigned(AGenericDef) then
              CurrentSpecializeDef:=lProcVarDef
            { reject declaration of generic class inside generic class }
            else if Assigned(AGenericList) then
              CurrentGenericDef:=lProcVarDef;
            SymTableStack.push(lProcVarDef.ParaST);
            InsertGenericParameterTypes(lProcVarDef,AGenericDef,AGenericList,false);
            { there are two possibilities for the following to be true:
              * the procvar declaration itself is generic
              * the procvar is declared inside a generic
              in both cases we need "parse_generic" and "current_genericdef"
              so that e.g. specializations of another generic inside the
              current generic can be used (either inline ones or "type" ones) }
            if lOldParseGeneric then
              include(lProcVarDef.DefOptions,df_generic);
            ParseGeneric:=(df_generic in lProcVarDef.DefOptions);
            if ParseGeneric and not Assigned(CurrentGenericDef) then
              CurrentGenericDef:=lOldCurrentGenericDef;

            if CurrentScanner.FToken=_LKLAMMER then
              ParseParameterDec(lProcVarDef);
            if lIsFunction then
              begin
                Consume(_COLON);
                lProcVarDef.ProcTypeOption:=potype_function;
                lProcVarDef.ReturnDef:=ResultType([stoAllowSpecialization]);
              end
            else
              lProcVarDef.ProcTypeOption:=potype_procedure;
            if TryToConsume(_OF) then
              begin
                Consume(_OBJECT);
                include(lProcVarDef.ProcOptions,po_methodpointer);
              end
            else if (m_nested_procvars in CurrentSettings.ModeSwitches) and
                    TryToConsume(_IS) then
              begin
                Consume(_NESTED);
                lProcVarDef.ParaST.SymTableLevel:=NormalFunctionLevel+1;
                lProcVarDef.Check_Mark_As_Nested;
              end;
            SymTableStack.pop(lProcVarDef.ParaST);
            { possible proc directives }
            if AParseProcVarDir then
              begin
                if CheckProcDirective(true) then
                  ParseProcTypeDirectives(lProcVarDef);
                { Add implicit hidden parameters and function result }
                Handle_Calling_Convention(lProcVarDef,cHCCDefaultActionsIntf);
              end;
            { restore old state }
            ParseGeneric:=lOldParseGeneric;
            CurrentGenericDef:=lOldCurrentGenericDef;
            CurrentSpecializeDef:=lOldCurrentSpecializeDef;

            if Assigned(ASym) then
              begin
                lProcVarDef.TypeSym:=nil;
                TTypeSym(ASym).TypeDef:=lOldDef;
              end;

            Result:=lProcVarDef;
          end;

      var
        lEnumExprNode  : TNode;
        lDef : TDef;
        lEnumDupMsg, lFirst, lIsSpecialize : Boolean;
        lOldLocalSwitches : TLocalSwitches;
        lBitPacking: Boolean;
        lSymTableItem: PSymTableStackItem;
        lSym: TSym;
        lSymTable: TSymTable;
      begin
         ADef:=nil;
         lExplicitEnumValue:=0;
         lEnumValue:=0;
         if Assigned(ANewSym) then
           lName:=ANewSym.RealName
         else
           lName:='';
         { type a = type ..,; syntax is allowed only with type syms and apparently helpers, see below }
         if AHadTypeToken and
             (
               (CurrentScanner.FToken<>_ID) or
               (
                 (m_function_references in CurrentSettings.ModeSwitches) and
                 (CurrentScanner.FIDToken=_REFERENCE)
               )
             ) and
             (CurrentScanner.FToken<>_STRING) and (CurrentScanner.FToken<>_FILE) then
           Consume(_ID);
         case CurrentScanner.FToken of
            _STRING,_FILE:
              begin
                if AHadTypeToken then
                  SingleType(ADef,[])
                else
                  SingleType(ADef,[stoAllowTypeDef]);
              end;
           _LKLAMMER:
              begin
                Consume(_LKLAMMER);
                lFirst:=true;
                { allow negativ value_str }
                lEnumValue:=Int64(-1);
                lEnumDupMsg:=false;
                { check that we are not adding an enum from specialization
                  we can't just use current_specializedef because of inner types
                  like specialize array of record }
                lIsSpecialize:=false;
                lSymTableItem:=SymTableStack.stack;
                while Assigned(lSymTableItem) do
                  begin
                    { check records, classes and arrays because they can be specialized }
                    if lSymTableItem^.SymTable.SymTableType in [recordsymtable,ObjectSymtable,arraysymtable] then
                      begin
                        lIsSpecialize:=lIsSpecialize or (df_specialization in TStoredDef(lSymTableItem^.SymTable.DefOwner).DefOptions);
                        lSymTableItem:=lSymTableItem^.next;
                      end
                    else
                      break;
                  end;
                if not lIsSpecialize then
                  lEnumDef:=CEnumDef.Create
                else
                  lEnumDef:=nil;
                repeat
                  { if it is a specialization then search the first enum member
                    and get the member owner instead of just created enumdef }
                  if not Assigned(lEnumDef) then
                    begin
                      if not SearchSym(CurrentScanner.FPattern,lSym,lSymTable) then
                        InternalError(202504121)
                      else if lSym.typ=enumsym then
                        lEnumDef:=TEnumSym(lSym).definition
                      else
                        InternalError(201101021);
                    end;
                  lMemberName:=CurrentScanner.FOrgPattern;
                  lDefPos:=CurrentTokenPos;
                  Consume(_ID);
                  { allow assigning specific numbers }
                  if
                      { in fpc mode also allow := to be compatible
                        with previous 1.0.x versions }
                      ((m_fpc in CurrentSettings.ModeSwitches) and
                       TryToConsume(_ASSIGNMENT)) or
                      TryToConsume(_EQ) then
                    begin
                       lOldLocalSwitches:=CurrentSettings.LocalSwitches;
                       include(CurrentSettings.LocalSwitches,cs_allow_enum_calc);
                       lEnumExprNode:=CompExpr([efAcceptEqual]);
                       CurrentSettings.LocalSwitches:=lOldLocalSwitches;
                       if (lEnumExprNode.nodetype=ordconstn) then
                        begin
                          { we expect an integer or an enum of the
                            same type }
                          if Is_Integer(lEnumExprNode.resultdef) or
                             Is_Char(lEnumExprNode.resultdef) or
                             Equal_Defs(lEnumExprNode.resultdef,lEnumDef) then
                           lExplicitEnumValue:=TOrdConstNode(lEnumExprNode).Value
                          else
                           IncompatibleTypes(lEnumExprNode.resultdef,S32IntType);
                        end
                       else
                        Message(parser_e_illegal_expression);
                       lEnumExprNode.free;
                       lEnumExprNode := nil;
                       { please leave that a note, allows type save }
                       { declarations in the win32 units ! }
                       if (not lFirst) and (lExplicitEnumValue<=lEnumValue) and (not lEnumDupMsg) then
                        begin
                          Message(parser_n_duplicate_enum);
                          lEnumDupMsg:=true;
                        end;
                       lEnumValue:=lExplicitEnumValue;
                    end
                  else
                    inc(lEnumValue.svalue);
                  lFirst:=false;
                  { don't generate enum members if this is a specialization because aktenumdef is copied from the generic type }
                  if not lIsSpecialize then
                    begin
                      lSavedPos:=CurrentTokenPos;
                      CurrentTokenPos:=lDefPos;
                      if (lEnumValue.svalue<low(LongInt)) or (lEnumValue.svalue>high(LongInt)) then
                        if m_delphi in CurrentSettings.ModeSwitches then
                          Message(parser_w_enumeration_out_of_range)
                        else
                          Message(parser_e_enumeration_out_of_range);
                      TEnumSymTable(lEnumDef.SymTable).InsertSym(CEnumSym.Create(lMemberName,lEnumDef,LongInt(lEnumValue.svalue)));
                      if not (cs_scopedenums in CurrentSettings.LocalSwitches) or
                          { also provide the global symbol for anonymous enums }
                          not Assigned(ANewSym) then
                        TStoredSymTable(lEnumDef.owner).InsertSym(CEnumSym.Create(lMemberName,lEnumDef,LongInt(lEnumValue.svalue)));
                      CurrentTokenPos:=lSavedPos;
                    end;
                until not TryToConsume(_COMMA);
                ADef:=lEnumDef;
                Consume(_RKLAMMER);
              end;
            _ARRAY:
              ArrayDec(false,AGenericDef,AGenericList);
            _SET:
              SetDec;
            _CARET:
              PointerDec;
            _RECORD:
              begin
                Consume(CurrentScanner.FToken);
                if (CurrentScanner.FIDToken=_HELPER) and (m_advanced_records in CurrentSettings.ModeSwitches) then
                  begin
                    Consume(_HELPER);
                    ADef:=ObjectDec(odt_helper,lName,ANewSym,AGenericDef,AGenericList,nil,ht_record);
                  end
                else
                  ADef:=RecordDec(lName,ANewSym,AGenericDef,AGenericList);
              end;
            _PACKED,
            _BITPACKED:
              begin
                lBitPacking :=
                  (cs_bitpacking in CurrentSettings.LocalSwitches) or
                  (CurrentScanner.FToken = _BITPACKED);
                Consume(CurrentScanner.FToken);
                if CurrentScanner.FToken=_ARRAY then
                  ArrayDec(lBitPacking,AGenericDef,AGenericList)
                else if CurrentScanner.FToken=_SET then
                  SetDec
                else if CurrentScanner.FToken=_FILE then
                  SingleType(ADef,[stoAllowTypeDef])
                else
                  begin
                    lOldPackRecords:=CurrentSettings.PackRecords;
                    if (not lBitPacking) or
                       (CurrentScanner.FToken in [_CLASS,_OBJECT]) then
                      CurrentSettings.PackRecords:=1
                    else
                      CurrentSettings.PackRecords:=BitAlignment;
                    case CurrentScanner.FToken of
                      _CLASS :
                        begin
                          Consume(_CLASS);
                          ADef:=ObjectDec(odt_class,lName,ANewSym,AGenericDef,AGenericList,nil,ht_none);
                        end;
                      _OBJECT :
                        begin
                          Consume(_OBJECT);
                          ADef:=ObjectDec(odt_object,lName,ANewSym,AGenericDef,AGenericList,nil,ht_none);
                        end;
                      else begin
                        Consume(_RECORD);
                        ADef:=RecordDec(lName,ANewSym,AGenericDef,AGenericList);
                      end;
                    end;
                    CurrentSettings.PackRecords:=lOldPackRecords;
                  end;
              end;
            _DISPINTERFACE :
              begin
                { need extra check here since interface is a keyword
                  in all pascal modes }
                if not(m_class in CurrentSettings.ModeSwitches) then
                  Message(parser_f_need_objfpc_or_delphi_mode);
                Consume(CurrentScanner.FToken);
                ADef:=ObjectDec(odt_dispinterface,lName,ANewSym,AGenericDef,AGenericList,nil,ht_none);
              end;
            _CLASS :
              begin
                Consume(CurrentScanner.FToken);
                { Delphi only allows class of in type blocks }
                if (CurrentScanner.FToken=_OF) and
                   (
                    not(m_delphi in CurrentSettings.ModeSwitches) or
                    (Block_Type=bt_type)
                   ) then
                  begin
                    Consume(_OF);
                    SingleType(lDef,cSingleTypeOptionsInTypeBlock[Block_Type=bt_type]);
                    if Is_Class(lDef) or
                       Is_ObjCClass(lDef) then
                      ADef:=CClassRefDef.Create(lDef)
                    else
                      if lDef.typ=ForwardDef then
                        begin
                          ADef:=CClassRefDef.Create(lDef);
                          CurrentModule.CheckForwardDefs.add(ADef);
                        end
                    else
                      Message1(type_e_class_or_objcclass_type_expected,lDef.TypeName);
                  end
                else
                if (CurrentScanner.FIDToken=_HELPER) then
                  begin
                    Consume(_HELPER);
                    ADef:=ObjectDec(odt_helper,lName,ANewSym,AGenericDef,AGenericList,nil,ht_class);
                  end
                else
                  ADef:=ObjectDec(DefaultClassType,lName,ANewSym,AGenericDef,AGenericList,nil,ht_none);
              end;
            _CPPCLASS :
              begin
                Consume(CurrentScanner.FToken);
                ADef:=ObjectDec(odt_cppclass,lName,ANewSym,AGenericDef,AGenericList,nil,ht_none);
              end;
            _OBJCCLASS :
              begin
                if not(m_objectivec1 in CurrentSettings.ModeSwitches) then
                  Message(parser_f_need_objc);

                Consume(CurrentScanner.FToken);
                ADef:=ObjectDec(odt_objcclass,lName,ANewSym,AGenericDef,AGenericList,nil,ht_none);
              end;
            _INTERFACE :
              begin
                { need extra check here since interface is a keyword
                  in all pascal modes }
                if not(m_class in CurrentSettings.ModeSwitches) then
                  Message(parser_f_need_objfpc_or_delphi_mode);
                Consume(CurrentScanner.FToken);
                case CurrentSettings.InterfaceType of
                  it_interfacecom:
                    ADef:=ObjectDec(odt_interfacecom,lName,ANewSym,AGenericDef,AGenericList,nil,ht_none);
                  it_interfacecorba:
                    ADef:=ObjectDec(odt_interfacecorba,lName,ANewSym,AGenericDef,AGenericList,nil,ht_none);
                end;
              end;
            _OBJCPROTOCOL :
               begin
                if not(m_objectivec1 in CurrentSettings.ModeSwitches) then
                  Message(parser_f_need_objc);

                Consume(CurrentScanner.FToken);
                ADef:=ObjectDec(odt_objcprotocol,lName,ANewSym,AGenericDef,AGenericList,nil,ht_none);
               end;
            _OBJCCATEGORY :
               begin
                if not(m_objectivec1 in CurrentSettings.ModeSwitches) then
                  Message(parser_f_need_objc);

                Consume(CurrentScanner.FToken);
                ADef:=ObjectDec(odt_objccategory,lName,ANewSym,AGenericDef,AGenericList,nil,ht_none);
               end;
            _OBJECT :
              begin
                Consume(CurrentScanner.FToken);
                ADef:=ObjectDec(odt_object,lName,ANewSym,AGenericDef,AGenericList,nil,ht_none);
              end;
            _PROCEDURE,
            _FUNCTION:
              begin
                ADef:=ProcVarDec(AGenericDef,AGenericList,nil,true);
              end;
            _ID:
              begin
                case CurrentScanner.FIDToken of
                  _HELPER:
                    begin
                      if AHadTypeToken and
                         (m_type_helpers in CurrentSettings.ModeSwitches) then
                        begin
                          { reset hadtypetoken, so that calling code knows that it should not be handled
                            as a "unique" type }
                          AHadTypeToken:=false;
                          Consume(_HELPER);
                          ADef:=ObjectDec(odt_helper,lName,ANewSym,AGenericDef,AGenericList,nil,ht_type);
                        end
                      else
                        ExprType
                    end;
                  _REFERENCE:
                    begin
                      if CurrentSettings.ModeSwitches*[m_blocks,m_function_references]<>[] then
                        begin
                          Consume(_REFERENCE);
                          Consume(_TO);
                          { don't register the def as a non-cblock function
                            reference will be converted to an interface }
                          ADef:=ProcVarDec(AGenericDef,AGenericList,ANewSym,false);
                          { could be errordef in case of a syntax error }
                          if Assigned(ADef) and
                             (ADef.typ=procvardef) then
                            begin
                              include(TProcVarDef(ADef).ProcOptions,po_is_function_ref);
                            end;
                        end
                      else
                        ExprType;
                    end;
                  else
                    ExprType;
                end;
              end
            else
              if (CurrentScanner.FToken=_KLAMMERAFFE) and (([m_iso]*CurrentSettings.ModeSwitches)<>[]) then
                begin
                  Consume(_KLAMMERAFFE);
                  SingleType(lTypeDef,cSingleTypeOptionsInTypeBlock[Block_Type=bt_type]);
                  ADef:=CPointerDef.Create(lTypeDef);
                  if lTypeDef.typ=ForwardDef then
                    CurrentModule.CheckForwardDefs.add(ADef);
                end
              else
                ExprType;
         end;

         if ADef=nil then
          ADef:=GenErrorDef;
      end;


    procedure ReadAnonType(var ADef : TDef;AParseProcVarDir:Boolean;AGenericDef:TStoredDef);
      var
        lHadTypeToken : Boolean;
      begin
        lHadTypeToken:=false;
        ReadNamedType(ADef,nil,AGenericDef,nil,AParseProcVarDir,lHadTypeToken);
      end;




end.
