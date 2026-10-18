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
         procedure Pass_Generate_Code;override;
      end;

      TI386ShlShrNode = class(TX86ShlShrNode)
         procedure Second_64Bit;override;
         function First_ShlShr64BitInt: TNode; override;
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



   procedure TI386ModDivNode.Pass_Generate_Code;
      var
        lReg1:TRegister;
        lPower:LongInt;
        lLabel:TAsmLabel;
      begin
        if Is_64BitInt(ResultDef) then
          { should be handled in pass_1 (JM) }
          InternalError(2001090507);

        if (NodeType=divn) and (Right.NodeType=ordconstn) and
          Is_Signed(Left.ResultDef) and
          IsPowerOf2(TOrdConstNode(Right).Value.svalue,lPower) and
          ((CurrentSettings.OptimizeCPUType = cpu_386) or
           (cs_opt_size in CurrentSettings.OptimizerSwitches)) then
          begin
            { signed divide-by-power-of-two optimized for size }
            SecondPass(Left);
            if CodeGenError then
              exit;
            SecondPass(Right);
            if CodeGenError then
              exit;
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,ResultDef,false);
            lReg1:=Left.Location.Register;
            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            emit_reg_reg(A_TEST,S_L,lReg1,lReg1);
            CurrentAsmData.getjumplabel(lLabel);
            cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NS,lLabel);
            cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            if lPower=1 then
              emit_reg(A_INC,S_L,lReg1)
            else
              emit_const_reg(A_ADD,S_L,TOrdConstNode(Right).Value.svalue-1,lReg1);
            cg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
            emit_const_reg(A_SAR,S_L,lPower,lReg1);
            Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
            Location.Register:=lReg1;
          end
        else
          inherited Pass_Generate_Code;
      end;


{*****************************************************************************
                             TI386SHLRSHRNODE
*****************************************************************************}


    function TI386ShlShrNode.First_ShlShr64BitInt: TNode;
      begin
        Result := nil;
      end;

    procedure TI386ShlShrNode.Second_64Bit;
      var
        lReg64Hi,lReg64Lo:TRegister;
        lValue : TConstExprInt;
        lLabel2,lLabel3:TAsmLabel;
      begin
        { shifting by a constant directly coded: }
        if (Right.NodeType=ordconstn) then
          begin
            lValue:=TOrdConstNode(Right).Value and 63;

            { load left operator in a register }
            if not(Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) or
              ((Left.Location.Loc=LOC_CREGISTER) and ((lValue.svalue and 31)<>0)) then
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,ResultDef,false);
            lReg64Hi:=Left.Location.Register64.RegHi;
            lReg64Lo:=Left.Location.Register64.RegLo;

            Location_Reset(Location,Left.Location.Loc,Def_CGSize(ResultDef));
            if lValue>31 then
              begin
                if NodeType=shln then
                  begin
                    lReg64Hi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                    emit_reg_reg(A_XOR,S_L,lReg64Hi,lReg64Hi);
                    if ((lValue and 31) <> 0) then
                      emit_const_reg(A_SHL,S_L,lValue.svalue and 31,lReg64Lo);
                  end
                else
                  begin
                    lReg64Lo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                    emit_reg_reg(A_XOR,S_L,lReg64Lo,lReg64Lo);
                    if ((lValue and 31) <> 0) then
                      emit_const_reg(A_SHR,S_L,lValue.svalue and 31,lReg64Hi);
                  end;
                Location.Register64.RegHi:=lReg64Lo;
                Location.Register64.RegLo:=lReg64Hi;
              end
            else
              begin
                if (lValue.svalue and 31)<>0 then
                  begin
                    if NodeType=shln then
                      begin
                        emit_const_reg_reg(A_SHLD,S_L,lValue.svalue and 31,lReg64Lo,lReg64Hi);
                        emit_const_reg(A_SHL,S_L,lValue.svalue and 31,lReg64Lo);
                      end
                    else
                      begin
                        emit_const_reg_reg(A_SHRD,S_L,lValue.svalue and 31,lReg64Hi,lReg64Lo);
                        emit_const_reg(A_SHR,S_L,lValue.svalue and 31,lReg64Hi);
                      end;
                  end;
                Location.Register64.RegLo:=lReg64Lo;
                Location.Register64.RegHi:=lReg64Hi;
              end;
          end
        else
          begin
            Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));

            { load left operator in a register }
            hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,ResultDef,false);

            lReg64Hi:=Left.Location.Register64.RegHi;
            lReg64Lo:=Left.Location.Register64.RegLo;

            { load right operators in a register }
            cg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_ECX);
            hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Right.ResultDef,U32IntType,Right.Location,NR_ECX);

            { left operator is already in a register }
            { hence are both in a register }
            { is it in the case ECX ? }

            { the damned shift instructions work only til a count of 32 }
            { so we've to do some tricks here                           }
            CurrentAsmData.getjumplabel(lLabel2);
            CurrentAsmData.getjumplabel(lLabel3);
            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            emit_const_reg(A_TEST,S_B,32,NR_CL);
            cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_E,lLabel2);
            cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            if NodeType=shln then
              begin
                emit_reg_reg(A_SHL,S_L,NR_CL,lReg64Lo);
                emit_reg_reg(A_MOV,S_L,lReg64Lo,lReg64Hi);
                emit_reg_reg(A_XOR,S_L,lReg64Lo,lReg64Lo);
                cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel3);
                cg.A_Label(CurrentAsmData.CurrAsmList,lLabel2);
                emit_reg_reg_reg(A_SHLD,S_L,NR_CL,lReg64Lo,lReg64Hi);
                emit_reg_reg(A_SHL,S_L,NR_CL,lReg64Lo);
              end
            else
              begin
                emit_reg_reg(A_SHR,S_L,NR_CL,lReg64Hi);
                emit_reg_reg(A_MOV,S_L,lReg64Hi,lReg64Lo);
                emit_reg_reg(A_XOR,S_L,lReg64Hi,lReg64Hi);
                cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel3);
                cg.A_Label(CurrentAsmData.CurrAsmList,lLabel2);
                emit_reg_reg_reg(A_SHRD,S_L,NR_CL,lReg64Hi,lReg64Lo);
                emit_reg_reg(A_SHR,S_L,NR_CL,lReg64Hi);
              end;
            cg.A_Label(CurrentAsmData.CurrAsmList,lLabel3);

            cg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_ECX);
            Location.Register64.RegLo:=lReg64Lo;
            Location.Register64.RegHi:=lReg64Hi;
          end;
      end;


begin
   CUnaryMinusNode:=TI386UnaryMinusNode;
   CModDivNode:=TI386ModDivNode;
   CShlShrNode:=TI386ShlShrNode;
   CNotNode:=TI386NotNode;
end.
