{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Code generation for add nodes on the x86-64

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
unit nx64add;

{$i fpcdefs.inc}

interface

    uses
       node,nadd,cpubase,nx86add;

    type
       TX8664AddNode = class(TX86AddNode)
         function use_generic_mul64bit: boolean; override;
         procedure second_addordinal; override;
         procedure second_mul;
       end;

  implementation

    uses
      GlobType,Globals,Verbose,
      aasmbase,AAsmData,
      defutil,
      cgbase,cgutils,cga,cgobj,hlcgobj,cgx86,
      tgobj;

    function TX8664AddNode.use_generic_mul64bit: boolean;
    begin
      result:=false;
    end;

{*****************************************************************************
                                Addordinal
*****************************************************************************}

    procedure TX8664AddNode.second_addordinal;
    begin
      { filter unsigned MUL opcode, which requires special handling.
        Note that when overflow checking is off, we can use IMUL instead. }
      if (nodetype=muln) and
        needoverflowcheck and
        (not(Is_Signed(left.resultdef)) or
         not(Is_Signed(right.resultdef))) then
      begin
        second_mul;
        exit;
      end;

      inherited second_addordinal;
    end;

{*****************************************************************************
                                MUL
*****************************************************************************}

    procedure TX8664AddNode.second_mul;
      var
        reg,rega,regd:TRegister;
        ref:TReference;
        use_ref:boolean;
        hl4 : TAsmLabel;
        cgsize:TCgSize;
        opsize:TOpSize;
      begin
        Reference_Reset(ref,0,[]);
        reg:=NR_NO;

        cgsize:=Def_CGSize(resultdef);
        opsize:=TCGSize2OpSize[cgsize];
        case cgsize of
          OS_S64,OS_64:
            begin
              rega:=NR_RAX;
              regd:=NR_RDX;
            end;
          OS_S32,OS_32:
            begin
              rega:=NR_EAX;
              regd:=NR_EDX;
            end;
          else
            InternalError(2013102703);
        end;

        pass_left_right;

        { The location.register will be filled in later (JM) }
        Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
        { Mul supports registers and references, so if not register/reference,
          load the location into a register}
        use_ref:=false;
        if left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER] then
          reg:=left.Location.Register
        else if left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
          begin
            ref:=left.Location.Reference;
            use_ref:=true;
          end
        else
          begin
            {LOC_CONSTANT for example.}
            reg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
            hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,left.resultdef,resultdef,left.Location,reg);
          end;
        { Allocate RAX. }
        cg.GetCPURegister(CurrentAsmData.CurrAsmList,rega);
        { Load the right value. }
        hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,right.resultdef,resultdef,right.Location,rega);
        { Also allocate RDX, since it is also modified by a mul (JM). }
        cg.GetCPURegister(CurrentAsmData.CurrAsmList,regd);

        if needoverflowcheck then
          cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

        if use_ref then
          emit_ref(A_MUL,opsize,ref)
        else
          emit_reg(A_MUL,opsize,reg);
        if needoverflowcheck then
         begin
           CurrentAsmData.getjumplabel(hl4);
           cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_AE,hl4);
           cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
           cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
           cg.A_Label(CurrentAsmData.CurrAsmList,hl4);
         end;
        { Free RDX,RAX }
        cg.UngetCPURegister(CurrentAsmData.CurrAsmList,regd);
        cg.UngetCPURegister(CurrentAsmData.CurrAsmList,rega);
        { Allocate a new register and store the result in RAX in it. }
        location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,cgsize);
        emit_reg_reg(A_MOV,opsize,rega,location.Register);
        location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
        location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
      end;


begin
   CAddNode:=TX8664AddNode;
end.
