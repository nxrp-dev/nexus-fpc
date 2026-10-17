{
    Copyright (c) 1998-2002 by Florian Klaempfl

    Type checking and simplification for add nodes

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
unit nadd;

{$i fpcdefs.inc}
{$modeswitch nestedprocvars}

{ define addstringopt}

interface

    uses
      TPCompilerReal,
      node,symtype;

    type
       TAddNodeFlag = (
         anf_has_pointerdiv,
         { the node shall be short boolean evaluated, this flag has priority over localswitches }
         anf_short_bool
       );

       TAddNodeFlags = set of TAddNodeFlag;

       TAddNode = class(TBinOpNode)
       private
          resultrealdefderef: TDeref;
          function pass_typecheck_internal:TNode;
          function do_currency_corrections: TNode;
       public
          resultrealdef : TDef;
          addnodeflags : TAddNodeFlags;
          constructor create(tt : TNodeType;l,r : TNode);override;
          constructor Create_Internal(tt:TNodeType;l,r:TNode);
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure BuildDerefImpl;override;
          procedure derefimpl;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function simplify(forinline: boolean) : TNode;override;
          function dogetcopy : TNode;override;
          function docompare(p: TNode): boolean; override;
          procedure printnodedata(var t:text);override;
    {$ifdef state_tracking}
          function track_state_pass(exec_known:boolean):boolean;override;
    {$endif}
    {$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeInfo(var T: Text); override;
    {$endif DEBUG_NODE_XML}
         protected
          { override the following if you want to implement }
          { parts explicitely in the code generator (JM)    }
          function first_addstring: TNode; virtual;
          function first_addset: TNode; virtual;
          function first_adddynarray : TNode; virtual;
          { only implements "muln" nodes, the rest always has to be done in }
          { the code generator for performance reasons (JM)                 }
          function first_add64bitint: TNode; virtual;
          function first_addpointer: TNode; virtual;
          function first_cmppointer: TNode; virtual;

          { override and return false if you can handle 32x32->64 }
          { bit multiplies directly in your code generator. If    }
          { this function is overridden to return false, you can  }
          { get multiplies with left/right both s32bit or u32bit, }
          { and resultdef of the muln s64bit or u64bit           }
          function use_generic_mul32to64: boolean; virtual;

          { override and return false if code generator can handle }
          { full 64 bit multiplies.                                }
          function use_generic_mul64bit: boolean; virtual;

{$ifdef cpuneedsmulhelper}
          { override to customize to decide if the code generator }
          { can handle a given multiply node directly, or it needs helpers }
          function use_mul_helper: boolean; virtual;
{$endif cpuneedsmulhelper}

          { shall be overridden if the target cpu supports
            an fma instruction
          }
          function use_fma : boolean; virtual;
       private
          { checks whether a muln can be calculated as a 32bit }
          { * 32bit -> 64 bit                                  }
          function try_make_mul32to64: boolean;

          { Match against the ranges, i.e.:
            var a:1..10;
            begin
              if a>0 then
                ...
            always evaluates to true. (DM)
          }
          function cmp_of_disjunct_ranges(var res : boolean) : boolean;

          { tries to replace the current node by a fma node }
          function try_fma(ld,rd : TDef) : TNode;
       end;
       TAddNodeClass = class of TAddNode;

    var
       { caddnode is used to create nodes of the add type }
       { the virtual constructor allows to assign         }
       { another class type to caddnode => processor      }
       { specific node types can be created               }
       CAddNode : TAddNodeClass = TAddNode;

implementation

    uses
{$IFNDEF USE_FAKE_SYSUTILS}
      SysUtils,
{$ELSE}
      FKSysUtl,
{$ENDIF}
      GlobType,Systems,ConstExp,compinnr,
      CUtils,Verbose,Globals,WideStr,
      tokens,
      symconst,symdef,SymSym,symcpu,SymTable,defutil,defcmp,
      cgbase,
      htypechk,pass_1,
      nld,nbas,nmat,ncnv,ncon,nset,nopt,ncal,ninl,nmem,nutils,
      {$ifdef state_tracking}
      nstate,
      {$endif}
      CPUInfo,
      PPU;

const
    BestRealLayoutCheck = 1 div Ord(SizeOf(BestRealRec) = SizeOf(BestReal));
    swap_relation: array [ltn..unequaln] of TNodeType=(gtn, gten, ltn, lten, EqualN, unequaln);

{*****************************************************************************
                                TADDNODE
*****************************************************************************}

{$maxfpuregisters 0}

    function getbestreal(t1,t2 : TDef) : TDef;
      const
        floatweight : array[TFloatType] of byte =
          (2,3,4,5,0,1);
      begin
        if t1.typ=floatdef then
          begin
            result:=t1;
            if t2.typ=floatdef then
              begin
                { when a comp or currency is used, use always the
                  best float type to calculate the result }
                if (TFloatDef(t1).FloatType in [s64comp,s64currency]) or
                  (TFloatDef(t2).FloatType in [s64comp,s64currency]) or
                  (cs_excessprecision in CurrentSettings.LocalSwitches) then
                  result:=PBestRealType^
                else
                  if floatweight[TFloatDef(t2).FloatType]>floatweight[TFloatDef(t1).FloatType] then
                    result:=t2;
              end;
          end
        else if t2.typ=floatdef then
          result:=t2
        else InternalError(200508061);
      end;


    constructor TAddNode.create(tt : TNodeType;l,r : TNode);
      begin
         inherited create(tt,l,r);
         addnodeflags:=[];
      end;

    constructor TAddNode.Create_Internal(tt:TNodeType;l,r:TNode);
      begin
        create(tt,l,r);
        include(flags,nf_internal);
      end;


    constructor TAddNode.ppuload(t: TNodeType; ppufile: TCompilerPPUFile);
      begin
        inherited ppuload(t, ppufile);
        ppufile.GetSet(TPPUSet1(addnodeflags));
        ppufile.GetDeref(resultrealdefderef);
      end;


    procedure TAddNode.ppuwrite(ppufile: TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.PutSet(TPPUSet1(addnodeflags));
        ppufile.PutDeref(resultrealdefderef);
      end;


    procedure TAddNode.BuildDerefImpl;
      begin
        inherited BuildDerefImpl;
        resultrealdefderef.build(resultrealdef);
      end;


    procedure TAddNode.derefimpl;
      begin
        inherited derefimpl;
        resultrealdef:=TDef(resultrealdefderef.resolve);
      end;


    function TAddNode.cmp_of_disjunct_ranges(var res : boolean) : boolean;
      var
        hp          : TNode;
        realdef     : TDef;
        v           : TConstExprInt;
      begin
        result:=false;
        { check for comparison with known result because the ranges of the operands don't overlap }
        if (is_constintnode(right) and (left.resultdef.typ=orddef) and
            { don't ignore type checks }
            Is_Subequal(right.resultdef,left.resultdef)) or
           (is_constintnode(left) and (right.resultdef.typ=orddef) and
            { don't ignore type checks }
            Is_Subequal(left.resultdef,right.resultdef)) then
           begin
             if is_constintnode(right) then
               begin
                 hp:=left;
                 v:=TOrdConstNode(right).Value;
               end
             else
               begin
                 hp:=right;
                 v:=TOrdConstNode(left).Value;
               end;

             realdef:=hp.resultdef;
             { stop with finding the real def when we either encounter
                a) an explicit type conversion (then the value has to be
                   re-interpreted)
                b) an "absolute" type conversion (also requires
                   re-interpretation)
             }
             while (hp.nodetype=typeconvn) and
                   ([nf_internal,nf_explicit,nf_absolute] * hp.flags = []) do
               begin
                 hp:=TTypeConvNode(hp).left;
                 realdef:=hp.resultdef;
               end;
             { could become an errordef in case of errors }
             if realdef.typ<>orddef then
               exit;
             if is_constintnode(left) then
               with TOrdDef(realdef) do
                 case nodetype of
                  ltn:
                    if v<low then
                      begin
                        result:=true;
                        res:=true;
                      end
                    else if v>=high then
                      begin
                        result:=true;
                        res:=false;
                      end;
                  lten:
                    if v<=low then
                      begin
                        result:=true;
                        res:=true;
                      end
                    else if v>high then
                      begin
                        result:=true;
                        res:=false;
                      end;
                  gtn:
                    if v<=low then
                      begin
                        result:=true;
                        res:=false;
                      end
                    else if v>high then
                      begin
                        result:=true;
                        res:=true;
                      end;
                  gten :
                    if v<low then
                      begin
                        result:=true;
                        res:=false;
                      end
                    else if v>=high then
                      begin
                        result:=true;
                        res:=true;
                      end;
                  EqualN:
                    if (v<low) or (v>high) then
                      begin
                        result:=true;
                        res:=false;
                      end;
                  unequaln:
                    if (v<low) or (v>high) then
                      begin
                        result:=true;
                        res:=true;
                      end;
                  else
                    ;
                 end
             else
               with TOrdDef(realdef) do
                 case nodetype of
                  ltn:
                    if high<v then
                      begin
                        result:=true;
                        res:=true;
                      end
                    else if low>=v then
                      begin
                        result:=true;
                        res:=false;
                      end;
                  lten:
                    if high<=v then
                      begin
                        result:=true;
                        res:=true;
                      end
                    else if low>v then
                      begin
                        result:=true;
                        res:=false;
                      end;
                  gtn:
                    if high<=v then
                      begin
                        result:=true;
                        res:=false;
                      end
                    else if low>v then
                      begin
                        result:=true;
                        res:=true;
                      end;
                  gten:
                    if high<v then
                      begin
                        result:=true;
                        res:=false;
                      end
                    else if low>=v then
                      begin
                        result:=true;
                        res:=true;
                      end;
                  EqualN:
                    if (v<low) or (v>high) then
                      begin
                        result:=true;
                        res:=false;
                      end;
                  unequaln:
                    if (v<low) or (v>high) then
                      begin
                        result:=true;
                        res:=true;
                      end;
                  else
                    ;
                 end;
           end;
      end;


    function TAddNode.simplify(forinline : boolean) : TNode;

      function is_range_test(nodel, noder: TAddNode; out value: TNode; var cl,cr: TConstExprInt): boolean;
        const
          is_upper_test: array[ltn..gten] of boolean = (true,true,false,false);
          inclusive_adjust: array[boolean,boolean,ltn..gten] of integer = (((-1,0,1,0),
                                                                            (1,0,-1,0)),
                                                                           ((0,-1,0,1),
                                                                            (0,1,0,-1)));
        var
          swapl, swapr, inverted_range: Boolean;
          valuer: TNode;
          t: TConstExprInt;
        begin
          result:=false;
          swapl:=false;
          swapr:=false;

          if nodel.left.nodetype=ordconstn then
            begin
              swapl:=true;
              cl:=TOrdConstNode(nodel.left).Value;
              value:=nodel.right;
            end
          else if nodel.right.nodetype=ordconstn then
            begin
              cl:=TOrdConstNode(nodel.right).Value;
              value:=nodel.left;
            end
          else
            exit;

          if noder.left.nodetype=ordconstn then
            begin
              swapl:=true;
              cr:=TOrdConstNode(noder.left).Value;
              valuer:=noder.right;
            end
          else if noder.right.nodetype=ordconstn then
            begin
              cr:=TOrdConstNode(noder.right).Value;
              valuer:=noder.left;
            end
          else
            exit;

          if not value.isequal(valuer) then
            exit;

          { This is based on De Morgan's theorem, namely that
            "A and B" = "not ((not A) or (not B))" }
          inverted_range:=(nodetype=orn);
          if inverted_range then
            begin
              swapl:=not swapl;
              swapr:=not swapr;
            end;

          { this could be simplified too, but probably never happens }
          if (is_upper_test[nodel.nodetype] xor swapl)=(is_upper_test[noder.nodetype] xor swapr) then
            exit;

          cl:=cl+inclusive_adjust[inverted_range,swapl,nodel.nodetype];
          cr:=cr+inclusive_adjust[inverted_range,swapr,noder.nodetype];

          if is_upper_test[nodel.nodetype] xor swapl then
            begin
              t:=cl;
              cl:=cr;
              cr:=t;
            end;

          if cl>cr then
            exit;

          result:=true;
        end;


      function TryHandleLengthZero(L,R : TNode; op : TNodeType; var resn : TNode) : boolean;
        var
          swapn : TNode;
        begin
          result:=false;
          { Attempt to handle Length(S) = 0, <> 0, > 0, < 0, >= 0, <= 0. }
          if not (op in [EqualN,unequaln,ltn,lten,gtn,gten]) then
            exit;
          if not is_inlinefunction(L,in_length_x) then
            if is_inlinefunction(R,in_length_x) then
              begin
                op:=swap_relation[op];
                swapn:=L;
                L:=R;
                R:=swapn;
              end
            else
              exit;
          if not is_constintvalue(R,0) or Is_ShortString(TInlineNode(L).left.resultdef) then
            exit;

          { Length = 0, <> 0, > 0, <= 0 are reduced to Length = 0. }
          if op in [EqualN,unequaln,gtn,lten] then
            begin
              { “pointer(L.left) = nil”. Steal L.left instead of getcopy, zero a bit later. }
              resn:=CAddNode.Create_Internal(EqualN,CTypeConvNode.Create_Internal(TInlineNode(L).left,VoidPointerType),
                 CPointerConstNode.create(0,VoidPointerType));

              { COM widestrings have 32-bit lengths, and can explicitly have 0 while being non-nil. }
              if Is_WideString(TInlineNode(L).left.resultdef) and (tf_winlikewidestring in TargetInfo.flags) then
                begin
                  { Expand to “(pointer(L.left) = nil) or (PUint32(L.left)[-1] = 0)”. }
                  resn:=CAddNode.Create_Internal(orn,
                      resn,
                      CAddNode.Create_Internal(EqualN,
                        CTypeConvNode.Create_Internal(
                          CDerefNode.create(
                            CAddNode.Create_Internal(subn,CTypeConvNode.Create_Internal(TInlineNode(L).left.GetCopy,VoidPointerType),
                              COrdConstNode.create(sizeof(uint32),PtrUIntType,false))
                          ),U32IntType
                        ),
                        COrdConstNode.create(0,U32IntType,false))
                    );
                  include(TAddNode(resn).addnodeflags,anf_short_bool);
                end;
              TInlineNode(L).left:=nil; { Was stolen inside resn, and no longer of interest. }

              { resn now checks for Length = 0. For Length <> 0, invert. }
              if op in [unequaln,gtn] then
                resn:=CNotNode.create(resn);
              exit(true);
            end;

          { Warn on Length < 0 and Length >= 0. }
          if not (tnf_pass1_done in L.transientflags) then { ...Only once. }
            if op=gten then
              Message(type_w_comparison_always_true)
            else
              Message(type_w_comparison_always_false);

          { Length < 0 is always false, Length >= 0 is always true. }
          if not might_have_sideeffects(TInlineNode(L).left) then { Could somehow remove the check but keep the F() even in Length(F()) >= 0... }
            begin
              resn:=COrdConstNode.create(ord(op=gten),resultdef,true);
              exit(true);
            end;
        end;


      function GetCopyAndTypeCheck: TNode;
        begin
          result:=GetCopy;
          result.resultdef:=nil;
          result:=CTypeConvNode.Create_Internal(result,resultdef);
          DoTypeCheckPass(result);
        end;


      function IsAndOrAndNot(n1,n2,n3,n4 : TNode): Boolean;
        begin
          result:=(n4.nodetype=notn) and
            TNotNode(n4).left.isequal(n2);
        end;


      function TransformAndOrAndNot(n1,n2,n3,n4 : TNode): TNode;
        begin
          result:=CAddNode.Create_Internal(xorn,n3.GetCopy,
            CAddNode.Create_Internal(andn,CAddNode.Create_Internal(xorn,n3.GetCopy,n1.GetCopy),n2.GetCopy));
        end;


      function SwapRightWithLeftRight : TNode;
        var
          hp : TNode;
        begin
          hp:=right;
          right:=TAddNode(left).right;
          TAddNode(left).right:=hp;
          left:=left.simplify(forinline);
          if resultdef.typ<>pointerdef then
            begin
              { ensure that the constant is not expanded to a larger type due to overflow,
                but this is only useful if no pointer operation is done }
              left:=CTypeConvNode.Create_Internal(left,resultdef);
              DoTypeCheckPass(left);
            end;
          result:=GetCopyAndTypeCheck;
        end;


      function SwapRightWithLeftLeft : TNode;
        var
          hp,hp2 : TNode;
        begin
          { keep the order of val+const else pointer and string operations might cause an error }
          hp:=TAddNode(left).left;
          TAddNode(left).left:=TAddNode(left).right;
          TAddNode(left).right:=right;
          left.resultdef:=nil;
          DoTypeCheckPass(left);
          hp2:=left.simplify(forinline);
          if Assigned(hp2) then
            left:=hp2;
          if resultdef.typ<>pointerdef then
            begin
              { ensure that the constant is not expanded to a larger type due to overflow,
                but this is only useful if no pointer operation is done }
              left:=CTypeConvNode.Create_Internal(left,resultdef);
              DoTypeCheckPass(left);
            end
          else if TPointerDef(resultdef).PointedDef.Size>1 then
          { the constants were already multiplied by the pointer element size }
            left:=CModDivNode.create(divn,left,COrdConstNode.create(TPointerDef(resultdef).PointedDef.Size,left.resultdef,false));
          right:=left;
          left:=hp;
          result:=GetCopyAndTypeCheck;
        end;


      function SwapLeftWithRightRight : TNode;
        var
          hp,hp2 : TNode;
        begin
          { keep the order of val+const else string operations might cause an error }
          hp:=TAddNode(right).right;

          TAddNode(right).right:=TAddNode(right).left;
          TAddNode(right).left:=left;

          right.resultdef:=nil;
          DoTypeCheckPass(right);
          hp2:=right.simplify(forinline);
          if Assigned(hp2) then
            right:=hp2;
          if resultdef.typ<>pointerdef then
            begin
              { ensure that the constant is not expanded to a larger type due to overflow,
                but this is only useful if no pointer operation is done }
              right:=CTypeConvNode.Create_Internal(right,resultdef);
              DoTypeCheckPass(right);
            end;
          left:=right;
          right:=hp;
          result:=GetCopyAndTypeCheck;
        end;


      function SwapLeftWithRightLeft : TNode;
        var
          hp: TNode;
        begin
          hp:=left;
          left:=TAddNode(right).left;
          TAddNode(right).left:=hp;
          right:=right.simplify(false);
          result:=GetCopyAndTypeCheck;
        end;


      function TryVariableShiftPair(lin, rin: TNode; bitsize: asizeint): boolean;
        begin
          Result:=(rin.nodetype=subn) and
            is_constintnode(TAddNode(rin).left) and
            (TOrdConstNode(TAddNode(rin).left).Value=bitsize) and
            not might_have_sideeffects(lin) and
            TAddNode(rin).right.isequal(lin);
        end;


      function CheckRotateOptimization(standard_op, reverse_op: TInlineNumber): TNode;
        var
          bitsize: asizeint;
        begin
          Result:=nil;
          if Is_Integer(TShlShrNode(left).left.resultdef) and
            { Avoid using custom integers due to the risk of unusual sizes and
              undesired effects in, say, bitpacked records. [Kit] }
            (TOrdDef(TShlShrNode(left).left.resultdef).OrdType<>customint) and
            not might_have_sideeffects(TShlShrNode(left).left) and
            TShlShrNode(left).left.isequal(TShlShrNode(right).left) then
            begin
              bitsize:=TShlShrNode(left).left.resultdef.Size*8;

              { Check for constants first }
              if (
                  is_constintnode(TShlShrNode(left).right) and
                  (TOrdConstNode(TShlShrNode(left).right).Value>0) and
                  is_constintnode(TShlShrNode(right).right) and
                  (TOrdConstNode(TShlShrNode(right).right).Value>0) and
                  (TOrdConstNode(TShlShrNode(right).right).Value=bitsize-TOrdConstNode(TShlShrNode(left).right).Value)
                ) or
                  { Try (X op1 Y) or (X op2 (S-Y)) for variable rotation}
                  TryVariableShiftPair(TShlShrNode(left).right, TShlShrNode(right).right, bitsize) then
                begin
                  result:=CInlineNode.create(standard_op,false,
                    CCallParaNode.create(TShlShrNode(left).PruneKeepRight(),
                    CCallParaNode.create(TShlShrNode(left).PruneKeepLeft(),nil)));
                  Exit;
                end;

              { Try (X op1 (S-Y)) or (X op2 Y) for variable rotation }
              if TryVariableShiftPair(TShlShrNode(right).right, TShlShrNode(left).right, bitsize) then
                begin
                  result:=CInlineNode.create(reverse_op,false,
                    CCallParaNode.create(TShlShrNode(right).PruneKeepRight(),
                    CCallParaNode.create(TShlShrNode(right).PruneKeepLeft(),nil)));
                  Exit;
                end;
            end;
        end;


      var
        hp: TAddNode;
        t,vl,lefttarget,righttarget,value1conv,value2conv: TNode;
        lt,rt,nt : TNodeType;
        hdef,
        rd,ld   , inttype: TDef;
        rv,lv,v : TConstExprInt;
        rvd,lvd : BestReal;
        ws1,ws2 : TCompilerWideString;
        concatstrings : boolean;
        c1,c2   : array[0..1] of char;
        s1,s2,stmp   : pchar;
        l1,l2   : LongInt;
        resultset : TConstSet;
        res,
        b       : boolean;
        cr, cl  : TConstExprInt;
        v2p, c2p, c1p, v1p: PNode;
        p1,p2: TConstPtrUInt;
      begin
        result:=do_currency_corrections;
        if Assigned(result) then
          Exit;

        l1:=0;
        l2:=0;
        s1:=nil;
        s2:=nil;

        { load easier access variables }
        rd:=right.resultdef;
        ld:=left.resultdef;
        rt:=right.nodetype;
        lt:=left.nodetype;

        if (nodetype = slashn) and
           (((rt = ordconstn) and
             (TOrdConstNode(right).Value = 0)) or
            ((rt = realconstn) and
             (TRealConstNode(right).value_real = 0.0))) then
          begin
            if Floating_Point_Range_Check_Error then
               begin
                 result:=CRealConstNode.create(1,PBestRealType^);
                 Message(parser_e_division_by_zero);
                 exit;
               end;
          end;

        { both are int constants }
        if  (
             is_constintnode(left) and
             is_constintnode(right)
            ) or
            (
             is_constboolnode(left) and
             is_constboolnode(right) and
             (nodetype in [slashn,ltn,lten,gtn,gten,EqualN,unequaln,andn,xorn,orn])
            ) or
            (
             is_constenumnode(left) and
             is_constenumnode(right) and
             (allowenumop(nodetype) or (nf_internal in flags))
            ) or
            (
             (lt in [pointerconstn,niln]) and
             is_constintnode(right) and
             (nodetype in [addn,subn])
            ) or
            (
             (rt in [pointerconstn,niln]) and
             is_constintnode(left) and
             (nodetype=addn)
            ) or
            (
             (lt in [pointerconstn,niln]) and
             (rt in [pointerconstn,niln]) and
             (nodetype in [ltn,lten,gtn,gten,EqualN,unequaln,subn])
            ) or
            (
             (lt = ordconstn) and (ld.typ = orddef) and Is_Currency(ld) and
             (rt = ordconstn) and (rd.typ = orddef) and Is_Currency(rd)
            ) then
          begin
             t:=nil;

             { load values }
             lv:=get_int_value(left);
             rv:=get_int_value(right);

             { Fix the currency scaling if, out of left and right, the
               nf_is_currency flag is set, but not for both }
             if (nf_is_currency in left.flags) and
               not (nf_is_currency in right.flags) then
               rv:=rv*10000
             else if (nf_is_currency in right.flags) and
               not (nf_is_currency in left.flags) then
               lv:=lv*10000;

             { type checking already took care of multiplying      }
             { integer constants with pointeddef.size if necessary }
             case nodetype of
               addn :
                 begin
                   v:=lv+rv;
                   if v.overflow then
                     begin
                       Message(parser_e_arithmetic_operation_overflow);
                       { Recover }
                       t:=genintconstnode(0)
                     end
                   else if is_constpointernode(left) or is_constpointernode(right) then
                     t:=CPointerConstNode.create(qword(v),resultdef)
                   else
                     begin
                       if Is_Integer(ld) then
                         t:=create_simplified_ord_const(v,resultdef,forinline,cs_check_overflow in LocalSwitches)
                       else
                         t:=COrdConstNode.create(v,resultdef,(ld.typ<>enumdef));
                     end;

                   if Is_Currency(resultdef) then
                     Include(t.flags,nf_is_currency);
                 end;
               subn :
                 begin
                   v:=lv-rv;
                   if v.overflow then
                     begin
                       Message(parser_e_arithmetic_operation_overflow);
                       { Recover }
                       t:=genintconstnode(0)
                     end
                   else if (lt=pointerconstn) then
                     { pointer-pointer results in an integer }
                     if (rt=pointerconstn) then
                       begin
                         if (cs_typed_addresses in CurrentSettings.LocalSwitches) and
                            (TPointerDef(rd).PointedDef.Size>1) and
                            not(anf_has_pointerdiv in addnodeflags) then
                           InternalError(2008030101);
                         t:=CPointerConstNode.create(qword(v),resultdef)
                       end
                     else
                       t:=CPointerConstNode.create(qword(v),resultdef)
                   else
                     begin
                       if Is_Integer(ld) then
                         t:=create_simplified_ord_const(v,resultdef,forinline,cs_check_overflow in LocalSwitches)
                       else
                         t:=COrdConstNode.create(v,resultdef,(ld.typ<>enumdef));
                     end;

                   if Is_Currency(resultdef) then
                     Include(t.flags,nf_is_currency);
                 end;
               muln :
                 begin
                   v:=lv*rv;
                   if v.overflow then
                     begin
                       message(parser_e_arithmetic_operation_overflow);
                       { Recover }
                       t:=genintconstnode(0)
                     end
                   else
                     begin
                       { If both are currency, we have to remove one of the
                         scalars}
                       if Is_Currency(resultdef) then
                         begin
                           v:=v div 10000;

                           if not (nf_is_currency in flags) then
                             { We have to remove both scalars in this case }
                             v:=v div 10000;
                         end;

                       t:=create_simplified_ord_const(v,resultdef,forinline,cs_check_overflow in LocalSwitches);

                       if Is_Currency(resultdef) then
                         Include(t.flags,nf_is_currency);
                     end;
                 end;
               xorn :
                 begin
                   if Is_Integer(ld) then
                     t:=create_simplified_ord_const(lv xor rv,resultdef,forinline,false)
                   else
                     t:=COrdConstNode.create(lv xor rv,resultdef,true);

                   if Is_Currency(resultdef) then
                     Include(t.flags,nf_is_currency);
                 end;
               orn :
                 begin
                   if Is_Integer(ld) then
                     t:=create_simplified_ord_const(lv or rv,resultdef,forinline,false)
                   else
                     t:=COrdConstNode.create(lv or rv,resultdef,true);

                   if Is_Currency(resultdef) then
                     Include(t.flags,nf_is_currency);
                 end;
               andn :
                 begin
                   if Is_Integer(ld) then
                     t:=create_simplified_ord_const(lv and rv,resultdef,forinline,false)
                   else
                     t:=COrdConstNode.create(lv and rv,resultdef,true);

                   if Is_Currency(resultdef) then
                     Include(t.flags,nf_is_currency);
                 end;
               ltn :
                 t:=COrdConstNode.create(ord(lv<rv),PasBool1Type,true);
               lten :
                 t:=COrdConstNode.create(ord(lv<=rv),PasBool1Type,true);
               gtn :
                 t:=COrdConstNode.create(ord(lv>rv),PasBool1Type,true);
               gten :
                 t:=COrdConstNode.create(ord(lv>=rv),PasBool1Type,true);
               EqualN :
                 t:=COrdConstNode.create(ord(lv=rv),PasBool1Type,true);
               unequaln :
                 t:=COrdConstNode.create(ord(lv<>rv),PasBool1Type,true);
               slashn :
                 begin
                   { int/int becomes a real }
                   rvd:=rv;
                   lvd:=lv;

                   { With currency, we may have to apply a scalar.  If both
                     are currency, the scalars cancel out and are not required }
                   if (nf_is_currency in left.flags) and
                     not (nf_is_currency in right.flags) then
                     lvd:=lvd/BestReal(10000.0)
                   else if (nf_is_currency in right.flags) and
                     not (nf_is_currency in left.flags) then
                     rvd:=rvd/BestReal(10000.0);

                   t:=CRealConstNode.create(lvd/rvd,resultrealdef);
                 end;
               else
                 InternalError(2008022101);
             end;
             result:=t;
             exit;
          end
        else if cmp_of_disjunct_ranges(res) then
          begin
            if res then
              t:=COrdConstNode.create(1,PasBool1Type,true)
            else
              t:=COrdConstNode.create(0,PasBool1Type,true);
            { don't do this optimization, if the variable expression might
              have a side effect }
            if (is_constintnode(left) and might_have_sideeffects(right)) or
              (is_constintnode(right) and might_have_sideeffects(left)) then
              t.free // no nil needed
            else
              result:=t;
            exit;
          end;

        { For operations that follow the commutative law, put integer constants on the right }
        if (nodetype in [addn,orn,xorn,andn,muln]) and
          is_constintnode(left) and (Is_Integer(right.resultdef) or Is_Pointer(right.resultdef)) then
          SwapLeftRight;

        { Add,Sub,Mul,Or,Xor,Andn with constant 0, 1 or -1?  }
        if is_constintnode(right) and (Is_Integer(ld) or Is_Pointer(ld)) then
          begin
            if (TOrdConstNode(right).Value = 0) and (nodetype in [addn,subn,orn,xorn,andn,muln]) then
              begin
                case nodetype of
                  addn,subn,orn,xorn:
                    result := PruneKeepLeft();
                  andn,muln:
                    begin
                      if (cs_opt_level4 in CurrentSettings.OptimizerSwitches) or
                         not might_have_sideeffects(left) then
                        result:=COrdConstNode.create(0,resultdef,true);
                    end
                  else
                    ;
                end;
              end

            else if (TOrdConstNode(right).Value = 1) and (nodetype=muln) then
              { insert type conversion in case it is a 32*32 to 64 bit multiplication optimization,
                the type conversion does not hurt because it is normally removed later on
              }
              result := CTypeConvNode.Create_Internal(PruneKeepLeft(),resultdef)

            { try to fold
                          op                         op
                         /  \                       /  \
                       op  const1       or        op  const1
                      /  \                       /  \
                  const2 val                   val const2
            }
            else if (left.nodetype=nodetype) and
              { there might be a mul operation e.g. longint*longint => int64 in this case
                we cannot do this optimization, see e.g. tests/tbs/tw36587.pas on arm }
              (Compare_Defs(resultdef,ld,nothingn)=te_exact) then
              begin
                if is_constintnode(TAddNode(left).left) then
                  begin
                    case left.nodetype of
                      xorn,
                      addn,
                      andn,
                      orn,
                      muln:
                        Result:=SwapRightWithLeftRight;
                      else
                        ;
                    end;
                  end
                else if is_constintnode(TAddNode(left).right) then
                  begin
                    case left.nodetype of
                      xorn,
                      addn,
                      andn,
                      orn,
                      muln:
                        Result:=SwapRightWithLeftLeft;
                      else
                        ;
                    end;
                  end
              end;

            if Assigned(result) then
              exit;

            { multiplication by -1? Convert it into an unary minus if the other conversions before failed, don't do
              it before the folding above, see #40448 }
            if (TOrdConstNode(right).Value = -1) and (nodetype=muln) then
              result := CTypeConvNode.Create_Internal(CUnaryMinusNode.create(PruneKeepLeft()),ld);

            if Assigned(result) then
              exit;
          end;

        { Deal with anti-commutative subtraction }
        if (nodetype = subn) then
          begin
            { transform -1-x into not(x) }
            if Is_Signed(rd) and is_constintnode(left) and (TOrdConstNode(left).Value=-1)  then
              begin
                result:=CNotNode.create(right.GetCopy);
                exit;
              end

            { change "0 - val" to "-val" }
            else if is_constintnode(left) and (Is_Integer(right.resultdef) or Is_Pointer(right.resultdef)) then
              begin
                if (TOrdConstNode(left).Value = 0) then
                  result := CTypeConvNode.Create_Internal(CUnaryMinusNode.create(right.GetCopy),right.resultdef);
              end

            { change "nil - val" to "-val" }
            else if (left.nodetype=niln) and Is_Pointer(right.resultdef) then
              result := CTypeConvNode.Create_Internal(CUnaryMinusNode.create(CTypeConvNode.Create_Internal(right.GetCopy,resultdef)),resultdef)

            { convert n - n mod const into n div const*const }
            else if (right.nodetype=modn) and is_constintnode(TModDivNode(right).right) and
              (left.isequal(TModDivNode(right).left)) and not(might_have_sideeffects(left)) { and
	      not(cs_check_overflow in localswitches) } then
              begin
                result:=CAddNode.create(muln,CModDivNode.create(divn,left,TModDivNode(right).right.GetCopy),TModDivNode(right).right);
                left:=nil;
                TModDivNode(right).right:=nil;
                exit;
              end

            { transform -x-1 into not(x) }
            else if Is_Signed(ld) and is_constintnode(right) and (TOrdConstNode(right).Value=1) and (left.nodetype=unaryminusn) then
              begin
                result:=CNotNode.create(TUnaryMinusNode(left).left.GetCopy);
                exit;
              end;
          end;

      { both real constants ? }
        if (lt=realconstn) and (rt=realconstn) then
          begin
             lvd:=TRealConstNode(left).value_real;
             rvd:=TRealConstNode(right).value_real;
             case nodetype of
                addn :
                  begin
                    t:=CRealConstNode.create(lvd+rvd,resultrealdef);
                    if nf_is_currency in flags then
                      include(t.flags,nf_is_currency);
                  end;
                subn :
                  begin
                    t:=CRealConstNode.create(lvd-rvd,resultrealdef);
                    if nf_is_currency in flags then
                      include(t.flags,nf_is_currency);
                  end;
                muln :
                  begin
                    if (nf_is_currency in flags) then
                      begin
                        if (nf_is_currency in left.flags) and
                          (nf_is_currency in right.flags) then
                          begin
                            { Need to remove one of the scalars }
                            rvd:=rvd/BestReal(10000.0);
                            if not (nf_is_currency in flags) then
                              { Make that both }
                              lvd:=lvd/BestReal(10000.0);
                          end
                        else if not (nf_is_currency in left.flags) and
                          not (nf_is_currency in right.flags) then
                          begin
                            { We actually lack a scalar - try to scale
                              the smallest to minimise precision errors }
                            if (Abs(rvd) > Abs(lvd)) then
                              lvd:=lvd*BestReal(10000.0)
                            else
                              rvd:=rvd*BestReal(10000.0);
                          end;
                      end
                    else
                      begin
                        { Clear any scalars }
                        if (nf_is_currency in left.flags) then
                          lvd:=lvd/BestReal(10000.0);
                        if (nf_is_currency in right.flags) then
                          rvd:=rvd/BestReal(10000.0);
                      end;

                    t:=CRealConstNode.create(lvd*rvd,resultrealdef);
                    if nf_is_currency in flags then
                      include(t.flags,nf_is_currency);
                  end;
                starstarn:
                  begin
                    if lvd<0 then
                     begin
                       Message(parser_e_invalid_float_operation);
                       t:=CRealConstNode.create(0,resultrealdef);
                     end
                    else if lvd=0 then
                      t:=CRealConstNode.create(1.0,resultrealdef)
                    else
                      t:=CRealConstNode.create(Exp(Ln(lvd)*rvd),resultrealdef);
                  end;
                slashn :
                  begin
                    if (nf_is_currency in flags) and
                      (nf_is_currency in left.flags) and
                      (nf_is_currency in right.flags) then
                      begin
                        { Need to put one of the scalars back }
                        t:=CRealConstNode.create((lvd/rvd)*BestReal(10000.0),resultrealdef);
                        Include(t.flags,nf_is_currency);
                      end
                    else
                      begin
                        t:=CRealConstNode.create(lvd/rvd,resultrealdef);

                        if (nf_is_currency in left.flags) and
                          not (nf_is_currency in right.flags) then
                          include(t.flags,nf_is_currency);
                      end;
                  end;
                ltn :
                  t:=COrdConstNode.create(ord(lvd<rvd),PasBool1Type,true);
                lten :
                  t:=COrdConstNode.create(ord(lvd<=rvd),PasBool1Type,true);
                gtn :
                  t:=COrdConstNode.create(ord(lvd>rvd),PasBool1Type,true);
                gten :
                  t:=COrdConstNode.create(ord(lvd>=rvd),PasBool1Type,true);
                EqualN :
                  t:=COrdConstNode.create(ord(lvd=rvd),PasBool1Type,true);
                unequaln :
                  t:=COrdConstNode.create(ord(lvd<>rvd),PasBool1Type,true);
                else
                  InternalError(2008022102);
             end;
             result:=t;
             exit;
          end;

        if Is_Real(resultdef) then
          begin
            if (nodetype=addn) then
              begin
                { -left+right => right-left,
                  this operation is always valid }
                if (left.nodetype=unaryminusn) then
                  begin
                    t := TUnaryMinusNode(left).PruneKeepLeft();
                    result:=CAddNode.create(subn,PruneKeepRight(),t);
                    exit;
                  end;

                { left+(-right) => left-right,
                  this operation is always valid }
                if (right.nodetype=unaryminusn) then
                  begin
                    t := TUnaryMinusNode(right).PruneKeepLeft();
                    result:=CAddNode.create(subn,PruneKeepLeft(),t);
                    exit;
                  end;
              end;

            { left-(-right) => left+right,
              this operation is always valid }
            if (nodetype=subn) and (right.nodetype=unaryminusn) then
              begin
                t := TUnaryMinusNode(right).PruneKeepLeft();
                result:=CAddNode.create(addn,PruneKeepLeft(),t);
                exit;
              end;

            { (-left)*(-right) => left*right, and
              (-left)/(-right) => left/right,
              these operations are always valid }
            if (nodetype in [muln,slashn]) and (left.nodetype=unaryminusn) and (right.nodetype=unaryminusn) then
              begin
                t := TUnaryMinusNode(right).PruneKeepLeft();
                result:=CAddNode.create(nodetype,TUnaryMinusNode(left).PruneKeepLeft(),t);
                exit;
              end;

            { optimize operations with real constants, but only if fast math is switched on as
              the operations could change e.g. the sign of 0 so they cannot be optimized always
            }
            if Is_Real(resultdef) then
              begin
                if lt=realconstn then
                  begin
                    if (TRealConstNode(left).value_real=0) and (nodetype in [addn,muln,subn,slashn]) then
                      begin
                        case nodetype of
                          addn:
                            begin
                              { -0.0+(+0.0)=+0.0 so we cannot carry out this optimization if no fastmath is passed }
                              if not(cs_opt_fastmath in CurrentSettings.OptimizerSwitches) then
                                begin
                                  result:=PruneKeepRight();
                                  exit;
                                end;
                            end;
                          slashn,
                          muln:
                            if not(might_have_sideeffects(right,[mhs_exceptions])) then
                              begin
                                result:=PruneKeepLeft;
                                exit;
                              end;
                          subn:
                            begin
                              t := PruneKeepRight();
                              result:=CTypeConvNode.Create_Internal(CUnaryMinusNode.create(t),rd);
                              exit;
                            end;
                          else
                            InternalError(2020060801);
                        end;
                      end
                    else if (TRealConstNode(left).value_real=1) and (nodetype=muln) then
                      begin
                        result:=right.GetCopy;
                        exit;
                      end
                    else if (TRealConstNode(left).value_real=2) and (nodetype=muln) and not(might_have_sideeffects(right,[mhs_exceptions])) and
                      (node_complexity(right)<=1) then
                      begin
                        result:=CAddNode.Create_Internal(addn,right.GetCopy,right.GetCopy);
                        exit;
                      end;
                  end
                else if rt=realconstn then
                  begin
                    if (TRealConstNode(right).value_real=0) and (nodetype in [addn,muln,subn]) then
                      begin
                        case nodetype of
                          subn,
                          addn:
                            begin
                              result:=left.GetCopy;
                              exit;
                            end;
                          muln:
                            if not(might_have_sideeffects(left,[mhs_exceptions])) then
                              begin
                                result:=right.GetCopy;
                                exit;
                              end;
                          else
                            InternalError(2020060802);
                        end;
                      end
                    else if (TRealConstNode(right).value_real=1) and (nodetype in [muln,slashn]) then
                      begin
                        result:=left.GetCopy;
                        exit;
                      end
                    else if (TRealConstNode(right).value_real=2) and (nodetype=muln) and not(might_have_sideeffects(left,[mhs_exceptions])) and
                      (node_complexity(left)<=1) then
                      begin
                        result:=CAddNode.Create_Internal(addn,left.GetCopy,left.GetCopy);
                        exit;
                      end;
                  end
                { optimize a/a and a-a }
                else if ((nodetype in [subn,slashn]) and ([cs_opt_fastmath,cs_opt_level2]*CurrentSettings.OptimizerSwitches=[cs_opt_fastmath,cs_opt_level2])) and
                  left.isequal(right) and not(might_have_sideeffects(left,[mhs_exceptions])) then
                  begin
                    case nodetype of
                      subn:
                        result:=CRealConstNode.create(0,ld);
                      slashn:
                        result:=CRealConstNode.create(1,ld);
                      else
                        InternalError(2020060901);
                    end;
                  end;
              end;
          end;

        { replace .../const by a multiplication, but only if fastmath is enabled or
          the division is done by a power of 2, do not mess with special floating point values like Inf etc.

          do this after constant folding to avoid unnecessary precision loss if
          an slash expresion would be first converted into a multiplication and later
          folded }
        if (nodetype=slashn) and
          { do not mess with currency and comp types }
          (not(Is_Currency(rd)) and
           not((rd.typ=floatdef) and
               (TFloatDef(rd).FloatType=s64comp)
              )
          ) and
          (((cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (rt=ordconstn)) or
           ((cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (rt=realconstn) and
            (Is_Number_Float(TRealConstNode(right).value_real) and (TRealConstNode(right).value_real<>0))
           ) or
           ((rt=realconstn) and
            (Is_Number_Float(TRealConstNode(right).value_real) and (TRealConstNode(right).value_real<>0)) and
            (BestRealRec(TRealConstNode(right).value_real).Mantissa(True)=BestRealHiddenBit)
           )
          ) then
          case rt of
            ordconstn:
              begin
                { the normal code handles div/0 }
                if (TOrdConstNode(right).Value<>0) then
                  begin
                    nodetype:=muln;
                    t:=CRealConstNode.create(1/TOrdConstNode(right).Value,resultdef);
                    right.free;
                    right:=t;
                    exit;
                  end;
              end;
            realconstn:
              begin
                nodetype:=muln;
                TRealConstNode(right).value_real:=1.0/TRealConstNode(right).value_real;
                exit;
              end;
            else
              ;
          end;
        { first, we handle widestrings, so we can check later for }
        { stringconstn only                                       }

        { widechars are converted above to widestrings too }
        { this isn't ver y efficient, but I don't think    }
        { that it does matter that much (FK)               }
        if (lt=stringconstn) and (rt=stringconstn) and
          (TStringConstNode(left).cst_type in [cst_widestring,cst_unicodestring]) and
          (TStringConstNode(right).cst_type in [cst_widestring,cst_unicodestring]) then
          begin
             InitWideString(ws1);
             InitWideString(ws2);
             CopyWideString(TStringConstNode(left).ValueWS,ws1);
             CopyWideString(TStringConstNode(right).ValueWS,ws2);
             case nodetype of
                addn :
                  begin
                     ConcatWideStrings(ws1,ws2);
                     t:=CStringConstNode.createunistr(ws1);
                  end;
                ltn :
                  t:=COrdConstNode.create(byte(CompareWideStrings(ws1,ws2)<0),PasBool1Type,true);
                lten :
                  t:=COrdConstNode.create(byte(CompareWideStrings(ws1,ws2)<=0),PasBool1Type,true);
                gtn :
                  t:=COrdConstNode.create(byte(CompareWideStrings(ws1,ws2)>0),PasBool1Type,true);
                gten :
                  t:=COrdConstNode.create(byte(CompareWideStrings(ws1,ws2)>=0),PasBool1Type,true);
                EqualN :
                  t:=COrdConstNode.create(byte(CompareWideStrings(ws1,ws2)=0),PasBool1Type,true);
                unequaln :
                  t:=COrdConstNode.create(byte(CompareWideStrings(ws1,ws2)<>0),PasBool1Type,true);
                else
                  InternalError(2008022103);
             end;
             DoneWideString(ws1);
             DoneWideString(ws2);
             result:=t;
             exit;
          end;

        { concatenating strings ? }
        concatstrings:=false;

        if (lt=ordconstn) and (rt=ordconstn) and
           Is_Char(ld) and Is_Char(rd) then
          begin
             c1[0]:=char(int64(TOrdConstNode(left).Value));
             c1[1]:=#0;
             l1:=1;
             c2[0]:=char(int64(TOrdConstNode(right).Value));
             c2[1]:=#0;
             l2:=1;
             s1:=@c1[0];
             s2:=@c2[0];
             concatstrings:=true;
          end
        else if (lt=stringconstn) and (rt=ordconstn) and Is_Char(rd) then
          begin
             l1:=TStringConstNode(left).len;
             s1:=TStringConstNode(left).asconstpchar;
             c2[0]:=char(int64(TOrdConstNode(right).Value));
             c2[1]:=#0;
             s2:=@c2[0];
             l2:=1;
             concatstrings:=true;
          end
        else if (lt=ordconstn) and (rt=stringconstn) and Is_Char(ld) then
          begin
             c1[0]:=char(int64(TOrdConstNode(left).Value));
             c1[1]:=#0;
             l1:=1;
             s1:=@c1[0];
             s2:=TStringConstNode(right).asconstpchar;
             l2:=TStringConstNode(right).len;
             concatstrings:=true;
          end
        else if (lt=stringconstn) and (rt=stringconstn) then
          begin
             s1:=TStringConstNode(left).asconstpchar;
             l1:=TStringConstNode(left).len;
             s2:=TStringConstNode(right).asconstpchar;
             l2:=TStringConstNode(right).len;
             concatstrings:=true;
          end;
        if concatstrings then
          begin
             case nodetype of
                addn :
                  begin
                    stmp:=ConcatAnsiStrings(s1,s2,l1,l2);
                    t:=CStringConstNode.createpchar(stmp,l1+l2,nil);
                    FreeMem(stmp);
                    TypeCheckPass(t);
                    if not Is_AnsiString(resultdef) or
                       (TStringDef(resultdef).encoding<>Globals.CP_NONE) then
                      TStringConstNode(t).changestringtype(resultdef)
                    else
                      TStringConstNode(t).changestringtype(GetAnsiStringDef)
                  end;
                ltn :
                  t:=COrdConstNode.create(byte(CompareAnsiStrings(s1,s2,l1,l2)<0),PasBool1Type,true);
                lten :
                  t:=COrdConstNode.create(byte(CompareAnsiStrings(s1,s2,l1,l2)<=0),PasBool1Type,true);
                gtn :
                  t:=COrdConstNode.create(byte(CompareAnsiStrings(s1,s2,l1,l2)>0),PasBool1Type,true);
                gten :
                  t:=COrdConstNode.create(byte(CompareAnsiStrings(s1,s2,l1,l2)>=0),PasBool1Type,true);
                EqualN :
                  t:=COrdConstNode.create(byte(CompareAnsiStrings(s1,s2,l1,l2)=0),PasBool1Type,true);
                unequaln :
                  t:=COrdConstNode.create(byte(CompareAnsiStrings(s1,s2,l1,l2)<>0),PasBool1Type,true);
                else
                  InternalError(2008022104);
             end;
             result:=t;
             exit;
          end;

        { set constant evaluation }
        if (right.nodetype=setconstn) and
           not Assigned(TSetConstNode(right).left) and
           (left.nodetype=setconstn) and
           not Assigned(TSetConstNode(left).left) then
          begin
             case nodetype of
               addn :
                 begin
                   resultset:=TSetConstNode(right).value_set^ + TSetConstNode(left).value_set^;
                   t:=CSetConstNode.create(@resultset,resultdef);
                 end;
                muln :
                  begin
                    resultset:=TSetConstNode(right).value_set^ * TSetConstNode(left).value_set^;
                    t:=CSetConstNode.create(@resultset,resultdef);
                  end;
               subn :
                  begin
                    resultset:=TSetConstNode(left).value_set^ - TSetConstNode(right).value_set^;
                            t:=CSetConstNode.create(@resultset,resultdef);
                  end;
               symdifn :
                  begin
                    resultset:=TSetConstNode(right).value_set^ >< TSetConstNode(left).value_set^;
                        t:=CSetConstNode.create(@resultset,resultdef);
                  end;
               unequaln :
                  begin
                    b:=TSetConstNode(right).value_set^ <> TSetConstNode(left).value_set^;
                    t:=COrdConstNode.create(byte(b),PasBool1Type,true);
                  end;
               EqualN :
                  begin
                    b:=TSetConstNode(right).value_set^ = TSetConstNode(left).value_set^;
                    t:=COrdConstNode.create(byte(b),PasBool1Type,true);
                  end;
               lten :
                  begin
                    b:=TSetConstNode(left).value_set^ <= TSetConstNode(right).value_set^;
                    t:=COrdConstNode.create(byte(b),PasBool1Type,true);
                  end;
               gten :
                  begin
                    b:=TSetConstNode(left).value_set^ >= TSetConstNode(right).value_set^;
                    t:=COrdConstNode.create(byte(b),PasBool1Type,true);
                  end;
                else
                  InternalError(2008022105);
             end;
             result:=t;
             exit;
          end;

        { in case of expressions having no side effect, we can simplify boolean expressions
          containing constants }
        if Is_Boolean(ld) and Is_Boolean(rd) then
          begin
            if is_constboolnode(left) then
              begin
                if ((nodetype=andn) and (TOrdConstNode(left).Value<>0)) or
                  ((nodetype=orn) and (TOrdConstNode(left).Value=0)) or
                  ((nodetype=xorn) and (TOrdConstNode(left).Value=0)) then
                  begin
                    Result := PruneKeepRight();
                    exit;
                  end
                else if not(might_have_sideeffects(right)) and
                  (((nodetype=orn) and (TOrdConstNode(left).Value<>0)) or
                  ((nodetype=andn) and (TOrdConstNode(left).Value=0))) then
                  begin
                    Result := PruneKeepLeft();
                    exit;
                  end
                else if ((nodetype=xorn) and (TOrdConstNode(left).Value<>0)) then
                  begin
                    Result := CNotNode.create(PruneKeepRight());
                    exit;
                  end
              end
            else if is_constboolnode(right) then
              begin
                if ((nodetype=andn) and (TOrdConstNode(right).Value<>0)) or
                  ((nodetype=orn) and (TOrdConstNode(right).Value=0)) or
                  ((nodetype=xorn) and (TOrdConstNode(right).Value=0)) then
                  begin
                    result := PruneKeepLeft();
                    exit;
                  end
                else if not(might_have_sideeffects(left)) and
                  (((nodetype=orn) and (TOrdConstNode(right).Value<>0)) or
                   ((nodetype=andn) and (TOrdConstNode(right).Value=0))) then
                  begin
                    result := PruneKeepRight();
                    exit;
                  end
                else if ((nodetype=xorn) and (TOrdConstNode(right).Value<>0)) then
                  begin
                    result := CNotNode.create(PruneKeepLeft());
                    exit;
                  end
              end;
          end;

        { optimize @<proc>=/<>@<proc>,
          such code might appear in generic specializations }
        if (nodetype in [EqualN,unequaln]) and
          (left.nodetype=typeconvn) and (Is_VoidPointer(left.resultdef)) and (TTypeConvNode(left).left.nodetype=typeconvn) and
          (TTypeConvNode(TTypeConvNode(left).left).convtype=tc_proc_2_procvar) and
          (TTypeConvNode(TTypeConvNode(left).left).left.nodetype=loadn) and
          (TTypeConvNode(TTypeConvNode(left).left).left.resultdef.typ=procdef) and
          left.isequal(right) then
          begin
            result:=COrdConstNode.create(ord(nodetype=EqualN),resultdef,false);
            exit;
          end;

        { check if
           typeinfo(<type1>)=/<>typeinfo(<type2>)
          can be evaluated at compile time
        }
        lefttarget:=actualtargetnode(@left)^;
        righttarget:=actualtargetnode(@right)^;
        if (nodetype in [EqualN,unequaln]) and (lefttarget.nodetype=inlinen) and (righttarget.nodetype=inlinen) and
          (TInlineNode(lefttarget).inlinenumber=in_typeinfo_x) and (TInlineNode(righttarget).inlinenumber=in_typeinfo_x) and
          not (TInlineNode(lefttarget).left.resultdef.typ in [undefineddef,errordef]) and
          not (TInlineNode(righttarget).left.resultdef.typ in [undefineddef,errordef]) then
          begin
            case nodetype of
              EqualN:
                result:=COrdConstNode.create(ord(TInlineNode(lefttarget).left.resultdef=TInlineNode(righttarget).left.resultdef),resultdef,false);
              unequaln:
                result:=COrdConstNode.create(ord(TInlineNode(lefttarget).left.resultdef<>TInlineNode(righttarget).left.resultdef),resultdef,false);
              else
                InternalError(2020092901);
            end;
            exit;
          end;

        if is_constpointernode(left) and is_constpointernode(right) then
          begin
            p1:=0;
            p2:=0;
            if left.nodetype=pointerconstn then
              p1:=TPointerConstNode(left).Value;
            if right.nodetype=pointerconstn then
              p2:=TPointerConstNode(right).Value;
            case nodetype of
              EqualN:
                result:=COrdConstNode.create(ord(p1=p2),Bool8Type,false);
              unequaln:
                result:=COrdConstNode.create(ord(p1<>p2),Bool8Type,false);
              gtn:
                result:=COrdConstNode.create(ord(p1>p2),Bool8Type,false);
              ltn:
                result:=COrdConstNode.create(ord(p1<p2),Bool8Type,false);
              gten:
                result:=COrdConstNode.create(ord(p1>=p2),Bool8Type,false);
              lten:
                result:=COrdConstNode.create(ord(p1<=p2),Bool8Type,false);
              else
                InternalError(2020100101);
            end;
            exit;
          end;

        { slow simplifications and/or more sophisticated transformations which might make debugging harder }
        if cs_opt_level2 in CurrentSettings.OptimizerSwitches then
          begin
            if nodetype in [addn,muln,subn] then
              begin
                { convert a+const1-const2 into a+const1+(-const2) so it is folded later on }
                if (left.nodetype=addn) and
                  (nodetype=subn) and
                  (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (rt=realconstn) and (TAddNode(left).right.nodetype=realconstn) and
                  (Compare_Defs(resultdef,ld,nothingn)=te_exact) then
                  begin
                    Result:=GetCopy;
                    Result.nodetype:=addn;
                    TAddNode(result).right:=CUnaryMinusNode.create(TAddNode(result).right);
                    exit;
                  end;

                { convert a-const1+const2 into a+(-const1)+const2 so it is folded later on }
                if (left.nodetype=subn) and
                  (nodetype=addn) and
                  (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (rt=realconstn) and (TAddNode(left).right.nodetype=realconstn) and
                  (Compare_Defs(resultdef,ld,nothingn)=te_exact) then
                  begin
                    Result:=GetCopy;
                    TAddNode(Result).left.nodetype:=addn;
                    TAddNode(TAddNode(Result).left).right:=CUnaryMinusNode.create(TAddNode(TAddNode(Result).left).right);
                    exit;
                  end;

                { try to fold
                            op
                           /  \
                         op  const1
                        /  \
                      val const2

                  while operating on strings or reals
                }
                if (left.nodetype=nodetype) and
                  (((nodetype=addn) and ((rt=stringconstn) or is_constcharnode(right)) and ((TAddNode(left).right.nodetype=stringconstn) or is_constcharnode(TAddNode(left).right))) or
                   ((nodetype in [addn,muln,subn]) and (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (rt=realconstn) and (TAddNode(left).right.nodetype=realconstn))
                  ) and
                  (Compare_Defs(resultdef,ld,nothingn)=te_exact) then
                  begin
                    { SwapRightWithLeftLeft moves the nodes around in way that we need to insert a minus
                      on left.right: a-b-c becomes b-c-a so we
                      need
                      1) insert a minus before b
                      2) make the current node an add node, see below
                    }
                    if nodetype=subn then
                      begin
                        TAddNode(left).right:=CUnaryMinusNode.create(TAddNode(left).right);
                        DoTypeCheckPass(TAddNode(left).right);
                      end;
                    Result:=SwapRightWithLeftLeft;
                    if nodetype=subn then
                      begin
                        Result.nodetype:=addn;
                        DoTypeCheckPass(Result);
                      end;
                    exit;
                  end;

                { try to fold
                              op
                             /  \
                         const1  op
                                /  \
                            const2 val

                  while operating on strings or reals
                }
                if (right.nodetype=nodetype) and
                  (((nodetype=addn) and ((lt=stringconstn) or is_constcharnode(left)) and ((TAddNode(right).left.nodetype=stringconstn) or is_constcharnode(TAddNode(right).left))) or
                   ((nodetype in [addn,muln]) and (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and (lt=realconstn) and (TAddNode(right).left.nodetype=realconstn))
                  ) and
                  (Compare_Defs(resultdef,rd,nothingn)=te_exact) then
                  begin
                    Result:=SwapLeftWithRightRight;
                    exit;
                  end;

                {
                  reorder string expressions with parentheses:
                  (s1+(s2+(s3+s4...))) into s1+s2+s3+s4 ...
                  so fpc_*_concat_multi can be used efficiently
                }
                hp:=self;
                while (hp.right.nodetype=hp.nodetype) and (hp.resultdef.typ=stringdef) and
                  (Compare_Defs(hp.resultdef,hp.right.resultdef,nothingn)=te_exact) and
                  (Compare_Defs(hp.resultdef,hp.left.resultdef,nothingn)=te_exact) and
                  (Compare_Defs(hp.resultdef,TAddNode(hp.right).left.resultdef,nothingn)=te_exact) and
                  (Compare_Defs(hp.resultdef,TAddNode(hp.right).right.resultdef,nothingn)=te_exact) do
                  begin
                    t:=hp.left;
                    hp.left:=hp.right;
                    hp.right:=TAddNode(hp.left).right;
                    TAddNode(hp.left).right:=TAddNode(hp.left).left;
                    TAddNode(hp.left).left:=t;
                    hp:=TAddNode(hp.left);
                  end;
              end;

            { the comparison is might be expensive and the nodes are usually only
              equal if some previous optimizations were done so don't check
              this simplification always
            }
            if Is_Boolean(ld) and Is_Boolean(rd) then
              begin
                { transform unsigned comparisons of (v>=x) and (v<=y)
                  into (v-x)<=(y-x)
                }
                if (nodetype in [andn,orn]) and
                   (left.nodetype in [ltn,lten,gtn,gten]) and
                   (right.nodetype in [ltn,lten,gtn,gten]) and
                   (not might_have_sideeffects(left)) and
                   (not might_have_sideeffects(right)) and
                   is_range_test(TAddNode(left),TAddNode(right),vl,cl,cr) and
                   { avoid optimization being applied to (<string. var > charconst1) and (<string. var < charconst2) }
                   (vl.resultdef.typ in [orddef,enumdef]) then
                  begin
                    hdef:=Get_Unsigned_IntType(vl.resultdef);
                    vl:=CTypeConvNode.Create_Internal(vl.GetCopy,hdef);

                    { If the condition is of the inverted form (v<x) or (v>y),
                      we have to invert the conditional result as well, since
                      the above nodes return True for if v is within the range
                      (we're merging "not ((v-x)<=(y-x))" into "(v-x)>(y-x)") }
                    if (nodetype=orn) then
                      nt:=gtn
                    else
                      nt:=lten;

                    result:=CAddNode.Create_Internal(nt,
                              CTypeConvNode.Create_Internal(CAddNode.Create_Internal(subn,vl,COrdConstNode.create(cl,hdef,false)),hdef),
                              COrdConstNode.create(cr-cl,hdef,false));

                    exit;
                  end;

                {
                  (v1=const1) and (v2=const2)
                    can be converted into
                  ((v1 xor const1) or (v2 xor const2))=0
                }
                if (nodetype=andn) and
                   (left.nodetype=EqualN) and
                   (right.nodetype=EqualN) and
                   (not might_have_sideeffects(left)) and
                   (not might_have_sideeffects(right,[mhs_exceptions])) and
                   (is_constintnode(TAddNode(left).left) or is_constintnode(TAddNode(left).right) or
                    is_constpointernode(TAddNode(left).left) or is_constpointernode(TAddNode(left).right) or
                    is_constcharnode(TAddNode(left).left) or is_constcharnode(TAddNode(left).right)) and
                   (is_constintnode(TAddNode(right).left) or is_constintnode(TAddNode(right).right) or
                    is_constpointernode(TAddNode(right).left) or is_constpointernode(TAddNode(right).right) or
                    is_constcharnode(TAddNode(right).left) or is_constcharnode(TAddNode(right).right)) then
                   begin
                     if is_constnode(TAddNode(left).left) then
                       begin
                         v1p:=@TAddNode(left).right;
                         c1p:=@TAddNode(left).left;
                       end
                     else
                       begin
                         v1p:=@TAddNode(left).left;
                         c1p:=@TAddNode(left).right;
                       end;
                     if is_constnode(TAddNode(right).left) then
                       begin
                         v2p:=@TAddNode(right).right;
                         c2p:=@TAddNode(right).left;
                       end
                     else
                       begin
                         v2p:=@TAddNode(right).left;
                         c2p:=@TAddNode(right).right;
                       end;
                     if v1p^.resultdef.Size=v2p^.resultdef.Size then
                       begin
                         case v1p^.resultdef.Size of
                           1:
                             inttype:=U8IntType;
                           2:
                             inttype:=U16IntType;
                           4:
                             inttype:=U32IntType;
                           8:
                             inttype:=U64IntType;
                           else
                             InternalError(2020060101);
                         end;

                         { Assigned compares procvar values. Preserve that
                           meaning in the casts introduced by this rewrite. }
                         value1conv:=CTypeConvNode.Create_Internal(v1p^.GetCopy,inttype);
                         value1conv.flags:=value1conv.flags+(left.flags*[nf_load_procvar]);
                         value2conv:=CTypeConvNode.Create_Internal(v2p^.GetCopy,inttype);
                         value2conv.flags:=value2conv.flags+(right.flags*[nf_load_procvar]);
                         result:=CAddNode.Create_Internal(EqualN,
                           CAddNode.Create_Internal(orn,
                             CAddNode.Create_Internal(xorn,value1conv,
                               CTypeConvNode.Create_Internal(c1p^.GetCopy,inttype)),
                             CAddNode.Create_Internal(xorn,value2conv,
                               CTypeConvNode.Create_Internal(c2p^.GetCopy,inttype))
                           ),
                           COrdConstNode.create(0,inttype,false));
                       end;
                   end;
                { even when short circuit boolean evaluation is active, this
                  optimization cannot be performed in case the node has
                  side effects, because this can change the result (e.g., in an
                  or-node that calls the same function twice and first returns
                  false and then true because of a global state change }
                if left.isequal(right) and not might_have_sideeffects(left) then
                  begin
                    case nodetype of
                      andn,orn:
                        begin
                          result:=PruneKeepLeft();
                          exit;
                        end;
                      {
                      xorn:
                        begin
                          result:=cordconstnode.create(0,resultdef,true);
                          exit;
                        end;
                      }
                      else
                        ;
                    end;
                  end
                { short to full boolean evaluation possible and useful? }
                else if not(might_have_sideeffects(right,[mhs_exceptions])) and doshortbooleval(self) then
                  begin
                    case nodetype of
                      andn,orn:
                        begin
                          { full boolean evaluation is only useful if the nodes are not too complex and if no jumps must be converted,
                            further, we need to know the expectloc }
                          if (node_complexity(right)<=2) and
                            not(left.expectloc in [LOC_JUMP,LOC_INVALID]) and not(right.expectloc in [LOC_JUMP,LOC_INVALID]) then
                            begin
                              { we need to copy the whole tree to force another pass_1 }
                              include(LocalSwitches,cs_full_boolean_eval);
                              exclude(addnodeflags,anf_short_bool);
                              result:=GetCopy;
                              exit;
                            end;
                        end;
                      else
                        ;
                    end;
                  end
              end;

            if Is_Integer(ld) and Is_Integer(rd) then
              begin
                if (cs_opt_level3 in CurrentSettings.OptimizerSwitches) and
                   left.isequal(right) and not might_have_sideeffects(left) then
                  begin
                    case nodetype of
                      andn,orn:
                        begin
                          result:=PruneKeepLeft();
                          exit;
                        end;
                      xorn,
                      subn,
                      unequaln,
                      ltn,
                      gtn:
                        begin
                          result:=COrdConstNode.create(0,resultdef,true);
                          exit;
                        end;
                      EqualN,
                      lten,
                      gten:
                        begin
                          result:=COrdConstNode.create(1,resultdef,true);
                          exit;
                        end;
                      else
                        ;
                    end;
                  end
                else if TryHandleLengthZero(left,right,nodetype,Result) then
                  exit
                   ;
              end;

            {
              compile x < length(arr) as x <= high(arr)
              compile x >= length(arr) as x > high(arr)

              tested by tests/tbs/tw40292.pas
            }
            if (nodetype in [ltn,gten]) and
              (right.nodetype=inlinen) and (TInlineNode(right).inlinenumber=in_length_x) and
              ((Is_Dynamic_Array(TInlineNode(right).left.resultdef)) or
               (Is_Open_Array(TInlineNode(right).left.resultdef))
              ) then
              begin
                case nodetype of
                  ltn:
                    result:=CAddNode.create(lten,left,CInlineNode.create(in_high_x,false,TInlineNode(right).left));
                  gten:
                    result:=CAddNode.create(gtn,left,CInlineNode.create(in_high_x,false,TInlineNode(right).left));
                  else
                    InternalError(2024041701);
                end;
                left:=nil;
                TInlineNode(right).left:=nil;
                exit;
              end;

            {
              compile length(arr) > x as high(arr) >= x
              compile length(arr) <= x as high(arr) < x

              tested by tests/tbs/tw40292.pas
            }
            if (nodetype in [lten,gtn]) and
              (left.nodetype=inlinen) and (TInlineNode(left).inlinenumber=in_length_x) and
              ((Is_Dynamic_Array(TInlineNode(left).left.resultdef)) or
               (Is_Open_Array(TInlineNode(left).left.resultdef))
              ) then
              begin
                case nodetype of
                  gtn:
                    result:=CAddNode.create(gten,CInlineNode.create(in_high_x,false,TInlineNode(left).left),right);
                  lten:
                    result:=CAddNode.create(ltn,CInlineNode.create(in_high_x,false,TInlineNode(left).left),right);
                  else
                    InternalError(2024041701);
                end;
                right:=nil;
                TInlineNode(left).left:=nil;
                exit;
              end;

            { using sqr(x) for reals instead of x*x might reduces register pressure and/or
              memory accesses while sqr(<real>) has no drawback }
            if
               (nodetype=muln) and
               Is_Real(ld) and Is_Real(rd) and
               left.isequal(right) and
               not(might_have_sideeffects(left)) then
              begin
                result:=CInlineNode.create(in_sqr_real,false,PruneKeepLeft());
                inserttypeconv(result,resultdef);
                exit;
              end;
{$ifdef cpurox}
            { optimize (i shl x) or (i shr (bitsizeof(i)-x)) into rol(x,i) (and different flavours with shl/shr swapped etc.) }
            if (nodetype in [addn,orn]) { add also works here }
{$ifndef cpu64bitalu}
               and (ld.typ=orddef) and
               not(TOrdDef(ld).OrdType in [s64bit,u64bit,scurrency])
{$endif cpu64bitalu}
              then
              begin
                if (left.nodetype=shln) and (right.nodetype=shrn) then
                  begin
                    result:=CheckRotateOptimization(in_rol_x_y,in_ror_x_y);
                    if Assigned(result) then
                      Exit;
                  end
                else if (left.nodetype=shrn) and (right.nodetype=shln) then
                  begin
                    result:=CheckRotateOptimization(in_ror_x_y,in_rol_x_y);
                    if Assigned(result) then
                      Exit;
                  end
              end;
{$endif cpurox}
            { optimize

                (a and b) or (c and not(b))

                into

                c xor ((c xor a) and b)
            }
            if (nodetype=orn) and
             (ld.typ=orddef) and
             (left.nodetype=andn) and
             (right.nodetype=andn) and
             (not(Is_Boolean(resultdef)) or not(might_have_sideeffects(self,[mhs_exceptions])) or not(doshortbooleval(self))) and
             { this test is not needed but it speeds up the test and allows to bail out early }
             ((TAddNode(left).left.nodetype=notn) or (TAddNode(left).right.nodetype=notn) or
              (TAddNode(right).left.nodetype=notn) or (TAddNode(right).right.nodetype=notn)
             ) and
             not(might_have_sideeffects(self)) then
             begin
               if MatchAndTransformNodesCommutative(TAddNode(left).left,TAddNode(left).right,TAddNode(right).left,TAddNode(right).right,
                 @IsAndOrAndNot,@TransformAndOrAndNot,Result) then
                 exit;
             end;
            { optimize tests for a single bit:
              (a and one_bit_mask_const) = <> one_bit_mask_const

              into

              (a and one_bit_mask_const) <> = 0
            }
            if (nodetype in [EqualN,unequaln]) then
              begin
                if (lt=andn) and (rt=ordconstn) then
                  begin
                    t:=left;
                    cr:=TOrdConstNode(right).Value;
                  end
                else
                  if (rt=andn) and (lt=ordconstn) then
                    begin
                      t:=right;
                      cr:=TOrdConstNode(left).Value;
                    end
                  else
                    begin
                      t:=nil;
                      cr:=0;
                    end;
                { using cr.uvalue is fine as we are interested only in the bit pattern }
                if (t<>nil) and (PopCnt(cr.uvalue) = 1) then
                  begin
                    if is_constintnode(TAddNode(t).left) then
                      vl:=TAddNode(t).left
                    else
                      if is_constintnode(TAddNode(t).right) then
                        vl:=TAddNode(t).right
                      else
                        vl:=nil;
                    if (vl<>nil) and (TOrdConstNode(vl).Value=cr) then
                      begin
                        if nodetype=EqualN then
                          nt:=unequaln
                        else
                          nt:=EqualN;
                        result:=CAddNode.create(nt,t,COrdConstNode.create(0,vl.resultdef,false));
                        Include(transientflags,tnf_do_not_execute);
                        if t=left then
                          left:=nil
                        else
                          right:=nil;
                        exit;
                      end;
                  end;
              end;
          end;
      end;


    function TAddNode.dogetcopy: TNode;
      var
        n: TAddNode;
      begin
        n:=TAddNode(inherited dogetcopy);
        n.addnodeflags:=addnodeflags;
        n.resultrealdef:=resultrealdef;
        result:=n;
      end;


    function TAddNode.docompare(p: TNode): boolean;
      begin
        result:=
          inherited docompare(p) and
          Equal_Defs(TAddNode(p).resultrealdef,resultrealdef);
      end;


    procedure TAddNode.printnodedata(var t: text);
      var
        i: TAddNodeFlag;
        first: Boolean;
      begin
        write(t,PrintNodeIndention,'addnodeflags = [');
        first:=true;
        for i:=low(TAddNodeFlag) to high(TAddNodeFlag) do
          if i in addnodeflags then
            begin
              if not(first) then
                write(t,',')
              else
                first:=false;
              write(t, i);
            end;
        WriteLn(t,']');
        inherited printnodedata(t);
      end;


    function TAddNode.pass_typecheck:TNode;
      begin
        { This function is small to keep the stack small for recursive of
          large + operations }
        TypeCheckPass(left);
        TypeCheckPass(right);
        result:=pass_typecheck_internal;
      end;


    function TAddNode.pass_typecheck_internal:TNode;
      var
        hp          : TNode;
        rd,ld,nd    : TDef;
        hsym        : TFieldVarSym;
        llow,lhigh,
        rlow,rhigh  : TConstExprInt;
        strtype     : TStringType;
        res,
        b           : boolean;
        lt,rt       : TNodeType;
        ot          : TNodeType;
{$ifdef state_tracking}
        factval     : TNode;
        change      : boolean;
{$endif}

        function maybe_cast_ordconst(var n: TNode; adef: TDef): boolean;
          begin
            result:=(TOrdConstNode(n).Value>=TOrdDef(adef).low) and
              (TOrdConstNode(n).Value<=TOrdDef(adef).high);
            if result then
              inserttypeconv(n,adef);
          end;

        function maybe_convert_to_insert:TNode;

          function element_count(arrconstr: TArrayConstructorNode):asizeint;
            begin
              result:=0;
              while Assigned(arrconstr) do
                begin
                  if arrconstr.nodetype=arrayconstructorrangen then
                    InternalError(2018052501);
                  inc(result);
                  arrconstr:=TArrayConstructorNode(TArrayConstructorNode(arrconstr).right);
                end;
            end;

          var
            elem : TNode;
            para : TCallParaNode;
            isarrconstrl,
            isarrconstrr : boolean;
            index : asizeint;
          begin
            result:=nil;

            isarrconstrl:=left.nodetype=arrayconstructorn;
            isarrconstrr:=right.nodetype=arrayconstructorn;

            if not Assigned(aktassignmentnode) or
                (aktassignmentnode.right<>self) or
                not(
                  isarrconstrl or
                  isarrconstrr
                ) or
                not(
                  left.isequal(aktassignmentnode.left) or
                  right.isequal(aktassignmentnode.left)
                ) or
                not valid_for_var(aktassignmentnode.left,false) or
                (isarrconstrl and (element_count(TArrayConstructorNode(left))>1)) or
                (isarrconstrr and (element_count(TArrayConstructorNode(right))>1)) then
              exit;

            if isarrconstrl then
              begin
                index:=0;
                elem:=TArrayConstructorNode(left).left;
                TArrayConstructorNode(left).left:=nil;
              end
            else
              begin
                index:=high(asizeint);
                elem:=TArrayConstructorNode(right).left;
                TArrayConstructorNode(right).left:=nil;
              end;

            { we use the fact that insert() caps the index to avoid a copy }
            para:=CCallParaNode.create(
                    COrdConstNode.create(index,SizeSIntType,false),
                    CCallParaNode.create(
                      aktassignmentnode.left.GetCopy,
                      CCallParaNode.create(
                        elem,nil)));

            result:=CInlineNode.create(in_insert_x_y_z,false,para);
            include(aktassignmentnode.assignmentnodeflags,anf_assign_done_in_right);
          end;

      begin
         result:=nil;
         rlow:=0;
         llow:=0;
         rhigh:=0;
         lhigh:=0;

         { avoid any problems with type parameters later on }
         if Is_TypeParam(left.resultdef) or Is_TypeParam(right.resultdef) then
           begin
             resultdef:=CUndefinedType;
             exit;
           end;

         { both left and right need to be valid }
         set_varstate(left,vs_read,[vsf_must_be_valid]);
         set_varstate(right,vs_read,[vsf_must_be_valid]);
         if CodeGenError then
           exit;

         { tp procvar support. Omit for converted assigned() nodes }
         if not (nf_load_procvar in flags) then
           begin
             maybe_call_procvar(left,true);
             maybe_call_procvar(right,true);
           end
         else
           if not (nodetype in [EqualN,unequaln]) then
             InternalError(2013091601);

         { allow operator overloading }
         hp:=self;

         if Is_Array_Constructor(left.resultdef) or Is_Array_Constructor(right.resultdef) then
           begin
             { check whether there is a suitable operator for the array constructor
               (but only if the "+" array operator isn't used), if not fall back to sets }
             if (
                   (nodetype<>addn) or
                   not (m_array_operators in CurrentSettings.ModeSwitches) or
                   (Is_Array_Constructor(left.resultdef) and not Is_Dynamic_Array(right.resultdef)) or
                   (not Is_Dynamic_Array(left.resultdef) and Is_Array_Constructor(right.resultdef))
                 ) and
                 not isbinaryoverloaded(hp,[ocf_check_only]) then
               begin
                 if Is_Array_Constructor(left.resultdef) then
                   begin
                     arrayconstructor_to_set(left);
                     TypeCheckPass(left);
                   end;
                 if Is_Array_Constructor(right.resultdef) then
                   begin
                     arrayconstructor_to_set(right);
                     TypeCheckPass(right);
                   end;
               end;
           end;

         if Is_Dynamic_Array(left.resultdef) and Is_Dynamic_Array(right.resultdef) and
             (nodetype=addn) and
             (m_array_operators in CurrentSettings.ModeSwitches) and
             isbinaryoverloaded(hp,[ocf_check_non_overloadable,ocf_check_only]) then
           message3(parser_w_operator_overloaded_hidden_3,left.resultdef.TypeName,arraytokeninfo[_PLUS].str,right.resultdef.TypeName);

         if isbinaryoverloaded(hp,[]) then
           begin
              result:=hp;
              exit;
           end;
         { Stop checking when an error was found in the operator checking }
         if CodeGenError then
           begin
             result:=CErrorNode.create;
             exit;
           end;

         { Kylix allows enum+ordconstn in an enum type declaration, we need to do
           the conversion here before the constant folding }
         if (m_delphi in CurrentSettings.ModeSwitches) and
            (blocktype in [bt_type,bt_const_type,bt_var_type]) then
          begin
            if (left.resultdef.typ=enumdef) and
               (right.resultdef.typ=orddef) then
             begin
               { insert explicit typecast to default signed int }
               left:=CTypeConvNode.Create_Internal(left,SIntType);
               TypeCheckPass(left);
             end
            else
             if (left.resultdef.typ=orddef) and
                (right.resultdef.typ=enumdef) then
              begin
                { insert explicit typecast to default signed int }
                right:=CTypeConvNode.Create_Internal(right,SIntType);
                TypeCheckPass(right);
              end;
          end;

        { is one a real float, then both need to be floats, this
          need to be done before the constant folding so constant
          operation on a float and int are also handled }
{$ifdef x86}
        { use extended as default real type only when the x87 fpu is used }
  {$if defined(i386)}
        if not(CurrentSettings.FPUType=fpu_x87) then
          resultrealdef:=S64FloatType
        else
          resultrealdef:=PBestRealType^;
  {$endif i386}
  {$ifdef x86_64}
        { x86-64 has no x87 only mode, so use always double as default }
        resultrealdef:=S64FloatType;
  {$endif x86_6}
{$else not x86}
        resultrealdef:=PBestRealType^;
{$endif not x86}

        if (right.resultdef.typ=floatdef) or (left.resultdef.typ=floatdef) then
         begin
           { when both floattypes are already equal then use that
             floattype for results }
           if (right.resultdef.typ=floatdef) and
              (left.resultdef.typ=floatdef) and
              (TFloatDef(left.resultdef).FloatType=TFloatDef(right.resultdef).FloatType) and
              not(TFloatDef(left.resultdef).FloatType in [s64comp,s64currency]) then
             begin
               if cs_excessprecision in CurrentSettings.LocalSwitches then
                 begin
                   resultrealdef:=PBestRealType^;
                   inserttypeconv(right,resultrealdef);
                   inserttypeconv(left,resultrealdef);
                 end
               else
                 resultrealdef:=left.resultdef
             end
           { when there is a currency type then use currency, but
             only when currency is defined as float }
           else
            if (Is_Currency(right.resultdef) or
                Is_Currency(left.resultdef)) and
               ((S64CurrencyType.typ = floatdef) or
                (nodetype <> slashn)) then
             begin
               resultrealdef:=S64CurrencyType;
               if (nodetype = muln) then
                 begin
                   { See if we can minimise any unnecessary scaling that might
                     cause precision problems }
                   if (nf_is_currency in right.flags) then
                     begin
                       if (nf_is_currency in left.flags) then
                         begin
                           inserttypeconv(right,resultrealdef);
                           inserttypeconv(left,resultrealdef);
                         end
                       else
                         begin
                           inserttypeconv(right,resultrealdef);
                           inserttypeconv_internal(left,resultrealdef)
                         end;
                     end
                   else
                     begin
                       if (nf_is_currency in left.flags) then
                         begin
                           inserttypeconv_internal(right,resultrealdef);
                           inserttypeconv(left,resultrealdef);
                         end
                       else
                         begin
                           inserttypeconv(right,resultrealdef);
                           inserttypeconv(left,resultrealdef);
                         end;
                     end;
                 end
               else
                 begin
                   inserttypeconv(right,resultrealdef);
                   inserttypeconv(left,resultrealdef);
                 end;
             end
           else
            begin
              resultrealdef:=getbestreal(left.resultdef,right.resultdef);
              inserttypeconv(right,resultrealdef);
              inserttypeconv(left,resultrealdef);
            end;
         end;

        { If both operands are constant and there is a unicodestring
          or unicodestring then convert everything to unicodestring }
        if is_constnode(right) and is_constnode(left) and
           (Is_UnicodeString(right.resultdef) or
            Is_UnicodeString(left.resultdef)) then
          begin
            inserttypeconv(right,CUnicodeStringType);
            inserttypeconv(left,CUnicodeStringType);
          end;

        { If both operands are constant and there is a widechar
          or widestring then convert everything to widestring. This
          allows constant folding like char+widechar }
        if is_constnode(right) and is_constnode(left) and
           (Is_WideString(right.resultdef) or
            Is_WideString(left.resultdef) or
            Is_WideChar(right.resultdef) or
            Is_WideChar(left.resultdef)) then
          begin
            inserttypeconv(right,CWideStringType);
            inserttypeconv(left,CWideStringType);
          end;

        { load easier access variables }
        rd:=right.resultdef;
        ld:=left.resultdef;
        rt:=right.nodetype;
        lt:=left.nodetype;

         { 4 character constant strings are compatible with orddef }
         { in macpas mode (become cardinals)                       }
         if (m_mac in CurrentSettings.ModeSwitches) and
            { only allow for comparisons, additions etc are }
            { normally program errors                       }
            (nodetype in [ltn,lten,gtn,gten,unequaln,EqualN]) and
            (((lt=stringconstn) and
              (TStringConstNode(left).len=4) and
              (rd.typ=orddef)) or
             ((rt=stringconstn) and
              (TStringConstNode(right).len=4) and
              (ld.typ=orddef))) then
           begin
             if (rt=stringconstn) then
               begin
                 inserttypeconv(right,U32IntType);
                 rt:=right.nodetype;
                 rd:=right.resultdef;
               end
             else
               begin
                 inserttypeconv(left,U32IntType);
                 lt:=left.nodetype;
                 ld:=left.resultdef;
               end;
           end;

         { but an int/int gives real/real! }
         if (nodetype=slashn) and not(Is_Vector(left.resultdef)) and not(Is_Vector(right.resultdef)) then
          begin
            if Is_Currency(left.resultdef) and
               Is_Currency(right.resultdef) then
              { In case of currency, converting to float means dividing by 10000 }
              { However, since this is already a division, both divisions by     }
              { 10000 are eliminated when we divide the results -> we can skip   }
              { them.                                                            }
              if S64CurrencyType.typ = floatdef then
                begin
                  { there's no s64comptype or so, how do we avoid the type conversion?
                  left.resultdef := s64comptype;
                  right.resultdef := s64comptype; }
                end
              else
                begin
                  left.resultdef := S64IntType;
                  right.resultdef := S64IntType;
                end;
            if CurrentSettings.FPUType=fpu_none then
              begin
                Message(parser_e_unsupported_real);
                result:=CErrorNode.create;
                exit;
              end
            else
              begin
                inserttypeconv(right,resultrealdef);
                inserttypeconv(left,resultrealdef);
              end;
          end

         { if both are orddefs then check sub types }
         else if (ld.typ=orddef) and (rd.typ=orddef) then
           begin
              { set for & and | operations in macpas mode: they only work on }
              { booleans, and always short circuit evaluation                }
              if (anf_short_bool in addnodeflags) then
                begin
                  if not Is_Boolean(ld) then
                    begin
                      inserttypeconv(left,PasBool1Type);
                      ld := left.resultdef;
                    end;
                  if not Is_Boolean(rd) then
                    begin
                      inserttypeconv(right,PasBool1Type);
                      rd := right.resultdef;
                    end;
                end;

             { 2 booleans? }
             if (Is_Boolean(ld) and Is_Boolean(rd)) then
              begin
                case nodetype of
                  xorn,
                  andn,
                  orn:
                    begin
                      { in case of xor or 'and' with cbool: convert both to Pascal bool and then
                        perform the xor/and to prevent issues with "longbool(1) and/xor
                        longbool(2)" }
                      if (Is_CBool(ld) or Is_CBool(rd)) and
                         (nodetype in [xorn,andn]) then
                        begin
                          resultdef:=nil;
                          if Is_CBool(ld) then
                            begin
                              left:=CTypeConvNode.create(left,PasBool8Type);
                              TTypeConvNode(left).convtype:=tc_bool_2_bool;
                              FirstPass(left);
                              if not Is_CBool(rd) or
                                 (ld.Size>=rd.Size) then
                                resultdef:=ld;
                            end;
                          if Is_CBool(rd) then
                            begin
                              right:=CTypeConvNode.Create(right,PasBool8Type);
                              TTypeConvNode(right).convtype:=tc_bool_2_bool;
                              FirstPass(right);
                              if not Assigned(resultdef) then
                                resultdef:=rd;
                            end;
                          result:=CTypeConvNode.create_explicit(CAddNode.create(nodetype,left,right),resultdef);
                          TTypeConvNode(result).convtype:=tc_bool_2_bool;
                          left:=nil;
                          right:=nil;
                          exit;
                        end;
                      { Make sides equal to the largest boolean }
                      if (TOrdDef(left.resultdef).Size>TOrdDef(right.resultdef).Size) or
                        (Is_CBool(left.resultdef) and not Is_CBool(right.resultdef)) then
                        begin
                          right:=CTypeConvNode.Create_Internal(right,left.resultdef);
                          TTypeConvNode(right).convtype:=tc_bool_2_bool;
                          TypeCheckPass(right);
                        end
                      else if (TOrdDef(left.resultdef).Size<TOrdDef(right.resultdef).Size) or
                        (not Is_CBool(left.resultdef) and Is_CBool(right.resultdef)) then
                        begin
                          left:=CTypeConvNode.Create_Internal(left,right.resultdef);
                          TTypeConvNode(left).convtype:=tc_bool_2_bool;
                          TypeCheckPass(left);
                        end;
                    end;
                  ltn,
                  lten,
                  gtn,
                  gten:
                    begin
                      { convert both to pasbool to perform the comparison (so
                        that longbool(4) = longbool(2), since both represent
                        "true" }
                      inserttypeconv(left,PasBool1Type);
                      inserttypeconv(right,PasBool1Type);
                    end;
                  unequaln,
                  EqualN:
                    begin
                      { Remove any compares with constants }
                      if (left.nodetype=ordconstn) then
                        begin
                          hp:=right;
                          b:=(TOrdConstNode(left).Value<>0);
                          ot:=nodetype;
                          right:=nil;
                          if (not(b) and (ot=EqualN)) or
                             (b and (ot=unequaln)) then
                           begin
                             hp:=CNotNode.create(hp);
                           end;
                          result:=hp;
                          exit;
                        end;
                      if (right.nodetype=ordconstn) then
                        begin
                          hp:=left;
                          b:=(TOrdConstNode(right).Value<>0);
                          ot:=nodetype;
                          left:=nil;
                          if (not(b) and (ot=EqualN)) or
                             (b and (ot=unequaln)) then
                           begin
                             hp:=CNotNode.create(hp);
                           end;
                          result:=hp;
                          exit;
                        end;
                      { Delphi-compatibility: convert both to pasbool to
                        perform the equality comparison }
                      inserttypeconv(left,PasBool1Type);
                      inserttypeconv(right,PasBool1Type);
                    end;
                  else
                    begin
                      CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
                      result:=CNothingNode.create;
                      exit;
                    end;
                end;
              end
             { Both are chars? }
             else if Is_Char(rd) and Is_Char(ld) then
               begin
                 if nodetype=addn then
                  begin
                    resultdef:=CShortStringType;
                    if not(is_constcharnode(left) and is_constcharnode(right)) then
                     begin
                       inserttypeconv(left,CShortStringType);
{$ifdef addstringopt}
                       hp := genaddsstringcharoptnode(self);
                       result := hp;
                       exit;
{$endif addstringopt}
                     end
                  end
                else if not(nodetype in [ltn,lten,gtn,gten,unequaln,EqualN]) then
                  begin
                    CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
                    result:=CNothingNode.create;
                    exit;
                  end;
               end
             { There is a widechar? }
             else if Is_WideChar(rd) or Is_WideChar(ld) then
               begin
                 { widechar+widechar gives unicodestring }
                 if nodetype=addn then
                   begin
                     inserttypeconv(left,CUnicodeStringType);
                     if (TOrdDef(rd).OrdType<>uwidechar) then
                       inserttypeconv(right,CWideCharType);
                     resultdef:=CUnicodeStringType;
                   end
                 else
                   begin
                     if (TOrdDef(ld).OrdType<>uwidechar) then
                       inserttypeconv(left,CWideCharType);
                     if (TOrdDef(rd).OrdType<>uwidechar) then
                       inserttypeconv(right,CWideCharType);
                   end;
               end
             { is there a currency type ? }
             else if ((TOrdDef(rd).OrdType=scurrency) or (TOrdDef(ld).OrdType=scurrency)) then
               begin
                 if (nodetype=muln) and
                   { Is only one currency? }
                   (
                     (TOrdDef(ld).OrdType=scurrency) xor (TOrdDef(rd).OrdType=scurrency)
                   ) then
                   begin
                     { Don't actually set the nf_is_currency flag, as it doesn't
                       need scaling }
                     if (TOrdDef(ld).OrdType<>scurrency) then
                       begin
                         left:=CTypeConvNode.Create_Internal(left,S64CurrencyType);
                         TypeCheckPass(left);
                       end
                     else
                       begin
                         right:=CTypeConvNode.Create_Internal(right,S64CurrencyType);
                         TypeCheckPass(right);
                       end;
                   end
                 else
                   begin
                     if (TOrdDef(ld).OrdType<>scurrency) then
                       inserttypeconv(left,S64CurrencyType);
                     if (TOrdDef(rd).OrdType<>scurrency) then
                       inserttypeconv(right,S64CurrencyType);
                   end;
               end
             { leave some constant integer expressions alone in case the
               resultdef of the integer types doesn't influence the outcome,
               because the forced type conversions below can otherwise result
               in unexpected results (such as high(qword)<high(int64) returning
               true because high(qword) gets converted to int64) }
             else if Is_Integer(ld) and Is_Integer(rd) and
                     (lt=ordconstn) and (rt=ordconstn) and
                     (nodetype in [EqualN,unequaln,gtn,gten,ltn,lten]) then
               begin
               end
             { "and" does't care about the sign of integers }
             { "xor", "or" and compares don't need extension to native int }
             { size either as long as both values are signed or unsigned   }
             { "xor" and "or" also don't care about the sign if the values }
             { occupy an entire register                                   }
             { don't do it if either type is 64 bit (except for "and"),    }
             { since in that case we can't safely find a "common" type     }
             else if Is_Integer(ld) and Is_Integer(rd) and
                     ((nodetype=andn) or
                      ((nodetype in [orn,xorn,EqualN,unequaln,gtn,gten,ltn,lten]) and
                        not Is_64BitInt(ld) and not Is_64BitInt(rd) and
                       (Is_Signed(ld)=Is_Signed(rd)))) then
               begin
                 { Delphi-compatible: prefer unsigned type for "and", when the
                   unsigned type is bigger than the signed one, and also bigger
                   than min(native_int, 32-bit) }
                 if (Is_OversizedInt(rd) or Is_NativeInt(rd) or Is_32BitInt(rd)) and
                    (rd.Size>=ld.Size) and
                    not Is_Signed(rd) and Is_Signed(ld) then
                      inserttypeconv_internal(left,rd)
                 else if (Is_OversizedInt(ld) or Is_NativeInt(ld) or Is_32BitInt(ld)) and
                    (ld.Size>=rd.Size) and
                    not Is_Signed(ld) and Is_Signed(rd) then
                      inserttypeconv_internal(right,ld)
                 else
                   begin
                     { not to left right.resultdef, because that may
                       cause a range error if left and right's def don't
                       completely overlap }
                     nd:=Get_Common_IntDef(TOrdDef(ld),TOrdDef(rd),true);
                     inserttypeconv(left,nd);
                     inserttypeconv(right,nd);
                   end;
               end
             { don't extend (sign-mismatched) comparisons if either side is a constant
               whose value is within range of opposite side }
             else if Is_Integer(ld) and Is_Integer(rd) and
                     (nodetype in [EqualN,unequaln,gtn,gten,ltn,lten]) and
                     (Is_Signed(ld)<>Is_Signed(rd)) and
                     (
                       ((lt=ordconstn) and maybe_cast_ordconst(left,rd)) or
                       ((rt=ordconstn) and maybe_cast_ordconst(right,ld))
                     ) then
               begin
                 { done here }
               end
             { is there a signed 64 bit type ? }
             else if ((TOrdDef(rd).OrdType=s64bit) or (TOrdDef(ld).OrdType=s64bit)) then
               begin
                  if (TOrdDef(ld).OrdType<>s64bit) then
                   inserttypeconv(left,S64IntType);
                  if (TOrdDef(rd).OrdType<>s64bit) then
                   inserttypeconv(right,S64IntType);
               end
             { is there a unsigned 64 bit type ? }
             else if ((TOrdDef(rd).OrdType=u64bit) or (TOrdDef(ld).OrdType=u64bit)) then
               begin
                  if (TOrdDef(ld).OrdType<>u64bit) then
                   inserttypeconv(left,U64IntType);
                  if (TOrdDef(rd).OrdType<>u64bit) then
                   inserttypeconv(right,U64IntType);
               end
             { is there a larger int? }
             else if Is_OversizedInt(rd) or Is_OversizedInt(ld) then
               begin
                 nd:=Get_Common_IntDef(TOrdDef(ld),TOrdDef(rd),false);
                 inserttypeconv(right,nd);
                 inserttypeconv(left,nd);
               end
             { is there a native unsigned int? }
             else if Is_NativeUInt(rd) or Is_NativeUInt(ld) then
               begin
                 { convert positive constants to uinttype }
                 if (not Is_NativeUInt(ld)) and
                    is_constintnode(left) and
                    (TOrdConstNode(left).Value >= 0) then
                   inserttypeconv(left,UIntType);
                 if (not Is_NativeUInt(rd)) and
                    is_constintnode(right) and
                    (TOrdConstNode(right).Value >= 0) then
                   inserttypeconv(right,UIntType);
                 { when one of the operand is signed or the operation is subn then perform
                   the operation in a larger signed type, can't use rd/ld here because there
                   could be already typeconvs inserted.
                   This is compatible with the code below for other unsigned types (PFV) }
                 if Is_Signed(left.resultdef) or
                    Is_Signed(right.resultdef) or
                    ((nodetype=subn)

                    ) then
                   begin
                     if nodetype<>subn then
                       CGMessage(type_h_mixed_signed_unsigned);
                     { mark as internal in case added for a subn, so }
                     { ttypeconvnode.simplify can remove the larger  }
                     { typecast again if semantically correct. Even  }
                     { if we could detect that here already, we      }
                     { mustn't do it here because that would change  }
                     { overload choosing behaviour etc. The code in  }
                     { ncnv.pas is run after that is already decided }
                     if (not Is_Signed(left.resultdef) and
                         not Is_Signed(right.resultdef)) or
                        (nodetype in [orn,xorn]) then
                       include(flags,nf_internal);
                     { get next larger signed int type }
                     nd:=Get_Common_IntDef(TOrdDef(SIntType),TOrdDef(UIntType),false);
                     inserttypeconv(left,nd);
                     inserttypeconv(right,nd);
                   end
                 else
                   begin
                     if not Is_NativeUInt(left.resultdef) then
                       inserttypeconv(left,UIntType);
                     if not Is_NativeUInt(right.resultdef) then
                       inserttypeconv(right,UIntType);
                   end;
               end
             { generic ord conversion is sinttype }
             else
               begin
                 { When there is a signed type or there is a minus operation
                   or in TP mode for 16-bit CPUs
                   we convert to signed int. Otherwise (both are unsigned) we keep
                   the result also unsigned. This is compatible with Delphi (PFV) }
                 if Is_Signed(ld) or
                    Is_Signed(rd) or
                    (([m_iso,m_extpas]*CurrentSettings.ModeSwitches)<>[]) or

                    (nodetype=subn) then
                   begin
                     inserttypeconv(right,SIntType);
                     inserttypeconv(left,SIntType);
                   end
                 else
                   begin
                     inserttypeconv(right,UIntType);
                     inserttypeconv(left,UIntType);
                   end;
               end;
           end

         { if both are floatdefs, conversion is already done before constant folding }
         else if (ld.typ=floatdef) then
           begin
             if not(nodetype in [addn,subn,muln,slashn,EqualN,unequaln,ltn,lten,gtn,gten]) then
               CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
           end

         { left side a setdef, must be before string processing,
           else array constructor can be seen as array of char (PFV) }
         else if (ld.typ=setdef) then
          begin
             if not(nodetype in [addn,subn,symdifn,muln,EqualN,unequaln,lten,gten]) then
              CGMessage(type_e_set_operation_unknown);
             { right must either be a set or a set element }
             if (rd.typ<>setdef) and
                (rt<>setelementn) then
               CGMessage(type_e_mismatch)
             { Make operands the same setdef. If one's elementtype fits   }
             { entirely inside the other's, pick the one with the largest }
             { range.  Otherwise create a new setdef with a range which   }
             { can contain both.                                          }
             else if not(Equal_Defs(ld,rd)) then
              begin
                { note: ld cannot be an empty set with elementdef=nil in }
                { case right is not a set, arrayconstructor_to_set takes }
                { care of that                                           }

                { 1: rd is a set with an assigned elementdef, and ld is    }
                {    either an empty set without elementdef or a set whose }
                {    elementdef fits in rd's elementdef -> convert to rd   }
                if ((rd.typ=setdef) and
                    Assigned(TSetDef(rd).ElementDef) and
                    (not Assigned(TSetDef(ld).ElementDef) or
                     Is_In_Limit(ld,rd))) then
                  inserttypeconv(left,rd)
                { 2: rd is either an empty set without elementdef or a set }
                {    whose elementdef fits in ld's elementdef, or a set    }
                {    element whose def fits in ld's elementdef -> convert  }
                {    to ld. ld's elementdef can't be nil here, is caught   }
                {    previous case and "note:" above                       }
                else if ((rd.typ=setdef) and
                         (not Assigned(TSetDef(rd).ElementDef) or
                          Is_In_Limit(rd,ld))) or
                        ((rd.typ<>setdef) and
                         Is_In_Limit(rd,TSetDef(ld).ElementDef)) then
                   if (rd.typ=setdef) then
                    inserttypeconv(right,ld)
                  else
                    inserttypeconv(right,TSetDef(ld).ElementDef)
                { 3: otherwise create setdef which encompasses both, taking }
                {    into account empty sets without elementdef             }
                else
                  begin
                    if Assigned(TSetDef(ld).ElementDef) then
                      begin
                        llow:=TSetDef(ld).SetLow;
                        lhigh:=TSetDef(ld).SetMax;
                      end;
                    if (rd.typ=setdef) then
                      if Assigned(TSetDef(rd).ElementDef) then
                        begin
                          rlow:=TSetDef(rd).SetLow;
                          rhigh:=TSetDef(rd).SetMax;
                        end
                      else
                        begin
                          { ld's elementdef must have been valid }
                          rlow:=llow;
                          rhigh:=lhigh;
                        end
                    else
                      GetRange(rd,rlow,rhigh);
                    if not Assigned(TSetDef(ld).ElementDef) then
                      begin
                        llow:=rlow;
                        lhigh:=rhigh;
                      end;
                    nd:=CSetDef.create(TSetDef(ld).ElementDef,min(llow,rlow).svalue,max(lhigh,rhigh).svalue,true);
                    inserttypeconv(left,nd);
                    if (rd.typ=setdef) then
                      inserttypeconv(right,nd)
                    else
                       inserttypeconv(right,TSetDef(nd).ElementDef);
                  end;
              end;
          end
         { pointer comparison and subtraction }
         else if (
                  (rd.typ=pointerdef) and (ld.typ=pointerdef)
                 ) or
                 { compare/add pchar to variable (not stringconst) char arrays
                   by addresses like BP/Delphi }
                 (
                  (nodetype in [EqualN,unequaln,subn,addn]) and
                  (
                   ((Is_PChar(ld) or (lt=niln)) and Is_CharArray(rd) and (rt<>stringconstn)) or
                   ((Is_PChar(rd) or (rt=niln)) and Is_CharArray(ld) and (lt<>stringconstn))
                  )
                 ) then
          begin
            { convert char array to pointer }
            if Is_CharArray(rd) then
              begin
                inserttypeconv(right,CharPointerType);
                rd:=right.resultdef;
              end
            else if Is_CharArray(ld) then
              begin
                inserttypeconv(left,CharPointerType);
                ld:=left.resultdef;
              end;

            case nodetype of
               EqualN,unequaln :
                 begin
                    if Is_VoidPointer(right.resultdef) then
                      inserttypeconv(right,left.resultdef)
                    else if Is_VoidPointer(left.resultdef) then
                      inserttypeconv(left,right.resultdef)
                    else if not(Equal_Defs(ld,rd)) then
                      IncompatibleTypes(ld,rd);
                 end;
               ltn,lten,gtn,gten:
                 begin
                    if (cs_extsyntax in CurrentSettings.ModuleSwitches) or
                       (nf_internal in flags) then
                     begin
                       if Is_VoidPointer(right.resultdef) then
                        inserttypeconv(right,left.resultdef)
                       else if Is_VoidPointer(left.resultdef) then
                        inserttypeconv(left,right.resultdef)
                       else if not (
                           { in Delphi two different pointer types can be compared
                             if either $POINTERMATH is currently enabled or if
                             both pointer defs were declared with $POINTERMATH
                             enabled }
                           (m_delphi in CurrentSettings.ModeSwitches) and
                           (ld.typ=pointerdef) and
                           (rd.typ=pointerdef) and
                           (
                             (cs_pointermath in CurrentSettings.LocalSwitches) or
                             (
                               TPointerDef(ld).HasPointerMath and
                               TPointerDef(rd).HasPointerMath
                             )
                           )
                         ) and not(Equal_Defs(ld,rd)) then
                        IncompatibleTypes(ld,rd);
                     end
                    else
                     CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
                 end;
               subn:
                 begin
                    if (cs_extsyntax in CurrentSettings.ModuleSwitches) or
                       (nf_internal in flags) then
                      begin
                        if Is_VoidPointer(right.resultdef) then
                        begin
                          if is_big_untyped_addrnode(right) then
                            CGMessage1(type_w_untyped_arithmetic_unportable,node2opstr(nodetype));
                          inserttypeconv(right,left.resultdef)
                        end
                        else if Is_VoidPointer(left.resultdef) then
                          inserttypeconv(left,right.resultdef)
                        else if not(Equal_Defs(ld,rd)) then
                          IncompatibleTypes(ld,rd);
                      end
                    else
                      CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);

                    if not(anf_has_pointerdiv in addnodeflags) and
                      (TPointerDef(rd).PointedDef.Size>1) then
                      begin
                        hp:=GetCopy;
                        include(TAddNode(hp).addnodeflags, anf_has_pointerdiv);
                        result:=CModDivNode.create(divn,hp,
                          COrdConstNode.create(TPointerDef(rd).PointedDef.Size,TPointerDef(rd).Pointer_Subtraction_Result_Type,false));
                      end;
                    resultdef:=TPointerDef(rd).Pointer_Subtraction_Result_Type;
                    exit;
                 end;
               else
                 CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
            end;
          end

         { is one of the operands a string?,
           chararrays are also handled as strings (after conversion), also take
           care of chararray+chararray and chararray+char.
           Note: Must be done after pointerdef+pointerdef has been checked, else
           pchar is converted to string }
         else if (rd.typ=stringdef) or
                 (ld.typ=stringdef) or
                 { stringconstn's can be arraydefs }
                 (lt=stringconstn) or
                 (rt=stringconstn) or
                 ((Is_PChar(rd) or Is_CharArray(rd) or Is_Char(rd) or Is_Open_CharArray(rd) or
                   Is_PWideChar(rd) or Is_WideCharArray(rd) or Is_WideChar(rd) or Is_Open_WideCharArray(rd)) and
                  (Is_PChar(ld) or Is_CharArray(ld) or Is_Char(ld) or Is_Open_CharArray(ld) or
                   Is_PWideChar(ld) or Is_WideCharArray(ld) or Is_WideChar(ld) or Is_Open_WideCharArray(ld))) then
          begin
            if (nodetype in [addn,EqualN,unequaln,lten,gten,ltn,gtn]) then
              begin
                { Is there a unicodestring? }
                if Is_UnicodeString(rd) or Is_UnicodeString(ld) or
                   ((m_default_unicodestring in CurrentSettings.ModeSwitches) and
                    (cs_refcountedstrings in CurrentSettings.LocalSwitches) and
                    (
                     Is_PWideChar(rd) or Is_WideCharArray(rd) or Is_Open_WideCharArray(rd) or (lt = stringconstn) or
                     Is_PWideChar(ld) or Is_WideCharArray(ld) or Is_Open_WideCharArray(ld) or (rt = stringconstn)
                    )
                   ) then
                  strtype:=st_unicodestring
                else
                { Is there a widestring? }
                  if Is_WideString(rd) or Is_WideString(ld) or
                     Is_PWideChar(rd) or Is_WideCharArray(rd) or Is_WideChar(rd) or Is_Open_WideCharArray(rd) or
                     Is_PWideChar(ld) or Is_WideCharArray(ld) or Is_WideChar(ld) or Is_Open_WideCharArray(ld) then
                    strtype:=st_widestring
                else
                  if Is_AnsiString(rd) or Is_AnsiString(ld) or
                     ((cs_refcountedstrings in CurrentSettings.LocalSwitches) and
                     //todo: Move some of this to longstring's then they are implemented?
                      (
                       Is_PChar(rd) or (Is_CharArray(rd) and (rd.Size > 255)) or Is_Open_CharArray(rd) or (lt = stringconstn) or
                       Is_PChar(ld) or (Is_CharArray(ld) and (ld.Size > 255)) or Is_Open_CharArray(ld) or (rt = stringconstn)
                      )
                     ) then
                    strtype:=st_ansistring
                else
                  if Is_LongString(rd) or Is_LongString(ld) then
                    strtype:=st_longstring
                else
                  begin
                    { TODO: todo: add a warning/hint here if one converting a too large array}
                    { nodes is PChar, array [with size > 255] or OpenArrayOfChar.
                      Note: Delphi halts with error if "array [0..xx] of char"
                           is assigned to ShortString and string length is less
                           then array size }
                    strtype:= st_shortstring;
                  end;

                // Now convert nodes to common string type
                case strtype of
                  st_widestring :
                    begin
                      if not(Is_WideString(rd)) then
                        inserttypeconv(right,CWideStringType);
                      if not(Is_WideString(ld)) then
                        inserttypeconv(left,CWideStringType);
                    end;
                  st_unicodestring :
                    begin
                      if not(Is_UnicodeString(rd)) then
                        inserttypeconv(right,CUnicodeStringType);
                      if not(Is_UnicodeString(ld)) then
                        inserttypeconv(left,CUnicodeStringType);
                    end;
                  st_ansistring :
                    begin
                      { use same code page if possible (don't force same code
                        page in case both are ansistrings with code page <>
                        CP_NONE, since then data loss can occur: the ansistring
                        helpers will convert them at run time to an encoding
                        that can represent both encodings) }
                      if Is_AnsiString(ld) and
                         (TStringDef(ld).encoding<>0) and
                         (TStringDef(ld).encoding<>Globals.CP_NONE) and
                         (not Is_AnsiString(rd) or
                          (TStringDef(rd).encoding=0) or
                          (TStringDef(rd).encoding=Globals.CP_NONE)) then
                        inserttypeconv(right,ld)
                      else if Is_AnsiString(rd) and
                         (TStringDef(rd).encoding<>0) and
                         (TStringDef(rd).encoding<>Globals.CP_NONE) and
                         (not Is_AnsiString(ld) or
                          (TStringDef(ld).encoding=0) or
                          (TStringDef(ld).encoding=Globals.CP_NONE)) then
                        inserttypeconv(left,rd)
                      else
                        begin
                          if not Is_AnsiString(ld) then
                            inserttypeconv(left,GetAnsiStringDef);
                          if not Is_AnsiString(rd) then
                            inserttypeconv(right,GetAnsiStringDef);
                        end;
                    end;
                  st_longstring :
                    begin
                      if not(Is_LongString(rd)) then
                        inserttypeconv(right,CLongStringType);
                      if not(Is_LongString(ld)) then
                        inserttypeconv(left,CLongStringType);
                     end;
                   st_shortstring :
                     begin
                       if not(Is_ShortString(ld)) then
                         inserttypeconv(left,CShortStringType);
                       { don't convert char, that can be handled by the optimized node }
                       if not(Is_ShortString(rd) or Is_Char(rd)) then
                         inserttypeconv(right,CShortStringType);
                     end;
                end;
              end
            else
              CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
          end

         { implicit pointer object type comparison }
         else if Is_Implicit_Pointer_Object_Type(rd) or Is_Implicit_Pointer_Object_Type(ld) then
          begin
            if (nodetype in [EqualN,unequaln]) then
              begin
                if Is_Implicit_Pointer_Object_Type(rd) and Is_Implicit_Pointer_Object_Type(ld) then
                 begin
                   if Def_Is_Related(TObjectDef(rd),TObjectDef(ld)) then
                    inserttypeconv(right,left.resultdef)
                   else
                    inserttypeconv(left,right.resultdef);
                 end
                else if Is_Implicit_Pointer_Object_Type(rd) then
                  inserttypeconv(left,right.resultdef)
                else
                  inserttypeconv(right,left.resultdef);
              end
            else
              CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
          end

         else if (rd.typ=classrefdef) and (ld.typ=classrefdef) then
          begin
            if (nodetype in [EqualN,unequaln]) then
              begin
                if Def_Is_Related(TObjectDef(TClassRefDef(rd).PointedDef),
                        TObjectDef(TClassRefDef(ld).PointedDef)) then
                  inserttypeconv(right,left.resultdef)
                else
                  inserttypeconv(left,right.resultdef);
              end
            else
              CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
          end

         { allow comparison with nil pointer }
         else if Is_Implicit_Pointer_Object_Type(rd) or (rd.typ=classrefdef) then
          begin
            if (nodetype in [EqualN,unequaln]) then
              inserttypeconv(left,right.resultdef)
            else
              CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
          end

         else if Is_Implicit_Pointer_Object_Type(ld) or (ld.typ=classrefdef) then
          begin
            if (nodetype in [EqualN,unequaln]) then
              inserttypeconv(right,left.resultdef)
            else
              CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
          end

       { support procvar=nil,procvar<>nil }
         else if ((ld.typ=procvardef) and (rt=niln)) or
                 ((rd.typ=procvardef) and (lt=niln)) then
          begin
            if not(nodetype in [EqualN,unequaln]) then
              CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
            { find proc field in methodpointer record }
            hsym:=TFieldVarSym(TRecordDef(MethodPointerType).SymTable.Find('proc'));
            if not Assigned(hsym) then
              InternalError(200412043);
            { For methodpointers compare only tmethodpointer.proc }
            if (rd.typ=procvardef) and
               (not TProcVarDef(rd).Is_AddressOnly) then
              begin
                right:=CSubscriptNode.create(
                           hsym,
                           CTypeConvNode.Create_Internal(right,MethodPointerType));
                TypeCheckPass(right);
               end;
            if (ld.typ=procvardef) and
               (not TProcVarDef(ld).Is_AddressOnly) then
              begin
                left:=CSubscriptNode.create(
                          hsym,
                          CTypeConvNode.Create_Internal(left,MethodPointerType));
                TypeCheckPass(left);
              end;
            if lt=niln then
              inserttypeconv_explicit(left,right.resultdef)
            else
              inserttypeconv_explicit(right,left.resultdef)
          end

         { <dyn. array>+<dyn. array> ? }
         else if (nodetype=addn) and (Is_Dynamic_Array(ld) or Is_Dynamic_Array(rd)) then
           begin
              { empty array to add? }
              if (right.nodetype=arrayconstructorn) and (TArrayConstructorNode(right).left=nil) then
                begin
                  result:=left;
                  left:=nil;
                  exit;
                end
              else if (left.nodetype=arrayconstructorn) and (TArrayConstructorNode(left).left=nil) then
                begin
                  result:=right;
                  right:=nil;
                  exit;
                end
              else
                begin
                  result:=maybe_convert_to_insert;
                  if Assigned(result) then
                    exit;
                  if not(Is_Dynamic_Array(ld)) then
                    inserttypeconv(left,rd);
                  if not(Is_Dynamic_Array(rd)) then
                    inserttypeconv(right,ld);
                end;
           end

        { support dynamicarray=nil,dynamicarray<>nil }
         else if (Is_Dynamic_Array(ld) and (rt=niln)) or
                 (Is_Dynamic_Array(rd) and (lt=niln)) or
                 (Is_Dynamic_Array(ld) and Is_Dynamic_Array(rd)) then
          begin
            if not(nodetype in [EqualN,unequaln]) then
              CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
            if lt=niln then
              inserttypeconv_explicit(left,right.resultdef)
            else
              inserttypeconv_explicit(right,left.resultdef)
          end

         { vector support, this must be before the zero based array
           check }
         else if (cs_support_vectors in CurrentSettings.GlobalSwitches) and
                 Fits_In_MM_Register(ld) and
                 Fits_In_MM_Register(rd) and
                 Equal_Defs(ld,rd) then
            begin
              if not(nodetype in [addn,subn,xorn,orn,andn,muln,slashn]) then
                CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
              { both defs must be equal, so taking left or right as resultdef doesn't matter }
              resultdef:=To_HWVectorDef(left.resultdef,false);
            end

         { this is a little bit dangerous, also the left type }
         { pointer to should be checked! This broke the mmx support      }
         else if (rd.typ=pointerdef) or
                 (Is_Zero_Based_Array(rd) and (rt<>stringconstn)) then
          begin
            if Is_Zero_Based_Array(rd) then
              begin
                resultdef:=CPointerDef.getreusable(TArrayDef(rd).ElementDef);
                inserttypeconv(right,resultdef);
              end
            else
              resultdef:=right.resultdef;
            inserttypeconv(left,TPointerDef(right.resultdef).Pointer_Arithmetic_Int_Type);
            if nodetype=addn then
              begin
                if (rt=niln) then
                  CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,'NIL');
                if (not(cs_extsyntax in CurrentSettings.ModuleSwitches) and not(nf_internal in flags))  or
                   (not (Is_PChar(rd) or Is_CharArray(rd) or Is_Open_CharArray(rd) or Is_WideChar(rd) or Is_WideCharArray(rd) or Is_Open_WideCharArray(rd)) and
                    not(cs_pointermath in CurrentSettings.LocalSwitches) and
                    not((rd.typ=pointerdef) and TPointerDef(rd).HasPointerMath)) then
                  CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
                if (rd.typ=pointerdef) and
                   (TPointerDef(rd).PointedDef.Size>1) then
                   begin
                     left:=CAddNode.create(muln,left,
                       COrdConstNode.create(TPointerDef(rd).PointedDef.Size,TPointerDef(right.resultdef).Pointer_Arithmetic_Int_Type,true));
                     TypeCheckPass(left);
                   end;
              end
            else
              CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
          end

         else if (ld.typ=pointerdef) or
                 (Is_Zero_Based_Array(ld) and (lt<>stringconstn)) then
           begin
             if Is_Zero_Based_Array(ld) then
               begin
                  resultdef:=CPointerDef.getreusable(TArrayDef(ld).ElementDef);
                  inserttypeconv(left,resultdef);
               end
             else
               resultdef:=left.resultdef;

             inserttypeconv(right,TPointerDef(left.resultdef).Pointer_Arithmetic_Int_Type);
             if nodetype in [addn,subn] then
               begin
                 if (lt=niln) then
                   CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),'NIL',rd.TypeName);
                 if (not(cs_extsyntax in CurrentSettings.ModuleSwitches) and not(nf_internal in flags)) or
                   (not (Is_PChar(ld) or Is_CharArray(ld) or Is_Open_CharArray(ld) or Is_WideChar(ld) or Is_WideCharArray(ld) or Is_Open_WideCharArray(ld)) and
                    not(cs_pointermath in CurrentSettings.LocalSwitches) and
                    not((ld.typ=pointerdef) and TPointerDef(ld).HasPointerMath)) then
                   CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
                 if (ld.typ=pointerdef) then
                 begin
                   if is_big_untyped_addrnode(left) then
                     CGMessage1(type_w_untyped_arithmetic_unportable,node2opstr(nodetype));
                   if (TPointerDef(ld).PointedDef.Size>1) then
                   begin
                     right:=CAddNode.create(muln,right,
                       COrdConstNode.create(TPointerDef(ld).PointedDef.Size,TPointerDef(left.resultdef).Pointer_Arithmetic_Int_Type,true));
                     TypeCheckPass(right);
                   end
                 end else
                   if Is_Zero_Based_Array(ld) and
                      (TArrayDef(ld).ElementDef.Size>1) then
                     begin
                       right:=CAddNode.create(muln,right,
                         COrdConstNode.create(TArrayDef(ld).ElementDef.Size,TPointerDef(left.resultdef).Pointer_Arithmetic_Int_Type,true));
                       TypeCheckPass(right);
                     end;
               end
             else
               CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
           end

         else if (rd.typ=procvardef) and
                 (ld.typ=procvardef) and
                 Equal_Defs(rd,ld) then
          begin
            if (nodetype in [EqualN,unequaln]) then
              begin
                if TProcVarDef(rd).Is_AddressOnly then
                  begin
                    inserttypeconv_internal(right,VoidCodePointerType);
                    inserttypeconv_internal(left,VoidCodePointerType);
                  end
                else
                  begin
                    { find proc field in methodpointer record }
                    hsym:=TFieldVarSym(TRecordDef(MethodPointerType).SymTable.Find('proc'));
                    if not Assigned(hsym) then
                      InternalError(2004120405);
                    { Compare tmehodpointer(left).proc }
                    right:=CSubscriptNode.create(
                                 hsym,
                                 CTypeConvNode.Create_Internal(right,MethodPointerType));
                    TypeCheckPass(right);
                    left:=CSubscriptNode.create(
                                 hsym,
                                 CTypeConvNode.Create_Internal(left,MethodPointerType));
                     TypeCheckPass(left);
                  end;
              end
            else
              CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
          end

         { enums }
         else if (ld.typ=enumdef) and (rd.typ=enumdef) then
          begin
            if allowenumop(nodetype) or (nf_internal in flags) then
              inserttypeconv(right,left.resultdef)
            else
              CGMessage3(type_e_operator_not_supported_for_types,node2opstr(nodetype),ld.TypeName,rd.TypeName);
          end

         { generic conversion, this is for error recovery }
         else
          begin
            inserttypeconv(left,SIntType);
            inserttypeconv(right,SIntType);
          end;

         if cmp_of_disjunct_ranges(res) and not(nf_internal in flags) then
           begin
             if res then
               CGMessage(type_w_comparison_always_true)
             else
               CGMessage(type_w_comparison_always_false);
           end;

         { set resultdef if not already done }
         if not Assigned(resultdef) then
          begin
             case nodetype of
                ltn,lten,gtn,gten,EqualN,unequaln :
                  resultdef:=PasBool1Type;
                slashn :
                  resultdef:=resultrealdef;
                addn:
                  begin
                    { for strings, return is always a 255 char string }
                    if Is_ShortString(left.resultdef) then
                      resultdef:=CShortStringType
                    else
                    { for ansistrings set resultdef to assignment left node
                      if it is an assignment and left node expects ansistring }
                    if Is_AnsiString(left.resultdef) and
                       Assigned(aktassignmentnode) and
                       (aktassignmentnode.right=self) and
                       Is_AnsiString(aktassignmentnode.left.resultdef) then
                      resultdef:=aktassignmentnode.left.resultdef
                    else
                      resultdef:=left.resultdef;
                  end;
                else
                  resultdef:=left.resultdef;
             end;
          end;

         result:=do_currency_corrections;

         if not(CodeGenError) and
            not Assigned(result) then
           begin
             if not (nf_internal in flags) and
               (nf_is_currency in left.flags) and
               (nf_is_currency in right.flags) and
               (nodetype in [addn,subn,muln]) then
               Include(flags,nf_is_currency);

             result:=simplify(false);
           end;
      end;


    function TAddNode.do_currency_corrections: TNode;
      var
        hp: TNode;
        procname: string[31];
      begin
        result:=nil;
        hp:=nil;
        { when the result is currency we need some extra code to make sure
           the comparisons are scaled properly. this should not be done when
           a muln or slashn node is created internally }
        if not(nf_internal in flags) and
          { Can't go by the node's resultdef in the case of comparisons }
          (
            Is_Currency(left.resultdef) or
            Is_Currency(right.resultdef)
          ) then
          begin
            case nodetype of
              slashn :
                if (
                    (nf_is_currency in flags) and
                    { Equivalence... both true or both false }
                    not ((nf_is_currency in left.flags) xor (nf_is_currency in right.flags))
                  ) then
                  begin
                    { slashn will only work with floats }
                    Exclude(flags,nf_is_currency);
                    Include(flags,nf_internal); { Prevent recursion }
                    hp:=CAddNode.Create_Internal(muln,GetCopy,CRealConstNode.create_currency_scalar(S64CurrencyType));
                    include(hp.flags,nf_is_currency);
                    result:=hp;
                  end
                else if not (nf_is_currency in flags) then
                  begin
                    if (
                      not (nf_is_currency in left.flags) and
                      (nf_is_currency in right.flags)
                    ) then
                      begin
                        { Put a multiplier on the left side }
                        left:=CAddNode.Create_Internal(muln,left,CRealConstNode.create_currency_scalar(S64CurrencyType));
                        include(left.flags,nf_is_currency);
                        TypeCheckPass(left);
                      end
                    else if (
                        (nf_is_currency in left.flags) and
                        not (nf_is_currency in right.flags)
                      ) then
                      { All the scalars are correct, so mark it so }
                      Include(flags,nf_is_currency);
                  end;

              muln :
                if (nf_is_currency in flags) then
                  begin
                    if (nf_is_currency in left.flags) and (nf_is_currency in right.flags) then
                      begin
                        if S64CurrencyType.typ=floatdef then
                          begin
                            { Probably a Currency constant with a fractional component }
                            if (right.nodetype=realconstn) and (nf_internal in right.flags) then
                              begin
                                left:=CAddNode.Create_Internal(slashn,left,CRealConstNode.create_currency_scalar(S64CurrencyType));
                                DoTypeCheckPass(left);
                              end
                            else
                              begin
                                right:=CAddNode.Create_Internal(slashn,right,CRealConstNode.create_currency_scalar(S64CurrencyType));
                                DoTypeCheckPass(right);
                              end;
                          end
                        else
                          begin
                            { Probably a Currency constant with a fractional component }
                            if (right.nodetype=realconstn) and (nf_internal in right.flags) then
                              begin
                                left:=CModDivNode.create(divn,left,COrdConstNode.create_currency_scalar(S64CurrencyType));
                                Include(left.flags,nf_internal);
                                DoTypeCheckPass(left);
                              end
                            else
                              begin
                                right:=CModDivNode.create(divn,right,COrdConstNode.create_currency_scalar(S64CurrencyType));
                                Include(right.flags,nf_internal);
                                DoTypeCheckPass(right);
                              end;
                          end;

                        { We need to force a re-evaluation }
                        result:=GetCopy;
                      end
                    else if not (nf_is_currency in left.flags) and not (nf_is_currency in right.flags) then
                      begin
                        result:=GetCopy;
                        { Prevent recursion }
                        Include(result.flags,nf_internal);

                        if S64CurrencyType.typ=floatdef then
                          hp:=CAddNode.Create_Internal(muln,result,CRealConstNode.create_currency_scalar(S64CurrencyType))
                        else
                          hp:=CAddNode.Create_Internal(muln,result,COrdConstNode.create_currency_scalar(S64CurrencyType));
                        { Because the multiplication doubles up on the currency scalar, dividing
                          removes only one and hence the result is still scaled }
                        Include(hp.flags,nf_is_currency);
                        result:=hp;
                      end;
                  end
                else
                  begin
                    if S64CurrencyType.typ=floatdef then
                      begin
                        { if left is a currency integer constant, we can get rid of the factor 10000 }
                        { int64(...) causes a cast on currency, so it is the currency value multiplied by 10000 }
                        if (left.nodetype=realconstn) and (Is_Currency(left.resultdef)) and (nf_is_currency in left.flags) and ((Trunc(TRealConstNode(left).value_real) mod 10000)=0) then
                          begin
                            { trealconstnode expects that value_real and value_currency contain valid values }
                            TRealConstNode(left).value_real:=TRealConstNode(left).value_real/BestReal(10000.0);
                            TRealConstNode(left).SetCurrencyValue(TRealConstNode(left).value_real);
                            Exclude(left.flags,nf_is_currency);
                            Include(flags,nf_is_currency);

                            { We need to force a re-evaluation }
                            hp:=GetCopy;
                          end
                        { or if right is an integer constant, we can get rid of its factor 10000 }
                        else if (right.nodetype=realconstn) and (Is_Currency(right.resultdef)) and (nf_is_currency in right.flags) and ((Trunc(TRealConstNode(right).value_real) mod 10000)=0) then
                          begin
                            { trealconstnode expects that value and value_currency contain valid values }
                            TRealConstNode(right).value_real:=TRealConstNode(right).value_real/BestReal(10000.0);
                            TRealConstNode(right).SetCurrencyValue(TRealConstNode(right).value_real);
                            Exclude(right.flags,nf_is_currency);
                            Include(flags,nf_is_currency);

                            { We need to force a re-evaluation }
                            hp:=GetCopy;
                          end
                        else if (nf_is_currency in left.flags) xor (nf_is_currency in right.flags) then
                          begin
                            { If one is scaled and one isn't, then the result is scaled }
                            Include(flags,nf_is_currency);
                          end
                        else if (nf_is_currency in left.flags) and (nf_is_currency in right.flags) then
                          begin
                            Include(flags,nf_is_currency);
                            right:=CAddNode.Create_Internal(slashn,right,CRealConstNode.create_currency_scalar(S64CurrencyType));
                            { Because the multiplication doubles up on the currency scalar, dividing
                              removes only one and hence the result is still scaled }
                            DoTypeCheckPass(right);

                            { We need to force a re-evaluation }
                            hp:=GetCopy;
                          end;
                      end
                    else
                      begin
                        { if left is a currency integer constant, we can get rid of the factor 10000 }
                        if (left.nodetype=ordconstn) and (Is_Currency(left.resultdef)) and (nf_is_currency in left.flags) and ((TOrdConstNode(left).Value mod 10000)=0) then
                          begin
                            TOrdConstNode(left).Value:=TOrdConstNode(left).Value div 10000;
                            Exclude(left.flags,nf_is_currency);
                            Include(flags,nf_is_currency);

                            { We need to force a re-evaluation }
                            hp:=GetCopy;
                          end
                        { or if right is an integer constant, we can get rid of its factor 10000 }
                        else if (right.nodetype=ordconstn) and (Is_Currency(right.resultdef)) and (nf_is_currency in right.flags) and ((TOrdConstNode(right).Value mod 10000)=0) then
                          begin
                            TOrdConstNode(right).Value:=TOrdConstNode(right).Value div 10000;
                            Exclude(right.flags,nf_is_currency);
                            Include(flags,nf_is_currency);

                            { We need to force a re-evaluation }
                            hp:=GetCopy;
                          end

                        else if (right.nodetype=muln) and Is_Currency(right.resultdef) and (nf_is_currency in right.flags) and
                          { do not test swapped here as the internal conversions are only create as "var."*"10000" }
                          Is_Currency(TAddNode(right).right.resultdef) and (TAddNode(right).right.nodetype=ordconstn) and (TOrdConstNode(TAddNode(right).right).Value=10000) and
                          Is_Currency(TAddNode(right).left.resultdef) and not (nf_is_currency in TAddNode(right).left.flags) and (TAddNode(right).left.nodetype=typeconvn) then
                          begin
                            hp:=TAddNode(right).left.GetCopy;
                            right.free;
                            right:=hp;

                            { We need to force a re-evaluation }
                            hp:=GetCopy;
                          end
                        else if (left.nodetype=muln) and Is_Currency(left.resultdef) and
                          { do not test swapped here as the internal conversions are only create as "var."*"10000" }
                          Is_Currency(TAddNode(left).right.resultdef) and (TAddNode(left).right.nodetype=ordconstn) and (TOrdConstNode(TAddNode(left).right).Value=10000) and
                          Is_Currency(TAddNode(left).left.resultdef) and not (nf_is_currency in TAddNode(left).left.flags) and (TAddNode(left).left.nodetype=typeconvn) then
                          begin
                            hp:=TAddNode(left).left.GetCopy;
                            left.free;
                            left:=hp;

                            { We need to force a re-evaluation }
                            hp:=GetCopy;
                          end
                        else if (nf_is_currency in left.flags) xor (nf_is_currency in right.flags) then
                          begin
                            { If one is scaled and one isn't, then the result is scaled }
                            Include(flags,nf_is_currency);
                          end
                        else if (nf_is_currency in left.flags) and (nf_is_currency in right.flags) then
                          begin
                            { The Int64-based Currency implementation (used e.g. on
                              Win64, where x87 extended types are not supported) can
                              NOT be safely done as a plain 64-bit "multiply, then
                              divide by 10000": both operands here are already scaled
                              by 10000, so their raw product can overflow a 64-bit
                              integer even for operands that are themselves well
                              within Currency's legal range (e.g. 9500000.0004 *
                              10000). Route through a helper that computes the
                              product and the rescaling division using a full
                              128-bit intermediate result, instead of building
                              generic muln+divn nodes that truncate to 64 bits
                              in between.
                            }
                            procname := 'fpc_mul_currency';
                            if cs_check_overflow in CurrentSettings.LocalSwitches then
                              procname := procname + '_checkoverflow';
                            hp:=CCallNode.createintern(procname,CCallParaNode.create(right,CCallParaNode.create(left,nil)));
                            Include(hp.flags,nf_is_currency);
                            left:=nil;
                            right:=nil;
                          end;
                      end;

                    result:=hp;
                  end;
              addn,
              subn,
              ltn,
              lten,
              gtn,
              gten,
              EqualN,
              unequaln:
                { Correct absence of nf_is_currency flag in addn and subn }
                if not
                  (
                    (nf_is_currency in left.flags) and
                    (nf_is_currency in right.flags)
                  ) then
                  begin
                    { Sort out problems with only one side being scaled }
                    if not (nf_is_currency in right.flags) then
                      begin
                        if S64CurrencyType.typ = floatdef then
                          right:=CAddNode.Create_Internal(muln,right,CRealConstNode.create_currency_scalar(S64CurrencyType))
                        else
                          right:=CAddNode.Create_Internal(muln,right,COrdConstNode.create_currency_scalar(S64CurrencyType));
                        Include(right.flags,nf_is_currency);
                        TypeCheckPass(right);
                        FirstPass(right);
                        Include(right.flags,nf_is_currency);
                      end;
                    if not (nf_is_currency in left.flags) then
                      begin
                        if S64CurrencyType.typ = floatdef then
                          left:=CAddNode.Create_Internal(muln,left,CRealConstNode.create_currency_scalar(S64CurrencyType))
                        else
                          left:=CAddNode.Create_Internal(muln,left,COrdConstNode.create_currency_scalar(S64CurrencyType));
                        Include(left.flags,nf_is_currency);
                        TypeCheckPass(left);
                        FirstPass(left);
                        Include(left.flags,nf_is_currency);
                      end;
                  end;
              else
                ;
            end;
          end;
      end;


    function TAddNode.first_addstring: TNode;
      var
        p: TNode;
        newstatement : TStatementNode;
        tempnode : TTempCreateNode;
        cmpfuncname: string;
        para: TCallParaNode;
      begin
        result:=nil;
        { when we get here, we are sure that both the left and the right }
        { node are both strings of the same stringtype (JM)              }
        case nodetype of
          addn:
            begin
              if (left.nodetype=stringconstn) and (TStringConstNode(left).len=0) then
                begin
                  result:=right;
                  left.free;
                  left:=nil;
                  right:=nil;
                  exit;
                end;
              if (right.nodetype=stringconstn) and (TStringConstNode(right).len=0) then
                begin
                  result:=left;
                  left:=nil;
                  right.free;
                  right:=nil;
                  exit;
                end;
              { create the call to the concat routine both strings as arguments }
              if Assigned(aktassignmentnode) and
                  (aktassignmentnode.right=self) and
                  (
                    (aktassignmentnode.left.resultdef=resultdef) or
                    (
                      Is_ShortString(aktassignmentnode.left.resultdef) and
                      Is_ShortString(resultdef)
                    )
                  ) and
                  valid_for_var(aktassignmentnode.left,false) then
                begin
                  para:=CCallParaNode.create(
                          right,
                          CCallParaNode.create(
                            left,
                            CCallParaNode.create(aktassignmentnode.left.GetCopy,nil)
                          )
                        );
                  if Is_AnsiString(resultdef) then
                    para:=CCallParaNode.create(
                            COrdConstNode.create(
                              { don't use getparaencoding(), we have to know
                                when the result is rawbytestring }
                              TStringDef(resultdef).encoding,
                              U16IntType,
                              true
                            ),
                            para
                          );
                  result:=CCallNode.createintern(
                            'fpc_'+TStringDef(resultdef).StringTypName+'_concat',
                            para
                          );
                  include(aktassignmentnode.assignmentnodeflags,anf_assign_done_in_right);
                  FirstPass(result);
                end
              else
                begin
                  result:=internalstatements(newstatement);
                  tempnode:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,true);
                  addstatement(newstatement,tempnode);
                  para:=CCallParaNode.create(
                          right,
                          CCallParaNode.create(
                            left,
                            CCallParaNode.create(CTempRefNode.create(tempnode),nil)
                          )
                        );
                  if Is_AnsiString(resultdef) then
                    para:=CCallParaNode.create(
                            COrdConstNode.create(
                              { don't use getparaencoding(), we have to know
                                when the result is rawbytestring }
                              TStringDef(resultdef).encoding,
                              U16IntType,
                              true
                            ),
                            para
                          );
                  addstatement(
                    newstatement,
                    CCallNode.createintern(
                      'fpc_'+TStringDef(resultdef).StringTypName+'_concat',
                      para
                    )
                  );
                  addstatement(newstatement,CTempDeleteNode.create_normal_temp(tempnode));
                  addstatement(newstatement,CTempRefNode.create(tempnode));
                end;
              { we reused the arguments }
              left := nil;
              right := nil;
            end;
          ltn,lten,gtn,gten,EqualN,unequaln :
            begin
              { generate better code for comparison with empty string, we
                only need to compare the length with 0 }
              if (nodetype in [EqualN,unequaln,gtn,gten,ltn,lten]) and
                 (((left.nodetype=stringconstn) and (TStringConstNode(left).len=0)) or
                  ((right.nodetype=stringconstn) and (TStringConstNode(right).len=0))) then
                begin
                  { switch so that the constant is always on the right }
                  if left.nodetype = stringconstn then
                    begin
                      p := left;
                      left := right;
                      right := p;
                      nodetype:=swap_relation[nodetype];
                    end;
                  if Is_ShortString(left.resultdef) or
                     (nodetype in [gtn,gten,ltn,lten]) then
                    { compare the length with 0 }
                    result := CAddNode.create(nodetype,
                      CInlineNode.create(in_length_x,false,left),
                      COrdConstNode.create(0,S8IntType,false))
                  else { nodetype in [equaln,unequaln] }
                    begin
                      if Is_WideString(left.resultdef) and (tf_winlikewidestring in TargetInfo.flags) then
                        begin
                          { windows like widestrings requires that we also check the length }
                          result:=CInlineNode.create(in_length_x,false,left);
                          { and compare its result with 0 }
                          result:=CAddNode.create(EqualN,result,COrdConstNode.create(0,S8IntType,false));
                          if nodetype=unequaln then
                            result:=CNotNode.create(result);
                        end
                      else
                        begin
                          { compare the pointer with nil (for ansistrings etc), }
                          { faster than getting the length (JM)                 }
                          result:= CAddNode.create(nodetype,
                            CTypeConvNode.Create_Internal(left,VoidPointerType),
                            CPointerConstNode.create(0,VoidPointerType));
                        end;
                    end;
                  { left is reused }
                  left := nil;
                  { right isn't }
                  right.free;
                  right := nil;
                  exit;
                end;
              { no string constant -> call compare routine }
              cmpfuncname := 'fpc_'+TStringDef(left.resultdef).StringTypName+'_compare';
              { for equality checks use optimized version }
              if nodetype in [EqualN,unequaln] then
                cmpfuncname := cmpfuncname + '_equal';

              result := CCallNode.createintern(cmpfuncname,
                CCallParaNode.create(right,CCallParaNode.create(left,nil)));
              { and compare its result with 0 according to the original operator }
              result := CAddNode.create(nodetype,result,
                COrdConstNode.create(0,S8IntType,false));
              left := nil;
              right := nil;
            end;
          else
            InternalError(2019050520);
        end;
      end;


    function TAddNode.first_addset : TNode;

      procedure call_varset_helper(const n : string);
        var
          newstatement : TStatementNode;
          temp    : TTempCreateNode;
        begin
          { directly load the result set into the assignee if possible }
          if Assigned(aktassignmentnode) and
              (aktassignmentnode.right=self) and
              (aktassignmentnode.left.resultdef=resultdef) and
              valid_for_var(aktassignmentnode.left,false) then
            begin
              result:=CCallNode.createintern(n,
                CCallParaNode.create(COrdConstNode.create(resultdef.Size,SIntType,false),
                CCallParaNode.create(aktassignmentnode.left.GetCopy,
                CCallParaNode.create(right,
                CCallParaNode.create(left,nil))))
              );

              { remove reused parts from original node }
              left:=nil;
              right:=nil;

              include(aktassignmentnode.assignmentnodeflags,anf_assign_done_in_right);
              FirstPass(result);
            end
          else
            begin
              { add two var sets }
              result:=internalstatements(newstatement);

              { create temp for result }
              temp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,true);
              addstatement(newstatement,temp);

              addstatement(newstatement,CCallNode.createintern(n,
                CCallParaNode.create(COrdConstNode.create(resultdef.Size,SIntType,false),
                CCallParaNode.create(CTempRefNode.create(temp),
                CCallParaNode.create(right,
                CCallParaNode.create(left,nil)))))
              );

              { remove reused parts from original node }
              left:=nil;
              right:=nil;
              { the last statement should return the value as
                location and type, this is done be referencing the
                temp and converting it first from a persistent temp to
                normal temp }
              addstatement(newstatement,CTempDeleteNode.create_normal_temp(temp));
              addstatement(newstatement,CTempRefNode.create(temp));
            end;
        end;

      var
        procname: string[31];
        tempn: TNode;
        newstatement : TStatementNode;
        temp    : TTempCreateNode;
        no_temp: Boolean;
      begin
        result:=nil;

        case nodetype of
          EqualN,unequaln,lten,gten:
            begin
              case nodetype of
                EqualN,unequaln:
                  procname := 'fpc_varset_comp_sets';
                lten,gten:
                  begin
                    procname := 'fpc_varset_contains_sets';
                    { (left >= right) = (right <= left) }
                    if nodetype = gten then
                      begin
                        tempn := left;
                        left := right;
                        right := tempn;
                      end;
                    end;
                  else
                    InternalError(2013112911);
                end;
                result := CCallNode.createinternres(procname,
                  CCallParaNode.create(COrdConstNode.create(left.resultdef.Size,SIntType,false),
                  CCallParaNode.create(right,
                  CCallParaNode.create(left,nil))),resultdef);
                { left and right are reused as parameters }
                left := nil;
                right := nil;
                { for an unequaln, we have to negate the result of comp_sets }
                if nodetype = unequaln then
                  result := CNotNode.create(result);
            end;
          addn:
            begin
              { can we directly write into the result? }
              no_temp:=Assigned(aktassignmentnode) and
                (aktassignmentnode.right=self) and
                (aktassignmentnode.left.resultdef=self.resultdef) and
                valid_for_var(aktassignmentnode.left,false);

              { optimize first loading of a set }
              if (right.nodetype=setelementn) and
                  not(Assigned(TSetElementNode(right).right)) and
                  is_emptyset(left) then
                begin
                  { adjust for set base }
                  TSetElementNode(right).left:=CAddNode.create(subn,
                    CTypeConvNode.Create_Internal(TSetElementNode(right).left,SIntType),
                    COrdConstNode.create(TSetDef(resultdef).SetBase,SIntType,false));

                  if no_temp then
                    begin
                      result:=CCallNode.createintern('fpc_varset_create_element',
                        CCallParaNode.create(aktassignmentnode.left.GetCopy,
                        CCallParaNode.create(COrdConstNode.create(resultdef.Size,SIntType,false),
                        CCallParaNode.create(TSetElementNode(right).left,nil))));
                      include(aktassignmentnode.assignmentnodeflags,anf_assign_done_in_right);
                    end
                  else
                    begin
                      result:=internalstatements(newstatement);

                      { create temp for result }
                      temp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,true);
                      addstatement(newstatement,temp);

                      addstatement(newstatement,CCallNode.createintern('fpc_varset_create_element',
                        CCallParaNode.create(CTempRefNode.create(temp),
                        CCallParaNode.create(COrdConstNode.create(resultdef.Size,SIntType,false),
                        CCallParaNode.create(TSetElementNode(right).left,nil))))
                      );

                      { the last statement should return the value as
                        location and type, this is done be referencing the
                        temp and converting it first from a persistent temp to
                        normal temp }
                      addstatement(newstatement,CTempDeleteNode.create_normal_temp(temp));
                      addstatement(newstatement,CTempRefNode.create(temp));
                    end;
                  TSetElementNode(right).left:=nil;
                end
              else
                begin
                  if right.nodetype=setelementn then
                    begin
                      if no_temp then
                        begin
                          { add a range or a single element? }
                          if Assigned(TSetElementNode(right).right) then
                            begin
                              { adjust for set base }
                              TSetElementNode(right).left:=CAddNode.create(subn,
                                CTypeConvNode.Create_Internal(TSetElementNode(right).left,SIntType),
                                COrdConstNode.create(TSetDef(resultdef).SetBase,SIntType,false));

                              { adjust for set base }
                              TSetElementNode(right).right:=CAddNode.create(subn,
                                CTypeConvNode.Create_Internal(TSetElementNode(right).right,SIntType),
                                COrdConstNode.create(TSetDef(resultdef).SetBase,SIntType,false));

                              result:=CCallNode.createintern('fpc_varset_set_range',
                                CCallParaNode.create(COrdConstNode.create(resultdef.Size,SIntType,false),
                                CCallParaNode.create(TSetElementNode(right).right,
                                CCallParaNode.create(TSetElementNode(right).left,
                                CCallParaNode.create(aktassignmentnode.left.GetCopy,
                                CCallParaNode.create(left,nil))))));
                            end
                          else
                            begin
                              { s:=s+[element]; ? }
                              if left.isequal(aktassignmentnode.left) then
                                result:=CInlineNode.createintern(in_include_x_y,false,CCallParaNode.create(aktassignmentnode.left.GetCopy,
                                  CCallParaNode.create(CTypeConvNode.Create_Internal(TSetElementNode(right).left,TSetDef(resultdef).ElementDef),nil)))
                              else
                                begin
                                  { adjust for set base }
                                  TSetElementNode(right).left:=CAddNode.create(subn,
                                    CTypeConvNode.Create_Internal(TSetElementNode(right).left,SIntType),
                                    COrdConstNode.create(TSetDef(resultdef).SetBase,SIntType,false));

                                  result:=CCallNode.createintern('fpc_varset_set',
                                    CCallParaNode.create(COrdConstNode.create(resultdef.Size,SIntType,false),
                                    CCallParaNode.create(CTypeConvNode.Create_Internal(TSetElementNode(right).left,SIntType),
                                    CCallParaNode.create(aktassignmentnode.left.GetCopy,
                                    CCallParaNode.create(left,nil)))));
                                end;
                            end;

                          include(aktassignmentnode.assignmentnodeflags,anf_assign_done_in_right);
                        end
                      else
                        begin
                          { adjust for set base }
                          TSetElementNode(right).left:=CAddNode.create(subn,
                            CTypeConvNode.Create_Internal(TSetElementNode(right).left,SIntType),
                            COrdConstNode.create(TSetDef(resultdef).SetBase,SIntType,false));

                          result:=internalstatements(newstatement);

                          { create temp for result }
                          temp:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,true);
                          addstatement(newstatement,temp);

                          { add a range or a single element? }
                          if Assigned(TSetElementNode(right).right) then
                            begin
                              { adjust for set base }
                              TSetElementNode(right).right:=CAddNode.create(subn,
                                CTypeConvNode.Create_Internal(TSetElementNode(right).right,SIntType),
                                COrdConstNode.create(TSetDef(resultdef).SetBase,SIntType,false));
                              addstatement(newstatement,CCallNode.createintern('fpc_varset_set_range',
                                CCallParaNode.create(COrdConstNode.create(resultdef.Size,SIntType,false),
                                CCallParaNode.create(TSetElementNode(right).right,
                                CCallParaNode.create(TSetElementNode(right).left,
                                CCallParaNode.create(CTempRefNode.create(temp),
                                CCallParaNode.create(left,nil))))))
                              );
                            end
                          else
                            addstatement(newstatement,CCallNode.createintern('fpc_varset_set',
                              CCallParaNode.create(COrdConstNode.create(resultdef.Size,SIntType,false),
                              CCallParaNode.create(CTypeConvNode.Create_Internal(TSetElementNode(right).left,SIntType),
                              CCallParaNode.create(CTempRefNode.create(temp),
                              CCallParaNode.create(left,nil)))))
                            );
                          { the last statement should return the value as
                            location and type, this is done be referencing the
                            temp and converting it first from a persistent temp to
                            normal temp }
                          addstatement(newstatement,CTempDeleteNode.create_normal_temp(temp));
                          addstatement(newstatement,CTempRefNode.create(temp));
                        end;
                      { remove reused parts from original node }
                      TSetElementNode(right).right:=nil;
                      TSetElementNode(right).left:=nil;
                      left:=nil;
                    end
                  else
                    call_varset_helper('fpc_varset_add_sets');
                end
            end;
          subn:
            call_varset_helper('fpc_varset_sub_sets');
          symdifn:
            call_varset_helper('fpc_varset_symdif_sets');
          muln:
            call_varset_helper('fpc_varset_mul_sets');
          else
            InternalError(200609241);
        end;
      end;


    function TAddNode.first_adddynarray : TNode;
      var
        newstatement : TStatementNode;
        tempnode (*,tempnode2*) : TTempCreateNode;
        para: TCallParaNode;
      begin
        result:=nil;
        { when we get here, we are sure that both the left and the right }
        { node are both strings of the same stringtype (JM)              }
        case nodetype of
          addn:
            begin
              if (left.nodetype=arrayconstructorn) and (TArrayConstructorNode(left).isempty) then
                begin
                  result:=right;
                  left.free;
                  left:=nil;
                  right:=nil;
                  exit;
                end;
              if (right.nodetype=arrayconstructorn) and (TArrayConstructorNode(right).isempty) then
                begin
                  result:=left;
                  left:=nil;
                  right.free;
                  right:=nil;
                  exit;
                end;
              { create the call to the concat routine both strings as arguments }
              if Assigned(aktassignmentnode) and
                  (aktassignmentnode.right=self) and
                  (aktassignmentnode.left.resultdef=resultdef) and
                  valid_for_var(aktassignmentnode.left,false) then
                begin
                  para:=CCallParaNode.create(
                          CTypeConvNode.Create_Internal(right,VoidCodePointerType),
                        CCallParaNode.create(
                          CTypeConvNode.Create_Internal(left,VoidCodePointerType),
                        CCallParaNode.create(
                          CAddrNode.Create_Internal(CRTTINode.create(TStoredDef(resultdef),initrtti,rdt_normal)),
                        CCallParaNode.create(
                          CTypeConvNode.Create_Internal(aktassignmentnode.left.GetCopy,VoidCodePointerType),nil)
                        )));
                  result:=CCallNode.createintern(
                            'fpc_dynarray_concat',
                            para
                          );
                  include(aktassignmentnode.assignmentnodeflags,anf_assign_done_in_right);
                  FirstPass(result);
                end
              else
                begin
                  result:=internalstatements(newstatement);
                  tempnode:=CTempCreateNode.create(resultdef,resultdef.Size,tt_persistent,true);
                  addstatement(newstatement,tempnode);
                  para:=CCallParaNode.create(
                          CTypeConvNode.Create_Internal(right,VoidCodePointerType),
                        CCallParaNode.create(
                          CTypeConvNode.Create_Internal(left,VoidCodePointerType),
                        CCallParaNode.create(
                          CAddrNode.Create_Internal(CRTTINode.create(TStoredDef(resultdef),initrtti,rdt_normal)),
                        CCallParaNode.create(
                          CTypeConvNode.Create_Internal(CTempRefNode.create(tempnode),VoidCodePointerType),nil)
                        )));
                  addstatement(
                    newstatement,
                    CCallNode.createintern(
                      'fpc_dynarray_concat',
                      para
                    )
                  );
                  addstatement(newstatement,CTempDeleteNode.create_normal_temp(tempnode));
                  addstatement(newstatement,CTempRefNode.create(tempnode));
                end;
              { we reused the arguments }
              left := nil;
              right := nil;
            end;
          unequaln,EqualN:
            expectloc:=LOC_FLAGS;
          else
            InternalError(2018030301);
          end;
      end;


    function TAddNode.use_generic_mul32to64: boolean;
      begin
        result := true;
      end;


    function TAddNode.use_generic_mul64bit: boolean;
      begin
        result := true;
      end;


    function TAddNode.try_make_mul32to64: boolean;

      function canbe32bitint(v: TConstExprInt; out canbesignedconst, canbeunsignedconst: boolean): boolean;
        begin
          result := ((v >= int64(low(LongInt))) and (v <= int64(high(LongInt)))) or
                    ((v >= qword(low(cardinal))) and (v <= qword(high(cardinal))));
          canbesignedconst:=v<=int64(high(LongInt));
          canbeunsignedconst:=v>=0;
        end;

      function is_32bitordconst(n: TNode; out canbesignedconst, canbeunsignedconst: boolean): boolean;
        begin
          canbesignedconst:=false;
          canbeunsignedconst:=false;
          result := (n.nodetype = ordconstn) and
                    canbe32bitint(TOrdConstNode(n).Value, canbesignedconst, canbeunsignedconst);
        end;

      function is_32to64typeconv(n: TNode): boolean;
        begin
          result := (n.nodetype = typeconvn) and
                    Is_Integer(TTypeConvNode(n).left.resultdef) and
                    not Is_64Bit(TTypeConvNode(n).left.resultdef);
        end;

      var
        temp: TNode;
        leftoriginallysigned,
        canbesignedconst, canbeunsignedconst, swapped: boolean;
      begin
        result := false;
        swapped := false;
        { make sure that if there is a constant, that it's on the right }
        if left.nodetype = ordconstn then
          begin
            swapleftright;
            swapped := true;
          end;
        if is_32to64typeconv(left) then
          begin
            leftoriginallysigned:=Is_Signed(TTypeConvNode(left).left.resultdef);
            if ((is_32bitordconst(right,canbesignedconst, canbeunsignedconst) and
                 ((leftoriginallysigned and canbesignedconst) or
                  (not leftoriginallysigned and canbeunsignedconst))) or
                (is_32to64typeconv(right) and
                  ((leftoriginallysigned =
                    Is_Signed(TTypeConvNode(right).left.resultdef)) or
                   (leftoriginallysigned and
                    (TOrdDef(TTypeConvNode(right).left.resultdef).OrdType in [u8bit,u16bit]))))) then
              begin
                temp := TTypeConvNode(left).left;
                TTypeConvNode(left).left := nil;
                left.free;
                left := temp;
                if (right.nodetype = typeconvn) then
                  begin
                    temp := TTypeConvNode(right).left;
                    TTypeConvNode(right).left := nil;
                    right.free;
                    right := temp;
                  end;
                if (Is_Signed(left.resultdef)) then
                  begin
                    inserttypeconv_internal(left,S32IntType);
                    inserttypeconv_internal(right,S32IntType);
                  end
                else
                  begin
                    inserttypeconv_internal(left,U32IntType);
                    inserttypeconv_internal(right,U32IntType);
                  end;
                FirstPass(left);
                FirstPass(right);
                result := true;
              end;
          end;
        { pass_Typecheck caches left/right type and resultdef, so restore the
          original order }
        if not result and swapped then
          swapleftright;
      end;


    function TAddNode.use_fma : boolean;
      begin
        result:=false;
      end;


    function TAddNode.try_fma(ld,rd : TDef) : TNode;
      var
        inlinennr : TInlineNumber;
      begin
        result:=nil;
        if (cs_opt_fastmath in CurrentSettings.OptimizerSwitches) and
          use_fma and
          (nodetype in [addn,subn]) and
          (rd.typ=floatdef) and (ld.typ=floatdef) and
          (Is_Single(rd) or Is_Double(rd)) and
          Equal_Defs(rd,ld) and
          { transforming a*b+c into fma(a,b,c) makes only sense if c can be
            calculated easily. Consider a*b+c*d which results in

            fmul
            fmul
            fadd

            and in

            fmul
            fma

            when using the fma optimization. On a super scalar architecture, the first instruction
            sequence requires clock_cycles(fmul)+clock_cycles(fadd) clock cycles because the fmuls can be executed in parallel.
            The second sequence requires clock_cycles(fmul)+clock_cycles(fma) because the fma has to wait for the
            result of the fmul. Since typically clock_cycles(fma)>clock_cycles(fadd) applies, the first sequence is better.
          }
          (((left.nodetype=muln) and (node_complexity(right)<3)) or
           ((right.nodetype=muln) and (node_complexity(left)<3)) or
           ((left.nodetype=inlinen) and
            (TInlineNode(left).inlinenumber=in_sqr_real) and
             (node_complexity(right)<3)) or
           ((right.nodetype=inlinen) and
            (TInlineNode(right).inlinenumber=in_sqr_real) and
            (node_complexity(left)<3))
          ) then
          begin
            case TFloatDef(ld).FloatType of
              S32Real:
               inlinennr:=in_fma_single;
              S64Real:
               inlinennr:=in_fma_double;
              s80real:
               inlinennr:=in_fma_extended;
              else
                InternalError(2014042601);
            end;
            if left.nodetype=muln then
              begin
                if nodetype=subn then
                  result:=CInlineNode.create(inlinennr,false,CCallParaNode.create(CUnaryMinusNode.create(right),
                    CCallParaNode.create(TAddNode(left).right,
                    CCallParaNode.create(TAddNode(left).left,nil
                    ))))
                else
                  result:=CInlineNode.create(inlinennr,false,CCallParaNode.create(right,
                    CCallParaNode.create(TAddNode(left).right,
                    CCallParaNode.create(TAddNode(left).left,nil
                    ))));
                right:=nil;
                TAddNode(left).right:=nil;
                TAddNode(left).left:=nil;
              end
            else if right.nodetype=muln then
              begin
                if nodetype=subn then
                  result:=CInlineNode.create(inlinennr,false,CCallParaNode.create(left,
                    CCallParaNode.create(CUnaryMinusNode.create(TAddNode(right).right),
                    CCallParaNode.create(TAddNode(right).left,nil
                    ))))
                else
                  result:=CInlineNode.create(inlinennr,false,CCallParaNode.create(left,
                    CCallParaNode.create(TAddNode(right).right,
                    CCallParaNode.create(TAddNode(right).left,nil
                    ))));
                left:=nil;
                TAddNode(right).right:=nil;
                TAddNode(right).left:=nil;
              end
            else if (left.nodetype=inlinen) and (TInlineNode(left).inlinenumber=in_sqr_real) then
              begin
                if node_complexity(TInlineNode(left).left)=0 then
                  begin
                    if nodetype=subn then
                      result:=CInlineNode.create(inlinennr,false,CCallParaNode.create(CUnaryMinusNode.create(right),
                        CCallParaNode.create(TInlineNode(left).left.GetCopy,
                        CCallParaNode.create(TInlineNode(left).left.GetCopy,nil
                        ))))
                    else
                      result:=CInlineNode.create(inlinennr,false,CCallParaNode.create(right,
                        CCallParaNode.create(TInlineNode(left).left.GetCopy,
                        CCallParaNode.create(TInlineNode(left).left.GetCopy,nil
                        ))));
                    right:=nil;
                  end;
              end
            { we get here only if right is a sqr node }
            else if (right.nodetype=inlinen) and (TInlineNode(right).inlinenumber=in_sqr_real) then
              begin
                if node_complexity(TInlineNode(right).left)=0 then
                  begin
                    if nodetype=subn then
                      result:=CInlineNode.create(inlinennr,false,CCallParaNode.create(left,
                        CCallParaNode.create(CUnaryMinusNode.create(TInlineNode(right).left.GetCopy),
                        CCallParaNode.create(TInlineNode(right).left.GetCopy,nil
                        ))))
                    else
                      result:=CInlineNode.create(inlinennr,false,CCallParaNode.create(left,
                        CCallParaNode.create(TInlineNode(right).left.GetCopy,
                        CCallParaNode.create(TInlineNode(right).left.GetCopy,nil
                        ))));
                    left:=nil;
                  end;
              end;
          end;
      end;


    function TAddNode.first_add64bitint: TNode;
      var
        procname: string[31];
        power: LongInt;
      begin
        result := nil;
        { create helper calls mul }
        if nodetype <> muln then
          exit;

        { make sure that if there is a constant, that it's on the right }
        if left.nodetype = ordconstn then
          swapleftright;

        { can we use a shift instead of a mul? }
        if not (cs_check_overflow in CurrentSettings.LocalSwitches) and
           (right.nodetype = ordconstn) and
           IsPowerOf2(TOrdConstNode(right).Value,power) then
          begin
            TOrdConstNode(right).Value := power;
            result := CShlShrNode.create(shln,left,right);
            { left and right are reused }
            left := nil;
            right := nil;
            { return firstpassed new node }
            exit;
          end;

        if try_make_mul32to64 then
          begin
            { this uses the same criteria for signedness as the 32 to 64-bit mul
              handling in the i386 code generator }
            if Is_Signed(left.resultdef) and Is_Signed(right.resultdef) then
              procname := 'fpc_mul_longint_to_int64'
            else
              procname := 'fpc_mul_dword_to_qword';

            right := CCallParaNode.create(right,CCallParaNode.create(left,nil));
            result := CCallNode.createintern(procname,right);
            left := nil;
            right := nil;
          end
        else
          begin
            { can full 64-bit multiplication be handled inline? }
            if not use_generic_mul64bit then
              begin
                { generic handling replaces this node with call to fpc_mul_int64,
                  whose result is int64 }
                if Is_Currency(resultdef) then
                  resultdef:=S64IntType;
                exit;
              end;

            { when currency is used set the result of the
              parameters to s64bit, so they are not converted }
            if Is_Currency(resultdef) then
              begin
                left.resultdef:=S64IntType;
                right.resultdef:=S64IntType;
              end;

            { otherwise, create the parameters for the helper }
            right :=   CCallParaNode.create(right,CCallParaNode.create(left,nil));
            left := nil;
            { only qword needs the unsigned code, the
              signed code is also used for currency }
            if Is_Signed(resultdef) then
              procname := 'fpc_mul_int64'
            else
              procname := 'fpc_mul_qword';
            if cs_check_overflow in CurrentSettings.LocalSwitches then
              procname := procname + '_checkoverflow';

            result := CCallNode.createintern(procname,right);
            right := nil;
          end;
      end;


    function TAddNode.first_addpointer: TNode;
      begin
        result:=nil;
        expectloc:=LOC_REGISTER;
      end;


    function TAddNode.first_cmppointer: TNode;
      begin
        result:=nil;
        expectloc:=LOC_FLAGS;
      end;



{$ifdef cpuneedsmulhelper}
    function TAddNode.use_mul_helper: boolean;
      begin
        result:=(nodetype=muln) and
                not(TOrdDef(resultdef).OrdType in [u8bit,s8bit
                ]);
      end;
{$endif cpuneedsmulhelper}


    function TAddNode.pass_1 : TNode;

      function isconstsetfewelements(p : TNode) : boolean;
        begin
          result:=(p.nodetype=setconstn) and (TSetConstNode(p).elements<=4);
        end;

      var
         rd,ld   : TDef;
         i,i2    : LongInt;
         lt,rt   : TNodeType;
{$ifdef cpuneedsmulhelper}
         procname : string[32];
{$endif cpuneedsmulhelper}
        tempn,varsetnode: TNode;
        mulnode : TAddNode;
        constsetnode : TSetConstNode;
        trycreateinnodes : Boolean;
      begin
         result:=nil;
         { Can we optimize multiple string additions into a single call?
           This need to be done on a complete tree to detect the multiple
           add nodes and is therefor done before the subtrees are processed }
         if canbemultistringadd(self) then
           begin
             result:=genmultistringadd(self);
             exit;
           end;

         { Can we optimize multiple dyn. array additions into a single call?
           This need to be done on a complete tree to detect the multiple
           add nodes and is therefor done before the subtrees are processed }
         if (m_array_operators in CurrentSettings.ModeSwitches) and canbemultidynarrayadd(self) then
           begin
             result:=genmultidynarrayadd(self);
             exit;
           end;

         { typical set tests like (s*[const. set])<>/=[] can be converted into an or'ed chain of in tests
           for var sets if const. set contains only a few elements }
         if (cs_opt_level1 in CurrentSettings.OptimizerSwitches) and (nodetype in [unequaln,EqualN]) and (left.resultdef.typ=setdef) and not(Is_SmallSet(left.resultdef)) then
           begin
             trycreateinnodes:=false;
             mulnode:=nil;
             if (is_emptyset(right) and (left.nodetype=muln) and
                 (isconstsetfewelements(TAddNode(left).right) or isconstsetfewelements(TAddNode(left).left))) then
               begin
                 trycreateinnodes:=true;
                 mulnode:=TAddNode(left);
               end
             else if (is_emptyset(left) and (right.nodetype=muln) and
               (isconstsetfewelements(TAddNode(right).right) or isconstsetfewelements(TAddNode(right).left))) then
               begin
                 trycreateinnodes:=true;
                 mulnode:=TAddNode(right);
               end;

             if trycreateinnodes then
               begin
                 constsetnode:=nil;
                 varsetnode:=nil;
                 if isconstsetfewelements(mulnode.right) then
                   begin
                     constsetnode:=TSetConstNode(mulnode.right);
                     varsetnode:=mulnode.left;
                   end
                 else
                   begin
                     constsetnode:=TSetConstNode(mulnode.left);
                     varsetnode:=mulnode.right;
                   end;
                 { the node is copied so it might have no side effects, if the complexity is too, cse should fix it, so
                   do not check complexity }
                 if not(might_have_sideeffects(varsetnode)) then
                   begin
                     result:=nil;
                     for i:=low(TConstSet) to high(TConstSet) do
                       if i in constsetnode.value_set^ then
                         begin
                           tempn:=CInNode.create(COrdConstNode.create(i,TSetDef(constsetnode.resultdef).ElementDef,false),varsetnode.GetCopy);
                           if Assigned(result) then
                             result:=CAddNode.Create_Internal(orn,result,tempn)
                           else
                             result:=tempn;
                         end;
                     if nodetype=EqualN then
                       result:=CNotNode.create(result);
                     exit;
                   end;
               end;
           end;

        { get rid of adding empty sets generated by set constructors (s+([]+[..]))

          this needs to be done before firstpass, else the set additions get already converted into calls }
        if (resultdef.typ=setdef) and (nodetype=addn) and (right.nodetype=addn) and (is_emptyset(TAddNode(right).left)) then
          begin
            result:=CAddNode.create(addn,left,TAddNode(right).right);
            left:=nil;
            TAddNode(right).right:=nil;
            exit;
          end;

         { first do the two subtrees }
         FirstPass(left);
         FirstPass(right);

         if CodeGenError then
           exit;

         { load easier access variables }
         rd:=right.resultdef;
         ld:=left.resultdef;
         rt:=right.nodetype;
         lt:=left.nodetype;

         { int/int gives real/real! }
         if nodetype=slashn then
           begin
             expectloc:=LOC_FPUREGISTER;
           end

         { if both are orddefs then check sub types }
         else if (ld.typ=orddef) and (rd.typ=orddef) then
           begin
             { optimize multiplication by a power of 2 }
             if not(cs_check_overflow in CurrentSettings.LocalSwitches) and
                (nodetype = muln) and
                not Is_Currency(resultdef) and
                (((left.nodetype = ordconstn) and
                  IsPowerOf2(TOrdConstNode(left).Value,i)) or
                 ((right.nodetype = ordconstn) and
                  IsPowerOf2(TOrdConstNode(right).Value,i2))) then
               begin
                 { it could be that we are converting a 32x32 -> 64 multiplication:
                   in this case, we have to restore the type conversion }
                 inserttypeconv_internal(left,resultdef);
                 inserttypeconv_internal(right,resultdef);
                 if ((left.nodetype = ordconstn) and
                     IsPowerOf2(TOrdConstNode(left).Value,i)) then
                   begin
                     TOrdConstNode(left).Value := i;
                     result := CShlShrNode.create(shln,right,left);
                   end
                 else
                   begin
                     TOrdConstNode(right).Value := i2;
                     result := CShlShrNode.create(shln,left,right);
                   end;
                 result.resultdef := resultdef;
                 left := nil;
                 right := nil;
                 exit;
               end;

           { 2 booleans ? }
             if Is_Boolean(ld) and Is_Boolean(rd) then
              begin
                if doshortbooleval(self) then
                  expectloc:=LOC_JUMP
                else
                 begin
                   if nodetype in [ltn,lten,gtn,gten,EqualN,unequaln] then
                     expectloc:=LOC_FLAGS
                   else
                     expectloc:=LOC_REGISTER;
                 end;
              end
             else
             { Both are chars? only convert to shortstrings for addn }
              if Is_Char(ld) then
               begin
                 if nodetype=addn then
                  InternalError(200103291);
                 expectloc:=LOC_FLAGS;
               end
             else if (nodetype=muln) and
                Is_64BitInt(resultdef) and
                not use_generic_mul32to64 and
                try_make_mul32to64 then
               begin
                 { if the code generator can handle 32 to 64-bit muls,
                   we're done here }
                 expectloc:=LOC_REGISTER;
               end
{$if not defined(cpu64bitalu) and not defined(cpuhighleveltarget)}
              { is there a 64 bit type ? }
             else if (TOrdDef(ld).OrdType in [s64bit,u64bit,scurrency]) then
               begin
                 result := first_add64bitint;
                 if Assigned(result) then
                   exit;
                  if nodetype in [addn,subn,muln,andn,orn,xorn] then
                    expectloc:=LOC_REGISTER
                  else
                    expectloc:=LOC_JUMP;
               end
{$endif not(cpu64bitalu) and not(cpuhighleveltarget)}
             { generic 32bit conversion }
             else
               begin
{$ifdef cpuneedsmulhelper}
                 if use_mul_helper then
                   begin
                     result := nil;

                     case TOrdDef(resultdef).OrdType of
                       s8bit:
                         procname := 'fpc_mul_shortint';
                       u8bit:
                         procname := 'fpc_mul_byte';
                       s16bit:
                         procname := 'fpc_mul_integer';
                       u16bit:
                         procname := 'fpc_mul_word';
                       s32bit:
                         procname := 'fpc_mul_longint';
                       u32bit:
                         procname := 'fpc_mul_dword';
                       else
                         InternalError(2011022301);
                     end;
                     if cs_check_overflow in CurrentSettings.LocalSwitches then
                       procname:=procname+'_checkoverflow';
                     result := CCallNode.createintern(procname,
                       CCallParaNode.create(right,
                       CCallParaNode.create(left,nil)));
                     left := nil;
                     right := nil;
                     FirstPass(result);
                     exit;
                   end;
{$endif cpuneedsmulhelper}
                  if nodetype in [addn,subn,muln,andn,orn,xorn] then
                    expectloc:=LOC_REGISTER
{$if not defined(cpuhighleveltarget)}
                  else if TOrdDef(ld).Size>sizeof(aint) then
                    expectloc:=LOC_JUMP
{$endif}
                  else
                    expectloc:=LOC_FLAGS;
              end;
           end

         { left side a setdef, must be before string processing,
           else array constructor can be seen as array of char (PFV) }
         else if (ld.typ=setdef) then
           begin
             { small sets are handled inline by the compiler.
               small set doesn't have support for adding ranges }
             if Is_SmallSet(ld) and
                not(
                    (right.nodetype=setelementn) and
                    Assigned(TSetElementNode(right).right)
                   ) then
               begin
                 if nodetype in [ltn,lten,gtn,gten,EqualN,unequaln] then
                   expectloc:=LOC_FLAGS
                 else
                   expectloc:=LOC_REGISTER;
               end
             else
               begin
                 result := first_addset;
                 if Assigned(result) then
                   exit;
                 expectloc:=LOC_CREFERENCE;
               end;
           end

         { compare pchar by addresses like BP/Delphi }
         else if Is_PChar(ld) then
           begin
             if nodetype in [addn,subn,muln,andn,orn,xorn] then
               result:=first_addpointer
             else
               result:=first_cmppointer;
           end

         { is one of the operands a string }
         else if (ld.typ=stringdef) then
            begin
              if Is_WideString(ld) then
                begin
                   { this is only for add, the comparison is handled later }
                   expectloc:=LOC_REGISTER;
                end
              else if Is_UnicodeString(ld) then
                begin
                   { this is only for add, the comparison is handled later }
                   expectloc:=LOC_REGISTER;
                end
              else if Is_AnsiString(ld) then
                begin
                   { this is only for add, the comparison is handled later }
                   expectloc:=LOC_REGISTER;
                end
              else if Is_LongString(ld) then
                begin
                   { this is only for add, the comparison is handled later }
                   expectloc:=LOC_REFERENCE;
                end
              else
                begin
{$ifdef addstringopt}
                   { can create a call which isn't handled by callparatemp }
                   if canbeaddsstringcharoptnode(self) then
                     begin
                       hp := genaddsstringcharoptnode(self);
                       pass_1 := hp;
                       exit;
                     end
                   else
{$endif addstringopt}
                     begin
                       { Fix right to be shortstring }
                       if Is_Char(right.resultdef) then
                        begin
                          inserttypeconv(right,CShortStringType);
                          FirstPass(right);
                        end;
                     end;
{$ifdef addstringopt}
                   { can create a call which isn't handled by callparatemp }
                   if canbeaddsstringcsstringoptnode(self) then
                     begin
                       hp := genaddsstringcsstringoptnode(self);
                       pass_1 := hp;
                       exit;
                     end;
{$endif addstringopt}
                end;
             { otherwise, let addstring convert everything }
              result := first_addstring;
              exit;
           end

         { is one a real float ? }
         else if (rd.typ=floatdef) or (ld.typ=floatdef) then
            begin
              if nodetype in [addn,subn,muln,andn,orn,xorn] then
                expectloc:=LOC_FPUREGISTER
              else
                expectloc:=LOC_FLAGS;

              result:=try_fma(ld,rd);
              if Assigned(result) then
                exit;
            end

         { pointer comparison and subtraction }
         else if (ld.typ=pointerdef) then
            begin
              if nodetype in [addn,subn,muln,andn,orn,xorn] then
                result:=first_addpointer
              else
                result:=first_cmppointer;
           end

         else if Is_Implicit_Pointer_Object_Type(ld) then
            begin
              if ld.Size>sizeof(aint) then
                expectloc:=LOC_JUMP
              else
                expectloc:=LOC_FLAGS;
            end

         else if (ld.typ=classrefdef) then
            begin
              if ld.Size>sizeof(aint) then
                expectloc:=LOC_JUMP
              else
                expectloc:=LOC_FLAGS;
            end

         { support procvar=nil,procvar<>nil }
         else if ((ld.typ=procvardef) and (rt=niln)) or
                 ((rd.typ=procvardef) and (lt=niln)) then
            begin
              if (ld.typ=procvardef) and (TProcVarDef(ld).Size>sizeof(aint)) or
                 (rd.typ=procvardef) and (TProcVarDef(rd).Size>sizeof(aint)) then
                expectloc:=LOC_JUMP
              else
                expectloc:=LOC_FLAGS;
            end


         else if (rd.typ=pointerdef) or (ld.typ=pointerdef) then
            begin
              result:=first_addpointer;
            end

         else  if (rd.typ=procvardef) and
                  (ld.typ=procvardef) and
                  Equal_Defs(rd,ld) then
           begin
             if TProcVarDef(ld).Size>sizeof(aint) then
               expectloc:=LOC_JUMP
             else
               expectloc:=LOC_FLAGS;
           end

         else if (ld.typ=enumdef) then
           begin
              if TEnumDef(ld).Size>sizeof(aint) then
                expectloc:=LOC_JUMP
              else
                expectloc:=LOC_FLAGS;
           end


         else if Is_Dynamic_Array(ld) or Is_Dynamic_Array(rd) then
           begin
             result:=first_adddynarray;
             exit;
           end
         { the general solution is to convert to 32 bit int }
         else
           begin
             expectloc:=LOC_REGISTER;
           end;
      end;

{$ifdef state_tracking}
    function TAddNode.track_state_pass(exec_known:boolean):boolean;

    var factval:TNode;

    begin
    track_state_pass:=false;
    if left.track_state_pass(exec_known) then
      begin
        track_state_pass:=true;
        left.resultdef:=nil;
        DoTypeCheckPass(left);
      end;
    factval:=aktstate.find_fact(left);
    if factval<>nil then
        begin
        track_state_pass:=true;
            left.free;
            left:=factval.GetCopy;
        end;
    if right.track_state_pass(exec_known) then
        begin
        track_state_pass:=true;
        right.resultdef:=nil;
        DoTypeCheckPass(right);
        end;
    factval:=aktstate.find_fact(right);
    if factval<>nil then
        begin
        track_state_pass:=true;
            right.free;
            right:=factval.GetCopy;
        end;
    end;
{$endif}
{$ifdef DEBUG_NODE_XML}
    procedure TAddNode.XMLPrintNodeInfo(var T: Text);
      var
        i: TAddNodeFlag;
        First: Boolean;
      begin
        inherited XMLPrintNodeInfo(T);
        First := True;
        for i in addnodeflags do
          begin
            if First then
              begin
                Write(T, ' addnodeflags="', i);
                First := False;
              end
            else
              Write(T, ',', i)
          end;
        if not First then
          Write(T, '"');
      end;
{$endif DEBUG_NODE_XML}

end.
