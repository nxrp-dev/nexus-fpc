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
         landingpad : TAsmLabel;
         actiontablelabel : TAsmLabel;
         actionlist : TAsmList;
         first : boolean;
         constructor Create(pad : TAsmLabel);
         destructor Destroy; override;
         function AddAction(p: TObjectDef): LongInt;
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
         callsite_table_data,
         action_table_data,
         gcc_except_table_data : TAsmList;
         typefilterlistlabel,typefilterlistlabelref,
         callsitetablestart,callsitetableend,
         { first label which must be inserted into the entry code }
         entrycallsitestart,
         callsitelaststart : TAsmLabel;
         typefilterlist,
         landingpadstack,
         actionstack : TFPList;
         CurrentCallSiteNumber : LongInt;

         destructor Destroy; override;

         { PSABIEH stuff }
         procedure PushAction(action: TPSABIEHAction);
         function CurrentAction: TPSABIEHAction;inline;
         function PopAction(action: TPSABIEHAction): boolean;
         function FinalizeAndPopAction(action: TPSABIEHAction): boolean;
         { a landing pad is also an action, however, when the landing pad is popped from the stack
           the area covered by this landing pad ends, i.e. it is popped at the beginning of the finally/except clause,
           the action above is popped at the end of the finally/except clause, so if on clauses add new types, they
           are added to CurrentAction }
         procedure PushLandingPad(action: TPSABIEHAction);
         function CurrentLandingPad: TPSABIEHAction;inline;
         function PopLandingPad(action: TPSABIEHAction): boolean;
         procedure CreateNewPSABIEHCallsite(list: TAsmList);
         { adds a new type to the type filter list and returns its index
           be aware, that this method can also handle catch all filters so it
           is valid to pass nil }
         function AddTypeFilter(p: TObjectDef): LongInt;
         procedure set_eh_info; override;
         procedure setup_eh; override;
         procedure finish_eh; override;
         procedure start_eh(list : TAsmList); override;
         procedure end_eh(list : TAsmList); override;

         function find_exception_handling(var n: TNode; para: pointer): TForEachNodeResult; virtual;
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
         class procedure begin_catch_internal(list: TAsmList; excepttype: TObjectDef; nextonlabel: TAsmLabel; add_catch: boolean; out exceptlocdef: TDef; out
           exceptlocreg: TRegister);
         class procedure catch_all_start_internal(list: TAsmList; add_catch: boolean);
       public
         class procedure get_exception_temps(list:TAsmList;var t:TExceptionTemps); override;
         class procedure unget_exception_temps(list:TAsmList;const t:TExceptionTemps); override;
         class procedure new_exception(list:TAsmList;const t:TExceptionTemps; const exceptframekind: TExceptFrameKind; out exceptstate: TExceptionState); override;
         { start of "except/finally" block }
         class procedure emit_except_label(list: TAsmList; exceptframekind: TExceptFrameKind; var exceptionstate: TExceptionState;var exceptiontemps:TExceptionTemps); override;
         { end of a try-block, label comes after the end of try/except or
           try/finally }
         class procedure end_try_block(list: TAsmList; exceptframekind: TExceptFrameKind; const t: TExceptionTemps; var exceptionstate: TExceptionState; endlabel: TAsmLabel); override;
         class procedure free_exception(list: TAsmList; const t: TExceptionTemps; const s: TExceptionState; a: aint; endexceptlabel: TAsmLabel; onlyfree:boolean); override;
         class procedure handle_reraise(list:TAsmList;const t:TExceptionTemps;const entrystate: TExceptionState; const exceptframekind: TExceptFrameKind); override;
         { start of an "on" (catch) block }
         class procedure begin_catch(list: TAsmList; excepttype: TObjectDef; nextonlabel: TAsmLabel; out exceptlocdef: TDef; out exceptlocreg: TRegister); override;
         { end of an "on" (catch) block }
         class procedure end_catch(list: TAsmList); override;
         { called for a catch all exception }
         class procedure catch_all_start(list: TAsmList); override;
         class procedure catch_all_end(list: TAsmList); override;
         class procedure catch_all_add(list: TAsmList); override;
         class procedure cleanupobjectstack(list: TAsmList); override;
         class procedure popaddrstack(list: TAsmList); override;
       end;


    constructor TPSABIEHAction.Create(pad: TAsmLabel);
      begin
        landingpad:=pad;
        actionlist:=TAsmList.create;
        CurrentAsmData.getlabel(actiontablelabel,alt_data);
        actionlist.concat(TAILabel.create(actiontablelabel));
        first:=true;
      end;


    destructor TPSABIEHAction.Destroy;
      begin
        if not(actionlist.Empty) then
          InternalError(2019020501);
        actionlist.Free;
        actionlist := nil;
        inherited Destroy;
      end;


    function TPSABIEHAction.AddAction(p: TObjectDef) : LongInt;
      var
        index: LongInt;
      begin
        { if not first entry, signal that another action follows }
        if not(first) then
          actionlist.concat(TAIConst.Create_sleb128bit(1));
        first:=false;

        { catch all? }
        if p=TObjectDef(-1) then
          index:=(CurrentProcInfo as TPSABIEHProcInfo).AddTypeFilter(nil)
        else if Assigned(p) then
          index:=(CurrentProcInfo as TPSABIEHProcInfo).AddTypeFilter(p)
        else
          index:=-1;
{$ifdef debug_eh}
        if p=TObjectDef(-1) then
          actionlist.concat(TAIComment.Create(StrPNew('Catch all')))
        else if Assigned(p) then
          actionlist.concat(TAIComment.Create(StrPNew('Action for '+p.GetTypeName)))
        else
          actionlist.concat(TAIComment.Create(StrPNew('Cleanup')));
{$endif debug_eh}
        if Assigned(p) then
          actionlist.concat(TAIConst.Create_sleb128bit(index+1))
        else
          actionlist.concat(TAIConst.Create_sleb128bit(0));
        Result:=index;
      end;

