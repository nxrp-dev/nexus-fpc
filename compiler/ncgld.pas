 {
    Copyright (c) 1998-2002 by Florian Klaempfl

    Generate assembler for nodes that handle loads and assignments which
    are the same for all (most) processors

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
unit ncgld;

{$i fpcdefs.inc}

interface

    uses
      GlobType,
      symtype,SymSym,
      AAsmData,
      node,nld,cgutils;

    type
       TCGLoadNode = class(TLoadNode)
         protected
          procedure Generate_Nested_Access(ASym: TSym);virtual;
          procedure Generate_AbsAddr_Access(AVarSym: TAbsoluteVarSym); virtual;
          procedure Generate_ThreadVar_Access(AVarSym: TStaticVarSym); virtual;
          function Use_Indirect_Symbol(AVarSym: TStaticVarSym): Boolean;
         public
          procedure Pass_Generate_Code;override;
          procedure ChangeRefLocation(const AReference: TReference);
       end;

       TCGAssignmentNode = class(TAssignmentNode)
        protected
          function MaybeChangeTemp(AList: TAsmList; var ANode: TNode; const ANewReference: TReference): Boolean;virtual;
        public
          procedure Pass_Generate_Code;override;
       end;

       TCGArrayConstructorNode = class(TArrayConstructorNode)
         protected
          procedure MakeArrayRef(var AReference: TReference; AElementDef: TDef);virtual;
          procedure AdvanceArrayOffset(var AReference: TReference; AElementSize: ASizeInt);virtual;
         public
          procedure Pass_Generate_Code;override;
       end;

       TCGRTTINode = class(TRTTINode)
          procedure Pass_Generate_Code;override;
       end;


implementation

    uses
      CUtils,
      Systems,
      Verbose,Globals,ConstExp,FModule,
      nutils,
      SymTable,symconst,symdef,defutil,paramgr,ncon,nbas,ncgrtti,
      aasmbase,
      cgbase,pass_2,
      ProcInfo,
      CPUInfo,
      cpubase,parabase,
      tgobj,
      cgobj,hlcgobj,
      ncgbas,ncgflw,
      wpobase;

{*****************************************************************************
                   SSA (for memory temps) support
*****************************************************************************}

    type
      PReplaceRefRec = ^TReplaceRefRec;
      TReplaceRefRec = record
        Old, New: PReference;
        ResultSym: TSym;
      end;

    function DoReplaceRef(var ANode: TNode; AArg: pointer): TForEachNodeResult;
      var
        lReplacement: PReplaceRefRec absolute AArg;
      begin
        Result := fen_false;
        case ANode.NodeType of
          loadn:
            begin
                 { regular variable }
              if (TAbstractVarSym(TLoadNode(ANode).SymTableEntry).VarOptions * [vo_is_dll_var, vo_is_thread_var] = []) and
                 not Assigned(TLoadNode(ANode).Left) and
                 { not function result, or no exit in function }
                 (((TLoadNode(ANode).SymTableEntry <> lReplacement^.ResultSym) and
                   not(vo_is_funcret in TAbstractVarSym(TLoadNode(ANode).SymTableEntry).VarOptions)) or
                  not(fc_exit in flowcontrol)) and
                 { stored in memory... }
                 (TAbstractNormalVarSym(TLoadNode(ANode).SymTableEntry).LocAlloc.Loc in [LOC_REFERENCE]) and
                 { ... at the place we are looking for }
                 References_Equal(TAbstractNormalVarSym(TLoadNode(ANode).SymTableEntry).LocAlloc.Reference,lReplacement^.Old^) and
                 { its address cannot have escaped the current routine }
                 not(TAbstractVarSym(TLoadNode(ANode).SymTableEntry).AddrTaken) and
                 { it is not accessed in nested procedures }
                 not(TAbstractVarSym(TLoadNode(ANode).SymTableEntry).DifferentScope) then
                begin
                  { relocate variable }
                  TCGLoadNode(ANode).ChangeRefLocation(lReplacement^.New^);
                  Result := fen_norecurse_true;
                end;
            end;
          temprefn:
            begin
              if (ti_valid in TTempRefNode(ANode).TempFlags) and
                 { memory temp... }
                 (TTempRefNode(ANode).TempInfo^.Location.Loc in [LOC_REFERENCE]) and
                 { ... at the place we are looking for }
                 References_Equal(TTempRefNode(ANode).TempInfo^.Location.Reference,lReplacement^.Old^) and
                 { its address cannot have escaped the current routine }
                 not(ti_addr_taken in TTempRefNode(ANode).TempFlags) then
                begin
                  { relocate the temp }
                  TCGTempRefNode(ANode).ChangeLocation(lReplacement^.New^);
                  Result := fen_norecurse_true;
                end;
            end;
          { Subscriptn must be rejected, otherwise we may replace an
            an entire record with a temp for its first field, mantis #13948)
            Exception: the field's size is the same as the entire record

            The same goes for array indexing
          }
          subscriptn,
          vecn:
            if not(TUnaryNode(ANode).Left.ResultDef.Typ in [recorddef,objectdef,arraydef,stringdef]) or
               { make sure we don't try to call resultdef.size for types that
                 don't have a compile-time size such as open arrays }
               Is_Special_Array(TUnaryNode(ANode).Left.ResultDef) or
               (TUnaryNode(ANode).Left.ResultDef.Size<>TUnaryNode(ANode).ResultDef.Size) then
              Result := fen_norecurse_false;

          { optimize the searching a bit }
          derefn,addrn,
          calln,inlinen,casen,
          addn,subn,muln,
          andn,orn,xorn,
          ltn,lten,gtn,gten,EqualN,unequaln,
          slashn,divn,shrn,shln,notn,
          inn,
          asn,isn:
            Result := fen_norecurse_false;
          else
            ;
        end;
      end;


    function TCGAssignmentNode.MaybeChangeTemp(AList: TAsmList; var ANode: TNode; const ANewReference: TReference): Boolean;
      var
        lReplacement: TReplaceRefRec;
      begin
        Result := false;

        { only do for -O2 or higher (breaks debugging since }
        { variables move to different memory locations)     }
        if not(cs_opt_level2 in CurrentSettings.OptimizerSwitches) or
           { must be a copy to a memory location ... }
           (ANode.Location.Loc <> LOC_REFERENCE) or
           { not inside a control flow statement and no goto's in sight }
           ([fc_inflowcontrol,fc_gotolabel] * flowcontrol <> []) or
           { not for refcounted types, because those locations are   }
           { still used later on in initialisation/finalisation code }
           Is_Managed_Type(ANode.ResultDef) or
           { source and destination are temps (= not global variables) }
           { and both point to the start of a temp, and the source is a }
           { non-persistent temp (otherwise we need some kind of copy-  }
           { on-write support in case later on both are still used)     }
           not TG.IsStartOfTemp(ANewReference) or
           not TG.IsStartOfTemp(ANode.Location.Reference) or
           (TG.GetTypeOfTemp(ANewReference) <> tt_normal) or
           not (TG.GetTypeOfTemp(ANode.Location.Reference) in [tt_normal,tt_persistent]) or
           { and both have the same size }
           (TG.SizeOfTemp(CurrentAsmData.CurrAsmList,ANewReference) <> TG.SizeOfTemp(CurrentAsmData.CurrAsmList,ANode.Location.Reference)) then
          exit;

        { find the source of the old reference (loadnode or tempnode) }
        { and replace it with the new reference                       }
        lReplacement.Old := @ANode.Location.Reference;
        lReplacement.New := @ANewReference;
        lReplacement.ResultSym := nil;

        if Assigned(CurrentProcInfo.ProcDef.FuncRetSym) and
           (TAbstractVarSym(CurrentProcInfo.ProcDef.FuncRetSym).refs <> 0) then
          if (CurrentProcInfo.ProcDef.ProcTypeOption=potype_constructor) then
            lReplacement.ResultSym:=TSym(CurrentProcInfo.ProcDef.ParaST.Find('self'))
         else
            lReplacement.ResultSym:=CurrentProcInfo.ProcDef.FuncRetSym;

        { if source not found, don't do anything }
        if not ForEachNodeStatic(ANode,@DoReplaceRef,@lReplacement) then
          exit;

        ANode.Location.Reference := ANewReference;
        Result:=true;
      end;

{*****************************************************************************
                             SecondLoad
*****************************************************************************}

    procedure TCGLoadNode.ChangeRefLocation(const AReference: TReference);
      var
        lOldTempType: TTempType;
      begin
        if (Location.Loc<>LOC_REFERENCE) then
          InternalError(2007020812);
        if not TG.IsTemp(Location.Reference) then
          InternalError(2007020813);
        lOldTempType:=TG.GetTypeOfTemp(Location.Reference);
        if (lOldTempType = tt_persistent) then
          TG.ChangeTempType(CurrentAsmData.CurrAsmList,Location.Reference,tt_normal);
        TG.UnGetTemp(CurrentAsmData.CurrAsmList,Location.Reference);
        Location.Reference:=AReference;
        TG.ChangeTempType(CurrentAsmData.CurrAsmList,Location.Reference,lOldTempType);
        TAbstractNormalVarSym(SymTableEntry).LocAlloc:=Location;
        hlcg.RecordNewSymLoc(CurrentAsmData.CurrAsmList,SymTableEntry,TAbstractNormalVarSym(SymTableEntry).vardef,Location.Reference,false);
      end;


    procedure TCGLoadNode.Generate_Nested_Access(ASym: TSym);
      var
        { parameter declared as tsym to reduce interface unit dependencies }
        lVarSym: TAbstractNormalVarSym absolute ASym;
      begin
        SecondPass(Left);
        if not(Left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          InternalError(200309286);
        if lVarSym.LocAlloc.Loc<>LOC_REFERENCE then
          InternalError(200409241);
        hlcg.Reference_Reset_Base(Location.Reference,Left.ResultDef,Left.Location.Register,lVarSym.LocAlloc.Reference.Offset,CTempPosInvalid,lVarSym.LocAlloc.Reference.Alignment,lVarSym.LocAlloc.Reference.Volatility);
      end;


    procedure TCGLoadNode.Generate_AbsAddr_Access(AVarSym: TAbsoluteVarSym);
      begin
        Location.Reference.Offset:=ASizeInt(AVarSym.AddrOffset);
        Location.Reference.Volatility:=[vol_read,vol_write];
      end;


    procedure TCGLoadNode.Generate_ThreadVar_Access(AVarSym: TStaticVarSym);
      var
        lProcDef: TProcDef;
        lPara, lResultPara: TCGPara;
        lReference: TReference;
        lReg: TRegister;
        lLocation: TLocation;
      begin
        if tf_section_threadvars in TargetInfo.Flags then
          begin
            if AVarSym.LocAlloc.Loc=LOC_INVALID then
              Reference_Reset_Symbol(Location.Reference,CurrentAsmData.RefAsmSymbol(AVarSym.MangledName,AT_TLS,Use_Indirect_Symbol(AVarSym)),0,Location.Reference.Alignment,[])
            else
              Location:=AVarSym.LocAlloc;
            exit;
          end;
        { Every variable names an image-owned descriptor. Startup and late
          images use the same resolver; there is no inline main-thread value. }
        lProcDef:=Search_System_Proc('fpc_threadvar_addr');
        lPara.init;
        ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,lProcDef,1,lPara);
        if vo_is_weak_external in AVarSym.VarOptions then
          Reference_Reset_Symbol(lReference,CurrentAsmData.WeakRefAsmSymbol(AVarSym.MangledName,AT_DATA),0,sizeof(PInt),[])
        else
          Reference_Reset_Symbol(lReference,CurrentAsmData.RefAsmSymbol(AVarSym.MangledName,AT_DATA,Use_Indirect_Symbol(AVarSym)),0,sizeof(PInt),[]);
        hlcg.A_LoadAddr_Ref_CGPara(CurrentAsmData.CurrAsmList,VoidPointerType,lReference,lPara);
        ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,lPara);
        lResultPara:=hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,lProcDef,[@lPara],VoidPointerType);
        lPara.done;
        lReg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,VoidPointerType);
        Location_Reset(lLocation,LOC_REGISTER,OS_ADDR);
        lLocation.Register:=lReg;
        hlcg.Gen_Load_CGPara_Loc(CurrentAsmData.CurrAsmList,VoidPointerType,lResultPara,lLocation,true);
        lResultPara.ResetIfTemp;
        hlcg.Reference_Reset_Base(Location.Reference,VoidPointerType,lReg,0,CTempPosInvalid,ResultDef.Alignment,[]);
      end;


    function TCGLoadNode.Use_Indirect_Symbol(AVarSym:TStaticVarSym):Boolean;
      begin
        { we are using a direct reference if any of the following is true:
          - the target does not support packages
          - the target does not use indirect references
          - the variable is declared as (weak) external
          - the variable is located inside the same unit }
        Result:=(tf_supports_packages in TargetInfo.Flags) and
                (TargetInfo.system in systems_indirect_var_imports) and
                (AVarSym.VarOptions*[vo_is_external,vo_is_weak_external]=[]) and
                (AVarSym.owner.SymTableType in [GlobalSymTable,staticsymtable]) and
                not Sym_Is_Owned_By(AVarSym,CurrentModule.GlobalSymTable) and
                (
                  (CurrentModule.GlobalSymTable=CurrentModule.LocalSymTable) or
                  not Sym_Is_Owned_By(AVarSym,CurrentModule.LocalSymTable)
                );
      end;

    procedure TCGLoadNode.Pass_Generate_Code;
      var
        lReg : TRegister;
        lVarSym   : TAbstractNormalVarSym;
        lGlobalVarSym  : TStaticVarSym;
        lVMTDef : TPointerDef;
        lVMTEntry: TFieldVarSym;
        lProcDef   : TProcDef;
        lReference : TReference;
        lNewSize : TCgSize;
        lVarDef : TDef;
        lAlignment: LongInt;
        lIndirect : Boolean;
        lName : TSymStr;
      begin
        { we don't know the size of all arrays }
        lNewSize:=Def_CGSize(ResultDef);
        { alignment is overridden per case below }
        Location_Reset_Ref(Location,LOC_REFERENCE,lNewSize,ResultDef.Alignment,[]);
        case SymTableEntry.Typ of
           absolutevarsym :
              begin
                 { this is only for toasm and toaddr }
                 case TAbsoluteVarSym(SymTableEntry).AbsTyp of
                   toaddr :
                     Generate_AbsAddr_Access(TAbsoluteVarSym(SymTableEntry));
                   toasm :
                     Location.Reference.Symbol:=CurrentAsmData.RefAsmSymbol(TAbsoluteVarSym(SymTableEntry).MangledName,AT_DATA);
                   else
                     InternalError(200310283);
                 end;
              end;
           constsym:
             begin
                if TConstSym(SymTableEntry).ConstTyp in [constresourcestring,constwresourcestring] then
                  begin
                     Location_Reset_Ref(Location,LOC_CREFERENCE,Def_CGSize(CAnsiStringType),CAnsiStringType.Size,[]);
                     lIndirect:=(tf_supports_packages in TargetInfo.Flags) and
                                 (TargetInfo.system in systems_indirect_var_imports) and
                                 (SymTableEntry.owner.ModuleID<>CurrentModule.ModuleID);
                     lName:=Make_MangledName('RESSTR',SymTableEntry.owner,SymTableEntry.name);
                     Location.Reference.Symbol:=CurrentAsmData.RefAsmSymbol(lName,AT_DATA,lIndirect);
                     if SymTableEntry.owner.ModuleID<>CurrentModule.ModuleID then
                       CurrentModule.AddImportedSym(SymTableEntry);
                     lVarDef:=Search_System_Type('TRESOURCESTRINGRECORD').TypeDef;
                     hlcg.G_Set_Addr_NonBitPacked_Field_Ref(
                       CurrentAsmData.CurrAsmList,
                       TRecordDef(lVarDef),
                       TFieldVarSym(Search_Struct_Member(TRecordDef(lVarDef),'CURRENTVALUE')),
                       Location.Reference);
                  end
                else
                  InternalError(22798);
             end;
           staticvarsym :
             begin
               lGlobalVarSym:=TStaticVarSym(SymTableEntry);

               if (vo_is_dll_var in lGlobalVarSym.VarOptions) then
               { DLL variable }
                 begin
                   lReg:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
                   if not(vo_is_weak_external in lGlobalVarSym.VarOptions) then
                     Location.Reference.Symbol:=CurrentAsmData.RefAsmSymbol(TStaticVarSym(SymTableEntry).MangledName,AT_DATA)
                   else
                     Location.Reference.Symbol:=CurrentAsmData.WeakRefAsmSymbol(TStaticVarSym(SymTableEntry).MangledName,AT_DATA);
                   cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,Location.Reference,lReg);
                   Reference_Reset_Base(Location.Reference,lReg,0,CTempPosInvalid,Location.Reference.Alignment,[]);
                 end
               { Thread variable }
               else if (vo_is_thread_var in lGlobalVarSym.VarOptions) then
                 Generate_ThreadVar_Access(lGlobalVarSym)
               { Normal (or external) variable }
               else
                 begin
                   if lGlobalVarSym.LocAlloc.Loc=LOC_INVALID then
                     begin
                       { static data is currently always volatile }
                       if not(vo_is_weak_external in lGlobalVarSym.VarOptions) then
                         Reference_Reset_Symbol(Location.Reference,CurrentAsmData.RefAsmSymbol(lGlobalVarSym.MangledName,AT_DATA,Use_Indirect_Symbol(lGlobalVarSym)),0,Location.Reference.Alignment,[])
                       else
                         Reference_Reset_Symbol(Location.Reference,CurrentAsmData.WeakRefAsmSymbol(lGlobalVarSym.MangledName,AT_DATA),0,Location.Reference.Alignment,[])
                     end
                   else
                      Location:=lGlobalVarSym.LocAlloc;
                  end;

                { make const a LOC_CREFERENCE }
                if (lGlobalVarSym.VarSpez=vs_const) and
                   (Location.Loc=LOC_REFERENCE) then
                  Location.Loc:=LOC_CREFERENCE;
              end;
            paravarsym,
            localvarsym :
              begin
                lVarSym:=TAbstractNormalVarSym(SymTableEntry);
                { Nested variable }
                if Assigned(Left) then
                  Generate_Nested_Access(lVarSym)
                else
                  Location:=lVarSym.LocAlloc;

                { handle call by reference variables when they are not
                  already copied to local copies. Also ignore the reference
                  when we need to load the self pointer for objects }
                if Is_Addr_Param_Load then
                  begin
                    if (Location.Loc in [LOC_CREGISTER,LOC_REGISTER]) then
                      lReg:=Location.Register
                    else
                      begin
                        lVarDef:=CPointerDef.getreusable(ResultDef);
                        lReg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,lVarDef);
                        { we need to load only an address }
                        Location.Size:=Int_CGSize(lVarDef.Size);
                        hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,lVarDef,lVarDef,Location,lReg);
                      end;
                    { assume packed records may always be unaligned }
                    if not(ResultDef.Typ in [recorddef,objectdef]) or
                       (TAbstractRecordSymTable(TAbstractRecordDef(ResultDef).SymTable).UseFieldAlignment<>1) then
                      begin
                        lAlignment:=min(min(min(ResultDef.Alignment,CurrentSettings.Alignment.LocalAlignMax),CurrentSettings.Alignment.ConstAlignMax),CurrentSettings.Alignment.VarAlignMax);
                        Location_Reset_Ref(Location,LOC_REFERENCE,lNewSize,lAlignment,[]);
                      end
                    else
                      Location_Reset_Ref(Location,LOC_REFERENCE,lNewSize,1,[]);
                    hlcg.Reference_Reset_Base(Location.Reference,VoidPointerType,lReg,0,CTempPosInvalid,Location.Reference.Alignment,[]);
                  end;

                { make const a LOC_CREFERENCE }
                if (lVarSym.VarSpez=vs_const) and
                   (Location.Loc=LOC_REFERENCE) then
                  Location.Loc:=LOC_CREFERENCE;
             end;
           ProcSym:
              begin
                 if not Assigned(ProcDef) then
                   InternalError(200312011);
                 if Assigned(Left) and
                   (ResultDef.Typ in [symconst.ProcDef,procvardef]) and
                    not TAbstractProcDef(ResultDef).Is_AddressOnly then
                   begin
                     Location_Reset(Location,LOC_CREGISTER,Int_CGSize(VoidPointerType.Size*2));

                     SecondPass(Left);

                     { load class instance/classrefdef address }
                     if Left.Location.Loc=LOC_CONSTANT then
                       hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,Left.Location,Left.ResultDef,Left.ResultDef,false);
                     { vd will contain the type of the self pointer (self in
                       case of a class/classref, address of self in case of
                       an object, frame pointer or pointer to parentfpstruct
                       in case of nested procsym load  }
                     lVarDef:=nil;
                     case Left.Location.Loc of
                        LOC_CREGISTER,
                        LOC_REGISTER:
                          begin
                             { this is not possible for objects }
                             if Is_Object(Left.ResultDef) then
                               InternalError(200304234);

                             Location.RegisterHi:=Left.Location.Register;

                             lVarDef:=Left.ResultDef;
                          end;
                        LOC_CREFERENCE,
                        LOC_REFERENCE:
                          begin
                             if Is_Implicit_Pointer_Object_Type(Left.ResultDef) or
                                (Left.ResultDef.Typ=classrefdef) or
                                Is_Nested_PD(ProcDef) then
                               begin
                                 lVarDef:=Left.ResultDef;

                                 Location.RegisterHi:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,Left.ResultDef);
                                 hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef,Left.Location.Reference,Location.RegisterHi)

                               end
                             else
                               begin
                                 lVarDef:=CPointerDef.getreusable(Left.ResultDef);

                                 Location.RegisterHi:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,lVarDef);
                                 hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,lVarDef,Left.Location.Reference,Location.RegisterHi);

                               end;
                             Location_FreeTemp(CurrentAsmData.CurrAsmList,Left.Location);
                          end;
                        else
                          InternalError(200610311);
                     end;

                     { virtual method ? }
                     if (po_virtualmethod in ProcDef.ProcOptions) and
                        not(loadnf_inherited in LoadNodeFlags) and
                        not Is_ObjectPascal_Helper(ProcDef.struct) then
                       begin
                         if (not Assigned(CurrentProcInfo) or
                             wpoinfomanager.symbol_live(CurrentProcInfo.ProcDef.MangledName)) then
                           TObjectDef(ProcDef.struct).Register_VMT_Call(ProcDef.ExtNumber);
            {$ifdef vtentry}
                         if not Is_Interface(ProcDef.struct) then
                           begin
                             inc(CurrentAsmData.NextVTEntryNr);
                             CurrentAsmData.CurrAsmList.Concat(TAISymbol.CreateName('VTREF'+ToStr(CurrentAsmData.NextVTEntryNr)+'_'+ProcDef._class.VMT_MangledName+'$$'+ToStr(vmtoffset div sizeof(PInt)),AT_FUNCTION,0,voidpointerdef));
                           end;
            {$endif vtentry}
                         if (Left.ResultDef.Typ=objectdef) and
                            Assigned(TObjectDef(Left.ResultDef).VMTField) then
                           begin
                             { vmt pointer is a pointer to the vmt record }
                             hlcg.Reference_Reset_Base(lReference,lVarDef,Location.RegisterHi,0,CTempPosInvalid,lVarDef.Alignment,[]);
                             lVMTDef:=CPointerDef.getreusable(TObjectDef(Left.ResultDef).VMT_Def);
                             hlcg.G_Set_Addr_NonBitPacked_Field_Ref(CurrentAsmData.CurrAsmList,TObjectDef(Left.ResultDef),TFieldVarSym(TObjectDef(Left.ResultDef).VMTField),lReference);
                             lReg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,lVMTDef);
                             hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,TFieldVarSym(TObjectDef(Left.ResultDef).VMTField).vardef,lVMTDef,lReference,lReg);
                           end
                         else if Left.ResultDef.Typ=classrefdef then
                           begin
                             lVMTDef:=CPointerDef.getreusable(TObjectDef(TClassRefDef(Left.ResultDef).PointedDef).VMT_Def);
                             { classrefdef is a pointer to the vmt already }

                             { targets with 32 bit method pointers got already a register assigned }
                             lReg:=Location.RegisterHi;

                             hlcg.G_PtrTypeCast_Reg(CurrentAsmData.CurrAsmList,Left.ResultDef,lVMTDef,lReg);
                           end
                         else if Is_Any_Interface_Kind(Left.ResultDef) then
                           begin
                             { an interface is a pointer to a pointer to a vmt }
                             hlcg.Reference_Reset_Base(lReference,lVarDef,Location.RegisterHi,0,CTempPosInvalid,lVarDef.Alignment,[]);
                             lVMTDef:=CPointerDef.getreusable(TObjectDef(Left.ResultDef).VMT_Def);
                             lReg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,lVMTDef);
                             hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,lVMTDef,lVMTDef,lReference,lReg);
                           end
                         else
                           InternalError(2015112501);
                         { load method address }
                         lVMTEntry:=TAbstractRecordSymTable(TRecordDef(lVMTDef.PointedDef).SymTable).FindFieldByOffset(
                           TObjectDef(ProcDef.struct).VMTMethodOffset(ProcDef.ExtNumber));
                         hlcg.Reference_Reset_Base(lReference,lVMTDef,lReg,0,CTempPosInvalid,lVMTDef.Alignment,[]);
                         { targets with 32 bit method pointers got already a register assigned }

                         Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,lVMTEntry.vardef);

                         hlcg.G_Set_Addr_NonBitPacked_Field_Ref(CurrentAsmData.CurrAsmList,TAbstractRecordDef(lVMTDef.PointedDef),lVMTEntry,lReference);
                         hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,lVMTEntry.vardef,lVMTEntry.vardef,lReference,Location.Register);
                       end
                     else
                       begin
                         { load address of the function }
                         Reference_Reset_Symbol(lReference,CurrentAsmData.RefAsmSymbol(ProcDef.MangledName,AT_FUNCTION),0,ProcDef.Address_Type.Alignment,[]);
                         { targets with 32 bit method pointers got already a register assigned }

                         Location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,CProcVarDef.GetReusableProcAddr(ProcDef,pc_address_only));

                         hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,ProcDef,CProcVarDef.GetReusableProcAddr(ProcDef,pc_address_only),lReference,Location.Register);
                       end;


                   end
                 else
                   begin
                      lProcDef:=TProcDef(TProcSym(SymTableEntry).ProcdefList[0]);
                      { def_cgsize does not work for tprocdef, so we use pd.address_type }
                      Location.Size:=Def_CGSize(lProcDef.Address_Type);
                      if not(po_weakexternal in lProcDef.ProcOptions) then
                        Location.Reference.Symbol:=CurrentAsmData.RefAsmSymbol(ProcDef.MangledName,AT_FUNCTION)
                      else
                        Location.Reference.Symbol:=CurrentAsmData.WeakRefAsmSymbol(ProcDef.MangledName,AT_FUNCTION);
                   end;
              end;
           labelsym :
             if Assigned(TLabelSym(SymTableEntry).AsmBlockLabel) then
               Location.Reference.Symbol:=TLabelSym(SymTableEntry).AsmBlockLabel
             else
               Location.Reference.Symbol:=TCGLabelNode((TLabelSym(SymTableEntry).code)).GetAsmLabel;
           else InternalError(200510032);
        end;
      end;


