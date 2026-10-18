{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate x86 code for math nodes

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
unit nx86mat;

{$i fpcdefs.inc}

interface

    uses
      node,ncgmat;

    type
      TX86UnaryMinusNode = class(TCGUnaryMinusNode)
         procedure Second_Float;override;
         function Pass_1:TNode;override;
      end;

      TX86NotNode = class(TCGNotNode)
         procedure Second_Boolean;override;
      end;

      TX86ModDivNode = class(TCGModDivNode)
         procedure Pass_Generate_Code;override;
      end;

      TX86ShlShrNode = class(TCGShlShrNode)
      end;

  implementation

    uses
      GlobType,
      ConstExp,
      CUtils,Verbose,Globals,
      symconst,symdef,
      aasmbase,aasmtai,aasmcpu,AAsmData,defutil,
      cgbase,Pass_1,pass_2,
      ncon,
      cpubase,CPUInfo,
      cga,cgobj,hlcgobj,cgx86,cgutils,
      tgobj;


{*****************************************************************************
                          TI386UNARYMINUSNODE
*****************************************************************************}

    function TX86UnaryMinusNode.Pass_1 : TNode;
      begin
         Result:=nil;
         FirstPass(Left);
         if CodeGenError then
           exit;

         if (Left.ResultDef.typ=floatdef) then
           begin
             if Use_VectorFPU(Left.ResultDef) then
               ExpectLoc:=LOC_MMREGISTER
             else
               ExpectLoc:=LOC_FPUREGISTER;
           end
         else
           inherited Pass_1;
      end;




    procedure TX86UnaryMinusNode.Second_Float;
      var
        lLabel: TAsmLabel;
        lReference: TReference;
        lReg: TRegister;
      begin
        SecondPass(Left);

        if ExpectLoc=LOC_MMREGISTER then
          begin
            if cs_opt_fastmath in CurrentSettings.OptimizerSwitches then
              begin
                if not(Left.Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER,LOC_CREFERENCE,LOC_REFERENCE]) then
                  hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
                Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));

                Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Def_CGSize(ResultDef));
                cg.A_OpMM_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,Location.Size,Location.Register,Location.Register,nil);
                cg.A_OpMM_Loc_Reg(CurrentAsmData.CurrAsmList,OP_SUB,Location.Size,Left.Location,Location.Register,MMS_MoveScalar);
              end
            else
              begin
                Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));

                CurrentAsmData.getdatalabel(lLabel);
                new_section(CurrentAsmData.asmlists[al_typedconsts],sec_rodata_norel,lLabel.name,Const_Align(16));
                CurrentAsmData.asmlists[al_typedconsts].concat(TAILabel.Create(lLabel));
                case Def_CGSize(ResultDef) of
                  OS_F32:
                    CurrentAsmData.asmlists[al_typedconsts].concat(TAIConst.create_32bit(LongInt(1 shl 31)));
                  OS_F64:
                    begin
                      CurrentAsmData.asmlists[al_typedconsts].concat(TAIConst.create_32bit(0));
                      CurrentAsmData.asmlists[al_typedconsts].concat(TAIConst.create_32bit(-(1 shl 31)));
                    end
                  else
                    InternalError(2004110215);
                end;

                Reference_Reset_Symbol(lReference,lLabel,0,ResultDef.Alignment,[]);

                if UseAVX then
                  begin
                    if not(Left.Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                      hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
                    Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Def_CGSize(ResultDef));
                    cg.A_OpMM_Ref_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,Left.Location.Size,lReference,Left.Location.Register,Location.Register,nil)
                  end
                else
                  begin
                    if not(Left.Location.Loc=LOC_MMREGISTER) then
                      hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,false);
                    Location.Register:=Left.Location.Register;
                    cg.A_OpMM_Ref_Reg(CurrentAsmData.CurrAsmList,OP_XOR,Left.Location.Size,lReference,Location.Register,MMS_MoveScalar);
                  end;
              end;
          end
        else
          begin
            Location_Reset(Location,LOC_FPUREGISTER,Def_CGSize(ResultDef));
            case Left.Location.Loc of
              LOC_REFERENCE,
              LOC_CREFERENCE:
                begin
                  Location.Register:=NR_ST;
                  cg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,
                     Left.Location.Size,Location.Size,
                     Left.Location.Reference,Location.Register);
                  emit_none(A_FCHS,S_NO);
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER:
                begin
                   { "load st,st" is ignored by the code generator }
                   cg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,Left.Location.Size,Location.Size,Left.Location.Register,NR_ST);
                   Location.Register:=NR_ST;
                   emit_none(A_FCHS,S_NO);
                end;
              else
                InternalError(200312241);
            end;
          end;
      end;


