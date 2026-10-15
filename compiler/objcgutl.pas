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

  procedure objcfinishstringrefpoolentry(entry: PHashSetItem; stringpool: TConstPoolType; refsec, stringsec: TAsmSectiontype);
  procedure objcfinishclassrefnfpoolentry(entry: PHashSetItem; classdef: TObjectDef);

  procedure MaybeGenerateObjectiveCImageInfo(globalst, LocalST: TSymTable);


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
      fabi: TObjCABI;
      classdefs,
      catdefs: TFPObjectList;
      classrttidefs,
      catrttidefs: TFPObjectList;
      classsyms,
      catsyms: TFPObjectList;
      procedure gen_objc_protocol_methods_common(
        list: TAsmList;
        classdef: TObjectDef;
        reqinstmlist,optinstmlist,reqclsmlist,optclsmlist: TFPObjectList;
        out reqinstsym,optinstsym,reqclssym,optclssym: TAsmSymbol);
      procedure gen_objc_methods(list: TAsmList; objccls: TObjectDef; out methodslabel: TAsmSymbol; classmethods, iscategory: Boolean);
      procedure gen_objc_protocol_list(list:TAsmList; classdef: TObjectDef; zero_terminator: boolean; out protolistsym: TAsmSymbol);
      procedure gen_objc_cat_methods(list:TAsmList; classdef: TObjectDef; items: TFPObjectList; rttiype: TObjCRTTIType; section: TAsmSectiontype;const sectname: string; out listsym: TAsmSymbol);

      procedure gen_objc_protocol(list:TAsmList; protocol: TObjectDef; out protocollabel: TAsmSymbol);virtual;abstract;
      procedure gen_objc_category_sections(list:TAsmList; objccat: TObjectDef; out catlabel: TAsmSymbol; out catlabeldef: TDef);virtual;abstract;
      procedure gen_objc_classes_sections(list:TAsmList; objclss: TObjectDef; out classlabel: TAsmSymbol; out classlabeldef: TDef);virtual;abstract;
      procedure gen_objc_info_sections(list: TAsmList);virtual;abstract;
      procedure get_objc_protocol_methods(const protocol: TObjectDef; out reqinstmlist, optinstmlist, reqclsmlist, optclsmlist: TFPObjectList);
     public
      constructor create(_abi: TObjCABI);
      destructor Destroy;override;
      procedure gen_objc_rtti_sections(list:TAsmList; st:TSymTable);
      property abi: TObjCABI read fabi;
    end;


    { Used by by PowerPC/32 and i386 }
    TObjCRTTIWriterFragile = class(TObjCRTTIWriter)
     protected
      function gen_objc_protocol_ext(list: TAsmList; optinstsym, optclssym: TAsmSymbol): TAsmLabel;
      procedure gen_objc_protocol_elements(list: TAsmList; protocol: TObjectDef; out reqinstsym, optinstsym, reqclssym, optclssym: TAsmSymbol);
      procedure gen_objc_ivars(list: TAsmList; objccls: TObjectDef; out ivarslabel: TAsmLabel);
      procedure gen_objc_protocol(list:TAsmList; protocol: TObjectDef; out protocollabel: TAsmSymbol);override;
      procedure gen_objc_category_sections(list:TAsmList; objccat: TObjectDef; out catlabel: TAsmSymbol; out catlabeldef: TDef);override;
      procedure gen_objc_classes_sections(list:TAsmList; objclss: TObjectDef; out classlabel: TAsmSymbol; out classlabeldef: TDef);override;
      procedure gen_objc_info_sections(list: TAsmList);override;
     public
      constructor create;
    end;


    { Used by PowerPC/64, ARM, x86_64 and AArch64 }
    TObjCRTTIWriterNonFragile = class(TObjCRTTIWriter)
     protected
      ObjCEmptyCacheVar,
      ObjCEmptyVtableVar: TAsmSymbol;

      procedure gen_objc_class_ro_part(list: TAsmList; objclss: TObjectDef; protolistsym: TAsmSymbol; out classrolabel: TAsmSymbol; metaclass: boolean);
      procedure addclasslist(list: TAsmList; section: TAsmSectiontype; const symname: string; classes: TFPObjectList);
      procedure gen_objc_protocol_extmethodtypes(list: TAsmList; prot: TObjectDef; items: TFPObjectList; out extmethsym: TAsmSymbol);
      procedure gen_objc_protocol_elements(list: TAsmList; protocol: TObjectDef; out reqinstsym, optinstsym, reqclssym, optclssym: TAsmSymbol; out extmethsym: TAsmSymbol);

      procedure gen_objc_ivars(list: TAsmList; objccls: TObjectDef; out ivarslabel: TAsmLabel);
      procedure gen_objc_protocol(list:TAsmList; protocol: TObjectDef; out protocollabel: TAsmSymbol);override;
      procedure gen_objc_category_sections(list:TAsmList; objccat: TObjectDef; out catlabel: TAsmSymbol; out catlabeldef: TDef);override;
      procedure gen_objc_classes_sections(list:TAsmList; objclss: TObjectDef; out classlabel: TAsmSymbol; out classlabeldef: TDef);override;
      procedure gen_objc_info_sections(list: TAsmList);override;
     public
      constructor create;
    end;



{******************************************************************
                    Protocol declaration helpers
*******************************************************************}

function objcfindprotocolentry(const p: shortstring): TAsmSymbol;
  var
    item  : PHashSetItem;
  begin
    result:=nil;
    if not Assigned(CurrentAsmData.ConstPools[sp_objcprotocolrefs]) then
      exit;
    item:=CurrentAsmData.constpools[sp_objcprotocolrefs].Find(@p[1], length(p));
    if not Assigned(item) then
      exit;
    result:=TAsmSymbol(item^.Data);
  end;


function objcaddprotocolentry(const p: shortstring; ref: TAsmSymbol): Boolean;
  var
    item  : PHashSetItem;
  begin
    item:=CurrentAsmData.constpools[sp_objcprotocolrefs].FindOrAdd(@p[1], length(p));
    Result:=(item^.Data=nil);
    if Result then
      item^.Data:=ref;
  end;

{******************************************************************
                       Pool section helpers
*******************************************************************}

procedure objcreatestringpoolentryintern(p: pchar; len: LongInt; pooltype: TConstPoolType; stringsec: TAsmSectiontype; out sym: TAsmLabel; out def: TDef);
  var
    entry  : PHashSetItem;
    strlab : TAsmLabel;
    pool   : THashSet;
    tcb    : TTAITypedConstBuilder;
  begin
    pool := CurrentAsmData.constpools[pooltype];

    entry:=pool.FindOrAdd(p,len);
    if not Assigned(entry^.data) then
      begin
        { create new entry }
        CurrentAsmData.getlabel(strlab,alt_data);
        entry^.Data:=strlab;

        { Make sure strlab has a reference }
        strlab.increfs;

        { add the string to the appropriate section }
        tcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_new_section]);
        def:=tcb.emit_pchar_const(pchar(entry^.key),entry^.keylength);
        CurrentAsmData.asmlists[al_objc_pools].ConcatList(
          tcb.get_final_asmlist(strlab,def,stringsec,strlab.name,1)
        );
        tcb.free;
        tcb := nil;
        def:=CPointerDef.getreusable(def);
      end
    else
      def:=CPointerDef.getreusable(CArrayDef.getreusable(CAnsiCharType,len+1));
    sym:=TAsmLabel(Entry^.Data);
  end;


procedure objcfinishstringrefpoolentry(entry: PHashSetItem; stringpool: TConstPoolType; refsec, stringsec: TAsmSectiontype);
  var
    reflab,
    strlab : TAsmLabel;
    classname: string;
    tcb: TTAITypedConstBuilder;
    strdef: TDef;
  begin
    { have we already generated a reference for this string entry? }
    if not Assigned(entry^.Data) then
      begin
        { no, add the string to the associated strings section }
        objcreatestringpoolentryintern(pchar(entry^.key),entry^.keylength,stringpool,stringsec,strlab,strdef);

        { and now finish the reference }
        CurrentAsmData.getlabel(reflab,alt_data);
        entry^.Data:=reflab;

        { add a pointer to the string in the string references section }
        tcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_new_section,tcalo_no_dead_strip]);

        tcb.emit_tai(TAIConst.Create_sym(strlab),strdef);
        CurrentAsmData.asmlists[al_objc_pools].ConcatList(
          tcb.get_final_asmlist(reflab,strdef,refsec,reflab.name,sizeof(PInt))
          );
        tcb.free;
        tcb := nil;

        { in case of a class reference, also add a lazy symbol reference for
          the class (the linker requires this for the fragile ABI). }
        if (refsec=sec_objc_cls_refs) and
           not(TargetInfo.system in systems_objc_nfabi) then
          begin
            classname:='';
            SetLength(classname,entry^.keylength);
            move(entry^.key^,classname[1],entry^.keylength);
            { no way to express this in LLVM either, they also just emit
              module level assembly for it }
            CurrentAsmData.asmlists[al_pure_assembler].concat(TAIDirective.Create(asd_lazy_reference,'.objc_class_name_'+classname));
          end;
      end;
  end;


