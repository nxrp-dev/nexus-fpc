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
          constructor Create;virtual;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
       end;
       TNothingNodeClass = class of TNothingNode;

       TErrorNode = class(TNode)
          constructor Create;virtual;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          procedure Mark_Write;override;
       end;
       TErrorNodeClass = class of TErrorNode;

       TSpecializeNode = class(TUnaryNode)
          Sym:TSym;
          GetAddr:Boolean;
          InheritedDef:TDef;
          UnitSpecific:Boolean;
          constructor Create(ALeft:TNode;AGetAddr:Boolean;ASym:TSym;AUnitSpecific:Boolean);virtual;
          constructor Create_Inherited(ALeft:TNode;AGetAddr:Boolean;ASym:TSym;AInheritedDef:TDef);virtual;
          function Pass_1:TNode;override;
          function Pass_TypeCheck:TNode;override;
       end;
       TSpecializeNodeClass = class of TSpecializeNode;

       TFinalizeTempsNode = class(TNode)
          constructor Create;virtual;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
       end;
       TFinalizeTempsNodeClass = class of TFinalizeTempsNode;

       TAsmNodeFlag = (
         asmnf_get_asm_position,
         { Used registers in assembler block }
         asmnf_has_registerlist
       );

       TAsmNodeFlags = set of TAsmNodeFlag;

       TAsmNode = class(TNode)
          AsmNodeFlags : TAsmNodeFlags;
          AssemblyList : TAsmList;
          CurrentTAI : TAI;
          constructor Create(AAsmList : TAsmList);virtual;
          constructor Create_Get_Position;
          destructor Destroy;override;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          function DoGetCopy : TNode;override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          function DoCompare(ANode: TNode): Boolean; override;
       end;
       TAsmNodeClass = class of TAsmNode;

       TStatementNode = class(TBinaryNode)
          constructor Create(ALeft,ARight : TNode);virtual;
          function Simplify(AForInline : Boolean) : TNode; override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          procedure PrintNodeTree(var AText:Text);override;
          property Statement : TNode read Left write Left;
          property Next : TNode read Right write Right;
       end;
       TStatementNodeClass = class of TStatementNode;

       TBlockNodeFlag = (
         bnf_strippable { Block node can be removed via simplify etc. }
       );

       TBlockNodeFlags = set of TBlockNodeFlag;

       TBlockNode = class(TUnaryNode)
          BlockNodeFlags : TBlockNodeFlags;
          constructor Create(ALeft : TNode);virtual;
          destructor Destroy; override;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          function DoGetCopy : TNode;override;
          function Simplify(AForInline : Boolean) : TNode; override;
          function Pass_1 : TNode;override;
          function Pass_TypeCheck:TNode;override;
          property Statements : TNode read Left write Left;
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
       cTempInfoStoreFlags = [ti_may_be_in_reg,ti_addr_taken,ti_reference,ti_readonly,ti_no_final_regsync,ti_nofini,ti_const];

     type
       { to allow access to the location by temp references even after the temp has }
       { already been disposed and to make sure the coherency between temps and     }
       { temp references is kept after a getcopy                                    }
       PTempInfo = ^TTempInfo;
       TTempInfo = record
        private
         Flags                      : TTempInfoFlags;
        public
         { set to the copy of a tempcreate pnode (if it gets copied) so that the }
         { refs and deletenode can hook to this copy once they get copied too    }
         HookOnCopy                 : PTempInfo;
         TypeDef                    : TDef;
         TypeDefDeref               : TDeref;
         TempType                   : TTempType;
         Owner                      : TTempCreateNode;
         WithNode                   : TNode;
         Location                   : TLocation;
         TempInitCode               : TNode;
       end;

       TTempInfoAccessor = class
         class procedure SetTempInfoFlags(ATempInfo: PTempInfo; const AFlags: TTempInfoFlags); virtual;
         class function GetTempInfoFlags(ATempInfo: PTempInfo): TTempInfoFlags; static; inline;
       end;
       TTempInfoAccessorClass = class of TTempInfoAccessor;

       TTempBaseNode = class(TNode)
        protected
          class var TempInfoAccessor: TTempInfoAccessorClass;
        protected
          procedure SetTempInfoFlags(const ATempFlags: TTempInfoFlags); inline;
          function GetTempInfoFlags: TTempInfoFlags; inline;
        public
          TempInfo: PTempInfo;
          procedure IncludeTempFlag(AFlag: TTempInfoFlag); inline;
          procedure ExcludeTempFlag(AFlag: TTempInfoFlag); inline;
          property TempFlags: TTempInfoFlags read GetTempInfoFlags write SetTempInfoFlags;
       end;

       { a node which will create a (non)persistent temp of a given type with a given  }
       { size (the size is separate to allow creating "void" temps with a custom size) }
       TTempCreateNode = class(TTempBaseNode)
          Size: TCGInt;
          FTempLValue : TNode;
          { * persistent temps are used in manually written code where the temp }
          { be usable among different statements and where you can manually say }
          { when the temp has to be freed (using a ttempdeletenode)             }
          { * non-persistent temps are mostly used in typeconversion helpers,   }
          { where the node that receives the temp becomes responsible for       }
          { freeing it. In this last case, you must use only one reference      }
          { to it and *not* generate a ttempdeletenode                          }
          constructor Create(ATypeDef: TDef; ASize: TCGInt; ATempType: TTempType;AAllowReg:Boolean); virtual;
          constructor Create_WithNode(ATypeDef: TDef; ASize: TCGInt; ATempType: TTempType; AAllowReg:Boolean; AWithNode: TNode); virtual;
          constructor Create_Value(ATypeDef:TDef; ASize: TCGInt; ATempType: TTempType;AAllowReg:Boolean; ATempLValue: TNode);
          constructor Create_Reference(ATypeDef:TDef; ASize: TCGInt; ATempType: TTempType;AAllowReg:Boolean; ATempLValue: TNode; AReadOnly: Boolean);
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure DerefImpl;override;
          function DoGetCopy: TNode; override;
          function Pass_1 : TNode; override;
          function Pass_TypeCheck: TNode; override;
          function DoCompare(ANode: TNode): Boolean; override;
          procedure PrintNodeData(var AText:Text);override;
        end;
       TTempCreateNodeClass = class of TTempCreateNode;

        { a node which is a reference to a certain temp }
        TTempRefNode = class(TTempBaseNode)
          constructor Create(const ATemp: TTempCreateNode); virtual;
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure ResolvePPUIdx;override;
          function DoGetCopy: TNode; override;
          function Pass_1 : TNode; override;
          function Pass_TypeCheck : TNode; override;
          procedure Mark_Write;override;
          function DoCompare(ANode: TNode): Boolean; override;
          procedure PrintNodeData(var AText:Text);override;
         private
          FTempIdx : LongInt;
        end;
       TTempRefNodeClass = class of TTempRefNode;

        { a node which removes a temp }
        TTempDeleteNode = class(TTempBaseNode)
          constructor Create(const ATemp: TTempCreateNode); virtual;
          { this will convert the persistent temp to a normal temp
            for returning to the other nodes }
          constructor Create_Normal_Temp(const ATemp: TTempCreateNode);
          constructor PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);override;
          procedure PPUWrite(APPUFile:TCompilerPPUFile);override;
          procedure ResolvePPUIdx;override;
          function DoGetCopy: TNode; override;
          function Pass_1: TNode; override;
          function Pass_TypeCheck: TNode; override;
          function DoCompare(ANode: TNode): Boolean; override;
          destructor Destroy; override;
          procedure PrintNodeData(var AText:Text);override;
         protected
          FReleaseToNormal : Boolean;
        private
          FTempIdx : LongInt;
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
       function  InternalStatements(out ALastStatement:TStatementNode):TBlockNode;
       function  LastStatement(ABlock:TBlockNode):TStatementNode;
       procedure AddStatement(var ALastStatement:TStatementNode;ANode:TNode);

       { true if p is a statement expression with anonymous functions as values,
         which still needs to be converted to a procvar or function reference }
       function Is_Deferred_Stmt_Expr(ANode : TNode) : Boolean;

       { if the complexity of n is "high", creates a reference temp to n's
         location and replace n with a ttemprefnode referring to that location }
       function MaybeReplaceWithTempRef(var ANode: TNode; var ABlock: TBlockNode; var AStatement: TStatementNode; ASize: ASizeInt; AReadOnly: Boolean): TTempCreateNode;
       { same as above, but create a regular temp rather than reference temp }
       function MaybeReplaceWithTemp(var ANode: TNode; var ABlock: TBlockNode; var AStatement: TStatementNode; ASize: ASizeInt; AAllowReg: Boolean): TTempCreateNode;