{*****************************************************************************
                               TX86NOTNODE
*****************************************************************************}

    procedure TX86NotNode.Second_Boolean;
      var
         lOpSize : TCgSize;
         {$if defined(cpu32bitalu)}
         lReg: TRegister;
         {$endif}
      begin
        lOpSize:=Def_CGSize(ResultDef);

        SecondPass(Left);
        if not Handle_LocJump then
         begin
           case Left.Location.Loc of
             LOC_FLAGS :
               begin
                 Location_Reset(Location,LOC_FLAGS,OS_NO);
                 Location.ResFlags:=Left.Location.ResFlags;
                 inverse_flags(Location.ResFlags);
               end;
             LOC_CREFERENCE,
             LOC_REFERENCE:
               begin
{$if defined(cpu32bitalu)}
                 if Is_64Bit(ResultDef) then
                   begin
                     lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                     TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,Left.Location.Reference);
                     cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,Left.Location.Reference,lReg);
                     inc(Left.Location.Reference.Offset,4);
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                     cg.A_Op_Ref_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_32,Left.Location.Reference,lReg);
                   end
                 else
{$endif}
                   begin
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                     emit_const_ref(A_CMP, TCGSize2Opsize[lOpSize], 0, Left.Location.Reference);
                   end;
                 Location_Reset(Location,LOC_FLAGS,OS_NO);
                 Location.ResFlags:=F_E;
               end;
             LOC_CONSTANT,
             LOC_REGISTER,
             LOC_CREGISTER,
             LOC_SUBSETREG,
             LOC_CSUBSETREG,
             LOC_SUBSETREF,
             LOC_CSUBSETREF :
               begin
{$if defined(cpu32bitalu)}
                 if Is_64Bit(ResultDef) then
                   begin
                     hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,ResultDef,false);
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                     emit_reg_reg(A_OR,S_L,Left.Location.Register64.RegHi,Left.Location.Register64.RegLo);
                   end
                 else
{$endif}
                   begin
                     hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,ResultDef,true);
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                     emit_reg_reg(A_TEST,TCGSize2Opsize[lOpSize],Left.Location.Register,Left.Location.Register);
                   end;
                 Location_Reset(Location,LOC_FLAGS,OS_NO);
                 Location.ResFlags:=F_E;
               end;
            else
               InternalError(200203224);
           end;
         end;
      end;




