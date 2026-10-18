{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate assembler for nodes that influence the flow which are
    the same for all (most?) processors

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
unit ncgflw;

{$i fpcdefs.inc}



interface

    uses
      GlobType,
      symtype,symdef,
      aasmbase,AAsmData,
      node,nflw,
      pass_2,cgbase,cgutils,ncgutil,cgexcept;

    type
       TCGWhileRepeatNode = class(TWhileRepeatNode)
          UsedRegVars: TUsedRegVars;

          procedure Pass_Generate_Code;override;
          procedure Sync_RegVars(ACheckUsedRegVars: boolean);
       end;

       TCGIfNode = class(TIfNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGForNode = class(TForNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGExitNode = class(TExitNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGBreakNode = class(TBreakNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGContinueNode = class(TContinueNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGGotoNode = class(TGotoNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGLabelNode = class(TLabelNode)
       protected
          FAsmLabel : TAsmLabel;
       public
          function GetAsmLabel : TAsmLabel; virtual;
          procedure Pass_Generate_Code;override;
       end;

       TCGRaiseNode = class(TRaiseNode)
         function Pass_1: TNode;override;
{$ifndef SkipABIEH}
         procedure Pass_Generate_Code;override;
{$endif SkipABIEH}
       end;

       TCGTryExceptNode = class(TTryExceptNode)
        protected
          type
            TFrameType = (ft_try,ft_except);

          procedure Emit_Jump_Out_Of_Try_Except_Frame(AList: TAsmList; AFrameType: TFrameType; const AExceptionState: TCGExceptionStateHandler.TExceptionState; var AExceptTemps: TCGExceptionStateHandler.TExceptionTemps; AFrameLabel, AOuterLabel: TAsmLabel); virtual;
        public
          procedure Pass_Generate_Code;override;
       end;

       TCGTryFinallyNode = class(TTryFinallyNode)
        protected
          procedure Emit_Jump_Out_Of_Try_Finally_Frame(AList: TAsmList; const AReason: byte; const AFinallyCodeLabel: TAsmLabel; var AExceptTemps: TCGExceptionStateHandler.TExceptionTemps; AFrameLabel: TAsmLabel);
          function Get_Jump_Out_Of_Try_Finally_Frame_Label(const AFinallyExceptionState: TCGExceptionStateHandler.TExceptionState): TAsmLabel;
        public
          procedure Handle_SafeCall_Exception;
          procedure Pass_Generate_Code;override;
       end;

       TCGOnNode = class(TOnNode)
          procedure Pass_Generate_Code;override;
       end;


implementation

    uses
      CUtils,
      Verbose,Globals,Systems,
      symconst,SymSym,SymTable,aasmtai,aasmcpu,defutil,
      ProcInfo,parabase,
      FModule,
      cpubase,
      tgobj,paramgr,
      cgobj,hlcgobj,nutils
{$ifndef SkipABIEH}
      ,psabiehpi
{$endif}
      ;
{*****************************************************************************
                         Second_While_RepeatN
*****************************************************************************}

    procedure TCGWhileRepeatNode.Sync_RegVars(ACheckUsedRegVars: boolean);
      begin
         if (cs_opt_regvar in CurrentSettings.OptimizerSwitches) and
            not(pi_has_label in CurrentProcInfo.Flags) then
           begin
             if ACheckUsedRegVars then
               begin
                 UsedRegVars.IntRegVars.init;
                 UsedRegVars.AddrRegVars.init;
                 UsedRegVars.FPURegVars.init;
                 UsedRegVars.MMRegVars.init;

                 { we have to synchronise both the regvars used in the loop }
                 { and the ones in the while/until condition                }
                 Get_Used_RegVars(self,UsedRegVars);
                 Gen_Sync_RegVars(CurrentAsmData.CurrAsmList,UsedRegVars);
               end
             else
               begin
                 Gen_Sync_RegVars(CurrentAsmData.CurrAsmList,UsedRegVars);
                 UsedRegVars.IntRegVars.done;
                 UsedRegVars.AddrRegVars.done;
                 UsedRegVars.FPURegVars.done;
                 UsedRegVars.MMRegVars.done;
               end;
           end;
      end;


    procedure TCGWhileRepeatNode.Pass_Generate_Code;
      var
         lContinueLabel,lBreakLabel,lLoopLabel,
         lOldContinueLabel,lOldBreakLabel : TAsmLabel;
         lTrueLabel,lFalseLabel : TAsmLabel;
         lOldFlowControl : TFlowControl;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);

         CurrentAsmData.getjumplabel(lLoopLabel);
         CurrentAsmData.getjumplabel(lContinueLabel);
         CurrentAsmData.getjumplabel(lBreakLabel);
         { arrange continue and breaklabels: }
         lOldFlowControl:=flowcontrol;
         lOldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
         lOldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
         include(flowcontrol,fc_inflowcontrol);
         exclude(flowcontrol,fc_unwind_loop);

         Sync_RegVars(true);
         { handling code at the end as it is much more efficient, and makes
           while equal to repeat loop, only the end true/false is swapped (PFV) }
         if lnf_testatbegin in LoopFlags then
           hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lContinueLabel);

         if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
            { align loop target, as an unconditional jump is done before,
              use jump align which assume that the instructions inserted as alignment are never executed }
            CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.Alignment.JumpAlign,CurrentSettings.Alignment.JumpAlignSkipMax));

         hlcg.A_Label(CurrentAsmData.CurrAsmList,lLoopLabel);

         CurrentProcInfo.CurrContinueLabel:=lContinueLabel;
         CurrentProcInfo.CurrBreakLabel:=lBreakLabel;

         if Assigned(Right) then
           SecondPass(Right);

         hlcg.A_Label(CurrentAsmData.CurrAsmList,lContinueLabel);
         if lnf_checknegate in LoopFlags then
          begin
             lTrueLabel:=lBreakLabel;
             lFalseLabel:=lLoopLabel;
          end
         else
          begin
             lTrueLabel:=lLoopLabel;
             lFalseLabel:=lBreakLabel;
          end;
         SecondPass(Left);

         hlcg.MakeToJumpBoolLabels(CurrentAsmData.CurrAsmList,Left,lTrueLabel,lFalseLabel);
         hlcg.A_Label(CurrentAsmData.CurrAsmList,lBreakLabel);

         Sync_RegVars(false);

         CurrentProcInfo.CurrContinueLabel:=lOldContinueLabel;
         CurrentProcInfo.CurrBreakLabel:=lOldBreakLabel;
         { a break/continue in a while/repeat block can't be seen outside }
         flowcontrol:=lOldFlowControl+(flowcontrol-[fc_break,fc_continue,fc_inflowcontrol]);
      end;


{*****************************************************************************
                               tcgIFNODE
*****************************************************************************}

    procedure TCGIfNode.Pass_Generate_Code;

      var
         lLabel : TAsmLabel;
         lOldFlowControl: TFlowControl;
(*
         org_regvar_loaded_other,
         then_regvar_loaded_other,
         else_regvar_loaded_other : regvarother_booleanarray;
         org_regvar_loaded_int,
         then_regvar_loaded_int,
         else_regvar_loaded_int : Tsuperregisterset;
         org_list,
         then_list,
         else_list : TAsmList;
*)

      begin
         Location_Reset(Location,LOC_VOID,OS_NO);
         lLabel:=nil;

         lOldFlowControl := flowcontrol;
         include(flowcontrol,fc_inflowcontrol);
         SecondPass(Left);

(*
         { save regvars loaded in the beginning so that we can restore them }
         { when processing the else-block                                   }
         if cs_opt_regvar in current_settings.optimizerswitches then
           begin
             org_list := current_asmdata.CurrAsmList;
             current_asmdata.CurrAsmList := TAsmList.create;
           end;
*)
         hlcg.MakeToJumpBool(CurrentAsmData.CurrAsmList,Left);

(*
         if cs_opt_regvar in current_settings.optimizerswitches then
           begin
             org_regvar_loaded_int := rg.regvar_loaded_int;
             org_regvar_loaded_other := rg.regvar_loaded_other;
           end;
*)
         if Assigned(Right) then
           begin
              hlcg.A_Label(CurrentAsmData.CurrAsmList,Left.Location.TrueLabel);
              SecondPass(Right);
           end;

         { save current asmlist (previous instructions + then-block) and }
         { loaded regvar state and create new clean ones                 }
{
         if cs_opt_regvar in current_settings.optimizerswitches then
           begin
             then_regvar_loaded_int := rg.regvar_loaded_int;
             then_regvar_loaded_other := rg.regvar_loaded_other;
             rg.regvar_loaded_int := org_regvar_loaded_int;
             rg.regvar_loaded_other := org_regvar_loaded_other;
             then_list := current_asmdata.CurrAsmList;
             current_asmdata.CurrAsmList := TAsmList.create;
           end;
}

         if Assigned(t1) then
           begin
              if Assigned(Right) then
                begin
                   CurrentAsmData.getjumplabel(lLabel);
                   { do go back to if line !! }
(*
                   if not(cs_opt_regvar in current_settings.optimizerswitches) then
*)
                     CurrentFilePos:=CurrentAsmData.CurrAsmList.getlasttaifilepos^
(*
                   else
                     current_filepos:=then_list.getlasttaifilepos^
*)
                   ;
                   hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel);
                   if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
                     CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.Alignment.JumpAlign,CurrentSettings.Alignment.JumpAlignSkipMax));
                end;
              hlcg.A_Label(CurrentAsmData.CurrAsmList,Left.Location.FalseLabel);
              SecondPass(t1);
(*
              { save current asmlist (previous instructions + else-block) }
              { and loaded regvar state and create a new clean list       }
              if cs_opt_regvar in current_settings.optimizerswitches then
                begin
{                  else_regvar_loaded_int := rg.regvar_loaded_int;
                  else_regvar_loaded_other := rg.regvar_loaded_other;}
                  else_list := current_asmdata.CurrAsmList;
                  current_asmdata.CurrAsmList := TAsmList.create;
                end;
*)
              if Assigned(Right) then
                hlcg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
           end
         else
           begin
(*
              if cs_opt_regvar in current_settings.optimizerswitches then
                begin
{                  else_regvar_loaded_int := rg.regvar_loaded_int;
                  else_regvar_loaded_other := rg.regvar_loaded_other;}
                  else_list := current_asmdata.CurrAsmList;
                  current_asmdata.CurrAsmList := TAsmList.create;
                end;
*)
              if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
                CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.Alignment.CoalesceAlign,CurrentSettings.Alignment.CoalesceAlignSkipMax));
              hlcg.A_Label(CurrentAsmData.CurrAsmList,Left.Location.FalseLabel);
           end;
         if not(Assigned(Right)) then
           begin
             if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
               CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.Alignment.CoalesceAlign,CurrentSettings.Alignment.CoalesceAlignSkipMax));
             hlcg.A_Label(CurrentAsmData.CurrAsmList,Left.Location.TrueLabel);
           end;

