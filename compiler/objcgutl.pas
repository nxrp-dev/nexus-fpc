{
    Copyright (c) 2009 by Jonas Maebe

    This unit implements some Objective-C helper routines at the code generator
    level.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License,or
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

{$i fpcdefs.inc}

unit objcgutl;

interface

  uses
    CClasses,
    aasmbase,AAsmData,
    SymBase,symdef;

  procedure ObjCFinishStringRefPoolEntry(AEntry: PHashSetItem; AStringPool: TConstPoolType; AReferenceSection, AStringSection: TAsmSectiontype);
  procedure ObjCFinishClassRefNFPoolEntry(AEntry: PHashSetItem; AClassDef: TObjectDef);

  procedure MaybeGenerateObjectiveCImageInfo(AGlobalST, ALocalST: TSymTable);


implementation

  uses
    GlobType,Globals,FModule,CUtils,
    Systems,
    aasmtai,
    cgbase,
    objcdef,objcutil,
    aasmcnst,
    symconst,symtype,SymSym,SymTable,
    ngenutil,
    Verbose;

  type
    TObjCABI = (oa_fragile, oa_nonfragile);
(*    tivarlayouttype = (il_weak,il_strong); *)

    TObjCRTTIWriter = class
     protected
      FABI: TObjCABI;
      FClassDefs,
      FCategoryDefs: TFPObjectList;
      FClassRTTIDefs,
      FCategoryRTTIDefs: TFPObjectList;
      FClassSyms,
      FCategorySyms: TFPObjectList;
      procedure GenObjCProtocolMethodsCommon(
        AList: TAsmList;
        AClassDef: TObjectDef;
        ARequiredInstanceMethods,AOptionalInstanceMethods,ARequiredClassMethods,AOptionalClassMethods: TFPObjectList;
        out ARequiredInstanceSym,AOptionalInstanceSym,ARequiredClassSym,AOptionalClassSym: TAsmSymbol);
      procedure GenObjCMethods(AList: TAsmList; AObjCClass: TObjectDef; out AMethodsLabel: TAsmSymbol; AClassMethods, AIsCategory: Boolean);
      procedure GenObjCProtocolList(AList:TAsmList; AClassDef: TObjectDef; AZeroTerminator: Boolean; out AProtocolListSym: TAsmSymbol);
      procedure GenObjCCatMethods(AList:TAsmList; AClassDef: TObjectDef; AItems: TFPObjectList; ARTTIType: TObjCRTTIType; ASection: TAsmSectiontype;const ASectionName: String; out AListSym: TAsmSymbol);

      procedure GenObjCProtocol(AList:TAsmList; AProtocol: TObjectDef; out AProtocolLabel: TAsmSymbol);virtual;abstract;
      procedure GenObjCCategorySections(AList:TAsmList; AObjCCategory: TObjectDef; out ACategoryLabel: TAsmSymbol; out ACategoryLabelDef: TDef);virtual;abstract;
      procedure GenObjCClassesSections(AList:TAsmList; AObjCClass: TObjectDef; out AClassLabel: TAsmSymbol; out AClassLabelDef: TDef);virtual;abstract;
      procedure GenObjCInfoSections(AList: TAsmList);virtual;abstract;
      procedure GetObjCProtocolMethods(const AProtocol: TObjectDef; out ARequiredInstanceMethods, AOptionalInstanceMethods, ARequiredClassMethods, AOptionalClassMethods: TFPObjectList);
     public
      constructor Create(AABI: TObjCABI);
      destructor Destroy;override;
      procedure GenObjCRTTISections(AList:TAsmList; ASymTable:TSymTable);
      property ABI: TObjCABI read FABI;
    end;


    { Used by by PowerPC/32 and i386 }
    TObjCRTTIWriterFragile = class(TObjCRTTIWriter)
     protected
      function GenObjCProtocolExt(AList: TAsmList; AOptionalInstanceSym, AOptionalClassSym: TAsmSymbol): TAsmLabel;
      procedure GenObjCProtocolElements(AList: TAsmList; AProtocol: TObjectDef; out ARequiredInstanceSym, AOptionalInstanceSym, ARequiredClassSym, AOptionalClassSym: TAsmSymbol);
      procedure GenObjCIVars(AList: TAsmList; AObjCClass: TObjectDef; out AIVarsLabel: TAsmLabel);
      procedure GenObjCProtocol(AList:TAsmList; AProtocol: TObjectDef; out AProtocolLabel: TAsmSymbol);override;
      procedure GenObjCCategorySections(AList:TAsmList; AObjCCategory: TObjectDef; out ACategoryLabel: TAsmSymbol; out ACategoryLabelDef: TDef);override;
      procedure GenObjCClassesSections(AList:TAsmList; AObjCClass: TObjectDef; out AClassLabel: TAsmSymbol; out AClassLabelDef: TDef);override;
      procedure GenObjCInfoSections(AList: TAsmList);override;
     public
      constructor Create;
    end;


    { Used by PowerPC/64, ARM, x86_64 and AArch64 }
    TObjCRTTIWriterNonFragile = class(TObjCRTTIWriter)
     protected
      FObjCEmptyCacheVar,
      FObjCEmptyVtableVar: TAsmSymbol;

      procedure GenObjCClassROPart(AList: TAsmList; AObjCClass: TObjectDef; AProtocolListSym: TAsmSymbol; out AClassROLabel: TAsmSymbol; AMetaClass: Boolean);
      procedure AddClassList(AList: TAsmList; ASection: TAsmSectiontype; const ASymName: String; AClasses: TFPObjectList);
      procedure GenObjCProtocolExtMethodTypes(AList: TAsmList; AProtocol: TObjectDef; AItems: TFPObjectList; out AExtMethodSym: TAsmSymbol);
      procedure GenObjCProtocolElements(AList: TAsmList; AProtocol: TObjectDef; out ARequiredInstanceSym, AOptionalInstanceSym, ARequiredClassSym, AOptionalClassSym: TAsmSymbol; out AExtMethodSym: TAsmSymbol);

      procedure GenObjCIVars(AList: TAsmList; AObjCClass: TObjectDef; out AIVarsLabel: TAsmLabel);
      procedure GenObjCProtocol(AList:TAsmList; AProtocol: TObjectDef; out AProtocolLabel: TAsmSymbol);override;
      procedure GenObjCCategorySections(AList:TAsmList; AObjCCategory: TObjectDef; out ACategoryLabel: TAsmSymbol; out ACategoryLabelDef: TDef);override;
      procedure GenObjCClassesSections(AList:TAsmList; AObjCClass: TObjectDef; out AClassLabel: TAsmSymbol; out AClassLabelDef: TDef);override;
      procedure GenObjCInfoSections(AList: TAsmList);override;
     public
      constructor Create;
    end;



{******************************************************************
                    Protocol declaration helpers
*******************************************************************}

function ObjCFindProtocolEntry(const AProtocolName: ShortString): TAsmSymbol;
  var
    lItem  : PHashSetItem;
  begin
    Result:=nil;
    if not Assigned(CurrentAsmData.ConstPools[sp_objcprotocolrefs]) then
      exit;
    lItem:=CurrentAsmData.constpools[sp_objcprotocolrefs].Find(@AProtocolName[1], length(AProtocolName));
    if not Assigned(lItem) then
      exit;
    Result:=TAsmSymbol(lItem^.Data);
  end;


function ObjCAddProtocolEntry(const AProtocolName: ShortString; AReference: TAsmSymbol): Boolean;
  var
    lItem  : PHashSetItem;
  begin
    lItem:=CurrentAsmData.constpools[sp_objcprotocolrefs].FindOrAdd(@AProtocolName[1], length(AProtocolName));
    Result:=(lItem^.Data=nil);
    if Result then
      lItem^.Data:=AReference;
  end;

{******************************************************************
                       Pool section helpers
*******************************************************************}

procedure ObjCreateStringPoolEntryIntern(AString: PChar; ALength: LongInt; APoolType: TConstPoolType; AStringSection: TAsmSectiontype; out AAsmSym: TAsmLabel; out ADef: TDef);
  var
    lEntry  : PHashSetItem;
    lStringLabel : TAsmLabel;
    lPool   : THashSet;
    lTypedConstBuilder    : TTAITypedConstBuilder;
  begin
    lPool := CurrentAsmData.constpools[APoolType];

    lEntry:=lPool.FindOrAdd(AString,ALength);
    if not Assigned(lEntry^.data) then
      begin
        { create new entry }
        CurrentAsmData.getlabel(lStringLabel,alt_data);
        lEntry^.Data:=lStringLabel;

        { Make sure strlab has a reference }
        lStringLabel.increfs;

        { add the string to the appropriate section }
        lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_is_lab,tcalo_new_section]);
        ADef:=lTypedConstBuilder.emit_pchar_const(PChar(lEntry^.key),lEntry^.keylength);
        CurrentAsmData.asmlists[al_objc_pools].ConcatList(
          lTypedConstBuilder.get_final_asmlist(lStringLabel,ADef,AStringSection,lStringLabel.name,1)
        );
        lTypedConstBuilder.free;
        lTypedConstBuilder := nil;
        ADef:=CPointerDef.getreusable(ADef);
      end
    else
      ADef:=CPointerDef.getreusable(CArrayDef.getreusable(CAnsiCharType,ALength+1));
    AAsmSym:=TAsmLabel(lEntry^.Data);
  end;


procedure ObjCFinishStringRefPoolEntry(AEntry: PHashSetItem; AStringPool: TConstPoolType; AReferenceSection, AStringSection: TAsmSectiontype);
  var
    lReferenceLabel,
    lStringLabel : TAsmLabel;
    lClassName: String;
    lTypedConstBuilder: TTAITypedConstBuilder;
    lStringDef: TDef;
  begin
    { have we already generated a reference for this string entry? }
    if not Assigned(AEntry^.Data) then
      begin
        { no, add the string to the associated strings section }
        ObjCreateStringPoolEntryIntern(PChar(AEntry^.key),AEntry^.keylength,AStringPool,AStringSection,lStringLabel,lStringDef);

        { and now finish the reference }
        CurrentAsmData.getlabel(lReferenceLabel,alt_data);
        AEntry^.Data:=lReferenceLabel;

        { add a pointer to the string in the string references section }
        lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_is_lab,tcalo_new_section,tcalo_no_dead_strip]);

        lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lStringLabel),lStringDef);
        CurrentAsmData.asmlists[al_objc_pools].ConcatList(
          lTypedConstBuilder.get_final_asmlist(lReferenceLabel,lStringDef,AReferenceSection,lReferenceLabel.name,sizeof(PInt))
          );
        lTypedConstBuilder.free;
        lTypedConstBuilder := nil;

        { in case of a class reference, also add a lazy symbol reference for
          the class (the linker requires this for the fragile ABI). }
        if (AReferenceSection=sec_objc_cls_refs) and
           not(TargetInfo.system in systems_objc_nfabi) then
          begin
            lClassName:='';
            SetLength(lClassName,AEntry^.keylength);
            move(AEntry^.key^,lClassName[1],AEntry^.keylength);
            { no way to express this in LLVM either, they also just emit
              module level assembly for it }
            CurrentAsmData.asmlists[al_pure_assembler].concat(TAIDirective.Create(asd_lazy_reference,'.objc_class_name_'+lClassName));
          end;
      end;
  end;


procedure ObjCreateStringPoolEntry(const AString: String; APoolType: TConstPoolType; AStringSection: TAsmSectiontype; out AAsmSym: TAsmLabel; out ADef: TDef);
  begin
    ObjCreateStringPoolEntryIntern(@AString[1],length(AString),APoolType,AStringSection,AAsmSym,ADef);
  end;


