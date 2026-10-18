{
    Copyright (c) 1998-2004 by Jonas Maebe, member of the Free Pascal
    Development Team

    This unit contains the interface routines between the code generator
    and the optimizer.

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
Unit aopt;

{$i fpcdefs.inc}

{ $define DEBUG_OPTALLOC}
{ $define DEBUG_INSTRUCTIONREGISTERDEPENDENCIES}

  Interface

    Uses
      aasmbase,aasmtai,AAsmData,aasmcpu,
      aoptobj;

    Type
      TAsmOptimizer = class(TAOptObj)
        { Pooled object that can be used by optimisation procedures to evaluate
          future register usage without upsetting the current state. }
        TmpUsedRegs: TAllUsedRegs;

        { _AsmL is the PAasmOutput list that has to be optimized }
        Constructor Create(_AsmL: TAsmList); virtual; reintroduce;

        { call the necessary optimizer procedures }
        Procedure Optimize;virtual;
        Destructor Destroy;override;

      private
        procedure FindLoHiLabels;

        { Builds a table with the locations of the labels in the TAsmList.
          Also fixes some RegDeallocs like "# %eax released; push (%eax)"  }
        Procedure BuildLabelTableAndFixRegAlloc;
      protected
        procedure Pass_1;
        procedure clear;
      End;
      TAsmOptimizerClass = class of TAsmOptimizer;

      TAsmScheduler = class(TAOptObj)
        { _AsmL is the PAasmOutput list that has to be re-scheduled }
        Constructor Create(_AsmL: TAsmList); virtual; reintroduce;
        Procedure Optimize;
        function SchedulerPass1Cpu(var p: TAI): boolean; virtual; abstract;
        procedure SchedulerPass1;
      end;
      TAsmSchedulerClass = class of TAsmScheduler;

    var
      casmoptimizer : TAsmOptimizerClass;
      cpreregallocscheduler : TAsmSchedulerClass;

    procedure Optimize(AsmL:TAsmList);
    procedure PreRegallocSchedule(AsmL:TAsmList);

  Implementation

    uses
      CUtils,
      CProfile,
      GlobType, Globals,
      Verbose,
      cpubase,
      cgbase,
      aoptcpu;

    Constructor TAsmOptimizer.Create(_AsmL: TAsmList);
      Begin
        inherited Create(_asml,nil,nil,nil);
        { setup labeltable, always necessary }
        New(LabelInfo);
        CreateUsedRegs(TmpUsedRegs);
      End;

    procedure TAsmOptimizer.FindLoHiLabels;
      { Walks through the paasmlist to find the lowest and highest label number.  }
      { Returns the last Pai object of the current block                          }
      Var LabelFound: Boolean;
          p: TAI;
      Begin
        LabelInfo^.LowLabel := High(LongInt);
        LabelInfo^.HighLabel := 0;
        LabelInfo^.LabelDif := 0;
        LabelInfo^.LabelTable:=nil;
        LabelFound := False;
        P := BlockStart;
        With LabelInfo^ Do
          Begin
            While Assigned(P) And
                  ((P.typ <> Ait_Marker) Or
                   (TAIMarker(P).Kind <> mark_AsmBlockStart)) Do
              Begin
                If (p.typ = ait_label) and
                   (TAILabel(p).LabSym.labeltype=alt_jump) and
                   (TAILabel(p).LabSym.Is_Used) Then
                  Begin
                    LabelFound := True;
                    If (TAILabel(p).LabSym.labelnr < LowLabel) Then
                      LowLabel := TAILabel(p).LabSym.labelnr;
                    If (TAILabel(p).LabSym.labelnr > HighLabel) Then
                      HighLabel := TAILabel(p).LabSym.labelnr
                  End;
                GetNextInstruction(p, p)
              End;
            blockend:=p;
            If LabelFound
              Then LabelDif := HighLabel-LowLabel+1
              Else LabelDif := 0
          End
      End;


    Procedure TAsmOptimizer.BuildLabelTableAndFixRegAlloc;
    Var p,hp1, hp2: TAI;
        Regs: TAllUsedRegs;
        LabelIdx : LongInt;
    Begin
      CreateUsedRegs(Regs);
      With LabelInfo^ Do
        begin
          If (LabelDif <> 0) Then
            SetLength(LabelTable, LabelDif);
          p := BlockStart;
          While (P <> BlockEnd) Do
            Begin
              prefetch(pointer(p.Next)^);
              Case p.typ Of
                ait_Label:
                  begin
                    If TAILabel(p).LabSym.Is_Used and
                       (TAILabel(p).LabSym.labeltype=alt_jump) then
                      begin
                        LabelIdx:=TAILabel(p).LabSym.labelnr-LowLabel;
                        if LabelIdx>int64(LabelDif) then
                          InternalError(200604202);
                        LabelTable[LabelIdx].PaiObj := p;
                      end;
                  end;
                ait_regAlloc:
                  begin
                    if TAIRegAlloc(p).ratype=ra_alloc then
                      Begin
                        If Not(RegInUsedRegs(TAIRegAlloc(p).Reg,Regs)) Then
                          IncludeRegInUsedRegs(TAIRegAlloc(p).Reg,Regs)
                        Else
                          Begin
                            hp1 := TAI(p.previous);
{$ifdef DEBUG_OPTALLOC}
                            AsmL.InsertAfter(TAIComment.Create(StrPNew('Removed allocation of '+std_regname(TAIRegAlloc(p).Reg))),p);
{$endif DEBUG_OPTALLOC}
                            AsmL.remove(p);
                            p.free;
                            p := hp1;
                            { not sure if this is useful, it even skips previous deallocs of the register (FK)
                            hp1 := p;
                            hp2 := nil;
                            While GetLastInstruction(hp1, hp1) And
                                  Not(RegInInstruction(tai_regalloc(p).Reg, hp1)) Do
                              hp2:=hp1;
                            If hp2<>nil Then
                              Begin
                                hp1:=tai_regalloc.DeAlloc(tai_regalloc(p).Reg,hp2);
                                InsertLLItem(tai(hp2.previous), hp2, hp1);
                              End;
                            }
                          End;
                      End
                    else if TAIRegAlloc(p).ratype=ra_dealloc then
                      Begin
                        hp1 := p;
                        hp2 := nil;
                        While Not(Assigned(FindRegAlloc(TAIRegAlloc(p).Reg, TAI(hp1.Next)))) And
                              GetNextInstruction(hp1, hp1) And
                              InstructionLoadsFromReg(TAIRegAlloc(p).Reg, hp1) Do
                          hp2 := hp1;
                        { move deallocations }
                        If hp2 <> nil Then
                          Begin
                            hp1 := TAI(p.previous);
{$ifdef DEBUG_OPTALLOC}
                            AsmL.InsertAfter(TAIComment.Create(StrPNew('Moved deallocation of '+std_regname(TAIRegAlloc(p).Reg))),p);
{$endif DEBUG_OPTALLOC}
                            AsmL.Remove(p);
                            InsertLLItem(hp2, TAI(hp2.Next), p);
                            { don't remove this deallocation later on when merging dealloc/alloc pairs because
                              it marks independent use of a register

                              This could be also achieved by a separate passes for merging first and then later
                              moving but I did not choose this solution because it takes more time and code (FK) }
                            TAIRegAlloc(p).keep:=true;
{$ifdef DEBUG_OPTALLOC}
                            AsmL.InsertAfter(TAIComment.Create(StrPNew('Moved deallocation of '+std_regname(TAIRegAlloc(p).Reg)+' here')),hp2);
{$endif DEBUG_OPTALLOC}
                            p := hp1;
                          End
                        { merge allocations/deallocations }
                        else if Assigned(findregalloc(TAIRegAlloc(p).reg, TAI(p.next))) and
                          getnextinstruction(p,hp1) and
                          (not(RegLoadedWithNewValue(TAIRegAlloc(p).Reg, hp1)) or InstructionLoadsFromReg(TAIRegAlloc(p).Reg, hp1)) and
                          { don't merge deallocations/allocation which mark a new use of register, this
                            enables more possibilities for the peephole optimizer }
                          not(TAIRegAlloc(p).keep) then
                          begin
                            hp1 := TAI(p.previous);
{$ifdef DEBUG_OPTALLOC}
                            AsmL.InsertAfter(TAIComment.Create(StrPNew('Removed deallocation of '+std_regname(TAIRegAlloc(p).Reg))),p);
{$endif DEBUG_OPTALLOC}
                            AsmL.remove(p);
                            p.free;
                            p := hp1;
                          end
                        else
                          ExcludeRegFromUsedRegs(TAIRegAlloc(p).Reg,Regs);
                      End
                  End
                else
                  ;
              End;
              P := TAI(p.Next);
              While Assigned(p) and
                    (p <> blockend) and
                    (p.typ in (SkipInstr - [ait_regalloc])) Do
                P := TAI(P.Next)
            End;
        end;
      ReleaseUsedRegs(Regs);
    End;

    procedure TAsmOptimizer.clear;
      begin
        LabelInfo^.labeltable:=Nil;
        LabelInfo^.labeldif:=0;
        LabelInfo^.lowlabel:=high(LongInt);
        LabelInfo^.highlabel:=0;
      end;


    procedure TAsmOptimizer.Pass_1;
      begin
        findlohilabels;
        BuildLabelTableAndFixRegAlloc;
      end;


    Procedure TAsmOptimizer.Optimize;
      Var
        HP: TAI;
      Begin
        BlockStart := TAI(AsmL.First);
        Pass_1;
        While Assigned(BlockStart) Do
          Begin
            if (cs_opt_peephole in CurrentSettings.OptimizerSwitches) then
              begin
                PrePeepHoleOpts;
                PeepHoleOptPass1;
                PeepHoleOptPass2;
                PostPeepHoleOpts;
              end;
            { free memory }
            clear;
            { continue where we left off, BlockEnd is either the start of an }
            { assembler block or nil}
            BlockStart := BlockEnd;
            While Assigned(BlockStart) And
                  (BlockStart.typ = ait_Marker) And
                  (TAIMarker(BlockStart).Kind = mark_AsmBlockStart) Do
              Begin
               { we stopped at an assembler block, so skip it    }
               While GetNextInstruction(BlockStart, BlockStart) And
                     ((BlockStart.Typ <> Ait_Marker) Or
                      (TAIMarker(Blockstart).Kind <> mark_AsmBlockEnd)) Do;
               { blockstart now contains a tai_marker(mark_AsmBlockEnd) }
               If GetNextInstruction(BlockStart, HP) And
                  ((HP.typ <> ait_Marker) Or
                   (TAIMarker(HP).Kind <> mark_AsmBlockStart)) Then
               { There is no assembler block anymore after the current one, so }
               { optimize the next block of "normal" instructions              }
                 Pass_1
               { Otherwise, skip the next assembler block }
               else
                 blockStart := hp;
              End
          End;
      End;


    Destructor TAsmOptimizer.Destroy;
      Begin
        ReleaseUsedRegs(TmpUsedRegs);
        LabelInfo^.LabelTable:=nil;
        Dispose(LabelInfo);
        inherited Destroy;
      End;


    constructor TAsmScheduler.Create(_AsmL: TAsmList);
      begin
        inherited Create(_asml,nil,nil,nil);
      end;


    procedure TAsmScheduler.SchedulerPass1;
      var
        p : TAI;
      begin
        p:=BlockStart;
        while p<>BlockEnd Do
          begin
            prefetch(pointer(p.Next)^);
            if SchedulerPass1Cpu(p) then
              continue;
            p:=TAI(p.next);
          end;
      end;


    procedure TAsmScheduler.Optimize;
      Var
        HP: TAI;
      Begin
        BlockStart := TAI(AsmL.First);
        While Assigned(BlockStart) Do
          Begin
            { Peephole optimizations }
            SchedulerPass1;
            { continue where we left off, BlockEnd is either the start of an }
            { assembler block or nil}
            BlockStart:=BlockEnd;
            While Assigned(BlockStart) And
                  (BlockStart.typ = ait_Marker) And
                  (TAIMarker(BlockStart).Kind = mark_AsmBlockStart) Do
              Begin
                { we stopped at an assembler block, so skip it    }
                While GetNextInstruction(BlockStart, BlockStart) And
                      ((BlockStart.Typ <> Ait_Marker) Or
                       (TAIMarker(Blockstart).Kind <> mark_AsmBlockEnd)) Do;
                { blockstart now contains a tai_marker(mark_AsmBlockEnd) }
                If not(GetNextInstruction(BlockStart, HP) And
                   ((HP.typ <> ait_Marker) Or
                    (TAIMarker(HP).Kind <> mark_AsmBlockStart))) Then
                  { skip the next assembler block }
                  blockStart := hp;
              End
          End;
      End;


    procedure Optimize(AsmL:TAsmList);
      var
        p : TAsmOptimizer;
      begin
        ResumeTimer(ct_aopt);
        p:=casmoptimizer.Create(AsmL);
        p.Optimize;
{$ifdef DEBUG_INSTRUCTIONREGISTERDEPENDENCIES}
        p.Debug_InsertInstrRegisterDependencyInfo;
{$endif DEBUG_INSTRUCTIONREGISTERDEPENDENCIES}
        p.free;
        p := nil;
        StopTimer;
      end;


    procedure PreRegallocSchedule(AsmL:TAsmList);
      var
        p : TAsmScheduler;
      begin
        p:=cpreregallocscheduler.Create(AsmL);
        p.Optimize;
        p.free;
        p := nil;
      end;


end.
