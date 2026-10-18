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
         function Use_Generic_Mul64Bit: Boolean; override;
         procedure Second_AddOrdinal; override;
         procedure Second_Mul;
       end;

  implementation

    uses
      GlobType,Globals,Verbose,
      aasmbase,AAsmData,
      defutil,
      cgbase,cgutils,cga,cgobj,hlcgobj,cgx86,
      tgobj;

    function TX8664AddNode.Use_Generic_Mul64Bit: Boolean;
    begin
      Result:=false;
    end;

{*****************************************************************************
                                Addordinal
*****************************************************************************}

    procedure TX8664AddNode.Second_AddOrdinal;
    begin
      { filter unsigned MUL opcode, which requires special handling.
        Note that when overflow checking is off, we can use IMUL instead. }
      if (NodeType=muln) and
        NeedOverflowCheck and
        (not(Is_Signed(Left.ResultDef)) or
         not(Is_Signed(Right.ResultDef))) then
      begin
        Second_Mul;
        exit;
      end;

      inherited Second_AddOrdinal;
    end;

{*****************************************************************************
                                MUL
*****************************************************************************}

    procedure TX8664AddNode.Second_Mul;
      var
        lRegister,lAccumulatorReg,lDataReg:TRegister;
        lReference:TReference;
        lUseReference:Boolean;
        lOverflowLabel : TAsmLabel;
        lCGSize:TCgSize;
        lOpSize:TOpSize;
      begin
        Reference_Reset(lReference,0,[]);
        lRegister:=NR_NO;

        lCGSize:=Def_CGSize(ResultDef);
        lOpSize:=TCGSize2OpSize[lCGSize];
        case lCGSize of
          OS_S64,OS_64:
            begin
              lAccumulatorReg:=NR_RAX;
              lDataReg:=NR_RDX;
            end;
          OS_S32,OS_32:
            begin
              lAccumulatorReg:=NR_EAX;
              lDataReg:=NR_EDX;
            end;
          else
            InternalError(2013102703);
        end;

        Pass_Left_Right;

        { The location.register will be filled in later (JM) }
        Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
        { Mul supports registers and references, so if not register/reference,
          load the location into a register}
        lUseReference:=false;
        if Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER] then
          lRegister:=Left.Location.Register
        else if Left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
          begin
            lReference:=Left.Location.Reference;
            lUseReference:=true;
          end
        else
          begin
            {LOC_CONSTANT for example.}
            lRegister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
            hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,ResultDef,Left.Location,lRegister);
          end;
        { Allocate RAX. }
        cg.GetCPURegister(CurrentAsmData.CurrAsmList,lAccumulatorReg);
        { Load the right value. }
        hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Right.ResultDef,ResultDef,Right.Location,lAccumulatorReg);
        { Also allocate RDX, since it is also modified by a mul (JM). }
        cg.GetCPURegister(CurrentAsmData.CurrAsmList,lDataReg);

        if NeedOverflowCheck then
          cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

        if lUseReference then
          emit_ref(A_MUL,lOpSize,lReference)
        else
          emit_reg(A_MUL,lOpSize,lRegister);
        if NeedOverflowCheck then
         begin
           CurrentAsmData.getjumplabel(lOverflowLabel);
           cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_AE,lOverflowLabel);
           cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
           cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
           cg.A_Label(CurrentAsmData.CurrAsmList,lOverflowLabel);
         end;
        { Free RDX,RAX }
        cg.UngetCPURegister(CurrentAsmData.CurrAsmList,lDataReg);
        cg.UngetCPURegister(CurrentAsmData.CurrAsmList,lAccumulatorReg);
        { Allocate a new register and store the result in RAX in it. }
        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lCGSize);
        emit_reg_reg(A_MOV,lOpSize,lAccumulatorReg,Location.Register);
        Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
        Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
      end;


begin
   CAddNode:=TX8664AddNode;
end.
