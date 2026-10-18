{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate assembler for call nodes

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
unit ncgcal;

{$i fpcdefs.inc}

interface

    uses
      cpubase,
      GlobType,
      parabase,cgutils,
      AAsmData,cgbase,
      symdef,node,ncal;

    type
       TCGCallParaNode = class(TCallParaNode)
       protected
          procedure Push_Addr_Para;
          procedure Push_Value_Para;virtual;
          procedure Push_Formal_Para;virtual;
          procedure Push_CopyOut_Para;virtual;abstract;
          function Maybe_Push_Unused_Para:Boolean;virtual;

          procedure SecondCallParaN_Do_SecondPass;
          procedure SecondCallParaN_After_SecondPass;
       public
          TempCGPara : TCGPara;

          constructor Create(AExpr,ANext : TNode);override;
          destructor Destroy;override;
          procedure SecondCallParaN;override;
       end;

       { tcgcallnode }

       TCGCallNode = class(TCallNode)
       private
          procedure HandleReturnValue;
          procedure ReleaseUnusedReturnValue;
          procedure CopyBackParas;
          procedure ReleaseParaTemps;
          procedure ReorderParameters;
          procedure FreeParas;
          function IsParentFPpushed:Boolean;
       protected
          FResultParaLoc: TCGPara;
          FParaLocs: array of PCGPara;

          FFramePointerParaLoc : TCGPara;
          {# This routine is used to push the current frame pointer
             on the stack. This is used in nested routines where the
             value of the frame pointer is always pushed as an extra
             parameter.

             The default handling is the standard handling used on
             most stack based machines, where the frame pointer is
             the first invisible parameter.
          }
          procedure Pop_ParaSize(APopSize:LongInt);virtual;
          procedure Extra_Interrupt_Code;virtual;
          procedure Extra_Pre_Call_Code;virtual;
          procedure Extra_Call_Code;virtual;
          procedure Extra_Post_Call_Code;virtual;


          { The function result is returned in a tcgpara. This tcgpara has to
            be translated into a tlocation so the rest of the code generator
            can work with it. This routine decides what the most appropriate
            tlocation is and sets self.location based on that. }
          procedure Set_Result_Location(ARealResultDef: TStoredDef);virtual;

          { if an unused return value is in another location than a
            LOC_REFERENCE, this method will be called to perform the necessary
            cleanups. By default it does not do anything }
          procedure Do_Release_Unused_Return_Value;virtual;

          { Override the following three methods to support calls to address in
            'ref' without loading it into register (only x86 targets probably).
            If can_call_ref returns true, it should do required simplification
            on ref. }
          function Can_Call_Ref(var AReference: TReference):Boolean;virtual;
          procedure Extra_Call_Ref_Code(var AReference: TReference);virtual;
          function Do_Call_Ref(AReference: TReference): TCGPara;virtual;

          { store all the parameters in the temporary FParaLocs in their final
            location, and create the FParaLocs array that will be passed to
            hlcg.a_call_* }
          procedure PushParas;virtual;

          { loads the code pointer of a complex procvar (one with a self/
            parentfp/... and a procedure address) into a register and returns it }
          procedure Load_Complex_ProcVar_CodePtr(out AReg: TRegister; out ACallProcDef: TAbstractProcDef); virtual;
          { loads the procvar code pointer into a register with type def }
          procedure Load_ProcVar_CodePtr(out AReg: TRegister; out ACallProcDef: TAbstractProcDef);

          procedure Load_Block_Invoke(out ATargetReg: TRegister; out ACallProcDef: TAbstractProcDef);

          function Get_Call_Reg(AList: TAsmList): TRegister; virtual;
          procedure UnGet_Call_Reg(AList: TAsmList; AReg: TRegister); virtual;
       public
          procedure Pass_Generate_Code;override;
          destructor Destroy;override;
       end;


implementation

    uses
      Systems,
      Verbose,Globals,CUtils,
      symconst,SymTable,symtype,SymSym,defutil,paramgr,
      pass_2,
      nld,ncnv,
      ncgutil,blockutl,
      cgobj,tgobj,hlcgobj,
      ProcInfo,
      aasmtai,
      wpobase;


    function CanSkipParaPush(AParaSym: TParaVarSym): Boolean;
      begin
        { We can skip passing the parameter when:
            the parameter can be optimized as unused
            and the target does not strictly require all parameters (has_strict_proc_signature = false)
            and
                 fixed stack is used
              or the parameter is in a register
              or the parameter is $parentfp and po_delphi_nested_cc is set for the routine. }
        Result:=ParaManager.Can_Opt_Unused_Para(AParaSym) and
          not ParaManager.Has_Strict_Proc_Signature and
          (ParaManager.Use_Fixed_Stack or
           ((vo_is_parentfp in AParaSym.VarOptions) and
            (po_delphi_nested_cc in TAbstractProcDef(AParaSym.owner.DefOwner).ProcOptions)) or
           (AParaSym.ParaLoc[callerside].Location^.Loc in [LOC_REGISTER,LOC_CREGISTER]));
      end;

{*****************************************************************************
                             TCGCALLPARANODE
*****************************************************************************}

    constructor TCGCallParaNode.Create(AExpr,ANext : TNode);
      begin
        inherited Create(AExpr,ANext);
        TempCGPara.init;
      end;


    destructor TCGCallParaNode.Destroy;
      begin
        TempCGPara.done;
        inherited Destroy;
      end;


    procedure TCGCallParaNode.Push_Addr_Para;
      var
        lValueDef: TDef;
      begin
        if not(Left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
          InternalError(200304235);
        if Maybe_Push_Unused_Para then
          exit;
        { see the call to keep_para_array_range in ncal: if that call returned
          true, we overwrite the resultdef of left with its original resultdef
          (to keep track of the range of the original array); we inserted a type
          conversion to parasym.vardef, so that is the type this value actually
          has }
        if Is_Dynamic_Array(Left.ResultDef) and
           Is_Open_Array(ParaSym.vardef) then
          lValueDef:=ParaSym.vardef
        else
          lValueDef:=Left.ResultDef;
        hlcg.A_LoadAddr_Ref_CGPara(CurrentAsmData.CurrAsmList,lValueDef,Left.Location.Reference,TempCGPara);
      end;


    procedure TCGCallNode.ReorderParameters;
      var
        lCurrentPara,lPreviousPara,lNextPara,lReverseStartPara : TCGCallParaNode;
      begin
        { All parameters are now in temporary locations. If we move them to
          their regular locations in the same order, then we get the
          following pattern for register parameters:
            mov para1, tempreg1
            mov para2, tempreg2
            mov para3, tempreg3
            mov tempreg1, parareg1
            mov tempreg2, parareg2
            mov tempreg3, parareg3

          The result is that all tempregs conflict with all pararegs.
          A better solution is to use:
            mov para1, tempreg1
            mov para2, tempreg2
            mov para3, tempreg3
            mov tempreg3, parareg3
            mov tempreg2, parareg2
            mov tempreg1, parareg1
          This way, tempreg2 can be the same as parareg1 etc.

          To achieve this, we invert the order of all LOC_XREGISTER
          paras (JM).
        }
        lCurrentPara:=TCGCallParaNode(Left);
        { assume all LOC_REFERENCE parameters come first
          (see tcallnode.order_parameters)
        }
        lReverseStartPara:=nil;
        while Assigned(lCurrentPara) do
          begin
            if not(lCurrentPara.ParaSym.ParaLoc[callerside].Location^.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
              lReverseStartPara:=lCurrentPara;
            lCurrentPara:=TCGCallParaNode(lCurrentPara.Right);
          end;

        { since all register tempparalocs have basically a complexity of 1,
          (unless there are large stack offsets that require a temp register on
          some architectures, but that's minor), we don't have to care about
          the internal relative order of different register type parameters
        }
        lPreviousPara:=nil;
        lCurrentPara:=TCGCallParaNode(Left);
        while (lCurrentPara<>lReverseStartPara) do
          begin
            lNextPara:=TCGCallParaNode(lCurrentPara.Right);
            if not(lCurrentPara.ParaSym.ParaLoc[callerside].Location^.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
              begin
                { remove hpcurr from chain }
                if Assigned(lPreviousPara) then
                  lPreviousPara.Right:=lNextPara
                else
                  Left:=lNextPara;
                { insert right after hpreversestart, so every element will
                  be inserted right before the previously moved one ->
                  reverse order; hpreversestart itself is the last register
                  parameter }
                lCurrentPara.Right:=lReverseStartPara.Right;
                lReverseStartPara.Right:=lCurrentPara;
              end
            else
              lPreviousPara:=lCurrentPara;
            lCurrentPara:=lNextPara;
          end;
      end;


    procedure TCGCallParaNode.Push_Value_Para;
      begin
        { Permissive backends do not need parameters with no storage. }
        if (Left.ResultDef.Size=0) and
           not ParaManager.Has_Strict_Proc_Signature then
          exit;

        if Maybe_Push_Unused_Para then
          exit;

        { Move flags and jump in register to make it less complex }
        if Left.Location.Loc in [LOC_FLAGS,LOC_JUMP,LOC_SUBSETREG,LOC_CSUBSETREG,LOC_SUBSETREF,LOC_CSUBSETREF] then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);

        { load the parameter's tlocation into its cgpara }
        hlcg.Gen_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.Location,TempCGPara)
      end;


    procedure TCGCallParaNode.Push_Formal_Para;
      begin
        if Maybe_Push_Unused_Para then
          exit;
        { allow passing of a constant to a const formaldef }
        if (ParaSym.VarSpez=vs_const) and
           not(Left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
          hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);
        Push_Addr_Para;
      end;


    function TCGCallParaNode.Maybe_Push_Unused_Para: Boolean;
      begin
        { Check if the parameter is unused and can be optimized }
        Result:=ParaManager.Can_Opt_Unused_Para(ParaSym);
        if not Result then
          exit;
        { If we can't skip loading of the parameter, load an undefined dummy value. }
        if not CanSkipParaPush(ParaSym) then
          begin
            if cs_asm_source in CurrentSettings.GlobalSwitches then
              CurrentAsmData.CurrAsmList.concat(TAIComment.Create(StrPNew('Parameter '+ParaSym.realname+' is unused, loading undefined value')));
            hlcg.A_Load_Undefined_CGPara(CurrentAsmData.CurrAsmList,Left.ResultDef,TempCGPara);
          end
        else
          if cs_asm_source in CurrentSettings.GlobalSwitches then
            CurrentAsmData.CurrAsmList.concat(TAIComment.Create(StrPNew('Parameter '+ParaSym.realname+' is unused')));
      end;


    procedure TCGCallParaNode.SecondCallParaN_Do_SecondPass;
      begin
        if Assigned(FParaInit) then
          SecondPass(FParaInit);
        SecondPass(Left);
      end;


    procedure TCGCallParaNode.SecondCallParaN_After_SecondPass;
      var
        lPushAddr: Boolean;
      begin
        hlcg.Maybe_Change_Load_Node_Reg(CurrentAsmData.CurrAsmList,Left,true);

        ParaManager.CreateTempParaLoc(CurrentAsmData.CurrAsmList,CallNode.ProcDefinition.ProcCallOption,ParaSym,not FollowedByStackTaintingCallCached,TempCGPara);

        { handle varargs first, because parasym is not valid }
        if (cpf_varargs_para in CallParaFlags) then
          begin
            if ParaManager.Push_Addr_Param(vs_value,Left.ResultDef,
                   CallNode.ProcDefinition.ProcCallOption) then
              Push_Addr_Para
            else
              Push_Value_Para;
          end
        { hidden parameters }
        else if (vo_is_hidden_para in ParaSym.VarOptions) then
          begin
            { don't push a node that already generated a pointer type
              by address for implicit hidden parameters }
            lPushAddr:=(vo_is_funcret in ParaSym.VarOptions) or
              { pass "this" in C++ classes explicitly as pointer
                because push_addr_param might not be true for them }
              (Is_CPPClass(ParaSym.vardef) and (vo_is_self in ParaSym.VarOptions)) or
               (
                 (
                   not(Left.ResultDef.typ in [pointerdef,classrefdef]) or
                   (
                     { allow pointerdefs (as self) to be passed as addr
                       param if the method is part of a type helper which
                       extends a pointer type }
                     (vo_is_self in ParaSym.VarOptions) and
                     (CallNode.ProcDefinition.owner.SymTableType=objectsymtable) and
                     (Is_ObjectPascal_Helper(TDef(CallNode.ProcDefinition.owner.DefOwner))) and
                     (TObjectDef(CallNode.ProcDefinition.owner.DefOwner).ExtendedDef.typ=pointerdef)
                   )
                 ) and
                ParaManager.Push_Addr_Param(ParaSym.VarSpez,ParaSym.vardef,
                    CallNode.ProcDefinition.ProcCallOption));

            if lPushAddr then
              begin
                { objects or advanced records could be located in registers if they are the result of a type case, see e.g. tbs\tw26075.pas }
                if not(Left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
                  hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);
                Push_Addr_Para
              end
            else
              Push_Value_Para;
          end
        { formal def }
        else if (ParaSym.vardef.typ=formaldef) then
          Push_Formal_Para
        { Normal parameter }
        else if ParaManager.Push_CopyOut_Param(ParaSym.VarSpez,ParaSym.vardef,
                    CallNode.ProcDefinition.ProcCallOption) then
          Push_CopyOut_Para
        else
          begin
            { don't push a node that already generated a pointer type
              by address for implicit hidden parameters }
            if (not(
                    (vo_is_hidden_para in ParaSym.VarOptions) and
                    (Left.ResultDef.typ in [pointerdef,classrefdef])
                   ) and
                ParaManager.Push_Addr_Param(ParaSym.VarSpez,ParaSym.vardef,
                    CallNode.ProcDefinition.ProcCallOption)) and
                { dyn. arrays passed to an array of const must be passed by value, see tests/tbs/tb_arrays_objfpc_run_02.pas (case tw4219.pas) }
                not(
                    Is_Array_Of_Const(ParaSym.vardef) and
                    Is_Dynamic_Array(Left.ResultDef)
                   ) then
              begin
                 { Passing a var parameter to a var parameter, we can
                   just push the address transparently }
                 if (Left.NodeType=loadn) and
                    (TLoadNode(Left).Is_Addr_Param_Load) then
                   begin
                     if (Left.Location.Reference.Index<>NR_NO) or
                        (Left.Location.Reference.Offset<>0) then
                       InternalError(200410107);
                     hlcg.A_Load_Reg_CGPara(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(Left.ResultDef),Left.Location.Reference.Base,TempCGPara)
                   end
                 else
                   begin
                     { Force to be in memory }
                     if not(Left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
                       hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef);
                     Push_Addr_Para;
                   end;
              end
            else
              Push_Value_Para;
          end;

        { update return location in callnode when this is the function
          result }
        if Assigned(ParaSym) and
           (
             { for type helper/record constructor check that it is self parameter }
             (
               (vo_is_self in ParaSym.VarOptions) and
               (CallNode.ProcDefinition.ProcTypeOption=potype_constructor) and
               (ParaSym.vardef.typ<>objectdef)
             ) or
             (vo_is_funcret in ParaSym.VarOptions)
           ) then
          Location_Copy(CallNode.Location,Left.Location);
      end;


    procedure TCGCallParaNode.SecondCallParaN;
      begin
         if not(Assigned(ParaSym)) then
           InternalError(200304242);

         { Skip nothingn nodes which are used after disabling
           a parameter }
         if (Left.NodeType<>nothingn) then
           begin
             SecondCallParaN_Do_SecondPass;
             SecondCallParaN_After_SecondPass;
           end;

         { next parameter }
         if Assigned(Right) then
           TCallParaNode(Right).SecondCallParaN;
      end;


{*****************************************************************************
                             TCGCALLNODE
*****************************************************************************}

    procedure TCGCallNode.Extra_Interrupt_Code;
      begin
      end;


    procedure TCGCallNode.Extra_Pre_Call_Code;
      begin
      end;


    procedure TCGCallNode.Extra_Call_Code;
      begin
      end;


    procedure TCGCallNode.Extra_Post_Call_Code;
      begin
      end;

    function TCGCallNode.Can_Call_Ref(var AReference: TReference): Boolean;
      begin
        Result:=false;
      end;


    procedure TCGCallNode.Extra_Call_Ref_Code(var AReference: TReference);
      begin
        { no action by default }
      end;


    function TCGCallNode.Do_Call_Ref(AReference: TReference): TCGPara;
      begin
        InternalError(2014012901);
        { silence warning }
        Result.init;
      end;


    procedure TCGCallNode.Load_Block_Invoke(out ATargetReg: TRegister; out ACallProcDef: TAbstractProcDef);
      var
        lReference: TReference;
        lLiteralDef: TRecordDef;
      begin
        lLiteralDef:=get_block_literal_type_for_proc(TAbstractProcDef(Right.ResultDef));
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,CPointerDef.getreusable(lLiteralDef),true);
        { load the invoke pointer }
        hlcg.Reference_Reset_Base(lReference,Right.ResultDef,Right.Location.Register,0,CTempPosInvalid,Right.ResultDef.Alignment,[]);
        ACallProcDef:=CProcVarDef.GetReusableProcAddr(ProcDefinition,pc_address_only);
        ATargetReg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ACallProcDef);
        hlcg.G_Load_Field_Reg_By_Name(CurrentAsmData.CurrAsmList,lLiteralDef,ACallProcDef,'INVOKE',lReference,ATargetReg);
     end;


    function TCGCallNode.Get_Call_Reg(AList: TAsmList): TRegister;
      begin
        Result:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ProcDefinition.Address_Type);
      end;


    procedure TCGCallNode.UnGet_Call_Reg(AList: TAsmList; AReg: TRegister);
      begin
        { nothing to do by default }
      end;


    procedure TCGCallNode.Set_Result_Location(ARealResultDef: TStoredDef);
      begin
        if ARealResultDef.Is_IntRegable or
           ARealResultDef.Is_FPURegable or
           { avoid temporarily storing pointer-sized entities that can't be
             regvars, such as reference-counted pointers, to memory --
             no exception can occur right now (except in case of existing
             memory corruption), and we'd store them to a regular temp
             anyway and that is not safer than keeping them in a register }
           ((ARealResultDef.Size=sizeof(AInt)) and
            (FResultParaLoc.Location^.Loc=LOC_REGISTER) and
            not Assigned(FResultParaLoc.Location^.next)) then
          Location_Allocate_Register(CurrentAsmData.CurrAsmList,Location,ARealResultDef,false)
        else
          begin
            Location_Reset_Ref(Location,LOC_REFERENCE,Def_CGSize(ARealResultDef),0,[]);
            TG.GetHLTemp(CurrentAsmData.CurrAsmList,ARealResultDef,FResultParaLoc.IntSize,tt_normal,Location.Reference);
          end;
      end;


    procedure TCGCallNode.Do_Release_Unused_Return_Value;
      begin
        case Location.Loc of
          LOC_REFERENCE :
            begin
              if Is_Managed_Type(ResultDef) then
                 hlcg.G_Finalize(CurrentAsmData.CurrAsmList,ResultDef,Location.Reference);
               TG.UnGetIfTemp(CurrentAsmData.CurrAsmList,Location.Reference);
            end;
          else
            ;
        end;
      end;


    procedure TCGCallNode.Pop_ParaSize(APopSize:LongInt);
      begin
      end;


    procedure TCGCallNode.HandleReturnValue;
      var
        lRealResultDef: TStoredDef;
      begin
        { Check that the return location is set when the result is passed in
          a parameter }
        if ParaManager.Ret_In_Param(ResultDef,ProcDefinition) then
          begin
            { self.location is set near the end of secondcallparan so it
              refers to the implicit result parameter }
            if Location.Loc<>LOC_REFERENCE then
              InternalError(200304241);
            exit;
          end;

        if not Assigned(TypeDef) then
          lRealResultDef:=TStoredDef(ResultDef)
        else
          lRealResultDef:=TStoredDef(TypeDef);

          { get a tlocation that can hold the return value that's currently in
            the return value's tcgpara }
          Set_Result_Location(lRealResultDef);

          { Do not move the physical register to a virtual one in case
            the return value is not used, because if the virtual one is
            then mapped to the same register as the physical one, we will
            end up with two deallocs of this register (one inserted here,
            one inserted by the register allocator), which unbalances the
            register allocation information.  The return register(s) will
            be freed by location_free() in ReleaseUnusedReturnValue
            (mantis #13536).  }
          if (cnf_return_value_used in CallNodeFlags) or
             Assigned(FuncRetNode) then
            hlcg.Gen_Load_CGPara_Loc(CurrentAsmData.CurrAsmList,lRealResultDef,FResultParaLoc,Location,false);

        if ((Location.Loc=LOC_REGISTER) and
            not lRealResultDef.Is_IntRegable) or
           ((Location.Loc in [LOC_FPUREGISTER,LOC_MMREGISTER]) and
            (not lRealResultDef.Is_FPURegable or
             ((Location.Loc=LOC_MMREGISTER)<>Use_VectorFPU(lRealResultDef)))) then
          begin
            hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Location,lRealResultDef);
            { may have been record returned in a floating point register (-> location.size
              will be the size of the fpuregister instead of the int size of the record) }
            Location.Size:=Def_CGSize(lRealResultDef);
          end;

        { copy value to the final location if this was already provided to the
          callnode. This must be done after the call node, because the location can
          also be used as parameter and may not be finalized yet }
        if Assigned(FuncRetNode) then
          begin
            FuncRetNode.Pass_Generate_Code;
            { Decrease refcount for refcounted types, this can be skipped when
              we have used a temp, because then it is already done from tempcreatenode.
              Also no finalize is needed, because there is no risk of exceptions from the
              function since this is code is only executed after the function call has returned }
            if Is_Managed_Type(FuncRetNode.ResultDef) and
               (FuncRetNode.NodeType<>temprefn) then
              hlcg.G_Finalize(CurrentAsmData.CurrAsmList,FuncRetNode.ResultDef,FuncRetNode.Location.Reference);

            case Location.Loc of
              LOC_REGISTER :
                begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                  if Location.Size in [OS_64,OS_S64] then
                    cg64.A_Load64_Reg_Loc(CurrentAsmData.CurrAsmList,Location.Register64,FuncRetNode.Location)
                  else
{$endif}
                    hlcg.A_Load_Reg_Loc(CurrentAsmData.CurrAsmList,ResultDef,ResultDef,Location.Register,FuncRetNode.Location);
                  Location_Free(CurrentAsmData.CurrAsmList,Location);
                end;
              LOC_MMREGISTER :
                begin
                  hlcg.A_LoadMM_Reg_Loc(CurrentAsmData.CurrAsmList,ResultDef,ResultDef,Location.Register,FuncRetNode.Location,nil);
                  Location_Free(CurrentAsmData.CurrAsmList,Location);
                end;
              LOC_FPUREGISTER:
                begin
                  hlcg.A_LoadFPU_Reg_Loc(CurrentAsmData.CurrAsmList,ResultDef,ResultDef,Location.Register,FuncRetNode.Location);
                  Location_Free(CurrentAsmData.CurrAsmList,Location);
                end;
              LOC_REFERENCE:
                begin
                  case FuncRetNode.Location.Loc of
                    LOC_CREGISTER,
                    LOC_REGISTER:
                      hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,ResultDef,ResultDef,Location.Reference,FuncRetNode.Location.Register);
                    LOC_CFPUREGISTER,
                    LOC_FPUREGISTER:
                      hlcg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,ResultDef,ResultDef,Location.Reference,FuncRetNode.Location.Register);
                    LOC_REFERENCE:
                      hlcg.G_ConcatCopy(CurrentAsmData.CurrAsmList,ResultDef,Location.Reference,FuncRetNode.Location.Reference);
                    LOC_CMMREGISTER,
                    LOC_MMREGISTER:
                      hlcg.A_LoadMM_Reg_Ref(CurrentAsmData.CurrAsmList,ResultDef,ResultDef,FuncRetNode.Location.Register,Location.Reference,nil);
                    else
                      InternalError(200802121);
                  end;
                  Location_FreeTemp(CurrentAsmData.CurrAsmList,Location);
                end;
              else
                InternalError(200709085);
            end;
            Location := FuncRetNode.Location;
          end;
      end;


    procedure TCGCallNode.ReleaseUnusedReturnValue;
      begin
        { When the result is not used we need to finalize the result and
          can release the temp. This need to be after the callcleanupblock
          tree is generated, because that converts the temp from persistent to normal }
        if not(cnf_return_value_used in CallNodeFlags) then
          begin
            Do_Release_Unused_Return_Value;
            if (FResultParaLoc.IntSize<>0) then
              ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,FResultParaLoc);
            Location_Reset(Location,LOC_VOID,OS_NO);
         end;
      end;


    procedure TCGCallNode.CopyBackParas;
      var
        lPara : TCallParaNode;
      begin
        lPara:=TCallParaNode(Left);
        while Assigned(lPara) do
          begin
             if Assigned(lPara.ParaCopyBack) then
               SecondPass(lPara.ParaCopyBack);
             lPara:=TCallParaNode(lPara.Right);
          end;
      end;


    procedure TCGCallNode.ReleaseParaTemps;
      var
        lNode,
        lNode2 : TNode;
        lPara : TCallParaNode;
      begin
        { Release temps from parameters }
        lPara:=TCallParaNode(Left);
        while Assigned(lPara) do
          begin
             if Assigned(lPara.Left) then
               begin
                 { don't release the funcret temp }
                 if not(Assigned(lPara.ParaSym)) or
                    not(
                      (vo_is_funcret in lPara.ParaSym.VarOptions) or
                      (
                        (vo_is_self in lPara.ParaSym.VarOptions) and
                        (ProcDefinition.ProcTypeOption=potype_constructor) and
                        (lPara.ParaSym.vardef.typ<>objectdef)
                      )
                    )then
                   Location_FreeTemp(CurrentAsmData.CurrAsmList,lPara.Left.Location);
                 { process also all nodes of an array of const }
                 lNode:=lPara.Left;
                 while (lNode.NodeType=typeconvn) do
                   lNode:=TTypeConvNode(lNode).Left;
                 if (lNode.NodeType=arrayconstructorn) and
                    Assigned(TArrayConstructorNode(lNode).Left) then
                   begin
                     while Assigned(lNode) do
                       begin
                         lNode2:=TArrayConstructorNode(lNode).Left;
                         { ignore typeconvs and addrn inserted by arrayconstructn for
                           passing a shortstring }
                         if (lNode2.NodeType=typeconvn) and
                            (TUnaryNode(lNode2).Left.NodeType=addrn) then
                           lNode2:=TUnaryNode(TUnaryNode(lNode2).Left).Left
                         else if lNode2.NodeType=addrn then
                           lNode2:=TUnaryNode(lNode2).Left;
                         Location_FreeTemp(CurrentAsmData.CurrAsmList,lNode2.Location);
                         lNode:=TArrayConstructorNode(lNode).Right;
                       end;
                   end;
               end;
             lPara:=TCallParaNode(lPara.Right);
          end;
        SetLength(FParaLocs,0);
      end;


     procedure TCGCallNode.PushParas;
       var
         lPara : TCGCallParaNode;
         lCallerParaLoc,
         lTempParaLoc : PCGParaLocation;
         lSizeLeft: AInt;
         lTempRef,
         lReference : TReference;
         lCallerAlignment,
         lTempAlignment, lIndex: LongInt;
         lSkipIfFinalLoc: Boolean;
       begin
         { copy all resources to the allocated registers }
         lPara:=TCGCallParaNode(Left);
         while Assigned(lPara) do
           begin
             if (lPara.Left.NodeType<>nothingn) and
               not CanSkipParaPush(lPara.ParaSym) then
               begin
                 { better check for the real location of the parameter here, when stack passed parameters
                   are saved temporary in registers, checking for the tmpparaloc.loc is wrong
                 }
                 ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lPara.TempCGPara);
                 lTempParaLoc:=lPara.TempCGPara.Location;
                 lSizeLeft:=lPara.ParaSym.ParaLoc[callerside].IntSize;
                 lCallerAlignment:=lPara.ParaSym.ParaLoc[callerside].Alignment;
                 lTempAlignment:=lPara.TempCGPara.Alignment;
                 if (lTempAlignment=0) or
                    (lCallerAlignment=0) then
                   InternalError(2009020701);
                 lCallerParaLoc:=lPara.ParaSym.ParaLoc[callerside].Location;
                 lSkipIfFinalLoc:=
                   not ParaManager.Use_Fixed_Stack or
                   not(lPara.FollowedByStackTaintingCallCached);
                 while Assigned(lCallerParaLoc) do
                   begin
                     { Every paraloc must have a matching tmpparaloc }
                     if not Assigned(lTempParaLoc) then
                       InternalError(200408224);
                     if lCallerParaLoc^.Size<>lTempParaLoc^.Size then
                       InternalError(200408225);
                     case lCallerParaLoc^.Loc of
                       LOC_REGISTER:
                         begin
                           if lTempParaLoc^.Loc<>LOC_REGISTER then
                             InternalError(200408221);
                           if GetSupReg(lCallerParaLoc^.Register)<first_int_imreg then
                             cg.GetCPURegister(CurrentAsmData.CurrAsmList,lCallerParaLoc^.Register);
                           cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,lTempParaLoc^.Size,lTempParaLoc^.Size,
                               lTempParaLoc^.Register,lCallerParaLoc^.Register);
                         end;
                       LOC_FPUREGISTER:
                         begin
                           if lTempParaLoc^.Loc<>LOC_FPUREGISTER then
                             InternalError(200408222);
                           if GetSupReg(lCallerParaLoc^.Register)<first_fpu_imreg then
                             cg.GetCPURegister(CurrentAsmData.CurrAsmList,lCallerParaLoc^.Register);
                           cg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,lTempParaLoc^.Size,lTempParaLoc^.Size,lTempParaLoc^.Register,lCallerParaLoc^.Register);
                         end;
                       LOC_MMREGISTER:
                         begin
                           if lTempParaLoc^.Loc<>LOC_MMREGISTER then
                             InternalError(200408223);
                           if GetSupReg(lCallerParaLoc^.Register)<first_mm_imreg then
                             cg.GetCPURegister(CurrentAsmData.CurrAsmList,lCallerParaLoc^.Register);
                           cg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,lTempParaLoc^.Size,lTempParaLoc^.Size,
                             lTempParaLoc^.Register,lCallerParaLoc^.Register,MMS_MoveScalar);
                         end;
                       LOC_REFERENCE:
                         begin
                           if not(lSkipIfFinalLoc and
                                  ParaManager.Is_Stack_ParaLoc(lCallerParaLoc)) then
                             begin
                               { Can't have a data copied to the stack, every location
                                 must contain a valid size field }

                              if (lTempParaLoc^.Size=OS_NO) and
                                 ((lTempParaLoc^.Loc<>LOC_REFERENCE) or
                                  Assigned(lTempParaLoc^.next)) then
                                InternalError(200501281);
                                Reference_Reset_Base(lReference,lCallerParaLoc^.Reference.Index,lCallerParaLoc^.Reference.Offset,CTempPosInvalid,lCallerAlignment,[]);
                              { copy parameters in case they were moved to a temp. location because we've a fixed stack }
                              case lTempParaLoc^.Loc of
                              LOC_REFERENCE:
                                  begin
                                    Reference_Reset_Base(lTempRef,lTempParaLoc^.Reference.Index,lTempParaLoc^.Reference.Offset,CTempPosInvalid,lTempAlignment,[]);
                                    { use concatcopy, because it can also be a float which fails when
                                      load_ref_ref is used }
                                    if (lTempParaLoc^.Size <> OS_NO) then
                                      cg.G_ConcatCopy(CurrentAsmData.CurrAsmList,lTempRef,lReference,TCgSize2Size[lTempParaLoc^.Size])
                                    else
                                      cg.G_ConcatCopy(CurrentAsmData.CurrAsmList,lTempRef,lReference,lSizeLeft)
                                  end;
                                LOC_REGISTER:
                                  cg.A_Load_Reg_Ref(CurrentAsmData.CurrAsmList,lTempParaLoc^.Size,lTempParaLoc^.Size,lTempParaLoc^.Register,lReference);
                                LOC_FPUREGISTER:
                                  cg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,lTempParaLoc^.Size,lTempParaLoc^.Size,lTempParaLoc^.Register,lReference);
                                LOC_MMREGISTER:
                                  cg.A_LoadMM_Reg_Ref(CurrentAsmData.CurrAsmList,lTempParaLoc^.Size,lTempParaLoc^.Size,lTempParaLoc^.Register,lReference,MMS_MoveScalar);
                                else
                                  InternalError(200402081);
                             end;
                           end;
                         end;
                       LOC_VOID:
                         ;
                       else
                         InternalError(2019050707);
                     end;
                     dec(lSizeLeft,TCgSize2Size[lTempParaLoc^.Size]);
                     lCallerParaLoc:=lCallerParaLoc^.next;
                     lTempParaLoc:=lTempParaLoc^.next;
                   end;
               end;
             lPara:=TCGCallParaNode(lPara.Right);
           end;
         SetLength(FParaLocs,ProcDefinition.paras.count);
         for lIndex:=0 to ProcDefinition.paras.count-1 do
           FParaLocs[lIndex]:=@TParaVarSym(ProcDefinition.paras[lIndex]).ParaLoc[callerside];
       end;


     procedure TCGCallNode.Load_Complex_ProcVar_CodePtr(out AReg: TRegister; out ACallProcDef: TAbstractProcDef);
       var
         lSourceReg: TRegister;
       begin
         { this is safe even on i8086, because procvardef code pointers are
           always far there (so the current state of far calls vs the state
           of far calls where the procvardef was defined does not matter,
           even though the procvardef constructor called by getcopyas looks at
           it) }
         ACallProcDef:=CProcVarDef.GetReusableProcAddr(ProcDefinition,pc_address_only);
         AReg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ACallProcDef);
         { in case we have a method pointer on a big endian target in registers,
           the method address is stored in registerhi (it's the first field
           in the tmethod record) }
         if (Right.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
           begin
             if not(Right.Location.Size in [OSPair,OSSPair]) then
               InternalError(2014081401);
             if (TargetInfo.endian=endian_big) then
               lSourceReg:=Right.Location.RegisterHi
             else
               lSourceReg:=Right.Location.Register;
             hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,ACallProcDef,ACallProcDef,lSourceReg,AReg)
           end
         else
           begin
             hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,Right.Location,ProcDefinition);
             hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(ProcDefinition),CPointerDef.getreusable(ACallProcDef),Right.Location.Reference);
             hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,ACallProcDef,ACallProcDef,Right.Location.Reference,AReg);
           end;
       end;


     procedure TCGCallNode.Load_ProcVar_CodePtr(out AReg: TRegister; out ACallProcDef: TAbstractProcDef);
       begin
         if po_is_block in ProcDefinition.ProcOptions then
           Load_Block_Invoke(AReg,ACallProcDef)
         else if not(ProcDefinition.Is_AddressOnly) then
           Load_Complex_ProcVar_CodePtr(AReg,ACallProcDef)
         else
           begin
             AReg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,ProcDefinition);
             hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,ProcDefinition,ProcDefinition,Right.Location,AReg);
             ACallProcDef:=ProcDefinition;
           end;
         ACallProcDef.Init_ParaLoc_Info(callerside);
       end;


     procedure TCGCallNode.FreeParas;
       var
         lPara : TCGCallParaNode;
       begin
         { free the resources allocated for the parameters }
         lPara:=TCGCallParaNode(Left);
         while Assigned(lPara) do
           begin
             if (lPara.Left.NodeType<>nothingn) then
               begin
                 if (lPara.ParaSym.ParaLoc[callerside].Location^.Loc <> LOC_REFERENCE) then
                   ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lPara.ParaSym.ParaLoc[callerside]);
               end;
             lPara:=TCGCallParaNode(lPara.Right);
           end;
       end;


    function TCGCallNode.IsParentFPpushed: Boolean;
      begin
        Result:=(ProcDefinition.typ<>procdef) or
          not CanSkipParaPush(TParaVarSym(TProcDef(ProcDefinition).ParentFPSym));
      end;


    procedure TCGCallNode.Pass_Generate_Code;
      var
        lNameToCall: TSymStr;
        lIntRegsToSave,
        lAddressRegsToSave,
        lFPURegsToSave,
        lMMRegsToSave   : TCPURegisterSet;
        lReference : TReference;
        lPopSize : LongInt;
        lProcVarReg : TRegister;
        lResultParaLocItem: PCGParaLocation;
        lCallProcVarDef: TAbstractProcDef;
        lProcDef : TProcDef;
        lCallReference: Boolean;
{$ifdef vtentry}
        lAsmSym : TAsmSymbol;
        lVMTOffset : AInt;
{$endif vtentry}
        lCGPara : TCGPara;
        lTempLoc: TLocation;
      begin
         if not Assigned(ProcDefinition) or
            not(ProcDefinition.HasParaLocInfo in [callerside,callbothsides]) then
           InternalError(200305264);

         Extra_Pre_Call_Code;

         if Assigned(CallInitBlock) then
           SecondPass(TNode(CallInitBlock));

         lIntRegsToSave:=ParaManager.Get_Volatile_Registers_Int(ProcDefinition.ProcCallOption);
         lAddressRegsToSave:=ParaManager.Get_Volatile_Registers_Address(ProcDefinition.ProcCallOption);
         lFPURegsToSave:=ParaManager.Get_Volatile_Registers_FPU(ProcDefinition.ProcCallOption);
         lMMRegsToSave:=ParaManager.Get_Volatile_Registers_MM(ProcDefinition.ProcCallOption);

         { Include Function result registers }
         if (not Is_Void(ResultDef)) then
          begin
            { The forced returntype may have a different size than the one
              declared for the procdef }
            FResultParaLoc:=hlcg.Get_Call_Result_CGPara(ProcDefinition,TypeDef);
            lResultParaLocItem:=FResultParaLoc.Location;
            while Assigned(lResultParaLocItem) do
              begin
                case lResultParaLocItem^.Loc of
                  LOC_REGISTER:
                    case GetRegType(lResultParaLocItem^.Register) of
                      R_INTREGISTER:
                        include(lIntRegsToSave,GetSupReg(lResultParaLocItem^.Register));
                      R_ADDRESSREGISTER:
                        include(lAddressRegsToSave,GetSupReg(lResultParaLocItem^.Register));
                      R_TEMPREGISTER:
                        ;
                      else
                        InternalError(2014020102);
                      end;
                  LOC_FPUREGISTER:
                    include(lFPURegsToSave,GetSupReg(lResultParaLocItem^.Register));
                  LOC_MMREGISTER:
                    include(lMMRegsToSave,GetSupReg(lResultParaLocItem^.Register));
                  LOC_REFERENCE,
                  LOC_VOID:
                    ;
                  else
                    InternalError(2004110213);
                end;
                lResultParaLocItem:=lResultParaLocItem^.next;
              end;
          end;

         if Assigned(Left) then
           TCallParaNode(Left).SecondCallParaN;

         { procedure variable or normal function call ? }
         if (Right=nil) then
           begin
             { register call for WPO (must be done before wpo test below,
               otherwise optimised called methods are no longer registered)
             }
             if (po_virtualmethod in ProcDefinition.ProcOptions) and
                not Is_ObjectPascal_Helper(TProcDef(ProcDefinition).struct) and
                Assigned(MethodPointer) and
                (MethodPointer.NodeType<>typen) and
                (not Assigned(CurrentProcInfo) or
                 wpoinfomanager.symbol_live(CurrentProcInfo.procdef.MangledName)) then
               TObjectDef(TProcDef(ProcDefinition).struct).Register_VMT_Call(TProcDef(ProcDefinition).ExtNumber);
{$ifdef vtentry}
             if not Is_Interface(TProcDef(ProcDefinition)._class) then
               begin
                 inc(CurrentAsmData.NextVTEntryNr);
                 CurrentAsmData.CurrAsmList.Concat(TAISymbol.CreateName('VTREF'+ToStr(CurrentAsmData.NextVTEntryNr)+'_'+TProcDef(ProcDefinition).struct.VMT_MangledName+'$$'+ToStr(lVMTOffset div sizeof(PInt)),AT_FUNCTION,0,voidpointerdef));
               end;
{$endif vtentry}

             { When methodpointer is typen we don't need (and can't) load
               a pointer. We can directly call the correct procdef (PFV) }
             lNameToCall:='';
             if not Assigned(OverrideProcNameDef) and
                (po_virtualmethod in ProcDefinition.ProcOptions) and
                not Is_ObjectPascal_Helper(TProcDef(ProcDefinition).struct) and
                Assigned(MethodPointer) and
                (MethodPointer.NodeType<>typen) and
                not wpoinfomanager.can_be_devirtualized(MethodPointer.ResultDef,ProcDefinition,lNameToCall) then
               begin
                 { virtual methods require an index }
                 if TProcDef(ProcDefinition).ExtNumber=$ffff then
                   InternalError(200304021);

                 { load the VMT entry (address of the virtual method) }
                 SecondPass(VMTEntry);

                 { register call for WPO }
                 if (not Assigned(CurrentProcInfo) or
                     wpoinfomanager.symbol_live(CurrentProcInfo.procdef.MangledName)) then
                   TObjectDef(TProcDef(ProcDefinition).struct).Register_VMT_Call(TProcDef(ProcDefinition).ExtNumber);

                 if not(VMTEntry.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                   InternalError(2015052502);
                 lReference:=VMTEntry.Location.Reference;
                 lProcVarReg:=NR_NO;

                 lCallReference:=Can_Call_Ref(lReference);
                 if not lCallReference then
                   begin
                     lProcVarReg:=Get_Call_Reg(CurrentAsmData.CurrAsmList);
                     hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,
                       VMTEntry.ResultDef,VMTEntry.ResultDef,
                       lReference,lProcVarReg);
                   end;

                 { Load parameters that are in temporary registers in the
                   correct parameter register }
                 if Assigned(Left) then
                   begin
                     ReorderParameters;
                     PushParas;
                   end;

                 if lCallReference then
                   Extra_Call_Ref_Code(lReference);

                 cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,lIntRegsToSave);
                 if cg.Uses_Registers(R_ADDRESSREGISTER) then
                   cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_ADDRESSREGISTER,lAddressRegsToSave);
                 if cg.Uses_Registers(R_FPUREGISTER) then
                   cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_FPUREGISTER,lFPURegsToSave);
                 if cg.Uses_Registers(R_MMREGISTER) then
                   cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_MMREGISTER,lMMRegsToSave);

                 { call method }
                 Extra_Call_Code;
                 FResultParaLoc.ResetIfTemp;
                 if lCallReference then
                   FResultParaLoc:=Do_Call_Ref(lReference)
                 else
                   begin
                     hlcg.G_PtrTypeCast_Reg(CurrentAsmData.CurrAsmList,VMTEntry.ResultDef,CPointerDef.getreusable(ProcDefinition),lProcVarReg);
                     FResultParaLoc:=hlcg.A_Call_Reg(CurrentAsmData.CurrAsmList,TAbstractProcDef(ProcDefinition),lProcVarReg,FParaLocs);
                     UnGet_Call_Reg(CurrentAsmData.CurrAsmList,lProcVarReg);
                   end;

                 Extra_Post_Call_Code;
               end
             else
               begin
                  { Load parameters that are in temporary registers in the
                    correct parameter register }
                  if Assigned(Left) then
                    begin
                      ReorderParameters;
                      PushParas;
                    end;

                  cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,lIntRegsToSave);
                  if cg.Uses_Registers(R_ADDRESSREGISTER) then
                    cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_ADDRESSREGISTER,lAddressRegsToSave);
                  if cg.Uses_Registers(R_FPUREGISTER) then
                    cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_FPUREGISTER,lFPURegsToSave);
                  if cg.Uses_Registers(R_MMREGISTER) then
                    cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_MMREGISTER,lMMRegsToSave);

                  { Calling interrupt from the same code requires some
                    extra code }
                  if (po_interrupt in ProcDefinition.ProcOptions) then
                    Extra_Interrupt_Code;
                  Extra_Call_Code;
                  FResultParaLoc.ResetIfTemp;
                  if lNameToCall='' then
                    begin
                      if not Assigned(OverrideProcNameDef) then
                        lNameToCall:=TProcDef(ProcDefinition).MangledName
                      else
                        lNameToCall:=OverrideProcNameDef.MangledName;
                    end;
                  if cnf_inherited in CallNodeFlags then
                    FResultParaLoc:=hlcg.A_Call_Name_Inherited(CurrentAsmData.CurrAsmList,TProcDef(ProcDefinition),lNameToCall,FParaLocs)
                  { under certain conditions, a static call (i.e. without PIC) can be generated }
                  else if ((ProcDefinition.owner=CurrentProcInfo.procdef.owner) or
                     (ProcDefinition.owner.SymTableType in [LocalSymTable,staticsymtable])
                    ) and ((ProcDefinition.ProcOptions*[po_weakexternal,po_external])=[]) then
                    FResultParaLoc:=hlcg.A_Call_Name_Static(CurrentAsmData.CurrAsmList,TProcDef(ProcDefinition),lNameToCall,FParaLocs,TypeDef)
                  else
                    FResultParaLoc:=hlcg.A_Call_Name(CurrentAsmData.CurrAsmList,TProcDef(ProcDefinition),lNameToCall,FParaLocs,TypeDef,po_weakexternal in ProcDefinition.ProcOptions);
                  Extra_Post_Call_Code;
               end;
           end
         else
           { now procedure variable case }
           begin
              SecondPass(Right);

              { can we directly call the procvar in a memory location? }
              lCallReference:=false;
              if not(po_is_block in ProcDefinition.ProcOptions) and
                 (Right.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                begin
                  lReference:=Right.Location.Reference;
                  lCallReference:=Can_Call_Ref(lReference);
                end;

              if not lCallReference then
                Load_ProcVar_CodePtr(lProcVarReg,lCallProcVarDef)
              else
                begin
                  lProcVarReg:=NRInvalid;
                  lCallProcVarDef:=nil;
                end;
              Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);

              { Load parameters that are in temporary registers in the
                correct parameter register }
              if Assigned(Left) then
                begin
                  ReorderParameters;
                  PushParas;
                end;

              if lCallReference then
                Extra_Call_Ref_Code(lReference);

              cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,lIntRegsToSave);
              if cg.Uses_Registers(R_ADDRESSREGISTER) then
                cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_ADDRESSREGISTER,lAddressRegsToSave);
              if cg.Uses_Registers(R_FPUREGISTER) then
                cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_FPUREGISTER,lFPURegsToSave);
              if cg.Uses_Registers(R_MMREGISTER) then
                cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_MMREGISTER,lMMRegsToSave);

              { Calling interrupt from the same code requires some
                extra code }
              if (po_interrupt in ProcDefinition.ProcOptions) then
                Extra_Interrupt_Code;
              Extra_Call_Code;

              FResultParaLoc.ResetIfTemp;
              if lCallReference then
                FResultParaLoc:=Do_Call_Ref(lReference)
              else
                FResultParaLoc:=hlcg.A_Call_Reg(CurrentAsmData.CurrAsmList,lCallProcVarDef,lProcVarReg,FParaLocs);
              Extra_Post_Call_Code;
           end;

         { free the resources allocated for the parameters }
         if Assigned(Left) then
           FreeParas;

         { Release registers, but not the registers that contain the
           function result }
         if (not Is_Void(ResultDef)) then
           begin
             lResultParaLocItem:=FResultParaLoc.Location;
             while Assigned(lResultParaLocItem) do
               begin
                 case lResultParaLocItem^.Loc of
                   LOC_REGISTER:
                     case GetRegType(lResultParaLocItem^.Register) of
                       R_INTREGISTER:
                         exclude(lIntRegsToSave,GetSupReg(lResultParaLocItem^.Register));
                       R_ADDRESSREGISTER:
                         exclude(lAddressRegsToSave,GetSupReg(lResultParaLocItem^.Register));
                       R_TEMPREGISTER:
                         ;
                       else
                         InternalError(2014020103);
                     end;
                   LOC_FPUREGISTER:
                     exclude(lFPURegsToSave,GetSupReg(lResultParaLocItem^.Register));
                   LOC_MMREGISTER:
                     exclude(lMMRegsToSave,GetSupReg(lResultParaLocItem^.Register));
                   LOC_REFERENCE,
                   LOC_VOID:
                     ;
                   else
                     InternalError(2004110214);
                 end;
                 lResultParaLocItem:=lResultParaLocItem^.next;
               end;
           end;

         if cg.Uses_Registers(R_MMREGISTER) then
           cg.DeallocCPURegisters(CurrentAsmData.CurrAsmList,R_MMREGISTER,lMMRegsToSave);
         if cg.Uses_Registers(R_FPUREGISTER) then
           cg.DeallocCPURegisters(CurrentAsmData.CurrAsmList,R_FPUREGISTER,lFPURegsToSave);
         if cg.Uses_Registers(R_ADDRESSREGISTER) then
           cg.DeallocCPURegisters(CurrentAsmData.CurrAsmList,R_ADDRESSREGISTER,lAddressRegsToSave);
         cg.DeallocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,lIntRegsToSave);

         { Need to remove the parameters from the stack? }
         if ProcDefinition.ProcCallOption in ClearStack_PoCalls then
           begin
             lPopSize:=FPushedParaSize;
             { for Cdecl functions we don't need to pop the funcret when it
               was pushed by para. Except for safecall functions with
               safecall-exceptions enabled. In that case the funcret is always
               returned as a para which is considered a normal para on the
               c-side, so the funcret has to be pop'ed normally. }
             if not ((ProcDefinition.ProcCallOption=pocall_safecall) and
                     (tf_safecall_exceptions in TargetInfo.Flags)) and
                ParaManager.Ret_In_Param(ProcDefinition.ReturnDef,ProcDefinition) then
               dec(lPopSize,sizeof(PInt));
             { Remove parameters/alignment from the stack }
             Pop_ParaSize(lPopSize);
           end
         { in case we use a fixed stack, we did not push anything, if the stack is
           really adjusted because a ret xxx was done, depends on
           pop_parasize which uses FPushedParaSize to determine this

           This does not apply to interrupt procedures, their ret statement never clears any stack parameters }
         else if ParaManager.Use_Fixed_Stack and
                 not(po_interrupt in ProcDefinition.ProcOptions) and
                 (TargetInfo.abi=abi_i386_dynalignedstack) then
           begin
             { however, a delphi style frame pointer for a nested subroutine
               is not cleared by the callee, so we have to compensate for this
               by passing 4 as FPushedParaSize does include it }
             if po_delphi_nested_cc in ProcDefinition.ProcOptions then
               Pop_ParaSize(sizeof(PInt))
             else
               Pop_ParaSize(0);
           end
         { frame pointer parameter is popped by the caller when it's passed the
           Delphi way and $parentfp is used }
         else if (po_delphi_nested_cc in ProcDefinition.ProcOptions) and
            not ParaManager.Use_Fixed_Stack and
            IsParentFPpushed() then
           Pop_ParaSize(sizeof(PInt));

         if ProcDefinition.Generate_SafeCall_Wrapper then
           begin
             lProcDef:=Search_System_Proc('fpc_safecallcheck');
             lCGPara.init;
             { fpc_safecallcheck returns its parameter value (= function result of function we just called) }
             ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,lProcDef,1,lCGPara);
             Location_Reset(lTempLoc,LOC_REGISTER,Def_CGSize(FResultParaLoc.Def));
             lTempLoc.Register:=hlcg.GetRegisterForDef(CurrentAsmData.CurrAsmList,FResultParaLoc.Def);
             hlcg.Gen_Load_CGPara_Loc(CurrentAsmData.CurrAsmList,FResultParaLoc.Def,FResultParaLoc,lTempLoc,true);
             ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lCGPara);
             hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,FResultParaLoc.Def,lTempLoc,lCGPara);
             FResultParaLoc.ResetIfTemp;
             FResultParaLoc:=hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,lProcDef,[@lCGPara],nil);
             lCGPara.done;
           end;

         { handle function results }
         if (not Is_Void(ResultDef)) then
           HandleReturnValue
         else
           Location_Reset(Location,LOC_VOID,OS_NO);

         { convert persistent temps for parameters and function result to normal temps }
         if Assigned(CallCleanupBlock) then
           SecondPass(TNode(CallCleanupBlock));

         { copy back copy-out parameters if any }
         CopyBackParas;

         { release temps and finalize unused return values, must be
           after the callcleanupblock because that converts temps
           from persistent to normal }
         ReleaseUnusedReturnValue;

         { release temps of paras }
         ReleaseParaTemps;

         { check for fpu exceptions }
         if cnf_check_fpu_exceptions in CallNodeFlags then
           cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);

         { perhaps i/o check ? }
         if (cs_check_io in CurrentSettings.LocalSwitches) and
            (po_iocheck in ProcDefinition.ProcOptions) and
            not(po_iocheck in CurrentProcInfo.procdef.ProcOptions) and
            { no IO check for methods and procedure variables }
            (Right=nil) and
            not(po_virtualmethod in ProcDefinition.ProcOptions) then
           begin
              hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,'fpc_iocheck',[],nil).ResetIfTemp;
              hlcg.G_Maybe_CheckForExceptions(CurrentAsmData.CurrAsmList);
           end;
      end;


    destructor TCGCallNode.Destroy;
      begin
        FResultParaLoc.ResetIfTemp;
        inherited Destroy;
      end;


begin
   CCallParaNode:=TCGCallParaNode;
   CCallNode:=TCGCallNode;
end.
