{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Code generation for add nodes on the i386

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
unit n386add;

{$i fpcdefs.inc}

interface

    uses
       node,nadd,cpubase,nx86add;

    type
       TI386AddNode = class(TX86AddNode)
         function Use_Generic_Mul32To64: Boolean; override;
         function Use_Generic_Mul64Bit: Boolean; override;
         procedure Second_AddOrdinal; override;
         procedure Second_Add64Bit;override;
         procedure Second_Cmp64Bit;override;
         procedure Second_Mul(AUnsigned: Boolean);
         procedure Second_Mul64Bit;
       protected
         procedure Set_Mul_Result_Location;
       end;

  implementation

    uses
      GlobType,Systems,
      CUtils,Verbose,Globals,
      symconst,symdef,paramgr,defutil,
      aasmbase,aasmtai,AAsmData,aasmcpu,
      cgbase,ProcInfo,
      ncon,nset,cgutils,tgobj,
      CPUInfo,
      cga,ncgutil,cgobj,cg64f32,cgx86,
      hlcgobj;

{*****************************************************************************
                                use_generic_mul32to64
*****************************************************************************}

    function TI386AddNode.Use_Generic_Mul32To64: Boolean;
    begin
      Result := False;
    end;

    function TI386AddNode.Use_Generic_Mul64Bit: Boolean;
    begin
      Result:=NeedOverflowCheck or
        (cs_opt_size in CurrentSettings.OptimizerSwitches);
    end;

    { handles all unsigned multiplications, and 32->64 bit signed ones.
      32bit-only signed mul is handled by generic codegen }
    procedure TI386AddNode.Second_AddOrdinal;
    var
      lUnsigned: Boolean;
    begin
      lUnsigned:=not(Is_Signed(Left.ResultDef)) or
                not(Is_Signed(Right.ResultDef));
      { use IMUL instead of MUL in case overflow checking is off and we're
        doing a 32->32-bit multiplication }
      if not NeedOverflowCheck and
         not Is_64Bit(ResultDef) then
        lUnsigned:=false;
      if (NodeType=muln) and (lUnsigned or Is_64Bit(ResultDef)) then
        Second_Mul(lUnsigned)
      else
        inherited Second_AddOrdinal;
    end;

{*****************************************************************************
                                Add64bit
*****************************************************************************}

    procedure TI386AddNode.Second_Add64Bit;
      var
        lCGOp         : TOpCG;
        lLowAsmOp,lHighAsmOp    : TAsmOp;
        lOpSize     : TOpSize;
        lRegister,
        lRegister2 : TRegister;
        lOverflowLabel        : TAsmLabel;
        lMultiplyOverflow,
        lUnsigned:Boolean;
        lScratchReg:TRegister;
      begin
        Pass_Left_Right;

        lLowAsmOp:=A_NONE;
        lHighAsmOp:=A_NONE;
        lMultiplyOverflow:=false;
        lOpSize:=S_L;
        lUnsigned:=((Left.ResultDef.typ=orddef) and
                   (TOrdDef(Left.ResultDef).OrdType=u64bit)) or
                  ((Right.ResultDef.typ=orddef) and
                   (TOrdDef(Right.ResultDef).OrdType=u64bit));
        case NodeType of
          addn :
            begin
              lCGOp:=OP_ADD;
              lMultiplyOverflow:=true;
            end;
          subn :
            begin
              lCGOp:=OP_SUB;
              lLowAsmOp:=A_SUB;
              lHighAsmOp:=A_SBB;
              lMultiplyOverflow:=true;
            end;
          xorn:
            lCGOp:=OP_XOR;
          orn:
            lCGOp:=OP_OR;
          andn:
            lCGOp:=OP_AND;
          muln:
            begin
              Second_Mul64Bit;
              exit;
            end
          else
            begin
              { everything should be handled in pass_1 (JM) }
              InternalError(2001090505);
            end;
        end;

        { left and right no register?  }
        { then one must be demanded    }
        if (Left.Location.Loc<>LOC_REGISTER) then
         begin
           if (Right.Location.Loc<>LOC_REGISTER) then
            begin
              lRegister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              lRegister2:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              cg64.A_Load64_Loc_Reg(CurrentAsmData.CurrAsmList,Left.Location,JoinReg64(lRegister,lRegister2));
              Location_Reset(Left.Location,LOC_REGISTER,Left.Location.Size);
              Left.Location.Register64.RegLo:=lRegister;
              Left.Location.Register64.RegHi:=lRegister2;
            end
           else
            begin
              Location_Swap(Left.Location,Right.Location);
              ToggleFlag(nf_swapped);
            end;
         end;

        { at this point, left.location.loc should be LOC_REGISTER }
        if Right.Location.Loc=LOC_REGISTER then
         begin
           if lMultiplyOverflow and NeedOverflowCheck then
             cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

           { when swapped another result register }
           if (NodeType=subn) and (nf_swapped in Flags) then
            begin
              cg64.A_Op64_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,Location.Size,
                Left.Location.Register64,
                Right.Location.Register64);
              Location_Swap(Left.Location,Right.Location);
              ToggleFlag(nf_swapped);
            end
           else
            begin
              cg64.A_Op64_Reg_Reg(CurrentAsmData.CurrAsmList,lCGOp,Location.Size,
                Right.Location.Register64,
                Left.Location.Register64);
            end;
         end
        else
         begin
           { right.location<>LOC_REGISTER }
           if (NodeType=subn) and (nf_swapped in Flags) then
            begin
              lScratchReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              cg64.A_Load64Low_Loc_Reg(CurrentAsmData.CurrAsmList,Right.Location,lScratchReg);
              cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              emit_reg_reg(lLowAsmOp,lOpSize,Left.Location.Register64.RegLo,lScratchReg);
              emit_reg_reg(A_MOV,lOpSize,lScratchReg,Left.Location.Register64.RegLo);
              cg64.A_Load64High_Loc_Reg(CurrentAsmData.CurrAsmList,Right.Location,lScratchReg);
              { the carry flag is still ok }
              emit_reg_reg(lHighAsmOp,lOpSize,Left.Location.Register64.RegHi,lScratchReg);

              { We need to keep the FLAGS register allocated for overflow checks }
              if not lMultiplyOverflow or not NeedOverflowCheck then
                cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

              emit_reg_reg(A_MOV,lOpSize,lScratchReg,Left.Location.Register64.RegHi);
            end
           else
            begin
              if lMultiplyOverflow and NeedOverflowCheck then
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);

              cg64.A_Op64_Loc_Reg(CurrentAsmData.CurrAsmList,lCGOp,Location.Size,Right.Location,
                Left.Location.Register64);
            end;
          Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
         end;

        { only in case of overflow operations }
        { produce overflow code }
        { we must put it here directly, because sign of operation }
        { is in unsigned VAR!!                              }
        if lMultiplyOverflow then
         begin
           if NeedOverflowCheck then
            begin
              CurrentAsmData.getjumplabel(lOverflowLabel);
              if lUnsigned then
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_AE,lOverflowLabel)
              else
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NO,lOverflowLabel);

              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
              cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
              cg.A_Label(CurrentAsmData.CurrAsmList,lOverflowLabel);
            end;
         end;

        Location_Copy(Location,Left.Location);
      end;


    procedure TI386AddNode.Second_Cmp64Bit;
      var
        lTrueLabel,
        lFalseLabel,
        lLabel       : TAsmLabel;
        lReference       : TReference;
        lUnsigned   : Boolean;

      procedure FirstJmp64BitCmp;

        var
           lOldNodeType : TNodeType;

        begin
           { the jump the sequence is a little bit hairy }
           case NodeType of
              ltn,gtn:
                begin
                   if (lLabel<>Location.TrueLabel) then
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,GetResFlags(lUnsigned),Location.TrueLabel);
                   { cheat a little bit for the negative test }
                   ToggleFlag(nf_swapped);
                   if (lLabel<>Location.FalseLabel) then
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,GetResFlags(lUnsigned),Location.FalseLabel);
                   ToggleFlag(nf_swapped);
                end;
              lten,gten:
                begin
                   lOldNodeType:=NodeType;
                   if NodeType=lten then
                     NodeType:=ltn
                   else
                     NodeType:=gtn;
                   if (lLabel<>Location.TrueLabel) then
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,GetResFlags(lUnsigned),Location.TrueLabel);
                   { cheat for the negative test }
                   if NodeType=ltn then
                     NodeType:=gtn
                   else
                     NodeType:=ltn;
                   if (lLabel<>Location.FalseLabel) then
                     cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,GetResFlags(lUnsigned),Location.FalseLabel);
                   NodeType:=lOldNodeType;
                end;
              EqualN:
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NE,Location.FalseLabel);
              unequaln:
                cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NE,Location.TrueLabel);
              else
                InternalError(2019050905);
           end;
        end;

      procedure SecondJmp64BitCmp;

        begin
           { the jump the sequence is a little bit hairy }
           case NodeType of
              ltn,gtn,lten,gten:
                begin
                   { the comparison of the low dword have to be   }
                   {  always unsigned!                            }
                   cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,GetResFlags(true),Location.TrueLabel);
                   cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,Location.FalseLabel);
                end;
              EqualN:
                begin
                   cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NE,Location.FalseLabel);
                   cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,Location.TrueLabel);
                end;
              unequaln:
                begin
                   cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_NE,Location.TrueLabel);
                   cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,Location.FalseLabel);
                end;
              else
                InternalError(2019050904);
           end;
        end;

      begin
        lTrueLabel:=nil;
        lFalseLabel:=nil;
        Pass_Left_Right;

        lUnsigned:=((Left.ResultDef.typ=orddef) and
                   (TOrdDef(Left.ResultDef).OrdType=u64bit)) or
                  ((Right.ResultDef.typ=orddef) and
                   (TOrdDef(Right.ResultDef).OrdType=u64bit));

        { we have LOC_JUMP as result }
        CurrentAsmData.getjumplabel(lTrueLabel);
        CurrentAsmData.getjumplabel(lFalseLabel);
        Location_Reset_Jump(Location,lTrueLabel,lFalseLabel);

        { Relational compares against constants having low dword=0 can omit the
          second compare based on the fact that any unsigned value is >=0 }
        lLabel:=nil;
        if (Right.Location.Loc=LOC_CONSTANT) and
           (lo(Right.Location.Value64)=0) then
          begin
            case GetResFlags(true) of
              F_AE: lLabel:=Location.TrueLabel ;
              F_B:  lLabel:=Location.FalseLabel;
              else
                ;
            end;
          end;

        if (Right.Location.Loc=LOC_CONSTANT) and
           (Left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
          begin
            TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,Left.Location.Reference);
            lReference:=Left.Location.Reference;
            inc(lReference.Offset,4);
            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            emit_const_ref(A_CMP,S_L,aint(hi(Right.Location.Value64)),lReference);
            FirstJmp64BitCmp;
            cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            if Assigned(lLabel) then
              cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel)
            else
              begin
                cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                emit_const_ref(A_CMP,S_L,aint(lo(Right.Location.Value64)),Left.Location.Reference);
                SecondJmp64BitCmp;
                cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              end;
            Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
            exit;
          end;

        { left and right no register?  }
        { then one must be demanded    }
        if not (Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
         begin
           if not (Right.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
             hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,true)
           else
            begin
              Location_Swap(Left.Location,Right.Location);
              ToggleFlag(nf_swapped);
            end;
         end;

        { at this point, left.location.loc should be LOC_[C]REGISTER }
        case Right.Location.Loc of
          LOC_REGISTER,
          LOC_CREGISTER :
            begin
              cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              emit_reg_reg(A_CMP,S_L,Right.Location.Register64.RegHi,Left.Location.Register64.RegHi);
              FirstJmp64BitCmp;
              emit_reg_reg(A_CMP,S_L,Right.Location.Register64.RegLo,Left.Location.Register64.RegLo);
              SecondJmp64BitCmp;
              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
            end;
          LOC_CREFERENCE,
          LOC_REFERENCE :
            begin
              TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,Right.Location.Reference);
              lReference:=Right.Location.Reference;
              inc(lReference.Offset,4);
              cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              emit_ref_reg(A_CMP,S_L,lReference,Left.Location.Register64.RegHi);
              FirstJmp64BitCmp;
              emit_ref_reg(A_CMP,S_L,Right.Location.Reference,Left.Location.Register64.RegLo);
              SecondJmp64BitCmp;
              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
            end;
          LOC_CONSTANT :
            begin
              cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_CMP,S_L,aint(hi(Right.Location.Value64)),Left.Location.Register64.RegHi));
              FirstJmp64BitCmp;
              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
              if Assigned(lLabel) then
                cg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel)
              else
                begin
                  cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                  CurrentAsmData.CurrAsmList.concat(TAICPU.op_const_reg(A_CMP,S_L,aint(lo(Right.Location.Value64)),Left.Location.Register64.RegLo));
                  SecondJmp64BitCmp;
                  cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                end;
            end;
        else
          InternalError(2002032803);
        end;

      end;


