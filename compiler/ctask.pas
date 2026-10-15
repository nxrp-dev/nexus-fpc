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
    module : TModule;
    state : TGlobalState;
    prev, next: TTask;
    constructor create(m : TModule);
    destructor Destroy; override;
    procedure SaveState;
    procedure RestoreState;
    procedure DiscardState;
  end;

  { ttask_handler }

  TTaskHandler = class
  private
    taskcount: integer;
    firsttask: TTask;
    function createtask(m: TModule): TTask;
    procedure freetask(t: TTask);
    procedure finishmodule(m: TModule);
    procedure queuemodule(m: TModule);
    function Restore_State(m: TModule): TTask;
    function reload_module(m: TModule): TTask;
    function recompile_module(m: TModule): TTask;
    procedure update_circular_unit_groups;
    procedure search_finished_scc(m: TModule{$IFDEF DEBUG_PPU_CYCLES}; const Indent: string = ''{$ENDIF});
    function find_unfinished_leaf_scc(m: TModule): TModule;
    function is_uses_waiting(m: TModule; uu: TUsedUnit): boolean;
    function check_do_reload_cycle(scc_root: TModule): boolean;
    function check_crc_mismatches(scc_root: TModule): boolean;
    function check_cycle_wait_for_pas(scc_root: TModule): boolean;
    function recompile_pending(scc_root: TModule): boolean;
    procedure recompile_scc(scc_root: TModule);
    function check_compiled_uses(dst: TModule): TModule;
  public
    constructor create;
    destructor Destroy; override;
    { Find the task for module m }
    function findtask(m : TModule; autocreate: boolean = false) : TTask;
    // Can we continue processing this module ? If not, firstwaiting contains first module that m is waiting for.
    function cancontinue(m : TModule; out firstwaiting: TModule): boolean;
    { Overload of cancontinue, based on task. }
    function cancontinue(t: TTask; out firstwaiting: TModule): boolean; inline;
    { Continue processing this module. Return true if the module is done and can be removed. }
    function continue_module(m : TModule): Boolean;
    { process the queue. Note that while processing the queue, elements will be added. }
    procedure processqueue;
    { add a module to the queue. If a module is already in the queue, we do not add it again. }
    procedure addmodule(m : TModule);
    { write current scc and what is waiting for what }
    procedure write_scc;
    { get number of modules in a scc }
    function get_scc_count(scc_root: TModule): integer;
    function has_scc_another_unfinished_module(m: TModule): boolean;
    procedure check_scc_tree(curr_scc: TModule);
  end;


var
  task_handler : TTaskHandler;

procedure InitTaskHandler;
procedure DoneTaskHandler;

implementation

uses
  Verbose, FPPU, SysUtils,
  Scanner, parser, pmodules, SymBase;

procedure InitTaskHandler;
begin
  task_handler:=TTaskHandler.create;
end;

procedure DoneTaskHandler;
begin
  freeandnil(task_handler);
end;

{ ttask }

constructor TTask.create(m: TModule);
begin
  inherited create;
  module:=m;
  m.task:=self;
  state:=nil;
end;

destructor TTask.Destroy;
begin
  { the module might already be freed! }
  DiscardState;
  Inherited;
end;

procedure TTask.DiscardState;
begin
  FreeAndNil(state);
end;

procedure TTask.SaveState;
begin
  if module.FromPPU then exit;
  SetCurrentModule(module);
  if State=Nil then
    State:=TGlobalState.Create(true)
  else
    State.save(true);
end;

procedure TTask.RestoreState;
begin
  if module.FromPPU then exit;
  if module.is_reset then
    begin
      WriteLn('ttask.RestoreState is_reset ',module.ModuleName^,' ',module.StateStr);
      InternalError(2026030105);
    end;
  if state=nil then
    begin
      WriteLn('ttask.RestoreState state=nil ',module.ModuleName^,' ',module.StateStr);
      InternalError(2026030106);
    end;
  state.restore;
  if Assigned(CurrentScanner) and Assigned(CurrentScanner.inputfile) then
    if CurrentScanner.inputfile.closed then
      begin
        CurrentScanner.tempopeninputfile;
        CurrentScanner.gettokenpos;
      end;
end;

{ ttask_handler }

constructor TTaskHandler.create;
begin
  TModule.finish_module:=@finishmodule;
end;

destructor TTaskHandler.Destroy;
begin
  while firsttask<>nil do
    freetask(firsttask);
  inherited Destroy;
end;

function TTaskHandler.findtask(m: TModule; autocreate: boolean): TTask;
begin
  Result:=TTask(m.task);
  if (Result=nil) and autocreate then
    begin
      addmodule(m);
      Result:=TTask(m.task);
    end;
end;

function TTaskHandler.createtask(m: TModule): TTask;
begin
  Result:=TTask.create(m);
  if firsttask<>nil then
    begin
      firsttask.next:=Result;
      Result.prev:=firsttask;
    end;
  firsttask:=Result;
  inc(taskcount);
end;

procedure TTaskHandler.freetask(t: TTask);
begin
  { the module might already be freed! }
  if firsttask=t then
    firsttask:=t.next;
  if t.next<>nil then
    t.next.prev:=t.prev;
  if t.prev<>nil then
    t.prev.next:=t.next;
  t.free;
  dec(taskcount);
end;