implementation

    uses
      Verbose,Globals,Systems,
      PPU,
      SymSym,symconst,symdef,defutil,defcmp,
      Pass_1,
      nutils,nld,ncnv,
      ProcInfo
      ;


{*****************************************************************************
                                     Helpers
*****************************************************************************}

    function Is_Deferred_Stmt_Expr(ANode : TNode) : Boolean;
      var
        lStatement : TStatementNode;
      begin
        Result:=false;
        if (ANode.NodeType<>blockn) or
            not Assigned(ANode.ResultDef) or
            (ANode.ResultDef.typ<>procdef) or
            not (po_anonymous in TProcDef(ANode.ResultDef).ProcOptions) then
          exit;

        { skip the nothing node created by internalstatements }
        lStatement:=TStatementNode(TBlockNode(ANode).Left);
        while Assigned(lStatement) and
            Assigned(lStatement.Left) and
            (lStatement.Left.NodeType=nothingn) do
          lStatement:=TStatementNode(lStatement.Right);

        Result:=Assigned(lStatement) and
                Assigned(lStatement.Left) and
                (lStatement.Left.NodeType=tempcreaten);
      end;


    function InternalStatements(out ALastStatement:TStatementNode):TBlockNode;
      begin
        { create dummy initial statement }
        ALastStatement := CStatementNode.Create(CNothingNode.Create,nil);
        Result := CBlockNode.Create(ALastStatement);
        Include(Result.BlockNodeFlags, bnf_strippable);
      end;


    function LastStatement(ABlock:TBlockNode):TStatementNode;
      begin
        Result:=TStatementNode(ABlock.Left);
        while Assigned(Result) and Assigned(Result.Right) do
          Result:=TStatementNode(Result.Right);
      end;


    procedure AddStatement(var ALastStatement:TStatementNode;ANode:TNode);
      begin
        if Assigned(ALastStatement.Right) then
          InternalError(200204201);
        ALastStatement.Right:=CStatementNode.Create(ANode,nil);
        ALastStatement:=TStatementNode(ALastStatement.Right);
      end;


    function MaybeReplaceWithTempRef(var ANode: TNode; var ABlock: TBlockNode; var AStatement: TStatementNode; ASize: ASizeInt; AReadOnly: Boolean): TTempCreateNode;
      begin
        Result:=nil;
        if (Node_Complexity(ANode)>4) or
           Might_Have_SideEffects(ANode) then
          begin
            Result:=CTempCreateNode.Create_Reference(ANode.ResultDef,ASize,tt_persistent,true,ANode,AReadOnly);
            TypeCheckPass(TNode(Result));
            ANode:=CTempRefNode.Create(Result);
            TypeCheckPass(ANode);
            if not Assigned(AStatement) then
              ABlock:=InternalStatements(AStatement);
            AddStatement(AStatement,Result)
          end;
      end;

    function MaybeReplaceWithTemp(var ANode: TNode; var ABlock: TBlockNode; var AStatement: TStatementNode; ASize: ASizeInt; AAllowReg: Boolean): TTempCreateNode;
      begin
        Result:=nil;
        if (Node_Complexity(ANode)>4) or
           Might_Have_SideEffects(ANode) then
          begin
            Result:=CTempCreateNode.Create_Value(ANode.ResultDef,ASize,tt_persistent,AAllowReg,ANode);
            TypeCheckPass(TNode(Result));
            ANode:=CTempRefNode.Create(Result);
            TypeCheckPass(ANode);
            if not Assigned(AStatement) then
              ABlock:=InternalStatements(AStatement);
            AddStatement(AStatement,Result)
          end;
      end;

{*****************************************************************************
                             TFIRSTNOTHING
*****************************************************************************}

    constructor TNothingNode.Create;
      begin
        inherited Create(nothingn);
      end;


    function TNothingNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=VoidType;
      end;


    function TNothingNode.Pass_1 : TNode;
      begin
        Result:=nil;
        ExpectLoc:=LOC_VOID;
      end;


