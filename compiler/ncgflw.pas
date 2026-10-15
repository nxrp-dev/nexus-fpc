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
          usedregvars: TUsedRegVars;

          procedure pass_generate_code;override;
          procedure sync_regvars(checkusedregvars: boolean);
       end;

       TCGIfNode = class(TIfNode)
          procedure pass_generate_code;override;
       end;

       TCGForNode = class(TForNode)
          procedure pass_generate_code;override;
       end;

       TCGExitNode = class(TExitNode)
          procedure pass_generate_code;override;
       end;

       TCGBreakNode = class(TBreakNode)
          procedure pass_generate_code;override;
       end;

       TCGContinueNode = class(TContinueNode)
          procedure pass_generate_code;override;
       end;

       TCGGotoNode = class(TGotoNode)
          procedure pass_generate_code;override;
       end;

       TCGLabelNode = class(TLabelNode)
       protected
          asmlabel : TAsmLabel;
       public
          function getasmlabel : TAsmLabel; virtual;
          procedure pass_generate_code;override;
       end;

       TCGRaiseNode = class(TRaiseNode)
         function pass_1: TNode;override;
{$ifndef SkipABIEH}
         procedure pass_generate_code;override;
{$endif SkipABIEH}
       end;

       TCGTryExceptNode = class(TTryExceptNode)
        protected
          type
            TFrameType = (ft_try,ft_except);

          procedure emit_jump_out_of_try_except_frame(list: TAsmList; frametype: TFrameType; const exceptiontate: TCGExceptionStateHandler.TExceptionState; var excepttemps: TCGExceptionStateHandler.TExceptionTemps; framelabel, outerlabel: TAsmLabel); virtual;
        public
          procedure pass_generate_code;override;
       end;

       TCGTryFinallyNode = class(TTryFinallyNode)
        protected
          procedure emit_jump_out_of_try_finally_frame(list: TAsmList; const reason: byte; const finallycodelabel: TAsmLabel; var excepttemps: TCGExceptionStateHandler.TExceptionTemps; framelabel: TAsmLabel);
          function get_jump_out_of_try_finally_frame_label(const finallyexceptionstate: TCGExceptionStateHandler.TExceptionState): TAsmLabel;
        public
          procedure handle_safecall_exception;
          procedure pass_generate_code;override;
       end;

       TCGOnNode = class(TOnNode)
          procedure pass_generate_code;override;
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

    procedure TCGWhileRepeatNode.sync_regvars(checkusedregvars: boolean);
      begin
         if (cs_opt_regvar in CurrentSettings.OptimizerSwitches) and
            not(pi_has_label in CurrentProcInfo.flags) then
           begin
             if checkusedregvars then
               begin
                 usedregvars.intregvars.init;
                 usedregvars.addrregvars.init;
                 usedregvars.fpuregvars.init;
                 usedregvars.mmregvars.init;

                 { we have to synchronise both the regvars used in the loop }
                 { and the ones in the while/until condition                }
                 get_used_regvars(self,usedregvars);
                 gen_sync_regvars(CurrentAsmData.CurrAsmList,usedregvars);
               end
             else
               begin
                 gen_sync_regvars(CurrentAsmData.CurrAsmList,usedregvars);
                 usedregvars.intregvars.done;
                 usedregvars.addrregvars.done;
                 usedregvars.fpuregvars.done;
                 usedregvars.mmregvars.done;
               end;
           end;
      end;


    procedure TCGWhileRepeatNode.pass_generate_code;
      var
         lcont,lbreak,lloop,
         oldclabel,oldblabel : TAsmLabel;
         truelabel,falselabel : TAsmLabel;
         oldflowcontrol : TFlowControl;
      begin
         location_reset(location,LOC_VOID,OS_NO);

         CurrentAsmData.getjumplabel(lloop);
         CurrentAsmData.getjumplabel(lcont);
         CurrentAsmData.getjumplabel(lbreak);
         { arrange continue and breaklabels: }
         oldflowcontrol:=flowcontrol;
         oldclabel:=CurrentProcInfo.CurrContinueLabel;
         oldblabel:=CurrentProcInfo.CurrBreakLabel;
         include(flowcontrol,fc_inflowcontrol);
         exclude(flowcontrol,fc_unwind_loop);

         sync_regvars(true);
         { handling code at the end as it is much more efficient, and makes
           while equal to repeat loop, only the end true/false is swapped (PFV) }
         if lnf_testatbegin in loopflags then
           hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,lcont);

         if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
            { align loop target, as an unconditional jump is done before,
              use jump align which assume that the instructions inserted as alignment are never executed }
            CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.alignment.JumpAlign,CurrentSettings.alignment.JumpAlignSkipMax));

         hlcg.a_label(CurrentAsmData.CurrAsmList,lloop);

         CurrentProcInfo.CurrContinueLabel:=lcont;
         CurrentProcInfo.CurrBreakLabel:=lbreak;

         if Assigned(right) then
           SecondPass(right);

         hlcg.a_label(CurrentAsmData.CurrAsmList,lcont);
         if lnf_checknegate in loopflags then
          begin
             truelabel:=lbreak;
             falselabel:=lloop;
          end
         else
          begin
             truelabel:=lloop;
             falselabel:=lbreak;
          end;
         SecondPass(left);

         hlcg.maketojumpboollabels(CurrentAsmData.CurrAsmList,left,truelabel,falselabel);
         hlcg.a_label(CurrentAsmData.CurrAsmList,lbreak);

         sync_regvars(false);

         CurrentProcInfo.CurrContinueLabel:=oldclabel;
         CurrentProcInfo.CurrBreakLabel:=oldblabel;
         { a break/continue in a while/repeat block can't be seen outside }
         flowcontrol:=oldflowcontrol+(flowcontrol-[fc_break,fc_continue,fc_inflowcontrol]);
      end;


{*****************************************************************************
                               tcgIFNODE
*****************************************************************************}

    procedure TCGIfNode.pass_generate_code;

      var
         hl : TAsmLabel;
         oldflowcontrol: TFlowControl;
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
         location_reset(location,LOC_VOID,OS_NO);
         hl:=nil;

         oldflowcontrol := flowcontrol;
         include(flowcontrol,fc_inflowcontrol);
         SecondPass(left);

(*
         { save regvars loaded in the beginning so that we can restore them }
         { when processing the else-block                                   }
         if cs_opt_regvar in current_settings.optimizerswitches then
           begin
             org_list := current_asmdata.CurrAsmList;
             current_asmdata.CurrAsmList := TAsmList.create;
           end;
*)
         hlcg.maketojumpbool(CurrentAsmData.CurrAsmList,left);

(*
         if cs_opt_regvar in current_settings.optimizerswitches then
           begin
             org_regvar_loaded_int := rg.regvar_loaded_int;
             org_regvar_loaded_other := rg.regvar_loaded_other;
           end;
*)
         if Assigned(right) then
           begin
              hlcg.a_label(CurrentAsmData.CurrAsmList,left.location.truelabel);
              SecondPass(right);
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
              if Assigned(right) then
                begin
                   CurrentAsmData.getjumplabel(hl);
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
                   hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,hl);
                   if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
                     CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.alignment.JumpAlign,CurrentSettings.alignment.JumpAlignSkipMax));
                end;
              hlcg.a_label(CurrentAsmData.CurrAsmList,left.location.falselabel);
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
              if Assigned(right) then
                hlcg.a_label(CurrentAsmData.CurrAsmList,hl);
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
                CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.alignment.CoalesceAlign,CurrentSettings.alignment.CoalesceAlignSkipMax));
              hlcg.a_label(CurrentAsmData.CurrAsmList,left.location.falselabel);
           end;
         if not(Assigned(right)) then
           begin
             if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
               CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.alignment.CoalesceAlign,CurrentSettings.alignment.CoalesceAlignSkipMax));
             hlcg.a_label(CurrentAsmData.CurrAsmList,left.location.truelabel);
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

         flowcontrol := oldflowcontrol + (flowcontrol - [fc_inflowcontrol]);
      end;


