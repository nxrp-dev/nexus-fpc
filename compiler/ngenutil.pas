{
    Copyright (c) 1998-2011 by Florian Klaempfl

    Generic version of some node tree helper routines that can be overridden
    by cpu-specific versions

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
unit ngenutil;

{$i fpcdefs.inc}

interface

  uses
    cclasses,globtype,
    fmodule,
    aasmbase,aasmdata,
    node,nbas,symtype,symsym,symconst,symdef;


  type
    tinitfinalentry = record
      initfunc : TSymStr;
      finifunc : TSymStr;
      initpd : TProcDef;
      finipd : TProcDef;
      module : tmodule;
    end;
    pinitfinalentry = ^tinitfinalentry;

    tnodeutils = class
      class function call_fail_node:TNode; virtual;
      class function initialize_data_node(p:TNode; force: boolean):TNode; virtual;
      class function finalize_data_node(p:TNode):TNode; virtual;
     strict protected
      type
        tstructinifinipotype = potype_class_constructor..potype_class_destructor;
      class procedure sym_maybe_initialize(p: TObject; arg: pointer);
      { generates the code for finalisation of local variables }
      class procedure local_varsyms_finalize(p:TObject;arg:pointer);
      { generates the code for finalization of static symtable and
        all local (static) typed consts }
      class procedure static_syms_finalize(p: TObject; arg: pointer);
      class procedure sym_maybe_finalize(var stat: tstatementnode; sym: TSym);
      class procedure append_struct_initfinis(u: tmodule; initfini: tstructinifinipotype; var stat: tstatementnode); virtual;
     public
      class procedure procdef_block_add_implicit_initialize_nodes(pd: TProcDef; var stat: tstatementnode);
      class procedure procdef_block_add_implicit_finalize_nodes(pd: TProcDef; var stat: tstatementnode);
      { returns true if the unit requires an initialisation section (e.g.,
        to force class constructors for the JVM target to initialise global
        records/arrays) }
      class function force_init: boolean; virtual;
      { idem for finalization }
      class function force_final: boolean; virtual;

      { if the funcretsym was moved to the parentfpstruct, use this method to
        move its value back back into the funcretsym before the function exit, as
        the code generator is hardcoded to use to use the funcretsym when loading
        the value to be returned; replacing it with an absolutevarsym that
        redirects to the field in the parentfpstruct doesn't work, as the code
        generator cannot deal with such symbols }
       class procedure load_parentfpstruct_nested_funcret(ressym: TSym; resdef: TDef; var stat: tstatementnode);
      { called after parsing a routine with the code of the entire routine
        as argument; can be used to modify the node tree. By default handles
        insertion of code for systems that perform the typed constant
        initialisation via the node tree }
      class function wrap_proc_body(pd: TProcDef; n: TNode): TNode; virtual;

      { trashes a paravarsym or localvarsym if possible (not a managed type,
        "out" in case of parameter, ...) }
      class procedure maybe_trash_variable(var stat: tstatementnode; p: TAbstractNormalVarSym; trashn: TNode); virtual;

      class function  check_insert_trashing(pd: TProcDef): boolean; virtual;
     strict protected
      { called from wrap_proc_body to insert the trashing for the wrapped
        routine's local variables and parameters }
      class function  maybe_insert_trashing(pd: TProcDef; n: TNode): TNode;
      { callback called for every local variable and parameter by
        maybe_insert_trashing(), calls through to maybe_trash_variable() }
      class procedure maybe_trash_variable_callback(p: TObject; statn: pointer);
      { returns whether a particular sym can be trashed. If not,
        maybe_trash_variable won't do anything }
      class function  trashable_sym(p: TSym): boolean; virtual;
      { trashing for 1/2/3/4/8-byte sized variables }
      class procedure trash_small(var stat: tstatementnode; trashn: TNode; trashvaln: TNode); virtual;
      { trashing for differently sized variables that those handled by
        trash_small() }
      class procedure trash_large(var stat: tstatementnode; trashn, sizen: TNode; trashintval: int64); virtual;
      { insert a single bss sym, called by insert bssdata (factored out
        non-common part for llvm) }
      class procedure insertbsssym(list: tasmlist; sym: TStaticVarSym; size: asizeint; varalign: shortint; _typ: Tasmsymtype); virtual;

      { initialization of iso styled program parameters }
      class procedure initialize_filerecs(p : TObject; statn : pointer);
      { finalization of iso styled program parameters }
      class procedure finalize_filerecs(p : TObject; statn : pointer);
     public
      class procedure insertbssdata(sym : TStaticVarSym); virtual;

      class function create_main_procdef(const name: string; potype:TProcTypeOption; ps: TProcSym):TDef; virtual;
      class procedure InsertInitFinalTable(main : tmodule);
     protected
      class procedure InsertRuntimeInits(const prefix:string;list:TLinkedList;unitflag:TModuleFlag); virtual;
      class procedure InsertRuntimeInitsTablesTable(const prefix,tablename:string;unitflag:TModuleFlag); virtual;

      class procedure insert_init_final_table(main: tmodule; entries:tfplist); virtual;

      class function get_init_final_list(main : tmodule): tfplist;
      class procedure release_init_final_list(list:tfplist);
     public
      class procedure InsertThreadvarTablesTable; virtual;
      class procedure InsertThreadvars; virtual;
      class procedure InsertWideInitsTablesTable; virtual;
      class procedure InsertWideInits; virtual;
      class procedure InsertResStrInits; virtual;
      class procedure InsertResStrTablesTable; virtual;
      class procedure InsertResourceTablesTable; virtual;
      class procedure InsertResourceInfo(ResourcesUsed : boolean); virtual;

      class procedure InsertMemorySizes; virtual;

      { Call this to check if init code is required }
      class function has_init_list: boolean; static;

      { called right before an object is assembled, can be used to insert
        global information into the assembler list (used by LLVM to insert type
        info) }
      class procedure InsertObjectInfo; virtual;

      { register that asm symbol sym with type def has to be considered as "used" even if not
        references to it can be found. If compileronly, this is only for the compiler, otherwise
        also for the linker }
      class procedure RegisterUsedAsmSym(sym: TAsmSymbol; def: TDef; compileronly: boolean); virtual;

      class procedure RegisterModuleInitFunction(pd: TProcDef); virtual;
      class procedure RegisterModuleFiniFunction(pd: TProcDef); virtual;

     strict protected
      class procedure add_main_procdef_paras(pd: TDef); virtual;
    end;
    tnodeutilsclass = class of tnodeutils;

  var
    cnodeutils: tnodeutilsclass = tnodeutils;


implementation

    uses
      verbose,version,globals,cutils,constexp,compinnr,
      systems,procinfo,pparautl,
      aasmtai,aasmcnst,
      symbase,symtable,defutil,
      nadd,ncal,ncnv,ncon,nflw,ninl,nld,nmem,nutils,
      ppu,
      pass_1,
      export;

  class function tnodeutils.call_fail_node:TNode;
    var
      para : tcallparanode;
      newstatement : tstatementnode;
      srsym : TSym;
    begin
      result:=internalstatements(newstatement);

      { call fail helper and exit normal }
      if is_class(CurrentStructDef) then
        begin
          srsym:=search_struct_member(CurrentStructDef,'FREEINSTANCE');
          if assigned(srsym) and
             (srsym.typ=procsym) then
            begin
              { if self<>0 and vmt<>0 then freeinstance }
              addstatement(newstatement,cifnode.create(
                  caddnode.create(andn,
                      caddnode.create(unequaln,
                          load_self_pointer_node,
                          cnilnode.create),
                      caddnode.create(unequaln,
                          load_vmt_pointer_node,
                          cnilnode.create)),
                  ccallnode.create(nil,TProcSym(srsym),srsym.owner,load_self_node,[],nil),
                  nil));
            end
          else
            internalerror(2003051002);
        end
      else
        if is_object(CurrentStructDef) then
          begin
            { parameter 3 : vmt_offset }
            { parameter 2 : pointer to vmt }
            { parameter 1 : self pointer }
            para:=ccallparanode.create(
                      cordconstnode.create(TObjectDef(CurrentStructDef).vmt_offset,s32inttype,false),
                  ccallparanode.create(
                      ctypeconvnode.create_internal(
                          load_vmt_pointer_node,
                          voidpointertype),
                  ccallparanode.create(
                      ctypeconvnode.create_internal(
                          load_self_pointer_node,
                          voidpointertype),
                  nil)));
            addstatement(newstatement,
                ccallnode.createintern('fpc_help_fail',para));
          end
      else
        internalerror(200305132);
      { self:=nil }
      addstatement(newstatement,cassignmentnode.create(
          load_self_pointer_node,
          cnilnode.create));
      { exit }
      addstatement(newstatement,cexitnode.create(nil));
    end;


  class function tnodeutils.initialize_data_node(p:TNode; force: boolean):TNode;
    begin
      { prevent initialisation of hidden syms that were moved to
        parentfpstructs: the original symbol isn't used anymore, the version
        in parentfpstruct will be initialised when that struct gets initialised,
        and references to it will actually be translated into references to the
        field in the parentfpstruct (so we'll initialise it twice) }

        begin
          if not assigned(p.resultdef) then
            TypeCheckPass(p);
          if is_ansistring(p.resultdef) or
             is_wide_or_unicode_string(p.resultdef) or
             is_interfacecom_or_dispinterface(p.resultdef) or
             is_dynamic_array(p.resultdef) then
            begin
              result:=cassignmentnode.create(
                 ctypeconvnode.create_internal(p,voidpointertype),
                 cnilnode.create
                 );
            end
          else if (p.resultdef.typ=variantdef) then
            begin
              result:=ccallnode.createintern('fpc_variant_init',
                ccallparanode.create(
                  ctypeconvnode.create_internal(p,search_system_type('TVARDATA').typedef),
                nil));
            end
          else
            begin
              result:=ccallnode.createintern('fpc_initialize',
                    ccallparanode.create(
                        caddrnode.create_internal(
                            crttinode.create(
                                TStoredDef(p.resultdef),initrtti,rdt_normal)),
                    ccallparanode.create(
                        caddrnode.create_internal(p),
                    nil)));
            end;
        end;
    end;


  class function tnodeutils.finalize_data_node(p:TNode):TNode;
    var
      hs : string;
    begin
      { see comment in initialize_data_node above }

        begin
          if not assigned(p.resultdef) then
            TypeCheckPass(p);
          { 'decr_ref' suffix is somewhat misleading, all these helpers
            set the passed pointer to nil now }
          if is_ansistring(p.resultdef) then
            hs:='fpc_ansistr_decr_ref'
          else if is_widestring(p.resultdef) then
            hs:='fpc_widestr_decr_ref'
          else if is_unicodestring(p.resultdef) then
            hs:='fpc_unicodestr_decr_ref'
          else if is_interfacecom_or_dispinterface(p.resultdef) then
            hs:='fpc_intf_decr_ref'
          else
            hs:='';
          if hs<>'' then
            result:=ccallnode.createintern(hs,
               ccallparanode.create(
                 ctypeconvnode.create_internal(p,voidpointertype),
                 nil))
          else if p.resultdef.typ=variantdef then
            begin
              result:=ccallnode.createintern('fpc_variant_clear',
                ccallparanode.create(
                  ctypeconvnode.create_internal(p,search_system_type('TVARDATA').typedef),
                nil));
            end
          else
            result:=ccallnode.createintern('fpc_finalize',
                  ccallparanode.create(
                      caddrnode.create_internal(
                          crttinode.create(
                              TStoredDef(p.resultdef),initrtti,rdt_normal)),
                  ccallparanode.create(
                      caddrnode.create_internal(p),
                  nil)));
        end;
    end;


  class procedure tnodeutils.sym_maybe_initialize(p: TObject; arg: pointer);
    var
      hp : TNode;
    begin
      if ((TSym(p).typ = localvarsym) or
          { check staticvarsym for record management operators and for objects
            which might contain record with management operators }
          ((TSym(p).typ = staticvarsym) and
           (
             is_record(TAbstractVarSym(p).vardef) or
             is_object(TAbstractVarSym(p).vardef)
           )
          )
         ) and
         { local (procedure or unit) variables only need initialization if
           they are used }
         ((TAbstractVarSym(p).refs>0) or
          { managed return symbols must be inited }
          ((TSym(p).typ=localvarsym) and (vo_is_funcret in TLocalVarSym(p).varoptions)) or
          { public managed records with Initialize operator need to be initialized
            even if they aren't referenced in *this* unit }
          (
            (TSym(p).owner.symtabletype=globalsymtable) and
            is_record(TAbstractVarSym(p).vardef) and
            (mop_initialize in TRecordSymTable(TRecordDef(TAbstractVarSym(p).vardef).symtable).managementoperators)
          )
         ) and
         not(vo_is_typed_const in TAbstractVarSym(p).varoptions) and
         not(vo_is_external in TAbstractVarSym(p).varoptions) and
         (
           not (vo_is_default_var in TAbstractVarSym(p).varoptions) or
           (TAbstractVarSym(p).varspez<>vs_const)
         ) and
         (is_managed_type(TAbstractVarSym(p).vardef) or
          ((m_iso in CurrentSettings.modeswitches) and (TAbstractVarSym(p).vardef.typ=filedef))
         ) then
        begin
          hp:=cloadnode.create(TSym(p),TSym(p).owner);
          { ensure that a function reference is not converted to a call }
          include(hp.flags,nf_load_procvar);
          addstatement(tstatementnode(arg^),initialize_data_node(hp,false));
        end;
    end;


  class procedure tnodeutils.local_varsyms_finalize(p: TObject; arg: pointer);
    begin
      if (TSym(p).typ=localvarsym) and
         (TLocalVarSym(p).refs>0) and
         not(vo_is_typed_const in TLocalVarSym(p).varoptions) and
         not(vo_is_external in TLocalVarSym(p).varoptions) and
         not(vo_is_funcret in TLocalVarSym(p).varoptions) and
         (
           not(vo_is_default_var in TAbstractVarSym(p).varoptions) or
           (TAbstractVarSym(p).varspez<>vs_const)
         ) and
         is_managed_type(TLocalVarSym(p).vardef) then
        sym_maybe_finalize(tstatementnode(arg^),TSym(p));
    end;


  class procedure tnodeutils.static_syms_finalize(p: TObject; arg: pointer);
    var
      i : longint;
      pd : TProcDef;
    begin
      case TSym(p).typ of
        staticvarsym :
          begin
            { local (procedure or unit) variables only need finalization
              if they are used
            }
            if ((TStaticVarSym(p).refs>0) or
                { global (unit) variables always need finalization, since
                  they may also be used in another unit
                }
                (TStaticVarSym(p).owner.symtabletype=globalsymtable)) and
                (
                  (TStaticVarSym(p).varspez<>vs_const) or
                  (vo_force_finalize in TStaticVarSym(p).varoptions)
                ) and
               not(vo_is_funcret in TStaticVarSym(p).varoptions) and
               not(vo_is_external in TStaticVarSym(p).varoptions) and
               is_managed_type(TStaticVarSym(p).vardef) and
               not (
                   assigned(TStaticVarSym(p).fieldvarsym) and
                   assigned(TStaticVarSym(p).fieldvarsym.owner.defowner) and
                   (df_generic in TDef(TStaticVarSym(p).fieldvarsym.owner.defowner).defoptions)
                 )
               then
              sym_maybe_finalize(tstatementnode(arg^),TSym(p));
          end;
        procsym :
          begin
            for i:=0 to TProcSym(p).ProcdefList.Count-1 do
              begin
                pd:=TProcDef(TProcSym(p).ProcdefList[i]);
                if assigned(pd.localst) and
                   (pd.procsym=TProcSym(p)) and
                   (pd.localst.symtabletype<>staticsymtable) then
                  pd.localst.SymList.ForEachCall(@static_syms_finalize,arg);
              end;
          end;
        else
          ;
      end;
    end;


  class procedure tnodeutils.sym_maybe_finalize(var stat: tstatementnode; sym: TSym);
    var
      hp: TNode;
    begin
      include(CurrentProcInfo.flags,pi_needs_implicit_finally);
      hp:=cloadnode.create(sym,sym.owner);
      if (sym.typ=staticvarsym) and (vo_force_finalize in TStaticVarSym(sym).varoptions) then
        include(tloadnode(hp).loadnodeflags,loadnf_isinternal_ignoreconst);
      { ensure that a function reference interface is not converted to a call }
      include(hp.flags,nf_load_procvar);
      addstatement(stat,finalize_data_node(hp));
    end;


  procedure AddToStructInits(p:TObject;arg:pointer);
    var
      StructList: TFPList absolute arg;
    begin
      if (TDef(p).typ in [objectdef,recorddef]) and
         not (df_generic in TDef(p).defoptions) then
        begin
          { first add the class... }
          if ([oo_has_class_constructor,oo_has_class_destructor] * TAbstractRecordDef(p).objectoptions <> []) then
            StructList.Add(p);
          { ... and then also add all subclasses }
          TAbstractRecordDef(p).symtable.deflist.foreachcall(@AddToStructInits,arg);
        end;
    end;


  class procedure tnodeutils.append_struct_initfinis(u: tmodule; initfini: tstructinifinipotype; var stat: tstatementnode);
    var
      structlist: tfplist;
      i: integer;
      pd: TProcDef;
    begin
      structlist:=tfplist.Create;
      if assigned(u.globalsymtable) then
        u.globalsymtable.DefList.ForEachCall(@AddToStructInits,structlist);
      u.localsymtable.DefList.ForEachCall(@AddToStructInits,structlist);
      { write structures }
      for i:=0 to structlist.Count-1 do
        begin
          pd:=TAbstractRecordDef(structlist[i]).find_procdef_bytype(initfini);
          if assigned(pd) then
            begin
              { class constructors are private -> ignore visibility checks }
              addstatement(stat,
                ccallnode.create(nil,TProcSym(pd.procsym),pd.owner,nil,[cnf_ignore_visibility],nil))
            end;
        end;
      structlist.free;
      structlist := nil;
    end;


  class procedure tnodeutils.procdef_block_add_implicit_initialize_nodes(pd: TProcDef; var stat: tstatementnode);
    begin
      { initialize local data like ansistrings }
      case pd.proctypeoption of
         potype_unitinit:
           begin
             { this is also used for initialization of variables in a
               program which does not have a globalsymtable }
             if assigned(CurrentModule.globalsymtable) then
               TSymTable(CurrentModule.globalsymtable).SymList.ForEachCall(@sym_maybe_initialize,@stat);
             TSymTable(CurrentModule.localsymtable).SymList.ForEachCall(@sym_maybe_initialize,@stat);
             { insert class constructors  }
             if mf_classinits in CurrentModule.moduleflags then
               append_struct_initfinis(CurrentModule, potype_class_constructor, stat);
           end;
         { units have separate code for initialization and finalization }
         potype_unitfinalize: ;
         { program init/final is generated in separate procedure }
         potype_proginit: ;
         else
           CurrentProcInfo.procdef.localst.SymList.ForEachCall(@sym_maybe_initialize,@stat);
      end;
    end;


  class procedure tnodeutils.procdef_block_add_implicit_finalize_nodes(pd: TProcDef; var stat: tstatementnode);
    begin
      { no finalization in exceptfilters, they /are/ the finalization code }
      if CurrentProcInfo.procdef.proctypeoption=potype_exceptfilter then
          exit;

      { finalize local data like ansistrings}
      case CurrentProcInfo.procdef.proctypeoption of
         potype_unitfinalize:
           begin
             { insert class destructors  }
             if mf_classinits in CurrentModule.moduleflags then
               append_struct_initfinis(CurrentModule, potype_class_destructor, stat);
             { this is also used for initialization of variables in a
               program which does not have a globalsymtable }
             if assigned(CurrentModule.globalsymtable) then
               TSymTable(CurrentModule.globalsymtable).SymList.ForEachCall(@static_syms_finalize,@stat);
             TSymTable(CurrentModule.localsymtable).SymList.ForEachCall(@static_syms_finalize,@stat);
           end;
         { units/progs have separate code for initialization and finalization }
         potype_unitinit: ;
         { program init/final is generated in separate procedure }
         potype_proginit: ;
         else
           CurrentProcInfo.procdef.localst.SymList.ForEachCall(@local_varsyms_finalize,@stat);
      end;
    end;


  class function tnodeutils.force_init: boolean;
    begin
      result:=false;
    end;


  class function tnodeutils.force_final: boolean;
    begin
      result:=false;
    end;


  class procedure tnodeutils.initialize_filerecs(p:TObject;statn:pointer);
    var
      stat: ^tstatementnode absolute statn;
    begin
      if (TSym(p).typ=staticvarsym) and
        (TStaticVarSym(p).vardef.typ=filedef) and
        (TStaticVarSym(p).isoindex<>0) then
        case TFileDef(TStaticVarSym(p).vardef).filetyp of
          ft_text:
            begin
              if cs_transparent_file_names in CurrentSettings.globalswitches then
                addstatement(stat^,ccallnode.createintern('fpc_textinit_filename_iso',
                  ccallparanode.create(
                    cstringconstnode.createstr(TStaticVarSym(p).Name),
                  ccallparanode.create(
                    cordconstnode.create(TStaticVarSym(p).isoindex,uinttype,false),
                  ccallparanode.create(
                    cloadnode.create(TStaticVarSym(p),TStaticVarSym(p).Owner),
                  nil)))))
              else
                addstatement(stat^,ccallnode.createintern('fpc_textinit_iso',
                  ccallparanode.create(
                    cordconstnode.create(TStaticVarSym(p).isoindex,uinttype,false),
                  ccallparanode.create(
                    cloadnode.create(TStaticVarSym(p),TStaticVarSym(p).Owner),
                  nil))));
            end;
          ft_typed:
            begin
              if cs_transparent_file_names in CurrentSettings.globalswitches then
                addstatement(stat^,ccallnode.createintern('fpc_typedfile_init_filename_iso',
                  ccallparanode.create(
                    cstringconstnode.createstr(TStaticVarSym(p).Name),
                  ccallparanode.create(
                    cordconstnode.create(TStaticVarSym(p).isoindex,uinttype,false),
                  ccallparanode.create(
                    cloadnode.create(TStaticVarSym(p),TStaticVarSym(p).Owner),
                  nil)))))
              else
                addstatement(stat^,ccallnode.createintern('fpc_typedfile_init_iso',
                  ccallparanode.create(
                    cordconstnode.create(TStaticVarSym(p).isoindex,uinttype,false),
                  ccallparanode.create(
                    cloadnode.create(TStaticVarSym(p),TStaticVarSym(p).Owner),
                  nil))));
            end;
          else
            ;
        end;
    end;


  class procedure tnodeutils.finalize_filerecs(p:TObject;statn:pointer);
    var
      stat: ^tstatementnode absolute statn;
    begin
      if (TSym(p).typ=staticvarsym) and
        (TStaticVarSym(p).vardef.typ=filedef) and
        (TStaticVarSym(p).isoindex<>0) then
        case TFileDef(TStaticVarSym(p).vardef).filetyp of
          ft_text:
            begin
              addstatement(stat^,ccallnode.createintern('fpc_textclose_iso',
                ccallparanode.create(
                  cloadnode.create(TStaticVarSym(p),TStaticVarSym(p).Owner),
                nil)));
            end;
          ft_typed:
            begin
              addstatement(stat^,ccallnode.createintern('fpc_typedfile_close_iso',
                ccallparanode.create(
                  cloadnode.create(TStaticVarSym(p),TStaticVarSym(p).Owner),
                nil)));
            end;
          else
            ;
        end;
    end;


  class procedure tnodeutils.load_parentfpstruct_nested_funcret(ressym: TSym; resdef: TDef; var stat: tstatementnode);
    var
      src, target: tloadnode;
    begin
      target:=cloadnode.create(ressym, ressym.owner);
      { ensure the target of this assignment doesn't translate the
        funcretsym also to its alias in the parentfpstruct }
      include(target.flags, nf_internal);
      src:=cloadnode.create(ressym, ressym.owner);
      if TAbstractNormalVarSym(ressym).vardef<>resdef then
        begin
          { the resultdef of TP-style object constructors is the object itself,
            but in practice they return a pointer to the object (the self
            pointer) }
          if (resdef.typ<>pointerdef) or
             (TPointerDef(resdef).pointeddef<>TAbstractNormalVarSym(ressym).vardef) then
            internalerror(2026072310);
          include(src.loadnodeflags, loadnf_load_addr);
          include(target.loadnodeflags, loadnf_load_addr);
        end;

      addstatement(stat,
        cassignmentnode.create(target,src)
      );
    end;


  class function tnodeutils.wrap_proc_body(pd: TProcDef; n: TNode): TNode;
    var
      stat: tstatementnode;
      block: TNode;
      ressym: TSym;
      resdef: TDef;
    begin
      result:=maybe_insert_trashing(pd,n);

      { initialise safecall result variable }
      if pd.generate_safecall_wrapper then
        begin
          ressym:=TSym(pd.localst.Find('safecallresult'));
          block:=internalstatements(stat);
          addstatement(stat,
            cassignmentnode.create(
              cloadnode.create(ressym,ressym.owner),
              genintconstnode(0)
            )
          );
          addstatement(stat,result);
          result:=block;
        end;

      if (m_isolike_program_para in CurrentSettings.modeswitches) and
        (pd.proctypeoption=potype_proginit) then
        begin
          block:=internalstatements(stat);
          pd.localst.SymList.ForEachCall(@initialize_filerecs,@stat);
          addstatement(stat,result);
          pd.localst.SymList.ForEachCall(@finalize_filerecs,@stat);
          result:=block;
        end;


    end;


  class function tnodeutils.maybe_insert_trashing(pd: TProcDef; n: TNode): TNode;
    var
      stat: tstatementnode;
    begin
      result:=n;
      if check_insert_trashing(pd) then
        begin
          result:=internalstatements(stat);
          pd.parast.SymList.ForEachCall(@maybe_trash_variable_callback,@stat);
          pd.localst.SymList.ForEachCall(@maybe_trash_variable_callback,@stat);
          addstatement(stat,n);
        end;
    end;

  class function tnodeutils.check_insert_trashing(pd: TProcDef): boolean;
    begin
      result:=
        (localvartrashing<>-1) and
        not(po_assembler in pd.procoptions);
    end;


  class function tnodeutils.trashable_sym(p: TSym): boolean;
    begin
      result:=
        ((p.typ=localvarsym) or
         ((p.typ=paravarsym) and
          ((vo_is_funcret in TAbstractNormalVarSym(p).varoptions) or
           (TAbstractNormalVarSym(p).varspez=vs_out)))) and
         not (vo_is_default_var in TAbstractNormalVarSym(p).varoptions) and
         (not is_managed_type(TAbstractNormalVarSym(p).vardef) or
          (is_string(TAbstractNormalVarSym(p).vardef) and
           (vo_is_funcret in TAbstractNormalVarSym(p).varoptions)
          )
         ) and
         (TAbstractNormalVarSym(p).varoptions*[vo_is_parentfp,vo_is_internal]=[]) and
         not assigned(TAbstractNormalVarSym(p).defaultconstsym);
    end;


  class procedure tnodeutils.maybe_trash_variable(var stat: tstatementnode; p: TAbstractNormalVarSym; trashn: TNode);
    var
      size: asizeint;
      trashintval: int64;
      stringres: tstringconstnode;
    begin
      if trashable_sym(p) then
        begin
          trashintval:=trashintvalues[localvartrashing];
          if (p.vardef.typ=procvardef) and
             ([m_tp_procvar,m_mac_procvar]*CurrentSettings.modeswitches<>[]) then
            begin
              if TProcVarDef(p.vardef).is_addressonly then
                { in tp/delphi mode, you need @procvar to get at the contents of
                  a procvar ... }
                trashn:=caddrnode.create(trashn)
              else
                { ... but if it's a procedure of object, that will only return
                  the procedure address -> cast to tmethod instead }
                trashn:=ctypeconvnode.create_explicit(trashn,methodpointertype);
            end;
          if is_managed_type(p.vardef) then
            begin
              if is_string(p.vardef) then
                begin
                  stringres:=
                    cstringconstnode.createstr(
                      'uninitialized function result in '+
                      TProcDef(p.owner.defowner).customprocname([pno_proctypeoption, pno_paranames,pno_ownername, pno_noclassmarker])
                    );
                  { prevent attempts to convert the string to the specified
                    code page at compile time, as it may not be available (and
                    it does not matter) }
                  if is_ansistring(p.vardef) then
                    stringres.changestringtype(search_system_type('RAWBYTESTRING').typedef);
                  trash_small(stat,trashn,stringres);
                end
              else
                internalerror(2016030601);
            end
          else if ((p.typ=localvarsym) and
              (not(vo_is_funcret in p.varoptions) or
               not is_shortstring(p.vardef))) or
             ((p.typ=paravarsym) and
              not is_shortstring(p.vardef)) then
            begin
              size:=p.getsize;
              case size of
                0:
                  begin
                    { open array -> at least size 1. Can also be zero-sized
                      record, so check it's actually an array }
                    if p.vardef.typ=arraydef then
                      trash_large(stat,trashn,caddnode.create(addn,cinlinenode.create(in_high_x,false,trashn.getcopy),genintconstnode(1)),trashintval)
                    else
                      trashn.free;
                      trashn := nil;
                  end;
                1: trash_small(stat,
                  ctypeconvnode.create_internal(trashn,s8inttype),
                    genintconstnode(shortint(trashintval)));
                2: trash_small(stat,
                  ctypeconvnode.create_internal(trashn,s16inttype),
                    genintconstnode(smallint(trashintval)));
                4: trash_small(stat,
                  ctypeconvnode.create_internal(trashn,s32inttype),
                    genintconstnode(longint(trashintval)));
                8: trash_small(stat,
                  ctypeconvnode.create_internal(trashn,s64inttype),
                    genintconstnode(int64(trashintval)));
                else
                  trash_large(stat,trashn,genintconstnode(size),trashintval);
              end;
            end
          else
            begin
              { may be an open string, even if is_open_string() returns false
                (for some helpers in the system unit)             }
              { an open string has at least size 2                      }
              trash_small(stat,
                cvecnode.create(trashn.getcopy,genintconstnode(0)),
                cordconstnode.create(tconstexprint(byte(trashintval)),cansichartype,false));
              trash_small(stat,
                cvecnode.create(trashn,genintconstnode(1)),
                cordconstnode.create(tconstexprint(byte(trashintval)),cansichartype,false));
            end;
        end
      else
        trashn.free;
        trashn := nil;
    end;


  class procedure tnodeutils.maybe_trash_variable_callback(p:TObject;statn:pointer);
    var
      stat: ^tstatementnode absolute statn;
    begin
      if not(TSym(p).typ in [localvarsym,paravarsym]) then
        exit;
      if sp_internal in TSym(p).symoptions then
        exit;
      maybe_trash_variable(stat^,TAbstractNormalVarSym(p),cloadnode.create(TSym(p),TSym(p).owner));
    end;


  class procedure tnodeutils.trash_small(var stat: tstatementnode; trashn: TNode; trashvaln: TNode);
    begin
      addstatement(stat,cassignmentnode.create(trashn,trashvaln));
    end;


  class procedure tnodeutils.trash_large(var stat: tstatementnode; trashn, sizen: TNode; trashintval: int64);
    begin
      addstatement(stat,ccallnode.createintern('fpc_fillmem',
        ccallparanode.Create(cordconstnode.create(tconstexprint(byte(trashintval)),u8inttype,false),
        ccallparanode.Create(sizen,
        ccallparanode.Create(trashn,nil)))
        ));
    end;


  class procedure tnodeutils.insertbsssym(list: tasmlist; sym: TStaticVarSym; size: asizeint; varalign: shortint; _typ:Tasmsymtype);
    begin
      if sym.globalasmsym then
        begin
          { on AIX/stabx, we cannot generate debug information that encodes
            the address of a global symbol, you need a symbol with the same
            name as the identifier -> create an extra *local* symbol.
            Moreover, such a local symbol will be removed if it's not
            referenced anywhere, so also create a reference }
          if (TargetDbg.id=dbg_stabx) and
             (cs_debuginfo in CurrentSettings.moduleswitches) and
             not assigned(CurrentAsmData.GetAsmSymbol(sym.name)) then
            begin
              list.concat(tai_symbol.Create(CurrentAsmData.DefineAsmSymbol(sym.name,AB_LOCAL,AT_DATA,sym.vardef),0));
              list.concat(tai_directive.Create(asd_reference,sym.name));
            end;
          list.concat(Tai_datablock.create_global(sym.mangledname,size,sym.vardef,_typ));
        end
      else
        list.concat(Tai_datablock.create_hidden(sym.mangledname,size,sym.vardef,_typ));
    end;


  class procedure tnodeutils.insertbssdata(sym: TStaticVarSym);
    var
      l : asizeint;
      varalign,wantedalign,explicitalign : shortint;
      storefilepos : TFilePosInfo;
      list : TAsmList;
      sectype : TAsmSectiontype;
      asmtype: TAsmsymtype;
      builder: ttai_typedconstbuilder;
      descriptor: TDef;
      descriptorbind: TAsmsymbind;
    begin
      storefilepos:=CurrentFilePos;
      CurrentFilePos:=sym.fileinfo;
      l:=sym.getsize;
      wantedalign:=sym.vardef.alignment;
      if sym.vardef.inheritsfrom(TAbstractRecordDef) and
         (sym.vardef.typ in [recorddef]) then
        explicitalign:=TAbstractRecordSymTable(TAbstractRecordDef(sym.vardef).symtable).explicitrecordalignment
      else
        explicitalign:=0;
      if (wantedalign=0) then
        varalign:=var_align_size(l)
      else
        begin
          varalign:=var_align(wantedalign);
          if (explicitalign>varalign) then
            begin
              Message1(scanner_w_alignment_larger_than_max,sym.name);
              varalign:=explicitalign;
            end
          else if (wantedalign>varalign) and (TargetInfo.alignment.varalignmax>1) then
            begin
              { varalign:=wantedalign; this can lead to
                troubles on systems like for instance
                msdos which do not support 8-byte alignment }
              Message1(scanner_n_alignment_larger_than_max,sym.name);
	    end;
	end;
      asmtype:=AT_DATA;
      if tf_section_threadvars in TargetInfo.flags then
        begin
          if (vo_is_thread_var in sym.varoptions) then
            begin
              list:=CurrentAsmData.asmlists[al_threadvars];
              sectype:=sec_threadvar;
              asmtype:=AT_TLS;
            end
          else
            begin
              list:=CurrentAsmData.asmlists[al_globals];
              sectype:=sec_bss;
            end;
        end
      else
        begin
          if (vo_is_thread_var in sym.varoptions) then
            begin
              { The exported symbol is a two-word descriptor, never storage. }
              builder:=ctai_typedconstbuilder.create([tcalo_make_dead_strippable,tcalo_new_section]);
              builder.begin_anonymous_record('',sizeof(pint),sizeof(pint),sizeof(pint));
              builder.emit_tai(tai_const.Createname('FPC_THREADVAROWNER',0),voidpointertype);
              builder.emit_ord_const(0,sizeuinttype);
              descriptor:=builder.end_anonymous_record;
              if sym.globalasmsym then
                descriptorbind:=AB_GLOBAL
              else if tf_supports_hidden_symbols in TargetInfo.flags then
                descriptorbind:=AB_PRIVATE_EXTERN
              else
                descriptorbind:=AB_LOCAL;
              CurrentAsmData.asmlists[al_globals].concatlist(builder.get_final_asmlist(
                CurrentAsmData.DefineAsmSymbol(sym.mangledname,descriptorbind,AT_DATA,descriptor),
                descriptor,sec_data,lower(sym.mangledname),sizeof(pint)));
              builder.free;
              CurrentFilePos:=storefilepos;
              exit;
            end;
          list:=CurrentAsmData.asmlists[al_globals];
          sectype:=sec_bss;
        end;
      maybe_new_object_file(list);
      if vo_has_section in sym.varoptions then
        new_section(list,sec_user,sym.section,varalign)
      else
        new_section(list,sectype,lower(sym.mangledname),varalign);
      insertbsssym(list,sym,l,varalign,asmtype);
      CurrentFilePos:=storefilepos;
    end;


  class function tnodeutils.create_main_procdef(const name: string; potype: TProcTypeOption; ps: TProcSym): TDef;
    var
      pd: TProcDef;
    begin
      if potype<>potype_mainstub then
        pd:=cprocdef.create(main_program_level,true)
      else
        pd:=cprocdef.create(normal_function_level,true);
      { always register the def }
      pd.RegisterDef;
      pd.procsym:=ps;
      ps.ProcdefList.Add(pd);
      include(pd.procoptions,po_global);
      { set procdef options }
      pd.proctypeoption:=potype;
      pd.proccalloption:=pocall_default;
      include(pd.procoptions,po_hascallingconvention);
      pd.forwarddef:=false;
      { may be required to calculate the mangled name }
      add_main_procdef_paras(pd);
      pd.setmangledname(name);
      { the mainstub is generated via a synthetic proc -> parsed via
        psub.read_proc_body() -> that one will insert the mangled name in the
        alias names already }
      if not(potype in [potype_mainstub,potype_libmainstub]) then
        pd.aliasnames.insert(pd.mangledname);
      result:=pd;
    end;


  class function tnodeutils.get_init_final_list(main : tmodule):tfplist;

    procedure addusedunits(m : tmodule);

    var
      hp : tused_unit;
      entry : pinitfinalentry;
    begin
      hp:=tused_unit(m.used_units.first);
      while assigned(hp) do
       begin
         if (not hp.u.initfinalchecked) then
           begin
           hp.u.initfinalchecked:=True;
           addusedunits(hp.u);
           if not assigned(hp.u.package) and
              ((hp.u.moduleflags * [mf_init,mf_finalize])<>[]) then
             begin
               new(entry);
               entry^.module:=hp.u;
               entry^.initpd:=nil;
               entry^.finipd:=nil;
               if mf_init in hp.u.moduleflags then
                 entry^.initfunc:=make_mangledname('INIT$',hp.u.globalsymtable,'')
               else
                 entry^.initfunc:='';
               if mf_finalize in hp.u.moduleflags then
                 entry^.finifunc:=make_mangledname('FINALIZE$',hp.u.globalsymtable,'')
               else
                 entry^.finifunc:='';
               result.add(entry);
             end;
           end;
         hp:=tused_unit(hp.next);
       end;

    end;

    var
      entry : pinitfinalentry;
    begin
      result:=tfplist.create;

      { Insert initialization/finalization of the used units }
      addusedunits(main);

      { Insert initialization/finalization of the program }
      if (main.moduleflags * [mf_init,mf_finalize])<>[] then
        begin
          new(entry);
          entry^.module:=CurrentModule;
          entry^.initpd:=nil;
          entry^.finipd:=nil;
          if mf_init in CurrentModule.moduleflags then
            entry^.initfunc:=make_mangledname('INIT$',CurrentModule.localsymtable,'')
          else
            entry^.initfunc:='';
          if mf_finalize in CurrentModule.moduleflags then
            entry^.finifunc:=make_mangledname('FINALIZE$',CurrentModule.localsymtable,'')
          else
            entry^.finifunc:='';
          result.add(entry);
        end;
    end;


  class procedure tnodeutils.release_init_final_list(list:tfplist);
    begin
      if not assigned(list) then
        internalerror(2017051901);
      TFPList.FreeAndNilDisposing(list,typeinfo(tinitfinalentry));
    end;


  class procedure tnodeutils.InsertInitFinalTable(main : tmodule);
    var
      entries : tfplist;
    begin
      entries := get_init_final_list(main);

      insert_init_final_table(main,entries);

      release_init_final_list(entries);
    end;


  class procedure tnodeutils.insert_init_final_table(main : tmodule; entries:tfplist);
    var
      i : longint;
      unitinits : ttai_typedconstbuilder;
      nameinit,namefini : TSymStr;
      tabledef: TDef;
      entry : pinitfinalentry;
      unitnametcb : ttai_typedconstbuilder;
      unitnamedef : TDef;
      unitnamelbl : tasmlabel;

      procedure add_initfinal_import(symtable:TSymTable);
        var
          i,j : longint;
          foundinit,foundfini : boolean;
          sym : TSymEntry;
          pd : TProcDef;
        begin
          if (nameinit='') and (namefini='') then
            exit;
          foundinit:=nameinit='';
          foundfini:=namefini='';
          for i:=0 to symtable.SymList.Count-1 do
            begin
              sym:=tsymentry(symtable.SymList[i]);
              if sym.typ<>procsym then
                continue;
              for j:=0 to TProcSym(sym).procdeflist.count-1 do
                begin
                  pd:=TProcDef(TProcSym(sym).procdeflist[j]);
                  if (nameinit<>'') and not foundinit and pd.has_alias_name(nameinit) then
                    begin
                      CurrentModule.addimportedsym(sym);
                      foundinit:=true;
                    end;
                  if (namefini<>'') and not foundfini and pd.has_alias_name(namefini) then
                    begin
                      CurrentModule.addimportedsym(sym);
                      foundfini:=true;
                    end;
                  if foundinit and foundfini then
                    break;
                end;
              if foundinit and foundfini then
                break;
            end;
          if not foundinit or not foundfini then
            internalerror(2016041401);
        end;

    begin
      unitinits:=ctai_typedconstbuilder.create([tcalo_make_dead_strippable,tcalo_new_section]);
      unitinits.begin_anonymous_record('',default_settings.packrecords,sizeof(pint),
        targetinfos[Ord(TargetInfo.system)]^.alignment.recordalignmin);

      { tablecount }
      unitinits.emit_ord_const(entries.count,aluuinttype);
      { initcount (initialised at run time }
      unitinits.emit_ord_const(0,aluuinttype);

      for i:=0 to entries.count-1 do
        begin
          entry:=pinitfinalentry(entries[i]);
          if assigned(entry^.initpd) or assigned(entry^.finipd) then
            begin
              if assigned(entry^.initpd) then
                begin
                  unitinits.emit_procdef_const(entry^.initpd);
                  if entry^.module<>CurrentModule then
                    CurrentModule.addimportedsym(entry^.initpd.procsym);
                end
              else
                unitinits.emit_tai(Tai_const.Create_nil_codeptr,voidcodepointertype);
              if assigned(entry^.finipd) then
                begin
                  unitinits.emit_procdef_const(entry^.finipd);
                  if entry^.module<>CurrentModule then
                    CurrentModule.addimportedsym(entry^.finipd.procsym);
                end
              else
                unitinits.emit_tai(Tai_const.Create_nil_codeptr,voidcodepointertype);
            end
          else
            begin
              nameinit:='';
              namefini:='';
              if entry^.initfunc<>'' then
                begin
                  nameinit:=entry^.initfunc;
                  unitinits.emit_tai(
                    Tai_const.Createname(nameinit,AT_FUNCTION,0),
                    voidcodepointertype);
                end
              else
                unitinits.emit_tai(Tai_const.Create_nil_codeptr,voidcodepointertype);
              if entry^.finifunc<>'' then
                begin
                  namefini:=entry^.finifunc;
                  unitinits.emit_tai(
                    Tai_const.Createname(namefini,AT_FUNCTION,0),
                    voidcodepointertype);
                end
              else
                unitinits.emit_tai(Tai_const.Create_nil_codeptr,voidcodepointertype);
              if entry^.module<>CurrentModule then
                add_initfinal_import(entry^.module.localsymtable);
            end;
          { Add pointer to unit name }
          if assigned(entry^.module.realmodulename) then
            begin
              { Create string constant and emit pointer to it }
              unitinits.start_internal_data_builder(CurrentAsmData.asmlists[al_globals],sec_rodata,'',unitnametcb,unitnamelbl);
              unitnamedef:=unitnametcb.emit_shortstring_const(entry^.module.realmodulename^);
              unitinits.finish_internal_data_builder(unitnametcb,unitnamelbl,unitnamedef,sizeof(pint));
              unitinits.queue_init(charpointertype);
              unitinits.queue_emit_asmsym(unitnamelbl,unitnamedef);
            end
          else
            unitinits.emit_tai(Tai_const.Create_nil_dataptr,charpointertype);
        end;

      { Add to data segment }
      tabledef:=unitinits.end_anonymous_record;
      CurrentAsmData.asmlists[al_globals].concatlist(
        unitinits.get_final_asmlist(
          CurrentAsmData.DefineAsmSymbol('INITFINAL',AB_GLOBAL,AT_DATA,tabledef),
          tabledef,
          sec_data,'INITFINAL',const_align(sizeof(pint))
        )
      );

      unitinits.free;
      unitinits := nil;
    end;


  class function tnodeutils.has_init_list: boolean;
    var
      hp : tused_unit;
    begin
      Result:=True;

      { Check current module first }
      if mf_init in CurrentModule.moduleflags then
        Exit;

      { Check used units }
      hp:=tused_unit(usedunits.first);
      while assigned(hp) do
        begin
          if mf_init in hp.u.moduleflags then
            Exit;
          hp:=tused_unit(hp.next);
        end;

      { We reach this point, none of the used units have an initialisation list }
      Result:=False;
    end;


  class procedure tnodeutils.InsertThreadvarTablesTable;
    var
      hp : tused_unit;
      tcb: ttai_typedconstbuilder;
      count: longint;
      sym: tasmsymbol;
      placeholder: ttypedconstplaceholder;
      tabledef: TDef;
      ownerbind: TAsmsymbind;
    begin
      if (tf_section_threadvars in TargetInfo.flags) then
        exit;
      count:=0;
      tcb:=ctai_typedconstbuilder.create([tcalo_make_dead_strippable,tcalo_new_section]);
      tcb.begin_anonymous_record('',default_settings.packrecords,voidpointertype.alignment,targetinfos[Ord(TargetInfo.system)]^.alignment.recordalignmin);
      placeholder:=tcb.emit_placeholder(sizesinttype);

      hp:=tused_unit(usedunits.first);
      while assigned(hp) do
       begin
         if not assigned(hp.u.package) and (mf_threadvars in hp.u.moduleflags) then
           begin
             sym:=CurrentAsmData.RefAsmSymbol(make_mangledname('THREADVARLIST',hp.u.globalsymtable,''),AT_DATA,true);
             tcb.emit_tai(
               tai_const.Create_sym(sym),
               voidpointertype);
             CurrentModule.add_extern_asmsym(sym);
             inc(count);
           end;
         hp:=tused_unit(hp.next);
       end;
      { Add program threadvars, if any }
      if mf_threadvars in CurrentModule.moduleflags then
        begin
          sym:=CurrentAsmData.RefAsmSymbol(make_mangledname('THREADVARLIST',CurrentModule.localsymtable,''),AT_DATA,true);
          tcb.emit_tai(
            Tai_const.Create_sym(sym),
            voidpointertype);
          inc(count);
        end;
      { set the count at the start }
      placeholder.replace(tai_const.Create_sizeint(count),sizesinttype);
      placeholder.free;
      placeholder := nil;
      { insert in data segment }
      tabledef:=tcb.end_anonymous_record;
      if tf_supports_hidden_symbols in TargetInfo.flags then
        ownerbind:=AB_PRIVATE_EXTERN
      else
        ownerbind:=AB_GLOBAL;
      sym:=CurrentAsmData.DefineAsmSymbol('FPC_THREADVARTABLES',ownerbind,AT_DATA,tabledef);
      CurrentAsmData.asmlists[al_globals].concatlist(
        tcb.get_final_asmlist(
          sym,tabledef,sec_data,'FPC_THREADVARTABLES',const_align(sizeof(pint))
        )
      );
      tcb.free;
      { All unit objects bind this local image owner at final link time. }
      tcb:=ctai_typedconstbuilder.create([tcalo_make_dead_strippable,tcalo_new_section]);
      tcb.begin_anonymous_record('',sizeof(pint),sizeof(pint),sizeof(pint));
      tcb.emit_tai(tai_const.Createname('FPC_THREADVARTABLES',0),voidpointertype);
      tcb.emit_ord_const(0,sizeuinttype); { runtime identity }
      tcb.emit_ord_const(0,sizeuinttype); { block size }
      tcb.emit_ord_const(0,sizeuinttype); { block alignment }
      tcb.emit_tai(tai_const.Create_nil_dataptr,voidpointertype); { main context debugger view }
      tabledef:=tcb.end_anonymous_record;
      CurrentAsmData.asmlists[al_globals].concatlist(tcb.get_final_asmlist(
        CurrentAsmData.DefineAsmSymbol('FPC_THREADVAROWNER',ownerbind,AT_DATA,tabledef),
        tabledef,sec_data,'FPC_THREADVAROWNER',sizeof(pint)));
      tcb.free;
      tcb := nil;
    end;



  procedure AddToThreadvarList(p:TObject;arg:pointer);
    var
      tcb: ttai_typedconstbuilder;
      def: TDef;
      alignment: shortint;
    begin
      if (TSym(p).typ=staticvarsym) and
         (vo_is_thread_var in TStaticVarSym(p).varoptions) then
       begin
         tcb:=ttai_typedconstbuilder(arg);
         def:=TStaticVarSym(p).vardef;
         alignment:=def.alignment;
         if (def.typ=recorddef) and
            (TAbstractRecordSymTable(TRecordDef(def).symtable).explicitrecordalignment>alignment) then
           alignment:=TAbstractRecordSymTable(TRecordDef(def).symtable).explicitrecordalignment;
         tcb.emit_tai(tai_const.Createname(TStaticVarSym(p).mangledname,0),voidpointertype);
         tcb.emit_ord_const(TStaticVarSym(p).getsize,sizeuinttype);
         tcb.emit_ord_const(alignment,sizeuinttype);
       end;
    end;


  class procedure tnodeutils.InsertThreadvars;
    var
      s : TSymStr;
      tcb: ttai_typedconstbuilder;
      sym: tasmsymbol;
      tabledef: TRecordDef;
      add : boolean;
    begin
       if (tf_section_threadvars in TargetInfo.flags) then
         exit;
       tcb:=ctai_typedconstbuilder.create([tcalo_make_dead_strippable,tcalo_new_section]);
       tabledef:=tcb.begin_anonymous_record('',default_settings.packrecords,voidpointertype.alignment,targetinfos[Ord(TargetInfo.system)]^.alignment.recordalignmin);
       if assigned(CurrentModule.globalsymtable) then
         CurrentModule.globalsymtable.SymList.ForEachCall(@AddToThreadvarList,tcb);
       CurrentModule.localsymtable.SymList.ForEachCall(@AddToThreadvarList,tcb);
       if TRecordSymTable(tabledef.symtable).datasize<>0 then
         { terminator }
         tcb.emit_tai(tai_const.Create_nil_dataptr,voidpointertype);
       tcb.end_anonymous_record;
       add:=TRecordSymTable(tabledef.symtable).datasize<>0;
       if add then
         begin
           s:=make_mangledname('THREADVARLIST',CurrentModule.localsymtable,'');
           sym:=CurrentAsmData.DefineAsmSymbol(s,AB_GLOBAL,AT_DATA_FORCEINDIRECT,tabledef);
           CurrentAsmData.asmlists[al_globals].concatlist(
             tcb.get_final_asmlist(sym,tabledef,sec_data,s,const_align(sizeof(pint))));
           include(CurrentModule.moduleflags,mf_threadvars);
           CurrentModule.add_public_asmsym(sym);
         end;
       tcb.Free;
       tcb := nil;
    end;


  class procedure tnodeutils.InsertRuntimeInitsTablesTable(const prefix,tablename:string;unitflag:TModuleFlag);
    var
      hp: tused_unit;
      tcb: ttai_typedconstbuilder;
      countplaceholder: ttypedconstplaceholder;
      tabledef: TDef;
      count: longint;
    begin
      tcb:=ctai_typedconstbuilder.create([tcalo_make_dead_strippable,tcalo_new_section]);
      tcb.begin_anonymous_record('',default_settings.packrecords,sizeof(pint),
        targetinfos[Ord(TargetInfo.system)]^.alignment.recordalignmin
      );
      { placeholder for the count }
      countplaceholder:=tcb.emit_placeholder(sizesinttype);
      count:=0;
      hp:=tused_unit(usedunits.first);
      while assigned(hp) do
       begin
         if not assigned(hp.u.package) and (unitflag in hp.u.moduleflags) then
          begin
            tcb.emit_tai(
              Tai_const.Createname(make_mangledname(prefix,hp.u.globalsymtable,''),0),
              voidcodepointertype);
            inc(count);
          end;
         hp:=tused_unit(hp.next);
       end;
      { Add items from program, if any }
      if unitflag in CurrentModule.moduleflags then
       begin
         tcb.emit_tai(
           Tai_const.Createname(make_mangledname(prefix,CurrentModule.localsymtable,''),0),
           voidcodepointertype);
         inc(count);
       end;
      { Insert TableCount at start }
      countplaceholder.replace(Tai_const.Create_sizeint(count),sizesinttype);
      countplaceholder.free;
      countplaceholder := nil;
      { insert in data segment }
      tabledef:=tcb.end_anonymous_record;
      CurrentAsmData.asmlists[al_globals].concatlist(
        tcb.get_final_asmlist(
          CurrentAsmData.DefineAsmSymbol(tablename,AB_GLOBAL,AT_DATA,tabledef),
          tabledef,
          sec_data,tablename,const_align(sizeof(pint))
        )
      );
      tcb.free;
      tcb := nil;
    end;


  class procedure tnodeutils.InsertRuntimeInits(const prefix:string;list:TLinkedList;unitflag:TModuleFlag);
    var
      s: string;
      item: TTCInitItem;
      tcb: ttai_typedconstbuilder;
      rawdatadef: TDef;
    begin
      item:=TTCInitItem(list.First);
      if item=nil then
        exit;
      s:=make_mangledname(prefix,CurrentModule.localsymtable,'');
      tcb:=ctai_typedconstbuilder.create([tcalo_make_dead_strippable,tcalo_new_section]);
      tcb.begin_anonymous_record('',default_settings.packrecords,sizeof(pint),
        targetinfos[Ord(TargetInfo.system)]^.alignment.recordalignmin);
      repeat
        { optimize away unused local/static symbols }
        if (item.sym.refs>0) or (item.sym.owner.symtabletype=globalsymtable) then
          begin
            { address to initialize }
            tcb.queue_init(voidpointertype);
            rawdatadef:=carraydef.getreusable(cansichartype,TStaticVarSym(item.sym).vardef.size);
            tcb.queue_vecn(rawdatadef,item.offset);
            tcb.queue_typeconvn(cpointerdef.getreusable(TStaticVarSym(item.sym).vardef),cpointerdef.getreusable(rawdatadef));
            tcb.queue_emit_staticvar(TStaticVarSym(item.sym));
            { value with which to initialize }
            tcb.emit_tai(Tai_const.Create_sym(item.datalabel),item.datadef)
          end;
        item:=TTCInitItem(item.Next);
      until item=nil;
      { end-of-list marker }
      tcb.emit_tai(Tai_const.Create_nil_dataptr,voidpointertype);
      rawdatadef:=tcb.end_anonymous_record;
      CurrentAsmData.asmlists[al_globals].concatList(
        tcb.get_final_asmlist(
          CurrentAsmData.DefineAsmSymbol(s,AB_GLOBAL,AT_DATA,rawdatadef),
          rawdatadef,sec_data,s,const_align(sizeof(pint))));
      tcb.free;
      tcb := nil;
      include(CurrentModule.moduleflags,unitflag);
    end;


  class procedure tnodeutils.InsertWideInits;
    begin
      InsertRuntimeInits('WIDEINITS',CurrentAsmData.WideInits,mf_wideinits);
    end;


  class procedure tnodeutils.InsertResStrInits;
    begin
      InsertRuntimeInits('RESSTRINITS',CurrentAsmData.ResStrInits,mf_resstrinits);
    end;


  class procedure tnodeutils.InsertWideInitsTablesTable;
    begin
      InsertRuntimeInitsTablesTable('WIDEINITS','FPC_WIDEINITTABLES',mf_wideinits);
    end;


  class procedure tnodeutils.InsertResStrTablesTable;
    begin
      InsertRuntimeInitsTablesTable('RESSTRINITS','FPC_RESSTRINITTABLES',mf_resstrinits);
    end;


  class procedure tnodeutils.InsertResourceTablesTable;
    var
      hp : tmodule;
      count : longint;
      tcb : ttai_typedconstbuilder;
      countplaceholder : ttypedconstplaceholder;
      tabledef: TDef;
    begin
      tcb:=ctai_typedconstbuilder.create([tcalo_make_dead_strippable,tcalo_new_section]);
      count:=0;
      hp:=tmodule(loaded_units.first);
      tcb.begin_anonymous_record('',default_settings.packrecords,sizeof(pint),
        targetinfos[Ord(TargetInfo.system)]^.alignment.recordalignmin);
      countplaceholder:=tcb.emit_placeholder(sizesinttype);
      while assigned(hp) do
        begin
          if not assigned(hp.package) and (mf_has_resourcestrings in hp.moduleflags) then
            begin
              tcb.emit_tai(Tai_const.Create_sym(
                ctai_typedconstbuilder.get_vectorized_dead_strip_section_symbol_start('RESSTR',hp.localsymtable,[tcdssso_register_asmsym,tcdssso_use_indirect])),
                voidpointertype
              );
              tcb.emit_tai(Tai_const.Create_sym(
                ctai_typedconstbuilder.get_vectorized_dead_strip_section_symbol_end('RESSTR',hp.localsymtable,[tcdssso_register_asmsym,tcdssso_use_indirect])),
                voidpointertype
              );
              inc(count);
            end;
          hp:=tmodule(hp.next);
        end;
      { Insert TableCount at start }
      countplaceholder.replace(Tai_const.Create_sizeint(count),sizesinttype);
      countplaceholder.free;
      countplaceholder := nil;
      { Add to data segment }
      tabledef:=tcb.end_anonymous_record;
      CurrentAsmData.AsmLists[al_globals].concatList(
        tcb.get_final_asmlist(
          CurrentAsmData.DefineAsmSymbol('FPC_RESOURCESTRINGTABLES',AB_GLOBAL,AT_DATA,tabledef),
          tabledef,sec_rodata,'FPC_RESOURCESTRINGTABLES',const_align(sizeof(pint))
        )
      );
      tcb.free;
      tcb := nil;
    end;


  class procedure tnodeutils.InsertResourceInfo(ResourcesUsed: boolean);
    var
      tcb: ttai_typedconstbuilder;
    begin
      if (TargetRes.id in [res_elf,res_macho,res_xcoff]) or
         { generate the FPC_RESLOCATION symbol even when using external resources,
           because in SysInit we can only reference it unconditionally }
         ((TargetRes.id=res_ext) and (TargetInfo.system in systems_darwin)) then
        begin
          tcb:=ctai_typedconstbuilder.create([tcalo_new_section,tcalo_make_dead_strippable]);

          if ResourcesUsed and (TargetRes.id<>res_ext) then
            tcb.emit_tai(Tai_const.Createname('FPC_RESSYMBOL',0),voidpointertype)
          else
            { Nil pointer to resource information }
            tcb.emit_tai(tai_const.Create_nil_dataptr,voidpointertype);
          CurrentAsmData.asmlists[al_globals].concatList(
            tcb.get_final_asmlist(
              CurrentAsmData.DefineAsmSymbol('FPC_RESLOCATION',AB_GLOBAL,AT_DATA,voidpointertype),
              voidpointertype,
              sec_rodata,
              'FPC_RESLOCATION',
              const_align(sizeof(puint))
            )
          );

          tcb.free;
          tcb := nil;
        end;
    end;


  class procedure tnodeutils.InsertMemorySizes;
    var
      tcb: ttai_typedconstbuilder;
      s: shortstring;
      sym: tasmsymbol;
      def: TDef;
    begin
      { Insert Ident of the compiler in the .fpc.version section }
      tcb:=ctai_typedconstbuilder.create([tcalo_no_dead_strip]);
      s:='FPC '+full_version_string+
        ' ['+date_string+'] for '+TargetCPUString+' - '+TargetInfo.shortname;
      def:=carraydef.getreusable(cansichartype,length(s));
      tcb.maybe_begin_aggregate(def);
      tcb.emit_tai(Tai_string.Create(s),def);
      tcb.maybe_end_aggregate(def);
      sym:=CurrentAsmData.DefineAsmSymbol('__fpc_ident',AB_LOCAL,AT_DATA,def);
      CurrentAsmData.asmlists[al_globals].concatlist(
        tcb.get_final_asmlist(sym,def,sec_fpc,'version',const_align(32))
      );
      tcb.free;

      if (tf_emit_stklen in TargetInfo.flags) or
          not(tf_no_generic_stackcheck in TargetInfo.flags) then
        begin
          { stacksize can be specified and is now simulated }
          tcb:=ctai_typedconstbuilder.create([tcalo_new_section,tcalo_make_dead_strippable]);
          tcb.emit_tai(Tai_const.Create_int_dataptr(stacksize),ptruinttype);
          sym:=CurrentAsmData.DefineAsmSymbol('__stklen',AB_GLOBAL,AT_DATA,ptruinttype);
          CurrentAsmData.asmlists[al_globals].concatlist(
            tcb.get_final_asmlist(sym,ptruinttype,sec_data,'__stklen',const_align(sizeof(pint)))
          );
          tcb.free;
          tcb := nil;
        end;

      { Initial heapsize }
      tcb:=ctai_typedconstbuilder.create([tcalo_new_section,tcalo_make_dead_strippable]);
      tcb.emit_tai(Tai_const.Create_int_dataptr(heapsize),ptruinttype);
      sym:=CurrentAsmData.DefineAsmSymbol('__heapsize',AB_GLOBAL,AT_DATA,ptruinttype);
      CurrentAsmData.asmlists[al_globals].concatlist(
        tcb.get_final_asmlist(sym,ptruinttype,sec_data,'__heapsize',const_align(sizeof(pint)))
      );
      tcb.free;
      tcb := nil;

      { Valgrind usage }
      tcb:=ctai_typedconstbuilder.create([tcalo_new_section,tcalo_make_dead_strippable]);
      tcb.emit_ord_const(byte(cs_gdb_valgrind in CurrentSettings.globalswitches),u8inttype);
      sym:=CurrentAsmData.DefineAsmSymbol('__fpc_valgrind',AB_GLOBAL,AT_DATA,u8inttype);
      CurrentAsmData.asmlists[al_globals].concatlist(
        tcb.get_final_asmlist(sym,u8inttype,sec_data,'__fpc_valgrind',const_align(sizeof(pint)))
      );
      tcb.free;
      tcb := nil;
    end;


  class procedure tnodeutils.InsertObjectInfo;
    var
      tcb: ttai_typedconstbuilder;
    begin
      if (m_objectivec1 in CurrentSettings.modeswitches) then
        begin
          { first 4 bytes contain version information about this section (currently version 0),
            next 4 bytes contain flags (currently only regarding whether the code in the object
            file supports or requires garbage collection)
          }
          tcb:=ctai_typedconstbuilder.create([tcalo_new_section,tcalo_no_dead_strip]);
          tcb.emit_ord_const(0,u64inttype);
          CurrentAsmData.asmlists[al_objc_data].concatList(
            tcb.get_final_asmlist(
              CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'_OBJC_IMAGE_INFO',AB_LOCAL,AT_DATA,u64inttype),
              u64inttype,sec_objc_image_info,'_OBJC_IMAGE_INFO',const_align(sizeof(pint))
            )
          );
          tcb.free;
          tcb := nil;
        end;
    end;


  class procedure tnodeutils.RegisterUsedAsmSym(sym: TAsmSymbol; def: TDef; compileronly: boolean);
    begin
      { don't do anything by default }
    end;


  class procedure tnodeutils.RegisterModuleInitFunction(pd: TProcDef);
    begin
      { setinitname may generate a new section -> don't add to the
        current list, because we assume this remains a text section }
      exportlib.setinitname(CurrentAsmData.AsmLists[al_pure_assembler],pd.mangledname);
    end;


  class procedure tnodeutils.RegisterModuleFiniFunction(pd: TProcDef);
    begin
      exportlib.setfininame(CurrentAsmData.AsmLists[al_pure_assembler],pd.mangledname);
    end;


   class procedure tnodeutils.add_main_procdef_paras(pd: TDef);
     var
       pvs: TParaVarSym;
     begin
       { stub for calling FPC_SYSTEMMAIN from the C main -> add argc/argv/argp }
       if (TProcDef(pd).proctypeoption=potype_mainstub) and
          (TargetInfo.system in systems_darwin) then
         begin
           pvs:=cparavarsym.create('ARGC',1,vs_const,s32inttype,[]);
           TProcDef(pd).parast.insertsym(pvs);
           pvs:=cparavarsym.create('ARGV',2,vs_const,cpointerdef.getreusable(charpointertype),[]);
           TProcDef(pd).parast.insertsym(pvs);
           pvs:=cparavarsym.create('ARGP',3,vs_const,cpointerdef.getreusable(charpointertype),[]);
           TProcDef(pd).parast.insertsym(pvs);
           TProcDef(pd).calcparas;
         end
       { package stub for Windows is a DLLMain }
       else if (TProcDef(pd).proctypeoption=potype_pkgstub) and
           (TargetInfo.system in systems_all_windows) then
         begin
           pvs:=cparavarsym.create('HINSTANCE',1,vs_const,uinttype,[]);
           TProcDef(pd).parast.insertsym(pvs);
           pvs:=cparavarsym.create('DLLREASON',2,vs_const,u32inttype,[]);
           TProcDef(pd).parast.insertsym(pvs);
           pvs:=cparavarsym.create('DLLPARAM',3,vs_const,voidpointertype,[]);
           TProcDef(pd).parast.insertsym(pvs);
           TProcDef(pd).returndef:=bool32type;
           insert_funcret_para(TProcDef(pd));
           TProcDef(pd).calcparas;
         end;
     end;


end.