{*****************************************************************************
                             TFIRSTERROR
*****************************************************************************}

    constructor TErrorNode.Create;

      begin
         inherited Create(errorn);
      end;


    function TErrorNode.Pass_TypeCheck:TNode;
      begin
         Result:=nil;
         include(TransientFlags,tnf_error);
         CodeGenError:=true;
         ResultDef:=GenErrorDef;
      end;


    function TErrorNode.Pass_1 : TNode;
      begin
         Result:=nil;
         ExpectLoc:=LOC_VOID;
         CodeGenError:=true;
      end;


    procedure TErrorNode.Mark_Write;
      begin
      end;


{*****************************************************************************
                             TSPECIALIZENODE
*****************************************************************************}

    constructor TSpecializeNode.Create(ALeft:TNode;AGetAddr:Boolean;ASym:TSym;AUnitSpecific:Boolean);
      begin
         inherited Create(specializen,ALeft);
         Sym:=ASym;
         GetAddr:=AGetAddr;
         UnitSpecific:=AUnitSpecific;
      end;

    constructor TSpecializeNode.Create_Inherited(ALeft:TNode;AGetAddr:Boolean;ASym:TSym;AInheritedDef:TDef);
      begin
        Create(ALeft,AGetAddr,ASym,false);
        InheritedDef:=AInheritedDef;
      end;


    function TSpecializeNode.Pass_TypeCheck:TNode;
      begin
         Result:=nil;
         ResultDef:=CUndefinedType;
      end;


    function TSpecializeNode.Pass_1:TNode;
      begin
         { such a node should not reach pass_1 }
         InternalError(2015071704);
         Result:=nil;
         ExpectLoc:=LOC_VOID;
         CodeGenError:=true;
      end;


{*****************************************************************************
                             TFINALIZETEMPSNODE
*****************************************************************************}

    constructor TFinalizeTempsNode.Create;
      begin
        inherited Create(finalizetempsn);
      end;

    function TFinalizeTempsNode.Pass_1: TNode;
      begin
        Result:=nil;
        ExpectLoc:=LOC_VOID;
      end;

    function TFinalizeTempsNode.Pass_TypeCheck: TNode;
      begin
        ResultDef:=VoidType;
        Result:=nil;
      end;

    function TFinalizeTempsNode.DoCompare(ANode: TNode): Boolean;
      begin
        { these nodes should never be coalesced }
        Result:=false;
      end;


