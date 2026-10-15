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
             resultdef:=voidtype;
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
              resultdef:=voidtype;
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
        hlcg.location_force_mmregscalar(CurrentAsmData.CurrAsmList,left.location,left.resultdef,true);
        location_copy(location,left.location);
        location.register:=cg.getmmregister(CurrentAsmData.CurrAsmList,location.size);
        location.loc:=LOC_MMREGISTER;
      end;


    function TAArch64InlineNode.first_abs_real : TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if needs_check_for_fpu_exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_sqr_real : TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if needs_check_for_fpu_exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_sqrt_real : TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if needs_check_for_fpu_exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_round_real: TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if needs_check_for_fpu_exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_trunc_real: TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if needs_check_for_fpu_exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_int_real : TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if needs_check_for_fpu_exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_frac_real : TNode;
      begin
        expectloc:=LOC_MMREGISTER;
        result:=nil;
        if needs_check_for_fpu_exceptions then
          Include(CurrentProcInfo.flags,pi_do_call);
      end;


    function TAArch64InlineNode.first_fma : TNode;
      begin
        if ((is_double(resultdef)) or (is_single(resultdef))) then
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
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FABS,location.register,left.location.register));
        cg.maybe_check_for_fpu_exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_sqr_real;
      begin
        load_fpu_location;
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_FMUL,location.register,left.location.register,left.location.register));
        cg.maybe_check_for_fpu_exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_sqrt_real;
      begin
        load_fpu_location;
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FSQRT,location.register,left.location.register));
        cg.maybe_check_for_fpu_exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_abs_long;
      var
        opsize : TCgSize;
        hl: TAsmLabel;
      begin
        SecondPass(left);
        opsize:=def_cgsize(left.resultdef);
        hlcg.location_force_reg(CurrentAsmData.CurrAsmList,left.location,left.resultdef,left.resultdef,true);
        location:=left.location;
        location.register:=cg.getintregister(CurrentAsmData.CurrAsmList,opsize);

        if cs_check_overflow in CurrentSettings.LocalSwitches then
          begin
            CurrentAsmData.getjumplabel(hl);
            hlcg.a_cmp_const_reg_label(CurrentAsmData.CurrAsmList,resultdef,OC_NE,TOrdDef(resultdef).low.svalue,left.location.register,hl);
            hlcg.a_reg_dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            hlcg.g_call_system_proc(CurrentAsmData.CurrAsmList,'fpc_overflow',[],nil).resetiftemp;
            hlcg.a_label(CurrentAsmData.CurrAsmList,hl);
          end;

        CurrentAsmData.CurrAsmList.concat(setoppostfix(TAICPU.op_reg_reg(A_NEG,location.register,left.location.register),PF_S));
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_CSEL,location.register,location.register,left.location.register,C_GE));
      end;


    procedure TAArch64InlineNode.second_round_real;
      var
        hreg: TRegister;
      begin
        SecondPass(left);
        hlcg.location_force_mmregscalar(CurrentAsmData.CurrAsmList,left.location,left.resultdef,true);
        location_reset(location,LOC_REGISTER,def_cgsize(resultdef));
        location.register:=cg.getintregister(CurrentAsmData.CurrAsmList,location.size);
        hreg:=cg.getmmregister(CurrentAsmData.CurrAsmList,left.location.size);
        { round as floating point using current rounding mode }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FRINTX,hreg,left.location.register));
        { convert to signed integer rounding towards zero (there's no "round to
          integer using current rounding mode") }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCVTZS,location.register,hreg));
        cg.maybe_check_for_fpu_exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_trunc_real;
      begin
        SecondPass(left);
        hlcg.location_force_mmregscalar(CurrentAsmData.CurrAsmList,left.location,left.resultdef,true);
        location_reset(location,LOC_REGISTER,def_cgsize(resultdef));
        location.register:=cg.getintregister(CurrentAsmData.CurrAsmList,location.size);
        { convert to signed integer rounding towards zero }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCVTZS,location.register,left.location.register));
      end;


    procedure TAArch64InlineNode.second_int_real;
      var
        hreg: TRegister;
      begin
        SecondPass(left);
        hlcg.location_force_mmregscalar(CurrentAsmData.CurrAsmList,left.location,left.resultdef,true);
        location_reset(location,LOC_MMREGISTER,def_cgsize(resultdef));
        location.register:=cg.getmmregister(CurrentAsmData.CurrAsmList,location.size);
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FRINTZ,location.register,left.location.register));
        cg.maybe_check_for_fpu_exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_frac_real;
      var
        hreg: TRegister;
      begin
        SecondPass(left);
        hlcg.location_force_mmregscalar(CurrentAsmData.CurrAsmList,left.location,left.resultdef,true);
        location_reset(location,LOC_MMREGISTER,def_cgsize(resultdef));
        location.register:=cg.getmmregister(CurrentAsmData.CurrAsmList,location.size);
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FRINTZ,location.register,left.location.register));
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_FSUB,location.register,left.location.register,location.register));
        cg.maybe_check_for_fpu_exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.second_get_frame;
      begin
        location_reset(location,LOC_CREGISTER,OS_ADDR);
        { this routine is used to get the frame pointer for backtracing
          purposes. current_procinfo.framepointer is set to SP because that one
          is used to access temps. On most platforms these two frame pointers
          are the same, but not on AArch64. }
        location.register:=NR_FRAME_POINTER_REG;
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
            if not(paraarray[i].location.loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
              hlcg.location_force_mmregscalar(CurrentAsmData.CurrAsmList,paraarray[i].location,paraarray[i].resultdef,true);
          end;

        location_reset(location,LOC_MMREGISTER,paraarray[1].location.size);
        location.register:=cg.getmmregister(CurrentAsmData.CurrAsmList,location.size);

        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_reg(op[negproduct,negop3],
          location.register,paraarray[1].location.register,paraarray[2].location.register,paraarray[3].location.register));
        cg.maybe_check_for_fpu_exception(CurrentAsmData.CurrAsmList);
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
       case left.location.loc of
         LOC_CREFERENCE,
         LOC_REFERENCE:
           begin
             r:=cg.getintregister(CurrentAsmData.CurrAsmList,OS_ADDR);
             cg.a_loadaddr_ref_reg(CurrentAsmData.CurrAsmList,left.location.reference,r);
             reference_reset_base(ref,r,0,location.reference.temppos,left.location.reference.alignment,location.reference.volatility);
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref(A_PRFM,0,ref));
           end;
         else
           { nothing to prefetch };
       end;
      end;


    function TAArch64InlineNode.first_minmax : TNode;
      begin
        if is_single(resultdef) or is_double(resultdef) then
          begin
            expectloc:=LOC_MMREGISTER;
            Result:=nil;
            if needs_check_for_fpu_exceptions then
              Include(CurrentProcInfo.flags,pi_do_call);
          end
        else if is_32bitint(resultdef) or is_64bitint(resultdef) then
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

        if is_single(resultdef) or is_double(resultdef) then
           begin
             { no memory operand is allowed }
             for i:=low(paraarray) to high(paraarray) do
               begin
                 if not(paraarray[i].location.loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                   hlcg.location_force_mmregscalar(CurrentAsmData.CurrAsmList,paraarray[i].location,
                     paraarray[i].resultdef,true);
               end;

             location_reset(location,LOC_MMREGISTER,paraarray[1].location.size);
             location.register:=cg.getmmregister(CurrentAsmData.CurrAsmList,location.size);

             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCMP,
               paraarray[1].location.register,paraarray[2].location.register));

             case inlinenumber of
               in_min_single,
               in_min_double:
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_FCSEL,
                  location.register,paraarray[1].location.register,paraarray[2].location.register,C_MI));
               in_max_single,
               in_max_double:
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_FCSEL,
                  location.register,paraarray[1].location.register,paraarray[2].location.register,C_GT));
               else
                 InternalError(2021121802);
             end;

             cg.maybe_check_for_fpu_exception(CurrentAsmData.CurrAsmList);
           end
         else if is_32bitint(resultdef) or is_64bitint(resultdef) then
           begin
             { no memory operand is allowed }
             for i:=low(paraarray) to high(paraarray) do
               begin
                 if not(paraarray[i].location.loc in [LOC_REGISTER,LOC_CREGISTER]) then
                   hlcg.location_force_reg(CurrentAsmData.CurrAsmList,paraarray[i].location,
                     paraarray[i].resultdef,paraarray[i].resultdef,true);
               end;

             location_reset(location,LOC_REGISTER,paraarray[1].location.size);
             location.register:=cg.getintregister(CurrentAsmData.CurrAsmList,location.size);

             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,
               paraarray[1].location.register,paraarray[2].location.register));

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
               location.register,paraarray[1].location.register,paraarray[2].location.register,cond));
           end
         else
           InternalError(2021121801);
      end;


begin
  CInlineNode:=TAArch64InlineNode;
end.
