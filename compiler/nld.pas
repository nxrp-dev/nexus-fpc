{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Type checking and register allocation for load/assignment nodes

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
unit nld;

{$i fpcdefs.inc}

interface

    uses
       node,
       {$ifdef state_tracking}
       nstate,
       {$endif}
       symconst,SymBase,symtype,SymSym,symdef;

    type
       Trttidatatype = (rdt_normal,rdt_ord2str,rdt_str2ord);

       TLoadNodeFlags = (
         loadnf_is_self,
         { tell the load node the address of the symbol into the location, i.e. location^ must
           be used to access the symbol
           this is for example needed to load self for objects }
         loadnf_load_addr,
         loadnf_inherited,
         { the loadnode is generated internally and a varspez=vs_const should be ignore,
           this requires that the parameter is actually passed by value
           Be really careful when using this flag! }
         loadnf_isinternal_ignoreconst,

         loadnf_only_uninitialized_hint
        );

       TLoadNode = class(TUnaryNode)
       protected
          fprocdef : TProcDef;
          fprocdefderef : TDeref;
          function handle_threadvar_access: TNode; virtual;
       public
          loadnodeflags : set of TLoadNodeFlags;
          symtableentry : TSym;
          symtableentryderef : TDeref;
          SymTable : TSymTable;
          constructor create(v : TSym;st : TSymTable);virtual;
          constructor create_procvar(v : TSym;d:TProcDef;st : TSymTable);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          procedure set_mp(p:TNode);
          function  is_addr_param_load:boolean;virtual;
          function  dogetcopy : TNode;override;
          function  pass_1 : TNode;override;
          function  pass_typecheck:TNode;override;
          procedure mark_write;override;
          function  docompare(p: TNode): boolean; override;
          procedure printnodedata(var t:text);override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
          procedure setprocdef(p : TProcDef;forfuncref:boolean);
          property procdef: TProcDef read fprocdef;
       end;
       TLoadNodeClass = class of TLoadNode;

       { different assignment types }
       TAssignType = (at_normal,at_plus,at_minus,at_star,at_slash);

       TAssignmentNodeFlag = (
         anf_assign_done_in_right
       );

       TAssignmentNodeFlags = set of TAssignmentNodeFlag;

       TAssignmentNode = class(TBinaryNode)
         protected
          function direct_shortstring_assignment: boolean; virtual;
         public
          assignmentnodeflags : TAssignmentNodeFlags;
          assigntype : TAssignType;
          constructor create(l,r : TNode);virtual;
          { no checks for validity of assignment }
          constructor create_internal(l,r : TNode);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function simplify(forinline : boolean) : TNode;override;
       {$ifdef state_tracking}
          function track_state_pass(exec_known:boolean):boolean;override;
       {$endif state_tracking}
          function docompare(p: TNode): boolean; override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeInfo(var T: Text); override;
          procedure XMLPrintNodeData(var T: Text); override;
{$endif DEBUG_NODE_XML}
       end;
       TAssignmentNodeClass = class of TAssignmentNode;

       TArrayConstructorRangeNode = class(TBinaryNode)
          constructor create(l,r : TNode);virtual;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
       end;
       TArrayConstructorRangeNodeClass = class of TArrayConstructorRangeNode;

       TArrayConstructorNodeFlag = (
         acnf_allow_array_constructor,
         acnf_forcevaria,
         acnf_novariaallowed
       );

       TArrayConstructorNodeFlags = set of TArrayConstructorNodeFlag;

       TArrayConstructorNode = class(TBinaryNode)
          arrayconstructornodeflags : TArrayConstructorNodeFlags;
         private
          function has_range_node:boolean;
         protected
          procedure wrapmanagedvarrec(var n : TNode);virtual;abstract;
         public
          constructor create(l,r : TNode);virtual;
          constructor ppuload(t : TNodeType;ppufile : TCompilerPPUFile);override;
          procedure ppuwrite(ppufile : TCompilerPPUFile);override;
          function dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode): boolean; override;
          procedure force_type(def:TDef);
          procedure insert_typeconvs;
          function isempty : boolean;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeInfo(var t : text);override;
{$endif DEBUG_NODE_XML}
       end;
       TArrayConstructorNodeClass = class of TArrayConstructorNode;

       TTypeNode = class(TNode)
          allowed : boolean;
          helperallowed : boolean;
          typedef : TDef;
          typedefderef : TDeref;
          typesym : TSym;
          typesymderef : TDeref;
          constructor create(def:TDef);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function  dogetcopy : TNode;override;
          function docompare(p: TNode): boolean; override;
       end;
       TTypeNodeClass = class of TTypeNode;

       TRTTINode = class(TNode)
          l1,l2  : LongInt;
          rttitype : TRTTIType;
          rttidef : TStoredDef;
          rttidefderef : TDeref;
          rttidatatype : Trttidatatype;
          constructor create(def:TStoredDef;rt:TRTTIType;dt:Trttidatatype);virtual;
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          function  dogetcopy : TNode;override;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function docompare(p: TNode): boolean; override;
       end;
       TRTTINodeClass = class of TRTTINode;

    var
       CLoadNode : TLoadNodeClass = TLoadNode;
       CAssignmentNode : TAssignmentNodeClass = TAssignmentNode;
       CArrayConstructorRangeNode : TArrayConstructorRangeNodeClass = TArrayConstructorRangeNode;
       CArrayConstructorNode : TArrayConstructorNodeClass = TArrayConstructorNode;
       CTypeNode : TTypeNodeClass = TTypeNode;
       CRTTINode : TRTTINodeClass = TRTTINode;

       { Current assignment node }
       aktassignmentnode : TAssignmentNode;

       { Create a node tree to load a variable if symbol is assigned, otherwise an error node.
         Generates an internalerror if called for an absolutevarsym of the "tovar" kind (those
         are only supported for expansion in the parser) }
       function gen_load_var(sym: TAbstractVarSym): TNode;