procedure objcreatestringpoolentry(const s: string; pooltype: TConstPoolType; stringsec: TAsmSectiontype; out sym: TAsmLabel; out def: TDef);
  begin
    objcreatestringpoolentryintern(@s[1],length(s),pooltype,stringsec,sym,def);
  end;


procedure objcfinishclassrefnfpoolentry(entry: PHashSetItem; classdef: TObjectDef);
  var
    reflab: TAsmLabel;
    classym: TAsmSymbol;
    tcb: TTAITypedConstBuilder;
  begin
    { have we already generated a reference for this class ref entry? }
    if not Assigned(entry^.Data) then
      begin
        { no, add the classref to the sec_objc_cls_refs section }
        CurrentAsmData.getlabel(reflab,alt_data);
        entry^.Data:=reflab;

        { add a pointer to the class }
        classym:=CurrentAsmData.RefAsmSymbol(classdef.RTTIMangledName(objcclassrtti),AT_DATA);

        tcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_new_section]);
        tcb.emit_tai(TAIConst.Create_sym(classym),VoidPointerType);
        CurrentAsmData.asmlists[al_objc_pools].ConcatList(
          tcb.get_final_asmlist(reflab,VoidPointerType,sec_objc_cls_refs,reflab.name,sizeof(PInt))
        );
        tcb.free;
        tcb := nil;
      end;
  end;

{******************************************************************
                    RTTI generation -- Helpers
*******************************************************************}

procedure ConcatSymOrNil(tcb: TTAITypedConstBuilder; sym: TAsmSymbol; def: TDef); inline;
begin
  if Assigned(sym) then
    tcb.emit_tai(TAIConst.Create_sym(sym),def)
  else
    tcb.emit_tai(TAIConst.Create_nil_dataptr,def);
end;


{******************************************************************
                 RTTI generation -- Common
*******************************************************************}

{ generate a method list, either of class methods or of instance methods,
  and both for obj-c classes and categories. }
