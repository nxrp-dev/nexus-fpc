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

    function  ReadConstant(const AOrgName:String;const AFilePos:TFilePosInfo; out ANodeType: TNodeType):TConstSym;

    procedure ConstDec(out AHadGeneric:Boolean);
    procedure ConstsDec(AInStructure, AAllowTypedConst: Boolean;out AHadGeneric:Boolean);
    procedure LabelDec;
    procedure TypeDec(out AHadGeneric:Boolean);
    procedure TypesDec(AInStructure: Boolean;out AHadGeneric:Boolean;var ARTTIAttrsDef: TRTTIAttributeList);
    procedure VarDec(out AHadGeneric:Boolean);
    procedure ThreadVarDec(out AHadGeneric:Boolean);
    procedure PropertyDec;
    procedure ResourceStringDec(out AHadGeneric:Boolean);
    procedure ParseRTTIAttributes(var ARTTIAttrsDef:TRTTIAttributeList);
    function ParseForwardDeclaration(ASym:TSym;AGenTypeName,AGenOrgTypeName:TIDString;AGenericDef:TDef;AGenericTypeList:TFPHashObjectList;out ANewType:TTypeSym):TDef;

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
       ninl,ncon,nobj,ngenutil,nld,nmem,ncal,Pass_1,
       { parser }
       Scanner,
       pbase,pexpr,ptype,ptconst,pdecsub,pdecvar,pdecobj,pgenutil,pparautl,
       procdefutil,
       { cpu-information }
       CPUInfo
       ;

    function IsSystemCustomAttributeDescendant(ADef:TDef):Boolean;
    begin
      if not Assigned(Class_TCustomAttribute) then
        Class_TCustomAttribute:=TObjectDef(Search_System_Type('TCUSTOMATTRIBUTE').TypeDef);
      Result:=Def_Is_Related(ADef,Class_TCustomAttribute);
    end;

    function ReadConstant(const AOrgName:String;const AFilePos:TFilePosInfo; out ANodeType: TNodeType):TConstSym;
      var
        lConstSym : TConstSym;
        lNode : TNode;
        lConstSet : PConstSet;
        lRealValue : PBestReal;
        lGUID : PGUID;
        lStringData : PChar;
        lWideString : TCompilerWideString;
        lSavedTokenPos : TFilePosInfo;
      begin
        ReadConstant:=nil;
        if AOrgName='' then
         InternalError(9584582);
        lConstSym:=nil;
        lNode:=CompExpr([efAcceptEqual]);
        ANodeType:=lNode.nodetype;
        lSavedTokenPos:=CurrentTokenPos;
        CurrentTokenPos:=AFilePos;
        case lNode.nodetype of
           ordconstn:
             begin
               if lNode.resultdef.typ=pointerdef then
                 lConstSym:=CConstSym.Create_OrdPtr(AOrgName,constpointer,TOrdConstNode(lNode).Value.uvalue,lNode.resultdef)
               else
                 lConstSym:=CConstSym.Create_Ord(AOrgName,constord,TOrdConstNode(lNode).Value,lNode.resultdef);
             end;
           stringconstn:
             begin
               if Is_Wide_Or_Unicode_String(lNode.resultdef) then
                 begin
                   InitWideString(lWideString);
                   CopyWideString(TStringConstNode(lNode).ValueWS,lWideString);
                   lConstSym:=CConstSym.Create_WString(AOrgName,constwstring,lWideString);
                 end
               else
                 begin
                   GetMem(lStringData,TStringConstNode(lNode).len+1);
                   lStringData[TStringConstNode(lNode).len]:=#0;
                   if TStringConstNode(lNode).len>0 then
                     move(TStringConstNode(lNode).ValueAS[0],lStringData^,TStringConstNode(lNode).len+1);
                   { if a non-default ansistring code page has been specified,
                     keep it }
                   if Is_AnsiString(lNode.resultdef) and
                      (TStringDef(lNode.resultdef).encoding<>0) then
                     lConstSym:=CConstSym.Create_String(AOrgName,conststring,lStringData,TStringConstNode(lNode).len,lNode.resultdef)
                   else
                     lConstSym:=CConstSym.Create_String(AOrgName,conststring,lStringData,TStringConstNode(lNode).len,nil);
                 end;
             end;
           realconstn :
             begin
                new(lRealValue);
                lRealValue^:=TRealConstNode(lNode).ValueReal;
                lConstSym:=CConstSym.Create_Ptr(AOrgName,constreal,lRealValue,lNode.resultdef);
             end;
           setconstn :
             begin
               new(lConstSet);
               if Assigned(TSetConstNode(lNode).ValueSet) then
                 lConstSet^:=TSetConstNode(lNode).ValueSet^
               else
                 lConstSet^:=[];
               lConstSym:=CConstSym.Create_Ptr(AOrgName,constset,lConstSet,lNode.resultdef);
             end;
           pointerconstn :
             begin
               lConstSym:=CConstSym.Create_OrdPtr(AOrgName,constpointer,TPointerConstNode(lNode).Value,lNode.resultdef);
             end;
           niln :
             begin
               lConstSym:=CConstSym.Create_Ord(AOrgName,constnil,0,lNode.resultdef);
             end;
           typen :
             begin
               if Is_Interface(lNode.resultdef) then
                begin
                  if Assigned(TObjectDef(lNode.resultdef).IIDGUID) then
                   begin
                     new(lGUID);
                     lGUID^:=TObjectDef(lNode.resultdef).IIDGUID^;
                     lConstSym:=CConstSym.Create_Ptr(AOrgName,constguid,lGUID,lNode.resultdef);
                   end
                  else
                   Message1(parser_e_interface_has_no_guid,TObjectDef(lNode.resultdef).ObjRealName^);
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
               if not ParseGeneric then
                 Message(parser_e_cannot_evaluate_expression_at_compile_time);
               case TInlineNode(lNode).InlineNumber of
                 in_sizeof_x:
                   begin
                     lConstSym:=CConstSym.Create_Ord(AOrgName,constord,1,lNode.resultdef);
                   end;
                 in_bitsizeof_x:
                   begin
                     lConstSym:=CConstSym.Create_Ord(AOrgName,constord,8,lNode.resultdef);
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
               if nf_generic_para in lNode.flags then
                 lConstSym:=CConstSym.Create_Ord(AOrgName,constnil,0,lNode.resultdef)
               else
                 Message(parser_e_illegal_expression);
             end;
        end;
        { transfer generic param flag from node to symbol }
        if nf_generic_para in lNode.flags then
          begin
            include(lConstSym.SymOptions,sp_generic_const);
            include(lConstSym.SymOptions,sp_generic_para);
          end;
        CurrentTokenPos:=lSavedTokenPos;
        lNode.free;
        lNode := nil;
        ReadConstant:=lConstSym;
      end;

    procedure ConstDec(out AHadGeneric:Boolean);
      begin
        Consume(_CONST);
        ConstsDec(false,true,AHadGeneric);
      end;

    procedure ConstsDec(AInStructure, AAllowTypedConst: Boolean;out AHadGeneric:Boolean);
      var
         lOrgName : TIDString;
         lDef : TDef;
         lSym : TSym;
         lFlags : THCCFlags;
         lDummySymOptions : TSymOptions;
         lDeprecatedMsg : PShortString;
         lSavedTokenPos,lFilePos : TFilePosInfo;
         lNodeType : TNodeType;
         lOldBlockType : TBlockType;
         lFirst,
         lIsGeneric,
         lExpectDirective,
         lSkipInitialiser : Boolean;
         lVarSpez : TVarSpez;
         lAsmType : TAsmListType;
      begin
         lOldBlockType:=Block_Type;
         Block_Type:=bt_const;
         AHadGeneric:=false;
         lFirst:=true;
         repeat
           lOrgName:=CurrentScanner.FOrgPattern;
           lFilePos:=CurrentTokenPos;
           lIsGeneric:=not (m_delphi in CurrentSettings.ModeSwitches) and (CurrentScanner.FToken=_ID) and (CurrentScanner.FIDToken=_GENERIC);
           Consume(_ID);
           case CurrentScanner.FToken of

             _EQ:
                begin
                   Consume(_EQ);
                   lSym:=ReadConstant(lOrgName,lFilePos,lNodeType);
                   { Support hint directives }
                   lDummySymOptions:=[];
                   lDeprecatedMsg:=nil;
                   TryConsumeHintDirective(lDummySymOptions,lDeprecatedMsg);
                   if Assigned(lSym) then
                     begin
                       lSym.SymOptions:=lSym.SymOptions+lDummySymOptions;
                       lSym.DeprecatedMsg:=lDeprecatedMsg;
                       lSym.visibility:=SymTableStack.top.CurrentVisibility;
                       SymTableStack.top.InsertSym(lSym);
                       lSym.RegisterSym;
                     end
                   else
                     StringDispose(lDeprecatedMsg);
                   Consume(_SEMICOLON);
                end;

             _COLON:
                begin
                   if not AAllowTypedConst then
                     begin
                       Message(parser_e_no_typed_const);
                       ConsumeAllUntil(_SEMICOLON);
                     end;
                   { set the blocktype first so a consume also supports a
                     caret, to support const s : ^string = nil }
                   Block_Type:=bt_const_type;
                   Consume(_COLON);
                   ReadAnonType(lDef,false,nil);
                   Block_Type:=bt_const;
                   { create symbol }
                   lSavedTokenPos:=CurrentTokenPos;
                   CurrentTokenPos:=lFilePos;
                   if not (cs_typed_const_writable in CurrentSettings.LocalSwitches) then
                     begin
                       lVarSpez:=vs_const;
                       lAsmType:=al_rotypedconsts;
                     end
                   else
                     begin
                       lVarSpez:=vs_value;
                       lAsmType:=al_typedconsts;
                     end;
                   { if we are dealing with structure const then we need to handle it as a
                     structure static variable: create a symbol in unit symtable and a reference
                     to it from the structure or linking will fail }
                   if SymTableStack.top.SymTableType in [recordsymtable,ObjectSymtable] then
                     begin
                       { note: we keep hdef so that we might at least read the
                               constant data correctly for error recovery }
                       CheckAllowedForVarOrConst(lDef,false);
                       lSym:=CFieldVarSym.Create(lOrgName,lVarSpez,lDef,[]);
                       SymTableStack.top.InsertSym(lSym);
                       lSym:=Make_Field_Static(SymTableStack.top,TFieldVarSym(lSym));
                     end
                   else
                     begin
                       lSym:=CStaticVarSym.Create(lOrgName,lVarSpez,lDef,[]);
                       lSym.visibility:=SymTableStack.top.CurrentVisibility;
                       SymTableStack.top.InsertSym(lSym);
                     end;
                   lSym.RegisterSym;
                   CurrentTokenPos:=lSavedTokenPos;
                   lSkipInitialiser:=false;
                   { Anonymous proctype definitions can have proc directives }
                   if (
                         (lDef.typ=procvardef) or
                         Is_FuncRef(lDef)
                       ) and
                       (lDef.TypeSym=nil) then
                    begin
                      { Either "procedure; stdcall" or "procedure stdcall" }
                      lExpectDirective:=TryToConsume(_SEMICOLON);
                      if CheckProcDirective(true) then
                        ParseProcTypeDirectives(lDef)
                      else if lExpectDirective then
                       begin
                         Message(parser_e_proc_directive_expected);
                         lSkipInitialiser:=true;
                       end;
                      { add default calling convention }
                      if lDef.typ=procvardef then
                        lFlags:=cHCCDefaultActionsIntf
                      else
                        lFlags:=cHCCDefaultActionsIntfStruct;
                      Handle_Calling_Convention(lDef,lFlags);
                    end;
                   { Parse the initialiser }
                   if not lSkipInitialiser then
                    begin
                      Consume(_EQ);
                      ReadTypedConst(CurrentAsmData.asmlists[lAsmType],TStaticVarSym(lSym),AInStructure);
                    end;
                end;

              else
                if not lFirst and lIsGeneric and (CurrentScanner.FToken in [_PROCEDURE,_FUNCTION,_CLASS]) then
                  begin
                    AHadGeneric:=true;
                    break;
                  end
                else
                  { generate an error }
                  Consume(_EQ);
           end;

           lFirst:=false;
         until (CurrentScanner.FToken<>_ID) or
               (AInStructure and
                ((CurrentScanner.FIDToken in [_PRIVATE,_PROTECTED,_PUBLIC,_PUBLISHED,_STRICT]) or
                 ((m_final_fields in CurrentSettings.ModeSwitches) and
                  (CurrentScanner.FIDToken=_FINAL))));
         Block_Type:=lOldBlockType;
      end;


    procedure LabelDec;
      var
        lLabelSym : TLabelSym;
      begin
         Consume(_LABEL);
         if not(cs_support_goto in CurrentSettings.ModuleSwitches) then
           Message(sym_e_goto_and_label_not_supported);
         repeat
           if not(CurrentScanner.FToken in [_ID,_INTCONST]) then
             Consume(_ID)
           else
             begin
                if CurrentScanner.FToken=_ID then
                  lLabelSym:=CLabelSym.Create(CurrentScanner.FOrgPattern)
                else
                  begin
                    { strip leading 0's in iso mode }
                    if (([m_iso]*CurrentSettings.ModeSwitches)<>[]) then
                      while (length(CurrentScanner.FPattern)>1) and (CurrentScanner.FPattern[1]='0') do
                        delete(CurrentScanner.FPattern,1,1);
                    lLabelSym:=CLabelSym.Create(CurrentScanner.FPattern);
                  end;

                SymTableStack.top.InsertSym(lLabelSym);
                if m_non_local_goto in CurrentSettings.ModeSwitches then
                  begin
                    if SymTableStack.top.SymTableType=LocalSymTable then
                      begin
                        lLabelSym.JumpBuf:=CLocalVarSym.Create('LABEL$_'+lLabelSym.name,vs_value,Rec_Jmp_Buf,[]);
                        SymTableStack.top.InsertSym(lLabelSym.JumpBuf);
                      end
                    else
                      begin
                        lLabelSym.JumpBuf:=CStaticVarSym.Create('LABEL$_'+lLabelSym.name,vs_value,Rec_Jmp_Buf,[]);
                        SymTableStack.top.InsertSym(lLabelSym.JumpBuf);
                        CNodeUtils.InsertBSSData(TStaticVarSym(lLabelSym.JumpBuf));
                      end;
                    include(lLabelSym.JumpBuf.SymOptions,sp_internal);
                    { the buffer will be setup later, but avoid a hint }
                    TAbstractVarSym(lLabelSym.JumpBuf).VarState:=vs_written;
                  end;
                Consume(CurrentScanner.FToken);
             end;
           if CurrentScanner.FToken<>_SEMICOLON then Consume(_COMMA);
         until not(CurrentScanner.FToken in [_ID,_INTCONST]);
         Consume(_SEMICOLON);
      end;

    function FindCreateConstructor(AObjDef:TObjectDef):TSymEntry;
      begin
         while Assigned(AObjDef) do
           begin
             Result:=AObjDef.SymTable.Find('CREATE');
             if Assigned(Result) then
               exit;
             AObjDef:=AObjDef.ChildOf;
           end;
         // A class without a constructor called 'create'?!?
         InternalError(2012111101);
      end;

    procedure ParseRTTIAttributes(var ARTTIAttrsDef:TRTTIAttributeList);

      function ReadAttrParas:TNode;
        var
          lOldBlockType : TBlockType;
        begin
          if TryToConsume(_LKLAMMER) then
            begin
              { we only want constants here }
              lOldBlockType:=Block_Type;
              Block_Type:=bt_const;
              Result:=ParseParas(false,false,_RKLAMMER);
              Block_Type:=lOldBlockType;
              Consume(_RKLAMMER);
            end
          else
            Result:=nil;
        end;

      var
        lNode,lParaNode,lCallNode,lTempNode : TNode;
        lErrorCount : LongInt;
        lIndex,lParaCount : SizeInt;
        lParas : array of TNode;
        lObjectDef : TObjectDef;
        lConstructorSym : TSymEntry;
        lTypeSym : TTypeSym;
        lParasOK : Boolean;
      begin
        Consume(_LECKKLAMMER);

        repeat
          { Parse attribute type }
          lNode:=Factor(false,[efTypeOnly,efCheckAttrSuffix]);
          if lNode.nodetype=typen then
            begin
              lTypeSym:=TTypeSym(TTypeNode(lNode).TypeSym);
              lObjectDef:=TObjectDef(TTypeNode(lNode).TypeDef);

              { Check if the attribute class is related to TCustomAttribute }
              if not IsSystemCustomAttributeDescendant(lObjectDef) then
                begin
                  IncompatibleTypes(lObjectDef,Class_TCustomAttribute);
                  ReadAttrParas.free; // no nil needed
                  continue;
                end;

              lParaNode:=ReadAttrParas;

              { Search the tprocdef of the constructor which has to be called. }
              lConstructorSym:=FindCreateConstructor(lObjectDef);
              if lConstructorSym.typ<>ProcSym then
                InternalError(2018102301);

              lCallNode:=CCallNode.Create(lParaNode,TProcSym(lConstructorSym),lObjectDef.SymTable,CLoadVMTAddrNode.Create(lNode),[cnf_no_convert_procvar],nil);
              lNode:=nil;
              lErrorCount:=ErrorCount;
              TypeCheckPass(lCallNode);

              if (lCallNode.nodetype=calln) and Assigned(TCallNode(lCallNode).ProcDefinition) and not CodeGenError then
                begin
                  { TODO: once extended RTTI for methods is supported, reject a
                          constructor if it doesn't have extended RTTI enabled }

                  { collect the parameters of the call node as there might be
                    compile time type conversions (e.g. a Byte parameter being
                    passed a value > 255) }
                  lParaNode:=TCallNode(lCallNode).left;

                  { only count visible parameters (thankfully open arrays are not
                    supported, otherwise we'd need to handle those as well) }
                  lParasOK:=true;
                  lParas:=nil;
                  if Assigned(lParaNode) then
                    begin
                      lTempNode:=lParaNode;
                      lParaCount:=0;
                      while Assigned(lTempNode) do
                        begin
                          if not (vo_is_hidden_para in TCallParaNode(lTempNode).ParaSym.VarOptions) then
                            inc(lParaCount);
                          lTempNode:=TCallParaNode(lTempNode).right;
                        end;
                      SetLength(lParas,lParaCount);
                      lTempNode:=lParaNode;
                      lParaCount:=0;
                      while Assigned(lTempNode) do
                        begin
                          if not (vo_is_hidden_para in TCallParaNode(lTempNode).ParaSym.VarOptions) then
                            begin
                              if not Is_ConstNode(TCallParaNode(lTempNode).left) then
                                begin
                                  lParasOK:=false;
                                  messagepos(TCallParaNode(lTempNode).left.fileinfo,type_e_constant_expr_expected);
                                end;
                              lParas[high(lParas)-lParaCount]:=TCallParaNode(lTempNode).left.GetCopy;
                              inc(lParaCount);
                            end;
                          lTempNode:=TCallParaNode(lTempNode).right;
                        end;
                    end;

                  if lParasOK then
                    begin
                      { Add attribute to attribute list which will be added
                        to the property which is defined next. }
                      if not Assigned(ARTTIAttrsDef) then
                        ARTTIAttrsDef:=TRTTIAttributeList.Create;
                      ARTTIAttrsDef.AddAttribute(lTypeSym,TCallNode(lCallNode).ProcDefinition,lCallNode,lParas);
                    end
                  else
                    begin
                      { cleanup }
                      lCallNode.free;
                      lCallNode := nil;
                      for lIndex:=0 to high(lParas) do
                        FreeAndNil(lParas[lIndex]);
                    end;
                end
              else begin
                { provide *some* error in case there hasn't been one }
                if ErrorCount=lErrorCount then
                  message(parser_e_illegal_expression);
                lCallNode.free;
                lCallNode := nil;
              end;
            end
          else
            begin
              Message(type_e_type_id_expected);
              { try to recover by nevertheless reading the parameters (if any) }
              ReadAttrParas.free; // no nil needed
            end;

          lNode.free;
          lNode := nil;
        until not TryToConsume(_COMMA);

        Consume(_RECKKLAMMER);
      end;


    function ParseForwardDeclaration(ASym:TSym;AGenTypeName,AGenOrgTypeName:TIDString;AGenericDef:TDef;AGenericTypeList:TFPHashObjectList;out ANewType:TTypeSym):TDef;
      var
        lWasForward : Boolean;
        lObjectType : TObjectTyp;
        lGenDef : TStoredDef;
      begin
        ANewType:=nil;
        lWasForward:=false;
        if ((CurrentScanner.FToken=_CLASS) or
            (CurrentScanner.FToken=_INTERFACE) or
            (CurrentScanner.FToken=_DISPINTERFACE) or
            (CurrentScanner.FToken=_OBJCCLASS) or
            (CurrentScanner.FToken=_OBJCPROTOCOL) or
            (CurrentScanner.FToken=_OBJCCATEGORY)) and
           (Assigned(TTypeSym(ASym).TypeDef)) and
           Is_Implicit_Pointer_Object_Type(TTypeSym(ASym).TypeDef) and
           (oo_is_forward in TObjectDef(TTypeSym(ASym).TypeDef).ObjectOptions) then
         begin
           lWasForward:=true;
           lObjectType:=odt_none;
           case CurrentScanner.FToken of
             _CLASS :
               lObjectType:=DefaultClassType;
             _INTERFACE :
               case CurrentSettings.InterfaceType of
                 it_interfacecom:
                   lObjectType:=odt_interfacecom;
                 it_interfacecorba:
                   lObjectType:=odt_interfacecorba;

               end;
             _DISPINTERFACE :
               lObjectType:=odt_dispinterface;
             _OBJCCLASS,
             _OBJCCATEGORY :
               lObjectType:=odt_objcclass;
             _OBJCPROTOCOL :
               lObjectType:=odt_objcprotocol;
             else
               InternalError(200811072);
           end;
           Consume(CurrentScanner.FToken);
           if Assigned(AGenericDef) then
             lGenDef:=TStoredDef(AGenericDef)
           else
             { determine the generic def in case we are in a nested type
               of a specialization }
             lGenDef:=DetermineGenericDef(AGenTypeName);
           { we can ignore the result, the definition is modified }
           ObjectDec(lObjectType,AGenOrgTypeName,ANewType,lGenDef,AGenericTypeList,TObjectDef(TTypeSym(ASym).TypeDef),ht_none);
           if lWasForward and
             (TObjectDef(TTypeSym(ASym).TypeDef).ObjectType<>lObjectType) then
             Message1(type_e_forward_interface_type_does_not_match,TObjectDef(TTypeSym(ASym).TypeDef).GetTypeName);
           ANewType:=TTypeSym(ASym);
           Result:=ANewType.TypeDef;
         end
        else
          begin
            message1(parser_h_type_redef,AGenOrgTypeName);
            Result:=GenErrorDef;
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
    procedure PDSetObjCRelatedResult(ADef: TObject; APara: Pointer);
      var
        lProcDef: TProcDef;
        lIndex, lFirstCamelEnd: LongInt;
        lInferResult: Boolean;
      begin
        if TDef(ADef).typ<>procdef then
          exit;
        lProcDef:=TProcDef(ADef);
        if not(po_msgstr in lProcDef.ProcOptions) then
          InternalError(2019082401);
        lFirstCamelEnd:=length(lProcDef.MessageInf.str^);
        for lIndex:=1 to length(lProcDef.MessageInf.str^) do
          if lProcDef.MessageInf.str^[lIndex] in ['A'..'Z'] then
            begin
              lFirstCamelEnd:=pred(lIndex);
              break;
            end;
        case copy(lProcDef.MessageInf.str^,1,lFirstCamelEnd) of
          'alloc',
          'new':
             lInferResult:=po_classmethod in lProcDef.ProcOptions;
          'autorelease',
          'init',
          'retain',
          'self':
             lInferResult:=not(po_classmethod in lProcDef.ProcOptions);
          else
            lInferResult:=false;
        end;
        if lInferResult and
           Def_Is_Related(TDef(lProcDef.ProcSym.owner.DefOwner),lProcDef.ReturnDef) then
          include(lProcDef.ProcOptions,po_objc_related_result_type);
      end;

    procedure TypesDec(AInStructure: Boolean;out AHadGeneric:Boolean;var ARTTIAttrsDef: TRTTIAttributeList);

      procedure FinalizeClassExternalStatus(AObjectDef: TObjectDef);
        begin
          if  [oo_is_external,oo_is_forward] <= AObjectDef.ObjectOptions then
            begin
              { formal definition: x = objcclass external; }
              exclude(AObjectDef.ObjectOptions,oo_is_forward);
              include(AObjectDef.ObjectOptions,oo_is_formal);
            end;
        end;

      var
         lTypeName,lOrgTypeName,
         lGenTypeName,lGenOrgTypeName : TIDString;
         lNewType  : TTypeSym;
         lDummySym,
         lSym      : TSym;
         lDef,
         lOtherDef    : TDef;
         lDefPos,lSavedTokenPos : TFilePosInfo;
         lOldBlockType : TBlockType;
         lOldCheckForwardDefs: TFPObjectList;
         lFlags : THCCFlags;
         lSetDummySym,
         lFirst,
         lIsGeneric,
         lIsUnique,
         lIsTypeRenaming : Boolean;
         lGenericTypeList : TFPHashObjectList;
         lLocalGenericTokenBuf : TDynamicArray;
         lNode:TNode;
         lGenDef : TStoredDef;
         lText : ShortString;
         lIndex : LongInt;
{$ifdef x86}
         lSegmentRegister: String;
{$endif x86}
      begin
         lOldBlockType:=Block_Type;
         { save unit container of forward declarations -
           we can be inside nested class type block }
         lOldCheckForwardDefs:=CurrentModule.CheckForwardDefs;
         CurrentModule.CheckForwardDefs:=TFPObjectList.Create(false);
         Block_Type:=bt_type;
         lDef:=nil;
         lFirst:=true;
         AHadGeneric:=false;
         lSavedTokenPos:=Default(TFilePosInfo);
         repeat
           lDefPos:=CurrentTokenPos;
           lIsTypeRenaming:=false;
           lSetDummySym:=false;
           lGenericTypeList:=nil;
           lLocalGenericTokenBuf:=nil;

           { class attribute definitions? }
           if m_prefixed_attributes in CurrentSettings.ModeSwitches then
             while CurrentScanner.FToken=_LECKKLAMMER do
               ParseRTTIAttributes(ARTTIAttrsDef);

           { fpc generic declaration? }
           if lFirst then
             AHadGeneric:=not(m_delphi in CurrentSettings.ModeSwitches) and TryToConsume(_GENERIC);
           lIsGeneric:=AHadGeneric;

           lTypeName:=CurrentScanner.FPattern;
           lOrgTypeName:=CurrentScanner.FOrgPattern;
           Consume(_ID);

           { delphi generic declaration? }
           if (m_delphi in CurrentSettings.ModeSwitches) then
             lIsGeneric:=CurrentScanner.FToken=_LSHARPBRACKET;

           { Generic type declaration? }
           if lIsGeneric then
             begin
               if Assigned(CurrentGenericDef) then
                 Message(parser_f_no_generic_inside_generic);

               Consume(_LSHARPBRACKET);
               lGenericTypeList:=ParseGenericParameters(true);
               Consume(_RSHARPBRACKET);

               str(lGenericTypeList.Count,lText);
               lGenTypeName:=lTypeName+'$'+lText;
               lGenOrgTypeName:=lOrgTypeName+'$'+lText;
             end
           else
             begin
               lGenTypeName:=lTypeName;
               lGenOrgTypeName:=lOrgTypeName;
             end;

           Consume(_EQ);

           { support 'ttype=type word' syntax }
           lIsUnique:=TryToConsume(_TYPE);

           { MacPas object model is more like Delphi's than like TP's, but }
           { uses the object keyword instead of class                      }
           if (m_mac in CurrentSettings.ModeSwitches) and
              (CurrentScanner.FToken = _OBJECT) then
             CurrentScanner.FToken := _CLASS;

           { Start recording a generic template }
           if Assigned(lGenericTypeList) then
             begin
               lLocalGenericTokenBuf:=TDynamicArray.Create(256);
               CurrentScanner.StartRecordTokens(lLocalGenericTokenBuf);
             end;

           { is the type already defined? -- must be in the current symtable,
             not in a nested symtable or one higher up the stack -> don't
             use searchsym & friends! }
           lSym:=TSym(SymTableStack.top.find(lGenTypeName));
           lNewType:=nil;
           { found a symbol with this name? }
           if Assigned(lSym) then
            begin
              if (lSym.typ=TypeSym) and
                 { this should not be a symbol that was created by a generic
                   that was declared earlier }
                 not (
                   (TTypeSym(lSym).TypeDef.typ=undefineddef) and
                   (sp_generic_dummy in lSym.SymOptions)
                 ) then
               begin
                 lDef:=ParseForwardDeclaration(lSym,lGenTypeName,lGenOrgTypeName,nil,lGenericTypeList,lNewType);
               end;
            end;
           { no old type reused ? Then insert this new type }
           if not Assigned(lNewType) then
            begin
              if lIsGeneric then
                begin
                  { we are not freeing the type parameters, so register them }
                  for lIndex:=0 to lGenericTypeList.count-1 do
                    begin
                       TStoredSym(lGenericTypeList[lIndex]).RegisterSym;
                       if TStoredSym(lGenericTypeList[lIndex]).typ=TypeSym then
                         TStoredDef(TTypeSym(lGenericTypeList[lIndex]).TypeDef).RegisterDef;
                    end;
                end;

              { insert the new type first with an errordef, so that
                referencing the type before it's really set it
                will give an error (PFV) }
              lDef:=GenErrorDef;
              lGenDef:=nil;
              lSavedTokenPos:=CurrentTokenPos;
              if lIsGeneric then
                begin
                  { for generics we need to check whether a non-generic type
                    already exists and if not we need to insert a symbol with
                    the non-generic name (available in (org)typename) that is a
                    undefineddef, so that inline specializations can be used }
                  lSym:=TSym(SymTableStack.top.Find(lTypeName));
                  if not Assigned(lSym) then
                    begin
                      lSym:=CTypeSym.Create(lOrgTypeName,CUndefinedDef.Create(true));
                      Include(lSym.SymOptions,sp_generic_dummy);
                      TTypeSym(lSym).TypeDef.TypeSym:=lSym;
                      lSym.visibility:=SymTableStack.top.CurrentVisibility;
                      { add as dummy symbol before adding it to the symtable stack }
                      AddGenericDummySym(lSym,lTypeName);
                      SymTableStack.top.InsertSym(lSym);
                      TTypeSym(lSym).TypeDef.owner:=lSym.owner;
                    end
                  else
                    { this is not allowed in non-Delphi modes }
                    if not (m_delphi in CurrentSettings.ModeSwitches) then
                      Message1(sym_e_duplicate_id,lGenOrgTypeName)
                    else
                      begin
                        { we need to find this symbol even if it's a variable or
                          something else when doing an inline specialization }
                        Include(lSym.SymOptions,sp_generic_dummy);
                        AddGenericDummySym(lSym,'');
                      end;
                end
              else
                begin
                  if Assigned(lSym) and (lSym.typ=TypeSym) and
                      (TTypeSym(lSym).TypeDef.typ=undefineddef) and
                      (sp_generic_dummy in lSym.SymOptions) then
                    begin
                      { this is a symbol that was added by an earlier generic
                        declaration, reuse it }
                      lNewType:=TTypeSym(lSym);
                      lNewType.TypeDef:=lDef;
                      { use the correct casing }
                      lNewType.RealName:=lGenOrgTypeName;
                      lSym:=nil;
                    end;

                  { determine the generic def in case we are in a nested type
                    of a specialization }
                  lGenDef:=DetermineGenericDef(lGenTypeName);
                end;
              { insert a new type if we don't reuse an existing symbol }
              if not Assigned(lNewType) then
                begin
                  lNewType:=CTypeSym.Create(lGenOrgTypeName,lDef);
                  lNewType.visibility:=SymTableStack.top.CurrentVisibility;
                  SymTableStack.top.InsertSym(lNewType);
                end;
              CurrentTokenPos:=lDefPos;
              CurrentTokenPos:=lSavedTokenPos;
              { read the type definition }
              ReadNamedType(lDef,lNewType,lGenDef,lGenericTypeList,false,lIsUnique);
              { update the definition of the type }
              if Assigned(lDef) then
                begin
                  if Assigned(lDef.TypeSym) then
                    begin
                      lIsTypeRenaming:=true;
                      include(lNewType.SymOptions,sp_explicitrename);
                    end;
                  if lIsUnique then
                    begin
                      if Is_ObjC_Class_Or_Protocol(lDef) then
                        Message(parser_e_unique_unsupported);

                      if Is_Object(lDef) or
                         Is_Class_Or_Interface_Or_DispInterface(lDef) then
                        begin
                          { just create a copy that is a child of the original class class type; this is
                            Delphi-compatible }
                          lOtherDef:=TStoredDef(lDef).GetCopy;
                          TObjectDef(lOtherDef).ChildOf:=TObjectDef(lDef);
                          TStoredDef(lOtherDef).OrgDef:=TStoredDef(lDef);
                          lDef:=lOtherDef;
                        end
                      else
                        begin
                          lOtherDef:=TStoredDef(lDef).GetCopy;
                          TStoredDef(lOtherDef).OrgDef:=TStoredDef(lDef);
                          lDef:=lOtherDef;
                          { check if it is an ansistring(codepage) declaration }
                          if Is_AnsiString(lDef) and TryToConsume(_LKLAMMER) then
                            begin
                              lNode:=CompExpr([efAcceptEqual]);
                              Consume(_RKLAMMER);
                              if not Is_ConstIntNode(lNode) then
                                begin
                                  Message(parser_e_illegal_expression);
                                  { error recovery }
                                end
                              else
                                begin
                                  if (TOrdConstNode(lNode).Value<0) or (TOrdConstNode(lNode).Value>65535) then
                                    begin
                                      Message(parser_e_invalid_codepage);
                                      TOrdConstNode(lNode).Value:=0;
                                    end;
                                  TStringDef(lDef).encoding:=int64(TOrdConstNode(lNode).Value);
                                end;
                              lNode.free;
                              lNode := nil;
                            end;
                          if (lDef.typ in [pointerdef,classrefdef]) and
                             (TAbstractPointerDef(lDef).PointedDef.typ=ForwardDef) then
                            CurrentModule.CheckForwardDefs.add(lDef);
                        end;

                      include(lDef.DefOptions,df_unique);

                      { update object's real name for better error messages }
                      if lDef is TAbstractRecordDef then
                        TAbstractRecordDef(lDef).SetObjRealName(lNewType.RealName);
                    end;
                  if not Assigned(lDef.TypeSym) then
                    begin
                      lDef.TypeSym:=lNewType;
                      if sp_generic_dummy in lNewType.SymOptions then
                        AddGenericDummySym(lNewType,'');
                    end;
                end;
              { in non-Delphi modes we need a reference to the generic def
                without the generic suffix, so it can be found easily when
                parsing method implementations }
              if lIsGeneric and Assigned(lSym) and
                  not (m_delphi in CurrentSettings.ModeSwitches) and
                  (TTypeSym(lSym).TypeDef.typ=undefineddef) then
                begin
                  { don't free the undefineddef as the defids rely on the count
                    of the defs in the def list of the module}
                  TTypeSym(lSym).TypeDef:=lDef;
                  lSetDummySym:=true;
                end;
              lNewType.TypeDef:=lDef;
              { ensure that the type is registered when no specialization is
                currently done }
              if (CurrentScanner.ReplayStackDepth=0) and
                  (
                    (lDef.typ<>procvardef) or
                    not (po_is_function_ref in TAbstractProcDef(lDef).ProcOptions)
                  ) then
                lDef.RegisterDef;
              { KAZ: handle TGUID declaration in system unit }
              if (cs_compilesystem in CurrentSettings.ModuleSwitches) and
                 Assigned(lDef) and
                 (lDef.typ=recorddef) then
                begin
                  if not Assigned(Rec_TGUID) and
                     (lGenTypeName='TGUID') and
                     (lDef.Size=16) then
                    Rec_TGUID:=TRecordDef(lDef)
                  else if not Assigned(Rec_Jmp_Buf) and
                     (lGenTypeName='JMP_BUF') then
                    Rec_Jmp_Buf:=TRecordDef(lDef)
                  else if not Assigned(Rec_ExceptAddr) and
                     (lGenTypeName='TEXCEPTADDR') then
                    Rec_ExceptAddr:=TRecordDef(lDef);
                end;
            end;
           if Assigned(lDef) then
            begin
              case lDef.typ of
                pointerdef :
                  begin
                    TryConsumeHintDirective(lNewType.SymOptions,lNewType.DeprecatedMsg);
                    Consume(_SEMICOLON);
{$ifdef x86}

  {$if defined(i386)}
                    if TryToConsume(_FAR) then
                     begin
                       TCPUPointerDef(lDef).X86PointerTyp:=x86pt_near_fs;
                       Consume(_SEMICOLON);
                     end
                    else
  {$endif}
                      if TryToConsume(_NEAR) then
                       begin
                         if CurrentScanner.FToken <> _SEMICOLON then
                           begin
                             lSegmentRegister:=GetStringConst;
                             case UpCase(lSegmentRegister) of
                               'CS': TCPUPointerDef(lDef).X86PointerTyp:=x86pt_near_cs;
                               'DS': TCPUPointerDef(lDef).X86PointerTyp:=x86pt_near_ds;
                               'SS': TCPUPointerDef(lDef).X86PointerTyp:=x86pt_near_ss;
                               'ES': TCPUPointerDef(lDef).X86PointerTyp:=x86pt_near_es;
                               'FS': TCPUPointerDef(lDef).X86PointerTyp:=x86pt_near_fs;
                               'GS': TCPUPointerDef(lDef).X86PointerTyp:=x86pt_near_gs;
                               else
                                 Message(asmr_e_invalid_register);
                             end;
                           end
                         else
                           TCPUPointerDef(lDef).X86PointerTyp:=x86pt_near;
                         Consume(_SEMICOLON);
                       end;
{$endif x86}
                  end;
                procvardef :
                  begin
                    { in case of type renaming, don't parse proc directives }
                    if lIsTypeRenaming then
                      begin
                        TryConsumeHintDirective(lNewType.SymOptions,lNewType.DeprecatedMsg);
                        Consume(_SEMICOLON);
                      end
                    else
                     begin
                       if not CheckProcDirective(true) then
                         begin
                           TryConsumeHintDirective(lNewType.SymOptions,lNewType.DeprecatedMsg);
                           Consume(_SEMICOLON);
                         end;
                       ParseProcTypeDirectives(TProcVarDef(lDef));
                       if po_is_function_ref in TProcVarDef(lDef).ProcOptions then
                         begin
                           if not (m_function_references in CurrentSettings.ModeSwitches) and
                               not (po_is_block in TProcVarDef(lDef).ProcOptions) then
                             messagepos(lSavedTokenPos,sym_e_error_in_type_def)
                           else
                             begin
                               if lSetDummySym then
                                 lDummySym:=lSym
                               else
                                 lDummySym:=nil;
                               Adjust_FuncRef(lDef,lNewType,lDummySym);
                             end;
                           if CurrentScanner.ReplayStackDepth=0 then
                             lDef.RegisterDef;
                         end;
                       if lDef.typ=procvardef then
                         lFlags:=cHCCDefaultActionsIntf
                       else
                         lFlags:=cHCCDefaultActionsIntfStruct;
                       Handle_Calling_Convention(lDef,lFlags);
                       if (lDef.typ=procvardef) and (po_is_function_ref in TProcVarDef(lDef).ProcOptions) then
                         begin
                           if (po_is_block in TProcVarDef(lDef).ProcOptions) and
                              not (TProcVarDef(lDef).ProcCallOption in [pocall_cdecl,pocall_mwpascal]) then
                             message(type_e_cblock_callconv);
                         end;
                       if TryConsumeHintDirective(lNewType.SymOptions,lNewType.DeprecatedMsg) then
                         Consume(_SEMICOLON);
                     end;
                  end;
                objectdef :
                  begin
                    if Is_FuncRef(lDef) then
                      begin
                        if not CheckProcDirective(true) then
                          begin
                            TryConsumeHintDirective(lNewType.SymOptions,lNewType.DeprecatedMsg);
                            Consume(_SEMICOLON);
                          end;
                        ParseProcTypeDirectives(lDef);
                        if TryConsumeHintDirective(lNewType.SymOptions,lNewType.DeprecatedMsg) then
                          Consume(_SEMICOLON);
                      end
                    else
                      begin
                        TryConsumeHintDirective(lNewType.SymOptions,lNewType.DeprecatedMsg);
                        Consume(_SEMICOLON);
                      end;

                    { change a forward and external class declaration into
                      formal external definition, so the compiler does not
                      expect an real definition later }
                    if Is_ObjC_Class_Or_Protocol(lDef) then
                      FinalizeClassExternalStatus(TObjectDef(lDef));

                    { Build VMT indexes, skip for type renaming and forward classes }
                    if not lIsTypeRenaming and
                       not(oo_is_forward in TObjectDef(lDef).ObjectOptions) then
                      if not (oo_inherits_not_specialized in TObjectDef(lDef).ObjectOptions) then
                        Build_VMT(TObjectDef(lDef))
                      else
                      { update the procdevs to add hidden self param }
                      Insert_Struct_Hidden_Paras(TObjectDef(lDef));

                    { In case of an objcclass, verify that all methods have a message
                      name set. We only check this now, because message names can be set
                      during the protocol (interface) mapping. At the same time, set the
                      mangled names (these depend on the "external" name of the class),
                      and mark private fields of external classes as "used" (to avoid
                      bogus notes about them being unused)
                    }
                    { watch out for crashes in case of errors }
                    if Is_ObjC_Class_Or_Protocol(lDef) and
                       (not Is_ObjCCategory(lDef) or
                        Assigned(TObjectDef(lDef).ChildOf)) then
                      begin
                        TObjectDef(lDef).Finish_ObjC_Data;
                        TObjectDef(lDef).SymTable.DefList.ForEachCall(@PDSetObjCRelatedResult,nil);
                      end;

                    if Is_CPPClass(lDef) then
                      TObjectDef(lDef).Finish_CPP_Data;
                  end;
                recorddef :
                  begin
                    TryConsumeHintDirective(lNewType.SymOptions,lNewType.DeprecatedMsg);
                    Consume(_SEMICOLON);
                  end;
                else
                  begin
                    TryConsumeHintDirective(lNewType.SymOptions,lNewType.DeprecatedMsg);
                    Consume(_SEMICOLON);
                  end;
              end;

              { if we have a real type definition or a unique type we may bind
                attributes to this def }
              if not lIsTypeRenaming or lIsUnique then
                TRTTIAttributeList.bind(ARTTIAttrsDef,TStoredDef(lDef).RTTIAttributeList);

              if df_generic in lDef.DefOptions then
                { flag parent symtables that they now contain a generic }
                lDef.owner.IncludeOption(sto_has_generic);
            end;

           if lIsGeneric and (not(lDef.typ in [objectdef,recorddef,arraydef,procvardef])
               or Is_ObjectPascal_Helper(lDef)) then
             begin
               lNewType.TypeDef:=GenErrorDef;
               message(parser_e_cant_create_generics_of_this_type);
             end;

           { Stop recording a generic template }
           if Assigned(lGenericTypeList) then
             begin
               CurrentScanner.StopRecordTokens;
               TStoredDef(lDef).GenericTokenBuf:=lLocalGenericTokenBuf;
               { Generic is never a type renaming }
               lDef.TypeSym:=lNewType;
               { reusing a forward declared type also reuses the type parameters,
                 so free them if they haven't been used }
               for lIndex:=0 to lGenericTypeList.count-1 do
                 begin
                   if (TStoredSym(lGenericTypeList[lIndex]).typ=TypeSym) and
                       not TTypeSym(lGenericTypeList[lIndex]).TypeDef.IsRegistered then
                     FreeAndNil(TTypeSym(lGenericTypeList[lIndex]).TypeDef);
                   if not TStoredSym(lGenericTypeList[lIndex]).IsRegistered then
                     TStoredSym(lGenericTypeList[lIndex]).free; // no nil needed
                 end;
               lGenericTypeList.free;
               lGenericTypeList := nil;
             end;

           if not (m_delphi in CurrentSettings.ModeSwitches) and
               (CurrentScanner.FToken=_ID) and (CurrentScanner.FIDToken=_GENERIC) then
             begin
               AHadGeneric:=true;
               Consume(_ID);
               if CurrentScanner.FToken in [_PROCEDURE,_FUNCTION,_CLASS] then
                 break;
             end
           else
             AHadGeneric:=false;
           lFirst:=false;
           if Assigned(ARTTIAttrsDef) and (ARTTIAttrsDef.GetAttributeCount>0) then
             Message1(parser_e_unbound_attribute,TRTTIAttribute(ARTTIAttrsDef.RTTIAttributes[0]).TypeSym.prettyname);


         until ((CurrentScanner.FToken<>_ID) and (CurrentScanner.FToken<>_LECKKLAMMER)) or
               (AInStructure and
                ((CurrentScanner.FIDToken in [_PRIVATE,_PROTECTED,_PUBLIC,_PUBLISHED,_STRICT]) or
                 ((m_final_fields in CurrentSettings.ModeSwitches) and
                  (CurrentScanner.FIDToken=_FINAL))));
         { resolve type block forward declarations and restore a unit
           container for them }
         ResolveForwardTypes;
         CurrentModule.CheckForwardDefs.free;
         CurrentModule.CheckForwardDefs:=lOldCheckForwardDefs;
         Block_Type:=lOldBlockType;
      end;


    { reads a type declaration to the symbol table }
    procedure TypeDec(out AHadGeneric:Boolean);
      var
        lRTTIAttrsDef: TRTTIAttributeList;
      begin
        Consume(_TYPE);
        lRTTIAttrsDef := nil;
        TypesDec(false,AHadGeneric,lRTTIAttrsDef);
        lRTTIAttrsDef.free;
        lRTTIAttrsDef := nil;
      end;


    procedure VarDec(out AHadGeneric:Boolean);
    { parses variable declarations and inserts them in }
    { the top symbol table of symtablestack         }
      begin
        Consume(_VAR);
        ReadVarDecls([vdCheckGeneric],AHadGeneric);
      end;


    procedure PropertyDec;
    { parses a global property (fpc mode feature) }
      var
         lOldBlockType: TBlockType;
      begin
         Consume(_PROPERTY);
         if not(SymTableStack.top.SymTableType in [staticsymtable,GlobalSymTable]) then
           message(parser_e_property_only_sgr);
         lOldBlockType:=Block_Type;
         Block_Type:=bt_const;
         repeat
           ReadPropertyDec(false, nil);
           Consume(_SEMICOLON);
         until CurrentScanner.FToken<>_ID;
         Block_Type:=lOldBlockType;
      end;


    procedure ThreadVarDec(out AHadGeneric:Boolean);
    { parses thread variable declarations and inserts them in }
    { the top symbol table of symtablestack                }
      begin
        Consume(_THREADVAR);
        if not(SymTableStack.top.SymTableType in [staticsymtable,GlobalSymTable]) then
          message(parser_e_threadvars_only_sg);
        if f_threading in Features then
          ReadVarDecls([vdThreadVar,vdCheckGeneric],AHadGeneric)
        else
          begin
            Message1(parser_f_unsupported_feature,FeatureStr[f_threading]);
            ReadVarDecls([vdCheckGeneric],AHadGeneric);
          end;
      end;


    procedure ResourceStringDec(out AHadGeneric:Boolean);
      var
         lOrgName : TIDString;
         lNode : TNode;
         lDummySymOptions : TSymOptions;
         lDeprecatedMsg : PShortString;
         lSavedTokenPos,lFilePos : TFilePosInfo;
         lOldBlockType : TBlockType;
         lStringData : PChar;
         lSym : TSym;
         lFirst,
         lIsGeneric : Boolean;
         lWideString : TCompilerWideString;

      begin
         Consume(_RESOURCESTRING);
         if not(SymTableStack.top.SymTableType in [staticsymtable,GlobalSymTable]) then
           message(parser_e_resourcestring_only_sg);
         lFirst:=true;
         AHadGeneric:=false;
         lOldBlockType:=Block_Type;
         Block_Type:=bt_const;
         repeat
           lOrgName:=CurrentScanner.FOrgPattern;
           lFilePos:=CurrentTokenPos;
           lIsGeneric:=not (m_delphi in CurrentSettings.ModeSwitches) and (CurrentScanner.FToken=_ID) and (CurrentScanner.FIDToken=_GENERIC);
           Consume(_ID);
           case CurrentScanner.FToken of
             _EQ:
                begin
                   Consume(_EQ);
                   lNode:=CompExpr([efAcceptEqual]);
                   lSavedTokenPos:=CurrentTokenPos;
                   CurrentTokenPos:=lFilePos;
                   lSym:=nil;
                   case lNode.nodetype of
                      ordconstn:
                        begin
                           if Is_ConstCharNode(lNode) then
                             begin
                                if not Is_SystemUnit_Unicode then
                                  begin
                                  GetMem(lStringData,2);
                                  lStringData[0]:=chr(TOrdConstNode(lNode).Value.svalue);
                                  lStringData[1]:=#0;
                                  lSym:=CConstSym.Create_String(lOrgName,constresourcestring,lStringData,1,nil);
                                  end
                                else
                                  begin
                                  InitWideString(lWideString);
                                  SetLengthWideString(lWideString,1);
                                  lWideString.data[0]:=TOrdConstNode(lNode).Value.svalue;
                                  lSym:=CConstSym.Create_WString(lOrgName,constwresourcestring,lWideString);
                                  end;
                             end
                           else
                             Message(parser_e_illegal_expression);
                        end;
                      stringconstn:
                        with TStringConstNode(lNode) do
                          begin
                             if not Is_SystemUnit_Unicode  then
                               begin
                               if ConstStringType in [cst_widestring,cst_unicodestring] then
                                 ChangeStringType(GetAnsiStringDef);
                               GetMem(lStringData,len+1);
                               lStringData[len]:=#0;
                               if len>0 then
                                 move(ValueAS[0],lStringData^,len);
                               lSym:=CConstSym.Create_String(lOrgName,constresourcestring,lStringData,len,nil);
                               end
                             else
                               begin
                               // For unicode rtl, resourcestrings are unicodestrings
                               if ConstStringType in [cst_conststring,cst_longstring, cst_shortstring,cst_ansistring] then
                                 ChangeStringType(CUnicodeStringType);
                               InitWideString(lWideString);
                               CopyWideString(ValueWS,lWideString);
                               lSym:=CConstSym.Create_WString(lOrgName,constwresourcestring,lWideString);
                               end;
                          end;
                      else
                        Message(parser_e_illegal_expression);
                   end;
                   CurrentTokenPos:=lSavedTokenPos;
                   { Support hint directives }
                   lDummySymOptions:=[];
                   lDeprecatedMsg:=nil;
                   TryConsumeHintDirective(lDummySymOptions,lDeprecatedMsg);
                   if Assigned(lSym) then
                     begin
                       lSym.SymOptions:=lSym.SymOptions+lDummySymOptions;
                       lSym.DeprecatedMsg:=lDeprecatedMsg;
                       SymTableStack.top.InsertSym(lSym);
                     end
                   else
                     StringDispose(lDeprecatedMsg);
                   Consume(_SEMICOLON);
                   lNode.free;
                   lNode := nil;
                end;
              else
                if not lFirst and lIsGeneric and
                    (CurrentScanner.FToken in [_PROCEDURE, _FUNCTION, _CLASS]) then
                  begin
                    AHadGeneric:=true;
                    break;
                  end
                else
                  Consume(_EQ);
           end;
           lFirst:=false;
         until CurrentScanner.FToken<>_ID;
         Block_Type:=lOldBlockType;
      end;

end.
