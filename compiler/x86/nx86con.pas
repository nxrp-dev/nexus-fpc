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
          function Pass_1 : TNode;override;
          procedure Pass_Generate_Code;override;
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

    function TX86RealConstNode.Pass_1 : TNode;
      begin
         Result:=nil;
         if Is_Number_Float(ValueReal) and not(Use_VectorFPU(ResultDef)) and ((ValueReal=1.0) or (ValueReal=-1.0) or ((ValueReal=0.0) and (Get_Real_Sign(ValueReal)=1)) or
           ((ValueReal=2.0) and (cs_create_pic in CurrentSettings.ModuleSwitches))) then
           expectloc:=LOC_FPUREGISTER
         else if (ValueReal=0.0) and (Get_Real_Sign(ValueReal)=1) and Use_VectorFPU(ResultDef) then
           expectloc:=LOC_MMREGISTER
         else
           expectloc:=LOC_CREFERENCE;
      end;


    procedure TX86RealConstNode.Pass_Generate_Code;
      begin
         if Is_Number_Float(ValueReal) then
           begin
             if (ValueReal=1.0) and not(Use_VectorFPU(ResultDef)) then
               begin
                  emit_none(A_FLD1,S_NO);
                  Location_Reset(Location,LOC_FPUREGISTER,Def_CGSize(ResultDef));
                  Location.Register:=NR_ST;
                  TCGX86(cg).inc_fpu_stack;
               end
             else if (ValueReal=2.0) and (cs_create_pic in CurrentSettings.ModuleSwitches) and not(Use_VectorFPU(ResultDef)) then
               begin
                  emit_none(A_FLD1,S_NO);
                  emit_reg_reg(A_FADD,S_NO,NR_ST,NR_ST);
                  Location_Reset(Location,LOC_FPUREGISTER,Def_CGSize(ResultDef));
                  Location.Register:=NR_ST;
                  TCGX86(cg).inc_fpu_stack;
               end
             else if (ValueReal=-1.0) and not(Use_VectorFPU(ResultDef)) then
               begin
                  emit_none(A_FLD1,S_NO);
                  emit_none(A_FCHS,S_NO);
                  Location_Reset(Location,LOC_FPUREGISTER,Def_CGSize(ResultDef));
                  Location.Register:=NR_ST;
                  TCGX86(cg).inc_fpu_stack;
               end
             else if (ValueReal=0.0) and (Get_Real_Sign(ValueReal)=1) then
               begin
                 if Use_VectorFPU(ResultDef) then
                   begin
                     Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
                     Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Def_CGSize(ResultDef));
                     if UseAVX then
                       begin
                         if Is_Single(ResultDef) then
                           emit_reg_reg_reg(A_VXORPS,S_NO,Location.Register,Location.Register,Location.Register)
                         else
                           emit_reg_reg_reg(A_VXORPD,S_NO,Location.Register,Location.Register,Location.Register);
                       end
                     else
                       begin
                         if Is_Single(ResultDef) then
                           emit_reg_reg(A_XORPS,S_NO,Location.Register,Location.Register)
                         else
                           emit_reg_reg(A_XORPD,S_NO,Location.Register,Location.Register);
                       end
                   end
                 else
                   begin
                      emit_none(A_FLDZ,S_NO);
                      if (Get_Real_Sign(ValueReal) < 0) then
                        emit_none(A_FCHS,S_NO);
                      Location_Reset(Location,LOC_FPUREGISTER,Def_CGSize(ResultDef));
                      Location.Register:=NR_ST;
                      TCGX86(cg).inc_fpu_stack;
                   end;
               end
            else
              inherited Pass_Generate_Code;
           end
         else
           inherited Pass_Generate_Code;
      end;


begin
   CRealConstNode:=TX86RealConstNode;
end.