procedure TTaskHandler.finishmodule(m: TModule);
{ finish loading special units added by the compiler itself, e.g. variants.nxu
  No reloads, no recompiles }

  function find_cancontinue(root: TModule): TModule;
  var
    uu: TUsedUnit;
    firstwaiting: TModule;
  begin
    Result:=nil;
    if root.cycle_search_stamp=TModule.cycle_stamp then exit;
    root.cycle_search_stamp:=TModule.cycle_stamp;

    if root.do_recompile then
      begin
        // e.g. system.nxu not found
        TPPUModule(root).Check_Sources_For_Recompile;
        WriteLn('ttask_handler.finishmodule ',root.ModuleName^,' ',root.StateStr);
        InternalError(2026032615);
      end
    else if not (root.state in [ms_registered,ms_load,ms_compiled,ms_processed]) then
      begin
        WriteLn('ttask_handler.finishmodule ',root.ModuleName^,' ',root.StateStr);
        InternalError(2026030401);
      end;

    { finish used units first }
    uu:=TUsedUnit(root.used_units.First);
    while Assigned(uu) do
      begin
        Result:=find_cancontinue(uu.u);
        if Assigned(Result) then exit;
        uu:=TUsedUnit(uu.Next);
      end;

    if not (root.state in [ms_compiled,ms_processed])
        and cancontinue(root,firstwaiting) then
      exit(root);
  end;

  procedure find_unfinished(root: TModule);
  { find unfinished unit(s) and write message }
  var
    uu: TUsedUnit;
    um: TModule;
  begin
    if root.cycle_search_stamp=TModule.cycle_stamp then exit;
    root.cycle_search_stamp:=TModule.cycle_stamp;

    if root.state in [ms_compiled,ms_processed] then
      begin
        uu:=TUsedUnit(root.used_units.First);
        while Assigned(uu) do
          begin
            find_unfinished(uu.u);
            uu:=TUsedUnit(uu.Next);
          end;
        exit;
      end;

    { check for invalid unit cycle }
    uu:=TUsedUnit(root.used_units.First);
    while Assigned(uu) and (uu.u.state in [ms_compiled,ms_processed]) do
      uu:=TUsedUnit(uu.Next);
    if uu<>nil then
      Message2(unit_f_circular_unit_reference,root.RealModuleName^,uu.u.RealModuleName^);

    if root.waitingforunit<>nil then
      begin
        um:=TModule(root.waitingforunit[0]);
        Message2(unit_f_circular_unit_reference,root.RealModuleName^,um.RealModuleName^);
      end;

    WriteLn('CTASK: cannot finish module ',root.RealModuleName^);
    InternalError(2026030301);
  end;

var
  next: TModule;
  state: TGlobalState;
begin
  if m.scc_finished then exit;

  state:=nil;
  repeat
    TModule.increase_cycle_stamp;
    next:=find_cancontinue(m);
    if next=nil then break;
    if state=nil then
      state:=TGlobalState.create(true);
    {$IF defined(DEBUG_CTASK) or defined(Debug_FreeParseMem)}WriteLn('CTASK-finish: continuing ',next.ToString,' state=',next.StateStr,' total-units=',loaded_units.Count,' tasks=',taskcount);{$ENDIF}
    continue_module(next);
  until false;

  TModule.increase_cycle_stamp;
  find_unfinished(m);

  if state<>nil then
    begin
      state.restore;
      state.free;
    end;
end;

procedure TTaskHandler.queuemodule(m: TModule);
var
  t: TTask;
begin
  addmodule(m);
  t:=findtask(m);
  t.SaveState;
end;

function TTaskHandler.cancontinue(m: TModule; out firstwaiting: TModule): boolean;
begin
  firstwaiting:=nil;

  { We do not need to consider the program as long as there are units that need to be treated. }
  if m.IsInitial and has_scc_another_unfinished_module(m) then
    begin
      if not m.is_unit then
        exit(false);
      if m.state=ms_compiled then
        exit(false); { the initial unit must wait for ms_processed til all others are processed }
    end;

  if m.do_reload then
    cancontinue:=TPPUModule(m).CanReload(firstwaiting,false)
  else
  begin
    case m.state of
      ms_unknown : cancontinue:=true;
      ms_registered : cancontinue:=true;
      ms_load: cancontinue:=TPPUModule(m).PPULoadCanContinue(firstwaiting);
      ms_compile : cancontinue:=true;
      ms_compiling_wait : cancontinue:=m.usedunitsloaded(true,firstwaiting);
      ms_compiling_waitintf : cancontinue:=m.usedunitsloaded(true,firstwaiting);
      ms_compiling_waitimpl : cancontinue:=m.usedunitsloaded(false,firstwaiting);
      ms_compiling_waitfinish : cancontinue:=m.nowaitingforunits(firstwaiting);
      ms_compiled_waitcrc : cancontinue:=m.usedunitsfinalcrc(firstwaiting);
      ms_compiled,
      ms_processed,
      ms_moduleerror : cancontinue:=true;
    end;
  end;

  {$IFDEF DEBUG_CTASK_VERBOSE}
  Write('CTASK: ',m.ToString,' state: ',m.state,', can continue: ',Result);
  if result then
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

function TTaskHandler.cancontinue(t: TTask; out firstwaiting: TModule): boolean;

begin
  Result:=cancontinue(t.module,firstwaiting);
end;

function TTaskHandler.continue_module(m: TModule): Boolean;

var
  t : TTask;

