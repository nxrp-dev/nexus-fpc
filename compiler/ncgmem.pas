{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate assembler for memory related nodes which are
    the same for all (most?) processors

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
unit ncgmem;

{$i fpcdefs.inc}

interface

    uses
      GlobType,cgbase,cgutils,cpubase,
      symtype,
      node,nmem;

    type
       TCGLoadVMTAddrNode = class(TLoadVMTAddrNode)
          procedure pass_generate_code;override;
       end;

       TCGLoadParentFPNode = class(TLoadParentFPNode)
          procedure pass_generate_code;override;
       end;

       TCGAddrNode = class(TAddrNode)
          procedure pass_generate_code;override;
       end;

       TCGDerefNode = class(TDerefNode)
          procedure pass_generate_code;override;
       end;

       TCGSubscriptNode = class(TSubscriptNode)
         protected
          function handle_platform_subscript: boolean; virtual;
         public
          procedure pass_generate_code;override;
       end;

       TCGVecNode = class(TVecNode)
         function get_mul_size : asizeint;
       private
         procedure rangecheck_array;
         procedure rangecheck_string;
       protected
         function get_address_type: TDef;virtual;
         {# This routine is used to calculate the address of the reference.
            On entry reg contains the index in the array,
           and l contains the size of each element in the array.
           This routine should update location.reference correctly,
           so it points to the correct address.
         }
         procedure update_reference_reg_mul(maybe_const_reg: TRegister;regsize: TDef; l: aint);virtual;
         procedure update_reference_reg_packed(maybe_const_reg: TRegister; regsize: TDef; l: aint);virtual;
         procedure update_reference_offset(var ref: TReference; index, mulsize: ASizeInt); virtual;
         procedure second_wideansistring;virtual;
         procedure second_dynamicarray;virtual;
         function valid_index_size(size: TCgSize): boolean;virtual;
       public
         procedure pass_generate_code;override;
       end;


implementation

    uses
      Systems,
      CUtils,CClasses,Verbose,Globals,ConstExp,FModule,
      symconst,SymBase,symdef,SymSym,SymTable,defutil,paramgr,
      aasmbase,AAsmData,
      ProcInfo,pass_2,parabase,
      ncon,nadd,nutils,
      cgobj,hlcgobj,
      objcgutl;


{*****************************************************************************
                              TCGLOADVMTADDRNODE
*****************************************************************************}

    procedure TCGLoadVMTAddrNode.pass_generate_code;
      var
        href    : TReference;
        pool    : THashSet;
        entry   : PHashSetItem;
        vmtname : TSymStr;
        otherunit,
        indirect : boolean;
      begin
         location_reset(location,LOC_REGISTER,def_cgsize(VoidPointerType));
         if (left.nodetype=typen) then
           begin
             location.register:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,VoidPointerType);
             if not Is_ObjCClass(left.resultdef) then
               begin
                 { we are using a direct reference if any of the following is true:
                   - the target does not support packages
                   - the target does not use indirect references
                   - the class is located inside the same unit }
                 otherunit:=FindUnitSymTable(left.resultdef.owner).ModuleID<>CurrentModule.ModuleID;
                 indirect:=(tf_supports_packages in TargetInfo.flags) and
                           (TargetInfo.system in systems_indirect_var_imports) and
                           otherunit;
                 vmtname:=TObjectDef(TClassRefDef(resultdef).PointedDef).VMT_MangledName;
                 reference_reset_symbol(href,
                   CurrentAsmData.RefAsmSymbol(vmtname,AT_DATA,indirect),0,
                   resultdef.alignment,[]);
                 hlcg.a_loadaddr_ref_reg(CurrentAsmData.CurrAsmList,resultdef,resultdef,href,location.register);
                 if otherunit then
                   CurrentModule.Add_Extern_AsmSym(vmtname,AB_EXTERNAL,AT_DATA);
               end
             else
               begin
                 pool:=CurrentAsmData.ConstPools[sp_objcclassnamerefs];
                 entry:=pool.FindOrAdd(@TObjectDef(left.resultdef).ObjExtName^[1],length(TObjectDef(left.resultdef).ObjExtName^));
                 if (TargetInfo.system in systems_objc_nfabi) then
                   begin
                     { find/add necessary classref/classname pool entries }
                     objcfinishclassrefnfpoolentry(entry,TObjectDef(left.resultdef));
                   end
                 else
                   begin
                     { find/add necessary classref/classname pool entries }
                     objcfinishstringrefpoolentry(entry,sp_objcclassnames,sec_objc_cls_refs,sec_objc_class_names);
                   end;
                 reference_reset_symbol(href,TAsmLabel(entry^.Data),0,ObjC_IDType.alignment,[]);
                 hlcg.a_load_ref_reg(CurrentAsmData.CurrAsmList,ObjC_IDType,ObjC_IDType,href,location.register);
               end;
           end
         else
           { should be handled in pass 1 }
           InternalError(2015052801);
      end;


