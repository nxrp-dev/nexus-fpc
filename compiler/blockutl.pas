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
    pass_1,pparautl,FModule,
    AAsmData,
    nbas,ncon,nmem,nutils,
    SymBase,symconst,SymTable,SymSym,symcreat,objcutil,defutil,
    paramgr;


  function get_block_literal_type_for_proc(pd: TAbstractProcDef): TRecordDef;
    begin
      if pd.typ=procvardef then
        result:=TRecordDef(search_named_unit_globaltype('BLOCKRTL','FPC_BLOCK_LITERAL_BASE',true).typedef)
      else if pd.is_addressonly then
        result:=TRecordDef(search_named_unit_globaltype('BLOCKRTL','FPC_BLOCK_LITERAL_STATIC',true).typedef)
      { todo: nested functions and Objective-C methods }
      else if not is_nested_pd(pd) and
              not is_objcclass(TDef(pd.owner.defowner)) then
        result:=TRecordDef(search_named_unit_globaltype('BLOCKRTL','FPC_BLOCK_LITERAL_COMPLEX_PROCVAR',true).typedef)
      else
        InternalError(2014071304);
    end;


  function get_block_literal_isa(orgpd: TProcDef): TStaticVarSym;
    var
      srsym: TSym;
      srsymtable: TSymTable;
      name: TIDString;
    begin
      if orgpd.is_addressonly then
        name:='_NSCONCRETEGLOBALBLOCK'
      else
        name:='_NSCONCRETESTACKBLOCK';
      if not searchsym_in_named_module('BLOCKRTL',name,srsym,srsymtable) or
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
      if orgpd.is_addressonly then
        result:=result or BLOCK_IS_GLOBAL;

      { BLOCK_USE_STRET:
          set in case the invoke function returns its result via a hidden
          parameter
      }
      if paramanager.ret_in_param(invokepd.returndef,orgpd) then
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
      if searchsym(name,srsym,srsymtable) then
        begin
          if srsym.typ<>staticvarsym then
            InternalError(2014071402);
          result:=TStaticVarSym(srsym);
          exit;
        end;
      { find the type of the descriptor structure }
      descriptordef:=search_named_unit_globaltype('BLOCKRTL','FPC_BLOCK_DESCRIPTOR_SIMPLE',true).typedef;
      { create new static variable }
      descriptor:=CStaticVarSym.create(name,vs_value,descriptordef,[]);
      SymTableStack.top.insertsym(descriptor);
      include(descriptor.symoptions,sp_internal);
      { create typed constant for the descriptor }
      str_parse_typedconst(CurrentAsmData.AsmLists[al_const],
        '(reserved: 0; Block_size: '+ToStr(block_literal_size)+
        '; signature: '''+objcencodemethod(invokepd)+''');',descriptor);
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
      wrappername:='__FPC_BLOCK_INVOKE_'+upper(copy(orgpd.procsym.realname,1,60))+'_'+ToStr(orgpd.owner.ModuleID)+'_'+orgpd.UniqueIDStr;
      { already an invoke wrapper for this procsym -> reuse }
      if searchsym(wrappername,srsym,srsymtable) then
        begin
          if (srsym.typ<>procsym) or
             (TProcSym(srsym).procdeflist.count<>1) then
            InternalError(2014071503);
          result:=TProcDef(TProcSym(srsym).procdeflist[0]);
          exit;
        end;
      { bare copy, so that self etc are not inserted }
      result:=TProcDef(orgpd.getcopyas(procdef,pc_bareproc,'',true));
      { will be called according to the ABI conventions }
      result.proccalloption:=pocall_cdecl;
      { add po_is_block so that a block "self" pointer gets added (of the type
        returned by get_block_literal_type_for_proc()) }
      include(result.procoptions,po_is_block);
      { now insert self/vmt/funcret according to the newly set calling
        convention }
      insert_self_and_vmt_para(result);
      insert_funcret_para(result);
      finish_copied_procdef(result,wrappername,CurrentModule.localsymtable,nil);
      if orgpd.is_addressonly then
        begin
          result.synthetickind:=tsk_callthrough;
          result.skpara:=orgpd;
        end
      else
        begin
          { alias for the type to invoke the procvar, used in the symcreat
            handling of tsk_block_invoke_procvar }
          result.localst.insertsym(CTypeSym.create('__FPC_BLOCK_INVOKE_PV_TYPE',orgpv));
          result.synthetickind:=tsk_block_invoke_procvar;
        end;
    end;


  { compose a block literal for a static block (one without context) }
  function get_global_proc_literal_sym(blockliteraldef: TDef; blockisasym: TStaticVarSym; blockflags: LongInt; invokepd: TProcDef; descriptor: TStaticVarSym): TStaticVarSym;
    var
      literalname: TIDString;
      srsym: TSym;
      srsymtable: TSymTable;
    begin
      literalname:='block_literal_for_'+invokepd.procsym.realname;
      { already exists -> return }
      if searchsym(literalname,srsym,srsymtable) then
        begin
          if srsym.typ<>staticvarsym then
            InternalError(2014071506);
          result:=TStaticVarSym(srsym);
          exit;
        end;
      { create new block literal symbol }
      result:=CStaticVarSym.create(
        '$'+literalname,
        vs_value,
        blockliteraldef,[]);
      include(result.symoptions,sp_internal);
      SymTableStack.top.insertsym(result);
      { initialise it }
      str_parse_typedconst(CurrentAsmData.AsmLists[al_const],
        '(base: (isa        : @'+blockisasym.realname+
              '; flags     : '+ToStr(blockflags)+
              '; reserved  : 0'+
              '; invoke    : @'+invokepd.procsym.realname+
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
      result:=internalstatements(statement);
      { create new block literal structure }
      literaltemp:=CTempCreateNode.create(blockliteraldef,blockliteraldef.size,tt_persistent,false);
      addstatement(statement,literaltemp);
      { temp.base.isa:=@blockisasym }
      addstatement(statement,CAssignmentNode.create(
        genloadfield(genloadfield(CTempRefNode.create(literaltemp),'BASE'),'ISA'),
        CAddrNode.create(CLoadNode.create(blockisasym,blockisasym.owner))));
      { temp.base.flags:=blockflags }
      addstatement(statement,CAssignmentNode.create(
        genloadfield(genloadfield(CTempRefNode.create(literaltemp),'BASE'),'FLAGS'),
        genintconstnode(blockflags)));
      { temp.base.reserved:=0 }
      addstatement(statement,CAssignmentNode.create(
        genloadfield(genloadfield(CTempRefNode.create(literaltemp),'BASE'),'RESERVED'),
        genintconstnode(0)));
      { temp.base.invoke:=tmethod(@invokepd) }
      addstatement(statement,CAssignmentNode.create(
        genloadfield(genloadfield(CTempRefNode.create(literaltemp),'BASE'),'INVOKE'),
        CTypeConvNode.create_proc_to_procvar(
          CLoadNode.create_procvar(invokepd.procsym,invokepd,invokepd.owner))));
      { temp.base.descriptor:=@descriptor }
      addstatement(statement,CAssignmentNode.create(
        genloadfield(genloadfield(CTempRefNode.create(literaltemp),'BASE'),'DESCRIPTOR'),
        CAddrNode.create(CLoadNode.create(descriptor,descriptor.owner))));
      { temp.pv:=tmethod(@orgpd) }
      addstatement(statement,CAssignmentNode.create(
        CTypeConvNode.create_explicit(genloadfield(CTempRefNode.create(literaltemp),'PV'),orgpv),
          procvarnode.getcopy));
      { and return the address of the temp }
      addstatement(statement,CAddrNode.create(CTempRefNode.create(literaltemp)));
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
         is_nested_pd(TProcDef(procloadnode.resultdef)) or
         is_objcclass(TDef(procloadnode.resultdef.owner.defowner)) then
        InternalError(2014071401);

      { add every symbol that we create here to the unit-level symbol table }
      old_symtablestack:=SymTableStack;
      SymTableStack:=old_symtablestack.getcopyuntil(CurrentModule.localsymtable);
      { save scanner state }
      replace_scanner('block literal creation',sstate);

      { def representing the original function }
      orgpd:=TProcDef(procloadnode.resultdef);
      { def representing the corresponding procvar type }
      procvarnode:=CTypeConvNode.create_proc_to_procvar(procloadnode.getcopy);
      TypeCheckPass(procvarnode);
      orgpv:=TProcVarDef(procvarnode.resultdef);
      { get blockdef for this kind of procdef }
      blockliteraldef:=get_block_literal_type_for_proc(orgpd);
      { get the invoke wrapper }
      invokepd:=get_invoke_wrapper(orgpd,orgpv);
      { get the descriptor }
      descriptor:=get_block_literal_descriptor(invokepd,blockliteraldef.size);
      { get the ISA pointer for the literal }
      blockisasym:=get_block_literal_isa(orgpd);
      { get the flags for the block }
      blockflags:=get_block_literal_flags(orgpd,invokepd);
      { global/simple procedure -> block literal is a typed constant }
      if orgpd.is_addressonly then
        begin
          blockliteralsym:=get_global_proc_literal_sym(blockliteraldef,blockisasym,blockflags,invokepd,descriptor);
          { result: address of the block literal }
          result:=CAddrNode.create(CLoadNode.create(blockliteralsym,blockliteralsym.owner));
        end
      else
        begin
          result:=get_pascal_method_literal(blockliteraldef,blockisasym,blockflags,procvarnode,invokepd,orgpv,descriptor)
        end;

      procvarnode.free;
      procvarnode := nil;

      { restore scanner }
      restore_scanner(sstate);
      { restore symtable stack }
      SymTableStack.free;
      SymTableStack:=old_symtablestack;
    end;

end.

