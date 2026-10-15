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
      pass_1,
      paramgr;

    procedure do_opttail(var n : TNode;p : TProcDef);

      var
        labelnode : TLabelNode;

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
                if Assigned(n.fparacopyback) then
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
              (TCallNode(n).procdefinition=p) and
              (not Assigned(TCallNode(n).methodpointer)) and
              (not has_copyback_paras(TCallNode(n)));
            if result then
              usedcallnode:=TCallNode(n)
            else
              { obsolete type cast? }
              result:=((n.nodetype=typeconvn) and (TTypeConvNode(n).convtype=tc_equal) and is_optimizable_recursivecall(TTypeConvNode(n).left));
          end;

        function is_resultassignment(n : TNode) : boolean;
          begin
            result:=((n.nodetype=loadn) and (TLoadNode(n).symtableentry=p.funcretsym)) or
              ((n.nodetype=typeconvn) and (TTypeConvNode(n).convtype=tc_equal) and is_resultassignment(TTypeConvNode(n).left));
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
                if ((n.nodetype=calln) and is_optimizable_recursivecall(n) and is_void(n.resultdef)) or
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

                    calcnodes:=internalstatements(calcstatements);
                    copynodes:=internalstatements(copystatements);
                    paranode:=TCallParaNode(usedcallnode.left);
                    while Assigned(paranode) do
                      begin
                        if Assigned(paranode.fparainit) then
                          begin
                            addstatement(calcstatements,paranode.fparainit);
                            paranode.fparainit:=nil;
                          end;
                        useaddr:=(paranode.parasym.varspez in [vs_var,vs_constref]) or
                          ((paranode.parasym.varspez=vs_const) and
                          paramanager.push_addr_param(paranode.parasym.varspez,paranode.parasym.vardef,p.proccalloption)) or
                          ((paranode.parasym.varspez=vs_value) and
                          is_open_array(paranode.parasym.vardef));
                        if useaddr then
                          begin
                            tempnode:=CTempCreateNode.create(voidpointertype,voidpointertype.size,tt_persistent,true);
                            addstatement(calcstatements,tempnode);
                            addstatement(calcstatements,
                              CAssignmentNode.create(
                                CTempRefNode.create(tempnode),
                                CAddrNode.create_internal(paranode.left)
                                ));
                          end
                        else
                          begin
                            tempnode:=CTempCreateNode.create(paranode.left.resultdef,paranode.left.resultdef.size,tt_persistent,true);
                            addstatement(calcstatements,tempnode);
                            addstatement(calcstatements,
                              CAssignmentNode.create_internal(
                                CTempRefNode.create(tempnode),
                                paranode.left
                                ));
                          end;

                        { "cast" away const varspezs }
                        loadnode:=CLoadNode.create(paranode.parasym,paranode.parasym.owner);
                        include(TLoadNode(loadnode).loadnodeflags,loadnf_isinternal_ignoreconst);

                        { load the address of the symbol instead of symbol }
                        if useaddr then
                          include(TLoadNode(loadnode).loadnodeflags,loadnf_load_addr);
                        addstatement(copystatements,
                          CAssignmentNode.create_internal(
                            loadnode,
                            CTempRefNode.create(tempnode)
                            ));
                        addstatement(copystatements,CTempDeleteNode.create_normal_temp(tempnode));

                        { reused }
                        paranode.left:=nil;
                        paranode:=TCallParaNode(paranode.right);
                      end;

                    oldnodetree:=n;
                    n:=internalstatements(nodes);

                    if Assigned(usedcallnode.callinitblock) then
                      begin
                        addstatement(nodes,usedcallnode.callinitblock);
                        usedcallnode.callinitblock:=nil;
                      end;

                    addstatement(nodes,calcnodes);
                    addstatement(nodes,copynodes);

                    { create goto }
                    addstatement(nodes,CGotoNode.create(labelnode.labsym));

                    if Assigned(usedcallnode.callcleanupblock) then
                      begin
                        { callcleanupblock should contain only temp. node clean up }
                        checktreenodetypes(usedcallnode.callcleanupblock,
                          [tempdeleten,blockn,statementn,temprefn,nothingn]);
                        addstatement(nodes,usedcallnode.callcleanupblock);
                        usedcallnode.callcleanupblock:=nil;
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
            if (varspez=vs_out) or
               { parameters requiring tables are too complicated to handle
                 and slow down things anyways so a tail recursion call
                 makes no sense
               }
               is_managed_type(vardef) then
              begin
{$ifdef debug_opttail}
        WriteLn('====================================================================================');
        write('callnode: ',p.gettypename,' tail call opt disabled because parameter ',i,' ',realname,' ');
        if is_managed_type(vardef) then
          write('is managed ')
        else if (varspez=vs_out) then
          write('is out parameter');
        WriteLn;
        WriteLn('====================================================================================');
{$endif debug_opttail}
                exit;
              end;

{$ifdef fix_opttail}
        { check if the local parameters should prevent tail recursion elimination }
        for i:=0 to p.localst.count-1 do
          with TAbstractVarSym(p.localst[i]) do
            if is_managed_type(vardef) then
              begin
{$ifdef debug_opttail}
        WriteLn('====================================================================================');
        WriteLn('callnode: ',p.gettypename,' tail call opt disabled because local ',i,' ',realname,' is managed');
        WriteLn('====================================================================================');
{$endif debug_opttail}
                exit;
              end;
{$endif fix_opttail}

        labelsym:=CLabelSym.create('$opttail');
        labelnode:=CLabelNode.create(CNothingNode.create,labelsym);
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
            n:=internalstatements(s);
            addstatement(s,labelnode);
            addstatement(s,oldnodes);
{$ifdef debug_opttail}
        WriteLn('====================================================================================');
        write('Tail call replaced by: ');
        printnode(Output,n);
        WriteLn('====================================================================================');
        WriteLn;
{$endif debug_opttail}
          end
        else
          labelnode.free;
          labelnode := nil;
      end;

end.

