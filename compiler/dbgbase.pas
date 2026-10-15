{
    Copyright (c) 2003-2006 by Peter Vreman and Florian Klaempfl

    This units contains the base class for debug info generation

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
unit dbgbase;

{$i fpcdefs.inc}

interface

    uses
      CClasses,
      Systems,
      parabase,
      symconst,SymBase,symdef,symtype,SymSym,
      FModule,
      aasmtai,AAsmData;

    type
      TDebugInfo=class
      protected
        { definitions }
        { collect all defs in one list so we can reset them easily }
        defnumberlist      : TFPObjectList;
        deftowritelist     : TFPObjectList;
        procedure appenddef(list:TAsmList;def:TDef);
        procedure beforeappenddef(list:TAsmList;def:TDef);virtual;
        procedure afterappenddef(list:TAsmList;def:TDef);virtual;
        procedure appenddef_ord(list:TAsmList;def:TOrdDef);virtual;
        procedure appenddef_float(list:TAsmList;def:TFloatDef);virtual;
        procedure appenddef_file(list:TAsmList;def:TFileDef);virtual;
        procedure appenddef_enum(list:TAsmList;def:TEnumDef);virtual;
        procedure appenddef_array(list:TAsmList;def:TArrayDef);virtual;
        procedure appenddef_record(list:TAsmList;def:TRecordDef);virtual;
        procedure appenddef_object(list:TAsmList;def:TObjectDef);virtual;
        procedure appenddef_classref(list:TAsmList;def: TClassRefDef);virtual;
        procedure appenddef_pointer(list:TAsmList;def:TPointerDef);virtual;
        procedure appenddef_string(list:TAsmList;def:TStringDef);virtual;
        procedure appenddef_procvar(list:TAsmList;def:TProcVarDef);virtual;
        procedure appenddef_variant(list:TAsmList;def:TVariantDef);virtual;
        procedure appenddef_set(list:TAsmList;def:TSetDef);virtual;
        procedure appenddef_formal(list:TAsmList;def:TFormalDef);virtual;
        procedure appenddef_undefined(list:TAsmList;def: TUndefinedDef);virtual;
        procedure appendprocdef(list:TAsmList;def:TProcDef);virtual;
        procedure write_remaining_defs_to_write(list:TAsmList);
        { symbols }
        procedure appendsym(list:TAsmList;sym:TSym);
        procedure beforeappendsym(list:TAsmList;sym:TSym);virtual;
        procedure afterappendsym(list:TAsmList;sym:TSym);virtual;
        procedure appendsym_staticvar(list:TAsmList;sym:TStaticVarSym);virtual;
        procedure appendsym_paravar(list:TAsmList;sym:TParaVarSym);virtual;
        procedure appendsym_localvar(list:TAsmList;sym:TLocalVarSym);virtual;
        procedure appendsym_fieldvar(list:TAsmList;sym:TFieldVarSym);virtual;
        procedure appendsym_unit(list:TAsmList;sym:TUnitSym);virtual;
        procedure appendsym_const(list:TAsmList;sym:TConstSym);virtual;
        procedure appendsym_type(list:TAsmList;sym:TTypeSym);virtual;
        procedure appendsym_label(list:TAsmList;sym:TLabelSym);virtual;
        procedure appendsym_absolute(list:TAsmList;sym:TAbsoluteVarSym);virtual;
        procedure appendsym_property(list:TAsmList;sym:TPropertySym);virtual;
        { symtable }
        procedure write_symtable_parasyms(list:TAsmList;paras: TParaList);
        procedure write_symtable_syms(list:TAsmList;st:TSymTable);
        procedure write_symtable_defs(list:TAsmList;st:TSymTable);
        procedure write_symtable_procdefs(list:TAsmList;st:TSymTable);
        procedure reset_unit_type_info;
        procedure write_used_unit_type_info(list:TAsmList;hp:TModule);
      public
        constructor Create;virtual;
        procedure inserttypeinfo;virtual;
        procedure insertmoduleinfo;virtual;
        procedure insertlineinfo(list:TAsmList);virtual;
        procedure referencesections(list:TAsmList);virtual;
      end;
      TDebugInfoClass=class of TDebugInfo;

    var
      CDebugInfo : array[TDbg] of TDebugInfoClass;
      CurrentDebugInfo : TDebugInfo;

    procedure InitDebugInfo(hp:TModule; restore_current_debuginfo : boolean);
    procedure DoneDebugInfo(hp:TModule; out current_debuginfo_reset : boolean);
    procedure RegisterDebugInfo(const r:TDbgInfo;c:TDebugInfoClass);


implementation

    uses
      CUtils,
      Globals,
      Verbose,
      cgbase;


    constructor TDebugInfo.Create;
      begin
      end;


    procedure TDebugInfo.insertmoduleinfo;
      begin
      end;


    procedure TDebugInfo.inserttypeinfo;
      begin
      end;


    procedure TDebugInfo.insertlineinfo(list:TAsmList);
      begin
      end;


    procedure TDebugInfo.referencesections(list:TAsmList);
      begin
      end;


{**************************************
          Definition
**************************************}

    procedure TDebugInfo.appendprocdef(list:TAsmList;def:TProcDef);
      begin
      end;


    procedure TDebugInfo.beforeappenddef(list:TAsmList;def:TDef);
      begin
      end;


    procedure TDebugInfo.afterappenddef(list:TAsmList;def:TDef);
      begin
      end;


    procedure TDebugInfo.appenddef_ord(list:TAsmList;def:TOrdDef);
      begin
      end;


    procedure TDebugInfo.appenddef_float(list:TAsmList;def:TFloatDef);
      begin
      end;


    procedure TDebugInfo.appenddef_formal(list:TAsmList;def: TFormalDef);
      begin
      end;


    procedure TDebugInfo.appenddef_undefined(list:TAsmList;def: TUndefinedDef);
      begin
      end;


    procedure TDebugInfo.appenddef_set(list:TAsmList;def: TSetDef);
      begin
      end;


    procedure TDebugInfo.appenddef_object(list:TAsmList;def: TObjectDef);
      begin
      end;


    procedure TDebugInfo.appenddef_classref(list:TAsmList;def: TClassRefDef);
      begin
        appenddef_pointer(list,TPointerDef(pvmttype));
      end;


    procedure TDebugInfo.appenddef_variant(list:TAsmList;def: TVariantDef);
      begin
      end;


    procedure TDebugInfo.appenddef_enum(list:TAsmList;def:TEnumDef);
      begin
      end;


    procedure TDebugInfo.appenddef_file(list:TAsmList;def: TFileDef);
      begin
      end;


    procedure TDebugInfo.appenddef_array(list:TAsmList;def:TArrayDef);
      begin
      end;


    procedure TDebugInfo.appenddef_record(list:TAsmList;def:TRecordDef);
      begin
      end;


    procedure TDebugInfo.appenddef_pointer(list:TAsmList;def:TPointerDef);
      begin
      end;


    procedure TDebugInfo.appenddef_string(list:TAsmList;def:TStringDef);
      begin
      end;


    procedure TDebugInfo.appenddef_procvar(list:TAsmList;def:TProcVarDef);
      begin
      end;


    procedure TDebugInfo.appenddef(list:TAsmList;def:TDef);
      begin
        if (def.dbg_state in [dbg_state_writing,dbg_state_written]) then
          exit;
        { never write generic template defs }
        if df_generic in def.defoptions then
          begin
            def.dbg_state:=dbg_state_written;
            exit;
          end;
        { to avoid infinite loops }
        def.dbg_state := dbg_state_writing;
        beforeappenddef(list,def);
        { queued defs have to be written later }
        if (def.dbg_state=dbg_state_queued) then
          exit;
        case def.typ of
          stringdef :
            appenddef_string(list,TStringDef(def));
          enumdef :
            appenddef_enum(list,TEnumDef(def));
          orddef :
            appenddef_ord(list,TOrdDef(def));
          pointerdef :
            appenddef_pointer(list,TPointerDef(def));
          floatdef :
            appenddef_float(list,TFloatDef(def));
          filedef :
            appenddef_file(list,TFileDef(def));
          recorddef :
            appenddef_record(list,TRecordDef(def));
          variantdef :
            appenddef_variant(list,TVariantDef(def));
          classrefdef :
            appenddef_classref(list,TClassRefDef(def));
          setdef :
            appenddef_set(list,TSetDef(def));
          formaldef :
            appenddef_formal(list,TFormalDef(def));
          arraydef :
            appenddef_array(list,TArrayDef(def));
          procvardef :
            appenddef_procvar(list,TProcVarDef(def));
          objectdef :
            appenddef_object(list,TObjectDef(def));
          undefineddef :
            appenddef_undefined(list,TUndefinedDef(def));
          procdef :
            begin
              { procdefs are already written in a separate step. procdef
                support in appenddef is only needed for beforeappenddef to
                write all local type defs }
            end;
        else
          InternalError(200601281);
        end;
        afterappenddef(list,def);
        def.dbg_state := dbg_state_written;
      end;


    procedure TDebugInfo.write_remaining_defs_to_write(list:TAsmList);
      var
        n       : integer;
        looplist,
        templist: TFPObjectList;
        def     : TDef;
      begin
        templist := TFPObjectList.Create(False);
        looplist := deftowritelist;
        while looplist.count > 0 do
          begin
            deftowritelist := templist;
            for n := 0 to looplist.count - 1 do
              begin
                def := TDef(looplist[n]);
                case def.dbg_state of
                  dbg_state_written:
                    continue;
                  dbg_state_writing:
                    InternalError(200610052);
                  dbg_state_unused:
                    InternalError(200610053);
                  dbg_state_used:
                    appenddef(list,def);
                  dbg_state_queued:
                    begin
                      { can happen in case an objectdef was used from another
                        unit that was compiled without debug info, and we are
                        using Stabs (which means that parent types have to be
                        written before child types). In this case, the child
                        objectdef will be queued and never written, because its
                        definition is not inside the current unit and hence will
                        not be encountered }
                      if def.typ<>objectdef then
                        InternalError(2012072401);
                      if not Assigned(TObjectDef(def).childof) or
                         (TObjectDef(def).childof.dbg_state=dbg_state_written) then
                        appenddef(list,def)
                      else if TObjectDef(def).childof.dbg_state=dbg_state_queued then
                        begin
                          { ensure that the parent is indeed queued }
                          deftowritelist.add(TObjectDef(def).childof);
                          deftowritelist.add(def);
                        end
                      else if TObjectDef(def).childof.dbg_state=dbg_state_used then
                        { comes somewhere after the current def in the looplist
                          and will be written at that point, so we will have to
                          wait until the next iteration }
                        deftowritelist.add(def)
                      else
                        InternalError(2012072402);
                    end;
                end;
              end;
            looplist.clear;
            templist := looplist;
            looplist := deftowritelist;
          end;
        templist.free;
        templist := nil;
      end;


{**************************************
          Symbols
**************************************}

    procedure TDebugInfo.beforeappendsym(list:TAsmList;sym:TSym);
      begin
      end;


    procedure TDebugInfo.afterappendsym(list:TAsmList;sym:TSym);
      begin
      end;


    procedure TDebugInfo.appendsym_staticvar(list:TAsmList;sym:TStaticVarSym);
      begin
      end;


    procedure TDebugInfo.appendsym_paravar(list:TAsmList;sym: TParaVarSym);
      begin
      end;


    procedure TDebugInfo.appendsym_localvar(list:TAsmList;sym: TLocalVarSym);
      begin
      end;


    procedure TDebugInfo.appendsym_fieldvar(list:TAsmList;sym: TFieldVarSym);
      begin
      end;


    procedure TDebugInfo.appendsym_const(list:TAsmList;sym:TConstSym);
      begin
      end;


    procedure TDebugInfo.appendsym_label(list:TAsmList;sym: TLabelSym);
      begin
      end;


    procedure TDebugInfo.appendsym_property(list:TAsmList;sym: TPropertySym);
      begin
      end;


    procedure TDebugInfo.appendsym_type(list:TAsmList;sym: TTypeSym);
      begin
      end;


    procedure TDebugInfo.appendsym_unit(list:TAsmList;sym: TUnitSym);
      begin
      end;


    procedure TDebugInfo.appendsym_absolute(list:TAsmList;sym:TAbsoluteVarSym);
      begin
      end;


    procedure TDebugInfo.appendsym(list:TAsmList;sym:TSym);
      begin
        if sym.isdbgwritten then
          exit;
        beforeappendsym(list,sym);
        case sym.typ of
          staticvarsym :
            if not Assigned(TStaticVarSym(sym).fieldvarsym) or
               not(df_generic in TDef(TStaticVarSym(sym).fieldvarsym.owner.defowner).defoptions) then
              appendsym_staticvar(list,TStaticVarSym(sym));
          unitsym:
            appendsym_unit(list,TUnitSym(sym));
          labelsym :
            appendsym_label(list,TLabelSym(sym));
          localvarsym :
            appendsym_localvar(list,TLocalVarSym(sym));
          paravarsym :
            if TParaVarSym(sym).localloc.loc<>LOC_VOID then
              appendsym_paravar(list,TParaVarSym(sym));
          constsym :
            appendsym_const(list,TConstSym(sym));
          typesym :
            appendsym_type(list,TTypeSym(sym));
          enumsym :
            { ignore enum syms, they are written by the owner }
            ;
          syssym :
            { ignore sys syms, they are only of internal use }
            ;
          procsym :
            { ignore proc syms, they are written by procdefs }
            ;
          absolutevarsym :
            appendsym_absolute(list,TAbsoluteVarSym(sym));
          propertysym :
            appendsym_property(list,TPropertySym(sym));
          namespacesym :
            { ignore namespace syms, they are only of internal use }
            ;
          else
            InternalError(200601242);
        end;
        afterappendsym(list,sym);
        sym.isdbgwritten:=true;
      end;


{**************************************
          Symtables
**************************************}

    procedure TDebugInfo.write_symtable_defs(list:TAsmList;st:TSymTable);
      var
        def : TDef;
        i   : LongInt;
        nonewadded : boolean;
      begin
        case st.symtabletype of
          staticsymtable :
            list.concat(TAIComment.Create(StrPNew('Defs - Begin Staticsymtable')));
          GlobalSymTable :
            list.concat(TAIComment.Create(StrPNew('Defs - Begin unit '+st.name^+' has index '+ToStr(st.ModuleID))));
          else
            ;
        end;
        repeat
          nonewadded:=true;
          for i:=0 to st.DefList.Count-1 do
            begin
              def:=TDef(st.DefList[i]);
              if (def.dbg_state in [dbg_state_used,dbg_state_queued]) then
                begin
                  appenddef(list,def);
                  nonewadded:=false;
                end;
            end;
        until nonewadded;
        case st.symtabletype of
          staticsymtable :
            list.concat(TAIComment.Create(StrPNew('Defs - End Staticsymtable')));
          GlobalSymTable :
            list.concat(TAIComment.Create(StrPNew('Defs - End unit '+st.name^+' has index '+ToStr(st.ModuleID))));
          else
            ;
        end;
      end;


    procedure TDebugInfo.write_symtable_parasyms(list:TAsmList;paras: TParaList);
      var
        i   : LongInt;
        sym : TSym;
      begin
        for i:=0 to paras.Count-1 do
          begin
            sym:=TSym(paras[i]);
            if (sym.visibility<>vis_hidden) then
              begin
                appendsym(list,sym);
                { if we ever write this procdef again for some reason (this
                  can happen with DWARF), then we want to write all the
                  parasyms again as well. }
                sym.isdbgwritten:=false;
              end;
          end;
      end;


    procedure TDebugInfo.write_symtable_syms(list:TAsmList;st:TSymTable);
      var
        i   : LongInt;
        sym : TSym;
      begin
        case st.symtabletype of
          staticsymtable :
            list.concat(TAIComment.Create(StrPNew('Syms - Begin Staticsymtable')));
          GlobalSymTable :
            list.concat(TAIComment.Create(StrPNew('Syms - Begin unit '+st.name^+' has index '+ToStr(st.ModuleID))));
          else
            ;
        end;
        for i:=0 to st.SymList.Count-1 do
          begin
            sym:=TSym(st.SymList[i]);
            if (sym.visibility<>vis_hidden) and
               (not sym.isdbgwritten) and
               { avoid all generic symbols }
               not (sp_generic_dummy in sym.symoptions) and
               not ((sym.typ=typesym) and Assigned(TTypeSym(sym).typedef) and
                    (df_generic in TTypeSym(sym).typedef.defoptions)) then
              appendsym(list,sym);
          end;
        case st.symtabletype of
          staticsymtable :
            list.concat(TAIComment.Create(StrPNew('Syms - End Staticsymtable')));
          GlobalSymTable :
            list.concat(TAIComment.Create(StrPNew('Syms - End unit '+st.name^+' has index '+ToStr(st.ModuleID))));
          else
            ;
        end;
      end;


    procedure TDebugInfo.write_symtable_procdefs(list:TAsmList;st:TSymTable);
      var
        i   : LongInt;
        def : TDef;
      begin
        for i:=0 to st.DefList.Count-1 do
          begin
            def:=TDef(st.DefList[i]);
            case def.typ of
              procdef :
                begin
                  appendprocdef(list,TProcDef(def));
                  if Assigned(TProcDef(def).localst) then
                    write_symtable_procdefs(list,TProcDef(def).localst);
                end;
              objectdef,recorddef :
                begin
                  write_symtable_procdefs(list,TAbstractRecordDef(def).SymTable);
                end;
              else
                ;
            end;
          end;
      end;


    procedure TDebugInfo.reset_unit_type_info;
      var
        hp : TModule;
      begin
        hp:=TModule(loaded_units.first);
        while Assigned(hp) do
          begin
            hp.is_dbginfo_written:=false;
            hp:=TModule(hp.next);
          end;
      end;


    procedure TDebugInfo.write_used_unit_type_info(list:TAsmList;hp:TModule);
      var
        pu : TUsedUnit;
      begin
        pu:=TUsedUnit(hp.used_units.first);
        while Assigned(pu) do
          begin
            if not pu.u.is_dbginfo_written and not Assigned(pu.u.package) then
              begin
                { prevent infinite loop for circular dependencies }
                pu.u.is_dbginfo_written:=true;
                { write type info from used units, use a depth first
                  strategy to reduce the recursion in writing all
                  dependent stabs }
                write_used_unit_type_info(list,pu.u);
                if Assigned(pu.u.GlobalSymTable) then
                  write_symtable_defs(list,pu.u.GlobalSymTable);
              end;
            pu:=TUsedUnit(pu.next);
          end;
      end;


{****************************************************************************
                           Init / Done
****************************************************************************}

    procedure InitDebugInfo(hp:TModule; restore_current_debuginfo : boolean);
      begin
        if not Assigned(CDebugInfo[TargetDbg.id]) then
          begin
            Comment(VFatal,'cg_f_debuginfo_output_not_supported');
            exit;
          end;

        hp.DebugInfo:=CDebugInfo[TargetDbg.id].Create;

        if restore_current_debuginfo then
          begin
            if CurrentDebugInfo=nil then
              CurrentDebugInfo:=TDebugInfo(hp.DebugInfo)
            else
              InternalError(2012032101);
          end;
      end;


    procedure DoneDebugInfo(hp:TModule; out current_debuginfo_reset : boolean);
      begin
        current_debuginfo_reset:=false;
        if Assigned(hp.DebugInfo) then
          begin
            if hp.DebugInfo=CurrentDebugInfo then
              begin
                CurrentDebugInfo:=nil;
                current_debuginfo_reset:=true;
              end;
            hp.DebugInfo.Free;
            hp.DebugInfo:=nil;
          end;
      end;


    procedure RegisterDebugInfo(const r:TDbgInfo;c:TDebugInfoClass);
      var
        t : TDbg;
      begin
        t:=r.id;
        if Assigned(dbginfos[t]) then
          WriteLn('Warning: DebugInfo is already registered!')
        else
          GetMem(dbginfos[t],sizeof(TDbgInfo));
        dbginfos[t]^:=r;
        CDebugInfo[t]:=c;
      end;


    const
      dbg_none_info : TDbgInfo =
         (
           id     : dbg_none;
           idtxt  : 'NONE';
         );

initialization
  RegisterDebugInfo(dbg_none_info,TDebugInfo);
end.
