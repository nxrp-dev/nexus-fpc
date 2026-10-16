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
          procedure generate_nested_access(vs: TSym);virtual;
          procedure generate_absaddr_access(vs: TAbsoluteVarSym); virtual;
          procedure generate_threadvar_access(gvs: TStaticVarSym); virtual;
          function use_indirect_symbol(gvs: TStaticVarSym): boolean;
         public
          procedure pass_generate_code;override;
          procedure changereflocation(const ref: TReference);
       end;

       TCGAssignmentNode = class(TAssignmentNode)
        protected
          function maybechangetemp(list: TAsmList; var n: TNode; const newref: TReference): boolean;virtual;
        public
          procedure pass_generate_code;override;
       end;

       TCGArrayConstructorNode = class(TArrayConstructorNode)
         protected
          procedure makearrayref(var ref: TReference; eledef: TDef);virtual;
          procedure advancearrayoffset(var ref: TReference; EleSize: asizeint);virtual;
         public
          procedure pass_generate_code;override;
       end;

       TCGRTTINode = class(TRTTINode)
          procedure pass_generate_code;override;
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
        old, new: PReference;
        ressym: TSym;
      end;

    function doreplaceref(var n: TNode; para: pointer): TForEachNodeResult;
      var
        rr: PReplaceRefRec absolute para;
      begin
        result := fen_false;
        case n.nodetype of
          loadn:
            begin
                 { regular variable }
              if (TAbstractVarSym(TLoadNode(n).symtableentry).VarOptions * [vo_is_dll_var, vo_is_thread_var] = []) and
                 not Assigned(TLoadNode(n).left) and
                 { not function result, or no exit in function }
                 (((TLoadNode(n).symtableentry <> rr^.ressym) and
                   not(vo_is_funcret in TAbstractVarSym(TLoadNode(n).symtableentry).VarOptions)) or
                  not(fc_exit in flowcontrol)) and
                 { stored in memory... }
                 (TAbstractNormalVarSym(TLoadNode(n).symtableentry).LocAlloc.Loc in [LOC_REFERENCE]) and
                 { ... at the place we are looking for }
                 References_Equal(TAbstractNormalVarSym(TLoadNode(n).symtableentry).LocAlloc.Reference,rr^.old^) and
                 { its address cannot have escaped the current routine }
                 not(TAbstractVarSym(TLoadNode(n).symtableentry).AddrTaken) and
                 { it is not accessed in nested procedures }
                 not(TAbstractVarSym(TLoadNode(n).symtableentry).DifferentScope) then
                begin
                  { relocate variable }
                  TCGLoadNode(n).changereflocation(rr^.new^);
                  result := fen_norecurse_true;
                end;
            end;
          temprefn:
            begin
              if (ti_valid in TTempRefNode(n).tempflags) and
                 { memory temp... }
                 (TTempRefNode(n).tempinfo^.Location.Loc in [LOC_REFERENCE]) and
                 { ... at the place we are looking for }
                 References_Equal(TTempRefNode(n).tempinfo^.Location.Reference,rr^.old^) and
                 { its address cannot have escaped the current routine }
                 not(ti_addr_taken in TTempRefNode(n).tempflags) then
                begin
                  { relocate the temp }
                  TCGTempRefNode(n).changelocation(rr^.new^);
                  result := fen_norecurse_true;
                end;
            end;
          { Subscriptn must be rejected, otherwise we may replace an
            an entire record with a temp for its first field, mantis #13948)
            Exception: the field's size is the same as the entire record

            The same goes for array indexing
          }
          subscriptn,
          vecn:
            if not(TUnaryNode(n).left.resultdef.typ in [recorddef,objectdef,arraydef,stringdef]) or
               { make sure we don't try to call resultdef.size for types that
                 don't have a compile-time size such as open arrays }
               Is_Special_Array(TUnaryNode(n).left.resultdef) or
               (TUnaryNode(n).left.resultdef.Size<>TUnaryNode(n).resultdef.Size) then
              result := fen_norecurse_false;

          { optimize the searching a bit }
          derefn,addrn,
          calln,inlinen,casen,
          addn,subn,muln,
          andn,orn,xorn,
          ltn,lten,gtn,gten,EqualN,unequaln,
          slashn,divn,shrn,shln,notn,
          inn,
          asn,isn:
            result := fen_norecurse_false;
          else
            ;
        end;
      end;


    function TCGAssignmentNode.maybechangetemp(list: TAsmList; var n: TNode; const newref: TReference): boolean;
      var
        rr: TReplaceRefRec;
      begin
        result := false;

        { only do for -O2 or higher (breaks debugging since }
        { variables move to different memory locations)     }
        if not(cs_opt_level2 in CurrentSettings.OptimizerSwitches) or
           { must be a copy to a memory location ... }
           (n.Location.Loc <> LOC_REFERENCE) or
           { not inside a control flow statement and no goto's in sight }
           ([fc_inflowcontrol,fc_gotolabel] * flowcontrol <> []) or
           { not for refcounted types, because those locations are   }
           { still used later on in initialisation/finalisation code }
           Is_Managed_Type(n.resultdef) or
           { source and destination are temps (= not global variables) }
           { and both point to the start of a temp, and the source is a }
           { non-persistent temp (otherwise we need some kind of copy-  }
           { on-write support in case later on both are still used)     }
           not tg.isstartoftemp(newref) or
           not tg.isstartoftemp(n.Location.Reference) or
           (tg.gettypeoftemp(newref) <> tt_normal) or
           not (tg.gettypeoftemp(n.Location.Reference) in [tt_normal,tt_persistent]) or
           { and both have the same size }
           (tg.sizeoftemp(CurrentAsmData.CurrAsmList,newref) <> tg.sizeoftemp(CurrentAsmData.CurrAsmList,n.Location.Reference)) then
          exit;

        { find the source of the old reference (loadnode or tempnode) }
        { and replace it with the new reference                       }
        rr.old := @n.Location.Reference;
        rr.new := @newref;
        rr.ressym := nil;

        if Assigned(CurrentProcInfo.procdef.FuncRetSym) and
           (TAbstractVarSym(CurrentProcInfo.procdef.FuncRetSym).refs <> 0) then
          if (CurrentProcInfo.procdef.ProcTypeOption=potype_constructor) then
            rr.ressym:=TSym(CurrentProcInfo.procdef.ParaST.Find('self'))
         else
            rr.ressym:=CurrentProcInfo.procdef.FuncRetSym;

        { if source not found, don't do anything }
        if not foreachnodestatic(n,@doreplaceref,@rr) then
          exit;

        n.Location.Reference := newref;
        result:=true;
      end;

{*****************************************************************************
                             SecondLoad
*****************************************************************************}

    procedure TCGLoadNode.changereflocation(const ref: TReference);
      var
        oldtemptype: TTempType;
      begin
        if (location.Loc<>LOC_REFERENCE) then
          InternalError(2007020812);
        if not tg.istemp(location.Reference) then
          InternalError(2007020813);
        oldtemptype:=tg.gettypeoftemp(location.Reference);
        if (oldtemptype = tt_persistent) then
          tg.ChangeTempType(CurrentAsmData.CurrAsmList,location.Reference,tt_normal);
        tg.ungettemp(CurrentAsmData.CurrAsmList,location.Reference);
        location.Reference:=ref;
        tg.ChangeTempType(CurrentAsmData.CurrAsmList,location.Reference,oldtemptype);
        TAbstractNormalVarSym(symtableentry).LocAlloc:=location;
        hlcg.RecordNewSymLoc(CurrentAsmData.CurrAsmList,symtableentry,TAbstractNormalVarSym(symtableentry).vardef,location.Reference,false);
      end;


    procedure TCGLoadNode.generate_nested_access(vs: TSym);
      var
        { parameter declared as tsym to reduce interface unit dependencies }
        lvs: TAbstractNormalVarSym absolute vs;
      begin
        SecondPass(left);
        if not(left.Location.Loc in [LOC_REGISTER,LOC_CREGISTER]) then
          InternalError(200309286);
        if lvs.LocAlloc.Loc<>LOC_REFERENCE then
          InternalError(200409241);
        hlcg.Reference_Reset_Base(location.Reference,left.resultdef,left.Location.Register,lvs.LocAlloc.Reference.Offset,CTempPosInvalid,lvs.LocAlloc.Reference.Alignment,lvs.LocAlloc.Reference.Volatility);
      end;


    procedure TCGLoadNode.generate_absaddr_access(vs: TAbsoluteVarSym);
      begin
        location.Reference.Offset:=asizeint(vs.AddrOffset);
        location.Reference.Volatility:=[vol_read,vol_write];
      end;


    procedure TCGLoadNode.generate_threadvar_access(gvs: TStaticVarSym);
      var
        pd: TProcDef;
        para, respara: TCGPara;
        ref: TReference;
        reg: TRegister;
        tmp: TLocation;
      begin
        if tf_section_threadvars in TargetInfo.flags then
          begin
            if gvs.LocAlloc.Loc=LOC_INVALID then
              Reference_Reset_Symbol(location.Reference,CurrentAsmData.RefAsmSymbol(gvs.MangledName,AT_TLS,use_indirect_symbol(gvs)),0,location.Reference.Alignment,[])
            else
              location:=gvs.LocAlloc;
            exit;
          end;
        { Every variable names an image-owned descriptor. Startup and late
          images use the same resolver; there is no inline main-thread value. }
        pd:=Search_System_Proc('fpc_threadvar_addr');
        para.init;
        ParaManager.GetCGTempParaLoc(CurrentAsmData.CurrAsmList,pd,1,para);
        if vo_is_weak_external in gvs.VarOptions then
          Reference_Reset_Symbol(ref,CurrentAsmData.WeakRefAsmSymbol(gvs.MangledName,AT_DATA),0,sizeof(PInt),[])
        else
          Reference_Reset_Symbol(ref,CurrentAsmData.RefAsmSymbol(gvs.MangledName,AT_DATA,use_indirect_symbol(gvs)),0,sizeof(PInt),[]);
        hlcg.A_LoadAddr_Ref_CGPara(CurrentAsmData.CurrAsmList,VoidPointerType,ref,para);
        ParaManager.FreeCGPara(CurrentAsmData.CurrAsmList,para);
        respara:=hlcg.G_Call_System_Proc(CurrentAsmData.CurrAsmList,pd,[@para],VoidPointerType);
        para.done;
        reg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,VoidPointerType);
        Location_Reset(tmp,LOC_REGISTER,OS_ADDR);
        tmp.Register:=reg;
        hlcg.Gen_Load_CGPara_Loc(CurrentAsmData.CurrAsmList,VoidPointerType,respara,tmp,true);
        respara.ResetIfTemp;
        hlcg.Reference_Reset_Base(location.Reference,VoidPointerType,reg,0,CTempPosInvalid,resultdef.Alignment,[]);
      end;


    function TCGLoadNode.use_indirect_symbol(gvs:TStaticVarSym):boolean;
      begin
        { we are using a direct reference if any of the following is true:
          - the target does not support packages
          - the target does not use indirect references
          - the variable is declared as (weak) external
          - the variable is located inside the same unit }
        result:=(tf_supports_packages in TargetInfo.flags) and
                (TargetInfo.system in systems_indirect_var_imports) and
                (gvs.VarOptions*[vo_is_external,vo_is_weak_external]=[]) and
                (gvs.owner.SymTableType in [GlobalSymTable,staticsymtable]) and
                not Sym_Is_Owned_By(gvs,CurrentModule.GlobalSymTable) and
                (
                  (CurrentModule.GlobalSymTable=CurrentModule.LocalSymTable) or
                  not Sym_Is_Owned_By(gvs,CurrentModule.LocalSymTable)
                );
      end;

    procedure TCGLoadNode.pass_generate_code;
      var
        hregister : TRegister;
        vs   : TAbstractNormalVarSym;
        gvs  : TStaticVarSym;
        vmtdef : TPointerDef;
        vmtentry: TFieldVarSym;
        pd   : TProcDef;
        href : TReference;
        newsize : TCgSize;
        vd : TDef;
        alignment: LongInt;
        indirect : boolean;
        name : TSymStr;
      begin
        { we don't know the size of all arrays }
        newsize:=Def_CGSize(resultdef);
        { alignment is overridden per case below }
        Location_Reset_Ref(location,LOC_REFERENCE,newsize,resultdef.Alignment,[]);
        case symtableentry.typ of
           absolutevarsym :
              begin
                 { this is only for toasm and toaddr }
                 case TAbsoluteVarSym(symtableentry).AbsTyp of
                   toaddr :
                     generate_absaddr_access(TAbsoluteVarSym(symtableentry));
                   toasm :
                     location.Reference.Symbol:=CurrentAsmData.RefAsmSymbol(TAbsoluteVarSym(symtableentry).MangledName,AT_DATA);
                   else
                     InternalError(200310283);
                 end;
              end;
           constsym:
             begin
                if TConstSym(symtableentry).ConstTyp in [constresourcestring,constwresourcestring] then
                  begin
                     Location_Reset_Ref(location,LOC_CREFERENCE,Def_CGSize(CAnsiStringType),CAnsiStringType.Size,[]);
                     indirect:=(tf_supports_packages in TargetInfo.flags) and
                                 (TargetInfo.system in systems_indirect_var_imports) and
                                 (symtableentry.owner.ModuleID<>CurrentModule.ModuleID);
                     name:=Make_MangledName('RESSTR',symtableentry.owner,symtableentry.name);
                     location.Reference.Symbol:=CurrentAsmData.RefAsmSymbol(name,AT_DATA,indirect);
                     if symtableentry.owner.ModuleID<>CurrentModule.ModuleID then
                       CurrentModule.AddImportedSym(symtableentry);
                     vd:=Search_System_Type('TRESOURCESTRINGRECORD').typedef;
                     hlcg.G_Set_Addr_NonBitPacked_Field_Ref(
                       CurrentAsmData.CurrAsmList,
                       TRecordDef(vd),
                       TFieldVarSym(Search_Struct_Member(TRecordDef(vd),'CURRENTVALUE')),
                       location.Reference);
                  end
                else
                  InternalError(22798);
             end;
           staticvarsym :
             begin
               gvs:=TStaticVarSym(symtableentry);

               if (vo_is_dll_var in gvs.VarOptions) then
               { DLL variable }
                 begin
                   hregister:=cg.GetAddressRegister(CurrentAsmData.CurrAsmList);
                   if not(vo_is_weak_external in gvs.VarOptions) then
                     location.Reference.Symbol:=CurrentAsmData.RefAsmSymbol(TStaticVarSym(symtableentry).MangledName,AT_DATA)
                   else
                     location.Reference.Symbol:=CurrentAsmData.WeakRefAsmSymbol(TStaticVarSym(symtableentry).MangledName,AT_DATA);
                   cg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,location.Reference,hregister);
                   Reference_Reset_Base(location.Reference,hregister,0,CTempPosInvalid,location.Reference.Alignment,[]);
                 end
               { Thread variable }
               else if (vo_is_thread_var in gvs.VarOptions) then
                 generate_threadvar_access(gvs)
               { Normal (or external) variable }
               else
                 begin
                   if gvs.LocAlloc.Loc=LOC_INVALID then
                     begin
                       { static data is currently always volatile }
                       if not(vo_is_weak_external in gvs.VarOptions) then
                         Reference_Reset_Symbol(location.Reference,CurrentAsmData.RefAsmSymbol(gvs.MangledName,AT_DATA,use_indirect_symbol(gvs)),0,location.Reference.Alignment,[])
                       else
                         Reference_Reset_Symbol(location.Reference,CurrentAsmData.WeakRefAsmSymbol(gvs.MangledName,AT_DATA),0,location.Reference.Alignment,[])
                     end
                   else
                      location:=gvs.LocAlloc;
                  end;

                { make const a LOC_CREFERENCE }
                if (gvs.VarSpez=vs_const) and
                   (location.Loc=LOC_REFERENCE) then
                  location.Loc:=LOC_CREFERENCE;
              end;
            paravarsym,
            localvarsym :
              begin
                vs:=TAbstractNormalVarSym(symtableentry);
                { Nested variable }
                if Assigned(left) then
                  generate_nested_access(vs)
                else
                  location:=vs.LocAlloc;

                { handle call by reference variables when they are not
                  already copied to local copies. Also ignore the reference
                  when we need to load the self pointer for objects }
                if is_addr_param_load then
                  begin
                    if (location.Loc in [LOC_CREGISTER,LOC_REGISTER]) then
                      hregister:=location.Register
                    else
                      begin
                        vd:=CPointerDef.getreusable(resultdef);
                        hregister:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,vd);
                        { we need to load only an address }
                        location.Size:=Int_CGSize(vd.Size);
                        hlcg.A_Load_Loc_Reg(CurrentAsmData.CurrAsmList,vd,vd,location,hregister);
                      end;
                    { assume packed records may always be unaligned }
                    if not(resultdef.typ in [recorddef,objectdef]) or
                       (TAbstractRecordSymTable(TAbstractRecordDef(resultdef).SymTable).UseFieldAlignment<>1) then
                      begin
                        alignment:=min(min(min(resultdef.Alignment,CurrentSettings.Alignment.LocalAlignMax),CurrentSettings.Alignment.ConstAlignMax),CurrentSettings.Alignment.VarAlignMax);
                        Location_Reset_Ref(location,LOC_REFERENCE,newsize,alignment,[]);
                      end
                    else
                      Location_Reset_Ref(location,LOC_REFERENCE,newsize,1,[]);
                    hlcg.Reference_Reset_Base(location.Reference,VoidPointerType,hregister,0,CTempPosInvalid,location.Reference.Alignment,[]);
                  end;

                { make const a LOC_CREFERENCE }
                if (vs.VarSpez=vs_const) and
                   (location.Loc=LOC_REFERENCE) then
                  location.Loc:=LOC_CREFERENCE;
             end;
           ProcSym:
              begin
                 if not Assigned(procdef) then
                   InternalError(200312011);
                 if Assigned(left) and
                   (resultdef.typ in [symconst.procdef,procvardef]) and
                    not TAbstractProcDef(resultdef).Is_AddressOnly then
                   begin
                     Location_Reset(location,LOC_CREGISTER,Int_CGSize(VoidPointerType.Size*2));

                     SecondPass(left);

                     { load class instance/classrefdef address }
                     if left.Location.Loc=LOC_CONSTANT then
                       hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,left.Location,left.resultdef,left.resultdef,false);
                     { vd will contain the type of the self pointer (self in
                       case of a class/classref, address of self in case of
                       an object, frame pointer or pointer to parentfpstruct
                       in case of nested procsym load  }
                     vd:=nil;
                     case left.Location.Loc of
                        LOC_CREGISTER,
                        LOC_REGISTER:
                          begin
                             { this is not possible for objects }
                             if Is_Object(left.resultdef) then
                               InternalError(200304234);

                             location.RegisterHi:=left.Location.Register;

                             vd:=left.resultdef;
                          end;
                        LOC_CREFERENCE,
                        LOC_REFERENCE:
                          begin
                             if Is_Implicit_Pointer_Object_Type(left.resultdef) or
                                (left.resultdef.typ=classrefdef) or
                                Is_Nested_PD(procdef) then
                               begin
                                 vd:=left.resultdef;

                                 location.RegisterHi:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,left.resultdef);
                                 hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,left.Location.Reference,location.RegisterHi)

                               end
                             else
                               begin
                                 vd:=CPointerDef.getreusable(left.resultdef);

                                 location.RegisterHi:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,vd);
                                 hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,left.resultdef,vd,left.Location.Reference,location.RegisterHi);

                               end;
                             location_freetemp(CurrentAsmData.CurrAsmList,left.Location);
                          end;
                        else
                          InternalError(200610311);
                     end;

                     { virtual method ? }
                     if (po_virtualmethod in procdef.ProcOptions) and
                        not(loadnf_inherited in loadnodeflags) and
                        not Is_ObjectPascal_Helper(procdef.struct) then
                       begin
                         if (not Assigned(CurrentProcInfo) or
                             wpoinfomanager.symbol_live(CurrentProcInfo.procdef.MangledName)) then
                           TObjectDef(procdef.struct).Register_VMT_Call(procdef.ExtNumber);
            {$ifdef vtentry}
                         if not Is_Interface(procdef.struct) then
                           begin
                             inc(CurrentAsmData.NextVTEntryNr);
                             CurrentAsmData.CurrAsmList.Concat(TAISymbol.CreateName('VTREF'+ToStr(CurrentAsmData.NextVTEntryNr)+'_'+procdef._class.VMT_MangledName+'$$'+ToStr(vmtoffset div sizeof(PInt)),AT_FUNCTION,0,voidpointerdef));
                           end;
            {$endif vtentry}
                         if (left.resultdef.typ=objectdef) and
                            Assigned(TObjectDef(left.resultdef).VMTField) then
                           begin
                             { vmt pointer is a pointer to the vmt record }
                             hlcg.Reference_Reset_Base(href,vd,location.RegisterHi,0,CTempPosInvalid,vd.Alignment,[]);
                             vmtdef:=CPointerDef.getreusable(TObjectDef(left.resultdef).VMT_Def);
                             hlcg.G_Set_Addr_NonBitPacked_Field_Ref(CurrentAsmData.CurrAsmList,TObjectDef(left.resultdef),TFieldVarSym(TObjectDef(left.resultdef).VMTField),href);
                             hregister:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,vmtdef);
                             hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,TFieldVarSym(TObjectDef(left.resultdef).VMTField).vardef,vmtdef,href,hregister);
                           end
                         else if left.resultdef.typ=classrefdef then
                           begin
                             vmtdef:=CPointerDef.getreusable(TObjectDef(TClassRefDef(left.resultdef).PointedDef).VMT_Def);
                             { classrefdef is a pointer to the vmt already }

                             { targets with 32 bit method pointers got already a register assigned }
                             hregister:=location.RegisterHi;

                             hlcg.G_PtrTypeCast_Reg(CurrentAsmData.CurrAsmList,left.resultdef,vmtdef,hregister);
                           end
                         else if Is_Any_Interface_Kind(left.resultdef) then
                           begin
                             { an interface is a pointer to a pointer to a vmt }
                             hlcg.Reference_Reset_Base(href,vd,location.RegisterHi,0,CTempPosInvalid,vd.Alignment,[]);
                             vmtdef:=CPointerDef.getreusable(TObjectDef(left.resultdef).VMT_Def);
                             hregister:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,vmtdef);
                             hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,vmtdef,vmtdef,href,hregister);
                           end
                         else
                           InternalError(2015112501);
                         { load method address }
                         vmtentry:=TAbstractRecordSymTable(TRecordDef(vmtdef.PointedDef).SymTable).FindFieldByOffset(
                           TObjectDef(procdef.struct).VMTMethodOffset(procdef.ExtNumber));
                         hlcg.Reference_Reset_Base(href,vmtdef,hregister,0,CTempPosInvalid,vmtdef.Alignment,[]);
                         { targets with 32 bit method pointers got already a register assigned }

                         location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,vmtentry.vardef);

                         hlcg.G_Set_Addr_NonBitPacked_Field_Ref(CurrentAsmData.CurrAsmList,TAbstractRecordDef(vmtdef.PointedDef),vmtentry,href);
                         hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,vmtentry.vardef,vmtentry.vardef,href,location.Register);
                       end
                     else
                       begin
                         { load address of the function }
                         Reference_Reset_Symbol(href,CurrentAsmData.RefAsmSymbol(procdef.MangledName,AT_FUNCTION),0,procdef.Address_Type.Alignment,[]);
                         { targets with 32 bit method pointers got already a register assigned }

                         location.Register:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,CProcVarDef.GetReusableProcAddr(procdef,pc_address_only));

                         hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,procdef,CProcVarDef.GetReusableProcAddr(procdef,pc_address_only),href,location.Register);
                       end;

                     { to get methodpointers stored correctly, code and self register must be swapped on
                       big endian targets }
                     if TargetInfo.endian=endian_big then
                       begin
                         { cpus with 16 bit address registers don't use registerhi here }

                         hregister:=location.Register;
                         location.Register:=location.RegisterHi;
                         location.RegisterHi:=hregister;
                       end;
                   end
                 else
                   begin
                      pd:=TProcDef(TProcSym(symtableentry).ProcdefList[0]);
                      { def_cgsize does not work for tprocdef, so we use pd.address_type }
                      location.Size:=Def_CGSize(pd.Address_Type);
                      if not(po_weakexternal in pd.ProcOptions) then
                        location.Reference.Symbol:=CurrentAsmData.RefAsmSymbol(procdef.MangledName,AT_FUNCTION)
                      else
                        location.Reference.Symbol:=CurrentAsmData.WeakRefAsmSymbol(procdef.MangledName,AT_FUNCTION);
                   end;
              end;
           labelsym :
             if Assigned(TLabelSym(symtableentry).AsmBlockLabel) then
               location.Reference.Symbol:=TLabelSym(symtableentry).AsmBlockLabel
             else
               location.Reference.Symbol:=TCGLabelNode((TLabelSym(symtableentry).code)).getasmlabel;
           else InternalError(200510032);
        end;
      end;


{*****************************************************************************
                             SecondAssignment
*****************************************************************************}

    procedure TCGAssignmentNode.pass_generate_code;
      var
         shuffle : PMMShuffle;
         hlabel : TAsmLabel;
         href : TReference;
         releaseright : boolean;
         alignmentrequirement,
         len : TCGInt;
         r : TRegister;
         {$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
         r64 : TRegister64;
         {$endif}
         oldflowcontrol : TFlowControl;
      begin
        { previously, managed types were handled in firstpass
          newer FPCs however can identify situations when
          assignments of managed types require no special code and the
          value could be just copied so this could should be able also to handle
          managed types without any special "managing code"}

        Location_Reset(location,LOC_VOID,OS_NO);

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
        if not(right.expectloc in [LOC_FLAGS,LOC_JUMP]) and
            (node_complexity(right)>node_complexity(left)) and not(has_conditional_nodes(right)) then
         begin
           SecondPass(right);
           if CodeGenError then
             exit;

           SecondPass(left);
           if CodeGenError then
             exit;
         end
        else
         begin
           { calculate left sides }
           SecondPass(left);
           if CodeGenError then
             exit;

           { tell the SSA/SSL code that the left side was handled first so
             ni SSL is done
           }
           oldflowcontrol:=flowcontrol;
           include(flowcontrol,fc_lefthandled);

           SecondPass(right);
           flowcontrol:=oldflowcontrol;

           if CodeGenError then
             exit;
         end;

        releaseright:=
          (left.nodetype<>temprefn) or
          not(ti_const in TTempRefNode(left).tempflags);

        { shortstring assignments are handled separately }
        if Is_ShortString(left.resultdef) then
          begin
            {
              we can get here only in the following situations
              for the right node:
               - empty constant string
               - char
            }

            { The addn is replaced by a blockn or calln that already returns
              a shortstring }
            if Is_ShortString(right.resultdef) and
               (right.nodetype in [blockn,calln]) then
              begin
                { verify that we indeed have nothing to do }
                if not(anf_assign_done_in_right in assignmentnodeflags) then
                  InternalError(2015042201);
              end
            { empty constant string }
            else if (right.nodetype=stringconstn) and
               (TStringConstNode(right).len=0) then
              begin
                hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(left.resultdef),TPointerDef(CharPointerType),left.Location.Reference);
                hlcg.A_Load_Const_Ref(CurrentAsmData.CurrAsmList,CAnsiCharType,0,left.Location.Reference);
              end
            { char loading }
            else if Is_Char(right.resultdef) then
              begin
                if right.nodetype=ordconstn then
                  begin
                    hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(left.resultdef),CPointerDef.getreusable(U16IntType),left.Location.Reference);
                    if (TargetInfo.endian = endian_little) then
                      hlcg.A_Load_Const_Ref(CurrentAsmData.CurrAsmList,U16IntType,(TOrdConstNode(right).Value.svalue shl 8) or 1,
                          SetAlignment(left.Location.Reference,1))
                    else
                      hlcg.A_Load_Const_Ref(CurrentAsmData.CurrAsmList,U16IntType,TOrdConstNode(right).Value.svalue or (1 shl 8),
                          SetAlignment(left.Location.Reference,1));
                  end
                else
                  begin
                    href:=left.Location.Reference;
                    hlcg.G_PtrTypeCast_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(left.resultdef),TPointerDef(CharPointerType),href);
                    hlcg.A_Load_Const_Ref(CurrentAsmData.CurrAsmList,CAnsiCharType,1,href);
                    inc(href.Offset,1);
                    href.Alignment:=1;
                    case right.Location.Loc of
                      LOC_REGISTER,
                      LOC_CREGISTER :
                        begin
{$ifndef cpuhighleveltarget}
                          r:=cg.MakeRegSize(CurrentAsmData.CurrAsmList,right.Location.Register,OS_8);
{$else not cpuhighleveltarget}
                          r:=hlcg.GetIntRegister(CurrentAsmData.CurrAsmList,U8IntType);
                          hlcg.A_Load_Reg_Reg(CurrentAsmData.CurrAsmList,CAnsiCharType,U8IntType,right.Location.Register,r);
{$endif cpuhighleveltarget}
                          hlcg.A_Load_Reg_Ref(CurrentAsmData.CurrAsmList,U8IntType,U8IntType,r,href);
                        end;
                      LOC_REFERENCE,
                      LOC_CREFERENCE :
                        hlcg.A_Load_Ref_Ref(CurrentAsmData.CurrAsmList,CAnsiCharType,CAnsiCharType,right.Location.Reference,href);
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
        else if (right.Location.Loc = LOC_REFERENCE) and
           maybechangetemp(CurrentAsmData.CurrAsmList,left,right.Location.Reference) then
          begin
            { if it worked, we're done }
          end
        else
          begin
            { SSA support }
            hlcg.Maybe_Change_Load_Node_Reg(CurrentAsmData.CurrAsmList,left,false);
            hlcg.Maybe_Change_Load_Node_Reg(CurrentAsmData.CurrAsmList,right,true);
            case right.Location.Loc of
              LOC_CONSTANT :
                begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                  if (left.Location.Size in [OS_64,OS_S64]) or (right.Location.Size in [OS_64,OS_S64]) then
                    cg64.A_Load64_Const_Loc(CurrentAsmData.CurrAsmList,right.Location.Value64,left.Location)
                  else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                    hlcg.A_Load_Const_Loc(CurrentAsmData.CurrAsmList,left.resultdef,right.Location.Value,left.Location);
                end;
              LOC_REFERENCE,
              LOC_CREFERENCE :
                begin
                  case left.Location.Loc of
                    LOC_REGISTER,
                    LOC_CREGISTER :
                      begin
{$ifndef cpuhighleveltarget}
{$ifdef cpu64bitalu}
                        if left.Location.Size in [OS_128,OS_S128] then
                          cg128.A_Load128_Ref_Reg(CurrentAsmData.CurrAsmList,right.Location.Reference,left.Location.Register128)
                        else
{$else cpu64bitalu}
                        if left.Location.Size in [OS_64,OS_S64] then
                          cg64.A_Load64_Ref_Reg(CurrentAsmData.CurrAsmList,right.Location.Reference,left.Location.Register64)
                        else
{$endif cpu64bitalu}
{$endif not cpuhighleveltarget}
                          hlcg.A_Load_Ref_Reg(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.Location.Reference,left.Location.Register);
                      end;
                    LOC_FPUREGISTER,
                    LOC_CFPUREGISTER :
                      begin
                        hlcg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,
                            right.resultdef,left.resultdef,
                            right.Location.Reference,
                            left.Location.Register);
                      end;
                    LOC_REFERENCE,
                    LOC_CREFERENCE :
                      begin
                        if (left.resultdef.typ=floatdef) and
                           (right.resultdef.typ=floatdef) and
                           ((left.Location.Size<>right.Location.Size)
                           { on newer (1993+ :)) x86 cpus, use the fpu to copy extended values }
{$ifdef x86}
                            or ({$ifndef x86_64}(CurrentSettings.CPUType>=cpu_Pentium) and{$endif x86_64}
                            (Is_Extended(right.resultdef) {$ifdef i386} or Is_Double(right.resultdef){$endif i386} ))
{$endif x86}
                           )then
                          begin
                            { assume that all float types can be handed by the
                              fpu if one can be handled by the fpu }
                            if not Use_VectorFPU(left.resultdef) or
                               not Use_VectorFPU(right.resultdef) then
                              hlcg.A_LoadFPU_Ref_Ref(CurrentAsmData.CurrAsmList,
                                right.resultdef,left.resultdef,
                                right.Location.Reference,left.Location.Reference)
                            else
                              hlcg.A_LoadMM_Ref_Ref(CurrentAsmData.CurrAsmList,
                                right.resultdef,left.resultdef,
                                right.Location.Reference,left.Location.Reference,MMS_MoveScalar)
                          end
                        else
                          begin
{ TODO: HACK: unaligned test, maybe remove all unaligned locations (array of char) from the compiler}
                            { Use unaligned copy when the offset is not aligned }
                            len:=left.resultdef.Size;

                            if len=0 then
                              len:=sizeof(PInt);

                            { data smaller than an aint has less alignment requirements }
                            { max(1,...) avoids div by zero in case of an empty record  }
                            alignmentrequirement:=min(max(1,len),sizeof(aint));

                            if (right.Location.Reference.Offset mod alignmentrequirement<>0) or
                              (left.Location.Reference.Offset mod alignmentrequirement<>0) or
                              (right.resultdef.Alignment<alignmentrequirement) or
                              ((right.Location.Reference.Alignment<>0) and
                               (right.Location.Reference.Alignment<alignmentrequirement)) or
                              ((left.Location.Reference.Alignment<>0) and
                               (left.Location.Reference.Alignment<alignmentrequirement)) then
                              hlcg.G_ConcatCopy_Unaligned(CurrentAsmData.CurrAsmList,left.resultdef,right.Location.Reference,left.Location.Reference)
                            else
                              hlcg.G_ConcatCopy(CurrentAsmData.CurrAsmList,left.resultdef,right.Location.Reference,left.Location.Reference);
                          end;
                      end;
                    LOC_MMREGISTER,
                    LOC_CMMREGISTER:
                      begin
{$ifdef x86}
                        if (right.resultdef.typ=floatdef) and
                           not Use_VectorFPU(right.resultdef) then
                          begin
                            { perform size conversion if needed (the mm-code cannot }
                            { convert an extended into a double/single, since sse   }
                            { doesn't support extended)                             }
                            r:=cg.GetFPURegister(CurrentAsmData.CurrAsmList,right.Location.Size);
                            tg.GetHLTemp(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef.Size,tt_normal,href);
                            cg.A_LoadFPU_Ref_Reg(CurrentAsmData.CurrAsmList,right.Location.Size,right.Location.Size,right.Location.Reference,r);
                            cg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,right.Location.Size,left.Location.Size,r,href);
                            if releaseright then
                              location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
                            releaseright:=true;
                            Location_Reset_Ref(right.Location,LOC_REFERENCE,left.Location.Size,0,[]);
                            right.Location.Reference:=href;
                            right.resultdef:=left.resultdef;
                          end;
{$endif}
                        hlcg.A_LoadMM_Ref_Reg(CurrentAsmData.CurrAsmList,
                          right.resultdef,
                          left.resultdef,
                          right.Location.Reference,
                          left.Location.Register,MMS_MoveScalar);
                      end;
                    LOC_SUBSETREG,
                    LOC_CSUBSETREG:
                      hlcg.A_Load_Ref_SubsetReg(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.Location.Reference,left.Location.SReg);
                    LOC_SUBSETREF,
                    LOC_CSUBSETREF:
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if right.Location.Size in [OS_64,OS_S64] then
                       cg64.A_Load64_Ref_SubsetRef(CurrentAsmData.CurrAsmList,right.Location.Reference,left.Location.SRef)
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                       hlcg.A_Load_Ref_SubsetRef(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.Location.Reference,left.Location.SRef);
                    else
                      InternalError(200203284);
                  end;
                end;
{$ifdef SUPPORT_MMX}
              LOC_CMMXREGISTER,
              LOC_MMXREGISTER:
                begin
                  if left.Location.Loc=LOC_CMMXREGISTER then
                    cg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,OS_M64,OS_M64,right.Location.Register,left.Location.Register,nil)
                  else
                    cg.A_LoadMM_Reg_Ref(CurrentAsmData.CurrAsmList,OS_M64,OS_M64,right.Location.Register,left.Location.Reference,nil);
                end;
{$endif SUPPORT_MMX}
              LOC_MMREGISTER,
              LOC_CMMREGISTER:
                begin
                  if (Is_Vector(left.resultdef)) then
                    shuffle := nil
                  else
                    shuffle := MMS_MoveScalar;

                  case left.Location.Loc of
                    LOC_CMMREGISTER,
                    LOC_MMREGISTER:
                      hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.Location.Register,left.Location.Register, shuffle);
                    LOC_REFERENCE,
                    LOC_CREFERENCE:
                      hlcg.A_LoadMM_Reg_Ref(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.Location.Register,left.Location.Reference, shuffle);
                    else
                      InternalError(2009112601);
                  end;
                end;
              LOC_REGISTER,
              LOC_CREGISTER :
                begin
{$ifndef cpuhighleveltarget}
{$ifdef cpu64bitalu}
                  if left.Location.Size in [OS_128,OS_S128] then
                    cg128.A_Load128_Reg_Loc(CurrentAsmData.CurrAsmList,
                      right.Location.Register128,left.Location)
                  else
{$else cpu64bitalu}
                  { also OS_F64 in case of mmreg -> intreg }
                  if left.Location.Size in [OS_64,OS_S64,OS_F64] then
                    cg64.A_Load64_Reg_Loc(CurrentAsmData.CurrAsmList,
                      right.Location.Register64,left.Location)
                  else
{$endif cpu64bitalu}
{$endif not cpuhighleveltarget}
                    hlcg.A_Load_Reg_Loc(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.Location.Register,left.Location);
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER :
                begin
                  { we can't do direct moves between fpu and mm registers }
                  if left.Location.Loc in [LOC_MMREGISTER,LOC_CMMREGISTER] then
                    begin
{$ifdef x86}
                      if not Use_VectorFPU(right.resultdef) then
                        begin
                          { perform size conversion if needed (the mm-code cannot convert an   }
                          { extended into a double/single, since sse doesn't support extended) }
                          tg.GetHLTemp(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef.Size,tt_normal,href);
                          cg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,right.Location.Size,left.Location.Size,right.Location.Register,href);
                          Location_Reset_Ref(right.Location,LOC_REFERENCE,left.Location.Size,0,[]);
                          right.Location.Reference:=href;
                          right.resultdef:=left.resultdef;
                        end;
{$endif}
                      hlcg.Location_Force_MMRegScalar(CurrentAsmData.CurrAsmList,right.Location,right.resultdef,false);
                      hlcg.A_LoadMM_Reg_Reg(CurrentAsmData.CurrAsmList,
                          right.resultdef,left.resultdef,
                          right.Location.Register,left.Location.Register,MMS_MoveScalar);
                    end
                  else
                    hlcg.A_LoadFPU_Reg_Loc(CurrentAsmData.CurrAsmList,
                        right.resultdef,left.resultdef,
                        right.Location.Register,left.Location);
                end;
              LOC_SUBSETREG,
              LOC_CSUBSETREG:
                begin
                  hlcg.A_Load_SubsetReg_Loc(CurrentAsmData.CurrAsmList,
                      right.resultdef,left.resultdef,right.Location.SReg,left.Location);
                end;
              LOC_SUBSETREF,
              LOC_CSUBSETREF:
                begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                  if right.Location.Size in [OS_64,OS_S64] then
                   cg64.A_Load64_SubsetRef_Loc(CurrentAsmData.CurrAsmList,right.Location.SRef,left.Location)
                  else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                  hlcg.A_Load_SubsetRef_Loc(CurrentAsmData.CurrAsmList,
                      right.resultdef,left.resultdef,right.Location.SRef,left.Location);
                end;
              LOC_JUMP :
                begin
                  CurrentAsmData.getjumplabel(hlabel);
                  hlcg.A_Label(CurrentAsmData.CurrAsmList,right.Location.TrueLabel);
                  if Is_PasBool(left.resultdef) then
                    begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if left.Location.Size in [OS_64,OS_S64] then
                        cg64.A_Load64_Const_Loc(CurrentAsmData.CurrAsmList,1,left.Location)
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                        hlcg.A_Load_Const_Loc(CurrentAsmData.CurrAsmList,left.resultdef,1,left.Location)
                    end
                  else
                    begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if left.Location.Size in [OS_64,OS_S64] then
                        cg64.A_Load64_Const_Loc(CurrentAsmData.CurrAsmList,-1,left.Location)
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                        hlcg.A_Load_Const_Loc(CurrentAsmData.CurrAsmList,left.resultdef,-1,left.Location);
                    end;

                  hlcg.A_Jmp_Always(CurrentAsmData.CurrAsmList,hlabel);
                  hlcg.A_Label(CurrentAsmData.CurrAsmList,right.Location.FalseLabel);
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                  if left.Location.Size in [OS_64,OS_S64] then
                    cg64.A_Load64_Const_Loc(CurrentAsmData.CurrAsmList,0,left.Location)
                  else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                    hlcg.A_Load_Const_Loc(CurrentAsmData.CurrAsmList,left.resultdef,0,left.Location);
                  hlcg.A_Label(CurrentAsmData.CurrAsmList,hlabel);
                end;
{$ifdef cpuflags}
              LOC_FLAGS :
                begin
                  { check for cbool here as booleans converted to other types shall be handled as pas booleans,
                    see also tests/tbs/tw40908.pas }
                  if Is_CBool(left.resultdef) then
                    begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if left.Location.Size in [OS_S64,OS_64] then
                        begin
                          r64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                          r64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                          cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,OS_32,right.Location.ResFlags,r64.RegLo);
                          cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                          cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,0,r64.RegHi);
                          cg64.A_Op64_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,OS_S64,
                            r64,r64);
                          cg64.A_Load64_Reg_Loc(CurrentAsmData.CurrAsmList,r64,left.Location);
                        end
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                        begin
                          r:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,left.Location.Size);
                          cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,left.Location.Size,right.Location.ResFlags,r);
                          cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                          cg.A_Op_Reg_Reg(CurrentAsmData.CurrAsmList,OP_NEG,left.Location.Size,r,r);
                          hlcg.A_Load_Reg_Loc(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,r,left.Location);
                        end
                    end
                  else
                    begin
                      case left.Location.Loc of
                        LOC_REGISTER,LOC_CREGISTER:
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                          if left.Location.Size in [OS_S64,OS_64] then
                            begin
                              cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,OS_32,right.Location.ResFlags,left.Location.Register64.RegLo);
                              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                              cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,0,left.Location.Register64.RegHi);
                            end
                          else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                            begin
                              cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,left.Location.Size,right.Location.ResFlags,left.Location.Register);
                              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            end;
                        LOC_CREFERENCE,
                        LOC_REFERENCE:
                        { i8086 and i386 have hacks in their code generators so that they can
                          deal with 64 bit locations in this particular case }
{$if not defined(cpu64bitalu) and not defined(x86) and not defined(cpuhighleveltarget)}
                          if left.Location.Size in [OS_S64,OS_64] then
                            begin
                              r64.RegLo:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                              r64.RegHi:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,OS_32);
                              cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,OS_32,right.Location.ResFlags,r64.RegLo);
                              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                              cg.A_Load_Const_Reg(CurrentAsmData.CurrAsmList,OS_32,0,r64.RegHi);
                              cg64.A_Load64_Reg_Ref(CurrentAsmData.CurrAsmList,r64,left.Location.Reference);
                            end
                          else
{$endif not cpu64bitalu and not x86 and not cpuhighleveltarget}
                            begin
                              cg.G_Flags2Ref(CurrentAsmData.CurrAsmList,left.Location.Size,right.Location.ResFlags,left.Location.Reference);
                              cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            end;
                        LOC_CSUBSETREG,LOC_SUBSETREG,LOC_SUBSETREF:
                          begin
                            r:=cg.GetIntRegister(CurrentAsmData.CurrAsmList,left.Location.Size);
                            cg.G_Flags2Reg(CurrentAsmData.CurrAsmList,left.Location.Size,right.Location.ResFlags,r);
                            cg.A_Reg_Dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            hlcg.A_Load_Reg_Loc(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,r,left.Location);
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

        if releaseright then
          location_freetemp(CurrentAsmData.CurrAsmList,right.Location);
      end;


