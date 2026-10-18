{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Helper routines for all code generators

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
unit ncgutil;

{$i fpcdefs.inc}

interface

    uses
      node,
      GlobType,
      cpubase,cgbase,parabase,cgutils,
      aasmbase,aasmtai,AAsmData,aasmcpu,
      symconst,SymBase,symdef,SymSym,symtype
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
      ,cg64f32
{$endif not cpu64bitalu and not cpuhighleveltarget}
      ;

    type
      TLoadRegVars = (lr_dont_load_regvars, lr_load_regvars);

      PUsedRegVars = ^TUsedRegVars;
      TUsedRegVars = record
        IntRegVars, AddrRegVars, FPURegVars, MMRegVars: TSuperRegisterWorkList;
      end;

{
      Not used currently, implemented because I thought we had to
      synchronise around if/then/else as well, but not needed. May
      still be useful for SSA once we get around to implementing
      that (JM)

      pusedregvarscommon = ^tusedregvarscommon;
      tusedregvarscommon = record
        allregvars, commonregvars, myregvars: tusedregvars;
      end;
}

    procedure FirstComplex(ABinaryNode : TBinaryNode);
    procedure MakeToJumpBoolLabels(AList: TAsmList; ANode: TNode; ATrueLabel, AFalseLabel: TAsmLabel);
//    procedure remove_non_regvars_from_loc(const t: tlocation; var regs:Tsuperregisterset);

    procedure Location_Force_MMReg(AList:TAsmList;var ALocation: TLocation;AMaybeConst:Boolean);
    procedure Location_Allocate_Register(AList:TAsmList;out ALocation: TLocation;ADef: TDef;AConstant: Boolean);

    { allocate registers for a tlocation; assumes that loc.loc is already
      set to LOC_CREGISTER/LOC_CFPUREGISTER/... }
    procedure Gen_Alloc_RegLoc(AList:TAsmList;var ALocation: TLocation;ADef: TDef);

    procedure Register_Maybe_Adjust_SetBase(AList: TAsmList; AOpDef: TDef; var ALocation: TLocation; ASetBase: AInt);


    procedure Alloc_Proc_Symbol(AProcDef: TProcDef);
    procedure Release_Proc_Symbol(AProcDef:TProcDef);
    procedure Gen_Proc_Entry_Code(AList:TAsmList);
    procedure Gen_Proc_Exit_Code(AList:TAsmList);
    procedure Gen_Save_Used_Regs(AList:TAsmList);
    procedure Gen_Restore_Used_Regs(AList:TAsmList);

    procedure Get_Used_RegVars(ANode: TNode; var AUsedRegVars: TUsedRegVars);
    { adds the regvars used in n and its children to rv.allregvars,
      those which were already in rv.allregvars to rv.commonregvars and
      uses rv.myregvars as scratch (so that two uses of the same regvar
      in a single tree to make it appear in commonregvars). Useful to
      find out which regvars are used in two different node trees
      e.g. in the "else" and "then" path, or in various case blocks }
//    procedure get_used_regvars_common(n: tnode; var rv: tusedregvarscommon);
    procedure Gen_Sync_RegVars(AList:TAsmList; var AUsedRegVars: TUsedRegVars);

    procedure Gen_Alloc_SymTable(AList:TAsmList;AProcDef:TProcDef;ASymTable:TSymTable);
    procedure Gen_Free_SymTable(AList:TAsmList;ASymTable:TSymTable);

    procedure Location_Free(AList: TAsmList; const ALocation : TLocation);

    function GetProcAlign : ShortInt;

    procedure Gen_Load_Frame_For_ExceptFilter(AList : TAsmList);

   procedure Gen_Alloc_RegVar(AList:TAsmList;ASym: TAbstractNormalVarSym; AAllocReg: Boolean);


implementation

  uses
    CUtils,CClasses,
    Globals,Systems,Verbose,
    defutil,
    ProcInfo,paramgr,
    DbgBase,
    nadd,nbas,ncon,nld,nmem,nutils,
    tgobj,cgobj,hlcgobj,hlcgcpu
;


{*****************************************************************************
                                  Misc Helpers
*****************************************************************************}
    procedure Location_Free(AList: TAsmList; const ALocation : TLocation);
      begin
        case ALocation.Loc of
          LOC_VOID:
            ;
          LOC_REGISTER,
          LOC_CREGISTER:
            begin
{$if defined(cpu64bitalu)}
                { x86-64 system v abi:
                  structs with up to 16 bytes are returned in registers }
                if ALocation.Size in [OS_128,OS_S128] then
                  begin
                    if GetSupReg(ALocation.Register)<first_int_imreg then
                      cg.UngetCPURegister(AList,ALocation.Register);
                    if GetSupReg(ALocation.RegisterHi)<first_int_imreg then
                      cg.UngetCPURegister(AList,ALocation.RegisterHi);
                  end
                else
{$elseif not defined(cpuhighleveltarget)}
                if ALocation.Size in [OS_64,OS_S64] then
                  begin
                    if GetSupReg(ALocation.Register64.RegLo)<first_int_imreg then
                      cg.UngetCPURegister(AList,ALocation.Register64.RegLo);
                    if GetSupReg(ALocation.Register64.RegHi)<first_int_imreg then
                      cg.UngetCPURegister(AList,ALocation.Register64.RegHi);
                  end
                else
{$endif cpu64bitalu and not cpuhighleveltarget}
                  if GetSupReg(ALocation.Register)<first_int_imreg then
                    cg.UngetCPURegister(AList,ALocation.Register);
            end;
          LOC_FPUREGISTER,
          LOC_CFPUREGISTER:
            begin
              if GetSupReg(ALocation.Register)<first_fpu_imreg then
                cg.UngetCPURegister(AList,ALocation.Register);
            end;
          LOC_MMREGISTER,
          LOC_CMMREGISTER :
            begin
              if GetSupReg(ALocation.Register)<first_mm_imreg then
                cg.UngetCPURegister(AList,ALocation.Register);
            end;
          LOC_REFERENCE,
          LOC_CREFERENCE :
            begin
              if ParaManager.Use_Fixed_Stack then
                Location_FreeTemp(AList,ALocation);
            end;
          else
            InternalError(2004110211);
        end;
      end;


    procedure FirstComplex(ABinaryNode : TBinaryNode);
      var
        lLeftComplexity, lRightComplexity: LongInt;
        lLeftNodeCount, lRightNodeCount: LongInt;
      begin
         { calculate boolean AND and OR from left to right if it's short boolean evaluated }
         if (ABinaryNode.NodeType in [orn,andn]) and Is_Boolean(ABinaryNode.Left.ResultDef) and Is_Boolean(ABinaryNode.Right.ResultDef) and DoShortBoolEval(ABinaryNode) then
           begin
             if nf_swapped in ABinaryNode.Flags then
               InternalError(200709253);
           end
         else
           begin
             lLeftComplexity:=Node_Resources_FPU(ABinaryNode.Left);
             lRightComplexity:=Node_Resources_FPU(ABinaryNode.Right);
             lLeftNodeCount:=Node_Complexity(ABinaryNode.Left);
             lRightNodeCount:=Node_Complexity(ABinaryNode.Right);
             { We swap left and right if
                a) right needs more floating point registers than left, and
                   left needs more than 0 floating point registers (if it
                   doesn't need any, swapping won't change the floating
                   point register pressure)
                b) both left and right need an equal amount of floating
                   point registers or right needs no floating point registers,
                   and in addition right has a higher complexity than left
                   (+- needs more integer registers, but not necessarily)
             }
             if ((lRightComplexity>lLeftComplexity) and
                 (lLeftComplexity>0)) or
                (((lRightComplexity=lLeftComplexity) or
                  (lRightComplexity=0)) and
                 (lRightNodeCount>lLeftNodeCount)) and
                { if one tree contains nodes being conditionally executed, we cannot swap the trees
                  as the other tree might depend on all nodes being executed, this applies for example
                  for temp. create nodes with init part, they must be executed else things break, see
                  issue #34653
                }
                 not(Has_Conditional_Nodes(ABinaryNode.Right)) then
               ABinaryNode.SwapLeftRight
           end;
      end;


    procedure MakeToJumpBoolLabels(AList: TAsmList; ANode: TNode; ATrueLabel, AFalseLabel: TAsmLabel);
    {
      produces jumps to true respectively false labels using boolean expressions
    }
      var
        lOpSize : TCgSize;
        lStoredFilePos : TFilePosInfo;
        lTempReg : TRegister;
      begin
         if tnf_error in ANode.TransientFlags then
           exit;
         lStoredFilePos:=CurrentFilePos;
         CurrentFilePos:=ANode.FileInfo;
         if Is_Boolean(ANode.ResultDef) then
           begin
              if Is_ConstBoolNode(ANode) then
                begin
                   if TOrdConstNode(ANode).Value.uvalue<>0 then
                     cg.A_Jmp_Always(AList,ATrueLabel)
                   else
                     cg.A_Jmp_Always(AList,AFalseLabel)
                end
              else
                begin
                   lOpSize:=Def_CGSize(ANode.ResultDef);
                   case ANode.Location.Loc of
                     LOC_SUBSETREG,LOC_CSUBSETREG:
                       begin
                         if ANode.Location.SReg.BitLen=1 then
                           begin
                             lTempReg:=cg.GetIntRegister(AList,ANode.Location.SReg.SubsetRegSize);
                             hlcg.A_Op_Const_Reg_Reg(AList,OP_AND,CGSize_OrdDef(ANode.Location.SReg.SubsetRegSize),1 shl ANode.Location.SReg.StartBit,ANode.Location.SReg.SubsetReg,lTempReg);
                           end
                         else
                           begin
                             lTempReg:=cg.GetIntRegister(AList,OS_INT);
                             hlcg.A_Load_Loc_Reg(AList,ANode.ResultDef,OSUIntType,ANode.Location,lTempReg);
                           end;
                         cg.A_Cmp_Const_Reg_Label(AList,OS_INT,OC_NE,0,lTempReg,ATrueLabel);
                         cg.A_Jmp_Always(AList,AFalseLabel);
                       end;
                     LOC_SUBSETREF,LOC_CSUBSETREF:
                       begin
                         if (ANode.Location.SRef.BitIndexReg=NR_NO) and (ANode.Location.SRef.BitLen=1) then
                           begin
                             lTempReg:=cg.GetIntRegister(AList,OS_INT);
                             hlcg.A_Load_Ref_Reg(AList,U8IntType,OSUIntType,ANode.Location.SRef.Ref,lTempReg);

                             if TargetInfo.endian=endian_big then
                               hlcg.A_Op_Const_Reg_Reg(AList,OP_AND,OSUIntType,1 shl (8-(ANode.Location.SRef.StartBit+1)),lTempReg,lTempReg)
                             else
                               hlcg.A_Op_Const_Reg_Reg(AList,OP_AND,OSUIntType,1 shl ANode.Location.SRef.StartBit,lTempReg,lTempReg);
                           end
                         else
                           begin
                             lTempReg:=cg.GetIntRegister(AList,OS_INT);
                             hlcg.A_Load_Loc_Reg(AList,ANode.ResultDef,OSUIntType,ANode.Location,lTempReg);
                           end;
                         cg.A_Cmp_Const_Reg_Label(AList,OS_INT,OC_NE,0,lTempReg,ATrueLabel);
                         cg.A_Jmp_Always(AList,AFalseLabel);
                       end;
                     LOC_CREGISTER,LOC_REGISTER,LOC_CREFERENCE,LOC_REFERENCE :
                       begin
{$if defined(cpu64bitalu)}
                         if lOpSize in [OS_128,OS_S128] then
                           begin
                             hlcg.Location_Force_Reg(AList,ANode.Location,ANode.ResultDef,CGSize_OrdDef(lOpSize),true);
                             lTempReg:=cg.GetIntRegister(AList,OS_64);
                             cg.A_Op_Reg_Reg_Reg(AList,OP_OR,OS_64,ANode.Location.Register128.RegLo,ANode.Location.Register128.RegHi,lTempReg);
                             Location_Reset(ANode.Location,LOC_REGISTER,OS_64);
                             ANode.Location.Register:=lTempReg;
                             lOpSize:=OS_64;
                           end;
{$elseif not defined(cpuhighleveltarget)}
                         if lOpSize in [OS_64,OS_S64] then
                           begin
                             hlcg.Location_Force_Reg(AList,ANode.Location,ANode.ResultDef,CGSize_OrdDef(lOpSize),true);
                             lTempReg:=cg.GetIntRegister(AList,OS_32);
                             cg.A_Op_Reg_Reg_Reg(AList,OP_OR,OS_32,ANode.Location.Register64.RegLo,ANode.Location.Register64.RegHi,lTempReg);
                             Location_Reset(ANode.Location,LOC_REGISTER,OS_32);
                             ANode.Location.Register:=lTempReg;
                             lOpSize:=OS_32;
                           end;
{$endif cpu64bitalu and not cpuhighleveltarget}
                         cg.A_Cmp_Const_Loc_Label(AList,lOpSize,OC_NE,0,ANode.Location,ATrueLabel);
                         cg.A_Jmp_Always(AList,AFalseLabel);
                       end;
                     LOC_JUMP:
                       begin
                         if ATrueLabel<>ANode.Location.TrueLabel then
                           begin
                             cg.A_Label(AList,ANode.Location.TrueLabel);
                             cg.A_Jmp_Always(AList,ATrueLabel);
                           end;
                         if AFalseLabel<>ANode.Location.FalseLabel then
                           begin
                             cg.A_Label(AList,ANode.Location.FalseLabel);
                             cg.A_Jmp_Always(AList,AFalseLabel);
                           end;
                       end;
{$ifdef cpuflags}
                     LOC_FLAGS :
                       begin
                         cg.A_Jmp_Flags(AList,ANode.Location.ResFlags,ATrueLabel);
                         cg.A_Reg_Dealloc(AList,NR_DEFAULTFLAGS);
                         cg.A_Jmp_Always(AList,AFalseLabel);
                       end;
{$endif cpuflags}
                     else
                       InternalError(200308241);
                   end;
                end;
              Location_Reset_Jump(ANode.Location,ATrueLabel,AFalseLabel);
           end
         else
           InternalError(200112305);
         CurrentFilePos:=lStoredFilePos;
      end;


        (*
        This code needs fixing. It is not safe to use rgint; on the m68000 it
        would be rgaddr.

    procedure remove_non_regvars_from_loc(const t: tlocation; var regs:Tsuperregisterset);
      begin
        case t.loc of
          LOC_REGISTER:
            begin
              { can't be a regvar, since it would be LOC_CREGISTER then }
              exclude(regs,getsupreg(t.register));
              if t.register64.reghi<>NR_NO then
                exclude(regs,getsupreg(t.register64.reghi));
            end;
          LOC_CREFERENCE,LOC_REFERENCE:
            begin
              if not(cs_opt_regvar in current_settings.optimizerswitches) or
                 (getsupreg(t.reference.base) in cg.rgint.usableregs) then
                exclude(regs,getsupreg(t.reference.base));
              if not(cs_opt_regvar in current_settings.optimizerswitches) or
                 (getsupreg(t.reference.index) in cg.rgint.usableregs) then
                exclude(regs,getsupreg(t.reference.index));
            end;
        end;
      end;
        *)


{*****************************************************************************
                                     TLocation
*****************************************************************************}


    procedure Register_Maybe_Adjust_SetBase(AList: TAsmList; AOpDef: TDef; var ALocation: TLocation; ASetBase: AInt);
      var
        lTempReg: TRegister;
      begin
        if (ASetBase<>0) then
          begin
            { subtract the setbase }
            case ALocation.Loc of
              LOC_CREGISTER:
                begin
                  lTempReg := hlcg.GetIntRegister(AList,AOpDef);
                  hlcg.A_Op_Const_Reg_Reg(AList,OP_SUB,AOpDef,ASetBase,ALocation.Register,lTempReg);
                  ALocation.Loc:=LOC_REGISTER;
                  ALocation.Register:=lTempReg;
                end;
              LOC_REGISTER:
                begin
                  hlcg.A_Op_Const_Reg(AList,OP_SUB,AOpDef,ASetBase,ALocation.Register);
                end;
              else
                InternalError(2007091502);
            end;
          end;
      end;


    procedure Location_Force_MMReg(AList:TAsmList;var ALocation: TLocation;AMaybeConst:Boolean);
      var
        lReg : TRegister;
      begin
        if (ALocation.Loc<>LOC_MMREGISTER)  and
           ((ALocation.Loc<>LOC_CMMREGISTER) or (not AMaybeConst)) then
          begin
            lReg:=cg.GetMMRegister(AList,ALocation.Size);
            cg.A_LoadMM_Loc_Reg(AList,ALocation.Size,ALocation,lReg,nil);
            Location_FreeTemp(AList,ALocation);
            Location_Reset(ALocation,LOC_MMREGISTER,ALocation.Size);
            ALocation.Register:=lReg;
          end;
      end;


    procedure Location_Allocate_Register(AList: TAsmList;out ALocation: TLocation;ADef: TDef;AConstant: Boolean);
      begin
        ALocation.Size:=Def_CGSize(ADef);
        if ADef.typ=floatdef then
          begin
            if Use_VectorFPU(ADef) then
              begin
                if AConstant then
                  Location_Reset(ALocation,LOC_CMMREGISTER,ALocation.Size)
                else
                  Location_Reset(ALocation,LOC_MMREGISTER,ALocation.Size);
                ALocation.Register:=cg.GetMMRegister(AList,ALocation.Size);
              end
            else
              begin
                if AConstant then
                  Location_Reset(ALocation,LOC_CFPUREGISTER,ALocation.Size)
                else
                  Location_Reset(ALocation,LOC_FPUREGISTER,ALocation.Size);
                ALocation.Register:=cg.GetFPURegister(AList,ALocation.Size);
              end;
          end
        else
          begin
            if AConstant then
              Location_Reset(ALocation,LOC_CREGISTER,ALocation.Size)
            else
              Location_Reset(ALocation,LOC_REGISTER,ALocation.Size);
{$if defined(cpu64bitalu)}
            if ALocation.Size in [OS_128,OS_S128,OS_F128] then
              begin
                ALocation.Register128.RegLo:=cg.GetIntRegister(AList,OS_64);
                ALocation.Register128.RegHi:=cg.GetIntRegister(AList,OS_64);
              end
            else
{$elseif not defined(cpuhighleveltarget)}
            if ALocation.Size in [OS_64,OS_S64,OS_F64] then
              begin
                ALocation.Register64.RegLo:=cg.GetIntRegister(AList,OS_32);
                ALocation.Register64.RegHi:=cg.GetIntRegister(AList,OS_32);
              end
            else
{$endif cpu64bitalu and not cpuhighleveltarget}
            { Note: for widths of records (and maybe objects, classes, etc.) an
                    address register could be set here, but that is later
                    changed to an intregister neverthless when in the
                    tcgassignmentnode thlcgobj.maybe_change_load_node_reg is
                    called for the temporary node; so the workaround for now is
                    to fix the symptoms... }
              ALocation.Register:=hlcg.GetRegisterForDef(AList,ADef);
          end;
      end;


{****************************************************************************
                            Init/Finalize Code
****************************************************************************}

    { generates the code for incrementing the reference count of parameters and
      initialize out parameters }
    procedure InitParas(AObject:TObject;AArg:Pointer);
      var
        lReference : TReference;
        lParaSym : TParaVarSym;
        lElementDef : TDef;
        lList : TAsmList;
        lNeedsInitTable : Boolean;
      begin
        lList:=TAsmList(AArg);
        if (TSym(AObject).typ=paravarsym) then
         begin
           lNeedsInitTable:=Is_Managed_Type(TParaVarSym(AObject).vardef);
           if not lNeedsInitTable then
             exit;
           case TParaVarSym(AObject).VarSpez of
             vs_value :
               begin
                 { variants are already handled by the call to fpc_variant_copy_overwrite if
                   they are passed by reference }
                 if not((TParaVarSym(AObject).vardef.typ=variantdef) and
                    ParaManager.Push_Addr_Param(TParaVarSym(AObject).VarSpez,TParaVarSym(AObject).vardef,CurrentProcInfo.procdef.ProcCallOption)) then
                   begin
                     hlcg.Location_Get_Data_Ref(lList,TParaVarSym(AObject).vardef,TParaVarSym(AObject).InitialLoc,lReference,
                       Is_Open_Array(TParaVarSym(AObject).vardef) or
                       ((TargetInfo.system in systems_caller_copy_addr_value_para) and
                        ParaManager.Push_Addr_Param(vs_value,TParaVarSym(AObject).vardef,CurrentProcInfo.procdef.ProcCallOption)),
                        sizeof(PInt));
                     if Is_Open_Array(TParaVarSym(AObject).vardef) then
                       begin
                         { open arrays do not contain correct element count in their rtti,
                           the actual count must be passed separately. }
                         lParaSym:=TParaVarSym(Get_High_Value_Sym(TParaVarSym(AObject)));
                         lElementDef:=TArrayDef(TParaVarSym(AObject).vardef).ElementDef;
                         if not Assigned(lParaSym) then
                           InternalError(201003031);
                         hlcg.G_Array_RTTI_Helper(lList,lElementDef,lReference,lParaSym.InitialLoc,'fpc_addref_array');
                       end
                     else
                      hlcg.G_IncrRefCount(lList,TParaVarSym(AObject).vardef,lReference);
                   end;
               end;
             vs_out :
               begin
                 { we have no idea about the alignment at the callee side,
                   and the user also cannot specify "unaligned" here, so
                   assume worst case }
                 hlcg.Location_Get_Data_Ref(lList,TParaVarSym(AObject).vardef,TParaVarSym(AObject).InitialLoc,lReference,true,1);
                 if Is_Open_Array(TParaVarSym(AObject).vardef) then
                   begin
                     lParaSym:=TParaVarSym(Get_High_Value_Sym(TParaVarSym(AObject)));
                     lElementDef:=TArrayDef(TParaVarSym(AObject).vardef).ElementDef;
                     if not Assigned(lParaSym) then
                       InternalError(201103033);
                     hlcg.G_Array_RTTI_Helper(lList,lElementDef,lReference,lParaSym.InitialLoc,'fpc_initialize_array');
                   end
                 else
                   hlcg.G_Initialize(lList,TParaVarSym(AObject).vardef,lReference);
               end;
             else
               ;
           end;
         end;
      end;


    procedure Gen_Alloc_RegLoc(AList:TAsmList;var ALocation: TLocation;ADef: TDef);
      begin
        case ALocation.Loc of
          LOC_CREGISTER:
            begin
{$if defined(cpu64bitalu)}
              if ALocation.Size in [OS_128,OS_S128] then
                begin
                  ALocation.Register128.RegLo:=cg.GetIntRegister(AList,OS_64);
                  ALocation.Register128.RegHi:=cg.GetIntRegister(AList,OS_64);
                end
              else
{$elseif not defined(cpuhighleveltarget)}
              if ALocation.Size in [OS_64,OS_S64] then
                begin
                  ALocation.Register64.RegLo:=cg.GetIntRegister(AList,OS_32);
                  ALocation.Register64.RegHi:=cg.GetIntRegister(AList,OS_32);
                end
              else
{$endif cpu64bitalu and not cpuhighleveltarget}
                if hlcg.def2regtyp(ADef)=R_ADDRESSREGISTER then
                  ALocation.Register:=hlcg.GetAddressRegister(AList,ADef)
                else
                  ALocation.Register:=cg.GetIntRegister(AList,ALocation.Size);
            end;
          LOC_CFPUREGISTER:
            begin
              ALocation.Register:=cg.GetFPURegister(AList,ALocation.Size);
            end;
          LOC_CMMREGISTER:
            begin
             ALocation.Register:=cg.GetMMRegister(AList,ALocation.Size);
            end;
          else
            ;
        end;
      end;


    procedure Gen_Alloc_RegVar(AList:TAsmList;ASym: TAbstractNormalVarSym; AAllocReg: Boolean);

      procedure SetParaRegVarInitialLocation;
        var
          lParaLoc: PCGParaLocation;
          lLocation: TLocation;
          lRegType: TRegisterType;
          lReg,lReg2: TRegister;
          lSize,lRegSize: TCGInt;
        begin
          TParaVarSym(ASym).ParaLoc[calleeside].Get_Location(lLocation);
          lSize:=TParaVarSym(ASym).ParaLoc[calleeside].IntSize;
          lParaLoc:=TParaVarSym(ASym).ParaLoc[calleeside].Location;
{$if defined(cpu64bitalu)}
          if ASym.InitialLoc.Size in [OS_128,OS_S128] then
{$else}
          if ASym.InitialLoc.Size in [OS_64,OS_S64] then
{$endif defined(cpu64bitalu)}
            begin
              if TargetInfo.endian=endian_little then
                begin
                  lReg:=ASym.InitialLoc.Register;
                  lReg2:=ASym.InitialLoc.RegisterHi;
                end
              else
                begin
                  lReg:=ASym.InitialLoc.RegisterHi;
                  lReg2:=ASym.InitialLoc.Register;
                end;
            end
          else
            begin
              lReg:=ASym.InitialLoc.Register;
              lReg2:=NR_NO;
            end;
          lRegType:=GetRegType(lReg);
          while true do
            begin
              lRegSize:=TCgSize2Size[reg_cgsize(lReg)];
{$ifndef x86}
              { The size of the stack parameter must be not less than
                the size of the register because the spilling code for
                most CPU targets spills whole registers.

                Spilling of sub registers is supported for x86.
              }
              if (lParaLoc<>nil) and (lRegSize>TCgSize2Size[lParaLoc^.Size]) then
                break;
{$endif x86}
              cg.rg[lRegType].Set_Reg_Initial_Location(lReg,lLocation.Reference);
              dec(lSize,lRegSize);
              if lSize<=0 then
                break;
              if lParaLoc<>nil then
                lParaLoc:=lParaLoc^.Next;
              if lParaLoc<>nil then
                lLocation.Reference.Offset:=lParaLoc^.Reference.Offset
              else
                inc(lLocation.Reference.Offset,lRegSize);

                begin
                  if lReg=lReg2 then
                    InternalError(2020090502);
                  lReg:=lReg2;
                end;
            end;
        end;

      var
        lUseDef: TDef;
        lVarLoc: TAIVarLoc;
      begin
        if AAllocReg then
          begin
            if ASym.typ=paravarsym then
              lUseDef:=TParaVarSym(ASym).ParaLoc[calleeside].def
            else
              lUseDef:=ASym.vardef;
            Gen_Alloc_RegLoc(AList,ASym.InitialLoc,lUseDef);
          end;
        if (pi_has_label in CurrentProcInfo.Flags) then
          begin
            { Allocate register already, to prevent first allocation to be
              inside a loop }
{$if defined(cpu64bitalu)}
            if ASym.InitialLoc.Size in [OS_128,OS_S128] then
              begin
                cg.A_Reg_Sync(AList,ASym.InitialLoc.Register128.RegLo);
                cg.A_Reg_Sync(AList,ASym.InitialLoc.Register128.RegHi);
              end
            else
{$elseif defined(cpu32bitalu) and not defined(cpuhighleveltarget)}
            if ASym.InitialLoc.Size in [OS_64,OS_S64] then
              begin
                cg.A_Reg_Sync(AList,ASym.InitialLoc.Register64.RegLo);
                cg.A_Reg_Sync(AList,ASym.InitialLoc.Register64.RegHi);
              end
            else
{$endif}
             cg.A_Reg_Sync(AList,ASym.InitialLoc.Register);
          end;
{$if defined(cpu64bitalu)}
        if (ASym.InitialLoc.Size in [OS_128,OS_S128]) then
          lVarLoc:=TAIVarLoc.Create128(ASym,ASym.InitialLoc.Register,ASym.InitialLoc.RegisterHi)
        else
{$elseif not defined(cpuhighleveltarget)}
        if (ASym.InitialLoc.Size in [OS_64,OS_S64]) then
          lVarLoc:=TAIVarLoc.Create64(ASym,ASym.InitialLoc.Register,ASym.InitialLoc.RegisterHi)
        else
{$endif cpu64bitalu and not cpuhighleveltarget}
          lVarLoc:=TAIVarLoc.Create(ASym,ASym.InitialLoc.Register);
        AList.concat(lVarLoc);
        { Notify the register allocator about memory location of
          the register which holds a value of a stack parameter }
        if (ASym.typ=paravarsym) and
           ParaManager.Param_Use_ParaLoc(TParaVarSym(ASym).ParaLoc[calleeside]) then
          SetParaRegVarInitialLocation;
      end;


{****************************************************************************
                                Entry/Exit
****************************************************************************}

    procedure Alloc_Proc_Symbol(AProcDef: TProcDef);
      var
        lItem: TCmdStrListItem;
      begin
        lItem:=TCmdStrListItem(AProcDef.AliasNames.first);
        while Assigned(lItem) do
          begin
            CurrentAsmData.DefineProcAsmSymbol(AProcDef,lItem.str,AProcDef.NeedsGlobalAsmSym);
            lItem:=TCmdStrListItem(lItem.next);
         end;
      end;


    procedure Release_Proc_Symbol(AProcDef:TProcDef);
      var
        lIndex : LongInt;
        lItem : TCmdStrListItem;
      begin
        lItem:=TCmdStrListItem(AProcDef.AliasNames.first);
        while Assigned(lItem) do
          begin
            lIndex:=CurrentAsmData.AsmSymbolDict.findindexof(lItem.str);
            if lIndex>=0 then
              CurrentAsmData.AsmSymbolDict.Delete(lIndex);
            lItem:=TCmdStrListItem(lItem.next);
          end;
      end;


    procedure Gen_Proc_Entry_Code(AList:TAsmList);
      var
        lHighTemp,
        lLowTemp, lStackFrameSize : LongInt;
      begin
        { generate call frame marker for dwarf call frame info }
        CurrentAsmData.asmcfi.start_frame(AList);

        { labels etc. for exception frames are inserted here }
        CurrentProcInfo.Start_EH(AList);

        if CurrentProcInfo.procdef.ProcTypeOption=potype_proginit then
          CurrentAsmData.asmcfi.outmost_frame(AList);

        { All temps are know, write offsets used for information }
        if (cs_asm_source in CurrentSettings.GlobalSwitches) and
           (CurrentProcInfo.TempStart<>TG.LastTemp) then
          begin
            if TG.direction>0 then
              begin
                lLowTemp:=CurrentProcInfo.TempStart;
                lHighTemp:=TG.LastTemp;
              end
            else
              begin
                lLowTemp:=TG.LastTemp;
                lHighTemp:=CurrentProcInfo.TempStart;
              end;
            AList.concat(TAIComment.Create(StrPNew('Temps allocated between '+std_regname(CurrentProcInfo.FramePointer)+
              ToStr_With_Plus(lLowTemp)+' and '+std_regname(CurrentProcInfo.FramePointer)+ToStr_With_Plus(lHighTemp))));
          end;

         { generate target specific proc entry code }
         lStackFrameSize := CurrentProcInfo.Calc_StackFrame_Size;
         if (lStackFrameSize <> 0) and
            (po_nostackframe in CurrentProcInfo.procdef.ProcOptions) then
           message1(parser_e_nostackframe_with_locals,ToStr(lStackFrameSize));

         hlcg.G_Proc_Entry(AList,lStackFrameSize,(po_nostackframe in CurrentProcInfo.procdef.ProcOptions));
      end;


    procedure Gen_Proc_Exit_Code(AList:TAsmList);
      var
        lParaSize : LongInt;
      begin
        { c style clearstack does not need to remove parameters from the stack, only the
          return value when it was pushed by arguments }
        if CurrentProcInfo.procdef.ProcCallOption in ClearStack_PoCalls then
          begin
            lParaSize:=0;
            { For safecall functions with safecall-exceptions enabled the funcret is always returned as a para
              which is considered a normal para on the c-side, so the funcret has to be pop'ed normally. }
            if not CurrentProcInfo.procdef.Generate_SafeCall_Wrapper and
               ParaManager.Ret_In_Param(CurrentProcInfo.procdef.ReturnDef,CurrentProcInfo.procdef) then
              inc(lParaSize,sizeof(PInt));
          end
        else
          begin
            lParaSize:=CurrentProcInfo.ParaStackSize;
            { the parent frame pointer para has to be removed always by the caller in
              case of Delphi-style parent frame pointer passing }
            if (not(ParaManager.Use_Fixed_Stack) or (TargetInfo.abi=abi_i386_dynalignedstack)) and
               (po_delphi_nested_cc in CurrentProcInfo.procdef.ProcOptions) then
              dec(lParaSize,sizeof(PInt));
          end;

        { generate target specific proc exit code }
        hlcg.G_Proc_Exit(AList,lParaSize,(po_nostackframe in CurrentProcInfo.procdef.ProcOptions));

        { labels etc. for exception frames are inserted here }
        CurrentProcInfo.End_EH(AList);

        { release return registers, needed for optimizer }
        if not Is_Void(CurrentProcInfo.procdef.ReturnDef) then
          ParaManager.FreeCGPara(AList,CurrentProcInfo.procdef.FuncRetLoc[calleeside]);

        { end of frame marker for call frame info }
        CurrentAsmData.asmcfi.end_frame(AList);
      end;


    procedure Gen_Save_Used_Regs(AList:TAsmList);
      begin
        if po_noreturn in CurrentProcInfo.procdef.ProcOptions then
          exit;
        { Pure assembler routines need to save the registers themselves }
        if (po_assembler in CurrentProcInfo.procdef.ProcOptions) then
          exit;

        cg.G_Save_Registers(AList);
      end;


    procedure Gen_Restore_Used_Regs(AList:TAsmList);
      begin
        if po_noreturn in CurrentProcInfo.procdef.ProcOptions then
          exit;
        { Pure assembler routines need to save the registers themselves }
        if (po_assembler in CurrentProcInfo.procdef.ProcOptions) then
          exit;

        cg.G_Restore_Registers(AList);
      end;


{****************************************************************************
                               Const Data
****************************************************************************}

    procedure Gen_Alloc_SymTable(AList:TAsmList;AProcDef:TProcDef;ASymTable:TSymTable);

      var
        lIndex       : LongInt;
        lHighSym,
        lSym     : TSym;
        lVarSym      : TAbstractNormalVarSym;
        lPointerDef  : TDef;
        lIsAddress  : Boolean;
      begin
        for lIndex:=0 to ASymTable.SymList.Count-1 do
          begin
            lSym:=TSym(ASymTable.SymList[lIndex]);
            case lSym.typ of
              staticvarsym :
                begin
                  lVarSym:=TAbstractNormalVarSym(lSym);
                  { The code in loadnode.pass_generatecode will create the
                    LOC_REFERENCE instead for all none register variables. This is
                    required because we can't store an asmsymbol in the localloc because
                    the asmsymbol is invalid after an unit is compiled. This gives
                    problems when this procedure is inlined in another unit (PFV) }
                  if lVarSym.Is_RegVar(false) then
                    begin
                      lVarSym.InitialLoc.Loc:=TVarRegable2TCGLoc[lVarSym.VarRegable];
                      lVarSym.InitialLoc.Size:=Def_CGSize(lVarSym.vardef);
                      Gen_Alloc_RegVar(AList,lVarSym,true);
                      hlcg.VarSym_Set_LocAlloc(AList,lVarSym);
                    end;
                end;
              paravarsym :
                begin
                  lVarSym:=TAbstractNormalVarSym(lSym);
                  { Parameters passed to assembler procedures need to be kept
                    in the original location }
                  if (po_assembler in AProcDef.ProcOptions) then
                    TParaVarSym(lVarSym).ParaLoc[calleeside].Get_Location(lVarSym.InitialLoc)
                  { exception filters receive their frame pointer as a parameter }
                  else if (AProcDef.ProcTypeOption=potype_exceptfilter) and
                    (vo_is_parentfp in lVarSym.VarOptions) then
                    begin
                      Location_Reset(lVarSym.InitialLoc,LOC_REGISTER,OS_ADDR);
                      lVarSym.InitialLoc.Register:=NR_FRAME_POINTER_REG;
                    end
                  { Unused parameters need to be kept in the original location
                    to prevent allocation of registers/resources for them. }
                  else if not TParaVarSym(lVarSym).Is_Used and
                    (cs_opt_unused_para in CurrentSettings.OptimizerSwitches) then
                    begin
                      TParaVarSym(lVarSym).ParaLoc[calleeside].Get_Location(lVarSym.InitialLoc);
                    end
                  else
                    begin
                      { if an open array is used, also its high parameter is used,
                        since the hidden high parameters are inserted after the corresponding symbols,
                        we can increase the ref. count here }
                      if Is_Open_Array(lVarSym.vardef) or Is_Array_Of_Const(lVarSym.vardef) then
                        begin
                          lHighSym:=Get_High_Value_Sym(TParaVarSym(lVarSym));
                          if Assigned(lHighSym) then
                            inc(lHighSym.refs);
                        end;

                      lIsAddress:=ParaManager.Push_Addr_Param(lVarSym.VarSpez,lVarSym.vardef,AProcDef.ProcCallOption);
                      if lIsAddress then
                        lVarSym.InitialLoc.Size:=Def_CGSize(VoidPointerType)
                      else
                        lVarSym.InitialLoc.Size:=Def_CGSize(lVarSym.vardef);

                      if lVarSym.Is_RegVar(lIsAddress) then
                        lVarSym.InitialLoc.Loc:=TVarRegable2TCGLoc[lVarSym.VarRegable]
                      else
                        begin
                          lVarSym.InitialLoc.Loc:=LOC_REFERENCE;
                          { Reuse the parameter location for values to are at a single location on the stack }
                          if ParaManager.Param_Use_ParaLoc(TParaVarSym(lVarSym).ParaLoc[calleeside]) then
                            begin
                              hlcg.ParaVarSym_Set_InitialLoc_To_ParaLoc(TParaVarSym(lVarSym));
                            end
                          else
                            begin
                              if lIsAddress then
                                begin
                                  lPointerDef:=CPointerDef.getreusable(lVarSym.vardef);
                                  hlcg.GetLocal(AList,lVarSym,lPointerDef.Size,lPointerDef.Alignment,lPointerDef,lVarSym.InitialLoc.Reference)
                                end
                              else
                                hlcg.GetLocal(AList,lVarSym,lVarSym.GetSize,TParaVarSym(lVarSym).ParaLoc[calleeside].Alignment,lVarSym.vardef,lVarSym.InitialLoc.Reference);
                            end;
                        end;
                    end;
                  hlcg.VarSym_Set_LocAlloc(AList,lVarSym);
                end;
              localvarsym :
                begin
                  lVarSym:=TAbstractNormalVarSym(lSym);
                  if Is_Vector(lVarSym.vardef) and
                     Fits_In_MM_Register(lVarSym.vardef) then
                    lVarSym.InitialLoc.Size:=Def_CGMMSize(lVarSym.vardef)
                  else
                    lVarSym.InitialLoc.Size:=Def_CGSize(lVarSym.vardef);
                  if ([po_assembler,po_nostackframe] * AProcDef.ProcOptions = [po_assembler,po_nostackframe]) and
                     (vo_is_funcret in lVarSym.VarOptions) then
                    begin
                      ParaManager.Create_FuncRetLoc_Info(AProcDef,calleeside);
                      if Assigned(AProcDef.FuncRetLoc[calleeside].Location^.next) then
                        begin
                          { can't replace references to "result" with a complex
                            location expression inside assembler code }
                          Location_Reset(lVarSym.InitialLoc,LOC_INVALID,OS_NO);
                        end
                      else
                        AProcDef.FuncRetLoc[calleeside].Get_Location(lVarSym.InitialLoc);
                    end
                  else if (m_delphi in CurrentSettings.ModeSwitches) and
                     (po_assembler in AProcDef.ProcOptions) and
                     (vo_is_funcret in lVarSym.VarOptions) and
                     (lVarSym.refs=0) then
                    begin
                      { not referenced, so don't allocate. Use dummy to }
                      { avoid ie's later on because of LOC_INVALID      }
                      lVarSym.InitialLoc.Loc:=LOC_REGISTER;
                      lVarSym.InitialLoc.Size:=OS_INT;
                      lVarSym.InitialLoc.Register:=NR_FUNCTION_RESULT_REG;
                    end
                  else if lVarSym.Is_RegVar(false) then
                    begin
                      lVarSym.InitialLoc.Loc:=TVarRegable2TCGLoc[lVarSym.VarRegable];
                      Gen_Alloc_RegVar(AList,lVarSym,true);
                    end
                  else
                    begin
                      lVarSym.InitialLoc.Loc:=LOC_REFERENCE;
                      hlcg.GetLocal(AList,lVarSym,lVarSym.GetSize,lVarSym.vardef.Alignment,lVarSym.vardef,lVarSym.InitialLoc.Reference);
                    end;
                  hlcg.VarSym_Set_LocAlloc(AList,lVarSym);
                end;
              else
                ;
            end;
          end;
      end;


    procedure AddRegVars(var AUsedRegVars: TUsedRegVars; const ALocation: TLocation);
      begin
        case ALocation.Loc of
          LOC_CREGISTER:
{$if defined(cpu64bitalu)}
            if ALocation.Size in [OS_128,OS_S128] then
              begin
                AUsedRegVars.IntRegVars.AddNoDup(GetSupReg(ALocation.Register128.RegLo));
                AUsedRegVars.IntRegVars.AddNoDup(GetSupReg(ALocation.Register128.RegHi));
              end
            else
{$elseif defined(cpu32bitalu)}
            if ALocation.Size in [OS_64,OS_S64] then
              begin
                AUsedRegVars.IntRegVars.AddNoDup(GetSupReg(ALocation.Register64.RegLo));
                AUsedRegVars.IntRegVars.AddNoDup(GetSupReg(ALocation.Register64.RegHi));
              end
            else
{$endif}
              if GetRegType(ALocation.Register)=R_INTREGISTER then
                AUsedRegVars.IntRegVars.AddNoDup(GetSupReg(ALocation.Register))
              else
                AUsedRegVars.AddrRegVars.AddNoDup(GetSupReg(ALocation.Register));
          LOC_CFPUREGISTER:
            AUsedRegVars.FPURegVars.AddNoDup(GetSupReg(ALocation.Register));
          LOC_CMMREGISTER:
            AUsedRegVars.MMRegVars.AddNoDup(GetSupReg(ALocation.Register));
          else
            ;
        end;
      end;


    function DoGetUsedRegVars(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      var
        lUsedRegVars: PUsedRegVars absolute AArg;
      begin
        case (ANode.NodeType) of
          temprefn:
            { We only have to synchronise a tempnode before a loop if it is }
            { not created inside the loop, and only synchronise after the   }
            { loop if it's not destroyed inside the loop. If it's created   }
            { before the loop and not yet destroyed, then before the loop   }
            { is secondpassed tempinfo^.valid will be true, and we get the  }
            { correct registers. If it's not destroyed inside the loop,     }
            { then after the loop has been secondpassed tempinfo^.valid     }
            { be true and we also get the right registers. In other cases,  }
            { tempinfo^.valid will be false and so we do not add            }
            { unnecessary registers. This way, we don't have to look at     }
            { tempcreate and tempdestroy nodes to get this info (JM)        }
            if (ti_valid in TTempRefNode(ANode).TempFlags) then
              AddRegVars(lUsedRegVars^,TTempRefNode(ANode).TempInfo^.Location);
          loadn:
            if (TLoadNode(ANode).SymTableEntry.typ in [staticvarsym,localvarsym,paravarsym]) then
              AddRegVars(lUsedRegVars^,TAbstractNormalVarSym(TLoadNode(ANode).SymTableEntry).LocAlloc);
          loadparentfpn:
            if CurrentProcInfo.procdef.ParaST.SymTableLevel>TLoadParentFPNode(ANode).ParentPD.ParaST.SymTableLevel then
              AddRegVars(lUsedRegVars^,TParaVarSym(CurrentProcInfo.procdef.ParentFPSym).LocAlloc);
          vecn:
            begin
              { range checks sometimes need the high parameter }
              if (cs_check_range in CurrentSettings.LocalSwitches) and
                 (Is_Open_Array(TVecNode(ANode).Left.ResultDef) or
                  Is_Array_Of_Const(TVecNode(ANode).Left.ResultDef)) and
                 not(CurrentProcInfo.procdef.ProcCallOption in CDecl_PoCalls) then
                AddRegVars(lUsedRegVars^,TAbstractNormalVarSym(Get_High_Value_Sym(TParaVarSym(TLoadNode(TVecNode(ANode).Left).SymTableEntry))).LocAlloc)
            end;
          else
            ;
        end;
        Result := fen_true;
      end;


    procedure Get_Used_RegVars(ANode: TNode; var AUsedRegVars: TUsedRegVars);
      begin
        ForEachNodeStatic(ANode,@DoGetUsedRegVars,@AUsedRegVars);
      end;

(*
    See comments at declaration of pusedregvarscommon

    function do_get_used_regvars_common(var n: tnode; arg: pointer): foreachnoderesult;
      var
        rv: pusedregvarscommon absolute arg;
      begin
        if (n.nodetype = loadn) and
           (tloadnode(n).symtableentry.typ in [staticvarsym,localvarsym,paravarsym]) then
          with tabstractnormalvarsym(tloadnode(n).symtableentry).localloc do
            case loc of
              LOC_CREGISTER:
                  { if not yet encountered in this node tree }
                if (rv^.myregvars.intregvars.addnodup(getsupreg(register))) and
                  { but nevertheless already encountered somewhere }
                   not(rv^.allregvars.intregvars.addnodup(getsupreg(register))) then
                  { then it's a regvar used in two or more node trees }
                  rv^.commonregvars.intregvars.addnodup(getsupreg(register));
              LOC_CFPUREGISTER:
                if (rv^.myregvars.intregvars.addnodup(getsupreg(register))) and
                   not(rv^.allregvars.intregvars.addnodup(getsupreg(register))) then
                  rv^.commonregvars.intregvars.addnodup(getsupreg(register));
              LOC_CMMREGISTER:
                if (rv^.myregvars.intregvars.addnodup(getsupreg(register))) and
                   not(rv^.allregvars.intregvars.addnodup(getsupreg(register))) then
                  rv^.commonregvars.intregvars.addnodup(getsupreg(register));
            end;
        result := fen_true;
      end;


    procedure get_used_regvars_common(n: tnode; var rv: tusedregvarscommon);
      begin
        rv.myregvars.intregvars.clear;
        rv.myregvars.fpuregvars.clear;
        rv.myregvars.mmregvars.clear;
        foreachnodestatic(n,@do_get_used_regvars_common,@rv);
      end;
*)

    procedure Gen_Sync_RegVars(AList:TAsmList; var AUsedRegVars: TUsedRegVars);
      var
        lCount: LongInt;
      begin
        for lCount := 1 to AUsedRegVars.IntRegVars.length do
          cg.A_Reg_Sync(AList,NewReg(R_INTREGISTER,AUsedRegVars.IntRegVars.ReadIdx(lCount-1),R_SUBWHOLE));
        for lCount := 1 to AUsedRegVars.AddrRegVars.length do
          cg.A_Reg_Sync(AList,NewReg(R_ADDRESSREGISTER,AUsedRegVars.AddrRegVars.ReadIdx(lCount-1),R_SUBWHOLE));
        for lCount := 1 to AUsedRegVars.FPURegVars.length do
          cg.A_Reg_Sync(AList,NewReg(R_FPUREGISTER,AUsedRegVars.FPURegVars.ReadIdx(lCount-1),R_SUBWHOLE));
        for lCount := 1 to AUsedRegVars.MMRegVars.length do
          cg.A_Reg_Sync(AList,NewReg(R_MMREGISTER,AUsedRegVars.MMRegVars.ReadIdx(lCount-1),R_SUBWHOLE));
      end;


    procedure Gen_Free_SymTable(AList:TAsmList;ASymTable:TSymTable);
      var
        lIndex   : LongInt;
        lSym : TSym;
      begin
        for lIndex:=0 to ASymTable.SymList.Count-1 do
          begin
            lSym:=TSym(ASymTable.SymList[lIndex]);
            if (lSym.typ in [staticvarsym,localvarsym,paravarsym]) then
              begin
                with TAbstractNormalVarSym(lSym) do
                  begin
                    { Note: We need to keep the data available in memory
                      for the sub procedures that can access local data
                      in the parent procedures }
                    case LocAlloc.Loc of
                      LOC_CREGISTER :
                        if (pi_has_label in CurrentProcInfo.Flags) then
{$if defined(cpu64bitalu)}
                          if LocAlloc.Size in [OS_128,OS_S128] then
                            begin
                              cg.A_Reg_Sync(AList,LocAlloc.Register128.RegLo);
                              cg.A_Reg_Sync(AList,LocAlloc.Register128.RegHi);
                            end
                          else
{$elseif defined(cpu32bitalu)}
                          if LocAlloc.Size in [OS_64,OS_S64] then
                            begin
                              cg.A_Reg_Sync(AList,LocAlloc.Register64.RegLo);
                              cg.A_Reg_Sync(AList,LocAlloc.Register64.RegHi);
                            end
                          else
{$endif}
                            cg.A_Reg_Sync(AList,LocAlloc.Register);
                      LOC_CFPUREGISTER,
                      LOC_CMMREGISTER,
                      LOC_CMMXREGISTER:
                        if (pi_has_label in CurrentProcInfo.Flags) then
                          cg.A_Reg_Sync(AList,LocAlloc.Register);
                      LOC_REFERENCE :
                        begin
                          { can't free the result, because we load it after
                            this call into the function result location
                            (gets freed in thlcgobj.gen_load_return_value();) }
                          if (typ in [localvarsym,paravarsym]) and
                             (([vo_is_funcret,vo_is_result]*VarOptions)=[]) and
                             ((CurrentProcInfo.procdef.ProcTypeOption<>potype_constructor) or
                              not(vo_is_self in VarOptions)) then
                            TG.UnGetLocal(AList,LocAlloc.Reference);
                        end;
                      { function results in pure assembler routines }
                      LOC_REGISTER,
                      LOC_FPUREGISTER,
                      LOC_MMREGISTER,
                      { empty parameter }
                      LOC_VOID,
                      { global variables in memory and typed constants don't get a location assigned,
                        and neither does an unused $result variable in pure assembler routines }
                      LOC_INVALID:
                        ;
                      else
                        InternalError(2019050538);
                    end;
                  end;
              end;
          end;
      end;


    function GetProcAlign : ShortInt;
      begin
        Result:=CurrentSettings.Alignment.ProcAlign;
      end;


    procedure Gen_Load_Frame_For_ExceptFilter(AList : TAsmList);
      var
        lParaSym: TParaVarSym;
        lFrameSource: TRegister;
      begin
        lParaSym:=TParaVarSym(CurrentProcInfo.procdef.paras[0]);
        if not (vo_is_parentfp in lParaSym.VarOptions) then
          InternalError(201201142);
        if (lParaSym.ParaLoc[calleeside].Location^.Loc<>LOC_REGISTER) or
          (lParaSym.ParaLoc[calleeside].Location^.next<>nil) then
          InternalError(201201143);
        lFrameSource:=lParaSym.ParaLoc[calleeside].Location^.Register;
        cg.A_Reg_Alloc(AList,lFrameSource);
        cg.A_Reg_Dealloc(AList,lFrameSource);
        cg.A_Load_Reg_Reg(AList,OS_ADDR,OS_ADDR,lFrameSource,NR_FRAME_POINTER_REG);
      end;

end.