(*
         if cs_opt_regvar in current_settings.optimizerswitches then
           begin
             { add loads of regvars at the end of the then- and else-blocks  }
             { so that at the end of both blocks the same regvars are loaded }

             { no else block? }
             if not assigned(t1) then
               begin
                 sync_regvars_int(org_list,then_list,org_regvar_loaded_int,then_regvar_loaded_int);
                 sync_regvars_other(org_list,then_list,org_regvar_loaded_other,then_regvar_loaded_other);
               end
             { no then block? }
             else if not assigned(right) then
               begin
                 sync_regvars_int(org_list,else_list,org_regvar_loaded_int,else_regvar_loaded_int);
                 sync_regvars_other(org_list,else_list,org_regvar_loaded_other,else_regvar_loaded_other);
               end
             { both else and then blocks }
             else
               begin
                 sync_regvars_int(then_list,else_list,then_regvar_loaded_int,else_regvar_loaded_int);
                 sync_regvars_other(then_list,else_list,then_regvar_loaded_other,else_regvar_loaded_other);
               end;
             { add all lists together }
             org_list.concatlist(then_list);
             then_list.free;
             then_list := nil;
             org_list.concatlist(else_list);
             else_list.free;
             else_list := nil;
             org_list.concatlist(current_asmdata.CurrAsmList);
             current_asmdata.CurrAsmList.free;
             current_asmdata.CurrAsmList := org_list;
           end;
*)

         flowcontrol := lOldFlowControl + (flowcontrol - [fc_inflowcontrol]);
      end;