{****************************************************************************
                                 tpsabiehprocinfo
****************************************************************************}


    destructor TPSABIEHProcInfo.Destroy;
      begin
         gcc_except_table_data.free;
         gcc_except_table_data := nil;
         actionstack.free;
         actionstack := nil;
         landingpadstack.free;
         landingpadstack := nil;
         typefilterlist.free;
         typefilterlist := nil;
         callsite_table_data.Free;
         callsite_table_data := nil;
         action_table_data.Free;
         action_table_data := nil;
         inherited;
      end;


    procedure TPSABIEHProcInfo.PushAction(action: TPSABIEHAction);
      begin
        actionstack.add(action);
      end;


    function TPSABIEHProcInfo.PopAction(action: TPSABIEHAction): boolean;
      begin
        if CurrentAction<>action then
          InternalError(2019022501);
        actionstack.count:=actionstack.count-1;
        result:=actionstack.count=0;
      end;


    function TPSABIEHProcInfo.FinalizeAndPopAction(action: TPSABIEHAction): boolean;
      var
        curpos: TAsmLabel;
      begin
        include(flags,pi_has_except_table_data);
        if CurrentAction<>action then
          InternalError(2019021006);
        { no further actions follow, finalize table
          we check for >1 as the outmost landing pad has no action, so
          we can ignore it }
        if landingpadstack.count>1 then
          begin
            CurrentAsmData.getlabel(curpos,alt_data);
            action.actionlist.concat(TAILabel.create(curpos));
            action.actionlist.concat(TAIConst.Create_rel_sym(aitconst_sleb128bit,curpos,TPSABIEHAction(landingpadstack[landingpadstack.count-1]).actiontablelabel));
          end
        else
          action.actionlist.concat(TAIConst.Create_sleb128bit(0));
        action_table_data.ConcatList(action.actionlist);
        actionstack.count:=actionstack.count-1;
        result:=actionstack.count=0;
      end;


    procedure TPSABIEHProcInfo.PushLandingPad(action: TPSABIEHAction);
      begin
        landingpadstack.add(action);
      end;


    function TPSABIEHProcInfo.CurrentLandingPad: TPSABIEHAction;
      begin
        result:=TPSABIEHAction(landingpadstack.last);
      end;


    function TPSABIEHProcInfo.PopLandingPad(action: TPSABIEHAction): boolean;
      begin
        if CurrentLandingPad<>action then
          InternalError(2019021007);
        landingpadstack.count:=landingpadstack.count-1;
        result:=landingpadstack.count=0;
      end;


    procedure TPSABIEHProcInfo.CreateNewPSABIEHCallsite(list : TAsmList);
      var
        callsiteend : TAsmLabel;
      begin
        include(flags,pi_has_except_table_data);
        { first, finish last entry }
        if Assigned(callsitelaststart) and Assigned(CurrentLandingPad) then
          begin
{$ifdef debug_eh}
            if Assigned(CurrentLandingPad.actiontablelabel) then
              callsite_table_data.concat(TAIComment.Create(StrPNew('Call site '+ToStr(CurrentCallSiteNumber)+', action table index = '+ToStr(landingpadstack.count-1))))
            else
              callsite_table_data.concat(TAIComment.Create(StrPNew('Call site '+ToStr(CurrentCallSiteNumber)+', no action')));
{$endif debug_eh}
            callsite_table_data.concat(TAIConst.create_rel_sym(aitconst_uleb128bit,CurrentAsmData.AsmCFI.get_frame_start,callsitelaststart));
            CurrentAsmData.getlabel(callsiteend,alt_eh_end);
            list.concat(TAILabel.create(callsiteend));
            callsite_table_data.concat(TAIConst.create_rel_sym(aitconst_uleb128bit,callsitelaststart,callsiteend));
            { landing pad? }
            if Assigned(CurrentLandingPad.landingpad) then
              callsite_table_data.concat(TAIConst.create_rel_sym(aitconst_uleb128bit,CurrentAsmData.AsmCFI.get_frame_start,CurrentLandingPad.landingpad))
            else
              callsite_table_data.concat(TAIConst.Create_uleb128bit(0));
            { action number set? if yes, concat }
            if Assigned(CurrentLandingPad.actiontablelabel) then
              begin
                callsite_table_data.concat(TAIConst.Create_rel_sym_offset(aitconst_uleb128bit,callsitetableend,CurrentLandingPad.actiontablelabel,1));
{$ifdef debug_eh}
                list.concat(TAIComment.Create(StrPNew('New call site '+ToStr(CurrentCallSiteNumber)+', action table index = '+ToStr(landingpadstack.count-1))));
{$endif debug_eh}
              end
            else
              begin
                callsite_table_data.concat(TAIConst.Create_uleb128bit(0));
{$ifdef debug_eh}
                list.concat(TAIComment.Create(StrPNew('New call site '+ToStr(CurrentCallSiteNumber)+', no action')));
{$endif debug_eh}
              end;
            CurrentAsmData.getlabel(callsitelaststart,alt_eh_begin);
            list.concat(TAILabel.create(callsitelaststart));
          end
        else
          begin
            CurrentAsmData.getlabel(entrycallsitestart,alt_eh_begin);
            callsitelaststart:=entrycallsitestart
          end;

        Inc(CurrentCallSiteNumber);
      end;


    function TPSABIEHProcInfo.AddTypeFilter(p: TObjectDef) : LongInt;
      var
        i: Integer;
      begin
        for i:=0 to typefilterlist.count-1 do
          begin
            if TObjectDef(typefilterlist[i])=p then
              begin
                result:=i;
                exit;
              end;
          end;
        result:=typefilterlist.add(p);
      end;


    procedure TPSABIEHProcInfo.set_eh_info;
      begin
        inherited set_eh_info;
        if (tf_use_psabieh in TargetInfo.flags) and not(pi_has_except_table_data in flags) then
          LSDALabel:=nil
        else
          CurrentAsmData.AsmCFI.get_cfa_list.concat(TDwarfItem.create_sym(DW_Set_LSDALabel,doe_32bit,LSDALabel));
      end;


    function TPSABIEHProcInfo.CurrentAction: TPSABIEHAction; inline;
      begin
        result:=TPSABIEHAction(actionstack.last);
      end;


    function TPSABIEHProcInfo.find_exception_handling(var n: TNode; para: pointer): TForEachNodeResult;
      begin
        if n.nodetype in [tryfinallyn,tryexceptn,raisen,onn] then
          Result:=fen_norecurse_true
        else
          Result:=fen_false;
        end;


    procedure TPSABIEHProcInfo.setup_eh;
      var
        gcc_except_table: TAISection;
      begin
        if tf_use_psabieh in TargetInfo.flags then
          begin
            CreateExceptionTable:=foreachnode(code,@find_exception_handling,nil);

            gcc_except_table_data:=TAsmList.Create;
            callsite_table_data:=TAsmList.Create;
            action_table_data:=TAsmList.Create;
            actionstack:=TFPList.Create;
            landingpadstack:=TFPList.Create;
            typefilterlist:=TFPList.Create;
            gcc_except_table:=new_section(gcc_except_table_data,sec_gcc_except_table,'',0);
            gcc_except_table.secflags:=[SF_A];
            gcc_except_table.secprogbits:=SPB_PROGBITS;
{$ifdef debug_eh}
            gcc_except_table_data.concat(TAIComment.Create(StrPNew('gcc_except_table for '+procdef.FullProcName(true))));
 {$endif debug_eh}
            CurrentAsmData.getlabel(LSDALabel,alt_data);

            CurrentAsmData.getlabel(callsitetablestart,alt_data);
            CurrentAsmData.getlabel(callsitetableend,alt_data);

            callsite_table_data.concat(TAILabel.create(callsitetablestart));
            cexceptionstatehandler:=TPSABIEHExceptionStateHandler;

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


    procedure TPSABIEHProcInfo.finish_eh;
      var
        i: Integer;
      begin
        if tf_use_psabieh in TargetInfo.flags then
          begin
            if pi_has_except_table_data in flags then
              begin
                gcc_except_table_data.concat(TAILabel.create(LSDALabel));
                { landing pad base is relative to procedure start, so write an omit }
                gcc_except_table_data.concat(TAIConst.create_8bit(DW_EH_PE_omit));

                if typefilterlist.count>0 then
                  begin
{$if defined(CPU64BITADDR)}
                    gcc_except_table_data.concat(TAIConst.create_8bit(DW_EH_PE_udata8));
{$elseif defined(CPU32BITADDR)}
                    gcc_except_table_data.concat(TAIConst.create_8bit(DW_EH_PE_udata4));
{$endif}
                    CurrentAsmData.getlabel(typefilterlistlabel,alt_data);
                    CurrentAsmData.getlabel(typefilterlistlabelref,alt_data);
                    gcc_except_table_data.concat(TAIConst.create_rel_sym(aitconst_uleb128bit,typefilterlistlabel,typefilterlistlabelref));
                    gcc_except_table_data.concat(TAILabel.create(typefilterlistlabel));
                  end
                else
                  { default types table encoding }
                  gcc_except_table_data.concat(TAIConst.create_8bit(DW_EH_PE_omit));

                { call-site table encoded using uleb128 }
                gcc_except_table_data.concat(TAIConst.create_8bit(DW_EH_PE_uleb128));
                gcc_except_table_data.concat(TAIConst.create_rel_sym(aitconst_uleb128bit,callsitetablestart,callsitetableend));

                callsite_table_data.concat(TAILabel.create(callsitetableend));
{$ifdef debug_eh}
                gcc_except_table_data.concat(TAIComment.Create(StrPNew('Call site table for '+procdef.FullProcName(true))));
{$endif debug_eh}
                gcc_except_table_data.ConcatList(callsite_table_data);
                { action table must follow immediately after callsite table }
{$ifdef debug_eh}
                if not(action_table_data.Empty) then
                  gcc_except_table_data.concat(TAIComment.Create(StrPNew('Action table for '+procdef.FullProcName(true))));
{$endif debug_eh}
                gcc_except_table_data.ConcatList(action_table_data);
                if typefilterlist.count>0 then
                  begin
{$ifdef debug_eh}
                    gcc_except_table_data.concat(TAIComment.Create(StrPNew('Type filter list for '+procdef.FullProcName(true))));
{$endif debug_eh}
                    for i:=typefilterlist.count-1 downto 0 do
                      begin
{$ifdef debug_eh}
                        gcc_except_table_data.concat(TAIComment.Create(StrPNew('Type filter '+ToStr(i))));
{$endif debug_eh}
                        if Assigned(typefilterlist[i]) then
                          gcc_except_table_data.concat(TAIConst.Create_sym(CurrentAsmData.RefAsmSymbol(TObjectDef(typefilterlist[i]).VMT_MangledName, AT_DATA)))
                        else
                          gcc_except_table_data.concat(TAIConst.Create_sym(nil));
                      end;
                    { the types are resolved by the negative offset, so the label must be written after all types }
                    gcc_except_table_data.concat(TAILabel.create(typefilterlistlabelref));
                  end;

                new_section(gcc_except_table_data,sec_code,'',0);
                aktproccode.ConcatList(gcc_except_table_data);
              end;
          end;
      end;


    procedure TPSABIEHProcInfo.start_eh(list: TAsmList);
      begin
        inherited start_eh(list);
        if CreateExceptionTable then
          list.insert(TAILabel.create(entrycallsitestart));
      end;


    procedure TPSABIEHProcInfo.end_eh(list: TAsmList);
      begin
       inherited end_eh(list);
       if CreateExceptionTable then
         begin
           CreateNewPSABIEHCallsite(list);
           PopLandingPad(CurrentLandingPad);
           FinalizeAndPopAction(OutmostLandingPad);
         end;
      end;


    class procedure TPSABIEHExceptionStateHandler.get_exception_temps(list: TAsmList; var t: TExceptionTemps);
      begin
        if not Assigned(ExceptionReasonType) then
          ExceptionReasonType:=OSSIntType;
        tg.GetHLTemp(list,ExceptionReasonType,ExceptionReasonType.Size,tt_persistent,t.reasonbuf);
      end;


    class procedure TPSABIEHExceptionStateHandler.unget_exception_temps(list: TAsmList; const t: TExceptionTemps);
      begin
        tg.ungettemp(list,t.reasonbuf);
        (CurrentProcInfo as TPSABIEHProcInfo).FinalizeAndPopAction((CurrentProcInfo as TPSABIEHProcInfo).CurrentAction);
      end;


    class procedure TPSABIEHExceptionStateHandler.new_exception(list: TAsmList; const t: TExceptionTemps;
      const exceptframekind: TExceptFrameKind; out exceptstate: TExceptionState);
      var
        reg: TRegister;
        action: TPSABIEHAction;
      begin
        exceptstate.oldflowcontrol:=flowcontrol;
        CurrentAsmData.getjumplabel(exceptstate.exceptionlabel);
        if exceptframekind<>tek_except then
          begin
            CurrentAsmData.getjumplabel(exceptstate.finallycodelabel);
            action:=TPSABIEHAction.Create(exceptstate.finallycodelabel);
          end
        else
          begin
            exceptstate.finallycodelabel:=nil;
            action:=TPSABIEHAction.Create(exceptstate.exceptionlabel);
          end;
        (CurrentProcInfo as TPSABIEHProcInfo).CreateNewPSABIEHCallsite(list);
        (CurrentProcInfo as TPSABIEHProcInfo).PushAction(action);
        (CurrentProcInfo as TPSABIEHProcInfo).PushLandingPad(action);
        if exceptframekind<>tek_except then
          { no safecall? }
          if use_cleanup(exceptframekind) then
            (CurrentProcInfo as TPSABIEHProcInfo).CurrentAction.AddAction(nil)
          else
            { if safecall, catch all }
            (CurrentProcInfo as TPSABIEHProcInfo).CurrentAction.AddAction(TObjectDef(-1));

        flowcontrol:=[fc_inflowcontrol,fc_catching_exceptions];
        if exceptframekind<>tek_except then
          begin
            reg:=hlcg.GetIntRegister(list,OSSIntType);
            hlcg.A_Load_Const_Reg(list,OSSIntType,1,reg);
            hlcg.G_Exception_Reason_Save(list,OSSIntType,OSSIntType,reg,t.reasonbuf);
          end;
      end;


    class procedure TPSABIEHExceptionStateHandler.emit_except_label(list: TAsmList; exceptframekind: TExceptFrameKind;
      var exceptionstate: TExceptionState;var exceptiontemps:TExceptionTemps);
      begin
        hlcg.G_Unreachable(list);
        hlcg.A_Label(list,exceptionstate.exceptionlabel);
        if exceptframekind<>tek_except then
          begin
            if not Assigned(exceptionstate.finallycodelabel) then
              InternalError(2019021002);

            hlcg.A_Label(list,exceptionstate.finallycodelabel);
            exceptionstate.finallycodelabel:=nil;
            exceptiontemps.unwind_info:=cg.GetAddressRegister(list);
            hlcg.A_Load_Reg_Reg(list,VoidPointerType,VoidPointerType,NR_FUNCTION_RESULT_REG,exceptiontemps.unwind_info);
          end;
      end;


    class procedure TPSABIEHExceptionStateHandler.end_try_block(list: TAsmList; exceptframekind: TExceptFrameKind; const t: TExceptionTemps;
      var exceptionstate: TExceptionState; endlabel: TAsmLabel);
      var
        reg: TRegister;
      begin
        if exceptframekind<>tek_except then
          begin
            { record that no exception happened in the reason buf, in case we are in a try block of a finally statement }
            reg:=hlcg.GetIntRegister(list,OSSIntType);
            hlcg.A_Load_Const_Reg(list,OSSIntType,0,reg);
            hlcg.G_Exception_Reason_Save(list,OSSIntType,OSSIntType,reg,t.reasonbuf);
          end;
        inherited;
        if exceptframekind=tek_except then
          hlcg.A_Jmp_Always(list,endlabel);
        (CurrentProcInfo as TPSABIEHProcInfo).CreateNewPSABIEHCallsite(list);
        (CurrentProcInfo as TPSABIEHProcInfo).PopLandingPad((CurrentProcInfo as TPSABIEHProcInfo).CurrentLandingPad);
      end;


    class procedure TPSABIEHExceptionStateHandler.free_exception(list: TAsmList; const t: TExceptionTemps; const s: TExceptionState; a: aint;
      endexceptlabel: TAsmLabel; onlyfree: boolean);
      begin
        { nothing to do }
      end;


    class procedure TPSABIEHExceptionStateHandler.handle_reraise(list: TAsmList; const t: TExceptionTemps; const entrystate: TExceptionState;
      const exceptframekind: TExceptFrameKind);
      var
        cgpara1: TCGPara;
        pd: TProcDef;
        ReRaiseLandingPad: TPSABIEHAction;
        psabiehprocinfo: TPSABIEHProcInfo;
      begin
        if not(fc_catching_exceptions in flowcontrol) and
           use_cleanup(exceptframekind) then
          begin
            { Resume might not be called outside of an landing pad else
              the unwind is immediately terminated, so create an empty landing pad }
            psabiehprocinfo:=CurrentProcInfo as TPSABIEHProcInfo;

            if psabiehprocinfo.landingpadstack.count>1 then
              begin
                psabiehprocinfo.CreateNewPSABIEHCallsite(list);

                psabiehprocinfo.PushAction(psabiehprocinfo.NoAction);
                psabiehprocinfo.PushLandingPad(psabiehprocinfo.NoAction);
              end;

            pd:=Search_System_Proc('_unwind_resume');
            cgpara1.init;
            ParaManager.GetCGTempParaLoc(list,pd,1,cgpara1);
            hlcg.A_Load_Reg_CGPara(list,VoidPointerType,t.unwind_info,cgpara1);
            ParaManager.FreeCGPara(list,cgpara1);
            hlcg.G_Call_System_Proc(list,'_unwind_resume',[@cgpara1],nil).ResetIfTemp;
            { we do not have to clean up the stack, we never return }
            cgpara1.done;

            if psabiehprocinfo.landingpadstack.count>1 then
              begin
                psabiehprocinfo.CreateNewPSABIEHCallsite(list);
                psabiehprocinfo.PopLandingPad(psabiehprocinfo.NoAction);
                psabiehprocinfo.PopAction(psabiehprocinfo.NoAction);
              end;
          end
        else
          begin
            psabiehprocinfo:=CurrentProcInfo as TPSABIEHProcInfo;
            { empty landing pad needed to avoid immediate termination? }
            if psabiehprocinfo.landingpadstack.Count=0 then
              begin
                psabiehprocinfo.CreateNewPSABIEHCallsite(list);

                ReRaiseLandingPad:=psabiehprocinfo.NoAction;
                psabiehprocinfo.PushAction(ReRaiseLandingPad);
                psabiehprocinfo.PushLandingPad(ReRaiseLandingPad);
              end
            else
              ReRaiseLandingPad:=nil;
            hlcg.G_Call_System_Proc(list,'fpc_reraise',[],nil).ResetIfTemp;
            if Assigned(ReRaiseLandingPad) then
              begin
                psabiehprocinfo.CreateNewPSABIEHCallsite(list);
                psabiehprocinfo.PopLandingPad(psabiehprocinfo.CurrentLandingPad);
                psabiehprocinfo.PopAction(ReRaiseLandingPad);
             end;
          end;
      end;


    class procedure TPSABIEHExceptionStateHandler.begin_catch_internal(list: TAsmList; excepttype: TObjectDef; nextonlabel: TAsmLabel;
      add_catch: boolean; out exceptlocdef: TDef; out exceptlocreg: TRegister);
      var
        catchstartlab : TAsmLabel;
        begincatchres,
        paraloc1: TCGPara;
        pd: TProcDef;
        {rttisym: TAsmSymbol;
        rttidef: tdef;
        indirect: boolean;
        otherunit: boolean; }
        wrappedexception: TRegister;
        exceptloc: TLocation;
{$if defined(i386) or defined(x86_64)}
        typeindex : aint;
{$endif}
      begin
        paraloc1.init;
{
        rttidef:=nil;
        rttisym:=nil;
}
        wrappedexception:=hlcg.GetAddressRegister(list,VoidPointerType);
        hlcg.A_Load_Reg_Reg(list,VoidPointerType,VoidPointerType,NR_FUNCTION_RESULT_REG,wrappedexception);
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
        if Assigned(excepttype) then
          begin
{$if defined(i386) or defined(x86_64)}
            typeindex:=(CurrentProcInfo as TPSABIEHProcInfo).CurrentAction.AddAction(excepttype);
{$endif}
            CurrentAsmData.getjumplabel(catchstartlab);
{$if defined(i386)}
            hlcg.A_Cmp_Const_Reg_Label (list,OSUIntType,OC_EQ,typeindex+1,NR_FUNCTION_RESULT64_HIGH_REG,catchstartlab);
{$elseif defined(x86_64)}
            hlcg.A_Cmp_Const_Reg_Label (list,S32IntType,OC_EQ,typeindex+1,NR_EDX,catchstartlab);
{$else}
            { we need to find a way to fix this in a generic way }
            InternalError(2019021008);
{$endif}
            hlcg.A_Jmp_Always(list,nextonlabel);
            hlcg.A_Label(list,catchstartlab);
          end
        else
          (CurrentProcInfo as TPSABIEHProcInfo).CurrentAction.AddAction(TObjectDef(-1));

        pd:=Search_System_Proc('fpc_psabi_begin_catch');
        ParaManager.GetCGTempParaLoc(list, pd, 1, paraloc1);
        hlcg.A_Load_Reg_CGPara(list,VoidPointerType,wrappedexception,paraloc1);
        begincatchres:=hlcg.G_Call_System_Proc(list,pd,[@paraloc1],nil);
        Location_Reset(exceptloc, LOC_REGISTER, Def_CGSize(begincatchres.def));
        exceptloc.Register:=hlcg.GetAddressRegister(list, begincatchres.def);
        hlcg.Gen_Load_CGPara_Loc(list, begincatchres.def, begincatchres, exceptloc, true);

        begincatchres.ResetIfTemp;
        paraloc1.done;

        exceptlocdef:=begincatchres.def;
        exceptlocreg:=exceptloc.Register;
      end;


    class procedure TPSABIEHExceptionStateHandler.catch_all_start_internal(list: TAsmList; add_catch: boolean);
      var
        exceptlocdef: TDef;
        exceptlocreg: TRegister;
      begin
        begin_catch_internal(list,nil,nil,add_catch,exceptlocdef,exceptlocreg);
      end;


    class procedure TPSABIEHExceptionStateHandler.begin_catch(list: TAsmList; excepttype: TObjectDef; nextonlabel: TAsmLabel; out exceptlocdef: TDef; out
      exceptlocreg: TRegister);
      begin
        begin_catch_internal(list,excepttype,nextonlabel,true,exceptlocdef,exceptlocreg);
      end;


    class procedure TPSABIEHExceptionStateHandler.end_catch(list: TAsmList);
      begin
        hlcg.G_Call_System_Proc(list,'fpc_psabi_end_catch',[],nil).ResetIfTemp;
        inherited;
      end;


    class procedure TPSABIEHExceptionStateHandler.catch_all_start(list: TAsmList);
      begin
        catch_all_start_internal(list,true);
      end;


    class procedure TPSABIEHExceptionStateHandler.catch_all_add(list: TAsmList);
      begin
        (CurrentProcInfo as TPSABIEHProcInfo).CurrentAction.AddAction(nil);
      end;


    class procedure TPSABIEHExceptionStateHandler.catch_all_end(list: TAsmList);
      begin
        hlcg.G_Call_System_Proc(list,'fpc_psabi_end_catch',[],nil).ResetIfTemp;
      end;


    class procedure TPSABIEHExceptionStateHandler.cleanupobjectstack(list: TAsmList);
      begin
        { there is nothing to do }
      end;


    class procedure TPSABIEHExceptionStateHandler.popaddrstack(list: TAsmList);
      begin
        { there is no addr stack, so do nothing }
      end;

end.
