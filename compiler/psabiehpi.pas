{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Information about the current procedure that is being compiled

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
unit psabiehpi;

{ $define debug_eh}

{$i fpcdefs.inc}

  interface

    uses
      { common }
      CClasses,
      { global }
      GlobType,
      { symtable }
      symconst,symtype,symdef,SymSym,
      node,nutils,
      { aasm }
      cpubase,cgbase,cgutils,
      aasmbase,AAsmData,aasmtai,
      psub;

    type
       TPSABIEHAction = class
         LandingPad : TAsmLabel;
         ActionTableLabel : TAsmLabel;
         ActionList : TAsmList;
         First : boolean;
         constructor Create(APad : TAsmLabel);
         destructor Destroy; override;
         function AddAction(AObjectDef: TObjectDef): LongInt;
       end;

       { This object gives information on the current routine being
         compiled.
       }
       TPSABIEHProcInfo = class(TCGProcInfo)
         { set if the procedure needs exception tables because it
           has exception generating nodes }
         CreateExceptionTable: Boolean;

         { if a procedure needs exception tables, this is the outmost landing pad
           with "no action", covering everything not covered by other landing pads
           since a procedure which has one landing pad need to be covered completely by landing pads }
         OutmostLandingPad: TPSABIEHAction;

         { This is a "no action" action for re-use, normally equal to OutmostLandingPad }
         NoAction: TPSABIEHAction;

         { label to language specific data }
         LSDALabel : TAsmLabel;
         CallSiteTableData,
         ActionTableData,
         GCCExceptTableData : TAsmList;
         TypeFilterListLabel,TypeFilterListLabelRef,
         CallSiteTableStart,CallSiteTableEnd,
         { first label which must be inserted into the entry code }
         EntryCallSiteStart,
         CallSiteLastStart : TAsmLabel;
         TypeFilterList,
         LandingPadStack,
         ActionStack : TFPList;
         CurrentCallSiteNumber : LongInt;

         destructor Destroy; override;

         { PSABIEH stuff }
         procedure PushAction(AAction: TPSABIEHAction);
         function CurrentAction: TPSABIEHAction;inline;
         function PopAction(AAction: TPSABIEHAction): boolean;
         function FinalizeAndPopAction(AAction: TPSABIEHAction): boolean;
         { a landing pad is also an action, however, when the landing pad is popped from the stack
           the area covered by this landing pad ends, i.e. it is popped at the beginning of the finally/except clause,
           the action above is popped at the end of the finally/except clause, so if on clauses add new types, they
           are added to CurrentAction }
         procedure PushLandingPad(AAction: TPSABIEHAction);
         function CurrentLandingPad: TPSABIEHAction;inline;
         function PopLandingPad(AAction: TPSABIEHAction): boolean;
         procedure CreateNewPSABIEHCallsite(AList: TAsmList);
         { adds a new type to the type filter list and returns its index
           be aware, that this method can also handle catch all filters so it
           is valid to pass nil }
         function AddTypeFilter(AObjectDef: TObjectDef): LongInt;
         procedure Set_EH_Info; override;
         procedure Setup_EH; override;
         procedure Finish_EH; override;
         procedure Start_EH(AList : TAsmList); override;
         procedure End_EH(AList : TAsmList); override;

         function Find_Exception_Handling(var ANode: TNode; AData: pointer): TForEachNodeResult; virtual;
       end;

implementation

    uses
      CUtils,
      Verbose,
      Systems,
      dwarfbase,
      cfidwarf,
      Globals,
      ProcInfo,
      SymTable,
      defutil,
      tgobj,
      cgobj,cgexcept,
      parabase,paramgr,
      hlcgobj,
      pass_2
{$ifdef i386}
      ,aasmcpu
{$endif i386}
      ;


    type
       { Utility class for exception handling state management that is used
         by tryexcept/tryfinally/on nodes (in a separate class so it can both
         be shared and overridden)

         Never instantiated. }
       TPSABIEHExceptionStateHandler = class(TCGExceptionStateHandler)
       protected
         class procedure Begin_Catch_Internal(AList: TAsmList; AExceptType: TObjectDef; ANextOnLabel: TAsmLabel; AAddCatch: boolean; out AExceptLocDef: TDef; out
           AExceptLocReg: TRegister);
         class procedure Catch_All_Start_Internal(AList: TAsmList; AAddCatch: boolean);
       public
         class procedure Get_Exception_Temps(AList:TAsmList;var ATemps:TExceptionTemps); override;
         class procedure UnGet_Exception_Temps(AList:TAsmList;const ATemps:TExceptionTemps); override;
         class procedure New_Exception(AList:TAsmList;const ATemps:TExceptionTemps; const AExceptFrameKind: TExceptFrameKind; out AExceptState: TExceptionState); override;
         { start of "except/finally" block }
         class procedure Emit_Except_Label(AList: TAsmList; AExceptFrameKind: TExceptFrameKind; var AExceptionState: TExceptionState;var AExceptionTemps:TExceptionTemps); override;
         { end of a try-block, label comes after the end of try/except or
           try/finally }
         class procedure End_Try_Block(AList: TAsmList; AExceptFrameKind: TExceptFrameKind; const ATemps: TExceptionTemps; var AExceptionState: TExceptionState; AEndLabel: TAsmLabel); override;
         class procedure Free_Exception(AList: TAsmList; const ATemps: TExceptionTemps; const AState: TExceptionState; AReason: aint; AEndExceptLabel: TAsmLabel; AOnlyFree:boolean); override;
         class procedure Handle_ReRaise(AList:TAsmList;const ATemps:TExceptionTemps;const AEntryState: TExceptionState; const AExceptFrameKind: TExceptFrameKind); override;
         { start of an "on" (catch) block }
         class procedure Begin_Catch(AList: TAsmList; AExceptType: TObjectDef; ANextOnLabel: TAsmLabel; out AExceptLocDef: TDef; out AExceptLocReg: TRegister); override;
         { end of an "on" (catch) block }
         class procedure End_Catch(AList: TAsmList); override;
         { called for a catch all exception }
         class procedure Catch_All_Start(AList: TAsmList); override;
         class procedure Catch_All_End(AList: TAsmList); override;
         class procedure Catch_All_Add(AList: TAsmList); override;
         class procedure CleanupObjectStack(AList: TAsmList); override;
         class procedure PopAddrStack(AList: TAsmList); override;
       end;


    constructor TPSABIEHAction.Create(APad: TAsmLabel);
      begin
        LandingPad:=APad;
        ActionList:=TAsmList.Create;
        CurrentAsmData.getlabel(ActionTableLabel,alt_data);
        ActionList.concat(TAILabel.Create(ActionTableLabel));
        First:=true;
      end;


    destructor TPSABIEHAction.Destroy;
      begin
        if not(ActionList.Empty) then
          InternalError(2019020501);
        ActionList.Free;
        ActionList := nil;
        inherited Destroy;
      end;


    function TPSABIEHAction.AddAction(AObjectDef: TObjectDef) : LongInt;
      var
        lIndex: LongInt;
      begin
        { if not first entry, signal that another action follows }
        if not(First) then
          ActionList.concat(TAIConst.Create_sleb128bit(1));
        First:=false;

        { catch all? }
        if AObjectDef=TObjectDef(-1) then
          lIndex:=(CurrentProcInfo as TPSABIEHProcInfo).AddTypeFilter(nil)
        else if Assigned(AObjectDef) then
          lIndex:=(CurrentProcInfo as TPSABIEHProcInfo).AddTypeFilter(AObjectDef)
        else
          lIndex:=-1;
{$ifdef debug_eh}
        if AObjectDef=TObjectDef(-1) then
          ActionList.concat(TAIComment.Create(StrPNew('Catch all')))
        else if Assigned(AObjectDef) then
          ActionList.concat(TAIComment.Create(StrPNew('Action for '+AObjectDef.GetTypeName)))
        else
          ActionList.concat(TAIComment.Create(StrPNew('Cleanup')));
{$endif debug_eh}
        if Assigned(AObjectDef) then
          ActionList.concat(TAIConst.Create_sleb128bit(lIndex+1))
        else
          ActionList.concat(TAIConst.Create_sleb128bit(0));
        Result:=lIndex;
      end;

{****************************************************************************
                                 tpsabiehprocinfo
****************************************************************************}


    destructor TPSABIEHProcInfo.Destroy;
      begin
         GCCExceptTableData.free;
         GCCExceptTableData := nil;
         ActionStack.free;
         ActionStack := nil;
         LandingPadStack.free;
         LandingPadStack := nil;
         TypeFilterList.free;
         TypeFilterList := nil;
         CallSiteTableData.Free;
         CallSiteTableData := nil;
         ActionTableData.Free;
         ActionTableData := nil;
         inherited;
      end;


    procedure TPSABIEHProcInfo.PushAction(AAction: TPSABIEHAction);
      begin
        ActionStack.add(AAction);
      end;


    function TPSABIEHProcInfo.PopAction(AAction: TPSABIEHAction): boolean;
      begin
        if CurrentAction<>AAction then
          InternalError(2019022501);
        ActionStack.count:=ActionStack.count-1;
        Result:=ActionStack.count=0;
      end;


    function TPSABIEHProcInfo.FinalizeAndPopAction(AAction: TPSABIEHAction): boolean;
      var
        lCurrentPos: TAsmLabel;
      begin
        include(Flags,pi_has_except_table_data);
        if CurrentAction<>AAction then
          InternalError(2019021006);
        { no further actions follow, finalize table
          we check for >1 as the outmost landing pad has no action, so
          we can ignore it }
        if LandingPadStack.count>1 then
          begin
            CurrentAsmData.getlabel(lCurrentPos,alt_data);
            AAction.ActionList.concat(TAILabel.Create(lCurrentPos));
            AAction.ActionList.concat(TAIConst.Create_rel_sym(aitconst_sleb128bit,lCurrentPos,TPSABIEHAction(LandingPadStack[LandingPadStack.count-1]).ActionTableLabel));
          end
        else
          AAction.ActionList.concat(TAIConst.Create_sleb128bit(0));
        ActionTableData.ConcatList(AAction.ActionList);
        ActionStack.count:=ActionStack.count-1;
        Result:=ActionStack.count=0;
      end;


    procedure TPSABIEHProcInfo.PushLandingPad(AAction: TPSABIEHAction);
      begin
        LandingPadStack.add(AAction);
      end;


    function TPSABIEHProcInfo.CurrentLandingPad: TPSABIEHAction;
      begin
        Result:=TPSABIEHAction(LandingPadStack.last);
      end;


    function TPSABIEHProcInfo.PopLandingPad(AAction: TPSABIEHAction): boolean;
      begin
        if CurrentLandingPad<>AAction then
          InternalError(2019021007);
        LandingPadStack.count:=LandingPadStack.count-1;
        Result:=LandingPadStack.count=0;
      end;


    procedure TPSABIEHProcInfo.CreateNewPSABIEHCallsite(AList : TAsmList);
      var
        lCallSiteEnd : TAsmLabel;
      begin
        include(Flags,pi_has_except_table_data);
        { first, finish last entry }
        if Assigned(CallSiteLastStart) and Assigned(CurrentLandingPad) then
          begin
{$ifdef debug_eh}
            if Assigned(CurrentLandingPad.ActionTableLabel) then
              CallSiteTableData.concat(TAIComment.Create(StrPNew('Call site '+ToStr(CurrentCallSiteNumber)+', action table index = '+ToStr(LandingPadStack.count-1))))
            else
              CallSiteTableData.concat(TAIComment.Create(StrPNew('Call site '+ToStr(CurrentCallSiteNumber)+', no action')));
{$endif debug_eh}
            CallSiteTableData.concat(TAIConst.create_rel_sym(aitconst_uleb128bit,CurrentAsmData.AsmCFI.get_frame_start,CallSiteLastStart));
            CurrentAsmData.getlabel(lCallSiteEnd,alt_eh_end);
            AList.concat(TAILabel.Create(lCallSiteEnd));
            CallSiteTableData.concat(TAIConst.create_rel_sym(aitconst_uleb128bit,CallSiteLastStart,lCallSiteEnd));
            { landing pad? }
            if Assigned(CurrentLandingPad.LandingPad) then
              CallSiteTableData.concat(TAIConst.create_rel_sym(aitconst_uleb128bit,CurrentAsmData.AsmCFI.get_frame_start,CurrentLandingPad.LandingPad))
            else
              CallSiteTableData.concat(TAIConst.Create_uleb128bit(0));
            { action number set? if yes, concat }
            if Assigned(CurrentLandingPad.ActionTableLabel) then
              begin
                CallSiteTableData.concat(TAIConst.Create_rel_sym_offset(aitconst_uleb128bit,CallSiteTableEnd,CurrentLandingPad.ActionTableLabel,1));
{$ifdef debug_eh}
                AList.concat(TAIComment.Create(StrPNew('New call site '+ToStr(CurrentCallSiteNumber)+', action table index = '+ToStr(LandingPadStack.count-1))));
{$endif debug_eh}
              end
            else
              begin
                CallSiteTableData.concat(TAIConst.Create_uleb128bit(0));
{$ifdef debug_eh}
                AList.concat(TAIComment.Create(StrPNew('New call site '+ToStr(CurrentCallSiteNumber)+', no action')));
{$endif debug_eh}
              end;
            CurrentAsmData.getlabel(CallSiteLastStart,alt_eh_begin);
            AList.concat(TAILabel.Create(CallSiteLastStart));
          end
        else
          begin
            CurrentAsmData.getlabel(EntryCallSiteStart,alt_eh_begin);
            CallSiteLastStart:=EntryCallSiteStart
          end;

        Inc(CurrentCallSiteNumber);
      end;


    function TPSABIEHProcInfo.AddTypeFilter(AObjectDef: TObjectDef) : LongInt;
      var
        lIndex: Integer;
      begin
        for lIndex:=0 to TypeFilterList.count-1 do
          begin
            if TObjectDef(TypeFilterList[lIndex])=AObjectDef then
              begin
                Result:=lIndex;
                exit;
              end;
          end;
        Result:=TypeFilterList.add(AObjectDef);
      end;


    procedure TPSABIEHProcInfo.Set_EH_Info;
      begin
        inherited Set_EH_Info;
        if (tf_use_psabieh in TargetInfo.Flags) and not(pi_has_except_table_data in Flags) then
          LSDALabel:=nil
        else
          CurrentAsmData.AsmCFI.get_cfa_list.concat(TDwarfItem.create_sym(DW_Set_LSDALabel,doe_32bit,LSDALabel));
      end;


    function TPSABIEHProcInfo.CurrentAction: TPSABIEHAction; inline;
      begin
        Result:=TPSABIEHAction(ActionStack.last);
      end;


    function TPSABIEHProcInfo.Find_Exception_Handling(var ANode: TNode; AData: pointer): TForEachNodeResult;
      begin
        if ANode.nodetype in [tryfinallyn,tryexceptn,raisen,onn] then
          Result:=fen_norecurse_true
        else
          Result:=fen_false;
        end;


    procedure TPSABIEHProcInfo.Setup_EH;
      var
        lGCCExceptTable: TAISection;
      begin
        if tf_use_psabieh in TargetInfo.Flags then
          begin
            CreateExceptionTable:=ForEachNode(Code,@Find_Exception_Handling,nil);

            GCCExceptTableData:=TAsmList.Create;
            CallSiteTableData:=TAsmList.Create;
            ActionTableData:=TAsmList.Create;
            ActionStack:=TFPList.Create;
            LandingPadStack:=TFPList.Create;
            TypeFilterList:=TFPList.Create;
            lGCCExceptTable:=new_section(GCCExceptTableData,sec_gcc_except_table,'',0);
            lGCCExceptTable.secflags:=[SF_A];
            lGCCExceptTable.secprogbits:=SPB_PROGBITS;
{$ifdef debug_eh}
            GCCExceptTableData.concat(TAIComment.Create(StrPNew('gcc_except_table for '+ProcDef.FullProcName(true))));
 {$endif debug_eh}
            CurrentAsmData.getlabel(LSDALabel,alt_data);

            CurrentAsmData.getlabel(CallSiteTableStart,alt_data);
            CurrentAsmData.getlabel(CallSiteTableEnd,alt_data);

            CallSiteTableData.concat(TAILabel.Create(CallSiteTableStart));
            CExceptionStateHandler:=TPSABIEHExceptionStateHandler;

            if CreateExceptionTable then
              begin
                CreateNewPSABIEHCallsite(CurrentAsmData.CurrAsmList);

                OutmostLandingPad:=TPSABIEHAction.Create(nil);
                NoAction:=OutmostLandingPad;
                PushAction(OutmostLandingPad);
                PushLandingPad(OutmostLandingPad);
                OutmostLandingPad.AddAction(nil);
              end;
          end;
      end;


    procedure TPSABIEHProcInfo.Finish_EH;
      var
        lIndex: Integer;
      begin
        if tf_use_psabieh in TargetInfo.Flags then
          begin
            if pi_has_except_table_data in Flags then
              begin
                GCCExceptTableData.concat(TAILabel.Create(LSDALabel));
                { landing pad base is relative to procedure start, so write an omit }
                GCCExceptTableData.concat(TAIConst.create_8bit(DW_EH_PE_omit));

                if TypeFilterList.count>0 then
                  begin
{$if defined(CPU64BITADDR)}
                    GCCExceptTableData.concat(TAIConst.create_8bit(DW_EH_PE_udata8));
{$elseif defined(CPU32BITADDR)}
                    GCCExceptTableData.concat(TAIConst.create_8bit(DW_EH_PE_udata4));
{$endif}
                    CurrentAsmData.getlabel(TypeFilterListLabel,alt_data);
                    CurrentAsmData.getlabel(TypeFilterListLabelRef,alt_data);
                    GCCExceptTableData.concat(TAIConst.create_rel_sym(aitconst_uleb128bit,TypeFilterListLabel,TypeFilterListLabelRef));
                    GCCExceptTableData.concat(TAILabel.Create(TypeFilterListLabel));
                  end
                else
                  { default types table encoding }
                  GCCExceptTableData.concat(TAIConst.create_8bit(DW_EH_PE_omit));

                { call-site table encoded using uleb128 }
                GCCExceptTableData.concat(TAIConst.create_8bit(DW_EH_PE_uleb128));
                GCCExceptTableData.concat(TAIConst.create_rel_sym(aitconst_uleb128bit,CallSiteTableStart,CallSiteTableEnd));

                CallSiteTableData.concat(TAILabel.Create(CallSiteTableEnd));
{$ifdef debug_eh}
                GCCExceptTableData.concat(TAIComment.Create(StrPNew('Call site table for '+ProcDef.FullProcName(true))));
{$endif debug_eh}
                GCCExceptTableData.ConcatList(CallSiteTableData);
                { action table must follow immediately after callsite table }
{$ifdef debug_eh}
                if not(ActionTableData.Empty) then
                  GCCExceptTableData.concat(TAIComment.Create(StrPNew('Action table for '+ProcDef.FullProcName(true))));
{$endif debug_eh}
                GCCExceptTableData.ConcatList(ActionTableData);
                if TypeFilterList.count>0 then
                  begin
{$ifdef debug_eh}
                    GCCExceptTableData.concat(TAIComment.Create(StrPNew('Type filter list for '+ProcDef.FullProcName(true))));
{$endif debug_eh}
                    for lIndex:=TypeFilterList.count-1 downto 0 do
                      begin
{$ifdef debug_eh}
                        GCCExceptTableData.concat(TAIComment.Create(StrPNew('Type filter '+ToStr(lIndex))));
{$endif debug_eh}
                        if Assigned(TypeFilterList[lIndex]) then
                          GCCExceptTableData.concat(TAIConst.Create_sym(CurrentAsmData.RefAsmSymbol(TObjectDef(TypeFilterList[lIndex]).VMT_MangledName, AT_DATA)))
                        else
                          GCCExceptTableData.concat(TAIConst.Create_sym(nil));
                      end;
                    { the types are resolved by the negative offset, so the label must be written after all types }
                    GCCExceptTableData.concat(TAILabel.Create(TypeFilterListLabelRef));
                  end;

                new_section(GCCExceptTableData,sec_code,'',0);
                AktProcCode.ConcatList(GCCExceptTableData);
              end;
          end;
      end;


    procedure TPSABIEHProcInfo.Start_EH(AList: TAsmList);
      begin
        inherited Start_EH(AList);
        if CreateExceptionTable then
          AList.insert(TAILabel.Create(EntryCallSiteStart));
      end;


    procedure TPSABIEHProcInfo.End_EH(AList: TAsmList);
      begin
       inherited End_EH(AList);
       if CreateExceptionTable then
         begin
           CreateNewPSABIEHCallsite(AList);
           PopLandingPad(CurrentLandingPad);
           FinalizeAndPopAction(OutmostLandingPad);
         end;
      end;


    class procedure TPSABIEHExceptionStateHandler.Get_Exception_Temps(AList: TAsmList; var ATemps: TExceptionTemps);
      begin
        if not Assigned(ExceptionReasonType) then
          ExceptionReasonType:=OSSIntType;
        TG.GetHLTemp(AList,ExceptionReasonType,ExceptionReasonType.Size,tt_persistent,ATemps.ReasonBuf);
      end;


    class procedure TPSABIEHExceptionStateHandler.UnGet_Exception_Temps(AList: TAsmList; const ATemps: TExceptionTemps);
      begin
        TG.UnGetTemp(AList,ATemps.ReasonBuf);
        (CurrentProcInfo as TPSABIEHProcInfo).FinalizeAndPopAction((CurrentProcInfo as TPSABIEHProcInfo).CurrentAction);
      end;


    class procedure TPSABIEHExceptionStateHandler.New_Exception(AList: TAsmList; const ATemps: TExceptionTemps;
      const AExceptFrameKind: TExceptFrameKind; out AExceptState: TExceptionState);
      var
        lReg: TRegister;
        lAction: TPSABIEHAction;
      begin
        AExceptState.OldFlowControl:=flowcontrol;
        CurrentAsmData.getjumplabel(AExceptState.ExceptionLabel);
        if AExceptFrameKind<>tek_except then
          begin
            CurrentAsmData.getjumplabel(AExceptState.FinallyCodeLabel);
            lAction:=TPSABIEHAction.Create(AExceptState.FinallyCodeLabel);
          end
        else
          begin
            AExceptState.FinallyCodeLabel:=nil;
            lAction:=TPSABIEHAction.Create(AExceptState.ExceptionLabel);
          end;
        (CurrentProcInfo as TPSABIEHProcInfo).CreateNewPSABIEHCallsite(AList);
        (CurrentProcInfo as TPSABIEHProcInfo).PushAction(lAction);
        (CurrentProcInfo as TPSABIEHProcInfo).PushLandingPad(lAction);
        if AExceptFrameKind<>tek_except then
          { no safecall? }
          if Use_Cleanup(AExceptFrameKind) then
            (CurrentProcInfo as TPSABIEHProcInfo).CurrentAction.AddAction(nil)
          else
            { if safecall, catch all }
            (CurrentProcInfo as TPSABIEHProcInfo).CurrentAction.AddAction(TObjectDef(-1));

        flowcontrol:=[fc_inflowcontrol,fc_catching_exceptions];
        if AExceptFrameKind<>tek_except then
          begin
            lReg:=hlcg.GetIntRegister(AList,OSSIntType);
            hlcg.A_Load_Const_Reg(AList,OSSIntType,1,lReg);
            hlcg.G_Exception_Reason_Save(AList,OSSIntType,OSSIntType,lReg,ATemps.ReasonBuf);
          end;
      end;


    class procedure TPSABIEHExceptionStateHandler.Emit_Except_Label(AList: TAsmList; AExceptFrameKind: TExceptFrameKind;
      var AExceptionState: TExceptionState;var AExceptionTemps:TExceptionTemps);
      begin
        hlcg.G_Unreachable(AList);
        hlcg.A_Label(AList,AExceptionState.ExceptionLabel);
        if AExceptFrameKind<>tek_except then
          begin
            if not Assigned(AExceptionState.FinallyCodeLabel) then
              InternalError(2019021002);

            hlcg.A_Label(AList,AExceptionState.FinallyCodeLabel);
            AExceptionState.FinallyCodeLabel:=nil;
            AExceptionTemps.UnwindInfo:=cg.GetAddressRegister(AList);
            hlcg.A_Load_Reg_Reg(AList,VoidPointerType,VoidPointerType,NR_FUNCTION_RESULT_REG,AExceptionTemps.UnwindInfo);
          end;
      end;


    class procedure TPSABIEHExceptionStateHandler.End_Try_Block(AList: TAsmList; AExceptFrameKind: TExceptFrameKind; const ATemps: TExceptionTemps;
      var AExceptionState: TExceptionState; AEndLabel: TAsmLabel);
      var
        lReg: TRegister;
      begin
        if AExceptFrameKind<>tek_except then
          begin
            { record that no exception happened in the reason buf, in case we are in a try block of a finally statement }
            lReg:=hlcg.GetIntRegister(AList,OSSIntType);
            hlcg.A_Load_Const_Reg(AList,OSSIntType,0,lReg);
            hlcg.G_Exception_Reason_Save(AList,OSSIntType,OSSIntType,lReg,ATemps.ReasonBuf);
          end;
        inherited;
        if AExceptFrameKind=tek_except then
          hlcg.A_Jmp_Always(AList,AEndLabel);
        (CurrentProcInfo as TPSABIEHProcInfo).CreateNewPSABIEHCallsite(AList);
        (CurrentProcInfo as TPSABIEHProcInfo).PopLandingPad((CurrentProcInfo as TPSABIEHProcInfo).CurrentLandingPad);
      end;


    class procedure TPSABIEHExceptionStateHandler.Free_Exception(AList: TAsmList; const ATemps: TExceptionTemps; const AState: TExceptionState; AReason: aint;
      AEndExceptLabel: TAsmLabel; AOnlyFree: boolean);
      begin
        { nothing to do }
      end;


    class procedure TPSABIEHExceptionStateHandler.Handle_ReRaise(AList: TAsmList; const ATemps: TExceptionTemps; const AEntryState: TExceptionState;
      const AExceptFrameKind: TExceptFrameKind);
      var
        lCGPara1: TCGPara;
        lProcDef: TProcDef;
        lReRaiseLandingPad: TPSABIEHAction;
        lPSABIEHProcInfo: TPSABIEHProcInfo;
      begin
        if not(fc_catching_exceptions in flowcontrol) and
           Use_Cleanup(AExceptFrameKind) then
          begin
            { Resume might not be called outside of an landing pad else
              the unwind is immediately terminated, so create an empty landing pad }
            lPSABIEHProcInfo:=CurrentProcInfo as TPSABIEHProcInfo;

            if lPSABIEHProcInfo.LandingPadStack.count>1 then
              begin
                lPSABIEHProcInfo.CreateNewPSABIEHCallsite(AList);

                lPSABIEHProcInfo.PushAction(lPSABIEHProcInfo.NoAction);
                lPSABIEHProcInfo.PushLandingPad(lPSABIEHProcInfo.NoAction);
              end;

            lProcDef:=Search_System_Proc('_unwind_resume');
            lCGPara1.init;
            ParaManager.GetCGTempParaLoc(AList,lProcDef,1,lCGPara1);
            hlcg.A_Load_Reg_CGPara(AList,VoidPointerType,ATemps.UnwindInfo,lCGPara1);
            ParaManager.FreeCGPara(AList,lCGPara1);
            hlcg.G_Call_System_Proc(AList,'_unwind_resume',[@lCGPara1],nil).ResetIfTemp;
            { we do not have to clean up the stack, we never return }
            lCGPara1.done;

            if lPSABIEHProcInfo.LandingPadStack.count>1 then
              begin
                lPSABIEHProcInfo.CreateNewPSABIEHCallsite(AList);
                lPSABIEHProcInfo.PopLandingPad(lPSABIEHProcInfo.NoAction);
                lPSABIEHProcInfo.PopAction(lPSABIEHProcInfo.NoAction);
              end;
          end
        else
          begin
            lPSABIEHProcInfo:=CurrentProcInfo as TPSABIEHProcInfo;
            { empty landing pad needed to avoid immediate termination? }
            if lPSABIEHProcInfo.LandingPadStack.Count=0 then
              begin
                lPSABIEHProcInfo.CreateNewPSABIEHCallsite(AList);

                lReRaiseLandingPad:=lPSABIEHProcInfo.NoAction;
                lPSABIEHProcInfo.PushAction(lReRaiseLandingPad);
                lPSABIEHProcInfo.PushLandingPad(lReRaiseLandingPad);
              end
            else
              lReRaiseLandingPad:=nil;
            hlcg.G_Call_System_Proc(AList,'fpc_reraise',[],nil).ResetIfTemp;
            if Assigned(lReRaiseLandingPad) then
              begin
                lPSABIEHProcInfo.CreateNewPSABIEHCallsite(AList);
                lPSABIEHProcInfo.PopLandingPad(lPSABIEHProcInfo.CurrentLandingPad);
                lPSABIEHProcInfo.PopAction(lReRaiseLandingPad);
             end;
          end;
      end;


    class procedure TPSABIEHExceptionStateHandler.Begin_Catch_Internal(AList: TAsmList; AExceptType: TObjectDef; ANextOnLabel: TAsmLabel;
      AAddCatch: boolean; out AExceptLocDef: TDef; out AExceptLocReg: TRegister);
      var
        lCatchStartLabel : TAsmLabel;
        lBeginCatchResult,
        lParaLoc1: TCGPara;
        lProcDef: TProcDef;
        {rttisym: TAsmSymbol;
        rttidef: tdef;
        indirect: boolean;
        otherunit: boolean; }
        lWrappedException: TRegister;
        lExceptLoc: TLocation;
{$if defined(i386) or defined(x86_64)}
        lTypeIndex : aint;
{$endif}
      begin
        lParaLoc1.init;
{
        rttidef:=nil;
        rttisym:=nil;
}
        lWrappedException:=hlcg.GetAddressRegister(AList,VoidPointerType);
        hlcg.A_Load_Reg_Reg(AList,VoidPointerType,VoidPointerType,NR_FUNCTION_RESULT_REG,lWrappedException);
(*
        if add_catch then
          begin
            if assigned(excepttype) then
              begin
                otherunit:=findunitsymtable(excepttype.owner).moduleid<>findunitsymtable(current_procinfo.procdef.owner).moduleid;
                indirect:=(tf_supports_packages in target_info.flags) and
                        (target_info.system in systems_indirect_var_imports) and
                        otherunit;
                { add "catch exceptiontype" clause to the landing pad }
                rttidef:=cpointerdef.getreusable(excepttype.vmt_def);
                rttisym:=current_asmdata.RefAsmSymbol(excepttype.vmt_mangledname, AT_DATA, indirect);
              end;
          end;
*)
        { check if the exception is handled by this node }
        if Assigned(AExceptType) then
          begin
{$if defined(i386) or defined(x86_64)}
            lTypeIndex:=(CurrentProcInfo as TPSABIEHProcInfo).CurrentAction.AddAction(AExceptType);
{$endif}
            CurrentAsmData.getjumplabel(lCatchStartLabel);
{$if defined(i386)}
            hlcg.A_Cmp_Const_Reg_Label (AList,OSUIntType,OC_EQ,lTypeIndex+1,NR_FUNCTION_RESULT64_HIGH_REG,lCatchStartLabel);
{$elseif defined(x86_64)}
            hlcg.A_Cmp_Const_Reg_Label (AList,S32IntType,OC_EQ,lTypeIndex+1,NR_EDX,lCatchStartLabel);
{$else}
            { we need to find a way to fix this in a generic way }
            InternalError(2019021008);
{$endif}
            hlcg.A_Jmp_Always(AList,ANextOnLabel);
            hlcg.A_Label(AList,lCatchStartLabel);
          end
        else
          (CurrentProcInfo as TPSABIEHProcInfo).CurrentAction.AddAction(TObjectDef(-1));

        lProcDef:=Search_System_Proc('fpc_psabi_begin_catch');
        ParaManager.GetCGTempParaLoc(AList, lProcDef, 1, lParaLoc1);
        hlcg.A_Load_Reg_CGPara(AList,VoidPointerType,lWrappedException,lParaLoc1);
        lBeginCatchResult:=hlcg.G_Call_System_Proc(AList,lProcDef,[@lParaLoc1],nil);
        Location_Reset(lExceptLoc, LOC_REGISTER, Def_CGSize(lBeginCatchResult.def));
        lExceptLoc.Register:=hlcg.GetAddressRegister(AList, lBeginCatchResult.def);
        hlcg.Gen_Load_CGPara_Loc(AList, lBeginCatchResult.def, lBeginCatchResult, lExceptLoc, true);

        lBeginCatchResult.ResetIfTemp;
        lParaLoc1.done;

        AExceptLocDef:=lBeginCatchResult.def;
        AExceptLocReg:=lExceptLoc.Register;
      end;


    class procedure TPSABIEHExceptionStateHandler.Catch_All_Start_Internal(AList: TAsmList; AAddCatch: boolean);
      var
        lExceptLocDef: TDef;
        lExceptLocReg: TRegister;
      begin
        Begin_Catch_Internal(AList,nil,nil,AAddCatch,lExceptLocDef,lExceptLocReg);
      end;


    class procedure TPSABIEHExceptionStateHandler.Begin_Catch(AList: TAsmList; AExceptType: TObjectDef; ANextOnLabel: TAsmLabel; out AExceptLocDef: TDef; out
      AExceptLocReg: TRegister);
      begin
        Begin_Catch_Internal(AList,AExceptType,ANextOnLabel,true,AExceptLocDef,AExceptLocReg);
      end;


    class procedure TPSABIEHExceptionStateHandler.End_Catch(AList: TAsmList);
      begin
        hlcg.G_Call_System_Proc(AList,'fpc_psabi_end_catch',[],nil).ResetIfTemp;
        inherited;
      end;


    class procedure TPSABIEHExceptionStateHandler.Catch_All_Start(AList: TAsmList);
      begin
        Catch_All_Start_Internal(AList,true);
      end;


    class procedure TPSABIEHExceptionStateHandler.Catch_All_Add(AList: TAsmList);
      begin
        (CurrentProcInfo as TPSABIEHProcInfo).CurrentAction.AddAction(nil);
      end;


    class procedure TPSABIEHExceptionStateHandler.Catch_All_End(AList: TAsmList);
      begin
        hlcg.G_Call_System_Proc(AList,'fpc_psabi_end_catch',[],nil).ResetIfTemp;
      end;


    class procedure TPSABIEHExceptionStateHandler.CleanupObjectStack(AList: TAsmList);
      begin
        { there is nothing to do }
      end;


    class procedure TPSABIEHExceptionStateHandler.PopAddrStack(AList: TAsmList);
      begin
        { there is no addr stack, so do nothing }
      end;

end.