procedure ObjCFinishClassRefNFPoolEntry(AEntry: PHashSetItem; AClassDef: TObjectDef);
  var
    lReferenceLabel: TAsmLabel;
    lClassSym: TAsmSymbol;
    lTypedConstBuilder: TTAITypedConstBuilder;
  begin
    { have we already generated a reference for this class ref entry? }
    if not Assigned(AEntry^.Data) then
      begin
        { no, add the classref to the sec_objc_cls_refs section }
        CurrentAsmData.getlabel(lReferenceLabel,alt_data);
        AEntry^.Data:=lReferenceLabel;

        { add a pointer to the class }
        lClassSym:=CurrentAsmData.RefAsmSymbol(AClassDef.RTTIMangledName(objcclassrtti),AT_DATA);

        lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_is_lab,tcalo_new_section]);
        lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lClassSym),VoidPointerType);
        CurrentAsmData.asmlists[al_objc_pools].ConcatList(
          lTypedConstBuilder.get_final_asmlist(lReferenceLabel,VoidPointerType,sec_objc_cls_refs,lReferenceLabel.name,sizeof(PInt))
        );
        lTypedConstBuilder.free;
        lTypedConstBuilder := nil;
      end;
  end;

{******************************************************************
                    RTTI generation -- Helpers
*******************************************************************}

procedure ConcatSymOrNil(ATypedConstBuilder: TTAITypedConstBuilder; AAsmSym: TAsmSymbol; ADef: TDef); inline;
begin
  if Assigned(AAsmSym) then
    ATypedConstBuilder.emit_tai(TAIConst.Create_sym(AAsmSym),ADef)
  else
    ATypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,ADef);
end;


{******************************************************************
                 RTTI generation -- Common
*******************************************************************}

{ generate a method list, either of class methods or of instance methods,
  and both for obj-c classes and categories. }
procedure TObjCRTTIWriter.GenObjCMethods(AList: TAsmList; AObjCClass: TObjectDef; out AMethodsLabel: TAsmSymbol; AClassMethods, AIsCategory: Boolean);
  const
                     {clas/cat inst/cls}
    cSectTypes : array [Boolean, Boolean] of TAsmSectiontype =
      ((sec_objc_inst_meth, sec_objc_cls_meth),
       (sec_objc_cat_inst_meth, sec_objc_cat_cls_meth));
                     {clas/cat inst/cls}
    cSectNames : array [Boolean, Boolean] of String[20] =
      (('_OBJC_INST_METH','_OBJC_CLS_METH'),
       ('_OBJC_CAT_INST_METH','_OBJC_CAT_CLS_METH'));
                   {frag/non-frag ABI}
    cSectFlags : array [Boolean] of TTCAsmListOptions =
     ([tcalo_new_section],[tcalo_new_section,tcalo_no_dead_strip]);
                        {inst/cls}
    cInstClassNames : array [Boolean] of String = ('INSTANCE','CLASS');
  type
    TMethodData = record
      Def     : TProcDef;
      SelectorSym  : TAsmLabel;
      SelectorDef  : TDef;
      EncodingSym  : TAsmLabel;
      EncodingDef  : TDef;
    end;
  var
    lIndex     : Integer;
    lDef   : TProcDef;
    lDefs  : array of TMethodData;
    lMethodCount  : Integer;
    lMethodType : TDef;
    lTypedConstBuilder   : TTAITypedConstBuilder;
    lMethodDef  : TDef;
  begin
    AMethodsLabel:=nil;
    lMethodCount:=0;
    lDefs:=nil;
    { collect all instance/class methods }
    SetLength(lDefs,AObjCClass.VMTEntries.count);
    for lIndex:=0 to AObjCClass.VMTEntries.count-1 do
      begin
        lDef:=PVMTEntry(AObjCClass.VMTEntries[lIndex])^.procdef;
        if (lDef.owner.DefOwner=AObjCClass) and
           (AClassMethods = (po_classmethod in lDef.ProcOptions)) then
          begin
            lDefs[lMethodCount].Def:=lDef;
            ObjCreateStringPoolEntry(lDef.MessageInf.str^,sp_objcvarnames,sec_objc_meth_var_names,lDefs[lMethodCount].SelectorSym,lDefs[lMethodCount].SelectorDef);
            ObjCreateStringPoolEntry(ObjCEncodeMethod(lDef),sp_objcvartypes,sec_objc_meth_var_types,lDefs[lMethodCount].EncodingSym,lDefs[lMethodCount].EncodingDef);
            inc(lMethodCount);
          end;
      end;
    if lMethodCount=0 then
      exit;

    lTypedConstBuilder:=CTAITypedConstBuilder.Create(cSectFlags[TargetInfo.system in systems_objc_nfabi]);
    lTypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itp_objc_method_list]+ToStr(lMethodCount),
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

    if (ABI=oa_fragile) then
      { not used, always zero }
      lTypedConstBuilder.emit_ord_const(0,U32IntType)
    else
      begin
        { size of each entry -- always 32 bit value }
        lMethodType:=Search_Named_Unit_GlobalType('OBJC','OBJC_METHOD',true).TypeDef;
        lTypedConstBuilder.emit_ord_const(lMethodType.Size,U32IntType);
      end;
    { number of objc_method entries in the method_list array -- always 32 bit}
    lTypedConstBuilder.emit_ord_const(lMethodCount,U32IntType);
    for lIndex:=0 to lMethodCount-1 do
      begin
        { reference to the selector name }
        lTypedConstBuilder.queue_init(CharPointerType);
        lTypedConstBuilder.queue_emit_asmsym(lDefs[lIndex].SelectorSym,lDefs[lIndex].SelectorDef);
        { reference to the obj-c encoded function parameters (signature) }
        lTypedConstBuilder.queue_init(CharPointerType);
        lTypedConstBuilder.queue_emit_asmsym(lDefs[lIndex].EncodingSym,lDefs[lIndex].EncodingDef);
        { mangled name of the method }
        lTypedConstBuilder.queue_init(VoidCodePointerType);
        lTypedConstBuilder.queue_emit_proc(lDefs[lIndex].Def);
      end;

    lMethodDef:=lTypedConstBuilder.end_anonymous_record;
    if AIsCategory then
      begin
        AMethodsLabel:=CurrentAsmData.DefineAsmSymbol('l_OBJC_$_CATEGORY_'+cInstClassNames[AClassMethods]+'_METHODS_'+AObjCClass.ObjExtName^+'_$_'+AObjCClass.ChildOf.ObjExtName^,AB_LOCAL,AT_DATA,lMethodDef);
      end
    else
      begin
        AMethodsLabel:=CurrentAsmData.DefineAsmSymbol('l_OBJC_$_'+cInstClassNames[AClassMethods]+'_METHODS_'+AObjCClass.ObjExtName^,AB_LOCAL,AT_DATA,lMethodDef);
      end;
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(AMethodsLabel,lMethodDef,
        cSectTypes[AIsCategory,AClassMethods],
        cSectNames[AIsCategory,AClassMethods],sizeof(PtrInt)
      )
    );
    lTypedConstBuilder.free;
    lTypedConstBuilder := nil;
  end;

procedure TObjCRTTIWriter.GenObjCProtocolMethodsCommon(
  AList: TAsmList;
  AClassDef: TObjectDef;
  ARequiredInstanceMethods,AOptionalInstanceMethods,ARequiredClassMethods,AOptionalClassMethods: TFPObjectList;
  out ARequiredInstanceSym,AOptionalInstanceSym,ARequiredClassSym,AOptionalClassSym: TAsmSymbol);
begin
  if ARequiredInstanceMethods.Count > 0 then
    GenObjCCatMethods(AList,AClassDef,ARequiredInstanceMethods,objcinstancemethods,sec_objc_cat_inst_meth,'_OBJC_CAT_INST_METH',ARequiredInstanceSym)
  else
    ARequiredInstanceSym:=nil;
  if AOptionalInstanceMethods.Count > 0 then
    GenObjCCatMethods(AList,AClassDef,AOptionalInstanceMethods,objcprotinstancemethodsopt,sec_objc_cat_inst_meth,'_OBJC_CAT_INST_METH', AOptionalInstanceSym)
  else
    AOptionalInstanceSym:=nil;

  if ARequiredClassMethods.Count>0 then
    GenObjCCatMethods(AList, AClassDef,ARequiredClassMethods,objcclassmethods,sec_objc_cat_cls_meth,'_OBJC_CAT_CLS_METH', ARequiredClassSym)
  else
    ARequiredClassSym:=nil;
  if AOptionalClassMethods.Count>0 then
    GenObjCCatMethods(AList, AClassDef,AOptionalClassMethods,objcprotclassmethodsopt,sec_objc_cat_cls_meth,'_OBJC_CAT_CLS_METH', AOptionalClassSym)
  else
    AOptionalClassSym:=nil;
end;


(*
From CLang:

  struct objc_protocol_list
  {
#ifdef FRAGILE_ABI
      struct objc_protocol_list *next;
      int count;
#else
      long count;
#endif
      Protocol *list[1];
  };
*)
procedure TObjCRTTIWriter.GenObjCProtocolList(AList: TAsmList; AClassDef: TObjectDef; AZeroTerminator: Boolean; out AProtocolListSym: TAsmSymbol);
  var
    lIndex         : Integer;
    lProtocolSym  : TAsmSymbol;
    lProtocolDef  : TObjectDef;
    lProtocolList : TFPObjectList;
    lTypedConstBuilder       : TTAITypedConstBuilder;
    lDef       : TDef;
  begin
    lProtocolList:=AClassDef.ImplementedInterfaces;;
    if not Assigned(lProtocolList) or
       (lProtocolList.Count=0) then
      begin
        AProtocolListSym:=nil;
        Exit;
      end;

    for lIndex:=0 to lProtocolList.Count-1 do
      begin
        lProtocolDef:=TImplementedInterface(lProtocolList[lIndex]).IntfDef;
        lProtocolSym:=ObjCFindProtocolEntry(lProtocolDef.ObjExtName^);
        if not Assigned(lProtocolSym) then
          begin
            GenObjCProtocol(AList,lProtocolDef,lProtocolSym);
            ObjCAddProtocolEntry(lProtocolDef.ObjExtName^,lProtocolSym);
          end;
      end;

    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section]);
    lTypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itp_objc_proto_list]+ToStr(lProtocolList.Count),
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

    if (ABI=oa_fragile) then
      { From Clang: next, always nil}
      lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,PtrUIntType);
    { From Clang: protocols count}
    lTypedConstBuilder.emit_tai(TAIConst.Create_int_dataptr(lProtocolList.Count),PtrUIntType);
    for lIndex:=0 to lProtocolList.Count-1 do
      begin
        lProtocolDef:=(lProtocolList[lIndex] as TImplementedInterface).IntfDef;
        lProtocolSym:=ObjCFindProtocolEntry(lProtocolDef.ObjExtName^);
        if not Assigned(lProtocolSym) then
          begin
            { For some reason protosym is not declared, though must be!
              Probably gen_obcj1_protocol returned wrong protosym
            }
            InternalError(2009091602);
          end;
        lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lProtocolSym),VoidPointerType);
      end;

    if AZeroTerminator then
      lTypedConstBuilder.emit_tai(TAIConst.Create_nil_codeptr,VoidPointerType);

    lDef:=lTypedConstBuilder.end_anonymous_record;
    AProtocolListSym:=CurrentAsmData.DefineAsmSymbol(AClassDef.RTTIMangledName(objcprotocollist),AB_LOCAL,AT_DATA,lDef);
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        AProtocolListSym,lDef,
        sec_objc_cat_cls_meth,'_OBJC_PROTOCOLLIST',sizeof(PInt)
      )
    );
    lTypedConstBuilder.free;
    lTypedConstBuilder := nil;
    { the symbol will point to a record }
  end;


