{
    Copyright (c) 2000-2002 by Florian Klaempfl

    This unit implements some basic nodes

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
unit nbas;

{$i fpcdefs.inc}

interface

    uses
       GlobType,
       cgbase,cgutils,
       aasmtai,AAsmData,aasmcpu,
       node,
       symtype;

    type
       TNothingNode = class(TNode)
          constructor create;virtual;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
       end;
       TNothingNodeClass = class of TNothingNode;

       TErrorNode = class(TNode)
          constructor create;virtual;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          procedure mark_write;override;
       end;
       TErrorNodeClass = class of TErrorNode;

       TSpecializeNode = class(TUnaryNode)
          sym:TSym;
          getaddr:boolean;
          inheriteddef:TDef;
          unit_specific:boolean;
          constructor create(l:TNode;g:boolean;s:TSym;u:boolean);virtual;
          constructor create_inherited(l:TNode;g:boolean;s:TSym;i:TDef);virtual;
          function pass_1:TNode;override;
          function pass_typecheck:TNode;override;
       end;
       TSpecializeNodeClass = class of TSpecializeNode;

       TFinalizeTempsNode = class(TNode)
          constructor create;virtual;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode): boolean; override;
       end;
       TFinalizeTempsNodeClass = class of TFinalizeTempsNode;

       TAsmNodeFlag = (
         asmnf_get_asm_position,
         { Used registers in assembler block }
         asmnf_has_registerlist
       );

       TAsmNodeFlags = set of TAsmNodeFlag;

       TAsmNode = class(TNode)
          asmnodeflags : TAsmNodeFlags;
          p_asm : TAsmList;
          currenttai : TAI;
          constructor create(p : TAsmList);virtual;
          constructor create_get_position;
          destructor Destroy;override;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure derefimpl;override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode): boolean; override;
       end;
       TAsmNodeClass = class of TAsmNode;

       TStatementNode = class(TBinaryNode)
          constructor create(l,r : TNode);virtual;
          function simplify(forinline : boolean) : TNode; override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          procedure printnodetree(var t:text);override;
          property statement : TNode read left write left;
          property next : TNode read right write right;
       end;
       TStatementNodeClass = class of TStatementNode;

       TBlockNodeFlag = (
         bnf_strippable { Block node can be removed via simplify etc. }
       );

       TBlockNodeFlags = set of TBlockNodeFlag;

       TBlockNode = class(TUnaryNode)
          blocknodeflags : TBlockNodeFlags;
          constructor create(l : TNode);virtual;
          destructor Destroy; override;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          function dogetcopy : TNode;override;
          function simplify(forinline : boolean) : TNode; override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
{$ifdef state_tracking}
          function track_state_pass(exec_known:boolean):boolean;override;
{$endif state_tracking}
          property statements : TNode read left write left;
       end;
       TBlockNodeClass = class of TBlockNode;

       TTempCreateNode = class;

       TTempInfoFlag = (
         { temp can be kept in a register as far as the original creator is
          concerned }
         ti_may_be_in_reg,
         { the ttempcreatenode has been process and the temp's location is
           valid (-> the ttempdeletenode has not yet been processed, or
           in case it's a "create_to_normal()" one, the final ttemprefnode
           has not yet been processed) }
         ti_valid,
         { when performing a getcopy of a nodetree, we have to hook up the
           copies of ttemprefnodes and ttempdestroynode to the copied
           ttempinfo. this is done by setting hookoncopy in the original
           ttempinfo to point to the new one. if the temp is deleted via a
           regular ttempdeletenode, the hookoncopy is simply set to nil once
           it's processed. otherwise, it sets the ti_nextref_set_hookoncopy_nil
           and after processing the final ttemprefnode, hookoncopy is set to nil
         }
         ti_nextref_set_hookoncopy_nil,
         { the address of this temp is taken (-> cannot be kept in a register,
           even if the creator didn't mind)
         }
         ti_addr_taken,
         { temps can get an extra node tree that contains the value to which
           they should be initialised when they are created. this initialisation
           has to be performed right before the first reference to the temp.
           this flag indicates that the ttempcreatenode has been
           processed by pass_generate_code, but that the first ttemprefnode
           hasn't yet and hence will have to perform the initialisation
         }
         ti_executeinitialisation,
         { in case an expression like "inc(x[func()],1)" is translated into
           a regular addition, you have to create a temp to hold the address
           representing x[func()], since otherwise func() will be called twice
           and that can spell trouble in case it has side effects. on platforms
           without pointers, we cannot just take the address though. this flag
           has to be combined with ti_executeinitialisation above and will,
           rather than loading the value at the calculated location and store
           it in the temp, keep a copy of the calculated location if possible
           and required (not possible for regvars, because SSA may change their
           register, but not required for them either since calculating their
           location has no side-effects
         }
         ti_reference,
         { this temp only allows reading (makes it possible to safely use as
           reference under more circumstances)
         }
         ti_readonly,
         { if this is a managed temp, it doesn't have to be finalised before use
         }
         ti_nofini,
         { the value described by this temp. node is const/immutable, this is important for
           managed types like ansistrings where temp. refs are pointers to the actual value
           -- in this case, assignments to the temp do not increase the
             reference count, and if the assigned value was a temp itself then
             that temp is not deallocated until this temp is deleted (since
             otherwise the assigned value may be freed before the last use of
             the temp) }
         ti_const,
         { the temp. needs no final sync instruction if it is located in a register,
           so there are no loops involved in the usage of the temp.
         }
         ti_no_final_regsync,
         { this applied only to delete nodes: the single purpose of the temp. delete node is to clean up memory. In case
           of cse it might happen that the tempcreate node is optimized away so tempinfo is never initialized properly but
           the allocated memory must be disposed
           If a temp. node has this flag set, the life time of the temp. data must be determined by reg. life, the temp.
           location (in the sense of stack space/register) is never release }
         ti_cleanup_only
         );
       TTempInfoFlags = set of TTempInfoFlag;

     const
       tempinfostoreflags = [ti_may_be_in_reg,ti_addr_taken,ti_reference,ti_readonly,ti_no_final_regsync,ti_nofini,ti_const];

     type
       { to allow access to the location by temp references even after the temp has }
       { already been disposed and to make sure the coherency between temps and     }
       { temp references is kept after a getcopy                                    }
       PTempInfo = ^TTempInfo;
       TTempInfo = record
        private
         flags                      : TTempInfoFlags;
        public
         { set to the copy of a tempcreate pnode (if it gets copied) so that the }
         { refs and deletenode can hook to this copy once they get copied too    }
         hookoncopy                 : PTempInfo;
         typedef                    : TDef;
         TypeDefDeref               : TDeref;
         temptype                   : TTempType;
         owner                      : TTempCreateNode;
         withnode                   : TNode;
         location                   : TLocation;
         tempinitcode               : TNode;
       end;

       TTempInfoAccessor = class
         class procedure settempinfoflags(tempinfo: PTempInfo; const flags: TTempInfoFlags); virtual;
         class function gettempinfoflags(tempinfo: PTempInfo): TTempInfoFlags; static; inline;
       end;
       TTempInfoAccessorClass = class of TTempInfoAccessor;

       TTempBaseNode = class(TNode)
        protected
          class var tempinfoaccessor: TTempInfoAccessorClass;
        protected
          procedure settempinfoflags(const tempflags: TTempInfoFlags); inline;
          function gettempinfoflags: TTempInfoFlags; inline;
        public
          tempinfo: PTempInfo;
          procedure includetempflag(flag: TTempInfoFlag); inline;
          procedure excludetempflag(flag: TTempInfoFlag); inline;
          property tempflags: TTempInfoFlags read gettempinfoflags write settempinfoflags;
       end;

       { a node which will create a (non)persistent temp of a given type with a given  }
       { size (the size is separate to allow creating "void" temps with a custom size) }
       TTempCreateNode = class(TTempBaseNode)
          size: TCGInt;
          ftemplvalue : TNode;
          { * persistent temps are used in manually written code where the temp }
          { be usable among different statements and where you can manually say }
          { when the temp has to be freed (using a ttempdeletenode)             }
          { * non-persistent temps are mostly used in typeconversion helpers,   }
          { where the node that receives the temp becomes responsible for       }
          { freeing it. In this last case, you must use only one reference      }
          { to it and *not* generate a ttempdeletenode                          }
          constructor create(_typedef: TDef; _size: TCGInt; _temptype: TTempType;allowreg:boolean); virtual;
          constructor create_withnode(_typedef: TDef; _size: TCGInt; _temptype: TTempType; allowreg:boolean; withnode: TNode); virtual;
          constructor create_value(_typedef:TDef; _size: TCGInt; _temptype: TTempType;allowreg:boolean; templvalue: TNode);
          constructor create_reference(_typedef:TDef; _size: TCGInt; _temptype: TTempType;allowreg:boolean; templvalue: TNode; readonly: boolean);
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure derefimpl;override;
          function dogetcopy: TNode; override;
          function pass_1 : TNode; override;
          function pass_typecheck: TNode; override;
          function docompare(p: TNode): boolean; override;
          procedure printnodedata(var t:text);override;
        end;
       TTempCreateNodeClass = class of TTempCreateNode;

        { a node which is a reference to a certain temp }
        TTempRefNode = class(TTempBaseNode)
          constructor create(const temp: TTempCreateNode); virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure resolveppuidx;override;
          function dogetcopy: TNode; override;
          function pass_1 : TNode; override;
          function pass_typecheck : TNode; override;
          procedure mark_write;override;
          function docompare(p: TNode): boolean; override;
          procedure printnodedata(var t:text);override;
         private
          tempidx : LongInt;
        end;
       TTempRefNodeClass = class of TTempRefNode;

        { a node which removes a temp }
        TTempDeleteNode = class(TTempBaseNode)
          constructor create(const temp: TTempCreateNode); virtual;
          { this will convert the persistent temp to a normal temp
            for returning to the other nodes }
          constructor create_normal_temp(const temp: TTempCreateNode);
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure resolveppuidx;override;
          function dogetcopy: TNode; override;
          function pass_1: TNode; override;
          function pass_typecheck: TNode; override;
          function docompare(p: TNode): boolean; override;
          destructor Destroy; override;
          procedure printnodedata(var t:text);override;
         protected
          release_to_normal : boolean;
        private
          tempidx : LongInt;
        end;
       TTempDeleteNodeClass = class of TTempDeleteNode;

    var
       CNothingNode : TNothingNodeClass = TNothingNode;
       CErrorNode : TErrorNodeClass = TErrorNode;
       CSpecializeNode : TSpecializeNodeClass = TSpecializeNode;
       CFinalizeTempsNode: TFinalizeTempsNodeClass = TFinalizeTempsNode;
       CAsmNode : TAsmNodeClass = TAsmNode;
       CStatementNode : TStatementNodeClass = TStatementNode;
       CBlockNode : TBlockNodeClass = TBlockNode;
       CTempInfoAccessor : TTempInfoAccessorClass = TTempInfoAccessor;
       CTempCreateNode : TTempCreateNodeClass = TTempCreateNode;
       CTempRefNode : TTempRefNodeClass = TTempRefNode;
       CTempDeleteNode : TTempDeleteNodeClass = TTempDeleteNode;

       { Create a blocknode and statement node for multiple statements
         generated internally by the parser }
       function  internalstatements(out laststatement:TStatementNode):TBlockNode;
       function  laststatement(block:TBlockNode):TStatementNode;
       procedure addstatement(var laststatement:TStatementNode;n:TNode);

       { true if p is a statement expression with anonymous functions as values,
         which still needs to be converted to a procvar or function reference }
       function is_deferred_stmt_expr(p : TNode) : boolean;

       { if the complexity of n is "high", creates a reference temp to n's
         location and replace n with a ttemprefnode referring to that location }
       function maybereplacewithtempref(var n: TNode; var block: TBlockNode; var stat: TStatementNode; size: ASizeInt; readonly: boolean): TTempCreateNode;
       { same as above, but create a regular temp rather than reference temp }
       function maybereplacewithtemp(var n: TNode; var block: TBlockNode; var stat: TStatementNode; size: ASizeInt; allowreg: boolean): TTempCreateNode;

implementation

    uses
      Verbose,Globals,Systems,
      PPU,
      SymSym,symconst,symdef,defutil,defcmp,
      pass_1,
      nutils,nld,ncnv,
      ProcInfo
      ;


{*****************************************************************************
                                     Helpers
*****************************************************************************}

    function is_deferred_stmt_expr(p : TNode) : boolean;
      var
        stmt : TStatementNode;
      begin
        result:=false;
        if (p.nodetype<>blockn) or
            not Assigned(p.resultdef) or
            (p.resultdef.typ<>procdef) or
            not (po_anonymous in TProcDef(p.resultdef).ProcOptions) then
          exit;

        { skip the nothing node created by internalstatements }
        stmt:=TStatementNode(TBlockNode(p).left);
        while Assigned(stmt) and
            Assigned(stmt.left) and
            (stmt.left.nodetype=nothingn) do
          stmt:=TStatementNode(stmt.right);

        result:=Assigned(stmt) and
                Assigned(stmt.left) and
                (stmt.left.nodetype=tempcreaten);
      end;


    function internalstatements(out laststatement:TStatementNode):TBlockNode;
      begin
        { create dummy initial statement }
        laststatement := CStatementNode.create(CNothingNode.create,nil);
        result := CBlockNode.create(laststatement);
        Include(result.blocknodeflags, bnf_strippable);
      end;


    function laststatement(block:TBlockNode):TStatementNode;
      begin
        result:=TStatementNode(block.left);
        while Assigned(result) and Assigned(result.right) do
          result:=TStatementNode(result.right);
      end;


    procedure addstatement(var laststatement:TStatementNode;n:TNode);
      begin
        if Assigned(laststatement.right) then
          InternalError(200204201);
        laststatement.right:=CStatementNode.create(n,nil);
        laststatement:=TStatementNode(laststatement.right);
      end;


    function maybereplacewithtempref(var n: TNode; var block: TBlockNode; var stat: TStatementNode; size: ASizeInt; readonly: boolean): TTempCreateNode;
      begin
        result:=nil;
        if (node_complexity(n)>4) or
           might_have_sideeffects(n) then
          begin
            result:=CTempCreateNode.create_reference(n.resultdef,size,tt_persistent,true,n,readonly);
            TypeCheckPass(TNode(result));
            n:=CTempRefNode.create(result);
            TypeCheckPass(n);
            if not Assigned(stat) then
              block:=internalstatements(stat);
            addstatement(stat,result)
          end;
      end;

    function maybereplacewithtemp(var n: TNode; var block: TBlockNode; var stat: TStatementNode; size: ASizeInt; allowreg: boolean): TTempCreateNode;
      begin
        result:=nil;
        if (node_complexity(n)>4) or
           might_have_sideeffects(n) then
          begin
            result:=CTempCreateNode.create_value(n.resultdef,size,tt_persistent,allowreg,n);
            TypeCheckPass(TNode(result));
            n:=CTempRefNode.create(result);
            TypeCheckPass(n);
            if not Assigned(stat) then
              block:=internalstatements(stat);
            addstatement(stat,result)
          end;
      end;

{*****************************************************************************
                             TFIRSTNOTHING
*****************************************************************************}

    constructor TNothingNode.create;
      begin
        inherited create(nothingn);
      end;


    function TNothingNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=VoidType;
      end;


    function TNothingNode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_VOID;
      end;


{*****************************************************************************
                             TFIRSTERROR
*****************************************************************************}

    constructor TErrorNode.create;

      begin
         inherited create(errorn);
      end;


    function TErrorNode.pass_typecheck:TNode;
      begin
         result:=nil;
         include(transientflags,tnf_error);
         CodeGenError:=true;
         resultdef:=GenErrorDef;
      end;


    function TErrorNode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_VOID;
         CodeGenError:=true;
      end;


    procedure TErrorNode.mark_write;
      begin
      end;


{*****************************************************************************
                             TSPECIALIZENODE
*****************************************************************************}

    constructor TSpecializeNode.create(l:TNode;g:boolean;s:TSym;u:boolean);
      begin
         inherited create(specializen,l);
         sym:=s;
         getaddr:=g;
         unit_specific:=u;
      end;

    constructor TSpecializeNode.create_inherited(l:TNode;g:boolean;s:TSym;i:TDef);
      begin
        create(l,g,s,false);
        inheriteddef:=i;
      end;


    function TSpecializeNode.pass_typecheck:TNode;
      begin
         result:=nil;
         resultdef:=CUndefinedType;
      end;


    function TSpecializeNode.pass_1:TNode;
      begin
         { such a node should not reach pass_1 }
         InternalError(2015071704);
         result:=nil;
         expectloc:=LOC_VOID;
         CodeGenError:=true;
      end;


{*****************************************************************************
                             TFINALIZETEMPSNODE
*****************************************************************************}

    constructor TFinalizeTempsNode.create;
      begin
        inherited create(finalizetempsn);
      end;

    function TFinalizeTempsNode.pass_1: TNode;
      begin
        result:=nil;
        expectloc:=LOC_VOID;
      end;

    function TFinalizeTempsNode.pass_typecheck: TNode;
      begin
        resultdef:=VoidType;
        result:=nil;
      end;

    function TFinalizeTempsNode.docompare(p: TNode): boolean;
      begin
        { these nodes should never be coalesced }
        result:=false;
      end;


{*****************************************************************************
                            TSTATEMENTNODE
*****************************************************************************}

    constructor TStatementNode.create(l,r : TNode);

      begin
         inherited create(statementn,l,r);
      end;


    function TStatementNode.simplify(forinline: boolean) : TNode;
      begin
        result:=nil;
        { these "optimizations" are only to make it more easy to recognise    }
        { blocknodes which at the end of inlining only contain one single     }
        { statement. Simplifying inside blocknode.simplify could be dangerous }
        { because if the main blocknode which makes up a procedure/function   }
        { body were replaced with a statementn/nothingn, this could cause     }
        { problems elsewhere in the compiler which expects a blocknode        }

        { remove next statement if it's a nothing-statement (since if it's }
        { the last, it won't remove itself -- see next simplification)     }
        while Assigned(right) and
              (TStatementNode(right).left.nodetype = nothingn) do
          begin
            result:=TStatementNode(right).right;
            TStatementNode(right).right:=nil;
            right.free;
            right:=result;
            result:=nil;
          end;

        { Remove initial nothingn if there are other statements. If there }
        { are no other statements, returning nil doesn't help (will be    }
        { interpreted as "can't be simplified") and replacing the         }
        { statementnode with a nothingnode cannot be done (because it's   }
        { possible this statementnode is a child of a blocknode, and      }
        { blocknodes are expected to only contain statementnodes)         }
        if (left.nodetype = nothingn) and
           Assigned(right) then
          begin
            result:=right;
            right:=nil;
            exit;
          end;

        { if the current statement contains a block with one statement,
          replace the current statement with that block's statement
          (but only if the block does not have nf_block_with_exit set
           or has no exit statement, because otherwise it needs an own
           exit label, see tests/test/tinline10)

           Further, it might not be the user code entry
        }
        if (left.nodetype = blockn) and
           ((left.flags*[nf_block_with_exit,nf_usercode_entry]=[]) or
            ((left.flags*[nf_block_with_exit,nf_usercode_entry]=[nf_block_with_exit]) and not has_node_of_type(left, [exitn]))) and
           Assigned(TBlockNode(left).left) and
           not Assigned(TStatementNode(TBlockNode(left).left).right) then
          begin
            result:=TBlockNode(left).left;
            TStatementNode(result).right:=right;
            right:=nil;
            TBlockNode(left).left:=nil;
            exit;
          end;
      end;


    function TStatementNode.pass_typecheck:TNode;
      begin
         result:=nil;
         resultdef:=VoidType;

         { left is the statement itself calln assignn or a complex one }
         TypeCheckPass(left);
         if CodeGenError then
           exit;

         { right is the next statement in the list }
         if Assigned(right) then
           TypeCheckPass(right);
         if CodeGenError then
           exit;
      end;


    function TStatementNode.pass_1 : TNode;
      begin
         result:=nil;
         { left is the statement itself calln assignn or a complex one }
         FirstPass(left);
         if CodeGenError then
           exit;
         expectloc:=left.expectloc;
         { right is the next in the list }
         if Assigned(right) then
           FirstPass(right);
         if CodeGenError then
           exit;
      end;


    procedure TStatementNode.printnodetree(var t:text);
      begin
        printnodelist(t);
      end;

{*****************************************************************************
                             TBLOCKNODE
*****************************************************************************}

    constructor TBlockNode.create(l : TNode);

      begin
         inherited create(blockn,l);
         blocknodeflags:=[];
      end;

    destructor TBlockNode.Destroy;

      var
        hp, next: TStatementNode;
      begin
        hp := TStatementNode(left);
        left := nil;
        while Assigned(hp) do
          begin
            next := TStatementNode(hp.right);
            hp.right := nil;
            hp.free;
            hp := next;
          end;
        inherited Destroy;
      end;


    constructor TBlockNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.GetSet(TPPUSet1(blocknodeflags));
      end;


    procedure TBlockNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutSet(TPPUSet1(blocknodeflags));
      end;


    function TBlockNode.dogetcopy : TNode;
      begin
        Result:=inherited dogetcopy;
        TBlockNode(Result).blocknodeflags:=blocknodeflags;
      end;


    function NodesEqual(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        if n.IsEqual(TNode(arg)) then
          result:=fen_norecurse_true
        else
          result:=fen_false;
      end;


    function TBlockNode.simplify(forinline : boolean): TNode;
      const
        NodeStripTerminators = [labeln, asmn, tempcreaten, tempdeleten];

      var
        n, p, first, last: TStatementNode;
{$ifdef break_inlining}
        a : array[0..3] of TStatementNode;
{$endif break_inlining}
      begin
        result := nil;
        { Warning: never replace a blocknode with another node type,
          since the block may be the main block of a procedure/function/
          main program body, and those nodes should always be blocknodes
          since that's what the compiler expects elsewhere. }

        if Assigned(left) then
          begin
            if not Assigned(TStatementNode(left).right) then
              begin
                { Block has a lone statement }
                case TStatementNode(left).left.nodetype of
                  blockn:
                    begin
                      { if the current block contains only one statement, and
                        this one statement only contains another block, replace
                        this block with that other block.                       }
                      result:=TStatementNode(left).left;
                      TStatementNode(left).left:=nil;
                      { make sure the nf_block_with_exit flag is safeguarded }
                      result.flags:=result.flags+(flags*[nf_block_with_exit,nf_usercode_entry]);
                      exit;
                    end;
                  nothingn:
                    begin
                      { if the block contains only a statement with a nothing node,
                        get rid of the statement }
                      left.Free;
                      left:=nil;
                      exit;
                    end;
                  else
                    ;
                end;
              end
            else if forinline or (cs_opt_level2 in CurrentSettings.OptimizerSwitches) then
              begin
                n := TStatementNode(left);
                while Assigned(n) do
                  begin
                    case n.left.nodetype of
                      raisen, exitn, breakn, continuen, goton:
                        { Remove all subsequent statements, stopping only at a
                          label or asm block since code can theoretically jump
                          to them.  Also, don't delete temp creates and deletes }
                        begin
                          last := n;
                          p := TStatementNode(n.Next);
                          while Assigned(p) do
                            begin
                              if has_node_of_type(TStatementNode(p).left, NodeStripTerminators) then
                                Break;

                              last := p;
                              p := TStatementNode(p.Next);
                            end;

                          if (last <> n) then
                            begin
                              last.next := nil; { Make sure we stop one before p }
                              n.next.Free;
                              n.next := p;
                              n := p;
                              Continue;
                            end;
                        end;
                      else
                        ;
                    end;

                    { Look one statement ahead in case it can be deleted - we
                      need the previous statement to stitch the tree correctly
                    }
                    p := TStatementNode(n.Next);
                    if not Assigned(p) then
                      Break;

                    if Assigned(p.left) then
                      begin
                        case p.left.nodetype of
                          blockn:
                            if (bnf_strippable in TBlockNode(p.left).blocknodeflags) and
                              ((p.left.flags * [nf_block_with_exit] = []) or not has_node_of_type(p.left, [exitn])) then
                              begin
                                { Attempt to merge this block into the main statement
                                  set }

                                { Find last statement }
                                first := TStatementNode(TBlockNode(p.left).PruneKeepLeft());
                                if Assigned(first) then
                                  begin
                                    last := first;
                                    while Assigned(last.right) do
                                      last := TStatementNode(last.right);

                                    n.right := first;
                                  end
                                else
                                  last := n;

                                last.right := p.PruneKeepRight();

                                { make sure the nf_usercode_entry flag is safeguarded }
                                Flags := Flags + (p.left.flags * [nf_usercode_entry]);

                                p.Free;
                                p := nil;
                                Continue;
                              end;
                          else
                            ;
                        end;
                      end;
                    n := TStatementNode(n.Next);
                  end;
              end;
          end;
{$ifdef break_inlining}
        { simple sequence of tempcreate, assign and return temp.? }
        if GetStatements(left,a) and
          (a[0].left.nodetype=tempcreaten) and
          (a[1].left.nodetype=assignn) and
          (actualtargetnode(@TAssignmentNode(a[1].left).left)^.nodetype=temprefn) and
          (a[2].left.nodetype=tempdeleten) and
          (a[3].left.nodetype=temprefn) and
          (TTempCreateNode(a[0].left).tempinfo=TTempRefNode(actualtargetnode(@TAssignmentNode(a[1].left).left)^).tempinfo) and
          (TTempCreateNode(a[0].left).tempinfo=TTempDeleteNode(a[2].left).tempinfo) and
          (TTempCreateNode(a[0].left).tempinfo=TTempRefNode(a[3].left).tempinfo) and
          { the temp. node might not be references inside the assigned expression }
          not(foreachnodestatic(TAssignmentNode(a[1].left).right,@NodesEqual,actualtargetnode(@TAssignmentNode(a[1].left).left)^)) then
          begin
            result:=TAssignmentNode(a[1].left).right;
            TAssignmentNode(a[1].left).right:=nil;
            { ensure the node is first passed, so the resultdef does not get changed if the
              the type conv. below is merged }
            FirstPass(result);
            result:=CTypeConvNode.Create_Internal(result,TTempRefNode(a[3].left).resultdef);
            FirstPass(result);
            exit;
          end;
{$endif break_inlining}
      end;


    function TBlockNode.pass_typecheck:TNode;
      var
         hp : TStatementNode;
      begin
         result:=nil;
         resultdef:=VoidType;

         hp:=TStatementNode(left);
         while Assigned(hp) do
           begin
              if Assigned(hp.left) then
                begin
                   CodeGenError:=false;
                   TypeCheckPass(hp.left);
                   { the resultdef of the block is the last type that is
                     returned. Normally this is a voidtype. But when the
                     compiler inserts a block of multiple statements then the
                     last entry can return a value }
                   resultdef:=hp.left.resultdef;
                end;
              hp:=TStatementNode(hp.right);
           end;
      end;


    function TBlockNode.pass_1 : TNode;
      var
         php,hp,chp : TStatementNode;
         FirstNode: Boolean;
         //count : longint;
      begin
         result:=nil;
         expectloc:=LOC_VOID;
         if is_deferred_stmt_expr(self) then
           begin
             { statement expression with anonymous functions, which was
               not converted to a procvar or function reference }
             CGMessage(parser_e_stmt_expr_anon_needs_type);
             exit;
           end;
         //count:=0;
         hp:=TStatementNode(left);
         php:=nil;
         chp:=nil;
         FirstNode := True;
         while Assigned(hp) do
           begin
              if Assigned(hp.left) then
                begin
                   { Calling firstpass on a statement node normally causes
                     problems, so we have to be a little bit hacky if we want
                     to remove nothing nodes }
                   CodeGenError:=false;
                   chp:=TStatementNode(hp);
                   FirstPass(TNode(hp));
                   { If the first node gets deleted, left must be updated,
                     otherwise it will be a dangling pointer }
                   if FirstNode then
                     begin
                       { If multiple statements are to be removed, they would
                         have all been removed by the firstpass call above, so
                         the next one will not be removed, hence it's safe to
                         set FirstNode to false }
                       FirstNode := False;
                       left := hp;
                     end
                   else if (chp<>hp) then
                     begin
                       { If FirstPass modified HP,
                         we must update php.right }
                       if Assigned(php) then
                         php.right:=hp;
                     end;
                   if Assigned(hp.left) then
                     hp.expectloc:=hp.left.expectloc;
                end;
              expectloc:=hp.expectloc;
              //inc(count);
              php:=hp;
              hp:=TStatementNode(hp.right);
           end;
      end;

{$ifdef state_tracking}
      function TBlockNode.track_state_pass(exec_known:boolean):boolean;

      var hp:TStatementNode;

      begin
        track_state_pass:=false;
        hp:=TStatementNode(left);
        while Assigned(hp) do
            begin
                if hp.left.track_state_pass(exec_known) then
                    track_state_pass:=true;
                hp:=TStatementNode(hp.right);
            end;
      end;
{$endif state_tracking}

{*****************************************************************************
                             TASMNODE
*****************************************************************************}

    constructor TAsmNode.create(p : TAsmList);
      begin
        inherited create(asmn);
        p_asm:=p;
        asmnodeflags:=[];
        currenttai:=nil;
      end;


    constructor TAsmNode.create_get_position;
      begin
        inherited create(asmn);
        p_asm:=nil;
        asmnodeflags:=[asmnf_get_asm_position];
        currenttai:=nil;
      end;


    destructor TAsmNode.Destroy;
      begin
        if Assigned(p_asm) then
          begin
            p_asm.free;
            p_asm := nil;
          end;
        inherited Destroy;
      end;


    constructor TAsmNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      var
        hp : TAI;
      begin
        inherited ppuload(t,ppufile);
        ppufile.GetSet(TPPUSet1(asmnodeflags));
        if not(asmnf_get_asm_position in asmnodeflags) then
          begin
            p_asm:=TAsmList.create;
            repeat
              hp:=ppuloadai(ppufile);
              if hp=nil then
                break;
              p_asm.concat(hp);
              if hp.typ=ait_section then
                inc(p_asm.section_count);
            until false;
          end
        else
          p_asm:=nil;
        currenttai:=nil;
      end;


    procedure TAsmNode.ppuwrite(ppufile:TCompilerPPUFile);
      var
        hp : TAI;
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutSet(TPPUSet1(asmnodeflags));
{ TODO: FIXME Add saving of register sets}
        if not(asmnf_get_asm_position in asmnodeflags) then
          begin
            hp:=TAI(p_asm.first);
            while Assigned(hp) do
             begin
               ppuwriteai(ppufile,hp);
               hp:=TAI(hp.next);
             end;
            { end is marked by a nil }
            ppuwriteai(ppufile,nil);
          end;
      end;


    procedure TAsmNode.BuildDerefImpl;
      var
        hp : TAI;
      begin
        inherited BuildDerefImpl;
        if not(asmnf_get_asm_position in asmnodeflags) then
          begin
            hp:=TAI(p_asm.first);
            while Assigned(hp) do
             begin
               hp.BuildDerefImpl;
               hp:=TAI(hp.next);
             end;
          end;
      end;


    procedure TAsmNode.derefimpl;
      var
        hp : TAI;
      begin
        inherited derefimpl;
        if not(asmnf_get_asm_position in asmnodeflags) then
          begin
            hp:=TAI(p_asm.first);
            while Assigned(hp) do
             begin
               hp.derefimpl;
               hp:=TAI(hp.next);
             end;
          end;
      end;


    function TAsmNode.dogetcopy: TNode;
      var
        n: TAsmNode;
      begin
        n:=TAsmNode(inherited dogetcopy);
        n.asmnodeflags:=asmnodeflags;
        if Assigned(p_asm) then
          begin
            n.p_asm:=TAsmList.create;
            n.p_asm.ConcatListCopy(p_asm);
          end
        else
          n.p_asm:=nil;
        n.currenttai:=currenttai;
        result:=n;
      end;


    function TAsmNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=VoidType;
        if not(asmnf_get_asm_position in asmnodeflags) then
          include(CurrentProcInfo.flags,pi_has_assembler_block);
      end;


    function TAsmNode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_VOID;
      end;


    function TAsmNode.docompare(p: TNode): boolean;
      begin
        { comparing of asmlists is not implemented (JM) }
        docompare := false;
      end;


{*****************************************************************************
                          TEMPBASENODE
*****************************************************************************}

    class procedure TTempInfoAccessor.settempinfoflags(tempinfo: PTempInfo; const flags: TTempInfoFlags);
      begin
        tempinfo^.flags:=flags;
      end;


    class function TTempInfoAccessor.gettempinfoflags(tempinfo: PTempInfo): TTempInfoFlags;
      begin
        result:=tempinfo^.flags;
      end;


{*****************************************************************************
                          TEMPBASENODE
*****************************************************************************}

    procedure TTempBaseNode.settempinfoflags(const tempflags: TTempInfoFlags);
      begin
        CTempInfoAccessor.settempinfoflags(tempinfo,tempflags);
      end;


    function TTempBaseNode.gettempinfoflags: TTempInfoFlags;
      begin
        result:=CTempInfoAccessor.gettempinfoflags(tempinfo);
      end;


    procedure TTempBaseNode.includetempflag(flag: TTempInfoFlag);
      begin
        { go through settempinfoflags() so it can filter out unsupported tempflags }
        settempinfoflags(gettempinfoflags+[flag])
      end;


    procedure TTempBaseNode.excludetempflag(flag: TTempInfoFlag);
      begin
        { go through settempinfoflags() so it can prevent required tempflags from
          being removed (if any) }
        settempinfoflags(gettempinfoflags-[flag])
      end;


{*****************************************************************************
                          TEMPCREATENODE
*****************************************************************************}

    constructor TTempCreateNode.create(_typedef:TDef; _size: TCGInt; _temptype: TTempType;allowreg:boolean);
      begin
        inherited create(tempcreaten);
        size := _size;
        new(tempinfo);
        fillchar(tempinfo^,sizeof(tempinfo^),0);
        tempinfo^.typedef := _typedef;
        tempinfo^.temptype := _temptype;
        tempinfo^.owner := self;
        tempinfo^.withnode := nil;
        if allowreg and
           { temp must fit a single register }
           (TStoredDef(_typedef).Is_FPURegable or
            (TStoredDef(_typedef).Is_IntRegable and
             (_size<=TCgSize2Size[OS_64]))) and
           { size of register operations must be known }
           (Def_CGSize(_typedef)<>OS_NO) and
           { no init/final needed }
           not Is_Managed_Type(_typedef) then
          includetempflag(ti_may_be_in_reg);
      end;


    constructor TTempCreateNode.create_withnode(_typedef: TDef; _size: TCGInt; _temptype: TTempType; allowreg:boolean; withnode: TNode);
      begin
        self.create(_typedef,_size,_temptype,allowreg);
        tempinfo^.withnode:=withnode.GetCopy;
      end;


    constructor TTempCreateNode.create_value(_typedef:TDef; _size: TCGInt; _temptype: TTempType;allowreg:boolean; templvalue: TNode);
      begin
        self.create(_typedef,_size,_temptype,allowreg);
        // store in ppuwrite
        ftemplvalue:=templvalue;
        // create from stored ftemplvalue in ppuload
        tempinfo^.tempinitcode:=CAssignmentNode.create(CTempRefNode.create(self),ftemplvalue);
      end;


     constructor TTempCreateNode.create_reference(_typedef: TDef; _size: TCGInt; _temptype: TTempType; allowreg: boolean; templvalue: TNode; readonly: boolean);
      begin
        // store in ppuwrite
        self.create(_typedef,_size,_temptype,allowreg);
        ftemplvalue:=templvalue;
        // no assignment node, just the tempvalue
        tempinfo^.tempinitcode:=ftemplvalue;
        includetempflag(ti_reference);
        if readonly then
          includetempflag(ti_readonly);
      end;


    function TTempCreateNode.dogetcopy: TNode;
      var
        n: TTempCreateNode;
      begin
        n := TTempCreateNode(inherited dogetcopy);
        n.Size := size;

        new(n.tempinfo);
        fillchar(n.tempinfo^,sizeof(n.tempinfo^),0);
        n.tempinfo^.owner:=n;
        n.tempinfo^.typedef := tempinfo^.typedef;
        n.tempinfo^.temptype := tempinfo^.temptype;
        n.tempflags := tempflags * tempinfostoreflags;

        { when the tempinfo has already a hookoncopy then it is not
          reset by a tempdeletenode }
        if Assigned(tempinfo^.hookoncopy) then
          InternalError(200211262);
        { signal the temprefs that the temp they point to has been copied, }
        { so that if the refs get copied as well, they can hook themselves }
        { to the copy of the temp                                          }
        tempinfo^.hookoncopy := n.tempinfo;
        excludetempflag(ti_nextref_set_hookoncopy_nil);

        if Assigned(tempinfo^.withnode) then
          n.tempinfo^.withnode := tempinfo^.withnode.GetCopy
        else
          n.tempinfo^.withnode := nil;

        if Assigned(tempinfo^.tempinitcode) then
          n.tempinfo^.tempinitcode := tempinfo^.tempinitcode.GetCopy
        else
          n.tempinfo^.tempinitcode := nil;

        result := n;
      end;


    constructor TTempCreateNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);

        size:=ppufile.GetLongInt;
        new(tempinfo);
        fillchar(tempinfo^,sizeof(tempinfo^),0);
        ppufile.GetSet(TPPUSet2(tempinfo^.flags));
        ppufile.GetDeref(tempinfo^.TypeDefDeref);
        tempinfo^.temptype := TTempType(ppufile.GetByte);
        tempinfo^.owner:=self;
        tempinfo^.withnode:=ppuloadnode(ppufile);
        ftemplvalue:=ppuloadnode(ppufile);
      end;


    procedure TTempCreateNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutLongInt(size);
        ppufile.PutSet(TPPUSet2(tempinfo^.flags));
        ppufile.PutDeref(tempinfo^.TypeDefDeref);
        ppufile.PutByte(byte(tempinfo^.temptype));
        ppuwritenode(ppufile,tempinfo^.withnode);
        ppuwritenode(ppufile,ftemplvalue);
      end;


    procedure TTempCreateNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        tempinfo^.TypeDefDeref.build(tempinfo^.typedef);
        if Assigned(tempinfo^.withnode) then
          tempinfo^.withnode.BuildDerefImpl;
        if Assigned(ftemplvalue) then
          ftemplvalue.BuildDerefImpl;
      end;


    procedure TTempCreateNode.derefimpl;
      begin
        inherited derefimpl;
        tempinfo^.typedef:=TDef(tempinfo^.TypeDefDeref.resolve);
        if Assigned(tempinfo^.withnode) then
          tempinfo^.withnode.derefimpl;
        if Assigned(ftemplvalue) then
          begin
            ftemplvalue.derefimpl;
            tempinfo^.tempinitcode:=CAssignmentNode.create(CTempRefNode.create(self),ftemplvalue);
          end;
      end;


    function TTempCreateNode.pass_1 : TNode;
      begin
        result := nil;
        expectloc:=LOC_VOID;
        { temps which are immutable do not need to be initialized/finalized }
        if (tempinfo^.typedef.NeedsInitTable) and not(ti_const in tempflags) then
          include(CurrentProcInfo.flags,pi_needs_implicit_finally);
        if Assigned(tempinfo^.withnode) then
          FirstPass(tempinfo^.withnode);
        if Assigned(tempinfo^.tempinitcode) then
          FirstPass(tempinfo^.tempinitcode);
        inc(CurrentProcInfo.estimatedtempsize,size);
        { if a temp. create node is loaded from a ppu, it could be that the unit was compiled with other settings which
          enabled a certain type to be stored in a register while the current settings do not support this, so correct this here
          if needed
        }
        if not(TStoredDef(tempinfo^.typedef).Is_FPURegable) and not(TStoredDef(tempinfo^.typedef).Is_IntRegable) and (ti_may_be_in_reg in tempflags) then
          excludetempflag(ti_may_be_in_reg);
      end;


    function TTempCreateNode.pass_typecheck: TNode;
      begin
        result := nil;
        { a tempcreatenode doesn't have a resultdef, only temprefnodes do }
        resultdef := VoidType;
        if Assigned(tempinfo^.withnode) then
          TypeCheckPass(tempinfo^.withnode);
        if Assigned(tempinfo^.tempinitcode) then
          TypeCheckPass(tempinfo^.tempinitcode);
      end;


    function TTempCreateNode.docompare(p: TNode): boolean;
      begin
        result :=
          inherited docompare(p) and
          (TTempCreateNode(p).Size = size) and
          (TTempCreateNode(p).tempflags*tempinfostoreflags=tempflags*tempinfostoreflags) and
          Equal_Defs(TTempCreateNode(p).tempinfo^.typedef,tempinfo^.typedef) and
          (TTempCreateNode(p).tempinfo^.withnode.isequal(tempinfo^.withnode)) and
          (TTempCreateNode(p).tempinfo^.tempinitcode.isequal(tempinfo^.tempinitcode));
      end;


    procedure TTempCreateNode.printnodedata(var t:text);
      var
        f: TTempInfoFlag;
        first: Boolean;
      begin
        inherited printnodedata(t);
        WriteLn(t,PrintNodeIndention,'size = ',size,', temptypedef = ',tempinfo^.typedef.TypeSymbolPrettyName,' = "',
          tempinfo^.typedef.GetTypeName,'", tempinfo = $',HexStr(ptrint(tempinfo),sizeof(ptrint)*2));
        write(t,PrintNodeIndention,'[');
        first:=true;
        for f in tempflags do
          begin
            if not(first) then
              write(t,',');
            write(t,f);
            first:=false;
          end;
        WriteLn(t,']');
        WriteLn(t,PrintNodeIndention,'tempinit =');
        printnode(t,tempinfo^.tempinitcode);
      end;


{*****************************************************************************
                             TEMPREFNODE
*****************************************************************************}

    constructor TTempRefNode.create(const temp: TTempCreateNode);
      begin
        inherited create(temprefn);
        tempinfo := temp.tempinfo;
      end;


    function TTempRefNode.dogetcopy: TNode;
      var
        n: TTempRefNode;
      begin
        n := TTempRefNode(inherited dogetcopy);

        if Assigned(tempinfo^.hookoncopy) then
          { if the temp has been copied, assume it becomes a new }
          { temp which has to be hooked by the copied reference  }
          begin
            { hook the ref to the copied temp }
            n.tempinfo := tempinfo^.hookoncopy;
            { if we passed a ttempdeletenode that changed the temp }
            { from a persistent one into a normal one, we must be  }
            { the last reference (since our parent should free the }
            { temp (JM)                                            }
            if (ti_nextref_set_hookoncopy_nil in tempflags) then
              tempinfo^.hookoncopy := nil;
          end
        else
          { if the temp we refer to hasn't been copied, assume }
          { we're just a new reference to that temp            }
          begin
            n.tempinfo := tempinfo;
          end;

        if not Assigned(n.tempinfo) then
          InternalError(2005071901);

        result := n;
      end;


    constructor TTempRefNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        tempidx:=ppufile.GetLongInt;
      end;


    procedure TTempRefNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutLongInt(tempinfo^.owner.ppuidx);
      end;


    procedure TTempRefNode.resolveppuidx;
      var
        temp : TTempCreateNode;
      begin
        temp:=TTempCreateNode(nodeppuidxget(tempidx));
        if temp.nodetype<>tempcreaten then
          InternalError(200311075);
        tempinfo:=temp.tempinfo;
      end;


    function TTempRefNode.pass_1 : TNode;
      begin
        expectloc := LOC_REFERENCE;
        if not tempinfo^.typedef.NeedsInitTable and
           (ti_may_be_in_reg in tempflags) then
          begin
            if tempinfo^.typedef.typ=floatdef then
              begin
                if not Use_VectorFPU(tempinfo^.typedef) then
                  if (tempinfo^.temptype = tt_persistent) then
                    expectloc := LOC_CFPUREGISTER
                  else
                    expectloc := LOC_FPUREGISTER
                else
                  if (tempinfo^.temptype = tt_persistent) then
                    expectloc := LOC_CMMREGISTER
                  else
                    expectloc := LOC_MMREGISTER
              end
            else
              begin
                if (tempinfo^.temptype = tt_persistent) then
                  expectloc := LOC_CREGISTER
                else
                  expectloc := LOC_REGISTER;
              end;
          end;
        result := nil;
      end;


    function TTempRefNode.pass_typecheck: TNode;
      begin
        { check if the temp is already resultdef passed }
        if not Assigned(tempinfo^.typedef) then
          InternalError(200108233);
        result := nil;
        resultdef := tempinfo^.typedef;
        { a temp that stands in for a currency value holds it already scaled
          by 10000, the same as a currency variable does
          (see tloadnode.pass_typecheck) }
        if Is_Currency(resultdef) then
          Include(flags, nf_is_currency);
      end;


    function TTempRefNode.docompare(p: TNode): boolean;
      begin
        result :=
          inherited docompare(p) and
          (TTempRefNode(p).tempinfo = tempinfo);
      end;


    procedure TTempRefNode.mark_write;
      begin
        include(flags,nf_write);
      end;


    procedure TTempRefNode.printnodedata(var t:text);
      var
        f : TTempInfoFlag;
        notfirst : Boolean;
      begin
        inherited printnodedata(t);
        write(t,PrintNodeIndention,'temptypedef = ',tempinfo^.typedef.TypeSymbolPrettyName,' = "',
          tempinfo^.typedef.GetTypeName,'", (tempinfo = $',HexStr(ptrint(tempinfo),sizeof(ptrint)*2),' flags = [');
        notfirst:=false;
        for f in tempinfo^.flags do
          begin
            if notfirst then
              write(t,',');
            write(t,f);
            notfirst:=true;
          end;
        WriteLn(t,'])');
      end;


{*****************************************************************************
                             TEMPDELETENODE
*****************************************************************************}

    constructor TTempDeleteNode.create(const temp: TTempCreateNode);
      begin
        inherited create(tempdeleten);
        tempinfo := temp.tempinfo;
        release_to_normal := false;
      end;


    constructor TTempDeleteNode.create_normal_temp(const temp: TTempCreateNode);
      begin
        inherited create(tempdeleten);
        tempinfo := temp.tempinfo;
        release_to_normal := true;
        if tempinfo^.temptype <> tt_persistent then
          InternalError(200204211);
      end;


    function TTempDeleteNode.dogetcopy: TNode;
      var
        n: TTempDeleteNode;
      begin
        n:=TTempDeleteNode(inherited dogetcopy);
        n.release_to_normal:=release_to_normal;

        if Assigned(tempinfo^.hookoncopy) then
          { if the temp has been copied, assume it becomes a new }
          { temp which has to be hooked by the copied deletenode }
          begin
            { hook the tempdeletenode to the copied temp }
            n.tempinfo:=tempinfo^.hookoncopy;
            { the temp shall not be used, reset hookoncopy    }
            { Only if release_to_normal is false, otherwise   }
            { the temp can still be referenced once more (JM) }
            if (not release_to_normal) then
              tempinfo^.hookoncopy:=nil
            else
              includetempflag(ti_nextref_set_hookoncopy_nil);
          end
        else
          { if the temp we refer to hasn't been copied, we have a }
          { problem since that means we now have two delete nodes }
          { for one temp                                          }
          InternalError(200108234);
        result:=n;
      end;


    constructor TTempDeleteNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        tempidx:=ppufile.GetLongInt;
        release_to_normal:=(ppufile.GetByte<>0);
      end;


    procedure TTempDeleteNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutLongInt(tempinfo^.owner.ppuidx);
        ppufile.PutByte(byte(release_to_normal));
      end;


    procedure TTempDeleteNode.resolveppuidx;
      var
        temp : TTempCreateNode;
      begin
        temp:=TTempCreateNode(nodeppuidxget(tempidx));
        if temp.nodetype<>tempcreaten then
          InternalError(2003110701);
        tempinfo:=temp.tempinfo;
      end;


    function TTempDeleteNode.pass_1 : TNode;
      begin
         expectloc:=LOC_VOID;
         result := nil;
      end;

    function TTempDeleteNode.pass_typecheck: TNode;
      begin
        result := nil;
        resultdef := VoidType;
      end;

    function TTempDeleteNode.docompare(p: TNode): boolean;
      begin
        result :=
          inherited docompare(p) and
          (TTempRefNode(p).tempinfo = tempinfo);
      end;

    destructor TTempDeleteNode.Destroy;
      begin
        tempinfo^.withnode.free; // no nil needed
        tempinfo^.tempinitcode.free; // no nil needed
        dispose(tempinfo);
        inherited Destroy;
      end;

    procedure TTempDeleteNode.printnodedata(var t:text);
      begin
        inherited printnodedata(t);
        WriteLn(t,PrintNodeIndention,'release_to_normal: ',release_to_normal,', temptypedef = ',tempinfo^.typedef.TypeSymbolPrettyName,' = "',
          tempinfo^.typedef.GetTypeName,'", temptype = ',tempinfo^.temptype,', tempinfo = $',HexStr(ptrint(tempinfo),sizeof(ptrint)*2));
      end;


end.