{*****************************************************************************
                              SecondFor
*****************************************************************************}

    procedure TCGForNode.pass_generate_code;
      begin
        { for nodes are converted in pass_1 in a while loop }
        InternalError(2015082501);
      end;


{*****************************************************************************
                              SecondExitN
*****************************************************************************}

    procedure TCGExitNode.pass_generate_code;
      begin
         location_reset(location,LOC_VOID,OS_NO);

         if fc_no_direct_exit in flowcontrol then
           include(flowcontrol,fc_gotolabel);
         include(flowcontrol,fc_exit);
         if Assigned(left) then
           SecondPass(left);

         if (fc_unwind_exit in flowcontrol) then
           hlcg.g_local_unwind(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrExitLabel)
         else
           hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrExitLabel);
         if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
           CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.alignment.JumpAlign,CurrentSettings.alignment.JumpAlignSkipMax));
       end;


{*****************************************************************************
                              SecondBreakN
*****************************************************************************}

    procedure TCGBreakNode.pass_generate_code;
      begin
         location_reset(location,LOC_VOID,OS_NO);

         include(flowcontrol,fc_break);
         if CurrentProcInfo.CurrBreakLabel<>nil then
           begin
             if (fc_unwind_loop in flowcontrol) then
               hlcg.g_local_unwind(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrBreakLabel)
             else
               hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrBreakLabel);
             if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
               CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.alignment.JumpAlign,CurrentSettings.alignment.JumpAlignSkipMax));
           end
         else
           CGMessage(cg_e_break_not_allowed);
      end;


{*****************************************************************************
                              SecondContinueN
*****************************************************************************}

    procedure TCGContinueNode.pass_generate_code;
      begin
         location_reset(location,LOC_VOID,OS_NO);

         include(flowcontrol,fc_continue);
         if CurrentProcInfo.CurrContinueLabel<>nil then
           begin
             if (fc_unwind_loop in flowcontrol) then
               hlcg.g_local_unwind(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrContinueLabel)
             else
               hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrContinueLabel);
             if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
               CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.alignment.JumpAlign,CurrentSettings.alignment.JumpAlignSkipMax));
           end
         else
           CGMessage(cg_e_continue_not_allowed);
      end;


{*****************************************************************************
                             SecondGoto
*****************************************************************************}

    procedure TCGGotoNode.pass_generate_code;

       begin
         location_reset(location,LOC_VOID,OS_NO);

         include(flowcontrol,fc_gotolabel);
         hlcg.a_jmp_always_pascal_goto(CurrentAsmData.CurrAsmList,TCGLabelNode(labelnode).getasmlabel);
         if not(cs_opt_size in CurrentSettings.OptimizerSwitches) then
           CurrentAsmData.CurrAsmList.concat(CAIAlign.create_max(CurrentSettings.alignment.JumpAlign,CurrentSettings.alignment.JumpAlignSkipMax));
       end;


