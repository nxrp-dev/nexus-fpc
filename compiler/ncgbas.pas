{
    Copyright (c) 2000-2002 by Florian Klaempfl

    This unit implements some basic nodes

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
unit ncgbas;

{$i fpcdefs.inc}

interface

    uses
       GlobType,
       aasmtai,AAsmData,
       cpubase,cgutils,
       node,nbas;

    type
       TCGNothingNode = class(TNothingNode)
          procedure pass_generate_code;override;
       end;

       TCGAsmNode = class(TAsmNode)
         protected
          procedure ResolveRef(const filepos: TFilePosInfo; var op:TOper); virtual;
         public
          procedure pass_generate_code;override;
       end;

       TCGStatementNode = class(TStatementNode)
          procedure pass_generate_code;override;
       end;

       TCGBlockNode = class(TBlockNode)
          procedure pass_generate_code;override;
       end;

       TCGTempCreateNode = class(TTempCreateNode)
          procedure pass_generate_code;override;
       end;

       TCGTempRefNode = class(TTempRefNode)
          procedure pass_generate_code;override;
          { Changes the location of this temp to ref. Useful when assigning }
          { another temp to this one. The current location will be freed.   }
          { Can only be called in pass 2 (since earlier, the temp location  }
          { isn't known yet)                                                }
          procedure changelocation(const ref: TReference);
       end;

       TCGTempDeleteNode = class(TTempDeleteNode)
          procedure pass_generate_code;override;
       end;

       TCGFinalizeTempsNode = class(TFinalizeTempsNode)
          procedure pass_generate_code; override;
       end;

  implementation

    uses
      Globals,
      CUtils,Verbose,
      aasmbase,aasmcpu,
      SymSym,symconst,defutil,
      pass_2,ncgutil,
      cgbase,cgobj,hlcgobj,
      ProcInfo,
      CPUInfo,
      tgobj
{$ifdef x86}
      ,cgx86
{$endif x86}
      ;

{*****************************************************************************
                                 TNOTHING
*****************************************************************************}

    procedure TCGNothingNode.pass_generate_code;
      begin
         location_reset(location,LOC_VOID,OS_NO);

         { avoid an abstract rte }
      end;


{*****************************************************************************
                               TSTATEMENTNODE
*****************************************************************************}

    procedure TCGStatementNode.pass_generate_code;
      var
         hp : TStatementNode;
      begin
         location_reset(location,LOC_VOID,OS_NO);

         hp:=self;
         while Assigned(hp) do
          begin
            if Assigned(hp.left) then
             begin
               SecondPass(hp.left);
               { Compiler inserted blocks can return values }
               location_copy(hp.location,hp.left.location);
             end;
            hp:=TStatementNode(hp.right);
          end;
      end;


{*****************************************************************************
                               TASMNODE
*****************************************************************************}


    procedure TCGAsmNode.ResolveRef(const filepos: TFilePosInfo; var op:TOper);
      var
        sym : TAbstractNormalVarSym;
{$ifdef x86}
        segment : TRegister;
        scale : byte;
{$endif x86}
        forceref,
        getoffset : boolean;
        indexreg : TRegister;
        sofs : LongInt;
      begin
        if (op.typ=top_local) then
          begin
            sofs:=op.localoper^.localsymofs;
            indexreg:=op.localoper^.localindexreg;
{$ifdef x86}
            segment:=op.localoper^.localsegment;
            scale:=op.localoper^.localscale;
{$endif x86}
            getoffset:=op.localoper^.localgetoffset;
            forceref:=op.localoper^.localforceref;
            sym:=TAbstractNormalVarSym(pointer(op.localoper^.localsym));
            dispose(op.localoper);
            case sym.localloc.loc of
              LOC_REFERENCE :
                begin
                  if getoffset then
                    begin
                      if (indexreg=NR_NO)
{$ifdef x86}
                         and (segment=NR_NO)
{$endif x86}
                         then
                        begin
                          op.typ:=top_const;
                          op.val:=sym.localloc.reference.offset+sofs;
                        end
                      else
                        begin
                          op.typ:=top_ref;
                          new(op.ref);
                          reference_reset_base(op.ref^,indexreg,sym.localloc.reference.offset+sofs,
                            sym.localloc.reference.temppos,NewAlignment(sym.localloc.reference.alignment,sofs),[]);
{$ifdef x86}
                          op.ref^.segment:=segment;
{$endif x86}
                        end;
                    end
                  else
                    begin
                      op.typ:=top_ref;
                      new(op.ref);
                      reference_reset_base(op.ref^,sym.localloc.reference.base,sym.localloc.reference.offset+sofs,
                        sym.localloc.reference.temppos,NewAlignment(sym.localloc.reference.alignment,sofs),[]);
                      op.ref^.index:=indexreg;
{$ifdef x86}
                      op.ref^.segment:=segment;
                      op.ref^.scalefactor:=scale;
{$endif x86}
                    end;
                end;
              LOC_REGISTER :
                begin
                  if getoffset then
                    MessagePos(filepos,asmr_e_invalid_reference_syntax);
                  { Subscribed access }
                  if forceref or
                     (sofs<>0)
                     then
                    begin
                      op.typ:=top_ref;
                      new(op.ref);
                      { no idea about the actual alignment }
                      reference_reset_base(op.ref^,sym.localloc.register,sofs,ctempposinvalid,1,[]);
                      op.ref^.index:=indexreg;
{$ifdef x86}
                      op.ref^.scalefactor:=scale;
{$endif x86}
                    end
                  else
                    begin
                      op.typ:=top_reg;
                      op.reg:=sym.localloc.register;
{$ifdef x86}
                      if reg2opsize(op.reg)<>TCGSize2Opsize[sym.localloc.size] then
                        op.reg:=newreg(getregtype(op.reg),getsupreg(op.reg),cgsize2subreg(getregtype(op.reg),sym.localloc.size));
{$endif x86}
                    end;
                end;
              LOC_FPUREGISTER,
              LOC_MMXREGISTER,
              LOC_MMREGISTER :
                begin
                  op.typ:=top_reg;
                  op.reg:=NR_NO;
                  if getoffset then
                    MessagePos(filepos,asmr_e_invalid_reference_syntax);
                  { Using an MM/FPU register in a reference is not possible }
                  if forceref or (sofs<>0) then
                    MessagePos1(filepos,asmr_e_invalid_ref_register,std_regname(sym.localloc.register))
                  else
                    op.reg:=sym.localloc.register;
                end;
              LOC_INVALID :
                begin
                  { in "assembler; nostackframe;" routines, the
                    funcret loc is set to LOC_INVALID in case the
                    result is returned via a complex location
                    (more than one register, ...) }
                  if (vo_is_funcret in TAbstractVarSym(sym).varoptions) then
                    MessagePos(filepos,asmr_e_complex_function_result_location)
                  else
                    InternalError(2012082101);
                  { recover }
                  op.typ:=top_reg;
                  op.reg:=NR_FUNCTION_RETURN_REG;
                end;
              else
                InternalError(201001031);
            end;
          end;
      end;


    procedure TCGAsmNode.pass_generate_code;

      procedure ReLabel(var p:TAsmSymbol);
        begin
          { Only relabel local tasmlabels }
          if (p.bind = AB_LOCAL) and
             (p is TAsmLabel) then
           begin
             if not Assigned(p.altsymbol) then
               CurrentAsmData.GenerateAltSymbol(p);
             p:=p.altsymbol;
             p.increfs;
           end;
        end;

      var
        hp,hp2 : TAI;
        i : LongInt;
        vs : TAbstractNormalVarSym;
      begin
         location_reset(location,LOC_VOID,OS_NO);

         if (asmnf_get_asm_position in asmnodeflags) then
           begin
             { Add a marker, to be sure the list is not empty }
             CurrentAsmData.CurrAsmList.concat(TAIMarker.create(mark_Position));
             currenttai:=TAI(CurrentAsmData.CurrAsmList.last);
             exit;
           end;
         { Switch to the CPU instruction set, specified by the $ASMCPU directive }
         CurrentAsmData.CurrAsmList.Concat(TAIDirective.create(asd_cpu,CPUTypeStr[CurrentSettings.AsmCPUType]));

         { Allocate registers used in the assembler block }
         { asmnf_has_registerlist means that registers are specified and already allocated }
         if not (asmnf_has_registerlist in asmnodeflags) then
           cg.allocallcpuregisters(CurrentAsmData.CurrAsmList);

         if (po_inline in CurrentProcInfo.procdef.procoptions) then
           begin
             hp:=TAI(p_asm.first);
             while Assigned(hp) do
              begin
                hp2:=TAI(hp.getcopy);
                case hp2.typ of
                  ait_label :
                     ReLabel(TAsmSymbol(TAILabel(hp2).labsym));
                  ait_const :
                     begin
                       if Assigned(TAIConst(hp2).sym) then
                         ReLabel(TAIConst(hp2).sym);
                       if Assigned(TAIConst(hp2).endsym) then
                         ReLabel(TAIConst(hp2).endsym);
                     end;
                  ait_instruction :
                     begin
                       { remove cached insentry, because the new code can
                         require another less optimized instruction }
{$ifdef i386}
{$ifndef NOAG386BIN}
                       TAICPU(hp2).ResetPass1;
{$endif}
{$endif}
                       { fixup the references }
                       for i:=1 to TAICPU(hp2).ops do
                        begin
                          ResolveRef(TAICPU(hp2).fileinfo,TAICPU(hp2).oper[i-1]^);
                          with TAICPU(hp2).oper[i-1]^ do
                           begin
                             case typ of
                               top_ref :
                                 begin
                                   if Assigned(ref^.symbol) then
                                     ReLabel(ref^.symbol);
                                   if Assigned(ref^.relsymbol) then
                                     ReLabel(ref^.relsymbol);
{$ifdef x86}
                                   if (ref^.segment<>NR_NO) and (ref^.segment<>get_default_segment_of_ref(ref^)) then
                                     TAICPU(hp2).segprefix:=ref^.segment;
{$endif x86}
                                 end;
                               else
                                 ;
                             end;
                           end;
                        end;
{$if defined(x86)}
                        { can only be checked now that all local operands }
                        { have been resolved                              }
                        TAICPU(hp2).CheckIfValid;
{$endif x86}
                     end;
                  else
                    ;
                end;
                CurrentAsmData.CurrAsmList.concat(hp2);
                hp:=TAI(hp.next);
              end;
             { restore used symbols }
             CurrentAsmData.ResetAltSymbols;
           end
         else
           begin
             hp:=TAI(p_asm.first);
             while Assigned(hp) do
              begin
                case hp.typ of
                  ait_instruction :
                     begin
                       { remove cached insentry, because the new code can
                         require another less optimized instruction }
{$ifdef i386}
{$ifndef NOAG386BIN}
                       TAICPU(hp).ResetPass1;
{$endif}
{$endif}
                       { fixup the references }
                       for i:=1 to TAICPU(hp).ops do
                         begin
                           ResolveRef(TAICPU(hp).fileinfo,TAICPU(hp).oper[i-1]^);
{$ifdef x86}
                           with TAICPU(hp).oper[i-1]^ do
                             begin
                               case typ of
                                 top_ref :
                                   if (ref^.segment<>NR_NO) and (ref^.segment<>get_default_segment_of_ref(ref^)) then
                                     TAICPU(hp).segprefix:=ref^.segment;
                                 else
                                   ;
                               end;
                             end;
{$endif x86}
                         end;
{$if defined(x86)}
                      { can only be checked now that all local operands }
                      { have been resolved                              }
                      TAICPU(hp).CheckIfValid;
{$endif x86}
                     end;
                  ait_const:
                    with TAIConst(hp) do begin
                      { Handle references to locals from TP-style INLINE(). }
                      if Assigned(sym) and (sym.bind=AB_NONE) then
                        begin
                          vs:=TAbstractNormalVarSym(CurrentProcInfo.procdef.parast.Find(sym.Name));
                          if not Assigned(vs) then
                            vs:=TAbstractNormalVarSym(CurrentProcInfo.procdef.localst.Find(sym.Name));
                          if not Assigned(vs) then
                            InternalError(2021081401);
                          if vs.localloc.loc<>LOC_REFERENCE then
                            InternalError(2021081402);
                          value:=vs.localloc.reference.offset+symofs;
                          sym:=nil;
                          symofs:=0;
                        end;
                    end
                  else
                    ;
                end;
                hp:=TAI(hp.next);
              end;
             { insert the list }
             CurrentAsmData.CurrAsmList.ConcatList(p_asm);
           end;

         { Release register used in the assembler block }
         if not (asmnf_has_registerlist in asmnodeflags) then
           cg.deallocallcpuregisters(CurrentAsmData.CurrAsmList);

         { Switch back to the CPU instruction set of the target CPU }
         CurrentAsmData.CurrAsmList.Concat(TAIDirective.create(asd_cpu,CPUTypeStr[CurrentSettings.CPUType]));
       end;


{*****************************************************************************
                             TBLOCKNODE
*****************************************************************************}

    procedure TCGBlockNode.pass_generate_code;
      var
        hp : TStatementNode;
        oldexitlabel : TAsmLabel;
        oldflowcontrol : TFlowControl;
      begin
        location_reset(location,LOC_VOID,OS_NO);
        oldflowcontrol:=[];
        oldexitlabel:=nil;

        { replace exitlabel? }
        if nf_block_with_exit in flags then
          begin
            oldexitlabel:=CurrentProcInfo.CurrExitLabel;
            CurrentAsmData.getjumplabel(CurrentProcInfo.CurrExitLabel);
            oldflowcontrol:=flowcontrol;
            { the nested block will not span an exit statement of the parent }
            exclude(flowcontrol,fc_exit);
            include(flowcontrol,fc_no_direct_exit);
          end;

        { do second pass on left node }
        if Assigned(left) then
         begin
           hp:=TStatementNode(left);
           while Assigned(hp) do
            begin
              if Assigned(hp.left) then
               begin
                 SecondPass(hp.left);
                 location_copy(hp.location,hp.left.location);
               end;
              location_copy(location,hp.location);
              hp:=TStatementNode(hp.right);
            end;
         end;

        { write exitlabel }
        if nf_block_with_exit in flags then
          begin
            cg.a_label(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrExitLabel);
            CurrentProcInfo.CurrExitLabel:=oldexitlabel;
            { the exit statements inside this block are not exit statements }
            { out of the parent                                             }
            flowcontrol:=oldflowcontrol+(flowcontrol - [fc_exit,fc_no_direct_exit]);
          end;
      end;


{*****************************************************************************
                          TTEMPCREATENODE
*****************************************************************************}

    procedure TCGTempCreateNode.pass_generate_code;
      begin
        location_reset(location,LOC_VOID,OS_NO);

        { if we're secondpassing the same tcgtempcreatenode twice, we have a bug }
        if (ti_valid in tempflags) then
          InternalError(200108222);

        { in case of ti_reference, the location will be initialised using the
          location of the tempinitnode once the first temprefnode is processed }
        if not(ti_reference in tempflags) then
          begin
            { get a (persistent) temp }
            if is_managed_type(tempinfo^.typedef) and
              not(ti_const in tempflags) then
              begin
                location_reset_ref(tempinfo^.location,LOC_REFERENCE,def_cgsize(tempinfo^.typedef),0,[]);
                tg.gethltempmanaged(CurrentAsmData.CurrAsmList,tempinfo^.typedef,tempinfo^.temptype,tempinfo^.location.reference);
                if not(ti_nofini in tempflags) then
                  hlcg.g_finalize(CurrentAsmData.CurrAsmList,tempinfo^.typedef,tempinfo^.location.reference);
              end
            else if (ti_may_be_in_reg in tempflags) then
              begin
                location_allocate_register(CurrentAsmData.CurrAsmList,tempinfo^.location,tempinfo^.typedef,tempinfo^.temptype = tt_persistent);
              end
            else
              begin
                location_reset_ref(tempinfo^.location,LOC_REFERENCE,def_cgsize(tempinfo^.typedef),0,[]);
                tg.gethltemp(CurrentAsmData.CurrAsmList,tempinfo^.typedef,size,tempinfo^.temptype,tempinfo^.location.reference);
              end;
          end;
        includetempflag(ti_valid);
        if Assigned(tempinfo^.tempinitcode) then
          includetempflag(ti_executeinitialisation);
      end;


{*****************************************************************************
                             TTEMPREFNODE
*****************************************************************************}

    procedure TCGTempRefNode.pass_generate_code;
      begin
        if ti_executeinitialisation in tempflags then
          begin
            { avoid recursion }
            excludetempflag(ti_executeinitialisation);
            SecondPass(tempinfo^.tempinitcode);
            if (ti_reference in tempflags) then
              begin
                case tempinfo^.tempinitcode.location.loc of
                  LOC_CREGISTER,
                  LOC_CFPUREGISTER,
                  LOC_CMMREGISTER,
                  LOC_CSUBSETREG:
                    begin
                      { although it's ok if we need this value multiple times
                        for reading, it's not in case of writing (because the
                        register could change due to SSA -> storing to the saved
                        register afterwards would be wrong). }
                      if not(ti_readonly in tempflags) then
                        InternalError(2011031407);
                    end;
                  { in case reference contains CREGISTERS, that doesn't matter:
                    we want to write to the location indicated by the current
                    value of those registers, and we can save those values }
                  else
                    ;
                end;
                hlcg.g_reference_loc(CurrentAsmData.CurrAsmList,tempinfo^.typedef,tempinfo^.tempinitcode.location,tempinfo^.location);
              end;
          end;
        { check if the temp is valid }
        if not(ti_valid in tempflags) then
          InternalError(200108231);
        location:=tempinfo^.location;
        { Allow CPU-specific adjustment of temp references (e.g., for exceptfilters) }
        if location.loc=LOC_REFERENCE then
          cg.adjust_exceptfilter_ref(location.reference,false);
        case tempinfo^.location.loc of
          LOC_REFERENCE:
            begin
              { ti_valid should be excluded if it's a normal temp }
            end;
          LOC_REGISTER,
          LOC_FPUREGISTER,
          LOC_MMREGISTER :
            excludetempflag(ti_valid);
          else
            ;
        end;
      end;


    procedure TCGTempRefNode.changelocation(const ref: TReference);
      begin
        { check if the temp is valid }
        if not(ti_valid in tempflags) then
          InternalError(200306081);
        if (tempinfo^.location.loc<>LOC_REFERENCE) then
          InternalError(2004020203);
        if (tempinfo^.temptype = tt_persistent) then
          tg.ChangeTempType(CurrentAsmData.CurrAsmList,tempinfo^.location.reference,tt_normal);
        tg.ungettemp(CurrentAsmData.CurrAsmList,tempinfo^.location.reference);
        tempinfo^.location.reference := ref;
        tg.ChangeTempType(CurrentAsmData.CurrAsmList,tempinfo^.location.reference,tempinfo^.temptype);
        { adapt location }
        location.reference := ref;
      end;


{*****************************************************************************
                           TTEMPDELETENODE
*****************************************************************************}

    procedure TCGTempDeleteNode.pass_generate_code;
      begin
        if ti_reference in tempflags then
          begin
            { release_to_normal means that the temp will be freed the next
              time it's used. However, reference temps reference some other
              location that is not managed by this temp and hence cannot be
              freed }
            if release_to_normal then
              InternalError(2011052205);
            { so we only mark this temp location as "no longer valid" when
              it's deleted (ttempdeletenodes are also used during getcopy, so
              we really do need one) }
            excludetempflag(ti_valid);
            exit;
          end;

        location_reset(location,LOC_VOID,OS_NO);

        if ti_cleanup_only in tempflags then
          exit;

        { see comments at ti_const declaration: if we initialised this temp with
          the value of another temp, that other temp was not freed because the
          ti_const flag was set }
        if (ti_const in tempflags) and
           Assigned(tempinfo^.tempinitcode) then
          begin
            if tempinfo^.tempinitcode.nodetype<>assignn then
              InternalError(2016081201);
            if TBinaryNode(tempinfo^.tempinitcode).right.location.loc in [LOC_REFERENCE,LOC_CREFERENCE] then
              tg.ungetiftemp(CurrentAsmData.CurrAsmList,TBinaryNode(tempinfo^.tempinitcode).right.location.reference);
          end;


        case tempinfo^.location.loc of
          LOC_REFERENCE:
            begin
              if release_to_normal then
                tg.ChangeTempType(CurrentAsmData.CurrAsmList,tempinfo^.location.reference,tt_normal)
              else
                begin
                  tg.UnGetTemp(CurrentAsmData.CurrAsmList,tempinfo^.location.reference);
                  excludetempflag(ti_valid);
                end;
            end;
          LOC_CREGISTER,
          LOC_REGISTER:
            begin
              if (not(cs_opt_regvar in CurrentSettings.OptimizerSwitches) or
                 (pi_has_label in CurrentProcInfo.flags)) and not(ti_no_final_regsync in tempflags) then
                begin
                  { make sure the register allocator doesn't reuse the }
                  { register e.g. in the middle of a loop              }
{$if defined(cpu32bitalu) and not defined(cpuhighleveltarget)}
                  if tempinfo^.location.size in [OS_64,OS_S64] then
                    begin
                      cg.a_reg_sync(CurrentAsmData.CurrAsmList,tempinfo^.location.register64.reghi);
                      cg.a_reg_sync(CurrentAsmData.CurrAsmList,tempinfo^.location.register64.reglo);
                    end
                  else
{$endif}
                    cg.a_reg_sync(CurrentAsmData.CurrAsmList,tempinfo^.location.register);
                end;
              if release_to_normal then
                tempinfo^.location.loc := LOC_REGISTER
              else
                excludetempflag(ti_valid);
            end;
          LOC_CFPUREGISTER,
          LOC_FPUREGISTER:
            begin
              if (not(cs_opt_regvar in CurrentSettings.OptimizerSwitches) or
                 (pi_has_label in CurrentProcInfo.flags)) and not(ti_no_final_regsync in tempflags) then
                begin
                  { make sure the register allocator doesn't reuse the }
                  { register e.g. in the middle of a loop              }
                  cg.a_reg_sync(CurrentAsmData.CurrAsmList,tempinfo^.location.register);
                end;
              if release_to_normal then
                tempinfo^.location.loc := LOC_FPUREGISTER
              else
                excludetempflag(ti_valid);
            end;
          LOC_CMMREGISTER,
          LOC_MMREGISTER:
            begin
              if (not(cs_opt_regvar in CurrentSettings.OptimizerSwitches) or
                 (pi_has_label in CurrentProcInfo.flags)) and not(ti_no_final_regsync in tempflags) then
                begin
                  { make sure the register allocator doesn't reuse the }
                  { register e.g. in the middle of a loop              }
                  cg.a_reg_sync(CurrentAsmData.CurrAsmList,tempinfo^.location.register);
                end;
              if release_to_normal then
                tempinfo^.location.loc := LOC_MMREGISTER
              else
                excludetempflag(ti_valid);
            end;
          else
            InternalError(200507161);
        end;
      end;


{*****************************************************************************
                         TCGFINALIZETEMPSNODE
*****************************************************************************}

    procedure TCGFinalizeTempsNode.pass_generate_code;
      begin
        hlcg.gen_finalize_code(CurrentAsmData.CurrAsmList);
        location.loc:=LOC_VOID;
      end;


begin
   CNothingNode:=TCGNothingNode;
   CAsmNode:=TCGAsmNode;
   CStatementNode:=TCGStatementNode;
   CBlockNode:=TCGBlockNode;
   CTempCreateNode:=TCGTempCreateNode;
   CTempRefNode:=TCGTempRefNode;
   CTempDeleteNode:=TCGTempDeleteNode;
   CFinalizeTempsNode:=TCGFinalizeTempsNode;
end.
