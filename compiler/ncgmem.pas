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
          procedure Pass_Generate_Code;override;
       end;

       TCGLoadParentFPNode = class(TLoadParentFPNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGAddrNode = class(TAddrNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGDerefNode = class(TDerefNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGSubscriptNode = class(TSubscriptNode)
         protected
          function Handle_Platform_Subscript: Boolean; virtual;
         public
          procedure Pass_Generate_Code;override;
       end;

       TCGVecNode = class(TVecNode)
         function Get_Mul_Size : ASizeInt;
       private
         procedure RangeCheckArray;
         procedure RangeCheckString;
       protected
         function Get_Address_Type: TDef;virtual;
         {# This routine is used to calculate the address of the reference.
            On entry AIndexReg contains the index in the array,
           and AElementSize contains the size of each element in the array.
           This routine should update location.reference correctly,
           so it points to the correct address.
         }
         procedure Update_Reference_Reg_Mul(AIndexReg: TRegister;ARegSize: TDef; AElementSize: AInt);virtual;
         procedure Update_Reference_Reg_Packed(AIndexReg: TRegister; ARegSize: TDef; AElementSize: AInt);virtual;
         procedure Update_Reference_Offset(var AReference: TReference; AIndex, AElementSize: ASizeInt); virtual;
         procedure Second_WideAnsiString;virtual;
         procedure Second_DynamicArray;virtual;
         function Valid_Index_Size(ASize: TCgSize): Boolean;virtual;
       public
         procedure Pass_Generate_Code;override;
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

    procedure TCGLoadVMTAddrNode.Pass_Generate_Code;
      var
        lReference    : TReference;
        lPool    : THashSet;
        lEntry   : PHashSetItem;
        lVMTName : TSymStr;
        lOtherUnit,
        lIndirect : Boolean;
      begin
         Location_Reset(Location,LOC_REGISTER,Def_CGSize(VoidPointerType));
         if (Left.NodeType=typen) then
           begin
             Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,VoidPointerType);
             if not Is_ObjCClass(Left.ResultDef) then
               begin
                 { we are using a direct reference if any of the following is true:
                   - the target does not support packages
                   - the target does not use indirect references
                   - the class is located inside the same unit }
                 lOtherUnit:=FindUnitSymTable(Left.ResultDef.owner).ModuleID<>CurrentModule.ModuleID;
                 lIndirect:=(tf_supports_packages in TargetInfo.Flags) and
                           (TargetInfo.system in systems_indirect_var_imports) and
                           lOtherUnit;
                 lVMTName:=TObjectDef(TClassRefDef(ResultDef).PointedDef).VMT_MangledName;
                 Reference_Reset_Symbol(lReference,
                   CurrentAsmData.RefAsmSymbol(lVMTName,AT_DATA,lIndirect),0,
                   ResultDef.Alignment,[]);
                 hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,ResultDef,ResultDef,lReference,Location.Register);
                 if lOtherUnit then
                   CurrentModule.Add_Extern_AsmSym(lVMTName,AB_EXTERNAL,AT_DATA);
               end
             else
               begin
                 lPool:=CurrentAsmData.ConstPools[sp_objcclassnamerefs];
                 lEntry:=lPool.FindOrAdd(@TObjectDef(Left.ResultDef).ObjExtName^[1],length(TObjectDef(Left.ResultDef).ObjExtName^));
                 if (TargetInfo.system in systems_objc_nfabi) then
                   begin
                     { find/add necessary classref/classname pool entries }
                     ObjCFinishClassRefNFPoolEntry(lEntry,TObjectDef(Left.ResultDef));
                   end
                 else
                   begin
                     { find/add necessary classref/classname pool entries }
                     ObjCFinishStringRefPoolEntry(lEntry,sp_objcclassnames,sec_objc_cls_refs,sec_objc_class_names);
                   end;
                 Reference_Reset_Symbol(lReference,TAsmLabel(lEntry^.Data),0,ObjC_IDType.Alignment,[]);
                 hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,ObjC_IDType,ObjC_IDType,lReference,Location.Register);
               end;
           end
         else
           { should be handled in pass 1 }
           InternalError(2015052801);
      end;


{*****************************************************************************
                        TCGLOADPARENTFPNODE
*****************************************************************************}

    procedure TCGLoadParentFPNode.Pass_Generate_Code;
      var
        lCurrentProcInfo : TProcInfo;
        lSym   : TParaVarSym;
        lReference   : TReference;
      begin
        if (CurrentProcInfo.procdef.ParaST.SymTableLevel=ParentPD.ParaST.SymTableLevel) then
          begin
            Location_Reset(Location,LOC_REGISTER,Def_CGSize(ParentFPVoidPointerType));
            Location.Register:=CurrentProcInfo.FramePointer;
          end
        else
          begin
            Location_Reset(Location,LOC_REGISTER,Def_CGSize(ParentFPVoidPointerType));
            lCurrentProcInfo:=CurrentProcInfo;
            { load framepointer of current proc }
            lSym:=TParaVarSym(lCurrentProcInfo.procdef.ParentFPSym);
            if (lCurrentProcInfo.procdef.owner.SymTableLevel=ParentPD.ParaST.SymTableLevel) and (lSym.LocAlloc.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
              Location.Register:=lSym.LocAlloc.Register
            else
              begin
                Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ParentFPVoidPointerType);
                hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,ParentFPVoidPointerType,ParentFPVoidPointerType,lSym.LocAlloc,Location.Register);
                { walk parents }
                while (lCurrentProcInfo.procdef.owner.SymTableLevel>ParentPD.ParaST.SymTableLevel) do
                  begin
                    lCurrentProcInfo:=lCurrentProcInfo.parent;
                    if not Assigned(lCurrentProcInfo) then
                      InternalError(200311201);
                    lSym:=TParaVarSym(lCurrentProcInfo.procdef.ParentFPSym);
                    if lSym.LocAlloc.Loc<>LOC_REFERENCE then
                      InternalError(200309283);

                    hlcg.Reference_Reset_Base(lReference,ParentFPVoidPointerType,Location.Register,lSym.LocAlloc.Reference.Offset,CTempPosInvalid,ParentFPVoidPointerType.Alignment,[]);
                    hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,ParentFPVoidPointerType,ParentFPVoidPointerType,lReference,Location.Register);
                  end;
              end;
          end;
      end;