{*****************************************************************************
                             SecondAssignment
*****************************************************************************}

    procedure TCGAssignmentNode.Pass_Generate_Code;
      var
         lShuffle : PMMShuffle;
         lLabel : TAsmLabel;
         lReference : TReference;
         lReleaseRight : Boolean;
         lAlignmentRequirement,
         lLength : TCGInt;
         lReg : TRegister;
         {$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         lReg64 : TRegister64;
         {$endif}
         lOldFlowControl : TFlowControl;
      begin
        { previously, managed types were handled in firstpass
          newer FPCs however can identify situations when
          assignments of managed types require no special code and the
          value could be just copied so this could should be able also to handle
          managed types without any special "managing code"}

        Location_Reset(Location,LOC_VOID,OS_NO);

        {
          in most cases we can process first the right node which contains
          the most complex code. Exceptions for this are:
            - result is in flags, loading left will then destroy the flags
            - result is a jump, loading left must be already done before the jump is made
            - result need reference count, when left points to a value used in
              right then decreasing the refcnt on left can possibly release
              the memory before right increased the refcnt, result is that an
              empty value is assigned

           But not when the result is in the flags, then
           loading the left node afterwards can destroy the flags.

           Neither if right contains conditional nodes: this might cause problems with
           temp. nodes with init code used by CSE, see e.g. #38129
        }
        if not(Right.expectloc in [LOC_FLAGS,LOC_JUMP]) and
            (Node_Complexity(Right)>Node_Complexity(Left)) and not(Has_Conditional_Nodes(Right)) then
         begin
           SecondPass(Right);
           if CodeGenError then
             exit;

           SecondPass(Left);
           if CodeGenError then
             exit;
         end
        else
         begin
           { calculate left sides }
           SecondPass(Left);
           if CodeGenError then
             exit;

           { tell the SSA/SSL code that the left side was handled first so
             ni SSL is done
           }
           lOldFlowControl:=flowcontrol;
           include(flowcontrol,fc_lefthandled);

           SecondPass(Right);
           flowcontrol:=lOldFlowControl;

           if CodeGenError then
             exit;
         end;

        lReleaseRight:=
          (Left.NodeType<>temprefn) or
          not(ti_const in TTempRefNode(Left).TempFlags);

        { shortstring assignments are handled separately }
        if Is_ShortString(Left.ResultDef) then
          begin
            {
              we can get here only in the following situations
              for the right node:
               - empty constant string
               - char
            }

            { The addn is replaced by a blockn or calln that already returns
              a shortstring }
            if Is_ShortString(Right.ResultDef) and
               (Right.NodeType in [blockn,calln]) then
              begin
                { verify that we indeed have nothing to do }
                if not(anf_assign_done_in_right in AssignmentNodeFlags) then
                  InternalError(2015042201);
              end
            { empty constant string }
            else if (Right.NodeType=stringconstn) and
               (TStringConstNode(Right).Len=0) then
              begin
                hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(Left.ResultDef),TPointerDef(CharPointerType),Left.Location.Reference);
                hlcg.A_Load_Const_Ref(CurrentAsmData.CurrAsmList,CAnsiCharType,0,Left.Location.Reference);
              end
            { char loading }
            else if Is_Char(Right.ResultDef) then
              begin
                if Right.NodeType=ordconstn then
                  begin
                    hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(Left.ResultDef),CPointerDef.getreusable(U16IntType),Left.Location.Reference);
                    hlcg.A_Load_Const_Ref(CurrentAsmData.CurrAsmList,U16IntType,(TOrdConstNode(Right).Value.svalue shl 8) or 1,
                          SetAlignment(Left.Location.Reference,1));
                  end
                else
                  begin
                    lReference:=Left.Location.Reference;
                    hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(Left.ResultDef),TPointerDef(CharPointerType),lReference);
                    hlcg.A_Load_Const_Ref(CurrentAsmData.CurrAsmList,CAnsiCharType,1,lReference);
                    inc(lReference.Offset,1);
                    lReference.Alignment:=1;
                    case Right.Location.Loc of
                      LOC_REGISTER,
                      LOC_CREGISTER :
                        begin
{$ifndef cpuhighleveltarget}
                          lReg:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,Right.Location.Register,OS_8);
{$else not cpuhighleveltarget}
                          lReg:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,U8IntType);
                          hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,CAnsiCharType,U8IntType,Right.Location.Register,lReg);
{$endif cpuhighleveltarget}
                          hlcg.A_Load_Reg_Ref(CurrentAsmData.CurrAsmList,U8IntType,U8IntType,lReg,lReference);
                        end;
                      LOC_REFERENCE,
                      LOC_CREFERENCE :
                        hlcg.A_Load_Ref_Ref(CurrentAsmData.CurrAsmList,CAnsiCharType,CAnsiCharType,Right.Location.Reference,lReference);
                      else
                        InternalError(200205111);
                    end;
                  end;
              end
            else
              InternalError(2002042410);
          end
       { try to reuse memory locations instead of copying }
       { copy to a memory location ... }
        else if (Right.Location.Loc = LOC_REFERENCE) and
           MaybeChangeTemp(CurrentAsmData.CurrAsmList,Left,Right.Location.Reference) then
          begin
            { if it worked, we're done }
          end
        else
          begin
            { SSA support }
            hlcg.Maybe_Change_Load_Node_Reg(CurrentAsmData.CurrAsmList,Left,false);
            hlcg.Maybe_Change_Load_Node_Reg(CurrentAsmData.CurrAsmList,Right,true);
            case Right.Location.Loc of
              LOC_CONSTANT :
                begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                  if (Left.Location.Size in [OS_64,OS_S64]) or (Right.Location.Size in [OS_64,OS_S64]) then
                    cg64.A_Load64_Const_Loc(CurrentAsmData.CurrAsmList,Right.Location.Value64,Left.Location)
                  else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                    hlcg.A_Load_Const_Loc(CurrentAsmData.CurrAsmList,Left.ResultDef,Right.Location.Value,Left.Location);
                end;
              LOC_REFERENCE,
              LOC_CREFERENCE :
                begin
                  case Left.Location.Loc of
                    LOC_REGISTER,
                    LOC_CREGISTER :
                      begin
{$ifndef cpuhighleveltarget}
{$ifdef cpu64bitalu}
                        if Left.Location.Size in [OS_128,OS_S128] then
                          cg128.A_Load128_Ref_Reg(CurrentAsmData.CurrAsmList,Right.Location.Reference,Left.Location.Register128)
                        else
{$else cpu64bitalu}
                        if Left.Location.Size in [OS_64,OS_S64] then
                          cg64.A_Load64_Ref_Reg(CurrentAsmData.CurrAsmList,Right.Location.Reference,Left.Location.Register64)
                        else
{$endif cpu64bitalu}
{$endif not cpuhighleveltarget}
                          hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,Right.ResultDef,Left.ResultDef,Right.Location.Reference,Left.Location.Register);
                      end;
                    LOC_FPUREGISTER,
                    LOC_CFPUREGISTER :
                      begin
                        hlcg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,
                            Right.ResultDef,Left.ResultDef,
                            Right.Location.Reference,
                            Left.Location.Register);
                      end;
                    LOC_REFERENCE,
                    LOC_CREFERENCE :
                      begin
                        if (Left.ResultDef.Typ=floatdef) and
                           (Right.ResultDef.Typ=floatdef) and
                           ((Left.Location.Size<>Right.Location.Size)
                           { on newer (1993+ :)) x86 cpus, use the fpu to copy extended values }
{$ifdef x86}
                            or ({$ifndef x86_64}(CurrentSettings.CPUType>=cpu_Pentium) and{$endif x86_64}
                            (Is_Extended(Right.ResultDef) {$ifdef i386} or Is_Double(Right.ResultDef){$endif i386} ))
{$endif x86}
                           )then
                          begin
                            { assume that all float types can be handed by the
                              fpu if one can be handled by the fpu }
                            if not Use_VectorFPU(Left.ResultDef) or
                               not Use_VectorFPU(Right.ResultDef) then
                              hlcg.A_LoadFPU_Ref_Ref(CurrentAsmData.CurrAsmList,
                                Right.ResultDef,Left.ResultDef,
                                Right.Location.Reference,Left.Location.Reference)
                            else
                              hlcg.A_LoadMM_Ref_Ref(CurrentAsmData.CurrAsmList,
                                Right.ResultDef,Left.ResultDef,
                                Right.Location.Reference,Left.Location.Reference,MMS_MoveScalar)
                          end
                        else
                          begin
{ TODO: HACK: unaligned test, maybe remove all unaligned locations (array of char) from the compiler}
                            { Use unaligned copy when the offset is not aligned }
                            lLength:=Left.ResultDef.Size;

                            if lLength=0 then
                              lLength:=sizeof(PInt);

                            { data smaller than an aint has less alignment requirements }
                            { max(1,...) avoids div by zero in case of an empty record  }
                            lAlignmentRequirement:=min(max(1,lLength),sizeof(AInt));

                            if (Right.Location.Reference.Offset mod lAlignmentRequirement<>0) or
                              (Left.Location.Reference.Offset mod lAlignmentRequirement<>0) or
                              (Right.ResultDef.Alignment<lAlignmentRequirement) or
                              ((Right.Location.Reference.Alignment<>0) and
                               (Right.Location.Reference.Alignment<lAlignmentRequirement)) or
                              ((Left.Location.Reference.Alignment<>0) and
                               (Left.Location.Reference.Alignment<lAlignmentRequirement)) then
                              hlcg.G_ConcatCopy_Unaligned(CurrentAsmData.CurrAsmList,Left.ResultDef,Right.Location.Reference,Left.Location.Reference)
                            else
                              hlcg.G_ConcatCopy(CurrentAsmData.CurrAsmList,Left.ResultDef,Right.Location.Reference,Left.Location.Reference);
                          end;
                      end;
                    LOC_MMREGISTER,
                    LOC_CMMREGISTER:
                      begin
{$ifdef x86}
                        if (Right.ResultDef.Typ=floatdef) and
                           not Use_VectorFPU(Right.ResultDef) then
                          begin
                            { perform size conversion if needed (the mm-code cannot }
                            { convert an extended into a double/single, since sse   }
                            { doesn't support extended)                             }
                            lReg:=cg.GetFPURegister(CurrentAsmData.CurrAsmList,Right.Location.Size);
                            TG.GetHLTemp(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef.Size,tt_normal,lReference);
                            cg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,Right.Location.Size,Right.Location.Size,Right.Location.Reference,lReg);
                            cg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,Right.Location.Size,Left.Location.Size,lReg,lReference);
                            if lReleaseRight then
                              Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
                            lReleaseRight:=true;
                            Location_Reset_Ref(Right.Location,LOC_REFERENCE,Left.Location.Size,0,[]);
                            Right.Location.Reference:=lReference;
                            Right.ResultDef:=Left.ResultDef;
                          end;
{$endif}
                        hlcg.A_LoadMM_Ref_Reg(CurrentAsmData.CurrAsmList,
                          Right.ResultDef,
                          Left.ResultDef,
                          Right.Location.Reference,
                          Left.Location.Register,MMS_MoveScalar);
                      end;
                    LOC_SUBSETREG,
                    LOC_CSUBSETREG:
                      hlcg.A_Load_Ref_SubsetReg(CurrentAsmData.CurrAsmList,Right.ResultDef,Left.ResultDef,Right.Location.Reference,Left.Location.SReg);
                    LOC_SUBSETREF,
                    LOC_CSUBSETREF:
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if Right.Location.Size in [OS_64,OS_S64] then
                       cg64.A_Load64_Ref_SubsetRef(CurrentAsmData.CurrAsmList,Right.Location.Reference,Left.Location.SRef)
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                       hlcg.A_Load_Ref_SubsetRef(CurrentAsmData.CurrAsmList,Right.ResultDef,Left.ResultDef,Right.Location.Reference,Left.Location.SRef);
                    else
                      InternalError(200203284);
                  end;
                end;
              LOC_MMREGISTER,
              LOC_CMMREGISTER:
                begin
                  if (Is_Vector(Left.ResultDef)) then
                    lShuffle := nil
                  else
                    lShuffle := MMS_MoveScalar;

                  case Left.Location.Loc of
                    LOC_CMMREGISTER,
                    LOC_MMREGISTER:
                      hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,Right.ResultDef,Left.ResultDef,Right.Location.Register,Left.Location.Register, lShuffle);
                    LOC_REFERENCE,
                    LOC_CREFERENCE:
                      hlcg.A_LoadMM_Reg_Ref(CurrentAsmData.CurrAsmList,Right.ResultDef,Left.ResultDef,Right.Location.Register,Left.Location.Reference, lShuffle);
                    else
                      InternalError(2009112601);
                  end;
                end;
              LOC_REGISTER,
              LOC_CREGISTER :
                begin
{$ifndef cpuhighleveltarget}
{$ifdef cpu64bitalu}
                  if Left.Location.Size in [OS_128,OS_S128] then
                    cg128.A_Load128_Reg_Loc(CurrentAsmData.CurrAsmList,
                      Right.Location.Register128,Left.Location)
                  else
{$else cpu64bitalu}
                  { also OS_F64 in case of mmreg -> intreg }
                  if Left.Location.Size in [OS_64,OS_S64,OS_F64] then
                    cg64.A_Load64_Reg_Loc(CurrentAsmData.CurrAsmList,
                      Right.Location.Register64,Left.Location)
                  else
{$endif cpu64bitalu}
{$endif not cpuhighleveltarget}
                    hlcg.A_Load_Reg_Loc(CurrentAsmData.CurrAsmList,Right.ResultDef,Left.ResultDef,Right.Location.Register,Left.Location);
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER :
                begin
                  { we can't do direct moves between fpu and mm registers }
                  if Left.Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER] then
                    begin
{$ifdef x86}
                      if not Use_VectorFPU(Right.ResultDef) then
                        begin
                          { perform size conversion if needed (the mm-code cannot convert an   }
                          { extended into a double/single, since sse doesn't support extended) }
                          TG.GetHLTemp(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef.Size,tt_normal,lReference);
                          cg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,Right.Location.Size,Left.Location.Size,Right.Location.Register,lReference);
                          Location_Reset_Ref(Right.Location,LOC_REFERENCE,Left.Location.Size,0,[]);
                          Right.Location.Reference:=lReference;
                          Right.ResultDef:=Left.ResultDef;
                        end;
{$endif}
                      hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,Right.Location,Right.ResultDef,false);
                      hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,
                          Right.ResultDef,Left.ResultDef,
                          Right.Location.Register,Left.Location.Register,MMS_MoveScalar);
                    end
                  else
                    hlcg.A_LoadFPU_Reg_Loc(CurrentAsmData.CurrAsmList,
                        Right.ResultDef,Left.ResultDef,
                        Right.Location.Register,Left.Location);
                end;
              LOC_SUBSETREG,
              LOC_CSUBSETREG:
                begin
                  hlcg.A_Load_SubsetReg_Loc(CurrentAsmData.CurrAsmList,
                      Right.ResultDef,Left.ResultDef,Right.Location.SReg,Left.Location);
                end;
              LOC_SUBSETREF,
              LOC_CSUBSETREF:
                begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                  if Right.Location.Size in [OS_64,OS_S64] then
                   cg64.A_Load64_SubsetRef_Loc(CurrentAsmData.CurrAsmList,Right.Location.SRef,Left.Location)
                  else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                  hlcg.A_Load_SubsetRef_Loc(CurrentAsmData.CurrAsmList,
                      Right.ResultDef,Left.ResultDef,Right.Location.SRef,Left.Location);
                end;
              LOC_JUMP :
                begin
                  CurrentAsmData.getjumplabel(lLabel);
                  hlcg.A_Label(CurrentAsmData.CurrAsmList,Right.Location.TrueLabel);
                  if Is_PasBool(Left.ResultDef) then
                    begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if Left.Location.Size in [OS_64,OS_S64] then
                        cg64.A_Load64_Const_Loc(CurrentAsmData.CurrAsmList,1,Left.Location)
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                        hlcg.A_Load_Const_Loc(CurrentAsmData.CurrAsmList,Left.ResultDef,1,Left.Location)
                    end
                  else
                    begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if Left.Location.Size in [OS_64,OS_S64] then
                        cg64.A_Load64_Const_Loc(CurrentAsmData.CurrAsmList,-1,Left.Location)
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                        hlcg.A_Load_Const_Loc(CurrentAsmData.CurrAsmList,Left.ResultDef,-1,Left.Location);
                    end;

                  hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,lLabel);
                  hlcg.A_Label(CurrentAsmData.CurrAsmList,Right.Location.FalseLabel);
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                  if Left.Location.Size in [OS_64,OS_S64] then
                    cg64.A_Load64_Const_Loc(CurrentAsmData.CurrAsmList,0,Left.Location)
                  else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                    hlcg.A_Load_Const_Loc(CurrentAsmData.CurrAsmList,Left.ResultDef,0,Left.Location);
                  hlcg.A_Label(CurrentAsmData.CurrAsmList,lLabel);
                end;
{$ifdef cpuflags}
              LOC_FLAGS :
                begin
                  { check for cbool here as booleans converted to other types shall be handled as pas booleans,
                    see also tests/tbs/tw40908.pas }
                  if Is_CBool(Left.ResultDef) then
                    begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if Left.Location.Size in [OS_S64,OS_64] then
                        begin
                          lReg64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                          lReg64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                          cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,OS_32,Right.Location.ResFlags,lReg64.RegLo);
                          cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                          cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,0,lReg64.RegHi);
                          cg64.A_Op64_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,OS_S64,
                            lReg64,lReg64);
                          cg64.A_Load64_Reg_Loc(CurrentAsmData.CurrAsmList,lReg64,Left.Location);
                        end
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                        begin
                          lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Left.Location.Size);
                          cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,Left.Location.Size,Right.Location.ResFlags,lReg);
                          cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                          cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,Left.Location.Size,lReg,lReg);
                          hlcg.A_Load_Reg_Loc(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef,lReg,Left.Location);
                        end
                    end
                  else
                    begin
                      case Left.Location.Loc of
                        LOC_REGISTER,LOC_CREGISTER:
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                          if Left.Location.Size in [OS_S64,OS_64] then
                            begin
                              cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,OS_32,Right.Location.ResFlags,Left.Location.Register64.RegLo);
                              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                              cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,0,Left.Location.Register64.RegHi);
                            end
                          else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                            begin
                              cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,Left.Location.Size,Right.Location.ResFlags,Left.Location.Register);
                              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            end;
                        LOC_CREFERENCE,
                        LOC_REFERENCE:
                        { i8086 and i386 have hacks in their code generators so that they can
                          deal with 64 bit locations in this particular case }
{$if not defined(cpu64bitalu) and not defined(x86) and not defined(cpuhighleveltarget)}
                          if Left.Location.Size in [OS_S64,OS_64] then
                            begin
                              lReg64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                              lReg64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                              cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,OS_32,Right.Location.ResFlags,lReg64.RegLo);
                              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                              cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,0,lReg64.RegHi);
                              cg64.A_Load64_Reg_Ref(CurrentAsmData.CurrAsmList,lReg64,Left.Location.Reference);
                            end
                          else
{$endif not cpu64bitalu and not x86 and not cpuhighleveltarget}
                            begin
                              cg.G_Flags2Ref(CurrentAsmData.CurrAsmList,Left.Location.Size,Right.Location.ResFlags,Left.Location.Reference);
                              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            end;
                        LOC_CSUBSETREG,LOC_SUBSETREG,LOC_SUBSETREF:
                          begin
                            lReg:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,Left.Location.Size);
                            cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,Left.Location.Size,Right.Location.ResFlags,lReg);
                            cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            hlcg.A_Load_Reg_Loc(CurrentAsmData.CurrAsmList,Left.ResultDef,Left.ResultDef,lReg,Left.Location);
                          end;
                        else
                          InternalError(200203273);
                      end;
                    end;
                end;
{$endif cpuflags}
              LOC_VOID:
                ;
              else
                InternalError(2019050706);
            end;
         end;

        if lReleaseRight then
          Location_FreeTemp(CurrentAsmData.CurrAsmList,Right.Location);
      end;