procedure TObjCRTTIWriter.gen_objc_methods(list: TAsmList; objccls: TObjectDef; out methodslabel: TAsmSymbol; classmethods, iscategory: Boolean);
  const
                     {clas/cat inst/cls}
    SectType : array [Boolean, Boolean] of TAsmSectiontype =
      ((sec_objc_inst_meth, sec_objc_cls_meth),
       (sec_objc_cat_inst_meth, sec_objc_cat_cls_meth));
                     {clas/cat inst/cls}
    SectName : array [Boolean, Boolean] of string[20] =
      (('_OBJC_INST_METH','_OBJC_CLS_METH'),
       ('_OBJC_CAT_INST_METH','_OBJC_CAT_CLS_METH'));
                   {frag/non-frag ABI}
    SectFlags : array [Boolean] of TTCAsmListOptions =
     ([tcalo_new_section],[tcalo_new_section,tcalo_no_dead_strip]);
                        {inst/cls}
    instclsName : array [Boolean] of string = ('INSTANCE','CLASS');
  type
    TMethodData = record
      def     : TProcDef;
      selsym  : TAsmLabel;
      seldef  : TDef;
      encsym  : TAsmLabel;
      encdef  : TDef;
    end;
  var
    i     : Integer;
    def   : TProcDef;
    defs  : array of TMethodData;
    mcnt  : integer;
    mtype : TDef;
    tcb   : TTAITypedConstBuilder;
    mdef  : TDef;
  begin
    methodslabel:=nil;
    mcnt:=0;
    defs:=nil;
    { collect all instance/class methods }
    SetLength(defs,objccls.VMTEntries.count);
    for i:=0 to objccls.VMTEntries.count-1 do
      begin
        def:=PVMTEntry(objccls.VMTEntries[i])^.procdef;
        if (def.owner.DefOwner=objccls) and
           (classmethods = (po_classmethod in def.ProcOptions)) then
          begin
            defs[mcnt].def:=def;
            objcreatestringpoolentry(def.MessageInf.str^,sp_objcvarnames,sec_objc_meth_var_names,defs[mcnt].selsym,defs[mcnt].seldef);
            objcreatestringpoolentry(objcencodemethod(def),sp_objcvartypes,sec_objc_meth_var_types,defs[mcnt].encsym,defs[mcnt].encdef);
            inc(mcnt);
          end;
      end;
    if mcnt=0 then
      exit;

    tcb:=CTAITypedConstBuilder.create(SectFlags[TargetInfo.system in systems_objc_nfabi]);
    tcb.begin_anonymous_record(internaltypeprefixName[itp_objc_method_list]+ToStr(mcnt),
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

    if (abi=oa_fragile) then
      { not used, always zero }
      tcb.emit_ord_const(0,U32IntType)
    else
      begin
        { size of each entry -- always 32 bit value }
        mtype:=Search_Named_Unit_GlobalType('OBJC','OBJC_METHOD',true).typedef;
        tcb.emit_ord_const(mtype.size,U32IntType);
      end;
    { number of objc_method entries in the method_list array -- always 32 bit}
    tcb.emit_ord_const(mcnt,U32IntType);
    for i:=0 to mcnt-1 do
      begin
        { reference to the selector name }
        tcb.queue_init(CharPointerType);
        tcb.queue_emit_asmsym(defs[i].selsym,defs[i].seldef);
        { reference to the obj-c encoded function parameters (signature) }
        tcb.queue_init(CharPointerType);
        tcb.queue_emit_asmsym(defs[i].encsym,defs[i].encdef);
        { mangled name of the method }
        tcb.queue_init(VoidCodePointerType);
        tcb.queue_emit_proc(defs[i].def);
      end;

    mdef:=tcb.end_anonymous_record;
    if iscategory then
      begin
        methodslabel:=CurrentAsmData.DefineAsmSymbol('l_OBJC_$_CATEGORY_'+instclsName[classmethods]+'_METHODS_'+objccls.ObjExtName^+'_$_'+objccls.ChildOf.ObjExtName^,AB_LOCAL,AT_DATA,mdef);
      end
    else
      begin
        methodslabel:=CurrentAsmData.DefineAsmSymbol('l_OBJC_$_'+instclsName[classmethods]+'_METHODS_'+objccls.ObjExtName^,AB_LOCAL,AT_DATA,mdef);
      end;
    list.ConcatList(
      tcb.get_final_asmlist(methodslabel,mdef,
        SectType[iscategory,classmethods],
        SectName[iscategory,classmethods],sizeof(ptrint)
      )
    );
    tcb.free;
    tcb := nil;
  end;

procedure TObjCRTTIWriter.gen_objc_protocol_methods_common(
  list: TAsmList;
  classdef: TObjectDef;
  reqinstmlist,optinstmlist,reqclsmlist,optclsmlist: TFPObjectList;
  out reqinstsym,optinstsym,reqclssym,optclssym: TAsmSymbol);
begin
  if reqinstmlist.Count > 0 then
    gen_objc_cat_methods(list,classdef,reqinstmlist,objcinstancemethods,sec_objc_cat_inst_meth,'_OBJC_CAT_INST_METH',reqinstsym)
  else
    reqinstsym:=nil;
  if optinstmlist.Count > 0 then
    gen_objc_cat_methods(list,classdef,optinstmlist,objcprotinstancemethodsopt,sec_objc_cat_inst_meth,'_OBJC_CAT_INST_METH', optinstsym)
  else
    optinstsym:=nil;

  if reqclsmlist.Count>0 then
    gen_objc_cat_methods(list, classdef,reqclsmlist,objcclassmethods,sec_objc_cat_cls_meth,'_OBJC_CAT_CLS_METH', reqclssym)
  else
    reqclssym:=nil;
  if optclsmlist.Count>0 then
    gen_objc_cat_methods(list, classdef,optclsmlist,objcprotclassmethodsopt,sec_objc_cat_cls_meth,'_OBJC_CAT_CLS_METH', optclssym)
  else
    optclssym:=nil;
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
procedure TObjCRTTIWriter.gen_objc_protocol_list(list: TAsmList; classdef: TObjectDef; zero_terminator: boolean; out protolistsym: TAsmSymbol);
  var
    i         : Integer;
    protosym  : TAsmSymbol;
    protodef  : TObjectDef;
    protolist : TFPObjectList;
    tcb       : TTAITypedConstBuilder;
    def       : TDef;
  begin
    protolist:=classdef.ImplementedInterfaces;;
    if not Assigned(protolist) or
       (protolist.Count=0) then
      begin
        protolistsym:=nil;
        Exit;
      end;

    for i:=0 to protolist.Count-1 do
      begin
        protodef:=TImplementedInterface(protolist[i]).IntfDef;
        protosym:=objcfindprotocolentry(protodef.ObjExtName^);
        if not Assigned(protosym) then
          begin
            gen_objc_protocol(list,protodef,protosym);
            objcaddprotocolentry(protodef.ObjExtName^,protosym);
          end;
      end;

    tcb:=CTAITypedConstBuilder.create([tcalo_new_section]);
    tcb.begin_anonymous_record(internaltypeprefixName[itp_objc_proto_list]+ToStr(protolist.Count),
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

    if (abi=oa_fragile) then
      { From Clang: next, always nil}
      tcb.emit_tai(TAIConst.Create_nil_dataptr,PtrUIntType);
    { From Clang: protocols count}
    tcb.emit_tai(TAIConst.Create_int_dataptr(protolist.Count),PtrUIntType);
    for i:=0 to protolist.Count-1 do
      begin
        protodef:=(protolist[i] as TImplementedInterface).IntfDef;
        protosym:=objcfindprotocolentry(protodef.ObjExtName^);
        if not Assigned(protosym) then
          begin
            { For some reason protosym is not declared, though must be!
              Probably gen_obcj1_protocol returned wrong protosym
            }
            InternalError(2009091602);
          end;
        tcb.emit_tai(TAIConst.Create_sym(protosym),VoidPointerType);
      end;

    if zero_terminator then
      tcb.emit_tai(TAIConst.Create_nil_codeptr,VoidPointerType);

    def:=tcb.end_anonymous_record;
    protolistsym:=CurrentAsmData.DefineAsmSymbol(classdef.RTTIMangledName(objcprotocollist),AB_LOCAL,AT_DATA,def);
    list.ConcatList(
      tcb.get_final_asmlist(
        protolistsym,def,
        sec_objc_cat_cls_meth,'_OBJC_PROTOCOLLIST',sizeof(PInt)
      )
    );
    tcb.free;
    tcb := nil;
    { the symbol will point to a record }
  end;


{ Generate rtti for an Objective-C methods (methods without implementation) }
{ items : TFPObjectList of Tprocdef }
procedure TObjCRTTIWriter.gen_objc_cat_methods(list:TAsmList; classdef: TObjectDef; items: TFPObjectList; rttiype: TObjCRTTIType; section: TAsmSectiontype; const sectname: string; out listsym: TAsmSymbol);
var
  i       : integer;
  m       : TProcDef;
  lab     : TAsmLabel;
  ldef,
  mtype,
  listdef : TDef;
  tcb     : TTAITypedConstBuilder;
begin
  if not Assigned(items) or
     (items.count=0) then
    exit;

  tcb:=CTAITypedConstBuilder.create([tcalo_new_section]);
  tcb.begin_anonymous_record(
    internaltypeprefixName[itp_objc_cat_methods]+ToStr(items.count),
    C_alignment,1,
    targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
  if (abi=oa_nonfragile) then
    begin
      { size of each entry -- always 32 bit value }
      mtype:=Search_Named_Unit_GlobalType('OBJC','OBJC_METHOD',true).typedef;
      tcb.emit_ord_const(mtype.size,U32IntType);
    end;
  tcb.emit_ord_const(items.count,U32IntType);
  for i:=0 to items.Count-1 do
    begin
      m:=TProcDef(items[i]);
      objcreatestringpoolentry(m.MessageInf.str^,sp_objcvarnames,sec_objc_meth_var_names,lab,ldef);
      tcb.emit_tai(TAIConst.Create_sym(lab),ldef);
      objcreatestringpoolentry(objcencodemethod(m),sp_objcvartypes,sec_objc_meth_var_types,lab,ldef);
      tcb.emit_tai(TAIConst.Create_sym(lab),ldef);
      { placeholder for address of implementation? }
      if (abi=oa_nonfragile) then
        tcb.emit_tai(TAIConst.Create_nil_codeptr,CodePtrUIntType);
    end;
  listdef:=tcb.end_anonymous_record;
  listsym:=CurrentAsmData.DefineAsmSymbol(classdef.RTTIMangledName(rttiype),AB_LOCAL,AT_DATA,listdef);
  list.ConcatList(
    tcb.get_final_asmlist(
      listsym,listdef,section,sectname,sizeof(PInt))
  );
  tcb.free;
  tcb := nil;
end;

procedure TObjCRTTIWriter.get_objc_protocol_methods(const protocol: TObjectDef; out reqinstmlist, optinstmlist, reqclsmlist, optclsmlist: TFPObjectList);
var
  i: ptrint;
  proc: TProcDef;
begin
  reqinstmlist:=TFPObjectList.Create(false);
  reqclsmlist:=TFPObjectList.Create(false);
  optinstmlist:=TFPObjectList.Create(false);
  optclsmlist:=TFPObjectList.Create(false);
  for i:=0 to protocol.VMTEntries.Count-1 do
    begin
      proc:=PVMTEntry(protocol.VMTEntries[i])^.procdef;
      if (po_classmethod in proc.ProcOptions) then
        if not(po_optional in proc.ProcOptions) then
          reqclsmlist.Add(proc)
        else
          optclsmlist.Add(proc)
      else if not(po_optional in proc.ProcOptions) then
        reqinstmlist.Add(proc)
      else
        optinstmlist.Add(proc);
    end;
end;


{ Generate the rtti sections for all obj-c classes defined in st, and return
  these classes in the classes list. }
procedure TObjCRTTIWriter.gen_objc_rtti_sections(list:TAsmList; st:TSymTable);
  var
    i: LongInt;
    def,
    rttidef: TDef;
    sym: TAsmSymbol;
  begin
    if not Assigned(st) then
      exit;

    for i:=0 to st.DefList.Count-1 do
      begin
        def:=TDef(st.DefList[i]);
        { check whether all types used in Objective-C class/protocol/category
          declarations can be used with the Objective-C run time (can only be
          done now, because at parse-time some of these types can still be
          forwarddefs) }
        if Is_ObjC_Class_Or_Protocol(def) then
          if not TObjectDef(def).Check_ObjC_Types then
            continue;
        if Is_ObjCClass(def) and
           not(oo_is_external in TObjectDef(def).ObjectOptions) then
          begin
            if not(oo_is_classhelper in TObjectDef(def).ObjectOptions) then
              begin
                gen_objc_classes_sections(list,TObjectDef(def),sym,rttidef);
                classsyms.add(sym);
                classrttidefs.add(rttidef);
                classdefs.add(def);
              end
            else
              begin
                gen_objc_category_sections(list,TObjectDef(def),sym,rttidef);
                catsyms.add(sym);
                catrttidefs.add(rttidef);
                catdefs.add(def);
              end
          end;
      end;
  end;


constructor TObjCRTTIWriter.create(_abi: TObjCABI);
  begin
    fabi:=_abi;
    classdefs:=TFPObjectList.create(false);
    classsyms:=TFPObjectList.create(false);
    classrttidefs:=TFPObjectList.create(false);
    catrttidefs:=TFPObjectList.create(false);
    catdefs:=TFPObjectList.create(false);
    catsyms:=TFPObjectList.create(false);
  end;


destructor TObjCRTTIWriter.Destroy;
  begin
    classdefs.free;
    classdefs := nil;
    classsyms.free;
    classsyms := nil;
    classrttidefs.free;
    classrttidefs := nil;
    catrttidefs.free;
    catrttidefs := nil;
    catdefs.free;
    catdefs := nil;
    catsyms.free;
    catsyms := nil;
    inherited Destroy;
  end;

{******************************************************************
                 RTTI generation -- Fragile ABI
*******************************************************************}

{ generate an instance variables list for an obj-c class. }
procedure TObjCRTTIWriterFragile.gen_objc_ivars(list: TAsmList; objccls: TObjectDef; out ivarslabel: TAsmLabel);
  type
    TIVarData = record
      vf      : TFieldVarSym;
      namesym : TAsmLabel;
      namedef : TDef;
      TypeSym : TAsmLabel;
      typedef : TDef;
    end;
  var
    i     : integer;
    vf    : TFieldVarSym;
    vars  : array of TIVarData;
    vcnt  : Integer;
    enctype : AnsiString;
    encerr  : TDef;
  begin
    ivarslabel:=nil;

    vcnt:=0;
    vars:=nil;
    SetLength(vars,objccls.SymTable.SymList.Count);

    for i:=0 to objccls.SymTable.SymList.Count-1 do
      if TSym(objccls.SymTable.SymList[i]).typ=FieldVarSym then
        begin
          vf:=TFieldVarSym(objccls.SymTable.SymList[i]);
          if objctryencodetype(vf.vardef,enctype,encerr) then
            begin
              vars[vcnt].vf:=vf;
              objcreatestringpoolentry(vf.RealName,sp_objcvarnames,sec_objc_meth_var_names,vars[vcnt].namesym,vars[vcnt].namedef);
              objcreatestringpoolentry(enctype,sp_objcvartypes,sec_objc_meth_var_types,vars[vcnt].TypeSym,vars[vcnt].typedef);
              inc(vcnt);
            end
          else
            { Should be caught during parsing }
            InternalError(2009090601);
        end;
    if vcnt=0 then
      exit;

    new_section(list,sec_objc_instance_vars,'_OBJC_INSTANCE_VARS',sizeof(PInt));

    CurrentAsmData.getlabel(ivarslabel,alt_data);
    list.Concat(TAILabel.Create(ivarslabel));

    { objc_ivar_list: first the number of elements }
    list.Concat(TAIConst.Create_32bit(vcnt));

    for i:=0 to vcnt-1 do
      begin
        { reference to the instance variable name }
        list.Concat(TAIConst.Create_sym(vars[i].namesym));
        { reference to the encoded type }
        list.Concat(TAIConst.Create_sym(vars[i].TypeSym));
        { and the offset of the field }
        list.Concat(TAIConst.Create_32bit(vars[i].vf.FieldOffset));
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
function TObjCRTTIWriterFragile.gen_objc_protocol_ext(list: TAsmList; optinstsym, optclssym: TAsmSymbol): TAsmLabel;
  var
    tcb: TTAITypedConstBuilder;
  begin
    if Assigned(optinstsym) or
       Assigned(optclssym) then
      begin
        CurrentAsmData.getlabel(Result,alt_data);
        tcb:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_no_dead_strip]);
        tcb.begin_anonymous_record(
          internaltypeprefixName[itb_objc_fr_protocol_ext],
          C_alignment,1,
          targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
        { size of this structure }
        tcb.emit_ord_const(16,U32IntType);
        { optional instance methods }
        ConcatSymOrNil(tcb,optinstsym,VoidPointerType);
        { optional class methods }
        ConcatSymOrNil(tcb,optclssym,VoidPointerType);
        { optional properties (todo) }
        ConcatSymOrNil(tcb,nil,VoidPointerType);
        list.ConcatList(
          tcb.get_final_asmlist(
            result,tcb.end_anonymous_record,
            sec_objc_protocol_ext,'_OBJC_PROTOCOLEXT',sizeof(PInt)
          )
        );
        tcb.free;
        tcb := nil;
      end
    else
      Result:=nil;
  end;

{ generate method (and in the future also property) info for protocols }
procedure TObjCRTTIWriterFragile.gen_objc_protocol_elements(list: TAsmList; protocol: TObjectDef; out reqinstsym, optinstsym, reqclssym, optclssym: TAsmSymbol);
  var
    reqinstmlist,
    reqclsmlist,
    optinstmlist,
    optclsmlist   : TFPObjectList;
begin
    get_objc_protocol_methods(protocol,reqinstmlist,optinstmlist,reqclsmlist,optclsmlist);
    gen_objc_protocol_methods_common(list,protocol,reqinstmlist,optinstmlist,reqclsmlist,optclsmlist,reqinstsym,optinstsym,reqclssym,optclssym);
    reqinstmlist.Free;
    reqclsmlist.Free;
    optinstmlist.Free;
    optclsmlist.Free;
end;

{ Generate rtti for an Objective-C protocol  }
procedure TObjCRTTIWriterFragile.gen_objc_protocol(list:TAsmList; protocol: TObjectDef; out protocollabel: TAsmSymbol);
  var
    namesym     : TAsmLabel;
    namedef     : TDef;
    protolist,
    reqinstsym,
    optinstsym,
    reqclssym,
    optclssym   : TAsmSymbol;
    protoext,
    lbl          : TAsmLabel;
    tcb          : TTAITypedConstBuilder;
  begin
    gen_objc_protocol_list(list,protocol,false,protolist);
    gen_objc_protocol_elements(list,protocol,reqinstsym,optinstsym,reqclssym,optclssym);
    protoext:=gen_objc_protocol_ext(list,optinstsym,optclssym);

    CurrentAsmData.getlabel(lbl,alt_data);
    protocollabel:=lbl;

    tcb:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_no_dead_strip]);
    tcb.begin_anonymous_record(
      internaltypeprefixName[itb_objc_fr_protocol],
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

    { protocol's isa - points to information about optional methods/properties }
    ConcatSymOrNil(tcb,protoext,VoidPointerType);
    { name }
    objcreatestringpoolentry(protocol.ObjExtName^,sp_objcclassnames,sec_objc_class_names,namesym,namedef);
    tcb.queue_init(VoidPointerType);
    tcb.queue_emit_asmsym(namesym,namedef);
    { protocol's list }
    ConcatSymOrNil(tcb,protolist,VoidPointerType);
    { instance methods, in __cat_inst_meth }
    ConcatSymOrNil(tcb,reqinstsym,VoidPointerType);
    { class methods, in __cat_cls_meth }
    ConcatSymOrNil(tcb,reqclssym,VoidPointerType);
    list.ConcatList(
      tcb.get_final_asmlist(
        lbl,tcb.end_anonymous_record,
        sec_objc_protocol,'_OBJC_PROTOCOL',sizeof(PInt)
      )
    );
    tcb.free;
    tcb := nil;
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
procedure TObjCRTTIWriterFragile.gen_objc_category_sections(list:TAsmList; objccat: TObjectDef; out catlabel: TAsmSymbol; out catlabeldef: TDef);
  var
    catstrsym,
    clsstrsym     : TAsmLabel;
    protolistsym,
    instmthdlist,
    clsmthdlist,
    catsym        : TAsmSymbol;
    catstrdef,
    clsstrdef,
    catdef        : TDef;
    tcb           : TTAITypedConstBuilder;
  begin
    { the category name }
    objcreatestringpoolentry(objccat.ObjExtName^,sp_objcclassnames,sec_objc_class_names,catstrsym,catstrdef);

    { the name of the class it extends }
    objcreatestringpoolentry(objccat.ChildOf.ObjExtName^,sp_objcclassnames,sec_objc_class_names,clsstrsym,clsstrdef);

    { generate the methods lists }
    gen_objc_methods(list,objccat,instmthdlist,false,true);
    gen_objc_methods(list,objccat,clsmthdlist,true,true);

    { generate implemented protocols list }
    gen_objc_protocol_list(list,objccat,false,protolistsym);

    { category declaration section }
    tcb:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_no_dead_strip]);
    tcb.begin_anonymous_record(
      internaltypeprefixName[itb_objc_fr_category],
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

    tcb.queue_init(VoidPointerType);
    tcb.queue_emit_asmsym(catstrsym,catstrdef);
    tcb.queue_init(VoidPointerType);
    tcb.queue_emit_asmsym(clsstrsym,clsstrdef);
    ConcatSymOrNil(tcb,instmthdlist,VoidPointerType);
    ConcatSymOrNil(tcb,clsmthdlist,VoidPointerType);
    ConcatSymOrNil(tcb,protolistsym,VoidPointerType);
    { size of this structure }
    tcb.emit_ord_const(28,U32IntType);
    { properties, not yet supported }
    tcb.emit_ord_const(0,U32IntType);
    catdef:=tcb.end_anonymous_record;
    catsym:=CurrentAsmData.DefineAsmSymbol(objccat.RTTIMangledName(objcclassrtti),AB_LOCAL,AT_DATA,catdef);
    list.ConcatList(
      tcb.get_final_asmlist(
        catsym,catdef,
        sec_objc_category,'_OBJC_CATEGORY',sizeof(PInt)
      )
    );
    tcb.free;
    tcb := nil;

    catlabel:=catsym;
    catlabeldef:=catdef;
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
procedure TObjCRTTIWriterFragile.gen_objc_classes_sections(list:TAsmList; objclss: TObjectDef; out classlabel: TAsmSymbol; out classlabeldef: TDef);
  const
    CLS_CLASS  = 1;
    CLS_META   = 2;
    CLS_HIDDEN = $20000;
    META_INST_SIZE = 40+8; // sizeof(objc_class) + 8
  var
    root          : TObjectDef;
    metasym,
    mthdlist,
    clssym,
    protolistsym  : TAsmSymbol;
    superStrDef,
    classStrDef,
    metaisaStrDef,
    metaDef,
    clsDef        : TDef;
    superStrSym,
    classStrSym,
    metaisaStrSym,
    ivarslist     : TAsmLabel;
    hiddenflag    : cardinal;
    tcb           : TTAITypedConstBuilder;

  begin
    { generate the class methods list }
    gen_objc_methods(list,objclss,mthdlist,true,false);

    { generate implemented protocols list }
    gen_objc_protocol_list(list,objclss,false,protolistsym);

    { register necessary names }
    { 1) the superclass }
    if Assigned(objclss.ChildOf) then
      objcreatestringpoolentry(objclss.ChildOf.ObjExtName^,sp_objcclassnames,sec_objc_class_names,superStrSym,superStrDef)
    else
      begin
        { not empty string, but nil! }
        superStrSym:=nil;
        superStrDef:=VoidPointerType;
      end;

    { 2) the current class }
    objcreatestringpoolentry(objclss.ObjExtName^,sp_objcclassnames,sec_objc_class_names,classStrSym,classStrDef);
    { 3) the isa }
    { From Clang: The isa for the meta-class is the root of the hierarchy. }
    root:=objclss;
    while Assigned(root.ChildOf) do
      root:=root.ChildOf;
    objcreatestringpoolentry(root.ObjExtName^,sp_objcclassnames,sec_objc_class_names,metaisaStrSym,metaisaStrDef);

    { 4) the flags }
    { consider every class declared in the implementation section of a unit
      as "hidden"
    }
    hiddenflag:=0;
    if (objclss.owner.SymTableType=staticsymtable) and
       CurrentModule.IsUnit then
      hiddenflag:=CLS_HIDDEN;

    { class declaration section }

    { 1) meta-class declaration  }
    tcb:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_no_dead_strip]);
    tcb.begin_anonymous_record(internaltypeprefixName[itb_objc_fr_meta_class],
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

    tcb.queue_init(VoidPointerType);
    tcb.queue_emit_asmsym(metaisaStrSym,metaisaStrDef);
    { pointer to the superclass name if any, otherwise nil }
    if Assigned(superstrsym) then
      begin
        tcb.queue_init(VoidPointerType);
        tcb.queue_emit_asmsym(superStrSym,superStrDef);
      end
    else
      tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { pointer to the class name }
    tcb.queue_init(VoidPointerType);
    tcb.queue_emit_asmsym(classStrSym,classStrDef);

    { version is always 0 currently }
    tcb.emit_ord_const(0,U32IntType);
    { CLS_META for meta-classes }
    tcb.emit_ord_const(hiddenflag or CLS_META,U32IntType);
    { size of the meta-class instance: sizeof(objc_class) + 8 bytes }
    tcb.emit_ord_const(META_INST_SIZE,U32IntType);
    { meta-classes don't have ivars list (=0) }
    tcb.emit_ord_const(0,U32IntType);
    { class methods list (stored in "__cls_meth" section) }
    ConcatSymOrNil(tcb,mthdlist,VoidPointerType);
    { From Clang: cache is always nil }
    tcb.emit_ord_const(0,U32IntType);
    { protocols }
    ConcatSymOrNil(tcb,protolistsym,VoidPointerType);
    { From Clang: ivar_layout for meta-class is always NULL. }
    tcb.emit_ord_const(0,U32IntType);
    { From Clang: The class extension is always unused for meta-classes. }
    tcb.emit_ord_const(0,U32IntType);
    metaDef:=tcb.end_anonymous_record;
    metasym:=CurrentAsmData.DefineAsmSymbol(objclss.RTTIMangledName(objcmetartti),AB_LOCAL,AT_DATA,metadef);
    list.ConcatList(
      tcb.get_final_asmlist(
        metasym,metaDef,
        sec_objc_meta_class,'_OBJC_META_CLASS',sizeof(PInt)
      )
    );
    tcb.free;


    { 2) regular class declaration }

    { generate the instance methods list }
    gen_objc_methods(list,objclss,mthdlist,false,false);
    { generate the instance variables list }
    gen_objc_ivars(list,objclss,ivarslist);

    tcb:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_no_dead_strip]);
    tcb.begin_anonymous_record(internaltypeprefixName[itb_objc_fr_class],
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

    { for class declaration: the isa points to the meta-class declaration }
    tcb.emit_tai(TAIConst.Create_sym(metasym),CPointerDef.getreusable(metaDef));
    { pointer to the super_class name if any, nil otherwise }
    if Assigned(superStrSym) then
      begin
        tcb.queue_init(VoidCodePointerType);
        tcb.queue_emit_asmsym(superStrSym,superStrDef)
      end
    else
      tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidCodePointerType);
    { pointer to the class name }
    tcb.queue_init(VoidCodePointerType);
    tcb.queue_emit_asmsym(classStrSym,classStrDef);
    { version is always 0 currently }
    tcb.emit_ord_const(0,U32IntType);
    { CLS_CLASS for classes }
    tcb.emit_ord_const(hiddenflag or CLS_CLASS,U32IntType);
    { size of instance: total size of instance variables }
    tcb.emit_ord_const(TObjectSymTable(objclss.SymTable).DataSize,U32IntType);
    { objc_ivar_list (stored in "__instance_vars" section) }
    ConcatSymOrNil(tcb,ivarslist,VoidPointerType);
    { instance methods list (stored in "__inst_meth" section) }
    ConcatSymOrNil(tcb,mthdlist,VoidPointerType);
    { From Clang: cache is always NULL }
    tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { protocols, protolistsym has been created for meta-class, no need to create another one}
    ConcatSymOrNil(tcb, protolistsym,VoidPointerType);
    { From Clang: strong ivar_layout, necessary for garbage collection support }
    tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { TODO: From Clang: weak ivar_layout, necessary for garbage collection support }
    tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);

    clsDef:=tcb.end_anonymous_record;
    clssym:=CurrentAsmData.DefineAsmSymbol(objclss.RTTIMangledName(objcclassrtti),AB_LOCAL,AT_DATA,clsDef);
    list.ConcatList(
      tcb.get_final_asmlist(
        clssym,clsDef,
        sec_objc_class,'_OBJC_CLASS',sizeof(PInt)
      )
    );
    tcb.free;
    tcb := nil;

    classlabel:=clssym;
    classlabeldef:=clsDef;
  end;