{ Generate rtti for an Objective-C methods (methods without implementation) }
{ items : TFPObjectList of Tprocdef }
procedure TObjCRTTIWriter.GenObjCCatMethods(AList:TAsmList; AClassDef: TObjectDef; AItems: TFPObjectList; ARTTIType: TObjCRTTIType; ASection: TAsmSectiontype; const ASectionName: String; out AListSym: TAsmSymbol);
var
  lIndex       : Integer;
  lMethod       : TProcDef;
  lLabel     : TAsmLabel;
  lLabelDef,
  lMethodType,
  lListDef : TDef;
  lTypedConstBuilder     : TTAITypedConstBuilder;
begin
  if not Assigned(AItems) or
     (AItems.count=0) then
    exit;

  lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section]);
  lTypedConstBuilder.begin_anonymous_record(
    InternalTypePrefixName[itp_objc_cat_methods]+ToStr(AItems.count),
    CAlignment,1,
    targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
  if (ABI=oa_nonfragile) then
    begin
      { size of each entry -- always 32 bit value }
      lMethodType:=Search_Named_Unit_GlobalType('OBJC','OBJC_METHOD',true).TypeDef;
      lTypedConstBuilder.emit_ord_const(lMethodType.Size,U32IntType);
    end;
  lTypedConstBuilder.emit_ord_const(AItems.count,U32IntType);
  for lIndex:=0 to AItems.Count-1 do
    begin
      lMethod:=TProcDef(AItems[lIndex]);
      ObjCreateStringPoolEntry(lMethod.MessageInf.str^,sp_objcvarnames,sec_objc_meth_var_names,lLabel,lLabelDef);
      lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lLabel),lLabelDef);
      ObjCreateStringPoolEntry(ObjCEncodeMethod(lMethod),sp_objcvartypes,sec_objc_meth_var_types,lLabel,lLabelDef);
      lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lLabel),lLabelDef);
      { placeholder for address of implementation? }
      if (ABI=oa_nonfragile) then
        lTypedConstBuilder.emit_tai(TAIConst.Create_nil_codeptr,CodePtrUIntType);
    end;
  lListDef:=lTypedConstBuilder.end_anonymous_record;
  AListSym:=CurrentAsmData.DefineAsmSymbol(AClassDef.RTTIMangledName(ARTTIType),AB_LOCAL,AT_DATA,lListDef);
  AList.ConcatList(
    lTypedConstBuilder.get_final_asmlist(
      AListSym,lListDef,ASection,ASectionName,sizeof(PInt))
  );
  lTypedConstBuilder.free;
  lTypedConstBuilder := nil;
end;

procedure TObjCRTTIWriter.GetObjCProtocolMethods(const AProtocol: TObjectDef; out ARequiredInstanceMethods, AOptionalInstanceMethods, ARequiredClassMethods, AOptionalClassMethods: TFPObjectList);
var
  lIndex: PtrInt;
  lProcDef: TProcDef;
begin
  ARequiredInstanceMethods:=TFPObjectList.Create(false);
  ARequiredClassMethods:=TFPObjectList.Create(false);
  AOptionalInstanceMethods:=TFPObjectList.Create(false);
  AOptionalClassMethods:=TFPObjectList.Create(false);
  for lIndex:=0 to AProtocol.VMTEntries.Count-1 do
    begin
      lProcDef:=PVMTEntry(AProtocol.VMTEntries[lIndex])^.procdef;
      if (po_classmethod in lProcDef.ProcOptions) then
        if not(po_optional in lProcDef.ProcOptions) then
          ARequiredClassMethods.Add(lProcDef)
        else
          AOptionalClassMethods.Add(lProcDef)
      else if not(po_optional in lProcDef.ProcOptions) then
        ARequiredInstanceMethods.Add(lProcDef)
      else
        AOptionalInstanceMethods.Add(lProcDef);
    end;
end;


{ Generate the rtti sections for all obj-c classes defined in st, and return
  these classes in the classes list. }
procedure TObjCRTTIWriter.GenObjCRTTISections(AList:TAsmList; ASymTable:TSymTable);
  var
    lIndex: LongInt;
    lDef,
    lRTTIDef: TDef;
    lSym: TAsmSymbol;
  begin
    if not Assigned(ASymTable) then
      exit;

    for lIndex:=0 to ASymTable.DefList.Count-1 do
      begin
        lDef:=TDef(ASymTable.DefList[lIndex]);
        { check whether all types used in Objective-C class/protocol/category
          declarations can be used with the Objective-C run time (can only be
          done now, because at parse-time some of these types can still be
          forwarddefs) }
        if Is_ObjC_Class_Or_Protocol(lDef) then
          if not TObjectDef(lDef).Check_ObjC_Types then
            continue;
        if Is_ObjCClass(lDef) and
           not(oo_is_external in TObjectDef(lDef).ObjectOptions) then
          begin
            if not(oo_is_classhelper in TObjectDef(lDef).ObjectOptions) then
              begin
                GenObjCClassesSections(AList,TObjectDef(lDef),lSym,lRTTIDef);
                FClassSyms.add(lSym);
                FClassRTTIDefs.add(lRTTIDef);
                FClassDefs.add(lDef);
              end
            else
              begin
                GenObjCCategorySections(AList,TObjectDef(lDef),lSym,lRTTIDef);
                FCategorySyms.add(lSym);
                FCategoryRTTIDefs.add(lRTTIDef);
                FCategoryDefs.add(lDef);
              end
          end;
      end;
  end;


constructor TObjCRTTIWriter.Create(AABI: TObjCABI);
  begin
    FABI:=AABI;
    FClassDefs:=TFPObjectList.Create(false);
    FClassSyms:=TFPObjectList.Create(false);
    FClassRTTIDefs:=TFPObjectList.Create(false);
    FCategoryRTTIDefs:=TFPObjectList.Create(false);
    FCategoryDefs:=TFPObjectList.Create(false);
    FCategorySyms:=TFPObjectList.Create(false);
  end;


destructor TObjCRTTIWriter.Destroy;
  begin
    FClassDefs.free;
    FClassDefs := nil;
    FClassSyms.free;
    FClassSyms := nil;
    FClassRTTIDefs.free;
    FClassRTTIDefs := nil;
    FCategoryRTTIDefs.free;
    FCategoryRTTIDefs := nil;
    FCategoryDefs.free;
    FCategoryDefs := nil;
    FCategorySyms.free;
    FCategorySyms := nil;
    inherited Destroy;
  end;

{******************************************************************
                 RTTI generation -- Fragile ABI
*******************************************************************}

{ generate an instance variables list for an obj-c class. }
procedure TObjCRTTIWriterFragile.GenObjCIVars(AList: TAsmList; AObjCClass: TObjectDef; out AIVarsLabel: TAsmLabel);
  type
    TIVarData = record
      FieldSym      : TFieldVarSym;
      NameSym : TAsmLabel;
      NameDef : TDef;
      TypeSym : TAsmLabel;
      TypeDef : TDef;
    end;
  var
    lIndex     : Integer;
    lFieldSym    : TFieldVarSym;
    lIVars  : array of TIVarData;
    lIVarCount  : Integer;
    lEncodingType : AnsiString;
    lEncodingError  : TDef;
  begin
    AIVarsLabel:=nil;

    lIVarCount:=0;
    lIVars:=nil;
    SetLength(lIVars,AObjCClass.SymTable.SymList.Count);

    for lIndex:=0 to AObjCClass.SymTable.SymList.Count-1 do
      if TSym(AObjCClass.SymTable.SymList[lIndex]).typ=FieldVarSym then
        begin
          lFieldSym:=TFieldVarSym(AObjCClass.SymTable.SymList[lIndex]);
          if ObjCTryEncodeType(lFieldSym.vardef,lEncodingType,lEncodingError) then
            begin
              lIVars[lIVarCount].FieldSym:=lFieldSym;
              ObjCreateStringPoolEntry(lFieldSym.RealName,sp_objcvarnames,sec_objc_meth_var_names,lIVars[lIVarCount].NameSym,lIVars[lIVarCount].NameDef);
              ObjCreateStringPoolEntry(lEncodingType,sp_objcvartypes,sec_objc_meth_var_types,lIVars[lIVarCount].TypeSym,lIVars[lIVarCount].TypeDef);
              inc(lIVarCount);
            end
          else
            { Should be caught during parsing }
            InternalError(2009090601);
        end;
    if lIVarCount=0 then
      exit;

    new_section(AList,sec_objc_instance_vars,'_OBJC_INSTANCE_VARS',sizeof(PInt));

    CurrentAsmData.getlabel(AIVarsLabel,alt_data);
    AList.Concat(TAILabel.Create(AIVarsLabel));

    { objc_ivar_list: first the number of elements }
    AList.Concat(TAIConst.Create_32bit(lIVarCount));

    for lIndex:=0 to lIVarCount-1 do
      begin
        { reference to the instance variable name }
        AList.Concat(TAIConst.Create_sym(lIVars[lIndex].NameSym));
        { reference to the encoded type }
        AList.Concat(TAIConst.Create_sym(lIVars[lIndex].TypeSym));
        { and the offset of the field }
        AList.Concat(TAIConst.Create_32bit(lIVars[lIndex].FieldSym.FieldOffset));
      end;
  end;


