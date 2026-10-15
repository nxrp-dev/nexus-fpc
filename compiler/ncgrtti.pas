{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Routines for the code generation of RTTI data structures

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
unit ncgrtti;

{$i fpcdefs.inc}

interface

    uses
      CClasses,ConstExp,GlobType,
      aasmbase,aasmcnst,
      SymBase,symconst,symtype,symdef,SymSym,
      parabase;

    type

      { TRTTIWriter }

      TRTTIWriter=class
      private
        { required internal alignment of the rtti data }
        reqalign: shortint;
        { required packing of all structures except for ttypeinfo and tpropinfo,
          which always use packrecords 1 }
        defaultpacking: shortint;
        { write comments ? }
        addcomments : boolean;
        procedure fields_write_rtti(st:TSymTable;rt:TRTTIType);
        procedure params_write_rtti(def:TAbstractProcDef;rt:TRTTIType;allow_hidden:boolean);
        procedure fields_write_rtti_data(tcb: TTAITypedConstBuilder; def: TAbstractRecordDef; rt: TRTTIType);
        procedure methods_write_rtti(st:TSymTable;rt:TRTTIType;visibilities:TVisibilities;allow_hidden:boolean);
        procedure write_rtti_extrasyms(def:TDef;rt:TRTTIType;mainrtti:TAsmSymbol);
        procedure published_write_rtti(def : TObjectDef;rt:TRTTIType);
        procedure properties_write_rtti_data(tcb:TTAITypedConstBuilder;propnamelist:TFPHashObjectList;st:TSymTable;extended_rtti:boolean;visibilities:TVisibilities);
        procedure write_extended_method_table(tcb:TTAITypedConstBuilder;def:TAbstractRecordDef;PackRecords:LongInt);
        procedure write_extended_field_table(tcb:TTAITypedConstBuilder;def:TAbstractRecordDef;PackRecords:LongInt);
        procedure collect_propnamelist(propnamelist:TFPHashObjectList;def:TAbstractRecordDef;visibilities:TVisibilities);
        { only use a direct reference if the referenced type can *only* reside
          in the same unit as the current one }
        function ref_rtti(def:TDef;rt:TRTTIType;indirect:boolean;suffix:TSymStr):TAsmSymbol;
        procedure write_rtti_name(tcb: TTAITypedConstBuilder; def: TDef);
        procedure write_common_rtti_data(tcb:TTAITypedConstBuilder;def:TDef;rt:TRTTIType);
        procedure write_rtti_data(tcb: TTAITypedConstBuilder; def:TDef; rt: TRTTIType);
        procedure write_attribute_data(tcb: TTAITypedConstBuilder;attr_list:TRTTIAttributeList);
        procedure write_child_rtti_data(def:TDef;rt:TRTTIType);
        procedure write_rtti_reference(tcb: TTAITypedConstBuilder; def: TDef; rt: TRTTIType);
        procedure write_methods(tcb:TTAITypedConstBuilder;st:TSymTable;extended_rtti:boolean;visibilities:TVisibilities);
        procedure write_header(tcb: TTAITypedConstBuilder; def: TDef; typekind: byte);
        function write_methodkind(tcb:TTAITypedConstBuilder;def:TAbstractProcDef):byte;
        procedure write_callconv(tcb:TTAITypedConstBuilder;def:TAbstractProcDef);
        procedure write_paralocs(tcb:TTAITypedConstBuilder;para:PCGPara);
        procedure write_param_flag(tcb:TTAITypedConstBuilder;parasym:TParaVarSym);
        procedure write_param(tcb:TTAITypedConstBuilder;para:TParaVarSym);
        procedure write_mop_offset_table(tcb:TTAITypedConstBuilder;def:TAbstractRecordDef;mop:TManagementOperator);
        procedure maybe_add_comment(tcb:TTAITypedConstBuilder;const comment : string); inline;
      public
        constructor create;
        procedure write_rtti(def:TDef;rt:TRTTIType);
        procedure write_extended_method_table(tcb:TTAITypedConstBuilder;def:TAbstractRecordDef); inline;
        procedure write_extended_field_table(tcb:TTAITypedConstBuilder;def:TAbstractRecordDef); inline;
        function  get_rtti_label(def:TDef;rt:TRTTIType;indirect:boolean):TAsmSymbol; inline;
        function  get_rtti_label_ord2str(def:TDef;rt:TRTTIType;indirect:boolean):TAsmSymbol; inline;
        function  get_rtti_label_str2ord(def:TDef;rt:TRTTIType;indirect:boolean):TAsmSymbol; inline;
      end;

    { generate RTTI and init tables }
    procedure write_persistent_type_info(st:TSymTable;is_global:boolean);

    var
      RTTIWriter : TRTTIWriter;


implementation

    uses
       CUtils,
       Globals,Verbose,Systems,
       node,ncal,ncon,
       FModule, ProcInfo,
       SymTable,symutil,
       aasmtai,AAsmData,
       defutil,
       paramgr
       ;


    const
       rttidefstate : array[TRTTIType] of TDefState =
         (ds_rtti_table_written,ds_init_table_written,
         { Objective-C related, does not pass here }
         symconst.ds_none,symconst.ds_none,
         symconst.ds_none,symconst.ds_none,
         symconst.ds_none,symconst.ds_none,
         symconst.ds_none,symconst.ds_none,
         symconst.ds_none,symconst.ds_none);
       rttitypenames : array[TRTTIType] of string =
         ('full','init',
          'objcmeta','objcmetaro',
          'objcclass','objcclassro',
          'objcprotocollist','objcprotocolmethodstypelist',
          'objcinstancemethods','objectclassmethods',
          'objcprotinstancemethodsopt','objcprotoclassmethodsopt'
          );

    type
       TPropNameListItem = class(TFPHashObject)
         propindex : LongInt;
         propowner : TSymTable;
       end;


    function visibility_to_rtti_flags(vis: TVisibility): byte;
      begin
        case vis of
          vis_private:
            result:=byte(rv_private);
          vis_strictprivate:
            begin
              result:=byte(rv_private);
              // add bit to indicate "strict"
              result:=result or (1 shl 2);
            end;
          vis_protected:
            result:=byte(rv_protected);
          vis_strictprotected:
            begin
              result:=byte(rv_protected);
              // add bit to indicate "strict"
              result:=result or (1 shl 2);
            end;
          vis_public:
            result:=byte(rv_public);
          vis_published:
            result:=byte(rv_published);
          otherwise
            InternalError(2021061301);
        end;
      end;


    procedure write_persistent_type_info(st: TSymTable; is_global: boolean);
      var
        i : LongInt;
        def : TDef;
      begin
        for i:=0 to st.DefList.Count-1 do
          begin
            def:=TDef(st.DefList[i]);
            { skip generics }
            if [df_generic,df_genconstraint]*def.DefOptions<>[] then
              continue;
            case def.typ of
              recorddef:
                write_persistent_type_info(TRecordDef(def).SymTable,is_global);
              objectdef :
                begin
                  { Skip forward defs }
                  if (oo_is_forward in TObjectDef(def).ObjectOptions) then
                    continue;
                  { skip unique type aliases, they use the RTTI from the parent class }
                  if TObjectDef(def).Is_Unique_ObjPasDef then
                    continue;
                  write_persistent_type_info(TObjectDef(def).SymTable,is_global);
                end;
              procdef :
                begin
                  if Assigned(TProcDef(def).LocalST) and
                     (TProcDef(def).LocalST.SymTableType=LocalSymTable) then
                    write_persistent_type_info(TProcDef(def).LocalST,false);
                  if Assigned(TProcDef(def).ParaST) then
                    write_persistent_type_info(TProcDef(def).ParaST,false);
                end;
              errordef:
                { we shouldn't have come this far if we have an errordef somewhere }
                InternalError(2017010701);
              undefineddef:
                { don't write any RTTI for these }
                continue;
              else
                ;
            end;
            { always generate persistent tables for types in the interface so
              they can be reused in other units and give always the same pointer
              location. }
            { Init }
            if (
                Assigned(def.TypeSym) and
                is_global and
                not Is_ObjC_Class_Or_Protocol(def)
               ) or
               is_managed_type(def) or
               (ds_init_table_used in def.DefStates) then
              RTTIWriter.write_rtti(def,initrtti);
            { RTTI }
            if not(df_internal in def.DefOptions) and
               (
                (
                 Assigned(def.TypeSym) and
                 is_global and
                 not Is_ObjC_Class_Or_Protocol(def)
                ) or
                (ds_rtti_table_used in def.DefStates)
               ) then
              RTTIWriter.write_rtti(def,fullrtti);
          end;
      end;


{***************************************************************************
                              TRTTIWriter
***************************************************************************}

    function TRTTIWriter.get_rtti_label(def:TDef;rt:TRTTIType;indirect:boolean):TAsmSymbol;
      begin
        result:=ref_rtti(def,rt,indirect,'');
      end;

    function TRTTIWriter.get_rtti_label_ord2str(def:TDef;rt:TRTTIType;indirect:boolean):TAsmSymbol;
      begin
        result:=ref_rtti(def,rt,indirect,'_o2s');
      end;

    function TRTTIWriter.get_rtti_label_str2ord(def:TDef;rt:TRTTIType;indirect:boolean):TAsmSymbol;
      begin
        result:=ref_rtti(def,rt,indirect,'_s2o');
      end;

    procedure TRTTIWriter.write_methods(tcb:TTAITypedConstBuilder;st:TSymTable;extended_rtti:boolean;visibilities:TVisibilities);
      var
        rtticount,
        totalcount,
        i,j,k : LongInt;
        sym : TProcSym;
        def : TProcDef;
        para : TParaVarSym;
      begin
        maybe_add_comment(tcb,'RTTI: begin methods');
        tcb.begin_anonymous_record('',defaultpacking,min(reqalign,SizeOf(PInt)),
          targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

        totalcount:=0;
        rtticount:=0;
        for i:=0 to st.SymList.count-1 do
          if TSym(st.SymList[i]).typ=ProcSym then
            begin
              sym:=TProcSym(st.SymList[i]);
              inc(totalcount,sym.procdeflist.count);
              for j:=0 to sym.procdeflist.count-1 do
                begin
                def:=TProcDef(sym.procdeflist[j]);
                if (def.visibility in visibilities) and not (def.Is_Generic) then
                  inc(rtticount);
                end;
            end;

        { write the count section for non-extended methods }
        if not extended_rtti then
          begin
            maybe_add_comment(tcb,#9'count');
            tcb.emit_ord_const(totalcount,U16IntType);
            maybe_add_comment(tcb,#9'RTTI count');
            if rtticount=0 then
              tcb.emit_ord_const($FFFF,U16IntType)
            else
              tcb.emit_ord_const(rtticount,U16IntType);
          end;

        if rtticount>0 then
          for i:=0 to st.SymList.count-1 do
            if TSym(st.SymList[i]).typ=ProcSym then
              begin
                sym:=TProcSym(st.SymList[i]);
                for j:=0 to sym.procdeflist.count-1 do
                  begin
                    def:=TProcDef(sym.procdeflist[j]);

                    if (def.Is_Generic) or not (def.visibility in visibilities) then
                      continue;

                    def.Init_ParaLoc_Info(callerside);

                    maybe_add_comment(tcb,'RTTI: begin method '+def.FullProcName(false));
                    tcb.begin_anonymous_record('',defaultpacking,min(reqalign,SizeOf(PInt)),
                      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

                    maybe_add_comment(tcb,#9'return type');
                    write_rtti_reference(tcb,def.ReturnDef,fullrtti);
                    maybe_add_comment(tcb,#9'calling convention');
                    write_callconv(tcb,def);
                    maybe_add_comment(tcb,#9'method kind');
                    write_methodkind(tcb,def);
                    maybe_add_comment(tcb,#9'param count');
                    tcb.emit_ord_const(def.paras.count,U16IntType);
                    maybe_add_comment(tcb,#9'caller args size');
                    tcb.emit_ord_const(def.CallerArgAreaSize,SizeSIntType);
                    maybe_add_comment(tcb,#9'invoke helper');
                    if def.InvokeHelper=nil then
                      tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidCodePointerType)
                    else
                      tcb.emit_procdef_const(def.InvokeHelper);
                    maybe_add_comment(tcb,#9'name');
                    tcb.emit_pooled_shortstring_const_ref(sym.realname);

                    if extended_rtti then
                      begin
                        { write visibility section for extended RTTI }
                        maybe_add_comment(tcb,#9'visibility');
                        tcb.emit_ord_const(visibility_to_rtti_flags(def.visibility),U8IntType);
                        { for objects and classes write a VMT index }
                        if st.DefOwner.typ=objectdef then
                          begin
                            maybe_add_comment(tcb,#9'VMT index');
                            tcb.emit_ord_const(def.ExtNumber,U16IntType);
                          end;
                        maybe_add_comment(tcb,#9'Code Address');
                        tcb.emit_procdef_const(def);
                        maybe_add_comment(tcb,#9'Attribute table');
                        write_attribute_data(tcb,def.RTTIAttributeList);
                      end;

                    for k:=0 to def.paras.count-1 do
                        write_param(tcb,TParaVarSym(def.paras[k]));

                    if not is_void(def.ReturnDef) then
                      begin
                      maybe_add_comment(tcb,#9'return loc');
                      write_paralocs(tcb,@def.FuncRetLoc[callerside]);
                      end;

                    tcb.end_anonymous_record;
                    maybe_add_comment(tcb,'RTTI: end method '+def.FullProcName(false));
                  end;
              end;

        tcb.end_anonymous_record;
        maybe_add_comment(tcb,'RTTI: end methods');
      end;


    procedure TRTTIWriter.write_header(tcb: TTAITypedConstBuilder; def: TDef; typekind: byte);
      var
        name: shortstring;
      begin
        if Assigned(def.TypeSym) then
          name:=TTypeSym(def.TypeSym).realname
        else
          name:='';
        { TTypeInfo, always packed and doesn't need alignment }
        tcb.begin_anonymous_record(
          internaltypeprefixName[itp_rtti_header]+ToStr(length(name)),1,1,
          targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
        if def.typ=arraydef then
          InternalError(201012211);
        tcb.emit_tai(TAIConst.Create_8bit(typekind),U8IntType);
        tcb.emit_shortstring_const(name);

        tcb.end_anonymous_record;
      end;


    function TRTTIWriter.write_methodkind(tcb:TTAITypedConstBuilder;def:TAbstractProcDef):byte;
      begin
        case def.ProcTypeOption of
          potype_constructor: result:=mkConstructor;
          potype_destructor: result:=mkDestructor;
          potype_class_constructor: result:=mkClassConstructor;
          potype_class_destructor: result:=mkClassDestructor;
          potype_operator: result:=mkOperatorOverload;
          potype_procedure:
            if po_classmethod in def.ProcOptions then
              result:=mkClassProcedure
            else
              result:=mkProcedure;
          potype_function:
            if po_classmethod in def.ProcOptions then
              result:=mkClassFunction
            else
              result:=mkFunction;
        else
          begin
            if def.ReturnDef = VoidType then
              result:=mkProcedure
            else
              result:=mkFunction;
          end;
        end;
        tcb.emit_ord_const(result,U8IntType);
      end;


    procedure TRTTIWriter.write_callconv(tcb:TTAITypedConstBuilder;def:TAbstractProcDef);
      const
        ProcCallOptionToCallConv: array[TProcCallOption] of byte = (
         { pocall_none       } 0,
         { pocall_cdecl      } 1,
         { pocall_cppdecl    } 5,
         { pocall_far16      } 6,
         { pocall_oldfpccall } 7,
         { pocall_internproc } 8,
         { pocall_syscall    } 9,
         { pocall_pascal     } 2,
         { pocall_register   } 0,
         { pocall_safecall   } 4,
         { pocall_stdcall    } 3,
         { pocall_softfloat  } 10,
         { pocall_mwpascal   } 11,
         { pocall_interrupt  } 12,
         { pocall_hardfloat  } 13,
         { pocall_sysv_abi_default } 14,
         { pocall_sysv_abi_cdecl }   15,
         { pocall_ms_abi_default }   16,
         { pocall_ms_abi_cdecl }     17,
         { pocall_vectorcall }       18
        );
      begin
        tcb.emit_ord_const(ProcCallOptionToCallConv[def.ProcCallOption],U8IntType);
      end;


    procedure TRTTIWriter.write_paralocs(tcb:TTAITypedConstBuilder;para:PCGPara);
      var
        locs : TRTTIParaLocs;
        i : LongInt;
        pool : THashSet;
        entry : PHashSetItem;
        loclab : TAsmLabel;
        loctcb : TTAITypedConstBuilder;
        datadef : TDef;
      begin
        locs:=paramanager.cgparalocs_to_rttiparalocs(para^.location);
        if length(locs)>high(byte) then
          InternalError(2017010601);

        if length(locs)=0 then
          begin
            { *shrugs* }
            tcb.emit_tai(TAIConst.Create_nil_codeptr,VoidPointerType);
            exit;
          end;

        { do we have such a paraloc already in the pool? }
        pool:=CurrentAsmData.ConstPools[sp_paraloc];

        entry:=pool.FindOrAdd(@locs[0],length(locs)*sizeof(TRTTIParaLoc));

        if not Assigned(entry^.Data) then
          begin
            CurrentAsmData.getglobaldatalabel(loclab);

            loctcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_make_dead_strippable]);

            loctcb.begin_anonymous_record('',defaultpacking,min(reqalign,SizeOf(PInt)),
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
            loctcb.emit_ord_const(length(locs),U8IntType);
            for i:=low(locs) to high(locs) do
              begin
                loctcb.begin_anonymous_record('',defaultpacking,min(reqalign,SizeOf(PInt)),
                  targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
                loctcb.emit_ord_const(locs[i].loctype,U8IntType);
                loctcb.emit_ord_const(locs[i].regsub,U8IntType);
                loctcb.emit_ord_const(locs[i].regindex,U16IntType);
                { the corresponding type for aint is alusinttype }
                loctcb.emit_ord_const(locs[i].offset,ALUSIntType);
                loctcb.end_anonymous_record;
              end;
            datadef:=loctcb.end_anonymous_record;

            CurrentAsmData.asmlists[al_typedconsts].ConcatList(
              loctcb.get_final_asmlist(loclab,datadef,sec_rodata_norel,loclab.name,Const_Align(sizeof(PInt)))
            );

            loctcb.free;
            loctcb := nil;

            entry^.data:=loclab;
          end
        else
          loclab:=TAsmLabel(entry^.Data);

        tcb.emit_tai(TAIConst.Create_sym(loclab),VoidPointerType);
      end;


    procedure TRTTIWriter.write_param_flag(tcb:TTAITypedConstBuilder;parasym:TParaVarSym);
      var
        paraspec : word;
      begin
        case parasym.VarSpez of
          vs_value   : paraspec := 0;
          vs_const   : paraspec := pfConst;
          vs_var     : paraspec := pfVar;
          vs_out     : paraspec := pfOut;
          vs_constref: paraspec := pfConstRef;
          else
            InternalError(2013112904);
        end;
        { Kylix also seems to always add both pfArray and pfReference
          in this case
        }
        if is_open_array(parasym.vardef) or is_array_of_const(parasym.vardef) then
          paraspec:=paraspec or pfArray or pfReference;
        { and these for classes and interfaces (maybe because they
          are themselves addresses?)
        }
        if Is_Class_Or_Interface(parasym.vardef) then
          paraspec:=paraspec or pfAddress;
        { flags for the hidden parameters }
        if vo_is_hidden_para in parasym.VarOptions then
          paraspec:=paraspec or pfHidden;
        if vo_is_high_para in parasym.VarOptions then
          paraspec:=paraspec or pfHigh;
        if vo_is_self in parasym.VarOptions then
          paraspec:=paraspec or pfSelf;
        if vo_is_vmt in parasym.VarOptions then
          paraspec:=paraspec or pfVmt;
        if vo_is_funcret in parasym.VarOptions then
          paraspec:=paraspec or pfResult;
        { set bits run from the highest to the lowest bit on
          big endian systems
        }
        if (TargetInfo.endian = endian_big) then
          paraspec:=Reverse_Word(paraspec);
        { write flags for current parameter }
        tcb.emit_ord_const(paraspec,U16IntType);
      end;

    procedure TRTTIWriter.write_param(tcb: TTAITypedConstBuilder;
      para: TParaVarSym);
      begin
        maybe_add_comment(tcb,'RTTI: begin param '+para.prettyname);
        tcb.begin_anonymous_record('',defaultpacking,min(reqalign,SizeOf(PInt)),
          targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

        maybe_add_comment(tcb,#9'type');
        if is_open_array(para.vardef) or is_array_of_const(para.vardef) then
          write_rtti_reference(tcb,TArrayDef(para.vardef).ElementDef,fullrtti)
        else if para.vardef=CFormalType then
          write_rtti_reference(tcb,nil,fullrtti)
        else
          write_rtti_reference(tcb,para.vardef,fullrtti);
        maybe_add_comment(tcb,#9'flags');
        write_param_flag(tcb,para);

        maybe_add_comment(tcb,#9'name');
        tcb.emit_pooled_shortstring_const_ref(para.realname);

        maybe_add_comment(tcb,#9'locs');
        write_paralocs(tcb,@para.ParaLoc[callerside]);

        tcb.end_anonymous_record;
        maybe_add_comment(tcb,'RTTI: end param '+para.prettyname);
      end;


    function compare_mop_offset_entry(item1,item2:pointer):LongInt;
      var
        entry1: PManagementOperatorOffsetEntry absolute item1;
        entry2: PManagementOperatorOffsetEntry absolute item2;
      begin
        if entry1^.offset<entry2^.offset then
          result:=-1
        else if entry1^.offset>entry2^.offset then
          result:=1
        else
          result:=0;
      end;


    procedure TRTTIWriter.write_mop_offset_table(tcb:TTAITypedConstBuilder;def:TAbstractRecordDef;mop:TManagementOperator);
      var
        list : TFPList;
        datatcb : TTAITypedConstBuilder;
        tbllbl : TAsmLabel;
        entry : PManagementOperatorOffsetEntry;
        datadef,entrydef : TDef;
        i : LongInt;
        pdef : TObjectDef;
      begin
        list:=TFPList.create;
        TAbstractRecordSymTable(def.SymTable).Get_ManagementOperator_Offset_List(mop,list);
        if (def.typ=objectdef) then
          begin
            pdef:=TObjectDef(def).ChildOf;
            while Assigned(pdef) do
              begin
                TAbstractRecordSymTable(pdef.SymTable).Get_ManagementOperator_Offset_List(mop,list);
                pdef:=pdef.ChildOf;
              end;
            list.sort(@compare_mop_offset_entry);
          end;
        if list.count=0 then
          tcb.emit_tai(TAIConst.create_nil_dataptr,VoidPointerType)
        else
          begin
            tcb.start_internal_data_builder(CurrentAsmData.AsmLists[al_rtti],sec_rodata,'',datatcb,tbllbl);

            datatcb.begin_anonymous_record('',defaultpacking,min(reqalign,SizeOf(PInt)),
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
            datatcb.emit_ord_const(list.count,U32IntType);

            entrydef:=Get_RecordDef(itp_init_mop_offset_entry,[VoidCodePointerType,SizeUIntType],defaultpacking);

            for i:=0 to list.count-1 do
              begin
                entry:=PManagementOperatorOffsetEntry(list[i]);

                datatcb.maybe_begin_aggregate(entrydef);

                datatcb.queue_init(VoidCodePointerType);
                datatcb.queue_emit_proc(entry^.pd);

                datatcb.queue_init(SizeUIntType);
                datatcb.queue_emit_ordconst(entry^.offset,SizeUIntType);

                datatcb.maybe_end_aggregate(entrydef);

                dispose(entry);
              end;

            datadef:=datatcb.end_anonymous_record;

            tcb.finish_internal_data_builder(datatcb,tbllbl,datadef,sizeof(PInt));

            tcb.emit_tai(TAIConst.Create_sym(tbllbl),VoidPointerType);
          end;
        list.free;
        list := nil;
      end;


    procedure TRTTIWriter.write_rtti_name(tcb: TTAITypedConstBuilder; def: TDef);
      begin
         if is_open_array(def) then
           { open arrays never have a typesym with a name, since you cannot
             define an "open array type". Kylix prints the type of the
             elements in the array in this case (so together with the pfArray
             flag, you can reconstruct the full typename, I assume (JM))
           }
           def:=TArrayDef(def).ElementDef;
         { name }
         if Assigned(def.TypeSym) then
           tcb.emit_shortstring_const(TTypeSym(def.TypeSym).prettyname)
         else
           tcb.emit_shortstring_const('');
      end;


    procedure TRTTIWriter.write_common_rtti_data(tcb:TTAITypedConstBuilder;def:TDef;rt:TRTTIType);
      begin
        if rt<>fullrtti then
          write_attribute_data(tcb,nil)
        else
          write_attribute_data(tcb,TStoredDef(def).RTTIAttributeList);
      end;


    { writes a 32-bit count followed by array of field infos for given symtable }
    procedure TRTTIWriter.fields_write_rtti_data(tcb: TTAITypedConstBuilder; def: TAbstractRecordDef; rt: TRTTIType);
      var
        i   : LongInt;
        sym : TSym;
        fieldcnt: LongInt;
        st: TSymTable;
        fields: TFPList;
        parentrtti: boolean;
      begin
        fieldcnt:=0;
        parentrtti:=false;
        st:=def.SymTable;
        fields:=TFPList.create;
        fields.capacity:=st.SymList.count+1;
        { For objects, treat parent (if any) as a field with offset 0. This
          provides correct handling of entire instance with RTL rtti routines. }
        if (def.typ=objectdef) and (TObjectDef(def).ObjectType=odt_object) and
            Assigned(TObjectDef(def).ChildOf) and
            ((rt=fullrtti) or (TObjectDef(def).ChildOf.NeedsInitTable)) then
           begin
             parentrtti:=true;
             inc(fieldcnt);
           end;

        for i:=0 to st.SymList.Count-1 do
          begin
            sym:=TSym(st.SymList[i]);
            if is_normal_fieldvarsym(sym) and
               (
                (rt=fullrtti) or
                TFieldVarSym(sym).vardef.NeedsInitTable
               ) and
               not Is_ObjC_Class_Or_Protocol(TFieldVarSym(sym).vardef) then
              begin
                fields.add(TFieldVarSym(sym));
                inc(fieldcnt);
              end;
          end;
        { insert field count before data }
        maybe_add_comment(tcb,'Field count');
        tcb.emit_ord_const(fieldcnt,U32IntType);
        { parent object? }
        if parentrtti then
          begin
            write_rtti_reference(tcb,TObjectDef(def).ChildOf,rt);
            tcb.emit_ord_const(0,PtrUIntType);
          end;
        { fields }
        for i:=0 to fields.count-1 do
          begin
            sym:=TSym(fields[i]);
            maybe_add_comment(tcb,'RTTI begin field '+ToStr(i)+': '+sym.prettyname);
            write_rtti_reference(tcb,TFieldVarSym(sym).vardef,rt);
            tcb.emit_ord_const(TFieldVarSym(sym).FieldOffset,SizeUIntType);
            maybe_add_comment(tcb,'RTTI end field '+ToStr(i)+': '+sym.prettyname);
          end;
        fields.free;
        fields := nil;
      end;


    procedure TRTTIWriter.fields_write_rtti(st:TSymTable;rt:TRTTIType);
      var
        i   : LongInt;
        sym : TSym;
      begin
        for i:=0 to st.SymList.Count-1 do
          begin
            sym:=TSym(st.SymList[i]);
            if is_normal_fieldvarsym(sym) and
               (
                (rt=fullrtti) or
                TFieldVarSym(sym).vardef.NeedsInitTable
               ) then
              write_rtti(TFieldVarSym(sym).vardef,rt);
          end;
      end;


    procedure TRTTIWriter.params_write_rtti(def:TAbstractProcDef;rt:TRTTIType;allow_hidden:boolean);
      var
        i   : LongInt;
        sym : TParaVarSym;
      begin
        for i:=0 to def.paras.count-1 do
          begin
            sym:=TParaVarSym(def.paras[i]);
            if not (vo_is_hidden_para in sym.VarOptions) or allow_hidden then
              begin
                if is_open_array(sym.vardef) or is_array_of_const(sym.vardef) then
                  write_rtti(TArrayDef(sym.vardef).ElementDef,rt)
                else
                  write_rtti(sym.vardef,rt);
              end;
          end;
      end;


    procedure TRTTIWriter.methods_write_rtti(st:TSymTable;rt:TRTTIType;visibilities:TVisibilities;allow_hidden:boolean);
      var
        i,j : LongInt;
        sym : TProcSym;
        def : TAbstractProcDef;
      begin
        for i:=0 to st.SymList.count-1 do
          if TSym(st.SymList[i]).typ=ProcSym then
            begin
              sym:=TProcSym(st.SymList[i]);
              for j:=0 to sym.procdeflist.count-1 do
                begin
                  def:=TAbstractProcDef(sym.procdeflist[j]);
                  write_rtti(def.ReturnDef,rt);
                  params_write_rtti(def,rt,allow_hidden);
                end;
            end;
      end;


    procedure TRTTIWriter.write_extended_method_table(tcb:TTAITypedConstBuilder;def:TAbstractRecordDef;PackRecords:LongInt);
      var
        methodcount,
        i, j: LongInt;
        sym: TProcSym;
        pdef : TProcDef;

      begin
        { count methods }
        methodcount:=0;
        for i:=0 to def.SymTable.SymList.count-1 do
          if TSym(def.SymTable.SymList[i]).typ=ProcSym then
            begin
              sym:=TProcSym(def.SymTable.SymList[i]);
              for j:=0 to sym.procdeflist.count-1 do
                begin
                pdef:=TProcDef(sym.procdeflist[j]);
                if (not pdef.Is_Generic) and def.Is_Visible_For_RTTI(ro_methods,pdef.visibility) then
                  inc(methodcount);
                end;
            end;

        tcb.begin_anonymous_record('',PackRecords,min(reqalign,SizeOf(PInt)),
          targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
        { emit method count }
        maybe_add_comment(tcb,'RTTI Method table: method count');
        tcb.emit_ord_const(methodcount,U16IntType);
        { emit method entries (array) }
        if methodcount>0 then
          write_methods(tcb,def.SymTable,true,def.RTTI_Visibilities_For_Option(ro_methods));
        tcb.end_anonymous_record;
      end;


    procedure TRTTIWriter.write_extended_method_table(tcb:TTAITypedConstBuilder;def:TAbstractRecordDef);
      begin
        write_extended_method_table(tcb,def,defaultpacking);
      end;


    procedure TRTTIWriter.write_extended_field_table(tcb:TTAITypedConstBuilder;def:TAbstractRecordDef;PackRecords:LongInt);
      var
        i,cnt: integer;
        asym: TSym;
        fldsym : TFieldVarSym;
        list: TFPList;
      begin
        list:=TFPList.Create;
        { build list of visible fields }
        for i:=0 to def.SymTable.SymList.Count-1 do
          begin
            asym:=TSym(def.SymTable.SymList[i]);
            if (asym.typ=FieldVarSym) and
               not(sp_static in asym.SymOptions) and
               def.Is_Visible_For_RTTI(ro_fields, asym.visibility) then
              list.add(asym);
          end;
        {
          TExtendedFieldTable = record
            FieldCount: Word;
            Fields: array[0..0] of TExtendedFieldInfo;
          end;
        }
        tcb.begin_anonymous_record(internaltypeprefixName[itp_extended_rtti_table]+ToStr(list.count),PackRecords,min(reqalign,SizeOf(PInt)),targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
        maybe_add_comment(tcb,'RTTI: Extended Field count');
        tcb.emit_ord_const(list.count,U16IntType);
        for i := 0 to list.count-1 do
          begin
            fldsym:=TFieldVarSym(list[i]);
            {
              TExtendedFieldInfo = record
                FieldOffset: SizeUInt;
                FieldType: Pointer;
                FieldVisibility: Byte;
                Name: PShortString;
                Attributes :
              end;
            }
            tcb.begin_anonymous_record(internaltypeprefixName[itp_extended_rtti_field]+ToStr(fldsym.FieldOffset),PackRecords,min(reqalign,SizeOf(PInt)),targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
            { FieldOffset }
            tcb.emit_tai(TAIConst.Create_sizeint(fldsym.FieldOffset),SizeUIntType);
            { FieldType: PPTypeInfo }
            if Is_ObjC_Class_Or_Protocol(fldsym.vardef) then
              tcb.emit_tai(TAIConst.Create_sym(RTTIWriter.get_rtti_label(VoidPointerType,fullrtti,true)),VoidPointerType)
            else
              tcb.emit_tai(TAIConst.Create_sym(RTTIWriter.get_rtti_label(fldsym.vardef,fullrtti,true)),VoidPointerType);
            { FieldVisibility }
            tcb.emit_ord_const(visibility_to_rtti_flags(fldsym.visibility),U8IntType);
            { Name }
            tcb.emit_pooled_shortstring_const_ref(fldsym.realname);
            { Attribute table }
            if Assigned(fldsym.RTTIAttributeList) and Assigned(fldsym.RTTIAttributeList.RTTIAttributes) then
              cnt:=fldsym.RTTIAttributeList.RTTIAttributes.count
            else
              cnt:=0;
            write_attribute_data(tcb,fldsym.RTTIAttributeList);
            tcb.end_anonymous_record;
          end;
        tcb.end_anonymous_record;
        list.free;
        list := nil;
      end;


    procedure TRTTIWriter.write_extended_field_table(tcb:TTAITypedConstBuilder;def:TAbstractRecordDef);
      begin
        write_extended_field_table(tcb,def,defaultpacking);
      end;


    procedure TRTTIWriter.published_write_rtti(def : TObjectDef;rt:TRTTIType);
      var
        i   : LongInt;
        st : TSymTable;
        sym : TSym;
      begin
        st:=def.SymTable;
        for i:=0 to st.SymList.Count-1 do
          begin
            sym:=TSym(st.SymList[i]);
            if (sym.visibility=vis_published) or def.Is_Visible_For_RTTI(ro_properties, sym.visibility)  then
              begin
                case TSym(sym).typ of
                  propertysym:
                    write_rtti(TPropertySym(sym).PropDef,rt);
                  FieldVarSym:
                    write_rtti(TFieldVarSym(sym).vardef,rt);
                  else
                    ;
                end;
              end;
          end;
      end;


    procedure TRTTIWriter.collect_propnamelist(propnamelist:TFPHashObjectList;def:TAbstractRecordDef;visibilities:TVisibilities);
      var
        i   : LongInt;
        sym : TSym;
        pn  : TPropNameListItem;
      begin
        { search into parent for objects }
        if def.typ=objectdef then
          begin
            if Assigned(TObjectDef(def).ChildOf) then
              collect_propnamelist(propnamelist,TObjectDef(def).ChildOf,visibilities);
          end;
        for i:=0 to def.SymTable.SymList.Count-1 do
          begin
            sym:=TSym(def.SymTable.SymList[i]);
            if (TSym(sym).typ=propertysym) and
               (sym.visibility in visibilities) then
              begin
                pn:=TPropNameListItem(propnamelist.Find(TSym(sym).name));
                if not Assigned(pn) then
                  begin
                     pn:=TPropNameListItem.create(propnamelist,TSym(sym).name);
                     pn.propindex:=propnamelist.count-1;
                     pn.propowner:=TSym(sym).owner;
                  end;
             end;
          end;
      end;


    procedure TRTTIWriter.properties_write_rtti_data(tcb: TTAITypedConstBuilder; propnamelist:TFPHashObjectList; st:TSymTable; extended_rtti:boolean; visibilities:TVisibilities);
      var
        i : LongInt;
        sym : TSym;
        proctypesinfo : byte;
        propnameitem  : TPropNameListItem;
        propdefname : string;
        tbltcb : TTAITypedConstBuilder;
        tbllab : TAsmLabel;
        tbldef : TDef;
        visbyte : byte;

        procedure writeaccessproc(tcb: TTAITypedConstBuilder; pap:TPropAccessListTypes; shiftvalue : byte; unsetvalue: byte);
        var
           typvalue : byte;
           hp : PPropAccessListItem;
           ExtNumber: LongInt;
           address,space : LongInt;
           def : TDef;
           hpropsym : TPropertySym;
           PropAccessList : TPropAccessList;
        begin
           hpropsym:=TPropertySym(sym);
           repeat
             PropAccessList:=hpropsym.PropAccessList[pap];
             if not PropAccessList.empty then
               break;
             hpropsym:=hpropsym.OverriddenPropSym;
           until not Assigned(hpropsym);
           if not(Assigned(PropAccessList) and Assigned(PropAccessList.FirstSym))  then
             begin
               tcb.emit_tai(TAIConst.Create_int_codeptr(unsetvalue),CodePtrUIntType);
               typvalue:=3;
             end
           { also for accessing class fields }
           else if PropAccessList.FirstSym^.sym.typ=FieldVarSym then
             begin
                address:=0;
                hp:=PropAccessList.FirstSym;
                def:=nil;
                while Assigned(hp) do
                  begin
                     case hp^.SLType of
                       sl_load :
                         begin
                           def:=TFieldVarSym(hp^.sym).vardef;
                           inc(address,TFieldVarSym(hp^.sym).FieldOffset);
                         end;
                       sl_subscript :
                         begin
                           if not(Assigned(def) and
                                  ((def.typ=recorddef) or
                                   Is_Object(def))) then
                             InternalError(200402171);
                           inc(address,TFieldVarSym(hp^.sym).FieldOffset);
                           def:=TFieldVarSym(hp^.sym).vardef;
                         end;
                       sl_vec :
                         begin
                           if not(Assigned(def) and (def.typ=arraydef)) then
                             InternalError(200402172);
                           def:=TArrayDef(def).ElementDef;
                           {Hp.value is a Tconstexprint, which can be rather large,
                            sanity check for longint overflow.}
                           space:=(high(address)-address) div def.size;
                           if int64(space)<hp^.value then
                             InternalError(200706101);
                           inc(address,int64(def.size*hp^.value));
                         end;
                       else
                         InternalError(2019050523);
                     end;
                     hp:=hp^.next;
                  end;
                tcb.emit_tai(TAIConst.Create_int_codeptr(address),CodePtrUIntType);
                typvalue:=0;
             end
           else
             begin
                { When there was an error then procdef is not assigned }
                if not Assigned(PropAccessList.procdef) then
                  exit;
                if not(po_virtualmethod in TProcDef(PropAccessList.procdef).ProcOptions) or
                   Is_ObjectPascal_Helper(TProcDef(PropAccessList.procdef).struct) then
                  begin
                    tcb.queue_init(CodePtrUIntType);
                    tcb.queue_emit_proc(TProcDef(PropAccessList.procdef));
                    typvalue:=1;
                  end
                else
                  begin
                    { virtual method, write vmt offset }
                    ExtNumber:=TProcDef(PropAccessList.procdef).ExtNumber;
                    tcb.emit_tai(TAIConst.Create_int_codeptr(
                      TObjectDef(TProcDef(PropAccessList.procdef).struct).VMTMethodOffset(ExtNumber)),
                      CodePtrUIntType);
                    { register for wpo }
                    TObjectDef(TProcDef(PropAccessList.procdef).struct).Register_VMT_Call(ExtNumber);
                    {$ifdef vtentry}
                    { not sure if we can insert those vtentry symbols safely here }
                    {$error register methods used for published properties}
                    {$endif vtentry}
                    typvalue:=2;
                  end;
             end;
           proctypesinfo:=proctypesinfo or (typvalue shl shiftvalue);
        end;

        function properties_count(st:TSymTable):LongInt;
          var
            i   : LongInt;
            sym : TSym;
          begin
            result:=0;
            for i:=0 to st.SymList.Count-1 do
              begin
                sym:=TSym(st.SymList[i]);
                if (TSym(sym).typ=propertysym) and
                   (sym.visibility in visibilities) and
                   (extended_rtti or (
                     (TPropertySym(sym).ParaST=Nil) and
                     not (sp_static in sym.SymOptions)
                   )) then
                  inc(result);
              end;
          end;

        procedure write_prop_params(tcb:TTAITypedConstBuilder;paramst:TSymTable);
          var
            paramtcb : TTAITypedConstBuilder;
            paramlbl : TAsmLabel;
            paramdef : TDef;
            i : LongInt;
          begin
              tcb.start_internal_data_builder(CurrentAsmData.AsmLists[al_rtti],sec_rodata,'',paramtcb,paramlbl);

              paramtcb.begin_anonymous_record('',defaultpacking,min(reqalign,SizeOf(PInt)),
                targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

              { paramcount }
              paramtcb.emit_ord_const(paramst.SymList.count,U32IntType);
              for i:=0 to paramst.SymList.count-1 do
                begin
                  if TSym(paramst.SymList[i]).typ<>paravarsym then
                    InternalError(2024103101);
                  write_param(paramtcb,TParaVarSym(paramst.SymList[i]));
                end;


              paramdef:=paramtcb.end_anonymous_record;
              tcb.finish_internal_data_builder(paramtcb,paramlbl,paramdef,sizeof(PInt));

              tcb.emit_tai(TAIConst.Create_sym(paramlbl),VoidPointerType);
          end;

        function write_propinfo_data(tcb: TTAITypedConstBuilder; sym: TPropertySym): TDef;
          begin
            { we can only easily reuse defs if the property is not stored,
              because otherwise the rtti layout depends on how the "stored"
              is defined (field, indexed expression, virtual method, ...) }
            if not(ppo_stored in sym.PropOptions) then
              propdefname:=internaltypeprefixName[itp_rtti_prop]+ToStr(length(sym.realname))
            else
              propdefname:='';
            { TPropInfo is a packed record (even on targets that require
              alignment), but it starts aligned }
            if addcomments then
              if Assigned(st.name) then
                tcb.emit_comment('RTTI: begin propinfo record '+sym.realname+' (class/rec: '+st.name^+')')
              else
                tcb.emit_comment('RTTI: begin propinfo record '+sym.realname+'(anon)');
            tcb.begin_anonymous_record(
              propdefname,
              1,min(reqalign,SizeOf(PInt)),
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
            if ppo_indexed in sym.PropOptions then
              proctypesinfo:=$40
            else
              proctypesinfo:=0;
            if addcomments then
              tcb.emit_comment(#9'type info '+sym.Name+' (Type: '+sym.PropDef.GetTypeName+')');
            write_rtti_reference(tcb,sym.PropDef,fullrtti);
            if addcomments then
              tcb.emit_comment(#9'read access');
            writeaccessproc(tcb,palt_read,0,0);
            if addcomments then
              tcb.emit_comment(#9'write access');
            writeaccessproc(tcb,palt_write,2,0);
            { is it stored ? }
            if addcomments then
              tcb.emit_comment(#9'stored ?');
            if not(ppo_stored in sym.PropOptions) then
              begin
                { no, so put a constant zero }
                tcb.emit_tai(TAIConst.Create_nil_codeptr,CodePtrUIntType);
                proctypesinfo:=proctypesinfo or (3 shl 4);
              end
            else
              writeaccessproc(tcb,palt_stored,4,1); { maybe; if no procedure put a constant 1 (=true) }
            if addcomments then
              tcb.emit_comment(#9'Index');
            tcb.emit_ord_const(sym.index,U32IntType);
            if addcomments then
              tcb.emit_comment(#9'default');
            tcb.emit_ord_const(sym.default,U32IntType);
            propnameitem:=TPropNameListItem(propnamelist.Find(sym.name));
            if not Assigned(propnameitem) then
              InternalError(200512201);
            if addcomments then
              tcb.emit_comment(#9'property index');
            tcb.emit_ord_const(propnameitem.propindex,U16IntType);
            if addcomments then
              tcb.emit_comment(#9'proc types');
            tcb.emit_ord_const(proctypesinfo,U8IntType);
            if addcomments then
              tcb.emit_comment(#9'is static prop');
            tcb.emit_ord_const(ord(sp_static in sym.SymOptions),PasBool1Type);
            { index parameters }
            if addcomments then
              tcb.emit_comment(#9'indexed params');
            if extended_rtti and Assigned(TPropertySym(sym).ParaST) then
              write_prop_params(tcb,sym.ParaST)
            else
              tcb.emit_tai(TAIConst.create_nil_dataptr,VoidPointerType);
            { write reference to attribute table }
            if addcomments then
              tcb.emit_comment(#9'attributes');
            write_attribute_data(tcb,sym.RTTIAttributeList);
            { write property name }
            if addcomments then
              tcb.emit_comment(#9'name');
            tcb.emit_shortstring_const(sym.realname);
            result:=tcb.end_anonymous_record;
            if addcomments then
              tcb.emit_comment('RTTI: End propinfo record '+sym.realname);
          end;

      begin
        tcb.begin_anonymous_record('',defaultpacking,min(reqalign,SizeOf(PInt)),
          targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
        if extended_rtti then
          maybe_add_comment(tcb,'RTTI: Extended property data: Property count')
        else
          maybe_add_comment(tcb,'RTTI: Legacy property data: Property count');
        tcb.emit_ord_const(properties_count(st),U16IntType);
        for i:=0 to st.SymList.Count-1 do
          begin
            sym:=TSym(st.SymList[i]);
            if (sym.typ=propertysym) and
               (sym.visibility in visibilities) and
               (extended_rtti or (TPropertySym(sym).ParaST=Nil)) then
              begin
                if extended_rtti then
                  begin
                    {
                      TPropInfoEx = record
                        Flags: Byte;
                        Info: PPropInfo;
                        // AttrData: TAttrData
                      end;
                    }
                    maybe_add_comment(tcb,'RTTI: begin property '+sym.prettyname);
                    tcb.begin_anonymous_record('',defaultpacking,min(reqalign,SizeOf(PInt)),
                      targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
                    { write visiblity flags for extended RTTI }
                    maybe_add_comment(tcb,#9'visibility flags');
                    visbyte:=byte(visibility_to_rtti_flags(sym.visibility));
                    tcb.emit_ord_const(visByte,U8IntType);
                    { create separate constant builder }
                    CurrentAsmData.getglobaldatalabel(tbllab);
                    tbltcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_make_dead_strippable]);
                    { write TPropInfo record }
                    tbldef:=write_propinfo_data(tbltcb,TPropertySym(sym));
                    CurrentAsmData.asmlists[al_rtti].ConcatList(
                      tbltcb.get_final_asmlist(tbllab,tbldef,sec_rodata,tbllab.name,Const_Align(sizeof(PInt)))
                    );
                    tbltcb.free;
                    tbltcb := nil;
                    { write the pointer to the prop info }
                    maybe_add_comment(tcb,#9'property info reference');
                    tcb.emit_tai(TAIConst.Create_sym(tbllab),VoidPointerType);
                    { end record }
                    tcb.end_anonymous_record;
                    maybe_add_comment(tcb,'RTTI: end property '+sym.prettyname);
                  end
                else if not (sp_static in sym.SymOptions) then
                  write_propinfo_data(tcb,TPropertySym(sym));
              end;
          end;
        tcb.end_anonymous_record;
      end;


    procedure TRTTIWriter.write_rtti_data(tcb: TTAITypedConstBuilder; def: TDef; rt: TRTTIType);

        procedure unknown_rtti(def:TStoredDef);
        begin
          tcb.emit_ord_const(tkUnknown,U8IntType);
          write_rtti_name(tcb,def);
          write_common_rtti_data(tcb,def,rt);
        end;

        procedure variantdef_rtti(def:TVariantDef);
        begin
          write_header(tcb,def,tkVariant);
          write_common_rtti_data(tcb,def,rt);
        end;

        procedure stringdef_rtti(def:TStringDef);
        const
          string_typekinds: array[TStringType] of byte = (
            tkSString,tkLString,tkAString,tkWString,tkUString
          );
        begin
          write_header(tcb,def,string_typekinds[def.StringType]);
          tcb.begin_anonymous_record(
            internaltypeprefixName[itp_rtti_outer]+ToStr(string_typekinds[def.StringType]),
            defaultpacking,reqalign,
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          write_common_rtti_data(tcb,def,rt);
          case def.StringType of
            st_ansistring:
              begin
                tcb.begin_anonymous_record(
                  internaltypeprefixName[itp_rtti_case]+ToStr(string_typekinds[def.StringType]),
                  defaultpacking,reqalign,
                  targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
                tcb.emit_ord_const(def.encoding,U16IntType);
                tcb.end_anonymous_record;
              end;

            st_shortstring:
              begin
                tcb.begin_anonymous_record(
                  internaltypeprefixName[itp_rtti_case]+ToStr(string_typekinds[def.StringType]),
                  defaultpacking,reqalign,
                  targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
                tcb.emit_ord_const(def.len,U8IntType);
                tcb.end_anonymous_record;
              end;

            st_widestring,
            st_unicodestring,
            st_longstring:
              { nothing }
              ;

          end;
          tcb.end_anonymous_record;
        end;

        procedure enumdef_rtti(def: TEnumDef);
        var
           i  : integer;
           hp : TEnumSym;
        begin
          write_header(tcb,def,tkEnumeration);
          { align; the named fields are so that we can let the compiler
            calculate the string offsets later on }
          tcb.next_field_name:='size_start_rec';
          { add a typename so that it can be reused when writing the the s2o
            and o2s arrays for llvm (otherwise we have to write out the entire
            type definition every time we access an element from this record) }
          tcb.begin_anonymous_record(internaltypeprefixName[itp_rtti_enum_size_start_rec]+def.UniqueIDStr,defaultpacking,reqalign,
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          write_common_rtti_data(tcb,def,rt);
          tcb.next_field_name:='typ_union_rec';
          tcb.begin_anonymous_record(internaltypeprefixName[itp_rtti_enum_size_start_rec2]+def.UniqueIDStr,defaultpacking,reqalign,
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          case LongInt(def.size) of
            1 :
              tcb.emit_ord_const(otUByte,U8IntType);
            2 :
              tcb.emit_ord_const(otUWord,U8IntType);
            4 :
              tcb.emit_ord_const(otULong,U8IntType);
          end;
          { we need to align by Tconstptruint here to satisfy the alignment
            rules set by records: in the typinfo unit we overlay a TTypeData
            record on this data, which at the innermost variant record needs an
            alignment of TConstPtrUint due to e.g. the "CompType" member for
            tkSet (also the "BaseType" member for tkEnumeration).

            We need to adhere to this, otherwise things will break. }
          tcb.next_field_name:='min_max_rec';
          tcb.begin_anonymous_record(internaltypeprefixName[itp_rtti_enum_min_max_rec]+def.UniqueIDStr,defaultpacking,reqalign,
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          tcb.emit_ord_const(def.min,S32IntType);
          tcb.emit_ord_const(def.max,S32IntType);
          tcb.next_field_name:='basetype_array_rec';
          { all strings must appear right after each other -> from now on
            packrecords 1 (but the start must still be aligned) }
          tcb.begin_anonymous_record(internaltypeprefixName[itp_rtti_enum_basetype_array_rec]+def.UniqueIDStr,1,reqalign,
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          { write base type }
          write_rtti_reference(tcb,def.BaseDef,rt);
          for i:=0 to def.SymTable.SymList.Count-1 do
            begin
              hp:=TEnumSym(def.SymTable.SymList[i]);
              if hp.value<def.MinVal then
                continue
              else
              if hp.value>def.MaxVal then
                break;
              tcb.next_field_name:=hp.name;
              tcb.emit_shortstring_const(hp.realname);
            end;
          { write unit name }
          tcb.emit_shortstring_const(CurrentModule.RealModuleName^);
          { write zero which is required by RTL }
          tcb.emit_ord_const(0,U8IntType);
          { terminate all records }
          tcb.end_anonymous_record;
          tcb.end_anonymous_record;
          tcb.end_anonymous_record;
          tcb.end_anonymous_record;
        end;

        procedure orddef_rtti(def:TOrdDef);

          procedure doint32_64(typekind: byte;min,max:int64);
            const
              trans : array[TOrdType] of byte =
                (otUByte{otNone},
                 otUByte,otUWord,otULong,otUQWord,otUByte{otNone},
                 otSByte,otSWord,otSLong,otSQWord,otUByte{otNone},
                 otUByte,otUByte,otUWord,otULong,otUQWord,
                 otSByte,otSWord,otSLong,otSQWord,
                 otUByte,otUWord,otUByte,255);
            var
              EleSize: string[1];
              deftrans: byte;
          begin
            write_header(tcb,def,typekind);
            deftrans:=trans[def.OrdType];
            case deftrans of
              otUQWord,
              otSQWord:
                EleSize:='8';
              255:
                begin
                  if def.PackedBitSize<=32 then
                    begin
                      EleSize:='4';
                      if def.low<0 then
                        deftrans:=otSLong
                      else
                        deftrans:=otULong;
                    end
                  else
                    begin
                      EleSize:='8';
                      if def.low<0 then
                        deftrans:=otSQWord
                      else
                        deftrans:=otUQWord;
                    end;
                end
              else
                EleSize:='4'
            end;
            tcb.begin_anonymous_record(
              internaltypeprefixName[itp_rtti_ord_outer]+EleSize,
              defaultpacking,reqalign,
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
            write_common_rtti_data(tcb,def,rt);
            tcb.begin_anonymous_record(
              internaltypeprefixName[itp_rtti_ord_middle]+EleSize,
              defaultpacking,reqalign,
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
            tcb.emit_ord_const(byte(trans[def.OrdType]),U8IntType);
            tcb.begin_anonymous_record(
              internaltypeprefixName[itp_rtti_ord_inner]+EleSize,
              defaultpacking,reqalign,
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
            {Convert to longint to smuggle values in high(longint)+1..high(cardinal) into asmlist.}
            case deftrans of
              otUQWord:
                begin
                  tcb.emit_ord_const(min,U64IntType);
                  tcb.emit_ord_const(max,U64IntType);
                end;
              otSQWord:
                begin
                  tcb.emit_ord_const(min,S64IntType);
                  tcb.emit_ord_const(max,S64IntType);
                end;
              else
                begin
                  tcb.emit_ord_const(LongInt(min),S32IntType);
                  tcb.emit_ord_const(LongInt(max),S32IntType);
                end;
            end;
            tcb.end_anonymous_record;
            tcb.end_anonymous_record;
            tcb.end_anonymous_record;
          end;

        procedure dointeger(typekind:byte);inline;
          begin
            doint32_64(typekind,int64(def.low.svalue),int64(def.high.svalue));
          end;

        begin
          case def.OrdType of
            s64bit :
                dointeger(tkInt64);
            u64bit :
                dointeger(tkQWord);
            pasbool1,
            pasbool8,
            pasbool16,
            pasbool32,
            pasbool64:
                dointeger(tkBool);
            { use different low/high values to be Delphi compatible }
            bool8bit,
            bool16bit,
            bool32bit:
                doint32_64(tkBool,LongInt(low(LongInt)),LongInt(high(LongInt)));
            bool64bit:
                doint32_64(tkBool,low(int64),high(int64));
            uchar:
                dointeger(tkChar);
            uwidechar:
                dointeger(tkWChar);
            scurrency:
              begin
                write_header(tcb,def,tkFloat);
                tcb.begin_anonymous_record(
                  internaltypeprefixName[itp_1byte],
                  defaultpacking,reqalign,
                  targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
                write_common_rtti_data(tcb,def,rt);
                tcb.emit_ord_const(ftCurr,U8IntType);
                tcb.end_anonymous_record;
              end;
            else
              dointeger(tkInteger);
          end;
        end;


        procedure floatdef_rtti(def:TFloatDef);
        const
          translate : array[TFloatType] of byte =
             (ftSingle,ftDouble,ftExtended,ftExtended,ftComp,ftCurr);
        begin
           write_header(tcb,def,tkFloat);
           tcb.begin_anonymous_record(
             internaltypeprefixName[itp_1byte],
             defaultpacking,reqalign,
             targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
           write_common_rtti_data(tcb,def,rt);
           tcb.begin_anonymous_record(
             internaltypeprefixName[itp_rtti_float],
             defaultpacking,reqalign,
             targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
           tcb.emit_ord_const(translate[def.FloatType],U8IntType);
           tcb.end_anonymous_record;
           tcb.end_anonymous_record;
        end;


        procedure setdef_rtti(def:TSetDef);
        begin
           write_header(tcb,def,tkSet);
           tcb.begin_anonymous_record(
             internaltypeprefixName[itp_rtti_set_outer],
             defaultpacking,reqalign,
             targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
           write_common_rtti_data(tcb,def,rt);
           tcb.begin_anonymous_record(
             internaltypeprefixName[itp_rtti_set_middle],
             defaultpacking,reqalign,
             targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
           case def.size of
             1:
               tcb.emit_ord_const(otUByte,U8IntType);
             2:
               tcb.emit_ord_const(otUWord,U8IntType);
             4:
               tcb.emit_ord_const(otULong,U8IntType);
             else
               tcb.emit_ord_const(otUByte,U8IntType);
           end;
           tcb.begin_anonymous_record(
             internaltypeprefixName[itp_rtti_set_inner],
             defaultpacking,reqalign,
             targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
           tcb.emit_ord_const(def.size,SizeSIntType);
           write_rtti_reference(tcb,def.ElementDef,rt);
           tcb.end_anonymous_record;
           tcb.end_anonymous_record;
           tcb.end_anonymous_record;
        end;


        procedure arraydef_rtti(def:TArrayDef);
          var
            i,dimcount: byte;
            totalcount: ASizeUInt;
            finaldef: TDef;
            curdef:TArrayDef;
        begin
           if ado_IsDynamicArray in def.ArrayOptions then
             tcb.emit_ord_const(tkDynArray,U8IntType)
           else
             tcb.emit_ord_const(tkArray,U8IntType);
           write_rtti_name(tcb,def);

           if not(ado_IsDynamicArray in def.ArrayOptions) then
             begin
               { remember tha last instruction. we will need to insert some
                 calculated values after it }
               finaldef:=def;
               totalcount:=1;
               dimcount:=0;
               repeat
                 curdef:=TArrayDef(finaldef);
                 finaldef:=curdef.ElementDef;
                 { Dims[i] PTypeInfo }
                 inc(dimcount);
                 totalcount:=totalcount*curdef.EleCount;
               until (finaldef.typ<>arraydef) or
                     (ado_IsDynamicArray in TArrayDef(finaldef).ArrayOptions);
               tcb.begin_anonymous_record(
                 internaltypeprefixName[itp_rtti_normal_array]+ToStr(dimcount),
                 defaultpacking,reqalign,
                 targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

               write_common_rtti_data(tcb,def,rt);

               tcb.begin_anonymous_record(internaltypeprefixName[itp_rtti_normal_array_inner]+ToStr(dimcount),
                 defaultpacking,reqalign,
                 targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

               { total size = elecount * elesize of the first arraydef }
               tcb.emit_tai(TAIConst.Create_sizeint(def.EleCount*def.EleSize),SizeUIntType);
               { total element count }
               tcb.emit_tai(TAIConst.Create_sizeint(asizeint(totalcount)),SizeUIntType);
               { last dimension element type }
               if Is_ObjC_Class_Or_Protocol(curdef.ElementDef) then
                 tcb.emit_tai(TAIConst.Create_sym(get_rtti_label(VoidPointerType,rt,true)),VoidPointerType)
               else
                 tcb.emit_tai(TAIConst.Create_sym(get_rtti_label(curdef.ElementDef,rt,true)),VoidPointerType);
               { dimension count }
               tcb.emit_ord_const(dimcount,U8IntType);
               finaldef:=def;
               { ranges of the dimensions }
               for i:=1 to dimcount do
                 begin
                   curdef:=TArrayDef(finaldef);
                   finaldef:=curdef.ElementDef;
                   { Dims[i] PPTypeInfo }
                   write_rtti_reference(tcb,curdef.RangeDef,rt);
                 end;
             end
           else
             { write a delphi almost compatible dyn. array entry:
               there are two types, eltype and eltype2, the latter is nil if the element type needs
               no finalization, the former is always valid, delphi has this swapped, but for
               compatibility with older fpc versions we do it different, to be delphi compatible,
               the names are swapped in typinfo.pas
             }
             begin
               tcb.begin_anonymous_record(
                 internaltypeprefixName[itp_rtti_dyn_array],
                 defaultpacking,reqalign,
                 targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

               write_common_rtti_data(tcb,def,rt);

               { record in TypInfo is aligned differently from init rtti }
               tcb.begin_anonymous_record(
                 internaltypeprefixName[itp_rtti_dyn_array_inner],
                 defaultpacking,reqalign,
                 targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

               { size of elements }
               tcb.emit_tai(TAIConst.Create_sizeint(def.EleSize),SizeUIntType);
               { element type }
               write_rtti_reference(tcb,def.ElementDef,rt);
               { variant type }
               tcb.emit_ord_const(TStoredDef(def.ElementDef).GetVarDef,S32IntType);
               { element type }
               if def.ElementDef.NeedsInitTable then
                 write_rtti_reference(tcb,def.ElementDef,rt)
               else
                 tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
               { write unit name }
               tcb.emit_shortstring_const(CurrentModule.RealModuleName^);
             end;

          tcb.end_anonymous_record;
          tcb.end_anonymous_record;
        end;

        procedure classrefdef_rtti(def:TClassRefDef);
        begin
          write_header(tcb,def,tkClassRef);
          tcb.begin_anonymous_record(
            internaltypeprefixName[itp_rtti_ref],
            defaultpacking,reqalign,
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          write_common_rtti_data(tcb,def,rt);
          tcb.begin_anonymous_record(
            internaltypeprefixName[itp_rtti_classref],
            defaultpacking,reqalign,
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          write_rtti_reference(tcb,def.PointedDef,rt);
          tcb.end_anonymous_record;
          tcb.end_anonymous_record;
        end;

        procedure pointerdef_rtti(def:TPointerDef);
        begin
          write_header(tcb,def,tkPointer);
          tcb.begin_anonymous_record(
            internaltypeprefixName[itp_rtti_ref],
            defaultpacking,reqalign,
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          write_common_rtti_data(tcb,def,rt);
          tcb.begin_anonymous_record(
            internaltypeprefixName[itp_rtti_pointer],
            defaultpacking,reqalign,
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          write_rtti_reference(tcb,def.PointedDef,rt);
          tcb.end_anonymous_record;
          tcb.end_anonymous_record;
        end;

        procedure recorddef_rtti(def:TRecordDef);

          procedure write_record_operators(rttilab:TAsmLabel);
          var
            rttidef: TDef;
            tcb: TTAITypedConstBuilder;
            mop: TManagementOperator;
            procdef: TProcDef;
          begin
            tcb:=CTAITypedConstBuilder.create([tcalo_make_dead_strippable]);

            tcb.begin_anonymous_record(
              '',
              defaultpacking,min(reqalign,SizeOf(PInt)),
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin
            );

            { use "succ" to omit first enum item "mop_none" }
            for mop := succ(low(TManagementOperator)) to high(TManagementOperator) do
            begin
              if not (mop in TRecordSymTable(def.SymTable).ManagementOperators) then
                tcb.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType)
              else
                begin
                  procdef := Search_Management_Operator(mop, def);
                  if procdef = nil then
                    InternalError(201603021)
                  else
                    tcb.emit_tai(TAIConst.Createname(procdef.MangledName,AT_FUNCTION,0),
                      CProcVarDef.GetReusableProcAddr(procdef,pc_address_only));
                end;
            end;

            rttidef := tcb.end_anonymous_record;

            CurrentAsmData.AsmLists[al_rtti].ConcatList(
              tcb.get_final_asmlist(rttilab,rttidef,sec_rodata,rttilab.name,
              sizeof(PInt)));
            tcb.free;
            tcb := nil;
          end;


          procedure write_extended_property_table;
          var
            propnamelist: TFPHashObjectList;
            visibilities: TVisibilities;
          begin
            propnamelist:=TFPHashObjectList.Create;
            visibilities:=def.RTTI_Visibilities_For_Option(ro_properties);
            collect_propnamelist(propnamelist,def,visibilities);
            properties_write_rtti_data(tcb,propnamelist,def.SymTable,true,visibilities);
            propnamelist.free;
            propnamelist := nil;
          end;

        var
          oplab : TAsmLabel;

        begin
           write_header(tcb,def,tkRecord);
           { need extra reqalign record, because otherwise the u32 int will
             only be aligned to 4 even on 64 bit target (while the rtti code
             in typinfo expects alignments to sizeof(pointer)) }
           tcb.begin_anonymous_record('',
             defaultpacking,reqalign,
             targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

           write_common_rtti_data(tcb,def,rt);

           tcb.begin_anonymous_record('',
             defaultpacking,reqalign,
             targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
           { store special terminator for init table for more optimal rtl operations
             strictly related to RecordRTTI procedure in rtti.inc (directly
             related to RTTIRecordRttiInfoToInitInfo function) }
           if rt=initrtti then
             tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType)
           else
             { we use a direct reference as the init RTTI is always in the same
               unit as the full RTTI }
             tcb.emit_tai(TAIConst.Create_sym(get_rtti_label(def,initrtti,false)),VoidPointerType);

           tcb.emit_ord_const(def.size,U32IntType);

           oplab:=nil;
           { store rtti management operators only for init table }
           if rt=initrtti then
             begin
               { for now records don't have the initializer table }
               tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
               if (TRecordSymTable(def.SymTable).ManagementOperators=[]) then
                 tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType)
               else
                 begin
                   CurrentAsmData.getlocaldatalabel(oplab);
                   tcb.emit_tai(TAIConst.Createname(
                     oplab.name,
                     AT_DATA_FORCEINDIRECT,0),VoidPointerType);
                 end;
             end;

           fields_write_rtti_data(tcb,def,rt);
           { write extended rtti }
           if rt=fullrtti then
             begin
               write_extended_field_table(tcb,def,defaultpacking);
               write_extended_method_table(tcb,def,defaultpacking);
               write_extended_property_table;
             end;
           tcb.end_anonymous_record;
           tcb.end_anonymous_record;

           { write pointers to operators if needed }
           if (rt=initrtti) and (TRecordSymTable(def.SymTable).ManagementOperators<>[]) then
             write_record_operators(oplab);
        end;


        procedure procvardef_rtti(def:TProcVarDef);

           procedure write_para(parasym:TParaVarSym);
             begin
               { write flags for current parameter }
               write_param_flag(tcb,parasym);
               { write name of current parameter }
               tcb.emit_shortstring_const(parasym.realname);
               { write name of type of current parameter }
               write_rtti_name(tcb,parasym.vardef);
             end;

           procedure write_procedure_param(parasym:TParaVarSym);
             begin
               { every parameter is expected to start aligned }
               tcb.begin_anonymous_record(
                 internaltypeprefixName[itp_rtti_proc_param]+ToStr(length(parasym.realname)),
                 defaultpacking,min(reqalign,SizeOf(PInt)),
                 targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
               { write flags for current parameter }
               write_param_flag(tcb,parasym);
               { write param type }
               if is_open_array(parasym.vardef) or is_array_of_const(parasym.vardef) then
                 write_rtti_reference(tcb,TArrayDef(parasym.vardef).ElementDef,fullrtti)
               else if parasym.vardef=CFormalType then
                 write_rtti_reference(tcb,nil,fullrtti)
               else
                 write_rtti_reference(tcb,parasym.vardef,fullrtti);
               { write name of current parameter }
               tcb.emit_shortstring_const(parasym.realname);
               tcb.end_anonymous_record;
             end;

        var
          methodkind : byte;
          i : integer;
        begin
          if po_methodpointer in def.ProcOptions then
            begin
               { write method id and name }
               write_header(tcb,def,tkMethod);
               tcb.begin_anonymous_record('',defaultpacking,reqalign,
                 targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

               write_common_rtti_data(tcb,def,rt);

               tcb.begin_anonymous_record('',
                 defaultpacking,reqalign,
                 targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
               { write kind of method }
               methodkind:=write_methodkind(tcb,def);

               { write parameter info. The parameters must be written in reverse order
                 if this method uses right to left parameter pushing! }
               tcb.emit_ord_const(def.paras.count,U8IntType);

               for i:=0 to def.paras.count-1 do
                 write_para(TParaVarSym(def.paras[i]));

               if (methodkind=mkFunction) or (methodkind=mkClassFunction) then
               begin
                 { write name of result type }
                 write_rtti_name(tcb,def.ReturnDef);
                 { enclosing record takes care of alignment }
                 { write result typeinfo }
                 write_rtti_reference(tcb,def.ReturnDef,fullrtti);
               end;

               { write calling convention }
               write_callconv(tcb,def);

               { enclosing record takes care of alignment }
               { write params typeinfo }
               for i:=0 to def.paras.count-1 do
                 begin
                   if is_open_array(TParaVarSym(def.paras[i]).vardef) or is_array_of_const(TParaVarSym(def.paras[i]).vardef) then
                     write_rtti_reference(tcb,TArrayDef(TParaVarSym(def.paras[i]).vardef).ElementDef,fullrtti)
                   else if TParaVarSym(def.paras[i]).vardef=CFormalType then
                     write_rtti_reference(tcb,nil,fullrtti)
                   else
                     write_rtti_reference(tcb,TParaVarSym(def.paras[i]).vardef,fullrtti);
                 end;
               tcb.end_anonymous_record;
               tcb.end_anonymous_record;
            end
          else
            begin
              write_header(tcb,def,tkProcvar);
              tcb.begin_anonymous_record('',defaultpacking,reqalign,
                targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

              write_common_rtti_data(tcb,def,rt);

              tcb.begin_anonymous_record('',
                defaultpacking,reqalign,
                targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
              { flags }
              tcb.emit_ord_const(0,U8IntType);
              { write calling convention }
              write_callconv(tcb,def);
              { enclosing record takes care of alignment }
              { write result typeinfo }
              write_rtti_reference(tcb,def.ReturnDef,fullrtti);
              { write parameter count }
              tcb.emit_ord_const(def.paras.count,U8IntType);
              for i:=0 to def.paras.count-1 do
                write_procedure_param(TParaVarSym(def.paras[i]));
              tcb.end_anonymous_record;
              tcb.end_anonymous_record;
            end;
        end;


        procedure objectdef_rtti(def: TObjectDef);

          procedure objectdef_rtti_fields(def:TObjectDef);
          begin
            maybe_add_comment(tcb,'RTTI begin fields '+def.ObjName^);
            tcb.begin_anonymous_record('',defaultpacking,reqalign,
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

            { - for compatiblity with record RTTI we need to write a terminator-
                Nil pointer for initrtti as well for objects
              - for RTTI consistency for objects we need point from fullrtti
                to initrtti
              - classes are assumed to have the same INIT RTTI as records
                (see TObject.CleanupInstance)
              - neither helper nor class type have fullrtti for fields
            }
            if (rt=initrtti) then
              tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType)
            else
              if (def.ObjectType=odt_object) then
                tcb.emit_tai(TAIConst.Create_sym(get_rtti_label(def,initrtti,false)),VoidPointerType)
              else
                InternalError(2017011801);

            tcb.emit_ord_const(def.size, U32IntType);
            { pointer to management operators available only for initrtti }
            if (rt=initrtti) then
              begin
                { initializer table only available for classes currently }
                if def.ObjectType=odt_class then
                  write_mop_offset_table(tcb,def,mop_initialize)
                else
                  tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
                tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
              end;
            { enclosing record takes care of alignment }
            fields_write_rtti_data(tcb,def,rt);

            tcb.end_anonymous_record;
            maybe_add_comment(tcb,'RTTI end fields '+def.ObjName^);
          end;

          procedure objectdef_rtti_interface_init(def:TObjectDef);
          begin
            tcb.emit_ord_const(def.size, U32IntType);
          end;

          procedure objectdef_extended_rtti_class(def:TObjectDef);
          var
            propnamelist : TFPHashObjectList;
            visibilities : TVisibilities;
          begin
            propnamelist:=TFPHashObjectList.Create;
            visibilities:=def.RTTI_Visibilities_For_Option(ro_properties);
            collect_propnamelist(propnamelist,def,visibilities);
            properties_write_rtti_data(tcb,propnamelist,def.SymTable,true,visibilities);
            propnamelist.free;
            propnamelist := nil;
          end;

          procedure objectdef_rtti_class_full(def:TObjectDef);
          var
            propnamelist : TFPHashObjectList;
          begin
            { Collect unique property names with nameindex }
            propnamelist:=TFPHashObjectList.Create;
            collect_propnamelist(propnamelist,def,[vis_published]);

            tcb.begin_anonymous_record('',defaultpacking,reqalign,
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

            if not Is_ObjectPascal_Helper(def) then
              begin
              maybe_add_comment(tcb,#9'Parent type info');
              if (oo_has_vmt in def.ObjectOptions) then
                tcb.emit_tai(
                  TAIConst.Createname(def.VMT_MangledName,AT_DATA_FORCEINDIRECT,0),
                  CPointerDef.getreusable(def.VMT_Def))
              else
                tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
              end;
            { write parent typeinfo }
            maybe_add_comment(tcb,#9'Parent type info');
            write_rtti_reference(tcb,def.ChildOf,fullrtti);

            { write typeinfo of extended type }
            if Is_ObjectPascal_Helper(def) then
              if Assigned(def.ExtendedDef) then
                begin
                maybe_add_comment(tcb,#9'helper for type info');
                write_rtti_reference(tcb,def.ExtendedDef,fullrtti)
                end
              else
                InternalError(2011033001);

            { total number of unique properties }

            maybe_add_comment(tcb,#9'Number of properties');
            tcb.emit_ord_const(propnamelist.count,U16IntType);

            { write unit name }

            maybe_add_comment(tcb, #9'Unit name');
            tcb.emit_shortstring_const(CurrentModule.RealModuleName^);

            { write published properties for this object }
            properties_write_rtti_data(tcb,propnamelist,def.SymTable,false,[vis_published]);

            { write extended properties }
            objectdef_extended_rtti_class(def);

            tcb.end_anonymous_record;

            propnamelist.free;
            propnamelist := nil;
          end;

          procedure objectdef_rtti_interface_full(def:TObjectDef);
          var
            propnamelist : TFPHashObjectList;
            { if changed to a set, make sure it's still a byte large, and
              swap appropriately when cross-compiling
            }
            IntfFlags: byte;
          begin
            { Collect unique property names with nameindex }
            propnamelist:=TFPHashObjectList.Create;
            collect_propnamelist(propnamelist,def,[vis_published]);

            tcb.begin_anonymous_record('',defaultpacking,reqalign,
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

            { write parent typeinfo }
            write_rtti_reference(tcb,def.ChildOf,fullrtti);

            { interface: write flags, iid and iidstr }
            IntfFlags:=0;
            if Assigned(def.IIDGUID) then
              IntfFlags:=IntfFlags or (1 shl ord(ifHasGuid));
            if (def.ObjectType=odt_interfacecorba) and (def.IIDStr^<>'') then
              IntfFlags:=IntfFlags or (1 shl ord(ifHasStrGUID));
            if (def.ObjectType=odt_dispinterface) then
              IntfFlags:=IntfFlags or (1 shl ord(ifDispInterface));
            if (TargetInfo.endian=endian_big) then
              IntfFlags:=Reverse_Byte(IntfFlags);
              {
              ifDispatch, }
            tcb.emit_ord_const(IntfFlags,U8IntType);

            { write GUID }
            tcb.emit_guid_const(def.IIDGUID^);

            { write hidden class reference - if it is nil, write_rtti_reference writes nil }
            write_rtti_reference(tcb,def.HiddenClassDef,fullrtti);

            { write unit name }
            tcb.emit_shortstring_const(CurrentModule.RealModuleName^);

            tcb.begin_anonymous_record('',defaultpacking,reqalign,
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

            { write iidstr }
            if def.ObjectType=odt_interfacecorba then
              begin
                { prepareguid always allocates an empty string }
                if not Assigned(def.IIDStr) then
                  InternalError(2016021901);
                tcb.emit_shortstring_const(def.IIDStr^)
              end;

            { write published properties for this object }
            properties_write_rtti_data(tcb,propnamelist,def.SymTable,false,[vis_published]);

            { write published methods for this interface }
            write_methods(tcb,def.SymTable,false,[vis_published]);

            tcb.end_anonymous_record;
            tcb.end_anonymous_record;

            propnamelist.free;
            propnamelist := nil;
          end;

        begin
           case def.ObjectType of
             odt_class:
               tcb.emit_ord_const(tkclass,U8IntType);
             odt_object:
               tcb.emit_ord_const(tkobject,U8IntType);
             odt_dispinterface,
             odt_interfacecom:
               tcb.emit_ord_const(tkInterface,U8IntType);
             odt_interfacecorba:
               tcb.emit_ord_const(tkinterfaceCorba,U8IntType);
             odt_helper:
               tcb.emit_ord_const(tkhelper,U8IntType);
             else
               InternalError(200611034);
           end;

           { generate the name }
           tcb.emit_shortstring_const(def.ObjRealName^);

           tcb.begin_anonymous_record('',defaultpacking,reqalign,
             targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

           write_common_rtti_data(tcb,def,rt);

           case rt of
             initrtti :
               begin
                 if def.ObjectType in [odt_class,odt_object,odt_helper] then
                   objectdef_rtti_fields(def)
                 else
                   objectdef_rtti_interface_init(def);
               end;
             fullrtti :
               begin
                 tcb.begin_anonymous_record('',
                   defaultpacking,reqalign,
                   targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
                 case def.ObjectType of
                   odt_helper,
                   odt_class:
                     objectdef_rtti_class_full(def);
                   odt_object:
                     objectdef_rtti_fields(def);
                 else
                   objectdef_rtti_interface_full(def);
                 end;
                 tcb.end_anonymous_record;
               end;
             else
               ;
           end;
           tcb.end_anonymous_record;
        end;

      begin
        case def.typ of
          variantdef :
            variantdef_rtti(TVariantDef(def));
          stringdef :
            stringdef_rtti(TStringDef(def));
          enumdef :
            enumdef_rtti(TEnumDef(def));
          orddef :
            orddef_rtti(TOrdDef(def));
          floatdef :
            floatdef_rtti(TFloatDef(def));
          setdef :
            setdef_rtti(TSetDef(def));
          procvardef :
            procvardef_rtti(TProcVarDef(def));
          arraydef :
            begin
              if ado_IsBitPacked in TArrayDef(def).ArrayOptions then
                unknown_rtti(TStoredDef(def))
              else
                arraydef_rtti(TArrayDef(def));
            end;
          recorddef :
            begin
              if TRecordDef(def).Is_Packed then
                unknown_rtti(TStoredDef(def))
              else
                recorddef_rtti(TRecordDef(def));
            end;
          objectdef :
            objectdef_rtti(TObjectDef(def));
          classrefdef :
            classrefdef_rtti(TClassRefDef(def));
          pointerdef :
            pointerdef_rtti(TPointerDef(def));
          else
            unknown_rtti(TStoredDef(def));
        end;
      end;

  procedure TRTTIWriter.write_attribute_data(tcb:TTAITypedConstBuilder;attr_list:TRTTIAttributeList);

    procedure write_args(tbltcb:TTAITypedConstBuilder;attr:TRTTIAttribute);
      var
        argtcb : TTAITypedConstBuilder;
        arglab : TAsmLabel;
        argdef : TDef;
        i : sizeint;
      begin
        if length(attr.paras)=0 then
          begin
            tbltcb.emit_tai(TAIConst.Create_16bit(0),U16IntType);
            tbltcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
          end
        else
          begin
            CurrentAsmData.getglobaldatalabel(arglab);

            argtcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_make_dead_strippable]);

            argtcb.begin_anonymous_record('',defaultpacking,min(reqalign,SizeOf(PInt)),
              targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);

            for i:=0 to High(attr.paras) do
              begin
                case attr.paras[i].nodetype of
                  niln,
                  ordconstn,
                  realconstn,
                  stringconstn,
                  pointerconstn,
                  guidconstn:
                    TConstNode(attr.paras[i]).emit_data(argtcb);
                  setconstn:
                    TSetConstNode(attr.paras[i]).emit_data(argtcb);
                  else
                    InternalError(2019070803);
                end;
              end;

            argdef:=argtcb.end_anonymous_record;

            CurrentAsmData.asmlists[al_rtti].ConcatList(
              argtcb.get_final_asmlist(arglab,argdef,sec_rodata,arglab.name,Const_Align(sizeof(PInt)))
            );

            argtcb.free;
            argtcb := nil;

            { write argument size and the reference to the argument entry }
            tbltcb.emit_ord_const(argdef.size,U16IntType);
            tbltcb.emit_tai(TAIConst.Create_sym(arglab),VoidPointerType);
          end;
      end;

    var
      count,i: word;
      attr : TRTTIAttribute;
      tbltcb : TTAITypedConstBuilder;
      tbllab : TAsmLabel;
      tbldef : TDef;
    begin
      if Assigned(attr_list) then
        count:=attr_list.GetAttributeCount
      else
        count:=0;

      if count=0 then
        begin
          { write a Nil reference }
          tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
          exit;
        end;

      { first write the attribute list as a separate table }
      CurrentAsmData.getglobaldatalabel(tbllab);

      tbltcb:=CTAITypedConstBuilder.create([tcalo_is_lab,tcalo_make_dead_strippable]);

      tbltcb.begin_anonymous_record(
        internaltypeprefixName[itp_rtti_attr_list]+ToStr(count),
        defaultpacking,min(reqalign,SizeOf(PInt)),
        targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
      tbltcb.emit_ord_const(count,U16IntType);
      for i:=0 to count-1 do
        begin
          tbltcb.begin_anonymous_record(internaltypeprefixName[itp_rtti_attr_entry],defaultpacking,min(reqalign,SizeOf(PInt)),
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          attr:=TRTTIAttribute(attr_list.RTTIAttributes[i]);

          write_rtti_reference(tbltcb,TTypeSym(attr.TypeSym).typedef,fullrtti);

          tbltcb.emit_procdef_const(TProcDef(TCallNode(attr.ConstructorCall).procdefinition));

          if not Assigned(attr.ConstructorPD) then
            InternalError(2019071004);
          tbltcb.emit_procdef_const(TProcDef(attr.ConstructorPD));

          write_args(tbltcb,attr);

          tbltcb.end_anonymous_record;
        end;
      tbldef:=tbltcb.end_anonymous_record;

      CurrentAsmData.asmlists[al_rtti].ConcatList(
        tbltcb.get_final_asmlist(tbllab,tbldef,sec_rodata,tbllab.name,Const_Align(sizeof(PInt)))
      );

      tbltcb.free;
      tbltcb := nil;

      { write the reference to the attribute table }
      tcb.emit_tai(TAIConst.Create_sym(tbllab),VoidPointerType);
    end;


    function enumsym_compare_name(item1, item2: pointer): Integer;
      var
        enum1: TEnumSym absolute item1;
        enum2: TEnumSym absolute item2;
      begin
        if enum1=enum2 then
          result:=0
        else if enum1.name>enum2.name then
          result:=1
        else
          { there can't be equal names, identifiers are unique }
          result:=-1;
      end;


    function enumsym_compare_value(item1, item2: pointer): Integer;
      var
        enum1: TEnumSym absolute item1;
        enum2: TEnumSym absolute item2;
      begin
        if enum1.value>enum2.value then
          result:=1
        else if enum1.value<enum2.value then
          result:=-1
        else
          result:=0;
      end;


    procedure TRTTIWriter.write_rtti_extrasyms(def:TDef;rt:TRTTIType;mainrtti:TAsmSymbol);

        type Penumsym = ^TEnumSym;

        { Writes a helper table for accelerated conversion of ordinal enum values to strings.
          If you change something in this method, make sure to adapt the corresponding code
          in sstrings.inc. }
        procedure enumdef_rtti_ord2stringindex(rttidef: TRecordDef; const syms: TFPList);

        var rttilab:TAsmSymbol;
            h,i,o,prev_value:LongInt;
            mode:(lookup,search); {Modify with care, ordinal value of enum is written.}
            r:single;             {Must be real type because of integer overflow risk.}
            tcb: TTAITypedConstBuilder;
            sym_count: integer;
            tabledef: TDef;
        begin

          {Decide wether a lookup array is size efficient.}
          mode:=lookup;
          sym_count:=syms.count;
          if sym_count>0 then
            begin
              i:=1;
              r:=0;
              h:=TEnumSym(syms[0]).value; {Next expected enum value is min.}
              { set prev_value for the first iteration to a value that is
                different from the first one without risking overflow (it's used
                to detect whether two enum values are the same) }
              if h=0 then
                prev_value:=1
              else
                prev_value:=0;
              while i<sym_count do
                begin
                  { if two enum values are the same, we have to create a table }
                  if (prev_value=h) then
                    begin
                      mode:=search;
                      break;
                    end;
                  {Calculate size of hole between values. Avoid integer overflows.}
                  r:=r+(single(TEnumSym(syms[i]).value)-single(h))-1;
                  prev_value:=h;
                  h:=TEnumSym(syms[i]).value;
                  inc(i);
                end;
              if r>sym_count then
                mode:=search; {Don't waste more than 50% space.}
            end;
          { write rtti data; make sure that the alignment matches the corresponding data structure
            in the code that uses it (if alignment is required). }
          tcb:=CTAITypedConstBuilder.create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);
          { use TConstPtrUInt packrecords to ensure good alignment }
          tcb.begin_anonymous_record('',defaultpacking,reqalign,
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          { now emit the data: first the mode }
          tcb.emit_tai(TAIConst.create_32bit(LongInt(mode)),U32IntType);
          { align }
          tcb.begin_anonymous_record('',defaultpacking,min(reqalign,sizeof(PInt)),
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          if mode=lookup then
            begin
              o:=TEnumSym(syms[0]).value;  {Start with min value.}
              for i:=0 to sym_count-1 do
                begin
                  while o<TEnumSym(syms[i]).value do
                    begin
                      tcb.emit_tai(TAIConst.create_nil_dataptr,PtrUIntType);
                      inc(o);
                    end;
                  inc(o);
                  tcb.queue_init(VoidPointerType);
                  tcb.queue_subscriptn_multiple_by_name(rttidef,
                    ['size_start_rec',
                      'typ_union_rec',
                      'min_max_rec',
                      'basetype_array_rec',
                      TSym(syms[i]).Name]
                  );
                  tcb.queue_emit_asmsym(mainrtti,rttidef);
                end;
            end
          else
            begin
              tcb.emit_ord_const(sym_count,U32IntType);
              tcb.begin_anonymous_record('',defaultpacking,min(reqalign,sizeof(PInt)),
                targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
              for i:=0 to sym_count-1 do
                begin
                  tcb.emit_ord_const(TEnumSym(syms[i]).value,S32IntType);
                  tcb.queue_init(VoidPointerType);
                  tcb.queue_subscriptn_multiple_by_name(rttidef,
                    ['size_start_rec',
                      'typ_union_rec',
                      'min_max_rec',
                      'basetype_array_rec',
                      TSym(syms[i]).Name]
                  );
                  tcb.queue_emit_asmsym(mainrtti,rttidef);
                end;
              tcb.end_anonymous_record;
            end;
            tcb.end_anonymous_record;

            tabledef:=tcb.end_anonymous_record;
            rttilab:=CurrentAsmData.DefineAsmSymbol(TStoredDef(def).RTTIMangledName(rt)+'_o2s',AB_GLOBAL,AT_DATA_NOINDIRECT,tabledef);
            CurrentAsmData.asmlists[al_rtti].ConcatList(tcb.get_final_asmlist(
              rttilab,tabledef,sec_rodata,
              rttilab.name,sizeof(PInt)));
            tcb.free;
            tcb := nil;

            CurrentModule.Add_Public_AsmSym(rttilab);
        end;


        { Writes a helper table for accelerated conversion of string to ordinal enum values.
          If you change something in this method, make sure to adapt the corresponding code
          in sstrings.inc. }
        procedure enumdef_rtti_string2ordindex(rttidef: TRecordDef; const syms: TFPList);

        var
          tcb: TTAITypedConstBuilder;
          rttilab: TAsmSymbol;
          i:LongInt;
          tabledef: TDef;
        begin
          { write rtti data }
          tcb:=CTAITypedConstBuilder.create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);
          { begin of Tstring_to_ord }
          tcb.begin_anonymous_record('',defaultpacking,min(reqalign,sizeof(PInt)),
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          tcb.emit_ord_const(syms.count,S32IntType);
          { begin of "data" array in Tstring_to_ord }
          tcb.begin_anonymous_record('',defaultpacking,min(reqalign,sizeof(PInt)),
            targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin);
          for i:=0 to syms.count-1 do
            begin
              tcb.emit_ord_const(TEnumSym(syms[i]).value,S32IntType);
              { alignment of pointer value handled by enclosing record already }
              tcb.queue_init(VoidPointerType);
              tcb.queue_subscriptn_multiple_by_name(rttidef,
                ['size_start_rec',
                  'typ_union_rec',
                  'min_max_rec',
                  'basetype_array_rec',
                  TSym(syms[i]).Name]
              );
              tcb.queue_emit_asmsym(mainrtti,rttidef);
            end;
          tcb.end_anonymous_record;
          tabledef:=tcb.end_anonymous_record;
          rttilab:=CurrentAsmData.DefineAsmSymbol(TStoredDef(def).RTTIMangledName(rt)+'_s2o',AB_GLOBAL,AT_DATA_NOINDIRECT,tabledef);
          CurrentAsmData.asmlists[al_rtti].ConcatList(tcb.get_final_asmlist(
            rttilab,tabledef,sec_rodata,
            rttilab.name,sizeof(PInt)));
          tcb.free;
          tcb := nil;

          CurrentModule.Add_Public_AsmSym(rttilab);
        end;

        procedure enumdef_rtti_extrasyms(def:TEnumDef);
        var
          t:TEnumSym;
          syms:TFPList;
          i:LongInt;
          rttitypesym: TTypeSym;
          rttidef: TRecordDef;
          s:TIDString;
        begin
          { collect enumsyms belonging to this enum type (could be a subsection
            in case of a subrange type) }
          syms:=TFPList.create;
          for i := 0 to def.SymTable.SymList.Count - 1 do
            begin
              t:=TEnumSym(def.SymTable.SymList[i]);
              if t.value<def.MinVal then
                continue
              else
              if t.value>def.MaxVal then
                break;
              syms.add(t);
            end;
          { sort the syms by enum name }
          syms.sort(@enumsym_compare_name);
          s:=internaltypeprefixName[itp_rttidef]+def.RTTIMangledName(fullrtti);
          rttitypesym:=Try_Search_Current_Module_Type(s);
          if not Assigned(rttitypesym) or
             (TTypeSym(rttitypesym).typedef.typ<>recorddef) then
            InternalError(2015071402);
          rttidef:=TRecordDef(TTypeSym(rttitypesym).typedef);
          enumdef_rtti_string2ordindex(rttidef,syms);
          { sort the syms by enum value }
          syms.sort(@enumsym_compare_value);
          enumdef_rtti_ord2stringindex(rttidef,syms);
          syms.free;
          syms := nil;
        end;


    begin
      case def.typ of
        enumdef:
          if rt=fullrtti then
            begin
              enumdef_rtti_extrasyms(TEnumDef(def));
            end;
        else
          ;
      end;
    end;

    procedure TRTTIWriter.write_child_rtti_data(def:TDef;rt:TRTTIType);
      begin
        case def.typ of
          enumdef :
            if Assigned(TEnumDef(def).BaseDef) then
              write_rtti(TEnumDef(def).BaseDef,rt);
          setdef :
            write_rtti(TSetDef(def).ElementDef,rt);
          arraydef :
            begin
              write_rtti(TArrayDef(def).RangeDef,rt);
              write_rtti(TArrayDef(def).ElementDef,rt);
            end;
          recorddef :
            begin
              { guarantee initrtti for any record for RTTI purposes
                also for fpc_initialize, fpc_finalize }
              if (rt=fullrtti) then
                begin
                  include(def.DefStates,ds_init_table_used);
                  write_rtti(def, initrtti);
                end;
              fields_write_rtti(TRecordDef(def).SymTable,rt);
            end;
          objectdef :
            begin
              if Assigned(TObjectDef(def).ChildOf) then
                write_rtti(TObjectDef(def).ChildOf,rt);
              if (rt=initrtti) or (TObjectDef(def).ObjectType=odt_object) then
                fields_write_rtti(TObjectDef(def).SymTable,rt)
              else
                published_write_rtti(TObjectDef(def),rt);

              if (rt=fullrtti) then
                begin
                  { guarantee initrtti for any object for RTTI purposes
                    also for fpc_initialize, fpc_finalize }
                  if (TObjectDef(def).ObjectType=odt_object) then
                    begin
                      include(def.DefStates,ds_init_table_used);
                      write_rtti(def,initrtti);
                    end;
                  if (Is_Interface(def) or Is_DispInterface(def))
                      and (oo_can_have_published in TObjectDef(def).ObjectOptions) then
                    methods_write_rtti(TObjectDef(def).SymTable,rt,[vis_published],true);
                end;
            end;
          classrefdef,
          pointerdef:
            if not Is_ObjC_Class_Or_Protocol(TAbstractPointerDef(def).PointedDef) then
              write_rtti(TAbstractPointerDef(def).PointedDef,rt);
          procvardef:
            params_write_rtti(TAbstractProcDef(def),rt,false);
          else
            ;
        end;
      end;

    procedure TRTTIWriter.write_rtti_reference(tcb: TTAITypedConstBuilder; def: TDef; rt: TRTTIType);
      begin
        { we don't care about the real type here, because
           a) we don't index into these elements
           b) we may not have the rtti type available at the point that we
              are emitting this data, because of forward definitions etc
           c) if the rtti is emitted in another unit, we won't have the type
              available at all
          For the cases where the type is emitted in the current unit and hence
          the underlying system will detect and complain about symbol def
          mismatches, type conversions will have to be inserted afterwards (like
          in llvm/llvmtype)
        }
        if not Assigned(def) or is_void(def) or ((rt<>initrtti) and Is_ObjC_Class_Or_Protocol(def)) then
          tcb.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType)
        else
          tcb.emit_tai(TAIConst.Create_sym(get_rtti_label(def,rt,true)),VoidPointerType);
      end;


    function TRTTIWriter.ref_rtti(def:TDef;rt:TRTTIType;indirect:boolean;suffix:TSymStr):TAsmSymbol;
      var
        s : TSymStr;
      begin
        s:=def.RTTIMangledName(rt)+suffix;
        result:=CurrentAsmData.RefAsmSymbol(s,AT_DATA,indirect);
        if def.owner.ModuleID<>CurrentModule.ModuleID then
          CurrentModule.Add_Extern_AsmSym(s,AB_EXTERNAL,AT_DATA);
      end;

    procedure TRTTIWriter.write_rtti(def:TDef;rt:TRTTIType);

      var
        tcb: TTAITypedConstBuilder;
        opts : TTCAsmListOptions;
        rttilab: TAsmSymbol;
        rttidef: TDef;
        s: TIDString;
      begin
        { Objective-C has its own RTTI system }
        if Is_ObjC_Class_Or_Protocol(def) then
          exit;

        { only write rtti of definitions from the current module }
        if not FindUnitSymTable(def.owner).IsCurrentUnit then
          exit;
        { check if separate initrtti is actually needed }
        if (rt=initrtti) and (not def.NeedsSeparateInitRTTI) then
          rt:=fullrtti;
        { prevent recursion }
        if rttidefstate[rt] in def.DefStates then
          exit;
        include(def.DefStates,rttidefstate[rt]);

        { write first all dependencies }
        write_child_rtti_data(def,rt);
        { write rtti data }
        tcb:=CTAITypedConstBuilder.create([tcalo_make_dead_strippable,tcalo_data_force_indirect]);
        s:=internaltypeprefixName[itp_rttidef]+TStoredDef(def).RTTIMangledName(rt);

        maybe_add_comment(tcb,'RTTI: begin Type '+def.GetTypeName+' ('+rttitypenames[rt]+')');
        tcb.begin_anonymous_record(
          s,
          defaultpacking,reqalign,
          targetinfos[Ord(TargetInfo.system)]^.alignment.RecordAlignMin
        );
        write_rtti_data(tcb,def,rt);
        rttidef:=tcb.end_anonymous_record;
        maybe_add_comment(tcb,'RTTI: end Type '+def.GetTypeName+' ('+rttitypenames[rt]+')');
        rttilab:=CurrentAsmData.DefineAsmSymbol(TStoredDef(def).RTTIMangledName(rt),AB_GLOBAL,AT_DATA_NOINDIRECT,rttidef);
        CurrentAsmData.AsmLists[al_rtti].ConcatList(
          tcb.get_final_asmlist(rttilab,rttidef,sec_rodata,rttilab.name,min(TargetInfo.alignment.MaxCRecordAlign,SizeOf(QWord))));
        tcb.free;
        tcb := nil;

        CurrentModule.Add_Public_AsmSym(rttilab);

        { write additional data }
        write_rtti_extrasyms(def,rt,rttilab);
      end;

    procedure TRTTIWriter.maybe_add_comment(tcb:TTAITypedConstBuilder;const comment : string);

      begin
        if addcomments then
          tcb.emit_comment(comment);
      end;

    constructor TRTTIWriter.create;
      begin
        addcomments:=cs_asm_rtti_source in CurrentSettings.GlobalSwitches;
        if tf_requires_proper_alignment in TargetInfo.flags then
          begin
            reqalign:=min(sizeof(QWord),TargetInfo.alignment.MaxCRecordAlign);
            defaultpacking:=C_alignment;
          end
        else
          begin
            reqalign:=1;
            defaultpacking:=1;
          end;
      end;


end.

