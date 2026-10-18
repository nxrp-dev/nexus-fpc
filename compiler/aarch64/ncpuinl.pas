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
        function First_Abs_Real: TNode; override;
        function First_Sqr_Real: TNode; override;
        function First_Sqrt_Real: TNode; override;
        function First_Round_Real: TNode; override;
        function First_Trunc_Real: TNode; override;
        function First_Int_Real: TNode; override;
        function First_Frac_Real: TNode; override;
        function First_FMA : TNode; override;
        function First_MinMax : TNode; override;
        procedure Second_Abs_Real; override;
        procedure Second_Sqr_Real; override;
        procedure Second_Sqrt_Real; override;
        procedure Second_Abs_Long; override;
        procedure Second_Round_Real; override;
        procedure Second_Trunc_Real; override;
        procedure Second_Int_Real; override;
        procedure Second_Frac_Real; override;
        procedure Second_Get_Frame; override;
        procedure Second_FMA; override;
        procedure Second_Prefetch; override;
        procedure Second_MinMax; override;
        procedure Pass_Generate_Code_CPU; override;
        function Pass_TypeCheck_CPU: TNode; override;
        function First_CPU: TNode; override;
      private
        procedure LoadFPULocation;
      end;


implementation

    uses
      GlobType,Verbose,Globals,
      compinnr,
      CPUInfo, defutil,symdef,aasmbase,AAsmData,aasmcpu,
      cgbase,cgutils,Pass_1,pass_2,
      ProcInfo,
      ncal,nutils,
      cpubase,ncgutil,cgobj,cgcpu,hlcgobj;

