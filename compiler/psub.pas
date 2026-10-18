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
          tempinfo : PTempInfo;
          flags : TTempInfoFlags;
        end;
        PTempInfoFlagsEntry = ^TTempInfoFlagsEntry;
      private
        tempinfo_flags_map : TFPList;
        tempflags_swapped : boolean;
        procedure swap_tempflags;
        function store_node_tempflags(var n: TNode; arg: pointer): TForEachNodeResult;
        procedure CreateInlineInfo;
        { returns the node which is the start of the user code, this is needed by the dfa }
        function GetUserCode: TNode;
        procedure maybe_add_constructor_wrapper(var tocode: TNode; withexceptblock: boolean);
        procedure add_entry_exit_code;
        procedure setup_tempgen;
        procedure TransformNodeTree;
        procedure Convert_Captured_Syms;
      protected
        procedure generate_code_exceptfilters;
      public
        { code for the subroutine as tree }
        code : TNode;
        { positions in the tree for init/final }
        entry_asmnode,
        loadpara_asmnode,
        exitlabel_asmnode,
        stackcheck_asmnode,
        init_asmnode    : TAsmNode;
        temps_finalized : boolean;
        dfabuilder : TDFABuilder;
        { Last temp offset of the parent procedure at the time exceptfilter
          code generation begins. Temps below this boundary belong to the parent
          and must be adjusted to FP-relative in the handler. Temps at or above
          this boundary belong to the handler and stay SP-relative.
          Only used on AArch64-Win64. }
        exceptfilter_parent_tempend : LongInt;

        destructor  Destroy;override;

        function calc_stackframe_size : LongInt;override;

        procedure printproc(pass:string);
        procedure generate_code;
        procedure generate_code_tree;
        procedure generate_exceptfilter(nestedpi: TCGProcInfo);
        procedure generate_exit_label(list: TAsmList); virtual;
        procedure resetprocdef;
        procedure add_to_symtablestack;
        procedure remove_from_symtablestack;
        procedure parse_body;

        procedure store_tempflags;
        procedure apply_tempflags;
        procedure reset_tempflags;

        function has_assembler_child : boolean;
        procedure set_eh_info; override;
      end;

      TReadProcFlag = (
        rpf_classmethod,
        rpf_generic,
        rpf_anonymous
      );
      TReadProcFlags = set of TReadProcFlag;


    procedure printnode_reset;

    { reads the declaration blocks }
    procedure read_declarations(IsLibrary : boolean);

    { reads declarations in the interface part of a unit }
    procedure read_interface_declarations;

    { reads any routine in the implementation, or a non-method routine
      declaration in the interface (depending on whether or not parse_only is
      true) }
    function read_proc(flags:TReadProcFlags; usefwpd: TProcDef):TProcDef;

    { parses only the body of a non nested routine; needs a correctly setup pd }
    procedure read_proc_body(pd:TProcDef);

    procedure import_external_proc(pd:TProcDef);


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
       pass_1,
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

    function checknodeinlining(procdef: TProcDef): boolean;

      procedure _no_inline(const reason: TMsgStr);
        begin
          include(procdef.ImplProcOptions,pio_inline_not_possible);
          Message1(parser_n_not_supported_for_inline,reason);
          Message(parser_h_inlining_disabled);
        end;

      var
        i : integer;
        currpara : TParaVarSym;
      begin
        result := false;
        { this code will never be used (only specialisations can be inlined),
          and moreover contains references to defs that are not stored in the
          ppu file }
        if df_generic in CurrentProcInfo.procdef.DefOptions then
          exit;
        if pi_has_assembler_block in CurrentProcInfo.flags then
          begin
            _no_inline('assembler');
            exit;
          end;
        if (pi_has_global_goto in CurrentProcInfo.flags) or
           (pi_has_interproclabel in CurrentProcInfo.flags) then
          begin
            _no_inline('global goto');
            exit;
          end;
        if pi_has_nested_exit in CurrentProcInfo.flags then
          begin
            _no_inline('nested exit');
            exit;
          end;
        if pi_calls_c_varargs in CurrentProcInfo.flags then
          begin
            _no_inline('called C-style varargs functions');
            exit;
          end;
        { the compiler cannot handle inherited in inlined subroutines because
          it tries to search for self in the symtable, however, the symtable
          is not available }
        if pi_has_inherited in CurrentProcInfo.flags then
          begin
            _no_inline('inherited');
            exit;
          end;
        if pio_nested_access in procdef.ImplProcOptions then
         begin
           _no_inline('access to local from nested scope');
           exit;
         end;
        { We can't support inlining for procedures that have nested
          procedures because the nested procedures use a fixed offset
          for accessing locals in the parent procedure (PFV) }
        if CurrentProcInfo.has_nestedprocs then
          begin
            _no_inline('nested procedures');
            exit;
          end;

        if pi_uses_get_frame in CurrentProcInfo.flags then
          begin
            _no_inline('get_frame');
            { for LLVM: it can inline things that FPC can't, but it mustn't
              inline this one }
            include(CurrentProcInfo.procdef.ImplProcOptions,pio_inline_forbidden);
            exit;
          end;

        for i:=0 to procdef.paras.count-1 do
          begin
            currpara:=TParaVarSym(procdef.paras[i]);
            case currpara.vardef.typ of
              arraydef :
                begin
                  if Is_Array_Of_Const(currpara.vardef) or
                     Is_Variant_Array(currpara.vardef) then
                    begin
                      _no_inline('array of const');
                      exit;
                    end;
                  { open arrays might need re-basing of the index, i.e. if you pass
                    an array[1..10] as open array, you have to add 1 to all index operations
                    if you directly inline it }
                  if Is_Open_Array(currpara.vardef) then
                    begin
                      _no_inline('open array');
                      exit;
                    end;
                end;
              else
                ;
            end;
        end;
        result:=true;
      end;