begin
  SetCurrentModule(m);
  t:=findtask(m,true);
  if Assigned(t.state) then
    t.RestoreState;

  TModule.ctask_fast_backtrack:=false;
  if m.do_reload then
  begin
    TPPUModule(m).reload;
    t.SaveState;
    TGlobalState.Clear_State;
    exit(false);
  end;
  case m.state of
    ms_registered :
      TPPUModule(m).LoadPPU(TPPUModule(m).loadedfrommodule);
    ms_load: (m as TPPUModule).ContinueLoadPPU;
    ms_compile :
      begin
        if (m=main_module) and (MacroSymTableStack<>nil) then
          begin
            MacroSymTableStack.clear;
            FreeAndNil(MacroSymTableStack);
          end;
        parser.compile_module(m);
      end;
    ms_compiled : ;
    ms_compiling_wait :
      if m.IsPackage then
        pmodules.finish_package(m)
      else
        pmodules.proc_program_declarations(m,m.IsLibrary);
    ms_compiling_waitintf : pmodules.parse_unit_interface_declarations(m);
    ms_compiling_waitimpl : pmodules.proc_unit_implementation(m);
    ms_compiling_waitfinish : pmodules.finish_compile_unit(m);
    ms_compiled_waitcrc : pmodules.finish_unit(m);
    ms_processed : ;
  else
    InternalError(2024011801);
  end;

  if m.state = ms_moduleerror then
    exit(false);

  if m.IsInitial and has_scc_another_unfinished_module(m) then
    begin
      { main module must wait for all units to finish }
      if (not m.is_unit) and (m.state in [ms_compiled,ms_processed]) then
        { program, library, package frees modules, there should be no tasked left }
        InternalError(2026030302);
      { Note: when main module is a unit, it can finish before used units finish }
    end
  else if m.state=ms_compiled then
    begin
    if not m.FromPPU then
      parsing_done(m);
    if (m.state=ms_compiled) and m.is_unit then
      TPPUModule(m).Post_Load_Or_Compile(m);
    m.state:=ms_processed;
    end;
  Result:=m.state=ms_processed;
  {$IFDEF DEBUG_CTASK}
  Write('CTASK: ',m.ToString,' done: ',Result);
  if Result then
    WriteLn
  else
    WriteLn(', state is now: ',m.StateStr);
  {$ENDIF}
  if result then
    begin
      {$IFDEF DEBUG_CTASK}WriteLn('CTASK: ',m.ToString,' is finished, removing from task list');{$ENDIF}
      m.task:=nil;
      freetask(t);
    end
  else
    { Not done, save state }
    t.SaveState;
  TGlobalState.Clear_State;
end;

procedure TTaskHandler.search_finished_scc(m: TModule{$IFDEF DEBUG_PPU_CYCLES}; const Indent: string{$ENDIF});
{ called after all circular_unit_groups have beeen computed.
  depth-first-search all modules and computes scc_tree_unfinished, other_scc_unfinished
  and scc_tree_crc_wait.
  marks finished scc with scc_finished:=true.
  returns an unfinished scc root, which sub sccs are all finished }
var
  uu: TUsedUnit;
  um, alt_scc_tree_crc_wait: TModule;
begin
  if m.cycle_search_stamp=TModule.cycle_stamp then
    exit;
  m.cycle_search_stamp:=TModule.cycle_stamp;

  {$IFDEF DEBUG_PPU_CYCLES}
  WriteLn(Indent,'ttask_handler.search_finished_scc ',m.ModuleName^,' ',m.StateStr);
  {$ENDIF}

  if m.scc_finished then
    InternalError(2026032903);

  m.scc_tree_unfinished:=m.state<>ms_processed;
  m.other_scc_unfinished:=false;
  m.scc_tree_crc_wait:=nil;
  if m.do_reload
      or not m.crc_final
      or ((m.state=ms_load) and not m.ppu_waitingfor_crc) then
    m.scc_tree_crc_wait:=m;

  uu:=TUsedUnit(m.used_units.First);
  while Assigned(uu) do
    begin
      um:=uu.u;
      if not um.scc_finished then
        begin
          search_finished_scc(um{$IFDEF DEBUG_PPU_CYCLES},Indent+'  '{$ENDIF});
          { Note: if um is in m' scc, um's values might be incomplete }
          if um.scc_tree_unfinished then
            begin
              m.scc_tree_unfinished:=true;
              if um.other_scc_unfinished
                  or ((m.scc_lowindex<>um.scc_lowindex) and um.scc_tree_unfinished) then
                m.other_scc_unfinished:=true;
            end
          else if um.other_scc_unfinished then
            InternalError(2026022201); { this finished and other unfinished }
          if (um.scc_tree_crc_wait<>nil)
              and ((m.scc_tree_crc_wait=nil)
                  { Note: do not "or m.scc_tree_crc_wait=m" here, so the below alt_scc_tree_crc_wait can find m }
                  or (m.scc_root<>um.scc_tree_crc_wait.scc_root)) then
                m.scc_tree_crc_wait:=um.scc_tree_crc_wait; { prefer pointing to a sub scc, helps debugging }
        end;
      uu:=TUsedUnit(uu.Next);
    end;

  if m.scc_root=m then
    begin
      { backtrack from scc root -> the scc was completely searched }

      { copy scc_tree_unfinished and other_scc_unfinished to all scc nodes }
      um:=m.scc_next;
      while Assigned(um) do
        begin
          um.scc_tree_unfinished:=m.scc_tree_unfinished;
          um.other_scc_unfinished:=m.other_scc_unfinished;
          um:=um.scc_next;
        end;

      if (not m.scc_tree_unfinished) then
        begin
          { scc finished }
          um:=m;
          while Assigned(um) do
            begin
              {$IFDEF DEBUG_CTASK}
              WriteLn('CTASK finished scc: ',um.ModuleName^,' ',um.StateStr);
              {$ENDIF}
              um.scc_finished:=true;
              um.scc_lowindex:=0;
              um.scc_index:=0;
              if um.scc_tree_crc_wait<>nil then
                InternalError(2026032901);
              um:=um.scc_next;
            end;
        end
      else if m.scc_tree_crc_wait<>nil then
        begin
          { scc has at least one module without finished crc }

          { scc_tree_crc_wait should point to an unfinished used unit.
            In a scc it might point to itself. Check for another unfinished unit. }
          alt_scc_tree_crc_wait:=nil;
          um:=m;
          while Assigned(um) do
            begin
              if um.scc_tree_crc_wait=nil then
                um.scc_tree_crc_wait:=m.scc_tree_crc_wait
              else if um.scc_tree_crc_wait<>m.scc_tree_crc_wait then
                alt_scc_tree_crc_wait:=um.scc_tree_crc_wait;
              um:=um.scc_next;
            end;

          um:=m;
          while Assigned(um) do
            begin
              if um.scc_tree_crc_wait=um then
                begin
                  if um=alt_scc_tree_crc_wait then
                    um.scc_tree_crc_wait:=m.scc_tree_crc_wait
                  else
                    um.scc_tree_crc_wait:=alt_scc_tree_crc_wait; { if um is the only unfinished module, this sets it to nil }
                end;
              um:=um.scc_next;
            end;
        end
      else
        ; { all modules of the scc have their crc, now the ppus can be be written }
    end;

  {$IFDEF DEBUG_PPU_CYCLES}
  if m=m.scc_root then
    WriteLn(Indent,'SCC: ',m.ModuleName^,' ',m.StateStr,' size=',get_scc_count(m),' other_scc=',m.other_scc_unfinished,' tree_crc_wait=',m.scc_tree_crc_wait<>nil);
  {$ENDIF}
