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
          procedure advancearrayoffset(var ref: TReference; elesize: asizeint);virtual;
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
              if (TAbstractVarSym(TLoadNode(n).symtableentry).varoptions * [vo_is_dll_var, vo_is_thread_var] = []) and
                 not Assigned(TLoadNode(n).left) and
                 { not function result, or no exit in function }
                 (((TLoadNode(n).symtableentry <> rr^.ressym) and
                   not(vo_is_funcret in TAbstractVarSym(TLoadNode(n).symtableentry).varoptions)) or
                  not(fc_exit in flowcontrol)) and
                 { stored in memory... }
                 (TAbstractNormalVarSym(TLoadNode(n).symtableentry).localloc.loc in [LOC_REFERENCE]) and
                 { ... at the place we are looking for }
                 references_equal(TAbstractNormalVarSym(TLoadNode(n).symtableentry).localloc.reference,rr^.old^) and
                 { its address cannot have escaped the current routine }
                 not(TAbstractVarSym(TLoadNode(n).symtableentry).addr_taken) and
                 { it is not accessed in nested procedures }
                 not(TAbstractVarSym(TLoadNode(n).symtableentry).different_scope) then
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
                 (TTempRefNode(n).tempinfo^.location.loc in [LOC_REFERENCE]) and
                 { ... at the place we are looking for }
                 references_equal(TTempRefNode(n).tempinfo^.location.reference,rr^.old^) and
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
               is_special_array(TUnaryNode(n).left.resultdef) or
               (TUnaryNode(n).left.resultdef.size<>TUnaryNode(n).resultdef.size) then
              result := fen_norecurse_false;

          { optimize the searching a bit }
          derefn,addrn,
          calln,inlinen,casen,
          addn,subn,muln,
          andn,orn,xorn,
          ltn,lten,gtn,gten,equaln,unequaln,
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
           (n.location.loc <> LOC_REFERENCE) or
           { not inside a control flow statement and no goto's in sight }
           ([fc_inflowcontrol,fc_gotolabel] * flowcontrol <> []) or
           { not for refcounted types, because those locations are   }
           { still used later on in initialisation/finalisation code }
           is_managed_type(n.resultdef) or
           { source and destination are temps (= not global variables) }
           { and both point to the start of a temp, and the source is a }
           { non-persistent temp (otherwise we need some kind of copy-  }
           { on-write support in case later on both are still used)     }
           not tg.isstartoftemp(newref) or
           not tg.isstartoftemp(n.location.reference) or
           (tg.gettypeoftemp(newref) <> tt_normal) or
           not (tg.gettypeoftemp(n.location.reference) in [tt_normal,tt_persistent]) or
           { and both have the same size }
           (tg.sizeoftemp(CurrentAsmData.CurrAsmList,newref) <> tg.sizeoftemp(CurrentAsmData.CurrAsmList,n.location.reference)) then
          exit;

        { find the source of the old reference (loadnode or tempnode) }
        { and replace it with the new reference                       }
        rr.old := @n.location.reference;
        rr.new := @newref;
        rr.ressym := nil;

        if Assigned(CurrentProcInfo.procdef.funcretsym) and
           (TAbstractVarSym(CurrentProcInfo.procdef.funcretsym).refs <> 0) then
          if (CurrentProcInfo.procdef.proctypeoption=potype_constructor) then
            rr.ressym:=TSym(CurrentProcInfo.procdef.parast.Find('self'))
         else
            rr.ressym:=CurrentProcInfo.procdef.funcretsym;

        { if source not found, don't do anything }
        if not foreachnodestatic(n,@doreplaceref,@rr) then
          exit;

        n.location.reference := newref;
        result:=true;
      end;

{*****************************************************************************
                             SecondLoad
*****************************************************************************}

    procedure TCGLoadNode.changereflocation(const ref: TReference);
      var
        oldtemptype: TTempType;
      begin
        if (location.loc<>LOC_REFERENCE) then
          InternalError(2007020812);
        if not tg.istemp(location.reference) then
          InternalError(2007020813);
        oldtemptype:=tg.gettypeoftemp(location.reference);
        if (oldtemptype = tt_persistent) then
          tg.ChangeTempType(CurrentAsmData.CurrAsmList,location.reference,tt_normal);
        tg.ungettemp(CurrentAsmData.CurrAsmList,location.reference);
        location.reference:=ref;
        tg.ChangeTempType(CurrentAsmData.CurrAsmList,location.reference,oldtemptype);
        TAbstractNormalVarSym(symtableentry).localloc:=location;
        hlcg.recordnewsymloc(CurrentAsmData.CurrAsmList,symtableentry,TAbstractNormalVarSym(symtableentry).vardef,location.reference,false);
      end;


    procedure TCGLoadNode.generate_nested_access(vs: TSym);
      var
        { parameter declared as tsym to reduce interface unit dependencies }
        lvs: TAbstractNormalVarSym absolute vs;
      begin
        SecondPass(left);
        if not(left.location.loc in [LOC_REGISTER,LOC_CREGISTER]) then
          InternalError(200309286);
        if lvs.localloc.loc<>LOC_REFERENCE then
          InternalError(200409241);
        hlcg.reference_reset_base(location.reference,left.resultdef,left.location.register,lvs.localloc.reference.offset,ctempposinvalid,lvs.localloc.reference.alignment,lvs.localloc.reference.volatility);
      end;


    procedure TCGLoadNode.generate_absaddr_access(vs: TAbsoluteVarSym);
      begin
        location.reference.offset:=asizeint(vs.addroffset);
        location.reference.volatility:=[vol_read,vol_write];
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
            if gvs.localloc.loc=LOC_INVALID then
              reference_reset_symbol(location.reference,CurrentAsmData.RefAsmSymbol(gvs.mangledname,AT_TLS,use_indirect_symbol(gvs)),0,location.reference.alignment,[])
            else
              location:=gvs.localloc;
            exit;
          end;
        { Every variable names an image-owned descriptor. Startup and late
          images use the same resolver; there is no inline main-thread value. }
        pd:=search_system_proc('fpc_threadvar_addr');
        para.init;
        paramanager.getcgtempparaloc(CurrentAsmData.CurrAsmList,pd,1,para);
        if vo_is_weak_external in gvs.varoptions then
          reference_reset_symbol(ref,CurrentAsmData.WeakRefAsmSymbol(gvs.mangledname,AT_DATA),0,sizeof(PInt),[])
        else
          reference_reset_symbol(ref,CurrentAsmData.RefAsmSymbol(gvs.mangledname,AT_DATA,use_indirect_symbol(gvs)),0,sizeof(PInt),[]);
        hlcg.a_loadaddr_ref_cgpara(CurrentAsmData.CurrAsmList,voidpointertype,ref,para);
        paramanager.freecgpara(CurrentAsmData.CurrAsmList,para);
        respara:=hlcg.g_call_system_proc(CurrentAsmData.CurrAsmList,pd,[@para],voidpointertype);
        para.done;
        reg:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,voidpointertype);
        location_reset(tmp,LOC_REGISTER,OS_ADDR);
        tmp.register:=reg;
        hlcg.gen_load_cgpara_loc(CurrentAsmData.CurrAsmList,voidpointertype,respara,tmp,true);
        respara.resetiftemp;
        hlcg.reference_reset_base(location.reference,voidpointertype,reg,0,ctempposinvalid,resultdef.alignment,[]);
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
                (gvs.varoptions*[vo_is_external,vo_is_weak_external]=[]) and
                (gvs.owner.symtabletype in [GlobalSymTable,staticsymtable]) and
                not sym_is_owned_by(gvs,CurrentModule.GlobalSymTable) and
                (
                  (CurrentModule.GlobalSymTable=CurrentModule.localsymtable) or
                  not sym_is_owned_by(gvs,CurrentModule.localsymtable)
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
        newsize:=def_cgsize(resultdef);
        { alignment is overridden per case below }
        location_reset_ref(location,LOC_REFERENCE,newsize,resultdef.alignment,[]);
        case symtableentry.typ of
           absolutevarsym :
              begin
                 { this is only for toasm and toaddr }
                 case TAbsoluteVarSym(symtableentry).abstyp of
                   toaddr :
                     generate_absaddr_access(TAbsoluteVarSym(symtableentry));
                   toasm :
                     location.reference.symbol:=CurrentAsmData.RefAsmSymbol(TAbsoluteVarSym(symtableentry).mangledname,AT_DATA);
                   else
                     InternalError(200310283);
                 end;
              end;
           constsym:
             begin
                if TConstSym(symtableentry).consttyp in [constresourcestring,constwresourcestring] then
                  begin
                     location_reset_ref(location,LOC_CREFERENCE,def_cgsize(cansistringtype),cansistringtype.size,[]);
                     indirect:=(tf_supports_packages in TargetInfo.flags) and
                                 (TargetInfo.system in systems_indirect_var_imports) and
                                 (symtableentry.owner.ModuleID<>CurrentModule.ModuleID);
                     name:=make_mangledname('RESSTR',symtableentry.owner,symtableentry.name);
                     location.reference.symbol:=CurrentAsmData.RefAsmSymbol(name,AT_DATA,indirect);
                     if symtableentry.owner.ModuleID<>CurrentModule.ModuleID then
                       CurrentModule.addimportedsym(symtableentry);
                     vd:=search_system_type('TRESOURCESTRINGRECORD').typedef;
                     hlcg.g_set_addr_nonbitpacked_field_ref(
                       CurrentAsmData.CurrAsmList,
                       TRecordDef(vd),
                       TFieldVarSym(search_struct_member(TRecordDef(vd),'CURRENTVALUE')),
                       location.reference);
                  end
                else
                  InternalError(22798);
             end;
           staticvarsym :
             begin
               gvs:=TStaticVarSym(symtableentry);

               if (vo_is_dll_var in gvs.varoptions) then
               { DLL variable }
                 begin
                   hregister:=cg.getaddressregister(CurrentAsmData.CurrAsmList);
                   if not(vo_is_weak_external in gvs.varoptions) then
                     location.reference.symbol:=CurrentAsmData.RefAsmSymbol(TStaticVarSym(symtableentry).mangledname,AT_DATA)
                   else
                     location.reference.symbol:=CurrentAsmData.WeakRefAsmSymbol(TStaticVarSym(symtableentry).mangledname,AT_DATA);
                   cg.a_load_ref_reg(CurrentAsmData.CurrAsmList,OS_ADDR,OS_ADDR,location.reference,hregister);
                   reference_reset_base(location.reference,hregister,0,ctempposinvalid,location.reference.alignment,[]);
                 end
               { Thread variable }
               else if (vo_is_thread_var in gvs.varoptions) then
                 generate_threadvar_access(gvs)
               { Normal (or external) variable }
               else
                 begin
                   if gvs.localloc.loc=LOC_INVALID then
                     begin
                       { static data is currently always volatile }
                       if not(vo_is_weak_external in gvs.varoptions) then
                         reference_reset_symbol(location.reference,CurrentAsmData.RefAsmSymbol(gvs.mangledname,AT_DATA,use_indirect_symbol(gvs)),0,location.reference.alignment,[])
                       else
                         reference_reset_symbol(location.reference,CurrentAsmData.WeakRefAsmSymbol(gvs.mangledname,AT_DATA),0,location.reference.alignment,[])
                     end
                   else
                      location:=gvs.localloc;
                  end;

                { make const a LOC_CREFERENCE }
                if (gvs.varspez=vs_const) and
                   (location.loc=LOC_REFERENCE) then
                  location.loc:=LOC_CREFERENCE;
              end;
            paravarsym,
            localvarsym :
              begin
                vs:=TAbstractNormalVarSym(symtableentry);
                { Nested variable }
                if Assigned(left) then
                  generate_nested_access(vs)
                else
                  location:=vs.localloc;

                { handle call by reference variables when they are not
                  already copied to local copies. Also ignore the reference
                  when we need to load the self pointer for objects }
                if is_addr_param_load then
                  begin
                    if (location.loc in [LOC_CREGISTER,LOC_REGISTER]) then
                      hregister:=location.register
                    else
                      begin
                        vd:=CPointerDef.getreusable(resultdef);
                        hregister:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,vd);
                        { we need to load only an address }
                        location.size:=int_cgsize(vd.size);
                        hlcg.a_load_loc_reg(CurrentAsmData.CurrAsmList,vd,vd,location,hregister);
                      end;
                    { assume packed records may always be unaligned }
                    if not(resultdef.typ in [recorddef,objectdef]) or
                       (TAbstractRecordSymTable(TAbstractRecordDef(resultdef).SymTable).usefieldalignment<>1) then
                      begin
                        alignment:=min(min(min(resultdef.alignment,CurrentSettings.alignment.LocalAlignMax),CurrentSettings.alignment.ConstAlignMax),CurrentSettings.alignment.VarAlignMax);
                        location_reset_ref(location,LOC_REFERENCE,newsize,alignment,[]);
                      end
                    else
                      location_reset_ref(location,LOC_REFERENCE,newsize,1,[]);
                    hlcg.reference_reset_base(location.reference,voidpointertype,hregister,0,ctempposinvalid,location.reference.alignment,[]);
                  end;

                { make const a LOC_CREFERENCE }
                if (vs.varspez=vs_const) and
                   (location.loc=LOC_REFERENCE) then
                  location.loc:=LOC_CREFERENCE;
             end;
           procsym:
              begin
                 if not Assigned(procdef) then
                   InternalError(200312011);
                 if Assigned(left) and
                   (resultdef.typ in [symconst.procdef,procvardef]) and
                    not TAbstractProcDef(resultdef).is_addressonly then
                   begin
                     location_reset(location,LOC_CREGISTER,int_cgsize(voidpointertype.size*2));

                     SecondPass(left);

                     { load class instance/classrefdef address }
                     if left.location.loc=LOC_CONSTANT then
                       hlcg.location_force_reg(CurrentAsmData.CurrAsmList,left.location,left.resultdef,left.resultdef,false);
                     { vd will contain the type of the self pointer (self in
                       case of a class/classref, address of self in case of
                       an object, frame pointer or pointer to parentfpstruct
                       in case of nested procsym load  }
                     vd:=nil;
                     case left.location.loc of
                        LOC_CREGISTER,
                        LOC_REGISTER:
                          begin
                             { this is not possible for objects }
                             if is_object(left.resultdef) then
                               InternalError(200304234);

                             location.registerhi:=left.location.register;

                             vd:=left.resultdef;
                          end;
                        LOC_CREFERENCE,
                        LOC_REFERENCE:
                          begin
                             if is_implicit_pointer_object_type(left.resultdef) or
                                (left.resultdef.typ=classrefdef) or
                                is_nested_pd(procdef) then
                               begin
                                 vd:=left.resultdef;

                                 location.registerhi:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,left.resultdef);
                                 hlcg.a_load_ref_reg(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,left.location.reference,location.registerhi)

                               end
                             else
                               begin
                                 vd:=CPointerDef.getreusable(left.resultdef);

                                 location.registerhi:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,vd);
                                 hlcg.a_loadaddr_ref_reg(CurrentAsmData.CurrAsmList,left.resultdef,vd,left.location.reference,location.registerhi);

                               end;
                             location_freetemp(CurrentAsmData.CurrAsmList,left.location);
                          end;
                        else
                          InternalError(200610311);
                     end;

                     { virtual method ? }
                     if (po_virtualmethod in procdef.procoptions) and
                        not(loadnf_inherited in loadnodeflags) and
                        not is_objectpascal_helper(procdef.struct) then
                       begin
                         if (not Assigned(CurrentProcInfo) or
                             wpoinfomanager.symbol_live(CurrentProcInfo.procdef.mangledname)) then
                           TObjectDef(procdef.struct).register_vmt_call(procdef.extnumber);
            {$ifdef vtentry}
                         if not is_interface(procdef.struct) then
                           begin
                             inc(CurrentAsmData.NextVTEntryNr);
                             CurrentAsmData.CurrAsmList.Concat(TAISymbol.CreateName('VTREF'+ToStr(CurrentAsmData.NextVTEntryNr)+'_'+procdef._class.vmt_mangledname+'$$'+ToStr(vmtoffset div sizeof(PInt)),AT_FUNCTION,0,voidpointerdef));
                           end;
            {$endif vtentry}
                         if (left.resultdef.typ=objectdef) and
                            Assigned(TObjectDef(left.resultdef).vmt_field) then
                           begin
                             { vmt pointer is a pointer to the vmt record }
                             hlcg.reference_reset_base(href,vd,location.registerhi,0,ctempposinvalid,vd.alignment,[]);
                             vmtdef:=CPointerDef.getreusable(TObjectDef(left.resultdef).vmt_def);
                             hlcg.g_set_addr_nonbitpacked_field_ref(CurrentAsmData.CurrAsmList,TObjectDef(left.resultdef),TFieldVarSym(TObjectDef(left.resultdef).vmt_field),href);
                             hregister:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,vmtdef);
                             hlcg.a_load_ref_reg(CurrentAsmData.CurrAsmList,TFieldVarSym(TObjectDef(left.resultdef).vmt_field).vardef,vmtdef,href,hregister);
                           end
                         else if left.resultdef.typ=classrefdef then
                           begin
                             vmtdef:=CPointerDef.getreusable(TObjectDef(TClassRefDef(left.resultdef).pointeddef).vmt_def);
                             { classrefdef is a pointer to the vmt already }

                             { targets with 32 bit method pointers got already a register assigned }
                             hregister:=location.registerhi;

                             hlcg.g_ptrtypecast_reg(CurrentAsmData.CurrAsmList,left.resultdef,vmtdef,hregister);
                           end
                         else if is_any_interface_kind(left.resultdef) then
                           begin
                             { an interface is a pointer to a pointer to a vmt }
                             hlcg.reference_reset_base(href,vd,location.registerhi,0,ctempposinvalid,vd.alignment,[]);
                             vmtdef:=CPointerDef.getreusable(TObjectDef(left.resultdef).vmt_def);
                             hregister:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,vmtdef);
                             hlcg.a_load_ref_reg(CurrentAsmData.CurrAsmList,vmtdef,vmtdef,href,hregister);
                           end
                         else
                           InternalError(2015112501);
                         { load method address }
                         vmtentry:=TAbstractRecordSymTable(TRecordDef(vmtdef.pointeddef).SymTable).findfieldbyoffset(
                           TObjectDef(procdef.struct).vmtmethodoffset(procdef.extnumber));
                         hlcg.reference_reset_base(href,vmtdef,hregister,0,ctempposinvalid,vmtdef.alignment,[]);
                         { targets with 32 bit method pointers got already a register assigned }

                         location.register:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,vmtentry.vardef);

                         hlcg.g_set_addr_nonbitpacked_field_ref(CurrentAsmData.CurrAsmList,TAbstractRecordDef(vmtdef.pointeddef),vmtentry,href);
                         hlcg.a_load_ref_reg(CurrentAsmData.CurrAsmList,vmtentry.vardef,vmtentry.vardef,href,location.register);
                       end
                     else
                       begin
                         { load address of the function }
                         reference_reset_symbol(href,CurrentAsmData.RefAsmSymbol(procdef.mangledname,AT_FUNCTION),0,procdef.address_type.alignment,[]);
                         { targets with 32 bit method pointers got already a register assigned }

                         location.register:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,CProcVarDef.getreusableprocaddr(procdef,pc_address_only));

                         hlcg.a_loadaddr_ref_reg(CurrentAsmData.CurrAsmList,procdef,CProcVarDef.getreusableprocaddr(procdef,pc_address_only),href,location.register);
                       end;

                     { to get methodpointers stored correctly, code and self register must be swapped on
                       big endian targets }
                     if TargetInfo.endian=endian_big then
                       begin
                         { cpus with 16 bit address registers don't use registerhi here }

                         hregister:=location.register;
                         location.register:=location.registerhi;
                         location.registerhi:=hregister;
                       end;
                   end
                 else
                   begin
                      pd:=TProcDef(TProcSym(symtableentry).ProcdefList[0]);
                      { def_cgsize does not work for tprocdef, so we use pd.address_type }
                      location.size:=def_cgsize(pd.address_type);
                      if not(po_weakexternal in pd.procoptions) then
                        location.reference.symbol:=CurrentAsmData.RefAsmSymbol(procdef.mangledname,AT_FUNCTION)
                      else
                        location.reference.symbol:=CurrentAsmData.WeakRefAsmSymbol(procdef.mangledname,AT_FUNCTION);
                   end;
              end;
           labelsym :
             if Assigned(TLabelSym(symtableentry).asmblocklabel) then
               location.reference.symbol:=TLabelSym(symtableentry).asmblocklabel
             else
               location.reference.symbol:=TCGLabelNode((TLabelSym(symtableentry).code)).getasmlabel;
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

        location_reset(location,LOC_VOID,OS_NO);

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
        if is_shortstring(left.resultdef) then
          begin
            {
              we can get here only in the following situations
              for the right node:
               - empty constant string
               - char
            }

            { The addn is replaced by a blockn or calln that already returns
              a shortstring }
            if is_shortstring(right.resultdef) and
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
                hlcg.g_ptrtypecast_ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(left.resultdef),TPointerDef(charpointertype),left.location.reference);
                hlcg.a_load_const_ref(CurrentAsmData.CurrAsmList,cansichartype,0,left.location.reference);
              end
            { char loading }
            else if is_char(right.resultdef) then
              begin
                if right.nodetype=ordconstn then
                  begin
                    hlcg.g_ptrtypecast_ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(left.resultdef),CPointerDef.getreusable(u16inttype),left.location.reference);
                    if (TargetInfo.endian = endian_little) then
                      hlcg.a_load_const_ref(CurrentAsmData.CurrAsmList,u16inttype,(TOrdConstNode(right).value.svalue shl 8) or 1,
                          setalignment(left.location.reference,1))
                    else
                      hlcg.a_load_const_ref(CurrentAsmData.CurrAsmList,u16inttype,TOrdConstNode(right).value.svalue or (1 shl 8),
                          setalignment(left.location.reference,1));
                  end
                else
                  begin
                    href:=left.location.reference;
                    hlcg.g_ptrtypecast_ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(left.resultdef),TPointerDef(charpointertype),href);
                    hlcg.a_load_const_ref(CurrentAsmData.CurrAsmList,cansichartype,1,href);
                    inc(href.offset,1);
                    href.alignment:=1;
                    case right.location.loc of
                      LOC_REGISTER,
                      LOC_CREGISTER :
                        begin
{$ifndef cpuhighleveltarget}
                          r:=cg.makeregsize(CurrentAsmData.CurrAsmList,right.location.register,OS_8);
{$else not cpuhighleveltarget}
                          r:=hlcg.getintregister(CurrentAsmData.CurrAsmList,u8inttype);
                          hlcg.a_load_reg_reg(CurrentAsmData.CurrAsmList,cansichartype,u8inttype,right.location.register,r);
{$endif cpuhighleveltarget}
                          hlcg.a_load_reg_ref(CurrentAsmData.CurrAsmList,u8inttype,u8inttype,r,href);
                        end;
                      LOC_REFERENCE,
                      LOC_CREFERENCE :
                        hlcg.a_load_ref_ref(CurrentAsmData.CurrAsmList,cansichartype,cansichartype,right.location.reference,href);
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
        else if (right.location.loc = LOC_REFERENCE) and
           maybechangetemp(CurrentAsmData.CurrAsmList,left,right.location.reference) then
          begin
            { if it worked, we're done }
          end
        else
          begin
            { SSA support }
            hlcg.maybe_change_load_node_reg(CurrentAsmData.CurrAsmList,left,false);
            hlcg.maybe_change_load_node_reg(CurrentAsmData.CurrAsmList,right,true);
            case right.location.loc of
              LOC_CONSTANT :
                begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                  if (left.location.size in [OS_64,OS_S64]) or (right.location.size in [OS_64,OS_S64]) then
                    cg64.a_load64_const_loc(CurrentAsmData.CurrAsmList,right.location.value64,left.location)
                  else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                    hlcg.a_load_const_loc(CurrentAsmData.CurrAsmList,left.resultdef,right.location.value,left.location);
                end;
              LOC_REFERENCE,
              LOC_CREFERENCE :
                begin
                  case left.location.loc of
                    LOC_REGISTER,
                    LOC_CREGISTER :
                      begin
{$ifndef cpuhighleveltarget}
{$ifdef cpu64bitalu}
                        if left.location.size in [OS_128,OS_S128] then
                          cg128.a_load128_ref_reg(CurrentAsmData.CurrAsmList,right.location.reference,left.location.register128)
                        else
{$else cpu64bitalu}
                        if left.location.size in [OS_64,OS_S64] then
                          cg64.a_load64_ref_reg(CurrentAsmData.CurrAsmList,right.location.reference,left.location.register64)
                        else
{$endif cpu64bitalu}
{$endif not cpuhighleveltarget}
                          hlcg.a_load_ref_reg(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.location.reference,left.location.register);
                      end;
                    LOC_FPUREGISTER,
                    LOC_CFPUREGISTER :
                      begin
                        hlcg.a_loadfpu_ref_reg(CurrentAsmData.CurrAsmList,
                            right.resultdef,left.resultdef,
                            right.location.reference,
                            left.location.register);
                      end;
                    LOC_REFERENCE,
                    LOC_CREFERENCE :
                      begin
                        if (left.resultdef.typ=floatdef) and
                           (right.resultdef.typ=floatdef) and
                           ((left.location.size<>right.location.size)
                           { on newer (1993+ :)) x86 cpus, use the fpu to copy extended values }
{$ifdef x86}
                            or ({$ifndef x86_64}(CurrentSettings.CPUType>=cpu_Pentium) and{$endif x86_64}
                            (is_extended(right.resultdef) {$ifdef i386} or is_double(right.resultdef){$endif i386} ))
{$endif x86}
                           )then
                          begin
                            { assume that all float types can be handed by the
                              fpu if one can be handled by the fpu }
                            if not use_vectorfpu(left.resultdef) or
                               not use_vectorfpu(right.resultdef) then
                              hlcg.a_loadfpu_ref_ref(CurrentAsmData.CurrAsmList,
                                right.resultdef,left.resultdef,
                                right.location.reference,left.location.reference)
                            else
                              hlcg.a_loadmm_ref_ref(CurrentAsmData.CurrAsmList,
                                right.resultdef,left.resultdef,
                                right.location.reference,left.location.reference,mms_movescalar)
                          end
                        else
                          begin
{ TODO: HACK: unaligned test, maybe remove all unaligned locations (array of char) from the compiler}
                            { Use unaligned copy when the offset is not aligned }
                            len:=left.resultdef.size;
                            { can be 0 in case of formaldef on JVM target }
                            if len=0 then
                              len:=sizeof(PInt);

                            { data smaller than an aint has less alignment requirements }
                            { max(1,...) avoids div by zero in case of an empty record  }
                            alignmentrequirement:=min(max(1,len),sizeof(aint));

                            if (right.location.reference.offset mod alignmentrequirement<>0) or
                              (left.location.reference.offset mod alignmentrequirement<>0) or
                              (right.resultdef.alignment<alignmentrequirement) or
                              ((right.location.reference.alignment<>0) and
                               (right.location.reference.alignment<alignmentrequirement)) or
                              ((left.location.reference.alignment<>0) and
                               (left.location.reference.alignment<alignmentrequirement)) then
                              hlcg.g_concatcopy_unaligned(CurrentAsmData.CurrAsmList,left.resultdef,right.location.reference,left.location.reference)
                            else
                              hlcg.g_concatcopy(CurrentAsmData.CurrAsmList,left.resultdef,right.location.reference,left.location.reference);
                          end;
                      end;
                    LOC_MMREGISTER,
                    LOC_CMMREGISTER:
                      begin
{$ifdef x86}
                        if (right.resultdef.typ=floatdef) and
                           not use_vectorfpu(right.resultdef) then
                          begin
                            { perform size conversion if needed (the mm-code cannot }
                            { convert an extended into a double/single, since sse   }
                            { doesn't support extended)                             }
                            r:=cg.getfpuregister(CurrentAsmData.CurrAsmList,right.location.size);
                            tg.gethltemp(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef.size,tt_normal,href);
                            cg.a_loadfpu_ref_reg(CurrentAsmData.CurrAsmList,right.location.size,right.location.size,right.location.reference,r);
                            cg.a_loadfpu_reg_ref(CurrentAsmData.CurrAsmList,right.location.size,left.location.size,r,href);
                            if releaseright then
                              location_freetemp(CurrentAsmData.CurrAsmList,right.location);
                            releaseright:=true;
                            location_reset_ref(right.location,LOC_REFERENCE,left.location.size,0,[]);
                            right.location.reference:=href;
                            right.resultdef:=left.resultdef;
                          end;
{$endif}
                        hlcg.a_loadmm_ref_reg(CurrentAsmData.CurrAsmList,
                          right.resultdef,
                          left.resultdef,
                          right.location.reference,
                          left.location.register,mms_movescalar);
                      end;
                    LOC_SUBSETREG,
                    LOC_CSUBSETREG:
                      hlcg.a_load_ref_subsetreg(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.location.reference,left.location.sreg);
                    LOC_SUBSETREF,
                    LOC_CSUBSETREF:
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if right.location.size in [OS_64,OS_S64] then
                       cg64.a_load64_ref_subsetref(CurrentAsmData.CurrAsmList,right.location.reference,left.location.sref)
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                       hlcg.a_load_ref_subsetref(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.location.reference,left.location.sref);
                    else
                      InternalError(200203284);
                  end;
                end;
{$ifdef SUPPORT_MMX}
              LOC_CMMXREGISTER,
              LOC_MMXREGISTER:
                begin
                  if left.location.loc=LOC_CMMXREGISTER then
                    cg.a_loadmm_reg_reg(CurrentAsmData.CurrAsmList,OS_M64,OS_M64,right.location.register,left.location.register,nil)
                  else
                    cg.a_loadmm_reg_ref(CurrentAsmData.CurrAsmList,OS_M64,OS_M64,right.location.register,left.location.reference,nil);
                end;
{$endif SUPPORT_MMX}
              LOC_MMREGISTER,
              LOC_CMMREGISTER:
                begin
                  if (is_vector(left.resultdef)) then
                    shuffle := nil
                  else
                    shuffle := mms_movescalar;

                  case left.location.loc of
                    LOC_CMMREGISTER,
                    LOC_MMREGISTER:
                      hlcg.a_loadmm_reg_reg(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.location.register,left.location.register, shuffle);
                    LOC_REFERENCE,
                    LOC_CREFERENCE:
                      hlcg.a_loadmm_reg_ref(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.location.register,left.location.reference, shuffle);
                    else
                      InternalError(2009112601);
                  end;
                end;
              LOC_REGISTER,
              LOC_CREGISTER :
                begin
{$ifndef cpuhighleveltarget}
{$ifdef cpu64bitalu}
                  if left.location.size in [OS_128,OS_S128] then
                    cg128.a_load128_reg_loc(CurrentAsmData.CurrAsmList,
                      right.location.register128,left.location)
                  else
{$else cpu64bitalu}
                  { also OS_F64 in case of mmreg -> intreg }
                  if left.location.size in [OS_64,OS_S64,OS_F64] then
                    cg64.a_load64_reg_loc(CurrentAsmData.CurrAsmList,
                      right.location.register64,left.location)
                  else
{$endif cpu64bitalu}
{$endif not cpuhighleveltarget}
                    hlcg.a_load_reg_loc(CurrentAsmData.CurrAsmList,right.resultdef,left.resultdef,right.location.register,left.location);
                end;
              LOC_FPUREGISTER,
              LOC_CFPUREGISTER :
                begin
                  { we can't do direct moves between fpu and mm registers }
                  if left.location.loc in [LOC_MMREGISTER,LOC_CMMREGISTER] then
                    begin
{$ifdef x86}
                      if not use_vectorfpu(right.resultdef) then
                        begin
                          { perform size conversion if needed (the mm-code cannot convert an   }
                          { extended into a double/single, since sse doesn't support extended) }
                          tg.gethltemp(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef.size,tt_normal,href);
                          cg.a_loadfpu_reg_ref(CurrentAsmData.CurrAsmList,right.location.size,left.location.size,right.location.register,href);
                          location_reset_ref(right.location,LOC_REFERENCE,left.location.size,0,[]);
                          right.location.reference:=href;
                          right.resultdef:=left.resultdef;
                        end;
{$endif}
                      hlcg.location_force_mmregscalar(CurrentAsmData.CurrAsmList,right.location,right.resultdef,false);
                      hlcg.a_loadmm_reg_reg(CurrentAsmData.CurrAsmList,
                          right.resultdef,left.resultdef,
                          right.location.register,left.location.register,mms_movescalar);
                    end
                  else
                    hlcg.a_loadfpu_reg_loc(CurrentAsmData.CurrAsmList,
                        right.resultdef,left.resultdef,
                        right.location.register,left.location);
                end;
              LOC_SUBSETREG,
              LOC_CSUBSETREG:
                begin
                  hlcg.a_load_subsetreg_loc(CurrentAsmData.CurrAsmList,
                      right.resultdef,left.resultdef,right.location.sreg,left.location);
                end;
              LOC_SUBSETREF,
              LOC_CSUBSETREF:
                begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                  if right.location.size in [OS_64,OS_S64] then
                   cg64.a_load64_subsetref_loc(CurrentAsmData.CurrAsmList,right.location.sref,left.location)
                  else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                  hlcg.a_load_subsetref_loc(CurrentAsmData.CurrAsmList,
                      right.resultdef,left.resultdef,right.location.sref,left.location);
                end;
              LOC_JUMP :
                begin
                  CurrentAsmData.getjumplabel(hlabel);
                  hlcg.a_label(CurrentAsmData.CurrAsmList,right.location.truelabel);
                  if is_pasbool(left.resultdef) then
                    begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if left.location.size in [OS_64,OS_S64] then
                        cg64.a_load64_const_loc(CurrentAsmData.CurrAsmList,1,left.location)
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                        hlcg.a_load_const_loc(CurrentAsmData.CurrAsmList,left.resultdef,1,left.location)
                    end
                  else
                    begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if left.location.size in [OS_64,OS_S64] then
                        cg64.a_load64_const_loc(CurrentAsmData.CurrAsmList,-1,left.location)
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                        hlcg.a_load_const_loc(CurrentAsmData.CurrAsmList,left.resultdef,-1,left.location);
                    end;

                  hlcg.a_jmp_always(CurrentAsmData.CurrAsmList,hlabel);
                  hlcg.a_label(CurrentAsmData.CurrAsmList,right.location.falselabel);
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                  if left.location.size in [OS_64,OS_S64] then
                    cg64.a_load64_const_loc(CurrentAsmData.CurrAsmList,0,left.location)
                  else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                    hlcg.a_load_const_loc(CurrentAsmData.CurrAsmList,left.resultdef,0,left.location);
                  hlcg.a_label(CurrentAsmData.CurrAsmList,hlabel);
                end;
{$ifdef cpuflags}
              LOC_FLAGS :
                begin
                  { check for cbool here as booleans converted to other types shall be handled as pas booleans,
                    see also tests/tbs/tw40908.pas }
                  if is_cbool(left.resultdef) then
                    begin
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                      if left.location.size in [OS_S64,OS_64] then
                        begin
                          r64.reglo:=cg.getintregister(CurrentAsmData.CurrAsmList,OS_32);
                          r64.reghi:=cg.getintregister(CurrentAsmData.CurrAsmList,OS_32);
                          cg.g_flags2reg(CurrentAsmData.CurrAsmList,OS_32,right.location.resflags,r64.reglo);
                          cg.a_reg_dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                          cg.a_load_const_reg(CurrentAsmData.CurrAsmList,OS_32,0,r64.reghi);
                          cg64.a_op64_reg_reg(CurrentAsmData.CurrAsmList,OP_NEG,OS_S64,
                            r64,r64);
                          cg64.a_load64_reg_loc(CurrentAsmData.CurrAsmList,r64,left.location);
                        end
                      else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                        begin
                          r:=cg.getintregister(CurrentAsmData.CurrAsmList,left.location.size);
                          cg.g_flags2reg(CurrentAsmData.CurrAsmList,left.location.size,right.location.resflags,r);
                          cg.a_reg_dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                          cg.a_op_reg_reg(CurrentAsmData.CurrAsmList,OP_NEG,left.location.size,r,r);
                          hlcg.a_load_reg_loc(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,r,left.location);
                        end
                    end
                  else
                    begin
                      case left.location.loc of
                        LOC_REGISTER,LOC_CREGISTER:
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
                          if left.location.size in [OS_S64,OS_64] then
                            begin
                              cg.g_flags2reg(CurrentAsmData.CurrAsmList,OS_32,right.location.resflags,left.location.register64.reglo);
                              cg.a_reg_dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                              cg.a_load_const_reg(CurrentAsmData.CurrAsmList,OS_32,0,left.location.register64.reghi);
                            end
                          else
{$endif not cpu64bitalu and not cpuhighleveltarget}
                            begin
                              cg.g_flags2reg(CurrentAsmData.CurrAsmList,left.location.size,right.location.resflags,left.location.register);
                              cg.a_reg_dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            end;
                        LOC_CREFERENCE,
                        LOC_REFERENCE:
                        { i8086 and i386 have hacks in their code generators so that they can
                          deal with 64 bit locations in this particular case }
{$if not defined(cpu64bitalu) and not defined(x86) and not defined(cpuhighleveltarget)}
                          if left.location.size in [OS_S64,OS_64] then
                            begin
                              r64.reglo:=cg.getintregister(CurrentAsmData.CurrAsmList,OS_32);
                              r64.reghi:=cg.getintregister(CurrentAsmData.CurrAsmList,OS_32);
                              cg.g_flags2reg(CurrentAsmData.CurrAsmList,OS_32,right.location.resflags,r64.reglo);
                              cg.a_reg_dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                              cg.a_load_const_reg(CurrentAsmData.CurrAsmList,OS_32,0,r64.reghi);
                              cg64.a_load64_reg_ref(CurrentAsmData.CurrAsmList,r64,left.location.reference);
                            end
                          else
{$endif not cpu64bitalu and not x86 and not cpuhighleveltarget}
                            begin
                              cg.g_flags2ref(CurrentAsmData.CurrAsmList,left.location.size,right.location.resflags,left.location.reference);
                              cg.a_reg_dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            end;
                        LOC_CSUBSETREG,LOC_SUBSETREG,LOC_SUBSETREF:
                          begin
                            r:=cg.getintregister(CurrentAsmData.CurrAsmList,left.location.size);
                            cg.g_flags2reg(CurrentAsmData.CurrAsmList,left.location.size,right.location.resflags,r);
                            cg.a_reg_dealloc(CurrentAsmData.CurrAsmList,NR_DEFAULTFLAGS);
                            hlcg.a_load_reg_loc(CurrentAsmData.CurrAsmList,left.resultdef,left.resultdef,r,left.location);
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
          location_freetemp(CurrentAsmData.CurrAsmList,right.location);
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


    procedure TCGArrayConstructorNode.advancearrayoffset(var ref: TReference; elesize: asizeint);
      begin
        ref.alignment:=NewAlignment(ref.alignment,elesize);
        inc(ref.offset,elesize);
      end;


    procedure TCGArrayConstructorNode.pass_generate_code;
      var
        hp    : TArrayConstructorNode;
        href,
        fref  : TReference;
        lt    : TDef;
        paraloc : TCGParaLocation;
        varvtypefield,
        varfield : TFieldVarSym;
        vtype : LongInt;
        eledef: TDef;
        elesize : LongInt;
        tmpreg  : TRegister;
        vaddr : boolean;
        freetemp,
        dovariant: boolean;
      begin
        if is_packed_array(resultdef) then
          InternalError(200608042);
        dovariant:=
          (acnf_forcevaria in arrayconstructornodeflags) or is_variant_array(resultdef);
        eledef:=TArrayDef(resultdef).elementdef;
        elesize:=eledef.size;
        if dovariant then
          varvtypefield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VTYPE'))
        else
          varvtypefield:=nil;
        { alignment is filled in by tg.gethltemp below }
        location_reset_ref(location,LOC_CREFERENCE,OS_NO,0,[]);
        fillchar(paraloc,sizeof(paraloc),0);
        { Allocate always a temp, also if no elements are required, to
          be sure that location is valid (PFV) }
        { on the JVM platform, an array can have 0 elements; since the length
          of the array is part of the array itself, make sure we allocate one
          of the proper length to avoid getting unexpected results later --
          allocating a temp of size 0 also forces it to be size 4 on regular
          targets }
        tg.gethltemp(CurrentAsmData.CurrAsmList,resultdef,(TArrayDef(resultdef).highrange+1)*elesize,tt_normal,location.reference);
        href:=location.reference;
        makearrayref(href,eledef);
        { Process nodes in array constructor }
        hp:=self;
        while Assigned(hp) do
         begin
           if Assigned(hp.left) then
            begin
              freetemp:=true;
              SecondPass(hp.left);
              if (hp.left.location.loc=LOC_JUMP)<>
                 (hp.left.expectloc=LOC_JUMP) then
                InternalError(2007103101);
              { Move flags and jump in register }
              if hp.left.location.loc in [LOC_FLAGS,LOC_JUMP] then
                hlcg.location_force_reg(CurrentAsmData.CurrAsmList,hp.left.location,hp.left.resultdef,hp.left.resultdef,false);

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
                       if is_64bit(lt) then
                         begin
                            case TOrdDef(lt).ordtype of
                              scurrency:
                                begin
                                  vtype:=vtCurrency;
                                  varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VCURRENCY'));
                                end;
                              s64bit:
                                begin
                                  vtype:=vtInt64;
                                  varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VINT64'));
                                end;
                              u64bit:
                                begin
                                  vtype:=vtQWord;
                                  varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VQWORD'));
                                end;
                              else
                                ;
                            end;
                            freetemp:=false;
                            vaddr:=true;
                         end
                       else if (lt.typ=enumdef) or
                           is_integer(lt) then
                         begin
                           vtype:=vtInteger;
                           varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VINTEGER'));
                         end
                       else
                         if is_boolean(lt) then
                           begin
                             vtype:=vtBoolean;
                             varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VINTEGER'));
                           end
                         else
                           if (lt.typ=orddef) then
                             begin
                               case TOrdDef(lt).ordtype of
                                 uchar:
                                   begin
                                     vtype:=vtChar;
                                     varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VINTEGER'));
                                   end;
                                 uwidechar:
                                   begin
                                     vtype:=vtWideChar;
                                     varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VINTEGER'));
                                   end;
                                 else
                                   ;
                               end;
                             end;
                     end;
                   floatdef :
                     begin
                       if is_currency(lt) then
                         begin
                           vtype:=vtCurrency;
                           varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VCURRENCY'));
                         end
                       else
                         begin
                           vtype:=vtExtended;
                           varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VEXTENDED'));
                         end;
                       freetemp:=false;
                       vaddr:=true;
                     end;
                   procvardef,
                   pointerdef :
                     begin
                       if is_pchar(lt) then
                         begin
                           vtype:=vtPChar;
                           varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VPCHAR'));
                         end
                       else if is_pwidechar(lt) then
                         begin
                           vtype:=vtPWideChar;
                           varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VPWIDECHAR'));
                         end
                       else
                         begin
                           vtype:=vtPointer;
                           varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VPOINTER'));
                         end;
                     end;
                   variantdef :
                     begin
                        vtype:=vtVariant;
                        varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VVARIANT'));
                        vaddr:=true;
                        freetemp:=false;
                     end;
                   classrefdef :
                     begin
                       vtype:=vtClass;
                       varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VCLASS'));
                     end;
                   objectdef :
                     if is_interface(lt) then
                       begin
                         vtype:=vtInterface;
                         varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VINTERFACE'));
                       end
                     { vtObject really means a class based on TObject }
                     else if is_class(lt) then
                       begin
                         vtype:=vtObject;
                         varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VOBJECT'));
                       end
                     else
                       InternalError(200505171);
                   stringdef :
                     begin
                       if is_shortstring(lt) then
                        begin
                          vtype:=vtString;
                          varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VSTRING'));
                          vaddr:=true;
                          freetemp:=false;
                        end
                       else
                        if is_ansistring(lt) then
                         begin
                           vtype:=vtAnsiString;
                           varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VANSISTRING'));
                           freetemp:=false;
                         end
                       else
                        if is_widestring(lt) then
                         begin
                           vtype:=vtWideString;
                           varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VWIDESTRING'));
                           freetemp:=false;
                         end
                       else
                        if is_unicodestring(lt) then
                         begin
                           vtype:=vtUnicodeString;
                           varfield:=TFieldVarSym(search_struct_member_no_helper(TRecordDef(eledef),'VUNICODESTRING'));
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
                 hlcg.g_set_addr_nonbitpacked_field_ref(CurrentAsmData.CurrAsmList,TRecordDef(eledef),varfield,fref);
                 if vaddr then
                   begin
                     hlcg.location_force_mem(CurrentAsmData.CurrAsmList,hp.left.location,lt);
                     tmpreg:=hlcg.getaddressregister(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(lt));
                     hlcg.a_loadaddr_ref_reg(CurrentAsmData.CurrAsmList,hp.left.resultdef,CPointerDef.getreusable(lt),hp.left.location.reference,tmpreg);
                     hlcg.a_load_reg_ref(CurrentAsmData.CurrAsmList,CPointerDef.getreusable(lt),varfield.vardef,tmpreg,fref);
                   end
                 else
                   hlcg.a_load_loc_ref(CurrentAsmData.CurrAsmList,hp.left.resultdef,varfield.vardef,hp.left.location,fref);
                 { update href to the vtype field and write it }
                 fref:=href;
                 hlcg.g_set_addr_nonbitpacked_field_ref(CurrentAsmData.CurrAsmList,TRecordDef(eledef),varvtypefield,fref);
                 hlcg.a_load_const_ref(CurrentAsmData.CurrAsmList,varvtypefield.vardef,vtype,fref);
                 { goto next array element }
                 advancearrayoffset(href,elesize);
               end
              else
              { normal array constructor of the same type }
               begin
                 if is_managed_type(resultdef) then
                   freetemp:=false;
                 case hp.left.location.loc of
                   LOC_MMREGISTER,
                   LOC_CMMREGISTER:
                     hlcg.a_loadmm_reg_ref(CurrentAsmData.CurrAsmList,hp.left.resultdef,hp.left.resultdef,
                       hp.left.location.register,href,mms_movescalar);
                   LOC_FPUREGISTER,
                   LOC_CFPUREGISTER :
                     hlcg.a_loadfpu_reg_ref(CurrentAsmData.CurrAsmList,hp.left.resultdef,hp.left.resultdef,hp.left.location.register,href);
                   LOC_REFERENCE,
                   LOC_CREFERENCE :
                     begin
                       if is_shortstring(hp.left.resultdef) then
                         hlcg.g_copyshortstring(CurrentAsmData.CurrAsmList,hp.left.location.reference,href,
                             TStringDef(hp.left.resultdef))
                       else
                         hlcg.g_concatcopy(CurrentAsmData.CurrAsmList,eledef,hp.left.location.reference,href);
                     end;
                   else
                     begin
{$ifndef cpuhighleveltarget}
{$ifdef cpu64bitalu}
                       if hp.left.location.size in [OS_128,OS_S128] then
                         cg128.a_load128_loc_ref(CurrentAsmData.CurrAsmList,hp.left.location,href)
                       else
{$else cpu64bitalu}
                       if hp.left.location.size in [OS_64,OS_S64] then
                         cg64.a_load64_loc_ref(CurrentAsmData.CurrAsmList,hp.left.location,href)
                       else
{$endif cpu64bitalu}
{$endif not cpuhighleveltarget}
                         hlcg.a_load_loc_ref(CurrentAsmData.CurrAsmList,eledef,eledef,hp.left.location,href);
                     end;
                 end;
                 advancearrayoffset(href,elesize);
               end;
              if freetemp then
                location_freetemp(CurrentAsmData.CurrAsmList,hp.left.location);
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

        location_reset_ref(location,LOC_CREFERENCE,OS_NO,sizeof(PInt),[]);
        case rttidatatype of
          rdt_normal:
            location.reference.symbol:=RTTIWriter.get_rtti_label(rttidef,rttitype,indirect);
          rdt_ord2str:
            location.reference.symbol:=RTTIWriter.get_rtti_label_ord2str(rttidef,rttitype,indirect);
          rdt_str2ord:
            location.reference.symbol:=RTTIWriter.get_rtti_label_str2ord(rttidef,rttitype,indirect);
        end;
      end;



begin
   CLoadNode:=TCGLoadNode;
   CAssignmentNode:=TCGAssignmentNode;
   CArrayConstructorNode:=TCGArrayConstructorNode;
   CRTTINode:=TCGRTTINode;
end.