{*****************************************************************************
                              SecondFor
*****************************************************************************}

    procedure TCGForNode.Pass_Generate_Code;
      begin
        { for nodes are converted in pass_1 in a while loop }
        InternalError(2015082501);
      end;


{*****************************************************************************
                              SecondExitN
*****************************************************************************}

    procedure TCGExitNode.Pass_Generate_Code;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);

         if fc_no_direct_exit in flowcontrol then
           include(flowcontrol,fc_gotolabel);
         include(flowcontrol,fc_exit);
         if Assigned(Left) then
           SecondPass(Left);

         if (fc_unwind_exit in flowcontrol) then
           hlcg.G_Local_Unwind(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrExitLabel)
         else
           hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrExitLabel);
         if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
           CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.Alignment.JumpAlign,CurrentSettings.Alignment.JumpAlignSkipMax));
       end;


{*****************************************************************************
                              SecondBreakN
*****************************************************************************}

    procedure TCGBreakNode.Pass_Generate_Code;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);

         include(flowcontrol,fc_break);
         if CurrentProcInfo.CurrBreakLabel<>nil then
           begin
             if (fc_unwind_loop in flowcontrol) then
               hlcg.G_Local_Unwind(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrBreakLabel)
             else
               hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrBreakLabel);
             if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
               CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.Alignment.JumpAlign,CurrentSettings.Alignment.JumpAlignSkipMax));
           end
         else
           CGMessage(cg_e_break_not_allowed);
      end;


{*****************************************************************************
                              SecondContinueN
*****************************************************************************}

    procedure TCGContinueNode.Pass_Generate_Code;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);

         include(flowcontrol,fc_continue);
         if CurrentProcInfo.CurrContinueLabel<>nil then
           begin
             if (fc_unwind_loop in flowcontrol) then
               hlcg.G_Local_Unwind(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrContinueLabel)
             else
               hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrContinueLabel);
             if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
               CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.Alignment.JumpAlign,CurrentSettings.Alignment.JumpAlignSkipMax));
           end
         else
           CGMessage(cg_e_continue_not_allowed);
      end;


{*****************************************************************************
                             SecondGoto
*****************************************************************************}

    procedure TCGGotoNode.Pass_Generate_Code;

       begin
         Location_Reset(Location,LOC_VOID,OS_NO);

         include(flowcontrol,fc_gotolabel);
         hlcg.A_Jmp_Always_Pascal_Goto(CurrentAsmData.CurrAsmList,TCGLabelNode(LabelNode).GetAsmLabel);
         if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
           CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.Alignment.JumpAlign,CurrentSettings.Alignment.JumpAlignSkipMax));
       end;


{*****************************************************************************
                             SecondLabel
*****************************************************************************}

    function TCGLabelNode.GetAsmLabel : TAsmLabel;
      begin
        if not(Assigned(FAsmLabel)) then
          { labsym is not set in inlined procedures, but since assembler }
          { routines can't be inlined, that shouldn't matter             }
          if Assigned(LabSym) and
             LabSym.nonlocal then
            CurrentAsmData.getglobaljumplabel(FAsmLabel)
          else
            CurrentAsmData.getjumplabel(FAsmLabel);
        Result:=FAsmLabel
      end;


    procedure TCGLabelNode.Pass_Generate_Code;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);
         if not (nf_internal in Flags) then
           include(flowcontrol,fc_gotolabel);
         hlcg.A_Label_Pascal_Goto_Target(CurrentAsmData.CurrAsmList,GetAsmLabel);

         { Write also extra label if this label was referenced from
           assembler block }
         if Assigned(LabSym) and
            Assigned(LabSym.AsmBlockLabel) then
           hlcg.A_Label(CurrentAsmData.CurrAsmList,LabSym.AsmBlockLabel);
      end;