{*****************************************************************************
                           SecondArrayConstruct
*****************************************************************************}

      const
        cVTInteger       = 0;
        cVTBoolean       = 1;
        cVTChar          = 2;
        cVTExtended      = 3;
        cVTString        = 4;
        cVTPointer       = 5;
        cVTPChar         = 6;
        cVTObject        = 7;
        cVTClass         = 8;
        cVTWideChar      = 9;
        cVTPWideChar     = 10;
        cVTAnsiString32  = 11;
        cVTCurrency      = 12;
        cVTVariant       = 13;
        cVTInterface     = 14;
        cVTWideString    = 15;
        cVTInt64         = 16;
        cVTQWord         = 17;
        cVTUnicodeString = 18;
        cVTAnsiString16  = 19;
        cVTAnsiString64  = 20;


    procedure TCGArrayConstructorNode.MakeArrayRef(var AReference: TReference; AElementDef: TDef);
      begin
        { do nothing by default }
      end;


    procedure TCGArrayConstructorNode.AdvanceArrayOffset(var AReference: TReference; AElementSize: ASizeInt);
      begin
        AReference.Alignment:=NewAlignment(AReference.Alignment,AElementSize);
        inc(AReference.Offset,AElementSize);
      end;


    procedure TCGArrayConstructorNode.Pass_Generate_Code;
      var
        lElementNode    : TArrayConstructorNode;
        lReference,
        lFieldReference  : TReference;
        lType    : TDef;
        lParaLoc : TCGParaLocation;
        lVarTypeField,
        lVarField : TFieldVarSym;
        lVarType : LongInt;
        lElementDef: TDef;
        lElementSize : LongInt;
        lTempReg  : TRegister;
        lIsAddress : Boolean;
        lFreeTemp,
        lDoVariant: Boolean;
      begin
        if Is_Packed_Array(ResultDef) then
          InternalError(200608042);
        lDoVariant:=
          (acnf_forcevaria in ArrayConstructorNodeFlags) or Is_Variant_Array(ResultDef);
        lElementDef:=TArrayDef(ResultDef).ElementDef;
        lElementSize:=lElementDef.Size;
        if lDoVariant then
          lVarTypeField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VTYPE'))
        else
          lVarTypeField:=nil;
        { alignment is filled in by tg.gethltemp below }
        Location_Reset_Ref(Location,LOC_CREFERENCE,OS_NO,0,[]);
        fillchar(lParaLoc,sizeof(lParaLoc),0);
        { Allocate always a temp, also if no elements are required, to
          be sure that location is valid (PFV) }

        TG.GetHLTemp(CurrentAsmData.CurrAsmList,ResultDef,(TArrayDef(ResultDef).HighRange+1)*lElementSize,tt_normal,Location.Reference);
        lReference:=Location.Reference;
        MakeArrayRef(lReference,lElementDef);
        { Process nodes in array constructor }
        lElementNode:=self;
        while Assigned(lElementNode) do
         begin
           if Assigned(lElementNode.Left) then
            begin
              lFreeTemp:=true;
              SecondPass(lElementNode.Left);
              if (lElementNode.Left.Location.Loc=LOC_JUMP)<>
                 (lElementNode.Left.expectloc=LOC_JUMP) then
                InternalError(2007103101);
              { Move flags and jump in register }
              if lElementNode.Left.Location.Loc in [LOC_FLAGS,LOC_JUMP] then
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,lElementNode.Left.Location,lElementNode.Left.ResultDef,lElementNode.Left.ResultDef,false);

              if lDoVariant then
               begin
                 { find the correct vtype value }
                 lVarType:=$ff;
                 lVarField:=nil;
                 lIsAddress:=false;
                 lType:=lElementNode.Left.ResultDef;
                 case lType.Typ of
                   enumdef,
                   orddef :
                     begin
                       if Is_64Bit(lType) then
                         begin
                            case TOrdDef(lType).OrdType of
                              scurrency:
                                begin
                                  lVarType:=cVTCurrency;
                                  lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VCURRENCY'));
                                end;
                              s64bit:
                                begin
                                  lVarType:=cVTInt64;
                                  lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VINT64'));
                                end;
                              u64bit:
                                begin
                                  lVarType:=cVTQWord;
                                  lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VQWORD'));
                                end;
                              else
                                ;
                            end;
                            lFreeTemp:=false;
                            lIsAddress:=true;
                         end
                       else if (lType.Typ=enumdef) or
                           Is_Integer(lType) then
                         begin
                           lVarType:=cVTInteger;
                           lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VINTEGER'));
                         end
                       else
                         if Is_Boolean(lType) then
                           begin
                             lVarType:=cVTBoolean;
                             lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VINTEGER'));
                           end
                         else
                           if (lType.Typ=orddef) then
                             begin
                               case TOrdDef(lType).OrdType of
                                 uchar:
                                   begin
                                     lVarType:=cVTChar;
                                     lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VINTEGER'));
                                   end;
                                 uwidechar:
                                   begin
                                     lVarType:=cVTWideChar;
                                     lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VINTEGER'));
                                   end;
                                 else
                                   ;
                               end;
                             end;
                     end;
                   floatdef :
                     begin
                       if Is_Currency(lType) then
                         begin
                           lVarType:=cVTCurrency;
                           lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VCURRENCY'));
                         end
                       else
                         begin
                           lVarType:=cVTExtended;
                           lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VEXTENDED'));
                         end;
                       lFreeTemp:=false;
                       lIsAddress:=true;
                     end;
                   procvardef,
                   pointerdef :
                     begin
                       if Is_PChar(lType) then
                         begin
                           lVarType:=cVTPChar;
                           lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VPCHAR'));
                         end
                       else if Is_PWideChar(lType) then
                         begin
                           lVarType:=cVTPWideChar;
                           lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VPWIDECHAR'));
                         end
                       else
                         begin
                           lVarType:=cVTPointer;
                           lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VPOINTER'));
                         end;
                     end;
                   variantdef :
                     begin
                        lVarType:=cVTVariant;
                        lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VVARIANT'));
                        lIsAddress:=true;
                        lFreeTemp:=false;
                     end;
                   classrefdef :
                     begin
                       lVarType:=cVTClass;
                       lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VCLASS'));
                     end;
                   objectdef :
                     if Is_Interface(lType) then
                       begin
                         lVarType:=cVTInterface;
                         lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VINTERFACE'));
                       end
                     { vtObject really means a class based on TObject }
                     else if Is_Class(lType) then
                       begin
                         lVarType:=cVTObject;
                         lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VOBJECT'));
                       end
                     else
                       InternalError(200505171);
                   stringdef :
                     begin
                       if Is_ShortString(lType) then
                        begin
                          lVarType:=cVTString;
                          lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VSTRING'));
                          lIsAddress:=true;
                          lFreeTemp:=false;
                        end
                       else
                        if Is_AnsiString(lType) then
                         begin
                           lVarType:=vtAnsiString;
                           lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VANSISTRING'));
                           lFreeTemp:=false;
                         end
                       else
                        if Is_WideString(lType) then
                         begin
                           lVarType:=cVTWideString;
                           lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VWIDESTRING'));
                           lFreeTemp:=false;
                         end
                       else
                        if Is_UnicodeString(lType) then
                         begin
                           lVarType:=cVTUnicodeString;
                           lVarField:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(lElementDef),'VUNICODESTRING'));
                           lFreeTemp:=false;
                         end;
                     end;
                   else
                     ;
                 end;
                 if lVarType=$ff then
                   InternalError(14357);
                 if not Assigned(lVarField) then
                   InternalError(2015102901);
                 { write changing field update href to the next element }
                 lFieldReference:=lReference;
                 hlcg.G_Set_Addr_NonBitPacked_Field_Ref(CurrentAsmData.CurrAsmList,TRecordDef(lElementDef),lVarField,lFieldReference);
                 if lIsAddress then
                   begin
                     hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,lElementNode.Left.Location,lType);
                     lTempReg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(lType));
                     hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,lElementNode.Left.ResultDef,CPointerDef.getreusable(lType),lElementNode.Left.Location.Reference,lTempReg);
                     hlcg.A_Load_Reg_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(lType),lVarField.vardef,lTempReg,lFieldReference);
                   end
                 else
                   hlcg.A_Load_Loc_Ref(CurrentAsmData.CurrAsmList,lElementNode.Left.ResultDef,lVarField.vardef,lElementNode.Left.Location,lFieldReference);
                 { update href to the vtype field and write it }
                 lFieldReference:=lReference;
                 hlcg.G_Set_Addr_NonBitPacked_Field_Ref(CurrentAsmData.CurrAsmList,TRecordDef(lElementDef),lVarTypeField,lFieldReference);
                 hlcg.A_Load_Const_Ref(CurrentAsmData.CurrAsmList,lVarTypeField.vardef,lVarType,lFieldReference);
                 { goto next array element }
                 AdvanceArrayOffset(lReference,lElementSize);
               end
              else
              { normal array constructor of the same type }
               begin
                 if Is_Managed_Type(ResultDef) then
                   lFreeTemp:=false;
                 case lElementNode.Left.Location.Loc of
                   LOC_MMREGISTER,
                   LOC_CMMREGISTER:
                     hlcg.A_LoadMM_Reg_Ref(CurrentAsmData.CurrAsmList,lElementNode.Left.ResultDef,lElementNode.Left.ResultDef,
                       lElementNode.Left.Location.Register,lReference,MMS_MoveScalar);
                   LOC_FPUREGISTER,
                   LOC_CFPUREGISTER :
                     hlcg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,lElementNode.Left.ResultDef,lElementNode.Left.ResultDef,lElementNode.Left.Location.Register,lReference);
                   LOC_REFERENCE,
                   LOC_CREFERENCE :
                     begin
                       if Is_ShortString(lElementNode.Left.ResultDef) then
                         hlcg.G_CopyShortString(CurrentAsmData.CurrAsmList,lElementNode.Left.Location.Reference,lReference,
                             TStringDef(lElementNode.Left.ResultDef))
                       else
                         hlcg.G_ConcatCopy(CurrentAsmData.CurrAsmList,lElementDef,lElementNode.Left.Location.Reference,lReference);
                     end;
                   else
                     begin
{$ifndef cpuhighleveltarget}
{$ifdef cpu64bitalu}
                       if lElementNode.Left.Location.Size in [OS_128,OS_S128] then
                         cg128.A_Load128_Loc_Ref(CurrentAsmData.CurrAsmList,lElementNode.Left.Location,lReference)
                       else
{$else cpu64bitalu}
                       if lElementNode.Left.Location.Size in [OS_64,OS_S64] then
                         cg64.A_Load64_Loc_Ref(CurrentAsmData.CurrAsmList,lElementNode.Left.Location,lReference)
                       else
{$endif cpu64bitalu}
{$endif not cpuhighleveltarget}
                         hlcg.A_Load_Loc_Ref(CurrentAsmData.CurrAsmList,lElementDef,lElementDef,lElementNode.Left.Location,lReference);
                     end;
                 end;
                 AdvanceArrayOffset(lReference,lElementSize);
               end;
              if lFreeTemp then
                Location_FreeTemp(CurrentAsmData.CurrAsmList,lElementNode.Left.Location);
            end;
           { load next entry }
           lElementNode:=TArrayConstructorNode(lElementNode.Right);
         end;
      end;


