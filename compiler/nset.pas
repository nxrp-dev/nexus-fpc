{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Type checking and register allocation for set/case nodes

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
unit nset;

{$i fpcdefs.inc}

interface

    uses
       SysUtils,CClasses,ConstExp,
       node,GlobType,Globals,
       aasmbase,ncon,nflw,symtype;

    type
       TLabelType = (ltOrdinal, ltConstString);

       PCaseLabel = ^TCaseLabel;
       TCaseLabel = record
          { unique blockid }
          blockid : LongInt;
          { left and right tree node }
          less,
          greater : PCaseLabel;

          labellabel : TAsmLabel;

          { range type }
          case label_type : TLabelType of
            ltOrdinal:
            (
              _low,
              _high       : TConstExprInt;
            );
            ltConstString:
            (
              _low_str,
              _high_str   : TStringConstNode;
            );
       end;

       PCaseBlock = ^TCaseBlock;
       TCaseBlock = record
          { label (only used in pass_generate_code) }
          blocklabel : TAsmLabel;

          { shortcut - set to true if blocklabel isn't actually unique to the
            case block due to one of the following conditions:
            - if the node contains a jump, then the label is set to that jump's destination,
            - if the node is empty, the label is set to the end label. }
          shortcut: Boolean;

          statementlabel : TLabelNode;
          { instructions }
          statement  : TNode;
       end;

       TSetElementNode = class(TBinaryNode)
          constructor create(l,r : TNode);virtual;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
       end;
       TSetElementNodeClass = class of TSetElementNode;

       TInNode = class(TBinOpNode)
          constructor create(l,r : TNode);virtual;reintroduce;
          function pass_typecheck:TNode;override;
          function simplify(forinline : boolean):TNode;override;
          function pass_1 : TNode;override;
       end;
       TInNodeClass = class of TInNode;

       TRangeNode = class(TBinaryNode)
          constructor create(l,r : TNode);virtual;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
       end;
       TRangeNodeClass = class of TRangeNode;

       TCaseNode = class(TUnaryNode)
        strict private
          { Number of labels }
          flabelcnt: cardinal;
          { Number of individual values checked, counting each value in a range
           individually (e.g. 0..2 counts as 3). }
          flabelcoverage: qword;
          fcountsuptodate: boolean;

          function getlabelcnt: cardinal;
          function getlabelcoverage: qword;
          procedure updatecoverage;
          procedure checkordinalcoverage;
        public
          blocks    : TFPList;
          elseblock : TNode;

          constructor create(l:TNode);virtual;
          destructor Destroy;override;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure derefimpl;override;
          function dogetcopy : TNode;override;
          procedure printnodetree(var t:text);override;
          procedure insertintolist(l : TNodeList);override;
          function pass_typecheck:TNode;override;
          function pass_1 : TNode;override;
          function simplify(forinline:boolean):TNode;override;
          function docompare(p: TNode): boolean; override;
          procedure addlabel(blockid:LongInt;const l,h : TConstExprInt); overload;
          procedure addlabel(blockid:LongInt;l,h : TStringConstNode); overload;
          procedure addblock(blockid:LongInt;instr:TNode);
          procedure addelseblock(instr:TNode);

          property labelcnt: cardinal read getlabelcnt;
          { returns one less than the covered case range, so that it
            does not overflow for a fully covered qword range }
          property labelcoverage: qword read getlabelcoverage;
         protected
          flabels    : PCaseLabel;
         public
          property labels: PCaseLabel read flabels;
       end;
       TCaseNodeClass = class of TCaseNode;

    var
       CSetElementNode : TSetElementNodeClass = TSetElementNode;
       CInNode : TInNodeClass = TInNode;
       CRangeNode : TRangeNodeClass = TRangeNode;
       CCaseNode : TCaseNodeClass = TCaseNode;

    { searches the highest label }
    function case_get_max(root : PCaseLabel) : TConstExprInt;
    { searches the lowest label }
    function case_get_min(root : PCaseLabel) : TConstExprInt;


implementation

    uses
      Verbose,CUtils,
      symconst,symdef,SymSym,SymTable,defutil,defcmp,
      htypechk,pass_1,
      nadd,nbas,ncal,ncnv,nld,nutils,
      cgbase;


{*****************************************************************************
                           TSETELEMENTNODE
*****************************************************************************}

    constructor TSetElementNode.create(l,r : TNode);

      begin
         inherited create(setelementn,l,r);
      end;


    function TSetElementNode.pass_typecheck:TNode;
      begin
         result:=nil;
         TypeCheckPass(left);
         if Assigned(right) then
          TypeCheckPass(right);
         set_varstate(left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
          exit;

         resultdef:=left.resultdef;
      end;


    function TSetElementNode.pass_1 : TNode;

      begin
         result:=nil;
         FirstPass(left);
         if Assigned(right) then
          FirstPass(right);
         if CodeGenError then
          exit;

         expectloc:=left.expectloc;
      end;


{*****************************************************************************
                              TINNODE
*****************************************************************************}

    constructor TInNode.create(l,r : TNode);
      begin
         inherited create(inn,l,r);
      end;


    function TInNode.pass_typecheck:TNode;

      var
        t : TNode;

        function createsetconst(psd : TSetDef) : PConstSet;
        var
          pcs : PConstSet;
          i : LongInt;
        begin
          new(pcs);
          case psd.ElementDef.typ of
            enumdef :
              begin
                for i := 0 to TEnumDef(psd.ElementDef).SymTable.SymList.Count - 1 do
                  begin
                    include(pcs^,TEnumSym(TEnumDef(psd.ElementDef).SymTable.SymList[i]).Value);
                  end;
              end;
            orddef :
              begin
                for i:=int64(TOrdDef(psd.ElementDef).low) to int64(TOrdDef(psd.ElementDef).high) do
                  include(pcs^,i);
              end;
            else
              InternalError(2019050516);
          end;
          createsetconst:=pcs;
        end;

      begin
         result:=nil;

         resultdef:=PasBool1Type;
         TypeCheckPass(right);
         set_varstate(right,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
          exit;

         { Convert array constructor first to set }
         if Is_Array_Constructor(right.resultdef) then
          begin
            arrayconstructor_to_set(right);
            if CodeGenError then
             exit;
          end;

         TypeCheckPass(left);
         set_varstate(left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         if not Assigned(left.resultdef) then
           InternalError(20021126);

         { avoid any problems with type parameters later on }
         if Is_TypeParam(left.resultdef) or Is_TypeParam(right.resultdef) then
           begin
             resultdef:=CUndefinedType;
             exit;
           end;

         t:=self;
         if isbinaryoverloaded(t,[]) then
           begin
             result:=t;
             exit;
           end;

         if right.resultdef.typ<>setdef then
           CGMessage(sym_e_set_expected);

         if CodeGenError then
           exit;

         if not Is_Ordinal(left.resultdef) or (left.resultdef.Size > U32IntType.Size) then
           begin
             CGMessage(type_h_in_range_check);
             if Is_Signed(left.resultdef) then
               inserttypeconv(left,S32IntType)
             else
               inserttypeconv(left,U32IntType);
           end
         else if Assigned(TSetDef(right.resultdef).ElementDef) and
                 not(Is_Integer(TSetDef(right.resultdef).ElementDef) and
                     Is_Integer(left.resultdef)) then
            { Type conversion to check things like 'char in set_of_byte'. }
            { Can't use is_subequal because that will fail for            }
            { 'widechar in set_of_char'                                   }
            { Can't use the type conversion for integers because then     }
            { "longint in set_of_byte" will give a range check error      }
            { instead of false                                            }
            inserttypeconv(left,TSetDef(right.resultdef).ElementDef);

         { empty set then return false }
         if not Assigned(TSetDef(right.resultdef).ElementDef) or
            ((right.nodetype = setconstn) and
             (TNormalSet(TSetConstNode(right).value_set^) = [])) then
          begin
            t:=COrdConstNode.create(0,PasBool1Type,false);
            TypeCheckPass(t);
            result:=t;
            exit;
          end;

         result:=simplify(false);
      end;


    function TInNode.simplify(forinline : boolean):TNode;
      var
        t : TNode;
      begin
         result:=nil;

         { constant evaluation }
         if (left.nodetype=ordconstn) then
           begin
             if (right.nodetype=setconstn) then
               begin
                 { tordconstnode.value is int64 -> signed -> the expression }
                 { below will be converted to longint on 32 bit systems due }
                 { to the rule above -> will give range check error if      }
                 { value > high(longint) if we don't take the signedness    }
                 { into account                                             }
                 if TOrdConstNode(left).Value.signed then
                   t:=COrdConstNode.create(byte(TOrdConstNode(left).Value.svalue in TSetConstNode(right).value_set^),
                     PasBool1Type,true)
                 else
                   t:=COrdConstNode.create(byte(TOrdConstNode(left).Value.uvalue in TSetConstNode(right).value_set^),
                     PasBool1Type,true);
                 TypeCheckPass(t);
                 result:=t;
                 exit;
               end
             else
               begin
                 if (TOrdConstNode(left).Value<int64(TSetDef(right.resultdef).SetBase)) or
                    (TOrdConstNode(left).Value>int64(TSetDef(right.resultdef).SetMax)) then
                   begin
                     t:=COrdConstNode.create(0, PasBool1Type, true);
                     TypeCheckPass(t);
                     result:=t;
                     exit;
                   end;
               end;
           end
         { a in [a] => true, if a has no side effects }
         else if (right.nodetype=addn) and
           (TAddNode(right).left.nodetype=setconstn) and
           (TSetConstNode(TAddNode(right).left).elements=0) and
           (TAddNode(right).right.nodetype=setelementn) and
           (TSetElementNode(TAddNode(right).right).right=nil) and
           ((TSetElementNode(TAddNode(right).right).left.isequal(left)) or
            (
              (TSetElementNode(TAddNode(right).right).left.nodetype=typeconvn) and
              (TTypeConvNode(TSetElementNode(TAddNode(right).right).left).left.isequal(left))
            )
           ) and
           not(might_have_sideeffects(left,[mhs_exceptions])) then
           begin
             t:=COrdConstNode.create(1, PasBool1Type, true);
             TypeCheckPass(t);
             result:=t;
             exit;
           end
         { ... in [] is always false }
         else if is_emptyset(right) and
           not(might_have_sideeffects(left,[mhs_exceptions])) then
           begin
             t:=COrdConstNode.create(1, PasBool1Type, false);
             TypeCheckPass(t);
             result:=t;
             exit;
           end;
      end;


    function TInNode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_REGISTER;

         FirstPass(right);
         FirstPass(left);
         if CodeGenError then
           exit;
      end;


{*****************************************************************************
                              TRANGENODE
*****************************************************************************}

    constructor TRangeNode.create(l,r : TNode);
      var
        value: string;
      begin
         { if right is char and left is string then
           right should be treated as one-symbol string }
         if is_conststringnode(l) and is_constcharnode(r) then
           begin
             value := char(TOrdConstNode(r).Value.uvalue) + ''#0;
             r.free;
             r := CStringConstNode.createstr(value);
             DoTypeCheckPass(r);
           end;
         inherited create(rangen,l,r);
      end;


    function TRangeNode.pass_typecheck : TNode;
      begin
         result:=nil;
         TypeCheckPass(left);
         TypeCheckPass(right);
         set_varstate(left,vs_read,[vsf_must_be_valid]);
         set_varstate(right,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;
         { both types must be compatible }
         if not (nf_generic_para in left.flags) and not (nf_generic_para in right.flags) and
           (Compare_Defs(left.resultdef,right.resultdef,left.nodetype)=te_incompatible) then
           IncompatibleTypes(left.resultdef,right.resultdef);
         { check if only when its a constant set and
           ignore range nodes which are generic parameter derived }
         if not (nf_generic_para in flags) and (left.nodetype=ordconstn) and (right.nodetype=ordconstn) then
          begin
            { upper limit must be greater or equal than lower limit }
            if (TOrdConstNode(left).Value>TOrdConstNode(right).Value) and
               ((TOrdConstNode(left).Value<0) or (TOrdConstNode(right).Value>=0)) then
              CGMessage(parser_e_upper_lower_than_lower);
          end;
        resultdef:=left.resultdef;
      end;


    function TRangeNode.pass_1 : TNode;
      begin
         result:=nil;
         FirstPass(left);
         FirstPass(right);
         if CodeGenError then
           exit;
        expectloc:=left.expectloc;
      end;


{*****************************************************************************
                              Case Helpers
*****************************************************************************}

    { labels is the number of case-labels, while cases includes each individual
      value in a range (e.g. "0..2" counts as 3) }
    procedure case_count_labels(root : PCaseLabel; out labels, cases: LongInt);

      procedure count(p : PCaseLabel);
        begin
           inc(labels);
           inc(cases, (p^._high.svalue - p^._low.svalue) + 1);
           if Assigned(p^.less) then
             count(p^.less);
           if Assigned(p^.greater) then
             count(p^.greater);
        end;

      begin
        labels:=0;
        cases:=0;
        count(root);
      end;


    function case_get_max(root : PCaseLabel) : TConstExprInt;
      var
         hp : PCaseLabel;
      begin
         hp:=root;
         while Assigned(hp^.greater) do
           hp:=hp^.greater;
         case_get_max:=hp^._high;
      end;


    function case_get_min(root : PCaseLabel) : TConstExprInt;
      var
         hp : PCaseLabel;
      begin
         hp:=root;
         while Assigned(hp^.less) do
           hp:=hp^.less;
         case_get_min:=hp^._low;
      end;

    procedure deletecaselabels(p : PCaseLabel);

      begin
         if Assigned(p^.greater) then
           deletecaselabels(p^.greater);
         if Assigned(p^.less) then
           deletecaselabels(p^.less);
         if (p^.label_type = ltConstString) then
           begin
             FreeAndNil(p^._low_str);
             FreeAndNil(p^._high_str);
           end;
         dispose(p);
      end;

    function copycaselabel(p : PCaseLabel) : PCaseLabel;

      var
         n : PCaseLabel;

      begin
         new(n);
         n^:=p^;
         if (p^.label_type = ltConstString) then
           begin
             n^._low_str := TStringConstNode(p^._low_str.GetCopy);
             n^._high_str := TStringConstNode(p^._high_str.GetCopy);
           end;
         if Assigned(p^.greater) then
           n^.greater:=copycaselabel(p^.greater);
         if Assigned(p^.less) then
           n^.less:=copycaselabel(p^.less);
         copycaselabel:=n;
      end;


    procedure ppuwritecaselabel(ppufile:TCompilerPPUFile;p : PCaseLabel);
      var
        b : byte;
      begin
        ppufile.PutBoolean(p^.label_type = ltConstString);
        if (p^.label_type = ltConstString) then
          begin
            p^._low_str.ppuwrite(ppufile);
            p^._high_str.ppuwrite(ppufile);
          end
        else
          begin
            ppufile.PutExprInt(p^._low);
            ppufile.PutExprInt(p^._high);
          end;

        ppufile.PutLongInt(p^.blockid);
        b:=ord(Assigned(p^.greater)) or (ord(Assigned(p^.less)) shl 1);
        ppufile.PutByte(b);
        if Assigned(p^.greater) then
          ppuwritecaselabel(ppufile,p^.greater);
        if Assigned(p^.less) then
          ppuwritecaselabel(ppufile,p^.less);
      end;


    function ppuloadcaselabel(ppufile:TCompilerPPUFile):PCaseLabel;
      var
        b : byte;
        p : PCaseLabel;
      begin
        new(p);
        if ppufile.GetBoolean then
          begin
            p^.label_type := ltConstString;
            p^._low_str := CStringConstNode.ppuload(stringconstn,ppufile);
            p^._high_str := CStringConstNode.ppuload(stringconstn,ppufile);
          end
        else
          begin
            p^.label_type := ltOrdinal;

            p^._low:=ppufile.GetExprInt;
            p^._high:=ppufile.GetExprInt;
          end;

        p^.blockid:=ppufile.GetLongInt;
        b:=ppufile.GetByte;
        if (b and 1)=1 then
         p^.greater:=ppuloadcaselabel(ppufile)
        else
         p^.greater:=nil;
        if (b and 2)=2 then
         p^.less:=ppuloadcaselabel(ppufile)
        else
         p^.less:=nil;
        ppuloadcaselabel:=p;
      end;


{*****************************************************************************
                              TCASENODE
*****************************************************************************}

    constructor TCaseNode.create(l:TNode);
      begin
         inherited create(casen,l);
         flabels:=nil;
         blocks:=TFPList.create;
         elseblock:=nil;
      end;


    destructor TCaseNode.Destroy;
      var
        i : LongInt;
        hp : PCaseBlock;
      begin
         elseblock.free;
         elseblock := nil;
         deletecaselabels(flabels);
         for i:=0 to blocks.count-1 do
           begin
             FreeAndNil(PCaseBlock(blocks[i])^.statement);
             hp:=PCaseBlock(blocks[i]);
             dispose(hp);
           end;
         blocks.free;
         blocks := nil;
         inherited Destroy;
      end;


    constructor TCaseNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      var
        cnt,i : LongInt;
      begin
        inherited ppuload(t,ppufile);
        elseblock:=ppuloadnode(ppufile);
        cnt:=ppufile.GetLongInt();
        blocks:=TFPList.create;
        for i:=0 to cnt-1 do
          addblock(i,ppuloadnode(ppufile));
        flabels:=ppuloadcaselabel(ppufile);
        { we don't save/restore the label counts, but recalculate them if needed }
        fcountsuptodate:=false;
      end;


    procedure TCaseNode.ppuwrite(ppufile:TCompilerPPUFile);
      var
        i : LongInt;
      begin
        inherited ppuwrite(ppufile);
        ppuwritenode(ppufile,elseblock);
        ppufile.PutLongInt(blocks.count);
        for i:=0 to blocks.count-1 do
          ppuwritenode(ppufile,PCaseBlock(blocks[i])^.statement);
        ppuwritecaselabel(ppufile,flabels);
        { we don't save/restore the label counts, but recalculate them if needed }
      end;


    procedure TCaseNode.BuildDerefImpl;
      var
        i : integer;
      begin
        inherited BuildDerefImpl;
        if Assigned(elseblock) then
          elseblock.BuildDerefImpl;
        for i:=0 to blocks.count-1 do
          PCaseBlock(blocks[i])^.statement.BuildDerefImpl;
      end;


    procedure TCaseNode.derefimpl;
      var
        i : integer;
      begin
        inherited derefimpl;
        if Assigned(elseblock) then
          elseblock.derefimpl;
        for i:=0 to blocks.count-1 do
          PCaseBlock(blocks[i])^.statement.derefimpl;
      end;


    function TCaseNode.pass_typecheck : TNode;
      var
        i : integer;
      begin
        result:=nil;

        DoTypeCheckPass(left);

        for i:=0 to blocks.count-1 do
          TypeCheckPass(PCaseBlock(blocks[i])^.statement);

        if Assigned(elseblock) then
          TypeCheckPass(elseblock);

        resultdef:=VoidType;
        result:=simplify(false);
      end;


    type
      TLinkedListCaseLabelItem = class(TLinkedListItem)
        casenode: PCaseLabel;
        constructor create(c: PCaseLabel);
      end;

    constructor TLinkedListCaseLabelItem.create(c: PCaseLabel);
      begin
        inherited create;
        casenode:=c;
      end;


    function TCaseNode.pass_1 : TNode;
      var
         i: integer;
         node_thenblock, node_elseblock, if_node,temp_cleanup : TNode;
         tempcaseexpr : TTempCreateNode;
         if_block, init_block: TBlockNode;
         stmt: TStatementNode;

      procedure add_label_to_blockid_list(list: TFPObjectList; lab: PCaseLabel);
        begin
          if not Assigned(lab) then
            exit;
          if not Assigned(list[lab^.blockid]) then
            list[lab^.blockid]:=TFPObjectList.create(true);
          TFPObjectList(list[lab^.blockid]).add(TLinkedListCaseLabelItem.create(lab));
          add_label_to_blockid_list(list,lab^.less);
          add_label_to_blockid_list(list,lab^.greater);
        end;

      function order_labels_by_blockid: TFPObjectList;
        begin
          result:=TFPObjectList.create(true);
          result.count:=blocks.count;
          add_label_to_blockid_list(result,flabels);
        end;

      function makeifblock(elseblock : TNode): TNode;
        var
          i, j: LongInt;
          check: TAddNode;
          newcheck: ^TAddNode;
          blocklist, lablist: TFPObjectList;
          labitem: PCaseLabel;
        begin
          result:=elseblock;
          blocklist:=order_labels_by_blockid;
          { in reverse order so that the case options at the start of the case
            statement are evaluated first, as they presumably are the most
            common }
          for i:=blocklist.count-1 downto 0 do
            begin
              lablist:=TFPObjectList(blocklist[i]);
              check:=nil;
              for j:=0 to lablist.count-1 do
                begin
                  if Assigned(check) then
                    begin
                      check:=CAddNode.create(orn,check,nil);
                      newcheck:=@check.right
                    end
                  else
                    newcheck:=@check;
                  labitem:=TLinkedListCaseLabelItem(lablist[j]).casenode;
                  newcheck^:=CAddNode.create(EqualN,left.GetCopy,labitem^._low_str.GetCopy);
                  if (labitem^._low_str.fullcompare(labitem^._high_str)<>0) then
                    begin
                      newcheck^.nodetype:=gten;
                      newcheck^:=CAddNode.create(
                        andn,newcheck^,CAddNode.create(
                          lten,left.GetCopy,labitem^._high_str.GetCopy));
                    end;
                end;
              result:=CIfNode.create(check,
                PCaseBlock(blocks[i])^.statement,result);
              PCaseBlock(blocks[i])^.statement:=nil;
            end;
          { will free its elements too because of create(true) }
          blocklist.free;
          blocklist := nil;
          TypeCheckPass(result);
        end;

      begin
         result:=nil;
         init_block:=nil;
         temp_cleanup:=nil;
         expectloc:=LOC_VOID;

         { only do in pass_1, so that simplify can run first and
             1) possibly simplify the case node without triggering a warning
             2) possibly give a compile-time error if not all cases are handled
                in ISO/Extended Pascal mode }
         if Is_Ordinal(left.resultdef) then
           checkordinalcoverage;

         { ideally this would be in simplify, but then checkordinalcoverage can
           false positives about case statements not handling all cases }
         if Assigned(elseblock) and
            has_no_code(elseblock) then
           begin
             elseblock.free;
             elseblock:=nil;
           end;

         { evaluates the case expression }
         FirstPass(left);
         set_varstate(left,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         { Load caseexpr into temp var if complex. }
         { No need to do this for ordinal, because }
         { in that case caseexpr is generated once }
         if (flabels^.label_type = ltConstString) and (not valid_for_addr(left, false)) and
           (blocks.count > 0) then
           begin
             init_block := internalstatements(stmt);
             tempcaseexpr :=
               CTempCreateNode.create(
                 left.resultdef, left.resultdef.Size, tt_persistent, true);
             temp_cleanup := CTempDeleteNode.create(tempcaseexpr);
             TypeCheckPass(TNode(tempcaseexpr));

             addstatement(stmt, tempcaseexpr);
             addstatement(
               stmt, CAssignmentNode.create(
                 CTempRefNode.create(tempcaseexpr), left));

             left := CTempRefNode.create(tempcaseexpr);
             TypeCheckPass(left);
           end;

         { first case }
         for i:=0 to blocks.count-1 do
           FirstPass(PCaseBlock(blocks[i])^.statement);

         { may be handle else tree }
         if Assigned(elseblock) then
           begin
             FirstPass(elseblock);

             { kill case? }
             if blocks.count=0 then
               begin
                 result:=elseblock;
                 elseblock:=nil;
                 exit;
               end;
           end
         else
           if blocks.count=0 then
             begin
               result:=CNothingNode.create;
               exit;
             end;

         if (flabels^.label_type = ltConstString) then
           begin
             if_node:=makeifblock(elseblock);

             if Assigned(init_block) then
               FirstPass(TNode(init_block));

             if_block:=internalstatements(stmt);

             if Assigned(init_block) then
               addstatement(stmt, init_block);
             addstatement(stmt,if_node);
             if Assigned(temp_cleanup) then
               addstatement(stmt,temp_cleanup);
             result:=if_block;
             elseblock:= nil;
             exit;
           end;

         if Is_Boolean(left.resultdef) then
           begin
             case blocks.count of
               2:
                 begin
                   if boolean(qword(flabels^._low))=false then
                     begin
                       node_thenblock:=PCaseBlock(blocks[flabels^.greater^.blockid])^.statement;
                       node_elseblock:=PCaseBlock(blocks[flabels^.blockid])^.statement;
                       PCaseBlock(blocks[flabels^.greater^.blockid])^.statement:=nil;
                     end
                   else
                     begin
                       node_thenblock:=PCaseBlock(blocks[flabels^.blockid])^.statement;
                       node_elseblock:=PCaseBlock(blocks[flabels^.less^.blockid])^.statement;
                       PCaseBlock(blocks[flabels^.less^.blockid])^.statement:=nil;
                     end;
                   PCaseBlock(blocks[flabels^.blockid])^.statement:=nil;
                 end;
               1:
                 begin
                   if flabels^._low=flabels^._high then
                     begin
                       if boolean(qword(flabels^._low))=false then
                         begin
                           node_thenblock:=elseblock;
                           node_elseblock:=PCaseBlock(blocks[flabels^.blockid])^.statement;
                         end
                       else
                         begin
                           node_thenblock:=PCaseBlock(blocks[flabels^.blockid])^.statement;
                           node_elseblock:=elseblock;
                         end;
                       PCaseBlock(blocks[flabels^.blockid])^.statement:=nil;
                       elseblock:=nil;
                     end
                   else
                     begin
                       result:=PCaseBlock(blocks[flabels^.blockid])^.statement;
                       PCaseBlock(blocks[flabels^.blockid])^.statement:=nil;
                       elseblock:=nil;
                       exit;
                     end;
                 end;
             else
               InternalError(200805031);
           end;
           result:=CIfNode.create(left,node_thenblock,node_elseblock);
           left:=nil;
           exit;
         end;
       { convert single case branch into if-statement }
       if (flabels^.greater=nil) and (flabels^.less=nil) then
         if flabels^.label_type=ltOrdinal then
           begin
             if flabels^._low=flabels^._high then
               begin
                 result:=CIfNode.Create_Internal(
                   CAddNode.Create_Internal(EqualN,left.GetCopy,COrdConstNode.create(flabels^._low,left.resultdef,false)),
                   PCaseBlock(blocks[flabels^.blockid])^.statement,elseblock);
               end
             else if not(might_have_sideeffects(left,[mhs_exceptions])) and (node_complexity(left)<=1) then
               begin
                 result:=CIfNode.Create_Internal(
                   CAddNode.Create_Internal(andn,
                     CAddNode.Create_Internal(gten,left.GetCopy,COrdConstNode.create(flabels^._low,left.resultdef,false)),
                     CAddNode.Create_Internal(lten,left.GetCopy,COrdConstNode.create(flabels^._high,left.resultdef,false))
                   ),
                   PCaseBlock(blocks[flabels^.blockid])^.statement,elseblock);
               end
             else
               begin
                 init_block:=internalstatements(stmt);
                 tempcaseexpr:=CTempCreateNode.create(
                   left.resultdef,left.resultdef.Size,tt_persistent,true);
                 temp_cleanup:=CTempDeleteNode.create(tempcaseexpr);
                 TypeCheckPass(TNode(tempcaseexpr));

                 addstatement(stmt,tempcaseexpr);
                 addstatement(stmt,CAssignmentNode.create(
                   CTempRefNode.create(tempcaseexpr),left.GetCopy));

                 left:=CTempRefNode.create(tempcaseexpr);
                 TypeCheckPass(left);

                 addstatement(stmt,CIfNode.Create_Internal(
                   CAddNode.Create_Internal(andn,
                     CAddNode.Create_Internal(gten,left.GetCopy,COrdConstNode.create(flabels^._low,left.resultdef,false)),
                     CAddNode.Create_Internal(lten,left.GetCopy,COrdConstNode.create(flabels^._high,left.resultdef,false))
                   ),
                   PCaseBlock(blocks[flabels^.blockid])^.statement,elseblock));
                 addstatement(stmt,temp_cleanup);
                 result:=init_block;
               end;
             elseblock:=nil;
             PCaseBlock(blocks[flabels^.blockid])^.statement:=nil;
             exit;
           end;
        end;


    function TCaseNode.simplify(forinline:boolean):TNode;
      var
        tmp: PCaseLabel;
      begin
        result:=nil;
        if left.nodetype=ordconstn then
          begin
            tmp:=flabels;
            { check all case labels until we find one that fits }
            while Assigned(tmp) do
              begin
                if (tmp^._low<=TOrdConstNode(left).Value) and
                    (tmp^._high>=TOrdConstNode(left).Value) then
                  begin
                    if tmp^.blockid>=blocks.count then
                      InternalError(2014022101);
                    result:=PCaseBlock(blocks[tmp^.blockid])^.statement;
                    if not Assigned(result) then
                      InternalError(2014022102);
                    result:=result.GetCopy;
                    exit;
                  end;

                if tmp^._high<TOrdConstNode(left).Value then
                  tmp:=tmp^.greater
                else
                  tmp:=tmp^.less;
              end;
            { no label did match; use the else block if available }
            if Assigned(elseblock) then
              result:=elseblock.GetCopy
            else
              begin
                if ([m_iso,m_extpas]*CurrentSettings.ModeSwitches)<>[] then
                  CGMessage1(cg_e_case_missing_value,ToStr(TOrdConstNode(left).Value))
                else
                  CGMessage(cg_w_case_incomplete);
                { no else block, so there is no code to execute at all }
                result:=CNothingNode.create;
              end;
          end;
      end;


    function TCaseNode.dogetcopy : TNode;
      var
         n : TCaseNode;
         i : LongInt;
      begin
         n:=TCaseNode(inherited dogetcopy);
         if Assigned(elseblock) then
           n.elseblock:=elseblock.dogetcopy
         else
           n.elseblock:=nil;
         if Assigned(flabels) then
           n.flabels:=copycaselabel(flabels)
         else
           n.flabels:=nil;
         if Assigned(blocks) then
           begin
             n.blocks:=TFPList.create;
             for i:=0 to blocks.count-1 do
               begin
                 if not Assigned(blocks[i]) then
                   InternalError(200411302);
                 n.addblock(i,PCaseBlock(blocks[i])^.statement.dogetcopy);
               end;
           end
         else
           n.blocks:=nil;
         n.fcountsuptodate:=fcountsuptodate;
         n.flabelcnt:=flabelcnt;
         n.flabelcoverage:=flabelcoverage;
         dogetcopy:=n;
      end;


    procedure TCaseNode.printnodetree(var t: text);
      var
        i : LongInt;
      begin
        write(t,PrintNodeIndention,'(');
        PrintNodeIndent;
        printnodeinfo(t);
        WriteLn(t);
        printnode(t,left);
        i:=0;
        for i:=0 to blocks.count-1 do
          begin
            WriteLn(t,PrintNodeIndention,'(caseblock blockid: ',i);
            PrintNodeIndent;
            printnode(t,PCaseBlock(blocks[i])^.statement);
            PrintNodeUnindent;
            WriteLn(t,PrintNodeIndention,')');
          end;
        if Assigned(elseblock) then
          begin
            WriteLn(t,PrintNodeIndention,'(else: ',i);
            PrintNodeIndent;
            printnode(t,elseblock);
            PrintNodeUnindent;
            WriteLn(t,PrintNodeIndention,')');
          end;
        PrintNodeUnindent;
        WriteLn(t,PrintNodeIndention,')');
      end;


    procedure TCaseNode.insertintolist(l : TNodeList);
      begin
      end;


    function caselabelsequal(n1,n2: PCaseLabel): boolean;
      begin
        result :=
          (not Assigned(n1) and not Assigned(n2)) or
          (Assigned(n1) and Assigned(n2) and
           (n1^._low = n2^._low) and
           (n1^._high = n2^._high) and
           { the rest of the fields don't matter for equality (JM) }
           caselabelsequal(n1^.less,n2^.less) and
           caselabelsequal(n1^.greater,n2^.greater))
      end;


    function caseblocksequal(b1,b2:TFPList): boolean;
      var
        i : LongInt;
      begin
        result:=false;
        if b1.count<>b2.count then
          exit;
        for i:=0 to b1.count-1 do
          begin
            if not PCaseBlock(b1[i])^.statement.isequal(PCaseBlock(b2[i])^.statement) then
              exit;
          end;
        result:=true;
      end;


    function TCaseNode.docompare(p: TNode): boolean;
      begin
        result :=
          inherited docompare(p) and
          caselabelsequal(flabels,TCaseNode(p).flabels) and
          caseblocksequal(blocks,TCaseNode(p).blocks) and
          elseblock.isequal(TCaseNode(p).elseblock);
      end;


    procedure TCaseNode.addblock(blockid:LongInt;instr:TNode);
      var
        hcaseblock : PCaseBlock;
      begin
        new(hcaseblock);
        fillchar(hcaseblock^,sizeof(hcaseblock^),0);
        hcaseblock^.statement:=instr;
        if blockid>=blocks.count then
          blocks.count:=blockid+1;
        blocks[blockid]:=hcaseblock;
      end;


    procedure TCaseNode.addelseblock(instr:TNode);
      begin
        elseblock:=instr;
      end;


    function TCaseNode.getlabelcnt: cardinal;
      begin
        if not fcountsuptodate then
          updatecoverage;
        result:=flabelcnt;
      end;


    function TCaseNode.getlabelcoverage: qword;
      begin
        if not fcountsuptodate then
          updatecoverage;
        result:=flabelcoverage;
      end;


    procedure TCaseNode.updatecoverage;

      var
        isord, first: boolean;

      procedure count(p : PCaseLabel);
        begin
           inc(flabelcnt);
           if isord then
             begin
               flabelcoverage:=flabelcoverage + (p^._high - p^._low);
               { ensure we don't overflow in case it covers the
                 full range of qword }
               if not first then
                 inc(flabelcoverage);
               first:=false;
             end;
           if Assigned(p^.less) then
             count(p^.less);
           if Assigned(p^.greater) then
             count(p^.greater);
        end;

      begin
        isord:=Is_Ordinal(left.resultdef);
        flabelcnt:=0;
        flabelcoverage:=0;
        first:=true;
        count(flabels);
        fcountsuptodate:=true;
      end;


    procedure TCaseNode.checkordinalcoverage;

      function orddefspansfullrange(def: TOrdDef): boolean;
        var
          PackedBitSize: cardinal;
          dummy: LongInt;
          val: qword;
        begin
          result:=false;
          PackedBitSize:=def.PackedBitSize;
          if ((PackedBitSize mod 8) <> 0) or
             not IsPowerOf2(PackedBitSize div 8,dummy) then
            exit;
          dec(PackedBitSize);
          if Is_Signed(def) then
            begin
{$push}{$q-}
              if def.low<>(-(int64(1) shl PackedBitSize)) then
                exit;
              if def.high<>((int64(1) shl PackedBitSize)-1) then
                exit;
{$pop}
            end
          else
            begin
              if def.low<>0 then
                exit;
              val:=qword(1) shl PackedBitSize;
              val:=(val-1)+val;
              if def.high<>val then
                exit;
            end;
          result:=true;
        end;

      var
        lv, hv, typcount: TConstExprInt;
      begin
        { Check label type coverage for enumerations and small types }
        GetRange(left.resultdef,lv,hv);
        { low/high value of c-style booleans are not suitable for calculating their "type count" }
        if Is_CBool(left.resultdef) then
          typcount:=1
        else
          typcount:=hv-lv;
        if not Assigned(elseblock) then
          begin
            { unless cs_check_all_case_coverage is set, only check for enums, booleans and
              subrange types different from the default ones }
            if (cs_check_all_case_coverage in CurrentSettings.LocalSwitches) or
               (Is_Enum(left.resultdef) or
                Is_Boolean(left.resultdef) or
                not orddefspansfullrange(TOrdDef(left.resultdef))) and
               (labelcoverage<typcount) then
              begin
                { labels for some values of the operand are missing, and no else block is present }
                CGMessage(cg_w_case_incomplete);
                { in Standard/Extended Pascal, this is a dynamic violation error if it actually happens }
                if ([m_extpas,m_iso]*CurrentSettings.ModeSwitches)<>[] then
                  begin
                    elseblock:=CCallNode.createintern('fpc_rangeerror',nil);
                    TypeCheckPass(elseblock);
                  end;
              end
          end
        else if labelcoverage=typcount then
          begin
            { labels for all values of the operand are present, but an extra else block is present }
            MessagePos(elseblock.fileinfo, cg_w_unreachable_code);
          end;
      end;


    procedure TCaseNode.addlabel(blockid:LongInt;const l,h : TConstExprInt);
      var
        hcaselabel : PCaseLabel;

        function insertlabel(var p : PCaseLabel):PCaseLabel;
          begin
             if p=nil then
               begin
                 p:=hcaselabel;
                 result:=p;
               end
             else
              if (p^._low>hcaselabel^._low) and
                 (p^._low>hcaselabel^._high) then
                begin
                  if (hcaselabel^.blockid = p^.blockid) and
                     (p^._low = hcaselabel^._high + 1) then
                    begin
                      p^._low := hcaselabel^._low;
                      dispose(hcaselabel);
                      result:=p;
                    end
                  else
                    result:=insertlabel(p^.less)
                end
             else
               if (p^._high<hcaselabel^._low) and
                  (p^._high<hcaselabel^._high) then
                 begin
                    if (hcaselabel^.blockid = p^.blockid) and
                       (p^._high+1 = hcaselabel^._low) then
                      begin
                        p^._high := hcaselabel^._high;
                        dispose(hcaselabel);
                        result:=p;
                      end
                    else
                      result:=insertlabel(p^.greater);
                 end
             else
               begin
                 dispose(hcaselabel);
                 Message(parser_e_double_caselabel);
                 result:=nil;
               end
          end;

      begin
        new(hcaselabel);
        fillchar(hcaselabel^,sizeof(TCaseLabel),0);
        hcaselabel^.blockid:=blockid;
        hcaselabel^.label_type:=ltOrdinal;
        hcaselabel^._low:=l;
        hcaselabel^._high:=h;
        insertlabel(flabels);
        fcountsuptodate:=false;
      end;

    procedure TCaseNode.addlabel(blockid: LongInt; l, h: TStringConstNode);

      var
        hcaselabel : PCaseLabel;

      function insertlabel(var p : PCaseLabel) : PCaseLabel;
        begin
          if not Assigned(p) then
            begin
              p := hcaselabel;
              result := p;
            end
          else
            if (p^._low_str.fullcompare(hcaselabel^._high_str) > 0) then
              result := insertlabel(p^.less)
          else
            if (p^._high_str.fullcompare(hcaselabel^._low_str) < 0) then
              result := insertlabel(p^.greater)
          else
            begin
              FreeAndNil(hcaselabel^._low_str);
              FreeAndNil(hcaselabel^._high_str);
              dispose(hcaselabel);
              Message(parser_e_double_caselabel);
              result:=nil;
            end;
        end;

      begin
        new(hcaselabel);
        fillchar(hcaselabel^, sizeof(TCaseLabel), 0);
        hcaselabel^.blockid := blockid;
        hcaselabel^.label_type := ltConstString;

        hcaselabel^._low_str := TStringConstNode(l.GetCopy);
        hcaselabel^._high_str := TStringConstNode(h.GetCopy);

        insertlabel(flabels);
      end;

end.