{*****************************************************************************
                             TX86MODDIVNODE
*****************************************************************************}

    procedure TX86ModDivNode.Pass_Generate_Code;
      var
        lReg1,lReg2,lReg3,lReg4,lRegA,lRegD,lTempReg:TRegister;
        lPower:LongInt;
        lInstruction:TAICPU;
        lOp:TAsmOp;
        lCGSize:TCgSize;
        lOpSize:TOpSize;
        lSignedDivisor, lSignedMultiplier: aint;
        lUnsignedDivisor,lMagicValue: aword;
        lMagicAdd, lInvertSign: Boolean;
        lShift: Byte;
      label
        DefaultDiv;


        procedure DoBMI2ReciprocalDivision;
          var
            lExpandedRegD: TRegister;
            lExpandedOpSize: TOpSize;
            lDoMod: Boolean;
            lSubSize: TSubRegister;
            lDivSize: Byte;
          begin
            lDoMod := (NodeType = modn);

            { Extend 32-bit divides to 64-bit registers and 16-bit
              divides to 32-bit registers.  Because the domain of
              the left input is only up to 2^(X/2 - 1) - 1, (i.e.
              2^31 - 1 for 64-bit and 2^15 - 1 for 32-bit), a much
              larger error in the reciprocal is permitted. }
            if (ResultDef.Size <= {$ifdef x86_64}4{$else x86_64}2{$endif x86_64}) then
              begin
{$ifdef x86_64}
                if ResultDef.Size = 4 then
                  lDivSize := 64
                else
{$endif x86_64}
                  lDivSize := 32;

                Calc_DivConst_Magic_Unsigned(lDivSize, lUnsignedDivisor, lMagicValue, lMagicAdd, lShift);

                { Should never have a zero shift and a magic add together }
                if (lShift = 0) and lMagicAdd then
                  InternalError(2021090203);

                { Extend the input and out registers (the peephole optimizer should
                  help clean up unnecessary MOVZX instructions }
                lReg3 := lReg1;
                case ResultDef.Size of
{$ifdef x86_64}
                  4:
                    begin
                      lSubSize := R_SUBQ;
                      SetSubReg(lReg3, R_SUBQ);
                      { Make sure the upper 32 bits are zero; the peephole
                        optimizer will remove this instruction via MovAnd2Mov
                        if it's not needed }
                      emit_const_reg(A_AND, S_L, $FFFFFFFF, lReg1);
                      lExpandedRegD := NR_RDX;
                      lExpandedOpSize := S_Q;

                      if lMagicAdd then
                        { Append 1 to the tail end of the result }
                        lMagicValue := (lMagicValue shr lShift) or ($8000000000000000 shr (lShift - 1))
                      else
                        lMagicValue := lMagicValue shr lShift;
                    end;
{$endif x86_64}
                  1, 2:
                    begin
                      { MULX doesn't have a 16-bit version }
                      lSubSize := R_SUBD;
                      SetSubReg(lReg3, R_SUBD);
                      if ResultDef.Size = 1 then
                        lExpandedOpSize := S_BL
                      else
                        lExpandedOpSize := S_WL;
                      emit_reg_reg(A_MOVZX, lExpandedOpSize, lReg1, lReg3);
                      lExpandedRegD := NR_EDX;
                      lExpandedOpSize := S_L;

                      if lMagicAdd then
                        { Append 1 to the tail end of the result }
                        lMagicValue := (lMagicValue shr lShift) or ($80000000 shr (lShift - 1))
                      else
                        lMagicValue := lMagicValue shr lShift;
                    end;
                  else
                    InternalError(2021090211);
                end;

                Inc(lMagicValue);

                cg.GetCPURegister(CurrentAsmData.CurrAsmList, lExpandedRegD);
                emit_const_reg(A_MOV, lExpandedOpSize, aint(lMagicValue), lExpandedRegD);
                lReg2 := cg.GetIntRegister(CurrentAsmData.CurrAsmList, lCGSize);
                lReg4 := lReg2;
                SetSubReg(lReg4, lSubSize);

                cg.UngetCPURegister(CurrentAsmData.CurrAsmList, lExpandedRegD);
                emit_reg_reg_reg(A_MULX, lExpandedOpSize, lReg3, lReg4, lReg4);
              end
            else
              begin
                Calc_DivConst_Magic_Unsigned(ResultDef.Size * 8, lUnsignedDivisor, lMagicValue, lMagicAdd, lShift);

                { Should never have a zero shift and a magic add together }
                if (lShift = 0) and lMagicAdd then
                  InternalError(2021090204);

                cg.GetCPURegister(CurrentAsmData.CurrAsmList, lRegD);
                emit_const_reg(A_MOV, lOpSize, aint(lMagicValue), lRegD);
                lReg2 := cg.GetIntRegister(CurrentAsmData.CurrAsmList, lCGSize);
                cg.UngetCPURegister(CurrentAsmData.CurrAsmList, lRegD);
                emit_reg_reg_reg(A_MULX, lOpSize, lReg1, lReg2, lReg2);

                if lMagicAdd then
                  begin
                    { addition can overflow, shift first bit considering carry,
                      then shift remaining bits in regular way. }
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                    emit_reg_reg(A_ADD, lOpSize, lReg1, lReg2);
                    emit_const_reg(A_RCR, lOpSize, 1, lReg2);
                    cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                    dec(lShift);
                  end;
                if lShift<>0 then
                  emit_const_reg(A_SHR, lOpSize, aint(lShift), lReg2);
              end;

            if lDoMod then
              begin
                { Now multiply the quotient by the original denominator and
                  subtract the product from the original numerator to get
                  the remainder. }
{$ifdef x86_64}
                if (lCGSize in [OS_64,OS_S64]) and (lUnsignedDivisor > $7FFFFFFF) then { Cannot use 64-bit constants in IMUL }
                  begin
                    lReg4 := cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
                    emit_const_reg(A_MOV, lOpSize, aint(lUnsignedDivisor), lReg4);
                    emit_reg_reg(A_IMUL, lOpSize, lReg4, lReg2);
                  end
                else
{$endif x86_64}
                  emit_const_reg(A_IMUL, lOpSize, aint(lUnsignedDivisor), lReg2);

                emit_reg_reg(A_SUB, lOpSize, lReg2, lReg1);
                Location.Register := lReg1;
              end
            else
              Location.Register := lReg2;
          end;


        procedure DoUnsignedReciprocalDivision;
          var
            lExpandedRegA,lExpandedRegD:TRegister;
            lExpandedOpSize:TOpSize;
            lDoMod: Boolean;
          begin

            IF (CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) then
              begin
                { If BMI2 is available, use more efficient instructions }
                DoBMI2ReciprocalDivision;
                Exit;
              end;


            lDoMod := (NodeType = modn);
            { Extend 32-bit divides to 64-bit registers and 16-bit
              divides to 32-bit registers.  Because the domain of
              the left input is only up to 2^(X/2 - 1) - 1, (i.e.
              2^31 - 1 for 64-bit and 2^15 - 1 for 32-bit), a much
              larger error in the reciprocal is permitted. }
            if (ResultDef.Size <= {$ifdef x86_64}4{$else x86_64}2{$endif x86_64}) then
              begin
                Calc_DivConst_Magic_Unsigned(ResultDef.Size * 2 * 8,lUnsignedDivisor,lMagicValue,lMagicAdd,lShift);

                { Should never have a zero shift and a magic add together }
                if (lShift = 0) and lMagicAdd then
                  InternalError(2021090201);

                { Extend the input register (the peephole optimizer should
                  help clean up unnecessary MOVZX instructions }
                lReg3 := lReg1;
                case ResultDef.Size of
{$ifdef x86_64}
                  4:
                    begin
                      SetSubReg(lReg3, R_SUBQ);
                      { Make sure the upper 32 bits are zero; the peephole
                        optimizer will remove this instruction via MovAnd2Mov
                        if it's not needed }
                      emit_const_reg(A_AND, S_L, $FFFFFFFF, lReg1);
                      lExpandedRegA := NR_RAX;
                      lExpandedRegD := NR_RDX;
                      lExpandedOpSize := S_Q;

                      if lMagicAdd then
                        { Append 1 to the tail end of the result }
                        lMagicValue := (lMagicValue shr lShift) or ($8000000000000000 shr (lShift - 1))
                      else
                        lMagicValue := lMagicValue shr lShift;
                    end;
{$endif x86_64}
                  2:
                    begin
                      SetSubReg(lReg3, R_SUBD);
                      emit_reg_reg(A_MOVZX, S_WL, lReg1, lReg3);
                      lExpandedRegA := NR_EAX;
                      lExpandedRegD := NR_EDX;
                      lExpandedOpSize := S_L;

                      if lMagicAdd then
                        { Append 1 to the tail end of the result }
                        lMagicValue := (lMagicValue shr lShift) or ($80000000 shr (lShift - 1))
                      else
                        lMagicValue := lMagicValue shr lShift;
                    end;
                  1:
                    begin
                      SetSubReg(lReg3, R_SUBW);
                      emit_reg_reg(A_MOVZX, S_BW, lReg1, lReg3);
                      lExpandedRegA := NR_AX;
                      lExpandedRegD := NR_DX;
                      lRegD := NR_DL; { We need to change this from AH }
                      lExpandedOpSize := S_W;

                      if lMagicAdd then
                        { Append 1 to the tail end of the result }
                        lMagicValue := (lMagicValue shr lShift) or ($8000 shr (lShift - 1))
                      else
                        lMagicValue := lMagicValue shr lShift;
                    end;
                  else
                    InternalError(2021090210);
                end;

                Inc(lMagicValue);

                cg.GetCPURegister(CurrentAsmData.CurrAsmList,lExpandedRegA);
                emit_const_reg(A_MOV,lExpandedOpSize,aint(lMagicValue),lExpandedRegA);
                cg.GetCPURegister(CurrentAsmData.CurrAsmList,lExpandedRegD);
                emit_reg(A_MUL,lExpandedOpSize,lReg3);
                cg.UngetCPURegister(CurrentAsmData.CurrAsmList,lExpandedRegA);
                if lDoMod then
                  begin
                    lReg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
                    emit_reg_reg(A_MOV,lOpSize,lReg1,lReg2);
                  end;
              end
            else
              begin
                Calc_DivConst_Magic_Unsigned(ResultDef.Size*8,lUnsignedDivisor,lMagicValue,lMagicAdd,lShift);

                { Should never have a zero shift and a magic add together }
                if (lShift = 0) and lMagicAdd then
                  InternalError(2021090202);

                cg.GetCPURegister(CurrentAsmData.CurrAsmList,lRegA);
                emit_const_reg(A_MOV,lOpSize,aint(lMagicValue),lRegA);
                cg.GetCPURegister(CurrentAsmData.CurrAsmList,lRegD);
                emit_reg(A_MUL,lOpSize,lReg1);
                cg.UngetCPURegister(CurrentAsmData.CurrAsmList,lRegA);
                if lDoMod then
                  begin
                    lReg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
                    emit_reg_reg(A_MOV,lOpSize,lReg1,lReg2);
                  end;

                if lMagicAdd then
                  begin
                    { addition can overflow, shift first bit considering carry,
                      then shift remaining bits in regular way. }
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                    emit_reg_reg(A_ADD,lOpSize,lReg1,lRegD);
                    emit_const_reg(A_RCR,lOpSize,1,lRegD);
                    cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                    dec(lShift);
                  end;
                if lShift<>0 then
                  emit_const_reg(A_SHR,lOpSize,aint(lShift),lRegD);
              end;

            if lDoMod then
              begin
                { Now multiply the quotient by the original denominator and
                  subtract the product from the original numerator to get
                  the remainder. }
{$ifdef x86_64}
                if (lCGSize in [OS_64,OS_S64]) and (lUnsignedDivisor > $7FFFFFFF) then { Cannot use 64-bit constants in IMUL }
                  begin
                    lReg3:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
                    emit_const_reg(A_MOV,lOpSize,aint(lUnsignedDivisor),lReg3);
                    emit_reg_reg(A_IMUL,lOpSize,lReg3,lRegD);
                  end
                else
{$endif x86_64}
                  emit_const_reg(A_IMUL,lOpSize,aint(lUnsignedDivisor),lRegD);

                emit_reg_reg(A_SUB,lOpSize,lRegD,lReg2);
              end;

            cg.UngetCPURegister(CurrentAsmData.CurrAsmList,lRegD);
            if not lDoMod then
              begin
                lReg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
                cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lCGSize,lCGSize,lRegD,lReg2);
              end;

            Location.Register:=lReg2;
          end;

      begin
        SecondPass(Left);
        if CodeGenError then
          exit;
        SecondPass(Right);
        if CodeGenError then
          exit;

        { put numerator in register }
        lCGSize:=Def_CGSize(ResultDef);
        lOpSize:=TCGSize2OpSize[lCGSize];
        lRegA:=NewReg(R_INTREGISTER,RS_EAX,cgsize2subreg(R_INTREGISTER,lCGSize));
        if lCGSize in [OS_8,OS_S8] then
          lRegD:=NR_AH
        else
          lRegD:=NewReg(R_INTREGISTER,RS_EDX,cgsize2subreg(R_INTREGISTER,lCGSize));

        Location_Reset(Location,LOC_REGISTER,lCGSize);
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,ResultDef,false);
        lReg1:=Left.Location.Register;

        if (NodeType=divn) and (Right.NodeType=ordconstn) then
          begin
            if IsAbsPowerOf2(TOrdConstNode(Right).Value,lPower) then
              begin
                { for signed numbers, the numerator must be adjusted before the
                  shift instruction, but not with unsigned numbers! Otherwise,
                  "Cardinal($ffffffff) div 16" overflows! (JM) }
                if Is_Signed(Left.ResultDef) Then
                  begin
                    lInvertSign:=TOrdConstNode(Right).Value<0;
                    { use a sequence without jumps, saw this in
                      comp.compilers (JM) }
                    { no jumps, but more operations }
                    lReg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
                    emit_reg_reg(A_MOV,lOpSize,lReg1,lReg2);
                    if lPower=1 then
                      begin
                        {If the left value is negative, hreg2=(1 shl power)-1=1, otherwise 0.}
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SHR,lCGSize,ResultDef.Size*8-1,lReg2);
                      end
                    else
                      begin
                        {If the left value is negative, hreg2=$ffffffff, otherwise 0.}
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SAR,lCGSize,ResultDef.Size*8-1,lReg2);
                        {If negative, hreg2=(1 shl power)-1, otherwise 0.}
                        { (don't use emit_const_reg, because if value>high(longint)
                           then it must first be loaded into a register) }
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_AND,lCGSize,(aint(1) shl lPower)-1,lReg2);
                      end;
                    { add to the left value }
                    emit_reg_reg(A_ADD,lOpSize,lReg2,lReg1);
                    { do the shift }
                    cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SAR,lCGSize,lPower,lReg1);
                    if lInvertSign then
                      emit_reg(A_NEG,lOpSize,lReg1);
                  end
                else
                  cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SHR,lCGSize,lPower,lReg1);
                Location.Register:=lReg1;
              end
            else
              begin
                if Is_Signed(Left.ResultDef) then
                  begin
                    lSignedDivisor:=TOrdConstNode(Right).Value.svalue;
                    Calc_DivConst_Magic_Signed(ResultDef.Size*8,lSignedDivisor,lSignedMultiplier,lShift);
                    cg.GetCPURegister(CurrentAsmData.CurrAsmList,lRegA);
                    emit_const_reg(A_MOV,lOpSize,lSignedMultiplier,lRegA);
                    cg.GetCPURegister(CurrentAsmData.CurrAsmList,lRegD);
                    emit_reg(A_IMUL,lOpSize,lReg1);
                    { only the high half of result is used }
                    cg.UngetCPURegister(CurrentAsmData.CurrAsmList,lRegA);
                    { add or subtract dividend }
                    if (lSignedDivisor>0) and (lSignedMultiplier<0) then
                      emit_reg_reg(A_ADD,lOpSize,lReg1,lRegD)
                    else if (lSignedDivisor<0) and (lSignedMultiplier>0) then
                      emit_reg_reg(A_SUB,lOpSize,lReg1,lRegD);
                    { shift if necessary }
                    if (lShift<>0) then
                      emit_const_reg(A_SAR,lOpSize,lShift,lRegD);
                    { extract and add the sign bit }
                    if (lSignedDivisor<0) then
                      emit_reg_reg(A_MOV,lOpSize,lRegD,lReg1);
                    { if e>=0, hreg1 still contains dividend }
                    emit_const_reg(A_SHR,lOpSize,Left.ResultDef.Size*8-1,lReg1);
                    emit_reg_reg(A_ADD,lOpSize,lReg1,lRegD);
                    cg.UngetCPURegister(CurrentAsmData.CurrAsmList,lRegD);
                    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
                    cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lCGSize,lCGSize,lRegD,Location.Register)
                  end
                else
                  begin
                    lUnsignedDivisor:=TOrdConstNode(Right).Value.uvalue;
                    if lUnsignedDivisor>=aword(1) shl (Left.ResultDef.Size*8-1) then
                      begin
                        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
                        { Ensure that the whole register is 0, since SETcc only sets the lowest byte }

                        { If the operands are 64 bits, this XOR routine will be shrunk by the
                          peephole optimizer. [Kit] }
                        emit_reg_reg(A_XOR,lOpSize,Location.Register,Location.Register);

                        if (lCGSize in [OS_64,OS_S64]) then { Cannot use 64-bit constants in CMP }
                          begin
                            lReg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
                            emit_const_reg(A_MOV,lOpSize,aint(lUnsignedDivisor),lReg2);
                            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            emit_reg_reg(A_CMP,lOpSize,lReg2,lReg1);
                          end
                        else
                          begin
                            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            emit_const_reg(A_CMP,lOpSize,aint(lUnsignedDivisor),lReg1);
                          end;
                        { NOTE: SBB and SETAE are both 3 bytes long without the REX prefix,
                          both use an ALU for their execution and take a single cycle to
                          run. The only difference is that SETAE does not modify the flags,
                          allowing for some possible reuse. [Kit] }

                        { Emit a SETcc instruction that depends on the carry bit being zero,
                          that is, the numerator is greater than or equal to the denominator. }
                        lTempReg:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,Location.Register,OS_8);
                        lInstruction:=TAICPU.op_reg(A_SETcc,S_B,lTempReg);
                        lInstruction.condition:=C_AE;
                        CurrentAsmData.CurrAsmList.concat(lInstruction);
                        cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                      end
                    else
                      DoUnsignedReciprocalDivision;

                  end;
              end;
          end
        else if (NodeType=modn) and (Right.NodeType=ordconstn) and not(Is_Signed(Left.ResultDef)) then
          begin
            { unsigned modulus by a (+/-)power-of-2 constant? }
            if IsAbsPowerOf2(TOrdConstNode(Right).Value,lPower) then
              begin
                emit_const_reg(A_AND,lOpSize,(aint(1) shl lPower)-1,lReg1);
                Location.Register:=lReg1;
              end
            else
              begin
                lUnsignedDivisor:=TOrdConstNode(Right).Value.uvalue;
                if lUnsignedDivisor>=aword(1) shl (Left.ResultDef.Size*8-1) then
                  begin

                    if not (CPUX86_HAS_CMOV in cpu_capabilities[CurrentSettings.CPUType]) then
                      goto DefaultDiv;

                    Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
                    lReg3:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);

                    lMagicValue := aword(-aint(lUnsignedDivisor)); { Two's complement of d }

                    if (lCGSize in [OS_64,OS_S64]) then { Cannot use 64-bit constants in CMP }
                      begin
                        lReg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
                        emit_const_reg(A_MOV,lOpSize,aint(lUnsignedDivisor),lReg2);
                        emit_const_reg(A_MOV,lOpSize,aint(lMagicValue),lReg3);
                        emit_reg_reg(A_XOR,lOpSize,Location.Register,Location.Register);
                        cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                        emit_reg_reg(A_CMP,lOpSize,lReg2,lReg1);
                      end
                    else
                      begin
                        emit_const_reg(A_MOV,lOpSize,aint(lMagicValue),lReg3);
                        emit_reg_reg(A_XOR,lOpSize,Location.Register,Location.Register);

                        cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                        emit_const_reg(A_CMP,lOpSize,aint(lUnsignedDivisor),lReg1);
                      end;

                    { Emit conditional move that depends on the carry flag being zero,
                      that is, the comparison result is above or equal }
                    lInstruction:=TAICPU.op_reg_reg(A_CMOVcc,lOpSize,lReg3,Location.Register);
                    lInstruction.condition := C_AE;
                    CurrentAsmData.CurrAsmList.concat(lInstruction);
                    cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

                    emit_reg_reg(A_ADD,lOpSize,lReg1,Location.Register);
                  end
                else
                  { Convert the division to a multiplication }
                  DoUnsignedReciprocalDivision;

              end;
          end
        else if (NodeType=modn) and (Right.NodeType=ordconstn) and (Is_Signed(Left.ResultDef)) and IsAbsPowerOf2(TOrdConstNode(Right).Value,lPower) then
          begin
            lReg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
            if lPower=1 then
              cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHR,lCGSize,ResultDef.Size*8-lPower,lReg1,lReg2)
            else
              begin
                cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SAR,lCGSize,ResultDef.Size*8-1,lReg1,lReg2);
                cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHR,lCGSize,ResultDef.Size*8-lPower,lReg2,lReg2);
              end;
            emit_reg_reg(A_ADD,lOpSize,lReg1,lReg2);
            cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_AND,lCGSize,not((aint(1) shl lPower)-1),lReg2);
            emit_reg_reg(A_SUB,lOpSize,lReg2,lReg1);
            Location.Register:=lReg1;
          end
        else
          begin
