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
          procedure push_addr_para;
          procedure push_value_para;virtual;
          procedure push_formal_para;virtual;
          procedure push_copyout_para;virtual;abstract;
          function maybe_push_unused_para:boolean;virtual;

          procedure secondcallparan_do_secondpass;
          procedure secondcallparan_after_secondpass;
       public
          tempcgpara : TCGPara;

          constructor create(expr,next : TNode);override;
          destructor Destroy;override;
          procedure secondcallparan;override;
       end;

       { tcgcallnode }

       TCGCallNode = class(TCallNode)
       private
          procedure handle_return_value;
          procedure release_unused_return_value;
          procedure copy_back_paras;
          procedure release_para_temps;
          procedure reorder_parameters;
          procedure freeparas;
          function is_parentfp_pushed:boolean;
       protected
          retloc: TCGPara;
          paralocs: array of PCGPara;

          framepointer_paraloc : TCGPara;
          {# This routine is used to push the current frame pointer
             on the stack. This is used in nested routines where the
             value of the frame pointer is always pushed as an extra
             parameter.

             The default handling is the standard handling used on
             most stack based machines, where the frame pointer is
             the first invisible parameter.
          }
          procedure pop_parasize(pop_size:LongInt);virtual;
          procedure extra_interrupt_code;virtual;
          procedure extra_pre_call_code;virtual;
          procedure extra_call_code;virtual;
          procedure extra_post_call_code;virtual;

          function get_syscall_libbase_paraloc: PCGParaLocation;virtual;
          procedure get_syscall_call_ref(out tmpref: TReference; reg: TRegister);virtual;
          procedure do_syscall;virtual;abstract;

          { The function result is returned in a tcgpara. This tcgpara has to
            be translated into a tlocation so the rest of the code generator
            can work with it. This routine decides what the most appropriate
            tlocation is and sets self.location based on that. }
          procedure set_result_location(realresdef: TStoredDef);virtual;

          { if an unused return value is in another location than a
            LOC_REFERENCE, this method will be called to perform the necessary
            cleanups. By default it does not do anything }
          procedure do_release_unused_return_value;virtual;

          { Override the following three methods to support calls to address in
            'ref' without loading it into register (only x86 targets probably).
            If can_call_ref returns true, it should do required simplification
            on ref. }
          function can_call_ref(var ref: TReference):boolean;virtual;
          procedure extra_call_ref_code(var ref: TReference);virtual;
          function do_call_ref(ref: TReference): TCGPara;virtual;

          { store all the parameters in the temporary paralocs in their final
            location, and create the paralocs array that will be passed to
            hlcg.a_call_* }
          procedure pushparas;virtual;

          { loads the code pointer of a complex procvar (one with a self/
            parentfp/... and a procedure address) into a register and returns it }
          procedure load_complex_procvar_codeptr(out reg: TRegister; out callprocdef: TAbstractProcDef); virtual;
          { loads the procvar code pointer into a register with type def }
          procedure load_procvar_codeptr(out reg: TRegister; out callprocdef: TAbstractProcDef);

          procedure load_block_invoke(out toreg: TRegister; out callprocdef: TAbstractProcDef);

          function get_call_reg(list: TAsmList): TRegister; virtual;
          procedure unget_call_reg(list: TAsmList; reg: TRegister); virtual;
       public
          procedure pass_generate_code;override;
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


    function can_skip_para_push(parasym: TParaVarSym): boolean;
      begin
        { We can skip passing the parameter when:
            the parameter can be optimized as unused
            and the target does not strictly require all parameters (has_strict_proc_signature = false)
            and
                 fixed stack is used
              or the parameter is in a register
              or the parameter is $parentfp and po_delphi_nested_cc is set for the routine. }
        result:=ParaManager.Can_Opt_Unused_Para(parasym) and
          not ParaManager.Has_Strict_Proc_Signature and
          (ParaManager.Use_Fixed_Stack or
           ((vo_is_parentfp in parasym.VarOptions) and
            (po_delphi_nested_cc in TAbstractProcDef(parasym.owner.DefOwner).ProcOptions)) or
           (parasym.ParaLoc[callerside].Location^.Loc in [LOC_REGISTER,LOC_CREGISTER]));
      end;