{ Generate the global information sections (objc_symbols and objc_module_info)
  for this module. }
procedure TObjCRTTIWriterFragile.gen_objc_info_sections(list: TAsmList);
  var
    i: LongInt;
    sym : TAsmSymbol;
    lab : TAsmLabel;
    symsdef,
    def : TDef;
    parent: TObjectDef;
    superclasses: TFPObjectList;
    tcb: TTAITypedConstBuilder;
  begin
    if (classsyms.count<>0) or
       (catsyms.count<>0) then
      begin
        tcb:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_no_dead_strip]);
        tcb.begin_anonymous_record('',
          C_alignment,1,
          targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
        { ??? (always 0 in Clang) }
        tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
        { ??? (From Clang: always 0, pointer to some selector) }
        tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
        { From Clang: number of defined classes }
        tcb.emit_ord_const(classsyms.count,U16IntType);
        { From Clang: number of defined categories }
        tcb.emit_ord_const(catsyms.count,U16IntType);
        { first all classes }
        for i:=0 to classsyms.count-1 do
           tcb.emit_tai(TAIConst.Create_sym(TAsmSymbol(classsyms[i])),TDef(classrttidefs[i]));
        { then all categories }
        for i:=0 to catsyms.count-1 do
          tcb.emit_tai(TAIConst.Create_sym(TAsmSymbol(catsyms[i])),TDef(catrttidefs[i]));
        symsdef:=tcb.end_anonymous_record;
        sym := CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'_OBJC_SYMBOLS_$',AB_LOCAL,AT_DATA,symsdef);
        list.ConcatList(tcb.get_final_asmlist(sym,
          symsdef,
          sec_objc_symbols,'_OBJC_SYMBOLS',
          sizeof(PInt)));
     end
    else
      begin
        sym:=nil;
        symsdef:=nil;
      end;

    tcb:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_no_dead_strip]);
    tcb.begin_anonymous_record('',
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
    { version number = 7 (always, both for gcc and clang) }
    tcb.emit_ord_const(7,PtrUIntType);
    { sizeof(objc_module): 4 pointer-size entities }
    tcb.emit_ord_const(sizeof(PInt)*4,PtrUIntType);
    { used to be file name, now unused (points to empty string) }
    objcreatestringpoolentry('',sp_objcclassnames,sec_objc_class_names,lab,def);
    tcb.emit_tai(TAIConst.Create_sym(lab),def);
    { pointer to classes/categories list declared in this module }
    if Assigned(sym) then
      tcb.emit_tai(TAIConst.Create_sym(sym),symsdef)
    else
      tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    CurrentAsmData.getlabel(lab,alt_data);
    list.ConcatList(tcb.get_final_asmlist(lab,
      tcb.end_anonymous_record,sec_objc_module_info,'_OBJC_MODULE_INFO',4));


    { Add lazy references to parent classes of all classes defined in this unit }
    superclasses:=TFPObjectList.create(false);
    for i:=0 to classdefs.count-1 do
      begin
        parent:=TObjectDef(classdefs[i]).ChildOf;
        { warning: linear search, performance hazard if large number of subclasses }
        if Assigned(parent) and
           (superclasses.indexof(parent)=-1) then
          begin
            list.concat(TAIDirective.create(asd_lazy_reference,'.objc_class_name_'+parent.ObjExtName^));
            superclasses.add(parent);
          end;
      end;
    for i:=0 to catdefs.count-1 do
      begin
        parent:=TObjectDef(catdefs[i]).ChildOf;
        { warning: linear search, performance hazard if large number of subclasses }
        if Assigned(parent) and
           (superclasses.indexof(parent)=-1) then
          begin
            list.concat(TAIDirective.create(asd_lazy_reference,'.objc_class_name_'+parent.ObjExtName^));
            superclasses.add(parent);
          end;
      end;
    superclasses.free;
    superclasses := nil;
    { reference symbols for all classes and categories defined in this unit }
    for i:=0 to classdefs.count-1 do
      list.concat(TAISymbol.Createname_global_value('.objc_class_name_'+TObjectDef(classdefs[i]).ObjExtName^,AT_DATA,0,0,VoidPointerType));
    for i:=0 to catdefs.count-1 do
      list.concat(TAISymbol.Createname_global_value('.objc_category_name_'+
        TObjectDef(catdefs[i]).ChildOf.ObjExtName^+'_'+
        TObjectDef(catdefs[i]).ObjExtName^,AT_DATA,0,0,VoidPointerType));
  end;


constructor TObjCRTTIWriterFragile.create;
  begin
    inherited create(oa_fragile);
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
procedure TObjCRTTIWriterNonFragile.gen_objc_ivars(list: TAsmList; objccls: TObjectDef; out ivarslabel: TAsmLabel);
  type
    TIVarData = record
      vf      : TFieldVarSym;
      namesym : TAsmLabel;
      namedef : TDef;
      TypeSym : TAsmLabel;
      typedef : TDef;
      offssym : TAsmSymbol;
    end;
  var
    ivtype: TDef;
    vf    : TFieldVarSym;
    vars  : array of TIVarData;
    i     : integer;
    vcnt  : integer;
    enctype : AnsiString;
    encerr  : TDef;
    prefix  : shortstring;
    vis     : TAsmsymbind;
    tcb     : TTAITypedConstBuilder;
    pptruinttype : TDef;
  begin
    ivarslabel:=nil;
    prefix:='';

    vcnt:=0;
    vars:=nil;
    SetLength(vars,objccls.SymTable.SymList.Count);

    tcb:=nil;
    prefix:='';

    for i:=0 to objccls.SymTable.SymList.Count-1 do
      if TSym(objccls.SymTable.SymList[i]).typ=FieldVarSym then
        begin
          vf:=TFieldVarSym(objccls.SymTable.SymList[i]);
          if objctryencodetype(vf.vardef,enctype,encerr) then
            begin
              vars[vcnt].vf:=vf;
              objcreatestringpoolentry(vf.RealName,sp_objcvarnames,sec_objc_meth_var_names,vars[vcnt].namesym,vars[vcnt].namedef);
              objcreatestringpoolentry(enctype,sp_objcvartypes,sec_objc_meth_var_types,vars[vcnt].TypeSym,vars[vcnt].typedef);
              if (vcnt=0) then
                begin
                  tcb:=CTAITypedConstBuilder.create([tcalo_new_section]);
                  prefix:=TargetInfo.cprefix+'OBJC_IVAR_$_'+objccls.ObjExtName^+'.';
                end
              else
                tcb:=CTAITypedConstBuilder.create([tcalo_new_section]);
              { This matches gcc/Clang, but is strange: I would expect private
                fields to be local symbols rather than private_extern (which
                is "package-global") (JM)
              }
              if not(vf.visibility in [vis_public,vis_protected,vis_strictprotected]) then
                vis:=AB_PRIVATE_EXTERN
              else
                vis:=AB_GLOBAL;
              vars[vcnt].offssym:=CurrentAsmData.DefineAsmSymbol(prefix+vf.RealName,vis,AT_DATA,PtrUIntType);
              tcb.emit_tai(TAIConst.Create_int_dataptr(vf.FieldOffset),PtrUIntType);
              list.ConcatList(
                tcb.get_final_asmlist(
                  vars[vcnt].offssym,PtrUIntType,
                  sec_objc_const,'_OBJC_IVAR_OFFSETS',sizeof(PInt)
                )
              );
              tcb.free;
              tcb := nil;
              inc(vcnt);
            end
          else
            { must be caught during parsing }
            InternalError(2009092301);
        end;
    if vcnt=0 then
      exit;

    tcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_new_section,tcalo_no_dead_strip]);

    CurrentAsmData.getlabel(ivarslabel,alt_data);

    tcb.begin_anonymous_record(
      internaltypeprefixName[itb_objc_nf_ivars]+ToStr(vcnt),
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

    { size of each entry -- always 32 bit value }
    ivtype:=Search_Named_Unit_GlobalType('OBJC','OBJC_IVAR',true).typedef;
    tcb.emit_ord_const(ivtype.size,U32IntType);
    { number of entries -- always 32 bit value }
    tcb.emit_ord_const(vcnt,U32IntType);

    { we use voidpointertype for all elements so that we can reuse the
      recorddef for all ivar tables with the same number of elements }
    pptruinttype:=CPointerDef.getreusable(PtrUIntType);
    for i:=0 to vcnt-1 do
      begin
        { reference to the offset }
        tcb.emit_tai(TAIConst.Create_sym(vars[i].offssym),pptruinttype);
        { reference to the instance variable name (}
        tcb.queue_init(VoidPointerType);
        tcb.queue_emit_asmsym(vars[i].namesym,vars[i].namedef);
        { reference to the encoded type }
        tcb.queue_init(VoidPointerType);
        tcb.queue_emit_asmsym(vars[i].TypeSym,vars[i].typedef);
        { alignment -- always 32 bit value }
        tcb.emit_ord_const(vars[i].vf.vardef.alignment,U32IntType);
        { size -- always 32 bit value }
        tcb.emit_ord_const(vars[i].vf.vardef.size,U32IntType);
      end;
    list.ConcatList(
      tcb.get_final_asmlist(
        ivarslabel,tcb.end_anonymous_record,
        sec_objc_instance_vars,'_OBJC_INSTANCE_VARS',sizeof(PInt)
      )
    );
    tcb.free;
    tcb := nil;
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
procedure TObjCRTTIWriterNonFragile.gen_objc_protocol(list: TAsmList; protocol: TObjectDef; out protocollabel: TAsmSymbol);
  var
    lbl,
    listsym,
    protolist     : TAsmSymbol;
    namedef       : TDef;
    namesym       : TAsmLabel;
    reqinstsym,
    reqclssym,
    optinstsym,
    optclssym,
    extmethodssym : TAsmSymbol;
    prottype      : TDef;
    tcb           : TTAITypedConstBuilder;
    sec           : TAsmSectiontype;
  begin
    gen_objc_protocol_list(list,protocol,true,protolist);
    gen_objc_protocol_elements(list,protocol,reqinstsym,optinstsym,reqclssym,optclssym,extmethodssym);

    { label for the protocol needs to be
        a) in a coalesced section (so multiple definitions of the same protocol
           can be merged by the linker)
        b) private_extern (should only be merged within the same module)
        c) weakly defined (so multiple definitions don't cause errors)
    }
    prottype:=Search_Named_Unit_GlobalType('OBJC','OBJC_PROTOCOL',true).typedef;
    lbl:=CurrentAsmData.DefineAsmSymbol(protocol.RTTIMangledName(objcclassrtti),AB_PRIVATE_EXTERN,AT_DATA,prottype);
    protocollabel:=lbl;

    tcb:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_weak]);
    tcb.maybe_begin_aggregate(prottype);
    { protocol's isa - always nil }
    tcb.emit_tai(TAIConst.Create_nil_dataptr,ObjC_IDType);
    { name }
    objcreatestringpoolentry(protocol.ObjExtName^,sp_objcclassnames,sec_objc_class_names,namesym,namedef);
    tcb.queue_init(CharPointerType);
    tcb.queue_emit_asmsym(namesym,namedef);
    { parent protocols list }
    ConcatSymOrNil(tcb,protolist,VoidPointerType);
    { required instance methods }
    ConcatSymOrNil(tcb,reqinstsym,VoidPointerType);
    { required class methods }
    ConcatSymOrNil(tcb,reqclssym,VoidPointerType);
    { optional instance methods }
    ConcatSymOrNil(tcb,optinstsym,VoidPointerType);
    { optional class methods }
    ConcatSymOrNil(tcb,optclssym,VoidPointerType);
    { TODO: properties }
    tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { size of this type }
    tcb.emit_ord_const(prottype.size,U32IntType);
    { flags }
    tcb.emit_ord_const(0,U32IntType);
    { extendedMethodTypes }
    ConcatSymOrNil(tcb,extmethodssym,VoidPointerType);
    { demangledName (unknown, always seems nil) }
    tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { classProperties -- todo }
    tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    tcb.maybe_end_aggregate(prottype);
    { coalesced sections are only required for ld-classic, because it does not
      support "weak" bits on all symbols. They are deprecated in ld64 starting
      from 2015: https://lists.llvm.org/pipermail/llvm-commits/Week-of-Mon-20151012/305992.html

      While targeting 10.6 or higher does not guarantee we are using ld64,
      we don't have a better heuristic available.
    }
    if not MacOSXVersionMin.IsValid or
       (MacOSXVersionMin.RelationTo(10,6,0)>=0) then
      sec:=sec_data
    else
      sec:=sec_data_coalesced;
    list.ConcatList(
      tcb.get_final_asmlist(
        lbl,prottype,
        sec,'_OBJC_PROTOCOL',sizeof(PInt)
      )
    );
    tcb.free;

    { also add an entry to the __DATA, __objc_protolist section, required to
      register the protocol with the runtime }
    listsym:=CurrentAsmData.DefineAsmSymbol(protocol.RTTIMangledName(objcmetartti),AB_PRIVATE_EXTERN,AT_DATA,CPointerDef.getreusable(prottype));
    tcb:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_weak,tcalo_no_dead_strip]);
    tcb.emit_tai(TAIConst.Create_sym(lbl),CPointerDef.getreusable(prottype));
    list.ConcatList(
      tcb.get_final_asmlist(
        listsym,CPointerDef.getreusable(prottype),
        sec_objc_protolist,'_OBJC_PROTOLIST',sizeof(PInt)
      )
    );
    tcb.free;
    tcb := nil;
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
procedure TObjCRTTIWriterNonFragile.gen_objc_category_sections(list:TAsmList; objccat: TObjectDef; out catlabel: TAsmSymbol; out catlabeldef: TDef);
  var
    catstrsym     : TAsmLabel;
    protolistsym,
    instmthdlist,
    clsmthdlist,
    clssym,
    catsym        : TAsmSymbol;
    catstrdef,
    catdef        : TDef;
    tcb           : TTAITypedConstBuilder;
  begin
    { the category name }
    objcreatestringpoolentry(objccat.ObjExtName^,sp_objcclassnames,sec_objc_class_names,catstrsym,catstrdef);

    { the class it extends }
    clssym:=CurrentAsmData.RefAsmSymbol(objccat.ChildOf.RTTIMangledName(objcclassrtti),AT_DATA);

    { generate the methods lists }
    gen_objc_methods(list,objccat,instmthdlist,false,true);
    gen_objc_methods(list,objccat,clsmthdlist,true,true);

    { generate implemented protocols list }
    gen_objc_protocol_list(list,objccat,true,protolistsym);

    { category declaration section }
    tcb:=CTAITypedConstBuilder.create([tcalo_new_section]);
    tcb.begin_anonymous_record(internaltypeprefixName[itb_objc_nf_category],
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
    tcb.queue_init(VoidPointerType);
    tcb.queue_emit_asmsym(catstrsym,catstrdef);
    tcb.emit_tai(TAIConst.Create_sym(clssym),VoidPointerType);
    ConcatSymOrNil(tcb,instmthdlist,VoidPointerType);
    ConcatSymOrNil(tcb,clsmthdlist,VoidPointerType);
    ConcatSymOrNil(tcb,protolistsym,VoidPointerType);
    { properties, not yet supported }
    tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { size }
    tcb.emit_tai(TAIConst.Create_32bit(64),S32IntType);
    { padding }
    tcb.emit_tai(TAIConst.Create_32bit(0),S32IntType);
    catdef:=tcb.end_anonymous_record;
    catsym:=CurrentAsmData.DefineAsmSymbol(objccat.RTTIMangledName(objcclassrtti),AB_LOCAL,AT_DATA,catdef);
    list.ConcatList(
      tcb.get_final_asmlist(
        catsym,catdef,
        sec_objc_const,'_OBJC_CATEGORY',sizeof(PInt)
      )
    );
    tcb.free;
    tcb := nil;

    catlabel:=catsym;
    catlabeldef:=catdef;
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

procedure TObjCRTTIWriterNonFragile.gen_objc_class_ro_part(list: TAsmList; objclss: TObjectDef; protolistsym: TAsmSymbol; out classrolabel: TAsmSymbol; metaclass: boolean);
  const
    CLS_CLASS        = 0;
    CLS_META         = 1;
    CLS_ROOT         = 2;
    OBJC2_CLS_HIDDEN = $10;
    CLS_EXCEPTION    = $20;
  var
    methodssym,
    rosym        : TAsmSymbol;
    classStrDef  : TDef;
    classStrSym,
    ivarslab     : TAsmLabel;
    rodef,
    class_type   : TDef;
    start,
    size,
    flags        : cardinal;
    rttitype     : TRTTIType;
    firstfield   : TFieldVarSym;
    i            : LongInt;
    tcb          : TTAITypedConstBuilder;
  begin
    { consider every class declared in the implementation section of a unit
      as "hidden"
    }
    flags:=0;
    if (objclss.owner.SymTableType=staticsymtable) and
       CurrentModule.IsUnit then
      flags:=OBJC2_CLS_HIDDEN;
    if metaclass then
      begin
        flags:=flags or CLS_META;
        rttitype:=objcmetarortti;
        { metaclass size/start: always size of objc_object }
        class_type:=Search_Named_Unit_GlobalType('OBJC','OBJC_OBJECT',true).typedef;
        start:=class_type.size;
        size:=start;
      end
    else
      begin
        flags:=flags or CLS_CLASS;
        rttitype:=objcclassrortti;
        size:=TObjectSymTable(objclss.SymTable).DataSize;
        { can't simply use childof's datasize, because alignment may cause the
          first field to skip a couple of bytes after the previous end }
        firstfield:=nil;
        for i:=0 to objclss.SymTable.SymList.Count-1 do
          if (TSym(objclss.SymTable.SymList[i]).typ=FieldVarSym) then
            begin
              firstfield:=TFieldVarSym(objclss.SymTable.SymList[i]);
              break;
            end;
        if Assigned(firstfield) then
          start:=firstfield.FieldOffset
        else
          { no extra fields -> start = size }
          start:=size;
      end;
    if not Assigned(objclss.ChildOf) then
      flags:=flags or CLS_ROOT;

    objcreatestringpoolentry(objclss.ObjExtName^,sp_objcclassnames,sec_objc_class_names,classStrSym,classStrDef);
    { generate methods list }
    gen_objc_methods(list,objclss,methodssym,metaclass,false);
    { generate ivars (nil for metaclass) }
    if metaclass then
      ivarslab:=nil
    else
      gen_objc_ivars(list,objclss,ivarslab);

    { class declaration section }
    tcb:=CTAITypedConstBuilder.create([tcalo_new_section]);
    tcb.begin_anonymous_record(
      internaltypeprefixName[itb_objc_nf_class_ro_part],
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

    tcb.emit_ord_const(flags,U32IntType);
    tcb.emit_ord_const(start,U32IntType);
    tcb.emit_ord_const(size,U32IntType);
    { strong ivar layout for garbage collection (deprecated) }
    tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    tcb.queue_init(VoidPointerType);
    tcb.queue_emit_asmsym(classStrSym,classStrDef);
    ConcatSymOrNil(tcb,methodssym,VoidPointerType);
    ConcatSymOrNil(tcb,protolistsym,VoidPointerType);
    ConcatSymOrNil(tcb,ivarslab,VoidPointerType);
    { weak ivar layout for garbage collection (deprecated) }
    tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    { TODO: properties }
    tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
    rodef:=tcb.end_anonymous_record;
    rosym:=CurrentAsmData.DefineAsmSymbol(objclss.RTTIMangledName(rttitype),AB_LOCAL,AT_DATA,rodef);
    list.ConcatList(
      tcb.get_final_asmlist(
        rosym,rodef,
        sec_objc_const,'_OBJC_META_CLASS',sizeof(PInt)
      )
    );
    tcb.free;
    tcb := nil;
    classrolabel:=rosym;
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
procedure TObjCRTTIWriterNonFragile.gen_objc_classes_sections(list:TAsmList; objclss: TObjectDef; out classlabel: TAsmSymbol; out classlabeldef: TDef);
  var
    root          : TObjectDef;
    superSym,
    superMetaSym,
    metaisaSym,
    metasym,
    clssym,
    metarosym,
    rosym,
    protolistsym  : TAsmSymbol;
    vis           : TAsmsymbind;
    isatcb,
    metatcb       : TTAITypedConstBuilder;
    metadef,
    classdef      : TDef;
  begin
    { A) Register necessary names }

    { 1) the current class and metaclass }
    if (objclss.owner.SymTableType=GlobalSymTable) then
      vis:=AB_GLOBAL
    else
      vis:=AB_PRIVATE_EXTERN;

    { create the typed const builders so we can get the (provisional) types
      for the class and metaclass symbols }
    isatcb:=CTAITypedConstBuilder.create([]);
    classdef:=isatcb.begin_anonymous_record(
      internaltypeprefixName[itb_objc_nf_class],
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

    metatcb:=CTAITypedConstBuilder.create([tcalo_new_section]);
    metadef:=metatcb.begin_anonymous_record(
      internaltypeprefixName[itb_objc_nf_meta_class],
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

    clssym:=CurrentAsmData.DefineAsmSymbol(objclss.RTTIMangledName(objcclassrtti),vis,AT_DATA,classdef);
    metasym:=CurrentAsmData.DefineAsmSymbol(objclss.RTTIMangledName(objcmetartti),vis,AT_DATA,metadef);
    { 2) the superclass and meta superclass }
    if Assigned(objclss.ChildOf) then
      begin
        superSym:=CurrentAsmData.RefAsmSymbol(objclss.ChildOf.RTTIMangledName(objcclassrtti),AT_DATA);
        superMetaSym:=CurrentAsmData.RefAsmSymbol(objclss.ChildOf.RTTIMangledName(objcmetartti),AT_DATA);
      end
    else
      begin
        superSym:=nil;
        { the class itself }
        superMetaSym:=clssym;
      end;

    { 3) the isa }
    { From Clang: The isa for the meta-class is the root of the hierarchy. }
    root:=objclss;
    while Assigned(root.ChildOf) do
      root:=root.ChildOf;
    metaisaSym:=CurrentAsmData.RefAsmSymbol(root.RTTIMangledName(objcmetartti),AT_DATA);

    { 4) the implemented protocols (same for metaclass and regular class) }
    gen_objc_protocol_list(list,objclss,true,protolistsym);

    { 5) the read-only parts of the class definitions }
    gen_objc_class_ro_part(list,objclss,protolistsym,metarosym,true);
    gen_objc_class_ro_part(list,objclss,protolistsym,rosym,false);

    { B) Class declaration section }
    { both class and metaclass are in the objc_data section for obj-c 2 }

    { 1) meta-class declaration }

    { the isa }
    metatcb.emit_tai(TAIConst.Create_sym(metaisaSym),VoidPointerType);
    { the superclass }
    metatcb.emit_tai(TAIConst.Create_sym(superMetaSym),VoidPointerType);
    { pointer to cache }
    if not Assigned(ObjCEmptyCacheVar) then
      ObjCEmptyCacheVar:=CurrentAsmData.RefAsmSymbol(TargetInfo.Cprefix+'_objc_empty_cache',AT_DATA);
    metatcb.emit_tai(TAIConst.Create_sym(ObjCEmptyCacheVar),VoidPointerType);
    { pointer to vtable }
    if not Assigned(ObjCEmptyVtableVar) and
       not(TargetInfo.system in [system_aarch64_ios,system_aarch64_darwin,system_i386_iphonesim,system_x86_64_iphonesim,system_aarch64_iphonesim]) then
      ObjCEmptyVtableVar:=CurrentAsmData.RefAsmSymbol(TargetInfo.Cprefix+'_objc_empty_vtable',AT_DATA);
    ConcatSymOrNil(metatcb,ObjCEmptyVtableVar,VoidPointerType);
    { the read-only part }
    metatcb.emit_tai(TAIConst.Create_sym(metarosym),VoidPointerType);
    metatcb.end_anonymous_record;
    list.ConcatList(
      metatcb.get_final_asmlist(
        metasym,metadef,
        sec_objc_data,'_OBJC_CLASS',sizeof(PInt)
      )
    );
    metatcb.free;
    metatcb := nil;

    { 2) regular class declaration }
    { the isa }
    isatcb.emit_tai(TAIConst.Create_sym(metasym),CPointerDef.getreusable(metadef));
    { the superclass }
    ConcatSymOrNil(isatcb,supersym,VoidPointerType);
    { pointer to cache }
    isatcb.emit_tai(TAIConst.Create_sym(ObjCEmptyCacheVar),VoidPointerType);
    { pointer to vtable }
    ConcatSymOrNil(isatcb,ObjCEmptyVtableVar,VoidPointerType);
    { the read-only part }
    isatcb.emit_tai(TAIConst.Create_sym(rosym),VoidPointerType);
    isatcb.end_anonymous_record;
    list.ConcatList(
      isatcb.get_final_asmlist(
        clssym,classdef,
        sec_objc_data,'_OBJC_CLASS',sizeof(PInt)
      )
    );
    isatcb.free;
    isatcb := nil;

    classlabel:=clssym;
    classlabeldef:=classdef;
  end;