{*****************************************************************************
                           SecondArrayConstruct
*****************************************************************************}

      const
        vtInteger       = 0;
        vtBoolean       = 1;
        vtChar          = 2;
        vtExtended      = 3;
        vtString        = 4;
        vtPointer       = 5;
        vtPChar         = 6;
        vtObject        = 7;
        vtClass         = 8;
        vtWideChar      = 9;
        vtPWideChar     = 10;
        vtAnsiString32  = 11;
        vtCurrency      = 12;
        vtVariant       = 13;
        vtInterface     = 14;
        vtWideString    = 15;
        vtInt64         = 16;
        vtQWord         = 17;
        vtUnicodeString = 18;
        vtAnsiString16  = 19;
        vtAnsiString64  = 20;


    procedure TCGArrayConstructorNode.makearrayref(var ref: TReference; eledef: TDef);
      begin
        { do nothing by default }
      end;


    procedure TCGArrayConstructorNode.advancearrayoffset(var ref: TReference; EleSize: asizeint);
      begin
        ref.Alignment:=NewAlignment(ref.Alignment,EleSize);
        inc(ref.Offset,EleSize);
      end;


    procedure TCGArrayConstructorNode.pass_generate_code;
      var
        hp    : TArrayConstructorNode;
        href,
        fref  : TReference;
        lt    : TDef;
        ParaLoc : TCGParaLocation;
        varvtypefield,
        varfield : TFieldVarSym;
        vtype : LongInt;
        eledef: TDef;
        EleSize : LongInt;
        tmpreg  : TRegister;
        vaddr : boolean;
        freetemp,
        dovariant: boolean;
      begin
        if Is_Packed_Array(resultdef) then
          InternalError(200608042);
        dovariant:=
          (acnf_forcevaria in arrayconstructornodeflags) or Is_Variant_Array(resultdef);
        eledef:=TArrayDef(resultdef).ElementDef;
        EleSize:=eledef.Size;
        if dovariant then
          varvtypefield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VTYPE'))
        else
          varvtypefield:=nil;
        { alignment is filled in by tg.gethltemp below }
        Location_Reset_Ref(location,LOC_CREFERENCE,OS_NO,0,[]);
        fillchar(ParaLoc,sizeof(ParaLoc),0);
        { Allocate always a temp, also if no elements are required, to
          be sure that location is valid (PFV) }

        tg.GetHLTemp(CurrentAsmData.CurrAsmList,resultdef,(TArrayDef(resultdef).HighRange+1)*EleSize,tt_normal,location.Reference);
        href:=location.Reference;
        makearrayref(href,eledef);
        { Process nodes in array constructor }
        hp:=self;
        while Assigned(hp) do
         begin
           if Assigned(hp.left) then
            begin
              freetemp:=true;
              SecondPass(hp.left);
              if (hp.left.Location.Loc=LOC_JUMP)<>
                 (hp.left.expectloc=LOC_JUMP) then
                InternalError(2007103101);
              { Move flags and jump in register }
              if hp.left.Location.Loc in [LOC_FLAGS,LOC_JUMP] then
                hlcg.Location_Force_Reg(CurrentAsmData.CurrAsmList,hp.left.Location,hp.left.resultdef,hp.left.resultdef,false);

              if dovariant then
               begin
                 { find the correct vtype value }
                 vtype:=$ff;
                 varfield:=nil;
                 vaddr:=false;
                 lt:=hp.left.resultdef;
                 case lt.typ of
                   enumdef,
                   orddef :
                     begin
                       if Is_64Bit(lt) then
                         begin
                            case TOrdDef(lt).OrdType of
                              scurrency:
                                begin
                                  vtype:=vtCurrency;
                                  varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VCURRENCY'));
                                end;
                              s64bit:
                                begin
                                  vtype:=vtInt64;
                                  varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VINT64'));
                                end;
                              u64bit:
                                begin
                                  vtype:=vtQWord;
                                  varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VQWORD'));
                                end;
                              else
                                ;
                            end;
                            freetemp:=false;
                            vaddr:=true;
                         end
                       else if (lt.typ=enumdef) or
                           Is_Integer(lt) then
                         begin
                           vtype:=vtInteger;
                           varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VINTEGER'));
                         end
                       else
                         if Is_Boolean(lt) then
                           begin
                             vtype:=vtBoolean;
                             varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VINTEGER'));
                           end
                         else
                           if (lt.typ=orddef) then
                             begin
                               case TOrdDef(lt).OrdType of
                                 uchar:
                                   begin
                                     vtype:=vtChar;
                                     varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VINTEGER'));
                                   end;
                                 uwidechar:
                                   begin
                                     vtype:=vtWideChar;
                                     varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VINTEGER'));
                                   end;
                                 else
                                   ;
                               end;
                             end;
                     end;
                   floatdef :
                     begin
                       if Is_Currency(lt) then
                         begin
                           vtype:=vtCurrency;
                           varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VCURRENCY'));
                         end
                       else
                         begin
                           vtype:=vtExtended;
                           varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VEXTENDED'));
                         end;
                       freetemp:=false;
                       vaddr:=true;
                     end;
                   procvardef,
                   pointerdef :
                     begin
                       if Is_PChar(lt) then
                         begin
                           vtype:=vtPChar;
                           varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VPCHAR'));
                         end
                       else if Is_PWideChar(lt) then
                         begin
                           vtype:=vtPWideChar;
                           varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VPWIDECHAR'));
                         end
                       else
                         begin
                           vtype:=vtPointer;
                           varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VPOINTER'));
                         end;
                     end;
                   variantdef :
                     begin
                        vtype:=vtVariant;
                        varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VVARIANT'));
                        vaddr:=true;
                        freetemp:=false;
                     end;
                   classrefdef :
                     begin
                       vtype:=vtClass;
                       varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VCLASS'));
                     end;
                   objectdef :
                     if Is_Interface(lt) then
                       begin
                         vtype:=vtInterface;
                         varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VINTERFACE'));
                       end
                     { vtObject really means a class based on TObject }
                     else if Is_Class(lt) then
                       begin
                         vtype:=vtObject;
                         varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VOBJECT'));
                       end
                     else
                       InternalError(200505171);
                   stringdef :
                     begin
                       if Is_ShortString(lt) then
                        begin
                          vtype:=vtString;
                          varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VSTRING'));
                          vaddr:=true;
                          freetemp:=false;
                        end
                       else
                        if Is_AnsiString(lt) then
                         begin
                           vtype:=vtAnsiString;
                           varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VANSISTRING'));
                           freetemp:=false;
                         end
                       else
                        if Is_WideString(lt) then
                         begin
                           vtype:=vtWideString;
                           varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VWIDESTRING'));
                           freetemp:=false;
                         end
                       else
                        if Is_UnicodeString(lt) then
                         begin
                           vtype:=vtUnicodeString;
                           varfield:=TFieldVarSym(Search_Struct_Member_No_Helper(TRecordDef(eledef),'VUNICODESTRING'));
                           freetemp:=false;
                         end;
                     end;
                   else
                     ;
                 end;
                 if vtype=$ff then
                   InternalError(14357);
                 if not Assigned(varfield) then
                   InternalError(2015102901);
                 { write changing field update href to the next element }
                 fref:=href;
                 hlcg.G_Set_Addr_NonBitPacked_Field_Ref(CurrentAsmData.CurrAsmList,TRecordDef(eledef),varfield,fref);
                 if vaddr then
                   begin
                     hlcg.Location_Force_Mem(CurrentAsmData.CurrAsmList,hp.left.Location,lt);
                     tmpreg:=hlcg.GetAddressRegister(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(lt));
                     hlcg.A_LoadAddr_Ref_Reg(CurrentAsmData.CurrAsmList,hp.left.resultdef,CPointerDef.getreusable(lt),hp.left.Location.Reference,tmpreg);
                     hlcg.A_Load_Reg_Ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(lt),varfield.vardef,tmpreg,fref);
                   end
                 else
                   hlcg.A_Load_Loc_Ref(CurrentAsmData.CurrAsmList,hp.left.resultdef,varfield.vardef,hp.left.Location,fref);
                 { update href to the vtype field and write it }
                 fref:=href;
                 hlcg.G_Set_Addr_NonBitPacked_Field_Ref(CurrentAsmData.CurrAsmList,TRecordDef(eledef),varvtypefield,fref);
                 hlcg.A_Load_Const_Ref(CurrentAsmData.CurrAsmList,varvtypefield.vardef,vtype,fref);
                 { goto next array element }
                 advancearrayoffset(href,EleSize);
               end
              else
              { normal array constructor of the same type }
               begin
                 if Is_Managed_Type(resultdef) then
                   freetemp:=false;
                 case hp.left.Location.Loc of
                   LOC_MMREGISTER,
                   LOC_CMMREGISTER:
                     hlcg.A_LoadMM_Reg_Ref(CurrentAsmData.CurrAsmList,hp.left.resultdef,hp.left.resultdef,
                       hp.left.Location.Register,href,MMS_MoveScalar);
                   LOC_FPUREGISTER,
                   LOC_CFPUREGISTER :
                     hlcg.A_LoadFPU_Reg_Ref(CurrentAsmData.CurrAsmList,hp.left.resultdef,hp.left.resultdef,hp.left.Location.Register,href);
                   LOC_REFERENCE,
                   LOC_CREFERENCE :
                     begin
                       if Is_ShortString(hp.left.resultdef) then
                         hlcg.G_CopyShortString(CurrentAsmData.CurrAsmList,hp.left.Location.Reference,href,
                             TStringDef(hp.left.resultdef))
                       else
                         hlcg.G_ConcatCopy(CurrentAsmData.CurrAsmList,eledef,hp.left.Location.Reference,href);
                     end;
                   else
                     begin
{$ifndef cpuhighleveltarget}
{$ifdef cpu64bitalu}
                       if hp.left.Location.Size in [OS_128,OS_S128] then
                         cg128.A_Load128_Loc_Ref(CurrentAsmData.CurrAsmList,hp.left.Location,href)
                       else
{$else cpu64bitalu}
                       if hp.left.Location.Size in [OS_64,OS_S64] then
                         cg64.A_Load64_Loc_Ref(CurrentAsmData.CurrAsmList,hp.left.Location,href)
                       else
{$endif cpu64bitalu}
{$endif not cpuhighleveltarget}
                         hlcg.A_Load_Loc_Ref(CurrentAsmData.CurrAsmList,eledef,eledef,hp.left.Location,href);
                     end;
                 end;
                 advancearrayoffset(href,EleSize);
               end;
              if freetemp then
                location_freetemp(CurrentAsmData.CurrAsmList,hp.left.Location);
            end;
           { load next entry }
           hp:=TArrayConstructorNode(hp.right);
         end;
      end;


{*****************************************************************************
                           SecondRTTI
*****************************************************************************}

    procedure TCGRTTINode.pass_generate_code;
      var
        indirect : boolean;
      begin
        indirect := (tf_supports_packages in TargetInfo.flags) and
                      (TargetInfo.system in systems_indirect_var_imports) and
                      (rttidef.owner.ModuleID<>CurrentModule.ModuleID);

        Location_Reset_Ref(location,LOC_CREFERENCE,OS_NO,sizeof(PInt),[]);
        case rttidatatype of
          rdt_normal:
            location.Reference.Symbol:=RTTIWriter.get_rtti_label(rttidef,rttitype,indirect);
          rdt_ord2str:
            location.Reference.Symbol:=RTTIWriter.get_rtti_label_ord2str(rttidef,rttitype,indirect);
          rdt_str2ord:
            location.Reference.Symbol:=RTTIWriter.get_rtti_label_str2ord(rttidef,rttitype,indirect);
        end;
      end;



begin
   CLoadNode:=TCGLoadNode;
   CAssignmentNode:=TCGAssignmentNode;
   CArrayConstructorNode:=TCGArrayConstructorNode;
   CRTTINode:=TCGRTTINode;
end.