(* From GCC:

  struct _objc_protocol_extension
    {
      uint32_t size;	// sizeof (struct _objc_protocol_extension)
      struct objc_method_list	*optional_instance_methods;
      struct objc_method_list   *optional_class_methods;
      struct objc_prop_list	*instance_properties;
    }
*)
function TObjCRTTIWriterFragile.GenObjCProtocolExt(AList: TAsmList; AOptionalInstanceSym, AOptionalClassSym: TAsmSymbol): TAsmLabel;
  var
    lTypedConstBuilder: TTAITypedConstBuilder;
  begin
    if Assigned(AOptionalInstanceSym) or
       Assigned(AOptionalClassSym) then
      begin
        CurrentAsmData.getlabel(Result,alt_data);
        lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_no_dead_strip]);
        lTypedConstBuilder.begin_anonymous_record(
          InternalTypePrefixName[itb_objc_fr_protocol_ext],
          CAlignment,1,
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
        { size of this structure }
        lTypedConstBuilder.emit_ord_const(16,U32IntType);
        { optional instance methods }
        ConcatSymOrNil(lTypedConstBuilder,AOptionalInstanceSym,VoidPointerType);
        { optional class methods }
        ConcatSymOrNil(lTypedConstBuilder,AOptionalClassSym,VoidPointerType);
        { optional properties (todo) }
        ConcatSymOrNil(lTypedConstBuilder,nil,VoidPointerType);
        AList.ConcatList(
          lTypedConstBuilder.get_final_asmlist(
            Result,lTypedConstBuilder.end_anonymous_record,
            sec_objc_protocol_ext,'_OBJC_PROTOCOLEXT',sizeof(PInt)
          )
        );
        lTypedConstBuilder.free;
        lTypedConstBuilder := nil;
      end
    else
      Result:=nil;
  end;

{ generate method (and in the future also property) info for protocols }
procedure TObjCRTTIWriterFragile.GenObjCProtocolElements(AList: TAsmList; AProtocol: TObjectDef; out ARequiredInstanceSym, AOptionalInstanceSym, ARequiredClassSym, AOptionalClassSym: TAsmSymbol);
  var
    lRequiredInstanceMethods,
    lRequiredClassMethods,
    lOptionalInstanceMethods,
    lOptionalClassMethods   : TFPObjectList;
begin
    GetObjCProtocolMethods(AProtocol,lRequiredInstanceMethods,lOptionalInstanceMethods,lRequiredClassMethods,lOptionalClassMethods);
    GenObjCProtocolMethodsCommon(AList,AProtocol,lRequiredInstanceMethods,lOptionalInstanceMethods,lRequiredClassMethods,lOptionalClassMethods,ARequiredInstanceSym,AOptionalInstanceSym,ARequiredClassSym,AOptionalClassSym);
    lRequiredInstanceMethods.Free;
    lRequiredClassMethods.Free;
    lOptionalInstanceMethods.Free;
    lOptionalClassMethods.Free;
end;

{ Generate rtti for an Objective-C protocol  }
procedure TObjCRTTIWriterFragile.GenObjCProtocol(AList:TAsmList; AProtocol: TObjectDef; out AProtocolLabel: TAsmSymbol);
  var
    lNameSym     : TAsmLabel;
    lNameDef     : TDef;
    lProtocolList,
    lRequiredInstanceSym,
    lOptionalInstanceSym,
    lRequiredClassSym,
    lOptionalClassSym   : TAsmSymbol;
    lProtocolExt,
    lLabel          : TAsmLabel;
    lTypedConstBuilder          : TTAITypedConstBuilder;
  begin
    GenObjCProtocolList(AList,AProtocol,false,lProtocolList);
    GenObjCProtocolElements(AList,AProtocol,lRequiredInstanceSym,lOptionalInstanceSym,lRequiredClassSym,lOptionalClassSym);
    lProtocolExt:=GenObjCProtocolExt(AList,lOptionalInstanceSym,lOptionalClassSym);

    CurrentAsmData.getlabel(lLabel,alt_data);
    AProtocolLabel:=lLabel;

    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_no_dead_strip]);
    lTypedConstBuilder.begin_anonymous_record(
      InternalTypePrefixName[itb_objc_fr_protocol],
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

    { protocol's isa - points to information about optional methods/properties }
    ConcatSymOrNil(lTypedConstBuilder,lProtocolExt,VoidPointerType);
    { name }
    ObjCreateStringPoolEntry(AProtocol.ObjExtName^,sp_objcclassnames,sec_objc_class_names,lNameSym,lNameDef);
    lTypedConstBuilder.queue_init(VoidPointerType);
    lTypedConstBuilder.queue_emit_asmsym(lNameSym,lNameDef);
    { protocol's list }
    ConcatSymOrNil(lTypedConstBuilder,lProtocolList,VoidPointerType);
    { instance methods, in __cat_inst_meth }
    ConcatSymOrNil(lTypedConstBuilder,lRequiredInstanceSym,VoidPointerType);
    { class methods, in __cat_cls_meth }
    ConcatSymOrNil(lTypedConstBuilder,lRequiredClassSym,VoidPointerType);
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        lLabel,lTypedConstBuilder.end_anonymous_record,
        sec_objc_protocol,'_OBJC_PROTOCOL',sizeof(PInt)
      )
    );
    lTypedConstBuilder.free;
    lTypedConstBuilder := nil;
  end;


(*
From Clang:

  struct _objc_category {
  char *category_name;
  char *class_name;
  struct _objc_method_list *instance_methods;
  struct _objc_method_list *class_methods;
  struct _objc_protocol_list *protocols;
  uint32_t size; // <rdar://4585769>
  struct _objc_property_list *instance_properties;
  };
*)

{ Generate rtti for an Objective-C class and its meta-class. }
procedure TObjCRTTIWriterFragile.GenObjCCategorySections(AList:TAsmList; AObjCCategory: TObjectDef; out ACategoryLabel: TAsmSymbol; out ACategoryLabelDef: TDef);
  var
    lCategoryStringSym,
    lClassStringSym     : TAsmLabel;
    lProtocolListSym,
    lInstanceMethodList,
    lClassMethodList,
    lCategorySym        : TAsmSymbol;
    lCategoryStringDef,
    lClassStringDef,
    lCategoryDef        : TDef;
    lTypedConstBuilder           : TTAITypedConstBuilder;
  begin
    { the category name }
    ObjCreateStringPoolEntry(AObjCCategory.ObjExtName^,sp_objcclassnames,sec_objc_class_names,lCategoryStringSym,lCategoryStringDef);

    { the name of the class it extends }
    ObjCreateStringPoolEntry(AObjCCategory.ChildOf.ObjExtName^,sp_objcclassnames,sec_objc_class_names,lClassStringSym,lClassStringDef);

    { generate the methods lists }
    GenObjCMethods(AList,AObjCCategory,lInstanceMethodList,false,true);
    GenObjCMethods(AList,AObjCCategory,lClassMethodList,true,true);

    { generate implemented protocols list }
    GenObjCProtocolList(AList,AObjCCategory,false,lProtocolListSym);

    { category declaration section }
    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_no_dead_strip]);
    lTypedConstBuilder.begin_anonymous_record(
      InternalTypePrefixName[itb_objc_fr_category],
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

    lTypedConstBuilder.queue_init(VoidPointerType);
    lTypedConstBuilder.queue_emit_asmsym(lCategoryStringSym,lCategoryStringDef);
    lTypedConstBuilder.queue_init(VoidPointerType);
    lTypedConstBuilder.queue_emit_asmsym(lClassStringSym,lClassStringDef);
    ConcatSymOrNil(lTypedConstBuilder,lInstanceMethodList,VoidPointerType);
    ConcatSymOrNil(lTypedConstBuilder,lClassMethodList,VoidPointerType);
    ConcatSymOrNil(lTypedConstBuilder,lProtocolListSym,VoidPointerType);
    { size of this structure }
    lTypedConstBuilder.emit_ord_const(28,U32IntType);
    { properties, not yet supported }
    lTypedConstBuilder.emit_ord_const(0,U32IntType);
    lCategoryDef:=lTypedConstBuilder.end_anonymous_record;
    lCategorySym:=CurrentAsmData.DefineAsmSymbol(AObjCCategory.RTTIMangledName(objcclassrtti),AB_LOCAL,AT_DATA,lCategoryDef);
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        lCategorySym,lCategoryDef,
        sec_objc_category,'_OBJC_CATEGORY',sizeof(PInt)
      )
    );
    lTypedConstBuilder.free;
    lTypedConstBuilder := nil;

    ACategoryLabel:=lCategorySym;
    ACategoryLabelDef:=lCategoryDef;
  end;

(*
From Clang:

  struct _objc_class {
    Class isa;
    Class super_class;
    const char *name;
    long version;
    long info;
    long instance_size;
    struct _objc_ivar_list *ivars;
    struct _objc_method_list *methods;
    struct _objc_cache *cache;
    struct _objc_protocol_list *protocols;
    // Objective-C 1.0 extensions (<rdr://4585769>) -- for garbage collection
    const char *ivar_layout;
    struct _objc_class_ext *ext;
  };
*)



{ Generate rtti for an Objective-C class and its meta-class. }
procedure TObjCRTTIWriterFragile.GenObjCClassesSections(AList:TAsmList; AObjCClass: TObjectDef; out AClassLabel: TAsmSymbol; out AClassLabelDef: TDef);
  const
    cClassFlag  = 1;
    cMetaFlag   = 2;
    cHiddenFlag = $20000;
    cMetaInstanceSize = 40+8; // sizeof(objc_class) + 8
  var
    lRoot          : TObjectDef;
    lMetaSym,
    lMethodList,
    lClassSym,
    lProtocolListSym  : TAsmSymbol;
    lSuperStringDef,
    lClassStringDef,
    lMetaISAStringDef,
    lMetaDef,
    lClassDef        : TDef;
    lSuperStringSym,
    lClassStringSym,
    lMetaISAStringSym,
    lIVarsList     : TAsmLabel;
    lHiddenFlag    : Cardinal;
    lTypedConstBuilder           : TTAITypedConstBuilder;

  begin
    { generate the class methods list }
    GenObjCMethods(AList,AObjCClass,lMethodList,true,false);

    { generate implemented protocols list }
    GenObjCProtocolList(AList,AObjCClass,false,lProtocolListSym);

    { register necessary names }
    { 1) the superclass }
    if Assigned(AObjCClass.ChildOf) then
      ObjCreateStringPoolEntry(AObjCClass.ChildOf.ObjExtName^,sp_objcclassnames,sec_objc_class_names,lSuperStringSym,lSuperStringDef)
    else
      begin
        { not empty string, but nil! }
        lSuperStringSym:=nil;
        lSuperStringDef:=VoidPointerType;
      end;

    { 2) the current class }
    ObjCreateStringPoolEntry(AObjCClass.ObjExtName^,sp_objcclassnames,sec_objc_class_names,lClassStringSym,lClassStringDef);
    { 3) the isa }
    { From Clang: The isa for the meta-class is the root of the hierarchy. }
    lRoot:=AObjCClass;
    while Assigned(lRoot.ChildOf) do
      lRoot:=lRoot.ChildOf;
    ObjCreateStringPoolEntry(lRoot.ObjExtName^,sp_objcclassnames,sec_objc_class_names,lMetaISAStringSym,lMetaISAStringDef);

    { 4) the flags }
    { consider every class declared in the implementation section of a unit
      as "hidden"
    }
    lHiddenFlag:=0;
    if (AObjCClass.owner.SymTableType=staticsymtable) and
       CurrentModule.IsUnit then
      lHiddenFlag:=cHiddenFlag;

    { class declaration section }

    { 1) meta-class declaration  }
    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_no_dead_strip]);
    lTypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itb_objc_fr_meta_class],
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

    lTypedConstBuilder.queue_init(VoidPointerType);
    lTypedConstBuilder.queue_emit_asmsym(lMetaISAStringSym,lMetaISAStringDef);
    { pointer to the superclass name if any, otherwise nil }
    if Assigned(lSuperStringSym) then
      begin
        lTypedConstBuilder.queue_init(VoidPointerType);
        lTypedConstBuilder.queue_emit_asmsym(lSuperStringSym,lSuperStringDef);
      end
    else
      lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { pointer to the class name }
    lTypedConstBuilder.queue_init(VoidPointerType);
    lTypedConstBuilder.queue_emit_asmsym(lClassStringSym,lClassStringDef);

    { version is always 0 currently }
    lTypedConstBuilder.emit_ord_const(0,U32IntType);
    { cMetaFlag for meta-classes }
    lTypedConstBuilder.emit_ord_const(lHiddenFlag or cMetaFlag,U32IntType);
    { size of the meta-class instance: sizeof(objc_class) + 8 bytes }
    lTypedConstBuilder.emit_ord_const(cMetaInstanceSize,U32IntType);
    { meta-classes don't have ivars list (=0) }
    lTypedConstBuilder.emit_ord_const(0,U32IntType);
    { class methods list (stored in "__cls_meth" section) }
    ConcatSymOrNil(lTypedConstBuilder,lMethodList,VoidPointerType);
    { From Clang: cache is always nil }
    lTypedConstBuilder.emit_ord_const(0,U32IntType);
    { protocols }
    ConcatSymOrNil(lTypedConstBuilder,lProtocolListSym,VoidPointerType);
    { From Clang: ivar_layout for meta-class is always NULL. }
    lTypedConstBuilder.emit_ord_const(0,U32IntType);
    { From Clang: The class extension is always unused for meta-classes. }
    lTypedConstBuilder.emit_ord_const(0,U32IntType);
    lMetaDef:=lTypedConstBuilder.end_anonymous_record;
    lMetaSym:=CurrentAsmData.DefineAsmSymbol(AObjCClass.RTTIMangledName(objcmetartti),AB_LOCAL,AT_DATA,lMetaDef);
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        lMetaSym,lMetaDef,
        sec_objc_meta_class,'_OBJC_META_CLASS',sizeof(PInt)
      )
    );
    lTypedConstBuilder.free;


    { 2) regular class declaration }

    { generate the instance methods list }
    GenObjCMethods(AList,AObjCClass,lMethodList,false,false);
    { generate the instance variables list }
    GenObjCIVars(AList,AObjCClass,lIVarsList);

    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_no_dead_strip]);
    lTypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itb_objc_fr_class],
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

    { for class declaration: the isa points to the meta-class declaration }
    lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lMetaSym),CPointerDef.getreusable(lMetaDef));
    { pointer to the super_class name if any, nil otherwise }
    if Assigned(lSuperStringSym) then
      begin
        lTypedConstBuilder.queue_init(VoidCodePointerType);
        lTypedConstBuilder.queue_emit_asmsym(lSuperStringSym,lSuperStringDef)
      end
    else
      lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidCodePointerType);
    { pointer to the class name }
    lTypedConstBuilder.queue_init(VoidCodePointerType);
    lTypedConstBuilder.queue_emit_asmsym(lClassStringSym,lClassStringDef);
    { version is always 0 currently }
    lTypedConstBuilder.emit_ord_const(0,U32IntType);
    { cClassFlag for classes }
    lTypedConstBuilder.emit_ord_const(lHiddenFlag or cClassFlag,U32IntType);
    { size of instance: total size of instance variables }
    lTypedConstBuilder.emit_ord_const(TObjectSymTable(AObjCClass.SymTable).DataSize,U32IntType);
    { objc_ivar_list (stored in "__instance_vars" section) }
    ConcatSymOrNil(lTypedConstBuilder,lIVarsList,VoidPointerType);
    { instance methods list (stored in "__inst_meth" section) }
    ConcatSymOrNil(lTypedConstBuilder,lMethodList,VoidPointerType);
    { From Clang: cache is always NULL }
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { protocols, protolistsym has been created for meta-class, no need to create another one}
    ConcatSymOrNil(lTypedConstBuilder, lProtocolListSym,VoidPointerType);
    { From Clang: strong ivar_layout, necessary for garbage collection support }
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { TODO: From Clang: weak ivar_layout, necessary for garbage collection support }
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);

    lClassDef:=lTypedConstBuilder.end_anonymous_record;
    lClassSym:=CurrentAsmData.DefineAsmSymbol(AObjCClass.RTTIMangledName(objcclassrtti),AB_LOCAL,AT_DATA,lClassDef);
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        lClassSym,lClassDef,
        sec_objc_class,'_OBJC_CLASS',sizeof(PInt)
      )
    );
    lTypedConstBuilder.free;
    lTypedConstBuilder := nil;

    AClassLabel:=lClassSym;
    AClassLabelDef:=lClassDef;
  end;


