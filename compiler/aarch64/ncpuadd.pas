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
          function  GetResFlags(unsigned:Boolean):TResFlags;
          function  GetFPUResFlags:TResFlags;
       protected
          function try_second_bit_test: Boolean;

          function use_fma : boolean;override;
          procedure second_addfloat;override;
          procedure second_cmpfloat;override;
          procedure second_cmpboolean;override;
          procedure second_cmpsmallset;override;
          procedure second_cmpordinal;override;
          procedure second_addordinal;override;
          procedure second_add64bit; override;
          procedure second_cmp64bit; override;
       public
          function use_generic_mul32to64: boolean; override;
          function pass_1 : TNode;override;
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

    function TAArch64AddNode.use_fma : boolean;
      begin
        Result:=true;
      end;


    function TAArch64AddNode.GetResFlags(unsigned:Boolean):TResFlags;
      begin
        case NodeType of
          EqualN:
            GetResFlags:=F_EQ;
          unequaln:
            GetResFlags:=F_NE;
          else
            if not(unsigned) then
              begin
                if nf_swapped in flags then
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
            result:=F_EQ;
          unequaln:
            result:=F_NE;
          else
            begin
              if nf_swapped in Flags then
                case NodeType of
                  ltn:
                    result:=F_GT;
                  lten:
                    result:=F_GE;
                  gtn:
                    result:=F_LO;
                  gten:
                    result:=F_LS;
                  else
                    InternalError(2014082014);
                end
              else
                case NodeType of
                  ltn:
                    result:=F_LO;
                  lten:
                    result:=F_LS;
                  gtn:
                    result:=F_GT;
                  gten:
                    result:=F_GE;
                  else
                    InternalError(2014082015);
                end;
            end;
        end;
      end;


    procedure TAArch64AddNode.second_addfloat;
      var
        op : TAsmOp;
      begin
        pass_left_right;
        if nf_swapped in flags then
          swapleftright;

        { force fpureg as location, left right doesn't matter
          as both will be in a fpureg }
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,true);

        Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));
        location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);

        case nodetype of
          addn :
            begin
              op:=A_FADD;
            end;
          muln :
            begin
              op:=A_FMUL;
            end;
          subn :
            begin
              op:=A_FSUB;
            end;
          slashn :
            begin
              op:=A_FDIV;
            end;
          else
            InternalError(200306014);
        end;

        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(op,
           location.Register,left.Location.Register,right.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64AddNode.second_cmpfloat;
      begin
        pass_left_right;
        if nf_swapped in flags then
          swapleftright;

        { force fpureg as location, left right doesn't matter
          as both will be in a fpureg }
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,true);

        Location_Reset(location,LOC_FLAGS,OS_NO);
        location.ResFlags:=getfpuresflags;

        { signalling compare so we can get exceptions }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCMPE,
             left.Location.Register,right.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64AddNode.second_cmpboolean;
      begin
        pass_left_right;
        force_reg_left_right(true,true);

        if right.Location.Loc=LOC_CONSTANT then
          begin
            if right.Location.Value>=0 then
              TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,A_CMP,left.Location.Size,left.Location.Register,right.Location.Value,NR_XZR,NR_NO,false,false)
            else
              { avoid overflow if value=low(int64) }
{$push}{$r-}{$q-}
              TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,A_CMN,left.Location.Size,left.Location.Register,-right.Location.Value,NR_XZR,NR_NO,false,false)
{$pop}
          end
        else
          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,left.Location.Register,right.Location.Register));

        Location_Reset(location,LOC_FLAGS,OS_NO);
        location.ResFlags:=getresflags(true);
      end;


    procedure TAArch64AddNode.second_cmpsmallset;
      var
        tmpreg : TRegister;
        op: TAsmOp;
      begin
        pass_left_right;

        Location_Reset(location,LOC_FLAGS,OS_NO);

        force_reg_left_right(true,true);

        if right.Location.Loc=LOC_CONSTANT then
          begin
            { when doing a cmp/cmn on 32 bit, we care whether the *lower 32 bit*
              is a positive/negative value -> sign extend }
            if not(right.Location.Size in [OS_64,OS_S64]) then
              right.Location.Value:=LongInt(right.Location.Value);
            if right.Location.Value>=0 then
              op:=A_CMP
            else
              op:=A_CMN;
          end
        else
          { for DFA }
          op:=A_NONE;

        case nodetype of
          EqualN,
          unequaln:
            begin
              if right.Location.Loc=LOC_CONSTANT then
                TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,op,Def_CGSize(resultdef),left.Location.Register,abs(right.Location.Value),NR_XZR,NR_NO,false,false)
              else
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,left.Location.Register,right.Location.Register));
              location.ResFlags:=getresflags(true);
            end;
          lten,
          gten:
            begin
              if (not(nf_swapped in flags) and
                  (nodetype=lten)) or
                 ((nf_swapped in flags) and
                  (nodetype=gten)) then
                swapleftright;
              { we can't handle left as a constant yet }
              if left.Location.Loc=LOC_CONSTANT then
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true);
              tmpreg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,left.Location.Size);
              if right.Location.Loc=LOC_CONSTANT then
                begin
                  hlcg.A_Op_Const_Reg_Reg(CurrentAsmData.CurrAsmList,OP_AND,resultdef,right.Location.Value,left.Location.Register,tmpreg);
                  TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,op,Def_CGSize(resultdef),tmpreg,abs(right.Location.Value),NR_XZR,NR_NO,false,false)
                end
              else
                begin
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_AND,tmpreg,left.Location.Register,right.Location.Register));
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,tmpreg,right.Location.Register));
                end;
              location.ResFlags:=F_EQ;
            end;
          else
            InternalError(2012042701);
        end;
      end;


    function TAArch64AddNode.try_second_bit_test: Boolean;

      function try_arrangement(compvaln: TOrdConstNode; andn: TAddNode): Boolean;
        var
          ResFlags: TResFlags;
          andconstn: TOrdConstNode;
          inputn: TNode;
        begin
          Result:=False;
          if andn.right.nodetype=ordconstn then
            begin
              andconstn:=TOrdConstNode(andn.right);
              inputn:=andn.left;
            end
          else if andn.left.nodetype=ordconstn then
            begin
              andconstn:=TOrdConstNode(andn.left);
              inputn:=andn.right;
            end
          else
            Exit;

          { An earlier node optimisation turns (x and const) = x into (x and const) <> 0
            if PopCnt(const) = 1, so don't bother checking anything other than 0 }
          if (compvaln.Value.svalue<>0) or (nodetype in [gten,ltn]) or
            { If the condition is <= or >, the optimisation can still work as
              long as the bit in question isn't the sign bit }
            (
              (nodetype in [gtn,lten]) and
              (
                ((inputn.Location.Size=OS_S64) and (andconstn.Value.svalue=$8000000000000000)) or
                (not (inputn.Location.Size in [OS_64,OS_S64,OS_32]) and (LongWord(andconstn.Value.uvalue)=$80000000))
              )
            )
            then
            Exit;

          { Skip processing the constant and and nodes }
          Include(compvaln.transientflags,tnf_do_not_execute);
          Include(andn.transientflags,tnf_do_not_execute);

          SecondPass(inputn);

          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,inputn.Location,inputn.resultdef,inputn.resultdef,true);

          if not is_shifter_const(andconstn.Value.svalue, inputn.Location.Size) then
            begin
              SecondPass(andconstn);
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,andconstn.Location,andconstn.resultdef,andconstn.resultdef,false);
              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_TST,inputn.Location.Register,andconstn.Location.Register));
            end
          else
            begin
              Include(andconstn.transientflags,tnf_do_not_execute);
              CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_const(A_TST,inputn.Location.Register,andconstn.Value.svalue));
            end;

          Location_Reset(location,LOC_FLAGS,OS_NO);
          if (nodetype in [EqualN,lten]) then
            { Can't be less than zero because the sign bit isn't set }
            ResFlags:=F_EQ
          else
            ResFlags:=F_NE;

          location.ResFlags:=ResFlags;
          Result:=True;
        end;

      begin
        Result:=False;

        { Optimise "(x and const) = 0" and "(x and const) = const" to use TST rather than AND/CMP }
        if ((right.nodetype=ordconstn) and (left.nodetype=andn) and try_arrangement(TOrdConstNode(right), TAddNode(left))) or
          ((left.nodetype=ordconstn) and (right.nodetype=andn) and try_arrangement(TOrdConstNode(left), TAddNode(right))) then
          Result:=True;
      end;


    procedure TAArch64AddNode.second_cmpordinal;
      var
        unsigned : boolean;
      begin
        if try_second_bit_test then
          Exit;

        pass_left_right;
        force_reg_left_right(true,true);

        unsigned:=not(Is_Signed(left.resultdef)) or
                  not(Is_Signed(right.resultdef));

        if right.Location.Loc = LOC_CONSTANT then
          begin
            if right.Location.Value>=0 then
              TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,A_CMP,left.Location.Size,left.Location.Register,right.Location.Value,NR_XZR,NR_NO,false,false)
            else
{$push}{$r-}{$q-}
              TCGAArch64(cg).handle_reg_imm12_reg(CurrentAsmData.CurrAsmList,A_CMN,left.Location.Size,left.Location.Register,-right.Location.Value,NR_XZR,NR_NO,false,false)
{$pop}
          end
        else
          CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,left.Location.Register,right.Location.Register));

        Location_Reset(location,LOC_FLAGS,OS_NO);
        location.ResFlags:=getresflags(unsigned);
      end;


    procedure TAArch64AddNode.second_addordinal;
      const
        multops: array[boolean] of TAsmOp = (A_SMULL,A_UMULL);
      var
        unsigned: boolean;
        logical_not_op: TAsmOp;
      begin
        { 32x32->64 multiplication }
        if (nodetype=muln) and
           Is_32Bit(left.resultdef) and
           Is_32Bit(right.resultdef) and
           Is_64Bit(resultdef) then
          begin
            unsigned:=not(Is_Signed(left.resultdef)) or
                      not(Is_Signed(right.resultdef));
            pass_left_right;
            force_reg_left_right(true,true);
            { force_reg_left_right can leave right as a LOC_CONSTANT (we can't
              say "a constant register is okay, but an ordinal constant isn't) }
            if right.Location.Loc=LOC_CONSTANT then
              hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,right.resultdef,true);
            Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
            location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Def_CGSize(resultdef));
            CurrentAsmData.CurrAsmList.Concat(TAICPU.op_reg_reg_reg(multops[unsigned],location.Register,left.Location.Register,right.Location.Register));
            Exit;
          end
        else if (cs_opt_level2 in CurrentSettings.OptimizerSwitches) then
          begin
            { Can we turn "x and (not y)" into an ANDN instruction instead? }
            if (nodetype in [andn, orn, xorn]) and
              (
                (
                  (left.nodetype = notn) and
                  (TNotNode(left).left.Location.Loc <> LOC_CONSTANT)
                ) or
                (
                  (right.nodetype = notn) and
                  (TNotNode(right).left.Location.Loc <> LOC_CONSTANT)
                )
              ) then
              begin
                { BIC only supports the second operand being inverted; however,
                  since we're dealing with ordinals, there won't be any Boolean
                  shortcutting, so we can safely swap the parameters }

                if (left.nodetype = notn) and (TNotNode(left).left.Location.Loc <> LOC_CONSTANT) then
                  { If the left node is "not" but is inverting a constant, then
                    the right node must also be a "not", but with a non-constant
                    input }
                  swapleftright;

                SecondPass(left);

                { Skip the not node completely }
                Include(right.transientflags, tnf_do_not_execute);
                SecondPass(TNotNode(right).left);

                { allocate registers }
                if not (TNotNode(right).left.Location.Loc in [LOC_REGISTER, LOC_CREGISTER]) then
                  hlcg.Location_Force_Reg(
                    CurrentAsmData.CurrAsmList,
                    TNotNode(right).left.Location,
                    TNotNode(right).left.resultdef,
                    TNotNode(right).left.resultdef,
                    // tnotnode(right).resultdef, { In case the "not" node does some implicit typecasting }
                    false
                  );

                if not (left.Location.Loc in [LOC_REGISTER, LOC_CREGISTER]) then
                  hlcg.Location_Force_Reg(
                    CurrentAsmData.CurrAsmList,
                    left.Location,
                    left.resultdef,
                    left.resultdef,
                    false
                  );

                set_result_location_reg;

                case nodetype of
                  andn:
                    logical_not_op := A_BIC;
                  orn:
                    logical_not_op := A_ORN;
                  xorn:
                    logical_not_op := A_EON;
                  else
                    InternalError(2022102130);
                end;

                CurrentAsmData.CurrAsmList.Concat(TAICPU.op_reg_reg_reg(logical_not_op,location.Register,left.Location.Register,TNotNode(right).left.Location.Register));

                { We have to make sure trailing bits are cut off for unsigned
                  extensions since it will be full of 1s, so do this by
                  downsizing the register from 32-bit to the target size }
                if (Def_CGSize(resultdef) in [OS_8, OS_16]) then
                  hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,TOrdDef(U32IntType),resultdef,self.Location.Register,self.Location.Register);

                { Overflow can't happen with bic/orn/eon }
                Exit;
              end;
          end;

        { Default behaviour }
        inherited second_addordinal;
      end;


    procedure TAArch64AddNode.second_add64bit;
      begin
        second_addordinal;
      end;


    procedure TAArch64AddNode.second_cmp64bit;
      begin
        second_cmpordinal;
      end;


    function TAArch64AddNode.use_generic_mul32to64: boolean;
      begin
        result:=false;
      end;

    function TAArch64AddNode.pass_1: TNode;
      begin
        Result:=inherited pass_1;
        { if the result is not nil, a new node has been generated and the current node will be discarded }
        if Result=nil then
          begin
            if left.resultdef.typ=floatdef then
              if Needs_Check_For_FPU_Exceptions then
                Include(CurrentProcInfo.flags,pi_do_call);
          end;
      end;


begin
  CAddNode:=TAArch64AddNode;
end.
