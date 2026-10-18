{
    Tail recursion optimization

    Copyright (c) 2006 by Florian Klaempfl

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
unit opttail;

{$i fpcdefs.inc}

  interface

    uses
      symdef,node;

    procedure do_opttail(var n : TNode;p : TProcDef);

  implementation

    uses
      GlobType,
      symconst,SymSym,
      defcmp,defutil,
      nutils,nbas,nflw,ncal,nld,ncnv,nmem,
      Pass_1,
      paramgr;

    procedure do_opttail(var n : TNode;p : TProcDef);

      var
        LabelNode : TLabelNode;

      function find_and_replace_tailcalls(var n : TNode) : boolean;

        var
          usedcallnode : TCallNode;

        function has_copyback_paras(call: TCallNode): boolean;
          var
            n: TCallParaNode;
          begin
            n:=TCallParaNode(call.left);
            result:=false;
            while Assigned(n) do
              begin
                if Assigned(n.FParaCopyBack) then
                  begin
                    result:=true;
                    exit;
                  end;
                n:=TCallParaNode(n.right);
              end;
          end;

        function is_optimizable_recursivecall(n : TNode) : boolean;
          begin
            result:=
              (n.nodetype=calln) and
              (TCallNode(n).ProcDefinition=p) and
              (not Assigned(TCallNode(n).MethodPointer)) and
              (not has_copyback_paras(TCallNode(n)));
            if result then
              usedcallnode:=TCallNode(n)
            else
              { obsolete type cast? }
              result:=((n.nodetype=typeconvn) and (TTypeConvNode(n).ConvType=tc_equal) and is_optimizable_recursivecall(TTypeConvNode(n).left));
          end;

        function is_resultassignment(n : TNode) : boolean;
          begin
            result:=((n.nodetype=loadn) and (TLoadNode(n).SymTableEntry=p.FuncRetSym)) or
              ((n.nodetype=typeconvn) and (TTypeConvNode(n).ConvType=tc_equal) and is_resultassignment(TTypeConvNode(n).left));
          end;

        var
          calcnodes,
          copynodes,
          hp : TNode;
          nodes,
          calcstatements,
          copystatements : TStatementNode;
          paranode : TCallParaNode;
          tempnode : TTempCreateNode;
          loadnode : TLoadNode;
          oldnodetree : TNode;
          useaddr : boolean;
        begin
          { no tail call found and replaced so far }
          result:=false;
          if n=nil then
            exit;
          usedcallnode:=nil;
          case n.nodetype of
            statementn:
              begin
                hp:=n;
                { search last node }
                while Assigned(TStatementNode(hp).right) do
                  hp:=TStatementNode(hp).right;
                result:=find_and_replace_tailcalls(TStatementNode(hp).left);
              end;
            ifn:
              begin
                result:=find_and_replace_tailcalls(TIfNode(n).right);
                { avoid short bool eval here }
                result:=find_and_replace_tailcalls(TIfNode(n).t1) or result;
              end;
            calln,
            assignn:
              begin
                if ((n.nodetype=calln) and is_optimizable_recursivecall(n) and Is_Void(n.resultdef)) or
                   ((n.nodetype=assignn) and is_resultassignment(TBinaryNode(n).left) and
                   is_optimizable_recursivecall(TBinaryNode(n).right)) then
                  begin
                    { found one! }
                    {
                    writeln('tail recursion optimization for ',p.mangledname);
                    printnode(output,n);
                    }
                    { create assignments for all parameters }

                    { this is hairy to do because one parameter could be used to calculate another one, so
                      assign them first to temps and then add them }

                    calcnodes:=InternalStatements(calcstatements);
                    copynodes:=InternalStatements(copystatements);
                    paranode:=TCallParaNode(usedcallnode.left);
                    while Assigned(paranode) do
                      begin
                        if Assigned(paranode.FParaInit) then
                          begin
                            AddStatement(calcstatements,paranode.FParaInit);
                            paranode.FParaInit:=nil;
                          end;
                        useaddr:=(paranode.ParaSym.VarSpez in [vs_var,vs_constref]) or
                          ((paranode.ParaSym.VarSpez=vs_const) and
                          ParaManager.Push_Addr_Param(paranode.ParaSym.VarSpez,paranode.ParaSym.vardef,p.ProcCallOption)) or
                          ((paranode.ParaSym.VarSpez=vs_value) and
                          Is_Open_Array(paranode.ParaSym.vardef));
                        if useaddr then
                          begin
                            tempnode:=CTempCreateNode.Create(VoidPointerType,VoidPointerType.Size,tt_persistent,true);
                            AddStatement(calcstatements,tempnode);
                            AddStatement(calcstatements,
                              CAssignmentNode.Create(
                                CTempRefNode.Create(tempnode),
                                CAddrNode.Create_Internal(paranode.left)
                                ));
                          end
                        else
                          begin
                            tempnode:=CTempCreateNode.Create(paranode.left.resultdef,paranode.left.resultdef.Size,tt_persistent,true);
                            AddStatement(calcstatements,tempnode);
                            AddStatement(calcstatements,
                              CAssignmentNode.Create_Internal(
                                CTempRefNode.Create(tempnode),
                                paranode.left
                                ));
                          end;

                        { "cast" away const varspezs }
                        loadnode:=CLoadNode.Create(paranode.ParaSym,paranode.ParaSym.owner);
                        include(TLoadNode(loadnode).LoadNodeFlags,loadnf_isinternal_ignoreconst);

                        { load the address of the symbol instead of symbol }
                        if useaddr then
                          include(TLoadNode(loadnode).LoadNodeFlags,loadnf_load_addr);
                        AddStatement(copystatements,
                          CAssignmentNode.Create_Internal(
                            loadnode,
                            CTempRefNode.Create(tempnode)
                            ));
                        AddStatement(copystatements,CTempDeleteNode.Create_Normal_Temp(tempnode));

                        { reused }
                        paranode.left:=nil;
                        paranode:=TCallParaNode(paranode.right);
                      end;

                    oldnodetree:=n;
                    n:=InternalStatements(nodes);

                    if Assigned(usedcallnode.CallInitBlock) then
                      begin
                        AddStatement(nodes,usedcallnode.CallInitBlock);
                        usedcallnode.CallInitBlock:=nil;
                      end;

                    AddStatement(nodes,calcnodes);
                    AddStatement(nodes,copynodes);

                    { create goto }
                    AddStatement(nodes,CGotoNode.Create(LabelNode.LabSym));

                    if Assigned(usedcallnode.CallCleanupBlock) then
                      begin
                        { callcleanupblock should contain only temp. node clean up }
                        CheckTreeNodeTypes(usedcallnode.CallCleanupBlock,
                          [tempdeleten,blockn,statementn,temprefn,nothingn]);
                        AddStatement(nodes,usedcallnode.CallCleanupBlock);
                        usedcallnode.CallCleanupBlock:=nil;
                      end;

                    oldnodetree.free;
                    oldnodetree := nil;

                    DoFirstPass(n);
                    result:=true;
                  end;
              end;
            blockn:
              result:=find_and_replace_tailcalls(TBlockNode(n).left);
            else
              ;
          end;
        end;

      var
        s : TStatementNode;
        oldnodes : TNode;
        i : LongInt;
        labelsym : TLabelSym;
      begin
        { check if the parameters actually would support tail recursion elimination }
        for i:=0 to p.paras.count-1 do
          with TParaVarSym(p.paras[i]) do
            if (VarSpez=vs_out) or
               { parameters requiring tables are too complicated to handle
                 and slow down things anyways so a tail recursion call
                 makes no sense
               }
               Is_Managed_Type(vardef) then
              begin
{$ifdef debug_opttail}
        WriteLn('====================================================================================');
        write('callnode: ',p.gettypename,' tail call opt disabled because parameter ',i,' ',realname,' ');
        if Is_Managed_Type(vardef) then
          write('is managed ')
        else if (VarSpez=vs_out) then
          write('is out parameter');
        WriteLn;
        WriteLn('====================================================================================');
{$endif debug_opttail}
                exit;
              end;

{$ifdef fix_opttail}
        { check if the local parameters should prevent tail recursion elimination }
        for i:=0 to p.LocalST.count-1 do
          with TAbstractVarSym(p.LocalST[i]) do
            if Is_Managed_Type(vardef) then
              begin
{$ifdef debug_opttail}
        WriteLn('====================================================================================');
        WriteLn('callnode: ',p.gettypename,' tail call opt disabled because local ',i,' ',realname,' is managed');
        WriteLn('====================================================================================');
{$endif debug_opttail}
                exit;
              end;
{$endif fix_opttail}

        labelsym:=CLabelSym.Create('$opttail');
        LabelNode:=CLabelNode.Create(CNothingNode.Create,labelsym);
        if find_and_replace_tailcalls(n) then
          begin
{$ifdef debug_opttail}
        WriteLn('====================================================================================');
        WriteLn('Tail call optimization found:');
        WriteLn('====================================================================================');
        write('callnode: ',p.gettypename);
        WriteLn('====================================================================================');
{$endif debug_opttail}
            oldnodes:=n;
            n:=InternalStatements(s);
            AddStatement(s,LabelNode);
            AddStatement(s,oldnodes);
{$ifdef debug_opttail}
        WriteLn('====================================================================================');
        write('Tail call replaced by: ');
        PrintNode(Output,n);
        WriteLn('====================================================================================');
        WriteLn;
{$endif debug_opttail}
          end
        else
          LabelNode.free;
          LabelNode := nil;
      end;

end.