{*****************************************************************************
                        TCGLOADPARENTFPNODE
*****************************************************************************}

    procedure TCGLoadParentFPNode.pass_generate_code;
      var
        currpi : TProcInfo;
        hsym   : TParaVarSym;
        href   : TReference;
      begin
        if (CurrentProcInfo.procdef.ParaST.SymTableLevel=parentpd.ParaST.SymTableLevel) then
          begin
            location_reset(location,LOC_REGISTER,def_cgsize(ParentFPVoidPointerType));
            location.register:=CurrentProcInfo.framepointer;
          end
        else
          begin
            location_reset(location,LOC_REGISTER,def_cgsize(ParentFPVoidPointerType));
            currpi:=CurrentProcInfo;
            { load framepointer of current proc }
            hsym:=TParaVarSym(currpi.procdef.ParentFPSym);
            if (currpi.procdef.owner.SymTableLevel=parentpd.ParaST.SymTableLevel) and (hsym.LocAlloc.loc in [LOC_REGISTER,LOC_CREGISTER]) then
              location.register:=hsym.LocAlloc.register
            else
              begin
                location.register:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,ParentFPVoidPointerType);
                hlcg.a_load_loc_reg(CurrentAsmData.CurrAsmList,ParentFPVoidPointerType,ParentFPVoidPointerType,hsym.LocAlloc,location.register);
                { walk parents }
                while (currpi.procdef.owner.SymTableLevel>parentpd.ParaST.SymTableLevel) do
                  begin
                    currpi:=currpi.parent;
                    if not Assigned(currpi) then
                      InternalError(200311201);
                    hsym:=TParaVarSym(currpi.procdef.ParentFPSym);
                    if hsym.LocAlloc.loc<>LOC_REFERENCE then
                      InternalError(200309283);

                    hlcg.reference_reset_base(href,ParentFPVoidPointerType,location.register,hsym.LocAlloc.reference.offset,ctempposinvalid,ParentFPVoidPointerType.alignment,[]);
                    hlcg.a_load_ref_reg(CurrentAsmData.CurrAsmList,ParentFPVoidPointerType,ParentFPVoidPointerType,href,location.register);
                  end;
              end;
          end;
      end;


{*****************************************************************************
                             TCGADDRNODE
*****************************************************************************}

    procedure TCGAddrNode.pass_generate_code;
      begin
         SecondPass(left);

         location_reset(location,LOC_REGISTER,int_cgsize(resultdef.size));
         location.register:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,resultdef);
         if not(left.location.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
           { on x86_64-win64, array of chars can be returned in registers, however,
             when passing these arrays to other functions, the compiler wants to take
             the address of the array so when the addrnode has been created internally,
             we have to force the data into memory, see also tw14388 (case in tb_arrays_objfpc_run_03.pas).pas
           }
           if nf_internal in flags then
             hlcg.location_force_mem(CurrentAsmData.CurrAsmList,left.location,left.resultdef)
           else
             InternalError(2006111510);
         hlcg.a_loadaddr_ref_reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.location.reference,location.register);
      end;


{*****************************************************************************
                           TCGDEREFNODE
*****************************************************************************}

    procedure TCGDerefNode.pass_generate_code;
      var
        paraloc1 : TCGPara;
        pd : TProcDef;
        sym : TSym;
        st : TSymTable;
        hp : PNode;
        newoffset : TCGInt;
      begin
         sym:=nil;
         { assume natural alignment, except for packed records }
         if not(resultdef.typ in [recorddef,objectdef]) or
            (TAbstractRecordSymTable(TAbstractRecordDef(resultdef).SymTable).UseFieldAlignment<>1) then
           location_reset_ref(location,LOC_REFERENCE,def_cgsize(resultdef),resultdef.alignment,[])
         else
           location_reset_ref(location,LOC_REFERENCE,def_cgsize(resultdef),1,[]);

         { can we fold an add/sub node into the offset of the deref node? }
         newoffset:=0;
         hp:=actualtargetnode(@left);
         if (hp^.nodetype=subn) and is_constintnode(TAddNode(hp^).right) then
           begin
             newoffset:=-TCGInt(TOrdConstNode(TAddNode(hp^).right).value);
             replacenode(hp^,TAddNode(hp^).left);
           end
         else if (hp^.nodetype=addn) and is_constintnode(TAddNode(hp^).right) then
           begin
             newoffset:=TCGInt(TOrdConstNode(TAddNode(hp^).right).value);
             replacenode(hp^,TAddNode(hp^).left);
           end
         else if (hp^.nodetype=addn) and is_constintnode(TAddNode(hp^).left) then
           begin
             newoffset:=TCGInt(TOrdConstNode(TAddNode(hp^).left).value);
             replacenode(hp^,TAddNode(hp^).right);
           end;

         SecondPass(left);

         if not(left.location.loc in [LOC_CREGISTER,LOC_REGISTER,LOC_CREFERENCE,LOC_REFERENCE,LOC_CONSTANT]) then
           hlcg.location_force_reg(CurrentAsmData.CurrAsmList,left.location,left.resultdef,left.resultdef,true);
         case left.location.loc of
            LOC_CREGISTER,
            LOC_REGISTER:
              begin
                hlcg.maybe_change_load_node_reg(CurrentAsmData.CurrAsmList,left,true);
              {$ifdef cpu_uses_separate_address_registers}
                if getregtype(left.location.register)<>R_ADDRESSREGISTER then
                  begin
                    location.reference.base := cg.getaddressregister(CurrentAsmData.CurrAsmList);
                    cg.a_load_reg_reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,left.location.register,
                      location.reference.base);
                  end
                else
              {$endif}
                  location.reference.base := left.location.register;
              end;
            LOC_CREFERENCE,
            LOC_REFERENCE:
              begin
                 location.reference.base:=cg.getaddressregister(CurrentAsmData.CurrAsmList);
                 hlcg.a_load_loc_reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,left.location,location.reference.base);
              end;
            LOC_CONSTANT:
              begin
                inc(newoffset,left.location.value);
              end;
            else
              InternalError(200507031);
         end;
{$ifopt R+}
{$ifdef cpu32bitaddr}
         if (newoffset>high(ASizeUInt)) or (newoffset<low(asizeint)) then
           message(parser_e_range_check_error)
         else
{$endif}
{$endif}
           location.reference.offset:=asizeint(newoffset);
         if (cs_use_heaptrc in CurrentSettings.GlobalSwitches) and
            (cs_checkpointer in CurrentSettings.LocalSwitches) and
            not(cs_compilesystem in CurrentSettings.ModuleSwitches) and
            TPointerDef(left.resultdef).Compatible_With_PointerDef_Size(TPointerDef(VoidPointerType)) and
            not(drnf_no_checkpointer in derefnodeflags) and
            { can be NR_NO in case of LOC_CONSTANT }
            (location.reference.base<>NR_NO) then
          begin
            if not SearchSym_In_Named_Module('HEAPTRC','CHECKPOINTER',sym,st) or
               (sym.typ<>ProcSym) then
              InternalError(2012010601);
            pd:=TProcDef(TProcSym(sym).ProcdefList[0]);
            paraloc1.init;
            paramanager.getcgtempparaloc(CurrentAsmData.CurrAsmList,pd,1,paraloc1);
            hlcg.a_loadaddr_ref_cgpara(CurrentAsmData.CurrAsmList,left.resultdef,location.reference,paraloc1);
            paramanager.freecgpara(CurrentAsmData.CurrAsmList,paraloc1);
            paraloc1.done;
            hlcg.allocallcpuregisters(CurrentAsmData.CurrAsmList);
            hlcg.a_call_name(CurrentAsmData.CurrAsmList,pd,'FPC_CHECKPOINTER',[@paraloc1],nil,false);
            hlcg.deallocallcpuregisters(CurrentAsmData.CurrAsmList);
            include(CurrentSettings.ModuleSwitches,cs_checkpointer_called);
          end;
      end;