procedure TObjCRTTIWriterNonFragile.addclasslist(list: TAsmList; section: TAsmSectiontype; const symname: string; classes: TFPObjectList);
  var
    i: LongInt;
    sym: TAsmSymbol;
    tcb: TTAITypedConstBuilder;
    arrdef: TDef;
  begin
    if classes.count=0 then
      exit;
    tcb:=CTAITypedConstBuilder.create([tcalo_new_section,tcalo_no_dead_strip]);
    arrdef:=CArrayDef.getreusable(VoidPointerType,classes.count);
    sym:=CurrentAsmData.DefineAsmSymbol(symname,AB_LOCAL,AT_DATA,arrdef);
    tcb.maybe_begin_aggregate(arrdef);
    for i:=0 to classes.count-1 do
      tcb.emit_tai(
        TAIConst.Create_sym(CurrentAsmData.RefAsmSymbol(TObjectDef(classes[i]).RTTIMangledName(objcclassrtti),AT_DATA)),
        VoidPointerType
      );
    tcb.maybe_end_aggregate(arrdef);
    list.ConcatList(
      tcb.get_final_asmlist(
        sym,arrdef,
        section,symname,sizeof(PInt)
      )
    );
  end;

procedure TObjCRTTIWriterNonFragile.gen_objc_protocol_extmethodtypes(list: TAsmList; prot: TObjectDef; items: TFPObjectList; out extmethsym: TAsmSymbol);
  var
    i     : integer;
    m     : TProcDef;
    lab   : TAsmLabel;
    def,
    ldef  : TDef;
    tcb   : TTAITypedConstBuilder;
  begin
    if not Assigned(items) or
       (items.count=0) then
      begin
        extmethsym:=nil;
        exit;
      end;

    tcb:=CTAITypedConstBuilder.create([tcalo_new_section]);
    tcb.begin_anonymous_record(
      internaltypeprefixName[itp_objc_prot_ext_methods]+ToStr(items.count),
      C_alignment,1,
      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
    for i:=0 to items.Count-1 do
      begin
        m:=TProcDef(items[i]);
        objcreatestringpoolentry(objcencodemethod(m),sp_objcvartypes,sec_objc_meth_var_types,lab,ldef);
        tcb.emit_tai(TAIConst.Create_sym(lab),ldef);
      end;
    def:=tcb.end_anonymous_record;
    extmethsym:=CurrentAsmData.DefineAsmSymbol(prot.RTTIMangledName(objcprotocolmethodstypelist),AB_LOCAL,AT_DATA,def);
    list.ConcatList(
      tcb.get_final_asmlist(
        extmethsym,def,sec_objc_const,'OBJC_PROTOCOL_METHOD_TYPES',sizeof(PInt))
    );
    tcb.free;
    tcb:=nil;
  end;

procedure TObjCRTTIWriterNonFragile.gen_objc_protocol_elements(list: TAsmList; protocol: TObjectDef; out reqinstsym, optinstsym, reqclssym, optclssym: TAsmSymbol; out extmethsym: TAsmSymbol);
  var
    reqinstmlist,
    reqclsmlist,
    optinstmlist,
    optclsmlist,
    allmethods: TFPObjectList;
begin
    get_objc_protocol_methods(protocol,reqinstmlist,optinstmlist,reqclsmlist,optclsmlist);
    gen_objc_protocol_methods_common(list,protocol,reqinstmlist,optinstmlist,reqclsmlist,optclsmlist,reqinstsym,optinstsym,reqclssym,optclssym);
    // extended method list = list of all method signatures in order (and only signatures)
    allmethods:=TFPObjectList.Create(false);
    allmethods.ConcatListCopy(reqinstmlist);
    allmethods.ConcatListCopy(reqclsmlist);
    allmethods.ConcatListCopy(optinstmlist);
    allmethods.ConcatListCopy(optclsmlist);
    gen_objc_protocol_extmethodtypes(list,protocol,allmethods,extmethsym);

    reqinstmlist.Free;
    reqclsmlist.Free;
    optinstmlist.Free;
    optclsmlist.Free;
    allmethods.Free;
end;


procedure TObjCRTTIWriterNonFragile.gen_objc_info_sections(list: TAsmList);

  function collectnonlazyclasses(classes: TFPObjectList): TFPObjectList;
    var
      symentry : TSym;
      procdef  : TProcDef;
      i,j      : LongInt;
    begin
      { non-lazy classes are all classes that define a class method with the
        selector called "load" (simply inheriting this class method is not enough,
        they have to implement it themselves)

        -- TODO: this currently only works if the Pascal identifier is also 'load'! }
      result:=TFPObjectList.create(false);
      for i:=0 to classes.count-1 do
        begin
          symentry:=TSym(TObjectSymTable(TObjectDef(classes[i]).SymTable).find('LOAD'));
          if Assigned(symentry) and
             (symentry.typ=ProcSym) then
            begin
              for j:=0 to TProcSym(symentry).ProcdefList.count do
                begin
                  procdef:=TProcDef(TProcSym(symentry).ProcdefList[0]);
                  if ((po_classmethod in procdef.ProcOptions) and
                      (procdef.MessageInf.str^='load')) then
                    begin
                      result.add(classes[i]);
                      break;
                    end;
                end;
            end;
        end;
    end;

  var
    nonlazyclasses,
    nonlazycategories : TFPObjectList;
  begin
    if (classdefs.count=0) and
       (catdefs.count=0) then
      exit;

    nonlazyclasses:=collectnonlazyclasses(classdefs);
    nonlazycategories:=collectnonlazyclasses(catdefs);

    { this list has to include all classes, also the non-lazy ones }
    addclasslist(list,sec_objc_classlist,TargetAsm.labelprefix+'_OBJC_LABEL_CLASS_$',classdefs);
    addclasslist(list,sec_objc_nlclasslist,TargetAsm.labelprefix+'_OBJC_LABEL_NONLAZY_CLASS_$',nonlazyclasses);
    { category and non-lazy category lists }
    addclasslist(list,sec_objc_catlist,TargetAsm.labelprefix+'_OBJC_LABEL_CATEGORY_$',catdefs);
    addclasslist(list,sec_objc_nlcatlist,TargetAsm.labelprefix+'_OBJC_LABEL_NONLAZY_CATEGORY_$',nonlazycategories);

    nonlazyclasses.free;
    nonlazyclasses := nil;
    nonlazycategories.free;
    nonlazycategories := nil;
    { the non-fragile abi doesn't have any module info, nor lazy references
      to used classes or to parent classes }
  end;


constructor TObjCRTTIWriterNonFragile.create;
  begin
    inherited create(oa_nonfragile);
  end;


{******************************************************************
                 RTTI generation -- Main function
*******************************************************************}

procedure MaybeGenerateObjectiveCImageInfo(globalst, LocalST: TSymTable);
  var
    objcrttiwriter: TObjCRTTIWriter;
  begin
    if (m_objectivec1 in CurrentSettings.ModeSwitches) then
      begin
        { generate rtti for all obj-c classes, protocols and categories
          defined in this module. }
        if not(TargetInfo.system in systems_objc_nfabi) then
          objcrttiwriter:=TObjCRTTIWriterFragile.create
        else
          objcrttiwriter:=TObjCRTTIWriterNonFragile.create;
        objcrttiwriter.gen_objc_rtti_sections(CurrentAsmData.asmlists[al_objc_data],globalst);
        objcrttiwriter.gen_objc_rtti_sections(CurrentAsmData.asmlists[al_objc_data],LocalST);
        objcrttiwriter.gen_objc_info_sections(CurrentAsmData.asmlists[al_objc_data]);
        objcrttiwriter.free;
        objcrttiwriter := nil;
      end;
  end;


end.