{*****************************************************************************
                              taarch64inlinenode
*****************************************************************************}

     function TAArch64InlineNode.Pass_TypeCheck_CPU: TNode;
       begin
         Result:=nil;
         case InlineNumber of
           in_a64_yield:
             ResultDef:=VoidType;
           else
             Result:=inherited;
         end;
       end;


    function TAArch64InlineNode.First_CPU : TNode;
      begin
        Result:=nil;
        case InlineNumber of
          in_a64_yield:
            begin
              ExpectLoc:=LOC_VOID;
              ResultDef:=VoidType;
            end;
          else
            Result:=inherited First_CPU;
        end;
      end;


     procedure TAArch64InlineNode.Pass_Generate_Code_CPU;
       begin
         case InlineNumber of
           in_a64_yield:
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_none(A_YIELD));
           else
             inherited Pass_Generate_Code_CPU;
         end;
       end;


    procedure TAArch64InlineNode.LoadFPULocation;
      begin
        SecondPass(Left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
        Location_Copy(Location,Left.Location);
        Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
        Location.Loc:=LOC_MMREGISTER;
      end;


    function TAArch64InlineNode.First_Abs_Real : TNode;
      begin
        ExpectLoc:=LOC_MMREGISTER;
        Result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.Flags,pi_do_call);
      end;


    function TAArch64InlineNode.First_Sqr_Real : TNode;
      begin
        ExpectLoc:=LOC_MMREGISTER;
        Result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.Flags,pi_do_call);
      end;


    function TAArch64InlineNode.First_Sqrt_Real : TNode;
      begin
        ExpectLoc:=LOC_MMREGISTER;
        Result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.Flags,pi_do_call);
      end;


    function TAArch64InlineNode.First_Round_Real: TNode;
      begin
        ExpectLoc:=LOC_MMREGISTER;
        Result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.Flags,pi_do_call);
      end;


    function TAArch64InlineNode.First_Trunc_Real: TNode;
      begin
        ExpectLoc:=LOC_MMREGISTER;
        Result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.Flags,pi_do_call);
      end;


    function TAArch64InlineNode.First_Int_Real : TNode;
      begin
        ExpectLoc:=LOC_MMREGISTER;
        Result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.Flags,pi_do_call);
      end;


    function TAArch64InlineNode.First_Frac_Real : TNode;
      begin
        ExpectLoc:=LOC_MMREGISTER;
        Result:=nil;
        if Needs_Check_For_FPU_Exceptions then
          Include(CurrentProcInfo.Flags,pi_do_call);
      end;


    function TAArch64InlineNode.First_FMA : TNode;
      begin
        if ((Is_Double(ResultDef)) or (Is_Single(ResultDef))) then
          begin
            ExpectLoc:=LOC_MMREGISTER;
            Result:=nil;
          end
        else
          Result:=inherited First_FMA;
     end;


    procedure TAArch64InlineNode.Second_Abs_Real;
      begin
        LoadFPULocation;
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FABS,Location.Register,Left.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.Second_Sqr_Real;
      begin
        LoadFPULocation;
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_FMUL,Location.Register,Left.Location.Register,Left.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.Second_Sqrt_Real;
      begin
        LoadFPULocation;
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FSQRT,Location.Register,Left.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.Second_Abs_Long;
      var
        lOpSize : TCgSize;
        lLabel: TAsmLabel;
      begin
        SecondPass(Left);
        lOpSize:=Def_CGSize(Left.ResultDef);
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true);
        Location:=Left.Location;
        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,lOpSize);

        if cs_check_overflow in CurrentSettings.LocalSwitches then
          begin
            CurrentAsmData.getjumplabel(lLabel);
            hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,ResultDef,OC_NE,TOrdDef(ResultDef).low.svalue,Left.Location.Register,lLabel);
            hlcg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
            hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,'fpc_overflow',[],nil).ResetIfTemp;
            hlcg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
          end;

        CurrentAsmData.CurrAsmList.concat(setoppostfix(TAICPU.op_reg_reg(A_NEG,Location.Register,Left.Location.Register),PF_S));
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_CSEL,Location.Register,Location.Register,Left.Location.Register,C_GE));
      end;


    procedure TAArch64InlineNode.Second_Round_Real;
      var
        lReg: TRegister;
      begin
        SecondPass(Left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
        Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
        lReg:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Left.Location.Size);
        { round as floating point using current rounding mode }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FRINTX,lReg,Left.Location.Register));
        { convert to signed integer rounding towards zero (there's no "round to
          integer using current rounding mode") }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCVTZS,Location.Register,lReg));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.Second_Trunc_Real;
      begin
        SecondPass(Left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
        Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);
        { convert to signed integer rounding towards zero }
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCVTZS,Location.Register,Left.Location.Register));
      end;


    procedure TAArch64InlineNode.Second_Int_Real;
      var
        lReg: TRegister;
      begin
        SecondPass(Left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
        Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
        Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FRINTZ,Location.Register,Left.Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.Second_Frac_Real;
      var
        lReg: TRegister;
      begin
        SecondPass(Left);
        hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,true);
        Location_Reset(Location,LOC_MMREGISTER,Def_CGSize(ResultDef));
        Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FRINTZ,Location.Register,Left.Location.Register));
        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg(A_FSUB,Location.Register,Left.Location.Register,Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.Second_Get_Frame;
      begin
        Location_Reset(Location,LOC_CREGISTER,OS_ADDR);
        { this routine is used to get the frame pointer for backtracing
          purposes. current_procinfo.framepointer is set to SP because that one
          is used to access temps. On most platforms these two frame pointers
          are the same, but not on AArch64. }
        Location.Register:=NR_FRAME_POINTER_REG;
      end;


    procedure TAArch64InlineNode.Second_FMA;
      const
        Op : array[false..true,false..true] of TAsmOp =
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
        lParaArray : array[1..3] of TNode;
        lIndex : Integer;
        lNegOperand3,
        lNegProduct : Boolean;
      begin
        lNegOperand3:=false;
        lNegProduct:=false;
        lParaArray[1]:=TCallParaNode(TCallParaNode(TCallParaNode(Parameters).NextPara).NextPara).ParaValue;
        lParaArray[2]:=TCallParaNode(TCallParaNode(Parameters).NextPara).ParaValue;
        lParaArray[3]:=TCallParaNode(Parameters).ParaValue;

        { check if a neg. node can be removed
          this is possible because changing the sign of
          a floating point number does not affect its absolute
          value in any way
        }
        if lParaArray[1].NodeType=unaryminusn then
          begin
            lParaArray[1]:=TUnaryNode(lParaArray[1]).Left;
            { do not release the unused unary minus node, it is kept and release together with the other nodes,
              only no code is generated for it }
            lNegProduct:=not(lNegProduct);
          end;

        if lParaArray[2].NodeType=unaryminusn then
          begin
            lParaArray[2]:=TUnaryNode(lParaArray[2]).Left;
            { do not release the unused unary minus node, it is kept and release together with the other nodes,
              only no code is generated for it }
            lNegProduct:=not(lNegProduct);
          end;

        if lParaArray[3].NodeType=unaryminusn then
          begin
            lParaArray[3]:=TUnaryNode(lParaArray[3]).Left;
            { do not release the unused unary minus node, it is kept and release together with the other nodes,
              only no code is generated for it }
            lNegOperand3:=true;
          end;

         for lIndex:=1 to 3 do
          SecondPass(lParaArray[lIndex]);

        { no memory operand is allowed }
        for lIndex:=1 to 3 do
          begin
            if not(lParaArray[lIndex].Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
              hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,lParaArray[lIndex].Location,lParaArray[lIndex].ResultDef,true);
          end;

        Location_Reset(Location,LOC_MMREGISTER,lParaArray[1].Location.Size);
        Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);

        CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_reg(Op[lNegProduct,lNegOperand3],
          Location.Register,lParaArray[1].Location.Register,lParaArray[2].Location.Register,lParaArray[3].Location.Register));
        cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
      end;


    procedure TAArch64InlineNode.Second_Prefetch;
      var
        lReference : TReference;
        lReg : TRegister;
        lCheckPointerUsed : Boolean;
      begin
        { do not call Checkpointer for left node }
        lCheckPointerUsed:=(cs_checkpointer in CurrentSettings.LocalSwitches);
        if lCheckPointerUsed then
          Node_Change_Local_Switch(Left,cs_checkpointer,false);
        SecondPass(Left);
        if lCheckPointerUsed then
          Node_Change_Local_Switch(Left,cs_checkpointer,false);
       case Left.Location.Loc of
         LOC_CREFERENCE,
         LOC_REFERENCE:
           begin
             lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_ADDR);
             cg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,Left.Location.Reference,lReg);
             Reference_Reset_Base(lReference,lReg,0,Location.Reference.TempPos,Left.Location.Reference.Alignment,Location.Reference.Volatility);
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_ref(A_PRFM,0,lReference));
           end;
         else
           { nothing to prefetch };
       end;
      end;


    function TAArch64InlineNode.First_MinMax : TNode;
      begin
        if Is_Single(ResultDef) or Is_Double(ResultDef) then
          begin
            ExpectLoc:=LOC_MMREGISTER;
            Result:=nil;
            if Needs_Check_For_FPU_Exceptions then
              Include(CurrentProcInfo.Flags,pi_do_call);
          end
        else if Is_32BitInt(ResultDef) or Is_64BitInt(ResultDef) then
          begin
            ExpectLoc:=LOC_REGISTER;
            Result:=nil;
          end
        else
          Result:=inherited First_MinMax;
      end;


    procedure TAArch64InlineNode.Second_MinMax;
      var
        lParaArray : array[1..2] of TNode;
        lIndex: Integer;
        lInstruction: TAICPU;
        lOp: TAsmOp;
        lCondition: TAsmCond;
      begin
        lParaArray[1]:=TCallParaNode(TCallParaNode(Parameters).NextPara).ParaValue;
          lParaArray[2]:=TCallParaNode(Parameters).ParaValue;

        for lIndex:=low(lParaArray) to high(lParaArray) do
           SecondPass(lParaArray[lIndex]);

        if Is_Single(ResultDef) or Is_Double(ResultDef) then
           begin
             { no memory operand is allowed }
             for lIndex:=low(lParaArray) to high(lParaArray) do
               begin
                 if not(lParaArray[lIndex].Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER]) then
                   hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,lParaArray[lIndex].Location,
                     lParaArray[lIndex].ResultDef,true);
               end;

             Location_Reset(Location,LOC_MMREGISTER,lParaArray[1].Location.Size);
             Location.Register:=cg.GetMMRegister(CurrentAsmData.CurrAsmList,Location.Size);

             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_FCMP,
               lParaArray[1].Location.Register,lParaArray[2].Location.Register));

             case InlineNumber of
               in_min_single,
               in_min_double:
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_FCSEL,
                  Location.Register,lParaArray[1].Location.Register,lParaArray[2].Location.Register,C_MI));
               in_max_single,
               in_max_double:
                CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_FCSEL,
                  Location.Register,lParaArray[1].Location.Register,lParaArray[2].Location.Register,C_GT));
               else
                 InternalError(2021121802);
             end;

             cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);
           end
         else if Is_32BitInt(ResultDef) or Is_64BitInt(ResultDef) then
           begin
             { no memory operand is allowed }
             for lIndex:=low(lParaArray) to high(lParaArray) do
               begin
                 if not(lParaArray[lIndex].Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
                   hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lParaArray[lIndex].Location,
                     lParaArray[lIndex].ResultDef,lParaArray[lIndex].ResultDef,true);
               end;

             Location_Reset(Location,LOC_REGISTER,lParaArray[1].Location.Size);
             Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Location.Size);

             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg(A_CMP,
               lParaArray[1].Location.Register,lParaArray[2].Location.Register));

             case InlineNumber of
               in_min_longint,
               in_min_int64:
                 lCondition := C_LT;
               in_min_dword,
               in_min_qword:
                 lCondition := C_LO;
               in_max_longint,
               in_max_int64:
                 lCondition := C_GT;
               in_max_dword,
               in_max_qword:
                 lCondition := C_HI;
               else
                 InternalError(2021121901);
             end;
             CurrentAsmData.CurrAsmList.concat(TAICPU.op_reg_reg_reg_cond(A_CSEL,
               Location.Register,lParaArray[1].Location.Register,lParaArray[2].Location.Register,lCondition));
           end
         else
           InternalError(2021121801);
      end;


begin
  CInlineNode:=TAArch64InlineNode;
end.