{*****************************************************************************
                                x86 MUL
*****************************************************************************}

    procedure TI386AddNode.Set_Mul_Result_Location;
    begin
      Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
      {Free EAX,EDX}
      cg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_EDX);
      if Is_64Bit(ResultDef) then
      begin
        {Allocate a couple of registers and store EDX:EAX into it}
        Location.Register64.RegHi := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
        cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList, OS_INT, OS_INT, NR_EDX, Location.Register64.RegHi);
        cg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_EAX);
        Location.Register64.RegLo := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
        cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList, OS_INT, OS_INT, NR_EAX, Location.Register64.RegLo);
      end
      else
      begin
        {Allocate a new register and store the result in EAX in it.}
        Location.Register:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
        cg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_EAX);
        cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,OS_INT,OS_INT,NR_EAX,Location.Register);
      end;
      Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
      Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
    end;


    procedure TI386AddNode.Second_Mul(AUnsigned: Boolean);

    var lRegister,lRegHigh,lRegLow:TRegister;
        lReference:TReference;
        lUseReference:Boolean;
        lOverflowLabel : TAsmLabel;

    const
      cAsmOps: array[Boolean] of TAsmOp = (A_IMUL, A_MUL);

    begin
      Pass_Left_Right;
      lRegister:=NR_NO;
      Reference_Reset(lReference,sizeof(PInt),[]);

      { Mul supports registers and references, so if not register/reference,
        load the location into a register.
        The variant of IMUL which is capable of doing 32->64 bits has the same restrictions. }
      lUseReference:=false;
      if Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER] then
        lRegister:=Left.Location.Register
      else if Left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
        begin
          TCGX86(cg).make_simple_ref(CurrentAsmData.CurrAsmList,Left.Location.Reference);
          lReference:=Left.Location.Reference;
          lUseReference:=true;
        end
      else
        begin
          { LOC_CONSTANT for example.}
          lRegister:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
          hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,OSUIntType,Left.Location,lRegister);
        end;

      if (CPUX86_HAS_BMI2 in cpu_capabilities[CurrentSettings.CPUType]) and
        (not(NeedOverflowCheck) or
        { 32->64 bit cannot overflow }
        Is_64Bit(ResultDef)) then
        begin
          cg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_EDX);
          hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Right.ResultDef,OSUIntType,Right.Location,NR_EDX);
          lRegLow:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
          lRegHigh:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
          if lUseReference then
            CurrentAsmData.CurrAsmList.concat(TAICPU.Op_ref_reg_reg(A_MULX,S_L,lReference,lRegLow,lRegHigh))
          else
            emit_reg_reg_reg(A_MULX,S_L,lRegister,lRegLow,lRegHigh);
          cg.UngetCPURegister(CurrentAsmData.CurrAsmList,NR_EDX);

          Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
          Location.Register64.RegLo:=lRegLow;

          if Is_64Bit(ResultDef) then
            Location.Register64.RegHi:=lRegHigh;

          Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
          Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
        end
      else
        begin
          { Allocate EAX. }
          cg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_EAX);
          { Load the right value. }
          hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,Right.ResultDef,OSUIntType,Right.Location,NR_EAX);
          { Also allocate EDX, since it is also modified by a mul (JM). }
          cg.GetCPURegister(CurrentAsmData.CurrAsmList,NR_EDX);

          if NeedOverflowCheck then
            cg.A_Reg_Alloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);

          if lUseReference then
            emit_ref(cAsmOps[AUnsigned],S_L,lReference)
          else
            emit_reg(cAsmOps[AUnsigned],S_L,lRegister);
          if NeedOverflowCheck and
            { 32->64 bit cannot overflow }
            (not Is_64Bit(ResultDef)) then
            begin
              CurrentAsmData.getjumplabel(lOverflowLabel);
              cg.A_Jmp_Flags(CurrentAsmData.CurrAsmList,F_AE,lOverflowLabel);
              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList, NR_DEFAULTFLAGS);
              cg.A_Call_Name(CurrentAsmData.CurrAsmList,'FPC_OVERFLOW',false);
              cg.A_Label(CurrentAsmData.CurrAsmList,lOverflowLabel);
            end;
          Set_Mul_Result_Location;
        end;
    end;


    procedure TI386AddNode.Second_Mul64Bit;
    var
      lList: TAsmList;
      lRegister1,lRegister2: TRegister;
    begin
      { 64x64 multiplication yields 128-bit result, but we're only
        interested in its lower 64 bits. This lower part is independent
        of operand signs, and so is the generated code. }
      { pass_left_right already called from second_add64bit }
      lList:=CurrentAsmData.CurrAsmList;
      if Left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
        TCGX86(cg).make_simple_ref(lList,Left.Location.Reference);
      if Right.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
        TCGX86(cg).make_simple_ref(lList,Right.Location.Reference);

      { calculate 32-bit terms lo(right)*hi(left) and hi(left)*lo(right) }
      if (Right.Location.Loc=LOC_CONSTANT) then
        begin
          { if left has side effects, it could be that this code is called with right.location.value64=0,
            see also #40182 }
          if Right.Location.Value64=0 then
            begin
              Location_Reset(Location,LOC_REGISTER,Def_CGSize(ResultDef));
              Location.Register64.RegLo := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              emit_const_reg(A_MOV,S_L,0,Location.Register64.RegLo);
              Location.Register64.RegHi := cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_INT);
              emit_const_reg(A_MOV,S_L,0,Location.Register64.RegHi);
              exit;
            end;

          { Omit zero terms, if any }
          lRegister1:=NR_NO;
          lRegister2:=NR_NO;
          if lo(Right.Location.Value64)<>0 then
            lRegister1:=cg.GetIntRegister(lList,OS_INT);
          if hi(Right.Location.Value64)<>0 then
            lRegister2:=cg.GetIntRegister(lList,OS_INT);

          { Take advantage of 3-operand form of IMUL }
          case Left.Location.Loc of
            LOC_REGISTER,LOC_CREGISTER:
              begin
                if lRegister1<>NR_NO then
                  emit_const_reg_reg(A_IMUL,S_L,LongInt(lo(Right.Location.Value64)),Left.Location.Register64.RegHi,lRegister1);
                if lRegister2<>NR_NO then
                  emit_const_reg_reg(A_IMUL,S_L,LongInt(hi(Right.Location.Value64)),Left.Location.Register64.RegLo,lRegister2);
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                if lRegister2<>NR_NO then
                  lList.concat(TAICPU.op_const_ref_reg(A_IMUL,S_L,LongInt(hi(Right.Location.Value64)),Left.Location.Reference,lRegister2));
                inc(Left.Location.Reference.Offset,4);
                if lRegister1<>NR_NO then
                  lList.concat(TAICPU.op_const_ref_reg(A_IMUL,S_L,LongInt(lo(Right.Location.Value64)),Left.Location.Reference,lRegister1));
                dec(Left.Location.Reference.Offset,4);
              end;
          else
            InternalError(2014011602);
          end;
        end
      else
        begin
          lRegister1:=cg.GetIntRegister(lList,OS_INT);
          lRegister2:=cg.GetIntRegister(lList,OS_INT);
          cg64.A_Load64Low_Loc_Reg(lList,Left.Location,lRegister1);
          cg64.A_Load64High_Loc_Reg(lList,Left.Location,lRegister2);
          case Right.Location.Loc of
            LOC_REGISTER,LOC_CREGISTER:
              begin
                emit_reg_reg(A_IMUL,S_L,Right.Location.Register64.RegHi,lRegister1);
                emit_reg_reg(A_IMUL,S_L,Right.Location.Register64.RegLo,lRegister2);
              end;
            LOC_REFERENCE,LOC_CREFERENCE:
              begin
                emit_ref_reg(A_IMUL,S_L,Right.Location.Reference,lRegister2);
                inc(Right.Location.Reference.Offset,4);
                emit_ref_reg(A_IMUL,S_L,Right.Location.Reference,lRegister1);
                dec(Right.Location.Reference.Offset,4);
              end;
          else
            InternalError(2014011603);
          end;
        end;
      { add hi*lo and lo*hi terms together }
      if (lRegister1<>NR_NO) and (lRegister2<>NR_NO) then
        emit_reg_reg(A_ADD,S_L,lRegister2,lRegister1);

      { load lo(right) into EAX }
      cg.GetCPURegister(lList,NR_EAX);
      cg64.A_Load64Low_Loc_Reg(lList,Right.Location,NR_EAX);

      { multiply EAX by lo(left), producing 64-bit value in EDX:EAX }
      cg.GetCPURegister(lList,NR_EDX);
      if (Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
        emit_reg(A_MUL,S_L,Left.Location.Register64.RegLo)
      else if (Left.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
        emit_ref(A_MUL,S_L,Left.Location.Reference)
      else
        InternalError(2014011604);
      { add previously calculated terms to the high half }
      if (lRegister1<>NR_NO) then
        emit_reg_reg(A_ADD,S_L,lRegister1,NR_EDX)
      else if (lRegister2<>NR_NO) then
        emit_reg_reg(A_ADD,S_L,lRegister2,NR_EDX)
      else
        InternalError(2014011601);

      { Result is now in EDX:EAX. Copy it to virtual registers. }
      Set_Mul_Result_Location;
    end;


begin
   CAddNode:=TI386AddNode;
end.