{*****************************************************************************
                             SecondLabel
*****************************************************************************}

    function TCGLabelNode.getasmlabel : TAsmLabel;
      begin
        if not(Assigned(asmlabel)) then
          { labsym is not set in inlined procedures, but since assembler }
          { routines can't be inlined, that shouldn't matter             }
          if Assigned(labsym) and
             labsym.nonlocal then
            CurrentAsmData.getglobaljumplabel(asmlabel)
          else
            CurrentAsmData.getjumplabel(asmlabel);
        result:=asmlabel
      end;


    procedure TCGLabelNode.pass_generate_code;
      begin
         location_reset(location,LOC_VOID,OS_NO);
         if not (nf_internal in flags) then
           include(flowcontrol,fc_gotolabel);
         hlcg.a_label_pascal_goto_target(CurrentAsmData.CurrAsmList,getasmlabel);

         { Write also extra label if this label was referenced from
           assembler block }
         if Assigned(labsym) and
            Assigned(labsym.AsmBlockLabel) then
           hlcg.a_label(CurrentAsmData.CurrAsmList,labsym.AsmBlockLabel);
      end;


{*****************************************************************************
                             SecondTryExcept
*****************************************************************************}

    var
       endexceptlabel : TAsmLabel;

     { jump out of an try/except block }
     procedure TCGTryExceptNode.emit_jump_out_of_try_except_frame(list: TAsmList; frametype: TFrameType; const exceptiontate: TCGExceptionStateHandler.TExceptionState; var excepttemps: TCGExceptionStateHandler.TExceptionTemps; framelabel, outerlabel: TAsmLabel);
       begin
          hlcg.a_label(list,framelabel);
          { we must also destroy the address frame which guards
            the exception object }
          cexceptionstatehandler.popaddrstack(list);
          hlcg.g_exception_reason_discard(list,ExceptionReasonType,excepttemps.reasonbuf);
          if frametype=ft_except then
            begin
              cexceptionstatehandler.cleanupobjectstack(list);
              cexceptionstatehandler.end_catch(list);
            end;
          hlcg.a_jmp_always(list,outerlabel);
       end;


    procedure TCGTryExceptNode.pass_generate_code;

      var
         oldendexceptlabel,
         lastonlabel,
         exitexceptlabel,
         continueexceptlabel,
         breakexceptlabel,
         exittrylabel,
         continuetrylabel,
         breaktrylabel,
         oldCurrExitLabel,
         oldContinueLabel,
         oldBreakLabel : TAsmLabel;
         destroytemps,
         excepttemps : TCGExceptionStateHandler.TExceptionTemps;
         trystate,doobjectdestroyandreraisestate: TCGExceptionStateHandler.TExceptionState;
         afteronflowcontrol: TFlowControl;
      label
         errorexit;
      begin
         location_reset(location,LOC_VOID,OS_NO);
         continuetrylabel:=nil;
         breaktrylabel:=nil;
         continueexceptlabel:=nil;
         breakexceptlabel:=nil;
         doobjectdestroyandreraisestate:=Default(TCGExceptionStateHandler.TExceptionState);

         { this can be called recursively }
         oldBreakLabel:=nil;
         oldContinueLabel:=nil;
         oldendexceptlabel:=endexceptlabel;

         { save the old labels for control flow statements }
         oldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
         if Assigned(CurrentProcInfo.CurrBreakLabel) then
           begin
              oldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
              oldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
           end;

         { get new labels for the control flow statements }
         CurrentAsmData.getjumplabel(exittrylabel);
         CurrentAsmData.getjumplabel(exitexceptlabel);
         if Assigned(CurrentProcInfo.CurrBreakLabel) then
           begin
              CurrentAsmData.getjumplabel(breaktrylabel);
              CurrentAsmData.getjumplabel(continuetrylabel);
              CurrentAsmData.getjumplabel(breakexceptlabel);
              CurrentAsmData.getjumplabel(continueexceptlabel);
           end;

         CurrentAsmData.getjumplabel(endexceptlabel);
         CurrentAsmData.getjumplabel(lastonlabel);

         cexceptionstatehandler.get_exception_temps(CurrentAsmData.CurrAsmList,excepttemps);
         cexceptionstatehandler.new_exception(CurrentAsmData.CurrAsmList,excepttemps,tek_except,trystate);

         { try block }
         { set control flow labels for the try block }
         CurrentProcInfo.CurrExitLabel:=exittrylabel;
         if Assigned(oldBreakLabel) then
          begin
            CurrentProcInfo.CurrContinueLabel:=continuetrylabel;
            CurrentProcInfo.CurrBreakLabel:=breaktrylabel;
          end;

         SecondPass(left);
         if CodeGenError then
           goto errorexit;

         { don't generate line info for internal cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoStart));

         cexceptionstatehandler.end_try_block(CurrentAsmData.CurrAsmList,tek_except,excepttemps,trystate,endexceptlabel);

         cexceptionstatehandler.emit_except_label(CurrentAsmData.CurrAsmList,tek_except,trystate,excepttemps);
         cexceptionstatehandler.free_exception(CurrentAsmData.CurrAsmList, excepttemps, trystate, 0, endexceptlabel, false);

         { end cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoEnd));

         { set control flow labels for the except block }
         { and the on statements                        }
         CurrentProcInfo.CurrExitLabel:=exitexceptlabel;
         if Assigned(oldBreakLabel) then
          begin
            CurrentProcInfo.CurrContinueLabel:=continueexceptlabel;
            CurrentProcInfo.CurrBreakLabel:=breakexceptlabel;
          end;

         flowcontrol:=[fc_inflowcontrol]+trystate.oldflowcontrol*[fc_catching_exceptions];
         { on statements }
         if Assigned(right) then
           SecondPass(right);

         afteronflowcontrol:=flowcontrol;

         { don't generate line info for internal cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoStart));

         hlcg.a_label(CurrentAsmData.CurrAsmList,lastonlabel);
         { default handling except handling }
         if Assigned(t1) then
           begin
              { FPC_CATCHES with 'default handler' flag (=-1) need no longer be called,
                it doesn't change any state and its return value is ignored (Sergei)
              }

              { the destruction of the exception object must be also }
              { guarded by an exception frame, but it can be omitted }
              { if there's no user code in 'except' block            }

              cexceptionstatehandler.catch_all_start(CurrentAsmData.CurrAsmList);
              if not (has_no_code(t1)) then
               begin
                 { if there is an outer frame that catches exceptions, remember this for the "except"
                   part of this try/except }
                 flowcontrol:=trystate.oldflowcontrol*[fc_inflowcontrol,fc_catching_exceptions];
                 cexceptionstatehandler.get_exception_temps(CurrentAsmData.CurrAsmList,destroytemps);
                 cexceptionstatehandler.new_exception(CurrentAsmData.CurrAsmList,destroytemps,tek_except,doobjectdestroyandreraisestate);
                 cexceptionstatehandler.catch_all_add(CurrentAsmData.CurrAsmList);
                 { the flowcontrol from the default except-block must be merged
                   with the flowcontrol flags potentially set by the
                   on-statements handled above (secondpass(right)), as they are
                   at the same program level }
                 flowcontrol:=
                   flowcontrol+
                   afteronflowcontrol;

                 { except block needs line info }
                 CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoEnd));

                 SecondPass(t1);

                 cexceptionstatehandler.handle_nested_exception(CurrentAsmData.CurrAsmList,destroytemps,doobjectdestroyandreraisestate);

                 cexceptionstatehandler.unget_exception_temps(CurrentAsmData.CurrAsmList,destroytemps);
                 cexceptionstatehandler.catch_all_end(CurrentAsmData.CurrAsmList);
                 hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,endexceptlabel);
               end
             else
               begin
                 doobjectdestroyandreraisestate.newflowcontrol:=afteronflowcontrol;
                 cexceptionstatehandler.cleanupobjectstack(CurrentAsmData.CurrAsmList);
                 cexceptionstatehandler.catch_all_end(CurrentAsmData.CurrAsmList);
                 hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,endexceptlabel);
               end;
           end
         else
           begin
             cexceptionstatehandler.handle_reraise(CurrentAsmData.CurrAsmList,excepttemps,trystate,tek_except);
             doobjectdestroyandreraisestate.newflowcontrol:=afteronflowcontrol;
           end;

         if fc_exit in doobjectdestroyandreraisestate.newflowcontrol then
           emit_jump_out_of_try_except_frame(CurrentAsmData.CurrAsmList,ft_except,doobjectdestroyandreraisestate,excepttemps,exitexceptlabel,oldCurrExitLabel);

         if fc_break in doobjectdestroyandreraisestate.newflowcontrol then
           emit_jump_out_of_try_except_frame(CurrentAsmData.CurrAsmList,ft_except,doobjectdestroyandreraisestate,excepttemps,breakexceptlabel,oldBreakLabel);

         if fc_continue in doobjectdestroyandreraisestate.newflowcontrol then
           emit_jump_out_of_try_except_frame(CurrentAsmData.CurrAsmList,ft_except,doobjectdestroyandreraisestate,excepttemps,continueexceptlabel,oldContinueLabel);

         if fc_exit in trystate.newflowcontrol then
           emit_jump_out_of_try_except_frame(CurrentAsmData.CurrAsmList,ft_try,trystate,excepttemps,exittrylabel,oldCurrExitLabel);

         if fc_break in trystate.newflowcontrol then
          emit_jump_out_of_try_except_frame(CurrentAsmData.CurrAsmList,ft_try,trystate,excepttemps,breaktrylabel,oldBreakLabel);

         if fc_continue in trystate.newflowcontrol then
           emit_jump_out_of_try_except_frame(CurrentAsmData.CurrAsmList,ft_try,trystate,excepttemps,continuetrylabel,oldContinueLabel);

         cexceptionstatehandler.unget_exception_temps(CurrentAsmData.CurrAsmList,excepttemps);
         hlcg.a_label(CurrentAsmData.CurrAsmList,endexceptlabel);

         { end cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoEnd));

       errorexit:
         { restore all saved labels }
         endexceptlabel:=oldendexceptlabel;

         { restore the control flow labels }
         CurrentProcInfo.CurrExitLabel:=oldCurrExitLabel;
         if Assigned(oldBreakLabel) then
          begin
            CurrentProcInfo.CurrContinueLabel:=oldContinueLabel;
            CurrentProcInfo.CurrBreakLabel:=oldBreakLabel;
          end;

         { return all used control flow statements }
         flowcontrol:=trystate.oldflowcontrol+(doobjectdestroyandreraisestate.newflowcontrol +
           trystate.newflowcontrol - [fc_inflowcontrol,fc_catching_exceptions]);
      end;


    procedure TCGOnNode.pass_generate_code;
      var
         nextonlabel,
         exitonlabel,
         continueonlabel,
         breakonlabel,
         oldCurrExitLabel,
         oldContinueLabel,
         oldBreakLabel : TAsmLabel;
         doobjectdestroyandreraisestate: TCGExceptionStateHandler.TExceptionState;
         excepttemps : TCGExceptionStateHandler.TExceptionTemps;
         exceptvarsym : TLocalVarSym;
         exceptlocdef: TDef;
         exceptlocreg: TRegister;
      begin
         location_reset(location,LOC_VOID,OS_NO);
         oldCurrExitLabel:=nil;
         continueonlabel:=nil;
         breakonlabel:=nil;
         exitonlabel:=nil;

         CurrentAsmData.getjumplabel(nextonlabel);

         cexceptionstatehandler.begin_catch(CurrentAsmData.CurrAsmList,excepttype,nextonlabel,exceptlocdef,exceptlocreg);

         { Retrieve exception variable }
         if Assigned(excepTSymtable) then
           exceptvarsym:=TLocalVarSym(excepTSymtable.SymList[0])
         else
           InternalError(2011020401);

         if Assigned(exceptvarsym) then
           begin
             location_reset_ref(exceptvarsym.LocAlloc, LOC_REFERENCE, def_cgsize(VoidPointerType), VoidPointerType.alignment, []);
             tg.GetLocal(CurrentAsmData.CurrAsmList, exceptvarsym.vardef.size, VoidPointerType.alignment, 0, exceptvarsym.vardef, exceptvarsym, exceptvarsym.LocAlloc.reference);
             hlcg.a_load_reg_ref(CurrentAsmData.CurrAsmList, exceptlocdef, exceptvarsym.vardef, exceptlocreg, exceptvarsym.LocAlloc.reference);
           end;
         { in the case that another exception is risen
           we've to destroy the old one, so create a new
           exception frame for the catch-handler }
         cexceptionstatehandler.get_exception_temps(CurrentAsmData.CurrAsmList,excepttemps);
         cexceptionstatehandler.new_exception(CurrentAsmData.CurrAsmList,excepttemps,tek_except,doobjectdestroyandreraisestate);

         oldBreakLabel:=nil;
         oldContinueLabel:=nil;
         if Assigned(right) then
           begin
              oldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
              CurrentAsmData.getjumplabel(exitonlabel);
              CurrentProcInfo.CurrExitLabel:=exitonlabel;
              if Assigned(CurrentProcInfo.CurrBreakLabel) then
               begin
                 oldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
                 oldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
                 CurrentAsmData.getjumplabel(breakonlabel);
                 CurrentAsmData.getjumplabel(continueonlabel);
                 CurrentProcInfo.CurrContinueLabel:=continueonlabel;
                 CurrentProcInfo.CurrBreakLabel:=breakonlabel;
               end;

              SecondPass(right);
           end;

         cexceptionstatehandler.handle_nested_exception(CurrentAsmData.CurrAsmList,excepttemps,doobjectdestroyandreraisestate);

         { clear some stuff }
         if Assigned(exceptvarsym) then
           begin
             tg.UngetLocal(CurrentAsmData.CurrAsmList,exceptvarsym.LocAlloc.reference);
             exceptvarsym.LocAlloc.loc:=LOC_INVALID;
           end;
         cexceptionstatehandler.end_catch(CurrentAsmData.CurrAsmList);
         hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,endexceptlabel);

         if Assigned(right) then
           begin
              { special handling for control flow instructions }
              if fc_exit in doobjectdestroyandreraisestate.newflowcontrol then
                begin
                   { the address and object pop does secondtryexcept }
                   hlcg.a_label(CurrentAsmData.CurrAsmList,exitonlabel);
                   hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,oldCurrExitLabel);
                end;

              if fc_break in doobjectdestroyandreraisestate.newflowcontrol then
                begin
                   { the address and object pop does secondtryexcept }
                   hlcg.a_label(CurrentAsmData.CurrAsmList,breakonlabel);
                   hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,oldBreakLabel);
                end;

              if fc_continue in doobjectdestroyandreraisestate.newflowcontrol then
                begin
                   { the address and object pop does secondtryexcept }
                   hlcg.a_label(CurrentAsmData.CurrAsmList,continueonlabel);
                   hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,oldContinueLabel);
                end;

              CurrentProcInfo.CurrExitLabel:=oldCurrExitLabel;
              if Assigned(oldBreakLabel) then
               begin
                 CurrentProcInfo.CurrContinueLabel:=oldContinueLabel;
                 CurrentProcInfo.CurrBreakLabel:=oldBreakLabel;
               end;
           end;

         cexceptionstatehandler.unget_exception_temps(CurrentAsmData.CurrAsmList,excepttemps);
         hlcg.a_label(CurrentAsmData.CurrAsmList,nextonlabel);
         CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoEnd));

         { propagate exit/break/continue }
         flowcontrol:=doobjectdestroyandreraisestate.oldflowcontrol+(doobjectdestroyandreraisestate.newflowcontrol-[fc_inflowcontrol,fc_catching_exceptions]);

         { next on node }
         if Assigned(left) then
           SecondPass(left);
      end;

