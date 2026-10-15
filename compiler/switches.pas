{
    Copyright (c) 1998-2002 by Peter Vreman

    This unit implements the parsing of the switches like $I-

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
unit switches;

{$i fpcdefs.inc}

interface

uses
  Systems,GlobType;

procedure HandleSwitch(Switch,State:Char);
function CheckSwitch(Switch,State:Char):Boolean;
function IsRecognizedSwitch(Switch:Char):Boolean;

procedure RecordPendingVerbositySwitch(SW: Char; State: Char);
procedure RecordPendingMessageState(Msg: LongInt; State: TMsgState);
procedure RecordPendingLocalSwitch(SW: TLocalSwitch; State: Char);
procedure RecordPendingLocalFullSwitch(const Switches: TLocalSwitches);
procedure RecordPendingVerbosityFullSwitch(Verbosity: LongInt);
procedure RecordPendingCallingSwitch(const Str: ShortString);
procedure RecordPendingAlignmentFullSwitch(const Alignment : TAlignmentInfo);
procedure RecordPendingSetAlloc(Alloc:ShortInt);
procedure RecordPendingPackEnum(Size:ShortInt);
procedure RecordPendingPackRecords(Size:ShortInt);
procedure RecordPendingAsmMode(AsmMode:TAsmMode);
procedure RecordPendingOptimizerSwitches(OptimizerSwitches:TOptimizerSwitches);
procedure FlushPendingSwitchesState;

implementation
uses
  CPUInfo,

  Globals,Verbose,CompHook,DirParse,CClasses,
  FModule;

{****************************************************************************
                          Main Switches Parsing
****************************************************************************}

type
  TSwitchType=(ignoredsw,unknownsw,localsw,modulesw,globalsw,illegalsw,removedsw,unsupportedsw,alignsw,optimizersw,packenumsw,pentiumfdivsw,targetsw);
  SwitchRec=record
    TypeSW : TSwitchType;
    SetSW  : Byte;
  end;
  TSwitchRec = SwitchRec;
  SwitchRecTable = array['A'..'Z'] of TSwitchRec;
  TSwitchRecTable = SwitchRecTable;

const
  TurboSwitchTable: TSwitchRecTable =(
   {A} (TypeSW:AlignSW; SetSW:Ord(cs_localnone)),
   {B} (TypeSW:LocalSW; SetSW:Ord(cs_full_boolean_eval)),
   {C} (TypeSW:LocalSW; SetSW:Ord(cs_do_assertion)),
   {D} (TypeSW:ModuleSW; SetSW:Ord(cs_debuginfo)),
   {E} (TypeSW:UnknownSW; SetSW:Ord(cs_localnone)),

   {F} (TypeSW:UnknownSW; SetSW:Ord(cs_localnone)),

   {G} (TypeSW:RemovedSW; SetSW:Ord(cs_localnone)),
   {H} (TypeSW:IgnoredSW; SetSW:Ord(cs_localnone)),
   {I} (TypeSW:LocalSW; SetSW:Ord(cs_check_io)),
   {J} (TypeSW:LocalSW; SetSW:Ord(cs_typed_const_writable)),
   {K} (TypeSW:UnsupportedSW; SetSW:Ord(cs_localnone)),
   {L} (TypeSW:UnsupportedSW; SetSW:Ord(cs_localnone)),
   {M} (TypeSW:LocalSW; SetSW:Ord(cs_generate_rtti)),
   {N} (TypeSW:UnknownSW; SetSW:Ord(cs_localnone)),
   {O} (TypeSW:OptimizerSW; SetSW:Ord(cs_opt_level2)),
   {P} (TypeSW:LocalSW; SetSW:Ord(cs_openstring)),
   {Q} (TypeSW:LocalSW; SetSW:Ord(cs_check_overflow)),
   {R} (TypeSW:LocalSW; SetSW:Ord(cs_check_range)),
   {S} (TypeSW:LocalSW; SetSW:Ord(cs_check_stack)),
   {T} (TypeSW:LocalSW; SetSW:Ord(cs_typed_addresses)),
   {U} (TypeSW:PentiumFDivSW; SetSW:Ord(cs_localnone)),
   {V} (TypeSW:LocalSW; SetSW:Ord(cs_strict_var_strings)),

   {W} (TypeSW:LocalSW; SetSW:Ord(cs_generate_stackframes)),

   {X} (TypeSW:ModuleSW; SetSW:Ord(cs_extsyntax)),
   {Y} (TypeSW:UnsupportedSW; SetSW:Ord(cs_localnone)),
   {Z} (TypeSW:PackEnumSW; SetSW:Ord(cs_localnone))
    );


  MacSwitchTable: TSwitchRecTable =(
   {A} (TypeSW:UnsupportedSW; SetSW:Ord(cs_localnone)),
   {B} (TypeSW:LocalSW; SetSW:Ord(cs_full_boolean_eval)),
   {C} (TypeSW:LocalSW; SetSW:Ord(cs_do_assertion)),
   {D} (TypeSW:ModuleSW; SetSW:Ord(cs_debuginfo)),
   {E} (TypeSW:UnknownSW; SetSW:Ord(cs_localnone)),

   {F} (TypeSW:UnknownSW; SetSW:Ord(cs_localnone)),

   {G} (TypeSW:RemovedSW; SetSW:Ord(cs_localnone)),
   {H} (TypeSW:IgnoredSW; SetSW:Ord(cs_localnone)),
   {I} (TypeSW:LocalSW; SetSW:Ord(cs_check_io)),
   {J} (TypeSW:LocalSW; SetSW:Ord(cs_external_var)),
   {K} (TypeSW:UnsupportedSW; SetSW:Ord(cs_localnone)),
   {L} (TypeSW:UnsupportedSW; SetSW:Ord(cs_localnone)),
   {M} (TypeSW:LocalSW; SetSW:Ord(cs_generate_rtti)),
   {N} (TypeSW:UnknownSW; SetSW:Ord(cs_localnone)),
   {O} (TypeSW:OptimizerSW; SetSW:Ord(cs_opt_level2)),
   {P} (TypeSW:LocalSW; SetSW:Ord(cs_openstring)),
   {Q} (TypeSW:LocalSW; SetSW:Ord(cs_check_overflow)),
   {R} (TypeSW:LocalSW; SetSW:Ord(cs_check_range)),
   {S} (TypeSW:LocalSW; SetSW:Ord(cs_check_stack)),
   {T} (TypeSW:LocalSW; SetSW:Ord(cs_typed_addresses)),
   {U} (TypeSW:IllegalSW; SetSW:Ord(cs_localnone)),
   {V} (TypeSW:LocalSW; SetSW:Ord(cs_strict_var_strings)),

   {W} (TypeSW:LocalSW; SetSW:Ord(cs_generate_stackframes)),

   {X} (TypeSW:ModuleSW; SetSW:Ord(cs_extsyntax)),
   {Y} (TypeSW:UnsupportedSW; SetSW:Ord(cs_localnone)),
   {Z} (TypeSW:LocalSW; SetSW:Ord(cs_externally_visible))
    );

function IsRecognizedSwitch(Switch:Char):Boolean;
  begin
    Switch:=UpCase(Switch);
    if not(Switch in ['A'..'Z']) then
      Exit(False);
    if m_mac in CurrentSettings.ModeSwitches then
      Result:=MacSwitchTable[Switch].TypeSW<>UnknownSW
    else
      Result:=TurboSwitchTable[Switch].TypeSW<>UnknownSW;
  end;

procedure HandleSwitch(Switch,State:Char);

var
  SwitchTablePtr: ^TSwitchRecTable;

begin
  Switch:=UpCase(Switch);
  { Kept for source compatibility with the 3.2.2 bootstrap compiler.
    NexusFPC's default String type cannot be changed within a unit. }
  if (Switch='H') and (State in ['+','-']) then
    Exit;
{ Is the Switch in the letters ? }
  if not ((Switch in ['A'..'Z']) and (State in ['-','+'])) then
   begin
     Message(scan_w_illegal_switch);
     Exit;
   end;

{ Select switch table }
  if m_mac in CurrentSettings.ModeSwitches  then
    SwitchTablePtr:= @MacSwitchTable
  else
    SwitchTablePtr:= @TurboSwitchTable;

{ Handle the switch }
   with SwitchTablePtr^[Switch] do
   begin
     case TypeSW of
       AlignSW:
         begin
           if State='+' then
             RecordPendingPackRecords(4)
           else
             RecordPendingPackRecords(1);
         end;
       OptimizerSW :
         begin
           if State='+' then
             CurrentSettings.OptimizerSwitches:=Level2OptimizerSwitches
           else
             CurrentSettings.OptimizerSwitches:=[];
         end;
       IgnoredSW :
         Message1(scan_n_ignored_switch,'$'+Switch);
       UnknownSW :
         Message1(scan_w_illegal_directive,'$'+Switch+State);
       IllegalSW :
         Message1(scan_w_illegal_switch,'$'+Switch);
       RemovedSW :
         Message1(scan_e_illegal_directive,'$'+Switch+State);
       UnsupportedSW :
         Message1(scan_w_unsupported_switch,'$'+Switch);
       LocalSW :
         RecordPendingLocalSwitch(TLocalSwitch(SetSW),State);
       ModuleSW :
         begin
           if CurrentModule.In_Global then
            begin
                begin
                  if State='+' then
                    Include(CurrentSettings.ModuleSwitches,TModuleSwitch(SetSW))
                  else
                    begin
                      { Turning off debuginfo when lineinfo is requested
                        is not possible }
                      if not((cs_use_lineinfo in CurrentSettings.GlobalSwitches) and
                             (TModuleSwitch(SetSW)=cs_debuginfo)) then
                        Exclude(CurrentSettings.ModuleSwitches,TModuleSwitch(SetSW));
                    end;
                end;
            end
           else
            Message(scan_w_switch_is_global);
         end;
       GlobalSW :
         begin
           if CurrentModule.In_Global and (CurrentModule=main_module) then
            begin
              if State='+' then
               Include(CurrentSettings.GlobalSwitches,TGlobalSwitch(SetSW))
              else
               Exclude(CurrentSettings.GlobalSwitches,TGlobalSwitch(SetSW));
            end
           else
            Message(scan_w_switch_is_global);
         end;
       PackEnumSW:
         begin
           if State='-' then
             CurrentSettings.PackEnum:=1
           else
             CurrentSettings.PackEnum:=4;
         end;
       PentiumFDivSW:
         begin
           { Switch u- means pentium-safe fdiv off -> fpc default. We don't }
           { support u+                                                     }
           if State='+' then
             Message1(scan_w_unsupported_switch,'$'+Switch);
         end;
       TargetSW:
         UpdateTargetSwitchStr(TargetSwitchStr[TTargetSwitch(SetSW)].Name+State,CurrentSettings.TargetSwitches,CurrentModule.In_Global);
     end;
   end;
end;


function CheckSwitch(Switch,State:Char):Boolean;

var
  Found : Boolean;
  SwitchTablePtr: ^TSwitchRecTable;

begin
  Switch:=UpCase(Switch);
  { The long-string default is always enabled; $H cannot change it. }
  if (Switch='H') and (State in ['+','-']) then
    Exit(State='+');
{ Is the Switch in the letters ? }
  if not ((Switch in ['A'..'Z']) and (State in ['-','+'])) then
   begin
     Message(scan_w_illegal_switch);
     CheckSwitch:=False;
     Exit;
   end;

{ Select switch table }
  if m_mac in CurrentSettings.ModeSwitches then
    SwitchTablePtr:= @MacSwitchTable
  else
    SwitchTablePtr:= @TurboSwitchTable;

{ Check the switch }
   with SwitchTablePtr^[Switch] do
   begin
     case TypeSW of
      LocalSW : Found:=(TLocalSwitch(SetSW) in CurrentSettings.LocalSwitches);
     ModuleSW : Found:=(TModuleSwitch(SetSW) in CurrentSettings.ModuleSwitches);
     GlobalSW : Found:=(TGlobalSwitch(SetSW) in CurrentSettings.GlobalSwitches);
     PackEnumSW : Found := (CurrentSettings.PackEnum = 4);
      UnknownSW :
        begin
          Message1(scan_w_illegal_switch,Switch);
          Exit(False);
        end;
      RemovedSW :
        begin
          Message1(scan_e_illegal_directive,'IFOPT '+Switch+State);
          Exit(False);
        end;
     else
      Found:=False;
     end;
     if State='-' then
      Found:=not Found;
     CheckSwitch:=Found;
   end;
end;


procedure RecordPendingVerbositySwitch(SW: Char; State: Char);
  begin
    PendingState.NextVerbosityStr:=PendingState.NextVerbosityStr+SW+State;
  end;


procedure RecordPendingMessageState(Msg: LongInt; State: TMsgState);
  var
    PState : PMessageStateRecord;
  begin
    New(PState);
    {$IFDEF DEBUG_MESSAGESTATE}
    PState^.Owner:=CurrentModule; { nil for global option }
    {$ENDIF}
    PState^.Next:=PendingState.NextMessageRecord;
    PState^.Value:=Msg;
    PState^.State:=State;
    PendingState.NextMessageRecord:=PState;
  end;


procedure RecordPendingLocalSwitch(SW: TLocalSwitch; State: Char);
  begin
    if not (psf_local_switches_changed in PendingState.Flags) then
       PendingState.NextLocalSwitches:=CurrentSettings.LocalSwitches;
    if State='-' then
      Exclude(PendingState.NextLocalSwitches,SW)
    else if State='+' then
      Include(PendingState.NextLocalSwitches,SW)
    else { state = '*' }
      begin
        if SW in InitSettings.LocalSwitches then
         Include(PendingState.NextLocalSwitches,SW)
        else
         Exclude(PendingState.NextLocalSwitches,SW);
      end;
    Include(PendingState.Flags,psf_local_switches_changed);
  end;


procedure RecordPendingAlignmentFullSwitch(const Alignment : TAlignmentInfo);
  begin
    PendingState.NextAlignment:=Alignment;
    Include(PendingState.Flags,psf_alignment_changed);
  end;


procedure RecordPendingLocalFullSwitch(const Switches: TLocalSwitches);
  begin
    PendingState.NextLocalSwitches:=Switches;
    Include(PendingState.Flags,psf_local_switches_changed);
  end;


procedure RecordPendingVerbosityFullSwitch(Verbosity: LongInt);
  begin
    PendingState.NextVerbosityStr:='';
    PendingState.NextVerbosityFullSwitch:=Verbosity;
    Include(PendingState.Flags,psf_verbosity_full_switched);
  end;

procedure RecordPendingCallingSwitch(const Str: ShortString);
  begin
    PendingState.NextCallingStr:=Str;
  end;


procedure RecordPendingSetAlloc(Alloc:ShortInt);
  begin
    PendingState.NextSetAlloc:=Alloc;
    Include(PendingState.Flags,psf_setalloc_changed);
  end;


procedure RecordPendingAsmMode(AsmMode:TAsmMode);
  begin
    PendingState.NextAsmMode:=AsmMode;
    Include(PendingState.Flags,psf_asmmode_changed);
  end;


procedure RecordPendingPackEnum(Size:ShortInt);
  begin
    PendingState.NextPackEnum:=Size;
    Include(PendingState.Flags,psf_packenum_changed);
  end;


procedure RecordPendingPackRecords(Size:ShortInt);
  begin
    PendingState.NextPackRecords:=Size;
    Include(PendingState.Flags,psf_packrecords_changed);
  end;


procedure RecordPendingOptimizerSwitches(OptimizerSwitches:TOptimizerSwitches);
  begin
    PendingState.NextOptimizerSwitches:=OptimizerSwitches;
    Include(PendingState.Flags,psf_optimizerswitches_changed);
  end;


procedure FlushPendingSwitchesState;
  var
    TmpProcCall: TProcCallOption;
    FState, PState : PMessageStateRecord;
    MsgSet : THashSet;
    MsgFound : Boolean;
  begin
    { process pending localswitches (range checking, etc) }
    if psf_local_switches_changed in PendingState.Flags then
      begin
        CurrentSettings.LocalSwitches:=PendingState.NextLocalSwitches;
        Include(CurrentSettings.LocalSwitches,cs_refcountedstrings);
        Exclude(PendingState.Flags,psf_local_switches_changed);
      end;
    { process pending verbosity changes (warnings on, etc) }
    if psf_verbosity_full_switched in PendingState.Flags then
      begin
        Status.Verbosity:=PendingState.NextVerbosityFullSwitch;
        Exclude(PendingState.Flags,psf_verbosity_full_switched);
      end;
    if psf_alignment_changed in PendingState.Flags then
      begin
        CurrentSettings.Alignment:=PendingState.NextAlignment;
        Exclude(PendingState.Flags,psf_alignment_changed);
      end;
    if psf_packenum_changed in PendingState.Flags then
      begin
        CurrentSettings.PackEnum:=PendingState.NextPackEnum;
        Exclude(PendingState.Flags,psf_packenum_changed);
      end;
    if psf_packrecords_changed in PendingState.Flags then
      begin
        CurrentSettings.PackRecords:=PendingState.NextPackRecords;
        Exclude(PendingState.Flags,psf_packrecords_changed);
      end;
    if psf_setalloc_changed in PendingState.Flags then
      begin
        CurrentSettings.SetAlloc:=PendingState.NextSetAlloc;
        Exclude(PendingState.Flags,psf_setalloc_changed);
      end;
    if psf_asmmode_changed in PendingState.Flags then
      begin
        CurrentSettings.AsmMode:=PendingState.NextAsmMode;
        Exclude(PendingState.Flags,psf_asmmode_changed);
      end;
    if psf_optimizerswitches_changed in PendingState.Flags then
      begin
        CurrentSettings.OptimizerSwitches:=PendingState.NextOptimizerSwitches;
        Exclude(PendingState.Flags,psf_optimizerswitches_changed);
      end;
    { process pending verbosity changes (warnings on, etc) }
    if PendingState.NextVerbosityStr<>'' then
      begin
        SetVerbosity(PendingState.NextVerbosityStr);
        PendingState.NextVerbosityStr:='';
      end;
    { we need to start from a clean slate }
    if not Assigned(CurrentSettings.PMessage) then
      RestoreLocalVerbosity(nil);
    FState:=PendingState.NextMessageRecord;
    PState:=PendingState.NextMessageRecord;
    if Assigned(PState) then
      MsgSet:=THashSet.Create(10,False,False)
    else
      MsgSet:=nil;
    while Assigned(PState) do
      begin
        {$IFDEF DEBUG_MESSAGESTATE}
        if Assigned(PState^.Owner) and (PState^.Owner<>CurrentModule) then
          begin
            WriteLn('flushpendingswitchesstate cur: ',CurrentModule.ModuleName^,' ',CurrentModule.StateStr);
            WriteLn('flushpendingswitchesstate pstate: ',TModule(PState^.Owner).ModuleName^,' ',TModule(PState^.Owner).StateStr);
            InternalError(2026030701);
          end;
        {$ENDIF}
        PendingState.NextMessageRecord:=PState^.Next;
        { the message records are ordered newest to oldest, so only apply the newest change }
        MsgFound:=False;
        if not Assigned(MsgSet.FindOrAdd(@PState^.Value,SizeOf(PState^.Value),MsgFound)) or
            not MsgFound then
          SetMessageVerbosity(PState^.Value,PState^.State);
        if not Assigned(PState^.Next) then
          begin
            PState^.Next:=CurrentSettings.PMessage;
            CurrentSettings.PMessage:=FState;
            PState:=nil;
          end
        else
          PState:=PState^.Next;
        PendingState.NextMessageRecord:=nil;
      end;
    MsgSet.Free;
    MsgSet := nil;
    { process pending calling convention changes (calling x) }
    if PendingState.NextCallingStr<>'' then
      begin
        if not SetAktProcCall(PendingState.NextCallingStr,TmpProcCall) then
          Message1(parser_w_unknown_proc_directive_ignored,PendingState.NextCallingStr)
        else if not(TmpProcCall in supported_calling_conventions) then
          Message1(parser_e_illegal_calling_convention,PendingState.NextCallingStr)
        else
          CurrentSettings.DefProcCall:=TmpProcCall;
        PendingState.NextCallingStr:='';
      end;
  end;


end.
