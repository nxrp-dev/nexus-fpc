{
    Copyright (c) 1998-2002, 2014 by Florian Klaempfl and Jonas Maebe

    Generate AArch64 assembler for math nodes

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
unit ncpumat;

{$i fpcdefs.inc}

interface

    uses
      node,nmat,ncgmat;

    type
      TAArch64ModDivNode = class(TModDivNode)
         function pass_1: TNode; override;
         procedure pass_generate_code;override;
      end;

      TAArch64NotNode = class(TCGNotNode)
         procedure second_boolean;override;
      end;

      TAArch64UnaryMinusNode = class(TCGUnaryMinusNode)
         function pass_1: TNode; override;
         procedure second_float; override;
      end;

implementation

    uses
      GlobType,Systems,ConstExp,
      CUtils,Verbose,Globals,
      symconst,symdef,
      aasmbase,aasmcpu,aasmtai,AAsmData,
      defutil,
      cgbase,cgobj,hlcgobj,pass_2,ProcInfo,
      ncon,nutils,
      cpubase,
      ncgutil,cgcpu,cgutils;

{*****************************************************************************
                             taarch64moddivnode
*****************************************************************************}

    function TAArch64ModDivNode.pass_1: TNode;
      begin
        result:=inherited pass_1;
        if not Assigned(result) and not(node_not_zero(right)) then
          include(CurrentProcInfo.flags,pi_do_call);
      end;


    procedure TAArch64ModDivNode.pass_generate_code;
      var
         op         : TAsmOp;
         tmpreg,
         zeroreg,
         numerator,
         divider,
         largernumreg,
         largerresreg,
         resultreg  : TRegister;
         hl         : TAsmLabel;
         overflowloc: TLocation;
         power      : LongInt;
         opsize     : TCgSize;

         dividend   : Int64;
         high_bit,
         reciprocal : QWord;
         { Just to save on stack space and the like }
         reciprocal_signed : Int64 absolute reciprocal;

         expandword,
         magic_add  : Boolean;
         shift      : byte;

         shifterop  : TShifterOp;
         hp         : TAICPU;

       procedure genOrdConstNodeDiv;
         var
           helper1, helper2: TRegister;
           so: TShifterOp;
         begin
           if TOrdConstNode(right).Value=0 then
             InternalError(2020021601)
           else if TOrdConstNode(right).Value=1 then
             cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList, opsize, opsize, numerator, resultreg)
           else if (TOrdConstNode(right).Value = int64(-1)) then
             begin
               // note: only in the signed case possible..., may overflow
               if cs_check_overflow in CurrentSettings.LocalSwitches then
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

               CurrentAsmData.CurrAsmList.concat(setoppostfix(TAICPU.op_reg_reg(A_NEG,
                 resultreg,numerator),TOpPostfix(ord(cs_check_overflow in CurrentSettings.LocalSwitches)*ord(PF_S))));
             end
           else if IsAbsPowerOf2(TOrdConstNode(right).Value,power) then
             begin
               if (Is_Signed(right.resultdef)) then
                 begin
                    helper2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                    if power = 1 then
                      helper1:=numerator
                    else
                      begin
                        helper1:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                        cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SAR,opsize,resultdef.Size*8-1,numerator,helper1);
                      end;
                    shifterop_reset(so);
                    so.ShiftMode:=SM_LSR;
                    so.ShiftImm:=resultdef.Size*8-power;
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_ADD,helper2,numerator,helper1,so));
                    cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SAR,Def_CGSize(resultdef),power,helper2,resultreg);

                    if (TOrdConstNode(right).Value < 0) then
                      { Invert the result }
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_NEG,resultreg,resultreg));
                  end
                else
                  cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHR,opsize,power,numerator,resultreg)
             end
           else
             { Generic division }
             begin
               if Is_Signed(left.resultdef) then
                 op:=A_SDIV
               else
                 op:=A_UDIV;

               { If we didn't acquire the original divisor earlier, grab it now }
               if divider = NR_NO then
                 begin
                   divider:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                   cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,opsize,TOrdConstNode(right).Value.svalue,divider);
                 end;

               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(op,resultreg,numerator,divider));
             end;
         end;

       procedure genOverflowCheck;
         begin
           { in case of overflow checking, also check for low(int64) div (-1)
             (no hardware support for this either) }
           if (cs_check_overflow in CurrentSettings.LocalSwitches) and
              Is_Signed(left.resultdef) and
              ((right.nodetype<>ordconstn) or
               (TOrdConstNode(right).Value=-1)) then
             begin
               { num=ffff... and div=8000... <=>
                 num xor not(div xor 8000...) = 0
                 (and we have the "eon" operation, which performs "xor not(...)" }
               tmpreg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,left.resultdef);
               hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,left.resultdef,low(int64),numerator,tmpreg);
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_EON,
                 tmpreg,numerator,tmpreg));
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_CMP,tmpreg,0));
               { now the zero/equal flag is set in case we divided low(int64) by
                 (-1) }
               Location_Reset(overflowloc,LOC_FLAGS,OS_NO);
               overflowloc.ResFlags:=F_EQ;
               cg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,location,resultdef,overflowloc);
             end;
         end;

      begin
        SecondPass(left);
        SecondPass(right);
        { avoid warning }
        divider := NR_NO;
        largernumreg := NR_NO;
        expandword := False;

        opsize := Def_CGSize(resultdef);

        { set result location }
        Location_Reset(location,LOC_REGISTER,opsize);
        location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
        resultreg:=location.Register;

        { put numerator in register }
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true);
        numerator:=left.Location.Register;

        if (right.nodetype=ordconstn) then
          begin
            { If optimising for size, just use regular division operations }
            if (cs_opt_size in CurrentSettings.OptimizerSwitches) or
              ((TOrdConstNode(right).Value=1) or
              (TOrdConstNode(right).Value=int64(-1)) or
              IsAbsPowerOf2(TOrdConstNode(right).Value,power)) then
              begin

                { Store divisor for later (and executed at the same time as the multiplication) }
                if (nodetype=modn) then
                  begin
                    if (TOrdConstNode(right).Value = 1) or (TOrdConstNode(right).Value = int64(-1)) then
                      begin
                        { Just evaluates to zero }
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_MOVZ,resultreg, 0));
                        Exit;
                      end
                    { "not cs_opt_size" saves from checking the value of the divisor again
                      (if cs_opt_size is not set, then the divisor is a power of 2) }
                    else if not (cs_opt_size in CurrentSettings.OptimizerSwitches) then
                      begin
                        divider:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                        cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,opsize,TOrdConstNode(right).Value.svalue,divider);
                      end
                  end;

                genOrdConstNodeDiv;
                genOverflowCheck;

                { in case of modulo, multiply result again by the divider and subtract
                  from the numerator }
                if (nodetype=modn) then
                  begin
                    if IsPowerOf2(TOrdConstNode(right).Value,power) then
                      begin
                        shifterop.ShiftMode := SM_LSL;
                        shifterop.ShiftImm := power;

                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_SUB,resultreg,numerator,resultreg,shifterop));
                      end
                    else
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_reg(A_MSUB,resultreg,
                        resultreg,divider,numerator));
                  end;

                Exit;
              end
            else
              begin
                if Is_Signed(left.resultdef) then
                  begin
                    if (nodetype=modn) then { Signed mod doesn't work properly }
                      begin
                        divider:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                        cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,opsize,TOrdConstNode(right).Value.svalue,divider);
                        genOrdConstNodeDiv;
                      end
                    else
                      begin
                        { Read signed value to avoid Internal Error 200706094 }
                        dividend := TOrdConstNode(right).Value.svalue;

                        Calc_DivConst_Magic_Signed(resultdef.Size * 8, dividend, reciprocal_signed, shift);
                        cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList, opsize, reciprocal_signed, resultreg);

                        { SMULH is only available for the full 64-bit registers }
                        if opsize in [OS_64, OS_S64] then
                          begin
                            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_SMULH,resultreg,resultreg,numerator));
                            largerresreg := resultreg;
                          end
                        else
                          begin
                            largerresreg := NewReg(GetRegType(resultreg), GetSupReg(resultreg), R_SUBWHOLE);
                            largernumreg := NewReg(GetRegType(numerator), GetSupReg(numerator), R_SUBWHOLE);
                            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_MUL,largerresreg,largerresreg,largernumreg));
                            expandword := True; { Merge the shift operation with something below }
                          end;

                        { Store divisor for later (and executed at the same time as the multiplication) }
                        if nodetype=modn then
                          begin
                            divider:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                            cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,opsize,dividend,divider);
                          end;

                        { add or subtract dividend }
                        if (dividend > 0) and (reciprocal_signed < 0) then
                          begin
                            if expandword then
                              begin
                                shifterop.ShiftMode := SM_ASR;
                                shifterop.ShiftImm := 32;
                                expandword := False;
                                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_ADD,largerresreg,largernumreg,largerresreg,shifterop));
                              end
                            else
                              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_ADD,resultreg,resultreg,numerator));
                          end
                        else if (dividend < 0) and (reciprocal_signed > 0) then
                          begin
                            if expandword then
                              begin
                                { We can't append LSR to the SUB below because it's on the wrong operand }
                                expandword := False;
                                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_ASR,largerresreg,largerresreg,32));
                              end;

                            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_SUB,resultreg,resultreg,numerator));
                          end
                        else if expandword then
                          Inc(shift,32);

                        { shift if necessary }
                        if (shift <> 0) then
                          begin
                            if expandword then
                              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_ASR,largerresreg,largerresreg,shift))
                            else
                              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_ASR,resultreg,resultreg,shift));
                          end;

                        { extract and add the sign bit }
                        shifterop.ShiftMode := SM_LSR;
                        shifterop.ShiftImm := left.resultdef.Size*8 - 1;

                        if (dividend < 0) then
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_ADD,resultreg,resultreg,resultreg,shifterop))
                        else
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_ADD,resultreg,resultreg,numerator,shifterop));
                      end;
                  end
                else
                  begin
                    Calc_DivConst_Magic_Unsigned(resultdef.Size * 8, TOrdConstNode(right).Value, reciprocal, magic_add, shift);
                    { Add explicit typecast to tcgint type, to avoid range or overflow check }
                    cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList, opsize, TCGInt(reciprocal), resultreg);
                    { UMULH is only available for the full 64-bit registers }
                    if opsize in [OS_64, OS_S64] then
                      begin
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_UMULH,resultreg,resultreg,numerator));
                        largerresreg := resultreg;
                      end
                    else
                      begin
                        largerresreg := NewReg(GetRegType(resultreg), GetSupReg(resultreg), R_SUBWHOLE);
                        largernumreg := NewReg(GetRegType(numerator), GetSupReg(numerator), R_SUBWHOLE);
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_MUL,largerresreg,largerresreg,largernumreg));
                        expandword := True; { Try to merge the shift operation with something below }
                      end;

                    { Store divisor for later (and executed at the same time as the multiplication) }
                    if (nodetype=modn) then
                      begin
                        divider:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                        cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,opsize,TOrdConstNode(right).Value.svalue,divider);
                      end;

                    if magic_add then
                      begin
                        { We can't append LSR to the ADD below because it would require extending the registers
                          and interfere with the carry bit }
                        if expandword then
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_LSR,largerresreg,largerresreg,32));

                        { Add the reciprocal to the high-order word, tracking the carry bit, shift, then
                          insert the carry bit via CSEL and ORR }

                        if opsize in [OS_64,OS_S64] then
                          zeroreg := NR_XZR
                        else
                          zeroreg := NR_WZR;

                        high_bit := QWord(1) shl ((resultdef.Size * 8) - shift);

                        tmpreg := cg.GetIntRegister(CurrentAsmData.CurrAsmList, opsize);
                        cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList, opsize, high_bit, tmpreg);

                        { Generate ADDS instruction }
                        hp := TAICPU.op_reg_reg_reg(A_ADD,resultreg,resultreg,numerator);
                        hp.oppostfix := PF_S;
                        CurrentAsmData.CurrAsmList.concat(hp);

                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_CSEL,tmpreg,tmpreg,zeroreg, C_CS));

                        if shift>=TCgSize2Size[opsize]*8 then
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_MOV,resultreg,tmpreg))
                        else
                          begin
                            shifterop.ShiftMode := SM_LSR;
                            shifterop.ShiftImm := shift;

                            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_ORR,resultreg,tmpreg,resultreg,shifterop));
                          end;
                      end
                    else if expandword then
                      { Include the right-shift by 32 to get the high-order DWord }
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_LSR,largerresreg,largerresreg,shift + 32))
                    else
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_LSR,resultreg,resultreg,shift));
                  end;

              end;

          end
        { no divide-by-zero detection available in hardware, emulate (if it's a
          constant, this will have been detected earlier already) }
        else
          begin
            { load divider in a register }
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,right.resultdef,true);
            divider:=right.Location.Register;

            { ARM-64 developer guides recommend checking for division by zero conditions
              AFTER the division, since the check and the division can be done in tandem }
            if Is_Signed(left.resultdef) then
              op:=A_SDIV
            else
              op:=A_UDIV;

            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(op,resultreg,numerator,divider));

            if not(node_not_zero(right)) then
              begin
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_CMP,divider,0));
                CurrentAsmData.getjumplabel(hl);
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_cond_sym(A_B,C_NE,hl));
                cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_DIVBYZERO',false);
                cg.A_Label(CurrentAsmData.CurrAsmList,hl);
              end;
          end;

        genOverflowCheck;

        { in case of modulo, multiply result again by the divider and subtract
          from the numerator }
        if (nodetype=modn) then
          begin
            { If we didn't acquire the original divisor earlier, grab it now }
            if divider = NR_NO then
              begin
                divider:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);
                cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,opsize,TOrdConstNode(right).Value.svalue,divider);
              end;

            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_reg(A_MSUB,resultreg,
              resultreg,divider,numerator));
          end;
    end;


