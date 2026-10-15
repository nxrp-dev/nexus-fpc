{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate i386 assembler for math nodes

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
unit n386mat;

{$i fpcdefs.inc}

interface

    uses
      node,nmat,ncgmat,nx86mat;

    type
      TI386ModDivNode = class(TX86ModDivNode)
         procedure pass_generate_code;override;
      end;

      TI386ShlShrNode = class(TX86ShlShrNode)
         procedure second_64bit;override;
         function first_shlshr64bitint: TNode; override;
      end;

      TI386UnaryMinusNode = class(TX86UnaryMinusNode)
      end;

      TI386NotNode = class(TX86NotNode)
      end;


implementation

    uses
      GlobType,Systems,ConstExp,
      CUtils,Verbose,Globals,
      symconst,symdef,aasmbase,aasmtai,AAsmData,defutil,
      cgbase,pass_2,
      ncon,
      cpubase,CPUInfo,
      cga,ncgutil,cgobj,cgutils,
      hlcgobj;

{*****************************************************************************
                             TI386MODDIVNODE
*****************************************************************************}



   procedure TI386ModDivNode.pass_generate_code;
      var
        hreg1:TRegister;
        power:LongInt;
        hl:TAsmLabel;
      begin
        if is_64bitint(resultdef) then
          { should be handled in pass_1 (JM) }
          InternalError(2001090507);

        if (nodetype=divn) and (right.nodetype=ordconstn) and
          is_signed(left.resultdef) and
          IsPowerOf2(TOrdConstNode(right).value.svalue,power) and
          ((CurrentSettings.OptimizeCPUType = cpu_386) or
           (cs_opt_size in CurrentSettings.OptimizerSwitches)) then
          begin
            { signed divide-by-power-of-two optimized for size }
            SecondPass(left);
            if CodeGenError then
              exit;
            SecondPass(right);
            if CodeGenError then
              exit;
            hlcg.location_force_reg(CurrentAsmData.CurrAsmList,left.location,left.resultdef,resultdef,false);
            hreg1:=left.location.register;
            cg.a_reg_alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            emit_reg_reg(A_TEST,S_L,hreg1,hreg1);
            CurrentAsmData.getjumplabel(hl);
            cg.a_jmp_flags(CurrentAsmData.CurrAsmList,F_NS,hl);
            cg.a_reg_dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            if power=1 then
              emit_reg(A_INC,S_L,hreg1)
            else
              emit_const_reg(A_ADD,S_L,TOrdConstNode(right).value.svalue-1,hreg1);
            cg.a_label(CurrentAsmData.CurrAsmList,hl);
            emit_const_reg(A_SAR,S_L,power,hreg1);
            location_reset(location,LOC_REGISTER,def_cgsize(resultdef));
            location.register:=hreg1;
          end
        else
          inherited pass_generate_code;
      end;


{*****************************************************************************
                             TI386SHLRSHRNODE
*****************************************************************************}


    function TI386ShlShrNode.first_shlshr64bitint: TNode;
      begin
        result := nil;
      end;

    procedure TI386ShlShrNode.second_64bit;
      var
        hreg64hi,hreg64lo:TRegister;
        v : TConstExprInt;
        l2,l3:TAsmLabel;
      begin
        { shifting by a constant directly coded: }
        if (right.nodetype=ordconstn) then
          begin
            v:=TOrdConstNode(right).value and 63;

            { load left operator in a register }
            if not(left.location.loc in [LOC_REGISTER,LOC_CREGISTER]) or
              ((left.location.loc=LOC_CREGISTER) and ((v.svalue and 31)<>0)) then
              hlcg.location_force_reg(CurrentAsmData.CurrAsmList,left.location,left.resultdef,resultdef,false);
            hreg64hi:=left.location.register64.reghi;
            hreg64lo:=left.location.register64.reglo;

            location_reset(location,left.location.loc,def_cgsize(resultdef));
            if v>31 then
              begin
                if nodetype=shln then
                  begin
                    hreg64hi:=cg.getintregister(CurrentAsmData.CurrAsmList,OS_32);
                    emit_reg_reg(A_XOR,S_L,hreg64hi,hreg64hi);
                    if ((v and 31) <> 0) then
                      emit_const_reg(A_SHL,S_L,v.svalue and 31,hreg64lo);
                  end
                else
                  begin
                    hreg64lo:=cg.getintregister(CurrentAsmData.CurrAsmList,OS_32);
                    emit_reg_reg(A_XOR,S_L,hreg64lo,hreg64lo);
                    if ((v and 31) <> 0) then
                      emit_const_reg(A_SHR,S_L,v.svalue and 31,hreg64hi);
                  end;
                location.register64.reghi:=hreg64lo;
                location.register64.reglo:=hreg64hi;
              end
            else
              begin
                if (v.svalue and 31)<>0 then
                  begin
                    if nodetype=shln then
                      begin
                        emit_const_reg_reg(A_SHLD,S_L,v.svalue and 31,hreg64lo,hreg64hi);
                        emit_const_reg(A_SHL,S_L,v.svalue and 31,hreg64lo);
                      end
                    else
                      begin
                        emit_const_reg_reg(A_SHRD,S_L,v.svalue and 31,hreg64hi,hreg64lo);
                        emit_const_reg(A_SHR,S_L,v.svalue and 31,hreg64hi);
                      end;
                  end;
                location.register64.reglo:=hreg64lo;
                location.register64.reghi:=hreg64hi;
              end;
          end
        else
          begin
            location_reset(location,LOC_REGISTER,def_cgsize(resultdef));

            { load left operator in a register }
            hlcg.location_force_reg(CurrentAsmData.CurrAsmList,left.location,left.resultdef,resultdef,false);

            hreg64hi:=left.location.register64.reghi;
            hreg64lo:=left.location.register64.reglo;

            { load right operators in a register }
            cg.getcpuregister(CurrentAsmData.CurrAsmList,NR_ECX);
            hlcg.a_load_loc_reg(CurrentAsmData.CurrAsmList,right.resultdef,u32inttype,right.location,NR_ECX);

            { left operator is already in a register }
            { hence are both in a register }
            { is it in the case ECX ? }

            { the damned shift instructions work only til a count of 32 }
            { so we've to do some tricks here                           }
            CurrentAsmData.getjumplabel(l2);
            CurrentAsmData.getjumplabel(l3);
            cg.a_reg_alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            emit_const_reg(A_TEST,S_B,32,NR_CL);
            cg.a_jmp_flags(CurrentAsmData.CurrAsmList,F_E,l2);
            cg.a_reg_dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            if nodetype=shln then
              begin
                emit_reg_reg(A_SHL,S_L,NR_CL,hreg64lo);
                emit_reg_reg(A_MOV,S_L,hreg64lo,hreg64hi);
                emit_reg_reg(A_XOR,S_L,hreg64lo,hreg64lo);
                cg.a_jmp_always(CurrentAsmData.CurrAsmList,l3);
                cg.a_label(CurrentAsmData.CurrAsmList,l2);
                emit_reg_reg_reg(A_SHLD,S_L,NR_CL,hreg64lo,hreg64hi);
                emit_reg_reg(A_SHL,S_L,NR_CL,hreg64lo);
              end
            else
              begin
                emit_reg_reg(A_SHR,S_L,NR_CL,hreg64hi);
                emit_reg_reg(A_MOV,S_L,hreg64hi,hreg64lo);
                emit_reg_reg(A_XOR,S_L,hreg64hi,hreg64hi);
                cg.a_jmp_always(CurrentAsmData.CurrAsmList,l3);
                cg.a_label(CurrentAsmData.CurrAsmList,l2);
                emit_reg_reg_reg(A_SHRD,S_L,NR_CL,hreg64hi,hreg64lo);
                emit_reg_reg(A_SHR,S_L,NR_CL,hreg64hi);
              end;
            cg.a_label(CurrentAsmData.CurrAsmList,l3);

            cg.ungetcpuregister(CurrentAsmData.CurrAsmList,NR_ECX);
            location.register64.reglo:=hreg64lo;
            location.register64.reghi:=hreg64hi;
          end;
      end;


begin
   CUnaryMinusNode:=TI386UnaryMinusNode;
   CModDivNode:=TI386ModDivNode;
   CShlShrNode:=TI386ShlShrNode;
   CNotNode:=TI386NotNode;
end.