end;

function TTaskHandler.find_unfinished_leaf_scc(m: TModule): TModule;
var
  uu: TUsedUnit;
  um: TModule;
begin
  if m.cycle_search_stamp=TModule.cycle_stamp then
    exit(nil);
  m.cycle_search_stamp:=TModule.cycle_stamp;

  if not m.other_scc_unfinished { scc has no unfinished sub scc }
      and m.scc_tree_unfinished { scc has at least one unfinished module }
      then
    exit(m);

  uu:=TUsedUnit(m.used_units.First);
  while Assigned(uu) do
    begin
      um:=uu.u;
      if not um.scc_finished then
        begin
          Result:=find_unfinished_leaf_scc(um);
          if Result<>nil then exit;
        end;
      uu:=TUsedUnit(uu.Next);
    end;
  Result:=nil;
end;

function TTaskHandler.is_uses_waiting(m: TModule; uu: TUsedUnit): boolean;
var
  um: TModule;
  check_impl_uses, check_crc: boolean;
begin
  um:=uu.u;
  TPPUModule(m).Get_Check_Uses(check_impl_uses, check_crc);

  if (uu.in_interface or check_impl_uses)
      and not um.interface_compiled then
    exit(true); { waiting for interface_compiled }

  if check_crc and not um.crc_final then
    exit(true); { waiting for crc }

  Result:=false;
end;

function TTaskHandler.check_do_reload_cycle(scc_root: TModule): boolean;
{ return true if something changed }
var
  m, firstwaiting: TModule;
  HasDoReload: Boolean;
begin
  Result:=false;
  HasDoReload:=false;
  m:=scc_root;
  while Assigned(m) do
    begin
      if m.do_reload then
        begin
          HasDoReload:=true;
          if not TPPUModule(m).CanReload(firstwaiting,true) then
            exit;
        end;
      m:=m.scc_next;
    end;

  if not HasDoReload then
    exit;

  { reload all do_reloads }
  Result:=true;
  m:=scc_root;
  while Assigned(m) do
    begin
      if m.do_reload then
        begin
          {$IFDEF DEBUG_CTASK}
          WriteLn('PPUALGO ttask_handler.check_do_reload_cycle reloading ',m.ModuleName^,' ',m.StateStr,' ...');
          {$ENDIF}
          reload_module(m);
        end;
      m:=m.scc_next;
    end;
end;

function TTaskHandler.check_crc_mismatches(scc_root: TModule): boolean;
{ recompile all scc modules whose crc of used units mismatch }
var
  m, next_m: TModule;
  pu: TUsedUnit;
  check_impl_uses, check_crc: Boolean;
begin
  Result:=false;
  m:=scc_root;
  while Assigned(m) do
    begin
      next_m:=m.scc_next;
      if TPPUModule(m).Get_Check_Uses(check_impl_uses, check_crc) or check_crc then
        begin
          pu:=TUsedUnit(m.used_units.First);
          while Assigned(pu) do
            begin
              if pu.in_interface or check_crc then
                begin
                  if (pu.u.interface_compiled
                      and ((pu.u.InterfaceCRC<>pu.InterfaceChecksum)
                        or (pu.u.IndirectCRC<>pu.IndirectChecksum)))
                      or (pu.u.crc_final and check_crc and (pu.u.crc<>pu.checksum) ) then
                    begin
                      {$IFDEF DEBUG_CTASK}
                      WriteLn('PPUALGO ttask_handler.check_crc_mismatches recompile ',m.ModuleName^,' ',m.StateStr,' ',BoolToStr(pu.in_interface,'interface','implementation'),' uses ',pu.u.ModuleName^,' ...');
                      {$ENDIF}
                      recompile_module(m);
                      Result:=true;
                      break;
                    end;
                end;
              pu:=TUsedUnit(pu.Next);
            end;
        end;
      m:=next_m;
    end;
end;

function TTaskHandler.check_cycle_wait_for_pas(scc_root: TModule): boolean;
{ find a waiting pas module A (non ppu),
  dfs through the scc to find all modules waiting for A,
  choose a ppu module to recompile }
var
  pas_mod, best: TModule;

  function search(m: TModule): boolean;
  var
    uu: TUsedUnit;
    um: TModule;
    i: Integer;
  begin
    Result:=false;
    if m.cycle_search_stamp=TModule.cycle_stamp then exit;
    m.cycle_search_stamp:=TModule.cycle_stamp;

    uu:=TUsedUnit(m.used_units.First);
    while Assigned(uu) do
      begin
        um:=uu.u;
        if um=pas_mod then
          begin
            { m waits for pas_mod }
            Result:=true;
            if m.FromPPU then
              begin
                best:=m;
                exit;
              end;
          end;
        if (um.scc_root=m.scc_root)
            and is_uses_waiting(m,uu) then
          begin
            if search(um) then
              begin
                Result:=true;
                if m.FromPPU then
                  begin
                    best:=m;
                    exit;
                  end;
              end;
          end;
        uu:=TUsedUnit(uu.Next);
      end;

    if (m.state=ms_compiling_waitfinish) and Assigned(m.waitingforunit) then
      begin
        for i:=0 to m.waitingforunit.Count do
          begin
            um:=TModule(m.waitingforunit[i]);
            if um=pas_mod then
              begin
                { m waits for pas_mod }
                Result:=true;
                if m.FromPPU then
                  begin
                    best:=m;
                    exit;
                  end;
              end;
            if search(um) then
              begin
                Result:=true;
                if m.FromPPU then
                  begin
                    best:=m;
                    exit;
                  end;
              end;
          end;
      end;
  end;