DefaultDiv:
            {Bring denominator to a register.}
            cg.GetCPURegister(CurrentAsmData.CurrAsmList,lRegA);
            emit_reg_reg(A_MOV,lOpSize,lReg1,lRegA);
            cg.GetCPURegister(CurrentAsmData.CurrAsmList,lRegD);
            {Sign extension depends on the left type.}
            if Is_Signed(Left.ResultDef) then
              case Left.ResultDef.Size of
{$ifdef x86_64}
                8:
                  emit_none(A_CQO,S_NO);
{$endif x86_64}
                4:
                  emit_none(A_CDQ,S_NO);
                else
                  InternalError(2013102704);
              end
            else
              emit_reg_reg(A_XOR,lOpSize,lRegD,lRegD);

            { Division depends on the result type }
            if Is_Signed(ResultDef) then
              lOp:=A_IDIV
            else
              lOp:=A_DIV;

            if Right.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
              emit_ref(lOp,lOpSize,Right.Location.Reference)
            else if Right.Location.Loc in [LOC_REGISTER,LOC_CREGISTER] then
              emit_reg(lOp,lOpSize,Right.Location.Register)
            else
              begin
                lReg1:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Right.Location.Size);
                hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Right.ResultDef,Right.ResultDef,Right.Location,lReg1);
                emit_reg(lOp,lOpSize,lReg1);
              end;

            { Copy the result into a new register. Release R/EAX & R/EDX.}
            cg.UngetCPURegister(CurrentAsmData.CurrAsmList,lRegD);
            cg.UngetCPURegister(CurrentAsmData.CurrAsmList,lRegA);
            Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
            if NodeType=divn then
              cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lCGSize,lCGSize,lRegA,Location.Register)
            else
              cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lCGSize,lCGSize,lRegD,Location.Register);
          end;
      end;



end.
