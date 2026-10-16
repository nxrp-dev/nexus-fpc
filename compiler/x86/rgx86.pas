{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit implements the x86 specific class for the register
    allocator

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

unit rgx86;

{$i fpcdefs.inc}

  interface

    uses
      CPUBase,CGBase,CGUtils,
      AAsmTAI,AAsmData,AAsmSym,AAsmCPU,
      RGObj;

    type
       TRGX86 = class(TRGObj)
         function  Get_Spill_SubReg(R : TRegister) : TSubRegister;override;
         function  Do_Spill_Replace(List:TAsmList;Instr:TAICPUAbstractSym;OrgReg:TSuperRegister;const SpillTemp:TReference):Boolean;override;
       end;

       TPushedSavedLoc = record
         case Byte of
           0: (Pushed: Boolean);
           1: (Ofs: LongInt);
       end;

       TPushedSavedFPU = array[TSuperRegister] of TPushedSavedLoc;

       TRGX86FPU = class
          { these counters contain the number of elements in the }
          { unusedregsxxx/usableregsxxx sets                     }
          CountUnusedRegsFPU : Byte;

          { Contains the registers which are really used by the proc itself.
            It doesn't take care of registers used by called procedures
          }
          UsedInProc : TCPURegisterSet;

          {reg_pushes_other : regvarother_longintarray;
          is_reg_var_other : regvarother_booleanarray;
          regvar_loaded_other : regvarother_booleanarray;}

          FPUVarOffset : Byte;

          constructor Create;

          function GetRegisterFPU(List: TAsmList) : TRegister;
          procedure UngetRegisterFPU(List: TAsmList; R : TRegister);

          { pushes and restores registers }
          procedure SaveUsedFPURegisters(List:TAsmList;
                                         var Saved:TPushedSavedFPU;
                                         const S:TCPURegisterSet);
          procedure RestoreUsedFPURegisters(List:TAsmList;
                                            const Saved:TPushedSavedFPU);

          { corrects the fpu stack register by ofs }
          function Correct_FPURegister(R : TRegister;Ofs : Byte) : TRegister;
       end;


implementation

    uses
       Verbose;

    const
       { This value is used in tsaved. If the array value is equal
         to this, then this means that this register is not used.}
       RegNotSaved = $7fffffff;


{******************************************************************************
                                    Trgcpu
******************************************************************************}

    function TRGX86.Get_Spill_SubReg(R : TRegister) : TSubRegister;
      begin
        Result:=GetSubReg(R);
      end;


    { Decide wether a "replace" spill is possible, i.e. wether we can replace a register
      in an instruction by a memory reference. For example, in "mov ireg26d,0", the imaginary
      register ireg26d can be replaced by a memory reference.}
    function TRGX86.Do_Spill_Replace(List:TAsmList;Instr:TAICPUAbstractSym;OrgReg:TSuperRegister;const SpillTemp:TReference):Boolean;

       { returns true if opcode is an avx opcode which allows only the first (zero) operand might be a memory reference }
       function AVXOpcodeOnlyOp0MayBeMemRef(Opcode : TAsmOp) : Boolean;
         begin
           case Opcode of
             A_VMAXPD,
             A_VMAXPS,
             A_VMAXSD,
             A_VMAXSS,
             A_VMINPD,
             A_VMINPS,
             A_VMINSD,
             A_VMINSS,
             A_VMULSS,
             A_VMULSD,
             A_VSUBSS,
             A_VSUBSD,
             A_VADDSD,
             A_VADDSS,
             A_VDIVSD,
             A_VDIVSS,
             A_VSQRTSD,
             A_VSQRTSS,
             A_VCVTDQ2PD,
             A_VCVTDQ2PS,
             A_VCVTPD2DQ,
             A_VCVTPD2PS,
             A_VCVTPS2DQ,
             A_VCVTPS2PD,
             A_VCVTSD2SI,
             A_VCVTSD2SS,
             A_VCVTSI2SD,
             A_VCVTSS2SD,
             A_VCVTTPD2DQ,
             A_VCVTTPS2DQ,
             A_VCVTTSD2SI,
             A_VCVTSI2SS,
             A_VCVTSS2SI,
             A_VCVTTSS2SI,
             A_VXORPD,
             A_VXORPS,
             A_VORPD,
             A_VORPS,
             A_VANDPD,
             A_VANDPS,
             A_VUNPCKLPS,
             A_VUNPCKHPS,
             A_VSHUFPD,
             A_VREDUCEPD,
             A_VREDUCEPS,
             A_VREDUCESD,
             A_VREDUCESS,
             A_VROUNDSS,
             A_VROUNDSD:
               Result:=True;
             else
               Result:=False;
           end;
         end;


      var
        N,ReplaceOper : LongInt;
        is_subh: Boolean;
      begin
        Result:=False;
        with TAICPU(Instr) do
          begin
            ReplaceOper:=-1;
            case Ops of
              1 :
                begin
                  if (Oper[0]^.Typ=top_reg) and
                     (GetRegType(Oper[0]^.Reg)=RegType) then
                    begin
                      if Get_Alias(GetSupReg(Oper[0]^.Reg))<>OrgReg then
                        InternalError(200410101);
                      ReplaceOper:=0;
                    end;
                end;
              2,3 :
                begin
                  { avx instruction?
                    currently this rule is sufficient but it might be extended }
                  if (Ops=3) and (Opcode<>A_SHRD) and (Opcode<>A_SHLD) and (Opcode<>A_IMUL) then
                    begin
                      { BMI shifting/rotating instructions have special requirements regarding spilling, only
                        the middle operand can be replaced }
                      if ((Opcode=A_RORX) or (Opcode=A_SHRX) or (Opcode=A_SARX) or (Opcode=A_SHLX) or (Opcode=A_BEXTR) or (Opcode=A_BZHI)) then
                        begin
                          if (Oper[1]^.Typ=top_reg) and (GetRegType(Oper[1]^.Reg)=RegType) and (Get_Alias(GetSupReg(Oper[1]^.Reg))=OrgReg) then
                            ReplaceOper:=1;
                        end
                      { avx instructions allow only the first operand (at&t counting) to be a register operand
                        all operands must be registers ... }
                      else if (Oper[0]^.Typ=top_reg) and
                         (GetRegType(Oper[0]^.Reg)=RegType) and
                         (Oper[1]^.Typ=top_reg) and
                         (Oper[2]^.Typ=top_reg) and
                         { but they must be different }
                         ((GetRegType(Oper[1]^.Reg)<>RegType) or
                          (Get_Alias(GetSupReg(Oper[0]^.Reg))<>Get_Alias(GetSupReg(Oper[1]^.Reg)))
                         ) and
                         ((GetRegType(Oper[2]^.Reg)<>RegType) or
                          (Get_Alias(GetSupReg(Oper[0]^.Reg))<>Get_Alias(GetSupReg(Oper[2]^.Reg)))
                         ) and
                         (Get_Alias(GetSupReg(Oper[0]^.Reg))=OrgReg) then
                        ReplaceOper:=0;
                    end
                  else
                    begin
                      { We can handle opcodes with 2 and 3-op imul/shrd/shld the same way, where the 3rd operand is const or CL,
                        that doesn't need spilling.
                        However, due to AT&T order inside the compiler, the 3rd operand is
                        numbered 0, so look at operand no. 1 and 2 if we have 3 operands by
                        adding a "n". }
                      N:=0;
                      if Ops=3 then
                        N:=1;
                      { lea is tricky: part of operand 0 can be spilled and the instruction can converted into an
                        add, if base or index shall be spilled and the other one is equal the destination }
                      if (Opcode=A_LEA) then
                        begin
                          if (Oper[0]^.Ref^.Offset=0) and
                             (Oper[0]^.Ref^.ScaleFactor in [0,1]) and
                             (((GetRegType(Oper[0]^.Ref^.Base)=RegType) and
                               (Get_Alias(GetSupReg(Oper[0]^.Ref^.Base))=OrgReg) and
                               (GetRegType(Oper[0]^.Ref^.Index)=GetRegType(Oper[1]^.Reg)) and
                               (Get_Alias(GetSupReg(Oper[0]^.Ref^.Index))=Get_Alias(GetSupReg(Oper[1]^.Reg)))) or
                              ((GetRegType(Oper[0]^.Ref^.Index)=RegType) and
                               (Get_Alias(GetSupReg(Oper[0]^.Ref^.Index))=OrgReg) and
                               (GetRegType(Oper[0]^.Ref^.Base)=GetRegType(Oper[1]^.Reg)) and
                               (Get_Alias(GetSupReg(Oper[0]^.Ref^.Base))=Get_Alias(GetSupReg(Oper[1]^.Reg))))
                             ) then
                             ReplaceOper:=0;
                        end
                      else if (Oper[N+0]^.Typ=top_reg) and
                         (Oper[N+1]^.Typ=top_reg) and
                         ((GetRegType(Oper[N+0]^.Reg)<>RegType) or
                          (GetRegType(Oper[N+1]^.Reg)<>RegType) or
                          (Get_Alias(GetSupReg(Oper[N+0]^.Reg))<>Get_Alias(GetSupReg(Oper[N+1]^.Reg)))) then
                        begin
                          if (GetRegType(Oper[N+0]^.Reg)=RegType) and
                             (Get_Alias(GetSupReg(Oper[N+0]^.Reg))=OrgReg) then
                            ReplaceOper:=0+N
                          else if (GetRegType(Oper[N+1]^.Reg)=RegType) and
                             (Get_Alias(GetSupReg(Oper[N+1]^.Reg))=OrgReg) then
                            ReplaceOper:=1+N;
                        end
                      else if (Oper[N+0]^.Typ=top_reg) and
                         (Oper[N+1]^.Typ=top_const) then
                        begin
                          if (GetRegType(Oper[0+N]^.Reg)=RegType) and
                             (Get_Alias(GetSupReg(Oper[0+N]^.Reg))=OrgReg) then
                            ReplaceOper:=0+N
                          else
                            InternalError(200704282);
                        end
                      else if (Oper[N+0]^.Typ=top_const) and
                         (Oper[N+1]^.Typ=top_reg) then
                        begin
                          if (GetRegType(Oper[1+N]^.Reg)=RegType) and
                             (Get_Alias(GetSupReg(Oper[1+N]^.Reg))=OrgReg) then
                            ReplaceOper:=1+N
                          else
                            InternalError(200704283);
                        end;
                      case ReplaceOper of
                        0 :
                          begin
                            { Some instructions don't allow memory references
                              for source }
                            case Opcode of
                              A_BT,
                              A_BTS,
                              A_BTC,
                              A_BTR,

                              { shufp*/unpcklp* would require 16 byte alignment for memory locations so we force the source
                                operand into a register }
                              A_SHUFPD,
                              A_SHUFPS,
                              A_UNPCKLPD,
                              A_UNPCKLPS :
                                ReplaceOper:=-1;

                              { movlhps/movhlps requires the second parameter to be XMM registers }
                              A_MOVHLPS,
                              A_MOVLHPS:
                                ReplaceOper:=-1;
                              else
                                ;
                            end;
                          end;
                        1 :
                          begin
                            { Some instructions don't allow memory references
                              for destination }
                            case Opcode of
                              A_CMOVcc,
                              A_MOVZX,
                              A_MOVSX,
{$ifdef x86_64}
                              A_MOVSXD,
{$endif x86_64}
                              A_MULSS,
                              A_MULSD,
                              A_SUBSS,
                              A_SUBSD,
                              A_ADDSD,
                              A_ADDSS,
                              A_DIVSD,
                              A_DIVSS,
                              A_SQRTSD,
                              A_SQRTSS,
                              A_SHLD,
                              A_SHRD,
                              A_COMISD,
                              A_COMISS,
                              A_CVTDQ2PD,
                              A_CVTDQ2PS,
                              A_CVTPD2DQ,
                              A_CVTPD2PI,
                              A_CVTPD2PS,
                              A_CVTPI2PD,
                              A_CVTPS2DQ,
                              A_CVTPS2PD,
                              A_CVTSD2SI,
                              A_CVTSD2SS,
                              A_CVTSI2SD,
                              A_CVTSS2SD,
                              A_CVTTPD2PI,
                              A_CVTTPD2DQ,
                              A_CVTTPS2DQ,
                              A_CVTTSD2SI,
                              A_CVTPI2PS,
                              A_CVTPS2PI,
                              A_CVTSI2SS,
                              A_CVTSS2SI,
                              A_CVTTPS2PI,
                              A_CVTTSS2SI,
                              A_XORPD,
                              A_XORPS,
                              A_PXOR,
                              A_PAND,
                              A_POR,
                              A_ORPD,
                              A_ORPS,
                              A_ANDPD,
                              A_ANDPS,
                              A_UNPCKLPS,
                              A_UNPCKHPS,
                              A_SHUFPD,
                              A_SHUFPS,
                              A_VCOMISD,
                              A_VCOMISS,
                              A_MINSS,
                              A_MINSD,
                              A_MINPS,
                              A_MINPD,
                              A_MAXSS,
                              A_MAXSD,
                              A_MAXPS,
                              A_MAXPD:
                                ReplaceOper:=-1;

                              A_IMUL:
                                if Ops<>3 then
                                  ReplaceOper:=-1;
{$ifdef x86_64}
                              A_MOV:
                                 { 64 bit constants can only be moved into registers }
                                 if (Oper[0]^.Typ=top_const) and
                                    (Oper[1]^.Typ=top_reg) and
                                    ((Oper[0]^.Val<Low(LongInt)) or
                                     (Oper[0]^.Val>High(LongInt))) then
                                   ReplaceOper:=-1;
{$endif x86_64}
                              else
                                if AVXOpcodeOnlyOp0MayBeMemRef(Opcode) then
                                  ReplaceOper:=-1;
                            end;
                          end;
                        2 :
                          begin
                            { Some 3-op instructions don't allow memory references
                              for destination }
                            case Instr.Opcode of
                              A_IMUL:
                                ReplaceOper:=-1;
                              else
                                if AVXOpcodeOnlyOp0MayBeMemRef(Opcode) then
                                  ReplaceOper:=-1;
                            end;
                          end;
                      end;
                    end;
                end;
             end;

{$ifdef x86_64}
            { 32 bit operations on 32 bit registers on x86_64 can result in
              zeroing the upper 32 bits of the register. This does not happen
              with memory operations, so we have to perform these calculations
              in registers.

              However, for instructions not modifying registers, this is not a problem }
            if (OpSize=S_L) and (Opcode<>A_CMP) and (Opcode<>A_TEST) and (Opcode<>A_BT) then
              ReplaceOper:=-1;
{$endif x86_64}

            { Replace register with spill reference }
            if ReplaceOper<>-1 then
              begin
                if ReplaceOper<=1 then
                  begin
{$ifdef x86_64}
                    { if an mm register => int register (v)movq is converted, replace it by MOV with opsize Q }
                    if ((Opcode=A_MOVQ) or (Opcode=A_VMOVQ)) and (Oper[0]^.Typ=top_reg)  and (Oper[1]^.Typ=top_reg) and (GetRegType(Oper[ReplaceOper xor 1]^.Reg)=R_INTREGISTER) then
                      begin
                        Opcode:=A_MOV;
                        OpSize:=S_Q;
                      end
                    else
{$endif x86_64}
                    { if an mm register => int register (v)movd is converted, replace it by MOV with opsize L }
                    if ((Opcode=A_MOVD) or (Opcode=A_VMOVD)) and (Oper[0]^.Typ=top_reg)  and (Oper[1]^.Typ=top_reg) and (GetRegType(Oper[ReplaceOper xor 1]^.Reg)=R_INTREGISTER) then
                      begin
                        Opcode:=A_MOV;
                        OpSize:=S_L;
                      end;
                  end;

                if Opcode=A_LEA then
                  begin
                    Opcode:=A_ADD;
                    Oper[0]^.Ref^:=SpillTemp;
                  end
                else
                  begin
                    is_subh:=GetSubReg(Oper[ReplaceOper]^.Reg)=R_SUBH;
                    Oper[ReplaceOper]^.Typ:=top_ref;
                    New(Oper[ReplaceOper]^.Ref);
                    Oper[ReplaceOper]^.Ref^:=SpillTemp;
                    if is_subh then
                      Inc(Oper[ReplaceOper]^.Ref^.Offset);
                    { memory locations aren't guaranteed to be aligned }
                    case Opcode of
                      A_MOVAPS:
                        Opcode:=A_MOVSS;
                      A_MOVAPD:
                        Opcode:=A_MOVSD;
                      A_VMOVAPS:
                        Opcode:=A_VMOVSS;
                      A_VMOVAPD:
                        Opcode:=A_VMOVSD;
                      else
                        ;
                    end;
                  end;
                Result:=True;
              end;
          end;
      end;


{******************************************************************************
                                  Trgx86fpu
******************************************************************************}

    constructor TRGX86FPU.Create;
      begin
        UsedInProc:=[];
      end;


    function TRGX86FPU.GetRegisterFPU(List: TAsmList) : TRegister;
      begin
        { note: don't return R_ST0, see comments above implementation of }
        { a_loadfpu_* methods in cgcpu (JM)                              }
        Result:=NR_ST;
      end;


    procedure TRGX86FPU.UngetRegisterFPU(List : TAsmList; R : TRegister);
      begin
        { nothing to do, fpu stack management is handled by the load/ }
        { store operations in cgcpu (JM)                              }
      end;



    function TRGX86FPU.Correct_FPURegister(R : TRegister;Ofs : Byte) : TRegister;
      begin
        Correct_FPURegister:=R;
        SetSupReg(Correct_FPURegister,Ofs);
      end;


    procedure TRGX86FPU.SaveUsedFPURegisters(List: TAsmList;
                                             var Saved : TPushedSavedFPU;
                                             const S: TCPURegisterSet);
     { var
         r : tregister;
         hr : treference; }
      begin
        UsedInProc:=UsedInProc+S;

{ TODO: firstsavefpureg}
(*
        { don't try to save the fpu registers if not desired (e.g. for }
        { the 80x86)                                                   }
        if firstsavefpureg <> R_NO then
          for r.enum:=firstsavefpureg to lastsavefpureg do
            begin
              saved[r.enum].ofs:=reg_not_saved;
              { if the register is used by the calling subroutine and if }
              { it's not a regvar (those are handled separately)         }
              if not is_reg_var_other[r.enum] and
                 (r.enum in s) and
                 { and is present in use }
                 not(r.enum in unusedregsfpu) then
                begin
                  { then save it }
                  tg.GetTemp(list,extended_size,tt_persistent,hr);
                  saved[r.enum].ofs:=hr.offset;
                  cg.a_loadfpu_reg_ref(list,OS_FLOAT,OS_FLOAT,r,hr);
                  cg.a_reg_dealloc(list,r);
                  include(unusedregsfpu,r.enum);
                  inc(countunusedregsfpu);
                end;
            end;
*)
      end;


    procedure TRGX86FPU.RestoreUsedFPURegisters(List : TAsmList;
                                                const Saved : TPushedSavedFPU);
{
      var
         r,r2 : tregister;
         hr : treference;
}
      begin
{ TODO: firstsavefpureg}
(*
        if firstsavefpureg <> R_NO then
          for r.enum:=lastsavefpureg downto firstsavefpureg do
            begin
              if saved[r.enum].ofs <> reg_not_saved then
                begin
                  r2.enum:=R_INTREGISTER;
                  r2.number:=NR_FRAME_POINTER_REG;
                  reference_reset_base(hr,r2,saved[r.enum].ofs);
                  cg.a_reg_alloc(list,r);
                  cg.a_loadfpu_ref_reg(list,OS_FLOAT,OS_FLOAT,hr,r);
                  if not (r.enum in unusedregsfpu) then
                    { internalerror(10)
                      in n386cal we always save/restore the reg *state*
                      using save/restoreunusedstate -> the current state
                      may not be real (JM) }
                  else
                    begin
                      dec(countunusedregsfpu);
                      exclude(unusedregsfpu,r.enum);
                    end;
                  tg.UnGetTemp(list,hr);
                end;
            end;
*)
      end;

(*
    procedure Trgx86fpu.saveotherregvars(list: TAsmList; const s: totherregisterset);
      var
        r: Tregister;
      begin
        if not(cs_opt_regvar in current_settings.optimizerswitches) then
          exit;
        if firstsavefpureg <> NR_NO then
          for r.enum := firstsavefpureg to lastsavefpureg do
            if is_reg_var_other[r.enum] and
               (r.enum in s) then
              store_regvar(list,r);
      end;
*)

end.