{*****************************************************************************
                            TSTATEMENTNODE
*****************************************************************************}

    constructor TStatementNode.Create(ALeft,ARight : TNode);

      begin
         inherited Create(statementn,ALeft,ARight);
      end;


    function TStatementNode.Simplify(AForInline: Boolean) : TNode;
      begin
        Result:=nil;
        { these "optimizations" are only to make it more easy to recognise    }
        { blocknodes which at the end of inlining only contain one single     }
        { statement. Simplifying inside blocknode.simplify could be dangerous }
        { because if the main blocknode which makes up a procedure/function   }
        { body were replaced with a statementn/nothingn, this could cause     }
        { problems elsewhere in the compiler which expects a blocknode        }

        { remove next statement if it's a nothing-statement (since if it's }
        { the last, it won't remove itself -- see next simplification)     }
        while Assigned(Right) and
              (TStatementNode(Right).Left.NodeType = nothingn) do
          begin
            Result:=TStatementNode(Right).Right;
            TStatementNode(Right).Right:=nil;
            Right.free;
            Right:=Result;
            Result:=nil;
          end;

        { Remove initial nothingn if there are other statements. If there }
        { are no other statements, returning nil doesn't help (will be    }
        { interpreted as "can't be simplified") and replacing the         }
        { statementnode with a nothingnode cannot be done (because it's   }
        { possible this statementnode is a child of a blocknode, and      }
        { blocknodes are expected to only contain statementnodes)         }
        if (Left.NodeType = nothingn) and
           Assigned(Right) then
          begin
            Result:=Right;
            Right:=nil;
            exit;
          end;

        { if the current statement contains a block with one statement,
          replace the current statement with that block's statement
          (but only if the block does not have nf_block_with_exit set
           or has no exit statement, because otherwise it needs an own
           exit label, see tests/test/tinline10)

           Further, it might not be the user code entry
        }
        if (Left.NodeType = blockn) and
           ((Left.Flags*[nf_block_with_exit,nf_usercode_entry]=[]) or
            ((Left.Flags*[nf_block_with_exit,nf_usercode_entry]=[nf_block_with_exit]) and not Has_Node_Of_Type(Left, [exitn]))) and
           Assigned(TBlockNode(Left).Left) and
           not Assigned(TStatementNode(TBlockNode(Left).Left).Right) then
          begin
            Result:=TBlockNode(Left).Left;
            TStatementNode(Result).Right:=Right;
            Right:=nil;
            TBlockNode(Left).Left:=nil;
            exit;
          end;
      end;


    function TStatementNode.Pass_TypeCheck:TNode;
      begin
         Result:=nil;
         ResultDef:=VoidType;

         { left is the statement itself calln assignn or a complex one }
         TypeCheckPass(Left);
         if CodeGenError then
           exit;

         { right is the next statement in the list }
         if Assigned(Right) then
           TypeCheckPass(Right);
         if CodeGenError then
           exit;
      end;


    function TStatementNode.Pass_1 : TNode;
      begin
         Result:=nil;
         { left is the statement itself calln assignn or a complex one }
         FirstPass(Left);
         if CodeGenError then
           exit;
         ExpectLoc:=Left.ExpectLoc;
         { right is the next in the list }
         if Assigned(Right) then
           FirstPass(Right);
         if CodeGenError then
           exit;
      end;


    procedure TStatementNode.PrintNodeTree(var AText:Text);
      begin
        PrintNodeList(AText);
      end;

{*****************************************************************************
                             TBLOCKNODE
*****************************************************************************}

    constructor TBlockNode.Create(ALeft : TNode);

      begin
         inherited Create(blockn,ALeft);
         BlockNodeFlags:=[];
      end;

    destructor TBlockNode.Destroy;

      var
        lStatement, lNextStatement: TStatementNode;
      begin
        lStatement := TStatementNode(Left);
        Left := nil;
        while Assigned(lStatement) do
          begin
            lNextStatement := TStatementNode(lStatement.Right);
            lStatement.Right := nil;
            lStatement.free;
            lStatement := lNextStatement;
          end;
        inherited Destroy;
      end;


    constructor TBlockNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetSet(TPPUSet1(BlockNodeFlags));
      end;


    procedure TBlockNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutSet(TPPUSet1(BlockNodeFlags));
      end;


    function TBlockNode.DoGetCopy : TNode;
      begin
        Result:=inherited DoGetCopy;
        TBlockNode(Result).BlockNodeFlags:=BlockNodeFlags;
      end;


    function NodesEqual(var ANode: TNode; AArg: Pointer): TForEachNodeResult;
      begin
        if ANode.IsEqual(TNode(AArg)) then
          Result:=fen_norecurse_true
        else
          Result:=fen_false;
      end;


    function TBlockNode.Simplify(AForInline : Boolean): TNode;
      const
        cNodeStripTerminators = [labeln, asmn, tempcreaten, tempdeleten];

      var
        lStatement, lNextStatement, lFirstStatement, lLastStatement: TStatementNode;
{$ifdef break_inlining}
        lStatements : array[0..3] of TStatementNode;
{$endif break_inlining}
      begin
        Result := nil;
        { Warning: never replace a blocknode with another node type,
          since the block may be the main block of a procedure/function/
          main program body, and those nodes should always be blocknodes
          since that's what the compiler expects elsewhere. }

        if Assigned(Left) then
          begin
            if not Assigned(TStatementNode(Left).Right) then
              begin
                { Block has a lone statement }
                case TStatementNode(Left).Left.NodeType of
                  blockn:
                    begin
                      { if the current block contains only one statement, and
                        this one statement only contains another block, replace
                        this block with that other block.                       }
                      Result:=TStatementNode(Left).Left;
                      TStatementNode(Left).Left:=nil;
                      { make sure the nf_block_with_exit flag is safeguarded }
                      Result.Flags:=Result.Flags+(Flags*[nf_block_with_exit,nf_usercode_entry]);
                      exit;
                    end;
                  nothingn:
                    begin
                      { if the block contains only a statement with a nothing node,
                        get rid of the statement }
                      Left.Free;
                      Left:=nil;
                      exit;
                    end;
                  else
                    ;
                end;
              end
            else if AForInline or (cs_opt_level2 in CurrentSettings.OptimizerSwitches) then
              begin
                lStatement := TStatementNode(Left);
                while Assigned(lStatement) do
                  begin
                    case lStatement.Left.NodeType of
                      raisen, exitn, breakn, continuen, goton:
                        { Remove all subsequent statements, stopping only at a
                          label or asm block since code can theoretically jump
                          to them.  Also, don't delete temp creates and deletes }
                        begin
                          lLastStatement := lStatement;
                          lNextStatement := TStatementNode(lStatement.Next);
                          while Assigned(lNextStatement) do
                            begin
                              if Has_Node_Of_Type(TStatementNode(lNextStatement).Left, cNodeStripTerminators) then
                                Break;

                              lLastStatement := lNextStatement;
                              lNextStatement := TStatementNode(lNextStatement.Next);
                            end;

                          if (lLastStatement <> lStatement) then
                            begin
                              lLastStatement.Next := nil; { Make sure we stop one before p }
                              lStatement.Next.Free;
                              lStatement.Next := lNextStatement;
                              lStatement := lNextStatement;
                              Continue;
                            end;
                        end;
                      else
                        ;
                    end;

                    { Look one statement ahead in case it can be deleted - we
                      need the previous statement to stitch the tree correctly
                    }
                    lNextStatement := TStatementNode(lStatement.Next);
                    if not Assigned(lNextStatement) then
                      Break;

                    if Assigned(lNextStatement.Left) then
                      begin
                        case lNextStatement.Left.NodeType of
                          blockn:
                            if (bnf_strippable in TBlockNode(lNextStatement.Left).BlockNodeFlags) and
                              ((lNextStatement.Left.Flags * [nf_block_with_exit] = []) or not Has_Node_Of_Type(lNextStatement.Left, [exitn])) then
                              begin
                                { Attempt to merge this block into the main statement
                                  set }

                                { Find last statement }
                                lFirstStatement := TStatementNode(TBlockNode(lNextStatement.Left).PruneKeepLeft());
                                if Assigned(lFirstStatement) then
                                  begin
                                    lLastStatement := lFirstStatement;
                                    while Assigned(lLastStatement.Right) do
                                      lLastStatement := TStatementNode(lLastStatement.Right);

                                    lStatement.Right := lFirstStatement;
                                  end
                                else
                                  lLastStatement := lStatement;

                                lLastStatement.Right := lNextStatement.PruneKeepRight();

                                { make sure the nf_usercode_entry flag is safeguarded }
                                Flags := Flags + (lNextStatement.Left.Flags * [nf_usercode_entry]);

                                lNextStatement.Free;
                                lNextStatement := nil;
                                Continue;
                              end;
                          else
                            ;
                        end;
                      end;
                    lStatement := TStatementNode(lStatement.Next);
                  end;
              end;
          end;
{$ifdef break_inlining}
        { simple sequence of tempcreate, assign and return temp.? }
        if GetStatements(Left,lStatements) and
          (lStatements[0].Left.NodeType=tempcreaten) and
          (lStatements[1].Left.NodeType=assignn) and
          (ActualTargetNode(@TAssignmentNode(lStatements[1].Left).Left)^.NodeType=temprefn) and
          (lStatements[2].Left.NodeType=tempdeleten) and
          (lStatements[3].Left.NodeType=temprefn) and
          (TTempCreateNode(lStatements[0].Left).TempInfo=TTempRefNode(ActualTargetNode(@TAssignmentNode(lStatements[1].Left).Left)^).TempInfo) and
          (TTempCreateNode(lStatements[0].Left).TempInfo=TTempDeleteNode(lStatements[2].Left).TempInfo) and
          (TTempCreateNode(lStatements[0].Left).TempInfo=TTempRefNode(lStatements[3].Left).TempInfo) and
          { the temp. node might not be references inside the assigned expression }
          not(ForEachNodeStatic(TAssignmentNode(lStatements[1].Left).Right,@NodesEqual,ActualTargetNode(@TAssignmentNode(lStatements[1].Left).Left)^)) then
          begin
            Result:=TAssignmentNode(lStatements[1].Left).Right;
            TAssignmentNode(lStatements[1].Left).Right:=nil;
            { ensure the node is first passed, so the resultdef does not get changed if the
              the type conv. below is merged }
            FirstPass(Result);
            Result:=CTypeConvNode.Create_Internal(Result,TTempRefNode(lStatements[3].Left).ResultDef);
            FirstPass(Result);
            exit;
          end;
{$endif break_inlining}
      end;


    function TBlockNode.Pass_TypeCheck:TNode;
      var
         lStatement : TStatementNode;
      begin
         Result:=nil;
         ResultDef:=VoidType;

         lStatement:=TStatementNode(Left);
         while Assigned(lStatement) do
           begin
              if Assigned(lStatement.Left) then
                begin
                   CodeGenError:=false;
                   TypeCheckPass(lStatement.Left);
                   { the resultdef of the block is the last type that is
                     returned. Normally this is a voidtype. But when the
                     compiler inserts a block of multiple statements then the
                     last entry can return a value }
                   ResultDef:=lStatement.Left.ResultDef;
                end;
              lStatement:=TStatementNode(lStatement.Right);
           end;
      end;


    function TBlockNode.Pass_1 : TNode;
      var
         lPreviousStatement,lStatement,lCurrentStatement : TStatementNode;
         lFirstNode: Boolean;
         //count : longint;
      begin
         Result:=nil;
         ExpectLoc:=LOC_VOID;
         if Is_Deferred_Stmt_Expr(self) then
           begin
             { statement expression with anonymous functions, which was
               not converted to a procvar or function reference }
             CGMessage(parser_e_stmt_expr_anon_needs_type);
             exit;
           end;
         //count:=0;
         lStatement:=TStatementNode(Left);
         lPreviousStatement:=nil;
         lCurrentStatement:=nil;
         lFirstNode := True;
         while Assigned(lStatement) do
           begin
              if Assigned(lStatement.Left) then
                begin
                   { Calling firstpass on a statement node normally causes
                     problems, so we have to be a little bit hacky if we want
                     to remove nothing nodes }
                   CodeGenError:=false;
                   lCurrentStatement:=TStatementNode(lStatement);
                   FirstPass(TNode(lStatement));
                   { If the first node gets deleted, left must be updated,
                     otherwise it will be a dangling pointer }
                   if lFirstNode then
                     begin
                       { If multiple statements are to be removed, they would
                         have all been removed by the firstpass call above, so
                         the next one will not be removed, hence it's safe to
                         set FirstNode to false }
                       lFirstNode := False;
                       Left := lStatement;
                     end
                   else if (lCurrentStatement<>lStatement) then
                     begin
                       { If FirstPass modified HP,
                         we must update php.right }
                       if Assigned(lPreviousStatement) then
                         lPreviousStatement.Right:=lStatement;
                     end;
                   if Assigned(lStatement.Left) then
                     lStatement.ExpectLoc:=lStatement.Left.ExpectLoc;
                end;
              ExpectLoc:=lStatement.ExpectLoc;
              //inc(count);
              lPreviousStatement:=lStatement;
              lStatement:=TStatementNode(lStatement.Right);
           end;
      end;


{*****************************************************************************
                             TASMNODE
*****************************************************************************}

    constructor TAsmNode.Create(AAsmList : TAsmList);
      begin
        inherited Create(asmn);
        AssemblyList:=AAsmList;
        AsmNodeFlags:=[];
        CurrentTAI:=nil;
      end;


    constructor TAsmNode.Create_Get_Position;
      begin
        inherited Create(asmn);
        AssemblyList:=nil;
        AsmNodeFlags:=[asmnf_get_asm_position];
        CurrentTAI:=nil;
      end;


    destructor TAsmNode.Destroy;
      begin
        if Assigned(AssemblyList) then
          begin
            AssemblyList.free;
            AssemblyList := nil;
          end;
        inherited Destroy;
      end;


    constructor TAsmNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      var
        lAsmItem : TAI;
      begin
        inherited PPULoad(ANodeType,APPUFile);
        APPUFile.GetSet(TPPUSet1(AsmNodeFlags));
        if not(asmnf_get_asm_position in AsmNodeFlags) then
          begin
            AssemblyList:=TAsmList.Create;
            repeat
              lAsmItem:=ppuloadai(APPUFile);
              if lAsmItem=nil then
                break;
              AssemblyList.concat(lAsmItem);
              if lAsmItem.typ=ait_section then
                inc(AssemblyList.section_count);
            until false;
          end
        else
          AssemblyList:=nil;
        CurrentTAI:=nil;
      end;


    procedure TAsmNode.PPUWrite(APPUFile:TCompilerPPUFile);
      var
        lAsmItem : TAI;
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutSet(TPPUSet1(AsmNodeFlags));
{ TODO: FIXME Add saving of register sets}
        if not(asmnf_get_asm_position in AsmNodeFlags) then
          begin
            lAsmItem:=TAI(AssemblyList.first);
            while Assigned(lAsmItem) do
             begin
               ppuwriteai(APPUFile,lAsmItem);
               lAsmItem:=TAI(lAsmItem.Next);
             end;
            { end is marked by a nil }
            ppuwriteai(APPUFile,nil);
          end;
      end;


    procedure TAsmNode.BuildDerefImpl;
      var
        lAsmItem : TAI;
      begin
        inherited BuildDerefImpl;
        if not(asmnf_get_asm_position in AsmNodeFlags) then
          begin
            lAsmItem:=TAI(AssemblyList.first);
            while Assigned(lAsmItem) do
             begin
               lAsmItem.BuildDerefImpl;
               lAsmItem:=TAI(lAsmItem.Next);
             end;
          end;
      end;


    procedure TAsmNode.DerefImpl;
      var
        lAsmItem : TAI;
      begin
        inherited DerefImpl;
        if not(asmnf_get_asm_position in AsmNodeFlags) then
          begin
            lAsmItem:=TAI(AssemblyList.first);
            while Assigned(lAsmItem) do
             begin
               lAsmItem.DerefImpl;
               lAsmItem:=TAI(lAsmItem.Next);
             end;
          end;
      end;


    function TAsmNode.DoGetCopy: TNode;
      var
        lCopy: TAsmNode;
      begin
        lCopy:=TAsmNode(inherited DoGetCopy);
        lCopy.AsmNodeFlags:=AsmNodeFlags;
        if Assigned(AssemblyList) then
          begin
            lCopy.AssemblyList:=TAsmList.Create;
            lCopy.AssemblyList.ConcatListCopy(AssemblyList);
          end
        else
          lCopy.AssemblyList:=nil;
        lCopy.CurrentTAI:=CurrentTAI;
        Result:=lCopy;
      end;


    function TAsmNode.Pass_TypeCheck:TNode;
      begin
        Result:=nil;
        ResultDef:=VoidType;
        if not(asmnf_get_asm_position in AsmNodeFlags) then
          include(CurrentProcInfo.Flags,pi_has_assembler_block);
      end;


    function TAsmNode.Pass_1 : TNode;
      begin
        Result:=nil;
        ExpectLoc:=LOC_VOID;
      end;


    function TAsmNode.DoCompare(ANode: TNode): Boolean;
      begin
        { comparing of asmlists is not implemented (JM) }
        DoCompare := false;
      end;


{*****************************************************************************
                          TEMPBASENODE
*****************************************************************************}

    class procedure TTempInfoAccessor.SetTempInfoFlags(ATempInfo: PTempInfo; const AFlags: TTempInfoFlags);
      begin
        ATempInfo^.Flags:=AFlags;
      end;


    class function TTempInfoAccessor.GetTempInfoFlags(ATempInfo: PTempInfo): TTempInfoFlags;
      begin
        Result:=ATempInfo^.Flags;
      end;


{*****************************************************************************
                          TEMPBASENODE
*****************************************************************************}

    procedure TTempBaseNode.SetTempInfoFlags(const ATempFlags: TTempInfoFlags);
      begin
        CTempInfoAccessor.SetTempInfoFlags(TempInfo,ATempFlags);
      end;


    function TTempBaseNode.GetTempInfoFlags: TTempInfoFlags;
      begin
        Result:=CTempInfoAccessor.GetTempInfoFlags(TempInfo);
      end;


    procedure TTempBaseNode.IncludeTempFlag(AFlag: TTempInfoFlag);
      begin
        { go through settempinfoflags() so it can filter out unsupported tempflags }
        SetTempInfoFlags(GetTempInfoFlags+[AFlag])
      end;


    procedure TTempBaseNode.ExcludeTempFlag(AFlag: TTempInfoFlag);
      begin
        { go through settempinfoflags() so it can prevent required tempflags from
          being removed (if any) }
        SetTempInfoFlags(GetTempInfoFlags-[AFlag])
      end;


{*****************************************************************************
                          TEMPCREATENODE
*****************************************************************************}

    constructor TTempCreateNode.Create(ATypeDef:TDef; ASize: TCGInt; ATempType: TTempType;AAllowReg:Boolean);
      begin
        inherited Create(tempcreaten);
        Size := ASize;
        new(TempInfo);
        fillchar(TempInfo^,sizeof(TempInfo^),0);
        TempInfo^.TypeDef := ATypeDef;
        TempInfo^.TempType := ATempType;
        TempInfo^.Owner := self;
        TempInfo^.WithNode := nil;
        if AAllowReg and
           { temp must fit a single register }
           (TStoredDef(ATypeDef).Is_FPURegable or
            (TStoredDef(ATypeDef).Is_IntRegable and
             (ASize<=TCgSize2Size[OS_64]))) and
           { size of register operations must be known }
           (Def_CGSize(ATypeDef)<>OS_NO) and
           { no init/final needed }
           not Is_Managed_Type(ATypeDef) then
          IncludeTempFlag(ti_may_be_in_reg);
      end;


    constructor TTempCreateNode.Create_WithNode(ATypeDef: TDef; ASize: TCGInt; ATempType: TTempType; AAllowReg:Boolean; AWithNode: TNode);
      begin
        self.Create(ATypeDef,ASize,ATempType,AAllowReg);
        TempInfo^.WithNode:=AWithNode.GetCopy;
      end;


    constructor TTempCreateNode.Create_Value(ATypeDef:TDef; ASize: TCGInt; ATempType: TTempType;AAllowReg:Boolean; ATempLValue: TNode);
      begin
        self.Create(ATypeDef,ASize,ATempType,AAllowReg);
        // store in ppuwrite
        FTempLValue:=ATempLValue;
        // create from stored ftemplvalue in ppuload
        TempInfo^.TempInitCode:=CAssignmentNode.Create(CTempRefNode.Create(self),FTempLValue);
      end;


     constructor TTempCreateNode.Create_Reference(ATypeDef: TDef; ASize: TCGInt; ATempType: TTempType; AAllowReg: Boolean; ATempLValue: TNode; AReadOnly: Boolean);
      begin
        // store in ppuwrite
        self.Create(ATypeDef,ASize,ATempType,AAllowReg);
        FTempLValue:=ATempLValue;
        // no assignment node, just the tempvalue
        TempInfo^.TempInitCode:=FTempLValue;
        IncludeTempFlag(ti_reference);
        if AReadOnly then
          IncludeTempFlag(ti_readonly);
      end;


    function TTempCreateNode.DoGetCopy: TNode;
      var
        lCopy: TTempCreateNode;
      begin
        lCopy := TTempCreateNode(inherited DoGetCopy);
        lCopy.Size := Size;

        new(lCopy.TempInfo);
        fillchar(lCopy.TempInfo^,sizeof(lCopy.TempInfo^),0);
        lCopy.TempInfo^.Owner:=lCopy;
        lCopy.TempInfo^.TypeDef := TempInfo^.TypeDef;
        lCopy.TempInfo^.TempType := TempInfo^.TempType;
        lCopy.TempFlags := TempFlags * cTempInfoStoreFlags;

        { when the tempinfo has already a hookoncopy then it is not
          reset by a tempdeletenode }
        if Assigned(TempInfo^.HookOnCopy) then
          InternalError(200211262);
        { signal the temprefs that the temp they point to has been copied, }
        { so that if the refs get copied as well, they can hook themselves }
        { to the copy of the temp                                          }
        TempInfo^.HookOnCopy := lCopy.TempInfo;
        ExcludeTempFlag(ti_nextref_set_hookoncopy_nil);

        if Assigned(TempInfo^.WithNode) then
          lCopy.TempInfo^.WithNode := TempInfo^.WithNode.GetCopy
        else
          lCopy.TempInfo^.WithNode := nil;

        if Assigned(TempInfo^.TempInitCode) then
          lCopy.TempInfo^.TempInitCode := TempInfo^.TempInitCode.GetCopy
        else
          lCopy.TempInfo^.TempInitCode := nil;

        Result := lCopy;
      end;


    constructor TTempCreateNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);

        Size:=APPUFile.GetLongInt;
        new(TempInfo);
        fillchar(TempInfo^,sizeof(TempInfo^),0);
        APPUFile.GetSet(TPPUSet2(TempInfo^.Flags));
        APPUFile.GetDeref(TempInfo^.TypeDefDeref);
        TempInfo^.TempType := TTempType(APPUFile.GetByte);
        TempInfo^.Owner:=self;
        TempInfo^.WithNode:=PPULoadNode(APPUFile);
        FTempLValue:=PPULoadNode(APPUFile);
      end;


    procedure TTempCreateNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutLongInt(Size);
        APPUFile.PutSet(TPPUSet2(TempInfo^.Flags));
        APPUFile.PutDeref(TempInfo^.TypeDefDeref);
        APPUFile.PutByte(Byte(TempInfo^.TempType));
        PPUWriteNode(APPUFile,TempInfo^.WithNode);
        PPUWriteNode(APPUFile,FTempLValue);
      end;


    procedure TTempCreateNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        TempInfo^.TypeDefDeref.Build(TempInfo^.TypeDef);
        if Assigned(TempInfo^.WithNode) then
          TempInfo^.WithNode.BuildDerefImpl;
        if Assigned(FTempLValue) then
          FTempLValue.BuildDerefImpl;
      end;


    procedure TTempCreateNode.DerefImpl;
      begin
        inherited DerefImpl;
        TempInfo^.TypeDef:=TDef(TempInfo^.TypeDefDeref.resolve);
        if Assigned(TempInfo^.WithNode) then
          TempInfo^.WithNode.DerefImpl;
        if Assigned(FTempLValue) then
          begin
            FTempLValue.DerefImpl;
            TempInfo^.TempInitCode:=CAssignmentNode.Create(CTempRefNode.Create(self),FTempLValue);
          end;
      end;


    function TTempCreateNode.Pass_1 : TNode;
      begin
        Result := nil;
        ExpectLoc:=LOC_VOID;
        { temps which are immutable do not need to be initialized/finalized }
        if (TempInfo^.TypeDef.NeedsInitTable) and not(ti_const in TempFlags) then
          include(CurrentProcInfo.Flags,pi_needs_implicit_finally);
        if Assigned(TempInfo^.WithNode) then
          FirstPass(TempInfo^.WithNode);
        if Assigned(TempInfo^.TempInitCode) then
          FirstPass(TempInfo^.TempInitCode);
        inc(CurrentProcInfo.EstimatedTempSize,Size);
        { if a temp. create node is loaded from a ppu, it could be that the unit was compiled with other settings which
          enabled a certain type to be stored in a register while the current settings do not support this, so correct this here
          if needed
        }
        if not(TStoredDef(TempInfo^.TypeDef).Is_FPURegable) and not(TStoredDef(TempInfo^.TypeDef).Is_IntRegable) and (ti_may_be_in_reg in TempFlags) then
          ExcludeTempFlag(ti_may_be_in_reg);
      end;


    function TTempCreateNode.Pass_TypeCheck: TNode;
      begin
        Result := nil;
        { a tempcreatenode doesn't have a resultdef, only temprefnodes do }
        ResultDef := VoidType;
        if Assigned(TempInfo^.WithNode) then
          TypeCheckPass(TempInfo^.WithNode);
        if Assigned(TempInfo^.TempInitCode) then
          TypeCheckPass(TempInfo^.TempInitCode);
      end;


    function TTempCreateNode.DoCompare(ANode: TNode): Boolean;
      begin
        Result :=
          inherited DoCompare(ANode) and
          (TTempCreateNode(ANode).Size = Size) and
          (TTempCreateNode(ANode).TempFlags*cTempInfoStoreFlags=TempFlags*cTempInfoStoreFlags) and
          Equal_Defs(TTempCreateNode(ANode).TempInfo^.TypeDef,TempInfo^.TypeDef) and
          (TTempCreateNode(ANode).TempInfo^.WithNode.IsEqual(TempInfo^.WithNode)) and
          (TTempCreateNode(ANode).TempInfo^.TempInitCode.IsEqual(TempInfo^.TempInitCode));
      end;


    procedure TTempCreateNode.PrintNodeData(var AText:Text);
      var
        lFlag: TTempInfoFlag;
        lFirst: Boolean;
      begin
        inherited PrintNodeData(AText);
        WriteLn(AText,PrintNodeIndention,'size = ',Size,', temptypedef = ',TempInfo^.TypeDef.TypeSymbolPrettyName,' = "',
          TempInfo^.TypeDef.GetTypeName,'", tempinfo = $',HexStr(ptrint(TempInfo),sizeof(ptrint)*2));
        write(AText,PrintNodeIndention,'[');
        lFirst:=true;
        for lFlag in TempFlags do
          begin
            if not(lFirst) then
              write(AText,',');
            write(AText,lFlag);
            lFirst:=false;
          end;
        WriteLn(AText,']');
        WriteLn(AText,PrintNodeIndention,'tempinit =');
        PrintNode(AText,TempInfo^.TempInitCode);
      end;


{*****************************************************************************
                             TEMPREFNODE
*****************************************************************************}

    constructor TTempRefNode.Create(const ATemp: TTempCreateNode);
      begin
        inherited Create(temprefn);
        TempInfo := ATemp.TempInfo;
      end;


    function TTempRefNode.DoGetCopy: TNode;
      var
        lCopy: TTempRefNode;
      begin
        lCopy := TTempRefNode(inherited DoGetCopy);

        if Assigned(TempInfo^.HookOnCopy) then
          { if the temp has been copied, assume it becomes a new }
          { temp which has to be hooked by the copied reference  }
          begin
            { hook the ref to the copied temp }
            lCopy.TempInfo := TempInfo^.HookOnCopy;
            { if we passed a ttempdeletenode that changed the temp }
            { from a persistent one into a normal one, we must be  }
            { the last reference (since our parent should free the }
            { temp (JM)                                            }
            if (ti_nextref_set_hookoncopy_nil in TempFlags) then
              TempInfo^.HookOnCopy := nil;
          end
        else
          { if the temp we refer to hasn't been copied, assume }
          { we're just a new reference to that temp            }
          begin
            lCopy.TempInfo := TempInfo;
          end;

        if not Assigned(lCopy.TempInfo) then
          InternalError(2005071901);

        Result := lCopy;
      end;


    constructor TTempRefNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        FTempIdx:=APPUFile.GetLongInt;
      end;


    procedure TTempRefNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutLongInt(TempInfo^.Owner.PPUIdx);
      end;


    procedure TTempRefNode.ResolvePPUIdx;
      var
        lTemp : TTempCreateNode;
      begin
        lTemp:=TTempCreateNode(NodePPUIdxGet(FTempIdx));
        if lTemp.NodeType<>tempcreaten then
          InternalError(200311075);
        TempInfo:=lTemp.TempInfo;
      end;


    function TTempRefNode.Pass_1 : TNode;
      begin
        ExpectLoc := LOC_REFERENCE;
        if not TempInfo^.TypeDef.NeedsInitTable and
           (ti_may_be_in_reg in TempFlags) then
          begin
            if TempInfo^.TypeDef.typ=floatdef then
              begin
                if not Use_VectorFPU(TempInfo^.TypeDef) then
                  if (TempInfo^.TempType = tt_persistent) then
                    ExpectLoc := LOC_CFPUREGISTER
                  else
                    ExpectLoc := LOC_FPUREGISTER
                else
                  if (TempInfo^.TempType = tt_persistent) then
                    ExpectLoc := LOC_CMMREGISTER
                  else
                    ExpectLoc := LOC_MMREGISTER
              end
            else
              begin
                if (TempInfo^.TempType = tt_persistent) then
                  ExpectLoc := LOC_CREGISTER
                else
                  ExpectLoc := LOC_REGISTER;
              end;
          end;
        Result := nil;
      end;


    function TTempRefNode.Pass_TypeCheck: TNode;
      begin
        { check if the temp is already resultdef passed }
        if not Assigned(TempInfo^.TypeDef) then
          InternalError(200108233);
        Result := nil;
        ResultDef := TempInfo^.TypeDef;
        { a temp that stands in for a currency value holds it already scaled
          by 10000, the same as a currency variable does
          (see tloadnode.pass_typecheck) }
        if Is_Currency(ResultDef) then
          Include(Flags, nf_is_currency);
      end;


    function TTempRefNode.DoCompare(ANode: TNode): Boolean;
      begin
        Result :=
          inherited DoCompare(ANode) and
          (TTempRefNode(ANode).TempInfo = TempInfo);
      end;


    procedure TTempRefNode.Mark_Write;
      begin
        include(Flags,nf_write);
      end;


    procedure TTempRefNode.PrintNodeData(var AText:Text);
      var
        lFlag : TTempInfoFlag;
        lNotFirst : Boolean;
      begin
        inherited PrintNodeData(AText);
        write(AText,PrintNodeIndention,'temptypedef = ',TempInfo^.TypeDef.TypeSymbolPrettyName,' = "',
          TempInfo^.TypeDef.GetTypeName,'", (tempinfo = $',HexStr(ptrint(TempInfo),sizeof(ptrint)*2),' flags = [');
        lNotFirst:=false;
        for lFlag in TempInfo^.Flags do
          begin
            if lNotFirst then
              write(AText,',');
            write(AText,lFlag);
            lNotFirst:=true;
          end;
        WriteLn(AText,'])');
      end;


{*****************************************************************************
                             TEMPDELETENODE
*****************************************************************************}

    constructor TTempDeleteNode.Create(const ATemp: TTempCreateNode);
      begin
        inherited Create(tempdeleten);
        TempInfo := ATemp.TempInfo;
        FReleaseToNormal := false;
      end;


    constructor TTempDeleteNode.Create_Normal_Temp(const ATemp: TTempCreateNode);
      begin
        inherited Create(tempdeleten);
        TempInfo := ATemp.TempInfo;
        FReleaseToNormal := true;
        if TempInfo^.TempType <> tt_persistent then
          InternalError(200204211);
      end;


    function TTempDeleteNode.DoGetCopy: TNode;
      var
        lCopy: TTempDeleteNode;
      begin
        lCopy:=TTempDeleteNode(inherited DoGetCopy);
        lCopy.FReleaseToNormal:=FReleaseToNormal;

        if Assigned(TempInfo^.HookOnCopy) then
          { if the temp has been copied, assume it becomes a new }
          { temp which has to be hooked by the copied deletenode }
          begin
            { hook the tempdeletenode to the copied temp }
            lCopy.TempInfo:=TempInfo^.HookOnCopy;
            { the temp shall not be used, reset hookoncopy    }
            { Only if release_to_normal is false, otherwise   }
            { the temp can still be referenced once more (JM) }
            if (not FReleaseToNormal) then
              TempInfo^.HookOnCopy:=nil
            else
              IncludeTempFlag(ti_nextref_set_hookoncopy_nil);
          end
        else
          { if the temp we refer to hasn't been copied, we have a }
          { problem since that means we now have two delete nodes }
          { for one temp                                          }
          InternalError(200108234);
        Result:=lCopy;
      end;


    constructor TTempDeleteNode.PPULoad(ANodeType:TNodeType;APPUFile:TCompilerPPUFile);
      begin
        inherited PPULoad(ANodeType,APPUFile);
        FTempIdx:=APPUFile.GetLongInt;
        FReleaseToNormal:=(APPUFile.GetByte<>0);
      end;


    procedure TTempDeleteNode.PPUWrite(APPUFile:TCompilerPPUFile);
      begin
        inherited PPUWrite(APPUFile);
        APPUFile.PutLongInt(TempInfo^.Owner.PPUIdx);
        APPUFile.PutByte(Byte(FReleaseToNormal));
      end;


    procedure TTempDeleteNode.ResolvePPUIdx;
      var
        lTemp : TTempCreateNode;
      begin
        lTemp:=TTempCreateNode(NodePPUIdxGet(FTempIdx));
        if lTemp.NodeType<>tempcreaten then
          InternalError(2003110701);
        TempInfo:=lTemp.TempInfo;
      end;


    function TTempDeleteNode.Pass_1 : TNode;
      begin
         ExpectLoc:=LOC_VOID;
         Result := nil;
      end;

    function TTempDeleteNode.Pass_TypeCheck: TNode;
      begin
        Result := nil;
        ResultDef := VoidType;
      end;

    function TTempDeleteNode.DoCompare(ANode: TNode): Boolean;
      begin
        Result :=
          inherited DoCompare(ANode) and
          (TTempRefNode(ANode).TempInfo = TempInfo);
      end;

    destructor TTempDeleteNode.Destroy;
      begin
        TempInfo^.WithNode.free; // no nil needed
        TempInfo^.TempInitCode.free; // no nil needed
        dispose(TempInfo);
        inherited Destroy;
      end;

    procedure TTempDeleteNode.PrintNodeData(var AText:Text);
      begin
        inherited PrintNodeData(AText);
        WriteLn(AText,PrintNodeIndention,'release_to_normal: ',FReleaseToNormal,', temptypedef = ',TempInfo^.TypeDef.TypeSymbolPrettyName,' = "',
          TempInfo^.TypeDef.GetTypeName,'", temptype = ',TempInfo^.TempType,', tempinfo = $',HexStr(ptrint(TempInfo),sizeof(ptrint)*2));
      end;


end.
