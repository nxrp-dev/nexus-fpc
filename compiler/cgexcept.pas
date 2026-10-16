{
    Copyright (c) 2017-2019 by Jonas Maebe, member of the
    Free Pascal Compiler development team

    Base class for exception handling support (setjump/longjump-based)

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
unit cgexcept;

{$i fpcdefs.inc}

  interface

    uses
      GlobType,
      aasmbase, AAsmData,
      symtype,symdef,
      cgbase,cgutils,pass_2;

    type
      { Utility class for exception handling state management that is used
        by tryexcept/tryfinally/on nodes (in a separate class so it can both
        be shared and overridden)

        Never instantiated. }
      TCGExceptionStateHandler = class
       type
        TExceptionTemps=record
          jmpbuf,
          envbuf,
          reasonbuf  : TReference;
          { when using dwarf based eh handling, the landing pads get the unwind info passed, it is
            stored in the given register so it can be passed to unwind_resume }
          unwind_info : TRegister;
        end;

        TExceptionState = record
          exceptionlabel: TAsmLabel;
          oldflowcontrol,
          newflowcontrol: TFlowControl;
          finallycodelabel  : TAsmLabel;
        end;

        TExceptFrameKind = (tek_except, tek_implicitfinally, tek_normalfinally);

        class procedure get_exception_temps(list:TAsmList;var t:TExceptionTemps); virtual;
        class procedure unget_exception_temps(list:TAsmList;const t:TExceptionTemps); virtual;
        class procedure new_exception(list:TAsmList;const t:TExceptionTemps; const exceptframekind: TExceptFrameKind; out exceptstate: TExceptionState); virtual;
        { start of "except/finally" block }
        class procedure emit_except_label(list: TAsmList; exceptframekind: TExceptFrameKind; var exceptstate: TExceptionState;var exceptiontemps:TExceptionTemps); virtual;
        { end of a try-block, label comes after the end of try/except or
          try/finally }
        class procedure end_try_block(list: TAsmList; exceptframekind: TExceptFrameKind; const t: TExceptionTemps; var exceptionstate: TExceptionState; endlabel: TAsmLabel); virtual;
        class procedure free_exception(list: TAsmList; const t: TExceptionTemps; const s: TExceptionState; a: aint; endexceptlabel: TAsmLabel; onlyfree:boolean); virtual;
        class procedure handle_nested_exception(list:TAsmList;var t:TExceptionTemps;var entrystate: TExceptionState); virtual;
        class procedure handle_reraise(list:TAsmList;const t:TExceptionTemps;const entrystate: TExceptionState; const exceptframekind: TExceptFrameKind); virtual;
        { start of an "on" (catch) block }
        class procedure begin_catch(list: TAsmList; excepttype: TObjectDef; nextonlabel: TAsmLabel; out exceptlocdef: TDef; out exceptlocreg: TRegister); virtual;
        { end of an "on" (catch) block }
        class procedure end_catch(list: TAsmList); virtual;
        { called for a catch all exception }
        class procedure catch_all_start(list: TAsmList); virtual;
        { called after the catch all exception has been started with new_exception }
        class procedure catch_all_add(list: TAsmList); virtual;
        class procedure catch_all_end(list: TAsmList); virtual;
        class procedure cleanupobjectstack(list: TAsmList); virtual;
        class procedure popaddrstack(list: TAsmList); virtual;
        class function use_cleanup(const exceptframekind: TExceptFrameKind): boolean;
      end;
      TCGExceptionStateHandlerClass = class of TCGExceptionStateHandler;

    var
      cexceptionstatehandler: TCGExceptionStateHandlerClass = TCGExceptionStateHandler;

  implementation

    uses
      Globals,
      Systems,
      FModule,
      aasmtai,
      symconst,SymTable,defutil,
      parabase,paramgr,
      ProcInfo,
      tgobj,
      hlcgobj;

{*****************************************************************************
                     tcgexceptionstatehandler
*****************************************************************************}

    class function TCGExceptionStateHandler.use_cleanup(const exceptframekind: TExceptFrameKind): boolean;
      begin
        { in case of an exception caught by the implicit exception frame of
          a safecall routine, this is not a cleanup frame but one that
          catches the exception and returns a value from the function }
        result:=
          (exceptframekind=tek_implicitfinally) and
          not((tf_safecall_exceptions in TargetInfo.flags) and
             (CurrentProcInfo.procdef.ProcCallOption=pocall_safecall));
      end;

    {  Allocate the buffers for exception management and setjmp environment.
       Return a pointer to these buffers, send them to the utility routine
       so they are registered, and then call setjmp.

       Then compare the result of setjmp with 0, and if not equal
       to zero, then jump to exceptlabel.

       Also store the result of setjmp to a temporary space by calling g_save_exception_reason

       It is to note that this routine may be called *after* the stackframe of a
       routine has been called, therefore on machines where the stack cannot
       be modified, all temps should be allocated on the heap instead of the
       stack. }

    class procedure TCGExceptionStateHandler.get_exception_temps(list:TAsmList;var t:TExceptionTemps);
      begin
        if not Assigned(ExceptionReasonType) then
          ExceptionReasonType:=Search_System_Proc('fpc_setjmp').ReturnDef;
        tg.GetHLTemp(list,Rec_ExceptAddr,Rec_ExceptAddr.Size,tt_persistent,t.envbuf);
        tg.GetHLTemp(list,Rec_Jmp_Buf,Rec_Jmp_Buf.Size,tt_persistent,t.jmpbuf);
        tg.GetHLTemp(list,ExceptionReasonType,ExceptionReasonType.Size,tt_persistent,t.reasonbuf);
      end;


    class procedure TCGExceptionStateHandler.unget_exception_temps(list:TAsmList;const t:TExceptionTemps);
      begin
        tg.Ungettemp(list,t.jmpbuf);
        tg.ungettemp(list,t.envbuf);
        tg.ungettemp(list,t.reasonbuf);
      end;


    class procedure TCGExceptionStateHandler.new_exception(list:TAsmList;const t:TExceptionTemps; const exceptframekind: TExceptFrameKind; out exceptstate: TExceptionState);
      var
        paraloc1, paraloc2, paraloc3, pushexceptres, setjmpres: TCGPara;
        pd: TProcDef;
        tmpresloc: TLocation;
      begin
        CurrentAsmData.getjumplabel(exceptstate.exceptionlabel);
        exceptstate.oldflowcontrol:=flowcontrol;
        exceptstate.finallycodelabel:=nil;

        paraloc1.init;
        paraloc2.init;
        paraloc3.init;

        { fpc_pushexceptaddr(exceptionframetype, setjmp_buffer, exception_address_chain_entry) }
        pd:=Search_System_Proc('fpc_pushexceptaddr');
        ParaManager.GetCGTempParaLoc(list,pd,1,paraloc1);
        ParaManager.GetCGTempParaLoc(list,pd,2,paraloc2);
        ParaManager.GetCGTempParaLoc(list,pd,3,paraloc3);
        if pd.Is_PushLeftRight then
          begin
            { type of exceptionframe }
            hlcg.A_Load_Const_CGPara(list,paraloc1.def,1,paraloc1);
            { setjmp buffer }
            hlcg.A_LoadAddr_Ref_CGPara(list,Rec_Jmp_Buf,t.jmpbuf,paraloc2);
            { exception address chain entry }
            hlcg.A_LoadAddr_Ref_CGPara(list,Rec_ExceptAddr,t.envbuf,paraloc3);
          end
        else
          begin
            hlcg.A_LoadAddr_Ref_CGPara(list,Rec_ExceptAddr,t.envbuf,paraloc3);
            hlcg.A_LoadAddr_Ref_CGPara(list,Rec_Jmp_Buf,t.jmpbuf,paraloc2);
            hlcg.A_Load_Const_CGPara(list,paraloc1.def,1,paraloc1);
          end;
        ParaManager.FreeCGPara(list,paraloc3);
        ParaManager.FreeCGPara(list,paraloc2);
        ParaManager.FreeCGPara(list,paraloc1);
        { perform the fpc_pushexceptaddr call }
        pushexceptres:=hlcg.G_Call_System_Proc(list,pd,[@paraloc1,@paraloc2,@paraloc3],nil);
        paraloc1.done;
        paraloc2.done;
        paraloc3.done;

        { get the result }
        Location_Reset(tmpresloc,LOC_REGISTER,Def_CGSize(pushexceptres.def));
        tmpresloc.Register:=hlcg.GetAddressRegister(list,pushexceptres.def);
        hlcg.Gen_Load_CGPara_Loc(list,pushexceptres.def,pushexceptres,tmpresloc,true);
        pushexceptres.ResetIfTemp;

        { fpc_setjmp(result_of_pushexceptaddr_call) }
        pd:=Search_System_Proc('fpc_setjmp');
        ParaManager.GetCGTempParaLoc(list,pd,1,paraloc1);

        hlcg.A_Load_Reg_CGPara(list,pushexceptres.def,tmpresloc.Register,paraloc1);
        ParaManager.FreeCGPara(list,paraloc1);
        { perform the fpc_setjmp call }
        setjmpres:=hlcg.G_Call_System_Proc(list,pd,[@paraloc1],nil);
        paraloc1.done;
        Location_Reset(tmpresloc,LOC_REGISTER,Def_CGSize(setjmpres.def));
        tmpresloc.Register:=hlcg.GetIntRegister(list,setjmpres.def);
        hlcg.Gen_Load_CGPara_Loc(list,setjmpres.def,setjmpres,tmpresloc,true);
        hlcg.G_Exception_Reason_Save(list,setjmpres.def,ExceptionReasonType,tmpresloc.Register,t.reasonbuf);
        { if we get 1 here in the function result register, it means that we
          longjmp'd back here }
        hlcg.A_Cmp_Const_Reg_Label(list,setjmpres.def,OC_NE,0,tmpresloc.Register,exceptstate.exceptionlabel);
        setjmpres.ResetIfTemp;

        flowcontrol:=[fc_inflowcontrol,fc_catching_exceptions];
     end;


    class procedure TCGExceptionStateHandler.emit_except_label(list: TAsmList; exceptframekind: TExceptFrameKind; var exceptstate: TExceptionState;var exceptiontemps:TExceptionTemps);
      begin
        hlcg.A_Label(list,exceptstate.exceptionlabel);
      end;


    class procedure TCGExceptionStateHandler.end_try_block(list: TAsmList; exceptframekind: TExceptFrameKind; const t: TExceptionTemps; var exceptionstate: TExceptionState; endlabel: TAsmLabel);
      begin
         exceptionstate.newflowcontrol:=flowcontrol;
         flowcontrol:=exceptionstate.oldflowcontrol;
      end;


    class procedure TCGExceptionStateHandler.free_exception(list: TAsmList; const t: TExceptionTemps; const s: TExceptionState; a: aint; endexceptlabel: TAsmLabel; onlyfree: boolean);
      var
        reasonreg: TRegister;
      begin
         popaddrstack(list);
         if not onlyfree then
          begin
            reasonreg:=hlcg.GetIntRegister(list,ExceptionReasonType);
            hlcg.G_Exception_Reason_Load(list,ExceptionReasonType,ExceptionReasonType,t.reasonbuf,reasonreg);
            hlcg.A_Cmp_Const_Reg_Label(list,ExceptionReasonType,OC_EQ,a,reasonreg,endexceptlabel);
          end;
      end;


    { does the necessary things to clean up the object stack }
    { in the except block                                    }
    class procedure TCGExceptionStateHandler.cleanupobjectstack(list: TAsmList);
      begin
         hlcg.G_Call_System_Proc(list,'fpc_doneexception',[],nil).ResetIfTemp;
      end;


    { generates code to be executed when another exeception is raised while
      control is inside except block }
    class procedure TCGExceptionStateHandler.handle_nested_exception(list:TAsmList;var t:TExceptionTemps;var entrystate: TExceptionState);
      var
         exitlabel: TAsmLabel;
      begin
         CurrentAsmData.getjumplabel(exitlabel);
         { add an catch all action clause, at least psabieh needs this }
         catch_all_add(list);
         end_try_block(list,tek_except,t,entrystate,exitlabel);
         emit_except_label(list,tek_except,entrystate,t);
         { don't generate line info for internal cleanup }
         list.concat(TAIMarker.create(mark_NoLineInfoStart));
         free_exception(list,t,entrystate,0,exitlabel,false);
         { we don't need to save/restore registers here because reraise never }
         { returns                                                            }
         hlcg.G_Call_System_Proc(list,'fpc_raise_nested',[],nil).ResetIfTemp;
         hlcg.A_Label(list,exitlabel);
         cleanupobjectstack(list);
      end;


    class procedure TCGExceptionStateHandler.handle_reraise(list: TAsmList; const t: TExceptionTemps; const entrystate: TExceptionState; const exceptframekind: TExceptFrameKind);
      begin
        hlcg.G_Call_System_Proc(list,'fpc_reraise',[],nil).ResetIfTemp;
      end;


    class procedure TCGExceptionStateHandler.begin_catch(list: TAsmList; excepttype: TObjectDef; nextonlabel: TAsmLabel; out exceptlocdef: TDef; out exceptlocreg: TRegister);
      var
        pd: TProcDef;
        href2: TReference;
        fpc_catches_res,
        paraloc1: TCGPara;
        exceptloc: TLocation;
        indirect: boolean;
        otherunit: boolean;
      begin
        paraloc1.init;
        otherunit:=FindUnitSymTable(excepttype.owner).ModuleID<>FindUnitSymTable(CurrentProcInfo.procdef.owner).ModuleID;
        indirect:=(tf_supports_packages in TargetInfo.flags) and
                    (TargetInfo.system in systems_indirect_var_imports) and
                    otherunit;

        { send the vmt parameter }
        pd:=Search_System_Proc('fpc_catches');
        Reference_Reset_Symbol(href2, CurrentAsmData.RefAsmSymbol(excepttype.VMT_MangledName, AT_DATA, indirect), 0, sizeof(PInt), []);
        if otherunit then
          CurrentModule.Add_Extern_AsmSym(excepttype.VMT_MangledName, AB_EXTERNAL, AT_DATA);
        ParaManager.GetCGTempParaLoc(list, pd, 1, paraloc1);
        hlcg.A_LoadAddr_Ref_CGPara(list, excepttype.VMT_Def, href2, paraloc1);
        ParaManager.FreeCGPara(list, paraloc1);
        fpc_catches_res:=hlcg.G_Call_System_Proc(list, pd, [@paraloc1], nil);
        Location_Reset(exceptloc, LOC_REGISTER, Def_CGSize(fpc_catches_res.def));
        exceptloc.Register:=hlcg.GetAddressRegister(list, fpc_catches_res.def);
        hlcg.Gen_Load_CGPara_Loc(list, fpc_catches_res.def, fpc_catches_res, exceptloc, true);

        { is it this catch? No. go to next onlabel }
        hlcg.A_Cmp_Const_Reg_Label(list, fpc_catches_res.def, OC_EQ, 0, exceptloc.Register, nextonlabel);

        paraloc1.done;

        exceptlocdef:=fpc_catches_res.def;
        exceptlocreg:=exceptloc.Register;
      end;


    class procedure TCGExceptionStateHandler.end_catch(list: TAsmList);
      begin
        { nothing to do by default }
      end;


    class procedure TCGExceptionStateHandler.catch_all_start(list: TAsmList);
      begin
        { nothing to do by default }
      end;


    class procedure TCGExceptionStateHandler.catch_all_add(list: TAsmList);
      begin
        { nothing to do by default }
      end;


    class procedure TCGExceptionStateHandler.catch_all_end(list: TAsmList);
      begin
        { nothing to do by default }
      end;

    class procedure TCGExceptionStateHandler.popaddrstack(list: TAsmList);
      begin
        hlcg.G_Call_System_Proc(list,'fpc_popaddrstack',[],nil).ResetIfTemp;
      end;


end.

