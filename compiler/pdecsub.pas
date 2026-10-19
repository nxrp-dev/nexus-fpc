{
    Copyright (c) 1998-2002 by Florian Klaempfl, Daniel Mantione

    Does the parsing of the procedures/functions

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
unit pdecsub;

{$i fpcdefs.inc}

interface

    uses
      { common }
      CClasses,
      { scanner }
      tokens,
      { symtable }
      symconst,symtype,symdef,SymSym;

    type
      TPDFlag=(
        pdBody,         { directive needs a body }
        pdImplemen,     { directive can be used in implementation section }
        pdInterface,    { directive can be used in interface section }
        pdObject,       { directive can be used with object declaration }
        pdRecord,       { directive can be used with record declaration }
        pdProcVar,      { directive can be used with procvar declaration }
        pdNotObject,    { directive can not be used with object declaration }
        pdNotRecord,    { directive can not be used with record declaration }
        pdNotObjIntf,   { directive can not be used with interface declaration }
        pdNotProcVar,   { directive can not be used with procvar declaration }
        pdDispInterface,{ directive can be used with dispinterface methods }
        pdCPPObject,    { directive can be used with cppclass }
        pdObjCClass,    { directive can be used with objcclass }
        pdObjCProt,     { directive can be used with objcprotocol }
        pdNotHelper     { directive can not be used with record/class helper declaration }
      );
      TPDFlags=set of TPDFlag;

      TParseProcFlag=(
        ppfClassMethod,
        ppfGeneric,
        ppfAnonymous
      );
      TParseProcFlags=set of TParseProcFlag;

    function  CheckProcDirective(AIsProcVar:Boolean):Boolean;

    function  ProcGetImportName(AProcDef:TProcDef):String;
    procedure ProcSetMangledName(AProcDef:TProcDef);

    procedure ParseParameterDec(AProcDef:TAbstractProcDef);
    procedure ParseProcDirectives(AProcDef:TAbstractProcDef;var APDFlags:TPDFlags);
    procedure ParseProcTypeDirectives(AProcOrInvokeDef:TDef);
    procedure ParseObjectProcDirectives(AProcDef:TProcDef);
    procedure ParseRecordProcDirectives(AProcDef:TProcDef);
    function  ParseProcHead(AStruct:TAbstractRecordDef;AProcType:TProcTypeOption;AFlags:TParseProcFlags;AGenericDef:TDef;AGenericTypeList:TFPHashObjectList;out AProcDef:TProcDef):Boolean;
    function  ParseProcDec(AFlags:TParseProcFlags;AStruct:TAbstractRecordDef):TProcDef;
    procedure ParseProcDecFinish(AProcDef:TProcDef;AFlags:TParseProcFlags;AStruct:TAbstractRecordDef);

    { parse a record method declaration (not a (class) constructor/destructor) }
    function ParseRecordMethodDec(AStruct: TAbstractRecordDef; AIsClassDef: Boolean;AHadGeneric:Boolean): TProcDef;

    { helper functions - they insert nested objects hierarchy to the symtablestack
      with object hierarchy
    }
    function PushChildHierarchy(AObjectDef:TAbstractRecordDef):Integer;
    function PopChildHierarchy(AObjectDef:TAbstractRecordDef):Integer;
    function PushNestedHierarchy(AObjectDef:TAbstractRecordDef):Integer;
    function PopNestedHierarchy(AObjectDef:TAbstractRecordDef):Integer;

implementation

    uses
       SysUtils,
       { common }
       CUtils,
       { global }
       GlobType,Globals,Verbose,ConstExp,
       Systems,
       CPUInfo,
       { assembler }
       aasmbase,
       { symtable }
       SymBase,symcpu,SymTable,symutil,defutil,defcmp,
       { parameter handling }
       paramgr,cpupara,
       { pass 1 }
       FModule,node,htypechk,ncon,nld,
       objcutil,
       { parser }
       Scanner,
       pbase,pexpr,ptype,pdecl,pparautl,pgenutil
       ;

    const
      { Please leave this here, this module should NOT use
        these variables.
        Declaring it as string here results in an error when compiling (PFV) }
      CurrentProcInfo = 'error';

    function PushChildHierarchy(AObjectDef:TAbstractRecordDef):Integer;
      var
        lClass,lPreviousClass : TObjectDef;
      begin
        if AObjectDef.typ=recorddef then
          begin
            SymTableStack.push(AObjectDef.SymTable);
            Result:=1;
            exit;
          end;
        Result:=0;
        { insert class hierarchy in the reverse order }
        lPreviousClass:=nil;
        repeat
          lClass:=TObjectDef(AObjectDef);
          while lClass.ChildOf<>lPreviousClass do
            lClass:=lClass.ChildOf;
          lPreviousClass:=lClass;
          SymTableStack.push(lClass.SymTable);
          inc(Result);
        until lPreviousClass=AObjectDef;
      end;

    function PushNestedHierarchy(AObjectDef:TAbstractRecordDef):Integer;
      begin
        Result:=0;
        if AObjectDef.owner.SymTableType in [ObjectSymtable,recordsymtable] then
          inc(Result,PushNestedHierarchy(TAbstractRecordDef(AObjectDef.owner.DefOwner)));
        inc(Result,PushChildHierarchy(AObjectDef));
      end;

    function PopChildHierarchy(AObjectDef:TAbstractRecordDef):Integer;
      var
        lClass : TObjectDef;
      begin
        if AObjectDef.typ=recorddef then
          begin
            SymTableStack.pop(AObjectDef.SymTable);
            Result:=1;
            exit;
          end;
        Result:=0;
        lClass:=TObjectDef(AObjectDef);
        while Assigned(lClass) do
          begin
            SymTableStack.pop(lClass.SymTable);
            lClass:=lClass.ChildOf;
            inc(Result);
          end;
      end;

    function PopNestedHierarchy(AObjectDef:TAbstractRecordDef):Integer;
      begin
        Result:=PopChildHierarchy(AObjectDef);
        if AObjectDef.owner.SymTableType in [ObjectSymtable,recordsymtable] then
          inc(Result,PopNestedHierarchy(TAbstractRecordDef(AObjectDef.owner.DefOwner)));
      end;


    procedure CheckMsgPara(AObject:TObject;AArg:Pointer);
      begin
        if (TSym(AObject).typ<>paravarsym) then
         exit;
        with TParaVarSym(AObject) do
          begin
            { Count parameters }
            if (ParaNr>=10) then
              inc(PLongInt(AArg)^);
            { First parameter must be var }
            if (ParaNr=10) and
               (VarSpez<>vs_var) then
              MessagePos(fileinfo,parser_e_ill_msg_param);
          end;
      end;


    procedure ParseParameterDec(AProcDef:TAbstractProcDef);
      {
        handle_procvar needs the same changes
      }
      type
        TPPV = (pvNone,pvProc,pvFunc);
      var
        lSymbols      : TFPObjectList;
        lDef    : TDef;
        lArrayElementDef : TDef;
        lParaVarSym      : TParaVarSym;
        lIndex       : LongInt;
        lSearchSym   : TSym;
        lProcVarDef      : TProcVarDef;
        lVarSpez : TVarSpez;
        lDefaultValue : TConstSym;
        lDefaultRequired : Boolean;
        lOldBlockType : TBlockType;
        lCurrentParaST : TParaSymTable;
        lParseProcVar : TPPV;
        lParaNr : Integer;
        lNeedArray,
        lIsUniv: Boolean;
        lTypeOptions : TSingleTypeOptions;

        procedure HandleDefaultParaValue;
          var
            lConvertProcDef : TProcDef;
            lConversion : TConvertType;
            lNodeType : TNodeType;
            lBlockType : TBlockType;
          begin
            { only allowed for types that can be represented by a
              constant expression }
            if TryToConsume(_EQ) then
             begin
               if (lDef.typ in [recorddef,variantdef,filedef,formaldef]) or
                  Is_Object(lDef) or
                  ((lDef.typ=arraydef) and
                   not Is_Dynamic_Array(lDef)) then
                 Message1(type_e_invalid_default_value,FullTypeName(lDef,nil));
               lParaVarSym:=TParaVarSym(lSymbols[0]);
               if lSymbols.count>1 then
                 Message(parser_e_default_value_only_one_para);
               if not(lParaVarSym.VarSpez in [vs_value,vs_const,vs_constref]) then
                 Message(parser_e_default_value_val_const);
               lBlockType:=Block_Type;
               Block_Type:=bt_const;
               { prefix 'def' to the parameter name }
               lDefaultValue:=ReadConstant('$def'+lParaVarSym.name,lParaVarSym.fileinfo,lNodeType);
               Block_Type:=lBlockType;
               if Assigned(lDefaultValue) then
                 begin
                   include(lDefaultValue.SymOptions,sp_internal);
                   AProcDef.ParaST.InsertSym(lDefaultValue);
                   { check whether the default value is of the correct
                     type }
                   if Compare_Defs_Ext(lDefaultValue.ConstDef,lDef,lNodeType,lConversion,lConvertProcDef,[])<=te_convert_operator then
                     MessagePos2(lDefaultValue.fileinfo,type_e_incompatible_types,FullTypeName(lDefaultValue.ConstDef,lDef),FullTypeName(lDef,lDefaultValue.ConstDef));
                 end;
               lDefaultRequired:=true;
             end
            else
             begin
               if lDefaultRequired then
                 Message1(parser_e_default_value_expected_for_para,lParaVarSym.name);
             end;
          end;


      begin
        lOldBlockType:=Block_Type;
        Consume(_LKLAMMER);
        { Delphi/Kylix supports nonsense like }
        { procedure p();                      }
        if TryToConsume(_RKLAMMER) then
          exit;
        { parsing a proc or procvar ? }
        lCurrentParaST:=TParaSymTable(AProcDef.ParaST);
        { reset }
        lSymbols:=TFPObjectList.Create(false);
        lDefaultRequired:=false;
        lParaNr:=0;
        Block_Type:=bt_var;
        lIsUniv:=false;
        repeat
          lParseProcVar:=pvNone;
          if TryToConsume(_VAR) then
            lVarSpez:=vs_var
          else
            if TryToConsume(_CONST) then
              lVarSpez:=vs_const
          else
            if (m_out in CurrentSettings.ModeSwitches) and
               TryToConsume(_OUT) then
              lVarSpez:=vs_out
          else
           if TryToConsume(_CONSTREF) then
             lVarSpez:=vs_constref
          else
            if (m_mac in CurrentSettings.ModeSwitches) and
               TryToConsume(_POINTPOINTPOINT) then
              begin
                include(AProcDef.ProcOptions,po_varargs);
                break;
              end
          else
            if (m_nested_procvars in CurrentSettings.ModeSwitches) and
               TryToConsume(_PROCEDURE) then
              begin
                lParseProcVar:=pvProc;
                lVarSpez:=vs_const;
              end
          else
            if (m_nested_procvars in CurrentSettings.ModeSwitches) and
               TryToConsume(_FUNCTION) then
              begin
                lParseProcVar:=pvFunc;
                lVarSpez:=vs_const;
              end
          else
              lVarSpez:=vs_value;
          lDefaultValue:=nil;
          lDef:=nil;
          { read identifiers and insert with error type }
          lSymbols.clear;
          repeat
            inc(lParaNr);
            lParaVarSym:=CParaVarSym.Create(CurrentScanner.FOrgPattern,lParaNr*10,lVarSpez,GenErrorDef,[]);
            lCurrentParaST.InsertSym(lParaVarSym);
            if Assigned(lParaVarSym.owner) then
             lSymbols.add(lParaVarSym)
            else
             lParaVarSym.free; // no nil needed
            Consume(_ID);
          until not TryToConsume(_COMMA);
          { macpas anonymous procvar }
          if lParseProcVar<>pvNone then
           begin
             { inline procvar definitions are always nested procvars }
             lProcVarDef:=CProcVarDef.Create(NormalFunctionLevel+1,true);
             if CurrentScanner.FToken=_LKLAMMER then
               ParseParameterDec(lProcVarDef);
             if lParseProcVar=pvFunc then
              begin
                Block_Type:=bt_var_type;
                Consume(_COLON);
                SingleType(lProcVarDef.ReturnDef,[]);
                Block_Type:=bt_var;
              end;
             { possible proc directives }
             if CheckProcDirective(true) then
               ParseProcTypeDirectives(lProcVarDef);
             { Add implicit hidden parameters and function result }
             Handle_Calling_Convention(lProcVarDef,cHCCDefaultActionsIntf);
             lDef:=lProcVarDef;
           end
          else
          { read type declaration, force reading for value paras }
           if (CurrentScanner.FToken=_COLON) or (lVarSpez=vs_value) then
           begin
             Consume(_COLON);
             { check for an open array }
             lNeedArray:=false;
             { bitpacked open array are not yet supported }
             if (CurrentScanner.FToken=_PACKED) and
                not(cs_bitpacking in CurrentSettings.LocalSwitches) then
               begin
                 Consume(_PACKED);
                 lNeedArray:=true;
               end;
             if (CurrentScanner.FToken=_ARRAY) or
                lNeedArray then
              begin
                Consume(_ARRAY);
                Consume(_OF);
                { define range and type of range }
                lDef:=CArrayDef.Create_OpenArray;
                { array of const ? }
                if (CurrentScanner.FToken=_CONST) and (m_objpas in CurrentSettings.ModeSwitches) then
                 begin
                   Consume(_CONST);
                   lSearchSym:=Search_System_Type('TVARREC');
                   TArrayDef(lDef).ElementDef:=TTypeSym(lSearchSym).TypeDef;
                   include(TArrayDef(lDef).ArrayOptions,ado_IsArrayOfConst);
                 end
                else
                 begin
                   { define field type }
                   if m_delphi in CurrentSettings.ModeSwitches then
                     lTypeOptions:=[stoAllowSpecialization]
                   else
                     lTypeOptions:=[];
                   SingleType(lArrayElementDef,lTypeOptions);
                   if Assigned(lArrayElementDef.TypeSym) then
                     Check_Hints(lArrayElementDef.TypeSym,lArrayElementDef.TypeSym.SymOptions,lArrayElementDef.TypeSym.DeprecatedMsg);
                   TArrayDef(lDef).ElementDef:=lArrayElementDef;
                 end;
              end
             else
              begin
                if (m_mac in CurrentSettings.ModeSwitches) then
                  lIsUniv:=TryToConsume(_UNIV);

                { this is not really working and generates internal errors
                if try_to_consume(_TYPE) then
                  hdef:=ctypedformaltype
                else }
                  begin
                    Block_Type:=bt_var_type;
                    SingleType(lDef,[stoAllowSpecialization]);
                    Block_Type:=bt_var;
                  end;

                { open string ? }
                if Is_ShortString(lDef) then
                  begin
                    case lVarSpez of
                      vs_var,vs_out:
                        begin
                          { not 100% Delphi-compatible: type xstr=string[255] cannot
                            become an openstring there, while here it can }
                          if (cs_openstring in CurrentSettings.LocalSwitches) and
                             (TStringDef(lDef).len=255) then
                            lDef:=OpenShortStringType
                        end;
                      vs_value:
                       begin
                         { value "openstring" parameters don't make sense (the
                            original string can never be modified, so there's no
                            use in passing its original length), so change these
                            into regular shortstring parameters (seems to be what
                            Delphi also does) }
                        if Is_Open_String(lDef) then
                          lDef:=CShortStringType;
                       end;
                      else
                        ;
                    end;
                  end;

                { default parameter }
                if (m_default_para in CurrentSettings.ModeSwitches) then
                  HandleDefaultParaValue;
              end;
           end
          else
           lDef:=CFormalType;

          if Assigned(lDef.TypeSym) then
            Check_Hints(lDef.TypeSym,lDef.TypeSym.SymOptions,lDef.TypeSym.DeprecatedMsg);

          { File types are only allowed for var and out parameters }
          if (lDef.typ=filedef) and
             not(lVarSpez in [vs_out,vs_var]) then
            CGMessage(cg_e_file_must_call_by_reference);

          { Dispinterfaces are restricted to using only automatable types }
          if (AProcDef.typ=procdef) and Is_DispInterface(TProcDef(AProcDef).struct) and
             not Is_Automatable(lDef) then
            Message1(type_e_not_automatable,lDef.TypeName);

          { univ cannot be used with types whose size is not known at compile
            time }
          if lIsUniv and
             not Is_Valid_Univ_Para_Type(lDef) then
            Message1(parser_e_invalid_univ_para,lDef.TypeName);

          for lIndex:=0 to lSymbols.count-1 do
            begin
              lParaVarSym:=TParaVarSym(lSymbols[lIndex]);
              lParaVarSym.UnivPara:=lIsUniv;
              { update varsym }
              lParaVarSym.vardef:=lDef;
              lParaVarSym.DefaultConstSym:=lDefaultValue;

            end;
        until not TryToConsume(_SEMICOLON);

        { remove parasymtable from stack }
        lSymbols.free;
        lSymbols := nil;
        { reset object options }
        Block_Type:=lOldBlockType;
        Consume(_RKLAMMER);
      end;


    function ParseProcHead(AStruct:TAbstractRecordDef;AProcType:TProcTypeOption;AFlags:TParseProcFlags;AGenericDef:TDef;AGenericTypeList:TFPHashObjectList;out AProcDef:TProcDef):Boolean;
      var
        lText       : String;
        lOrgPattern,lPattern,lOrgPatternNonGen,lPatternNonGen : TIDString;
        lDummySym,lSearchSym : TSym;
        lCheckStack : PSymTableStackItem;
        lOldFilePos,
        lClassStartFilePos,
        lProcStartFilePos : TFilePosInfo;
        lIndex,
        lDirectiveIndex : LongInt;
        lAddGenDummy,
        lHadSpecialize,
        lFirstPart,
        lFound,
        lSearchAgain : Boolean;
        lSymTable,
        lInsertSymTable,
        lGenericSymTable: TSymTable;
        lProcSym : TProcSym;
        lPopClass : Integer;
        lParentDef : TObjectDef;
        lImplIntf : TImplementedInterface;
        lOldParseGeneric : Boolean;
        lOldCurrentStructDef: TAbstractRecordDef;
        lOldCurrentGenericDef,
        lOldCurrentSpecializeDef: TStoredDef;
        lLastToken,lLastIDToken: TToken;
        lGenericParams : TFPHashObjectList;

        procedure ParseOperatorName;
         begin
           if (lLastToken in [first_overloaded..last_overloaded]) then
            begin
              OpToken:=CurrentScanner.FToken;
            end
           else
            begin
              case lLastToken of
                _CARET:
                  Message1(parser_e_overload_operator_failed,'**');
                _ID:
                  case lLastIDToken of
                    _ENUMERATOR:OpToken:=_OP_ENUMERATOR;
                    _EXPLICIT:OpToken:=_OP_EXPLICIT;
                    _INC:OpToken:=_OP_INC;
                    _DEC:OpToken:=_OP_DEC;
                    _INITIALIZE:OpToken:=_OP_INITIALIZE;
                    _FINALIZE:OpToken:=_OP_FINALIZE;
                    _ADDREF:OpToken:=_OP_ADDREF;
                    _COPY:OpToken:=_OP_COPY;
                    else
                    if (m_delphi in CurrentSettings.ModeSwitches) then
                      case lLastIDToken of
                        _IMPLICIT:OpToken:=_ASSIGNMENT;
                        _NEGATIVE:OpToken:=_MINUS;
                        _POSITIVE:OpToken:=_PLUS;
                        _LOGICALNOT:OpToken:=_OP_NOT;
                        _IN:OpToken:=_OP_IN;
                        _EQUAL:OpToken:=_EQ;
                        _NOTEQUAL:OpToken:=_NE;
                        _GREATERTHAN:OpToken:=_GT;
                        _GREATERTHANOREQUAL:OpToken:=_GTE;
                        _LESSTHAN:OpToken:=_LT;
                        _LESSTHANOREQUAL:OpToken:=_LTE;
                        _ADD:OpToken:=_PLUS;
                        _SUBTRACT:OpToken:=_MINUS;
                        _MULTIPLY:OpToken:=_STAR;
                        _DIVIDE:OpToken:=_SLASH;
                        _INTDIVIDE:OpToken:=_OP_DIV;
                        _MODULUS:OpToken:=_OP_MOD;
                        _LEFTSHIFT:OpToken:=_OP_SHL;
                        _RIGHTSHIFT:OpToken:=_OP_SHR;
                        _LOGICALAND:OpToken:=_OP_AND;
                        _LOGICALOR:OpToken:=_OP_OR;
                        _LOGICALXOR:OpToken:=_OP_XOR;
                        _BITWISEAND:OpToken:=_OP_AND;
                        _BITWISEOR:OpToken:=_OP_OR;
                        _BITWISEXOR:OpToken:=_OP_XOR;
                        else
                          Message1(parser_e_overload_operator_failed,'');
                      end
                    else
                      Message1(parser_e_overload_operator_failed,'');
                  end
                else
                  Message1(parser_e_overload_operator_failed,'');
              end;
            end;
           lPattern:=Overloaded_Names[OpToken];
           lOrgPattern:=lPattern;
           lPatternNonGen:=lPattern;
           lOrgPatternNonGen:=lOrgPattern;
         end;

        procedure ConsumeProcName;
          var
            lText : String;
            lIndex : LongInt;
            lTypeSym : TTypeSym;
          begin
            lLastToken:=CurrentScanner.FToken;
            lLastIDToken:=CurrentScanner.FIDToken;
            if Assigned(lGenericParams) then
              for lIndex:=0 to lGenericParams.count-1 do
                begin
                  lTypeSym:=TTypeSym(lGenericParams[lIndex]);
                  if (lTypeSym.typ<>constsym) and TStoredDef(lTypeSym.TypeDef).IsRegistered then
                    begin
                      lTypeSym.TypeDef.free;
                      lTypeSym.TypeDef:=nil;
                    end;
                  lTypeSym.free;
                  lTypeSym := nil;
                end;
            lGenericParams.free;
            lGenericParams:=nil;
            lHadSpecialize:=false;
            if AProcType=potype_operator then
              OpToken:=NOTOKEN;
            if (AProcType=potype_operator) and (CurrentScanner.FToken<>_ID) then
              begin
                ParseOperatorName;
                Consume(CurrentScanner.FToken);
              end
            else
              begin
                lPattern:=CurrentScanner.FPattern;
                lOrgPattern:=CurrentScanner.FOrgPattern;
                lPatternNonGen:=lPattern;
                lOrgPatternNonGen:=lOrgPattern;
                if lFirstPart and
                    not (m_delphi in CurrentSettings.ModeSwitches) and
                    (CurrentScanner.FIDToken=_SPECIALIZE) then
                  lHadSpecialize:=true;
                Consume(_ID);
                if ((ppfGeneric in AFlags) or (m_delphi in CurrentSettings.ModeSwitches)) and
                    (CurrentScanner.FToken in [_LT,_LSHARPBRACKET]) then
                  begin
                    Consume(CurrentScanner.FToken);
                    if CurrentScanner.FToken in [_GT,_RSHARPBRACKET] then
                      message(type_e_type_id_expected)
                    else
                      begin
                        lGenericParams:=ParseGenericParameters(true);
                        if not Assigned(lGenericParams) then
                          InternalError(2015061201);
                        if lGenericParams.count=0 then
                          InternalError(2015061202);
                        lText:='';
                        str(lGenericParams.count,lText);
                        lPatternNonGen:=lPattern;
                        lOrgPatternNonGen:=lOrgPattern;
                        lPattern:=lPattern+'$'+lText;
                        lOrgPattern:=lOrgPattern+'$'+lText;
                      end;
                    if not TryToConsume(_GT) then
                      Consume(_RSHARPBRACKET);
                  end;
              end;
            lFirstPart:=false;
          end;

        function SearchObjectName(const APattern:TIDString;AGenError:Boolean):TSym;
          var
            lSavedPos:TFilePosInfo;
            lSearchSymTable:TSymTable;
          begin
            lSavedPos:=CurrentTokenPos;
            CurrentTokenPos:=lProcStartFilePos;
            SearchSym(APattern,Result,lSearchSymTable);
            if not Assigned(Result) then
              begin
                if AGenError then
                  IdentifierNotFound(lOrgPattern);
                Result:=GenErrorSym;
              end;
            CurrentTokenPos:=lSavedPos;
          end;

        function HandleGenericInterface:Boolean;
          var
            lIndex : LongInt;
            lTypeSym : TTypeSym;
            lTypeSearchSym : TSym;
            lTypeSearchSymTable : TSymTable;
            lHierarchy,
            lSpecializeName,
            lPrettyName: AnsiString;
            lError : Boolean;
            lGenName,
            lUpperGenName : TIDString;
            lModule : TModule;
          begin
            Result:=false;
            if not Assigned(lGenericParams) then
              exit;
            lSpecializeName:='$';
            lPrettyName:='';
            lError:=false;
            for lIndex:=0 to lGenericParams.count-1 do
              begin
                lTypeSym:=TTypeSym(lGenericParams[lIndex]);
                { ToDo: position }
                if not SearchSym(upper(lTypeSym.RealName),lTypeSearchSym,lTypeSearchSymTable) then
                  begin
                    message1(sym_e_id_not_found,lTypeSym.name);
                    lError:=true;
                    continue;
                  end;
                if lTypeSearchSym.typ<>TypeSym then
                  begin
                    message(type_e_type_id_expected);
                    lError:=true;
                    continue;
                  end;
                lModule:=Find_Module_From_SymTable(TTypeSym(lTypeSearchSym).TypeDef.owner);
                if not Assigned(lModule) then
                  InternalError(2016112803);
                lSpecializeName:=lSpecializeName+'_$'+HexStr(lModule.ModuleID,8)+'$$'+TTypeSym(lTypeSearchSym).TypeDef.UniqueIDStr;
                if lIndex>0 then
                  lPrettyName:=lPrettyName+',';
                lPrettyName:=lPrettyName+TTypeSym(lTypeSearchSym).prettyname;
              end;
            Result:=true;
            if lError then
              begin
                lSearchSym:=GenErrorSym;
                exit;
              end;

            if not SearchSym(lPattern,lTypeSearchSym,lTypeSearchSymTable) or (lTypeSearchSym.typ<>TypeSym) then
              begin
                IdentifierNotFound(lPattern);
                lSearchSym:=GenErrorSym;
                exit;
              end;

            lModule:=Find_Module_From_SymTable(TTypeSym(lTypeSearchSym).owner);
            if not Assigned(lModule) then
              InternalError(2022102105);

            lHierarchy:=TTypeSym(lTypeSearchSym).TypeDef.ownerhierarchyname;
            if lHierarchy<>'' then
              lHierarchy:='.'+lHierarchy;

            lGenName:=GenerateGenericName(lPattern,lSpecializeName,lModule.ModuleName^+lHierarchy);
            lUpperGenName:=upper(lGenName);

            lSearchSym:=SearchObjectName(lUpperGenName,false);
            if not Assigned(lSearchSym) then
              begin
                Message1(type_e_generic_declaration_does_not_match,lPattern+'<'+lPrettyName+'>');
                lSearchSym:=GenErrorSym;
              end;
          end;

        procedure SpecializeGenericInterface;
          var
            lNode : TNode;
          begin
            lNode:=Factor(false,[efTypeOnly,efHadSpecialize]);
            if lNode.nodetype=typen then
              begin
                lPattern:=TTypeNode(lNode).TypeDef.TypeSym.name;
              end
            else
              lPattern:='';
          end;

        function CheckGenericParameters(ADef:TStoredDef):Boolean;
          var
            lIndex : LongInt;
            lDeclSym,
            lImplSym : TSym;
            lImplType : TTypeSym absolute lImplSym;
            lImplName : TSymStr;
            lFileInfo : TFilePosInfo;
          begin
            Result:=true;
            if not Assigned(ADef.GenericParas) then
              InternalError(2018090102);
            if not Assigned(lGenericParams) then
              InternalError(2018090103);
            if ADef.GenericParas.count<>lGenericParams.count then
              InternalError(2018090104);
            for lIndex:=0 to ADef.GenericParas.count-1 do
              begin
                lDeclSym:=TSym(ADef.GenericParas[lIndex]);
                lImplSym:=TSym(lGenericParams[lIndex]);
                lImplName:=upper(lGenericParams.nameofindex(lIndex));
                if lDeclSym.name<>lImplName then
                  begin
                    messagepos1(lImplSym.fileinfo,sym_e_generic_type_param_mismatch,lImplSym.realname);
                    messagepos1(lDeclSym.fileinfo,sym_e_generic_type_param_decl,lDeclSym.realname);
                    Result:=false;
                  end;
                if ((lImplSym.typ=TypeSym) and (df_genconstraint in lImplType.TypeDef.DefOptions)) or
                    (lImplSym.typ=constsym) then
                  begin
                    if lImplSym.typ=constsym then
                      lFileInfo:=lImplType.fileinfo
                    else
                      lFileInfo:=TStoredDef(lImplType.TypeDef).GenConstraintData.fileinfo;
                    messagepos(lFileInfo,parser_e_generic_constraints_not_allowed_here);
                    Result:=false;
                  end;
              end;
          end;

      begin
        lPattern:='';
        lOrgPattern:='';
        lPatternNonGen:='';
        lOrgPatternNonGen:='';

        { Save the position where this procedure really starts }
        lProcStartFilePos:=CurrentTokenPos;
        lOldParseGeneric:=ParseGeneric;

        lFirstPart:=true;
        Result:=false;
        AProcDef:=nil;
        lProcSym:=nil;
        lSearchSym:=nil;
        lGenericParams:=nil;
        lHadSpecialize:=false;
        lAddGenDummy:=false;

        { ensure that we don't insert into a withsymtable (can happen with
          anonymous functions) }
        lCheckStack:=SymTableStack.stack;
        while lCheckStack^.SymTable.SymTableType in [withsymtable] do
          lCheckStack:=lCheckStack^.next;
        lInsertSymTable:=lCheckStack^.SymTable;

        if not Assigned(AGenericDef) then
          begin
            if ppfAnonymous in AFlags then
              begin
                if not (lInsertSymTable.SymTableType in [LocalSymTable,staticsymtable]) then
                  InternalError(2021050101);
                { generate a unique name for the anonymous function; don't use
                  something like file position however as this might be inside
                  an include file that's included multiple times }
                str(lInsertSymTable.SymList.count,lOrgPattern);
                lOrgPattern:='__FPCINTERNAL__Anonymous_'+lOrgPattern;
                lPattern:=upper(lOrgPattern);
                lPatternNonGen:=lPattern;
                lOrgPatternNonGen:=lOrgPattern;
              end
            else
              ConsumeProcName;

            { examine interface map: function/procedure iname.functionname=locfuncname }
            if Assigned(AStruct) and
               (AStruct.typ=objectdef) and
               Assigned(TObjectDef(AStruct).ImplementedInterfaces) and
               (TObjectDef(AStruct).ImplementedInterfaces.count>0) and
               (
                 (CurrentScanner.FToken=_POINT) or
                 (
                   lHadSpecialize and
                   (CurrentScanner.FToken=_ID)
                 )
               ) then
             begin
               if lHadSpecialize and (CurrentScanner.FToken=_ID) then
                 SpecializeGenericInterface;
               Consume(_POINT);
               if lHadSpecialize or not HandleGenericInterface then
                 lSearchSym:=SearchObjectName(lPattern,true);
               { qualifier is interface? }
               lImplIntf:=nil;
               if Assigned(lSearchSym) and
                  (lSearchSym.typ=TypeSym) and
                  (TTypeSym(lSearchSym).TypeDef.typ=objectdef) then
                 lImplIntf:=Find_Implemented_Interface(TObjectDef(AStruct),TObjectDef(TTypeSym(lSearchSym).TypeDef));
               if lImplIntf=nil then
                 begin
                   Message(parser_e_interface_id_expected);
                   { error recovery }
                   Consume(_ID);
                   if TryToConsume(_EQ) then
                     Consume(_ID);
                   exit;
                 end
               else
                 { in case of a generic or specialized interface we need to use the
                   name of the def instead of the symbol, so that always the correct
                   name is used }
                 if [df_generic,df_specialization]*TTypeSym(lSearchSym).TypeDef.DefOptions<>[] then
                   lPattern:=TObjectDef(TTypeSym(lSearchSym).TypeDef).ObjName^;
               { must be a directly implemented interface }
               if Assigned(lImplIntf.ImplementsGetter) then
                 Message2(parser_e_implements_no_mapping,lImplIntf.IntfDef.TypeName,AStruct.ObjRealName^);
               Consume(_ID);
               { Create unique name <interface>.<method> }
               lText:=lPattern+'.'+CurrentScanner.FPattern;
               Consume(_EQ);
               if Assigned(lImplIntf) and
                  (CurrentScanner.FToken=_ID) then
                 lImplIntf.AddMapping(lText,CurrentScanner.FPattern);
               Consume(_ID);
               Result:=true;
               exit;
             end;

            if Assigned(lGenericParams) and Assigned(CurrentGenericDef) then
              Message(parser_f_no_generic_inside_generic);

            { method  ? }
            lSearchSym:=nil;
            if not Assigned(AStruct) and
               (SymTableStack.top.SymTableLevel=MainProgramLevel) and
               TryToConsume(_POINT) then
             begin
               repeat
                 lClassStartFilePos:=lProcStartFilePos;
                 lSearchAgain:=false;

                 { throw the error at the right location }
                 lOldFilePos:=CurrentFilePos;
                 CurrentFilePos:=lProcStartFilePos;
                 if not Assigned(AStruct) and not Assigned(lSearchSym) then
                   lSearchSym:=SearchObjectName(lPattern,true);
                 CurrentFilePos:=lOldFilePos;

                 { we need to check whether the names of the generic parameter
                   types match with the one in the declaration of a class/record,
                   but we need to do this before consume_proc_name frees the
                   type parameters of the class part }
                 if (lSearchSym.typ=TypeSym) and
                     (TTypeSym(lSearchSym).TypeDef.typ in [objectdef,recorddef]) and
                     TStoredDef(TTypeSym(lSearchSym).TypeDef).Is_Generic and
                     Assigned(lGenericParams) then
                   { this is recoverable, so no further action necessary }
                   CheckGenericParameters(TStoredDef(TTypeSym(lSearchSym).TypeDef));

                 { consume proc name }
                 lProcStartFilePos:=CurrentTokenPos;
                 ConsumeProcName;
                 { qualifier is class name ? }
                 if (lSearchSym.typ=TypeSym) and
                    (TTypeSym(lSearchSym).TypeDef.typ in [objectdef,recorddef]) then
                  begin
                    AStruct:=TAbstractRecordDef(TTypeSym(lSearchSym).TypeDef);
                    if (CurrentScanner.FToken<>_POINT) then
                      if (AProcType in [potype_class_constructor,potype_class_destructor]) then
                        lPattern:=lower(lPattern)
                      else
                      if (AProcType=potype_operator) and (OpToken=NOTOKEN) then
                        ParseOperatorName;
                    lSearchSym:=TSym(AStruct.SymTable.Find(lPattern));
                    if Assigned(lSearchSym) then
                     begin
                       if lSearchSym.typ=ProcSym then
                         lProcSym:=TProcSym(lSearchSym)
                       else
                       if (lSearchSym.typ=TypeSym) and
                          (TTypeSym(lSearchSym).TypeDef.typ in [objectdef,recorddef]) then
                         begin
                           lSearchAgain:=true;
                           Consume(_POINT);
                         end
                       else
                         begin
                           {  we use a different error message for tp7 so it looks more compatible }
                           if (m_fpc in CurrentSettings.ModeSwitches) then
                             Message1(parser_e_overloaded_no_procedure,lSearchSym.realname)
                           else
                             Message(parser_e_methode_id_expected);
                           { rename the name to an unique name to avoid an
                             error when inserting the symbol in the symtable }
                           lOrgPattern:=lOrgPattern+'$'+ToStr(CurrentFilePos.line);
                         end;
                     end
                    else
                     begin
                       MessagePos(lProcStartFilePos,parser_e_methode_id_expected);
                       { recover by making it a normal procedure instead of method }
                       AStruct:=nil;
                     end;
                  end
                 else
                  MessagePos(lClassStartFilePos,parser_e_class_id_expected);
               until not lSearchAgain;
             end
            else
             begin
               { check for constructor/destructor/class operators which are not allowed here }
               if (not ParseOnly) and
                  ((AProcType in [potype_constructor,potype_destructor,
                               potype_class_constructor,potype_class_destructor]) or
                   ((AProcType=potype_operator) and (m_delphi in CurrentSettings.ModeSwitches))) then
                 Message(parser_e_only_methods_allowed);

               repeat
                 { only 1 class constructor and destructor is allowed in the class and
                   the check was already done with oo_has_class_constructor or
                   oo_has_class_destructor -> skip searching
                   (bug #28801) }
                 if (AProcType in [potype_class_constructor,potype_class_destructor]) then
                   break;

                 lSearchAgain:=false;
                 CurrentTokenPos:=lProcStartFilePos;

                 if (AProcType=potype_operator)and(OpToken=NOTOKEN) then
                   ParseOperatorName;

                 lSearchSym:=TSym(lInsertSymTable.Find(lPattern));

                 { Also look in the globalsymtable if we didn't found
                   the symbol in the localsymtable }
                 if not Assigned(lSearchSym) and
                    not(ParseOnly) and
                    (SymTableStack.top=CurrentModule.LocalSymTable) and
                    Assigned(CurrentModule.GlobalSymTable) then
                   lSearchSym:=TSym(CurrentModule.GlobalSymTable.Find(lPattern));

                 { if the symbol isn't assigned, but we're parsing a class or
                   object then check in the parent types for symbols of the same
                   name that are generics and declare the new symbol as a generic
                   dummy symbol }

                 if not Assigned(lSearchSym) and Is_Class_Or_Object(AStruct) then
                   begin
                     lParentDef:=TObjectDef(AStruct).ChildOf;
                     while Assigned(lParentDef) do
                       begin
                         lSearchSym:=TSym(lParentDef.SymTable.Find(lPattern));
                         if Assigned(lSearchSym) and (sp_generic_dummy in lSearchSym.SymOptions) then
                           begin
                             lAddGenDummy:=true;
                             break;
                           end;
                         lParentDef:=lParentDef.ChildOf;
                       end;
                     lSearchSym:=nil;
                   end;

                 { Check if overloaded is a procsym }
                 if Assigned(lSearchSym) then
                   begin
                     if lSearchSym.typ=ProcSym then
                       lProcSym:=TProcSym(lSearchSym)
                     else
                       begin
                         { when the other symbol is a unit symbol then hide the unit symbol }
                         if lSearchSym.typ=UnitSym then
                          begin
                            HideSym(lSearchSym);
                            lSearchAgain:=true;
                          end
                         else
                         if (m_delphi in CurrentSettings.ModeSwitches) and
                            (lSearchSym.typ=absolutevarsym) and
                            ([vo_is_funcret,vo_is_result]*TAbstractVarSym(lSearchSym).VarOptions=[vo_is_funcret]) then
                           begin
                             HideSym(lSearchSym);
                             lSearchAgain:=true;
                           end
                         else if (lSearchSym.typ=TypeSym) and
                             (sp_generic_dummy in lSearchSym.SymOptions) and
                             (TTypeSym(lSearchSym).TypeDef.typ=undefineddef) and
                             not Assigned(lGenericParams) then
                           begin
                             { this is a generic dummy symbol that has not yet
                               been used; so we rename the dummy symbol and continue
                               as if nothing happened }
                             HideSym(lSearchSym);
                             lSearchAgain:=true;
                             lAddGenDummy:=true;
                           end
                         else
                          begin
                            {  we use a different error message for tp7 so it looks more compatible }
                            if (m_fpc in CurrentSettings.ModeSwitches) then
                              Message1(parser_e_overloaded_no_procedure,lSearchSym.realname)
                            else
                              Message1(sym_e_duplicate_id,lSearchSym.realname);
                            { rename the name to an unique name to avoid an
                              error when inserting the symbol in the symtable }
                            lOrgPattern:=lOrgPattern+'$'+ToStr(CurrentFilePos.line);
                          end;
                       end;
                  end;
               until not lSearchAgain;
             end;

            { test again if assigned, it can be reset to recover }
            if not Assigned(lProcSym) then
              begin
                { create a new procsym and set the real filepos }
                CurrentTokenPos:=lProcStartFilePos;
                { for operator we have only one procsym for each overloaded
                  operation }
                if (AProcType=potype_operator) then
                  begin
                    lProcSym:=TProcSym(lInsertSymTable.Find(lPattern));
                    if lProcSym=nil then
                      lProcSym:=CProcSym.Create('$'+lPattern);
                  end
                else
                if (AProcType in [potype_class_constructor,potype_class_destructor]) then
                  lProcSym:=CProcSym.Create('$'+lower(lPattern))
                else
                  lProcSym:=CProcSym.Create(lOrgPattern);
                if ppfAnonymous in AFlags then
                  include(lProcSym.SymOptions,sp_internal);
                if lAddGenDummy then
                  include(lProcSym.SymOptions,sp_generic_dummy);
                lInsertSymTable.InsertSym(lProcSym);
              end;
          end;

        { to get the correct symtablelevel we must ignore ObjectSymtables }
        lSymTable:=nil;
        lCheckStack:=SymTableStack.stack;
        while Assigned(lCheckStack) do
          begin
            lSymTable:=lCheckStack^.SymTable;
            if lSymTable.SymTableType in [staticsymtable,GlobalSymTable,LocalSymTable] then
              break;
            lCheckStack:=lCheckStack^.next;
          end;
        AProcDef:=CProcDef.Create(lSymTable.SymTableLevel+1,not Assigned(AGenericDef));
        AProcDef.struct:=AStruct;
        AProcDef.ProcSym:=lProcSym;
        AProcDef.ProcTypeOption:=AProcType;
        if ppfAnonymous in AFlags then
          begin
            include(AProcDef.ProcOptions,po_anonymous);
            { inherit the "static" and "class" flag from the method the anonymous function
              is contained in }
            if (lSymTable.SymTableType=LocalSymTable) and
                (lSymTable.DefOwner.typ=procdef) and
                ([po_staticmethod,po_classmethod]*TProcDef(lSymTable.DefOwner).ProcOptions<>[]) then
              AProcDef.ProcOptions:=AProcDef.ProcOptions+([po_staticmethod,po_classmethod]*TProcDef(lSymTable.DefOwner).ProcOptions);
          end;

        if Assigned(lGenericParams) then
          begin
            if AProcType=potype_constructor then
              begin
                Message(parser_e_constructors_cannot_take_type_parameters);
                lGenericParams.free;
                lGenericParams:=nil;
              end
            else
              begin
                include(AProcDef.DefOptions,df_generic);
                { push the parameter symtable so that constraint definitions are added
                  there and not in the owner symtable }
                SymTableStack.push(AProcDef.ParaST);
                { register the parameters }
                for lIndex:=0 to lGenericParams.count-1 do
                  begin
                     TSym(lGenericParams[lIndex]).RegisterSym;
                     if TSym(lGenericParams[lIndex]).typ=TypeSym then
                       TStoredDef(TTypeSym(lGenericParams[lIndex]).TypeDef).RegisterDef;
                  end;
                InsertGenericParameterTypes(AProcDef,nil,lGenericParams,false);
                { the list is no longer required }
                lGenericParams.free;
                lGenericParams:=nil;
                SymTableStack.pop(AProcDef.ParaST);
                ParseGeneric:=true;
                { also generate a dummy symbol if none exists already }
                if Assigned(AStruct) then
                  lDummySym:=TSym(AStruct.SymTable.find(lPatternNonGen))
                else
                  begin
                    lDummySym:=TSym(lInsertSymTable.find(lPatternNonGen));
                    if not Assigned(lDummySym) and
                        (SymTableStack.top=CurrentModule.LocalSymTable) and
                        Assigned(CurrentModule.GlobalSymTable) then
                      lDummySym:=TSym(CurrentModule.GlobalSymTable.find(lPatternNonGen));
                  end;
                if not Assigned(lDummySym) then
                  begin
                    { overloading generic routines with non-generic types is not
                      allowed, so we create a procsym as dummy }
                    lDummySym:=CProcSym.Create(lOrgPatternNonGen);
                    if Assigned(AStruct) then
                      AStruct.SymTable.InsertSym(lDummySym)
                    else
                      lInsertSymTable.InsertSym(lDummySym);
                  end
                else if (lDummySym.typ<>ProcSym) and
                    (
                      { show error only for the declaration, not also the implementation }
                      not Assigned(AStruct) or
                      (SymTableStack.top.SymTableLevel<>MainProgramLevel)
                    ) then
                  Message1(sym_e_duplicate_id,lDummySym.realname);
                if not (sp_generic_dummy in lDummySym.SymOptions) then
                  begin
                    include(lDummySym.SymOptions,sp_generic_dummy);
                    AddGenericDummySym(lDummySym,'');
                  end;
                if lDummySym.typ=ProcSym then
                  TProcSym(lDummySym).Add_Generic_Overload(lProcSym);
                { start token recorder for the declaration }
                AProcDef.Init_GenericDecl;
                CurrentScanner.StartRecordTokens(AProcDef.GenericDeclTokenBuf);
              end;
          end
        else if Assigned(AGenericDef) then
          InsertGenericParameterTypes(AProcDef,TStoredDef(AGenericDef),AGenericTypeList,false);

        { methods inherit df_generic or df_specialization from the objectdef }
        if Assigned(AProcDef.struct) and
           (AProcDef.ParaST.SymTableLevel=NormalFunctionLevel) then
          begin
            if (df_generic in AProcDef.struct.DefOptions) then
              begin
                include(AProcDef.DefOptions,df_generic);
                ParseGeneric:=true;
              end;
            if (df_specialization in AProcDef.struct.DefOptions) then
              begin
                if Assigned(CurrentSpecializeDef) then
                  begin
                    include(AProcDef.DefOptions,df_specialization);
                    { Find corresponding genericdef, we need it later to
                      replay the tokens to generate the body }
                    if not Assigned(AProcDef.struct.GenericDef) then
                      InternalError(200512113);
                    lGenericSymTable:=AProcDef.struct.GenericDef.GetSymTable(gs_record);
                    if not Assigned(lGenericSymTable) then
                      InternalError(200512114);

                    { when searching for the correct procdef to use as genericdef we need to ignore
                      everything except procdefs so that we can find the correct indices }
                    lDirectiveIndex:=0;
                    lFound:=false;
                    for lIndex:=0 to AProcDef.owner.DefList.count-1 do
                      begin
                        if TDef(AProcDef.owner.DefList[lIndex]).typ<>procdef then
                          continue;
                        if AProcDef.owner.DefList[lIndex]=AProcDef then
                          begin
                            lFound:=true;
                            break;
                          end;
                        inc(lDirectiveIndex);
                      end;
                    if not lFound then
                      InternalError(2014052301);

                    for lIndex:=0 to lGenericSymTable.DefList.count-1 do
                      begin
                        if TDef(lGenericSymTable.DefList[lIndex]).typ<>procdef then
                          continue;
                        if lDirectiveIndex=0 then
                          AProcDef.GenericDef:=TStoredDef(lGenericSymTable.DefList[lIndex]);
                        dec(lDirectiveIndex);
                      end;

                    if not Assigned(AProcDef.GenericDef) or
                       (AProcDef.GenericDef.typ<>procdef) then
                      InternalError(200512115);
                  end
                else
                  Message(parser_e_explicit_method_implementation_for_specializations_not_allowed);
              end;
          end;

        { methods need to be exported }
        if Assigned(AStruct) and
           (
            (SymTableStack.top.SymTableType in [ObjectSymtable,recordsymtable]) or
            (SymTableStack.top.SymTableLevel=MainProgramLevel)
           ) then
          include(AProcDef.ProcOptions,po_global);

        { symbol options that need to be kept per procdef }
        AProcDef.fileinfo:=lProcStartFilePos;
        AProcDef.visibility:=lInsertSymTable.CurrentVisibility;
        if lInsertSymTable.CurrentlyOptional then
          include(AProcDef.ProcOptions,po_optional);

        { parse parameters }
        if CurrentScanner.FToken=_LKLAMMER then
          begin
            lOldCurrentStructDef:=nil;
            lOldCurrentGenericDef:=CurrentGenericDef;
            lOldCurrentSpecializeDef:=nil;
            { Add ObjectSymtable to be able to find nested type definitions }
            lPopClass:=0;
            if Assigned(AProcDef.struct) and
               (AProcDef.ParaST.SymTableLevel>=NormalFunctionLevel) and
               not(SymTableStack.top.SymTableType in [ObjectSymtable,recordsymtable]) then
              begin
                lPopClass:=PushNestedHierarchy(AProcDef.struct);
                lOldCurrentStructDef:=CurrentStructDef;
                lOldCurrentSpecializeDef:=CurrentSpecializeDef;
                CurrentStructDef:=AProcDef.struct;
                if Assigned(CurrentStructDef) and (df_generic in CurrentStructDef.DefOptions) then
                  CurrentGenericDef:=CurrentStructDef;
                if Assigned(CurrentStructDef) and (df_specialization in CurrentStructDef.DefOptions) then
                  CurrentSpecializeDef:=CurrentStructDef;
              end;
            if AProcDef.Is_Generic then
              CurrentGenericDef:=AProcDef;
            { Add parameter symtable }
            if AProcDef.ParaST.SymTableType<>staticsymtable then
              SymTableStack.push(AProcDef.ParaST);
            ParseParameterDec(AProcDef);
            if AProcDef.ParaST.SymTableType<>staticsymtable then
              SymTableStack.pop(AProcDef.ParaST);
            CurrentGenericDef:=lOldCurrentGenericDef;
            if lPopClass>0 then
              begin
                CurrentStructDef:=lOldCurrentStructDef;
                CurrentSpecializeDef:=lOldCurrentSpecializeDef;
                dec(lPopClass,PopNestedHierarchy(AProcDef.struct));
                if lPopClass<>0 then
                  InternalError(201011260); // 11 nov 2010 index 0
              end;
          end;

        ParseGeneric:=lOldParseGeneric;
        Result:=true;
      end;


    procedure ParseProcDecFinish(AProcDef:TProcDef;AFlags:TParseProcFlags;AStruct:TAbstractRecordDef);
      var
        lIndex: Integer;
        lFound: Boolean;

        procedure ReadReturnDef(AProcDef: TProcDef);
          var
            lPopClass: Integer;
            lOldParseGeneric: Boolean;
            lOldCurrentStructDef: TAbstractRecordDef;
            lOldCurrentGenericDef,
            lOldCurrentSpecializeDef: TStoredDef;
          begin
            lOldParseGeneric:=ParseGeneric;
            { Add ObjectSymtable to be able to find generic type definitions }
            lPopClass:=0;
            lOldCurrentStructDef:=nil;
            lOldCurrentGenericDef:=CurrentGenericDef;
            lOldCurrentSpecializeDef:=CurrentSpecializeDef;
            CurrentGenericDef:=nil;
            CurrentSpecializeDef:=nil;
            if Assigned(AProcDef.struct) and
               (AProcDef.ParaST.SymTableLevel>=NormalFunctionLevel) and
               not (SymTableStack.top.SymTableType in [ObjectSymtable,recordsymtable]) then
              begin
                lPopClass:=PushNestedHierarchy(AProcDef.struct);
                lOldCurrentStructDef:=CurrentStructDef;
                CurrentStructDef:=AProcDef.struct;
              end;
            if df_generic in AProcDef.DefOptions then
              begin
                if AProcDef.Is_Generic then
                  CurrentGenericDef:=AProcDef
                else if Assigned(AProcDef.struct) then
                  CurrentGenericDef:=AProcDef.struct
                else
                  InternalError(2016090202);
              end;
            if df_specialization in AProcDef.DefOptions then
              begin
                if AProcDef.Is_Specialization then
                  CurrentSpecializeDef:=AProcDef
                else if Assigned(AProcDef.struct) then
                  CurrentSpecializeDef:=AProcDef.struct
                else
                  InternalError(2016090203);
              end;
            ParseGeneric:=(df_generic in AProcDef.DefOptions);
            if AProcDef.Is_Generic or AProcDef.Is_Specialization then
              SymTableStack.push(AProcDef.ParaST);
            AProcDef.ReturnDef:=ResultType([stoAllowSpecialization]);

            // Issue #24863, enabled only for the main progra commented out for now because it breaks building of RTL and needs extensive
// testing and/or RTL patching.
{
            if ((pd.returndef=cvarianttype) or (pd.returndef=colevarianttype)) and
               not(cs_compilesystem in current_settings.moduleswitches) then
              include(current_module.moduleflags,mf_uses_variants);
}
            if Is_DispInterface(AProcDef.struct) and not Is_Automatable(AProcDef.ReturnDef) then
              Message1(type_e_not_automatable,AProcDef.ReturnDef.TypeName);

            if Assigned(AProcDef.ReturnDef.TypeSym) then
              Check_Hints(AProcDef.ReturnDef.TypeSym,AProcDef.ReturnDef.TypeSym.SymOptions,AProcDef.ReturnDef.TypeSym.DeprecatedMsg);

            if AProcDef.Is_Generic or AProcDef.Is_Specialization then
              SymTableStack.pop(AProcDef.ParaST);
            if lPopClass>0 then
              begin
                CurrentStructDef:=lOldCurrentStructDef;
                dec(lPopClass,PopNestedHierarchy(AProcDef.struct));
                if lPopClass<>0 then
                  InternalError(201012020);
              end;
            CurrentGenericDef:=lOldCurrentGenericDef;
            CurrentSpecializeDef:=lOldCurrentSpecializeDef;
            ParseGeneric:=lOldParseGeneric;
          end;

      begin
        case AProcDef.ProcTypeOption of
          potype_procedure:
            begin
              AProcDef.ReturnDef:=VoidType;
              if ppfClassMethod in AFlags then
                include(AProcDef.ProcOptions,po_classmethod);
            end;
          potype_function:
            begin
              if po_anonymous in AProcDef.ProcOptions then
                begin
                  { allow a different result name for anonymous functions (especially
                    for modes without Result modeswitch), but for consistency with
                    operators we allow this in other modes as well }
                  if CurrentScanner.FToken<>_ID then
                    begin
                       if not(m_result in CurrentSettings.ModeSwitches) then
                         Consume(_ID);
                    end
                  else
                    begin
                      AProcDef.ResultName:=StringDup(CurrentScanner.FOrgPattern);
                      Consume(_ID);
                    end;
                end;
              if TryToConsume(_COLON) then
               begin
                 ReadReturnDef(AProcDef);
               end
              else
               begin
                  if (
                      ParseOnly and
                      not(Is_Interface(AProcDef.struct))
                     ) or
                     (m_repeat_forward in CurrentSettings.ModeSwitches) then
                  begin
                    Consume(_COLON);
                    ConsumeAllUntil(_SEMICOLON);
                  end;
               end;
              if ppfClassMethod in AFlags then
               include(AProcDef.ProcOptions,po_classmethod);
            end;
          potype_constructor,
          potype_class_constructor:
            begin
              if not (ppfClassMethod in AFlags) and
                 Assigned(AProcDef) and
                 Assigned(AProcDef.struct) then
                begin
                  { Set return type, class constructors return the
                    created instance, object constructors return boolean }
                  if Is_Class(AProcDef.struct) or
                     Is_Record(AProcDef.struct) then
                    AProcDef.ReturnDef:=AProcDef.struct
                  else
                    if Is_ObjectPascal_Helper(AProcDef.struct) then
                      AProcDef.ReturnDef:=TObjectDef(AProcDef.struct).ExtendedDef
                    else
{$ifdef CPU64bitaddr}
                      AProcDef.ReturnDef:=Bool64Type;
{$else CPU64bitaddr}
                      AProcDef.ReturnDef:=Bool32Type;
{$endif CPU64bitaddr}
                end
              else
                AProcDef.ReturnDef:=VoidType;
            end;
          potype_class_destructor,
          potype_destructor:
            begin
              if Assigned(AProcDef) then
                AProcDef.ReturnDef:=VoidType;
            end;
          potype_operator:
            begin
              { operators always need to be searched in all units (that
                contain operators) }
              include(AProcDef.ProcOptions,po_overload);
              AProcDef.ProcSym.owner.IncludeOption(sto_has_operator);
              if AProcDef.ParaST.SymTableLevel>NormalFunctionLevel then
                Message(parser_e_no_local_operator);
              if ppfClassMethod in AFlags then
                begin
                  include(AProcDef.ProcOptions,po_classmethod);
                  { any class operator is also static }
                  include(AProcDef.ProcOptions,po_staticmethod);
                end;
              if CurrentScanner.FToken<>_ID then
                begin
                   if not(m_result in CurrentSettings.ModeSwitches) then
                     Consume(_ID);
                end
              else
                begin
                  AProcDef.ResultName:=StringDup(CurrentScanner.FOrgPattern);
                  Consume(_ID);
                end;
              { operators without result (management operators) }
              if OpToken in [_OP_INITIALIZE, _OP_FINALIZE, _OP_ADDREF, _OP_COPY] then
                begin
                  { single var parameter to point the record }
                  if (OpToken in [_OP_INITIALIZE, _OP_FINALIZE, _OP_ADDREF]) and
                     (
                      (AProcDef.ParaST.SymList.Count<>1) or
                      (TParaVarSym(AProcDef.ParaST.SymList[0]).vardef<>AProcDef.struct) or
                      (TParaVarSym(AProcDef.ParaST.SymList[0]).VarSpez<>vs_var)
                     ) then
                    Message(parser_e_overload_impossible)
                  { constref (source) and var (dest) parameter to point the records }
                  else if (OpToken=_OP_COPY) and
                     (
                      (AProcDef.ParaST.SymList.Count<>2) or
                      (TParaVarSym(AProcDef.ParaST.SymList[0]).vardef<>AProcDef.struct) or
                      (TParaVarSym(AProcDef.ParaST.SymList[0]).VarSpez<>vs_constref) or
                      (TParaVarSym(AProcDef.ParaST.SymList[1]).vardef<>AProcDef.struct) or
                      (TParaVarSym(AProcDef.ParaST.SymList[1]).VarSpez<>vs_var)
                     ) then
                    Message(parser_e_overload_impossible);

                  TRecordSymTable(AProcDef.ProcSym.Owner).IncludeManagementOperator(
                    Token2ManagementOperator(OpToken));
                  AProcDef.ReturnDef:=VoidType
                end
              else
                if not TryToConsume(_COLON) then
                  begin
                    Consume(_COLON);
                    AProcDef.ReturnDef:=GenErrorDef;
                    ConsumeAllUntil(_SEMICOLON);
                  end
                else
                 begin
                   ReadReturnDef(AProcDef);
                   { check that class operators have either return type of structure or }
                   { at least one argument of that type                                 }
                   if (po_classmethod in AProcDef.ProcOptions) and
                      (AProcDef.ReturnDef <> AProcDef.struct) then
                     begin
                       lFound:=false;
                       for lIndex := 0 to AProcDef.ParaST.SymList.Count - 1 do
                         if TParaVarSym(AProcDef.ParaST.SymList[lIndex]).vardef=AProcDef.struct then
                           begin
                             lFound:=true;
                             break;
                           end;
                       if not lFound then
                         if Assigned(AProcDef.struct) then
                           Message1(parser_e_at_least_one_argument_must_be_of_type,AProcDef.struct.RTTIName)
                         else
                           MessagePos(AProcDef.fileinfo,type_e_type_id_expected);
                     end;
                   if not Assigned(AProcDef.struct) or Assigned(AStruct) then
                     begin
                       if (OpToken in [_ASSIGNMENT,_OP_EXPLICIT]) and
                          Equal_Defs(AProcDef.ReturnDef,TParaVarSym(AProcDef.ParaST.SymList[0]).vardef) and
                          (AProcDef.ReturnDef.typ<>undefineddef) and (TParaVarSym(AProcDef.ParaST.SymList[0]).vardef.typ<>undefineddef) then
                         message(parser_e_no_such_assignment)
                       else if not IsOperatorAcceptable(AProcDef,OpToken) then
                         Message(parser_e_overload_impossible);
                     end;
                 end;
            end;
          else
            InternalError(2015052202);
        end;

        if (AProcDef.ProcCallOption in CDecl_PoCalls) and
           (AProcDef.paras.count>0) and
           Is_Array_Of_Const(TParaVarSym(AProcDef.paras[AProcDef.paras.count-1]).vardef) then
          begin
            include(AProcDef.ProcOptions,po_variadic);
          end;

        { support procedure proc stdcall export; }
        if not(CheckProcDirective(false)) then
          begin
            if (CurrentScanner.FToken=_COLON) and not(Assigned(AProcDef) and Is_Void(AProcDef.ReturnDef)) then
              begin
                message(parser_e_field_not_allowed_here);
                ConsumeAllUntil(_SEMICOLON);
              end;
            if not (ppfAnonymous in AFlags) then
              Consume(_SEMICOLON);
          end;

      end;

    function ParseProcDec(AFlags:TParseProcFlags;AStruct:TAbstractRecordDef):TProcDef;
      var
        lProcDef : TProcDef;
        lOldBlockType : TBlockType;
        lRecover : Boolean;

        procedure FinishIntfMapping;
          begin
            if CurrentScanner.FToken=_COLON then
              begin
                message(parser_e_field_not_allowed_here);
                ConsumeAllUntil(_SEMICOLON);
              end;
            Consume(_SEMICOLON);
          end;

      begin
        lProcDef:=nil;
        lRecover:=false;
        case CurrentScanner.FToken of
          _FUNCTION :
            begin
              Consume(_FUNCTION);
              if ParseProcHead(AStruct,potype_function,AFlags,nil,nil,lProcDef) then
                begin
                  { pd=nil when it is a interface mapping }
                  if Assigned(lProcDef) then
                    ParseProcDecFinish(lProcDef,AFlags,AStruct)
                  else
                    FinishIntfMapping;
                end
              else
                begin
                  { recover }
                  Consume(_COLON);
                  ConsumeAllUntil(_SEMICOLON);
                  lRecover:=true;
                end;
            end;

          _PROCEDURE :
            begin
              Consume(_PROCEDURE);
              if ParseProcHead(AStruct,potype_procedure,AFlags,nil,nil,lProcDef) then
                begin
                  { pd=nil when it is an interface mapping }
                  if Assigned(lProcDef) then
                    ParseProcDecFinish(lProcDef,AFlags,AStruct)
                  else
                    FinishIntfMapping;
                end
              else
                lRecover:=true;
            end;

          _CONSTRUCTOR :
            begin
              Consume(_CONSTRUCTOR);
              if ppfClassMethod in AFlags then
                lRecover:=not ParseProcHead(AStruct,potype_class_constructor,[],nil,nil,lProcDef)
              else
                lRecover:=not ParseProcHead(AStruct,potype_constructor,[],nil,nil,lProcDef);
              if not lRecover then
                ParseProcDecFinish(lProcDef,AFlags,AStruct);
            end;

          _DESTRUCTOR :
            begin
              Consume(_DESTRUCTOR);
              if ppfClassMethod in AFlags then
                lRecover:=not ParseProcHead(AStruct,potype_class_destructor,[],nil,nil,lProcDef)
              else
                lRecover:=not ParseProcHead(AStruct,potype_destructor,[],nil,nil,lProcDef);
              if not lRecover then
                ParseProcDecFinish(lProcDef,AFlags,AStruct);
            end;
        else
          if (CurrentScanner.FToken=_OPERATOR) or
             ((ppfClassMethod in AFlags) and (CurrentScanner.FIDToken=_OPERATOR)) then
            begin
              { we need to set the block type to bt_body, so that operator names
                like ">", "=>" or "<>" are parsed correctly instead of e.g.
                _LSHARPBRACKET and _RSHARPBRACKET for "<>" }
              lOldBlockType:=Block_Type;
              Block_Type:=bt_body;
              Consume(_OPERATOR);
              ParseProcHead(AStruct,potype_operator,[],nil,nil,lProcDef);
              Block_Type:=lOldBlockType;
              if Assigned(lProcDef) then
                ParseProcDecFinish(lProcDef,AFlags,AStruct)
              else
                begin
                  { recover }
                  TryToConsume(_ID);
                  Consume(_COLON);
                  ConsumeAllUntil(_SEMICOLON);
                  lRecover:=true;
                end;
            end;
        end;

        if lRecover and not(CheckProcDirective(false)) then
          begin
            if (CurrentScanner.FToken=_COLON) and not(Assigned(lProcDef) and Is_Void(lProcDef.ReturnDef)) then
              begin
                message(parser_e_field_not_allowed_here);
                ConsumeAllUntil(_SEMICOLON);
              end;
            if not (ppfAnonymous in AFlags) then
              Consume(_SEMICOLON);
          end;

        { we've parsed the final semicolon, so stop recording tokens }
        if Assigned(lProcDef) and
            (df_generic in lProcDef.DefOptions) and
            Assigned(lProcDef.GenericDeclTokenBuf) then
          CurrentScanner.StopRecordTokens;

        Result:=lProcDef;
      end;


    function ParseRecordMethodDec(AStruct: TAbstractRecordDef; AIsClassDef: Boolean;AHadGeneric:Boolean): TProcDef;
      var
        lOldParseOnly: Boolean;
        lFlags : TParseProcFlags;
      begin
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
            ParseRecordProcDirectives(Result);

            { since records have no inheritance, don't allow non-static
              class methods. Delphi does the same. }
            if (Result.ProcTypeOption<>potype_operator) and
               AIsClassDef and
               not (po_staticmethod in Result.ProcOptions) then
              MessagePos(Result.fileinfo, parser_e_class_methods_only_static_in_records);

            // we can't add hidden params here because record is not yet defined
            // and therefore record size which has influence on parameter passing rules may change too
            // look at record_dec to see where calling conventions are applied (issue #0021044)
            Handle_Calling_Convention(Result,cHCCDefaultActionsIntfStruct);

            { add definition to procsym }
            Proc_Add_Definition(Result);

            if Result.Is_Generic then
              AStruct.SymTable.IncludeOption(sto_has_generic);
          end;

        MaybeParseHintDirectives(Result);

        ParseOnly:=lOldParseOnly;
      end;


{****************************************************************************
                        Procedure directive handlers
****************************************************************************}

procedure PDCompilerProc(AProcDef:TAbstractProcDef);
var
  lValue : TConstExprInt;
begin
  { check for optional syssym index }
  if TryToConsume(_COLON) then
    begin
      lValue:=GetIntConst;
      if (lValue<Int64(low(LongInt))) or (lValue>Int64(high(LongInt))) then
        message3(type_e_range_check_error_bounds,ToStr(lValue),ToStr(low(LongInt)),ToStr(high(LongInt)))
      else if not Assigned(TSysSym.Find_By_Number(LongInt(lValue.svalue))) then
        message1(parser_e_invalid_internal_function_index,ToStr(lValue))
      else
        TProcDef(AProcDef).ExtNumber:=LongInt(lValue.svalue);
    end;
end;

procedure PDExport(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(200304264);
  if Assigned(TProcDef(AProcDef).struct) then
    Message(parser_e_methods_dont_be_export);
  if AProcDef.ParaST.SymTableLevel>NormalFunctionLevel then
    Message(parser_e_dont_nest_export);
end;

procedure PDForward(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(200304265);
  TProcDef(AProcDef).ForwardDef:=true;
end;


procedure PDAlias(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(200304266);
  Consume(_COLON);
  TProcDef(AProcDef).AliasNames.insert(GetStringConst);
  include(AProcDef.ProcOptions,po_has_public_name);
end;


procedure PDPublic(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(2003042601);
  if TryToConsume(_NAME) then
    begin
      TProcDef(AProcDef).AliasNames.insert(GetStringConst);
      include(AProcDef.ProcOptions,po_has_public_name);
    end;
end;


procedure PDAsmName(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(200304267);
  if CurrentScanner.FToken=_CCHAR then
    begin
      TProcDef(AProcDef).AliasNames.insert(TargetInfo.Cprefix+CurrentScanner.FPattern);
      Consume(_CCHAR)
    end
  else
    begin
      TProcDef(AProcDef).AliasNames.insert(TargetInfo.Cprefix+CurrentScanner.FCStringPattern);
      Consume(_CSTRING);
    end;
  { we don't need anything else }
  TProcDef(AProcDef).ForwardDef:=false;
end;


procedure PDInternConst(AProcDef:TAbstractProcDef);

var v:TConstExprInt;

begin
  if AProcDef.typ<>procdef then
    InternalError(200304268);
  Consume(_COLON);
  v:=GetIntConst;
  if (v<Int64(low(LongInt))) or (v>Int64(high(LongInt))) then
    message3(type_e_range_check_error_bounds,ToStr(v),ToStr(low(LongInt)),ToStr(high(LongInt)))
  else
    TProcDef(AProcDef).ExtNumber:=LongInt(v.svalue);
end;


procedure PDInternProc(AProcDef:TAbstractProcDef);

var v:TConstExprInt;

begin
  if AProcDef.typ<>procdef then
    InternalError(2003042602);
  Consume(_COLON);
  v:=GetIntConst;
  if (v<Int64(low(LongInt))) or (v>Int64(high(LongInt))) then
    message3(type_e_range_check_error_bounds,ToStr(v),ToStr(low(LongInt)),ToStr(high(LongInt)))
  else
    TProcDef(AProcDef).ExtNumber:=LongInt(v.svalue);
  { the proc is defined }
  TProcDef(AProcDef).ForwardDef:=false;
end;

procedure PDInterrupt(AProcDef:TAbstractProcDef);
begin
  if AProcDef.ParaST.SymTableLevel>NormalFunctionLevel then
    Message(parser_e_dont_nest_interrupt);
end;

procedure PDAbstract(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(200304269);
  if Is_ObjectPascal_Helper(TProcDef(AProcDef).struct) then
    Message1(parser_e_not_allowed_in_helper, arraytokeninfo[_ABSTRACT].str);
  if Assigned(TProcDef(AProcDef).struct) and
    (oo_is_sealed in TProcDef(AProcDef).struct.ObjectOptions) then
    Message(parser_e_sealed_class_cannot_have_abstract_methods)
  else if (po_virtualmethod in AProcDef.ProcOptions) then
    begin
      include(AProcDef.ProcOptions,po_abstractmethod);
      { one more abstract method }
      inc(TObjectDef(AProcDef.owner.DefOwner).AbstractCnt);
    end
  else
    Message(parser_e_only_virtual_methods_abstract);
  { the method is defined }
  TProcDef(AProcDef).ForwardDef:=false;
end;

procedure PDFinal(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(200910170);
  if Is_ObjectPascal_Helper(TProcDef(AProcDef).struct) and
      (m_objfpc in CurrentSettings.ModeSwitches) then
    Message1(parser_e_not_allowed_in_helper, arraytokeninfo[_FINAL].str);
  if (po_virtualmethod in AProcDef.ProcOptions) then
    include(AProcDef.ProcOptions,po_finalmethod)
  else
    Message(parser_e_only_virtual_methods_final);
end;

procedure PDEnumerator(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(200910250);
  if (CurrentScanner.FToken = _ID) then
  begin
    if CurrentScanner.FPattern='MOVENEXT' then
    begin
      if oo_has_enumerator_movenext in TProcDef(AProcDef).struct.ObjectOptions then
        message(parser_e_only_one_enumerator_movenext);
      AProcDef.CalcParas;
      if (AProcDef.ProcTypeOption = potype_function) and Is_Boolean(AProcDef.ReturnDef) and
         (AProcDef.MinParaCount = 0) then
      begin
        include(TProcDef(AProcDef).struct.ObjectOptions, oo_has_enumerator_movenext);
        include(AProcDef.ProcOptions,po_enumerator_movenext);
      end
      else
        Message(parser_e_enumerator_movenext_is_not_valid)
    end
    else
      Message1(parser_e_invalid_enumerator_identifier, CurrentScanner.FPattern);
    Consume(CurrentScanner.FToken);
  end
  else
    Message(parser_e_enumerator_identifier_required);
end;

procedure PDVirtual(AProcDef:TAbstractProcDef);
begin
  if Assigned(AProcDef.owner) and
     (po_external in AProcDef.ProcOptions) then
    Message2(parser_e_proc_dir_conflict,'EXTERNAL','"VIRTUAL"');

  if AProcDef.typ<>procdef then
    InternalError(2003042610);
  if (AProcDef.ProcTypeOption=potype_constructor) and
     Is_Object(TProcDef(AProcDef).struct) then
    Message(parser_e_constructor_cannot_be_not_virtual);
  if AProcDef.Is_Generic then
    message(parser_e_genfuncs_cannot_be_virtual);
  if Is_ObjectPascal_Helper(TProcDef(AProcDef).struct) and
      (m_objfpc in CurrentSettings.ModeSwitches) then
    Message1(parser_e_not_allowed_in_helper, arraytokeninfo[_VIRTUAL].str);
end;


procedure PDDispID(AProcDef:TAbstractProcDef);

var pt:TNode;

begin
  if AProcDef.typ<>procdef then
    InternalError(200604301);
  pt:=CompExpr([efAcceptEqual]);
  if Is_ConstIntNode(pt) then
    if (TOrdConstNode(pt).Value<Int64(low(LongInt))) or (TOrdConstNode(pt).Value>Int64(high(LongInt))) then
      message3(type_e_range_check_error_bounds,ToStr(TOrdConstNode(pt).Value),ToStr(low(LongInt)),ToStr(high(LongInt)))
    else
      TProcDef(AProcDef).DispID:=TOrdConstNode(pt).Value.svalue
  else
    message(parser_e_dispid_must_be_ord_const);
  pt.free;
  pt := nil;
end;


procedure PDStatic(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(2013032001);
  if not Assigned(TProcDef(AProcDef).struct) then
    InternalError(2013032002);
  include(TProcDef(AProcDef).ProcSym.SymOptions,sp_static);
  { "static" is not allowed for operators or normal methods (except in objects) }
  if (AProcDef.ProcTypeOption=potype_operator) or
      (
        not (po_classmethod in AProcDef.ProcOptions) and
        not Is_Object(TProcDef(AProcDef).struct)
      )
      then
    Message1(parser_e_dir_not_allowed,arraytokeninfo[_STATIC].str);
  include(AProcDef.ProcOptions,po_staticmethod);
end;

procedure PDOverride(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(2003042611);
  if Is_ObjectPascal_Helper(TProcDef(AProcDef).struct) then
    begin
      if m_objfpc in CurrentSettings.ModeSwitches then
        Message1(parser_e_not_allowed_in_helper, arraytokeninfo[_OVERRIDE].str)
    end
  else if not(Is_Class_Or_Interface_Or_ObjC(TProcDef(AProcDef).struct)) then
    Message(parser_e_no_object_override)
  else if Is_ObjCCategory(TProcDef(AProcDef).struct) then
    Message(parser_e_no_category_override)
  else if (po_external in AProcDef.ProcOptions) and
          not Is_ObjC_Class_Or_Protocol(TProcDef(AProcDef).struct) and
          not Is_CPPClass(TProcDef(AProcDef).struct) then
    Message2(parser_e_proc_dir_conflict,'OVERRIDE','"EXTERNAL"');
end;

procedure PDOverload(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(2003042612);
  include(TProcDef(AProcDef).ProcSym.SymOptions,sp_has_overloaded);
end;

procedure PDMessage(AProcDef:TAbstractProcDef);
var
  lNode : TNode;
  lParaCount : LongInt;
begin
  if AProcDef.typ<>procdef then
    InternalError(2003042613);
  if Is_ObjectPascal_Helper(TProcDef(AProcDef).struct) then
    begin
      if m_objfpc in CurrentSettings.ModeSwitches then
        Message1(parser_e_not_allowed_in_helper, arraytokeninfo[_MESSAGE].str);
    end
  else
    if not Is_Class(TProcDef(AProcDef).struct) and
       not Is_ObjC_Class_Or_Protocol(TProcDef(AProcDef).struct) then
      Message(parser_e_msg_only_for_classes);
  if ([po_msgstr,po_msgint]*AProcDef.ProcOptions)<>[] then
    Message(parser_e_multiple_messages);
  { check parameter type }
  if not Is_ObjC_Class_Or_Protocol(TProcDef(AProcDef).struct) then
    begin
      if po_external in AProcDef.ProcOptions then
        Message2(parser_e_proc_dir_conflict,'MESSAGE','"EXTERNAL"');
      lParaCount:=0;
      AProcDef.ParaST.SymList.ForEachCall(@CheckMsgPara,@lParaCount);
      if lParaCount<>1 then
        Message(parser_e_ill_msg_param);
    end;
  lNode:=CompExpr([efAcceptEqual]);
  { message is 1-character long }
  if Is_ConstCharNode(lNode) then
    begin
      include(AProcDef.ProcOptions,po_msgstr);
      TProcDef(AProcDef).MessageInf.str:=StringDup(chr(Byte(TOrdConstNode(lNode).Value.uvalue and $FF)));
    end
  else if lNode.nodetype=stringconstn then
    begin
      include(AProcDef.ProcOptions,po_msgstr);
      if (TStringConstNode(lNode).len>255) then
        Message(parser_e_message_string_too_long);
      TProcDef(AProcDef).MessageInf.str:=StringDup(TStringConstNode(lNode).AsConstPChar);
    end
  else
   if Is_ConstIntNode(lNode) and
      (Is_Class(TProcDef(AProcDef).struct) or
      Is_ObjectPascal_Helper(TProcDef(AProcDef).struct)) then
    begin
      include(AProcDef.ProcOptions,po_msgint);
      if (TOrdConstNode(lNode).Value<Int64(low(TProcDef(AProcDef).MessageInf.i))) or
         (TOrdConstNode(lNode).Value>Int64(high(TProcDef(AProcDef).MessageInf.i))) then
        message3(type_e_range_check_error_bounds,ToStr(TOrdConstNode(lNode).Value),ToStr(low(TProcDef(AProcDef).MessageInf.i)),ToStr(high(TProcDef(AProcDef).MessageInf.i)))
      else
        TProcDef(AProcDef).MessageInf.i:=TOrdConstNode(lNode).Value.svalue;
    end
  else
    Message(parser_e_ill_msg_expr);
  { check whether the selector name is valid in case of Objective-C }
  if (po_msgstr in AProcDef.ProcOptions) and
     Is_ObjC_Class_Or_Protocol(TProcDef(AProcDef).struct) and
     not ObjCValidSelectorName(@TProcDef(AProcDef).MessageInf.str^[1],length(TProcDef(AProcDef).MessageInf.str^)) then
    Message1(type_e_invalid_objc_selector_name,TProcDef(AProcDef).MessageInf.str^);
  lNode.free;
  lNode := nil;
end;


procedure PDReintroduce(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(200401211);
  if Is_ObjectPascal_Helper(TProcDef(AProcDef).struct) then
    begin
      if m_objfpc in CurrentSettings.ModeSwitches then
        Message1(parser_e_not_allowed_in_helper, arraytokeninfo[_REINTRODUCE].str);
    end
  else
    if not(Is_Class_Or_Interface_Or_Object(TProcDef(AProcDef).struct)) and
       not(Is_ObjCCategory(TProcDef(AProcDef).struct)) then
      Message(parser_e_no_object_reintroduce);
end;


procedure PDExternal(AProcDef:TAbstractProcDef);
{
  If import_dll=nil the procedure is assumed to be in another
  object file. In that object file it should have the name to
  which import_name is pointing to. Otherwise, the procedure is
  assumed to be in the DLL to which import_dll is pointing to. In
  that case either import_nr<>0 or import_name<>nil is true, so
  the procedure is either imported by number or by name. (DM)
}
var
  lLibraryName : String;
  lValue:TConstExprInt;
begin
  if AProcDef.typ<>procdef then
    InternalError(2003042615);
  with TProcDef(AProcDef) do
    begin
      ForwardDef:=false;
      { forbid local external procedures }
      if ParaST.SymTableLevel>NormalFunctionLevel then
        Message(parser_e_no_local_proc_external);
      { If the procedure should be imported from a DLL, a constant string follows.
        This isn't really correct, an contant string expression follows
        so we check if an semicolon follows, else a string constant have to
        follow (FK) }
      if not(CurrentScanner.FToken=_SEMICOLON) and not(CurrentScanner.FIDToken=_NAME) then
        begin
          { Always add library prefix and suffix to create an uniform name }
          lLibraryName:=GetStringConst;
          if ExtractFileExt(lLibraryName)='' then
            lLibraryName:=ChangeFileExt(lLibraryName,TargetInfo.sharedlibext);
          if Copy(lLibraryName,1,length(TargetInfo.sharedlibprefix))<>TargetInfo.sharedlibprefix then
            lLibraryName:=TargetInfo.sharedlibprefix+lLibraryName;
          ImportDLL:=StringDup(lLibraryName);
          include(ProcOptions,po_has_importdll);
          if (CurrentScanner.FIDToken=_NAME) then
           begin
             Consume(_NAME);
             ImportName:=StringDup(GetStringConst);
             include(ProcOptions,po_has_importname);
             if ImportName^='' then
               message(parser_e_empty_import_name);
           end;
          if (CurrentScanner.FIDToken=_INDEX) then
           begin
             {After the word index follows the index number in the DLL.}
             Consume(_INDEX);
             lValue:=GetIntConst;
             if (lValue<Int64(low(ImportNr))) or (lValue>Int64(high(ImportNr))) then
               message(parser_e_range_check_error)
             else
               ImportNr:=LongInt(lValue.svalue);
           end;
          if (CurrentScanner.FIDToken=_SUSPENDING) then
           begin
             message(parser_e_suspending_externals_not_supported_on_current_platform);
             Consume(_SUSPENDING);
             if CurrentScanner.FIDToken=_FIRST then
               Consume(_FIRST)
             else if CurrentScanner.FIDToken=_LAST then
               Consume(_LAST);
           end;
          { default is to used the realname of the procedure }
          if (ImportNr=0) and not Assigned(ImportName) then
            begin
              ImportName:=StringDup(ProcSym.realname);
              include(ProcOptions,po_has_importname);
            end;
        end
      else
        begin
          if (CurrentScanner.FIDToken=_NAME) then
           begin
             Consume(_NAME);
             ImportName:=StringDup(GetStringConst);
             include(ProcOptions,po_has_importname);
             if ImportName^='' then
               message(parser_e_empty_import_name);
           end;
        end;
    end;
end;


procedure PDWeakExternal(AProcDef:TAbstractProcDef);
begin
  if not(TargetInfo.system in systems_weak_linking) then
    message(parser_e_weak_external_not_supported)
  else
    PDExternal(AProcDef);
end;


procedure PDWinAPI(AProcDef:TAbstractProcDef);
begin
  if not(TargetInfo.system in systems_all_windows+[system_i386_nativent]) then
    AProcDef.ProcCallOption:=pocall_cdecl
  else
    AProcDef.ProcCallOption:=pocall_stdcall;
  include(AProcDef.ProcOptions,po_hascallingconvention);
end;


procedure PDHardFloat(AProcDef:TAbstractProcDef);
begin
end;

procedure PDSection(AProcDef:TAbstractProcDef);
begin
  if AProcDef.typ<>procdef then
    InternalError(2021032801);
  Message(parser_e_section_directive_not_allowed_for_target);
{$ifdef symansistr}
  TProcDef(AProcDef).section:=GetStringConst;
{$else symansistr}
  TProcDef(AProcDef).section:=StringDup(GetStringConst);
{$endif}
end;

type
   TPDHandler=procedure(AProcDef:TAbstractProcDef);
   TProcDirRec=record
     IDTok     : TToken;
     PDFlags  : TPDFlags;
     Handler   : TPDHandler;
     POCall    : TProcCallOption;
     POOption  : TProcOptions;
     MutexClPOCall : TProcCallOptions;
     MutexClPOType : TProcTypeOptions;
     MutexClPO     : TProcOptions;
   end;
const
  {Should contain the number of procedure directives we support.}
  cNumProcDirectives=52;
var
  ProcDirecData:array[1..cNumProcDirectives] of TProcDirRec=
   (
    (
      IDTok:_ABSTRACT;
      PDFlags : [pdInterface,pdObject,pdNotObjIntf,pdNotRecord];
      Handler  : @PDAbstract;
      POCall   : pocall_none;
      POOption : [po_abstractmethod];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : [po_exports,po_interrupt,po_inline]
    ),(
      IDTok:_ALIAS;
      PDFlags : [pdImplemen,pdBody,pdNotObjIntf];
      Handler  : @PDAlias;
      POCall   : pocall_none;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [];
      MutexClPO     : [po_external,po_inline]
    ),(
      IDTok:_ASMNAME;
      PDFlags : [pdInterface,pdImplemen,pdNotObjIntf];
      Handler  : @PDAsmName;
      POCall   : pocall_cdecl;
      POOption : [po_external];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : [po_external,po_inline]
    ),(
      IDTok:_ASSEMBLER;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdNotObjIntf];
      Handler  : nil;
      POCall   : pocall_none;
      POOption : [po_assembler];
      MutexClPOCall : [];
      MutexClPOType : [];
      MutexClPO     : [po_external]
    ),(
      IDTok:_C; {same as cdecl for mode mac}
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_cdecl;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_assembler,po_external]
    ),(
      IDTok:_CBLOCK;
      PDFlags : [pdProcVar];
      Handler  : nil;
      POCall   : pocall_none;
      POOption : [po_is_block];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_assembler,po_external]
    ),(
      IDTok:_CDECL;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_cdecl;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_assembler,po_external]
    ),(
      IDTok:_DISPID;
      PDFlags : [pdDispInterface];
      Handler  : @PDDispID;
      POCall   : pocall_none;
      POOption : [po_dispid];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [potype_constructor,potype_destructor,potype_operator,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt,po_external,po_inline]
    ),(
      IDTok:_DYNAMIC;
      PDFlags : [pdInterface,pdObject,pdNotObjIntf,pdNotRecord];
      Handler  : @PDVirtual;
      POCall   : pocall_none;
      POOption : [po_virtualmethod];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_exports,po_interrupt,po_external,po_overridingmethod,po_inline]
    ),(
      IDTok:_EXPORT;
      PDFlags : [pdBody,pdInterface,pdImplemen,pdNotObjIntf,pdNotRecord,pdNotHelper];
      Handler  : @PDExport;
      POCall   : pocall_none;
      POOption : [po_exports,po_global];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_external,po_interrupt,po_inline]
    ),(
      IDTok:_EXTERNAL;
      PDFlags : [pdImplemen,pdInterface,pdNotObject,pdNotObjIntf,pdCPPObject,pdNotRecord,pdNotHelper];
      Handler  : @PDExternal;
      POCall   : pocall_none;
      POOption : [po_external];
      MutexClPOCall : [];
      { allowed for external cpp classes }
      MutexClPOType : [{potype_constructor,potype_destructor}potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_public,po_exports,po_interrupt,po_assembler,po_inline]
    ),(
      IDTok:_FAR16;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar,pdNotObject,pdNotRecord,pdNotHelper];
      Handler  : nil;
      POCall   : pocall_far16;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [];
      MutexClPO     : [po_external]
    ),(
      IDTok:_FINAL;
      PDFlags : [pdInterface,pdObject,pdNotObjIntf,pdNotRecord];
      Handler  : @PDFinal;
      POCall   : pocall_none;
      POOption : [po_finalmethod];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : [po_exports,po_interrupt,po_inline]
    ),(
      IDTok:_FORWARD;
      PDFlags : [pdImplemen,pdNotObject,pdNotObjIntf,pdNotRecord,pdNotHelper];
      Handler  : @PDForward;
      POCall   : pocall_none;
      POOption : [];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : [po_external,po_inline]
    ),(
      IDTok:_OLDFPCCALL;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_oldfpccall;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [];
      MutexClPO     : []
    ),(
      IDTok:_INLINE;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdNotObjIntf];
      Handler  : nil;
      POCall   : pocall_none;
      POOption : [po_inline];
      MutexClPOCall : [pocall_safecall];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_noinline,po_exports,po_external,po_interrupt,po_virtualmethod,po_iocheck]
    ),(
      IDTok:_NOINLINE;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdNotObjIntf];
      Handler  : nil;
      POCall   : pocall_none;
      POOption : [po_noinline];
      MutexClPOCall : [];
      MutexClPOType : [];
      MutexClPO     : [po_inline,po_external]
    ),(
      IDTok:_INTERNCONST;
      PDFlags : [pdInterface,pdBody,pdNotObject,pdNotObjIntf,pdNotRecord,pdNotHelper];
      Handler  : @PDInternConst;
      POCall   : pocall_none;
      POOption : [po_internconst];
      MutexClPOCall : [];
      MutexClPOType : [potype_operator];
      MutexClPO     : []
    ),(
      IDTok:_INTERNPROC;
      PDFlags : [pdInterface,pdImplemen,pdNotObject,pdNotObjIntf,pdNotRecord,pdNotHelper];
      Handler  : @PDInternProc;
      POCall   : pocall_internproc;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_operator,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_exports,po_external,po_interrupt,po_assembler,po_iocheck,po_virtualmethod]
    ),(
      IDTok:_INTERRUPT;
      PDFlags : [pdImplemen,pdBody,pdNotObject,pdNotObjIntf,pdNotRecord,pdNotHelper];
      Handler  : @PDInterrupt;
{$ifdef i386}
      POCall   : pocall_oldfpccall;
{$else i386}
      POCall   : pocall_stdcall;
{$endif i386}
      POOption : [po_interrupt];
      MutexClPOCall : [pocall_internproc,pocall_cdecl,pocall_cppdecl,pocall_stdcall,pocall_mwpascal,
                       pocall_pascal,pocall_far16,pocall_oldfpccall,pocall_sysv_abi_cdecl,pocall_ms_abi_cdecl];
      MutexClPOType : [potype_constructor,potype_destructor,potype_operator,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_external,po_inline,po_exports]
    ),(
      IDTok:_IOCHECK;
      PDFlags : [pdImplemen,pdBody,pdNotObjIntf];
      Handler  : nil;
      POCall   : pocall_none;
      POOption : [po_iocheck];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : [po_external]
    ),(
      IDTok:_LOCAL;
      PDFlags : [pdImplemen,pdBody];
      Handler  : nil;
      POCall   : pocall_none;
      POOption : [po_kylixlocal];
      MutexClPOCall : [pocall_internproc,pocall_far16];
      MutexClPOType : [];
      MutexClPO     : [po_external,po_exports]
    ),(
      IDTok:_MESSAGE;
      PDFlags : [pdInterface,pdObject,pdNotObjIntf,pdObjCClass,pdObjCProt,pdNotRecord];
      Handler  : @PDMessage;
      POCall   : pocall_none;
      POOption : []; { can be po_msgstr or po_msgint }
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [potype_constructor,potype_destructor,potype_operator,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt,po_inline]
    ),(
      IDTok:_MWPASCAL;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_mwpascal;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [];
      MutexClPO     : []
    ),(
      IDTok:_NORETURN;
      PDFlags : [pdImplemen,pdInterface,pdBody,pdNotObjIntf];
      Handler  : nil;
      POCall   : pocall_none;
      POOption : [po_noreturn];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_operator,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt,po_virtualmethod,po_iocheck]
    ),(
      IDTok:_NOSTACKFRAME;
      PDFlags : [pdImplemen,pdBody,pdProcVar,pdNotObjIntf];
      Handler  : nil;
      POCall   : pocall_none;
      POOption : [po_nostackframe];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : []
    ),(
      IDTok:_OVERLOAD;
      PDFlags : [pdImplemen,pdInterface,pdBody,pdObjCClass,pdObjCProt];
      Handler  : @PDOverload;
      POCall   : pocall_none;
      POOption : [po_overload];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : []
    ),(
      IDTok:_OVERRIDE;
      PDFlags : [pdInterface,pdObject,pdNotObjIntf,pdObjCClass,pdNotRecord];
      Handler  : @PDOverride;
      POCall   : pocall_none;
      POOption : [po_overridingmethod,po_virtualmethod];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : [po_exports,po_interrupt,po_virtualmethod,po_inline]
    ),(
      IDTok:_PASCAL;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_pascal;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_external]
    ),(
      IDTok:_PUBLIC;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdNotObject,pdNotObjIntf,pdNotRecord,pdNotHelper];
      Handler  : @PDPublic;
      POCall   : pocall_none;
      POOption : [po_public,po_global];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : [po_external,po_inline]
    ),(
      IDTok:_REGISTER;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_register;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_external]
    ),(
      IDTok:_REINTRODUCE;
      PDFlags : [pdInterface,pdObject,pdNotObjIntf,pdObjCClass,pdNotRecord];
      Handler  : @PDReintroduce;
      POCall   : pocall_none;
      POOption : [po_reintroduce];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : [po_external,po_interrupt,po_exports,po_overridingmethod,po_inline]
    ),(
      IDTok:_SAFECALL;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_safecall;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_external]
    ),(
      IDTok:_SECTION;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdNotObject,pdNotObjIntf,pdNotRecord,pdNotHelper];
      Handler  : @PDSection;
      POCall   : pocall_none;
      POOption : [po_public,po_global];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : [po_external,po_inline,po_interrupt]
    ),(
      IDTok:_SOFTFLOAT;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_softfloat;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      { it's available with po_external because the libgcc floating point routines on the arm
        uses this calling convention }
      MutexClPO     : []
    ),(
      IDTok:_STATIC;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdObject,pdRecord,pdNotObjIntf];
      Handler  : @PDStatic;
      POCall   : pocall_none;
      POOption : [po_staticmethod];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt,po_exports,po_virtualmethod]
    ),(
      IDTok:_STDCALL;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_stdcall;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_external]
    ),(
      IDTok:_VIRTUAL;
      PDFlags : [pdInterface,pdObject,pdNotObjIntf,pdNotRecord];
      Handler  : @PDVirtual;
      POCall   : pocall_none;
      POOption : [po_virtualmethod];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [potype_class_constructor,potype_class_destructor];
      MutexClPO     : cVirtualMutuallyExclusiveProcOptions
    ),(
      IDTok:_CPPDECL;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_cppdecl;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_assembler,po_external,po_virtualmethod]
    ),(
      IDTok:_VARARGS;
      PDFlags : [pdInterface,pdImplemen,pdProcVar,pdObjCClass,pdObjCProt];
      Handler  : nil;
      POCall   : pocall_none;
      POOption : [po_varargs];
      MutexClPOCall : [pocall_internproc,pocall_register,
                       pocall_far16,pocall_oldfpccall,pocall_mwpascal];
      MutexClPOType : [];
      MutexClPO     : [po_assembler,po_interrupt,po_inline]
    ),(
      IDTok:_COMPILERPROC;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdNotObjIntf];
      Handler  : @PDCompilerProc;
      POCall   : pocall_none;
      POOption : [po_compilerproc];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt]
    ),(
      IDTok:_WEAKEXTERNAL;
      PDFlags : [pdImplemen,pdInterface,pdNotObject,pdNotObjIntf,pdCPPObject,pdNotRecord,pdNotHelper];
      Handler  : @PDWeakExternal;
      POCall   : pocall_none;
      { mark it both external and weak external, so we don't have to
        adapt all code for external symbols to also check for weak external
      }
      POOption : [po_external,po_weakexternal];
      MutexClPOCall : [pocall_internproc];
      { allowed for external cpp classes }
      MutexClPOType : [{potype_constructor,potype_destructor}potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_public,po_exports,po_interrupt,po_assembler,po_inline]
    ),(
      IDTok:_WINAPI;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : @PDWinAPI;
      POCall   : pocall_none;
      POOption : [];
      MutexClPOCall : [pocall_stdcall,pocall_cdecl,pocall_mwpascal,pocall_sysv_abi_cdecl,pocall_ms_abi_cdecl];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_external]
    ),(
      IDTok:_ENUMERATOR;
      PDFlags : [pdInterface,pdObject,pdRecord];
      Handler  : @PDEnumerator;
      POCall   : pocall_none;
      POOption : [];
      MutexClPOCall : [pocall_internproc];
      MutexClPOType : [];
      MutexClPO     : [po_exports,po_interrupt,po_external,po_inline]
    ),(
      IDTok:_RTLPROC;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdNotObjIntf];
      Handler  : nil;
      POCall   : pocall_none;
      POOption : [po_rtlproc];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt]
    ),(
      IDTok:_HARDFLOAT;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : @PDHardFloat;
      POCall   : pocall_hardfloat;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      { it's available with po_external because the libgcc floating point routines on the arm
        uses this calling convention }
      MutexClPO     : []
    ),(
      IDTok:_SYSV_ABI_DEFAULT;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_sysv_abi_default;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt]
    ),(
      IDTok:_SYSV_ABI_CDECL;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_sysv_abi_cdecl;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt]
    ),(
      IDTok:_MS_ABI_DEFAULT;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_ms_abi_default;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt]
    ),(
      IDTok:_MS_ABI_CDECL;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_ms_abi_cdecl;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt]
    ),(
      IDTok:_VECTORCALL;
      PDFlags : [pdInterface,pdImplemen,pdBody,pdProcVar];
      Handler  : nil;
      POCall   : pocall_vectorcall;
      POOption : [];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt]
    ),(
      IDTok:_WASMFUNCREF;
      PDFlags : [pdProcVar];
      Handler  : nil;
      POCall   : pocall_none;
      POOption : [po_wasm_funcref];
      MutexClPOCall : [];
      MutexClPOType : [potype_constructor,potype_destructor,potype_class_constructor,potype_class_destructor];
      MutexClPO     : [po_interrupt]
    )
   );


    function CheckProcDirective(AIsProcVar:Boolean):Boolean;
      var
        lIndex : LongInt;
      begin
        Result:=false;
        for lIndex:=1 to cNumProcDirectives do
         if ProcDirecData[lIndex].IDTok=CurrentScanner.FIDToken then
          begin
            if ((not AIsProcVar) or
               (pdProcVar in ProcDirecData[lIndex].PDFlags)) and
               { don't eat a public directive in classes }
               not((CurrentScanner.FIDToken=_PUBLIC) and (SymTableStack.top.SymTableType=ObjectSymtable)) then
              Result:=true;
            exit;
          end;
      end;


    function FindProcDirectiveIndex(AToken: TToken): LongInt; inline;
      begin
        Result:=-1;
        for Result:=1 to cNumProcDirectives do
          if ProcDirecData[Result].IDTok=AToken then
            exit;
        Result:=-1;
      end;


    function ParseProcDirec(AProcDef:TAbstractProcDef;var APDFlags:TPDFlags):Boolean;
      {
        Parse the procedure directive, returns true if a correct directive is found
      }
      var
        lDirectiveIndex     : LongInt;
        lName : TIDString;
        lProcOptions : TProcOptions;
        lTokenPos : TFilePosInfo;
      begin
        ParseProcDirec:=false;
        lName:=tokeninfo^[CurrentScanner.FIDToken].str;

      { Hint directive? Then exit immediately }
        if (m_hintdirective in CurrentSettings.ModeSwitches) then
         begin
           case CurrentScanner.FIDToken of
             _LIBRARY,
             _PLATFORM,
             _UNIMPLEMENTED,
             _EXPERIMENTAL,
             _DEPRECATED :
               if (m_delphi in CurrentSettings.ModeSwitches) and (AProcDef.typ=procdef) then
                 begin
                   MaybeParseHintDirectives(TProcDef(AProcDef));
                   { could the new token still be a directive? }
                   if CurrentScanner.FToken<>_ID then
                     exit;
                 end
               else
                 exit;
             else
               ;
           end;
         end;

        { C directive is MacPas only, because it breaks too much existing code
          on other platforms (PFV) }
        if (CurrentScanner.FIDToken=_C) and
           not(m_mac in CurrentSettings.ModeSwitches) then
          exit;

      { retrieve data for directive if found }
      lDirectiveIndex:=FindProcDirectiveIndex(CurrentScanner.FIDToken);

      { Check if the procedure directive is known }
        if lDirectiveIndex=-1 then
         begin
            { parsing a procvar type the name can be any
              next variable !! }
            if ((APDFlags * [pdProcVar,pdObject,pdRecord,pdObjCClass,pdObjCProt])=[]) and
               not(CurrentScanner.FIDToken in [_PROPERTY,_GENERIC]) then
              Message1(parser_w_unknown_proc_directive_ignored,CurrentScanner.FPattern);
            exit;
         end;

        { check if method and directive not for object, like public.
          This needs to be checked also for procvars }
        if (pdNotObject in ProcDirecData[lDirectiveIndex].PDFlags) and
           (SymTableStack.top.SymTableType=ObjectSymtable) and not((pdCPPObject in ProcDirecData[lDirectiveIndex].PDFlags) and Is_CPPClass(TDef(SymTableStack.top.DefOwner))) then
           exit;

        if (pdNotRecord in ProcDirecData[lDirectiveIndex].PDFlags) and
           (SymTableStack.top.SymTableType=recordsymtable) then
          exit;

        { Keep track of the token's position in the file so it's correctly indicated if an error occurs. }
        lTokenPos := CurrentTokenPos;

        { consume directive, and turn flag on }
        Consume(CurrentScanner.FToken);
        ParseProcDirec:=true;

        { Conflicts between directives? }
        if (AProcDef.ProcTypeOption in ProcDirecData[lDirectiveIndex].MutexClPOType) then
          begin
            MessagePos2(lTokenPos, parser_e_proc_dir_conflict,lName,ProcTypeOptionKeywords[AProcDef.ProcTypeOption]);
            exit;
          end;

        if (AProcDef.ProcCallOption in ProcDirecData[lDirectiveIndex].MutexClPOCall) then
          begin
            MessagePos2(lTokenPos, parser_e_proc_dir_conflict,lName,'"' + UpCase(proccalloptionStr[AProcDef.ProcCallOption]) + '"');
            exit;
          end;

        lProcOptions := (AProcDef.ProcOptions*ProcDirecData[lDirectiveIndex].MutexClPO);
        if (lProcOptions<>[]) then
          begin
            MessagePos2(lTokenPos, parser_e_proc_dir_conflict,lName,Get_First_Proc_Str(lProcOptions));
            exit;
          end;

        { set calling convention }
        if ProcDirecData[lDirectiveIndex].POCall<>pocall_none then
         begin
           if (po_hascallingconvention in AProcDef.ProcOptions) then
            begin
              MessagePos2(lTokenPos, parser_w_proc_overriding_calling,
                proccalloptionStr[AProcDef.ProcCallOption],
                proccalloptionStr[ProcDirecData[lDirectiveIndex].POCall]);
            end;
           { check if the target processor supports this calling convention }
           if not(ProcDirecData[lDirectiveIndex].POCall in supported_calling_conventions) then
             begin
               MessagePos1(lTokenPos, parser_e_illegal_calling_convention,proccalloptionStr[ProcDirecData[lDirectiveIndex].POCall]);
               { recover }
               ProcDirecData[lDirectiveIndex].POCall:=pocall_stdcall;
             end;
           AProcDef.ProcCallOption:=ProcDirecData[lDirectiveIndex].POCall;
           include(AProcDef.ProcOptions,po_hascallingconvention);
         end;

        if AProcDef.typ=procdef then
         begin
           { Check if the directive is only for objects }
           if (pdObject in ProcDirecData[lDirectiveIndex].PDFlags) and
              not Assigned(TProcDef(AProcDef).struct) then
            exit;

           { Check if the directive is only for records }
           if (pdRecord in ProcDirecData[lDirectiveIndex].PDFlags) and
              not Assigned(TProcDef(AProcDef).struct) then
            exit;

           { check if method and directive not for interface }
           if (pdNotObjIntf in ProcDirecData[lDirectiveIndex].PDFlags) and
              Is_Interface(TProcDef(AProcDef).struct) then
            exit;

           { check if method and directive not for interface }
           if Is_DispInterface(TProcDef(AProcDef).struct) and
             not(pdDispInterface in ProcDirecData[lDirectiveIndex].PDFlags) then
            exit;

           { check if method and directive not for objcclass }
           if Is_ObjCClass(TProcDef(AProcDef).struct) and
             not(pdObjCClass in ProcDirecData[lDirectiveIndex].PDFlags) then
            exit;

           { check if method and directive not for objcprotocol }
           if Is_ObjCProtocol(TProcDef(AProcDef).struct) and
             not(pdObjCProt in ProcDirecData[lDirectiveIndex].PDFlags) then
            exit;

           { check if method and directive not for record/class helper }
           if Is_ObjectPascal_Helper(TProcDef(AProcDef).struct) and
             (pdNotHelper in ProcDirecData[lDirectiveIndex].PDFlags) then
             exit;
         end;

        { Check the pd_flags if the directive should be allowed }
        if (pdInterface in APDFlags) and
           not(pdInterface in ProcDirecData[lDirectiveIndex].PDFlags) then
          begin
            MessagePos1(lTokenPos, parser_e_proc_dir_not_allowed_in_interface,lName);
            exit;
          end;
        if (pdImplemen in APDFlags) and
           not(pdImplemen in ProcDirecData[lDirectiveIndex].PDFlags) then
          begin
            MessagePos1(lTokenPos, parser_e_proc_dir_not_allowed_in_implementation,lName);
            exit;
          end;
        if (pdProcVar in APDFlags) and
           not(pdProcVar in ProcDirecData[lDirectiveIndex].PDFlags) then
          begin
            { reset mismatching calling convention to avoid further errors, see e.g. tests/webtbf/tw41041.pas }
            if ProcDirecData[lDirectiveIndex].POCall<>pocall_none then
              AProcDef.ProcCallOption:=pocall_default;

            MessagePos1(lTokenPos, parser_e_proc_dir_not_allowed_in_procvar,lName);
            exit;
          end;

        { Return the new pd_flags }
        if not(pdBody in ProcDirecData[lDirectiveIndex].PDFlags) then
          exclude(APDFlags,pdBody);

        { Add the correct flag }
        AProcDef.ProcOptions:=AProcDef.ProcOptions+ProcDirecData[lDirectiveIndex].POOption;

        { Call the handler }
        if Pointer(ProcDirecData[lDirectiveIndex].Handler)<>nil then
          ProcDirecData[lDirectiveIndex].Handler(AProcDef);
      end;


    function ProcGetImportName(AProcDef:TProcDef):String;
      var
        lDLLName, lImportName : String;

      begin
        Result:='';
        if not(po_external in AProcDef.ProcOptions) then
          InternalError(200412151);
        { external name or number is specified }
        if Assigned(AProcDef.ImportName) or (AProcDef.ImportNr<>0) then
          begin
            if Assigned(AProcDef.ImportDLL) then
              lDLLName:=AProcDef.ImportDLL^
            else
              lDLLName:='';
            if Assigned(AProcDef.ImportName) then
              lImportName:=AProcDef.ImportName^
            else
              lImportName:='';
            ProcGetImportName:=Make_DLLMangledName(lDLLName,
              lImportName,AProcDef.ImportNr,AProcDef.ProcCallOption);
          end
        else
          begin
            { Default names when importing variables }
            case AProcDef.ProcCallOption of
              pocall_cdecl,
              pocall_sysv_abi_cdecl,
              pocall_ms_abi_cdecl:
                begin
                  if Assigned(AProcDef.struct) then
                    Result:=TargetInfo.Cprefix+AProcDef.struct.ObjRealName^+'_'+AProcDef.ProcSym.realname
                  else
                    Result:=TargetInfo.Cprefix+AProcDef.ProcSym.realname;
                end;
              pocall_cppdecl :
                begin
                  Result:=TargetInfo.Cprefix+AProcDef.CPlusPlusMangledName;
                end;
              else
                begin
                  {In MacPas a single "external" has the same effect as "external name 'xxx'" }
                  { but according to MacPas mode description
                    Cprefix should still be used PM }
                  if (m_mac in CurrentSettings.ModeSwitches) then
                    Result:=TargetInfo.Cprefix+TProcDef(AProcDef).ProcSym.realname
                  else
                    Result:=AProcDef.ProcSym.realname;

                end;
            end;
          end;
      end;


    procedure ProcSetMangledName(AProcDef:TProcDef);
      var
        lName : String;
      begin
        { When the mangledname is already set we aren't allowed to change
          it because it can already be used somewhere (PFV) }
        if not(po_has_mangledname in AProcDef.ProcOptions) then
          begin
            if (po_external in AProcDef.ProcOptions) and not (po_wasm_suspending in AProcDef.ProcOptions) then
              begin
                { External Procedures are only allowed to change the mangledname
                  in their first declaration }
                if (AProcDef.ForwardDef or (not AProcDef.HasForward)) then
                  begin
                    lName:=ProcGetImportName(AProcDef);
                    if lName<>'' then
                      begin
                        AProcDef.SetMangledName(lName);
                      end;
                    { since this is an external declaration, there won't be an
                      implementation that needs to match the original symbol
                      again -> immediately convert here }
                    if po_compilerproc in AProcDef.ProcOptions then
                      AProcDef.SetCompilerProcName;
                  end
              end
            else
            { Normal procedures }
              begin
                if (po_compilerproc in AProcDef.ProcOptions) then
                  begin
                    AProcDef.SetMangledName(lower(AProcDef.ProcSym.name));
                  end;
              end;
          end;

        { Public/exported alias names }
        if (([po_public,po_exports]*AProcDef.ProcOptions)<>[]) and
           not(po_has_public_name in AProcDef.ProcOptions) then
          begin
            case AProcDef.ProcCallOption of
              pocall_cdecl,
              pocall_sysv_abi_cdecl,
              pocall_ms_abi_cdecl:
                begin
                  if Assigned(AProcDef.struct) then
                   AProcDef.AliasNames.insert(TargetInfo.Cprefix+AProcDef.struct.ObjRealName^+'_'+AProcDef.ProcSym.realname)
                  else
                    begin
                      { Export names are not mangled on Windows, see also pexports.pas }
                      if (TargetInfo.system in systems_all_windows) and
                        (po_exports in AProcDef.ProcOptions) then
                        AProcDef.AliasNames.insert(AProcDef.ProcSym.realname)
                      else
                        AProcDef.AliasNames.insert(TargetInfo.Cprefix+AProcDef.ProcSym.realname);
                    end;
                end;
              pocall_cppdecl :
                begin
                  AProcDef.AliasNames.insert(TargetInfo.Cprefix+AProcDef.CPlusPlusMangledName);
                end;
              else
                ;
            end;
            { prevent adding the alias a second time }
            include(AProcDef.ProcOptions,po_has_public_name);
          end;
      end;


    procedure ParseProcDirectives(AProcDef:TAbstractProcDef;var APDFlags:TPDFlags);
      {
        Parse the procedure directives. It does not matter if procedure directives
        are written using ;procdir; or ['procdir'] syntax.
      }
      var
        lStopRecording,
        lResult : Boolean;
      begin
        if (m_mac in CurrentSettings.ModeSwitches) and (cs_externally_visible in CurrentSettings.LocalSwitches) then
          begin
            TProcDef(AProcDef).AliasNames.insert(TargetInfo.Cprefix+TProcDef(AProcDef).ProcSym.realname);
            include(AProcDef.ProcOptions,po_public);
            include(AProcDef.ProcOptions,po_has_public_name);
            include(AProcDef.ProcOptions,po_global);
          end;

        { methods from external class definitions are all external themselves }
        if (AProcDef.typ=procdef) and
           Assigned(TProcDef(AProcDef).struct) and
           (TProcDef(AProcDef).struct.typ=objectdef) and
           (oo_is_external in TObjectDef(TProcDef(AProcDef).struct).ObjectOptions) then
          TProcDef(AProcDef).Make_External;

        { Class constructors and destructor are static class methods in real. }
        { There are many places in the compiler where either class or static  }
        { method flag changes the behavior. It is simpler to add them to      }
        { the class constructors/destructors options than to fix all the      }
        { occurrences. (Paul)                                                 }
        if AProcDef.ProcTypeOption in [potype_class_constructor,potype_class_destructor] then
          begin
            include(AProcDef.ProcOptions,po_classmethod);
            include(AProcDef.ProcOptions,po_staticmethod);
          end;

        { for a generic routine we also need to record the procedure          }
        { directives, but only if we aren't already recording for a           }
        { surrounding generic                                                 }
        if AProcDef.Is_Generic and (AProcDef.typ=procdef) and not CurrentScanner.IsRecordingTokens then
          begin
            CurrentScanner.StartRecordTokens(TProcDef(AProcDef).GenericDeclTokenBuf);
            lStopRecording:=true;
          end
        else
          lStopRecording:=false;

        while (CurrentScanner.FToken=_ID) or
            (
              not (m_prefixed_attributes in CurrentSettings.ModeSwitches) and
              (CurrentScanner.FToken=_LECKKLAMMER)
            ) do
         begin
           if not (m_prefixed_attributes in CurrentSettings.ModeSwitches) and
              TryToConsume(_LECKKLAMMER) then
            begin
              repeat
                ParseProcDirec(AProcDef,APDFlags);
              until not TryToConsume(_COMMA);
              Consume(_RECKKLAMMER);
              { we always expect at least '[];' }
              lResult:=true;
            end
           else
            begin
              lResult:=ParseProcDirec(AProcDef,APDFlags);
            end;
           { A procedure directive normally followed by a semicolon, but in
             a const section or reading a type we should stop when _EQ is found,
             because a constant/default value follows }
           if lResult then
            begin
              if (Block_Type=bt_const_type) and
                 (CurrentScanner.FToken=_EQ) then
               break;
              { support procedure proc;stdcall export; }
              if not(CheckProcDirective((AProcDef.typ=procvardef))) then
                begin
                  { support "record p : procedure stdcall end;" and
                    "var p : procedure stdcall = nil;" }
                  if (
                      (pdProcVar in APDFlags) and
                       (CurrentScanner.FToken in [_END,_RKLAMMER,_EQ])
                    ) or (
                      (po_anonymous in AProcDef.ProcOptions) and
                      (CurrentScanner.FToken in [_BEGIN,_VAR,_CONST,_TYPE,_LABEL,_FUNCTION,_PROCEDURE,_OPERATOR])
                    ) then
                    break
                  else
                    begin
                      if (CurrentScanner.FToken=_COLON) then
                        begin
                          Message(parser_e_field_not_allowed_here);
                          ConsumeAllUntil(_SEMICOLON);
                        end;
                      Consume(_SEMICOLON)
                    end;
                end;
            end
           else
            break;
         end;

        if lStopRecording then
          CurrentScanner.StopRecordTokens;

         { nostackframe requires assembler, but assembler
           may be specified in the implementation part only,
           and in not required if the function is first forward declared
           if it is a procdef that has forwardef set to true
           we postpone the possible error message to the real implementation
           parse_only does not need to be considered as po_nostackframe
           is an implementation only directive  }
         if (po_nostackframe in AProcDef.ProcOptions) and
            not (po_assembler in AProcDef.ProcOptions) and
            ((AProcDef.typ<>procdef) or not TProcDef(AProcDef).ForwardDef) then
           message(parser_e_nostackframe_without_assembler);
      end;


    procedure ParseProcTypeDirectives(AProcOrInvokeDef:TDef);
      var
        lPDFlags : TPDFlags;
        lProcDef : TAbstractProcDef;
      begin
        if Is_FuncRef(AProcOrInvokeDef) then
          lProcDef:=Get_Invoke_ProcDef(TObjectDef(AProcOrInvokeDef))
        else if AProcOrInvokeDef.typ=procvardef then
          lProcDef:=TProcVarDef(AProcOrInvokeDef)
        else
          InternalError(2022012501);
        lPDFlags:=[pdProcVar];
        ParseProcDirectives(lProcDef,lPDFlags);
      end;


    procedure ParseObjectProcDirectives(AProcDef:TProcDef);
      var
        lPDFlags : TPDFlags;
      begin
        lPDFlags:=[pdObject];
        ParseProcDirectives(AProcDef,lPDFlags);
      end;

    procedure ParseRecordProcDirectives(AProcDef:TProcDef);
      var
        lPDFlags : TPDFlags;
      begin
        lPDFlags:=[pdRecord];
        ParseProcDirectives(AProcDef,lPDFlags);
      end;

end.
