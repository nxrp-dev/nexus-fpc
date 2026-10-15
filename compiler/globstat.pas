{
    Copyright (c) 2012 by the FPC development team

    Contains functionality to save/restore the global compiler state when
    switching between the compilation of different units.

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
unit globstat;

{$i fpcdefs.inc}

interface

uses
  GlobType,Globals,
  AAsmData,
  DbgBase,
  SymBase,SymSym,
  FModule,
  Scanner,ScanDir,
  ProcInfo;


type
  TSymTableStackKind = (
    stsk_global,
    stsk_macro
    );

  { tglobalstate }
  { Note: this is only needed for pas modules, ppu modules simply skip save and restore
    Especially a ppu does not create its own symtablestack }

  TGlobalState = class
    Reload: Boolean;
  { scanner }
    OldTokenPos    : TFilePosInfo;
    OldBlockType : TBlockType;
  { symtable }
    OldSymTableStack,
    OldMacroSymTableStack : TSymTableStack;
    OldAktProcSym    : TProcSym;
  { cg }
    OldParseOnly  : Boolean;
  { akt.. things }
    OldCurrentFilePos      : TFilePosInfo;
    OldCurrentModule : TModule;
    OldCurrentProcInfo : TProcInfo;
    OldSettings : TSettings;
    OldSwitchesStateStack : TSwitchesStateStack;
    OldSwitchesStateStackPos : Integer;
    OldVerbosity : LongInt;

  { only saved/restored if "full" is true }
    OldAsmData : TAsmData;
    OldDebugInfo : TDebugInfo;
    OldScanner : TScannerFile;
    OldParserFile : string;
    constructor Create(ForModuleSwitch: Boolean);
    destructor Destroy; override;
    procedure ClearScanner;
    class procedure Remove_Scanner_From_States(Scanner : TScannerFile); static;
    procedure Save(ForModuleSwitch: Boolean = False);
    procedure Save_SymTable_Stack(Stack: TSymTableStack; Kind: TSymTableStackKind);
    procedure Restore;
    procedure Reload_SymTable_Stack(Stack: TSymTableStack; Kind: TSymTableStackKind);
    class procedure Clear_State;
  end;

procedure Save_Global_State(State:TGlobalState);
procedure Restore_Global_State(State:TGlobalState);

implementation

uses
  Switches, Verbose, PBase,CompHook;

var
  States : array of TGlobalState;
  StateCount : Integer = 0;



  class procedure TGlobalState.Remove_Scanner_From_States(Scanner : TScannerFile);

  var
    I : Integer;

  begin
    for I:=0 to StateCount-1 do
      if (States[I].OldScanner=Scanner) then
        States[I].ClearScanner;
  end;

  procedure AddState(AState : TGlobalState);

  var
    L : Integer;

  begin
    L:=Length(States);
    if L=StateCount then
      SetLength(States,L+10);
    States[StateCount]:=AState;
    Inc(StateCount);
  end;

  procedure RemoveState(AState : TGlobalState);

  var
    L : Integer;

  begin
    L:=StateCount-1;
    While (L>=0) and (States[L]<>AState) do
      Dec(L);
    if L<0 then
      Exit;
    if L<>StateCount-1 then
      States[L]:=States[StateCount-1];
    States[StateCount-1]:=Nil;
    Dec(StateCount);
  end;

  procedure Save_Global_State(State:TGlobalState);
    begin
      State.Save;
    end;

  procedure Restore_Global_State(State:TGlobalState);

    begin
      State.Restore;
    end;

  procedure TGlobalState.Save(ForModuleSwitch: Boolean);

    begin
      Reload:=ForModuleSwitch;
      OldCurrentModule:=CurrentModule;

      { save symtable state }
      if CurrentModule.FromPPU then
        begin
          { a ppu does not use the symbolstacks
            they might have been set by a pas module loading this ppu
            => do not store them in the the ppu state }
          OldSymTableStack:=nil;
          OldMacroSymTableStack:=nil;
        end
      else
        begin
          { a pas module has symbolstacks, which contain references to other modules
            when switching between modules, the references must be updated as the
            used module might have been recompiled }
          OldSymTableStack:=SymTableStack;
          if ForModuleSwitch then
            Save_SymTable_Stack(OldSymTableStack,stsk_global);
          OldMacroSymTableStack:=MacroSymTableStack;
          if ForModuleSwitch then
            Save_SymTable_Stack(OldMacroSymTableStack,stsk_macro);
        end;
      OldCurrentProcInfo:=CurrentProcInfo;

      { save scanner state }
      OldBlockType:=Block_Type;
      OldTokenPos:=CurrentTokenPos;
      {
        consuming the semicolon after a uses clause can add to the
        pending state if the first directives change warning state.
        So we must flush before context switch. See for example:
        ppcgen/cgppc.pas
        line 144 has a WARN 6018 OFF...
      }
      FlushPendingSwitchesState; { flushpendingswitchesstate before storing current_settings.pmessage, switchesstatestack etc }
      OldSwitchesStateStack:=SwitchesStateStack;
      OldSwitchesStateStackPos:=SwitchesStateStackPos;

      { save cg }
      OldParseOnly:=parse_only;

      { save akt... state }
      { handle the postponed case first }
      OldCurrentFilePos:=CurrentFilePos;
      OldSettings:=CurrentSettings;
      OldVerbosity:=Status.Verbosity;

      OldAsmData:=CurrentAsmData;
      OldDebugInfo:=CurrentDebugInfo;
      OldParserFile:=Parser_Current_File;
      OldScanner:=CurrentScanner;
    end;

  procedure TGlobalState.Save_SymTable_Stack(Stack: TSymTableStack; Kind: TSymTableStackKind);
    var
      Item: PSymTableStackItem;
      M: TModule;
      Id: LongInt;
    begin
      if Stack=nil then Exit;

      Item:=Stack.Stack;
      while Item<>nil do
        begin
          Id:=Item^.SymTable.ModuleID;
          Item^.Saved_ModuleID:=Id;
          if (Id<>CurrentModule.ModuleID) and (Id>0) then
            begin
              M:=Get_Module(Id);
              if M=nil then
                begin
                  WriteLn('tglobalstate.save_symtable_stack ',CurrentModule.ModuleName^,' ',CurrentModule.StateStr,' ',Kind,' unknown moduleid: ',Id);
                  InternalError(2026030103);
                end;
              case Kind of
                stsk_global:
                  if M.GlobalSymTable<>Item^.SymTable then
                    begin
                      WriteLn('tglobalstate.save_symtable_stack ',CurrentModule.ModuleName^,' ',CurrentModule.StateStr,' globalsymstack: item is not globalsymtable of ', M.ModuleName^,' ',M.StateStr);
                      InternalError(2026030101);
                    end;
                stsk_macro:
                  if M.GlobalMacroSymTable<>Item^.SymTable then
                    begin
                      WriteLn('tglobalstate.save_symtable_stack ',CurrentModule.ModuleName^,' ',CurrentModule.StateStr,' globalmacrosymstack: item is not globalmacrosymtable of ', M.ModuleName^,' ',M.StateStr);
                      InternalError(2026030102);
                    end;
              end;
            end;
          Item:=Item^.Next;
        end;
    end;

  procedure TGlobalState.Restore;

    begin
      SetCurrentModule(OldCurrentModule);

      { restore scanner }
      CurrentTokenPos:=OldTokenPos;
      Block_Type:=OldBlockType;
      SwitchesStateStack:=OldSwitchesStateStack;
      SwitchesStateStackPos:=OldSwitchesStateStackPos;

      { restore cg }
      parse_only:=OldParseOnly;

      { restore symtable state }
      SymTableStack:=OldSymTableStack;
      if Reload then
        Reload_SymTable_Stack(SymTableStack,stsk_global);
      MacroSymTableStack:=OldMacroSymTableStack;
      if Reload then
        Reload_SymTable_Stack(MacroSymTableStack,stsk_macro);
      CurrentProcInfo:=OldCurrentProcInfo;
      CurrentFilePos:=OldCurrentFilePos;
      CurrentSettings:=OldSettings;
      Status.Verbosity:=OldVerbosity;

      { restore message settings which were recorded prior to unit switch }
      RestoreLocalVerbosity(CurrentSettings.PMessage);

      // These can be different
      CurrentAsmData:=OldAsmData;
      CurrentDebugInfo:=OldDebugInfo;
    end;

  procedure TGlobalState.Reload_SymTable_Stack(Stack: TSymTableStack; Kind: TSymTableStackKind);
    var
      Item: PSymTableStackItem;
      M: TModule;
      Id: LongInt;
    begin
      if Stack=nil then Exit;
      if OldCurrentModule.FromPPU then
        begin
          { ppu does not have its own symtablestack }
          WriteLn('tglobalstate.reload_symtable_stack ',OldCurrentModule.ModuleName^,' ',OldCurrentModule.StateStr);
          InternalError(2026030106);
        end;
      Item:=Stack.Stack;
      while Item<>nil do
        begin
          Id:=Item^.Saved_ModuleID;
          if (Id<>OldCurrentModule.ModuleID) and (Id>0) then
            begin
              M:=Get_Module(Id);
              case Kind of
                stsk_global: Item^.SymTable:=M.GlobalSymTable;
                stsk_macro:  Item^.SymTable:=M.GlobalMacroSymTable;
              end;
            end;
          Item:=Item^.Next;
        end;
    end;

  class procedure TGlobalState.Clear_State;
    begin
      SymTableStack:=nil;
      MacroSymTableStack:=nil;
      CurrentProcInfo:=nil;

      Block_Type:=bt_none;
      FlushPendingSwitchesState;
      SwitchesStateStack:=default(TSwitchesStateStack);
      SwitchesStateStackPos:=0;

      // keep "current_settings"

      parse_only:=False;
      CurrentAsmData:=nil;
      CurrentDebugInfo:=nil;

      Parser_Current_File:='';
      Set_Current_Scanner(nil);
    end;

  constructor TGlobalState.Create(ForModuleSwitch: Boolean);

    begin
      AddState(Self);
      Save(ForModuleSwitch);
    end;

  destructor TGlobalState.Destroy;

    begin
      RemoveState(Self);
      inherited Destroy;
    end;

  procedure TGlobalState.ClearScanner;

  begin
    OldScanner:=nil;
    OldTokenPos:=Default(TFilePosInfo);
    OldBlockType:=bt_none;
  end;

initialization
  OnFreeScanner:=@TGlobalState.Remove_Scanner_From_States;
finalization
  OnFreeScanner:=Nil;
end.

