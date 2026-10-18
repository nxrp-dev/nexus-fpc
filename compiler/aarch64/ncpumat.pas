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
         function Pass_1: TNode; override;
         procedure Pass_Generate_Code;override;
      end;

      TAArch64NotNode = class(TCGNotNode)
         procedure Second_Boolean;override;
      end;

      TAArch64UnaryMinusNode = class(TCGUnaryMinusNode)
         function Pass_1: TNode; override;
         procedure Second_Float; override;
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

    function TAArch64ModDivNode.Pass_1: TNode;
      begin
        Result:=inherited Pass_1;
        if not Assigned(Result) and not(Node_Not_Zero(Right)) then
          include(CurrentProcInfo.Flags,pi_do_call);
      end;


    procedure TAArch64ModDivNode.Pass_Generate_Code;
      var
         lOp         : TAsmOp;
         lTempReg,
         lZeroReg,
         lNumeratorReg,
         lDivisorReg,
         lLargerNumeratorReg,
         lLargerResultReg,
         lResultReg  : TRegister;
         lLabel         : TAsmLabel;
         lOverflowLoc: TLocation;
         lPower      : LongInt;
         lOpSize     : TCgSize;

         lDivisorValue   : Int64;
         lHighBit,
         lReciprocal : QWord;
         { Just to save on stack space and the like }
         lReciprocalSigned : Int64 absolute lReciprocal;

         lExpandWord,
         lMagicAdd  : Boolean;
         lShift      : Byte;

         lShifterOp  : TShifterOp;
         lInstruction         : TAICPU;

       procedure GenOrdConstNodeDiv;
         var
           lHelperReg1, lHelperReg2: TRegister;
           lOperandShift: TShifterOp;
         begin
           if TOrdConstNode(Right).Value=0 then
             InternalError(2020021601)
           else if TOrdConstNode(Right).Value=1 then
             cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList, lOpSize, lOpSize, lNumeratorReg, lResultReg)
           else if (TOrdConstNode(Right).Value = Int64(-1)) then
             begin
               // note: only in the signed case possible..., may overflow
               if cs_check_overflow in CurrentSettings.LocalSwitches then
                 cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

               CurrentAsmData.CurrAsmList.concat(setoppostfix(TAICPU.op_reg_reg(A_NEG,
                 lResultReg,lNumeratorReg),TOpPostfix(ord(cs_check_overflow in CurrentSettings.LocalSwitches)*ord(PF_S))));
             end
           else if IsAbsPowerOf2(TOrdConstNode(Right).Value,lPower) then
             begin
               if (Is_Signed(Right.ResultDef)) then
                 begin
                    lHelperReg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
                    if lPower = 1 then
                      lHelperReg1:=lNumeratorReg
                    else
                      begin
                        lHelperReg1:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
                        cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SAR,lOpSize,ResultDef.Size*8-1,lNumeratorReg,lHelperReg1);
                      end;
                    shifterop_reset(lOperandShift);
                    lOperandShift.ShiftMode:=SM_LSR;
                    lOperandShift.ShiftImm:=ResultDef.Size*8-lPower;
                    CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_ADD,lHelperReg2,lNumeratorReg,lHelperReg1,lOperandShift));
                    cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SAR,Def_CGSize(ResultDef),lPower,lHelperReg2,lResultReg);

                    if (TOrdConstNode(Right).Value < 0) then
                      { Invert the result }
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_NEG,lResultReg,lResultReg));
                  end
                else
                  cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHR,lOpSize,lPower,lNumeratorReg,lResultReg)
             end
           else
             { Generic division }
             begin
               if Is_Signed(Left.ResultDef) then
                 lOp:=A_SDIV
               else
                 lOp:=A_UDIV;

               { If we didn't acquire the original divisor earlier, grab it now }
               if lDivisorReg = NR_NO then
                 begin
                   lDivisorReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
                   cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,lOpSize,TOrdConstNode(Right).Value.svalue,lDivisorReg);
                 end;

               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(lOp,lResultReg,lNumeratorReg,lDivisorReg));
             end;
         end;

       procedure GenOverflowCheck;
         begin
           { in case of overflow checking, also check for low(int64) div (-1)
             (no hardware support for this either) }
           if (cs_check_overflow in CurrentSettings.LocalSwitches) and
              Is_Signed(Left.ResultDef) and
              ((Right.NodeType<>ordconstn) or
               (TOrdConstNode(Right).Value=-1)) then
             begin
               { num=ffff... and div=8000... <=>
                 num xor not(div xor 8000...) = 0
                 (and we have the "eon" operation, which performs "xor not(...)" }
               lTempReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,Left.ResultDef);
               hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,Left.ResultDef,low(Int64),lNumeratorReg,lTempReg);
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_EON,
                 lTempReg,lNumeratorReg,lTempReg));
               CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_CMP,lTempReg,0));
               { now the zero/equal flag is set in case we divided low(int64) by
                 (-1) }
               Location_Reset(lOverflowLoc,LOC_FLAGS,OS_NO);
               lOverflowLoc.ResFlags:=F_EQ;
               cg.G_OverflowCheck_Loc(CurrentAsmData.CurrAsmList,Location,ResultDef,lOverflowLoc);
             end;
         end;

      begin
        SecondPass(Left);
        SecondPass(Right);
        { avoid warning }
        lDivisorReg := NR_NO;
        lLargerNumeratorReg := NR_NO;
        lExpandWord := False;

        lOpSize := Def_CGSize(ResultDef);

        { set result location }
        Location_Reset(Location,LOC_REGISTER,lOpSize);
        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
        lResultReg:=Location.Register;

        { put numerator in register }
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
        lNumeratorReg:=Left.Location.Register;

        if (Right.NodeType=ordconstn) then
          begin
            { If optimising for size, just use regular division operations }
            if (cs_opt_size in CurrentSettings.OptimizerSwitches) or
              ((TOrdConstNode(Right).Value=1) or
              (TOrdConstNode(Right).Value=Int64(-1)) or
              IsAbsPowerOf2(TOrdConstNode(Right).Value,lPower)) then
              begin

                { Store divisor for later (and executed at the same time as the multiplication) }
                if (NodeType=modn) then
                  begin
                    if (TOrdConstNode(Right).Value = 1) or (TOrdConstNode(Right).Value = Int64(-1)) then
                      begin
                        { Just evaluates to zero }
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_MOVZ,lResultReg, 0));
                        Exit;
                      end
                    { "not cs_opt_size" saves from checking the value of the divisor again
                      (if cs_opt_size is not set, then the divisor is a power of 2) }
                    else if not (cs_opt_size in CurrentSettings.OptimizerSwitches) then
                      begin
                        lDivisorReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
                        cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,lOpSize,TOrdConstNode(Right).Value.svalue,lDivisorReg);
                      end
                  end;

                GenOrdConstNodeDiv;
                GenOverflowCheck;

                { in case of modulo, multiply result again by the divider and subtract
                  from the numerator }
                if (NodeType=modn) then
                  begin
                    if IsPowerOf2(TOrdConstNode(Right).Value,lPower) then
                      begin
                        lShifterOp.ShiftMode := SM_LSL;
                        lShifterOp.ShiftImm := lPower;

                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_SUB,lResultReg,lNumeratorReg,lResultReg,lShifterOp));
                      end
                    else
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_reg(A_MSUB,lResultReg,
                        lResultReg,lDivisorReg,lNumeratorReg));
                  end;

                Exit;
              end
            else
              begin
                if Is_Signed(Left.ResultDef) then
                  begin
                    if (NodeType=modn) then { Signed mod doesn't work properly }
                      begin
                        lDivisorReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
                        cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,lOpSize,TOrdConstNode(Right).Value.svalue,lDivisorReg);
                        GenOrdConstNodeDiv;
                      end
                    else
                      begin
                        { Read signed value to avoid Internal Error 200706094 }
                        lDivisorValue := TOrdConstNode(Right).Value.svalue;

                        Calc_DivConst_Magic_Signed(ResultDef.Size * 8, lDivisorValue, lReciprocalSigned, lShift);
                        cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList, lOpSize, lReciprocalSigned, lResultReg);

                        { SMULH is only available for the full 64-bit registers }
                        if lOpSize in [OS_64, OS_S64] then
                          begin
                            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_SMULH,lResultReg,lResultReg,lNumeratorReg));
                            lLargerResultReg := lResultReg;
                          end
                        else
                          begin
                            lLargerResultReg := NewReg(GetRegType(lResultReg), GetSupReg(lResultReg), R_SUBWHOLE);
                            lLargerNumeratorReg := NewReg(GetRegType(lNumeratorReg), GetSupReg(lNumeratorReg), R_SUBWHOLE);
                            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_MUL,lLargerResultReg,lLargerResultReg,lLargerNumeratorReg));
                            lExpandWord := True; { Merge the shift operation with something below }
                          end;

                        { Store divisor for later (and executed at the same time as the multiplication) }
                        if NodeType=modn then
                          begin
                            lDivisorReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
                            cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,lOpSize,lDivisorValue,lDivisorReg);
                          end;

                        { add or subtract dividend }
                        if (lDivisorValue > 0) and (lReciprocalSigned < 0) then
                          begin
                            if lExpandWord then
                              begin
                                lShifterOp.ShiftMode := SM_ASR;
                                lShifterOp.ShiftImm := 32;
                                lExpandWord := False;
                                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_ADD,lLargerResultReg,lLargerNumeratorReg,lLargerResultReg,lShifterOp));
                              end
                            else
                              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_ADD,lResultReg,lResultReg,lNumeratorReg));
                          end
                        else if (lDivisorValue < 0) and (lReciprocalSigned > 0) then
                          begin
                            if lExpandWord then
                              begin
                                { We can't append LSR to the SUB below because it's on the wrong operand }
                                lExpandWord := False;
                                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_ASR,lLargerResultReg,lLargerResultReg,32));
                              end;

                            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_SUB,lResultReg,lResultReg,lNumeratorReg));
                          end
                        else if lExpandWord then
                          Inc(lShift,32);

                        { shift if necessary }
                        if (lShift <> 0) then
                          begin
                            if lExpandWord then
                              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_ASR,lLargerResultReg,lLargerResultReg,lShift))
                            else
                              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_ASR,lResultReg,lResultReg,lShift));
                          end;

                        { extract and add the sign bit }
                        lShifterOp.ShiftMode := SM_LSR;
                        lShifterOp.ShiftImm := Left.ResultDef.Size*8 - 1;

                        if (lDivisorValue < 0) then
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_ADD,lResultReg,lResultReg,lResultReg,lShifterOp))
                        else
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_ADD,lResultReg,lResultReg,lNumeratorReg,lShifterOp));
                      end;
                  end
                else
                  begin
                    Calc_DivConst_Magic_Unsigned(ResultDef.Size * 8, TOrdConstNode(Right).Value, lReciprocal, lMagicAdd, lShift);
                    { Add explicit typecast to tcgint type, to avoid range or overflow check }
                    cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList, lOpSize, TCGInt(lReciprocal), lResultReg);
                    { UMULH is only available for the full 64-bit registers }
                    if lOpSize in [OS_64, OS_S64] then
                      begin
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_UMULH,lResultReg,lResultReg,lNumeratorReg));
                        lLargerResultReg := lResultReg;
                      end
                    else
                      begin
                        lLargerResultReg := NewReg(GetRegType(lResultReg), GetSupReg(lResultReg), R_SUBWHOLE);
                        lLargerNumeratorReg := NewReg(GetRegType(lNumeratorReg), GetSupReg(lNumeratorReg), R_SUBWHOLE);
                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_MUL,lLargerResultReg,lLargerResultReg,lLargerNumeratorReg));
                        lExpandWord := True; { Try to merge the shift operation with something below }
                      end;

                    { Store divisor for later (and executed at the same time as the multiplication) }
                    if (NodeType=modn) then
                      begin
                        lDivisorReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
                        cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,lOpSize,TOrdConstNode(Right).Value.svalue,lDivisorReg);
                      end;

                    if lMagicAdd then
                      begin
                        { We can't append LSR to the ADD below because it would require extending the registers
                          and interfere with the carry bit }
                        if lExpandWord then
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_LSR,lLargerResultReg,lLargerResultReg,32));

                        { Add the reciprocal to the high-order word, tracking the carry bit, shift, then
                          insert the carry bit via CSEL and ORR }

                        if lOpSize in [OS_64,OS_S64] then
                          lZeroReg := NR_XZR
                        else
                          lZeroReg := NR_WZR;

                        lHighBit := QWord(1) shl ((ResultDef.Size * 8) - lShift);

                        lTempReg := cg.GetIntRegister(CurrentAsmData.CurrAsmList, lOpSize);
                        cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList, lOpSize, lHighBit, lTempReg);

                        { Generate ADDS instruction }
                        lInstruction := TAICPU.op_reg_reg_reg(A_ADD,lResultReg,lResultReg,lNumeratorReg);
                        lInstruction.oppostfix := PF_S;
                        CurrentAsmData.CurrAsmList.concat(lInstruction);

                        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_CSEL,lTempReg,lTempReg,lZeroReg, C_CS));

                        if lShift>=TCgSize2Size[lOpSize]*8 then
                          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_MOV,lResultReg,lTempReg))
                        else
                          begin
                            lShifterOp.ShiftMode := SM_LSR;
                            lShifterOp.ShiftImm := lShift;

                            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_shifterop(A_ORR,lResultReg,lTempReg,lResultReg,lShifterOp));
                          end;
                      end
                    else if lExpandWord then
                      { Include the right-shift by 32 to get the high-order DWord }
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_LSR,lLargerResultReg,lLargerResultReg,lShift + 32))
                    else
                      CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_const(A_LSR,lResultReg,lResultReg,lShift));
                  end;

              end;

          end
        { no divide-by-zero detection available in hardware, emulate (if it's a
          constant, this will have been detected earlier already) }
        else
          begin
            { load divider in a register }
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,Right.ResultDef,true);
            lDivisorReg:=Right.Location.Register;

            { ARM-64 developer guides recommend checking for division by zero conditions
              AFTER the division, since the check and the division can be done in tandem }
            if Is_Signed(Left.ResultDef) then
              lOp:=A_SDIV
            else
              lOp:=A_UDIV;

            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(lOp,lResultReg,lNumeratorReg,lDivisorReg));

            if not(Node_Not_Zero(Right)) then
              begin
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_CMP,lDivisorReg,0));
                CurrentAsmData.getjumplabel(lLabel);
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_cond_sym(A_B,C_NE,lLabel));
                cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_DIVBYZERO',false);
                cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
              end;
          end;

        GenOverflowCheck;

        { in case of modulo, multiply result again by the divider and subtract
          from the numerator }
        if (NodeType=modn) then
          begin
            { If we didn't acquire the original divisor earlier, grab it now }
            if lDivisorReg = NR_NO then
              begin
                lDivisorReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);
                cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,lOpSize,TOrdConstNode(Right).Value.svalue,lDivisorReg);
              end;

            CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_reg(A_MSUB,lResultReg,
              lResultReg,lDivisorReg,lNumeratorReg));
          end;
    end;


