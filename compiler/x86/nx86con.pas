{
    Copyright (c) 1998-2012 by Florian Klaempfl and others

    Generate i386 assembler for constants

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
unit nx86con;

{$i fpcdefs.inc}

interface

    uses
       TPCompilerReal,
       node,ncon,ncgcon;

    type
       TX86RealConstNode = class(TCGRealConstNode)
          function pass_1 : TNode;override;
          procedure pass_generate_code;override;
       end;

implementation

    uses
      Systems,Globals,GlobType,
      symdef,
      defutil,
      cpubase,
      AAsmData,
      cga,cgx86,cgobj,cgbase,cgutils;

{*****************************************************************************
                           TX86REALCONSTNODE
*****************************************************************************}

    function TX86RealConstNode.pass_1 : TNode;
      begin
         result:=nil;
         if Is_Number_Float(value_real) and not(Use_VectorFPU(resultdef)) and ((value_real=1.0) or (value_real=-1.0) or ((value_real=0.0) and (Get_Real_Sign(value_real)=1)) or
           ((value_real=2.0) and (cs_create_pic in CurrentSettings.ModuleSwitches))) then
           expectloc:=LOC_FPUREGISTER
         else if (value_real=0.0) and (Get_Real_Sign(value_real)=1) and Use_VectorFPU(resultdef) then
           expectloc:=LOC_MMREGISTER
         else
           expectloc:=LOC_CREFERENCE;
      end;


    procedure TX86RealConstNode.pass_generate_code;
      begin
         if Is_Number_Float(value_real) then
           begin
             if (value_real=1.0) and not(Use_VectorFPU(resultdef)) then
               begin
                  emit_none(A_FLD1,S_NO);
                  location_reset(location,LOC_FPUREGISTER,def_cgsize(resultdef));
                  location.register:=NR_ST;
                  TCGX86(cg).inc_fpu_stack;
               end
             else if (value_real=2.0) and (cs_create_pic in CurrentSettings.ModuleSwitches) and not(Use_VectorFPU(resultdef)) then
               begin
                  emit_none(A_FLD1,S_NO);
                  emit_reg_reg(A_FADD,S_NO,NR_ST,NR_ST);
                  location_reset(location,LOC_FPUREGISTER,def_cgsize(resultdef));
                  location.register:=NR_ST;
                  TCGX86(cg).inc_fpu_stack;
               end
             else if (value_real=-1.0) and not(Use_VectorFPU(resultdef)) then
               begin
                  emit_none(A_FLD1,S_NO);
                  emit_none(A_FCHS,S_NO);
                  location_reset(location,LOC_FPUREGISTER,def_cgsize(resultdef));
                  location.register:=NR_ST;
                  TCGX86(cg).inc_fpu_stack;
               end
             else if (value_real=0.0) and (Get_Real_Sign(value_real)=1) then
               begin
                 if Use_VectorFPU(resultdef) then
                   begin
                     location_reset(location,LOC_MMREGISTER,def_cgsize(resultdef));
                     location.register:=cg.getmmregister(CurrentAsmData.CurrAsmList,def_cgsize(resultdef));
                     if UseAVX then
                       begin
                         if is_single(resultdef) then
                           emit_reg_reg_reg(A_VXORPS,S_NO,location.register,location.register,location.register)
                         else
                           emit_reg_reg_reg(A_VXORPD,S_NO,location.register,location.register,location.register);
                       end
                     else
                       begin
                         if is_single(resultdef) then
                           emit_reg_reg(A_XORPS,S_NO,location.register,location.register)
                         else
                           emit_reg_reg(A_XORPD,S_NO,location.register,location.register);
                       end
                   end
                 else
                   begin
                      emit_none(A_FLDZ,S_NO);
                      if (Get_Real_Sign(value_real) < 0) then
                        emit_none(A_FCHS,S_NO);
                      location_reset(location,LOC_FPUREGISTER,def_cgsize(resultdef));
                      location.register:=NR_ST;
                      TCGX86(cg).inc_fpu_stack;
                   end;
               end
            else
              inherited pass_generate_code;
           end
         else
           inherited pass_generate_code;
      end;


begin
   CRealConstNode:=TX86RealConstNode;
end.
