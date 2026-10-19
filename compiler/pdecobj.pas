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
    function ObjectDec(AObjectType:TObjectTyp;const AName:TIDString;AObjSym:TSym;AGenericDef:TStoredDef;AGenericList:TFPHashObjectList;AForwardDef : TObjectDef;AHelperType:THelperType) : TObjectDef;

    { parses a (class) method declaration }
    function MethodDec(AStruct: TAbstractRecordDef; AIsClassDef: Boolean;AHadGeneric:Boolean): TProcDef;

    function ClassConstructorHead(AStruct: TAbstractRecordDef):TProcDef;
    function ClassDestructorHead(AStruct: TAbstractRecordDef):TProcDef;
    function ConstructorHead:TProcDef;
    function DestructorHead:TProcDef;
    procedure StructPropertyDec(AIsClassProperty:Boolean;var ARTTIAttrsDef: TRTTIAttributeList);

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
      CurrentObjectDef : TObjectDef absolute CurrentStructDef;


    procedure ConstrDestrFinishHead(AProcDef: TProcDef; const AStruct: TAbstractRecordDef);
      begin
        case AStruct.typ of
          recorddef:
            begin
              ParseRecordProcDirectives(AProcDef);
            end;
          objectdef:
            begin
              ParseObjectProcDirectives(AProcDef);
            end
          else
            InternalError(2011040502);
        end;
        // We can't add hidden params here because record is not yet defined
        // and therefore record size which has influence on parameter passing rules may change too
        // look at record_dec to see where calling conventions are applied (issue #0021044).
        // The same goes for objects/classes due to the calling convention that may only be set
        // later (mantis #35233).
        Handle_Calling_Convention(AProcDef,cHCCDefaultActionsIntfStruct);

        { add definition to procsym }
        Proc_Add_Definition(AProcDef);

        { add procdef options to objectdef options }
        if (po_virtualmethod in AProcDef.ProcOptions) then
          include(AStruct.ObjectOptions,oo_has_virtual);

        MaybeParseHintDirectives(AProcDef);
      end;


    function ClassConstructorHead(AStruct: TAbstractRecordDef):TProcDef;
      var
        lProcDef : TProcDef;
      begin
        Result:=nil;
        Consume(_CONSTRUCTOR);
        { must be at same level as in implementation }
        ParseProcHead(CurrentStructDef,potype_class_constructor,[],nil,nil,lProcDef);
        if not Assigned(lProcDef) then
          begin
            Consume(_SEMICOLON);
            exit;
          end;
        lProcDef.CalcParas;
        if (lProcDef.MaxParaCount>0) then
          Message(parser_e_no_paras_for_class_constructor);
        Consume(_SEMICOLON);
        include(AStruct.ObjectOptions,oo_has_class_constructor);
        include(CurrentModule.ModuleFlags,mf_classinits);
        { no return value }
        lProcDef.ReturnDef:=VoidType;
        ConstrDestrFinishHead(lProcDef,AStruct);
        Result:=lProcDef;
      end;

    function ConstructorHead:TProcDef;
      var
        lProcDef : TProcDef;
      begin
        Result:=nil;
        Consume(_CONSTRUCTOR);
        { must be at same level as in implementation }
        ParseProcHead(CurrentStructDef,potype_constructor,[],nil,nil,lProcDef);
        if not Assigned(lProcDef) then
          begin
            Consume(_SEMICOLON);
            exit;
          end;
        Consume(_SEMICOLON);
        include(CurrentStructDef.ObjectOptions,oo_has_constructor);
        { Set return type, class and record constructors return the
          created instance, helper types return the extended type,
          object constructors return boolean }
        if Is_Class(lProcDef.struct) or
           Is_Record(lProcDef.struct) then
          lProcDef.ReturnDef:=lProcDef.struct
        else
          if Is_ObjectPascal_Helper(lProcDef.struct) then
            lProcDef.ReturnDef:=TObjectDef(lProcDef.struct).ExtendedDef
          else
{$ifdef CPU64bitaddr}
            lProcDef.ReturnDef:=Bool64Type;
{$else CPU64bitaddr}
            lProcDef.ReturnDef:=Bool32Type;
{$endif CPU64bitaddr}
        ConstrDestrFinishHead(lProcDef,lProcDef.struct);
        Result:=lProcDef;
      end;


    procedure StructPropertyDec(AIsClassProperty:Boolean;var ARTTIAttrsDef: TRTTIAttributeList);
      var
        lProperty : TPropertySym;
        lDeprecatedMsg: PShortString;
        lSymOptions: TSymOptions;
      begin
        { check for a class, record or helper }
        if not((Is_Class_Or_Interface_Or_DispInterface(CurrentStructDef) or Is_Record(CurrentStructDef) or
                Is_ObjectPascal_Helper(CurrentStructDef)) or
               Is_Object(CurrentStructDef)) then
          Message(parser_e_syntax_error);
        Consume(_PROPERTY);
        lProperty:=ReadPropertyDec(AIsClassProperty,CurrentStructDef);
        Consume(_SEMICOLON);
        if TryToConsume(_DEFAULT) then
          begin
            if oo_has_default_property in CurrentStructDef.ObjectOptions then
              message(parser_e_only_one_default_property);
            include(CurrentStructDef.ObjectOptions,oo_has_default_property);
            include(lProperty.PropOptions,ppo_defaultproperty);
            if not(ppo_hasparameters in lProperty.PropOptions) then
              message(parser_e_property_need_paras);
            if (CurrentScanner.FToken=_COLON) then
              begin
                Message(parser_e_field_not_allowed_here);
                ConsumeAllUntil(_SEMICOLON);
              end;
            Consume(_SEMICOLON);
          end;
        { parse possible enumerator modifier }
        if TryToConsume(_ENUMERATOR) then
          begin
            if (CurrentScanner.FToken = _ID) then
            begin
              if CurrentScanner.FPattern='CURRENT' then
              begin
                if oo_has_enumerator_current in CurrentStructDef.ObjectOptions then
                  message(parser_e_only_one_enumerator_current);
                if not lProperty.PropAccessList[palt_read].empty then
                begin
                  include(CurrentStructDef.ObjectOptions,oo_has_enumerator_current);
                  include(lProperty.PropOptions,ppo_enumerator_current);
                end
                else
                  Message(parser_e_enumerator_current_is_not_valid) // property has no reader
              end
              else
                Message1(parser_e_invalid_enumerator_identifier, CurrentScanner.FPattern);
              Consume(CurrentScanner.FToken);
            end
            else
              Message(parser_e_enumerator_identifier_required);
            Consume(_SEMICOLON);
          end;
        { in case of a previous error, p might not be assigned }
        if Assigned(lProperty) then
          begin
            TRTTIAttributeList.bind(ARTTIAttrsDef,lProperty.RTTIAttributeList);

            { hint directives, these can be separated by semicolons here,
              that needs to be handled here with a loop (PFV) }
            while TryConsumeHintDirective(lProperty.SymOptions,lProperty.DeprecatedMsg) do
              Consume(_SEMICOLON);
          end
        else
          begin
            { recover from error so we can continue to parse }

            { hint directives, these can be separated by semicolons here,
              that needs to be handled here with a loop (PFV) }
            while TryConsumeHintDirective(lSymOptions,lDeprecatedMsg) do
              Consume(_SEMICOLON);
          end;
      end;


    function ClassDestructorHead(AStruct: TAbstractRecordDef):TProcDef;
      var
        lProcDef : TProcDef;
      begin
        Result:=nil;
        Consume(_DESTRUCTOR);
        ParseProcHead(CurrentStructDef,potype_class_destructor,[],nil,nil,lProcDef);
        if not Assigned(lProcDef) then
          begin
            Consume(_SEMICOLON);
            exit;
          end;
        lProcDef.CalcParas;
        if (lProcDef.MaxParaCount>0) then
          Message(parser_e_no_paras_for_class_destructor);
        Consume(_SEMICOLON);
        include(AStruct.ObjectOptions,oo_has_class_destructor);
        include(CurrentModule.ModuleFlags,mf_classinits);
        { no return value }
        lProcDef.ReturnDef:=VoidType;
        ConstrDestrFinishHead(lProcDef,AStruct);
        Result:=lProcDef;
      end;

    function DestructorHead:TProcDef;
      var
        lProcDef : TProcDef;
      begin
        Result:=nil;
        Consume(_DESTRUCTOR);
        ParseProcHead(CurrentStructDef,potype_destructor,[],nil,nil,lProcDef);
        if not Assigned(lProcDef) then
          begin
            Consume(_SEMICOLON);
            exit;
          end;
        lProcDef.CalcParas;
        if not(lProcDef.MaxParaCount=0) and
           (m_fpc in CurrentSettings.ModeSwitches) then
          Message(parser_e_no_paras_for_destructor);
        Consume(_SEMICOLON);
        include(CurrentStructDef.ObjectOptions,oo_has_destructor);
        include(CurrentStructDef.ObjectOptions,oo_has_new_destructor);
        { no return value }
        lProcDef.ReturnDef:=VoidType;
        ConstrDestrFinishHead(lProcDef,lProcDef.struct);
        Result:=lProcDef;
      end;


    procedure SetInterfaceMethodOptions;
      var
        lIndex   : LongInt;
        lDef : TDef;
      begin
        include(CurrentStructDef.ObjectOptions,oo_has_virtual);
        for lIndex:=0 to CurrentStructDef.SymTable.DefList.count-1 do
          begin
            lDef:=TDef(CurrentStructDef.SymTable.DefList[lIndex]);
            if Assigned(lDef) and
               (lDef.typ=procdef) then
              begin
                include(TProcDef(lDef).ProcOptions,po_virtualmethod);
                TProcDef(lDef).ForwardDef:=false;
              end;
          end;
      end;


    procedure SetObjCClassMethodOptions;
      var
        lIndex   : LongInt;
        lDef : TDef;
      begin
        for lIndex:=0 to CurrentStructDef.SymTable.DefList.count-1 do
          begin
            lDef:=TDef(CurrentStructDef.SymTable.DefList[lIndex]);
            if Assigned(lDef) and
               (lDef.typ=procdef) then
              begin
                include(TProcDef(lDef).ProcOptions,po_virtualmethod);
              end;
          end;
      end;


    procedure HandleImplementedInterface(AInterfaceDef : TObjectDef);
      begin
        if not Is_Interface(AInterfaceDef) then
          begin
             Message1(type_e_interface_type_expected,AInterfaceDef.TypeName);
             exit;
          end;
        if ([oo_is_forward,oo_is_formal] * AInterfaceDef.ObjectOptions <> []) then
          begin
             Message1(parser_e_forward_intf_declaration_must_be_resolved,AInterfaceDef.ObjRealName^);
             exit;
          end;
        if Find_Implemented_Interface(CurrentObjectDef,AInterfaceDef)<>nil then
          Message1(sym_e_duplicate_id,AInterfaceDef.ObjName^)
        else
          CurrentObjectDef.Register_Implemented_Interface(AInterfaceDef,true);
      end;


    procedure HandleImplementedProtocol(AProtocolDef : TObjectDef);
      begin
        AProtocolDef:=Find_Real_Class_Definition(AProtocolDef,false);
        case CurrentObjectDef.ObjectType of
          odt_objcclass,
          odt_objccategory,
          odt_objcprotocol:
            if not Is_ObjCProtocol(AProtocolDef) then
              begin
                 Message1(type_e_protocol_type_expected,AProtocolDef.TypeName);
                 exit;
              end;
          else
            InternalError(2011010807);
        end;
        if ([oo_is_forward,oo_is_formal] * AProtocolDef.ObjectOptions <> []) then
          begin
             Message1(parser_e_forward_intf_declaration_must_be_resolved,AProtocolDef.ObjRealName^);
             exit;
          end;
        if Find_Implemented_Interface(CurrentObjectDef,AProtocolDef)<>nil then
          Message1(sym_e_duplicate_id,AProtocolDef.ObjName^)
        else
          CurrentObjectDef.Register_Implemented_Interface(AProtocolDef,false);
      end;


    procedure ReadImplementedInterfacesAndProtocols(AIsInterface: Boolean);
      var
        lDef : TDef;
      begin
        while TryToConsume(_COMMA) do
          begin
             { use single_type instead of id_type for specialize support }
             SingleType(lDef,[stoAllowSpecialization,stoParseClassParent]);
             if (lDef.typ<>objectdef) then
               begin
                  if AIsInterface then
                    Message1(type_e_interface_type_expected,lDef.TypeName)
                  else
                    Message1(type_e_protocol_type_expected,lDef.TypeName);
                  continue;
               end;
             if AIsInterface then
               HandleImplementedInterface(TObjectDef(lDef))
             else
               HandleImplementedProtocol(TObjectDef(lDef));
          end;
      end;


    procedure ReadInterfaceIID;
      var
        lNode : TNode;
        lValid : Boolean;
      begin
        lNode:=CompExpr([efAcceptEqual]);
        if lNode.nodetype=stringconstn then
          begin
            StringDispose(CurrentObjectDef.IIDStr);
            CurrentObjectDef.IIDStr:=StringDup(TStringConstNode(lNode).AsRawByteString);
            lValid:=String2GUID(CurrentObjectDef.IIDStr^,CurrentObjectDef.IIDGUID^);
            if (CurrentObjectDef.ObjectType in [odt_interfacecom,odt_dispinterface]) and
               not lValid then
              Message(parser_e_improper_guid_syntax);
            include(CurrentStructDef.ObjectOptions,oo_has_valid_guid);
          end
        else
          Message(parser_e_illegal_expression);
        lNode.free;
        lNode := nil;
      end;

    procedure GetCPPClassExternalStatus(AObjectDef: TObjectDef);
      var
        lLibraryName: String;
      begin
        { C++ classes can be external -> all methods inside are external
         (defined at the class level instead of per method, so that you cannot
         define some methods as external and some not)
        }
        if TryToConsume(_EXTERNAL) then
          begin
            lLibraryName:='';
            if CurrentScanner.FToken in [_CSTRING,_CWSTRING,_CCHAR,_CWCHAR] then
              begin
                { Always add library prefix and suffix to create an uniform name }
                lLibraryName:=GetStringConst;
                if ExtractFileExt(lLibraryName)='' then
                  lLibraryName:=ChangeFileExt(lLibraryName,TargetInfo.sharedlibext);
                if Copy(lLibraryName,1,length(TargetInfo.sharedlibprefix))<>TargetInfo.sharedlibprefix then
                  lLibraryName:=TargetInfo.sharedlibprefix+lLibraryName;
              end;
            if lLibraryName<>'' then
              begin
                StringDispose(AObjectDef.ImportLib);
                AObjectDef.ImportLib:=StringDup(lLibraryName);
              end;
            { check if we shall use another name for the class }
            if TryToConsume(_NAME) then
              AObjectDef.ObjExtName:=StringDup(GetStringConst)
            else
              AObjectDef.ObjExtName:=StringDup(AObjectDef.ObjRealName^);
            include(AObjectDef.ObjectOptions,oo_is_external);
          end
        else
          begin
            AObjectDef.ObjExtName:=StringDup(AObjectDef.ObjRealName^);
          end;
      end;


    procedure GetObjCClassOrProtocolExternalStatus(AObjectDef: TObjectDef);
      begin
        { Objective-C classes can be external -> all messages inside are
          external (defined at the class level instead of per method, so
          that you cannot define some methods as external and some not)
        }
        if TryToConsume(_EXTERNAL) then
          begin
            if TryToConsume(_NAME) then
              AObjectDef.ObjExtName:=StringDup(GetStringConst)
            else
              { the external name doesn't matter for formally declared
                classes, and allowing to specify one would mean that we would
                have to check it for consistency with the actual definition
                later on }
              AObjectDef.ObjExtName:=StringDup(AObjectDef.ObjRealName^);
            include(AObjectDef.ObjectOptions,oo_is_external);
          end
        else
          AObjectDef.ObjExtName:=StringDup(AObjectDef.ObjRealName^);
      end;


    procedure ParseObjectOptions;
      begin
        case CurrentObjectDef.ObjectType of
          odt_object,odt_class:
            begin
              while true do
                begin
                  if TryToConsume(_ABSTRACT) then
                    include(CurrentStructDef.ObjectOptions,oo_is_abstract)
                  else
                  if TryToConsume(_SEALED) then
                    include(CurrentStructDef.ObjectOptions,oo_is_sealed)
                  else break;
                end;
              { don't use <=, because there's a bug in the 2.6.0 SPARC code
                generator regarding handling this expression }
              if ([oo_is_abstract, oo_is_sealed] * CurrentStructDef.ObjectOptions) = [oo_is_abstract, oo_is_sealed] then
                Message(parser_e_abstract_and_sealed_conflict);
            end;
          odt_cppclass:
            GetCPPClassExternalStatus(CurrentObjectDef);
          odt_objcclass,odt_objcprotocol,odt_objccategory:
            GetObjCClassOrProtocolExternalStatus(CurrentObjectDef);
          odt_helper: ; // nothing
          else
            ;
        end;
      end;

    procedure ParseParentClasses;
      var
        lInterfaceParent,
        lParent : TObjectDef;
        lDef : TDef;
        lHasParentDefined : Boolean;
      begin
        lParent:=nil;
        lInterfaceParent:=nil;
        lHasParentDefined:=false;

        { reads the parent class }
        if (CurrentScanner.FToken=_LKLAMMER) or
           Is_ObjCCategory(CurrentStructDef) then
          begin
            Consume(_LKLAMMER);
            { use single_type instead of id_type for specialize support }
            SingleType(lDef,[stoAllowSpecialization, stoParseClassParent]);
            if (not Assigned(lDef)) or
               (lDef.typ<>objectdef) then
              begin
                if Assigned(lDef) then
                  Message1(type_e_class_type_expected,lDef.TypeName)
                else if Is_ObjCCategory(CurrentStructDef) then
                  { a category must specify the class to extend }
                  Message(type_e_objcclass_type_expected);
              end
            else
              begin
                lParent:=TObjectDef(lDef);
                { a mix of class, interfaces, objects and cppclasses
                  isn't allowed }
                case CurrentObjectDef.ObjectType of
                   odt_class:
                     if (lParent.ObjectType<>CurrentObjectDef.ObjectType) then
                       begin
                          if (Is_Interface(lParent) and
                              Is_Class(CurrentObjectDef)) then
                            begin
                               { we insert the interface after the child
                                 is set, see below
                               }
                               lInterfaceParent:=lParent;
                               lParent:=Class_TObject;
                            end
                          else
                            Message(parser_e_mix_of_classes_and_objects);
                       end
                     else
                       if oo_is_sealed in lParent.ObjectOptions then
                         Message1(parser_e_sealed_descendant,lParent.TypeSymbolPrettyName)
                       else
                         lParent:=Find_Real_Class_Definition(lParent,true);
                   odt_interfacecorba,
                   odt_interfacecom:
                     begin
                       if not(Is_Interface(lParent)) then
                         Message(parser_e_mix_of_classes_and_objects);
                       CurrentObjectDef.ObjectType:=lParent.ObjectType;
                     end;
                   odt_cppclass:
                     if not(Is_CPPClass(lParent)) then
                       Message(parser_e_mix_of_classes_and_objects);
                   odt_objcclass:
                     if not(Is_ObjCClass(lParent) or
                        Is_ObjCCategory(lParent)) then
                       begin
                         if Is_ObjCProtocol(lParent) then
                           begin
                             if not(oo_is_classhelper in CurrentStructDef.ObjectOptions) then
                               begin
                                 lInterfaceParent:=lParent;
                                 lParent:=nil;
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
                       lParent:=Find_Real_Class_Definition(lParent,true);
                   odt_objcprotocol:
                     begin
                       if not(Is_ObjCProtocol(lParent)) then
                         Message(parser_e_mix_of_classes_and_objects);
                       lInterfaceParent:=lParent;
                       lParent:=nil;
                     end;

                   odt_object:
                     if not(Is_Object(lParent)) then
                       Message(parser_e_mix_of_classes_and_objects)
                     else
                       if oo_is_sealed in lParent.ObjectOptions then
                         Message1(parser_e_sealed_descendant,lParent.TypeName);
                   odt_dispinterface:
                     Message(parser_e_dispinterface_cant_have_parent);
                   odt_helper:
                     if not Is_ObjectPascal_Helper(lParent) then
                       begin
                         Message(type_e_helper_type_expected);
                         lParent:=nil;
                       end;
                   else
                     ;
                end;
              end;
            lHasParentDefined:=true;
          end;

        { if no parent class, then a class get tobject as parent }
        if not Assigned(lParent) then
          begin
            case CurrentObjectDef.ObjectType of
              odt_class:
                if CurrentObjectDef<>Class_TObject then
                  lParent:=Class_TObject;
              odt_interfacecom:
                if CurrentObjectDef<>Interface_IUnknown then
                  lParent:=Interface_IUnknown;
              odt_dispinterface:
                lParent:=Interface_IDispatch;
              odt_objcclass:
                CGMessage(parser_h_no_objc_parent);

              else
                ;
            end;
          end;

        if Assigned(lParent) then
          begin
            { Forbid not completly defined objects to be used as parents. This will
              also prevent circular loops of classes, because we set the forward flag
              at the start of the new definition and will reset it below after the
              parent has been set }
            if (oo_is_forward in lParent.ObjectOptions) then
              Message1(parser_e_forward_declaration_must_be_resolved,lParent.ObjRealName^)
            else if not(oo_is_formal in lParent.ObjectOptions) then
              CurrentObjectDef.Set_Parent(lParent)
            else
              Message1(sym_e_formal_class_not_resolved,lParent.ObjRealName^);
          end;

        if lHasParentDefined then
          begin
            if CurrentObjectDef.ObjectType in [odt_class,odt_objcclass,odt_objcprotocol] then
              begin
                if Assigned(lInterfaceParent) then
                  if CurrentObjectDef.ObjectType=odt_class then
                    HandleImplementedInterface(lInterfaceParent)
                  else
                    HandleImplementedProtocol(lInterfaceParent);
                ReadImplementedInterfacesAndProtocols(CurrentObjectDef.ObjectType=odt_class);
              end;
            Consume(_RKLAMMER);
          end;
      end;

    procedure ParseExtendedType(AHelperType:THelperType);

      procedure ValidateExtendedDefTypeHelper(var ADef:TDef);
        begin
          if (ADef.typ in [undefineddef,procvardef,procdef,
              filedef,classrefdef,abstractdef,ForwardDef,formaldef]) or
              (
                (ADef.typ=objectdef) and
                not (TObjectDef(ADef).ObjectType in ObjectTypesWithHelpers)
              ) then
            begin
              Message1(type_e_type_not_allowed_for_type_helper,ADef.TypeName);
              ADef:=GenErrorDef;
            end;
        end;

      procedure CheckInheritanceRecordTypeHelper(var ADef:TDef);
        var
          lTempDef : TStoredDef;
        begin
          if (ADef.typ<>errordef) and Assigned(CurrentObjectDef.ChildOf) then
            begin
              if ADef<>CurrentObjectDef.ChildOf.ExtendedDef then
                begin
                  { a type helper may extend a type alias of the type its
                    parent type helper extends }
                  lTempDef:=TStoredDef(ADef);
                  while (df_unique in lTempDef.DefOptions) and Assigned(TStoredDef(lTempDef).OrgDef) do
                    begin
                      if lTempDef.OrgDef=CurrentObjectDef.ChildOf.ExtendedDef then
                        exit;
                      lTempDef:=TStoredDef(lTempDef.OrgDef);
                    end;
                  Message1(type_e_record_helper_must_extend_same_record,CurrentObjectDef.ChildOf.ExtendedDef.TypeName);
                  ADef:=GenErrorDef;
                end;
            end;
        end;

      procedure CheckInheritanceClassHelper(var ADef:TDef);
        begin
          if (ADef.typ<>errordef) and Assigned(CurrentObjectDef.ChildOf) then
            begin
              if (CurrentObjectDef.ChildOf.ExtendedDef.typ<>objectdef) or
                 not (TObjectDef(CurrentObjectDef.ChildOf.ExtendedDef).ObjectType in ObjectTypesWithHelpers) then
                InternalError(2011021101);
              if not Def_Is_Related(ADef,CurrentObjectDef.ChildOf.ExtendedDef) then
                begin
                  Message1(type_e_class_helper_must_extend_subclass,CurrentObjectDef.ChildOf.ExtendedDef.TypeName);
                  ADef:=GenErrorDef;
                end;
            end;
        end;

      var
        lDef: TDef;
      begin
        if not Is_ObjectPascal_Helper(CurrentStructDef) then
          InternalError(2011021103);

        Consume(_FOR);
        { set extendeddef to non-Nil so that potential checks for it won't trigger
          access violations }
        CurrentObjectDef.ExtendedDef:=GenErrorDef;
        SingleType(lDef,[stoParseClassParent]);
        if not Assigned(lDef) or (lDef.typ=errordef) then
          begin
            case AHelperType of
              ht_class:
                Message1(type_e_class_type_expected,lDef.TypeName);
              ht_record:
                Message(type_e_record_type_expected);
              ht_type:
                Message1(type_e_type_id_expected,lDef.TypeName);
              else
                InternalError(2019050532);
            end;
          end
        else
          begin
            case AHelperType of
              ht_class:
                if (lDef.typ<>objectdef) or
                    not Is_Class(lDef) then
                  Message1(type_e_class_type_expected,lDef.TypeName)
                else
                  begin
                    { a class helper must extend the same class or a subclass
                      of the class extended by the parent class helper }
                    CheckInheritanceClassHelper(lDef);
                  end;
              ht_record:
                if (lDef.typ=objectdef) or
                    (
                      { primitive types are allowed for record helpers in mode
                        delphi }
                      (lDef.typ<>recorddef) and
                      not (m_delphi in CurrentSettings.ModeSwitches)
                    ) then
                  Message1(type_e_record_type_expected,lDef.TypeName)
                else
                  begin
                    if lDef.typ<>recorddef then
                      { this is a primitive type in mode delphi, so validate
                        the def }
                      ValidateExtendedDefTypeHelper(lDef);
                    { a record helper must extend the same record as the
                      parent helper }
                    CheckInheritanceRecordTypeHelper(lDef);
                  end;
              ht_type:
                begin
                  ValidateExtendedDefTypeHelper(lDef);
                  if (lDef.typ=objectdef) and
                      (TObjectDef(lDef).ObjectType in ObjectTypesWithHelpers) then
                    CheckInheritanceClassHelper(lDef)
                  else
                    { a type helper must extend the same type as the
                      parent helper }
                    CheckInheritanceRecordTypeHelper(lDef);
                end;
              else
                InternalError(2019050531);
            end;
          end;

        if Assigned(lDef) then
          CurrentObjectDef.ExtendedDef:=lDef;
      end;

    procedure ParseGUID;
      begin
        { read GUID }
        if (CurrentObjectDef.ObjectType in [odt_interfacecom,odt_interfacecorba,odt_dispinterface]) and
           TryToConsume(_LECKKLAMMER) then
          begin
            ReadInterfaceIID;
            Consume(_RECKKLAMMER);
          end
        else if (CurrentObjectDef.ObjectType=odt_dispinterface) then
          message(parser_e_dispinterface_needs_a_guid);
      end;


    function MethodDec(AStruct: TAbstractRecordDef; AIsClassDef: Boolean;AHadGeneric:Boolean): TProcDef;

      procedure CheckObjC(AProcDef: TProcDef);
        begin
          if Is_ObjC_Class_Or_Protocol(AProcDef.struct) then
            begin
              include(AProcDef.ProcOptions,po_objc);
            end;
        end;


      procedure CheckCPP(AProcDef:TProcDef);
          begin
            { nothing currently }
          end;

      var
        lOldParseOnly: Boolean;
        lFlags : TParseProcFlags;
      begin
        case CurrentScanner.FToken of
          _PROCEDURE,
          _FUNCTION:
            begin
              if (AStruct.SymTable.CurrentVisibility=vis_published) and
                 not(oo_can_have_published in AStruct.ObjectOptions) then
                Message(parser_e_cant_have_published);

              lOldParseOnly:=ParseOnly;
              ParseOnly:=true;
              lFlags:=[];
              if AIsClassDef then
                include(lFlags,ppfClassMethod);
              if AHadGeneric then
                include(lFlags,ppfGeneric);
              Result:=ParseProcDec(lFlags,AStruct);

              { this is for error recovery as well as forward }
              { interface mappings, i.e. mapping to a method  }
              { which isn't declared yet                      }
              if Assigned(Result) then
                begin
                  ParseObjectProcDirectives(Result);

                  { check if dispid is set }
                  if Is_DispInterface(Result.struct) and not (po_dispid in Result.ProcOptions) then
                    begin
                      Result.DispID:=TObjectDef(Result.struct).Get_Next_DispID;
                      include(Result.ProcOptions, po_dispid);
                    end;

                  { all Macintosh Object Pascal methods are virtual.  }
                  { this can't be a class method, because macpas mode }
                  { has no m_class                                    }
                  if (m_mac in CurrentSettings.ModeSwitches) then
                    include(Result.ProcOptions,po_virtualmethod);

                  { for record and type helpers only static class methods are
                    allowed }
                  if Is_ObjectPascal_Helper(AStruct) and
                     (
                       (TObjectDef(AStruct).ExtendedDef.typ<>objectdef) or
                       (TObjectDef(TObjectDef(AStruct).ExtendedDef).ObjectType<>odt_class)
                     ) and
                     AIsClassDef and not (po_staticmethod in Result.ProcOptions) then
                    MessagePos(Result.fileinfo,parser_e_class_methods_only_static_in_records);

                  Handle_Calling_Convention(Result,cHCCDefaultActionsIntfStruct);

                  { add definition to procsym }
                  Proc_Add_Definition(Result);

                  { add procdef options to objectdef options }
                  if (po_msgint in Result.ProcOptions) then
                    include(AStruct.ObjectOptions,oo_has_msgint);
                  if (po_msgstr in Result.ProcOptions) then
                    include(AStruct.ObjectOptions,oo_has_msgstr);
                  if (po_virtualmethod in Result.ProcOptions) then
                    include(AStruct.ObjectOptions,oo_has_virtual);

                  if Result.Is_Generic then
                    AStruct.SymTable.IncludeOption(sto_has_generic);

                  CheckCPP(Result);
                  CheckObjC(Result);
                end;

              MaybeParseHintDirectives(Result);

              ParseOnly:=lOldParseOnly;
            end;
          _CONSTRUCTOR :
            begin
              if (AStruct.SymTable.CurrentVisibility=vis_published) and
                not(oo_can_have_published in AStruct.ObjectOptions) then
                Message(parser_e_cant_have_published);

              if not AIsClassDef and not(AStruct.SymTable.CurrentVisibility in [vis_public,vis_published]) then
                Message(parser_w_constructor_should_be_public);

              if Is_Interface(AStruct) then
                Message(parser_e_no_con_des_in_interfaces);

              { Objective-C does not know the concept of a constructor }
              if Is_ObjC_Class_Or_Protocol(AStruct) then
                Message(parser_e_objc_no_constructor_destructor);

              if Is_ObjectPascal_Helper(AStruct) then
                if AIsClassDef then
                  { class constructors are not allowed in class helpers }
                  Message(parser_e_no_class_constructor_in_helpers);

              { only 1 class constructor is allowed }
              if AIsClassDef and (oo_has_class_constructor in AStruct.ObjectOptions) then
                Message1(parser_e_only_one_class_constructor_allowed, AStruct.ObjRealName^);

              lOldParseOnly:=ParseOnly;
              ParseOnly:=true;
              if AIsClassDef then
                Result:=ClassConstructorHead(CurrentStructDef)
              else
                begin
                  Result:=ConstructorHead;
                  if Is_ObjectPascal_Helper(AStruct) and
                     (TObjectDef(AStruct).ExtendedDef.typ<>objectdef) and
                     (Result.MinParaCount=0) then
                      { as long as parameterless constructors aren't allowed in records they
                       aren't allowed in record/type helpers either }
                    MessagePos(Result.ProcSym.fileinfo,parser_e_no_parameterless_constructor_in_records);
                end;

              CheckCPP(Result);

              ParseOnly:=lOldParseOnly;
            end;
          _DESTRUCTOR :
            begin
              if (AStruct.SymTable.CurrentVisibility=vis_published) and
                 not(oo_can_have_published in AStruct.ObjectOptions) then
                Message(parser_e_cant_have_published);

              if not AIsClassDef then
                if (oo_has_new_destructor in AStruct.ObjectOptions) then
                  Message(parser_n_only_one_destructor);

              if Is_Interface(AStruct) then
                Message(parser_e_no_con_des_in_interfaces);

              { (class) destructors are not allowed in class helpers }
              if Is_ObjectPascal_Helper(AStruct) then
                Message(parser_e_no_destructor_in_records);

              if not AIsClassDef and (AStruct.SymTable.CurrentVisibility<>vis_public) then
                Message(parser_w_destructor_should_be_public);

              { Objective-C does not know the concept of a destructor }
              if Is_ObjC_Class_Or_Protocol(AStruct) then
                Message(parser_e_objc_no_constructor_destructor);

              { only 1 class destructor is allowed }
              if AIsClassDef and (oo_has_class_destructor in AStruct.ObjectOptions) then
                Message1(parser_e_only_one_class_destructor_allowed, AStruct.ObjRealName^);

              lOldParseOnly:=ParseOnly;
              ParseOnly:=true;
              if AIsClassDef then
                Result:=ClassDestructorHead(CurrentStructDef)
              else
                Result:=DestructorHead;

              CheckCPP(Result);

              ParseOnly:=lOldParseOnly;
            end;
          else
            InternalError(2011032102);
        end;
      end;


    procedure ParseObjectMembers;

      var
        lTypedConstsWritable: Boolean;
        lObjectMemberBlockType : TBlockType;
        lHadGeneric,
        lFieldsAllowed, lIsClassDef, lClassFields, lIsFinal, lFinalFields,
        lThreadVarFields : Boolean;
        lVarDecOptions: TVarDecOptions;
        lFieldList: TFPObjectList;
        lRTTIAttrsDef: TRTTIAttributeList;
        lAttrElementCount,lFieldCount : Integer;
        lMethodDef : TProcDef;

      procedure CheckUnboundAttributes;
        begin
          if Assigned(lRTTIAttrsDef) and (lRTTIAttrsDef.GetAttributeCount>0) then
            Message1(parser_e_unbound_attribute,TRTTIAttribute(lRTTIAttrsDef.RTTIAttributes[0]).TypeSym.prettyname);
          lRTTIAttrsDef.free;
          lRTTIAttrsDef:=nil;
        end;


      procedure ParseConst;
        begin
          if not(CurrentObjectDef.ObjectType in [odt_class,odt_object,odt_helper]) then
            Message(parser_e_type_var_const_only_in_records_and_classes);
          Consume(_CONST);
          lObjectMemberBlockType:=bt_const;
          lFinalFields:=lIsFinal;
          lIsFinal:=false;
        end;


      procedure ParseVar(AIsThreadVar:Boolean);
        begin
          if not(CurrentObjectDef.ObjectType in [odt_class,odt_object,odt_helper]) then
            Message(parser_e_type_var_const_only_in_records_and_classes);
          if AIsThreadVar then
            Consume(_THREADVAR)
          else
            Consume(_VAR);
          lFieldsAllowed:=true;
          lObjectMemberBlockType:=bt_general;
          lClassFields:=lIsClassDef;
          lFinalFields:=lIsFinal;
          lThreadVarFields:=AIsThreadVar;
          lIsClassDef:=false;
          lIsFinal:=false;
        end;


      procedure ParseClass;
        begin
          lIsClassDef:=false;
          { read class method/field/property }
          Consume(_CLASS);
          { class modifier is only allowed for procedures, functions, }
          { constructors, destructors, fields and properties          }
          if not((CurrentScanner.FToken in [_FUNCTION,_PROCEDURE,_PROPERTY,_VAR,_DESTRUCTOR,_THREADVAR]) or (CurrentScanner.FToken=_CONSTRUCTOR)) then
            Message(parser_e_procedure_or_function_expected);

          { class properties currently can't have attributes }
          if not(CurrentScanner.FToken in [_FUNCTION,_PROCEDURE]) then
            CheckUnboundAttributes;


          if Is_Interface(CurrentStructDef) then
            Message(parser_e_no_static_method_in_interfaces)
          else
            { class methods are also allowed for Objective-C protocols }
            lIsClassDef:=true;
        end;


      procedure ParseVisibility(AVisibility: TVisibility; AObjectOption: TObjectOption);
        begin

          if (AVisibility=vis_published) and
             (Is_ObjC_Class_Or_Protocol(CurrentStructDef)) then
             Message(parser_e_no_objc_published)
          else if Is_Interface(CurrentStructDef) or
             Is_ObjC_Protocol_Or_Category(CurrentStructDef) then
            Message(parser_e_no_access_specifier_in_interfaces);
          CurrentStructDef.SymTable.CurrentVisibility:=AVisibility;
          Consume(CurrentScanner.FToken);
          if (AObjectOption<>oo_none) then
            include(CurrentStructDef.ObjectOptions,AObjectOption);
          lFieldsAllowed:=true;
          lIsClassDef:=false;
          lClassFields:=false;
          lThreadVarFields:=false;
          lIsFinal:=false;
          lObjectMemberBlockType:=bt_general;
        end;


      begin
        { empty class declaration ? }
        if (CurrentObjectDef.ObjectType in [odt_class,odt_objcclass]) and
           (CurrentScanner.FToken=_SEMICOLON) then
          exit;

        { in "publishable" classes the default access type is published }
        if (oo_can_have_published in CurrentStructDef.ObjectOptions) then
          CurrentStructDef.SymTable.CurrentVisibility:=vis_published
        else
          CurrentStructDef.SymTable.CurrentVisibility:=vis_public;
        lFieldsAllowed:=true;
        lIsClassDef:=false;
        lClassFields:=false;
        lIsFinal:=false;
        lFinalFields:=false;
        lRTTIAttrsDef:=nil;
        lHadGeneric:=false;
        lThreadVarFields:=false;
        lObjectMemberBlockType:=bt_general;
        lFieldList:=TFPObjectList.Create(false);
        repeat
          case CurrentScanner.FToken of
            _TYPE :
              begin
                CheckUnboundAttributes;
                if not(CurrentObjectDef.ObjectType in [odt_class,odt_object,odt_helper]) then
                  Message(parser_e_type_var_const_only_in_records_and_classes);
                Consume(_TYPE);
                lObjectMemberBlockType:=bt_type;

                if (CurrentScanner.FToken=_LECKKLAMMER) and (m_prefixed_attributes in CurrentSettings.ModeSwitches) then
                  begin
                    CheckUnboundAttributes;
                    TypesDec(true,lHadGeneric, lRTTIAttrsDef);
                  end
                else
                  { expect at least one type declaration }
                  if CurrentScanner.FToken<>_ID then
                    Consume(_ID);
              end;
            _VAR :
              begin
                CheckUnboundAttributes;
                lRTTIAttrsDef := nil;
                ParseVar(false);
                { expect at least one var declaration }
                if CurrentScanner.FToken<>_ID then
                  Consume(_ID);
              end;
            _CONST:
              begin
                CheckUnboundAttributes;
                lRTTIAttrsDef := nil;
                ParseConst;
                { expect at least one constant declaration }
                if CurrentScanner.FToken<>_ID then
                  Consume(_ID);
              end;
            _THREADVAR :
              begin
                CheckUnboundAttributes;
                if not lIsClassDef then
                  begin
                    Message(parser_e_threadvar_must_be_class);
                    { for error recovery we enforce class fields }
                    lIsClassDef:=true;
                  end;
                ParseVar(true);
                { expect at least one threadvar declaration }
                if CurrentScanner.FToken<>_ID then
                  Consume(_ID);
              end;
            _ID :
              begin
                if Is_ObjCProtocol(CurrentStructDef) and
                   ((CurrentScanner.FIDToken=_REQUIRED) or
                    (CurrentScanner.FIDToken=_OPTIONAL)) then
                  begin
                    CurrentStructDef.SymTable.CurrentlyOptional:=(CurrentScanner.FIDToken=_OPTIONAL);
                    Consume(CurrentScanner.FIDToken)
                  end
                else case CurrentScanner.FIDToken of
                  _PRIVATE :
                    begin
                      ParseVisibility(vis_private,oo_has_private);
                     end;
                   _PROTECTED :
                     begin
                       ParseVisibility(vis_protected,oo_has_protected);
                     end;
                   _PUBLIC :
                     begin
                       ParseVisibility(vis_public,oo_none);
                     end;
                   _PUBLISHED :
                     begin
                       ParseVisibility(vis_published,oo_none);
                     end;
                   _STRICT :
                     begin
                       if Is_Interface(CurrentStructDef) or
                          Is_ObjC_Protocol_Or_Category(CurrentStructDef) then
                         Message(parser_e_no_access_specifier_in_interfaces);
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
                        lIsFinal:=false;
                        lFinalFields:=false;
                        lObjectMemberBlockType:=bt_general;
                     end
                    else if (m_final_fields in CurrentSettings.ModeSwitches) and
                            (CurrentScanner.FToken=_ID) and
                            (CurrentScanner.FIDToken=_FINAL) then
                      begin
                        { currently only supported for external classes, because
                          requires fully working DFA otherwise }
                        if (CurrentStructDef.typ<>objectdef) or
                           not(oo_is_external in TObjectDef(CurrentStructDef).ObjectOptions) then
                          Message(parser_e_final_only_external);
                        Consume(_final);
                        lIsFinal:=true;
                        if CurrentScanner.FToken=_CLASS then
                          ParseClass;
                        if not(CurrentScanner.FToken in [_CONST,_VAR]) then
                          message(parser_e_final_only_const_var);
                      end
                    else
                      begin
                        if lObjectMemberBlockType=bt_general then
                          begin
                            if (CurrentScanner.FIDToken=_GENERIC) and
                                not (m_delphi in CurrentSettings.ModeSwitches) and
                                (
                                  not lFieldsAllowed or
                                  Is_ObjectPascal_Helper(CurrentStructDef)
                                ) then
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
                                if Is_Interface(CurrentStructDef) or
                                   Is_ObjC_Protocol_Or_Category(CurrentStructDef) or
                                   (
                                     Is_ObjectPascal_Helper(CurrentStructDef) and
                                     not lClassFields
                                   ) then
                                  Message(parser_e_no_vars_in_interfaces);

                                if (CurrentStructDef.SymTable.CurrentVisibility=vis_published) and
                                   not(oo_can_have_published in CurrentStructDef.ObjectOptions) then
                                  Message(parser_e_cant_have_published);
                                if (not lFieldsAllowed) then
                                  Message(parser_e_field_not_allowed_here);

                                lVarDecOptions:=[vdObject];
                                if not (m_delphi in CurrentSettings.ModeSwitches) then
                                  include(lVarDecOptions,vdCheckGeneric);
                                if lClassFields then
                                  include(lVarDecOptions,vdClass);
                                if Is_Class(CurrentStructDef) then
                                  include(lVarDecOptions,vdCanReorder);
                                if lFinalFields then
                                  include(lVarDecOptions,vdFinal);
                                if lThreadVarFields then
                                  include(lVarDecOptions,vdThreadVar);
                                // Record count
                                lFieldCount:=lFieldList.Count;
                                ReadRecordFields(lVarDecOptions,lFieldList,nil,lHadGeneric,lAttrElementCount);
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
                                  { read_record_fields can read a list of fields with the same type.
                                    for the first fields, we simply copy. for the last one we bind.}
                                  While (lAttrElementCount>1) do
                                    begin
                                    TRTTIAttributeList.CopyAndBind(lRTTIAttrsDef,TFieldVarSym(lFieldList[lFieldCount]).RTTIAttributeList);
                                    inc(lFieldCount);
                                    dec(lAttrElementCount);
                                    end;
                                  if lFieldCount<lFieldList.Count then
                                    TRTTIAttributeList.bind(lRTTIAttrsDef,TFieldVarSym(lFieldList[lFieldCount]).RTTIAttributeList)
                                  else
                                    lRTTIAttrsDef.free;
                                    lRTTIAttrsDef := nil;
                                  end;
                                lRTTIAttrsDef:=nil;
                              end;
                          end
                        else if lObjectMemberBlockType=bt_type then
                          begin
                          CheckUnboundAttributes;
                          TypesDec(true,lHadGeneric, lRTTIAttrsDef)
                          end
                        else if lObjectMemberBlockType=bt_const then
                          begin
                            CheckUnboundAttributes;
                            lTypedConstsWritable:=false;
                            if lFinalFields then
                              begin
                                { the value of final fields cannot be changed
                                  once they've been assigned a value }
                                lTypedConstsWritable:=cs_typed_const_writable in CurrentSettings.LocalSwitches;
                                exclude(CurrentSettings.LocalSwitches,cs_typed_const_writable);
                              end;
                            ConstsDec(true,true,lHadGeneric);
                            if lFinalFields and
                               lTypedConstsWritable then
                              include(CurrentSettings.LocalSwitches,cs_typed_const_writable);
                          end
                        else
                          InternalError(2010011103);
                      end;
                end;
              end;
            _PROPERTY :
              begin
                StructPropertyDec(lIsClassDef, lRTTIAttrsDef);
                lFieldsAllowed:=false;
                lIsClassDef:=false;
              end;
            _CLASS:
                ParseClass;
            _PROCEDURE,
            _FUNCTION,
            _CONSTRUCTOR,
            _DESTRUCTOR :
              begin
                lMethodDef:=MethodDec(CurrentStructDef,lIsClassDef,lHadGeneric);
                if Assigned(lRTTIAttrsDef) then
                  begin
                  TRTTIAttributeList.bind(lRTTIAttrsDef,lMethodDef.RTTIAttributeList);
                  lRTTIAttrsDef:=nil;
                  end;
                lFieldsAllowed:=false;
                lIsClassDef:=false;
                lHadGeneric:=false;
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
                CheckUnboundAttributes;
                Consume(_END);
                break;
              end;
            else
              Consume(_ID); { Give a ident expected message, like tp7 }
          end;
        until false;

        if Is_Class(CurrentStructDef) then
          TAbstractRecordSymTable(CurrentStructDef.SymTable).AddFieldList(lFieldList,true);
        lFieldList.free;
        lFieldList := nil;
      end;


    function ObjectDec(AObjectType:TObjectTyp;const AName:TIDString;AObjSym:TSym;AGenericDef:TStoredDef;AGenericList:TFPHashObjectList;AForwardDef : TObjectDef;AHelperType:THelperType) : TObjectDef;
      var
        lOldCurrentStructDef: TAbstractRecordDef;
        lOldCurrentGenericDef,
        lOldCurrentSpecializeDef: TStoredDef;
        lOldParseGeneric: Boolean;
        lList: TFPObjectList;
        lText: TSymStr;
        lSymTable: TSymTable;
        lOldDef: TDef;
      begin
        lOldCurrentStructDef:=CurrentStructDef;
        lOldCurrentGenericDef:=CurrentGenericDef;
        lOldCurrentSpecializeDef:=CurrentSpecializeDef;
        lOldParseGeneric:=ParseGeneric;

        CurrentStructDef:=nil;
        CurrentGenericDef:=nil;
        CurrentSpecializeDef:=nil;

        { objects and class types can't be declared local }
        if not(SymTableStack.top.SymTableType in [GlobalSymTable,staticsymtable,objectsymtable,recordsymtable]) and
           not Assigned(AGenericList) then
          Message(parser_e_no_local_objects);

        { reuse forward objectdef? }
        if Assigned(AForwardDef) then
          begin
            if (AForwardDef.ObjectType<>AObjectType) or ((AForwardDef.Is_Generic or AForwardDef.Is_Specialization) xor Assigned(AGenericList)) then
              begin
                Message(parser_e_forward_mismatch);
                { recover }
                CurrentStructDef:=CObjectDef.Create(AObjectType,AName,nil,true);
                include(CurrentStructDef.ObjectOptions,oo_is_forward);
              end
            else
              CurrentStructDef:=AForwardDef
          end
        else
          begin
            { anonym objects aren't allow (o : object a : longint; end;) }
            if AName='' then
              Message(parser_f_no_anonym_objects);

            { create new class }
            CurrentStructDef:=CObjectDef.Create(AObjectType,AName,nil,true);
            TObjectDef(CurrentStructDef).HelperType:=AHelperType;

            { include always the forward flag, it'll be removed once the whole
              class has been parsed so that it can be used as a parent class
              of a nested class;
              Exception: for external classes this will be removed once the
              parent classes have been parsed }
            include(CurrentStructDef.ObjectOptions,oo_is_forward);

            if (cs_compilesystem in CurrentSettings.ModuleSwitches) then
              begin
                case CurrentObjectDef.ObjectType of
                  odt_interfacecom :
                    if (CurrentStructDef.ObjName^='IUNKNOWN') then
                      Interface_IUnknown:=CurrentObjectDef
                    else
                    if (CurrentStructDef.ObjName^='IDISPATCH') then
                      Interface_IDispatch:=CurrentObjectDef;
                  odt_class :
                    if (CurrentStructDef.ObjName^='TOBJECT') then
                      Class_TObject:=CurrentObjectDef;

                  else
                    ;
                end;
              end;
            if (CurrentModule.ModuleName^='OBJCBASE') then
              begin
                case CurrentObjectDef.ObjectType of
                  odt_objcclass:
                    if (CurrentObjectDef.ObjName^='Protocol') then
                      ObjC_ProtocolType:=CurrentObjectDef;
                  else
                    ;
                end;
              end;
          end;

        { usage of specialized type inside its generic template }
        if Assigned(AGenericDef) then
          CurrentSpecializeDef:=CurrentStructDef;
        { reject declaration of generic class inside generic class }
        if Assigned(AGenericList) then
          CurrentGenericDef:=CurrentStructDef;

        { nested types of specializations are specializations as well }
        if Assigned(lOldCurrentStructDef) and
            (df_specialization in lOldCurrentStructDef.DefOptions) then
          include(CurrentStructDef.DefOptions,df_specialization);
        if Assigned(lOldCurrentStructDef) and
            (df_generic in lOldCurrentStructDef.DefOptions) then
          begin
            include(CurrentStructDef.DefOptions,df_generic);
            CurrentGenericDef:=CurrentStructDef;
          end;

        { set published flag in $M+ mode, it can also be inherited and will
          be added when the parent class set with tobjectdef.set_parent (PFV) }
        if (cs_generate_rtti in CurrentSettings.LocalSwitches) and
           (CurrentObjectDef.ObjectType in [odt_interfacecom,odt_interfacecorba,odt_class,odt_helper]) then
          include(CurrentStructDef.ObjectOptions,oo_can_have_published);


        if AObjectType in [odt_objcclass,odt_objcprotocol,odt_objccategory] then
          ParseObjectOptions;

        { forward def? }
        if CurrentScanner.FToken=_SEMICOLON then
          begin
            if Assigned(AForwardDef) then
              Message1(parser_e_type_alread_forward,AName)
            else
              begin
                if Is_ObjectPascal_Helper(CurrentStructDef) then
                  Consume(_FOR);
                { add to the list of definitions to check that the forward
                  is resolved. this is required for delphi mode }
                CurrentModule.CheckForwardDefs.add(CurrentStructDef);

                SymTableStack.push(CurrentStructDef.SymTable);
                InsertGenericParameterTypes(CurrentStructDef,AGenericDef,AGenericList,false);
                { when we are parsing a generic already then this is a generic as
                  well }
                if lOldParseGeneric then
                  include(CurrentStructDef.DefOptions,df_generic);
                ParseGeneric:=(df_generic in CurrentStructDef.DefOptions);

                { *don't* add the strict private symbol for non-Delphi modes for
                  forward defs }

                SymTableStack.pop(CurrentStructDef.SymTable);
              end;
          end
        else
          begin
            { change objccategories into objcclass helpers }
            if (AObjectType=odt_objccategory) then
              begin
                CurrentObjectDef.ObjectType:=odt_objcclass;
                include(CurrentStructDef.ObjectOptions,oo_is_classhelper);
              end;

            { include the class helper flag for Object Pascal helpers }
            if (AObjectType=odt_helper) then
              include(CurrentObjectDef.ObjectOptions,oo_is_classhelper);

            { parse list of options (abstract / sealed) }
            if not(AObjectType in [odt_objcclass,odt_objcprotocol,odt_objccategory]) then
              ParseObjectOptions;

            SymTableStack.push(CurrentStructDef.SymTable);
            InsertGenericParameterTypes(CurrentStructDef,AGenericDef,AGenericList,Assigned(AForwardDef));
            { when we are parsing a generic already then this is a generic as
              well }
            if lOldParseGeneric then
              include(CurrentStructDef.DefOptions, df_generic);
            ParseGeneric:=(df_generic in CurrentStructDef.DefOptions);

            { in non-Delphi modes we need a strict private symbol without type
              count and type parameters in the name to simplify resolving }
            MaybeInsertGenericRenameSymbol(AName,AGenericList);

            { parse list of parent classes }
            { for record helpers in mode Delphi this is not allowed }
            if not (Is_ObjectPascal_Helper(CurrentObjectDef) and
                (m_delphi in CurrentSettings.ModeSwitches) and
                (AHelperType=ht_record)) then
              ParseParentClasses;

            { for external classes we remove the external flag here already }
            if oo_is_external in CurrentObjectDef.ObjectOptions then
              exclude(CurrentObjectDef.ObjectOptions,oo_is_forward);

            { parse extended type for helpers }
            if Is_ObjectPascal_Helper(CurrentStructDef) then
              ParseExtendedType(AHelperType);

            if Is_Interface(CurrentObjectDef) and
                Is_Interface(CurrentObjectDef.ChildOf) and
                (oo_is_invokable in TObjectDef(CurrentObjectDef.ChildOf).ObjectOptions) then
              include(CurrentObjectDef.ObjectOptions,oo_is_invokable);

            { parse optional GUID for interfaces }
            ParseGUID;

            { classes can handle links to themself not only inside type blocks
              but in const blocks too. Additionally this is needed to parse parameters that are
              specializations of the currently parsed type in basically everything except C++ and
              ObjC classes. To make this possible we need to set their symbols to real defs instead
              of errordef }

            if Assigned(AObjSym) and not (AObjectType in [odt_cppclass,odt_objccategory,odt_objcclass,odt_objcprotocol]) then
              begin
                lOldDef:=TTypeSym(AObjSym).TypeDef;
                TTypeSym(AObjSym).TypeDef:=CurrentStructDef;
                CurrentStructDef.TypeSym:=AObjSym;
              end
            else
              lOldDef:=nil;

            { if set explicitly, apply $RTTI directive to current object }
            if CurrentModule.RTTIDirective.clause<>rtc_none then
              CurrentStructDef.Apply_RTTI_Directive(CurrentModule.RTTIDirective)
            else
              { if not set, and class has a parent, take parent object settings }
              if (AObjectType = odt_class) and Assigned(CurrentObjectDef.ChildOf) then
                CurrentStructDef.Apply_RTTI_Directive(CurrentObjectDef.ChildOf.RTTI);

            { generate TObject VMT space }
            { We must insert the VMT at the start for system.tobject, and class_tobject was already set.
              The cs_compilesystem is superfluous, but we add it for safety.

            }
            if (CurrentObjectDef=Class_TObject) and (cs_compilesystem in CurrentSettings.ModuleSwitches) then
              CurrentObjectDef.InsertVMT;

            { parse and insert object members }
            ParseObjectMembers;

            if Assigned(lOldDef) then
              begin
                TTypeSym(AObjSym).TypeDef:=lOldDef;
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
           not(CurrentObjectDef.ObjectType in [odt_class]) and
           not(oo_is_forward in CurrentStructDef.ObjectOptions) and
           not(ParseGeneric) and
           { no vmt for helpers ever }
           not Is_ObjectPascal_Helper(CurrentStructDef) and
            ([oo_has_virtual,oo_has_constructor,oo_has_destructor]*CurrentStructDef.ObjectOptions<>[])
           then
          CurrentObjectDef.InsertVMT;

        { for implemented classes with a vmt check if there is a constructor }
        if (oo_has_vmt in CurrentStructDef.ObjectOptions) and
           not(oo_is_forward in CurrentStructDef.ObjectOptions) and
           not(oo_has_constructor in CurrentStructDef.ObjectOptions) and
           not Is_ObjC_Class_Or_Protocol(CurrentStructDef) then
          Message1(parser_w_virtual_without_constructor,CurrentStructDef.ObjRealName^);

        if Is_Interface(CurrentStructDef) or
           Is_ObjCProtocol(CurrentStructDef) then
          SetInterfaceMethodOptions
        else if Is_ObjCClass(CurrentStructDef) then
          SetObjCClassMethodOptions;

        { we need to add this helper to the extendeddefs of the current module,
          as the global and static symtable are not pushed onto the symtable
          stack again (it will be removed when popping the symtable) }
        if Is_ObjectPascal_Helper(CurrentStructDef) and
            (CurrentObjectDef.ExtendedDef.typ<>errordef) then
          begin
            { the topmost symtable must be a static symtable }
            lSymTable:=CurrentStructDef.owner;
            while lSymTable.SymTableType in [objectsymtable,recordsymtable] do
              lSymTable:=lSymTable.DefOwner.owner;
            if lSymTable.SymTableType in [staticsymtable,GlobalSymTable] then
              begin
                if CurrentObjectDef.ExtendedDef.typ in [recorddef,objectdef] then
                  lText:=Make_MangledName('',TAbstractRecordDef(CurrentObjectDef.ExtendedDef).SymTable,'')
                else
                  lText:=Make_MangledName('',CurrentObjectDef.ExtendedDef.owner,CurrentObjectDef.ExtendedDef.TypeSym.name);
                Message1(sym_d_adding_helper_for,lText);
                lList:=TFPObjectList(CurrentModule.ExtendedDefs.Find(lText));
                if not Assigned(lList) then
                  begin
                    lList:=TFPObjectList.Create(false);
                    CurrentModule.ExtendedDefs.Add(lText, lList);
                  end;
                lList.add(CurrentStructDef);
              end;
          end;
        TAbstractRecordSymTable(CurrentObjectDef.SymTable).AddAlignmentPadding;

        { return defined objectdef }
        Result:=CurrentObjectDef;

        { restore old state }
        CurrentStructDef:=lOldCurrentStructDef;
        CurrentGenericDef:=lOldCurrentGenericDef;
        CurrentSpecializeDef:=lOldCurrentSpecializeDef;
        ParseGeneric:=lOldParseGeneric;
      end;

end.
