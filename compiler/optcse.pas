{
    Common subexpression elimination on base blocks

    Copyright (c) 2005-2012 by Florian Klaempfl

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
unit optcse;

{$i fpcdefs.inc}

{ $define csedebug}
{ $define csestats}

  interface

    uses
      sysutils,node;

    {
      the function  creates non optimal code so far:
      - call para nodes are cse barriers because they can be reordered and thus the
        temp. creation could be done too late
      - the cse knows nothing about register pressure. In case of high register pressure, cse might
        have a negative impact
      - the list of cseinvariant node types and inline numbers is not complete yet

      Further, it could be done probably in a faster way though the complexity can't probably not reduced
    }
    function do_optcse(var rootnode : TNode) : TNode;
    function do_consttovar(var rootnode : TNode) : TNode;

  implementation

    uses
      globtype,cdynset,globals,
      systems,
      cutils,cclasses,
      nutils,compinnr,
      nbas,nld,ninl,ncal,nadd,nmem,ncnv,
      pass_1,
      procinfo,
      paramgr,
      cpubase,
      symconst,symdef,symsym,symtable,symtype,
      defutil,
      optbase;

    const
      cseinvariant : set of TNodeType = [addn,muln,subn,divn,slashn,modn,andn,orn,xorn,notn,vecn,
        derefn,equaln,unequaln,ltn,gtn,lten,gten,typeconvn,subscriptn,
        inn,symdifn,shrn,shln,ordconstn,realconstn,unaryminusn,pointerconstn,stringconstn,setconstn,niln,
        setelementn,{arrayconstructorn,arrayconstructorrangen,}
        isn,asn,starstarn,nothingn,temprefn,loadparentfpn {,callparan},assignn,addrn];

    function searchsubdomain(var n:TNode; arg: pointer) : foreachnoderesult;
      begin
        if (n.nodetype in cseinvariant) or
          ((n.nodetype=inlinen) and
           (tinlinenode(n).inlinenumber in [in_length_x,in_assigned_x,in_sqr_real,in_sqrt_real,in_sin_real,in_cos_real,in_abs_long,
             in_abs_real,in_exp_real,in_ln_real,in_pi_real,in_popcnt_x,in_arctan_real,in_round_real,in_trunc_real,
             { cse on fma will still not work because it would require proper handling of call nodes
               with more than one parameter }
             in_fma_single,in_fma_double,in_fma_extended,
             in_min_single,in_min_double,in_max_single,in_max_double,
             in_max_longint,in_max_dword,in_min_longint,in_min_dword,
             in_max_int64,in_max_qword,in_min_int64,in_min_qword
             ])
          ) or
          ((n.nodetype=callparan) and not(assigned(tcallparanode(n).right))) or
          ((n.nodetype=loadn) and
            not((tloadnode(n).symtableentry.typ in [staticvarsym,localvarsym,paravarsym]) and
                (vo_volatile in tabstractvarsym(tloadnode(n).symtableentry).varoptions))
          ) then
          result:=fen_true
        else
          begin
            pboolean(arg)^:=false;
            result:=fen_norecurse_true;
          end;
      end;

    type
      tlists = record
        nodelist : tfplist;
        locationlist : tfplist;
        equalto : tfplist;
        refs : tfplist;
        avail : TDFASet;
      end;

      plists = ^tlists;

    { collectnodes needs the address of itself to call foreachnodestatic,
      so we need a wrapper because @<func> inside <func doesn't work }

    function collectnodes(var n:TNode; arg: pointer) : foreachnoderesult;forward;

    function collectnodes2(var n:TNode; arg: pointer) : foreachnoderesult;
      begin
        result:=collectnodes(n,arg);
      end;


    function collectnodes(var n:TNode; arg: pointer) : foreachnoderesult;

      { when compiling a tree like
            and
            / \
          and  C
          / \
         A   B
        all expressions of B are available during evaluation of C. However considering the whole expression,
        values of B and C might not be available due to short boolean evaluation.

        So recurseintobooleanchain detects such chained and/or expressions and removes sub-expressions of B
        that are referenced in C

        firstleftend is later used to remove all sub-expressions of B and C by storing the expression count
        in the CSE table after handling A
      }
      var
        firstleftend : longint;
        maybeskipped : TDFASet; { Only valid for the current "collectnodes" invocation }

      procedure recurseintobooleanchain(t : TNodeType;n : TNode);
        var
          i, rightstart : longint;
        begin
          if (TBinaryNode(n).left.nodetype=t) and is_boolean(TBinaryNode(n).left.resultdef) then
            recurseintobooleanchain(t,TBinaryNode(n).left)
          else
            foreachnodestatic(pm_postprocess,TBinaryNode(n).left,@collectnodes2,arg);

          rightstart:=plists(arg)^.nodelist.count;
          firstleftend:=min(rightstart,firstleftend);

          if doshortbooleval(n) then
            begin
              foreachnodestatic(pm_postprocess,TBinaryNode(n).right,@collectnodes2,arg);

              { short boolean evaluation might skip the right side of n in nested nodes }
              for i:=rightstart to plists(arg)^.nodelist.count-1 do
                DynSetInclude(maybeskipped,i);
            end
          else
            begin
              { if n does not use short boolean evaluation, its right side is always
                evaluated, even when an and/or node deeper in the chain used short
                boolean evaluation and skipped its own right side. Expressions
                collected from such skipped right sides must therefore not be
                available while collecting the right side of n }
              for i:=firstleftend to rightstart-1 do
                if DynSetIn(maybeskipped,i) then
                  DynSetExclude(plists(arg)^.avail,i);

              { We can only collect the right nodes after excluding the left
                side so newer entries don't reference them }
              foreachnodestatic(pm_postprocess,TBinaryNode(n).right,@collectnodes2,arg);
            end;
        end;

      var
        i : longint;
        tempdef : tdef;
      begin
        result:=fen_false;
        { don't add the tree below an untyped const parameter: there is
          no information available that this kind of tree actually needs
          to be addressable, this could be improved }
        { the nodes below a type conversion node created for an absolute
          reference cannot be handled separately, because the absolute reference
          may have special requirements (no regability, must be in memory, ...)
        }
        if (((n.nodetype=callparan) and
             (tcallparanode(n).left.resultdef.typ=formaldef) and
             (tcallparanode(n).parasym.varspez=vs_const)) or
            ((n.nodetype=typeconvn) and
             (nf_absolute in n.flags))
           ) then
          begin
            result:=fen_norecurse_false;
            exit;
          end;
        if
          { node possible to add? }
          assigned(n.resultdef) and
          ((
            { regable expressions }
            (actualtargetnode(@n)^.flags*[nf_write,nf_modify,nf_address_taken]=[]) and
            (
              tstoreddef(n.resultdef).is_intregable or
              tstoreddef(n.resultdef).is_fpuregable or
              tstoreddef(n.resultdef).is_const_intregable
            ) and
            { is_int/fpuregable allows arrays and records to be in registers, cse cannot handle this }
            (
              not(n.resultdef.typ in [arraydef,recorddef]) or
              (
                (
                  (n.resultdef.typ = recorddef) and
                  tabstractrecordsymtable(tabstractrecorddef(n.resultdef).symtable).has_single_field(tempdef)
                ) or
                is_dynamic_array(n.resultdef) or
                (
                  not(is_special_array(tstoreddef(n.resultdef))) and
                  not(tstoreddef(n.resultdef).is_intregable) and
                  not(tstoreddef(n.resultdef).is_fpuregable)
                )
              )
            ) and
            { same for voiddef }
            not(is_void(n.resultdef)) and
            { adding tempref and callpara nodes itself is worthless but
              their complexity is probably <= 1 anyways

              neither add setelementn nodes because the compiler sometimes depends on the fact
              that a certain node stays a setelementn, this does not hurt either because
              setelementn nodes itself generate no real code (except moving data into register) }
            not(n.nodetype in [temprefn,callparan,setelementn]) and

            { node worth to add?

              We consider almost every node because even loading a variables from
              a register instead of memory is more beneficial. This behaviour should
              not increase register pressure because if a variable is already
              in a register, the reg. allocator can merge the nodes. If a variable
              is loaded from memory, loading this variable and spilling another register
              should not add a speed penalty.
            }
            {
              load nodes are not considered if they load para or local symbols from the
              current stack frame, those are in registers anyways if possible
            }
            (not(actualtargetnode(@n)^.nodetype=loadn) or
             not(tloadnode(actualtargetnode(@n)^).symtableentry.typ in [paravarsym,localvarsym,staticvarsym]) or
             { apply cse on non-regable variables }
             ((tloadnode(actualtargetnode(@n)^).symtableentry.typ in [paravarsym,localvarsym,staticvarsym]) and
               not(tabstractvarsym(tloadnode(actualtargetnode(@n)^).symtableentry).is_regvar(true)) and
               not(vo_volatile in tabstractvarsym(tloadnode(actualtargetnode(@n)^).symtableentry).varoptions)) or
             (node_complexity(n)>1)
            ) and

            {
              Const nodes however are only considered if their complexity is >1
              This might be the case for the risc architectures if they need
              more than one instruction to load this particular value
            }
            (not(is_constnode(n)) or (node_complexity(n)>1)))
{$if not(defined(i386))}
            or
            { store reference of expression? }

            { loading the address of a global symbol takes typically more than
              one instruction on every platform except i8086/i386
              so consider in this case loading the address of the data
            }
            (((n.resultdef.typ in [arraydef,recorddef]) or is_object(n.resultdef)) and not(is_dynamic_array(n.resultdef)) and
             (n.nodetype=loadn) and
             (tloadnode(n).symtableentry.typ=staticvarsym)
            )
{$endif not(defined(i386))}
          ) then
          begin
            plists(arg)^.nodelist.Add(n);
            plists(arg)^.locationlist.Add(@n);
            plists(arg)^.refs.Add(nil);
            plists(arg)^.equalto.Add(pointer(-1));

            DynSetInclude(plists(arg)^.avail,plists(arg)^.nodelist.count-1);

            for i:=0 to plists(arg)^.nodelist.count-2 do
              begin
                if TNode(plists(arg)^.nodelist[i]).isequal(n) and DynSetIn(plists(arg)^.avail,i) then
                  begin
                    { use always the first occurrence }
                    if plists(arg)^.equalto[i]<>pointer(-1) then
                      plists(arg)^.equalto[plists(arg)^.nodelist.count-1]:=plists(arg)^.equalto[i]
                    else
                      plists(arg)^.equalto[plists(arg)^.nodelist.count-1]:=pointer(ptrint(i));
                    plists(arg)^.refs[i]:=pointer(plists(arg)^.refs[i])+1;
                    { tree has been found, no need to search further,
                      sub-trees have been added by the first occurrence of
                      the tree already }
                    result:=fen_norecurse_false;
                    break;
                  end;
              end;
          end;

        { boolean and/or require a special handling: after evaluating the and/or node,
          the expressions of the right side might not be available due to short boolean
          evaluation, so after handling the right side, mark those expressions
          as unavailable }
        if doshortbooleval(n) and is_boolean(taddnode(n).left.resultdef) then
          begin
            SetLength(maybeskipped,0);
            firstleftend:=high(longint);
            recurseintobooleanchain(n.nodetype,n);

            { Exclude tge nodes from the chain if there's a chance they'll be skipped }
            for i:=firstleftend to plists(arg)^.nodelist.count-1 do
              if DynSetIn(maybeskipped,i) then
                DynSetExclude(plists(arg)^.avail,i);

            result:=fen_norecurse_false;
          end;
{$ifdef cpuhighleveltarget}
          { The high level targets use the functionality from ncgnstld for
            nested accesses, and that one stores the complete location of the
            nested variable in tloadnode.left rather than only the location of
            the parent context containing it. This causes problems with the
            CSE in case the nested variable is used as an lvalue, so disable
            CSE in that case
          }
          if (n.nodetype=loadn) and assigned(tloadnode(n).left) then
            result:=fen_norecurse_false;
{$endif}
       end;


    function searchcsedomain(var n: TNode; arg: pointer) : foreachnoderesult;
      var
        csedomain : boolean;
        lists : tlists;
        templist : tfplist;
        i : longint;
        def : tstoreddef;
        nodes : tblocknode;
        creates,
        statements : tstatementnode;
        deletetemp : ttempdeletenode;
        hp : ttempcreatenode;
        addrstored : boolean;
        hp2 : TNode;
      begin
        result:=fen_false;
        nodes:=nil;
        if (n.nodetype in cseinvariant) and
          { a setelement node is cseinvariant, but it might not be replaced by a block so
            it cannot be the root of the cse search }
          (n.nodetype<>setelementn) then
          begin
            csedomain:=true;
            foreachnodestatic(pm_postprocess,n,@searchsubdomain,@csedomain);
            if not(csedomain) then
              begin
                { try to transform the tree to get better cse domains, consider:
                       +   (1)
                      / \
                (2)  +   C
                    / \
                   A   B

                  if A is not cse'able but B and C are, then the compiler cannot do cse so the tree is transformed into
                       +
                      / \
                     A   +
                        / \
                       B   C
                  Because A could be another tree of this kind, the whole process is done in a while loop
                }
                if (n.nodetype in [andn,orn,addn,muln]) and
                  (n.nodetype=TBinaryNode(n).left.nodetype) and
                  { do is optimizations only for integers, reals (no currency!), vectors, sets or booleans }
                  (is_integer(n.resultdef) or is_real(n.resultdef) or is_vector(n.resultdef) or is_set(n.resultdef) or
                   is_boolean(n.resultdef)) and
                  { either if fastmath is on }
                  ((cs_opt_fastmath in CurrentSettings.optimizerswitches) or
                   { or for the logical operators, they cannot overflow }
                   (n.nodetype in [andn,orn]) or
                   { or for integers if range checking is off }
                   ((is_integer(n.resultdef) and
                    (n.localswitches*[cs_check_range,cs_check_overflow]=[]) and
                    (TBinaryNode(n).left.localswitches*[cs_check_range,cs_check_overflow]=[]))) or
                   { for sets, we can do this always }
                   (is_set(n.resultdef))
                   ) then
                  while (n.nodetype=TBinaryNode(n).left.nodetype) and
                    { if not both or none of the nodes is short/full boolean evaluated, we cannot do this optimization as it might change
                      semantics, there are border cases where this might not apply, but so far it is not worth the effort to check }
                    (not(is_boolean(n.resultdef)) or not(n.nodetype in [andn,orn]) or (doshortbooleval(n)=doshortbooleval(TBinaryNode(n).left))) and
                        { the resulttypes of the operands we'll swap must be equal,
                          required in case of a 32x32->64 multiplication, then we
                          cannot swap out one of the 32 bit operands for a 64 bit one
                        }
                        (TBinaryNode(TBinaryNode(n).left).left.resultdef=TBinaryNode(n).left.resultdef) and
                        (TBinaryNode(n).left.resultdef=TBinaryNode(n).right.resultdef) do
                    begin
                      csedomain:=true;
                      foreachnodestatic(pm_postprocess,TBinaryNode(n).right,@searchsubdomain,@csedomain);
                      if csedomain then
                        begin
                          csedomain:=true;
                          foreachnodestatic(pm_postprocess,TBinaryNode(TBinaryNode(n).left).right,@searchsubdomain,@csedomain);
                          if csedomain then
                            begin
                              {
                                move the full boolean evaluation of (2) to (1), if it was there (so it again applies to A and
                                what follows) }
                              { this cannot happen anymore, see above, so the condition is not needed anymore

                              if not(doshortbooleval(tbinarynode(n).left)) and
                                 doshortbooleval(n) then }
                                begin
                                  n.localswitches:=n.localswitches+(TBinaryNode(n).left.localswitches*[cs_full_boolean_eval]);
                                  exclude(TBinaryNode(n).left.localswitches,cs_full_boolean_eval);
                                  if (n.nodetype in [orn,andn]) then
                                    begin
                                      if (TBinaryNode(n).left.nodetype in [orn,andn]) then
                                        taddnode(TBinaryNode(n).left).addnodeflags:=taddnode(TBinaryNode(n).left).addnodeflags+
                                          (taddnode(n).addnodeflags*[anf_short_bool]);

                                      exclude(taddnode(n).addnodeflags,anf_short_bool);
                                    end;
                                end;

                              hp2:=TBinaryNode(TBinaryNode(n).left).left;
                              TBinaryNode(TBinaryNode(n).left).left:=TBinaryNode(TBinaryNode(n).left).right;
                              TBinaryNode(TBinaryNode(n).left).right:=TBinaryNode(n).right;
                              TBinaryNode(n).right:=TBinaryNode(n).left;
                              TBinaryNode(n).left:=hp2;

                              { the transformed tree could result in new possibilities to fold constants
                                so force a firstpass on the root node }
                              exclude(TBinaryNode(n).right.transientflags,tnf_pass1_done);
                              DoFirstPass(TBinaryNode(n).right);
                            end
                          else
                            break;
                        end
                      else
                        break;
                    end;
              end
            else
              begin
                statements:=nil;
                result:=fen_norecurse_true;
{$ifdef csedebug}
                writeln('============ cse domain ==================');
                printnode(output,n);
                writeln('Complexity: ',node_complexity(n));
{$endif csedebug}
                lists.nodelist:=tfplist.create;
                lists.locationlist:=tfplist.create;
                lists.equalto:=tfplist.create;
                lists.refs:=tfplist.create;
                foreachnodestatic(pm_postprocess,n,@collectnodes,@lists);

                templist:=tfplist.create;
                templist.count:=lists.nodelist.count;

                { check all nodes if one is used more than once }
                for i:=0 to lists.nodelist.count-1 do
                  begin
                    { current node used more than once? }
                    if assigned(lists.refs[i]) then
                      begin
                        if not(assigned(statements)) then
                          begin
                            nodes:=internalstatements(statements);
                            addstatement(statements,internalstatements(creates));
                          end;

                        def:=tstoreddef(TNode(lists.nodelist[i]).resultdef);
                        { we cannot handle register stored records or array in CSE yet
                          but we can store their reference }
                        addrstored:=((def.typ in [arraydef,recorddef]) or is_object(def)) and not(is_dynamic_array(def));

                        if addrstored then
                          templist[i]:=ctempcreatenode.create_value(cpointerdef.getreusable(def),voidpointertype.size,tt_persistent,
                            true,caddrnode.create_internal(TNode(lists.nodelist[i])))
                        else
                          templist[i]:=ctempcreatenode.create_value(def,def.size,tt_persistent,
                            def.is_intregable or def.is_fpuregable or def.is_const_intregable,TNode(lists.nodelist[i]));

                        { the value described by the temp. is immutable and the temp. can be always in register

                          ttempcreatenode.create normally takes care of the register location but it does not
                          know about immutability so it cannot take care of managed types }
                        ttempcreatenode(templist[i]).includetempflag(ti_const);
                        ttempcreatenode(templist[i]).includetempflag(ti_may_be_in_reg);

                        { make debugging easier and set temp. location to the original location }
                        TNode(templist[i]).fileinfo:=TNode(lists.nodelist[i]).fileinfo;

                        addstatement(creates,TNode(templist[i]));

                        { the delete node has no semantic use yet, it is just used to clean up memory }
                        deletetemp:=ctempdeletenode.create(ttempcreatenode(templist[i]));
                        deletetemp.includetempflag(ti_cleanup_only);
                        addstatement(tstatementnode(arg^),deletetemp);

                        { make debugging easier and set temp. location to the original location }
                        creates.fileinfo:=TNode(lists.nodelist[i]).fileinfo;

                        hp:=ttempcreatenode(templist[i]);
                        DoFirstPass(TNode(hp));
                        templist[i]:=hp;

                        if addrstored then
                          PNode(lists.locationlist[i])^:=cderefnode.Create(ctemprefnode.create(ttempcreatenode(templist[i])))
                        else
                          PNode(lists.locationlist[i])^:=ctemprefnode.create(ttempcreatenode(templist[i]));
                        { make debugging easier and set temp. location to the original location }
                        PNode(lists.locationlist[i])^.fileinfo:=TNode(lists.nodelist[i]).fileinfo;

                        DoFirstPass(PNode(lists.locationlist[i])^);
{$ifdef csedebug}
                        printnode(output,statements);
{$endif csedebug}
                      end
                    { current node reference to another node? }
                    else if lists.equalto[i]<>pointer(-1) then
                      begin
                        def:=tstoreddef(TNode(lists.nodelist[i]).resultdef);
                        { we cannot handle register stored records or array in CSE yet
                          but we can store their reference }
                        addrstored:=((def.typ in [arraydef,recorddef]) or is_object(def)) and not(is_dynamic_array(def));

{$if defined(csedebug) or defined(csestats)}
                        writeln;
                        writeln('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
                        writeln('Complexity: ',node_complexity(TNode(lists.nodelist[i])),'  Node ',i,' equals Node ',ptrint(lists.equalto[i]));
                        printnode(output,TNode(lists.nodelist[i]));
                        printnode(output,TNode(lists.nodelist[ptrint(lists.equalto[i])]));
                        writeln('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
                        writeln;
{$endif defined(csedebug) or defined(csestats)}
                        templist[i]:=templist[ptrint(lists.equalto[i])];
                        if addrstored then
                          PNode(lists.locationlist[i])^:=cderefnode.Create(ctemprefnode.create(ttempcreatenode(templist[ptrint(lists.equalto[i])])))
                        else
                          PNode(lists.locationlist[i])^:=ctemprefnode.create(ttempcreatenode(templist[ptrint(lists.equalto[i])]));

                        { make debugging easier and set temp. location to the original location }
                        PNode(lists.locationlist[i])^.fileinfo:=TNode(lists.nodelist[i]).fileinfo;

                        DoFirstPass(PNode(lists.locationlist[i])^);
                      end;
                  end;
                { clean up unused trees }
                for i:=0 to lists.nodelist.count-1 do
                  if lists.equalto[i]<>pointer(-1) then
                    TNode(lists.nodelist[i]).free; // no nil needed
{$ifdef csedebug}
                writeln('nodes: ',lists.nodelist.count);
                writeln('==========================================');
{$endif csedebug}
                FreeAndNil(lists.nodelist);
                FreeAndNil(lists.locationlist);
                FreeAndNil(lists.equalto);
                FreeAndNil(lists.refs);
                templist.free;
                templist := nil;

                if assigned(statements) then
                  begin
                    { call para nodes need a special handling because
                      they can be only children nodes of call nodes
                      so the initialization code is inserted below the
                      call para node
                    }
                    if n.nodetype=callparan then
                      begin
                        addstatement(statements,tcallparanode(n).left);
                        tcallparanode(n).left:=nodes;
                        DoFirstPass(tcallparanode(n).left);
                      end
                    else
                      begin
                        addstatement(statements,n);
                        n:=nodes;
                        DoFirstPass(n);
                      end;
{$ifdef csedebug}
                    printnode(output,nodes);
{$endif csedebug}
                  end;
              end
          end;
      end;


    function do_optcse(var rootnode : TNode) : TNode;
      var
        deletes,
        statements : tstatementnode;
        deleteblock,
        rootblock : tblocknode;
      begin
{$ifdef csedebug}
        writeln('====================================================================================');
        writeln('CSE optimization pass started');
        writeln('====================================================================================');
        printnode(output,rootnode);
        writeln('====================================================================================');
        writeln;
{$endif csedebug}
        deleteblock:=internalstatements(deletes);
        foreachnodestatic(pm_postprocess,rootnode,@searchcsedomain,@deletes);
        rootblock:=internalstatements(statements);
        addstatement(statements,rootnode);
        addstatement(statements,deleteblock);
        rootnode:=rootblock;
        DoFirstPass(rootnode);
{$ifdef csedebug}
        writeln('====================================================================================');
        writeln('CSE optimization result');
        writeln('====================================================================================');
        printnode(output,rootnode);
        writeln('====================================================================================');
        writeln;
{$endif csedebug}
        result:=nil;
      end;

    type
      tconstentry = record
        valuenode : TNode;
        weight : TCGInt;
        temp : ttempcreatenode;
      end;

      pconstentry = ^tconstentry;

      tconstentries = array of tconstentry;
      pconstentries = ^tconstentries;

    function CSEOnReference(n : TNode) : Boolean;
      begin
        Result:=(n.nodetype=loadn) and (tloadnode(n).symtableentry.typ=staticvarsym)
          and ((vo_is_thread_var in tstaticvarsym(tloadnode(n).symtableentry).varoptions) or
            (cs_create_pic in CurrentSettings.moduleswitches)
{$if defined(aarch64)}
            or (not(tabstractvarsym(tloadnode(n).symtableentry).is_regvar(false)))
{$endif defined(aarch64) or defined(sparc) or defined(sparc64)}
           );
      end;


    function collectconsts(var n:TNode; arg: pointer) : foreachnoderesult;
      var
        consts: pconstentries;
        found: Boolean;
        i: Integer;
      begin
        result:=fen_true;
        consts:=pconstentries(arg);
        if ((n.nodetype=realconstn)
{$ifdef x86}
          { x87 consts would end up in memory, so loading them in temps. makes no sense }
          and use_vectorfpu(n.resultdef)
{$endif x86}
          ) or
          CSEOnReference(n) then
          begin
            found:=false;
            i:=0;
            for i:=0 to High(consts^) do
              begin
                if TNode(consts^[i].valuenode).isequal(n) then
                  begin
                    found:=true;
                    break;
                  end;
              end;
            if found then
              begin
                inc(consts^[i].weight);

                { non-sectioned threadvars really hurt so do more aggressive cse on them }
                if not(tf_section_threadvars in TargetInfo.flags) and (n.nodetype=loadn) and (tloadnode(n).symtableentry.typ=staticvarsym) and (vo_is_thread_var in tstaticvarsym(tloadnode(n).symtableentry).varoptions) then
                  inc(consts^[i].weight);
              end
            else
              begin
                SetLength(consts^,length(consts^)+1);
                with consts^[high(consts^)] do
                  begin
                    valuenode:=n.getcopy;
                    valuenode.fileinfo:=CurrentProcInfo.entrypos;
                    weight:=1;
                  end;
              end;
          end;
      end;


    function replaceconsts(var n:TNode; arg: pointer) : foreachnoderesult;
      var
        hp: TNode;
      begin
        result:=fen_true;
        if TNode(pconstentry(arg)^.valuenode).isequal(n) then
          begin
            { shall we take the address? }
            if CSEOnReference(pconstentry(arg)^.valuenode) then
              begin
                hp:=ctypeconvnode.create_internal(cderefnode.create(ctemprefnode.create(pconstentry(arg)^.temp)),pconstentry(arg)^.valuenode.resultdef);
                ttypeconvnode(hp).left.fileinfo:=n.fileinfo;
              end
            else
              hp:=ctemprefnode.create(pconstentry(arg)^.temp);

            hp.fileinfo:=n.fileinfo;
            n.Free;
            n:=hp;
            DoFirstPass(n);
          end;
       end;


    function do_consttovar(var rootnode : TNode) : TNode;
      var
        constentries : tconstentries;
      Procedure QuickSort(L, R : Longint);
        var
          I, J, P: Longint;
          Item, Q : tconstentry;
        begin
         repeat
           I := L;
           J := R;
           P := (L + R) div 2;
           repeat
             Item := constentries[P];
             while Item.weight>constentries[I].weight do
               I := I + 1;
             while Item.weight<constentries[J].weight do
               J := J - 1;
             If I <= J then
             begin
               Q := constentries[I];
               constentries[I] := constentries[J];
               constentries[J] := Q;
               if P = I then
                P := J
               else if P = J then
                P := I;
               I := I + 1;
               J := J - 1;
             end;
           until I > J;
           if L < J then
             QuickSort(L, J);
           L := I;
         until I >= R;
        end;

      var
        creates,
        deletes,
        statements : tstatementnode;
        createblock,
        deleteblock,
        rootblock : tblocknode;
        i, max_fpu_regs_assigned, fpu_regs_assigned,
        max_int_regs_assigned, int_regs_assigned: Integer;
        old_current_filepos: TFilePosInfo;
      begin
  {$ifdef csedebug}
        writeln('====================================================================================');
        writeln('Const optimization pass started');
        writeln('====================================================================================');
        printnode(output,rootnode);
        writeln('====================================================================================');
        writeln;
  {$endif csedebug}
        foreachnodestatic(pm_postprocess,rootnode,@collectconsts,@constentries);
        createblock:=nil;
        deleteblock:=nil;
        rootblock:=nil;
        { estimate how many int registers can be used }
        if pi_do_call in CurrentProcInfo.flags then
          max_int_regs_assigned:=length(paramanager.get_saved_registers_int(CurrentProcInfo.procdef.proccalloption))
          { we store only addresses, so take care of the relation between address sizes and register sizes }
            div max(sizeof(PtrUInt) div sizeof(ALUUInt),1)
          { heuristics, just use a quarter of all registers at maximum }
            div 4
        else
          max_int_regs_assigned:=max(first_int_imreg div 4,1);
{$if defined(x86) or defined(aarch64)}
        { x86, aarch64 and arm (neglecting fpa) use mm registers for floats }
        if pi_do_call in CurrentProcInfo.flags then
          { heuristics, just use a fifth of all registers at maximum }
          max_fpu_regs_assigned:=length(paramanager.get_saved_registers_mm(CurrentProcInfo.procdef.proccalloption)) div 5
        else
          max_fpu_regs_assigned:=max(first_mm_imreg div 5,1);
{$else defined(x86) or defined(aarch64) or defined(arm)}
        if pi_do_call in CurrentProcInfo.flags then
          { heuristics, just use a fifth of all registers at maximum }
          max_fpu_regs_assigned:=length(paramanager.get_saved_registers_fpu(CurrentProcInfo.procdef.proccalloption)) div 5
        else
          max_fpu_regs_assigned:=max(first_fpu_imreg div 5,1);
{$endif}
        fpu_regs_assigned:=0;
        int_regs_assigned:=0;
        if Length(constentries)>0 then
          begin
            { sort entries by weight }
            QuickSort(0,High(constentries));
            { assign only the constants with the highest weight to a register }
            for i:=High(constentries) downto 0 do
              begin
                if (constentries[i].valuenode.nodetype=realconstn) and
                   { if there is a call, we need most likely to save/restore a register }
                  ((constentries[i].weight>3) or
                  ((constentries[i].weight>1) and not(pi_do_call in CurrentProcInfo.flags)))
                then
                  begin
                    if fpu_regs_assigned>=max_fpu_regs_assigned then
                      break;
                    old_current_filepos:=CurrentFilePos;
                    CurrentFilePos:=CurrentProcInfo.entrypos;
                    if not(assigned(createblock)) then
                      begin
                        rootblock:=internalstatements(statements);
                        createblock:=internalstatements(creates);
                        deleteblock:=internalstatements(deletes);
                      end;
                     constentries[i].temp:=ctempcreatenode.create(constentries[i].valuenode.resultdef,
                       constentries[i].valuenode.resultdef.size,tt_persistent,true);
                     addstatement(creates,constentries[i].temp);
                     addstatement(creates,cassignmentnode.create_internal(ctemprefnode.create(constentries[i].temp),constentries[i].valuenode));
                     CurrentFilePos:=old_current_filepos;
                     foreachnodestatic(pm_postprocess,rootnode,@replaceconsts,@constentries[i]);
                     inc(fpu_regs_assigned);
                  end
                else if CSEOnReference(constentries[i].valuenode) and
                   { if there is a call, we need most likely to save/restore a register }
                  ((constentries[i].weight>2) or
                  ((constentries[i].weight>1) and not(pi_do_call in CurrentProcInfo.flags)))
                then
                  begin
                    if int_regs_assigned>=max_int_regs_assigned then
                      break;
                    old_current_filepos:=CurrentFilePos;
                    CurrentFilePos:=CurrentProcInfo.entrypos;
                    if not(assigned(createblock)) then
                      begin
                        rootblock:=internalstatements(statements);
                        createblock:=internalstatements(creates);
                        deleteblock:=internalstatements(deletes);
                      end;
                     constentries[i].temp:=ctempcreatenode.create(cpointerdef.getreusable(constentries[i].valuenode.resultdef),
                       voidpointertype.size,tt_persistent,true);
                     addstatement(creates,constentries[i].temp);
                     addstatement(creates,cassignmentnode.create_internal(ctemprefnode.create(constentries[i].temp),
                       caddrnode.create_internal(constentries[i].valuenode)));
                     CurrentFilePos:=old_current_filepos;
                     foreachnodestatic(pm_postprocess,rootnode,@replaceconsts,@constentries[i]);
                     inc(int_regs_assigned);
                  end;
              end;
          end;
        if assigned(createblock) then
          begin
            addstatement(statements,createblock);
            addstatement(statements,rootnode);
            addstatement(statements,deleteblock);
            rootnode:=rootblock;
            DoFirstPass(rootnode);
          end;
  {$ifdef csedebug}
        writeln('====================================================================================');
        writeln('Const optimization result');
        writeln('====================================================================================');
        printnode(output,rootnode);
        writeln('====================================================================================');
        writeln;
  {$endif csedebug}
        result:=nil;
      end;

end.