begin
  Result:=false;

  { find one pas module (non ppu) }
  best:=nil;
  TModule.increase_cycle_stamp;
  pas_mod:=scc_root;
  while Assigned(pas_mod) do
    begin
      if pas_mod.FromPPU then
        begin
          { dfs through the scc to find a ppu waiting for pas_mod and vice versus
            Note: already searched pas are skipped, resulting in linear time }
          search(pas_mod);

          if best<>nil then
            begin
              { waiting ppu found -> recompile }
              {$IFDEF DEBUG_CTASK}
              WriteLn('PPUALGO ttask_handler.check_cycle_wait_for_pas breaking cycle, recompiling ',best.ModuleName^,' ',best.StateStr,' ...');
              {$ENDIF}
              recompile_module(best);
              exit(true);
            end;
        end;
      pas_mod:=pas_mod.scc_next;
    end;
end;

function TTaskHandler.recompile_pending(scc_root: TModule): boolean;
var
  m, next: TModule;
begin
  Result:=false;
  m:=scc_root;
  while Assigned(m) do
    begin
      next:=m.scc_next;
      if m.do_recompile then
        begin
          {$IFDEF DEBUG_CTASK}
          WriteLn('PPUALGO ttask_handler.recompile_pending recompiling ',m.ModuleName^,' ',m.StateStr,' ...');
          {$ENDIF}
          Result:=true;
          recompile_module(m);
        end;
      m:=next;
    end;
end;

procedure TTaskHandler.recompile_scc(scc_root: TModule);
var
  m, next, firstwaiting: TModule;
  changed: Boolean;
begin
  {$IFDEF DEBUG_PPU_CYCLES}
  WriteLn('ttask_handler.recompile_scc root=',scc_root.ModuleName^,' ',scc_root.StateStr,' size=',get_scc_count(scc_root));
  m:=scc_root;
  while Assigned(m) do
  begin
    cancontinue(m,firstwaiting);
    WriteLn('PPUALGO ttask_handler.recompile_scc module: ',m.ModuleName^,' ',m.StateStr,' firstwaiting=',firstwaiting.ModuleName^,' ',firstwaiting.StateStr);
    m:=m.scc_next;
  end;
  {$ENDIF}
  repeat
    changed:=false;
    m:=scc_root;
    while Assigned(m) do
      begin
        next:=m.scc_next;
        if m.do_reload then
          begin
            {$IFDEF DEBUG_CTASK}
            WriteLn('PPUALGO ttask_handler.recompile_scc breaking cycle, recompiling ',m.ModuleName^,' ',m.StateStr,' ...');
            {$ENDIF}
            changed:=true;
            recompile_module(m);
          end;
        m:=next;
      end;

    if not changed then
      begin
        m:=scc_root;
        while Assigned(m) and not cancontinue(m,firstwaiting) do
          m:=m.scc_next;
        if m=nil then
          begin
            write_scc;
            WriteLn('ttask_handler.recompile_scc no more do_reloads and still can not continue');
            InternalError(2026033114);
          end;
      end;
  until not changed;
end;

function TTaskHandler.check_compiled_uses(dst: TModule): TModule;

  function search_dest(compiled_module: TModule): boolean;
  var
    visited: array of boolean;

    function search(m: TModule): boolean;
    var
      uu: TUsedUnit;
    begin
      Result:=false;
      if m=dst then
        exit(true);
      if m.scc_finished then exit;
      if visited[m.ModuleID] then exit;
      visited[m.ModuleID]:=true;

      uu:=TUsedUnit(m.used_units.First);
      while Assigned(uu) do
        begin
          if search(uu.u) then exit(true);
          uu:=TUsedUnit(uu.Next);
        end;
    end;

  begin
    visited:=nil;
    SetLength(visited,length(all_modules));
    Result:=search(compiled_module);
  end;

  function search_compiled(m: TModule): boolean;
  var
    uu: TUsedUnit;
  begin
    Result:=false;
    if m.scc_finished then exit;

    if m.cycle_search_stamp=TModule.cycle_stamp then exit;
    m.cycle_search_stamp:=TModule.cycle_stamp;

    if m.state in [ms_compiled,ms_processed] then
      begin
        if search_dest(m) then
          begin
            check_compiled_uses:=m;
            exit(true);
          end;
      end;

    uu:=TUsedUnit(m.used_units.First);
    while Assigned(uu) do
      begin
        if search_compiled(uu.u) then exit;
        uu:=TUsedUnit(uu.Next);
      end;
  end;

begin
  Result:=nil;
  TModule.increase_cycle_stamp;
  search_compiled(main_module);
end;

function TTaskHandler.Restore_State(m: TModule): TTask;
begin
  Result:=findtask(m);
  if Result=nil then
    begin
      addmodule(m);
      Result:=findtask(m);
    end
  else if Result.state<>nil then
    Result.RestoreState;
end;

function TTaskHandler.reload_module(m: TModule): TTask;
begin
  if m.state in [ms_compiled,ms_processed] then
    begin
      write_scc;
      WriteLn('ttask_handler.reload_module ',m.ModuleName^,' ',m.StateStr);
      InternalError(2026022410);
    end;
  if m.scc_finished then
    begin
      write_scc;
      WriteLn('ttask_handler.reload_module ',m.ModuleName^,' ',m.StateStr);
      InternalError(2026022411);
    end;


  Result:=Restore_State(m);
  TPPUModule(m).reload;
  Result.SaveState;
  TGlobalState.Clear_State;
