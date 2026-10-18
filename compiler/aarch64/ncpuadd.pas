{
    Copyright (c) 2014 Jonas Maebe

    Code generation for add nodes on AArch64

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
unit ncpuadd;

{$i fpcdefs.inc}

interface

    uses
       node,ncgadd,cpubase;

    type
       TAArch64AddNode = class(TCGAddNode)
       private
          function  GetResFlags(AUnsigned:Boolean):TResFlags;
          function  GetFPUResFlags:TResFlags;
       protected
          function Try_Second_Bit_Test: Boolean;

          function Use_FMA : Boolean;override;
          procedure Second_AddFloat;override;
          procedure Second_CmpFloat;override;
          procedure Second_CmpBoolean;override;
          procedure Second_CmpSmallSet;override;
          procedure Second_CmpOrdinal;override;
          procedure Second_AddOrdinal;override;
          procedure Second_Add64Bit; override;
          procedure Second_Cmp64Bit; override;
       public
          function Use_Generic_Mul32To64: Boolean; override;
          function Pass_1 : TNode;override;
       end;

  implementation

    uses
      Systems,symconst,symtype,symdef,
      Globals,GlobType,
      CUtils,Verbose,
      paramgr,ProcInfo,
      aasmtai,AAsmData,aasmcpu,defutil,
      cgbase,cgcpu,cgutils,
      cpupara,
      ncon,nset,nadd,nmat,
      hlcgobj, ncgutil,cgobj,pass_2;

{*****************************************************************************
                               taarch64addnode
*****************************************************************************}

    function TAArch64AddNode.Use_FMA : Boolean;
      begin
        Result:=true;
      end;


    function TAArch64AddNode.GetResFlags(AUnsigned:Boolean):TResFlags;
      begin
        case NodeType of
          EqualN:
            GetResFlags:=F_EQ;
          unequaln:
            GetResFlags:=F_NE;
          else
            if not(AUnsigned) then
              begin
                if nf_swapped in Flags then
                  case NodeType of
                    ltn:
                      GetResFlags:=F_GT;
                    lten:
                      GetResFlags:=F_GE;
                    gtn:
                      GetResFlags:=F_LT;
                    gten:
                      GetResFlags:=F_LE;
                    else
                      InternalError(2014082010);
                  end
                else
                  case NodeType of
                    ltn:
                      GetResFlags:=F_LT;
                    lten:
                      GetResFlags:=F_LE;
                    gtn:
                      GetResFlags:=F_GT;
                    gten:
                      GetResFlags:=F_GE;
                    else
                      InternalError(2014082011);
                  end;
              end
            else
              begin
                if nf_swapped in Flags then
                  case NodeType of
                    ltn:
                      GetResFlags:=F_HI;
                    lten:
                      GetResFlags:=F_HS;
                    gtn:
                      GetResFlags:=F_LO;
                    gten:
                      GetResFlags:=F_LS;
                    else
                      InternalError(2014082012);
                  end
                else
                  case NodeType of
                    ltn:
                      GetResFlags:=F_LO;
                    lten:
                      GetResFlags:=F_LS;
                    gtn:
                      GetResFlags:=F_HI;
                    gten:
                      GetResFlags:=F_HS;
                    else
                      InternalError(2014082013);
                  end;
              end;
        end;
      end;


    function TAArch64AddNode.GetFPUResFlags:TResFlags;
      begin
        case NodeType of
          EqualN:
            Result:=F_EQ;
          unequaln:
            Result:=F_NE;
          else
            begin
              if nf_swapped in Flags then
                case NodeType of
                  ltn:
                    Result:=F_GT;
                  lten:
                    Result:=F_GE;
                  gtn:
                    Result:=F_LO;
                  gten:
                    Result:=F_LS;
                  else
                    InternalError(2014082014);
                end
              else
                case NodeType of
                  ltn:
                    Result:=F_LO;
                  lten:
                    Result:=F_LS;
                  gtn:
                    Result:=F_GT;
                  gten:
                    Result:=F_GE;
                  else
                    InternalError(2014082015);
                end;
            end;
        end;
      end;


    procedure TAArch64AddNode.Second_AddFloat;
      var
        lAsmOp : TAsmOp;
      begin
        Pass_Left_Right;
        if nf_swapped in Flags then
          SwapLeftRight;

        { force fpureg as location, left right doesn't matter
          as both will be in a fpureg }
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,true);

        Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
        Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);

        case NodeType of
          addn :
            begin
              lAsmOp:=A_FADD;
            end;
          muln :
            begin
              lAsmOp:=A_FMUL;
            end;
          subn :
            begin
              lAsmOp:=A_FSUB;
            end;
          slashn :
            begin
              lAsmOp:=A_FDIV;
            end;
          else
            InternalError(200306014);
        end;

        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(lAsmOp,
           Location.Register,Left.Location.Register,Right.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64AddNode.Second_CmpFloat;
      begin
        Pass_Left_Right;
        if nf_swapped in Flags then
          SwapLeftRight;

        { force fpureg as location, left right doesn't matter
          as both will be in a fpureg }
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,true);

        Location_Reset(Location,LOC_FLAGS,OS_NO);
        Location.ResFlags:=GetFPUResFlags;

        { signalling compare so we can get exceptions }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCMPE,
             Left.Location.Register,Right.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64AddNode.Second_CmpBoolean;
      begin
        Pass_Left_Right;
        Force_Reg_Left_Right(true,true);

        if Right.Location.Loc=LOC_CONSTANT then
          begin
            if Right.Location.Value>=0 then
              TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,A_CMP,Left.Location.Size,Left.Location.Register,Right.Location.Value,NR_XZR,NR_NO,false,false)
            else
              { avoid overflow if value=low(int64) }
{$push}{$r-}{$q-}
              TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,A_CMN,Left.Location.Size,Left.Location.Register,-Right.Location.Value,NR_XZR,NR_NO,false,false)
{$pop}
          end
        else
          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,Left.Location.Register,Right.Location.Register));

        Location_Reset(Location,LOC_FLAGS,OS_NO);
        Location.ResFlags:=GetResFlags(true);
      end;


    procedure TAArch64AddNode.Second_CmpSmallSet;
      var
        lTempReg : TRegister;
        lAsmOp: TAsmOp;
      begin
        Pass_Left_Right;

        Location_Reset(Location,LOC_FLAGS,OS_NO);

        Force_Reg_Left_Right(true,true);

        if Right.Location.Loc=LOC_CONSTANT then
          begin
            { when doing a cmp/cmn on 32 bit, we care whether the *lower 32 bit*
              is a positive/negative value -> sign extend }
            if not(Right.Location.Size in [OS_64,OS_S64]) then
              Right.Location.Value:=LongInt(Right.Location.Value);
            if Right.Location.Value>=0 then
              lAsmOp:=A_CMP
            else
              lAsmOp:=A_CMN;
          end
        else
          { for DFA }
          lAsmOp:=A_NONE;

        case NodeType of
          EqualN,
          unequaln:
            begin
              if Right.Location.Loc=LOC_CONSTANT then
                TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,lAsmOp,Def_CGSize(ResultDef),Left.Location.Register,abs(Right.Location.Value),NR_XZR,NR_NO,false,false)
              else
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,Left.Location.Register,Right.Location.Register));
              Location.ResFlags:=GetResFlags(true);
            end;
          lten,
          gten:
            begin
              if (not(nf_swapped in Flags) and
                  (NodeType=lten)) or
                 ((nf_swapped in Flags) and
                  (NodeType=gten)) then
                SwapLeftRight;
              { we can't handle left as a constant yet }
              if Left.Location.Loc=LOC_CONSTANT then
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
              lTempReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Left.Location.Size);
              if Right.Location.Loc=LOC_CONSTANT then
                begin
                  hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_AND,ResultDef,Right.Location.Value,Left.Location.Register,lTempReg);
                  TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,lAsmOp,Def_CGSize(ResultDef),lTempReg,abs(Right.Location.Value),NR_XZR,NR_NO,false,false)
                end
              else
                begin
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_AND,lTempReg,Left.Location.Register,Right.Location.Register));
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,lTempReg,Right.Location.Register));
                end;
              Location.ResFlags:=F_EQ;
            end;
          else
            InternalError(2012042701);
        end;
      end;


    function TAArch64AddNode.Try_Second_Bit_Test: Boolean;

      function TryArrangement(ACompareValue: TOrdConstNode; AAndNode: TAddNode): Boolean;
        var
          lResFlags: TResFlags;
          lAndConstNode: TOrdConstNode;
          lInputNode: TNode;
        begin
          Result:=False;
          if AAndNode.Right.NodeType=ordconstn then
            begin
              lAndConstNode:=TOrdConstNode(AAndNode.Right);
              lInputNode:=AAndNode.Left;
            end
          else if AAndNode.Left.NodeType=ordconstn then
            begin
              lAndConstNode:=TOrdConstNode(AAndNode.Left);
              lInputNode:=AAndNode.Right;
            end
          else
            Exit;

          { An earlier node optimisation turns (x and const) = x into (x and const) <> 0
            if PopCnt(const) = 1, so don't bother checking anything other than 0 }
          if (ACompareValue.Value.svalue<>0) or (NodeType in [gten,ltn]) or
            { If the condition is <= or >, the optimisation can still work as
              long as the bit in question isn't the sign bit }
            (
              (NodeType in [gtn,lten]) and
              (
                ((lInputNode.Location.Size=OS_S64) and (lAndConstNode.Value.svalue=$8000000000000000)) or
                (not (lInputNode.Location.Size in [OS_64,OS_S64,OS_32]) and (LongWord(lAndConstNode.Value.uvalue)=$80000000))
              )
            )
            then
            Exit;

          { Skip processing the constant and and nodes }
          Include(ACompareValue.TransientFlags,tnf_do_not_execute);
          Include(AAndNode.TransientFlags,tnf_do_not_execute);

          SecondPass(lInputNode);

          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lInputNode.Location,lInputNode.ResultDef,lInputNode.ResultDef,true);

          if not is_shifter_const(lAndConstNode.Value.svalue, lInputNode.Location.Size) then
            begin
              SecondPass(lAndConstNode);
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lAndConstNode.Location,lAndConstNode.ResultDef,lAndConstNode.ResultDef,false);
              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_TST,lInputNode.Location.Register,lAndConstNode.Location.Register));
            end
          else
            begin
              Include(lAndConstNode.TransientFlags,tnf_do_not_execute);
              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_TST,lInputNode.Location.Register,lAndConstNode.Value.svalue));
            end;

          Location_Reset(Location,LOC_FLAGS,OS_NO);
          if (NodeType in [EqualN,lten]) then
            { Can't be less than zero because the sign bit isn't set }
            lResFlags:=F_EQ
          else
            lResFlags:=F_NE;

          Location.ResFlags:=lResFlags;
          Result:=True;
        end;

      begin
        Result:=False;

        { Optimise "(x and const) = 0" and "(x and const) = const" to use TST rather than AND/CMP }
        if ((Right.NodeType=ordconstn) and (Left.NodeType=andn) and TryArrangement(TOrdConstNode(Right), TAddNode(Left))) or
          ((Left.NodeType=ordconstn) and (Right.NodeType=andn) and TryArrangement(TOrdConstNode(Left), TAddNode(Right))) then
          Result:=True;
      end;


    procedure TAArch64AddNode.Second_CmpOrdinal;
      var
        lUnsigned : Boolean;
      begin
        if Try_Second_Bit_Test then
          Exit;

        Pass_Left_Right;
        Force_Reg_Left_Right(true,true);

        lUnsigned:=not(Is_Signed(Left.ResultDef)) or
                  not(Is_Signed(Right.ResultDef));

        if Right.Location.Loc = LOC_CONSTANT then
          begin
            if Right.Location.Value>=0 then
              TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,A_CMP,Left.Location.Size,Left.Location.Register,Right.Location.Value,NR_XZR,NR_NO,false,false)
            else
{$push}{$r-}{$q-}
              TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,A_CMN,Left.Location.Size,Left.Location.Register,-Right.Location.Value,NR_XZR,NR_NO,false,false)
{$pop}
          end
        else
          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,Left.Location.Register,Right.Location.Register));

        Location_Reset(Location,LOC_FLAGS,OS_NO);
        Location.ResFlags:=GetResFlags(lUnsigned);
      end;


    procedure TAArch64AddNode.Second_AddOrdinal;
      const
        cMultiplyOps: array[Boolean] of TAsmOp = (A_SMULL,A_UMULL);
      var
        lUnsigned: Boolean;
        lLogicalNotOp: TAsmOp;
      begin
        { 32x32->64 multiplication }
        if (NodeType=muln) and
           Is_32Bit(Left.ResultDef) and
           Is_32Bit(Right.ResultDef) and
           Is_64Bit(ResultDef) then
          begin
            lUnsigned:=not(Is_Signed(Left.ResultDef)) or
                      not(Is_Signed(Right.ResultDef));
            Pass_Left_Right;
            Force_Reg_Left_Right(true,true);
            { force_reg_left_right can leave right as a LOC_CONSTANT (we can't
              say "a constant register is okay, but an ordinal constant isn't) }
            if Right.Location.Loc=LOC_CONSTANT then
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,Right.ResultDef,true);
            Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
            Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Def_CGSize(ResultDef));
            CurrentAsmData.CurrAsmList.Concat(TAICPU.op_reg_reg_reg(cMultiplyOps[lUnsigned],Location.Register,Left.Location.Register,Right.Location.Register));
            Exit;
          end
        else if (cs_opt_level2 in CurrentSettings.OptimizerSwitches) then
          begin
            { Can we turn "x and (not y)" into an ANDN instruction instead? }
            if (NodeType in [andn, orn, xorn]) and
              (
                (
                  (Left.NodeType = notn) and
                  (TNotNode(Left).Left.Location.Loc <> LOC_CONSTANT)
                ) or
                (
                  (Right.NodeType = notn) and
                  (TNotNode(Right).Left.Location.Loc <> LOC_CONSTANT)
                )
              ) then
              begin
                { BIC only supports the second operand being inverted; however,
                  since we're dealing with ordinals, there won't be any Boolean
                  shortcutting, so we can safely swap the parameters }

                if (Left.NodeType = notn) and (TNotNode(Left).Left.Location.Loc <> LOC_CONSTANT) then
                  { If the left node is "not" but is inverting a constant, then
                    the right node must also be a "not", but with a non-constant
                    input }
                  SwapLeftRight;

                SecondPass(Left);

                { Skip the not node completely }
                Include(Right.TransientFlags, tnf_do_not_execute);
                SecondPass(TNotNode(Right).Left);

                { allocate registers }
                if not (TNotNode(Right).Left.Location.Loc in [LOC_REGISTER, LOC_CREGISTER]) then
                  hlcg.Location_Force_Reg(
                    CurrentAsmData.CurrAsmList,
                    TNotNode(Right).Left.Location,
                    TNotNode(Right).Left.ResultDef,
                    TNotNode(Right).Left.ResultDef,
                    // tnotnode(right).resultdef, { In case the "not" node does some implicit typecasting }
                    false
                  );

                if not (Left.Location.Loc in [LOC_REGISTER, LOC_CREGISTER]) then
                  hlcg.Location_Force_Reg(
                    CurrentAsmData.CurrAsmList,
                    Left.Location,
                    Left.ResultDef,
                    Left.ResultDef,
                    false
                  );

                Set_Result_Location_Reg;

                case NodeType of
                  andn:
                    lLogicalNotOp := A_BIC;
                  orn:
                    lLogicalNotOp := A_ORN;
                  xorn:
                    lLogicalNotOp := A_EON;
                  else
                    InternalError(2022102130);
                end;

                CurrentAsmData.CurrAsmList.Concat(TAICPU.op_reg_reg_reg(lLogicalNotOp,Location.Register,Left.Location.Register,TNotNode(Right).Left.Location.Register));

                { We have to make sure trailing bits are cut off for unsigned
                  extensions since it will be full of 1s, so do this by
                  downsizing the register from 32-bit to the target size }
                if (Def_CGSize(ResultDef) in [OS_8, OS_16]) then
                  hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,TOrdDef(U32IntType),ResultDef,Self.Location.Register,Self.Location.Register);

                { Overflow can't happen with bic/orn/eon }
                Exit;
              end;
          end;

        { Default behaviour }
        inherited Second_AddOrdinal;
      end;


    procedure TAArch64AddNode.Second_Add64Bit;
      begin
        Second_AddOrdinal;
      end;


    procedure TAArch64AddNode.Second_Cmp64Bit;
      begin
        Second_CmpOrdinal;
      end;


    function TAArch64AddNode.Use_Generic_Mul32To64: Boolean;
      begin
        Result:=false;
      end;

    function TAArch64AddNode.Pass_1: TNode;
      begin
        Result:=inherited Pass_1;
        { if the result is not nil, a new node has been generated and the current node will be discarded }
        if Result=nil then
          begin
            if Left.ResultDef.typ=floatdef then
              if Needs_Check_For_FPU_Exceptions then
                Include(CurrentProcInfo.Flags,pi_do_call);
          end;
      end;


begin
  CAddNode:=TAArch64AddNode;
end.
