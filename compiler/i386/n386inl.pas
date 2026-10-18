{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate i386 inline nodes

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
unit n386inl;

{$i fpcdefs.inc}

interface

    uses
       node,nx86inl;

    type
       TI386InlineNode = class(TX86InlineNode)
       public
         function First_SAR: TNode; override;
         procedure Second_ROX_SAR; override;
       end;

implementation

  uses
    GlobType,Globals,compinnr,
    defutil,
    aasmbase,AAsmData,
    cgbase,pass_2,
    CPUInfo,cpubase,
    cga,cgutils,cgx86,cgobj,hlcgobj,
    ninl,ncon,ncal;


  function TI386InlineNode.First_SAR: TNode;
    begin
      if Is_64BitInt(ResultDef) and (
        (InlineNumber=in_sar_x) or (
          (InlineNumber=in_sar_x_y) and
          (TCallParaNode(Left).Left.NodeType=ordconstn)
      )) then
        begin
          Result:=nil;
          ExpectLoc:=LOC_REGISTER;
        end
      else
        Result:=inherited First_SAR;
    end;


  procedure TI386InlineNode.Second_ROX_SAR;
    var
      lOperand1: TNode;
      lReg64Hi,lReg64Lo: TRegister;
      lValue: AInt;
    begin
      if Is_64BitInt(ResultDef) and (
        (InlineNumber=in_sar_x) or (
          (InlineNumber=in_sar_x_y) and
          (TCallParaNode(Left).Left.NodeType=ordconstn)
      )) then
        begin
          { x sar constant }
          if (Left.NodeType=callparan) and
             Assigned(TCallParaNode(Left).Right) then
            begin
              lOperand1:=TCallParaNode(TCallParaNode(Left).Right).Left;
              SecondPass(TCallParaNode(Left).Left);
              lValue:=TOrdConstNode(TCallParaNode(Left).Left).Value.svalue and 63;
            end
          else
            begin
              lOperand1:=Left;
              lValue:=1;
            end;
          SecondPass(lOperand1);

          Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));

          { load left operator in a register }
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lOperand1.Location,lOperand1.ResultDef,ResultDef,false);
          lReg64Hi:=lOperand1.Location.Register64.RegHi;
          lReg64Lo:=lOperand1.Location.Register64.RegLo;

          if (lValue=63) then
            begin
              emit_const_reg(A_SAR,S_L,31,lReg64Hi);
              cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,lReg64Hi,lReg64Lo);
            end
          else if (lValue>31) then
            begin
              cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_32,OS_32,lReg64Hi,lReg64Lo);
              emit_const_reg(A_SAR,S_L,31,lReg64Hi);
              emit_const_reg(A_SAR,S_L,lValue and 31,lReg64Lo);
            end
          else
            begin
              emit_const_reg_reg(A_SHRD,S_L,lValue and 31,lReg64Hi,lReg64Lo);
              emit_const_reg(A_SAR,S_L,lValue and 31,lReg64Hi);
            end;
          Location.Register64.RegHi:=lReg64Hi;
          Location.Register64.RegLo:=lReg64Lo;
        end
      else
        inherited Second_ROX_SAR;
    end;

begin
   CInlineNode:=TI386InlineNode;
end.
