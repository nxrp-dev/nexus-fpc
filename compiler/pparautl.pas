{
    Copyright (c) 1998-2002 by Florian Klaempfl, Daniel Mantione

    Helpers for dealing with subroutine parameters during parsing

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
unit pparautl;

{$i fpcdefs.inc}

interface

    uses
      symtype,symconst,symdef;

    procedure insert_funcret_para(pd:TAbstractProcDef);
    procedure insert_parentfp_para(pd:TAbstractProcDef);
    procedure insert_self_and_vmt_para(pd:TAbstractProcDef);
    procedure insert_funcret_local(pd:TProcDef);
    procedure insert_hidden_para(p:TObject;arg:pointer);
    procedure check_c_para(pd:TAbstractProcDef);
    procedure insert_struct_hidden_paras(astruct: TAbstractRecordDef);

    type
      // flags of the *handle_calling_convention routines
      THCCFlag=(
        hcc_declaration,          // declaration (as opposed to definition, i.e. interface rather than implementation)
        hcc_check,                // perform checks and output errors if found
        hcc_insert_hidden_paras   // insert hidden parameters
      );
      THCCFlags=set of THCCFlag;

    const
      hcc_default_actions_intf=[hcc_declaration,hcc_check,hcc_insert_hidden_paras];
      hcc_default_actions_intf_struct=hcc_default_actions_intf-[hcc_insert_hidden_paras];
      hcc_default_actions_impl=[hcc_check,hcc_insert_hidden_paras];
      hcc_default_actions_parse=[hcc_check,hcc_insert_hidden_paras];
      PD_VIRTUAL_MUTEXCLPO = [po_interrupt,po_exports,po_overridingmethod,po_inline,po_staticmethod];

    { may take procdef, procvardef or defs for which is_funcref is true }
    procedure handle_calling_convention(pd_or_invkdef:TDef;flags:THCCFlags);
    function proc_add_definition(var currpd:TProcDef):boolean;

    { create "parent frame pointer" record skeleton for procdef, in which local
      variables and parameters from pd accessed from nested routines can be
      stored }
    procedure build_parentfpstruct(pd: TProcDef);

implementation

    uses
      Globals,GlobType,CClasses,CUtils,Verbose,Systems,FModule,
      tokens,
      SymBase,SymSym,SymTable,symutil,defutil,defcmp,blockutl,
      node,nbas,
      aasmbase,
      paramgr;


    procedure insert_funcret_para(pd:TAbstractProcDef);
      const
        name_result='result';
      var
        storepos : TFilePosInfo;
        vs       : TParaVarSym;
        ParaNr   : word;
      begin
        if not(pd.ProcTypeOption in [potype_constructor,potype_destructor]) and
           not is_void(pd.ReturnDef) and
           not (df_generic in pd.DefOptions) and
           { if this was originally an anonymous function then this was already
             done earlier }
           not ((pd.typ=procdef) and TProcDef(pd).WasAnonymous) and
           paramanager.ret_in_param(pd.ReturnDef,pd) and
           not Assigned(pd.ParaST.find(name_result)) then
         begin
           storepos:=CurrentTokenPos;
           if pd.typ=procdef then
            CurrentTokenPos:=TProcDef(pd).fileinfo;
{$if defined(i386)}
           { For left to right add it at the end to be delphi compatible.
             In the case of safecalls with safecal-exceptions support the
             funcret-para is (from the 'c'-point of view) a normal parameter
             which has to be added to the end of the parameter-list }
           if (pd.ProcCallOption in (pushleftright_pocalls)) or
              ((tf_safecall_exceptions in TargetInfo.flags) and
               (pd.ProcCallOption=pocall_safecall)) then
             ParaNr:=paranr_result_leftright
           else
{$elseif defined(SUPPORT_SAFECALL)}
           if (tf_safecall_exceptions in TargetInfo.flags) and
              (pd.ProcCallOption = pocall_safecall)  then
             ParaNr:=paranr_result_leftright
           else
{$endif}
           if is_managed_type(pd.ReturnDef) then
             ParaNr:=paranr_result_managed
           else
             ParaNr:=paranr_result;
           { Generate result variable accessing function result }
           vs:=CParaVarSym.create('$'+name_result,ParaNr,vs_var,pd.ReturnDef,[vo_is_funcret,vo_is_hidden_para]);
           pd.ParaST.InsertSym(vs);
           { Store this symbol as funcretsym for procedures }
           if pd.typ=procdef then
            TProcDef(pd).FuncRetSym:=vs;

           CurrentTokenPos:=storepos;
         end;
      end;


    procedure insert_parentfp_para(pd:TAbstractProcDef);
      const
        name_parentfp='parentfp';
      var
        storepos : TFilePosInfo;
        vs       : TParaVarSym;
        ParaNr   : LongInt;
      begin
        if (pd.ParaST.SymTableLevel>normal_function_level) and
           not Assigned(pd.ParaST.find(name_parentfp)) then
          begin
            storepos:=CurrentTokenPos;
            if pd.typ=procdef then
             CurrentTokenPos:=TProcDef(pd).fileinfo;

            { if no support for nested procvars is activated, use the old
              calling convention to pass the parent frame pointer for backwards
              compatibility }
            if not(m_nested_procvars in CurrentSettings.ModeSwitches) then
              ParaNr:=paranr_parentfp
            { nested procvars require Delphi-style parentfp passing, see
              po_delphi_nested_cc declaration for more info }
{$if defined(i386)}
            else if (pd.ProcCallOption in pushleftright_pocalls) then
              ParaNr:=paranr_parentfp_delphi_cc_leftright
{$endif i386}
            else
              ParaNr:=paranr_parentfp_delphi_cc;
            { Generate frame pointer. It can't be put in a register since it
              must be accessible from nested routines }

              begin
                vs:=CParaVarSym.create('$'+name_parentfp,ParaNr,vs_value
                      ,ParentFPVoidPointerType,[vo_is_parentfp,vo_is_hidden_para]);
              end

            ;
            pd.ParaST.InsertSym(vs);

            CurrentTokenPos:=storepos;
          end;
      end;


    procedure insert_self_and_vmt_para(pd:TAbstractProcDef);
      const
        name_cmd='_cmd';
        name_self='self';
        name_block_literal='_block_literal';
        name_vmt='vmt';
      var
        storepos : TFilePosInfo;
        vs       : TParaVarSym;
        hdef     : TDef;
        selfdef  : TDef;
        vsp      : TVarSpez;
        aliasvs  : TAbsoluteVarSym;
        sl       : TPropAccessList;
      begin
        if (pd.typ=procdef) and
           Is_ObjC_Class_Or_Protocol(TProcDef(pd).struct) and
           (pd.ParaST.SymTableLevel=normal_function_level) then
          begin
            if not Assigned(pd.ParaST.find(name_cmd)) or
                not Assigned(pd.ParaST.find(name_self)) then
              begin
                { insert Objective-C self and selector parameters }
                vs:=CParaVarSym.create('$'+name_cmd,paranr_objc_cmd,vs_value,ObjC_SelType,[vo_is_msgsel,vo_is_hidden_para]);
                pd.ParaST.InsertSym(vs);
                { make accessible to code }
                sl:=TPropAccessList.create;
                sl.AddSym(sl_load,vs);
                aliasvs:=CAbsoluteVarSym.Create_Ref('_CMD',ObjC_SelType,sl);
                include(aliasvs.VarOptions,vo_is_msgsel);
                TLocalSymTable(TProcDef(pd).LocalST).InsertSym(aliasvs);

                if (po_classmethod in pd.ProcOptions) then
                  { compatible with what gcc does }
                  hdef:=ObjC_IDType
                else
                  hdef:=TProcDef(pd).struct;

                vs:=CParaVarSym.create('$'+name_self,paranr_objc_self,vs_value,hdef,[vo_is_self,vo_is_hidden_para]);
                pd.ParaST.InsertSym(vs);
              end;
          end
        else if (pd.typ=procvardef) and
           pd.Is_MethodPointer then
          begin
            if not Assigned(pd.ParaST.find(name_self)) then
              begin
                { Generate self variable }
                vs:=CParaVarSym.create('$'+name_self,paranr_self,vs_value,VoidPointerType,[vo_is_self,vo_is_hidden_para]);
                pd.ParaST.InsertSym(vs);
              end;
          end
        { while only procvardefs of this type can be declared in Pascal code,
          internally we also generate procdefs of this type when creating
          block wrappers }
        else if (po_is_block in pd.ProcOptions) then
          begin
            if not Assigned(pd.ParaST.find('$'+name_block_literal)) then
              begin
                { generate the first hidden parameter, which is a so-called "block
                  literal" describing the block and containing its invocation
                  procedure  }
                hdef:=CPointerDef.getreusable(get_block_literal_type_for_proc(pd));
                { mark as vo_is_parentfp so that proc2procvar comparisons will
                  succeed when assigning arbitrary routines to the block }
                vs:=CParaVarSym.create('$'+name_block_literal,paranr_blockselfpara,vs_value,
                  hdef,[vo_is_hidden_para,vo_is_parentfp]
                );
                pd.ParaST.InsertSym(vs);
                if pd.typ=procdef then
                  begin
                    { make accessible to code }
                    sl:=TPropAccessList.create;
                    sl.AddSym(sl_load,vs);
                    aliasvs:=CAbsoluteVarSym.Create_Ref('FPC_BLOCK_SELF',hdef,sl);
                    include(aliasvs.VarOptions,vo_is_parentfp);
                    TLocalSymTable(TProcDef(pd).LocalST).InsertSym(aliasvs);
                  end;
              end;
          end
        else
          begin
             if (pd.typ=procdef) and
                Assigned(TProcDef(pd).struct) and
                (
                  (pd.ParaST.SymTableLevel=normal_function_level) or
                  ([po_anonymous,po_methodpointer]<=pd.ProcOptions)
                ) then
              begin
                { static class methods have no hidden self/vmt pointer }
                if pd.No_Self_Node then
                   exit;

                storepos:=CurrentTokenPos;
                CurrentTokenPos:=TProcDef(pd).fileinfo;

                { Generate VMT variable for constructor/destructor }
                if (pd.ProcTypeOption in [potype_constructor,potype_destructor]) and
                   not(Is_CPPClass(TProcDef(pd).struct) or
                       Is_Record(TProcDef(pd).struct) or (Is_ObjectPascal_Helper(TProcDef(pd).struct) and
                         (TObjectDef(TProcDef(pd).struct).ExtendedDef.typ<>objectdef)
                       )) and
                   not Assigned(pd.ParaST.find(name_vmt)) then
                 begin
                   vs:=CParaVarSym.create('$'+name_vmt,paranr_vmt,vs_value,CClassRefDef.create(TProcDef(pd).struct),[vo_is_vmt,vo_is_hidden_para]);
                   pd.ParaST.InsertSym(vs);
                 end;

                { for helpers the type of Self is equivalent to the extended
                  type or equal to an instance of it }
                if Is_ObjectPascal_Helper(TProcDef(pd).struct) then
                  selfdef:=TObjectDef(TProcDef(pd).struct).ExtendedDef
                else if Is_ObjCCategory(TProcDef(pd).struct) then
                  selfdef:=TObjectDef(TProcDef(pd).struct).ChildOf
                else
                  selfdef:=TProcDef(pd).struct;
                { Generate self variable, for classes we need
                  to use the generic voidpointer to be compatible with
                  methodpointers }
                vsp:=vs_value;
                if (po_staticmethod in pd.ProcOptions) or
                   (po_classmethod in pd.ProcOptions) then
                  hdef:=CClassRefDef.create(selfdef)
                else
                  begin
                    if Is_Object(selfdef) or (selfdef.typ<>objectdef) then
                      vsp:=vs_var;
                    hdef:=selfdef;
                  end;
                vs:=TParaVarSym(pd.ParaST.find(name_self));
                if not Assigned(vs) or (vs.typ<>paravarsym) or (vs.vardef<>hdef) then
                  begin
                    vs:=CParaVarSym.create('$'+name_self,paranr_self,vsp,hdef,[vo_is_self,vo_is_hidden_para]);
                    pd.ParaST.InsertSym(vs);
                  end;

                CurrentTokenPos:=storepos;
              end;
          end;
      end;


    procedure insert_funcret_local(pd:TProcDef);
      var
        storepos : TFilePosInfo;
        vs       : TLocalVarSym;
        aliasvs  : TAbsoluteVarSym;
        sl       : TPropAccessList;
        hs       : string;
      begin
        storepos:=CurrentTokenPos;
        CurrentTokenPos:=pd.fileinfo;

        { The result from constructors and destructors can't be accessed directly }
        if not(pd.ProcTypeOption in [potype_constructor,potype_destructor]) and
           not is_void(pd.ReturnDef) and
           (not(po_assembler in pd.ProcOptions) or paramanager.asm_result_var(pd.ReturnDef,pd)) then
         begin
           { We need to insert a varsym for the result in the localst
             when it is returning in a register }
           { we also need to do this for a generic procdef as we didn't allow
             the creation of a result symbol in insert_funcret_para, but we need
             a valid funcretsym }
           if (df_generic in pd.DefOptions) or
               not paramanager.ret_in_param(pd.ReturnDef,pd) then
            begin
              vs:=CLocalVarSym.create('$result',vs_value,pd.ReturnDef,[vo_is_funcret]);
              pd.LocalST.InsertSym(vs,false);
              pd.FuncRetSym:=vs;
            end;

           { insert the name of the procedure as alias for the function result,
             we can't use realname because that will not work for compilerprocs
             as the name is lowercase and unreachable from the code;
             don't insert this alias for an anonymous function unless an
             explicit name is provided }
           if (
                 (pd.ProcTypeOption<>potype_operator) and
                 not (po_anonymous in pd.ProcOptions)
               ) or Assigned(pd.ResultName) then
             begin
               if Assigned(pd.ResultName) then
                 hs:=pd.ResultName^
               else
                 hs:=pd.ProcSym.name;
               if (hs='') then
                 hs:='$_result';
               sl:=TPropAccessList.create;
               sl.AddSym(sl_load,pd.FuncRetSym);
               aliasvs:=CAbsoluteVarSym.Create_Ref(hs,pd.ReturnDef,sl);
               include(aliasvs.VarOptions,vo_is_funcret);
               TLocalSymTable(pd.LocalST).InsertSym(aliasvs);
             end;

           { insert result also if support is on }
           if (m_result in CurrentSettings.ModeSwitches) then
            begin
              sl:=TPropAccessList.create;
              sl.AddSym(sl_load,pd.FuncRetSym);
              aliasvs:=CAbsoluteVarSym.Create_Ref('RESULT',pd.ReturnDef,sl);
              include(aliasvs.VarOptions,vo_is_funcret);
              include(aliasvs.VarOptions,vo_is_result);
              TLocalSymTable(pd.LocalST).InsertSym(aliasvs);
            end;

         end;

        if pd.Generate_SafeCall_Wrapper then
          begin
            { vo_is_funcret is necessary so the local only gets freed after we loaded its
              value into the return register }
            vs:=CLocalVarSym.create('$safecallresult',vs_value,Search_System_Type('HRESULT').typedef,[vo_is_funcret]);
            { do not put this variable in a register. The register which will be bound
              to this symbol will not be allocated automatically. Which means it will
              be re-used which breaks the code. Besides this it is questionable if it is
              an optimization if one of the registers is kept allocated during the complete
              function, without ever using it.
              (It would be better to re-write the safecall-support in such a way that this
              variable it not needed at all, but that the HRESULT is set when the method
              is finalized) }
            vs.VarRegable:=vr_none;
            pd.LocalST.InsertSym(vs);
          end;

        CurrentTokenPos:=storepos;
      end;


    procedure insert_hidden_para(p:TObject;arg:pointer);
      const
        name_high = 'high';
        name_typinfo = 'typinfo';
      var
        n   : TSymStr;
        hvs : TParaVarSym;
        pd  : TAbstractProcDef absolute arg;
      begin
        if (TSym(p).typ<>paravarsym) then
         exit;
        with TParaVarSym(p) do
         begin
           { We need a local copy for a value parameter when only the
             address is pushed. Open arrays and Array of Const are
             an exception because they are allocated at runtime and the
             address that is pushed is patched.

             Arrays passed to cdecl routines are special: they are pointers in
             C and hence must be passed as such. Due to historical reasons, if
             a cdecl routine is implemented in Pascal, we still make a copy on
             the callee side. Do this the same on platforms that normally must
             make a copy on the caller side, as otherwise the behaviour will
             be different (and less perfomant) for routines implemented in C }
           if (VarSpez=vs_value) and
              paramanager.push_addr_param(VarSpez,vardef,pd.ProcCallOption) and
              not(is_open_array(vardef) or
                  is_array_of_const(vardef)) and
              (not(TargetInfo.system in systems_caller_copy_addr_value_para) or
               ((pd.ProcCallOption in cdecl_pocalls) and
                (vardef.typ=arraydef))) then
             include(VarOptions,vo_has_local_copy);

           { needs high parameter ? }
           if paramanager.push_high_param(VarSpez,vardef,pd.ProcCallOption) then
             begin
               n:=name_high+name;
               if not Assigned(owner.find(n)) then
                 begin

                     hvs:=CParaVarSym.create('$'+n,ParaNr+1,vs_const,SizeSIntType,[vo_is_high_para,vo_is_hidden_para]);
                   hvs.SymOptions:=[];
                   owner.InsertSym(hvs);
                   { don't place to register if it will be accessed from implicit finally block }
                   if (VarSpez=vs_value) and
                      is_open_array(vardef) and
                      is_managed_type(vardef) then
                     hvs.VarRegable:=vr_none;
                 end;
             end
           else
            begin
              { Give a warning that cdecl routines does not include high()
                support }
              if (pd.ProcCallOption in cdecl_pocalls) and
                 paramanager.push_high_param(VarSpez,vardef,pocall_default) then
               begin
                 if is_open_string(vardef) then
                    MessagePos(fileinfo,parser_w_cdecl_no_openstring);
                 if not(po_external in pd.ProcOptions) and
                    (pd.typ<>procvardef) and
                    not Is_ObjC_Class_Or_Protocol(TProcDef(pd).struct) then
                   if is_array_of_const(vardef) then
                     MessagePos(fileinfo,parser_e_varargs_need_cdecl_and_external)
                   else
                     MessagePos(fileinfo,parser_w_cdecl_has_no_high);
               end;
              if (vardef.typ=formaldef) and (TFormalDef(vardef).typed) then
                begin
                  n:=name_typinfo+name;
                  if not Assigned(owner.find(n)) then
                    begin
                      hvs:=CParaVarSym.create('$'+n,ParaNr+1,vs_const,VoidPointerType,
                                              [vo_is_typinfo_para,vo_is_hidden_para]);
                      owner.InsertSym(hvs);
                    end;
                end;
            end;
         end;
      end;


    procedure check_c_para(pd:TAbstractProcDef);
      var
        i,
        lastparaidx : LongInt;
        sym : TSym;
      begin
        lastparaidx:=pd.ParaST.SymList.Count-1;
        for i:=0 to pd.ParaST.SymList.Count-1 do
          begin
            sym:=TSym(pd.ParaST.SymList[i]);
            if (sym.typ=paravarsym) and
               (TParaVarSym(sym).vardef.typ=arraydef) then
              begin
                if not is_variant_array(TParaVarSym(sym).vardef) and
                   not is_array_of_const(TParaVarSym(sym).vardef) and
                   (TParaVarSym(sym).VarSpez<>vs_var) then
                  MessagePos(TParaVarSym(sym).fileinfo,parser_h_c_arrays_are_references);
                if is_array_of_const(TParaVarSym(sym).vardef) and
                   (i<lastparaidx) and
                   (TSym(pd.ParaST.SymList[i+1]).typ=paravarsym) and
                   not(vo_is_high_para in TParaVarSym(pd.ParaST.SymList[i+1]).VarOptions) then
                  MessagePos(TParaVarSym(sym).fileinfo,parser_e_C_array_of_const_must_be_last);
              end;
          end;
      end;


    procedure insert_struct_hidden_paras(astruct: TAbstractRecordDef);
      var
        pd: TDef;
        i: LongInt;
        oldpos: TFilePosInfo;
      begin
        // handle calling conventions of record methods
        oldpos:=CurrentFilePos;

        for i := 0 to astruct.SymTable.DefList.count - 1 do
          begin
            pd:=TDef(astruct.SymTable.DefList[i]);
            if pd.typ<>procdef then
              continue;
            CurrentFilePos:=TProcDef(pd).fileinfo;
            handle_calling_convention(TProcDef(pd),[hcc_declaration,hcc_insert_hidden_paras]);
          end;
        CurrentFilePos:=oldpos;
      end;


    procedure set_addr_param_regable(p:TObject;arg:pointer);
      begin
        if (TSym(p).typ<>paravarsym) then
         exit;
        with TParaVarSym(p) do
         begin
           if (not Needs_Finalization) and
              paramanager.push_addr_param(VarSpez,vardef,TProcDef(arg).ProcCallOption) then
             VarRegable:=vr_addr;
         end;
      end;


    procedure handle_calling_convention(pd_or_invkdef:TDef;flags:THCCFlags);
      var
        pd : TAbstractProcDef;
      begin
        if is_funcref(pd_or_invkdef) then
          pd:=get_invoke_procdef(TObjectDef(pd_or_invkdef))
        else if pd_or_invkdef.typ in [procdef,procvardef] then
          pd:=TAbstractProcDef(pd_or_invkdef)
        else
          InternalError(2022012502);
        if hcc_check in flags then
          begin
            { set the default calling convention if none provided }
            if (pd.typ=procdef) and
               (Is_ObjC_Class_Or_Protocol(TProcDef(pd).struct) or
                Is_CPPClass(TProcDef(pd).struct)) then
              begin
                { none of the explicit calling conventions should be allowed }
                if (po_hascallingconvention in pd.ProcOptions) then
                  InternalError(2009032501);
                if Is_CPPClass(TProcDef(pd).struct) then
                  pd.ProcCallOption:=pocall_cppdecl
                else
                  pd.ProcCallOption:=pocall_cdecl;
              end
            else if not(po_hascallingconvention in pd.ProcOptions) then
              pd.ProcCallOption:=CurrentSettings.DefProcCall
            else
              begin
                if pd.ProcCallOption=pocall_none then
                  InternalError(200309081);
              end;

            { handle proccall specific settings }
            case pd.ProcCallOption of
              pocall_cdecl,
              pocall_cppdecl,
              pocall_sysv_abi_cdecl,
              pocall_ms_abi_cdecl:
                begin
                  { check C cdecl para types }
                  check_c_para(pd);
                end;
              pocall_far16 :
                begin
                  { Temporary stub, must be rewritten to support OS/2 far16 }
                  Message1(parser_w_proc_directive_ignored,'FAR16');
                end;
              else
                ;
            end;

            { Inlining is enabled and supported? }
            if (po_inline in pd.ProcOptions) and
               not(cs_do_inline in CurrentSettings.LocalSwitches) then
              begin
                { Give an error if inline is not supported by the compiler mode,
                  otherwise only give a hint that this procedure will not be inlined }
                if not(m_default_inline in CurrentSettings.ModeSwitches) then
                  Message(parser_e_proc_inline_not_supported)
                else
                  Message(parser_h_inlining_disabled);
                exclude(pd.ProcOptions,po_inline);
              end;

            { For varargs directive also cdecl and external must be defined }
            if (po_varargs in pd.ProcOptions) then
             begin
               { check first for external in the interface, if available there
                 then the cdecl must also be there since there is no implementation
                 available to contain it }
               if hcc_declaration in flags then
                begin
                  { if external is available, then cdecl must also be available,
                    procvars don't need external }
                  if not((po_external in pd.ProcOptions) or
                         (pd.typ=procvardef) or
                         { for objcclasses this is checked later, because the entire
                           class may be external.  }
                         Is_ObjC_Class_Or_Protocol(TProcDef(pd).struct)) and
                     not(pd.ProcCallOption in (cdecl_pocalls + [pocall_stdcall])) then
                    Message(parser_e_varargs_need_cdecl_and_external);
                end
               else
                begin
                  { both must be defined now }
                  if not((po_external in pd.ProcOptions) or
                         (pd.typ=procvardef)) or
                     not(pd.ProcCallOption in cstylearrayofconst) then
                    Message(parser_e_varargs_need_cdecl_and_external);
                end;
             end;
          end;

        if hcc_insert_hidden_paras in flags then
          begin
            { If the paraloc info has been calculated already, it will be missing for
              the new parameters we add below. This should never be necessary before
              we add them, as users of this information would not process these extra
              parameters in that case }
            if pd.HasParaLocInfo<>callnoside then
              InternalError(2019031610);

            { insert hidden high parameters }
            pd.ParaST.SymList.ForEachCall(@insert_hidden_para,pd);

            { insert hidden self parameter }
            insert_self_and_vmt_para(pd);

            { insert funcret parameter if required }
            insert_funcret_para(pd);

            { Make var parameters regable, this must be done after the calling
              convention is set. }
            { this must be done before parentfp is insert, because getting all cases
              where parentfp must be in a memory location isn't catched properly so
              we put parentfp never in a register }
            pd.ParaST.SymList.ForEachCall(@set_addr_param_regable,pd);

            { insert parentfp parameter if required }
            insert_parentfp_para(pd);
          end;

        { Calculate parameter tlist }
        pd.CalcParas;
      end;


    function proc_add_definition(var currpd:TProcDef):boolean;

      function check_generic_parameters(fwpd,currpd:TProcDef):boolean;
        var
          i : LongInt;
          fwsym,
          currsym : TSym;
          currtype : TTypeSym absolute currsym;
          fileinfo : TFilePosInfo;
        begin
          result:=true;
          if fwpd.GenericParas.count<>currpd.GenericParas.count then
            InternalError(2018090101);
          for i:=0 to fwpd.GenericParas.count-1 do
            begin
              fwsym:=TSym(fwpd.GenericParas[i]);
              currsym:=TSym(currpd.GenericParas[i]);
              if fwsym.name<>currsym.name then
                begin
                  messagepos1(currsym.fileinfo,sym_e_generic_type_param_mismatch,currsym.realname);
                  messagepos1(fwsym.fileinfo,sym_e_generic_type_param_decl,fwsym.realname);
                  result:=false;
                end;
              if (fwpd.InterfaceDef or Assigned(fwpd.struct)) and
                 (
                   ((currsym.typ=TypeSym) and (df_genconstraint in currtype.typedef.DefOptions)) or
                   (currsym.typ=constsym)
                 ) then
                begin
                  if currsym.typ=constsym then
                    fileinfo:=currsym.fileinfo
                  else
                    fileinfo:=TStoredDef(currtype.typedef).GenConstraintData.fileinfo;
                  messagepos(fileinfo,parser_e_generic_constraints_not_allowed_here);
                  result:=false;
                end;
              if not fwpd.InterfaceDef and not Assigned(fwpd.struct) and
                 (fwsym.typ=constsym) then
                begin
                  { without modeswitch RepeatForward we need to check here
                    if the type of the constants match }
                  if (currsym.typ<>constsym) or not equal_defs(TConstSym(fwsym).ConstDef,TConstSym(currsym).ConstDef) then
                    begin
                      messagepos1(currpd.fileinfo,parser_e_header_dont_match_forward,currpd.FullProcName(false));
                      result:=false;
                    end;
                end;
            end;
        end;


      function equal_generic_procdefs(fwpd,currpd:TProcDef;out sameparas,sameret:boolean):boolean;
        var
          i : LongInt;
          fwsym,
          currsym : TSym;
          currtype : TTypeSym absolute currsym;
          convdummy: TConvertType;
          pddummy: TProcDef;
        begin
          result:=false;
          sameparas:=false;
          sameret:=false;
          if fwpd.GenericParas.count<>currpd.GenericParas.count then
            exit;
          { comparing generic declarations is a bit more cumbersome as the
            defs of the generic parameter types are not equal, especially if the
            declaration contains constraints; essentially we have two cases:
            - proc declared in interface of unit (or in class/record/object)
              and defined in implementation; here the fwpd might contain
              constraints while currpd must only contain undefineddefs
            - forward declaration in implementation: here constraints must be
              repeated }
          for i:=0 to fwpd.GenericParas.count-1 do
            begin
              fwsym:=TSym(fwpd.GenericParas[i]);
              currsym:=TSym(currpd.GenericParas[i]);
              { if the type in the currpd isn't a pure undefineddef (thus there
                are constraints and the fwpd was declared in the interface, then
                we can stop right there }
              if fwpd.InterfaceDef and
                 (
                   (currsym.typ=constsym) or
                   ((currsym.typ=TypeSym) and
                     (
                       (currtype.typedef.typ<>undefineddef) or
                       (df_genconstraint in currtype.typedef.DefOptions)
                     )
                   )
                 )then
                exit;
              if not fwpd.InterfaceDef then
                begin
                  if (fwsym.typ=constsym) and (currsym.typ=constsym) then
                    begin
                      { check whether the constant type for forward functions match }
                      if not equal_defs(TConstSym(fwsym).ConstDef,TConstSym(currsym).ConstDef) then
                        exit;
                    end
                  else if (fwsym.typ=constsym) then
                    { if the forward sym is a constant, the implementation needs to be one
                      as well }
                    exit;
                end;
            end;
          if compare_paras(fwpd.paras,currpd.paras,cp_none,[cpo_ignorehidden,cpo_openequalisexact,cpo_ignoreuniv,cpo_generic])<>te_exact then
            exit;
          sameparas:=true;
          if (df_specialization in TStoredDef(fwpd.ReturnDef).DefOptions) and (df_specialization in TStoredDef(currpd.ReturnDef).DefOptions) then
            { for specializations we're happy with equal defs instead of exactly the same defs }
            result:=equal_defs(fwpd.ReturnDef,currpd.ReturnDef)
          else
            begin
              { strictly compare defs using compare_defs_ext, but allow
                non exactly equal undefineddefs }
              convdummy:=tc_none;
              pddummy:=nil;
              result:=(compare_defs_ext(fwpd.ReturnDef,currpd.ReturnDef,nothingn,convdummy,pddummy,[cdo_allow_variant,cdo_strict_undefined_check])=te_exact) or
                        equal_genfunc_paradefs(fwpd.ReturnDef,currpd.ReturnDef,fwpd.ParaST,currpd.ParaST);
            end;
          { the result variable is only set depending on the return type, so we
            can simply use "result" }
          sameret:=result;
        end;

      function equal_signature(fwpd,currpd:TProcDef;out sameparas,sameret:boolean):boolean;
        begin
          sameparas:=compare_paras(fwpd.paras,currpd.paras,cp_none,[cpo_ignorehidden,cpo_openequalisexact,cpo_ignoreuniv])=te_exact;
          sameret:=compare_rettype(fwpd.ReturnDef,currpd.ReturnDef)=te_exact;
          result:=sameparas and sameret;
        end;

      {
        Add definition aprocdef to the overloaded definitions of aprocsym. If a
        forwarddef is found and reused it returns true
      }
      var
        fwpd    : TProcDef;
        currparasym,
        fwparasym : TSym;
        currparacnt,
        fwparacnt,
        curridx,
        fwidx,
        i       : LongInt;
        po_comp : TProcOptions;
        paracompopt: TCompareParasOptions;
        sameparasfound,
        gensameparas,
        gensameret,
        sameparas,
        sameret,
        forwardfound : boolean;
        symentry: TSymEntry;
        item : TLinkedListItem;
      begin
        forwardfound:=false;

        if Assigned(currpd.struct) and
           (currpd.struct.SymTable.ModuleID<>CurrentModule.ModuleID) and
           not (df_specialization in currpd.DefOptions) then
          begin
            result:=false;
            exit;
          end;

        sameparasfound:=false;
        fwpd:=nil;

        { check overloaded functions if the same function already exists }
        for i:=0 to TProcSym(currpd.ProcSym).ProcdefList.Count-1 do
         begin
           fwpd:=TProcDef(TProcSym(currpd.ProcSym).ProcdefList[i]);

           { can happen for internally generated routines }
           if (fwpd=currpd) then
             begin
               result:=true;
               exit;
             end;

           { Skip overloaded definitions that are declared in other units }
           if fwpd.ProcSym<>currpd.ProcSym then
             continue;

           gensameparas:=false;
           gensameret:=false;
           sameparas:=false;
           sameret:=false;

           { check the parameters, for delphi/tp it is possible to
             leave the parameters away in the implementation (forwarddef=false).
             But for an overload declared function this is not allowed }
           if { check if empty implementation arguments match is allowed }
              (
               not(m_repeat_forward in CurrentSettings.ModeSwitches) and
               not(currpd.ForwardDef) and
               is_bareprocdef(currpd) and
               not(po_overload in fwpd.ProcOptions)
              ) or
              (
                fwpd.Is_Generic and
                currpd.Is_Generic and
                equal_generic_procdefs(fwpd,currpd,gensameparas,gensameret)
              ) or
              { check arguments, we need to check only the user visible parameters. The hidden parameters
                can be in a different location because of the calling convention, eg. L-R vs. R-L order (PFV)

                don't check default values here, because routines that are the same except for their default
                values should be reported as mismatches (since you can't overload based on different default
                parameter values) }
              (
                not fwpd.Is_Generic and
                not currpd.Is_Generic and
                equal_signature(fwpd,currpd,sameparas,sameret)
              ) then
             begin
               { Check if we've found the forwarddef, if found then
                 we need to update the forward def with the current
                 implementation settings }
               if fwpd.ForwardDef then
                 begin
                   forwardfound:=true;

                   if not(m_repeat_forward in CurrentSettings.ModeSwitches) and
                      (fwpd.ProcCallOption<>currpd.ProcCallOption) then
                     paracompopt:=[cpo_ignorehidden,cpo_comparedefaultvalue,cpo_openequalisexact,cpo_ignoreuniv]
                   else
                     paracompopt:=[cpo_comparedefaultvalue,cpo_openequalisexact,cpo_ignoreuniv];

                   { Check calling convention }
                   if (fwpd.ProcCallOption<>currpd.ProcCallOption) then
                    begin
                      { In delphi it is possible to specify the calling
                        convention in the interface or implementation if
                        there was no convention specified in the other
                        part }
                      if (m_delphi in CurrentSettings.ModeSwitches) then
                        begin
                          if not(po_hascallingconvention in currpd.ProcOptions) then
                            currpd.ProcCallOption:=fwpd.ProcCallOption
                          else
                            if not(po_hascallingconvention in fwpd.ProcOptions) then
                              fwpd.ProcCallOption:=currpd.ProcCallOption
                          else
                            begin
                              MessagePos(currpd.fileinfo,parser_e_call_convention_dont_match_forward);
                              TProcSym(currpd.ProcSym).Write_Parameter_Lists(currpd);
                              { restore interface settings }
                              currpd.ProcCallOption:=fwpd.ProcCallOption;
                            end;
                        end
                      else
                        begin
                          MessagePos(currpd.fileinfo,parser_e_call_convention_dont_match_forward);
                          TProcSym(currpd.ProcSym).Write_Parameter_Lists(currpd);
                          { restore interface settings }
                          currpd.ProcCallOption:=fwpd.ProcCallOption;
                        end;
                    end;

                   { Check static }
                   if (po_staticmethod in fwpd.ProcOptions) then
                    begin
                      if not (po_staticmethod in currpd.ProcOptions) then
                       begin
                         include(currpd.ProcOptions, po_staticmethod);
                         if (po_classmethod in currpd.ProcOptions) then
                          begin
                           { remove self from the hidden paras }
                           symentry:=currpd.ParaST.Find('self');
                           if symentry<>nil then
                            begin
                              currpd.ParaST.DeleteSym(symentry);
                              currpd.CalcParas;
                            end;
                          end;
                       end;
                    end;

                   { Check if the procedure type and return type are correct,
                     also the parameters must match also with the type and that
                     if the implementation has default parameters, the interface
                     also has them and that if they both have them, that they
                     have the same value }
                   if ((m_repeat_forward in CurrentSettings.ModeSwitches) or
                       not is_bareprocdef(currpd)) and
                       (
                         (
                           fwpd.Is_Generic and
                           currpd.Is_Generic and
                           not equal_generic_procdefs(fwpd,currpd,sameparas,sameret)
                         ) or
                         (
                           (
                             not fwpd.Is_Generic or
                             not currpd.Is_Generic
                           ) and
                           (
                             (compare_paras(fwpd.paras,currpd.paras,cp_all,paracompopt)<>te_exact) or
                             (compare_defs(fwpd.ReturnDef,currpd.ReturnDef,nothingn)<>te_exact)
                           )
                         )
                       ) then
                     begin
                       MessagePos1(currpd.fileinfo,parser_e_header_dont_match_forward,
                                   fwpd.FullProcName(false));
                       TProcSym(currpd.ProcSym).Write_Parameter_Lists(currpd);
                       break;
                     end;

                   { Check if both are declared forward }
                   if fwpd.ForwardDef and currpd.ForwardDef then
                    begin
                      MessagePos1(currpd.fileinfo,parser_e_function_already_declared_public_forward,
                                  currpd.FullProcName(false));
                    end;

                   { internconst or internproc only need to be defined once }
                   if (fwpd.ProcCallOption=pocall_internproc) then
                    currpd.ProcCallOption:=fwpd.ProcCallOption
                   else
                    if (currpd.ProcCallOption=pocall_internproc) then
                     fwpd.ProcCallOption:=currpd.ProcCallOption;

                   { Check procedure options, Delphi requires that class is
                     repeated in the implementation for class methods }
                   if (m_fpc in CurrentSettings.ModeSwitches) then
                     po_comp:=[po_classmethod,po_varargs,po_methodpointer,po_interrupt]
                   else
                     po_comp:=[po_classmethod,po_methodpointer];

                   if ((po_comp * fwpd.ProcOptions)<>(po_comp * currpd.ProcOptions)) or
                      (fwpd.ProcTypeOption <> currpd.ProcTypeOption) or
                      { if the implementation version has an "overload" modifier,
                        the interface version must also have it (otherwise we can
                        get annoying crashes due to interface crc changes) }
                      (not(po_overload in fwpd.ProcOptions) and
                       (po_overload in currpd.ProcOptions)) or
                      { same with noreturn }
                      (not(po_noreturn in fwpd.ProcOptions) and
                       (po_noreturn in currpd.ProcOptions)) then
                     begin
                       MessagePos1(currpd.fileinfo,parser_e_header_dont_match_forward,
                                   fwpd.FullProcName(false));
                       TProcSym(fwpd.ProcSym).Write_Parameter_Lists(fwpd);
                       { This error is non-fatal, we can recover }
                     end;

                   { Forward declaration is external? }
                   if (po_external in fwpd.ProcOptions) then
                     MessagePos(currpd.fileinfo,parser_e_proc_already_external);

                   { check for conflicts with "virtual" if this is a virtual
                     method, as "virtual" cannot be repeated in the
                     implementation and hence does not get checked against }
                   if (po_virtualmethod in fwpd.ProcOptions) then
                     begin
                       po_comp:=currpd.ProcOptions*PD_VIRTUAL_MUTEXCLPO;
                       if po_comp<>[] then
                         MessagePos2(currpd.fileinfo,parser_e_proc_dir_conflict,tokeninfo^[_VIRTUAL].str,get_first_proc_str(po_comp));
                     end;
                    { Check parameters }
                   if (m_repeat_forward in CurrentSettings.ModeSwitches) or
                      (currpd.MinParaCount>0) then
                    begin
                      { If mangled names are equal then they have the same amount of arguments }
                      { We can check the names of the arguments }
                      { both symtables are in the same order from left to right }
                      curridx:=0;
                      fwidx:=0;
                      currparacnt:=currpd.ParaST.SymList.Count;
                      fwparacnt:=fwpd.ParaST.SymList.Count;
                      repeat
                        { skip default parameter constsyms }
                        while (curridx<currparacnt) and
                              (TSym(currpd.ParaST.SymList[curridx]).typ<>paravarsym) do
                          inc(curridx);
                        while (fwidx<fwparacnt) and
                              (TSym(fwpd.ParaST.SymList[fwidx]).typ<>paravarsym) do
                          inc(fwidx);
                        { stop when one of the two lists is at the end }
                        if (fwidx>=fwparacnt) or (curridx>=currparacnt) then
                          break;
                        { compare names of parameters, ignore implicitly
                          renamed parameters }
                        currparasym:=TSym(currpd.ParaST.SymList[curridx]);
                        fwparasym:=TSym(fwpd.ParaST.SymList[fwidx]);
                        if not(sp_implicitrename in currparasym.SymOptions) and
                           not(sp_implicitrename in fwparasym.SymOptions) then
                          begin
                            if (currparasym.name<>fwparasym.name) then
                              begin
                                MessagePos3(currpd.fileinfo,parser_e_header_different_var_names,
                                            TProcSym(currpd.ProcSym).realname,fwparasym.realname,currparasym.realname);
                                break;
                              end;
                          end;
                        { next parameter }
                        inc(curridx);
                        inc(fwidx);
                      until false;
                    end;
                   { check that the type parameter names for generic methods match;
                     we check this here and not in equal_generic_procdefs as the defs
                     might still be different due to their parameters, so we'd generate
                     errors without any need }
                   if currpd.Is_Generic and fwpd.Is_Generic then
                     { an error here is recoverable, so we simply continue }
                     check_generic_parameters(fwpd,currpd);
                   { Everything is checked, now we can update the forward declaration
                     with the new data from the implementation }
                   fwpd.ForwardDef:=currpd.ForwardDef;
                   fwpd.HasForward:=true;
                   fwpd.ProcOptions:=fwpd.ProcOptions+currpd.ProcOptions;

                   { marked as local but exported from unit? }
                   if (po_kylixlocal in fwpd.ProcOptions) and (fwpd.owner.SymTableType=GlobalSymTable) then
                     MessagePos(fwpd.fileinfo,type_e_cant_export_local);

                   if fwpd.ExtNumber=$ffff then
                     fwpd.ExtNumber:=currpd.ExtNumber;
                   while not currpd.AliasNames.empty do
                     fwpd.AliasNames.insert(currpd.AliasNames.GetFirst);
                   { update fileinfo so position references the implementation,
                     also update funcretsym if it is already generated }
                   fwpd.fileinfo:=currpd.fileinfo;
                   if Assigned(fwpd.FuncRetSym) then
                     fwpd.FuncRetSym.fileinfo:=currpd.fileinfo;
                   if Assigned(currpd.DeprecatedMsg) then
                     begin
                       StringDispose(fwpd.DeprecatedMsg);
                       fwpd.DeprecatedMsg:=StringDup(currpd.DeprecatedMsg^);
                     end;
                   { import names }
                   if Assigned(currpd.ImportDLL) then
                     begin
                       StringDispose(fwpd.ImportDLL);
                       fwpd.ImportDLL:=StringDup(currpd.ImportDLL^);
                     end;
                   if Assigned(currpd.ImportName) then
                     begin
                       StringDispose(fwpd.ImportName);
                       fwpd.ImportName:=StringDup(currpd.ImportName^);
                     end;
                   fwpd.ImportNr:=currpd.ImportNr;
                   { for compilerproc defines we need to rename and update the
                     symbolname to lowercase so users can' access it (can't do
                     it immediately, because then the implementation symbol
                     won't be matched) }
                   if po_compilerproc in fwpd.ProcOptions then
                     begin
                       fwpd.SetCompilerProcName;
                       CurrentModule.Add_Public_AsmSym(fwpd.MangledName,AB_GLOBAL,AT_FUNCTION);
                     end;
                   if po_public in fwpd.ProcOptions then
                     begin
                       item:=fwpd.AliasNames.first;
                       while Assigned(item) do
                         begin
                           CurrentModule.Add_Public_AsmSym(TCmdStrListItem(item).str,AB_GLOBAL,AT_FUNCTION);
                           item:=item.next;
                         end;
                     end;

                   { Release current procdef }
                   currpd.owner.DeleteDef(currpd);
                   currpd:=fwpd;
                 end
               else
                begin
                  { abstract methods aren't forward defined, but this }
                  { needs another error message                   }
                  if (po_abstractmethod in fwpd.ProcOptions) then
                    MessagePos(currpd.fileinfo,parser_e_abstract_no_definition)
                  else
                    begin
                      MessagePos(currpd.fileinfo,parser_e_overloaded_have_same_parameters);
                      TProcSym(currpd.ProcSym).Write_Parameter_Lists(currpd);
                    end;
                 end;

               { we found one proc with the same arguments, there are no others
                 so we can stop }
               break;
             end;

           { check for allowing overload directive }
           if not(m_fpc in CurrentSettings.ModeSwitches) then
            begin
              { overload directive turns on overloading }
              if ((po_overload in currpd.ProcOptions) or
                  (po_overload in fwpd.ProcOptions)) then
               begin
                 { check if all procs have overloading, but not if the proc is a method or
                   already declared forward, then the check is already done }
                 if not(fwpd.HasForward or
                        Assigned(currpd.struct) or
                        (currpd.ForwardDef<>fwpd.ForwardDef) or
                        ((po_overload in currpd.ProcOptions) and
                         (po_overload in fwpd.ProcOptions))) then
                  begin
                    MessagePos1(currpd.fileinfo,parser_e_no_overload_for_all_procs,currpd.ProcSym.realname);
                    break;
                  end
               end
              else
               begin
                 if not(fwpd.ForwardDef) then
                  begin
                    MessagePos1(currpd.fileinfo,parser_e_no_overload_for_all_procs,currpd.ProcSym.realname);
                    break;
                  end;
               end;
            end; { equal arguments }

           { we found a match with the same parameter signature, but mismatching
             return types; complain about that, but only once we've checked for
             a forward to improve error recovery }
           if (sameparas and not sameret and
               { ensure that specifiers are the same as well }
               (compare_paras(fwpd.paras,currpd.paras,cp_all,[cpo_ignorehidden,cpo_openequalisexact,cpo_ignoreuniv])=te_exact)
               ) or (gensameparas and not gensameret) then
             sameparasfound:=true;
         end;

        if sameparasfound and
            not (currpd.ProcTypeOption=potype_operator) then
          begin
            MessagePos(currpd.fileinfo,parser_e_overloaded_have_same_parameters);
            TProcSym(currpd.ProcSym).Write_Parameter_Lists(currpd);
          end;

        { if we didn't reuse a forwarddef then we add the procdef to the overloaded
          list }
        if not forwardfound then
          begin
            { can happen in Delphi mode }
            if (currpd.ProcTypeOption = potype_function) and
               is_void(currpd.ReturnDef) then
              MessagePos1(currpd.fileinfo,parser_e_no_funcret_specified,currpd.ProcSym.realname);
            TProcSym(currpd.ProcSym).ProcdefList.Add(currpd);
            if not currpd.ForwardDef and (po_public in currpd.ProcOptions) then
              begin
                item:=currpd.AliasNames.first;
                while Assigned(item) do
                  begin
                    CurrentModule.Add_Public_AsmSym(TCmdStrListItem(item).str,AB_GLOBAL,AT_FUNCTION);
                    item:=item.next;
                  end;
              end;
          end;

        proc_add_definition:=forwardfound;
      end;


    procedure build_parentfpstruct(pd: TProcDef);
      var
        nestedvars: TSym;
        nestedvarsst: TSymTable;
        pnestedvarsdef,
        nestedvarsdef: TDef;
        old_symtablestack: TSymTableStack;
      begin
        { make sure the defs are not registered in the current symtablestack,
          because they may be for a parent procdef (changeowner does remove a def
          from the symtable in which it was originally created, so that by itself
          is not enough) }
        old_symtablestack:=SymTableStack;
        SymTableStack:=old_symtablestack.GetCopyUntil(CurrentModule.LocalSymTable);

        nestedvarsst:=TRecordSymTable.create('$'+CurrentModule.RealModuleName^+'$$_fpc_nestedvars$'+pd.UniqueIDStr,
          CurrentSettings.alignment.LocalAlignMax,CurrentSettings.alignment.LocalAlignMin);
        nestedvarsdef:=CRecordDef.create(nestedvarsst.name^,nestedvarsst);
        SymTableStack.free;
        SymTableStack:=old_symtablestack.GetCopyUntil(pd.LocalST);
        pnestedvarsdef:=CPointerDef.getreusable(nestedvarsdef);
        if not(po_assembler in pd.ProcOptions) then
          begin
            nestedvars:=CLocalVarSym.create('$nestedvars',vs_var,nestedvarsdef,[]);
            include(nestedvars.SymOptions,sp_internal);
            pd.LocalST.InsertSym(nestedvars);
            pd.ParentFPStruct:=nestedvars;
            pd.ParentFPInitBlock:=CBlockNode.create(nil);
          end;
        SymTableStack.free;
        pd.ParentFPStructPtrType:=pnestedvarsdef;

        SymTableStack:=old_symtablestack;
      end;

end.
