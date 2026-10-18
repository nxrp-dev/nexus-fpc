{
    Copyright (c) 2002 by Florian Klaempfl

    This unit implements the code generator for the x86-64.

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
unit cgcpu;

{$i fpcdefs.inc}

  interface

    uses
       cgbase,cgutils,cgobj,cgx86,
       aasmbase,aasmtai,AAsmData,aasmcpu,
       cpubase,parabase,
       symdef,
       symconst,rgx86,ProcInfo;

    type
      TCGX8664 = class(TCGX86)
        procedure Init_Register_Allocators;override;

        procedure A_LoadFPU_Ref_CGPara(list: TAsmList; size: TCgSize; const ref: TReference; const cgpara: TCGPara); override;
        procedure A_LoadFPU_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference); override;

        procedure G_Proc_Entry(list : TAsmList;localsize:LongInt; nostackframe:boolean);override;
        procedure G_Proc_Exit(list : TAsmList;parasize:LongInt;nostackframe:boolean);override;
        procedure G_Local_Unwind(list: TAsmList; l: TAsmLabel);override;
        procedure G_Save_Registers(list: TAsmList);override;
        procedure G_Restore_Registers(list: TAsmList);override;

        procedure A_LoadMM_IntReg_Reg(list: TAsmList; fromsize, tosize : TCgSize;intreg, mmreg: TRegister; shuffle: PMMShuffle); override;
        procedure A_LoadMM_Reg_IntReg(list: TAsmList; fromsize, tosize : TCgSize;mmreg, intreg: TRegister;shuffle : PMMShuffle); override;

        function use_ms_abi: boolean;
      private
        function use_push: boolean;
        function saved_xmm_reg_size: LongInt;
      end;

    procedure create_codegen;

  implementation

    uses
       GlobType,Globals,Verbose,Systems,CUtils,CClasses,
       CPUInfo,
       SymTable,paramgr,cpupi,
       rgcpu,ncgutil;


    procedure TCGX8664.Init_Register_Allocators;
      var
        ms_abi: boolean;
      begin
        inherited Init_Register_Allocators;

        ms_abi:=use_ms_abi;
        if ms_abi then
          begin
            if (cs_userbp in CurrentSettings.OptimizerSwitches) and Assigned(CurrentProcInfo) and (CurrentProcInfo.FramePointer=NR_STACK_POINTER_REG) then
              begin
                rg[R_INTREGISTER]:=TRGCPU.Create(R_INTREGISTER,R_SUBWHOLE,[RS_RAX,RS_RDX,RS_RCX,RS_R8,RS_R9,RS_R10,
                  RS_R11,RS_RBX,RS_RSI,RS_RDI,RS_R12,RS_R13,RS_R14,RS_R15,RS_RBP],first_int_imreg,[]);
              end
            else
              rg[R_INTREGISTER]:=TRGCPU.Create(R_INTREGISTER,R_SUBWHOLE,[RS_RAX,RS_RDX,RS_RCX,RS_R8,RS_R9,RS_R10,
                RS_R11,RS_RBX,RS_RSI,RS_RDI,RS_R12,RS_R13,RS_R14,RS_R15],first_int_imreg,[])
          end
        else
          rg[R_INTREGISTER]:=TRGCPU.Create(R_INTREGISTER,R_SUBWHOLE,[RS_RAX,RS_RDX,RS_RCX,RS_RSI,RS_RDI,RS_R8,
            RS_R9,RS_R10,RS_R11,RS_RBX,RS_R12,RS_R13,RS_R14,RS_R15],first_int_imreg,[]);

        if FPUX86_HAS_32MMREGS in fpu_capabilities[CurrentSettings.FPUType] then
          rg[R_MMREGISTER]:=TRGCPU.Create(R_MMREGISTER,R_SUBWHOLE,[RS_XMM0,RS_XMM1,RS_XMM2,RS_XMM3,RS_XMM4,RS_XMM5,RS_XMM6,RS_XMM7,
            RS_XMM8,RS_XMM9,RS_XMM10,RS_XMM11,RS_XMM12,RS_XMM13,RS_XMM14,RS_XMM15,RS_XMM16,RS_XMM17,RS_XMM18,RS_XMM19,RS_XMM20,
            RS_XMM21,RS_XMM22,RS_XMM23,RS_XMM24,RS_XMM25,RS_XMM26,RS_XMM27,RS_XMM28,RS_XMM29,RS_XMM30,RS_XMM31],first_mm_imreg,[])
        else
          rg[R_MMREGISTER]:=TRGCPU.Create(R_MMREGISTER,R_SUBWHOLE,[RS_XMM0,RS_XMM1,RS_XMM2,RS_XMM3,RS_XMM4,RS_XMM5,RS_XMM6,RS_XMM7,
            RS_XMM8,RS_XMM9,RS_XMM10,RS_XMM11,RS_XMM12,RS_XMM13,RS_XMM14,RS_XMM15],first_mm_imreg,[]);
        rgfpu:=TRGX86FPU.Create;
      end;


    procedure TCGX8664.A_LoadFPU_Ref_CGPara(list: TAsmList; size: TCgSize; const ref: TReference; const cgpara: TCGPara);
      begin
        { a record containing an extended value is returned on the x87 stack
          -> size will be OS_F128 (if not packed), while cgpara.paraloc^.size
          contains the proper size

          In the future we should probably always use cgpara.location^.size, but
          that should only be tested/done after 2.8 is branched }
        if size in [OS_128,OS_F128] then
          size:=cgpara.Location^.Size;
        inherited;
      end;


    procedure TCGX8664.A_LoadFPU_Reg_Ref(list: TAsmList; fromsize, tosize: TCgSize; reg: TRegister; const ref: TReference);
      begin
        { same as with a_loadfpu_ref_cgpara() above, but on the callee side
          when the value is moved from the fpu register into a memory location }
        if tosize in [OS_128,OS_F128] then
          tosize:=OS_F80;
        inherited;
      end;


    function TCGX8664.use_push: boolean;
      begin
        result:=(CurrentProcInfo.FramePointer=NR_STACK_POINTER_REG) or
          (CurrentProcInfo.procdef.ProcTypeOption=potype_exceptfilter);
      end;


    function TCGX8664.saved_xmm_reg_size: LongInt;
      var
        i: LongInt;
        regs_to_save_mm: TCPURegisterArray;
      begin
        result:=0;
        if (TargetInfo.system<>system_x86_64_win64) or
           (not Uses_Registers(R_MMREGISTER)) then
          exit;
        regs_to_save_mm:=ParaManager.Get_Saved_Registers_MM(CurrentProcInfo.procdef.ProcCallOption);
        for i:=low(regs_to_save_mm) to high(regs_to_save_mm) do
          begin
            if (regs_to_save_mm[i] in rg[R_MMREGISTER].UsedInProc) then
              inc(result,TCgSize2Size[OS_VECTOR]);
          end;
      end;


    procedure TCGX8664.G_Proc_Entry(list : TAsmList;localsize:LongInt;nostackframe:boolean);
      var
        hitem: TLinkedListItem;
        seh_proc: TAISEHDirective;
        regsize: LongInt;
        r: integer;
        href: TReference;
        TempList: TAsmList;
        frame_offset: LongInt;
        suppress_endprologue: boolean;
        stackmisalignment: LongInt;
        xmmsize: LongInt;
        regs_to_save_int,
        regs_to_save_mm: TCPURegisterArray;

      procedure push_one_reg(reg: TRegister);
        begin
          list.concat(TAICPU.op_reg(A_PUSH,tcgsize2opsize[OS_ADDR],reg));
          if (TargetInfo.system=system_x86_64_win64) then
            begin
              list.concat(CAISEHDirective.create_reg(ash_pushreg,reg));
              include(CurrentProcInfo.flags,pi_has_unwind_info);
            end;
        end;

      procedure push_regs;
        var
          r: LongInt;
          usedregs: TCPURegisterSet;
          hreg: TRegister;
        begin
          usedregs:=rg[R_INTREGISTER].UsedInProc-ParaManager.Get_Volatile_Registers_Int(CurrentProcInfo.procdef.ProcCallOption);
          for r := low(regs_to_save_int) to high(regs_to_save_int) do
            if regs_to_save_int[r] in usedregs then
              begin
                inc(regsize,sizeof(aint));
                inc(stackmisalignment,sizeof(aint));
                hreg:=NewReg(R_INTREGISTER,regs_to_save_int[r],R_SUBWHOLE);
                push_one_reg(hreg);
                if CurrentProcInfo.FramePointer<>NR_STACK_POINTER_REG then
                  CurrentAsmData.asmcfi.cfa_offset(list,hreg,-(regsize+sizeof(PInt)*2+localsize))
                else
                  begin
                    CurrentAsmData.asmcfi.cfa_offset(list,hreg,-(regsize+sizeof(PInt)+localsize));
                    CurrentAsmData.asmcfi.cfa_def_cfa_offset(list,regsize+sizeof(PInt)+localsize);
                  end;
              end;
        end;

      begin
        regsize:=0;
        regs_to_save_int:=ParaManager.Get_Saved_Registers_Int(CurrentProcInfo.procdef.ProcCallOption);
        regs_to_save_mm:=ParaManager.Get_Saved_Registers_MM(CurrentProcInfo.procdef.ProcCallOption);
        hitem:=list.last;
        { pi_has_unwind_info may already be set at this point if there are
          SEH directives in assembler body. In this case, .seh_endprologue
          is expected to be one of those directives, and not generated here. }
        suppress_endprologue:=(pi_has_unwind_info in CurrentProcInfo.flags);

        list.concat(TAIRegAlloc.alloc(NR_STACK_POINTER_REG,nil));

        { save old framepointer }
        if not nostackframe then
          begin
            { return address }
            stackmisalignment := sizeof(PInt);
            if CurrentProcInfo.FramePointer=NR_STACK_POINTER_REG then
              begin
                push_regs;
                CGMessage(cg_d_stackframe_omited);
              end
            else
              begin
                list.concat(TAIRegAlloc.alloc(CurrentProcInfo.FramePointer,nil));
                { push <frame_pointer> }
                inc(stackmisalignment,sizeof(PInt));
                push_one_reg(NR_FRAME_POINTER_REG);
                { Return address and FP are both on stack }
                CurrentAsmData.asmcfi.cfa_def_cfa_offset(list,2*sizeof(PInt));
                CurrentAsmData.asmcfi.cfa_offset(list,NR_FRAME_POINTER_REG,-(2*sizeof(PInt)));
                if CurrentProcInfo.procdef.ProcTypeOption<>potype_exceptfilter then
                  list.concat(TAICPU.op_reg_reg(A_MOV,tcgsize2opsize[OS_ADDR],NR_STACK_POINTER_REG,NR_FRAME_POINTER_REG))
                else
                  begin
                    push_regs;
                    Gen_Load_Frame_For_ExceptFilter(list);
                    { Need only as much stack space as necessary to do the calls.
                      Exception filters don't have own local vars, and temps are 'mapped'
                      to the parent procedure.
                      maxpushedparasize is already aligned at least on x86_64. }
                    localsize:=CurrentProcInfo.MaxPushedParaSize;
                  end;
                CurrentAsmData.asmcfi.cfa_def_cfa_register(list,NR_FRAME_POINTER_REG);
                {
                  TODO: current framepointer handling is not compatible with Win64 at all:
                  Win64 expects FP to point to the top or into the middle of local area.
                  In FPC it points to the bottom, making it impossible to generate
                  UWOP_SET_FPREG unwind code if local area is > 240 bytes.
                  So for now pretend we never have a framepointer.
                }
              end;

            xmmsize:=saved_xmm_reg_size;
            if use_push and (xmmsize<>0) then
              begin
                localsize:=align(localsize,TargetInfo.stackalign)+xmmsize;
                Reference_Reset_Base(CurrentProcInfo.SaveRegsRef,NR_STACK_POINTER_REG,
                  localsize-xmmsize,CTempPosInvalid,TCgSize2Size[OS_VECTOR],[]);
              end;

            { allocate stackframe space }
            if (localsize<>0) or
               ((TargetInfo.stackalign>sizeof(PInt)) and
                (stackmisalignment <> 0) and
                ((pi_do_call in CurrentProcInfo.flags) or
                 (po_assembler in CurrentProcInfo.procdef.ProcOptions))) then
              begin
                if TargetInfo.stackalign>sizeof(PInt) then
                  localsize := align(localsize+stackmisalignment,TargetInfo.stackalign)-stackmisalignment;
                G_StackPointer_Alloc(list,localsize);
                if CurrentProcInfo.FramePointer=NR_STACK_POINTER_REG then
                  CurrentAsmData.asmcfi.cfa_def_cfa_offset(list,regsize+localsize+sizeof(PInt));
                CurrentProcInfo.FinalLocalSize:=localsize;
                if (TargetInfo.system=system_x86_64_win64) then
                  begin
                    if localsize<>0 then
                      list.concat(CAISEHDirective.create_offset(ash_stackalloc,localsize));
                    include(CurrentProcInfo.flags,pi_has_unwind_info);
                    if use_push and (xmmsize<>0) then
                      begin
                        href:=CurrentProcInfo.SaveRegsRef;
                        for r:=low(regs_to_save_mm) to high(regs_to_save_mm) do
                          if regs_to_save_mm[r] in rg[R_MMREGISTER].UsedInProc then
                            begin
                              A_LoadMM_Reg_Ref(list,OS_VECTOR,OS_VECTOR,NewReg(R_MMREGISTER,regs_to_save_mm[r],R_SUBMMWHOLE),href,nil);
                              inc(href.Offset,TCgSize2Size[OS_VECTOR]);
                            end;
                      end;
                  end;
               end;
          end;

        if not (pi_has_unwind_info in CurrentProcInfo.flags) then
          exit;
        { Generate unwind data for x86_64-win64 }
        seh_proc:=CAISEHDirective.create_name(ash_proc,CurrentProcInfo.procdef.MangledName);
        if Assigned(hitem) then
          list.insertafter(seh_proc,hitem)
        else
          list.insert(seh_proc);
        { the directive creates another section }
        inc(list.section_count);
        TempList:=TAsmList.Create;

        { We need to record positive offsets from RSP; if registers are saved
          at negative offsets from RBP we need to account for it. }
        if (not use_push) then
          frame_offset:=CurrentProcInfo.FinalLocalSize
        else
          frame_offset:=0;

        { There's no need to describe position of register saves precisely;
          since registers are not modified before they are saved, and saves do not
          change RSP, 'logically' all saves can happen at the end of prologue. }
        href:=CurrentProcInfo.SaveRegsRef;
        if (not use_push) then
          begin
            for r:=low(regs_to_save_int) to high(regs_to_save_int) do
              if regs_to_save_int[r] in rg[R_INTREGISTER].UsedInProc then
                begin
                  TempList.concat(CAISEHDirective.create_reg_offset(ash_savereg,
                    NewReg(R_INTREGISTER,regs_to_save_int[r],R_SUBWHOLE),
                    href.Offset+frame_offset));
                 inc(href.Offset,sizeof(aint));
                end;
          end;
        if Uses_Registers(R_MMREGISTER) then
          begin
            if (href.Offset mod TCgSize2Size[OS_VECTOR])<>0 then
              inc(href.Offset,TCgSize2Size[OS_VECTOR]-(href.Offset mod TCgSize2Size[OS_VECTOR]));

            for r:=low(regs_to_save_mm) to high(regs_to_save_mm) do
              begin
                if regs_to_save_mm[r] in rg[R_MMREGISTER].UsedInProc then
                  begin
                    TempList.concat(CAISEHDirective.create_reg_offset(ash_savexmm,
                      NewReg(R_MMREGISTER,regs_to_save_mm[r],R_SUBMMWHOLE),
                      href.Offset+frame_offset));
                    inc(href.Offset,TCgSize2Size[OS_VECTOR]);
                  end;
              end;
          end;
        if not suppress_endprologue then
          TempList.concat(CAISEHDirective.Create(ash_endprologue));
        if Assigned(CurrentProcInfo.EndPrologueAI) then
          CurrentProcInfo.AktProcCode.InsertListAfter(CurrentProcInfo.EndPrologueAI,TempList)
        else
          list.ConcatList(TempList);
        TempList.free;
      end;


    procedure TCGX8664.G_Proc_Exit(list : TAsmList;parasize:LongInt;nostackframe:boolean);

      procedure increase_sp(a : TCGInt);
        var
          href : TReference;
        begin
          if a=8 then
            list.concat(TAICPU.op_reg(A_POP,TCGSize2OpSize[OS_ADDR],NR_RCX))
          else
            begin
              Reference_Reset_Base(href,NR_STACK_POINTER_REG,a,CTempPosInvalid,0,[]);
              { normally, lea is a better choice than an add }
              list.concat(TAICPU.op_ref_reg(A_LEA,TCGSize2OpSize[OS_ADDR],href,NR_STACK_POINTER_REG));
            end;
        end;

      var
        href : TReference;
        hreg : TRegister;
        r : LongInt;
        regs_to_save_mm: TCPURegisterArray;
      begin
        { we do not need an exit stack frame when we never return
                * the final ret is left so the peephole optimizer can easily do call/ret -> jmp or call conversions
                * the entry stack frame must be normally generated because the subroutine could be still left by
                  an exception and then the unwinding code might need to restore the registers stored by the entry code
        }
        if not(po_noreturn in CurrentProcInfo.procdef.ProcOptions) then
          begin
            regs_to_save_mm:=ParaManager.Get_Saved_Registers_MM(CurrentProcInfo.procdef.ProcCallOption);
            { Prevent return address from a possible call from ending up in the epilogue }
            { (restoring registers happens before epilogue, providing necessary padding) }
            if (CurrentProcInfo.flags*[pi_has_unwind_info,pi_do_call,pi_has_saved_regs])=[pi_has_unwind_info,pi_do_call] then
              list.concat(TAICPU.op_none(A_NOP));
            { remove stackframe }
            if not(nostackframe) then
              begin
                if use_push then
                  begin
                    if (saved_xmm_reg_size<>0) then
                      begin
                        href:=CurrentProcInfo.SaveRegsRef;
                        for r:=low(regs_to_save_mm) to high(regs_to_save_mm) do
                          if regs_to_save_mm[r] in rg[R_MMREGISTER].UsedInProc then
                            begin
                              { Allocate register so the optimizer does not remove the load }
                              hreg:=NewReg(R_MMREGISTER,regs_to_save_mm[r],R_SUBMMWHOLE);
                              A_Reg_Alloc(list,hreg);
                              A_LoadMM_Ref_Reg(list,OS_VECTOR,OS_VECTOR,href,hreg,nil);
                              inc(href.Offset,TCgSize2Size[OS_VECTOR]);
                            end;
                      end;

                    if (CurrentProcInfo.FinalLocalSize<>0) then
                      increase_sp(CurrentProcInfo.FinalLocalSize);
                    internal_restore_regs(list,true);

                    if (CurrentProcInfo.procdef.ProcTypeOption=potype_exceptfilter) then
                      list.concat(TAICPU.op_reg(A_POP,tcgsize2opsize[OS_ADDR],NR_FRAME_POINTER_REG));
                    CurrentAsmData.asmcfi.cfa_def_cfa_offset(list,sizeof(PInt));
                  end
                else if (TargetInfo.system=system_x86_64_win64) then
                  begin
                    { Comply with Win64 unwinding mechanism, which only recognizes
                      'add $constant,%rsp' and 'lea offset(FPREG),%rsp' as belonging to
                      the function epilog.
                      Neither 'leave' nor even 'mov %FPREG,%rsp' are allowed. }
                    Reference_Reset_Base(href,CurrentProcInfo.FramePointer,0,CTempPosInvalid,sizeof(PInt),[]);
                    list.concat(TAICPU.op_ref_reg(A_LEA,tcgsize2opsize[OS_ADDR],href,NR_STACK_POINTER_REG));
                    list.concat(TAICPU.op_reg(A_POP,tcgsize2opsize[OS_ADDR],CurrentProcInfo.FramePointer));
                  end
                else
                  generate_leave(list);
                list.concat(TAIRegAlloc.dealloc(CurrentProcInfo.FramePointer,nil));
              end;

            if pi_uses_ymm in CurrentProcInfo.flags then
              list.Concat(TAICPU.op_none(A_VZEROUPPER));
          end;

        if CurrentProcInfo.FramePointer<>NR_STACK_POINTER_REG then
          list.concat(TAIRegAlloc.dealloc(NR_STACK_POINTER_REG,nil));

        list.concat(TAICPU.Op_none(A_RET,S_NO));

        if (pi_has_unwind_info in CurrentProcInfo.flags) then
          begin
            TCPUProcInfo(CurrentProcInfo).Dump_Scopes(list);
            list.concat(CAISEHDirective.Create(ash_endproc));
          end;
      end;


    procedure TCGX8664.G_Save_Registers(list: TAsmList);
      begin
        if (not use_push) then
          inherited G_Save_Registers(list);
      end;


    procedure TCGX8664.G_Restore_Registers(list: TAsmList);
      begin
        if (not use_push) then
          inherited G_Restore_Registers(list);
      end;


    procedure TCGX8664.G_Local_Unwind(list: TAsmList; l: TAsmLabel);
      var
        para1,para2: TCGPara;
        href: TReference;
        pd: TProcDef;
      begin
        if (TargetInfo.system<>system_x86_64_win64) then
          begin
            inherited G_Local_Unwind(list,l);
            exit;
          end;
        pd:=Search_System_Proc('_fpc_local_unwind');
        para1.init;
        para2.init;
        ParaManager.GetCGTempParaLoc(list,pd,1,para1);
        ParaManager.GetCGTempParaLoc(list,pd,2,para2);
        Reference_Reset_Symbol(href,l,0,1,[]);
        { TODO: using RSP is correct only while the stack is fixed!!
          (true now, but will change if/when allocating from stack is implemented) }
        A_Load_Reg_CGPara(list,OS_ADDR,NR_STACK_POINTER_REG,para1);
        A_LoadAddr_Ref_CGPara(list,href,para2);
        ParaManager.FreeCGPara(list,para2);
        ParaManager.FreeCGPara(list,para1);
        G_Call(list,'_FPC_local_unwind');
        para2.done;
        para1.done;
      end;

    procedure TCGX8664.A_LoadMM_IntReg_Reg(list: TAsmList; fromsize, tosize : TCgSize; intreg, mmreg: TRegister; shuffle: PMMShuffle);
      var
        opc: TAsmOp;
      begin
        { this code can only be used to transfer raw data, not to perform
          conversions }
        if (TCgSize2Size[fromsize]<>TCgSize2Size[tosize]) or
           not(tosize in [OS_F32,OS_F64,OS_M64]) then
          InternalError(2009112505);
        case fromsize of
          OS_32,OS_S32:
            if UseAVX then
              opc:=A_VMOVD
            else
              opc:=A_MOVD;
          OS_64,OS_S64:
            if UseAVX then
              opc:=A_VMOVQ
            else
              opc:=A_MOVQ;
          else
            InternalError(2009112506);
        end;
        if Assigned(shuffle) and
           not ShuffleScalar(shuffle) then
          InternalError(2009112517);
        list.concat(TAICPU.op_reg_reg(opc,S_NO,intreg,mmreg));
      end;


    procedure TCGX8664.A_LoadMM_Reg_IntReg(list: TAsmList; fromsize, tosize : TCgSize; mmreg, intreg: TRegister;shuffle : PMMShuffle);
      var
        opc: TAsmOp;
      begin
        { this code can only be used to transfer raw data, not to perform
          conversions }
        if (TCgSize2Size[fromsize]<>TCgSize2Size[tosize]) or
           not (fromsize in [OS_F32,OS_F64,OS_M64]) then
          InternalError(2009112507);
        case tosize of
          OS_32,OS_S32:
            if UseAVX then
              opc:=A_VMOVD
            else
              opc:=A_MOVD;
          OS_64,OS_S64:
            if UseAVX then
              opc:=A_VMOVQ
            else
              opc:=A_MOVQ;
          else
            InternalError(2009112408);
        end;
        if Assigned(shuffle) and
           not ShuffleScalar(shuffle) then
          InternalError(2009112515);
        list.concat(TAICPU.op_reg_reg(opc,S_NO,mmreg,intreg));
      end;


    function TCGX8664.Use_MS_ABI: boolean;
      begin
        if Assigned(CurrentProcInfo) then
          use_ms_abi:=X86_64_Use_MS_ABI(CurrentProcInfo.procdef.ProcCallOption)
        else
          use_ms_abi:=TargetInfo.system=system_x86_64_win64;
      end;


    procedure create_codegen;
      begin
        cg:=TCGX8664.Create;
        cg128:=TCG128.Create;
      end;

end.