{*****************************************************************************
                             SecondTryFinally
*****************************************************************************}

    { jump out of a finally block }
    procedure TCGTryFinallyNode.emit_jump_out_of_try_finally_frame(list: TAsmList; const reason: byte; const finallycodelabel: TAsmLabel; var excepttemps: TCGExceptionStateHandler.TExceptionTemps; framelabel: TAsmLabel);
      begin
         hlcg.a_label(list,framelabel);
         hlcg.g_exception_reason_discard(list,ExceptionReasonType,excepttemps.reasonbuf);
         hlcg.g_exception_reason_save_const(list,ExceptionReasonType,reason,excepttemps.reasonbuf);
         hlcg.a_jmp_always(list,finallycodelabel);
      end;


    function TCGTryFinallyNode.get_jump_out_of_try_finally_frame_label(const finallyexceptionstate: TCGExceptionStateHandler.TExceptionState): TAsmLabel;
      begin
        CurrentAsmData.getjumplabel(result);
      end;


    procedure TCGTryFinallyNode.handle_safecall_exception;
      var
        cgpara, resultpara: TCGPara;
        selfsym: TParaVarSym;
        pd: TProcDef;
        safecallresult: TLocalVarSym;
      begin
        { call fpc_safecallhandler, passing self for methods of classes,
          nil otherwise. }
        pd:=Search_System_Proc('fpc_safecallhandler');
        cgpara.init;
        paramanager.getcgtempparaloc(CurrentAsmData.CurrAsmList,pd,1,cgpara);
        if Is_Class(CurrentProcInfo.procdef.struct) then
          begin
            selfsym:=TParaVarSym(CurrentProcInfo.procdef.ParaST.Find('self'));
            if (selfsym=nil) or (selfsym.typ<>paravarsym) then
              InternalError(2011123101);
            hlcg.a_load_loc_cgpara(CurrentAsmData.CurrAsmList,selfsym.vardef,selfsym.LocAlloc,cgpara);
          end
        else
          hlcg.a_load_const_cgpara(CurrentAsmData.CurrAsmList,VoidPointerType,0,cgpara);
        paramanager.freecgpara(CurrentAsmData.CurrAsmList,cgpara);
        resultpara:=hlcg.g_call_system_proc(CurrentAsmData.CurrAsmList,pd,[@cgpara],nil);
        cgpara.done;
        safecallresult:=TLocalVarSym(CurrentProcInfo.procdef.LocalST.Find('safecallresult'));
        hlcg.gen_load_cgpara_loc(CurrentAsmData.CurrAsmList,resultpara.def,resultpara,safecallresult.LocAlloc,false);
        resultpara.resetiftemp;
      end;


    procedure TCGTryFinallyNode.pass_generate_code;
      var
         endfinallylabel,
         exitfinallylabel,
         continuefinallylabel,
         breakfinallylabel,
         oldCurrExitLabel,
         oldContinueLabel,
         oldBreakLabel,
         finallyNoExceptionLabel: TAsmLabel;
         finallyexceptionstate: TCGExceptionStateHandler.TExceptionState;
         excepttemps : TCGExceptionStateHandler.TExceptionTemps;
         reasonreg : TRegister;
         exceptframekind: TCGExceptionStateHandler.TExceptFrameKind;
         tmplist: TAsmList;

        procedure handle_breakcontinueexit(const finallycode: TAsmLabel; doreraise: boolean);
          begin
            { no exception happened, but maybe break/continue/exit }
            hlcg.a_cmp_const_reg_label(CurrentAsmData.CurrAsmList,ExceptionReasonType,OC_EQ,0,reasonreg,endfinallylabel);
            if fc_exit in finallyexceptionstate.newflowcontrol then
              hlcg.a_cmp_const_reg_label(CurrentAsmData.CurrAsmList,ExceptionReasonType,OC_EQ,2,reasonreg,oldCurrExitLabel);
            if fc_break in finallyexceptionstate.newflowcontrol then
              hlcg.a_cmp_const_reg_label(CurrentAsmData.CurrAsmList,ExceptionReasonType,OC_EQ,3,reasonreg,oldBreakLabel);
            if fc_continue in finallyexceptionstate.newflowcontrol then
              hlcg.a_cmp_const_reg_label(CurrentAsmData.CurrAsmList,ExceptionReasonType,OC_EQ,4,reasonreg,oldContinueLabel);
            if doreraise then
              cexceptionstatehandler.handle_reraise(CurrentAsmData.CurrAsmList,excepttemps,finallyexceptionstate,tek_normalfinally)
            else
              hlcg.g_unreachable(CurrentAsmData.CurrAsmList);
            { redirect break/continue/exit to the label above, with the reasonbuf set appropriately }
            if fc_exit in finallyexceptionstate.newflowcontrol then
              emit_jump_out_of_try_finally_frame(CurrentAsmData.CurrAsmList,2,finallycode,excepttemps,exitfinallylabel);
            if fc_break in finallyexceptionstate.newflowcontrol then
              emit_jump_out_of_try_finally_frame(CurrentAsmData.CurrAsmList,3,finallycode,excepttemps,breakfinallylabel);
            if fc_continue in finallyexceptionstate.newflowcontrol then
              emit_jump_out_of_try_finally_frame(CurrentAsmData.CurrAsmList,4,finallycode,excepttemps,continuefinallylabel);
          end;

      begin
         location_reset(location,LOC_VOID,OS_NO);
         oldBreakLabel:=nil;
         oldContinueLabel:=nil;
         continuefinallylabel:=nil;
         breakfinallylabel:=nil;

         if not implicitframe then
           exceptframekind:=tek_normalfinally
         else
           exceptframekind:=tek_implicitfinally;

         CurrentAsmData.getjumplabel(endfinallylabel);

         { call setjmp, and jump to finally label on non-zero result }
         cexceptionstatehandler.get_exception_temps(CurrentAsmData.CurrAsmList,excepttemps);
         cexceptionstatehandler.new_exception(CurrentAsmData.CurrAsmList,excepttemps,exceptframekind,finallyexceptionstate);

         { the finally block must catch break, continue and exit }
         { statements                                            }
         oldCurrExitLabel:=CurrentProcInfo.CurrExitLabel;
         exitfinallylabel:=get_jump_out_of_try_finally_frame_label(finallyexceptionstate);
         CurrentProcInfo.CurrExitLabel:=exitfinallylabel;
         if Assigned(CurrentProcInfo.CurrBreakLabel) then
          begin
            oldContinueLabel:=CurrentProcInfo.CurrContinueLabel;
            oldBreakLabel:=CurrentProcInfo.CurrBreakLabel;
            breakfinallylabel:=get_jump_out_of_try_finally_frame_label(finallyexceptionstate);
            continuefinallylabel:=get_jump_out_of_try_finally_frame_label(finallyexceptionstate);
            CurrentProcInfo.CurrContinueLabel:=continuefinallylabel;
            CurrentProcInfo.CurrBreakLabel:=breakfinallylabel;
          end;

         { try code }
         if Assigned(left) then
           begin
              SecondPass(left);
              if CodeGenError then
                exit;
           end;

         { don't generate line info for internal cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoStart));

         cexceptionstatehandler.end_try_block(CurrentAsmData.CurrAsmList,exceptframekind,excepttemps,finallyexceptionstate,finallyexceptionstate.finallycodelabel);
         if Assigned(third) then
           begin
             tmplist:=TAsmList.create;
             { emit the except label already (to a temporary list) to ensure that any calls in the
               finally block refer to the outer exception frame rather than to the exception frame
               that emits this same finally code in case an exception does happen }
             cexceptionstatehandler.emit_except_label(tmplist,exceptframekind,finallyexceptionstate,excepttemps);

             flowcontrol:=finallyexceptionstate.oldflowcontrol*[fc_inflowcontrol,fc_catching_exceptions];
             CurrentAsmData.getjumplabel(finallyNoExceptionLabel);
             hlcg.a_label(CurrentAsmData.CurrAsmList,finallyNoExceptionLabel);
             if not implicitframe then
               CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoEnd));
             SecondPass(third);
             if CodeGenError then
               exit;
             if not implicitframe then
               CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoStart));
             reasonreg:=hlcg.getintregister(CurrentAsmData.CurrAsmList,ExceptionReasonType);
             hlcg.g_exception_reason_load(CurrentAsmData.CurrAsmList,ExceptionReasonType,ExceptionReasonType,excepttemps.reasonbuf,reasonreg);
             handle_breakcontinueexit(finallyNoExceptionLabel,false);

             CurrentAsmData.CurrAsmList.ConcatList(tmplist);
             tmplist.free;
             tmplist := nil;
           end
         else
           cexceptionstatehandler.emit_except_label(CurrentAsmData.CurrAsmList,exceptframekind,finallyexceptionstate,excepttemps);

         { just free the frame information }
         cexceptionstatehandler.free_exception(CurrentAsmData.CurrAsmList,excepttemps,finallyexceptionstate,1,finallyexceptionstate.exceptionlabel,true);

         { end cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoEnd));

         { finally code (don't unconditionally set fc_inflowcontrol, since the
           finally code is unconditionally executed; we do have to filter out
           flags regarding break/contrinue/etc. because we have to give an
           error in case one of those is used in the finally-code }
         flowcontrol:=finallyexceptionstate.oldflowcontrol*[fc_inflowcontrol,fc_catching_exceptions];
         SecondPass(right);
         { goto is allowed if it stays inside the finally block,
           this is checked using the exception block number }
         if (flowcontrol-[fc_gotolabel])<>(finallyexceptionstate.oldflowcontrol*[fc_inflowcontrol,fc_catching_exceptions]) then
           CGMessage(cg_e_control_flow_outside_finally);
         if CodeGenError then
           exit;

         { don't generate line info for internal cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoStart));

         { same level as before try, but this part is only executed if an exception occurred
           -> always fc_in_flowcontrol }
         flowcontrol:=finallyexceptionstate.oldflowcontrol*[fc_catching_exceptions];
         include(flowcontrol,fc_inflowcontrol);
         if not Assigned(third) then
           begin
             { the value should now be in the exception handler }
             reasonreg:=hlcg.getintregister(CurrentAsmData.CurrAsmList,ExceptionReasonType);
             hlcg.g_exception_reason_load(CurrentAsmData.CurrAsmList,ExceptionReasonType,ExceptionReasonType,excepttemps.reasonbuf,reasonreg);
             if implicitframe then
               begin
                 hlcg.a_cmp_const_reg_label(CurrentAsmData.CurrAsmList,ExceptionReasonType,OC_EQ,0,reasonreg,endfinallylabel);
                 { finally code only needed to be executed on exception (-> in
                   if-branch -> fc_inflowcontrol) }
                 if CurrentProcInfo.procdef.Generate_SafeCall_Wrapper then
                   begin
                     handle_safecall_exception;
                     { we have to jump immediately as we have to return the value of FPC_SAFECALL }
                     hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,oldCurrExitLabel);
                   end
                 else
                   cexceptionstatehandler.handle_reraise(CurrentAsmData.CurrAsmList,excepttemps,finallyexceptionstate,exceptframekind);
                 { we have to load 0 into the execepttemp, else the program thinks an exception happened }
                 emit_jump_out_of_try_finally_frame(CurrentAsmData.CurrAsmList,0,finallyexceptionstate.exceptionlabel,excepttemps,exitfinallylabel);
               end
             else
               begin
                 handle_breakcontinueexit(finallyexceptionstate.exceptionlabel,true);
               end;
           end
         else
           begin
             if implicitframe then
               begin
                 if CurrentProcInfo.procdef.Generate_SafeCall_Wrapper then
                   handle_safecall_exception
                 else
                   cexceptionstatehandler.handle_reraise(CurrentAsmData.CurrAsmList,excepttemps,finallyexceptionstate,exceptframekind);
               end
             else
               begin
                 cexceptionstatehandler.handle_reraise(CurrentAsmData.CurrAsmList,excepttemps,finallyexceptionstate,exceptframekind);
               end;

           end;
         cexceptionstatehandler.unget_exception_temps(CurrentAsmData.CurrAsmList,excepttemps);
         hlcg.a_label(CurrentAsmData.CurrAsmList,endfinallylabel);

         { end cleanup }
         CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_NoLineInfoEnd));

         CurrentProcInfo.CurrExitLabel:=oldCurrExitLabel;
         if Assigned(CurrentProcInfo.CurrBreakLabel) then
          begin
            CurrentProcInfo.CurrContinueLabel:=oldContinueLabel;
            CurrentProcInfo.CurrBreakLabel:=oldBreakLabel;
          end;
         flowcontrol:=finallyexceptionstate.oldflowcontrol+(finallyexceptionstate.newflowcontrol-[fc_inflowcontrol,fc_catching_exceptions]);
      end;


    function TCGRaiseNode.pass_1: TNode;
      begin
        if not(tf_use_psabieh in TargetInfo.flags) or Assigned(left) then
          result:=inherited
        else
          begin
            expectloc:=LOC_VOID;
            result:=nil;
          end;
      end;

