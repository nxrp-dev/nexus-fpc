{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generates AAarch64 inline nodes

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
unit ncpuinl;

{$i fpcdefs.inc}

interface

    uses
      node,ninl,ncginl;

    type
      TAArch64InlineNode = class(TCGInlineNode)
        function first_abs_real: TNode; override;
        function first_sqr_real: TNode; override;
        function first_sqrt_real: TNode; override;
        function first_round_real: TNode; override;
        function first_trunc_real: TNode; override;
        function first_int_real: TNode; override;
        function first_frac_real: TNode; override;
        function first_fma : TNode; override;
        function first_minmax : TNode; override;
        procedure second_abs_real; override;
        procedure second_sqr_real; override;
        procedure second_sqrt_real; override;
        procedure second_abs_long; override;
        procedure second_round_real; override;
        procedure second_trunc_real; override;
        procedure second_int_real; override;
        procedure second_frac_real; override;
        procedure second_get_frame; override;
        procedure second_fma; override;
        procedure second_prefetch; override;
        procedure second_minmax; override;
        procedure pass_generate_code_cpu; override;
        function pass_typecheck_cpu: TNode; override;
        function first_cpu: TNode; override;
      private
        procedure load_fpu_location;
      end;


implementation

    uses
      GlobType,Verbose,Globals,
      compinnr,
      CPUInfo, defutil,symdef,aasmbase,AAsmData,aasmcpu,
      cgbase,cgutils,pass_1,pass_2,
      ProcInfo,
      ncal,nutils,
      cpubase,ncgutil,cgobj,cgcpu,hlcgobj;

{*****************************************************************************
                              taarch64inlinenode
*****************************************************************************}

     function TAArch64InlineNode.pass_typecheck_cpu: TNode;
       begin
         Result:=nil;
         case inlinenumber of
           in_a64_yield:
             resultdef:=VoidType;
           else
             result:=inherited;
         end;
       end;


    function TAArch64InlineNode.first_cpu : TNode;
      begin
        Result:=nil;
        case inlinenumber of
          in_a64_yield:
            begin
              expectloc:=LOC_VOID;
              resultdef:=VoidType;
            end;
          else
            Result:=inherited first_cpu;
        end;
      end;


     procedure TAArch64InlineNode.pass_generate_code_cpu;
       begin
         case inlinenumber of
           in_a64_yield:
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_YIELD));
           else
             inherited pass_generate_code_cpu;
         end;
       end;


    procedure TAArch64InlineNode.load_fpu_location;
      begin
        SecondPass(left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
        Location_Copy(location,left.Location);
        location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
        location.Loc:=LOC_MMREGISTER;
      end;


    function TAArch64InlineNode.first_abs_real : TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_sqr_real : TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_sqrt_real : TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_round_real: TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_trunc_real: TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_int_real : TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_frac_real : TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_fma : TNode;
      begin
        if ((Is_Double(resultdef)) or (Is_Single(resultdef))) then
          begin
            expectloc:=LOC_MMREGISTER;
            Result:=nil;
          end
        else
          Result:=inherited first_fma;
     end;


    procedure TAArch64InlineNode.second_abs_real;
      begin
        load_fpu_location;
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FABS,location.Register,left.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_sqr_real;
      begin
        load_fpu_location;
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_FMUL,location.Register,left.Location.Register,left.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_sqrt_real;
      begin
        load_fpu_location;
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FSQRT,location.Register,left.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_abs_long;
      var
        opsize : TCgSize;
        hl: TAsmLabel;
      begin
        SecondPass(left);
        opsize:=Def_CGSize(left.resultdef);
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,true);
        location:=left.Location;
        location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,opsize);

        if cs_check_overflow in CurrentSettings.LocalSwitches then
          begin
            CurrentAsmData.getjumplabel(hl);
            hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,resultdef,OC_NE,TOrdDef(resultdef).low.svalue,left.Location.Register,hl);
            hlcg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,'fpc_overflow',[],nil).ResetIfTemp;
            hlcg.A_Label(CurrentAsmData.CurrAsmList,hl);
          end;

        CurrentAsmData.CurrAsmList.concat(setoppostfix(TAICPU.op_reg_reg(A_NEG,location.Register,left.Location.Register),PF_S));
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_CSEL,location.Register,location.Register,left.Location.Register,C_GE));
      end;


    procedure TAArch64InlineNode.second_round_real;
      var
        hreg: TRegister;
      begin
        SecondPass(left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
        Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
        location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
        hreg:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,left.Location.Size);
        { round as floating point using current rounding mode }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FRINTX,hreg,left.Location.Register));
        { convert to signed integer rounding towards zero (there's no "round to
          integer using current rounding mode") }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCVTZS,location.Register,hreg));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_trunc_real;
      begin
        SecondPass(left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
        Location_Reset(location,LOC_REGISTER,Def_CGSize(resultdef));
        location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);
        { convert to signed integer rounding towards zero }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCVTZS,location.Register,left.Location.Register));
      end;


    procedure TAArch64InlineNode.second_int_real;
      var
        hreg: TRegister;
      begin
        SecondPass(left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
        Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));
        location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FRINTZ,location.Register,left.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_frac_real;
      var
        hreg: TRegister;
      begin
        SecondPass(left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,true);
        Location_Reset(location,LOC_MMREGISTER,Def_CGSize(resultdef));
        location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FRINTZ,location.Register,left.Location.Register));
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_FSUB,location.Register,left.Location.Register,location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_get_frame;
      begin
        Location_Reset(location,LOC_CREGISTER,OS_ADDR);
        { this routine is used to get the frame pointer for backtracing
          purposes. current_procinfo.framepointer is set to SP because that one
          is used to access temps. On most platforms these two frame pointers
          are the same, but not on AArch64. }
        location.Register:=NR_FRAME_POINTER_REG;
      end;


    procedure TAArch64InlineNode.second_fma;
      const
        op : array[false..true,false..true] of TAsmOp =
          { positive product }
          (
           { positive third operand }
           (A_FMADD,
           { negative third operand }
            A_FNMSUB),
           { negative product }
            { positive third operand }
            (A_FMSUB,
             A_FNMADD)
           );

      var
        paraarray : array[1..3] of TNode;
        i : integer;
        negop3,
        negproduct : boolean;
      begin
        negop3:=false;
        negproduct:=false;
        paraarray[1]:=TCallParaNode(TCallParaNode(TCallParaNode(parameters).nextpara).nextpara).paravalue;
        paraarray[2]:=TCallParaNode(TCallParaNode(parameters).nextpara).paravalue;
        paraarray[3]:=TCallParaNode(parameters).paravalue;

        { check if a neg. node can be removed
          this is possible because changing the sign of
          a floating point number does not affect its absolute
          value in any way
        }
        if paraarray[1].nodetype=unaryminusn then
          begin
            paraarray[1]:=TUnaryNode(paraarray[1]).left;
            { do not release the unused unary minus node, it is kept and release together with the other nodes,
              only no code is generated for it }
            negproduct:=not(negproduct);
          end;

        if paraarray[2].nodetype=unaryminusn then
          begin
            paraarray[2]:=TUnaryNode(paraarray[2]).left;
            { do not release the unused unary minus node, it is kept and release together with the other nodes,
              only no code is generated for it }
            negproduct:=not(negproduct);
          end;

        if paraarray[3].nodetype=unaryminusn then
          begin
            paraarray[3]:=TUnaryNode(paraarray[3]).left;
            { do not release the unused unary minus node, it is kept and release together with the other nodes,
              only no code is generated for it }
            negop3:=true;
          end;

         for i:=1 to 3 do
          SecondPass(paraarray[i]);

        { no memory operand is allowed }
        for i:=1 to 3 do
          begin
            if not(paraarray[i].Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
              hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,paraarray[i].Location,paraarray[i].resultdef,true);
          end;

        Location_Reset(location,LOC_MMREGISTER,paraarray[1].Location.Size);
        location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);

        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_reg(op[negproduct,negop3],
          location.Register,paraarray[1].Location.Register,paraarray[2].Location.Register,paraarray[3].Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_prefetch;
      var
        ref : TReference;
        r : TRegister;
        checkpointer_used : boolean;
      begin
        { do not call Checkpointer for left node }
        checkpointer_used:=(cs_checkpointer in CurrentSettings.LocalSwitches);
        if checkpointer_used then
          node_change_local_switch(left,cs_checkpointer,false);
        SecondPass(left);
        if checkpointer_used then
          node_change_local_switch(left,cs_checkpointer,false);
       case left.Location.Loc of
         LOC_CREFERENCE,
         LOC_REFERENCE:
           begin
             r:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
             cg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,left.Location.Reference,r);
             Reference_Reset_Base(ref,r,0,location.Reference.TempPos,left.Location.Reference.Alignment,location.Reference.Volatility);
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref(A_PRFM,0,ref));
           end;
         else
           { nothing to prefetch };
       end;
      end;


    function TAArch64InlineNode.first_minmax : TNode;
      begin
        if Is_Single(resultdef) or Is_Double(resultdef) then
          begin
            expectloc:=LOC_MMREGISTER;
            Result:=nil;
            if Needs_Check_For_FPU_Exceptions then
              Include(CurrentProcInfo.flags,pi_do_call);
          end
        else if Is_32BitInt(resultdef) or Is_64BitInt(resultdef) then
          begin
            expectloc:=LOC_REGISTER;
            Result:=nil;
          end
        else
          Result:=inherited first_minmax;
      end;


    procedure TAArch64InlineNode.second_minmax;
      var
        paraarray : array[1..2] of TNode;
        i: Integer;
        ai: TAICPU;
        op: TAsmOp;
        cond: TAsmCond;
      begin
        paraarray[1]:=TCallParaNode(TCallParaNode(parameters).nextpara).paravalue;
          paraarray[2]:=TCallParaNode(parameters).paravalue;

        for i:=low(paraarray) to high(paraarray) do
           SecondPass(paraarray[i]);

        if Is_Single(resultdef) or Is_Double(resultdef) then
           begin
             { no memory operand is allowed }
             for i:=low(paraarray) to high(paraarray) do
               begin
                 if not(paraarray[i].Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                   hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,paraarray[i].Location,
                     paraarray[i].resultdef,true);
               end;

             Location_Reset(location,LOC_MMREGISTER,paraarray[1].Location.Size);
             location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,location.Size);

             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCMP,
               paraarray[1].Location.Register,paraarray[2].Location.Register));

             case inlinenumber of
               in_min_single,
               in_min_double:
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_FCSEL,
                  location.Register,paraarray[1].Location.Register,paraarray[2].Location.Register,C_MI));
               in_max_single,
               in_max_double:
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_FCSEL,
                  location.Register,paraarray[1].Location.Register,paraarray[2].Location.Register,C_GT));
               else
                 InternalError(2021121802);
             end;

             cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
           end
         else if Is_32BitInt(resultdef) or Is_64BitInt(resultdef) then
           begin
             { no memory operand is allowed }
             for i:=low(paraarray) to high(paraarray) do
               begin
                 if not(paraarray[i].Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
                   hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,paraarray[i].Location,
                     paraarray[i].resultdef,paraarray[i].resultdef,true);
               end;

             Location_Reset(location,LOC_REGISTER,paraarray[1].Location.Size);
             location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,location.Size);

             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,
               paraarray[1].Location.Register,paraarray[2].Location.Register));

             case inlinenumber of
               in_min_longint,
               in_min_int64:
                 cond := C_LT;
               in_min_dword,
               in_min_qword:
                 cond := C_LO;
               in_max_longint,
               in_max_int64:
                 cond := C_GT;
               in_max_dword,
               in_max_qword:
                 cond := C_HI;
               else
                 InternalError(2021121901);
             end;
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_CSEL,
               location.Register,paraarray[1].Location.Register,paraarray[2].Location.Register,cond));
           end
         else
           InternalError(2021121801);
      end;


begin
  CInlineNode:=TAArch64InlineNode;
end.
