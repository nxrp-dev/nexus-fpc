{
    Copyright (c) 2011

    Contains different functions that are used in the context of
    parsing generics.

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
unit pgenutil;

{$i fpcdefs.inc}

interface

uses
  TPCompilerReal,
    { common }
  CClasses,
  { global }
  GlobType,
  { parser }
  pgentype,
  { node }
  node,
  { symtable }
  symtype,symdef,SymBase;

    procedure GenerateSpecialization(var ADef:TDef;AEnforceUnit:Boolean;AParseClassParent:Boolean;const APrettyName:String;AParsedType:TDef;const ASymName:String;AParsedPos:TFilePosInfo);inline;
    procedure GenerateSpecialization(var ADef:TDef;AEnforceUnit:Boolean;AParseClassParent:Boolean;const APrettyName:String;const ASymName:String;ASymTable:TSymTable);inline;
    function GenerateSpecializationPhase1(out AContext:TSpecializationContext;AGenericDef:TDef;AEnforceUnit:Boolean):TDef;inline;
    function GenerateSpecializationPhase1(out AContext:TSpecializationContext;AGenericDef:TDef;AEnforceUnit:Boolean;const ASymName:String;ASymTable:TSymTable):TDef;inline;
    function GenerateSpecializationPhase1(out AContext:TSpecializationContext;AGenericDef:TDef;AEnforceUnit:Boolean;AParsedType:TDef;const ASymName:String;ASymTable:TSymTable;AParsedPos:TFilePosInfo):TDef;
    function GenerateSpecializationPhase2(AContext:TSpecializationContext;AGenericDef:TStoredDef;AParseClassParent:Boolean;const APrettyName:AnsiString):TDef;
    function CheckGenericConstraints(AGenericDef:TStoredDef;AParamList:TFPObjectList;APosList:TFPList):Boolean;
    function ParseGenericParameters(AAllowConstraints:Boolean):TFPHashObjectList;
    function ParseGenericSpecializationTypes(AParamList:TFPObjectList;APosList:TFPList;out APrettyName,ASpecializeName:AnsiString):Boolean;
    procedure InsertGenericParameterTypes(ADef:TStoredDef;AGenericDef:TStoredDef;AGenericList:TFPHashObjectList;AIsFwd:Boolean);
    procedure MaybeInsertGenericRenameSymbol(const AName:TIDString;AGenericList:TFPHashObjectList);
    function GenerateGenericName(const AName:TIDString;const ASpecializeName:AnsiString;const AOwnerHierarchy:AnsiString):TIDString;
    procedure SplitGenericName(const AName:TIDString;out ANonGeneric:String;out ACount:LongInt);
    procedure AddGenericDummySym(ASym:TSym;const AName:TIDString);
    function ResolveGenericDummySym(const AName:TIDString):TSym;
    function CouldBeGeneric(const AName:TIDString):Boolean;inline;
    function TryImplicitSpecialization(ASym:TSym;APara:TNode;APDOverloadList:TFPObjectList;var AUnnamedSyms:TFPList;var AFirstProcSym:TSym;var AHasOverload:Boolean):Boolean;
    function FinalizeSpecialization(var AProcDef:TProcDef;ASpezContext:TSpecializationContext):Boolean;

    procedure GenerateSpecializationProcs;
    procedure GenerateSpecializationsForForwardDef(ADef:TDef);
    procedure MaybeAddPendingSpecialization(ADef:TDef;AUnnamedSyms:TFPList);
    function DetermineGenericDef(const AName:TIDString):TStoredDef;

    function IsOrBelongsToCurrentGenericDef(ADef:TDef):Boolean;

    procedure SpecializationInit(AGenericDef:TDef;var AState:TSpecializationState);
    procedure SpecializationDone(var AState:TSpecializationState);

implementation

uses
  { common }
  CUtils,CRC32,
  { global }
  Globals,tokens,Verbose,FinPut,ConstExp,
  { symtable }
  symconst,SymSym,SymTable,defcmp,defutil,ProcInfo,
  { modules }
  FModule,
  { node }
  nobj,ncon,ncal,
  { parser }
  Scanner,
  pbase,pexpr,pdecsub,ptype,psub,pparautl,pdecl,procdefutil;

  type
    TDefTypeSet = set of TDefTyp;
  const
    cGenericParamConstTypes : TDefTypeSet = [orddef,stringdef,floatdef,setdef,pointerdef,enumdef];
    cGenericParamNodes : TNodeTypeSet = [typen,ordconstn,stringconstn,realconstn,setconstn,niln];

    procedure MakePrettyString(AParamType:TDef;AFirst:Boolean;AConstPrettyName:AnsiString;var APrettyName,ASpecializeName:AnsiString);
      var
        lNamePart : String;
        lPrettyNamePart : AnsiString;
        lModule : TModule;
      begin
        if Assigned(AParamType.owner) then
          lModule:=Find_Module_From_SymTable(AParamType.owner)
        else
          lModule:=CurrentModule;
        if not Assigned(lModule) then
          InternalError(2016112802);
        lNamePart:='_$'+HexStr(lModule.ModuleID,8)+'$$'+AParamType.UniqueIDStr;
        if AConstPrettyName<>'' then
          lNamePart:=lNamePart+'$$'+AConstPrettyName;
        { we use the full name of the type to uniquely identify it }
        if (SymTableStack.top.SymTableType=parasymtable) and
            (SymTableStack.top.DefOwner.typ=procdef) and
            (AParamType.owner=SymTableStack.top) then
          begin
            { special handling for specializations inside generic function declarations }
            lPrettyNamePart:=TDef(SymTableStack.top.DefOwner).FullOwnerHierarchyName(true,true)+TProcDef(SymTableStack.top.DefOwner).ProcSym.prettyname;
          end
        else
          begin
            lPrettyNamePart:=AParamType.FullOwnerHierarchyName(true,true);
          end;
        ASpecializeName:=ASpecializeName+lNamePart;
        if not AFirst then
          APrettyName:=APrettyName+',';
        if AConstPrettyName<>'' then
          APrettyName:=APrettyName+AConstPrettyName
        else
          APrettyName:=APrettyName+lPrettyNamePart+AParamType.TypeSym.prettyname;
      end;

    function GetGenericParamDef(ASym:TSym):TDef;
      begin
        if ASym.typ=constsym then
          Result:=TConstSym(ASym).ConstDef
        else
          Result:=TTypeSym(ASym).TypeDef;
      end;

    function CompareOrdDefByRange(AParam1,AParam2:TOrdDef;AValue:TConstValue):Boolean;
      begin
        if (AValue.ValueOrd<AParam2.low) or (AValue.ValueOrd>AParam2.high) then
          Result:=false
        else
          Result:=true;
      end;

    function CompareGenericParams(AParam1,AParam2:TDef;AConstParamSym:TConstSym):Boolean;
      begin
        if (AParam1.typ=orddef) and (AParam2.typ=orddef) then
          begin
            if Is_Boolean(AParam2) then
              Result:=Is_Boolean(AParam1)
            else if Is_Char(AParam2) then
              Result:=Is_Char(AParam1)
            else if CompareOrdDefByRange(TOrdDef(AParam1),TOrdDef(AParam2),AConstParamSym.Value) then
              Result:=true
            else
              Result:=false;
          end
        { arraydef is string constant so it's compatible with stringdef }
        else if (AParam1.typ=arraydef) and (AParam2.typ=stringdef) then
          Result:=true
        { integer ords are compatible with float }
        else if (AParam1.typ=orddef) and Is_Integer(AParam1) and (AParam2.typ=floatdef) then
          Result:=true
        { chars are compatible with stringdef }
        else if (AParam1.typ=orddef) and Is_Char(AParam1) and (AParam2.typ=stringdef) then
          Result:=true
        { undefined def is compatible with all types }
        else if AParam2.typ=undefineddef then
          Result:=true
        { sets require stricter checks }
        else if Is_Set(AParam2) then
          Result:=Equal_Defs(AParam1,AParam2) or
            { constant could be empty set }
            not(Assigned(TSetDef(AParam1).ElementDef))
        else
          Result:=AParam1.typ=AParam2.typ;
      end;

    function CreateGenericConstSym(AFromDef:TDef;ANode:TNode;out APrettyName:String):TConstSym;
      const
        cUndefinedName = 'undefined';
      var
        lSym : TConstSym;
        lSetDef : TSetDef;
        lEnumSym : TSym;
        lEnumName : String;
        lStringData : PChar;
        lSetValue : ^TConstSet;
        lRealValue : ^BestReal;
        lIndex,lLength : Integer;
      begin
        if ANode=nil then
          InternalError(2020011401);
        case ANode.nodetype of
          ordconstn:
            begin
              lSym:=CConstSym.Create_Ord(cUndefinedName,constord,TOrdConstNode(ANode).Value,AFromDef);
              APrettyName:=ToStr(TOrdConstNode(ANode).Value.svalue);
            end;
          stringconstn:
            begin
              // unicode, convert to utf8
              if TStringConstNode(ANode).ConstStringType in [cst_widestring,cst_unicodestring] then
                begin
                lLength:=UnicodeToUtf8(nil,0,TStringConstNode(ANode).ValueWS.AsConstPUnicodeChar,TStringConstNode(ANode).ValueWS.len);
                GetMem(lStringData,lLength);
                UnicodeToUtf8(lStringData,lLength,TStringConstNode(ANode).ValueWS.AsConstPUnicodeChar,TStringConstNode(ANode).ValueWS.len);
                lSym:=CConstSym.Create_String(cUndefinedName,conststring,lStringData,lLength,AFromDef);
                APrettyName:=''''+lStringData+'''';
                end
              else
                begin
                GetMem(lStringData,TStringConstNode(ANode).len+1);
                move(TStringConstNode(ANode).AsConstPChar^,lStringData^,TStringConstNode(ANode).len+1);
                lSym:=CConstSym.Create_String(cUndefinedName,conststring,lStringData,TStringConstNode(ANode).len,AFromDef);
                APrettyName:=''''+TStringConstNode(ANode).AsConstPChar+'''';
                end;
            end;
          realconstn:
            begin
              new(lRealValue);
              lRealValue^:=TRealConstNode(ANode).ValueReal;
              lSym:=CConstSym.Create_Ptr(cUndefinedName,constreal,lRealValue,AFromDef);
              APrettyName:=RealToStr(TRealConstNode(ANode).ValueReal);
            end;
          setconstn:
            begin
              new(lSetValue);
              lSetValue^:=TSetConstNode(ANode).ValueSet^;
              lSym:=CConstSym.Create_Ptr(cUndefinedName,constset,lSetValue,AFromDef);
              lSetDef:=TSetDef(TSetConstNode(ANode).resultdef);
              APrettyName:='[';
              for lIndex := lSetDef.SetBase to lSetDef.SetMax do
                if lIndex in TSetConstNode(ANode).ValueSet^ then
                  begin
                    if lSetDef.ElementDef.typ=enumdef then
                      lEnumSym:=TEnumDef(lSetDef.ElementDef).Int2EnumSym(lIndex)
                    else
                      lEnumSym:=nil;
                    if Assigned(lEnumSym) then
                      lEnumName:=lEnumSym.realname
                    else if lSetDef.ElementDef.typ=orddef then
                      begin
                        if TOrdDef(lSetDef.ElementDef).OrdType=uchar then
                          lEnumName:=chr(lIndex)
                        else
                          lEnumName:=ToStr(lIndex);
                      end
                    else
                      lEnumName:=ToStr(lIndex);
                    if length(APrettyName) > 1 then
                      APrettyName:=APrettyName+','+lEnumName
                    else
                      APrettyName:=APrettyName+lEnumName;
                  end;
              APrettyName:=APrettyName+']';
            end;
          niln:
            begin
              { only "nil" is available for pointer constants }
              lSym:=CConstSym.Create_Ord(cUndefinedName,constnil,0,AFromDef);
              APrettyName:='nil';
            end;
          else
            InternalError(2019021601);
        end;
        { the sym needs an owner for later checks so use the typeparam owner }
        lSym.owner:=AFromDef.owner;
        include(lSym.SymOptions,sp_generic_const);
        Result:=lSym;
      end;

    procedure MaybeAddWaitingUnit(ADef:TDef);
    { called only by a pas module when specializing or inlining, not by a ppu module }
      var
        lModule : TModule;
      begin
        if not Assigned(ADef) or
            not (df_generic in ADef.DefOptions) then
          exit;

        lModule:=Find_Module_From_SymTable(ADef.owner);
        if not Assigned(lModule) then
          InternalError(2012092401);

        if lModule=CurrentModule then
          exit;

        { Note: if hmodule.state=ms_load its implementation is not yet ready }

        if lModule.state<ms_compiling_waitfinish then
          begin
            TModule.CTask_Fast_Backtrack:=true;
            if CurrentModule.WaitingForUnit.indexof(lModule)<0 then
              CurrentModule.WaitingForUnit.add(lModule);
            if lModule.WaitingUnits.indexof(CurrentModule)<0 then
              lModule.WaitingUnits.add(CurrentModule);
          end;
      end;


    procedure AddForwardGenericDef(ADef:TDef;AContext:TSpecializationContext);
      var
        lList : TFPObjectList;
        lFwdContext : TSpecializationContext;
      begin
        if not Is_Implicit_Pointer_Object_Type(ADef) then
          InternalError(2020070301);
        if not (oo_is_forward in TObjectDef(ADef).ObjectOptions) then
          InternalError(2020070302);
        if not Assigned(TObjectDef(ADef).GenericDef) then
          InternalError(2020070303);
        lList:=TFPObjectList(CurrentModule.ForwardGenericDefs.find(TObjectDef(ADef).GenericDef.FullTypeName));
        if not Assigned(lList) then
          begin
            lList:=TFPObjectList.Create(true);
            CurrentModule.ForwardGenericDefs.add(TObjectDef(ADef).GenericDef.FullTypeName,lList);
          end;
        lFwdContext:=AContext.GetCopy;
        lFwdContext.FForwardDef:=ADef;
        lList.add(lFwdContext);
      end;


    function CheckGenericConstraints(AGenericDef:TStoredDef;AParamList:TFPObjectList;APosList:TFPList):Boolean;
      var
        lIndex,lInnerIndex,
        lIntfCount : LongInt;
        lFormalDef,
        lParaDef : TStoredDef;
        lGenParaDef : TDef;
        lObjDef,
        lParaObjDef,
        lFormalObjDef : TObjectDef;
        lIntfFound : Boolean;
        lFilePos : TFilePosInfo;
        lIsConst : Boolean;
      begin
        { check whether the given specialization parameters fit to the eventual
          constraints of the generic }
        if not Assigned(AGenericDef.GenericParas) or (AGenericDef.GenericParas.count=0) then
          InternalError(2012101001);
        if AGenericDef.GenericParas.count<>AParamList.count then
          InternalError(2012101002);
        if AParamList.count<>APosList.count then
          InternalError(2012120801);
        Result:=true;
        for lIndex:=0 to AGenericDef.GenericParas.count-1 do
          begin
            lFilePos:=PFilePosInfo(APosList[lIndex])^;
            lParaDef:=TStoredDef(GetGenericParamDef(TSym(AParamList[lIndex])));
            lIsConst:=TSym(AParamList[lIndex]).typ=constsym;
            lGenParaDef:=AGenericDef.Get_Generic_Param_Def(lIndex);
            { validate const params }
            if not AGenericDef.Is_Generic_Param_Const(lIndex) and lIsConst then
              begin
                MessagePos(lFilePos,type_e_mismatch);
                exit(false);
              end
            else if AGenericDef.Is_Generic_Param_Const(lIndex) then
              begin
                { param type mismatch (type <> const) }
                 if AGenericDef.Is_Generic_Param_Const(lIndex)<>lIsConst then
                   begin
                    MessagePos(lFilePos,type_e_mismatch);
                    exit(false);
                  end;
                { type constrained param doesn't match type }
                if not CompareGenericParams(lParaDef,AGenericDef.Get_Generic_Param_Def(lIndex),TConstSym(AParamList[lIndex])) then
                  begin
                    MessagePos2(lFilePos,type_e_incompatible_types,FullTypeName(lParaDef,lGenParaDef),FullTypeName(lGenParaDef,lParaDef));
                    exit(false);
                  end;
              end;
            { test constraints for non-const params }
            if not AGenericDef.Is_Generic_Param_Const(lIndex) then
              begin
                lFormalDef:=TStoredDef(TTypeSym(AGenericDef.GenericParas[lIndex]).TypeDef);
                if lFormalDef.typ=undefineddef then
                  { the parameter is of unspecified type, so no need to check }
                  continue;
                if not (df_genconstraint in lFormalDef.DefOptions) or
                    not Assigned(lFormalDef.GenConstraintData) then
                  InternalError(2013021602);
                { undefineddef is compatible with anything }
                if lFormalDef.typ=undefineddef then
                  continue;
                if lParaDef.typ<>lFormalDef.typ then
                  begin
                    case lFormalDef.typ of
                      recorddef:
                        { delphi has own fantasy about record constraint
                          (almost non-nullable/non-nil-able value type) }
                        if m_delphi in CurrentSettings.ModeSwitches then
                          case lParaDef.typ of
                            floatdef,enumdef,orddef:
                              continue;
                            objectdef:
                              if TObjectDef(lParaDef).ObjectType=odt_object then
                                continue
                              else
                                MessagePos(lFilePos,type_e_record_type_expected);
                            else
                              MessagePos(lFilePos,type_e_record_type_expected);
                          end
                        else
                          MessagePos(lFilePos,type_e_record_type_expected);
                      objectdef:
                        case TObjectDef(lFormalDef).ObjectType of
                          odt_class:
                            MessagePos1(lFilePos,type_e_class_type_expected,lParaDef.TypeName);
                          odt_interfacecom,
                          odt_interfacecorba,
                          odt_dispinterface:
                            MessagePos1(lFilePos,type_e_interface_type_expected,lParaDef.TypeName);
                          else
                            InternalError(2012101003);
                        end;
                      errordef:
                        { ignore }
                        ;
                      else
                        InternalError(2012101004);
                    end;
                    Result:=false;
                  end
                else
                  begin
                    { the paradef types are the same, so do special checks for the
                      cases in which they are needed }
                    if lFormalDef.typ=objectdef then
                      begin
                        lParaObjDef:=TObjectDef(lParaDef);
                        lFormalObjDef:=TObjectDef(lFormalDef);
                        if not (lFormalObjDef.ObjectType in [odt_class,odt_interfacecom,odt_interfacecorba,odt_dispinterface]) then
                          InternalError(2012101102);
                        if lFormalObjDef.ObjectType in [odt_interfacecom,odt_interfacecorba,odt_dispinterface] then
                          begin
                            { this is either a concrete interface or class type (the
                              latter without specific implemented interfaces) }
                            case lParaObjDef.ObjectType of
                              odt_interfacecom,
                              odt_interfacecorba,
                              odt_dispinterface:
                                begin
                                  if (oo_is_forward in lParaObjDef.ObjectOptions) and
                                      (lParaObjDef.ObjectType=lFormalObjDef.ObjectType) and
                                      (df_genconstraint in lFormalObjDef.DefOptions) and
                                      (
                                        (lFormalObjDef.ObjectType=odt_interfacecom) and
                                        (lFormalObjDef.ChildOf=Interface_IUnknown)
                                      )
                                      or
                                      (
                                        (lFormalObjDef.ObjectType=odt_interfacecorba) and
                                        (lFormalObjDef.ChildOf=nil)
                                      ) then
                                    continue;
                                  if not Def_Is_Related(lParaObjDef,lFormalObjDef.ChildOf) then
                                    begin
                                      MessagePos2(lFilePos,type_e_incompatible_types,lParaObjDef.TypeName,lFormalObjDef.ChildOf.TypeName);
                                      Result:=false;
                                    end;
                                end;
                              odt_class:
                                begin
                                  lObjDef:=lParaObjDef;
                                  lIntfFound:=false;
                                  while Assigned(lObjDef) do
                                    begin
                                      for lInnerIndex:=0 to lObjDef.implementedinterfaces.count-1 do
                                        if TImplementedInterface(lObjDef.implementedinterfaces[lInnerIndex]).intfdef=lFormalObjDef.ChildOf then
                                          begin
                                            lIntfFound:=true;
                                            break;
                                          end;
                                      if lIntfFound then
                                        break;
                                      lObjDef:=lObjDef.ChildOf;
                                    end;
                                  Result:=lIntfFound;
                                  if not Result then
                                    MessagePos2(lFilePos,parser_e_class_doesnt_implement_interface,lParaObjDef.TypeName,lFormalObjDef.ChildOf.TypeName);
                                end;
                              else
                                begin
                                  MessagePos1(lFilePos,type_e_class_or_interface_type_expected,lParaObjDef.TypeName);
                                  Result:=false;
                                end;
                            end;
                          end
                        else
                          begin
                            { this is either a "class" or a concrete instance with
                              or without implemented interfaces }
                            if not (lParaObjDef.ObjectType in [odt_class]) then
                              begin
                                MessagePos1(lFilePos,type_e_class_type_expected,lParaObjDef.TypeName);
                                Result:=false;
                                continue;
                              end;
                            { for forward declared classes we allow pure TObject/class declarations }
                            if (oo_is_forward in lParaObjDef.ObjectOptions) and
                                (df_genconstraint in lFormalDef.DefOptions) then
                              begin
                                if (lFormalObjDef.ChildOf=Class_TObject) and
                                    not lFormalObjDef.Implements_Any_Interfaces then
                                  continue;
                              end;
                            if Assigned(lFormalObjDef.ChildOf) and
                                not Def_Is_Related(lParaDef,lFormalObjDef.ChildOf) then
                              begin
                                MessagePos2(lFilePos,type_e_incompatible_types,lParaObjDef.TypeName,lFormalObjDef.ChildOf.TypeName);
                                Result:=false;
                              end;
                            lIntfCount:=0;
                            for lInnerIndex:=0 to lFormalObjDef.implementedinterfaces.count-1 do
                              begin
                                lObjDef:=lParaObjDef;
                                lIntfFound:=false;
                                while Assigned(lObjDef) do
                                  begin
                                    lIntfFound:=Assigned(
                                                 Find_Implemented_Interface(lObjDef,
                                                   TImplementedInterface(lFormalObjDef.implementedinterfaces[lInnerIndex]).intfdef
                                                 )
                                               );
                                    if lIntfFound then
                                      break;
                                    lObjDef:=lObjDef.ChildOf;
                                  end;
                                if lIntfFound then
                                  inc(lIntfCount)
                                else
                                  MessagePos2(lFilePos,parser_e_class_doesnt_implement_interface,lParaObjDef.TypeName,TImplementedInterface(lFormalObjDef.implementedinterfaces[lInnerIndex]).intfdef.TypeName);
                              end;
                            if lIntfCount<>lFormalObjDef.implementedinterfaces.count then
                              Result:=false;
                          end;
                      end;
                  end;
              end;
          end;
      end;

    function ParseGenericSpecializationTypesInternal(AParamList:TFPObjectList;APosList:TFPList;out APrettyName,ASpecializeName:AnsiString;AParsedType:TDef;AParsedPos:TFilePosInfo):Boolean;
      var
        lOldBlockType : TBlockType;
        lFirst : Boolean;
        lTypeParam : TNode;
        lParamPos : PFilePosInfo;
        lTmpParamPos : TFilePosInfo;
        lNamePart : String;
        lModule : TModule;
        lConstPrettyName : String;
        lValidParam : Boolean;
      begin
        Result:=true;
        APrettyName:='';
        lConstPrettyName:='';
        if AParamList=nil then
          InternalError(2012061401);
        { set the block type to type, so that the parsed type are returned as
          ttypenode (e.g. classes are in non type-compatible blocks returned as
          tloadvmtaddrnode) }
        lOldBlockType:=Block_Type;
        { if parsedtype is set, then the first type identifer was already parsed
          (happens in inline specializations) and thus we only need to parse
          the remaining types and do as if the first one was already given }
        lFirst:=not Assigned(AParsedType);
        if Assigned(AParsedType) then
          begin
            AParamList.Add(AParsedType.TypeSym);
            lModule:=Find_Module_From_SymTable(AParsedType.owner);
            if not Assigned(lModule) then
              InternalError(2016112801);
            lNamePart:='_$'+HexStr(lModule.ModuleID,8)+'$$'+AParsedType.UniqueIDStr;
            ASpecializeName:='$'+lNamePart;
            APrettyName:=AParsedType.FullOwnerHierarchyName(true,true)+AParsedType.TypeSym.prettyname;
            if Assigned(APosList) then
              begin
                New(lParamPos);
                lParamPos^:=AParsedPos;
                APosList.add(lParamPos);
              end;
          end
        else
          ASpecializeName:='$';
        while not (CurrentScanner.FToken in [_GT,_RSHARPBRACKET]) do
          begin
            { "first" is set to false at the end of the loop! }
            if not lFirst then
              Consume(_COMMA);
            Block_Type:=bt_type;
            lTmpParamPos:=CurrentFilePos;
            lTypeParam:=Factor(false,[efAcceptEqual]);
            { determine if the typeparam node is a valid type or const }
            lValidParam:=lTypeParam.nodetype in cGenericParamNodes;
            if lValidParam then
              begin
                if TStoredDef(lTypeParam.resultdef).Is_Generic and
                    not IsOrBelongsToCurrentGenericDef(lTypeParam.resultdef) and
                    (
                      not ParseGeneric or
                      not Defs_Belong_To_Same_Generic(lTypeParam.resultdef,CurrentGenericDef)
                    ) then
                  Message(parser_e_no_generics_as_params);
                if Assigned(APosList) then
                  begin
                    New(lParamPos);
                    lParamPos^:=lTmpParamPos;
                    APosList.add(lParamPos);
                  end;
                if lTypeParam.resultdef.typ<>errordef then
                  begin
                    if (lTypeParam.nodetype=typen) and not Assigned(lTypeParam.resultdef.TypeSym) then
                      message(type_e_generics_cannot_reference_itself)
                    else if (lTypeParam.resultdef.typ<>errordef) then
                      begin
                        { all non-type nodes are considered const }
                        if lTypeParam.nodetype<>typen then
                          AParamList.Add(CreateGenericConstSym(lTypeParam.resultdef,lTypeParam,lConstPrettyName))
                        else
                          begin
                            lConstPrettyName:='';
                            AParamList.Add(lTypeParam.resultdef.TypeSym);
                          end;
                        MakePrettyString(lTypeParam.resultdef,lFirst,lConstPrettyName,APrettyName,ASpecializeName);
                      end;
                  end
                else
                  begin
                    Result:=false;
                  end;
              end
            else
              begin
                Message(type_e_type_id_expected);
                Result:=false;
              end;
            lTypeParam.free;
            lTypeParam := nil;
            lFirst:=false;
          end;
        Block_Type:=lOldBlockType;
      end;


    function ParseGenericSpecializationTypes(AParamList:TFPObjectList;APosList:TFPList;out APrettyName,ASpecializeName:AnsiString):Boolean;
      var
        lDummyPos : TFilePosInfo;
      begin
        FillChar(lDummyPos, SizeOf(TFilePosInfo), 0);
        Result:=ParseGenericSpecializationTypesInternal(AParamList,APosList,APrettyName,ASpecializeName,nil,lDummyPos);
      end;


    procedure GenerateSpecialization(var ADef:TDef;AEnforceUnit:Boolean;AParseClassParent:Boolean;const APrettyName:String;const ASymName:String;ASymTable:TSymTable);
      var
        lContext : TSpecializationContext;
        lGenericDef : TStoredDef;
        lDummyPos : TFilePosInfo;
      begin
        FillChar(lDummyPos, SizeOf(TFilePosInfo), 0);
        lGenericDef:=TStoredDef(GenerateSpecializationPhase1(lContext,ADef,AEnforceUnit,nil,ASymName,ASymTable,lDummyPos));
        if lGenericDef<>GenErrorDef then
          lGenericDef:=TStoredDef(GenerateSpecializationPhase2(lContext,lGenericDef,AParseClassParent,APrettyName));
        ADef:=lGenericDef;
        if Assigned(lContext) then
          lContext.free; // no nil needed
      end;


    function FinalizeSpecialization(var AProcDef:TProcDef;ASpezContext:TSpecializationContext):Boolean;
      var
        lDef : TDef;
      begin
        Result:=false;
        if Assigned(ASpezContext) then
          begin
            if not (df_generic in AProcDef.DefOptions) then
              InternalError(2015060301);
            { check whether the given parameters are compatible
              to the def's constraints }
            if not CheckGenericConstraints(AProcDef,ASpezContext.FParamList,ASpezContext.FPosList) then
              exit;
            lDef:=GenerateSpecializationPhase2(ASpezContext,AProcDef,false,'');
            case lDef.typ of
              errordef:
                { do nothing }
                ;
              procdef:
                AProcDef:=TProcDef(lDef);
              else
                InternalError(2015070303);
            end;
          end;
        Result:=true;
      end;


    procedure TransferUnnamedSymbols(AOwner:TSymTable;AUnnamedSyms:TFPList);
      var
        lIndex : Integer;
        lSym : TSym;
      begin
        for lIndex:=0 to AUnnamedSyms.count-1 do
          begin
            lSym:=TSym(AUnnamedSyms[lIndex]);
            lSym.ChangeOwnerAndName(AOwner,lSym.realname);
          end;
        AUnnamedSyms.clear;
      end;


    function TryImplicitSpecialization(ASym:TSym;APara:TNode;APDOverloadList:TFPObjectList;var AUnnamedSyms:TFPList;var AFirstProcSym:TSym;var AHasOverload:Boolean):Boolean;

      { hash key for generic parameter lookups }
      function GenericParamHash(ADef:TDef):String;inline;
        begin
          Result:=ADef.TypeName;
        end;

      { returns true if the def a literal array such as [1,2,3] and not a shortstring }
      function IsArrayLiteral(ADef:TDef):Boolean;
        begin
          Result:=(ADef.typ=arraydef) and not Is_ConstString_Array(ADef);
        end;

      { makes the specialization context from the generic proc def and generic params }
      procedure GenerateImplicitSpecialization(out AContext:TSpecializationContext;AGenericDef:TProcDef;AGenericParams:TFPHashList);
        var
          lParsedPos:TFilePosInfo;
          lPosList:TFPList;
          lIndex: LongInt;
          lParamType: TTypeSym;
          lParamPos : PFilePosInfo;
          lTmpParamPos : TFilePosInfo;
          lParamName: String;
        begin
          AContext:=TSpecializationContext.Create;
          fillchar(lParsedPos,sizeof(lParsedPos),0);
          lPosList:=AContext.FPosList;
          lTmpParamPos:=CurrentFilePos;
          if AGenericParams.count<>AGenericDef.GenericParas.count then
            InternalError(2021020901);
          lPosList.capacity:=lPosList.count+AGenericParams.count;
          AContext.FParamList.capacity:=AContext.FParamList.count+AGenericParams.count;
          for lIndex:=0 to AGenericParams.count-1 do
            begin
              lParamName:=GenericParamHash(TTypeSym(AGenericDef.GenericParas[lIndex]).TypeDef);
              lParamType:=TTypeSym(AGenericParams.find(lParamName));
              if not Assigned(lParamType) then
                InternalError(2021020902);
              new(lParamPos);
              lParamPos^:=lTmpParamPos;
              lPosList.add(lParamPos);
              AContext.FParamList.Add(lParamType);
              MakePrettyString(lParamType.TypeDef,lIndex=0,'',AContext.FPrettyName,AContext.FSpecializeName);
            end;
          AContext.FGenName:=AGenericDef.ProcSym.realname;
        end;

      { specialization context parameter lists require a typesym so we need
        to generate a placeholder for unnamed constant types like
        short strings, open arrays, function pointers etc... }
      function CreateUnnamedTypeSym(ADef:TDef):TSym;
        var
          lNewType: TSym;
        begin
          lNewType:=nil;
          if Is_ConstString_Array(ADef) then
            begin
              { for constant strings we need to respect various modeswitches }
              if (cs_refcountedstrings in CurrentSettings.LocalSwitches) then
                begin
                  if m_default_unicodestring in CurrentSettings.ModeSwitches then
                    lNewType:=CUnicodeStringType.TypeSym
                  else
                    lNewType:=CAnsiStringType.TypeSym;
                end
              else
                lNewType:=CShortStringType.TypeSym;
            end
          else if ADef.typ=stringdef then
            lNewType:=TStringDef(ADef).Get_Default_String_Type.TypeSym
          else
            begin
              if Is_Array_Constructor(ADef) then
                begin
                  { array constructor is not a valid parameter type; getreusable
                    avoids creating multiple implementations for calls with the
                    same number of array elements of a particular type }
                  ADef:=CArrayDef.getreusable(TArrayDef(ADef).ElementDef,TArrayDef(ADef).HighRange-TArrayDef(ADef).LowRange+1);
                end;
              lNewType:=CTypeSym.Create(ADef.FullOwnerHierarchyName(false,true)+TypName[ADef.typ]+'$'+ADef.UniqueIDStr,ADef);
              include(lNewType.SymOptions,sp_generic_unnamed_type);
              lNewType.owner:=ADef.owner;
              { ensure that there's no warning }
              lNewType.refs:=1;
            end;
          if not Assigned(lNewType) then
            InternalError(2021020904);
          Result:=lNewType;
        end;

      { searches for the generic param in specializations }
      function FindParamInSpecialization(AOwner:TProcDef;AGenericParam:TTypeSym;ADef:TStoredDef):Boolean;
        var
          lParaSym: TTypeSym;
          lIndex: Integer;
        begin
          Result:=false;
          for lIndex:=0 to ADef.GenericParas.count-1 do
            begin
              lParaSym:=TTypeSym(ADef.GenericParas[lIndex]);
              { the generic param must have a named typesym }
              if not Assigned(lParaSym.TypeDef.TypeSym) then
                InternalError(2021020907);
              { recurse into inline specialization }
              if TStoredDef(lParaSym.TypeDef).Is_Specialization then
                begin
                  Result:=FindParamInSpecialization(AOwner,AGenericParam,TStoredDef(lParaSym.TypeDef));
                  if Result then
                    exit;
                end
              else if (AGenericParam=lParaSym.TypeDef.TypeSym) and AOwner.Is_Generic_Param(lParaSym.TypeDef) then
                exit(true);
            end;
        end;

      { searches for the generic param in arrays }
      function FindParamInArray(AOwner:TProcDef;AGenericParam:TTypeSym;ADef:TArrayDef):Boolean;
        var
          lElementDef:TStoredDef;
        begin
          lElementDef:=TStoredDef(ADef.ElementDef);
          { recurse into multi-dimensional array }
          if lElementDef.typ=arraydef then
            Result:=FindParamInArray(AOwner,AGenericParam,TArrayDef(lElementDef))
          { something went wrong during parsing and the element is invalid }
          else if lElementDef.typ=errordef then
            Result:=false
          else
            begin
              { the element must have a named typesym }
              if not Assigned(lElementDef.TypeSym) then
                InternalError(2021020906);
              Result:=(AGenericParam=lElementDef.TypeSym) and AOwner.Is_Generic_Param(lElementDef);
            end;
        end;

      { tests if the generic param is used in the parameter list }
      function IsGenericParamUsed(AOwner:TProcDef;AGenericParam:TTypeSym;AParas:TFPList):Boolean;
        var
          lParaVar:TParaVarSym;
          lIndex: Integer;
        begin
          Result:=false;
          for lIndex:=0 to AParas.count-1 do
            begin
              lParaVar:=TParaVarSym(AParas[lIndex]);

              { handle array types by using element types (for example: array of T) }
              if lParaVar.vardef.typ=arraydef then
                Result:=FindParamInArray(AOwner,AGenericParam,TArrayDef(lParaVar.vardef))
              { for specializations check search in generic params }
              else if TStoredDef(lParaVar.vardef).Is_Specialization then
                Result:=FindParamInSpecialization(AOwner,AGenericParam,TStoredDef(lParaVar.vardef))
              { something went wrong during parsing and the parameter is invalid }
              else if lParaVar.vardef.typ=errordef then
                exit(false)
              else
                begin
                  if not Assigned(lParaVar.vardef.TypeSym) then
                    InternalError(2021020905);
                  Result:=(AGenericParam=lParaVar.vardef.TypeSym) and AOwner.Is_Generic_Param(lParaVar.vardef)
                end;

              { exit if we find a used parameter }
              if Result then
                exit;
            end;
        end;

      { handle generic specializations by using generic params from caller
        to specialize the target. for example "TRec<Integer>" can use "Integer"
        to specialize "TRec<T>" with "Integer" for "T". }
      procedure HandleSpecializations(AGenericParams:TFPHashList;ATargetDef,ACallerDef:TStoredDef);
        var
          lIndex,
          lLookupIndex : Integer;
          lKey : String;
          lTargetParam,
          lCallerParam : TTypeSym;
        begin
          { the target and the caller must the same generic def
            with the same set of generic parameters }
          if ATargetDef.GenericDef<>ACallerDef.GenericDef then
            InternalError(2021020909);

          for lIndex:=0 to ATargetDef.GenericParas.count-1 do
            begin
              lTargetParam:=TTypeSym(ATargetDef.GenericParas[lIndex]);
              lCallerParam:=TTypeSym(ACallerDef.GenericParas[lIndex]);

              { reject generics with constants }
              if (lTargetParam.typ=constsym) or (lCallerParam.typ=constsym) then
                exit;

              lKey:=GenericParamHash(lTargetParam.TypeDef);

              { the generic param is already used }
              lLookupIndex:=AGenericParams.findindexof(lKey);
              if lLookupIndex>=0 then
                continue;

              { add the type to the generic params }
              AGenericParams.add(lKey,lCallerParam);
            end;
        end;

      { specialize arrays by using element types but arrays may be multi-dimensional
        so we need to examine the caller/target pairs recursively in order to
        verify the dimensionality is equal }
      function HandleArrays(AOwner:TProcDef;ATargetDef,ACallerDef:TArrayDef;out ATargetElement,ACallerElement:TDef):Boolean;
        begin
          { the target and the caller are both arrays and the target is a
            specialization so we can recurse into the targets element def }
          if IsArrayLiteral(ATargetDef.ElementDef) and
            IsArrayLiteral(ACallerDef.ElementDef) and
            ATargetDef.Is_Specialization then
            Result:=HandleArrays(AOwner,TArrayDef(ATargetDef.ElementDef),TArrayDef(ACallerDef.ElementDef),ATargetElement,ACallerElement)
          else
            begin
              { the caller is an array which means the dimensionality is unbalanced
                and thus the arrays are compatible }
              if IsArrayLiteral(ACallerDef.ElementDef) then
                exit(false);
              { if the element is a generic param then return this type
                along with the caller element type at the same level }
              Result:=AOwner.Is_Generic_Param(ATargetDef.ElementDef);
              if Result then
                begin
                  ATargetElement:=ATargetDef.ElementDef;
                  ACallerElement:=ACallerDef.ElementDef;
                end;
            end;
        end;

      { handle procvars by using the parameters from the caller to specialize
        the parameters of the target generic procedure specialization. for example:

          type generic TProc<S> = procedure(value: S);
          generic procedure Run<T>(proc: specialize TProc<T>);
          procedure DoCallback(value: integer);
          Run(@DoCallback);

        will specialize as Run<integer> because the signature
        of DoCallback() matches TProc<S> so we can specialize "S"
        with "integer", as they are both parameter #1
      }

      function HandleProcVars(AGenericParams:TFPHashList;ACallerParams:TFPList;ATargetDef:TDef;ACallerDef:TDef):Boolean;
        var
          lNewParams : TFPHashList;

        procedure HandleGenericParam(ATargetParaDef,ACallerParaDef:TDef);
          var
            lKey : String;
            lLookupIndex : Integer;
          begin
            if not Assigned(ACallerParaDef.TypeSym) then
              InternalError(2021020908);

            lKey:=GenericParamHash(ATargetParaDef);

            { the generic param must not already be used }
            lLookupIndex:=AGenericParams.findindexof(lKey);
            if lLookupIndex<0 then
              begin
                { add the type to the list }
                lLookupIndex:=lNewParams.findindexof(lKey);
                if lLookupIndex<0 then
                  lNewParams.add(lKey,ACallerParaDef.TypeSym);
              end;
          end;

        var
          lIndex,lInnerIndex : Integer;
          lParaVar : TParaVarSym;
          lTargetProc,
          lCallerProc : TProcVarDef;
          lTargetProcPara,
          lCallerProcPara : TParaVarSym;
          lValidParams : Integer;
        begin
          Result := false;

          lTargetProc:=TProcVarDef(ATargetDef);
          lCallerProc:=TProcVarDef(ACallerDef);

          { parameter count must match exactly
            currently default values are not considered }
          if lTargetProc.paras.count<>lCallerProc.paras.count then
            exit;

          { a mixture of functions and procedures is not allowed }
          if (not Assigned(lTargetProc.ReturnDef) or Is_Void(lTargetProc.ReturnDef)) xor
              (not Assigned(lCallerProc.ReturnDef) or Is_Void(lCallerProc.ReturnDef)) then
            exit;

          { reject generics with constants }
          for lIndex:=0 to lTargetProc.GenericDef.GenericParas.count-1 do
            if TSym(lTargetProc.GenericDef.GenericParas[lIndex]).typ=constsym then
              exit;

          lNewParams:=TFPHashList.Create;
          lValidParams:=0;

          for lIndex:=0 to lTargetProc.paras.count-1 do
            begin
              lTargetProcPara:=TParaVarSym(lTargetProc.paras[lIndex]);
              lCallerProcPara:=TParaVarSym(lCallerProc.paras[lIndex]);

              { the parameters are not compatible }
              if Compare_Defs(lCallerProcPara.vardef,lTargetProcPara.vardef,nothingn)=te_incompatible then
                begin
                  lNewParams.free;
                  lNewParams := nil;
                  exit(false);
                end;

              if sp_generic_para in lTargetProcPara.vardef.TypeSym.SymOptions then
                begin
                  lParaVar:=TParaVarSym(TProcVarDef(lTargetProc.GenericDef).paras[lIndex]);

                  { find the generic param name in the generic def parameters }
                  lInnerIndex:=lTargetProc.GenericDef.GenericParas.findindexof(lParaVar.vardef.TypeSym.name);

                  HandleGenericParam(TTypeSym(lTargetProc.GenericParas[lInnerIndex]).TypeDef,lCallerProcPara.vardef);
                end;

              inc(lValidParams);
            end;

          if Assigned(lTargetProc.ReturnDef) and not Is_Void(lTargetProc.ReturnDef) then
            begin
              { or check for exact? }
              if Compare_Defs(lCallerProc.ReturnDef,lTargetProc.ReturnDef,nothingn)<te_equal then
                begin
                  lNewParams.free;
                  lNewParams := nil;
                  exit(false);
                end;

              if sp_generic_para in lTargetProc.ReturnDef.TypeSym.SymOptions then
                begin
                  HandleGenericParam(lTargetProc.ReturnDef,lCallerProc.ReturnDef);
                end;
            end;

          { if the count of valid params matches the target then
            transfer the temporary params to the actual params }
          Result:=lValidParams=lTargetProc.paras.count;
          if Result then
            for lIndex := 0 to lNewParams.count-1 do
              AGenericParams.add(lNewParams.nameofindex(lIndex),lNewParams[lIndex]);

          lNewParams.free;
          lNewParams := nil;
        end;

      function MaybeInheritedSpecialization(AGivenDef,ADesiredDef:TStoredDef;out ABaseDef:TStoredDef):Boolean;
        begin
          Result:=false;
          ABaseDef:=nil;
          if AGivenDef.typ<>objectdef then
            begin
              Result:=AGivenDef.Is_Specialization and (AGivenDef.GenericDef=ADesiredDef.GenericDef);
              if Result then
                ABaseDef:=AGivenDef;
            end
          else
            begin
              while Assigned(AGivenDef) do
                begin
                  if AGivenDef.Is_Specialization and (AGivenDef.GenericDef=ADesiredDef.GenericDef) then
                    begin
                      ABaseDef:=AGivenDef;
                      Result:=true;
                      break;
                    end;

                  AGivenDef:=TObjectDef(AGivenDef).ChildOf;
                end;
            end;
        end;

      { compare generic parameters <T> with call node parameters. }
      function IsPossibleSpecialization(ACallerParams:TFPList;AGenericDef:TProcDef;out AUnnamedSyms:TFPList;out AGenericParams:TFPHashList):Boolean;
        var
          lIndex,
          lCount : Integer;
          lParaVar : TParaVarSym;
          lBaseDef : TStoredDef;
          lTargetDef,
          lCallerDef : TDef;
          lTargetKey : String;
          lLookupIndex : Integer;
          lParas : TFPList;
          lTargetElement,
          lCallerElement : TDef;
          lRequiredParamCount : Integer;
        begin
          Result:=false;
          lParas:=nil;
          AGenericParams:=nil;
          lRequiredParamCount:=0;
          AUnnamedSyms:=nil;

          { first perform a check to reject generics with constants }
          for lIndex:=0 to AGenericDef.GenericParas.count-1 do
            if TSym(AGenericDef.GenericParas[lIndex]).typ=constsym then
              exit;

          { build list of visible target function parameters }
          lParas:=TFPList.Create;
          for lIndex:=0 to AGenericDef.paras.count-1 do
            begin
              lParaVar:=TParaVarSym(AGenericDef.paras[lIndex]);
              { ignore hidden parameters }
              if vo_is_hidden_para in lParaVar.VarOptions then
                continue;
              lParas.add(lParaVar);

              { const non-default parameters are required }
              if not Assigned(lParaVar.DefaultConstSym) then
                inc(lRequiredParamCount);
            end;

          { not enough parameters were supplied }
          if ACallerParams.count<lRequiredParamCount then
            begin
              lParas.free;
              lParas := nil;
              exit;
            end;

          { check to make sure the generic parameters are all used
            at least once in the  caller parameters. }
          lCount:=0;
          for lIndex:=0 to AGenericDef.GenericParas.count-1 do
            if IsGenericParamUsed(AGenericDef,TTypeSym(AGenericDef.GenericParas[lIndex]),lParas) then
              inc(lCount);

          if lCount<AGenericDef.GenericParas.count then
            begin
              lParas.free;
              lParas := nil;
              exit;
            end;

          AGenericParams:=TFPHashList.Create;
          for lIndex:=0 to ACallerParams.count-1 do
            begin
              lCallerDef:=TTypeSym(ACallerParams[lIndex]).TypeDef;

              { caller parameter exceeded the possible parameters }
              if lIndex=lParas.count then
                begin
                  AGenericParams.free;
                  AGenericParams := nil;
                  lParas.free;
                  lParas := nil;
                  exit;
                end;

              lTargetDef:=TParaVarSym(lParas[lIndex]).vardef;
              lTargetKey:='';

              { strings are compatible with "array of T" so we
                need to use the element type for specialization }
              if Is_StringLike(lCallerDef) and
                IsArrayLiteral(lTargetDef) and
                AGenericDef.Is_Generic_Param(TArrayDef(lTargetDef).ElementDef) then
                begin
                  lTargetDef:=TArrayDef(lTargetDef).ElementDef;
                  lTargetKey:=GenericParamHash(lTargetDef);
                  lCallerDef:=CharType_For_StringLike(lCallerDef);
                end
              { non-uniform array constructors (i.e. array of const) are not compatible
                with normal arrays like "array of T" so we reject them }
              else if IsArrayLiteral(lTargetDef) and
                (lCallerDef.typ=arraydef) and
                (ado_IsConstructor in TArrayDef(lCallerDef).ArrayOptions) and
                (ado_IsArrayOfConst in TArrayDef(lCallerDef).ArrayOptions) then
                begin
                  continue;
                end
              { handle generic arrays }
              else if IsArrayLiteral(lCallerDef) and
                IsArrayLiteral(lTargetDef) and
                HandleArrays(AGenericDef,TArrayDef(lTargetDef),TArrayDef(lCallerDef),lTargetElement,lCallerElement) then
                begin
                  lTargetDef:=lTargetElement;
                  lCallerDef:=lCallerElement;
                  lTargetKey:=GenericParamHash(lTargetDef);
                end
              { handle generic procvars }
              else if (lCallerDef.typ=procvardef) and
                (lTargetDef.typ=procvardef) and
                TProcVarDef(lTargetDef).Is_Specialization and
                HandleProcVars(AGenericParams,ACallerParams,lTargetDef,lCallerDef) then
                begin
                  continue;
                end
              { handle specialized objects by taking the base class as the type to specialize }
              else if Is_Class_Or_Object(lCallerDef) and
                Is_Class_Or_Object(lTargetDef) and
                AGenericDef.Is_Generic_Param(lTargetDef) then
                begin
                  lTargetKey:=GenericParamHash(lTargetDef);
                  lTargetDef:=TObjectDef(lTargetDef).ChildOf;
                end
              { handle generic specializations }
              else if TStoredDef(lTargetDef).Is_Specialization and
                MaybeInheritedSpecialization(TStoredDef(lCallerDef),TStoredDef(lTargetDef),lBaseDef) then
                begin
                  HandleSpecializations(AGenericParams,TStoredDef(lTargetDef),lBaseDef);
                  continue;
                end
              { handle all other generic params }
              else if lTargetDef.typ=undefineddef then
                lTargetKey:=GenericParamHash(lTargetDef);

              { the param doesn't have a generic key which means we don't need to consider it }
              if lTargetKey='' then
                continue;

              { the generic param is already used }
              lLookupIndex:=AGenericParams.findindexof(lTargetKey);
              if lLookupIndex>=0 then
                continue;

              { the caller type may not have a typesym so we need to create an unnamed one }
              if not Assigned(lCallerDef.TypeSym) then
                begin
                  ASym:=CreateUnnamedTypeSym(lCallerDef);
                  { add the unnamed sym to the list but only it was allocated manually }
                  if ASym.owner=lCallerDef.owner then
                    TFPList.AddOnDemand(AUnnamedSyms,ASym);
                  AGenericParams.add(lTargetKey,ASym);
                end
              else
                AGenericParams.add(lTargetKey,lCallerDef.TypeSym);
            end;

          { if the parameter counts match then the specialization is possible }
          Result:=AGenericParams.count=AGenericDef.GenericParas.count;

          { cleanup }
          lParas.free;
          lParas := nil;
          if not Result then begin
            AGenericParams.free;
            AGenericParams := nil;
          end;
        end;

      { make an ordered list of parameters from the caller }
      function MakeParamList(ADummySym:TSym;APara:TNode;var AUnnamedSyms:TFPList):TFPList;
        var
          lParaNode : TCallParaNode;
          lParaDef : TDef;
          lSym : TSym;
        begin
          Result:=TFPList.Create;
          lParaNode:=TCallParaNode(APara);
          while Assigned(lParaNode) do
            begin
              lParaDef:=lParaNode.ParaValue.resultdef;
              { unnamed parameter types can not be specialized }
              if not Assigned(lParaDef.TypeSym) then
                begin
                  lSym:=CreateUnnamedTypeSym(lParaDef);
                  Result.insert(0,lSym);
                  { add the unnamed sym to the list but only if it was allocated manually }
                  if lSym.owner=lParaDef.owner then
                    TFPList.AddOnDemand(AUnnamedSyms,lSym);
                end
              else
                Result.insert(0,lParaDef.TypeSym);
              lParaNode:=TCallParaNode(lParaNode.NextPara);
            end;
        end;

      var
        lIndex,lInnerIndex,lThirdIndex : Integer;
        lSearchSym : TProcSym;
        lCallerParams : TFPList;
        lProcDef : TProcDef;
        lDummySym : TProcSym;
        lGenericParams : TFPHashList;
        lSpezContext : TSpecializationContext;
        lPDUnnamedSyms : TFPList;
      begin
        Result:=false;
        lSpezContext:=nil;
        lGenericParams:=nil;
        lDummySym:=TProcSym(ASym);
        lCallerParams:=MakeParamList(lDummySym,APara,AUnnamedSyms);

        { failed to build the parameter list }
        if not Assigned(lCallerParams) then
          exit;

        for lIndex:=0 to lDummySym.GenProcSymOvlds.count-1 do
          begin
            lSearchSym:=TProcSym(lDummySym.GenProcSymOvlds[lIndex]);
            for lInnerIndex:=0 to lSearchSym.ProcdefList.Count-1 do
              begin
                lProcDef:=TProcDef(lSearchSym.ProcdefList[lInnerIndex]);
                if IsPossibleSpecialization(lCallerParams,lProcDef,lPDUnnamedSyms,lGenericParams) then
                  begin
                    GenerateImplicitSpecialization(lSpezContext,lProcDef,lGenericParams);
                    lGenericParams.free;
                    lGenericParams := nil;
                    { finalize the specialization so it can be added to the list of overloads }
                    if not FinalizeSpecialization(lProcDef,lSpezContext) then
                      begin
                        lSpezContext.free;
                        lSpezContext := nil;
                        continue;
                      end;
                    { handle unnamed syms used by the specialization }
                    if lPDUnnamedSyms<>nil then
                      begin
                        TransferUnnamedSymbols(lProcDef.owner,lPDUnnamedSyms);
                        lPDUnnamedSyms.free;
                        lPDUnnamedSyms := nil;
                      end;
                    APDOverloadList.add(lProcDef);
                    lSpezContext.free;
                    lSpezContext := nil;
                    if po_overload in lProcDef.ProcOptions then
                      AHasOverload:=true;
                    { store first procsym found }
                    if not Assigned(AFirstProcSym) then
                      AFirstProcSym:=lSearchSym;
                    Result:=true;
                  end
                else
                  begin
                    { the specialization was not chosen so clean up any unnamed syms }
                    TFPList.FreeAndNilObjects(lPDUnnamedSyms);
                  end;
              end;
          end;

        { unlink unused defs }
        if not(Result) and Assigned(lCallerParams) then
          begin
            for lThirdIndex:=0 to lCallerParams.count-1 do
              begin
                if (TSym(lCallerParams[lThirdIndex]).typ=TypeSym) and (sp_generic_unnamed_type in TTypeSym(lCallerParams[lThirdIndex]).SymOptions) then
                  TTypeSym(lCallerParams[lThirdIndex]).TypeDef.TypeSym:=nil;
              end;
          end;

        lCallerParams.free;
        lCallerParams := nil;
      end;

    function GenerateSpecializationPhase1(out AContext:TSpecializationContext;AGenericDef:TDef;AEnforceUnit:Boolean):TDef;
      var
        lDummyPos : TFilePosInfo;
{$push}
{$warn 5036 off}
      begin
        Result:=GenerateSpecializationPhase1(AContext,AGenericDef,AEnforceUnit,nil,'',nil,lDummyPos);
      end;
{$pop}


    function GenerateSpecializationPhase1(out AContext:TSpecializationContext;AGenericDef:TDef;AEnforceUnit:Boolean;const ASymName:String;ASymTable:TSymTable):TDef;
      var
        lDummyPos : TFilePosInfo;
{$push}
{$warn 5036 off}
      begin
        Result:=GenerateSpecializationPhase1(AContext,AGenericDef,AEnforceUnit,nil,ASymName,ASymTable,lDummyPos);
      end;
{$pop}


    function GenerateSpecializationPhase1(out AContext:TSpecializationContext;AGenericDef:TDef;AEnforceUnit:Boolean;AParsedType:TDef;const ASymName:String;ASymTable:TSymTable;AParsedPos:TFilePosInfo):TDef;
      var
        lFound,
        lErr : Boolean;
        lIndex,
        lGenCount : LongInt;
        lCountStr,lGenName,lUGenName,lPrettyGenName: String;
        lTmpStack : TFPObjectList;
        lSymOwner : TSymTable;
        lModule : TModule;
      begin
        AContext:=nil;
        Result:=nil;

        { either symname must be given or genericdef needs to be valid }
        if (ASymName='') and
            (not Assigned(AGenericDef) or
              (
                (AGenericDef.typ<>procdef) and
                (
                  not Assigned(AGenericDef.TypeSym) or
                  (AGenericDef.TypeSym.typ<>TypeSym)
                ) and
                (
                  (AGenericDef.typ<>objectdef) or
                  not (oo_is_forward in TObjectDef(AGenericDef).ObjectOptions)
                )
              ) or
              (
                (AGenericDef.typ=procdef) and
                (
                  not Assigned(TProcDef(AGenericDef).ProcSym) or
                  (TProcDef(AGenericDef).ProcSym.typ<>ProcSym)
                )
              )
            ) then
          begin
            InternalError(2019112401);
          end;

        if not Assigned(AParsedType) and not TryToConsume(_LT) then
          begin
            Consume(_LSHARPBRACKET);
            { handle "<>" }
            if (CurrentScanner.FToken=_GT) or (CurrentScanner.FToken=_RSHARPBRACKET) then
              begin
                Message(type_e_type_id_expected);
                if not TryToConsume(_GT) then
                  TryToConsume(_RSHARPBRACKET);
                Result:=GenErrorDef;
                exit;
              end;
          end;

        AContext:=TSpecializationContext.Create;

        { Parse type parameters }
        lErr:=not ParseGenericSpecializationTypesInternal(AContext.FParamList,AContext.FPosList,AContext.FPrettyName,AContext.FSpecializeName,AParsedType,AParsedPos);
        if lErr then
          begin
            if not TryToConsume(_GT) then
              TryToConsume(_RSHARPBRACKET);
            AContext.free;
            AContext:=nil;
            Result:=GenErrorDef;
            exit;
          end;

        { use the name of the symbol as procvars return a user friendly version
          of the name }
        if ASymName='' then
          begin
            if AGenericDef.typ=procdef then
              lGenName:=TProcDef(AGenericDef).ProcSym.realname
            else if Assigned(AGenericDef.TypeSym) then
              lGenName:=TTypeSym(AGenericDef.TypeSym).realname
            else if (AGenericDef.typ=objectdef) and (oo_is_forward in TObjectDef(AGenericDef).ObjectOptions) then
              lGenName:=TObjectDef(AGenericDef).ObjRealName^
            else
              InternalError(2020071201);
          end
        else
          lGenName:=ASymName;

        { in case of non-Delphi mode the type name could already be a generic
          def (but maybe the wrong one) }
        if Assigned(AGenericDef) and
            ([df_generic,df_specialization]*AGenericDef.DefOptions<>[]) then
          begin
            { remove the type count suffix from the generic's name }
            for lIndex:=Length(lGenName) downto 1 do
              if lGenName[lIndex]='$' then
                begin
                  lGenName:=copy(lGenName,1,lIndex-1);
                  break;
                end;
            { in case of a specialization we've only reached the specialization
              checksum yet }
            if df_specialization in AGenericDef.DefOptions then
              for lIndex:=length(lGenName) downto 1 do
                if lGenName[lIndex]='$' then
                  begin
                    lGenName:=copy(lGenName,1,lIndex-1);
                    break;
                  end;
          end
        else
          begin
            SplitGenericName(lGenName,lUGenName,lGenCount);
            if lGenName<>lUGenName then
              lGenName:=lUGenName;
          end;

        { search a generic with the given count of params }
        lCountStr:='';
        str(AContext.FParamList.Count,lCountStr);

        lPrettyGenName:=lGenName;
        lGenName:=lGenName+'$'+lCountStr;
        lUGenName:=upper(lGenName);

        AContext.FGenName:=lGenName;

        if Assigned(AGenericDef) then
          lSymOwner:=AGenericDef.owner
        else
          lSymOwner:=ASymTable;

        if Assigned(lSymOwner) and (lSymOwner.SymTableType in [objectsymtable,recordsymtable]) then
          begin
            if lSymOwner.SymTableType = objectsymtable then
              lFound:=SearchSym_In_Class(TObjectDef(lSymOwner.DefOwner),TObjectDef(lSymOwner.DefOwner),lUGenName,AContext.FSym,AContext.FSymTable,[])
            else
              lFound:=SearchSym_In_Record(TAbstractRecordDef(lSymOwner.DefOwner),lUGenName,AContext.FSym,AContext.FSymTable);
            if not lFound then
              lFound:=SearchSym(lUGenName,AContext.FSym,AContext.FSymTable);
          end
        else if AEnforceUnit then
          begin
            if not Assigned(lSymOwner) then
              InternalError(2022102101);
            if not (lSymOwner.SymTableType in [GlobalSymTable,staticsymtable]) then
              InternalError(2022102102);
            lModule:=Find_Module_From_SymTable(lSymOwner);
            if not Assigned(lModule) then
              InternalError(2022102103);
            lFound:=SearchSym_In_Module(lModule,lUGenName,AContext.FSym,AContext.FSymTable);
          end
        else
          lFound:=SearchSym(lUGenName,AContext.FSym,AContext.FSymTable);

        if lFound and (AContext.FSym.typ=absolutevarsym) and
            (vo_is_funcret in TAbstractVarSym(AContext.FSym).VarOptions) then
          begin
            { we found the function result alias of a generic function; go up the
              symbol stack *before* this alias was inserted, so that we can
              (hopefully) find the correct generic symbol }
            lTmpStack:=TFPObjectList.Create(false);
            while Assigned(SymTableStack.top) do
              begin
                lTmpStack.Add(SymTableStack.top);
                SymTableStack.pop(SymTableStack.top);
                if lTmpStack.Last=AContext.FSymTable then
                  break;
              end;
            if not Assigned(SymTableStack.top) then
              InternalError(2019123001);
            lFound:=SearchSym(lUGenName,AContext.FSym,AContext.FSymTable);
            for lIndex:=lTmpStack.count-1 downto 0 do
              SymTableStack.push(TSymTable(lTmpStack[lIndex]));
            lTmpStack.free;
            lTmpStack := nil;
          end;

        if not lFound or not (AContext.FSym.typ in [TypeSym,ProcSym]) then
          begin
            IdentifierNotFound(lPrettyGenName);
            if not TryToConsume(_GT) then
              TryToConsume(_RSHARPBRACKET);
            AContext.free;
            AContext:=nil;
            Result:=GenErrorDef;
            exit;
          end;

        { we've found the correct def }
        if AContext.FSym.typ=TypeSym then
          Result:=TStoredDef(TTypeSym(AContext.FSym).TypeDef)
        else
          begin
            if TProcSym(AContext.FSym).procdeflist.count=0 then
              InternalError(2015061203);
            Result:=TStoredDef(TProcSym(AContext.FSym).procdefList[0]);
          end;

        if not TryToConsume(_GT) then
          Consume(_RSHARPBRACKET);
      end;

    function GenerateSpecializationPhase2(AContext:TSpecializationContext;AGenericDef:TStoredDef;AParseClassParent:Boolean;const APrettyName:AnsiString):TDef;

        procedure UnsetForwardDef(ADef: TDef);
          var
            lSymTable : TSymTable;
            lIndex : LongInt;
          begin
            case ADef.typ of
              procdef:
                TProcDef(ADef).ForwardDef:=false;
              objectdef,
              recorddef:
                begin
                  lSymTable:=ADef.GetSymTable(gs_record);
                  for lIndex:=0 to lSymTable.DefList.count-1 do
                    UnsetForwardDef(TDef(lSymTable.DefList[lIndex]));
                end;
              else
                ;
            end;
          end;

        procedure RetrieveGenericDefOrProcSym(ASym:TSym;out AGenDef:TDef;out APSym:TSym);
          var
            lIndex : LongInt;
          begin
            AGenDef:=nil;
            APSym:=nil;
            case ASym.typ of
              TypeSym:
                begin
                  AGenDef:=TTypeSym(ASym).TypeDef
                end;
              ProcSym:
                begin
                  for lIndex:=0 to TProcSym(ASym).procdeflist.count-1 do
                    if TStoredDef(TProcSym(ASym).procdeflist[lIndex]).GenericDef=AGenericDef then
                      begin
                        AGenDef:=TDef(TProcSym(ASym).procdeflist[lIndex]);
                        break;
                      end;
                  APSym:=ASym;
                end
              else
                InternalError(200710171);
            end;
          end;

        function FindInHierarchy(ADef:TDef;AGenericTypeList:TFPHashObjectList):TDef;
          var
            lParamDef1,
            lParamDef2 : TDef;
            lAllEqual : Boolean;
            lIndex : LongInt;
          begin
            Result:=nil;
            while Assigned(ADef) do
              begin
                if (df_generic in ADef.DefOptions) and (ADef=AGenericDef) then
                  begin
                    Result:=ADef;
                    break;
                  end;
                { the following happens when a routine with its parent struct
                  as parameter is specialized as a parameter or result of a
                  generic function }
                if (df_specialization in ADef.DefOptions) and (TStoredDef(ADef).GenericDef=AGenericDef) then
                  begin
                    if TStoredDef(ADef).GenericParas.count=AGenericTypeList.count then
                      begin
                        lAllEqual:=true;
                        for lIndex:=0 to AGenericTypeList.count-1 do
                          begin
                            if TSym(AGenericTypeList[lIndex]).typ<>TSym(TStoredDef(ADef).GenericParas[lIndex]).typ then
                              begin
                                lAllEqual:=false;
                                break;
                              end;
                            if TSym(AGenericTypeList[lIndex]).typ=constsym then
                              lParamDef1:=TConstSym(AGenericTypeList[lIndex]).ConstDef
                            else
                              lParamDef1:=TTypeSym(AGenericTypeList[lIndex]).TypeDef;
                            if TSym(TStoredDef(ADef).GenericParas[lIndex]).typ=constsym then
                              lParamDef2:=TConstSym(TStoredDef(ADef).GenericParas[lIndex]).ConstDef
                            else
                              lParamDef2:=TTypeSym(TStoredDef(ADef).GenericParas[lIndex]).TypeDef;
                            if not Equal_Defs(lParamDef1,lParamDef2) then
                              begin
                                lAllEqual:=false;
                                break;
                              end;
                            if (TSym(AGenericTypeList[lIndex]).typ=constsym) and
                                (
                                  (TConstSym(AGenericTypeList[lIndex]).ConstTyp<>TConstSym(TStoredDef(ADef).GenericParas[lIndex]).ConstTyp) or
                                  not Same_ConstValue(TConstSym(AGenericTypeList[lIndex]).ConstTyp,TConstSym(AGenericTypeList[lIndex]).Value,TConstSym(TStoredDef(ADef).GenericParas[lIndex]).Value)
                                ) then
                                begin
                                  lAllEqual:=false;
                                  break;
                                end;
                          end;
                        if lAllEqual then
                          begin
                            Result:=ADef;
                            break;
                          end;
                      end;
                  end;
                if Assigned(ADef.owner) then
                  ADef:=TStoredDef(ADef.owner.DefOwner)
                else
                  ADef:=nil;
              end;
          end;

      function HasGenericParas(ADef: TStoredDef): Boolean;
        var
          lIndex: Integer;
        begin
          Result:=False;
          if ADef.GenericParas<>nil then
            for lIndex:=0 to ADef.GenericParas.Count-1 do
              if ((TSym(ADef.GenericParas[lIndex]).typ=TypeSym) and (sp_generic_para in TSym(ADef.GenericParas[lIndex]).SymOptions)) or
                  ((TSym(ADef.GenericParas[lIndex]).typ=constsym) and not (sp_generic_const in TSym(ADef.GenericParas[lIndex]).SymOptions)) then
                exit(true);
        end;

      var
        lFinalSpecializeName,
        lUFinalSpecializeName : TIDString;
        lHierarchy,
        lPrettyName : AnsiString;
        lGenericTypeList : TFPHashObjectList;
        lSearchSymTable,
        lSpecializeSymTable : TSymTable;
        lHashedID : THashedIDString;
        lTempSymTable : TGlobalSymTable;
        lTypeSym : TTypeSym;
        lPSym,
        lSearchSym : TSym;
        lFlags : THCCFlags;
        lDef : TDef;
        lOldBlockType : TBlockType;
        lState : TSpecializationState;
        lOldCurrentStructDef : TAbstractRecordDef;
        lOldCurrentSpecializeDef,
        lOldCurrentGenericDef : TStoredDef;
        lOldCurrentProcInfo : TProcInfo;
        lOldModuleProcInfo : TObject;
        lModule : TModule;
        lOldCurrentFilePos : TFilePosInfo;
        lRecordBuf : TDynamicArray;
        lHadTypeToken : Boolean;
        lIndex,
        lReplayDepth : LongInt;
        lFoundDef : TDef;
        lItem : TObject;
        lHintsProcessed : Boolean;
        lProcDef : TProcDef;
        lPDFlags : TPDFlags;
        lPPFlags : TParseProcFlags;
      begin
        if not Assigned(AContext) then
          InternalError(2015052203);

        Result:=nil;

        lProcDef:=nil;
        lModule:=nil;

        if not CheckGenericConstraints(AGenericDef,AContext.FParamList,AContext.FPosList) then
          begin
            { the parameters didn't fit the constraints, so don't continue with the
              specialization }
            Result:=GenErrorDef;
            exit;
          end;

        { build the new type's name }
        lHierarchy:=AGenericDef.ownerhierarchyname;
        if Assigned(AGenericDef.owner) then
          begin
            lModule:=Find_Module_From_SymTable(AGenericDef.owner);
            if not Assigned(lModule) then
              InternalError(2022102801);
            if lHierarchy<>'' then
              lHierarchy:='.'+lHierarchy;
            lHierarchy:=lModule.ModuleName^+lHierarchy;
          end;
        lFinalSpecializeName:=GenerateGenericName(AContext.FGenName,AContext.FSpecializeName,lHierarchy);
        lUFinalSpecializeName:=upper(lFinalSpecializeName);
        if AGenericDef.typ=procdef then
          lPrettyName:=TProcDef(AGenericDef).ProcSym.prettyname
        else
          lPrettyName:=AGenericDef.TypeSym.prettyname;
        lPrettyName:=lPrettyName+'<'+AContext.FPrettyName+'>';
        lGenericTypeList:=TFPHashObjectList.Create(false);

        { build the list containing the types for the generic params }
        if not Assigned(AGenericDef.GenericParas) then
          InternalError(2013092601);
        if AContext.FParamList.count<>AGenericDef.GenericParas.count then
          InternalError(2013092603);
        for lIndex:=0 to AGenericDef.GenericParas.Count-1 do
          begin
            lSearchSym:=TSym(AGenericDef.GenericParas[lIndex]);
            if not (sp_generic_para in lSearchSym.SymOptions) then
              InternalError(2013092602);
            lGenericTypeList.add(lSearchSym.realname,AContext.FParamList[lIndex]);
          end;

        { Special case if we are referencing the current defined object }
        if Assigned(CurrentStructDef) and
           (CurrentStructDef.ObjName^=lUFinalSpecializeName) then
          Result:=CurrentStructDef;

        { Can we reuse an already specialized type? }

        { for this first check whether we are currently specializing a nested
          type of the current (main) specialization (this is necessary, because
          during that time the symbol of the main specialization will still
          contain a reference to an errordef) }
        if not Assigned(Result) and Assigned(CurrentSpecializeDef) then
          begin
            lDef:=CurrentSpecializeDef;
            repeat
              if lDef.typ in [objectdef,recorddef] then
                if TAbstractRecordDef(lDef).ObjName^=lUFinalSpecializeName then begin
                  Result:=lDef;
                  break;
                end;
              if Assigned(lDef.owner) then
                lDef:=TStoredDef(lDef.owner.DefOwner)
              else
                { this can happen when specializing a generic function }
                lDef:=nil;
            until not Assigned(lDef) or not (df_specialization in lDef.DefOptions);
          end;

        { if the genericdef is the def we are currently parsing (or one of its parents) then we can
          not use it for specializing as the tokenbuffer is not yet set (and we aren't done with
          parsing anyway), so for now we treat those still as generic defs without doing a partial
          specialization }
        if not Assigned(Result) then
          begin
            lDef:=CurrentGenericDef;
            if lDef=AGenericDef then
              Result:=lDef
            else if Assigned(CurrentGenericDef) then
              Result:=FindInHierarchy(CurrentGenericDef,lGenericTypeList);
            if not Assigned(Result) and Assigned(CurrentSpecializeDef) then
              Result:=FindInHierarchy(CurrentSpecializeDef,lGenericTypeList);
          end;

        { decide in which symtable to put the specialization }
        if Assigned(AContext.FForwardDef) then
          begin
            lSpecializeSymTable:=AContext.FForwardDef.owner;
          end
        else if ParseGeneric and not Assigned(Result) then
          begin
            lSearchSymTable:=SymTableStack.top;
            if (lSearchSymTable.SymTableType in [LocalSymTable,parasymtable]) and TStoredDef(lSearchSymTable.DefOwner).Is_Specialization then
              { if we are currently specializing a routine we need to specialize into
                the routine's local- or parasymtable so that they are correctly
                registered should the specialization be finalized }
              lSpecializeSymTable:=lSearchSymTable
            else if Assigned(CurrentProcInfo) and (df_generic in CurrentProcInfo.procdef.DefOptions) then
              { if we are parsing the definition of a method we specialize into
                the local symtable of it }
              lSpecializeSymTable:=CurrentProcInfo.procdef.GetSymTable(gs_local)
            else
              begin
                if not Assigned(CurrentGenericDef) then
                  InternalError(2014050901);
                { we specialize the partial specialization into the symtable of the currently parsed
                  generic }
                case CurrentGenericDef.typ of
                  procvardef:
                    lSpecializeSymTable:=CurrentGenericDef.GetSymTable(gs_para);
                  procdef:
                    lSpecializeSymTable:=CurrentGenericDef.GetSymTable(gs_local);
                  objectdef,
                  recorddef:
                    lSpecializeSymTable:=CurrentGenericDef.GetSymTable(gs_record);
                  arraydef:
                    lSpecializeSymTable:=TArrayDef(CurrentGenericDef).SymTable;
                  else
                    InternalError(2014050902);
                end;
              end;
          end
        else
          begin
            { if one of the type parameters resolves to a type living in a
              local- or parasymtable then use that local symtable for the
              specialization. Walk the underlying typedef chain (pointer,
              array, set, ...) so that e.g. TEnumerable<TLocal>.PT = ^TLocal,
              when used to specialize TEnumerator<PT>, is recognised as
              proc-local rather than wrongly placed at unit scope (which
              would result in a PPU defref that fails to resolve on reload). }
            lSpecializeSymTable:=nil;
            for lIndex:=0 to AContext.FParamList.count-1 do
              begin
                lPSym:=TSym(AContext.FParamList[lIndex]);
                if lPSym.typ=TypeSym then
                  lFoundDef:=TTypeSym(lPSym).TypeDef
                else
                  lFoundDef:=nil;
                while Assigned(lFoundDef) do
                  begin
                    if Assigned(lFoundDef.owner) and
                       (lFoundDef.owner.SymTableType in [LocalSymTable,parasymtable]) then
                      begin
                        if (lFoundDef.owner.SymTableType=parasymtable) and
                           Assigned(lFoundDef.owner.DefOwner) and
                           (lFoundDef.owner.DefOwner.typ=procdef) then
                          lSpecializeSymTable:=TProcDef(lFoundDef.owner.DefOwner).GetSymTable(gs_local)
                        else
                          lSpecializeSymTable:=lFoundDef.owner;
                        break;
                      end;
                    case lFoundDef.typ of
                      pointerdef:
                        lFoundDef:=TPointerDef(lFoundDef).PointedDef;
                      arraydef:
                        lFoundDef:=TArrayDef(lFoundDef).ElementDef;
                      setdef:
                        lFoundDef:=TSetDef(lFoundDef).ElementDef;
                      filedef:
                        lFoundDef:=TFileDef(lFoundDef).TypedFileDef;
                      classrefdef:
                        lFoundDef:=TClassRefDef(lFoundDef).PointedDef;
                      else
                        lFoundDef:=nil;
                    end;
                  end;
                if Assigned(lSpecializeSymTable) then
                  break;
                { also accept the param's immediate sym owner being a local
                  scope — covers the case where the type-arg is a const-sym
                  rather than a typesym }
                if lPSym.owner.SymTableType in [LocalSymTable,parasymtable] then
                  begin
                    if (lPSym.owner.SymTableType=parasymtable) and
                       Assigned(lPSym.owner.DefOwner) and
                       (lPSym.owner.DefOwner.typ=procdef) then
                      lSpecializeSymTable:=TProcDef(lPSym.owner.DefOwner).GetSymTable(gs_local)
                    else
                      lSpecializeSymTable:=lPSym.owner;
                    break;
                  end;
              end;

            if not Assigned(lSpecializeSymTable) then
              if CurrentModule.IsUnit and CurrentModule.InInterface then
                lSpecializeSymTable:=CurrentModule.GlobalSymTable
              else
                lSpecializeSymTable:=CurrentModule.LocalSymTable;
          end;
        if not Assigned(lSpecializeSymTable) then
          InternalError(2014050910);

        { now check whether there is a specialization somewhere else }
        lPSym:=nil;
        if not Assigned(Result) then
          begin
            lHashedID.id:=lUFinalSpecializeName;

            if (lSpecializeSymTable.SymTableType=objectsymtable) and not Assigned(AContext.FForwardDef) then
              begin
                { search also in parent classes }
                if not Assigned(CurrentGenericDef) or (CurrentGenericDef.typ<>objectdef) then
                  InternalError(2016112901);
                if not SearchSym_In_Class(TObjectDef(CurrentGenericDef),TObjectDef(CurrentGenericDef),lUFinalSpecializeName,lSearchSym,lSearchSymTable,[]) then
                  lSearchSym:=nil;
              end
            else
              lSearchSym:=TSym(lSpecializeSymTable.findwithhash(lHashedID));

            if Assigned(AContext.FForwardDef) then
              begin
                { just do a few sanity checks }
                if not Assigned(lSearchSym) or not (lSearchSym.typ=TypeSym) then
                  InternalError(2020070306);
                if TTypeSym(lSearchSym).TypeDef<>AContext.FForwardDef then
                  InternalError(2020070307);
              end
            else if Assigned(lSearchSym) then
              begin
                RetrieveGenericDefOrProcSym(lSearchSym,Result,lPSym);
              end
            else
              { the generic could have been specialized in the globalsymtable
                already, so search there as well }
              if (lSpecializeSymTable<>CurrentModule.GlobalSymTable) and Assigned(CurrentModule.GlobalSymTable) then
                begin
                  lSearchSym:=TSym(CurrentModule.GlobalSymTable.findwithhash(lHashedID));
                  if Assigned(lSearchSym) then
                    begin
                      RetrieveGenericDefOrProcSym(lSearchSym,Result,lPSym);
                    end;
                end;
          end;

        if not Assigned(Result) then
          begin
            SpecializationInit(AGenericDef,lState);

            { push a temporary global symtable so that the specialization is
              added to the correct symtable; this symtable does not contain
              any other symbols, so that the type resolution can not be
              influenced by symbols in the current unit }
            lTempSymTable:=TSpecializeSymTable.Create(CurrentModule.ModuleName^,CurrentModule.ModuleID);
            SymTableStack.push(lTempSymTable);

            { Reparse the original type definition }
              begin
                lOldCurrentSpecializeDef:=nil;
                lOldCurrentGenericDef:=nil;
                lOldCurrentStructDef:=nil;
                lOldCurrentProcInfo:=CurrentProcInfo;
                lOldModuleProcInfo:=CurrentModule.ProcInfo;

                CurrentProcInfo:=nil;
                CurrentModule.ProcInfo:=nil;

                if AParseClassParent then
                  begin
                    lOldCurrentStructDef:=CurrentStructDef;
                    lOldCurrentGenericDef:=CurrentGenericDef;
                    lOldCurrentSpecializeDef:=CurrentSpecializeDef;

                    if AGenericDef.owner.SymTableType in [recordsymtable,objectsymtable] then
                      CurrentStructDef:=TAbstractRecordDef(AGenericDef.owner.DefOwner)
                    else
                      CurrentStructDef:=nil;
                    CurrentGenericDef:=nil;
                    CurrentSpecializeDef:=nil;
                  end;

                MaybeAddWaitingUnit(AGenericDef);

                { First a new sym so we can reuse this specialization and
                  references to this specialization can be handled }
                if AGenericDef.typ=procdef then
                  if Assigned(lPSym) then
                    lSearchSym:=lPSym
                  else
                    lSearchSym:=CProcSym.Create(lFinalSpecializeName)
                else
                  lSearchSym:=CTypeSym.Create(lFinalSpecializeName,GenErrorDef);
                { insert the symbol only if we don't know already that we have
                  a procsym to add it to and we aren't dealing with a forwarddef }
                if not Assigned(lPSym) and not Assigned(AContext.FForwardDef) then
                  lSpecializeSymTable.InsertSym(lSearchSym);

                { specializations are declarations as such it is the wisest to
                  declare set the blocktype to "type"; otherwise we'll
                  experience unexpected side effects like the addition of
                  classrefdefs if we have a generic that's derived from another
                  generic }
                lOldBlockType:=Block_Type;
                Block_Type:=bt_type;

                if (
                     (AGenericDef.typ=procdef) and
                     not Assigned(TProcDef(AGenericDef).GenericDeclTokenBuf)
                   ) or (
                     (AGenericDef.typ<>procdef) and
                     not Assigned(AGenericDef.GenericTokenBuf)
                   ) then
                  InternalError(200511171);
                if lModule=nil then
                  InternalError(2012051202);
                lOldCurrentFilePos:=CurrentFilePos;
                { use the index the module got from the current compilation process }
                CurrentFilePos.moduleindex:=lModule.ModuleID;
                CurrentTokenPos:=CurrentFilePos;
                if ParseGeneric then
                  begin
                    lRecordBuf:=CurrentScanner.FRecordTokenBuf;
                    CurrentScanner.FRecordTokenBuf:=nil;
                  end
                else
                  lRecordBuf:=nil;
                lReplayDepth:=CurrentScanner.ReplayStackDepth;
                if AGenericDef.typ=procdef then
                  begin
                    CurrentScanner.StartReplayTokens(TProcDef(AGenericDef).GenericDeclTokenBuf);
                    ParseProcHead(TProcDef(AGenericDef).struct,TProcDef(AGenericDef).ProcTypeOption,[],AGenericDef,lGenericTypeList,lProcDef);
                    if Assigned(lProcDef) then
                      begin
                        if Assigned(lPSym) then
                          lProcDef.ProcSym:=lPSym
                        else
                          lProcDef.ProcSym:=lSearchSym;
                        lPPFlags:=[];
                        if po_classmethod in TProcDef(AGenericDef).ProcOptions then
                          include(lPPFlags,ppfClassMethod);
                        ParseProcDecFinish(lProcDef,lPPFlags,TProcDef(AGenericDef).struct);
                      end;
                    Result:=lProcDef;
                  end
                else
                  begin
                    CurrentScanner.StartReplayTokens(AGenericDef.GenericTokenBuf);
                    if Assigned(AContext.FForwardDef) then
                      begin
                        lTypeSym:=nil;
                        Result:=ParseForwardDeclaration(AContext.FForwardDef.TypeSym,lUFinalSpecializeName,lFinalSpecializeName,AGenericDef,lGenericTypeList,lTypeSym);
                        lSearchSym:=lTypeSym;
                      end
                    else
                      begin
                        lHadTypeToken:=false;

                        { ensure a pretty name for error messages, might be chanced below }
                        if APrettyName<>'' then
                          TTypeSym(lSearchSym).FPrettyName:=APrettyName
                        else
                          TTypeSym(lSearchSym).FPrettyName:=lPrettyName;

                        ReadNamedType(Result,lSearchSym,AGenericDef,lGenericTypeList,false,lHadTypeToken);
                        TTypeSym(lSearchSym).TypeDef:=Result;
                        Result.TypeSym:=lSearchSym;
                      end;

                    if APrettyName<>'' then
                      TTypeSym(Result.TypeSym).FPrettyName:=APrettyName
                    else
                      TTypeSym(Result.TypeSym).FPrettyName:=lPrettyName;
                  end;
                CurrentFilePos:=lOldCurrentFilePos;

                { Note regarding hint directives:
                  There is no need to remove the flags for them from the
                  specialized generic symbol, because hint directives that
                  follow the specialization are handled by the code in
                  pdecl.types_dec and added to the type symbol.
                  E.g.: TFoo = TBar<Blubb> deprecated;
                  Here the symbol TBar$1$Blubb will contain the
                  "sp_hint_deprecated" flag while the TFoo symbol won't.}

                case Result.typ of
                  { Build VMT indexes for classes and read hint directives }
                  objectdef:
                    begin
                      if lReplayDepth<CurrentScanner.ReplayStackDepth then
                        begin
                          TryConsumeHintDirective(lSearchSym.SymOptions,lSearchSym.DeprecatedMsg);
                          if lReplayDepth<CurrentScanner.ReplayStackDepth then
                            Consume(_SEMICOLON);
                        end;

                      if oo_is_forward in TObjectDef(Result).ObjectOptions then
                        AddForwardGenericDef(Result,AContext)
                      else if not (oo_inherits_not_specialized in TObjectDef(Result).ObjectOptions) then
                        Build_VMT(TObjectDef(Result))
                      else
                        { update the procdevs to add hidden self param }
                        Insert_Struct_Hidden_Paras(TObjectDef(Result));
                    end;
                  { handle params, calling convention, etc }
                  procvardef:
                    begin
                      lHintsProcessed:=false;
                      if lReplayDepth<CurrentScanner.ReplayStackDepth then
                        begin
                          if not CheckProcDirective(true) then
                            begin
                              lHintsProcessed:=TryConsumeHintDirective(TTypeSym(lSearchSym).SymOptions,TTypeSym(lSearchSym).DeprecatedMsg);
                              if lReplayDepth<CurrentScanner.ReplayStackDepth then
                                Consume(_SEMICOLON);
                            end
                          else
                            lHintsProcessed:=true;
                        end;
                      if lReplayDepth<CurrentScanner.ReplayStackDepth then
                        ParseProcTypeDirectives(TProcVarDef(Result));
                      if po_is_function_ref in TProcVarDef(Result).ProcOptions then
                        Adjust_FuncRef(Result,lSearchSym,nil);
                      if Result.typ=procvardef then
                        lFlags:=cHCCDefaultActionsIntf
                      else
                        lFlags:=cHCCDefaultActionsIntfStruct;
                      Handle_Calling_Convention(Result,lFlags);
                      if not lHintsProcessed and (lReplayDepth<CurrentScanner.ReplayStackDepth) then
                        begin
                          TryConsumeHintDirective(TTypeSym(lSearchSym).SymOptions,TTypeSym(lSearchSym).DeprecatedMsg);
                          if lReplayDepth<CurrentScanner.ReplayStackDepth then
                            Consume(_SEMICOLON);
                        end;
                    end;
                  procdef:
                    begin
                      lPDFlags:=[];
                      if AGenericDef.owner.SymTableType=objectsymtable then
                        include(lPDFlags,pdObject)
                      else if AGenericDef.owner.SymTableType=recordsymtable then
                        include(lPDFlags,pdRecord);
                      ParseProcDirectives(lProcDef,lPDFlags);
                      while TryConsumeHintDirective(lProcDef.SymOptions,lProcDef.DeprecatedMsg) do
                        Consume(_SEMICOLON);
                      if ParseGeneric then
                        Handle_Calling_Convention(TProcDef(Result),cHCCDefaultActionsIntf)
                      else
                        Handle_Calling_Convention(TProcDef(Result),cHCCDefaultActionsImpl);
                      Proc_Add_Definition(TProcDef(Result));
                      { for partial specializations we implicitly declare the routine as
                        having its implementation although we'll not specialize it in reality }
                      if ParseGeneric then
                        UnsetForwardDef(Result);
                    end;
                  else
                    { parse hint directives for records and arrays }
                    if lReplayDepth<CurrentScanner.ReplayStackDepth then begin
                      TryConsumeHintDirective(lSearchSym.SymOptions,lSearchSym.DeprecatedMsg);
                      if lReplayDepth<CurrentScanner.ReplayStackDepth then
                        Consume(_SEMICOLON);
                    end;
                end;
                { Consume the remainder of the buffer }
                while CurrentScanner.ReplayStackDepth>lReplayDepth do
                  Consume(CurrentScanner.FToken);

                if Assigned(lRecordBuf) then
                  begin
                    if Assigned(CurrentScanner.FRecordTokenBuf) then
                      InternalError(2014050909);
                    CurrentScanner.FRecordTokenBuf:=lRecordBuf;
                  end;

                Block_Type:=lOldBlockType;
                CurrentProcInfo:=lOldCurrentProcInfo;
                CurrentModule.ProcInfo:=lOldModuleProcInfo;
                if AParseClassParent then
                  begin
                    CurrentStructDef:=lOldCurrentStructDef;
                    CurrentGenericDef:=lOldCurrentGenericDef;
                    CurrentSpecializeDef:=lOldCurrentSpecializeDef;
                  end;
              end;

            { extract all created symbols and defs from the temporary symtable
              and add them to the specializest }
            for lIndex:=lTempSymTable.SymList.Count-1 downto 0 do
              begin
                lItem:=lTempSymTable.SymList.Items[lIndex];
                { using changeowner the symbol is automatically added to the
                  new symtable }
                TSym(lItem).ChangeOwner(lSpecializeSymTable);
              end;

            for lIndex:=lTempSymTable.DefList.Count-1 downto 0 do
              begin
                lItem:=lTempSymTable.DefList.Items[lIndex];
                { using changeowner the def is automatically added to the new
                  symtable }
                TDef(lItem).ChangeOwner(lSpecializeSymTable);
                { for partial specializations we implicitly declare any methods as having their
                  implementations although we'll not specialize them in reality }
                if ParseGeneric or HasGenericParas(TStoredDef(lItem)) then
                  UnsetForwardDef(TDef(lItem));
              end;

            { if a generic was declared during the specialization we need to
              flag the specialize symtable accordingly }
            if sto_has_generic in lTempSymTable.TableOptions then
              lSpecializeSymTable.IncludeOption(sto_has_generic);

            lTempSymTable.free;
            lTempSymTable := nil;

            SpecializationDone(lState);

            { procdefs are only added once we know which overload we use }
            if not ParseGeneric and (Result.typ<>procdef) and
              not HasGenericParas(TStoredDef(Result)) then
                  CurrentModule.PendingSpecializations.add(Result.TypeName,Result);
          end;

        lGenericTypeList.free;
        lGenericTypeList := nil;
        if Assigned(AGenericDef) then
          begin
            { check the hints of the found generic symbol }
            if AGenericDef.typ=procdef then
              lSearchSym:=TProcDef(AGenericDef).ProcSym
            else
              lSearchSym:=AGenericDef.TypeSym;
            Check_Hints(lSearchSym,lSearchSym.SymOptions,lSearchSym.DeprecatedMsg);
          end;
      end;


    procedure GenerateSpecialization(var ADef:TDef;AEnforceUnit:Boolean;AParseClassParent:Boolean;const APrettyName:String;AParsedType:TDef;const ASymName:String;AParsedPos:TFilePosInfo);
      var
        lContext : TSpecializationContext;
        lGenericDef : TStoredDef;
      begin
        lGenericDef:=TStoredDef(GenerateSpecializationPhase1(lContext,ADef,AEnforceUnit,AParsedType,ASymName,nil,AParsedPos));
        if lGenericDef<>GenErrorDef then
          lGenericDef:=TStoredDef(GenerateSpecializationPhase2(lContext,lGenericDef,AParseClassParent,APrettyName));
        ADef:=lGenericDef;
        if Assigned(lContext) then
          lContext.free; // no nil needed
      end;


    function ParseGenericParameters(AAllowConstraints:Boolean):TFPHashObjectList;
      var
        lGenericType : TStoredSym;
        lIndex,lFirstIdx,lConstListIndex : LongInt;
        lSearchSymTable : TSymTable;
        lBaseDef,lDef : TDef;
        lDefName : TIDString;
        lAllowConst,
        lAllowConstructor,
        lIsConst,
        lDoConsume : Boolean;
        lConstraintData : TGenericConstraintData;
        lOldBlockType : TBlockType;
        lFileInfo : TFilePosInfo;
      begin
        Result:=TFPHashObjectList.Create(false);
        lFirstIdx:=0;
        lConstListIndex:=0;
        lOldBlockType:=Block_Type;
        Block_Type:=bt_type;
        lAllowConst:=true;
        lIsConst:=false;
        repeat
          if lAllowConst and TryToConsume(_CONST) then
            begin
              lAllowConst:=false;
              lIsConst:=true;
              lConstListIndex:=Result.count;
            end;
          if CurrentScanner.FToken=_ID then
            begin
              if lIsConst then
                lGenericType:=CConstSym.Create_Undefined(CurrentScanner.FOrgPattern,CUndefinedType)
              else
                lGenericType:=CTypeSym.Create(CurrentScanner.FOrgPattern,CUndefinedType);
              { type parameters need to be added as strict private }
              lGenericType.visibility:=vis_strictprivate;
              include(lGenericType.SymOptions,sp_generic_para);
              Result.add(CurrentScanner.FOrgPattern,lGenericType);
            end;
          Consume(_ID);
          lFileInfo:=CurrentTokenPos;
          { const restriction }
          if lIsConst and TryToConsume(_COLON) then
            begin
              lDef:=nil;
              { parse the type and assign the const type to generictype  }
              SingleType(lDef,[]);
              for lIndex:=lConstListIndex to Result.count-1 do
                begin
                  { finalize constant information once type is known }
                  if Assigned(lDef) and (lDef.typ in cGenericParamConstTypes) then
                    begin
                      case lDef.typ of
                        orddef,
                        enumdef:
                          TConstSym(Result[lIndex]).ConstTyp:=constord;
                        stringdef:
                          TConstSym(Result[lIndex]).ConstTyp:=conststring;
                        floatdef:
                          TConstSym(Result[lIndex]).ConstTyp:=constreal;
                        setdef:
                          TConstSym(Result[lIndex]).ConstTyp:=constset;
                        { pointer always refers to nil with constants }
                        pointerdef:
                          TConstSym(Result[lIndex]).ConstTyp:=constnil;
                        else
                          InternalError(2020011402);
                      end;
                      TConstSym(Result[lIndex]).ConstDef:=lDef;
                    end
                  else
                    Message1(type_e_generic_const_type_not_allowed,lDef.FullTypeName);
                end;
              { after type restriction const list terminates }
              lIsConst:=false;
            end
          { type restriction }
          else if TryToConsume(_COLON) then
            begin
              if not AAllowConstraints then
                Message(parser_e_generic_constraints_not_allowed_here);
              { construct a name which can be used for a type specification }
              lConstraintData:=TGenericConstraintData.Create;
              lConstraintData.fileinfo:=lFileInfo;
              lDefName:='';
              str(CurrentModule.DefList.count,lDefName);
              lDefName:='$gendef'+lDefName;

              lAllowConstructor:=m_delphi in CurrentSettings.ModeSwitches;

              lBaseDef:=GenErrorDef;
              repeat
                lDoConsume:=true;

                case CurrentScanner.FToken of
                  _CONSTRUCTOR:
                    begin
                      if not lAllowConstructor or (gcf_constructor in lConstraintData.flags) then
                        Message(parser_e_illegal_expression);
                      include(lConstraintData.flags,gcf_constructor);
                      lAllowConstructor:=false;
                    end;
                  _CLASS:
                    begin
                      if gcf_class in lConstraintData.flags then
                        Message(parser_e_illegal_expression);
                      if lBaseDef=GenErrorDef then
                        include(lConstraintData.flags,gcf_class)
                      else
                        Message(parser_e_illegal_expression);
                    end;
                  _RECORD:
                    begin
                      if ([gcf_constructor,gcf_class]*lConstraintData.flags<>[])
                          or (lConstraintData.Interfaces.count>0) then
                        Message(parser_e_illegal_expression)
                      else
                        begin
                          lSearchSymTable:=TRecordSymTable.Create(lDefName,0,1);
                          lBaseDef:=CRecordDef.Create(lDefName,lSearchSymTable);
                          include(lConstraintData.flags,gcf_record);
                          lAllowConstructor:=false;
                        end;
                    end;
                  else
                    begin
                      { after single_type "token" is the trailing ",", ";" or
                        ">"! }
                      lDoConsume:=false;
                      { def is already set to a class or record }
                      if gcf_record in lConstraintData.flags then
                        Message(parser_e_illegal_expression);
                      SingleType(lDef, [stoAllowSpecialization]);
                      { only types that are inheritable are allowed }
                      if (lDef.typ<>objectdef) or
                          not (TObjectDef(lDef).ObjectType in [odt_class,odt_interfacecom,odt_interfacecorba]) then
                        Message1(type_e_class_or_interface_type_expected,lDef.TypeName)
                      else
                        case TObjectDef(lDef).ObjectType of
                          odt_class:
                            begin
                              if gcf_class in lConstraintData.flags then
                                { "class" + concrete class is not allowed }
                                Message(parser_e_illegal_expression)
                              else
                                { do we already have a concrete class? }
                                if lBaseDef<>GenErrorDef then
                                  Message(parser_e_illegal_expression)
                                else
                                  lBaseDef:=lDef;
                            end;
                          odt_interfacecom,
                          odt_interfacecorba,
                          odt_dispinterface:
                            lConstraintData.Interfaces.add(lDef);
                          else
                            ;
                        end;
                    end;
                end;
                if lDoConsume then
                  Consume(CurrentScanner.FToken);
              until not TryToConsume(_COMMA);

              if ([gcf_class,gcf_constructor]*lConstraintData.flags<>[]) or
                  (lConstraintData.Interfaces.count>1) or
                  (
                    (lBaseDef.typ=objectdef) and
                    (TObjectDef(lBaseDef).ObjectType in [odt_class])
                  ) then
                begin
                  if lBaseDef.typ=errordef then
                    { don't pass an errordef as a parent to a tobjectdef }
                    lBaseDef:=Class_TObject
                  else
                    if (lBaseDef.typ<>objectdef) or
                        not (TObjectDef(lBaseDef).ObjectType in [odt_class]) then
                      InternalError(2012101101);
                  lBaseDef:=CObjectDef.Create(TObjectDef(lBaseDef).ObjectType,lDefName,TObjectDef(lBaseDef),false);
                  for lIndex:=0 to lConstraintData.Interfaces.count-1 do
                    TObjectDef(lBaseDef).Register_Implemented_Interface(TObjectDef(lConstraintData.Interfaces[lIndex]),false);
                end
              else
                if lConstraintData.Interfaces.count=1 then
                  begin
                    if lBaseDef.typ<>errordef then
                      InternalError(2013021601);
                    lDef:=TDef(lConstraintData.Interfaces[0]);
                    lBaseDef:=CObjectDef.Create(TObjectDef(lDef).ObjectType,lDefName,TObjectDef(lDef),false);
                    lConstraintData.Interfaces.delete(0);
                  end;

              if lBaseDef.typ<>errordef then
                with TStoredDef(lBaseDef) do
                  begin
                    GenConstraintData:=TGenericConstraintData.Create;
                    GenConstraintData.flags:=lConstraintData.flags;
                    GenConstraintData.Interfaces.assign(lConstraintData.Interfaces);
                    GenConstraintData.fileinfo:=lConstraintData.fileinfo;
                    include(DefOptions,df_genconstraint);
                  end
              else
                { the constraint was rejected: recover as an unconstrained
                  parameter; keeping the shared errordef would corrupt its
                  typesym below and IE in check_generic_constraints later }
                lBaseDef:=CUndefinedDef.Create(false);

              for lIndex:=lFirstIdx to Result.count-1 do
                TTypeSym(Result[lIndex]).TypeDef:=lBaseDef;
              { we need a typesym in case we do a Delphi-mode inline
                specialization with this parameter; so just use the first sym }
              if not Assigned(lBaseDef.TypeSym) then
                lBaseDef.TypeSym:=TTypeSym(Result[lFirstIdx]);
              lFirstIdx:=Result.count;

              lConstraintData.free;
              lConstraintData := nil;
            end
          else
            begin
              if CurrentScanner.FToken=_SEMICOLON then
                begin
                  { two different typeless parameters are considered as incompatible }
                  for lIndex:=lFirstIdx to Result.count-1 do
                    if TSym(Result[lIndex]).typ<>constsym then
                      begin
                        TTypeSym(Result[lIndex]).TypeDef:=CUndefinedDef.Create(false);
                        TTypeSym(Result[lIndex]).TypeDef.TypeSym:=TTypeSym(Result[lIndex]);
                      end;
                  { a semicolon terminates a type parameter group }
                  lFirstIdx:=Result.count;
                end;
            end;
          if CurrentScanner.FToken=_SEMICOLON then
            begin
              lIsConst:=false;
              lAllowConst:=true;
            end;
        until not (TryToConsume(_COMMA) or TryToConsume(_SEMICOLON));
        { if the constant parameter is not terminated then the type restriction was
          not specified and we need to give an error }
        if lIsConst then
          Consume(_COLON);
        { two different typeless parameters are considered as incompatible }
        for lIndex:=lFirstIdx to Result.count-1 do
          if TSym(Result[lIndex]).typ<>constsym then
            begin
              TTypeSym(Result[lIndex]).TypeDef:=CUndefinedDef.Create(false);
              TTypeSym(Result[lIndex]).TypeDef.TypeSym:=TTypeSym(Result[lIndex]);
            end;
        Block_Type:=lOldBlockType;
      end;


    procedure InsertGenericParameterTypes(ADef:TStoredDef;AGenericDef:TStoredDef;AGenericList:TFPHashObjectList;AIsFwd:Boolean);
      var
        lIndex : LongInt;
        lGenericType,
        lFwdParam : TStoredSym;
        lGenericTypeDef : TDef;
        lSym : TSym;
        lSymTable : TSymTable;
        lFwdOK : Boolean;
        lConv : TConvertType;
        lOp : TProcDef;
      begin
        ADef.GenericDef:=AGenericDef;
        if not Assigned(AGenericList) then
          exit;

        if Assigned(AGenericDef) then
          include(ADef.DefOptions,df_specialization)
        else
          if AGenericList.count>0 then
            include(ADef.DefOptions,df_generic);

        case ADef.typ of
          recorddef,objectdef: lSymTable:=TAbstractRecordDef(ADef).SymTable;
          arraydef: lSymTable:=TArrayDef(ADef).SymTable;
          procvardef,procdef: lSymTable:=TAbstractProcDef(ADef).ParaST;
          else
            InternalError(201101020);
        end;

        { if we have a forwarddef we check whether the generic parameters are
          equal and otherwise ignore the list }
        if AIsFwd then
          begin
            lFwdOK:=true;
            if (AGenericList.count>0) and
                (
                  not Assigned(ADef.GenericParas)
                  or (ADef.GenericParas.count<>AGenericList.count)
                ) then
              lFwdOK:=false
            else
              begin
                for lIndex:=0 to AGenericList.count-1 do
                  begin
                    if ADef.GenericParas.nameofindex(lIndex)<>AGenericList.nameofindex(lIndex) then
                      begin
                        lFwdOK:=false;
                        break;
                      end;
                    lGenericType:=TStoredSym(AGenericList[lIndex]);
                    lFwdParam:=TStoredSym(ADef.GenericParas[lIndex]);
                    lOp:=nil;
                    lConv:=tc_equal;
                    if lGenericType.typ<>lFwdParam.typ then
                      lFwdOK:=false
                    else if (lGenericType.typ=TypeSym) then
                      begin
                        if Compare_Defs_Ext(TTypeSym(lGenericType).TypeDef,TTypeSym(lFwdParam).TypeDef,nothingn,lConv,lOp,[cdo_strict_genconstraint_check])<te_exact then
                          lFwdOK:=false;
                      end
                    else if (lGenericType.typ=constsym) then
                      begin
                        if (TConstSym(lGenericType).ConstTyp<>TConstSym(lFwdParam).ConstTyp) or
                            (Compare_Defs_Ext(TConstSym(lGenericType).ConstDef,TConstSym(lFwdParam).ConstDef,nothingn,lConv,lOp,[cdo_strict_genconstraint_check])<te_exact) then
                          lFwdOK:=false;
                      end
                    else
                      InternalError(2020070101);

                    if not lFwdOK then
                      break;
                  end;
              end;

            if not lFwdOK then
              Message(parser_e_forward_mismatch);

            exit;
          end;

        if (AGenericList.count>0) and not Assigned(ADef.GenericParas) then
          ADef.GenericParas:=TFPHashObjectList.Create(false);
        for lIndex:=0 to AGenericList.count-1 do
          begin
            lGenericType:=TStoredSym(AGenericList[lIndex]);
            if Assigned(lGenericType.owner) then
              begin
                if lGenericType.typ=TypeSym then
                  lSym:=CTypeSym.Create(AGenericList.nameofindex(lIndex),TTypeSym(lGenericType).TypeDef)
                else if lGenericType.typ=constsym then
                  { generictype is a constsym that was created in create_generic_constsym
                    during phase 1 so we pass this directly without copying }
                  begin
                    lSym:=lGenericType;
                    { the sym name is still undefined so we set it to match
                      the generic param name so it's accessible }
                    lSym.realname:=AGenericList.nameofindex(lIndex);
                    include(lSym.SymOptions,sp_generic_const);
                  end
                else
                  InternalError(2019021602);
                { type parameters need to be added as strict private }
                lSym.visibility:=vis_strictprivate;
                lSymTable.InsertSym(lSym);
                include(lSym.SymOptions,sp_generic_para);
              end
            else
              begin
                if lGenericType.typ=TypeSym then
                  begin
                    lGenericTypeDef:=TTypeSym(lGenericType).TypeDef;
                    if (lGenericTypeDef.typ=undefineddef) and (lGenericTypeDef<>CUndefinedType) then
                      begin
                        { the generic parameters were parsed before the genericdef existed thus the
                          undefineddefs were added as part of the parent symtable }
                        if Assigned(lGenericTypeDef.owner) then
                          lGenericTypeDef.owner.DefList.Extract(lGenericTypeDef);
                        lGenericTypeDef.changeowner(lSymTable);
                      end;
                  end;
                lSymTable.InsertSym(lGenericType);
                include(lGenericType.SymOptions,sp_generic_para);
              end;
            ADef.GenericParas.add(AGenericList.nameofindex(lIndex),lGenericType);
          end;
       end;

    procedure MaybeInsertGenericRenameSymbol(const AName:TIDString;AGenericList:TFPHashObjectList);
      var
        lGenSym : TTypeSym;
      begin
        { for generics in non-Delphi modes we insert a private type symbol
          that has the same base name as the currently parsed generic and
          that references this defs }
        if not (m_delphi in CurrentSettings.ModeSwitches) and
            (
              (
                ParseGeneric and
                Assigned(AGenericList) and
                (AGenericList.count>0)
              ) or
              (
                Assigned(CurrentSpecializeDef) and
                Assigned(CurrentStructDef.GenericDef) and
                (CurrentStructDef.GenericDef.typ in [objectdef,recorddef]) and
                (pos('$',AName)>0)
              )
            ) then
          begin
            { we need to pass nil as def here, because the constructor wants
              to set the typesym of the def which is not what we want }
            lGenSym:=CTypeSym.Create(copy(AName,1,pos('$',AName)-1),nil);
            lGenSym.TypeDef:=CurrentStructDef;
            include(lGenSym.SymOptions,sp_internal);
            { the symbol should be only visible to the generic class
              itself }
            lGenSym.visibility:=vis_strictprivate;
            SymTableStack.top.InsertSym(lGenSym);
          end;
      end;

    function GenerateGenericName(const AName:TIDString;const ASpecializeName:AnsiString;const AOwnerHierarchy:AnsiString):TIDString;
    var
      lCRC : cardinal;
    begin
      if ASpecializeName='' then
        InternalError(2012061901);
      { build the new type's name }
      lCRC:=UpdateCRC32(0,ASpecializeName[1],length(ASpecializeName));
      Result:=AName+'$crc'+HexStr(lCRC,8);
      if AOwnerHierarchy<>'' then
        begin
          lCRC:=UpdateCRC32(0,AOwnerHierarchy[1],length(AOwnerHierarchy));
          Result:=Result+'_crc'+HexStr(lCRC,8);
        end;
    end;

    procedure SplitGenericName(const AName:TIDString;out ANonGeneric:String;out ACount:LongInt);
      var
        lIndex,lCode : LongInt;
        lCountStr : String;
      begin
        for lIndex:=length(AName) downto 1 do
          if AName[lIndex]='$' then
            begin
              ANonGeneric:=copy(AName,1,lIndex-1);
              lCountStr:=copy(AName,lIndex+1,length(AName)-lIndex);
              val(lCountStr,ACount,lCode);
              if lCode<>0 then
                break;
              exit;
            end;
        ANonGeneric:=AName;
        ACount:=0;
      end;


    procedure AddGenericDummySym(ASym:TSym;const AName:TIDString);
      var
        lList: TFPObjectList;
        lSearchSym : TSym;
        lSearchSymTable : TSymTable;
        lEntry : TGenericDummyEntry;
        lCount : TIDString;
      begin
        if sp_generic_dummy in ASym.SymOptions then
          begin
            lCount:=ASym.name;
            if lCount='' then
              lCount:=AName;
            { did we already search for a generic with that name? }
            lList:=TFPObjectList(CurrentModule.GenericDummySyms.find(lCount));
            if not Assigned(lList) then
              begin
                lList:=TFPObjectList.Create(true);
                CurrentModule.GenericDummySyms.add(lCount,lList);
              end;
            { is the dummy sym still "dummy"? }
            if (ASym.typ=TypeSym) and
                (
                  { dummy sym defined in mode Delphi }
                  (TTypeSym(ASym).TypeDef.typ=undefineddef) or
                  { dummy sym defined in non-Delphi mode }
                  (TStoredDef(TTypeSym(ASym).TypeDef).Is_Generic)
                ) then
              begin
                { do we have a non-generic type of the same name
                  available? }
                if not SearchSym_With_Flags(lCount,lSearchSym,lSearchSymTable,[ssf_no_addsymref]) then
                  lSearchSym:=nil;
              end
            else if ASym.typ=ProcSym then
              lSearchSym:=ASym
            else
              { dummy symbol is already not so dummy anymore }
              lSearchSym:=nil;
            if Assigned(lSearchSym) then
              begin
                lEntry:=TGenericDummyEntry.Create;
                lEntry.ResolvedSym:=lSearchSym;
                lEntry.DummySym:=ASym;
                lList.add(lEntry);
              end;
          end;
      end;


    function ResolveGenericDummySym(const AName:TIDString):TSym;
      var
        lList : TFPObjectList;
      begin
        lList:=TFPObjectList(CurrentModule.GenericDummySyms.find(AName));
        if Assigned(lList) and (lList.count>0) then
          Result:=TGenericDummyEntry(lList.last).ResolvedSym
        else
          Result:=nil;
      end;


    function CouldBeGeneric(const AName:TIDString):Boolean;
      begin
        Result:=(AName<>'') and
                  (CurrentModule.GenericDummySyms.findindexof(AName)>=0);
      end;


    function IsOrBelongsToCurrentGenericDef(ADef:TDef):Boolean;
      var
        lState : PSpecializationState;
      begin
        Result:=true;
        if (ADef=CurrentGenericDef) or
            Defs_Belong_To_Same_Generic(ADef,CurrentGenericDef) then
          exit;
        lState:=PSpecializationState(CurrentModule.SpecializeState);
        while Assigned(lState) do
          begin
            if (lState^.OldCurrentGenericDef=ADef) or
                Defs_Belong_To_Same_Generic(lState^.OldCurrentGenericDef,ADef) then
              exit;
            lState:=lState^.OldSpecializeState;
          end;
        Result:=false;
      end;


    procedure SpecializationInit(AGenericDef:TDef;var AState: TSpecializationState);
    var
      lUsedUnit : TUsedUnit;
      lModule : TModule;
      lUnitSyms : TFPHashObjectList;
      lSym : TSym;
      lSymTable : TSymTable;
      lIndex : Integer;
      lName : String;

    begin
      if not Assigned(AGenericDef) then
        InternalError(200705151);
      { Setup symtablestack at definition time
        to get types right, however this is not perfect, we should probably record
        the resolved symbols }
      AState.OldSymTableStack:=SymTableStack;
      AState.OldExtendedDefs:=CurrentModule.ExtendedDefs;
      AState.OldGenericDummySyms:=CurrentModule.GenericDummySyms;
      AState.OldCurrentGenericDef:=CurrentGenericDef;
      AState.OldSpecializeState:=PSpecializationState(CurrentModule.SpecializeState);
      AState.OldOpToken:=OpToken;
      OpToken:=NOTOKEN;
      CurrentModule.SpecializeState:=@AState;
      CurrentModule.ExtendedDefs:=TFPHashObjectList.Create(true);
      CurrentModule.GenericDummySyms:=TFPHashObjectList.Create(true);
      SymTableStack:=TDefAwareSymTableStack.Create;
      if not Assigned(AGenericDef.owner) then
        lModule:=CurrentModule
      else
        lModule:=Find_Module_From_SymTable(AGenericDef.owner);
      if lModule=nil then
        InternalError(200705152);
      { collect all unit syms in the generic's unit as we need to establish
        their unitsym.module link again so that unit identifiers can be used }
      lUnitSyms:=TFPHashObjectList.Create(false);
      if (lModule<>CurrentModule) and Assigned(lModule.GlobalSymTable) then
        for lIndex:=0 to lModule.GlobalSymTable.SymList.count-1 do
          begin
            lSym:=TSym(lModule.GlobalSymTable.SymList[lIndex]);
            if lSym.typ=UnitSym then
              begin
              lName:=lSym.realname;
              if (Copy(lName,1,7)='$hidden') then
                Delete(lName,1,7);
              lUnitSyms.add(upper(lName),lSym);
              end;
          end;
      { add all units if we are specializing inside the current unit (as the
        generic could have been declared in the implementation part), but load
        only interface units, if we are in a different unit as then the generic
        needs to be in the interface section }
      lUsedUnit:=TUsedUnit(lModule.UsedUnitList.first);
      while Assigned(lUsedUnit) do
        begin
          if not Assigned(lUsedUnit.u.GlobalSymTable) then
            { in certain circular, but valid unit constellations it can happen
              that we specialize a generic in a different unit that was used
              in the implementation section of the generic's unit and were the
              interface is still being parsed and thus the localsymtable is in
              reality the global symtable

              In addition to that it can also be the case that neither the
              global- nor the localsymtable is set, namely when the compiler
              didn't yet have the chance to process on of the units in the
              (implementation) uses clause simply due to the orders, so don't
              add anything of that unit yet (once routine bodies need to be
              specialized everything needed should be in place however). }
            if lUsedUnit.u.InInterface then
              begin
                if Assigned(lUsedUnit.u.LocalSymTable) then
                  SymTableStack.push(lUsedUnit.u.LocalSymTable)
              end
            else
              InternalError(200705153)
          else
            SymTableStack.push(lUsedUnit.u.GlobalSymTable);
          lSym:=TSym(lUnitSyms.find(lUsedUnit.u.ModuleName^));
          if Assigned(lSym) and not Assigned(TUnitSym(lSym).module) then
            TUnitSym(lSym).module:=lUsedUnit.u;
          lUsedUnit:=TUsedUnit(lUsedUnit.next);
        end;
      lUnitSyms.free;
      lUnitSyms := nil;
      if Assigned(lModule.GlobalSymTable) then
        SymTableStack.push(lModule.GlobalSymTable);
      lSymTable:=AGenericDef.owner;
      { push the localsymtable if needed }
      if ((lModule<>CurrentModule) or not CurrentModule.InInterface)
          and Assigned(lModule.LocalSymTable) then
        SymTableStack.push(lModule.LocalSymTable);
      { also push the symtables of all owning types }
      while Assigned(lSymTable) and (lSymTable.SymTableType in [objectsymtable,recordsymtable]) do
        begin
          SymTableStack.push(lSymTable);
          if Assigned(lSymTable.DefOwner) then
            lSymTable:=lSymTable.DefOwner.owner
          else
            lSymTable:=nil;
        end;
    end;

    procedure SpecializationDone(var AState: TSpecializationState);
    begin
      { Restore symtablestack }
      CurrentModule.ExtendedDefs.free;
      CurrentModule.ExtendedDefs:=AState.OldExtendedDefs;
      CurrentModule.GenericDummySyms.free;
      CurrentModule.GenericDummySyms:=AState.OldGenericDummySyms;
      CurrentModule.SpecializeState:=AState.OldSpecializeState;
      OpToken:=AState.OldOpToken;
      SymTableStack.free;
      SymTableStack:=AState.OldSymTableStack;
      { clear the state record to be on the safe side }
      fillchar(AState, sizeof(AState), 0);
    end;


{****************************************************************************
                      SPECIALIZATION BODY GENERATION
****************************************************************************}


    procedure ProcessProcDef(ADef:TProcDef;AModule:TModule);
      var
        lOldCurrentFilePos : TFilePosInfo;
      begin
        if Assigned(ADef.GenericDef) and
            (ADef.GenericDef.typ=procdef) and
            Assigned(TProcDef(ADef.GenericDef).GenericTokenBuf) then
          begin
            if not Assigned(TProcDef(ADef.GenericDef).GenericTokenBuf) then
              InternalError(2015061902);
            lOldCurrentFilePos:=CurrentFilePos;
            CurrentFilePos:=TProcDef(ADef.GenericDef).fileinfo;
            { use the index the module got from the current compilation process }
            CurrentFilePos.moduleindex:=AModule.ModuleID;
            CurrentTokenPos:=CurrentFilePos;
            CurrentScanner.StartReplayTokens(TProcDef(ADef.GenericDef).GenericTokenBuf);
            Read_Proc_Body(ADef);
            CurrentFilePos:=lOldCurrentFilePos;
          end
        { synthetic routines will be implemented afterwards }
        else if ADef.SyntheticKind=tsk_none then
          MessagePos1(ADef.fileinfo,sym_e_forward_not_resolved,ADef.FullProcName(false));
      end;


    function ProcessAbstractRecordDef(ADef:TAbstractRecordDef):Boolean;
      var
        lIndex  : LongInt;
        lMemberDef : TDef;
        lModule : TModule;
      begin
        Result:=true;
        lModule:=nil;
        if Assigned(ADef.GenericDef) then
          lModule:=Find_Module_From_SymTable(ADef.GenericDef.owner)
        else if not (df_internal in ADef.DefOptions) then
          InternalError(201202041);
        for lIndex:=0 to ADef.SymTable.DefList.Count-1 do
          begin
            lMemberDef:=TDef(ADef.SymTable.DefList[lIndex]);
            if lMemberDef.typ=procdef then
             begin
               { only generate the code if we need a body }
               if Assigned(TProcDef(lMemberDef).struct) and not TProcDef(lMemberDef).ForwardDef then
                 continue;
               { and the body is available already (which is implicitly the
                 case if the generic routine is part of another unit) }
               if (
                    not Assigned(lModule) or
                    (lModule=CurrentModule) or
                    (lModule.state=ms_compile)
                  ) and
                  { may not be assigned in case it's a synthetic procdef that
                    still needs to be generated }
                  (Assigned(TProcDef(lMemberDef).GenericDef) and
                  TProcDef(TProcDef(lMemberDef).GenericDef).ForwardDef)
                  { when the implementation of the module was not yet parsed, it will not yet have a generictokenbuf }
                  or not Assigned(TProcDef(TProcDef(lMemberDef).GenericDef).GenericTokenBuf) then

                 begin
                   Result:=false;
                   continue;
                 end;
               ProcessProcDef(TProcDef(lMemberDef),lModule);
             end
           else
             if lMemberDef.typ in [objectdef,recorddef] then
               { generate code for subtypes as well }
               Result:=ProcessAbstractRecordDef(TAbstractRecordDef(lMemberDef)) and Result;
         end;
      end;


    procedure GenerateSpecializationProcs;
      var
        lIndex : LongInt;
        lList,
        lReAddList : TFPObjectList;
        lDef : TStoredDef;
        lState : TSpecializationState;
        lModule : TModule;

      begin
        { first copy all entries and then work with that list to ensure that
          we don't get an infinite recursion }
        lList:=TFPObjectList.Create(false);
        lReAddList:=TFPObjectList.Create(false);

        lList.Capacity:=CurrentModule.PendingSpecializations.Count;
        for lIndex:=0 to CurrentModule.PendingSpecializations.Count-1 do
          lList.add(CurrentModule.PendingSpecializations.Items[lIndex]);

        CurrentModule.PendingSpecializations.clear;

        for lIndex:=0 to lList.count-1 do
          begin
            lDef:=TStoredDef(lList[lIndex]);
            if not TStoredDef(lDef).Is_Specialization then
              continue;
            case lDef.typ of
              procdef:
                begin
                  { the use of forwarddef should not backfire as the
                    specialization always belongs to the current module }
                  if not TProcDef(lDef).ForwardDef then
                    continue;
                  if not Assigned(lDef.GenericDef) then
                    InternalError(2015061903);
                  lModule:=Find_Module_From_SymTable(lDef.GenericDef.owner);
                  if lModule=nil then
                    InternalError(2015061904);
                  { we need to check for a forward declaration only if the
                    generic was declared in the same unit (otherwise there
                    should be one) }
                  if ((lModule=CurrentModule) and TProcDef(lDef.GenericDef).ForwardDef)
                      or ((lModule<>CurrentModule) and (lModule.state<ms_compiling_waitfinish)) then
                    begin
                      lReAddList.add(lDef);
                      continue;
                    end;

                  SpecializationInit(TStoredDef(lDef).GenericDef,lState);

                  ProcessProcDef(TProcDef(lDef),lModule);

                  SpecializationDone(lState);
                end;
              recorddef,
              objectdef:
                begin
                  SpecializationInit(TStoredDef(lDef).GenericDef,lState);

                  if not ProcessAbstractRecordDef(TAbstractRecordDef(lDef)) then
                    lReAddList.add(lDef);

                  SpecializationDone(lState);
                end;
              else
                ;
            end;
          end;

        { add those defs back to the pending list for which we don't yet have
          all method bodies }
        for lIndex:=0 to lReAddList.count-1 do
          CurrentModule.PendingSpecializations.add(TStoredDef(lReAddList[lIndex]).TypeName,lReAddList[lIndex]);

        lReAddList.free;
        lReAddList := nil;
        lList.free;
        lList := nil;
      end;


    procedure GenerateSpecializationsForForwardDef(ADef:TDef);
      var
        lList : TFPObjectList;
        lIdx,
        lIndex : LongInt;
        lContext : TSpecializationContext;
      begin
        if not TStoredDef(ADef).Is_Generic then
          InternalError(2020070304);
        lIdx:=CurrentModule.ForwardGenericDefs.findindexof(ADef.FullTypeName);
        if lIdx<0 then
          exit;
        lList:=TFPObjectList(CurrentModule.ForwardGenericDefs.items[lIdx]);
        if not Assigned(lList) then
          InternalError(2020070305);
        for lIndex:=0 to lList.count-1 do begin
          lContext:=TSpecializationContext(lList[lIndex]);
          GenerateSpecializationPhase2(lContext,TStoredDef(ADef),false,'');
        end;
        CurrentModule.ForwardGenericDefs.delete(lIdx);
      end;


    procedure MaybeAddPendingSpecialization(ADef:TDef;AUnnamedSyms: TFPList);
      var
        lModule : TModule;
        lSymTable : TSymTable;
      begin
        if ParseGeneric then
          exit;
        { transfer ownership of any unnamed syms to be the specialization }
        if AUnnamedSyms<>nil then
          TransferUnnamedSymbols(TProcDef(ADef).ParaST,AUnnamedSyms);
        lSymTable:=ADef.owner;
        while lSymTable.SymTableType in [LocalSymTable] do
          lSymTable:=lSymTable.DefOwner.owner;
        lModule:=Find_Module_From_SymTable(lSymTable);
        if TStoredDef(ADef).Is_Specialization and (lModule=CurrentModule) then
          CurrentModule.PendingSpecializations.add(ADef.TypeName,ADef);
      end;


    function DetermineGenericDef(const AName:TIDString):TStoredDef;
      var
        lHashedID : THashedIDString;
        lProcDef : TProcDef;
        lSym : TSym;
      begin
        Result:=nil;
        { check whether this is a declaration of a type inside a
          specialization }
        if Assigned(CurrentStructDef) and
            (df_specialization in CurrentStructDef.DefOptions) then
          begin
            if not Assigned(CurrentStructDef.GenericDef) or
                not (CurrentStructDef.GenericDef.typ in [recorddef,objectdef]) then
              InternalError(2011052301);
            lHashedID.id:=AName;
            { we could be inside a method of the specialization
              instead of its declaration, so check that first (as
              local nested types aren't allowed we don't need to
              walk the symtablestack to find the localsymtable) }
            if SymTableStack.top.SymTableType=LocalSymTable then
              begin
                { we are in a method }
                if not Assigned(SymTableStack.top.DefOwner) or
                    (SymTableStack.top.DefOwner.typ<>procdef) then
                  InternalError(2011120701);
                lProcDef:=TProcDef(SymTableStack.top.DefOwner);
                if not Assigned(lProcDef.GenericDef) or (lProcDef.GenericDef.typ<>procdef) then
                  InternalError(2011120702);
                lSym:=TSym(TProcDef(lProcDef.GenericDef).LocalST.findwithhash(lHashedID));
              end
            else
              lSym:=nil;
            if not Assigned(lSym) or not (lSym.typ=TypeSym) then
              begin
                { now search in the declaration of the generic }
                lSym:=TSym(TAbstractRecordDef(CurrentStructDef.GenericDef).SymTable.findwithhash(lHashedID));
                if not Assigned(lSym) or not (lSym.typ=TypeSym) then
                  InternalError(2011052302);
              end;
            { use the corresponding type in the generic's symtable as
              genericdef for the specialized type }
            Result:=TStoredDef(TTypeSym(lSym).TypeDef);
          end;
      end;


end.