{*****************************************************************************
                             SecondTryExcept
*****************************************************************************}

    var
       EndExceptLabel : TAsmLabel;

     { jump out of an try/except block }
     procedure TCGTryExceptNode.Emit_Jump_Out_Of_Try_Except_Frame(AList: TAsmList; AFrameType: TFrameType; const AExceptionState: TCGExceptionStateHandler.TExceptionState; var AExceptTemps: TCGExceptionStateHandler.TExceptionTemps; AFrameLabel, AOuterLabel: TAsmLabel);
       begin
          hlcg.A_Label(AList,AFrameLabel);
          { we must also destroy the address frame which guards
            the exception object }
          CExceptionStateHandler.PopAddrStack(AList);
          hlcg.G_Exception_Reason_Discard(AList,ExceptionReasonType,AExceptTemps.ReasonBuf);
          if AFrameType=ft_except then
            begin
              CExceptionStateHandler.CleanupObjectStack(AList);
              CExceptionStateHandler.End_Catch(AList);
            end;
          hlcg.A_Jmp_Always(AList,AOuterLabel);
       end;


    procedure TCGTryExceptNode.Pass_Generate_Code;

      var
         lOldEndExceptLabel,
         lLastOnLabel,
         lExitExceptLabel,
         lContinueExceptLabel,
         lBreakExceptLabel,
         lExitTryLabel,
         lContinueTryLabel,
         lBreakTryLabel,
         lOldCurrExitLabel,
         lOldContinueLabel,
         lOldBreakLabel : TAsmLabel;
         lDestroyTemps,
         lExceptTemps : TCGExceptionStateHandler.TExceptionTemps;
         lTryState,lObjectDestroyAndReRaiseState: TCGExceptionStateHandler.TExceptionState;
         lAfterOnFlowControl: TFlowControl;
      label
         errorexit;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);
         lContinueTryLabel:=nil;
         lBreakTryLabel:=nil;
         lContinueExceptLabel:=nil;
         lBreakExceptLabel:=nil;
         lObjectDestroyAndReRaiseState:=Default(TCGExceptionStateHandler.TExceptionState);

         { this can be called recursively }
         lOldBreakLabel:=nil;
         lOldContinueLabel:=nil;
         lOldEndExceptLabel:=EndExceptLabel;

         { save the old labels for control flow statements }
         lOldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
         if Assigned(CurrentProcInfo.CurrBreakLabel) then
           begin
              lOldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
              lOldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
           end;

         { get new labels for the control flow statements }
         CurrentAsmData.getjumplabel(lExitTryLabel);
         CurrentAsmData.getjumplabel(lExitExceptLabel);
         if Assigned(CurrentProcInfo.CurrBreakLabel) then
           begin
              CurrentAsmData.getjumplabel(lBreakTryLabel);
              CurrentAsmData.getjumplabel(lContinueTryLabel);
              CurrentAsmData.getjumplabel(lBreakExceptLabel);
              CurrentAsmData.getjumplabel(lContinueExceptLabel);
           end;

         CurrentAsmData.getjumplabel(EndExceptLabel);
         CurrentAsmData.getjumplabel(lLastOnLabel);

         CExceptionStateHandler.Get_Exception_Temps(CurrentAsmData.CurrAsmList,lExceptTemps);
         CExceptionStateHandler.New_Exception(CurrentAsmData.CurrAsmList,lExceptTemps,tek_except,lTryState);

         { try block }
         { set control flow labels for the try block }
         CurrentProcInfo.CurrExitLabel:=lExitTryLabel;
         if Assigned(lOldBreakLabel) then
          begin
            CurrentProcInfo.CurrContinueLabel:=lContinueTryLabel;
            CurrentProcInfo.CurrBreakLabel:=lBreakTryLabel;
          end;

         SecondPass(Left);
         if CodeGenError then
           goto errorexit;

         { don't generate line info for internal cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoStart));

         CExceptionStateHandler.End_Try_Block(CurrentAsmData.CurrAsmList,tek_except,lExceptTemps,lTryState,EndExceptLabel);

         CExceptionStateHandler.Emit_Except_Label(CurrentAsmData.CurrAsmList,tek_except,lTryState,lExceptTemps);
         CExceptionStateHandler.Free_Exception(CurrentAsmData.CurrAsmList, lExceptTemps, lTryState, 0, EndExceptLabel, false);

         { end cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoEnd));

         { set control flow labels for the except block }
         { and the on statements                        }
         CurrentProcInfo.CurrExitLabel:=lExitExceptLabel;
         if Assigned(lOldBreakLabel) then
          begin
            CurrentProcInfo.CurrContinueLabel:=lContinueExceptLabel;
            CurrentProcInfo.CurrBreakLabel:=lBreakExceptLabel;
          end;

         flowcontrol:=[fc_inflowcontrol]+lTryState.OldFlowControl*[fc_catching_exceptions];
         { on statements }
         if Assigned(Right) then
           SecondPass(Right);

         lAfterOnFlowControl:=flowcontrol;

         { don't generate line info for internal cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoStart));

         hlcg.A_Label(CurrentAsmData.CurrAsmList,lLastOnLabel);
         { default handling except handling }
         if Assigned(t1) then
           begin
              { FPC_CATCHES with 'default handler' flag (=-1) need no longer be called,
                it doesn't change any state and its return value is ignored (Sergei)
              }

              { the destruction of the exception object must be also }
              { guarded by an exception frame, but it can be omitted }
              { if there's no user code in 'except' block            }

              CExceptionStateHandler.Catch_All_Start(CurrentAsmData.CurrAsmList);
              if not (Has_No_Code(t1)) then
               begin
                 { if there is an outer frame that catches exceptions, remember this for the "except"
                   part of this try/except }
                 flowcontrol:=lTryState.OldFlowControl*[fc_inflowcontrol,fc_catching_exceptions];
                 CExceptionStateHandler.Get_Exception_Temps(CurrentAsmData.CurrAsmList,lDestroyTemps);
                 CExceptionStateHandler.New_Exception(CurrentAsmData.CurrAsmList,lDestroyTemps,tek_except,lObjectDestroyAndReRaiseState);
                 CExceptionStateHandler.Catch_All_Add(CurrentAsmData.CurrAsmList);
                 { the flowcontrol from the default except-block must be merged
                   with the flowcontrol flags potentially set by the
                   on-statements handled above (secondpass(right)), as they are
                   at the same program level }
                 flowcontrol:=
                   flowcontrol+
                   lAfterOnFlowControl;

                 { except block needs line info }
                 CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoEnd));

                 SecondPass(t1);

                 CExceptionStateHandler.Handle_Nested_Exception(CurrentAsmData.CurrAsmList,lDestroyTemps,lObjectDestroyAndReRaiseState);

                 CExceptionStateHandler.UnGet_Exception_Temps(CurrentAsmData.CurrAsmList,lDestroyTemps);
                 CExceptionStateHandler.Catch_All_End(CurrentAsmData.CurrAsmList);
                 hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,EndExceptLabel);
               end
             else
               begin
                 lObjectDestroyAndReRaiseState.NewFlowControl:=lAfterOnFlowControl;
                 CExceptionStateHandler.CleanupObjectStack(CurrentAsmData.CurrAsmList);
                 CExceptionStateHandler.Catch_All_End(CurrentAsmData.CurrAsmList);
                 hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,EndExceptLabel);
               end;
           end
         else
           begin
             CExceptionStateHandler.Handle_ReRaise(CurrentAsmData.CurrAsmList,lExceptTemps,lTryState,tek_except);
             lObjectDestroyAndReRaiseState.NewFlowControl:=lAfterOnFlowControl;
           end;

         if fc_exit in lObjectDestroyAndReRaiseState.NewFlowControl then
           Emit_Jump_Out_Of_Try_Except_Frame(CurrentAsmData.CurrAsmList,ft_except,lObjectDestroyAndReRaiseState,lExceptTemps,lExitExceptLabel,lOldCurrExitLabel);

         if fc_break in lObjectDestroyAndReRaiseState.NewFlowControl then
           Emit_Jump_Out_Of_Try_Except_Frame(CurrentAsmData.CurrAsmList,ft_except,lObjectDestroyAndReRaiseState,lExceptTemps,lBreakExceptLabel,lOldBreakLabel);

         if fc_continue in lObjectDestroyAndReRaiseState.NewFlowControl then
           Emit_Jump_Out_Of_Try_Except_Frame(CurrentAsmData.CurrAsmList,ft_except,lObjectDestroyAndReRaiseState,lExceptTemps,lContinueExceptLabel,lOldContinueLabel);

         if fc_exit in lTryState.NewFlowControl then
           Emit_Jump_Out_Of_Try_Except_Frame(CurrentAsmData.CurrAsmList,ft_try,lTryState,lExceptTemps,lExitTryLabel,lOldCurrExitLabel);

         if fc_break in lTryState.NewFlowControl then
          Emit_Jump_Out_Of_Try_Except_Frame(CurrentAsmData.CurrAsmList,ft_try,lTryState,lExceptTemps,lBreakTryLabel,lOldBreakLabel);

         if fc_continue in lTryState.NewFlowControl then
           Emit_Jump_Out_Of_Try_Except_Frame(CurrentAsmData.CurrAsmList,ft_try,lTryState,lExceptTemps,lContinueTryLabel,lOldContinueLabel);

         CExceptionStateHandler.UnGet_Exception_Temps(CurrentAsmData.CurrAsmList,lExceptTemps);
         hlcg.A_Label(CurrentAsmData.CurrAsmList,EndExceptLabel);

         { end cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoEnd));

       errorexit:
         { restore all saved labels }
         EndExceptLabel:=lOldEndExceptLabel;

         { restore the control flow labels }
         CurrentProcInfo.CurrExitLabel:=lOldCurrExitLabel;
         if Assigned(lOldBreakLabel) then
          begin
            CurrentProcInfo.CurrContinueLabel:=lOldContinueLabel;
            CurrentProcInfo.CurrBreakLabel:=lOldBreakLabel;
          end;

         { return all used control flow statements }
         flowcontrol:=lTryState.OldFlowControl+(lObjectDestroyAndReRaiseState.NewFlowControl +
           lTryState.NewFlowControl - [fc_inflowcontrol,fc_catching_exceptions]);
      end;


    procedure TCGOnNode.Pass_Generate_Code;
      var
         lNextOnLabel,
         lExitOnLabel,
         lContinueOnLabel,
         lBreakOnLabel,
         lOldCurrExitLabel,
         lOldContinueLabel,
         lOldBreakLabel : TAsmLabel;
         lObjectDestroyAndReRaiseState: TCGExceptionStateHandler.TExceptionState;
         lExceptTemps : TCGExceptionStateHandler.TExceptionTemps;
         lExceptVarSym : TLocalVarSym;
         lExceptLocDef: TDef;
         lExceptLocReg: TRegister;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);
         lOldCurrExitLabel:=nil;
         lContinueOnLabel:=nil;
         lBreakOnLabel:=nil;
         lExitOnLabel:=nil;

         CurrentAsmData.getjumplabel(lNextOnLabel);

         CExceptionStateHandler.Begin_Catch(CurrentAsmData.CurrAsmList,ExceptType,lNextOnLabel,lExceptLocDef,lExceptLocReg);

         { Retrieve exception variable }
         if Assigned(ExceptSymTable) then
           lExceptVarSym:=TLocalVarSym(ExceptSymTable.SymList[0])
         else
           InternalError(2011020401);

         if Assigned(lExceptVarSym) then
           begin
             Location_Reset_Ref(lExceptVarSym.LocAlloc, LOC_REFERENCE, Def_CGSize(VoidPointerType), VoidPointerType.Alignment, []);
             TG.GetLocal(CurrentAsmData.CurrAsmList, lExceptVarSym.vardef.Size, VoidPointerType.Alignment, 0, lExceptVarSym.vardef, lExceptVarSym, lExceptVarSym.LocAlloc.Reference);
             hlcg.A_Load_Reg_Ref(CurrentAsmData.CurrAsmList, lExceptLocDef, lExceptVarSym.vardef, lExceptLocReg, lExceptVarSym.LocAlloc.Reference);
           end;
         { in the case that another exception is risen
           we've to destroy the old one, so create a new
           exception frame for the catch-handler }
         CExceptionStateHandler.Get_Exception_Temps(CurrentAsmData.CurrAsmList,lExceptTemps);
         CExceptionStateHandler.New_Exception(CurrentAsmData.CurrAsmList,lExceptTemps,tek_except,lObjectDestroyAndReRaiseState);

         lOldBreakLabel:=nil;
         lOldContinueLabel:=nil;
         if Assigned(Right) then
           begin
              lOldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
              CurrentAsmData.getjumplabel(lExitOnLabel);
              CurrentProcInfo.CurrExitLabel:=lExitOnLabel;
              if Assigned(CurrentProcInfo.CurrBreakLabel) then
               begin
                 lOldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
                 lOldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
                 CurrentAsmData.getjumplabel(lBreakOnLabel);
                 CurrentAsmData.getjumplabel(lContinueOnLabel);
                 CurrentProcInfo.CurrContinueLabel:=lContinueOnLabel;
                 CurrentProcInfo.CurrBreakLabel:=lBreakOnLabel;
               end;

              SecondPass(Right);
           end;

         CExceptionStateHandler.Handle_Nested_Exception(CurrentAsmData.CurrAsmList,lExceptTemps,lObjectDestroyAndReRaiseState);

         { clear some stuff }
         if Assigned(lExceptVarSym) then
           begin
             TG.UnGetLocal(CurrentAsmData.CurrAsmList,lExceptVarSym.LocAlloc.Reference);
             lExceptVarSym.LocAlloc.Loc:=LOC_INVALID;
           end;
         CExceptionStateHandler.End_Catch(CurrentAsmData.CurrAsmList);
         hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,EndExceptLabel);

         if Assigned(Right) then
           begin
              { special handling for control flow instructions }
              if fc_exit in lObjectDestroyAndReRaiseState.NewFlowControl then
                begin
                   { the address and object pop does secondtryexcept }
                   hlcg.A_Label(CurrentAsmData.CurrAsmList,lExitOnLabel);
                   hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldCurrExitLabel);
                end;

              if fc_break in lObjectDestroyAndReRaiseState.NewFlowControl then
                begin
                   { the address and object pop does secondtryexcept }
                   hlcg.A_Label(CurrentAsmData.CurrAsmList,lBreakOnLabel);
                   hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldBreakLabel);
                end;

              if fc_continue in lObjectDestroyAndReRaiseState.NewFlowControl then
                begin
                   { the address and object pop does secondtryexcept }
                   hlcg.A_Label(CurrentAsmData.CurrAsmList,lContinueOnLabel);
                   hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldContinueLabel);
                end;

              CurrentProcInfo.CurrExitLabel:=lOldCurrExitLabel;
              if Assigned(lOldBreakLabel) then
               begin
                 CurrentProcInfo.CurrContinueLabel:=lOldContinueLabel;
                 CurrentProcInfo.CurrBreakLabel:=lOldBreakLabel;
               end;
           end;

         CExceptionStateHandler.UnGet_Exception_Temps(CurrentAsmData.CurrAsmList,lExceptTemps);
         hlcg.A_Label(CurrentAsmData.CurrAsmList,lNextOnLabel);
         CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoEnd));

         { propagate exit/break/continue }
         flowcontrol:=lObjectDestroyAndReRaiseState.OldFlowControl+(lObjectDestroyAndReRaiseState.NewFlowControl-[fc_inflowcontrol,fc_catching_exceptions]);

         { next on node }
         if Assigned(Left) then
           SecondPass(Left);
      end;