{*****************************************************************************
                             TCGADDRNODE
*****************************************************************************}

    procedure TCGAddrNode.Pass_Generate_Code;
      begin
         SecondPass(Left);

         Location_Reset(Location,LOC_REGISTER,Int_CGSize(ResultDef.Size));
         Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ResultDef);
         if not(Left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
           { on x86_64-win64, array of chars can be returned in registers, however,
             when passing these arrays to other functions, the compiler wants to take
             the address of the array so when the addrnode has been created internally,
             we have to force the data into memory, see also tw14388 (case in tb_arrays_objfpc_run_03.pas).pas
           }
           if nf_internal in Flags then
             hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef)
           else
             InternalError(2006111510);
         hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location.Reference,Location.Register);
      end;


{*****************************************************************************
                           TCGDEREFNODE
*****************************************************************************}

    procedure TCGDerefNode.Pass_Generate_Code;
      var
        lParaLoc1 : TCGPara;
        lProcDef : TProcDef;
        lSym : TSym;
        lSymTable : TSymTable;
        lNodePointer : PNode;
        lNewOffset : TCGInt;
      begin
         lSym:=nil;
         { assume natural alignment, except for packed records }
         if not(ResultDef.typ in [recorddef,objectdef]) or
            (TAbstractRecordSymTable(TAbstractRecordDef(ResultDef).SymTable).UseFieldAlignment<>1) then
           Location_Reset_Ref(Location,LOC_REFERENCE,Def_CGSize(ResultDef),ResultDef.Alignment,[])
         else
           Location_Reset_Ref(Location,LOC_REFERENCE,Def_CGSize(ResultDef),1,[]);

         { can we fold an add/sub node into the offset of the deref node? }
         lNewOffset:=0;
         lNodePointer:=ActualTargetNode(@Left);
         if (lNodePointer^.NodeType=subn) and Is_ConstIntNode(TAddNode(lNodePointer^).Right) then
           begin
             lNewOffset:=-TCGInt(TOrdConstNode(TAddNode(lNodePointer^).Right).Value);
             ReplaceNode(lNodePointer^,TAddNode(lNodePointer^).Left);
           end
         else if (lNodePointer^.NodeType=addn) and Is_ConstIntNode(TAddNode(lNodePointer^).Right) then
           begin
             lNewOffset:=TCGInt(TOrdConstNode(TAddNode(lNodePointer^).Right).Value);
             ReplaceNode(lNodePointer^,TAddNode(lNodePointer^).Left);
           end
         else if (lNodePointer^.NodeType=addn) and Is_ConstIntNode(TAddNode(lNodePointer^).Left) then
           begin
             lNewOffset:=TCGInt(TOrdConstNode(TAddNode(lNodePointer^).Left).Value);
             ReplaceNode(lNodePointer^,TAddNode(lNodePointer^).Right);
           end;

         SecondPass(Left);

         if not(Left.Location.Loc in [LOC_CREGISTER,LOC_REGISTER,LOC_CREFERENCE,LOC_REFERENCE,LOC_CONSTANT]) then
           hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
         case Left.Location.Loc of
            LOC_CREGISTER,
            LOC_REGISTER:
              begin
                hlcg.Maybe_Change_Load_Node_Reg(CurrentAsmData.CurrAsmList,Left,true);
              {$ifdef cpu_uses_separate_address_registers}
                if GetRegType(Left.Location.Register)<>R_ADDRESSREGISTER then
                  begin
                    Location.Reference.Base := cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
                    cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,Left.Location.Register,
                      Location.Reference.Base);
                  end
                else
              {$endif}
                  Location.Reference.Base := Left.Location.Register;
              end;
            LOC_CREFERENCE,
            LOC_REFERENCE:
              begin
                 Location.Reference.Base:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
                 hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef,Left.Location,Location.Reference.Base);
              end;
            LOC_CONSTANT:
              begin
                inc(lNewOffset,Left.Location.Value);
              end;
            else
              InternalError(200507031);
         end;
{$ifopt R+}
{$ifdef cpu32bitaddr}
         if (lNewOffset>high(ASizeUInt)) or (lNewOffset<low(ASizeInt)) then
           message(parser_e_range_check_error)
         else
{$endif}
{$endif}
           Location.Reference.Offset:=ASizeInt(lNewOffset);
         if (cs_use_heaptrc in CurrentSettings.GlobalSwitches) and
            (cs_checkpointer in CurrentSettings.LocalSwitches) and
            not(cs_compilesystem in CurrentSettings.ModuleSwitches) and
            TPointerDef(Left.ResultDef).Compatible_With_PointerDef_Size(TPointerDef(VoidPointerType)) and
            not(drnf_no_checkpointer in DerefNodeFlags) and
            { can be NR_NO in case of LOC_CONSTANT }
            (Location.Reference.Base<>NR_NO) then
          begin
            if not SearchSym_In_Named_Module('HEAPTRC','CHECKPOINTER',lSym,lSymTable) or
               (lSym.typ<>ProcSym) then
              InternalError(2012010601);
            lProcDef:=TProcDef(TProcSym(lSym).ProcdefList[0]);
            lParaLoc1.init;
            ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,lProcDef,1,lParaLoc1);
            hlcg.A_LoadAddr_Ref_CGPara(CurrentAsmData.CurrAsmList,Left.ResultDef,Location.Reference,lParaLoc1);
            ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lParaLoc1);
            lParaLoc1.done;
            hlcg.AllocAllCPURegisters(CurrentAsmData.CurrAsmList);
            hlcg.A_Call_Name(CurrentAsmData.CurrAsmList,lProcDef,'FPC_CHECKPOINTER',[@lParaLoc1],nil,false);
            hlcg.DeallocAllCPURegisters(CurrentAsmData.CurrAsmList);
            include(CurrentSettings.ModuleSwitches,cs_checkpointer_called);
          end;
      end;