{*****************************************************************************
                          TCGSUBSCRIPTNODE
*****************************************************************************}

    function TCGSubscriptNode.handle_platform_subscript: boolean;
      begin
        result:=false;
      end;

    procedure TCGSubscriptNode.pass_generate_code;
      var
        asmsym: TAsmSymbol;
        paraloc1 : TCGPara;
        tmpref: TReference;
        sref: TSubsetReference;
        awordoffset,
        offsetcorrection : aint;
        pd : TProcDef;
        sym : TSym;
        st : TSymTable;
        hreg : TRegister;
      begin
         sym:=nil;
         SecondPass(left);
         if CodeGenError then
           exit;
         paraloc1.init;
         { several object types must be dereferenced implicitly }
         if Is_Implicit_Pointer_Object_Type(left.resultdef) then
           begin
             if not is_managed_type(left.resultdef) then
               begin
                 { take care of the alignment of the fields }
                 if not(left.resultdef is TAbstractRecordDef) then
                   InternalError(2018021601);
                 location_reset_ref(location,LOC_REFERENCE,def_cgsize(resultdef),NewAlignment(TAbstractRecordSymTable(TAbstractRecordDef(left.resultdef).SymTable).RecordAlignment,vs.FieldOffset),[]);
                 case left.location.loc of
                    LOC_CREGISTER,
                    LOC_REGISTER:
                      begin
                      {$ifdef cpu_uses_separate_address_registers}
                        if getregtype(left.location.register)<>R_ADDRESSREGISTER then
                          begin
                            location.reference.base:=cg.getaddressregister(CurrentAsmData.CurrAsmList);
                            hlcg.a_load_reg_reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,
                              left.location.register,location.reference.base);
                          end
                        else
                      {$endif}
                          hlcg.reference_reset_base(location.reference,left.resultdef,left.location.register,0,ctempposinvalid,location.reference.alignment,location.reference.volatility);
                      end;
                    LOC_CREFERENCE,
                    LOC_REFERENCE,
                    { tricky type casting of parameters can cause these locations, see tb0592 (case in tb_classes_objfpc_run_01.pas).pas on x86_64-linux }
                    LOC_SUBSETREG,
                    LOC_CSUBSETREG,
                    LOC_SUBSETREF,
                    LOC_CSUBSETREF:
                      begin
                         hlcg.reference_reset_base(location.reference,left.resultdef,
                           hlcg.getaddressregister(CurrentAsmData.CurrAsmList,left.resultdef),0,ctempposinvalid,location.reference.alignment,location.reference.volatility);
                         hlcg.a_load_loc_reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,left.location,location.reference.base);
                      end;
                    LOC_CONSTANT:
                      begin
                        { can happen with @classtype(pointerconst).field }
                        location.reference.offset:=left.location.value;
                      end;
                    else
                      InternalError(2009092401);
                 end;
                 { implicit deferencing }
                 if (cs_use_heaptrc in CurrentSettings.GlobalSwitches) and
                    (cs_checkpointer in CurrentSettings.LocalSwitches) and
                    not(cs_compilesystem in CurrentSettings.ModuleSwitches) then
                  begin
                    if not SearchSym_In_Named_Module('HEAPTRC','CHECKPOINTER',sym,st) or
                       (sym.typ<>ProcSym) then
                      InternalError(2012010602);
                    pd:=TProcDef(TProcSym(sym).ProcdefList[0]);
                    paramanager.getcgtempparaloc(CurrentAsmData.CurrAsmList,pd,1,paraloc1);
                    hlcg.a_loadaddr_ref_cgpara(CurrentAsmData.CurrAsmList,left.resultdef,location.reference,paraloc1);
                    paramanager.freecgpara(CurrentAsmData.CurrAsmList,paraloc1);
                    hlcg.allocallcpuregisters(CurrentAsmData.CurrAsmList);
                    hlcg.a_call_name(CurrentAsmData.CurrAsmList,pd,'FPC_CHECKPOINTER',[@paraloc1],nil,false);
                    hlcg.deallocallcpuregisters(CurrentAsmData.CurrAsmList);
                    system.include(CurrentSettings.ModuleSwitches,cs_checkpointer_called);
                  end;
               end
             else
               { reference-counted implicit pointer object types don't have
                 fields -> cannot be subscripted (calls are handled via call
                 nodes) }
               InternalError(2011011901);
           end
         else
           begin
             location_copy(location,left.location);
             { some abi's require that functions return (some) records in }
             { registers                                                  }
             case location.loc of
               LOC_REFERENCE,
               LOC_CREFERENCE:
                 ;
               LOC_CONSTANT,
               LOC_REGISTER,
               LOC_CREGISTER,
               { if a floating point value is casted into a record, it
                 can happen that we get here an fpu or mm register }
               LOC_MMREGISTER,
               LOC_FPUREGISTER,
               LOC_CMMREGISTER,
               LOC_CFPUREGISTER:
                 begin
                   { in case the result is not something that can be put
                     into an integer register (e.g.
                     function_returning_record().non_regable_field, or
                     a function returning a value > sizeof(intreg))
                     -> force to memory
                   }

                   if not TStoredDef(left.resultdef).Is_IntRegable or
                      not TStoredDef(resultdef).Is_IntRegable or
                      { if the field spans multiple registers, we must force the record into
                        memory as well }
                      ((left.location.size in [OS_PAIR,OS_SPAIR]) and
                       (vs.FieldOffset div sizeof(aword)<>(vs.FieldOffset+vs.GetSize-1) div sizeof(aword))) or
                      (location.loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER,
                        { actually, we should be able to "subscript" a constant, but this would require some code
                          which enables dumping and reading constants from a temporary memory buffer. This
                          must be done a CPU dependent way, so it is not easy and probably not worth the effort (FK)
                        }
                        LOC_CONSTANT]) then
                     hlcg.location_force_mem(CurrentAsmData.CurrAsmList,location,left.resultdef)
                   else
                     begin
                       if (location.loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                         if (tcgsize2size[location.size]<=tcgsize2size[OS_INT]) then
                           begin
                             hreg:=cg.getintregister(CurrentAsmData.CurrAsmList,location.size);
                             cg.a_loadmm_reg_intreg(CurrentAsmData.CurrAsmList,reg_cgsize(left.location.register),location.size,
                               left.location.register,hreg,mms_movescalar);
                             location_reset(left.location,LOC_REGISTER,int_cgsize(tcgsize2size[left.location.size]));
                             left.location.register:=hreg;
                             { copy again, we changed left.location }
                             location_copy(location,left.location);
                           end
                         else
                           hlcg.location_force_mem(CurrentAsmData.CurrAsmList,location,left.resultdef);

                       if (left.location.loc = LOC_REGISTER) then
                         location.loc := LOC_SUBSETREG
                       else
                         location.loc := LOC_CSUBSETREG;
                       location.size:=def_cgsize(resultdef);

                       offsetcorrection:=0;
                       if (left.location.size in [OS_PAIR,OS_SPAIR]) then
                         begin
                           if not is_packed_record_or_object(left.resultdef) then
                             awordoffset:=sizeof(aword)
                           else
                             awordoffset:=sizeof(aword)*8;

                           if (vs.FieldOffset>=awordoffset) xor (TargetInfo.endian=endian_big) then
                             location.sreg.subsetreg := left.location.registerhi
                           else
                             location.sreg.subsetreg := left.location.register;

                           if vs.FieldOffset>=awordoffset then
                             offsetcorrection := sizeof(aword)*8;

                           location.sreg.subsetregsize := OS_INT;
                         end
                       else
                         begin
                           location.sreg.subsetreg := left.location.register;
                           location.sreg.subsetregsize := left.location.size;
                         end;

                       if not is_packed_record_or_object(left.resultdef) then
                         begin
                           if (TargetInfo.endian = ENDIAN_BIG) then
                             location.sreg.startbit := (tcgsize2size[location.sreg.subsetregsize] - tcgsize2size[location.size] - vs.FieldOffset) * 8+offsetcorrection
                           else
                             location.sreg.startbit := (vs.FieldOffset * 8)-offsetcorrection;
                           location.sreg.bitlen := tcgsize2size[location.size] * 8;
                         end
                       else
                         begin
                           location.sreg.bitlen := resultdef.PackedBitSize;
                           if (TargetInfo.endian = ENDIAN_BIG) then
                             location.sreg.startbit := (tcgsize2size[location.sreg.subsetregsize]*8 - location.sreg.bitlen) - vs.FieldOffset+offsetcorrection
                           else
                             location.sreg.startbit := vs.FieldOffset-offsetcorrection;
                         end;
                     end;
                 end;
               LOC_SUBSETREG,
               LOC_CSUBSETREG:
                 begin
                   location.size:=def_cgsize(resultdef);
                   if not is_packed_record_or_object(left.resultdef) then
                     begin
                       if (TargetInfo.endian = ENDIAN_BIG) then
                         inc(location.sreg.startbit, (left.resultdef.size - tcgsize2size[location.size] - vs.FieldOffset) * 8)
                       else
                         inc(location.sreg.startbit, vs.FieldOffset * 8);
                       location.sreg.bitlen := tcgsize2size[location.size] * 8;
                     end
                   else
                     begin
                       location.sreg.bitlen := resultdef.PackedBitSize;
                       if (TargetInfo.endian = ENDIAN_BIG) then
                         inc(location.sreg.startbit, left.location.sreg.bitlen - location.sreg.bitlen - vs.FieldOffset)
                       else
                         inc(location.sreg.startbit, vs.FieldOffset);
                     end;
                 end;
               else
                 InternalError(2006031901);
             end;
           end;

         if Is_ObjC_Class_Or_Protocol(left.resultdef) and
            (TargetInfo.system in systems_objc_nfabi) then
           begin
             if (location.loc<>LOC_REFERENCE) or
                (location.reference.index<>NR_NO) then
               InternalError(2009092402);
             { the actual field offset is stored in memory (to solve the
               "fragile base class" problem: this way the layout of base
               classes can be changed without breaking programs compiled against
               earlier versions)
             }
             asmsym:=CurrentAsmData.RefAsmSymbol(vs.MangledName,AT_DATA);
             reference_reset_symbol(tmpref,asmsym,0,VoidPointerType.alignment,[]);
             hlcg.g_ptrtypecast_ref(CurrentAsmData.CurrAsmList,left.resultdef,CPointerDef.getreusable(resultdef),location.reference);
             location.reference.index:=hlcg.getintregister(CurrentAsmData.CurrAsmList,PtrUIntType);
             hlcg.a_load_ref_reg(CurrentAsmData.CurrAsmList,PtrUIntType,PtrUIntType,tmpref,location.reference.index);
             { always packrecords C -> natural alignment }
             location.reference.alignment:=vs.vardef.alignment;
           end
         else if handle_platform_subscript then
           begin
             { done }
           end
         else if (location.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
           begin
             if not is_packed_record_or_object(left.resultdef) then
               begin
                 inc(location.reference.offset,vs.FieldOffset);
                 location.reference.alignment:=NewAlignment(location.reference.alignment,vs.FieldOffset);
               end
             else if (vs.FieldOffset mod 8 = 0) and
                     (resultdef.PackedBitSize mod 8 = 0) and
                     { is different in case of e.g. packenum 2 and an enum }
                     { which fits in 8 bits                                }
                     (resultdef.size*8 = resultdef.PackedBitSize) then
               begin
                 inc(location.reference.offset,vs.FieldOffset div 8);
                 location.reference.alignment:=NewAlignment(location.reference.alignment,vs.FieldOffset div 8);
               end
             else
               begin
                 sref.ref:=location.reference;
                 sref.ref.alignment:=1;
                 sref.bitindexreg:=NR_NO;
                 inc(sref.ref.offset,vs.FieldOffset div 8);
                 sref.startbit:=vs.FieldOffset mod 8;
                 sref.bitlen:=resultdef.PackedBitSize;
                 if (left.location.loc=LOC_REFERENCE) then
                   location.loc:=LOC_SUBSETREF
                 else
                   location.loc:=LOC_CSUBSETREF;
                 location.sref:=sref;
               end;
             { also update the size of the location }
             location.size:=def_cgsize(resultdef);
           end;
         paraloc1.done;
      end;


{*****************************************************************************
                            TCGVECNODE
*****************************************************************************}

     function TCGVecNode.get_mul_size : asizeint;
       begin
         if vnf_memindex in vecnodeflags then
          get_mul_size:=1
         else
          begin
            if (left.resultdef.typ=arraydef) then
             if not is_packed_array(left.resultdef) then
              get_mul_size:=TArrayDef(left.resultdef).EleSize
             else
              get_mul_size:=TArrayDef(left.resultdef).ElePackedBitSize
            else
             get_mul_size:=resultdef.size;
          end
       end;


     function TCGVecNode.get_address_type: TDef;
       begin
         result:=CPointerDef.getreusable(resultdef);
       end;


     { this routine must, like any other routine, not change the contents }
     { of base/index registers of references, as these may be regvars.    }
     { The register allocator can coalesce one LOC_REGISTER being moved   }
     { into another (as their live ranges won't overlap), but not a       }
     { LOC_CREGISTER moved into a LOC_(C)REGISTER most of the time (as    }
     { the live range of the LOC_CREGISTER will most likely overlap the   }
     { the live range of the target LOC_(C)REGISTER)                      }
     { The passed register may be a LOC_CREGISTER as well.                }
     procedure TCGVecNode.update_reference_reg_mul(maybe_const_reg: TRegister; regsize: TDef; l: aint);
       var
         hreg: TRegister;
       begin
         hlcg.g_ptrtypecast_reg(CurrentAsmData.CurrAsmList,regsize,get_address_type,maybe_const_reg);
         if l<>1 then
           begin
             hreg:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,get_address_type);
             hlcg.a_op_const_reg_reg(CurrentAsmData.CurrAsmList,OP_IMUL,get_address_type,l,maybe_const_reg,hreg);
             maybe_const_reg:=hreg;
           end;
         if location.reference.base=NR_NO then
           location.reference.base:=maybe_const_reg
         else if location.reference.index=NR_NO then
           location.reference.index:=maybe_const_reg
         else
          begin
            hreg:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,get_address_type);
            hlcg.a_loadaddr_ref_reg(CurrentAsmData.CurrAsmList,resultdef,get_address_type,location.reference,hreg);
            reference_reset_base(location.reference,hreg,0,location.reference.temppos,location.reference.alignment,location.reference.volatility);
            { insert new index register }
            location.reference.index:=maybe_const_reg;
          end;
          { update alignment }
          if (location.reference.alignment=0) then
            InternalError(2009020704);
          location.reference.alignment:=NewAlignment(location.reference.alignment,l);
       end;


     { see remarks for tcgvecnode.update_reference_reg_mul above }
     procedure TCGVecNode.update_reference_reg_packed(maybe_const_reg: TRegister; regsize: TDef; l:aint);
       var
         sref: TSubsetReference;
         offsetreg, hreg: TRegister;
         alignpower: aint;
         temp : LongInt;
       begin
         { only orddefs are bitpacked. Even then we only need special code in }
         { case the bitpacked *byte size* is not a power of two, otherwise    }
         { everything can be handled using the the regular array code.        }
         if ((l mod 8) = 0) and
            (IsPowerOf2(l div 8,temp) or
             not is_ordinal(resultdef)
{$ifndef cpu64bitalu}
             or is_64bitint(resultdef)
{$endif not cpu64bitalu}
             ) then
           begin
             update_reference_reg_mul(maybe_const_reg,regsize,l div 8);
             exit;
           end;
         if (l > 8*sizeof(aint)) then
           InternalError(200608051);
         hlcg.g_ptrtypecast_reg(CurrentAsmData.CurrAsmList,regsize,get_address_type,maybe_const_reg);
         sref.ref := location.reference;
         hreg := hlcg.getaddressregister(CurrentAsmData.CurrAsmList,get_address_type);
         hlcg.a_op_const_reg_reg(CurrentAsmData.CurrAsmList,OP_SUB,get_address_type,TArrayDef(left.resultdef).LowRange,maybe_const_reg,hreg);
         hlcg.a_op_const_reg(CurrentAsmData.CurrAsmList,OP_IMUL,get_address_type,l,hreg);
         { keep alignment for index }
         sref.ref.alignment := left.resultdef.alignment;
         if not IsPowerOf2(PackedBitsLoadSize(l),temp) then
           InternalError(2006081201);
         alignpower:=temp;
         offsetreg := hlcg.getaddressregister(CurrentAsmData.CurrAsmList,get_address_type);
         hlcg.a_op_const_reg_reg(CurrentAsmData.CurrAsmList,OP_SHR,get_address_type,3+alignpower,hreg,offsetreg);
         hlcg.a_op_const_reg(CurrentAsmData.CurrAsmList,OP_SHL,get_address_type,alignpower,offsetreg);
         if (sref.ref.base = NR_NO) then
           sref.ref.base := offsetreg
         else if (sref.ref.index = NR_NO) then
           sref.ref.index := offsetreg
         else
           begin
             hlcg.a_op_reg_reg(CurrentAsmData.CurrAsmList,OP_ADD,get_address_type,sref.ref.base,offsetreg);
             sref.ref.base := offsetreg;
           end;

         { the if expression below is a constant evaluated at compile time, so disable the unreachable code
           warning }
{$push}
{$warn 6018 off}
         { we can reuse hreg only if aluuinttype and get_address_type have the same size/type }
         if ALUUIntType.size<>get_address_type.size then
           begin
             sref.bitindexreg := hlcg.getintregister(CurrentAsmData.CurrAsmList,ALUUIntType);
             hlcg.a_load_reg_reg(CurrentAsmData.CurrAsmList,get_address_type,ALUUIntType,hreg,sref.bitindexreg);
           end
         else
           sref.bitindexreg:=hreg;
{$pop}

         hlcg.a_op_const_reg(CurrentAsmData.CurrAsmList,OP_AND,ALUUIntType,(1 shl (3+alignpower))-1,sref.bitindexreg);
         sref.startbit := 0;
         sref.bitlen := resultdef.PackedBitSize;
         if (left.location.loc = LOC_REFERENCE) then
           location.loc := LOC_SUBSETREF
         else
           location.loc := LOC_CSUBSETREF;
         location.sref := sref;
       end;


     procedure TCGVecNode.update_reference_offset(var ref: TReference; index, mulsize: ASizeInt);
       var
         newoffset : TCGInt;
       begin
         newoffset:=ref.offset+index*mulsize;
{$ifopt R+}
{$ifdef cpu32bitaddr}
         if (newoffset>high(ASizeUInt)) or (newoffset<low(asizeint)) then
           message(parser_e_range_check_error)
	 else
{$endif}
{$endif}
          ref.offset:=asizeint(newoffset);
       end;

     procedure TCGVecNode.second_wideansistring;
       begin
       end;

     procedure TCGVecNode.second_dynamicarray;
       begin
       end;


     function TCGVecNode.valid_index_size(size: TCgSize): boolean;
       begin
         result:=
           tcgsize2signed[size]=tcgsize2signed[OS_ADDR];
       end;


     procedure TCGVecNode.rangecheck_array;
       var
         paraloc1,paraloc2 : TCGPara;
         pd : TProcDef;
       begin
         { omit range checking when this is an array access to a pointer which has been
           typecasted from an array }
         if (ado_isconvertedpointer in TArrayDef(left.resultdef).ArrayOptions) then
           exit;
         paraloc1.init;
         paraloc2.init;
         if is_dynamic_array(left.resultdef) then
            begin
               pd:=Search_System_Proc('fpc_dynarray_rangecheck');
               paramanager.getcgtempparaloc(CurrentAsmData.CurrAsmList,pd,1,paraloc1);
               paramanager.getcgtempparaloc(CurrentAsmData.CurrAsmList,pd,2,paraloc2);
               if pd.Is_PushLeftRight then
                 begin
                   hlcg.a_load_loc_cgpara(CurrentAsmData.CurrAsmList,left.resultdef,left.location,paraloc1);
                   hlcg.a_load_loc_cgpara(CurrentAsmData.CurrAsmList,right.resultdef,right.location,paraloc2);
                 end
               else
                 begin
                   hlcg.a_load_loc_cgpara(CurrentAsmData.CurrAsmList,right.resultdef,right.location,paraloc2);
                   hlcg.a_load_loc_cgpara(CurrentAsmData.CurrAsmList,left.resultdef,left.location,paraloc1);
                 end;
               paramanager.freecgpara(CurrentAsmData.CurrAsmList,paraloc1);
               paramanager.freecgpara(CurrentAsmData.CurrAsmList,paraloc2);
               hlcg.g_call_system_proc(CurrentAsmData.CurrAsmList,pd,[@paraloc1,@paraloc2],nil).resetiftemp;
            end;
         { for regular arrays, we don't have to do anything because the index has been
           type converted to the index type, which already inserted a range check if
           necessary }
         paraloc1.done;
         paraloc2.done;
       end;

    procedure TCGVecNode.rangecheck_string;
      var
        paraloc1,
        paraloc2: TCGPara;
        helpername: TIDString;
        pd: TProcDef;
      begin
        paraloc1.init;
        paraloc2.init;
        case TStringDef(left.resultdef).StringType of
          { it's the same for ansi- and wide strings }
          st_unicodestring,
          st_widestring,
          st_ansistring:
            begin
              if cs_zerobasedstrings in CurrentSettings.LocalSwitches then
                helpername:='fpc_'+TStringDef(left.resultdef).StringTypName+'_zerobased_rangecheck'
              else
                helpername:='fpc_'+TStringDef(left.resultdef).StringTypName+'_rangecheck';
              pd:=Search_System_Proc(helpername);
              paramanager.getcgtempparaloc(CurrentAsmData.CurrAsmList,pd,1,paraloc1);
              paramanager.getcgtempparaloc(CurrentAsmData.CurrAsmList,pd,2,paraloc2);
              if pd.Is_PushLeftRight then
                begin
                  hlcg.a_load_loc_cgpara(CurrentAsmData.CurrAsmList,left.resultdef,left.location,paraloc1);
                  hlcg.a_load_loc_cgpara(CurrentAsmData.CurrAsmList,right.resultdef,right.location,paraloc2);
                end
              else
                begin
                  hlcg.a_load_loc_cgpara(CurrentAsmData.CurrAsmList,right.resultdef,right.location,paraloc2);
                  hlcg.a_load_loc_cgpara(CurrentAsmData.CurrAsmList,left.resultdef,left.location,paraloc1);
                end;

              paramanager.freecgpara(CurrentAsmData.CurrAsmList,paraloc1);
              paramanager.freecgpara(CurrentAsmData.CurrAsmList,paraloc2);
              hlcg.g_call_system_proc(CurrentAsmData.CurrAsmList,pd,[@paraloc1,@paraloc2],nil).resetiftemp;
            end;

          st_shortstring:
            begin
              {!!!!!!!!!!!!!!!!!}
              { if this one is implemented making use of the high parameter for openshortstrings, update ncgutils.do_get_used_regvars() too (JM) }
            end;

          st_longstring:
            begin
              {!!!!!!!!!!!!!!!!!}
            end;
        end;
        paraloc1.done;
        paraloc2.done;
      end;

    procedure TCGVecNode.pass_generate_code;

      var
         offsetdec,
         extraoffset : ASizeInt;
         rightp      : PNode;
         newsize  : TCgSize;
         mulsize,
         bytemulsize : ASizeInt;
         alignpow : aint;
         paraloc1,
         paraloc2 : TCGPara;
         subsetref : TSubsetReference;
         temp : LongInt;
         hreg : TRegister;
         IndexDef : TDef;

      begin
         paraloc1.init;
         paraloc2.init;
         mulsize:=get_mul_size;
         if not is_packed_array(left.resultdef) then
           bytemulsize:=mulsize
         else
           bytemulsize:=mulsize div 8;

         newsize:=def_cgsize(resultdef);
         SecondPass(left);
         if left.location.loc in [LOC_CREFERENCE,LOC_REFERENCE] then
           location_reset_ref(location,left.location.loc,newsize,left.location.reference.alignment,left.location.reference.volatility)
         else
           location_reset_ref(location,LOC_REFERENCE,newsize,resultdef.alignment,[]);

         { an ansistring needs to be dereferenced }
         if is_ansistring(left.resultdef) or
            is_wide_or_unicode_string(left.resultdef) then
           begin
              if vnf_callunique in vecnodeflags then
                InternalError(200304236);

              {DM!!!!!}
              case left.location.loc of
                LOC_REGISTER,
                LOC_CREGISTER :
                  begin
                    hlcg.reference_reset_base(location.reference,left.resultdef,left.location.register,0,ctempposinvalid,location.reference.alignment,[]);
                  end;
                LOC_CREFERENCE,
                LOC_REFERENCE :
                  begin
                    hlcg.reference_reset_base(location.reference,left.resultdef,hlcg.getaddressregister(CurrentAsmData.CurrAsmList,left.resultdef),0,ctempposinvalid,location.reference.alignment,[]);
                    hlcg.a_load_ref_reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,left.location.reference,location.reference.base);
                  end;
                LOC_CONSTANT:
                  begin
                    hlcg.reference_reset_base(location.reference,left.resultdef,NR_NO,left.location.value,ctempposinvalid,location.reference.alignment,[]);
                  end;
                else
                  InternalError(2002032218);
              end;

              if is_ansistring(left.resultdef) then
                offsetdec:=1
              else
                offsetdec:=2;
              location.reference.alignment:=offsetdec;
              location.reference.volatility:=[];

              { in ansistrings/widestrings S[1] is p<w>char(S)[0] }
              if not(cs_zerobasedstrings in CurrentSettings.LocalSwitches) then
                update_reference_offset(location.reference,-1,offsetdec);
           end
         else if is_dynamic_array(left.resultdef) then
           begin
              case left.location.loc of
                LOC_REGISTER,
                LOC_CREGISTER :
                  hlcg.reference_reset_base(location.reference,left.resultdef,left.location.register,0,ctempposinvalid,location.reference.alignment,[]);
                LOC_REFERENCE,
                LOC_CREFERENCE :
                  begin
                     hlcg.reference_reset_base(location.reference,left.resultdef,hlcg.getaddressregister(CurrentAsmData.CurrAsmList,left.resultdef),0,ctempposinvalid,location.reference.alignment,[]);
                     hlcg.a_load_ref_reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,
                      left.location.reference,location.reference.base);
                  end;
                else
                  InternalError(2002032219);
              end;
              { a dynarray points to the start of a memory block, which
                we assume to be always aligned to a multiple of the
                pointer size
              }
              location.reference.alignment:=VoidPointerType.size;
              location.reference.volatility:=[];
           end
         else
           begin
             { may happen in case of function results }
             case left.location.loc of
               LOC_CREGISTER,
               LOC_REGISTER:
                 begin
                   if not(is_constnode(right)) or (TArrayDef(left.resultdef).ElementDef.size<>ALUSIntType.size) then
                     begin
                       hlcg.location_force_mem(CurrentAsmData.CurrAsmList,left.location,left.resultdef);
                       location_copy(location,left.location);
                     end
                   else
                     { we use location here only to get the right offset }
                     location_reset_ref(location,LOC_REFERENCE,OS_NO,1,[]);
                 end;
               LOC_CSUBSETREG,
               LOC_CMMREGISTER,
               LOC_SUBSETREG,
               LOC_MMREGISTER:
                 begin
                   hlcg.location_force_mem(CurrentAsmData.CurrAsmList,left.location,left.resultdef);
                   location_copy(location,left.location);
                 end;
               LOC_CONSTANT:  { Usually 'nil' }
                 begin
                   hlcg.reference_reset_base(location.reference,left.resultdef,NR_NO,left.location.value,ctempposinvalid,location.reference.alignment,[]);
                 end;
               LOC_INVALID:
                 InternalError(2019061101);
               else
                 location_copy(location,left.location);
             end;
           end;

         { location must be memory }
         if not(location.loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
           InternalError(200411013);

         { offset can only differ from 0 if arraydef }
         if (left.resultdef.typ=arraydef) and
            not(is_dynamic_array(left.resultdef)) and
            (not(is_packed_array(left.resultdef)) or
             ((mulsize mod 8 = 0) and
              IsPowerOf2(mulsize div 8,temp)) or
              { only orddefs are bitpacked }
              not is_ordinal(resultdef)
{$ifndef cpu64bitalu}
              or is_64bitint(resultdef)
{$endif not cpu64bitalu}
              ) then
           update_reference_offset(location.reference,-TArrayDef(left.resultdef).LowRange,bytemulsize);

         if right.nodetype=ordconstn then
           begin
              { offset can only differ from 0 if arraydef }
              if cs_check_range in CurrentSettings.LocalSwitches then
                begin
                  SecondPass(right);
                  case left.resultdef.typ of
                    arraydef :
                      rangecheck_array;
                    stringdef :
                      rangecheck_string;
                    else
                      ;
                  end;
                end;
              if not(is_packed_array(left.resultdef)) or
                 ((mulsize mod 8 = 0) and
                  (IsPowerOf2(mulsize div 8,temp) or
                   { only orddefs are bitpacked }
                   not is_ordinal(resultdef))) then
                begin
                  extraoffset:=TOrdConstNode(right).value.svalue;
                  update_reference_offset(location.reference,extraoffset,bytemulsize);
                  { adjust alignment after this change }
                  location.reference.alignment:=NewAlignment(location.reference.alignment,extraoffset*bytemulsize);

                  { actually an array in a register? }
                  if (left.location.loc in [LOC_CREGISTER,LOC_REGISTER]) and
                    is_normal_array(left.resultdef) then
                    begin
{$if defined(cpu64bitalu)}
                      hreg:=left.location.register;
{$else defined(cpu64bitalu)}
                      if TargetInfo.endian=endian_little then
                        begin
                          if location.reference.offset>3 then
                            hreg:=left.location.register64.reghi
                          else
                            hreg:=left.location.register64.reglo;
                        end
                      else
                        begin
                          if location.reference.offset>3 then
                            hreg:=left.location.register64.reglo
                          else
                            hreg:=left.location.register64.reghi;
                        end;
{$endif defined(cpu64bitalu)}

                      location_reset(location,left.location.loc,def_cgsize(TArrayDef(left.resultdef).ElementDef));
                      location.register:=hreg;
                    end;
                end
              else
                begin
                  subsetref.ref := location.reference;
                  subsetref.ref.alignment := left.resultdef.alignment;
                  if not IsPowerOf2(PackedBitsLoadSize(resultdef.PackedBitSize),temp) then
                    InternalError(2006081212);
                  alignpow:=temp;
                  update_reference_offset(subsetref.ref,(mulsize * (TOrdConstNode(right).value.svalue-TArrayDef(left.resultdef).LowRange)) shr (3+alignpow),1 shl alignpow);
                  subsetref.bitindexreg := NR_NO;
                  subsetref.startbit := (mulsize * (TOrdConstNode(right).value.svalue-TArrayDef(left.resultdef).LowRange)) and ((1 shl (3+alignpow))-1);
                  subsetref.bitlen := resultdef.PackedBitSize;
                  if (left.location.loc = LOC_REFERENCE) then
                    location.loc := LOC_SUBSETREF
                  else
                    location.loc := LOC_CSUBSETREF;
                  location.sref := subsetref;
                end;
           end
         else
         { not nodetype=ordconstn }
           begin
              if (cs_opt_level1 in CurrentSettings.OptimizerSwitches) and
                 { if we do range checking, we don't }
                 { need that fancy code (it would be }
                 { buggy)                            }
                 not(cs_check_range in CurrentSettings.LocalSwitches) and
                 (left.resultdef.typ=arraydef) and
                 not is_packed_array(left.resultdef) then
                begin
                   extraoffset:=0;
                   rightp:=actualtargetnode(@right);
                   if rightp^.nodetype=addn then
                     begin
                        if TAddNode(rightp^).right.nodetype=ordconstn then
                          begin
                            extraoffset:=TOrdConstNode(TAddNode(rightp^).right).value.svalue;
                            replacenode(rightp^,TAddNode(rightp^).left);
                          end
                        else if TAddNode(rightp^).left.nodetype=ordconstn then
                          begin
                            extraoffset:=TOrdConstNode(TAddNode(rightp^).left).value.svalue;
                            replacenode(rightp^,TAddNode(rightp^).right);
                          end;
                     end
                   else if rightp^.nodetype=subn then
                     begin
                        if TAddNode(rightp^).right.nodetype=ordconstn then
                          begin
                            extraoffset:=-TOrdConstNode(TAddNode(rightp^).right).value.svalue;
                            replacenode(rightp^,TAddNode(rightp^).left);
                          end;
                     end;
                   update_reference_offset(location.reference,extraoffset,mulsize);
                end;
              { calculate from left to right }
              if not(location.loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
                InternalError(200304237);
              SecondPass(right);
              if (right.expectloc=LOC_JUMP)<>
                 (right.location.loc=LOC_JUMP) then
                InternalError(2006010801);

              { if mulsize = 1, we won't have to modify the index }
              if not(right.location.loc in [LOC_CREGISTER,LOC_REGISTER]) or
                 not valid_index_size(right.location.size) then
                begin
                  hlcg.location_force_reg(CurrentAsmData.CurrAsmList,right.location,right.resultdef,SizeUIntType,true);
                  IndexDef:=SizeUIntType
                end
              else
                IndexDef:=right.resultdef;

            { produce possible range check code: }
              if cs_check_range in CurrentSettings.LocalSwitches then
               begin
                 if left.resultdef.typ=arraydef then
                   rangecheck_array
                 else if (left.resultdef.typ=stringdef) then
                   rangecheck_string;
               end;

              { insert the register and the multiplication factor in the
                reference }
              if not is_packed_array(left.resultdef) then
                update_reference_reg_mul(right.location.register,IndexDef,mulsize)
              else
                update_reference_reg_packed(right.location.register,IndexDef,mulsize);
           end;

        location.size:=newsize;
        paraloc1.done;
        paraloc2.done;
      end;


begin
   CLoadVMTAddrNode:=TCGLoadVMTAddrNode;
   CLoadParentFPNode:=TCGLoadParentFPNode;
   CAddrNode:=TCGAddrNode;
   CDerefNode:=TCGDerefNode;
   CSubscriptNode:=TCGSubscriptNode;
   CVecNode:=TCGVecNode;
end.
