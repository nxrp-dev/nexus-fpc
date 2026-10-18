{
    Copyright (c) 1998-2002 by Florian Klaempfl, Daniel Mantione

    Does the parsing and codegeneration at subroutine level

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
unit psub;

{$i fpcdefs.inc}

{ $define debug_eh}

interface

    uses
      Globals,CClasses,
      node,nbas,nutils,AAsmData,
      symdef,ProcInfo,optdfa;

    type
      TCGProcInfo = class(TProcInfo)
      private type
        TTempInfoFlagsEntry = record
          TempInfo : PTempInfo;
          Flags : TTempInfoFlags;
        end;
        PTempInfoFlagsEntry = ^TTempInfoFlagsEntry;
      private
        FTempInfoFlagsMap : TFPList;
        FTempFlagsSwapped : boolean;
        procedure SwapTempFlags;
        function StoreNodeTempFlags(var ANode: TNode; AArg: pointer): TForEachNodeResult;
        procedure CreateInlineInfo;
        { returns the node which is the start of the user code, this is needed by the dfa }
        function GetUserCode: TNode;
        procedure MaybeAddConstructorWrapper(var ACode: TNode; AWithExceptBlock: boolean);
        procedure AddEntryExitCode;
        procedure SetupTempGen;
        procedure TransformNodeTree;
        procedure ConvertCapturedSyms;
      protected
        procedure Generate_Code_ExceptFilters;
      public
        { code for the subroutine as tree }
        Code : TNode;
        { positions in the tree for init/final }
        EntryAsmNode,
        LoadParaAsmNode,
        ExitLabelAsmNode,
        StackCheckAsmNode,
        InitAsmNode    : TAsmNode;
        TempsFinalized : boolean;
        DFABuilder : TDFABuilder;
        { Last temp offset of the parent procedure at the time exceptfilter
          code generation begins. Temps below this boundary belong to the parent
          and must be adjusted to FP-relative in the handler. Temps at or above
          this boundary belong to the handler and stay SP-relative.
          Only used on AArch64-Win64. }
        ExceptFilterParentTempEnd : LongInt;

        destructor  Destroy;override;

        function Calc_StackFrame_Size : LongInt;override;

        procedure PrintProc(APass:string);
        procedure Generate_Code;
        procedure Generate_Code_Tree;
        procedure Generate_ExceptFilter(ANestedProcInfo: TCGProcInfo);
        procedure Generate_Exit_Label(AList: TAsmList); virtual;
        procedure ResetProcDef;
        procedure Add_To_SymTableStack;
        procedure Remove_From_SymTableStack;
        procedure Parse_Body;

        procedure Store_TempFlags;
        procedure Apply_TempFlags;
        procedure Reset_TempFlags;

        function Has_Assembler_Child : boolean;
        procedure Set_EH_Info; override;
      end;

      TReadProcFlag = (
        rpf_classmethod,
        rpf_generic,
        rpf_anonymous
      );
      TReadProcFlags = set of TReadProcFlag;


    procedure PrintNode_Reset;

    { reads the declaration blocks }
    procedure Read_Declarations(AIsLibrary : boolean);

    { reads declarations in the interface part of a unit }
    procedure Read_Interface_Declarations;

    { reads any routine in the implementation, or a non-method routine
      declaration in the interface (depending on whether or not parse_only is
      true) }
    function Read_Proc(AFlags:TReadProcFlags; AForwardProcDef: TProcDef):TProcDef;

    { parses only the body of a non nested routine; needs a correctly setup pd }
    procedure Read_Proc_Body(AProcDef:TProcDef);

    procedure Import_External_Proc(AProcDef:TProcDef);


implementation

    uses
       SysUtils,
       { common }
       CUtils, CMsgs, CDynSet,
       { global }
       GlobType,tokens,Verbose,CompHook,ConstExp,
       Systems,cpubase,aasmbase,aasmtai,
       { symtable }
       symconst,SymBase,SymSym,symtype,SymTable,defutil,defcmp,procdefutil,symcreat,
       paramgr,
       FModule,
       { pass 1 }
       ngenutil,nld,ncal,ncon,nflw,nadd,ncnv,nmem,
       Pass_1,
       { pass 2 }
{$ifndef NOPASS2}
       pass_2,
{$endif}
       { parser }
       Scanner,gendef,
       pbase,pstatmnt,pdecl,pdecsub,pexports,pgenutil,pparautl,
       { codegen }
       tgobj,cgbase,cgobj,hlcgobj,hlcgcpu,DbgBase,

       ncgflw,
       ncgutil,

       optbase,
       opttree,
       opttail,
       optcse,
       optloop,
       optconstprop,
       optdeadstore,
       optloadmodifystore,
       optcall,
       optutils
       {$ifndef NOOPT}
       ,aopt
       {$endif}
       ;

    function CheckNodeInlining(AProcDef: TProcDef): boolean;

      procedure NoInline(const AReason: TMsgStr);
        begin
          include(AProcDef.ImplProcOptions,pio_inline_not_possible);
          Message1(parser_n_not_supported_for_inline,AReason);
          Message(parser_h_inlining_disabled);
        end;

      var
        lIndex : integer;
        lCurrentPara : TParaVarSym;
      begin
        Result := false;
        { this code will never be used (only specialisations can be inlined),
          and moreover contains references to defs that are not stored in the
          ppu file }
        if df_generic in CurrentProcInfo.ProcDef.DefOptions then
          exit;
        if pi_has_assembler_block in CurrentProcInfo.Flags then
          begin
            NoInline('assembler');
            exit;
          end;
        if (pi_has_global_goto in CurrentProcInfo.Flags) or
           (pi_has_interproclabel in CurrentProcInfo.Flags) then
          begin
            NoInline('global goto');
            exit;
          end;
        if pi_has_nested_exit in CurrentProcInfo.Flags then
          begin
            NoInline('nested exit');
            exit;
          end;
        if pi_calls_c_varargs in CurrentProcInfo.Flags then
          begin
            NoInline('called C-style varargs functions');
            exit;
          end;
        { the compiler cannot handle inherited in inlined subroutines because
          it tries to search for self in the symtable, however, the symtable
          is not available }
        if pi_has_inherited in CurrentProcInfo.Flags then
          begin
            NoInline('inherited');
            exit;
          end;
        if pio_nested_access in AProcDef.ImplProcOptions then
         begin
           NoInline('access to local from nested scope');
           exit;
         end;
        { We can't support inlining for procedures that have nested
          procedures because the nested procedures use a fixed offset
          for accessing locals in the parent procedure (PFV) }
        if CurrentProcInfo.Has_NestedProcs then
          begin
            NoInline('nested procedures');
            exit;
          end;

        if pi_uses_get_frame in CurrentProcInfo.Flags then
          begin
            NoInline('get_frame');
            { for LLVM: it can inline things that FPC can't, but it mustn't
              inline this one }
            include(CurrentProcInfo.ProcDef.ImplProcOptions,pio_inline_forbidden);
            exit;
          end;

        for lIndex:=0 to AProcDef.paras.count-1 do
          begin
            lCurrentPara:=TParaVarSym(AProcDef.paras[lIndex]);
            case lCurrentPara.vardef.typ of
              arraydef :
                begin
                  if Is_Array_Of_Const(lCurrentPara.vardef) or
                     Is_Variant_Array(lCurrentPara.vardef) then
                    begin
                      NoInline('array of const');
                      exit;
                    end;
                  { open arrays might need re-basing of the index, i.e. if you pass
                    an array[1..10] as open array, you have to add 1 to all index operations
                    if you directly inline it }
                  if Is_Open_Array(lCurrentPara.vardef) then
                    begin
                      NoInline('open array');
                      exit;
                    end;
                end;
              else
                ;
            end;
        end;
        Result:=true;
      end;


{****************************************************************************
                      PROCEDURE/FUNCTION BODY PARSING
****************************************************************************}

    procedure InitializeVars(AObject:TObject;AArg:pointer);
      var
        lBlock : TBlockNode;
      begin
        if not (TSym(AObject).typ in [localvarsym,staticvarsym]) then
         exit;
        with TAbstractNormalVarSym(AObject) do
         begin
           if Assigned(DefaultConstSym) then
            begin
              lBlock:=TBlockNode(AArg);
              lBlock.left:=CStatementNode.Create(
                        CAssignmentNode.Create(
                            CLoadNode.Create(TSym(AObject),TSym(AObject).owner),
                            CLoadNode.Create(DefaultConstSym,DefaultConstSym.owner)),
                        lBlock.left);
            end
         end;
      end;


    procedure CheckFinalizeParas(AObject:TObject;AArg:pointer);
      begin
        if (TSym(AObject).typ=paravarsym) then
          begin
            if TParaVarSym(AObject).Needs_Finalization then
              begin
                include(CurrentProcInfo.Flags,pi_needs_implicit_finally);
                include(CurrentProcInfo.Flags,pi_do_call);
              end;
          end;
      end;


    procedure CheckFinalizeLocals(AObject:TObject;AArg:pointer);
      begin
        { include the result: it needs to be finalized in case an exception }
        { occurs                                                            }
        if (TSym(AObject).typ=localvarsym) and
           (TLocalVarSym(AObject).refs>0) and
           Is_Managed_Type(TLocalVarSym(AObject).vardef) then
          begin
            include(CurrentProcInfo.Flags,pi_needs_implicit_finally);
            include(CurrentProcInfo.Flags,pi_do_call);
          end;
      end;

    procedure InitMainBlockSyms(ABlock: TNode);
      var
         lOldFilePos: TFilePosInfo;
      begin
        { initialized variables }
        if CurrentProcInfo.ProcDef.LocalST.SymTableType=LocalSymTable then
         begin
           { initialization of local variables with their initial
             values: part of function entry }
           lOldFilePos:=CurrentFilePos;
           CurrentFilePos:=CurrentProcInfo.EntryPos;
           CurrentProcInfo.ProcDef.LocalST.SymList.ForEachCall(@InitializeVars,ABlock);
           CurrentFilePos:=lOldFilePos;
         end;

        if Assigned(CurrentProcInfo.ProcDef.ParentFPStruct) then
         begin
           { finish the parentfpstruct (add padding, ...) }
           Finish_ParentFPStruct(CurrentProcInfo.ProcDef);
         end;
      end;

    function Block(AIsLibrary : boolean) : TNode;
      begin
         { parse const,types and vars }
         Read_Declarations(AIsLibrary);

         { do we have an assembler block without the po_assembler?
           we should allow this for Delphi compatibility (PFV) }
         if (CurrentScanner.token=_ASM) and (m_delphi in CurrentSettings.ModeSwitches) then
           include(CurrentProcInfo.ProcDef.ProcOptions,po_assembler);

         { Handle assembler block different }
         if (po_assembler in CurrentProcInfo.ProcDef.ProcOptions) then
          begin
            Block:=assembler_block;
            exit;
          end;

         {Unit initialization?.}
         if (
             Assigned(CurrentProcInfo.ProcDef.LocalST) and
             (CurrentProcInfo.ProcDef.LocalST.SymTableLevel=MainProgramLevel) and
             (CurrentModule.IsUnit or AIsLibrary)
            ) then
           begin
             if (CurrentScanner.token=_END) then
                begin
                   consume(_END);
                   { We need at least a node, else the entry/exit code is not
                     generated and thus no PASCALMAIN symbol which we need (PFV) }
                   if AIsLibrary then
                    Block:=CNothingNode.Create
                   else
                    Block:=nil;
                end
              else
                begin
                   if CurrentScanner.token=_INITIALIZATION then
                     begin
                        { The library init code is already called and does not
                          need to be in the initfinal table (PFV) }
                        Block:=statement_block(_INITIALIZATION);
                        InitMainBlockSyms(Block);
                     end
                   else if CurrentScanner.token=_FINALIZATION then
                     begin
                       { when a unit has only a finalization section, we can come to this
                         point when we try to read the nonh existing initialization section
                         so we've to check if we are really try to parse the finalization }
                       if CurrentProcInfo.ProcDef.ProcTypeOption=potype_unitfinalize then
                         Block:=statement_block(_FINALIZATION)
                       else
                         Block:=nil;
                     end
                   else
                     Block:=statement_block(_BEGIN);
                end;
            end
         else
            begin
               { parse routine body }
               Block:=statement_block(_BEGIN);
               InitMainBlockSyms(Block);
            end;
      end;


{****************************************************************************
                       PROCEDURE/FUNCTION COMPILING
****************************************************************************}

    procedure PrintNode_Reset;
      begin
        assign(PrintNodeFile,TreeLogFileName);
        {$push}{$I-}
         rewrite(PrintNodeFile);
        {$pop}
        if IOResult<>0 then
         begin
           Comment(VError,'Error creating '+TreeLogFileName);
           exit;
         end;
        close(PrintNodeFile);
      end;


    procedure AddLabelInit(AObject:TObject;AArg:pointer);
      begin
        if TStoredSym(AObject).typ=labelsym then
          begin
            AddStatement(TStatementNode(AArg^),
              CIfNode.Create(CAddNode.Create(EqualN,
                CCallNode.CreateIntern('fpc_setjmp',
                  CCallParaNode.Create(CLoadNode.Create(TLabelSym(AObject).JumpBuf,TLabelSym(AObject).JumpBuf.owner),nil)),
                COrdConstNode.Create(1,Search_System_Proc('fpc_setjmp').ReturnDef,true))
              ,CGotoNode.Create(TLabelSym(AObject)),nil)
            );
          end;
      end;


    function GenerateBodyEntryBlock:TNode;
      var
        lSym        : TSym;
        lPara         : TCallParaNode;
        lCall         : TCallNode;
        lNewStatement : TStatementNode;
        lDef          : TAbstractRecordDef;
      begin
        Result:=InternalStatements(lNewStatement);

        if Assigned(CurrentStructDef) then
          begin
            { a constructor needs a help procedure }
            if (CurrentProcInfo.ProcDef.ProcTypeOption=potype_constructor) then
              begin
                if Is_Class(CurrentStructDef) or
                    (
                      Is_ObjectPascal_Helper(CurrentStructDef) and
                      Is_Class(TObjectDef(CurrentStructDef).ExtendedDef)
                    ) then
                  begin
                    if Is_ObjectPascal_Helper(CurrentStructDef) then
                      lDef:=TAbstractRecordDef(TObjectDef(CurrentStructDef).ExtendedDef)
                    else
                      lDef:=CurrentStructDef;
                    lSym:=Search_Struct_Member(lDef,'NEWINSTANCE');
                    if Assigned(lSym) and
                       (lSym.typ=ProcSym) then
                      begin
                        { if vmt=1 then newinstance }
                        lCall:=
                          CCallNode.Create(nil,TProcSym(lSym),lSym.owner,
                            CTypeConvNode.Create_Internal(Load_Self_Pointer_Node,CClassRefDef.Create(CurrentStructDef)),
                            [],nil);
                        include(lCall.CallNodeFlags,cnf_ignore_devirt_wpo);
                        AddStatement(lNewStatement,CIfNode.Create(
                            CAddNode.Create_Internal(EqualN,
                                CTypeConvNode.Create_Internal(
                                    Load_VMT_Pointer_Node,
                                    VoidPointerType),
                                CPointerConstNode.Create(1,VoidPointerType)),
                            CAssignmentNode.Create(
                                CTypeConvNode.Create_Internal(
                                    Load_Self_Pointer_Node,
                                    VoidPointerType),
                                lCall),
                            nil));
                      end
                    else
                      Message(parser_e_no_suitable_newinstance_method_found);
                  end
                else
                  if Is_Object(CurrentStructDef) then
                    begin
                      { parameter 3 : vmt_offset }
                      { parameter 2 : address of pointer to vmt,
                        this is required to allow setting the vmt to -1 to indicate
                        that memory was allocated }
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
                      AddStatement(lNewStatement,CAssignmentNode.Create(
                          CTypeConvNode.Create_Internal(
                              Load_Self_Pointer_Node,
                              VoidPointerType),
                          CCallNode.CreateIntern('fpc_help_constructor',lPara)));
                    end
                else
                  if not Is_Record(CurrentStructDef) and
                     not (
                            Is_ObjectPascal_Helper(CurrentStructDef) and
                            (TObjectDef(CurrentStructDef).ExtendedDef.typ<>objectdef)
                         ) then
                    InternalError(200305103);
                { if self=nil then exit
                  calling fail instead of exit is useless because
                  there is nothing to dispose (PFV) }
                if Is_Class_Or_Object(CurrentStructDef) then
                  AddStatement(lNewStatement,CIfNode.Create(
                    CAddNode.Create(EqualN,
                        Load_Self_Pointer_Node,
                        CNilNode.Create),
                    CExitNode.Create(nil),
                    nil));
              end;

            { maybe call BeforeDestruction for classes }
            if (CurrentProcInfo.ProcDef.ProcTypeOption=potype_destructor) and
               Is_Class(CurrentStructDef) then
              begin
                lSym:=Search_Struct_Member(CurrentStructDef,'BEFOREDESTRUCTION');
                if Assigned(lSym) and
                   (lSym.typ=ProcSym) then
                  begin
                    { if vmt>0 then beforedestruction }
                    AddStatement(lNewStatement,CIfNode.Create(
                        CAddNode.Create(gtn,
                            CTypeConvNode.Create_Internal(
                              Load_VMT_Pointer_Node,PtrSIntType),
                            CTypeConvNode.Create_Internal(
                              CNilNode.Create,PtrSIntType)),
                        CCallNode.Create(nil,TProcSym(lSym),lSym.owner,Load_Self_Node,[],nil),
                        nil));
                  end
                else
                  InternalError(200305104);
              end;
          end;
        if m_non_local_goto in CurrentSettings.ModeSwitches then
          TSymTable(CurrentProcInfo.ProcDef.LocalST).SymList.ForEachCall(@AddLabelInit,@lNewStatement);

        Initialize_Capturer(CurrentProcInfo,lNewStatement);
      end;


    function GenerateBodyExitBlock:TNode;
      var
        lSym : TSym;
        lPara : TCallParaNode;
        lNewStatement : TStatementNode;
        lOldLocalSwitches: TLocalSwitches;
      begin
        Result:=InternalStatements(lNewStatement);

        if Assigned(CurrentStructDef) then
          begin
            { Don't test self and the vmt here. The reason is that  }
            { a constructor already checks whether these are valid  }
            { before. Further, in case of TThread the thread may    }
            { free the class instance right after AfterConstruction }
            { has been called, so it may no longer be valid (JM)    }
            lOldLocalSwitches:=CurrentSettings.LocalSwitches;
            CurrentSettings.LocalSwitches:=lOldLocalSwitches-[cs_check_object,cs_check_range];

            { a destructor needs a help procedure }
            if (CurrentProcInfo.ProcDef.ProcTypeOption=potype_destructor) then
              begin
                if Is_Class(CurrentStructDef) then
                  begin
                    lSym:=Search_Struct_Member(CurrentStructDef,'FREEINSTANCE');
                    if Assigned(lSym) and
                       (lSym.typ=ProcSym) then
                      begin
                        { if self<>0 and vmt<>0 then freeinstance }
                        AddStatement(lNewStatement,CIfNode.Create(
                            CAddNode.Create(andn,
                                CAddNode.Create(unequaln,
                                    Load_Self_Pointer_Node,
                                    CNilNode.Create),
                                CAddNode.Create(unequaln,
                                    CTypeConvNode.Create(
                                        Load_VMT_Pointer_Node,
                                        VoidPointerType),
                                    CPointerConstNode.Create(0,VoidPointerType))),
                            CCallNode.Create(nil,TProcSym(lSym),lSym.owner,Load_Self_Node,[],nil),
                            nil));
                      end
                    else
                      InternalError(2003051001);
                  end
                else
                  if Is_Object(CurrentStructDef) then
                    begin
                      { finalize object data, but only if not in inherited call }
                      if Is_Managed_Type(CurrentStructDef) then
                        begin
                          AddStatement(lNewStatement,CIfNode.Create(
                            CAddNode.Create(unequaln,
                              CTypeConvNode.Create_Internal(Load_VMT_Pointer_Node,VoidPointerType),
                              CNilNode.Create),
                            CNodeUtils.Finalize_Data_Node(Load_Self_Node),
                            nil));
                        end;
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
                          CCallNode.CreateIntern('fpc_help_destructor',lPara));
                    end
                else
                  InternalError(200305105);
              end;
            CurrentSettings.LocalSwitches:=lOldLocalSwitches;
          end;
      end;


{****************************************************************************
                                  TCGProcInfo
****************************************************************************}

     destructor TCGProcInfo.Destroy;
       begin
         TFPList.FreeAndNilDisposing(FTempInfoFlagsMap,TypeInfo(TTempInfoFlagsEntry));
         Code.free;
         Code := nil;
         inherited Destroy;
       end;


    function TCGProcInfo.Calc_StackFrame_Size:LongInt;
      begin
        Result:=Align(TG.direction*TG.LastTemp,CurrentSettings.Alignment.LocalAlignMin);
      end;


    procedure TCGProcInfo.PrintProc(APass:string);
      begin
        assign(PrintNodeFile,TreeLogFileName);
        {$push}{$I-}
         append(PrintNodeFile);
         if IOResult<>0 then
          rewrite(PrintNodeFile);
        {$pop}
        if IOResult<>0 then
         begin
           Comment(VError,'Error creating '+TreeLogFileName);
           exit;
         end;
        WriteLn(PrintNodeFile);
        WriteLn(PrintNodeFile,'*******************************************************************************');
        WriteLn(PrintNodeFile, APass);
        WriteLn(PrintNodeFile,ProcDef.FullProcName(false));
        WriteLn(PrintNodeFile,'*******************************************************************************');
        PrintNode(PrintNodeFile,Code);
        close(PrintNodeFile);
      end;


    procedure TCGProcInfo.MaybeAddConstructorWrapper(var ACode: TNode; AWithExceptBlock: boolean);
      var
        lOldLocalSwitches: TLocalSwitches;
        lSym: TSym;
        lConstructionBlock,
        lExceptBlock,
        lNewBlock: TBlockNode;
        lNewStatement: TStatementNode;
        lProcDef: TProcDef;
        lConstructionSuccessful: TLocalVarSym;
      begin
        if Assigned(ProcDef.struct) and
           (ProcDef.ProcTypeOption=potype_constructor) then
          begin
            { Don't test self and the vmt here. See generate_bodyexit_block }
            { why (JM)                                                      }
            lOldLocalSwitches:=CurrentSettings.LocalSwitches;
            CurrentSettings.LocalSwitches:=lOldLocalSwitches-[cs_check_object,cs_check_range];

            { call AfterConstruction for classes }
            lConstructionSuccessful:=nil;
            if Is_Class(ProcDef.struct) then
              begin
                lConstructionSuccessful:=CLocalVarSym.Create(InternalTypePrefixName[itp_vmt_afterconstruction_local],vs_value,PtrSIntType,[]);
                ProcDef.LocalST.InsertSym(lConstructionSuccessful,false);
                lSym:=Search_Struct_Member(ProcDef.struct,'AFTERCONSTRUCTION');
                if not Assigned(lSym) or
                   (lSym.typ<>ProcSym) then
                  InternalError(200305106);

                CurrentFilePos:=EntryPos;
                lConstructionBlock:=InternalStatements(lNewStatement);
                { initialise constructionsuccessful with -1, indicating that
                  the construction was not successful and hence
                  beforedestruction should not be called if a destructor is
                  called from the constructor }
                AddStatement(lNewStatement,CAssignmentNode.Create(
                  CLoadNode.Create(lConstructionSuccessful,ProcDef.LocalST),
                  GenIntConstNode(-1))
                );
                { first execute all constructor code. If no exception
                  occurred then we will execute afterconstruction,
                  otherwise we won't (the exception will jump over us) }
                AddStatement(lNewStatement,ACode);
                CurrentFilePos:=ExitPos;
                { if implicit finally node wasn't created, then exit label and
                  finalization code must be handled here and placed before
                  afterconstruction }
                if not ((pi_needs_implicit_finally in Flags) and
                  (cs_implicit_exceptions in CurrentSettings.ModuleSwitches)) then
                  begin
                    include(ACode.Flags,nf_block_with_exit);
                    if ProcDef.ProcTypeOption<>potype_exceptfilter then
                      AddStatement(lNewStatement,CFinalizeTempsNode.Create);
                    CNodeUtils.ProcDef_Block_Add_Implicit_Finalize_Nodes(ProcDef,lNewStatement);
                    TempsFinalized:=true;
                  end;

                { construction successful -> beforedestruction should be called
                  if an exception happens now }
                AddStatement(lNewStatement,CAssignmentNode.Create(
                  CLoadNode.Create(lConstructionSuccessful,ProcDef.LocalST),
                  GenIntConstNode(1))
                );
                { Self can be nil when fail is called }
                { if self<>nil and vmt<>nil then afterconstruction }
                AddStatement(lNewStatement,CIfNode.Create(
                  CAddNode.Create(andn,
                    CAddNode.Create(unequaln,
                      Load_Self_Node,
                      CNilNode.Create),
                    CAddNode.Create(unequaln,
                      Load_VMT_Pointer_Node,
                      CNilNode.Create)),
                    CCallNode.Create(nil,TProcSym(lSym),lSym.owner,Load_Self_Node,[],nil),
                    nil));
                ACode:=lConstructionBlock;
              end;

            if AWithExceptBlock and (ProcDef.struct.typ=objectdef) then
              begin
                { Generate the implicit "fail" code for a constructor (destroy
                  in case an exception happened) }
                lProcDef:=TObjectDef(ProcDef.struct).Find_Destructor;
                { this will always be the case for classes, since tobject has
                  a destructor }
                if Assigned(lProcDef) or Is_Object(ProcDef.struct) then
                  begin
                    CurrentFilePos:=ExitPos;
                    lExceptBlock:=InternalStatements(lNewStatement);
                    { first free the instance if non-nil }
                    if Assigned(lProcDef) then
                      { if vmt<>0 then call destructor }
                      AddStatement(lNewStatement,
                        CIfNode.Create(
                          CAddNode.Create(unequaln,
                            Load_VMT_Pointer_Node,
                            CNilNode.Create),
                          { cnf_create_failed -> don't call BeforeDestruction }
                          CCallNode.Create(nil,TProcSym(lProcDef.ProcSym),lProcDef.ProcSym.owner,Load_Self_Node,[cnf_create_failed],nil),
                          nil))
                    else
                      { object without destructor, call 'fail' helper }
                      AddStatement(lNewStatement,
                        CCallNode.CreateIntern('fpc_help_fail',
                          CCallParaNode.Create(
                            COrdConstNode.Create(TObjectDef(ProcDef.struct).VMT_Offset,S32IntType,false),
                          CCallParaNode.Create(
                            CTypeConvNode.Create_Internal(
                              Load_VMT_Pointer_Node,
                              VoidPointerType),
                          CCallParaNode.Create(
                            CTypeConvNode.Create_Internal(
                              Load_Self_Pointer_Node,
                              VoidPointerType),
                          nil))))
                      );
                    { then re-raise the exception }
                    AddStatement(lNewStatement,CRaiseNode.Create(nil,nil,nil));
                    CurrentFilePos:=EntryPos;
                    lNewBlock:=InternalStatements(lNewStatement);
                    { try
                        tocode
                      except
                        exceptblock
                      end
                    }
                    AddStatement(lNewStatement,CTryExceptNode.Create(
                      ACode,
                      nil,
                      lExceptBlock));
                    ACode:=lNewBlock;
                  end;
              end;
            CurrentSettings.LocalSwitches:=lOldLocalSwitches;
          end;
      end;


    procedure TCGProcInfo.AddEntryExitCode;
      var
        lFinalCode,
        lBodyEntryCode,
        lBodyExitCode,
        lWrappedBody,
        lNewBlock     : TNode;
        lCodeStatement,
        lNewStatement : TStatementNode;
        lOldFilePos   : TFilePosInfo;
        lIsConstructor: boolean;
      begin
        lIsConstructor:=Assigned(ProcDef.struct) and
          (ProcDef.ProcTypeOption=potype_constructor);

        lOldFilePos:=CurrentFilePos;
        { Generate code/locations used at start of proc }
        CurrentFilePos:=EntryPos;
        EntryAsmNode:=CAsmNode.Create_Get_Position;
        LoadParaAsmNode:=CAsmNode.Create_Get_Position;
        StackCheckAsmNode:=CAsmNode.Create_Get_Position;
        InitAsmNode:=CAsmNode.Create_Get_Position;
        lBodyEntryCode:=GenerateBodyEntryBlock;
        { Generate code/locations used at end of proc }
        CurrentFilePos:=ExitPos;
        ExitLabelAsmNode:=CAsmNode.Create_Get_Position;
        TempsFinalized:=false;
        lBodyExitCode:=GenerateBodyExitBlock;
        { Check if bodyexitcode is not empty }
        with TStatementNode(TBlockNode(lBodyExitCode).statements) do
          if (statement.nodetype<>nothingn) or Assigned(next) then
            { Indicate that the extra code is executed after the exit statement }
            include(flowcontrol,fc_no_direct_exit);

        { Generate procedure by combining init+body+final,
          depending on the implicit finally we need to add
          an try...finally...end wrapper }
        CurrentFilePos:=EntryPos;
        lNewBlock:=InternalStatements(lNewStatement);
        { Note - this is not strippable since it wraps the entire procedure }
        Exclude(TBlockNode(lNewBlock).BlockNodeFlags, bnf_strippable);
        { initialization is common for all cases }
        AddStatement(lNewStatement,LoadParaAsmNode);
        AddStatement(lNewStatement,StackCheckAsmNode);
        AddStatement(lNewStatement,EntryAsmNode);
        CNodeUtils.ProcDef_Block_Add_Implicit_Initialize_Nodes(ProcDef,lNewStatement);
        AddStatement(lNewStatement,InitAsmNode);
        if Assigned(ProcDef.ParentFPInitBlock) then
          begin
            if Assigned(TBlockNode(ProcDef.ParentFPInitBlock).left) then
              begin
                if CNodeUtils.Check_Insert_Trashing(ProcDef) then
                  CNodeUtils.Maybe_Trash_Variable(lNewStatement,TAbstractNormalVarSym(ProcDef.ParentFPStruct),CLoadNode.Create(ProcDef.ParentFPStruct,ProcDef.ParentFPStruct.owner));
                { could be an asmn in case of a pure assembler procedure,
                  but those shouldn't access nested variables }
                AddStatement(lNewStatement,ProcDef.ParentFPInitBlock);
              end
            else
              ProcDef.ParentFPInitBlock.free;
            ProcDef.ParentFPInitBlock:=nil;
          end;
        AddStatement(lNewStatement,lBodyEntryCode);

        if (cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and
           (pi_needs_implicit_finally in Flags) and
           { but it's useless in init/final code of units }
           not(ProcDef.ProcTypeOption in [potype_unitfinalize,potype_unitinit]) and
           (f_exceptions in Features) then
          begin
            { Any result of managed type must be returned in parameter }
            if Is_Managed_Type(ProcDef.ReturnDef) and
               (not ParaManager.Ret_In_Param(ProcDef.ReturnDef,ProcDef)) and
               (not Is_Class(ProcDef.ReturnDef)) then
               InternalError(2013121301);

            { Generate special exception block only needed when
              implicit finally is used }
            CurrentFilePos:=ExitPos;
            { Generate code that will be in the try...finally }
            lFinalCode:=InternalStatements(lCodeStatement);
            if ProcDef.ProcTypeOption<>potype_exceptfilter then
              AddStatement(lCodeStatement,CFinalizeTempsNode.Create);
            CNodeUtils.ProcDef_Block_Add_Implicit_Finalize_Nodes(ProcDef,lCodeStatement);
            TempsFinalized:=true;

            CurrentFilePos:=EntryPos;
            lWrappedBody:=CTryFinallyNode.Create_Implicit(Code,lFinalCode);
            { afterconstruction must be called after finalizetemps, because it
               has to execute after the temps have been finalised in case of a
               refcounted class (afterconstruction decreases the refcount
               without freeing the instance if the count becomes nil, while
               the finalising of the temps can free the instance) }
            MaybeAddConstructorWrapper(lWrappedBody,true);
            AddStatement(lNewStatement,lWrappedBody);
            AddStatement(lNewStatement,ExitLabelAsmNode);
            AddStatement(lNewStatement,lBodyExitCode);
            { set flag the implicit finally has been generated }
            include(Flags,pi_has_implicit_finally);
          end
        else
          begin
            { constructors need destroy-on-exception code even if they don't
              have managed variables/temps }
            MaybeAddConstructorWrapper(Code,
              (cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and (f_exceptions in Features));
            CurrentFilePos:=EntryPos;
            AddStatement(lNewStatement,Code);
            CurrentFilePos:=ExitPos;
            if Assigned(NestedExitLabel) then
              AddStatement(lNewStatement,CLabelNode.Create(CNothingNode.Create,NestedExitLabel));
            AddStatement(lNewStatement,ExitLabelAsmNode);
            AddStatement(lNewStatement,lBodyExitCode);
            if not lIsConstructor then
              begin
                if ProcDef.ProcTypeOption<>potype_exceptfilter then
                  AddStatement(lNewStatement,CFinalizeTempsNode.Create);
                CNodeUtils.ProcDef_Block_Add_Implicit_Finalize_Nodes(ProcDef,lNewStatement);
                TempsFinalized:=true;
              end;
          end;
        if not TempsFinalized then
          begin
            CurrentFilePos:=ExitPos;
            CNodeUtils.ProcDef_Block_Add_Implicit_Finalize_Nodes(ProcDef,lNewStatement);
          end;
        DoFirstPass(lNewBlock);
        Code:=lNewBlock;
        CurrentFilePos:=lOldFilePos;
      end;


    procedure ClearRefs(AObject:TObject;AArg:pointer);
      begin
         if (TSym(AObject).typ in [localvarsym,paravarsym,staticvarsym]) then
           if TAbstractVarSym(AObject).refs>1 then
             TAbstractVarSym(AObject).refs:=1;
      end;


    procedure TranslateRegisters(AObject:TObject;AList:pointer);
      begin
         if (TSym(AObject).typ in [localvarsym,paravarsym,staticvarsym]) and
            (TAbstractNormalVarSym(AObject).LocAlloc.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_MMREGISTER,
              LOC_CMMREGISTER,LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
           begin
             if not(cs_no_regalloc in CurrentSettings.GlobalSwitches) then
               begin
                 cg.Translate_Register(TAbstractNormalVarSym(AObject).LocAlloc.Register);
                 if (TAbstractNormalVarSym(AObject).LocAlloc.RegisterHi<>NR_NO) then
                   cg.Translate_Register(TAbstractNormalVarSym(AObject).LocAlloc.RegisterHi);
               end;
           end;
      end;


{$if defined(i386) or defined(x86_64) or defined(aarch64)}
    const
      exception_flags: array[boolean] of TProcInfoFlags = (
        [],
        [pi_uses_exceptions,pi_needs_implicit_finally,pi_has_implicit_finally]
      );
{$endif}

    procedure TCGProcInfo.SetupTempGen;
      begin
        TG:=TGObjClass.Create;

{$if defined(i386) or defined(x86_64) or defined(aarch64)}
          begin
            { try to strip the stack frame }
            { set the framepointer to esp if:
              - no assembler directive, those are handled in assembler_block
                in pstatment.pas (for cases not caught by the Delphi
                exception below)
              - no exceptions are used
              - no pushes are used/esp modifications, could be:
                * outgoing parameters on the stack on non-fixed stack target
                * incoming parameters on the stack
                * open arrays
              - no inline assembler
             or
              - Delphi mode
              - assembler directive
              - no pushes are used/esp modifications, could be:
                * outgoing parameters on the stack
                * incoming parameters on the stack
                * open arrays
              - no local variables

              - stack frame cannot be optimized if using Win64 SEH
                (at least with the current state of our codegenerator).
            }
            if ((po_assembler in ProcDef.ProcOptions) and
               (m_delphi in CurrentSettings.ModeSwitches) and
               { localst at main_program_level is a staticsymtable }
                (ProcDef.LocalST.SymTableLevel<>MainProgramLevel) and
                (TAbstractLocalSymTable(ProcDef.LocalST).Count_Locals = 0)) or
               ((cs_opt_stackframe in CurrentSettings.OptimizerSwitches) and
                not(cs_generate_stackframes in CurrentSettings.LocalSwitches) and
                not(po_assembler in ProcDef.ProcOptions) and
{$if defined(aarch64)}
               { on aarch64, it must be a leaf subroutine }
                not(pi_do_call in Flags) and
{$endif defined(aarch64)}
                not ((pi_has_stackparameter in Flags)
{$if defined(i386) or defined(x86_64)}
               { Outgoing parameter(s) on stack do not need stackframe on x86 targets
                 with fixed stack. On ARM it fails, see bug #25050 }
                  and (not ParaManager.Use_Fixed_Stack)
{$endif defined(i386) or defined(x86_64)}
                  ) and
                ((Flags*([pi_has_assembler_block,pi_is_assembler,
                        pi_needs_stackframe]+
                        exception_flags[((TargetInfo.cpu=cpu_i386) and (not ParaManager.Use_Fixed_Stack))
{$ifndef DISABLE_WIN64_SEH}
                        or (TargetInfo.system=system_x86_64_win64)
{$endif DISABLE_WIN64_SEH}
                        ]))=[])
               )
            then
              begin
                { we need the parameter info here to determine if the procedure gets
                  parameters on the stack

                  calling generate_parameter_info doesn't hurt but it costs time
                  (necessary to init para_stack_size)
                }
                Generate_Parameter_Info;

                if not(ProcDef.Stack_Tainting_Parameter(calleeside)) and
                   not(Has_Assembler_Child)
                  { parasize must be really zero, this means also that no result may be returned
                    in a parameter }
                  and not((CurrentProcInfo.ProcDef.ProcCallOption in ClearStack_PoCalls) and
                  not(CurrentProcInfo.ProcDef.Generate_SafeCall_Wrapper) and
                  ParaManager.Ret_In_Param(CurrentProcInfo.ProcDef.ReturnDef,CurrentProcInfo.ProcDef)) then
                  begin
                    { Only need to set the framepointer }
                    FramePointer:=NR_STACK_POINTER_REG;
                    TG.direction:=1;
                    Include(Flags,pi_no_framepointer_needed)
                  end
              end;
          end;
{$endif}
        { set the start offset to the start of the temp area in the stack }
        Set_First_Temp_Offset;
      end;


    procedure TCGProcInfo.TransformNodeTree;
      var
        lIndex : integer;
        lUserCode : TNode;
        lUpdated,
        lRedoDFA : boolean;
      begin
       { inlining is a heuristics, so we do this very early }
       do_optinline(Code,lUpdated);

       { do this before adding the entry code else the tail recursion recognition won't work,
         if this causes troubles, it must be if'ed
       }
       if (cs_opt_tailrecursion in CurrentSettings.OptimizerSwitches) and
         (pi_is_recursive in Flags) then
         do_opttail(Code,ProcDef);

       if cs_opt_constant_propagate in CurrentSettings.OptimizerSwitches then
         begin
           do_optconstpropagate(Code,lRedoDFA);
           { RedoDFA value not used here }
           lRedoDFA:=false;
         end;

       if (cs_opt_nodedfa in CurrentSettings.OptimizerSwitches) and
         { creating dfa is not always possible }
         ((Flags*[pi_has_assembler_block,pi_uses_exceptions,pi_is_assembler])=[]) then
         begin
           DFABuilder:=TDFABuilder.Create;
           DFABuilder.createdfainfo(Code);
           include(Flags,pi_dfaavailable);
           lRedoDFA:=false;

           if cs_opt_constant_propagate in CurrentSettings.OptimizerSwitches then
             begin
               do_optconstpropagate(Code,lRedoDFA);
               if lRedoDFA then
                 begin
                   DFABuilder.redodfainfo(Code);
                   lRedoDFA:=false; { Don't redo it again unless necessary }
                 end;
               { Don't re-run constant propagation as redoing DFA info didn't
                 actually change any nodes }
             end;

           if (cs_opt_loopstrength in CurrentSettings.OptimizerSwitches)
             { our induction variable strength reduction doesn't like
               for loops with more than one entry }
             and not(pi_has_label in Flags) then
             begin
               lRedoDFA:=OptimizeInductionVariables(Code);
             end;

           if lRedoDFA then
             begin
               DFABuilder.redodfainfo(Code);
               lRedoDFA:=false; { Don't redo it again unless necessary }
             end;

           if cs_opt_forloop in CurrentSettings.OptimizerSwitches then
             lRedoDFA:=OptimizeForLoop(Code);

           lRedoDFA:=ConvertForLoops(Code) or lRedoDFA;

           if cs_opt_forloop in CurrentSettings.OptimizerSwitches then
             lRedoDFA:=optimize_record_writes(Code) or lRedoDFA;

           if lRedoDFA then
             DFABuilder.redodfainfo(Code);

           { when life info is available, we can give more sophisticated warning about uninitialized
             variables ...
             ... but not for the finalization section of a unit, we would need global dfa to handle
             it properly }
           if potype_unitfinalize<>ProcDef.ProcTypeOption then
             { iterate through life info of the first node }
             for lIndex:=0 to DFABuilder.nodemap.count-1 do
               begin
                 lUserCode:=GetUserCode();
                 if DynSetIn(lUserCode.optinfo^.life,lIndex) then
                   begin
                     { do not warn for certain parameters: }
                     if not((TNode(DFABuilder.nodemap[lIndex]).nodetype=loadn) and (TLoadNode(DFABuilder.nodemap[lIndex]).SymTableEntry.typ=paravarsym) and
                       { do not warn about parameters passed by var }
                       (((TParaVarSym(TLoadNode(DFABuilder.nodemap[lIndex]).SymTableEntry).VarSpez=vs_var) and
                       { function result is passed by var but it must be initialized }
                       not(vo_is_funcret in TParaVarSym(TLoadNode(DFABuilder.nodemap[lIndex]).SymTableEntry).VarOptions)) or
                       { do not warn about initialized hidden parameters }
                       ((TParaVarSym(TLoadNode(DFABuilder.nodemap[lIndex]).SymTableEntry).VarOptions*[vo_is_high_para,vo_is_parentfp,vo_is_result,vo_is_self])<>[]))) then
                       CheckAndWarn(lUserCode,TNode(DFABuilder.nodemap[lIndex]));
                   end
                 else
                   begin
                     if (TNode(DFABuilder.nodemap[lIndex]).nodetype=loadn) and
                       (TLoadNode(DFABuilder.nodemap[lIndex]).SymTableEntry.typ in [staticvarsym,localvarsym]) then
                       TAbstractNormalVarSym(TLoadNode(DFABuilder.nodemap[lIndex]).SymTableEntry).NoRegVarInitNeeded:=true
                   end;
               end;

           if cs_opt_dead_store_eliminate in CurrentSettings.OptimizerSwitches then
             begin
               if normalize(Code) then
                 begin
                   do_optdeadstoreelim(Code,lRedoDFA);
                   if lRedoDFA then
                     DFABuilder.redodfainfo(Code);
                 end;
             end;
         end
       else
         begin
           ConvertForLoops(Code);
           if cs_opt_forloop in CurrentSettings.OptimizerSwitches then
             optimize_record_writes(Code);
         end;

       if (cs_opt_remove_empty_proc in CurrentSettings.OptimizerSwitches) and
         (ProcDef.ProcTypeOption in [potype_operator,potype_procedure,potype_function]) and
         (Code.nodetype=blockn) and (TBlockNode(Code).statements=nil) then
         ProcDef.isempty:=true;

       if cs_opt_nodecse in CurrentSettings.OptimizerSwitches then
         do_optcse(Code);

       if cs_opt_use_load_modify_store in CurrentSettings.OptimizerSwitches then
         do_optloadmodifystore(Code);

       if (cs_opt_consts in CurrentSettings.OptimizerSwitches) and
          { non-local gotos can cause an fpc_setjmp call to be generated before
            this block, which means the loaded value won't be loaded when the
             longjmp is performed }
          not(m_non_local_goto in CurrentSettings.ModeSwitches) then
         do_consttovar(Code);
      end;


    function TCGProcInfo.Has_Assembler_Child : boolean;
      var
        lProcInfo : TProcInfo;
      begin
        Result:=false;
        lProcInfo:=Get_First_NestedProc;
        while Assigned(lProcInfo) do
          begin
            if (lProcInfo.Flags*[pi_has_assembler_block,pi_is_assembler])<>[] then
              begin
                Result:=true;
                exit;
              end;
            lProcInfo:=TProcInfo(lProcInfo.next);
          end;
      end;


    procedure TCGProcInfo.Set_EH_Info;
      begin
        inherited;
         if (tf_use_psabieh in TargetInfo.Flags) and
            ((pi_uses_exceptions in Flags) or
             ((cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and
              (pi_needs_implicit_finally in Flags))) or
             (pi_has_except_table_data in Flags) then
           ProcDef.Personality:=Search_System_Proc('_FPC_PSABIEH_PERSONALITY_V0');
      end;


    function TCGProcInfo.StoreNodeTempFlags(var ANode: TNode; AArg: pointer): TForEachNodeResult;
      var
        lNodeSet : THashSet absolute AArg;
        lEntry : PTempInfoFlagsEntry;
        lIndex : LongInt;
        {hashsetitem: PHashSetItem;}
      begin
        Result:=fen_true;
        case ANode.nodetype of
          tempcreaten:
            begin
              {$ifdef EXTDEBUG}
              comment(VDebug,'keeping track of new temp node: '+HexStr(TTempBaseNode(ANode).TempInfo));
              {$endif EXTDEBUG}
              lNodeSet.FindOrAdd(TTempBaseNode(ANode).TempInfo,sizeof(pointer));
            end;
          tempdeleten:
            begin
              {$ifdef EXTDEBUG}
              comment(VDebug,'got temp delete node: '+HexStr(TTempBaseNode(ANode).TempInfo));
              {$endif EXTDEBUG}
              { don't remove temp nodes so that outside code can know if some temp
                was only created in here }
              (*hashsetitem:=nodeset.find(ttempbasenode(n).tempinfo,sizeof(pointer));
              if assigned(hashsetitem) then
                begin
                  {$ifdef EXTDEBUG}
                  comment(V_Debug,'no longer keeping track of temp node');
                  {$endif EXTDEBUG}
                  writeln('no longer keeping track of temp node');
                  nodeset.Remove(hashsetitem);
                end;*)
            end;
          temprefn:
            begin
              {$ifdef EXTDEBUG}
              comment(VDebug,'found temp ref node: '+HexStr(TTempBaseNode(ANode).TempInfo));
              {$endif EXTDEBUG}
              if not Assigned(lNodeSet.find(TTempBaseNode(ANode).TempInfo,sizeof(pointer))) then
                begin
                  for lIndex:=0 to FTempInfoFlagsMap.count-1 do
                    begin
                      lEntry:=PTempInfoFlagsEntry(FTempInfoFlagsMap[lIndex]);
                      {$ifdef EXTDEBUG}
                      comment(VDebug,'comparing with tempinfo: '+HexStr(lEntry^.TempInfo));
                      {$endif EXTDEBUG}
                      if lEntry^.TempInfo=TTempBaseNode(ANode).TempInfo then
                        begin
                          {$ifdef EXTDEBUG}
                          comment(VDebug,'temp node exists');
                          {$endif EXTDEBUG}
                          exit;
                        end;
                    end;
                  {$ifdef EXTDEBUG}
                  comment(VDebug,'storing node');
                  {$endif EXTDEBUG}
                  new(lEntry);
                  lEntry^.TempInfo:=TTempBaseNode(ANode).TempInfo;
                  lEntry^.Flags:=TTempInfoAccessor.GetTempInfoFlags(lEntry^.TempInfo);
                  FTempInfoFlagsMap.add(lEntry);
                end
              else
                begin
                  {$ifdef EXTDEBUG}
                  comment(VDebug,'ignoring node');
                  {$endif EXTDEBUG}
                end;
            end;
          else
            ;
        end;
      end;


    procedure TCGProcInfo.Store_TempFlags;
      var
        lNodeSet : THashSet;
      begin
        if Assigned(FTempInfoFlagsMap) then
          InternalError(2020040601);
        {$ifdef EXTDEBUG}
        comment(VDebug,'storing temp nodes of '+ProcDef.MangledName);
        {$endif EXTDEBUG}
        FTempInfoFlagsMap:=TFPList.Create;
        lNodeSet:=THashSet.Create(32,false,false);
        ForEachNode(Code,@StoreNodeTempFlags,lNodeSet);
        lNodeSet.free;
        lNodeSet := nil;
      end;


    procedure TCGProcInfo.SwapTempFlags;
      var
        lEntry : PTempInfoFlagsEntry;
        lIndex : LongInt;
        lTempFlags : TTempInfoFlags;
      begin
        if not Assigned(FTempInfoFlagsMap) then
          exit;
        for lIndex:=0 to FTempInfoFlagsMap.count-1 do
          begin
            lEntry:=PTempInfoFlagsEntry(FTempInfoFlagsMap[lIndex]);
            lTempFlags:=TTempInfoAccessor.GetTempInfoFlags(lEntry^.TempInfo);
            TTempInfoAccessor.SetTempInfoFlags(lEntry^.TempInfo,lEntry^.Flags);
            lEntry^.Flags:=lTempFlags;
          end;
      end;


    procedure TCGProcInfo.Apply_TempFlags;
      begin
        if FTempFlagsSwapped then
          InternalError(2020040602);
        SwapTempFlags;
        FTempFlagsSwapped:=true;
      end;


    procedure TCGProcInfo.Reset_TempFlags;
      begin
        if not FTempFlagsSwapped then
          InternalError(2020040603);
        SwapTempFlags;
        FTempFlagsSwapped:=false;
      end;



    procedure TCGProcInfo.Generate_Code_Tree;
      var
        lProcInfo : TCGProcInfo;
      begin
        { generate code for this procedure }
        Generate_Code;
        { process nested procedures }
        lProcInfo:=TCGProcInfo(Get_First_NestedProc);
        while Assigned(lProcInfo) do
          begin
            if not (df_generic in lProcInfo.ProcDef.DefOptions) then
              lProcInfo.Generate_Code_Tree;
            lProcInfo:=TCGProcInfo(lProcInfo.next);
          end;
        ResetProcDef;
      end;


    procedure TCGProcInfo.Generate_Code_ExceptFilters;
      var
        lProcInfo : TCGProcInfo;
      begin
        { On AArch64-Win64, exceptfilter code generation is deferred (after the
          parent's prolog has been emitted). Record the parent's current lasttemp
          so that adjust_exceptfilter_ref can distinguish parent temps (which must
          be converted to FP-relative) from handler temps (which stay SP-relative
          in the handler's own stack frame). Also discard the TG free list to
          prevent handler temps from reusing freed parent param/local slots,
          which would cause collisions with still-live parent data. }
        if TargetInfo.system=system_aarch64_win64 then
          begin
            ExceptFilterParentTempEnd:=TG.LastTemp;
            TG.Discard_FreeList;
          end;
        lProcInfo:=TCGProcInfo(Get_First_NestedProc);
        while Assigned(lProcInfo) do
          begin
            if (lProcInfo.ProcDef.ProcTypeOption=potype_exceptfilter) and
               Assigned(lProcInfo.Code) then
              begin
                lProcInfo.Apply_TempFlags;
                Generate_ExceptFilter(lProcInfo);
                lProcInfo.Reset_TempFlags;
              end;
            lProcInfo:=TCGProcInfo(lProcInfo.next);
          end;
      end;

    { For SEH, the code from 'finally' blocks must be put into a separate procedures,
      which can be called by OS during stack unwind. This resembles nested procedures,
      but finalizer procedures do not have their own local variables and work directly
      with the stack frame of parent. In particular, the tempgen must be shared, so
      1) finalizer procedure is able to finalize temps of the parent,
      2) if the finalizer procedure is complex enough to need its own temps, they are
         allocated in stack frame of parent, so second-level finalizer procedures are
         not needed.

      Due to requirement of shared tempgen we cannot process finalizer as a regular nested
      procedure (after the parent) and have to do it inline.
      This is called by platform-specific tryfinallynodes during pass2.
      Here we put away the codegen (which carries the register allocator state), process
      the 'nested' procedure, then restore previous cg and continue processing the parent
      procedure. generate_code() will create another cg, but not another tempgen because
      setup_tempgen() is not called for potype_exceptfilter procedures. }

    procedure TCGProcInfo.Generate_ExceptFilter(ANestedProcInfo: TCGProcInfo);
      var
        lSavedCG: TCG;
        lSavedHLCG: THLCGObj;
{$ifdef cpu64bitalu}
        lSavedCG128 : TCG128;
{$else cpu64bitalu}
        lSavedCG64 : TCG64;
{$endif cpu64bitalu}
      begin
        if ANestedProcInfo.ProcDef.ProcTypeOption<>potype_exceptfilter then
          InternalError(201201141);
        { flush code generated this far }
        AktProcCode.ConcatList(CurrentAsmData.CurrAsmList);
        { save the codegen }
        lSavedCG:=cg;
        lSavedHLCG:=hlcg;
        cg:=nil;
        hlcg:=nil;
{$ifdef cpu64bitalu}
        lSavedCG128:=cg128;
        cg128:=nil;
{$else cpu64bitalu}
        lSavedCG64:=cg64;
        cg64:=nil;
{$endif cpu64bitalu}
        ANestedProcInfo.Generate_Code;
        { prevents generating code the second time when processing nested procedures }
        ANestedProcInfo.ResetProcDef;
        cg:=lSavedCG;
        hlcg:=lSavedHLCG;
{$ifdef cpu64bitalu}
        cg128:=lSavedCG128;
{$else cpu64bitalu}
        cg64:=lSavedCG64;
{$endif cpu64bitalu}
        Add_Reg_Instruction_Hook:=@cg.Add_Reg_Instruction;
      end;


    procedure TCGProcInfo.Generate_Exit_Label(AList: TAsmList);
      begin
        hlcg.A_Label(AList,CurrExitLabel);
      end;


    procedure TCGProcInfo.ConvertCapturedSyms;
      var
        lProcInfo : TCGProcInfo;
        lOldCurrentProcInfo : TProcInfo;
      begin
        { do the conversion only if there haven't been any errors so far }
        if ErrorCount<>0 then
          exit;
        lOldCurrentProcInfo:=CurrentProcInfo;
        CurrentProcInfo:=self;
        { process nested procedures }
        lProcInfo:=TCGProcInfo(Get_First_NestedProc);
        while Assigned(lProcInfo) do
          begin
            lProcInfo.ConvertCapturedSyms;
            lProcInfo:=TCGProcInfo(lProcInfo.next);
          end;
        { convert the captured symbols for this routine }
        if Assigned(Code) then
          procdefutil.Convert_Captured_Syms(ProcDef,Code);
        CurrentProcInfo:=lOldCurrentProcInfo;
      end;


     procedure TCGProcInfo.CreateInlineInfo;
       begin
        new(ProcDef.InliningInfo);
        ProcDef.InliningInfo^.Code:=Code.GetCopy;
        ProcDef.InliningInfo^.Flags:=Flags;
        { The blocknode needs to set an exit label }
        if ProcDef.InliningInfo^.Code.nodetype=blockn then
          include(ProcDef.InliningInfo^.Code.Flags,nf_block_with_exit);
        ProcDef.HasInliningInfo:=true;
        Export_Local_Ref_Syms;
        Export_Local_Ref_Defs;
       end;

    procedure SearchThreadVar(AObject: TObject; AArg: pointer);
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
              if (vo_is_thread_var in TStaticVarSym(AObject).VarOptions) and
                 ((TStaticVarSym(AObject).refs>0) or
                  { global (unit) variables always need finalization, since
                    they may also be used in another unit
                  }
                  (TStaticVarSym(AObject).owner.SymTableType=GlobalSymTable)) and
                  (
                    (TStaticVarSym(AObject).VarSpez<>vs_const) or
                    (vo_force_finalize in TStaticVarSym(AObject).VarOptions)
                  ) and
                 not(vo_is_funcret in TStaticVarSym(AObject).VarOptions) and
                 not(vo_is_external in TStaticVarSym(AObject).VarOptions) and
                 Is_Managed_Type(TStaticVarSym(AObject).vardef) then
                include(CurrentProcInfo.Flags,pi_uses_threadvar);
            end;
          ProcSym :
            begin
              for lIndex:=0 to TProcSym(AObject).ProcdefList.Count-1 do
                begin
                  lProcDef:=TProcDef(TProcSym(AObject).ProcdefList[lIndex]);
                  if Assigned(lProcDef.LocalST) and
                     (lProcDef.ProcSym=TProcSym(AObject)) and
                     (lProcDef.LocalST.SymTableType<>staticsymtable) then
                    lProcDef.LocalST.SymList.ForEachCall(@SearchThreadVar,AArg);
                end;
            end;
          else
            ;
        end;
      end;


    function SearchUserCode(var ANode: TNode; AArg: pointer): TForEachNodeResult;
      begin
        if nf_usercode_entry in ANode.Flags then
          begin
            PNode(AArg)^:=ANode;
            Result:=fen_norecurse_true
          end
        else
          Result:=fen_false;
      end;


    function TCGProcInfo.GetUserCode : TNode;
      var
        lNode : TNode;
      begin
        lNode:=nil;
        ForEachNodeStatic(Code,@SearchUserCode,@lNode);
        if not(Assigned(lNode)) then
          InternalError(2013111004);
        Result:=lNode;
      end;


    procedure TCGProcInfo.Generate_Code;

       procedure CheckForThreadVarsInInitFinal;
         begin
           if CurrentProcInfo.ProcDef.ProcTypeOption=potype_unitfinalize then
             begin
                { this is also used for initialization of variables in a
                  program which does not have a globalsymtable }
                if Assigned(CurrentModule.GlobalSymTable) then
                  TSymTable(CurrentModule.GlobalSymTable).SymList.ForEachCall(@SearchThreadVar,nil);
                TSymTable(CurrentModule.LocalSymTable).SymList.ForEachCall(@SearchThreadVar,nil);
             end;
         end;

       function HeuristicsFavorsAutoInlining(ACode: TNode): boolean;
         var
           lComplexityAvailable : integer;
         begin
           { rough approximation if we should auto inline:
             - if the tree is simple enough
             - if the tree is not too big
             A bigger tree which is simpler might be autoinlined otoh
             a smaller and complexer tree as well: so we use the sum of
             both measures here }

           { This is a shortcutted version of
             "result:=node_count(code)+node_complexity(code)<=25". }
           lComplexityAvailable:=25-Node_Complexity(ACode);
           Result:=(lComplexityAvailable>0) and (Node_Count(ACode,lComplexityAvailable+1)<=dword(lComplexityAvailable));
         end;

      var
        lOldCurrentProcInfo : TProcInfo;
        lOldMaxFPURegisters : LongInt;
        lOldFilePos : TFilePosInfo;
        lOldCurrentStructDef : TAbstractRecordDef;
        lOldSwitches : TLocalSwitches;
        lTempList : TAsmList;
        lHeaderTAI : TAI;

      procedure DeleteMarker(ANode: TAsmNode);
        var
          lInstruction: TAI;
        begin
          if Assigned(ANode) then
            begin
              lInstruction:=ANode.CurrentTAI;
              if Assigned(lInstruction) then
                begin
                  AktProcCode.remove(lInstruction);
                  lInstruction.free;
                  lInstruction := nil;
                  ANode.CurrentTAI:=nil;
                end;
            end;
        end;

      begin
        { the initialization procedure can be empty, then we
          don't need to generate anything. When it was an empty
          procedure there would be at least a blocknode }
        if not Assigned(Code) then
          begin
            exit;
          end;

        { We need valid code }
        if ErrorCount<>0 then
          exit;

        { No code can be generated for generic template }
        if (df_generic in ProcDef.DefOptions) then
          InternalError(200511152);

        { For regular procedures the RA and Tempgen shall not be available yet,
          but exception filters reuse Tempgen of parent }
        if Assigned(TG)<>(ProcDef.ProcTypeOption=potype_exceptfilter) then
          InternalError(200309201);

        lOldCurrentProcInfo:=CurrentProcInfo;
        lOldFilePos:=CurrentFilePos;
        lOldCurrentStructDef:=CurrentStructDef;
        lOldMaxFPURegisters:=CurrentSettings.MaxFPURegisters;

        CurrentProcInfo:=self;
        CurrentFilePos:=EntryPos;
        CurrentStructDef:=ProcDef.struct;

        { store start of user code, it must be a block node, it will be used later one to
          check variable lifeness }
        include(Code.Flags,nf_usercode_entry);

        { add wrapping code if necessary (initialization of typed constants on
          some platforms, initing of local variables and out parameters with
          trashing values, ...) }
        { init/final code must be wrapped later (after code for main proc body
          has been generated) }
        if not(CurrentProcInfo.ProcDef.ProcTypeOption in [potype_unitinit,potype_unitfinalize]) then
          Code:=CNodeUtils.Wrap_Proc_Body(ProcDef,Code);

        { automatic inlining? }
        if (cs_opt_autoinline in CurrentSettings.OptimizerSwitches) and
           not(po_noinline in ProcDef.ProcOptions) and
           { no inlining yet? }
           not(ProcDef.HasInliningInfo) and not(Has_NestedProcs) and
            not(ProcDef.ProcTypeOption in [potype_proginit,potype_unitinit,potype_unitfinalize,potype_constructor,
                                           potype_destructor,potype_class_constructor,potype_class_destructor]) and
            ((ProcDef.ProcOptions*[po_exports,po_external,po_interrupt,po_virtualmethod,po_iocheck])=[]) and
            (not(ProcDef.ProcCallOption in [pocall_safecall])) and
            HeuristicsFavorsAutoInlining(Code) then
          begin
            { Can we inline this procedure? }
            if CheckNodeInlining(ProcDef) then
              begin
                Message1(cg_d_autoinlining,ProcDef.GetTypeName);
                include(ProcDef.ProcOptions,po_inline);
                CreateInlineInfo;
              end;
          end;

        lTempList:=TAsmList.Create;

        { add parast/localst to symtablestack }
        Add_To_SymTableStack;

        { clear register count }
        ProcDef.LocalST.SymList.ForEachCall(@ClearRefs,nil);
        ProcDef.ParaST.SymList.ForEachCall(@ClearRefs,nil);

        { there's always a call to FPC_INITIALIZEUNITS/FPC_DO_EXIT in the main program }
        if (ProcDef.LocalST.SymTableLevel=MainProgramLevel) and
           (not CurrentModule.IsUnit) then
          begin
            include(Flags,pi_do_call);
            { the main program never returns due to the do_exit call }
            if not(CurrentModule.IsLibrary) and (ProcDef.ProcTypeOption=potype_proginit) then
              include(ProcDef.ProcOptions,po_noreturn);
          end;

        { set implicit_finally flag when there are locals/paras to be finalized }
        if not(po_assembler in CurrentProcInfo.ProcDef.ProcOptions) then
          begin
            ProcDef.ParaST.SymList.ForEachCall(@CheckFinalizeParas,nil);
            ProcDef.LocalST.SymList.ForEachCall(@CheckFinalizeLocals,nil);
          end;

{$ifdef SUPPORT_SAFECALL}
        { set implicit_finally flag for if procedure is safecall }
        if (tf_safecall_exceptions in TargetInfo.Flags) and
           (ProcDef.ProcCallOption=pocall_safecall) then
          include(Flags, pi_needs_implicit_finally);
{$endif}

        { firstpass everything }
        flowcontrol:=[];
        DoFirstPass(Code);

{$if defined(i386)}
        if Node_Resources_FPU(Code)>0 then
          include(Flags,pi_uses_fpu);
{$endif i386}

        { Print the node to tree.log }
        if ParaPrintNodeTree <> 0 then
          PrintProc( 'after the firstpass');

        { A failed first pass can leave unresolved helper calls in the tree. }
        if ErrorCount=0 then
          TransformNodeTree;

        { unit static/global symtables might contain threadvars which are not explicitly used but which might
          require a tls register, so check for such variables }
        CheckForThreadVarsInInitFinal;

        { add implicit entry and exit code }
        AddEntryExitCode;

        { only do secondpass if there are no errors }
        if (ErrorCount<>0) then
          begin
          end
        else
          begin
            Create_HLCodeGen(nil);

            Setup_EH;

            if (ProcDef.ProcTypeOption<>potype_exceptfilter) then
              SetupTempGen;

            { Create register allocator, must come after framepointer is known }
            hlcg.Init_Register_Allocators;

            Generate_Parameter_Info;

            { allocate got register if needed }
            Allocate_GOT_Register(AktProcCode);

            { allocate got register if needed }
            Allocate_TLS_Register(AktProcCode);

            { Allocate space in temp/registers for parast and localst }
            CurrentFilePos:=EntryPos;
            Gen_Alloc_SymTable(AktProcCode,ProcDef,ProcDef.ParaST);
            Gen_Alloc_SymTable(AktProcCode,ProcDef,ProcDef.LocalST);

            { Store temp offset for information about 'real' temps }
            TempStart:=TG.LastTemp;

            { Generate code to load register parameters in temps and insert local
              copies for values parameters. This must be done before the code for the
              body is generated because the localloc is updated.
              Note: The generated code will be inserted after the code generation of
              the body is finished, because only then the position is known }
            CurrentFilePos:=EntryPos;

            hlcg.Gen_Load_Para_Value(lTempList);

            { caller paraloc info is also necessary in the stackframe_entry
              code of the ppc (and possibly other processors)               }
            ProcDef.Init_ParaLoc_Info(callerside);

            CalcExecutionWeights(Code);

            { Print the node to tree.log }
            if ParaPrintNodeTree <> 0 then
              PrintProc( 'right before code generation');


            { generate code for the node tree }
            DoSecondPass(Code);
            AktProcCode.ConcatList(CurrentAsmData.CurrAsmList);

            { The position of the loadpara_asmnode is now known }
            AktProcCode.InsertListAfter(LoadParaAsmNode.CurrentTAI,lTempList);

            lOldSwitches:=CurrentSettings.LocalSwitches;

            { first generate entry and initialize code with the correct
              position and switches }
            CurrentFilePos:=EntryPos;
            CurrentSettings.LocalSwitches:=EntrySwitches;

            cg.Set_RegAlloc_Live_Range_Direction(rad_backwards);

            hlcg.Gen_Entry_Code(lTempList);
            AktProcCode.InsertListAfter(EntryAsmNode.CurrentTAI,lTempList);
            hlcg.Gen_Initialize_Code(lTempList);
            AktProcCode.InsertListAfter(InitAsmNode.CurrentTAI,lTempList);

            { now generate finalize and exit code with the correct position
              and switches }
            CurrentFilePos:=ExitPos;
            CurrentSettings.LocalSwitches:=ExitSwitches;

            cg.Set_RegAlloc_Live_Range_Direction(rad_forward);

            if Assigned(FinalizeProcInfo) then
              begin
                if TargetInfo.system in [system_aarch64_win64] then
                  TCGProcInfo(FinalizeProcInfo).Store_TempFlags
                else
                  Generate_ExceptFilter(TCGProcInfo(FinalizeProcInfo));
              end
            else if not TempsFinalized then
              begin
                hlcg.Gen_Finalize_Code(lTempList);
                { the finalcode must be concatenated if there was no position available,
                  using insertlistafter will result in an insert at the start
                  when currentai=nil }
                AktProcCode.ConcatList(lTempList);
              end;
            { insert exit label at the correct position }
            Generate_Exit_Label(lTempList);
            if Assigned(ExitLabelAsmNode.CurrentTAI) then
              AktProcCode.InsertListAfter(ExitLabelAsmNode.CurrentTAI,lTempList)
            else
              AktProcCode.ConcatList(lTempList);
            { exit code }
            hlcg.Gen_Exit_Code(lTempList);
            AktProcCode.ConcatList(lTempList);

            { reset switches }
            CurrentSettings.LocalSwitches:=lOldSwitches;

            { generate symbol and save end of header position }
            CurrentFilePos:=EntryPos;
            hlcg.Gen_Proc_Symbol(lTempList);
            lHeaderTAI:=TAI(lTempList.last);
            { insert symbol }
            AktProcCode.InsertList(lTempList);

            { Free space in temp/registers for parast and localst, must be
              done after gen_entry_code }
            CurrentFilePos:=ExitPos;

            { make sure the got/pic register doesn't get freed in the }
            { middle of a loop                                        }
            if (tf_pic_uses_got in TargetInfo.Flags) and
              (pi_needs_got in Flags) and
              (got<>NR_NO) then
              cg.A_Reg_Sync(AktProcCode,got);

            if (pi_needs_tls in Flags) and
              (TLSOffset<>NR_NO) then
              cg.A_Reg_Sync(AktProcCode,TLSOffset);

            Gen_Free_SymTable(AktProcCode,ProcDef.LocalST);
            Gen_Free_SymTable(AktProcCode,ProcDef.ParaST);

            { add code that will load the return value, this is not done
              for assembler routines when they didn't reference the result
              variable }
            hlcg.Gen_Load_Return_Value(lTempList);
            AktProcCode.ConcatList(lTempList);

            { Already reserve all registers for stack checking code and
              generate the call to the helper function }
            if not(tf_no_generic_stackcheck in TargetInfo.Flags) and
               (cs_check_stack in EntrySwitches) and
               not(po_assembler in ProcDef.ProcOptions) and
               (ProcDef.ProcTypeOption<>potype_proginit) then
              begin
                CurrentFilePos:=EntryPos;
                hlcg.Gen_Stack_Check_Call(lTempList);
                AktProcCode.InsertListAfter(StackCheckAsmNode.CurrentTAI,lTempList);
              end;

            { this code (got loading) comes before everything which has }
            { already been generated, so reset the info about already   }
            { backwards extended registers (so their live range can be  }
            { extended backwards even further if needed)                }
            { This code must be                                         }
            {  a) generated after do_secondpass has been called         }
            {     (because pi_needs_got may be set there)               }
            {  b) generated before register allocation, because the     }
            {     got/pic register can be a virtual one                 }
            {  c) inserted before the entry code, because the entry     }
            {     code may need global symbols such as init rtti        }
            {  d) inserted after the stackframe allocation, because     }
            {     this register may have to be spilled                  }
            cg.Set_RegAlloc_Live_Range_Direction(rad_backwards_reinit);
            CurrentFilePos:=EntryPos;
            { load got if necessary }
            cg.G_Maybe_Got_Init(lTempList);
            AktProcCode.InsertListAfter(lHeaderTAI,lTempList);

            { init tls if needed }
            cg.G_Maybe_TLS_Init(lTempList);
            AktProcCode.InsertListAfter(StackCheckAsmNode.CurrentTAI,lTempList);

            { re-enable if more code at the end is ever generated here
            cg.set_regalloc_live_range_direction(rad_forward);
            }


{$ifndef NoOpt}
{$ifndef i386}
            if (cs_opt_scheduler in CurrentSettings.OptimizerSwitches) and
              { do not optimize pure assembler procedures }
              not(pi_is_assembler in Flags) then
              preregallocschedule(AktProcCode);
{$endif i386}
{$endif NoOpt}

            { The procedure body is finished, we can now
              allocate the registers }
            cg.Do_Register_Allocation(AktProcCode,lHeaderTAI);

            { translate imag. register to their real counter parts
              this is necessary for debuginfo and verbose assembler output
              when SSA will be implemented, this will be more complicated because we've to
              maintain location lists }
            ProcDef.ParaST.SymList.ForEachCall(@TranslateRegisters,lTempList);
            ProcDef.LocalST.SymList.ForEachCall(@TranslateRegisters,lTempList);
            if (tf_pic_uses_got in TargetInfo.Flags) and (pi_needs_got in Flags) and
               not(cs_no_regalloc in CurrentSettings.GlobalSwitches) and
               (got<>NR_NO) then
              cg.Translate_Register(got);

            { Add save and restore of used registers }
            CurrentFilePos:=EntryPos;
            Gen_Save_Used_Regs(lTempList);
            { Remember the last instruction of register saving block
              (may be =nil for e.g. assembler procedures) }
            EndPrologueAI:=lTempList.last;
            AktProcCode.InsertListAfter(lHeaderTAI,lTempList);
            CurrentFilePos:=ExitPos;
            Gen_Restore_Used_Regs(AktProcCode);
            { We know the size of the stack, now we can generate the
              parameter that is passed to the stack checking code }
            if not(tf_no_generic_stackcheck in TargetInfo.Flags) and
               (cs_check_stack in EntrySwitches) and
               not(po_assembler in ProcDef.ProcOptions) and
               (ProcDef.ProcTypeOption<>potype_proginit) then
              begin
                CurrentFilePos:=EntryPos;
                hlcg.Gen_Stack_Check_Size_Para(lTempList);
                AktProcCode.InsertListAfter(StackCheckAsmNode.CurrentTAI,lTempList)
              end;

            CurrentProcInfo.Set_EH_Info;

            { Add entry code (stack allocation) after header }
            CurrentFilePos:=EntryPos;
            Gen_Proc_Entry_Code(lTempList);
            AktProcCode.InsertListAfter(lHeaderTAI,lTempList);
{$ifdef SUPPORT_SAFECALL}
            { Set return value of safecall procedure if implicit try/finally blocks are disabled }
            if not (cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and
               (tf_safecall_exceptions in TargetInfo.Flags) and
               (ProcDef.ProcCallOption=pocall_safecall) then
              cg.A_Load_Const_Reg(AktProcCode,OS_ADDR,0,NR_FUNCTION_RETURN_REG);
{$endif}
            { Add exit code at the end }
            CurrentFilePos:=ExitPos;
            Gen_Proc_Exit_Code(lTempList);
            AktProcCode.ConcatList(lTempList);

            { check if the implicit finally has been generated. The flag
              should already be set in pass1 }
            if (cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and
               not(ProcDef.ProcTypeOption in [potype_unitfinalize,potype_unitinit]) and
               (pi_needs_implicit_finally in Flags) and
               not(pi_has_implicit_finally in Flags) then
             InternalError(200405231);

             { sanity check }
             if not(Assigned(CurrentProcInfo.ProcDef.Personality)) and
                (tf_use_psabieh in TargetInfo.Flags) and
                ((pi_uses_exceptions in Flags) or
                 ((cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and
                  (pi_needs_implicit_finally in Flags))) then
               InternalError(2019021005);

            { Position markers are only used to insert additional code after the secondpass
              and before this point. They are of no use in optimizer. Instead of checking and
              ignoring all over the optimizer, just remove them here. }
            DeleteMarker(EntryAsmNode);
            DeleteMarker(LoadParaAsmNode);
            DeleteMarker(ExitLabelAsmNode);
            DeleteMarker(StackCheckAsmNode);
            DeleteMarker(InitAsmNode);

{$ifndef NoOpt}
            if not(cs_no_regalloc in CurrentSettings.GlobalSwitches) then
              begin
                if (cs_opt_level1 in CurrentSettings.OptimizerSwitches) and
                   { do not optimize pure assembler procedures }
                   not(pi_is_assembler in Flags)  then
                  optimize(AktProcCode);
{$ifndef i386}
                { schedule after assembler optimization, it could have brought up
                  new schedule possibilities }
                if (cs_opt_scheduler in CurrentSettings.OptimizerSwitches) and
                  { do not optimize pure assembler procedures }
                  not(pi_is_assembler in Flags)  then
                  preregallocschedule(AktProcCode);
{$endif i386}
              end;
{$endif NoOpt}

            { Perform target-specific processing if necessary }
            PostProcess_Code;

            { Add end symbol and debug info }
            { this must be done after the pcrelativedata is appended else the distance calculation of
              insertpcrelativedata will be wrong, further the pc indirect data is part of the procedure
              so it should be inserted before the end symbol (FK)
            }
            CurrentFilePos:=ExitPos;
            hlcg.Gen_Proc_Symbol_End(lTempList);
            AktProcCode.ConcatList(lTempList);

            { insert line debuginfo }
            if (cs_debuginfo in CurrentSettings.ModuleSwitches) or
               (cs_use_lineinfo in CurrentSettings.GlobalSwitches) then
             begin
               { We only do this after the code generated because
                 otherwise for-loop counters moved to the struct cause
                 errors. And doing it before optimisation passes have run
                 causes problems when they manually look up symbols
                 like result and self (nutils.load_self_node etc). Still
                 do it nevertheless to to assist debug info generation
                 (hide original symbols, add absolutevarsyms that redirect
                  to their new locations in the parentfpstruct) }
              if Assigned(CurrentProcInfo.ProcDef.ParentFPStruct) then
                Redirect_ParentFPStruct_Local_Syms(CurrentProcInfo.ProcDef);
              CurrentDebugInfo.insertlineinfo(AktProcCode);
             end;

            Finish_EH;

            hlcg.Record_Generated_Code_For_ProcDef(CurrentProcInfo.ProcDef,AktProcCode,AktLocalData);

            { now generate code for any exception filters (they need the tempgen) }
            Generate_Code_ExceptFilters;

            { only now we can remove the temps }
            if (ProcDef.ProcTypeOption<>potype_exceptfilter) then
              begin
                TG.ResetTempGen;
                TG.free;
                TG:=nil;
              end;
            { stop tempgen and ra }
            hlcg.Done_Register_Allocators;
            Destroy_HLCodeGen;
          end;

        DFABuilder.free;
        DFABuilder := nil;

        { restore symtablestack }
        Remove_From_SymTableStack;

        { restore }
        lTempList.free;
        lTempList := nil;
        CurrentSettings.MaxFPURegisters:=lOldMaxFPURegisters;
        CurrentFilePos:=lOldFilePos;
        CurrentStructDef:=lOldCurrentStructDef;
        CurrentProcInfo:=lOldCurrentProcInfo;
      end;


    procedure TCGProcInfo.Add_To_SymTableStack;
      begin
        { insert symtables for the class, but only if it is no nested function }
        if Assigned(ProcDef.struct) and
           not(Assigned(Parent) and
               Assigned(Parent.ProcDef) and
               Assigned(Parent.ProcDef.struct)) then
          push_nested_hierarchy(ProcDef.struct);

        { insert parasymtable in symtablestack when parsing
          a function }
        if ProcDef.ParaST.SymTableLevel>=NormalFunctionLevel then
          SymTableStack.push(ProcDef.ParaST);

        { insert localsymtable, except for the main procedure
          (in that case the localst is the unit's static symtable,
           which is already on the stack) }
        if ProcDef.LocalST.SymTableLevel>=NormalFunctionLevel then
          SymTableStack.push(ProcDef.LocalST);
      end;


    procedure TCGProcInfo.Remove_From_SymTableStack;
      begin
        { remove localsymtable }
        if ProcDef.LocalST.SymTableLevel>=NormalFunctionLevel then
          SymTableStack.pop(ProcDef.LocalST);

        { remove parasymtable }
        if ProcDef.ParaST.SymTableLevel>=NormalFunctionLevel then
          SymTableStack.pop(ProcDef.ParaST);

        { remove symtables for the class, but only if it is no nested function }
        if Assigned(ProcDef.struct) and
           not(Assigned(Parent) and
               Assigned(Parent.ProcDef) and
               Assigned(Parent.ProcDef.struct)) then
          pop_nested_hierarchy(ProcDef.struct);
      end;


    procedure TCGProcInfo.ResetProcDef;
      begin
         { remove code tree, if not inline procedure }
         if Assigned(Code) then
          begin
            { the inline procedure has already got a copy of the tree
              stored in procdef.inlininginfo }
            Code.free;
            Code:=nil;
          end;
       end;


    procedure TCGProcInfo.Parse_Body;
      var
         lOldCurrentProcInfo : TProcInfo;
         lOldBlockType : TBlockType;
         lSymTable : TSymTable;
         lOldCurrentStructDef: TAbstractRecordDef;
         lOldCurrentGenericDef,
         lOldCurrentSpecializeDef: TStoredDef;
         lParentFPInitBlock: TNode;
         lOldParseGeneric: boolean;
         lRecordTokens : boolean;
      begin
         lOldCurrentProcInfo:=CurrentProcInfo;
         lOldBlockType:=Block_Type;
         lOldCurrentStructDef:=CurrentStructDef;
         lOldCurrentGenericDef:=CurrentGenericDef;
         lOldCurrentSpecializeDef:=CurrentSpecializeDef;
         lOldParseGeneric:=parse_generic;

         CurrentProcInfo:=self;
         CurrentStructDef:=ProcDef.struct;


        { check if the definitions of certain types are available which might not be available in older rtls and
          which are assigned "on the fly" in types_dec }
        if not Assigned(Rec_ExceptAddr) then
          Message1(cg_f_internal_type_not_found,'TEXCEPTADDR');
        if not Assigned(Rec_TGUID) then
          Message1(cg_f_internal_type_not_found,'TGUID');
        if not Assigned(Rec_Jmp_Buf) then
          Message1(cg_f_internal_type_not_found,'JMP_BUF');

         { if the procdef is truly a generic (thus takes parameters itself) then
           /that/ is our genericdef, not the - potentially - generic struct }
         if ProcDef.Is_Generic then
           begin
             CurrentGenericDef:=ProcDef;
             parse_generic:=true;
           end
         else if Assigned(CurrentStructDef) and (df_generic in CurrentStructDef.DefOptions) then
           begin
             CurrentGenericDef:=CurrentStructDef;
             parse_generic:=true;
           end;
         if Assigned(CurrentStructDef) and (df_specialization in CurrentStructDef.DefOptions) then
           CurrentSpecializeDef:=CurrentStructDef;

         { calculate the lexical level }
         if ProcDef.ParaST.SymTableLevel>MaxNesting then
           Message(parser_e_too_much_lexlevel);
         Block_Type:=bt_body;


         { allocate the symbol for this procedure }
         Alloc_Proc_Symbol(ProcDef);

         { add parast/localst to symtablestack }
         Add_To_SymTableStack;

         { save entry info }
         EntryPos:=CurrentFilePos;
         EntrySwitches:=CurrentSettings.LocalSwitches;

         lRecordTokens:=ProcDef.Is_Generic or
                       (
                         Assigned(ProcDef.struct) and
                         (df_generic in ProcDef.struct.DefOptions) and
                         Assigned(ProcDef.owner) and
                         (ProcDef.owner.DefOwner=ProcDef.struct)
                       );

         if lRecordTokens then
           begin
             { start token recorder for generic template }
             ProcDef.InitGeneric;
             CurrentScanner.startrecordtokens(ProcDef.GenericTokenBuf);
           end;

         { parse the code ... }
         Code:=Block(CurrentModule.IsLibrary);

         PostProcess_Capturer(self);

         if lRecordTokens then
           begin
             { stop token recorder for generic template }
             CurrentScanner.stoprecordtokens;

             { Give an error for accesses in the static symtable that aren't visible
               outside the current unit }
             lSymTable:=ProcDef.owner;
             while (lSymTable.SymTableType in [ObjectSymtable,recordsymtable]) do
               lSymTable:=lSymTable.DefOwner.owner;
             if (pi_uses_static_symtable in Flags) and
                (lSymTable.SymTableType<>staticsymtable) then
               Message(parser_e_global_generic_references_static);
           end;

         { save exit info }
         ExitSwitches:=CurrentSettings.LocalSwitches;
         ExitPos:=last_endtoken_filepos;

         { the procedure is now defined }
         ProcDef.ForwardDef:=false;
         ProcDef.IsImplemented:=true;

         if Assigned(Code) then
           begin
             { get a better entry point }
             EntryPos:=Code.fileinfo;

             { Finish type checking pass }
             DoTypeCheckPass(Code);

             if Assigned(ProcDef.ParentFPInitBlock) then
               begin
                 if Assigned(TBlockNode(ProcDef.ParentFPInitBlock).left) then
                   begin
                     lParentFPInitBlock:=ProcDef.ParentFPInitBlock;
                     DoTypeCheckPass(lParentFPInitBlock);
                     ProcDef.ParentFPInitBlock:=lParentFPInitBlock;
                   end
               end;

           end;

         { Check for unused labels, forwards, symbols for procedures. Static
           symtable is checked in pmodules.
           The check must be done after the typecheckpass }
         if (ErrorCount=0) and
            (TStoredSymTable(ProcDef.LocalST).SymTableType<>staticsymtable) then
           begin
             { check if forwards are resolved }
             TStoredSymTable(ProcDef.LocalST).Check_Forwards;
             { check if all labels are used }
             TStoredSymTable(ProcDef.LocalST).CheckLabels;
             { check for unused symbols, but only if there is no asm block }
             if not(pi_has_assembler_block in Flags) then
               begin
                 TStoredSymTable(ProcDef.LocalST).AllSymbolsUsed;
                 TStoredSymTable(ProcDef.ParaST).AllSymbolsUsed;
               end;
           end;

         if (po_inline in ProcDef.ProcOptions) and
           { Can we inline this procedure? }
           CheckNodeInlining(ProcDef) then
           CreateInlineInfo;

         { Print the node to tree.log }
         if ParaPrintNodeTree <> 0 then
           PrintProc( 'after parsing');


         { ... remove symbol tables }
         Remove_From_SymTableStack;


         CurrentStructDef:=lOldCurrentStructDef;
         CurrentGenericDef:=lOldCurrentGenericDef;
         CurrentSpecializeDef:=lOldCurrentSpecializeDef;
         CurrentProcInfo:=lOldCurrentProcInfo;
         parse_generic:=lOldParseGeneric;

         { Restore old state }
         Block_Type:=lOldBlockType;
      end;


{****************************************************************************
                        PROCEDURE/FUNCTION PARSING
****************************************************************************}


    procedure CheckInitParas(AObject:TObject;AArg:pointer);
      begin
        if TSym(AObject).typ<>paravarsym then
         exit;
        with TParaVarSym(AObject) do
          if (Is_Managed_Type(vardef) and
             (VarSpez in [vs_value,vs_out])) or
             (Is_ShortString(vardef) and
             (VarSpez=vs_value)) then
            include(CurrentProcInfo.Flags,pi_do_call);
      end;


    procedure Read_Proc_Body(AOldCurrentProcInfo:TProcInfo;AProcDef:TProcDef);
      {
        Parses the procedure directives, then parses the procedure body, then
        generates the code for it
      }

      var
        lOldFailTokenMode : TModeSwitches;
        lIsNestedProc     : boolean;
      begin
        Message1(parser_d_procedure_start,AProcDef.FullProcName(false));
        lOldFailTokenMode:=[];

        { create a new procedure }
        CurrentProcInfo:=CProcInfo.Create(AOldCurrentProcInfo);
        CurrentModule.ProcInfo:=CurrentProcInfo;
        CurrentProcInfo.ProcDef:=AProcDef;
        lIsNestedProc:=(CurrentProcInfo.ProcDef.ParaST.SymTableLevel>NormalFunctionLevel);
        { an anonymous function is always considered as nested }
        if po_anonymous in AProcDef.ProcOptions then
          begin
            CurrentProcInfo.Force_Nested;
            lIsNestedProc:=true;
          end;

        { Insert mangledname }
        AProcDef.AliasNames.insert(AProcDef.MangledName);

        { Insert result variables in the localst }
        insert_funcret_local(AProcDef);

        { check if there are para's which require initing -> set }
        { pi_do_call (if not yet set)                            }
        if not(pi_do_call in CurrentProcInfo.Flags) then
          AProcDef.ParaST.SymList.ForEachCall(@CheckInitParas,nil);

        { set _FAIL as keyword if constructor }
        if (AProcDef.ProcTypeOption=potype_constructor) then
         begin
           lOldFailTokenMode:=tokeninfo^[_FAIL].keyword;
           tokeninfo^[_FAIL].keyword:=alllanguagemodes;
         end;

        TCGProcInfo(CurrentProcInfo).Parse_Body;

        { reset _FAIL as _SELF normal }
        if (AProcDef.ProcTypeOption=potype_constructor) then
          tokeninfo^[_FAIL].keyword:=lOldFailTokenMode;

        { When it's a nested procedure then defer the code generation,
          when back at normal function level then generate the code
          for all deferred nested procedures and the current procedure }
        if not lIsNestedProc then
          begin
            if not(df_generic in CurrentProcInfo.ProcDef.DefOptions) then
              begin
                { also generate the bodies for all previously done
                  specializations so that we might inline them }
                generate_specialization_procs;
                { convert all load nodes that might have been captured by a
                  capture object }
                TCGProcInfo(CurrentProcInfo).ConvertCapturedSyms;
                TCGProcInfo(CurrentProcInfo).Generate_Code_Tree;
              end;
          end;

        { release procinfo }
        if TProcInfo(CurrentModule.ProcInfo)<>CurrentProcInfo then
          InternalError(200304274);
        CurrentModule.ProcInfo:=CurrentProcInfo.Parent;

        { For specialization we didn't record the last semicolon. Moving this parsing
          into the parse_body routine is not done because of having better file position
          information available }
        if not CurrentProcInfo.ProcDef.Is_Specialization and
            not (po_anonymous in CurrentProcInfo.ProcDef.ProcOptions) and
            (
              not Assigned(CurrentProcInfo.ProcDef.struct) or
              not (df_specialization in CurrentProcInfo.ProcDef.struct.DefOptions)
              or not (
                Assigned(CurrentProcInfo.ProcDef.owner) and
                (CurrentProcInfo.ProcDef.owner.DefOwner=CurrentProcInfo.ProcDef.struct)
              )
            ) then
          consume(_SEMICOLON);

        if not lIsNestedProc then
          { current_procinfo is checked for nil later on }
          freeandnil(CurrentProcInfo);
      end;


    procedure Read_Proc_Body(AProcDef:TProcDef);
      var
        lOldModuleProcInfo : tobject;
        lOldCurrentProcInfo : TProcInfo;
      begin
        lOldCurrentProcInfo:=CurrentProcInfo;
        lOldModuleProcInfo:=CurrentModule.ProcInfo;
        CurrentProcInfo:=nil;
        CurrentModule.ProcInfo:=nil;
        Read_Proc_Body(nil,AProcDef);
        CurrentProcInfo:=lOldCurrentProcInfo;
        CurrentModule.ProcInfo:=lOldModuleProcInfo;
      end;


    function Read_Proc(AFlags:TReadProcFlags; AForwardProcDef: TProcDef):TProcDef;
      {
        Parses the procedure directives, then parses the procedure body, then
        generates the code for it
      }

        function ConvertFlagsToPPF:TParseProcFlags;inline;
          begin
            Result:=[];
            if rpf_classmethod in AFlags then
              include(Result,ppf_classmethod);
            if rpf_generic in AFlags then
              include(Result,ppf_generic);
            if rpf_anonymous in AFlags then
              include(Result,ppf_anonymous);
          end;

      var
        lOldCurrentProcInfo : TProcInfo;
        lOldCurrentStructDef: TAbstractRecordDef;
        lOldCurrentGenericDef,
        lOldCurrentSpecializeDef: TStoredDef;
        lProcDefFlags    : TPDFlags;
        lFirstProcDef : TProcDef;
{$ifdef genericdef_for_nested}
        lDef : TProcDef;
        lSym : TSym;
        lIndex : LongInt;
{$endif genericdef_for_nested}
      begin
         { save old state }
         lOldCurrentProcInfo:=CurrentProcInfo;
         lOldCurrentStructDef:=CurrentStructDef;
         lOldCurrentGenericDef:=CurrentGenericDef;
         lOldCurrentSpecializeDef:=CurrentSpecializeDef;

         { reset current_procinfo.procdef to nil to be sure that nothing is writing
           to another procdef }
         CurrentProcInfo:=nil;
         CurrentStructDef:=nil;
         CurrentGenericDef:=nil;
         CurrentSpecializeDef:=nil;

         if not Assigned(AForwardProcDef) then
           { parse procedure declaration }
           Result:=parse_proc_dec(ConvertFlagsToPPF,lOldCurrentStructDef)
         else
           Result:=AForwardProcDef;

         { set the default function options }
         if parse_only then
          begin
            Result.ForwardDef:=true;
            { set also the interface flag, for better error message when the
              implementation doesn't match this header }
            Result.InterfaceDef:=true;
            include(Result.ProcOptions,po_global);
            lProcDefFlags:=[pd_interface];
          end
         else
          begin
            lProcDefFlags:=[pd_body];
            if (not CurrentModule.InInterface) then
              include(lProcDefFlags,pd_implemen);
            if (not CurrentModule.IsUnit) or
               create_smartlink_library then
              include(Result.ProcOptions,po_global);
            Result.ForwardDef:=false;
          end;

         if not Assigned(AForwardProcDef) then
           begin
             { parse the directives that may follow }
             parse_proc_directives(Result,lProcDefFlags);

             if not (rpf_anonymous in AFlags) then
               { hint directives, these can be separated by semicolons here,
                 that needs to be handled here with a loop (PFV) }
               while try_consume_hintdirective(Result.SymOptions,Result.DeprecatedMsg) do
                Consume(_SEMICOLON);

             { Set calling convention }
             if parse_only then
               handle_calling_convention(Result,hcc_default_actions_intf)
             else
               handle_calling_convention(Result,hcc_default_actions_impl)
           end;

         { search for forward declarations }
         if not proc_add_definition(Result) then
           begin
             { One may not implement a method of a type declared in a different unit }
             if Assigned(Result.struct) and
                (Result.struct.SymTable.ModuleID<>CurrentModule.ModuleID) and
                not Result.Is_Specialization then
              begin
                MessagePos1(Result.fileinfo,parser_e_method_for_type_in_other_unit,Result.struct.TypeSymbolPrettyName);
              end
             { A method must be forward defined (in the object declaration) }
             else if Assigned(Result.struct) and
                (not Assigned(lOldCurrentStructDef)) then
              begin
                MessagePos1(Result.fileinfo,parser_e_header_dont_match_any_member,Result.FullProcName(false));
                TProcSym(Result.ProcSym).Write_Parameter_Lists(Result);
              end
             else
              begin
                { Give a better error if there is a forward def in the interface and only
                  a single implementation }
                lFirstProcDef:=TProcDef(TProcSym(Result.ProcSym).ProcdefList[0]);
                if (not Result.ForwardDef) and
                   (not Result.InterfaceDef) and
                   (TProcSym(Result.ProcSym).ProcdefList.Count>1) and
                   lFirstProcDef.ForwardDef and
                   lFirstProcDef.InterfaceDef and
                   not(TProcSym(Result.ProcSym).ProcdefList.Count>2) and
                   { don't give an error if it may be an overload }
                   not(m_fpc in CurrentSettings.ModeSwitches) and
                   (not(po_overload in Result.ProcOptions) or
                    not(po_overload in lFirstProcDef.ProcOptions)) then
                 begin
                   MessagePos1(Result.fileinfo,parser_e_header_dont_match_forward,Result.FullProcName(false));
                   TProcSym(Result.ProcSym).Write_Parameter_Lists(Result);
                 end
                else
                  begin
                    if Result.Is_Generic and not Assigned(Result.struct) then
                      TProcSym(Result.ProcSym).owner.IncludeOption(sto_has_generic);
                  end;
              end;
           end;

         { Set mangled name }
         proc_set_mangledname(Result);

         { inherit generic flags from parent routine }
         if Assigned(lOldCurrentProcInfo) and
             (lOldCurrentProcInfo.ProcDef.DefOptions*[df_specialization,df_generic]<>[]) then
           begin
             if df_generic in lOldCurrentProcInfo.ProcDef.DefOptions then
               include(Result.DefOptions,df_generic);
             if df_specialization in lOldCurrentProcInfo.ProcDef.DefOptions then
               begin
                 include(Result.DefOptions,df_specialization);
                 { the procdefs encountered here are nested procdefs of which
                   their complete definition also resides inside the current token
                   stream, thus access to their genericdef is not required }
                 {$ifdef genericdef_for_nested}
                 { find the corresponding routine in the generic routine }
                 if not Assigned(lOldCurrentProcInfo.ProcDef.GenericDef) then
                   InternalError(2016121701);
                 lSym:=TSym(TProcDef(lOldCurrentProcInfo.ProcDef.GenericDef).GetSymTable(gs_local).find(Result.ProcSym.name));
                 if not Assigned(lSym) or (lSym.typ<>ProcSym) then
                   InternalError(2016121702);
                 { in practice the generic procdef should be at the same index
                   as the index of the current procdef, but as there *might* be
                   differences between the amount of defs generated for the
                   specialization and the generic search for the def using
                   parameter comparison }
                 for lIndex:=0 to TProcSym(lSym).procdeflist.count-1 do
                   begin
                     lDef:=TProcDef(TProcSym(lSym).procdeflist[lIndex]);
                     if (Compare_Paras(lDef.paras,Result.paras,cp_none,[cpo_ignorehidden,cpo_openequalisexact,cpo_ignoreuniv])=te_exact) and
                         (Compare_Defs(lDef.ReturnDef,Result.ReturnDef,nothingn)=te_exact) then
                       begin
                         Result.GenericDef:=lDef;
                         break;
                       end;
                   end;
                 if not Assigned(Result.GenericDef) then
                   InternalError(2016121703);
                 {$endif}
               end;
           end;

         { compile procedure when a body is needed }
         if (pd_body in lProcDefFlags) then
           begin
             Read_Proc_Body(lOldCurrentProcInfo,Result);
           end
         else
           begin
             { Handle imports }
             if (po_external in Result.ProcOptions) then
               begin
                 Import_External_Proc(Result);
{$ifdef cpuhighleveltarget}
                 { it's hard to factor this out in a virtual method, because the
                   generic version (the one inside this ifdef) doesn't fit in
                   hlcgobj but in symcreat or here, while the other version
                   doesn't fit in symcreat (since it uses the code generator).
                   Maybe we need another class for this kind of code that could
                   either be symcreat- or hlcgobj-based
                 }
                 if (not Result.ForwardDef) and
                    (Result.HasForward) and
                    (proc_get_importname(Result)<>'') then
                   begin
                     { we cannot handle the callee-side of variadic functions (and
                       even if we could, e.g. LLVM cannot call through to something
                       else in that case) }
                     if Is_C_Variadic(Result) then
                       Message1(parser_e_callthrough_varargs,Result.FullProcName(false));
                     Call_Through_New_Name(Result,proc_get_importname(Result));
                     include(Result.ImplProcOptions,pio_thunk);
                   end
                 else
{$endif cpuhighleveltarget}
                   begin
                     Create_HLCodeGen(nil);
                     hlcg.Handle_External_Proc(
                       CurrentAsmData.asmlists[al_procedures],
                       Result,
                       proc_get_importname(Result));
                     Destroy_HLCodeGen;
                   end
               end;
           end;

         { always register public functions that are only declared in the
           implementation section as they might be called using an external
           declaration from another unit }
         if (po_global in Result.ProcOptions) and
             not Result.InterfaceDef and
             ([df_generic,df_specialization]*Result.DefOptions=[]) then
           begin
             Result.RegisterDef;
             Result.ProcSym.RegisterSym;
           end;

         { make sure that references to forward-declared functions are not }
         { treated as references to external symbols, needed for darwin.   }

         { make sure we don't change the binding of real external symbols }
         if (([po_external,po_weakexternal]*Result.ProcOptions)=[]) and (pocall_internproc<>Result.ProcCallOption) then
           CurrentAsmData.DefineProcAsmSymbol(Result,Result.MangledName,Result.NeedsGlobalAsmSym);

         CurrentStructDef:=lOldCurrentStructDef;
         CurrentGenericDef:=lOldCurrentGenericDef;
         CurrentSpecializeDef:=lOldCurrentSpecializeDef;
         CurrentProcInfo:=lOldCurrentProcInfo;
      end;


    procedure Import_External_Proc(AProcDef:TProcDef);
      var
        lName : string;
      begin
        if not (po_external in AProcDef.ProcOptions) then
          InternalError(2015121101);

        { Import DLL specified? }
        if Assigned(AProcDef.ImportDLL) then
          begin
            if Assigned (AProcDef.ImportName) then
              CurrentModule.AddExternalImport(AProcDef.ImportDLL^,
                AProcDef.ImportName^,proc_get_importname(AProcDef),
                AProcDef.ImportNr,false,false)
            else
              CurrentModule.AddExternalImport(AProcDef.ImportDLL^,
                proc_get_importname(AProcDef),proc_get_importname(AProcDef),
                AProcDef.ImportNr,false,true);
          end
        else
          begin
            lName:=proc_get_importname(AProcDef);
            { add import name to external list for DLL scanning }
            if tf_has_dllscanner in TargetInfo.Flags then
              CurrentModule.DLLScannerInputList.Add(lName,AProcDef);
            { needed for units that use functions in packages this way }
            CurrentModule.Add_Extern_AsmSym(lName,AB_EXTERNAL,AT_FUNCTION);
          end;
      end;

{****************************************************************************
                             DECLARATION PARSING
****************************************************************************}

    { search in symtablestack for not complete classes }
    procedure CheckForwardClass(AObject:TObject;AArg:pointer);
      begin
        if (TSym(AObject).typ=TypeSym) and
           (TTypeSym(AObject).TypeDef.typ=objectdef) and
           (oo_is_forward in TObjectDef(TTypeSym(AObject).TypeDef).ObjectOptions) then
          MessagePos1(TSym(AObject).fileinfo,sym_e_forward_type_not_resolved,TSym(AObject).realname);
      end;


    procedure Read_Declarations(AIsLibrary : boolean);
      var
        lHadGeneric : boolean;

        procedure HandleUnexpectedHadGeneric;
          begin
            if lHadGeneric then
              begin
                Message(parser_e_procedure_or_function_expected);
                lHadGeneric:=false;
              end;
          end;

      var
        lIsClassDef:boolean;
        lFlags : TReadProcFlags;
      begin
        lIsClassDef:=false;
        lHadGeneric:=false;
        repeat
           if not Assigned(CurrentProcInfo) then
             InternalError(200304251);
           case CurrentScanner.token of
              _LABEL:
                begin
                  HandleUnexpectedHadGeneric;
                  label_dec;
                end;
              _CONST:
                begin
                  HandleUnexpectedHadGeneric;
                  const_dec(lHadGeneric);
                end;
              _TYPE:
                begin
                  HandleUnexpectedHadGeneric;
                  type_dec(lHadGeneric);
                end;
              _VAR:
                begin
                  HandleUnexpectedHadGeneric;
                  var_dec(lHadGeneric);
                end;
              _THREADVAR:
                begin
                  HandleUnexpectedHadGeneric;
                  threadvar_dec(lHadGeneric);
                end;
              _CLASS:
                begin
                  lIsClassDef:=false;
                  if try_to_consume(_CLASS) then
                   begin
                     { class modifier is only allowed for procedures, functions, }
                     { constructors, destructors                                 }
                     if not((CurrentScanner.token in [_FUNCTION,_PROCEDURE,_DESTRUCTOR,_OPERATOR]) or (CurrentScanner.token=_CONSTRUCTOR)) and
                        not((CurrentScanner.token=_ID) and (CurrentScanner.idtoken=_OPERATOR)) then
                       Message(parser_e_procedure_or_function_expected);

                     if Is_Interface(CurrentStructDef) then
                       Message(parser_e_no_static_method_in_interfaces)
                     else
                       { class methods are also allowed for Objective-C protocols }
                       lIsClassDef:=true;
                   end;
                end;
              _CONSTRUCTOR,
              _DESTRUCTOR,
              _FUNCTION,
              _PROCEDURE,
              _OPERATOR:
                begin
                  if lHadGeneric and not (CurrentScanner.token in [_PROCEDURE,_FUNCTION]) then
                    begin
                      Message(parser_e_procedure_or_function_expected);
                      lHadGeneric:=false;
                    end;
                  lFlags:=[];
                  if lIsClassDef then
                    include(lFlags,rpf_classmethod);
                  if lHadGeneric then
                    include(lFlags,rpf_generic);
                  Read_Proc(lFlags,nil);
                  lIsClassDef:=false;
                  lHadGeneric:=false;
                end;
              _EXPORTS:
                begin
                   HandleUnexpectedHadGeneric;
                   if (CurrentProcInfo.ProcDef.LocalST.SymTableLevel>MainProgramLevel) then
                     begin
                        Message(parser_e_syntax_error);
                        consume_all_until(_SEMICOLON);
                     end
                   else if AIsLibrary or
                     (TargetInfo.system in systems_unit_program_exports) then
                     read_exports
                   else
                     begin
                        Message(parser_w_unsupported_feature);
                        consume(_BEGIN);
                     end;
                end;
              _PROPERTY:
                begin
                  HandleUnexpectedHadGeneric;
                  if (m_fpc in CurrentSettings.ModeSwitches) then
                    property_dec
                  else
                    break;
                end;
              else
                begin
                  case CurrentScanner.idtoken of
                    _RESOURCESTRING:
                      begin
                        HandleUnexpectedHadGeneric;
                        { m_class is needed, because the resourcestring
                          loading is in the ObjPas unit }
{                        if (m_class in current_settings.modeswitches) then}
                          resourcestring_dec(lHadGeneric)
{                        else
                          break;}
                      end;
                    _OPERATOR:
                      begin
                        HandleUnexpectedHadGeneric;
                        if lIsClassDef then
                          begin
                            Read_Proc([rpf_classmethod],nil);
                            lIsClassDef:=false;
                          end
                        else
                          break;
                      end;
                    _GENERIC:
                      begin
                        HandleUnexpectedHadGeneric;
                        if not (m_delphi in CurrentSettings.ModeSwitches) then
                          begin
                            consume(_ID);
                            lHadGeneric:=true;
                          end
                        else
                          break;
                      end
                    else
                      break;
                  end;
                end;
           end;
         until false;

         { add implementations for synthetic method declarations added by
           the compiler (not for unit/program init functions, their localst
           is the statistic -> would duplicate the work done in pmodules) }
         if (CurrentProcInfo.ProcDef.LocalST.SymTableType=LocalSymTable) and
           { we cannot call add_synthetic_method_implementations as it throws an internalerror if
             the token is a string/char. As this is a syntax error and compilation will abort anyways,
             skipping the call does not matter
           }
           (CurrentScanner.token<>_CSTRING) and
           (CurrentScanner.token<>_CWCHAR) and
           (CurrentScanner.token<>_CWSTRING) then
           Add_Synthetic_Method_Implementations(CurrentProcInfo.ProcDef.LocalST);

         { check for incomplete class definitions, this is only required
           for fpc modes }
         if (m_fpc in CurrentSettings.ModeSwitches) then
           CurrentProcInfo.ProcDef.LocalST.SymList.ForEachCall(@CheckForwardClass,nil);
      end;


    procedure Read_Interface_Declarations;
      var
        lHadGeneric : boolean;

        procedure HandleUnexpectedHadGeneric;
          begin
            if lHadGeneric then
              begin
                Message(parser_e_procedure_or_function_expected);
                lHadGeneric:=false;
              end;
          end;

      var
        lFlags : TReadProcFlags;
      begin
         lHadGeneric:=false;
         repeat
           case CurrentScanner.token of
             _CONST :
               begin
                 HandleUnexpectedHadGeneric;
                 const_dec(lHadGeneric);
               end;
             _TYPE :
               begin
                 HandleUnexpectedHadGeneric;
                 type_dec(lHadGeneric);
               end;
             _VAR :
               begin
                 HandleUnexpectedHadGeneric;
                 var_dec(lHadGeneric);
               end;
             _THREADVAR :
               begin
                 HandleUnexpectedHadGeneric;
                 threadvar_dec(lHadGeneric);
               end;
             _FUNCTION,
             _PROCEDURE,
             _OPERATOR :
               begin
                 if lHadGeneric and not (CurrentScanner.token in [_FUNCTION, _PROCEDURE]) then
                   begin
                     message(parser_e_procedure_or_function_expected);
                     lHadGeneric:=false;
                   end;
                 lFlags:=[];
                 if lHadGeneric then
                   include(lFlags,rpf_generic);
                 Read_Proc(lFlags,nil);
                 lHadGeneric:=false;
               end;
             else
               begin
                 case CurrentScanner.idtoken of
                   _RESOURCESTRING :
                     begin
                       HandleUnexpectedHadGeneric;
                       resourcestring_dec(lHadGeneric);
                     end;
                   _PROPERTY:
                     begin
                       HandleUnexpectedHadGeneric;
                       if (m_fpc in CurrentSettings.ModeSwitches) then
                         property_dec
                       else
                         break;
                     end;
                   _GENERIC:
                     begin
                       HandleUnexpectedHadGeneric;
                       if not (m_delphi in CurrentSettings.ModeSwitches) then
                         begin
                           lHadGeneric:=true;
                           consume(_ID);
                         end
                       else
                         break;
                     end
                   else
                     break;
                 end;
               end;
           end;
         until false;
         { check for incomplete class definitions, this is only required
           for fpc modes }
         if (m_fpc in CurrentSettings.ModeSwitches) then
          SymTableStack.top.SymList.ForEachCall(@CheckForwardClass,nil);
      end;


end.
