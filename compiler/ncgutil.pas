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
        intregvars, addrregvars, fpuregvars, mmregvars: TSuperRegisterWorkList;
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

    procedure firstcomplex(p : TBinaryNode);
    procedure MakeToJumpBoolLabels(list: TAsmList; p: TNode; TrueLabel, FalseLabel: TAsmLabel);
//    procedure remove_non_regvars_from_loc(const t: tlocation; var regs:Tsuperregisterset);

    procedure location_force_mmreg(list:TAsmList;var l: TLocation;maybeconst:boolean);
    procedure location_allocate_register(list:TAsmList;out l: TLocation;def: TDef;constant: boolean);

    { allocate registers for a tlocation; assumes that loc.loc is already
      set to LOC_CREGISTER/LOC_CFPUREGISTER/... }
    procedure gen_alloc_regloc(list:TAsmList;var loc: TLocation;def: TDef);

    procedure register_maybe_adjust_setbase(list: TAsmList; opdef: TDef; var l: TLocation; SetBase: aint);


    procedure alloc_proc_symbol(pd: TProcDef);
    procedure release_proc_symbol(pd:TProcDef);
    procedure gen_proc_entry_code(list:TAsmList);
    procedure gen_proc_exit_code(list:TAsmList);
    procedure gen_save_used_regs(list:TAsmList);
    procedure gen_restore_used_regs(list:TAsmList);

    procedure get_used_regvars(n: TNode; var rv: TUsedRegVars);
    { adds the regvars used in n and its children to rv.allregvars,
      those which were already in rv.allregvars to rv.commonregvars and
      uses rv.myregvars as scratch (so that two uses of the same regvar
      in a single tree to make it appear in commonregvars). Useful to
      find out which regvars are used in two different node trees
      e.g. in the "else" and "then" path, or in various case blocks }
