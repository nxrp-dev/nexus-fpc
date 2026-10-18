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

    procedure Insert_FuncRet_Para(AProcDef:TAbstractProcDef);
    procedure Insert_ParentFP_Para(AProcDef:TAbstractProcDef);
    procedure Insert_Self_And_VMT_Para(AProcDef:TAbstractProcDef);
    procedure Insert_FuncRet_Local(AProcDef:TProcDef);
    procedure Insert_Hidden_Para(AObject:TObject;AArg:Pointer);
    procedure Check_C_Para(AProcDef:TAbstractProcDef);
    procedure Insert_Struct_Hidden_Paras(AStructDef: TAbstractRecordDef);

    type
      // flags of the *handle_calling_convention routines
      THCCFlag=(
        hcc_declaration,          // declaration (as opposed to definition, i.e. interface rather than implementation)
        hcc_check,                // perform checks and output errors if found
        hcc_insert_hidden_paras   // insert hidden parameters
      );
      THCCFlags=set of THCCFlag;

    const
      cHCCDefaultActionsIntf=[hcc_declaration,hcc_check,hcc_insert_hidden_paras];
      cHCCDefaultActionsIntfStruct=cHCCDefaultActionsIntf-[hcc_insert_hidden_paras];
      cHCCDefaultActionsImpl=[hcc_check,hcc_insert_hidden_paras];
      cHCCDefaultActionsParse=[hcc_check,hcc_insert_hidden_paras];
      cVirtualMutuallyExclusiveProcOptions = [po_interrupt,po_exports,po_overridingmethod,po_inline,po_staticmethod];

    { may take procdef, procvardef or defs for which is_funcref is true }
    procedure Handle_Calling_Convention(AProcOrInvokableDef:TDef;AFlags:THCCFlags);
    function Proc_Add_Definition(var ACurrentProcDef:TProcDef):Boolean;

    { create "parent frame pointer" record skeleton for procdef, in which local
      variables and parameters from pd accessed from nested routines can be
      stored }
    procedure Build_ParentFPStruct(AProcDef: TProcDef);

