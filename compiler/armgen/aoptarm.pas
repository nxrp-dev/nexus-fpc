{
    Copyright (c) 1998-2020 by Jonas Maebe and Florian Klaempfl, members of the Free Pascal
    Development Team

    This unit implements the AArch64 assembly optimizer

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

Unit aoptarm;

{$i fpcdefs.inc}

{ $define DEBUG_PREREGSCHEDULER}
{$ifdef EXTDEBUG}
{$define DEBUG_AOPTCPU}
{$endif EXTDEBUG}

Interface

uses
  cgbase, cgutils, GlobType, cpubase, aasmtai, aasmcpu,aopt, aoptobj;

Type
  { while ARM and AAarch64 look not very similar at a first glance,
    several optimizations can be shared between both }
  TARMAsmOptimizer = class(TAsmOptimizer)
    procedure DebugMsg(const s : string; p : TAI);

    function RegEndOfLife(reg: TRegister;p: TAICPU): boolean; override;

    function RemoveSuperfluousMove(const p: TAI; movp: TAI; const optimizer: string): boolean;
    function RedundantMovProcess(var p: TAI; var hp1: TAI): boolean;
    function GetNextInstructionUsingReg(Current: TAI; out Next: TAI; const reg: TRegister): Boolean;
    function USxtOp2Op(var p, hp1: TAI; ShiftMode: TShiftMode): Boolean;
    function OptPreSBFXUBFX(var p: TAI): Boolean;

    function OptPass1UXTB(var p: TAI): Boolean;
    function OptPass1UXTH(var p: TAI): Boolean;
    function OptPass1SXTB(var p: TAI): Boolean;
    function OptPass1SXTH(var p: TAI): Boolean;

    function OptPass1LDR(var p: TAI): Boolean; virtual;
    function OptPass1STR(var p: TAI): Boolean; virtual;
    function OptPass1And(var p: TAI): Boolean; virtual;

    function OptPass2Bitwise(var p: TAI): Boolean;
    function OptPass2TST(var p: TAI): Boolean;

    { Common code that tries to merge constant writes to sequential memory }
    function TryConstMerge(var p: TAI; hp1: TAI): Boolean;

  protected
    function DoXTArithOp(var p: TAI; hp1: TAI): Boolean;
  End;

  function MatchInstruction(const instr: TAI; const op: TCommonAsmOps; const cond: TAsmConds; const postfix: TOpPostfixes): boolean;
  function MatchInstruction(const instr: TAI; const op: TAsmOp; const cond: TAsmConds; const postfix: TOpPostfixes): boolean;
  function MatchInstruction(const instr: TAI; const ops : array of TAsmOp; const postfix: TOpPostfixes): boolean;
  function MatchInstruction(const instr: TAI; const op: TAsmOp; const postfix: TOpPostfixes): boolean;

  function RefsEqual(const r1, r2: TReference): boolean;

  function MatchOperand(const oper: TOper; const reg: TRegister): boolean; inline;
  function MatchOperand(const oper1: TOper; const oper2: TOper): boolean; inline;
  function MatchOperand(const oper: TOper; const a: TCGInt): boolean; inline;

Implementation

  uses
    TPCompilerReal,CUtils,Verbose,Globals,aoptutils,
    Systems,
    CPUInfo,
    cgobj,ProcInfo,
    aasmbase,AAsmData,itcpugas;


{$ifdef DEBUG_AOPTCPU}
  const
    SPeepholeOptimization: shortstring = 'Peephole Optimization: ';

  procedure TARMAsmOptimizer.DebugMsg(const s: string;p : TAI);
    begin
      asml.insertbefore(TAIComment.Create(StrPNew(s)), p);
    end;
{$else DEBUG_AOPTCPU}
  { Empty strings help the optimizer to remove string concatenations that won't
    ever appear to the user on release builds. [Kit] }
  const
    SPeepholeOptimization = '';

  procedure TARMAsmOptimizer.DebugMsg(const s: string;p : TAI);inline;
    begin
    end;
{$endif DEBUG_AOPTCPU}

  function MatchInstruction(const instr: TAI; const op: TCommonAsmOps; const cond: TAsmConds; const postfix: TOpPostfixes): boolean;
    begin
      result :=
        (instr.typ = ait_instruction) and
        ((op = []) or ((TAICPU(instr).opcode<=LastCommonAsmOp) and (TAICPU(instr).opcode in op))) and
        ((cond = []) or (TAICPU(instr).condition in cond)) and
        ((postfix = []) or (TAICPU(instr).oppostfix in postfix));
    end;


  function MatchInstruction(const instr: TAI; const op: TAsmOp; const cond: TAsmConds; const postfix: TOpPostfixes): boolean;
    begin
      result :=
        (instr.typ = ait_instruction) and
        (TAICPU(instr).opcode = op) and
        ((cond = []) or (TAICPU(instr).condition in cond)) and
        ((postfix = []) or (TAICPU(instr).oppostfix in postfix));
    end;


  function MatchInstruction(const instr: TAI; const ops : array of TAsmOp; const postfix: TOpPostfixes): boolean;
  var
    op : TAsmOp;
  begin
    result:=false;
    if instr.typ <> ait_instruction then
      exit;
    for op in ops do
      begin
        if (TAICPU(instr).opcode = op) and
           ((postfix = []) or (TAICPU(instr).oppostfix in postfix)) then
          begin
            result:=true;
            exit;
          end;
      end;
    end;

  function MatchInstruction(const instr: TAI; const op: TAsmOp; const postfix: TOpPostfixes): boolean;
    begin
      result :=
        (instr.typ = ait_instruction) and
        (TAICPU(instr).opcode = op) and
        ((postfix = []) or (TAICPU(instr).oppostfix in postfix));
    end;


  function MatchOperand(const oper: TOper; const reg: TRegister): boolean; inline;
    begin
      result := (oper.typ = top_reg) and (oper.reg = reg);
    end;


  function RefsEqual(const r1, r2: TReference): boolean;
    begin
      refsequal :=
        (r1.Offset = r2.Offset) and
        (r1.Base = r2.Base) and
        (r1.Index = r2.Index) and (r1.ScaleFactor = r2.ScaleFactor) and
        (r1.Symbol=r2.Symbol) and (r1.RefAddr = r2.RefAddr) and
        (r1.RelSymbol = r2.RelSymbol) and
        (r1.ShiftImm = r2.ShiftImm) and
        (r1.AddressMode = r2.AddressMode) and
        (r1.ShiftMode = r2.ShiftMode) and
        (r1.Volatility=[]) and
        (r2.Volatility=[]);
    end;


  function MatchOperand(const oper1: TOper; const oper2: TOper): boolean; inline;
    begin
      result := oper1.typ = oper2.typ;

      if result then
        case oper1.typ of
          top_const:
            Result:=oper1.Val = oper2.Val;
          top_reg:
            Result:=oper1.reg = oper2.reg;
          top_conditioncode:
            Result:=oper1.cc = oper2.cc;
          top_realconst:
            Result:=oper1.val_real = oper2.val_real;
          top_ref:
            Result:=RefsEqual(oper1.Ref^, oper2.Ref^);
          else Result:=false;
        end
    end;


  function MatchOperand(const oper: TOper; const a: TCGInt): boolean; inline;
    begin
      result := (oper.typ = top_const) and (oper.Val = a);
    end;


  function TARMAsmOptimizer.RegEndOfLife(reg: TRegister;p: TAICPU): boolean;
    var
      i: Integer;
      RegWritten: Boolean;
    begin
      Result:=Assigned(FindRegDealloc(reg,TAI(p.Next)));
      if Result then
        Exit;

      RegWritten:=False;
      for i:=0 to p.ops-1 do
        begin
          case TAICPU(p).oper[i]^.typ of
            top_indexedreg,
            top_reg,
            top_regset:
              if RegInOp(reg,TAICPU(p).oper[i]^) then
                case TAICPU(p).spilling_get_operation_type(i) of
                  operand_read:
                    { Do nothing };

                  operand_write:
                    RegWritten:=True;

                  operand_readwrite:
                    { The register is directly modified, so it isn't end-of-life }
                    Exit;
                end;

            else
              { If a register is modified by a reference via pre- or
                post-indexing, its value gets overwritten anyway if it is
                directly written to in another operator, i.e. if RegWritten is
                set to True) };
          end;
        end;
      Result:=RegWritten;
    end;

  function TARMAsmOptimizer.USxtOp2Op(var p,hp1: TAI; ShiftMode: TShiftMode): Boolean;
    var
      so: TShifterOp;
      opoffset: Integer;
    begin
      Result:=false;
      if ((MatchInstruction(hp1, [A_ADD,A_SUB], [C_None], [PF_None,PF_S]) and
        (TAICPU(hp1).ops=3) and
         MatchOperand(TAICPU(hp1).oper[2]^, TAICPU(p).oper[0]^.reg) and
         not(MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg))) or
         (MatchInstruction(hp1, [A_CMP,A_CMN], [C_None], [PF_None]) and
         (TAICPU(hp1).ops=2) and
         MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg))
        ) and
        RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
        { reg1 must not be modified in between }
        not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
        begin
          DebugMsg(SPeepholeOptimization+gas_op2str[TAICPU(p).opcode]+gas_op2str[TAICPU(hp1).opcode]+'2'+gas_op2str[TAICPU(hp1).opcode]+' done', p);
          AllocRegBetween(TAICPU(p).oper[1]^.reg,p,hp1,UsedRegs);
          if MatchInstruction(hp1, [A_CMP,A_CMN], [C_None], [PF_None]) then
            opoffset:=0
          else
            opoffset:=1;
          TAICPU(hp1).LoadReg(opoffset+1,TAICPU(p).oper[1]^.reg);
          if not(ShiftMode in [SM_SXTX,SM_UXTX,SM_LSL]) then
            SetSubReg(TAICPU(hp1).oper[opoffset+1]^.reg,R_SUBD);
          TAICPU(hp1).ops:=opoffset+3;
          shifterop_reset(so);
          so.ShiftMode:=ShiftMode;
          so.ShiftImm:=0;
          TAICPU(hp1).loadshifterop(opoffset+2,so);
          result:=RemoveCurrentP(p);
        end;
    end;


  function TARMAsmOptimizer.GetNextInstructionUsingReg(Current: TAI;
    Out Next: TAI; const reg: TRegister): Boolean;
    var
      gniResult: Boolean;
    begin
      Next:=Current;
      Result := False;
      repeat

        gniResult:=GetNextInstruction(Next,Next);
        if gniResult and RegInInstruction(reg,Next) then
          { Found something }
          Exit(True);

      until not gniResult or
        not(cs_opt_level3 in CurrentSettings.OptimizerSwitches) or
        (Next.typ<>ait_instruction) or
        is_calljmp(TAICPU(Next).opcode)
        ;
    end;


  function TARMAsmOptimizer.RemoveSuperfluousMove(const p: TAI; movp: TAI; const optimizer: string):boolean;
    var
      alloc,
      dealloc : TAIRegAlloc;
      hp1 : TAI;
    begin
      Result:=false;
      if MatchInstruction(movp, A_MOV, [TAICPU(p).condition], [PF_None]) and
        { We can't optimize if there is a shiftop }
        (TAICPU(movp).ops=2) and
        MatchOperand(TAICPU(movp).oper[1]^, TAICPU(p).oper[0]^.reg) and
        { don't mess with moves to fp }
        (TAICPU(movp).oper[0]^.reg<>CurrentProcInfo.FramePointer) and
        { the destination register of the mov might not be used between p and movp }
        not(RegUsedBetween(TAICPU(movp).oper[0]^.reg,p,movp)) and
        { Take care to only do this for instructions which REALLY load to the first register.
          Otherwise
            str reg0, [reg1]
            mov reg2, reg0
          will be optimized to
            str reg2, [reg1]
        }
        (TAICPU(p).spilling_get_operation_type(0) = operand_write) then
        begin
          dealloc:=FindRegDeAlloc(TAICPU(p).oper[0]^.reg,TAI(movp.Next));
          if Assigned(dealloc) then
            begin
              DebugMsg(SPeepholeOptimization + optimizer +' removed superfluous mov', movp);
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

              AllocRegBetween(TAICPU(movp).oper[0]^.reg,p,movp,UsedRegs);

              { finally get rid of the mov }
              TAICPU(p).LoadReg(0,TAICPU(movp).oper[0]^.reg);
              { Remove preindexing and postindexing for LDR in some cases.
                For example:
                  ldr	reg2,[reg1, xxx]!
                  mov reg1,reg2
                must be translated to:
                  ldr	reg1,[reg1, xxx]

                Preindexing must be removed there, since the same register is used as the base and as the target.
                Such case is not allowed for ARM CPU and produces crash. }
              if (TAICPU(p).opcode = A_LDR) and (TAICPU(p).oper[1]^.typ = top_ref)
                and (TAICPU(movp).oper[0]^.reg = TAICPU(p).oper[1]^.Ref^.Base)
              then
                TAICPU(p).oper[1]^.Ref^.AddressMode:=AM_OFFSET;
              asml.remove(movp);
              movp.free;
            end;
        end;
    end;


  function TARMAsmOptimizer.RedundantMovProcess(var p: TAI; var hp1: TAI):boolean;
    var
      I: Integer;
      current_hp, next_hp: TAI;
      LDRChange: Boolean;
    begin
      Result:=false;
      {
        change
        mov r1, r0
        add r1, r1, #1
        to
        add r1, r0, #1

        Todo: Make it work for mov+cmp too

        CAUTION! If this one is successful p might not be a mov instruction anymore!
      }
      if (TAICPU(p).ops = 2) and
         (TAICPU(p).oper[1]^.typ = top_reg) and
         (TAICPU(p).oppostfix = PF_NONE) then
        begin

          if
            MatchInstruction(hp1, [A_ADD, A_ADC,
                                   A_EON,
                                   A_SUB, A_SBC,
                                   A_AND, A_BIC, A_EOR, A_ORN, A_ORR,
                                   A_MOV, A_MVN],
                             [TAICPU(p).condition], []) and
            { MOV and MVN might only have 2 ops }
            (TAICPU(hp1).ops >= 2) and
            MatchOperand(TAICPU(p).oper[0]^, TAICPU(hp1).oper[0]^.reg) and
            (TAICPU(hp1).oper[1]^.typ = top_reg) and
            (
              (TAICPU(hp1).ops = 2) or
              (TAICPU(hp1).oper[2]^.typ in [top_reg, top_const, top_shifterop])
            ) and
            (TAICPU(p).oper[1]^.reg<>NR_SP) and
            { in this case you have to transform it to movk or the like }
            (GetSupReg(TAICPU(p).oper[1]^.reg)<>RS_XZR) and
            not(RegUsedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
            begin
              { When we get here we still don't know if the registers match }
              for I:=1 to 2 do
                {
                  If the first loop was successful p will be replaced with hp1.
                  The checks will still be ok, because all required information
                  will also be in hp1 then.
                }
                if (TAICPU(hp1).ops > I) and
                   MatchOperand(TAICPU(p).oper[0]^, TAICPU(hp1).oper[I]^.reg)

                then
                  begin
                    DebugMsg('Peephole RedundantMovProcess done', hp1);
                    TAICPU(hp1).oper[I]^.reg := TAICPU(p).oper[1]^.reg;
                    if p<>hp1 then
                      begin
                        asml.remove(p);
                        p.free;
                        p:=hp1;
                        Result:=true;
                      end;
                  end;

              if Result then Exit;
            end
          { Change:                   Change:
              mov     r1, r0            mov     r1, r0
              ...                       ...
              ldr/str r2, [r1, etc.]    mov     r2, r1
            To:                       To:
              ldr/str r2, [r0, etc.]    mov     r2, r0
          }
          else if (TAICPU(p).condition = C_None) and (TAICPU(p).oper[1]^.typ = top_reg)
            and (GetSupReg(TAICPU(p).oper[0]^.reg) <> RS_STACK_POINTER_REG)
            then
            begin
              current_hp := p;
              TransferUsedRegs(TmpUsedRegs);

              { Search local instruction block }
              while GetNextInstruction(current_hp, next_hp) and (next_hp <> BlockEnd) and (next_hp.typ = ait_instruction) do
                begin
                  UpdateUsedRegs(TmpUsedRegs, TAI(current_hp.Next));
                  LDRChange := False;

                  if (TAICPU(next_hp).opcode in [A_LDR,A_STR]) and (TAICPU(next_hp).ops = 2)
                    { If r0 is the zero register, then this sequence of instructions will cause
                      an access violation, but that's better than an assembler error caused by
                      changing r0 to xzr inside the reference (Where it's illegal). [Kit] }
                    and (GetSupReg(TAICPU(p).oper[1]^.reg) <> RS_XZR)
                    then
                    begin

                      { Change the registers from r1 to r0 }
                      if (TAICPU(next_hp).oper[1]^.Ref^.Base = TAICPU(p).oper[0]^.reg) and
                        { Don't mess around with the base register if the
                          reference is pre- or post-indexed }
                        (TAICPU(next_hp).oper[1]^.Ref^.AddressMode = AM_OFFSET) then
                        begin
                          TAICPU(next_hp).oper[1]^.Ref^.Base := TAICPU(p).oper[1]^.reg;
                          LDRChange := True;
                        end;

                      if TAICPU(next_hp).oper[1]^.Ref^.Index = TAICPU(p).oper[0]^.reg then
                        begin
                          TAICPU(next_hp).oper[1]^.Ref^.Index := TAICPU(p).oper[1]^.reg;
                          LDRChange := True;
                        end;

                      if LDRChange then
                        DebugMsg('Peephole Optimization: ' + std_regname(TAICPU(p).oper[0]^.reg) + ' = ' + std_regname(TAICPU(p).oper[1]^.reg) + ' (MovLdr2Ldr 1)', next_hp);

                      { Drop out if we're dealing with pre-indexed references }
                      if (TAICPU(next_hp).oper[1]^.Ref^.AddressMode = AM_PREINDEXED) and
                        (
                          RegInRef(TAICPU(p).oper[0]^.reg, TAICPU(next_hp).oper[1]^.Ref^) or
                          RegInRef(TAICPU(p).oper[1]^.reg, TAICPU(next_hp).oper[1]^.Ref^)
                        ) then
                        begin
                          { Remember to update register allocations }
                          if LDRChange then
                            AllocRegBetween(TAICPU(p).oper[1]^.reg, p, next_hp, UsedRegs);

                          Break;
                        end;

                      { The register being stored can be potentially changed (as long as it's not the stack pointer) }
                      if (TAICPU(next_hp).opcode = A_STR) and (GetSupReg(TAICPU(p).oper[1]^.reg) <> RS_STACK_POINTER_REG) and
                        MatchOperand(TAICPU(next_hp).oper[0]^, TAICPU(p).oper[0]^.reg) then
                        begin
                          DebugMsg('Peephole Optimization: ' + std_regname(TAICPU(p).oper[0]^.reg) + ' = ' + std_regname(TAICPU(p).oper[1]^.reg) + ' (MovLdr2Ldr 2)', next_hp);
                          TAICPU(next_hp).oper[0]^.reg := TAICPU(p).oper[1]^.reg;
                          LDRChange := True;
                        end;

                      if LDRChange and (GetSupReg(TAICPU(p).oper[1]^.reg) <> RS_STACK_POINTER_REG) then
                        begin
                          AllocRegBetween(TAICPU(p).oper[1]^.reg, p, next_hp, UsedRegs);
                          if (TAICPU(p).oppostfix = PF_None) and
                            (
                              (
                                (TAICPU(next_hp).opcode = A_LDR) and
                                MatchOperand(TAICPU(next_hp).oper[0]^, TAICPU(p).oper[0]^.reg)
                              ) or
                              not RegUsedAfterInstruction(TAICPU(p).oper[0]^.reg, next_hp, TmpUsedRegs)
                            ) and
                            { Double-check to see if the old registers were actually
                              changed (e.g. if the super registers matched, but not
                              the sizes, they won't be changed). }
                            (
                              (TAICPU(next_hp).opcode = A_LDR) or
                              not RegInOp(TAICPU(p).oper[0]^.reg, TAICPU(next_hp).oper[0]^)
                            ) and
                            not RegInRef(TAICPU(p).oper[0]^.reg, TAICPU(next_hp).oper[1]^.Ref^) then
                            begin
                              DebugMsg('Peephole Optimization: RedundantMovProcess 2a done', p);
                              RemoveCurrentP(p);
                              Result := True;
                              Exit;
                            end;
                        end;
                    end
                  else if (TAICPU(next_hp).opcode = A_MOV) and (TAICPU(next_hp).oppostfix = PF_None) and
                    (TAICPU(next_hp).ops = 2) then
                    begin
                      if MatchOperand(TAICPU(next_hp).oper[0]^, TAICPU(p).oper[0]^.reg) then
                        begin
                          { mov r0,r1; mov r1,r1 - remove second MOV here so
                            so "RedundantMovProcess 2b" doesn't get erroneously
                            applied }
                          if MatchOperand(TAICPU(next_hp).oper[0]^, TAICPU(next_hp).oper[1]^.reg) then
                            begin
                              DebugMsg(SPeepholeOptimization + 'Mov2None 2a done', next_hp);

                              if (next_hp = hp1) then
                                { Don't let hp1 become a dangling pointer }
                                hp1 := nil;

                              asml.Remove(next_hp);
                              next_hp.Free;
                              Continue;
                            end;

                          { Found another mov that writes entirely to the register }
                          if RegUsedBetween(TAICPU(p).oper[0]^.reg, p, next_hp) then
                            begin
                              { Register was used beforehand }
                              if MatchOperand(TAICPU(next_hp).oper[1]^, TAICPU(p).oper[1]^.reg) then
                                begin
                                  { This MOV is exactly the same as the first one.
                                    Since none of the registers have changed value
                                    at this point, we can remove it. }
                                  DebugMsg(SPeepholeOptimization + 'RedundantMovProcess 3a done', next_hp);

                                  if (next_hp = hp1) then
                                    { Don't let hp1 become a dangling pointer }
                                    hp1 := nil;

                                  asml.Remove(next_hp);
                                  next_hp.Free;

                                  { We still have the original p, so we can continue optimising;
                                   if it was -O2 or below, this instruction appeared immediately
                                   after the first MOV, so we're technically not looking more
                                   than one instruction ahead after it's removed! [Kit] }
                                  Continue;
                                end
                              else
                                { Register changes value - drop out }
                                Break;
                            end;

                          { We can delete the first MOV (only if the second MOV is unconditional) }
                            begin
                              DebugMsg('Peephole Optimization: RedundantMovProcess 2b done', p);
                              RemoveCurrentP(p);
                              Result := True;
                            end;
                          Exit;
                        end
                      else if MatchOperand(TAICPU(next_hp).oper[1]^, TAICPU(p).oper[0]^.reg) then
                        begin
                          if MatchOperand(TAICPU(next_hp).oper[0]^, TAICPU(p).oper[1]^.reg)
                            { Be careful - if the entire register is not used, removing this
                              instruction will leave the unused part uninitialised }
                            and (GetSubReg(TAICPU(p).oper[1]^.reg) = R_SUBQ)
                            then
                            begin
                              { Instruction will become mov r1,r1 }
                              DebugMsg(SPeepholeOptimization + 'Mov2None 2 done', next_hp);

                              { Allocate r1 between the instructions; not doing
                                so may cause problems when removing superfluous
                                MOVs later (i38055) }
                              AllocRegBetween(TAICPU(p).oper[1]^.reg, p, next_hp, UsedRegs);

                              if (next_hp = hp1) then
                                { Don't let hp1 become a dangling pointer }
                                hp1 := nil;

                              asml.Remove(next_hp);
                              next_hp.Free;
                              Continue;
                            end;

                          { Change the old register (checking the first operand again
                            forces it to be left alone if the full register is not
                            used, lest mov w1,w1 gets optimised out by mistake. [Kit] }
                          if not MatchOperand(TAICPU(next_hp).oper[0]^, TAICPU(p).oper[1]^.reg) then
                            begin
                              DebugMsg(SPeepholeOptimization + std_regname(TAICPU(p).oper[0]^.reg) + ' = ' + std_regname(TAICPU(p).oper[1]^.reg) + ' (MovMov2Mov 2)', next_hp);
                              TAICPU(next_hp).oper[1]^.reg := TAICPU(p).oper[1]^.reg;
                              AllocRegBetween(TAICPU(p).oper[1]^.reg, p, next_hp, UsedRegs);

                              { If this was the only reference to the old register,
                                then we can remove the original MOV now }

                              if (TAICPU(p).oppostfix = PF_None) and
                                { A bit of a hack - sometimes registers aren't tracked properly, so do not
                                  remove if the register was apparently not allocated when its value is
                                  first set at the MOV command (this is especially true for the stack
                                  register). [Kit] }
                                (GetSupReg(TAICPU(p).oper[1]^.reg) <> RS_STACK_POINTER_REG) and
                                RegInUsedRegs(TAICPU(p).oper[0]^.reg, UsedRegs) and
                                not RegUsedAfterInstruction(TAICPU(p).oper[0]^.reg, next_hp, TmpUsedRegs) then
                                begin
                                  DebugMsg(SPeepholeOptimization + 'RedundantMovProcess 2c done', p);
                                  RemoveCurrentP(p);
                                  Result := True;
                                  Exit;
                                end;
                            end;
                        end;
                    end;

                  { On low optimisation sections, don't search more than one instruction ahead }
                  if not(cs_opt_level3 in CurrentSettings.OptimizerSwitches) or
                    { Stop at procedure calls and jumps }
                    is_calljmp(TAICPU(next_hp).opcode) or
                    { If the read register has changed value, or the MOV
                      destination register has been used, drop out }
                    RegInInstruction(TAICPU(p).oper[0]^.reg, next_hp) or
                    RegModifiedByInstruction(TAICPU(p).oper[1]^.reg, next_hp) then
                    Break;

                  current_hp := next_hp;
                end;
            end;
        end;
    end;


  function TARMAsmOptimizer.DoXTArithOp(var p: TAI; hp1: TAI): Boolean;
    var
      hp2: TAI;
      ConstLimit: TCGInt;
      ValidPostFixes: TOpPostfixes;
      FirstCode, SecondCode, ThirdCode, FourthCode: TAsmOp;
    begin
      Result := False;
      { Change:
          uxtb/h reg1,reg1
          (operation on reg1 with immediate operand where the upper 24/56
          bits don't affect the state of the first 8 bits )
          uxtb/h reg1,reg1

        Remove first uxtb/h
      }
      case TAICPU(p).opcode of
        A_UXTB,
        A_SXTB:
          begin
            ConstLimit := $FF;
            ValidPostFixes := [PF_B];
            FirstCode := A_UXTB;
            SecondCode := A_SXTB;
            ThirdCode := A_UXTB; { Used to indicate no other valid codes }
            FourthCode := A_SXTB;
          end;
        A_UXTH,
        A_SXTH:
          begin
            ConstLimit := $FFFF;
            ValidPostFixes := [PF_B, PF_H];
            FirstCode := A_UXTH;
            SecondCode := A_SXTH;
            ThirdCode := A_UXTB;
            FourthCode := A_SXTB;
          end;
        else
          InternalError(2024051401);
      end;


      if
        (TAICPU(p).oper[1]^.reg = TAICPU(p).oper[0]^.reg) and
        MatchInstruction(hp1, [A_ADD, A_SUB, A_MUL, A_LSL, A_AND, A_ORR, A_EOR, A_BIC, A_ORN, A_EON], [PF_None]) and
        (TAICPU(hp1).condition = C_None) and
        (TAICPU(hp1).ops = 3) and
        (TAICPU(hp1).oper[0]^.reg = TAICPU(p).oper[0]^.reg) and
        (TAICPU(hp1).oper[1]^.reg = TAICPU(p).oper[0]^.reg) and
        (TAICPU(hp1).oper[2]^.typ = top_const) and
        (
          (
            { If the AND immediate is 8-bit, then this essentially performs
              the functionality of the second UXTB and so its presence is
              not required }
            (TAICPU(hp1).opcode = A_AND) and
            (TAICPU(hp1).oper[2]^.Val >= 0) and
            (TAICPU(hp1).oper[2]^.Val <= ConstLimit)
          ) or
          (
            GetNextInstructionUsingReg(hp1,hp2,TAICPU(p).oper[0]^.reg) and
            (hp2.typ = ait_instruction) and
            (TAICPU(hp2).ops = 2) and
            (TAICPU(hp2).condition = C_None) and
            (
              (
                (TAICPU(hp2).opcode in [FirstCode, SecondCode, ThirdCode, FourthCode]) and
                (TAICPU(hp2).oppostfix = PF_None) and
                (TAICPU(hp2).oper[1]^.reg = TAICPU(p).oper[0]^.reg)
                { Destination is allowed to be different in this case, but
                  only if the source is no longer in use (it being the same as
                  the source is covered by RegEndOfLife as well) }
              ) or
              (
                { STRB essentially fills the same role as the second UXTB
                  as long as the register is deallocated afterwards }
                MatchInstruction(hp2, A_STR, [C_None], ValidPostFixes) and
                (TAICPU(hp2).oper[0]^.reg = TAICPU(p).oper[0]^.reg) and
                not RegInOp(TAICPU(p).oper[0]^.reg, TAICPU(hp2).oper[1]^)
              )
            ) and
            RegEndOfLife(TAICPU(p).oper[0]^.reg, TAICPU(hp2))
          )
        ) then
        begin
          DebugMsg(SPeepholeOptimization + 'S/Uxtb/hArithUxtb/h2ArithS/Uxtb/h done', p);
          Result := RemoveCurrentP(p);

          { Simplify bitwise constants if able }
          if (TAICPU(hp1).opcode in [A_AND, A_ORR, A_EOR, A_BIC, A_ORN, A_EON]) and
            is_shifter_const(TAICPU(hp1).oper[2]^.Val and ConstLimit, OS_32) then
            TAICPU(hp1).oper[2]^.Val := TAICPU(hp1).oper[2]^.Val and ConstLimit;
        end;
    end;


  function TARMAsmOptimizer.OptPass1UXTB(var p : TAI) : Boolean;
    var
      hp1, hp2: TAI;
      so: TShifterOp;
    begin
      Result:=false;
      if GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) and
        (TAICPU(p).oppostfix = PF_None) and
        (TAICPU(p).ops = 2) then
        begin
          if (TAICPU(p).condition = C_None) then
            begin
              {
                change
                uxtb reg2,reg1
                strb reg2,[...]
                dealloc reg2
                to
                strb reg1,[...]
              }
              if MatchInstruction(hp1, A_STR, [C_None], [PF_B]) and
                Assigned(FindRegDealloc(TAICPU(p).oper[0]^.reg,TAI(hp1.Next))) and
                { the reference in strb might not use reg2 }
                not(RegInRef(TAICPU(p).oper[0]^.reg,TAICPU(hp1).oper[1]^.Ref^)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole UxtbStrb2Strb done', p);
                  TAICPU(hp1).LoadReg(0,TAICPU(p).oper[1]^.reg);
                  result:=RemoveCurrentP(p);
                end
              {
                change
                uxtb reg2,reg1
                uxth reg3,reg2
                dealloc reg2
                to
                uxtb reg3,reg1
              }
              else if MatchInstruction(hp1, A_UXTH, [C_None], [PF_None]) and
                (TAICPU(hp1).ops = 2) and
                MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole UxtbUxth2Uxtb done', p);
                  AllocRegBetween(TAICPU(hp1).oper[0]^.reg,p,hp1,UsedRegs);
                  TAICPU(p).LoadReg(0,TAICPU(hp1).oper[0]^.reg);
                  asml.remove(hp1);
                  hp1.free;
                  result:=true;
                end
              {
                change
                uxtb reg2,reg1
                uxtb reg3,reg2
                dealloc reg2
                to
                uxtb reg3,reg1
              }
              else if MatchInstruction(hp1, A_UXTB, [C_None], [PF_None]) and
                (TAICPU(hp1).ops = 2) and
                MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole UxtbUxtb2Uxtb done', p);
                  AllocRegBetween(TAICPU(hp1).oper[0]^.reg,p,hp1,UsedRegs);
                  TAICPU(p).LoadReg(0,TAICPU(hp1).oper[0]^.reg);
                  asml.remove(hp1);
                  hp1.free;
                  result:=true;
                end
              {
                change
                uxtb reg2,reg1
                and reg3,reg2,#0x*FF
                dealloc reg2
                to
                uxtb reg3,reg1
              }
              else if MatchInstruction(hp1, A_AND, [C_None], [PF_None]) and
                (TAICPU(hp1).ops=3) and
                (TAICPU(hp1).oper[2]^.typ=top_const) and
                ((TAICPU(hp1).oper[2]^.Val and $FF)=$FF) and
                MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole UxtbAndImm2Uxtb done', p);
                  TAICPU(hp1).opcode:=A_UXTB;
                  TAICPU(hp1).ops:=2;
                  TAICPU(hp1).LoadReg(1,TAICPU(p).oper[1]^.reg);
                  result:=RemoveCurrentP(p);
                end
              else if DoXTArithOp(p, hp1) then
                Result:=true
              else if USxtOp2Op(p,hp1,SM_UXTB) then
                Result:=true
            end;

          { Condition doesn't have to be C_None }
          if not Result and
            RemoveSuperfluousMove(p, hp1, 'UxtbMov2Uxtb') then
            Result:=true;
        end;
    end;


  function TARMAsmOptimizer.OptPass1UXTH(var p : TAI) : Boolean;
    var
      hp1: TAI;
      so: TShifterOp;
    begin
      Result:=false;
      if GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) and
        (TAICPU(p).oppostfix = PF_None) and
        (TAICPU(p).ops = 2) then
        begin
          if (TAICPU(p).condition = C_None) then
            begin
              {
                change
                uxth reg2,reg1
                strh reg2,[...]
                dealloc reg2
                to
                strh reg1,[...]
              }
              if MatchInstruction(hp1, A_STR, [C_None], [PF_H]) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { the reference in strb might not use reg2 }
                not(RegInRef(TAICPU(p).oper[0]^.reg,TAICPU(hp1).oper[1]^.Ref^)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole UXTHStrh2Strh done', p);
                  TAICPU(hp1).LoadReg(0,TAICPU(p).oper[1]^.reg);
                  result:=RemoveCurrentP(p);
                end
              {
                change
                uxth reg2,reg1
                uxth reg3,reg2
                dealloc reg2
                to
                uxth reg3,reg1
              }
              else if MatchInstruction(hp1, A_UXTH, [C_None], [PF_None]) and
                (TAICPU(hp1).ops=2) and
                MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole UxthUxth2Uxth done', p);
                  AllocRegBetween(TAICPU(p).oper[1]^.reg,p,hp1,UsedRegs);
                  TAICPU(hp1).opcode:=A_UXTH;
                  TAICPU(hp1).LoadReg(1,TAICPU(p).oper[1]^.reg);
                  result:=RemoveCurrentP(p);
                end
              {
                change
                uxth reg2,reg1
                and reg3,reg2,#65535
                dealloc reg2
                to
                uxth reg3,reg1
              }
              else if MatchInstruction(hp1, A_AND, [C_None], [PF_None]) and
                (TAICPU(hp1).ops=3) and
                (TAICPU(hp1).oper[2]^.typ=top_const) and
                ((TAICPU(hp1).oper[2]^.Val and $FFFF)=$FFFF) and
                MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole UxthAndImm2Uxth done', p);
                  TAICPU(hp1).opcode:=A_UXTH;
                  TAICPU(hp1).ops:=2;
                  TAICPU(hp1).LoadReg(1,TAICPU(p).oper[1]^.reg);
                  result:=RemoveCurrentP(p);
                end
              else if DoXTArithOp(p, hp1) then
                Result:=true
              else if USxtOp2Op(p,hp1,SM_UXTH) then
                Result:=true
            end;

          { Condition doesn't have to be C_None }
          if not Result and
            RemoveSuperfluousMove(p, hp1, 'UxthMov2Data') then
            Result:=true;
        end;
    end;


  function TARMAsmOptimizer.OptPass1SXTB(var p : TAI) : Boolean;
    var
      hp1, hp2: TAI;
      so: TShifterOp;
    begin
      Result:=false;
      if GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) and
        (TAICPU(p).oppostfix = PF_None) and
        (TAICPU(p).ops = 2) then
        begin
          if (TAICPU(p).condition = C_None) then
            begin
              {
                change
                sxtb reg2,reg1
                strb reg2,[...]
                dealloc reg2
                to
                strb reg1,[...]
              }
              if MatchInstruction(hp1, A_STR, [C_None], [PF_B]) and
                Assigned(FindRegDealloc(TAICPU(p).oper[0]^.reg,TAI(hp1.Next))) and
                { the reference in strb might not use reg2 }
                not(RegInRef(TAICPU(p).oper[0]^.reg,TAICPU(hp1).oper[1]^.Ref^)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole SxtbStrb2Strb done', p);
                  TAICPU(hp1).LoadReg(0,TAICPU(p).oper[1]^.reg);
                  result:=RemoveCurrentP(p);
                end
              {
                change
                sxtb reg2,reg1
                sxth reg3,reg2
                dealloc reg2
                to
                sxtb reg3,reg1
              }
              else if MatchInstruction(hp1, A_SXTH, [C_None], [PF_None]) and
                (TAICPU(hp1).ops = 2) and
                MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole SxtbSxth2Sxtb done', p);
                  AllocRegBetween(TAICPU(hp1).oper[0]^.reg,p,hp1,UsedRegs);
                  TAICPU(p).LoadReg(0,TAICPU(hp1).oper[0]^.reg);
                  asml.remove(hp1);
                  hp1.free;
                  result:=true;
                end
              {
                change
                sxtb reg2,reg1
                sxtb reg3,reg2
                dealloc reg2
                to
                uxtb reg3,reg1
              }
              else if MatchInstruction(hp1, A_SXTB, [C_None], [PF_None]) and
                (TAICPU(hp1).ops = 2) and
                MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole SxtbSxtb2Sxtb done', p);
                  AllocRegBetween(TAICPU(hp1).oper[0]^.reg,p,hp1,UsedRegs);
                  TAICPU(p).LoadReg(0,TAICPU(hp1).oper[0]^.reg);
                  asml.remove(hp1);
                  hp1.free;
                  result:=true;
                end
              {
                change
                sxtb reg2,reg1
                and reg3,reg2,#0x*FF
                dealloc reg2
                to
                uxtb reg3,reg1
              }
              else if MatchInstruction(hp1, A_AND, [C_None], [PF_None]) and
                (TAICPU(hp1).ops=3) and
                (TAICPU(hp1).oper[2]^.typ=top_const) and
                ((TAICPU(hp1).oper[2]^.Val and $FF)=$FF) and
                MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole SxtbAndImm2Uxtb done', p);
                  TAICPU(hp1).opcode:=A_UXTB;
                  TAICPU(hp1).ops:=2;
                  TAICPU(hp1).LoadReg(1,TAICPU(p).oper[1]^.reg);
                  result:=RemoveCurrentP(p);
                end
              else if DoXTArithOp(p, hp1) then
                Result:=true
              else if USxtOp2Op(p,hp1,SM_SXTB) then
                Result:=true
            end;

          { Condition doesn't have to be C_None }
          if not Result and
            RemoveSuperfluousMove(p, hp1, 'SxtbMov2Sxtb') then
            Result:=true;
        end;
    end;


  function TARMAsmOptimizer.OptPass1SXTH(var p : TAI) : Boolean;
    var
      hp1: TAI;
      so: TShifterOp;
    begin
      Result:=false;
      if GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) and
        (TAICPU(p).oppostfix = PF_None) and
        (TAICPU(p).ops = 2) then
        begin
          if (TAICPU(p).condition = C_None) then
            begin
              {
                change
                sxth reg2,reg1
                strh reg2,[...]
                dealloc reg2
                to
                strh reg1,[...]
              }
              if MatchInstruction(p, TAICPU(p).opcode, [C_None], [PF_None]) and
                (TAICPU(p).ops=2) and
                MatchInstruction(hp1, A_STR, [C_None], [PF_H]) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { the reference in strb might not use reg2 }
                not(RegInRef(TAICPU(p).oper[0]^.reg,TAICPU(hp1).oper[1]^.Ref^)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole SxthStrh2Strh done', p);
                  TAICPU(hp1).LoadReg(0,TAICPU(p).oper[1]^.reg);
                  result:=RemoveCurrentP(p);
                end
              {
                change
                sxth reg2,reg1
                sxth reg3,reg2
                dealloc reg2
                to
                sxth reg3,reg1
              }
              else if MatchInstruction(p, A_SXTH, [C_None], [PF_None]) and
                (TAICPU(p).ops=2) and
                MatchInstruction(hp1, A_SXTH, [C_None], [PF_None]) and
                (TAICPU(hp1).ops=2) and
                MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole SxthSxth2Sxth done', p);
                  AllocRegBetween(TAICPU(p).oper[1]^.reg,p,hp1,UsedRegs);
                  TAICPU(hp1).opcode:=A_SXTH;
                  TAICPU(hp1).LoadReg(1,TAICPU(p).oper[1]^.reg);
                  result:=RemoveCurrentP(p);
                end
              {
                change
                sxth reg2,reg1
                sxtw reg3,reg2
                dealloc reg2
                to
                sxth reg3,reg1
              }
              else if MatchInstruction(p, A_SXTH, [C_None], [PF_None]) and
                (TAICPU(p).ops=2) and
                MatchInstruction(hp1, A_SXTW, [C_None], [PF_None]) and
                (TAICPU(hp1).ops=2) and
                MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole SxthSxtw2Sxth done', p);
                  AllocRegBetween(TAICPU(p).oper[1]^.reg,p,hp1,UsedRegs);
                  TAICPU(hp1).opcode:=A_SXTH;
                  TAICPU(hp1).LoadReg(1,TAICPU(p).oper[1]^.reg);
                  result:=RemoveCurrentP(p);
                end
              {
                change
                sxth reg2,reg1
                and reg3,reg2,#65535
                dealloc reg2
                to
                uxth reg3,reg1
              }
              else if MatchInstruction(p, A_SXTH, [C_None], [PF_None]) and
                (TAICPU(p).ops=2) and
                MatchInstruction(hp1, A_AND, [C_None], [PF_None]) and
                (TAICPU(hp1).ops=3) and
                (TAICPU(hp1).oper[2]^.typ=top_const) and
                ((TAICPU(hp1).oper[2]^.Val and $FFFF)=$FFFF) and
                MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
                RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
                { reg1 might not be modified in between }
                not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole SxthAndImm2Uxth done', p);
                  TAICPU(hp1).opcode:=A_UXTH;
                  TAICPU(hp1).ops:=2;
                  TAICPU(hp1).LoadReg(1,TAICPU(p).oper[1]^.reg);
                  result:=RemoveCurrentP(p);
                end
              else if DoXTArithOp(p, hp1) then
                Result:=true
              else if USxtOp2Op(p,hp1,SM_SXTH) then
                Result:=true
            end;

          { Condition doesn't have to be C_None }
          if not Result and
            RemoveSuperfluousMove(p, hp1, 'SxthMov2Sxth') then
            Result:=true;
        end;
    end;


  function TARMAsmOptimizer.OptPreSBFXUBFX(var p: TAI): Boolean;
    begin
      Result := False;
      { Convert:
          s/ubfx reg1,reg2,#0,#64 (or #32 for 32-bit registers)
        To:
          mov    reg1,reg2
      }
      if (TAICPU(p).oper[2]^.Val = 0) and
        (
          (
            (GetSubReg(TAICPU(p).oper[0]^.reg) = R_SUBQ) and
            (TAICPU(p).oper[3]^.Val = 64)
          ) or
          (
            (GetSubReg(TAICPU(p).oper[0]^.reg) = R_SUBD) and
            (TAICPU(p).oper[3]^.Val = 32)
          )
        )
        then
        begin
          DebugMsg(SPeepholeOptimization + 'SBFX or UBFX -> MOV (full bitfield extract)', p);
          TAICPU(p).opcode := A_MOV;
          TAICPU(p).ops := 2;
          TAICPU(p).clearop(2);
          TAICPU(p).clearop(3);

          Result := True;
          Exit;
        end;
    end;


  function TARMAsmOptimizer.OptPass1LDR(var p : TAI) : Boolean;
    var
      hp1: TAI;
      Reference: TReference;
      NewOp: TAsmOp;
    begin
      Result := False;
      if (TAICPU(p).ops <> 2) or (TAICPU(p).condition <> C_None) then
        Exit;

      Reference := TAICPU(p).oper[1]^.Ref^;
      if (Reference.AddressMode = AM_OFFSET) and
        not RegInRef(TAICPU(p).oper[0]^.reg, Reference) and
        { Delay calling GetNextInstruction for as long as possible }
        GetNextInstruction(p, hp1) and
        (hp1.typ = ait_instruction) and
        (TAICPU(hp1).condition = C_None) and
        (TAICPU(hp1).oppostfix = TAICPU(p).oppostfix) then
        begin
          if (TAICPU(hp1).opcode = A_STR) and
            RefsEqual(TAICPU(hp1).oper[1]^.Ref^, Reference) and
            (GetRegType(TAICPU(p).oper[0]^.reg) = GetRegType(TAICPU(hp1).oper[0]^.reg)) then
            begin
              { With:
                  ldr reg1,[ref]
                  str reg2,[ref]

                If reg1 = reg2, Remove str
              }
              if TAICPU(p).oper[0]^.reg = TAICPU(hp1).oper[0]^.reg then
                begin
                  DebugMsg(SPeepholeOptimization + 'Removed redundant store instruction (load/store -> load/nop)', hp1);
                  RemoveInstruction(hp1);
                  Result := True;
                  Exit;
                end;
            end
          else if (TAICPU(hp1).opcode = A_LDR) and
            RefsEqual(TAICPU(hp1).oper[1]^.Ref^, Reference) then
            begin
              { With:
                  ldr reg1,[ref]
                  ldr reg2,[ref]

                If reg1 = reg2, delete the second ldr
                If reg1 <> reg2, changing the 2nd ldr to a mov might introduce
                  a dependency, but it will likely open up new optimisations, so
                  do it for now and handle any new dependencies later.
              }
              if TAICPU(p).oper[0]^.reg = TAICPU(hp1).oper[0]^.reg then
                begin
                  DebugMsg(SPeepholeOptimization + 'Removed duplicate load instruction (load/load -> load/nop)', hp1);
                  RemoveInstruction(hp1);
                  Result := True;
                  Exit;
                end
              else if
                (GetRegType(TAICPU(p).oper[0]^.reg) = R_INTREGISTER) and
                (GetRegType(TAICPU(hp1).oper[0]^.reg) = R_INTREGISTER) and
                (GetSubReg(TAICPU(p).oper[0]^.reg) = GetSubReg(TAICPU(hp1).oper[0]^.reg)) then
                begin
                  DebugMsg(SPeepholeOptimization + 'Changed second ldr' + oppostfix2str[TAICPU(hp1).oppostfix] + ' to mov (load/load -> load/move)', hp1);
                  TAICPU(hp1).opcode := A_MOV;
                  TAICPU(hp1).oppostfix := PF_None;
                  TAICPU(hp1).LoadReg(1, TAICPU(p).oper[0]^.reg);
                  AllocRegBetween(TAICPU(p).oper[0]^.reg, p, hp1, UsedRegs);
                  Result := True;
                  Exit;
                end;
            end;
        end;
    end;


    function TARMAsmOptimizer.OptPass1STR(var p : TAI) : Boolean;
      var
        hp1: TAI;
        Reference: TReference;
        SizeMismatch: Boolean;
        SrcReg, DstReg: TRegister;
        NewOp: TAsmOp;
      begin
        Result := False;
        if (TAICPU(p).ops <> 2) or (TAICPU(p).condition <> C_None) then
          Exit;

        Reference := TAICPU(p).oper[1]^.Ref^;
        if (Reference.AddressMode = AM_OFFSET) and
          not RegInRef(TAICPU(p).oper[0]^.reg, Reference) and
          { Delay calling GetNextInstruction for as long as possible }
          GetNextInstruction(p, hp1) and
          (hp1.typ = ait_instruction) and
          (TAICPU(hp1).condition = C_None) and
          (TAICPU(hp1).oppostfix = TAICPU(p).oppostfix) and
          (TAICPU(hp1).ops>0) and (TAICPU(hp1).oper[0]^.typ=top_reg) then
          begin
            { Saves constant dereferencing and makes it easier to change the size if necessary }
            SrcReg := TAICPU(p).oper[0]^.reg;
            DstReg := TAICPU(hp1).oper[0]^.reg;

            if (TAICPU(hp1).opcode = A_LDR) and
              RefsEqual(TAICPU(hp1).oper[1]^.Ref^, Reference) and
              (TAICPU(hp1).oper[1]^.Ref^.Volatility=[]) and
              (
                (TAICPU(hp1).oppostfix = TAICPU(p).oppostfix) or
                ((TAICPU(p).oppostfix = PF_B) and (TAICPU(hp1).oppostfix = PF_SB)) or
                ((TAICPU(p).oppostfix = PF_H) and (TAICPU(hp1).oppostfix = PF_SH))
                or ((TAICPU(p).oppostfix = PF_W) and (TAICPU(hp1).oppostfix = PF_SW))
              ) then
              begin
                { With:
                    str reg1,[ref]
                    ldr reg2,[ref]

                  If reg1 = reg2, Remove ldr.
                  If reg1 <> reg2, replace ldr with "mov reg2,reg1"
                }

                if (SrcReg = DstReg) and
                  { e.g. the ldrb in strb/ldrb is not a null operation as it clears the upper 24 bits }
                  (TAICPU(p).oppostfix=PF_None) then
                  begin
                    DebugMsg(SPeepholeOptimization + 'Removed redundant load instruction (store/load -> store/nop)', hp1);
                    RemoveInstruction(hp1);
                    Result := True;
                    Exit;
                  end
                else if (GetRegType(SrcReg) = R_INTREGISTER) and
                  (GetRegType(DstReg) = R_INTREGISTER) and
                  (GetSubReg(SrcReg) = GetSubReg(DstReg)) then
                  begin
                    NewOp:=A_NONE;
                    if TAICPU(hp1).oppostfix=PF_None then
                      NewOp:=A_MOV
                    else
                        case TAICPU(hp1).oppostfix of
                          PF_B:
                            NewOp := A_UXTB;
                          PF_SB:
                            NewOp := A_SXTB;
                          PF_H:
                            NewOp := A_UXTH;
                          PF_SH:
                            NewOp := A_SXTH;
                          PF_SW:
                            NewOp := A_SXTW;
                          PF_W:
                            NewOp := A_MOV;
                        else
                          InternalError(2021043001);
                        end;
                    if (NewOp<>A_None) then
                      begin
                        DebugMsg(SPeepholeOptimization + 'Changed ldr' + oppostfix2str[TAICPU(hp1).oppostfix] + ' to ' + gas_op2str[NewOp] + ' (store/load -> store/move)', hp1);

                        TAICPU(hp1).oppostfix := PF_None;
                        TAICPU(hp1).opcode := NewOp;
                        TAICPU(hp1).LoadReg(1, SrcReg);
                        AllocRegBetween(SrcReg, p, hp1, UsedRegs);
                        Result := True;
                        Exit;
                      end;
                end
              end
            else if (TAICPU(hp1).opcode = A_STR) and
              RefsEqual(TAICPU(hp1).oper[1]^.Ref^, Reference) then
              begin
                { With:
                    str reg1,[ref]
                    str reg2,[ref]

                  If reg1 <> reg2, delete the first str
                  IF reg1 = reg2, delete the second str
                }
                if (SrcReg = DstReg) and (TAICPU(hp1).oper[1]^.Ref^.Volatility=[]) then
                  begin
                    DebugMsg(SPeepholeOptimization + 'Removed duplicate store instruction (store/store -> store/nop)', hp1);
                    RemoveInstruction(hp1);
                    Result := True;
                    Exit;
                  end
                else if
                  { Registers same byte size? }
                  (TCgSize2Size[reg_cgsize(SrcReg)] = TCgSize2Size[reg_cgsize(DstReg)]) and
                  (TAICPU(p).oper[1]^.Ref^.Volatility=[])  then
                  begin
                    DebugMsg(SPeepholeOptimization + 'Removed dominated store instruction (store/store -> nop/store)', p);
                    RemoveCurrentP(p, hp1);
                    Result := True;
                    Exit;
                  end;
              end;
          end;
      end;


  function TARMAsmOptimizer.OptPass1And(var p : TAI) : Boolean;
    var
      hp1, hp2: TAI;
      i: LongInt;
    begin
      Result:=false;
      {
        optimize
        and reg2,reg1,const1
        ...
      }
      if (TAICPU(p).ops>2) and
         (TAICPU(p).oper[1]^.typ = top_reg) and
         (TAICPU(p).oper[2]^.typ = top_const) then
        begin
          {
            change
            and reg2,reg1,const1
            ...
            and reg3,reg2,const2
            to
            and reg3,reg1,(const1 and const2)
          }
          if GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) and
          MatchInstruction(hp1, A_AND, [TAICPU(p).condition], [PF_None]) and
          RegEndOfLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
          MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
          (TAICPU(hp1).oper[2]^.typ = top_const)
          and ((((GetSubReg(TAICPU(p).oper[0]^.reg)=R_SUBQ) and is_shifter_const(TAICPU(p).oper[2]^.Val and TAICPU(hp1).oper[2]^.Val,OS_64)) or
               ((GetSubReg(TAICPU(p).oper[0]^.reg)=R_SUBL) and is_shifter_const(TAICPU(p).oper[2]^.Val and TAICPU(hp1).oper[2]^.Val,OS_32))
          ) or
          ((TAICPU(p).oper[2]^.Val and TAICPU(hp1).oper[2]^.Val)=0))
          then
            begin
              if not(RegUsedBetween(TAICPU(hp1).oper[0]^.reg,p,hp1)) then
                begin
                  DebugMsg('Peephole AndAnd2And done', p);
                  AllocRegBetween(TAICPU(hp1).oper[0]^.reg,p,hp1,UsedRegs);
                  if (TAICPU(p).oper[2]^.Val and TAICPU(hp1).oper[2]^.Val)=0 then
                    begin
                      DebugMsg('Peephole AndAnd2Mov0 1 done', p);
                      TAICPU(p).opcode:=A_MOV;
                      TAICPU(p).ops:=2;
                      TAICPU(p).loadConst(1,0);
                      TAICPU(p).oppostfix:=TAICPU(hp1).oppostfix;
                    end
                  else
                    begin
                      DebugMsg('Peephole AndAnd2And 1 done', p);
                      TAICPU(p).loadConst(2,TAICPU(p).oper[2]^.Val and TAICPU(hp1).oper[2]^.Val);
                      TAICPU(p).oppostfix:=TAICPU(hp1).oppostfix;
                      TAICPU(p).LoadReg(0,TAICPU(hp1).oper[0]^.reg);
                    end;
                  asml.remove(hp1);
                  hp1.free;
                  Result:=true;
                  exit;
                end
              else if not(RegUsedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
                begin
                  if (TAICPU(p).oper[2]^.Val and TAICPU(hp1).oper[2]^.Val)=0 then
                    begin
                      DebugMsg('Peephole AndAnd2Mov0 2 done', hp1);
                      TAICPU(hp1).opcode:=A_MOV;
                      TAICPU(hp1).loadConst(1,0);
                      TAICPU(hp1).ops:=2;
                      TAICPU(hp1).oppostfix:=TAICPU(p).oppostfix;
                    end
                  else
                    begin
                      DebugMsg('Peephole AndAnd2And 2 done', hp1);
                      AllocRegBetween(TAICPU(p).oper[1]^.reg,p,hp1,UsedRegs);
                      TAICPU(hp1).loadConst(2,TAICPU(p).oper[2]^.Val and TAICPU(hp1).oper[2]^.Val);
                      TAICPU(hp1).oppostfix:=TAICPU(p).oppostfix;
                      TAICPU(hp1).LoadReg(1,TAICPU(p).oper[1]^.reg);
                    end;
                  GetNextInstruction(p, hp1);
                  RemoveCurrentP(p);
                  p:=hp1;
                  Result:=true;
                  exit;
                end;
            end
          {
            change
            and reg2,reg1,$xxxxxxFF
            strb reg2,[...]
            dealloc reg2
            to
            strb reg1,[...]
          }
          else if ((TAICPU(p).oper[2]^.Val and $FF) = $FF) and
            MatchInstruction(p, A_AND, [C_None], [PF_None]) and
            GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) and
            MatchInstruction(hp1, A_STR, [C_None], [PF_B]) and
            Assigned(FindRegDealloc(TAICPU(p).oper[0]^.reg,TAI(hp1.Next))) and
            { the reference in strb might not use reg2 }
            not(RegInRef(TAICPU(p).oper[0]^.reg,TAICPU(hp1).oper[1]^.Ref^)) and
            { reg1 might not be modified in between }
            not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
            begin
              DebugMsg('Peephole AndStrb2Strb done', p);
              TAICPU(hp1).LoadReg(0,NewReg(R_INTREGISTER,GetSupReg(TAICPU(p).oper[1]^.reg),R_SUBD));
              AllocRegBetween(TAICPU(p).oper[1]^.reg,p,hp1,UsedRegs);
              RemoveCurrentP(p);
              result:=true;
              exit;
            end
          {
            change
            and reg2,reg1,255
            uxtb/uxth reg3,reg2
            dealloc reg2
            to
            and reg3,reg1,x
          }
          else if MatchInstruction(p, A_AND, [C_None], [PF_None]) and
            GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) and
            ((((TAICPU(p).oper[2]^.Val and $ffffff00)=0) and MatchInstruction(hp1, A_UXTB, [C_None], [PF_None])) or
             (((TAICPU(p).oper[2]^.Val and $ffff0000)=0) and MatchInstruction(hp1, A_UXTH, [C_None], [PF_None]))) and
            (TAICPU(hp1).ops = 2) and
            RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
            MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
            { reg1 might not be modified in between }
            not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
            begin
              DebugMsg('Peephole AndUxt2And done', p);
              TAICPU(hp1).opcode:=A_AND;
              TAICPU(hp1).ops:=3;
              TAICPU(hp1).LoadReg(1,TAICPU(p).oper[1]^.reg);
              TAICPU(hp1).loadconst(2,TAICPU(p).oper[2]^.Val);
              GetNextInstruction(p,hp1);
              asml.remove(p);
              p.Free;
              p:=hp1;
              result:=true;
              exit;
            end
          else if ((TAICPU(p).oper[2]^.Val and $ffffff80)=0) and
            MatchInstruction(p, A_AND, [C_None], [PF_None]) and
            GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) and
            MatchInstruction(hp1, [A_SXTB,A_SXTH], [C_None], [PF_None]) and
            (TAICPU(hp1).ops = 2) and
            RegEndofLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) and
            MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
            { reg1 might not be modified in between }
            not(RegModifiedBetween(TAICPU(p).oper[1]^.reg,p,hp1)) then
            begin
              DebugMsg('Peephole AndSxt2And done', p);
              TAICPU(hp1).opcode:=A_AND;
              TAICPU(hp1).ops:=3;
              TAICPU(hp1).LoadReg(1,TAICPU(p).oper[1]^.reg);
              SetSubReg(TAICPU(hp1).oper[1]^.reg,GetSubReg(TAICPU(hp1).oper[0]^.reg));
              TAICPU(hp1).loadconst(2,TAICPU(p).oper[2]^.Val);
              GetNextInstruction(p,hp1);
              asml.remove(p);
              p.Free;
              p:=hp1;
              result:=true;
              exit;
            end
          {
            from
            and reg1,reg0,2^n-1
            mov reg2,reg1, lsl imm1
            (mov reg3,reg2, lsr/asr imm1)
            remove either the and or the lsl/xsr sequence if possible
          }

          else if (TAICPU(p).oper[2]^.Val < high(int64)) and
	    CUtils.IsPowerOf2(TAICPU(p).oper[2]^.Val+1,i) and
            GetNextInstructionUsingReg(p,hp1,TAICPU(p).oper[0]^.reg) and
            MatchInstruction(hp1, A_MOV, [TAICPU(p).condition], [PF_None]) and
            (TAICPU(hp1).ops=3) and
            MatchOperand(TAICPU(hp1).oper[1]^, TAICPU(p).oper[0]^.reg) and
            (TAICPU(hp1).oper[2]^.typ = top_shifterop) and
            (TAICPU(hp1).oper[2]^.shifterop^.ShiftMode=SM_LSL) and
            RegEndOfLife(TAICPU(p).oper[0]^.reg,TAICPU(hp1)) then
            begin
              {
                and reg1,reg0,2^n-1
                mov reg2,reg1, lsl imm1
                mov reg3,reg2, lsr/asr imm1
                =>
                and reg1,reg0,2^n-1
                if lsr and 2^n-1>=imm1 or asr and 2^n-1>imm1
              }
              if GetNextInstructionUsingReg(hp1,hp2,TAICPU(p).oper[0]^.reg) and
                MatchInstruction(hp2, A_MOV, [TAICPU(p).condition], [PF_None]) and
                (TAICPU(hp2).ops=3) and
                MatchOperand(TAICPU(hp2).oper[1]^, TAICPU(hp1).oper[0]^.reg) and
                (TAICPU(hp2).oper[2]^.typ = top_shifterop) and
                (TAICPU(hp2).oper[2]^.shifterop^.ShiftMode in [SM_ASR,SM_LSR]) and
                (TAICPU(hp1).oper[2]^.shifterop^.ShiftImm=TAICPU(hp2).oper[2]^.shifterop^.ShiftImm) and
                RegEndOfLife(TAICPU(hp1).oper[0]^.reg,TAICPU(hp2)) and
                ((i<32-TAICPU(hp1).oper[2]^.shifterop^.ShiftImm) or
                ((i=32-TAICPU(hp1).oper[2]^.shifterop^.ShiftImm) and
                 (TAICPU(hp2).oper[2]^.shifterop^.ShiftMode=SM_LSR))) then
                begin
                  DebugMsg('Peephole AndLslXsr2And done', p);
                  TAICPU(p).oper[0]^.reg:=TAICPU(hp2).oper[0]^.reg;
                  asml.Remove(hp1);
                  asml.Remove(hp2);
                  hp1.free;
                  hp2.free;
                  result:=true;
                  exit;
                end
              {
                and reg1,reg0,2^n-1
                mov reg2,reg1, lsl imm1
                =>
                mov reg2,reg0, lsl imm1
                if imm1>i
              }
              else if (i>32-TAICPU(hp1).oper[2]^.shifterop^.ShiftImm) and
                      not(RegModifiedBetween(TAICPU(p).oper[1]^.reg, p, hp1)) then
                begin
                  DebugMsg('Peephole AndLsl2Lsl done', p);
                  TAICPU(hp1).oper[1]^.reg:=TAICPU(p).oper[1]^.reg;
                  GetNextInstruction(p, hp1);
                  asml.Remove(p);
                  p.free;
                  p:=hp1;
                  result:=true;
                  exit;
                end
            end;
        end;

      {
        change
        and reg1, ...
        mov reg2, reg1
        to
        and reg2, ...
      }
      if GetNextInstructionUsingReg(p, hp1, TAICPU(p).oper[0]^.reg) and
         (TAICPU(p).ops>=3) and
         RemoveSuperfluousMove(p, hp1, 'DataMov2Data') then
        Result:=true;
    end;


  function TARMAsmOptimizer.OptPass2Bitwise(var p: TAI): Boolean;
    var
      hp1, hp2: TAI;
      WorkingReg: TRegister;
    begin
      Result := False;
      {
        change
        and/bic  reg1, ...
        ...
        cmp      reg1, #0
        b<ne/eq> @Lbl
        to
        ands/bics reg1, ...

        Also:

        and/bic  reg1, ...
        ...
        cmp      reg1, #0
        (reg1 end of life)
        b<ne/eq> @Lbl
        to
        tst  reg1, ...
        or
        bics xzr, reg1, ... under AArch64

        For ARM, also include OR, EOR and ORN
      }
      if (TAICPU(p).condition = C_None) and
        (TAICPU(p).ops>=3) and
        GetNextInstructionUsingReg(p, hp1, TAICPU(p).oper[0]^.reg) and
        MatchInstruction(hp1, A_CMP, [C_None], [PF_None]) and
        MatchOperand(TAICPU(hp1).oper[1]^, 0) and
        (SuperRegistersEqual(TAICPU(hp1).oper[0]^.reg, TAICPU(p).oper[0]^.reg)) and
        (
          (GetSubReg(TAICPU(hp1).oper[0]^.reg) = GetSubReg(TAICPU(p).oper[0]^.reg))
          or
          (
            (TAICPU(p).oper[2]^.typ = top_const) and
            (TAICPU(p).oper[2]^.Val >= 0) and
            (TAICPU(p).oper[2]^.Val <= $FFFFFFFF)
          )
        ) and

        not RegModifiedBetween(NR_DEFAULTFLAGS, p, hp1) and
        GetNextInstruction(hp1, hp2) then
        begin
          if MatchInstruction(hp2, [A_B, A_CMP, A_CMN, A_TST], [C_EQ, C_NE], [PF_None]) then
            begin
              AllocRegBetween(NR_DEFAULTFLAGS, p, hp1, UsedRegs);

              WorkingReg := TAICPU(p).oper[0]^.reg;

              if
                RegEndOfLife(WorkingReg, TAICPU(hp1)) then
                begin
                  if (TAICPU(p).opcode <> A_AND) then
                    begin
                      SetSupReg(TAICPU(p).oper[0]^.reg, RS_XZR);
                      TAICPU(p).oppostfix := PF_S;
                      DebugMsg(SPeepholeOptimization + 'BIC; CMP -> BICS ' + gas_regname(TAICPU(p).oper[0]^.reg), p);
                    end
                  else
                    begin
                      TAICPU(p).opcode := A_TST;
                      TAICPU(p).oppostfix := PF_None;
                      TAICPU(p).LoadReg(0, TAICPU(p).oper[1]^.reg);
                      TAICPU(p).loadoper(1, TAICPU(p).oper[2]^);
                      if (TAICPU(p).ops = 4) then
                        begin
                          { Make sure any shifter operator is also transferred }
                          TAICPU(p).loadshifterop(2, TAICPU(p).oper[3]^.shifterop^);
                          TAICPU(p).ops := 3;
                        end
                      else
                        TAICPU(p).ops := 2;

                      DebugMsg(SPeepholeOptimization + 'AND; CMP -> TST', p);
                    end;
                end
              else
                begin
                  TAICPU(p).oppostfix := PF_S;
                  DebugMsg(SPeepholeOptimization + 'AND/BIC; CMP -> ANDS/BICS', p);
                end;

              RemoveInstruction(hp1);

              { If a temporary register was used for and/cmp before, we might be
                able to deallocate the register so it can be used for other
                optimisations later }
              if (TAICPU(p).opcode = A_TST) and TryRemoveRegAlloc(WorkingReg, p, p) then
                ExcludeRegFromUsedRegs(WorkingReg, UsedRegs);

              Result := True;
              Exit;
            end
          else if
            (hp2.typ = ait_label) or
            { Conditional comparison instructions have already been covered }
            RegModifiedByInstruction(NR_DEFAULTFLAGS, hp2) then
            begin
              { The comparison is a null operation }
              if RegEndOfLife(TAICPU(p).oper[0]^.reg, TAICPU(hp1)) then
                begin
                  DebugMsg(SPeepholeOptimization + 'Bitwise; CMP -> nop', p);
                  RemoveInstruction(hp1);
                  RemoveCurrentP(p);
                end
              else
                begin
                  DebugMsg(SPeepholeOptimization + 'CMP/BIC -> nop', hp1);
                  RemoveInstruction(hp1);
                end;
              Result := True;
              Exit;
            end;
        end;
    end;


  function TARMAsmOptimizer.OptPass2TST(var p: TAI): Boolean;
    var
      hp1, hp2: TAI;
    begin
      Result := False;
      if
        GetNextInstruction(p, hp1) and
        MatchInstruction(hp1, A_B, [C_EQ, C_NE], [PF_None]) and
        GetNextInstructionUsingReg(hp1, hp2, TAICPU(p).oper[0]^.reg) then
        begin
          case TAICPU(hp2).opcode of
            A_AND:
              { Change:
                 tst  r1,##
                 (r2 not in use, or r2 = r1)
                 b.c  .Lbl
                 ...
                 and  r2,r1,##

               Optimise to:
                 ands r2,r1,##
                 b.c  .Lbl
                 ...
              }
              if (TAICPU(hp2).oppostfix in [PF_None, PF_S]) and
                (TAICPU(hp2).ops = TAICPU(p).ops + 1) and
                  not RegInUsedRegs(TAICPU(hp2).oper[0]^.reg, UsedRegs) and
                  MatchOperand(TAICPU(hp2).oper[1]^, TAICPU(p).oper[0]^.reg) and
                  MatchOperand(TAICPU(hp2).oper[2]^, TAICPU(p).oper[1]^) and
                  (
                    (TAICPU(hp2).ops = 3) or
                    MatchOperand(TAICPU(hp2).oper[3]^, TAICPU(p).oper[2]^)
                  ) and
                  (
                    not (cs_opt_level3 in CurrentSettings.OptimizerSwitches) or
                    (
                      { Make sure the target register isn't used in between }
                      not RegUsedBetween(TAICPU(hp2).oper[0]^.reg, hp1, hp2) and
                      (
                        { If the second operand is a register, make sure it isn't modified in between }
                        (TAICPU(p).oper[1]^.typ <> top_reg) or
                        not RegModifiedBetween(TAICPU(p).oper[1]^.reg, hp1, hp2)
                      )
                    )
                  ) then
                  begin
                    AllocRegBetween(TAICPU(hp2).oper[0]^.reg, p, hp2, UsedRegs);

                    if (TAICPU(hp2).oppostfix = PF_S) then
                      AllocRegBetween(NR_DEFAULTFLAGS, p, hp2, UsedRegs);

                    DebugMsg(SPeepholeOptimization + 'TST; B.c; AND -> ANDS; B.c (TstBcAnd2AndsBc)', p);
                    TAICPU(hp2).oppostfix := PF_S;

                    Asml.Remove(hp2);
                    Asml.InsertAfter(hp2, p);

                    RemoveCurrentP(p, hp2);
                    Result := True;

                    Exit;
                  end;
            A_TST:
              { Change:
                 tst  r1,##
                 b.c  .Lbl
                 ... (flags not modified)
                 tst  r1,##

                Remove second tst
              }
              if
                (TAICPU(hp2).ops = TAICPU(p).ops) and
                MatchOperand(TAICPU(hp2).oper[0]^, TAICPU(p).oper[0]^.reg) and
                MatchOperand(TAICPU(hp2).oper[1]^, TAICPU(p).oper[1]^) and
                (
                  (TAICPU(hp2).ops = 2) or
                  MatchOperand(TAICPU(hp2).oper[2]^, TAICPU(p).oper[2]^)
                ) and
                (
                  not (cs_opt_level3 in CurrentSettings.OptimizerSwitches) or
                  (
                    { Make sure the flags aren't modified in between }
                    not RegModifiedBetween(NR_DEFAULTFLAGS, hp1, hp2) and
                    (
                      { If the second operand is a register, make sure it isn't modified in between }
                      (TAICPU(p).oper[1]^.typ <> top_reg) or
                      not RegModifiedBetween(TAICPU(p).oper[1]^.reg, hp1, hp2)
                    )
                  )
                ) then
                begin
                  DebugMsg(SPeepholeOptimization + 'TST; B.c; TST -> TST; B.c (TstBcTst2TstBc)', p);

                  AllocRegBetween(NR_DEFAULTFLAGS, hp1, hp2, UsedRegs);
                  RemoveInstruction(hp2);
                  Result := True;
                  Exit;
                end;
            else
              ;
          end;
        end;
    end;


  function TARMAsmOptimizer.TryConstMerge(var p: TAI; hp1: TAI): Boolean;
    const
      LO_16_WRITE: TAsmOp = A_MOVZ;
      HI_16_WRITE: TAsmOp = A_MOVK;
    var
      hp2, hp2_second, hp3, hp3_second, p_second, hp1_second: TAI;
      ThisReg: TRegister;
      ThisRef: TReference;
      so: TShifterOp;

      procedure SearchAhead;
        begin
          { If p.opcode = A_STR, then ThisReg will be NR_NO }
          if
            (
              (
                MatchInstruction(p, A_MOVZ, []) and
                Assigned(hp1)
              ) or
              (
                MatchInstruction(p, A_STR, []) and
                SetAndTest(p, hp1)
              )
            ) and
            (
              (
                (ThisReg <> NR_NO) and
                (
                  (
                    (GetSubReg(ThisReg) = R_SUBD) and
                    MatchInstruction(hp1, A_MOVK, []) and
                    (TAICPU(hp1).oper[0]^.reg = ThisReg) and
                    GetNextInstruction(hp1, hp2) and
                    MatchInstruction(hp2, A_STR, []) and
                    (TAICPU(hp2).oper[0]^.reg = ThisReg) and
                    GetNextInstruction(hp2, p_second)
                  ) or
                  (
                    MatchInstruction(hp1, A_STR, []) and
                    (TAICPU(hp1).oper[0]^.reg = ThisReg) and
                    GetNextInstruction(hp1, p_second)
                  )
                )
              ) or (
                { Just search one ahead if ThisReg is NR_NO }
                (ThisReg = NR_NO) and
                GetNextInstruction(hp1, p_second)
              )
            ) and
            (
              (
                MatchInstruction(p_second, A_MOVZ, []) and
                { Don't use ThisReg because it may be NR_NO }
                GetNextInstruction(p_second, hp1_second) and
                (
                  (
                    MatchInstruction(hp1_second, A_MOVK, []) and
                    GetNextInstruction(hp1_second, hp2_second) and
                    MatchInstruction(hp2_second, A_STR, [PF_None])
                  ) or
                  MatchInstruction(hp1_second, A_STR, [])
                )
              )
              or (
                MatchInstruction(p_second, A_STR, []) and
                (GetSupReg(TAICPU(p_second).oper[0]^.reg) = RS_WZR) and
                { Negate the result because we're setting hp1_second to nil }
                not SetAndTest(nil, hp1_second)
              )
            ) then
            TryConstMerge(p_second, hp1_second);
        end;

    begin
      Result := False;

      ThisReg := NR_NO; { Safe initialisation }

      case TAICPU(p).opcode of
        A_MOVZ:
          begin
            ThisReg := TAICPU(p).oper[0]^.reg;
            if Assigned(hp1) then
              case TAICPU(hp1).opcode of
                A_STR:
                  if SuperRegistersEqual(TAICPU(hp1).oper[0]^.reg, ThisReg) then
                    begin
                      ThisRef := TAICPU(hp1).oper[1]^.Ref^;

                      if (ThisRef.AddressMode = AM_OFFSET) and
                        (ThisRef.Index = NR_NO) and
                        { Only permit writes to the stack, since we can guarantee alignment with that }
                        (
                          (ThisRef.Base = NR_STACK_POINTER_REG) or
                          (ThisRef.Base = CurrentProcInfo.FramePointer)
                        ) then
                        begin
                          case TAICPU(hp1).oppostfix of
                            PF_B:
                              {
                                With sequences such as:
                                  movz  w0,x
                                  strb  w0,[sp, #ofs]
                                  movz  w0,y
                                  strb  w0,[sp, #ofs+1]

                                Merge the constants to:
                                  movz  w0,x + (y shl 8)
                                  strh  w0,[sp, #ofs]

                                Only use the stack pointer or frame pointer and an even offset though
                                to guarantee alignment
                              }
                              if ((ThisRef.Offset mod 2) = 0) and
                                GetNextInstruction(hp1, p_second) and
                                (p_second.typ = ait_instruction)
                                then
                                begin
                                  case TAICPU(p_second).opcode of
                                    A_MOVZ:
                                      begin
                                        if SuperRegistersEqual(TAICPU(p_second).oper[0]^.reg, ThisReg) and
                                          GetNextInstruction(p_second, hp1_second) and
                                          MatchInstruction(hp1_second, A_STR, [PF_B]) and
                                          SuperRegistersEqual(TAICPU(hp1_second).oper[0]^.reg, ThisReg) then
                                          begin
                                            { Is the second storage location exactly one byte ahead? }
                                            Inc(ThisRef.Offset);
                                            if RefsEqual(TAICPU(hp1_second).oper[1]^.Ref^, ThisRef) and
                                              { The final safety check... make sure the register used
                                                to store the constant isn't used afterwards }
                                              RegEndOfLife(ThisReg, TAICPU(hp1_second)) then
                                              begin

                                                { See if we can merge 4 bytes at once (this benefits ARM mostly, but provides a speed boost for AArch64 too) }
                                                if GetNextInstruction(hp1_second, hp2) and
                                                  (
                                                    (
                                                      MatchInstruction(hp2, LO_16_WRITE, [])
                                                    )
                                                  ) and
                                                  SuperRegistersEqual(TAICPU(hp2).oper[0]^.reg, ThisReg) and
                                                  GetNextInstruction(hp2, hp2_second) and
                                                  MatchInstruction(hp2_second, A_STR, [PF_B]) and
                                                  SuperRegistersEqual(TAICPU(hp2_second).oper[0]^.reg, ThisReg) and
                                                  GetNextInstruction(hp2_second, hp3) and
                                                  (
                                                    (
                                                      MatchInstruction(hp3, LO_16_WRITE, [])
                                                    )
                                                  ) and
                                                  SuperRegistersEqual(TAICPU(hp3).oper[0]^.reg, ThisReg) and
                                                  GetNextInstruction(hp3, hp3_second) and
                                                  MatchInstruction(hp3_second, A_STR, [PF_B]) and
                                                  SuperRegistersEqual(TAICPU(hp3_second).oper[0]^.reg, ThisReg) then
                                                  begin
                                                    Inc(ThisRef.Offset);
                                                    if RefsEqual(TAICPU(hp2_second).oper[1]^.Ref^, ThisRef) then
                                                      begin
                                                        Inc(ThisRef.Offset);
                                                        if RefsEqual(TAICPU(hp3_second).oper[1]^.Ref^, ThisRef) then
                                                          begin
                                                            { Merge the constants }
                                                            DebugMsg(SPeepholeOptimization + 'Merged four byte-writes to memory into a single word-write (MovzStrbMovzStrbMovzStrbMovzStrb2MovzMovkStr)', p);
                                                            TAICPU(p).oper[1]^.Val := (TAICPU(p).oper[1]^.Val and $FF) or ((TAICPU(p_second).oper[1]^.Val and $FF) shl 8);

                                                            TAICPU(hp2).opcode := HI_16_WRITE;
                                                            TAICPU(hp2).oper[1]^.Val := (TAICPU(hp2).oper[1]^.Val and $FF) or ((TAICPU(hp3).oper[1]^.Val and $FF) shl 8);

                                                            so.ShiftImm := 16;
                                                            so.ShiftMode := SM_LSL;
                                                            TAICPU(hp2).loadshifterop(2, so);
                                                            TAICPU(hp2).ops := 3;

                                                            TAICPU(hp1).oppostfix := PF_None;

                                                            AsmL.Remove(hp2);
                                                            AsmL.InsertAfter(hp2, p);

                                                            RemoveInstruction(p_second);
                                                            RemoveInstruction(hp1_second);
                                                            RemoveInstruction(hp2_second);
                                                            RemoveInstruction(hp3);
                                                            RemoveInstruction(hp3_second);
                                                            Result := True;
                                                            { Searching ahead only benefits AArch64 here }
                                                            hp1 := hp2; { Since hp2 now appears immediately after p }
                                                            SearchAhead;
                                                            Exit;
                                                          end;
                                                        { Reset the offset so the range check below is correct }
                                                        Dec(ThisRef.Offset);
                                                      end;
                                                    Dec(ThisRef.Offset);
                                                  end;
                                                  begin

                                                    { Merge the constants and remove the second pair of instructions }
                                                    DebugMsg(SPeepholeOptimization + 'Merged two byte-writes to memory into a single half-write (MovzStrbMovzStrb2MovzStrh)', p);
                                                    TAICPU(p).oper[1]^.Val := (TAICPU(p).oper[1]^.Val and $FF) or ((TAICPU(p_second).oper[1]^.Val and $FF) shl 8);
                                                    TAICPU(hp1).oppostfix := PF_H;
                                                    RemoveInstruction(p_second);
                                                    RemoveInstruction(hp1_second);
                                                    Result := True;
                                                  end;
                                              end;
                                          end;
                                      end;
                                    A_STR:
                                      { Sometimes, the second mov might not be present as we're writing the
                                        zero register to the next address - that is:
                                          movz  w0,x
                                          strb  w0,[sp, #ofs]
                                          strb  wzr,[sp, #ofs+1]

                                        Which becomes:
                                          movz  w0,x
                                          strh  w0,[sp, #ofs]
                                      }
                                      if RegEndOfLife(ThisReg, TAICPU(hp1)) and
                                        (TAICPU(p_second).oppostfix = PF_B) and
                                        (GetSupReg(TAICPU(p_second).oper[0]^.reg) = RS_WZR) then
                                        begin
                                          { Is the second storage location exactly one byte ahead? }
                                          Inc(ThisRef.Offset);
                                          if RefsEqual(TAICPU(p_second).oper[1]^.Ref^, ThisRef) then
                                            begin
                                              { Merge the constants and remove the second pair of instructions }
                                              DebugMsg(SPeepholeOptimization + 'Merged a byte-write and a zero-register byte-write to memory into a single half-write (MovzStrbStrb2MovzStrh 1)', p);
                                              TAICPU(p).oper[1]^.Val := TAICPU(p).oper[1]^.Val and $FF; { In case there's some extraneous bits }
                                              TAICPU(hp1).oppostfix := PF_H;
                                              RemoveInstruction(p_second);
                                              Result := True;
                                            end;
                                        end;
                                    else
                                      ;
                                  end;

                                  { Search ahead to see if more bytes are written individually,
                                    because then we may be able to merge 4 bytes into a full
                                    word write in a single pass }
                                  if Result then
                                    begin
                                      SearchAhead;
                                      Exit;
                                    end;
                                end;
                            PF_H:
                              {
                                With sequences such as:
                                  movz  w0,x
                                  strh  w0,[sp, #ofs]
                                  movz  w0,y
                                  strh  w0,[sp, #ofs+2]

                                Merge the constants to:
                                  movz  w0,x
                                  movk  w0,y,lsl #16
                                  str   w0,[sp, #ofs]

                                Only use the stack pointer or frame pointer and an offset
                                that's a multiple of 4 though to guarantee alignment
                              }
                              if ((ThisRef.Offset mod 4) = 0) and
                                GetNextInstruction(hp1, p_second) and
                                (p_second.typ = ait_instruction)
                                then
                                begin
                                  case TAICPU(p_second).opcode of
                                    A_MOVZ:
                                      begin
                                        if SuperRegistersEqual(TAICPU(p_second).oper[0]^.reg, ThisReg) and
                                          GetNextInstruction(p_second, hp1_second) and
                                          MatchInstruction(hp1_second, A_STR, [PF_H]) and
                                          SuperRegistersEqual(TAICPU(hp1_second).oper[0]^.reg, ThisReg) then
                                          begin
                                            { Is the second storage location exactly one byte ahead? }
                                            Inc(ThisRef.Offset, 2);
                                            if RefsEqual(TAICPU(hp1_second).oper[1]^.Ref^, ThisRef) and
                                              { The final safety check... make sure the register used
                                                to store the constant isn't used afterwards }
                                              RegEndOfLife(ThisReg, TAICPU(hp1_second)) then
                                              begin
                                                { Merge the constants }
                                                DebugMsg(SPeepholeOptimization + 'Merged two half-writes to memory into a single word-write (MovzStrhMovzStrh2MovzMovkStr)', p);

                                                { Repurpose the second MOVZ instruction into a MOVK instruction }
                                                if TAICPU(p_second).oper[1]^.Val = 0 then
                                                  begin
                                                    { Or just remove it if it's not needed }
                                                    RemoveInstruction(p_second);
                                                    TAICPU(hp1).oppostfix := PF_None;
                                                  end
                                                else
                                                  begin
                                                    asml.Remove(p_second);
                                                    asml.InsertAfter(p_second, p);
                                                    TAICPU(p_second).opcode := HI_16_WRITE;
                                                    so.ShiftMode := SM_LSL;
                                                    so.ShiftImm := 16;

                                                    TAICPU(p_second).ops := 3;
                                                    TAICPU(p_second).loadshifterop(2, so);

                                                    { Make doubly sure we're only using the 32-bit register, otherwise STR could write 64 bits }
                                                    SetSubReg(ThisReg, R_SUBD);
                                                    TAICPU(p).oper[0]^.reg := ThisReg;
                                                    TAICPU(p_second).oper[0]^.reg := ThisReg;
                                                    TAICPU(hp1).oper[0]^.reg := ThisReg;
                                                    TAICPU(hp1).oppostfix := PF_None;
                                                    hp1 := p_second; { Since p_second now appears immediately after p }
                                                    p_second := hp1;
                                                    { TODO: Confirm that the A_MOVZ / A_MOVK combination is the most efficient }
                                                  end;

                                                RemoveInstruction(hp1_second);
                                                Result := True;
                                              end;
                                          end;
                                      end;
                                    A_STR:
                                      { Sometimes, the second mov might not be present as we're writing the
                                        zero register to the next address - that is:
                                          movz  w0,x
                                          strh  w0,[sp, #ofs]
                                          strh  wzr,[sp, #ofs+1]

                                        Which becomes:
                                          movz  w0,x
                                          str   w0,[sp, #ofs]
                                      }
                                      if RegEndOfLife(ThisReg, TAICPU(hp1)) and
                                        (TAICPU(p_second).oppostfix = PF_H) and
                                        (GetSupReg(TAICPU(p_second).oper[0]^.reg) = RS_WZR) then
                                        begin
                                          { Is the second storage location exactly one byte ahead? }
                                          Inc(ThisRef.Offset, 2);
                                          if RefsEqual(TAICPU(p_second).oper[1]^.Ref^, ThisRef) then
                                            begin
                                              { Merge the constants and remove the second pair of instructions }
                                              DebugMsg(SPeepholeOptimization + 'Merged a half-write and a zero-register half-write to memory into a single word-write (MovzStrhStrh2MovzStr)', p);

                                              { Make doubly sure we're only using the 32-bit register, otherwise STR could write 64 bits }
                                              SetSubReg(ThisReg, R_SUBD);
                                              TAICPU(p).oper[0]^.reg := ThisReg;
                                              TAICPU(hp1).oper[0]^.reg := ThisReg;

                                              TAICPU(hp1).oppostfix := PF_None;
                                              RemoveInstruction(p_second);
                                              Result := True;
                                            end;
                                        end;
                                    else
                                      ;
                                  end;
                                  { Search ahead to see if more half-words are written
                                    individually, because then we may be able to merge
                                    4 words into a full extended write in a single pass }
                                  if Result then
                                    begin
                                      SearchAhead;
                                      Exit;
                                    end;
                                end;
                            else
                              ;
                          end;
                        end;
                    end;
                A_MOVK:
                  if (GetSubReg(ThisReg) = R_SUBD) and
                    Assigned(hp1) and
                    (TAICPU(hp1).oper[0]^.reg = ThisReg) and
                    (TAICPU(hp1).ops = 3) and
                    (TAICPU(hp1).oper[2]^.shifterop^.ShiftMode = SM_LSL) and
                    (TAICPU(hp1).oper[2]^.shifterop^.ShiftImm = 16) and
                    GetNextInstruction(hp1, hp2) and
                    MatchInstruction(hp2, A_STR, [PF_None]) and
                    (TAICPU(hp2).oper[0]^.reg = ThisReg) then
                    begin
                      {
                        With sequences such as:
                          movz  w0,x
                          movk  w0,y,lsl #16
                          str   w0,[sp, #ofs]
                          movz  w0,z
                          movk  w0,q,lsl #16
                          str   w0,[sp, #ofs+4]

                        Merge the constants to:
                          movz  x0,x
                          movk  x0,y,lsl #16
                          movk  x0,z,lsl #32
                          movk  x0,q,lsl #48
                          str   x0,[sp, #ofs]

                        Only use the stack pointer or frame pointer and an offset
                        that's a multiple of 8 though to guarantee alignment
                      }
                      ThisRef := TAICPU(hp2).oper[1]^.Ref^;
                      if ((ThisRef.Offset mod 8) = 0) and
                        GetNextInstruction(hp2, p_second) and
                        (p_second.typ = ait_instruction) then
                        case TAICPU(p_second).opcode of
                          A_MOVZ:
                            if (
                                (TAICPU(p_second).oper[0]^.reg = ThisReg) or
                                (
                                  RegEndOfLife(ThisReg, TAICPU(hp2)) and
                                  (GetSubReg(TAICPU(p_second).oper[0]^.reg) = R_SUBD)
                                )
                              ) and GetNextInstruction(p_second, hp1_second) then
                              begin
                                case TAICPU(hp1_second).opcode of
                                  A_MOVK:
                                    if (TAICPU(p_second).oper[1]^.Val <= $FFFF) and
                                      (TAICPU(hp1_second).oper[0]^.reg = TAICPU(p_second).oper[0]^.reg) and
                                      (TAICPU(hp1_second).ops = 3) and
                                      (TAICPU(hp1_second).oper[2]^.shifterop^.ShiftMode = SM_LSL) and
                                      (TAICPU(hp1_second).oper[2]^.shifterop^.ShiftImm = 16) and
                                      GetNextInstruction(hp1_second, hp2_second) and
                                      MatchInstruction(hp2_second, A_STR, [PF_None]) and
                                      (TAICPU(hp1_second).oper[0]^.reg = TAICPU(p_second).oper[0]^.reg) then
                                      begin
                                        Inc(ThisRef.Offset, 4);
                                        if RefsEqual(TAICPU(hp2_second).oper[1]^.Ref^, ThisRef) and
                                          { The final safety check... make sure the register used
                                            to store the constant isn't used afterwards }
                                          RegEndOfLife(TAICPU(p_second).oper[0]^.reg, TAICPU(hp2_second)) then
                                          begin
                                            DebugMsg(SPeepholeOptimization + 'Merged two word-writes to memory into a single extended-write (MovzMovkStrMovzMovkStr2MovzMovkMovkMovkStr)', p);

                                            { Extend register to 64-bit and repurpose second MOVZ to a MOVK with lsl 32 }
                                            SetSubReg(ThisReg, R_SUBQ);

                                            TAICPU(p).oper[0]^.reg := ThisReg;
                                            TAICPU(hp1).oper[0]^.reg := ThisReg;

                                            { If the 3rd word is zero, we can remove the instruction entirely }
                                            if TAICPU(p_second).oper[1]^.Val = 0 then
                                              RemoveInstruction(p_second)
                                            else
                                              begin
                                                TAICPU(p_second).oper[0]^.reg := ThisReg;
                                                so.ShiftImm := 32;
                                                so.ShiftMode := SM_LSL;
                                                TAICPU(p_second).opcode := A_MOVK;
                                                TAICPU(p_second).ops := 3;
                                                TAICPU(p_second).loadshifterop(2, so);
                                                AsmL.Remove(p_second);
                                                AsmL.InsertBefore(p_second, hp2);
                                              end;

                                            TAICPU(hp1_second).oper[0]^.reg := ThisReg;
                                            TAICPU(hp1_second).oper[2]^.shifterop^.ShiftImm := 48;
                                            TAICPU(hp2).oper[0]^.reg := ThisReg;

                                            AsmL.Remove(hp1_second);
                                            AsmL.InsertBefore(hp1_second, hp2);

                                            RemoveInstruction(hp2_second);
                                            Result := True;
                                          end;
                                      end;
                                  else
                                    ;
                                end;
                              end;
                          A_STR:
                            { Sometimes, the second mov might not be present as we're writing the
                              zero register to the next address - that is:
                                movz  w0,x
                                movk  w0,y,lsl #16
                                str   w0,[sp, #ofs]
                                str   wzr,[sp, #ofs+4]

                              Which becomes:
                                movz  x0,x
                                movk  x0,y,lsl #16
                                str   x0,[sp, #ofs]
                            }
                            begin
                              { Sometimes, the second mov might not be present as we're writing the
                                zero register to the next address - that is:
                                  movz  w0,x
                                  strh  w0,[sp, #ofs]
                                  strh  wzr,[sp, #ofs+1]

                                Which becomes:
                                  movz  w0,x
                                  str   w0,[sp, #ofs]
                              }
                              { Don't need to check end-of-life because the upper 32 bits are zero
                                and the overall value isn't being modified }
                              if (TAICPU(p_second).oppostfix = PF_None) and
                                (TAICPU(p_second).oper[0]^.reg = NR_WZR) then
                                begin
                                  { Is the second storage location exactly one byte ahead? }
                                  Inc(ThisRef.Offset, 4);
                                  if RefsEqual(TAICPU(p_second).oper[1]^.Ref^, ThisRef) then
                                    begin
                                      { Merge the constants and remove the second pair of instructions }
                                      DebugMsg(SPeepholeOptimization + 'Merged a word-write and a zero-register word-write to memory into a single extended-write (MovzStrStr2MovzStr)', p);

                                      SetSubReg(TAICPU(p).oper[0]^.reg, R_SUBQ);
                                      SetSubReg(TAICPU(hp1).oper[0]^.reg, R_SUBQ);
                                      SetSubReg(TAICPU(hp2).oper[0]^.reg, R_SUBQ);
                                      RemoveInstruction(p_second);
                                      Result := True;
                                    end;
                                end;
                            end
                          else
                            ;
                        end;
                    end;
                else
                  ;
              end;
          end;
        A_STR:
          { hp1 is probably nil }
          if GetSupReg(TAICPU(p).oper[0]^.reg) = RS_WZR then
            begin
              ThisRef := TAICPU(p).oper[1]^.Ref^;
              if (ThisRef.AddressMode = AM_OFFSET) and
                (ThisRef.Index = NR_NO) and
                { Only permit writes to the stack, since we can guarantee alignment with that }
                (
                  (ThisRef.Base = NR_STACK_POINTER_REG) or
                  (ThisRef.Base = CurrentProcInfo.FramePointer)
                ) then
                begin

                  case TAICPU(p).oppostfix of
                    PF_B:
                      {
                        With sequences such as:
                          strb  wzr,[sp, #ofs]
                          movz  w0,x
                          strb  w0,[sp, #ofs+1]

                        Merge the constants to:
                          movz  w0,x shl 8
                          strh  w0,[sp, #ofs]

                        Only use the stack pointer or frame pointer and an even offset though
                        to guarantee alignment
                      }
                      if ((ThisRef.Offset mod 2) = 0) and
                        GetNextInstruction(p, p_second) and
                        (p_second.typ = ait_instruction) then
                        begin

                          case TAICPU(p_second).opcode of
                            A_MOVZ:
                              begin
                                ThisReg := TAICPU(p_second).oper[0]^.reg;
                                if GetNextInstruction(p_second, hp1_second) and
                                  MatchInstruction(hp1_second, A_STR, [PF_B]) and
                                  SuperRegistersEqual(TAICPU(hp1_second).oper[0]^.reg, ThisReg) then
                                  begin
                                    { Is the second storage location exactly one byte ahead? }
                                    Inc(ThisRef.Offset);
                                    if RefsEqual(TAICPU(hp1_second).oper[1]^.Ref^, ThisRef) and
                                      { The final safety check... make sure the register used
                                        to store the constant isn't used afterwards }
                                      RegEndOfLife(ThisReg, TAICPU(hp1_second)) then
                                      begin
                                        { Merge the constants by repurposing the 2nd move, changing the register in the first STR and removing the second STR }
                                        DebugMsg(SPeepholeOptimization + 'Merged a zero-register byte-write and a byte-write to memory into a single half-write (MovzStrbStrb2MovzStrh 2)', p);
                                        TAICPU(p_second).oper[1]^.Val := (TAICPU(p_second).oper[1]^.Val and $FF) shl 8;

                                        TAICPU(hp1_second).oppostfix := PF_H;
                                        Dec(TAICPU(hp1_second).oper[1]^.Ref^.Offset, 1);

                                        RemoveCurrentP(p, p_second);
                                        Result := True;

                                        hp1 := hp1_second; { So SearchAhead works properly below }
                                      end;
                                  end;
                              end;
                            A_STR:
                              { Change:
                                  strb  wzr,[sp, #ofs]
                                  strb  wzr,[sp, #ofs+1]

                                To:
                                  strh  wzr,[sp, #ofs]
                              }
                              if (TAICPU(p_second).oppostfix = PF_B) and
                                (GetSupReg(TAICPU(p_second).oper[0]^.reg) = RS_WZR) then
                                begin
                                  { Is the second storage location exactly one byte ahead? }
                                  Inc(ThisRef.Offset);
                                  if RefsEqual(TAICPU(p_second).oper[1]^.Ref^, ThisRef) then
                                    begin
                                      DebugMsg(SPeepholeOptimization + 'Merged two zero-register byte-writes to memory into a single zero-register half-write (StrbStrb2Strh)', p);
                                      TAICPU(p).oppostfix := PF_H;
                                      RemoveInstruction(p_second);
                                      if hp1 = p_second then { Make sure hp1 deson't become a dangling pointer }
                                        GetNextInstruction(p, hp1);
                                      Result := True;
                                    end;
                                end;
                            else
                              ;
                          end;

                          { Search ahead to see if more bytes are written individually,
                            because then we may be able to merge 4 bytes into a full
                            word write in a single pass }
                          if Result then
                            begin
                              SearchAhead;
                              Exit;
                            end;
                        end;
                    PF_H:
                      {
                        With sequences such as:
                          strh  wzr,[sp, #ofs]
                          movz  w0,x
                          strh  w0,[sp, #ofs+2]

                        Merge the constants to:
                          movz  w0,#0
                          movk  w0,x,lsl #16
                          str   w0,[sp, #ofs]

                        Only use the stack pointer or frame pointer and an offset
                        that's a multiple of 4 though to guarantee alignment
                      }
                      if ((ThisRef.Offset mod 4) = 0) and
                        GetNextInstruction(p, p_second) and
                        (p_second.typ = ait_instruction) then
                        begin
                          case TAICPU(p_second).opcode of
                            A_MOVZ:
                              begin
                                ThisReg := TAICPU(p_second).oper[0]^.reg;
                                if GetNextInstruction(p_second, hp1_second) and
                                  MatchInstruction(hp1_second, A_STR, [PF_H]) and
                                  SuperRegistersEqual(TAICPU(hp1_second).oper[0]^.reg, ThisReg) then
                                  begin
                                    { Is the second storage location exactly two bytes ahead? }
                                    Inc(ThisRef.Offset, 2);
                                    if RefsEqual(TAICPU(hp1_second).oper[1]^.Ref^, ThisRef) and
                                      { The final safety check... make sure the register used
                                        to store the constant isn't used afterwards }
                                      RegEndOfLife(ThisReg, TAICPU(hp1_second)) then
                                      begin

                                        { Merge the constants }
                                        DebugMsg(SPeepholeOptimization + 'Merged a zero-register half-write and a half-write to memory into a single word-write (StrhMovzStrh2MovzMovkStr)', p);

                                        { Repurpose the first STR to a MOVZ instruction }
                                        TAICPU(p).opcode := A_MOVZ;
                                        TAICPU(p).oppostfix := PF_None;
                                        TAICPU(p).oper[0]^.reg := ThisReg;
                                        TAICPU(p).loadconst(1, 0);

                                        so.ShiftMode := SM_LSL;
                                        so.ShiftImm := 16;

                                        TAICPU(p_second).opcode := A_MOVK;
                                        TAICPU(p_second).ops := 3;
                                        TAICPU(p_second).loadshifterop(2, so);

                                        { Make doubly sure we're only using the 32-bit register, otherwise STR could write 64 bits }
                                        SetSubReg(ThisReg, R_SUBD);
                                        TAICPU(p).oper[0]^.reg := ThisReg;
                                        TAICPU(p_second).oper[0]^.reg := ThisReg;
                                        TAICPU(hp1_second).oper[0]^.reg := ThisReg;

                                        { TODO: Confirm that the A_MOVZ / A_MOVK combination is the most efficient }

                                        TAICPU(hp1_second).oppostfix := PF_None;
                                        Dec(TAICPU(hp1_second).oper[1]^.Ref^.Offset, 2);
                                        Result := True;
                                      end;
                                  end;
                              end;
                            A_STR:
                              { Change:
                                  strh  wzr,[sp, #ofs]
                                  strh  wzr,[sp, #ofs+2]

                                To:
                                  str   wzr,[sp, #ofs]
                              }
                              if (TAICPU(p_second).oppostfix = PF_H) and
                                (GetSupReg(TAICPU(p_second).oper[0]^.reg) = RS_WZR) then
                                begin
                                  { Is the second storage location exactly one byte ahead? }
                                  Inc(ThisRef.Offset, 2);
                                  if RefsEqual(TAICPU(p_second).oper[1]^.Ref^, ThisRef) then
                                    begin
                                      DebugMsg(SPeepholeOptimization + 'Merged two zero-register half-writes to memory into a single zero-register word-write (StrhStrh2Str)', p);

                                      { Make doubly sure we're only using the 32-bit register, otherwise STR could write 64 bits }
                                      TAICPU(p).oper[0]^.reg := NR_WZR;

                                      TAICPU(p).oppostfix := PF_None;
                                      RemoveInstruction(p_second);
                                      if hp1 = p_second then { Make sure hp1 deson't become a dangling pointer }
                                        GetNextInstruction(p, hp1);
                                      Result := True;
                                    end;
                                end;
                            else
                              ;
                          end;
                        end;
                    PF_None:
                      {
                        With sequences such as:
                          str   wzr,[sp, #ofs]
                          movz  w0,x
                          movk  w0,y,lsl #16
                          str   w0,[sp, #ofs+4]

                        Merge the constants to:
                          movz  x0,#0
                          movk  x0,x,lsl #32
                          movk  x0,y,lsl #48
                          str   x0,[sp, #ofs]

                        Only use the stack pointer or frame pointer and an offset
                        that's a multiple of 8 though to guarantee alignment
                      }
                      if ((ThisRef.Offset mod 8) = 0) and
                        GetNextInstruction(p, p_second) and
                        (p_second.typ = ait_instruction) then
                        begin
                          case TAICPU(p_second).opcode of
                            A_MOVZ:
                              begin
                                ThisReg := TAICPU(p_second).oper[0]^.reg;
                                if GetNextInstruction(p_second, hp1_second) and
                                  MatchInstruction(hp1_second, A_MOVK, []) and
                                  GetNextInstruction(hp1_second, hp2_second) and
                                  MatchInstruction(hp2_second, A_STR, [PF_None]) and
                                  (TAICPU(hp2_second).oper[0]^.reg = ThisReg) then
                                  begin
                                    { Is the second storage location exactly four bytes ahead? }
                                    Inc(ThisRef.Offset, 4);
                                    if RefsEqual(TAICPU(hp2_second).oper[1]^.Ref^, ThisRef) and
                                      { The final safety check... make sure the register used
                                        to store the constant isn't used afterwards }
                                      RegEndOfLife(ThisReg, TAICPU(hp1_second)) then
                                      begin
                                        { Merge the constants }
                                        DebugMsg(SPeepholeOptimization + 'Merged a zero-register word-write and a word-write to memory into a single extended-write (StrMovzMovkStr2MovzMovkMovkStr)', p);

                                        SetSubReg(ThisReg, R_SUBQ);

                                        { Repurpose the first STR to a MOVZ instruction }
                                        TAICPU(p).opcode := A_MOVZ;
                                        TAICPU(p).oppostfix := PF_None;
                                        TAICPU(p).oper[0]^.reg := ThisReg;
                                        TAICPU(p).loadconst(1, 0);

                                        { If the 3rd word is zero, we can remove the instruction entirely }
                                        if TAICPU(p_second).oper[1]^.Val = 0 then
                                          begin
                                            RemoveInstruction(p_second);
                                            if hp1 = p_second then { Make sure hp1 deson't become a dangling pointer }
                                              GetNextInstruction(p, hp1);
                                          end
                                        else
                                          begin
                                            so.ShiftMode := SM_LSL;
                                            so.ShiftImm := 32;
                                            TAICPU(p_second).opcode := A_MOVK;
                                            TAICPU(p_second).ops := 3;
                                            TAICPU(p_second).loadshifterop(2, so);
                                            TAICPU(p_second).oper[0]^.reg := ThisReg;
                                          end;

                                        TAICPU(p).oper[0]^.reg := ThisReg;
                                        TAICPU(hp1_second).oper[0]^.reg := ThisReg;
                                        TAICPU(hp1_second).oper[2]^.shifterop^.ShiftImm := 48;

                                        { TODO: Confirm that the A_MOVZ / A_MOVK / A_MOVK combination is the most efficient }

                                        TAICPU(hp2_second).oppostfix := PF_None;
                                        Dec(TAICPU(hp2_second).oper[1]^.Ref^.Offset, 4);
                                        TAICPU(hp2_second).oper[0]^.reg := ThisReg; { Remember to change the register to its 64-bit counterpart }
                                        Result := True;
                                      end;
                                  end;
                              end;
                            A_STR:
                              { Change:
                                  str   wzr,[sp, #ofs]
                                  str   wzr,[sp, #ofs+4]

                                To:
                                  str   xzr,[sp, #ofs]
                              }
                              if (TAICPU(p_second).oppostfix = PF_None) and
                                (GetSupReg(TAICPU(p_second).oper[0]^.reg) = RS_WZR) then
                                begin
                                  { Is the second storage location exactly one byte ahead? }
                                  Inc(ThisRef.Offset, 4);
                                  if RefsEqual(TAICPU(p_second).oper[1]^.Ref^, ThisRef) then
                                    begin
                                      DebugMsg(SPeepholeOptimization + 'Merged two zero-register word-writes to memory into a single zero-register extended-write (StrStr2Str)', p);
                                      TAICPU(p).oper[0]^.reg := NR_XZR;
                                      RemoveInstruction(p_second);
                                      if hp1 = p_second then { Make sure hp1 deson't become a dangling pointer }
                                        GetNextInstruction(p, hp1);
                                      Result := True;
                                    end;
                                end;
                            else
                              ;
                          end;
                        end;
                    else
                      ;
                  end;
                end;
            end;
        else
          ;
      end;
    end;

end.

