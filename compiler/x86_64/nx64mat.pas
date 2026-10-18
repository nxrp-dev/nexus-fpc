{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate x86-64 assembler for math nodes

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
unit nx64mat;

{$i fpcdefs.inc}

interface

    uses
      node,nmat,nx86mat;

    type
      TX8664ShlShrNode = class(TX86ShlShrNode)
         procedure Pass_Generate_Code;override;
      end;

      TX8664UnaryMinusNode = class(TX86UnaryMinusNode)
      end;

      TX8664NotNode = class(TX86NotNode)
      end;

implementation

    uses
      GlobType,ConstExp,
      CUtils,
      AAsmData,defutil,
      pass_2,
      ncon,
      cgbase,cgutils,cgobj,hlcgobj;


{*****************************************************************************
                             TX8664SHLRSHRNODE
*****************************************************************************}


    procedure TX8664ShlShrNode.Pass_Generate_Code;
      var
        lOp : TOpCG;
        lOpSize : TCgSize;
        lMask : aint;
      begin
        SecondPass(Left);
        SecondPass(Right);

        { determine operator }
        if NodeType=shln then
          lOp:=OP_SHL
        else
          lOp:=OP_SHR;

        lOpSize:=Def_CGSize(ResultDef);
        lMask:=max(ResultDef.Size,4)*8-1;

        { load left operators in a register }
        if not(Left.Location.Loc in [LOC_CREGISTER,LOC_REGISTER]) or
          { location_force_reg can be also used to change the size of a register }
          (Left.Location.Size<>lOpSize) then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,CGSize_OrdDef(lOpSize),true);
        Location_Reset(Location,LOC_REGISTER,lOpSize);
        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);

        { shifting by a constant directly coded: }
        if (Right.NodeType=ordconstn) then
          cg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,lOp,Location.Size,
            TOrdConstNode(Right).Value.uvalue and lMask,Left.Location.Register,Location.Register)
        else
          begin
            { load right operators in a register - this
              is done since most target cpu which will use this
              node do not support a shift count in a mem. location (cec)
            }
            if not(Right.Location.Loc in [LOC_CREGISTER,LOC_REGISTER]) or
               { location_force_reg can be also used to change the size of a register }
              (Right.Location.Size<>lOpSize) then
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,CGSize_OrdDef(lOpSize),true);

            cg.A_Op_Reg_Reg_Reg(CurrentAsmData.CurrAsmList,lOp,lOpSize,Right.Location.Register,Left.Location.Register,Location.Register);
          end;
      end;


begin
   CUnaryMinusNode:=TX8664UnaryMinusNode;
   CModDivNode:=TX86ModDivNode;
   CShlShrNode:=TX8664ShlShrNode;
   CNotNode:=TX8664NotNode;
end.