{$ifndef SkipABIEH}
    { has to be factored out as well }
    procedure TCGRaiseNode.pass_generate_code;
      var
        CurrentLandingPad, CurrentAction, ReRaiseLandingPad: TPSABIEHAction;
        psabiehprocinfo: TPSABIEHProcInfo;
      begin
        if not(tf_use_psabieh in TargetInfo.flags) then
          InternalError(2019021701);

        location_reset(location,LOC_VOID,OS_NO);
        CurrentLandingPad:=nil;
        CurrentAction:=nil;
        ReRaiseLandingPad:=nil;
        psabiehprocinfo:=CurrentProcInfo as TPSABIEHProcInfo;
        { a reraise must raise the exception to the parent exception frame }
        if fc_catching_exceptions in flowcontrol then
          begin
            psabiehprocinfo.CreateNewPSABIEHCallsite(CurrentAsmData.CurrAsmList);
            CurrentLandingPad:=psabiehprocinfo.CurrentLandingPad;
            if psabiehprocinfo.PopLandingPad(CurrentLandingPad) then
              exclude(flowcontrol,fc_catching_exceptions);
            CurrentAction:=psabiehprocinfo.CurrentAction;
            psabiehprocinfo.FinalizeAndPopAction(CurrentAction);

            if not(fc_catching_exceptions in flowcontrol) then
              begin
                ReRaiseLandingPad:=psabiehprocinfo.NoAction;
                psabiehprocinfo.PushAction(ReRaiseLandingPad);
                psabiehprocinfo.PushLandingPad(ReRaiseLandingPad);
              end;
          end;
        hlcg.g_call_system_proc(CurrentAsmData.CurrAsmList,'fpc_reraise',[],nil).resetiftemp;
        if Assigned(CurrentLandingPad) then
          begin
            psabiehprocinfo.CreateNewPSABIEHCallsite(CurrentAsmData.CurrAsmList);
            if not(fc_catching_exceptions in flowcontrol) then
              begin
                psabiehprocinfo.PopLandingPad(psabiehprocinfo.CurrentLandingPad);
                psabiehprocinfo.PopAction(ReRaiseLandingPad);
              end;

            psabiehprocinfo.PushAction(CurrentAction);
            psabiehprocinfo.PushLandingPad(CurrentLandingPad);
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
   cexceptionstatehandler:=TCGExceptionStateHandler;
end.

