{
    Copyright (c) 2024- by Michael Van Canneyt

    This unit handles the compiler tasks.

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

unit CTask;

{$mode ObjFPC}

{ $DEFINE DEBUG_CTASK}

interface

uses
  FinPut, FModule, CClasses, Globals, GlobStat;

type
  { ttask

    About state:
      Contains scanner/parser position needed for compiling pascal sources,
      irrelevant for loading ppu(s).
      It is restored before continuing and saved afterwards (if unfinished).
      Loading ppu files works recursively and stops when a unit requires (re)compile,
      A recompile discards the saved state the adds the module to ctask.
      When the recursion steps back, leaving the current unit unfinished the state is saved,
      so ctask can continue with another unit.
  }

  TTask = class
    Module : TModule;
    State : TGlobalState;
    Prev, Next: TTask;
    constructor Create(M : TModule);
    destructor Destroy; override;
    procedure SaveState;
    procedure RestoreState;
    procedure DiscardState;
  end;

  { ttask_handler }

  TTaskHandler = class
  private
    TaskCount: Integer;
    FirstTask: TTask;
    function CreateTask(M: TModule): TTask;
    procedure FreeTask(T: TTask);
    procedure FinishModule(M: TModule);
    procedure QueueModule(M: TModule);
    function RestoreTaskState(M: TModule): TTask;
    function ReloadModule(M: TModule): TTask;
    function RecompileModule(M: TModule): TTask;
    procedure UpdateCircularUnitGroups;
    procedure SearchFinishedSCC(M: TModule{$IFDEF DEBUG_PPU_CYCLES}; const Indent: string = ''{$ENDIF});
    function FindUnfinishedLeafSCC(M: TModule): TModule;
    function IsUsesWaiting(M: TModule; UU: TUsedUnit): Boolean;
    function CheckDoReloadCycle(SCCRoot: TModule): Boolean;
    function CheckCRCMismatches(SCCRoot: TModule): Boolean;
    function CheckCycleWaitForPas(SCCRoot: TModule): Boolean;
    function RecompilePending(SCCRoot: TModule): Boolean;
    procedure RecompileSCC(SCCRoot: TModule);
    function CheckCompiledUses(Dst: TModule): TModule;
  public
    constructor Create;
    destructor Destroy; override;
    { Find the task for module m }
    function FindTask(M : TModule; AutoCreate: Boolean = False) : TTask;
    // Can we continue processing this module ? If not, firstwaiting contains first module that m is waiting for.
    function CanContinue(M : TModule; out FirstWaiting: TModule): Boolean;
    { Overload of cancontinue, based on task. }
    function CanContinue(T: TTask; out FirstWaiting: TModule): Boolean; inline;
    { Continue processing this module. Return true if the module is done and can be removed. }
    function Continue_Module(M : TModule): Boolean;
    { process the queue. Note that while processing the queue, elements will be added. }
    procedure ProcessQueue;
    { add a module to the queue. If a module is already in the queue, we do not add it again. }
    procedure AddModule(M : TModule);
    { write current scc and what is waiting for what }
    procedure Write_SCC;
    { get number of modules in a scc }
    function Get_SCC_Count(SCCRoot: TModule): Integer;
    function Has_SCC_Another_Unfinished_Module(M: TModule): Boolean;
    procedure Check_SCC_Tree(CurrentSCC: TModule);
  end;


var
  Task_Handler : TTaskHandler;

procedure InitTaskHandler;
procedure DoneTaskHandler;

implementation

uses
  Verbose, FPPU, SysUtils,
  Scanner, Parser, PModules, SymBase;

procedure InitTaskHandler;
begin
  Task_Handler:=TTaskHandler.Create;
end;

procedure DoneTaskHandler;
begin
  FreeAndNil(Task_Handler);
end;

{ ttask }

constructor TTask.Create(M: TModule);
begin
  inherited Create;
  Module:=M;
  M.Task:=Self;
  State:=Nil;
end;

destructor TTask.Destroy;
begin
  { the module might already be freed! }
  DiscardState;
  Inherited;
end;

procedure TTask.DiscardState;
begin
  FreeAndNil(State);
end;

procedure TTask.SaveState;
begin
  if Module.FromPPU then Exit;
  SetCurrentModule(Module);
  if State=Nil then
    State:=TGlobalState.Create(True)
  else
    State.Save(True);
end;

procedure TTask.RestoreState;
begin
  if Module.FromPPU then Exit;
  if Module.IsReset then
    begin
      WriteLn('ttask.RestoreState is_reset ',Module.ModuleName^,' ',Module.StateStr);
      InternalError(2026030105);
    end;
  if State=Nil then
    begin
      WriteLn('ttask.RestoreState state=nil ',Module.ModuleName^,' ',Module.StateStr);
      InternalError(2026030106);
    end;
  State.Restore;
  if Assigned(CurrentScanner) and Assigned(CurrentScanner.FInputFile) then
    if CurrentScanner.FInputFile.Closed then
      begin
        CurrentScanner.TempOpenInputFile;
        CurrentScanner.GetTokenPos;
      end;
end;

{ ttask_handler }

constructor TTaskHandler.Create;
begin
  TModule.Finish_Module:=@FinishModule;
end;

destructor TTaskHandler.Destroy;
begin
  while FirstTask<>Nil do
    FreeTask(FirstTask);
  inherited Destroy;
end;

function TTaskHandler.FindTask(M: TModule; AutoCreate: Boolean): TTask;
begin
  Result:=TTask(M.Task);
  if (Result=Nil) and AutoCreate then
    begin
      AddModule(M);
      Result:=TTask(M.Task);
    end;
end;

function TTaskHandler.CreateTask(M: TModule): TTask;
begin
  Result:=TTask.Create(M);
  if FirstTask<>Nil then
    begin
      FirstTask.Next:=Result;
      Result.Prev:=FirstTask;
    end;
  FirstTask:=Result;
  Inc(TaskCount);
end;

procedure TTaskHandler.FreeTask(T: TTask);
begin
  { the module might already be freed! }
  if FirstTask=T then
    FirstTask:=T.Next;
  if T.Next<>Nil then
    T.Next.Prev:=T.Prev;
  if T.Prev<>Nil then
    T.Prev.Next:=T.Next;
  T.Free;
  Dec(TaskCount);
end;

procedure TTaskHandler.FinishModule(M: TModule);
{ finish loading special units added by the compiler itself, e.g. variants.nxu
  No reloads, no recompiles }

  function FindCanContinue(Root: TModule): TModule;
  var
    UU: TUsedUnit;
    FirstWaiting: TModule;
  begin
    Result:=Nil;
    if Root.CycleSearchStamp=TModule.Cycle_Stamp then Exit;
    Root.CycleSearchStamp:=TModule.Cycle_Stamp;

    if Root.DoRecompile then
      begin
        // e.g. system.nxu not found
        TPPUModule(Root).Check_Sources_For_Recompile;
        WriteLn('ttask_handler.finishmodule ',Root.ModuleName^,' ',Root.StateStr);
        InternalError(2026032615);
      end
    else if not (Root.State in [ms_registered,ms_load,ms_compiled,ms_processed]) then
      begin
        WriteLn('ttask_handler.finishmodule ',Root.ModuleName^,' ',Root.StateStr);
        InternalError(2026030401);
      end;

    { finish used units first }
    UU:=TUsedUnit(Root.UsedUnitList.First);
    while Assigned(UU) do
      begin
        Result:=FindCanContinue(UU.U);
        if Assigned(Result) then Exit;
        UU:=TUsedUnit(UU.Next);
      end;

    if not (Root.State in [ms_compiled,ms_processed])
        and CanContinue(Root,FirstWaiting) then
      Exit(Root);
  end;

  procedure FindUnfinished(Root: TModule);
  { find unfinished unit(s) and write message }
  var
    UU: TUsedUnit;
    UM: TModule;
  begin
    if Root.CycleSearchStamp=TModule.Cycle_Stamp then Exit;
    Root.CycleSearchStamp:=TModule.Cycle_Stamp;

    if Root.State in [ms_compiled,ms_processed] then
      begin
        UU:=TUsedUnit(Root.UsedUnitList.First);
        while Assigned(UU) do
          begin
            FindUnfinished(UU.U);
            UU:=TUsedUnit(UU.Next);
          end;
        Exit;
      end;

    { check for invalid unit cycle }
    UU:=TUsedUnit(Root.UsedUnitList.First);
    while Assigned(UU) and (UU.U.State in [ms_compiled,ms_processed]) do
      UU:=TUsedUnit(UU.Next);
    if UU<>Nil then
      Message2(unit_f_circular_unit_reference,Root.RealModuleName^,UU.U.RealModuleName^);

    if Root.WaitingForUnit<>Nil then
      begin
        UM:=TModule(Root.WaitingForUnit[0]);
        Message2(unit_f_circular_unit_reference,Root.RealModuleName^,UM.RealModuleName^);
      end;

    WriteLn('CTASK: cannot finish module ',Root.RealModuleName^);
    InternalError(2026030301);
  end;

var
  Next: TModule;
  State: TGlobalState;
begin
  if M.SCCFinished then Exit;

  State:=Nil;
  repeat
    TModule.Increase_Cycle_Stamp;
    Next:=FindCanContinue(M);
    if Next=Nil then Break;
    if State=Nil then
      State:=TGlobalState.Create(True);
    {$IF defined(DEBUG_CTASK) or defined(Debug_FreeParseMem)}WriteLn('CTASK-finish: continuing ',Next.ToString,' state=',Next.StateStr,' total-units=',Loaded_Units.Count,' tasks=',TaskCount);{$ENDIF}
    Continue_Module(Next);
  until False;

  TModule.Increase_Cycle_Stamp;
  FindUnfinished(M);

  if State<>Nil then
    begin
      State.Restore;
      State.Free;
    end;
end;

procedure TTaskHandler.QueueModule(M: TModule);
var
  T: TTask;
begin
  AddModule(M);
  T:=FindTask(M);
  T.SaveState;
end;

function TTaskHandler.CanContinue(M: TModule; out FirstWaiting: TModule): Boolean;
begin
  FirstWaiting:=Nil;

  { We do not need to consider the program as long as there are units that need to be treated. }
  if M.IsInitial and Has_SCC_Another_Unfinished_Module(M) then
    begin
      if not M.IsUnit then
        Exit(False);
      if M.State=ms_compiled then
        Exit(False); { the initial unit must wait for ms_processed til all others are processed }
    end;

  if M.DoReload then
    CanContinue:=TPPUModule(M).CanReload(FirstWaiting,False)
  else
  begin
    case M.State of
      ms_unknown : CanContinue:=True;
      ms_registered : CanContinue:=True;
      ms_load: CanContinue:=TPPUModule(M).PPULoadCanContinue(FirstWaiting);
      ms_compile : CanContinue:=True;
      ms_compiling_wait : CanContinue:=M.UsedUnitsLoaded(True,FirstWaiting);
      ms_compiling_waitintf : CanContinue:=M.UsedUnitsLoaded(True,FirstWaiting);
      ms_compiling_waitimpl : CanContinue:=M.UsedUnitsLoaded(False,FirstWaiting);
      ms_compiling_waitfinish : CanContinue:=M.NoWaitingForUnits(FirstWaiting);
      ms_compiled_waitcrc : CanContinue:=M.UsedUnitsFinalCRC(FirstWaiting);
      ms_compiled,
      ms_processed,
      ms_moduleerror : CanContinue:=True;
    end;
  end;

  {$IFDEF DEBUG_CTASK_VERBOSE}
  Write('CTASK: ',M.ToString,' state: ',M.State,', can continue: ',Result);
  if Result then
    WriteLn
  else
    begin
    Write(' (First waiting: ');
    If Assigned(FirstWaiting) then
      WriteLn(FirstWaiting.ToString,' )')
    else
      WriteLn('<none>)');
    end;
  {$ENDIF}
end;

function TTaskHandler.CanContinue(T: TTask; out FirstWaiting: TModule): Boolean;

begin
  Result:=CanContinue(T.Module,FirstWaiting);
end;

function TTaskHandler.Continue_Module(M: TModule): Boolean;

var
  T : TTask;

begin
  SetCurrentModule(M);
  T:=FindTask(M,True);
  if Assigned(T.State) then
    T.RestoreState;

  TModule.CTask_Fast_Backtrack:=False;
  if M.DoReload then
  begin
    TPPUModule(M).Reload;
    T.SaveState;
    TGlobalState.Clear_State;
    Exit(False);
  end;
  case M.State of
    ms_registered :
      TPPUModule(M).LoadPPU(TPPUModule(M).LoadedFromModule);
    ms_load: (M as TPPUModule).ContinueLoadPPU;
    ms_compile :
      begin
        if (M=Main_Module) and (MacroSymTableStack<>Nil) then
          begin
            MacroSymTableStack.Clear;
            FreeAndNil(MacroSymTableStack);
          end;
        Parser.CompileModule(M);
      end;
    ms_compiled : ;
    ms_compiling_wait :
      if M.IsPackage then
        PModules.FinishPackage(M)
      else
        PModules.ProcProgramDeclarations(M,M.IsLibrary);
    ms_compiling_waitintf : PModules.ParseUnitInterfaceDeclarations(M);
    ms_compiling_waitimpl : PModules.ProcUnitImplementation(M);
    ms_compiling_waitfinish : PModules.FinishCompileUnit(M);
    ms_compiled_waitcrc : PModules.FinishUnit(M);
    ms_processed : ;
  else
    InternalError(2024011801);
  end;

  if M.State = ms_moduleerror then
    Exit(False);

  if M.IsInitial and Has_SCC_Another_Unfinished_Module(M) then
    begin
      { main module must wait for all units to finish }
      if (not M.IsUnit) and (M.State in [ms_compiled,ms_processed]) then
        { program, library, package frees modules, there should be no tasked left }
        InternalError(2026030302);
      { Note: when main module is a unit, it can finish before used units finish }
    end
  else if M.State=ms_compiled then
    begin
    if not M.FromPPU then
      ParsingDone(M);
    if (M.State=ms_compiled) and M.IsUnit then
      TPPUModule(M).Post_Load_Or_Compile(M);
    M.State:=ms_processed;
    end;
  Result:=M.State=ms_processed;
  {$IFDEF DEBUG_CTASK}
  Write('CTASK: ',M.ToString,' done: ',Result);
  if Result then
    WriteLn
  else
    WriteLn(', state is now: ',M.StateStr);
  {$ENDIF}
  if Result then
    begin
      {$IFDEF DEBUG_CTASK}WriteLn('CTASK: ',M.ToString,' is finished, removing from task list');{$ENDIF}
      M.Task:=Nil;
      FreeTask(T);
    end
  else
    { Not done, save state }
    T.SaveState;
  TGlobalState.Clear_State;
end;

procedure TTaskHandler.SearchFinishedSCC(M: TModule{$IFDEF DEBUG_PPU_CYCLES}; const Indent: string{$ENDIF});
{ called after all circular_unit_groups have beeen computed.
  depth-first-search all modules and computes scc_tree_unfinished, other_scc_unfinished
  and scc_tree_crc_wait.
  marks finished scc with scc_finished:=true.
  returns an unfinished scc root, which sub sccs are all finished }
var
  UU: TUsedUnit;
  UM, AltSCCTreeCRCWait: TModule;
begin
  if M.CycleSearchStamp=TModule.Cycle_Stamp then
    Exit;
  M.CycleSearchStamp:=TModule.Cycle_Stamp;

  {$IFDEF DEBUG_PPU_CYCLES}
  WriteLn(Indent,'ttask_handler.search_finished_scc ',M.ModuleName^,' ',M.StateStr);
  {$ENDIF}

  if M.SCCFinished then
    InternalError(2026032903);

  M.SCCTreeUnfinished:=M.State<>ms_processed;
  M.OtherSCCUnfinished:=False;
  M.SCCTreeCRCWait:=Nil;
  if M.DoReload
      or not M.CRCFinal
      or ((M.State=ms_load) and not M.PPUWaitingForCRC) then
    M.SCCTreeCRCWait:=M;

  UU:=TUsedUnit(M.UsedUnitList.First);
  while Assigned(UU) do
    begin
      UM:=UU.U;
      if not UM.SCCFinished then
        begin
          SearchFinishedSCC(UM{$IFDEF DEBUG_PPU_CYCLES},Indent+'  '{$ENDIF});
          { Note: if um is in m' scc, um's values might be incomplete }
          if UM.SCCTreeUnfinished then
            begin
              M.SCCTreeUnfinished:=True;
              if UM.OtherSCCUnfinished
                  or ((M.SCCLowIndex<>UM.SCCLowIndex) and UM.SCCTreeUnfinished) then
                M.OtherSCCUnfinished:=True;
            end
          else if UM.OtherSCCUnfinished then
            InternalError(2026022201); { this finished and other unfinished }
          if (UM.SCCTreeCRCWait<>Nil)
              and ((M.SCCTreeCRCWait=Nil)
                  { Note: do not "or m.scc_tree_crc_wait=m" here, so the below alt_scc_tree_crc_wait can find m }
                  or (M.SCCRoot<>UM.SCCTreeCRCWait.SCCRoot)) then
                M.SCCTreeCRCWait:=UM.SCCTreeCRCWait; { prefer pointing to a sub scc, helps debugging }
        end;
      UU:=TUsedUnit(UU.Next);
    end;

  if M.SCCRoot=M then
    begin
      { backtrack from scc root -> the scc was completely searched }

      { copy scc_tree_unfinished and other_scc_unfinished to all scc nodes }
      UM:=M.SCCNext;
      while Assigned(UM) do
        begin
          UM.SCCTreeUnfinished:=M.SCCTreeUnfinished;
          UM.OtherSCCUnfinished:=M.OtherSCCUnfinished;
          UM:=UM.SCCNext;
        end;

      if (not M.SCCTreeUnfinished) then
        begin
          { scc finished }
          UM:=M;
          while Assigned(UM) do
            begin
              {$IFDEF DEBUG_CTASK}
              WriteLn('CTASK finished scc: ',UM.ModuleName^,' ',UM.StateStr);
              {$ENDIF}
              UM.SCCFinished:=True;
              UM.SCCLowIndex:=0;
              UM.SCCIndex:=0;
              if UM.SCCTreeCRCWait<>Nil then
                InternalError(2026032901);
              UM:=UM.SCCNext;
            end;
        end
      else if M.SCCTreeCRCWait<>Nil then
        begin
          { scc has at least one module without finished crc }

          { scc_tree_crc_wait should point to an unfinished used unit.
            In a scc it might point to itself. Check for another unfinished unit. }
          AltSCCTreeCRCWait:=Nil;
          UM:=M;
          while Assigned(UM) do
            begin
              if UM.SCCTreeCRCWait=Nil then
                UM.SCCTreeCRCWait:=M.SCCTreeCRCWait
              else if UM.SCCTreeCRCWait<>M.SCCTreeCRCWait then
                AltSCCTreeCRCWait:=UM.SCCTreeCRCWait;
              UM:=UM.SCCNext;
            end;

          UM:=M;
          while Assigned(UM) do
            begin
              if UM.SCCTreeCRCWait=UM then
                begin
                  if UM=AltSCCTreeCRCWait then
                    UM.SCCTreeCRCWait:=M.SCCTreeCRCWait
                  else
                    UM.SCCTreeCRCWait:=AltSCCTreeCRCWait; { if um is the only unfinished module, this sets it to nil }
                end;
              UM:=UM.SCCNext;
            end;
        end
      else
        ; { all modules of the scc have their crc, now the ppus can be be written }
    end;

  {$IFDEF DEBUG_PPU_CYCLES}
  if M=M.SCCRoot then
    WriteLn(Indent,'SCC: ',M.ModuleName^,' ',M.StateStr,' size=',Get_SCC_Count(M),' other_scc=',M.OtherSCCUnfinished,' tree_crc_wait=',M.SCCTreeCRCWait<>Nil);
  {$ENDIF}
end;

function TTaskHandler.FindUnfinishedLeafSCC(M: TModule): TModule;
var
  UU: TUsedUnit;
  UM: TModule;
begin
  if M.CycleSearchStamp=TModule.Cycle_Stamp then
    Exit(Nil);
  M.CycleSearchStamp:=TModule.Cycle_Stamp;

  if not M.OtherSCCUnfinished { scc has no unfinished sub scc }
      and M.SCCTreeUnfinished { scc has at least one unfinished module }
      then
    Exit(M);

  UU:=TUsedUnit(M.UsedUnitList.First);
  while Assigned(UU) do
    begin
      UM:=UU.U;
      if not UM.SCCFinished then
        begin
          Result:=FindUnfinishedLeafSCC(UM);
          if Result<>Nil then Exit;
        end;
      UU:=TUsedUnit(UU.Next);
    end;
  Result:=Nil;
end;

function TTaskHandler.IsUsesWaiting(M: TModule; UU: TUsedUnit): Boolean;
var
  UM: TModule;
  CheckImplUses, CheckCRC: Boolean;
begin
  UM:=UU.U;
  TPPUModule(M).Get_Check_Uses(CheckImplUses, CheckCRC);

  if (UU.InInterface or CheckImplUses)
      and not UM.InterfaceCompiled then
    Exit(True); { waiting for interface_compiled }

  if CheckCRC and not UM.CRCFinal then
    Exit(True); { waiting for crc }

  Result:=False;
end;

function TTaskHandler.CheckDoReloadCycle(SCCRoot: TModule): Boolean;
{ return true if something changed }
var
  M, FirstWaiting: TModule;
  HasDoReload: Boolean;
begin
  Result:=False;
  HasDoReload:=False;
  M:=SCCRoot;
  while Assigned(M) do
    begin
      if M.DoReload then
        begin
          HasDoReload:=True;
          if not TPPUModule(M).CanReload(FirstWaiting,True) then
            Exit;
        end;
      M:=M.SCCNext;
    end;

  if not HasDoReload then
    Exit;

  { reload all do_reloads }
  Result:=True;
  M:=SCCRoot;
  while Assigned(M) do
    begin
      if M.DoReload then
        begin
          {$IFDEF DEBUG_CTASK}
          WriteLn('PPUALGO ttask_handler.check_do_reload_cycle reloading ',M.ModuleName^,' ',M.StateStr,' ...');
          {$ENDIF}
          ReloadModule(M);
        end;
      M:=M.SCCNext;
    end;
end;

function TTaskHandler.CheckCRCMismatches(SCCRoot: TModule): Boolean;
{ recompile all scc modules whose crc of used units mismatch }
var
  M, NextModule: TModule;
  PU: TUsedUnit;
  CheckImplUses, CheckCRC: Boolean;
begin
  Result:=False;
  M:=SCCRoot;
  while Assigned(M) do
    begin
      NextModule:=M.SCCNext;
      if TPPUModule(M).Get_Check_Uses(CheckImplUses, CheckCRC) or CheckCRC then
        begin
          PU:=TUsedUnit(M.UsedUnitList.First);
          while Assigned(PU) do
            begin
              if PU.InInterface or CheckCRC then
                begin
                  if (PU.U.InterfaceCompiled
                      and ((PU.U.InterfaceCRC<>PU.InterfaceChecksum)
                        or (PU.U.IndirectCRC<>PU.IndirectChecksum)))
                      or (PU.U.CRCFinal and CheckCRC and (PU.U.CRC<>PU.Checksum) ) then
                    begin
                      {$IFDEF DEBUG_CTASK}
                      WriteLn('PPUALGO ttask_handler.check_crc_mismatches recompile ',M.ModuleName^,' ',M.StateStr,' ',BoolToStr(PU.InInterface,'interface','implementation'),' uses ',PU.U.ModuleName^,' ...');
                      {$ENDIF}
                      RecompileModule(M);
                      Result:=True;
                      Break;
                    end;
                end;
              PU:=TUsedUnit(PU.Next);
            end;
        end;
      M:=NextModule;
    end;
end;

function TTaskHandler.CheckCycleWaitForPas(SCCRoot: TModule): Boolean;
{ find a waiting pas module A (non ppu),
  dfs through the scc to find all modules waiting for A,
  choose a ppu module to recompile }
var
  PascalModule, Best: TModule;

  function Search(M: TModule): Boolean;
  var
    UU: TUsedUnit;
    UM: TModule;
    I: Integer;
  begin
    Result:=False;
    if M.CycleSearchStamp=TModule.Cycle_Stamp then Exit;
    M.CycleSearchStamp:=TModule.Cycle_Stamp;

    UU:=TUsedUnit(M.UsedUnitList.First);
    while Assigned(UU) do
      begin
        UM:=UU.U;
        if UM=PascalModule then
          begin
            { m waits for pas_mod }
            Result:=True;
            if M.FromPPU then
              begin
                Best:=M;
                Exit;
              end;
          end;
        if (UM.SCCRoot=M.SCCRoot)
            and IsUsesWaiting(M,UU) then
          begin
            if Search(UM) then
              begin
                Result:=True;
                if M.FromPPU then
                  begin
                    Best:=M;
                    Exit;
                  end;
              end;
          end;
        UU:=TUsedUnit(UU.Next);
      end;

    if (M.State=ms_compiling_waitfinish) and Assigned(M.WaitingForUnit) then
      begin
        for I:=0 to M.WaitingForUnit.Count do
          begin
            UM:=TModule(M.WaitingForUnit[I]);
            if UM=PascalModule then
              begin
                { m waits for pas_mod }
                Result:=True;
                if M.FromPPU then
                  begin
                    Best:=M;
                    Exit;
                  end;
              end;
            if Search(UM) then
              begin
                Result:=True;
                if M.FromPPU then
                  begin
                    Best:=M;
                    Exit;
                  end;
              end;
          end;
      end;
  end;

begin
  Result:=False;

  { find one pas module (non ppu) }
  Best:=Nil;
  TModule.Increase_Cycle_Stamp;
  PascalModule:=SCCRoot;
  while Assigned(PascalModule) do
    begin
      if PascalModule.FromPPU then
        begin
          { dfs through the scc to find a ppu waiting for pas_mod and vice versus
            Note: already searched pas are skipped, resulting in linear time }
          Search(PascalModule);

          if Best<>Nil then
            begin
              { waiting ppu found -> recompile }
              {$IFDEF DEBUG_CTASK}
              WriteLn('PPUALGO ttask_handler.check_cycle_wait_for_pas breaking cycle, recompiling ',Best.ModuleName^,' ',Best.StateStr,' ...');
              {$ENDIF}
              RecompileModule(Best);
              Exit(True);
            end;
        end;
      PascalModule:=PascalModule.SCCNext;
    end;
end;

function TTaskHandler.RecompilePending(SCCRoot: TModule): Boolean;
var
  M, Next: TModule;
begin
  Result:=False;
  M:=SCCRoot;
  while Assigned(M) do
    begin
      Next:=M.SCCNext;
      if M.DoRecompile then
        begin
          {$IFDEF DEBUG_CTASK}
          WriteLn('PPUALGO ttask_handler.recompile_pending recompiling ',M.ModuleName^,' ',M.StateStr,' ...');
          {$ENDIF}
          Result:=True;
          RecompileModule(M);
        end;
      M:=Next;
    end;
end;

procedure TTaskHandler.RecompileSCC(SCCRoot: TModule);
var
  M, Next, FirstWaiting: TModule;
  Changed: Boolean;
begin
  {$IFDEF DEBUG_PPU_CYCLES}
  WriteLn('ttask_handler.recompile_scc root=',SCCRoot.ModuleName^,' ',SCCRoot.StateStr,' size=',Get_SCC_Count(SCCRoot));
  M:=SCCRoot;
  while Assigned(M) do
  begin
    CanContinue(M,FirstWaiting);
    WriteLn('PPUALGO ttask_handler.recompile_scc module: ',M.ModuleName^,' ',M.StateStr,' firstwaiting=',FirstWaiting.ModuleName^,' ',FirstWaiting.StateStr);
    M:=M.SCCNext;
  end;
  {$ENDIF}
  repeat
    Changed:=False;
    M:=SCCRoot;
    while Assigned(M) do
      begin
        Next:=M.SCCNext;
        if M.DoReload then
          begin
            {$IFDEF DEBUG_CTASK}
            WriteLn('PPUALGO ttask_handler.recompile_scc breaking cycle, recompiling ',M.ModuleName^,' ',M.StateStr,' ...');
            {$ENDIF}
            Changed:=True;
            RecompileModule(M);
          end;
        M:=Next;
      end;

    if not Changed then
      begin
        M:=SCCRoot;
        while Assigned(M) and not CanContinue(M,FirstWaiting) do
          M:=M.SCCNext;
        if M=Nil then
          begin
            Write_SCC;
            WriteLn('ttask_handler.recompile_scc no more do_reloads and still can not continue');
            InternalError(2026033114);
          end;
      end;
  until not Changed;
end;

function TTaskHandler.CheckCompiledUses(Dst: TModule): TModule;

  function SearchDest(CompiledModule: TModule): Boolean;
  var
    Visited: array of Boolean;

    function Search(M: TModule): Boolean;
    var
      UU: TUsedUnit;
    begin
      Result:=False;
      if M=Dst then
        Exit(True);
      if M.SCCFinished then Exit;
      if Visited[M.ModuleID] then Exit;
      Visited[M.ModuleID]:=True;

      UU:=TUsedUnit(M.UsedUnitList.First);
      while Assigned(UU) do
        begin
          if Search(UU.U) then Exit(True);
          UU:=TUsedUnit(UU.Next);
        end;
    end;

  begin
    Visited:=Nil;
    SetLength(Visited,Length(All_Modules));
    Result:=Search(CompiledModule);
  end;

  function SearchCompiled(M: TModule): Boolean;
  var
    UU: TUsedUnit;
  begin
    Result:=False;
    if M.SCCFinished then Exit;

    if M.CycleSearchStamp=TModule.Cycle_Stamp then Exit;
    M.CycleSearchStamp:=TModule.Cycle_Stamp;

    if M.State in [ms_compiled,ms_processed] then
      begin
        if SearchDest(M) then
          begin
            CheckCompiledUses:=M;
            Exit(True);
          end;
      end;

    UU:=TUsedUnit(M.UsedUnitList.First);
    while Assigned(UU) do
      begin
        if SearchCompiled(UU.U) then Exit;
        UU:=TUsedUnit(UU.Next);
      end;
  end;

begin
  Result:=Nil;
  TModule.Increase_Cycle_Stamp;
  SearchCompiled(Main_Module);
end;

function TTaskHandler.RestoreTaskState(M: TModule): TTask;
begin
  Result:=FindTask(M);
  if Result=Nil then
    begin
      AddModule(M);
      Result:=FindTask(M);
    end
  else if Result.State<>Nil then
    Result.RestoreState;
end;

function TTaskHandler.ReloadModule(M: TModule): TTask;
begin
  if M.State in [ms_compiled,ms_processed] then
    begin
      Write_SCC;
      WriteLn('ttask_handler.reload_module ',M.ModuleName^,' ',M.StateStr);
      InternalError(2026022410);
    end;
  if M.SCCFinished then
    begin
      Write_SCC;
      WriteLn('ttask_handler.reload_module ',M.ModuleName^,' ',M.StateStr);
      InternalError(2026022411);
    end;


  Result:=RestoreTaskState(M);
  TPPUModule(M).Reload;
  Result.SaveState;
  TGlobalState.Clear_State;
end;

function TTaskHandler.RecompileModule(M: TModule): TTask;
begin
  if M.State in [ms_compiled,ms_processed] then
    begin
      Write_SCC;
      WriteLn('ttask_handler.recompile_module ',M.ModuleName^,' ',M.StateStr);
      InternalError(2026022413);
    end;
  if M.SCCFinished then
    begin
      Write_SCC;
      WriteLn('ttask_handler.recompile_module ',M.ModuleName^,' ',M.StateStr);
      InternalError(2026022414);
    end;
  {$IFDEF DEBUG_UR_RECOMPILE}
  if (mf_release in M.ModuleFlags) and not M.IsInitial then begin
    WriteLn('ttask_handler.recompile_module UR ',M.ModuleName^,' ',M.StateStr);
    InternalError(2026030915);
  end;
  {$ENDIF}


  Result:=RestoreTaskState(M);
  if M.RecompileReason=rr_unknown then
    M.RecompileReason:=rr_buildcycle;
  TPPUModule(M).Recompile_From_Sources;
  AddModule(M);
  TGlobalState.Clear_State;
end;

procedure TTaskHandler.UpdateCircularUnitGroups;
var
  {$IFDEF DEBUG_PPU_CYCLES}
  GroupCount: Integer;
  {$ENDIF}
  Cnt: Integer;
  CurrentIndex: Integer;
  Stack: array of TModule;
  StackIndex: Integer;

  procedure SCCTraverse(M: TModule);
    var
      UU: TUsedUnit;
      UM, Prev: TModule;
    begin
      Inc(CurrentIndex);
      M.SCCIndex:=CurrentIndex;
      M.SCCLowIndex:=CurrentIndex;
      //writeln('scc_traverse ',m.modulename^,' cur_index=',cur_index,' ',length(stack),' stackindex=',stackindex);
      Stack[StackIndex]:=M;
      Inc(StackIndex);
      M.SCCOnStack:=True;

      UU:=TUsedUnit(M.UsedUnitList.First);
      while Assigned(UU) do
        begin
          UM:=UU.U;
          if not UM.SCCFinished then
            begin
              if UM.SCCIndex=0 then
                begin
                  SCCTraverse(UM);
                  if M.SCCLowIndex > UM.SCCLowIndex then
                    M.SCCLowIndex:=UM.SCCLowIndex;
                end
              else if UM.SCCOnStack then
                begin
                  { um is in same scc }
                  if M.SCCLowIndex > UM.SCCIndex then
                    M.SCCLowIndex:=UM.SCCIndex;
                end;
            end;
          UU:=TUsedUnit(UU.Next);
        end;

      if M.SCCLowIndex = M.SCCIndex then
        begin
          { new scc, pop from stack }
          {$IFDEF DEBUG_PPU_CYCLES}
          WriteLn('scc_traverse scc_root=',M.ModuleName^,' ',M.StateStr);
          Inc(GroupCount);
          {$ENDIF}
          Prev:=Nil;
          repeat
            Dec(StackIndex);
            UM:=Stack[StackIndex];
            {$IFDEF DEBUG_PPU_CYCLES}
            if M<>UM then WriteLn('  scc module: ',UM.ModuleName^,' ',UM.StateStr);
            {$ENDIF}
            UM.SCCOnStack:=False;
            UM.SCCRoot:=M;
            UM.SCCNext:=Prev;
            UM.SCCLowIndex:=M.SCCLowIndex;
            Prev:=UM;
          until M=UM;
        end;
    end;

  procedure SCCClear(M: TModule);
    var
      UU: TUsedUnit;
    begin
      if M.SCCFinished then Exit;

      if M.CycleSearchStamp=TModule.Cycle_Stamp then
        Exit; { already visited }
      M.CycleSearchStamp:=TModule.Cycle_Stamp;

      Inc(Cnt);
      M.SCCRoot:=Nil;
      M.SCCNext:=Nil;
      M.SCCIndex:=0;
      M.SCCLowIndex:=0;
      M.SCCOnStack:=False;
      M.SCCTreeCRCWait:=Nil;
      UU:=TUsedUnit(M.UsedUnitList.First);
      while Assigned(UU) do
        begin
          if not UU.U.SCCFinished then
            SCCClear(UU.U);
          UU:=TUsedUnit(UU.Next);
        end;
    end;

begin
  Cnt:=0;
  TModule.Increase_Cycle_Stamp;
  SCCClear(Main_Module);
  Stack:=[];
  SetLength(Stack,Cnt);
  StackIndex:=0;

  {$IFDEF DEBUG_PPU_CYCLES}
  GroupCount:=0;
  {$ENDIF}
  CurrentIndex:=0;
  SCCTraverse(Main_Module);
  {$IFDEF DEBUG_PPU_CYCLES}
  WriteLn('tmodule.update_circular_unit_groups modulecnt=',Cnt,' grp_cnt=',GroupCount);
  {$ENDIF}
end;

procedure TTaskHandler.ProcessQueue;

var
  FirstWaiting, M, SCCRoot, Best: TModule;
  {$IFDEF DEBUG_CTASK}
  LoopCnt: Integer;
  {$ENDIF}
begin
  { Strategy: goal is to write ppus early, so that mem is freed early and in case of an error
              next compile can load ppus instead of compiling again. }
  {$IFDEF DEBUG_CTASK}
  LoopCnt:=0;
  {$ENDIF}
  SCCRoot:=Nil;
  repeat
    {$IFDEF DEBUG_CTASK}
    Inc(LoopCnt);
    WriteLn('CTASK: Iteration: ',LoopCnt);
    {$ENDIF}

    if Main_Module.State<ms_compiled then
      RecompilePending(SCCRoot);

    { compute circular unit groups aka scc (strongly connected components) }
    UpdateCircularUnitGroups;

    { compute scc_tree_unfinished and other_scc_unfinished, and mark finished scc }
    TModule.Increase_Cycle_Stamp;
    SearchFinishedSCC(Main_Module);
    { now each scc root module has scc_tree_unfinished and other_scc_unfinished:
        scc_tree_unfinished=true means at least one module is not yet finished (do_reload or not ms_compiled)
        other_scc_unfinished=true means at least one sub scc has one unfinished module }

    if not Main_Module.SCCTreeUnfinished then
      Exit;

    { find a scc with at least one unfinished module and all sub scc are finished }
    TModule.Increase_Cycle_Stamp;
    SCCRoot:=FindUnfinishedLeafSCC(Main_Module);
    if SCCRoot=Nil then
    begin
      Write_SCC;
      InternalError(2026022204);
    end;
    {$IFDEF DEBUG_PPU_CYCLES}
    WriteLn('ttask_handler.processqueue scc_root: ',SCCRoot.ModuleName^,' ',SCCRoot.StateStr);
    {$ENDIF}


    { recompile marked modules }
    if RecompilePending(SCCRoot) then
      Continue;

    { check all scc' modules if crc mismatch }
    if CheckCRCMismatches(SCCRoot) then
      Continue;

    { check if any of the scc' modules can continue }
    Best:=Nil;
    M:=SCCRoot;
    while Assigned(M) do
      begin
        {$IFDEF DEBUG_PPU_CYCLES}
        //writeln('ttask_handler.processqueue check scc module: ',m.modulename^,' ',m.statestr);
        {$ENDIF}
        if (M.State<ms_processed) and CanContinue(M,FirstWaiting) then
          begin
            { prefer do_reload, then pas, last ppu }
            if (Best=Nil)
                or M.DoReload
                or (not Best.DoReload and Best.FromPPU and not M.FromPPU)
            then
              Best:=M;
          end;
        M:=M.SCCNext;
      end;

    if Best=Nil then
      begin
        { checking for a do_reload cycle }
        if CheckDoReloadCycle(SCCRoot) then
          Continue;
        { break the cycle by recompiling one ppu module waiting for a pas }
        if CheckCycleWaitForPas(SCCRoot) then
          Continue;
        { finally: recompile the whole scc }
        RecompileSCC(SCCRoot);
        Continue;
      end;

    {$IF defined(DEBUG_CTASK) or defined(Debug_FreeParseMem)}WriteLn('CTASK: continuing ',Best.ToString,' state=',Best.StateStr,' total-units=',Loaded_Units.Count,' tasks=',TaskCount);{$ENDIF}
    if Continue_Module(Best) then
      // done
    else if Best.State=ms_moduleerror then
      Exit;
  until False;
end;

procedure TTaskHandler.AddModule(M: TModule);

var
  T : TTask;

begin
  T:=FindTask(M);
  if T=Nil then
    begin
    {$IFDEF DEBUG_CTASK}WriteLn('CTASK: ',M.ToString,' added to task scheduler. State: ',M.StateStr,' moduleid=',M.ModuleID);{$ENDIF}
    { Clear reset flag.
      This can happen when during load, reset is done and unit is added to task list. }
    M.IsReset:=False;
    T:=CreateTask(M);
    end
  else
    begin
    { We have a task, if it was reset, then clear the state. }
    if M.IsReset then
      begin
      {$IFDEF DEBUG_CTASK}WriteLn('CTASK: ',M.ToString,' was reset, resetting flag. State: ',M.StateStr);{$ENDIF}
      M.IsReset:=False;
      T.DiscardState;
      end;
    end;
  TModule.CTask_Fast_Backtrack:=True;
end;

procedure TTaskHandler.Write_SCC;

  function Search(M: TModule; const Indent: string): TModule;
  // returns m, if m is an unfinished scc
  var
    FirstWaiting, SubSCC, UM: TModule;
    UU, UM2: TUsedUnit;
  begin
    Result:=Nil;
    if M.CycleSearchStamp=TModule.Cycle_Stamp then Exit;
    M.CycleSearchStamp:=TModule.Cycle_Stamp;

    SubSCC:=Nil;
    UU:=TUsedUnit(M.UsedUnitList.First);
    while Assigned(UU) do
      begin
        UM:=Search(UU.U,Indent+'  ');
        if SubSCC=Nil then SubSCC:=UM;
        UU:=TUsedUnit(UU.Next);
      end;

    FirstWaiting:=Nil;
    if M=M.SCCRoot then
      CanContinue(M,FirstWaiting);
    Write(Indent,' ',M.ModuleName^,' ',M.StateStr);
    if M.SCCFinished then
      Write('  scc_finished');
    if M=M.SCCRoot then
      begin
        if not M.SCCFinished and M.SCCTreeUnfinished then
          Result:=M;
        Write(' SCC ',Get_SCC_Count(M),' WaitForSCC=',M.OtherSCCUnfinished);
        if SubSCC<>Nil then
          begin
            // has an unfinished sub scc
            if not M.OtherSCCUnfinished then
              begin
                WriteLn;
                WriteLn('ERROR: has unfinished sub scc: ',SubSCC.ModuleName^,' ',SubSCC.StateStr,' scc_tree_unfinished=',SubSCC.SCCTreeUnfinished);
                InternalError(2026022205);
              end
            else
              Write(' unfinished sub scc=',SubSCC.ModuleName^,' ',SubSCC.StateStr);
          end
        else
          begin
            // has no unfinished sub scc
            if M.OtherSCCUnfinished then
              begin
                WriteLn;
                WriteLn('ERROR: this scc has no unfinished sub scc:');
                UM:=M;
                while Assigned(UM) do
                  begin
                    CanContinue(UM,FirstWaiting);
                    Write('  ',UM.ModuleName^,' ',UM.StateStr,' tree_unfinished=',UM.SCCTreeUnfinished,' other=',UM.OtherSCCUnfinished);
                    if UM.SCCFinished then
                      Write(' ERROR:scc_finished');
                    if FirstWaiting<>Nil then
                      Write(' WaitsFor=',FirstWaiting.ModuleName^,' ',FirstWaiting.StateStr)
                    else
                      Write(' WaitsFor=nil');
                    if UM.SCCRoot<>M then
                      if UM.SCCRoot<>Nil then
                        Write(' ERROR:scc_root=',UM.SCCRoot.ModuleName^)
                      else
                        Write(' ERROR:scc_root=nil');
                    WriteLn;

                    UM2:=TUsedUnit(UM.UsedUnitList.First);
                    while Assigned(UM2) do
                      begin
                        WriteLn('    ',UM2.U.ModuleName^,' ',UM2.U.StateStr,' scc_finished=',UM2.U.SCCFinished,' tree_unfinished=',UM2.U.SCCTreeUnfinished);
                        UM2:=TUsedUnit(UM2.Next);
                      end;

                    UM:=UM.SCCNext;
                  end;
                InternalError(2026022206);
              end;
            if FirstWaiting<>Nil then
              Write(' WaitForMod=',FirstWaiting.ModuleName^,' ',FirstWaiting.StateStr)
            else
              Write(' WaitForMod=nil');
          end;
      end
    else
      begin
        if M.SCCRoot=Nil then
          Write(' ERROR: scc_root=nil')
        else begin
          Write(' scc_root=',M.SCCRoot.ModuleName^);
          CanContinue(M,FirstWaiting);
          if FirstWaiting<>Nil then
            Write(' WaitForMod=',FirstWaiting.ModuleName^,' ',FirstWaiting.StateStr)
          else
            Write(' WaitForMod=nil');
        end;
      end;
    WriteLn;
  end;

begin
  WriteLn('ttask_handler.write_scc');
  TModule.Increase_Cycle_Stamp;
  Search(Main_Module,'');
end;

function TTaskHandler.Get_SCC_Count(SCCRoot: TModule): Integer;
begin
  Result:=0;
  while Assigned(SCCRoot) do
    begin
      Inc(Result);
      SCCRoot:=SCCRoot.SCCNext;
    end;
end;

function TTaskHandler.Has_SCC_Another_Unfinished_Module(M: TModule): Boolean;
var
  SCCRoot: TModule;
begin
  Result:=False;
  SCCRoot:=M.SCCRoot;
  while Assigned(SCCRoot) do
    begin
      if (M<>SCCRoot) and (SCCRoot.State<>ms_processed) then
        Exit(True);
      SCCRoot:=SCCRoot.SCCNext;
    end;
end;

procedure TTaskHandler.Check_SCC_Tree(CurrentSCC: TModule);
var
  Visited: array of Boolean;

  procedure MarkReachable(M: TModule);

    procedure Mark(Sub: TModule);
    var
      UU: TUsedUnit;
    begin
      if Sub.SCCFinished then Exit;
      if Sub.CycleSearchStamp=TModule.Cycle_Stamp then Exit;
      Sub.CycleSearchStamp:=TModule.Cycle_Stamp;

      UU:=TUsedUnit(Sub.UsedUnitList.First);
      while Assigned(UU) do
        begin
          Mark(UU.U);
          UU:=TUsedUnit(UU.Next);
        end;
    end;

  begin
    TModule.Increase_Cycle_Stamp;
    Mark(M);
  end;

  function CanReach(Src, Dst: TModule): Boolean;

    function Search(M: TModule): Boolean;
    var
      UU: TUsedUnit;
    begin
      Result:=False;
      if M.CycleSearchStamp=TModule.Cycle_Stamp then Exit;
      M.CycleSearchStamp:=TModule.Cycle_Stamp;

      UU:=TUsedUnit(M.UsedUnitList.First);
      while Assigned(UU) do
        begin
          if UU.U=Dst then Exit(True);
          if Search(UU.U) then Exit(True);
          UU:=TUsedUnit(UU.Next);
        end;
    end;

  begin
    TModule.Increase_Cycle_Stamp;
    Result:=Search(Src);
  end;

  procedure Check(M: TModule);
  var
    UM: TModule;
    UU: TUsedUnit;
  begin
    if Visited[M.ModuleID] then Exit;
    Visited[M.ModuleID]:=True;

    UM:=M.Find_Used_Unit_Compiling;

    if M.SCCFinished or (M.State in [ms_compiled,ms_processed]) then
      begin
        if UM<>Nil then
          begin
            Write_SCC;
            WriteLn(M.ModuleName^,' ',M.StateStr,' scc_finished=',M.SCCFinished,' uses ',UM.ModuleName^,' ',UM.StateStr);
            InternalError(2026032905);
          end;
        Exit;
      end;

    // the scc_tree_crc_wait is only valid for the current scc
    if CurrentSCC=M.SCCRoot then
      begin
        if (M.SCCTreeCRCWait<>Nil) and (UM=Nil) then
          begin
            Write_SCC;
            WriteLn('INVALID scc_tree_crc_wait: ',M.ModuleName^,' ',M.StateStr,' scc_tree_crc_wait=',M.SCCTreeCRCWait.ModuleName^,' ',M.SCCTreeCRCWait.StateStr);
            InternalError(2026032906);
          end;

        if (M.SCCTreeCRCWait=Nil) and (UM<>Nil) then
          begin
            Write_SCC;
            WriteLn('INVALID scc_tree_crc_wait: ',M.ModuleName^,' ',M.StateStr,' scc_tree_crc_wait=nil uses ',UM.ModuleName^,' ',UM.StateStr);
            InternalError(2026032907);
          end;
      end;

    if M.SCCRoot=Nil then
      begin
        WriteLn('INVALID scc_root: ',M.ModuleName^,' ',M.StateStr);
        InternalError(2026032908);
      end;

    if M.SCCRoot=M then
      begin
        { check if scc root uses all modules in the scc_next list  }
        TModule.Increase_Cycle_Stamp;
        MarkReachable(M);
        UM:=M.SCCNext;
        while Assigned(UM) do
          begin
            if UM.CycleSearchStamp<>TModule.Cycle_Stamp then
              begin
                Write_SCC;
                WriteLn('INVALID scc_next: ',M.ModuleName^,' ',M.StateStr,' um=',UM.ModuleName^,' ',UM.StateStr);
                InternalError(2026032909);
              end;
            UM:=UM.SCCNext;
          end;
      end
    else
      begin
        { check if all scc_next can reach their scc_root }
        if not CanReach(M,M.SCCRoot) then
          begin
            Write_SCC;
            WriteLn('INVALID scc_root: ',M.ModuleName^,' ',M.StateStr,' m.scc_root=',M.SCCRoot.ModuleName^,' ',M.SCCRoot.StateStr);
            InternalError(2026032910);
          end;
      end;

    // check recursively
    UU:=TUsedUnit(M.UsedUnitList.First);
    while Assigned(UU) do
      begin
        Check(UU.U);
        UU:=TUsedUnit(UU.Next);
      end;

  end;

begin
  Visited:=Nil;
  SetLength(Visited,Length(All_Modules));

  Check(Main_Module);
end;

end.