{*****************************************************************************
                          TCGSUBSCRIPTNODE
*****************************************************************************}

    function TCGSubscriptNode.Handle_Platform_Subscript: Boolean;
      begin
        Result:=false;
      end;

    procedure TCGSubscriptNode.Pass_Generate_Code;
      var
        lAsmSym: TAsmSymbol;
        lParaLoc1 : TCGPara;
        lTempRef: TReference;
        lSubsetRef: TSubsetReference;
        lWordOffset,
        lOffsetCorrection : AInt;
        lProcDef : TProcDef;
        lSym : TSym;
        lSymTable : TSymTable;
        lReg : TRegister;
      begin
         lSym:=nil;
         SecondPass(Left);
         if CodeGenError then
           exit;
         lParaLoc1.init;
         { several object types must be dereferenced implicitly }
         if Is_Implicit_Pointer_Object_Type(Left.ResultDef) then
           begin
             if not Is_Managed_Type(Left.ResultDef) then
               begin
                 { take care of the alignment of the fields }
                 if not(Left.ResultDef is TAbstractRecordDef) then
                   InternalError(2018021601);
                 Location_Reset_Ref(Location,LOC_REFERENCE,Def_CGSize(ResultDef),NewAlignment(TAbstractRecordSymTable(TAbstractRecordDef(Left.ResultDef).SymTable).RecordAlignment,FieldSym.FieldOffset),[]);
                 case Left.Location.Loc of
                    LOC_CREGISTER,
                    LOC_REGISTER:
                      begin
                      {$ifdef cpu_uses_separate_address_registers}
                        if GetRegType(Left.Location.Register)<>R_ADDRESSREGISTER then
                          begin
                            Location.Reference.Base:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
                            hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef,
                              Left.Location.Register,Location.Reference.Base);
                          end
                        else
                      {$endif}
                          hlcg.Reference_Reset_Base(Location.Reference,Left.ResultDef,Left.Location.Register,0,CTempPosInvalid,Location.Reference.Alignment,Location.Reference.Volatility);
                      end;
                    LOC_CREFERENCE,
                    LOC_REFERENCE,
                    { tricky type casting of parameters can cause these locations, see tb0592 (case in tb_classes_objfpc_run_01.pas).pas on x86_64-linux }
                    LOC_SUBSETREG,
                    LOC_CSUBSETREG,
                    LOC_SUBSETREF,
                    LOC_CSUBSETREF:
                      begin
                         hlcg.Reference_Reset_Base(Location.Reference,Left.ResultDef,
                           hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,Left.ResultDef),0,CTempPosInvalid,Location.Reference.Alignment,Location.Reference.Volatility);
                         hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef,Left.Location,Location.Reference.Base);
                      end;
                    LOC_CONSTANT:
                      begin
                        { can happen with @classtype(pointerconst).field }
                        Location.Reference.Offset:=Left.Location.Value;
                      end;
                    else
                      InternalError(2009092401);
                 end;
                 { implicit deferencing }
                 if (cs_use_heaptrc in CurrentSettings.GlobalSwitches) and
                    (cs_checkpointer in CurrentSettings.LocalSwitches) and
                    not(cs_compilesystem in CurrentSettings.ModuleSwitches) then
                  begin
                    if not SearchSym_In_Named_Module('HEAPTRC','CHECKPOINTER',lSym,lSymTable) or
                       (lSym.typ<>ProcSym) then
                      InternalError(2012010602);
                    lProcDef:=TProcDef(TProcSym(lSym).ProcdefList[0]);
                    ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,lProcDef,1,lParaLoc1);
                    hlcg.A_LoadAddr_Ref_CGPara(CurrentAsmData.CurrAsmList,Left.ResultDef,Location.Reference,lParaLoc1);
                    ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lParaLoc1);
                    hlcg.AllocAllCPURegisters(CurrentAsmData.CurrAsmList);
                    hlcg.A_Call_Name(CurrentAsmData.CurrAsmList,lProcDef,'FPC_CHECKPOINTER',[@lParaLoc1],nil,false);
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
             Location_Copy(Location,Left.Location);
             { some abi's require that functions return (some) records in }
             { registers                                                  }
             case Location.Loc of
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

                   if not TStoredDef(Left.ResultDef).Is_IntRegable or
                      not TStoredDef(ResultDef).Is_IntRegable or
                      { if the field spans multiple registers, we must force the record into
                        memory as well }
                      ((Left.Location.Size in [OSPair,OSSPair]) and
                       (FieldSym.FieldOffset div sizeof(aword)<>(FieldSym.FieldOffset+FieldSym.GetSize-1) div sizeof(aword))) or
                      (Location.Loc in [LOC_FPUREGISTER,LOC_CFPUREGISTER,
                        { actually, we should be able to "subscript" a constant, but this would require some code
                          which enables dumping and reading constants from a temporary memory buffer. This
                          must be done a CPU dependent way, so it is not easy and probably not worth the effort (FK)
                        }
                        LOC_CONSTANT]) then
                     hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Location,Left.ResultDef)
                   else
                     begin
                       if (Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                         if (TCgSize2Size[Location.Size]<=TCgSize2Size[OS_INT]) then
                           begin
                             lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
                             cg.A_LoadMM_Reg_IntReg(CurrentAsmData.CurrAsmList,reg_cgsize(Left.Location.Register),Location.Size,
                               Left.Location.Register,lReg,MMS_MoveScalar);
                             Location_Reset(Left.Location,LOC_REGISTER,Int_CGSize(TCgSize2Size[Left.Location.Size]));
                             Left.Location.Register:=lReg;
                             { copy again, we changed left.location }
                             Location_Copy(Location,Left.Location);
                           end
                         else
                           hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Location,Left.ResultDef);

                       if (Left.Location.Loc = LOC_REGISTER) then
                         Location.Loc := LOC_SUBSETREG
                       else
                         Location.Loc := LOC_CSUBSETREG;
                       Location.Size:=Def_CGSize(ResultDef);

                       lOffsetCorrection:=0;
                       if (Left.Location.Size in [OSPair,OSSPair]) then
                         begin
                           if not Is_Packed_Record_Or_Object(Left.ResultDef) then
                             lWordOffset:=sizeof(aword)
                           else
                             lWordOffset:=sizeof(aword)*8;

                           if FieldSym . FieldOffset >= lWordOffset then
                             Location.SReg.SubsetReg := Left.Location.RegisterHi
                           else
                             Location.SReg.SubsetReg := Left.Location.Register;

                           if FieldSym.FieldOffset>=lWordOffset then
                             lOffsetCorrection := sizeof(aword)*8;

                           Location.SReg.SubsetRegSize := OS_INT;
                         end
                       else
                         begin
                           Location.SReg.SubsetReg := Left.Location.Register;
                           Location.SReg.SubsetRegSize := Left.Location.Size;
                         end;

                       if not Is_Packed_Record_Or_Object(Left.ResultDef) then
                         begin
                           Location.SReg.StartBit := (FieldSym.FieldOffset * 8)-lOffsetCorrection;
                           Location.SReg.BitLen := TCgSize2Size[Location.Size] * 8;
                         end
                       else
                         begin
                           Location.SReg.BitLen := ResultDef.PackedBitSize;
                           Location.SReg.StartBit := FieldSym.FieldOffset-lOffsetCorrection;
                         end;
                     end;
                 end;
               LOC_SUBSETREG,
               LOC_CSUBSETREG:
                 begin
                   Location.Size:=Def_CGSize(ResultDef);
                   if not Is_Packed_Record_Or_Object(Left.ResultDef) then
                     begin
                       inc(Location.SReg.StartBit, FieldSym.FieldOffset * 8);
                       Location.SReg.BitLen := TCgSize2Size[Location.Size] * 8;
                     end
                   else
                     begin
                       Location.SReg.BitLen := ResultDef.PackedBitSize;
                       inc(Location.SReg.StartBit, FieldSym.FieldOffset);
                     end;
                 end;
               else
                 InternalError(2006031901);
             end;
           end;

         if Is_ObjC_Class_Or_Protocol(Left.ResultDef) and
            (TargetInfo.system in systems_objc_nfabi) then
           begin
             if (Location.Loc<>LOC_REFERENCE) or
                (Location.Reference.Index<>NR_NO) then
               InternalError(2009092402);
             { the actual field offset is stored in memory (to solve the
               "fragile base class" problem: this way the layout of base
               classes can be changed without breaking programs compiled against
               earlier versions)
             }
             lAsmSym:=CurrentAsmData.RefAsmSymbol(FieldSym.MangledName,AT_DATA);
             Reference_Reset_Symbol(lTempRef,lAsmSym,0,VoidPointerType.Alignment,[]);
             hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,Left.ResultDef,CPointerDef.getreusable(ResultDef),Location.Reference);
             Location.Reference.Index:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,PtrUIntType);
             hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,PtrUIntType,PtrUIntType,lTempRef,Location.Reference.Index);
             { always packrecords C -> natural alignment }
             Location.Reference.Alignment:=FieldSym.vardef.Alignment;
           end
         else if Handle_Platform_Subscript then
           begin
             { done }
           end
         else if (Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
           begin
             if not Is_Packed_Record_Or_Object(Left.ResultDef) then
               begin
                 inc(Location.Reference.Offset,FieldSym.FieldOffset);
                 Location.Reference.Alignment:=NewAlignment(Location.Reference.Alignment,FieldSym.FieldOffset);
               end
             else if (FieldSym.FieldOffset mod 8 = 0) and
                     (ResultDef.PackedBitSize mod 8 = 0) and
                     { is different in case of e.g. packenum 2 and an enum }
                     { which fits in 8 bits                                }
                     (ResultDef.Size*8 = ResultDef.PackedBitSize) then
               begin
                 inc(Location.Reference.Offset,FieldSym.FieldOffset div 8);
                 Location.Reference.Alignment:=NewAlignment(Location.Reference.Alignment,FieldSym.FieldOffset div 8);
               end
             else
               begin
                 lSubsetRef.Ref:=Location.Reference;
                 lSubsetRef.Ref.Alignment:=1;
                 lSubsetRef.BitIndexReg:=NR_NO;
                 inc(lSubsetRef.Ref.Offset,FieldSym.FieldOffset div 8);
                 lSubsetRef.StartBit:=FieldSym.FieldOffset mod 8;
                 lSubsetRef.BitLen:=ResultDef.PackedBitSize;
                 if (Left.Location.Loc=LOC_REFERENCE) then
                   Location.Loc:=LOC_SUBSETREF
                 else
                   Location.Loc:=LOC_CSUBSETREF;
                 Location.SRef:=lSubsetRef;
               end;
             { also update the size of the location }
             Location.Size:=Def_CGSize(ResultDef);
           end;
         lParaLoc1.done;
      end;


{*****************************************************************************
                            TCGVECNODE
*****************************************************************************}

     function TCGVecNode.Get_Mul_Size : ASizeInt;
       begin
         if vnf_memindex in VecNodeFlags then
          Get_Mul_Size:=1
         else
          begin
            if (Left.ResultDef.typ=arraydef) then
             if not Is_Packed_Array(Left.ResultDef) then
              Get_Mul_Size:=TArrayDef(Left.ResultDef).EleSize
             else
              Get_Mul_Size:=TArrayDef(Left.ResultDef).ElePackedBitSize
            else
             Get_Mul_Size:=ResultDef.Size;
          end
       end;


     function TCGVecNode.Get_Address_Type: TDef;
       begin
         Result:=CPointerDef.getreusable(ResultDef);
       end;


     { this routine must, like any other routine, not change the contents }
     { of base/index registers of references, as these may be regvars.    }
     { The register allocator can coalesce one LOC_REGISTER being moved   }
     { into another (as their live ranges won't overlap), but not a       }
     { LOC_CREGISTER moved into a LOC_(C)REGISTER most of the time (as    }
     { the live range of the LOC_CREGISTER will most likely overlap the   }
     { the live range of the target LOC_(C)REGISTER)                      }
     { The passed register may be a LOC_CREGISTER as well.                }
     procedure TCGVecNode.Update_Reference_Reg_Mul(AIndexReg: TRegister; ARegSize: TDef; AElementSize: AInt);
       var
         lReg: TRegister;
       begin
         hlcg.G_PtrTypeCast_Reg(CurrentAsmData.CurrAsmList,ARegSize,Get_Address_Type,AIndexReg);
         if AElementSize<>1 then
           begin
             lReg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,Get_Address_Type);
             hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_IMUL,Get_Address_Type,AElementSize,AIndexReg,lReg);
             AIndexReg:=lReg;
           end;
         if Location.Reference.Base=NR_NO then
           Location.Reference.Base:=AIndexReg
         else if Location.Reference.Index=NR_NO then
           Location.Reference.Index:=AIndexReg
         else
          begin
            lReg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,Get_Address_Type);
            hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,ResultDef,Get_Address_Type,Location.Reference,lReg);
            Reference_Reset_Base(Location.Reference,lReg,0,Location.Reference.TempPos,Location.Reference.Alignment,Location.Reference.Volatility);
            { insert new index register }
            Location.Reference.Index:=AIndexReg;
          end;
          { update alignment }
          if (Location.Reference.Alignment=0) then
            InternalError(2009020704);
          Location.Reference.Alignment:=NewAlignment(Location.Reference.Alignment,AElementSize);
       end;


     { see remarks for tcgvecnode.update_reference_reg_mul above }
     procedure TCGVecNode.Update_Reference_Reg_Packed(AIndexReg: TRegister; ARegSize: TDef; AElementSize:AInt);
       var
         lSubsetRef: TSubsetReference;
         lOffsetReg, lReg: TRegister;
         lAlignPower: AInt;
         lTemp : LongInt;
       begin
         { only orddefs are bitpacked. Even then we only need special code in }
         { case the bitpacked *byte size* is not a power of two, otherwise    }
         { everything can be handled using the the regular array code.        }
         if ((AElementSize mod 8) = 0) and
            (IsPowerOf2(AElementSize div 8,lTemp) or
             not Is_Ordinal(ResultDef)
{$ifndef cpu64bitalu}
             or Is_64BitInt(ResultDef)
{$endif not cpu64bitalu}
             ) then
           begin
             Update_Reference_Reg_Mul(AIndexReg,ARegSize,AElementSize div 8);
             exit;
           end;
         if (AElementSize > 8*sizeof(AInt)) then
           InternalError(200608051);
         hlcg.G_PtrTypeCast_Reg(CurrentAsmData.CurrAsmList,ARegSize,Get_Address_Type,AIndexReg);
         lSubsetRef.Ref := Location.Reference;
         lReg := hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,Get_Address_Type);
         hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SUB,Get_Address_Type,TArrayDef(Left.ResultDef).LowRange,AIndexReg,lReg);
         hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_IMUL,Get_Address_Type,AElementSize,lReg);
         { keep alignment for index }
         lSubsetRef.Ref.Alignment := Left.ResultDef.Alignment;
         if not IsPowerOf2(PackedBitsLoadSize(AElementSize),lTemp) then
           InternalError(2006081201);
         lAlignPower:=lTemp;
         lOffsetReg := hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,Get_Address_Type);
         hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHR,Get_Address_Type,3+lAlignPower,lReg,lOffsetReg);
         hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SHL,Get_Address_Type,lAlignPower,lOffsetReg);
         if (lSubsetRef.Ref.Base = NR_NO) then
           lSubsetRef.Ref.Base := lOffsetReg
         else if (lSubsetRef.Ref.Index = NR_NO) then
           lSubsetRef.Ref.Index := lOffsetReg
         else
           begin
             hlcg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_ADD,Get_Address_Type,lSubsetRef.Ref.Base,lOffsetReg);
             lSubsetRef.Ref.Base := lOffsetReg;
           end;

         { the if expression below is a constant evaluated at compile time, so disable the unreachable code
           warning }
{$push}
{$warn 6018 off}
         { we can reuse hreg only if aluuinttype and get_address_type have the same size/type }
         if ALUUIntType.Size<>Get_Address_Type.Size then
           begin
             lSubsetRef.BitIndexReg := hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ALUUIntType);
             hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,Get_Address_Type,ALUUIntType,lReg,lSubsetRef.BitIndexReg);
           end
         else
           lSubsetRef.BitIndexReg:=lReg;
{$pop}

         hlcg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_AND,ALUUIntType,(1 shl (3+lAlignPower))-1,lSubsetRef.BitIndexReg);
         lSubsetRef.StartBit := 0;
         lSubsetRef.BitLen := ResultDef.PackedBitSize;
         if (Left.Location.Loc = LOC_REFERENCE) then
           Location.Loc := LOC_SUBSETREF
         else
           Location.Loc := LOC_CSUBSETREF;
         Location.SRef := lSubsetRef;
       end;


     procedure TCGVecNode.Update_Reference_Offset(var AReference: TReference; AIndex, AElementSize: ASizeInt);
       var
         lNewOffset : TCGInt;
       begin
         lNewOffset:=AReference.Offset+AIndex*AElementSize;
{$ifopt R+}
{$ifdef cpu32bitaddr}
         if (lNewOffset>high(ASizeUInt)) or (lNewOffset<low(ASizeInt)) then
           message(parser_e_range_check_error)
	 else
{$endif}
{$endif}
          AReference.Offset:=ASizeInt(lNewOffset);
       end;

     procedure TCGVecNode.Second_WideAnsiString;
       begin
       end;

     procedure TCGVecNode.Second_DynamicArray;
       begin
       end;


     function TCGVecNode.Valid_Index_Size(ASize: TCgSize): Boolean;
       begin
         Result:=
           TCgSize2Signed[ASize]=TCgSize2Signed[OS_ADDR];
       end;


     procedure TCGVecNode.RangeCheckArray;
       var
         lParaLoc1,lParaLoc2 : TCGPara;
         lProcDef : TProcDef;
       begin
         { omit range checking when this is an array access to a pointer which has been
           typecasted from an array }
         if (ado_isconvertedpointer in TArrayDef(Left.ResultDef).ArrayOptions) then
           exit;
         lParaLoc1.init;
         lParaLoc2.init;
         if Is_Dynamic_Array(Left.ResultDef) then
            begin
               lProcDef:=Search_System_Proc('fpc_dynarray_rangecheck');
               ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,lProcDef,1,lParaLoc1);
               ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,lProcDef,2,lParaLoc2);
               if lProcDef.Is_PushLeftRight then
                 begin
                   hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.Location,lParaLoc1);
                   hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,Right.ResultDef,Right.Location,lParaLoc2);
                 end
               else
                 begin
                   hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,Right.ResultDef,Right.Location,lParaLoc2);
                   hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.Location,lParaLoc1);
                 end;
               ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lParaLoc1);
               ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lParaLoc2);
               hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,lProcDef,[@lParaLoc1,@lParaLoc2],nil).ResetIfTemp;
            end;
         { for regular arrays, we don't have to do anything because the index has been
           type converted to the index type, which already inserted a range check if
           necessary }
         lParaLoc1.done;
         lParaLoc2.done;
       end;

    procedure TCGVecNode.RangeCheckString;
      var
        lParaLoc1,
        lParaLoc2: TCGPara;
        lHelperName: TIDString;
        lProcDef: TProcDef;
      begin
        lParaLoc1.init;
        lParaLoc2.init;
        case TStringDef(Left.ResultDef).StringType of
          { it's the same for ansi- and wide strings }
          st_unicodestring,
          st_widestring,
          st_ansistring:
            begin
              if cs_zerobasedstrings in CurrentSettings.LocalSwitches then
                lHelperName:='fpc_'+TStringDef(Left.ResultDef).StringTypName+'_zerobased_rangecheck'
              else
                lHelperName:='fpc_'+TStringDef(Left.ResultDef).StringTypName+'_rangecheck';
              lProcDef:=Search_System_Proc(lHelperName);
              ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,lProcDef,1,lParaLoc1);
              ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,lProcDef,2,lParaLoc2);
              if lProcDef.Is_PushLeftRight then
                begin
                  hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.Location,lParaLoc1);
                  hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,Right.ResultDef,Right.Location,lParaLoc2);
                end
              else
                begin
                  hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,Right.ResultDef,Right.Location,lParaLoc2);
                  hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.Location,lParaLoc1);
                end;

              ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lParaLoc1);
              ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lParaLoc2);
              hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,lProcDef,[@lParaLoc1,@lParaLoc2],nil).ResetIfTemp;
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
        lParaLoc1.done;
        lParaLoc2.done;
      end;

    procedure TCGVecNode.Pass_Generate_Code;

      var
         lOffsetDecrement,
         lExtraOffset : ASizeInt;
         lRightNode      : PNode;
         lNewSize  : TCgSize;
         lElementSize,
         lByteElementSize : ASizeInt;
         lAlignPower : AInt;
         lParaLoc1,
         lParaLoc2 : TCGPara;
         lSubsetRef : TSubsetReference;
         lTemp : LongInt;
         lReg : TRegister;
         lIndexDef : TDef;

      begin
         lParaLoc1.init;
         lParaLoc2.init;
         lElementSize:=Get_Mul_Size;
         if not Is_Packed_Array(Left.ResultDef) then
           lByteElementSize:=lElementSize
         else
           lByteElementSize:=lElementSize div 8;

         lNewSize:=Def_CGSize(ResultDef);
         SecondPass(Left);
         if Left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE] then
           Location_Reset_Ref(Location,Left.Location.Loc,lNewSize,Left.Location.Reference.Alignment,Left.Location.Reference.Volatility)
         else
           Location_Reset_Ref(Location,LOC_REFERENCE,lNewSize,ResultDef.Alignment,[]);

         { an ansistring needs to be dereferenced }
         if Is_AnsiString(Left.ResultDef) or
            Is_Wide_Or_Unicode_String(Left.ResultDef) then
           begin
              if vnf_callunique in VecNodeFlags then
                InternalError(200304236);

              {DM!!!!!}
              case Left.Location.Loc of
                LOC_REGISTER,
                LOC_CREGISTER :
                  begin
                    hlcg.Reference_Reset_Base(Location.Reference,Left.ResultDef,Left.Location.Register,0,CTempPosInvalid,Location.Reference.Alignment,[]);
                  end;
                LOC_CREFERENCE,
                LOC_REFERENCE :
                  begin
                    hlcg.Reference_Reset_Base(Location.Reference,Left.ResultDef,hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,Left.ResultDef),0,CTempPosInvalid,Location.Reference.Alignment,[]);
                    hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef,Left.Location.Reference,Location.Reference.Base);
                  end;
                LOC_CONSTANT:
                  begin
                    hlcg.Reference_Reset_Base(Location.Reference,Left.ResultDef,NR_NO,Left.Location.Value,CTempPosInvalid,Location.Reference.Alignment,[]);
                  end;
                else
                  InternalError(2002032218);
              end;

              if Is_AnsiString(Left.ResultDef) then
                lOffsetDecrement:=1
              else
                lOffsetDecrement:=2;
              Location.Reference.Alignment:=lOffsetDecrement;
              Location.Reference.Volatility:=[];

              { in ansistrings/widestrings S[1] is p<w>char(S)[0] }
              if not(cs_zerobasedstrings in CurrentSettings.LocalSwitches) then
                Update_Reference_Offset(Location.Reference,-1,lOffsetDecrement);
           end
         else if Is_Dynamic_Array(Left.ResultDef) then
           begin
              case Left.Location.Loc of
                LOC_REGISTER,
                LOC_CREGISTER :
                  hlcg.Reference_Reset_Base(Location.Reference,Left.ResultDef,Left.Location.Register,0,CTempPosInvalid,Location.Reference.Alignment,[]);
                LOC_REFERENCE,
                LOC_CREFERENCE :
                  begin
                     hlcg.Reference_Reset_Base(Location.Reference,Left.ResultDef,hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,Left.ResultDef),0,CTempPosInvalid,Location.Reference.Alignment,[]);
                     hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef,
                      Left.Location.Reference,Location.Reference.Base);
                  end;
                else
                  InternalError(2002032219);
              end;
              { a dynarray points to the start of a memory block, which
                we assume to be always aligned to a multiple of the
                pointer size
              }
              Location.Reference.Alignment:=VoidPointerType.Size;
              Location.Reference.Volatility:=[];
           end
         else
           begin
             { may happen in case of function results }
             case Left.Location.Loc of
               LOC_CREGISTER,
               LOC_REGISTER:
                 begin
                   if not(Is_ConstNode(Right)) or (TArrayDef(Left.ResultDef).ElementDef.Size<>ALUSIntType.Size) then
                     begin
                       hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);
                       Location_Copy(Location,Left.Location);
                     end
                   else
                     { we use location here only to get the right offset }
                     Location_Reset_Ref(Location,LOC_REFERENCE,OS_NO,1,[]);
                 end;
               LOC_CSUBSETREG,
               LOC_CMMREGISTER,
               LOC_SUBSETREG,
               LOC_MMREGISTER:
                 begin
                   hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);
                   Location_Copy(Location,Left.Location);
                 end;
               LOC_CONSTANT:  { Usually 'nil' }
                 begin
                   hlcg.Reference_Reset_Base(Location.Reference,Left.ResultDef,NR_NO,Left.Location.Value,CTempPosInvalid,Location.Reference.Alignment,[]);
                 end;
               LOC_INVALID:
                 InternalError(2019061101);
               else
                 Location_Copy(Location,Left.Location);
             end;
           end;

         { location must be memory }
         if not(Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
           InternalError(200411013);

         { offset can only differ from 0 if arraydef }
         if (Left.ResultDef.typ=arraydef) and
            not(Is_Dynamic_Array(Left.ResultDef)) and
            (not(Is_Packed_Array(Left.ResultDef)) or
             ((lElementSize mod 8 = 0) and
              IsPowerOf2(lElementSize div 8,lTemp)) or
              { only orddefs are bitpacked }
              not Is_Ordinal(ResultDef)
{$ifndef cpu64bitalu}
              or Is_64BitInt(ResultDef)
{$endif not cpu64bitalu}
              ) then
           Update_Reference_Offset(Location.Reference,-TArrayDef(Left.ResultDef).LowRange,lByteElementSize);

         if Right.NodeType=ordconstn then
           begin
              { offset can only differ from 0 if arraydef }
              if cs_check_range in CurrentSettings.LocalSwitches then
                begin
                  SecondPass(Right);
                  case Left.ResultDef.typ of
                    arraydef :
                      RangeCheckArray;
                    stringdef :
                      RangeCheckString;
                    else
                      ;
                  end;
                end;
              if not(Is_Packed_Array(Left.ResultDef)) or
                 ((lElementSize mod 8 = 0) and
                  (IsPowerOf2(lElementSize div 8,lTemp) or
                   { only orddefs are bitpacked }
                   not Is_Ordinal(ResultDef))) then
                begin
                  lExtraOffset:=TOrdConstNode(Right).Value.svalue;
                  Update_Reference_Offset(Location.Reference,lExtraOffset,lByteElementSize);
                  { adjust alignment after this change }
                  Location.Reference.Alignment:=NewAlignment(Location.Reference.Alignment,lExtraOffset*lByteElementSize);

                  { actually an array in a register? }
                  if (Left.Location.Loc in [LOC_CREGISTER,LOC_REGISTER]) and
                    Is_Normal_Array(Left.ResultDef) then
                    begin
{$if defined(cpu64bitalu)}
                      lReg:=Left.Location.Register;
{$else defined(cpu64bitalu)}
                      begin
                          if Location.Reference.Offset>3 then
                            lReg:=Left.Location.Register64.RegHi
                          else
                            lReg:=Left.Location.Register64.RegLo;
                        end;
{$endif defined(cpu64bitalu)}

                      Location_Reset(Location,Left.Location.Loc,Def_CGSize(TArrayDef(Left.ResultDef).ElementDef));
                      Location.Register:=lReg;
                    end;
                end
              else
                begin
                  lSubsetRef.Ref := Location.Reference;
                  lSubsetRef.Ref.Alignment := Left.ResultDef.Alignment;
                  if not IsPowerOf2(PackedBitsLoadSize(ResultDef.PackedBitSize),lTemp) then
                    InternalError(2006081212);
                  lAlignPower:=lTemp;
                  Update_Reference_Offset(lSubsetRef.Ref,(lElementSize * (TOrdConstNode(Right).Value.svalue-TArrayDef(Left.ResultDef).LowRange)) shr (3+lAlignPower),1 shl lAlignPower);
                  lSubsetRef.BitIndexReg := NR_NO;
                  lSubsetRef.StartBit := (lElementSize * (TOrdConstNode(Right).Value.svalue-TArrayDef(Left.ResultDef).LowRange)) and ((1 shl (3+lAlignPower))-1);
                  lSubsetRef.BitLen := ResultDef.PackedBitSize;
                  if (Left.Location.Loc = LOC_REFERENCE) then
                    Location.Loc := LOC_SUBSETREF
                  else
                    Location.Loc := LOC_CSUBSETREF;
                  Location.SRef := lSubsetRef;
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
                 (Left.ResultDef.typ=arraydef) and
                 not Is_Packed_Array(Left.ResultDef) then
                begin
                   lExtraOffset:=0;
                   lRightNode:=ActualTargetNode(@Right);
                   if lRightNode^.NodeType=addn then
                     begin
                        if TAddNode(lRightNode^).Right.NodeType=ordconstn then
                          begin
                            lExtraOffset:=TOrdConstNode(TAddNode(lRightNode^).Right).Value.svalue;
                            ReplaceNode(lRightNode^,TAddNode(lRightNode^).Left);
                          end
                        else if TAddNode(lRightNode^).Left.NodeType=ordconstn then
                          begin
                            lExtraOffset:=TOrdConstNode(TAddNode(lRightNode^).Left).Value.svalue;
                            ReplaceNode(lRightNode^,TAddNode(lRightNode^).Right);
                          end;
                     end
                   else if lRightNode^.NodeType=subn then
                     begin
                        if TAddNode(lRightNode^).Right.NodeType=ordconstn then
                          begin
                            lExtraOffset:=-TOrdConstNode(TAddNode(lRightNode^).Right).Value.svalue;
                            ReplaceNode(lRightNode^,TAddNode(lRightNode^).Left);
                          end;
                     end;
                   Update_Reference_Offset(Location.Reference,lExtraOffset,lElementSize);
                end;
              { calculate from left to right }
              if not(Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
                InternalError(200304237);
              SecondPass(Right);
              if (Right.ExpectLoc=LOC_JUMP)<>
                 (Right.Location.Loc=LOC_JUMP) then
                InternalError(2006010801);

              { if mulsize = 1, we won't have to modify the index }
              if not(Right.Location.Loc in [LOC_CREGISTER,LOC_REGISTER]) or
                 not Valid_Index_Size(Right.Location.Size) then
                begin
                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,SizeUIntType,true);
                  lIndexDef:=SizeUIntType
                end
              else
                lIndexDef:=Right.ResultDef;

            { produce possible range check code: }
              if cs_check_range in CurrentSettings.LocalSwitches then
               begin
                 if Left.ResultDef.typ=arraydef then
                   RangeCheckArray
                 else if (Left.ResultDef.typ=stringdef) then
                   RangeCheckString;
               end;

              { insert the register and the multiplication factor in the
                reference }
              if not Is_Packed_Array(Left.ResultDef) then
                Update_Reference_Reg_Mul(Right.Location.Register,lIndexDef,lElementSize)
              else
                Update_Reference_Reg_Packed(Right.Location.Register,lIndexDef,lElementSize);
           end;

        Location.Size:=lNewSize;
        lParaLoc1.done;
        lParaLoc2.done;
      end;


begin
   CLoadVMTAddrNode:=TCGLoadVMTAddrNode;
   CLoadParentFPNode:=TCGLoadParentFPNode;
   CAddrNode:=TCGAddrNode;
   CDerefNode:=TCGDerefNode;
   CSubscriptNode:=TCGSubscriptNode;
   CVecNode:=TCGVecNode;
end.
