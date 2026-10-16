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
         Location_Reset(location,LOC_REGISTER,Def_CGSize(VoidPointerType));
         if (left.nodetype=typen) then
           begin
             location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,VoidPointerType);
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
                 Reference_Reset_Symbol(href,
                   CurrentAsmData.RefAsmSymbol(vmtname,AT_DATA,indirect),0,
                   resultdef.Alignment,[]);
                 hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,resultdef,resultdef,href,location.Register);
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
                 Reference_Reset_Symbol(href,TAsmLabel(entry^.Data),0,ObjC_IDType.Alignment,[]);
                 hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,ObjC_IDType,ObjC_IDType,href,location.Register);
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
            Location_Reset(location,LOC_REGISTER,Def_CGSize(ParentFPVoidPointerType));
            location.Register:=CurrentProcInfo.framepointer;
          end
        else
          begin
            Location_Reset(location,LOC_REGISTER,Def_CGSize(ParentFPVoidPointerType));
            currpi:=CurrentProcInfo;
            { load framepointer of current proc }
            hsym:=TParaVarSym(currpi.procdef.ParentFPSym);
            if (currpi.procdef.owner.SymTableLevel=parentpd.ParaST.SymTableLevel) and (hsym.LocAlloc.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
              location.Register:=hsym.LocAlloc.Register
            else
              begin
                location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ParentFPVoidPointerType);
                hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,ParentFPVoidPointerType,ParentFPVoidPointerType,hsym.LocAlloc,location.Register);
                { walk parents }
                while (currpi.procdef.owner.SymTableLevel>parentpd.ParaST.SymTableLevel) do
                  begin
                    currpi:=currpi.parent;
                    if not Assigned(currpi) then
                      InternalError(200311201);
                    hsym:=TParaVarSym(currpi.procdef.ParentFPSym);
                    if hsym.LocAlloc.Loc<>LOC_REFERENCE then
                      InternalError(200309283);

                    hlcg.Reference_Reset_Base(href,ParentFPVoidPointerType,location.Register,hsym.LocAlloc.Reference.Offset,CTempPosInvalid,ParentFPVoidPointerType.Alignment,[]);
                    hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,ParentFPVoidPointerType,ParentFPVoidPointerType,href,location.Register);
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

         Location_Reset(location,LOC_REGISTER,Int_CGSize(resultdef.Size));
         location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,resultdef);
         if not(left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
           { on x86_64-win64, array of chars can be returned in registers, however,
             when passing these arrays to other functions, the compiler wants to take
             the address of the array so when the addrnode has been created internally,
             we have to force the data into memory, see also tw14388 (case in tb_arrays_objfpc_run_03.pas).pas
           }
           if nf_internal in flags then
             hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef)
           else
             InternalError(2006111510);
         hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location.Reference,location.Register);
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
           Location_Reset_Ref(location,LOC_REFERENCE,Def_CGSize(resultdef),resultdef.Alignment,[])
         else
           Location_Reset_Ref(location,LOC_REFERENCE,Def_CGSize(resultdef),1,[]);

         { can we fold an add/sub node into the offset of the deref node? }
         newoffset:=0;
         hp:=actualtargetnode(@left);
         if (hp^.nodetype=subn) and is_constintnode(TAddNode(hp^).right) then
           begin
             newoffset:=-TCGInt(TOrdConstNode(TAddNode(hp^).right).Value);
             replacenode(hp^,TAddNode(hp^).left);
           end
         else if (hp^.nodetype=addn) and is_constintnode(TAddNode(hp^).right) then
           begin
             newoffset:=TCGInt(TOrdConstNode(TAddNode(hp^).right).Value);
             replacenode(hp^,TAddNode(hp^).left);
           end
         else if (hp^.nodetype=addn) and is_constintnode(TAddNode(hp^).left) then
           begin
             newoffset:=TCGInt(TOrdConstNode(TAddNode(hp^).left).Value);
             replacenode(hp^,TAddNode(hp^).right);
           end;

         SecondPass(left);

         if not(left.Location.Loc in [LOC_CREGISTER,LOC_REGISTER,LOC_CREFERENCE,LOC_REFERENCE,LOC_CONSTANT]) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true);
         case left.Location.Loc of
            LOC_CREGISTER,
            LOC_REGISTER:
              begin
                hlcg.Maybe_Change_Load_Node_Reg(CurrentAsmData.CurrAsmList,left,true);
              {$ifdef cpu_uses_separate_address_registers}
                if GetRegType(left.Location.Register)<>R_ADDRESSREGISTER then
                  begin
                    location.Reference.Base := cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
                    cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,left.Location.Register,
                      location.Reference.Base);
                  end
                else
              {$endif}
                  location.Reference.Base := left.Location.Register;
              end;
            LOC_CREFERENCE,
            LOC_REFERENCE:
              begin
                 location.Reference.Base:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
                 hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,left.Location,location.Reference.Base);
              end;
            LOC_CONSTANT:
              begin
                inc(newoffset,left.Location.Value);
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
           location.Reference.Offset:=asizeint(newoffset);
         if (cs_use_heaptrc in CurrentSettings.GlobalSwitches) and
            (cs_checkpointer in CurrentSettings.LocalSwitches) and
            not(cs_compilesystem in CurrentSettings.ModuleSwitches) and
            TPointerDef(left.resultdef).Compatible_With_PointerDef_Size(TPointerDef(VoidPointerType)) and
            not(drnf_no_checkpointer in derefnodeflags) and
            { can be NR_NO in case of LOC_CONSTANT }
            (location.Reference.Base<>NR_NO) then
          begin
            if not SearchSym_In_Named_Module('HEAPTRC','CHECKPOINTER',sym,st) or
               (sym.typ<>ProcSym) then
              InternalError(2012010601);
            pd:=TProcDef(TProcSym(sym).ProcdefList[0]);
            paraloc1.init;
            ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,pd,1,paraloc1);
            hlcg.A_LoadAddr_Ref_CGPara(CurrentAsmData.CurrAsmList,left.resultdef,location.Reference,paraloc1);
            ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,paraloc1);
            paraloc1.done;
            hlcg.AllocAllCPURegisters(CurrentAsmData.CurrAsmList);
            hlcg.A_Call_Name(CurrentAsmData.CurrAsmList,pd,'FPC_CHECKPOINTER',[@paraloc1],nil,false);
            hlcg.DeallocAllCPURegisters(CurrentAsmData.CurrAsmList);
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
             if not Is_Managed_Type(left.resultdef) then
               begin
                 { take care of the alignment of the fields }
                 if not(left.resultdef is TAbstractRecordDef) then
                   InternalError(2018021601);
                 Location_Reset_Ref(location,LOC_REFERENCE,Def_CGSize(resultdef),NewAlignment(TAbstractRecordSymTable(TAbstractRecordDef(left.resultdef).SymTable).RecordAlignment,vs.FieldOffset),[]);
                 case left.Location.Loc of
                    LOC_CREGISTER,
                    LOC_REGISTER:
                      begin
                      {$ifdef cpu_uses_separate_address_registers}
                        if GetRegType(left.Location.Register)<>R_ADDRESSREGISTER then
                          begin
                            location.Reference.Base:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
                            hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,
                              left.Location.Register,location.Reference.Base);
                          end
                        else
                      {$endif}
                          hlcg.Reference_Reset_Base(location.Reference,left.resultdef,left.Location.Register,0,CTempPosInvalid,location.Reference.Alignment,location.Reference.Volatility);
                      end;
                    LOC_CREFERENCE,
                    LOC_REFERENCE,
                    { tricky type casting of parameters can cause these locations, see tb0592 (case in tb_classes_objfpc_run_01.pas).pas on x86_64-linux }
                    LOC_SUBSETREG,
                    LOC_CSUBSETREG,
                    LOC_SUBSETREF,
                    LOC_CSUBSETREF:
                      begin
                         hlcg.Reference_Reset_Base(location.Reference,left.resultdef,
                           hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,left.resultdef),0,CTempPosInvalid,location.Reference.Alignment,location.Reference.Volatility);
                         hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,left.Location,location.Reference.Base);
                      end;
                    LOC_CONSTANT:
                      begin
                        { can happen with @classtype(pointerconst).field }
                        location.Reference.Offset:=left.Location.Value;
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
                    ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,pd,1,paraloc1);
                    hlcg.A_LoadAddr_Ref_CGPara(CurrentAsmData.CurrAsmList,left.resultdef,location.Reference,paraloc1);
                    ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,paraloc1);
                    hlcg.AllocAllCPURegisters(CurrentAsmData.CurrAsmList);
                    hlcg.A_Call_Name(CurrentAsmData.CurrAsmList,pd,'FPC_CHECKPOINTER',[@paraloc1],nil,false);
                    hlcg.DeallocAllCPURegisters(CurrentAsmData.CurrAsmList);
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
             Location_Copy(location,left.Location);
             { some abi's require that functions return (some) records in }
             { registers                                                  }
             case location.Loc of
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
                      ((left.Location.Size in [OSPair,OSSPair]) and
                       (vs.FieldOffset div sizeof(aword)<>(vs.FieldOffset+vs.GetSize-1) div sizeof(aword))) or
                      (location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER,
                        { actually, we should be able to "subscript" a constant, but this would require some code
                          which enables dumping and reading constants from a temporary memory buffer. This
                          must be done a CPU dependent way, so it is not easy and probably not worth the effort (FK)
                        }
                        LOC_CONSTANT]) then
                     hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,location,left.resultdef)
                   else
                     begin
                       if (location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                         if (TCgSize2Size[location.Size]<=TCgSize2Size[OS_INT]) then
                           begin
                             hreg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
                             cg.A_LoadMM_Reg_IntReg(CurrentAsmData.CurrAsmList,reg_cgsize(left.Location.Register),location.Size,
                               left.Location.Register,hreg,MMS_MoveScalar);
                             Location_Reset(left.Location,LOC_REGISTER,Int_CGSize(TCgSize2Size[left.Location.Size]));
                             left.Location.Register:=hreg;
                             { copy again, we changed left.location }
                             Location_Copy(location,left.Location);
                           end
                         else
                           hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,location,left.resultdef);

                       if (left.Location.Loc = LOC_REGISTER) then
                         location.Loc := LOC_SUBSETREG
                       else
                         location.Loc := LOC_CSUBSETREG;
                       location.Size:=Def_CGSize(resultdef);

                       offsetcorrection:=0;
                       if (left.Location.Size in [OSPair,OSSPair]) then
                         begin
                           if not Is_Packed_Record_Or_Object(left.resultdef) then
                             awordoffset:=sizeof(aword)
                           else
                             awordoffset:=sizeof(aword)*8;

                           if (vs.FieldOffset>=awordoffset) xor (TargetInfo.endian=endian_big) then
                             location.SReg.SubsetReg := left.Location.RegisterHi
                           else
                             location.SReg.SubsetReg := left.Location.Register;

                           if vs.FieldOffset>=awordoffset then
                             offsetcorrection := sizeof(aword)*8;

                           location.SReg.SubsetRegSize := OS_INT;
                         end
                       else
                         begin
                           location.SReg.SubsetReg := left.Location.Register;
                           location.SReg.SubsetRegSize := left.Location.Size;
                         end;

                       if not Is_Packed_Record_Or_Object(left.resultdef) then
                         begin
                           if (TargetInfo.endian = ENDIAN_BIG) then
                             location.SReg.StartBit := (TCgSize2Size[location.SReg.SubsetRegSize] - TCgSize2Size[location.Size] - vs.FieldOffset) * 8+offsetcorrection
                           else
                             location.SReg.StartBit := (vs.FieldOffset * 8)-offsetcorrection;
                           location.SReg.BitLen := TCgSize2Size[location.Size] * 8;
                         end
                       else
                         begin
                           location.SReg.BitLen := resultdef.PackedBitSize;
                           if (TargetInfo.endian = ENDIAN_BIG) then
                             location.SReg.StartBit := (TCgSize2Size[location.SReg.SubsetRegSize]*8 - location.SReg.BitLen) - vs.FieldOffset+offsetcorrection
                           else
                             location.SReg.StartBit := vs.FieldOffset-offsetcorrection;
                         end;
                     end;
                 end;
               LOC_SUBSETREG,
               LOC_CSUBSETREG:
                 begin
                   location.Size:=Def_CGSize(resultdef);
                   if not Is_Packed_Record_Or_Object(left.resultdef) then
                     begin
                       if (TargetInfo.endian = ENDIAN_BIG) then
                         inc(location.SReg.StartBit, (left.resultdef.Size - TCgSize2Size[location.Size] - vs.FieldOffset) * 8)
                       else
                         inc(location.SReg.StartBit, vs.FieldOffset * 8);
                       location.SReg.BitLen := TCgSize2Size[location.Size] * 8;
                     end
                   else
                     begin
                       location.SReg.BitLen := resultdef.PackedBitSize;
                       if (TargetInfo.endian = ENDIAN_BIG) then
                         inc(location.SReg.StartBit, left.Location.SReg.BitLen - location.SReg.BitLen - vs.FieldOffset)
                       else
                         inc(location.SReg.StartBit, vs.FieldOffset);
                     end;
                 end;
               else
                 InternalError(2006031901);
             end;
           end;

         if Is_ObjC_Class_Or_Protocol(left.resultdef) and
            (TargetInfo.system in systems_objc_nfabi) then
           begin
             if (location.Loc<>LOC_REFERENCE) or
                (location.Reference.Index<>NR_NO) then
               InternalError(2009092402);
             { the actual field offset is stored in memory (to solve the
               "fragile base class" problem: this way the layout of base
               classes can be changed without breaking programs compiled against
               earlier versions)
             }
             asmsym:=CurrentAsmData.RefAsmSymbol(vs.MangledName,AT_DATA);
             Reference_Reset_Symbol(tmpref,asmsym,0,VoidPointerType.Alignment,[]);
             hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,left.resultdef,CPointerDef.getreusable(resultdef),location.Reference);
             location.Reference.Index:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,PtrUIntType);
             hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,PtrUIntType,PtrUIntType,tmpref,location.Reference.Index);
             { always packrecords C -> natural alignment }
             location.Reference.Alignment:=vs.vardef.Alignment;
           end
         else if handle_platform_subscript then
           begin
             { done }
           end
         else if (location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
           begin
             if not Is_Packed_Record_Or_Object(left.resultdef) then
               begin
                 inc(location.Reference.Offset,vs.FieldOffset);
                 location.Reference.Alignment:=NewAlignment(location.Reference.Alignment,vs.FieldOffset);
               end
             else if (vs.FieldOffset mod 8 = 0) and
                     (resultdef.PackedBitSize mod 8 = 0) and
                     { is different in case of e.g. packenum 2 and an enum }
                     { which fits in 8 bits                                }
                     (resultdef.Size*8 = resultdef.PackedBitSize) then
               begin
                 inc(location.Reference.Offset,vs.FieldOffset div 8);
                 location.Reference.Alignment:=NewAlignment(location.Reference.Alignment,vs.FieldOffset div 8);
               end
             else
               begin
                 sref.Ref:=location.Reference;
                 sref.Ref.Alignment:=1;
                 sref.BitIndexReg:=NR_NO;
                 inc(sref.Ref.Offset,vs.FieldOffset div 8);
                 sref.StartBit:=vs.FieldOffset mod 8;
                 sref.BitLen:=resultdef.PackedBitSize;
                 if (left.Location.Loc=LOC_REFERENCE) then
                   location.Loc:=LOC_SUBSETREF
                 else
                   location.Loc:=LOC_CSUBSETREF;
                 location.SRef:=sref;
               end;
             { also update the size of the location }
             location.Size:=Def_CGSize(resultdef);
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
             if not Is_Packed_Array(left.resultdef) then
              get_mul_size:=TArrayDef(left.resultdef).EleSize
             else
              get_mul_size:=TArrayDef(left.resultdef).ElePackedBitSize
            else
             get_mul_size:=resultdef.Size;
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
         hlcg.G_PtrTypeCast_Reg(CurrentAsmData.CurrAsmList,regsize,get_address_type,maybe_const_reg);
         if l<>1 then
           begin
             hreg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,get_address_type);
             hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_IMUL,get_address_type,l,maybe_const_reg,hreg);
             maybe_const_reg:=hreg;
           end;
         if location.Reference.Base=NR_NO then
           location.Reference.Base:=maybe_const_reg
         else if location.Reference.Index=NR_NO then
           location.Reference.Index:=maybe_const_reg
         else
          begin
            hreg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,get_address_type);
            hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,resultdef,get_address_type,location.Reference,hreg);
            Reference_Reset_Base(location.Reference,hreg,0,location.Reference.TempPos,location.Reference.Alignment,location.Reference.Volatility);
            { insert new index register }
            location.Reference.Index:=maybe_const_reg;
          end;
          { update alignment }
          if (location.Reference.Alignment=0) then
            InternalError(2009020704);
          location.Reference.Alignment:=NewAlignment(location.Reference.Alignment,l);
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
             not Is_Ordinal(resultdef)
{$ifndef cpu64bitalu}
             or Is_64BitInt(resultdef)
{$endif not cpu64bitalu}
             ) then
           begin
             update_reference_reg_mul(maybe_const_reg,regsize,l div 8);
             exit;
           end;
         if (l > 8*sizeof(aint)) then
           InternalError(200608051);
         hlcg.G_PtrTypeCast_Reg(CurrentAsmData.CurrAsmList,regsize,get_address_type,maybe_const_reg);
         sref.Ref := location.Reference;
         hreg := hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,get_address_type);
         hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SUB,get_address_type,TArrayDef(left.resultdef).LowRange,maybe_const_reg,hreg);
         hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_IMUL,get_address_type,l,hreg);
         { keep alignment for index }
         sref.Ref.Alignment := left.resultdef.Alignment;
         if not IsPowerOf2(PackedBitsLoadSize(l),temp) then
           InternalError(2006081201);
         alignpower:=temp;
         offsetreg := hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,get_address_type);
         hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHR,get_address_type,3+alignpower,hreg,offsetreg);
         hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SHL,get_address_type,alignpower,offsetreg);
         if (sref.Ref.Base = NR_NO) then
           sref.Ref.Base := offsetreg
         else if (sref.Ref.Index = NR_NO) then
           sref.Ref.Index := offsetreg
         else
           begin
             hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_ADD,get_address_type,sref.Ref.Base,offsetreg);
             sref.Ref.Base := offsetreg;
           end;

         { the if expression below is a constant evaluated at compile time, so disable the unreachable code
           warning }
{$push}
{$warn 6018 off}
         { we can reuse hreg only if aluuinttype and get_address_type have the same size/type }
         if ALUUIntType.Size<>get_address_type.Size then
           begin
             sref.BitIndexReg := hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ALUUIntType);
             hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,get_address_type,ALUUIntType,hreg,sref.BitIndexReg);
           end
         else
           sref.BitIndexReg:=hreg;
{$pop}

         hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_AND,ALUUIntType,(1 shl (3+alignpower))-1,sref.BitIndexReg);
         sref.StartBit := 0;
         sref.BitLen := resultdef.PackedBitSize;
         if (left.Location.Loc = LOC_REFERENCE) then
           location.Loc := LOC_SUBSETREF
         else
           location.Loc := LOC_CSUBSETREF;
         location.SRef := sref;
       end;


     procedure TCGVecNode.update_reference_offset(var ref: TReference; index, mulsize: ASizeInt);
       var
         newoffset : TCGInt;
       begin
         newoffset:=ref.Offset+index*mulsize;
{$ifopt R+}
{$ifdef cpu32bitaddr}
         if (newoffset>high(ASizeUInt)) or (newoffset<low(asizeint)) then
           message(parser_e_range_check_error)
	 else
{$endif}
{$endif}
          ref.Offset:=asizeint(newoffset);
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
           TCgSize2Signed[size]=TCgSize2Signed[OS_ADDR];
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
         if Is_Dynamic_Array(left.resultdef) then
            begin
               pd:=Search_System_Proc('fpc_dynarray_rangecheck');
               ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,pd,1,paraloc1);
               ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,pd,2,paraloc2);
               if pd.Is_PushLeftRight then
                 begin
                   hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,left.resultdef,left.Location,paraloc1);
                   hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,right.resultdef,right.Location,paraloc2);
                 end
               else
                 begin
                   hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,right.resultdef,right.Location,paraloc2);
                   hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,left.resultdef,left.Location,paraloc1);
                 end;
               ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,paraloc1);
               ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,paraloc2);
               hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,pd,[@paraloc1,@paraloc2],nil).ResetIfTemp;
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
              ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,pd,1,paraloc1);
              ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,pd,2,paraloc2);
              if pd.Is_PushLeftRight then
                begin
                  hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,left.resultdef,left.Location,paraloc1);
                  hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,right.resultdef,right.Location,paraloc2);
                end
              else
                begin
                  hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,right.resultdef,right.Location,paraloc2);
                  hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,left.resultdef,left.Location,paraloc1);
                end;

              ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,paraloc1);
              ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,paraloc2);
              hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,pd,[@paraloc1,@paraloc2],nil).ResetIfTemp;
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
         if not Is_Packed_Array(left.resultdef) then
           bytemulsize:=mulsize
         else
           bytemulsize:=mulsize div 8;

         newsize:=Def_CGSize(resultdef);
         SecondPass(left);
         if left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE] then
           Location_Reset_Ref(location,left.Location.Loc,newsize,left.Location.Reference.Alignment,left.Location.Reference.Volatility)
         else
           Location_Reset_Ref(location,LOC_REFERENCE,newsize,resultdef.Alignment,[]);

         { an ansistring needs to be dereferenced }
         if Is_AnsiString(left.resultdef) or
            Is_Wide_Or_Unicode_String(left.resultdef) then
           begin
              if vnf_callunique in vecnodeflags then
                InternalError(200304236);

              {DM!!!!!}
              case left.Location.Loc of
                LOC_REGISTER,
                LOC_CREGISTER :
                  begin
                    hlcg.Reference_Reset_Base(location.Reference,left.resultdef,left.Location.Register,0,CTempPosInvalid,location.Reference.Alignment,[]);
                  end;
                LOC_CREFERENCE,
                LOC_REFERENCE :
                  begin
                    hlcg.Reference_Reset_Base(location.Reference,left.resultdef,hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,left.resultdef),0,CTempPosInvalid,location.Reference.Alignment,[]);
                    hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,left.Location.Reference,location.Reference.Base);
                  end;
                LOC_CONSTANT:
                  begin
                    hlcg.Reference_Reset_Base(location.Reference,left.resultdef,NR_NO,left.Location.Value,CTempPosInvalid,location.Reference.Alignment,[]);
                  end;
                else
                  InternalError(2002032218);
              end;

              if Is_AnsiString(left.resultdef) then
                offsetdec:=1
              else
                offsetdec:=2;
              location.Reference.Alignment:=offsetdec;
              location.Reference.Volatility:=[];

              { in ansistrings/widestrings S[1] is p<w>char(S)[0] }
              if not(cs_zerobasedstrings in CurrentSettings.LocalSwitches) then
                update_reference_offset(location.Reference,-1,offsetdec);
           end
         else if Is_Dynamic_Array(left.resultdef) then
           begin
              case left.Location.Loc of
                LOC_REGISTER,
                LOC_CREGISTER :
                  hlcg.Reference_Reset_Base(location.Reference,left.resultdef,left.Location.Register,0,CTempPosInvalid,location.Reference.Alignment,[]);
                LOC_REFERENCE,
                LOC_CREFERENCE :
                  begin
                     hlcg.Reference_Reset_Base(location.Reference,left.resultdef,hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,left.resultdef),0,CTempPosInvalid,location.Reference.Alignment,[]);
                     hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,
                      left.Location.Reference,location.Reference.Base);
                  end;
                else
                  InternalError(2002032219);
              end;
              { a dynarray points to the start of a memory block, which
                we assume to be always aligned to a multiple of the
                pointer size
              }
              location.Reference.Alignment:=VoidPointerType.Size;
              location.Reference.Volatility:=[];
           end
         else
           begin
             { may happen in case of function results }
             case left.Location.Loc of
               LOC_CREGISTER,
               LOC_REGISTER:
                 begin
                   if not(is_constnode(right)) or (TArrayDef(left.resultdef).ElementDef.Size<>ALUSIntType.Size) then
                     begin
                       hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);
                       Location_Copy(location,left.Location);
                     end
                   else
                     { we use location here only to get the right offset }
                     Location_Reset_Ref(location,LOC_REFERENCE,OS_NO,1,[]);
                 end;
               LOC_CSUBSETREG,
               LOC_CMMREGISTER,
               LOC_SUBSETREG,
               LOC_MMREGISTER:
                 begin
                   hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);
                   Location_Copy(location,left.Location);
                 end;
               LOC_CONSTANT:  { Usually 'nil' }
                 begin
                   hlcg.Reference_Reset_Base(location.Reference,left.resultdef,NR_NO,left.Location.Value,CTempPosInvalid,location.Reference.Alignment,[]);
                 end;
               LOC_INVALID:
                 InternalError(2019061101);
               else
                 Location_Copy(location,left.Location);
             end;
           end;

         { location must be memory }
         if not(location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
           InternalError(200411013);

         { offset can only differ from 0 if arraydef }
         if (left.resultdef.typ=arraydef) and
            not(Is_Dynamic_Array(left.resultdef)) and
            (not(Is_Packed_Array(left.resultdef)) or
             ((mulsize mod 8 = 0) and
              IsPowerOf2(mulsize div 8,temp)) or
              { only orddefs are bitpacked }
              not Is_Ordinal(resultdef)
{$ifndef cpu64bitalu}
              or Is_64BitInt(resultdef)
{$endif not cpu64bitalu}
              ) then
           update_reference_offset(location.Reference,-TArrayDef(left.resultdef).LowRange,bytemulsize);

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
              if not(Is_Packed_Array(left.resultdef)) or
                 ((mulsize mod 8 = 0) and
                  (IsPowerOf2(mulsize div 8,temp) or
                   { only orddefs are bitpacked }
                   not Is_Ordinal(resultdef))) then
                begin
                  extraoffset:=TOrdConstNode(right).Value.svalue;
                  update_reference_offset(location.Reference,extraoffset,bytemulsize);
                  { adjust alignment after this change }
                  location.Reference.Alignment:=NewAlignment(location.Reference.Alignment,extraoffset*bytemulsize);

                  { actually an array in a register? }
                  if (left.Location.Loc in [LOC_CREGISTER,LOC_REGISTER]) and
                    Is_Normal_Array(left.resultdef) then
                    begin
{$if defined(cpu64bitalu)}
                      hreg:=left.Location.Register;
{$else defined(cpu64bitalu)}
                      if TargetInfo.endian=endian_little then
                        begin
                          if location.Reference.Offset>3 then
                            hreg:=left.Location.Register64.RegHi
                          else
                            hreg:=left.Location.Register64.RegLo;
                        end
                      else
                        begin
                          if location.Reference.Offset>3 then
                            hreg:=left.Location.Register64.RegLo
                          else
                            hreg:=left.Location.Register64.RegHi;
                        end;
{$endif defined(cpu64bitalu)}

                      Location_Reset(location,left.Location.Loc,Def_CGSize(TArrayDef(left.resultdef).ElementDef));
                      location.Register:=hreg;
                    end;
                end
              else
                begin
                  subsetref.Ref := location.Reference;
                  subsetref.Ref.Alignment := left.resultdef.Alignment;
                  if not IsPowerOf2(PackedBitsLoadSize(resultdef.PackedBitSize),temp) then
                    InternalError(2006081212);
                  alignpow:=temp;
                  update_reference_offset(subsetref.Ref,(mulsize * (TOrdConstNode(right).Value.svalue-TArrayDef(left.resultdef).LowRange)) shr (3+alignpow),1 shl alignpow);
                  subsetref.BitIndexReg := NR_NO;
                  subsetref.StartBit := (mulsize * (TOrdConstNode(right).Value.svalue-TArrayDef(left.resultdef).LowRange)) and ((1 shl (3+alignpow))-1);
                  subsetref.BitLen := resultdef.PackedBitSize;
                  if (left.Location.Loc = LOC_REFERENCE) then
                    location.Loc := LOC_SUBSETREF
                  else
                    location.Loc := LOC_CSUBSETREF;
                  location.SRef := subsetref;
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
                 not Is_Packed_Array(left.resultdef) then
                begin
                   extraoffset:=0;
                   rightp:=actualtargetnode(@right);
                   if rightp^.nodetype=addn then
                     begin
                        if TAddNode(rightp^).right.nodetype=ordconstn then
                          begin
                            extraoffset:=TOrdConstNode(TAddNode(rightp^).right).Value.svalue;
                            replacenode(rightp^,TAddNode(rightp^).left);
                          end
                        else if TAddNode(rightp^).left.nodetype=ordconstn then
                          begin
                            extraoffset:=TOrdConstNode(TAddNode(rightp^).left).Value.svalue;
                            replacenode(rightp^,TAddNode(rightp^).right);
                          end;
                     end
                   else if rightp^.nodetype=subn then
                     begin
                        if TAddNode(rightp^).right.nodetype=ordconstn then
                          begin
                            extraoffset:=-TOrdConstNode(TAddNode(rightp^).right).Value.svalue;
                            replacenode(rightp^,TAddNode(rightp^).left);
                          end;
                     end;
                   update_reference_offset(location.Reference,extraoffset,mulsize);
                end;
              { calculate from left to right }
              if not(location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
                InternalError(200304237);
              SecondPass(right);
              if (right.expectloc=LOC_JUMP)<>
                 (right.Location.Loc=LOC_JUMP) then
                InternalError(2006010801);

              { if mulsize = 1, we won't have to modify the index }
              if not(right.Location.Loc in [LOC_CREGISTER,LOC_REGISTER]) or
                 not valid_index_size(right.Location.Size) then
                begin
                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,SizeUIntType,true);
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
              if not Is_Packed_Array(left.resultdef) then
                update_reference_reg_mul(right.Location.Register,IndexDef,mulsize)
              else
                update_reference_reg_packed(right.Location.Register,IndexDef,mulsize);
           end;

        location.Size:=newsize;
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