end;

function TTaskHandler.recompile_module(m: TModule): TTask;
begin
  if m.state in [ms_compiled,ms_processed] then
    begin
      write_scc;
      WriteLn('ttask_handler.recompile_module ',m.ModuleName^,' ',m.StateStr);
      InternalError(2026022413);
    end;
  if m.scc_finished then
    begin
      write_scc;
      WriteLn('ttask_handler.recompile_module ',m.ModuleName^,' ',m.StateStr);
      InternalError(2026022414);
    end;
  {$IFDEF DEBUG_UR_RECOMPILE}
  if (mf_release in m.moduleflags) and not m.IsInitial then begin
    WriteLn('ttask_handler.recompile_module UR ',m.ModuleName^,' ',m.StateStr);
    InternalError(2026030915);
  end;
  {$ENDIF}


  Result:=Restore_State(m);
  if m.recompile_reason=rr_unknown then
    m.recompile_reason:=rr_buildcycle;
  TPPUModule(m).Recompile_From_Sources;
  addmodule(m);
  TGlobalState.Clear_State;
end;

procedure TTaskHandler.update_circular_unit_groups;
var
  {$IFDEF DEBUG_PPU_CYCLES}
  grp_cnt: integer;
  {$ENDIF}
  cnt: Integer;
  cur_index: integer;
  stack: array of TModule;
  stackindex: integer;

  procedure scc_traverse(m: TModule);
    var
      uu: TUsedUnit;
      um, prev: TModule;
    begin
      inc(cur_index);
      m.scc_index:=cur_index;
      m.scc_lowindex:=cur_index;
      //writeln('scc_traverse ',m.modulename^,' cur_index=',cur_index,' ',length(stack),' stackindex=',stackindex);
      stack[stackindex]:=m;
      inc(stackindex);
      m.scc_onstack:=true;

      uu:=TUsedUnit(m.used_units.first);
      while Assigned(uu) do
        begin
          um:=uu.u;
          if not um.scc_finished then
            begin
              if um.scc_index=0 then
                begin
                  scc_traverse(um);
                  if m.scc_lowindex > um.scc_lowindex then
                    m.scc_lowindex:=um.scc_lowindex;
                end
              else if um.scc_onstack then
                begin
                  { um is in same scc }
                  if m.scc_lowindex > um.scc_index then
                    m.scc_lowindex:=um.scc_index;
                end;
            end;
          uu:=TUsedUnit(uu.next);
        end;

      if m.scc_lowindex = m.scc_index then
        begin
          { new scc, pop from stack }
          {$IFDEF DEBUG_PPU_CYCLES}
          WriteLn('scc_traverse scc_root=',m.ModuleName^,' ',m.StateStr);
          inc(grp_cnt);
          {$ENDIF}
          prev:=nil;
          repeat
            dec(stackindex);
            um:=stack[stackindex];
            {$IFDEF DEBUG_PPU_CYCLES}
            if m<>um then WriteLn('  scc module: ',um.ModuleName^,' ',um.StateStr);
            {$ENDIF}
            um.scc_onstack:=false;
            um.scc_root:=m;
            um.scc_next:=prev;
            um.scc_lowindex:=m.scc_lowindex;
            prev:=um;
          until m=um;
        end;
    end;

  procedure scc_clear(m: TModule);
    var
      uu: TUsedUnit;
    begin
      if m.scc_finished then exit;

      if m.cycle_search_stamp=TModule.cycle_stamp then
        exit; { already visited }
      m.cycle_search_stamp:=TModule.cycle_stamp;

      inc(cnt);
      m.scc_root:=nil;
      m.scc_next:=nil;
      m.scc_index:=0;
      m.scc_lowindex:=0;
      m.scc_onstack:=false;
      m.scc_tree_crc_wait:=nil;
      uu:=TUsedUnit(m.used_units.First);
      while Assigned(uu) do
        begin
          if not uu.u.scc_finished then
            scc_clear(uu.u);
          uu:=TUsedUnit(uu.Next);
        end;
    end;

begin
  cnt:=0;
  TModule.increase_cycle_stamp;
  scc_clear(main_module);
  stack:=[];
  SetLength(stack,cnt);
  stackindex:=0;

  {$IFDEF DEBUG_PPU_CYCLES}
  grp_cnt:=0;
  {$ENDIF}
  cur_index:=0;
  scc_traverse(main_module);
  {$IFDEF DEBUG_PPU_CYCLES}
  WriteLn('tmodule.update_circular_unit_groups modulecnt=',cnt,' grp_cnt=',grp_cnt);
  {$ENDIF}
end;

procedure TTaskHandler.processqueue;

var
  firstwaiting, m, scc_root, best: TModule;
  {$IFDEF DEBUG_CTASK}
  loopcnt: integer;
  {$ENDIF}