{*****************************************************************************
                             TCGCALLPARANODE
*****************************************************************************}

    constructor TCGCallParaNode.create(expr,next : TNode);
      begin
        inherited create(expr,next);
        tempcgpara.init;
      end;


    destructor TCGCallParaNode.Destroy;
      begin
        tempcgpara.done;
        inherited Destroy;
      end;


    procedure TCGCallParaNode.push_addr_para;
      var
        ValueDef: TDef;
      begin
        if not(left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
          InternalError(200304235);
        if maybe_push_unused_para then
          exit;
        { see the call to keep_para_array_range in ncal: if that call returned
          true, we overwrite the resultdef of left with its original resultdef
          (to keep track of the range of the original array); we inserted a type
          conversion to parasym.vardef, so that is the type this value actually
          has }
        if Is_Dynamic_Array(left.resultdef) and
           Is_Open_Array(parasym.vardef) then
          ValueDef:=parasym.vardef
        else
          ValueDef:=left.resultdef;
        hlcg.A_LoadAddr_Ref_CGPara(CurrentAsmData.CurrAsmList,ValueDef,left.Location.Reference,tempcgpara);
      end;


    procedure TCGCallNode.reorder_parameters;
      var
        hpcurr,hpprev,hpnext,hpreversestart : TCGCallParaNode;
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
        hpcurr:=TCGCallParaNode(left);
        { assume all LOC_REFERENCE parameters come first
          (see tcallnode.order_parameters)
        }
        hpreversestart:=nil;
        while Assigned(hpcurr) do
          begin
            if not(hpcurr.parasym.ParaLoc[callerside].Location^.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
              hpreversestart:=hpcurr;
            hpcurr:=TCGCallParaNode(hpcurr.right);
          end;

        { since all register tempparalocs have basically a complexity of 1,
          (unless there are large stack offsets that require a temp register on
          some architectures, but that's minor), we don't have to care about
          the internal relative order of different register type parameters
        }
        hpprev:=nil;
        hpcurr:=TCGCallParaNode(left);
        while (hpcurr<>hpreversestart) do
          begin
            hpnext:=TCGCallParaNode(hpcurr.right);
            if not(hpcurr.parasym.ParaLoc[callerside].Location^.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
              begin
                { remove hpcurr from chain }
                if Assigned(hpprev) then
                  hpprev.right:=hpnext
                else
                  left:=hpnext;
                { insert right after hpreversestart, so every element will
                  be inserted right before the previously moved one ->
                  reverse order; hpreversestart itself is the last register
                  parameter }
                hpcurr.right:=hpreversestart.right;
                hpreversestart.right:=hpcurr;
              end
            else
              hpprev:=hpcurr;
            hpcurr:=hpnext;
          end;
      end;


    procedure TCGCallParaNode.push_value_para;
      begin
        { Permissive backends do not need parameters with no storage. }
        if (left.resultdef.Size=0) and
           not ParaManager.Has_Strict_Proc_Signature then
          exit;

        if maybe_push_unused_para then
          exit;

        { Move flags and jump in register to make it less complex }
        if left.Location.Loc in [LOC_FLAGS,LOC_JUMP,LOC_SUBSETREG,LOC_CSUBSETREG,LOC_SUBSETREF,LOC_CSUBSETREF] then
          hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);

        { load the parameter's tlocation into its cgpara }
        hlcg.Gen_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,left.resultdef,left.Location,tempcgpara)
      end;


    procedure TCGCallParaNode.push_formal_para;
      begin
        if maybe_push_unused_para then
          exit;
        { allow passing of a constant to a const formaldef }
        if (parasym.VarSpez=vs_const) and
           not(left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
          hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);
        push_addr_para;
      end;


    function TCGCallParaNode.maybe_push_unused_para: boolean;
      begin
        { Check if the parameter is unused and can be optimized }
        result:=ParaManager.Can_Opt_Unused_Para(parasym);
        if not result then
          exit;
        { If we can't skip loading of the parameter, load an undefined dummy value. }
        if not can_skip_para_push(parasym) then
          begin
            if cs_asm_source in CurrentSettings.GlobalSwitches then
              CurrentAsmData.CurrAsmList.concat(TAIComment.Create(StrPNew('Parameter '+parasym.realname+' is unused, loading undefined value')));
            hlcg.A_Load_Undefined_CGPara(CurrentAsmData.CurrAsmList,left.resultdef,tempcgpara);
          end
        else
          if cs_asm_source in CurrentSettings.GlobalSwitches then
            CurrentAsmData.CurrAsmList.concat(TAIComment.Create(StrPNew('Parameter '+parasym.realname+' is unused')));
      end;


    procedure TCGCallParaNode.secondcallparan_do_secondpass;
      begin
        if Assigned(fparainit) then
          SecondPass(fparainit);
        SecondPass(left);
      end;


    procedure TCGCallParaNode.secondcallparan_after_secondpass;
      var
        pushaddr: boolean;
      begin
        hlcg.Maybe_Change_Load_Node_Reg(CurrentAsmData.CurrAsmList,left,true);

        ParaManager.CreateTempParaLoc(CurrentAsmData.CurrAsmList,callnode.procdefinition.ProcCallOption,parasym,not followed_by_stack_tainting_call_cached,tempcgpara);

        { handle varargs first, because parasym is not valid }
        if (cpf_varargs_para in callparaflags) then
          begin
            if ParaManager.Push_Addr_Param(vs_value,left.resultdef,
                   callnode.procdefinition.ProcCallOption) then
              push_addr_para
            else
              push_value_para;
          end
        { hidden parameters }
        else if (vo_is_hidden_para in parasym.VarOptions) then
          begin
            { don't push a node that already generated a pointer type
              by address for implicit hidden parameters }
            pushaddr:=(vo_is_funcret in parasym.VarOptions) or
              { pass "this" in C++ classes explicitly as pointer
                because push_addr_param might not be true for them }
              (Is_CPPClass(parasym.vardef) and (vo_is_self in parasym.VarOptions)) or
               (
                 (
                   not(left.resultdef.typ in [pointerdef,classrefdef]) or
                   (
                     { allow pointerdefs (as self) to be passed as addr
                       param if the method is part of a type helper which
                       extends a pointer type }
                     (vo_is_self in parasym.VarOptions) and
                     (callnode.procdefinition.owner.SymTableType=objectsymtable) and
                     (Is_ObjectPascal_Helper(TDef(callnode.procdefinition.owner.DefOwner))) and
                     (TObjectDef(callnode.procdefinition.owner.DefOwner).ExtendedDef.typ=pointerdef)
                   )
                 ) and
                ParaManager.Push_Addr_Param(parasym.VarSpez,parasym.vardef,
                    callnode.procdefinition.ProcCallOption));

            if pushaddr then
              begin
                { objects or advanced records could be located in registers if they are the result of a type case, see e.g. tbs\tw26075.pas }
                if not(left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
                  hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);
                push_addr_para
              end
            else
              push_value_para;
          end
        { formal def }
        else if (parasym.vardef.typ=formaldef) then
          push_formal_para
        { Normal parameter }
        else if ParaManager.Push_CopyOut_Param(parasym.VarSpez,parasym.vardef,
                    callnode.procdefinition.ProcCallOption) then
          push_copyout_para
        else
          begin
            { don't push a node that already generated a pointer type
              by address for implicit hidden parameters }
            if (not(
                    (vo_is_hidden_para in parasym.VarOptions) and
                    (left.resultdef.typ in [pointerdef,classrefdef])
                   ) and
                ParaManager.Push_Addr_Param(parasym.VarSpez,parasym.vardef,
                    callnode.procdefinition.ProcCallOption)) and
                { dyn. arrays passed to an array of const must be passed by value, see tests/tbs/tb_arrays_objfpc_run_02.pas (case tw4219.pas) }
                not(
                    Is_Array_Of_Const(parasym.vardef) and
                    Is_Dynamic_Array(left.resultdef)
                   ) then
              begin
                 { Passing a var parameter to a var parameter, we can
                   just push the address transparently }
                 if (left.nodetype=loadn) and
                    (TLoadNode(left).is_addr_param_load) then
                   begin
                     if (left.Location.Reference.Index<>NR_NO) or
                        (left.Location.Reference.Offset<>0) then
                       InternalError(200410107);
                     hlcg.A_Load_Reg_CGPara(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(left.resultdef),left.Location.Reference.Base,tempcgpara)
                   end
                 else
                   begin
                     { Force to be in memory }
                     if not(left.Location.Loc in [LOC_CREFERENCE,LOC_REFERENCE]) then
                       hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,left.Location,left.resultdef);
                     push_addr_para;
                   end;
              end
            else
              push_value_para;
          end;

        { update return location in callnode when this is the function
          result }
        if Assigned(parasym) and
           (
             { for type helper/record constructor check that it is self parameter }
             (
               (vo_is_self in parasym.VarOptions) and
               (callnode.procdefinition.ProcTypeOption=potype_constructor) and
               (parasym.vardef.typ<>objectdef)
             ) or
             (vo_is_funcret in parasym.VarOptions)
           ) then
          Location_Copy(callnode.Location,left.Location);
      end;


    procedure TCGCallParaNode.secondcallparan;
      begin
         if not(Assigned(parasym)) then
           InternalError(200304242);

         { Skip nothingn nodes which are used after disabling
           a parameter }
         if (left.nodetype<>nothingn) then
           begin
             secondcallparan_do_secondpass;
             secondcallparan_after_secondpass;
           end;

         { next parameter }
         if Assigned(right) then
           TCallParaNode(right).secondcallparan;
      end;


{*****************************************************************************
                             TCGCALLNODE
*****************************************************************************}

    procedure TCGCallNode.extra_interrupt_code;
      begin
      end;


    procedure TCGCallNode.extra_pre_call_code;
      begin
      end;


    procedure TCGCallNode.extra_call_code;
      begin
      end;


    procedure TCGCallNode.extra_post_call_code;
      begin
      end;

    function TCGCallNode.get_syscall_libbase_paraloc: PCGParaLocation;
      var
        hsym: TSym;
      begin
        hsym:=TSym(procdefinition.ParaST.Find('syscalllib'));
        if not Assigned(hsym) then
          InternalError(2016110605);
        result:=TParaVarSym(hsym).ParaLoc[callerside].Location;
        if not Assigned(result) then
          InternalError(2016110604);
      end;

    procedure TCGCallNode.get_syscall_call_ref(out tmpref: TReference; reg: TRegister);
      var
        libparaloc: PCGParaLocation;
      begin
        libparaloc:=get_syscall_libbase_paraloc;

        case libparaloc^.Loc of
          LOC_REGISTER:
            Reference_Reset_Base(tmpref,libparaloc^.Register,-TProcDef(procdefinition).ExtNumber,CTempPosInvalid,sizeof(PInt),[]);
          LOC_REFERENCE:
            begin
              Reference_Reset_Base(tmpref,libparaloc^.Reference.Index,libparaloc^.Reference.Offset,CTempPosInvalid,sizeof(PInt),[]);
              cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,tmpref,reg);
              Reference_Reset_Base(tmpref,reg,-TProcDef(procdefinition).ExtNumber,CTempPosInvalid,sizeof(PInt),[]);
            end;
          else
            begin
              Reference_Reset(tmpref,0,[]);
              InternalError(2016090205);
            end;
        end;
      end;

    function TCGCallNode.can_call_ref(var ref: TReference): boolean;
      begin
        result:=false;
      end;


    procedure TCGCallNode.extra_call_ref_code(var ref: TReference);
      begin
        { no action by default }
      end;


    function TCGCallNode.do_call_ref(ref: TReference): TCGPara;
      begin
        InternalError(2014012901);
        { silence warning }
        result.init;
      end;


    procedure TCGCallNode.load_block_invoke(out toreg: TRegister; out callprocdef: TAbstractProcDef);
      var
        href: TReference;
        literaldef: TRecordDef;
      begin
        literaldef:=get_block_literal_type_for_proc(TAbstractProcDef(right.resultdef));
        hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,CPointerDef.getreusable(literaldef),true);
        { load the invoke pointer }
        hlcg.Reference_Reset_Base(href,right.resultdef,right.Location.Register,0,CTempPosInvalid,right.resultdef.Alignment,[]);
        callprocdef:=CProcVarDef.GetReusableProcAddr(procdefinition,pc_address_only);
        toreg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,callprocdef);
        hlcg.G_Load_Field_Reg_By_Name(CurrentAsmData.CurrAsmList,literaldef,callprocdef,'INVOKE',href,toreg);
     end;


    function TCGCallNode.get_call_reg(list: TAsmList): TRegister;
      begin
        result:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,procdefinition.Address_Type);
      end;


    procedure TCGCallNode.unget_call_reg(list: TAsmList; reg: TRegister);
      begin
        { nothing to do by default }
      end;


    procedure TCGCallNode.set_result_location(realresdef: TStoredDef);
      begin
        if realresdef.Is_IntRegable or
           realresdef.Is_FPURegable or
           { avoid temporarily storing pointer-sized entities that can't be
             regvars, such as reference-counted pointers, to memory --
             no exception can occur right now (except in case of existing
             memory corruption), and we'd store them to a regular temp
             anyway and that is not safer than keeping them in a register }
           ((realresdef.Size=sizeof(aint)) and
            (retloc.Location^.Loc=LOC_REGISTER) and
            not Assigned(retloc.Location^.next)) then
          location_allocate_register(CurrentAsmData.CurrAsmList,location,realresdef,false)
        else
          begin
            Location_Reset_Ref(location,LOC_REFERENCE,Def_CGSize(realresdef),0,[]);
            tg.GetHLTemp(CurrentAsmData.CurrAsmList,realresdef,retloc.IntSize,tt_normal,location.Reference);
          end;
      end;


    procedure TCGCallNode.do_release_unused_return_value;
      begin
        case location.Loc of
          LOC_REFERENCE :
            begin
              if Is_Managed_Type(resultdef) then
                 hlcg.G_Finalize(CurrentAsmData.CurrAsmList,resultdef,location.Reference);
               tg.ungetiftemp(CurrentAsmData.CurrAsmList,location.Reference);
            end;
          else
            ;
        end;
      end;


    procedure TCGCallNode.pop_parasize(pop_size:LongInt);
      begin
      end;


    procedure TCGCallNode.handle_return_value;
      var
        realresdef: TStoredDef;
      begin
        { Check that the return location is set when the result is passed in
          a parameter }
        if ParaManager.Ret_In_Param(resultdef,procdefinition) then
          begin
            { self.location is set near the end of secondcallparan so it
              refers to the implicit result parameter }
            if location.Loc<>LOC_REFERENCE then
              InternalError(200304241);
            exit;
          end;

        if not Assigned(typedef) then
          realresdef:=TStoredDef(resultdef)
        else
          realresdef:=TStoredDef(typedef);

          { get a tlocation that can hold the return value that's currently in
            the return value's tcgpara }
          set_result_location(realresdef);

          { Do not move the physical register to a virtual one in case
            the return value is not used, because if the virtual one is
            then mapped to the same register as the physical one, we will
            end up with two deallocs of this register (one inserted here,
            one inserted by the register allocator), which unbalances the
            register allocation information.  The return register(s) will
            be freed by location_free() in release_unused_return_value
            (mantis #13536).  }
          if (cnf_return_value_used in callnodeflags) or
             Assigned(funcretnode) then
            hlcg.Gen_Load_CGPara_Loc(CurrentAsmData.CurrAsmList,realresdef,retloc,location,false);

        if ((location.Loc=LOC_REGISTER) and
            not realresdef.Is_IntRegable) or
           ((location.Loc in [LOC_FPUREGISTER,LOC_MMREGISTER]) and
            (not realresdef.Is_FPURegable or
             ((location.Loc=LOC_MMREGISTER)<>Use_VectorFPU(realresdef)))) then
          begin
            hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,location,realresdef);
            { may have been record returned in a floating point register (-> location.size
              will be the size of the fpuregister instead of the int size of the record) }
            location.Size:=Def_CGSize(realresdef);
          end;

        { copy value to the final location if this was already provided to the
          callnode. This must be done after the call node, because the location can
          also be used as parameter and may not be finalized yet }
        if Assigned(funcretnode) then
          begin
            funcretnode.pass_generate_code;
            { Decrease refcount for refcounted types, this can be skipped when
              we have used a temp, because then it is already done from tempcreatenode.
              Also no finalize is needed, because there is no risk of exceptions from the
              function since this is code is only executed after the function call has returned }
            if Is_Managed_Type(funcretnode.resultdef) and
               (funcretnode.nodetype<>temprefn) then
              hlcg.G_Finalize(CurrentAsmData.CurrAsmList,funcretnode.resultdef,funcretnode.Location.Reference);

            case location.Loc of
              LOC_REGISTER :
                begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                  if location.Size in [OS_64,OS_S64] then
                    cg64.A_Load64_Reg_Loc(CurrentAsmData.CurrAsmList,location.Register64,funcretnode.Location)
                  else
{$endif}
                    hlcg.A_Load_Reg_Loc(CurrentAsmData.CurrAsmList,resultdef,resultdef,location.Register,funcretnode.Location);
                  location_free(CurrentAsmData.CurrAsmList,location);
                end;
              LOC_MMREGISTER :
                begin
                  hlcg.A_LoadMM_Reg_Loc(CurrentAsmData.CurrAsmList,resultdef,resultdef,location.Register,funcretnode.Location,nil);
                  location_free(CurrentAsmData.CurrAsmList,location);
                end;
              LOC_FPUREGISTER:
                begin
                  hlcg.A_LoadFPU_Reg_Loc(CurrentAsmData.CurrAsmList,resultdef,resultdef,location.Register,funcretnode.Location);
                  location_free(CurrentAsmData.CurrAsmList,location);
                end;
              LOC_REFERENCE:
                begin
                  case funcretnode.Location.Loc of
                    LOC_CREGISTER,
                    LOC_REGISTER:
                      hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,resultdef,resultdef,location.Reference,funcretnode.Location.Register);
                    LOC_CFPUREGISTER,
                    LOC_FPUREGISTER:
                      hlcg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,resultdef,resultdef,location.Reference,funcretnode.Location.Register);
                    LOC_REFERENCE:
                      hlcg.G_ConcatCopy(CurrentAsmData.CurrAsmList,resultdef,location.Reference,funcretnode.Location.Reference);
                    LOC_CMMREGISTER,
                    LOC_MMREGISTER:
                      hlcg.A_LoadMM_Reg_Ref(CurrentAsmData.CurrAsmList,resultdef,resultdef,funcretnode.Location.Register,location.Reference,nil);
                    else
                      InternalError(200802121);
                  end;
                  location_freetemp(CurrentAsmData.CurrAsmList,location);
                end;
              else
                InternalError(200709085);
            end;
            location := funcretnode.Location;
          end;
      end;


    procedure TCGCallNode.release_unused_return_value;
      begin
        { When the result is not used we need to finalize the result and
          can release the temp. This need to be after the callcleanupblock
          tree is generated, because that converts the temp from persistent to normal }
        if not(cnf_return_value_used in callnodeflags) then
          begin
            do_release_unused_return_value;
            if (retloc.IntSize<>0) then
              ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,retloc);
            Location_Reset(location,LOC_VOID,OS_NO);
         end;
      end;


    procedure TCGCallNode.copy_back_paras;
      var
        ppn : TCallParaNode;
      begin
        ppn:=TCallParaNode(left);
        while Assigned(ppn) do
          begin
             if Assigned(ppn.paracopyback) then
               SecondPass(ppn.paracopyback);
             ppn:=TCallParaNode(ppn.right);
          end;
      end;


    procedure TCGCallNode.release_para_temps;
      var
        hp,
        hp2 : TNode;
        ppn : TCallParaNode;
      begin
        { Release temps from parameters }
        ppn:=TCallParaNode(left);
        while Assigned(ppn) do
          begin
             if Assigned(ppn.left) then
               begin
                 { don't release the funcret temp }
                 if not(Assigned(ppn.parasym)) or
                    not(
                      (vo_is_funcret in ppn.parasym.VarOptions) or
                      (
                        (vo_is_self in ppn.parasym.VarOptions) and
                        (procdefinition.ProcTypeOption=potype_constructor) and
                        (ppn.parasym.vardef.typ<>objectdef)
                      )
                    )then
                   location_freetemp(CurrentAsmData.CurrAsmList,ppn.left.Location);
                 { process also all nodes of an array of const }
                 hp:=ppn.left;
                 while (hp.nodetype=typeconvn) do
                   hp:=TTypeConvNode(hp).left;
                 if (hp.nodetype=arrayconstructorn) and
                    Assigned(TArrayConstructorNode(hp).left) then
                   begin
                     while Assigned(hp) do
                       begin
                         hp2:=TArrayConstructorNode(hp).left;
                         { ignore typeconvs and addrn inserted by arrayconstructn for
                           passing a shortstring }
                         if (hp2.nodetype=typeconvn) and
                            (TUnaryNode(hp2).left.nodetype=addrn) then
                           hp2:=TUnaryNode(TUnaryNode(hp2).left).left
                         else if hp2.nodetype=addrn then
                           hp2:=TUnaryNode(hp2).left;
                         location_freetemp(CurrentAsmData.CurrAsmList,hp2.Location);
                         hp:=TArrayConstructorNode(hp).right;
                       end;
                   end;
               end;
             ppn:=TCallParaNode(ppn.right);
          end;
        SetLength(paralocs,0);
      end;


     procedure TCGCallNode.pushparas;
       var
         ppn : TCGCallParaNode;
         callerparaloc,
         tmpparaloc : PCGParaLocation;
         sizeleft: aint;
         htempref,
         href : TReference;
         calleralignment,
         tmpalignment, i: LongInt;
         skipiffinalloc: boolean;
       begin
         { copy all resources to the allocated registers }
         ppn:=TCGCallParaNode(left);
         while Assigned(ppn) do
           begin
             if (ppn.left.nodetype<>nothingn) and
               not can_skip_para_push(ppn.parasym) then
               begin
                 { better check for the real location of the parameter here, when stack passed parameters
                   are saved temporary in registers, checking for the tmpparaloc.loc is wrong
                 }
                 ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,ppn.tempcgpara);
                 tmpparaloc:=ppn.tempcgpara.Location;
                 sizeleft:=ppn.parasym.ParaLoc[callerside].IntSize;
                 calleralignment:=ppn.parasym.ParaLoc[callerside].Alignment;
                 tmpalignment:=ppn.tempcgpara.Alignment;
                 if (tmpalignment=0) or
                    (calleralignment=0) then
                   InternalError(2009020701);
                 callerparaloc:=ppn.parasym.ParaLoc[callerside].Location;
                 skipiffinalloc:=
                   not ParaManager.Use_Fixed_Stack or
                   not(ppn.followed_by_stack_tainting_call_cached);
                 while Assigned(callerparaloc) do
                   begin
                     { Every paraloc must have a matching tmpparaloc }
                     if not Assigned(tmpparaloc) then
                       InternalError(200408224);
                     if callerparaloc^.Size<>tmpparaloc^.Size then
                       InternalError(200408225);
                     case callerparaloc^.Loc of
                       LOC_REGISTER:
                         begin
                           if tmpparaloc^.Loc<>LOC_REGISTER then
                             InternalError(200408221);
                           if GetSupReg(callerparaloc^.Register)<first_int_imreg then
                             cg.GetCPURegister(CurrentAsmData.CurrAsmList,callerparaloc^.Register);
                           cg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,tmpparaloc^.Size,tmpparaloc^.Size,
                               tmpparaloc^.Register,callerparaloc^.Register);
                         end;
                       LOC_FPUREGISTER:
                         begin
                           if tmpparaloc^.Loc<>LOC_FPUREGISTER then
                             InternalError(200408222);
                           if GetSupReg(callerparaloc^.Register)<first_fpu_imreg then
                             cg.GetCPURegister(CurrentAsmData.CurrAsmList,callerparaloc^.Register);
                           cg.A_LoadFPU_Reg_Reg(CurrentAsmData.CurrAsmList,tmpparaloc^.Size,tmpparaloc^.Size,tmpparaloc^.Register,callerparaloc^.Register);
                         end;
                       LOC_MMREGISTER:
                         begin
                           if tmpparaloc^.Loc<>LOC_MMREGISTER then
                             InternalError(200408223);
                           if GetSupReg(callerparaloc^.Register)<first_mm_imreg then
                             cg.GetCPURegister(CurrentAsmData.CurrAsmList,callerparaloc^.Register);
                           cg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,tmpparaloc^.Size,tmpparaloc^.Size,
                             tmpparaloc^.Register,callerparaloc^.Register,MMS_MoveScalar);
                         end;
                       LOC_REFERENCE:
                         begin
                           if not(skipiffinalloc and
                                  ParaManager.Is_Stack_ParaLoc(callerparaloc)) then
                             begin
                               { Can't have a data copied to the stack, every location
                                 must contain a valid size field }

                              if (tmpparaloc^.Size=OS_NO) and
                                 ((tmpparaloc^.Loc<>LOC_REFERENCE) or
                                  Assigned(tmpparaloc^.next)) then
                                InternalError(200501281);
                                Reference_Reset_Base(href,callerparaloc^.Reference.Index,callerparaloc^.Reference.Offset,CTempPosInvalid,calleralignment,[]);
                              { copy parameters in case they were moved to a temp. location because we've a fixed stack }
                              case tmpparaloc^.Loc of
                              LOC_REFERENCE:
                                  begin
                                    Reference_Reset_Base(htempref,tmpparaloc^.Reference.Index,tmpparaloc^.Reference.Offset,CTempPosInvalid,tmpalignment,[]);
                                    { use concatcopy, because it can also be a float which fails when
                                      load_ref_ref is used }
                                    if (tmpparaloc^.Size <> OS_NO) then
                                      cg.G_ConcatCopy(CurrentAsmData.CurrAsmList,htempref,href,TCgSize2Size[tmpparaloc^.Size])
                                    else
                                      cg.G_ConcatCopy(CurrentAsmData.CurrAsmList,htempref,href,sizeleft)
                                  end;
                                LOC_REGISTER:
                                  cg.A_Load_Reg_Ref(CurrentAsmData.CurrAsmList,tmpparaloc^.Size,tmpparaloc^.Size,tmpparaloc^.Register,href);
                                LOC_FPUREGISTER:
                                  cg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,tmpparaloc^.Size,tmpparaloc^.Size,tmpparaloc^.Register,href);
                                LOC_MMREGISTER:
                                  cg.A_LoadMM_Reg_Ref(CurrentAsmData.CurrAsmList,tmpparaloc^.Size,tmpparaloc^.Size,tmpparaloc^.Register,href,MMS_MoveScalar);
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
                     dec(sizeleft,TCgSize2Size[tmpparaloc^.Size]);
                     callerparaloc:=callerparaloc^.next;
                     tmpparaloc:=tmpparaloc^.next;
                   end;
               end;
             ppn:=TCGCallParaNode(ppn.right);
           end;
         SetLength(paralocs,procdefinition.paras.count);
         for i:=0 to procdefinition.paras.count-1 do
           paralocs[i]:=@TParaVarSym(procdefinition.paras[i]).ParaLoc[callerside];
       end;


     procedure TCGCallNode.load_complex_procvar_codeptr(out reg: TRegister; out callprocdef: TAbstractProcDef);
       var
         srcreg: TRegister;
       begin
         { this is safe even on i8086, because procvardef code pointers are
           always far there (so the current state of far calls vs the state
           of far calls where the procvardef was defined does not matter,
           even though the procvardef constructor called by getcopyas looks at
           it) }
         callprocdef:=CProcVarDef.GetReusableProcAddr(procdefinition,pc_address_only);
         reg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,callprocdef);
         { in case we have a method pointer on a big endian target in registers,
           the method address is stored in registerhi (it's the first field
           in the tmethod record) }
         if (right.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
           begin
             if not(right.Location.Size in [OSPair,OSSPair]) then
               InternalError(2014081401);
             if (TargetInfo.endian=endian_big) then
               srcreg:=right.Location.RegisterHi
             else
               srcreg:=right.Location.Register;
             hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,callprocdef,callprocdef,srcreg,reg)
           end
         else
           begin
             hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,right.Location,procdefinition);
             hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(procdefinition),CPointerDef.getreusable(callprocdef),right.Location.Reference);
             hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,callprocdef,callprocdef,right.Location.Reference,reg);
           end;
       end;


     procedure TCGCallNode.load_procvar_codeptr(out reg: TRegister; out callprocdef: TAbstractProcDef);
       begin
         if po_is_block in procdefinition.ProcOptions then
           load_block_invoke(reg,callprocdef)
         else if not(procdefinition.Is_AddressOnly) then
           load_complex_procvar_codeptr(reg,callprocdef)
         else
           begin
             reg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,procdefinition);
             hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,procdefinition,procdefinition,right.Location,reg);
             callprocdef:=procdefinition;
           end;
         callprocdef.Init_ParaLoc_Info(callerside);
       end;


     procedure TCGCallNode.freeparas;
       var
         ppn : TCGCallParaNode;
       begin
         { free the resources allocated for the parameters }
         ppn:=TCGCallParaNode(left);
         while Assigned(ppn) do
           begin
             if (ppn.left.nodetype<>nothingn) then
               begin
                 if (ppn.parasym.ParaLoc[callerside].Location^.Loc <> LOC_REFERENCE) then
                   ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,ppn.parasym.ParaLoc[callerside]);
               end;
             ppn:=TCGCallParaNode(ppn.right);
           end;
       end;


    function TCGCallNode.is_parentfp_pushed: boolean;
      begin
        result:=(procdefinition.typ<>procdef) or
          not can_skip_para_push(TParaVarSym(TProcDef(procdefinition).ParentFPSym));
      end;


    procedure TCGCallNode.pass_generate_code;
      var
        name_to_call: TSymStr;
        regs_to_save_int,
        regs_to_save_address,
        regs_to_save_fpu,
        regs_to_save_mm   : TCPURegisterSet;
        href : TReference;
        pop_size : LongInt;
        pvreg : TRegister;
        retlocitem: PCGParaLocation;
        callpvdef: TAbstractProcDef;
        pd : TProcDef;
        callref: boolean;
{$ifdef vtentry}
        sym : TAsmSymbol;
        vmtoffset : aint;
{$endif vtentry}
        cgpara : TCGPara;
        tmploc: TLocation;
      begin
         if not Assigned(procdefinition) or
            not(procdefinition.HasParaLocInfo in [callerside,callbothsides]) then
           InternalError(200305264);

         extra_pre_call_code;

         if Assigned(callinitblock) then
           SecondPass(TNode(callinitblock));

         regs_to_save_int:=ParaManager.Get_Volatile_Registers_Int(procdefinition.ProcCallOption);
         regs_to_save_address:=ParaManager.Get_Volatile_Registers_Address(procdefinition.ProcCallOption);
         regs_to_save_fpu:=ParaManager.Get_Volatile_Registers_FPU(procdefinition.ProcCallOption);
         regs_to_save_mm:=ParaManager.Get_Volatile_Registers_MM(procdefinition.ProcCallOption);

         { Include Function result registers }
         if (not Is_Void(resultdef)) then
          begin
            { The forced returntype may have a different size than the one
              declared for the procdef }
            retloc:=hlcg.Get_Call_Result_CGPara(procdefinition,typedef);
            retlocitem:=retloc.Location;
            while Assigned(retlocitem) do
              begin
                case retlocitem^.Loc of
                  LOC_REGISTER:
                    case GetRegType(retlocitem^.Register) of
                      R_INTREGISTER:
                        include(regs_to_save_int,GetSupReg(retlocitem^.Register));
                      R_ADDRESSREGISTER:
                        include(regs_to_save_address,GetSupReg(retlocitem^.Register));
                      R_TEMPREGISTER:
                        ;
                      else
                        InternalError(2014020102);
                      end;
                  LOC_FPUREGISTER:
                    include(regs_to_save_fpu,GetSupReg(retlocitem^.Register));
                  LOC_MMREGISTER:
                    include(regs_to_save_mm,GetSupReg(retlocitem^.Register));
                  LOC_REFERENCE,
                  LOC_VOID:
                    ;
                  else
                    InternalError(2004110213);
                end;
                retlocitem:=retlocitem^.next;
              end;
          end;

         if Assigned(left) then
           TCallParaNode(left).secondcallparan;

         { procedure variable or normal function call ? }
         if (right=nil) then
           begin
             { register call for WPO (must be done before wpo test below,
               otherwise optimised called methods are no longer registered)
             }
             if (po_virtualmethod in procdefinition.ProcOptions) and
                not Is_ObjectPascal_Helper(TProcDef(procdefinition).struct) and
                Assigned(methodpointer) and
                (methodpointer.nodetype<>typen) and
                (not Assigned(CurrentProcInfo) or
                 wpoinfomanager.symbol_live(CurrentProcInfo.procdef.MangledName)) then
               TObjectDef(TProcDef(procdefinition).struct).Register_VMT_Call(TProcDef(procdefinition).ExtNumber);
{$ifdef vtentry}
             if not Is_Interface(TProcDef(procdefinition)._class) then
               begin
                 inc(CurrentAsmData.NextVTEntryNr);
                 CurrentAsmData.CurrAsmList.Concat(TAISymbol.CreateName('VTREF'+ToStr(CurrentAsmData.NextVTEntryNr)+'_'+TProcDef(procdefinition).struct.VMT_MangledName+'$$'+ToStr(vmtoffset div sizeof(PInt)),AT_FUNCTION,0,voidpointerdef));
               end;
{$endif vtentry}

             { When methodpointer is typen we don't need (and can't) load
               a pointer. We can directly call the correct procdef (PFV) }
             name_to_call:='';
             if not Assigned(overrideprocnamedef) and
                (po_virtualmethod in procdefinition.ProcOptions) and
                not Is_ObjectPascal_Helper(TProcDef(procdefinition).struct) and
                Assigned(methodpointer) and
                (methodpointer.nodetype<>typen) and
                not wpoinfomanager.can_be_devirtualized(methodpointer.resultdef,procdefinition,name_to_call) then
               begin
                 { virtual methods require an index }
                 if TProcDef(procdefinition).ExtNumber=$ffff then
                   InternalError(200304021);

                 { load the VMT entry (address of the virtual method) }
                 SecondPass(vmt_entry);

                 { register call for WPO }
                 if (not Assigned(CurrentProcInfo) or
                     wpoinfomanager.symbol_live(CurrentProcInfo.procdef.MangledName)) then
                   TObjectDef(TProcDef(procdefinition).struct).Register_VMT_Call(TProcDef(procdefinition).ExtNumber);

                 if not(vmt_entry.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                   InternalError(2015052502);
                 href:=vmt_entry.Location.Reference;
                 pvreg:=NR_NO;

                 callref:=can_call_ref(href);
                 if not callref then
                   begin
                     pvreg:=get_call_reg(CurrentAsmData.CurrAsmList);
                     hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,
                       vmt_entry.resultdef,vmt_entry.resultdef,
                       href,pvreg);
                   end;

                 { Load parameters that are in temporary registers in the
                   correct parameter register }
                 if Assigned(left) then
                   begin
                     reorder_parameters;
                     pushparas;
                   end;

                 if callref then
                   extra_call_ref_code(href);

                 cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,regs_to_save_int);
                 if cg.Uses_Registers(R_ADDRESSREGISTER) then
                   cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_ADDRESSREGISTER,regs_to_save_address);
                 if cg.Uses_Registers(R_FPUREGISTER) then
                   cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_FPUREGISTER,regs_to_save_fpu);
                 if cg.Uses_Registers(R_MMREGISTER) then
                   cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_MMREGISTER,regs_to_save_mm);

                 { call method }
                 extra_call_code;
                 retloc.ResetIfTemp;
                 if callref then
                   retloc:=do_call_ref(href)
                 else
                   begin
                     hlcg.G_PtrTypeCast_Reg(CurrentAsmData.CurrAsmList,vmt_entry.resultdef,CPointerDef.getreusable(procdefinition),pvreg);
                     retloc:=hlcg.A_Call_Reg(CurrentAsmData.CurrAsmList,TAbstractProcDef(procdefinition),pvreg,paralocs);
                     unget_call_reg(CurrentAsmData.CurrAsmList,pvreg);
                   end;

                 extra_post_call_code;
               end
             else
               begin
                  { Load parameters that are in temporary registers in the
                    correct parameter register }
                  if Assigned(left) then
                    begin
                      reorder_parameters;
                      pushparas;
                    end;

                  cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,regs_to_save_int);
                  if cg.Uses_Registers(R_ADDRESSREGISTER) then
                    cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_ADDRESSREGISTER,regs_to_save_address);
                  if cg.Uses_Registers(R_FPUREGISTER) then
                    cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_FPUREGISTER,regs_to_save_fpu);
                  if cg.Uses_Registers(R_MMREGISTER) then
                    cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_MMREGISTER,regs_to_save_mm);

                  if procdefinition.ProcCallOption=pocall_syscall then
                    do_syscall
                  else
                    begin
                      { Calling interrupt from the same code requires some
                        extra code }
                      if (po_interrupt in procdefinition.ProcOptions) then
                        extra_interrupt_code;
                      extra_call_code;
                      retloc.ResetIfTemp;
                      if name_to_call='' then
                        begin
                          if not Assigned(overrideprocnamedef) then
                            name_to_call:=TProcDef(procdefinition).MangledName
                          else
                            name_to_call:=overrideprocnamedef.MangledName;
                        end;
                      if cnf_inherited in callnodeflags then
                        retloc:=hlcg.A_Call_Name_Inherited(CurrentAsmData.CurrAsmList,TProcDef(procdefinition),name_to_call,paralocs)
                      { under certain conditions, a static call (i.e. without PIC) can be generated }
                      else if ((procdefinition.owner=CurrentProcInfo.procdef.owner) or
                         (procdefinition.owner.SymTableType in [LocalSymTable,staticsymtable])
                        ) and ((procdefinition.ProcOptions*[po_weakexternal,po_external])=[]) then
                        retloc:=hlcg.A_Call_Name_Static(CurrentAsmData.CurrAsmList,TProcDef(procdefinition),name_to_call,paralocs,typedef)
                      else
                        retloc:=hlcg.A_Call_Name(CurrentAsmData.CurrAsmList,TProcDef(procdefinition),name_to_call,paralocs,typedef,po_weakexternal in procdefinition.ProcOptions);
                      extra_post_call_code;
                    end;
               end;
           end
         else
           { now procedure variable case }
           begin
              SecondPass(right);

              { can we directly call the procvar in a memory location? }
              callref:=false;
              if not(po_is_block in procdefinition.ProcOptions) and
                 (right.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE]) then
                begin
                  href:=right.Location.Reference;
                  callref:=can_call_ref(href);
                end;

              if not callref then
                load_procvar_codeptr(pvreg,callpvdef)
              else
                begin
                  pvreg:=NRInvalid;
                  callpvdef:=nil;
                end;
              location_freetemp(CurrentAsmData.CurrAsmList,right.Location);

              { Load parameters that are in temporary registers in the
                correct parameter register }
              if Assigned(left) then
                begin
                  reorder_parameters;
                  pushparas;
                end;

              if callref then
                extra_call_ref_code(href);

              cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,regs_to_save_int);
              if cg.Uses_Registers(R_ADDRESSREGISTER) then
                cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_ADDRESSREGISTER,regs_to_save_address);
              if cg.Uses_Registers(R_FPUREGISTER) then
                cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_FPUREGISTER,regs_to_save_fpu);
              if cg.Uses_Registers(R_MMREGISTER) then
                cg.AllocCPURegisters(CurrentAsmData.CurrAsmList,R_MMREGISTER,regs_to_save_mm);

              { Calling interrupt from the same code requires some
                extra code }
              if (po_interrupt in procdefinition.ProcOptions) then
                extra_interrupt_code;
              extra_call_code;

              retloc.ResetIfTemp;
              if callref then
                retloc:=do_call_ref(href)
              else
                retloc:=hlcg.A_Call_Reg(CurrentAsmData.CurrAsmList,callpvdef,pvreg,paralocs);
              extra_post_call_code;
           end;

         { free the resources allocated for the parameters }
         if Assigned(left) then
           freeparas;

         { Release registers, but not the registers that contain the
           function result }
         if (not Is_Void(resultdef)) then
           begin
             retlocitem:=retloc.Location;
             while Assigned(retlocitem) do
               begin
                 case retlocitem^.Loc of
                   LOC_REGISTER:
                     case GetRegType(retlocitem^.Register) of
                       R_INTREGISTER:
                         exclude(regs_to_save_int,GetSupReg(retlocitem^.Register));
                       R_ADDRESSREGISTER:
                         exclude(regs_to_save_address,GetSupReg(retlocitem^.Register));
                       R_TEMPREGISTER:
                         ;
                       else
                         InternalError(2014020103);
                     end;
                   LOC_FPUREGISTER:
                     exclude(regs_to_save_fpu,GetSupReg(retlocitem^.Register));
                   LOC_MMREGISTER:
                     exclude(regs_to_save_mm,GetSupReg(retlocitem^.Register));
                   LOC_REFERENCE,
                   LOC_VOID:
                     ;
                   else
                     InternalError(2004110214);
                 end;
                 retlocitem:=retlocitem^.next;
               end;
           end;

         if cg.Uses_Registers(R_MMREGISTER) then
           cg.DeallocCPURegisters(CurrentAsmData.CurrAsmList,R_MMREGISTER,regs_to_save_mm);
         if cg.Uses_Registers(R_FPUREGISTER) then
           cg.DeallocCPURegisters(CurrentAsmData.CurrAsmList,R_FPUREGISTER,regs_to_save_fpu);
         if cg.Uses_Registers(R_ADDRESSREGISTER) then
           cg.DeallocCPURegisters(CurrentAsmData.CurrAsmList,R_ADDRESSREGISTER,regs_to_save_address);
         cg.DeallocCPURegisters(CurrentAsmData.CurrAsmList,R_INTREGISTER,regs_to_save_int);

         { Need to remove the parameters from the stack? }
         if procdefinition.ProcCallOption in ClearStack_PoCalls then
           begin
             pop_size:=pushedparasize;
             { for Cdecl functions we don't need to pop the funcret when it
               was pushed by para. Except for safecall functions with
               safecall-exceptions enabled. In that case the funcret is always
               returned as a para which is considered a normal para on the
               c-side, so the funcret has to be pop'ed normally. }
             if not ((procdefinition.ProcCallOption=pocall_safecall) and
                     (tf_safecall_exceptions in TargetInfo.flags)) and
                ParaManager.Ret_In_Param(procdefinition.ReturnDef,procdefinition) then
               dec(pop_size,sizeof(PInt));
             { Remove parameters/alignment from the stack }
             pop_parasize(pop_size);
           end
         { in case we use a fixed stack, we did not push anything, if the stack is
           really adjusted because a ret xxx was done, depends on
           pop_parasize which uses pushedparasize to determine this

           This does not apply to interrupt procedures, their ret statement never clears any stack parameters }
         else if ParaManager.Use_Fixed_Stack and
                 not(po_interrupt in procdefinition.ProcOptions) and
                 (TargetInfo.abi=abi_i386_dynalignedstack) then
           begin
             { however, a delphi style frame pointer for a nested subroutine
               is not cleared by the callee, so we have to compensate for this
               by passing 4 as pushedparasize does include it }
             if po_delphi_nested_cc in procdefinition.ProcOptions then
               pop_parasize(sizeof(PInt))
             else
               pop_parasize(0);
           end
         { frame pointer parameter is popped by the caller when it's passed the
           Delphi way and $parentfp is used }
         else if (po_delphi_nested_cc in procdefinition.ProcOptions) and
            not ParaManager.Use_Fixed_Stack and
            is_parentfp_pushed() then
           pop_parasize(sizeof(PInt));

         if procdefinition.Generate_SafeCall_Wrapper then
           begin
             pd:=Search_System_Proc('fpc_safecallcheck');
             cgpara.init;
             { fpc_safecallcheck returns its parameter value (= function result of function we just called) }
             ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,pd,1,cgpara);
             Location_Reset(tmploc,LOC_REGISTER,Def_CGSize(retloc.Def));
             tmploc.Register:=hlcg.GetRegisterForDef(CurrentAsmData.CurrAsmList,retloc.Def);
             hlcg.Gen_Load_CGPara_Loc(CurrentAsmData.CurrAsmList,retloc.Def,retloc,tmploc,true);
             ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,cgpara);
             hlcg.A_Load_Loc_CGPara(CurrentAsmData.CurrAsmList,retloc.Def,tmploc,cgpara);
             retloc.ResetIfTemp;
             retloc:=hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,pd,[@cgpara],nil);
             cgpara.done;
           end;

         { handle function results }
         if (not Is_Void(resultdef)) then
           handle_return_value
         else
           Location_Reset(location,LOC_VOID,OS_NO);

         { convert persistent temps for parameters and function result to normal temps }
         if Assigned(callcleanupblock) then
           SecondPass(TNode(callcleanupblock));

         { copy back copy-out parameters if any }
         copy_back_paras;

         { release temps and finalize unused return values, must be
           after the callcleanupblock because that converts temps
           from persistent to normal }
         release_unused_return_value;

         { release temps of paras }
         release_para_temps;

         { check for fpu exceptions }
         if cnf_check_fpu_exceptions in callnodeflags then
           cg.Maybe_Check_For_FPU_Exception(CurrentAsmData.CurrAsmList);

         { perhaps i/o check ? }
         if (cs_check_io in CurrentSettings.LocalSwitches) and
            (po_iocheck in procdefinition.ProcOptions) and
            not(po_iocheck in CurrentProcInfo.procdef.ProcOptions) and
            { no IO check for methods and procedure variables }
            (right=nil) and
            not(po_virtualmethod in procdefinition.ProcOptions) then
           begin
              hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,'fpc_iocheck',[],nil).ResetIfTemp;
              hlcg.G_Maybe_CheckForExceptions(CurrentAsmData.CurrAsmList);
           end;
      end;


    destructor TCGCallNode.Destroy;
      begin
        retloc.ResetIfTemp;
        inherited Destroy;
      end;


begin
   CCallParaNode:=TCGCallParaNode;
   CCallNode:=TCGCallNode;
end.
