{
    Copyright (c) 2018 by Jonas Maebe
    Copyright (c) 2011-2021 by Blaise.ru

    This unit provides helpers for creating procdefs

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
unit procdefutil;

interface

uses
  GlobType,ProcInfo,
  symconst,symtype,symdef,
  node,nbas;

{ create a nested procdef that will be used to outline code from a procedure;
  astruct should usually be nil, except in special cases like the Windows SEH
  exception handling funclets }
function create_outline_procdef(const basesymname: string; astruct: TAbstractRecordDef; potype: TProcTypeOption; resultdef: TDef): TProcDef;

procedure convert_to_funcref_intf(const n:TIDString;var def:TDef);
function adjust_funcref(var def:TDef;sym,DummySym:TSym):boolean;

{ functionality related to capturing local variables for anonymous functions }

function get_or_create_capturer(pd:TProcDef):TSym;
function capturer_add_anonymous_proc(owner:TProcInfo;pd:TProcDef;out capturer:TSym):TObjectDef;
function capturer_add_procvar_or_proc(owner:TProcInfo;n:TNode;out capturer:TSym;out capturen:TNode):TObjectDef;
procedure initialize_capturer(ctx:TProcInfo;var stmt:TStatementNode);
procedure postprocess_capturer(ctx:TProcInfo);
procedure convert_captured_syms(pd:TProcDef;tree:TNode);

implementation

  uses
    CUtils,CClasses,Verbose,Globals,
    FModule,
    pass_1,
    nobj,ncal,nmem,nld,nutils,
    ngenutil,
    SymBase,SymSym,SymTable,defutil,defcmp,
    htypechk,
    pparautl,psub;


  function create_outline_procdef(const basesymname: string; astruct: TAbstractRecordDef; potype: TProcTypeOption; resultdef: TDef): TProcDef;
    var
      st:TSymTable;
      checkstack: PSymTableStackItem;
      OldSymTableStack: TSymTableStack;
      sym:TProcSym;
    begin
      { get actual procedure symtable (skip withsymtables, etc.) }
      st:=nil;
      checkstack:=SymTableStack.stack;
      while Assigned(checkstack) do
        begin
          st:=checkstack^.SymTable;
          if st.SymTableType in [staticsymtable,GlobalSymTable,LocalSymTable] then
            break;
          checkstack:=checkstack^.next;
        end;
      { Create a nested procedure, even from main_program_level.
        Furthermore, force procdef and procsym into the same symtable
        (by default, defs are registered with symtablestack.top which may be
        something temporary like exceptsymtable - in that case, procdef can be
        destroyed before procsym, leaving invalid pointers). }
      OldSymTableStack:=SymTableStack;
      SymTableStack:=nil;
      result:=CProcDef.create(max(normal_function_level,st.SymTableLevel)+1,true);
      result.ReturnDef:=resultdef;
      { if the parent is a generic or a specialization, the new function is one
        as well }
      if st.SymTableType=LocalSymTable then
        result.DefOptions:=result.DefOptions+(TStoredDef(st.DefOwner).DefOptions*[df_generic,df_specialization]);
      SymTableStack:=OldSymTableStack;
      st.InsertDef(result);
      result.struct:=astruct;
      { tabstractprocdef constructor sets po_delphi_nested_cc whenever
        nested procvars modeswitch is active. We must be independent of this switch. }
      exclude(result.ProcOptions,po_delphi_nested_cc);
      result.ProcTypeOption:=potype;
      { always use the default calling convention }
      result.ProcCallOption:=pocall_default;
      include(result.ProcOptions,po_hascallingconvention);
      handle_calling_convention(result,hcc_default_actions_impl);
      sym:=CProcSym.create(basesymname+result.UniqueIDStr);
      st.InsertSym(sym);

      result.ProcSym:=sym;
      proc_add_definition(result);
      { the code will be assigned directly to the "code" field later }
      result.ForwardDef:=false;
      result.AliasNames.insert(result.MangledName);
    end;


  function fileinfo_to_suffix(const fileinfo:TFilePosInfo):TSymStr;inline;
    begin
      result:=ToStr(fileinfo.moduleindex)+'_'+
              ToStr(fileinfo.fileindex)+'_'+
              ToStr(fileinfo.line)+'_'+
              ToStr(fileinfo.column);
    end;


  const
    anon_funcref_prefix='$FuncRef_';
    capturer_class_name='$CapturerClass';
    { the leading $ is only added when registering the var symbol }
    capturer_var_name='Capturer';
    keepalive_suffix='_keepalive';
    outer_self_field_name='OuterSelf';


  procedure convert_to_funcref_intf(const n:TIDString;var def:TDef);
    var
      OldSymTableStack : TSymTableStack;
      pvdef : TProcVarDef absolute def;
      intfdef : TObjectDef;
      invokedef : TProcDef;
      sym : TSym;
      i : LongInt;
      name : TIDString;
    begin
      if def.typ<>procvardef then
        InternalError(2021040201);
      if not (po_is_function_ref in TProcVarDef(pvdef).ProcOptions) then
        InternalError(2021022101);
      if n='' then
        name:=anon_funcref_prefix+fileinfo_to_suffix(CurrentFilePos)
      else
        name:=n;
      intfdef:=CObjectDef.create(odt_interfacecom,name,Interface_IUnknown,true);
      include(intfdef.ObjectOptions,oo_is_funcref);
      include(intfdef.ObjectOptions,oo_is_invokable);
      include(intfdef.ObjectOptions,oo_has_virtual);
      intfdef.TypeSym:=pvdef.TypeSym;
      pvdef.TypeSym:=nil;

      intfdef.DefOptions:=intfdef.DefOptions+pvdef.DefOptions*[df_generic,df_specialization];
      { also inherit the general flags from the surrounding structured type or
        function }
      if Assigned(CurrentStructDef) then
        begin
          intfdef.DefOptions:=intfdef.DefOptions+CurrentStructDef.DefOptions*[df_generic,df_specialization];
        end
      else if Assigned(CurrentProcInfo) then
        begin
          intfdef.DefOptions:=intfdef.DefOptions+CurrentProcInfo.procdef.DefOptions*[df_generic,df_specialization];
        end;

      if cs_generate_rtti in CurrentSettings.LocalSwitches then
        include(intfdef.ObjectOptions,oo_can_have_published);

      OldSymTableStack:=SymTableStack;
      SymTableStack:=nil;

      invokedef:=TProcDef(pvdef.GetCopyAs(procdef,pc_normal_no_paras,'',false));
      invokedef.struct:=intfdef;
      invokedef.ForwardDef:=false;

      include(invokedef.ProcOptions,po_overload);
      include(invokedef.ProcOptions,po_virtualmethod);

      invokedef.ProcSym:=CProcSym.create(method_name_funcref_invoke_decl);
      if cs_generate_rtti in CurrentSettings.LocalSwitches then
        invokedef.visibility:=vis_published
      else
        invokedef.visibility:=vis_public;

      intfdef.SymTable.InsertSym(invokedef.ProcSym);
      intfdef.SymTable.InsertDef(invokedef);

      { we need to do this even if the def isn't a generic/specialization itself,
        but *belongs* to one }
      if intfdef.DefOptions*[df_generic,df_specialization]<>[] then
        begin
          if Assigned(pvdef.GenericDef) and (pvdef.GenericDef.typ<>objectdef) then
            InternalError(2021040501);
          intfdef.GenericDef:=pvdef.GenericDef;
          { in case of a generic we move all involved syms/defs to the interface }
          intfdef.GenericParas:=pvdef.GenericParas;
          pvdef.GenericParas:=nil;
          if Assigned(intfdef.GenericParas) then
            for i:=0 to intfdef.GenericParas.count-1 do
              begin
                sym:=TSym(intfdef.GenericParas[i]);
                if sym.owner<>pvdef.ParaST then
                  continue;
                sym.changeowner(intfdef.SymTable);
                if (sym.typ=TypeSym) and (TTypeSym(sym).typedef.owner=pvdef.ParaST) then
                  TTypeSym(sym).typedef.changeowner(intfdef.SymTable);
              end;
        end;

      { now move the symtable over }
      invokedef.ParaST.free;
      invokedef.ParaST:=pvdef.ParaST;
      invokedef.ParaST.DefOwner:=invokedef;
      pvdef.ParaST:=nil;

      for i:=0 to invokedef.ParaST.SymList.count-1 do
        begin
          sym:=TSym(invokedef.ParaST.SymList[i]);
          if sym.typ<>paravarsym then
            continue;
          if TParaVarSym(sym).vardef=pvdef then
            TParaVarSym(sym).vardef:=intfdef;
        end;

      SymTableStack:=OldSymTableStack;

      if invokedef.ReturnDef=pvdef then
        invokedef.ReturnDef:=intfdef;

      handle_calling_convention(invokedef,hcc_default_actions_intf_struct);
      proc_add_definition(invokedef);
      invokedef.CalcParas;
      { def is not owned, so it can be simply freed }
      def.free;
      def:=intfdef;
    end;


  function adjust_funcref(var def:TDef;sym,DummySym:TSym):boolean;
    var
      sympos : TFilePosInfo;
      name : string;
    begin
      result:=false;
      if (def.typ<>procvardef) and not is_funcref(def) then
        InternalError(2022020401);
      if Assigned(sym) and not (sym.typ=TypeSym) then
        InternalError(2022020402);
      { these always support everything, no "of object" or
        "is_nested" is allowed }
      if is_nested_pd(TProcVarDef(def)) or
         Is_MethodPointer(def) then
        CGMessage(type_e_function_reference_kind);
      if not (po_is_block in TProcVarDef(def).ProcOptions) then
        begin
          if Assigned(DummySym) then
            TTypeSym(DummySym).typedef:=nil;
          if Assigned(sym) then
            begin
              TTypeSym(sym).typedef:=nil;
              name:=sym.name;
            end
          else
            name:='';
          convert_to_funcref_intf(name,def);
          if Assigned(sym) then
            TTypeSym(sym).typedef:=def;
          if Assigned(DummySym) then
            TTypeSym(DummySym).typedef:=def;
          build_vmt(TObjectDef(def));
          result:=true;
        end
      else
        begin
          if Assigned(sym) and (sym.refs>0) then
            begin
              { find where the symbol was used and trigger
                a "symbol not completely defined" error }
              if not FileInfo_Of_TypeSym_In_Def(def,sym,sympos) then
                sympos:=sym.fileinfo;
              messagepos1(sympos,type_e_type_is_not_completly_defined,sym.realname);
            end;
        end;
    end;


  function funcref_intf_for_proc(pd:TAbstractProcDef;const suffix:string):TObjectDef;
    var
      name : TSymStr;
      sym : TSym;
      symowner : TSymTable;
      OldSymTableStack: TSymTableStack;
      invokedef: TProcDef;
    begin
      if pd.Is_Generic then
        InternalError(2022010710);

      name:='funcrefintf_'+suffix;
      if pd.owner.SymTableType=GlobalSymTable then
        symowner:=CurrentModule.LocalSymTable
      else
        symowner:=pd.owner;
      sym:=TSym(symowner.find(name));
      if Assigned(sym) then
        begin
          if sym.typ<>TypeSym then
            InternalError(2022010708);
          if not is_funcref(TTypeSym(sym).typedef) then
            InternalError(2022010709);
          result:=TObjectDef(TTypeSym(sym).typedef);
          exit;
        end;

      name:='$'+name;

      result:=CObjectDef.create(odt_interfacecom,name,Interface_IUnknown,false);
      include(result.ObjectOptions,oo_is_funcref);
      include(result.ObjectOptions,oo_is_invokable);

      sym:=CTypeSym.create(name,result);

      OldSymTableStack:=SymTableStack;
      SymTableStack:=nil;

      invokedef:=TProcDef(pd.GetCopyAs(procdef,pc_normal_no_hidden,'',false));
      invokedef.struct:=result;
      invokedef.visibility:=vis_public;
      invokedef.ProcSym:=CProcSym.create(method_name_funcref_invoke_decl);
      invokedef.ParaST.SymTableLevel:=normal_function_level;
      invokedef.LocalST.SymTableLevel:=normal_function_level;
      include(invokedef.ProcOptions,po_virtualmethod);
      exclude(invokedef.ProcOptions,po_staticmethod);
      exclude(invokedef.ProcOptions,po_classmethod);
      invokedef.ForwardDef:=false;

      SymTableStack:=OldSymTableStack;

      result.SymTable.InsertSym(invokedef.ProcSym);
      result.SymTable.InsertDef(invokedef);

      proc_add_definition(invokedef);
      invokedef.CalcParas;
      include(result.ObjectOptions,oo_has_virtual);

      symowner.InsertSym(sym);
      symowner.InsertDef(result);
      AddSymRef(sym);

      build_vmt(result);
    end;



  function acceptable_typ(sym:TAbstractVarSym;typ :TSymTyp) : boolean;
    begin
      acceptable_typ:=false;
      if (sym.typ=typ) then
        acceptable_typ:=true
      else if (sym.typ=absolutevarsym) and (TAbsoluteVarSym(sym).RefTyp=typ) then
        acceptable_typ:=true;
    end;

  function get_capturer(pd:TProcDef):TAbstractVarSym;

    function getsym(st:TSymTable;typ:TSymTyp):TAbstractVarSym;
      begin
        result:=TAbstractVarSym(st.find(capturer_var_name));
        if not Assigned(result) then
          InternalError(2022010703);
       if not acceptable_typ(result,typ) then
          InternalError(2022010704);
        if not Is_Class(result.vardef) then
          InternalError(2022010705);
      end;

    begin
      case pd.ProcTypeOption of
        potype_unitfinalize,
        potype_unitinit,
        potype_proginit:
          begin
            if not Assigned(pd.owner) then
              InternalError(2022052401);
            if pd.owner.SymTableType<>staticsymtable then
              InternalError(2022052402);
            result:=getsym(pd.owner,staticvarsym);
          end;
        else
          begin
            if not Assigned(pd.LocalST) then
              InternalError(2022020502);
            result:=getsym(pd.LocalST,localvarsym);
          end;
      end;
    end;


  function get_capturer_alive(pd:TProcDef):TAbstractVarSym;

    function getsym(st:TSymTable;typ:TSymTyp):TAbstractVarSym;
      begin
        result:=TAbstractVarSym(st.find(capturer_var_name+keepalive_suffix));
        if not Assigned(result) then
          InternalError(2022051703);
        if not acceptable_typ(result,typ) then
          InternalError(2022051704);
        if not Is_InterfaceCOM(result.vardef) then
          InternalError(2022051705);
      end;

    begin
      case pd.ProcTypeOption of
        potype_unitfinalize,
        potype_unitinit,
        potype_proginit:
          begin
            if not Assigned(pd.owner) then
              InternalError(2022052403);
            if pd.owner.SymTableType<>staticsymtable then
              InternalError(2022052404);
            result:=getsym(pd.owner,staticvarsym);
          end;
        else
          begin
            if not Assigned(pd.LocalST) then
              InternalError(2022051702);
            result:=getsym(pd.LocalST,localvarsym);
          end;
      end;
    end;


  function get_or_create_capturer(pd:TProcDef):TSym;
    var
      name : TSymStr;
      parent,
      def : TObjectDef;
      TypeSym : TSym;
      keepalive : TAbstractVarSym;
      st : TSymTable;
    begin
      if pd.HasCapturer then
        begin
          result:=get_capturer(pd);
        end
      else
        begin
          parent:=TObjectDef(Search_System_Type('TINTERFACEDOBJECT').typedef);
          if not Is_Class(parent) then
            InternalError(2022010706);

          name:=capturer_class_name+'_'+fileinfo_to_suffix(pd.fileinfo);

          case pd.ProcTypeOption of
            potype_unitfinalize,
            potype_unitinit,
            potype_proginit:
              st:=pd.owner;
            else
              st:=pd.LocalST;
          end;

          def:=CObjectDef.create(odt_class,name,parent,false);
          include(def.ObjectOptions,oo_is_capturer);
          TypeSym:=CTypeSym.create(name,def);
          TypeSym.fileinfo:=pd.fileinfo;
          st.InsertDef(def);
          st.InsertSym(TypeSym);
          AddSymRef(TypeSym);

          if df_generic in pd.DefOptions then
            include(def.DefOptions,df_generic);
          { don't set df_specialization as in that case genericdef needs to be
            set, but the local symtables are freed once a unit is finished }
          {if df_specialization in pd.defoptions then
            begin
              if not assigned(pd.genericdef) or (pd.genericdef.typ<>procdef) then
                internalerror(2022020501);
              def.genericdef:=tstoreddef(get_capturer(tprocdef(pd.genericdef)).vardef);
              include(def.defoptions,df_specialization);
            end;}

          if st.SymTableType=LocalSymTable then
            result:=CLocalVarSym.create('$'+capturer_var_name,vs_value,def,[vo_is_internal])
          else
            result:=CStaticVarSym.create('$'+capturer_var_name,vs_value,def,[vo_is_internal]);
          result.fileinfo:=pd.fileinfo;
          st.InsertSym(result);
          AddSymRef(result);

          if st.SymTableType=LocalSymTable then
            keepalive:=CLocalVarSym.create('$'+capturer_var_name+keepalive_suffix,vs_value,Interface_IUnknown,[vo_is_internal])
          else
            keepalive:=CStaticVarSym.create('$'+capturer_var_name+keepalive_suffix,vs_value,Interface_IUnknown,[vo_is_internal]);
          keepalive.fileinfo:=pd.fileinfo;
          st.InsertSym(keepalive);
          AddSymRef(keepalive);

          if st.SymTableType<>LocalSymTable then
            begin
              CNodeUtils.insertbssdata(TStaticVarSym(result));
              CNodeUtils.insertbssdata(TStaticVarSym(keepalive));
            end;

          { avoid warnings as these symbols are initialized using initialize_capturer
            after parsing the body }
          TAbstractVarSym(result).VarState:=vs_readwritten;
          keepalive.VarState:=vs_readwritten;

          pd.HasCapturer:=true;
        end;
    end;


  function can_be_captured(sym:TSym;curpd:TProcDef):boolean;
    begin
      result:=false;
      if (sym.typ=ProcSym) and Assigned(curpd) and (curpd.ProcSym=sym) then
        exit(true);
      if not (sym.typ in [localvarsym,paravarsym]) then
        exit;
      if TAbstractNormalVarSym(sym).VarOptions*[vo_is_result,vo_is_funcret]<>[] then
        exit;
      if sym.typ=paravarsym then
        begin
          if (TParaVarSym(sym).VarSpez in [vs_out,vs_var]) and
              not (vo_is_self in TParaVarSym(sym).VarOptions) then
            exit;
          if is_open_array(TParaVarSym(sym).vardef) then
            exit;
        end;
      result:=true;
    end;


  type
    TSymMapping = record
      oldsym:TSym;
      newsym:TSym;
    end;
    PSymMapping = ^TSymMapping;


  function replace_self_sym(var n:TNode;arg:pointer):TForEachNodeResult;
    var
      mapping : PSymMapping absolute arg;
      ld : TLoadNode;
    begin
      if n.nodetype=loadn then
        begin
          ld:=TLoadNode(n);
          if ld.symtableentry=mapping^.oldsym then
            begin
              ld.symtableentry:=mapping^.newsym;
              { make sure that the node is processed again }
              ld.resultdef:=nil;
              if Assigned(ld.left) then
                begin
                  { no longer loaded through the frame pointer }
                  ld.left.free;
                  ld.left:=nil;
                end;
              TypeCheckPass(n);
            end;
        end;
      result:=fen_true;
    end;


  procedure capture_captured_syms(pd:TProcDef;owner:TProcInfo;capturedef:TObjectDef;oldpd:TProcDef);
    var
      curpd : TProcDef;
      subcapturer : TObjectDef;
      symstodo : TFPList;
      i : LongInt;
      sym : TSym;
      fieldsym : TFieldVarSym;
      fieldname : TSymStr;
      fielddef : TDef;
    begin
      if not pd.WasAnonymous or not Assigned(pd.CapturedSyms) or (pd.CapturedSyms.count=0) then
        exit;
      { capture all variables that the original procdef captured }
      curpd:=owner.procdef;
      subcapturer:=capturedef;
      symstodo:=TFPList.create;
      for i:=0 to pd.CapturedSyms.count-1 do
        if can_be_captured(PCapturedSymInfo(pd.CapturedSyms[i])^.sym,oldpd) and
            (PCapturedSymInfo(pd.CapturedSyms[i])^.sym.typ<>ProcSym) then
          symstodo.add(PCapturedSymInfo(pd.CapturedSyms[i])^.sym);
      while symstodo.count>0 do
        begin
          { we know we have symbols left to capture thus we either have a
            symbol that's located in the capturer of the current procdef or
            we need to put in the OuterSelf reference }
          if curpd=owner.procdef then
            subcapturer:=capturedef
          else
            subcapturer:=TObjectDef(TAbstractVarSym(get_or_create_capturer(curpd)).vardef);
          i:=0;
          while i<symstodo.count do
            begin
              sym:=TSym(symstodo[i]);
              if (sym.owner=curpd.LocalST) or
                  (sym.owner=curpd.ParaST) then
                begin
                  { the symbol belongs to the current procdef, so add a field to
                    the capturer if it doesn't already exist }
                  if vo_is_self in TAbstractNormalVarSym(sym).VarOptions then
                    fieldname:=outer_self_field_name
                  else
                    fieldname:=sym.name;
                  fieldsym:=TFieldVarSym(subcapturer.SymTable.find(fieldname));
                  if not Assigned(fieldsym) then
                    begin
                      fielddef:=TAbstractVarSym(sym).vardef;
                      if vo_is_self in TAbstractNormalVarSym(sym).VarOptions then
                        begin
                          fieldname:='$'+fieldname;
                          if not Is_Implicit_Pointer_Object_Type(fielddef) then
                            fielddef:=CPointerDef.getreusable(fielddef);
                        end;
                      fieldsym:=CFieldVarSym.create(fieldname,vs_value,fielddef,[]);
                      fieldsym.fileinfo:=sym.fileinfo;
                      subcapturer.SymTable.InsertSym(fieldsym);
                      TAbstractRecordSymTable(subcapturer.SymTable).AddField(fieldsym,vis_public);
                    end;
                  if not Assigned(TAbstractNormalVarSym(sym).CaptureSym) then
                    TAbstractNormalVarSym(sym).CaptureSym:=fieldsym
                  else if TAbstractNormalVarSym(sym).CaptureSym<>fieldsym then
                    InternalError(2022011602);
                  symstodo.delete(i);
                end
              else if sym=pd.ProcSym then
                { no explicit capturing needed here }
                symstodo.delete(i)
              else
                inc(i);
            end;
          if symstodo.count>0 then
            begin
              if curpd.owner.SymTableType<>LocalSymTable then
                InternalError(2022011001);
              { there are still symbols left, so before we move to the parent
                procdef we add the OuterSelf field to set up the chain of
                capturers }
              { we no longer need the curpd, but we need the parent, so change
                curpd here }
                curpd:=TProcDef(curpd.owner.DefOwner);
                if curpd.typ<>procdef then
                  InternalError(2022011002);
              if not Assigned(subcapturer.SymTable.find(outer_self_field_name)) then
                begin
                  if subcapturer.owner.SymTableLevel>normal_function_level then
                    begin
                      { the outer self is the capturer of the outer procdef }
                      sym:=get_or_create_capturer(curpd);
                      { ensure that the outer capturer isn't put into a register anymore }
                      TAbstractVarSym(sym).DifferentScope:=true;
                      TAbstractVarSym(sym).VarRegable:=vr_none;
                    end
                  else
                    begin
                      { the outer self is the self of the method }
                      if not (curpd.owner.SymTableType in [objectsymtable,recordsymtable]) then
                        InternalError(2022011603);
                      sym:=TSym(curpd.ParaST.find('self'));
                      if not Assigned(sym) then
                        InternalError(2022011604);
                    end;
                  { add the keep alive IUnknown symbol }
                  fieldsym:=CFieldVarSym.create('$'+outer_self_field_name+keepalive_suffix,vs_value,Interface_IUnknown,[]);
                  fieldsym.fileinfo:=sym.fileinfo;
                  subcapturer.SymTable.InsertSym(fieldsym);
                  TAbstractRecordSymTable(subcapturer.SymTable).AddField(fieldsym,vis_public);
                  { add the capturer symbol }
                  fieldsym:=CFieldVarSym.create('$'+outer_self_field_name,vs_value,TAbstractVarSym(sym).vardef,[]);
                  fieldsym.fileinfo:=sym.fileinfo;
                  subcapturer.SymTable.InsertSym(fieldsym);
                  TAbstractRecordSymTable(subcapturer.SymTable).AddField(fieldsym,vis_public);
                  if (sym.typ=paravarsym) and (vo_is_self in TParaVarSym(sym).VarOptions) then
                    begin
                      if Assigned(TParaVarSym(sym).CaptureSym) then
                        InternalError(2022011705);
                      TParaVarSym(sym).CaptureSym:=fieldsym;
                    end;
                end;
            end;
        end;
      symstodo.free;
      symstodo := nil;
    end;


  function retrieve_sym_for_filepos(var n:TNode;arg:pointer):TForEachNodeResult;
    var
      sym : ^TSym absolute arg;
    begin
      if Assigned(sym^) then
        exit(fen_norecurse_true);
      result:=fen_false;
      if not (n.resultdef.typ in [procdef,procvardef]) then
        exit;
      if n.nodetype=loadn then
        begin
          sym^:=TLoadNode(n).symtableentry;
          result:=fen_norecurse_true;
        end
      else if n.nodetype=subscriptn then
        begin
          sym^:=TSubscriptNode(n).vs;
          result:=fen_norecurse_true;
        end;
    end;


  function collect_syms_to_capture(var n:TNode;arg:pointer):TForEachNodeResult;
    var
      pd : TProcDef absolute arg;
      sym : TSym;
    begin
      result:=fen_false;
      if n.nodetype<>loadn then
        exit;
      sym:=TSym(TLoadNode(n).symtableentry);
      if not (sym.owner.SymTableType in [parasymtable,LocalSymTable]) then
        exit;
      if sym.owner.SymTableLevel>normal_function_level then begin
        pd.Add_Captured_Sym(sym,TLoadNode(n).resultdef,n.fileinfo);
        result:=fen_true;
      end;
    end;


  type
    TSelfInfo=record
      selfsym:TSym;
      ignore:TSym;
    end;
    PSelfInfo=^TSelfInfo;


  function find_self_sym(var n:TNode;arg:pointer):TForEachNodeResult;
    var
      info : PSelfInfo absolute arg;
    begin
      result:=fen_false;
      if Assigned(info^.selfsym) then
        exit(fen_norecurse_true);
      if n.nodetype<>loadn then
        exit;
      if TLoadNode(n).symtableentry.typ<>paravarsym then
        exit;
      if TLoadNode(n).symtableentry=info^.ignore then
        exit;
      if vo_is_self in TParaVarSym(TLoadNode(n).symtableentry).VarOptions then
        begin
          info^.selfsym:=TParaVarSym(TLoadNode(n).symtableentry);
          result:=fen_norecurse_true;
        end;
    end;


  function find_outermost_loaded_sym(var n:TNode;arg:pointer):TForEachNodeResult;
    var
      sym : ^TSym absolute arg;
    begin
      if Assigned(sym^) then
        exit(fen_norecurse_true);
      result:=fen_false;
      if n.nodetype<>loadn then
        exit;
      if not (n.resultdef.typ in [procdef,procvardef]) then
        exit;
      sym^:=TLoadNode(n).symtableentry;
      result:=fen_norecurse_true;
    end;


  function find_procdef(var n:TNode;arg:pointer):TForEachNodeResult;
    var
      pd : ^TProcDef absolute arg;
    begin
      if Assigned(pd^) then
        exit(fen_norecurse_true);
      result:=fen_false;
      if n.resultdef.typ<>procdef then
        exit;
      pd^:=TProcDef(n.resultdef);
      result:=fen_norecurse_true;
    end;


  function capturer_add_procvar_or_proc(owner:TProcInfo;n:TNode;out capturer:TSym;out capturen:TNode):TObjectDef;

    function create_paras(pd:TProcDef):TCallParaNode;
      var
        para : TParaVarSym;
        i : LongInt;
      begin
        result:=nil;
        for i:=0 to pd.paras.count-1 do
          begin
            para:=TParaVarSym(pd.paras[i]);
            if vo_is_hidden_para in para.VarOptions then
              continue;
            result:=CCallParaNode.create(CLoadNode.create(para,pd.ParaST),result);
          end;
      end;

      function find_nested_procinfo(pd:TProcDef):TCGProcInfo;
        var
          tmp,
          res : TProcInfo;
        begin
          tmp:=owner;
          while Assigned(tmp) and (tmp.procdef.ParaST.SymTableLevel>=normal_function_level) do
            begin
              res:=tmp.find_nestedproc_by_pd(pd);
              if Assigned(res) then
                exit(TCGProcInfo(res));
              tmp:=tmp.parent;
            end;
          result:=nil;
        end;

      procedure swap_symtable(var st1,st2:TSymTable);
        var
          st : TSymTable;
          owner : TDefEntry;
          level : byte;
        begin
          { first swap the symtables themselves }
          st:=st1;
          st1:=st2;
          st2:=st;
          { then swap the symtables' owners }
          owner:=st1.DefOwner;
          st1.DefOwner:=st2.DefOwner;
          st2.DefOwner:=owner;
          { and finally the symtable level }
          level:=st1.SymTableLevel;
          st1.SymTableLevel:=st2.SymTableLevel;
          st2.SymTableLevel:=level;
        end;

      procedure print_procinfo(pi:TCGProcInfo);
        begin
          { Print the node to tree.log }
          if ParaPrintNodeTree <> 0 then
            pi.printproc('after parsing');

{$ifdef DEBUG_NODE_XML}
          { Methods of generic classes don't get any code generated, so output
            the node tree here }
          if (df_generic in pi.procdef.DefOptions) then
            pi.XMLPrintProc(True);
{$endif DEBUG_NODE_XML}
        end;

    var
      ps : TProcSym;
      oldpd,
      pd : TProcDef;
      pinested,
      pi : TCGProcInfo;
      sym,
      fpsym,
      selfsym : TSym;
      invokename : TSymStr;
      capturedef : TObjectDef;
      capturesyms : TFPList;
      captured : PCapturedSymInfo;
      implintf : TImplementedInterface;
      i : LongInt;
      stmt : TStatementNode;
      n1 : TNode;
      fieldsym : TFieldVarSym;
      selfinfo : TSelfInfo;
    begin
      if not (n.resultdef.typ in [procdef,procvardef]) then
        InternalError(2022022101);

      capturer:=nil;
      capturen:=nil;
      pinested:=nil;
      oldpd:=nil;

      { determine a unique name for the variable, field for function of the
        node we're trying to load }

      sym:=nil;
      if not foreachnodestatic(pm_preprocess,n,@find_outermost_loaded_sym,@sym) then
        InternalError(2022022102);

      result:=funcref_intf_for_proc(TAbstractProcDef(n.resultdef),fileinfo_to_suffix(sym.fileinfo));

      if (sym.typ=ProcSym) and (sym.owner.SymTableType=LocalSymTable) then
        begin
          { this is assigning a nested function, so retrieve the correct procdef
            so that we can then retrieve the procinfo for it }
          if n.resultdef.typ=procdef then
            pd:=TProcDef(n.resultdef)
          else
            begin
              pd:=nil;
              if not foreachnodestatic(pm_preprocess,n,@find_procdef,@pd) then
                InternalError(2022041801);
              if not Assigned(pd) then
                InternalError(2022041802);
            end;
          { check whether all captured symbols can indeed be captured }
          capturesyms:=pd.CapturedSyms;
          if Assigned(capturesyms) then
            for i:=0 to capturesyms.count-1 do
              begin
                captured:=PCapturedSymInfo(capturesyms[i]);
                if not can_be_captured(captured^.sym,pd) then
                  MessagePos1(captured^.fileinfo,sym_e_symbol_no_capture,captured^.sym.realname);
              end;
          if not (df_generic in owner.procdef.DefOptions) then
            begin
              pinested:=find_nested_procinfo(pd);
              if not Assigned(pinested) then
                InternalError(2022041803);
              oldpd:=pd;
              if pinested.parent<>owner then
                begin
                  { we need to capture this into the owner of the nested function
                    instead }
                  owner:=pinested;
                  capturer:=get_or_create_capturer(pinested.procdef);
                  if not Assigned(capturer) then
                    InternalError(2022041804);
                end;
            end;
        end
      else if (n.resultdef.typ=procvardef) and
          (po_delphi_nested_cc in TProcVarDef(n.resultdef).ProcOptions) then
        begin
          MessagePos(n.fileinfo,type_e_nested_procvar_to_funcref);
          exit;
        end
      else
        pinested:=nil;

      if df_generic in owner.procdef.DefOptions then
        exit;

      if not Assigned(capturer) then
        capturer:=get_or_create_capturer(owner.procdef);

      if not (capturer.typ in [localvarsym,staticvarsym]) then
        InternalError(2022022103);
      capturedef:=TObjectDef(TAbstractVarSym(capturer).vardef);
      if not Is_Class(capturedef) then
        InternalError(2022022104);
      implintf:=find_implemented_interface(capturedef,result);
      if Assigned(implintf) then
        begin
          { this is already captured into a method of the capturer, so nothing
            further to do }
          exit;
        end;
      implintf:=capturedef.Register_Implemented_Interface(result,true);

      invokename:=method_name_funcref_invoke_decl+'__FPCINTERNAL__'+fileinfo_to_suffix(sym.fileinfo);

      ps:=CProcSym.create(invokename);
      pd:=TProcDef(TAbstractProcDef(n.resultdef).GetCopyAs(procdef,pc_normal_no_hidden,'',false));
      pd.AliasNames.clear;

      pd.ProcSym:=ps;
      pd.struct:=capturedef;
      pd.changeowner(capturedef.SymTable);
      pd.ParaST.SymTableLevel:=normal_function_level;
      pd.LocalST.SymTableLevel:=normal_function_level;
      { reset procoptions }
      pd.ProcOptions:=[];
      ps.ProcdefList.Add(pd);
      pd.ForwardDef:=false;
      { set procinfo and current_procinfo.procdef }
      pi:=TCGProcInfo(CProcInfo.create(nil));
      pi.procdef:=pd;
      if not Assigned(pinested) then
        begin
          insert_funcret_para(pd);
          insert_funcret_local(pd);
          { we always do a call, namely to the provided function }
          include(pi.flags,pi_do_call);
        end
      else
        begin
          { the original nested function now calls the method }
          include(pinested.flags,pi_do_call);
          { swap the para and local symtables of the nested and new routine }
          swap_symtable(pinested.procdef.ParaST,pd.ParaST);
          swap_symtable(pinested.procdef.LocalST,pd.LocalST);
          { fix function return symbol }
          pd.FuncRetSym:=pinested.procdef.FuncRetSym;
          pinested.procdef.FuncRetSym:=nil;
          pinested.procdef.Reset_After_Conv;
          insert_funcret_para(pinested.procdef);
          insert_funcret_local(pinested.procdef);
          { the nested function needs access to the parent's framepointer to
            access the capturer }
          insert_parentfp_para(pinested.procdef);
          pd.CopiedFrom:=pinested.procdef;
        end;
      { to simplify some checks, but only after insert_funcret_para }
      pd.WasAnonymous:=true;
      capturedef.SymTable.InsertSym(ps);
      owner.addnestedproc(pi);

      { remove self and parentfp parameter if any as that will be replaced by
        the capturer }
      selfsym:=nil;
      fpsym:=nil;
      for i:=0 to pd.ParaST.SymList.count-1 do
        begin
          sym:=TSym(pd.ParaST.SymList[i]);
          if sym.typ<>paravarsym then
            continue;
          if vo_is_self in TParaVarSym(sym).VarOptions then
            selfsym:=sym
          else if vo_is_parentfp in TParaVarSym(sym).VarOptions then
            fpsym:=sym;
          if Assigned(selfsym) and Assigned(fpsym) then
            break;
        end;
      if Assigned(selfsym) then
        pd.ParaST.DeleteSym(selfsym);
      if Assigned(fpsym) then
        pd.ParaST.DeleteSym(fpsym);
      pd.CalcParas;
      if Assigned(pinested) then
        pinested.procdef.CalcParas;

      insert_self_and_vmt_para(pd);

      if Assigned(pinested) then
        begin
          { when we're assigning a nested function to a function reference we
            move the code of the nested function to the newly created capturer
            method (including the captured symbols) and have the original nested
            function simply call that function-turned-method }
          pi.code:=pinested.code;
          pinested.code:=internalstatements(stmt);
        end
      else
        pi.code:=internalstatements(stmt);

      selfinfo.selfsym:=nil;
      selfinfo.ignore:=nil;

      fieldsym:=nil;
      if Assigned(pinested) then
        begin
          n1:=CCallNode.create(create_paras(pinested.procdef),ps,capturedef.SymTable,CLoadNode.create(capturer,capturer.owner),[],nil);
          { captured variables cannot be in registers }
          make_not_regable(TCallNode(n1).methodpointer,[ra_addr_regable,ra_addr_taken]);
        end
      else if n.resultdef.typ=procvardef then
        begin
          { store the procvar in a field so that it won't be changed if the
            procvar itself is changed }
          fieldsym:=CFieldVarSym.create('$'+fileinfo_to_suffix(n.fileinfo),vs_value,n.resultdef,[]);
          fieldsym.fileinfo:=n.fileinfo;
          capturedef.SymTable.InsertSym(fieldsym);
          TAbstractRecordSymTable(capturedef.SymTable).AddField(fieldsym,vis_public);

          capturen:=CSubscriptNode.create(fieldsym,CLoadNode.create(capturer,capturer.owner));

          selfsym:=TSym(pd.ParaST.find('self'));
          if not Assigned(selfsym) then
            InternalError(2022052301);
          selfinfo.ignore:=selfsym;
          n1:=CCallNode.create_procvar(create_paras(pd),CSubscriptNode.create(fieldsym,CLoadNode.create(selfsym,selfsym.owner)));
        end
      else
        begin
          if n.nodetype<>loadn then
            InternalError(2022032401);
          if TLoadNode(n).symtableentry.typ<>ProcSym then
            InternalError(2022032402);
          n1:=CCallNode.create(create_paras(pd),TProcSym(TLoadNode(n).symtableentry),TLoadNode(n).SymTable,TLoadNode(n).left,[],nil);
          TLoadNode(n).left:=nil;
        end;
      if Assigned(pd.ReturnDef) and not is_void(pd.ReturnDef) then
        begin
          if Assigned(pinested) then
            sym:=pinested.procdef.FuncRetSym
          else
            sym:=pd.FuncRetSym;
          n1:=CAssignmentNode.create(
                      CLoadNode.create(sym,sym.owner),
                      n1
                    );
          { captured variables cannot be in registers }
          make_not_regable(TAssignmentNode(n1).left,[ra_addr_regable,ra_addr_taken]);
        end;
      addstatement(stmt,n1);
      pd.AliasNames.insert(pd.MangledName);

      if Assigned(pinested) then
        begin
          { transfer all captured syms }
          capturesyms:=pinested.procdef.CapturedSyms;
          if Assigned(capturesyms) then
            begin
              for i:=0 to capturesyms.count-1 do
                begin
                  captured:=PCapturedSymInfo(capturesyms[i]);
                  pi.Add_Captured_Sym(captured^.sym,captured^.def,captured^.fileinfo);
                  dispose(captured);
                end;
              capturesyms.clear;
            end;
          { the original nested function now needs to capture only the capturer }
          pinested.procdef.Add_Captured_Sym(capturer,capturedef,n.fileinfo);
        end
      { does this need to capture Self? }
      else if not foreachnodestatic(pm_postprocess,n,@find_self_sym,@selfinfo) then
        begin
          { is this a method of the current class? }
          if (n.resultdef.typ=procdef) and
              Assigned(TProcDef(n.resultdef).struct) and
              not (po_staticmethod in TProcDef(n.resultdef).ProcOptions) and
              Assigned(CurrentProcInfo.procdef.struct) and
              def_is_related(CurrentProcInfo.procdef.struct,TProcDef(n.resultdef).struct) then
            begin
              selfinfo.selfsym:=TSym(CurrentProcInfo.procdef.ParaST.find('self'));
              if not Assigned(selfinfo.selfsym) then
                InternalError(2022110601);
            end
          else
            { does this need some other local variable or parameter? }
            foreachnodestatic(pm_postprocess,n,@collect_syms_to_capture,@pd)
        end;

      if Assigned(selfinfo.selfsym) and not Assigned(fieldsym) then
        { this isn't a procdef that was captured into a field, so capture the
          self }
        pd.Add_Captured_Sym(selfinfo.selfsym,TAbstractVarSym(selfinfo.selfsym).vardef,n.fileinfo);

      print_procinfo(pi);
      if Assigned(pinested) then
        print_procinfo(pinested);

      implintf.AddMapping(upcase(result.ObjRealName^+'.')+method_name_funcref_invoke_find,upcase(invokename));

      capture_captured_syms(pd,owner,capturedef,oldpd);
    end;


  function capturer_add_anonymous_proc(owner:TProcInfo;pd:TProcDef;out capturer:TSym):TObjectDef;
    var
      capturedef : TObjectDef;
      implintf : TImplementedInterface;
      invokename : TSymStr;
      i : LongInt;
      outerself,
      fpsym,
      selfsym,
      sym : TSym;
      info : PCapturedSymInfo;
      pi : TProcInfo;
      mapping : TSymMapping;
    begin
      capturer:=nil;
      result:=funcref_intf_for_proc(pd,fileinfo_to_suffix(pd.fileinfo));

      if df_generic in pd.DefOptions then
        begin
          if (po_anonymous in pd.ProcOptions) and
              Assigned(pd.CapturedSyms) and
              (pd.CapturedSyms.count>0) then
            begin
              { only check whether the symbols can be captured, but don't
                convert anything to avoid problems }
              for i:=0 to pd.CapturedSyms.count-1 do
                begin
                  info:=PCapturedSymInfo(pd.CapturedSyms[i]);
                  if not can_be_captured(info^.sym,pd) then
                    MessagePos1(info^.fileinfo,sym_e_symbol_no_capture,info^.sym.realname)
                end;
            end;
          exit;
        end;

      capturer:=get_or_create_capturer(owner.procdef);

      if not (capturer.typ in [localvarsym,staticvarsym]) then
        InternalError(2022010711);
      capturedef:=TObjectDef(TAbstractVarSym(capturer).vardef);
      if not Is_Class(capturedef) then
        InternalError(2022010712);
      implintf:=find_implemented_interface(capturedef,result);
      if Assigned(implintf) then
        begin
          { this can only already be an implemented interface if a named procdef
            was assigned to a function ref at an earlier point, an anonymous
            function can be used only once }
          if po_anonymous in pd.ProcOptions then
            InternalError(2022010713);
          exit;
        end;
      implintf:=capturedef.Register_Implemented_Interface(result,true);

      invokename:=method_name_funcref_invoke_decl+'__FPCINTERNAL__'+fileinfo_to_suffix(pd.fileinfo);
      if po_anonymous in pd.ProcOptions then
        begin
          { turn the anonymous function into a method of the capturer }
          pd.changeowner(capturedef.SymTable);
          pd.struct:=capturedef;
          exclude(pd.ProcOptions,po_anonymous);
          exclude(pd.ProcOptions,po_delphi_nested_cc);
          exclude(pd.ProcOptions,po_staticmethod);
          exclude(pd.ProcOptions,po_classmethod);
          pd.WasAnonymous:=true;
          pd.ProcSym.ChangeOwnerAndName(capturedef.SymTable,upcase(invokename));
          pd.ProcSym.realname:=invokename;
          pd.ParaST.SymTableLevel:=normal_function_level;
          pd.LocalST.SymTableLevel:=normal_function_level;
          { retrieve framepointer and self parameters if any }
          fpsym:=nil;
          selfsym:=nil;
          for i:=0 to pd.ParaST.SymList.count-1 do
            begin
              sym:=TSym(pd.ParaST.SymList[i]);
              if sym.typ<>paravarsym then
                continue;
              if vo_is_parentfp in TParaVarSym(sym).VarOptions then
                fpsym:=sym
              else if vo_is_self in TParaVarSym(sym).VarOptions then
                selfsym:=sym;
              if Assigned(fpsym) and Assigned(selfsym) then
                break;
            end;
          { get rid of the framepointer parameter }
          if Assigned(fpsym) then
            pd.ParaST.DeleteSym(fpsym);
          outerself:=nil;
          { complain about all symbols that can't be captured and add the symbols
            to this procdefs capturedsyms if it isn't a top level function }
          if Assigned(pd.CapturedSyms) and (pd.CapturedSyms.count>0) then
            begin
              for i:=0 to pd.CapturedSyms.count-1 do
                begin
                  info:=PCapturedSymInfo(pd.CapturedSyms[i]);
                  if not can_be_captured(info^.sym,pd) then
                    MessagePos1(info^.fileinfo,sym_e_symbol_no_capture,info^.sym.realname)
                  else if info^.sym=selfsym then
                    begin
                      { we need to replace the captured "dummy" self parameter
                        with the real self parameter symbol from the surrounding
                        method }
                      if not Assigned(outerself) then
                        outerself:=TSym(owner.get_normal_proc.procdef.ParaST.find('self'));
                      if not Assigned(outerself) then
                        InternalError(2022010905);

                      { the anonymous function can only be a direct child of the
                        owner }
                      pi:=owner.get_first_nestedproc;
                      while Assigned(pi) do
                        begin
                          if pi.procdef=pd then
                            break;
                          pi:=TProcInfo(pi.next);
                        end;

                      if not Assigned(pi) then
                        InternalError(2022010906);

                      mapping.oldsym:=selfsym;
                      mapping.newsym:=outerself;

                      { replace all uses of the captured Self by the new Self
                        parameter }
                      foreachnodestatic(pm_preprocess,TCGProcInfo(pi).code,@replace_self_sym,@mapping);

                      { update the captured symbol }
                      info^.sym:=outerself;
                      info^.def:=TAbstractVarSym(outerself).vardef;
                    end
                  else if info^.sym.owner.DefOwner<>owner.procdef then
                    owner.procdef.Add_Captured_Sym(info^.sym,info^.def,info^.fileinfo);
                end;
            end;
          { delete the original self parameter }
          if Assigned(selfsym) then
            pd.ParaST.DeleteSym(selfsym);
          { note: don't call insert_self_and_vmt_para here, as that is later on
                  done when building the VMT }
        end
      else
        InternalError(2022022201);
      implintf.AddMapping(upcase(result.ObjRealName^+'.')+method_name_funcref_invoke_find,upcase(invokename));

      capture_captured_syms(pd,owner,capturedef,nil);
    end;


  function load_capturer(capturer:TAbstractVarSym):TNode;inline;
    begin
      result:=CLoadNode.create(capturer,capturer.owner);
    end;


  function instantiate_capturer(capturer_sym:TAbstractVarSym):TNode;
    var
      capturer_def : TObjectDef;
      ctor : TProcSym;
    begin
      capturer_def:=TObjectDef(capturer_sym.vardef);

      { Neither TInterfacedObject, nor TCapturer have a custom constructor }
      ctor:=TProcSym(Class_TObject.SymTable.Find('CREATE'));
      if not Assigned(ctor) then
        InternalError(2022010801);

      { Insert "Capturer := TCapturer.Create()" as the first statement of the routine }
      result:=CLoadVMTAddrNode.create(CTypeNode.create(capturer_def));
      result:=CCallNode.create(nil,ctor,capturer_def.SymTable,result,[],nil);
      result:=CAssignmentNode.create(load_capturer(capturer_sym),result);
    end;


  procedure initialize_captured_paras(pd:TProcDef;capturer:TAbstractVarSym;var stmt:TStatementNode);
    var
      i : LongInt;
      psym: TParaVarSym;
      n : TNode;
    begin
      for i:=0 to pd.paras.count-1 do
        begin
          psym:=TParaVarSym(pd.paras[i]);
          if not psym.Is_Captured then
            continue;
          n:=CLoadNode.create(psym,psym.owner);
          if psym.CaptureSym.owner.DefOwner<>capturer.vardef then
            InternalError(2022010903);
          if (vo_is_self in psym.VarOptions) and not Is_Implicit_Pointer_Object_Type(psym.vardef) then
            n:=CAddrNode.create(n);
          n:=CAssignmentNode.create(
               CSubscriptNode.create(psym.CaptureSym,CLoadNode.create(capturer,capturer.owner)),
               n
               );
          addstatement(stmt,n);
        end;
    end;


  procedure attach_outer_capturer(ctx:TProcInfo;capturer:TAbstractVarSym;var stmt:TStatementNode);
    var
      alivefield,
      selffield : TFieldVarSym;
      outeralive,
      outercapturer : TAbstractVarSym;
      alivenode,
      selfnode : TNode;
    begin
      if not ctx.procdef.WasAnonymous and
          not (ctx.procdef.owner.SymTableType=LocalSymTable) then
        exit;
      selffield:=TFieldVarSym(TObjectDef(capturer.vardef).SymTable.find(outer_self_field_name));
      if not Assigned(selffield) then
        { we'll simply assume that we don't need the outer capturer }
        exit;
      alivefield:=TFieldVarSym(TObjectDef(capturer.vardef).SymTable.find(outer_self_field_name+keepalive_suffix));
      if not Assigned(alivefield) then
        InternalError(2022051701);
      if ctx.procdef.WasAnonymous then
        begin
          selfnode:=load_self_node;
          alivenode:=selfnode.GetCopy;
        end
      else
        begin
          outercapturer:=get_capturer(TProcDef(ctx.procdef.owner.DefOwner));
          if not Assigned(outercapturer) then
            InternalError(2022011605);
          selfnode:=CLoadNode.create(outercapturer,outercapturer.owner);
          make_not_regable(selfnode,[ra_different_scope]);
          outeralive:=get_capturer_alive(TProcDef(ctx.procdef.owner.DefOwner));
          if not Assigned(outeralive) then
            InternalError(2022051706);
          alivenode:=CLoadNode.create(outeralive,outeralive.owner);
          make_not_regable(alivenode,[ra_different_scope]);
        end;
      addstatement(stmt,CAssignmentNode.create(
                          CSubscriptNode.create(
                            selffield,
                            CLoadNode.create(
                              capturer,
                              capturer.owner
                              )
                            ),
                            selfnode));
      addstatement(stmt,CAssignmentNode.create(
                          CSubscriptNode.create(
                            alivefield,
                            CLoadNode.create(
                              capturer,
                              capturer.owner
                              )
                            ),
                            alivenode));
    end;


  procedure initialize_capturer(ctx:TProcInfo;var stmt:TStatementNode);
    var
      capturer_sym,
      keepalive_sym : TAbstractVarSym;
    begin
      if ctx.procdef.HasCapturer then
        begin
          capturer_sym:=get_capturer(ctx.procdef);

          addstatement(stmt,instantiate_capturer(capturer_sym));
          attach_outer_capturer(ctx,capturer_sym,stmt);
          initialize_captured_paras(ctx.procdef,capturer_sym,stmt);

          keepalive_sym:=get_capturer_alive(ctx.procdef);
          if not Assigned(keepalive_sym) then
            InternalError(2022010701);
          addstatement(stmt,CAssignmentNode.create(CLoadNode.create(keepalive_sym,keepalive_sym.owner),load_capturer(capturer_sym)));
        end;
    end;


  procedure postprocess_capturer(ctx: TProcInfo);
    var
      def: TObjectDef;
    begin
      if not ctx.procdef.HasCapturer then
        exit;

      def:=TObjectDef(get_capturer(ctx.procdef).vardef);
      { These two are delayed until this point because
        ... we have been adding fields on-the-fly }
      TAbstractRecordSymTable(def.SymTable).AddAlignmentPadding;
      { ... we have been adding interfaces on-the-fly }
      build_vmt(def);
    end;


  type
    TConvertArg=record
      mappings:TFPList;
    end;
    PConvertArg=^TConvertArg;

    TConvertMapping=record
      oldsym:TSym;
      newsym:TSym;
      olddef:TDef;
      selfnode:TNode;
    end;
    PConvertMapping=^TConvertMapping;


  function convert_captured_sym(var n:TNode;arg:pointer):TForEachNodeResult;
    var
      convertarg : PConvertArg absolute arg;
      mapping : PConvertMapping;
      i : LongInt;
      OldFilePos : TFilePosInfo;
      loadprocvar : boolean;
      paras: TNode;
      cnf : TCallNodeFlags;
      paraold,
      paranew : TCallParaNode;
    begin
      result:=fen_true;
      if not (n.nodetype in [loadn,calln]) then
        exit;
      for i:=0 to convertarg^.mappings.count-1 do
        begin
          mapping:=convertarg^.mappings[i];
          case n.nodetype of
            loadn:
              begin
                if TLoadNode(n).symtableentry<>mapping^.oldsym then
                  continue;
                OldFilePos:=CurrentFilePos;
                CurrentFilePos:=n.fileinfo;
                loadprocvar:=nf_load_procvar in n.flags;
                n.free;
                n:=CSubscriptNode.create(mapping^.newsym,mapping^.selfnode.GetCopy);
                if loadprocvar then
                  include(n.flags,nf_load_procvar);
                if (mapping^.oldsym.typ=paravarsym) and
                    (vo_is_self in TParaVarSym(mapping^.oldsym).VarOptions) and
                    not Is_Implicit_Pointer_Object_Type(TParaVarSym(mapping^.oldsym).vardef) then
                  n:=CDerefNode.create(n);
                TypeCheckPass(n);
                CurrentFilePos:=OldFilePos;
                break;
              end;
            calln:
              begin
                if mapping^.oldsym.typ<>ProcSym then
                  continue;
                if TCallNode(n).symtableprocentry<>TProcSym(mapping^.oldsym) then
                  continue;
                if TCallNode(n).procdefinition<>TProcDef(mapping^.olddef) then
                  continue;
                OldFilePos:=CurrentFilePos;
                CurrentFilePos:=n.fileinfo;
                loadprocvar:=nf_load_procvar in n.flags;
                paras:=TCallNode(n).left;
                paraold:=TCallParaNode(paras);
                paranew:=nil;
                while Assigned(paraold) do
                  begin
                    if not (vo_is_hidden_para in paraold.parasym.VarOptions) then
                      begin
                        paranew:=CCallParaNode.create(paraold.left,paranew);
                        paraold.left:=nil;
                      end;
                    paraold:=TCallParaNode(paraold.right);
                  end;
                reverseparameters(paranew);
                if Assigned(TCallNode(n).methodpointer) then
                  InternalError(2023120802);
                cnf:=TCallNode(n).callnodeflags;
                n.free;
                n:=CCallNode.create(paranew,TProcSym(mapping^.newsym),mapping^.newsym.owner,mapping^.selfnode.GetCopy,cnf,nil);
                if loadprocvar then
                  include(n.flags,nf_load_procvar);
                TypeCheckPass(n);
                CurrentFilePos:=OldFilePos;
                break;
              end;
            else
              InternalError(2023120801);
          end;
        end;
    end;


  procedure convert_captured_syms(pd:TProcDef;tree:TNode);

    function self_tree_for_sym(selfsym:TSym;fieldsym:TSym):TNode;
      var
        fieldowner : TDef;
        newsym : TSym;
      begin
        result:=CLoadNode.create(selfsym,selfsym.owner);
        fieldowner:=TDef(fieldsym.owner.DefOwner);
        newsym:=selfsym;
        while (TAbstractVarSym(newsym).vardef<>fieldowner) do
          begin
            newsym:=TSym(TObjectDef(TAbstractVarSym(newsym).vardef).SymTable.find(outer_self_field_name));
            if not Assigned(newsym) then
              InternalError(2022011101);
            result:=CSubscriptNode.create(newsym,result);
          end;
      end;

    var
      i: LongInt;
      capturer : TObjectDef;
      tocapture,
      CapturedSyms : TFPList;
      convertarg : TConvertArg;
      mapping : PConvertMapping;
      selfsym,
      sym : TSym;
    begin

      convertarg.mappings:=TFPList.create;

      CapturedSyms:=TFPList.create;

      if pd.WasAnonymous and
          Assigned(pd.CapturedSyms) and
          (pd.CapturedSyms.count>0) then
        begin

          { this is a converted anonymous function, so rework all symbols that
            now belong to the new Self }

          selfsym:=TSym(pd.ParaST.find('self'));
          if not Assigned(selfsym) then
            InternalError(2022010809);

          for i:=0 to pd.CapturedSyms.count-1 do
            begin
              sym:=TSym(PCapturedSymInfo(pd.CapturedSyms[i])^.sym);
              if not can_be_captured(sym,pd) and
                  not (
                    (sym.typ=ProcSym) and
                    Assigned(pd.CopiedFrom) and
                    (pd.CopiedFrom.ProcSym=sym)
                  ) then
                continue;
              new(mapping);
              mapping^.oldsym:=sym;
              if sym.typ=ProcSym then
                begin
                  if not Assigned(pd.CopiedFrom) or
                      (pd.CopiedFrom.ProcSym<>sym) then
                    InternalError(2023123001);
                  mapping^.newsym:=pd.ProcSym;
                end
              else
                mapping^.newsym:=TAbstractNormalVarSym(sym).CaptureSym;
              mapping^.olddef:=PCapturedSymInfo(pd.CapturedSyms[i])^.def;
              if not Assigned(mapping^.newsym) then
                InternalError(2022010810);
              mapping^.selfnode:=self_tree_for_sym(selfsym,mapping^.newsym);
              convertarg.mappings.add(mapping);
              CapturedSyms.add(sym);
            end;
        end;

      if (pd.ParaST.SymTableLevel>normal_function_level) and
          Assigned(pd.CapturedSyms) and
          (pd.CapturedSyms.count>0) then
        begin
          if pd.WasAnonymous then
            InternalError(2022081201);


          { this is a nested function, so rework all symbols that are used from
            a parent function, but that might have been captured }

          for i:=0 to pd.CapturedSyms.count-1 do
            begin
              sym:=TSym(PCapturedSymInfo(pd.CapturedSyms[i])^.sym);
              if not can_be_captured(sym,pd) or
                  (sym.typ=ProcSym) or
                  not Assigned(TAbstractNormalVarSym(sym).CaptureSym) then
                continue;
              new(mapping);
              mapping^.oldsym:=sym;
              mapping^.newsym:=TAbstractNormalVarSym(sym).CaptureSym;
              mapping^.olddef:=PCapturedSymInfo(pd.CapturedSyms[i])^.def;
              capturer:=TObjectDef(mapping^.newsym.owner.DefOwner);
              if not Is_Class(capturer) then
                InternalError(2022012701);
              if not (capturer.TypeSym.owner.SymTableType in [LocalSymTable,staticsymtable]) then
                InternalError(2022012702);
              selfsym:=TSym(capturer.TypeSym.owner.find(capturer_var_name));
              if not Assigned(selfsym) then
                InternalError(2022012703);
              mapping^.selfnode:=self_tree_for_sym(selfsym,mapping^.newsym);
              convertarg.mappings.add(mapping);
              CapturedSyms.add(sym);
            end;
        end;

      if pd.HasCapturer then
        begin
          { this procedure has a capturer, so rework all symbols that are
            captured in that capturer }

          selfsym:=get_capturer(pd);

          { only capture those symbols that weren't captured already by one of
            the above if-clauses and thus are now listed in capturedsyms }
          tocapture:=TFPList.create;

          for i:=0 to pd.LocalST.SymList.count-1 do
            begin
              sym:=TSym(pd.LocalST.SymList[i]);
              if sym.typ<>localvarsym then
                continue;
              if Assigned(TAbstractNormalVarSym(sym).CaptureSym) then
                if CapturedSyms.indexof(sym)<0 then
                  tocapture.add(sym);
            end;

          for i:=0 to pd.ParaST.SymList.count-1 do
            begin
              sym:=TSym(pd.ParaST.SymList[i]);
              if sym.typ<>paravarsym then
                continue;
              if Assigned(TAbstractNormalVarSym(sym).CaptureSym) and
                  { no need to adjust accesses to the outermost Self inside the
                    outermost method }
                  not (vo_is_self in TAbstractVarSym(sym).VarOptions) then
                if CapturedSyms.indexof(sym)<0 then
                  tocapture.add(sym);
            end;

          convertarg.mappings.capacity:=convertarg.mappings.count+tocapture.count;
          for i:=0 to tocapture.count-1 do
            begin
              new(mapping);
              mapping^.oldsym:=TSym(tocapture[i]);
              mapping^.newsym:=TAbstractNormalVarSym(mapping^.oldsym).CaptureSym;
              if not Assigned(mapping^.newsym) then
                InternalError(2022010805);
              mapping^.selfnode:=self_tree_for_sym(selfsym,mapping^.newsym);
              convertarg.mappings.add(mapping);
            end;

          tocapture.free;
          tocapture := nil;
        end;

      { not required anymore }
      CapturedSyms.free;
      CapturedSyms := nil;

      if convertarg.mappings.count>0 then
        foreachnodestatic(pm_postprocess,tree,@convert_captured_sym,@convertarg);

      for i:=0 to convertarg.mappings.count-1 do
        begin
          mapping:=PConvertMapping(convertarg.mappings[i]);
          mapping^.selfnode.free; // no nil needed
          dispose(mapping);
        end;

      convertarg.mappings.free; // no nil needed
    end;


end.

