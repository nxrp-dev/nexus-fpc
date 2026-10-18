{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements the code generator for the i386

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
       GlobType,
       cgbase,cgobj,cg64f32,cgx86,
       aasmbase,aasmtai,AAsmData,aasmcpu,
       cpubase,parabase,cgutils,
       symconst,symdef,SymSym
       ;

    type
      TCG386 = class(TCGX86)
        procedure Init_Register_Allocators;override;

        { passing parameter using push instead of mov }
        procedure A_Load_Reg_CGPara(list : TAsmList;size : TCgSize;r : TRegister;const cgpara : TCGPara);override;
        procedure A_Load_Const_CGPara(list : TAsmList;size : TCgSize;a : TCGInt;const cgpara : TCGPara);override;
        procedure A_Load_Ref_CGPara(list : TAsmList;size : TCgSize;const r : TReference;const cgpara : TCGPara);override;
        procedure A_LoadAddr_Ref_CGPara(list : TAsmList;const r : TReference;const cgpara : TCGPara);override;

        procedure G_Proc_Exit(list : TAsmList;parasize:LongInt;nostackframe:boolean);override;
        procedure G_CopyValuePara_OpenArray(list : TAsmList;const ref:TReference;const lenloc:TLocation;EleSize:TCGInt;destreg:TRegister);
        procedure G_ReleaseValuePara_OpenArray(list : TAsmList;const l:TLocation);

        procedure G_Maybe_Got_Init(list: TAsmList); override;
     end;

      TCG64F386 = class(TCG64F32)
        procedure A_Op64_Ref_Reg(list : TAsmList;op:TOpCG;size : TCgSize;const ref : TReference;reg : TRegister64);override;
        procedure A_Op64_Reg_Ref(list : TAsmList;op:TOpCG;size : TCgSize;reg : TRegister64; const ref: TReference);override;
        procedure A_Op64_Reg_Reg(list : TAsmList;op:TOpCG;size : TCgSize;regsrc,regdst : TRegister64);override;
        procedure A_Op64_Const_Reg(list : TAsmList;op:TOpCG;size : TCgSize;value : int64;reg : TRegister64);override;
        procedure A_Op64_Const_Ref(list : TAsmList;op:TOpCG;size : TCgSize;value : int64;const ref : TReference);override;
        procedure A_Op64_Ref(list : TAsmList;op:TOpCG;size : TCgSize;const ref: TReference);override;
      private
        procedure get_64bit_ops(op:TOpCG;var op1,op2:TAsmOp);
      end;

    procedure create_codegen;

  implementation

    uses
       Globals,Verbose,Systems,CUtils,
       paramgr,ProcInfo,FModule,
       rgcpu,rgx86,CPUInfo;

    function use_push(const cgpara:TCGPara):boolean;
      begin
        result:=(not ParaManager.Use_Fixed_Stack) and
                Assigned(cgpara.Location) and
                (cgpara.Location^.Loc=LOC_REFERENCE) and
                (cgpara.Location^.Reference.Index=NR_STACK_POINTER_REG);
      end;


    procedure TCG386.Init_Register_Allocators;
      begin
        inherited Init_Register_Allocators;

        if Assigned(CurrentProcInfo) and (CurrentProcInfo.FramePointer<>NR_EBP) then
          begin
            { Sometimes, whole program optimization will forego a frame pointer on leaf functions }
            if (cs_useebp in CurrentSettings.OptimizerSwitches) then
              rg[R_INTREGISTER]:=TRGCPU.Create(R_INTREGISTER,R_SUBWHOLE,[RS_EAX,RS_EDX,RS_ECX,RS_EBX,RS_ESI,RS_EDI,RS_EBP],first_int_imreg,[])
            else
              rg[R_INTREGISTER]:=TRGCPU.Create(R_INTREGISTER,R_SUBWHOLE,[RS_EAX,RS_EDX,RS_ECX,RS_EBX,RS_ESI,RS_EDI],first_int_imreg,[]);
          end
        else
          rg[R_INTREGISTER]:=TRGCPU.Create(R_INTREGISTER,R_SUBWHOLE,[RS_EAX,RS_EDX,RS_ECX,RS_EBX,RS_ESI,RS_EDI],first_int_imreg,[RS_EBP]);

        rg[R_MMXREGISTER]:=TRGCPU.Create(R_MMXREGISTER,R_SUBNONE,[RS_XMM0,RS_XMM1,RS_XMM2,RS_XMM3,RS_XMM4,RS_XMM5,RS_XMM6,RS_XMM7],first_mm_imreg,[]);
        rg[R_MMREGISTER]:=TRGCPU.Create(R_MMREGISTER,R_SUBWHOLE,[RS_XMM0,RS_XMM1,RS_XMM2,RS_XMM3,RS_XMM4,RS_XMM5,RS_XMM6,RS_XMM7],first_mm_imreg,[]);
        rgfpu:=TRGX86FPU.Create;
      end;


    procedure TCG386.A_Load_Reg_CGPara(list : TAsmList;size : TCgSize;r : TRegister;const cgpara : TCGPara);
      var
        pushsize : TCgSize;
      begin
        check_register_size(size,r);
        if use_push(cgpara) then
          begin
            cgpara.Check_Simple_Location;
            if TCgSize2Size[cgpara.Location^.Size]>cgpara.Alignment then
              pushsize:=cgpara.Location^.Size
            else
              pushsize:=Int_CGSize(cgpara.Alignment);
            list.concat(TAICPU.op_reg(A_PUSH,tcgsize2opsize[pushsize],MakeRegSize(list,r,pushsize)));
          end
        else
          inherited A_Load_Reg_CGPara(list,size,r,cgpara);
      end;


    procedure TCG386.A_Load_Const_CGPara(list : TAsmList;size : TCgSize;a : TCGInt;const cgpara : TCGPara);
      var
        pushsize : TCgSize;
      begin
        if use_push(cgpara) then
          begin
            cgpara.Check_Simple_Location;
            if TCgSize2Size[cgpara.Location^.Size]>cgpara.Alignment then
              pushsize:=cgpara.Location^.Size
            else
              pushsize:=Int_CGSize(cgpara.Alignment);
            list.concat(TAICPU.op_const(A_PUSH,tcgsize2opsize[pushsize],a));
          end
        else
          inherited A_Load_Const_CGPara(list,size,a,cgpara);
      end;


    procedure TCG386.A_Load_Ref_CGPara(list : TAsmList;size : TCgSize;const r : TReference;const cgpara : TCGPara);

        procedure pushdata(ParaLoc:PCGParaLocation;ofs:TCGInt);
        var
          pushsize : TCgSize;
          opsize : TOpSize;
          tmpreg   : TRegister;
          href     : TReference;
        begin
          if not Assigned(ParaLoc) then
            exit;
          if (ParaLoc^.Loc<>LOC_REFERENCE) or
             (ParaLoc^.Reference.Index<>NR_STACK_POINTER_REG) or
             (TCgSize2Size[ParaLoc^.Size]>sizeof(aint)) then
            InternalError(200501162);
          { Pushes are needed in reverse order, add the size of the
            current location to the offset where to load from. This
            prevents wrong calculations for the last location when
            the size is not a power of 2 }
          if Assigned(ParaLoc^.next) then
            pushdata(ParaLoc^.next,ofs+TCgSize2Size[ParaLoc^.Size]);
          { Push the data starting at ofs }
          href:=r;
          inc(href.Offset,ofs);
          if TCgSize2Size[ParaLoc^.Size]>cgpara.Alignment then
            pushsize:=ParaLoc^.Size
          else
            pushsize:=Int_CGSize(cgpara.Alignment);
          opsize:=TCgsize2opsize[pushsize];
          { for go32v2 we obtain OS_F32,
            but pushs is not valid, we need pushl }
          if opsize=S_FS then
            opsize:=S_L;
          if TCgSize2Size[ParaLoc^.Size]<cgpara.Alignment then
            begin
              tmpreg:=GetIntRegister(list,pushsize);
              A_Load_Ref_Reg(list,ParaLoc^.Size,pushsize,href,tmpreg);
              list.concat(TAICPU.op_reg(A_PUSH,opsize,tmpreg));
            end
          else
            begin
              make_simple_ref(list,href);
              list.concat(TAICPU.op_ref(A_PUSH,opsize,href));
            end;
        end;

      var
        len : TCGInt;
        href : TReference;
      begin
        { cgpara.size=OS_NO requires a copy on the stack }
        if use_push(cgpara) then
          begin
            { Record copy? }
            if (cgpara.Size=OS_NO) or (size=OS_NO) then
              begin
                cgpara.Check_Simple_Location;
                len:=align(cgpara.IntSize,cgpara.Alignment);
                G_StackPointer_Alloc(list,len);
                Reference_Reset_Base(href,NR_STACK_POINTER_REG,0,CTempPosInvalid,4,[]);
                G_ConcatCopy(list,r,href,len);
              end
            else
              begin
                if TCgSize2Size[cgpara.Size]<>TCgSize2Size[size] then
                  InternalError(200501161);
                if (cgpara.Size=OS_F64) then
                  begin
                    href:=r;
                    make_simple_ref(list,href);
                    inc(href.Offset,4);
                    list.concat(TAICPU.op_ref(A_PUSH,S_L,href));
                    dec(href.Offset,4);
                    list.concat(TAICPU.op_ref(A_PUSH,S_L,href));
                  end
                else
                  { We need to push the data in reverse order,
                    therefor we use a recursive algorithm }
                  pushdata(cgpara.Location,0);
              end
          end
        else
          begin
            href:=r;
            make_simple_ref(list,href);
            inherited A_Load_Ref_CGPara(list,size,href,cgpara);
          end;
      end;


    procedure TCG386.A_LoadAddr_Ref_CGPara(list : TAsmList;const r : TReference;const cgpara : TCGPara);
      var
        tmpreg : TRegister;
        opsize : TOpSize;
        tmpref,dirref : TReference;
      begin
        dirref:=r;

        { this could probably done in a more optimized way, but for now this
          is sufficient }
        make_direct_ref(list,dirref);

        with dirref do
          begin
            if use_push(cgpara) then
              begin
                cgpara.Check_Simple_Location;
                opsize:=tcgsize2opsize[OS_ADDR];
                if (segment=NR_NO) and (base=NR_NO) and (index=NR_NO) then
                  begin
                    if Assigned(symbol) then
                      begin
                        if (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) and
                           ((dirref.Symbol.bind in [AB_EXTERNAL,AB_WEAK_EXTERNAL]) or
                            (cs_create_pic in CurrentSettings.ModuleSwitches)) then
                          begin
                            tmpreg:=GetAddressRegister(list);
                            A_LoadAddr_Ref_Reg(list,dirref,tmpreg);
                            list.concat(TAICPU.op_reg(A_PUSH,opsize,tmpreg));
                          end
                        else if cs_create_pic in CurrentSettings.ModuleSwitches then
                          begin
                            if offset<>0 then
                              begin
                                tmpreg:=GetAddressRegister(list);
                                A_LoadAddr_Ref_Reg(list,dirref,tmpreg);
                                list.concat(TAICPU.op_reg(A_PUSH,opsize,tmpreg));
                              end
                            else
                              begin
                                Reference_Reset_Symbol(tmpref,dirref.Symbol,0,sizeof(PInt),[]);
                                tmpref.RefAddr:=addr_pic;
                                tmpref.Base:=CurrentProcInfo.got;
                                include(CurrentProcInfo.flags,pi_needs_got);
                                list.concat(TAICPU.op_ref(A_PUSH,S_L,tmpref));
                              end
                          end
                        else
                          list.concat(TAICPU.Op_sym_ofs(A_PUSH,opsize,symbol,offset));
                      end
                    else
                      list.concat(TAICPU.Op_const(A_PUSH,opsize,offset));
                  end
                else if (segment=NR_NO) and (base=NR_NO) and (index<>NR_NO) and
                        (offset=0) and (ScaleFactor=0) and (symbol=nil) then
                  list.concat(TAICPU.Op_reg(A_PUSH,opsize,index))
                else if (segment=NR_NO) and (base<>NR_NO) and (index=NR_NO) and
                        (offset=0) and (symbol=nil) then
                  list.concat(TAICPU.Op_reg(A_PUSH,opsize,base))
                else
                  begin
                    tmpreg:=GetAddressRegister(list);
                    A_LoadAddr_Ref_Reg(list,dirref,tmpreg);
                    list.concat(TAICPU.op_reg(A_PUSH,opsize,tmpreg));
                  end;
              end
            else
              inherited A_LoadAddr_Ref_CGPara(list,dirref,cgpara);
          end;
      end;


    procedure TCG386.G_Proc_Exit(list : TAsmList;parasize:LongInt;nostackframe:boolean);

      procedure increase_sp(a : TCGInt);
        var
          href : TReference;
        begin
          Reference_Reset_Base(href,NR_STACK_POINTER_REG,a,CTempPosInvalid,0,[]);
          { normally, lea is a better choice than an add }
          list.concat(TAICPU.op_ref_reg(A_LEA,TCGSize2OpSize[OS_ADDR],href,NR_STACK_POINTER_REG));
        end;

      begin
        { MMX needs to call EMMS }
        if Assigned(rg[R_MMXREGISTER]) and
           (rg[R_MMXREGISTER].Uses_Registers) then
          list.concat(TAICPU.op_none(A_EMMS,S_NO));

        { remove stackframe }
        if not(nostackframe) and
          { we do not need an exit stack frame when we never return

            * the final ret is left so the peephole optimizer can easily do call/ret -> jmp or call conversions
            * the entry stack frame must be normally generated because the subroutine could be still left by
              an exception and then the unwinding code might need to restore the registers stored by the entry code
          }
          not(po_noreturn in CurrentProcInfo.procdef.ProcOptions) then
          begin
            if (CurrentProcInfo.FramePointer=NR_STACK_POINTER_REG) or
               (CurrentProcInfo.procdef.ProcTypeOption=potype_exceptfilter) then
              begin
                if CurrentProcInfo.FinalLocalSize<>0 then
                  increase_sp(CurrentProcInfo.FinalLocalSize);
                if (not ParaManager.Use_Fixed_Stack) then
                  internal_restore_regs(list,true);
                if (CurrentProcInfo.procdef.ProcTypeOption=potype_exceptfilter) then
                  list.concat(TAICPU.op_reg(A_POP,tcgsize2opsize[OS_ADDR],NR_FRAME_POINTER_REG));
                CurrentAsmData.asmcfi.cfa_def_cfa_offset(list,sizeof(PInt));
              end
            else
              begin
                if (not ParaManager.Use_Fixed_Stack) then
                  internal_restore_regs(list,not (pi_has_stack_allocs in CurrentProcInfo.flags));
                generate_leave(list);
              end;
            list.concat(TAIRegAlloc.dealloc(CurrentProcInfo.FramePointer,nil));
          end;

        if pi_uses_ymm in CurrentProcInfo.flags then
          list.Concat(TAICPU.op_none(A_VZEROUPPER));

        { return from proc }
        if po_interrupt in CurrentProcInfo.procdef.ProcOptions then
          begin
            if Assigned(CurrentProcInfo.procdef.FuncRetLoc[calleeside].Location) and
               (CurrentProcInfo.procdef.FuncRetLoc[calleeside].Location^.Loc=LOC_REGISTER) then
              begin
                if (GetSupReg(CurrentProcInfo.procdef.FuncRetLoc[calleeside].Location^.Register)=RS_EAX) then
                  list.concat(TAICPU.Op_const_reg(A_ADD,S_L,4,NR_ESP))
                else
                  InternalError(2010053001);
              end
            else
              list.concat(TAICPU.Op_reg(A_POP,S_L,NR_EAX));
            list.concat(TAICPU.Op_reg(A_POP,S_L,NR_EBX));
            list.concat(TAICPU.Op_reg(A_POP,S_L,NR_ECX));

            if (CurrentProcInfo.procdef.FuncRetLoc[calleeside].Size in [OS_64,OS_S64]) and
               Assigned(CurrentProcInfo.procdef.FuncRetLoc[calleeside].Location) and
               Assigned(CurrentProcInfo.procdef.FuncRetLoc[calleeside].Location^.next) and
               (CurrentProcInfo.procdef.FuncRetLoc[calleeside].Location^.next^.Loc=LOC_REGISTER) then
              begin
                if (GetSupReg(CurrentProcInfo.procdef.FuncRetLoc[calleeside].Location^.next^.Register)=RS_EDX) then
                  list.concat(TAICPU.Op_const_reg(A_ADD,S_L,4,NR_ESP))
                else
                  InternalError(2010053002);
              end
            else
              list.concat(TAICPU.Op_reg(A_POP,S_L,NR_EDX));

            list.concat(TAICPU.Op_reg(A_POP,S_L,NR_ESI));
            list.concat(TAICPU.Op_reg(A_POP,S_L,NR_EDI));
            { .... also the segment registers }
            list.concat(TAICPU.Op_reg(A_POP,S_W,NR_DS));
            list.concat(TAICPU.Op_reg(A_POP,S_W,NR_ES));
            list.concat(TAICPU.Op_reg(A_POP,S_W,NR_FS));
            list.concat(TAICPU.Op_reg(A_POP,S_W,NR_GS));
            { this restores the flags }

            if CurrentProcInfo.FramePointer<>NR_STACK_POINTER_REG then
              list.concat(TAIRegAlloc.dealloc(NR_STACK_POINTER_REG,nil));

            list.concat(TAICPU.Op_none(A_IRET,S_NO));
          end
        { Routines with the poclearstack flag set use only a ret }
        else if (CurrentProcInfo.procdef.ProcCallOption in ClearStack_PoCalls) and
                (not ParaManager.Use_Fixed_Stack)  then
         begin
           { complex return values are removed from stack in C code PM }
           { but not on win32 }
           { and not for safecall with hidden exceptions, because the result }
           { which contains the exception is passed in EAX }
           if CurrentProcInfo.FramePointer<>NR_STACK_POINTER_REG then
             list.concat(TAIRegAlloc.dealloc(NR_STACK_POINTER_REG,nil));

           if ((TargetInfo.system <> system_i386_win32) or
               (TargetInfo.abi=abi_old_win32_gnu)) and
              not ((CurrentProcInfo.procdef.ProcCallOption = pocall_safecall) and
               (tf_safecall_exceptions in TargetInfo.flags)) and
              ParaManager.Ret_In_Param(CurrentProcInfo.procdef.ReturnDef,
                                       CurrentProcInfo.procdef) then
             list.concat(TAICPU.Op_const(A_RET,S_W,sizeof(aint)))
           else
             list.concat(TAICPU.Op_none(A_RET,S_NO));
         end

        { ... also routines with parasize=0 }
        else if (parasize=0) then
         begin
           if CurrentProcInfo.FramePointer<>NR_STACK_POINTER_REG then
             list.concat(TAIRegAlloc.dealloc(NR_STACK_POINTER_REG,nil));

           list.concat(TAICPU.Op_none(A_RET,S_NO))
         end
        else
         begin
           { parameters are limited to 65535 bytes because ret allows only imm16 }
           if (parasize>65535) then
             CGMessage(cg_e_parasize_too_big);

           if CurrentProcInfo.FramePointer<>NR_STACK_POINTER_REG then
             list.concat(TAIRegAlloc.dealloc(NR_STACK_POINTER_REG,nil));

           list.concat(TAICPU.Op_const(A_RET,S_W,parasize));
         end;

      end;


    procedure TCG386.G_CopyValuePara_OpenArray(list : TAsmList;const ref:TReference;const lenloc:TLocation;EleSize:TCGInt;destreg:TRegister);
      var
        power  : LongInt;
        opsize : TOpSize;
{$ifndef __NOWINPECOFF__}
        again,ok : TAsmLabel;
{$endif}
      begin
        { get stack space }
        GetCPURegister(list,NR_EDI);
        A_Load_Loc_Reg(list,OS_INT,lenloc,NR_EDI);
        list.concat(TAICPU.op_reg(A_INC,S_L,NR_EDI));
        { Now EDI contains (high+1). }

        { special case handling for elesize=8, 4 and 2:
          set ECX = (high+1) instead of ECX = (high+1)*elesize.

          In the case of elesize=4 and 2, this allows us to avoid the SHR later.
          In the case of elesize=8, we can later use a SHL ECX, 1 instead of
          SHR ECX, 2 which is one byte shorter. }
        if (EleSize=8) or (EleSize=4) or (EleSize=2) then
          begin
            { Now EDI contains (high+1). Copy it to ECX for later use. }
            GetCPURegister(list,NR_ECX);
            list.concat(TAICPU.op_reg_reg(A_MOV,S_L,NR_EDI,NR_ECX));
          end;
        { EDI := EDI * elesize }
        if (EleSize<>1) then
         begin
           if IsPowerOf2(EleSize, power) then
             list.concat(TAICPU.op_const_reg(A_SHL,S_L,power,NR_EDI))
           else
             list.concat(TAICPU.op_const_reg(A_IMUL,S_L,EleSize,NR_EDI));
         end;
        if (EleSize<>8) and (EleSize<>4) and (EleSize<>2) then
          begin
            { Now EDI contains (high+1)*elesize. Copy it to ECX for later use. }
            GetCPURegister(list,NR_ECX);
            list.concat(TAICPU.op_reg_reg(A_MOV,S_L,NR_EDI,NR_ECX));
          end;
{$ifndef __NOWINPECOFF__}
        { windows guards only a few pages for stack growing, }
        { so we have to access every page first              }
        if TargetInfo.system=system_i386_win32 then
          begin
             CurrentAsmData.getjumplabel(again);
             CurrentAsmData.getjumplabel(ok);
             A_Label(list,again);
             cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
             list.concat(TAICPU.op_const_reg(A_CMP,S_L,winstackpagesize,NR_EDI));
             a_jmp_cond(list,OC_B,ok);
             cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
             list.concat(TAICPU.op_const_reg(A_SUB,S_L,winstackpagesize-4,NR_ESP));
             list.concat(TAICPU.op_reg(A_PUSH,S_L,NR_EDI));
             list.concat(TAICPU.op_const_reg(A_SUB,S_L,winstackpagesize,NR_EDI));
             A_Jmp_Always(list,again);

             A_Label(list,ok);
          end;
{$endif __NOWINPECOFF__}
        { If we were probing pages, EDI=(size mod pagesize) and ESP is decremented
          by (size div pagesize)*pagesize, otherwise EDI=size.
          Either way, subtracting EDI from ESP will set ESP to desired final value. }
        list.concat(TAICPU.op_reg_reg(A_SUB,S_L,NR_EDI,NR_ESP));
        { align stack on 4 bytes }
        list.concat(TAICPU.op_const_reg(A_AND,S_L,aint($fffffff4),NR_ESP));
        { load destination, don't use a_load_reg_reg, that will add a move instruction
          that can confuse the reg allocator }
        list.concat(TAICPU.Op_reg_reg(A_MOV,S_L,NR_ESP,NR_EDI));

        { Allocate ESI and load it with source }
        GetCPURegister(list,NR_ESI);
        A_LoadAddr_Ref_Reg(list,ref,NR_ESI);

        { calculate size }
        opsize:=S_B;
        if EleSize=8 then
          begin
            opsize:=S_L;
            { ECX is number of qwords, convert to dwords }
            list.concat(TAICPU.op_const_reg(A_SHL,S_L,1,NR_ECX))
          end
        else if EleSize=4 then
          begin
            opsize:=S_L;
            { ECX is already number of dwords, so no need to SHL/SHR }
          end
        else if EleSize=2 then
          begin
            opsize:=S_W;
            { ECX is already number of words, so no need to SHL/SHR }
          end
        else
         if (EleSize and 3)=0 then
         begin
           opsize:=S_L;
           { ECX is number of bytes, convert to dwords }
           list.concat(TAICPU.op_const_reg(A_SHR,S_L,2,NR_ECX))
         end
        else
         if (EleSize and 1)=0 then
          begin
            opsize:=S_W;
            { ECX is number of bytes, convert to words }
            list.concat(TAICPU.op_const_reg(A_SHR,S_L,1,NR_ECX))
          end;

        if ts_cld in CurrentSettings.TargetSwitches then
          list.concat(TAICPU.op_none(A_CLD,S_NO));
        list.concat(TAICPU.op_none(A_REP,S_NO));
        case opsize of
          S_B : list.concat(TAICPU.Op_none(A_MOVSB,S_NO));
          S_W : list.concat(TAICPU.Op_none(A_MOVSW,S_NO));
          S_L : list.concat(TAICPU.Op_none(A_MOVSD,S_NO));
          else
            InternalError(2019050901);
        end;
        UngetCPURegister(list,NR_EDI);
        UngetCPURegister(list,NR_ECX);
        UngetCPURegister(list,NR_ESI);

        { patch the new address, but don't use a_load_reg_reg, that will add a move instruction
          that can confuse the reg allocator }
        list.concat(TAICPU.Op_reg_reg(A_MOV,S_L,NR_ESP,destreg));
        include(CurrentProcInfo.flags,pi_has_stack_allocs);
      end;


    procedure TCG386.G_ReleaseValuePara_OpenArray(list : TAsmList;const l:TLocation);
      begin
        { Nothing to release }
      end;


    procedure TCG386.G_Maybe_Got_Init(list: TAsmList);
      var
        i: LongInt;
        tmpreg: TRegister;
      begin
        { allocate PIC register }
        if (tf_pic_uses_got in TargetInfo.flags) and
          (pi_needs_got in CurrentProcInfo.flags) then
          begin
            if not (TargetInfo.system in [system_i386_darwin,system_i386_iphonesim]) then
              begin
                { Use ECX as a temp register by default }
                if CurrentProcInfo.got = NR_EBX then
                  tmpreg:=NR_EBX
                else
                  tmpreg:=NR_ECX;
                { Allocate registers used for parameters to make sure they
                  never allocated during this PIC init code }
                for i:=0 to CurrentProcInfo.procdef.paras.Count - 1 do
                  with TParaVarSym(CurrentProcInfo.procdef.paras[i]).ParaLoc[calleeside].Location^ do
                    if Loc in [LOC_REGISTER, LOC_CREGISTER] then begin
                      A_Reg_Alloc(list, register);
                      { If ECX is used for a parameter, use EBX as temp }
                      if GetSupReg(register) = RS_ECX then
                        tmpreg:=NR_EBX;
                    end;

                if tmpreg = NR_EBX then
                  begin
                    { Mark EBX as used in the proc }
                    include(rg[R_INTREGISTER].UsedInProc,RS_EBX);
                    CurrentModule.RequiresEBXPICHelper:=true;
                    A_Call_Name_Static(list,'fpc_geteipasebx');
                  end
                else
                  begin
                    CurrentModule.RequiresECXPICHelper:=true;
                    A_Call_Name_Static(list,'fpc_geteipasecx');
                  end;
                list.concat(TAICPU.op_sym_ofs_reg(A_ADD,S_L,CurrentAsmData.RefAsmSymbol('_GLOBAL_OFFSET_TABLE_',AT_DATA),0,tmpreg));
                list.concat(TAICPU.op_reg_reg(A_MOV,S_L,tmpreg,CurrentProcInfo.got));

                { Deallocate parameter registers }
                for i:=0 to CurrentProcInfo.procdef.paras.Count - 1 do
                  with TParaVarSym(CurrentProcInfo.procdef.paras[i]).ParaLoc[calleeside].Location^ do
                    if Loc in [LOC_REGISTER, LOC_CREGISTER] then
                      A_Reg_Dealloc(list, register);
              end
            else
              begin
                { call/pop is faster than call/ret/mov on Core Solo and later
                  according to Apple's benchmarking -- and all Intel Macs
                  have at least a Core Solo (furthermore, the i386 - Pentium 1
                  don't have a return stack buffer) }
                A_Call_Name_Static(list,CurrentProcInfo.CurrGOTLabel.name);
                A_Label(list,CurrentProcInfo.CurrGotLabel);
                list.concat(TAICPU.op_reg(A_POP,S_L,CurrentProcInfo.got))
              end;
          end;
      end;


{ ************* 64bit operations ************ }

    procedure TCG64F386.get_64bit_ops(op:TOpCG;var op1,op2:TAsmOp);
      begin
        case op of
          OP_ADD :
            begin
              op1:=A_ADD;
              op2:=A_ADC;
            end;
          OP_SUB :
            begin
              op1:=A_SUB;
              op2:=A_SBB;
            end;
          OP_XOR :
            begin
              op1:=A_XOR;
              op2:=A_XOR;
            end;
          OP_OR :
            begin
              op1:=A_OR;
              op2:=A_OR;
            end;
          OP_AND :
            begin
              op1:=A_AND;
              op2:=A_AND;
            end;
          else
            InternalError(2002032408);
        end;
      end;


    procedure TCG64F386.A_Op64_Ref_Reg(list : TAsmList;op:TOpCG;size : TCgSize;const ref : TReference;reg : TRegister64);
      var
        op1,op2 : TAsmOp;
        tempref : TReference;
      begin
        if not(op in [OP_NEG,OP_NOT]) then
          begin
            get_64bit_ops(op,op1,op2);
            tempref:=ref;
            TCGX86(cg).make_simple_ref(list,tempref);
            if op in [OP_ADD,OP_SUB] then
              cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
            list.concat(TAICPU.op_ref_reg(op1,S_L,tempref,reg.RegLo));
            inc(tempref.Offset,4);
            list.concat(TAICPU.op_ref_reg(op2,S_L,tempref,reg.RegHi));
            if op in [OP_ADD,OP_SUB] then
              cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
          end
        else
          begin
            A_Load64_Ref_Reg(list,ref,reg);
            A_Op64_Reg_Reg(list,op,size,reg,reg);
          end;
      end;


    procedure TCG64F386.A_Op64_Reg_Ref(list : TAsmList;op:TOpCG;size : TCgSize;reg : TRegister64; const ref: TReference);
      var
        op1,op2 : TAsmOp;
        tempref : TReference;
        tmpreg: TRegister;
        l1, l2: TAsmLabel;
      begin
        case op of
          OP_NOT,OP_NEG:
            inherited;
          OP_SHR,OP_SHL,OP_SAR:
            begin
              { load right operators in a register }
              cg.GetCPURegister(list,NR_ECX);
              cg.A_Load_Reg_Reg(list,OS_32,OS_32,reg.RegLo,NR_ECX);

              tempref:=ref;
              TCGX86(cg).make_simple_ref(list,tempref);

              { the damned shift instructions work only til a count of 32 }
              { so we've to do some tricks here                           }
              CurrentAsmData.getjumplabel(l1);
              CurrentAsmData.getjumplabel(l2);
              cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
              list.Concat(TAICPU.op_const_reg(A_TEST,S_B,32,NR_CL));
              cg.A_Jmp_Flags(list,F_E,l1);
              cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
              tmpreg:=cg.GetIntRegister(list,OS_32);
              case op of
                OP_SHL:
                  begin
                    cg.A_Load_Ref_Reg(list,OS_32,OS_32,tempref,tmpreg);
                    list.Concat(TAICPU.op_reg_reg(A_SHL,S_L,NR_CL,tmpreg));
                    inc(tempref.Offset,4);
                    cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                    dec(tempref.Offset,4);
                    cg.A_Load_Const_Ref(list,OS_32,0,tempref);
                    cg.A_Jmp_Always(list,l2);
                    cg.A_Label(list,l1);
                    cg.A_Load_Ref_Reg(list,OS_32,OS_32,tempref,tmpreg);
                    inc(tempref.Offset,4);
                    list.Concat(TAICPU.op_reg_reg_ref(A_SHLD,S_L,NR_CL,tmpreg,tempref));
                    dec(tempref.Offset,4);
                    if cs_opt_size in CurrentSettings.OptimizerSwitches then
                      list.concat(TAICPU.op_reg_ref(A_SHL,S_L,NR_CL,tempref))
                    else
                      begin
                        list.concat(TAICPU.op_reg_reg(A_SHL,S_L,NR_CL,tmpreg));
                        cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                      end;
                  end;
                OP_SHR:
                  begin
                    inc(tempref.Offset,4);
                    cg.A_Load_Ref_Reg(list,OS_32,OS_32,tempref,tmpreg);
                    list.Concat(TAICPU.op_reg_reg(A_SHR,S_L,NR_CL,tmpreg));
                    dec(tempref.Offset,4);
                    cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                    inc(tempref.Offset,4);
                    cg.A_Load_Const_Ref(list,OS_32,0,tempref);
                    cg.A_Jmp_Always(list,l2);
                    cg.A_Label(list,l1);
                    cg.A_Load_Ref_Reg(list,OS_32,OS_32,tempref,tmpreg);
                    dec(tempref.Offset,4);
                    list.Concat(TAICPU.op_reg_reg_ref(A_SHRD,S_L,NR_CL,tmpreg,tempref));
                    inc(tempref.Offset,4);
                    if cs_opt_size in CurrentSettings.OptimizerSwitches then
                      list.concat(TAICPU.op_reg_ref(A_SHR,S_L,NR_CL,tempref))
                    else
                      begin
                        list.concat(TAICPU.op_reg_reg(A_SHR,S_L,NR_CL,tmpreg));
                        cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                      end;
                  end;
                OP_SAR:
                  begin
                    inc(tempref.Offset,4);
                    cg.A_Load_Ref_Reg(list,OS_32,OS_32,tempref,tmpreg);
                    list.Concat(TAICPU.op_reg_reg(A_SAR,S_L,NR_CL,tmpreg));
                    dec(tempref.Offset,4);
                    cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                    inc(tempref.Offset,4);
                    list.Concat(TAICPU.op_const_reg(A_SAR,S_L,31,tmpreg));
                    cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                    cg.A_Jmp_Always(list,l2);
                    cg.A_Label(list,l1);
                    cg.A_Load_Ref_Reg(list,OS_32,OS_32,tempref,tmpreg);
                    dec(tempref.Offset,4);
                    list.Concat(TAICPU.op_reg_reg_ref(A_SHRD,S_L,NR_CL,tmpreg,tempref));
                    inc(tempref.Offset,4);
                    if cs_opt_size in CurrentSettings.OptimizerSwitches then
                      list.concat(TAICPU.op_reg_ref(A_SAR,S_L,NR_CL,tempref))
                    else
                      begin
                        list.concat(TAICPU.op_reg_reg(A_SAR,S_L,NR_CL,tmpreg));
                        cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                      end;
                  end;
                else
                  InternalError(2017041801);
              end;
              cg.A_Label(list,l2);

              cg.UngetCPURegister(list,NR_ECX);
              exit;
            end;
          else
            begin
              get_64bit_ops(op,op1,op2);
              tempref:=ref;
              TCGX86(cg).make_simple_ref(list,tempref);
              if op in [OP_ADD,OP_SUB] then
                cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
              list.concat(TAICPU.op_reg_ref(op1,S_L,reg.RegLo,tempref));
              inc(tempref.Offset,4);
              list.concat(TAICPU.op_reg_ref(op2,S_L,reg.RegHi,tempref));
              if op in [OP_ADD,OP_SUB] then
                cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
            end;
        end;
      end;


    procedure TCG64F386.A_Op64_Reg_Reg(list : TAsmList;op:TOpCG;size : TCgSize;regsrc,regdst : TRegister64);
      var
        op1,op2 : TAsmOp;
        l1, l2: TAsmLabel;
      begin
        case op of
          OP_NEG :
            begin
              if (regsrc.RegLo<>regdst.RegLo) then
                A_Load64_Reg_Reg(list,regsrc,regdst);
              list.concat(TAICPU.op_reg(A_NOT,S_L,regdst.RegHi));
              cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
              list.concat(TAICPU.op_reg(A_NEG,S_L,regdst.RegLo));
              list.concat(TAICPU.op_const_reg(A_SBB,S_L,-1,regdst.RegHi));
              cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
              exit;
            end;
          OP_NOT :
            begin
              if (regsrc.RegLo<>regdst.RegLo) then
                A_Load64_Reg_Reg(list,regsrc,regdst);
              list.concat(TAICPU.op_reg(A_NOT,S_L,regdst.RegHi));
              list.concat(TAICPU.op_reg(A_NOT,S_L,regdst.RegLo));
              exit;
            end;
          OP_SHR,OP_SHL,OP_SAR:
            begin
              { load right operators in a register }
              cg.GetCPURegister(list,NR_ECX);
              cg.A_Load_Reg_Reg(list,OS_32,OS_32,regsrc.RegLo,NR_ECX);

              { the damned shift instructions work only til a count of 32 }
              { so we've to do some tricks here                           }
              CurrentAsmData.getjumplabel(l1);
              CurrentAsmData.getjumplabel(l2);
              cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
              list.Concat(TAICPU.op_const_reg(A_TEST,S_B,32,NR_CL));
              cg.A_Jmp_Flags(list,F_E,l1);
              cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
              case op of
                OP_SHL:
                  begin
                    list.Concat(TAICPU.op_reg_reg(A_SHL,S_L,NR_CL,regdst.RegLo));
                    cg.A_Load_Reg_Reg(list,OS_32,OS_32,regdst.RegLo,regdst.RegHi);
                    list.Concat(TAICPU.op_reg_reg(A_XOR,S_L,regdst.RegLo,regdst.RegLo));
                    cg.A_Jmp_Always(list,l2);
                    cg.A_Label(list,l1);
                    list.Concat(TAICPU.op_reg_reg_reg(A_SHLD,S_L,NR_CL,regdst.RegLo,regdst.RegHi));
                    list.Concat(TAICPU.op_reg_reg(A_SHL,S_L,NR_CL,regdst.RegLo));
                  end;
                OP_SHR:
                  begin
                    list.Concat(TAICPU.op_reg_reg(A_SHR,S_L,NR_CL,regdst.RegHi));
                    cg.A_Load_Reg_Reg(list,OS_32,OS_32,regdst.RegHi,regdst.RegLo);
                    list.Concat(TAICPU.op_reg_reg(A_XOR,S_L,regdst.RegHi,regdst.RegHi));
                    cg.A_Jmp_Always(list,l2);
                    cg.A_Label(list,l1);
                    list.Concat(TAICPU.op_reg_reg_reg(A_SHRD,S_L,NR_CL,regdst.RegHi,regdst.RegLo));
                    list.Concat(TAICPU.op_reg_reg(A_SHR,S_L,NR_CL,regdst.RegHi));
                  end;
                OP_SAR:
                  begin
                    cg.A_Load_Reg_Reg(list,OS_32,OS_32,regdst.RegHi,regdst.RegLo);
                    list.Concat(TAICPU.op_reg_reg(A_SAR,S_L,NR_CL,regdst.RegLo));
                    list.Concat(TAICPU.op_const_reg(A_SAR,S_L,31,regdst.RegHi));
                    cg.A_Jmp_Always(list,l2);
                    cg.A_Label(list,l1);
                    list.Concat(TAICPU.op_reg_reg_reg(A_SHRD,S_L,NR_CL,regdst.RegHi,regdst.RegLo));
                    list.Concat(TAICPU.op_reg_reg(A_SAR,S_L,NR_CL,regdst.RegHi));
                  end;
                else
                  InternalError(2017041802);
              end;
              cg.A_Label(list,l2);

              cg.UngetCPURegister(list,NR_ECX);
              exit;
            end;
          else
            ;
        end;
        get_64bit_ops(op,op1,op2);
        if op in [OP_ADD,OP_SUB] then
          cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
        list.concat(TAICPU.op_reg_reg(op1,S_L,regsrc.RegLo,regdst.RegLo));
        list.concat(TAICPU.op_reg_reg(op2,S_L,regsrc.RegHi,regdst.RegHi));
        if op in [OP_ADD,OP_SUB] then
          cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
      end;


    procedure TCG64F386.A_Op64_Const_Reg(list : TAsmList;op:TOpCG;size : TCgSize;value : int64;reg : TRegister64);
      var
        op1,op2 : TAsmOp;
      begin
        case op of
          OP_AND,OP_OR,OP_XOR:
            begin
              cg.A_Op_Const_Reg(list,op,OS_32,TCGInt(lo(value)),reg.RegLo);
              cg.A_Op_Const_Reg(list,op,OS_32,TCGInt(hi(value)),reg.RegHi);
            end;
          OP_ADD, OP_SUB:
            begin
              // can't use a_op_const_ref because this may use dec/inc
              get_64bit_ops(op,op1,op2);
              cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
              list.concat(TAICPU.op_const_reg(op1,S_L,aint(lo(value)),reg.RegLo));
              list.concat(TAICPU.op_const_reg(op2,S_L,aint(hi(value)),reg.RegHi));
              cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
            end;
          OP_SHR,OP_SHL,OP_SAR:
            begin
              value:=value and 63;
              if value<>0 then
                begin
                  if (value=1) and (op=OP_SHL) and
                     (CurrentSettings.OptimizeCPUType<=cpu_486) and
                     not (cs_opt_size in CurrentSettings.OptimizerSwitches) then
                    begin
                      cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
                      list.concat(TAICPU.op_reg_reg(A_ADD,S_L,reg.RegLo,reg.RegLo));
                      list.concat(TAICPU.op_reg_reg(A_ADC,S_L,reg.RegHi,reg.RegHi));
                      cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
                    end
                  else if (value=1) and (cs_opt_size in CurrentSettings.OptimizerSwitches) then
                    case op of
                      OP_SHR:
                        begin
                          cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
                          list.concat(TAICPU.op_const_reg(A_SHR,S_L,value,reg.RegHi));
                          list.concat(TAICPU.op_const_reg(A_RCR,S_L,value,reg.RegLo));
                          cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
                        end;
                      OP_SHL:
                        begin
                          cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
                          list.concat(TAICPU.op_const_reg(A_SHL,S_L,value,reg.RegLo));
                          list.concat(TAICPU.op_const_reg(A_RCL,S_L,value,reg.RegHi));
                          cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
                        end;
                      OP_SAR:
                        begin
                          cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
                          list.concat(TAICPU.op_const_reg(A_SAR,S_L,value,reg.RegHi));
                          list.concat(TAICPU.op_const_reg(A_RCR,S_L,value,reg.RegLo));
                          cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
                        end;
                      else
                        InternalError(2019050902);
                    end
                  else if value>31 then
                    case op of
                      OP_SAR:
                        begin
                          cg.A_Load_Reg_Reg(list,OS_32,OS_32,reg.RegHi,reg.RegLo);
                          list.concat(TAICPU.op_const_reg(A_SAR,S_L,31,reg.RegHi));
                          if (value and 31)<>0 then
                            list.concat(TAICPU.op_const_reg(A_SAR,S_L,value and 31,reg.RegLo));
                        end;
                      OP_SHR:
                        begin
                          cg.A_Load_Reg_Reg(list,OS_32,OS_32,reg.RegHi,reg.RegLo);
                          list.concat(TAICPU.op_reg_reg(A_XOR,S_L,reg.RegHi,reg.RegHi));
                          if (value and 31)<>0 then
                            list.concat(TAICPU.op_const_reg(A_SHR,S_L,value and 31,reg.RegLo));
                        end;
                      OP_SHL:
                        begin
                          cg.A_Load_Reg_Reg(list,OS_32,OS_32,reg.RegLo,reg.RegHi);
                          list.concat(TAICPU.op_reg_reg(A_XOR,S_L,reg.RegLo,reg.RegLo));
                          if (value and 31)<>0 then
                            list.concat(TAICPU.op_const_reg(A_SHL,S_L,value and 31,reg.RegHi));
                        end;
                      else
                        InternalError(2017041201);
                    end
                  else
                    case op of
                      OP_SAR:
                        begin
                          list.concat(TAICPU.op_const_reg_reg(A_SHRD,S_L,value,reg.RegHi,reg.RegLo));
                          list.concat(TAICPU.op_const_reg(A_SAR,S_L,value,reg.RegHi));
                        end;
                      OP_SHR:
                        begin
                          list.concat(TAICPU.op_const_reg_reg(A_SHRD,S_L,value,reg.RegHi,reg.RegLo));
                          list.concat(TAICPU.op_const_reg(A_SHR,S_L,value,reg.RegHi));
                        end;
                      OP_SHL:
                        begin
                          list.concat(TAICPU.op_const_reg_reg(A_SHLD,S_L,value,reg.RegLo,reg.RegHi));
                          list.concat(TAICPU.op_const_reg(A_SHL,S_L,value,reg.RegLo));
                        end;
                      else
                        InternalError(2017041202);
                    end;
                end;
            end;
          else
            InternalError(200204021);
        end;
      end;


    procedure TCG64F386.A_Op64_Const_Ref(list : TAsmList;op:TOpCG;size : TCgSize;value : int64;const ref : TReference);
      var
        op1,op2 : TAsmOp;
        tempref : TReference;
        tmpreg: TRegister;
      begin
        tempref:=ref;
        TCGX86(cg).make_simple_ref(list,tempref);
        case op of
          OP_AND,OP_OR,OP_XOR:
            begin
              cg.A_Op_Const_Ref(list,op,OS_32,aint(lo(value)),tempref);
              inc(tempref.Offset,4);
              cg.A_Op_Const_Ref(list,op,OS_32,aint(hi(value)),tempref);
            end;
          OP_ADD, OP_SUB:
            begin
              get_64bit_ops(op,op1,op2);
              // can't use a_op_const_ref because this may use dec/inc
              cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
              list.concat(TAICPU.op_const_ref(op1,S_L,aint(lo(value)),tempref));
              inc(tempref.Offset,4);
              list.concat(TAICPU.op_const_ref(op2,S_L,aint(hi(value)),tempref));
              cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
            end;
          OP_SHR,OP_SHL,OP_SAR:
            begin
              value:=value and 63;
              if value<>0 then
                begin
                  if value=1 then
                    case op of
                      OP_SHR:
                        begin
                          cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
                          inc(tempref.Offset,4);
                          list.concat(TAICPU.op_const_ref(A_SHR,S_L,value,tempref));
                          dec(tempref.Offset,4);
                          list.concat(TAICPU.op_const_ref(A_RCR,S_L,value,tempref));
                          cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
                        end;
                      OP_SHL:
                        begin
                          cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
                          list.concat(TAICPU.op_const_ref(A_SHL,S_L,value,tempref));
                          inc(tempref.Offset,4);
                          list.concat(TAICPU.op_const_ref(A_RCL,S_L,value,tempref));
                          cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
                        end;
                      OP_SAR:
                        begin
                          cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
                          inc(tempref.Offset,4);
                          list.concat(TAICPU.op_const_ref(A_SAR,S_L,value,tempref));
                          dec(tempref.Offset,4);
                          list.concat(TAICPU.op_const_ref(A_RCR,S_L,value,tempref));
                          cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
                        end;
                      else
                        InternalError(2019050903);
                    end
                  else if value>31 then
                    case op of
                      OP_SHR,OP_SAR:
                        begin
                          tmpreg:=cg.GetIntRegister(list,OS_32);
                          inc(tempref.Offset,4);
                          cg.A_Load_Ref_Reg(list,OS_32,OS_32,tempref,tmpreg);
                          if (value and 31)<>0 then
                            if op=OP_SHR then
                              list.concat(TAICPU.op_const_reg(A_SHR,S_L,value and 31,tmpreg))
                            else
                              list.concat(TAICPU.op_const_reg(A_SAR,S_L,value and 31,tmpreg));
                          dec(tempref.Offset,4);
                          cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                          inc(tempref.Offset,4);
                          if op=OP_SHR then
                            cg.A_Load_Const_Ref(list,OS_32,0,tempref)
                          else
                            begin
                              list.concat(TAICPU.op_const_reg(A_SAR,S_L,31,tmpreg));
                              cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                            end;
                        end;
                      OP_SHL:
                        begin
                          tmpreg:=cg.GetIntRegister(list,OS_32);
                          cg.A_Load_Ref_Reg(list,OS_32,OS_32,tempref,tmpreg);
                          if (value and 31)<>0 then
                            list.concat(TAICPU.op_const_reg(A_SHL,S_L,value and 31,tmpreg));
                          inc(tempref.Offset,4);
                          cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                          dec(tempref.Offset,4);
                          cg.A_Load_Const_Ref(list,OS_32,0,tempref);
                        end;
                      else
                        InternalError(2017041803);
                    end
                  else
                    case op of
                      OP_SHR,OP_SAR:
                        begin
                          tmpreg:=cg.GetIntRegister(list,OS_32);
                          inc(tempref.Offset,4);
                          cg.A_Load_Ref_Reg(list,OS_32,OS_32,tempref,tmpreg);
                          dec(tempref.Offset,4);
                          list.concat(TAICPU.op_const_reg_ref(A_SHRD,S_L,value,tmpreg,tempref));
                          inc(tempref.Offset,4);
                          if cs_opt_size in CurrentSettings.OptimizerSwitches then
                            begin
                              if op=OP_SHR then
                                list.concat(TAICPU.op_const_ref(A_SHR,S_L,value,tempref))
                              else
                                list.concat(TAICPU.op_const_ref(A_SAR,S_L,value,tempref));
                            end
                          else
                            begin
                              if op=OP_SHR then
                                list.concat(TAICPU.op_const_reg(A_SHR,S_L,value,tmpreg))
                              else
                                list.concat(TAICPU.op_const_reg(A_SAR,S_L,value,tmpreg));
                              cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                            end;
                        end;
                      OP_SHL:
                        begin
                          tmpreg:=cg.GetIntRegister(list,OS_32);
                          cg.A_Load_Ref_Reg(list,OS_32,OS_32,tempref,tmpreg);
                          inc(tempref.Offset,4);
                          list.concat(TAICPU.op_const_reg_ref(A_SHLD,S_L,value,tmpreg,tempref));
                          dec(tempref.Offset,4);
                          if cs_opt_size in CurrentSettings.OptimizerSwitches then
                            list.concat(TAICPU.op_const_ref(A_SHL,S_L,value,tempref))
                          else
                            begin
                              list.concat(TAICPU.op_const_reg(A_SHL,S_L,value,tmpreg));
                              cg.A_Load_Reg_Ref(list,OS_32,OS_32,tmpreg,tempref);
                            end;
                        end;
                      else
                        InternalError(2017041203);
                    end;
                end;
            end;
          else
            InternalError(200204022);
        end;
      end;


    procedure TCG64F386.A_Op64_Ref(list: TAsmList; op: TOpCG; size: TCgSize; const ref: TReference);
      var
        tempref : TReference;
      begin
        case op of
          OP_NOT:
            begin
              tempref:=ref;
              TCGX86(cg).make_simple_ref(list,tempref);
              list.concat(TAICPU.op_ref(A_NOT,S_L,tempref));
              inc(tempref.Offset,4);
              list.concat(TAICPU.op_ref(A_NOT,S_L,tempref));
            end;
          OP_NEG:
            begin
              tempref:=ref;
              TCGX86(cg).make_simple_ref(list,tempref);
              inc(tempref.Offset,4);
              list.concat(TAICPU.op_ref(A_NOT,S_L,tempref));
              cg.A_Reg_Alloc(list,NR_DEFAULTFLAGS);
              dec(tempref.Offset,4);
              list.concat(TAICPU.op_ref(A_NEG,S_L,tempref));
              inc(tempref.Offset,4);
              list.concat(TAICPU.op_const_ref(A_SBB,S_L,-1,tempref));
              cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
            end;
          else
            InternalError(2020050708);
        end;
      end;


    procedure create_codegen;
      begin
        cg := TCG386.Create;
        cg64 := TCG64F386.Create;
      end;

end.
