{
    Helper routines for the optimizer

    Copyright (c) 2007 by Florian Klaempfl

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
unit optutils;

{$i fpcdefs.inc}

  interface

    uses
      CClasses,
      node,
      GlobType;

    type
      { this implementation should be really improved,
        its purpose is to find equal nodes }
      TIndexedNodeSet = class(TFPList)
        function Add(node : TNode) : boolean;
        function Includes(node : TNode) : TNode;
        function Remove(node : TNode) : boolean;
      end;

    procedure SetNodeSucessors(p,last : TNode);
    procedure PrintDFAInfo(var f : text;p : TNode);
    procedure PrintIndexedNodeSet(var f : text;s : TIndexedNodeSet);

    { determines the optinfo.defsum field for the given node
      this field contains a sum of all expressions defined by
      all child expressions reachable through p
    }
    procedure CalcDefSum(p : TNode);

    { calculates/estimates the field execution weight of optinfo }
    procedure CalcExecutionWeights(p : TNode;Initial : LongInt = 100);

    { determines the optinfo.defsum field for the given node
      this field contains a sum of all expressions defined by
      all child expressions reachable through p
    }
    procedure CalcUseSum(p : TNode);

    { returns true, if n is a valid node and has life info }
    function has_life_info(n : TNode) : boolean;

  implementation

    uses
      CUtils,CDynSet,
      Verbose,
      optbase,
      ncal,nbas,nflw,nutils,nset,ncon;

    function TIndexedNodeSet.Add(node : TNode) : boolean;
      var
        i : Integer;
        p : TNode;
      begin
        node.allocoptinfo;
        p:=Includes(node);
        if Assigned(p) then
          begin
            result:=false;
            node.optinfo^.index:=p.optinfo^.index;
          end
        else
          begin
            i:=inherited Add(node);
            node.optinfo^.index:=i;
            result:=true;
          end
      end;


    function TIndexedNodeSet.Includes(node : TNode) : TNode;
      var
        i : LongInt;
      begin
        for i:=0 to Count-1 do
          if TNode(List[i]).isequal(node) then
            begin
              result:=TNode(List[i]);
              exit;
            end;
        result:=nil;
      end;


    function TIndexedNodeSet.Remove(node : TNode) : boolean;
      var
        p : TNode;
      begin
        result:=false;
        p:=Includes(node);
        if Assigned(p) then
          begin
            if inherited Remove(p)<>-1 then
              result:=true;
          end;
      end;


    procedure PrintIndexedNodeSet(var f : text;s : TIndexedNodeSet);
      var
        i : integer;
      begin
        for i:=0 to s.count-1 do
          begin
            WriteLn(f,'=============================== Node ',i,' ===============================');
            printnode(f,TNode(s[i]));
            WriteLn(f);
          end;
      end;


    function PrintNodeDFA(var n: TNode; arg: pointer): TForEachNodeResult;
      begin
        if Assigned(n.optinfo) and ((n.optinfo^.life<>nil) or (n.optinfo^.use<>nil) or (n.optinfo^.def<>nil)) then
          begin
            write(text(arg^),nodetype2str[n.nodetype],'(',n.fileinfo.line,',',n.fileinfo.column,') Life: ');
            PrintDynSet(text(arg^),n.optinfo^.life);
            write(text(arg^),' Def: ');
            PrintDynSet(text(arg^),n.optinfo^.def);
            write(text(arg^),' Use: ');
            PrintDynSet(text(arg^),n.optinfo^.use);
            if Assigned(n.successor) then
              write(text(arg^),' Successor: ',nodetype2str[n.successor.nodetype],'(',n.successor.fileinfo.line,',',n.successor.fileinfo.column,')')
            else
              write(text(arg^),' Successor: nil');
            write(text(arg^),' DefSum: ');
            PrintDynSet(text(arg^),n.optinfo^.defsum);
            WriteLn(text(arg^));
          end;
        result:=fen_false;
      end;


    procedure PrintDFAInfo(var f : text;p : TNode);
      begin
        foreachnodestatic(pm_postprocess,p,@PrintNodeDFA,@f);
      end;


    type
      PBreakContinueStackNode = ^TBreakContinueStackNode;
      TBreakContinueStackNode = record
        { successor node for a break statement in the current loop }
        brk,
        { successor node for a continue statement in the current loop }
        cont : TNode;
        next : PBreakContinueStackNode;
      end;

      { implements a stack to track successor nodes for break and continue
        statements }
      TBreakContinueStack = object
        top: PBreakContinueStackNode;
        constructor Init;
        destructor Done;
        procedure Push(brk,cont : TNode);
        procedure Pop;
      end;

    const
      NullBreakContinueStackNode : TBreakContinueStackNode = (brk: nil; cont: nil; next: nil);


    constructor TBreakContinueStack.Init;
      begin
        top:=@NullBreakContinueStackNode;
      end;


    destructor TBreakContinueStack.Done;
      begin
        while top<>@NullBreakContinueStackNode do
          Pop;
      end;


    procedure TBreakContinueStack.Push(brk,cont : TNode);
      var
        n : PBreakContinueStackNode;
      begin
        new(n);
        n^.brk:=brk;
        n^.cont:=cont;
        n^.next:=top;
        top:=n;
      end;


    procedure TBreakContinueStack.Pop;
      var
        n : PBreakContinueStackNode;
      begin
        n:=top;
        top:=n^.next;
        Dispose(n);
      end;


    procedure SetNodeSucessors(p,last : TNode);
      var
        BreakContinueStack : TBreakContinueStack;
        Exitsuccessor: TNode;
      { sets the successor nodes of a node tree block
        returns the first node of the tree if it's a control flow node }
      function DoSet(p : TNode;succ : TNode) : TNode;
        var
          hp1,hp2, oldexitsuccessor: TNode;
          i : LongInt;
        begin
          result:=nil;
          if p=nil then
            exit;
          case p.nodetype of
            statementn:
              begin
                hp1:=p;
                result:=p;
                while Assigned(hp1) do
                  begin
                    { does another statement follow? }
                    if Assigned(TStatementNode(hp1).next) then
                      begin
                        hp2:=DoSet(TStatementNode(hp1).statement,TStatementNode(hp1).next);
                        if Assigned(hp2) then
                          TStatementNode(hp1).successor:=hp2
                        else
                          TStatementNode(hp1).successor:=TStatementNode(hp1).next;
                      end
                    else
                      begin
                        hp2:=DoSet(TStatementNode(hp1).statement,succ);
                        if Assigned(hp2) then
                          TStatementNode(hp1).successor:=hp2
                        else
                          TStatementNode(hp1).successor:=succ;
                      end;
                    hp1:=TStatementNode(hp1).next;
                  end;
              end;
            blockn:
              begin
                result:=p;
                oldexitsuccessor:=Exitsuccessor;
                if nf_block_with_exit in p.flags then
                  Exitsuccessor:=succ;
                DoSet(TBlockNode(p).statements,succ);
                if Assigned(TBlockNode(p).statements) then
                  p.successor:=TBlockNode(p).statements
                else
                  p.successor:=succ;
                Exitsuccessor:=oldexitsuccessor;
              end;
            forn:
              begin
                BreakContinueStack.Push(succ,p);
                result:=p;
                { the successor of the last node of the for body is the dummy loop iteration node
                  it allows the dfa to inject needed life information into the loop }
                TForNode(p).loopiteration:=CNothingNode.create;

                DoSet(TForNode(p).t2,TForNode(p).loopiteration);
                p.successor:=succ;
                BreakContinueStack.Pop;
              end;
            breakn:
              begin
                result:=p;
                p.successor:=BreakContinueStack.top^.brk;
              end;
            continuen:
              begin
                result:=p;
                p.successor:=BreakContinueStack.top^.cont;
              end;
            whilerepeatn:
              begin
                BreakContinueStack.Push(succ,p);
                result:=p;
                { the successor of the last node of the while/repeat body is the while node itself }
                DoSet(TWhileRepeatNode(p).right,p);

                p.successor:=succ;

                { special case: we do not do a dyn. dfa, but we should handle endless loops }
                if is_constboolnode(TWhileRepeatNode(p).left) then
                  begin
                    if ((lnf_testatbegin in TWhileRepeatNode(p).loopflags) and
                      getbooleanvalue(TWhileRepeatNode(p).left)) or (not(lnf_testatbegin in TWhileRepeatNode(p).loopflags) and
                      not(getbooleanvalue(TWhileRepeatNode(p).left))) then
                      p.successor:=nil;
                  end;

                BreakContinueStack.Pop;
              end;
            ifn:
              begin
                result:=p;
                DoSet(TIfNode(p).right,succ);
                DoSet(TIfNode(p).t1,succ);
                p.successor:=succ;
              end;
            labeln:
              begin
                result:=p;
                p.successor:=succ;
              end;
            assignn:
              begin
                result:=p;
                p.successor:=succ;
              end;
            goton:
              begin
                result:=p;
                if not(Assigned(TGotoNode(p).labelnode)) then
                  InternalError(2007050701);
                p.successor:=TGotoNode(p).labelnode;
              end;
            exitn:
              begin
                result:=p;
                p.successor:=Exitsuccessor;
              end;
            casen:
              begin
                result:=p;
                DoSet(TCaseNode(p).elseblock,succ);
                for i:=0 to TCaseNode(p).blocks.count-1 do
                  DoSet(PCaseBlock(TCaseNode(p).blocks[i])^.statement,succ);
                p.successor:=succ;
              end;
            calln:
              begin
                { not sure if this is enough (FK) }
                result:=p;
                if cnf_call_never_returns in TCallNode(p).callnodeflags then
                  p.successor:=nil
                else
                  p.successor:=succ;
              end;
            inlinen:
              begin
                { not sure if this is enough (FK) }
                result:=p;
                p.successor:=succ;
              end;
            loadn,
            tempcreaten,
            tempdeleten,
            nothingn:
               begin
                result:=p;
                p.successor:=succ;
              end;
            raisen:
              begin
                result:=p;
                { raise never returns }
                p.successor:=nil;
              end;
            tryexceptn,
            tryfinallyn,
            onn:
              InternalError(2007050501);
            else
              ;
          end;
        end;

      begin
        BreakContinueStack.Init;
        Exitsuccessor:=nil;
        DoSet(p,last);
        BreakContinueStack.Done;
      end;


    function adddef(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        defsum : PDFASet absolute arg;
      begin
        if Assigned(n.optinfo) then
          begin
            DynSetIncludeSet(defsum^,n.optinfo^.def);
            { for nodes itself do not necessarily expose the definition of the counter as
              the counter might be undefined after the for loop, so include here the counter
              explicitly }
            if (n.nodetype=forn) and Assigned(TForNode(n).left.optinfo) then
              DynSetInclude(defsum^,TForNode(n).left.optinfo^.index);
          end;
        Result:=fen_false;
      end;


    procedure CalcDefSum(p : TNode);
      var
        defsum : PDFASet;
      begin
        p.allocoptinfo;
        defsum:=@p.optinfo^.defsum;
        if not Assigned(defsum^) then
            foreachnodestatic(pm_postprocess,p,@adddef,defsum);
      end;


    function SetExecutionWeight(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        Weight, CaseWeight : LongInt;
        i : Integer;
      begin
        Result:=fen_false;
        n.allocoptinfo;
        Weight:=max(PLongInt(arg)^,1);
        case n.nodetype of
          casen:
            begin
              CalcExecutionWeights(TCaseNode(n).left,Weight);
              CaseWeight:=max(Weight div TCaseNode(n).labelcnt,1);
              for i:=0 to TCaseNode(n).blocks.count-1 do
                CalcExecutionWeights(PCaseBlock(TCaseNode(n).blocks[i])^.statement,CaseWeight);

              CalcExecutionWeights(TCaseNode(n).elseblock,CaseWeight);
              Result:=fen_norecurse_false;
            end;
          whilerepeatn:
            begin
              CalcExecutionWeights(TWhileRepeatNode(n).right,Weight*8);
              CalcExecutionWeights(TWhileRepeatNode(n).left,Weight*8);
              Result:=fen_norecurse_false;
            end;
          ifn:
            begin
              CalcExecutionWeights(TIfNode(n).left,Weight);
              CalcExecutionWeights(TIfNode(n).right,Weight div 2);
              CalcExecutionWeights(TIfNode(n).t1,Weight div 2);
              Result:=fen_norecurse_false;
            end;
          else
            ;
        end;
        n.optinfo^.executionweight:=Weight;
      end;


    procedure CalcExecutionWeights(p : TNode;Initial : LongInt = 100);
      begin
        if Assigned(p) then
          foreachnodestatic(pm_postprocess,p,@SetExecutionWeight,Pointer(@Initial));
      end;


    function adduse(var n: TNode; arg: pointer): TForEachNodeResult;
      var
        usesum : PDFASet absolute arg;
      begin
        if Assigned(n.optinfo) then
          DynSetIncludeSet(usesum^,n.optinfo^.use);
        Result:=fen_false;
      end;


    procedure CalcUseSum(p : TNode);
      var
        usesum : PDFASet;
      begin
        p.allocoptinfo;
        usesum:=@p.optinfo^.usesum;
        if not Assigned(usesum^) then
            foreachnodestatic(pm_postprocess,p,@adduse,usesum);
      end;


    function has_life_info(n : TNode) : boolean;
      begin
        result:=Assigned(n) and Assigned(n.optinfo) and
          Assigned(n.optinfo^.life);
      end;

end.

