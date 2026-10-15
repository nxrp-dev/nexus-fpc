{
    Copyright (c) 1998-2002 by Jonas Maebe, member of the Free Pascal
    Development Team

    This unit implements the ARM64 optimizer object

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

Unit aoptcpu;

{$i fpcdefs.inc}

{$ifdef EXTDEBUG}
{$define DEBUG_AOPTCPU}
{$endif EXTDEBUG}

Interface

    uses
      GlobType, Globals,
      CUtils,
      cgbase, cpubase, aasmtai, aasmcpu,
      aopt, aoptcpub, aoptarm, aoptobj;

    Type
      TCpuAsmOptimizer = class(TARMAsmOptimizer)
        { uses the same constructor as TAopObj }
        function PrePeepHoleOptsCpu(var p: TAI): boolean; override;
        function PeepHoleOptPass1Cpu(var p: TAI): boolean; override;
        function PeepHoleOptPass2Cpu(var p: TAI): boolean; override;
        function PostPeepHoleOptsCpu(var p: TAI): boolean; override;
        function RegLoadedWithNewValue(reg: TRegister; hp: TAI): boolean;override;
        function InstructionLoadsFromReg(const reg: TRegister; const hp: TAI): boolean;override;
        function LookForPostindexedPattern(var p : TAI) : boolean;
      public
        { With these routines, there's optimisation code that's general for all ARM platforms }
        function OptPass1LDR(var p: TAI): Boolean; override;
        function OptPass1STR(var p: TAI): Boolean; override;
      private
        function RemoveSuperfluousFMov(const p: TAI; movp: TAI; const optimizer: string): boolean;
        function OptPass1Shift(var p: TAI): boolean;
        function OptPass1Data(var p: TAI): boolean;
        function OptPass1FData(var p: TAI): Boolean;
        function OptPass1STP(var p: TAI): boolean;
        function OptPass1Mov(var p: TAI): boolean;
        function OptPass1MOVZ(var p: TAI): boolean;
        function OptPass1FMov(var p: TAI): Boolean;
        function OptPass1B(var p: TAI): boolean;
        function OptPass1SXTW(var p: TAI): Boolean;

        function OptPass2CSEL(var p: TAI): Boolean;
        function OptPass2B(var p: TAI): Boolean;
        function OptPass2LDRSTR(var p: TAI): boolean;
        function OptPass2MOV(var p: TAI): Boolean;

        function PostPeepholeOptAND(var p: TAI): Boolean;
        function PostPeepholeOptCMP(var p: TAI): boolean;
        function PostPeepholeOptTST(var p: TAI): Boolean;
      protected
        { Like UpdateUsedRegs, but ignores deallocations }
        class procedure UpdateIntRegsNoDealloc(var AUsedRegs: TAllUsedRegs; p: TAI); static;

        { Attempts to allocate a volatile integer register for use between p and hp,
          using AUsedRegs for the current register usage information.  Returns NR_NO
          if no free register could be found }
        function GetIntRegisterBetween(RegSize: TSubRegister; var AUsedRegs: TAllUsedRegs; p, hp: TAI; DontAlloc: Boolean = False): TRegister;
      End;

Implementation

  uses
    aasmbase,
    aoptbase,
    aoptutils,
    cgutils,
    ProcInfo,
    paramgr,
    Verbose;

{$ifdef DEBUG_AOPTCPU}
    const
      SPeepholeOptimization: shortstring = 'Peephole Optimization: ';
{$else DEBUG_AOPTCPU}
    { Empty strings help the optimizer to remove string concatenations that won't
      ever appear to the user on release builds. [Kit] }
    const
      SPeepholeOptimization = '';
{$endif DEBUG_AOPTCPU}

      MAX_CSEL_INSTRUCTIONS = 8;
      MAX_CSEL_REGISTERS = 30;

    type
      TCSELTrackingState = (tsInvalid, tsSimple, tsDetour, tsBranching,
        tsDouble, tsDoubleBranchSame, tsDoubleBranchDifferent, tsDoubleSecondBranching,
        tsProcessed);

      { For OptPass2Jcc }
      TCSELTracking = object
      private
        CSELScore, ConstCount: LongInt;

        RegWrites: array[0..MAX_CSEL_INSTRUCTIONS*2 - 1] of TRegister;

        ConstRegs: array[0..MAX_CSEL_REGISTERS - 1] of TRegister;
        ConstVals: array[0..MAX_CSEL_REGISTERS - 1] of TCGInt;
        ConstSizes: array[0..MAX_CSEL_REGISTERS - 1] of TSubRegister; { May not match ConstRegs if one is shared over multiple CSELs. }
        ConstMovs: array[0..MAX_CSEL_REGISTERS - 1] of TAI; { Location of initialisation instruction }

        ConstWriteSizes: array[0..first_int_imreg - 1] of TSubRegister; { Largest size of register written. }

        fOptimizer: TCpuAsmOptimizer;

        fLabel: TAsmSymbol;

        fInsertionPoint,
        fCondition,
        fInitialJump,
        fFirstMovBlock,
        fFirstMovBlockStop,
        fSecondJump,
        fThirdJump,
        fSecondMovBlock,
        fSecondMovBlockStop,
        fMidLabel,
        fEndLabel,
        fAllocationRange: TAI;

        fState: TCSELTrackingState;

        function TryCSELConst(p, start, stop: TAI; var Count: LongInt): Boolean;
        function InitialiseBlock(BlockStart, OneBeforeBlock: TAI; out BlockStop: TAI; out EndJump: TAI): Boolean;
        function AnalyseMOVBlock(BlockStart, BlockStop, SearchStart: TAI): LongInt;
      public
        RegisterTracking: TAllUsedRegs;
        constructor Init(Optimizer: TCpuAsmOptimizer; var p_initialjump, p_initialmov: TAI; var AFirstLabel: TAsmLabel);
        destructor Done;
        procedure Process(out new_p: TAI);
        property State: TCSELTrackingState read fState;
      end;

      PCSELTracking = ^TCSELTracking;

  function CanBeCond(p : TAI) : boolean;
    begin
      result:=(p.typ=ait_instruction) and (TAICPU(p).condition=C_None);
    end;


  function TCpuAsmOptimizer.RegLoadedWithNewValue(reg: TRegister; hp: TAI): boolean;
    var
      p: TAICPU absolute hp; { Implicit typecast }
      i: integer;
    begin
      Result := false;
      if not ((Assigned(hp)) and (hp.typ = ait_instruction)) then
        exit;

      p := TAICPU(hp);
      case p.opcode of
        { These operations do not write into a register at all

          LDR/STR with post/pre-indexed operations do not need special treatment
          because post-/preindexed does not mean that a register
          is loaded with a new value, it is only modified }
        A_STR, A_STP, A_CMP, A_CMN, A_TST, A_B, A_BL, A_MSR, A_FCMP:
          exit;
        else
          ;
      end;

      for i:=0 to p.ops-1 do
        begin
          case p.spilling_get_operation_type(i) of
            operand_read,
            operand_readwrite:
              if RegInOp(reg,p.oper[i]^) then
                { Depends on register's previous value }
                exit;

            operand_write:
              case p.oper[i]^.typ of
                top_reg,
                top_indexedreg:
                  if SuperRegistersEqual(p.oper[i]^.reg,reg) then
                    Result:=True;
                top_regset:
                  if RegInOp(reg,p.oper[i]^) then
                    Result:=True;
                top_ref:
                  { With a reference, if the register is pre- or post-indexed,
                    it's a modified value, not a new value }
                  if (TAICPU(p).oper[i]^.ref^.addressmode in [AM_PREINDEXED,AM_POSTINDEXED]) and
                    (TAICPU(p).oper[i]^.ref^.base=reg) then
                    begin
                      Result:=False;
                      Exit;
                    end;
                else
                  ;
              end;
          end;
        end;
    end;


  function TCpuAsmOptimizer.InstructionLoadsFromReg(const reg: TRegister; const hp: TAI): boolean;
    var
      p: TAICPU;
      i: LongInt;
    begin
      instructionLoadsFromReg := false;
      if not (Assigned(hp) and (hp.typ = ait_instruction)) then
        exit;
      p:=TAICPU(hp);

      i:=1;

      { Start on oper[0]? }
      if TAICPU(hp).spilling_get_operation_type(0) in [operand_read, operand_readwrite] then
        i:=0;

      while(i<p.ops) do
        begin
          case p.oper[I]^.typ of
            top_reg:
              Result := (p.oper[I]^.reg = reg);
            top_ref:
              Result :=
                (p.oper[I]^.ref^.base = reg) or
                (p.oper[I]^.ref^.index = reg);
            else
              ;
          end;
          { Bailout if we found something }
          if Result then
            exit;
          Inc(I);
        end;
    end;

  {
    optimize
      ldr/str regX,[reg1]
      ...
      add/sub reg1,reg1,regY/const

      into

      ldr/str regX,[reg1], regY/const
  }
  function TCpuAsmOptimizer.LookForPostindexedPattern(var p: TAI) : boolean;
    var
      hp1 : TAI;
    begin
      Result:=false;
      if (TAICPU(p).oper[1]^.typ = top_ref) and
        (TAICPU(p).oper[1]^.ref^.addressmode=AM_OFFSET) and
        (TAICPU(p).oper[1]^.ref^.index=NR_NO) and
        (TAICPU(p).oper[1]^.ref^.offset=0) and
        GetNextInstructionUsingReg(p, hp1, TAICPU(p).oper[1]^.ref^.base) and
        { we cannot check NR_DEFAULTFLAGS for modification yet so don't allow a condition }
        MatchInstruction(hp1, [A_ADD, A_SUB], [PF_None]) and
        (TAICPU(hp1).oper[0]^.reg=TAICPU(p).oper[1]^.ref^.base) and
        (TAICPU(hp1).oper[1]^.reg=TAICPU(p).oper[1]^.ref^.base) and
        (
         { valid offset? }
         (TAICPU(hp1).oper[2]^.typ=top_const) and
         (TAICPU(hp1).oper[2]^.val>=-256) and
         (abs(TAICPU(hp1).oper[2]^.val)<256)
        ) and
        { don't apply the optimization if the base register is loaded }
        (getsupreg(TAICPU(p).oper[0]^.reg)<>getsupreg(TAICPU(p).oper[1]^.ref^.base)) and
        not(RegModifiedBetween(TAICPU(hp1).oper[0]^.reg,p,hp1)) and
        not(RegModifiedBetween(TAICPU(hp1).oper[2]^.reg,p,hp1)) then
        begin
          if TAICPU(p).opcode = A_LDR then
            DebugMsg(SPeepholeOptimization + 'LdrAdd/Sub2Ldr Postindex done', p)
          else
            DebugMsg(SPeepholeOptimization + 'StrAdd/Sub2Str Postindex done', p);

          TAICPU(p).oper[1]^.ref^.addressmode:=AM_POSTINDEXED;
          if TAICPU(hp1).opcode=A_ADD then
            TAICPU(p).oper[1]^.ref^.offset:=TAICPU(hp1).oper[2]^.val
          else
            TAICPU(p).oper[1]^.ref^.offset:=-TAICPU(hp1).oper[2]^.val;
          asml.Remove(hp1);
          hp1.Free;
          Result:=true;
        end;
    end;


  function TCpuAsmOptimizer.RemoveSuperfluousFMov(const p: TAI; movp: TAI; const optimizer: string):boolean;
    var
      alloc,
      dealloc : TAIRegAlloc;
      hp1 : TAI;
    begin
      Result:=false;
      if ((MatchInstruction(movp, A_FMOV, [TAICPU(p).condition], [TAICPU(p).oppostfix]) and
           ((getregtype(TAICPU(movp).oper[0]^.reg)=R_MMREGISTER) { or (taicpu(p).opcode in [A_LDUR])})
          ) { or
          (((taicpu(p).oppostfix in [PF_F64F32,PF_F64S16,PF_F64S32,PF_F64U16,PF_F64U32]) or (getsubreg(taicpu(p).oper[0]^.reg)=R_SUBFD)) and MatchInstruction(movp, A_VMOV, [taicpu(p).condition], [PF_F64])) or
          (((taicpu(p).oppostfix in [PF_F32F64,PF_F32S16,PF_F32S32,PF_F32U16,PF_F32U32]) or (getsubreg(taicpu(p).oper[0]^.reg)=R_SUBFS)) and MatchInstruction(movp, A_VMOV, [taicpu(p).condition], [PF_F32])) }
         ) and
         (TAICPU(movp).ops=2) and
         MatchOperand(TAICPU(movp).oper[1]^, TAICPU(p).oper[0]^.reg) and
         { the destination register of the mov might not be used between p and movp }
         not(RegUsedBetween(TAICPU(movp).oper[0]^.reg,p,movp)) and
         { Take care to only do this for instructions which REALLY load to the first register.
           Otherwise
             str reg0, [reg1]
             fmov reg2, reg0
           will be optimized to
             str reg2, [reg1]
         }
         RegLoadedWithNewValue(TAICPU(p).oper[0]^.reg, p) then
        begin
          dealloc:=FindRegDeAlloc(TAICPU(p).oper[0]^.reg,TAI(movp.Next));
          if Assigned(dealloc) then
            begin
              DebugMsg(SPeepholeOptimization + optimizer+' removed superfluous vmov', movp);
              result:=true;

              { taicpu(p).oper[0]^.reg is not used anymore, try to find its allocation
                and remove it if possible }
              asml.Remove(dealloc);
              alloc:=FindRegAllocBackward(TAICPU(p).oper[0]^.reg,TAI(p.previous));
              if Assigned(alloc) then
                begin
                  asml.Remove(alloc);
                  alloc.free;
                  dealloc.free;
                end
              else
                asml.InsertAfter(dealloc,p);

              { try to move the allocation of the target register }
              GetLastInstruction(movp,hp1);
              alloc:=FindRegAlloc(TAICPU(movp).oper[0]^.reg,TAI(hp1.Next));
              if Assigned(alloc) then
                begin
                  asml.Remove(alloc);
                  asml.InsertBefore(alloc,p);
                  { adjust used regs }
                  IncludeRegInUsedRegs(TAICPU(movp).oper[0]^.reg,UsedRegs);
                end;

              { change
                  vldr reg0,[reg1]
                  vmov reg2,reg0
                into
                  ldr reg2,[reg1]

                if reg2 is an int register
              if (taicpu(p).opcode=A_VLDR) and (getregtype(taicpu(movp).oper[0]^.reg)=R_INTREGISTER) then
                taicpu(p).opcode:=A_LDR;
              }

              { finally get rid of the mov }
              TAICPU(p).loadreg(0,TAICPU(movp).oper[0]^.reg);
              asml.remove(movp);
              movp.free;
            end;
        end;
    end;


  function TCpuAsmOptimizer.OptPass1LDR(var p: TAI): Boolean;
    var
      hp1: TAI;
    begin
      Result := False;
      if inherited OptPass1LDR(p) or
        LookForPostindexedPattern(p) then
        Exit(True)
      else if (TAICPU(p).oppostfix in [PF_B,PF_SB,PF_H,PF_SH,PF_None]) and
        GetNextInstructionUsingReg(p, hp1, TAICPU(p).oper[0]^.reg) and
        RemoveSuperfluousMove(p, hp1, 'Ldr<Postfix>Mov2Ldr<Postfix>') then
        Exit(true);
    end;


  function TCpuAsmOptimizer.OptPass1STR(var p: TAI): Boolean;
    begin
      Result := False;
      if inherited OptPass1STR(p) or
        LookForPostindexedPattern(p) then
        Exit(True);

      if getsupreg(TAICPU(p).oper[0]^.reg) = RS_WZR then
        Result := TryConstMerge(p, nil);
    end;


  function TCpuAsmOptimizer.OptPass1Shift(var p : TAI): boolean;
    var
      hp1,hp2: TAI;
      I2, I: Integer;
      shifterop: TShifterOp;
    begin
      Result:=false;
      { This folds shifterops into following instructions
        <shiftop> r0, r1, #imm
        <op> r2, r3, r0

        to

        <op> r2, r3, r1, <shiftop> #imm
      }
      { do not handle ROR yet, only part of the instructions below support ROR as shifter operand }
      if MatchInstruction(p,[A_LSL, A_LSR, A_ASR{, A_ROR}],[PF_None]) and
         MatchOpType(TAICPU(p),top_reg,top_reg,top_const) and
         GetNextInstructionUsingReg(p, hp1, TAICPU(p).oper[0]^.reg) and
         MatchInstruction(hp1, [A_ADD, A_AND, A_BIC, A_CMP, A_CMN,
                                A_EON, A_EOR, A_NEG, A_ORN, A_ORR,
                                A_SUB, A_TST], [PF_None]) and
         RegEndOfLife(TAICPU(p).oper[0]^.reg, TAICPU(hp1)) and
         (TAICPU(hp1).ops >= 2) and
         { Currently we can't fold into another shifterop }
         (TAICPU(hp1).oper[TAICPU(hp1).ops-1]^.typ = top_reg) and
         { SP does not work completely with shifted registers, as I didn't find the exact rules,
           we do not operate on SP }
         (TAICPU(hp1).oper[0]^.reg<>NR_SP) and
         (TAICPU(hp1).oper[1]^.reg<>NR_SP) and
         (TAICPU(hp1).oper[TAICPU(hp1).ops-1]^.reg<>NR_SP) and
         { reg1 might not be modified in between }
         not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) and
         (
           { Only ONE of the two src operands is allowed to match }
           MatchOperand(TAICPU(p).oper[0]^, TAICPU(hp1).oper[TAICPU(hp1).ops-2]^) xor
           MatchOperand(TAICPU(p).oper[0]^, TAICPU(hp1).oper[TAICPU(hp1).ops-1]^)
         ) and
         { for SUB, the last operand must match, there is no RSB on AArch64 }
         ((TAICPU(hp1).opcode<>A_SUB) or
          MatchOperand(TAICPU(p).oper[0]^, TAICPU(hp1).oper[TAICPU(hp1).ops-1]^)) then
        begin
          { for the two operand instructions, start also at the second operand as they are not always commutative
            (depends on the flags tested laster on) and thus the operands cannot swapped }
          I2:=1;
          for I:=I2 to TAICPU(hp1).ops-1 do
            if MatchOperand(TAICPU(p).oper[0]^, TAICPU(hp1).oper[I]^.reg) then
              begin
                { If the parameter matched on the second op from the RIGHT
                  we have to switch the parameters, this will not happen for CMP
                  were we're only evaluating the most right parameter
                }
                shifterop_reset(shifterop);
                case TAICPU(p).opcode of
                  A_LSL:
                    shifterop.shiftmode:=SM_LSL;
                  A_ROR:
                    shifterop.shiftmode:=SM_ROR;
                  A_LSR:
                    shifterop.shiftmode:=SM_LSR;
                  A_ASR:
                    shifterop.shiftmode:=SM_ASR;
                  else
                    InternalError(2019090401);
                end;
                shifterop.shiftimm:=TAICPU(p).oper[2]^.val;

                if I <> TAICPU(hp1).ops-1 then
                  begin
                    if TAICPU(hp1).ops = 3 then
                      hp2:=TAICPU.op_reg_reg_reg_shifterop(TAICPU(hp1).opcode,
                           TAICPU(hp1).oper[0]^.reg, TAICPU(hp1).oper[2]^.reg,
                           TAICPU(p).oper[1]^.reg, shifterop)
                    else
                      hp2:=TAICPU.op_reg_reg_shifterop(TAICPU(hp1).opcode,
                           TAICPU(hp1).oper[0]^.reg, TAICPU(p).oper[1]^.reg,
                           shifterop);
                  end
                else
                  if TAICPU(hp1).ops = 3 then
                    hp2:=TAICPU.op_reg_reg_reg_shifterop(TAICPU(hp1).opcode,
                         TAICPU(hp1).oper[0]^.reg, TAICPU(hp1).oper[1]^.reg,
                         TAICPU(p).oper[1]^.reg,shifterop)
                  else
                    hp2:=TAICPU.op_reg_reg_shifterop(TAICPU(hp1).opcode,
                         TAICPU(hp1).oper[0]^.reg, TAICPU(p).oper[1]^.reg,
                         shifterop);

                { Make sure the register used in the shifting is tracked all
                  the way through, otherwise it may become deallocated while
                  it's still live and cause incorrect optimisations later }
                if (TAICPU(hp1).oper[0]^.reg <> TAICPU(p).oper[1]^.reg) then
                  begin
                    TransferUsedRegs(TmpUsedRegs);
                    UpdateUsedRegs(TmpUsedRegs, TAI(p.Next));
                    ALlocRegBetween(TAICPU(p).oper[1]^.reg, p, hp1, TmpUsedRegs);
                  end;

                TAICPU(hp2).fileinfo:=TAICPU(hp1).fileinfo;
                asml.insertbefore(hp2, hp1);

                RemoveInstruction(hp1);
                RemoveCurrentp(p);

                DebugMsg(SPeepholeOptimization + 'FoldShiftProcess done', hp2);
                Result:=true;
                break;
              end;
        end
      else if MatchInstruction(p,[A_LSL, A_LSR, A_ASR,A_ROR],[PF_None]) and
        GetNextInstructionUsingReg(p, hp1, TAICPU(p).oper[0]^.reg) and
        RemoveSuperfluousMove(p, hp1, 'ShiftMov2Shift') then
        Result:=true;
    end;


  function TCpuAsmOptimizer.OptPass1Data(var p : TAI): boolean;
    var
      hp1: TAI;
    begin
      Result := GetNextInstructionUsingReg(p, hp1, TAICPU(p).oper[0]^.reg) and
        RemoveSuperfluousMove(p, hp1, 'DataMov2Data');
    end;


  function TCpuAsmOptimizer.OptPass1FData(var p: TAI): Boolean;
    var
      hp1: TAI;
    begin
      Result := GetNextInstructionUsingReg(p, hp1, TAICPU(p).oper[0]^.reg) and
        RemoveSuperfluousFMov(p, hp1, 'FOpFMov2FOp');
    end;


  function TCpuAsmOptimizer.OptPass1STP(var p : TAI): boolean;
    var
      hp1, hp2, hp3, hp4, tmp1 : TAI;
    begin
      Result:=false;
      {
        change

	stp	x29,x30,[sp, #-16]!
	mov	x29,sp
	bl	abc
	ldp	x29,x30,[sp], #16
	ret

        into

        b         abc
      }
      if MatchInstruction(p, A_STP, [C_None], [PF_None]) and
        MatchOpType(TAICPU(p),top_reg,top_reg,top_ref) and
        (TAICPU(p).oper[0]^.reg = NR_X29) and
        (TAICPU(p).oper[1]^.reg = NR_X30) and
        (TAICPU(p).oper[2]^.ref^.base=NR_STACK_POINTER_REG) and
        (TAICPU(p).oper[2]^.ref^.index=NR_NO) and
        (TAICPU(p).oper[2]^.ref^.offset=-16) and
        (TAICPU(p).oper[2]^.ref^.addressmode=AM_PREINDEXED) and

        GetNextInstruction(p, hp1) and
        MatchInstruction(hp1, A_MOV, [C_None], [PF_NONE]) and
        MatchOperand(TAICPU(hp1).oper[0]^,TAICPU(p).oper[0]^) and
        (TAICPU(hp1).oper[1]^.typ = top_reg) and
        (TAICPU(hp1).oper[1]^.reg = NR_STACK_POINTER_REG) and

        GetNextInstruction(hp1, hp2) and
        SkipEntryExitMarker(hp2, hp2) and
        MatchInstruction(hp2, A_BL, [C_None], [PF_NONE]) and
        (TAICPU(hp2).oper[0]^.typ = top_ref) and

        GetNextInstruction(hp2, hp3) and
        SkipEntryExitMarker(hp3, hp3) and
        MatchInstruction(hp3, A_LDP, [C_None], [PF_NONE]) and
        MatchOpType(TAICPU(hp3),top_reg,top_reg,top_ref) and
        (TAICPU(hp3).oper[0]^.reg = NR_X29) and
        (TAICPU(hp3).oper[1]^.reg = NR_X30) and
        (TAICPU(hp3).oper[2]^.ref^.base=NR_STACK_POINTER_REG) and
        (TAICPU(hp3).oper[2]^.ref^.index=NR_NO) and
        (TAICPU(hp3).oper[2]^.ref^.offset=16) and
        (TAICPU(hp3).oper[2]^.ref^.addressmode=AM_POSTINDEXED) and

        GetNextInstruction(hp3, hp4) and
        MatchInstruction(hp4, A_RET, [C_None], [PF_None]) and
        (TAICPU(hp4).ops = 0) then
        begin
          { remove the SEH instruction for the STP FP,LR }
          if GetNextInstruction(p,tmp1,[ait_seh_directive]) and
              (tmp1.typ=ait_seh_directive) and
              (TAISEHDirective(tmp1).kind=ash_savefplr_x) then
            begin
              asml.Remove(tmp1);
              tmp1.free;
            end;
          { remove the SEH instruction for the MOV FP,SP }
          if GetNextInstruction(hp1,tmp1,[ait_seh_directive]) and
              (tmp1.typ=ait_seh_directive) and
              (TAISEHDirective(tmp1).kind=ash_setfp) then
            begin
              asml.Remove(tmp1);
              tmp1.free;
            end;
          asml.Remove(p);
          asml.Remove(hp1);
          asml.Remove(hp3);
          asml.Remove(hp4);
          TAICPU(hp2).opcode:=A_B;
          p.free;
          hp1.free;
          hp3.free;
          hp4.free;
          p:=hp2;
          DebugMsg(SPeepholeOptimization + 'Bl2B done', p);
          Result:=true;
        end;
    end;


  function TCpuAsmOptimizer.OptPass1Mov(var p : TAI): boolean;
    var
      hp1: TAI;
      so: TShifterOp;
    begin
     Result:=false;
     if MatchOperand(TAICPU(p).oper[0]^,TAICPU(p).oper[1]^) and
       (TAICPU(p).oppostfix=PF_None) then
       begin
         RemoveCurrentP(p);
         DebugMsg(SPeepholeOptimization + 'Mov2None done', p);
         Result:=true;
       end


     else if (TAICPU(p).ops=2) and
       (getsubreg(TAICPU(p).oper[0]^.reg)=R_SUBD) and
       GetNextInstruction(p, hp1) and
       { Faster to get it out of the way than go through MatchInstruction }
       (hp1.typ=ait_instruction) and
       (TAICPU(hp1).ops=3) and
       MatchInstruction(hp1,[A_ADD,A_SUB],[TAICPU(p).condition], [PF_None,PF_S]) and
       (getsubreg(TAICPU(hp1).oper[2]^.reg)=R_SUBQ) and
       (getsupreg(TAICPU(p).oper[0]^.reg)=getsupreg(TAICPU(hp1).oper[2]^.reg)) and
       RegEndOfLife(TAICPU(hp1).oper[2]^.reg,TAICPU(hp1)) then
       begin
         DebugMsg(SPeepholeOptimization + 'MovOp2AddUtxw 1 done', p);
         shifterop_reset(so);
         so.shiftmode:=SM_UXTW;
         TAICPU(hp1).ops:=4;
         TAICPU(hp1).loadreg(2,TAICPU(p).oper[1]^.reg);
         TAICPU(hp1).loadshifterop(3,so);
         RemoveCurrentP(p);
         Result:=true;
         exit;
       end
     {
       optimize
       mov rX, yyyy
       ....
     }
     else if GetNextInstructionUsingReg(p, hp1, TAICPU(p).oper[0]^.reg) then
       begin
         if RemoveSuperfluousMove(p, hp1, 'MovMov2Mov') then
           Result:=true
         else if (TAICPU(p).ops = 2) and
           (TAI(hp1).typ = ait_instruction) and
           RedundantMovProcess(p,hp1) then
           Result:=true
       end;
    end;


  function TCpuAsmOptimizer.OptPass1MOVZ(var p: TAI): boolean;
    var
      hp1: TAI;
      TargetReg: TRegister;
    begin
      Result := False;
      hp1 := nil;

      TargetReg := TAICPU(p).oper[0]^.reg;
      if (TAICPU(p).oppostfix = PF_None) and (TAICPU(p).condition = C_None) then
        begin
          if
            { Check next instruction first so hp1 gets set to something, then
              if it remains nil, we know for sure that there's no valid next
              instruction. }
            not GetNextInstruction(p, hp1) or
            { MOVZ and MOVK/MOVN instructions undergo macro-fusion. }
            not MatchInstruction(hp1, [A_MOVK, A_MOVN], [C_None], [PF_None]) or
            (TAICPU(hp1).oper[0]^.reg <> TargetReg) then
            begin
              if (TAICPU(p).oper[1]^.val = 0) then
                begin
                  { Change;
                      movz reg,#0
                      (no movk or movn)
                    To:
                      mov  reg,xzr (or wzr)

                    Easier to perform other optimisations with registers
                  }
                  DebugMsg(SPeepholeOptimization + 'Movz0ToMovZeroReg', p);

                  { Convert TargetReg to the correctly-sized zero register }
                  setsupreg(TargetReg, RS_XZR);

                  TAICPU(p).opcode := A_MOV;
                  TAICPU(p).loadreg(1, TargetReg);
                  Result := True;
                  Exit;
                end;
            end;
          {
             remove the second Movz from

             movz reg,...
             movz reg,...
          }
          if GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) and
            MatchInstruction(hp1,A_MOVZ,[C_None],[PF_none]) and
            MatchOperand(TAICPU(p).oper[0]^,TAICPU(hp1).oper[0]^) then
            begin
              DebugMsg(SPeepholeOptimization + 'MovzMovz2Movz', p);
              RemoveCurrentP(p);
              Result:=true;
              exit;
            end;
        end;

      if (getsupreg(TargetReg) <= RS_X30) and { Mostly to play safe }
        GetNextInstructionUsingReg(p, hp1, TargetReg) and
        (hp1.typ = ait_instruction) then
        begin
          case TAICPU(hp1).opcode of
{$ifdef AARCH64}
            A_MOVK:
              { Try to avoid too much unnecessary processing by checking to see
                if the register is 32-bit }
              if (getsubreg(TargetReg) = R_SUBD) and
                (TAICPU(hp1).oper[0]^.reg = TargetReg) and
                TryConstMerge(p, hp1) then
                begin
                  Result := True;
                  Exit;
                end;
{$endif AARCH64}
            A_STR:
              {
                With sequences such as:
                  movz  w0,x
                  strb  w0,[sp, #ofs]
                  movz  w0,y
                  strb  w0,[sp, #ofs+1]

                Merge the constants to:
                  movz  w0,x + (y shl 8)
                  strw  w0,[sp, #ofs]

                Only use the stack pointer or frame pointer and an even offset though
                to guarantee alignment
              }
              if TryConstMerge(p, hp1) then
                begin
                  Result := True;
                  Exit;
                end;
            else
              ;
          end;
        end;
    end;


  function TCpuAsmOptimizer.OptPass1FMov(var p: TAI): Boolean;
    var
      hp1: TAI;
      alloc, dealloc: TAIRegAlloc;
    begin
      {
        change
        fmov reg0,reg1
        fmov reg1,reg0
        into
        fmov reg0,reg1
      }
      Result := False;
      while GetNextInstruction(p, hp1) and
        MatchInstruction(hp1, A_FMOV, [TAICPU(p).condition], [TAICPU(p).oppostfix]) and
        MatchOperand(TAICPU(p).oper[0]^, TAICPU(hp1).oper[1]^) and
        MatchOperand(TAICPU(p).oper[1]^, TAICPU(hp1).oper[0]^) do
        begin
          asml.Remove(hp1);
          hp1.free;
          DebugMsg(SPeepholeOptimization + 'FMovFMov2FMov 1 done', p);
          Result:=true;
        end;

      { change
          fmov reg0,const
          fmov reg1,reg0
          dealloc reg0
          into
          fmov reg1,const
      }
      if MatchOpType(TAICPU(p),top_reg,top_realconst) and
        GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) and
        (not RegModifiedBetween(TAICPU(p).oper[1]^.reg, p, hp1)) and
        MatchInstruction(hp1,A_FMOV,[TAICPU(p).condition],[TAICPU(p).oppostfix]) and
        MatchOpType(TAICPU(hp1),top_reg,top_reg) and
        MatchOperand(TAICPU(p).oper[0]^,TAICPU(hp1).oper[1]^.reg) and
        (not RegModifiedByInstruction(TAICPU(p).oper[0]^.reg, hp1)) and
        Assigned(FindRegDeAlloc(TAICPU(p).oper[0]^.reg,TAI(hp1.Next)))
        then
        begin
          DebugMsg('Peephole FMovFMov2FMov 2 done', p);

          TAICPU(hp1).loadrealconst(1,TAICPU(p).oper[1]^.val_real);

          alloc:=FindRegAllocBackward(TAICPU(p).oper[0]^.reg,TAI(p.Previous));
          dealloc:=FindRegDeAlloc(TAICPU(p).oper[0]^.reg,TAI(hp1.Next));

          if Assigned(alloc) and Assigned(dealloc) then
            begin
              asml.Remove(alloc);
              alloc.Free;
              asml.Remove(dealloc);
              dealloc.Free;
            end;

          { p will be removed, update used register as we continue
            with the next instruction after p }

          result:=RemoveCurrentP(p);
        end;

      { not enabled as apparently not happening
      if MatchOpType(taicpu(p),top_reg,top_reg) and
        GetNextInstructionUsingReg(p,hp1,taicpu(p).oper[0]^.reg) and
        MatchInstruction(hp1, [A_FSUB,A_FADD,A_FNEG,A_FMUL,A_FSQRT,A_FDIV,A_FABS], [PF_None]) and
        (MatchOperand(taicpu(p).oper[0]^,taicpu(hp1).oper[1]^) or
         ((taicpu(hp1).ops=3) and MatchOperand(taicpu(p).oper[0]^,taicpu(hp1).oper[2]^))
        ) and
        RegEndofLife(taicpu(p).oper[0]^.reg,taicpu(hp1)) and
        not(RegUsedBetween(taicpu(p).oper[0]^.reg,p,hp1)) then
        begin
          DebugMsg(SPeepholeOptimization + 'FMovFOp2FOp done', hp1);
          AllocRegBetween(taicpu(hp1).oper[1]^.reg,p,hp1,UsedRegs);
          if MatchOperand(taicpu(p).oper[0]^,taicpu(hp1).oper[1]^) then
            taicpu(hp1).oper[1]^.reg:=taicpu(p).oper[1]^.reg;
          if (taicpu(hp1).ops=3) and MatchOperand(taicpu(p).oper[0]^,taicpu(hp1).oper[2]^) then
            taicpu(hp1).oper[2]^.reg:=taicpu(p).oper[1]^.reg;
          RemoveCurrentP(p);
          Result:=true;
          exit;
        end;
      }
    end;


  function TCpuAsmOptimizer.OptPass1SXTW(var p : TAI) : Boolean;
    var
      hp1: TAI;
      GetNextInstructionUsingReg_hp1: Boolean;
    begin
      Result:=false;
      if GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) then
        begin
          {
            change
            sxtw reg2,reg1
            str reg2,[...]
            dealloc reg2
            to
            str reg1,[...]
          }
          if MatchInstruction(p, TAICPU(p).opcode, [C_None], [PF_None]) and
            (TAICPU(p).ops=2) and
            MatchInstruction(hp1, A_STR, [C_None], [PF_None]) and
            (getsubreg(TAICPU(hp1).oper[0]^.reg)=R_SUBD) and
            RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
            { the reference in strb might not use reg2 }
            not(RegInRef(TAICPU(p).oper[0]^.reg,TAICPU(hp1).oper[1]^.ref^)) and
            { reg1 might not be modified in between }
            not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
            begin
              DebugMsg('Peephole SXTHStr2Str done', p);
              TAICPU(hp1).loadReg(0,TAICPU(p).oper[1]^.reg);
              result:=RemoveCurrentP(p);
            end
          {
            change
            sxtw reg2,reg1
            sxtw reg3,reg2
            dealloc reg2
            to
            sxtw reg3,reg1
          }
          else if MatchInstruction(p, A_SXTW, [C_None], [PF_None]) and
            (TAICPU(p).ops=2) and
            MatchInstruction(hp1, A_SXTW, [C_None], [PF_None]) and
            (TAICPU(hp1).ops=2) and
            MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
            RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
            { reg1 might not be modified in between }
            not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
            begin
              DebugMsg('Peephole SxtwSxtw2Sxtw done', p);
              AllocRegBetween(TAICPU(p).oper[1]^.reg,p,hp1,UsedRegs);
              TAICPU(hp1).opcode:=A_SXTW;
              TAICPU(hp1).loadReg(1,TAICPU(p).oper[1]^.reg);
              result:=RemoveCurrentP(p);
            end
          else if USxtOp2Op(p,hp1,SM_SXTW) then
            Result:=true
          else if RemoveSuperfluousMove(p, hp1, 'SxtwMov2Data') then
            Result:=true;
        end;
    end;


  function TCpuAsmOptimizer.OptPass1B(var p: TAI): boolean;
    var
      hp1, hp2, hp3, hp4, hp5: TAI;
      Invert: Boolean;
    begin
      Result := False;
      {
          convert
          b<c>  .L1
          movz  reg,#1`
          b     .L2
        .L1
          movz  reg,#0 (or mov reg,xzr)
        .L2

        into
          cset  reg,<not(c)>

        Also do the same if the constants are reversed, instead converting it to:
          cset  reg,<c>
      }

      if (TAICPU(p).condition <> C_None) and
        (TAICPU(p).oper[0]^.typ = top_ref) and
        GetNextInstruction(p, hp1) and
        { Check individually instead of using MatchInstruction in order to save time }
        (hp1.typ = ait_instruction) and
        (TAICPU(hp1).condition = C_None) and
        (TAICPU(hp1).oppostfix = PF_None) and
        (TAICPU(hp1).ops = 2) and
        (
          (
            (TAICPU(hp1).opcode = A_MOVZ) and
            (TAICPU(hp1).oper[1]^.val in [0, 1])
          ) or
          (
            (TAICPU(hp1).opcode = A_MOV) and
            (getsupreg(TAICPU(hp1).oper[1]^.reg) = RS_XZR)
          )
        ) and
        GetNextInstruction(hp1, hp2) and
        MatchInstruction(hp2, A_B, [PF_None]) and
        (TAICPU(hp2).condition = C_None) and
        (TAICPU(hp2).oper[0]^.typ = top_ref) and
        GetNextInstruction(hp2, hp3) and
        (hp3.typ = ait_label) and
        (TAsmLabel(TAICPU(p).oper[0]^.ref^.symbol) = TAILabel(hp3).labsym) and
        GetNextInstruction(hp3, hp4) and
        { As before, check individually instead of using MatchInstruction in order to save time }
        (hp4.typ = ait_instruction) and
        (TAICPU(hp4).condition = C_None) and
        (TAICPU(hp4).oppostfix = PF_None) and
        (TAICPU(hp4).ops = 2) and
        (TAICPU(hp4).oper[0]^.reg = TAICPU(hp1).oper[0]^.reg) and
        (
          (
            (TAICPU(hp4).opcode = A_MOVZ) and
            (
              (
                { Check to confirm the following:
                  - First mov is either "movz reg,#0" or "mov reg,xzr"
                  - Second mov is "movz reg,#1"
                }
                (
                  (TAICPU(hp1).oper[1]^.typ = top_reg) { Will be the zero register } or
                  (TAICPU(hp1).oper[1]^.val = 0)
                ) and
                (TAICPU(hp4).oper[1]^.val = 1)
              ) or
              (
                { Check to confirm the following:
                  - First mov is "movz reg,#1"
                  - Second mov is "movz reg,#0"
                }
                MatchOperand(TAICPU(hp1).oper[1]^, 1) and
                (TAICPU(hp4).oper[1]^.val = 0)
              )
            )
          ) or
          (
            { Check to confirm the following:
              - First mov is "movz reg,#1"
              - Second mov is "mov reg,xzr"
            }
            (TAICPU(hp4).opcode = A_MOV) and
            (getsupreg(TAICPU(hp4).oper[1]^.reg) = RS_XZR) and
            MatchOperand(TAICPU(hp1).oper[1]^, 1)
          )
        ) and
        GetNextInstruction(hp4, hp5) and
        (hp5.typ = ait_label) and
        (TAsmLabel(TAICPU(hp2).oper[0]^.ref^.symbol) = TAILabel(hp5).labsym) then
        begin
          Invert := MatchOperand(TAICPU(hp1).oper[1]^, 1); { if true, hp4 will be mov reg,0 in some form }
          if Invert then
            TAICPU(p).condition := inverse_cond(TAICPU(p).condition);

          TAILabel(hp3).labsym.DecRefs;

          { If this isn't the only reference to the middle label, we can
            still make a saving - only that the first jump and everything
            that follows will remain. }
          if (TAILabel(hp3).labsym.getrefs = 0) then
            begin
              if Invert then
                DebugMsg(SPeepholeOptimization + 'B(c)Movz1BMovz0 -> Cset(~c)',p)
              else
                DebugMsg(SPeepholeOptimization + 'B(c)Movz0bMovZ1 -> Cset(c)',p);

              { remove jump, first label and second MOV (also catching any aligns) }
              repeat
                if not GetNextInstruction(hp2, hp3) then
                  InternalError(2022070801);

                RemoveInstruction(hp2);

                hp2 := hp3;
              until hp2 = hp5;

              { Don't decrement reference count before the removal loop
                above, otherwise GetNextInstruction won't stop on the
                the label }
              TAILabel(hp5).labsym.DecRefs;
            end
          else
            begin
              if Invert then
                DebugMsg(SPeepholeOptimization + 'B(c)Movz1BMovz0 -> Cset(~c) (partial)',p)
              else
                DebugMsg(SPeepholeOptimization + 'B(c)Movz0BMovz1 -> Cset(c) (partial)',p);
            end;

          TAICPU(hp1).opcode := A_CSET;
          TAICPU(hp1).loadconditioncode(1, TAICPU(p).condition);

          RemoveCurrentP(p, hp1);

          Result:=true;
          exit;
        end;
    end;


  function TCpuAsmOptimizer.OptPass2B(var p: TAI): Boolean;
    var
      hp1: TAI;
      LabelSym: TAsmLabel;
      CSELTracking: PCSELTracking;
    begin
      Result := False;
      if (TAICPU(p).condition = C_None) and
        IsJumpToLabel(TAICPU(p)) then
        begin
          { Check for:
                B   @lbl
                ...
              @Lbl:
                RET

            Change to:
                RET (and reduce reference count on label)
          }

          LabelSym := TAsmLabel(JumpTargetOp(TAICPU(p))^.ref^.symbol);
          hp1 := GetLabelWithSym(LabelSym);
          if Assigned(hp1) and
            GetNextInstruction(hp1, hp1) and
            (hp1.typ = ait_instruction) and
            (TAICPU(hp1).opcode = A_RET) then
            begin
              DebugMsg(SPeepholeOptimization + 'B -> RET since a RET immediately follows the destination label (B2Ret)', p);
              TAICPU(p).ops := 0;
              TAICPU(p).clearop(0);
              TAICPU(p).is_jmp := false;
              TAICPU(p).opcode := A_RET;

              { Make sure the label is dereferenced now }
              LabelSym.decrefs;

              Result := True;
              Exit;
            end;
        end;


      if (TAICPU(p).condition <> C_None) and
        IsJumpToLabel(TAICPU(p)) and
        GetNextInstruction(p, hp1) and
        (hp1.typ = ait_instruction) and
        (TAICPU(hp1).opcode = A_MOV) then
        begin
          { check for
                jCC   xxx
                <several movs>
             xxx:

           Also spot:
                Jcc   xxx
                <several movs>
                jmp   xxx

           Change to:
                <several csets with inverted condition>
                jmp   xxx  (only for the 2nd case)
          }
          CSELTracking := New(PCSELTracking, Init(Self, p, hp1, TAsmLabel(JumpTargetOp(TAICPU(p))^.ref^.symbol)));

          if CSELTracking^.State <> tsInvalid then
            begin
              CSELTracking^.Process(p);
              Result := True;
            end;

          CSELTracking^.Done;
        end;
    end;


  function TCpuAsmOptimizer.OptPass2CSEL(var p: TAI): Boolean;
    begin
      Result := False;

      { Csel r0,r1,r1,cond -> mov r0,r1 }
      if (TAICPU(p).oper[1]^.reg = TAICPU(p).oper[2]^.reg) then
        begin
          DebugMsg(SPeepholeOptimization + 'CSel2Mov (identical true/false registers)', p);
          TAICPU(p).opcode := A_MOV;
          TAICPU(p).ops := 2;
          Result := True;
          Exit;
        end;
    end;


  function TCpuAsmOptimizer.OptPass2LDRSTR(var p: TAI): boolean;
    var
      hp1, hp1_last: TAI;
      ThisRegister: TRegister;
      OffsetVal, ValidOffset, MinOffset, MaxOffset: asizeint;
      TargetOpcode: TAsmOp;
    begin
      Result := False;
      ThisRegister := TAICPU(p).oper[0]^.reg;

      case TAICPU(p).opcode of
        A_LDR:
          TargetOpcode := A_LDP;
        A_STR:
          TargetOpcode := A_STP;
        else
          InternalError(2020081501);
      end;

      { reg appearing in ref invalidates these optimisations }
      if (TargetOpcode = A_STP) or not RegInRef(ThisRegister, TAICPU(p).oper[1]^.ref^) then
        begin
          { LDP/STP has a smaller permitted offset range than LDR/STR.

            TODO: For a group of out-of-range LDR/STR instructions, can
            we declare a temporary register equal to the offset base
            address, modify the STR instructions to use that register
            and then convert them to STP instructions?  Note that STR
            generally takes 2 cycles (on top of the memory latency),
            while LDP/STP takes 3.
          }

          if (getsubreg(ThisRegister) = R_SUBQ) then
            begin
              ValidOffset := 8;
              MinOffset := -512;
              MaxOffset := 504;
            end
          else
            begin
              ValidOffset := 4;
              MinOffset := -256;
              MaxOffset := 252;
            end;

          hp1_last := p;

          { Look for nearby LDR/STR instructions }
          if (TAICPU(p).oppostfix = PF_NONE) and
            (TAICPU(p).oper[1]^.ref^.addressmode = AM_OFFSET) then
            { If SkipGetNext is True, GextNextInstruction isn't called }
            while GetNextInstruction(hp1_last, hp1) do
              begin
                if (hp1.typ <> ait_instruction) then
                  Break;

                if (TAICPU(hp1).opcode = TAICPU(p).opcode) then
                  begin
                    if (TAICPU(hp1).oppostfix = PF_NONE) and
                      { Registers need to be the same size }
                      (getsubreg(ThisRegister) = getsubreg(TAICPU(hp1).oper[0]^.reg)) and
                      (
                        (TargetOpcode = A_STP) or
                        { LDP x0, x0, [sp, #imm] is undefined behaviour, even
                          though such an LDR pair should have been optimised
                          out by now. STP is okay }
                        (ThisRegister <> TAICPU(hp1).oper[0]^.reg)
                      ) and
                      (TAICPU(hp1).oper[1]^.ref^.addressmode = AM_OFFSET) and
                      (TAICPU(p).oper[1]^.ref^.base = TAICPU(hp1).oper[1]^.ref^.base) and
                      (TAICPU(p).oper[1]^.ref^.index = TAICPU(hp1).oper[1]^.ref^.index) and
                      { Make sure the address registers haven't changed }
                      not RegModifiedBetween(TAICPU(hp1).oper[1]^.ref^.base, p, hp1) and
                      (
                        (TAICPU(hp1).oper[1]^.ref^.index = NR_NO) or
                        not RegModifiedBetween(TAICPU(hp1).oper[1]^.ref^.index, p, hp1)
                      ) and
                      { Don't need to check "RegInRef" because the base registers are identical,
                        and the first one was checked already. [Kit] }
                      (((TargetOpcode=A_LDP) and not RegUsedBetween(TAICPU(hp1).oper[0]^.reg, p, hp1)) or
                       ((TargetOpcode=A_STP) and not RegModifiedBetween(TAICPU(hp1).oper[0]^.reg, p, hp1))) then
                      begin
                        { Can we convert these two LDR/STR instructions into a
                          single LDR/STP? }

                        OffsetVal := TAICPU(hp1).oper[1]^.ref^.offset - TAICPU(p).oper[1]^.ref^.offset;
                        if (OffsetVal = ValidOffset) then
                          begin
                            if  (TAICPU(p).oper[1]^.ref^.offset >= MinOffset) and (TAICPU(hp1).oper[1]^.ref^.offset <= MaxOffset) then
                              begin
                                { Convert:
                                    LDR/STR reg0, [reg2, #ofs]
                                    ...
                                    LDR/STR reg1. [reg2, #ofs + 8] // 4 if registers are 32-bit
                                  To:
                                    LDP/STP reg0, reg1, [reg2, #ofs]
                                }
                                TAICPU(p).opcode := TargetOpcode;
                                if TargetOpcode = A_STP then
                                  DebugMsg(SPeepholeOptimization + 'StrStr2Stp', p)
                                else
                                  DebugMsg(SPeepholeOptimization + 'LdrLdr2Ldp', p);
                                TAICPU(p).ops := 3;
                                TAICPU(p).loadref(2, TAICPU(p).oper[1]^.ref^);
                                TAICPU(p).loadreg(1, TAICPU(hp1).oper[0]^.reg);

                                asml.Remove(hp1);
                                hp1.Free;
                                Result := True;
                                Exit;
                              end;
                          end
                        else if (OffsetVal = -ValidOffset) then
                          begin
                            if (TAICPU(hp1).oper[1]^.ref^.offset >= MinOffset) and (TAICPU(p).oper[1]^.ref^.offset <= MaxOffset) then
                              begin
                                { Convert:
                                    LDR/STR reg0, [reg2, #ofs + 8] // 4 if registers are 32-bit
                                    ...
                                    LDR/STR reg1. [reg2, #ofs]
                                  To:
                                    LDP/STP reg1, reg0, [reg2, #ofs]
                                }
                                TAICPU(p).opcode := TargetOpcode;
                                if TargetOpcode = A_STP then
                                  DebugMsg(SPeepholeOptimization + 'StrStr2Stp (reverse)', p)
                                else
                                  DebugMsg(SPeepholeOptimization + 'LdrLdr2Ldp (reverse)', p);
                                TAICPU(p).ops := 3;
                                TAICPU(p).loadref(2, TAICPU(hp1).oper[1]^.ref^);
                                TAICPU(p).loadreg(1, TAICPU(p).oper[0]^.reg);
                                TAICPU(p).loadreg(0, TAICPU(hp1).oper[0]^.reg);

                                asml.Remove(hp1);
                                hp1.Free;
                                Result := True;
                                Exit;
                              end;
                          end;
                      end;
                  end
                else
                  Break;

                { Don't continue looking for LDR/STR pairs if the address register
                  gets modified }
                if RegModifiedByInstruction(TAICPU(p).oper[1]^.ref^.base, hp1) then
                  Break;

                hp1_last := hp1;
              end;
        end;
    end;


  function TCpuAsmOptimizer.OptPass2MOV(var p: TAI): Boolean;
    var
      hp1: TAI;
      X: Integer;
    begin
      Result := False;

      { Merge MOV and CSEL instructions left behind by OptPass2B - that is,
        change:

          mov  r0,r1
          csel r0,r2,r0,cond

        To:
          csel r0,r2,r1,cond

        (Also if r0 is the second operand)
      }
      if (TAICPU(p).oper[1]^.typ = top_reg) and
        GetNextInstructionUsingReg(p, hp1, TAICPU(p).oper[0]^.reg) and
        (hp1.typ = ait_instruction) and
        (TAICPU(hp1).opcode = A_CSEL) and
        (TAICPU(hp1).oper[0]^.reg = TAICPU(p).oper[0]^.reg) and
        not RegModifiedBetween(TAICPU(p).oper[1]^.reg, p, hp1) then
        begin
          { Use "Result" to note if a change was made so we only have to do
            expensive register allocation once }
          for X := 1 to 2 do
            if (TAICPU(hp1).oper[X]^.reg = TAICPU(p).oper[0]^.reg) then
              begin
                TAICPU(hp1).oper[X]^.reg := TAICPU(p).oper[1]^.reg;
                Result := True;
              end;

          if Result then
            begin
              DebugMSg(SPeepholeOptimization + 'MovCSel2CSel', p);
              { Don't need to allocate the zero register - so save time by
                skipping it in this case }
              if getsupreg(TAICPU(p).oper[1]^.reg) <> RS_XZR then
                AllocRegBetween(TAICPU(p).oper[1]^.reg, p, hp1, UsedRegs);
              RemoveCurrentP(p);
              Exit;
            end;
        end;
    end;


  function TCpuAsmOptimizer.PostPeepholeOptAND(var p: TAI): Boolean;
    var
      hp1, hp2: TAI;
      hp3: TAICPU;
      bitval : cardinal;
    begin
      Result:=false;
      {
        and reg1,reg0,<const=power of 2>
        cmp reg1,#0
        <reg1 end of life>
        b.e/b.ne label

        into

        tb(n)z reg0,<power of 2>,label
      }
      if MatchOpType(TAICPU(p),top_reg,top_reg,top_const) and
        (PopCnt(QWord(TAICPU(p).oper[2]^.val))=1) and
        GetNextInstruction(p,hp1) and
        MatchInstruction(hp1,A_CMP,[PF_None]) and
        MatchOpType(TAICPU(hp1),top_reg,top_const) and
        (TAICPU(hp1).oper[1]^.val=0) and
        MatchOperand(TAICPU(p).oper[0]^,TAICPU(hp1).oper[0]^) and
        RegEndOfLife(TAICPU(p).oper[0]^.reg, TAICPU(hp1)) and
        GetNextInstruction(hp1,hp2) and
        MatchInstruction(hp2,A_B,[PF_None]) and
        (TAICPU(hp2).condition in [C_EQ,C_NE]) then
        begin
           bitval:=BsfQWord(qword(TAICPU(p).oper[2]^.val));
           case TAICPU(hp2).condition of
            C_NE:
              hp3:=TAICPU.op_reg_const_ref(A_TBNZ,TAICPU(p).oper[1]^.reg,bitval,TAICPU(hp2).oper[0]^.ref^);
            C_EQ:
              hp3:=TAICPU.op_reg_const_ref(A_TBZ,TAICPU(p).oper[1]^.reg,bitval,TAICPU(hp2).oper[0]^.ref^);
            else
              InternalError(2021100201);
          end;
          TAICPU(hp3).fileinfo:=TAICPU(hp1).fileinfo;
          asml.insertbefore(hp3, hp1);

          RemoveInstruction(hp1);
          RemoveInstruction(hp2);
          RemoveCurrentP(p);
          DebugMsg(SPeepholeOptimization + 'AndCmpB.E/NE2Tbnz/Tbz done', p);
          Result:=true;
        end;
    end;


  function TCpuAsmOptimizer.PostPeepholeOptCMP(var p : TAI): boolean;
    var
     hp1,hp2: TAI;
    begin
      Result:=false;
      {
         cmp reg0,#0
         b.e/b.ne label

         into

         cb(n)z reg0,label
      }
      if MatchOpType(TAICPU(p),top_reg,top_const) and
        (TAICPU(p).oper[0]^.reg<>NR_SP) and
        (TAICPU(p).oper[1]^.val=0) and
        GetNextInstruction(p,hp1) and
        MatchInstruction(hp1,A_B,[PF_None]) and
        (TAICPU(hp1).condition in [C_EQ,C_NE]) then
        begin
          case TAICPU(hp1).condition of
            C_NE:
              hp2:=TAICPU.op_reg_sym_ofs(A_CBNZ,TAICPU(p).oper[0]^.reg,TAICPU(hp1).oper[0]^.ref^.symbol,TAICPU(hp1).oper[0]^.ref^.offset);
            C_EQ:
              hp2:=TAICPU.op_reg_sym_ofs(A_CBZ,TAICPU(p).oper[0]^.reg,TAICPU(hp1).oper[0]^.ref^.symbol,TAICPU(hp1).oper[0]^.ref^.offset);
            else
              InternalError(2019090801);
          end;
          TAICPU(hp2).fileinfo:=TAICPU(hp1).fileinfo;
          asml.insertbefore(hp2, hp1);

          asml.remove(p);
          asml.remove(hp1);
          p.free;
          hp1.free;
          p:=hp2;
          DebugMsg(SPeepholeOptimization + 'CMPB.E/NE2CBNZ/CBZ done', p);
          Result:=true;
        end;
    end;


  function TCpuAsmOptimizer.PostPeepholeOptTST(var p : TAI): boolean;
    var
      hp1: TAI;
      hp3: TAICPU;
      bitval : cardinal;
      swapoper: POper;
    begin
      Result:=false;
      if MatchOpType(TAICPU(p),top_reg,top_const) and
        (PopCnt(QWord(TAICPU(p).oper[1]^.val))=1) and
        GetNextInstruction(p,hp1) then
        begin
          {
            tst reg1,<const=power of 2>
            b.e/b.ne label

            into

            tb(n)z reg0,<index of said power of 2>,label
          }
          if MatchInstruction(hp1,A_B,[C_EQ,C_NE],[PF_None]) then
            begin
               bitval:=BsfQWord(qword(TAICPU(p).oper[1]^.val));
               case TAICPU(hp1).condition of
                C_NE:
                  hp3:=TAICPU.op_reg_const_ref(A_TBNZ,TAICPU(p).oper[0]^.reg,bitval,TAICPU(hp1).oper[0]^.ref^);
                C_EQ:
                  hp3:=TAICPU.op_reg_const_ref(A_TBZ,TAICPU(p).oper[0]^.reg,bitval,TAICPU(hp1).oper[0]^.ref^);
                else
                  InternalError(2021100210);
              end;
              TAICPU(hp3).fileinfo:=TAICPU(p).fileinfo;
              asml.insertafter(hp3, p);

              RemoveInstruction(hp1);
              RemoveCurrentP(p, hp3);
              DebugMsg(SPeepholeOptimization + 'TST; B(E/NE) -> TB(Z/NZ) done', p);
              Result:=true;
              Exit;
            end;

          {
            tst  reg1,#1
            cset reg2,ne

            into

            and  reg2,reg1,#1
          }
          if (TAICPU(p).oper[1]^.val=1) and
            MatchInstruction(hp1,A_CSET,[PF_None]) and
            (TAICPU(hp1).oper[1]^.typ=top_conditioncode) and
            (TAICPU(hp1).oper[1]^.cc=C_NE) then
            begin
              TransferUsedRegs(TmpUsedRegs);
              UpdateUsedRegs(TmpUsedRegs, TAI(p.Next));
              if not RegUsedAfterInstruction(NR_DEFAULTFLAGS, hp1, TmpUsedRegs) then
                begin
                  TAICPU(p).opcode:=A_AND;
                  TAICPU(p).allocate_oper(2);
                  TAICPU(p).ops:=3;
                  TAICPU(p).loadconst(2,1);
                  { Move p.oper[0] to p.oper[1] and hp1.oper[0] to p.oper[0] by cycling the pointers }
                  swapoper:=TAICPU(p).oper[0];
                  TAICPU(p).oper[0]:=TAICPU(hp1).oper[0];
                  TAICPU(hp1).oper[0]:=TAICPU(p).oper[1];
                  TAICPU(p).oper[1]:=swapoper;

                  if (TAICPU(p).oper[0]^.reg<>TAICPU(p).oper[1]^.reg) then
                    begin
                      { p.oper[0] contains the register that was written to by CSET.
                        Since we're deleting the next instruction, update UsedRegs directly }
                      AllocRegBetween(TAICPU(p).oper[1]^.reg, p, hp1, UsedRegs);

                      { Ensure the registers are the same size (if the destination register
                        is shrunk fro 64 bits to 32 bits, the upper 32 bits will be set to
                        zero, preserving existing behaviour since only the least significant
                        bit is set or cleared with everything else zeroed }
                      setsubreg(TAICPU(p).oper[0]^.reg, getsubreg(TAICPU(p).oper[1]^.reg));
                    end;

                  RemoveInstruction(hp1);
                  DebugMsg(SPeepholeOptimization + 'TST #1; CSET NE -> AND #1 done', p);
                  Result:=true;
                  Exit;
                end;
            end;
        end;
    end;


  function TCpuAsmOptimizer.PrePeepHoleOptsCpu(var p: TAI): boolean;
    begin
      result := false;
      if p.typ=ait_instruction then
        begin
          case TAICPU(p).opcode of
            A_SBFX,
            A_UBFX:
              Result:=OptPreSBFXUBFX(p);
            else
              ;
          end;
        end;
    end;


  function TCpuAsmOptimizer.PeepHoleOptPass1Cpu(var p: TAI): boolean;
    begin
      result := false;
      if p.typ=ait_instruction then
        begin
          case TAICPU(p).opcode of
            A_B:
              Result:=OptPass1B(p);
            A_LDR:
              Result:=OptPass1LDR(p);
            A_STR:
              Result:=OptPass1STR(p);
            A_MOV:
              Result:=OptPass1Mov(p);
            A_MOVZ:
              Result:=OptPass1MOVZ(p);
            A_STP:
              Result:=OptPass1STP(p);
            A_LSR,
            A_ROR,
            A_ASR,
            A_LSL:
              Result:=OptPass1Shift(p);
            A_AND:
              Result:=OptPass1And(p);
            A_LSRV,
            A_RORV,
            A_ASRV,
            A_LSLV,
            A_UDIV,
            A_SDIV,
            A_NEG,
            A_CSEL,
            A_ADD,
            A_ADC,
            A_SUB,
            A_SBC,
            A_BIC,
            A_EOR,
            A_ORR,
            A_MUL:
              Result:=OptPass1Data(p);
            A_UXTB:
              Result:=OptPass1UXTB(p);
            A_UXTH:
              Result:=OptPass1UXTH(p);
            A_SXTB:
              Result:=OptPass1SXTB(p);
            A_SXTH:
              Result:=OptPass1SXTH(p);
            A_SXTW:
              Result:=OptPass1SXTW(p);
//            A_VLDR,
            A_FRINTA,
            A_FRINTI,
            A_FRINTM,
            A_FRINTN,
            A_FRINTP,
            A_FRINTX,
            A_FRINTZ,
            A_FCSEL,
            A_FMADD,
            A_FMSUB,
            A_FNMADD,
            A_FNMSUB,
            A_FNMUL,
            A_FADD,
            A_FMUL,
            A_FDIV,
            A_FSUB,
            A_FSQRT,
            A_FNEG,
            A_FCVT,
            A_FABS:
              Result:=OptPass1FData(p);
            A_FMOV:
              Result:=OptPass1FMov(p);
            else
              ;
          end;
        end;
    end;


  function TCpuAsmOptimizer.PeepHoleOptPass2Cpu(var p: TAI): boolean;
    begin
      result := false;
      if p.typ=ait_instruction then
        begin
          case TAICPU(p).opcode of
            A_AND,
            A_BIC:
              Result := OptPass2Bitwise(p);
            A_B:
              Result := OptPass2B(p);
            A_CSEL:
              Result := OptPass2CSEL(p);
            A_MOV:
              Result := OptPass2MOV(p);
            A_LDR,
            A_STR:
              Result := OptPass2LDRSTR(p);
            A_TST:
              Result := OptPass2TST(p);
            else
              ;
          end;
        end;
    end;


  function TCpuAsmOptimizer.PostPeepHoleOptsCpu(var p: TAI): boolean;
    begin
      result := false;
      if p.typ=ait_instruction then
        begin
          case TAICPU(p).opcode of
            A_CMP:
              Result:=PostPeepholeOptCMP(p);
            A_AND:
              Result:=PostPeepholeOptAND(p);
            A_TST:
              Result:=PostPeepholeOptTST(p);
            else
              ;
          end;
        end;
    end;


  class procedure TCpuAsmOptimizer.UpdateIntRegsNoDealloc(var AUsedRegs: TAllUsedRegs; p: TAI);
    begin
      { Update integer registers, ignoring deallocations }
      repeat
        while Assigned(p) and
              ((p.typ in (SkipInstr - [ait_RegAlloc])) or
               (p.typ = ait_label) or
               ((p.typ = ait_marker) and
                (TAIMarker(p).Kind in [mark_AsmBlockEnd,mark_NoLineInfoStart,mark_NoLineInfoEnd]))) do
             p := TAI(p.next);
        while Assigned(p) and
              (p.typ=ait_RegAlloc) Do
          begin
            if (getregtype(TAIRegAlloc(p).reg) = R_INTREGISTER) then
              begin
                case TAIRegAlloc(p).ratype of
                  ra_alloc :
                    IncludeRegInUsedRegs(TAIRegAlloc(p).reg, AUsedRegs);
                  else
                    ;
                end;
              end;
            p := TAI(p.next);
          end;
      until not(Assigned(p)) or
            (not(p.typ in SkipInstr) and
             not((p.typ = ait_label) and
                 labelCanBeSkipped(TAILabel(p))));
    end;

  { Attempts to allocate a volatile integer register for use between p and hp,
    using AUsedRegs for the current register usage information.  Returns NR_NO
    if no free register could be found }
  function TCpuAsmOptimizer.GetIntRegisterBetween(RegSize: TSubRegister; var AUsedRegs: TAllUsedRegs; p, hp: TAI; DontAlloc: Boolean = False): TRegister;
    var
      RegSet: TCPURegisterSet;
      CurrentSuperReg: Integer;
      CurrentReg: TRegister;
      Currentp: TAI;
      Breakout: Boolean;
    begin
      Result := NR_NO;
      RegSet :=
        paramanager.get_volatile_registers_int(CurrentProcInfo.procdef.proccalloption) +
        CurrentProcInfo.saved_regs_int;
(*
      { Don't use the frame register unless explicitly allowed (fixes i40111) }
      if ([cs_useebp, cs_userbp] * current_settings.optimizerswitches) = [] then
        Exclude(RegSet, RS_FRAME_POINTER_REG);
*)
      for CurrentSuperReg in RegSet do
        begin
          CurrentReg := newreg(R_INTREGISTER, TSuperRegister(CurrentSuperReg), RegSize);
          if not AUsedRegs[R_INTREGISTER].IsUsed(CurrentReg)
            then
            begin
              Currentp := p;
              Breakout := False;
              while not Breakout and GetNextInstruction(Currentp, Currentp) and (Currentp <> hp) do
                begin
                  case Currentp.typ of
                    ait_instruction:
                      begin
                        if RegInInstruction(CurrentReg, Currentp) then
                          begin
                            Breakout := True;
                            Break;

                          end;
                        { Cannot allocate across an unconditional jump }
                        if is_calljmpmaybeuncondret(TAICPU(Currentp).opcode) and (TAICPU(Currentp).condition = C_None) then
                          Exit;
                      end;
                    ait_marker:
                      { Don't try anything more if a marker is hit }
                      Exit;
                    ait_regalloc:
                      if (TAIRegAlloc(Currentp).ratype <> ra_dealloc) and SuperRegistersEqual(CurrentReg, TAIRegAlloc(Currentp).reg) then
                        begin
                          Breakout := True;
                          Break;
                        end;
                    else
                      ;
                  end;
                end;

              if Breakout then
                { Try the next register }
                Continue;

              { We have a free register available }
              Result := CurrentReg;
              if not DontAlloc then
                AllocRegBetween(CurrentReg, p, hp, AUsedRegs);
              Exit;
            end;
        end;
    end;


  function TCSELTracking.InitialiseBlock(BlockStart, OneBeforeBlock: TAI; out BlockStop: TAI; out EndJump: TAI): Boolean;
    begin
      Result := False;
      EndJump := nil;
      BlockStop := nil;

      while (BlockStart <> fOptimizer.BlockEnd) and
        { stop on labels }
        (BlockStart.typ <> ait_label) do
        begin
          { Keep track of all integer registers that are used }
          fOptimizer.UpdateIntRegsNoDealloc(RegisterTracking, TAI(OneBeforeBlock.Next));
          if BlockStart.typ = ait_instruction then
            begin
              if MatchInstruction(BlockStart, A_B, [C_None], []) then
                begin
                  if not IsJumpToLabel(TAICPU(BlockStart)) or
                    (JumpTargetOp(TAICPU(BlockStart))^.ref^.index <> NR_NO) then
                    Exit;

                  EndJump := BlockStart;
                  Break;
                end
              { Check to see if we have a valid MOV instruction instead }
              else if (TAICPU(BlockStart).opcode <> A_MOV) or
                { Can't include the stack pointer in CSEL }
                fOptimizer.RegInInstruction(NR_SP, BlockStart) then
                begin
                  Exit;
                end
              else
                { This will be a valid MOV }
                fAllocationRange := BlockStart;
            end;

          OneBeforeBlock := BlockStart;
          fOptimizer.GetNextInstruction(BlockStart, BlockStart);
        end;

      if (BlockStart = fOptimizer.BlockEnd) then
        Exit;

      BlockStop := BlockStart;
      Result := True;
    end;


  function TCSELTracking.AnalyseMOVBlock(BlockStart, BlockStop, SearchStart: TAI): LongInt;
    var
      hp1: TAI;
      RefModified: Boolean;
    begin
      Result := 0;
      hp1 := BlockStart;
      RefModified := False; { As long as the condition is inverted, this can be reset }

      while Assigned(hp1) and
        (hp1 <> BlockStop) do
        begin
          case hp1.typ of
            ait_instruction:
              if MatchInstruction(hp1, A_MOV, []) then
                begin
                  Inc(Result);
                  if TAICPU(hp1).oper[1]^.typ = top_reg then
                    begin
                      Inc(Result);
                    end
                  else if not (cs_opt_size in CurrentSettings.OptimizerSwitches) and
                    { CSEL with constants grows the code size }
                    TryCSELConst(hp1, SearchStart, BlockStop, Result) then
                    begin
                      { Register was reserved by TryCSELConst and
                        stored on ConstRegs }
                    end
                  else
                    begin
                      Result := -1;
                      Exit;
                    end;
                end
              else
                begin
                  Result := -1;
                  Exit;
                end;
            else
              { Most likely an align };
          end;
          fOptimizer.GetNextInstruction(hp1, hp1);
        end;
    end;


  constructor TCSELTracking.Init(Optimizer: TCpuAsmOptimizer; var p_initialjump, p_initialmov: TAI; var AFirstLabel: TAsmLabel);

    { For the tsBranching type, increase the weighting score to account for the new conditional jump
      (this is done as a separate stage because the double types are extensions of the branching type,
      but we can't discount the conditional jump until the last step) }
    procedure EvaluateBranchingType;
      begin
        Inc(CSELScore);
        if (CSELScore > MAX_CSEL_INSTRUCTIONS) then
          { Too many instructions to be worthwhile }
          fState := tsInvalid;
      end;

    var
      hp1: TAI;
      Count: Integer;
    begin
      { Table of valid CSEL block types

        Block type                  2nd Jump    Mid-label   2nd MOVs    3rd Jump    End-label
        ----------                  ---------   ---------   ---------   ---------   ---------
        tsSimple                        X          Yes          X           X           X
        tsDetour                      = 1st         X           X           X           X
        tsBranching                  <> Mid        Yes          X           X           X
        tsDouble                    End-label      Yes *       Yes          X          Yes
        tsDoubleBranchSame           <> Mid        Yes *       Yes        = 2nd         X
        tsDoubleBranchDifferent      <> Mid        Yes *       Yes       <> 2nd         X
        tsDoubleSecondBranching     End-label      Yes *       Yes       <> 2nd        Yes

        * Only one reference allowed
      }

      hp1 := nil; { To prevent compiler warnings }

      Optimizer.CopyUsedRegs(RegisterTracking);
      fOptimizer := Optimizer;
      fLabel := AFirstLabel;

      CSELScore := 0;
      ConstCount := 0;

      { Initialise RegWrites, ConstRegs, ConstVals, ConstSizes, ConstWriteSizes and ConstMovs }
      FillChar(RegWrites[0], MAX_CSEL_INSTRUCTIONS * 2 * SizeOf(TRegister), 0);
      FillChar(ConstRegs[0], MAX_CSEL_REGISTERS * SizeOf(TRegister), 0);
      FillChar(ConstVals[0], MAX_CSEL_REGISTERS * SizeOf(TCGInt), 0);
      FillChar(ConstSizes[0], MAX_CSEL_REGISTERS * SizeOf(TSubRegister), 0);
      FillChar(ConstWriteSizes[0], first_int_imreg * SizeOf(TOpSize), 0);
      FillChar(ConstMovs[0], MAX_CSEL_REGISTERS * SizeOf(TAICPU), 0);

      fInsertionPoint := p_initialjump;
      fCondition := nil;
      fInitialJump := p_initialjump;
      fFirstMovBlock := p_initialmov;
      fFirstMovBlockStop := nil;

      fSecondJump := nil;
      fSecondMovBlock := nil;
      fSecondMovBlockStop := nil;

      fMidLabel := nil;

      fSecondJump := nil;
      fSecondMovBlock := nil;

      fEndLabel := nil;

      fAllocationRange := nil;

      { Assume it all goes horribly wrong! }
      fState := tsInvalid;

      { Look backwards at the comparisons to get an accurate picture of register usage and a better position for any MOV const,reg insertions }
      if Optimizer.GetLastInstruction(p_initialjump, fCondition) and
        (
          MatchInstruction(fCondition, [A_CMP, A_CMN, A_TST], []) or
          (
            (fCondition.typ = ait_instruction) and
            (TAICPU(fCondition).opcode = A_AND) and
            (TAICPU(fCondition).oppostfix = PF_S)
          )
        ) then
        begin
          { Mark all the registers in the comparison as 'in use', even if they've just been deallocated }
          for Count := 0 to TAICPU(fCondition).ops - 1 do
            with TAICPU(fCondition).oper[Count]^ do
              case typ of
                top_reg:
                  if getregtype(reg) = R_INTREGISTER then
                    Optimizer.IncludeRegInUsedRegs(reg, RegisterTracking);
                top_ref:
                  begin
                    if
                      (ref^.base <> NR_NO) then
                      Optimizer.IncludeRegInUsedRegs(ref^.base, RegisterTracking);

                    if (ref^.index <> NR_NO) then
                      Optimizer.IncludeRegInUsedRegs(ref^.index, RegisterTracking);
                  end
                else
                  ;
              end;

          { When inserting instructions before hp_prev, try to insert them
            before the allocation of the FLAGS register }
          if not SetAndTest(Optimizer.FindRegAllocBackward(NR_DEFAULTFLAGS, TAI(fCondition.Previous)), fInsertionPoint) or
            (TAIRegAlloc(fInsertionPoint).ratype = ra_dealloc) then
            { If not found, set it equal to the condition so it's something sensible }
            fInsertionPoint := fCondition;

        end
      else
        fCondition := nil;

      { When inserting instructions, try to insert them before the allocation of the FLAGS register }
      if SetAndTest(Optimizer.FindRegAllocBackward(NR_DEFAULTFLAGS, TAI(p_initialjump.Previous)), hp1) and
        (TAIRegAlloc(hp1).ratype <> ra_dealloc) then
        { If not found, set it equal to p so it's something sensible }
        fInsertionPoint := hp1;

      hp1 := p_initialmov;

      if not InitialiseBlock(p_initialmov, p_initialjump, fFirstMovBlockStop, fSecondJump) then
        Exit;

      hp1 := fFirstMovBlockStop; { Will either be on a label or a jump }

      if (hp1.typ <> ait_label) then { should be on a jump }
        begin
          if not Optimizer.GetNextInstruction(hp1, fMidLabel) or (fMidLabel.typ <> ait_label) then
            { Need a label afterwards }
            Exit;
        end
      else
        fMidLabel := hp1;

      if TAILabel(fMidLabel).labsym <> AFirstLabel then
        { Not the correct label }
        fMidLabel := nil;

      if not Assigned(fSecondJump) and not Assigned(fMidLabel) then
        { If there's neither a 2nd jump nor correct label, then it's invalid
          (see above table) }
        Exit;

      { Analyse the first block of MOVs more closely }
      CSELScore := AnalyseMOVBlock(fFirstMovBlock, fFirstMovBlockStop, fInsertionPoint);

      if Assigned(fSecondJump) then
        begin
          if (JumpTargetOp(TAICPU(fSecondJump))^.ref^.symbol = AFirstLabel) then
            begin
              fState := tsDetour
            end
          else
            begin
              { Need the correct mid-label for this one }
              if not Assigned(fMidLabel) then
                Exit;

              fState := tsBranching;
            end;
        end
      else
        { No jump. but mid-label is present }
        fState := tsSimple;

      if (CSELScore > MAX_CSEL_INSTRUCTIONS) or (CSELScore <= 0) then
        begin
          { Invalid or too many instructions to be worthwhile }
          fState := tsInvalid;
          Exit;
        end;


      { check further for
             b     xxx
             <several movs 1>
             bl    yyy
         xxx:
             <several movs 2>
         yyy:

        etc.
      }
      if (fState = tsBranching) and
        { Estimate for required savings for extra jump }
        (CSELScore <= MAX_CSEL_INSTRUCTIONS - 1) and
        { Only one reference is allowed for double blocks }
        (AFirstLabel.getrefs = 1) then
        begin
          Optimizer.GetNextInstruction(fMidLabel, hp1);
          fSecondMovBlock := hp1;

          if not InitialiseBlock(fSecondMovBlock, fMidLabel, fSecondMovBlockStop, fThirdJump) then
            begin
              EvaluateBranchingType;
              Exit;
            end;

          hp1 := fSecondMovBlockStop; { Will either be on a label or a jump }

          if (hp1.typ <> ait_label) then { should be on a jump }
            begin
              if not Optimizer.GetNextInstruction(hp1, fEndLabel) or (fEndLabel.typ <> ait_label) then
                begin
                  { Need a label afterwards }
                  EvaluateBranchingType;
                  Exit;
                end;
            end
          else
            fEndLabel := hp1;

          if TAILabel(fEndLabel).labsym <> JumpTargetOp(TAICPU(fSecondJump))^.ref^.symbol then
            { Second jump doesn't go to the end }
            fEndLabel := nil;

          if not Assigned(fThirdJump) and not Assigned(fEndLabel) then
            begin
            { If there's neither a 3rd jump nor correct end label, then it's
              not a invalid double block, but is a valid single branching
              block (see above table) }
              EvaluateBranchingType;
              Exit;
            end;

          Count := AnalyseMOVBlock(fSecondMovBlock, fSecondMovBlockStop, fMidLabel);

          if (Count > MAX_CSEL_INSTRUCTIONS) or (Count <= 0) then
            { Invalid or too many instructions to be worthwhile }
            Exit;

          Inc(CSELScore, Count);

          if Assigned(fThirdJump) then
            begin
              if not Assigned(fSecondJump) then
                fState := tsDoubleSecondBranching
              else if (JumpTargetOp(TAICPU(fSecondJump))^.ref^.symbol = JumpTargetOp(TAICPU(fThirdJump))^.ref^.symbol) then
                fState := tsDoubleBranchSame
              else
                fState := tsDoubleBranchDifferent;
            end
          else
            fState := tsDouble;
        end;

      if fState = tsBranching then
        EvaluateBranchingType;
    end;

  { Tries to convert a mov const,%reg instruction into a CSEL by reserving a
    new register to store the constant }
  function TCSELTracking.TryCSELConst(p, start, stop: TAI; var Count: LongInt): Boolean;
    var
      RegSize: TSubRegister;
      CurrentVal: TCGInt;
      ANewReg: TRegister;
      X: ShortInt;
    begin
      Result := False;

      if not MatchOpType(TAICPU(p), top_reg, top_const) then
        Exit;

      if ConstCount >= MAX_CSEL_REGISTERS then
        { Arrays are full }
        Exit;

      { See if the value has already been reserved for another CSEL instruction }
      CurrentVal := TAICPU(p).oper[1]^.val;
      RegSize := getsubreg(TAICPU(p).oper[0]^.reg);
      for X := 0 to ConstCount - 1 do
        if ConstVals[X] = CurrentVal then
          begin
            ConstRegs[ConstCount] := ConstRegs[X];
            ConstSizes[ConstCount] := RegSize;
            ConstVals[ConstCount] := CurrentVal;

            Inc(ConstCount);
            Inc(Count);

            Result := True;
            Exit;
          end;

      ANewReg := fOptimizer.GetIntRegisterBetween(R_SUBWHOLE, RegisterTracking, start, stop, True);
      if ANewReg = NR_NO then
        { No free registers }
        Exit;

      { Reserve the register so subsequent TryCSELConst calls don't all end
        up vying for the same register }
      fOptimizer.IncludeRegInUsedRegs(ANewReg, RegisterTracking);

      ConstRegs[ConstCount] := ANewReg;
      ConstSizes[ConstCount] := RegSize;
      ConstVals[ConstCount] := CurrentVal;

      Inc(ConstCount);
      Inc(Count);

      Result := True;
    end;

  destructor TCSELTracking.Done;
    begin
      TAOptObj.ReleaseUsedRegs(RegisterTracking);
    end;

  procedure TCSELTracking.Process(out new_p: TAI);
    var
      Count, Writes: LongInt;
      RegMatch: Boolean;
      hp1, hp_new: TAI;
      inverted_condition, condition: TAsmCond;
    begin
      if (fState in [tsInvalid, tsProcessed]) then
        InternalError(2023110702);

      { Repurpose RegisterTracking to mark registers that we've defined }
      RegisterTracking[R_INTREGISTER].Clear;

      Count := 0;
      Writes := 0;
      condition := TAICPU(fInitialJump).condition;
      inverted_condition := inverse_cond(condition);

      { Exclude tsDoubleBranchDifferent from this check, as the second block
        doesn't get CSELs in this case }
      if (fState in [tsDouble, tsDoubleBranchSame, tsDoubleSecondBranching]) then
        begin
          { Include the jump in the flag tracking }
          if Assigned(fThirdJump) then
            begin
              if (fState = tsDoubleBranchSame) then
                begin
                  { Will be an unconditional jump, so track to the instruction before it }
                  if not fOptimizer.GetLastInstruction(fThirdJump, hp1) then
                    InternalError(2023110712);
                end
              else
                hp1 := fThirdJump;
            end
          else
            hp1 := fSecondMovBlockStop;
        end
      else
        begin
          { Include a conditional jump in the flag tracking }
          if Assigned(fSecondJump) then
            begin
              if (fState = tsDetour) then
                begin
                  { Will be an unconditional jump, so track to the instruction before it }
                  if not fOptimizer.GetLastInstruction(fSecondJump, hp1) then
                    InternalError(2023110713);
                end
              else
                hp1 := fSecondJump;
            end
          else
            hp1 := fFirstMovBlockStop;
        end;

      fOptimizer.AllocRegBetween(NR_DEFAULTFLAGS, fInitialJump, hp1, fOptimizer.UsedRegs);

      { Process the second set of MOVs first, because if a destination
        register is shared between the first and second MOV sets, it is more
        efficient to turn the first one into a MOV instruction and place it
        before the CMP if possible, but we won't know which registers are
        shared until we've processed at least one list, so we might as well
        make it the second one since that won't be modified again. }

      if (fState in [tsDouble, tsDoubleBranchSame, tsDoubleBranchDifferent, tsDoubleSecondBranching]) then
        begin
          hp1 := fSecondMovBlock;
          repeat
            if not Assigned(hp1) then
              InternalError(2018062902);

            if (hp1.typ = ait_instruction) then
              begin
                { Extra safeguard }
                if (TAICPU(hp1).opcode <> A_MOV) then
                  InternalError(2018062903);

                { Note: tsDoubleBranchDifferent is essentially identical to
                  tsBranching and the 2nd block is best left largely
                  untouched, but we need to evaluate which registers the MOVs
                  write to in order to track what would be complementary CSEL
                  pairs that can be further optimised. [Kit] }
                if fState <> tsDoubleBranchDifferent then
                  begin
                    if TAICPU(hp1).oper[1]^.typ = top_const then
                      begin
                        RegMatch := False;

                        for Count := 0 to ConstCount - 1 do
                          if (ConstVals[Count] = TAICPU(hp1).oper[1]^.val) and
                            (getsubreg(TAICPU(hp1).oper[0]^.reg) = ConstSizes[Count]) then
                            begin
                              RegMatch := True;

                              { If it's in RegisterTracking, then this register
                                is being used more than once and hence has
                                already had its value defined (it gets added to
                                UsedRegs through AllocRegBetween below) }
                              if not RegisterTracking[R_INTREGISTER].IsUsed(ConstRegs[Count]) then
                                begin
                                  hp_new := TAI(hp1.getcopy);
                                  TAICPU(hp_new).oper[0]^.reg := ConstRegs[Count];
                                  TAICPU(hp_new).fileinfo := TAICPU(fInitialJump).fileinfo;

                                  fOptimizer.asml.InsertBefore(hp_new, fInsertionPoint);
                                  fOptimizer.IncludeRegInUsedRegs(ConstRegs[Count], RegisterTracking);

                                  ConstMovs[Count] := hp_new;
                                end
                              else
                                { We just need an instruction between hp_prev and hp1
                                  where we know the register is marked as in use }
                                hp_new := fSecondMovBlock;

                              { Keep track of largest write for this register so it can be optimised later }
                              if (getsubreg(TAICPU(hp1).oper[0]^.reg) > ConstWriteSizes[getsupreg(ConstRegs[Count])]) then
                                ConstWriteSizes[getsupreg(ConstRegs[Count])] := getsubreg(TAICPU(hp1).oper[0]^.reg);

                              fOptimizer.AllocRegBetween(ConstRegs[Count], hp_new, hp1, fOptimizer.UsedRegs);
                              TAICPU(hp1).loadreg(1, newreg(R_INTREGISTER, getsupreg(ConstRegs[Count]), ConstSizes[Count]));
                              Break;
                            end;

                        if not RegMatch then
                          InternalError(2021100413);
                      end;

                    TAICPU(hp1).opcode := A_CSEL;
                    TAICPU(hp1).ops := 4;
                    TAICPU(hp1).loadreg(2, TAICPU(hp1).oper[0]^.reg);
                    TAICPU(hp1).loadconditioncode(3, condition);
                  end;

                { Store these writes to search for duplicates later on }
                RegWrites[Writes] := TAICPU(hp1).oper[0]^.reg;
                Inc(Writes);
              end;

            fOptimizer.GetNextInstruction(hp1, hp1);
          until (hp1 = fSecondMovBlockStop);
        end;

      { Now do the first set of MOVs }
      hp1 := fFirstMovBlock;
      repeat
        if not Assigned(hp1) then
          InternalError(2018062904);

        if (hp1.typ = ait_instruction) then
          begin
            RegMatch := False;

            { Extra safeguard }
            if (TAICPU(hp1).opcode <> A_MOV) then
              InternalError(2018062905);

            { Search through the RegWrites list to see if there are any
              opposing CSEL pairs that write to the same register }
            for Count := 0 to Writes - 1 do
              if (RegWrites[Count] = TAICPU(hp1).oper[0]^.reg) then
                begin
                  { We have a match.  Keep this as a MOV }

                  { Move ahead in preparation }
                  fOptimizer.GetNextInstruction(hp1, hp1);

                  RegMatch := True;
                  Break;
                end;

            if RegMatch then
              Continue;

            if TAICPU(hp1).oper[1]^.typ = top_const then
              begin
                for Count := 0 to ConstCount - 1 do
                  if (ConstVals[Count] = TAICPU(hp1).oper[1]^.val) and
                    (getsubreg(TAICPU(hp1).oper[0]^.reg) = ConstSizes[Count]) then
                    begin
                      RegMatch := True;

                      { If it's in RegisterTracking, then this register is
                        being used more than once and hence has already had
                        its value defined (it gets added to UsedRegs through
                        AllocRegBetween below) }
                      if not RegisterTracking[R_INTREGISTER].IsUsed(ConstRegs[Count]) then
                        begin
                          hp_new := TAI(hp1.getcopy);
                          TAICPU(hp_new).oper[0]^.reg := ConstRegs[Count];
                          TAICPU(hp_new).fileinfo := TAICPU(fInitialJump).fileinfo;

                          fOptimizer.asml.InsertBefore(hp_new, fInsertionPoint);
                          fOptimizer.IncludeRegInUsedRegs(ConstRegs[Count], RegisterTracking);

                          ConstMovs[Count] := hp_new;
                        end
                      else
                        { We just need an instruction between hp_prev and hp1
                          where we know the register is marked as in use }
                          hp_new := fFirstMovBlock;

                      { Keep track of largest write for this register so it can be optimised later }
                      if (getsubreg(TAICPU(hp1).oper[0]^.reg) > ConstWriteSizes[getsupreg(ConstRegs[Count])]) then
                        ConstWriteSizes[getsupreg(ConstRegs[Count])] := getsubreg(TAICPU(hp1).oper[0]^.reg);

                      fOptimizer.AllocRegBetween(ConstRegs[Count], hp_new, hp1, fOptimizer.UsedRegs);
                      TAICPU(hp1).loadreg(1, newreg(R_INTREGISTER, getsupreg(ConstRegs[Count]), ConstSizes[Count]));
                      Break;
                    end;

                if not RegMatch then
                  InternalError(2021100412);
              end;

              TAICPU(hp1).opcode := A_CSEL;
              TAICPU(hp1).ops := 4;
              TAICPU(hp1).loadreg(2, TAICPU(hp1).oper[0]^.reg);
              TAICPU(hp1).loadconditioncode(3, inverted_condition);

            if (fState = tsDoubleBranchDifferent) then
              begin
                { Store these writes to search for duplicates later on }
                RegWrites[Writes] := TAICPU(hp1).oper[0]^.reg;
                Inc(Writes);
              end;
          end;

        fOptimizer.GetNextInstruction(hp1, hp1);
      until (hp1 = fFirstMovBlockStop);

      { Update initialisation MOVs to the smallest possible size }
      for Count := 0 to ConstCount - 1 do
        if Assigned(ConstMovs[Count]) then
          setsubreg(TAICPU(ConstMovs[Count]).oper[0]^.reg, ConstWriteSizes[Word(ConstRegs[Count])]);

      case fState of
        tsSimple:
          begin
            fOptimizer.DebugMsg(SPeepholeOptimization + 'CSEL Block (Simple type)', fInitialJump);
            { No branch to delete }
          end;
        tsDetour:
          begin
            fOptimizer.DebugMsg(SPeepholeOptimization + 'CSEL Block (Detour type)', fInitialJump);
            { Preserve jump }
          end;
        tsBranching, tsDoubleBranchDifferent:
          begin
            if (fState = tsBranching) then
              fOptimizer.DebugMsg(SPeepholeOptimization + 'CSEL Block (Branching type)', fInitialJump)
            else
              fOptimizer.DebugMsg(SPeepholeOptimization + 'CSEL Block (Double branching (different) type)', fInitialJump);
            TAICPU(fSecondJump).condition := inverted_condition;
          end;
        tsDouble, tsDoubleBranchSame:
          begin
            if (fState = tsDouble) then
              fOptimizer.DebugMsg(SPeepholeOptimization + 'CSEL Block (Double type)', fInitialJump)
            else
              fOptimizer.DebugMsg(SPeepholeOptimization + 'CSEL Block (Double branching (same) type)', fInitialJump);
            { Delete second jump }
            JumpTargetOp(TAICPU(fSecondJump))^.ref^.symbol.decrefs;
            fOptimizer.RemoveInstruction(fSecondJump);
          end;
        tsDoubleSecondBranching:
          begin
            fOptimizer.DebugMsg(SPeepholeOptimization + 'CSEL Block (Double, second branching type)', fInitialJump);
            { Delete second jump, preserve third jump as conditional }
            JumpTargetOp(TAICPU(fSecondJump))^.ref^.symbol.decrefs;
            fOptimizer.RemoveInstruction(fSecondJump);
            TAICPU(fThirdJump).condition := condition;
          end;
        else
          InternalError(2023110721);
      end;

      { Now we can safely decrement the reference count }
      TAsmLabel(fLabel).decrefs;

      fOptimizer.UpdateUsedRegs(TAI(fInitialJump.next));

      { Remove the original jump }
      fOptimizer.RemoveInstruction(fInitialJump); { Note, the choice to not use RemoveCurrentp is deliberate }

      new_p := fFirstMovBlock; { Appears immediately after the initial jump }

      fState := tsProcessed;
    end;

begin
  casmoptimizer:=TCpuAsmOptimizer;
End.