implementation

    uses
      Verbose,GlobType,Globals,Systems,ConstExp,compinnr,
      ppu,
      SymTable,
      defutil,defcmp,
      CPUInfo,
      htypechk,pass_1,ProcInfo,paramgr,
      nbas,ncon,nflw,ninl,ncnv,nmem,ncal,nutils,
      cgbase,
      optloadmodifystore,wpobase
      ;


    function gen_load_var(sym: TAbstractVarSym): TNode;
      begin
        result:=nil;
        if Assigned(sym) then
          begin
            if (sym.typ<>absolutevarsym) or
               (TAbsoluteVarSym(sym).abstyp<>tovar) then
              begin
                result:=CLoadNode.create(sym,sym.owner);
              end
            else
              InternalError(2020122601);
          end
        else
          begin
            result:=CErrorNode.create;
            CGMessage(parser_e_illegal_expression);
          end;
      end;


{*****************************************************************************
                             TLOADNODE
*****************************************************************************}

    function TLoadNode.handle_threadvar_access: TNode;
      begin
        { nothing special by default }
        result:=nil;
      end;


    constructor TLoadNode.create(v : TSym;st : TSymTable);
      begin
         inherited create(loadn,nil);
         if not Assigned(v) then
          InternalError(200108121);
         symtableentry:=v;
         SymTable:=st;
         fprocdef:=nil;
      end;


    constructor TLoadNode.create_procvar(v : TSym;d:TProcDef;st : TSymTable);
      begin
         inherited create(loadn,nil);
         if not Assigned(v) then
          InternalError(200108122);
         symtableentry:=v;
         SymTable:=st;
         fprocdef:=d;
      end;


    constructor TLoadNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.getderef(symtableentryderef);
        SymTable:=nil;
        ppufile.getderef(fprocdefderef);
        ppufile.getset(TPPUSet1(loadnodeflags));
      end;


    procedure TLoadNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putderef(symtableentryderef);
        ppufile.putderef(fprocdefderef);
        ppufile.putset(TPPUSet1(loadnodeflags));
      end;


    procedure TLoadNode.buildderefimpl;
      begin
        inherited buildderefimpl;
        symtableentryderef.build(symtableentry);
        fprocdefderef.build(fprocdef);
      end;


    procedure TLoadNode.derefimpl;
      begin
        inherited derefimpl;
        symtableentry:=TSym(symtableentryderef.resolve);
        SymTable:=symtableentry.owner;
        fprocdef:=TProcDef(fprocdefderef.resolve);
      end;


    procedure TLoadNode.set_mp(p:TNode);
      begin
        { typen nodes should not be set }
        if p.nodetype=typen then
          InternalError(200301042);
        left:=p;
      end;


    function TLoadNode.dogetcopy : TNode;
      var
         n : TLoadNode;
         orglabel,
         labelcopy : TLabelNode;
      begin
         n:=TLoadNode(inherited dogetcopy);
         n.SymTable:=SymTable;
         n.symtableentry:=symtableentry;
         n.fprocdef:=fprocdef;
         n.loadnodeflags:=loadnodeflags;
         if symtableentry.typ=labelsym then
           begin
             { see the comments for the tgotonode.labelsym field }
             orglabel:=TLabelNode(TLabelSym(symtableentry).code);
             labelcopy:=TLabelNode(orglabel.dogetcopy);
             if not Assigned(labelcopy.labsym) then
               begin
                 if not Assigned(orglabel.labsym) then
                   InternalError(2019091301);
                 labelcopy.labsym:=CLabelSym.create('$copiedlabelfrom$'+orglabel.labsym.RealName);
                 labelcopy.labsym.code:=labelcopy;
               end;
             n.symtableentry:=labelcopy.labsym;
           end;
         result:=n;
      end;


    function TLoadNode.is_addr_param_load:boolean;
      begin
        result:=(SymTable.symtabletype=parasymtable) and
                (symtableentry.typ=paravarsym) and
                not(vo_has_local_copy in TParaVarSym(symtableentry).varoptions) and
                not(loadnf_load_addr in loadnodeflags) and
                paramanager.push_addr_param(TParaVarSym(symtableentry).varspez,TParaVarSym(symtableentry).vardef,TProcDef(SymTable.defowner).proccalloption);
      end;


    function TLoadNode.pass_typecheck:TNode;
      begin
         result:=nil;
         case symtableentry.typ of
           absolutevarsym :
             resultdef:=TAbsoluteVarSym(symtableentry).vardef;
           constsym:
             begin
               if TConstSym(symtableentry).consttyp=constresourcestring then
                 resultdef:=getansistringdef
               else if TConstSym(symtableentry).consttyp=constwresourcestring then
                 resultdef:=cunicodestringtype
               else
                 InternalError(22799);
             end;
           staticvarsym :
             begin
               TAbstractVarSym(symtableentry).IncRefCountBy(1);
               { static variables referenced in procedures or from finalization,
                 variable needs to be in memory.
                 It is too hard and the benefit is too small to detect whether a
                 variable is only used in the finalization to add support for it (PFV) }
               if Assigned(CurrentProcInfo) and
                  (SymTable.symtabletype=staticsymtable) and
                  (
                    (SymTable.symtablelevel<>CurrentProcInfo.procdef.localst.symtablelevel) or
                    (CurrentProcInfo.procdef.proctypeoption=potype_unitfinalize)
                  ) then
                 make_not_regable(self,[ra_different_scope]);
               resultdef:=TAbstractVarSym(symtableentry).vardef;
               if vo_is_thread_var in TStaticVarSym(symtableentry).varoptions then
                 result:=handle_threadvar_access;
             end;
           paravarsym,
           localvarsym :
             begin
               TAbstractVarSym(symtableentry).IncRefCountBy(1);
               resultdef:=TAbstractVarSym(symtableentry).vardef;
               { Nested variable? The we need to load the framepointer of
                 the parent procedure }
               if Assigned(CurrentProcInfo) and
                  (SymTable.symtabletype in [localsymtable,parasymtable]) and
                  (SymTable.symtablelevel<>CurrentProcInfo.procdef.parast.symtablelevel) then
                 begin
                   if Assigned(left) then
                     InternalError(200309289);
                   left:=CLoadParentFPNode.create(TProcDef(SymTable.defowner),lpf_forload);
                   CurrentProcInfo.set_needs_parentfp(TProcDef(SymTable.defowner).parast.symtablelevel);
                   { reference this as a captured symbol }
                   CurrentProcInfo.add_captured_sym(symtableentry,resultdef,fileinfo);
                   { reference in nested procedures, variable needs to be in memory }
                   { and behaves as if its address escapes its parent block         }
                   make_not_regable(self,[ra_different_scope]);
                 end
               { if this is a nested function and it uses the Self parameter then
                 consider this as captured as well (needed for anonymous functions) }
               else if Assigned(CurrentProcInfo) and
                   (vo_is_self in TAbstractVarSym(symtableentry).varoptions) and
                   (SymTable.symtablelevel>normal_function_level) then
                 CurrentProcInfo.add_captured_sym(symtableentry,resultdef,fileinfo);

               { e.g. self for objects is passed as var-parameter on the caller
                 side, but on the callee-side we use it as a pointer ->
                 adjust }
               if (loadnf_load_addr in loadnodeflags) then
                 resultdef:=CPointerDef.getreusable(resultdef);

               if (vo_is_self in TAbstractVarSym(symtableentry).varoptions) and (resultdef=objc_idtype) and
                 (po_classmethod in TProcDef(symtableentry.owner.defowner).procoptions) then
                 resultdef:=CClassRefDef.create(TProcDef(symtableentry.owner.defowner).struct)
             end;
           procsym :
             begin
               { Return the first procdef. In case of overloaded
                 procdefs the matching procdef will be choosen
                 when the expected procvardef is known, see get_information
                 in htypechk.pas (PFV) }
               if not Assigned(fprocdef) then
                 fprocdef:=TProcDef(TProcSym(symtableentry).ProcdefList[0])
               else if po_kylixlocal in fprocdef.procoptions then
                 CGMessage(type_e_cant_take_address_of_local_subroutine);

               { the result is a fprocdef, addrn and proc_to_procvar
                 typeconvn need this as resultdef so they know
                 that the address needs to be returned }
               resultdef:=fprocdef;

               if is_nested_pd(fprocdef) and is_nested_pd(CurrentProcInfo.procdef) then
                 CurrentProcInfo.set_needs_parentfp(TProcDef(fprocdef.owner.defowner).parast.symtablelevel);

               { process methodpointer/framepointer }
               if Assigned(left) then
                 begin
                   TypeCheckPass(left);
                   if (po_classmethod in fprocdef.procoptions) and
                      is_class(left.resultdef) and
                      (left.nodetype<>niln) then
                     begin
                       left:=CLoadVMTAddrNode.create(left);
                       TypeCheckPass(left);
                     end
                 end;

               { we can't know what will happen with this function pointer, so
                 we have to assume it will be used to create an instance of this
                 type }
               if fprocdef.wpo_may_create_instance(left) then
                 begin
                   if wpoinfomanager.symbol_live_in_currentproc(TDef(SymTable.defowner)) then
                     begin
                       if Assigned(left) then
                         TObjectDef(left.resultdef).RegisterCreatedObjectType
                       else
                         TObjectDef(fprocdef.owner.defowner).RegisterCreatedObjectType;
                     end;
                 end;
             end;
           labelsym:
             begin
               TLabelSym(symtableentry).used:=true;
               resultdef:=voidtype;
             end;
           else
             InternalError(200104141);
         end;

         { Currency variables are scaled by 10000 when stored }
         if is_currency(resultdef) then
           Include(flags, nf_is_currency);
      end;

    procedure TLoadNode.mark_write;

    begin
      include(flags,nf_write);
    end;

    function TLoadNode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_REFERENCE;

         case symtableentry.typ of
            absolutevarsym :
              ;
            constsym:
              begin
                if TConstSym(symtableentry).consttyp in [constresourcestring,constwresourcestring] then
                  expectloc:=LOC_CREFERENCE;
              end;
            staticvarsym,
            localvarsym,
            paravarsym :
              begin
                if Assigned(left) then
                  FirstPass(left);
                if not is_addr_param_load and
                   TAbstractVarSym(symtableentry).is_regvar(is_addr_param_load) then
                  expectloc:=tvarregable2tcgloc[TAbstractVarSym(symtableentry).varregable]
                else
                  if (TAbstractVarSym(symtableentry).varspez=vs_const) then
                    expectloc:=LOC_CREFERENCE;
                { call to get address of threadvar }
                if (vo_is_thread_var in TAbstractVarSym(symtableentry).varoptions) then
                  begin
                    include(CurrentProcInfo.flags,pi_do_call);
                    include(CurrentProcInfo.flags,pi_uses_threadvar);
                  end;
              end;
            procsym :
              begin
                { initialise left for nested procs if necessary (this won't need
                  to pass true for the forfuncref parameter, cause code that would
                  need that wouldn't have been reworked before it reaches pass_1) }
                if (m_nested_procvars in CurrentSettings.ModeSwitches) then
                  setprocdef(fprocdef,false);
                { method pointer or nested proc ? }
                if Assigned(left) then
                  begin
                     expectloc:=LOC_CREGISTER;
                     FirstPass(left);
                  end;
              end;
            labelsym :
              begin
                if not Assigned(TLabelSym(symtableentry).asmblocklabel) and
                   not Assigned(TLabelSym(symtableentry).code) then
                  Message(parser_e_label_outside_proc);
              end
            else
              InternalError(200104143);
         end;
      end;


    function TLoadNode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (symtableentry = TLoadNode(p).symtableentry) and
          (fprocdef = TLoadNode(p).fprocdef) and
          (SymTable = TLoadNode(p).SymTable);
      end;


    procedure TLoadNode.printnodedata(var t:text);
      begin
        inherited printnodedata(t);
        write(t,PrintNodeIndention,'symbol = ',symtableentry.name);
        if symtableentry.typ=procsym then
          write(t,PrintNodeIndention,'procdef = ',fprocdef.mangledname);
        WriteLn(t,'');
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TLoadNode.XMLPrintNodeData(var T: Text);
      begin
        inherited XMLPrintNodeData(T);
        WriteLn(T, PrintNodeIndention, '<symbol>', symtableentry.name, '</symbol>');

        if symtableentry.typ = procsym then
          WriteLn(T, PrintNodeIndention, '<procdef>', fprocdef.mangledname, '</procdef>');
      end;
{$endif DEBUG_NODE_XML}

    procedure TLoadNode.setprocdef(p : TProcDef;forfuncref:boolean);
      begin
        fprocdef:=p;
        resultdef:=p;
        { nested procedure? }
        if Assigned(p) and
           is_nested_pd(p) and
           not forfuncref and
           (
             not (po_anonymous in p.procoptions) or
             (po_delphi_nested_cc in p.procoptions)
           ) then
          begin
            if not(m_nested_procvars in CurrentSettings.ModeSwitches) then
              CGMessage(type_e_cant_take_address_of_local_subroutine)
            else
              begin
                { parent frame pointer pointer as "self" }
                left.free;
                left:=CLoadParentFPNode.create(TProcDef(p.owner.defowner),lpf_forpara);
                TypeCheckPass(left);
              end;
          end
        { we should never go from nested to non-nested (except for an anonymous
          function which might have been changed to a global function or a
          method) }
        else if Assigned(left) and
                (left.nodetype=loadparentfpn) then
          begin
            if po_anonymous in p.procoptions then
              begin
                left.free;
                left:=nil;
              end
            else
              InternalError(2010072201);
          end;
      end;

{*****************************************************************************
                             TASSIGNMENTNODE
*****************************************************************************}

    function TAssignmentNode.direct_shortstring_assignment: boolean;
      begin
        result:=
          is_char(right.resultdef) or
          (right.resultdef.typ=stringdef);
      end;


    constructor TAssignmentNode.create(l,r : TNode);

      begin
         inherited create(assignn,l,r);
         assignmentnodeflags:=[];
         assigntype:=at_normal;
         if r.nodetype = typeconvn then
           TTypeConvNode(r).warn_pointer_to_signed:=false;
      end;


    constructor TAssignmentNode.create_internal(l, r: TNode);
      begin
        create(l,r);
        include(flags,nf_internal);
      end;


    constructor TAssignmentNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.getset(TPPUSet1(assignmentnodeflags));
        assigntype:=TAssignType(ppufile.getbyte);
      end;


    procedure TAssignmentNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putset(TPPUSet1(assignmentnodeflags));
        ppufile.putbyte(byte(assigntype));
      end;


    function TAssignmentNode.dogetcopy : TNode;

      var
         n : TAssignmentNode;

      begin
         n:=TAssignmentNode(inherited dogetcopy);
         n.assignmentnodeflags:=assignmentnodeflags;
         n.assigntype:=assigntype;
         result:=n;
      end;


    function TAssignmentNode.simplify(forinline : boolean) : TNode;
      begin
        result:=nil;
        { assignment nodes can perform several floating point }
        { type conversions directly, so no typeconversions    }
        { are inserted in those cases. When inlining, a       }
        { variable may be replaced by a constant which can be }
        { converted at compile time, so check for this case   }
        if is_real(left.resultdef) and
           is_real(right.resultdef) and
           is_constrealnode(right) and
           not equal_defs(right.resultdef,left.resultdef) then
          inserttypeconv(right,left.resultdef);
        { Perform simple optimizations when -O2 and the dedicated
          cs_opt_use_load_modify_store optimization pass is not enabled. }
        if (cs_opt_use_load_modify_store in supported_optimizerswitches) and
           (cs_opt_level2 in CurrentSettings.OptimizerSwitches) and
           not (cs_opt_use_load_modify_store in CurrentSettings.OptimizerSwitches) then
          result:=try_opt_assignmentnode(self);
      end;


    function TAssignmentNode.pass_typecheck:TNode;
      var
        hp : TNode;
        useshelper : boolean;
        oldassignmentnode : TAssignmentNode;
      begin
        result:=nil;
        resultdef:=voidtype;

        { must be made unique }
        set_unique(left);

        TypeCheckPass(left);

        left.mark_write;

        { PI. This is needed to return correct resultdef of add nodes for ansistrings
          rawbytestring return needs to be replaced by left.resultdef }
        oldassignmentnode:=aktassignmentnode;
        aktassignmentnode:=self;
        TypeCheckPass(right);
        aktassignmentnode:=oldassignmentnode;

        set_varstate(right,vs_read,[vsf_must_be_valid]);
        set_varstate(left,vs_written,[]);
        if CodeGenError then
          exit;

        { just in case the typecheckpass of right optimized something here }
        if anf_assign_done_in_right in assignmentnodeflags then
          begin
            result:=right;
            right:=nil;
            exit;
          end;

        { tp procvar support, when we don't expect a procvar
          then we need to call the procvar }
        if (left.resultdef.typ<>procvardef) and
            not is_invokable(left.resultdef) then
          maybe_call_procvar(right,true);

        { assignments to formaldefs and open arrays aren't allowed }
        if is_open_array(left.resultdef) or is_array_of_const(left.resultdef) then
          begin
            CGMessage(type_e_assignment_not_allowed);
            result:=CErrorNode.create;
            exit;
          end
        else if (left.resultdef.typ=formaldef) then
          CGMessage(type_e_assignment_not_allowed);


        { test if node can be assigned, properties are allowed }
        if not(nf_internal in flags) then
          if not valid_for_assignment(left,true) then
            { errors can in situations that cause the compiler to run out of
              memory, such as assigning to an implicit pointer-to-array
              converted node (that array is 2^31 or 2^63 bytes large) }
            exit;

        { assigning nil or [] to a dynamic array clears the array }
        if is_dynamic_array(left.resultdef) and
            (
              (right.nodetype=niln) or
              (
                (right.nodetype=arrayconstructorn) and
                (right.resultdef.typ=arraydef) and
                (TArrayDef(right.resultdef).elementdef=voidtype) and
                TArrayConstructorNode(right).isempty
              )
            ) then
         begin
           { remove property flag to avoid errors, see comments for }
           { tf_winlikewidestring assignments below                 }
           exclude(left.flags,nf_isproperty);
           { generate a setlength node so it can be intercepted by
             target-specific code }
           result:=CInlineNode.create(in_setlength_x,false,
             CCallParaNode.create(genintconstnode(0),
               CCallParaNode.create(left,nil)));
           left:=nil;
           exit;
         end;

        { shortstring helpers can do the conversion directly,
          so treat them separately }
        if (is_shortstring(left.resultdef)) then
         begin
           { insert typeconv, except for chars that are handled in
             secondpass and except for ansi/wide string that can
             be converted immediately }
           if not direct_shortstring_assignment then
             inserttypeconv(right,left.resultdef);
           if right.resultdef.typ=stringdef then
            begin
              useshelper:=true;
              { convert constant strings to shortstrings. But
                skip empty constant strings, that will be handled
                in secondpass }
              if (right.nodetype=stringconstn) then
                begin
                  { verify if range fits within shortstring }
                  { just emit a warning, delphi gives an    }
                  { error, only if the type definition of   }
                  { of the string is less  < 255 characters }
                  if not is_open_string(left.resultdef) and
                     (TStringConstNode(right).len > TStringDef(left.resultdef).len) then
                     CGMessage(type_w_string_too_long);
                  inserttypeconv(right,left.resultdef);
                  if (right.nodetype=stringconstn) and
                     (TStringConstNode(right).len=0) then
                    useshelper:=false;
                end
              else if (TStringDef(right.resultdef).stringtype in [st_unicodestring,st_widestring]) then
                Message2(type_w_implicit_string_cast_loss,right.resultdef.typename,left.resultdef.typename);
             { rest is done in pass 1 (JM) }
             if useshelper then
               exit;
            end
         end
        { floating point assignments can also perform the conversion directly }
        else if is_real(left.resultdef) and is_real(right.resultdef) and
                not is_constrealnode(right)

{$ifdef x86}
                { the assignment node code can't convert a double in an }
                { sse register to an extended value in memory more      }
                { efficiently than a type conversion node, so don't     }
                { bother implementing support for that                  }
                and (use_vectorfpu(left.resultdef) or not(use_vectorfpu(right.resultdef)))
{$endif}

        then
          begin
            if not(nf_internal in flags) then
              check_ranges(fileinfo,right,left.resultdef);
          end
        else
          begin
            { check if the assignment may cause a range check error }
            if not(nf_internal in flags) then
              check_ranges(fileinfo,right,left.resultdef);

            { beginners might be confused about an error message like
              Incompatible types: got "untyped" expected "LongInt"
              when trying to assign the result of a procedure, so give
              a better error message, see also #19122 }
            if (left.resultdef.typ<>procvardef) and
                not is_invokable(left.resultdef) and
              (right.nodetype=calln) and is_void(right.resultdef) then
              CGMessage(type_e_procedures_return_no_value)
            else
              begin
                if nf_internal in flags then
                  inserttypeconv_internal(right,left.resultdef)
                else
                  inserttypeconv(right,left.resultdef);

                { If assigning to a currency type, we need to make sure the
                  value is correctly scaled }
                if (nf_is_currency in left.flags) and
                  not (nf_is_currency in right.flags) then
                  begin
                    right:=CTypeConvNode.Create(right,right.resultdef);
                    Include(right.flags,nf_is_currency);

                    { Force an explicit conversion so the scalar is generated }
                    if s64currencytype.typ=floatdef then
                      TTypeConvNode(right).convtype:=tc_real_2_real
                    else
                      TTypeConvNode(right).convtype:=tc_int_2_int;
                    TypeCheckPass(right);
                  end;
              end;
          end;

        { call helpers for interface }
        if is_interfacecom_or_dispinterface(left.resultdef) then
         begin
	   { Normal interface assignments are handled by the generic refcount incr/decr }
           if not def_is_related(right.resultdef,left.resultdef) then
             begin
               { remove property flag to avoid errors, see comments for }
               { tf_winlikewidestring assignments below                 }
               exclude(left.flags,nf_isproperty);
               hp:=
                 CCallParaNode.create(
                   CGUIDConstNode.create(TObjectDef(left.resultdef).iidguid^),
                 CCallParaNode.create(
                   CTypeConvNode.create_internal(right,voidpointertype),
                 CCallParaNode.create(
                   CTypeConvNode.create_internal(left,voidpointertype),
                   nil)));
               result:=CCallNode.createintern('fpc_intf_assign_by_iid',hp);
               left:=nil;
               right:=nil;
               exit;
             end;
         end;

        { check if local proc/func is assigned to procvar }
        if right.resultdef.typ=procvardef then
          test_local_to_procvar(TProcVarDef(right.resultdef),left.resultdef);
      end;


    function TAssignmentNode.pass_1 : TNode;

      function tempreturnfromcall:boolean;
        var
          node:TNode;
        begin
          result:=false;
          if not is_managed_type(right.resultdef) then
            exit;
          node:=right;
          while Assigned(node) do
            begin
              case node.nodetype of
              blockn:
                node:=TBlockNode(node).left;
              statementn:
                if Assigned(TStatementNode(node).right) then
                  node:=TStatementNode(node).right
                else
                  node:=TStatementNode(node).left;
              else
                break;
              end;
            end;
          if not Assigned(node) then
            InternalError(2024111101);
          if (node.nodetype=calln) and Assigned(TCallNode(node).funcretnode) then
            node:=TCallNode(node).funcretnode;
          result:=(node.nodetype=temprefn) and (nf_is_funcret in node.flags);
        end;

      var
        hp: TNode;
        oldassignmentnode : TAssignmentNode;
        hdef: TDef;
        hs: string;
        needrtti: boolean;
      begin
         result:=nil;
         expectloc:=LOC_VOID;

         FirstPass(left);

         { Optimize the reuse of the destination of the assignment in left.
           Allow the use of the left inside the tree generated on the right.
           This is especially useful for string routines where the destination
           is pushed as a parameter. Using the final destination of left directly
           save a temp allocation and copy of data (PFV) }
         oldassignmentnode:=aktassignmentnode;
         aktassignmentnode:=self;
         FirstPass(right);
         aktassignmentnode:=oldassignmentnode;
         if anf_assign_done_in_right in assignmentnodeflags then
           begin
             result:=right;
             right:=nil;
             exit;
           end;

         if CodeGenError then
           exit;

         { assignment to refcounted variable -> inc/decref }
         if is_managed_type(left.resultdef) then
           include(CurrentProcInfo.flags,pi_do_call);

         needrtti:=false;

        if (is_shortstring(left.resultdef)) then
          begin
           if right.resultdef.typ=stringdef then
            begin
              if (right.nodetype<>stringconstn) or
                 (TStringConstNode(right).len<>0) then
               begin
                 { remove property flag to avoid errors, see comments for }
                 { tf_winlikewidestring assignments below                 }
                 exclude(left.flags, nf_isproperty);
                 hp:=CCallParaNode.create
                       (right,
                  CCallParaNode.create(left,nil));
                 result:=CCallNode.createintern('fpc_'+TStringDef(right.resultdef).stringtypname+'_to_shortstr',hp);
                 FirstPass(result);
                 left:=nil;
                 right:=nil;
               end;
            end;
            exit;
           end
        { call helpers for composite types containing automated types }
        else if is_managed_type(left.resultdef) and
            (left.resultdef.typ in [arraydef,objectdef,recorddef]) and
            not is_interfacecom_or_dispinterface(left.resultdef) and
            not is_dynamic_array(left.resultdef) and
            not is_const(left) then
         begin
           hp:=CCallParaNode.create(CAddrNode.create_internal(
                  CRTTINode.create(TStoredDef(left.resultdef),initrtti,rdt_normal)),
               CCallParaNode.create(CTypeConvNode.create_internal(
                 CAddrNode.create_internal(left),voidpointertype),
               CCallParaNode.create(CTypeConvNode.create_internal(
                 CAddrNode.create_internal(right),voidpointertype),
               nil)));
           if tempreturnfromcall then
             result:=CCallNode.createintern('fpc_copy_with_move_semantics_proc',hp)
           else
             result:=CCallNode.createintern('fpc_copy_proc',hp);
           FirstPass(result);
           left:=nil;
           right:=nil;
           exit;
         end
        { call helpers for variant, they can contain non ref. counted types like
          vararrays which must be really copied }
        else if (left.resultdef.typ=variantdef) and
            not(is_const(left)) then
         begin
           { remove property flag to avoid errors, see comments for }
           { tf_winlikewidestring assignments below                 }
           exclude(left.flags,nf_isproperty);
           hdef:=search_system_type('TVARDATA').typedef;
           hp:=CCallParaNode.create(CTypeConvNode.create_internal(
                 right,hdef),
               CCallParaNode.create(CTypeConvNode.create_internal(
                 left,hdef),
               nil));
           result:=CCallNode.createintern('fpc_variant_copy',hp);
           FirstPass(result);
           left:=nil;
           right:=nil;
           exit;
         end
        else if not(is_const(left)) then
          begin
            { call helpers for pointer-sized managed types }
            if is_widestring(left.resultdef) then
              hs:='fpc_widestr_assign'
            else if is_ansistring(left.resultdef) then
              hs:='fpc_ansistr_assign'
            else if is_unicodestring(left.resultdef) then
              hs:='fpc_unicodestr_assign'
            else if is_interfacecom_or_dispinterface(left.resultdef) then
              hs:='fpc_intf_assign'
            else if is_dynamic_array(left.resultdef) then
              begin
                hs:='fpc_dynarray_assign';
                needrtti:=true;
              end
            else
              exit;
          end
        else
          exit;

        { The first argument of these procedures is a var parameter. Properties cannot     }
        { be passed to var or out parameters, because in that case setters/getters are not }
        { used. Further, if we would allow it in case there are no getters or setters, you }
        { would need source changes in case these are introduced later on, thus defeating  }
        { part of the transparency advantages of properties. In this particular case,      }
        { however:                                                                         }
        {   a) if there is a setter, this code will not be used since then the assignment  }
        {      will be converted to a procedure call                                       }
        {   b) the getter is irrelevant, because fpc_widestr_assign must always decrease   }
        {      the refcount of the field to which we are writing                           }
        {   c) source code changes are not required if a setter is added/removed, because  }
        {      this transformation is handled at compile time                              }
        {  -> we can remove the nf_isproperty flag (if any) from left, so that in case it  }
        {     is a property which refers to a field without a setter call, we will not get }
        {     an error about trying to pass a property as a var parameter                  }
        exclude(left.flags,nf_isproperty);
        hp:=CCallParaNode.create(CTypeConvNode.create_internal(right,voidpointertype),
            CCallParaNode.create(CTypeConvNode.create_internal(left,voidpointertype),
            nil));
        if needrtti then
          hp:=CCallParaNode.create(
            CAddrNode.create_internal(
              CRTTINode.create(TStoredDef(left.resultdef),initrtti,rdt_normal)),
            hp);
        result:=CCallNode.createintern(hs,hp);
        FirstPass(result);
        left:=nil;
        right:=nil;
      end;


    function TAssignmentNode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (assigntype = TAssignmentNode(p).assigntype);
      end;

{$ifdef state_tracking}
    function TAssignmentNode.track_state_pass(exec_known:boolean):boolean;

    var se:Tstate_entry;

    begin
        track_state_pass:=false;
        if exec_known then
            begin
                track_state_pass:=right.track_state_pass(exec_known);
                {Force a new resultdef pass.}
                right.resultdef:=nil;
                DoTypeCheckPass(right);
                TypeCheckPass(right);
                aktstate.store_fact(left.getcopy,right.getcopy);
            end
        else
            aktstate.delete_fact(left);
    end;
{$endif}


{$ifdef DEBUG_NODE_XML}
    procedure TAssignmentNode.XMLPrintNodeInfo(var T: Text);
      var
        i: TAssignmentNodeFlag;
        First: Boolean;
      begin
        inherited XMLPrintNodeInfo(T);
        First := True;
        for i in assignmentnodeflags do
          begin
            if First then
              begin
                Write(T, ' assignmentnodeflags="', i);
                First := False;
              end
            else
              Write(T, ',', i)
          end;
        if not First then
          Write(T, '"');
      end;


    procedure TAssignmentNode.XMLPrintNodeData(var T: Text);
      begin
        { For assignments, put the left and right branches on the same level for clarity }
        XMLPrintNode(T, Left);
        XMLPrintNode(T, Right);
        PrintNodeUnindent;
        WriteLn(T, PrintNodeIndention, '</', nodetype2str[nodetype], '>');
      end;
{$endif DEBUG_NODE_XML}


{*****************************************************************************
                           TARRAYCONSTRUCTORRANGENODE
*****************************************************************************}

    constructor TArrayConstructorRangeNode.create(l,r : TNode);

      begin
         inherited create(arrayconstructorrangen,l,r);
      end;

    function TArrayConstructorRangeNode.pass_typecheck:TNode;
      begin
        result:=nil;
        TypeCheckPass(left);
        TypeCheckPass(right);
        set_varstate(left,vs_read,[vsf_must_be_valid]);
        set_varstate(right,vs_read,[vsf_must_be_valid]);
        if CodeGenError then
         exit;
        resultdef:=left.resultdef;
      end;


    function TArrayConstructorRangeNode.pass_1 : TNode;
      begin
        result:=nil;
        CGMessage(parser_e_illegal_expression);
      end;


{****************************************************************************
                            TARRAYCONSTRUCTORNODE
*****************************************************************************}

    constructor TArrayConstructorNode.create(l,r : TNode);
      begin
         inherited create(arrayconstructorn,l,r);
         arrayconstructornodeflags:=[];
      end;


    constructor TArrayConstructorNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.getset(TPPUSet1(arrayconstructornodeflags));
      end;


    procedure TArrayConstructorNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putset(TPPUSet1(arrayconstructornodeflags));
      end;


    function TArrayConstructorNode.dogetcopy : TNode;
      var
         n : TArrayConstructorNode;
      begin
         n:=TArrayConstructorNode(inherited dogetcopy);
         n.arrayconstructornodeflags:=arrayconstructornodeflags;
         result:=n;
      end;


    function TArrayConstructorNode.has_range_node:boolean;
      var
        n : TArrayConstructorNode;
      begin
        result:=false;
        n:=self;
        while Assigned(n) do
          begin
            if Assigned(n.left) and (n.left.nodetype=arrayconstructorrangen) then
              begin
                result:=true;
                break;
              end;
            n:=TArrayConstructorNode(n.right);
          end;
      end;


    function TArrayConstructorNode.isempty:boolean;
      begin
        result:=not(Assigned(left)) and not(Assigned(right));
      end;


    function TArrayConstructorNode.pass_typecheck:TNode;
      var
        hdef  : TDef;
        hp    : TArrayConstructorNode;
        len   : LongInt;
        diff,
        varia : boolean;
        eq    : TEqualType;
        hnodetype : TNodeType;
      begin
        result:=nil;

      { are we allowing array constructor? Then convert it to a set.
        Do this only if we didn't convert the arrayconstructor yet. This
        is needed for the cases where the resultdef is forced for a second
        run }
        if not (acnf_allow_array_constructor in arrayconstructornodeflags) or has_range_node then
         begin
           hp:=TArrayConstructorNode(getcopy);
           arrayconstructor_to_set(TNode(hp));
           result:=hp;
           exit;
         end;

      { only pass left tree, right tree contains next construct if any }
        hdef:=nil;
        hnodetype:=errorn;
        len:=0;
        varia:=false;
        diff:=false;
        if Assigned(left) then
         begin
           hp:=self;
           while Assigned(hp) do
            begin
              TypeCheckPass(hp.left);
              set_varstate(hp.left,vs_read,[vsf_must_be_valid]);
              if (hdef=nil) then
                begin
                  hdef:=hp.left.resultdef;
                  hnodetype:=hp.left.nodetype;
                end
              else
               begin
                 { If we got a niln we don't know the type yet and need to take the
                   type of the next array element.
                   This is to handle things like [nil,tclass,tclass], see also tw8371 (PFV) }
                 if hnodetype=niln then
                   begin
                     eq:=compare_defs(hp.left.resultdef,hdef,hnodetype);
                     if eq>te_incompatible then
                       begin
                         hdef:=hp.left.resultdef;
                         hnodetype:=hp.left.nodetype;
                       end;
                   end
                 else
                   eq:=compare_defs(hdef,hp.left.resultdef,hp.left.nodetype);
                 { the element is not compatible with the previous element
                   which means the constructor is array of const }
                 if eq=te_incompatible then
                   diff:=true;
                 if (not varia) and (eq<te_equal) then
                   begin
                     { If both are integers we need to take the type that can hold both
                       defs }
                     if is_integer(hdef) and is_integer(hp.left.resultdef) then
                       begin
                         if is_in_limit(hdef,hp.left.resultdef) then
                           hdef:=hp.left.resultdef;
                       end
                     else
                       if (acnf_novariaallowed in arrayconstructornodeflags) then
                         varia:=true;
                   end;
               end;
              inc(len);
              hp:=TArrayConstructorNode(hp.right);
            end;
         end;
         { Set the type of empty or varia arrays to void. Also
           do this if the type is array of const/open array
           because those can't be used with setelementdef }
         if not Assigned(hdef) or
            varia or
            is_array_of_const(hdef) or
            is_open_array(hdef) then
           hdef:=voidtype;
         resultdef:=CArrayDef.create(0,len-1,s32inttype);
         include(TArrayDef(resultdef).arrayoptions,ado_IsConstructor);
         if varia then
           include(TArrayDef(resultdef).arrayoptions,ado_IsVariant);
         if diff then
           include(TArrayDef(resultdef).arrayoptions,ado_IsArrayOfConst);
         TArrayDef(resultdef).elementdef:=hdef;
      end;


    procedure TArrayConstructorNode.force_type(def:TDef);
      var
        hp : TArrayConstructorNode;
      begin
        TArrayDef(resultdef).elementdef:=def;
        include(TArrayDef(resultdef).arrayoptions,ado_IsConstructor);
        exclude(TArrayDef(resultdef).arrayoptions,ado_IsVariant);
        if Assigned(left) then
         begin
           hp:=self;
           while Assigned(hp) do
            begin
              inserttypeconv(hp.left,def);
              hp:=TArrayConstructorNode(hp.right);
            end;
         end;
      end;


    procedure TArrayConstructorNode.insert_typeconvs;
      var
        hp        : TArrayConstructorNode;
        dovariant : boolean;
      begin
        dovariant:=(acnf_forcevaria in arrayconstructornodeflags) or (ado_isvariant in TArrayDef(resultdef).arrayoptions);
        { only pass left tree, right tree contains next construct if any }
        if Assigned(left) then
         begin
           hp:=self;
           while Assigned(hp) do
            begin
              TypeCheckPass(hp.left);
              { Insert typeconvs for array of const }
              if dovariant then
                { at this time C varargs are no longer an arrayconstructornode }
                insert_varargstypeconv(hp.left,false);
              hp:=TArrayConstructorNode(hp.right);
            end;
         end;
      end;


    function TArrayConstructorNode.pass_1 : TNode;
      var
        hp : TArrayConstructorNode;
        do_variant:boolean;
      begin
        do_variant:=(acnf_forcevaria in arrayconstructornodeflags) or (ado_isvariant in TArrayDef(resultdef).arrayoptions);
        result:=nil;
        { Insert required type convs, this must be
          done in pass 1, because the call must be
          typecheckpassed already }
        if Assigned(left) then
          begin
            insert_typeconvs;
            { call firstpass for all nodes }
            hp:=self;
            while Assigned(hp) do
              begin
                if hp.left<>nil then
                  begin
                    {This check is pessimistic; a call will happen depending
                     on the location in which the elements will be found in
                     pass 2.}
                    if not do_variant then
                      include(CurrentProcInfo.flags,pi_do_call);
                    FirstPass(hp.left);
                  end;
                hp:=TArrayConstructorNode(hp.right);
              end;
          end;
        { set the elementdef to the correct type in case of a variant array }
        if do_variant then
          TArrayDef(resultdef).elementdef:=search_system_type('TVARREC').typedef;
        expectloc:=LOC_CREFERENCE;

        inc(CurrentProcInfo.estimatedtempsize,(TArrayDef(resultdef).highrange+1)*TArrayDef(resultdef).elementdef.size);
      end;


    function TArrayConstructorNode.docompare(p: TNode): boolean;
      begin
        docompare:=inherited docompare(p);
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TArrayConstructorNode.XMLPrintNodeInfo(var T: Text);
      var
        i: TArrayConstructorNodeFlag;
        First: Boolean;
      begin
        inherited XMLPrintNodeInfo(T);
        First := True;
        for i in arrayconstructornodeflags do
          begin
            if First then
              begin
                Write(T, ' arrayconstructornodeflags="', i);
                First := False;
              end
            else
              Write(T, ',', i)
          end;
        if not First then
          Write(T, '"');
      end;
{$endif DEBUG_NODE_XML}

{*****************************************************************************
                              TTYPENODE
*****************************************************************************}

    constructor TTypeNode.create(def:TDef);
      begin
         inherited create(typen);
         typedef:=def;
         typesym:=def.typesym;
         allowed:=false;
         helperallowed:=false;
      end;


    constructor TTypeNode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.getderef(typedefderef);
        ppufile.getderef(typesymderef);
        allowed:=ppufile.getboolean;
        helperallowed:=ppufile.getboolean;
      end;


    procedure TTypeNode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putderef(typedefderef);
        ppufile.putderef(typesymderef);
        ppufile.putboolean(allowed);
        ppufile.putboolean(helperallowed);
      end;


    procedure TTypeNode.buildderefimpl;
      begin
        inherited buildderefimpl;
        typedefderef.build(typedef);
        typesymderef.build(typesym);
      end;


    procedure TTypeNode.derefimpl;
      begin
        inherited derefimpl;
        typedef:=TDef(typedefderef.resolve);
        typesym:=TSym(typesymderef.resolve);
      end;


    function TTypeNode.pass_typecheck:TNode;
      begin
        result:=nil;
        resultdef:=typedef;
        { check if it's valid }
        if typedef.typ = errordef then
          CGMessage(parser_e_illegal_expression);
      end;


    function TTypeNode.pass_1 : TNode;
      begin
         result:=nil;
         expectloc:=LOC_VOID;
         { a typenode can't generate code, so we give here
           an error. Else it'll be an abstract error in pass_generate_code.
           Only when the allowed flag is set we don't generate
           an error }
         if not allowed then
           CGMessage(parser_e_no_type_not_allowed_here);
         if not helperallowed and is_objectpascal_helper(typedef) then
           CGMessage(parser_e_no_category_as_types);
      end;


    function TTypeNode.dogetcopy : TNode;
      var
         n : TTypeNode;
      begin
         n:=TTypeNode(inherited dogetcopy);
         n.allowed:=allowed;
         n.typedef:=typedef;
         n.typesym:=typesym;
         n.helperallowed:=helperallowed;
         result:=n;
      end;


    function TTypeNode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (typedef=TTypeNode(p).typedef) and
          (typesym=TTypeNode(p).typesym) and
          (allowed=TTypeNode(p).allowed) and
          (helperallowed=TTypeNode(p).helperallowed);
      end;


{*****************************************************************************
                              TRTTINODE
*****************************************************************************}


    constructor TRTTINode.create(def:TStoredDef;rt:TRTTIType;dt:Trttidatatype);
      begin
         inherited create(rttin);
         rttidef:=def;
         rttitype:=rt;
         rttidatatype:=dt;
      end;


    constructor TRTTINode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.getderef(rttidefderef);
        rttitype:=TRTTIType(ppufile.getbyte);
        rttidatatype:=trttidatatype(ppufile.getbyte);
      end;


    procedure TRTTINode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putderef(rttidefderef);
        ppufile.putbyte(byte(rttitype));
        ppufile.putbyte(byte(rttidatatype));
      end;


    procedure TRTTINode.buildderefimpl;
      begin
        inherited buildderefimpl;
        rttidefderef.build(rttidef);
      end;


    procedure TRTTINode.derefimpl;
      begin
        inherited derefimpl;
        rttidef:=TStoredDef(rttidefderef.resolve);
      end;


    function TRTTINode.dogetcopy : TNode;
      var
         n : TRTTINode;
      begin
         n:=TRTTINode(inherited dogetcopy);
         n.rttidef:=rttidef;
         n.rttitype:=rttitype;
         n.rttidatatype:=rttidatatype;
         result:=n;
      end;


    function TRTTINode.pass_typecheck:TNode;
      begin
        { rtti information will be returned as a void pointer }
        result:=nil;
        resultdef:=voidpointertype;
      end;


    function TRTTINode.pass_1 : TNode;
      begin
        result:=nil;
        expectloc:=LOC_CREFERENCE;
      end;


    function TRTTINode.docompare(p: TNode): boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (rttidef = TRTTINode(p).rttidef) and
          (rttitype = TRTTINode(p).rttitype) and
          (rttidatatype = TRTTINode(p).rttidatatype);
      end;

end.
