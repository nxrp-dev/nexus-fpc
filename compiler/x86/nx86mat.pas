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
         procedure second_float;override;
         function pass_1:TNode;override;
      end;

      TX86NotNode = class(TCGNotNode)
         procedure second_boolean;override;
      end;

      TX86ModDivNode = class(TCGModDivNode)
         procedure pass_generate_code;override;
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
      cgbase,pass_1,pass_2,
      ncon,
      cpubase,CPUInfo,
      cga,cgobj,hlcgobj,cgx86,cgutils,
      tgobj;


{*****************************************************************************
                          TI386UNARYMINUSNODE
*****************************************************************************}

    function TX86UnaryMinusNode.pass_1 : TNode;
      begin
         result:=nil;
         FirstPass(left);
         if CodeGenError then
           exit;

         if (left.resultdef.typ=floatdef) then
           begin
             if Use_VectorFPU(left.resultdef) then
               expectloc:=LOC_MMREGISTER
             else
               expectloc:=LOC_FPUREGISTER;
           end
         else
           inherited pass_1;
      end;




    procedure TX86UnaryMinusNode.second_float;
      var
        l1: TAsmLabel;
        href: TReference;
        reg: TRegister;
      begin
        SecondPass(left);

        if expectloc=LOC_MMREGISTER then
          begin
            if cs_opt_fastmath in CurrentSettings.OptimizerSwitches then
              begin
                if not(left.Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER,LOC_CREFERENCE,LOC_REFERENCE]) then
                  hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
                Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));

                location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Def_CGSize(resultdef));
                cg.A_OpMM_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,location.Size,location.Register,location.Register,nil);
                cg.A_OpMM_Loc_Reg(CurrentAsmData.CurrAsmList,OP_SUB,location.Size,left.Location,location.Register,MMS_MoveScalar);
              end
            else
              begin
                Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));

                CurrentAsmData.getdatalabel(l1);
                new_section(CurrentAsmData.asmlists[al_typedconsts],sec_rodata_norel,l1.name,Const_Align(16));
                CurrentAsmData.asmlists[al_typedconsts].concat(TAILabel.Create(l1));
                case Def_CGSize(resultdef) of
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

                Reference_Reset_Symbol(href,l1,0,resultdef.Alignment,[]);

                if UseAVX then
                  begin
                    if not(left.Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                      hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
                    location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Def_CGSize(resultdef));
                    cg.A_OpMM_Ref_Reg_Reg(CurrentAsmData.CurrAsmList,OP_XOR,left.Location.Size,href,left.Location.Register,location.Register,nil)
                  end
                else
                  begin
                    if not(left.Location.Loc=LOC_MMREGISTER) then
                      hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,false);
                    location.Register:=left.Location.Register;
                    cg.A_OpMM_Ref_Reg(CurrentAsmData.CurrAsmList,OP_XOR,left.Location.Size,href,location.Register,MMS_MoveScalar);
                  end;
              end;
          end
        else
          begin
            Location_Reset(location,LOC_FPUREGISTER,Def_CGSize(resultdef));
            case left.Location.Loc of
              LOC_REFERENCE,
              LOC_CREFERENCE:
                begin
                  location.Register:=NR_ST;
                  cg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,
                     left.Location.Size,location.Size,
                     left.Location.Reference,location.Register);
                  emit_none(A_FCHS,S_NO);
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER:
                begin
                   { "load st,st" is ignored by the code generator }
                   cg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,left.Location.Size,location.Size,left.Location.Register,NR_ST);
                   location.Register:=NR_ST;
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

    procedure TX86NotNode.second_boolean;
      var
         opsize : TCgSize;
         {$if defined(cpu32bitalu)}
         hreg: TRegister;
         {$endif}
      begin
        opsize:=Def_CGSize(resultdef);

        SecondPass(left);
        if not handle_locjump then
         begin
           case left.Location.Loc of
             LOC_FLAGS :
               begin
                 Location_Reset(location,LOC_FLAGS,OS_NO);
                 location.ResFlags:=left.Location.ResFlags;
                 inverse_flags(location.ResFlags);
               end;
             LOC_CREFERENCE,
             LOC_REFERENCE:
               begin
{$if defined(cpu32bitalu)}
                 if Is_64Bit(resultdef) then
                   begin
                     hreg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                     TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,left.Location.Reference);
                     cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,left.Location.Reference,hreg);
                     inc(left.Location.Reference.Offset,4);
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                     cg.A_Op_Ref_Reg(CurrentAsmData.CurrAsmList,OP_OR,OS_32,left.Location.Reference,hreg);
                   end
                 else
{$endif}
                   begin
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                     emit_const_ref(A_CMP, TCGSize2Opsize[opsize], 0, left.Location.Reference);
                   end;
                 Location_Reset(location,LOC_FLAGS,OS_NO);
                 location.ResFlags:=F_E;
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
                 if Is_64Bit(resultdef) then
                   begin
                     hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,resultdef,false);
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                     emit_reg_reg(A_OR,S_L,left.Location.Register64.RegHi,left.Location.Register64.RegLo);
                   end
                 else
{$endif}
                   begin
                     hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,resultdef,true);
                     cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                     emit_reg_reg(A_TEST,TCGSize2Opsize[opsize],left.Location.Register,left.Location.Register);
                   end;
                 Location_Reset(location,LOC_FLAGS,OS_NO);
                 location.ResFlags:=F_E;
               end;
            else
               InternalError(200203224);
           end;
         end;
      end;




