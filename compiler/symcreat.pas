{
    Copyright (c) 2011 by Jonas Maebe

    This unit provides helpers for creating new syms/defs based on string
    representations.

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
{$i fpcdefs.inc}

unit symcreat;

interface

  uses
    FinPut,tokens,Scanner,GlobType,CClasses,
    AAsmData,
    symconst,SymBase,symtype,symdef,SymSym,
    node;


  type
    TScannerState = record
      new_scanner: TScannerFile;
      old_scanner: TScannerFile;
      old_filepos: TFilePosInfo;
      old_modeswitches: TModeSwitches;
      valid: boolean;
    end;

  { save/restore the scanner state before/after injecting }
  procedure replace_scanner(const tempname: string; out sstate: TScannerState);
  procedure restore_scanner(const sstate: TScannerState);

  { parses a (class or regular) method/constructor/destructor declaration from
    str, as if it were declared in astruct's declaration body

    WARNING: save the scanner state before calling this routine, and restore
      when done. }
  function str_parse_method_dec(str: AnsiString; potype: TProcTypeOption; is_classdef: boolean; astruct: TAbstractRecordDef; out pd: TProcDef): boolean;

  { parses a (class or regular)  method/constructor/destructor implementation
    from str, as if it appeared in the current unit's implementation section

      WARNINGS:
        * save the scanner state before calling this routine, and restore when done.
        * the code *must* be written in objfpc style
  }
  function str_parse_method_impl(const str: AnsiString; usefwpd: TProcDef; is_classdef: boolean):boolean;

  { parses a typed constant assignment to ssym

      WARNINGS:
        * save the scanner state before calling this routine, and restore when done.
        * the code *must* be written in objfpc style
  }
  procedure str_parse_typedconst(list: TAsmList; str: AnsiString; ssym: TStaticVarSym);



  { in the JVM, constructors are not automatically inherited (so you can hide
    them). To emulate the Pascal behaviour, we have to automatically add
    all parent constructors to the current class as well. We also have to do
    the same for the (emulated) virtual class methods }
  procedure add_missing_parent_constructors_intf(obj: TObjectDef; addvirtclassmeth: boolean; forcevis: TVisibility);

  { goes through all defs in st to add implementations for synthetic methods
    added earlier }
  procedure add_synthetic_method_implementations(st: TSymTable);

  { create an alias for a procdef with Pascal name "newrealname",
    mangledname "newmangledname", in symtable newparentst, part of the
    record/class/.. "newstruct" (nil if none), and with synthetickind "sk" and
    synthetic kind para "skpara" to create the implementation (tsk_none and nil
    in case not necessary). Returns the new procdef; finish_copied_procdef() is
    not required/must not be called for the result. }
  function create_procdef_alias(pd: TProcDef; const newrealname: string; const newmangledname: TSymStr; newparentst: TSymTable; newstruct: TAbstractRecordDef; sk: TSyntheticKind; skpara: pointer): TProcDef;

  { finalize a procdef that has been copied with
    tprocdef.getcopyas(procdef,pc_bareproc) }
  procedure finish_copied_procdef(var pd: TProcDef; const realname: string; newparentst: TSymTable; newstruct: TAbstractRecordDef);

  { checks whether sym (a local or para of pd) already has a counterpart in
    pd's parentfpstruct, and if not adds a new field to the struct with type
    "vardef" (can be different from sym's type in case it's a call-by-reference
    parameter, which is indicated by addrparam). If it already has a field in
    the parentfpstruct, this field is returned. }
  function maybe_add_sym_to_parentfpstruct(pd: TProcDef; sym: TSym; vardef: TDef; addrparam: boolean): TSym;
  { given a localvarsym or paravarsym of pd, returns the field of the
    parentfpstruct corresponding to this sym }
  function find_sym_in_parentfpstruct(pd: TProcDef; sym: TSym): TSym;
  { replaces all local and paravarsyms that have been mirrored in the
    parentfpstruct with aliasvarsyms that redirect to these fields (used to
    make sure that references to these syms in the owning procdef itself also
    use the ones in the parentfpstructs) }
  procedure redirect_parentfpstruct_local_syms(pd: TProcDef);
  { finalises the parentfpstruct (alignment padding, ...) }
  procedure finish_parentfpstruct(pd: TProcDef);

  { turns a fieldvarsym into a class/static field definition, and returns the
    created staticvarsym that is responsible for allocating the global storage }
  function make_field_static(recst: TSymTable; fieldvs: TFieldVarSym): TStaticVarSym;

  { create a new procdef with the signature of orgpd and (mangled) name
    newname, and change the implementation of orgpd so that it calls through
    to this new procedure }
  procedure call_through_new_name(orgpd: TProcDef; const newname: TSymStr);

  function generate_pkg_stub(pd:TProcDef):TNode;
  procedure generate_attr_constrs(attrs:TFPObjectList);

  { Generate the hidden thunk class for interfaces,
    so we can use them in TVirtualInterface on platforms that do not allow
    generating executable code in memory at runtime.}
  procedure add_synthetic_interface_classes_for_st(st : TSymTable; gen_intf, gen_impl : boolean);


implementation

  uses
    CUtils,Globals,Verbose,Systems,CompHook,FModule,ConstExp,
    SymTable,defutil,symutil,ProcInfo,
    pbase,pdecl, pdecobj,pdecsub,psub,ptconst,pparautl,
    aasmcpu,symcpu,
    nbas,nld,nmem,ncon,
    defcmp,
    paramgr;

  procedure replace_scanner(const tempname: string; out sstate: TScannerState);
    var
      old_block_type: TBlockType;
    begin
      { would require saving of cstringpattern, patternw }
      if (CurrentScanner.token=_CSTRING) or
         (CurrentScanner.token=_CWCHAR) or
         (CurrentScanner.token=_CWSTRING) then
        InternalError(2011032201);
      sstate.old_scanner:=CurrentScanner;
      sstate.old_filepos:=CurrentFilePos;
      sstate.old_modeswitches:=CurrentSettings.ModeSwitches;
      sstate.valid:=true;
      { creating a new scanner resets the block type, while we want to continue
        in the current one }
      old_block_type:=Block_Type;
      sstate.new_scanner:=TScannerFile.Create('_Macro_.'+tempname,true);
      Set_Current_Scanner(sstate.new_scanner);
      Block_Type:=old_block_type;
      { required for e.g. FpcDeepCopy record method (uses "out" parameter; field
        names are escaped via &, so should not cause conflicts }
      CurrentSettings.ModeSwitches:=ObjFPCModeSwitches+
        (sstate.old_modeswitches*[m_default_ansistring,m_default_unicodestring]);
    end;


  procedure restore_scanner(const sstate: TScannerState);
    begin
      if sstate.valid then
        begin
          sstate.new_scanner.free; // no nil needed
          Set_Current_Scanner(sstate.old_scanner);
          CurrentFilePos:=sstate.old_filepos;
          CurrentSettings.ModeSwitches:=sstate.old_modeswitches;
        end;
    end;


  function str_parse_method_dec(str: AnsiString; potype: TProcTypeOption; is_classdef: boolean; astruct: TAbstractRecordDef; out pd: TProcDef): boolean;
    var
      oldparse_only: boolean;
    begin
      Message1(parser_d_internal_parser_string,str);
      oldparse_only:=parse_only;
      parse_only:=true;
      result:=false;
      { in case multiple strings are injected, make sure to always close the
        previous macro inputfile to prevent memory leaks }
      if Assigned(CurrentScanner.inputfile) and
         not(CurrentScanner.inputfile.closed) then
        CurrentScanner.closeinputfile;
      { inject the string in the scanner }
      str:=str+'end;';
      CurrentScanner.substitutemacro('meth_head_macro',@str[1],length(str),CurrentScanner.line_no,CurrentScanner.inputfile.RefIndex,true);
      CurrentScanner.readtoken(false);
      { and parse it... }
      case potype of
        potype_class_constructor:
          pd:=class_constructor_head(astruct);
        potype_class_destructor:
          pd:=class_destructor_head(astruct);
        potype_constructor:
          pd:=constructor_head;
        potype_destructor:
          pd:=destructor_head;
        else if Assigned(astruct) and
           (astruct.typ=recorddef) then
          pd:=parse_record_method_dec(astruct,is_classdef,false)
        else
          pd:=method_dec(astruct,is_classdef,false);
      end;
      if Assigned(pd) then
        result:=true;
      parse_only:=oldparse_only;
      { remove the temporary macro input file again }
      CurrentScanner.closeinputfile;
      CurrentScanner.nextfile;
      CurrentScanner.tempopeninputfile;
    end;


  function str_parse_method_impl_with_fileinfo(str: AnsiString; usefwpd: TProcDef; fileno, lineno: LongInt; is_classdef: boolean; out result_procdef: TProcDef):boolean;
     var
       oldparse_only: boolean;
       tmpstr: AnsiString;
       flags : TReadProcFlags;
     begin
      if ((status.verbosity and VDebug)<>0) then
        begin
           if Assigned(usefwpd) then
             Message1(parser_d_internal_parser_string,usefwpd.customprocname([pno_proctypeoption,pno_paranames,pno_ownername,pno_noclassmarker,pno_noleadingdollar])+str)
           else
             begin
               if is_classdef then
                 tmpstr:='class '
               else
                 tmpstr:='';
               Message1(parser_d_internal_parser_string,tmpstr+str);
             end;
        end;
      oldparse_only:=parse_only;
      parse_only:=false;
      result:=false;
      { "const" starts a new kind of block and hence makes the scanner return }
      str:=str+'const;';
      { inject the string in the scanner }
      CurrentScanner.substitutemacro('meth_impl_macro',@str[1],length(str),lineno,fileno,true);
      CurrentScanner.readtoken(false);
      { and parse it... }
      flags:=[];
      if is_classdef then
        include(flags,rpf_classmethod);
      result_procdef:=read_proc(flags,usefwpd);
      parse_only:=oldparse_only;
      { remove the temporary macro input file again }
      CurrentScanner.closeinputfile;
      CurrentScanner.nextfile;
      CurrentScanner.tempopeninputfile;
      result:=true;
     end;


  function str_parse_method_impl(const str: AnsiString; usefwpd: TProcDef; is_classdef: boolean):boolean;
    var
      tmpproc: TProcDef;
    begin
      result:=str_parse_method_impl_with_fileinfo(str, usefwpd, CurrentScanner.inputfile.RefIndex, CurrentScanner.line_no, is_classdef, tmpproc);
    end;


  function str_parse_method_impl(const str: AnsiString; usefwpd: TProcDef; is_classdef: boolean; out result_procdef: TProcDef):boolean;
    begin
      result:=str_parse_method_impl_with_fileinfo(str, usefwpd, CurrentScanner.inputfile.RefIndex, CurrentScanner.line_no, is_classdef, result_procdef);
    end;


  procedure str_parse_typedconst(list: TAsmList; str: AnsiString; ssym: TStaticVarSym);
    var
      old_block_type: TBlockType;
      old_parse_only: boolean;
    begin
      Message1(parser_d_internal_parser_string,str);
      { a string that will be interpreted as the start of a new section ->
        typed constant parsing will stop }
      str:=str+'type ';
      old_parse_only:=parse_only;
      old_block_type:=Block_Type;
      parse_only:=true;
      Block_Type:=bt_const;
      CurrentScanner.substitutemacro('typed_const_macro',@str[1],length(str),CurrentScanner.line_no,CurrentScanner.inputfile.RefIndex,true);
      CurrentScanner.readtoken(false);
      read_typed_const(list,ssym,ssym.owner.symtabletype in [recordsymtable,objectsymtable]);
      parse_only:=old_parse_only;
      Block_Type:=old_block_type;
      { remove the temporary macro input file again }
      CurrentScanner.closeinputfile;
      CurrentScanner.nextfile;
      CurrentScanner.tempopeninputfile;
    end;

    function str_parse_objecttypedef(typename : shortstring;str: AnsiString): TObjectDef;
     var
       b,oldparse_only: boolean;
       i : integer;
       tmpstr: AnsiString;
       flags : TReadProcFlags;
       o : TObject;

     begin
      result:=nil;
      Message1(parser_d_internal_parser_string,str);
      oldparse_only:=parse_only;
      parse_only:=true;
      { "const" starts a new kind of block and hence makes the scanner return }
      str:=str+'const;';
      Block_Type:=bt_type;
      { inject the string in the scanner }
      CurrentScanner.substitutemacro('hidden_interface_class_macro',@str[1],length(str),CurrentScanner.line_no,CurrentScanner.inputfile.RefIndex,true);
      CurrentScanner.readtoken(false);
      type_dec(b);
      // In the interface part, the object def is not necessarily the last one, the methods also generate defs.
      i:=CurrentModule.DefList.count-1;
      While (result=nil) and (i>=0) do
        begin
        O:=CurrentModule.DefList[i];
        if (o is TObjectDef) then
           if (TObjectDef(o).GetTypeName=typename) then
             result:=TObjectDef(o);
        dec(i);
        end;
      if result=nil then
        InternalError(2024050401);
      parse_only:=oldparse_only;
      { remove the temporary macro input file again }
      CurrentScanner.closeinputfile;
      CurrentScanner.nextfile;
      CurrentScanner.tempopeninputfile;
     end;


  function def_unit_name_prefix_if_toplevel(def: TDef): TSymStr;
    begin
      result:='';
      { if the routine is a global routine in a unit, explicitly use this unit
        name to avoid accidentally calling other same-named routines that may be
        in scope }
      if not Assigned(def.owner.defowner) and
         Assigned(def.owner.realname) and
         (def.owner.ModuleID<>0) then
        result:=internal_macro_escape_unit_namespace_name+def.owner.realname^+'.';
    end;


  procedure add_missing_parent_constructors_intf(obj: TObjectDef; addvirtclassmeth: boolean; forcevis: TVisibility);
    var
      parent: TObjectDef;
      def: TDef;
      parentpd,
      childpd: TProcDef;
      i: LongInt;
      srsym: TSym;
      srsymtable: TSymTable;
    begin
      if (oo_is_external in obj.objectoptions) or
         not Assigned(obj.childof) then
        exit;
      parent:=obj.childof;
      { find all constructor in the parent }
      for i:=0 to TObjectSymTable(parent.SymTable).deflist.count-1 do
        begin
          def:=TDef(TObjectSymTable(parent.SymTable).deflist[i]);
          if (def.typ<>procdef) or
             ((TProcDef(def).proctypeoption<>potype_constructor) and
              (not addvirtclassmeth or
               not([po_classmethod,po_virtualmethod]<=TProcDef(def).procoptions))) or
             not is_visible_for_object(TProcDef(def),obj) then
            continue;
          parentpd:=TProcDef(def);
          { do we have this constructor too? (don't use
            search_struct_member/searchsym_in_class, since those will
            search parents too) }
          if searchsym_in_record(obj,parentpd.procsym.name,srsym,srsymtable) then
            begin
              { there's a symbol with the same name, is it a routine of the
                same type with the same parameters? }
              if srsym.typ=procsym then
                begin
                  childpd:=TProcSym(srsym).find_procdef_bytype_and_para(
                    TProcDef(def).proctypeoption,parentpd.paras,nil,
                    [cpo_ignorehidden,cpo_ignoreuniv,cpo_openequalisexact]);
                  if Assigned(childpd) then
                    continue;
                end;
            end;
          { if we get here, we did not find it in the current objectdef ->
            add }
          childpd:=TProcDef(parentpd.getcopyas(procdef,pc_normal_no_hidden,'',true));
          { get rid of the import name for inherited virtual class methods,
            it has to be regenerated rather than amended }
          if [po_classmethod,po_virtualmethod]<=childpd.procoptions then
            begin
              StringDispose(childpd.import_name);
              exclude(childpd.procoptions,po_has_importname);
            end;
          if forcevis<>vis_none then
            childpd.visibility:=forcevis;
          if po_virtualmethod in childpd.procoptions then
            include(childpd.procoptions,po_overridingmethod);
          { ignore this artificially added procdef when looking for overloads }
          include(childpd.procoptions,po_ignore_for_overload_resolution);
          finish_copied_procdef(childpd,parentpd.procsym.realname,obj.SymTable,obj);
          exclude(childpd.procoptions,po_external);
          childpd.synthetickind:=tsk_anon_inherited;
          include(obj.objectoptions,oo_has_constructor);
        end;
    end;


  procedure implement_anon_inherited(pd: TProcDef);
    var
      str: AnsiString;
      isclassmethod: boolean;
    begin
      isclassmethod:=
        (po_classmethod in pd.procoptions) and
        not(pd.proctypeoption in [potype_constructor,potype_destructor]);
      str:='begin ';
      if (pd.proctypeoption<>potype_constructor) and
         not is_void(pd.returndef) then
        str:=str+'result:=';
      str:=str+'inherited end;';
      str_parse_method_impl(str,pd,isclassmethod);
    end;


  procedure implement_jvm_clone(pd: TProcDef);
    var
      struct: TAbstractRecordDef;
      str: AnsiString;
      i: LongInt;
      sym: TSym;
      fsym: TFieldVarSym;
    begin
      if not(pd.struct.typ in [recorddef,objectdef]) then
        InternalError(2011032802);
      struct:=pd.struct;
      { anonymous record types must get an artificial name, so we can generate
        a typecast at the scanner level }
      if (struct.typ=recorddef) and
         not Assigned(struct.typesym) then
        InternalError(2011032812);
      { We cannot easily use the inherited clone in case we have to create a
        deep copy of certain fields. The reason is that e.g. sets are pointers
        at the JVM level, but not in Pascal. So the JVM clone routine will copy
        the pointer to the set from the old record (= class instance) to the new
        one, but we have no way to change this pointer itself from inside Pascal
        code.

        We solve this by relying on the fact that the JVM is garbage collected:
        we simply declare a temporary instance on the stack, which will be
        allocated/initialized by the temp generator. We return its address as
        the result of the clone routine, so it remains live. }
      str:='var __fpc_newcopy:'+ struct.typesym.realname+'; begin clone:=JLObject(@__fpc_newcopy);';
      { copy all field contents }
      for i:=0 to struct.SymTable.symlist.count-1 do
        begin
          sym:=TSym(struct.SymTable.symlist[i]);
          if (sym.typ=fieldvarsym) then
            begin
              fsym:=TFieldVarSym(sym);
              str:=str+'__fpc_newcopy.&'+fsym.realname+':=&'+fsym.realname+';';
            end;
        end;
      str:=str+'end;';
      str_parse_method_impl(str,pd,false);
    end;


  procedure implement_record_deepcopy(pd: TProcDef);
    var
      struct: TAbstractRecordDef;
      str: AnsiString;
      i: LongInt;
      sym: TSym;
      fsym: TFieldVarSym;
    begin
      if not(pd.struct.typ in [recorddef,objectdef]) then
        InternalError(2011032810);
      struct:=pd.struct;
      { anonymous record types must get an artificial name, so we can generate
        a typecast at the scanner level }
      if (struct.typ=recorddef) and
         not Assigned(struct.typesym) then
        InternalError(2011032811);
      { copy all fields }
      str:='type _fpc_ptrt = ^'+struct.typesym.realname+'; var res: _fpc_ptrt; begin res:=_fpc_ptrt(result);';
      for i:=0 to struct.SymTable.symlist.count-1 do
        begin
          sym:=TSym(struct.SymTable.symlist[i]);
          if (sym.typ=fieldvarsym) then
            begin
              fsym:=TFieldVarSym(sym);
              str:=str+'res^.&'+fsym.realname+':=&'+fsym.realname+';';
            end;
        end;
      str:=str+'end;';
      str_parse_method_impl(str,pd,false);
    end;


  procedure implement_record_initialize(pd: TProcDef);
    var
      struct: TAbstractRecordDef;
      str: AnsiString;
      i: LongInt;
      sym: TSym;
      fsym: TFieldVarSym;
    begin
      if not(pd.struct.typ in [recorddef,objectdef]) then
        InternalError(2011071710);
      struct:=pd.struct;
      { anonymous record types must get an artificial name, so we can generate
        a typecast at the scanner level }
      if (struct.typ=recorddef) and
         not Assigned(struct.typesym) then
        InternalError(2011032804);
      { walk over all fields that need initialization }
      str:='begin ';
      for i:=0 to struct.SymTable.symlist.count-1 do
        begin
          sym:=TSym(struct.SymTable.symlist[i]);
          if (sym.typ=fieldvarsym) then
            begin
              fsym:=TFieldVarSym(sym);
              if fsym.vardef.NeedsInitTable then
                str:=str+(internal_macro_escape_unit_namespace_name+'system.initialize(&')+fsym.realname+');';
            end;
        end;
      str:=str+'end;';
      str_parse_method_impl(str,pd,false);
    end;

  procedure implement_empty(pd: TProcDef);
    var
      str: AnsiString;
      isclassmethod: boolean;
    begin
      isclassmethod:=
        (po_classmethod in pd.procoptions) and
        not(pd.proctypeoption in [potype_constructor,potype_destructor]);
      str:='begin end;';
      str_parse_method_impl(str,pd,isclassmethod);
    end;


  procedure addvisibleparameters(var str: AnsiString; pd: TProcDef);
    var
      currpara: TParaVarSym;
      i: LongInt;
      firstpara: boolean;
    begin
      firstpara:=true;
      for i:=0 to pd.paras.count-1 do
        begin
          currpara:=TParaVarSym(pd.paras[i]);
          if not(vo_is_hidden_para in currpara.varoptions) then
            begin
              if not firstpara then
                str:=str+',';
              firstpara:=false;
              str:=str+'&'+currpara.realname;
            end;
        end;
    end;



  procedure implement_callthrough(pd: TProcDef);
    var
      str: AnsiString;
      callpd: TProcDef;
      isclassmethod: boolean;
    begin
      isclassmethod:=
        (po_classmethod in pd.procoptions) and
        not(pd.proctypeoption in [potype_constructor,potype_destructor]);
      callpd:=TProcDef(pd.skpara);
      str:='begin ';
      if pd.returndef<>voidtype then
        str:=str+'result:=';
      { if the routine is a global routine in a unit/program, explicitly
        mnetion this program/unit name to avoid accidentally calling other
        same-named routines that may be in scope }
      str:=str+def_unit_name_prefix_if_toplevel(callpd)+callpd.procsym.realname+'(';
      addvisibleparameters(str,pd);
      str:=str+') end;';
      str_parse_method_impl(str,pd,isclassmethod);
    end;






  procedure implement_field_getter(pd: TProcDef);
    var
      i: LongInt;
      pvs: TParaVarSym;
      str: AnsiString;
      callthroughprop: TPropertySym;
      propaccesslist: TPropAccessList;
      lastparanr: LongInt;
      firstpara: boolean;
    begin
      callthroughprop:=TPropertySym(pd.skpara);
      str:='begin result:='+callthroughprop.realname;
      if ppo_hasparameters in callthroughprop.propoptions then
        begin
          if not callthroughprop.getpropaccesslist(palt_read,propaccesslist) then
            InternalError(2012100701);
          str:=str+'[';
          firstpara:=true;
          lastparanr:=TProcDef(propaccesslist.procdef).paras.count-1;
          if ppo_indexed in callthroughprop.propoptions then
            dec(lastparanr);
          for i:=0 to lastparanr do
            begin
              { skip self/vmt/parentfp, passed implicitly }
              pvs:=TParaVarSym(TProcDef(propaccesslist.procdef).paras[i]);
              if ([vo_is_self,vo_is_vmt,vo_is_parentfp]*pvs.varoptions)<>[] then
                continue;
              if not firstpara then
                str:=str+',';
              firstpara:=false;
              str:=str+pvs.realname;
            end;
          str:=str+']';
        end;
      str:=str+'; end;';
      str_parse_method_impl(str,pd,po_classmethod in pd.procoptions)
    end;


  procedure implement_field_setter(pd: TProcDef);
    var
      i, lastparaindex: LongInt;
      pvs: TParaVarSym;
      paraname,  str: AnsiString;
      callthroughprop: TPropertySym;
      propaccesslist: TPropAccessList;
      firstpara: boolean;
    begin
      callthroughprop:=TPropertySym(pd.skpara);
      str:='begin '+callthroughprop.realname;
      if not callthroughprop.getpropaccesslist(palt_write,propaccesslist) then
        InternalError(2012100702);
      if ppo_hasparameters in callthroughprop.propoptions then
        begin
          str:=str+'[';
          firstpara:=true;
          { last parameter is the value to be set, skip (only add index
            parameters here) }
          lastparaindex:=TProcDef(propaccesslist.procdef).paras.count-2;
          if ppo_indexed in callthroughprop.propoptions then
            dec(lastparaindex);
          for i:=0 to lastparaindex do
            begin
              { skip self/vmt/parentfp/index, passed implicitly }
              pvs:=TParaVarSym(TProcDef(propaccesslist.procdef).paras[i]);
              if ([vo_is_self,vo_is_vmt,vo_is_parentfp]*pvs.varoptions)<>[] then
                continue;
              if not firstpara then
                str:=str+',';
              firstpara:=false;
              str:=str+pvs.realname;
            end;
          str:=str+']';
        end;
      { the value-to-be-set }
      if Assigned(propaccesslist.procdef) then
        begin
          pvs:=TParaVarSym(TProcDef(propaccesslist.procdef).paras[TProcDef(propaccesslist.procdef).paras.count-1]);
          paraname:=pvs.realname;
        end
      else
        paraname:='__fpc_newval__';
      str:=str+':='+paraname+'; end;';
      str_parse_method_impl(str,pd,po_classmethod in pd.procoptions)
    end;


  procedure implement_block_invoke_procvar(pd: TProcDef);
    var
      str: AnsiString;
    begin
      str:='';
      str:='begin ';
      if pd.returndef<>voidtype then
        str:=str+'result:=';
      str:=str+'__FPC_BLOCK_INVOKE_PV_TYPE(PFPC_Block_literal_complex_procvar(FPC_Block_Self)^.pv)(';
      addvisibleparameters(str,pd);
      str:=str+') end;';
      str_parse_method_impl(str,pd,false);
    end;


  procedure implement_interface_wrapper(pd: TProcDef);
    var
      wrapperinfo: PSKParaInterfaceWrapper;
      callthroughpd, tmpproc: TProcDef;
      str: AnsiString;
      fileinfo: TFilePosInfo;
    begin
      wrapperinfo:=PSKParaInterfaceWrapper(pd.skpara);
      if not Assigned(wrapperinfo) then
        InternalError(2015090801);
      callthroughpd:=TProcDef(wrapperinfo^.pd);
      str:='begin ';
      { self right now points to the VMT of interface inside the instance ->
        adjust so it points to the start of the instance }
      str:=str+'pointer(self):=pointer(self) - '+ToStr(wrapperinfo^.offset)+';';
      { now call through to the actual method }
      if pd.returndef<>voidtype then
        str:=str+'result:=';
      str:=str+'&'+callthroughpd.procsym.realname+'(';
      addvisibleparameters(str,pd);
      str:=str+') end;';
      { add dummy file info so we can step in/through it }
      if pd.owner.iscurrentunit then
        fileinfo:=pd.fileinfo
      else
        begin
          fileinfo.moduleindex:=CurrentModule.ModuleID;
          fileinfo.fileindex:=1;
          fileinfo.line:=1;
          fileinfo.column:=1;
        end;
      str_parse_method_impl_with_fileinfo(str,pd,fileinfo.fileindex,fileinfo.line,false,tmpproc);
      dispose(wrapperinfo);
      pd.skpara:=nil;
    end;


  procedure implement_call_no_parameters(pd: TProcDef);
    var
      callpd: TProcDef;
      str: AnsiString;
      warningson,
      isclassmethod: boolean;
    begin
      { avoid warnings about unset function results in these abstract wrappers }
      warningson:=(status.verbosity and VWarning)<>0;
      setverbosity('W-');
      str:='begin ';
      callpd:=TProcDef(pd.skpara);
      str:=str+def_unit_name_prefix_if_toplevel(callpd)+callpd.procsym.realname+'; end;';
      isclassmethod:=
        (po_classmethod in pd.procoptions) and
        not(pd.proctypeoption in [potype_constructor,potype_destructor]);
      str_parse_method_impl(str,pd,isclassmethod);
      if warningson then
        setverbosity('W+');
    end;

  function get_method_paramtype(vardef  : TDef; asPointer : Boolean; out isAnonymousArrayDef : Boolean) : AnsiString; forward;

  function str_parse_method(str: AnsiString; allowgenericid : boolean): TProcDef; forward;

  function str_parse_method(str: AnsiString): TProcDef;
  begin
     Result:=str_parse_method(str,false);
  end;

  procedure implement_invoke_helper(cn : string;pd: TProcDef; idx : integer);

    var
      sarg,str : AnsiString;
      pt, pn,d : shortstring;
      sym : TSym;
      aArg,argcount,i : integer;
      isarray,haveresult : boolean;
      para : TParaVarSym;
      hasopenarray, washigh: Boolean;

    begin
      str:='procedure __invoke_helper__';
      pn:=pd.procsym.realname;
      str:=str+cn+'__'+pn+'_'+ToStr(idx);
      for I:=1 to length(str) do
        if str[i]='.' then
          str[i]:='_';
      str:=str+'(Instance : Pointer; Args : PPointer);'#10;
      argCount:=0;
      for i:=0 to pd.paras.Count-1 do
        begin
          para:=TParaVarSym(pd.paras[i]);
          if vo_is_hidden_para in para.varoptions then
            continue;
          inc(argCount);
          if argCount=1 then
            str:=str+'Type'#10;
          pt:=get_method_paramtype(para.vardef,true,isArray);
          if isArray then
            begin
            str:=str+'  tpa'+ToStr(argcount)+' = '+pt+';'#10;
            pt:='^tpa'+ToStr(argcount);
            end;
          str:=str+'  tp'+ToStr(argcount)+' = '+pt+';'#10;
        end;
      haveresult:=pd.returndef<>voidtype;
      if haveresult then
        begin
        if argCount=0 then
          str:=str+'Type'#10;
        pt:=get_method_paramtype(pd.returndef ,true,isArray);
        if isArray then
          begin
          str:=str+'  tra'+ToStr(argcount)+' = '+pt+';'#10;
          pt:='^tra';
          end;
        str:=str+'  tr = '+pt+';'#10;
        end;
      str:=str+'begin'#10'  ';
      if haveResult then
        str:=str+'TR(args[0])^:=';
      str:=str+cn+'(Instance).'+pn+'(';
      argCount:=0;
      for i:=0 to pd.paras.Count-1 do
        begin
          para:=TParaVarSym(pd.paras[i]);
          if vo_is_hidden_para in para.varoptions then
            continue;
          inc(argCount);
          sarg:=ToStr(argcount);
          if argCount>1 then
            str:=str+',';
          str:=str+'tp'+sarg+'(Args['+sarg+'])^';
        end;
      str:=str+');'#10;
      str:=str+'end;'#10;
      pd.invoke_helper:=str_parse_method(str,true);
  end;

  procedure add_synthetic_method_implementations_for_st(st: TSymTable);
    var
      i   : LongInt;
      def : TDef;
      pd  : TProcDef;
      cn  : shortstring;
    begin
      for i:=0 to st.deflist.count-1 do
        begin
          def:=TDef(st.deflist[i]);
          if (def.typ<>procdef) then
            continue;
          { skip methods when processing unit symtable }
          if def.owner<>st then
            continue;
          pd:=TProcDef(def);
          case pd.synthetickind of
            tsk_none:
              ;
            tsk_anon_inherited:
              implement_anon_inherited(pd);
            tsk_jvm_clone:
              implement_jvm_clone(pd);
            tsk_record_deepcopy:
              implement_record_deepcopy(pd);
            tsk_record_initialize:
              implement_record_initialize(pd);
            tsk_empty,
            { special handling for this one is done in tnodeutils.wrap_proc_body }
            tsk_tcinit:
              implement_empty(pd);
            tsk_callthrough:
              implement_callthrough(pd);
            tsk_callthrough_nonabstract:
              begin
                if (pd.owner.defowner.typ<>objectdef) or
                   (TObjectDef(pd.owner.defowner).abstractcnt=0) then
                  implement_callthrough(pd)
                else
                  implement_empty(pd);
              end;
            tsk_jvm_enum_values,
            tsk_jvm_enum_valueof,
            tsk_jvm_enum_classconstr,
            tsk_jvm_enum_jumps_constr,
            tsk_jvm_enum_fpcordinal,
            tsk_jvm_enum_fpcvalueof,
            tsk_jvm_enum_long2set,
            tsk_jvm_enum_bitset2set,
            tsk_jvm_enum_set2set,
            tsk_jvm_procvar_invoke,
            tsk_jvm_procvar_intconstr,
            tsk_jvm_virtual_clmethod:
              InternalError(2011032801);
            tsk_wasm_suspending_first,
            tsk_wasm_suspending_last,
            tsk_wasm_promising:
              InternalError(2023061107);
            tsk_field_getter:
              implement_field_getter(pd);
            tsk_field_setter:
              implement_field_setter(pd);
            tsk_block_invoke_procvar:
              implement_block_invoke_procvar(pd);
            tsk_interface_wrapper:
              implement_interface_wrapper(pd);
            tsk_call_no_parameters:
              implement_call_no_parameters(pd);
            tsk_invoke_helper:
              begin
                if (pd.owner.defowner) is TObjectDef  then
                  cn:=TObjectDef(def.owner.defowner).GetTypeName
                else
                  InternalError(2023061107);
                implement_invoke_helper(cn,pd,i);
              end;
          end;
        end;
    end;

  function get_method_paramtype(vardef  : TDef; asPointer : Boolean; out isAnonymousArrayDef : Boolean) : AnsiString;

  var
    p : integer;
    arrdef : TArrayDef absolute vardef;

  begin
    {
      None of the existing routines fulltypename,OwnerHierarchyName,FullOwnerHierarchyName,typename
      results in a workable definition for open array parameters.
    }
    isAnonymousArrayDef:=false;
    if asPointer and (vardef.typ=formaldef) then
      exit('pointer');
    if (vardef is TProcVarDef) then
      begin
      result:=vardef.fullownerhierarchyname(false,false);
      if Assigned(vardef.typesym) then
        Result:=Result+(vardef.typesym.Name);
      end
    else if not (vardef is TArrayDef) then
      result:=vardef.fulltypename
    else
      begin
      if (ado_isarrayofconst in arrdef.arrayoptions) then
        begin
          if asPointer then
            Result:='Array of TVarRec'
          else
            result:='Array Of Const';
          asPointer:=False;
          isAnonymousArrayDef:=true;
        end
      else if (ado_OpenArray in arrdef.arrayoptions) then
        begin
        result:='Array of '+arrdef.elementdef.fulltypename;
        asPointer:=False;
        isAnonymousArrayDef:=true;
        end
      else
        begin
        result:=vardef.fulltypename;
        end;
      end;
    // ansistring(0) -> ansistring
    p:=pos('(',result);
    if p=0 then
      p:=pos('[',result);
    if p>0 then
      result:=copy(result,1,p-1);
    if asPointer then
      Result:='^'+Result;
  end;

  function get_method_paramtype(vardef  : TDef; asPointer : Boolean) : AnsiString;

  var
    ad : boolean;

  begin
    result:=get_method_paramtype(vardef,aspointer,ad);
  end;

  function create_intf_method_args(p : TProcDef; out argcount: integer) : AnsiString;

  const
    varspezprefixes : array[TVarSpez] of shortstring =
      ('','const','var','out','constref','final');
  var
    i : integer;
    s : string;
    para : TParaVarSym;


  begin
    result:='';
    argCount:=0;
    for i:=0 to p.paras.Count-1 do
      begin
      para:=TParaVarSym(p.paras[i]);
      if vo_is_hidden_para in para.varoptions then
        continue;
      if Result<>'' then
        Result:=Result+';';
      inc(argCount);
      result:=result+varspezprefixes[para.varspez]+' p'+ToStr(argcount);
      if Assigned(para.vardef) and not (para.vardef is TFormalDef) then
        result:=Result+' : '+get_method_paramtype(para.vardef,false);
      end;
    if Result<>'' then
      Result:='('+Result+')';
  end;

  function generate_thunkclass_name(acount: Integer; objdef : TObjectDef) : shortstring;

  var
    cn : shortstring;
    i : integer;

  begin
    cn:=ObjDef.GetTypeName;
    for i:=0 to Length(cn) do
      begin
      if cn[i]='.' then
        cn[i]:='_'
      else if (cn[i]='<') or (cn[i]='>') then
        cn[i]:='_';
      end;
    result:='_t_hidden'+ToStr(acount)+cn;
  end;

  function get_thunkclass_interface_vmtoffset(objdef : TObjectDef) : integer;

  var
    i,j,offs : integer;
    sym : TSym;
    proc : TProcSym absolute sym;
    pd : TProcDef;

  begin
    offs:=maxint;
    for I:=0 to objdef.SymTable.symList.Count-1 do
      begin
      sym:=TSym(objdef.SymTable.symList[i]);
      if Not Assigned(sym) then
        continue;
      if (Sym.typ<>procsym) then
        continue;
      for j:=0 to proc.ProcdefList.Count-1 do
        begin
        pd:=TProcDef(proc.ProcdefList[j]);
        if pd.extnumber<offs then
          offs:=pd.extnumber;
        end;
      end;
      if offs=maxint then
        offs:=0;
      result:=offs;
    end;


  // return parent Interface def, but skip iunknown.

  function getparent_interface_def(odef : TObjectDef) : TObjectDef;

  begin
    if (odef.getparentdef is TObjectDef) then
      begin
      result:=odef.getparentdef as TObjectDef;
      if result=interface_iunknown then
        result:=Nil;
      end
    else
      result:=nil;
  end;

  procedure implement_interface_thunkclass_decl(cn : shortstring; objdef : TObjectDef);

  var
    parentname,str : AnsiString;
    sym : TSym;
    proc : TProcSym absolute sym;
    pd : TProcDef;
    odef,def : TObjectDef;
    offs,argcount,i,j : integer;
    intfDef : TObjectDef;
  begin
    str:='type '#10;
    odef:=getparent_interface_def(objdef);
    if (oDef=Nil) or (oDef.hiddenclassdef=Nil) then
      parentname:='TInterfaceThunk'
    else
      parentname:=odef.hiddenclassdef.GetTypeName;
    str:=str+cn+' = class('+parentname+','+objdef.GetTypeName+')'#10;
    str:=str+' protected '#10;
    Intfdef:=objdef;
    Repeat
      if not IntfDef.is_generic then
        for I:=0 to intfdef.SymTable.symList.Count-1 do
          begin
          sym:=TSym(intfdef.SymTable.symList[i]);
          if Not Assigned(sym) then
            continue;
          if (Sym.typ<>procsym) then
            continue;
          for j:=0 to proc.ProcdefList.Count-1 do
            begin
            pd:=TProcDef(proc.ProcdefList[j]);
            if pd.returndef<>voidtype then
              str:=str+'function '
            else
              str:=str+'procedure ';
            str:=str+proc.RealName;
            str:=str+create_intf_method_args(pd,argcount);
            if pd.returndef<>voidtype then
              str:=str+' : '+get_method_paramtype(pd.returndef,false);
            str:=str+';'#10;
            end;
          end;
      // Check parent class
      intfdef:=getparent_interface_def(intfdef);
      // If we already have a hidden class def for it, no need to continue
      if (IntfDef<>nil) and (IntfDef.hiddenclassdef<>nil) then
        IntfDef:=Nil;
    until intfdef=nil;
    offs:=get_thunkclass_interface_vmtoffset(objdef);
    if offs>0 then
      begin
      str:=str+'public '#10;
      str:=str+'  function InterfaceVMTOffset : word; override;'#10;
      end;
    str:=str+' end;'#10;
    def:=str_parse_objecttypedef(cn,str);
    if Assigned(def) then
      begin
      def.created_in_current_module:=true;
      if not def.typesym.IsRegistered then
        def.typesym.RegisterSym;
      def.buildderef;
      include(def.objectoptions,oo_can_have_published);
      end;
    objdef.hiddenclassdef:=def;
  end;

  function str_parse_method(str: AnsiString; allowgenericid : boolean): TProcDef;
   var
     oldparse_only: boolean;
     tmpstr: AnsiString;
     flags : TReadProcFlags;
     oldallow : boolean;

   begin
    Message1(parser_d_internal_parser_string,str);
    oldparse_only:=parse_only;
    parse_only:=false;
    { "const" starts a new kind of block and hence makes the scanner return }
    str:=str+'const;';
    Block_Type:=bt_none;
    { inject the string in the scanner }
    oldallow:=CurrentScanner.allowgenericid;
    CurrentScanner.allowgenericid:=allowgenericid;
    CurrentScanner.substitutemacro('hidden_interface_method',@str[1],length(str),CurrentScanner.line_no,CurrentScanner.inputfile.RefIndex,true);
    CurrentScanner.readtoken(false);
    Result:=read_proc([],Nil);
    parse_only:=oldparse_only;
    { remove the temporary macro input file again }
    CurrentScanner.closeinputfile;
    CurrentScanner.nextfile;
    CurrentScanner.tempopeninputfile;
    CurrentScanner.allowgenericid:=oldallow;
   end;


  procedure implement_interface_thunkclass_impl_method(cn : shortstring; objdef : TObjectDef; proc : TProcSym; pd : TProcDef);

  var
    rest,str : AnsiString;
    pn,d : shortstring;
    sym : TSym;
    aArg,argcount,i : integer;
    haveresult : boolean;
    para : TParaVarSym;
    hasopenarray, washigh: Boolean;

  begin
    rest:='';
    str:='';
    if pd.returndef<>voidtype then
      str:=str+'function '
    else
      str:=str+'procedure ';
    pn:=proc.RealName;
    str:=str+cn+'.'+pn;
    str:=str+create_intf_method_args(pd,argcount);
    haveresult:=pd.returndef<>voidtype;
    if haveresult then
      begin
      rest:=get_method_paramtype(pd.returndef,false);
      str:=str+' : '+rest;
      end;
    str:=str+';'#10;
    str:=str+'var '#10;
    str:=str+'  data : array[0..'+ToStr(argcount)+'] of System.TInterfaceThunk.TArgData;'#10;
    if haveresult then
      str:=str+'  res : '+rest+';'#10;
    str:=str+'begin'#10;
    // initialize result.
    if HaveResult then
      begin
      str:=Str+'  data[0].addr:=@Res;'#10;
      str:=Str+'  data[0].info:=TypeInfo(Res);'#10;
      end
    else
      begin
      str:=Str+'  data[0].addr:=nil;'#10;
      str:=Str+'  data[0].idx:=-1;'#10;
      end;
    str:=Str+'  data[0].idx:=-1;'#10;
    str:=Str+'  data[0].ahigh:=-1;'#10;
    // Fill rest of data
    aArg:=0;
    washigh:=false;
    d:='0';
    for i:=0 to pd.paras.Count-1 do
      begin
      para:=TParaVarSym(pd.paras[i]);
      // previous was open array. Record high
      if (i>1) then
        begin
        WasHigh:=(vo_is_high_para in para.varoptions);
        if Washigh then
          // D is still value of previous (real) parameter
          str:=str+'  data['+d+'].ahigh:=High(p'+d+');'#10
        else
          str:=str+'  data['+d+'].ahigh:=-1;'#10;
        end;
      if vo_is_hidden_para in para.varoptions then
        continue;
      inc(aArg);
      d:=ToStr(aArg);
      Str:=Str+'  data['+d+'].addr:=@p'+d+';'#10;
      Str:=Str+'  data['+d+'].idx:='+ToStr(i)+';'#10;
      if Assigned(para.vardef) and not (para.vardef is TFormalDef) then
        Str:=Str+'  data['+d+'].info:=TypeInfo(p'+d+');'#10
      else
        Str:=Str+'  data['+d+'].info:=Nil;'#10
      end;
    // if last was not high, set to sentinel.
    if not WasHigh then
      str:=str+'  data['+d+'].ahigh:=-1;'#10;
    str:=str+'  Thunk('+ToStr(pd.extnumber)+','+ToStr(argcount)+',@Data);'#10;
    if HaveResult then
      str:=str+'  Result:=res;'#10;
    str:=str+'end;'#10;
    pd:=str_parse_method(str,true);
  end;

  procedure implement_thunkclass_interfacevmtoffset(cn : shortstring; objdef : TObjectDef; offs : integer);

  var
    str : AnsiString;
  begin
    str:='function '+cn+'.InterfaceVMTOffset : word;'#10;
    str:=str+'begin'#10;
    str:=str+'  result:='+ToStr(offs)+';'#10;
    str:=str+'end;'#10;
    str_parse_method(str);
  end;


  procedure implement_interface_thunkclass_impl(cn: shortstring; objdef : TObjectDef);

  var
    str : AnsiString;
    sym : TSym;
    proc : TProcSym absolute sym;
    pd : TProcDef;
    offs,i,j : integer;
    intfDef : TObjectDef;

  begin
    offs:=get_thunkclass_interface_vmtoffset(objdef);
    if offs>0 then
      implement_thunkclass_interfacevmtoffset(cn,objdef,offs);
    intfDef:=objdef;
    repeat
      for I:=0 to intfdef.SymTable.symList.Count-1 do
        begin
        sym:=TSym(intfdef.SymTable.symList[i]);
        if Not Assigned(sym) then
          continue;
        if (Sym.typ<>procsym) then
          continue;
        for j:=0 to proc.ProcdefList.Count-1 do
          begin
          pd:=TProcDef(proc.ProcdefList[j]);
          implement_interface_thunkclass_impl_method(cn,intfdef,proc,pd);
          end;
        end;
      // Check parent class.
      intfdef:=getparent_interface_def(intfdef);
      // If we already have a hidden class def for it, no need to continue
      if (intfdef<>Nil) and (IntfDef.hiddenclassdef<>nil) then
        IntfDef:=Nil;
    until (intfdef=Nil);
  end;

  procedure add_synthetic_interface_classes_for_st(st : TSymTable; gen_intf, gen_impl : boolean);

  var
    i   : LongInt;
    def : TDef;
    objdef : TObjectDef absolute def;
    recdef : TRecordDef absolute def;
    sstate: TScannerState;
    cn : shortstring;
    isDelphiMode : boolean;
    oldsettings: TModeSwitches;

  begin
    { skip if any errors have occurred, since then this can only cause more
      errors }
    if ErrorCount<>0 then
      exit;
    isDelphiMode:=(m_delphi in CurrentSettings.ModeSwitches);
    replace_scanner('hiddenclass_impl',sstate);
    sstate.new_scanner.allowgenericid:=true;
    if isDelphiMode then
      begin
      oldsettings:=CurrentSettings.ModeSwitches;
      CurrentSettings.ModeSwitches:=CurrentSettings.ModeSwitches+[m_delphi]-[m_objfpc];
      end;
    for i:=0 to st.deflist.count-1 do
      begin
      def:=TDef(st.deflist[i]);
      if (def.typ<>objectdef) then
        continue;
      if not (objdef.objecttype in objecttypes_with_thunk) then
        continue;
      if not (oo_can_have_published in objdef.objectoptions) then
        continue;
      // need to add here extended rtti check when it is available
      cn:=generate_thunkclass_name(i,objdef);
      if gen_intf then
        implement_interface_thunkclass_decl(cn,objdef);
      if gen_impl then
        implement_interface_thunkclass_impl(cn,objdef);
      end;
    restore_scanner(sstate);
    // Recurse for interfaces defined in a type section of a class/record.
    for i:=0 to st.deflist.count-1 do
      begin
      def:=TDef(st.deflist[i]);
      if (def.typ=objectdef) and (objdef.objecttype=odt_class) then
        add_synthetic_interface_classes_for_st(objdef.SymTable,gen_intf,gen_impl)
      else if (def.typ=recorddef) and (m_advanced_records in CurrentSettings.ModeSwitches) then
        add_synthetic_interface_classes_for_st(recdef.SymTable,gen_intf,gen_impl);
      end;
  end;

  procedure add_synthetic_method_implementations(st: TSymTable);
    var
      i: LongInt;
      def: TDef;
      sstate: TScannerState;
    begin
      { skip if any errors have occurred, since then this can only cause more
        errors }
      if ErrorCount<>0 then
        exit;
      replace_scanner('synthetic_impl',sstate);
      add_synthetic_method_implementations_for_st(st);
      for i:=0 to st.deflist.count-1 do
        begin
          def:=TDef(st.deflist[i]);
          if (def.typ=procdef) and
             Assigned(TProcDef(def).localst) and
             { not true for the "main" procedure, whose localsymtable is the staticsymtable }
             (TProcDef(def).localst.symtabletype=localsymtable) then
            add_synthetic_method_implementations(TProcDef(def).localst)
          else if ((def.typ=objectdef) and
                   not(oo_is_external in TObjectDef(def).objectoptions) and
                   { we must not create duplicate synthetic methods for a unique
                     type declaration as that simply shares the VMT of the aliased
                     types }
                   not(TObjectDef(def).is_unique_objpasdef)) or
                  (def.typ=recorddef) then
           begin
            { also complete nested types }
            add_synthetic_method_implementations(TAbstractRecordDef(def).SymTable);
           end;
        end;
      restore_scanner(sstate);
    end;


  function create_procdef_alias(pd: TProcDef; const newrealname: string; const newmangledname: TSymStr; newparentst: TSymTable; newstruct: TAbstractRecordDef;
      sk: TSyntheticKind; skpara: pointer): TProcDef;
    begin
      { bare copy so we don't copy the aliasnames (specify prefix for
        parameter names so we don't get issues in the body in case
        we e.g. reference system.initialize and one of the parameters
        is called "system") }
      result:=TProcDef(pd.getcopyas(procdef,pc_bareproc,'__FPCW_',true));
      { set the mangled name to the wrapper name }
      result.setmangledname(newmangledname);
      { finish creating the copy }
      finish_copied_procdef(result,newrealname,newparentst,newstruct);
      { insert hidden high parameters }
      result.parast.SymList.ForEachCall(@insert_hidden_para,result);
      { now insert self/vmt }
      insert_self_and_vmt_para(result);
      { and the function result }
      insert_funcret_para(result);
      { recalculate the parameters now that we've added the missing ones }
      result.calcparas;
      { set the info required to generate the implementation }
      result.synthetickind:=sk;
      result.skpara:=skpara;
    end;


  procedure finish_copied_procdef(var pd: TProcDef; const realname: string; newparentst: TSymTable; newstruct: TAbstractRecordDef);
    var
      sym: TSym;
      parasym: TParaVarSym;
      ps: TProcSym;
      stname: string;
      i: LongInt;
    begin
      { add generic flag if required }
      if Assigned(newstruct) and
         (df_generic in newstruct.defoptions) then
        include(pd.defoptions,df_generic);
      { associate the procdef with a procsym in the owner }
      if not(pd.proctypeoption in [potype_class_constructor,potype_class_destructor]) then
        stname:=upper(realname)
      else
        stname:=lower(realname);
      sym:=TSym(newparentst.find(stname));
      if Assigned(sym) then
        begin
          if sym.typ<>procsym then
            InternalError(2011040601);
          ps:=TProcSym(sym);
        end
      else
        begin
          ps:=CProcSym.create(realname);
          newparentst.insertsym(ps);
        end;
      pd.procsym:=ps;
      pd.struct:=newstruct;
      { in case of methods, replace the special parameter types with new ones }
      if Assigned(newstruct) then
        begin
          SymTableStack.push(pd.parast);
          { may not be assigned in case we converted a procvar into a procdef }
          if Assigned(pd.paras) then
            begin
              for i:=0 to pd.paras.count-1 do
                begin
                  parasym:=TParaVarSym(pd.paras[i]);
                  if vo_is_self in parasym.varoptions then
                    begin
                      if parasym.vardef.typ=classrefdef then
                        parasym.vardef:=CClassRefDef.create(newstruct)
                      else
                        parasym.vardef:=newstruct;
                    end
                end;
            end;
          { also fix returndef in case of a constructor }
          if pd.proctypeoption=potype_constructor then
            pd.returndef:=newstruct;
          SymTableStack.pop(pd.parast);
        end;
      pd.calcparas;
      proc_add_definition(pd);
    end;


  function maybe_add_sym_to_parentfpstruct(pd: TProcDef; sym: TSym; vardef: TDef; addrparam: boolean): TSym;
    var
      fieldvardef,
      nestedvarsdef: TDef;
      nestedvarsst: TSymTable;
      initcode: TNode;
      old_filepos: TFilePosInfo;
      symname,
      symrealname: TSymStr;
      highsym: TAbstractVarSym;
    begin
      nestedvarsdef:=TLocalVarSym(pd.parentfpstruct).vardef;
      { redirect all aliases for the function result also to the function
        result }
      if vo_is_funcret in TAbstractVarSym(sym).varoptions then
        begin
          symname:='result';
          symrealname:='$result'
        end
      else
        begin
          symname:=sym.name;
          symrealname:=sym.EscapedRealName;
        end;
      result:=search_struct_member(TRecordDef(nestedvarsdef),symname);
      if not Assigned(result) then
        begin
          { mark that this symbol is mirrored in the parentfpstruct }
          TAbstractNormalVarSym(sym).inparentfpstruct:=true;
          { add field to the struct holding all locals accessed
            by nested routines }
          nestedvarsst:=TRecordDef(nestedvarsdef).SymTable;
          { indicate whether or not this is a var/out/constref/... parameter }
          if addrparam then
            fieldvardef:=CPointerDef.getreusable(vardef)
          else
            fieldvardef:=vardef;
          result:=CFieldVarSym.create(symrealname,vs_value,fieldvardef,[]);
          nestedvarsst.insertsym(result);
          TRecordSymTable(nestedvarsst).addfield(TFieldVarSym(result),vis_public);

          { add initialization with original value if it's a parameter }
          if (sym.typ=paravarsym) then
            begin
              old_filepos:=CurrentFilePos;
              fillchar(CurrentFilePos,sizeof(CurrentFilePos),0);
              initcode:=CLoadNode.create(sym,sym.owner);
              { indicate that this load should not be transformed into a load
                from the parentfpstruct, but instead should load the original
                value }
              include(initcode.flags,nf_internal);
              { in case it's a var/out/constref parameter, store the address of the
                parameter in the struct }
              if addrparam then
                begin
                  initcode:=CAddrNode.create_internal(initcode);
                  include(TAddrNode(initcode).addrnodeflags,anf_typedaddr);
                end;
              initcode:=CAssignmentNode.create(
                CSubscriptNode.create(result,CLoadNode.create(pd.parentfpstruct,pd.parentfpstruct.owner)),
                initcode);
              TBlockNode(pd.parentfpinitblock).left:=CStatementNode.create
                (initcode,TBlockNode(pd.parentfpinitblock).left);
              CurrentFilePos:=old_filepos;

              { also add the associated high para, if any. It may not be accessed
                during code generation, and we need to catch 'em all (TM) during
                the typecheck/firstpass }
              highsym:=get_high_value_sym(TParaVarSym(sym));
              if Assigned(highsym) then
                maybe_add_sym_to_parentfpstruct(pd, highsym, highsym.vardef, false);
            end;
        end;
    end;


  procedure redirect_parentfpstruct_local_syms(pd: TProcDef);
    var
      nestedvarsdef: TRecordDef;
      sl: TPropAccessList;
      fsym,
      lsym,
      aliassym: TSym;
      i: LongInt;
    begin
      nestedvarsdef:=TRecordDef(TLocalVarSym(pd.parentfpstruct).vardef);
      for i:=0 to nestedvarsdef.SymTable.symlist.count-1 do
        begin
          fsym:=TSym(nestedvarsdef.SymTable.symlist[i]);
          if fsym.typ<>fieldvarsym then
            continue;
          lsym:=TSym(pd.localst.find(fsym.name));
          if not Assigned(lsym) then
            lsym:=TSym(pd.parast.find(fsym.name));
          if not Assigned(lsym) then
            InternalError(2011060408);
          { add an absolute variable that redirects to the field }
          sl:=TPropAccessList.create;
          sl.addsym(sl_load,pd.parentfpstruct);
          sl.addsym(sl_subscript,TFieldVarSym(fsym));
          aliassym:=CAbsoluteVarSym.create_ref(lsym.EscapedRealName,TFieldVarSym(fsym).vardef,sl);
          { hide the original variable (can't delete, because there
            may be other loadnodes that reference it)
            -- only for locals; hiding parameters changes the
            function signature }
          if lsym.typ<>paravarsym then
            hidesym(lsym);
          { insert the absolute variable in the localst of the
            routine; ignore duplicates, because this will also check the
            parasymtable and we want to override parameters with our local
            versions }
          pd.localst.insertsym(aliassym,false);
        end;
    end;


  function find_sym_in_parentfpstruct(pd: TProcDef; sym: TSym): TSym;
    var
      nestedvarsdef: TDef;
    begin
      nestedvarsdef:=TLocalVarSym(pd.parentfpstruct).vardef;
      result:=search_struct_member(TRecordDef(nestedvarsdef),sym.name);
    end;


  procedure finish_parentfpstruct(pd: TProcDef);
    begin
      TRecordSymTable(TRecordDef(TLocalVarSym(pd.parentfpstruct).vardef).SymTable).addalignmentpadding;
    end;


  function make_field_static(recst: TSymTable; fieldvs: TFieldVarSym): TStaticVarSym;
    var
      static_name: string;
      hstaticvs: TStaticVarSym;
      tmp: TAbsoluteVarSym;
      sl: TPropAccessList;
    begin
      include(fieldvs.symoptions,sp_static);
      { generate the symbol which reserves the space }
      static_name:=lower(generate_nested_name(recst,'_'))+'_'+fieldvs.name;
      hstaticvs:=CStaticVarSym.create_from_fieldvar(static_name,fieldvs);
      include(hstaticvs.symoptions,sp_internal);
      if df_generic in TDef(recst.defowner).defoptions then
        TAbstractRecordSymTable(recst).insertsym(hstaticvs)
      else
        TDef(TAbstractRecordSymTable(recst).defowner).GetTopLevelSymTable(false).insertsym(hstaticvs);
      { generate the symbol for the access }
      sl:=TPropAccessList.create;
      sl.addsym(sl_load,hstaticvs);
      { do *not* change the visibility of this absolutevarsym from vis_public
        to anything else, because its visibility is used by visibility checks
        after turning a class property referring to a class variable into a
        load node (handle_staticfield_access -> searchsym_in_class ->
        is_visible_for_object), which means that the load will fail if this
        symbol is e.g. "strict private" while the property is public }
      tmp:=CAbsoluteVarSym.create_ref('$'+static_name,fieldvs.vardef,sl);
      recst.insertsym(tmp);
      result:=hstaticvs;
    end;


  procedure call_through_new_name(orgpd: TProcDef; const newname: TSymStr);
    var
      newpd: TProcDef;
    begin
      { we have a forward declaration like
         procedure test; (in the unit interface or "forward")
        and then an implementation like
         procedure test; external name 'something';

        To solve this, we create a new external procdef for the
        implementation, and then generate a procedure body for the original
        one that calls through to the external procdef. This is necessary
        because there may already be references to the mangled name for the
        non-external "test".
      }

      { prefixing the parameters here is useless, because the new procdef will
        just be an external declaration without a body }
      newpd:=TProcDef(orgpd.getcopyas(procdef,pc_bareproc,'',true));
      insert_funcret_para(newpd);
      newpd.procoptions:=newpd.procoptions+orgpd.procoptions*[po_external,po_has_importname,po_has_importdll];
      StringDispose(orgpd.import_name);
      StringDispose(orgpd.import_dll);
      orgpd.import_nr:=0;
      newpd.setmangledname(newname);
      finish_copied_procdef(newpd,'__FPC_IMPL_EXTERNAL_REDIRECT_'+newname,CurrentModule.localsymtable,nil);
      newpd.forwarddef:=false;
      { ideally we would prefix the parameters of the original routine here, but since it
        can be an interface definition, we cannot do that without risking to change the
        interface crc }
      orgpd.skpara:=newpd;
      orgpd.synthetickind:=tsk_callthrough;
      orgpd.procoptions:=orgpd.procoptions-[po_external,po_has_importname,po_has_importdll];
      orgpd.forwarddef:=true;
    end;


  function generate_pkg_stub(pd:TProcDef):TNode;
    var
      stat: TStatementNode;
      handlevar: TStaticVarSym;
      instance: TSym;
    begin
      if TargetInfo.system in systems_all_windows then
        begin
          insert_funcret_local(pd);
          result:=internalstatements(stat);
          if TargetInfo.system=system_x86_64_win64 then
            begin
              handlevar:=CStaticVarSym.create_C('FPC_PACKAGE_HANDLE','FPC_PACKAGE_HANDLE',
                vs_value,sizeuinttype);
              include(handlevar.varoptions,vo_is_external);
              CurrentModule.localsymtable.insertsym(handlevar);
              instance:=TSym(pd.parast.find('HINSTANCE'));
              addstatement(stat,CAssignmentNode.create(
                CLoadNode.create(handlevar,handlevar.owner),
                CLoadNode.create(instance,pd.parast)));
            end;
          addstatement(stat,CAssignmentNode.create(
                      CLoadNode.create(pd.funcretsym,pd.localst),
                      COrdConstNode.create(1,bool32type,false)
                    ));
        end
      else
        result:=CNothingNode.create;
    end;

  procedure generate_attr_constrs(attrs:TFPObjectList);
    var
      ps : TProcSym;
      pd : TProcDef;
      pi : TCGProcInfo;
      i : sizeint;
      attr : TRTTIAttribute;
    begin
      if attrs.count=0 then
        exit;
      { if this isn't set then this unit shouldn't have any attributes }
      if not Assigned(class_tcustomattribute) then
        InternalError(2019071003);
      for i:=0 to attrs.count-1 do
        begin
          attr:=TRTTIAttribute(attrs[i]);
          {Generate a procsym for main}
          ps:=CProcSym.create('$rttiattrconstr$'+ToStr(i));
          { always register the symbol }
          ps.RegisterSym;
          { the RTTI always references this symbol }
          inc(ps.refs);
          CurrentModule.localsymtable.insertsym(ps);
          pd:=CProcDef.create(normal_function_level,true);
          { always register the def }
          pd.RegisterDef;
          pd.procsym:=ps;
          ps.ProcdefList.Add(pd);
          { set procdef options }
          pd.proctypeoption:=potype_function;
          pd.proccalloption:=pocall_default;
          include(pd.procoptions,po_hascallingconvention);
          pd.returndef:=class_tcustomattribute;
          insert_funcret_para(pd);
          pd.calcparas;
          pd.forwarddef:=false;
          pd.aliasnames.insert(pd.mangledname);
          handle_calling_convention(pd,hcc_default_actions_impl);
          { set procinfo and current_procinfo.procdef }
          pi:=TCGProcInfo(CProcInfo.create(nil));
          pi.procdef:=pd;
          { we always do a call, namely to the constructor }
          include(pi.flags,pi_do_call);
          insert_funcret_local(pd);
          pi.code:=CAssignmentNode.create(
                      CLoadNode.create(pd.funcretsym,pd.localst),
                      attr.constructorcall.getcopy
                    );
          pi.generate_code;
          attr.constructorpd:=pd;
        end;
    end;

end.