{*****************************************************************************
                             SecondTryFinally
*****************************************************************************}

    { jump out of a finally block }
    procedure TCGTryFinallyNode.Emit_Jump_Out_Of_Try_Finally_Frame(AList: TAsmList; const AReason: byte; const AFinallyCodeLabel: TAsmLabel; var AExceptTemps: TCGExceptionStateHandler.TExceptionTemps; AFrameLabel: TAsmLabel);
      begin
         hlcg.A_Label(AList,AFrameLabel);
         hlcg.G_Exception_Reason_Discard(AList,ExceptionReasonType,AExceptTemps.ReasonBuf);
         hlcg.G_Exception_Reason_Save_Const(AList,ExceptionReasonType,AReason,AExceptTemps.ReasonBuf);
         hlcg.A_Jmp_Always(AList,AFinallyCodeLabel);
      end;


    function TCGTryFinallyNode.Get_Jump_Out_Of_Try_Finally_Frame_Label(const AFinallyExceptionState: TCGExceptionStateHandler.TExceptionState): TAsmLabel;
      begin
        CurrentAsmData.getjumplabel(Result);
      end;


    procedure TCGTryFinallyNode.Handle_SafeCall_Exception;
      var
        lCGPara, lResultPara: TCGPara;
        lSelfSym: TParaVarSym;
        lProcDef: TProcDef;
        lSafeCallResult: TLocalVarSym;
      begin
        { call fpc_safecallhandler, passing self for methods of classes,
          nil otherwise. }
        lProcDef:=Search_System_Proc('fpc_safecallhandler');
        lCGPara.init;
        ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,lProcDef,1,lCGPara);
        if Is_Class(CurrentProcInfo.ProcDef.struct) then
          begin
            lSelfSym:=TParaVarSym(CurrentProcInfo.ProcDef.ParaST.Find('self'));
            if (lSelfSym=nil) or (lSelfSym.typ<>paravarsym) then
              InternalError(2011123101);
            hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,lSelfSym.vardef,lSelfSym.LocAlloc,lCGPara);
          end
        else
          hlcg.A_Load_Const_CGPara(CurrentAsmData.CurrAsmList,VoidPointerType,0,lCGPara);
        ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lCGPara);
        lResultPara:=hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,lProcDef,[@lCGPara],nil);
        lCGPara.done;
        lSafeCallResult:=TLocalVarSym(CurrentProcInfo.ProcDef.LocalST.Find('safecallresult'));
        hlcg.Gen_Load_CGPara_Loc(CurrentAsmData.CurrAsmList,lResultPara.def,lResultPara,lSafeCallResult.LocAlloc,false);
        lResultPara.ResetIfTemp;
      end;


    procedure TCGTryFinallyNode.Pass_Generate_Code;
      var
         lEndFinallyLabel,
         lExitFinallyLabel,
         lContinueFinallyLabel,
         lBreakFinallyLabel,
         lOldCurrExitLabel,
         lOldContinueLabel,
         lOldBreakLabel,
         lFinallyNoExceptionLabel: TAsmLabel;
         lFinallyExceptionState: TCGExceptionStateHandler.TExceptionState;
         lExceptTemps : TCGExceptionStateHandler.TExceptionTemps;
         lReasonReg : TRegister;
         lExceptFrameKind: TCGExceptionStateHandler.TExceptFrameKind;
         lTempList: TAsmList;

        procedure HandleBreakContinueExit(const AFinallyCode: TAsmLabel; ADoReRaise: boolean);
          begin
            { no exception happened, but maybe break/continue/exit }
            hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,ExceptionReasonType,OC_EQ,0,lReasonReg,lEndFinallyLabel);
            if fc_exit in lFinallyExceptionState.NewFlowControl then
              hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,ExceptionReasonType,OC_EQ,2,lReasonReg,lOldCurrExitLabel);
            if fc_break in lFinallyExceptionState.NewFlowControl then
              hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,ExceptionReasonType,OC_EQ,3,lReasonReg,lOldBreakLabel);
            if fc_continue in lFinallyExceptionState.NewFlowControl then
              hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,ExceptionReasonType,OC_EQ,4,lReasonReg,lOldContinueLabel);
            if ADoReRaise then
              CExceptionStateHandler.Handle_ReRaise(CurrentAsmData.CurrAsmList,lExceptTemps,lFinallyExceptionState,tek_normalfinally)
            else
              hlcg.G_Unreachable(CurrentAsmData.CurrAsmList);
            { redirect break/continue/exit to the label above, with the reasonbuf set appropriately }
            if fc_exit in lFinallyExceptionState.NewFlowControl then
              Emit_Jump_Out_Of_Try_Finally_Frame(CurrentAsmData.CurrAsmList,2,AFinallyCode,lExceptTemps,lExitFinallyLabel);
            if fc_break in lFinallyExceptionState.NewFlowControl then
              Emit_Jump_Out_Of_Try_Finally_Frame(CurrentAsmData.CurrAsmList,3,AFinallyCode,lExceptTemps,lBreakFinallyLabel);
            if fc_continue in lFinallyExceptionState.NewFlowControl then
              Emit_Jump_Out_Of_Try_Finally_Frame(CurrentAsmData.CurrAsmList,4,AFinallyCode,lExceptTemps,lContinueFinallyLabel);
          end;

      begin
         Location_Reset(Location,LOC_VOID,OS_NO);
         lOldBreakLabel:=nil;
         lOldContinueLabel:=nil;
         lContinueFinallyLabel:=nil;
         lBreakFinallyLabel:=nil;

         if not ImplicitFrame then
           lExceptFrameKind:=tek_normalfinally
         else
           lExceptFrameKind:=tek_implicitfinally;

         CurrentAsmData.getjumplabel(lEndFinallyLabel);

         { call setjmp, and jump to finally label on non-zero result }
         CExceptionStateHandler.Get_Exception_Temps(CurrentAsmData.CurrAsmList,lExceptTemps);
         CExceptionStateHandler.New_Exception(CurrentAsmData.CurrAsmList,lExceptTemps,lExceptFrameKind,lFinallyExceptionState);

         { the finally block must catch break, continue and exit }
         { statements                                            }
         lOldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
         lExitFinallyLabel:=Get_Jump_Out_Of_Try_Finally_Frame_Label(lFinallyExceptionState);
         CurrentProcInfo.CurrExitLabel:=lExitFinallyLabel;
         if Assigned(CurrentProcInfo.CurrBreakLabel) then
          begin
            lOldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
            lOldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
            lBreakFinallyLabel:=Get_Jump_Out_Of_Try_Finally_Frame_Label(lFinallyExceptionState);
            lContinueFinallyLabel:=Get_Jump_Out_Of_Try_Finally_Frame_Label(lFinallyExceptionState);
            CurrentProcInfo.CurrContinueLabel:=lContinueFinallyLabel;
            CurrentProcInfo.CurrBreakLabel:=lBreakFinallyLabel;
          end;

         { try code }
         if Assigned(Left) then
           begin
              SecondPass(Left);
              if CodeGenError then
                exit;
           end;

         { don't generate line info for internal cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoStart));

         CExceptionStateHandler.End_Try_Block(CurrentAsmData.CurrAsmList,lExceptFrameKind,lExceptTemps,lFinallyExceptionState,lFinallyExceptionState.FinallyCodeLabel);
         if Assigned(third) then
           begin
             lTempList:=TAsmList.Create;
             { emit the except label already (to a temporary list) to ensure that any calls in the
               finally block refer to the outer exception frame rather than to the exception frame
               that emits this same finally code in case an exception does happen }
             CExceptionStateHandler.Emit_Except_Label(lTempList,lExceptFrameKind,lFinallyExceptionState,lExceptTemps);

             flowcontrol:=lFinallyExceptionState.OldFlowControl*[fc_inflowcontrol,fc_catching_exceptions];
             CurrentAsmData.getjumplabel(lFinallyNoExceptionLabel);
             hlcg.A_Label(CurrentAsmData.CurrAsmList,lFinallyNoExceptionLabel);
             if not ImplicitFrame then
               CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoEnd));
             SecondPass(third);
             if CodeGenError then
               exit;
             if not ImplicitFrame then
               CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoStart));
             lReasonReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ExceptionReasonType);
             hlcg.G_Exception_Reason_Load(CurrentAsmData.CurrAsmList,ExceptionReasonType,ExceptionReasonType,lExceptTemps.ReasonBuf,lReasonReg);
             HandleBreakContinueExit(lFinallyNoExceptionLabel,false);

             CurrentAsmData.CurrAsmList.ConcatList(lTempList);
             lTempList.free;
             lTempList := nil;
           end
         else
           CExceptionStateHandler.Emit_Except_Label(CurrentAsmData.CurrAsmList,lExceptFrameKind,lFinallyExceptionState,lExceptTemps);

         { just free the frame information }
         CExceptionStateHandler.Free_Exception(CurrentAsmData.CurrAsmList,lExceptTemps,lFinallyExceptionState,1,lFinallyExceptionState.ExceptionLabel,true);

         { end cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoEnd));

         { finally code (don't unconditionally set fc_inflowcontrol, since the
           finally code is unconditionally executed; we do have to filter out
           flags regarding break/contrinue/etc. because we have to give an
           error in case one of those is used in the finally-code }
         flowcontrol:=lFinallyExceptionState.OldFlowControl*[fc_inflowcontrol,fc_catching_exceptions];
         SecondPass(Right);
         { goto is allowed if it stays inside the finally block,
           this is checked using the exception block number }
         if (flowcontrol-[fc_gotolabel])<>(lFinallyExceptionState.OldFlowControl*[fc_inflowcontrol,fc_catching_exceptions]) then
           CGMessage(cg_e_control_flow_outside_finally);
         if CodeGenError then
           exit;

         { don't generate line info for internal cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoStart));

         { same level as before try, but this part is only executed if an exception occurred
           -> always fc_in_flowcontrol }
         flowcontrol:=lFinallyExceptionState.OldFlowControl*[fc_catching_exceptions];
         include(flowcontrol,fc_inflowcontrol);
         if not Assigned(third) then
           begin
             { the value should now be in the exception handler }
             lReasonReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,ExceptionReasonType);
             hlcg.G_Exception_Reason_Load(CurrentAsmData.CurrAsmList,ExceptionReasonType,ExceptionReasonType,lExceptTemps.ReasonBuf,lReasonReg);
             if ImplicitFrame then
               begin
                 hlcg.A_Cmp_Const_Reg_Label(CurrentAsmData.CurrAsmList,ExceptionReasonType,OC_EQ,0,lReasonReg,lEndFinallyLabel);
                 { finally code only needed to be executed on exception (-> in
                   if-branch -> fc_inflowcontrol) }
                 if CurrentProcInfo.ProcDef.Generate_SafeCall_Wrapper then
                   begin
                     Handle_SafeCall_Exception;
                     { we have to jump immediately as we have to return the value of FPC_SAFECALL }
                     hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lOldCurrExitLabel);
                   end
                 else
                   CExceptionStateHandler.Handle_ReRaise(CurrentAsmData.CurrAsmList,lExceptTemps,lFinallyExceptionState,lExceptFrameKind);
                 { we have to load 0 into the execepttemp, else the program thinks an exception happened }
                 Emit_Jump_Out_Of_Try_Finally_Frame(CurrentAsmData.CurrAsmList,0,lFinallyExceptionState.ExceptionLabel,lExceptTemps,lExitFinallyLabel);
               end
             else
               begin
                 HandleBreakContinueExit(lFinallyExceptionState.ExceptionLabel,true);
               end;
           end
         else
           begin
             if ImplicitFrame then
               begin
                 if CurrentProcInfo.ProcDef.Generate_SafeCall_Wrapper then
                   Handle_SafeCall_Exception
                 else
                   CExceptionStateHandler.Handle_ReRaise(CurrentAsmData.CurrAsmList,lExceptTemps,lFinallyExceptionState,lExceptFrameKind);
               end
             else
               begin
                 CExceptionStateHandler.Handle_ReRaise(CurrentAsmData.CurrAsmList,lExceptTemps,lFinallyExceptionState,lExceptFrameKind);
               end;

           end;
         CExceptionStateHandler.UnGet_Exception_Temps(CurrentAsmData.CurrAsmList,lExceptTemps);
         hlcg.A_Label(CurrentAsmData.CurrAsmList,lEndFinallyLabel);

         { end cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_NoLineInfoEnd));

         CurrentProcInfo.CurrExitLabel:=lOldCurrExitLabel;
         if Assigned(CurrentProcInfo.CurrBreakLabel) then
          begin
            CurrentProcInfo.CurrContinueLabel:=lOldContinueLabel;
            CurrentProcInfo.CurrBreakLabel:=lOldBreakLabel;
          end;
         flowcontrol:=lFinallyExceptionState.OldFlowControl+(lFinallyExceptionState.NewFlowControl-[fc_inflowcontrol,fc_catching_exceptions]);
      end;


    function TCGRaiseNode.Pass_1: TNode;
      begin
        if not(tf_use_psabieh in TargetInfo.Flags) or Assigned(Left) then
          Result:=inherited
        else
          begin
            expectloc:=LOC_VOID;
            Result:=nil;
          end;
      end;