{*****************************************************************************
                             TX86MODDIVNODE
*****************************************************************************}

    procedure TX86ModDivNode.pass_generate_code;
      var
        hreg1,hreg2,hreg3,hreg4,rega,regd,tempreg:TRegister;
        power:LongInt;
        instr:TAICPU;
        op:TAsmOp;
        cgsize:TCgSize;
        opsize:TOpSize;
        e, sm: aint;
        d,m: aword;
        m_add, invertsign: boolean;
        s: byte;
      label
        DefaultDiv;


        procedure DoBMI2ReciprocalDivision;
          var
            exp_regd: TRegister;
            exp_opsize: TOpSize;
            DoMod: Boolean;
            SubSize: TSubRegister;
            divsize: Byte;
          begin
            DoMod := (nodetype = modn);

            { Extend 32-bit divides to 64-bit registers and 16-bit
              divides to 32-bit registers.  Because the domain of
              the left input is only up to 2^(X/2 - 1) - 1, (i.e.
              2^31 - 1 for 64-bit and 2^15 - 1 for 32-bit), a much
              larger error in the reciprocal is permitted. }
            if (resultdef.Size <= {$ifdef x86_64}4{$else x86_64}2{$endif x86_64}) then
              begin
{$ifdef x86_64}
                if resultdef.Size = 4 then
                  divsize := 64
                else
{$endif x86_64}
                  divsize := 32;

                Calc_DivConst_Magic_Unsigned(divsize, d, m, m_add, s);

                { Should never have a zero shift and a magic add together }
                if (s = 0) and m_add then
                  InternalError(2021090203);

                { Extend the input and out registers (the peephole optimizer should
                  help clean up unnecessary MOVZX instructions }
                hreg3 := hreg1;
                case resultdef.Size of
{$ifdef x86_64}
                  4:
                    begin
                      SubSize := R_SUBQ;
                      SetSubReg(hreg3, R_SUBQ);
                      { Make sure the upper 32 bits are zero; the peephole
                        optimizer will remove this instruction via MovAnd2Mov
                        if it's not needed }
                      emit_const_reg(A_AND, S_L, $FFFFFFFF, hreg1);
                      exp_regd := NR_RDX;
                      exp_opsize := S_Q;

                      if m_add then
                        { Append 1 to the tail end of the result }
                        m := (m shr s) or ($8000000000000000 shr (s - 1))
                      else
                        m := m shr s;
                    end;
{$endif x86_64}
                  1, 2:
                    begin
                      { MULX doesn't have a 16-bit version }
                      SubSize := R_SUBD;
                      SetSubReg(hreg3, R_SUBD);
                      if resultdef.Size = 1 then
                        exp_opsize := S_BL
                      else
                        exp_opsize := S_WL;
                      emit_reg_reg(A_MOVZX, exp_opsize, hreg1, hreg3);
                      exp_regd := NR_EDX;
                      exp_opsize := S_L;

                      if m_add then
                        { Append 1 to the tail end of the result }
                        m := (m shr s) or ($80000000 shr (s - 1))
                      else
                        m := m shr s;
                    end;
                  else
                    InternalError(2021090211);
                end;

                Inc(m);

                cg.GetCPURegister(CurrentAsmData.CurrAsmList, exp_regd);
                emit_const_reg(A_MOV, exp_opsize, aint(m), exp_regd);
                hreg2 := cg.GetIntRegister(CurrentAsmData.CurrAsmList, cgsize);
                hreg4 := hreg2;
                SetSubReg(hreg4, SubSize);

                cg.UngetCPURegister(CurrentAsmData.CurrAsmList, exp_regd);
                emit_reg_reg_reg(A_MULX, exp_opsize, hreg3, hreg4, hreg4);
              end
            else
              begin
                Calc_DivConst_Magic_Unsigned(resultdef.Size * 8, d, m, m_add, s);

                { Should never have a zero shift and a magic add together }
                if (s = 0) and m_add then
                  InternalError(2021090204);

                cg.GetCPURegister(CurrentAsmData.CurrAsmList, regd);
                emit_const_reg(A_MOV, opsize, aint(m), regd);
                hreg2 := cg.GetIntRegister(CurrentAsmData.CurrAsmList, cgsize);
                cg.UngetCPURegister(CurrentAsmData.CurrAsmList, regd);
                emit_reg_reg_reg(A_MULX, opsize, hreg1, hreg2, hreg2);

                if m_add then
                  begin
                    { addition can overflow, shift first bit considering carry,
                      then shift remaining bits in regular way. }
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                    emit_reg_reg(A_ADD, opsize, hreg1, hreg2);
                    emit_const_reg(A_RCR, opsize, 1, hreg2);
                    cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
                    dec(s);
                  end;
                if s<>0 then
                  emit_const_reg(A_SHR, opsize, aint(s), hreg2);
              end;

            if DoMod then
              begin
                { Now multiply the quotient by the original denominator and
                  subtract the product from the original numerator to get
                  the remainder. }
{$ifdef x86_64}
                if (cgsize in [OS_64,OS_S64]) and (d > $7FFFFFFF) then { Cannot use 64-bit constants in IMUL }
                  begin
                    hreg4 := cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
                    emit_const_reg(A_MOV, opsize, aint(d), hreg4);
                    emit_reg_reg(A_IMUL, opsize, hreg4, hreg2);
                  end
                else
{$endif x86_64}
                  emit_const_reg(A_IMUL, opsize, aint(d), hreg2);

                emit_reg_reg(A_SUB, opsize, hreg2, hreg1);
                location.Register := hreg1;
              end
            else
              location.Register := hreg2;
          end;


        procedure DoUnsignedReciprocalDivision;
          var
            exp_rega,exp_regd:TRegister;
            exp_opsize:TOpSize;
            DoMod: Boolean;
          begin

            IF (CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) then
              begin
                { If BMI2 is available, use more efficient instructions }
                DoBMI2ReciprocalDivision;
                Exit;
              end;


            DoMod := (nodetype = modn);
            { Extend 32-bit divides to 64-bit registers and 16-bit
              divides to 32-bit registers.  Because the domain of
              the left input is only up to 2^(X/2 - 1) - 1, (i.e.
              2^31 - 1 for 64-bit and 2^15 - 1 for 32-bit), a much
              larger error in the reciprocal is permitted. }
            if (resultdef.Size <= {$ifdef x86_64}4{$else x86_64}2{$endif x86_64}) then
              begin
                Calc_DivConst_Magic_Unsigned(resultdef.Size * 2 * 8,d,m,m_add,s);

                { Should never have a zero shift and a magic add together }
                if (s = 0) and m_add then
                  InternalError(2021090201);

                { Extend the input register (the peephole optimizer should
                  help clean up unnecessary MOVZX instructions }
                hreg3 := hreg1;
                case resultdef.Size of
{$ifdef x86_64}
                  4:
                    begin
                      SetSubReg(hreg3, R_SUBQ);
                      { Make sure the upper 32 bits are zero; the peephole
                        optimizer will remove this instruction via MovAnd2Mov
                        if it's not needed }
                      emit_const_reg(A_AND, S_L, $FFFFFFFF, hreg1);
                      exp_rega := NR_RAX;
                      exp_regd := NR_RDX;
                      exp_opsize := S_Q;

                      if m_add then
                        { Append 1 to the tail end of the result }
                        m := (m shr s) or ($8000000000000000 shr (s - 1))
                      else
                        m := m shr s;
                    end;
{$endif x86_64}
                  2:
                    begin
                      SetSubReg(hreg3, R_SUBD);
                      emit_reg_reg(A_MOVZX, S_WL, hreg1, hreg3);
                      exp_rega := NR_EAX;
                      exp_regd := NR_EDX;
                      exp_opsize := S_L;

                      if m_add then
                        { Append 1 to the tail end of the result }
                        m := (m shr s) or ($80000000 shr (s - 1))
                      else
                        m := m shr s;
                    end;
                  1:
                    begin
                      SetSubReg(hreg3, R_SUBW);
                      emit_reg_reg(A_MOVZX, S_BW, hreg1, hreg3);
                      exp_rega := NR_AX;
                      exp_regd := NR_DX;
                      regd := NR_DL; { We need to change this from AH }
                      exp_opsize := S_W;

                      if m_add then
                        { Append 1 to the tail end of the result }
                        m := (m shr s) or ($8000 shr (s - 1))
                      else
                        m := m shr s;
                    end;
                  else
                    InternalError(2021090210);
                end;

                Inc(m);

                cg.GetCPURegister(CurrentAsmData.CurrAsmList,exp_rega);
                emit_const_reg(A_MOV,exp_opsize,aint(m),exp_rega);
                cg.GetCPURegister(CurrentAsmData.CurrAsmList,exp_regd);
                emit_reg(A_MUL,exp_opsize,hreg3);
                cg.UngetCPURegister(CurrentAsmData.CurrAsmList,exp_rega);
                if DoMod then
                  begin
                    hreg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
                    emit_reg_reg(A_MOV,opsize,hreg1,hreg2);
                  end;
              end
            else
              begin
                Calc_DivConst_Magic_Unsigned(resultdef.Size*8,d,m,m_add,s);

                { Should never have a zero shift and a magic add together }
                if (s = 0) and m_add then
                  InternalError(2021090202);

                cg.GetCPURegister(CurrentAsmData.CurrAsmList,rega);
                emit_const_reg(A_MOV,opsize,aint(m),rega);
                cg.GetCPURegister(CurrentAsmData.CurrAsmList,regd);
                emit_reg(A_MUL,opsize,hreg1);
                cg.UngetCPURegister(CurrentAsmData.CurrAsmList,rega);
                if DoMod then
                  begin
                    hreg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
                    emit_reg_reg(A_MOV,opsize,hreg1,hreg2);
                  end;

                if m_add then
                  begin
                    { addition can overflow, shift first bit considering carry,
                      then shift remaining bits in regular way. }
                    cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                    emit_reg_reg(A_ADD,opsize,hreg1,regd);
                    emit_const_reg(A_RCR,opsize,1,regd);
                    cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                    dec(s);
                  end;
                if s<>0 then
                  emit_const_reg(A_SHR,opsize,aint(s),regd);
              end;

            if DoMod then
              begin
                { Now multiply the quotient by the original denominator and
                  subtract the product from the original numerator to get
                  the remainder. }
{$ifdef x86_64}
                if (cgsize in [OS_64,OS_S64]) and (d > $7FFFFFFF) then { Cannot use 64-bit constants in IMUL }
                  begin
                    hreg3:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
                    emit_const_reg(A_MOV,opsize,aint(d),hreg3);
                    emit_reg_reg(A_IMUL,opsize,hreg3,regd);
                  end
                else
{$endif x86_64}
                  emit_const_reg(A_IMUL,opsize,aint(d),regd);

                emit_reg_reg(A_SUB,opsize,regd,hreg2);
              end;

            cg.UngetCPURegister(CurrentAsmData.CurrAsmList,regd);
            if not DoMod then
              begin
                hreg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
                cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,cgsize,cgsize,regd,hreg2);
              end;

            location.Register:=hreg2;
          end;

      begin
        SecondPass(left);
        if CodeGenError then
          exit;
        SecondPass(right);
        if CodeGenError then
          exit;

        { put numerator in register }
        cgsize:=Def_CGSize(resultdef);
        opsize:=TCGSize2OpSize[cgsize];
        rega:=NewReg(R_INTREGISTER,RS_EAX,cgsize2subreg(R_INTREGISTER,cgsize));
        if cgsize in [OS_8,OS_S8] then
          regd:=NR_AH
        else
          regd:=NewReg(R_INTREGISTER,RS_EDX,cgsize2subreg(R_INTREGISTER,cgsize));

        Location_Reset(location,LOC_REGISTER,cgsize);
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,resultdef,false);
        hreg1:=left.Location.Register;

        if (nodetype=divn) and (right.nodetype=ordconstn) then
          begin
            if IsAbsPowerOf2(TOrdConstNode(right).Value,power) then
              begin
                { for signed numbers, the numerator must be adjusted before the
                  shift instruction, but not with unsigned numbers! Otherwise,
                  "Cardinal($ffffffff) div 16" overflows! (JM) }
                if Is_Signed(left.resultdef) Then
                  begin
                    invertsign:=TOrdConstNode(right).Value<0;
                    { use a sequence without jumps, saw this in
                      comp.compilers (JM) }
                    { no jumps, but more operations }
                    hreg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
                    emit_reg_reg(A_MOV,opsize,hreg1,hreg2);
                    if power=1 then
                      begin
                        {If the left value is negative, hreg2=(1 shl power)-1=1, otherwise 0.}
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SHR,cgsize,resultdef.Size*8-1,hreg2);
                      end
                    else
                      begin
                        {If the left value is negative, hreg2=$ffffffff, otherwise 0.}
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SAR,cgsize,resultdef.Size*8-1,hreg2);
                        {If negative, hreg2=(1 shl power)-1, otherwise 0.}
                        { (don't use emit_const_reg, because if value>high(longint)
                           then it must first be loaded into a register) }
                        cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_AND,cgsize,(aint(1) shl power)-1,hreg2);
                      end;
                    { add to the left value }
                    emit_reg_reg(A_ADD,opsize,hreg2,hreg1);
                    { do the shift }
                    cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SAR,cgsize,power,hreg1);
                    if invertsign then
                      emit_reg(A_NEG,opsize,hreg1);
                  end
                else
                  cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_SHR,cgsize,power,hreg1);
                location.Register:=hreg1;
              end
            else
              begin
                if Is_Signed(left.resultdef) then
                  begin
                    e:=TOrdConstNode(right).Value.svalue;
                    Calc_DivConst_Magic_Signed(resultdef.Size*8,e,sm,s);
                    cg.GetCPURegister(CurrentAsmData.CurrAsmList,rega);
                    emit_const_reg(A_MOV,opsize,sm,rega);
                    cg.GetCPURegister(CurrentAsmData.CurrAsmList,regd);
                    emit_reg(A_IMUL,opsize,hreg1);
                    { only the high half of result is used }
                    cg.UngetCPURegister(CurrentAsmData.CurrAsmList,rega);
                    { add or subtract dividend }
                    if (e>0) and (sm<0) then
                      emit_reg_reg(A_ADD,opsize,hreg1,regd)
                    else if (e<0) and (sm>0) then
                      emit_reg_reg(A_SUB,opsize,hreg1,regd);
                    { shift if necessary }
                    if (s<>0) then
                      emit_const_reg(A_SAR,opsize,s,regd);
                    { extract and add the sign bit }
                    if (e<0) then
                      emit_reg_reg(A_MOV,opsize,regd,hreg1);
                    { if e>=0, hreg1 still contains dividend }
                    emit_const_reg(A_SHR,opsize,left.resultdef.Size*8-1,hreg1);
                    emit_reg_reg(A_ADD,opsize,hreg1,regd);
                    cg.UngetCPURegister(CurrentAsmData.CurrAsmList,regd);
                    location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
                    cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,cgsize,cgsize,regd,location.Register)
                  end
                else
                  begin
                    d:=TOrdConstNode(right).Value.uvalue;
                    if d>=aword(1) shl (left.resultdef.Size*8-1) then
                      begin
                        location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
                        { Ensure that the whole register is 0, since SETcc only sets the lowest byte }

                        { If the operands are 64 bits, this XOR routine will be shrunk by the
                          peephole optimizer. [Kit] }
                        emit_reg_reg(A_XOR,opsize,location.Register,location.Register);

                        if (cgsize in [OS_64,OS_S64]) then { Cannot use 64-bit constants in CMP }
                          begin
                            hreg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
                            emit_const_reg(A_MOV,opsize,aint(d),hreg2);
                            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            emit_reg_reg(A_CMP,opsize,hreg2,hreg1);
                          end
                        else
                          begin
                            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            emit_const_reg(A_CMP,opsize,aint(d),hreg1);
                          end;
                        { NOTE: SBB and SETAE are both 3 bytes long without the REX prefix,
                          both use an ALU for their execution and take a single cycle to
                          run. The only difference is that SETAE does not modify the flags,
                          allowing for some possible reuse. [Kit] }

                        { Emit a SETcc instruction that depends on the carry bit being zero,
                          that is, the numerator is greater than or equal to the denominator. }
                        tempreg:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,location.Register,OS_8);
                        instr:=TAICPU.op_reg(A_SETcc,S_B,tempreg);
                        instr.condition:=C_AE;
                        CurrentAsmData.CurrAsmList.concat(instr);
                        cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                      end
                    else
                      DoUnsignedReciprocalDivision;

                  end;
              end;
          end
        else if (nodetype=modn) and (right.nodetype=ordconstn) and not(Is_Signed(left.resultdef)) then
          begin
            { unsigned modulus by a (+/-)power-of-2 constant? }
            if IsAbsPowerOf2(TOrdConstNode(right).Value,power) then
              begin
                emit_const_reg(A_AND,opsize,(aint(1) shl power)-1,hreg1);
                location.Register:=hreg1;
              end
            else
              begin
                d:=TOrdConstNode(right).Value.uvalue;
                if d>=aword(1) shl (left.resultdef.Size*8-1) then
                  begin

                    if not (CPUX86_HAS_CMOV in cpu_capabilities[CurrentSettings.CPUType]) then
                      goto DefaultDiv;

                    location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
                    hreg3:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);

                    m := aword(-aint(d)); { Two's complement of d }

                    if (cgsize in [OS_64,OS_S64]) then { Cannot use 64-bit constants in CMP }
                      begin
                        hreg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
                        emit_const_reg(A_MOV,opsize,aint(d),hreg2);
                        emit_const_reg(A_MOV,opsize,aint(m),hreg3);
                        emit_reg_reg(A_XOR,opsize,location.Register,location.Register);
                        cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                        emit_reg_reg(A_CMP,opsize,hreg2,hreg1);
                      end
                    else
                      begin
                        emit_const_reg(A_MOV,opsize,aint(m),hreg3);
                        emit_reg_reg(A_XOR,opsize,location.Register,location.Register);

                        cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                        emit_const_reg(A_CMP,opsize,aint(d),hreg1);
                      end;

                    { Emit conditional move that depends on the carry flag being zero,
                      that is, the comparison result is above or equal }
                    instr:=TAICPU.op_reg_reg(A_CMOVcc,opsize,hreg3,location.Register);
                    instr.condition := C_AE;
                    CurrentAsmData.CurrAsmList.concat(instr);
                    cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

                    emit_reg_reg(A_ADD,opsize,hreg1,location.Register);
                  end
                else
                  { Convert the division to a multiplication }
                  DoUnsignedReciprocalDivision;

              end;
          end
        else if (nodetype=modn) and (right.nodetype=ordconstn) and (Is_Signed(left.resultdef)) and IsAbsPowerOf2(TOrdConstNode(right).Value,power) then
          begin
            hreg2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
            if power=1 then
              cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHR,cgsize,resultdef.Size*8-power,hreg1,hreg2)
            else
              begin
                cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SAR,cgsize,resultdef.Size*8-1,hreg1,hreg2);
                cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_SHR,cgsize,resultdef.Size*8-power,hreg2,hreg2);
              end;
            emit_reg_reg(A_ADD,opsize,hreg1,hreg2);
            cg.A_Op_Const_Reg(CurrentAsmData.CurrAsmList,OP_AND,cgsize,not((aint(1) shl power)-1),hreg2);
            emit_reg_reg(A_SUB,opsize,hreg2,hreg1);
            location.Register:=hreg1;
          end
        else
          begin