//    procedure get_used_regvars_common(n: tnode; var rv: tusedregvarscommon);
    procedure gen_sync_regvars(list:TAsmList; var rv: TUsedRegVars);

    procedure gen_alloc_symtable(list:TAsmList;pd:TProcDef;st:TSymTable);
    procedure gen_free_symtable(list:TAsmList;st:TSymTable);

    procedure location_free(list: TAsmList; const location : TLocation);

    function getprocalign : shortint;

    procedure gen_load_frame_for_exceptfilter(list : TAsmList);

   procedure gen_alloc_regvar(list:TAsmList;sym: TAbstractNormalVarSym; allocreg: boolean);


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
    procedure location_free(list: TAsmList; const location : TLocation);
      begin
        case location.Loc of
          LOC_VOID:
            ;
          LOC_REGISTER,
          LOC_CREGISTER:
            begin
{$if defined(cpu64bitalu)}
                { x86-64 system v abi:
                  structs with up to 16 bytes are returned in registers }
                if location.Size in [OS_128,OS_S128] then
                  begin
                    if GetSupReg(location.Register)<first_int_imreg then
                      cg.UngetCPURegister(list,location.Register);
                    if GetSupReg(location.RegisterHi)<first_int_imreg then
                      cg.UngetCPURegister(list,location.RegisterHi);
                  end
                else
{$elseif not defined(cpuhighleveltarget)}
                if location.Size in [OS_64,OS_S64] then
                  begin
                    if GetSupReg(location.Register64.RegLo)<first_int_imreg then
                      cg.UngetCPURegister(list,location.Register64.RegLo);
                    if GetSupReg(location.Register64.RegHi)<first_int_imreg then
                      cg.UngetCPURegister(list,location.Register64.RegHi);
                  end
                else
{$endif cpu64bitalu and not cpuhighleveltarget}
                  if GetSupReg(location.Register)<first_int_imreg then
                    cg.UngetCPURegister(list,location.Register);
            end;
          LOC_FPUREGISTER,
          LOC_CFPUREGISTER:
            begin
              if GetSupReg(location.Register)<first_fpu_imreg then
                cg.UngetCPURegister(list,location.Register);
            end;
          LOC_MMREGISTER,
          LOC_CMMREGISTER :
            begin
              if GetSupReg(location.Register)<first_mm_imreg then
                cg.UngetCPURegister(list,location.Register);
            end;
          LOC_REFERENCE,
          LOC_CREFERENCE :
            begin
              if ParaManager.Use_Fixed_Stack then
                location_freetemp(list,location);
            end;
          else
            InternalError(2004110211);
        end;
      end;


    procedure firstcomplex(p : TBinaryNode);
      var
        fcl, fcr: LongInt;
        ncl, ncr: LongInt;
      begin
         { calculate boolean AND and OR from left to right if it's short boolean evaluated }
         if (p.nodetype in [orn,andn]) and Is_Boolean(p.left.resultdef) and Is_Boolean(p.right.resultdef) and doshortbooleval(p) then
           begin
             if nf_swapped in p.flags then
               InternalError(200709253);
           end
         else
           begin
             fcl:=node_resources_fpu(p.left);
             fcr:=node_resources_fpu(p.right);
             ncl:=node_complexity(p.left);
             ncr:=node_complexity(p.right);
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
             if ((fcr>fcl) and
                 (fcl>0)) or
                (((fcr=fcl) or
                  (fcr=0)) and
                 (ncr>ncl)) and
                { if one tree contains nodes being conditionally executed, we cannot swap the trees
                  as the other tree might depend on all nodes being executed, this applies for example
                  for temp. create nodes with init part, they must be executed else things break, see
                  issue #34653
                }
                 not(has_conditional_nodes(p.right)) then
               p.swapleftright
           end;
      end;


    procedure MakeToJumpBoolLabels(list: TAsmList; p: TNode; TrueLabel, FalseLabel: TAsmLabel);
    {
      produces jumps to true respectively false labels using boolean expressions
    }
      var
        opsize : TCgSize;
        storepos : TFilePosInfo;
        tmpreg : TRegister;
      begin
         if tnf_error in p.transientflags then
           exit;
         storepos:=CurrentFilePos;
         CurrentFilePos:=p.fileinfo;
         if Is_Boolean(p.resultdef) then
           begin
              if is_constboolnode(p) then
                begin
                   if TOrdConstNode(p).Value.uvalue<>0 then
                     cg.A_Jmp_Always(list,TrueLabel)
                   else
                     cg.A_Jmp_Always(list,FalseLabel)
                end
              else
                begin
                   opsize:=Def_CGSize(p.resultdef);
                   case p.Location.Loc of
                     LOC_SUBSETREG,LOC_CSUBSETREG:
                       begin
                         if p.Location.SReg.BitLen=1 then
                           begin
                             tmpreg:=cg.GetIntRegister(list,p.Location.SReg.SubsetRegSize);
                             hlcg.A_Op_Const_Reg_Reg(list,OP_AND,CGSize_OrdDef(p.Location.SReg.SubsetRegSize),1 shl p.Location.SReg.StartBit,p.Location.SReg.SubsetReg,tmpreg);
                           end
                         else
                           begin
                             tmpreg:=cg.GetIntRegister(list,OS_INT);
                             hlcg.A_Load_Loc_Reg(list,p.resultdef,OSUIntType,p.Location,tmpreg);
                           end;
                         cg.A_Cmp_Const_Reg_Label(list,OS_INT,OC_NE,0,tmpreg,TrueLabel);
                         cg.A_Jmp_Always(list,FalseLabel);
                       end;
                     LOC_SUBSETREF,LOC_CSUBSETREF:
                       begin
                         if (p.Location.SRef.BitIndexReg=NR_NO) and (p.Location.SRef.BitLen=1) then
                           begin
                             tmpreg:=cg.GetIntRegister(list,OS_INT);
                             hlcg.A_Load_Ref_Reg(list,U8IntType,OSUIntType,p.Location.SRef.Ref,tmpreg);

                             if TargetInfo.endian=endian_big then
                               hlcg.A_Op_Const_Reg_Reg(list,OP_AND,OSUIntType,1 shl (8-(p.Location.SRef.StartBit+1)),tmpreg,tmpreg)
                             else
                               hlcg.A_Op_Const_Reg_Reg(list,OP_AND,OSUIntType,1 shl p.Location.SRef.StartBit,tmpreg,tmpreg);
                           end
                         else
                           begin
                             tmpreg:=cg.GetIntRegister(list,OS_INT);
                             hlcg.A_Load_Loc_Reg(list,p.resultdef,OSUIntType,p.Location,tmpreg);
                           end;
                         cg.A_Cmp_Const_Reg_Label(list,OS_INT,OC_NE,0,tmpreg,TrueLabel);
                         cg.A_Jmp_Always(list,FalseLabel);
                       end;
                     LOC_CREGISTER,LOC_REGISTER,LOC_CREFERENCE,LOC_REFERENCE :
                       begin
{$if defined(cpu64bitalu)}
                         if opsize in [OS_128,OS_S128] then
                           begin
                             hlcg.Location_Force_Reg(list,p.Location,p.resultdef,CGSize_OrdDef(opsize),true);
                             tmpreg:=cg.GetIntRegister(list,OS_64);
                             cg.A_Op_Reg_Reg_Reg(list,OP_OR,OS_64,p.Location.Register128.RegLo,p.Location.Register128.RegHi,tmpreg);
                             Location_Reset(p.Location,LOC_REGISTER,OS_64);
                             p.Location.Register:=tmpreg;
                             opsize:=OS_64;
                           end;
{$elseif not defined(cpuhighleveltarget)}
                         if opsize in [OS_64,OS_S64] then
                           begin
                             hlcg.Location_Force_Reg(list,p.Location,p.resultdef,CGSize_OrdDef(opsize),true);
                             tmpreg:=cg.GetIntRegister(list,OS_32);
                             cg.A_Op_Reg_Reg_Reg(list,OP_OR,OS_32,p.Location.Register64.RegLo,p.Location.Register64.RegHi,tmpreg);
                             Location_Reset(p.Location,LOC_REGISTER,OS_32);
                             p.Location.Register:=tmpreg;
                             opsize:=OS_32;
                           end;
{$endif cpu64bitalu and not cpuhighleveltarget}
                         cg.A_Cmp_Const_Loc_Label(list,opsize,OC_NE,0,p.Location,TrueLabel);
                         cg.A_Jmp_Always(list,FalseLabel);
                       end;
                     LOC_JUMP:
                       begin
                         if TrueLabel<>p.Location.TrueLabel then
                           begin
                             cg.A_Label(list,p.Location.TrueLabel);
                             cg.A_Jmp_Always(list,TrueLabel);
                           end;
                         if FalseLabel<>p.Location.FalseLabel then
                           begin
                             cg.A_Label(list,p.Location.FalseLabel);
                             cg.A_Jmp_Always(list,FalseLabel);
                           end;
                       end;
{$ifdef cpuflags}
                     LOC_FLAGS :
                       begin
                         cg.A_Jmp_Flags(list,p.Location.ResFlags,TrueLabel);
                         cg.A_Reg_Dealloc(list,NR_DEFAULTFLAGS);
                         cg.A_Jmp_Always(list,FalseLabel);
                       end;
{$endif cpuflags}
                     else
                       InternalError(200308241);
                   end;
                end;
              Location_Reset_Jump(p.Location,TrueLabel,FalseLabel);
           end
         else
           InternalError(200112305);
         CurrentFilePos:=storepos;
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


    procedure register_maybe_adjust_setbase(list: TAsmList; opdef: TDef; var l: TLocation; SetBase: aint);
      var
        tmpreg: TRegister;
      begin
        if (SetBase<>0) then
          begin
            { subtract the setbase }
            case l.Loc of
              LOC_CREGISTER:
                begin
                  tmpreg := hlcg.GetIntRegister(list,opdef);
                  hlcg.A_Op_Const_Reg_Reg(list,OP_SUB,opdef,SetBase,l.Register,tmpreg);
                  l.Loc:=LOC_REGISTER;
                  l.Register:=tmpreg;
                end;
              LOC_REGISTER:
                begin
                  hlcg.A_Op_Const_Reg(list,OP_SUB,opdef,SetBase,l.Register);
                end;
              else
                InternalError(2007091502);
            end;
          end;
      end;


    procedure location_force_mmreg(list:TAsmList;var l: TLocation;maybeconst:boolean);
      var
        reg : TRegister;
      begin
        if (l.Loc<>LOC_MMREGISTER)  and
           ((l.Loc<>LOC_CMMREGISTER) or (not maybeconst)) then
          begin
            reg:=cg.GetMMRegister(list,l.Size);
            cg.A_LoadMM_Loc_Reg(list,l.Size,l,reg,nil);
            location_freetemp(list,l);
            Location_Reset(l,LOC_MMREGISTER,l.Size);
            l.Register:=reg;
          end;
      end;


    procedure location_allocate_register(list: TAsmList;out l: TLocation;def: TDef;constant: boolean);
      begin
        l.Size:=Def_CGSize(def);
        if def.typ=floatdef then
          begin
            if Use_VectorFPU(def) then
              begin
                if constant then
                  Location_Reset(l,LOC_CMMREGISTER,l.Size)
                else
                  Location_Reset(l,LOC_MMREGISTER,l.Size);
                l.Register:=cg.GetMMRegister(list,l.Size);
              end
            else
              begin
                if constant then
                  Location_Reset(l,LOC_CFPUREGISTER,l.Size)
                else
                  Location_Reset(l,LOC_FPUREGISTER,l.Size);
                l.Register:=cg.GetFPURegister(list,l.Size);
              end;
          end
        else
          begin
            if constant then
              Location_Reset(l,LOC_CREGISTER,l.Size)
            else
              Location_Reset(l,LOC_REGISTER,l.Size);
{$if defined(cpu64bitalu)}
            if l.Size in [OS_128,OS_S128,OS_F128] then
              begin
                l.Register128.RegLo:=cg.GetIntRegister(list,OS_64);
                l.Register128.RegHi:=cg.GetIntRegister(list,OS_64);
              end
            else
{$elseif not defined(cpuhighleveltarget)}
            if l.Size in [OS_64,OS_S64,OS_F64] then
              begin
                l.Register64.RegLo:=cg.GetIntRegister(list,OS_32);
                l.Register64.RegHi:=cg.GetIntRegister(list,OS_32);
              end
            else
{$endif cpu64bitalu and not cpuhighleveltarget}
            { Note: for widths of records (and maybe objects, classes, etc.) an
                    address register could be set here, but that is later
                    changed to an intregister neverthless when in the
                    tcgassignmentnode thlcgobj.maybe_change_load_node_reg is
                    called for the temporary node; so the workaround for now is
                    to fix the symptoms... }
              l.Register:=hlcg.GetRegisterForDef(list,def);
          end;
      end;


{****************************************************************************
                            Init/Finalize Code
****************************************************************************}

    { generates the code for incrementing the reference count of parameters and
      initialize out parameters }
    procedure Init_Paras(p:TObject;arg:pointer);
      var
        href : TReference;
        hsym : TParaVarSym;
        eldef : TDef;
        list : TAsmList;
        NeedsInitTable : boolean;
      begin
        list:=TAsmList(arg);
        if (TSym(p).typ=paravarsym) then
         begin
           NeedsInitTable:=Is_Managed_Type(TParaVarSym(p).vardef);
           if not NeedsInitTable then
             exit;
           case TParaVarSym(p).VarSpez of
             vs_value :
               begin
                 { variants are already handled by the call to fpc_variant_copy_overwrite if
                   they are passed by reference }
                 if not((TParaVarSym(p).vardef.typ=variantdef) and
                    ParaManager.Push_Addr_Param(TParaVarSym(p).VarSpez,TParaVarSym(p).vardef,CurrentProcInfo.procdef.ProcCallOption)) then
                   begin
                     hlcg.Location_Get_Data_Ref(list,TParaVarSym(p).vardef,TParaVarSym(p).InitialLoc,href,
                       Is_Open_Array(TParaVarSym(p).vardef) or
                       ((TargetInfo.system in systems_caller_copy_addr_value_para) and
                        ParaManager.Push_Addr_Param(vs_value,TParaVarSym(p).vardef,CurrentProcInfo.procdef.ProcCallOption)),
                        sizeof(PInt));
                     if Is_Open_Array(TParaVarSym(p).vardef) then
                       begin
                         { open arrays do not contain correct element count in their rtti,
                           the actual count must be passed separately. }
                         hsym:=TParaVarSym(Get_High_Value_Sym(TParaVarSym(p)));
                         eldef:=TArrayDef(TParaVarSym(p).vardef).ElementDef;
                         if not Assigned(hsym) then
                           InternalError(201003031);
                         hlcg.G_Array_RTTI_Helper(list,eldef,href,hsym.InitialLoc,'fpc_addref_array');
                       end
                     else
                      hlcg.G_IncrRefCount(list,TParaVarSym(p).vardef,href);
                   end;
               end;
             vs_out :
               begin
                 { we have no idea about the alignment at the callee side,
                   and the user also cannot specify "unaligned" here, so
                   assume worst case }
                 hlcg.Location_Get_Data_Ref(list,TParaVarSym(p).vardef,TParaVarSym(p).InitialLoc,href,true,1);
                 if Is_Open_Array(TParaVarSym(p).vardef) then
                   begin
                     hsym:=TParaVarSym(Get_High_Value_Sym(TParaVarSym(p)));
                     eldef:=TArrayDef(TParaVarSym(p).vardef).ElementDef;
                     if not Assigned(hsym) then
                       InternalError(201103033);
                     hlcg.G_Array_RTTI_Helper(list,eldef,href,hsym.InitialLoc,'fpc_initialize_array');
                   end
                 else
                   hlcg.G_Initialize(list,TParaVarSym(p).vardef,href);
               end;
             else
               ;
           end;
         end;
      end;


    procedure gen_alloc_regloc(list:TAsmList;var loc: TLocation;def: TDef);
      begin
        case loc.Loc of
          LOC_CREGISTER:
            begin
{$if defined(cpu64bitalu)}
              if loc.Size in [OS_128,OS_S128] then
                begin
                  loc.Register128.RegLo:=cg.GetIntRegister(list,OS_64);
                  loc.Register128.RegHi:=cg.GetIntRegister(list,OS_64);
                end
              else
{$elseif not defined(cpuhighleveltarget)}
              if loc.Size in [OS_64,OS_S64] then
                begin
                  loc.Register64.RegLo:=cg.GetIntRegister(list,OS_32);
                  loc.Register64.RegHi:=cg.GetIntRegister(list,OS_32);
                end
              else
{$endif cpu64bitalu and not cpuhighleveltarget}
                if hlcg.def2regtyp(def)=R_ADDRESSREGISTER then
                  loc.Register:=hlcg.GetAddressRegister(list,def)
                else
                  loc.Register:=cg.GetIntRegister(list,loc.Size);
            end;
          LOC_CFPUREGISTER:
            begin
              loc.Register:=cg.GetFPURegister(list,loc.Size);
            end;
          LOC_CMMREGISTER:
            begin
             loc.Register:=cg.GetMMRegister(list,loc.Size);
            end;
          else
            ;
        end;
      end;


    procedure gen_alloc_regvar(list:TAsmList;sym: TAbstractNormalVarSym; allocreg: boolean);

      procedure set_para_regvar_initial_location;
        var
          ParaLoc: PCGParaLocation;
          loc: TLocation;
          RegType: TRegisterType;
          reg,reg2: TRegister;
          size,regsize: TCGInt;
        begin
          TParaVarSym(sym).ParaLoc[calleeside].Get_Location(loc);
          size:=TParaVarSym(sym).ParaLoc[calleeside].IntSize;
          ParaLoc:=TParaVarSym(sym).ParaLoc[calleeside].Location;
{$if defined(cpu64bitalu)}
          if sym.InitialLoc.Size in [OS_128,OS_S128] then
{$else}
          if sym.InitialLoc.Size in [OS_64,OS_S64] then
{$endif defined(cpu64bitalu)}
            begin
              if TargetInfo.endian=endian_little then
                begin
                  reg:=sym.InitialLoc.Register;
                  reg2:=sym.InitialLoc.RegisterHi;
                end
              else
                begin
                  reg:=sym.InitialLoc.RegisterHi;
                  reg2:=sym.InitialLoc.Register;
                end;
            end
          else
            begin
              reg:=sym.InitialLoc.Register;
              reg2:=NR_NO;
            end;
          RegType:=GetRegType(reg);
          while true do
            begin
              regsize:=TCgSize2Size[reg_cgsize(reg)];
{$ifndef x86}
              { The size of the stack parameter must be not less than
                the size of the register because the spilling code for
                most CPU targets spills whole registers.

                Spilling of sub registers is supported for x86.
              }
              if (ParaLoc<>nil) and (regsize>TCgSize2Size[ParaLoc^.Size]) then
                break;
{$endif x86}
              cg.rg[RegType].Set_Reg_Initial_Location(reg,loc.Reference);
              dec(size,regsize);
              if size<=0 then
                break;
              if ParaLoc<>nil then
                ParaLoc:=ParaLoc^.Next;
              if ParaLoc<>nil then
                loc.Reference.Offset:=ParaLoc^.Reference.Offset
              else
                inc(loc.Reference.Offset,regsize);

                begin
                  if reg=reg2 then
                    InternalError(2020090502);
                  reg:=reg2;
                end;
            end;
        end;

      var
        usedef: TDef;
        varloc: TAIVarLoc;
      begin
        if allocreg then
          begin
            if sym.typ=paravarsym then
              usedef:=TParaVarSym(sym).ParaLoc[calleeside].def
            else
              usedef:=sym.vardef;
            gen_alloc_regloc(list,sym.InitialLoc,usedef);
          end;
        if (pi_has_label in CurrentProcInfo.flags) then
          begin
            { Allocate register already, to prevent first allocation to be
              inside a loop }
{$if defined(cpu64bitalu)}
            if sym.InitialLoc.Size in [OS_128,OS_S128] then
              begin
                cg.A_Reg_Sync(list,sym.InitialLoc.Register128.RegLo);
                cg.A_Reg_Sync(list,sym.InitialLoc.Register128.RegHi);
              end
            else
{$elseif defined(cpu32bitalu) and not defined(cpuhighleveltarget)}
            if sym.InitialLoc.Size in [OS_64,OS_S64] then
              begin
                cg.A_Reg_Sync(list,sym.InitialLoc.Register64.RegLo);
                cg.A_Reg_Sync(list,sym.InitialLoc.Register64.RegHi);
              end
            else
{$endif}
             cg.A_Reg_Sync(list,sym.InitialLoc.Register);
          end;
{$if defined(cpu64bitalu)}
        if (sym.InitialLoc.Size in [OS_128,OS_S128]) then
          varloc:=TAIVarLoc.Create128(sym,sym.InitialLoc.Register,sym.InitialLoc.RegisterHi)
        else
{$elseif not defined(cpuhighleveltarget)}
        if (sym.InitialLoc.Size in [OS_64,OS_S64]) then
          varloc:=TAIVarLoc.Create64(sym,sym.InitialLoc.Register,sym.InitialLoc.RegisterHi)
        else
{$endif cpu64bitalu and not cpuhighleveltarget}
          varloc:=TAIVarLoc.create(sym,sym.InitialLoc.Register);
        list.concat(varloc);
        { Notify the register allocator about memory location of
          the register which holds a value of a stack parameter }
        if (sym.typ=paravarsym) and
           ParaManager.Param_Use_ParaLoc(TParaVarSym(sym).ParaLoc[calleeside]) then
          set_para_regvar_initial_location;
      end;


{****************************************************************************
                                Entry/Exit
****************************************************************************}

    procedure alloc_proc_symbol(pd: TProcDef);
      var
        item: TCmdStrListItem;
      begin
        item:=TCmdStrListItem(pd.AliasNames.first);
        while Assigned(item) do
          begin
            CurrentAsmData.DefineProcAsmSymbol(pd,item.str,pd.NeedsGlobalAsmSym);
            item:=TCmdStrListItem(item.next);
         end;
      end;


    procedure release_proc_symbol(pd:TProcDef);
      var
        idx : LongInt;
        item : TCmdStrListItem;
      begin
        item:=TCmdStrListItem(pd.AliasNames.first);
        while Assigned(item) do
          begin
            idx:=CurrentAsmData.AsmSymbolDict.findindexof(item.str);
            if idx>=0 then
              CurrentAsmData.AsmSymbolDict.Delete(idx);
            item:=TCmdStrListItem(item.next);
          end;
      end;


    procedure gen_proc_entry_code(list:TAsmList);
      var
        hitemp,
        lotemp, stack_frame_size : LongInt;
      begin
        { generate call frame marker for dwarf call frame info }
        CurrentAsmData.asmcfi.start_frame(list);

        { labels etc. for exception frames are inserted here }
        CurrentProcInfo.start_eh(list);

        if CurrentProcInfo.procdef.ProcTypeOption=potype_proginit then
          CurrentAsmData.asmcfi.outmost_frame(list);

        { All temps are know, write offsets used for information }
        if (cs_asm_source in CurrentSettings.GlobalSwitches) and
           (CurrentProcInfo.tempstart<>tg.lasttemp) then
          begin
            if tg.direction>0 then
              begin
                lotemp:=CurrentProcInfo.tempstart;
                hitemp:=tg.lasttemp;
              end
            else
              begin
                lotemp:=tg.lasttemp;
                hitemp:=CurrentProcInfo.tempstart;
              end;
            list.concat(TAIComment.Create(StrPNew('Temps allocated between '+std_regname(CurrentProcInfo.framepointer)+
              ToStr_With_Plus(lotemp)+' and '+std_regname(CurrentProcInfo.framepointer)+ToStr_With_Plus(hitemp))));
          end;

         { generate target specific proc entry code }
         stack_frame_size := CurrentProcInfo.calc_stackframe_size;
         if (stack_frame_size <> 0) and
            (po_nostackframe in CurrentProcInfo.procdef.ProcOptions) then
           message1(parser_e_nostackframe_with_locals,ToStr(stack_frame_size));

         hlcg.G_Proc_Entry(list,stack_frame_size,(po_nostackframe in CurrentProcInfo.procdef.ProcOptions));
      end;


    procedure gen_proc_exit_code(list:TAsmList);
      var
        parasize : LongInt;
      begin
        { c style clearstack does not need to remove parameters from the stack, only the
          return value when it was pushed by arguments }
        if CurrentProcInfo.procdef.ProcCallOption in ClearStack_PoCalls then
          begin
            parasize:=0;
            { For safecall functions with safecall-exceptions enabled the funcret is always returned as a para
              which is considered a normal para on the c-side, so the funcret has to be pop'ed normally. }
            if not CurrentProcInfo.procdef.Generate_SafeCall_Wrapper and
               ParaManager.Ret_In_Param(CurrentProcInfo.procdef.ReturnDef,CurrentProcInfo.procdef) then
              inc(parasize,sizeof(PInt));
          end
        else
          begin
            parasize:=CurrentProcInfo.para_stack_size;
            { the parent frame pointer para has to be removed always by the caller in
              case of Delphi-style parent frame pointer passing }
            if (not(ParaManager.Use_Fixed_Stack) or (TargetInfo.abi=abi_i386_dynalignedstack)) and
               (po_delphi_nested_cc in CurrentProcInfo.procdef.ProcOptions) then
              dec(parasize,sizeof(PInt));
          end;

        { generate target specific proc exit code }
        hlcg.G_Proc_Exit(list,parasize,(po_nostackframe in CurrentProcInfo.procdef.ProcOptions));

        { labels etc. for exception frames are inserted here }
        CurrentProcInfo.end_eh(list);

        { release return registers, needed for optimizer }
        if not Is_Void(CurrentProcInfo.procdef.ReturnDef) then
          ParaManager.FreeCGPara(list,CurrentProcInfo.procdef.FuncRetLoc[calleeside]);

        { end of frame marker for call frame info }
        CurrentAsmData.asmcfi.end_frame(list);
      end;


    procedure gen_save_used_regs(list:TAsmList);
      begin
        if po_noreturn in CurrentProcInfo.procdef.ProcOptions then
          exit;
        { Pure assembler routines need to save the registers themselves }
        if (po_assembler in CurrentProcInfo.procdef.ProcOptions) then
          exit;

        cg.G_Save_Registers(list);
      end;


    procedure gen_restore_used_regs(list:TAsmList);
      begin
        if po_noreturn in CurrentProcInfo.procdef.ProcOptions then
          exit;
        { Pure assembler routines need to save the registers themselves }
        if (po_assembler in CurrentProcInfo.procdef.ProcOptions) then
          exit;

        cg.G_Restore_Registers(list);
      end;


{****************************************************************************
                               Const Data
****************************************************************************}

    procedure gen_alloc_symtable(list:TAsmList;pd:TProcDef;st:TSymTable);

      var
        i       : LongInt;
        highsym,
        sym     : TSym;
        vs      : TAbstractNormalVarSym;
        ptrdef  : TDef;
        isaddr  : boolean;
      begin
        for i:=0 to st.SymList.Count-1 do
          begin
            sym:=TSym(st.SymList[i]);
            case sym.typ of
              staticvarsym :
                begin
                  vs:=TAbstractNormalVarSym(sym);
                  { The code in loadnode.pass_generatecode will create the
                    LOC_REFERENCE instead for all none register variables. This is
                    required because we can't store an asmsymbol in the localloc because
                    the asmsymbol is invalid after an unit is compiled. This gives
                    problems when this procedure is inlined in another unit (PFV) }
                  if vs.Is_RegVar(false) then
                    begin
                      vs.InitialLoc.Loc:=TVarRegable2TCGLoc[vs.VarRegable];
                      vs.InitialLoc.Size:=Def_CGSize(vs.vardef);
                      gen_alloc_regvar(list,vs,true);
                      hlcg.VarSym_Set_LocAlloc(list,vs);
                    end;
                end;
              paravarsym :
                begin
                  vs:=TAbstractNormalVarSym(sym);
                  { Parameters passed to assembler procedures need to be kept
                    in the original location }
                  if (po_assembler in pd.ProcOptions) then
                    TParaVarSym(vs).ParaLoc[calleeside].Get_Location(vs.InitialLoc)
                  { exception filters receive their frame pointer as a parameter }
                  else if (pd.ProcTypeOption=potype_exceptfilter) and
                    (vo_is_parentfp in vs.VarOptions) then
                    begin
                      Location_Reset(vs.InitialLoc,LOC_REGISTER,OS_ADDR);
                      vs.InitialLoc.Register:=NR_FRAME_POINTER_REG;
                    end
                  { Unused parameters need to be kept in the original location
                    to prevent allocation of registers/resources for them. }
                  else if not TParaVarSym(vs).Is_Used and
                    (cs_opt_unused_para in CurrentSettings.OptimizerSwitches) then
                    begin
                      TParaVarSym(vs).ParaLoc[calleeside].Get_Location(vs.InitialLoc);
                    end
                  else
                    begin
                      { if an open array is used, also its high parameter is used,
                        since the hidden high parameters are inserted after the corresponding symbols,
                        we can increase the ref. count here }
                      if Is_Open_Array(vs.vardef) or Is_Array_Of_Const(vs.vardef) then
                        begin
                          highsym:=Get_High_Value_Sym(TParaVarSym(vs));
                          if Assigned(highsym) then
                            inc(highsym.refs);
                        end;

                      isaddr:=ParaManager.Push_Addr_Param(vs.VarSpez,vs.vardef,pd.ProcCallOption);
                      if isaddr then
                        vs.InitialLoc.Size:=Def_CGSize(VoidPointerType)
                      else
                        vs.InitialLoc.Size:=Def_CGSize(vs.vardef);

                      if vs.Is_RegVar(isaddr) then
                        vs.InitialLoc.Loc:=TVarRegable2TCGLoc[vs.VarRegable]
                      else
                        begin
                          vs.InitialLoc.Loc:=LOC_REFERENCE;
                          { Reuse the parameter location for values to are at a single location on the stack }
                          if ParaManager.Param_Use_ParaLoc(TParaVarSym(vs).ParaLoc[calleeside]) then
                            begin
                              hlcg.ParaVarSym_Set_InitialLoc_To_ParaLoc(TParaVarSym(vs));
                            end
                          else
                            begin
                              if isaddr then
                                begin
                                  ptrdef:=CPointerDef.getreusable(vs.vardef);
                                  hlcg.GetLocal(list,vs,ptrdef.Size,ptrdef.Alignment,ptrdef,vs.InitialLoc.Reference)
                                end
                              else
                                hlcg.GetLocal(list,vs,vs.GetSize,TParaVarSym(vs).ParaLoc[calleeside].Alignment,vs.vardef,vs.InitialLoc.Reference);
                            end;
                        end;
                    end;
                  hlcg.VarSym_Set_LocAlloc(list,vs);
                end;
              localvarsym :
                begin
                  vs:=TAbstractNormalVarSym(sym);
                  if Is_Vector(vs.vardef) and
                     Fits_In_MM_Register(vs.vardef) then
                    vs.InitialLoc.Size:=Def_CGMMSize(vs.vardef)
                  else
                    vs.InitialLoc.Size:=Def_CGSize(vs.vardef);
                  if ([po_assembler,po_nostackframe] * pd.ProcOptions = [po_assembler,po_nostackframe]) and
                     (vo_is_funcret in vs.VarOptions) then
                    begin
                      ParaManager.Create_FuncRetLoc_Info(pd,calleeside);
                      if Assigned(pd.FuncRetLoc[calleeside].Location^.next) then
                        begin
                          { can't replace references to "result" with a complex
                            location expression inside assembler code }
                          Location_Reset(vs.InitialLoc,LOC_INVALID,OS_NO);
                        end
                      else
                        pd.FuncRetLoc[calleeside].Get_Location(vs.InitialLoc);
                    end
                  else if (m_delphi in CurrentSettings.ModeSwitches) and
                     (po_assembler in pd.ProcOptions) and
                     (vo_is_funcret in vs.VarOptions) and
                     (vs.refs=0) then
                    begin
                      { not referenced, so don't allocate. Use dummy to }
                      { avoid ie's later on because of LOC_INVALID      }
                      vs.InitialLoc.Loc:=LOC_REGISTER;
                      vs.InitialLoc.Size:=OS_INT;
                      vs.InitialLoc.Register:=NR_FUNCTION_RESULT_REG;
                    end
                  else if vs.Is_RegVar(false) then
                    begin
                      vs.InitialLoc.Loc:=TVarRegable2TCGLoc[vs.VarRegable];
                      gen_alloc_regvar(list,vs,true);
                    end
                  else
                    begin
                      vs.InitialLoc.Loc:=LOC_REFERENCE;
                      hlcg.GetLocal(list,vs,vs.GetSize,vs.vardef.Alignment,vs.vardef,vs.InitialLoc.Reference);
                    end;
                  hlcg.VarSym_Set_LocAlloc(list,vs);
                end;
              else
                ;
            end;
          end;
      end;


    procedure add_regvars(var rv: TUsedRegVars; const location: TLocation);
      begin
        case location.Loc of
          LOC_CREGISTER:
{$if defined(cpu64bitalu)}
            if location.Size in [OS_128,OS_S128] then
              begin
                rv.intregvars.AddNoDup(GetSupReg(location.Register128.RegLo));
                rv.intregvars.AddNoDup(GetSupReg(location.Register128.RegHi));
              end
            else
{$elseif defined(cpu32bitalu)}
            if location.Size in [OS_64,OS_S64] then
              begin
                rv.intregvars.AddNoDup(GetSupReg(location.Register64.RegLo));
                rv.intregvars.AddNoDup(GetSupReg(location.Register64.RegHi));
              end
            else
{$endif}
              if GetRegType(location.Register)=R_INTREGISTER then
                rv.intregvars.AddNoDup(GetSupReg(location.Register))
              else
                rv.addrregvars.AddNoDup(GetSupReg(location.Register));
          LOC_CFPUREGISTER:
            rv.fpuregvars.AddNoDup(GetSupReg(location.Register));
          LOC_CMMREGISTER:
            rv.mmregvars.AddNoDup(GetSupReg(location.Register));
          else
            ;
        end;
      end;


    function do_get_used_regvars(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        rv: PUsedRegVars absolute arg;
      begin
        case (n.nodetype) of
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
            if (ti_valid in TTempRefNode(n).tempflags) then
              add_regvars(rv^,TTempRefNode(n).tempinfo^.Location);
          loadn:
            if (TLoadNode(n).symtableentry.typ in [staticvarsym,localvarsym,paravarsym]) then
              add_regvars(rv^,TAbstractNormalVarSym(TLoadNode(n).symtableentry).LocAlloc);
          loadparentfpn:
            if CurrentProcInfo.procdef.ParaST.SymTableLevel>TLoadParentFPNode(n).parentpd.ParaST.SymTableLevel then
              add_regvars(rv^,TParaVarSym(CurrentProcInfo.procdef.ParentFPSym).LocAlloc);
          vecn:
            begin
              { range checks sometimes need the high parameter }
              if (cs_check_range in CurrentSettings.LocalSwitches) and
                 (Is_Open_Array(TVecNode(n).left.resultdef) or
                  Is_Array_Of_Const(TVecNode(n).left.resultdef)) and
                 not(CurrentProcInfo.procdef.ProcCallOption in CDecl_PoCalls) then
                add_regvars(rv^,TAbstractNormalVarSym(Get_High_Value_Sym(TParaVarSym(TLoadNode(TVecNode(n).left).symtableentry))).LocAlloc)
            end;
          else
            ;
        end;
        result := fen_true;
      end;


    procedure get_used_regvars(n: TNode; var rv: TUsedRegVars);
      begin
        foreachnodestatic(n,@do_get_used_regvars,@rv);
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

    procedure gen_sync_regvars(list:TAsmList; var rv: TUsedRegVars);
      var
        count: LongInt;
      begin
        for count := 1 to rv.intregvars.length do
          cg.A_Reg_Sync(list,NewReg(R_INTREGISTER,rv.intregvars.ReadIdx(count-1),R_SUBWHOLE));
        for count := 1 to rv.addrregvars.length do
          cg.A_Reg_Sync(list,NewReg(R_ADDRESSREGISTER,rv.addrregvars.ReadIdx(count-1),R_SUBWHOLE));
        for count := 1 to rv.fpuregvars.length do
          cg.A_Reg_Sync(list,NewReg(R_FPUREGISTER,rv.fpuregvars.ReadIdx(count-1),R_SUBWHOLE));
        for count := 1 to rv.mmregvars.length do
          cg.A_Reg_Sync(list,NewReg(R_MMREGISTER,rv.mmregvars.ReadIdx(count-1),R_SUBWHOLE));
      end;


    procedure gen_free_symtable(list:TAsmList;st:TSymTable);
      var
        i   : LongInt;
        sym : TSym;
      begin
        for i:=0 to st.SymList.Count-1 do
          begin
            sym:=TSym(st.SymList[i]);
            if (sym.typ in [staticvarsym,localvarsym,paravarsym]) then
              begin
                with TAbstractNormalVarSym(sym) do
                  begin
                    { Note: We need to keep the data available in memory
                      for the sub procedures that can access local data
                      in the parent procedures }
                    case LocAlloc.Loc of
                      LOC_CREGISTER :
                        if (pi_has_label in CurrentProcInfo.flags) then
{$if defined(cpu64bitalu)}
                          if LocAlloc.Size in [OS_128,OS_S128] then
                            begin
                              cg.A_Reg_Sync(list,LocAlloc.Register128.RegLo);
                              cg.A_Reg_Sync(list,LocAlloc.Register128.RegHi);
                            end
                          else
{$elseif defined(cpu32bitalu)}
                          if LocAlloc.Size in [OS_64,OS_S64] then
                            begin
                              cg.A_Reg_Sync(list,LocAlloc.Register64.RegLo);
                              cg.A_Reg_Sync(list,LocAlloc.Register64.RegHi);
                            end
                          else
{$endif}
                            cg.A_Reg_Sync(list,LocAlloc.Register);
                      LOC_CFPUREGISTER,
                      LOC_CMMREGISTER,
                      LOC_CMMXREGISTER:
                        if (pi_has_label in CurrentProcInfo.flags) then
                          cg.A_Reg_Sync(list,LocAlloc.Register);
                      LOC_REFERENCE :
                        begin
                          { can't free the result, because we load it after
                            this call into the function result location
                            (gets freed in thlcgobj.gen_load_return_value();) }
                          if (typ in [localvarsym,paravarsym]) and
                             (([vo_is_funcret,vo_is_result]*VarOptions)=[]) and
                             ((CurrentProcInfo.procdef.ProcTypeOption<>potype_constructor) or
                              not(vo_is_self in VarOptions)) then
                            tg.Ungetlocal(list,LocAlloc.Reference);
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


    function getprocalign : shortint;
      begin
        result:=CurrentSettings.Alignment.ProcAlign;
      end;


    procedure gen_load_frame_for_exceptfilter(list : TAsmList);
      var
        para: TParaVarSym;
        framesrc: TRegister;
      begin
        para:=TParaVarSym(CurrentProcInfo.procdef.paras[0]);
        if not (vo_is_parentfp in para.VarOptions) then
          InternalError(201201142);
        if (para.ParaLoc[calleeside].Location^.Loc<>LOC_REGISTER) or
          (para.ParaLoc[calleeside].Location^.next<>nil) then
          InternalError(201201143);
        framesrc:=para.ParaLoc[calleeside].Location^.Register;
        cg.A_Reg_Alloc(list,framesrc);
        cg.A_Reg_Dealloc(list,framesrc);
        cg.A_Load_Reg_Reg(list,OS_ADDR,OS_ADDR,framesrc,NR_FRAME_POINTER_REG);
      end;

end.
