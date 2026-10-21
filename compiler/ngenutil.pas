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
    CClasses,GlobType,
    FModule,
    aasmbase,AAsmData,
    node,nbas,symtype,SymSym,symconst,symdef;


  type
    TInitFinalEntry = record
      InitFunc : TSymStr;
      FiniFunc : TSymStr;
      InitPD : TProcDef;
      FiniPD : TProcDef;
      Module : TModule;
    end;
    PInitFinalEntry = ^TInitFinalEntry;

    TNodeUtils = class
      class function Call_Fail_Node:TNode; virtual;
      class function Initialize_Data_Node(ANode:TNode; AForce: Boolean):TNode; virtual;
      class function Finalize_Data_Node(ANode:TNode):TNode; virtual;
     strict protected
      type
        TStructIniFiniPOType = potype_class_constructor..potype_class_destructor;
      class procedure Sym_Maybe_Initialize(AObject: TObject; AArg: Pointer);
      { generates the code for finalisation of local variables }
      class procedure Local_VarSyms_Finalize(AObject:TObject;AArg:Pointer);
      { generates the code for finalization of static symtable and
        all local (static) typed consts }
      class procedure Static_Syms_Finalize(AObject: TObject; AArg: Pointer);
      class procedure Sym_Maybe_Finalize(var AStatement: TStatementNode; ASym: TSym);
      class procedure Append_Struct_InitFinis(AModule: TModule; AInitFini: TStructIniFiniPOType; var AStatement: TStatementNode); virtual;
     public
      class procedure ProcDef_Block_Add_Implicit_Initialize_Nodes(AProcDef: TProcDef; var AStatement: TStatementNode);
      class procedure ProcDef_Block_Add_Implicit_Finalize_Nodes(AProcDef: TProcDef; var AStatement: TStatementNode);

      class function Force_Init: Boolean; virtual;
      { idem for finalization }
      class function Force_Final: Boolean; virtual;

      { if the funcretsym was moved to the parentfpstruct, use this method to
        move its value back back into the funcretsym before the function exit, as
        the code generator is hardcoded to use to use the funcretsym when loading
        the value to be returned; replacing it with an absolutevarsym that
        redirects to the field in the parentfpstruct doesn't work, as the code
        generator cannot deal with such symbols }
       class procedure Load_ParentFPStruct_Nested_FuncRet(AResultSym: TSym; AResultDef: TDef; var AStatement: TStatementNode);
      { called after parsing a routine with the code of the entire routine
        as argument; can be used to modify the node tree. By default handles
        insertion of code for systems that perform the typed constant
        initialisation via the node tree }
      class function Wrap_Proc_Body(AProcDef: TProcDef; ANode: TNode): TNode; virtual;

      { trashes a paravarsym or localvarsym if possible (not a managed type,
        "out" in case of parameter, ...) }
      class procedure Maybe_Trash_Variable(var AStatement: TStatementNode; AVarSym: TAbstractNormalVarSym; ATrashNode: TNode); virtual;

      class function  Check_Insert_Trashing(AProcDef: TProcDef): Boolean; virtual;
     strict protected
      { called from wrap_proc_body to insert the trashing for the wrapped
        routine's local variables and parameters }
      class function  Maybe_Insert_Trashing(AProcDef: TProcDef; ANode: TNode): TNode;
      { callback called for every local variable and parameter by
        maybe_insert_trashing(), calls through to maybe_trash_variable() }
      class procedure Maybe_Trash_Variable_Callback(AObject: TObject; AStatementPtr: Pointer);
      { returns whether a particular sym can be trashed. If not,
        maybe_trash_variable won't do anything }
      class function  Trashable_Sym(ASym: TSym): Boolean; virtual;
      { trashing for 1/2/3/4/8-byte sized variables }
      class procedure Trash_Small(var AStatement: TStatementNode; ATrashNode: TNode; ATrashValueNode: TNode); virtual;
      { trashing for differently sized variables that those handled by
        trash_small() }
      class procedure Trash_Large(var AStatement: TStatementNode; ATrashNode, ASizeNode: TNode; ATrashIntValue: Int64); virtual;
      { insert a single bss sym, called by insert bssdata (factored out
        non-common part for llvm) }
      class procedure InsertBSSSym(AList: TAsmList; ASym: TStaticVarSym; ASize: ASizeInt; AVarAlign: ShortInt; AType: TAsmsymtype); virtual;

      { initialization of iso styled program parameters }
      class procedure Initialize_FileRecs(AObject : TObject; AStatementPtr : Pointer);
      { finalization of iso styled program parameters }
      class procedure Finalize_FileRecs(AObject : TObject; AStatementPtr : Pointer);
     public
      class procedure InsertBSSData(ASym : TStaticVarSym); virtual;

      class function Create_Main_ProcDef(const AName: string; AProcType:TProcTypeOption; AProcSym: TProcSym):TDef; virtual;
      class procedure InsertInitFinalTable(AMainModule : TModule);
     protected
      class procedure InsertRuntimeInits(const APrefix:string;AList:TLinkedList;AUnitFlag:TModuleFlag); virtual;
      class procedure InsertRuntimeInitsTablesTable(const APrefix,ATableName:string;AUnitFlag:TModuleFlag); virtual;

      class procedure Insert_Init_Final_Table(AMainModule: TModule; AEntries:TFPList); virtual;

      class function Get_Init_Final_List(AMainModule : TModule): TFPList;
      class procedure Release_Init_Final_List(AList:TFPList);
     public
      class procedure InsertThreadvarTablesTable; virtual;
      class procedure InsertThreadvars; virtual;
      class procedure InsertWideInitsTablesTable; virtual;
      class procedure InsertWideInits; virtual;
      class procedure InsertResStrInits; virtual;
      class procedure InsertResStrTablesTable; virtual;
      class procedure InsertResourceTablesTable; virtual;
      class procedure InsertResourceInfo(AResourcesUsed : Boolean); virtual;

      class procedure InsertMemorySizes; virtual;

      { Call this to check if init code is required }
      class function Has_Init_List: Boolean; static;

      { called right before an object is assembled, can be used to insert
        global information into the assembler list (used by LLVM to insert type
        info) }
      class procedure InsertObjectInfo; virtual;

      { register that asm symbol sym with type def has to be considered as "used" even if not
        references to it can be found. If compileronly, this is only for the compiler, otherwise
        also for the linker }
      class procedure RegisterUsedAsmSym(ASym: TAsmSymbol; ADef: TDef; ACompilerOnly: Boolean); virtual;

      class procedure RegisterModuleInitFunction(AProcDef: TProcDef); virtual;
      class procedure RegisterModuleFiniFunction(AProcDef: TProcDef); virtual;

     strict protected
      class procedure Add_Main_ProcDef_Paras(AProcDef: TDef); virtual;
    end;
    TNodeUtilsClass = class of TNodeUtils;

  var
    CNodeUtils: TNodeUtilsClass = TNodeUtils;


implementation

    uses
      Verbose,version,Globals,CUtils,ConstExp,compinnr,
      Systems,ProcInfo,pparautl,
      aasmtai,aasmcnst,
      SymBase,SymTable,defutil,
      nadd,ncal,ncnv,ncon,nflw,ninl,nld,nmem,nutils,
      PPU,
      Pass_1,
      export;

  class function TNodeUtils.Call_Fail_Node:TNode;
    var
      lPara : TCallParaNode;
      lNewStatement : TStatementNode;
      lSymbol : TSym;
    begin
      Result:=InternalStatements(lNewStatement);

      { call fail helper and exit normal }
      if Is_Class(CurrentStructDef) then
        begin
          lSymbol:=Search_Struct_Member(CurrentStructDef,'FREEINSTANCE');
          if Assigned(lSymbol) and
             (lSymbol.typ=ProcSym) then
            begin
              { if self<>0 and vmt<>0 then freeinstance }
              AddStatement(lNewStatement,CIfNode.Create(
                  CAddNode.Create(andn,
                      CAddNode.Create(unequaln,
                          Load_Self_Pointer_Node,
                          CNilNode.Create),
                      CAddNode.Create(unequaln,
                          Load_VMT_Pointer_Node,
                          CNilNode.Create)),
                  CCallNode.Create(nil,TProcSym(lSymbol),lSymbol.Owner,Load_Self_Node,[],nil),
                  nil));
            end
          else
            InternalError(2003051002);
        end
      else
        if Is_Object(CurrentStructDef) then
          begin
            { parameter 3 : vmt_offset }
            { parameter 2 : pointer to vmt }
            { parameter 1 : self pointer }
            lPara:=CCallParaNode.Create(
                      COrdConstNode.Create(TObjectDef(CurrentStructDef).VMT_Offset,S32IntType,false),
                  CCallParaNode.Create(
                      CTypeConvNode.Create_Internal(
                          Load_VMT_Pointer_Node,
                          VoidPointerType),
                  CCallParaNode.Create(
                      CTypeConvNode.Create_Internal(
                          Load_Self_Pointer_Node,
                          VoidPointerType),
                  nil)));
            AddStatement(lNewStatement,
                CCallNode.CreateIntern('fpc_help_fail',lPara));
          end
      else
        InternalError(200305132);
      { self:=nil }
      AddStatement(lNewStatement,CAssignmentNode.Create(
          Load_Self_Pointer_Node,
          CNilNode.Create));
      { exit }
      AddStatement(lNewStatement,CExitNode.Create(nil));
    end;


  class function TNodeUtils.Initialize_Data_Node(ANode:TNode; AForce: Boolean):TNode;
    begin
      { prevent initialisation of hidden syms that were moved to
        parentfpstructs: the original symbol isn't used anymore, the version
        in parentfpstruct will be initialised when that struct gets initialised,
        and references to it will actually be translated into references to the
        field in the parentfpstruct (so we'll initialise it twice) }

        begin
          if not Assigned(ANode.ResultDef) then
            TypeCheckPass(ANode);
          if Is_AnsiString(ANode.ResultDef) or
             Is_Wide_Or_Unicode_String(ANode.ResultDef) or
             Is_InterfaceCOM_Or_DispInterface(ANode.ResultDef) or
             Is_Dynamic_Array(ANode.ResultDef) then
            begin
              Result:=CAssignmentNode.Create(
                 CTypeConvNode.Create_Internal(ANode,VoidPointerType),
                 CNilNode.Create
                 );
            end
          else if (ANode.ResultDef.typ=variantdef) then
            begin
              Result:=CCallNode.CreateIntern('fpc_variant_init',
                CCallParaNode.Create(
                  CTypeConvNode.Create_Internal(ANode,Search_System_Type('TVARDATA').TypeDef),
                nil));
            end
          else
            begin
              Result:=CCallNode.CreateIntern('fpc_initialize',
                    CCallParaNode.Create(
                        CAddrNode.Create_Internal(
                            CRTTINode.Create(
                                TStoredDef(ANode.ResultDef),initrtti,rdt_normal)),
                    CCallParaNode.Create(
                        CAddrNode.Create_Internal(ANode),
                    nil)));
            end;
        end;
    end;


  class function TNodeUtils.Finalize_Data_Node(ANode:TNode):TNode;
    var
      lHelperName : string;
    begin
      { see comment in initialize_data_node above }

        begin
          if not Assigned(ANode.ResultDef) then
            TypeCheckPass(ANode);
          { 'decr_ref' suffix is somewhat misleading, all these helpers
            set the passed pointer to nil now }
          if Is_AnsiString(ANode.ResultDef) then
            lHelperName:='fpc_ansistr_decr_ref'
          else if Is_WideString(ANode.ResultDef) then
            lHelperName:='fpc_widestr_decr_ref'
          else if Is_UnicodeString(ANode.ResultDef) then
            lHelperName:='fpc_unicodestr_decr_ref'
          else if Is_InterfaceCOM_Or_DispInterface(ANode.ResultDef) then
            lHelperName:='fpc_intf_decr_ref'
          else
            lHelperName:='';
          if lHelperName<>'' then
            Result:=CCallNode.CreateIntern(lHelperName,
               CCallParaNode.Create(
                 CTypeConvNode.Create_Internal(ANode,VoidPointerType),
                 nil))
          else if ANode.ResultDef.typ=variantdef then
            begin
              Result:=CCallNode.CreateIntern('fpc_variant_clear',
                CCallParaNode.Create(
                  CTypeConvNode.Create_Internal(ANode,Search_System_Type('TVARDATA').TypeDef),
                nil));
            end
          else
            Result:=CCallNode.CreateIntern('fpc_finalize',
                  CCallParaNode.Create(
                      CAddrNode.Create_Internal(
                          CRTTINode.Create(
                              TStoredDef(ANode.ResultDef),initrtti,rdt_normal)),
                  CCallParaNode.Create(
                      CAddrNode.Create_Internal(ANode),
                  nil)));
        end;
    end;


  class procedure TNodeUtils.Sym_Maybe_Initialize(AObject: TObject; AArg: Pointer);
    var
      lNode : TNode;
    begin
      if ((TSym(AObject).typ = localvarsym) or
          { check staticvarsym for record management operators and for objects
            which might contain record with management operators }
          ((TSym(AObject).typ = staticvarsym) and
           (
             Is_Record(TAbstractVarSym(AObject).vardef) or
             Is_Object(TAbstractVarSym(AObject).vardef)
           )
          )
         ) and
         { local (procedure or unit) variables only need initialization if
           they are used }
         ((TAbstractVarSym(AObject).refs>0) or
          { managed return symbols must be inited }
          ((TSym(AObject).typ=localvarsym) and (vo_is_funcret in TLocalVarSym(AObject).VarOptions)) or
          { public managed records with Initialize operator need to be initialized
            even if they aren't referenced in *this* unit }
          (
            (TSym(AObject).Owner.SymTableType=GlobalSymTable) and
            Is_Record(TAbstractVarSym(AObject).vardef) and
            (mop_initialize in TRecordSymTable(TRecordDef(TAbstractVarSym(AObject).vardef).SymTable).ManagementOperators)
          )
         ) and
         not(vo_is_typed_const in TAbstractVarSym(AObject).VarOptions) and
         not(vo_is_external in TAbstractVarSym(AObject).VarOptions) and
         (
           not (vo_is_default_var in TAbstractVarSym(AObject).VarOptions) or
           (TAbstractVarSym(AObject).VarSpez<>vs_const)
         ) and
         (Is_Managed_Type(TAbstractVarSym(AObject).vardef) or
          ((m_iso in CurrentSettings.ModeSwitches) and (TAbstractVarSym(AObject).vardef.typ=filedef))
         ) then
        begin
          lNode:=CLoadNode.Create(TSym(AObject),TSym(AObject).Owner);
          { ensure that a function reference is not converted to a call }
          include(lNode.Flags,nf_load_procvar);
          AddStatement(TStatementNode(AArg^),Initialize_Data_Node(lNode,false));
        end;
    end;


  class procedure TNodeUtils.Local_VarSyms_Finalize(AObject: TObject; AArg: Pointer);
    begin
      if (TSym(AObject).typ=localvarsym) and
         (TLocalVarSym(AObject).refs>0) and
         not(vo_is_typed_const in TLocalVarSym(AObject).VarOptions) and
         not(vo_is_external in TLocalVarSym(AObject).VarOptions) and
         not(vo_is_funcret in TLocalVarSym(AObject).VarOptions) and
         (
           not(vo_is_default_var in TAbstractVarSym(AObject).VarOptions) or
           (TAbstractVarSym(AObject).VarSpez<>vs_const)
         ) and
         Is_Managed_Type(TLocalVarSym(AObject).vardef) then
        Sym_Maybe_Finalize(TStatementNode(AArg^),TSym(AObject));
    end;


  class procedure TNodeUtils.Static_Syms_Finalize(AObject: TObject; AArg: Pointer);
    var
      lIndex : LongInt;
      lProcDef : TProcDef;
    begin
      case TSym(AObject).typ of
        staticvarsym :
          begin
            { local (procedure or unit) variables only need finalization
              if they are used
            }
            if ((TStaticVarSym(AObject).refs>0) or
                { global (unit) variables always need finalization, since
                  they may also be used in another unit
                }
                (TStaticVarSym(AObject).Owner.SymTableType=GlobalSymTable)) and
                (
                  (TStaticVarSym(AObject).VarSpez<>vs_const) or
                  (vo_force_finalize in TStaticVarSym(AObject).VarOptions)
                ) and
               not(vo_is_funcret in TStaticVarSym(AObject).VarOptions) and
               not(vo_is_external in TStaticVarSym(AObject).VarOptions) and
               Is_Managed_Type(TStaticVarSym(AObject).vardef) and
               not (
                   Assigned(TStaticVarSym(AObject).FieldVarSym) and
                   Assigned(TStaticVarSym(AObject).FieldVarSym.Owner.DefOwner) and
                   (df_generic in TDef(TStaticVarSym(AObject).FieldVarSym.Owner.DefOwner).DefOptions)
                 )
               then
              Sym_Maybe_Finalize(TStatementNode(AArg^),TSym(AObject));
          end;
        ProcSym :
          begin
            for lIndex:=0 to TProcSym(AObject).ProcdefList.Count-1 do
              begin
                lProcDef:=TProcDef(TProcSym(AObject).ProcdefList[lIndex]);
                if Assigned(lProcDef.LocalST) and
                   (lProcDef.ProcSym=TProcSym(AObject)) and
                   (lProcDef.LocalST.SymTableType<>staticsymtable) then
                  lProcDef.LocalST.SymList.ForEachCall(@Static_Syms_Finalize,AArg);
              end;
          end;
        else
          ;
      end;
    end;


  class procedure TNodeUtils.Sym_Maybe_Finalize(var AStatement: TStatementNode; ASym: TSym);
    var
      lNode: TNode;
    begin
      include(CurrentProcInfo.Flags,pi_needs_implicit_finally);
      lNode:=CLoadNode.Create(ASym,ASym.Owner);
      if (ASym.typ=staticvarsym) and (vo_force_finalize in TStaticVarSym(ASym).VarOptions) then
        include(TLoadNode(lNode).LoadNodeFlags,loadnf_isinternal_ignoreconst);
      { ensure that a function reference interface is not converted to a call }
      include(lNode.Flags,nf_load_procvar);
      AddStatement(AStatement,Finalize_Data_Node(lNode));
    end;


  procedure AddToStructInits(AObject:TObject;AArg:Pointer);
    var
      lStructList: TFPList absolute AArg;
    begin
      if (TDef(AObject).typ in [objectdef,recorddef]) and
         not (df_generic in TDef(AObject).DefOptions) then
        begin
          { first add the class... }
          if ([oo_has_class_constructor,oo_has_class_destructor] * TAbstractRecordDef(AObject).ObjectOptions <> []) then
            lStructList.Add(AObject);
          { ... and then also add all subclasses }
          TAbstractRecordDef(AObject).SymTable.DefList.foreachcall(@AddToStructInits,AArg);
        end;
    end;


  class procedure TNodeUtils.Append_Struct_InitFinis(AModule: TModule; AInitFini: TStructIniFiniPOType; var AStatement: TStatementNode);
    var
      lStructList: TFPList;
      lIndex: integer;
      lProcDef: TProcDef;
    begin
      lStructList:=TFPList.Create;
      if Assigned(AModule.GlobalSymTable) then
        AModule.GlobalSymTable.DefList.ForEachCall(@AddToStructInits,lStructList);
      AModule.LocalSymTable.DefList.ForEachCall(@AddToStructInits,lStructList);
      { write structures }
      for lIndex:=0 to lStructList.Count-1 do
        begin
          lProcDef:=TAbstractRecordDef(lStructList[lIndex]).Find_ProcDef_ByType(AInitFini);
          if Assigned(lProcDef) then
            begin
              { class constructors are private -> ignore visibility checks }
              AddStatement(AStatement,
                CCallNode.Create(nil,TProcSym(lProcDef.ProcSym),lProcDef.Owner,nil,[cnf_ignore_visibility],nil))
            end;
        end;
      lStructList.free;
      lStructList := nil;
    end;


  class procedure TNodeUtils.ProcDef_Block_Add_Implicit_Initialize_Nodes(AProcDef: TProcDef; var AStatement: TStatementNode);
    begin
      { initialize local data like ansistrings }
      case AProcDef.ProcTypeOption of
         potype_unitinit:
           begin
             { this is also used for initialization of variables in a
               program which does not have a globalsymtable }
             if Assigned(CurrentModule.GlobalSymTable) then
               TSymTable(CurrentModule.GlobalSymTable).SymList.ForEachCall(@Sym_Maybe_Initialize,@AStatement);
             TSymTable(CurrentModule.LocalSymTable).SymList.ForEachCall(@Sym_Maybe_Initialize,@AStatement);
             { insert class constructors  }
             if mf_classinits in CurrentModule.ModuleFlags then
               Append_Struct_InitFinis(CurrentModule, potype_class_constructor, AStatement);
           end;
         { units have separate code for initialization and finalization }
         potype_unitfinalize: ;
         { program init/final is generated in separate procedure }
         potype_proginit: ;
         else
           CurrentProcInfo.procdef.LocalST.SymList.ForEachCall(@Sym_Maybe_Initialize,@AStatement);
      end;
    end;


  class procedure TNodeUtils.ProcDef_Block_Add_Implicit_Finalize_Nodes(AProcDef: TProcDef; var AStatement: TStatementNode);
    begin
      { no finalization in exceptfilters, they /are/ the finalization code }
      if CurrentProcInfo.procdef.ProcTypeOption=potype_exceptfilter then
          exit;

      { finalize local data like ansistrings}
      case CurrentProcInfo.procdef.ProcTypeOption of
         potype_unitfinalize:
           begin
             { insert class destructors  }
             if mf_classinits in CurrentModule.ModuleFlags then
               Append_Struct_InitFinis(CurrentModule, potype_class_destructor, AStatement);
             { this is also used for initialization of variables in a
               program which does not have a globalsymtable }
             if Assigned(CurrentModule.GlobalSymTable) then
               TSymTable(CurrentModule.GlobalSymTable).SymList.ForEachCall(@Static_Syms_Finalize,@AStatement);
             TSymTable(CurrentModule.LocalSymTable).SymList.ForEachCall(@Static_Syms_Finalize,@AStatement);
           end;
         { units/progs have separate code for initialization and finalization }
         potype_unitinit: ;
         { program init/final is generated in separate procedure }
         potype_proginit: ;
         else
           CurrentProcInfo.procdef.LocalST.SymList.ForEachCall(@Local_VarSyms_Finalize,@AStatement);
      end;
    end;


  class function TNodeUtils.Force_Init: Boolean;
    begin
      Result:=false;
    end;


  class function TNodeUtils.Force_Final: Boolean;
    begin
      Result:=false;
    end;


  class procedure TNodeUtils.Initialize_FileRecs(AObject:TObject;AStatementPtr:Pointer);
    var
      lStatement: ^TStatementNode absolute AStatementPtr;
    begin
      if (TSym(AObject).typ=staticvarsym) and
        (TStaticVarSym(AObject).vardef.typ=filedef) and
        (TStaticVarSym(AObject).IsoIndex<>0) then
        case TFileDef(TStaticVarSym(AObject).vardef).FileTyp of
          ft_text:
            begin
              if cs_transparent_file_names in CurrentSettings.GlobalSwitches then
                AddStatement(lStatement^,CCallNode.CreateIntern('fpc_textinit_filename_iso',
                  CCallParaNode.Create(
                    CStringConstNode.CreateStr(TStaticVarSym(AObject).Name),
                  CCallParaNode.Create(
                    COrdConstNode.Create(TStaticVarSym(AObject).IsoIndex,UIntType,false),
                  CCallParaNode.Create(
                    CLoadNode.Create(TStaticVarSym(AObject),TStaticVarSym(AObject).Owner),
                  nil)))))
              else
                AddStatement(lStatement^,CCallNode.CreateIntern('fpc_textinit_iso',
                  CCallParaNode.Create(
                    COrdConstNode.Create(TStaticVarSym(AObject).IsoIndex,UIntType,false),
                  CCallParaNode.Create(
                    CLoadNode.Create(TStaticVarSym(AObject),TStaticVarSym(AObject).Owner),
                  nil))));
            end;
          ft_typed:
            begin
              if cs_transparent_file_names in CurrentSettings.GlobalSwitches then
                AddStatement(lStatement^,CCallNode.CreateIntern('fpc_typedfile_init_filename_iso',
                  CCallParaNode.Create(
                    CStringConstNode.CreateStr(TStaticVarSym(AObject).Name),
                  CCallParaNode.Create(
                    COrdConstNode.Create(TStaticVarSym(AObject).IsoIndex,UIntType,false),
                  CCallParaNode.Create(
                    CLoadNode.Create(TStaticVarSym(AObject),TStaticVarSym(AObject).Owner),
                  nil)))))
              else
                AddStatement(lStatement^,CCallNode.CreateIntern('fpc_typedfile_init_iso',
                  CCallParaNode.Create(
                    COrdConstNode.Create(TStaticVarSym(AObject).IsoIndex,UIntType,false),
                  CCallParaNode.Create(
                    CLoadNode.Create(TStaticVarSym(AObject),TStaticVarSym(AObject).Owner),
                  nil))));
            end;
          else
            ;
        end;
    end;


  class procedure TNodeUtils.Finalize_FileRecs(AObject:TObject;AStatementPtr:Pointer);
    var
      lStatement: ^TStatementNode absolute AStatementPtr;
    begin
      if (TSym(AObject).typ=staticvarsym) and
        (TStaticVarSym(AObject).vardef.typ=filedef) and
        (TStaticVarSym(AObject).IsoIndex<>0) then
        case TFileDef(TStaticVarSym(AObject).vardef).FileTyp of
          ft_text:
            begin
              AddStatement(lStatement^,CCallNode.CreateIntern('fpc_textclose_iso',
                CCallParaNode.Create(
                  CLoadNode.Create(TStaticVarSym(AObject),TStaticVarSym(AObject).Owner),
                nil)));
            end;
          ft_typed:
            begin
              AddStatement(lStatement^,CCallNode.CreateIntern('fpc_typedfile_close_iso',
                CCallParaNode.Create(
                  CLoadNode.Create(TStaticVarSym(AObject),TStaticVarSym(AObject).Owner),
                nil)));
            end;
          else
            ;
        end;
    end;


  class procedure TNodeUtils.Load_ParentFPStruct_Nested_FuncRet(AResultSym: TSym; AResultDef: TDef; var AStatement: TStatementNode);
    var
      lSource, lTarget: TLoadNode;
    begin
      lTarget:=CLoadNode.Create(AResultSym, AResultSym.Owner);
      { ensure the target of this assignment doesn't translate the
        funcretsym also to its alias in the parentfpstruct }
      include(lTarget.Flags, nf_internal);
      lSource:=CLoadNode.Create(AResultSym, AResultSym.Owner);
      if TAbstractNormalVarSym(AResultSym).vardef<>AResultDef then
        begin
          { the resultdef of TP-style object constructors is the object itself,
            but in practice they return a pointer to the object (the self
            pointer) }
          if (AResultDef.typ<>pointerdef) or
             (TPointerDef(AResultDef).PointedDef<>TAbstractNormalVarSym(AResultSym).vardef) then
            InternalError(2026072310);
          include(lSource.LoadNodeFlags, loadnf_load_addr);
          include(lTarget.LoadNodeFlags, loadnf_load_addr);
        end;

      AddStatement(AStatement,
        CAssignmentNode.Create(lTarget,lSource)
      );
    end;


  class function TNodeUtils.Wrap_Proc_Body(AProcDef: TProcDef; ANode: TNode): TNode;
    var
      lStatement: TStatementNode;
      lBlock: TNode;
      lResultSym: TSym;
      lResultDef: TDef;
    begin
      Result:=Maybe_Insert_Trashing(AProcDef,ANode);

      { initialise safecall result variable }
      if AProcDef.Generate_SafeCall_Wrapper then
        begin
          lResultSym:=TSym(AProcDef.LocalST.Find('safecallresult'));
          lBlock:=InternalStatements(lStatement);
          AddStatement(lStatement,
            CAssignmentNode.Create(
              CLoadNode.Create(lResultSym,lResultSym.Owner),
              GenIntConstNode(0)
            )
          );
          AddStatement(lStatement,Result);
          Result:=lBlock;
        end;

      if (m_isolike_program_para in CurrentSettings.ModeSwitches) and
        (AProcDef.ProcTypeOption=potype_proginit) then
        begin
          lBlock:=InternalStatements(lStatement);
          AProcDef.LocalST.SymList.ForEachCall(@Initialize_FileRecs,@lStatement);
          AddStatement(lStatement,Result);
          AProcDef.LocalST.SymList.ForEachCall(@Finalize_FileRecs,@lStatement);
          Result:=lBlock;
        end;


    end;


  class function TNodeUtils.Maybe_Insert_Trashing(AProcDef: TProcDef; ANode: TNode): TNode;
    var
      lStatement: TStatementNode;
    begin
      Result:=ANode;
      if Check_Insert_Trashing(AProcDef) then
        begin
          Result:=InternalStatements(lStatement);
          AProcDef.ParaST.SymList.ForEachCall(@Maybe_Trash_Variable_Callback,@lStatement);
          AProcDef.LocalST.SymList.ForEachCall(@Maybe_Trash_Variable_Callback,@lStatement);
          AddStatement(lStatement,ANode);
        end;
    end;

  class function TNodeUtils.Check_Insert_Trashing(AProcDef: TProcDef): Boolean;
    begin
      Result:=
        (LocalVarTrashing<>-1) and
        not(po_assembler in AProcDef.ProcOptions);
    end;


  class function TNodeUtils.Trashable_Sym(ASym: TSym): Boolean;
    begin
      Result:=
        ((ASym.typ=localvarsym) or
         ((ASym.typ=paravarsym) and
          ((vo_is_funcret in TAbstractNormalVarSym(ASym).VarOptions) or
           (TAbstractNormalVarSym(ASym).VarSpez=vs_out)))) and
         not (vo_is_default_var in TAbstractNormalVarSym(ASym).VarOptions) and
         (not Is_Managed_Type(TAbstractNormalVarSym(ASym).vardef) or
          (Is_String(TAbstractNormalVarSym(ASym).vardef) and
           (vo_is_funcret in TAbstractNormalVarSym(ASym).VarOptions)
          )
         ) and
         (TAbstractNormalVarSym(ASym).VarOptions*[vo_is_parentfp,vo_is_internal]=[]) and
         not Assigned(TAbstractNormalVarSym(ASym).DefaultConstSym);
    end;


  class procedure TNodeUtils.Maybe_Trash_Variable(var AStatement: TStatementNode; AVarSym: TAbstractNormalVarSym; ATrashNode: TNode);
    var
      lSize: ASizeInt;
      lTrashIntValue: Int64;
      lStringResult: TStringConstNode;
    begin
      if Trashable_Sym(AVarSym) then
        begin
          lTrashIntValue:=TrashIntValues[LocalVarTrashing];
          if (AVarSym.vardef.typ=procvardef) and
             ([m_tp_procvar,m_mac_procvar]*CurrentSettings.ModeSwitches<>[]) then
            begin
              if TProcVarDef(AVarSym.vardef).Is_AddressOnly then
                { in tp/delphi mode, you need @procvar to get at the contents of
                  a procvar ... }
                ATrashNode:=CAddrNode.Create(ATrashNode)
              else
                { ... but if it's a procedure of object, that will only return
                  the procedure address -> cast to tmethod instead }
                ATrashNode:=CTypeConvNode.Create_Explicit(ATrashNode,MethodPointerType);
            end;
          if Is_Managed_Type(AVarSym.vardef) then
            begin
              if Is_String(AVarSym.vardef) then
                begin
                  lStringResult:=
                    CStringConstNode.CreateStr(
                      'uninitialized function result in '+
                      TProcDef(AVarSym.Owner.DefOwner).CustomProcName([pno_proctypeoption, pno_paranames,pno_ownername, pno_noclassmarker])
                    );
                  { prevent attempts to convert the string to the specified
                    code page at compile time, as it may not be available (and
                    it does not matter) }
                  if Is_AnsiString(AVarSym.vardef) then
                    lStringResult.ChangeStringType(Search_System_Type('RAWBYTESTRING').TypeDef);
                  Trash_Small(AStatement,ATrashNode,lStringResult);
                end
              else
                InternalError(2016030601);
            end
          else if ((AVarSym.typ=localvarsym) and
              (not(vo_is_funcret in AVarSym.VarOptions) or
               not Is_ShortString(AVarSym.vardef))) or
             ((AVarSym.typ=paravarsym) and
              not Is_ShortString(AVarSym.vardef)) then
            begin
              lSize:=AVarSym.GetSize;
              case lSize of
                0:
                  begin
                    { open array -> at least size 1. Can also be zero-sized
                      record, so check it's actually an array }
                    if AVarSym.vardef.typ=arraydef then
                      Trash_Large(AStatement,ATrashNode,CAddNode.Create(addn,CInlineNode.Create(in_high_x,false,ATrashNode.GetCopy),GenIntConstNode(1)),lTrashIntValue)
                    else
                      ATrashNode.free;
                      ATrashNode := nil;
                  end;
                1: Trash_Small(AStatement,
                  CTypeConvNode.Create_Internal(ATrashNode,S8IntType),
                    GenIntConstNode(ShortInt(lTrashIntValue)));
                2: Trash_Small(AStatement,
                  CTypeConvNode.Create_Internal(ATrashNode,S16IntType),
                    GenIntConstNode(smallint(lTrashIntValue)));
                4: Trash_Small(AStatement,
                  CTypeConvNode.Create_Internal(ATrashNode,S32IntType),
                    GenIntConstNode(LongInt(lTrashIntValue)));
                8: Trash_Small(AStatement,
                  CTypeConvNode.Create_Internal(ATrashNode,S64IntType),
                    GenIntConstNode(Int64(lTrashIntValue)));
                else
                  Trash_Large(AStatement,ATrashNode,GenIntConstNode(lSize),lTrashIntValue);
              end;
            end
          else
            begin
              { may be an open string, even if is_open_string() returns false
                (for some helpers in the system unit)             }
              { an open string has at least size 2                      }
              Trash_Small(AStatement,
                CVecNode.Create(ATrashNode.GetCopy,GenIntConstNode(0)),
                COrdConstNode.Create(TConstExprInt(Byte(lTrashIntValue)),CAnsiCharType,false));
              Trash_Small(AStatement,
                CVecNode.Create(ATrashNode,GenIntConstNode(1)),
                COrdConstNode.Create(TConstExprInt(Byte(lTrashIntValue)),CAnsiCharType,false));
            end;
        end
      else
        ATrashNode.free;
        ATrashNode := nil;
    end;


  class procedure TNodeUtils.Maybe_Trash_Variable_Callback(AObject:TObject;AStatementPtr:Pointer);
    var
      lStatement: ^TStatementNode absolute AStatementPtr;
    begin
      if not(TSym(AObject).typ in [localvarsym,paravarsym]) then
        exit;
      if sp_internal in TSym(AObject).SymOptions then
        exit;
      Maybe_Trash_Variable(lStatement^,TAbstractNormalVarSym(AObject),CLoadNode.Create(TSym(AObject),TSym(AObject).Owner));
    end;


  class procedure TNodeUtils.Trash_Small(var AStatement: TStatementNode; ATrashNode: TNode; ATrashValueNode: TNode);
    begin
      AddStatement(AStatement,CAssignmentNode.Create(ATrashNode,ATrashValueNode));
    end;


  class procedure TNodeUtils.Trash_Large(var AStatement: TStatementNode; ATrashNode, ASizeNode: TNode; ATrashIntValue: Int64);
    begin
      AddStatement(AStatement,CCallNode.CreateIntern('fpc_fillmem',
        CCallParaNode.Create(COrdConstNode.Create(TConstExprInt(Byte(ATrashIntValue)),U8IntType,false),
        CCallParaNode.Create(ASizeNode,
        CCallParaNode.Create(ATrashNode,nil)))
        ));
    end;


  class procedure TNodeUtils.InsertBSSSym(AList: TAsmList; ASym: TStaticVarSym; ASize: ASizeInt; AVarAlign: ShortInt; AType:TAsmsymtype);
    begin
      if ASym.GlobalAsmSym then
        begin
          AList.concat(TAIDataBlock.create_global(ASym.MangledName,ASize,ASym.vardef,AType));
        end
      else
        AList.concat(TAIDataBlock.create_hidden(ASym.MangledName,ASize,ASym.vardef,AType));
    end;


  class procedure TNodeUtils.InsertBSSData(ASym: TStaticVarSym);
    var
      lSize : ASizeInt;
      lVarAlign,lWantedAlign,lExplicitAlign : ShortInt;
      lSavedFilePos : TFilePosInfo;
      lList : TAsmList;
      lSectionType : TAsmSectiontype;
      lAsmType: TAsmsymtype;
      lBuilder: TTAITypedConstBuilder;
      lDescriptor: TDef;
      lDescriptorBind: TAsmsymbind;
    begin
      lSavedFilePos:=CurrentFilePos;
      CurrentFilePos:=ASym.FileInfo;
      lSize:=ASym.GetSize;
      lWantedAlign:=ASym.vardef.Alignment;
      if ASym.vardef.inheritsfrom(TAbstractRecordDef) and
         (ASym.vardef.typ in [recorddef]) then
        lExplicitAlign:=TAbstractRecordSymTable(TAbstractRecordDef(ASym.vardef).SymTable).ExplicitRecordAlignment
      else
        lExplicitAlign:=0;
      if (lWantedAlign=0) then
        lVarAlign:=Var_Align_Size(lSize)
      else
        begin
          lVarAlign:=Var_Align(lWantedAlign);
          if (lExplicitAlign>lVarAlign) then
            begin
              Message1(scanner_w_alignment_larger_than_max,ASym.name);
              lVarAlign:=lExplicitAlign;
            end
          else if (lWantedAlign>lVarAlign) and (TargetInfo.Alignment.VarAlignMax>1) then
            begin
              { varalign:=wantedalign; this can lead to
                troubles on systems like for instance
                msdos which do not support 8-byte alignment }
              Message1(scanner_n_alignment_larger_than_max,ASym.name);
	    end;
	end;
      lAsmType:=AT_DATA;
      if tf_section_threadvars in TargetInfo.Flags then
        begin
          if (vo_is_thread_var in ASym.VarOptions) then
            begin
              lList:=CurrentAsmData.asmlists[al_threadvars];
              lSectionType:=sec_threadvar;
              lAsmType:=AT_TLS;
            end
          else
            begin
              lList:=CurrentAsmData.asmlists[al_globals];
              lSectionType:=sec_bss;
            end;
        end
      else
        begin
          if (vo_is_thread_var in ASym.VarOptions) then
            begin
              { The exported symbol is a two-word descriptor, never storage. }
              lBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_new_section]);
              lBuilder.begin_anonymous_record('',sizeof(PInt),sizeof(PInt),sizeof(PInt));
              lBuilder.emit_tai(TAIConst.Createname('FPC_THREADVAROWNER',0),VoidPointerType);
              lBuilder.emit_ord_const(0,SizeUIntType);
              lDescriptor:=lBuilder.end_anonymous_record;
              if ASym.GlobalAsmSym then
                lDescriptorBind:=AB_GLOBAL
              else if tf_supports_hidden_symbols in TargetInfo.Flags then
                lDescriptorBind:=AB_PRIVATE_EXTERN
              else
                lDescriptorBind:=AB_LOCAL;
              CurrentAsmData.asmlists[al_globals].ConcatList(lBuilder.get_final_asmlist(
                CurrentAsmData.DefineAsmSymbol(ASym.MangledName,lDescriptorBind,AT_DATA,lDescriptor),
                lDescriptor,sec_data,lower(ASym.MangledName),sizeof(PInt)));
              lBuilder.free;
              CurrentFilePos:=lSavedFilePos;
              exit;
            end;
          lList:=CurrentAsmData.asmlists[al_globals];
          lSectionType:=sec_bss;
        end;
      maybe_new_object_file(lList);
      if vo_has_section in ASym.VarOptions then
        new_section(lList,sec_user,ASym.section,lVarAlign)
      else
        new_section(lList,lSectionType,lower(ASym.MangledName),lVarAlign);
      InsertBSSSym(lList,ASym,lSize,lVarAlign,lAsmType);
      CurrentFilePos:=lSavedFilePos;
    end;


  class function TNodeUtils.Create_Main_ProcDef(const AName: string; AProcType: TProcTypeOption; AProcSym: TProcSym): TDef;
    var
      lProcDef: TProcDef;
    begin
      if AProcType<>potype_mainstub then
        lProcDef:=CProcDef.Create(MainProgramLevel,true)
      else
        lProcDef:=CProcDef.Create(NormalFunctionLevel,true);
      { always register the def }
      lProcDef.RegisterDef;
      lProcDef.ProcSym:=AProcSym;
      AProcSym.ProcdefList.Add(lProcDef);
      include(lProcDef.ProcOptions,po_global);
      { set procdef options }
      lProcDef.ProcTypeOption:=AProcType;
      lProcDef.ProcCallOption:=pocall_default;
      include(lProcDef.ProcOptions,po_hascallingconvention);
      lProcDef.ForwardDef:=false;
      { may be required to calculate the mangled name }
      Add_Main_ProcDef_Paras(lProcDef);
      lProcDef.SetMangledName(AName);
      { the mainstub is generated via a synthetic proc -> parsed via
        psub.read_proc_body() -> that one will insert the mangled name in the
        alias names already }
      if not(AProcType in [potype_mainstub,potype_libmainstub]) then
        lProcDef.AliasNames.insert(lProcDef.MangledName);
      Result:=lProcDef;
    end;


  class function TNodeUtils.Get_Init_Final_List(AMainModule : TModule):TFPList;

    procedure AddUsedUnits(AModule : TModule);

    var
      lUsedUnit : TUsedUnit;
      lEntry : PInitFinalEntry;
    begin
      lUsedUnit:=TUsedUnit(AModule.UsedUnitList.first);
      while Assigned(lUsedUnit) do
       begin
         if (not lUsedUnit.u.InitFinalChecked) then
           begin
           lUsedUnit.u.InitFinalChecked:=True;
           AddUsedUnits(lUsedUnit.u);
           if not Assigned(lUsedUnit.u.package) and
              ((lUsedUnit.u.ModuleFlags * [mf_init,mf_finalize])<>[]) then
             begin
               new(lEntry);
               lEntry^.Module:=lUsedUnit.u;
               lEntry^.InitPD:=nil;
               lEntry^.FiniPD:=nil;
               if mf_init in lUsedUnit.u.ModuleFlags then
                 lEntry^.InitFunc:=Make_MangledName('INIT$',lUsedUnit.u.GlobalSymTable,'')
               else
                 lEntry^.InitFunc:='';
               if mf_finalize in lUsedUnit.u.ModuleFlags then
                 lEntry^.FiniFunc:=Make_MangledName('FINALIZE$',lUsedUnit.u.GlobalSymTable,'')
               else
                 lEntry^.FiniFunc:='';
               Result.add(lEntry);
             end;
           end;
         lUsedUnit:=TUsedUnit(lUsedUnit.next);
       end;

    end;

    var
      lEntry : PInitFinalEntry;
    begin
      Result:=TFPList.Create;

      { Insert initialization/finalization of the used units }
      AddUsedUnits(AMainModule);

      { Insert initialization/finalization of the program }
      if (AMainModule.ModuleFlags * [mf_init,mf_finalize])<>[] then
        begin
          new(lEntry);
          lEntry^.Module:=CurrentModule;
          lEntry^.InitPD:=nil;
          lEntry^.FiniPD:=nil;
          if mf_init in CurrentModule.ModuleFlags then
            lEntry^.InitFunc:=Make_MangledName('INIT$',CurrentModule.LocalSymTable,'')
          else
            lEntry^.InitFunc:='';
          if mf_finalize in CurrentModule.ModuleFlags then
            lEntry^.FiniFunc:=Make_MangledName('FINALIZE$',CurrentModule.LocalSymTable,'')
          else
            lEntry^.FiniFunc:='';
          Result.add(lEntry);
        end;
    end;


  class procedure TNodeUtils.Release_Init_Final_List(AList:TFPList);
    begin
      if not Assigned(AList) then
        InternalError(2017051901);
      TFPList.FreeAndNilDisposing(AList,typeinfo(TInitFinalEntry));
    end;


  class procedure TNodeUtils.InsertInitFinalTable(AMainModule : TModule);
    var
      lEntries : TFPList;
    begin
      lEntries := Get_Init_Final_List(AMainModule);

      Insert_Init_Final_Table(AMainModule,lEntries);

      Release_Init_Final_List(lEntries);
    end;


  class procedure TNodeUtils.Insert_Init_Final_Table(AMainModule : TModule; AEntries:TFPList);
    var
      lIndex : LongInt;
      lUnitInits : TTAITypedConstBuilder;
      lInitName,lFiniName : TSymStr;
      lTableDef: TDef;
      lEntry : PInitFinalEntry;
      lUnitNameBuilder : TTAITypedConstBuilder;
      lUnitNameDef : TDef;
      lUnitNameLabel : TAsmLabel;

      procedure AddInitFinalImport(ASymTable:TSymTable);
        var
          lIndex,lOverloadIndex : LongInt;
          lFoundInit,lFoundFini : Boolean;
          lSymbol : TSymEntry;
          lProcDef : TProcDef;
        begin
          if (lInitName='') and (lFiniName='') then
            exit;
          lFoundInit:=lInitName='';
          lFoundFini:=lFiniName='';
          for lIndex:=0 to ASymTable.SymList.Count-1 do
            begin
              lSymbol:=TSymEntry(ASymTable.SymList[lIndex]);
              if lSymbol.typ<>ProcSym then
                continue;
              for lOverloadIndex:=0 to TProcSym(lSymbol).procdeflist.count-1 do
                begin
                  lProcDef:=TProcDef(TProcSym(lSymbol).procdeflist[lOverloadIndex]);
                  if (lInitName<>'') and not lFoundInit and lProcDef.Has_Alias_Name(lInitName) then
                    begin
                      CurrentModule.AddImportedSym(lSymbol);
                      lFoundInit:=true;
                    end;
                  if (lFiniName<>'') and not lFoundFini and lProcDef.Has_Alias_Name(lFiniName) then
                    begin
                      CurrentModule.AddImportedSym(lSymbol);
                      lFoundFini:=true;
                    end;
                  if lFoundInit and lFoundFini then
                    break;
                end;
              if lFoundInit and lFoundFini then
                break;
            end;
          if not lFoundInit or not lFoundFini then
            InternalError(2016041401);
        end;

    begin
      lUnitInits:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_new_section]);
      lUnitInits.begin_anonymous_record('',Default_Settings.PackRecords,sizeof(PInt),
        targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);

      { tablecount }
      lUnitInits.emit_ord_const(AEntries.count,ALUUIntType);
      { initcount (initialised at run time }
      lUnitInits.emit_ord_const(0,ALUUIntType);

      for lIndex:=0 to AEntries.count-1 do
        begin
          lEntry:=PInitFinalEntry(AEntries[lIndex]);
          if Assigned(lEntry^.InitPD) or Assigned(lEntry^.FiniPD) then
            begin
              if Assigned(lEntry^.InitPD) then
                begin
                  lUnitInits.emit_procdef_const(lEntry^.InitPD);
                  if lEntry^.Module<>CurrentModule then
                    CurrentModule.AddImportedSym(lEntry^.InitPD.ProcSym);
                end
              else
                lUnitInits.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType);
              if Assigned(lEntry^.FiniPD) then
                begin
                  lUnitInits.emit_procdef_const(lEntry^.FiniPD);
                  if lEntry^.Module<>CurrentModule then
                    CurrentModule.AddImportedSym(lEntry^.FiniPD.ProcSym);
                end
              else
                lUnitInits.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType);
            end
          else
            begin
              lInitName:='';
              lFiniName:='';
              if lEntry^.InitFunc<>'' then
                begin
                  lInitName:=lEntry^.InitFunc;
                  lUnitInits.emit_tai(
                    TAIConst.Createname(lInitName,AT_FUNCTION,0),
                    VoidCodePointerType);
                end
              else
                lUnitInits.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType);
              if lEntry^.FiniFunc<>'' then
                begin
                  lFiniName:=lEntry^.FiniFunc;
                  lUnitInits.emit_tai(
                    TAIConst.Createname(lFiniName,AT_FUNCTION,0),
                    VoidCodePointerType);
                end
              else
                lUnitInits.emit_tai(TAIConst.Create_nil_codeptr,VoidCodePointerType);
              if lEntry^.Module<>CurrentModule then
                AddInitFinalImport(lEntry^.Module.LocalSymTable);
            end;
          { Add pointer to unit name }
          if Assigned(lEntry^.Module.RealModuleName) then
            begin
              { Create string constant and emit pointer to it }
              lUnitInits.start_internal_data_builder(CurrentAsmData.asmlists[al_globals],sec_rodata,'',lUnitNameBuilder,lUnitNameLabel);
              lUnitNameDef:=lUnitNameBuilder.emit_shortstring_const(lEntry^.Module.RealModuleName^);
              lUnitInits.finish_internal_data_builder(lUnitNameBuilder,lUnitNameLabel,lUnitNameDef,sizeof(PInt));
              lUnitInits.queue_init(CharPointerType);
              lUnitInits.queue_emit_asmsym(lUnitNameLabel,lUnitNameDef);
            end
          else
            lUnitInits.emit_tai(TAIConst.Create_nil_dataptr,CharPointerType);
        end;

      { Add to data segment }
      lTableDef:=lUnitInits.end_anonymous_record;
      CurrentAsmData.asmlists[al_globals].ConcatList(
        lUnitInits.get_final_asmlist(
          CurrentAsmData.DefineAsmSymbol('INITFINAL',AB_GLOBAL,AT_DATA,lTableDef),
          lTableDef,
          sec_data,'INITFINAL',Const_Align(sizeof(PInt))
        )
      );

      lUnitInits.free;
      lUnitInits := nil;
    end;


  class function TNodeUtils.Has_Init_List: Boolean;
    var
      lUsedUnit : TUsedUnit;
    begin
      Result:=True;

      { Check current module first }
      if mf_init in CurrentModule.ModuleFlags then
        Exit;

      { Check used units }
      lUsedUnit:=TUsedUnit(UsedUnits.first);
      while Assigned(lUsedUnit) do
        begin
          if mf_init in lUsedUnit.u.ModuleFlags then
            Exit;
          lUsedUnit:=TUsedUnit(lUsedUnit.next);
        end;

      { We reach this point, none of the used units have an initialisation list }
      Result:=False;
    end;


  class procedure TNodeUtils.InsertThreadvarTablesTable;
    var
      lUsedUnit : TUsedUnit;
      lBuilder: TTAITypedConstBuilder;
      lCount: LongInt;
      lSymbol: TAsmSymbol;
      lPlaceholder: TTypedConstPlaceholder;
      lTableDef: TDef;
      lOwnerBind: TAsmsymbind;
    begin
      if (tf_section_threadvars in TargetInfo.Flags) then
        exit;
      lCount:=0;
      lBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_new_section]);
      lBuilder.begin_anonymous_record('',Default_Settings.PackRecords,VoidPointerType.Alignment,targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
      lPlaceholder:=lBuilder.emit_placeholder(SizeSIntType);

      lUsedUnit:=TUsedUnit(UsedUnits.first);
      while Assigned(lUsedUnit) do
       begin
         if not Assigned(lUsedUnit.u.package) and (mf_threadvars in lUsedUnit.u.ModuleFlags) then
           begin
             lSymbol:=CurrentAsmData.RefAsmSymbol(Make_MangledName('THREADVARLIST',lUsedUnit.u.GlobalSymTable,''),AT_DATA,true);
             lBuilder.emit_tai(
               TAIConst.Create_sym(lSymbol),
               VoidPointerType);
             CurrentModule.Add_Extern_AsmSym(lSymbol);
             inc(lCount);
           end;
         lUsedUnit:=TUsedUnit(lUsedUnit.next);
       end;
      { Add program threadvars, if any }
      if mf_threadvars in CurrentModule.ModuleFlags then
        begin
          lSymbol:=CurrentAsmData.RefAsmSymbol(Make_MangledName('THREADVARLIST',CurrentModule.LocalSymTable,''),AT_DATA,true);
          lBuilder.emit_tai(
            TAIConst.Create_sym(lSymbol),
            VoidPointerType);
          inc(lCount);
        end;
      { set the count at the start }
      lPlaceholder.replace(TAIConst.Create_sizeint(lCount),SizeSIntType);
      lPlaceholder.free;
      lPlaceholder := nil;
      { insert in data segment }
      lTableDef:=lBuilder.end_anonymous_record;
      if tf_supports_hidden_symbols in TargetInfo.Flags then
        lOwnerBind:=AB_PRIVATE_EXTERN
      else
        lOwnerBind:=AB_GLOBAL;
      lSymbol:=CurrentAsmData.DefineAsmSymbol('FPC_THREADVARTABLES',lOwnerBind,AT_DATA,lTableDef);
      CurrentAsmData.asmlists[al_globals].ConcatList(
        lBuilder.get_final_asmlist(
          lSymbol,lTableDef,sec_data,'FPC_THREADVARTABLES',Const_Align(sizeof(PInt))
        )
      );
      lBuilder.free;
      { All unit objects bind this local image owner at final link time. }
      lBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_new_section]);
      lBuilder.begin_anonymous_record('',sizeof(PInt),sizeof(PInt),sizeof(PInt));
      lBuilder.emit_tai(TAIConst.Createname('FPC_THREADVARTABLES',0),VoidPointerType);
      lBuilder.emit_ord_const(0,SizeUIntType); { runtime identity }
      lBuilder.emit_ord_const(0,SizeUIntType); { block size }
      lBuilder.emit_ord_const(0,SizeUIntType); { block alignment }
      lBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType); { main context debugger view }
      lTableDef:=lBuilder.end_anonymous_record;
      CurrentAsmData.asmlists[al_globals].ConcatList(lBuilder.get_final_asmlist(
        CurrentAsmData.DefineAsmSymbol('FPC_THREADVAROWNER',lOwnerBind,AT_DATA,lTableDef),
        lTableDef,sec_data,'FPC_THREADVAROWNER',sizeof(PInt)));
      lBuilder.free;
      lBuilder := nil;
    end;



  procedure AddToThreadvarList(AObject:TObject;AArg:Pointer);
    var
      lBuilder: TTAITypedConstBuilder;
      lDef: TDef;
      lAlignment: ShortInt;
    begin
      if (TSym(AObject).typ=staticvarsym) and
         (vo_is_thread_var in TStaticVarSym(AObject).VarOptions) then
       begin
         lBuilder:=TTAITypedConstBuilder(AArg);
         lDef:=TStaticVarSym(AObject).vardef;
         lAlignment:=lDef.Alignment;
         if (lDef.typ=recorddef) and
            (TAbstractRecordSymTable(TRecordDef(lDef).SymTable).ExplicitRecordAlignment>lAlignment) then
           lAlignment:=TAbstractRecordSymTable(TRecordDef(lDef).SymTable).ExplicitRecordAlignment;
         lBuilder.emit_tai(TAIConst.Createname(TStaticVarSym(AObject).MangledName,0),VoidPointerType);
         lBuilder.emit_ord_const(TStaticVarSym(AObject).GetSize,SizeUIntType);
         lBuilder.emit_ord_const(lAlignment,SizeUIntType);
       end;
    end;


  class procedure TNodeUtils.InsertThreadvars;
    var
      lName : TSymStr;
      lBuilder: TTAITypedConstBuilder;
      lSymbol: TAsmSymbol;
      lTableDef: TRecordDef;
      lAdd : Boolean;
    begin
       if (tf_section_threadvars in TargetInfo.Flags) then
         exit;
       lBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_new_section]);
       lTableDef:=lBuilder.begin_anonymous_record('',Default_Settings.PackRecords,VoidPointerType.Alignment,targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
       if Assigned(CurrentModule.GlobalSymTable) then
         CurrentModule.GlobalSymTable.SymList.ForEachCall(@AddToThreadvarList,lBuilder);
       CurrentModule.LocalSymTable.SymList.ForEachCall(@AddToThreadvarList,lBuilder);
       if TRecordSymTable(lTableDef.SymTable).DataSize<>0 then
         { terminator }
         lBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
       lBuilder.end_anonymous_record;
       lAdd:=TRecordSymTable(lTableDef.SymTable).DataSize<>0;
       if lAdd then
         begin
           lName:=Make_MangledName('THREADVARLIST',CurrentModule.LocalSymTable,'');
           lSymbol:=CurrentAsmData.DefineAsmSymbol(lName,AB_GLOBAL,AT_DATA_FORCEINDIRECT,lTableDef);
           CurrentAsmData.asmlists[al_globals].ConcatList(
             lBuilder.get_final_asmlist(lSymbol,lTableDef,sec_data,lName,Const_Align(sizeof(PInt))));
           include(CurrentModule.ModuleFlags,mf_threadvars);
           CurrentModule.Add_Public_AsmSym(lSymbol);
         end;
       lBuilder.Free;
       lBuilder := nil;
    end;


  class procedure TNodeUtils.InsertRuntimeInitsTablesTable(const APrefix,ATableName:string;AUnitFlag:TModuleFlag);
    var
      lUsedUnit: TUsedUnit;
      lBuilder: TTAITypedConstBuilder;
      lCountPlaceholder: TTypedConstPlaceholder;
      lTableDef: TDef;
      lCount: LongInt;
    begin
      lBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_new_section]);
      lBuilder.begin_anonymous_record('',Default_Settings.PackRecords,sizeof(PInt),
        targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin
      );
      { placeholder for the count }
      lCountPlaceholder:=lBuilder.emit_placeholder(SizeSIntType);
      lCount:=0;
      lUsedUnit:=TUsedUnit(UsedUnits.first);
      while Assigned(lUsedUnit) do
       begin
         if not Assigned(lUsedUnit.u.package) and (AUnitFlag in lUsedUnit.u.ModuleFlags) then
          begin
            lBuilder.emit_tai(
              TAIConst.Createname(Make_MangledName(APrefix,lUsedUnit.u.GlobalSymTable,''),0),
              VoidCodePointerType);
            inc(lCount);
          end;
         lUsedUnit:=TUsedUnit(lUsedUnit.next);
       end;
      { Add items from program, if any }
      if AUnitFlag in CurrentModule.ModuleFlags then
       begin
         lBuilder.emit_tai(
           TAIConst.Createname(Make_MangledName(APrefix,CurrentModule.LocalSymTable,''),0),
           VoidCodePointerType);
         inc(lCount);
       end;
      { Insert TableCount at start }
      lCountPlaceholder.replace(TAIConst.Create_sizeint(lCount),SizeSIntType);
      lCountPlaceholder.free;
      lCountPlaceholder := nil;
      { insert in data segment }
      lTableDef:=lBuilder.end_anonymous_record;
      CurrentAsmData.asmlists[al_globals].ConcatList(
        lBuilder.get_final_asmlist(
          CurrentAsmData.DefineAsmSymbol(ATableName,AB_GLOBAL,AT_DATA,lTableDef),
          lTableDef,
          sec_data,ATableName,Const_Align(sizeof(PInt))
        )
      );
      lBuilder.free;
      lBuilder := nil;
    end;


  class procedure TNodeUtils.InsertRuntimeInits(const APrefix:string;AList:TLinkedList;AUnitFlag:TModuleFlag);
    var
      lName: string;
      lItem: TTCInitItem;
      lBuilder: TTAITypedConstBuilder;
      lRawDataDef: TDef;
    begin
      lItem:=TTCInitItem(AList.First);
      if lItem=nil then
        exit;
      lName:=Make_MangledName(APrefix,CurrentModule.LocalSymTable,'');
      lBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_new_section]);
      lBuilder.begin_anonymous_record('',Default_Settings.PackRecords,sizeof(PInt),
        targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
      repeat
        { optimize away unused local/static symbols }
        if (lItem.sym.refs>0) or (lItem.sym.Owner.SymTableType=GlobalSymTable) then
          begin
            { address to initialize }
            lBuilder.queue_init(VoidPointerType);
            lRawDataDef:=CArrayDef.getreusable(CAnsiCharType,TStaticVarSym(lItem.sym).vardef.Size);
            lBuilder.queue_vecn(lRawDataDef,lItem.Offset);
            lBuilder.queue_typeconvn(CPointerDef.getreusable(TStaticVarSym(lItem.sym).vardef),CPointerDef.getreusable(lRawDataDef));
            lBuilder.queue_emit_staticvar(TStaticVarSym(lItem.sym));
            { value with which to initialize }
            lBuilder.emit_tai(TAIConst.Create_sym(lItem.datalabel),lItem.datadef)
          end;
        lItem:=TTCInitItem(lItem.Next);
      until lItem=nil;
      { end-of-list marker }
      lBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
      lRawDataDef:=lBuilder.end_anonymous_record;
      CurrentAsmData.asmlists[al_globals].ConcatList(
        lBuilder.get_final_asmlist(
          CurrentAsmData.DefineAsmSymbol(lName,AB_GLOBAL,AT_DATA,lRawDataDef),
          lRawDataDef,sec_data,lName,Const_Align(sizeof(PInt))));
      lBuilder.free;
      lBuilder := nil;
      include(CurrentModule.ModuleFlags,AUnitFlag);
    end;


  class procedure TNodeUtils.InsertWideInits;
    begin
      InsertRuntimeInits('WIDEINITS',CurrentAsmData.WideInits,mf_wideinits);
    end;


  class procedure TNodeUtils.InsertResStrInits;
    begin
      InsertRuntimeInits('RESSTRINITS',CurrentAsmData.ResStrInits,mf_resstrinits);
    end;


  class procedure TNodeUtils.InsertWideInitsTablesTable;
    begin
      InsertRuntimeInitsTablesTable('WIDEINITS','FPC_WIDEINITTABLES',mf_wideinits);
    end;


  class procedure TNodeUtils.InsertResStrTablesTable;
    begin
      InsertRuntimeInitsTablesTable('RESSTRINITS','FPC_RESSTRINITTABLES',mf_resstrinits);
    end;


  class procedure TNodeUtils.InsertResourceTablesTable;
    var
      lModule : TModule;
      lCount : LongInt;
      lBuilder : TTAITypedConstBuilder;
      lCountPlaceholder : TTypedConstPlaceholder;
      lTableDef: TDef;
    begin
      lBuilder:=CTAITypedConstBuilder.Create([tcalo_make_dead_strippable,tcalo_new_section]);
      lCount:=0;
      lModule:=TModule(Loaded_Units.first);
      lBuilder.begin_anonymous_record('',Default_Settings.PackRecords,sizeof(PInt),
        targetinfos[Ord(TargetInfo.system)]^.Alignment.RecordAlignMin);
      lCountPlaceholder:=lBuilder.emit_placeholder(SizeSIntType);
      while Assigned(lModule) do
        begin
          if not Assigned(lModule.package) and (mf_has_resourcestrings in lModule.ModuleFlags) then
            begin
              lBuilder.emit_tai(TAIConst.Create_sym(
                CTAITypedConstBuilder.get_vectorized_dead_strip_section_symbol_start('RESSTR',lModule.LocalSymTable,[tcdssso_register_asmsym,tcdssso_use_indirect])),
                VoidPointerType
              );
              lBuilder.emit_tai(TAIConst.Create_sym(
                CTAITypedConstBuilder.get_vectorized_dead_strip_section_symbol_end('RESSTR',lModule.LocalSymTable,[tcdssso_register_asmsym,tcdssso_use_indirect])),
                VoidPointerType
              );
              inc(lCount);
            end;
          lModule:=TModule(lModule.next);
        end;
      { Insert TableCount at start }
      lCountPlaceholder.replace(TAIConst.Create_sizeint(lCount),SizeSIntType);
      lCountPlaceholder.free;
      lCountPlaceholder := nil;
      { Add to data segment }
      lTableDef:=lBuilder.end_anonymous_record;
      CurrentAsmData.AsmLists[al_globals].ConcatList(
        lBuilder.get_final_asmlist(
          CurrentAsmData.DefineAsmSymbol('FPC_RESOURCESTRINGTABLES',AB_GLOBAL,AT_DATA,lTableDef),
          lTableDef,sec_rodata,'FPC_RESOURCESTRINGTABLES',Const_Align(sizeof(PInt))
        )
      );
      lBuilder.free;
      lBuilder := nil;
    end;


  class procedure TNodeUtils.InsertResourceInfo(AResourcesUsed: Boolean);
    var
      lBuilder: TTAITypedConstBuilder;
    begin
      if TargetInfo.res in [res_elf,res_macho] then
        begin
          lBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_make_dead_strippable]);

          if AResourcesUsed then
            lBuilder.emit_tai(TAIConst.Createname('FPC_RESSYMBOL',0),VoidPointerType)
          else
            { Nil pointer to resource information }
            lBuilder.emit_tai(TAIConst.Create_nil_dataptr,VoidPointerType);
          CurrentAsmData.asmlists[al_globals].ConcatList(
            lBuilder.get_final_asmlist(
              CurrentAsmData.DefineAsmSymbol('FPC_RESLOCATION',AB_GLOBAL,AT_DATA,VoidPointerType),
              VoidPointerType,
              sec_rodata,
              'FPC_RESLOCATION',
              Const_Align(sizeof(PUint))
            )
          );

          lBuilder.free;
          lBuilder := nil;
        end;
    end;


  class procedure TNodeUtils.InsertMemorySizes;
    var
      lBuilder: TTAITypedConstBuilder;
      lName: ShortString;
      lSymbol: TAsmSymbol;
      lDef: TDef;
    begin
      { Insert Ident of the compiler in the .fpc.version section }
      lBuilder:=CTAITypedConstBuilder.Create([tcalo_no_dead_strip]);
      lName:='NXPC '+Full_Version_String+
        ' ['+DateString+'] for '+TargetCPUString+' - '+TargetInfo.shortname;
      lDef:=CArrayDef.getreusable(CAnsiCharType,length(lName));
      lBuilder.maybe_begin_aggregate(lDef);
      lBuilder.emit_tai(TAIString.Create(lName),lDef);
      lBuilder.maybe_end_aggregate(lDef);
      lSymbol:=CurrentAsmData.DefineAsmSymbol('__fpc_ident',AB_LOCAL,AT_DATA,lDef);
      CurrentAsmData.asmlists[al_globals].ConcatList(
        lBuilder.get_final_asmlist(lSymbol,lDef,sec_fpc,'version',Const_Align(32))
      );
      lBuilder.free;

      if (tf_emit_stklen in TargetInfo.Flags) or
          not(tf_no_generic_stackcheck in TargetInfo.Flags) then
        begin
          { stacksize can be specified and is now simulated }
          lBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_make_dead_strippable]);
          lBuilder.emit_tai(TAIConst.Create_int_dataptr(StackSize),PtrUIntType);
          lSymbol:=CurrentAsmData.DefineAsmSymbol('__stklen',AB_GLOBAL,AT_DATA,PtrUIntType);
          CurrentAsmData.asmlists[al_globals].ConcatList(
            lBuilder.get_final_asmlist(lSymbol,PtrUIntType,sec_data,'__stklen',Const_Align(sizeof(PInt)))
          );
          lBuilder.free;
          lBuilder := nil;
        end;

      { Initial heapsize }
      lBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_make_dead_strippable]);
      lBuilder.emit_tai(TAIConst.Create_int_dataptr(HeapSize),PtrUIntType);
      lSymbol:=CurrentAsmData.DefineAsmSymbol('__heapsize',AB_GLOBAL,AT_DATA,PtrUIntType);
      CurrentAsmData.asmlists[al_globals].ConcatList(
        lBuilder.get_final_asmlist(lSymbol,PtrUIntType,sec_data,'__heapsize',Const_Align(sizeof(PInt)))
      );
      lBuilder.free;
      lBuilder := nil;

      { Valgrind usage }
      lBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_make_dead_strippable]);
      lBuilder.emit_ord_const(Byte(cs_gdb_valgrind in CurrentSettings.GlobalSwitches),U8IntType);
      lSymbol:=CurrentAsmData.DefineAsmSymbol('__fpc_valgrind',AB_GLOBAL,AT_DATA,U8IntType);
      CurrentAsmData.asmlists[al_globals].ConcatList(
        lBuilder.get_final_asmlist(lSymbol,U8IntType,sec_data,'__fpc_valgrind',Const_Align(sizeof(PInt)))
      );
      lBuilder.free;
      lBuilder := nil;
    end;


  class procedure TNodeUtils.InsertObjectInfo;
    var
      lBuilder: TTAITypedConstBuilder;
    begin
      if (m_objectivec1 in CurrentSettings.ModeSwitches) then
        begin
          { first 4 bytes contain version information about this section (currently version 0),
            next 4 bytes contain flags (currently only regarding whether the code in the object
            file supports or requires garbage collection)
          }
          lBuilder:=CTAITypedConstBuilder.Create([tcalo_new_section,tcalo_no_dead_strip]);
          lBuilder.emit_ord_const(0,U64IntType);
          CurrentAsmData.asmlists[al_objc_data].ConcatList(
            lBuilder.get_final_asmlist(
              CurrentAsmData.DefineAsmSymbol(TargetAsm.labelprefix+'_OBJC_IMAGE_INFO',AB_LOCAL,AT_DATA,U64IntType),
              U64IntType,sec_objc_image_info,'_OBJC_IMAGE_INFO',Const_Align(sizeof(PInt))
            )
          );
          lBuilder.free;
          lBuilder := nil;
        end;
    end;


  class procedure TNodeUtils.RegisterUsedAsmSym(ASym: TAsmSymbol; ADef: TDef; ACompilerOnly: Boolean);
    begin
      { don't do anything by default }
    end;


  class procedure TNodeUtils.RegisterModuleInitFunction(AProcDef: TProcDef);
    begin
      { setinitname may generate a new section -> don't add to the
        current list, because we assume this remains a text section }
      exportlib.setinitname(CurrentAsmData.AsmLists[al_pure_assembler],AProcDef.MangledName);
    end;


  class procedure TNodeUtils.RegisterModuleFiniFunction(AProcDef: TProcDef);
    begin
      exportlib.setfininame(CurrentAsmData.AsmLists[al_pure_assembler],AProcDef.MangledName);
    end;


   class procedure TNodeUtils.Add_Main_ProcDef_Paras(AProcDef: TDef);
     var
       lParaVarSym: TParaVarSym;
     begin
       { stub for calling FPC_SYSTEMMAIN from the C main -> add argc/argv/argp }
       if (TProcDef(AProcDef).ProcTypeOption=potype_mainstub) and
          (TargetInfo.system in systems_darwin) then
         begin
           lParaVarSym:=CParaVarSym.Create('ARGC',1,vs_const,S32IntType,[]);
           TProcDef(AProcDef).ParaST.InsertSym(lParaVarSym);
           lParaVarSym:=CParaVarSym.Create('ARGV',2,vs_const,CPointerDef.getreusable(CharPointerType),[]);
           TProcDef(AProcDef).ParaST.InsertSym(lParaVarSym);
           lParaVarSym:=CParaVarSym.Create('ARGP',3,vs_const,CPointerDef.getreusable(CharPointerType),[]);
           TProcDef(AProcDef).ParaST.InsertSym(lParaVarSym);
           TProcDef(AProcDef).CalcParas;
         end
       { package stub for Windows is a DLLMain }
       else if (TProcDef(AProcDef).ProcTypeOption=potype_pkgstub) and
           (TargetInfo.system in systems_all_windows) then
         begin
           lParaVarSym:=CParaVarSym.Create('HINSTANCE',1,vs_const,UIntType,[]);
           TProcDef(AProcDef).ParaST.InsertSym(lParaVarSym);
           lParaVarSym:=CParaVarSym.Create('DLLREASON',2,vs_const,U32IntType,[]);
           TProcDef(AProcDef).ParaST.InsertSym(lParaVarSym);
           lParaVarSym:=CParaVarSym.Create('DLLPARAM',3,vs_const,VoidPointerType,[]);
           TProcDef(AProcDef).ParaST.InsertSym(lParaVarSym);
           TProcDef(AProcDef).ReturnDef:=Bool32Type;
           Insert_FuncRet_Para(TProcDef(AProcDef));
           TProcDef(AProcDef).CalcParas;
         end;
     end;


end.
