{
    Copyright (c) 2014 by Jonas Maebe, Member of the Free Pascal
    development team.

    This unit implements helper routines for "blocks" support
    (http://en.wikipedia.org/wiki/Blocks_(C_language_extension) )

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
unit blockutl;

{$i fpcdefs.inc}

interface

  uses
    node,nld,ncnv,
    symtype,symdef;

  { accepts a loadnode for a procdef

    returns a node representing the converted code to implement this
    conversion (this node is valid both for typed constant declarations and
    in function bodies). The node is not reused }
  function generate_block_for_procaddr(procloadnode: TLoadNode): TNode;

  { for a procdef, return a recorddef representing a block literal for this
    procdef

    for a procvardef, return a basic recorddef representing a block literal
    with enough info to call this procvardef }
  function get_block_literal_type_for_proc(pd: TAbstractProcDef): TRecordDef;

implementation

  uses
    Verbose,GlobType,CUtils,ConstExp,
    Pass_1,pparautl,FModule,
    AAsmData,
    nbas,ncon,nmem,nutils,
    SymBase,symconst,SymTable,SymSym,symcreat,objcutil,defutil,
    paramgr;


  function get_block_literal_type_for_proc(pd: TAbstractProcDef): TRecordDef;
    begin
      if pd.typ=procvardef then
        result:=TRecordDef(Search_Named_Unit_GlobalType('BLOCKRTL','FPC_BLOCK_LITERAL_BASE',true).TypeDef)
      else if pd.Is_AddressOnly then
        result:=TRecordDef(Search_Named_Unit_GlobalType('BLOCKRTL','FPC_BLOCK_LITERAL_STATIC',true).TypeDef)
      { todo: nested functions and Objective-C methods }
      else if not Is_Nested_PD(pd) and
              not Is_ObjCClass(TDef(pd.owner.DefOwner)) then
        result:=TRecordDef(Search_Named_Unit_GlobalType('BLOCKRTL','FPC_BLOCK_LITERAL_COMPLEX_PROCVAR',true).TypeDef)
      else
        InternalError(2014071304);
    end;


  function get_block_literal_isa(orgpd: TProcDef): TStaticVarSym;
    var
      srsym: TSym;
      srsymtable: TSymTable;
      name: TIDString;
    begin
      if orgpd.Is_AddressOnly then
        name:='_NSCONCRETEGLOBALBLOCK'
      else
        name:='_NSCONCRETESTACKBLOCK';
      if not SearchSym_In_Named_Module('BLOCKRTL',name,srsym,srsymtable) or
         (srsym.typ<>staticvarsym) then
        InternalError(2014071501);
      result:=TStaticVarSym(srsym);
    end;


  function get_block_literal_flags(orgpd, invokepd: TProcDef): LongInt;
    { BlockLiteralFlags }
    const
      BLOCK_HAS_COPY_DISPOSE    = 1 shl 25;
      BLOCK_HAS_CXX_OBJ         = 1 shl 26;
      BLOCK_IS_GLOBAL           = 1 shl 28;
      BLOCK_USE_STRET           = 1 shl 29;
      BLOCK_HAS_SIGNATURE       = 1 shl 30;
      BLOCK_HAS_EXTENDED_LAYOUT = 1 shl 31;
    begin
      result:=0;
      { BLOCK_HAS_COPY_DISPOSE :
          copy/dispose will be necessary once we support nested procedures, in
          case they capture reference counted types, Objective-C class instances
          or block-type variables
      }

      { BLOCK_HAS_CXX_OBJ:
          we don't support C++ (stack-based) class instances yet
      }

      { BLOCK_IS_GLOBAL:
          set in case the block does not capture any local state; used for
          global functions and in theory also possible for nested functions that
          do not access any variables from their parentfp context
      }
      if orgpd.Is_AddressOnly then
        result:=result or BLOCK_IS_GLOBAL;

      { BLOCK_USE_STRET:
          set in case the invoke function returns its result via a hidden
          parameter
      }
      if ParaManager.Ret_In_Param(invokepd.ReturnDef,orgpd) then
        result:=result or BLOCK_USE_STRET;
      { BLOCK_HAS_SIGNATURE:
          only if this bit is set, the above bit will actually be taken into
          account (for backward compatibility). We need it so that our invoke
          function isn't called as a variadic function, but on the downside this
          requires Mac OS X 10.7 or later
      }
      result:=result or BLOCK_HAS_SIGNATURE;
      { BLOCK_HAS_EXTENDED_LAYOUT:
          no documentation about what this means or what it's good for (clang
          adds it for Objective-C 1 platforms in case garbage collection is
          switched off, but then you also have to actually generate this layout)
      }
    end;


  function get_block_literal_descriptor(invokepd: TProcDef; block_literal_size: TCGInt): TStaticVarSym;
    var
      descriptordef: TDef;
      descriptor: TStaticVarSym;
      name: TSymStr;
      srsym: TSym;
      srsymtable: TSymTable;
    begin
      (*
        FPC_Block_descriptor_simple = record
          reserved: culong;
          Block_size: culong;
          { signatures are only for the "ABI.2010.3.16" version, but that's all
            we support because otherwise the callback has to be a C-style
            variadic function, which we cannot (yet?) generate }
          signature: pchar;
        end;
      *)

      { must be a valid Pascal identifier, because we will reference it when
        constructing the block initialiser }
      { we don't have to include the moduleid in this mangledname, because
        the invokepd is a local procedure in the current unit -> unique_id_str
        by itself is unique }
      name:='__FPC_BLOCK_DESCRIPTOR_SIMPLE_'+invokepd.UniqueIDStr;
      { already exists -> return }
      if SearchSym(name,srsym,srsymtable) then
        begin
          if srsym.typ<>staticvarsym then
            InternalError(2014071402);
          result:=TStaticVarSym(srsym);
          exit;
        end;
      { find the type of the descriptor structure }
      descriptordef:=Search_Named_Unit_GlobalType('BLOCKRTL','FPC_BLOCK_DESCRIPTOR_SIMPLE',true).TypeDef;
      { create new static variable }
      descriptor:=CStaticVarSym.Create(name,vs_value,descriptordef,[]);
      SymTableStack.top.InsertSym(descriptor);
      include(descriptor.SymOptions,sp_internal);
      { create typed constant for the descriptor }
      Str_Parse_TypedConst(CurrentAsmData.AsmLists[al_const],
        '(reserved: 0; Block_size: '+ToStr(block_literal_size)+
        '; signature: '''+ObjCEncodeMethod(invokepd)+''');',descriptor);
      result:=descriptor;
    end;


  { creates a wrapper function for pd with the C calling convention and an
    extra first parameter pointing to the block "self" pointer. This wrapper is
    what will be assigned to the "invoke" field of the block }
  function get_invoke_wrapper(orgpd: TProcDef; orgpv: TProcVarDef): TProcDef;
    var
      wrappername: TIDString;
      srsym: TSym;
      srsymtable: TSymTable;
    begin
      { the copy() is to ensure we don't overflow the maximum identifier length;
        the combination of owner.moduleid and defid will make the name unique }
      wrappername:='__FPC_BLOCK_INVOKE_'+upper(copy(orgpd.ProcSym.realname,1,60))+'_'+ToStr(orgpd.owner.ModuleID)+'_'+orgpd.UniqueIDStr;
      { already an invoke wrapper for this procsym -> reuse }
      if SearchSym(wrappername,srsym,srsymtable) then
        begin
          if (srsym.typ<>ProcSym) or
             (TProcSym(srsym).procdeflist.count<>1) then
            InternalError(2014071503);
          result:=TProcDef(TProcSym(srsym).procdeflist[0]);
          exit;
        end;
      { bare copy, so that self etc are not inserted }
      result:=TProcDef(orgpd.GetCopyAs(procdef,pc_bareproc,'',true));
      { will be called according to the ABI conventions }
      result.ProcCallOption:=pocall_cdecl;
      { add po_is_block so that a block "self" pointer gets added (of the type
        returned by get_block_literal_type_for_proc()) }
      include(result.ProcOptions,po_is_block);
      { now insert self/vmt/funcret according to the newly set calling
        convention }
      insert_self_and_vmt_para(result);
      insert_funcret_para(result);
      Finish_Copied_ProcDef(result,wrappername,CurrentModule.LocalSymTable,nil);
      if orgpd.Is_AddressOnly then
        begin
          result.SyntheticKind:=tsk_callthrough;
          result.SKPara:=orgpd;
        end
      else
        begin
          { alias for the type to invoke the procvar, used in the symcreat
            handling of tsk_block_invoke_procvar }
          result.LocalST.InsertSym(CTypeSym.Create('__FPC_BLOCK_INVOKE_PV_TYPE',orgpv));
          result.SyntheticKind:=tsk_block_invoke_procvar;
        end;
    end;


  { compose a block literal for a static block (one without context) }
  function get_global_proc_literal_sym(blockliteraldef: TDef; blockisasym: TStaticVarSym; blockflags: LongInt; invokepd: TProcDef; descriptor: TStaticVarSym): TStaticVarSym;
    var
      literalname: TIDString;
      srsym: TSym;
      srsymtable: TSymTable;
    begin
      literalname:='block_literal_for_'+invokepd.ProcSym.realname;
      { already exists -> return }
      if SearchSym(literalname,srsym,srsymtable) then
        begin
          if srsym.typ<>staticvarsym then
            InternalError(2014071506);
          result:=TStaticVarSym(srsym);
          exit;
        end;
      { create new block literal symbol }
      result:=CStaticVarSym.Create(
        '$'+literalname,
        vs_value,
        blockliteraldef,[]);
      include(result.SymOptions,sp_internal);
      SymTableStack.top.InsertSym(result);
      { initialise it }
      Str_Parse_TypedConst(CurrentAsmData.AsmLists[al_const],
        '(base: (isa        : @'+blockisasym.realname+
              '; flags     : '+ToStr(blockflags)+
              '; reserved  : 0'+
              '; invoke    : @'+invokepd.ProcSym.realname+
              '; descriptor: @'+descriptor.realname+
              '));',
        result);
    end;


  { compose an on-stack block literal for a "procedure of object" }
  function get_pascal_method_literal(blockliteraldef: TDef; blockisasym: TStaticVarSym; blockflags: LongInt; procvarnode: TNode; invokepd: TProcDef; orgpv: TProcVarDef; descriptor: TStaticVarSym): TNode;
    var
      statement: TStatementNode;
      literaltemp: TTempCreateNode;
    begin
      result:=InternalStatements(statement);
      { create new block literal structure }
      literaltemp:=CTempCreateNode.Create(blockliteraldef,blockliteraldef.Size,tt_persistent,false);
      AddStatement(statement,literaltemp);
      { temp.base.isa:=@blockisasym }
      AddStatement(statement,CAssignmentNode.Create(
        GenLoadField(GenLoadField(CTempRefNode.Create(literaltemp),'BASE'),'ISA'),
        CAddrNode.Create(CLoadNode.Create(blockisasym,blockisasym.owner))));
      { temp.base.flags:=blockflags }
      AddStatement(statement,CAssignmentNode.Create(
        GenLoadField(GenLoadField(CTempRefNode.Create(literaltemp),'BASE'),'FLAGS'),
        GenIntConstNode(blockflags)));
      { temp.base.reserved:=0 }
      AddStatement(statement,CAssignmentNode.Create(
        GenLoadField(GenLoadField(CTempRefNode.Create(literaltemp),'BASE'),'RESERVED'),
        GenIntConstNode(0)));
      { temp.base.invoke:=tmethod(@invokepd) }
      AddStatement(statement,CAssignmentNode.Create(
        GenLoadField(GenLoadField(CTempRefNode.Create(literaltemp),'BASE'),'INVOKE'),
        CTypeConvNode.Create_Proc_To_ProcVar(
          CLoadNode.Create_ProcVar(invokepd.ProcSym,invokepd,invokepd.owner))));
      { temp.base.descriptor:=@descriptor }
      AddStatement(statement,CAssignmentNode.Create(
        GenLoadField(GenLoadField(CTempRefNode.Create(literaltemp),'BASE'),'DESCRIPTOR'),
        CAddrNode.Create(CLoadNode.Create(descriptor,descriptor.owner))));
      { temp.pv:=tmethod(@orgpd) }
      AddStatement(statement,CAssignmentNode.Create(
        CTypeConvNode.Create_Explicit(GenLoadField(CTempRefNode.Create(literaltemp),'PV'),orgpv),
          procvarnode.GetCopy));
      { and return the address of the temp }
      AddStatement(statement,CAddrNode.Create(CTempRefNode.Create(literaltemp)));
      { typecheck this now, because the current source may be written in TP/
        Delphi/MacPas mode and the above node tree has been constructed for
        ObjFPC mode, which has been set by replace_scanner (in Delphi, the
        assignment to invoke would be without the proc_to_procvar conversion) }
      TypeCheckPass(result);
    end;


  function generate_block_for_procaddr(procloadnode: TLoadNode): TNode;
    var
      procvarnode: TNode;
      { procvardef representing the original function we want to invoke }
      orgpv: TProcVarDef;
      { procdef of the original function we want to invoke }
      orgpd,
      { procdef for the invoke-wrapper that we generated to call the original
        function via a procvar }
      invokepd: TProcDef;
      blockliteraldef: TDef;
      descriptor,
      blockisasym,
      blockliteralsym: TStaticVarSym;
      blockflags: LongInt;
      old_symtablestack: TSymTableStack;
      sstate: TScannerState;
    begin
      result:=nil;
      { supported? (should be caught earlier) }
      if (procloadnode.resultdef.typ<>procdef) or
         Is_Nested_PD(TProcDef(procloadnode.resultdef)) or
         Is_ObjCClass(TDef(procloadnode.resultdef.owner.DefOwner)) then
        InternalError(2014071401);

      { add every symbol that we create here to the unit-level symbol table }
      old_symtablestack:=SymTableStack;
      SymTableStack:=old_symtablestack.GetCopyUntil(CurrentModule.LocalSymTable);
      { save scanner state }
      Replace_Scanner('block literal creation',sstate);

      { def representing the original function }
      orgpd:=TProcDef(procloadnode.resultdef);
      { def representing the corresponding procvar type }
      procvarnode:=CTypeConvNode.Create_Proc_To_ProcVar(procloadnode.GetCopy);
      TypeCheckPass(procvarnode);
      orgpv:=TProcVarDef(procvarnode.resultdef);
      { get blockdef for this kind of procdef }
      blockliteraldef:=get_block_literal_type_for_proc(orgpd);
      { get the invoke wrapper }
      invokepd:=get_invoke_wrapper(orgpd,orgpv);
      { get the descriptor }
      descriptor:=get_block_literal_descriptor(invokepd,blockliteraldef.Size);
      { get the ISA pointer for the literal }
      blockisasym:=get_block_literal_isa(orgpd);
      { get the flags for the block }
      blockflags:=get_block_literal_flags(orgpd,invokepd);
      { global/simple procedure -> block literal is a typed constant }
      if orgpd.Is_AddressOnly then
        begin
          blockliteralsym:=get_global_proc_literal_sym(blockliteraldef,blockisasym,blockflags,invokepd,descriptor);
          { result: address of the block literal }
          result:=CAddrNode.Create(CLoadNode.Create(blockliteralsym,blockliteralsym.owner));
        end
      else
        begin
          result:=get_pascal_method_literal(blockliteraldef,blockisasym,blockflags,procvarnode,invokepd,orgpv,descriptor)
        end;

      procvarnode.free;
      procvarnode := nil;

      { restore scanner }
      Restore_Scanner(sstate);
      { restore symtable stack }
      SymTableStack.free;
      SymTableStack:=old_symtablestack;
    end;

end.