begin
  { Strategy: goal is to write ppus early, so that mem is freed early and in case of an error
              next compile can load ppus instead of compiling again. }
  {$IFDEF DEBUG_CTASK}
  loopcnt:=0;
  {$ENDIF}
  scc_root:=nil;
  repeat
    {$IFDEF DEBUG_CTASK}
    inc(loopcnt);
    WriteLn('CTASK: Iteration: ',loopcnt);
    {$ENDIF}

    if main_module.state<ms_compiled then
      recompile_pending(scc_root);

    { compute circular unit groups aka scc (strongly connected components) }
    update_circular_unit_groups;

    { compute scc_tree_unfinished and other_scc_unfinished, and mark finished scc }
    TModule.increase_cycle_stamp;
    search_finished_scc(main_module);
    { now each scc root module has scc_tree_unfinished and other_scc_unfinished:
        scc_tree_unfinished=true means at least one module is not yet finished (do_reload or not ms_compiled)
        other_scc_unfinished=true means at least one sub scc has one unfinished module }

    if not main_module.scc_tree_unfinished then
      exit;

    { find a scc with at least one unfinished module and all sub scc are finished }
    TModule.increase_cycle_stamp;
    scc_root:=find_unfinished_leaf_scc(main_module);
    if scc_root=nil then
    begin
      write_scc;
      InternalError(2026022204);
    end;
    {$IFDEF DEBUG_PPU_CYCLES}
    WriteLn('ttask_handler.processqueue scc_root: ',scc_root.ModuleName^,' ',scc_root.StateStr);
    {$ENDIF}


    { recompile marked modules }
    if recompile_pending(scc_root) then
      continue;

    { check all scc' modules if crc mismatch }
    if check_crc_mismatches(scc_root) then
      continue;

    { check if any of the scc' modules can continue }
    best:=nil;
    m:=scc_root;
    while Assigned(m) do
      begin
        {$IFDEF DEBUG_PPU_CYCLES}
        //writeln('ttask_handler.processqueue check scc module: ',m.modulename^,' ',m.statestr);
        {$ENDIF}
        if (m.state<ms_processed) and cancontinue(m,firstwaiting) then
          begin
            { prefer do_reload, then pas, last ppu }
            if (best=nil)
                or m.do_reload
                or (not best.do_reload and best.FromPPU and not m.FromPPU)
            then
              best:=m;
          end;
        m:=m.scc_next;
      end;

    if best=nil then
      begin
        { checking for a do_reload cycle }
        if check_do_reload_cycle(scc_root) then
          continue;
        { break the cycle by recompiling one ppu module waiting for a pas }
        if check_cycle_wait_for_pas(scc_root) then
          continue;
        { finally: recompile the whole scc }
        recompile_scc(scc_root);
        continue;
      end;

    {$IF defined(DEBUG_CTASK) or defined(Debug_FreeParseMem)}WriteLn('CTASK: continuing ',best.ToString,' state=',best.StateStr,' total-units=',loaded_units.Count,' tasks=',taskcount);{$ENDIF}
    if continue_module(best) then
      // done
    else if best.state=ms_moduleerror then
      exit;
  until false;
end;

procedure TTaskHandler.addmodule(m: TModule);

var
  t : TTask;

begin
  t:=findtask(m);
  if t=nil then
    begin
    {$IFDEF DEBUG_CTASK}WriteLn('CTASK: ',m.ToString,' added to task scheduler. State: ',m.StateStr,' moduleid=',m.ModuleID);{$ENDIF}
    { Clear reset flag.
      This can happen when during load, reset is done and unit is added to task list. }
    m.is_reset:=false;
    t:=createtask(m);
    end
  else
    begin
    { We have a task, if it was reset, then clear the state. }
    if m.is_reset then
      begin
      {$IFDEF DEBUG_CTASK}WriteLn('CTASK: ',m.ToString,' was reset, resetting flag. State: ',m.StateStr);{$ENDIF}
      m.is_reset:=false;
      t.DiscardState;
      end;
    end;
  TModule.ctask_fast_backtrack:=true;
end;

procedure TTaskHandler.write_scc;

  function Search(m: TModule; const Indent: string): TModule;
  // returns m, if m is an unfinished scc
  var
    firstwaiting, sub_scc, um: TModule;
    uu, um2: TUsedUnit;
  begin
    Result:=nil;
    if m.cycle_search_stamp=TModule.cycle_stamp then exit;
    m.cycle_search_stamp:=TModule.cycle_stamp;

    sub_scc:=nil;
    uu:=TUsedUnit(m.used_units.First);
    while Assigned(uu) do
      begin
        um:=Search(uu.u,Indent+'  ');
        if sub_scc=nil then sub_scc:=um;
        uu:=TUsedUnit(uu.Next);
      end;

    firstwaiting:=nil;
    if m=m.scc_root then
      cancontinue(m,firstwaiting);
    write(Indent,' ',m.ModuleName^,' ',m.StateStr);
    if m.scc_finished then
      write('  scc_finished');
    if m=m.scc_root then
      begin
        if not m.scc_finished and m.scc_tree_unfinished then
          Result:=m;
        write(' SCC ',get_scc_count(m),' WaitForSCC=',m.other_scc_unfinished);
        if sub_scc<>nil then
          begin
            // has an unfinished sub scc
            if not m.other_scc_unfinished then
              begin
                WriteLn;
                WriteLn('ERROR: has unfinished sub scc: ',sub_scc.ModuleName^,' ',sub_scc.StateStr,' scc_tree_unfinished=',sub_scc.scc_tree_unfinished);
                InternalError(2026022205);
              end
            else
              write(' unfinished sub scc=',sub_scc.ModuleName^,' ',sub_scc.StateStr);
          end
        else
          begin
            // has no unfinished sub scc
            if m.other_scc_unfinished then
              begin
                WriteLn;
                WriteLn('ERROR: this scc has no unfinished sub scc:');
                um:=m;
                while Assigned(um) do
                  begin
                    cancontinue(um,firstwaiting);
                    write('  ',um.ModuleName^,' ',um.StateStr,' tree_unfinished=',um.scc_tree_unfinished,' other=',um.other_scc_unfinished);
                    if um.scc_finished then
                      write(' ERROR:scc_finished');
                    if firstwaiting<>nil then
                      write(' WaitsFor=',firstwaiting.ModuleName^,' ',firstwaiting.StateStr)
                    else
                      write(' WaitsFor=nil');
                    if um.scc_root<>m then
                      if um.scc_root<>nil then
                        write(' ERROR:scc_root=',um.scc_root.ModuleName^)
                      else
                        write(' ERROR:scc_root=nil');
                    WriteLn;

                    um2:=TUsedUnit(um.used_units.First);
                    while Assigned(um2) do
                      begin
                        WriteLn('    ',um2.u.ModuleName^,' ',um2.u.StateStr,' scc_finished=',um2.u.scc_finished,' tree_unfinished=',um2.u.scc_tree_unfinished);
                        um2:=TUsedUnit(um2.Next);
                      end;

                    um:=um.scc_next;
                  end;
                InternalError(2026022206);
              end;
            if firstwaiting<>nil then
              write(' WaitForMod=',firstwaiting.ModuleName^,' ',firstwaiting.StateStr)
            else
              write(' WaitForMod=nil');
          end;
      end
    else
      begin
        if m.scc_root=nil then
          write(' ERROR: scc_root=nil')
        else begin
          write(' scc_root=',m.scc_root.ModuleName^);
          cancontinue(m,firstwaiting);
          if firstwaiting<>nil then
            write(' WaitForMod=',firstwaiting.ModuleName^,' ',firstwaiting.StateStr)
          else
            write(' WaitForMod=nil');
        end;
      end;
    WriteLn;
  end;

begin
  WriteLn('ttask_handler.write_scc');
  TModule.increase_cycle_stamp;
  Search(main_module,'');
end;

function TTaskHandler.get_scc_count(scc_root: TModule): integer;
begin
  Result:=0;
  while Assigned(scc_root) do
    begin
      inc(Result);
      scc_root:=scc_root.scc_next;
    end;
end;

function TTaskHandler.has_scc_another_unfinished_module(m: TModule): boolean;
var
  scc_root: TModule;
begin
  Result:=false;
  scc_root:=m.scc_root;
  while Assigned(scc_root) do
    begin
      if (m<>scc_root) and (scc_root.state<>ms_processed) then
        exit(true);
      scc_root:=scc_root.scc_next;
    end;
end;

procedure TTaskHandler.check_scc_tree(curr_scc: TModule);
var
  Visited: array of boolean;

  procedure mark_reachable(m: TModule);

    procedure mark(sub: TModule);
    var
      uu: TUsedUnit;
    begin
      if sub.scc_finished then exit;
      if sub.cycle_search_stamp=TModule.cycle_stamp then exit;
      sub.cycle_search_stamp:=TModule.cycle_stamp;

      uu:=TUsedUnit(sub.used_units.First);
      while Assigned(uu) do
        begin
          mark(uu.u);
          uu:=TUsedUnit(uu.Next);
        end;
    end;

  begin
    TModule.increase_cycle_stamp;
    mark(m);
  end;

  function can_reach(src, dst: TModule): boolean;

    function search(m: TModule): boolean;
    var
      uu: TUsedUnit;
    begin
      Result:=false;
      if m.cycle_search_stamp=TModule.cycle_stamp then exit;
      m.cycle_search_stamp:=TModule.cycle_stamp;

      uu:=TUsedUnit(m.used_units.First);
      while Assigned(uu) do
        begin
          if uu.u=dst then exit(true);
          if search(uu.u) then exit(true);
          uu:=TUsedUnit(uu.Next);
        end;
    end;

  begin
    TModule.increase_cycle_stamp;
    Result:=search(src);
  end;

  procedure check(m: TModule);
  var
    um: TModule;
    uu: TUsedUnit;
  begin
    if Visited[m.ModuleID] then exit;
    Visited[m.ModuleID]:=true;

    um:=m.find_used_unit_compiling;

    if m.scc_finished or (m.state in [ms_compiled,ms_processed]) then
      begin
        if um<>nil then
          begin
            write_scc;
            WriteLn(m.ModuleName^,' ',m.StateStr,' scc_finished=',m.scc_finished,' uses ',um.ModuleName^,' ',um.StateStr);
            InternalError(2026032905);
          end;
        exit;
      end;

    // the scc_tree_crc_wait is only valid for the current scc
    if curr_scc=m.scc_root then
      begin
        if (m.scc_tree_crc_wait<>nil) and (um=nil) then
          begin
            write_scc;
            WriteLn('INVALID scc_tree_crc_wait: ',m.ModuleName^,' ',m.StateStr,' scc_tree_crc_wait=',m.scc_tree_crc_wait.ModuleName^,' ',m.scc_tree_crc_wait.StateStr);
            InternalError(2026032906);
          end;

        if (m.scc_tree_crc_wait=nil) and (um<>nil) then
          begin
            write_scc;
            WriteLn('INVALID scc_tree_crc_wait: ',m.ModuleName^,' ',m.StateStr,' scc_tree_crc_wait=nil uses ',um.ModuleName^,' ',um.StateStr);
            InternalError(2026032907);
          end;
      end;

    if m.scc_root=nil then
      begin
        WriteLn('INVALID scc_root: ',m.ModuleName^,' ',m.StateStr);
        InternalError(2026032908);
      end;

    if m.scc_root=m then
      begin
        { check if scc root uses all modules in the scc_next list  }
        TModule.increase_cycle_stamp;
        mark_reachable(m);
        um:=m.scc_next;
        while Assigned(um) do
          begin
            if um.cycle_search_stamp<>TModule.cycle_stamp then
              begin
                write_scc;
                WriteLn('INVALID scc_next: ',m.ModuleName^,' ',m.StateStr,' um=',um.ModuleName^,' ',um.StateStr);
                InternalError(2026032909);
              end;
            um:=um.scc_next;
          end;
      end
    else
      begin
        { check if all scc_next can reach their scc_root }
        if not can_reach(m,m.scc_root) then
          begin
            write_scc;
            WriteLn('INVALID scc_root: ',m.ModuleName^,' ',m.StateStr,' m.scc_root=',m.scc_root.ModuleName^,' ',m.scc_root.StateStr);
            InternalError(2026032910);
          end;
      end;

    // check recursively
    uu:=TUsedUnit(m.used_units.First);
    while Assigned(uu) do
      begin
        check(uu.u);
        uu:=TUsedUnit(uu.Next);
      end;

  end;

begin
  Visited:=nil;
  SetLength(Visited,length(all_modules));

  check(main_module);
end;

end.