{ Generate the global information sections (objc_symbols and objc_module_info)
  for this module. }
procedure TObjCRTTIWriterFragile.GenObjCInfoSections(AList: TAsmList);
  var
    lIndex: LongInt;
    lSym : TAsmSymbol;
    lLabel : TAsmLabel;
    lSymbolsDef,
    lDef : TDef;
    lParent: TObjectDef;
    lSuperClasses: TFPObjectList;
    lTypedConstBuilder: TTAITypedConstBuilder;
  begin
    if (FClassSyms.count<>0) or
       (FCategorySyms.count<>0) then
      begin
        lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_no_dead_strip]);
        lTypedConstBuilder.begin_anonymous_record('',
          CAlignment,1,
          targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
        { ??? (always 0 in Clang) }
        lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
        { ??? (From Clang: always 0, pointer to some selector) }
        lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
        { From Clang: number of defined classes }
        lTypedConstBuilder.emit_ord_const(FClassSyms.count,U16IntType);
        { From Clang: number of defined categories }
        lTypedConstBuilder.emit_ord_const(FCategorySyms.count,U16IntType);
        { first all classes }
        for lIndex:=0 to FClassSyms.count-1 do
           lTypedConstBuilder.emit_tai(TAIConst.Create_sym(TAsmSymbol(FClassSyms[lIndex])),TDef(FClassRTTIDefs[lIndex]));
        { then all categories }
        for lIndex:=0 to FCategorySyms.count-1 do
          lTypedConstBuilder.emit_tai(TAIConst.Create_sym(TAsmSymbol(FCategorySyms[lIndex])),TDef(FCategoryRTTIDefs[lIndex]));
        lSymbolsDef:=lTypedConstBuilder.end_anonymous_record;
        lSym := CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'_OBJC_SYMBOLS_$',AB_LOCAL,AT_DATA,lSymbolsDef);
        AList.ConcatList(lTypedConstBuilder.get_final_asmlist(lSym,
          lSymbolsDef,
          sec_objc_symbols,'_OBJC_SYMBOLS',
          sizeof(PInt)));
     end
    else
      begin
        lSym:=nil;
        lSymbolsDef:=nil;
      end;

    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_no_dead_strip]);
    lTypedConstBuilder.begin_anonymous_record('',
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
    { version number = 7 (always, both for gcc and clang) }
    lTypedConstBuilder.emit_ord_const(7,PtrUIntType);
    { sizeof(objc_module): 4 pointer-size entities }
    lTypedConstBuilder.emit_ord_const(sizeof(PInt)*4,PtrUIntType);
    { used to be file name, now unused (points to empty string) }
    ObjCreateStringPoolEntry('',sp_objcclassnames,sec_objc_class_names,lLabel,lDef);
    lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lLabel),lDef);
    { pointer to classes/categories list declared in this module }
    if Assigned(lSym) then
      lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lSym),lSymbolsDef)
    else
      lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    CurrentAsmData.getlabel(lLabel,alt_data);
    AList.ConcatList(lTypedConstBuilder.get_final_asmlist(lLabel,
      lTypedConstBuilder.end_anonymous_record,sec_objc_module_info,'_OBJC_MODULE_INFO',4));


    { Add lazy references to parent classes of all classes defined in this unit }
    lSuperClasses:=TFPObjectList.Create(false);
    for lIndex:=0 to FClassDefs.count-1 do
      begin
        lParent:=TObjectDef(FClassDefs[lIndex]).ChildOf;
        { warning: linear search, performance hazard if large number of subclasses }
        if Assigned(lParent) and
           (lSuperClasses.indexof(lParent)=-1) then
          begin
            AList.concat(TAIDirective.Create(asd_lazy_reference,'.objc_class_name_'+lParent.ObjExtName^));
            lSuperClasses.add(lParent);
          end;
      end;
    for lIndex:=0 to FCategoryDefs.count-1 do
      begin
        lParent:=TObjectDef(FCategoryDefs[lIndex]).ChildOf;
        { warning: linear search, performance hazard if large number of subclasses }
        if Assigned(lParent) and
           (lSuperClasses.indexof(lParent)=-1) then
          begin
            AList.concat(TAIDirective.Create(asd_lazy_reference,'.objc_class_name_'+lParent.ObjExtName^));
            lSuperClasses.add(lParent);
          end;
      end;
    lSuperClasses.free;
    lSuperClasses := nil;
    { reference symbols for all classes and categories defined in this unit }
    for lIndex:=0 to FClassDefs.count-1 do
      AList.concat(TAISymbol.Createname_global_value('.objc_class_name_'+TObjectDef(FClassDefs[lIndex]).ObjExtName^,AT_DATA,0,0,VoidPointerType));
    for lIndex:=0 to FCategoryDefs.count-1 do
      AList.concat(TAISymbol.Createname_global_value('.objc_category_name_'+
        TObjectDef(FCategoryDefs[lIndex]).ChildOf.ObjExtName^+'_'+
        TObjectDef(FCategoryDefs[lIndex]).ObjExtName^,AT_DATA,0,0,VoidPointerType));
  end;


constructor TObjCRTTIWriterFragile.Create;
  begin
    inherited Create(oa_fragile);
  end;


{******************************************************************
                 RTTI generation -- Non-Fragile ABI
*******************************************************************}

(*
From Clang:
/// EmitIvarList - Emit the ivar list for the given
/// implementation. The return value has type
/// IvarListnfABIPtrTy.
///  struct _ivar_t {
///   unsigned long int *offset;  // pointer to ivar offset location
///   char *name;
///   char *type;
///   uint32_t alignment;
///   uint32_t size;
/// }
/// struct _ivar_list_t {
///   uint32 entsize;  // sizeof(struct _ivar_t)
///   uint32 count;
///   struct _iver_t list[count];
/// }
///
*)
procedure TObjCRTTIWriterNonFragile.GenObjCIVars(AList: TAsmList; AObjCClass: TObjectDef; out AIVarsLabel: TAsmLabel);
  type
    TIVarData = record
      FieldSym      : TFieldVarSym;
      NameSym : TAsmLabel;
      NameDef : TDef;
      TypeSym : TAsmLabel;
      TypeDef : TDef;
      OffsetSym : TAsmSymbol;
    end;
  var
    lIVarType: TDef;
    lFieldSym    : TFieldVarSym;
    lIVars  : array of TIVarData;
    lIndex     : Integer;
    lIVarCount  : Integer;
    lEncodingType : AnsiString;
    lEncodingError  : TDef;
    lPrefix  : ShortString;
    lVisibility     : TAsmsymbind;
    lTypedConstBuilder     : TTAITypedConstBuilder;
    lPtrUIntPointerType : TDef;
  begin
    AIVarsLabel:=nil;
    lPrefix:='';

    lIVarCount:=0;
    lIVars:=nil;
    SetLength(lIVars,AObjCClass.SymTable.SymList.Count);

    lTypedConstBuilder:=nil;
    lPrefix:='';

    for lIndex:=0 to AObjCClass.SymTable.SymList.Count-1 do
      if TSym(AObjCClass.SymTable.SymList[lIndex]).typ=FieldVarSym then
        begin
          lFieldSym:=TFieldVarSym(AObjCClass.SymTable.SymList[lIndex]);
          if ObjCTryEncodeType(lFieldSym.vardef,lEncodingType,lEncodingError) then
            begin
              lIVars[lIVarCount].FieldSym:=lFieldSym;
              ObjCreateStringPoolEntry(lFieldSym.RealName,sp_objcvarnames,sec_objc_meth_var_names,lIVars[lIVarCount].NameSym,lIVars[lIVarCount].NameDef);
              ObjCreateStringPoolEntry(lEncodingType,sp_objcvartypes,sec_objc_meth_var_types,lIVars[lIVarCount].TypeSym,lIVars[lIVarCount].TypeDef);
              if (lIVarCount=0) then
                begin
                  lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section]);
                  lPrefix:=TargetInfo.cprefix+'OBJC_IVAR_$_'+AObjCClass.ObjExtName^+'.';
                end
              else
                lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section]);
              { This matches gcc/Clang, but is strange: I would expect private
                fields to be local symbols rather than private_extern (which
                is "package-global") (JM)
              }
              if not(lFieldSym.visibility in [vis_public,vis_protected,vis_strictprotected]) then
                lVisibility:=AB_PRIVATE_EXTERN
              else
                lVisibility:=AB_GLOBAL;
              lIVars[lIVarCount].OffsetSym:=CurrentAsmData.DefineAsmSymbol(lPrefix+lFieldSym.RealName,lVisibility,AT_DATA,PtrUIntType);
              lTypedConstBuilder.emit_tai(TAIConst.Create_int_dataptr(lFieldSym.FieldOffset),PtrUIntType);
              AList.ConcatList(
                lTypedConstBuilder.get_final_asmlist(
                  lIVars[lIVarCount].OffsetSym,PtrUIntType,
                  sec_objc_const,'_OBJC_IVAR_OFFSETS',sizeof(PInt)
                )
              );
              lTypedConstBuilder.free;
              lTypedConstBuilder := nil;
              inc(lIVarCount);
            end
          else
            { must be caught during parsing }
            InternalError(2009092301);
        end;
    if lIVarCount=0 then
      exit;

    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_is_lab,tcalo_new_section,tcalo_no_dead_strip]);

    CurrentAsmData.getlabel(AIVarsLabel,alt_data);

    lTypedConstBuilder.begin_anonymous_record(
      InternalTypePrefixName[itb_objc_nf_ivars]+ToStr(lIVarCount),
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

    { size of each entry -- always 32 bit value }
    lIVarType:=Search_Named_Unit_GlobalType('OBJC','OBJC_IVAR',true).TypeDef;
    lTypedConstBuilder.emit_ord_const(lIVarType.Size,U32IntType);
    { number of entries -- always 32 bit value }
    lTypedConstBuilder.emit_ord_const(lIVarCount,U32IntType);

    { we use voidpointertype for all elements so that we can reuse the
      recorddef for all ivar tables with the same number of elements }
    lPtrUIntPointerType:=CPointerDef.getreusable(PtrUIntType);
    for lIndex:=0 to lIVarCount-1 do
      begin
        { reference to the offset }
        lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lIVars[lIndex].OffsetSym),lPtrUIntPointerType);
        { reference to the instance variable name (}
        lTypedConstBuilder.queue_init(VoidPointerType);
        lTypedConstBuilder.queue_emit_asmsym(lIVars[lIndex].NameSym,lIVars[lIndex].NameDef);
        { reference to the encoded type }
        lTypedConstBuilder.queue_init(VoidPointerType);
        lTypedConstBuilder.queue_emit_asmsym(lIVars[lIndex].TypeSym,lIVars[lIndex].TypeDef);
        { alignment -- always 32 bit value }
        lTypedConstBuilder.emit_ord_const(lIVars[lIndex].FieldSym.vardef.Alignment,U32IntType);
        { size -- always 32 bit value }
        lTypedConstBuilder.emit_ord_const(lIVars[lIndex].FieldSym.vardef.Size,U32IntType);
      end;
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        AIVarsLabel,lTypedConstBuilder.end_anonymous_record,
        sec_objc_instance_vars,'_OBJC_INSTANCE_VARS',sizeof(PInt)
      )
    );
    lTypedConstBuilder.free;
    lTypedConstBuilder := nil;
  end;