{*****************************************************************************
                           SecondRTTI
*****************************************************************************}

    procedure TCGRTTINode.Pass_Generate_Code;
      var
        lIndirect : Boolean;
      begin
        lIndirect := (tf_supports_packages in TargetInfo.Flags) and
                      (TargetInfo.system in systems_indirect_var_imports) and
                      (RTTIDef.owner.ModuleID<>CurrentModule.ModuleID);

        Location_Reset_Ref(Location,LOC_CREFERENCE,OS_NO,sizeof(PInt),[]);
        case RTTIDataType of
          rdt_normal:
            Location.Reference.Symbol:=RTTIWriter.Get_RTTI_Label(RTTIDef,RTTIType,lIndirect);
          rdt_ord2str:
            Location.Reference.Symbol:=RTTIWriter.Get_RTTI_Label_Ord2Str(RTTIDef,RTTIType,lIndirect);
          rdt_str2ord:
            Location.Reference.Symbol:=RTTIWriter.Get_RTTI_Label_Str2Ord(RTTIDef,RTTIType,lIndirect);
        end;
      end;



begin
   CLoadNode:=TCGLoadNode;
   CAssignmentNode:=TCGAssignmentNode;
   CArrayConstructorNode:=TCGArrayConstructorNode;
   CRTTINode:=TCGRTTINode;
end.