{*****************************************************************************
                               taarch64notnode
*****************************************************************************}

    procedure TAArch64NotNode.second_boolean;
      begin
        SecondPass(left);
        if not handle_locjump then
          begin
            case left.Location.Loc of
              LOC_FLAGS :
                begin
                  Location_Copy(location,left.Location);
                  inverse_flags(location.ResFlags);
                end;
              LOC_REGISTER, LOC_CREGISTER,
              LOC_REFERENCE, LOC_CREFERENCE,
              LOC_SUBSETREG, LOC_CSUBSETREG,
              LOC_SUBSETREF, LOC_CSUBSETREF:
                begin
                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true);
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_CMP,
                    left.Location.Register,0));
                  Location_Reset(location,LOC_FLAGS,OS_NO);
                  location.ResFlags:=F_EQ;
               end;
              else
                InternalError(2003042401);
            end;
          end;
      end;


{*****************************************************************************
                                   taarch64unaryminusnode
*****************************************************************************}

    function TAArch64UnaryMinusNode.pass_1: TNode;
      begin
        Result:=inherited pass_1;
        if Result=nil then
          if Needs_Check_For_FPU_Exceptions then
            Include(CurrentProcInfo.flags,pi_do_call);
      end;


    procedure TAArch64UnaryMinusNode.second_float;
      begin
        SecondPass(left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
        Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));
        location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FNEG,location.Register,left.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;

begin
   CModDivNode:=TAArch64ModDivNode;
   CNotNode:=TAArch64NotNode;
   CUnaryMinusNode:=TAArch64UnaryMinusNode;
end.
