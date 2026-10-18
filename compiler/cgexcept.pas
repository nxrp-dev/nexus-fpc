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
          JmpBuf,
          EnvBuf,
          ReasonBuf  : TReference;
          { when using dwarf based eh handling, the landing pads get the unwind info passed, it is
            stored in the given register so it can be passed to unwind_resume }
          UnwindInfo : TRegister;
        end;

        TExceptionState = record
          ExceptionLabel: TAsmLabel;
          OldFlowControl,
          NewFlowControl: TFlowControl;
          FinallyCodeLabel  : TAsmLabel;
        end;

        TExceptFrameKind = (tek_except, tek_implicitfinally, tek_normalfinally);

        class procedure Get_Exception_Temps(AList:TAsmList;var ATemps:TExceptionTemps); virtual;
        class procedure UnGet_Exception_Temps(AList:TAsmList;const ATemps:TExceptionTemps); virtual;
        class procedure New_Exception(AList:TAsmList;const ATemps:TExceptionTemps; const AExceptFrameKind: TExceptFrameKind; out AExceptState: TExceptionState); virtual;
        { start of "except/finally" block }
        class procedure Emit_Except_Label(AList: TAsmList; AExceptFrameKind: TExceptFrameKind; var AExceptState: TExceptionState;var AExceptionTemps:TExceptionTemps); virtual;
        { end of a try-block, label comes after the end of try/except or
          try/finally }
        class procedure End_Try_Block(AList: TAsmList; AExceptFrameKind: TExceptFrameKind; const ATemps: TExceptionTemps; var AExceptionState: TExceptionState; AEndLabel: TAsmLabel); virtual;
        class procedure Free_Exception(AList: TAsmList; const ATemps: TExceptionTemps; const AState: TExceptionState; AReason: aint; AEndExceptLabel: TAsmLabel; AOnlyFree:boolean); virtual;
        class procedure Handle_Nested_Exception(AList:TAsmList;var ATemps:TExceptionTemps;var AEntryState: TExceptionState); virtual;
        class procedure Handle_ReRaise(AList:TAsmList;const ATemps:TExceptionTemps;const AEntryState: TExceptionState; const AExceptFrameKind: TExceptFrameKind); virtual;
        { start of an "on" (catch) block }
        class procedure Begin_Catch(AList: TAsmList; AExceptType: TObjectDef; ANextOnLabel: TAsmLabel; out AExceptLocDef: TDef; out AExceptLocReg: TRegister); virtual;
        { end of an "on" (catch) block }
        class procedure End_Catch(AList: TAsmList); virtual;
        { called for a catch all exception }
        class procedure Catch_All_Start(AList: TAsmList); virtual;
        { called after the catch all exception has been started with new_exception }
        class procedure Catch_All_Add(AList: TAsmList); virtual;
        class procedure Catch_All_End(AList: TAsmList); virtual;
        class procedure CleanupObjectStack(AList: TAsmList); virtual;
        class procedure PopAddrStack(AList: TAsmList); virtual;
        class function Use_Cleanup(const AExceptFrameKind: TExceptFrameKind): boolean;
      end;
      TCGExceptionStateHandlerClass = class of TCGExceptionStateHandler;

    var
      CExceptionStateHandler: TCGExceptionStateHandlerClass = TCGExceptionStateHandler;

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

    class function TCGExceptionStateHandler.Use_Cleanup(const AExceptFrameKind: TExceptFrameKind): boolean;
      begin
        { in case of an exception caught by the implicit exception frame of
          a safecall routine, this is not a cleanup frame but one that
          catches the exception and returns a value from the function }
        Result:=
          (AExceptFrameKind=tek_implicitfinally) and
          not((tf_safecall_exceptions in TargetInfo.Flags) and
             (CurrentProcInfo.ProcDef.ProcCallOption=pocall_safecall));
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

    class procedure TCGExceptionStateHandler.Get_Exception_Temps(AList:TAsmList;var ATemps:TExceptionTemps);
      begin
        if not Assigned(ExceptionReasonType) then
          ExceptionReasonType:=Search_System_Proc('fpc_setjmp').ReturnDef;
        TG.GetHLTemp(AList,Rec_ExceptAddr,Rec_ExceptAddr.Size,tt_persistent,ATemps.EnvBuf);
        TG.GetHLTemp(AList,Rec_Jmp_Buf,Rec_Jmp_Buf.Size,tt_persistent,ATemps.JmpBuf);
        TG.GetHLTemp(AList,ExceptionReasonType,ExceptionReasonType.Size,tt_persistent,ATemps.ReasonBuf);
      end;


    class procedure TCGExceptionStateHandler.UnGet_Exception_Temps(AList:TAsmList;const ATemps:TExceptionTemps);
      begin
        TG.UnGetTemp(AList,ATemps.JmpBuf);
        TG.UnGetTemp(AList,ATemps.EnvBuf);
        TG.UnGetTemp(AList,ATemps.ReasonBuf);
      end;


    class procedure TCGExceptionStateHandler.New_Exception(AList:TAsmList;const ATemps:TExceptionTemps; const AExceptFrameKind: TExceptFrameKind; out AExceptState: TExceptionState);
      var
        lParaLoc1, lParaLoc2, lParaLoc3, lPushExceptResult, lSetJmpResult: TCGPara;
        lProcDef: TProcDef;
        lTempResultLoc: TLocation;
      begin
        CurrentAsmData.getjumplabel(AExceptState.ExceptionLabel);
        AExceptState.OldFlowControl:=flowcontrol;
        AExceptState.FinallyCodeLabel:=nil;

        lParaLoc1.init;
        lParaLoc2.init;
        lParaLoc3.init;

        { fpc_pushexceptaddr(exceptionframetype, setjmp_buffer, exception_address_chain_entry) }
        lProcDef:=Search_System_Proc('fpc_pushexceptaddr');
        ParaManager.GetCGTempParaLoc(AList,lProcDef,1,lParaLoc1);
        ParaManager.GetCGTempParaLoc(AList,lProcDef,2,lParaLoc2);
        ParaManager.GetCGTempParaLoc(AList,lProcDef,3,lParaLoc3);
        if lProcDef.Is_PushLeftRight then
          begin
            { type of exceptionframe }
            hlcg.A_Load_Const_CGPara(AList,lParaLoc1.def,1,lParaLoc1);
            { setjmp buffer }
            hlcg.A_LoadAddr_Ref_CGPara(AList,Rec_Jmp_Buf,ATemps.JmpBuf,lParaLoc2);
            { exception address chain entry }
            hlcg.A_LoadAddr_Ref_CGPara(AList,Rec_ExceptAddr,ATemps.EnvBuf,lParaLoc3);
          end
        else
          begin
            hlcg.A_LoadAddr_Ref_CGPara(AList,Rec_ExceptAddr,ATemps.EnvBuf,lParaLoc3);
            hlcg.A_LoadAddr_Ref_CGPara(AList,Rec_Jmp_Buf,ATemps.JmpBuf,lParaLoc2);
            hlcg.A_Load_Const_CGPara(AList,lParaLoc1.def,1,lParaLoc1);
          end;
        ParaManager.FreeCGPara(AList,lParaLoc3);
        ParaManager.FreeCGPara(AList,lParaLoc2);
        ParaManager.FreeCGPara(AList,lParaLoc1);
        { perform the fpc_pushexceptaddr call }
        lPushExceptResult:=hlcg.G_Call_System_Proc(AList,lProcDef,[@lParaLoc1,@lParaLoc2,@lParaLoc3],nil);
        lParaLoc1.done;
        lParaLoc2.done;
        lParaLoc3.done;

        { get the result }
        Location_Reset(lTempResultLoc,LOC_REGISTER,Def_CGSize(lPushExceptResult.def));
        lTempResultLoc.Register:=hlcg.GetAddressRegister(AList,lPushExceptResult.def);
        hlcg.Gen_Load_CGPara_Loc(AList,lPushExceptResult.def,lPushExceptResult,lTempResultLoc,true);
        lPushExceptResult.ResetIfTemp;

        { fpc_setjmp(result_of_pushexceptaddr_call) }
        lProcDef:=Search_System_Proc('fpc_setjmp');
        ParaManager.GetCGTempParaLoc(AList,lProcDef,1,lParaLoc1);

        hlcg.A_Load_Reg_CGPara(AList,lPushExceptResult.def,lTempResultLoc.Register,lParaLoc1);
        ParaManager.FreeCGPara(AList,lParaLoc1);
        { perform the fpc_setjmp call }
        lSetJmpResult:=hlcg.G_Call_System_Proc(AList,lProcDef,[@lParaLoc1],nil);
        lParaLoc1.done;
        Location_Reset(lTempResultLoc,LOC_REGISTER,Def_CGSize(lSetJmpResult.def));
        lTempResultLoc.Register:=hlcg.GetIntRegister(AList,lSetJmpResult.def);
        hlcg.Gen_Load_CGPara_Loc(AList,lSetJmpResult.def,lSetJmpResult,lTempResultLoc,true);
        hlcg.G_Exception_Reason_Save(AList,lSetJmpResult.def,ExceptionReasonType,lTempResultLoc.Register,ATemps.ReasonBuf);
        { if we get 1 here in the function result register, it means that we
          longjmp'd back here }
        hlcg.A_Cmp_Const_Reg_Label(AList,lSetJmpResult.def,OC_NE,0,lTempResultLoc.Register,AExceptState.ExceptionLabel);
        lSetJmpResult.ResetIfTemp;

        flowcontrol:=[fc_inflowcontrol,fc_catching_exceptions];
     end;


    class procedure TCGExceptionStateHandler.Emit_Except_Label(AList: TAsmList; AExceptFrameKind: TExceptFrameKind; var AExceptState: TExceptionState;var AExceptionTemps:TExceptionTemps);
      begin
        hlcg.A_Label(AList,AExceptState.ExceptionLabel);
      end;


    class procedure TCGExceptionStateHandler.End_Try_Block(AList: TAsmList; AExceptFrameKind: TExceptFrameKind; const ATemps: TExceptionTemps; var AExceptionState: TExceptionState; AEndLabel: TAsmLabel);
      begin
         AExceptionState.NewFlowControl:=flowcontrol;
         flowcontrol:=AExceptionState.OldFlowControl;
      end;


    class procedure TCGExceptionStateHandler.Free_Exception(AList: TAsmList; const ATemps: TExceptionTemps; const AState: TExceptionState; AReason: aint; AEndExceptLabel: TAsmLabel; AOnlyFree: boolean);
      var
        lReasonReg: TRegister;
      begin
         PopAddrStack(AList);
         if not AOnlyFree then
          begin
            lReasonReg:=hlcg.GetIntRegister(AList,ExceptionReasonType);
            hlcg.G_Exception_Reason_Load(AList,ExceptionReasonType,ExceptionReasonType,ATemps.ReasonBuf,lReasonReg);
            hlcg.A_Cmp_Const_Reg_Label(AList,ExceptionReasonType,OC_EQ,AReason,lReasonReg,AEndExceptLabel);
          end;
      end;


    { does the necessary things to clean up the object stack }
    { in the except block                                    }
    class procedure TCGExceptionStateHandler.CleanupObjectStack(AList: TAsmList);
      begin
         hlcg.G_Call_System_Proc(AList,'fpc_doneexception',[],nil).ResetIfTemp;
      end;


    { generates code to be executed when another exeception is raised while
      control is inside except block }
    class procedure TCGExceptionStateHandler.Handle_Nested_Exception(AList:TAsmList;var ATemps:TExceptionTemps;var AEntryState: TExceptionState);
      var
         lExitLabel: TAsmLabel;
      begin
         CurrentAsmData.getjumplabel(lExitLabel);
         { add an catch all action clause, at least psabieh needs this }
         Catch_All_Add(AList);
         End_Try_Block(AList,tek_except,ATemps,AEntryState,lExitLabel);
         Emit_Except_Label(AList,tek_except,AEntryState,ATemps);
         { don't generate line info for internal cleanup }
         AList.concat(TAIMarker.Create(mark_NoLineInfoStart));
         Free_Exception(AList,ATemps,AEntryState,0,lExitLabel,false);
         { we don't need to save/restore registers here because reraise never }
         { returns                                                            }
         hlcg.G_Call_System_Proc(AList,'fpc_raise_nested',[],nil).ResetIfTemp;
         hlcg.A_Label(AList,lExitLabel);
         CleanupObjectStack(AList);
      end;


    class procedure TCGExceptionStateHandler.Handle_ReRaise(AList: TAsmList; const ATemps: TExceptionTemps; const AEntryState: TExceptionState; const AExceptFrameKind: TExceptFrameKind);
      begin
        hlcg.G_Call_System_Proc(AList,'fpc_reraise',[],nil).ResetIfTemp;
      end;


    class procedure TCGExceptionStateHandler.Begin_Catch(AList: TAsmList; AExceptType: TObjectDef; ANextOnLabel: TAsmLabel; out AExceptLocDef: TDef; out AExceptLocReg: TRegister);
      var
        lProcDef: TProcDef;
        lReference2: TReference;
        lFPCCatchesResult,
        lParaLoc1: TCGPara;
        lExceptLoc: TLocation;
        lIndirect: boolean;
        lOtherUnit: boolean;
      begin
        lParaLoc1.init;
        lOtherUnit:=FindUnitSymTable(AExceptType.owner).ModuleID<>FindUnitSymTable(CurrentProcInfo.ProcDef.owner).ModuleID;
        lIndirect:=(tf_supports_packages in TargetInfo.Flags) and
                    (TargetInfo.system in systems_indirect_var_imports) and
                    lOtherUnit;

        { send the vmt parameter }
        lProcDef:=Search_System_Proc('fpc_catches');
        Reference_Reset_Symbol(lReference2, CurrentAsmData.RefAsmSymbol(AExceptType.VMT_MangledName, AT_DATA, lIndirect), 0, sizeof(PInt), []);
        if lOtherUnit then
          CurrentModule.Add_Extern_AsmSym(AExceptType.VMT_MangledName, AB_EXTERNAL, AT_DATA);
        ParaManager.GetCGTempParaLoc(AList, lProcDef, 1, lParaLoc1);
        hlcg.A_LoadAddr_Ref_CGPara(AList, AExceptType.VMT_Def, lReference2, lParaLoc1);
        ParaManager.FreeCGPara(AList, lParaLoc1);
        lFPCCatchesResult:=hlcg.G_Call_System_Proc(AList, lProcDef, [@lParaLoc1], nil);
        Location_Reset(lExceptLoc, LOC_REGISTER, Def_CGSize(lFPCCatchesResult.def));
        lExceptLoc.Register:=hlcg.GetAddressRegister(AList, lFPCCatchesResult.def);
        hlcg.Gen_Load_CGPara_Loc(AList, lFPCCatchesResult.def, lFPCCatchesResult, lExceptLoc, true);

        { is it this catch? No. go to next onlabel }
        hlcg.A_Cmp_Const_Reg_Label(AList, lFPCCatchesResult.def, OC_EQ, 0, lExceptLoc.Register, ANextOnLabel);

        lParaLoc1.done;

        AExceptLocDef:=lFPCCatchesResult.def;
        AExceptLocReg:=lExceptLoc.Register;
      end;


    class procedure TCGExceptionStateHandler.End_Catch(AList: TAsmList);
      begin
        { nothing to do by default }
      end;


    class procedure TCGExceptionStateHandler.Catch_All_Start(AList: TAsmList);
      begin
        { nothing to do by default }
      end;


    class procedure TCGExceptionStateHandler.Catch_All_Add(AList: TAsmList);
      begin
        { nothing to do by default }
      end;


    class procedure TCGExceptionStateHandler.Catch_All_End(AList: TAsmList);
      begin
        { nothing to do by default }
      end;

    class procedure TCGExceptionStateHandler.PopAddrStack(AList: TAsmList);
      begin
        hlcg.G_Call_System_Proc(AList,'fpc_popaddrstack',[],nil).ResetIfTemp;
      end;


end.

