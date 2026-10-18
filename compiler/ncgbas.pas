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
          procedure Pass_Generate_Code;override;
       end;

       TCGAsmNode = class(TAsmNode)
         protected
          procedure ResolveRef(const AFilePos: TFilePosInfo; var AOperand:TOper); virtual;
         public
          procedure Pass_Generate_Code;override;
       end;

       TCGStatementNode = class(TStatementNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGBlockNode = class(TBlockNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGTempCreateNode = class(TTempCreateNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGTempRefNode = class(TTempRefNode)
          procedure Pass_Generate_Code;override;
          { Changes the location of this temp to ref. Useful when assigning }
          { another temp to this one. The current location will be freed.   }
          { Can only be called in pass 2 (since earlier, the temp location  }
          { isn't known yet)                                                }
          procedure ChangeLocation(const AReference: TReference);
       end;

       TCGTempDeleteNode = class(TTempDeleteNode)
          procedure Pass_Generate_Code;override;
       end;

       TCGFinalizeTempsNode = class(TFinalizeTempsNode)
          procedure Pass_Generate_Code; override;
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

    procedure TCGNothingNode.Pass_Generate_Code;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);

         { avoid an abstract rte }
      end;


{*****************************************************************************
                               TSTATEMENTNODE
*****************************************************************************}

    procedure TCGStatementNode.Pass_Generate_Code;
      var
         lStatement : TStatementNode;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);

         lStatement:=self;
         while Assigned(lStatement) do
          begin
            if Assigned(lStatement.Left) then
             begin
               SecondPass(lStatement.Left);
               { Compiler inserted blocks can return values }
               Location_Copy(lStatement.Location,lStatement.Left.Location);
             end;
            lStatement:=TStatementNode(lStatement.Right);
          end;
      end;


{*****************************************************************************
                               TASMNODE
*****************************************************************************}


    procedure TCGAsmNode.ResolveRef(const AFilePos: TFilePosInfo; var AOperand:TOper);
      var
        lSymbol : TAbstractNormalVarSym;
{$ifdef x86}
        lSegment : TRegister;
        lScale : Byte;
{$endif x86}
        lForceRef,
        lGetOffset : Boolean;
        lIndexReg : TRegister;
        lSymbolOffset : LongInt;
      begin
        if (AOperand.typ=top_local) then
          begin
            lSymbolOffset:=AOperand.localoper^.localsymofs;
            lIndexReg:=AOperand.localoper^.localindexreg;
{$ifdef x86}
            lSegment:=AOperand.localoper^.localsegment;
            lScale:=AOperand.localoper^.localscale;
{$endif x86}
            lGetOffset:=AOperand.localoper^.localgetoffset;
            lForceRef:=AOperand.localoper^.localforceref;
            lSymbol:=TAbstractNormalVarSym(Pointer(AOperand.localoper^.localsym));
            dispose(AOperand.localoper);
            case lSymbol.LocAlloc.Loc of
              LOC_REFERENCE :
                begin
                  if lGetOffset then
                    begin
                      if (lIndexReg=NR_NO)
{$ifdef x86}
                         and (lSegment=NR_NO)
{$endif x86}
                         then
                        begin
                          AOperand.typ:=top_const;
                          AOperand.Val:=lSymbol.LocAlloc.Reference.Offset+lSymbolOffset;
                        end
                      else
                        begin
                          AOperand.typ:=top_ref;
                          new(AOperand.Ref);
                          Reference_Reset_Base(AOperand.Ref^,lIndexReg,lSymbol.LocAlloc.Reference.Offset+lSymbolOffset,
                            lSymbol.LocAlloc.Reference.TempPos,NewAlignment(lSymbol.LocAlloc.Reference.Alignment,lSymbolOffset),[]);
{$ifdef x86}
                          AOperand.Ref^.Segment:=lSegment;
{$endif x86}
                        end;
                    end
                  else
                    begin
                      AOperand.typ:=top_ref;
                      new(AOperand.Ref);
                      Reference_Reset_Base(AOperand.Ref^,lSymbol.LocAlloc.Reference.Base,lSymbol.LocAlloc.Reference.Offset+lSymbolOffset,
                        lSymbol.LocAlloc.Reference.TempPos,NewAlignment(lSymbol.LocAlloc.Reference.Alignment,lSymbolOffset),[]);
                      AOperand.Ref^.Index:=lIndexReg;
{$ifdef x86}
                      AOperand.Ref^.Segment:=lSegment;
                      AOperand.Ref^.ScaleFactor:=lScale;
{$endif x86}
                    end;
                end;
              LOC_REGISTER :
                begin
                  if lGetOffset then
                    MessagePos(AFilePos,asmr_e_invalid_reference_syntax);
                  { Subscribed access }
                  if lForceRef or
                     (lSymbolOffset<>0)
                     then
                    begin
                      AOperand.typ:=top_ref;
                      new(AOperand.Ref);
                      { no idea about the actual alignment }
                      Reference_Reset_Base(AOperand.Ref^,lSymbol.LocAlloc.Register,lSymbolOffset,CTempPosInvalid,1,[]);
                      AOperand.Ref^.Index:=lIndexReg;
{$ifdef x86}
                      AOperand.Ref^.ScaleFactor:=lScale;
{$endif x86}
                    end
                  else
                    begin
                      AOperand.typ:=top_reg;
                      AOperand.reg:=lSymbol.LocAlloc.Register;
{$ifdef x86}
                      if reg2opsize(AOperand.reg)<>TCGSize2Opsize[lSymbol.LocAlloc.Size] then
                        AOperand.reg:=NewReg(GetRegType(AOperand.reg),GetSupReg(AOperand.reg),cgsize2subreg(GetRegType(AOperand.reg),lSymbol.LocAlloc.Size));
{$endif x86}
                    end;
                end;
              LOC_FPUREGISTER,
              LOC_MMXREGISTER,
              LOC_MMREGISTER :
                begin
                  AOperand.typ:=top_reg;
                  AOperand.reg:=NR_NO;
                  if lGetOffset then
                    MessagePos(AFilePos,asmr_e_invalid_reference_syntax);
                  { Using an MM/FPU register in a reference is not possible }
                  if lForceRef or (lSymbolOffset<>0) then
                    MessagePos1(AFilePos,asmr_e_invalid_ref_register,std_regname(lSymbol.LocAlloc.Register))
                  else
                    AOperand.reg:=lSymbol.LocAlloc.Register;
                end;
              LOC_INVALID :
                begin
                  { in "assembler; nostackframe;" routines, the
                    funcret loc is set to LOC_INVALID in case the
                    result is returned via a complex location
                    (more than one register, ...) }
                  if (vo_is_funcret in TAbstractVarSym(lSymbol).VarOptions) then
                    MessagePos(AFilePos,asmr_e_complex_function_result_location)
                  else
                    InternalError(2012082101);
                  { recover }
                  AOperand.typ:=top_reg;
                  AOperand.reg:=NR_FUNCTION_RETURN_REG;
                end;
              else
                InternalError(201001031);
            end;
          end;
      end;


    procedure TCGAsmNode.Pass_Generate_Code;

      procedure ReLabel(var AAsmSymbol:TAsmSymbol);
        begin
          { Only relabel local tasmlabels }
          if (AAsmSymbol.bind = AB_LOCAL) and
             (AAsmSymbol is TAsmLabel) then
           begin
             if not Assigned(AAsmSymbol.altsymbol) then
               CurrentAsmData.GenerateAltSymbol(AAsmSymbol);
             AAsmSymbol:=AAsmSymbol.altsymbol;
             AAsmSymbol.increfs;
           end;
        end;

      var
        lAsmItem,lCopiedAsmItem : TAI;
        lIndex : LongInt;
        lVarSym : TAbstractNormalVarSym;
      begin
         Location_Reset(Location,LOC_VOID,OS_NO);

         if (asmnf_get_asm_position in AsmNodeFlags) then
           begin
             { Add a marker, to be sure the list is not empty }
             CurrentAsmData.CurrAsmList.concat(TAIMarker.Create(mark_Position));
             CurrentTAI:=TAI(CurrentAsmData.CurrAsmList.last);
             exit;
           end;
         { Switch to the CPU instruction set, specified by the $ASMCPU directive }
         CurrentAsmData.CurrAsmList.Concat(TAIDirective.Create(asd_cpu,CPUTypeStr[CurrentSettings.AsmCPUType]));

         { Allocate registers used in the assembler block }
         { asmnf_has_registerlist means that registers are specified and already allocated }
         if not (asmnf_has_registerlist in AsmNodeFlags) then
           cg.AllocAllCPURegisters(CurrentAsmData.CurrAsmList);

         if (po_inline in CurrentProcInfo.procdef.ProcOptions) then
           begin
             lAsmItem:=TAI(AssemblyList.first);
             while Assigned(lAsmItem) do
              begin
                lCopiedAsmItem:=TAI(lAsmItem.GetCopy);
                case lCopiedAsmItem.typ of
                  ait_label :
                     ReLabel(TAsmSymbol(TAILabel(lCopiedAsmItem).LabSym));
                  ait_const :
                     begin
                       if Assigned(TAIConst(lCopiedAsmItem).sym) then
                         ReLabel(TAIConst(lCopiedAsmItem).sym);
                       if Assigned(TAIConst(lCopiedAsmItem).endsym) then
                         ReLabel(TAIConst(lCopiedAsmItem).endsym);
                     end;
                  ait_instruction :
                     begin
                       { remove cached insentry, because the new code can
                         require another less optimized instruction }
{$ifdef i386}
{$ifndef NOAG386BIN}
                       TAICPU(lCopiedAsmItem).ResetPass1;
{$endif}
{$endif}
                       { fixup the references }
                       for lIndex:=1 to TAICPU(lCopiedAsmItem).ops do
                        begin
                          ResolveRef(TAICPU(lCopiedAsmItem).FileInfo,TAICPU(lCopiedAsmItem).oper[lIndex-1]^);
                          with TAICPU(lCopiedAsmItem).oper[lIndex-1]^ do
                           begin
                             case typ of
                               top_ref :
                                 begin
                                   if Assigned(ref^.Symbol) then
                                     ReLabel(ref^.Symbol);
                                   if Assigned(ref^.RelSymbol) then
                                     ReLabel(ref^.RelSymbol);
{$ifdef x86}
                                   if (ref^.Segment<>NR_NO) and (ref^.Segment<>get_default_segment_of_ref(ref^)) then
                                     TAICPU(lCopiedAsmItem).segprefix:=ref^.Segment;
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
                        TAICPU(lCopiedAsmItem).CheckIfValid;
{$endif x86}
                     end;
                  else
                    ;
                end;
                CurrentAsmData.CurrAsmList.concat(lCopiedAsmItem);
                lAsmItem:=TAI(lAsmItem.next);
              end;
             { restore used symbols }
             CurrentAsmData.ResetAltSymbols;
           end
         else
           begin
             lAsmItem:=TAI(AssemblyList.first);
             while Assigned(lAsmItem) do
              begin
                case lAsmItem.typ of
                  ait_instruction :
                     begin
                       { remove cached insentry, because the new code can
                         require another less optimized instruction }
{$ifdef i386}
{$ifndef NOAG386BIN}
                       TAICPU(lAsmItem).ResetPass1;
{$endif}
{$endif}
                       { fixup the references }
                       for lIndex:=1 to TAICPU(lAsmItem).ops do
                         begin
                           ResolveRef(TAICPU(lAsmItem).FileInfo,TAICPU(lAsmItem).oper[lIndex-1]^);
{$ifdef x86}
                           with TAICPU(lAsmItem).oper[lIndex-1]^ do
                             begin
                               case typ of
                                 top_ref :
                                   if (ref^.Segment<>NR_NO) and (ref^.Segment<>get_default_segment_of_ref(ref^)) then
                                     TAICPU(lAsmItem).segprefix:=ref^.Segment;
                                 else
                                   ;
                               end;
                             end;
{$endif x86}
                         end;
{$if defined(x86)}
                      { can only be checked now that all local operands }
                      { have been resolved                              }
                      TAICPU(lAsmItem).CheckIfValid;
{$endif x86}
                     end;
                  ait_const:
                    with TAIConst(lAsmItem) do begin
                      { Handle references to locals from TP-style INLINE(). }
                      if Assigned(sym) and (sym.bind=AB_NONE) then
                        begin
                          lVarSym:=TAbstractNormalVarSym(CurrentProcInfo.procdef.ParaST.Find(sym.Name));
                          if not Assigned(lVarSym) then
                            lVarSym:=TAbstractNormalVarSym(CurrentProcInfo.procdef.LocalST.Find(sym.Name));
                          if not Assigned(lVarSym) then
                            InternalError(2021081401);
                          if lVarSym.LocAlloc.Loc<>LOC_REFERENCE then
                            InternalError(2021081402);
                          value:=lVarSym.LocAlloc.Reference.Offset+symofs;
                          sym:=nil;
                          symofs:=0;
                        end;
                    end
                  else
                    ;
                end;
                lAsmItem:=TAI(lAsmItem.next);
              end;
             { insert the list }
             CurrentAsmData.CurrAsmList.ConcatList(AssemblyList);
           end;

         { Release register used in the assembler block }
         if not (asmnf_has_registerlist in AsmNodeFlags) then
           cg.DeallocAllCPURegisters(CurrentAsmData.CurrAsmList);

         { Switch back to the CPU instruction set of the target CPU }
         CurrentAsmData.CurrAsmList.Concat(TAIDirective.Create(asd_cpu,CPUTypeStr[CurrentSettings.CPUType]));
       end;


{*****************************************************************************
                             TBLOCKNODE
*****************************************************************************}

    procedure TCGBlockNode.Pass_Generate_Code;
      var
        lStatement : TStatementNode;
        lOldExitLabel : TAsmLabel;
        lOldFlowControl : TFlowControl;
      begin
        Location_Reset(Location,LOC_VOID,OS_NO);
        lOldFlowControl:=[];
        lOldExitLabel:=nil;

        { replace exitlabel? }
        if nf_block_with_exit in Flags then
          begin
            lOldExitLabel:=CurrentProcInfo.CurrExitLabel;
            CurrentAsmData.getjumplabel(CurrentProcInfo.CurrExitLabel);
            lOldFlowControl:=flowcontrol;
            { the nested block will not span an exit statement of the parent }
            exclude(flowcontrol,fc_exit);
            include(flowcontrol,fc_no_direct_exit);
          end;

        { do second pass on left node }
        if Assigned(Left) then
         begin
           lStatement:=TStatementNode(Left);
           while Assigned(lStatement) do
            begin
              if Assigned(lStatement.Left) then
               begin
                 SecondPass(lStatement.Left);
                 Location_Copy(lStatement.Location,lStatement.Left.Location);
               end;
              Location_Copy(Location,lStatement.Location);
              lStatement:=TStatementNode(lStatement.Right);
            end;
         end;

        { write exitlabel }
        if nf_block_with_exit in Flags then
          begin
            cg.A_Label(CurrentAsmData.CurrAsmList,CurrentProcInfo.CurrExitLabel);
            CurrentProcInfo.CurrExitLabel:=lOldExitLabel;
            { the exit statements inside this block are not exit statements }
            { out of the parent                                             }
            flowcontrol:=lOldFlowControl+(flowcontrol - [fc_exit,fc_no_direct_exit]);
          end;
      end;


{*****************************************************************************
                          TTEMPCREATENODE
*****************************************************************************}

    procedure TCGTempCreateNode.Pass_Generate_Code;
      begin
        Location_Reset(Location,LOC_VOID,OS_NO);

        { if we're secondpassing the same tcgtempcreatenode twice, we have a bug }
        if (ti_valid in TempFlags) then
          InternalError(200108222);

        { in case of ti_reference, the location will be initialised using the
          location of the tempinitnode once the first temprefnode is processed }
        if not(ti_reference in TempFlags) then
          begin
            { get a (persistent) temp }
            if Is_Managed_Type(TempInfo^.TypeDef) and
              not(ti_const in TempFlags) then
              begin
                Location_Reset_Ref(TempInfo^.Location,LOC_REFERENCE,Def_CGSize(TempInfo^.TypeDef),0,[]);
                TG.GetHLTempManaged(CurrentAsmData.CurrAsmList,TempInfo^.TypeDef,TempInfo^.TempType,TempInfo^.Location.Reference);
                if not(ti_nofini in TempFlags) then
                  hlcg.G_Finalize(CurrentAsmData.CurrAsmList,TempInfo^.TypeDef,TempInfo^.Location.Reference);
              end
            else if (ti_may_be_in_reg in TempFlags) then
              begin
                Location_Allocate_Register(CurrentAsmData.CurrAsmList,TempInfo^.Location,TempInfo^.TypeDef,TempInfo^.TempType = tt_persistent);
              end
            else
              begin
                Location_Reset_Ref(TempInfo^.Location,LOC_REFERENCE,Def_CGSize(TempInfo^.TypeDef),0,[]);
                TG.GetHLTemp(CurrentAsmData.CurrAsmList,TempInfo^.TypeDef,Size,TempInfo^.TempType,TempInfo^.Location.Reference);
              end;
          end;
        IncludeTempFlag(ti_valid);
        if Assigned(TempInfo^.TempInitCode) then
          IncludeTempFlag(ti_executeinitialisation);
      end;


{*****************************************************************************
                             TTEMPREFNODE
*****************************************************************************}

    procedure TCGTempRefNode.Pass_Generate_Code;
      begin
        if ti_executeinitialisation in TempFlags then
          begin
            { avoid recursion }
            ExcludeTempFlag(ti_executeinitialisation);
            SecondPass(TempInfo^.TempInitCode);
            if (ti_reference in TempFlags) then
              begin
                case TempInfo^.TempInitCode.Location.Loc of
                  LOC_CREGISTER,
                  LOC_CFPUREGISTER,
                  LOC_CMMREGISTER,
                  LOC_CSUBSETREG:
                    begin
                      { although it's ok if we need this value multiple times
                        for reading, it's not in case of writing (because the
                        register could change due to SSA -> storing to the saved
                        register afterwards would be wrong). }
                      if not(ti_readonly in TempFlags) then
                        InternalError(2011031407);
                    end;
                  { in case reference contains CREGISTERS, that doesn't matter:
                    we want to write to the location indicated by the current
                    value of those registers, and we can save those values }
                  else
                    ;
                end;
                hlcg.G_Reference_Loc(CurrentAsmData.CurrAsmList,TempInfo^.TypeDef,TempInfo^.TempInitCode.Location,TempInfo^.Location);
              end;
          end;
        { check if the temp is valid }
        if not(ti_valid in TempFlags) then
          InternalError(200108231);
        Location:=TempInfo^.Location;
        { Allow CPU-specific adjustment of temp references (e.g., for exceptfilters) }
        if Location.Loc=LOC_REFERENCE then
          cg.Adjust_ExceptFilter_Ref(Location.Reference,false);
        case TempInfo^.Location.Loc of
          LOC_REFERENCE:
            begin
              { ti_valid should be excluded if it's a normal temp }
            end;
          LOC_REGISTER,
          LOC_FPUREGISTER,
          LOC_MMREGISTER :
            ExcludeTempFlag(ti_valid);
          else
            ;
        end;
      end;


    procedure TCGTempRefNode.ChangeLocation(const AReference: TReference);
      begin
        { check if the temp is valid }
        if not(ti_valid in TempFlags) then
          InternalError(200306081);
        if (TempInfo^.Location.Loc<>LOC_REFERENCE) then
          InternalError(2004020203);
        if (TempInfo^.TempType = tt_persistent) then
          TG.ChangeTempType(CurrentAsmData.CurrAsmList,TempInfo^.Location.Reference,tt_normal);
        TG.UnGetTemp(CurrentAsmData.CurrAsmList,TempInfo^.Location.Reference);
        TempInfo^.Location.Reference := AReference;
        TG.ChangeTempType(CurrentAsmData.CurrAsmList,TempInfo^.Location.Reference,TempInfo^.TempType);
        { adapt location }
        Location.Reference := AReference;
      end;


{*****************************************************************************
                           TTEMPDELETENODE
*****************************************************************************}

    procedure TCGTempDeleteNode.Pass_Generate_Code;
      begin
        if ti_reference in TempFlags then
          begin
            { release_to_normal means that the temp will be freed the next
              time it's used. However, reference temps reference some other
              location that is not managed by this temp and hence cannot be
              freed }
            if FReleaseToNormal then
              InternalError(2011052205);
            { so we only mark this temp location as "no longer valid" when
              it's deleted (ttempdeletenodes are also used during getcopy, so
              we really do need one) }
            ExcludeTempFlag(ti_valid);
            exit;
          end;

        Location_Reset(Location,LOC_VOID,OS_NO);

        if ti_cleanup_only in TempFlags then
          exit;

        { see comments at ti_const declaration: if we initialised this temp with
          the value of another temp, that other temp was not freed because the
          ti_const flag was set }
        if (ti_const in TempFlags) and
           Assigned(TempInfo^.TempInitCode) then
          begin
            if TempInfo^.TempInitCode.NodeType<>assignn then
              InternalError(2016081201);
            if TBinaryNode(TempInfo^.TempInitCode).Right.Location.Loc in [LOC_REFERENCE,LOC_CREFERENCE] then
              TG.UnGetIfTemp(CurrentAsmData.CurrAsmList,TBinaryNode(TempInfo^.TempInitCode).Right.Location.Reference);
          end;


        case TempInfo^.Location.Loc of
          LOC_REFERENCE:
            begin
              if FReleaseToNormal then
                TG.ChangeTempType(CurrentAsmData.CurrAsmList,TempInfo^.Location.Reference,tt_normal)
              else
                begin
                  TG.UnGetTemp(CurrentAsmData.CurrAsmList,TempInfo^.Location.Reference);
                  ExcludeTempFlag(ti_valid);
                end;
            end;
          LOC_CREGISTER,
          LOC_REGISTER:
            begin
              if (not(cs_opt_regvar in CurrentSettings.OptimizerSwitches) or
                 (pi_has_label in CurrentProcInfo.Flags)) and not(ti_no_final_regsync in TempFlags) then
                begin
                  { make sure the register allocator doesn't reuse the }
                  { register e.g. in the middle of a loop              }
{$if defined(cpu32bitalu) and not defined(cpuhighleveltarget)}
                  if TempInfo^.Location.Size in [OS_64,OS_S64] then
                    begin
                      cg.A_Reg_Sync(CurrentAsmData.CurrAsmList,TempInfo^.Location.Register64.RegHi);
                      cg.A_Reg_Sync(CurrentAsmData.CurrAsmList,TempInfo^.Location.Register64.RegLo);
                    end
                  else
{$endif}
                    cg.A_Reg_Sync(CurrentAsmData.CurrAsmList,TempInfo^.Location.Register);
                end;
              if FReleaseToNormal then
                TempInfo^.Location.Loc := LOC_REGISTER
              else
                ExcludeTempFlag(ti_valid);
            end;
          LOC_CFPUREGISTER,
          LOC_FPUREGISTER:
            begin
              if (not(cs_opt_regvar in CurrentSettings.OptimizerSwitches) or
                 (pi_has_label in CurrentProcInfo.Flags)) and not(ti_no_final_regsync in TempFlags) then
                begin
                  { make sure the register allocator doesn't reuse the }
                  { register e.g. in the middle of a loop              }
                  cg.A_Reg_Sync(CurrentAsmData.CurrAsmList,TempInfo^.Location.Register);
                end;
              if FReleaseToNormal then
                TempInfo^.Location.Loc := LOC_FPUREGISTER
              else
                ExcludeTempFlag(ti_valid);
            end;
          LOC_CMMREGISTER,
          LOC_MMREGISTER:
            begin
              if (not(cs_opt_regvar in CurrentSettings.OptimizerSwitches) or
                 (pi_has_label in CurrentProcInfo.Flags)) and not(ti_no_final_regsync in TempFlags) then
                begin
                  { make sure the register allocator doesn't reuse the }
                  { register e.g. in the middle of a loop              }
                  cg.A_Reg_Sync(CurrentAsmData.CurrAsmList,TempInfo^.Location.Register);
                end;
              if FReleaseToNormal then
                TempInfo^.Location.Loc := LOC_MMREGISTER
              else
                ExcludeTempFlag(ti_valid);
            end;
          else
            InternalError(200507161);
        end;
      end;


{*****************************************************************************
                         TCGFINALIZETEMPSNODE
*****************************************************************************}

    procedure TCGFinalizeTempsNode.Pass_Generate_Code;
      begin
        hlcg.Gen_Finalize_Code(CurrentAsmData.CurrAsmList);
        Location.Loc:=LOC_VOID;
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
