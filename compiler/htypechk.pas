{
    Copyright (c) 1998-2002 by Florian Klaempfl

    This unit exports some help routines for the type checking

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
unit htypechk;

{$i fpcdefs.inc}

interface

    uses
      SysUtils,CClasses,CMsgs,tokens,
      node,GlobType,compinnr,
      symconst,symtype,symdef,SymSym,SymBase,
      pgentype;

    type
      TSupportedOpOverload = (op_unary, op_binary);
      Ttok2nodeRec=record
        tok : TToken;
        nod : TNodeType;
        inr : TInlineNumber;
        supported_op_overloads: set of TSupportedOpOverload;
      end;

      Ttok2opRec=record
        tok : TToken;
        managementoperator : TManagementOperator;
      end;

      PCandidate = ^TCandidate;
      TCandidate = object
         next         : PCandidate;
         data         : TProcDef;
         wrongparaidx,
         firstparaidx : integer;
         te_count : array[te_convert_operator .. te_exact] of integer; { should be signed }
         ordinal_distance_lo : uint64;
         ordinal_distance_hi,ordinal_distance_secondary : uint32; { “hi” allows summing many uint64s, “secondary” allows tie-break corrections. }
         invalid : boolean;
{$ifndef DISABLE_FAST_OVERLOAD_PATCH}
         saved_validity : boolean;
{$endif}
         wrongparanr : byte;
         procedure increment_ordinal_distance(by: uint64);
      end;

      TCallCandidatesFlag =
      (
        cc_ignorevisibility,cc_allowdefaultparas,cc_objcidcall,cc_explicitunit,cc_searchhelpers,cc_anoninherited
      );
      TCallCandidatesFlags = set of TCallCandidatesFlag;

      TCallCandidates = object
      private
        FProcsym     : TProcSym;
        FProcsymtable : TSymTable;
        FOperator    : TToken;
        FCandidateProcs    : PCandidate;
        FIgnoredCandidateProcs : TFPList;
        FProcCnt    : integer;
        FParaNode   : TNode;
        FParaLength : smallint;
        FAllowVariant : boolean;
        FParaAnonSyms : TFPList;
        procedure collect_overloads_in_struct(structdef:TAbstractRecordDef;ProcdefOverloadList:TFPObjectList;flags:TCallCandidatesFlags;spezcontext:TSpecializationContext);
        procedure collect_overloads_in_units(ProcdefOverloadList:TFPObjectList; flags:TCallCandidatesFlags;spezcontext:TSpecializationContext);
        procedure create_candidate_list(flags:TCallCandidatesFlags;spezcontext:TSpecializationContext);
        procedure calc_distance(st_root:TSymTable;flags:TCallCandidatesFlags);
        function  proc_add(st:TSymTable;pd:TProcDef):PCandidate;
      public
        constructor init(sym:TProcSym;st:TSymTable;ppn:TNode;flags:TCallCandidatesFlags;spezcontext:TSpecializationContext);
        constructor init_operator(op:TToken;ppn:TNode);
        destructor done;
        procedure list(all:boolean);
{$ifdef EXTDEBUG}
        procedure dump_info(lvl:LongInt);
{$endif EXTDEBUG}
        procedure get_information;
        function  choose_best(var bestpd:TAbstractProcDef; singlevariant: boolean):integer;
        procedure find_wrong_para;
        property  Count:integer read FProcCnt;
        { list of symbols for anonymous types required for implicit specializations;
          these should be handed over to the picked procdef, otherwise they'll be
          freed by tcallcandidates }
        property para_anon_syms:TFPList read FParaAnonSyms;
      end;

    type
      TRegableInfoFlag = (
         // can be put in a register if it's the address of a var/out/const parameter
         ra_addr_regable,
         { orthogonal to above flag: the address of the node is taken and may
           possibly escape the block in which this node is declared (e.g. a
           local variable is passed as var parameter to another procedure)
         }
         ra_addr_taken,
         { variable is accessed in a different scope }
         ra_different_scope);
      TRegableInfoFlags = set of TRegableInfoFlag;

    const
      tok2nodes=27;
      tok2node:array[1..tok2nodes] of ttok2noderec=(
        (tok:_PLUS       ;nod:addn     ;inr:in_none ;supported_op_overloads:[op_unary,op_binary]),
        (tok:_MINUS      ;nod:subn     ;inr:in_none ;supported_op_overloads:[op_unary,op_binary]),
        (tok:_STAR       ;nod:muln     ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_SLASH      ;nod:slashn   ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_EQ         ;nod:equaln   ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_GT         ;nod:gtn      ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_LT         ;nod:ltn      ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_GTE        ;nod:gten     ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_LTE        ;nod:lten     ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_SYMDIF     ;nod:symdifn  ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_STARSTAR   ;nod:starstarn;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_OP_AS      ;nod:asn      ;inr:in_none ;supported_op_overloads:[]),
        (tok:_OP_IN      ;nod:inn      ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_OP_IS      ;nod:isn      ;inr:in_none ;supported_op_overloads:[]),
        (tok:_OP_OR      ;nod:orn      ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_OP_AND     ;nod:andn     ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_OP_DIV     ;nod:divn     ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_OP_NOT     ;nod:notn     ;inr:in_none ;supported_op_overloads:[op_unary]),
        (tok:_OP_MOD     ;nod:modn     ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_OP_SHL     ;nod:shln     ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_OP_SHR     ;nod:shrn     ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_OP_XOR     ;nod:xorn     ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_ASSIGNMENT ;nod:assignn  ;inr:in_none ;supported_op_overloads:[op_unary]),
        (tok:_OP_EXPLICIT;nod:assignn  ;inr:in_none ;supported_op_overloads:[op_unary]),
        (tok:_NE         ;nod:unequaln ;inr:in_none ;supported_op_overloads:[op_binary]),
        (tok:_OP_INC     ;nod:inlinen  ;inr:in_inc_x;supported_op_overloads:[op_unary]),
        (tok:_OP_DEC     ;nod:inlinen  ;inr:in_dec_x;supported_op_overloads:[op_unary])
      );

      tok2ops=4;
      tok2op: array[1..tok2ops] of ttok2oprec=(
        (tok:_OP_INITIALIZE; managementoperator: mop_initialize),
        (tok:_OP_FINALIZE  ; managementoperator: mop_finalize),
        (tok:_OP_ADDREF    ; managementoperator: mop_addref),
        (tok:_OP_COPY      ; managementoperator: mop_copy)
      );

    function node2opstr(nt:TNodeType):string;
    function token2managementoperator(optoken:TToken):TManagementOperator;

    { check operator args and result type }

    type
      TOverloadCheckFlag = (
        ocf_check_non_overloadable, { also check operators that are (currently) considered as
                                      not overloadable (e.g. the "+" operator for dynamic arrays
                                      if modeswitch arrayoperators is active) }
        ocf_check_only              { only check whether the operator is overloaded, but don't
                                      modify the passed in node (return true if the operator is
                                      overloaded, false otherwise) }
      );
      TOverloadCheckFlags = set of TOverloadCheckFlag;

    function isbinaryoperatoroverloadable(treetyp:TNodeType;ld:TDef;lt:TNodeType;rd:TDef;rt:TNodeType) : boolean;
    function isoperatoracceptable(pf : TProcDef; optoken : TToken) : boolean;
    function isunaryoverloaded(var t : TNode;ocf:TOverloadCheckFlags) : boolean;
    function isbinaryoverloaded(var t : TNode;ocf:TOverloadCheckFlags) : boolean;

    { Register Allocation }
    procedure make_not_regable(p : TNode; how: TRegableInfoFlags);

    { procvar handling }
    function  is_proc2procvar_load(p:TNode;out realprocdef:TProcDef):boolean;
    { returns whether a node represents a load of the function result node via
      the function name (so it could also be a recursive call to the function
      in case there or no parameters, or the function could be passed as
      procvar }
    function  is_ambiguous_funcret_load(p: TNode; out owningprocdef: TProcDef): boolean;
    procedure test_local_to_procvar(from_def:TProcVarDef;to_def:TDef);

    { sets varsym varstate field correctly }
    type
      TVarStateFlag = (vsf_must_be_valid,vsf_use_hints,vsf_use_hint_for_string_result);
      TVarStateFlags = set of TVarStateFlag;
    procedure set_varstate(p:TNode;newstate:TVarState;varstateflags:TVarStateFlags);

    { sets the callunique flag, if the node is a vecn, }
    { takes care of type casts etc.                 }
    procedure set_unique(p : TNode);

    function  valid_for_formal_var(p : TNode; report_errors: boolean) : boolean;
    function  valid_for_formal_constref(p : TNode; report_errors: boolean) : boolean;
    function  valid_for_formal_const(p : TNode; report_errors: boolean) : boolean;
    function  valid_for_var(p:TNode; report_errors: boolean):boolean;
    function  valid_for_assignment(p:TNode; report_errors: boolean):boolean;
    function  valid_for_loopvar(p:TNode; report_errors: boolean):boolean;
    function  valid_for_addr(p : TNode; report_errors: boolean) : boolean;

    function allowenumop(nt:TNodeType):boolean;

    procedure check_ranges(const location: TFilePosInfo; source: TNode; destdef: TDef);

    { returns whether the def may be used in the Default() intrinsic; static
      arrays, records and objects are checked recursively }
    function is_valid_for_default(def:TDef):boolean;

    procedure UninitializedVariableMessage(pos : TFilePosInfo;warning,local,managed : boolean;name : TMsgStr);

implementation

    uses
       Systems,ConstExp,Globals,
       CUtils,Verbose,
       SymTable,symutil,
       defutil,defcmp,
       nbas,ncnv,nld,nmem,ncal,nmat,ninl,nutils,ProcInfo,
       pgenutil
       ;

    type
      TValidAssign=(Valid_Property,Valid_Void,Valid_Const,Valid_Addr,Valid_Packed,Valid_Range);
      TValidAssigns=set of TValidAssign;


    { keep these two in sync! }
    const
      non_commutative_op_tokens=[_OP_SHL,_OP_SHR,_OP_DIV,_OP_MOD,_STARSTAR,_SLASH,_MINUS];
      non_commutative_op_nodes=[shln,shrn,divn,modn,starstarn,slashn,subn];


    function node2opstr(nt:TNodeType):string;
      var
        i : integer;
      begin
        result:='<unknown>';
        for i:=1 to tok2nodes do
          if tok2node[i].nod=nt then
            begin
              result:=tokeninfo^[tok2node[i].tok].str;
              break;
            end;
       end;


    function token2managementoperator(optoken:TToken):TManagementOperator;
      var
        i : integer;
      begin
        result:=mop_none;
        for i:=1 to tok2ops do
          if tok2op[i].tok=optoken then
            begin
              result:=tok2op[i].managementoperator;
              break;
            end;
      end;


    function isbinaryoperatoroverloadable(treetyp:TNodeType;ld:TDef;lt:TNodeType;rd:TDef;rt:TNodeType) : boolean;

        function internal_check(treetyp:TNodeType;ld:TDef;lt:TNodeType;rd:TDef;rt:TNodeType;var allowed:boolean):boolean;
        const
          identity_operators=[equaln,unequaln];
          order_theoretic_operators=identity_operators+[ltn,lten,gtn,gten];
          arithmetic_operators=[addn,subn,muln,divn,modn];
          rational_operators=[addn,subn,muln,slashn];
          numerical_operators=arithmetic_operators+[slashn];
          pointer_arithmetic_operators=[addn,subn];
          logical_operators=[andn,orn,xorn];
          bit_manipulation_operators=logical_operators+[shln,shrn];
          set_set_operators=identity_operators+[addn,subn,muln,symdifn]+
            order_theoretic_operators;
          element_set_operators=[inn];
          string_comparison_operators=order_theoretic_operators;
          string_manipulation_operators=[addn];
          string_operators =
            string_comparison_operators+string_manipulation_operators;
        begin
          internal_check:=true;

          { Reject the cases permitted by the default interpretation (DI). }
          case ld.typ of
            formaldef,
            recorddef,
            variantdef :
              begin
                allowed:=true;
              end;
            enumdef:
              begin
                allowed:=not (
                           (
                             is_set(rd) and
                             (treetyp in element_set_operators)
                           ) or
                           (
                             is_enum(rd) and
                             (treetyp in (order_theoretic_operators+[addn, subn]))
                           ) or
                           (
                             { for enum definitions, see tbs/tw22860.pas }
                             is_integer(rd) and
                             (treetyp in (order_theoretic_operators+bit_manipulation_operators+arithmetic_operators))
                           )
                         );
              end;
            setdef:
              begin
                allowed:=not (
                           (
                             is_set(rd) and
                             (treetyp in (set_set_operators+identity_operators))
                           ) or
                           (
                             { This clause is a hack but it’s due to a hack somewhere
                               else---while set + element is not permitted by DI, it
                               seems to be used when a set is constructed inline }
                             (rd.typ in [enumdef,orddef]) and
                             (treetyp=addn)
                           )
                         );
              end;
            orddef, floatdef:
              begin
                allowed:=not (
                           (
                             (rd.typ in [orddef,floatdef]) and
                             (treetyp in order_theoretic_operators)
                           ) or
                           (
                             (m_mac in CurrentSettings.ModeSwitches) and
                             is_stringlike(rd) and
                             (ld.typ=orddef) and
                             (treetyp in string_comparison_operators)) or
                             { c.f. $(source)\tests\tmacpas5.pas }
                             (
                               (rd.typ=setdef) and
                               (ld.typ=orddef) and
                               (treetyp in element_set_operators)
                             )
                            { This clause may be too restrictive---not all types under
                              orddef have a corresponding set type; despite this the
                              restriction should be very unlikely to become
                              a practical obstacle, and can be relaxed by simply
                              adding an extra check on TOrdDef(rd).ordtype }
                           );

                { Note that Currency can be under either orddef or floatdef;
                  when it’s under floatdef, is_currency() implies is_float();
                  when it’s under orddef, is_currency() does NOT imply
                  is_integer(). }
                if allowed then
                  begin
                    if is_anychar(ld) then
                      allowed:=not (
                                 is_stringlike(rd) and
                                 (treetyp in string_operators)
                               )
                    else if is_boolean(ld) then
                      allowed:=not (
                                 is_boolean(rd) and
                                 (treetyp in logical_operators)
                               )
                    else if is_integer(ld) or
                        (
                          (ld.typ=orddef) and
                          is_currency(ld)
                        { Here ld is Currency but behaves like an integer }
                        ) then
                      allowed:=not (
                                 (
                                   (
                                     is_integer(rd) or
                                     (
                                       (rd.typ=orddef) and
                                       is_currency(rd)
                                     )
                                   ) and
                                   (treetyp in (bit_manipulation_operators+numerical_operators))
                                 ) or
                                 (
                                   is_fpu(rd) and
                                   (treetyp in rational_operators)
                                 ) or
                                 (
                                   { When an integer type is used as the first operand in
                                     pointer arithmetic, DI doesn’t accept minus as the
                                     operator (Currency can’t be used in pointer
                                     arithmetic even if it’s under orddef)  }
                                   is_integer(ld) and
                                   (rd.typ=pointerdef) and
                                   (treetyp in pointer_arithmetic_operators-[subn])
                                 )
                               )
                    else  { is_fpu(ld) = True }
                      allowed:=not (
                                 (
                                   is_fpu(rd) or
                                   is_integer(rd) or
                                   is_currency(rd)
                                 ) and
                                 (treetyp in rational_operators)
                               );
                  end;
              end;
            procvardef :
              begin
                if (rd.typ in [pointerdef,procdef,procvardef]) then
                 begin
                   allowed:=false;
                   exit;
                 end;
                allowed:=true;
              end;
            pointerdef :
              begin
                { DI permits pointer arithmetic for pointer + pointer, pointer -
                  integer, pointer - pointer, but not for pointer + pointer.
                  The last case is only valid in DI when both sides are
                  stringlike. }

                if is_stringlike(ld) then
                  if is_stringlike(rd) then
                    { DI in this case permits string operations and pointer
                      arithmetic. }
                    allowed:=not (treetyp in (string_operators+pointer_arithmetic_operators))
                  else if rd.typ = pointerdef then
                    { DI in this case permits minus for pointer arithmetic and
                      order-theoretic operators for pointer comparison. }
                    allowed:=not (
                               treetyp in (
                                 pointer_arithmetic_operators-[addn]+
                                 order_theoretic_operators
                               )
                             )
                  else if is_integer(rd) then
                    { DI in this case permits pointer arithmetic. }
                    allowed:=not (treetyp in pointer_arithmetic_operators)
                  else
                    allowed:=true
                else
                  allowed:=not (
                             (
                               is_integer(rd) and
                               (treetyp in pointer_arithmetic_operators)
                             ) or
                             (
                               (rd.typ=pointerdef) and
                               (
                                 treetyp in (
                                   pointer_arithmetic_operators-[addn]+
                                   order_theoretic_operators
                                 )
                               )
                             ) or
                             (
                               (lt=niln) and
                               ((rd.typ in [procvardef,procdef,classrefdef]) or
                                (is_dynamic_array(rd))) and
                               (treetyp in identity_operators)
                             ) or
                             (
                               is_implicit_pointer_object_type(rd) and
                               (treetyp in identity_operators)
                             )
                           );
              end;
            arraydef :
              begin
                { not vector/mmx }
                if ((cs_mmx in CurrentSettings.LocalSwitches) and
                   is_mmx_able_array(ld)) or
                   ((cs_support_vectors in CurrentSettings.GlobalSwitches) and
                   is_vector(ld)) then
                 begin
                   allowed:=false;
                   exit;
                 end;

                if is_stringlike(ld) and
                    (
                      (
                        (
                          is_stringlike(rd) or
                          (rt = niln)
                        ) and
                        (treetyp in string_operators)
                      ) or
                      (
                        is_integer(rd) and
                        (treetyp in pointer_arithmetic_operators)
                      ) or
                      (
                        (
                          is_pchar(rd) or
                          is_pwidechar(rd)) and
                          (treetyp in pointer_arithmetic_operators) and
                          (TPointerDef(rd).pointeddef=TArrayDef(ld).elementdef
                        )
                      )
                    ) then
                  begin
                    allowed:=false;
                    exit;
                  end;

                { dynamic array compare with niln }
                if is_dynamic_array(ld) and
                    (treetyp in identity_operators) then
                  if is_dynamic_array(rd) or
                      (rt=niln) then
                    begin
                      allowed:=false;
                      exit;
                    end;

                 { <dyn. array> + <dyn. array> is handled by the compiler }
                 if (m_array_operators in CurrentSettings.ModeSwitches) and
                     (treetyp=addn) and
                     (is_dynamic_array(ld) or is_array_constructor(ld)) and
                     (is_dynamic_array(rd) or is_array_constructor(rd)) then
                    begin
                      allowed:=false;
                      exit;
                    end;

                allowed:=true;
              end;
            objectdef :
              begin
                { <> and = are defined for implicit pointer object types }
                allowed:=not (
                           is_implicit_pointer_object_type(ld) and
                           (
                             (
                               is_implicit_pointer_object_type(rd) or
                               (rd.typ=pointerdef) or
                               (rt=niln) or
                               ((ld=java_jlstring) and
                                is_stringlike(rd))
                             )
                           ) and
                           (treetyp in identity_operators)
                         );
              end;
            stringdef :
              begin
                allowed:=not (
                           is_stringlike(rd) and
                           (treetyp in string_operators)
                         );
              end;
            else
              internal_check:=false;
          end;
        end;

      begin
        { power ** is always possible }
        result:=treetyp=starstarn;
        if not result then
          begin
            if not internal_check(treetyp,ld,lt,rd,rt,result) and
                not (treetyp in non_commutative_op_nodes) then
              internal_check(treetyp,rd,rt,ld,lt,result)
          end;
      end;


    function isunaryoperatoroverloadable(treetyp:TNodeType;inlinenumber:TInlineNumber;ld:TDef) : boolean;
      begin
        result:=false;
        case treetyp of
          subn,
          addn,
          unaryminusn,
          unaryplusn,
          inlinen:
            begin
              { only Inc, Dec inline functions are supported for now, so skip check inlinenumber }

              if (ld.typ in [orddef,enumdef,floatdef]) then
                exit;

{$ifdef SUPPORT_MMX}
              if (cs_mmx in CurrentSettings.LocalSwitches) and
                 is_mmx_able_array(ld) then
                exit;
{$endif SUPPORT_MMX}

              result:=true;
            end;

          notn :
            begin
              if ld.typ = orddef then exit;

{$ifdef SUPPORT_MMX}
              if (cs_mmx in CurrentSettings.LocalSwitches) and
                 is_mmx_able_array(ld) then
                exit;
{$endif SUPPORT_MMX}

              result:=true;
            end;
          else
            ;
        end;
      end;


    function isoperatoracceptable(pf : TProcDef; optoken : TToken) : boolean;
      var
        ld,rd : TDef;
        i : LongInt;
        eq : TEqualType;
        conv : TConvertType;
        cdo : TCompareDefsOptions;
        pd : TProcDef;
        oldcount,
        count: LongInt;
        sym : TSym;
        parasym : TParaVarSym absolute sym;
      begin
        result:=false;
        count := pf.parast.SymList.count;

        oldcount:=count;
        while count > 0 do
          begin
            sym:=TSym(pf.parast.SymList[count-1]);
            if sym.typ<>paravarsym then
              begin
                dec(count);
              end
            else if is_boolean(parasym.vardef) then
              begin
                if parasym.name='RANGECHECK' then
                  begin
                    Include(parasym.varoptions, vo_is_hidden_para);
                    Include(parasym.varoptions, vo_is_range_check);
                    Dec(count);
                  end
                else if parasym.name='OVERFLOWCHECK' then
                  begin
                    Include(parasym.varoptions, vo_is_hidden_para);
                    Include(parasym.varoptions, vo_is_overflow_check);
                    Dec(count);
                  end
                else
                  break;
              end
            else
              break;
          end;
        if count<>oldcount then
          pf.calcparas;

        case count of
          1 : begin
                ld:=TParaVarSym(pf.parast.SymList[0]).vardef;
                { assignment is a special case }
                if optoken in [_ASSIGNMENT,_OP_EXPLICIT] then
                  begin
                    cdo:=[];
                    if optoken=_OP_EXPLICIT then
                      include(cdo,cdo_explicit);
                    eq:=compare_defs_ext(ld,pf.returndef,nothingn,conv,pd,cdo);
                    result:=
                      (eq=te_exact) or
                      (eq=te_incompatible);
                  end
                else
                { enumerator is a special case too }
                if optoken=_OP_ENUMERATOR then
                  begin
                    result:=
                      is_class_or_interface_or_object(pf.returndef) or
                      is_record(pf.returndef);
                    if result then
                      begin
                        if not Assigned(TAbstractRecordDef(pf.returndef).search_enumerator_move) then
                          begin
                            Message1(sym_e_no_enumerator_move, pf.returndef.typename);
                            result:=false;
                          end;
                        if not Assigned(TAbstractRecordDef(pf.returndef).search_enumerator_current) then
                          begin
                            Message1(sym_e_no_enumerator_current,pf.returndef.typename);
                            result:=false;
                          end;
                      end;
                  end
                else
                  begin
                    for i:=1 to tok2nodes do
                      if tok2node[i].tok=optoken then
                        begin
                          result:=
                            (op_unary in tok2node[i].supported_op_overloads) and
                            isunaryoperatoroverloadable(tok2node[i].nod,tok2node[i].inr,ld);
                          break;
                        end;
                    { Inc, Dec operators are valid if only result type is the same as argument type }
                    if result and (optoken in [_OP_INC,_OP_DEC]) then
                      result:=pf.returndef=ld;
                  end;
              end;
          2 : begin
                ld:=TParaVarSym(pf.parast.SymList[0]).vardef;
                rd:=TParaVarSym(pf.parast.SymList[1]).vardef;
                for i:=1 to tok2nodes do
                  if tok2node[i].tok=optoken then
                    begin
                      result:=
                        (op_binary in tok2node[i].supported_op_overloads) and
                        isbinaryoperatoroverloadable(tok2node[i].nod,ld,nothingn,rd,nothingn);
                      break;
                    end;
              end;
        end;
      end;


    function isunaryoverloaded(var t : TNode;ocf:TOverloadCheckFlags) : boolean;
      var
        ld      : TDef;
        optoken : TToken;
        operpd  : TProcDef;
        ppn     : TCallParaNode;
        candidates : TCallCandidates;
        cand_cnt : integer;
        inlinenumber: TInlineNumber;
      begin
        result:=false;
        operpd:=nil;

        { load easier access variables }
        ld:=TUnaryNode(t).left.resultdef;

        { if we are dealing with inline function then get the function }
        if t.nodetype=inlinen then
          inlinenumber:=TInlineNode(t).inlinenumber
        else
          inlinenumber:=in_none;

        if not (ocf_check_non_overloadable in ocf) and not isunaryoperatoroverloadable(t.nodetype,inlinenumber,ld) then
          exit;

        { operator overload is possible }
        result:=not (ocf_check_only in ocf);

        optoken:=NOTOKEN;
        case t.nodetype of
           notn:
             optoken:=_OP_NOT;
           unaryminusn:
             optoken:=_MINUS;
           unaryplusn:
             optoken:=_PLUS;
           inlinen:
             case inlinenumber of
                in_inc_x:
                  optoken:=_OP_INC;
                in_dec_x:
                  optoken:=_OP_DEC;
                else
                  ;
             end;
           else
             ;
        end;
        if (optoken=NOTOKEN) then
          begin
            if not (ocf_check_only in ocf) then
              begin
                CGMessage(parser_e_operator_not_overloaded);
                t:=CNothingNode.create;
              end;
            exit;
          end;

        { generate parameter nodes }
        { for inline nodes just copy existent callparanode }
        if (t.nodetype=inlinen) and (TInlineNode(t).left.nodetype=callparan) then
          ppn:=TCallParaNode(TInlineNode(t).left.getcopy)
        else
          begin
            ppn:=CCallParaNode.create(TUnaryNode(t).left.getcopy,nil);
            ppn.get_paratype;
          end;
        candidates.init_operator(optoken,ppn);

        { stop when there are no operators found }
        if candidates.count=0 then
          begin
            candidates.done;
            ppn.free;
            ppn := nil;
            if not (ocf_check_only in ocf) then
              begin
                CGMessage2(parser_e_operator_not_overloaded_2,ld.typename,arraytokeninfo[optoken].str);
                t:=CNothingNode.create;
              end;
            exit;
          end;

        { Retrieve information about the candidates }
        candidates.get_information;
{$ifdef EXTDEBUG}
        { Display info when multiple candidates are found }
        candidates.dump_info(VDebug);
{$endif EXTDEBUG}
        cand_cnt:=candidates.choose_best(TAbstractProcDef(operpd),false);

        { exit when no overloads are found }
        if cand_cnt=0 then
          begin
            candidates.done;
            ppn.free;
            ppn := nil;
            if not (ocf_check_only in ocf) then
              begin
                CGMessage2(parser_e_operator_not_overloaded_2,ld.typename,arraytokeninfo[optoken].str);
                t:=CNothingNode.create;
              end;
            exit;
          end;

        { Multiple candidates left? }
        if (cand_cnt>1) and not (ocf_check_only in ocf) then
          begin
            CGMessage(type_e_cant_choose_overload_function);
{$ifdef EXTDEBUG}
            candidates.dump_info(VHint);
{$else EXTDEBUG}
            candidates.list(false);
{$endif EXTDEBUG}
            { we'll just use the first candidate to make the
              call }
          end;
        candidates.done;

        if ocf_check_only in ocf then
          begin
            ppn.free;
            ppn := nil;
            result:=true;
            exit;
          end;

        addsymref(operpd.procsym,operpd);

        { the nil as symtable signs firstcalln that this is
          an overloaded operator }
        t:=CCallNode.create(ppn,TProcSym(operpd.procsym),nil,nil,[],nil);

        { we already know the procdef to use, so it can
          skip the overload choosing in callnode.pass_typecheck }
        TCallNode(t).procdefinition:=operpd;
      end;


    function isbinaryoverloaded(var t : TNode;ocf:TOverloadCheckFlags) : boolean;
      var
        rd,ld   : TDef;
        optoken : TToken;
        operpd  : TProcDef;
        ht      : TNode;
        ppn     : TCallParaNode;
        i,cand_cnt : sizeint;

        function search_operator(optoken:TToken;generror:boolean): integer;
          var
            candidates : TCallCandidates;
          begin
            { generate parameter nodes }
            ppn:=CCallParaNode.create(TBinaryNode(t).right.getcopy,CCallParaNode.create(TBinaryNode(t).left.getcopy,nil));
            ppn.get_paratype;
            candidates.init_operator(optoken,ppn);

            { for commutative operators we can swap arguments and try again }
            if (candidates.count=0) and
               not(optoken in non_commutative_op_tokens) then
              begin
                candidates.done;
                reverseparameters(ppn);
                { reverse compare operators }
                case optoken of
                  _LT:
                    optoken:=_GTE;
                  _GT:
                    optoken:=_LTE;
                  _LTE:
                    optoken:=_GT;
                  _GTE:
                    optoken:=_LT;
                  else
                    ;
                end;
                candidates.init_operator(optoken,ppn);
              end;

            { stop when there are no operators found }
            result:=candidates.count;
            if (result=0) and generror then
              begin
                CGMessage(parser_e_operator_not_overloaded);
                candidates.done;
                ppn.free;
                ppn:=nil;
                exit;
              end;

            if (result>0) then
              begin
                { Retrieve information about the candidates }
                candidates.get_information;
        {$ifdef EXTDEBUG}
                { Display info when multiple candidates are found }
                candidates.dump_info(VDebug);
        {$endif EXTDEBUG}
                result:=candidates.choose_best(TAbstractProcDef(operpd),false);
              end;

            { exit when no overloads are found }
            if (result=0) and generror then
              begin
                CGMessage3(parser_e_operator_not_overloaded_3,ld.GetTypeName,arraytokeninfo[optoken].str,rd.GetTypeName);
                candidates.done;
                ppn.free;
                ppn:=nil;
                exit;
              end;

            { Multiple candidates left? }
            if result>1 then
              begin
                CGMessage(type_e_cant_choose_overload_function);
    {$ifdef EXTDEBUG}
                candidates.dump_info(VHint);
    {$else EXTDEBUG}
                candidates.list(false);
    {$endif EXTDEBUG}
                { we'll just use the first candidate to make the
                  call }
              end;
            candidates.done;
          end;

      begin
        isbinaryoverloaded:=false;
        operpd:=nil;
        ppn:=nil;

        { load easier access variables }
        ld:=TBinaryNode(t).left.resultdef;
        rd:=TBinaryNode(t).right.resultdef;
        if not (ocf_check_non_overloadable in ocf) and
            not isbinaryoperatoroverloadable(t.nodetype,ld,TBinaryNode(t).left.nodetype,rd,TBinaryNode(t).right.nodetype) then
          exit;

        { operator overload is possible }
        { if we only check for the existence of the overload, then we assume that
          it is not overloaded }
        result:=not (ocf_check_only in ocf);

        optoken:=NOTOKEN;
        for i:=1 to tok2nodes do
          if (t.nodetype=tok2node[i].nod) and (op_binary in tok2node[i].supported_op_overloads) then
            begin
              optoken:=tok2node[i].tok;
              break;
            end;
        if optoken=NOTOKEN then
          begin
            if not (ocf_check_only in ocf) then
              begin
                CGMessage(parser_e_operator_not_overloaded);
                t:=CNothingNode.create;
              end;
            exit;
          end;

        cand_cnt:=search_operator(optoken,(optoken<>_NE) and not (ocf_check_only in ocf));

        { no operator found for "<>" then search for "=" operator }
        if (cand_cnt=0) and (optoken=_NE) and not (ocf_check_only in ocf) then
          begin
            ppn.free;
            ppn:=nil;
            operpd:=nil;
            optoken:=_EQ;
            cand_cnt:=search_operator(optoken,true);
          end;

        if (cand_cnt=0) then
          begin
            ppn.free;
            ppn := nil;
            if not (ocf_check_only in ocf) then
              t:=CNothingNode.create;
            exit;
          end;

        if ocf_check_only in ocf then
          begin
            ppn.free;
            ppn := nil;
            result:=true;
            exit;
          end;

        addsymref(operpd.procsym,operpd);

        { the nil as symtable signs firstcalln that this is
          an overloaded operator }
        ht:=CCallNode.create(ppn,TProcSym(operpd.procsym),nil,nil,[],nil);

        { we already know the procdef to use, so it can
          skip the overload choosing in callnode.pass_typecheck }
        TCallNode(ht).procdefinition:=operpd;

        { if we found "=" operator for "<>" expression then use it
          together with "not" }
        if (t.nodetype=unequaln) and (optoken=_EQ) then
          ht:=CNotNode.create(ht);
        t:=ht;
      end;


{****************************************************************************
                          Register Calculation
****************************************************************************}

    { marks an lvalue as "unregable" }
    procedure make_not_regable_intern(p : TNode; how: TRegableInfoFlags; records_only: boolean);
      var
        lHighSym: TAbstractVarSym;
      begin
        if ra_addr_taken in how then
          include(p.flags,nf_address_taken);
        repeat
          case p.nodetype of
            subscriptn:
              begin
                records_only:=true;
                p:=TSubscriptNode(p).left;
              end;
            vecn:
              begin
                { if there's an implicit dereference, we can stop (just like
                  when there is an actual derefn) }
                if ((TVecNode(p).left.resultdef.typ=arraydef) and
                    not is_special_array(TVecNode(p).left.resultdef)) or
                   ((TVecNode(p).left.resultdef.typ=stringdef) and
                    (TStringDef(TVecNode(p).left.resultdef).stringtype in [st_shortstring,st_longstring])) then
                  p:=TVecNode(p).left
                else
                  break;
              end;
            typeconvn :
               begin
                 { implicit dereference -> stop }
                 if (TTypeConvNode(p).convtype=tc_pointer_2_array) then
                   break;
                 if (TTypeConvNode(p).resultdef.typ=recorddef) then
                   records_only:=false;
                 p:=TTypeConvNode(p).left;
               end;
            loadn :
              begin
                if (TLoadNode(p).symtableentry.typ in [staticvarsym,localvarsym,paravarsym]) then
                  begin
                    if (ra_addr_taken in how) then
                      TAbstractVarSym(TLoadNode(p).symtableentry).addr_taken:=true;
                    if (ra_different_scope in how) then
                      begin
                        TAbstractVarSym(TLoadNode(p).symtableentry).different_scope:=true;
                        { Hidden bounds can be loaded only during code generation.
                          Reserve their frame location before allocating the parent. }
                        if TLoadNode(p).symtableentry.typ=paravarsym then
                          begin
                            lHighSym:=get_high_value_sym(TParaVarSym(TLoadNode(p).symtableentry));
                            if Assigned(lHighSym) then
                              begin
                                lHighSym.different_scope:=true;
                                lHighSym.varregable:=vr_none;
                              end;
                          end;
                      end;
                    if (TAbstractVarSym(TLoadNode(p).symtableentry).varregable <> vr_none) and
                       ((not records_only) or
                        (TAbstractVarSym(TLoadNode(p).symtableentry).vardef.typ = recorddef)) then
                      if (TLoadNode(p).symtableentry.typ = paravarsym) and
                         (ra_addr_regable in how) then
                        TAbstractVarSym(TLoadNode(p).symtableentry).varregable:=vr_addr
                      else
                        TAbstractVarSym(TLoadNode(p).symtableentry).varregable:=vr_none;
                  end;
                break;
              end;
            temprefn :
              begin
                if (ra_addr_taken in how) then
                  TTempRefNode(p).includetempflag(ti_addr_taken);
                if (ti_may_be_in_reg in TTempRefNode(p).tempflags) and
                   ((not records_only) or
                    (TTempRefNode(p).tempinfo^.typedef.typ = recorddef)) then
                  TTempRefNode(p).excludetempflag(ti_may_be_in_reg);
                break;
              end;
            else
              break;
          end;
        until false;
      end;

    procedure make_not_regable(p : TNode; how: TRegableInfoFlags);
      begin
        make_not_regable_intern(p,how,false);
      end;


{****************************************************************************
                          Subroutine Handling
****************************************************************************}

    function is_proc2procvar_load(p:TNode;out realprocdef:TProcDef):boolean;
      begin
        result:=false;
        { remove voidpointer typecast for tp procvars }
        if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
            (m_mac_procvar in CurrentSettings.ModeSwitches)) and
           (p.nodetype=typeconvn) and
           is_voidpointer(p.resultdef) then
          p:=TUnaryNode(p).left;
        result:=(p.nodetype=typeconvn) and
                (TTypeConvNode(p).convtype=tc_proc_2_procvar);
        if result then
          realprocdef:=TProcDef(TTypeConvNode(p).left.resultdef);
      end;


    function is_ambiguous_funcret_load(p: TNode; out owningprocdef: TProcDef): boolean;
      begin
        result:=false;
        { the funcret is an absolutevarsym, which gets converted into a type
          conversion node of the loadnode of the actual function result. Its
          resulttype is obviously the same as that of the real function result }
        if (p.nodetype=typeconvn) and
              (p.resultdef=TTypeConvNode(p).left.resultdef) then
          p:=TTypeConvNode(p).left;
        if (p.nodetype=loadn) and
           (TLoadNode(p).symtableentry.typ in [absolutevarsym,localvarsym,paravarsym]) and
           ([vo_is_funcret,vo_is_result] * TAbstractVarSym(TLoadNode(p).symtableentry).varoptions = [vo_is_funcret]) then
         begin
           owningprocdef:=TProcDef(TLoadNode(p).symtableentry.owner.defowner);
           result:=true;
         end;
      end;


    { local routines can't be assigned to procvars }
    procedure test_local_to_procvar(from_def:TProcVarDef;to_def:TDef);
      begin
         if not(m_nested_procvars in CurrentSettings.ModeSwitches) and
            (from_def.parast.symtablelevel>normal_function_level) and
            not (po_anonymous in from_def.procoptions) and
            (to_def.typ=procvardef) and
            (TProcVarDef(to_def).parast.symtablelevel <= normal_function_level) then
           CGMessage(type_e_cannot_local_proc_to_procvar);
      end;


    procedure UninitializedVariableMessage(pos : TFilePosInfo;warning,local,managed : boolean;name : TMsgStr);
      const
        msg : array[false..true,false..true,false..true] of dword = (
            (
              (sym_h_uninitialized_variable,sym_h_uninitialized_managed_variable),
              (sym_h_uninitialized_local_variable,sym_h_uninitialized_managed_local_variable)
            ),
            (
              (sym_w_uninitialized_variable,sym_w_uninitialized_managed_variable),
              (sym_w_uninitialized_local_variable,sym_w_uninitialized_managed_local_variable)
            )
          );
      begin
        CGMessagePos1(pos,msg[warning,local,managed],name);
      end;


    procedure set_varstate(p:TNode;newstate:TVarState;varstateflags:TVarStateFlags);
      const
        vstrans: array[TVarState,TVarState] of TVarState = (
          { vs_none -> ... }
          (vs_none,vs_declared,vs_initialised,vs_read,vs_read_not_warned,vs_referred_not_inited,vs_written,vs_readwritten),
          { vs_declared -> ... }
          (vs_none,vs_declared,vs_initialised,vs_read,vs_read_not_warned,vs_referred_not_inited,vs_written,vs_readwritten),
          { vs_initialised -> ... }
          (vs_none,vs_initialised,vs_initialised,vs_read,vs_read,vs_read,vs_written,vs_readwritten),
          { vs_read -> ... }
          (vs_none,vs_read,vs_read,vs_read,vs_read,vs_read,vs_readwritten,vs_readwritten),
          { vs_read_not_warned -> ... }
          (vs_none,vs_read_not_warned,vs_read,vs_read,vs_read_not_warned,vs_read_not_warned,vs_readwritten,vs_readwritten),
          { vs_referred_not_inited }
          (vs_none,vs_referred_not_inited,vs_read,vs_read,vs_read_not_warned,vs_referred_not_inited,vs_written,vs_readwritten),
          { vs_written -> ... }
          (vs_none,vs_written,vs_written,vs_readwritten,vs_readwritten,vs_written,vs_written,vs_readwritten),
          { vs_readwritten -> ... }
          (vs_none,vs_readwritten,vs_readwritten,vs_readwritten,vs_readwritten,vs_readwritten,vs_readwritten,vs_readwritten));
      var
        hsym : TAbstractVarSym;
      begin
        { make sure we can still warn about uninitialised use after high(v), @v etc }
        if (newstate = vs_read) and
           not(vsf_must_be_valid in varstateflags) then
          newstate := vs_referred_not_inited;

        while Assigned(p) do
         begin
           case p.nodetype of
             derefn:
               begin
                 if (TDerefNode(p).left.nodetype=temprefn) and
                    Assigned(TTempRefNode(TDerefNode(p).left).tempinfo^.withnode) then
                   p:=TTempRefNode(TDerefNode(p).left).tempinfo^.withnode
                 else
                   break;
               end;
             typeconvn :
               begin
                 case TTypeConvNode(p).convtype of
                   tc_cchar_2_pchar,
                   tc_cstring_2_pchar,
                   tc_array_2_pointer :
                     exclude(varstateflags,vsf_must_be_valid);
                   tc_pchar_2_string,
                   tc_pointer_2_array :
                     begin
                       include(varstateflags,vsf_must_be_valid);
                       { when a pointer is used for array access, the
                         pointer itself is read and never written }
                       newstate := vs_read;
                     end;
                   else
                     ;
               end;
                 p:=TUnaryNode(p).left;
               end;
             subscriptn :
               begin
                 if is_implicit_pointer_object_type(TUnaryNode(p).left.resultdef) then
                   newstate := vs_read;
                 p:=TUnaryNode(p).left;
               end;
             vecn:
               begin
                 set_varstate(TBinaryNode(p).right,vs_read,[vsf_must_be_valid]);
                 { dyn. arrays and dyn. strings are read }
                 if is_implicit_array_pointer(TUnaryNode(p).left.resultdef) then
                   newstate:=vs_read;
                 if (newstate in [vs_read,vs_readwritten]) or
                    not(TUnaryNode(p).left.resultdef.typ in [stringdef,arraydef]) then
                   include(varstateflags,vsf_must_be_valid)
                 else if (newstate = vs_written) then
                   exclude(varstateflags,vsf_must_be_valid);
                 p:=TUnaryNode(p).left;
               end;
             { do not parse calln }
             calln :
               break;
             loadn :
               begin
                 { the methodpointer/framepointer is read }
                 if Assigned(TUnaryNode(p).left) then
                   set_varstate(TUnaryNode(p).left,vs_read,[vsf_must_be_valid]);
                 if (TLoadNode(p).symtableentry.typ in [localvarsym,paravarsym,staticvarsym]) then
                   begin
                     hsym:=TAbstractVarSym(TLoadNode(p).symtableentry);
                     { this check requires proper data flow analysis... }
(*                     if (hsym.varspez=vs_final) and
                        (hsym.varstate in [vs_written,vs_readwritten]) and
                        (newstate in [vs_written,vs_readwritten]) then
                       CGMessagePos1(p.fileinfo,sym_e_final_write_once); *)
                     if (vsf_must_be_valid in varstateflags) and
                        (hsym.varstate in [vs_declared,vs_read_not_warned,vs_referred_not_inited]) then
                       begin
                         { Give warning/note for uninitialized locals }
                         if Assigned(hsym.owner) and
                            not(vo_is_external in hsym.varoptions) and
                            (hsym.owner.symtabletype in [parasymtable,localsymtable,staticsymtable]) and
                            ((hsym.owner=CurrentProcInfo.procdef.localst) or
                             (hsym.owner=CurrentProcInfo.procdef.parast)) then
                           begin
                             if vsf_use_hints in varstateflags then
                               include(TLoadNode(p).loadnodeflags,loadnf_only_uninitialized_hint);
                             if not(cs_opt_nodedfa in CurrentSettings.OptimizerSwitches) then
                               begin
                                 if (vo_is_funcret in hsym.varoptions) then
                                   begin
                                     { An uninitialized function Result of a managed type needs special handling.
                                       When passing it as a var parameter a warning need to be emitted, since a user
                                       may expect Result to be empty (nil) by default as it happens with local vars
                                       of a managed type. But this is not true for Result and may lead to serious issues.

                                       The only exception is SetLength(Result, ?) for a string Result. A user always
                                       expects undefined contents of the string after calling SetLength(). In such
                                       case a hint need to be emitted.
                                     }
                                     if is_managed_type(hsym.vardef) then
                                       if not ( is_string(hsym.vardef) and (vsf_use_hint_for_string_result in varstateflags) ) then
                                         exclude(varstateflags,vsf_use_hints);

                                     if vsf_use_hints in varstateflags then
                                       begin
                                         if is_managed_type(hsym.vardef) then
                                           CGMessagePos(p.fileinfo,sym_h_managed_function_result_uninitialized)
                                         else
                                           CGMessagePos(p.fileinfo,sym_h_function_result_uninitialized);
                                       end
                                     else
                                       begin
                                         if is_managed_type(hsym.vardef) then
                                           CGMessagePos(p.fileinfo,sym_w_managed_function_result_uninitialized)
                                         else
                                          CGMessagePos(p.fileinfo,sym_w_function_result_uninitialized);
                                       end;
                                   end
                                 else
                                   begin
                                     UninitializedVariableMessage(p.fileinfo,
                                       { on the JVM, an uninitialized var-parameter
                                         is just as fatal as a nil pointer dereference }
                                       not(vsf_use_hints in varstateflags),
                                       TLoadNode(p).SymTable.symtabletype=localsymtable,
                                       is_managed_type(TLoadNode(p).resultdef),
                                       hsym.realname);
                                   end;
                               end;
                           end
                         else if (newstate = vs_read) then
                           newstate := vs_read_not_warned;
                       end;
                     hsym.varstate := vstrans[hsym.varstate,newstate];
                   end;
                 case newstate of
                   vs_written:
                     include(TLoadNode(p).flags,nf_write);
                   vs_readwritten:
                     if not(nf_write in TLoadNode(p).flags) then
                       include(TLoadNode(p).flags,nf_modify);
                   else
                     ;
                 end;
                 break;
               end;
             addrn:
               break;
             callparan :
               InternalError(200310081);
             else
               break;
           end;{case }
         end;
      end;


    procedure set_unique(p : TNode);
      begin
        while Assigned(p) do
         begin
           case p.nodetype of
             vecn:
               begin
                 include(TVecNode(p).vecnodeflags,vnf_callunique);
                 break;
               end;
             typeconvn,
             subscriptn,
             derefn:
               p:=TUnaryNode(p).left;
             else
               break;
           end;
         end;
      end;


    function  valid_for_assign(p:TNode;opts:TValidAssigns; report_errors: boolean):boolean;
      var
        typeconvs: TFPObjectList;
        hp2,
        hp : TNode;
        gotstring,
        gotsubscript,
        gotrecord,
        gotvec,
        gottypeconv : boolean;
        fromdef,
        todef    : TDef;
        errmsg,
        temp     : LongInt;

        function constaccessok(vs: TAbstractVarSym): boolean;
          begin
            result:=false;
            { allow p^:= constructions with p is const parameter }
            if (Valid_Const in opts) or
              ((hp.nodetype=loadn) and
               (loadnf_isinternal_ignoreconst in TLoadNode(hp).loadnodeflags)) then
              result:=true
            { final (class) fields can only be initialised in the (class) constructors of
              class in which they have been declared (not in descendent constructors) }
            else if vs.varspez=vs_final then
              begin
                if (CurrentProcInfo.procdef.owner=vs.owner) then
                  if vs.typ=staticvarsym then
                    result:=CurrentProcInfo.procdef.proctypeoption=potype_class_constructor
                  else
                    result:=CurrentProcInfo.procdef.proctypeoption=potype_constructor;
                if not result and
                   report_errors then
                  CGMessagePos(hp.fileinfo,type_e_invalid_final_assignment);
              end
            else
              if report_errors then
                CGMessagePos(hp.fileinfo,type_e_no_assign_to_const);
          end;


        procedure mayberesettypeconvs;
          var
            i: LongInt;
          begin
            if Assigned(typeconvs) then
              begin
                if not report_errors and
                   not result then
                  for i:=0 to typeconvs.Count-1 do
                    TTypeConvNode(typeconvs[i]).assignment_side:=false;
                typeconvs.free;
                typeconvs := nil;
              end;
          end;


      begin
        if valid_const in opts then
          errmsg:=type_e_variable_id_expected
        else if valid_property in opts then
          errmsg:=type_e_argument_cant_be_assigned
        else
          errmsg:=type_e_no_addr_of_constant;
        result:=false;
        gotsubscript:=false;
        gotvec:=false;
        gotrecord:=false;
        gotstring:=false;
        gottypeconv:=false;
        hp:=p;
        if not(valid_void in opts) and
           is_void(hp.resultdef) then
         begin
           if report_errors then
             CGMessagePos(hp.fileinfo,errmsg);
           exit;
         end;
        typeconvs:=nil;
        while Assigned(hp) do
         begin
           { property allowed? calln has a property check itself }
           if (nf_isproperty in hp.flags) then
             begin
               { check return type }
               case hp.resultdef.typ of
                 recorddef :
                   gotrecord:=true;
                 stringdef :
                   gotstring:=true;
                 else
                   ;
               end;
               if (valid_property in opts) then
                 begin
                   { don't allow writing to calls that will create
                     temps like calls that return a structure and we
                     are assigning to a member }
                   if (valid_const in opts) or
                      (
                       { allowing assignments to typecasted properties
                           a) is Delphi-incompatible
                           b) causes problems in case the getter is a function
                              (because then the result of the getter is
                               typecasted to this type, and then we "assign" to
                               this typecasted function result) -> always
                               disallow, since property accessors should be
                               transparently changeable to functions at all
                               times
                       }
                       not(gottypeconv) and
                       not(gotsubscript and gotrecord) and
                       not(gotstring and gotvec) and
                       not(nf_no_lvalue in hp.flags)
                      ) then
                     result:=true
                   else
                     if report_errors then
                       CGMessagePos(hp.fileinfo,errmsg);
                 end
               else
                 begin
                   { 1. if it returns a pointer and we've found a deref,
                     2. if it returns a class and a subscription or with is found
                     3. if the address is needed of a field (subscriptn, vecn) }
                   if (gotstring and gotvec) or
                      (
                       (Valid_Addr in opts) and
                       (hp.nodetype in [subscriptn,vecn])
                      ) then
                     result:=true
                   else
                     if report_errors then
                       CGMessagePos(hp.fileinfo,errmsg);
                 end;
               mayberesettypeconvs;
               exit;
             end;
           case hp.nodetype of
             temprefn :
               begin
                 valid_for_assign := not(ti_readonly in TTempRefNode(hp).tempflags);
                 mayberesettypeconvs;
                 exit;
               end;
             derefn :
               begin
                 { dereference -> always valid }
                 valid_for_assign:=true;
                 mayberesettypeconvs;
                 exit;
               end;
             typeconvn :
               begin
                 gottypeconv:=true;
                 { typecast sizes must match, exceptions:
                   - implicit typecast made by absolute
                   - from formaldef
                   - from void
                   - from/to open array
                   - typecast from pointer to array }
                 fromdef:=TTypeConvNode(hp).left.resultdef;
                 todef:=hp.resultdef;
                 { typeconversions on the assignment side must keep
                   left.location the same }
                 TTypeConvNode(hp).assignment_side:=true;
                 if not Assigned(typeconvs) then
                   typeconvs:=TFPObjectList.create(false);
                 typeconvs.add(hp);
                 if not((nf_absolute in TTypeConvNode(hp).flags) or
                        TTypeConvNode(hp).target_specific_general_typeconv or
                        ((nf_explicit in hp.flags) and
                         TTypeConvNode(hp).target_specific_explicit_typeconv) or
                        (fromdef.typ=formaldef) or
                        is_void(fromdef) or
                        is_open_array(fromdef) or
                        is_open_array(todef) or
                        ((fromdef.typ=pointerdef) and (todef.typ=arraydef)) or
                        (def_is_related(fromdef,todef))) then
                  begin
                    if (fromdef.size<>todef.size) then
                      begin
                        { A cast to a smaller type cannot use a register variable. }
                        if todef.size<fromdef.size then
                          make_not_regable(hp,[ra_addr_regable])
                        else
                          if report_errors then
                            CGMessagePos2(hp.fileinfo,type_e_typecast_wrong_size_for_assignment,ToStr(fromdef.size),ToStr(todef.size));
                      end

                  end;

                 { don't allow assignments to typeconvs that need special code }
                 if not(gotsubscript or gotvec) and
                    not(TTypeConvNode(hp).assign_allowed) then
                   begin
                     if report_errors then
                       CGMessagePos(hp.fileinfo,errmsg);
                     mayberesettypeconvs;
                     exit;
                   end;
                 case hp.resultdef.typ of
                   arraydef :
                     begin
                       { pointer -> array conversion is done then we need to see it
                         as a deref, because a ^ is then not required anymore }
                       if TTypeConvNode(hp).convtype=tc_pointer_2_array then
                         begin
                           valid_for_assign:=true;
                           mayberesettypeconvs;
                           exit
                         end;
                     end;
                   else
                     ;
                 end;
                 hp:=TTypeConvNode(hp).left;
               end;
             vecn :
               begin
                 if (TVecNode(hp).right.nodetype=rangen) and
                    not(valid_range in opts) then
                  begin
                    if report_errors then
                      CGMessagePos(TVecNode(hp).right.fileinfo,parser_e_illegal_expression);
                    mayberesettypeconvs;
                    exit;
                  end;
                 if { only check for first (= outermost) vec node }
                    not gotvec and
                    not(valid_packed in opts) and
                    (TVecNode(hp).left.resultdef.typ = arraydef) and
                    (ado_IsBitPacked in TArrayDef(TVecNode(hp).left.resultdef).arrayoptions) and
                    ((TArrayDef(TVecNode(hp).left.resultdef).elepackedbitsize mod 8 <> 0) or
                     (is_ordinal(TArrayDef(TVecNode(hp).left.resultdef).elementdef) and
                      not IsPowerOf2(TArrayDef(TVecNode(hp).left.resultdef).elepackedbitsize div 8,temp))) then
                   begin
                     if report_errors then
                       if (valid_property in opts) then
                         CGMessagePos(hp.fileinfo,parser_e_packed_element_no_loop)
                       else
                         CGMessagePos(hp.fileinfo,parser_e_packed_element_no_var_addr);
                     mayberesettypeconvs;
                     exit;
                   end;
                 gotvec:=true;
                 { accesses to dyn. arrays override read only access in delphi
                   -- now also in FPC, because the elements of a dynamic array
                      returned by a function can also be changed, or you can
                      assign the dynamic array to a variable and then change
                      its elements anyway }
                 if is_dynamic_array(TUnaryNode(hp).left.resultdef) then
                   begin
                     result:=true;
                     mayberesettypeconvs;
                     exit;
                   end;
                 hp:=TUnaryNode(hp).left;
               end;
             asn :
               begin
                 { asn can't be assigned directly, it returns the value in a register instead
                   of reference. }
                 if not(gotsubscript or gotvec) then
                   begin
                     if report_errors then
                       CGMessagePos(hp.fileinfo,errmsg);
                     mayberesettypeconvs;
                     exit;
                   end;
                 hp:=TUnaryNode(hp).left;
               end;
             subscriptn :
               begin
                 { only check first (= outermost) subscriptn }
                 if not gotsubscript and
                    not(valid_packed in opts) and
                    is_packed_record_or_object(TSubscriptNode(hp).left.resultdef) and
                    ((TSubscriptNode(hp).vs.fieldoffset mod 8 <> 0) or
                     (is_ordinal(TSubscriptNode(hp).resultdef) and
                      not IsPowerOf2(TSubscriptNode(hp).resultdef.packedbitsize div 8,temp)))  then
                   begin
                     if report_errors then
                       if (valid_property in opts) then
                         CGMessagePos(hp.fileinfo,parser_e_packed_element_no_loop)
                       else
                         CGMessagePos(hp.fileinfo,parser_e_packed_element_no_var_addr);
                     mayberesettypeconvs;
                     exit;
                   end;
                 { check for final fields }
                 if (TSubscriptNode(hp).vs.varspez=vs_final) and
                    not constaccessok(TSubscriptNode(hp).vs) then
                   begin
                     mayberesettypeconvs;
                     exit;
                   end;
                 { if we assign something to a field of a record that is not
                   regable, then then the record can't be kept in a regvar,
                   because we will force the record into memory for this
                   subscript operation (to a temp location, so the assignment
                   will happen to the temp and be lost) }
                 if not gotsubscript and
                    not gotvec and
                    not TStoredDef(hp.resultdef).is_intregable then
                   make_not_regable(hp,[ra_addr_regable]);

                 gotsubscript:=true;
                 { loop counter? }
                 if not(Valid_Const in opts) and
                    (vo_is_loop_counter in TSubscriptNode(hp).vs.varoptions) then
                   begin
                     if report_errors then
                       CGMessage1(parser_e_illegal_assignment_to_count_var,TSubscriptNode(hp).vs.realname);
                     mayberesettypeconvs;
                     exit;
                   end;
                 { implicit pointer object types result in dereferencing }
                 hp:=TSubscriptNode(hp).left;
                 if is_implicit_pointer_object_type(hp.resultdef) or
                    (hp.resultdef.typ=classrefdef) then
                   begin
                     valid_for_assign:=true;
                     mayberesettypeconvs;
                     exit
                   end;
               end;
             muln,
             divn,
             andn,
             xorn,
             orn,
             notn,
             subn,
             addn :
               begin
                 { Temp strings are stored in memory, for compatibility with
                   delphi only }
                 if (m_delphi in CurrentSettings.ModeSwitches) and
                    ((valid_addr in opts) or
                     (valid_const in opts)) and
                    (hp.resultdef.typ=stringdef) then
                   result:=true
                 else
                  if report_errors then
                   CGMessagePos(hp.fileinfo,type_e_variable_id_expected);
                 mayberesettypeconvs;
                 exit;
               end;
             niln,
             pointerconstn :
               begin
                 { this is an implicit dereference, so it is valid for assign }
                 if hp.resultdef.typ=arraydef then
                   begin
                     valid_for_assign:=true;
                     mayberesettypeconvs;
                     exit;
                   end;

                 if report_errors then
                   CGMessagePos(hp.fileinfo,type_e_no_assign_to_addr);
                 mayberesettypeconvs;
                 exit;
               end;
             ordconstn,
             realconstn :
               begin
                 { these constants will be passed by value }
                 if report_errors then
                   CGMessagePos(hp.fileinfo,type_e_variable_id_expected);
                 mayberesettypeconvs;
                 exit;
               end;
             arrayconstructorn,
             setconstn,
             stringconstn,
             guidconstn :
               begin
                 { these constants will be passed by reference }
                 if valid_const in opts then
                   result:=true
                 else
                   if report_errors then
                     CGMessagePos(hp.fileinfo,type_e_variable_id_expected);
                 mayberesettypeconvs;
                 exit;
               end;
             addrn :
               begin
                 if report_errors then
                   CGMessagePos(hp.fileinfo,type_e_no_assign_to_addr);
                 mayberesettypeconvs;
                 exit;
               end;
             blockn,
             calln :
               begin
                 if ((hp.nodetype=calln) and not(is_void(hp.resultdef))) or
                    (nf_no_lvalue in hp.flags) then
                   begin
                     { Temp strings are stored in memory, for compatibility with
                       delphi only }
                     if (m_delphi in CurrentSettings.ModeSwitches) and
                        (valid_addr in opts) and
                        (hp.resultdef.typ=stringdef) then
                       result:=true
                     else
                       if ([valid_const,valid_addr] * opts = [valid_const]) then
                         result:=true
                     else
                      if report_errors then
                       CGMessagePos(hp.fileinfo,errmsg);
                     mayberesettypeconvs;
                     exit;
                   end
                 else if hp.nodetype=blockn then
                   begin
                     hp2:=TBlockNode(hp).statements;
                     if Assigned(hp2) then
                       begin
                         if hp2.nodetype<>statementn then
                           InternalError(2006110801);
                         while Assigned(TStatementNode(hp2).next) do
                           hp2:=TStatementNode(hp2).next;
                         hp:=TStatementNode(hp2).statement;
                       end
                     else
                       begin
                         if report_errors then
                          CGMessagePos(hp.fileinfo,type_e_variable_id_expected);
                         mayberesettypeconvs;
                         exit;
                       end;
                   end
                 else
                   begin
                     if report_errors then
                      CGMessagePos(hp.fileinfo,type_e_variable_id_expected);
                     mayberesettypeconvs;
                     exit;
                   end;
               end;
             inlinen :
               begin
                 { recurse so volatile(non-lvalue):=... gives a proper error instead of IE 200203272 }
                 if TInlineNode(hp).inlinenumber in [in_unaligned_x,in_aligned_x,in_volatile_x] then
                   begin
                     hp:=TCallParaNode(TInlineNode(hp).left).left;
                     continue;
                   end;
                 if ((valid_const in opts) and
                     (TInlineNode(hp).inlinenumber in [in_typeof_x])) then
                   result:=true
                 else
                   if report_errors then
                    CGMessagePos(hp.fileinfo,type_e_variable_id_expected);
                 mayberesettypeconvs;
                 exit;
               end;
             nothingn :
               begin
                 { generics can generate nothing nodes, just allow everything }
                 if df_generic in CurrentProcInfo.procdef.defoptions then
                   result:=true
                 else if report_errors then
                   CGMessagePos(hp.fileinfo,type_e_variable_id_expected);

                 mayberesettypeconvs;
                 exit;
               end;
             loadn :
               begin
                 case TLoadNode(hp).symtableentry.typ of
                   absolutevarsym,
                   staticvarsym,
                   localvarsym,
                   paravarsym :
                     begin
                       { loop counter? }
                       if not(Valid_Const in opts) and
                          (vo_is_loop_counter in TAbstractVarSym(TLoadNode(hp).symtableentry).varoptions) then
                         begin
                           if report_errors then
                             CGMessage1(parser_e_illegal_assignment_to_count_var,TLoadNode(hp).symtableentry.realname);
                           mayberesettypeconvs;
                           exit;
                         end;
                       { read-only variable? }
                       if (TAbstractVarSym(TLoadNode(hp).symtableentry).varspez in [vs_const,vs_constref,vs_final]) then
                        begin
                          result:=constaccessok(TAbstractVarSym(TLoadNode(hp).symtableentry));
                          mayberesettypeconvs;
                          exit;
                        end;
                       result:=true;
                       mayberesettypeconvs;
                       exit;
                     end;
                   procsym :
                     begin
                       if (Valid_Const in opts) then
                         result:=true
                       else
                         if report_errors then
                          CGMessagePos(hp.fileinfo,type_e_variable_id_expected);
                       mayberesettypeconvs;
                       exit;
                     end;
                   labelsym :
                     begin
                       if (Valid_Addr in opts) then
                         result:=true
                       else
                         if report_errors then
                          CGMessagePos(hp.fileinfo,type_e_variable_id_expected);
                       mayberesettypeconvs;
                       exit;
                     end;
                   constsym:
                     begin
                       if (TConstSym(TLoadNode(hp).symtableentry).consttyp in [constresourcestring,constwresourcestring]) and
                         (valid_addr in opts) then
                         result:=true
                       else
                         if report_errors then
                          CGMessagePos(hp.fileinfo,type_e_variable_id_expected);
                       mayberesettypeconvs;
                       exit;
                     end;
                   else
                     begin
                       if report_errors then
                        CGMessagePos(hp.fileinfo,type_e_variable_id_expected);
                       mayberesettypeconvs;
                       exit;
                     end;
                 end;
               end;
             else
               begin
                 if report_errors then
                  CGMessagePos(hp.fileinfo,type_e_variable_id_expected);
                 mayberesettypeconvs;
                 exit;
               end;
            end;
         end;
         mayberesettypeconvs;
      end;


    function  valid_for_var(p:TNode; report_errors: boolean):boolean;
      begin
        valid_for_var:=valid_for_assign(p,[valid_range],report_errors);
      end;


    function  valid_for_formal_var(p : TNode; report_errors: boolean) : boolean;
      begin
        valid_for_formal_var:=valid_for_assign(p,[valid_void,valid_range],report_errors);
      end;


    function  valid_for_formal_constref(p : TNode; report_errors: boolean) : boolean;
      begin
        valid_for_formal_constref:=(p.resultdef.typ=formaldef) or
          valid_for_assign(p,[valid_void,valid_range],report_errors);
      end;


    function  valid_for_formal_const(p : TNode; report_errors: boolean) : boolean;
      begin
        valid_for_formal_const:=(p.resultdef.typ=formaldef) or
          valid_for_assign(p,[valid_void,valid_const,valid_property,valid_range],report_errors);
      end;


    function  valid_for_assignment(p:TNode; report_errors: boolean):boolean;
      begin
        valid_for_assignment:=valid_for_assign(p,[valid_property,valid_packed],report_errors);
      end;


    function  valid_for_loopvar(p:TNode; report_errors: boolean):boolean;
      begin
        valid_for_loopvar:=valid_for_assign(p,[valid_property],report_errors);
      end;


    function  valid_for_addr(p : TNode; report_errors: boolean) : boolean;
      begin
        result:=valid_for_assign(p,[valid_const,valid_addr,valid_void],report_errors);
      end;


    procedure var_para_allowed(var eq:TEqualType;def_from,def_to:TDef; fromnode: TNode);
      begin
        { Note: eq must be already valid, it will only be updated! }
        case def_to.typ of
          formaldef :
            begin
              { all types can be passed to a formaldef,
                but it is not the prefered way }
              if not is_constnode(fromnode) then
                eq:=te_convert_l6
              else
                eq:=te_incompatible;
            end;
          arraydef :
            begin
              if is_open_array(def_to) then
                begin
                  if is_dynamic_array(def_from) and
                     equal_defs(TArrayDef(def_from).elementdef,TArrayDef(def_to).elementdef) then
                    eq:=te_convert_l2
                  else
                    if equal_defs(def_from,TArrayDef(def_to).elementdef) then
                      eq:=te_convert_l3;
                end;
            end;
          pointerdef :
            begin
              { an implicit pointer conversion is allowed }
              if (def_from.typ=pointerdef) then
                eq:=te_convert_l1;
            end;
          stringdef :
            begin
              { all shortstrings are allowed, size is not important }
              if is_shortstring(def_from) and
                 is_shortstring(def_to) then
                eq:=te_equal;
            end;
          objectdef :
            begin
              { child objects can be also passed }
              { in non-delphi mode, otherwise    }
              { they must match exactly, except  }
              { if they are objects              }
              if (def_from.typ=objectdef) and
                 (
                  (TObjectDef(def_from).objecttype=odt_object) and
                  (TObjectDef(def_to).objecttype=odt_object)
                 ) and
                 (def_is_related(TObjectDef(def_from),TObjectDef(def_to))) then
                eq:=te_convert_l1;
            end;
          filedef :
            begin
              { an implicit file conversion is also allowed }
              { from a typed file to an untyped one           }
              if (def_from.typ=filedef) and
                 (TFileDef(def_from).filetyp = ft_typed) and
                 (TFileDef(def_to).filetyp = ft_untyped) then
                eq:=te_convert_l1;
            end;
          else
            ;
        end;
      end;


    procedure para_allowed(var eq:TEqualType;p:TCallParaNode;def_to:TDef);
      var
        acn: TArrayConstructorNode;
        realprocdef: TProcDef;
        tmpeq: TEqualType;
      begin
        { Note: eq must be already valid, it will only be updated! }
        case def_to.typ of
          stringdef :
            begin
              { to support ansi/long/wide strings in a proper way }
              { string and string[10] are assumed as equal }
              { when searching the correct overloaded procedure   }
              if (p.resultdef.typ=stringdef) and
                 (TStringDef(def_to).stringtype=TStringDef(p.resultdef).stringtype) and
                 (TStringDef(def_to).encoding=TStringDef(p.resultdef).encoding) then
                eq:=te_equal
            end;
          formaldef,
          setdef :
            begin
              { set can also be a not yet converted array constructor }
              if (p.resultdef.typ=arraydef) and
                 is_array_constructor(p.resultdef) and
                 not is_variant_array(p.resultdef) then
                eq:=te_equal;
            end;
          procvardef :
            begin
              tmpeq:=te_incompatible;
              { in tp/macpas mode proc -> procvar is allowed }
              if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                  (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                 (p.left.nodetype=calln) then
                tmpeq:=proc_to_procvar_equal(TProcDef(TCallNode(p.left).procdefinition),TProcVarDef(def_to),false);
              if (tmpeq=te_incompatible) and
                 (m_nested_procvars in CurrentSettings.ModeSwitches) and
                 is_proc2procvar_load(p.left,realprocdef) then
                tmpeq:=proc_to_procvar_equal(realprocdef,TProcVarDef(def_to),false);
              if (tmpeq=te_incompatible) and
                 (m_mac in CurrentSettings.ModeSwitches) and
                 is_ambiguous_funcret_load(p.left,realprocdef) then
                tmpeq:=proc_to_procvar_equal(realprocdef,TProcVarDef(def_to),false);
              if tmpeq<>te_incompatible then
                eq:=tmpeq;
            end;
          objectdef :
            begin
              tmpeq:=te_incompatible;
              { in tp/macpas mode proc -> funcref is allowed }
              if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                  (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                 (p.left.nodetype=calln) and
                 is_invokable(def_to) then
                tmpeq:=proc_to_funcref_conv(TProcDef(TCallNode(p.left).procdefinition),TObjectDef(def_to));
              if tmpeq<>te_incompatible then
                eq:=tmpeq;
            end;
          arraydef :
            begin
              { an arrayconstructor of proccalls may have to be converted to
                an array of procvars }
              if ((m_tp_procvar in CurrentSettings.ModeSwitches) or
                  (m_mac_procvar in CurrentSettings.ModeSwitches)) and
                 (TArrayDef(def_to).elementdef.typ=procvardef) and
                 is_array_constructor(p.resultdef) and
                 not is_variant_array(p.resultdef) then
                begin
                  acn:=TArrayConstructorNode(p.left);
                  if Assigned(acn.left) then
                    begin
                      eq:=te_exact;
                      while Assigned(acn) and
                            (eq<>te_incompatible) do
                        begin
                          if (acn.left.nodetype=calln) then
                            tmpeq:=proc_to_procvar_equal(TProcDef(TCallNode(acn.left).procdefinition),TProcVarDef(TArrayDef(def_to).elementdef),false)
                          else
                            tmpeq:=compare_defs(acn.left.resultdef,TArrayDef(def_to).elementdef,acn.left.nodetype);
                          if tmpeq<eq then
                            eq:=tmpeq;
                          acn:=TArrayConstructorNode(acn.right);
                        end;
                    end
                end;
            end;
          else
            ;
        end;
      end;


    function allowenumop(nt:TNodeType):boolean;
      begin
        result:=(nt in [equaln,unequaln,ltn,lten,gtn,gten]) or
                ((cs_allow_enum_calc in CurrentSettings.LocalSwitches) and
                 (nt in [addn,subn]));
      end;


    procedure TCandidate.increment_ordinal_distance(by: uint64);
      begin
      {$push} {$q-,r-} inc(ordinal_distance_lo,by); {$pop}
        if ordinal_distance_lo<by then
          inc(ordinal_distance_hi); { Carry. }
      end;


{****************************************************************************
                           TCallCandidates
****************************************************************************}

    constructor TCallCandidates.init(sym:TProcSym;st:TSymTable;ppn:TNode;flags:TCallCandidatesFlags;spezcontext:TSpecializationContext);
      begin
        if not Assigned(sym) then
          InternalError(200411015);
        FOperator:=NOTOKEN;
        FProcsym:=sym;
        FProcsymtable:=st;
        FParanode:=ppn;
        create_candidate_list(flags,spezcontext);
      end;


    constructor TCallCandidates.init_operator(op:TToken;ppn:TNode);
      begin
        FOperator:=op;
        FProcsym:=nil;
        FProcsymtable:=nil;
        FParanode:=ppn;
        create_candidate_list([],nil);
      end;


    destructor TCallCandidates.done;
      var
        hpnext,
        hp : PCandidate;
        psym : TProcSym;
        i : LongInt;
        sym : TSym;
      begin
        FIgnoredCandidateProcs.free;
        FIgnoredCandidateProcs := nil;
        { free any symbols for anonymous parameter types that we're used for
          specialization when no specialization was picked }
        TFPList.FreeAndNilObjects(FParaAnonSyms);
        hp:=FCandidateProcs;
        while Assigned(hp) do
         begin
           hpnext:=hp^.next;
           { free those procdef specializations that are not owned (thus were discarded) }
           if hp^.data.is_specialization and not hp^.data.IsRegistered then
             begin
               { also remove the procdef from its symbol's procdeflist }
               psym:=TProcSym(hp^.data.procsym);
               for i:=0 to psym.procdeflist.count-1 do
                 begin
                   if psym.procdeflist[i]=hp^.data then
                     begin
                       psym.procdeflist.delete(i);
                       break;
                     end;
                 end;
               FreeAndNil(hp^.data);
             end;
           dispose(hp);
           hp:=hpnext;
         end;
      end;


    procedure TCallCandidates.collect_overloads_in_struct(structdef:TAbstractRecordDef;ProcdefOverloadList:TFPObjectList;flags:TCallCandidatesFlags;spezcontext:TSpecializationContext);

      var
        changedhierarchy : boolean;

      function processprocsym(srsym:TProcSym; out foundanything: boolean):boolean;
        var
          j  : integer;
          pd : TProcDef;
        begin
          { add all definitions }
          result:=false;
          foundanything:=false;
          { try to specialize the procsym }
          if srsym.could_be_implicitly_specialized and
            try_implicit_specialization(srsym,FParaNode,ProcdefOverloadList,FParaAnonSyms,TSym(FProcsym),result) then
            foundanything:=true;
          for j:=0 to srsym.ProcdefList.Count-1 do
            begin
              pd:=TProcDef(srsym.ProcdefList[j]);
              if not finalize_specialization(pd,spezcontext) then
                continue;
              if (po_ignore_for_overload_resolution in pd.procoptions) then
                begin
                  TFPList.AddOnDemand(FIgnoredCandidateProcs,pd);
                  continue;
                end;
              { in case of anonymous inherited, only match procdefs identical
                to the current one (apart from hidden parameters), rather than
                anything compatible to the parameters -- except in case of
                the presence of a messagestr/int, in which case those have to
                match exactly }
              if cc_anoninherited in flags then
                if po_msgint in CurrentProcInfo.procdef.procoptions then
                  begin
                    if not(po_msgint in pd.procoptions) or
                       (pd.messageinf.i<>CurrentProcInfo.procdef.messageinf.i) then
                      continue
                  end
                else if po_msgstr in CurrentProcInfo.procdef.procoptions then
                  begin
                    if not(po_msgstr in pd.procoptions) or
                       (pd.messageinf.str^<>CurrentProcInfo.procdef.messageinf.str^) then
                      continue
                  end
                else if (compare_paras(CurrentProcInfo.procdef.paras,pd.paras,cp_all,[cpo_ignorehidden])<te_equal) then
                  continue;
              foundanything:=true;
              { Store first procsym found }
              if not Assigned(FProcsym) then
                FProcsym:=TProcSym(srsym);
              if po_overload in pd.procoptions then
                result:=true;
              { if the hierarchy had been changed we need to check for duplicates }
              if not changedhierarchy or (ProcdefOverloadList.IndexOf(pd)<0) then
                ProcdefOverloadList.Add(pd);
            end;
        end;

      function processhelper(hashedid:THashedIDString;helperdef:TObjectDef):boolean;
        var
          srsym : TSym;
          hasoverload,foundanything : boolean;
        begin
          result:=false;
          srsym:=nil;
          hasoverload:=false;
          while Assigned(helperdef) do
            begin
              srsym:=TSym(helperdef.SymTable.FindWithHash(hashedid));
              if Assigned(srsym) and
                  { Delphi allows hiding a property by a procedure with the same name }
                  (srsym.typ=procsym) and
                  (TProcSym(srsym).procdeflist.count>0) then
                begin
                  hasoverload:=processprocsym(TProcSym(srsym),foundanything);
                  { when there is no explicit overload we stop searching }
                  if foundanything and
                     not hasoverload then
                    break;
                end;
              helperdef:=helperdef.childof;
            end;
          if not hasoverload and Assigned(srsym) then
            exit(true);
        end;

      var
        srsym      : TSym;
        hashedid   : THashedIDString;
        hasoverload,
        foundanything : boolean;
        extendeddef : TAbstractRecordDef;
        helperdef  : TObjectDef;
        helperlist : TFPObjectList;
        i : integer;
      begin
        if FOperator=NOTOKEN then
          hashedid.id:=FProcsym.name
        else
          hashedid.id:=overloaded_names[FOperator];
        hasoverload:=false;
        extendeddef:=nil;
        changedhierarchy:=false;
        while Assigned(structdef) do
         begin
           { first search in helpers for this type }
           if ((structdef.typ=recorddef) or
                 (
                   (structdef.typ=objectdef) and
                   (TObjectDef(structdef).objecttype in objecttypes_with_helpers)
                 )
               )
               and (cc_searchhelpers in flags) then
             begin
               if m_multi_helpers in CurrentSettings.ModeSwitches then
                 begin
                   helperlist:=get_objectpascal_helpers(structdef);
                   if Assigned(helperlist) and (helperlist.count>0) then
                     begin
                       i:=helperlist.count-1;
                       repeat
                         helperdef:=TObjectDef(helperlist[i]);
                         if (helperdef.owner.symtabletype in [staticsymtable,GlobalSymTable]) or
                            is_visible_for_object(helperdef.typesym,helperdef) then
                              if processhelper(hashedid,helperdef) then
                                exit;
                         dec(i);
                       until (i<0);
                     end;
                 end
               else if search_last_objectpascal_helper(structdef,nil,helperdef) and processhelper(hashedid,helperdef) then
                  exit;
             end;
           { now search in the type itself }
           srsym:=TSym(structdef.SymTable.FindWithHash(hashedid));
           if Assigned(srsym) and
              { Delphi allows hiding a property by a procedure with the same name }
              (srsym.typ=procsym) then
             begin
               hasoverload:=processprocsym(TProcSym(srsym),foundanything);
               { when there is no explicit overload we stop searching }
               if foundanything and
                  not hasoverload then
                 break;
             end;
           if is_objectpascal_helper(structdef) and
              (
                (TObjectDef(structdef).extendeddef.typ=recorddef) or
                (
                  (TObjectDef(structdef).extendeddef.typ=objectdef) and
                  (TObjectDef(TObjectDef(structdef).extendeddef).objecttype in objecttypes_with_helpers)
                )
              ) then
             begin
               { remember the first extendeddef of the hierarchy }
               if not Assigned(extendeddef) then
                 extendeddef:=TAbstractRecordDef(TObjectDef(structdef).extendeddef);
               { search methods in the extended type as well }
               srsym:=TProcSym(TAbstractRecordDef(TObjectDef(structdef).extendeddef).SymTable.FindWithHash(hashedid));
               if Assigned(srsym) and
                  { Delphi allows hiding a property by a procedure with the same name }
                  (srsym.typ=procsym) and
                  (TProcSym(srsym).procdeflist.count>0) then
                 begin
                   hasoverload:=processprocsym(TProcSym(srsym),foundanything);
                   { when there is no explicit overload we stop searching }
                   if foundanything and
                      not hasoverload then
                     break;
                 end;
             end;
           { next parent }
           if (structdef.typ=objectdef) then
             structdef:=TObjectDef(structdef).childof
           else
             structdef:=nil;
           { switch over to the extended def's hierarchy }
           if not Assigned(structdef) and Assigned(extendeddef) then
             begin
               structdef:=extendeddef;
               extendeddef:=nil;
               changedhierarchy:=true;
             end;
         end;
      end;


    procedure TCallCandidates.collect_overloads_in_units(ProcdefOverloadList:TFPObjectList; flags:TCallCandidatesFlags;spezcontext:TSpecializationContext);
      var
        j          : integer;
        pd         : TProcDef;
        srsymtable : TSymTable;
        srsym      : TSym;
        checkstack : PSymTableStackItem;
        hashedid   : THashedIDString;
        foundanything,
        hasoverload : boolean;
      begin
        { we search all overloaded operator definitions in the symtablestack. The found
          entries are only added to the procs list and not the procsym, because
          the list can change in every situation }
        if FOperator=NOTOKEN then
          begin
            if not (cc_objcidcall in flags) then
              hashedid.id:=FProcsym.name
            else
              hashedid.id:=class_helper_prefix+FProcsym.name;
          end
        else
          hashedid.id:=overloaded_names[FOperator];

        checkstack:=SymTableStack.stack;
        if Assigned(FProcsymtable) then
          begin
            while Assigned(checkstack) and
                  (checkstack^.SymTable<>FProcsymtable) do
              checkstack:=checkstack^.next;
          end;
        while Assigned(checkstack) do
          begin
            srsymtable:=checkstack^.SymTable;
            { if the unit in which the routine has to be searched has been
              specified explicitly, stop searching after its symtable(s) have
              been checked (can be both the static and the global symtable
              in case it's the current unit itself) }
            if (cc_explicitunit in flags) and
               (FProcsymtable.symtabletype in [GlobalSymTable,staticsymtable]) and
               (srsymtable.ModuleID<>FProcsymtable.ModuleID) then
              break;
            if (srsymtable.symtabletype in [localsymtable,staticsymtable,GlobalSymTable]) and
                (
                  (FOperator=NOTOKEN) or
                  (sto_has_operator in srsymtable.tableoptions)
                )
               then
              begin
                srsym:=TSym(srsymtable.FindWithHash(hashedid));
                if Assigned(srsym) and
                   (srsym.typ=procsym) and
                   (
                     (TProcSym(srsym).procdeflist.count>0) or
                     (sp_generic_dummy in srsym.symoptions)
                   ) then
                  begin
                    { add all definitions }
                    hasoverload:=false;
                    foundanything:=false;
                    if TProcSym(srsym).could_be_implicitly_specialized then
                      foundanything:=try_implicit_specialization(srsym,FParaNode,ProcdefOverloadList,FParaAnonSyms,TSym(FProcsym),hasoverload);
                    for j:=0 to TProcSym(srsym).ProcdefList.Count-1 do
                      begin
                        pd:=TProcDef(TProcSym(srsym).ProcdefList[j]);
                        if not finalize_specialization(pd,spezcontext) then
                          continue;
                        if (po_ignore_for_overload_resolution in pd.procoptions) then
                          begin
                            TFPList.AddOnDemand(FIgnoredCandidateProcs,pd);
                            continue;
                          end;
                        { Store first procsym found }
                        if not Assigned(FProcsym) then
                          FProcsym:=TProcSym(srsym);
                        if po_overload in pd.procoptions then
                          hasoverload:=true;
                        ProcdefOverloadList.Add(pd);
                        foundanything:=true;
                      end;
                    { when there is no explicit overload we stop searching,
                      except for Objective-C methods called via id }
                    if foundanything and
                       not hasoverload and
                       not (cc_objcidcall in flags) then
                      break;
                  end;
              end;
            checkstack:=checkstack^.next
          end;
      end;


    procedure TCallCandidates.create_candidate_list(flags:TCallCandidatesFlags;spezcontext:TSpecializationContext);
      var
        j     : integer;
        pd    : TProcDef;
        hp    : PCandidate;
        pt    : TCallParaNode;
        found,
        added : boolean;
        st    : TSymTable;
        contextstructdef : TAbstractRecordDef;
        ProcdefOverloadList : TFPObjectList;
        cpoptions : TCompareParasOptions;
      begin
        FCandidateProcs:=nil;

        { Find all available overloads for this procsym }
        ProcdefOverloadList:=TFPObjectList.Create(false);
        if not (cc_objcidcall in flags) and
           (FOperator=NOTOKEN) and
           (FProcsym.owner.symtabletype in [objectsymtable,recordsymtable]) then
          collect_overloads_in_struct(TAbstractRecordDef(FProcsym.owner.defowner),ProcdefOverloadList,flags,spezcontext)
        else
        if (FOperator<>NOTOKEN) then
          begin
            { check operands and if they contain records then search in records,
              then search in unit }
            pt:=TCallParaNode(FParaNode);
            while Assigned(pt) do
              begin
                if (pt.resultdef.typ=recorddef) and
                    (sto_has_operator in TAbstractRecordDef(pt.resultdef).SymTable.tableoptions) then
                  collect_overloads_in_struct(TAbstractRecordDef(pt.resultdef),ProcdefOverloadList,flags,spezcontext);
                pt:=TCallParaNode(pt.right);
              end;
            collect_overloads_in_units(ProcdefOverloadList,flags,spezcontext);
          end
        else
          collect_overloads_in_units(ProcdefOverloadList,flags,spezcontext);

        { determine length of parameter list.
          for operators also enable the variant-operators if
          a variant parameter is passed }
        FParalength:=0;
        FAllowVariant:=(FOperator=NOTOKEN);
        pt:=TCallParaNode(FParaNode);
        while Assigned(pt) do
          begin
            if (pt.resultdef.typ=variantdef) then
              FAllowVariant:=true;
            inc(FParalength);
            pt:=TCallParaNode(pt.right);
          end;

        { when the class passed is defined in this unit we
          need to use the scope of that class. This is a trick
          that can be used to access protected members in other
          units. At least kylix supports it this way (PFV) }
        if Assigned(FProcSymtable) and
           (
            (FProcSymtable.symtabletype in [ObjectSymtable,recordsymtable]) or
            ((FProcSymtable.symtabletype=withsymtable) and
             (FProcSymtable.defowner.typ in [objectdef,recorddef]))
           ) and
           (FProcSymtable.defowner.owner.symtabletype in [GlobalSymTable,staticsymtable,objectsymtable,recordsymtable]) and
           FProcSymtable.defowner.owner.iscurrentunit then
          contextstructdef:=TAbstractRecordDef(FProcSymtable.defowner)
        else
          contextstructdef:=CurrentStructDef;

        { symtable is needed later to calculate the distance }
        if Assigned(FProcsym) then
          st:=FProcsym.Owner
        else
          st:=nil;
        { Process all found overloads }
        for j:=0 to ProcdefOverloadList.Count-1 do
          begin
            pd:=TProcDef(ProcdefOverloadList[j]);
            added:=false;

            { only when the # of parameter are supported by the procedure and
              it is visible }
{$ifdef DISABLE_FAST_OVERLOAD_PATCH}
            if (FParalength>=pd.minparacount) and
{$else}
            if (pd.seenmarker<>pointer(@self)) and (FParalength>=pd.minparacount) and
{$endif}
               (
                (
                 (cc_allowdefaultparas in flags) and
                 (
                  (FParalength<=pd.maxparacount) or
                  (po_varargs in pd.procoptions)
                 )
                ) or
                (
                 not (cc_allowdefaultparas in flags) and
                 (FParalength=pd.maxparacount)
                )
               ) and
               (
                (cc_ignorevisibility in flags) or
                (
                  pd.is_specialization and not Assigned(pd.owner) and
                  (
                    not (pd.genericdef.owner.symtabletype in [objectsymtable,recordsymtable]) or
                    is_visible_for_object(TProcDef(pd.genericdef),contextstructdef)
                  )
                ) or
                (
                  Assigned(pd.owner) and
                  (
                    not (pd.owner.symtabletype in [objectsymtable,recordsymtable]) or
                    is_visible_for_object(pd,contextstructdef)
                  )
                )
               ) then
              begin
                { don't add duplicates, only compare visible parameters for the user }
                cpoptions:=[cpo_ignorehidden];
                if (po_compilerproc in pd.procoptions) then
                  cpoptions:=cpoptions+[cpo_compilerproc];
                if (po_rtlproc in pd.procoptions) then
                  cpoptions:=cpoptions+[cpo_rtlproc];
                found:=false;
                hp:=FCandidateProcs;
{$ifdef DISABLE_FAST_OVERLOAD_PATCH}
                while Assigned(hp) do
                  begin
                    if (compare_paras(hp^.data.paras,pd.paras,cp_value_equal_const,cpoptions)>=te_equal) and
                       (not(po_objc in pd.procoptions) or
                        (pd.messageinf.str^=hp^.data.messageinf.str^)) then
                      begin
                        found:=true;
                        break;
                      end;
                    hp:=hp^.next;
                  end;
{$endif}
                if not found then
                  begin
                    proc_add(st,pd);
                    added:=true;
{$ifndef DISABLE_FAST_OVERLOAD_PATCH}
                    pd.seenmarker:=pointer(@self);
{$endif}
                  end;
              end;

            { we need to remove all specializations that were not used from their
              procsyms as no code must be generated for them (if they are used
              later on they'll be added like the ones that were used now) }
            if not added and Assigned(spezcontext) and not pd.IsRegistered then
              begin
                if TProcSym(pd.procsym).procdeflist.extract(pd)<>pd then
                  InternalError(20150828);
                pd.free;
                pd := nil;
              end;
          end;
{$ifndef DISABLE_FAST_OVERLOAD_PATCH}
        {cleanup modified duplicate pd markers}
        hp := FCandidateProcs;
        while Assigned(hp) do begin
          hp^.data.seenmarker := nil;
          hp := hp^.next;
        end;
{$endif}

        calc_distance(st,flags);

        ProcdefOverloadList.Free;
        ProcdefOverloadList := nil;
      end;


    procedure TCallCandidates.calc_distance(st_root: TSymTable; flags:TCallCandidatesFlags);
      var
        pd:TProcDef;
        candidate:PCandidate;
        st: TSymTable;
      begin
        { Give a small penalty for overloaded methods not defined in the
          current class/unit }
        st:=nil;
        if (cc_objcidcall in flags) or
           not Assigned(st_root) or
           not Assigned(st_root.defowner) or
           (st_root.defowner.typ<>objectdef) then
          st:=st_root
        else
          repeat
            { In case of a method, st_root is the symtable of the first found
              procsym with the called method's name, but this procsym may not
              contain any of the overloads that match the used parameters (which
              are the procdefs that have been collected as candidates) -> walk
              up the class hierarchy and look for the first class that actually
              defines at least one of the candidate procdefs.

              The reason is that we will penalise methods in other classes/
              symtables, so if we pick a symtable that does not contain any of
              the candidates, this won't help with picking the best/
              most-inner-scoped one (since all of them will be penalised) }
            candidate:=FCandidateProcs;

            { the current class contains one of the candidates? }
            while Assigned(candidate) do
              begin
                pd:=candidate^.data;
                if pd.owner=st_root then
                  begin
                    { yes -> choose this class }
                    st:=st_root;
                    break;
                  end;
                candidate:=candidate^.next;
              end;

            { None found -> go to parent class }
            if not Assigned(st) then
              begin
                if not Assigned(st_root.defowner) then
                  InternalError(201605301);

                { no more parent class -> take current class as root anyway
                  (could maybe happen in case of a class helper?) }
                if not Assigned(TObjectDef(st_root.defowner).childof) then
                  begin
                    st:=st_root;
                    break;
                  end;

                st_root:=TObjectDef(st_root.defowner).childof.SymTable;
              end;
          until Assigned(st);

        candidate:=FCandidateProcs;
        {  when calling Objective-C methods via id.method, then the found
           procsym will be inside an arbitrary ObjectSymtable, and we don't
           want to give the methods of that particular objcclass precedence
           over other methods, so instead check against the symtable in
           which this objcclass is defined }
        if cc_objcidcall in flags then
          st:=st.defowner.owner;
        while Assigned(candidate) do
          begin
            pd:=candidate^.data;

            if st<>pd.owner then
              candidate^.increment_ordinal_distance(1);

            candidate:=candidate^.next;
          end;
      end;


    function TCallCandidates.proc_add(st:TSymTable;pd:TProcDef):PCandidate;
      var
        defaultparacnt : integer;
      begin
        { generate new candidate entry }
        new(result);
        fillchar(result^,sizeof(TCandidate),0);
        result^.data:=pd;
        result^.next:=FCandidateProcs;
        FCandidateProcs:=result;
        inc(FProccnt);
        { Find last parameter, skip all default parameters
          that are not passed. Ignore this skipping for varargs }
        result^.firstparaidx:=pd.paras.count-1;
        if not(po_varargs in pd.procoptions) then
         begin
           { ignore hidden parameters }
           while (result^.firstparaidx>=0) and (vo_is_hidden_para in TParaVarSym(pd.paras[result^.firstparaidx]).varoptions) do
             dec(result^.firstparaidx);
           defaultparacnt:=pd.maxparacount-FParalength;
           if defaultparacnt>0 then
             begin
               if defaultparacnt>result^.firstparaidx+1 then
                 InternalError(200401141);
               dec(result^.firstparaidx,defaultparacnt);
             end;
         end;
      end;


    procedure TCallCandidates.list(all:boolean);
      var
        hp : PCandidate;
      begin
        hp:=FCandidateProcs;
        while Assigned(hp) do
         begin
           if all or
              (not hp^.invalid) then
             MessagePos1(hp^.data.fileinfo,sym_h_param_list,hp^.data.fullprocname(false));
           hp:=hp^.next;
         end;
      end;


{$ifdef EXTDEBUG}
    procedure TCallCandidates.dump_info(lvl:LongInt);

        function ParaTreeStr(p:TCallParaNode):string;
        begin
          result:='';
          while Assigned(p) do
           begin
             if result<>'' then
              result:=','+result;
             result:=p.resultdef.typename+result;
             p:=TCallParaNode(p.right);
           end;
        end;

      var
        hp : PCandidate;
        i  : integer;
        currpara : TParaVarSym;
      begin
        if not CheckVerbosity(lvl) then
         exit;
        Comment(lvl+VLineInfo,'Overloaded callnode: '+FProcsym.name+'('+ParaTreeStr(TCallParaNode(FParaNode))+')');
        hp:=FCandidateProcs;
        while Assigned(hp) do
         begin
           Comment(lvl,'  '+hp^.data.fullprocname(false));
           if (hp^.invalid) then
            Comment(lvl,'   invalid')
           else
            begin
              Comment(lvl,'   ex: '+ToStr(hp^.te_count[te_exact])+
                          ' eq: '+ToStr(hp^.te_count[te_equal])+
                          ' l1: '+ToStr(hp^.te_count[te_convert_l1])+
                          ' l2: '+ToStr(hp^.te_count[te_convert_l2])+
                          ' l3: '+ToStr(hp^.te_count[te_convert_l3])+
                          ' l4: '+ToStr(hp^.te_count[te_convert_l4])+
                          ' l5: '+ToStr(hp^.te_count[te_convert_l5])+
                          ' l6: '+ToStr(hp^.te_count[te_convert_l6])+
                          ' oper: '+ToStr(hp^.te_count[te_convert_operator])+
                          ' ordhi: '+ToStr(hp^.ordinal_distance_hi)+
                          ' ordlo: '+ToStr(hp^.ordinal_distance_lo)+
                          ' ord2: '+ToStr(hp^.ordinal_distance_secondary));
              { Print parameters in left-right order }
              for i:=0 to hp^.data.paras.count-1 do
               begin
                 currpara:=TParaVarSym(hp^.data.paras[i]);
                 if not(vo_is_hidden_para in currpara.varoptions) then
                   Comment(lvl,'    - '+currpara.vardef.typename+' : '+EqualTypeName[currpara.eqval]);
               end;
            end;
           hp:=hp^.next;
         end;
      end;
{$endif EXTDEBUG}


    procedure TCallCandidates.get_information;
      var
        hp       : PCandidate;
        currpara : TParaVarSym;
        paraidx,fp_precision_distance : integer;
        currparanr : word;
        obj_from,
        obj_to   : TObjectDef;
        def_from,
        def_to   : TDef;
        currpt,
        pt       : TCallParaNode;
        eq,
        mineq    : TEqualType;
        convtype : TConvertType;
        pdtemp,
        pdoper   : TProcDef;
        releasecurrpt, check_valid_var : boolean;
        cdoptions : TCompareDefsOptions;
        n : TNode;

        function fp_precision_score(def: TDef): integer;
          begin
            if is_extended(def) then
              result:=4
            else if is_double(def) then
              result:=2
            else
              result:=1;
          end;

      begin
        cdoptions:=[cdo_check_operator];
        if FAllowVariant then
          include(cdoptions,cdo_allow_variant);
        { process all procs }
        hp:=FCandidateProcs;
        while Assigned(hp) do
         begin
           { We compare parameters in reverse order (right to left),
             the firstpara is already pointing to the last parameter
             were we need to start comparing }
           currparanr:=FParalength;
           paraidx:=hp^.firstparaidx;
           while (paraidx>=0) and (vo_is_hidden_para in TParaVarSym(hp^.data.paras[paraidx]).varoptions) do
             dec(paraidx);
           pt:=TCallParaNode(FParaNode);
           while Assigned(pt) and ((paraidx>=0) or (po_varargs in hp^.data.procoptions)) do
            begin
              if paraidx<0 then
                currpara:=nil
              else
                currpara:=TParaVarSym(hp^.data.paras[paraidx]);
              { currpt can be changed from loadn to calln when a procvar
                is passed. This is to prevent that the change is permanent }
              currpt:=pt;
              releasecurrpt:=false;
              { Should we check if the callparanode.left is valid for var }
              check_valid_var:=true;
              { retrieve current parameter definitions to compares }
              eq:=te_incompatible;
              def_from:=currpt.resultdef;
              if Assigned(currpara) then
                def_to:=currpara.vardef
              else
                def_to:=nil;
              if not(Assigned(def_from)) then
               InternalError(200212091);
              if not(
                     Assigned(def_to) or
                     ((po_varargs in hp^.data.procoptions) and
                      (currparanr>hp^.data.minparacount))
                    ) then
               InternalError(200212092);

              { Convert tp procvars when not expecting a procvar }
             if Assigned(def_to) and
                (currpt.left.resultdef.typ=procvardef) and
                not(def_to.typ in [procvardef,formaldef]) and
                { if it doesn't require any parameters }
                (TProcVarDef(currpt.left.resultdef).minparacount=0) and
                { Only convert to call when there is no overload or the return type
                  is compatible with the expected type. }
                (
                 (count=1) or
                 (compare_defs_ext(TProcVarDef(currpt.left.resultdef).returndef,def_to,nothingn,convtype,pdoper,[])>te_incompatible)
                ) then
               begin
                 releasecurrpt:=true;
                 currpt:=TCallParaNode(pt.getcopy);
                 if maybe_call_procvar(currpt.left,true) then
                   begin
                     currpt.resultdef:=currpt.left.resultdef;
                     def_from:=currpt.left.resultdef;
                   end;
               end;

             { If we expect a procvar and the left is loadnode that
               returns a procdef we need to find the correct overloaded
               procdef that matches the expected procvar. The loadnode
               temporary returned the first procdef (PFV) }
             if Assigned(def_to) and
                (
                   (def_to.typ=procvardef) or
                   is_funcref(def_to)
                ) and
                (currpt.left.nodetype=loadn) and
                (currpt.left.resultdef.typ=procdef) then
               begin
                 if def_to.typ=procvardef then
                   pdtemp:=TProcSym(TLoadNode(currpt.left).symtableentry).Find_procdef_byprocvardef(TProcVarDef(def_to))
                 else
                   pdtemp:=TProcSym(TLoadNode(currpt.left).symtableentry).find_procdef_byfuncrefdef(TObjectDef(def_to));
                 if Assigned(pdtemp) then
                   begin
                     TLoadNode(currpt.left).setprocdef(pdtemp,def_to.typ<>procvardef);
                     currpt.resultdef:=currpt.left.resultdef;
                     def_from:=currpt.left.resultdef;
                   end;
               end;

             { same as above, but for the case that we have a proc-2-procvar
               conversion together with a load }
             if Assigned(def_to) and
                (
                   (def_to.typ=procvardef) or
                   is_funcref(def_to)
                ) and
                (currpt.left.nodetype=typeconvn) and
                (TTypeConvNode(currpt.left).convtype=tc_proc_2_procvar) and
                (TTypeConvNode(currpt.left).totypedef=voidtype) and
                not (nf_explicit in currpt.left.flags) and
                (TTypeConvNode(currpt.left).left.nodetype=loadn) and
                (TTypeConvNode(currpt.left).left.resultdef.typ=procdef) then
               begin
                 if def_to.typ=procvardef then
                   pdtemp:=TProcSym(TLoadNode(TTypeConvNode(currpt.left).left).symtableentry).Find_procdef_byprocvardef(TProcVarDef(def_to))
                 else
                   pdtemp:=TProcSym(TLoadNode(TTypeConvNode(currpt.left).left).symtableentry).find_procdef_byfuncrefdef(TObjectDef(def_to));
                 if Assigned(pdtemp) then
                   begin
                     TLoadNode(TTypeConvNode(currpt.left).left).setprocdef(pdtemp,def_to.typ<>procvardef);
                     TTypeConvNode(currpt.left).totypedef:=CProcVarDef.getreusableprocaddr(pdtemp,pc_normal);
                     TTypeConvNode(currpt.left).resultdef:=TTypeConvNode(currpt.left).totypedef;
                     def_from:=TTypeConvNode(currpt.left).resultdef;
                   end;
               end;

              { varargs are always equal, but not exact }
              if (po_varargs in hp^.data.procoptions) and
                 (currparanr>hp^.data.minparacount) and
                 not is_array_of_const(def_from) and
                 not is_array_constructor(def_from) then
                eq:=te_equal
              else
              { same definition -> exact }
               if (def_from=def_to) then
                 eq:=te_exact
              else
              { for value and const parameters check if a integer is constant or
                included in other integer -> equal and calc ordinal_distance }
               if Assigned(currpara) and
                  not(currpara.varspez in [vs_var,vs_out]) and
                  is_integer(def_from) and
                  is_integer(def_to) and
                  is_in_limit(def_from,def_to) then
                 begin
                   eq:=te_equal;
                   { is_in_limit(def_from, def_to) means that def_from.low >= def_to.low and def_from.high <= def_to.high. }
                   hp^.increment_ordinal_distance(TOrdDef(def_from).low-TOrdDef(def_to).low);
                   hp^.increment_ordinal_distance(TOrdDef(def_to).high-TOrdDef(def_from).high);
                   { Give wrong sign a small penalty, this is need to get a difference
                     from word->[longword,longint] }
                   if (is_signed(def_from)<>is_signed(def_to)) then
                     inc(hp^.ordinal_distance_secondary);
                 end
              else
              { for value and const parameters check precision of real, give
                penalty for loosing of precision. var and out parameters must match exactly }
               if Assigned(currpara) and
                  not(currpara.varspez in [vs_var,vs_out]) and
                  is_real_or_cextended(def_from) and
                  is_real_or_cextended(def_to) then
                 begin
                   eq:=te_equal;
                   fp_precision_distance:=fp_precision_score(def_to)-fp_precision_score(def_from);
                   { penalty for shrinking of precision }
                   if fp_precision_distance<0 then
                     fp_precision_distance:=16*-fp_precision_distance;
                   hp^.increment_ordinal_distance(fp_precision_distance);
                 end
              else
              { related object parameters also need to determine the distance between the current
                object and the object we are comparing with. var and out parameters must match exactly }
               if Assigned(currpara) and
                  Assigned(def_to) and
                  not(currpara.varspez in [vs_var,vs_out]) and
                  (def_from.typ=objectdef) and
                  (def_to.typ=objectdef) and
                  (TObjectDef(def_from).objecttype=TObjectDef(def_to).objecttype) and
                  def_is_related(TObjectDef(def_from),TObjectDef(def_to)) then
                 begin
                   eq:=te_convert_l1;
                   check_valid_var:=false;
                   { resolve anonymous external class definitions }
                   obj_from:=find_real_class_definition(TObjectDef(def_from),false);
                   obj_to:=find_real_class_definition(TObjectDef(def_to),false);
                   while Assigned(obj_from) do
                     begin
                       if obj_from=obj_to then
                         break;
                       hp^.increment_ordinal_distance(1);
                       obj_from:=obj_from.childof;
                     end;
                 end
               { compare_defs_ext compares sets and array constructors very poorly because
                 it has too little information. So we do explicitly a detailed comparison,
                 see also bug #11288 (FK)
               }
               else if Assigned(def_to) and (def_to.typ=setdef) and is_array_constructor(currpt.left.resultdef) then
                 begin
                   n:=currpt.left.getcopy;
                   arrayconstructor_to_set(n);
                   eq:=compare_defs_ext(n.resultdef,def_to,n.nodetype,convtype,pdoper,cdoptions);
                   check_valid_var:=false;
                   n.free;
                   n := nil;
                 end
              else if is_open_array(def_to) and
                      is_class_or_interface_or_dispinterface_or_objc_or_java(TArrayDef(def_to).elementdef) and
                      is_array_constructor(currpt.left.resultdef) and
                      Assigned(TArrayConstructorNode(currpt.left).left) then
                begin
                  { ensure that [nil] can be converted to "array of tobject",
                    because if we just try to convert "array of pointer" to
                    "array of tobject", we get type conversion errors in
                    non-Delphi modes }
                  n:=currpt.left;
                  mineq:=te_exact;
                  repeat
                    if TArrayConstructorNode(n).left.nodetype=arrayconstructorrangen then
                      eq:=te_incompatible
                    else
                      eq:=compare_defs_ext(TArrayConstructorNode(n).left.resultdef,TArrayDef(def_to).elementdef,TArrayConstructorNode(n).left.nodetype,convtype,pdoper,cdoptions);
                    if eq<mineq then
                      mineq:=eq;
                    if eq=te_incompatible then
                      break;
                    n:=TArrayConstructorNode(n).right;
                  until not Assigned(n);
                  eq:=mineq;
                  check_valid_var:=false;
                end
              else
              { generic type comparison }
               begin
                 if (hp^.data.procoptions*[po_rtlproc,po_compilerproc]=[]) and
                    is_ansistring(def_from) and
                    is_ansistring(def_to) and
                    (TStringDef(def_from).encoding<>TStringDef(def_to).encoding) and
                    (currpara.varspez in [vs_var,vs_out]) then
                    begin
                      eq:=te_convert_l1; // don't allow to pass different ansistring types to each-other
                      check_valid_var:=false;
                    end
                 else
                   eq:=compare_defs_ext(def_from,def_to,currpt.left.nodetype,convtype,pdoper,cdoptions);

                 { when the types are not equal we need to check
                   some special case for parameter passing }
                 if (eq<te_equal) then
                  begin
                    if currpara.varspez in [vs_var,vs_out] then
                      begin
                        { para requires an equal type so the previous found
                          match was not good enough, reset to incompatible }
                        eq:=te_incompatible;
                        var_para_allowed(eq,currpt.resultdef,currpara.vardef,currpt.left);
                        check_valid_var:=false;
                      end
                    else
                      para_allowed(eq,currpt,def_to);
                  end;
               end;

              { univ parameters match if the size matches (don't override the
                comparison result if it was ok, since a match based on the
                "univ" character is the lowest possible match) }
                if (eq=te_incompatible) and
                   currpara.univpara and
                   is_valid_univ_para_type(def_from) and
                   (def_from.size=def_to.size) then
                  eq:=te_convert_l5;

               { when a procvar was changed to a call an exact match is
                downgraded to equal. This way an overload call with the
                procvar is choosen. See tb_procvar_calls_delphi, case tb0471 (PFV) }
              if (pt<>currpt) and (eq=te_exact) then
                eq:=te_equal;
              { if var or out parameter type but paranode not is_valid_for_var }
              if check_valid_var and Assigned(currpara) and (currpara.varspez in [vs_var,vs_out]) and not valid_for_var(currpt.left,false)
                 and Assigned(def_to) and (def_to.typ<>formaldef) and not is_open_array(def_to) then
                eq:=te_incompatible;

              { increase correct counter }
              if eq<>te_incompatible then
                inc(hp^.te_count[eq])
              else
                hp^.invalid:=true;

              { stop checking when an incompatible parameter is found }
              if hp^.invalid then
               begin
                 { store the current parameter info for
                   a nice error message when no procedure is found }
                 hp^.wrongparaidx:=paraidx;
                 hp^.wrongparanr:=currparanr;
                 break;
               end;

{$ifdef EXTDEBUG}
              { store equal in node tree for dump }
              if Assigned(currpara) then
                currpara.eqval:=eq;
{$endif EXTDEBUG}

              { maybe release temp currpt }
              if releasecurrpt then
               begin
                 currpt.free;
                 currpt := nil;
               end;

              { next parameter in the call tree }
              pt:=TCallParaNode(pt.right);

              { next parameter for definition, only goto next para
                if we're out of the varargs }
              if not(po_varargs in hp^.data.procoptions) or
                 (currparanr<=hp^.data.maxparacount) then
               begin
                 { Ignore vs_hidden parameters }
                 repeat
                   dec(paraidx);
                 until (paraidx<0) or not(vo_is_hidden_para in TParaVarSym(hp^.data.paras[paraidx]).varoptions);
               end;
              dec(currparanr);
            end;
           if not(hp^.invalid) and
              (Assigned(pt) or (paraidx>=0) or (currparanr<>0)) then
             InternalError(200212141);
           { next candidate }
           hp:=hp^.next;
         end;
      end;


    function get_variantequaltype(def: TDef): TVariantEqualType;
      const
        variantorddef_cl: array[TOrdType] of TVariantEqualType =
          (tve_incompatible,tve_byte,tve_word,tve_cardinal,tve_chari64,tve_incompatible,
           tve_shortint,tve_smallint,tve_longint,tve_chari64,tve_incompatible,
           tve_boolformal,tve_boolformal,tve_boolformal,tve_boolformal,tve_boolformal,
           tve_boolformal,tve_boolformal,tve_boolformal,tve_boolformal,
           tve_chari64,tve_chari64,tve_dblcurrency,tve_incompatible);
        variantfloatdef_cl: array[TFloatType] of TVariantEqualType =
          (tve_single,tve_dblcurrency,tve_extended,tve_extended,
           tve_dblcurrency,tve_dblcurrency);
        variantstringdef_cl: array[TStringType] of TVariantEqualType =
          (tve_sstring,tve_astring,tve_astring,tve_wstring,tve_ustring);
      begin
        case def.typ of
          orddef:
            begin
              result:=variantorddef_cl[TOrdDef(def).ordtype];
            end;
          floatdef:
            begin
              result:=variantfloatdef_cl[TFloatDef(def).floattype];
            end;
          stringdef:
            begin
              result:=variantstringdef_cl[TStringDef(def).stringtype];
            end;
          formaldef:
            begin
              result:=tve_boolformal;
            end;
          else
            begin
              result:=tve_incompatible;
            end;
        end
      end;




    function is_better_candidate(currpd,bestpd:PCandidate):integer;
      begin
        {
          Return values:
            > 0 when currpd is better than bestpd
            < 0 when bestpd is better than currpd
            = 0 when both are equal

          To choose the best candidate we use the following order:
          - Incompatible flag
          - (Smaller) Number of convert operator parameters.
          - (Smaller) Number of convertlevel 2 parameters.
          - (Smaller) Number of convertlevel 1 parameters.
          - (Bigger) Number of exact parameters.
          - (Smaller) Number of equal parameters.
          - (Smaller) Total of ordinal distance. For example, the distance of a word
            to a byte is 65535-255=65280.
        }
        if bestpd^.invalid or currpd^.invalid then
          exit(ord(bestpd^.invalid)-ord(currpd^.invalid)); { 1 if bestpd^.invalid, -1 if currpd^.invalid, 0 if both. }
        { less operator parameters? }
        is_better_candidate:=(bestpd^.te_count[te_convert_operator]-currpd^.te_count[te_convert_operator]);
        if is_better_candidate<>0 then
          exit;
        { less cl6 parameters? }
        is_better_candidate:=bestpd^.te_count[te_convert_l6]-currpd^.te_count[te_convert_l6];
        if is_better_candidate<>0 then
          exit;
        { less cl5 parameters? }
        is_better_candidate:=bestpd^.te_count[te_convert_l5]-currpd^.te_count[te_convert_l5];
        if is_better_candidate<>0 then
          exit;
        { less cl4 parameters? }
        is_better_candidate:=bestpd^.te_count[te_convert_l4]-currpd^.te_count[te_convert_l4];
        if is_better_candidate<>0 then
          exit;
        { less cl3 parameters? }
        is_better_candidate:=bestpd^.te_count[te_convert_l3]-currpd^.te_count[te_convert_l3];
        if is_better_candidate<>0 then
          exit;
        { less cl2 parameters? }
        is_better_candidate:=bestpd^.te_count[te_convert_l2]-currpd^.te_count[te_convert_l2];
        if is_better_candidate<>0 then
          exit;
        { less cl1 parameters? }
        is_better_candidate:=bestpd^.te_count[te_convert_l1]-currpd^.te_count[te_convert_l1];
        if is_better_candidate<>0 then
          exit;
        { more exact parameters? }
        is_better_candidate:=currpd^.te_count[te_exact]-bestpd^.te_count[te_exact];
        if is_better_candidate<>0 then
          exit;
        { less equal parameters? }
        is_better_candidate:=bestpd^.te_count[te_equal]-currpd^.te_count[te_equal];
        if is_better_candidate<>0 then
          exit;
        { if a specialization is better than a non-specialization then
          the non-generic always wins }
        if m_implicit_function_specialization in CurrentSettings.ModeSwitches then
          begin
            is_better_candidate:=ord(bestpd^.data.is_specialization)-ord(currpd^.data.is_specialization); { 1 if bestpd^.data.is_specialization and not currpd^.data.is_specialization, -1 if the reverse, 0 if same is_specialization. }
            if is_better_candidate<>0 then
              exit;
          end;
        { smaller ordinal distance? }
        is_better_candidate:=int32(bestpd^.ordinal_distance_hi)-int32(currpd^.ordinal_distance_hi); { >0 if currpd^.ordinal_distance_hi < bestpd^.ordinal_distance_hi. }
        if is_better_candidate<>0 then
          exit;
        if currpd^.ordinal_distance_lo<>bestpd^.ordinal_distance_lo then
          exit(2*ord(currpd^.ordinal_distance_lo<bestpd^.ordinal_distance_lo)-1); { 1 if currpd^.ordinal_distance_lo < bestpd^.ordinal_distance_lo, -1 if the reverse. }
        is_better_candidate:=int32(bestpd^.ordinal_distance_secondary)-int32(currpd^.ordinal_distance_secondary); { >0 if currpd^.ordinal_distance_secondary < bestpd^.ordinal_distance_secondary. }
      end;


{ Delphi precedence rules extracted from test programs. Only valid if passing
  a variant parameter to overloaded procedures expecting exactly one parameter.

  single > (char, currency, int64, shortstring, ansistring, widestring, unicodestring, extended, double)
  double/currency > (char, int64, shortstring, ansistring, widestring, unicodestring, extended)
  extended > (char, int64, shortstring, ansistring, widestring, unicodestring)
  longint/cardinal > (int64, shortstring, ansistring, widestring, unicodestring, extended, double, single, char, currency)
  smallint > (longint, int64, shortstring, ansistring, widestring, unicodestring, extended, double single, char, currency);
  word > (longint, cardinal, int64, shortstring, ansistring, widestring, unicodestring, extended, double single, char, currency);
  shortint > (longint, smallint, int64, shortstring, ansistring, widestring, unicodestring, extended, double, single, char, currency)
  byte > (longint, cardinal, word, smallint, int64, shortstring, ansistring, widestring, unicodestring, extended, double, single, char, currency);
  boolean/formal > (char, int64, shortstring, ansistring, widestring, unicodestring)
  widestring > (char, int64, shortstring, ansistring, unicodestring)
  unicodestring > (char, int64, shortstring, ansistring)
  ansistring > (char, int64, shortstring)
  shortstring > (char, int64)

  Relations not mentioned mean that they conflict: no decision possible }

    function is_better_candidate_single_variant(currpd,bestpd:PCandidate):integer;

      function calculate_relation(const currvcl, bestvcl, testvcl:
          TVariantEqualType; const conflictvcls: TVariantEqualTypes):integer;
        begin
          { if (bestvcl=conflictvcl) or
               (currvcl=conflictvcl) then
              result:=0
            else if (bestvcl=testvcl) then
              result:=-1
            else result:=1 }
          result:=1-2*ord(bestvcl=testvcl)+
                  ord(currvcl in conflictvcls)-ord(bestvcl in conflictvcls);
        end;


        function getfirstrealparaidx(pd: PCandidate): integer;
          begin
            { can be different for currpd and bestpd in case of overloaded }
            { functions, e.g. lowercase():char and lowercase():shortstring }
            { (depending on the calling convention and parameter order)    }
            result:=pd^.firstparaidx;
            while (result>=0) and (vo_is_hidden_para in TParaVarSym(pd^.data.paras[result]).varoptions) do
              dec(result);
            if (vo_is_hidden_para in TParaVarSym(pd^.data.paras[result]).varoptions) then
              InternalError(2006122803);
          end;

      var
        currpara, bestpara: TParaVarSym;
        currvcl, bestvcl: TVariantEqualType;
      begin
        {
          Return values:
            > 0 when currpd is better than bestpd
            < 0 when bestpd is better than currpd
            = 0 when both are equal
        }
        currpara:=TParaVarSym(currpd^.data.paras[getfirstrealparaidx(currpd)]);
        bestpara:=TParaVarSym(bestpd^.data.paras[getfirstrealparaidx(bestpd)]);

        { if one of the parameters is a regular variant, fall back to the }
        { default algorithm                                               }
        if (currpara.vardef.typ = variantdef) or
           (bestpara.vardef.typ = variantdef) then
          begin
            result:=is_better_candidate(currpd,bestpd);
            exit;
          end;

        currvcl:=get_variantequaltype(currpara.vardef);
        bestvcl:=get_variantequaltype(bestpara.vardef);

        { sanity check }
        result:=-5;

        { if both are the same, there is a conflict }
        if (currvcl=bestvcl) then
          result:=0
        { if one of the two cannot be used as variant, the other is better }
        else if (bestvcl=tve_incompatible) then
          result:=1
        else if (currvcl=tve_incompatible) then
          result:=-1
        { boolean and formal are better than chari64str, but conflict with }
        { everything else                                                  }
        else if (currvcl=tve_boolformal) or
                (bestvcl=tve_boolformal) then
          if (currvcl=tve_boolformal) then
            result:=ord(bestvcl in [tve_chari64,tve_sstring,tve_astring,tve_wstring,tve_ustring])
          else
            result:=-ord(currvcl in [tve_chari64,tve_sstring,tve_astring,tve_wstring,tve_ustring])
        { byte is better than everything else (we assume both aren't byte, }
        { since there's only one parameter and that one can't be the same) }
        else if (currvcl=tve_byte) or
                (bestvcl=tve_byte) then
          result:=calculate_relation(currvcl,bestvcl,tve_byte,[tve_shortint])
        { shortint conflicts with word and cardinal, but is better than    }
        { everything else but byte (which has already been handled)        }
        else if (currvcl=tve_shortint) or
                (bestvcl=tve_shortint) then
          result:=calculate_relation(currvcl,bestvcl,tve_shortint,[tve_word, tve_cardinal])
        { word conflicts with smallint, but is better than everything else }
        { but shortint and byte (which has already been handled)           }
        else if (currvcl=tve_word) or
                (bestvcl=tve_word) then
          result:=calculate_relation(currvcl,bestvcl,tve_word,[tve_smallint])
        { smallint conflicts with cardinal, but is better than everything  }
        { which has not yet been tested                                    }
        else if (currvcl=tve_smallint) or
                (bestvcl=tve_smallint) then
          result:=calculate_relation(currvcl,bestvcl,tve_smallint,[tve_cardinal])
        { cardinal conflicts with each longint and is better than everything }
        { which has not yet been tested                                      }
        else if (currvcl=tve_cardinal) or
                (bestvcl=tve_cardinal) then
          result:=calculate_relation(currvcl,bestvcl,tve_cardinal,[tve_longint])
        { longint is better than everything which has not yet been tested }
        else if (currvcl=tve_longint) or
                (bestvcl=tve_longint) then
          { if bestvcl=tve_longint then
              result:=-1
            else
              result:=1 }
          result:=1-2*ord(bestvcl=tve_longint)
        { single is better than everything left }
        else if (currvcl=tve_single) or
                (bestvcl=tve_single) then
          result:=1-2*ord(bestvcl=tve_single)
        { double/comp/currency are better than everything left, and conflict }
        { with each other (but that's already tested)                        }
        else if (currvcl=tve_dblcurrency) or
                (bestvcl=tve_dblcurrency) then
          result:=1-2*ord(bestvcl=tve_dblcurrency)
        { extended is better than everything left }
        else if (currvcl=tve_extended) or
                (bestvcl=tve_extended) then
          result:=1-2*ord(bestvcl=tve_extended)
        { widestring is better than everything left }
        else if (currvcl=tve_wstring) or
                (bestvcl=tve_wstring) then
          result:=1-2*ord(bestvcl=tve_wstring)
        { unicodestring is better than everything left }
        else if (currvcl=tve_ustring) or
                (bestvcl=tve_ustring) then
          result:=1-2*ord(bestvcl=tve_ustring)
        { ansistring is better than everything left }
        else if (currvcl=tve_astring) or
                (bestvcl=tve_astring) then
          result:=1-2*ord(bestvcl=tve_astring)
        { shortstring is better than everything left }
        else if (currvcl=tve_sstring) or
                (bestvcl=tve_sstring) then
          result:=1-2*ord(bestvcl=tve_sstring);

        { all possibilities should have been checked now }
        if (result=-5) then
          InternalError(2006122805);
      end;



{$ifdef DISABLE_FAST_OVERLOAD_PATCH}

    function TCallCandidates.choose_best(var bestpd:TAbstractProcDef; singlevariant: boolean):integer;
      var
        pd: TProcDef;
        besthpstart,
        hp            : PCandidate;
        cntpd,
        res           : integer;
      begin
        {
          Returns the number of candidates left and the
          first candidate is returned in pdbest
        }
        { Setup the first procdef as best, only count it as a result
          when it is valid }
        bestpd:=FCandidateProcs^.data;
        if FCandidateProcs^.invalid then
         cntpd:=0
        else
         cntpd:=1;
        if Assigned(FCandidateProcs^.next) then
         begin
           besthpstart:=FCandidateProcs;
           hp:=FCandidateProcs^.next;
           while Assigned(hp) do
            begin
              if not singlevariant then
                res:=is_better_candidate(hp,besthpstart)
              else
                res:=is_better_candidate_single_variant(hp,besthpstart);
              if (res>0) then
               begin
                 { hp is better, flag all procs to be incompatible }
                 while (besthpstart<>hp) do
                  begin
                    besthpstart^.invalid:=true;
                    besthpstart:=besthpstart^.next;
                  end;
                 { besthpstart is already set to hp }
                 bestpd:=besthpstart^.data;
                 cntpd:=1;
               end
              else
               if (res<0) then
                begin
                  { besthpstart is better, flag current hp to be incompatible }
                  hp^.invalid:=true;
                end
              else
               begin
                 { res=0, both are valid }
                 if not hp^.invalid then
                   inc(cntpd);
               end;
              hp:=hp^.next;
            end;
         end;

        { if we've found one, check the procdefs ignored for overload choosing
          to see whether they contain one from a child class with the same
          parameters (so the overload choosing was not influenced by their
          presence, but now that we've decided which overloaded version to call,
          make sure we call the version closest in terms of visibility }
        if (cntpd=1) and Assigned(FIgnoredCandidateProcs) then
          begin
            for res:=0 to FIgnoredCandidateProcs.count-1 do
              begin
                pd:=TProcDef(FIgnoredCandidateProcs[res]);
                { stop searching when we start comparing methods of parent of
                  the struct in which the current best method was found }
                if Assigned(pd.struct) and
                   (pd.struct<>TProcDef(bestpd).struct) and
                   def_is_related(TProcDef(bestpd).struct,pd.struct) then
                  break;
                if (pd.proctypeoption=bestpd.proctypeoption) and
                   ((pd.procoptions*[po_classmethod,po_methodpointer])=(bestpd.procoptions*[po_classmethod,po_methodpointer])) and
                   (compare_paras(pd.paras,bestpd.paras,cp_all,[cpo_ignorehidden,cpo_ignoreuniv,cpo_openequalisexact])=te_exact) then
                  begin
                    { first one encountered is closest in terms of visibility }
                    bestpd:=pd;
                    break;
                  end;
              end;
          end;
        result:=cntpd;
      end;


{$else}

    function compare_by_old_sortout_check(pd,bestpd:PCandidate):integer;
      var cpoptions : TCompareParasOptions;
      begin
        { don't add duplicates, only compare visible parameters for the user }
        cpoptions:=[cpo_ignorehidden];
        if (po_compilerproc in bestpd^.data.procoptions) then
          cpoptions:=cpoptions+[cpo_compilerproc];
        if (po_rtlproc in bestpd^.data.procoptions) then
          cpoptions:=cpoptions+[cpo_rtlproc];

        compare_by_old_sortout_check := 0; // can't decide, bestpd probably wasn't sorted out in unpatched
        if (compare_paras(pd^.data.paras,bestpd^.data.paras,cp_value_equal_const,cpoptions)>=te_equal) and
          (not(po_objc in bestpd^.data.procoptions) or (bestpd^.data.messageinf.str^=pd^.data.messageinf.str^)) then
          compare_by_old_sortout_check := 1; // bestpd was sorted out before patch

        { for implicit specializations non-generics should take precedence so
          when comparing a specialization to a non-specialization mark as undecided
          and it will be re-evaluated in is_better_candidate }
        if (m_implicit_function_specialization in CurrentSettings.ModeSwitches)
          and (pd^.data.is_specialization <> bestpd^.data.is_specialization) then
          compare_by_old_sortout_check:=0;
     end;

    function decide_restart(pd,bestpd:PCandidate) : boolean;
      begin
        decide_restart := false;
        if Assigned(bestpd) then
          begin
            { don't restart if bestpd is marked invalid already }
            if not bestpd^.invalid then
              decide_restart := compare_by_old_sortout_check(pd,bestpd)<>0;
        end;
      end;


    procedure save_validity(c : PCandidate);
      begin
        while Assigned(c) do
          begin
            c^.saved_validity := c^.invalid;
            c := c^.next;
          end;
      end;


    procedure restore_validity(c : PCandidate);
      begin
        while Assigned(c) do begin
          c^.invalid := c^.saved_validity;
          c := c^.next;
        end;
      end;


    function TCallCandidates.choose_best(var bestpd:TAbstractProcDef; singlevariant: boolean):integer;
      var
        pd: TProcDef;
        besthpstart,
        hp,hp2        : PCandidate;
        cntpd,
        res           : integer;
        restart : boolean;
      begin
        res:=0;
        {
          Returns the number of candidates left and the
          first candidate is returned in pdbest
        }
       if not(Assigned(FCandidateProcs)) then
         begin
           choose_best := 0;
           exit;
         end;

        bestpd:=FCandidateProcs^.data;
        if FCandidateProcs^.invalid then
          cntpd:=0
        else
          cntpd:=1;

        if Assigned(FCandidateProcs^.next) then
         begin
           save_validity(FCandidateProcs);
           restart := false;
           { keep restarting, until there wasn't a sorted-out besthpstart }
           repeat
             besthpstart:=FCandidateProcs;
             bestpd:=FCandidateProcs^.data;
             if restart then
               begin
                 restore_validity(FCandidateProcs);
                 restart := false;
               end;
             { Setup the first procdef as best, only count it as a result
               when it is valid }
             if besthpstart^.invalid then
               cntpd:=0
             else
               cntpd:=1;
             hp:=FCandidateProcs^.next;
             while Assigned(hp) and not(restart) do
               begin
                 restart := decide_restart(hp,besthpstart);
                 if not restart then
                   begin
                   if besthpstart^.invalid then res := 1
                   else if hp^.invalid then res := -1
                   else if not singlevariant then
                     res:=is_better_candidate(hp,besthpstart)
                   else
                     res:=is_better_candidate_single_variant(hp,besthpstart);
                 end;
                 if restart then
                   begin
                     { mark the sorted out invalid globally }
                     besthpstart^.saved_validity := true;
                   end
                 else if (res>0) then
                   begin
                     { hp is better, flag all procs to be incompatible }
                     while (besthpstart<>hp) do
                       begin
                         besthpstart^.invalid:=true;
                         besthpstart:=besthpstart^.next;
                       end;
                     { besthpstart is already set to hp }
                     bestpd:=besthpstart^.data;
                     if besthpstart^.invalid then
                       cntpd:=0
                     else
                       cntpd:=1;
                   end
                 else if (res<0) then
                   begin
                    { besthpstart is better, flag current hp to be incompatible }
                    hp^.invalid:=true;
                   end
                 else
                   begin
                     { res=0, both are valid }
                     if not hp^.invalid then
                       inc(cntpd);
                   end;
                 hp:=hp^.next;
               end;
           until not(restart);
         end;

        { check the alternate choices if they would have been sorted out before patch... }

        { note we have procadded the candidates, so order is reversed procadd order here.
          this was also used above: each sorted-out always has an "outsorter" counterpart
          deeper down the next chain
        }

        { for the initial implementation, let's first do some more consistency checking}
        res := 0;
        hp := FCandidateProcs;
        while Assigned(hp) do
          begin
            if not(hp^.invalid) then
              inc(res);
            hp := hp^.next;
          end;
        if (res<>cntpd) then
          InternalError(202002161);

        { check all valid choices for sortout }
        cntpd := 0;
        hp := FCandidateProcs;
        while Assigned(hp) do
          begin
            if not(hp^.invalid) then
              begin
                hp2 := hp^.next;
                while Assigned(hp2) do begin
                  if compare_by_old_sortout_check(hp2,hp)<>0 then
                    begin
                      hp^.invalid := true;
                      hp2 := nil;
                    end
                  else
                    hp2:=hp2^.next;
                end;
                if not(hp^.invalid) then
                  begin
                    inc(cntpd);
                    { check for the impossible event bestpd had become invalid}
                    if (cntpd=1) and (hp^.data<>bestpd) then
                      InternalError(202002162);
                  end;
              end;
            hp := hp^.next;
          end;


        { if we've found one, check the procdefs ignored for overload choosing
          to see whether they contain one from a child class with the same
          parameters (so the overload choosing was not influenced by their
          presence, but now that we've decided which overloaded version to call,
          make sure we call the version closest in terms of visibility }
        if (cntpd=1) and Assigned(FIgnoredCandidateProcs) then
          begin
            for res:=0 to FIgnoredCandidateProcs.count-1 do
              begin
                pd:=TProcDef(FIgnoredCandidateProcs[res]);
                { stop searching when we start comparing methods of parent of
                  the struct in which the current best method was found }
                if Assigned(pd.struct) and
                   (pd.struct<>TProcDef(bestpd).struct) and
                   def_is_related(TProcDef(bestpd).struct,pd.struct) then
                  break;
                if (pd.proctypeoption=bestpd.proctypeoption) and
                   ((pd.procoptions*[po_classmethod,po_methodpointer])=(bestpd.procoptions*[po_classmethod,po_methodpointer])) and
                   (compare_paras(pd.paras,bestpd.paras,cp_all,[cpo_ignorehidden,cpo_ignoreuniv,cpo_openequalisexact])=te_exact) then
                  begin
                    { first one encountered is closest in terms of visibility }
                    bestpd:=pd;
                    break;
                  end;
              end;
          end;
        result:=cntpd;
      end;

{$endif}





    procedure TCallCandidates.find_wrong_para;
      var
        currparanr : smallint;
        hp : PCandidate;
        pt : TCallParaNode;
        wrongpara : TParaVarSym;
      begin
        { Only process the first overloaded procdef }
        hp:=FCandidateProcs;
        { Find callparanode corresponding to the argument }
        pt:=TCallParaNode(FParanode);
        currparanr:=FParalength;
        while Assigned(pt) and
              (currparanr>hp^.wrongparanr) do
         begin
           pt:=TCallParaNode(pt.right);
           dec(currparanr);
         end;
        if (currparanr<>hp^.wrongparanr) or
           not Assigned(pt) then
          InternalError(200212094);
        { Show error message, when it was a var or out parameter
          guess that it is a missing typeconv }
        wrongpara:=TParaVarSym(hp^.data.paras[hp^.wrongparaidx]);
        if wrongpara.varspez in [vs_var,vs_out] then
          begin
            { Maybe passing the correct type but passing a const to var parameter }
            if (compare_defs(pt.resultdef,wrongpara.vardef,pt.nodetype)<>te_incompatible) and
               not valid_for_var(pt.left,true) then
              CGMessagePos(pt.left.fileinfo,type_e_variable_id_expected)
            else
              CGMessagePos3(pt.left.fileinfo,parser_e_call_by_ref_without_typeconv,ToStr(hp^.wrongparanr),
                FullTypeName(pt.left.resultdef,wrongpara.vardef),
                FullTypeName(wrongpara.vardef,pt.left.resultdef))
          end
        else
          begin
            CGMessagePos3(pt.left.fileinfo,type_e_wrong_parameter_type,ToStr(hp^.wrongparanr),
              FullTypeName(pt.left.resultdef,wrongpara.vardef),
              FullTypeName(wrongpara.vardef,pt.left.resultdef));
          end;
      end;


    procedure check_ranges(const location: TFilePosInfo; source: TNode; destdef: TDef);
      begin
        if not(cs_check_ordinal_size in CurrentSettings.LocalSwitches) then
          exit;
        { check if the assignment may cause a range check error }
        { if its not explicit, and only if the values are       }
        { ordinals, enumdef and floatdef                        }
        if Assigned(destdef) and
          (destdef.typ in [enumdef,orddef,floatdef]) and
          not is_boolean(destdef) and
          Assigned(source.resultdef) and
          (source.resultdef.typ in [enumdef,orddef,floatdef]) and
          not is_boolean(source.resultdef) and
          not is_constrealnode(source) and
          { constants are handled via regular range checking }
          (source.nodetype<>ordconstn) then
         begin
           if ((destdef.size < source.resultdef.size) and
               { s80real and sc80real have a different size but the same precision }
               not((destdef.typ=floatdef) and
                   (source.resultdef.typ=floatdef) and
                   (TFloatDef(source.resultdef).floattype in [s80real,sc80real]) and
                   (TFloatDef(destdef).floattype in [s80real,sc80real]))) or
              ((destdef.typ<>floatdef) and
               (source.resultdef.typ<>floatdef) and
               not is_in_limit(source.resultdef,destdef)) then
             begin
               if (cs_check_range in CurrentSettings.LocalSwitches) then
                 MessagePos(location,type_w_smaller_possible_range_check)
               else
                 MessagePos(location,type_h_smaller_possible_range_check);
             end;
         end;
      end;

    function is_valid_for_default(def:TDef):boolean;

      function is_valid_record_or_object(def:TAbstractRecordDef):boolean;
        var
          sym : TSym;
          i : LongInt;
        begin
          for i:=0 to def.SymTable.symlist.count-1 do
            begin
              sym:=TSym(def.SymTable.symlist[i]);
              if not is_normal_fieldvarsym(sym) then
                continue;
              if not is_valid_for_default(TFieldVarSym(sym).vardef) then
                begin
                  result:=false;
                  exit;
                end;
            end;
          result:=true;
        end;

      begin
        case def.typ of
          recorddef:
            result:=is_valid_record_or_object(TAbstractRecordDef(def));
          objectdef:
            if is_implicit_pointer_object_type(def) then
              result:=true
            else
              if is_object(def) then
                result:=is_valid_record_or_object(TAbstractRecordDef(def))
              else
                result:=false;
          arraydef:
            if not (ado_isdynamicarray in TArrayDef(def).arrayoptions) then
              result:=is_valid_for_default(TArrayDef(def).elementdef)
            else
              result:=true;
          formaldef,
          abstractdef,
          filedef:
            result:=false;
          else
            result:=true;
        end;
      end;


end.