(*
From Clang:
/// GetOrEmitProtocol - Generate the protocol meta-data:
/// @code
/// struct _protocol_t {
///   id isa;  // NULL
///   const char * const protocol_name;
///   const struct _protocol_list_t * protocol_list; // super protocols
///   const struct method_list_t * const instance_methods;
///   const struct method_list_t * const class_methods;
///   const struct method_list_t *optionalInstanceMethods;
///   const struct method_list_t *optionalClassMethods;
///   const struct _prop_list_t * properties;
///   const uint32_t size;  // sizeof(struct _protocol_t)
///   const uint32_t flags;  // = 0
/// }
/// @endcode
*)
procedure TObjCRTTIWriterNonFragile.GenObjCProtocol(AList: TAsmList; AProtocol: TObjectDef; out AProtocolLabel: TAsmSymbol);
  var
    lLabel,
    lListSym,
    lProtocolList     : TAsmSymbol;
    lNameDef       : TDef;
    lNameSym       : TAsmLabel;
    lRequiredInstanceSym,
    lRequiredClassSym,
    lOptionalInstanceSym,
    lOptionalClassSym,
    lExtMethodsSym : TAsmSymbol;
    lProtocolType      : TDef;
    lTypedConstBuilder           : TTAITypedConstBuilder;
    lSection           : TAsmSectiontype;
  begin
    GenObjCProtocolList(AList,AProtocol,true,lProtocolList);
    GenObjCProtocolElements(AList,AProtocol,lRequiredInstanceSym,lOptionalInstanceSym,lRequiredClassSym,lOptionalClassSym,lExtMethodsSym);

    { label for the protocol needs to be
        a) in a coalesced section (so multiple definitions of the same protocol
           can be merged by the linker)
        b) private_extern (should only be merged within the same module)
        c) weakly defined (so multiple definitions don't cause errors)
    }
    lProtocolType:=Search_Named_Unit_GlobalType('OBJC','OBJC_PROTOCOL',true).TypeDef;
    lLabel:=CurrentAsmData.DefineAsmSymbol(AProtocol.RTTIMangledName(objcclassrtti),AB_PRIVATE_EXTERN,AT_DATA,lProtocolType);
    AProtocolLabel:=lLabel;

    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_weak]);
    lTypedConstBuilder.maybe_begin_aggregate(lProtocolType);
    { protocol's isa - always nil }
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,ObjC_IDType);
    { name }
    ObjCreateStringPoolEntry(AProtocol.ObjExtName^,sp_objcclassnames,sec_objc_class_names,lNameSym,lNameDef);
    lTypedConstBuilder.queue_init(CharPointerType);
    lTypedConstBuilder.queue_emit_asmsym(lNameSym,lNameDef);
    { parent protocols list }
    ConcatSymOrNil(lTypedConstBuilder,lProtocolList,VoidPointerType);
    { required instance methods }
    ConcatSymOrNil(lTypedConstBuilder,lRequiredInstanceSym,VoidPointerType);
    { required class methods }
    ConcatSymOrNil(lTypedConstBuilder,lRequiredClassSym,VoidPointerType);
    { optional instance methods }
    ConcatSymOrNil(lTypedConstBuilder,lOptionalInstanceSym,VoidPointerType);
    { optional class methods }
    ConcatSymOrNil(lTypedConstBuilder,lOptionalClassSym,VoidPointerType);
    { TODO: properties }
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { size of this type }
    lTypedConstBuilder.emit_ord_const(lProtocolType.Size,U32IntType);
    { flags }
    lTypedConstBuilder.emit_ord_const(0,U32IntType);
    { extendedMethodTypes }
    ConcatSymOrNil(lTypedConstBuilder,lExtMethodsSym,VoidPointerType);
    { demangledName (unknown, always seems nil) }
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { classProperties -- todo }
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    lTypedConstBuilder.maybe_end_aggregate(lProtocolType);
    { coalesced sections are only required for ld-classic, because it does not
      support "weak" bits on all symbols. They are deprecated in ld64 starting
      from 2015: https://lists.llvm.org/pipermail/llvm-commits/Week-of-Mon-20151012/305992.html

      While targeting 10.6 or higher does not guarantee we are using ld64,
      we don't have a better heuristic available.
    }
    if not MacOSXVersionMin.IsValid or
       (MacOSXVersionMin.RelationTo(10,6,0)>=0) then
      lSection:=sec_data
    else
      lSection:=sec_data_coalesced;
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        lLabel,lProtocolType,
        lSection,'_OBJC_PROTOCOL',sizeof(PInt)
      )
    );
    lTypedConstBuilder.free;

    { also add an entry to the __DATA, __objc_protolist section, required to
      register the protocol with the runtime }
    lListSym:=CurrentAsmData.DefineAsmSymbol(AProtocol.RTTIMangledName(objcmetartti),AB_PRIVATE_EXTERN,AT_DATA,CPointerDef.getreusable(lProtocolType));
    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_weak,tcalo_no_dead_strip]);
    lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lLabel),CPointerDef.getreusable(lProtocolType));
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        lListSym,CPointerDef.getreusable(lProtocolType),
        sec_objc_protolist,'_OBJC_PROTOLIST',sizeof(PInt)
      )
    );
    lTypedConstBuilder.free;
    lTypedConstBuilder := nil;
  end;

(*
From Clang:
/// struct _category_t {
///   const char * const name;
///   struct _class_t *const cls;
///   const struct _method_list_t * const instance_methods;
///   const struct _method_list_t * const class_methods;
///   const struct _protocol_list_t * const protocols;
///   const struct _prop_list_t * const properties;
/// }
*)
procedure TObjCRTTIWriterNonFragile.GenObjCCategorySections(AList:TAsmList; AObjCCategory: TObjectDef; out ACategoryLabel: TAsmSymbol; out ACategoryLabelDef: TDef);
  var
    lCategoryStringSym     : TAsmLabel;
    lProtocolListSym,
    lInstanceMethodList,
    lClassMethodList,
    lClassSym,
    lCategorySym        : TAsmSymbol;
    lCategoryStringDef,
    lCategoryDef        : TDef;
    lTypedConstBuilder           : TTAITypedConstBuilder;
  begin
    { the category name }
    ObjCreateStringPoolEntry(AObjCCategory.ObjExtName^,sp_objcclassnames,sec_objc_class_names,lCategoryStringSym,lCategoryStringDef);

    { the class it extends }
    lClassSym:=CurrentAsmData.RefAsmSymbol(AObjCCategory.ChildOf.RTTIMangledName(objcclassrtti),AT_DATA);

    { generate the methods lists }
    GenObjCMethods(AList,AObjCCategory,lInstanceMethodList,false,true);
    GenObjCMethods(AList,AObjCCategory,lClassMethodList,true,true);

    { generate implemented protocols list }
    GenObjCProtocolList(AList,AObjCCategory,true,lProtocolListSym);

    { category declaration section }
    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section]);
    lTypedConstBuilder.begin_anonymous_record(InternalTypePrefixName[itb_objc_nf_category],
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
    lTypedConstBuilder.queue_init(VoidPointerType);
    lTypedConstBuilder.queue_emit_asmsym(lCategoryStringSym,lCategoryStringDef);
    lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lClassSym),VoidPointerType);
    ConcatSymOrNil(lTypedConstBuilder,lInstanceMethodList,VoidPointerType);
    ConcatSymOrNil(lTypedConstBuilder,lClassMethodList,VoidPointerType);
    ConcatSymOrNil(lTypedConstBuilder,lProtocolListSym,VoidPointerType);
    { properties, not yet supported }
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { size }
    lTypedConstBuilder.emit_tai(TAIConst.Create_32bit(64),S32IntType);
    { padding }
    lTypedConstBuilder.emit_tai(TAIConst.Create_32bit(0),S32IntType);
    lCategoryDef:=lTypedConstBuilder.end_anonymous_record;
    lCategorySym:=CurrentAsmData.DefineAsmSymbol(AObjCCategory.RTTIMangledName(objcclassrtti),AB_LOCAL,AT_DATA,lCategoryDef);
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        lCategorySym,lCategoryDef,
        sec_objc_const,'_OBJC_CATEGORY',sizeof(PInt)
      )
    );
    lTypedConstBuilder.free;
    lTypedConstBuilder := nil;

    ACategoryLabel:=lCategorySym;
    ACategoryLabelDef:=lCategoryDef;
  end;