{$ifndef SkipABIEH}
    { has to be factored out as well }
    procedure TCGRaiseNode.Pass_Generate_Code;
      var
        lCurrentLandingPad, lCurrentAction, lReRaiseLandingPad: TPSABIEHAction;
        lPSABIEHProcInfo: TPSABIEHProcInfo;
      begin
        if not(tf_use_psabieh in TargetInfo.Flags) then
          InternalError(2019021701);

        Location_Reset(Location,LOC_VOID,OS_NO);
        lCurrentLandingPad:=nil;
        lCurrentAction:=nil;
        lReRaiseLandingPad:=nil;
        lPSABIEHProcInfo:=CurrentProcInfo as TPSABIEHProcInfo;
        { a reraise must raise the exception to the parent exception frame }
        if fc_catching_exceptions in flowcontrol then
          begin
            lPSABIEHProcInfo.CreateNewPSABIEHCallsite(CurrentAsmData.CurrAsmList);
            lCurrentLandingPad:=lPSABIEHProcInfo.CurrentLandingPad;
            if lPSABIEHProcInfo.PopLandingPad(lCurrentLandingPad) then
              exclude(flowcontrol,fc_catching_exceptions);
            lCurrentAction:=lPSABIEHProcInfo.CurrentAction;
            lPSABIEHProcInfo.FinalizeAndPopAction(lCurrentAction);

            if not(fc_catching_exceptions in flowcontrol) then
              begin
                lReRaiseLandingPad:=lPSABIEHProcInfo.NoAction;
                lPSABIEHProcInfo.PushAction(lReRaiseLandingPad);
                lPSABIEHProcInfo.PushLandingPad(lReRaiseLandingPad);
              end;
          end;
        hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,'fpc_reraise',[],nil).ResetIfTemp;
        if Assigned(lCurrentLandingPad) then
          begin
            lPSABIEHProcInfo.CreateNewPSABIEHCallsite(CurrentAsmData.CurrAsmList);
            if not(fc_catching_exceptions in flowcontrol) then
              begin
                lPSABIEHProcInfo.PopLandingPad(lPSABIEHProcInfo.CurrentLandingPad);
                lPSABIEHProcInfo.PopAction(lReRaiseLandingPad);
              end;

            lPSABIEHProcInfo.PushAction(lCurrentAction);
            lPSABIEHProcInfo.PushLandingPad(lCurrentLandingPad);
            include(flowcontrol,fc_catching_exceptions);
          end;
      end;
{$endif SkipABIEH}


begin
   CWhileRepeatNode:=TCGWhileRepeatNode;
   CIfNode:=TCGIfNode;
   CForNode:=TCGForNode;
   CExitNode:=TCGExitNode;
   CBreakNode:=TCGBreakNode;
   CContinueNode:=TCGContinueNode;
   CGotoNode:=TCGGotoNode;
   CLabelNode:=TCGLabelNode;
   CRaiseNode:=TCGRaiseNode;
   CTryExceptNode:=TCGTryExceptNode;
   CTryFinallyNode:=TCGTryFinallyNode;
   COnNode:=TCGOnNode;
   CExceptionStateHandler:=TCGExceptionStateHandler;
end.