{*****************************************************************************
                               taarch64notnode
*****************************************************************************}

    procedure TAArch64NotNode.Second_Boolean;
      begin
        SecondPass(Left);
        if not Handle_LocJump then
          begin
            case Left.Location.Loc of
              LOC_FLAGS :
                begin
                  Location_Copy(Location,Left.Location);
                  inverse_flags(Location.ResFlags);
                end;
              LOC_REGISTER, LOC_CREGISTER,
              LOC_REFERENCE, LOC_CREFERENCE,
              LOC_SUBSETREG, LOC_CSUBSETREG,
              LOC_SUBSETREF, LOC_CSUBSETREF:
                begin
                  hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_CMP,
                    Left.Location.Register,0));
                  Location_Reset(Location,LOC_FLAGS,OS_NO);
                  Location.ResFlags:=F_EQ;
               end;
              else
                InternalError(2003042401);
            end;
          end;
      end;


{*****************************************************************************
                                   taarch64unaryminusnode
*****************************************************************************}

    function TAArch64UnaryMinusNode.Pass_1: TNode;
      begin
        Result:=inherited Pass_1;
        if Result=nil then
          if Needs_Check_For_FPU_Exceptions then
            Include(CurrentProcInfo.Flags,pi_do_call);
      end;


    procedure TAArch64UnaryMinusNode.Second_Float;
      begin
        SecondPass(Left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
        Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
        Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FNEG,Location.Register,Left.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;

begin
   CModDivNode:=TAArch64ModDivNode;
   CNotNode:=TAArch64NotNode;
   CUnaryMinusNode:=TAArch64UnaryMinusNode;
end.
