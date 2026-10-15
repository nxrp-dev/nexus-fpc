{
    General tree transformations

    Copyright (c) 2013 by Florian Klaempfl

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


{ this unit implements routines to perform all-purpose tree transformations }
unit opttree;

{$i fpcdefs.inc}

  interface

    uses
      node;

    { tries to bring the tree in a normalized form:
       - expressions are free of control statements
       - callinitblock/callcleanupblocks are converted into statements

      rationale is that this simplifies data flow analysis

      returns true, if this was successful
    }
    function normalize(var n : TNode) : Boolean;

  implementation

    uses
      Verbose,
      GlobType,
      cgbase,
      defutil,
      nbas,nld,ncal,
      nutils,
      pass_1;

    function searchstatements(var n : TNode;arg : pointer) : TForEachNodeResult;forward;

    { success pointer shared across recursive searchstatements calls so nested
      blockns can be processed with the proper arg (their own statement chain) }
    var
      normalize_success : PBoolean;

    function hasblock(var n : TNode;arg : pointer) : TForEachNodeResult;
      begin
        result:=fen_false;
        if n.nodetype=blockn then
          result:=fen_norecurse_true;
      end;

    { scan the block's top-level statements for a tempdeletenode referring to
      the given tempinfo, unlink it (replace its statement slot with a
      nothingnode) and return it; nil if not found. Matches the flat
      tempcreate/.../tempdelete pattern emitted around internalstatements
      blocks (nested deletes not expected) }
    function block_extract_tempdelete(block : TBlockNode; ti : PTempInfo) : TTempDeleteNode;
      var
        s : TStatementNode;
      begin
        result:=nil;
        s:=TStatementNode(block.left);
        while Assigned(s) do
          begin
            if Assigned(s.left) and
               (s.left.nodetype=tempdeleten) and
               (TTempDeleteNode(s.left).tempinfo=ti) then
              begin
                result:=TTempDeleteNode(s.left);
                s.left:=CNothingNode.create;
                exit;
              end;
            s:=TStatementNode(s.right);
          end;
      end;

    function searchblock(var n : TNode;arg : pointer) : TForEachNodeResult;
      var
        hp,
        stmnt : TStatementNode;
        res : PNode;
        tempcreatenode : TTempCreateNode;
        tempdelnode : TTempDeleteNode;
        movedblock : TNode;
      begin
        result:=fen_true;
        if n.nodetype in [addn,orn] then
          begin
            { so far we cannot fiddle with short boolean evaluations containing blocks }
            if doshortbooleval(n) and foreachnodestatic(n,@hasblock,nil) then
              begin
                result:=fen_norecurse_false;
                exit;
              end;
          end;
        case n.nodetype of
          calln:
            begin
              if Assigned(TCallNode(n).callinitblock) then
                begin
                  { create a new statement node and insert it }
                  hp:=CStatementNode.create(TCallNode(n).callinitblock,PNode(arg)^);
                  PNode(arg)^:=hp;
                  { tree moved }
                  TCallNode(n).callinitblock:=nil;
                  { process the newly generated block }
                  foreachnodestatic(PNode(arg)^,@searchstatements,nil);
                end;
              if Assigned(TCallNode(n).callcleanupblock) then
                begin
                  { create a new statement node and append it }
                  hp:=CStatementNode.create(TCallNode(n).callcleanupblock,TStatementNode(PNode(arg)^).right);
                  TStatementNode(PNode(arg)^).right:=hp;
                  { tree moved }
                  TCallNode(n).callcleanupblock:=nil;
                  { process the newly generated block }
                  foreachnodestatic(TStatementNode(PNode(arg)^).right,@searchstatements,nil);
                end;
            end;
          blockn:
            begin
              if Assigned(TBlockNode(n).left) and (TBlockNode(n).left.nodetype<>statementn) then
                InternalError(2013120502);

              { blocks used as statements (void result) cannot be extracted -
                replacing the statement slot with a value would produce a
                malformed tree. But their body may contain extractable blockns
                with references to this block's own temps; recurse through the
                statement chain so those inner blockns get normalized at the
                scope where their external temp refs are still valid. }
              if not Assigned(TBlockNode(n).resultdef) or
                 is_void(TBlockNode(n).resultdef) then
                begin
                  if Assigned(TBlockNode(n).left) then
                    foreachnodestatic(TBlockNode(n).left,@searchstatements,normalize_success);
                  { tell the outer foreachnodestatic not to descend again -
                    we've already walked the body with searchstatements }
                  result:=fen_norecurse_true;
                  exit;
                end;

              stmnt:=TStatementNode(TBlockNode(n).left);
              { search for the result of the block node }
              if Assigned(stmnt) then
                begin
                  res:=nil;
                  hp:=TStatementNode(stmnt);
                  while Assigned(hp) do
                    begin
                      if Assigned(hp.left) then
                        res:=@hp.left;
                      hp:=TStatementNode(hp.right);
                    end;
                  { did we find a last node? }
                  if Assigned(res^) then
                    begin
                      case res^.nodetype of
                        ordconstn,
                        realconstn,
                        stringconstn,
                        pointerconstn,
                        setconstn,
                        temprefn:
                          begin
                            { when the block ends with temprefn(t) and also
                              contains tempdelete(t), lift the tempdelete out
                              so the extracted tempref outlives its backing
                              temp (otherwise the delete would run before the
                              use and trip IE 200108231); nil for other cases }
                            if res^.nodetype=temprefn then
                              tempdelnode:=block_extract_tempdelete(TBlockNode(n),TTempRefNode(res^).tempinfo)
                            else
                              tempdelnode:=nil;
                            { create a new statement node and insert it }
                            hp:=CStatementNode.create(n,PNode(arg)^);
                            PNode(arg)^:=hp;
                            { use the result node instead of the block node }
                            n:=res^;
                            { the old statement is not used anymore }
                            res^:=CNothingNode.create;
                            { splice the lifted tempdelete after the original
                              statement so the temp outlives the extracted tempref }
                            if Assigned(tempdelnode) then
                              TStatementNode(hp.right).right:=
                                CStatementNode.create(tempdelnode,TStatementNode(hp.right).right);
                            { process the newly generated statement }
                            foreachnodestatic(PNode(arg)^,@searchstatements,nil);
                          end
                        else if Assigned(res^.resultdef) and not(is_void(res^.resultdef)) then
                          begin
                            { Splice into the parent chain:
                                tempcreate -> block (now assigns to temp) -> origstmt -> tempdelete
                              The blockn's slot in the source expression is
                              replaced by a temprefn for the new temp; the
                              statement slot at pnode(arg)^ stays a statementn. }
                            tempcreatenode:=CTempCreateNode.create(res^.resultdef,res^.resultdef.size,tt_persistent,true);
                            { pass_1 on tempcreate sets pi_needs_implicit_finally
                              for managed typedefs; must fire before
                              add_entry_exit_code reads that flag }
                            DoFirstPass(TNode(tempcreatenode));

                            { rewrite block's last expression: "temp := <expr>" }
                            res^:=CAssignmentNode.create_internal(CTempRefNode.create(tempcreatenode),res^);
                            DoFirstPass(res^);
                            { replace blockn in source expression with a temprefn }
                            movedblock:=n;
                            n:=CTempRefNode.create(tempcreatenode);
                            DoFirstPass(n);

                            { tempdelete after origstmt }
                            hp:=CStatementNode.create(
                                  CTempDeleteNode.create_normal_temp(tempcreatenode),
                                  TStatementNode(PNode(arg)^).right);
                            TStatementNode(PNode(arg)^).right:=hp;
                            { movedblock before origstmt }
                            hp:=CStatementNode.create(movedblock,PNode(arg)^);
                            PNode(arg)^:=hp;
                            { tempcreate before movedblock }
                            hp:=CStatementNode.create(tempcreatenode,PNode(arg)^);
                            PNode(arg)^:=hp;

                            foreachnodestatic(PNode(arg)^,@searchstatements,nil);
                          end;
                      end;
                    end;
                end;
            end;
          else
            ;
        end;
      end;

    var
      searchstatementsproc : TStaticForEachNodeFunction;

    function searchstatements(var n : TNode;arg : pointer) : TForEachNodeResult;
      begin
        if n.nodetype=statementn then
          begin
            if not(foreachnodestatic(TStatementNode(n).left,@searchblock,@n)) then
              begin
                PBoolean(arg)^:=false;
                result:=fen_norecurse_false;
                exit;
              end;
            { do not recurse automatically, but continue with the next statement }
            result:=fen_norecurse_false;
            foreachnodestatic(TStatementNode(n).right,searchstatementsproc,arg);
          end
        else
          result:=fen_false;
      end;


    function normalize(var n: TNode) : Boolean;
      var
        success : Boolean;
      begin
        success:=true;
        searchstatementsproc:=@searchstatements;
        normalize_success:=@success;
        foreachnodestatic(n,@searchstatements,@success);
        Result:=success;
      end;


end.