(*
From Clang:
/// BuildIvarLayout - Builds ivar layout bitmap for the class
/// implementation for the __strong or __weak case.
/// The layout map displays which words in ivar list must be skipped
/// and which must be scanned by GC (see below). String is built of bytes.
/// Each byte is divided up in two nibbles (4-bit each). Left nibble is count
/// of words to skip and right nibble is count of words to scan. So, each
/// nibble represents up to 15 workds to skip or scan. Skipping the rest is
/// represented by a 0x00 byte which also ends the string.
/// 1. when ForStrongLayout is true, following ivars are scanned:
/// - id, Class
/// - object *  // note: this "object" means "Objective-C object" (JM)
/// - __strong anything
///
/// 2. When ForStrongLayout is false, following ivars are scanned:
/// - __weak anything
*)
(*

Only required when supporting garbage collection

procedure tobjcrttiwriter_nonfragile.gen_objc_ivargc_recursive(st: tabstractrecordsymtable; ptrbset: tbitset; startoffset: puint; il: tivarlayouttype);
var
  i: longint;
  fs: tfieldvarsym;
  includelen: longint;
begin
  for i:=0 to st.SymList.count-1 do
    if (tsym(st.symlist[i]).typ=fieldvarsym) then
      begin
        fs:=tfieldvarsym(st.symlist[i]);
        includelen:=0;
        case fs.vardef.typ of
          pointerdef,
          classrefdef:
            if (fs.vardef=objc_idtype) or
               (fs.vardef=objc_metaclasstype) then
              includelen:=1;
          recorddef:
            TODO: bitpacking -> offset differences
            gen_objc_ivargc_recursive(tabstractrecordsymtable(trecorddef(fs.vardef).symtable),ptrbset,startoffset+fs.fieldoffset,il);
          arraydef:
            begin
              if not is_special_
            end;
          objectdef :
            begin
              case tobjectdef(fs.vardef).objecttype of
                odt_objcclass,
                odt_objcprotocol:
                  includelen:=1;
                odt_object:
                  gen_objc_ivargc_recursive(tabstractrecordsymtable(tobjectdef(fs.vardef).symtable),ptrbset,startoffset+fs.fieldoffset,il);
              end;
            end;
        end;
      end;
end;


function tobjcrttiwriter_nonfragile.gen_objc_ivargcstring(objclss: tobjectdef; il: tivarlayouttype): ansistring;
  var
    ptrbset: tbitset;
    parent: tobjectdef;
    size,
    startoffset: puint;
    i: longint;
  begin
    size:=tObjectSymtable(objclss.symtable).datasize;
    if assigned(objclss.childof) then
      startoffset:=tObjectSymtable(objclss.childof.symtable).datasize
    else
      startoffset:=0;
    size:=size-startoffset;
    ptrbset:=tbitset.create_bytesize((size+sizeof(ptruint)-1) div sizeof(ptruint));
    { has to include info for this class' fields and those of all parent
      classes as well
    }
    parent:=obclss;
    repeat
      gen_objc_ivargc_recursive(parent.symtable,ptrbset,0,il);
      parent:=parent.childof;
    until not assigned(parent);
    { convert bits set to encoded string }
  end;
*)

(*
From Clang:
/// struct _class_ro_t {
///   uint32_t const flags;
///   uint32_t const instanceStart;
///   uint32_t const instanceSize;
///   uint32_t const reserved;  // only when building for 64bit targets
///   const uint8_t * const ivarLayout;
///   const char *const name;
///   const struct _method_list_t * const baseMethods;
///   const struct _protocol_list_t *const baseProtocols;
///   const struct _ivar_list_t *const ivars;
///   const uint8_t * const weakIvarLayout;
///   const struct _prop_list_t * const properties;
/// }
*)

procedure TObjCRTTIWriterNonFragile.GenObjCClassROPart(AList: TAsmList; AObjCClass: TObjectDef; AProtocolListSym: TAsmSymbol; out AClassROLabel: TAsmSymbol; AMetaClass: Boolean);
  const
    cClassFlag        = 0;
    cMetaFlag         = 1;
    cRootFlag         = 2;
    cObjC2HiddenFlag = $10;
    cExceptionFlag    = $20;
  var
    lMethodsSym,
    lROSym        : TAsmSymbol;
    lClassStringDef  : TDef;
    lClassStringSym,
    lIVarsLabel     : TAsmLabel;
    lRODef,
    lClassType   : TDef;
    lStart,
    lSize,
    lFlags        : Cardinal;
    lRTTIType     : TRTTIType;
    lFirstField   : TFieldVarSym;
    lIndex            : LongInt;
    lTypedConstBuilder          : TTAITypedConstBuilder;
  begin
    { consider every class declared in the implementation section of a unit
      as "hidden"
    }
    lFlags:=0;
    if (AObjCClass.owner.SymTableType=staticsymtable) and
       CurrentModule.IsUnit then
      lFlags:=cObjC2HiddenFlag;
    if AMetaClass then
      begin
        lFlags:=lFlags or cMetaFlag;
        lRTTIType:=objcmetarortti;
        { metaclass size/start: always size of objc_object }
        lClassType:=Search_Named_Unit_GlobalType('OBJC','OBJC_OBJECT',true).TypeDef;
        lStart:=lClassType.Size;
        lSize:=lStart;
      end
    else
      begin
        lFlags:=lFlags or cClassFlag;
        lRTTIType:=objcclassrortti;
        lSize:=TObjectSymTable(AObjCClass.SymTable).DataSize;
        { can't simply use childof's datasize, because alignment may cause the
          first field to skip a couple of bytes after the previous end }
        lFirstField:=nil;
        for lIndex:=0 to AObjCClass.SymTable.SymList.Count-1 do
          if (TSym(AObjCClass.SymTable.SymList[lIndex]).typ=FieldVarSym) then
            begin
              lFirstField:=TFieldVarSym(AObjCClass.SymTable.SymList[lIndex]);
              break;
            end;
        if Assigned(lFirstField) then
          lStart:=lFirstField.FieldOffset
        else
          { no extra fields -> start = size }
          lStart:=lSize;
      end;
    if not Assigned(AObjCClass.ChildOf) then
      lFlags:=lFlags or cRootFlag;

    ObjCreateStringPoolEntry(AObjCClass.ObjExtName^,sp_objcclassnames,sec_objc_class_names,lClassStringSym,lClassStringDef);
    { generate methods list }
    GenObjCMethods(AList,AObjCClass,lMethodsSym,AMetaClass,false);
    { generate ivars (nil for metaclass) }
    if AMetaClass then
      lIVarsLabel:=nil
    else
      GenObjCIVars(AList,AObjCClass,lIVarsLabel);

    { class declaration section }
    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section]);
    lTypedConstBuilder.begin_anonymous_record(
      InternalTypePrefixName[itb_objc_nf_class_ro_part],
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

    lTypedConstBuilder.emit_ord_const(lFlags,U32IntType);
    lTypedConstBuilder.emit_ord_const(lStart,U32IntType);
    lTypedConstBuilder.emit_ord_const(lSize,U32IntType);
    { strong ivar layout for garbage collection (deprecated) }
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    lTypedConstBuilder.queue_init(VoidPointerType);
    lTypedConstBuilder.queue_emit_asmsym(lClassStringSym,lClassStringDef);
    ConcatSymOrNil(lTypedConstBuilder,lMethodsSym,VoidPointerType);
    ConcatSymOrNil(lTypedConstBuilder,AProtocolListSym,VoidPointerType);
    ConcatSymOrNil(lTypedConstBuilder,lIVarsLabel,VoidPointerType);
    { weak ivar layout for garbage collection (deprecated) }
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { TODO: properties }
    lTypedConstBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    lRODef:=lTypedConstBuilder.end_anonymous_record;
    lROSym:=CurrentAsmData.DefineAsmSymbol(AObjCClass.RTTIMangledName(lRTTIType),AB_LOCAL,AT_DATA,lRODef);
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        lROSym,lRODef,
        sec_objc_const,'_OBJC_META_CLASS',sizeof(PInt)
      )
    );
    lTypedConstBuilder.free;
    lTypedConstBuilder := nil;
    AClassROLabel:=lROSym;
  end;


(*
From Clang:

/// struct _class_t {
///   struct _class_t *isa;
///   struct _class_t * const superclass;
///   void *cache;
///   IMP *vtable;
///   struct class_ro_t *ro;
/// }
///
*)

{ Generate rtti for an Objective-C class and its meta-class. }
procedure TObjCRTTIWriterNonFragile.GenObjCClassesSections(AList:TAsmList; AObjCClass: TObjectDef; out AClassLabel: TAsmSymbol; out AClassLabelDef: TDef);
  var
    lRoot          : TObjectDef;
    lSuperSym,
    lSuperMetaSym,
    lMetaISASym,
    lMetaSym,
    lClassSym,
    lMetaROSym,
    lROSym,
    lProtocolListSym  : TAsmSymbol;
    lVisibility           : TAsmsymbind;
    lISATypedConstBuilder,
    lMetaTypedConstBuilder       : TTAITypedConstBuilder;
    lMetaDef,
    lClassDef      : TDef;
  begin
    { A) Register necessary names }

    { 1) the current class and metaclass }
    if (AObjCClass.owner.SymTableType=GlobalSymTable) then
      lVisibility:=AB_GLOBAL
    else
      lVisibility:=AB_PRIVATE_EXTERN;

    { create the typed const builders so we can get the (provisional) types
      for the class and metaclass symbols }
    lISATypedConstBuilder:=CTAITypedConstBuilder.Create([]);
    lClassDef:=lISATypedConstBuilder.begin_anonymous_record(
      InternalTypePrefixName[itb_objc_nf_class],
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

    lMetaTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section]);
    lMetaDef:=lMetaTypedConstBuilder.begin_anonymous_record(
      InternalTypePrefixName[itb_objc_nf_meta_class],
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

    lClassSym:=CurrentAsmData.DefineAsmSymbol(AObjCClass.RTTIMangledName(objcclassrtti),lVisibility,AT_DATA,lClassDef);
    lMetaSym:=CurrentAsmData.DefineAsmSymbol(AObjCClass.RTTIMangledName(objcmetartti),lVisibility,AT_DATA,lMetaDef);
    { 2) the superclass and meta superclass }
    if Assigned(AObjCClass.ChildOf) then
      begin
        lSuperSym:=CurrentAsmData.RefAsmSymbol(AObjCClass.ChildOf.RTTIMangledName(objcclassrtti),AT_DATA);
        lSuperMetaSym:=CurrentAsmData.RefAsmSymbol(AObjCClass.ChildOf.RTTIMangledName(objcmetartti),AT_DATA);
      end
    else
      begin
        lSuperSym:=nil;
        { the class itself }
        lSuperMetaSym:=lClassSym;
      end;

    { 3) the isa }
    { From Clang: The isa for the meta-class is the root of the hierarchy. }
    lRoot:=AObjCClass;
    while Assigned(lRoot.ChildOf) do
      lRoot:=lRoot.ChildOf;
    lMetaISASym:=CurrentAsmData.RefAsmSymbol(lRoot.RTTIMangledName(objcmetartti),AT_DATA);

    { 4) the implemented protocols (same for metaclass and regular class) }
    GenObjCProtocolList(AList,AObjCClass,true,lProtocolListSym);

    { 5) the read-only parts of the class definitions }
    GenObjCClassROPart(AList,AObjCClass,lProtocolListSym,lMetaROSym,true);
    GenObjCClassROPart(AList,AObjCClass,lProtocolListSym,lROSym,false);

    { B) Class declaration section }
    { both class and metaclass are in the objc_data section for obj-c 2 }

    { 1) meta-class declaration }

    { the isa }
    lMetaTypedConstBuilder.emit_tai(TAIConst.Create_sym(lMetaISASym),VoidPointerType);
    { the superclass }
    lMetaTypedConstBuilder.emit_tai(TAIConst.Create_sym(lSuperMetaSym),VoidPointerType);
    { pointer to cache }
    if not Assigned(FObjCEmptyCacheVar) then
      FObjCEmptyCacheVar:=CurrentAsmData.RefAsmSymbol(TargetInfo.Cprefix+'_objc_empty_cache',AT_DATA);
    lMetaTypedConstBuilder.emit_tai(TAIConst.Create_sym(FObjCEmptyCacheVar),VoidPointerType);
    { pointer to vtable }
    if not Assigned(FObjCEmptyVtableVar) and
       not(TargetInfo.system in [system_aarch64_ios,system_aarch64_darwin,system_x86_64_iphonesim,system_aarch64_iphonesim]) then
      FObjCEmptyVtableVar:=CurrentAsmData.RefAsmSymbol(TargetInfo.Cprefix+'_objc_empty_vtable',AT_DATA);
    ConcatSymOrNil(lMetaTypedConstBuilder,FObjCEmptyVtableVar,VoidPointerType);
    { the read-only part }
    lMetaTypedConstBuilder.emit_tai(TAIConst.Create_sym(lMetaROSym),VoidPointerType);
    lMetaTypedConstBuilder.end_anonymous_record;
    AList.ConcatList(
      lMetaTypedConstBuilder.get_final_asmlist(
        lMetaSym,lMetaDef,
        sec_objc_data,'_OBJC_CLASS',sizeof(PInt)
      )
    );
    lMetaTypedConstBuilder.free;
    lMetaTypedConstBuilder := nil;

    { 2) regular class declaration }
    { the isa }
    lISATypedConstBuilder.emit_tai(TAIConst.Create_sym(lMetaSym),CPointerDef.getreusable(lMetaDef));
    { the superclass }
    ConcatSymOrNil(lISATypedConstBuilder,lSuperSym,VoidPointerType);
    { pointer to cache }
    lISATypedConstBuilder.emit_tai(TAIConst.Create_sym(FObjCEmptyCacheVar),VoidPointerType);
    { pointer to vtable }
    ConcatSymOrNil(lISATypedConstBuilder,FObjCEmptyVtableVar,VoidPointerType);
    { the read-only part }
    lISATypedConstBuilder.emit_tai(TAIConst.Create_sym(lROSym),VoidPointerType);
    lISATypedConstBuilder.end_anonymous_record;
    AList.ConcatList(
      lISATypedConstBuilder.get_final_asmlist(
        lClassSym,lClassDef,
        sec_objc_data,'_OBJC_CLASS',sizeof(PInt)
      )
    );
    lISATypedConstBuilder.free;
    lISATypedConstBuilder := nil;

    AClassLabel:=lClassSym;
    AClassLabelDef:=lClassDef;
  end;