implementation

    uses
      Globals,GlobType,CClasses,CUtils,Verbose,Systems,FModule,
      tokens,
      SymBase,SymSym,SymTable,symutil,defutil,defcmp,blockutl,
      node,nbas,
      aasmbase,
      paramgr;


    procedure Insert_FuncRet_Para(AProcDef:TAbstractProcDef);
      const
        cNameResult='result';
      var
        lStoredPosition : TFilePosInfo;
        lVarSym       : TParaVarSym;
        lParaNr   : Word;
      begin
        if not(AProcDef.ProcTypeOption in [potype_constructor,potype_destructor]) and
           not Is_Void(AProcDef.ReturnDef) and
           not (df_generic in AProcDef.DefOptions) and
           { if this was originally an anonymous function then this was already
             done earlier }
           not ((AProcDef.typ=procdef) and TProcDef(AProcDef).WasAnonymous) and
           ParaManager.Ret_In_Param(AProcDef.ReturnDef,AProcDef) and
           not Assigned(AProcDef.ParaST.find(cNameResult)) then
         begin
           lStoredPosition:=CurrentTokenPos;
           if AProcDef.typ=procdef then
            CurrentTokenPos:=TProcDef(AProcDef).fileinfo;
{$if defined(i386)}
           { For left to right add it at the end to be delphi compatible.
             In the case of safecalls with safecal-exceptions support the
             funcret-para is (from the 'c'-point of view) a normal parameter
             which has to be added to the end of the parameter-list }
           if (AProcDef.ProcCallOption in (PushLeftRight_PoCalls)) or
              ((tf_safecall_exceptions in TargetInfo.flags) and
               (AProcDef.ProcCallOption=pocall_safecall)) then
             lParaNr:=ParaNrResultLeftRight
           else
{$elseif defined(SUPPORT_SAFECALL)}
           if (tf_safecall_exceptions in TargetInfo.flags) and
              (AProcDef.ProcCallOption = pocall_safecall)  then
             lParaNr:=ParaNrResultLeftRight
           else
{$endif}
           if Is_Managed_Type(AProcDef.ReturnDef) then
             lParaNr:=ParaNrResultManaged
           else
             lParaNr:=ParaNrResult;
           { Generate result variable accessing function result }
           lVarSym:=CParaVarSym.Create('$'+cNameResult,lParaNr,vs_var,AProcDef.ReturnDef,[vo_is_funcret,vo_is_hidden_para]);
           AProcDef.ParaST.InsertSym(lVarSym);
           { Store this symbol as funcretsym for procedures }
           if AProcDef.typ=procdef then
            TProcDef(AProcDef).FuncRetSym:=lVarSym;

           CurrentTokenPos:=lStoredPosition;
         end;
      end;


    procedure Insert_ParentFP_Para(AProcDef:TAbstractProcDef);
      const
        cNameParentFP='parentfp';
      var
        lStoredPosition : TFilePosInfo;
        lVarSym       : TParaVarSym;
        lParaNr   : LongInt;
      begin
        if (AProcDef.ParaST.SymTableLevel>NormalFunctionLevel) and
           not Assigned(AProcDef.ParaST.find(cNameParentFP)) then
          begin
            lStoredPosition:=CurrentTokenPos;
            if AProcDef.typ=procdef then
             CurrentTokenPos:=TProcDef(AProcDef).fileinfo;

            { if no support for nested procvars is activated, use the old
              calling convention to pass the parent frame pointer for backwards
              compatibility }
            if not(m_nested_procvars in CurrentSettings.ModeSwitches) then
              lParaNr:=ParaNrParentFP
            { nested procvars require Delphi-style parentfp passing, see
              po_delphi_nested_cc declaration for more info }
{$if defined(i386)}
            else if (AProcDef.ProcCallOption in PushLeftRight_PoCalls) then
              lParaNr:=ParaNrParentFPDelphiCCLeftRight
{$endif i386}
            else
              lParaNr:=ParaNrParentFPDelphiCC;
            { Generate frame pointer. It can't be put in a register since it
              must be accessible from nested routines }

              begin
                lVarSym:=CParaVarSym.Create('$'+cNameParentFP,lParaNr,vs_value
                      ,ParentFPVoidPointerType,[vo_is_parentfp,vo_is_hidden_para]);
              end

            ;
            AProcDef.ParaST.InsertSym(lVarSym);

            CurrentTokenPos:=lStoredPosition;
          end;
      end;


    procedure Insert_Self_And_VMT_Para(AProcDef:TAbstractProcDef);
      const
        cNameCmd='_cmd';
        cNameSelf='self';
        cNameBlockLiteral='_block_literal';
        cNameVMT='vmt';
      var
        lStoredPosition : TFilePosInfo;
        lVarSym       : TParaVarSym;
        lDef     : TDef;
        lSelfDef  : TDef;
        lParaVarSym      : TVarSpez;
        lAliasVarSym  : TAbsoluteVarSym;
        lSymList       : TPropAccessList;
      begin
        if (AProcDef.typ=procdef) and
           Is_ObjC_Class_Or_Protocol(TProcDef(AProcDef).struct) and
           (AProcDef.ParaST.SymTableLevel=NormalFunctionLevel) then
          begin
            if not Assigned(AProcDef.ParaST.find(cNameCmd)) or
                not Assigned(AProcDef.ParaST.find(cNameSelf)) then
              begin
                { insert Objective-C self and selector parameters }
                lVarSym:=CParaVarSym.Create('$'+cNameCmd,ParaNrObjCCmd,vs_value,ObjC_SelType,[vo_is_msgsel,vo_is_hidden_para]);
                AProcDef.ParaST.InsertSym(lVarSym);
                { make accessible to code }
                lSymList:=TPropAccessList.Create;
                lSymList.AddSym(sl_load,lVarSym);
                lAliasVarSym:=CAbsoluteVarSym.Create_Ref('_CMD',ObjC_SelType,lSymList);
                include(lAliasVarSym.VarOptions,vo_is_msgsel);
                TLocalSymTable(TProcDef(AProcDef).LocalST).InsertSym(lAliasVarSym);

                if (po_classmethod in AProcDef.ProcOptions) then
                  { compatible with what gcc does }
                  lDef:=ObjC_IDType
                else
                  lDef:=TProcDef(AProcDef).struct;

                lVarSym:=CParaVarSym.Create('$'+cNameSelf,ParaNrObjCSelf,vs_value,lDef,[vo_is_self,vo_is_hidden_para]);
                AProcDef.ParaST.InsertSym(lVarSym);
              end;
          end
        else if (AProcDef.typ=procvardef) and
           AProcDef.Is_MethodPointer then
          begin
            if not Assigned(AProcDef.ParaST.find(cNameSelf)) then
              begin
                { Generate self variable }
                lVarSym:=CParaVarSym.Create('$'+cNameSelf,ParaNrSelf,vs_value,VoidPointerType,[vo_is_self,vo_is_hidden_para]);
                AProcDef.ParaST.InsertSym(lVarSym);
              end;
          end
        { while only procvardefs of this type can be declared in Pascal code,
          internally we also generate procdefs of this type when creating
          block wrappers }
        else if (po_is_block in AProcDef.ProcOptions) then
          begin
            if not Assigned(AProcDef.ParaST.find('$'+cNameBlockLiteral)) then
              begin
                { generate the first hidden parameter, which is a so-called "block
                  literal" describing the block and containing its invocation
                  procedure  }
                lDef:=CPointerDef.getreusable(get_block_literal_type_for_proc(AProcDef));
                { mark as vo_is_parentfp so that proc2procvar comparisons will
                  succeed when assigning arbitrary routines to the block }
                lVarSym:=CParaVarSym.Create('$'+cNameBlockLiteral,ParaNrBlockSelfPara,vs_value,
                  lDef,[vo_is_hidden_para,vo_is_parentfp]
                );
                AProcDef.ParaST.InsertSym(lVarSym);
                if AProcDef.typ=procdef then
                  begin
                    { make accessible to code }
                    lSymList:=TPropAccessList.Create;
                    lSymList.AddSym(sl_load,lVarSym);
                    lAliasVarSym:=CAbsoluteVarSym.Create_Ref('FPC_BLOCK_SELF',lDef,lSymList);
                    include(lAliasVarSym.VarOptions,vo_is_parentfp);
                    TLocalSymTable(TProcDef(AProcDef).LocalST).InsertSym(lAliasVarSym);
                  end;
              end;
          end
        else
          begin
             if (AProcDef.typ=procdef) and
                Assigned(TProcDef(AProcDef).struct) and
                (
                  (AProcDef.ParaST.SymTableLevel=NormalFunctionLevel) or
                  ([po_anonymous,po_methodpointer]<=AProcDef.ProcOptions)
                ) then
              begin
                { static class methods have no hidden self/vmt pointer }
                if AProcDef.No_Self_Node then
                   exit;

                lStoredPosition:=CurrentTokenPos;
                CurrentTokenPos:=TProcDef(AProcDef).fileinfo;

                { Generate VMT variable for constructor/destructor }
                if (AProcDef.ProcTypeOption in [potype_constructor,potype_destructor]) and
                   not(Is_CPPClass(TProcDef(AProcDef).struct) or
                       Is_Record(TProcDef(AProcDef).struct) or (Is_ObjectPascal_Helper(TProcDef(AProcDef).struct) and
                         (TObjectDef(TProcDef(AProcDef).struct).ExtendedDef.typ<>objectdef)
                       )) and
                   not Assigned(AProcDef.ParaST.find(cNameVMT)) then
                 begin
                   lVarSym:=CParaVarSym.Create('$'+cNameVMT,ParaNrVMT,vs_value,CClassRefDef.Create(TProcDef(AProcDef).struct),[vo_is_vmt,vo_is_hidden_para]);
                   AProcDef.ParaST.InsertSym(lVarSym);
                 end;

                { for helpers the type of Self is equivalent to the extended
                  type or equal to an instance of it }
                if Is_ObjectPascal_Helper(TProcDef(AProcDef).struct) then
                  lSelfDef:=TObjectDef(TProcDef(AProcDef).struct).ExtendedDef
                else if Is_ObjCCategory(TProcDef(AProcDef).struct) then
                  lSelfDef:=TObjectDef(TProcDef(AProcDef).struct).ChildOf
                else
                  lSelfDef:=TProcDef(AProcDef).struct;
                { Generate self variable, for classes we need
                  to use the generic voidpointer to be compatible with
                  methodpointers }
                lParaVarSym:=vs_value;
                if (po_staticmethod in AProcDef.ProcOptions) or
                   (po_classmethod in AProcDef.ProcOptions) then
                  lDef:=CClassRefDef.Create(lSelfDef)
                else
                  begin
                    if Is_Object(lSelfDef) or (lSelfDef.typ<>objectdef) then
                      lParaVarSym:=vs_var;
                    lDef:=lSelfDef;
                  end;
                lVarSym:=TParaVarSym(AProcDef.ParaST.find(cNameSelf));
                if not Assigned(lVarSym) or (lVarSym.typ<>paravarsym) or (lVarSym.vardef<>lDef) then
                  begin
                    lVarSym:=CParaVarSym.Create('$'+cNameSelf,ParaNrSelf,lParaVarSym,lDef,[vo_is_self,vo_is_hidden_para]);
                    AProcDef.ParaST.InsertSym(lVarSym);
                  end;

                CurrentTokenPos:=lStoredPosition;
              end;
          end;
      end;


    procedure Insert_FuncRet_Local(AProcDef:TProcDef);
      var
        lStoredPosition : TFilePosInfo;
        lVarSym       : TLocalVarSym;
        lAliasVarSym  : TAbsoluteVarSym;
        lSymList       : TPropAccessList;
        lSym       : String;
      begin
        lStoredPosition:=CurrentTokenPos;
        CurrentTokenPos:=AProcDef.fileinfo;

        { The result from constructors and destructors can't be accessed directly }
        if not(AProcDef.ProcTypeOption in [potype_constructor,potype_destructor]) and
           not Is_Void(AProcDef.ReturnDef) and
           (not(po_assembler in AProcDef.ProcOptions) or ParaManager.Asm_Result_Var(AProcDef.ReturnDef,AProcDef)) then
         begin
           { We need to insert a varsym for the result in the localst
             when it is returning in a register }
           { we also need to do this for a generic procdef as we didn't allow
             the creation of a result symbol in insert_funcret_para, but we need
             a valid funcretsym }
           if (df_generic in AProcDef.DefOptions) or
               not ParaManager.Ret_In_Param(AProcDef.ReturnDef,AProcDef) then
            begin
              lVarSym:=CLocalVarSym.Create('$result',vs_value,AProcDef.ReturnDef,[vo_is_funcret]);
              AProcDef.LocalST.InsertSym(lVarSym,false);
              AProcDef.FuncRetSym:=lVarSym;
            end;

           { insert the name of the procedure as alias for the function result,
             we can't use realname because that will not work for compilerprocs
             as the name is lowercase and unreachable from the code;
             don't insert this alias for an anonymous function unless an
             explicit name is provided }
           if (
                 (AProcDef.ProcTypeOption<>potype_operator) and
                 not (po_anonymous in AProcDef.ProcOptions)
               ) or Assigned(AProcDef.ResultName) then
             begin
               if Assigned(AProcDef.ResultName) then
                 lSym:=AProcDef.ResultName^
               else
                 lSym:=AProcDef.ProcSym.name;
               if (lSym='') then
                 lSym:='$_result';
               lSymList:=TPropAccessList.Create;
               lSymList.AddSym(sl_load,AProcDef.FuncRetSym);
               lAliasVarSym:=CAbsoluteVarSym.Create_Ref(lSym,AProcDef.ReturnDef,lSymList);
               include(lAliasVarSym.VarOptions,vo_is_funcret);
               TLocalSymTable(AProcDef.LocalST).InsertSym(lAliasVarSym);
             end;

           { insert result also if support is on }
           if (m_result in CurrentSettings.ModeSwitches) then
            begin
              lSymList:=TPropAccessList.Create;
              lSymList.AddSym(sl_load,AProcDef.FuncRetSym);
              lAliasVarSym:=CAbsoluteVarSym.Create_Ref('RESULT',AProcDef.ReturnDef,lSymList);
              include(lAliasVarSym.VarOptions,vo_is_funcret);
              include(lAliasVarSym.VarOptions,vo_is_result);
              TLocalSymTable(AProcDef.LocalST).InsertSym(lAliasVarSym);
            end;

         end;

        if AProcDef.Generate_SafeCall_Wrapper then
          begin
            { vo_is_funcret is necessary so the local only gets freed after we loaded its
              value into the return register }
            lVarSym:=CLocalVarSym.Create('$safecallresult',vs_value,Search_System_Type('HRESULT').TypeDef,[vo_is_funcret]);
            { do not put this variable in a register. The register which will be bound
              to this symbol will not be allocated automatically. Which means it will
              be re-used which breaks the code. Besides this it is questionable if it is
              an optimization if one of the registers is kept allocated during the complete
              function, without ever using it.
              (It would be better to re-write the safecall-support in such a way that this
              variable it not needed at all, but that the HRESULT is set when the method
              is finalized) }
            lVarSym.VarRegable:=vr_none;
            AProcDef.LocalST.InsertSym(lVarSym);
          end;

        CurrentTokenPos:=lStoredPosition;
      end;


    procedure Insert_Hidden_Para(AObject:TObject;AArg:Pointer);
      const
        cNameHigh = 'high';
        cNameTypeInfo = 'typinfo';
      var
        lName   : TSymStr;
        lHiddenVarSym : TParaVarSym;
        lProcDef  : TAbstractProcDef absolute AArg;
      begin
        if (TSym(AObject).typ<>paravarsym) then
         exit;
        with TParaVarSym(AObject) do
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
              ParaManager.Push_Addr_Param(VarSpez,vardef,lProcDef.ProcCallOption) and
              not(Is_Open_Array(vardef) or
                  Is_Array_Of_Const(vardef)) and
              (not(TargetInfo.system in systems_caller_copy_addr_value_para) or
               ((lProcDef.ProcCallOption in CDecl_PoCalls) and
                (vardef.typ=arraydef))) then
             include(VarOptions,vo_has_local_copy);

           { needs high parameter ? }
           if ParaManager.Push_High_Param(VarSpez,vardef,lProcDef.ProcCallOption) then
             begin
               lName:=cNameHigh+name;
               if not Assigned(owner.find(lName)) then
                 begin

                     lHiddenVarSym:=CParaVarSym.Create('$'+lName,ParaNr+1,vs_const,SizeSIntType,[vo_is_high_para,vo_is_hidden_para]);
                   lHiddenVarSym.SymOptions:=[];
                   owner.InsertSym(lHiddenVarSym);
                   { don't place to register if it will be accessed from implicit finally block }
                   if (VarSpez=vs_value) and
                      Is_Open_Array(vardef) and
                      Is_Managed_Type(vardef) then
                     lHiddenVarSym.VarRegable:=vr_none;
                 end;
             end
           else
            begin
              { Give a warning that cdecl routines does not include high()
                support }
              if (lProcDef.ProcCallOption in CDecl_PoCalls) and
                 ParaManager.Push_High_Param(VarSpez,vardef,pocall_default) then
               begin
                 if Is_Open_String(vardef) then
                    MessagePos(fileinfo,parser_w_cdecl_no_openstring);
                 if not(po_external in lProcDef.ProcOptions) and
                    (lProcDef.typ<>procvardef) and
                    not Is_ObjC_Class_Or_Protocol(TProcDef(lProcDef).struct) then
                   if Is_Array_Of_Const(vardef) then
                     MessagePos(fileinfo,parser_e_varargs_need_cdecl_and_external)
                   else
                     MessagePos(fileinfo,parser_w_cdecl_has_no_high);
               end;
              if (vardef.typ=formaldef) and (TFormalDef(vardef).typed) then
                begin
                  lName:=cNameTypeInfo+name;
                  if not Assigned(owner.find(lName)) then
                    begin
                      lHiddenVarSym:=CParaVarSym.Create('$'+lName,ParaNr+1,vs_const,VoidPointerType,
                                              [vo_is_typinfo_para,vo_is_hidden_para]);
                      owner.InsertSym(lHiddenVarSym);
                    end;
                end;
            end;
         end;
      end;


    procedure Check_C_Para(AProcDef:TAbstractProcDef);
      var
        lIndex,
        lLastParaIndex : LongInt;
        lSym : TSym;
      begin
        lLastParaIndex:=AProcDef.ParaST.SymList.Count-1;
        for lIndex:=0 to AProcDef.ParaST.SymList.Count-1 do
          begin
            lSym:=TSym(AProcDef.ParaST.SymList[lIndex]);
            if (lSym.typ=paravarsym) and
               (TParaVarSym(lSym).vardef.typ=arraydef) then
              begin
                if not Is_Variant_Array(TParaVarSym(lSym).vardef) and
                   not Is_Array_Of_Const(TParaVarSym(lSym).vardef) and
                   (TParaVarSym(lSym).VarSpez<>vs_var) then
                  MessagePos(TParaVarSym(lSym).fileinfo,parser_h_c_arrays_are_references);
                if Is_Array_Of_Const(TParaVarSym(lSym).vardef) and
                   (lIndex<lLastParaIndex) and
                   (TSym(AProcDef.ParaST.SymList[lIndex+1]).typ=paravarsym) and
                   not(vo_is_high_para in TParaVarSym(AProcDef.ParaST.SymList[lIndex+1]).VarOptions) then
                  MessagePos(TParaVarSym(lSym).fileinfo,parser_e_C_array_of_const_must_be_last);
              end;
          end;
      end;


    procedure Insert_Struct_Hidden_Paras(AStructDef: TAbstractRecordDef);
      var
        lProcDef: TDef;
        lIndex: LongInt;
        lOldPosition: TFilePosInfo;
      begin
        // handle calling conventions of record methods
        lOldPosition:=CurrentFilePos;

        for lIndex := 0 to AStructDef.SymTable.DefList.count - 1 do
          begin
            lProcDef:=TDef(AStructDef.SymTable.DefList[lIndex]);
            if lProcDef.typ<>procdef then
              continue;
            CurrentFilePos:=TProcDef(lProcDef).fileinfo;
            Handle_Calling_Convention(TProcDef(lProcDef),[hcc_declaration,hcc_insert_hidden_paras]);
          end;
        CurrentFilePos:=lOldPosition;
      end;


    procedure SetAddrParamRegable(AObject:TObject;AArg:Pointer);
      begin
        if (TSym(AObject).typ<>paravarsym) then
         exit;
        with TParaVarSym(AObject) do
         begin
           if (not Needs_Finalization) and
              ParaManager.Push_Addr_Param(VarSpez,vardef,TProcDef(AArg).ProcCallOption) then
             VarRegable:=vr_addr;
         end;
      end;


    procedure Handle_Calling_Convention(AProcOrInvokableDef:TDef;AFlags:THCCFlags);
      var
        lProcDef : TAbstractProcDef;
      begin
        if Is_FuncRef(AProcOrInvokableDef) then
          lProcDef:=Get_Invoke_ProcDef(TObjectDef(AProcOrInvokableDef))
        else if AProcOrInvokableDef.typ in [procdef,procvardef] then
          lProcDef:=TAbstractProcDef(AProcOrInvokableDef)
        else
          InternalError(2022012502);
        if hcc_check in AFlags then
          begin
            { set the default calling convention if none provided }
            if (lProcDef.typ=procdef) and
               (Is_ObjC_Class_Or_Protocol(TProcDef(lProcDef).struct) or
                Is_CPPClass(TProcDef(lProcDef).struct)) then
              begin
                { none of the explicit calling conventions should be allowed }
                if (po_hascallingconvention in lProcDef.ProcOptions) then
                  InternalError(2009032501);
                if Is_CPPClass(TProcDef(lProcDef).struct) then
                  lProcDef.ProcCallOption:=pocall_cppdecl
                else
                  lProcDef.ProcCallOption:=pocall_cdecl;
              end
            else if not(po_hascallingconvention in lProcDef.ProcOptions) then
              lProcDef.ProcCallOption:=CurrentSettings.DefProcCall
            else
              begin
                if lProcDef.ProcCallOption=pocall_none then
                  InternalError(200309081);
              end;

            { handle proccall specific settings }
            case lProcDef.ProcCallOption of
              pocall_cdecl,
              pocall_cppdecl,
              pocall_sysv_abi_cdecl,
              pocall_ms_abi_cdecl:
                begin
                  { check C cdecl para types }
                  Check_C_Para(lProcDef);
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
            if (po_inline in lProcDef.ProcOptions) and
               not(cs_do_inline in CurrentSettings.LocalSwitches) then
              begin
                { Give an error if inline is not supported by the compiler mode,
                  otherwise only give a hint that this procedure will not be inlined }
                if not(m_default_inline in CurrentSettings.ModeSwitches) then
                  Message(parser_e_proc_inline_not_supported)
                else
                  Message(parser_h_inlining_disabled);
                exclude(lProcDef.ProcOptions,po_inline);
              end;

            { For varargs directive also cdecl and external must be defined }
            if (po_varargs in lProcDef.ProcOptions) then
             begin
               { check first for external in the interface, if available there
                 then the cdecl must also be there since there is no implementation
                 available to contain it }
               if hcc_declaration in AFlags then
                begin
                  { if external is available, then cdecl must also be available,
                    procvars don't need external }
                  if not((po_external in lProcDef.ProcOptions) or
                         (lProcDef.typ=procvardef) or
                         { for objcclasses this is checked later, because the entire
                           class may be external.  }
                         Is_ObjC_Class_Or_Protocol(TProcDef(lProcDef).struct)) and
                     not(lProcDef.ProcCallOption in (CDecl_PoCalls + [pocall_stdcall])) then
                    Message(parser_e_varargs_need_cdecl_and_external);
                end
               else
                begin
                  { both must be defined now }
                  if not((po_external in lProcDef.ProcOptions) or
                         (lProcDef.typ=procvardef)) or
                     not(lProcDef.ProcCallOption in cstylearrayofconst) then
                    Message(parser_e_varargs_need_cdecl_and_external);
                end;
             end;
          end;

        if hcc_insert_hidden_paras in AFlags then
          begin
            { If the paraloc info has been calculated already, it will be missing for
              the new parameters we add below. This should never be necessary before
              we add them, as users of this information would not process these extra
              parameters in that case }
            if lProcDef.HasParaLocInfo<>callnoside then
              InternalError(2019031610);

            { insert hidden high parameters }
            lProcDef.ParaST.SymList.ForEachCall(@Insert_Hidden_Para,lProcDef);

            { insert hidden self parameter }
            Insert_Self_And_VMT_Para(lProcDef);

            { insert funcret parameter if required }
            Insert_FuncRet_Para(lProcDef);

            { Make var parameters regable, this must be done after the calling
              convention is set. }
            { this must be done before parentfp is insert, because getting all cases
              where parentfp must be in a memory location isn't catched properly so
              we put parentfp never in a register }
            lProcDef.ParaST.SymList.ForEachCall(@SetAddrParamRegable,lProcDef);

            { insert parentfp parameter if required }
            Insert_ParentFP_Para(lProcDef);
          end;

        { Calculate parameter tlist }
        lProcDef.CalcParas;
      end;


    function Proc_Add_Definition(var ACurrentProcDef:TProcDef):Boolean;

      function CheckGenericParameters(AForwardProcDef,ACurrentProcDef:TProcDef):Boolean;
        var
          lIndex : LongInt;
          lForwardSym,
          lCurrentSym : TSym;
          lCurrentType : TTypeSym absolute lCurrentSym;
          lFileInfo : TFilePosInfo;
        begin
          Result:=true;
          if AForwardProcDef.GenericParas.count<>ACurrentProcDef.GenericParas.count then
            InternalError(2018090101);
          for lIndex:=0 to AForwardProcDef.GenericParas.count-1 do
            begin
              lForwardSym:=TSym(AForwardProcDef.GenericParas[lIndex]);
              lCurrentSym:=TSym(ACurrentProcDef.GenericParas[lIndex]);
              if lForwardSym.name<>lCurrentSym.name then
                begin
                  messagepos1(lCurrentSym.fileinfo,sym_e_generic_type_param_mismatch,lCurrentSym.realname);
                  messagepos1(lForwardSym.fileinfo,sym_e_generic_type_param_decl,lForwardSym.realname);
                  Result:=false;
                end;
              if (AForwardProcDef.InterfaceDef or Assigned(AForwardProcDef.struct)) and
                 (
                   ((lCurrentSym.typ=TypeSym) and (df_genconstraint in lCurrentType.TypeDef.DefOptions)) or
                   (lCurrentSym.typ=constsym)
                 ) then
                begin
                  if lCurrentSym.typ=constsym then
                    lFileInfo:=lCurrentSym.fileinfo
                  else
                    lFileInfo:=TStoredDef(lCurrentType.TypeDef).GenConstraintData.fileinfo;
                  messagepos(lFileInfo,parser_e_generic_constraints_not_allowed_here);
                  Result:=false;
                end;
              if not AForwardProcDef.InterfaceDef and not Assigned(AForwardProcDef.struct) and
                 (lForwardSym.typ=constsym) then
                begin
                  { without modeswitch RepeatForward we need to check here
                    if the type of the constants match }
                  if (lCurrentSym.typ<>constsym) or not Equal_Defs(TConstSym(lForwardSym).ConstDef,TConstSym(lCurrentSym).ConstDef) then
                    begin
                      messagepos1(ACurrentProcDef.fileinfo,parser_e_header_dont_match_forward,ACurrentProcDef.FullProcName(false));
                      Result:=false;
                    end;
                end;
            end;
        end;


      function EqualGenericProcDefs(AForwardProcDef,ACurrentProcDef:TProcDef;out ASameParas,ASameReturn:Boolean):Boolean;
        var
          lIndex : LongInt;
          lForwardSym,
          lCurrentSym : TSym;
          lCurrentType : TTypeSym absolute lCurrentSym;
          lDummyConversion: TConvertType;
          lDummyProcDef: TProcDef;
        begin
          Result:=false;
          ASameParas:=false;
          ASameReturn:=false;
          if AForwardProcDef.GenericParas.count<>ACurrentProcDef.GenericParas.count then
            exit;
          { comparing generic declarations is a bit more cumbersome as the
            defs of the generic parameter types are not equal, especially if the
            declaration contains constraints; essentially we have two cases:
            - proc declared in interface of unit (or in class/record/object)
              and defined in implementation; here the fwpd might contain
              constraints while currpd must only contain undefineddefs
            - forward declaration in implementation: here constraints must be
              repeated }
          for lIndex:=0 to AForwardProcDef.GenericParas.count-1 do
            begin
              lForwardSym:=TSym(AForwardProcDef.GenericParas[lIndex]);
              lCurrentSym:=TSym(ACurrentProcDef.GenericParas[lIndex]);
              { if the type in the currpd isn't a pure undefineddef (thus there
                are constraints and the fwpd was declared in the interface, then
                we can stop right there }
              if AForwardProcDef.InterfaceDef and
                 (
                   (lCurrentSym.typ=constsym) or
                   ((lCurrentSym.typ=TypeSym) and
                     (
                       (lCurrentType.TypeDef.typ<>undefineddef) or
                       (df_genconstraint in lCurrentType.TypeDef.DefOptions)
                     )
                   )
                 )then
                exit;
              if not AForwardProcDef.InterfaceDef then
                begin
                  if (lForwardSym.typ=constsym) and (lCurrentSym.typ=constsym) then
                    begin
                      { check whether the constant type for forward functions match }
                      if not Equal_Defs(TConstSym(lForwardSym).ConstDef,TConstSym(lCurrentSym).ConstDef) then
                        exit;
                    end
                  else if (lForwardSym.typ=constsym) then
                    { if the forward sym is a constant, the implementation needs to be one
                      as well }
                    exit;
                end;
            end;
          if Compare_Paras(AForwardProcDef.paras,ACurrentProcDef.paras,cp_none,[cpo_ignorehidden,cpo_openequalisexact,cpo_ignoreuniv,cpo_generic])<>te_exact then
            exit;
          ASameParas:=true;
          if (df_specialization in TStoredDef(AForwardProcDef.ReturnDef).DefOptions) and (df_specialization in TStoredDef(ACurrentProcDef.ReturnDef).DefOptions) then
            { for specializations we're happy with equal defs instead of exactly the same defs }
            Result:=Equal_Defs(AForwardProcDef.ReturnDef,ACurrentProcDef.ReturnDef)
          else
            begin
              { strictly compare defs using compare_defs_ext, but allow
                non exactly equal undefineddefs }
              lDummyConversion:=tc_none;
              lDummyProcDef:=nil;
              Result:=(Compare_Defs_Ext(AForwardProcDef.ReturnDef,ACurrentProcDef.ReturnDef,nothingn,lDummyConversion,lDummyProcDef,[cdo_allow_variant,cdo_strict_undefined_check])=te_exact) or
                        Equal_GenFunc_ParaDefs(AForwardProcDef.ReturnDef,ACurrentProcDef.ReturnDef,AForwardProcDef.ParaST,ACurrentProcDef.ParaST);
            end;
          { the result variable is only set depending on the return type, so we
            can simply use "result" }
          ASameReturn:=Result;
        end;

      function EqualSignature(AForwardProcDef,ACurrentProcDef:TProcDef;out ASameParas,ASameReturn:Boolean):Boolean;
        begin
          ASameParas:=Compare_Paras(AForwardProcDef.paras,ACurrentProcDef.paras,cp_none,[cpo_ignorehidden,cpo_openequalisexact,cpo_ignoreuniv])=te_exact;
          ASameReturn:=Compare_RetType(AForwardProcDef.ReturnDef,ACurrentProcDef.ReturnDef)=te_exact;
          Result:=ASameParas and ASameReturn;
        end;

      {
        Add definition aprocdef to the overloaded definitions of aprocsym. If a
        forwarddef is found and reused it returns true
      }
      var
        lForwardProcDef    : TProcDef;
        lCurrentParaSym,
        lForwardParaSym : TSym;
        lCurrentParaCount,
        lForwardParaCount,
        lCurrentIndex,
        lForwardIndex,
        lIndex       : LongInt;
        lProcOptions : TProcOptions;
        lParaCompareOptions: TCompareParasOptions;
        lSameParasFound,
        lGenericSameParas,
        lGenericSameReturn,
        lSameParas,
        lSameReturn,
        lForwardFound : Boolean;
        lSymEntry: TSymEntry;
        lItem : TLinkedListItem;
      begin
        lForwardFound:=false;

        if Assigned(ACurrentProcDef.struct) and
           (ACurrentProcDef.struct.SymTable.ModuleID<>CurrentModule.ModuleID) and
           not (df_specialization in ACurrentProcDef.DefOptions) then
          begin
            Result:=false;
            exit;
          end;

        lSameParasFound:=false;
        lForwardProcDef:=nil;

        { check overloaded functions if the same function already exists }
        for lIndex:=0 to TProcSym(ACurrentProcDef.ProcSym).ProcdefList.Count-1 do
         begin
           lForwardProcDef:=TProcDef(TProcSym(ACurrentProcDef.ProcSym).ProcdefList[lIndex]);

           { can happen for internally generated routines }
           if (lForwardProcDef=ACurrentProcDef) then
             begin
               Result:=true;
               exit;
             end;

           { Skip overloaded definitions that are declared in other units }
           if lForwardProcDef.ProcSym<>ACurrentProcDef.ProcSym then
             continue;

           lGenericSameParas:=false;
           lGenericSameReturn:=false;
           lSameParas:=false;
           lSameReturn:=false;

           { check the parameters, for delphi/tp it is possible to
             leave the parameters away in the implementation (forwarddef=false).
             But for an overload declared function this is not allowed }
           if { check if empty implementation arguments match is allowed }
              (
               not(m_repeat_forward in CurrentSettings.ModeSwitches) and
               not(ACurrentProcDef.ForwardDef) and
               Is_BareProcDef(ACurrentProcDef) and
               not(po_overload in lForwardProcDef.ProcOptions)
              ) or
              (
                lForwardProcDef.Is_Generic and
                ACurrentProcDef.Is_Generic and
                EqualGenericProcDefs(lForwardProcDef,ACurrentProcDef,lGenericSameParas,lGenericSameReturn)
              ) or
              { check arguments, we need to check only the user visible parameters. The hidden parameters
                can be in a different location because of the calling convention, eg. L-R vs. R-L order (PFV)

                don't check default values here, because routines that are the same except for their default
                values should be reported as mismatches (since you can't overload based on different default
                parameter values) }
              (
                not lForwardProcDef.Is_Generic and
                not ACurrentProcDef.Is_Generic and
                EqualSignature(lForwardProcDef,ACurrentProcDef,lSameParas,lSameReturn)
              ) then
             begin
               { Check if we've found the forwarddef, if found then
                 we need to update the forward def with the current
                 implementation settings }
               if lForwardProcDef.ForwardDef then
                 begin
                   lForwardFound:=true;

                   if not(m_repeat_forward in CurrentSettings.ModeSwitches) and
                      (lForwardProcDef.ProcCallOption<>ACurrentProcDef.ProcCallOption) then
                     lParaCompareOptions:=[cpo_ignorehidden,cpo_comparedefaultvalue,cpo_openequalisexact,cpo_ignoreuniv]
                   else
                     lParaCompareOptions:=[cpo_comparedefaultvalue,cpo_openequalisexact,cpo_ignoreuniv];

                   { Check calling convention }
                   if (lForwardProcDef.ProcCallOption<>ACurrentProcDef.ProcCallOption) then
                    begin
                      { In delphi it is possible to specify the calling
                        convention in the interface or implementation if
                        there was no convention specified in the other
                        part }
                      if (m_delphi in CurrentSettings.ModeSwitches) then
                        begin
                          if not(po_hascallingconvention in ACurrentProcDef.ProcOptions) then
                            ACurrentProcDef.ProcCallOption:=lForwardProcDef.ProcCallOption
                          else
                            if not(po_hascallingconvention in lForwardProcDef.ProcOptions) then
                              lForwardProcDef.ProcCallOption:=ACurrentProcDef.ProcCallOption
                          else
                            begin
                              MessagePos(ACurrentProcDef.fileinfo,parser_e_call_convention_dont_match_forward);
                              TProcSym(ACurrentProcDef.ProcSym).Write_Parameter_Lists(ACurrentProcDef);
                              { restore interface settings }
                              ACurrentProcDef.ProcCallOption:=lForwardProcDef.ProcCallOption;
                            end;
                        end
                      else
                        begin
                          MessagePos(ACurrentProcDef.fileinfo,parser_e_call_convention_dont_match_forward);
                          TProcSym(ACurrentProcDef.ProcSym).Write_Parameter_Lists(ACurrentProcDef);
                          { restore interface settings }
                          ACurrentProcDef.ProcCallOption:=lForwardProcDef.ProcCallOption;
                        end;
                    end;

                   { Check static }
                   if (po_staticmethod in lForwardProcDef.ProcOptions) then
                    begin
                      if not (po_staticmethod in ACurrentProcDef.ProcOptions) then
                       begin
                         include(ACurrentProcDef.ProcOptions, po_staticmethod);
                         if (po_classmethod in ACurrentProcDef.ProcOptions) then
                          begin
                           { remove self from the hidden paras }
                           lSymEntry:=ACurrentProcDef.ParaST.Find('self');
                           if lSymEntry<>nil then
                            begin
                              ACurrentProcDef.ParaST.DeleteSym(lSymEntry);
                              ACurrentProcDef.CalcParas;
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
                       not Is_BareProcDef(ACurrentProcDef)) and
                       (
                         (
                           lForwardProcDef.Is_Generic and
                           ACurrentProcDef.Is_Generic and
                           not EqualGenericProcDefs(lForwardProcDef,ACurrentProcDef,lSameParas,lSameReturn)
                         ) or
                         (
                           (
                             not lForwardProcDef.Is_Generic or
                             not ACurrentProcDef.Is_Generic
                           ) and
                           (
                             (Compare_Paras(lForwardProcDef.paras,ACurrentProcDef.paras,cp_all,lParaCompareOptions)<>te_exact) or
                             (Compare_Defs(lForwardProcDef.ReturnDef,ACurrentProcDef.ReturnDef,nothingn)<>te_exact)
                           )
                         )
                       ) then
                     begin
                       MessagePos1(ACurrentProcDef.fileinfo,parser_e_header_dont_match_forward,
                                   lForwardProcDef.FullProcName(false));
                       TProcSym(ACurrentProcDef.ProcSym).Write_Parameter_Lists(ACurrentProcDef);
                       break;
                     end;

                   { Check if both are declared forward }
                   if lForwardProcDef.ForwardDef and ACurrentProcDef.ForwardDef then
                    begin
                      MessagePos1(ACurrentProcDef.fileinfo,parser_e_function_already_declared_public_forward,
                                  ACurrentProcDef.FullProcName(false));
                    end;

                   { internconst or internproc only need to be defined once }
                   if (lForwardProcDef.ProcCallOption=pocall_internproc) then
                    ACurrentProcDef.ProcCallOption:=lForwardProcDef.ProcCallOption
                   else
                    if (ACurrentProcDef.ProcCallOption=pocall_internproc) then
                     lForwardProcDef.ProcCallOption:=ACurrentProcDef.ProcCallOption;

                   { Check procedure options, Delphi requires that class is
                     repeated in the implementation for class methods }
                   if (m_fpc in CurrentSettings.ModeSwitches) then
                     lProcOptions:=[po_classmethod,po_varargs,po_methodpointer,po_interrupt]
                   else
                     lProcOptions:=[po_classmethod,po_methodpointer];

                   if ((lProcOptions * lForwardProcDef.ProcOptions)<>(lProcOptions * ACurrentProcDef.ProcOptions)) or
                      (lForwardProcDef.ProcTypeOption <> ACurrentProcDef.ProcTypeOption) or
                      { if the implementation version has an "overload" modifier,
                        the interface version must also have it (otherwise we can
                        get annoying crashes due to interface crc changes) }
                      (not(po_overload in lForwardProcDef.ProcOptions) and
                       (po_overload in ACurrentProcDef.ProcOptions)) or
                      { same with noreturn }
                      (not(po_noreturn in lForwardProcDef.ProcOptions) and
                       (po_noreturn in ACurrentProcDef.ProcOptions)) then
                     begin
                       MessagePos1(ACurrentProcDef.fileinfo,parser_e_header_dont_match_forward,
                                   lForwardProcDef.FullProcName(false));
                       TProcSym(lForwardProcDef.ProcSym).Write_Parameter_Lists(lForwardProcDef);
                       { This error is non-fatal, we can recover }
                     end;

                   { Forward declaration is external? }
                   if (po_external in lForwardProcDef.ProcOptions) then
                     MessagePos(ACurrentProcDef.fileinfo,parser_e_proc_already_external);

                   { check for conflicts with "virtual" if this is a virtual
                     method, as "virtual" cannot be repeated in the
                     implementation and hence does not get checked against }
                   if (po_virtualmethod in lForwardProcDef.ProcOptions) then
                     begin
                       lProcOptions:=ACurrentProcDef.ProcOptions*cVirtualMutuallyExclusiveProcOptions;
                       if lProcOptions<>[] then
                         MessagePos2(ACurrentProcDef.fileinfo,parser_e_proc_dir_conflict,tokeninfo^[_VIRTUAL].str,Get_First_Proc_Str(lProcOptions));
                     end;
                    { Check parameters }
                   if (m_repeat_forward in CurrentSettings.ModeSwitches) or
                      (ACurrentProcDef.MinParaCount>0) then
                    begin
                      { If mangled names are equal then they have the same amount of arguments }
                      { We can check the names of the arguments }
                      { both symtables are in the same order from left to right }
                      lCurrentIndex:=0;
                      lForwardIndex:=0;
                      lCurrentParaCount:=ACurrentProcDef.ParaST.SymList.Count;
                      lForwardParaCount:=lForwardProcDef.ParaST.SymList.Count;
                      repeat
                        { skip default parameter constsyms }
                        while (lCurrentIndex<lCurrentParaCount) and
                              (TSym(ACurrentProcDef.ParaST.SymList[lCurrentIndex]).typ<>paravarsym) do
                          inc(lCurrentIndex);
                        while (lForwardIndex<lForwardParaCount) and
                              (TSym(lForwardProcDef.ParaST.SymList[lForwardIndex]).typ<>paravarsym) do
                          inc(lForwardIndex);
                        { stop when one of the two lists is at the end }
                        if (lForwardIndex>=lForwardParaCount) or (lCurrentIndex>=lCurrentParaCount) then
                          break;
                        { compare names of parameters, ignore implicitly
                          renamed parameters }
                        lCurrentParaSym:=TSym(ACurrentProcDef.ParaST.SymList[lCurrentIndex]);
                        lForwardParaSym:=TSym(lForwardProcDef.ParaST.SymList[lForwardIndex]);
                        if not(sp_implicitrename in lCurrentParaSym.SymOptions) and
                           not(sp_implicitrename in lForwardParaSym.SymOptions) then
                          begin
                            if (lCurrentParaSym.name<>lForwardParaSym.name) then
                              begin
                                MessagePos3(ACurrentProcDef.fileinfo,parser_e_header_different_var_names,
                                            TProcSym(ACurrentProcDef.ProcSym).realname,lForwardParaSym.realname,lCurrentParaSym.realname);
                                break;
                              end;
                          end;
                        { next parameter }
                        inc(lCurrentIndex);
                        inc(lForwardIndex);
                      until false;
                    end;
                   { check that the type parameter names for generic methods match;
                     we check this here and not in equal_generic_procdefs as the defs
                     might still be different due to their parameters, so we'd generate
                     errors without any need }
                   if ACurrentProcDef.Is_Generic and lForwardProcDef.Is_Generic then
                     { an error here is recoverable, so we simply continue }
                     CheckGenericParameters(lForwardProcDef,ACurrentProcDef);
                   { Everything is checked, now we can update the forward declaration
                     with the new data from the implementation }
                   lForwardProcDef.ForwardDef:=ACurrentProcDef.ForwardDef;
                   lForwardProcDef.HasForward:=true;
                   lForwardProcDef.ProcOptions:=lForwardProcDef.ProcOptions+ACurrentProcDef.ProcOptions;

                   { marked as local but exported from unit? }
                   if (po_kylixlocal in lForwardProcDef.ProcOptions) and (lForwardProcDef.owner.SymTableType=GlobalSymTable) then
                     MessagePos(lForwardProcDef.fileinfo,type_e_cant_export_local);

                   if lForwardProcDef.ExtNumber=$ffff then
                     lForwardProcDef.ExtNumber:=ACurrentProcDef.ExtNumber;
                   while not ACurrentProcDef.AliasNames.empty do
                     lForwardProcDef.AliasNames.insert(ACurrentProcDef.AliasNames.GetFirst);
                   { update fileinfo so position references the implementation,
                     also update funcretsym if it is already generated }
                   lForwardProcDef.fileinfo:=ACurrentProcDef.fileinfo;
                   if Assigned(lForwardProcDef.FuncRetSym) then
                     lForwardProcDef.FuncRetSym.fileinfo:=ACurrentProcDef.fileinfo;
                   if Assigned(ACurrentProcDef.DeprecatedMsg) then
                     begin
                       StringDispose(lForwardProcDef.DeprecatedMsg);
                       lForwardProcDef.DeprecatedMsg:=StringDup(ACurrentProcDef.DeprecatedMsg^);
                     end;
                   { import names }
                   if Assigned(ACurrentProcDef.ImportDLL) then
                     begin
                       StringDispose(lForwardProcDef.ImportDLL);
                       lForwardProcDef.ImportDLL:=StringDup(ACurrentProcDef.ImportDLL^);
                     end;
                   if Assigned(ACurrentProcDef.ImportName) then
                     begin
                       StringDispose(lForwardProcDef.ImportName);
                       lForwardProcDef.ImportName:=StringDup(ACurrentProcDef.ImportName^);
                     end;
                   lForwardProcDef.ImportNr:=ACurrentProcDef.ImportNr;
                   { for compilerproc defines we need to rename and update the
                     symbolname to lowercase so users can' access it (can't do
                     it immediately, because then the implementation symbol
                     won't be matched) }
                   if po_compilerproc in lForwardProcDef.ProcOptions then
                     begin
                       lForwardProcDef.SetCompilerProcName;
                       CurrentModule.Add_Public_AsmSym(lForwardProcDef.MangledName,AB_GLOBAL,AT_FUNCTION);
                     end;
                   if po_public in lForwardProcDef.ProcOptions then
                     begin
                       lItem:=lForwardProcDef.AliasNames.first;
                       while Assigned(lItem) do
                         begin
                           CurrentModule.Add_Public_AsmSym(TCmdStrListItem(lItem).str,AB_GLOBAL,AT_FUNCTION);
                           lItem:=lItem.Next;
                         end;
                     end;

                   { Release current procdef }
                   ACurrentProcDef.owner.DeleteDef(ACurrentProcDef);
                   ACurrentProcDef:=lForwardProcDef;
                 end
               else
                begin
                  { abstract methods aren't forward defined, but this }
                  { needs another error message                   }
                  if (po_abstractmethod in lForwardProcDef.ProcOptions) then
                    MessagePos(ACurrentProcDef.fileinfo,parser_e_abstract_no_definition)
                  else
                    begin
                      MessagePos(ACurrentProcDef.fileinfo,parser_e_overloaded_have_same_parameters);
                      TProcSym(ACurrentProcDef.ProcSym).Write_Parameter_Lists(ACurrentProcDef);
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
              if ((po_overload in ACurrentProcDef.ProcOptions) or
                  (po_overload in lForwardProcDef.ProcOptions)) then
               begin
                 { check if all procs have overloading, but not if the proc is a method or
                   already declared forward, then the check is already done }
                 if not(lForwardProcDef.HasForward or
                        Assigned(ACurrentProcDef.struct) or
                        (ACurrentProcDef.ForwardDef<>lForwardProcDef.ForwardDef) or
                        ((po_overload in ACurrentProcDef.ProcOptions) and
                         (po_overload in lForwardProcDef.ProcOptions))) then
                  begin
                    MessagePos1(ACurrentProcDef.fileinfo,parser_e_no_overload_for_all_procs,ACurrentProcDef.ProcSym.realname);
                    break;
                  end
               end
              else
               begin
                 if not(lForwardProcDef.ForwardDef) then
                  begin
                    MessagePos1(ACurrentProcDef.fileinfo,parser_e_no_overload_for_all_procs,ACurrentProcDef.ProcSym.realname);
                    break;
                  end;
               end;
            end; { equal arguments }

           { we found a match with the same parameter signature, but mismatching
             return types; complain about that, but only once we've checked for
             a forward to improve error recovery }
           if (lSameParas and not lSameReturn and
               { ensure that specifiers are the same as well }
               (Compare_Paras(lForwardProcDef.paras,ACurrentProcDef.paras,cp_all,[cpo_ignorehidden,cpo_openequalisexact,cpo_ignoreuniv])=te_exact)
               ) or (lGenericSameParas and not lGenericSameReturn) then
             lSameParasFound:=true;
         end;

        if lSameParasFound and
            not (ACurrentProcDef.ProcTypeOption=potype_operator) then
          begin
            MessagePos(ACurrentProcDef.fileinfo,parser_e_overloaded_have_same_parameters);
            TProcSym(ACurrentProcDef.ProcSym).Write_Parameter_Lists(ACurrentProcDef);
          end;

        { if we didn't reuse a forwarddef then we add the procdef to the overloaded
          list }
        if not lForwardFound then
          begin
            { can happen in Delphi mode }
            if (ACurrentProcDef.ProcTypeOption = potype_function) and
               Is_Void(ACurrentProcDef.ReturnDef) then
              MessagePos1(ACurrentProcDef.fileinfo,parser_e_no_funcret_specified,ACurrentProcDef.ProcSym.realname);
            TProcSym(ACurrentProcDef.ProcSym).ProcdefList.Add(ACurrentProcDef);
            if not ACurrentProcDef.ForwardDef and (po_public in ACurrentProcDef.ProcOptions) then
              begin
                lItem:=ACurrentProcDef.AliasNames.first;
                while Assigned(lItem) do
                  begin
                    CurrentModule.Add_Public_AsmSym(TCmdStrListItem(lItem).str,AB_GLOBAL,AT_FUNCTION);
                    lItem:=lItem.Next;
                  end;
              end;
          end;

        Proc_Add_Definition:=lForwardFound;
      end;


    procedure Build_ParentFPStruct(AProcDef: TProcDef);
      var
        lNestedVars: TSym;
        lNestedVarsST: TSymTable;
        lNestedVarsPointerDef,
        lNestedVarsDef: TDef;
        lOldSymTableStack: TSymTableStack;
      begin
        { make sure the defs are not registered in the current symtablestack,
          because they may be for a parent procdef (changeowner does remove a def
          from the symtable in which it was originally created, so that by itself
          is not enough) }
        lOldSymTableStack:=SymTableStack;
        SymTableStack:=lOldSymTableStack.GetCopyUntil(CurrentModule.LocalSymTable);

        lNestedVarsST:=TRecordSymTable.Create('$'+CurrentModule.RealModuleName^+'$$_fpc_nestedvars$'+AProcDef.UniqueIDStr,
          CurrentSettings.Alignment.LocalAlignMax,CurrentSettings.Alignment.LocalAlignMin);
        lNestedVarsDef:=CRecordDef.Create(lNestedVarsST.name^,lNestedVarsST);
        SymTableStack.free;
        SymTableStack:=lOldSymTableStack.GetCopyUntil(AProcDef.LocalST);
        lNestedVarsPointerDef:=CPointerDef.getreusable(lNestedVarsDef);
        if not(po_assembler in AProcDef.ProcOptions) then
          begin
            lNestedVars:=CLocalVarSym.Create('$nestedvars',vs_var,lNestedVarsDef,[]);
            include(lNestedVars.SymOptions,sp_internal);
            AProcDef.LocalST.InsertSym(lNestedVars);
            AProcDef.ParentFPStruct:=lNestedVars;
            AProcDef.ParentFPInitBlock:=CBlockNode.Create(nil);
          end;
        SymTableStack.free;
        AProcDef.ParentFPStructPtrType:=lNestedVarsPointerDef;

        SymTableStack:=lOldSymTableStack;
      end;

end.