DefaultDiv:
            {Bring denominator to a register.}
            cg.GetCPURegister(CurrentAsmData.CurrAsmList,rega);
            emit_reg_reg(A_MOV,opsize,hreg1,rega);
            cg.GetCPURegister(CurrentAsmData.CurrAsmList,regd);
            {Sign extension depends on the left type.}
            if Is_Signed(left.resultdef) then
              case left.resultdef.Size of
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
              emit_reg_reg(A_XOR,opsize,regd,regd);

            { Division depends on the result type }
            if Is_Signed(resultdef) then
              op:=A_IDIV
            else
              op:=A_DIV;

            if right.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
              emit_ref(op,opsize,right.Location.Reference)
            else if right.Location.Loc in [LOC_REGISTER,LOC_CREGISTER] then
              emit_reg(op,opsize,right.Location.Register)
            else
              begin
                hreg1:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,right.Location.Size);
                hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,right.resultdef,right.resultdef,right.Location,hreg1);
                emit_reg(op,opsize,hreg1);
              end;

            { Copy the result into a new register. Release R/EAX & R/EDX.}
            cg.UngetCPURegister(CurrentAsmData.CurrAsmList,regd);
            cg.UngetCPURegister(CurrentAsmData.CurrAsmList,rega);
            location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
            if nodetype=divn then
              cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,cgsize,cgsize,rega,location.Register)
            else
              cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,cgsize,cgsize,regd,location.Register);
          end;
      end;



end.