procedure TObjCRTTIWriterNonFragile.AddClassList(AList: TAsmList; ASection: TAsmSectiontype; const ASymName: String; AClasses: TFPObjectList);
  var
    lIndex: LongInt;
    lSym: TAsmSymbol;
    lTypedConstBuilder: TTAITypedConstBuilder;
    lArrayDef: TDef;
  begin
    if AClasses.count=0 then
      exit;
    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_no_dead_strip]);
    lArrayDef:=CArrayDef.getreusable(VoidPointerType,AClasses.count);
    lSym:=CurrentAsmData.DefineAsmSymbol(ASymName,AB_LOCAL,AT_DATA,lArrayDef);
    lTypedConstBuilder.maybe_begin_aggregate(lArrayDef);
    for lIndex:=0 to AClasses.count-1 do
      lTypedConstBuilder.emit_tai(
        TAIConst.Create_sym(CurrentAsmData.RefAsmSymbol(TObjectDef(AClasses[lIndex]).RTTIMangledName(objcclassrtti),AT_DATA)),
        VoidPointerType
      );
    lTypedConstBuilder.maybe_end_aggregate(lArrayDef);
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        lSym,lArrayDef,
        ASection,ASymName,sizeof(PInt)
      )
    );
  end;

procedure TObjCRTTIWriterNonFragile.GenObjCProtocolExtMethodTypes(AList: TAsmList; AProtocol: TObjectDef; AItems: TFPObjectList; out AExtMethodSym: TAsmSymbol);
  var
    lIndex     : Integer;
    lMethod     : TProcDef;
    lLabel   : TAsmLabel;
    lDef,
    lLabelDef  : TDef;
    lTypedConstBuilder   : TTAITypedConstBuilder;
  begin
    if not Assigned(AItems) or
       (AItems.count=0) then
      begin
        AExtMethodSym:=nil;
        exit;
      end;

    lTypedConstBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section]);
    lTypedConstBuilder.begin_anonymous_record(
      InternalTypePrefixName[itp_objc_prot_ext_methods]+ToStr(AItems.count),
      CAlignment,1,
      targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
    for lIndex:=0 to AItems.Count-1 do
      begin
        lMethod:=TProcDef(AItems[lIndex]);
        ObjCreateStringPoolEntry(ObjCEncodeMethod(lMethod),sp_objcvartypes,sec_objc_meth_var_types,lLabel,lLabelDef);
        lTypedConstBuilder.emit_tai(TAIConst.Create_sym(lLabel),lLabelDef);
      end;
    lDef:=lTypedConstBuilder.end_anonymous_record;
    AExtMethodSym:=CurrentAsmData.DefineAsmSymbol(AProtocol.RTTIMangledName(objcprotocolmethodstypelist),AB_LOCAL,AT_DATA,lDef);
    AList.ConcatList(
      lTypedConstBuilder.get_final_asmlist(
        AExtMethodSym,lDef,sec_objc_const,'OBJC_PROTOCOL_METHOD_TYPES',sizeof(PInt))
    );
    lTypedConstBuilder.free;
    lTypedConstBuilder:=nil;
  end;

procedure TObjCRTTIWriterNonFragile.GenObjCProtocolElements(AList: TAsmList; AProtocol: TObjectDef; out ARequiredInstanceSym, AOptionalInstanceSym, ARequiredClassSym, AOptionalClassSym: TAsmSymbol; out AExtMethodSym: TAsmSymbol);
  var
    lRequiredInstanceMethods,
    lRequiredClassMethods,
    lOptionalInstanceMethods,
    lOptionalClassMethods,
    lAllMethods: TFPObjectList;
begin
    GetObjCProtocolMethods(AProtocol,lRequiredInstanceMethods,lOptionalInstanceMethods,lRequiredClassMethods,lOptionalClassMethods);
    GenObjCProtocolMethodsCommon(AList,AProtocol,lRequiredInstanceMethods,lOptionalInstanceMethods,lRequiredClassMethods,lOptionalClassMethods,ARequiredInstanceSym,AOptionalInstanceSym,ARequiredClassSym,AOptionalClassSym);
    // extended method list = list of all method signatures in order (and only signatures)
    lAllMethods:=TFPObjectList.Create(false);
    lAllMethods.ConcatListCopy(lRequiredInstanceMethods);
    lAllMethods.ConcatListCopy(lRequiredClassMethods);
    lAllMethods.ConcatListCopy(lOptionalInstanceMethods);
    lAllMethods.ConcatListCopy(lOptionalClassMethods);
    GenObjCProtocolExtMethodTypes(AList,AProtocol,lAllMethods,AExtMethodSym);

    lRequiredInstanceMethods.Free;
    lRequiredClassMethods.Free;
    lOptionalInstanceMethods.Free;
    lOptionalClassMethods.Free;
    lAllMethods.Free;
end;


procedure TObjCRTTIWriterNonFragile.GenObjCInfoSections(AList: TAsmList);

  function CollectNonLazyClasses(AClasses: TFPObjectList): TFPObjectList;
    var
      lSymEntry : TSym;
      lProcDef  : TProcDef;
      lIndex,lIndexJ      : LongInt;
    begin
      { non-lazy classes are all classes that define a class method with the
        selector called "load" (simply inheriting this class method is not enough,
        they have to implement it themselves)

        -- TODO: this currently only works if the Pascal identifier is also 'load'! }
      Result:=TFPObjectList.Create(false);
      for lIndex:=0 to AClasses.count-1 do
        begin
          lSymEntry:=TSym(TObjectSymTable(TObjectDef(AClasses[lIndex]).SymTable).find('LOAD'));
          if Assigned(lSymEntry) and
             (lSymEntry.typ=ProcSym) then
            begin
              for lIndexJ:=0 to TProcSym(lSymEntry).ProcdefList.count do
                begin
                  lProcDef:=TProcDef(TProcSym(lSymEntry).ProcdefList[0]);
                  if ((po_classmethod in lProcDef.ProcOptions) and
                      (lProcDef.MessageInf.str^='load')) then
                    begin
                      Result.add(AClasses[lIndex]);
                      break;
                    end;
                end;
            end;
        end;
    end;

  var
    lNonLazyClasses,
    lNonLazyCategories : TFPObjectList;
  begin
    if (FClassDefs.count=0) and
       (FCategoryDefs.count=0) then
      exit;

    lNonLazyClasses:=CollectNonLazyClasses(FClassDefs);
    lNonLazyCategories:=CollectNonLazyClasses(FCategoryDefs);

    { this list has to include all classes, also the non-lazy ones }
    AddClassList(AList,sec_objc_classlist,TargetAsm.labelprefix+'_OBJC_LABEL_CLASS_$',FClassDefs);
    AddClassList(AList,sec_objc_nlclasslist,TargetAsm.labelprefix+'_OBJC_LABEL_NONLAZY_CLASS_$',lNonLazyClasses);
    { category and non-lazy category lists }
    AddClassList(AList,sec_objc_catlist,TargetAsm.labelprefix+'_OBJC_LABEL_CATEGORY_$',FCategoryDefs);
    AddClassList(AList,sec_objc_nlcatlist,TargetAsm.labelprefix+'_OBJC_LABEL_NONLAZY_CATEGORY_$',lNonLazyCategories);

    lNonLazyClasses.free;
    lNonLazyClasses := nil;
    lNonLazyCategories.free;
    lNonLazyCategories := nil;
    { the non-fragile abi doesn't have any module info, nor lazy references
      to used classes or to parent classes }
  end;


constructor TObjCRTTIWriterNonFragile.Create;
  begin
    inherited Create(oa_nonfragile);
  end;


{******************************************************************
                 RTTI generation -- Main function
*******************************************************************}

procedure MaybeGenerateObjectiveCImageInfo(AGlobalST, ALocalST: TSymTable);
  var
    lObjCRTTIWriter: TObjCRTTIWriter;
  begin
    if (m_objectivec1 in CurrentSettings.ModeSwitches) then
      begin
        { generate rtti for all obj-c classes, protocols and categories
          defined in this module. }
        if not(TargetInfo.system in systems_objc_nfabi) then
          lObjCRTTIWriter:=TObjCRTTIWriterFragile.Create
        else
          lObjCRTTIWriter:=TObjCRTTIWriterNonFragile.Create;
        lObjCRTTIWriter.GenObjCRTTISections(CurrentAsmData.asmlists[al_objc_data],AGlobalST);
        lObjCRTTIWriter.GenObjCRTTISections(CurrentAsmData.asmlists[al_objc_data],ALocalST);
        lObjCRTTIWriter.GenObjCInfoSections(CurrentAsmData.asmlists[al_objc_data]);
        lObjCRTTIWriter.free;
        lObjCRTTIWriter := nil;
      end;
  end;


end.