{****************************************************************************
                      PROCEDURE/FUNCTION BODY PARSING
****************************************************************************}

    procedure initializevars(p:TObject;arg:pointer);
      var
        b : TBlockNode;
      begin
        if not (TSym(p).typ in [localvarsym,staticvarsym]) then
         exit;
        with TAbstractNormalVarSym(p) do
         begin
           if Assigned(DefaultConstSym) then
            begin
              b:=TBlockNode(arg);
              b.left:=CStatementNode.create(
                        CAssignmentNode.create(
                            CLoadNode.create(TSym(p),TSym(p).owner),
                            CLoadNode.create(DefaultConstSym,DefaultConstSym.owner)),
                        b.left);
            end
         end;
      end;


    procedure check_finalize_paras(p:TObject;arg:pointer);
      begin
        if (TSym(p).typ=paravarsym) then
          begin
            if TParaVarSym(p).Needs_Finalization then
              begin
                include(CurrentProcInfo.flags,pi_needs_implicit_finally);
                include(CurrentProcInfo.flags,pi_do_call);
              end;
          end;
      end;


    procedure check_finalize_locals(p:TObject;arg:pointer);
      begin
        { include the result: it needs to be finalized in case an exception }
        { occurs                                                            }
        if (TSym(p).typ=localvarsym) and
           (TLocalVarSym(p).refs>0) and
           Is_Managed_Type(TLocalVarSym(p).vardef) then
          begin
            include(CurrentProcInfo.flags,pi_needs_implicit_finally);
            include(CurrentProcInfo.flags,pi_do_call);
          end;
      end;

    procedure init_main_block_syms(block: TNode);
      var
         oldfilepos: TFilePosInfo;
      begin
        { initialized variables }
        if CurrentProcInfo.procdef.LocalST.SymTableType=LocalSymTable then
         begin
           { initialization of local variables with their initial
             values: part of function entry }
           oldfilepos:=CurrentFilePos;
           CurrentFilePos:=CurrentProcInfo.entrypos;
           CurrentProcInfo.procdef.LocalST.SymList.ForEachCall(@initializevars,block);
           CurrentFilePos:=oldfilepos;
         end;

        if Assigned(CurrentProcInfo.procdef.ParentFPStruct) then
         begin
           { finish the parentfpstruct (add padding, ...) }
           Finish_ParentFPStruct(CurrentProcInfo.procdef);
         end;
      end;

    function block(IsLibrary : boolean) : TNode;
      begin
         { parse const,types and vars }
         read_declarations(IsLibrary);

         { do we have an assembler block without the po_assembler?
           we should allow this for Delphi compatibility (PFV) }
         if (CurrentScanner.token=_ASM) and (m_delphi in CurrentSettings.ModeSwitches) then
           include(CurrentProcInfo.procdef.ProcOptions,po_assembler);

         { Handle assembler block different }
         if (po_assembler in CurrentProcInfo.procdef.ProcOptions) then
          begin
            block:=assembler_block;
            exit;
          end;

         {Unit initialization?.}
         if (
             Assigned(CurrentProcInfo.procdef.LocalST) and
             (CurrentProcInfo.procdef.LocalST.SymTableLevel=MainProgramLevel) and
             (CurrentModule.IsUnit or IsLibrary)
            ) then
           begin
             if (CurrentScanner.token=_END) then
                begin
                   consume(_END);
                   { We need at least a node, else the entry/exit code is not
                     generated and thus no PASCALMAIN symbol which we need (PFV) }
                   if IsLibrary then
                    block:=CNothingNode.create
                   else
                    block:=nil;
                end
              else
                begin
                   if CurrentScanner.token=_INITIALIZATION then
                     begin
                        { The library init code is already called and does not
                          need to be in the initfinal table (PFV) }
                        block:=statement_block(_INITIALIZATION);
                        init_main_block_syms(block);
                     end
                   else if CurrentScanner.token=_FINALIZATION then
                     begin
                       { when a unit has only a finalization section, we can come to this
                         point when we try to read the nonh existing initialization section
                         so we've to check if we are really try to parse the finalization }
                       if CurrentProcInfo.procdef.ProcTypeOption=potype_unitfinalize then
                         block:=statement_block(_FINALIZATION)
                       else
                         block:=nil;
                     end
                   else
                     block:=statement_block(_BEGIN);
                end;
            end
         else
            begin
               { parse routine body }
               block:=statement_block(_BEGIN);
               init_main_block_syms(block);
            end;
      end;


{****************************************************************************
                       PROCEDURE/FUNCTION COMPILING
****************************************************************************}

    procedure printnode_reset;
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


    procedure add_label_init(p:TObject;arg:pointer);
      begin
        if TStoredSym(p).typ=labelsym then
          begin
            addstatement(TStatementNode(arg^),
              CIfNode.create(CAddNode.create(EqualN,
                CCallNode.createintern('fpc_setjmp',
                  CCallParaNode.create(CLoadNode.create(TLabelSym(p).JumpBuf,TLabelSym(p).JumpBuf.owner),nil)),
                COrdConstNode.create(1,Search_System_Proc('fpc_setjmp').ReturnDef,true))
              ,CGotoNode.create(TLabelSym(p)),nil)
            );
          end;
      end;


    function generate_bodyentry_block:TNode;
      var
        srsym        : TSym;
        para         : TCallParaNode;
        call         : TCallNode;
        newstatement : TStatementNode;
        def          : TAbstractRecordDef;
      begin
        result:=internalstatements(newstatement);

        if Assigned(CurrentStructDef) then
          begin
            { a constructor needs a help procedure }
            if (CurrentProcInfo.procdef.ProcTypeOption=potype_constructor) then
              begin
                if Is_Class(CurrentStructDef) or
                    (
                      Is_ObjectPascal_Helper(CurrentStructDef) and
                      Is_Class(TObjectDef(CurrentStructDef).ExtendedDef)
                    ) then
                  begin
                    if Is_ObjectPascal_Helper(CurrentStructDef) then
                      def:=TAbstractRecordDef(TObjectDef(CurrentStructDef).ExtendedDef)
                    else
                      def:=CurrentStructDef;
                    srsym:=Search_Struct_Member(def,'NEWINSTANCE');
                    if Assigned(srsym) and
                       (srsym.typ=ProcSym) then
                      begin
                        { if vmt=1 then newinstance }
                        call:=
                          CCallNode.create(nil,TProcSym(srsym),srsym.owner,
                            CTypeConvNode.Create_Internal(load_self_pointer_node,CClassRefDef.create(CurrentStructDef)),
                            [],nil);
                        include(call.callnodeflags,cnf_ignore_devirt_wpo);
                        addstatement(newstatement,CIfNode.create(
                            CAddNode.Create_Internal(EqualN,
                                CTypeConvNode.Create_Internal(
                                    load_vmt_pointer_node,
                                    VoidPointerType),
                                CPointerConstNode.create(1,VoidPointerType)),
                            CAssignmentNode.create(
                                CTypeConvNode.Create_Internal(
                                    load_self_pointer_node,
                                    VoidPointerType),
                                call),
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
                      para:=CCallParaNode.create(
                                COrdConstNode.create(TObjectDef(CurrentStructDef).VMT_Offset,S32IntType,false),
                            CCallParaNode.create(
                                CTypeConvNode.Create_Internal(
                                    load_vmt_pointer_node,
                                    VoidPointerType),
                            CCallParaNode.create(
                                CTypeConvNode.Create_Internal(
                                    load_self_pointer_node,
                                    VoidPointerType),
                            nil)));
                      addstatement(newstatement,CAssignmentNode.create(
                          CTypeConvNode.Create_Internal(
                              load_self_pointer_node,
                              VoidPointerType),
                          CCallNode.createintern('fpc_help_constructor',para)));
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
                  addstatement(newstatement,CIfNode.create(
                    CAddNode.create(EqualN,
                        load_self_pointer_node,
                        CNilNode.create),
                    CExitNode.create(nil),
                    nil));
              end;

            { maybe call BeforeDestruction for classes }
            if (CurrentProcInfo.procdef.ProcTypeOption=potype_destructor) and
               Is_Class(CurrentStructDef) then
              begin
                srsym:=Search_Struct_Member(CurrentStructDef,'BEFOREDESTRUCTION');
                if Assigned(srsym) and
                   (srsym.typ=ProcSym) then
                  begin
                    { if vmt>0 then beforedestruction }
                    addstatement(newstatement,CIfNode.create(
                        CAddNode.create(gtn,
                            CTypeConvNode.Create_Internal(
                              load_vmt_pointer_node,PtrSIntType),
                            CTypeConvNode.Create_Internal(
                              CNilNode.create,PtrSIntType)),
                        CCallNode.create(nil,TProcSym(srsym),srsym.owner,load_self_node,[],nil),
                        nil));
                  end
                else
                  InternalError(200305104);
              end;
          end;
        if m_non_local_goto in CurrentSettings.ModeSwitches then
          TSymTable(CurrentProcInfo.procdef.LocalST).SymList.ForEachCall(@add_label_init,@newstatement);

        Initialize_Capturer(CurrentProcInfo,newstatement);
      end;


    function generate_bodyexit_block:TNode;
      var
        srsym : TSym;
        para : TCallParaNode;
        newstatement : TStatementNode;
        oldlocalswitches: TLocalSwitches;
      begin
        result:=internalstatements(newstatement);

        if Assigned(CurrentStructDef) then
          begin
            { Don't test self and the vmt here. The reason is that  }
            { a constructor already checks whether these are valid  }
            { before. Further, in case of TThread the thread may    }
            { free the class instance right after AfterConstruction }
            { has been called, so it may no longer be valid (JM)    }
            oldlocalswitches:=CurrentSettings.LocalSwitches;
            CurrentSettings.LocalSwitches:=oldlocalswitches-[cs_check_object,cs_check_range];

            { a destructor needs a help procedure }
            if (CurrentProcInfo.procdef.ProcTypeOption=potype_destructor) then
              begin
                if Is_Class(CurrentStructDef) then
                  begin
                    srsym:=Search_Struct_Member(CurrentStructDef,'FREEINSTANCE');
                    if Assigned(srsym) and
                       (srsym.typ=ProcSym) then
                      begin
                        { if self<>0 and vmt<>0 then freeinstance }
                        addstatement(newstatement,CIfNode.create(
                            CAddNode.create(andn,
                                CAddNode.create(unequaln,
                                    load_self_pointer_node,
                                    CNilNode.create),
                                CAddNode.create(unequaln,
                                    CTypeConvNode.create(
                                        load_vmt_pointer_node,
                                        VoidPointerType),
                                    CPointerConstNode.create(0,VoidPointerType))),
                            CCallNode.create(nil,TProcSym(srsym),srsym.owner,load_self_node,[],nil),
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
                          addstatement(newstatement,CIfNode.create(
                            CAddNode.create(unequaln,
                              CTypeConvNode.Create_Internal(load_vmt_pointer_node,VoidPointerType),
                              CNilNode.create),
                            CNodeUtils.finalize_data_node(load_self_node),
                            nil));
                        end;
                      { parameter 3 : vmt_offset }
                      { parameter 2 : pointer to vmt }
                      { parameter 1 : self pointer }
                      para:=CCallParaNode.create(
                                COrdConstNode.create(TObjectDef(CurrentStructDef).VMT_Offset,S32IntType,false),
                            CCallParaNode.create(
                                CTypeConvNode.Create_Internal(
                                    load_vmt_pointer_node,
                                    VoidPointerType),
                            CCallParaNode.create(
                                CTypeConvNode.Create_Internal(
                                    load_self_pointer_node,
                                    VoidPointerType),
                            nil)));
                      addstatement(newstatement,
                          CCallNode.createintern('fpc_help_destructor',para));
                    end
                else
                  InternalError(200305105);
              end;
            CurrentSettings.LocalSwitches:=oldlocalswitches;
          end;
      end;


{****************************************************************************
                                  TCGProcInfo
****************************************************************************}

     destructor TCGProcInfo.Destroy;
       begin
         TFPList.FreeAndNilDisposing(tempinfo_flags_map,TypeInfo(TTempInfoFlagsEntry));
         code.free;
         code := nil;
         inherited Destroy;
       end;


    function TCGProcInfo.calc_stackframe_size:LongInt;
      begin
        result:=Align(tg.direction*tg.lasttemp,CurrentSettings.Alignment.LocalAlignMin);
      end;


    procedure TCGProcInfo.printproc(pass:string);
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
        WriteLn(PrintNodeFile, pass);
        WriteLn(PrintNodeFile,procdef.FullProcName(false));
        WriteLn(PrintNodeFile,'*******************************************************************************');
        printnode(PrintNodeFile,code);
        close(PrintNodeFile);
      end;


    procedure TCGProcInfo.maybe_add_constructor_wrapper(var tocode: TNode; withexceptblock: boolean);
      var
        oldlocalswitches: TLocalSwitches;
        srsym: TSym;
        constructionblock,
        exceptblock,
        newblock: TBlockNode;
        newstatement: TStatementNode;
        pd: TProcDef;
        constructionsuccessful: TLocalVarSym;
      begin
        if Assigned(procdef.struct) and
           (procdef.ProcTypeOption=potype_constructor) then
          begin
            { Don't test self and the vmt here. See generate_bodyexit_block }
            { why (JM)                                                      }
            oldlocalswitches:=CurrentSettings.LocalSwitches;
            CurrentSettings.LocalSwitches:=oldlocalswitches-[cs_check_object,cs_check_range];

            { call AfterConstruction for classes }
            constructionsuccessful:=nil;
            if Is_Class(procdef.struct) then
              begin
                constructionsuccessful:=CLocalVarSym.create(InternalTypePrefixName[itp_vmt_afterconstruction_local],vs_value,PtrSIntType,[]);
                procdef.LocalST.InsertSym(constructionsuccessful,false);
                srsym:=Search_Struct_Member(procdef.struct,'AFTERCONSTRUCTION');
                if not Assigned(srsym) or
                   (srsym.typ<>ProcSym) then
                  InternalError(200305106);

                CurrentFilePos:=entrypos;
                constructionblock:=internalstatements(newstatement);
                { initialise constructionsuccessful with -1, indicating that
                  the construction was not successful and hence
                  beforedestruction should not be called if a destructor is
                  called from the constructor }
                addstatement(newstatement,CAssignmentNode.create(
                  CLoadNode.create(constructionsuccessful,procdef.LocalST),
                  genintconstnode(-1))
                );
                { first execute all constructor code. If no exception
                  occurred then we will execute afterconstruction,
                  otherwise we won't (the exception will jump over us) }
                addstatement(newstatement,tocode);
                CurrentFilePos:=exitpos;
                { if implicit finally node wasn't created, then exit label and
                  finalization code must be handled here and placed before
                  afterconstruction }
                if not ((pi_needs_implicit_finally in flags) and
                  (cs_implicit_exceptions in CurrentSettings.ModuleSwitches)) then
                  begin
                    include(tocode.flags,nf_block_with_exit);
                    if procdef.ProcTypeOption<>potype_exceptfilter then
                      addstatement(newstatement,CFinalizeTempsNode.create);
                    CNodeUtils.procdef_block_add_implicit_finalize_nodes(procdef,newstatement);
                    temps_finalized:=true;
                  end;

                { construction successful -> beforedestruction should be called
                  if an exception happens now }
                addstatement(newstatement,CAssignmentNode.create(
                  CLoadNode.create(constructionsuccessful,procdef.LocalST),
                  genintconstnode(1))
                );
                { Self can be nil when fail is called }
                { if self<>nil and vmt<>nil then afterconstruction }
                addstatement(newstatement,CIfNode.create(
                  CAddNode.create(andn,
                    CAddNode.create(unequaln,
                      load_self_node,
                      CNilNode.create),
                    CAddNode.create(unequaln,
                      load_vmt_pointer_node,
                      CNilNode.create)),
                    CCallNode.create(nil,TProcSym(srsym),srsym.owner,load_self_node,[],nil),
                    nil));
                tocode:=constructionblock;
              end;

            if withexceptblock and (procdef.struct.typ=objectdef) then
              begin
                { Generate the implicit "fail" code for a constructor (destroy
                  in case an exception happened) }
                pd:=TObjectDef(procdef.struct).Find_Destructor;
                { this will always be the case for classes, since tobject has
                  a destructor }
                if Assigned(pd) or Is_Object(procdef.struct) then
                  begin
                    CurrentFilePos:=exitpos;
                    exceptblock:=internalstatements(newstatement);
                    { first free the instance if non-nil }
                    if Assigned(pd) then
                      { if vmt<>0 then call destructor }
                      addstatement(newstatement,
                        CIfNode.create(
                          CAddNode.create(unequaln,
                            load_vmt_pointer_node,
                            CNilNode.create),
                          { cnf_create_failed -> don't call BeforeDestruction }
                          CCallNode.create(nil,TProcSym(pd.ProcSym),pd.ProcSym.owner,load_self_node,[cnf_create_failed],nil),
                          nil))
                    else
                      { object without destructor, call 'fail' helper }
                      addstatement(newstatement,
                        CCallNode.createintern('fpc_help_fail',
                          CCallParaNode.create(
                            COrdConstNode.create(TObjectDef(procdef.struct).VMT_Offset,S32IntType,false),
                          CCallParaNode.create(
                            CTypeConvNode.Create_Internal(
                              load_vmt_pointer_node,
                              VoidPointerType),
                          CCallParaNode.create(
                            CTypeConvNode.Create_Internal(
                              load_self_pointer_node,
                              VoidPointerType),
                          nil))))
                      );
                    { then re-raise the exception }
                    addstatement(newstatement,CRaiseNode.create(nil,nil,nil));
                    CurrentFilePos:=entrypos;
                    newblock:=internalstatements(newstatement);
                    { try
                        tocode
                      except
                        exceptblock
                      end
                    }
                    addstatement(newstatement,CTryExceptNode.create(
                      tocode,
                      nil,
                      exceptblock));
                    tocode:=newblock;
                  end;
              end;
            CurrentSettings.LocalSwitches:=oldlocalswitches;
          end;
      end;


    procedure TCGProcInfo.add_entry_exit_code;
      var
        finalcode,
        bodyentrycode,
        bodyexitcode,
        wrappedbody,
        newblock     : TNode;
        codestatement,
        newstatement : TStatementNode;
        oldfilepos   : TFilePosInfo;
        is_constructor: boolean;
      begin
        is_constructor:=Assigned(procdef.struct) and
          (procdef.ProcTypeOption=potype_constructor);

        oldfilepos:=CurrentFilePos;
        { Generate code/locations used at start of proc }
        CurrentFilePos:=entrypos;
        entry_asmnode:=CAsmNode.create_get_position;
        loadpara_asmnode:=CAsmNode.create_get_position;
        stackcheck_asmnode:=CAsmNode.create_get_position;
        init_asmnode:=CAsmNode.create_get_position;
        bodyentrycode:=generate_bodyentry_block;
        { Generate code/locations used at end of proc }
        CurrentFilePos:=exitpos;
        exitlabel_asmnode:=CAsmNode.create_get_position;
        temps_finalized:=false;
        bodyexitcode:=generate_bodyexit_block;
        { Check if bodyexitcode is not empty }
        with TStatementNode(TBlockNode(bodyexitcode).statements) do
          if (statement.nodetype<>nothingn) or Assigned(next) then
            { Indicate that the extra code is executed after the exit statement }
            include(flowcontrol,fc_no_direct_exit);

        { Generate procedure by combining init+body+final,
          depending on the implicit finally we need to add
          an try...finally...end wrapper }
        CurrentFilePos:=entrypos;
        newblock:=internalstatements(newstatement);
        { Note - this is not strippable since it wraps the entire procedure }
        Exclude(TBlockNode(newblock).blocknodeflags, bnf_strippable);
        { initialization is common for all cases }
        addstatement(newstatement,loadpara_asmnode);
        addstatement(newstatement,stackcheck_asmnode);
        addstatement(newstatement,entry_asmnode);
        CNodeUtils.procdef_block_add_implicit_initialize_nodes(procdef,newstatement);
        addstatement(newstatement,init_asmnode);
        if Assigned(procdef.ParentFPInitBlock) then
          begin
            if Assigned(TBlockNode(procdef.ParentFPInitBlock).left) then
              begin
                if CNodeUtils.check_insert_trashing(procdef) then
                  CNodeUtils.maybe_trash_variable(newstatement,TAbstractNormalVarSym(procdef.ParentFPStruct),CLoadNode.create(procdef.ParentFPStruct,procdef.ParentFPStruct.owner));
                { could be an asmn in case of a pure assembler procedure,
                  but those shouldn't access nested variables }
                addstatement(newstatement,procdef.ParentFPInitBlock);
              end
            else
              procdef.ParentFPInitBlock.free;
            procdef.ParentFPInitBlock:=nil;
          end;
        addstatement(newstatement,bodyentrycode);

        if (cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and
           (pi_needs_implicit_finally in flags) and
           { but it's useless in init/final code of units }
           not(procdef.ProcTypeOption in [potype_unitfinalize,potype_unitinit]) and
           (f_exceptions in Features) then
          begin
            { Any result of managed type must be returned in parameter }
            if Is_Managed_Type(procdef.ReturnDef) and
               (not ParaManager.Ret_In_Param(procdef.ReturnDef,procdef)) and
               (not Is_Class(procdef.ReturnDef)) then
               InternalError(2013121301);

            { Generate special exception block only needed when
              implicit finally is used }
            CurrentFilePos:=exitpos;
            { Generate code that will be in the try...finally }
            finalcode:=internalstatements(codestatement);
            if procdef.ProcTypeOption<>potype_exceptfilter then
              addstatement(codestatement,CFinalizeTempsNode.create);
            CNodeUtils.procdef_block_add_implicit_finalize_nodes(procdef,codestatement);
            temps_finalized:=true;

            CurrentFilePos:=entrypos;
            wrappedbody:=CTryFinallyNode.create_implicit(code,finalcode);
            { afterconstruction must be called after finalizetemps, because it
               has to execute after the temps have been finalised in case of a
               refcounted class (afterconstruction decreases the refcount
               without freeing the instance if the count becomes nil, while
               the finalising of the temps can free the instance) }
            maybe_add_constructor_wrapper(wrappedbody,true);
            addstatement(newstatement,wrappedbody);
            addstatement(newstatement,exitlabel_asmnode);
            addstatement(newstatement,bodyexitcode);
            { set flag the implicit finally has been generated }
            include(flags,pi_has_implicit_finally);
          end
        else
          begin
            { constructors need destroy-on-exception code even if they don't
              have managed variables/temps }
            maybe_add_constructor_wrapper(code,
              (cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and (f_exceptions in Features));
            CurrentFilePos:=entrypos;
            addstatement(newstatement,code);
            CurrentFilePos:=exitpos;
            if Assigned(nestedexitlabel) then
              addstatement(newstatement,CLabelNode.create(CNothingNode.create,nestedexitlabel));
            addstatement(newstatement,exitlabel_asmnode);
            addstatement(newstatement,bodyexitcode);
            if not is_constructor then
              begin
                if procdef.ProcTypeOption<>potype_exceptfilter then
                  addstatement(newstatement,CFinalizeTempsNode.create);
                CNodeUtils.procdef_block_add_implicit_finalize_nodes(procdef,newstatement);
                temps_finalized:=true;
              end;
          end;
        if not temps_finalized then
          begin
            CurrentFilePos:=exitpos;
            CNodeUtils.procdef_block_add_implicit_finalize_nodes(procdef,newstatement);
          end;
        DoFirstPass(newblock);
        code:=newblock;
        CurrentFilePos:=oldfilepos;
      end;


    procedure clearrefs(p:TObject;arg:pointer);
      begin
         if (TSym(p).typ in [localvarsym,paravarsym,staticvarsym]) then
           if TAbstractVarSym(p).refs>1 then
             TAbstractVarSym(p).refs:=1;
      end;


    procedure Translate_Registers(p:TObject;list:pointer);
      begin
         if (TSym(p).typ in [localvarsym,paravarsym,staticvarsym]) and
            (TAbstractNormalVarSym(p).LocAlloc.Loc in [LOC_REGISTER,LOC_CREGISTER,LOC_MMREGISTER,
              LOC_CMMREGISTER,LOC_FPUREGISTER,LOC_CFPUREGISTER]) then
           begin
             if not(cs_no_regalloc in CurrentSettings.GlobalSwitches) then
               begin
                 cg.Translate_Register(TAbstractNormalVarSym(p).LocAlloc.Register);
                 if (TAbstractNormalVarSym(p).LocAlloc.RegisterHi<>NR_NO) then
                   cg.Translate_Register(TAbstractNormalVarSym(p).LocAlloc.RegisterHi);
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

    procedure TCGProcInfo.setup_tempgen;
      begin
        tg:=tgobjclass.create;

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
            if ((po_assembler in procdef.ProcOptions) and
               (m_delphi in CurrentSettings.ModeSwitches) and
               { localst at main_program_level is a staticsymtable }
                (procdef.LocalST.SymTableLevel<>MainProgramLevel) and
                (TAbstractLocalSymTable(procdef.LocalST).Count_Locals = 0)) or
               ((cs_opt_stackframe in CurrentSettings.OptimizerSwitches) and
                not(cs_generate_stackframes in CurrentSettings.LocalSwitches) and
                not(po_assembler in procdef.ProcOptions) and
{$if defined(aarch64)}
               { on aarch64, it must be a leaf subroutine }
                not(pi_do_call in flags) and
{$endif defined(aarch64)}
                not ((pi_has_stackparameter in flags)
{$if defined(i386) or defined(x86_64)}
               { Outgoing parameter(s) on stack do not need stackframe on x86 targets
                 with fixed stack. On ARM it fails, see bug #25050 }
                  and (not ParaManager.Use_Fixed_Stack)
{$endif defined(i386) or defined(x86_64)}
                  ) and
                ((flags*([pi_has_assembler_block,pi_is_assembler,
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
                generate_parameter_info;

                if not(procdef.Stack_Tainting_Parameter(calleeside)) and
                   not(has_assembler_child)
                  { parasize must be really zero, this means also that no result may be returned
                    in a parameter }
                  and not((CurrentProcInfo.procdef.ProcCallOption in ClearStack_PoCalls) and
                  not(CurrentProcInfo.procdef.Generate_SafeCall_Wrapper) and
                  ParaManager.Ret_In_Param(CurrentProcInfo.procdef.ReturnDef,CurrentProcInfo.procdef)) then
                  begin
                    { Only need to set the framepointer }
                    framepointer:=NR_STACK_POINTER_REG;
                    tg.direction:=1;
                    Include(flags,pi_no_framepointer_needed)
                  end
              end;
          end;
{$endif}
        { set the start offset to the start of the temp area in the stack }
        set_first_temp_offset;
      end;


    procedure TCGProcInfo.TransformNodeTree;
      var
        i : integer;
        UserCode : TNode;
        updated,
        RedoDFA : boolean;
      begin
       { inlining is a heuristics, so we do this very early }
       do_optinline(code,updated);

       { do this before adding the entry code else the tail recursion recognition won't work,
         if this causes troubles, it must be if'ed
       }
       if (cs_opt_tailrecursion in CurrentSettings.OptimizerSwitches) and
         (pi_is_recursive in flags) then
         do_opttail(code,procdef);

       if cs_opt_constant_propagate in CurrentSettings.OptimizerSwitches then
         begin
           do_optconstpropagate(code,RedoDFA);
           { RedoDFA value not used here }
           RedoDFA:=false;
         end;

       if (cs_opt_nodedfa in CurrentSettings.OptimizerSwitches) and
         { creating dfa is not always possible }
         ((flags*[pi_has_assembler_block,pi_uses_exceptions,pi_is_assembler])=[]) then
         begin
           dfabuilder:=TDFABuilder.Create;
           dfabuilder.createdfainfo(code);
           include(flags,pi_dfaavailable);
           RedoDFA:=false;

           if cs_opt_constant_propagate in CurrentSettings.OptimizerSwitches then
             begin
               do_optconstpropagate(code,RedoDFA);
               if RedoDFA then
                 begin
                   dfabuilder.redodfainfo(code);
                   RedoDFA:=false; { Don't redo it again unless necessary }
                 end;
               { Don't re-run constant propagation as redoing DFA info didn't
                 actually change any nodes }
             end;

           if (cs_opt_loopstrength in CurrentSettings.OptimizerSwitches)
             { our induction variable strength reduction doesn't like
               for loops with more than one entry }
             and not(pi_has_label in flags) then
             begin
               RedoDFA:=OptimizeInductionVariables(code);
             end;

           if RedoDFA then
             begin
               dfabuilder.redodfainfo(code);
               RedoDFA:=false; { Don't redo it again unless necessary }
             end;

           if cs_opt_forloop in CurrentSettings.OptimizerSwitches then
             RedoDFA:=OptimizeForLoop(code);

           RedoDFA:=ConvertForLoops(code) or RedoDFA;

           if cs_opt_forloop in CurrentSettings.OptimizerSwitches then
             RedoDFA:=optimize_record_writes(code) or RedoDFA;

           if RedoDFA then
             dfabuilder.redodfainfo(code);

           { when life info is available, we can give more sophisticated warning about uninitialized
             variables ...
             ... but not for the finalization section of a unit, we would need global dfa to handle
             it properly }
           if potype_unitfinalize<>procdef.ProcTypeOption then
             { iterate through life info of the first node }
             for i:=0 to dfabuilder.nodemap.count-1 do
               begin
                 UserCode:=GetUserCode();
                 if DynSetIn(UserCode.optinfo^.life,i) then
                   begin
                     { do not warn for certain parameters: }
                     if not((TNode(dfabuilder.nodemap[i]).nodetype=loadn) and (TLoadNode(dfabuilder.nodemap[i]).symtableentry.typ=paravarsym) and
                       { do not warn about parameters passed by var }
                       (((TParaVarSym(TLoadNode(dfabuilder.nodemap[i]).symtableentry).VarSpez=vs_var) and
                       { function result is passed by var but it must be initialized }
                       not(vo_is_funcret in TParaVarSym(TLoadNode(dfabuilder.nodemap[i]).symtableentry).VarOptions)) or
                       { do not warn about initialized hidden parameters }
                       ((TParaVarSym(TLoadNode(dfabuilder.nodemap[i]).symtableentry).VarOptions*[vo_is_high_para,vo_is_parentfp,vo_is_result,vo_is_self])<>[]))) then
                       CheckAndWarn(UserCode,TNode(dfabuilder.nodemap[i]));
                   end
                 else
                   begin
                     if (TNode(dfabuilder.nodemap[i]).nodetype=loadn) and
                       (TLoadNode(dfabuilder.nodemap[i]).symtableentry.typ in [staticvarsym,localvarsym]) then
                       TAbstractNormalVarSym(TLoadNode(dfabuilder.nodemap[i]).symtableentry).NoRegVarInitNeeded:=true
                   end;
               end;

           if cs_opt_dead_store_eliminate in CurrentSettings.OptimizerSwitches then
             begin
               if normalize(code) then
                 begin
                   do_optdeadstoreelim(code,RedoDFA);
                   if RedoDFA then
                     dfabuilder.redodfainfo(code);
                 end;
             end;
         end
       else
         begin
           ConvertForLoops(code);
           if cs_opt_forloop in CurrentSettings.OptimizerSwitches then
             optimize_record_writes(code);
         end;

       if (cs_opt_remove_empty_proc in CurrentSettings.OptimizerSwitches) and
         (procdef.ProcTypeOption in [potype_operator,potype_procedure,potype_function]) and
         (code.nodetype=blockn) and (TBlockNode(code).statements=nil) then
         procdef.isempty:=true;

       if cs_opt_nodecse in CurrentSettings.OptimizerSwitches then
         do_optcse(code);

       if cs_opt_use_load_modify_store in CurrentSettings.OptimizerSwitches then
         do_optloadmodifystore(code);

       if (cs_opt_consts in CurrentSettings.OptimizerSwitches) and
          { non-local gotos can cause an fpc_setjmp call to be generated before
            this block, which means the loaded value won't be loaded when the
             longjmp is performed }
          not(m_non_local_goto in CurrentSettings.ModeSwitches) then
         do_consttovar(code);
      end;


    function TCGProcInfo.has_assembler_child : boolean;
      var
        hp : TProcInfo;
      begin
        result:=false;
        hp:=get_first_nestedproc;
        while Assigned(hp) do
          begin
            if (hp.flags*[pi_has_assembler_block,pi_is_assembler])<>[] then
              begin
                result:=true;
                exit;
              end;
            hp:=TProcInfo(hp.next);
          end;
      end;


    procedure TCGProcInfo.set_eh_info;
      begin
        inherited;
         if (tf_use_psabieh in TargetInfo.flags) and
            ((pi_uses_exceptions in flags) or
             ((cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and
              (pi_needs_implicit_finally in flags))) or
             (pi_has_except_table_data in flags) then
           procdef.Personality:=Search_System_Proc('_FPC_PSABIEH_PERSONALITY_V0');
      end;


    function TCGProcInfo.store_node_tempflags(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        nodeset : THashSet absolute arg;
        entry : PTempInfoFlagsEntry;
        i : LongInt;
        {hashsetitem: PHashSetItem;}
      begin
        result:=fen_true;
        case n.nodetype of
          tempcreaten:
            begin
              {$ifdef EXTDEBUG}
              comment(VDebug,'keeping track of new temp node: '+HexStr(TTempBaseNode(n).tempinfo));
              {$endif EXTDEBUG}
              nodeset.FindOrAdd(TTempBaseNode(n).tempinfo,sizeof(pointer));
            end;
          tempdeleten:
            begin
              {$ifdef EXTDEBUG}
              comment(VDebug,'got temp delete node: '+HexStr(TTempBaseNode(n).tempinfo));
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
              comment(VDebug,'found temp ref node: '+HexStr(TTempBaseNode(n).tempinfo));
              {$endif EXTDEBUG}
              if not Assigned(nodeset.find(TTempBaseNode(n).tempinfo,sizeof(pointer))) then
                begin
                  for i:=0 to tempinfo_flags_map.count-1 do
                    begin
                      entry:=PTempInfoFlagsEntry(tempinfo_flags_map[i]);
                      {$ifdef EXTDEBUG}
                      comment(VDebug,'comparing with tempinfo: '+HexStr(entry^.tempinfo));
                      {$endif EXTDEBUG}
                      if entry^.tempinfo=TTempBaseNode(n).tempinfo then
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
                  new(entry);
                  entry^.tempinfo:=TTempBaseNode(n).tempinfo;
                  entry^.flags:=TTempInfoAccessor.gettempinfoflags(entry^.tempinfo);
                  tempinfo_flags_map.add(entry);
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


    procedure TCGProcInfo.store_tempflags;
      var
        nodeset : THashSet;
      begin
        if Assigned(tempinfo_flags_map) then
          InternalError(2020040601);
        {$ifdef EXTDEBUG}
        comment(VDebug,'storing temp nodes of '+procdef.MangledName);
        {$endif EXTDEBUG}
        tempinfo_flags_map:=TFPList.create;
        nodeset:=THashSet.Create(32,false,false);
        foreachnode(code,@store_node_tempflags,nodeset);
        nodeset.free;
        nodeset := nil;
      end;


    procedure TCGProcInfo.swap_tempflags;
      var
        entry : PTempInfoFlagsEntry;
        i : LongInt;
        tempflags : TTempInfoFlags;
      begin
        if not Assigned(tempinfo_flags_map) then
          exit;
        for i:=0 to tempinfo_flags_map.count-1 do
          begin
            entry:=PTempInfoFlagsEntry(tempinfo_flags_map[i]);
            tempflags:=TTempInfoAccessor.gettempinfoflags(entry^.tempinfo);
            TTempInfoAccessor.settempinfoflags(entry^.tempinfo,entry^.flags);
            entry^.flags:=tempflags;
          end;
      end;


    procedure TCGProcInfo.apply_tempflags;
      begin
        if tempflags_swapped then
          InternalError(2020040602);
        swap_tempflags;
        tempflags_swapped:=true;
      end;


    procedure TCGProcInfo.reset_tempflags;
      begin
        if not tempflags_swapped then
          InternalError(2020040603);
        swap_tempflags;
        tempflags_swapped:=false;
      end;



    procedure TCGProcInfo.generate_code_tree;
      var
        hpi : TCGProcInfo;
      begin
        { generate code for this procedure }
        generate_code;
        { process nested procedures }
        hpi:=TCGProcInfo(get_first_nestedproc);
        while Assigned(hpi) do
          begin
            if not (df_generic in hpi.procdef.DefOptions) then
              hpi.generate_code_tree;
            hpi:=TCGProcInfo(hpi.next);
          end;
        resetprocdef;
      end;


    procedure TCGProcInfo.generate_code_exceptfilters;
      var
        hpi : TCGProcInfo;
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
            exceptfilter_parent_tempend:=tg.lasttemp;
            tg.discard_freelist;
          end;
        hpi:=TCGProcInfo(get_first_nestedproc);
        while Assigned(hpi) do
          begin
            if (hpi.procdef.ProcTypeOption=potype_exceptfilter) and
               Assigned(hpi.code) then
              begin
                hpi.apply_tempflags;
                generate_exceptfilter(hpi);
                hpi.reset_tempflags;
              end;
            hpi:=TCGProcInfo(hpi.next);
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

    procedure TCGProcInfo.generate_exceptfilter(nestedpi: TCGProcInfo);
      var
        saved_cg: TCG;
        saved_hlcg: THLCGObj;
{$ifdef cpu64bitalu}
        saved_cg128 : TCG128;
{$else cpu64bitalu}
        saved_cg64 : TCG64;
{$endif cpu64bitalu}
      begin
        if nestedpi.procdef.ProcTypeOption<>potype_exceptfilter then
          InternalError(201201141);
        { flush code generated this far }
        aktproccode.ConcatList(CurrentAsmData.CurrAsmList);
        { save the codegen }
        saved_cg:=cg;
        saved_hlcg:=hlcg;
        cg:=nil;
        hlcg:=nil;
{$ifdef cpu64bitalu}
        saved_cg128:=cg128;
        cg128:=nil;
{$else cpu64bitalu}
        saved_cg64:=cg64;
        cg64:=nil;
{$endif cpu64bitalu}
        nestedpi.generate_code;
        { prevents generating code the second time when processing nested procedures }
        nestedpi.resetprocdef;
        cg:=saved_cg;
        hlcg:=saved_hlcg;
{$ifdef cpu64bitalu}
        cg128:=saved_cg128;
{$else cpu64bitalu}
        cg64:=saved_cg64;
{$endif cpu64bitalu}
        Add_Reg_Instruction_Hook:=@cg.Add_Reg_Instruction;
      end;


    procedure TCGProcInfo.generate_exit_label(list: TAsmList);
      begin
        hlcg.A_Label(list,CurrExitLabel);
      end;


    procedure TCGProcInfo.Convert_Captured_Syms;
      var
        hpi : TCGProcInfo;
        old_current_procinfo : TProcInfo;
      begin
        { do the conversion only if there haven't been any errors so far }
        if ErrorCount<>0 then
          exit;
        old_current_procinfo:=CurrentProcInfo;
        CurrentProcInfo:=self;
        { process nested procedures }
        hpi:=TCGProcInfo(get_first_nestedproc);
        while Assigned(hpi) do
          begin
            hpi.Convert_Captured_Syms;
            hpi:=TCGProcInfo(hpi.next);
          end;
        { convert the captured symbols for this routine }
        if Assigned(code) then
          procdefutil.Convert_Captured_Syms(procdef,code);
        CurrentProcInfo:=old_current_procinfo;
      end;


     procedure TCGProcInfo.CreateInlineInfo;
       begin
        new(procdef.InliningInfo);
        procdef.InliningInfo^.code:=code.GetCopy;
        procdef.InliningInfo^.flags:=flags;
        { The blocknode needs to set an exit label }
        if procdef.InliningInfo^.code.nodetype=blockn then
          include(procdef.InliningInfo^.code.flags,nf_block_with_exit);
        procdef.HasInliningInfo:=true;
        export_local_ref_syms;
        export_local_ref_defs;
       end;

    procedure searchthreadvar(p: TObject; arg: pointer);
      var
        i : LongInt;
        pd : TProcDef;
      begin
        case TSym(p).typ of
          staticvarsym :
            begin
                  { local (procedure or unit) variables only need finalization
                    if they are used
                  }
              if (vo_is_thread_var in TStaticVarSym(p).VarOptions) and
                 ((TStaticVarSym(p).refs>0) or
                  { global (unit) variables always need finalization, since
                    they may also be used in another unit
                  }
                  (TStaticVarSym(p).owner.SymTableType=GlobalSymTable)) and
                  (
                    (TStaticVarSym(p).VarSpez<>vs_const) or
                    (vo_force_finalize in TStaticVarSym(p).VarOptions)
                  ) and
                 not(vo_is_funcret in TStaticVarSym(p).VarOptions) and
                 not(vo_is_external in TStaticVarSym(p).VarOptions) and
                 Is_Managed_Type(TStaticVarSym(p).vardef) then
                include(CurrentProcInfo.flags,pi_uses_threadvar);
            end;
          ProcSym :
            begin
              for i:=0 to TProcSym(p).ProcdefList.Count-1 do
                begin
                  pd:=TProcDef(TProcSym(p).ProcdefList[i]);
                  if Assigned(pd.LocalST) and
                     (pd.ProcSym=TProcSym(p)) and
                     (pd.LocalST.SymTableType<>staticsymtable) then
                    pd.LocalST.SymList.ForEachCall(@searchthreadvar,arg);
                end;
            end;
          else
            ;
        end;
      end;


    function searchusercode(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        if nf_usercode_entry in n.flags then
          begin
            PNode(arg)^:=n;
            result:=fen_norecurse_true
          end
        else
          result:=fen_false;
      end;


    function TCGProcInfo.GetUserCode : TNode;
      var
        n : TNode;
      begin
        n:=nil;
        foreachnodestatic(code,@searchusercode,@n);
        if not(Assigned(n)) then
          InternalError(2013111004);
        result:=n;
      end;


    procedure TCGProcInfo.generate_code;

       procedure check_for_threadvars_in_initfinal;
         begin
           if CurrentProcInfo.procdef.ProcTypeOption=potype_unitfinalize then
             begin
                { this is also used for initialization of variables in a
                  program which does not have a globalsymtable }
                if Assigned(CurrentModule.GlobalSymTable) then
                  TSymTable(CurrentModule.GlobalSymTable).SymList.ForEachCall(@searchthreadvar,nil);
                TSymTable(CurrentModule.LocalSymTable).SymList.ForEachCall(@searchthreadvar,nil);
             end;
         end;

       function heuristics_favors_autoinlining(code: TNode): boolean;
         var
           complexityAvail : integer;
         begin
           { rough approximation if we should auto inline:
             - if the tree is simple enough
             - if the tree is not too big
             A bigger tree which is simpler might be autoinlined otoh
             a smaller and complexer tree as well: so we use the sum of
             both measures here }

           { This is a shortcutted version of
             "result:=node_count(code)+node_complexity(code)<=25". }
           complexityAvail:=25-node_complexity(code);
           result:=(complexityAvail>0) and (node_count(code,complexityAvail+1)<=dword(complexityAvail));
         end;

      var
        old_current_procinfo : TProcInfo;
        oldmaxfpuregisters : LongInt;
        oldfilepos : TFilePosInfo;
        old_current_structdef : TAbstractRecordDef;
        oldswitches : TLocalSwitches;
        templist : TAsmList;
        headertai : TAI;

      procedure delete_marker(anode: TAsmNode);
        var
          ai: TAI;
        begin
          if Assigned(anode) then
            begin
              ai:=anode.currenttai;
              if Assigned(ai) then
                begin
                  aktproccode.remove(ai);
                  ai.free;
                  ai := nil;
                  anode.currenttai:=nil;
                end;
            end;
        end;

      begin
        { the initialization procedure can be empty, then we
          don't need to generate anything. When it was an empty
          procedure there would be at least a blocknode }
        if not Assigned(code) then
          begin
            exit;
          end;

        { We need valid code }
        if ErrorCount<>0 then
          exit;

        { No code can be generated for generic template }
        if (df_generic in procdef.DefOptions) then
          InternalError(200511152);

        { For regular procedures the RA and Tempgen shall not be available yet,
          but exception filters reuse Tempgen of parent }
        if Assigned(tg)<>(procdef.ProcTypeOption=potype_exceptfilter) then
          InternalError(200309201);

        old_current_procinfo:=CurrentProcInfo;
        oldfilepos:=CurrentFilePos;
        old_current_structdef:=CurrentStructDef;
        oldmaxfpuregisters:=CurrentSettings.MaxFPURegisters;

        CurrentProcInfo:=self;
        CurrentFilePos:=entrypos;
        CurrentStructDef:=procdef.struct;

        { store start of user code, it must be a block node, it will be used later one to
          check variable lifeness }
        include(code.flags,nf_usercode_entry);

        { add wrapping code if necessary (initialization of typed constants on
          some platforms, initing of local variables and out parameters with
          trashing values, ...) }
        { init/final code must be wrapped later (after code for main proc body
          has been generated) }
        if not(CurrentProcInfo.procdef.ProcTypeOption in [potype_unitinit,potype_unitfinalize]) then
          code:=CNodeUtils.wrap_proc_body(procdef,code);

        { automatic inlining? }
        if (cs_opt_autoinline in CurrentSettings.OptimizerSwitches) and
           not(po_noinline in procdef.ProcOptions) and
           { no inlining yet? }
           not(procdef.HasInliningInfo) and not(has_nestedprocs) and
            not(procdef.ProcTypeOption in [potype_proginit,potype_unitinit,potype_unitfinalize,potype_constructor,
                                           potype_destructor,potype_class_constructor,potype_class_destructor]) and
            ((procdef.ProcOptions*[po_exports,po_external,po_interrupt,po_virtualmethod,po_iocheck])=[]) and
            (not(procdef.ProcCallOption in [pocall_safecall])) and
            heuristics_favors_autoinlining(code) then
          begin
            { Can we inline this procedure? }
            if checknodeinlining(procdef) then
              begin
                Message1(cg_d_autoinlining,procdef.GetTypeName);
                include(procdef.ProcOptions,po_inline);
                CreateInlineInfo;
              end;
          end;

        templist:=TAsmList.create;

        { add parast/localst to symtablestack }
        add_to_symtablestack;

        { clear register count }
        procdef.LocalST.SymList.ForEachCall(@clearrefs,nil);
        procdef.ParaST.SymList.ForEachCall(@clearrefs,nil);

        { there's always a call to FPC_INITIALIZEUNITS/FPC_DO_EXIT in the main program }
        if (procdef.LocalST.SymTableLevel=MainProgramLevel) and
           (not CurrentModule.IsUnit) then
          begin
            include(flags,pi_do_call);
            { the main program never returns due to the do_exit call }
            if not(CurrentModule.IsLibrary) and (procdef.ProcTypeOption=potype_proginit) then
              include(procdef.ProcOptions,po_noreturn);
          end;

        { set implicit_finally flag when there are locals/paras to be finalized }
        if not(po_assembler in CurrentProcInfo.procdef.ProcOptions) then
          begin
            procdef.ParaST.SymList.ForEachCall(@check_finalize_paras,nil);
            procdef.LocalST.SymList.ForEachCall(@check_finalize_locals,nil);
          end;

{$ifdef SUPPORT_SAFECALL}
        { set implicit_finally flag for if procedure is safecall }
        if (tf_safecall_exceptions in TargetInfo.flags) and
           (procdef.ProcCallOption=pocall_safecall) then
          include(flags, pi_needs_implicit_finally);
{$endif}

        { firstpass everything }
        flowcontrol:=[];
        DoFirstPass(code);

{$if defined(i386)}
        if node_resources_fpu(code)>0 then
          include(flags,pi_uses_fpu);
{$endif i386}

        { Print the node to tree.log }
        if ParaPrintNodeTree <> 0 then
          printproc( 'after the firstpass');

        { A failed first pass can leave unresolved helper calls in the tree. }
        if ErrorCount=0 then
          TransformNodeTree;

        { unit static/global symtables might contain threadvars which are not explicitly used but which might
          require a tls register, so check for such variables }
        check_for_threadvars_in_initfinal;

        { add implicit entry and exit code }
        add_entry_exit_code;

        { only do secondpass if there are no errors }
        if (ErrorCount<>0) then
          begin
          end
        else
          begin
            Create_HLCodeGen(nil);

            setup_eh;

            if (procdef.ProcTypeOption<>potype_exceptfilter) then
              setup_tempgen;

            { Create register allocator, must come after framepointer is known }
            hlcg.Init_Register_Allocators;

            generate_parameter_info;

            { allocate got register if needed }
            allocate_got_register(aktproccode);

            { allocate got register if needed }
            allocate_tls_register(aktproccode);

            { Allocate space in temp/registers for parast and localst }
            CurrentFilePos:=entrypos;
            gen_alloc_symtable(aktproccode,procdef,procdef.ParaST);
            gen_alloc_symtable(aktproccode,procdef,procdef.LocalST);

            { Store temp offset for information about 'real' temps }
            tempstart:=tg.lasttemp;

            { Generate code to load register parameters in temps and insert local
              copies for values parameters. This must be done before the code for the
              body is generated because the localloc is updated.
              Note: The generated code will be inserted after the code generation of
              the body is finished, because only then the position is known }
            CurrentFilePos:=entrypos;

            hlcg.Gen_Load_Para_Value(templist);

            { caller paraloc info is also necessary in the stackframe_entry
              code of the ppc (and possibly other processors)               }
            procdef.Init_ParaLoc_Info(callerside);

            CalcExecutionWeights(code);

            { Print the node to tree.log }
            if ParaPrintNodeTree <> 0 then
              printproc( 'right before code generation');


            { generate code for the node tree }
            DoSecondPass(code);
            aktproccode.ConcatList(CurrentAsmData.CurrAsmList);

            { The position of the loadpara_asmnode is now known }
            aktproccode.InsertListAfter(loadpara_asmnode.currenttai,templist);

            oldswitches:=CurrentSettings.LocalSwitches;

            { first generate entry and initialize code with the correct
              position and switches }
            CurrentFilePos:=entrypos;
            CurrentSettings.LocalSwitches:=entryswitches;

            cg.Set_RegAlloc_Live_Range_Direction(rad_backwards);

            hlcg.Gen_Entry_Code(templist);
            aktproccode.InsertListAfter(entry_asmnode.currenttai,templist);
            hlcg.Gen_Initialize_Code(templist);
            aktproccode.InsertListAfter(init_asmnode.currenttai,templist);

            { now generate finalize and exit code with the correct position
              and switches }
            CurrentFilePos:=exitpos;
            CurrentSettings.LocalSwitches:=exitswitches;

            cg.Set_RegAlloc_Live_Range_Direction(rad_forward);

            if Assigned(finalize_procinfo) then
              begin
                if TargetInfo.system in [system_aarch64_win64] then
                  TCGProcInfo(finalize_procinfo).store_tempflags
                else
                  generate_exceptfilter(TCGProcInfo(finalize_procinfo));
              end
            else if not temps_finalized then
              begin
                hlcg.Gen_Finalize_Code(templist);
                { the finalcode must be concatenated if there was no position available,
                  using insertlistafter will result in an insert at the start
                  when currentai=nil }
                aktproccode.ConcatList(templist);
              end;
            { insert exit label at the correct position }
            generate_exit_label(templist);
            if Assigned(exitlabel_asmnode.currenttai) then
              aktproccode.InsertListAfter(exitlabel_asmnode.currenttai,templist)
            else
              aktproccode.ConcatList(templist);
            { exit code }
            hlcg.Gen_Exit_Code(templist);
            aktproccode.ConcatList(templist);

            { reset switches }
            CurrentSettings.LocalSwitches:=oldswitches;

            { generate symbol and save end of header position }
            CurrentFilePos:=entrypos;
            hlcg.Gen_Proc_Symbol(templist);
            headertai:=TAI(templist.last);
            { insert symbol }
            aktproccode.InsertList(templist);

            { Free space in temp/registers for parast and localst, must be
              done after gen_entry_code }
            CurrentFilePos:=exitpos;

            { make sure the got/pic register doesn't get freed in the }
            { middle of a loop                                        }
            if (tf_pic_uses_got in TargetInfo.flags) and
              (pi_needs_got in flags) and
              (got<>NR_NO) then
              cg.A_Reg_Sync(aktproccode,got);

            if (pi_needs_tls in flags) and
              (tlsoffset<>NR_NO) then
              cg.A_Reg_Sync(aktproccode,tlsoffset);

            gen_free_symtable(aktproccode,procdef.LocalST);
            gen_free_symtable(aktproccode,procdef.ParaST);

            { add code that will load the return value, this is not done
              for assembler routines when they didn't reference the result
              variable }
            hlcg.Gen_Load_Return_Value(templist);
            aktproccode.ConcatList(templist);

            { Already reserve all registers for stack checking code and
              generate the call to the helper function }
            if not(tf_no_generic_stackcheck in TargetInfo.flags) and
               (cs_check_stack in entryswitches) and
               not(po_assembler in procdef.ProcOptions) and
               (procdef.ProcTypeOption<>potype_proginit) then
              begin
                CurrentFilePos:=entrypos;
                hlcg.Gen_Stack_Check_Call(templist);
                aktproccode.InsertListAfter(stackcheck_asmnode.currenttai,templist);
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
            CurrentFilePos:=entrypos;
            { load got if necessary }
            cg.G_Maybe_Got_Init(templist);
            aktproccode.InsertListAfter(headertai,templist);

            { init tls if needed }
            cg.G_Maybe_TLS_Init(templist);
            aktproccode.InsertListAfter(stackcheck_asmnode.currenttai,templist);

            { re-enable if more code at the end is ever generated here
            cg.set_regalloc_live_range_direction(rad_forward);
            }


{$ifndef NoOpt}
{$ifndef i386}
            if (cs_opt_scheduler in CurrentSettings.OptimizerSwitches) and
              { do not optimize pure assembler procedures }
              not(pi_is_assembler in flags) then
              preregallocschedule(aktproccode);
{$endif i386}
{$endif NoOpt}

            { The procedure body is finished, we can now
              allocate the registers }
            cg.Do_Register_Allocation(aktproccode,headertai);

            { translate imag. register to their real counter parts
              this is necessary for debuginfo and verbose assembler output
              when SSA will be implemented, this will be more complicated because we've to
              maintain location lists }
            procdef.ParaST.SymList.ForEachCall(@Translate_Registers,templist);
            procdef.LocalST.SymList.ForEachCall(@Translate_Registers,templist);
            if (tf_pic_uses_got in TargetInfo.flags) and (pi_needs_got in flags) and
               not(cs_no_regalloc in CurrentSettings.GlobalSwitches) and
               (got<>NR_NO) then
              cg.Translate_Register(got);

            { Add save and restore of used registers }
            CurrentFilePos:=entrypos;
            gen_save_used_regs(templist);
            { Remember the last instruction of register saving block
              (may be =nil for e.g. assembler procedures) }
            endprologue_ai:=templist.last;
            aktproccode.InsertListAfter(headertai,templist);
            CurrentFilePos:=exitpos;
            gen_restore_used_regs(aktproccode);
            { We know the size of the stack, now we can generate the
              parameter that is passed to the stack checking code }
            if not(tf_no_generic_stackcheck in TargetInfo.flags) and
               (cs_check_stack in entryswitches) and
               not(po_assembler in procdef.ProcOptions) and
               (procdef.ProcTypeOption<>potype_proginit) then
              begin
                CurrentFilePos:=entrypos;
                hlcg.Gen_Stack_Check_Size_Para(templist);
                aktproccode.InsertListAfter(stackcheck_asmnode.currenttai,templist)
              end;

            CurrentProcInfo.set_eh_info;

            { Add entry code (stack allocation) after header }
            CurrentFilePos:=entrypos;
            gen_proc_entry_code(templist);
            aktproccode.InsertListAfter(headertai,templist);
{$ifdef SUPPORT_SAFECALL}
            { Set return value of safecall procedure if implicit try/finally blocks are disabled }
            if not (cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and
               (tf_safecall_exceptions in TargetInfo.flags) and
               (procdef.ProcCallOption=pocall_safecall) then
              cg.A_Load_Const_Reg(aktproccode,OS_ADDR,0,NR_FUNCTION_RETURN_REG);
{$endif}
            { Add exit code at the end }
            CurrentFilePos:=exitpos;
            gen_proc_exit_code(templist);
            aktproccode.ConcatList(templist);

            { check if the implicit finally has been generated. The flag
              should already be set in pass1 }
            if (cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and
               not(procdef.ProcTypeOption in [potype_unitfinalize,potype_unitinit]) and
               (pi_needs_implicit_finally in flags) and
               not(pi_has_implicit_finally in flags) then
             InternalError(200405231);

             { sanity check }
             if not(Assigned(CurrentProcInfo.procdef.Personality)) and
                (tf_use_psabieh in TargetInfo.flags) and
                ((pi_uses_exceptions in flags) or
                 ((cs_implicit_exceptions in CurrentSettings.ModuleSwitches) and
                  (pi_needs_implicit_finally in flags))) then
               InternalError(2019021005);

            { Position markers are only used to insert additional code after the secondpass
              and before this point. They are of no use in optimizer. Instead of checking and
              ignoring all over the optimizer, just remove them here. }
            delete_marker(entry_asmnode);
            delete_marker(loadpara_asmnode);
            delete_marker(exitlabel_asmnode);
            delete_marker(stackcheck_asmnode);
            delete_marker(init_asmnode);

{$ifndef NoOpt}
            if not(cs_no_regalloc in CurrentSettings.GlobalSwitches) then
              begin
                if (cs_opt_level1 in CurrentSettings.OptimizerSwitches) and
                   { do not optimize pure assembler procedures }
                   not(pi_is_assembler in flags)  then
                  optimize(aktproccode);
{$ifndef i386}
                { schedule after assembler optimization, it could have brought up
                  new schedule possibilities }
                if (cs_opt_scheduler in CurrentSettings.OptimizerSwitches) and
                  { do not optimize pure assembler procedures }
                  not(pi_is_assembler in flags)  then
                  preregallocschedule(aktproccode);
{$endif i386}
              end;
{$endif NoOpt}

            { Perform target-specific processing if necessary }
            postprocess_code;

            { Add end symbol and debug info }
            { this must be done after the pcrelativedata is appended else the distance calculation of
              insertpcrelativedata will be wrong, further the pc indirect data is part of the procedure
              so it should be inserted before the end symbol (FK)
            }
            CurrentFilePos:=exitpos;
            hlcg.Gen_Proc_Symbol_End(templist);
            aktproccode.ConcatList(templist);

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
              if Assigned(CurrentProcInfo.procdef.ParentFPStruct) then
                Redirect_ParentFPStruct_Local_Syms(CurrentProcInfo.procdef);
              CurrentDebugInfo.insertlineinfo(aktproccode);
             end;

            finish_eh;

            hlcg.Record_Generated_Code_For_ProcDef(CurrentProcInfo.procdef,aktproccode,AktLocalData);

            { now generate code for any exception filters (they need the tempgen) }
            generate_code_exceptfilters;

            { only now we can remove the temps }
            if (procdef.ProcTypeOption<>potype_exceptfilter) then
              begin
                tg.resettempgen;
                tg.free;
                tg:=nil;
              end;
            { stop tempgen and ra }
            hlcg.Done_Register_Allocators;
            Destroy_HLCodeGen;
          end;

        dfabuilder.free;
        dfabuilder := nil;

        { restore symtablestack }
        remove_from_symtablestack;

        { restore }
        templist.free;
        templist := nil;
        CurrentSettings.MaxFPURegisters:=oldmaxfpuregisters;
        CurrentFilePos:=oldfilepos;
        CurrentStructDef:=old_current_structdef;
        CurrentProcInfo:=old_current_procinfo;
      end;


    procedure TCGProcInfo.add_to_symtablestack;
      begin
        { insert symtables for the class, but only if it is no nested function }
        if Assigned(procdef.struct) and
           not(Assigned(parent) and
               Assigned(parent.procdef) and
               Assigned(parent.procdef.struct)) then
          push_nested_hierarchy(procdef.struct);

        { insert parasymtable in symtablestack when parsing
          a function }
        if procdef.ParaST.SymTableLevel>=NormalFunctionLevel then
          SymTableStack.push(procdef.ParaST);

        { insert localsymtable, except for the main procedure
          (in that case the localst is the unit's static symtable,
           which is already on the stack) }
        if procdef.LocalST.SymTableLevel>=NormalFunctionLevel then
          SymTableStack.push(procdef.LocalST);
      end;


    procedure TCGProcInfo.remove_from_symtablestack;
      begin
        { remove localsymtable }
        if procdef.LocalST.SymTableLevel>=NormalFunctionLevel then
          SymTableStack.pop(procdef.LocalST);

        { remove parasymtable }
        if procdef.ParaST.SymTableLevel>=NormalFunctionLevel then
          SymTableStack.pop(procdef.ParaST);

        { remove symtables for the class, but only if it is no nested function }
        if Assigned(procdef.struct) and
           not(Assigned(parent) and
               Assigned(parent.procdef) and
               Assigned(parent.procdef.struct)) then
          pop_nested_hierarchy(procdef.struct);
      end;


    procedure TCGProcInfo.resetprocdef;
      begin
         { remove code tree, if not inline procedure }
         if Assigned(code) then
          begin
            { the inline procedure has already got a copy of the tree
              stored in procdef.inlininginfo }
            code.free;
            code:=nil;
          end;
       end;


    procedure TCGProcInfo.parse_body;
      var
         old_current_procinfo : TProcInfo;
         old_block_type : TBlockType;
         st : TSymTable;
         old_current_structdef: TAbstractRecordDef;
         old_current_genericdef,
         old_current_specializedef: TStoredDef;
         ParentFPInitBlock: TNode;
         old_parse_generic: boolean;
         recordtokens : boolean;
      begin
         old_current_procinfo:=CurrentProcInfo;
         old_block_type:=Block_Type;
         old_current_structdef:=CurrentStructDef;
         old_current_genericdef:=CurrentGenericDef;
         old_current_specializedef:=CurrentSpecializeDef;
         old_parse_generic:=parse_generic;

         CurrentProcInfo:=self;
         CurrentStructDef:=procdef.struct;


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
         if procdef.Is_Generic then
           begin
             CurrentGenericDef:=procdef;
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
         if procdef.ParaST.SymTableLevel>MaxNesting then
           Message(parser_e_too_much_lexlevel);
         Block_Type:=bt_body;


         { allocate the symbol for this procedure }
         alloc_proc_symbol(procdef);

         { add parast/localst to symtablestack }
         add_to_symtablestack;

         { save entry info }
         entrypos:=CurrentFilePos;
         entryswitches:=CurrentSettings.LocalSwitches;

         recordtokens:=procdef.Is_Generic or
                       (
                         Assigned(procdef.struct) and
                         (df_generic in procdef.struct.DefOptions) and
                         Assigned(procdef.owner) and
                         (procdef.owner.DefOwner=procdef.struct)
                       );

         if recordtokens then
           begin
             { start token recorder for generic template }
             procdef.InitGeneric;
             CurrentScanner.startrecordtokens(procdef.GenericTokenBuf);
           end;

         { parse the code ... }
         code:=block(CurrentModule.IsLibrary);

         PostProcess_Capturer(self);

         if recordtokens then
           begin
             { stop token recorder for generic template }
             CurrentScanner.stoprecordtokens;

             { Give an error for accesses in the static symtable that aren't visible
               outside the current unit }
             st:=procdef.owner;
             while (st.SymTableType in [ObjectSymtable,recordsymtable]) do
               st:=st.DefOwner.owner;
             if (pi_uses_static_symtable in flags) and
                (st.SymTableType<>staticsymtable) then
               Message(parser_e_global_generic_references_static);
           end;

         { save exit info }
         exitswitches:=CurrentSettings.LocalSwitches;
         exitpos:=last_endtoken_filepos;

         { the procedure is now defined }
         procdef.ForwardDef:=false;
         procdef.IsImplemented:=true;

         if Assigned(code) then
           begin
             { get a better entry point }
             entrypos:=code.fileinfo;

             { Finish type checking pass }
             DoTypeCheckPass(code);

             if Assigned(procdef.ParentFPInitBlock) then
               begin
                 if Assigned(TBlockNode(procdef.ParentFPInitBlock).left) then
                   begin
                     ParentFPInitBlock:=procdef.ParentFPInitBlock;
                     DoTypeCheckPass(ParentFPInitBlock);
                     procdef.ParentFPInitBlock:=ParentFPInitBlock;
                   end
               end;

           end;

         { Check for unused labels, forwards, symbols for procedures. Static
           symtable is checked in pmodules.
           The check must be done after the typecheckpass }
         if (ErrorCount=0) and
            (TStoredSymTable(procdef.LocalST).SymTableType<>staticsymtable) then
           begin
             { check if forwards are resolved }
             TStoredSymTable(procdef.LocalST).Check_Forwards;
             { check if all labels are used }
             TStoredSymTable(procdef.LocalST).CheckLabels;
             { check for unused symbols, but only if there is no asm block }
             if not(pi_has_assembler_block in flags) then
               begin
                 TStoredSymTable(procdef.LocalST).AllSymbolsUsed;
                 TStoredSymTable(procdef.ParaST).AllSymbolsUsed;
               end;
           end;

         if (po_inline in procdef.ProcOptions) and
           { Can we inline this procedure? }
           checknodeinlining(procdef) then
           CreateInlineInfo;

         { Print the node to tree.log }
         if ParaPrintNodeTree <> 0 then
           printproc( 'after parsing');


         { ... remove symbol tables }
         remove_from_symtablestack;


         CurrentStructDef:=old_current_structdef;
         CurrentGenericDef:=old_current_genericdef;
         CurrentSpecializeDef:=old_current_specializedef;
         CurrentProcInfo:=old_current_procinfo;
         parse_generic:=old_parse_generic;

         { Restore old state }
         Block_Type:=old_block_type;
      end;


{****************************************************************************
                        PROCEDURE/FUNCTION PARSING
****************************************************************************}


    procedure check_init_paras(p:TObject;arg:pointer);
      begin
        if TSym(p).typ<>paravarsym then
         exit;
        with TParaVarSym(p) do
          if (Is_Managed_Type(vardef) and
             (VarSpez in [vs_value,vs_out])) or
             (Is_ShortString(vardef) and
             (VarSpez=vs_value)) then
            include(CurrentProcInfo.flags,pi_do_call);
      end;


    procedure read_proc_body(old_current_procinfo:TProcInfo;pd:TProcDef);
      {
        Parses the procedure directives, then parses the procedure body, then
        generates the code for it
      }

      var
        oldfailtokenmode : TModeSwitches;
        isnestedproc     : boolean;
      begin
        Message1(parser_d_procedure_start,pd.FullProcName(false));
        oldfailtokenmode:=[];

        { create a new procedure }
        CurrentProcInfo:=CProcInfo.create(old_current_procinfo);
        CurrentModule.ProcInfo:=CurrentProcInfo;
        CurrentProcInfo.procdef:=pd;
        isnestedproc:=(CurrentProcInfo.procdef.ParaST.SymTableLevel>NormalFunctionLevel);
        { an anonymous function is always considered as nested }
        if po_anonymous in pd.ProcOptions then
          begin
            CurrentProcInfo.force_nested;
            isnestedproc:=true;
          end;

        { Insert mangledname }
        pd.AliasNames.insert(pd.MangledName);

        { Insert result variables in the localst }
        insert_funcret_local(pd);

        { check if there are para's which require initing -> set }
        { pi_do_call (if not yet set)                            }
        if not(pi_do_call in CurrentProcInfo.flags) then
          pd.ParaST.SymList.ForEachCall(@check_init_paras,nil);

        { set _FAIL as keyword if constructor }
        if (pd.ProcTypeOption=potype_constructor) then
         begin
           oldfailtokenmode:=tokeninfo^[_FAIL].keyword;
           tokeninfo^[_FAIL].keyword:=alllanguagemodes;
         end;

        TCGProcInfo(CurrentProcInfo).parse_body;

        { reset _FAIL as _SELF normal }
        if (pd.ProcTypeOption=potype_constructor) then
          tokeninfo^[_FAIL].keyword:=oldfailtokenmode;

        { When it's a nested procedure then defer the code generation,
          when back at normal function level then generate the code
          for all deferred nested procedures and the current procedure }
        if not isnestedproc then
          begin
            if not(df_generic in CurrentProcInfo.procdef.DefOptions) then
              begin
                { also generate the bodies for all previously done
                  specializations so that we might inline them }
                generate_specialization_procs;
                { convert all load nodes that might have been captured by a
                  capture object }
                TCGProcInfo(CurrentProcInfo).Convert_Captured_Syms;
                TCGProcInfo(CurrentProcInfo).generate_code_tree;
              end;
          end;

        { release procinfo }
        if TProcInfo(CurrentModule.ProcInfo)<>CurrentProcInfo then
          InternalError(200304274);
        CurrentModule.ProcInfo:=CurrentProcInfo.parent;

        { For specialization we didn't record the last semicolon. Moving this parsing
          into the parse_body routine is not done because of having better file position
          information available }
        if not CurrentProcInfo.procdef.Is_Specialization and
            not (po_anonymous in CurrentProcInfo.procdef.ProcOptions) and
            (
              not Assigned(CurrentProcInfo.procdef.struct) or
              not (df_specialization in CurrentProcInfo.procdef.struct.DefOptions)
              or not (
                Assigned(CurrentProcInfo.procdef.owner) and
                (CurrentProcInfo.procdef.owner.DefOwner=CurrentProcInfo.procdef.struct)
              )
            ) then
          consume(_SEMICOLON);

        if not isnestedproc then
          { current_procinfo is checked for nil later on }
          freeandnil(CurrentProcInfo);
      end;


    procedure read_proc_body(pd:TProcDef);
      var
        old_module_procinfo : tobject;
        old_current_procinfo : TProcInfo;
      begin
        old_current_procinfo:=CurrentProcInfo;
        old_module_procinfo:=CurrentModule.ProcInfo;
        CurrentProcInfo:=nil;
        CurrentModule.ProcInfo:=nil;
        read_proc_body(nil,pd);
        CurrentProcInfo:=old_current_procinfo;
        CurrentModule.ProcInfo:=old_module_procinfo;
      end;


    function read_proc(flags:TReadProcFlags; usefwpd: TProcDef):TProcDef;
      {
        Parses the procedure directives, then parses the procedure body, then
        generates the code for it
      }

        function convert_flags_to_ppf:TParseProcFlags;inline;
          begin
            result:=[];
            if rpf_classmethod in flags then
              include(result,ppf_classmethod);
            if rpf_generic in flags then
              include(result,ppf_generic);
            if rpf_anonymous in flags then
              include(result,ppf_anonymous);
          end;

      var
        old_current_procinfo : TProcInfo;
        old_current_structdef: TAbstractRecordDef;
        old_current_genericdef,
        old_current_specializedef: TStoredDef;
        pdflags    : TPDFlags;
        firstpd : TProcDef;
{$ifdef genericdef_for_nested}
        def : TProcDef;
        srsym : TSym;
        i : LongInt;
{$endif genericdef_for_nested}
      begin
         { save old state }
         old_current_procinfo:=CurrentProcInfo;
         old_current_structdef:=CurrentStructDef;
         old_current_genericdef:=CurrentGenericDef;
         old_current_specializedef:=CurrentSpecializeDef;

         { reset current_procinfo.procdef to nil to be sure that nothing is writing
           to another procdef }
         CurrentProcInfo:=nil;
         CurrentStructDef:=nil;
         CurrentGenericDef:=nil;
         CurrentSpecializeDef:=nil;

         if not Assigned(usefwpd) then
           { parse procedure declaration }
           result:=parse_proc_dec(convert_flags_to_ppf,old_current_structdef)
         else
           result:=usefwpd;

         { set the default function options }
         if parse_only then
          begin
            result.ForwardDef:=true;
            { set also the interface flag, for better error message when the
              implementation doesn't match this header }
            result.InterfaceDef:=true;
            include(result.ProcOptions,po_global);
            pdflags:=[pd_interface];
          end
         else
          begin
            pdflags:=[pd_body];
            if (not CurrentModule.InInterface) then
              include(pdflags,pd_implemen);
            if (not CurrentModule.IsUnit) or
               create_smartlink_library then
              include(result.ProcOptions,po_global);
            result.ForwardDef:=false;
          end;

         if not Assigned(usefwpd) then
           begin
             { parse the directives that may follow }
             parse_proc_directives(result,pdflags);

             if not (rpf_anonymous in flags) then
               { hint directives, these can be separated by semicolons here,
                 that needs to be handled here with a loop (PFV) }
               while try_consume_hintdirective(result.SymOptions,result.DeprecatedMsg) do
                Consume(_SEMICOLON);

             { Set calling convention }
             if parse_only then
               handle_calling_convention(result,hcc_default_actions_intf)
             else
               handle_calling_convention(result,hcc_default_actions_impl)
           end;

         { search for forward declarations }
         if not proc_add_definition(result) then
           begin
             { One may not implement a method of a type declared in a different unit }
             if Assigned(result.struct) and
                (result.struct.SymTable.ModuleID<>CurrentModule.ModuleID) and
                not result.Is_Specialization then
              begin
                MessagePos1(result.fileinfo,parser_e_method_for_type_in_other_unit,result.struct.TypeSymbolPrettyName);
              end
             { A method must be forward defined (in the object declaration) }
             else if Assigned(result.struct) and
                (not Assigned(old_current_structdef)) then
              begin
                MessagePos1(result.fileinfo,parser_e_header_dont_match_any_member,result.FullProcName(false));
                TProcSym(result.ProcSym).Write_Parameter_Lists(result);
              end
             else
              begin
                { Give a better error if there is a forward def in the interface and only
                  a single implementation }
                firstpd:=TProcDef(TProcSym(result.ProcSym).ProcdefList[0]);
                if (not result.ForwardDef) and
                   (not result.InterfaceDef) and
                   (TProcSym(result.ProcSym).ProcdefList.Count>1) and
                   firstpd.ForwardDef and
                   firstpd.InterfaceDef and
                   not(TProcSym(result.ProcSym).ProcdefList.Count>2) and
                   { don't give an error if it may be an overload }
                   not(m_fpc in CurrentSettings.ModeSwitches) and
                   (not(po_overload in result.ProcOptions) or
                    not(po_overload in firstpd.ProcOptions)) then
                 begin
                   MessagePos1(result.fileinfo,parser_e_header_dont_match_forward,result.FullProcName(false));
                   TProcSym(result.ProcSym).Write_Parameter_Lists(result);
                 end
                else
                  begin
                    if result.Is_Generic and not Assigned(result.struct) then
                      TProcSym(result.ProcSym).owner.IncludeOption(sto_has_generic);
                  end;
              end;
           end;

         { Set mangled name }
         proc_set_mangledname(result);

         { inherit generic flags from parent routine }
         if Assigned(old_current_procinfo) and
             (old_current_procinfo.procdef.DefOptions*[df_specialization,df_generic]<>[]) then
           begin
             if df_generic in old_current_procinfo.procdef.DefOptions then
               include(result.DefOptions,df_generic);
             if df_specialization in old_current_procinfo.procdef.DefOptions then
               begin
                 include(result.DefOptions,df_specialization);
                 { the procdefs encountered here are nested procdefs of which
                   their complete definition also resides inside the current token
                   stream, thus access to their genericdef is not required }
                 {$ifdef genericdef_for_nested}
                 { find the corresponding routine in the generic routine }
                 if not Assigned(old_current_procinfo.procdef.GenericDef) then
                   InternalError(2016121701);
                 srsym:=TSym(TProcDef(old_current_procinfo.procdef.GenericDef).GetSymTable(gs_local).find(result.ProcSym.name));
                 if not Assigned(srsym) or (srsym.typ<>ProcSym) then
                   InternalError(2016121702);
                 { in practice the generic procdef should be at the same index
                   as the index of the current procdef, but as there *might* be
                   differences between the amount of defs generated for the
                   specialization and the generic search for the def using
                   parameter comparison }
                 for i:=0 to TProcSym(srsym).procdeflist.count-1 do
                   begin
                     def:=TProcDef(TProcSym(srsym).procdeflist[i]);
                     if (Compare_Paras(def.paras,result.paras,cp_none,[cpo_ignorehidden,cpo_openequalisexact,cpo_ignoreuniv])=te_exact) and
                         (Compare_Defs(def.ReturnDef,result.ReturnDef,nothingn)=te_exact) then
                       begin
                         result.GenericDef:=def;
                         break;
                       end;
                   end;
                 if not Assigned(result.GenericDef) then
                   InternalError(2016121703);
                 {$endif}
               end;
           end;

         { compile procedure when a body is needed }
         if (pd_body in pdflags) then
           begin
             read_proc_body(old_current_procinfo,result);
           end
         else
           begin
             { Handle imports }
             if (po_external in result.ProcOptions) then
               begin
                 import_external_proc(result);
{$ifdef cpuhighleveltarget}
                 { it's hard to factor this out in a virtual method, because the
                   generic version (the one inside this ifdef) doesn't fit in
                   hlcgobj but in symcreat or here, while the other version
                   doesn't fit in symcreat (since it uses the code generator).
                   Maybe we need another class for this kind of code that could
                   either be symcreat- or hlcgobj-based
                 }
                 if (not result.ForwardDef) and
                    (result.HasForward) and
                    (proc_get_importname(result)<>'') then
                   begin
                     { we cannot handle the callee-side of variadic functions (and
                       even if we could, e.g. LLVM cannot call through to something
                       else in that case) }
                     if Is_C_Variadic(result) then
                       Message1(parser_e_callthrough_varargs,result.FullProcName(false));
                     Call_Through_New_Name(result,proc_get_importname(result));
                     include(result.ImplProcOptions,pio_thunk);
                   end
                 else
{$endif cpuhighleveltarget}
                   begin
                     Create_HLCodeGen(nil);
                     hlcg.Handle_External_Proc(
                       CurrentAsmData.asmlists[al_procedures],
                       result,
                       proc_get_importname(result));
                     Destroy_HLCodeGen;
                   end
               end;
           end;

         { always register public functions that are only declared in the
           implementation section as they might be called using an external
           declaration from another unit }
         if (po_global in result.ProcOptions) and
             not result.InterfaceDef and
             ([df_generic,df_specialization]*result.DefOptions=[]) then
           begin
             result.RegisterDef;
             result.ProcSym.RegisterSym;
           end;

         { make sure that references to forward-declared functions are not }
         { treated as references to external symbols, needed for darwin.   }

         { make sure we don't change the binding of real external symbols }
         if (([po_external,po_weakexternal]*result.ProcOptions)=[]) and (pocall_internproc<>result.ProcCallOption) then
           CurrentAsmData.DefineProcAsmSymbol(result,result.MangledName,result.NeedsGlobalAsmSym);

         CurrentStructDef:=old_current_structdef;
         CurrentGenericDef:=old_current_genericdef;
         CurrentSpecializeDef:=old_current_specializedef;
         CurrentProcInfo:=old_current_procinfo;
      end;


    procedure import_external_proc(pd:TProcDef);
      var
        name : string;
      begin
        if not (po_external in pd.ProcOptions) then
          InternalError(2015121101);

        { Import DLL specified? }
        if Assigned(pd.ImportDLL) then
          begin
            if Assigned (pd.ImportName) then
              CurrentModule.AddExternalImport(pd.ImportDLL^,
                pd.ImportName^,proc_get_importname(pd),
                pd.ImportNr,false,false)
            else
              CurrentModule.AddExternalImport(pd.ImportDLL^,
                proc_get_importname(pd),proc_get_importname(pd),
                pd.ImportNr,false,true);
          end
        else
          begin
            name:=proc_get_importname(pd);
            { add import name to external list for DLL scanning }
            if tf_has_dllscanner in TargetInfo.flags then
              CurrentModule.DLLScannerInputList.Add(name,pd);
            { needed for units that use functions in packages this way }
            CurrentModule.Add_Extern_AsmSym(name,AB_EXTERNAL,AT_FUNCTION);
          end;
      end;

{****************************************************************************
                             DECLARATION PARSING
****************************************************************************}

    { search in symtablestack for not complete classes }
    procedure check_forward_class(p:TObject;arg:pointer);
      begin
        if (TSym(p).typ=TypeSym) and
           (TTypeSym(p).typedef.typ=objectdef) and
           (oo_is_forward in TObjectDef(TTypeSym(p).typedef).ObjectOptions) then
          MessagePos1(TSym(p).fileinfo,sym_e_forward_type_not_resolved,TSym(p).realname);
      end;


    procedure read_declarations(IsLibrary : boolean);
      var
        hadgeneric : boolean;

        procedure handle_unexpected_had_generic;
          begin
            if hadgeneric then
              begin
                Message(parser_e_procedure_or_function_expected);
                hadgeneric:=false;
              end;
          end;

      var
        is_classdef:boolean;
        flags : TReadProcFlags;
      begin
        is_classdef:=false;
        hadgeneric:=false;
        repeat
           if not Assigned(CurrentProcInfo) then
             InternalError(200304251);
           case CurrentScanner.token of
              _LABEL:
                begin
                  handle_unexpected_had_generic;
                  label_dec;
                end;
              _CONST:
                begin
                  handle_unexpected_had_generic;
                  const_dec(hadgeneric);
                end;
              _TYPE:
                begin
                  handle_unexpected_had_generic;
                  type_dec(hadgeneric);
                end;
              _VAR:
                begin
                  handle_unexpected_had_generic;
                  var_dec(hadgeneric);
                end;
              _THREADVAR:
                begin
                  handle_unexpected_had_generic;
                  threadvar_dec(hadgeneric);
                end;
              _CLASS:
                begin
                  is_classdef:=false;
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
                       is_classdef:=true;
                   end;
                end;
              _CONSTRUCTOR,
              _DESTRUCTOR,
              _FUNCTION,
              _PROCEDURE,
              _OPERATOR:
                begin
                  if hadgeneric and not (CurrentScanner.token in [_PROCEDURE,_FUNCTION]) then
                    begin
                      Message(parser_e_procedure_or_function_expected);
                      hadgeneric:=false;
                    end;
                  flags:=[];
                  if is_classdef then
                    include(flags,rpf_classmethod);
                  if hadgeneric then
                    include(flags,rpf_generic);
                  read_proc(flags,nil);
                  is_classdef:=false;
                  hadgeneric:=false;
                end;
              _EXPORTS:
                begin
                   handle_unexpected_had_generic;
                   if (CurrentProcInfo.procdef.LocalST.SymTableLevel>MainProgramLevel) then
                     begin
                        Message(parser_e_syntax_error);
                        consume_all_until(_SEMICOLON);
                     end
                   else if IsLibrary or
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
                  handle_unexpected_had_generic;
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
                        handle_unexpected_had_generic;
                        { m_class is needed, because the resourcestring
                          loading is in the ObjPas unit }
{                        if (m_class in current_settings.modeswitches) then}
                          resourcestring_dec(hadgeneric)
{                        else
                          break;}
                      end;
                    _OPERATOR:
                      begin
                        handle_unexpected_had_generic;
                        if is_classdef then
                          begin
                            read_proc([rpf_classmethod],nil);
                            is_classdef:=false;
                          end
                        else
                          break;
                      end;
                    _GENERIC:
                      begin
                        handle_unexpected_had_generic;
                        if not (m_delphi in CurrentSettings.ModeSwitches) then
                          begin
                            consume(_ID);
                            hadgeneric:=true;
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
         if (CurrentProcInfo.procdef.LocalST.SymTableType=LocalSymTable) and
           { we cannot call add_synthetic_method_implementations as it throws an internalerror if
             the token is a string/char. As this is a syntax error and compilation will abort anyways,
             skipping the call does not matter
           }
           (CurrentScanner.token<>_CSTRING) and
           (CurrentScanner.token<>_CWCHAR) and
           (CurrentScanner.token<>_CWSTRING) then
           Add_Synthetic_Method_Implementations(CurrentProcInfo.procdef.LocalST);

         { check for incomplete class definitions, this is only required
           for fpc modes }
         if (m_fpc in CurrentSettings.ModeSwitches) then
           CurrentProcInfo.procdef.LocalST.SymList.ForEachCall(@check_forward_class,nil);
      end;


    procedure read_interface_declarations;
      var
        hadgeneric : boolean;

        procedure handle_unexpected_had_generic;
          begin
            if hadgeneric then
              begin
                Message(parser_e_procedure_or_function_expected);
                hadgeneric:=false;
              end;
          end;

      var
        flags : TReadProcFlags;
      begin
         hadgeneric:=false;
         repeat
           case CurrentScanner.token of
             _CONST :
               begin
                 handle_unexpected_had_generic;
                 const_dec(hadgeneric);
               end;
             _TYPE :
               begin
                 handle_unexpected_had_generic;
                 type_dec(hadgeneric);
               end;
             _VAR :
               begin
                 handle_unexpected_had_generic;
                 var_dec(hadgeneric);
               end;
             _THREADVAR :
               begin
                 handle_unexpected_had_generic;
                 threadvar_dec(hadgeneric);
               end;
             _FUNCTION,
             _PROCEDURE,
             _OPERATOR :
               begin
                 if hadgeneric and not (CurrentScanner.token in [_FUNCTION, _PROCEDURE]) then
                   begin
                     message(parser_e_procedure_or_function_expected);
                     hadgeneric:=false;
                   end;
                 flags:=[];
                 if hadgeneric then
                   include(flags,rpf_generic);
                 read_proc(flags,nil);
                 hadgeneric:=false;
               end;
             else
               begin
                 case CurrentScanner.idtoken of
                   _RESOURCESTRING :
                     begin
                       handle_unexpected_had_generic;
                       resourcestring_dec(hadgeneric);
                     end;
                   _PROPERTY:
                     begin
                       handle_unexpected_had_generic;
                       if (m_fpc in CurrentSettings.ModeSwitches) then
                         property_dec
                       else
                         break;
                     end;
                   _GENERIC:
                     begin
                       handle_unexpected_had_generic;
                       if not (m_delphi in CurrentSettings.ModeSwitches) then
                         begin
                           hadgeneric:=true;
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
          SymTableStack.top.SymList.ForEachCall(@check_forward_class,nil);
      end;


end.
