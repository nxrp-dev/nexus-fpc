{
    Copyright (c) 2000-2002 by Florian Klaempfl

    Type checking and register allocation for type converting nodes

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
unit ncnv;

{$i fpcdefs.inc}

interface

    uses
       tpcompilerreal,
       node,
       symtype,
       defutil,defcmp,
       nld
       ;

    type
       ttypeconvnodeflag = (
          { the typeconvnode is a proc_2_procvar, generated internally by an
            address operator, such as @proc, Addr(proc), Ofs(proc) or Seg(proc),
            which is then going to be converted to a void pointer. Why does it
            matter? Because, on i8086 far code memory models you're allowed to
            take the address of a _near_ procedure as a void pointer (which the
            @ operator does in TP mode), but not as a procvar (in that case the
            procedure must be far). }
          tcnf_proc_2_procvar_2_voidpointer,
          { proc_2_procvar, generated internally by Ofs() }
          tcnf_proc_2_procvar_get_offset_only
       );
       ttypeconvnodeflags = set of ttypeconvnodeflag;

       ttypeconvnode = class(TUnaryNode)
          totypedef   : TDef;
          totypedefderef : TDeref;
          convtype : tconverttype;
          convnodeflags : ttypeconvnodeflags;
          warn_pointer_to_signed,
          assignment_side: boolean;
          constructor create(node : TNode;def:TDef);virtual;
          constructor create_explicit(node : TNode;def:TDef);
          constructor create_internal(node : TNode;def:TDef);
          constructor create_proc_to_procvar(node : TNode);
          constructor ppuload(t:TNodeType;ppufile:TCompilerPPUFile);override;
          procedure ppuwrite(ppufile:TCompilerPPUFile);override;
          procedure buildderefimpl;override;
          procedure derefimpl;override;
          function dogetcopy : TNode;override;
          procedure printnodeinfo(var t : text);override;
{$ifdef DEBUG_NODE_XML}
          procedure XMLPrintNodeInfo(var T: Text); override;
{$endif DEBUG_NODE_XML}
          procedure convert_deferred_stmt_expr;
          function pass_1 : TNode;override;
          function pass_typecheck:TNode;override;
          function simplify(forinline : boolean):TNode; override;
          procedure mark_write;override;
          function docompare(p: TNode) : boolean; override;
          function retains_value_location:boolean;
          function assign_allowed:boolean;
          procedure second_call_helper(c : tconverttype);
          { always called before any other type conversion checks. If it
            returns true, the type conversion is ok and no further checks/
            handling are required. }
          function target_specific_general_typeconv: boolean;virtual;
          { called in case of a valid explicit type conversion. Can be used to
            replace this explicit type conversion with a different node, or to
            reject it after all }
          function target_specific_explicit_typeconv: boolean;virtual;

          { called when inserttypeconv is used to convert to a def that is equal
            according to compare_defs() }
          class function target_specific_need_equal_typeconv(fromdef, todef: TDef): boolean; virtual;
       protected
          function typecheck_int_to_int : TNode; virtual;
          function typecheck_cord_to_pointer : TNode; virtual;
          function typecheck_chararray_to_string : TNode; virtual;
          function typecheck_string_to_chararray : TNode; virtual;
          function typecheck_string_to_string : TNode; virtual;
          function typecheck_char_to_string : TNode; virtual;
          function typecheck_char_to_chararray : TNode; virtual;
          function typecheck_int_to_real : TNode; virtual;
          function typecheck_real_to_real : TNode; virtual;
          function typecheck_real_to_currency : TNode; virtual;
          function typecheck_cchar_to_pchar : TNode; virtual;
          function typecheck_cstring_to_pchar : TNode; virtual;
          function typecheck_cstring_to_int : TNode; virtual;
          function typecheck_char_to_char : TNode; virtual;
          function typecheck_arrayconstructor_to_set : TNode; virtual;
          function typecheck_set_to_set : TNode; virtual;
          function typecheck_pchar_to_string : TNode; virtual;
          function typecheck_interface_to_string : TNode; virtual;
          function typecheck_interface_to_guid : TNode; virtual;
          function typecheck_dynarray_to_openarray : TNode; virtual;
          function typecheck_pwchar_to_string : TNode; virtual;
          function typecheck_variant_to_dynarray : TNode; virtual;
          function typecheck_dynarray_to_variant : TNode; virtual;
          function typecheck_variant_to_enum : TNode; virtual;
          function typecheck_enum_to_variant : TNode; virtual;
          function typecheck_proc_to_procvar : TNode; virtual;
          function typecheck_variant_to_interface : TNode; virtual;
          function typecheck_interface_to_variant : TNode; virtual;
          function typecheck_array_2_dynarray : TNode; virtual;
          function typecheck_elem_2_openarray : TNode; virtual;
          function typecheck_arrayconstructor_to_dynarray : TNode; virtual;
          function typecheck_arrayconstructor_to_array : TNode; virtual;
          function typecheck_anonproc_2_funcref : TNode; virtual;
          function typecheck_procvar_2_funcref : TNode; virtual;
       private
          function _typecheck_int_to_int : TNode;
          function _typecheck_cord_to_pointer : TNode;
          function _typecheck_chararray_to_string : TNode;
          function _typecheck_string_to_chararray : TNode;
          function _typecheck_string_to_string : TNode;
          function _typecheck_char_to_string : TNode;
          function _typecheck_char_to_chararray : TNode;
          function _typecheck_int_to_real : TNode;
          function _typecheck_real_to_real : TNode;
          function _typecheck_real_to_currency : TNode;
          function _typecheck_cchar_to_pchar : TNode;
          function _typecheck_cstring_to_pchar : TNode;
          function _typecheck_cstring_to_int : TNode;
          function _typecheck_char_to_char : TNode;
          function _typecheck_arrayconstructor_to_set : TNode;
          function _typecheck_set_to_set : TNode;
          function _typecheck_pchar_to_string : TNode;
          function _typecheck_interface_to_string : TNode;
          function _typecheck_interface_to_guid : TNode;
          function _typecheck_dynarray_to_openarray : TNode;
          function _typecheck_pwchar_to_string : TNode;
          function _typecheck_variant_to_dynarray : TNode;
          function _typecheck_dynarray_to_variant : TNode;
          function _typecheck_variant_to_enum : TNode;
          function _typecheck_enum_to_variant : TNode;
          function _typecheck_proc_to_procvar : TNode;
          function _typecheck_variant_to_interface : TNode;
          function _typecheck_interface_to_variant : TNode;
          function _typecheck_array_2_dynarray : TNode;
          function _typecheck_elem_2_openarray : TNode;
          function _typecheck_arrayconstructor_to_dynarray : TNode;
          function _typecheck_arrayconstructor_to_array : TNode;
          function _typecheck_anonproc_to_funcref : TNode;
          function _typecheck_procvar_to_funcref : TNode;
       protected
          function first_int_to_int : TNode;virtual;
          function first_cstring_to_pchar : TNode;virtual;
          function first_cstring_to_int : TNode;virtual;
          function first_string_to_chararray : TNode;virtual;
          function first_char_to_string : TNode;virtual;
          function first_char_to_chararray : TNode; virtual;
          function first_nothing : TNode;virtual;
          function first_array_to_pointer : TNode;virtual;
          function first_int_to_real : TNode;virtual;
          function first_real_to_real : TNode;virtual;
          function first_pointer_to_array : TNode;virtual;
          function first_cchar_to_pchar : TNode;virtual;
          function first_bool_to_int : TNode;virtual;
          function first_int_to_bool : TNode;virtual;
          function first_bool_to_bool : TNode;virtual;
          function first_proc_to_procvar : TNode;virtual;
          function first_nil_to_methodprocvar : TNode;virtual;
          function first_set_to_set : TNode;virtual;
          function first_cord_to_pointer : TNode;virtual;
          function first_ansistring_to_pchar : TNode;virtual;
          function first_arrayconstructor_to_set : TNode;virtual;
          function first_class_to_intf : TNode;virtual;
          function first_char_to_char : TNode;virtual;
          function first_string_to_string : TNode;virtual;
          function first_call_helper(c : tconverttype) : TNode;
          function typecheck_call_helper(c : tconverttype) : TNode;
       private
          { these wrapper are necessary, because the first_* stuff is called }
          { through a table. Without the wrappers override wouldn't have     }
          { any effect                                                       }
          function _first_int_to_int : TNode;
          function _first_cstring_to_pchar : TNode;
          function _first_cstring_to_int : TNode;
          function _first_string_to_chararray : TNode;
          function _first_char_to_string : TNode;
          function _first_char_to_chararray : TNode;
          function _first_nothing : TNode;
          function _first_array_to_pointer : TNode;
          function _first_int_to_real : TNode;
          function _first_real_to_real: TNode;
          function _first_pointer_to_array : TNode;
          function _first_cchar_to_pchar : TNode;
          function _first_bool_to_int : TNode;
          function _first_int_to_bool : TNode;
          function _first_bool_to_bool : TNode;
          function _first_proc_to_procvar : TNode;
          function _first_nil_to_methodprocvar : TNode;
          function _first_cord_to_pointer : TNode;
          function _first_ansistring_to_pchar : TNode;
          function _first_arrayconstructor_to_set : TNode;
          function _first_class_to_intf : TNode;
          function _first_char_to_char : TNode;
          function _first_set_to_set : TNode;
          function _first_string_to_string : TNode;

          procedure _second_int_to_int;virtual;
          procedure _second_string_to_string;virtual;
          procedure _second_cstring_to_pchar;virtual;
          procedure _second_cstring_to_int;virtual;
          procedure _second_string_to_chararray;virtual;
          procedure _second_array_to_pointer;virtual;
          procedure _second_pointer_to_array;virtual;
          procedure _second_chararray_to_string;virtual;
          procedure _second_char_to_string;virtual;
          procedure _second_int_to_real;virtual;
          procedure _second_real_to_real;virtual;
          procedure _second_cord_to_pointer;virtual;
          procedure _second_proc_to_procvar;virtual;
          procedure _second_nil_to_methodprocvar;virtual;
          procedure _second_bool_to_int;virtual;
          procedure _second_int_to_bool;virtual;
          procedure _second_bool_to_bool;virtual;
          procedure _second_set_to_set;virtual;
          procedure _second_ansistring_to_pchar;virtual;
          procedure _second_class_to_intf;virtual;
          procedure _second_char_to_char;virtual;
          procedure _second_elem_to_openarray;virtual;
          procedure _second_nothing; virtual;

        protected
          procedure second_int_to_int;virtual;abstract;
          procedure second_string_to_string;virtual;abstract;
          procedure second_cstring_to_pchar;virtual;abstract;
          procedure second_cstring_to_int;virtual;abstract;
          procedure second_string_to_chararray;virtual;abstract;
          procedure second_array_to_pointer;virtual;abstract;
          procedure second_pointer_to_array;virtual;abstract;
          procedure second_chararray_to_string;virtual;abstract;
          procedure second_char_to_string;virtual;abstract;
          procedure second_int_to_real;virtual;abstract;
          procedure second_real_to_real;virtual;abstract;
          procedure second_cord_to_pointer;virtual;abstract;
          procedure second_proc_to_procvar;virtual;abstract;
          procedure second_nil_to_methodprocvar;virtual;abstract;
          procedure second_bool_to_int;virtual;abstract;
          procedure second_int_to_bool;virtual;abstract;
          procedure second_bool_to_bool;virtual;abstract;
          procedure second_set_to_set;virtual;abstract;
          procedure second_ansistring_to_pchar;virtual;abstract;
          procedure second_class_to_intf;virtual;abstract;
          procedure second_char_to_char;virtual;abstract;
          procedure second_elem_to_openarray;virtual;abstract;
          procedure second_nothing; virtual;abstract;
       end;
       ttypeconvnodeclass = class of ttypeconvnode;

       { common functionality of as-nodes and is-nodes }
       tasisnode = class(TBinaryNode)
          protected
           { if non-standard usage of as-nodes is possible, targets can override
           this method and return true in case the conditions are fulfilled }
          function target_specific_typecheck: boolean;virtual;
         public
          function pass_typecheck:TNode;override;
       end;

       tasnode = class(tasisnode)
          { as nodes cannot be translated directly into call nodes bcause:

            When using -CR, explicit class typecasts are replaced with as-nodes to perform
            class type checking. The problem is that if a typecasted class instance is
            passed as a var-parameter, then you cannot replace it with a function call. So the as-node
            a) call the as helper to perform the type checking
            b) still pass the original instance as parameter to var-parameters
            (and in general: to return it as the result of the as-node)

            so the call field is required
          }
          call: TNode;
          constructor create(l,r : TNode);virtual;
          constructor create_internal(l,r : TNode);virtual;
          function pass_1 : TNode;override;
          function dogetcopy: TNode;override;
          function docompare(p: TNode): boolean; override;
          destructor destroy; override;
       end;
       tasnodeclass = class of tasnode;

       tisnode = class(tasisnode)
          constructor create(l,r : TNode);virtual;
          constructor create_internal(l,r : TNode);virtual;
          function pass_1 : TNode;override;
          procedure pass_generate_code;override;
       end;
       tisnodeclass = class of tisnode;

    var
       ctypeconvnode : ttypeconvnodeclass = ttypeconvnode;
       casnode : tasnodeclass = tasnode;
       cisnode : tisnodeclass=tisnode;

    procedure inserttypeconv(var p:TNode;def:TDef);
    procedure inserttypeconv_explicit(var p:TNode;def:TDef);
    procedure inserttypeconv_internal(var p:TNode;def:TDef);
    procedure arrayconstructor_to_set(var p : TNode);inline;
    function arrayconstructor_to_set(p:TNode;freep:boolean):TNode;
    function arrayconstructor_can_be_set(p:TNode):boolean;
    procedure insert_varargstypeconv(var p : TNode; iscvarargs: boolean);

    function maybe_global_proc_to_nested(var fromnode: TNode; todef: TDef): boolean;


implementation

   uses
      globtype,systems,constexp,compinnr,
      cutils,verbose,globals,widestr,ppu,
      symconst,symdef,symsym,symcpu,symtable,
      ncon,ncal,nset,nadd,nmem,nmat,nbas,nutils,ninl,nflw,
      psub,
      cgbase,procinfo,
      htypechk,blockutl,pparautl,procdefutil,pass_1,cpuinfo;


{*****************************************************************************
                                   Helpers
*****************************************************************************}
    type
      ttypeconvnodetype = (tct_implicit,tct_explicit,tct_internal);

    procedure do_inserttypeconv(var p: TNode;def: TDef; convtype: ttypeconvnodetype);

      begin
        if not assigned(p.resultdef) then
         begin
           TypeCheckPass(p);
           if CodeGenError then
            exit;
         end;

        { don't insert superfluous type conversions, but
          in case of bitpacked accesses, the original type must
          remain too so that not too many/few bits are laoded.

          Also, in case the deftyp changes, don't ignore because lots of code
          expects that if the resultdef is set to e.g. stringdef, it remains
          that way (e.g., in case of Java where java_jlstring equals
          unicodestring according to equal_defs, but an add node for strings
          still expects the resultdef of the node to be a stringdef) }
        if equal_defs(p.resultdef,def) and
           (p.resultdef.typ=def.typ) and
           not is_bitpacked_access(p) and
           { result of a hardware vector node must remain a hardware
             vector of the same kind (will match to tc_equal with regular arrays
             of same dimension/eledef) }
           not((p.resultdef.typ=arraydef) and
               TArrayDef(p.resultdef).is_hwvector) and
           ((p.blocktype=bt_const) or
            not ctypeconvnode.target_specific_need_equal_typeconv(p.resultdef,def)) then
          begin
            { don't replace encoded string constants to rawbytestring encoding.
              preserve the codepage }
            if not (is_rawbytestring(def) and (p.nodetype=stringconstn)) then
              p.resultdef:=def
          end
        else
         begin
           case convtype of
             tct_implicit:
               p:=ctypeconvnode.create(p,def);
             tct_explicit:
               p:=ctypeconvnode.create_explicit(p,def);
             tct_internal:
               p:=ctypeconvnode.create_internal(p,def);
           end;
           if not (nf_internal in p.flags) and is_currency(def) then
             Include(p.flags, nf_is_currency);
           p.fileinfo:=ttypeconvnode(p).left.fileinfo;
           TypeCheckPass(p);
         end;
      end;


    procedure inserttypeconv(var p:TNode;def:TDef);

      begin
        do_inserttypeconv(p,def,tct_implicit);
      end;


    procedure inserttypeconv_explicit(var p: TNode; def: TDef);

      begin
        do_inserttypeconv(p,def,tct_explicit);
      end;

    procedure inserttypeconv_internal(var p:TNode;def:TDef);

      begin
        do_inserttypeconv(p,def,tct_internal);
      end;


{*****************************************************************************
                    Array constructor to Set Conversion
*****************************************************************************}

    procedure arrayconstructor_to_set(var p : TNode);
      begin
        p:=arrayconstructor_to_set(p,true);
      end;

    function arrayconstructor_to_set(p:TNode;freep:boolean):TNode;
      var
        constp      : tsetconstnode;
        p2,p3,p4    : TNode;
        hdef        : TDef;
        constset    : PConstSet;
        constsetlo,
        constsethi  : TConstExprInt;

        procedure update_constsethi(def:TDef; maybetruncenumrange: boolean);
          begin
            if (def.typ=orddef) and
               ((TOrdDef(def).high>=constsethi) or
                (TOrdDef(def).low <=constsetlo)) then
              begin
                if TOrdDef(def).ordtype=uwidechar then
                  begin
                    constsethi:=255;
                    constsetlo:=0;
                    if hdef=nil then
                      hdef:=def;
                  end
                else
                  begin
                    if (TOrdDef(def).high>=constsethi) then
                      constsethi:=TOrdDef(def).high;
                    if (TOrdDef(def).low<=constsetlo) then
                      constsetlo:=TOrdDef(def).low;
                    if hdef=nil then
                      begin
                         if (constsethi>255) or
                            (TOrdDef(def).low<0) then
                           hdef:=u8inttype
                         else
                           hdef:=def;
                      end;
                    if constsethi>255 then
                      constsethi:=255;
                    if constsetlo<0 then
                      constsetlo:=0;
                  end;
              end
            else if (def.typ=enumdef) and
                    ((TEnumDef(def).max>=constsethi) or
                     (TEnumDef(def).min<=constsetlo)) then
              begin
                 if hdef=nil then
                   hdef:=def;
                 if (TEnumDef(def).max>=constsethi) then
                   constsethi:=TEnumDef(def).max;
                 if (TEnumDef(def).min<=constsetlo) then
                   constsetlo:=TEnumDef(def).min;
                 { for constant set elements, delphi allows the usage of elements of enumerations which
                   have value>255 if there is no element with a value > 255 used }
                 if (maybetruncenumrange) then
                   begin
                    if constsethi>255 then
                      constsethi:=255;
                    if constsetlo<0 then
                      constsetlo:=0;
                   end;
              end;
          end;

        procedure do_set(pos : longint);
          begin
            if (pos and not $ff)<>0 then
              begin
                Message(parser_e_illegal_set_expr);
                exit;
              end;
            if pos>constsethi then
             constsethi:=pos;
            if pos<constsetlo then
             constsetlo:=pos;
            if pos in constset^ then
              Message(parser_e_illegal_set_expr);
            include(constset^,pos);
          end;

      var
        l : Longint;
        lr,hr : TConstExprInt;
        hp : tarrayconstructornode;
        oldfilepos: TFilePosInfo;
        first: Boolean;
      begin
        { keep in sync with arrayconstructor_can_be_set }
        if p.nodetype<>arrayconstructorn then
          internalerror(200205105);
        { A generic body is parsed again when specializing. Do not lower a set
          constructor before its element types are known: even a fixed set
          destination can contain expressions whose type is a parameter. }
        if assigned(CurrentProcInfo) and
           (df_generic in CurrentProcInfo.procdef.defoptions) then
          begin
            hp:=tarrayconstructornode(p);
            while assigned(hp) and assigned(hp.left) do
              begin
                TypeCheckPass(hp.left);
                if hp.left.nodetype=arrayconstructorrangen then
                  begin
                    p2:=tarrayconstructorrangenode(hp.left).left;
                    p3:=tarrayconstructorrangenode(hp.left).right;
                  end
                else
                  begin
                    p2:=hp.left;
                    p3:=nil;
                  end;
                if is_typeparam(p2.resultdef) or
                   (assigned(p3) and is_typeparam(p3.resultdef)) then
                  begin
                    { Keep a set-typed placeholder so surrounding set operators
                      can still be checked while parsing the template. }
                    new(constset);
                    constset^:=[];
                    constp:=csetconstnode.create(nil,csetdef.create(nil,0,0,true));
                    constp.value_set:=constset;
                    result:=constp;
                    TypeCheckPass(result);
                    if freep then
                      p.free;
                    exit;
                  end;
                hp:=tarrayconstructornode(hp.right);
              end;
          end;
        new(constset);
        constset^:=[];
        hdef:=nil;
        { make sure to set constsetlo correctly for empty sets }
        if assigned(tarrayconstructornode(p).left) then
          constsetlo:=high(aint)
        else
          constsetlo:=0;
        constsethi:=0;
        constp:=csetconstnode.create(nil,hdef);
        constp.value_set:=constset;
        result:=constp;
        hp:=tarrayconstructornode(p);
        if assigned(hp.left) then
         begin
           first:=true;
           while assigned(hp) do
            begin
              p4:=nil; { will contain the tree to create the set }
              { split a range into p2 and p3 }
              if hp.left.nodetype=arrayconstructorrangen then
               begin
                 p2:=tarrayconstructorrangenode(hp.left).left;
                 p3:=tarrayconstructorrangenode(hp.left).right;
                 tarrayconstructorrangenode(hp.left).left:=nil;
                 tarrayconstructorrangenode(hp.left).right:=nil;
               end
              else
               begin
                 p2:=hp.left;
                 hp.left:=nil;
                 p3:=nil;
               end;
              TypeCheckPass(p2);
              set_varstate(p2,vs_read,[vsf_must_be_valid]);
              if assigned(p3) then
                begin
                  TypeCheckPass(p3);
                  set_varstate(p3,vs_read,[vsf_must_be_valid]);
                end;
              if CodeGenError then
               break;
              oldfilepos:=CurrentFilePos;
              CurrentFilePos:=p2.fileinfo;
              case p2.resultdef.typ of
                enumdef,
                orddef:
                  begin
                    { widechars are not yet supported }
                    if is_widechar(p2.resultdef) then
                      begin
                        if block_type<>bt_const then
                          inserttypeconv(p2,cansichartype);
                        if (p2.nodetype<>ordconstn) and not (m_default_unicodestring in CurrentSettings.modeswitches) then
                          incompatibletypes(cwidechartype,cansichartype);
                      end;

                    getrange(p2.resultdef,lr,hr);
                    if assigned(p3) then
                     begin
                       if is_widechar(p3.resultdef) then
                         begin
                           if block_type<>bt_const then
                             inserttypeconv(p3,cansichartype);
                           if (p3.nodetype<>ordconstn) and not (m_default_unicodestring in CurrentSettings.modeswitches) then
                             begin
                               CurrentFilePos:=p3.fileinfo;
                               incompatibletypes(cwidechartype,cansichartype);
                             end;
                         end;
                       { this isn't good, you'll get problems with
                         type t010 = 0..10;
                              ts = set of t010;
                         var  s : ts;b : t010
                         begin  s:=[1,2,b]; end.
                       if is_integer(p3^.resultdef) then
                        begin
                          inserttypeconv(p3,u8bitdef);
                        end;
                       }
                       if assigned(hdef) and not(equal_defs(hdef,p3.resultdef)) then
                         begin
                            CGMessagePos(p3.fileinfo,type_e_typeconflict_in_set);
                         end
                       else
                         begin
                           if (p2.nodetype=ordconstn) and (p3.nodetype=ordconstn) then
                            begin
                               if not(is_integer(p3.resultdef)) then
                                 begin
                                   if not(assigned(hdef)) and first then
                                     hdef:=p3.resultdef;
                                 end
                               else
                                 begin
                                   inserttypeconv(p3,u8inttype);
                                   inserttypeconv(p2,u8inttype);
                                 end;

                              if tordconstnode(p2).value.svalue>tordconstnode(p3).value.svalue then
                                CGMessagePos(p2.fileinfo,type_w_empty_constant_range_set);
                              for l:=tordconstnode(p2).value.svalue to tordconstnode(p3).value.svalue do
                                do_set(l);
                              p2.free;
                              p2 := nil;
                              p3.free;
                              p3 := nil;
                            end
                           else
                            begin
                              update_constsethi(p2.resultdef,false);
                              inserttypeconv(p2,hdef);

                              update_constsethi(p3.resultdef,false);
                              inserttypeconv(p3,hdef);

                              if assigned(hdef) then
                                inserttypeconv(p3,hdef)
                              else if first then
                                hdef:=p3.resultdef
                              else
                                inserttypeconv(p3,u8inttype);
                              p4:=csetelementnode.create(p2,p3);
                            end;
                         end;
                     end
                    else
                     begin
                       { Single value }
                       if p2.nodetype=ordconstn then
                        begin
                          if assigned(hdef) then
                            inserttypeconv(p2,hdef)
                          else if not(is_integer(p2.resultdef)) and first then
                            hdef:=p2.resultdef
                          else
                            inserttypeconv(p2,u8inttype);

                          if not(is_integer(p2.resultdef)) then
                            update_constsethi(p2.resultdef,true);

                          do_set(tordconstnode(p2).value.svalue);
                          p2.free;
                          p2 := nil;
                        end
                       else
                        begin
                          update_constsethi(p2.resultdef,false);

                          if assigned(hdef) then
                            inserttypeconv(p2,hdef)
                          else if not(is_integer(p2.resultdef)) and first then
                            hdef:=p2.resultdef
                          else
                            inserttypeconv(p2,u8inttype);

                          p4:=csetelementnode.create(p2,nil);
                        end;
                     end;
                  end;
                else
                  CGMessage(type_e_ordinal_expr_expected);
              end;
              { insert the set creation tree }
              if assigned(p4) then
               result:=caddnode.create(addn,result,p4);
              { load next and dispose current node }
              p2:=hp;
              hp:=tarrayconstructornode(tarrayconstructornode(p2).right);
              tarrayconstructornode(p2).right:=nil;
              if freep then
                p2.free; // no nil needed
              CurrentFilePos:=oldfilepos;
              first:=false;
            end;
          if (hdef=nil) then
            hdef:=u8inttype;
         end
        else
         begin
           { empty set [], only remove node }
           if freep then
             p.free; // no nil needed
         end;
        { set the initial set type }
        constp.resultdef:=csetdef.create(hdef,constsetlo.svalue,constsethi.svalue,true);
        { determine the resultdef for the tree }
        TypeCheckPass(result);
      end;


    function arrayconstructor_can_be_set(p:TNode):boolean;
      var
        p1,p2 : TNode;
        hdef : TDef;
      begin
        { keep in sync with arrayconstructor_to_set }
        if not assigned(p) then
          internalerror(2015050401);
        if not assigned(tarrayconstructornode(p).left) then
          begin
            if assigned(tarrayconstructornode(p).right) then
              internalerror(2015050103);
            result:=true;
          end
        else
          begin
            result:=false;

            hdef:=nil;

            while assigned(p) do
              begin
                if tarrayconstructornode(p).left.nodetype=arrayconstructorrangen then
                  begin
                    p1:=tarrayconstructorrangenode(tarrayconstructornode(p).left).left;
                    p2:=tarrayconstructorrangenode(tarrayconstructornode(p).left).right;
                  end
                else
                  begin
                    p1:=tarrayconstructornode(p).left;
                    p2:=nil;
                  end;

                case p1.resultdef.typ of
                  orddef,
                  enumdef:
                    begin
                      if is_widechar(p1.resultdef) then
                        begin
                          if p1.nodetype<>ordconstn then
                            exit
                          else if (tordconstnode(p1).value.uvalue>high(byte)) and not (m_default_unicodestring in CurrentSettings.modeswitches) then
                            exit;
                        end;

                      if assigned(p2) then
                        begin
                          if is_widechar(p2.resultdef) then
                            begin
                              if p2.nodetype<>ordconstn then
                                exit
                              else if (tordconstnode(p2).value.uvalue>high(byte)) and not (m_default_unicodestring in CurrentSettings.modeswitches) then
                                exit;
                            end;

                          { anything to exclude? }
                        end
                      else
                        begin
                          { anything to exclude? }
                        end;
                    end;
                  stringdef:
                    if p1.nodetype<>stringconstn then
                      exit
                    else if assigned(hdef) and not is_char(hdef) then
                      exit;
                  else
                    exit;
                end;

                p:=tarrayconstructornode(p).right;
              end;

            result:=true;
          end;
      end;


    procedure insert_varargstypeconv(var p : TNode; iscvarargs: boolean);
      begin
        { procvars without arguments in variant arrays are always called by
          Delphi }
        if not(iscvarargs) then
          maybe_call_procvar(p,true);
        if not(iscvarargs) and
           (p.nodetype=stringconstn) and
           { don't cast to AnsiString if already casted to Wide/UnicodeString, issue #18266 }
           (tstringconstnode(p).cst_type in [cst_conststring,cst_shortstring,cst_longstring]) then
          p:=ctypeconvnode.create_internal(p,getansistringdef)
        else
          case p.resultdef.typ of
            enumdef :
              p:=ctypeconvnode.create_internal(p,s32inttype);
            arraydef :
              begin
                if is_chararray(p.resultdef) then
                  p:=ctypeconvnode.create_internal(p,charpointertype)
                else
                  if is_widechararray(p.resultdef) then
                    p:=ctypeconvnode.create_internal(p,widecharpointertype)
                else
                  CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.typename);
              end;
            orddef :
              begin
                if is_integer(p.resultdef) and
                   not(is_64bitint(p.resultdef)) then
                  if not(m_delphi in CurrentSettings.modeswitches) then
                    p:=ctypeconvnode.create(p,s32inttype)
                  else
                    { delphi doesn't generate a range error when passing a
                      cardinal >= $80000000, but since these are seen as
                      longint on the callee side, this causes data loss;
                      as a result, we require an explicit longint()
                      typecast in FPC mode on the caller side if range
                      checking should be disabled, but not in Delphi mode }
                    p:=ctypeconvnode.create_internal(p,s32inttype)
                else if is_void(p.resultdef) then
                  CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.typename)
                else if iscvarargs and is_currency(p.resultdef)
                    and (CurrentSettings.fputype<>fpu_none) then
                  p:=ctypeconvnode.create(p,s64floattype);
              end;
            floatdef :
              if not(iscvarargs) then
                begin
                  if not(is_currency(p.resultdef)) then
                    p:=ctypeconvnode.create(p,pbestrealtype^);
                end
              else
                begin
                  if (is_constrealnode(p) and not(nf_explicit in p.flags)) or
                     ((TargetInfo.system=system_x86_64_win64) and is_extended(p.resultdef)) then
                    MessagePos(p.fileinfo,type_w_double_c_varargs);
                  if (TFloatDef(p.resultdef).floattype in [s32real,s64currency]) or
                     ((TargetInfo.system=system_x86_64_win64) and is_extended(p.resultdef)) or
                     (is_constrealnode(p) and
                      not(nf_explicit in p.flags)) then
                    p:=ctypeconvnode.create(p,s64floattype);
                end;
            procvardef :
              p:=ctypeconvnode.create(p,voidpointertype);
            stringdef:
              if iscvarargs then
                p:=ctypeconvnode.create(p,charpointertype);
            variantdef:
              if iscvarargs then
                CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.typename);
            { maybe warn in case it's not using "packrecords c"? }
            recorddef:
              if not iscvarargs then
                CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.typename);
            pointerdef:
              ;
            classrefdef:
              if iscvarargs then
                p:=ctypeconvnode.create(p,voidpointertype);
            objectdef :
              if is_objc_class_or_protocol(p.resultdef) then
                p:=ctypeconvnode.create(p,voidpointertype)
              else if iscvarargs or
                 is_object(p.resultdef) then
                CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.typename)
              else
            else
              CGMessagePos1(p.fileinfo,type_e_wrong_type_in_array_constructor,p.resultdef.typename);
          end;
        TypeCheckPass(p);
      end;


    { in FPC mode, @procname immediately has to be evaluated as a
      procvar. If procname is global, then this will be a global
      procvar. Since converting global procvars to local procvars is
      not allowed (see point d in defcmp.proc_to_procvar_equal()),
      this results in errors when passing global procedures to local
      procvar parameters or assigning them to nested procvars. The
      solution is to remove the (wrong) conversion to a global procvar,
      and instead insert a conversion to the local procvar type. }
    function maybe_global_proc_to_nested(var fromnode: TNode; todef: TDef): boolean;
      var
        hp: TNode;
      begin
        result:=false;
        if (m_nested_procvars in CurrentSettings.modeswitches) and
           not(m_tp_procvar in CurrentSettings.modeswitches) and
           (todef.typ=procvardef) and
           is_nested_pd(TProcVarDef(todef)) and
           (fromnode.nodetype=typeconvn) and
           (ttypeconvnode(fromnode).convtype=tc_proc_2_procvar) and
           not is_nested_pd(TProcVarDef(fromnode.resultdef)) and
           (proc_to_procvar_equal(TProcDef(ttypeconvnode(fromnode).left.resultdef),TProcVarDef(todef),false)>=te_convert_l1) then
          begin
            hp:=fromnode;
            fromnode:=ctypeconvnode.create_proc_to_procvar(ttypeconvnode(fromnode).left);
            ttypeconvnode(fromnode).totypedef:=todef;
            TypeCheckPass(fromnode);
            ttypeconvnode(hp).left:=nil;
            hp.free;
            hp := nil;
            result:=true;
          end;
      end;


    { similar as above, but for assigning @classtype.method to a
      procvar of object. pexpr.do_proc_call() stores the symtable of classtype
      in the loadnode so we can retrieve it here (rather than the symtable in
      which method was found, which may be a parent class) }
    function maybe_classmethod_to_methodprocvar(var fromnode: TNode; todef: TDef): boolean;
      var
        hp: TNode;
      begin
        result:=false;
        if not(m_tp_procvar in CurrentSettings.modeswitches) and
           (todef.typ=procvardef) and
           is_methodpointer(TProcVarDef(todef)) and
           (fromnode.nodetype=typeconvn) and
           (ttypeconvnode(fromnode).convtype=tc_proc_2_procvar) and
           is_methodpointer(fromnode.resultdef) and
           (po_classmethod in TProcVarDef(fromnode.resultdef).procoptions) and
           not(po_staticmethod in TProcVarDef(fromnode.resultdef).procoptions) and
           (proc_to_procvar_equal(TProcDef(ttypeconvnode(fromnode).left.resultdef),TProcVarDef(todef),false)>=te_convert_l1) then
          begin
            hp:=fromnode;
            fromnode:=ttypeconvnode(fromnode).left;
            if (fromnode.nodetype=loadn) and
               not assigned(tloadnode(fromnode).left) then
              tloadnode(fromnode).set_mp(cloadvmtaddrnode.create(ctypenode.create(TDef(tloadnode(fromnode).symtable.defowner))));
            fromnode:=ctypeconvnode.create_proc_to_procvar(fromnode);
            ttypeconvnode(fromnode).totypedef:=todef;
            TypeCheckPass(fromnode);
            ttypeconvnode(hp).left:=nil;
            hp.free;
            hp := nil;
            result:=true;
          end;
      end;

{*****************************************************************************
                           TTYPECONVNODE
*****************************************************************************}


    constructor ttypeconvnode.create(node : TNode;def:TDef);

      begin
         inherited create(typeconvn,node);
         convtype:=tc_none;
         convnodeflags:=[];
         totypedef:=def;
         if def=nil then
          internalerror(200103281);
         fileinfo:=node.fileinfo;
         {An attempt to convert the result of a floating point division
          (with the / operator) to an integer type will fail. Give a hint
          to use the div operator.}
         if (node.nodetype=slashn) and (def.typ=orddef) and not(is_currency(def)) then
           cgmessage(type_h_use_div_for_int);
         {In expressions like int64:=longint+longint, an integer overflow could be avoided
          by simply converting the operands to int64 first. Give a hint to do this.}
         if (node.nodetype in [addn,subn,muln]) and
            (def.typ=orddef) and (node.resultdef<>nil) and (node.resultdef.typ=orddef) and
            ((TOrdDef(node.resultdef).low>=TOrdDef(def).low) and (TOrdDef(node.resultdef).high<=TOrdDef(def).high)) and
            ((TOrdDef(node.resultdef).low>TOrdDef(def).low) or (TOrdDef(node.resultdef).high<TOrdDef(def).high)) then
           case node.nodetype of
             addn:
               cgmessage1(type_h_convert_add_operands_to_prevent_overflow,def.typename);
             subn:
               cgmessage1(type_h_convert_sub_operands_to_prevent_overflow,def.typename);
             muln:
               cgmessage1(type_h_convert_mul_operands_to_prevent_overflow,def.typename);
             else
               ;
           end;
      end;


    constructor ttypeconvnode.create_explicit(node : TNode;def:TDef);

      begin
         self.create(node,def);
         include(flags,nf_explicit);
      end;


    constructor ttypeconvnode.create_internal(node : TNode;def:TDef);

      begin
         self.create(node,def);
         { handle like explicit conversions }
         include(flags,nf_explicit);
         include(flags,nf_internal);
      end;


    constructor ttypeconvnode.create_proc_to_procvar(node : TNode);

      begin
         self.create(node,voidtype);
         convtype:=tc_proc_2_procvar;
      end;


    constructor ttypeconvnode.ppuload(t:TNodeType;ppufile:TCompilerPPUFile);
      begin
        inherited ppuload(t,ppufile);
        ppufile.getderef(totypedefderef);
        convtype:=tconverttype(ppufile.getbyte);
        ppufile.getset(tppuset1(convnodeflags));
      end;


    procedure ttypeconvnode.ppuwrite(ppufile:TCompilerPPUFile);
      begin
        inherited ppuwrite(ppufile);
        ppufile.putderef(totypedefderef);
        ppufile.putbyte(byte(convtype));
        ppufile.putset(tppuset1(convnodeflags));
      end;


    procedure ttypeconvnode.buildderefimpl;
      begin
        inherited buildderefimpl;
        totypedefderef.build(totypedef);
      end;


    procedure ttypeconvnode.derefimpl;
      begin
        inherited derefimpl;
        totypedef:=TDef(totypedefderef.resolve);
      end;


    function ttypeconvnode.dogetcopy : TNode;
      var
         n : ttypeconvnode;
      begin
         n:=ttypeconvnode(inherited dogetcopy);
         n.convtype:=convtype;
         n.convnodeflags:=convnodeflags;
         n.totypedef:=totypedef;
         n.assignment_side:=assignment_side;
         dogetcopy:=n;
      end;

    procedure ttypeconvnode.printnodeinfo(var t : text);
      var
        first: Boolean;
        i: ttypeconvnodeflag;
      begin
        inherited printnodeinfo(t);
        write(t,', totypedef = ',totypedef.GetTypeName);
        write(t,', convtype = ',convtype);
        write(t,', assignment_side = ',assignment_side);
        write(t,', convnodeflags = [');
        first:=true;
        for i:=low(ttypeconvnodeflag) to high(ttypeconvnodeflag) do
          if i in convnodeflags then
            begin
              if not first then
                write(t,',')
              else
                first:=false;
              write(t,i);
            end;
        write(t,']');
      end;

{$ifdef DEBUG_NODE_XML}
    procedure TTypeConvNode.XMLPrintNodeInfo(var T: Text);
      var
        First: Boolean;
        i: TTypeConvNodeFlag;
      begin
        inherited XMLPrintNodeInfo(T);
        Write(T,' convtype="', convtype);
        First := True;
        for i := Low(TTypeConvNodeFlag) to High(TTypeConvNodeFlag) do
          if i in ConvNodeFlags then
            begin
              if First then
                begin
                  Write(T, '" convnodeflags="', i);
                  First := False;
                end
              else
                Write(T, ',', i);
           end;

        { If no flags were printed, this is the closing " for convtype }
        Write(T, '"');
      end;
{$endif DEBUG_NODE_XML}

    function ttypeconvnode.typecheck_cord_to_pointer : TNode;

      begin
        result:=nil;
        if left.nodetype=ordconstn then
          begin
            if not(nf_explicit in flags) then
              if (tordconstnode(left).value.svalue=0) then
                CGMessage(type_w_zero_to_nil)
              else
                { in Delphi mode, these aren't caught in compare_defs_ext }
                IncompatibleTypes(left.resultdef,resultdef);
            result:=cpointerconstnode.create(TConstPtrUInt(tordconstnode(left).value.uvalue),resultdef);
          end
         else
          internalerror(200104023);
      end;


    function ttypeconvnode.typecheck_chararray_to_string : TNode;
      var
        chartype : string[8];
        newblock : tblocknode;
        newstat  : tstatementnode;
        restemp  : ttempcreatenode;
      begin
        if is_widechar(TArrayDef(left.resultdef).elementdef) then
          chartype:='widechar'
        else
          chartype:='char';
        if TStringDef(resultdef).stringtype=st_shortstring then
          begin
            newblock:=internalstatements(newstat);
            restemp:=ctempcreatenode.create(resultdef,resultdef.size,tt_persistent,false);
            addstatement(newstat,restemp);
            addstatement(newstat,ccallnode.createintern('fpc_'+chartype+'array_to_shortstr',
              ccallparanode.create(cordconstnode.create(
                ord(TArrayDef(left.resultdef).lowrange=0),pasbool1type,false),
              ccallparanode.create(left,ccallparanode.create(
              ctemprefnode.create(restemp),nil)))));
            addstatement(newstat,ctempdeletenode.create_normal_temp(restemp));
            addstatement(newstat,ctemprefnode.create(restemp));
            result:=newblock;
          end
        else if (TStringDef(resultdef).stringtype=st_ansistring) then
          begin
            result:=ccallnode.createinternres(
                      'fpc_'+chartype+'array_to_'+TStringDef(resultdef).stringtypname,
                      ccallparanode.create(
                        cordconstnode.create(
                          ord(TArrayDef(left.resultdef).lowrange=0),
                          pasbool1type,
                          false
                        ),
                        ccallparanode.create(
                          cordconstnode.create(
                            getparaencoding(resultdef),
                            u16inttype,
                            true
                          ),
                          ccallparanode.create(left,nil)
                        )
                      ),
                      resultdef
                    );
          end
        else
          result:=ccallnode.createinternres(
            'fpc_'+chartype+'array_to_'+TStringDef(resultdef).stringtypname,
            ccallparanode.create(cordconstnode.create(
               ord(TArrayDef(left.resultdef).lowrange=0),pasbool1type,false),
             ccallparanode.create(left,nil)),resultdef);
        left:=nil;
      end;


    function ttypeconvnode.typecheck_string_to_chararray : TNode;
      var
        newblock : tblocknode;
        newstat  : tstatementnode;
        restemp  : ttempcreatenode;
        pchtemp  : pchar;
        arrsize  : tcgint;
        chartype : string[8];

      begin
        result := nil;
        with TArrayDef(resultdef) do
          begin
            if highrange<lowrange then
             internalerror(2005010502);
            arrsize := highrange-lowrange+1;
          end;
        if (left.nodetype = stringconstn) and
           (tstringconstnode(left).cst_type=cst_conststring) then
           begin
             if (m_iso in CurrentSettings.modeswitches) and (arrsize<>tstringconstnode(left).len) and
                is_char(TArrayDef(resultdef).elementdef) then
               Message2(type_w_array_size_does_not_match_size_of_constant_string,tostr(tstringconstnode(left).len),tostr(arrsize));
             { if the array of char is large enough we can use the string
               constant directly. This is handled in ncgcnv }
             if (arrsize>=tstringconstnode(left).len) and
                is_char(TArrayDef(resultdef).elementdef) then
               begin
                 { pad the constant string with #0 to the array len }
                 { (2.0.x compatible)                               }
                 if (arrsize>tstringconstnode(left).len) then
                   begin
                     pchtemp:=concatansistrings(tstringconstnode(left).asconstpchar,pchar(StringOfChar(#0,arrsize-tstringconstnode(left).len)),tstringconstnode(left).len,arrsize-tstringconstnode(left).len);
                     left.free;
                     left:=cstringconstnode.createpchar(pchtemp,arrsize,nil);
                     freemem(pchtemp);
                     TypeCheckPass(left);
                   end;
                 exit;
               end;
             { Convert to wide/short/ansistring and call default helper }
             if is_widechar(TArrayDef(resultdef).elementdef) then
               inserttypeconv(left,cunicodestringtype)
             else
               begin
                 if tstringconstnode(left).len>255 then
                   inserttypeconv(left,getansistringdef)
                 else
                   inserttypeconv(left,cshortstringtype);
               end;
           end;
        if is_widechar(TArrayDef(resultdef).elementdef) then
          chartype:='widechar'
        else
          chartype:='char';
        newblock:=internalstatements(newstat);
        restemp:=ctempcreatenode.create(resultdef,resultdef.size,tt_persistent,false);
        addstatement(newstat,restemp);
        addstatement(newstat,ccallnode.createintern('fpc_'+TStringDef(left.resultdef).stringtypname+
          '_to_'+chartype+'array',ccallparanode.create(left,ccallparanode.create(
          ctemprefnode.create(restemp),nil))));
        addstatement(newstat,ctempdeletenode.create_normal_temp(restemp));
        addstatement(newstat,ctemprefnode.create(restemp));
        result:=newblock;
        left:=nil;
      end;


    function ttypeconvnode.typecheck_char_to_string : TNode;
      var
        procname: string[31];
        para : tcallparanode;
        hp : tstringconstnode;
        ws : tcompilerwidestring;
        sa : ansistring;
        cw : tcompilerwidechar;
        l : SizeUInt;
        exprtype : TDef;
      begin
         result:=nil;
         sa:='';
         if (left.nodetype=ordconstn) and
            ((TStringDef(resultdef).stringtype in [st_widestring,st_unicodestring,st_ansistring]) or
             (TOrdDef(left.resultdef).ordtype in [uchar,uwidechar])) then
           begin
              if (TStringDef(resultdef).stringtype in [st_widestring,st_unicodestring]) then
               begin
                 initwidestring(ws);
                 if TOrdDef(left.resultdef).ordtype=uwidechar then
                   concatwidestringchar(ws,tcompilerwidechar(tordconstnode(left).value.uvalue))
                 else
                   concatwidestringchar(ws,asciichar2unicode(chr(tordconstnode(left).value.uvalue)));
                 hp:=cstringconstnode.createunistr(ws);
                 hp.changestringtype(resultdef);
                 donewidestring(ws);
               end
              else
                begin
                  if (TOrdDef(left.resultdef).ordtype=uwidechar) then
                    begin
                      if not((CurrentSettings.sourcecodepage=CP_UTF8) or
                             ((TStringDef(resultdef).stringtype=st_ansistring) and
                              (TStringDef(resultdef).encoding=CP_UTF8))) then
                        begin
                          if tordconstnode(left).value.uvalue>127 then
                            begin
                              Message(type_w_unicode_data_loss);
                              // compiler has different codepage than a system running an application
                              // to prevent wrong codepage and data loss we are converting unicode char
                              // using a helper routine. This is not delphi compatible behavior.
                              // Delphi converts UniocodeChar to ansistring at the compile time
                              // old behavior:
                              // hp:=cstringconstnode.createstr(unicode2asciichar(tcompilerwidechar(tordconstnode(left).value.uvalue)));
                              para:=ccallparanode.create(left,nil);
                              if TStringDef(resultdef).stringtype=st_ansistring then
                                para:=ccallparanode.create(cordconstnode.create(getparaencoding(resultdef),u16inttype,true),para);
                              result:=ccallnode.createinternres('fpc_uchar_to_'+TStringDef(resultdef).stringtypname,
                                para,resultdef);
                              left:=nil;
                              exit;
                            end
                          else
                            hp:=cstringconstnode.createstr(unicode2asciichar(tcompilerwidechar(tordconstnode(left).value.uvalue)));
                        end
                      else
                        begin
                          cw:=tcompilerwidechar(tordconstnode(left).value.uvalue);
                          SetLength(sa,5);
                          l:=UnicodeToUtf8(@(sa[1]),Length(sa),@cw,1);
                          SetLength(sa,l-1);
                          hp:=cstringconstnode.createstr(sa);
                          { explicitly set the type of string constant to avoid unnecessary conversion }
                          if (TStringDef(resultdef).stringtype=st_ansistring) and
                             (TStringDef(resultdef).encoding=CP_UTF8) then
                            begin
                              hp.cst_type:=cst_ansistring;
                              hp.resultdef:=resultdef;
                            end;
                        end
                    end
                  else
                    hp:=cstringconstnode.createstr(chr(tordconstnode(left).value.uvalue));
                  { output string consts in local ansistring encoding }
                  if is_ansistring(resultdef) and ((TStringDef(resultdef).encoding=0) or (TStringDef(resultdef).encoding=globals.CP_NONE)) then
                    tstringconstnode(hp).changestringtype(getansistringdef)
                  else
                    tstringconstnode(hp).changestringtype(resultdef);
                end;
              result:=hp;
           end
         else
           { shortstrings are handled 'inline' (except for widechars) }
           if (TStringDef(resultdef).stringtype<>st_shortstring) or
              (TOrdDef(left.resultdef).ordtype=uwidechar) then
             begin
               { parameter }
               para:=ccallparanode.create(left,nil);
               { encoding required? }
               if TStringDef(resultdef).stringtype=st_ansistring then
                 para:=ccallparanode.create(cordconstnode.create(getparaencoding(resultdef),u16inttype,true),para);

               { create the procname }
               if TOrdDef(left.resultdef).ordtype<>uwidechar then
                 begin
                   procname:='fpc_char_to_';
                   if TStringDef(resultdef).stringtype in [st_widestring,st_unicodestring] then
                     if nf_explicit in flags then
                       Message2(type_w_explicit_string_cast,left.resultdef.typename,resultdef.typename)
                     else
                       Message2(type_w_implicit_string_cast,left.resultdef.typename,resultdef.typename);
                 end
               else
                 begin
                   procname:='fpc_uchar_to_';
                   if not (TStringDef(resultdef).stringtype in [st_widestring,st_unicodestring]) then
                     if nf_explicit in flags then
                       Message2(type_w_explicit_string_cast_loss,left.resultdef.typename,resultdef.typename)
                     else
                       Message2(type_w_implicit_string_cast_loss,left.resultdef.typename,resultdef.typename);
                 end;
               procname:=procname+TStringDef(resultdef).stringtypname;

               { and finally the call }
               result:=ccallnode.createinternres(procname,para,resultdef);
               left := nil;
             end
           else
             begin
               { use at least u16inttype }

               exprtype:=uinttype;

               { create word(byte(char) shl 8 or 1) for little endian machines}
               { and word(byte(char) or 256) for big endian machines          }
               left := ctypeconvnode.create_internal(left,exprtype);
               if (TargetInfo.endian = endian_little) then
                 left := caddnode.create(orn,
                   cshlshrnode.create(shln,left,cordconstnode.create(8,exprtype,false)),
                   cordconstnode.create(1,exprtype,false))
               else
                 left := caddnode.create(orn,left,
                   cordconstnode.create(1 shl 8,exprtype,false));
               left := ctypeconvnode.create_internal(left,u16inttype);
               TypeCheckPass(left);
             end;
      end;

    function ttypeconvnode.typecheck_string_to_string : TNode;
      begin
        result:=nil;
        if (left.nodetype=stringconstn) and
           (((TStringDef(resultdef).stringtype=st_ansistring) and
             (TStringDef(resultdef).encoding<>CP_NONE)
            )
           ) and
           (TStringDef(left.resultdef).stringtype in [st_unicodestring,st_widestring]) then
          begin
            tstringconstnode(left).changestringtype(resultdef);
            Result:=left;
            left:=nil;
          end
        else if (TStringDef(resultdef).stringtype=st_ansistring) and
                (TStringDef(left.resultdef).stringtype=st_ansistring) and
                (TStringDef(resultdef).encoding<>TStringDef(left.resultdef).encoding) then
          begin
            result:=ccallnode.createinternres(
                      'fpc_ansistr_to_ansistr',
                      ccallparanode.create(
                        cordconstnode.create(
                          TStringDef(resultdef).encoding,
                          u16inttype,
                          true
                        ),
                        ccallparanode.create(left,nil)
                      ),
                      resultdef
                    );
            left:=nil;
          end
        else if (left.nodetype=stringconstn) and
                (TStringDef(left.resultdef).stringtype in [st_unicodestring,st_widestring]) and
                (TStringDef(resultdef).stringtype=st_shortstring) then
          begin
            if not hasnonasciichars(tstringconstnode(left).valuews) then
              begin
                tstringconstnode(left).changestringtype(resultdef);
                Result:=left;
                left:=nil;
              end;
          end
        else if (TStringDef(left.resultdef).stringtype in [st_unicodestring,st_widestring]) and
                not (TStringDef(resultdef).stringtype in [st_unicodestring,st_widestring]) then
          begin
            if nf_explicit in flags then
              Message2(type_w_explicit_string_cast_loss,left.resultdef.typename,resultdef.typename)
            else
              Message2(type_w_implicit_string_cast_loss,left.resultdef.typename,resultdef.typename);
          end
        else if not (TStringDef(left.resultdef).stringtype in [st_unicodestring,st_widestring]) and
                (TStringDef(resultdef).stringtype in [st_unicodestring,st_widestring]) then
          begin
            if nf_explicit in flags then
              Message2(type_w_explicit_string_cast,left.resultdef.typename,resultdef.typename)
            else
              Message2(type_w_implicit_string_cast,left.resultdef.typename,resultdef.typename);
          end
      end;

    function ttypeconvnode.typecheck_char_to_chararray : TNode;
      begin
        result:=nil;
      end;


    function ttypeconvnode.typecheck_char_to_char : TNode;
      var
        hp : tordconstnode;
      begin
         result:=nil;
         if (left.nodetype=ordconstn) and
            ((TOrdDef(resultdef).ordtype<>uchar) or
             (TOrdDef(left.resultdef).ordtype<>uwidechar) or
             (CurrentSettings.sourcecodepage<>CP_UTF8))
         then
           begin
             if (TOrdDef(resultdef).ordtype=uchar) and
                (TOrdDef(left.resultdef).ordtype=uwidechar) and
                (CurrentSettings.sourcecodepage<>CP_UTF8) then
              begin
                if tordconstnode(left).value.uvalue>127 then
                  Message(type_w_unicode_data_loss);
                hp:=cordconstnode.create(
                      ord(unicode2asciichar(tcompilerwidechar(tordconstnode(left).value.uvalue))),
                      cansichartype,true);
                result:=hp;
              end
             else if (TOrdDef(resultdef).ordtype=uwidechar) and
                     (TOrdDef(left.resultdef).ordtype=uchar) then
              begin
                hp:=cordconstnode.create(
                      asciichar2unicode(chr(tordconstnode(left).value.uvalue)),
                      cwidechartype,true);
                result:=hp;
              end
             else
              internalerror(200105131);
             exit;
           end;
      end;


    function ttypeconvnode.typecheck_int_to_int : TNode;
      var
        v : TConstExprInt;
        n : TNode;
        SetCurFlag: Boolean;
      begin
        SetCurFlag:=False;
        result:=nil;
        if left.nodetype=ordconstn then
         begin
           v:=tordconstnode(left).value;
           if is_currency(resultdef) and
              (nf_is_currency in flags) and
              not(nf_internal in flags) then
             begin
               if not(nf_is_currency in left.flags) then
                 v:=v*10000;
               SetCurFlag:=True;
             end;
           if (resultdef.typ=pointerdef) then
             result:=cpointerconstnode.create(TConstPtrUInt(v.uvalue),resultdef)
           else
             begin
               if (nf_is_currency in left.flags) and
                 is_currency(left.resultdef) then
                 begin
                  if not(nf_internal in flags) and
                    not(nf_is_currency in flags) then
                    v:=v div 10000;
                 end
               else if (resultdef.typ in [orddef,enumdef]) then
                 adaptrange(resultdef,v,([nf_internal,nf_absolute]*flags)<>[],nf_explicit in flags,cs_check_range in localswitches);
               result:=cordconstnode.create(v,resultdef,false);
             end;

           if SetCurFlag then
             Include(result.flags, nf_is_currency);
         end
        else if left.nodetype=pointerconstn then
         begin
           v:=tpointerconstnode(left).value;
           if (resultdef.typ=pointerdef) then
             result:=cpointerconstnode.create(v.uvalue,resultdef)
           else
             begin
               if (nf_is_currency in flags) and
                 is_currency(resultdef) and
                  not(nf_internal in flags) then
                 v:=v*10000;
               result:=cordconstnode.create(v,resultdef,false);
             end;
         end
        else
         if not (nf_internal in flags) then
          begin
           { multiply by 10000 for currency. We need to use getcopy to pass
             the argument because the current node is always disposed. Only
             inserting the multiply in the left node is not possible because
             it'll get in an infinite loop to convert int->currency }
           if (nf_is_currency in flags) and not (nf_is_currency in left.flags) then
            begin
              n:=getcopy;
              result:=caddnode.create(muln,n,cordconstnode.create_currency_scalar(resultdef));
              include(result.flags,nf_is_currency);
              exclude(n.flags,nf_is_currency);
              include(n.flags,nf_internal);
            end
           else if not (nf_is_currency in flags) and (nf_is_currency in left.flags) then
            begin
              n:=getcopy;
              result:=cmoddivnode.create(divn,n,cordconstnode.create_currency_scalar(resultdef));
              include(n.flags,nf_is_currency);
              include(n.flags,nf_internal);
            end;
         end;
      end;


    function ttypeconvnode.typecheck_int_to_real : TNode;
      var
        rv : bestreal;
        n : TNode;
        SetCurFlag: Boolean;
      begin
        result:=nil;
        if left.nodetype=ordconstn then
         begin
           rv:=tordconstnode(left).value;

           if not(nf_internal in flags) then
             begin
               SetCurFlag:=(nf_is_currency in flags); { Make sure the flag gets preserved }

               if (nf_is_currency in flags) and is_currency(resultdef) then
                 begin
                   if not(nf_is_currency in left.flags) then
                     begin
                       rv:=rv*BestReal(10000.0);
                       SetCurFlag:=True;
                     end
                 end
               else if is_currency(left.resultdef) and
                 (nf_is_currency in left.flags) and
                 not SetCurFlag then
                 rv:=rv/BestReal(10000.0);
             end
           else
             SetCurFlag:=False;

           result:=crealconstnode.create(rv,resultdef);
           if SetCurFlag then
             include(result.flags,nf_is_currency)
         end
        else if not(nf_internal in flags) then
         begin
           { multiply by 10000 for currency. We need to use getcopy to pass
             the argument because the current node is always disposed. Only
             inserting the multiply in the left node is not possible because
             it'll get in an infinite loop to convert int->currency }
           if is_currency(resultdef) and
             not (nf_is_currency in left.flags) then
            begin
              n:=getcopy;
              Exclude(n.flags,nf_is_currency);
              result:=caddnode.create(muln,n,crealconstnode.create_currency_scalar(resultdef));
              Include(result.flags,nf_is_currency);
            end
           else if is_currency(left.resultdef) and
            (nf_is_currency in left.flags) and
            not (nf_is_currency in flags) then
            begin
              n:=getcopy;
              Include(n.flags,nf_is_currency);
              result:=caddnode.create(slashn,n,crealconstnode.create_currency_scalar(resultdef));
            end;
         end;
      end;


    function ttypeconvnode.typecheck_real_to_currency : TNode;
      var
        n: TNode;
      begin
        if not is_currency(resultdef) then
          internalerror(200304221);

        { Convert constants directly, else call Round() }
        if left.nodetype=realconstn then
          begin
            result:=cordconstnode.create(trealconstnode(left).CurrencyScaledValue,resultdef,false);
            include(result.flags,nf_is_currency);
          end
        else
          begin
            if not (nf_is_currency in left.flags) then
              begin
                left:=caddnode.create(muln,left,crealconstnode.create_currency_scalar(left.resultdef));
                include(left.flags,nf_is_currency);
              end;

            result:=cinlinenode.create(in_round_real,false,left);
            include(result.flags,nf_is_currency);
            { Internal type cast to currency }
            result:=ctypeconvnode.create_internal(result,s64currencytype);
            include(result.flags,nf_is_currency);
            left:=nil;
          end;
      end;


    function ttypeconvnode.typecheck_real_to_real : TNode;
      begin
         result:=nil;
         if not(nf_internal in flags) then
           begin
             if not (nf_is_currency in flags) and not(is_currency(resultdef))
               and (nf_is_currency in left.flags) and is_currency(left.resultdef) then
               begin
                 left:=caddnode.create_internal(slashn,left,crealconstnode.create_currency_scalar(left.resultdef));
                 TypeCheckPass(left);
               end
             else
               if (nf_is_currency in flags) and is_currency(resultdef) and
                 not (nf_is_currency in left.flags) then { Regardless of whether or not the type is Currency }
                 begin
                   left:=caddnode.create_internal(muln,left,crealconstnode.create_currency_scalar(left.resultdef));
                   include(left.flags,nf_is_currency);
                   TypeCheckPass(left);
                 end;
             { comp is handled by the fpu but not a floating type point }
             if is_fpucomp(resultdef) and not(is_fpucomp(left.resultdef)) and
               not (nf_explicit in flags) then
               Message(type_w_convert_real_2_comp);
           end;
      end;


    function ttypeconvnode.typecheck_cchar_to_pchar : TNode;

      begin
         result:=nil;
         { handle any constants via cunicodestringtype because the compiler
           cannot convert arbitrary unicodechar constants at compile time to
           a shortstring (since it doesn't know the code page to use) }
         inserttypeconv(left,cunicodestringtype);
         { evaluate again, reset resultdef so the convert_typ
           will be calculated again and cstring_to_pchar will
           be used for further conversion }
         convtype:=tc_none;
         result:=pass_typecheck;
      end;


    function ttypeconvnode.typecheck_cstring_to_pchar : TNode;

      begin
         result:=nil;
         if is_pwidechar(resultdef) then
           inserttypeconv(left,cunicodestringtype)
         else
           if is_pchar(resultdef) and
              (is_widestring(left.resultdef) or
               is_unicodestring(left.resultdef)) then
             begin
               inserttypeconv(left,getansistringdef);
               { the second pass of second_cstring_to_pchar expects a  }
               { strinconstn, but this may become a call to the        }
               { widestring manager in case left contains "high ascii" }
               if (left.nodetype<>stringconstn) then
                 begin
                   result:=left;
                   left:=nil;
                 end;
             end;
      end;


    function ttypeconvnode.typecheck_cstring_to_int : TNode;
      var
        fcc : cardinal;
        pb  : pbyte;
      begin
         result:=nil;
         if left.nodetype<>stringconstn then
           internalerror(200510012);
         if (m_mac in CurrentSettings.modeswitches) and
            is_integer(resultdef) and
            (tstringconstnode(left).cst_type=cst_conststring) and
            (tstringconstnode(left).len=4) then
           begin
             pb:=pbyte(tstringconstnode(left).asconstpchar);
             fcc:=(pb[0] shl 24) or (pb[1] shl 16) or (pb[2] shl 8) or pb[3];
             result:=cordconstnode.create(fcc,u32inttype,false);
           end
         else
           CGMessage2(type_e_illegal_type_conversion,left.resultdef.typename,resultdef.typename);
      end;


    function ttypeconvnode.typecheck_arrayconstructor_to_set : TNode;
      var
        hp : TNode;
      begin
        result:=nil;
        if left.nodetype<>arrayconstructorn then
         internalerror(5546);
        { remove typeconv node }
        hp:=left;
        left:=nil;
        { create a set constructor tree }
        arrayconstructor_to_set(hp);
        if is_emptyset(hp) then
          begin
            { enforce the result type for an empty set }
            hp.resultdef:=resultdef;
            result:=hp;
          end
        else if hp.resultdef<>resultdef then
          begin
            { the set might contain a subrange element (e.g. through a variable),
              thus we need to insert another type conversion }
            if nf_explicit in flags then
              result:=ctypeconvnode.create_explicit(hp,totypedef)
            else if nf_internal in flags then
              result:=ctypeconvnode.create_internal(hp,totypedef)
            else
              result:=ctypeconvnode.create(hp,totypedef);
          end
        else
          result:=hp;
      end;


    function ttypeconvnode.typecheck_set_to_set : TNode;
      begin
        result:=nil;
        { constant sets can be converted by changing the type only }
        if (left.nodetype=setconstn) then
         begin
           if (cs_check_range in CurrentSettings.localswitches) and (tsetconstnode(left).elements>0) and ((tsetconstnode(left).low<TSetDef(resultdef).setlow) or (tsetconstnode(left).high>TSetDef(resultdef).setmax)) then
             Message(parser_e_range_check_error);

           left.resultdef:=resultdef;
           result:=left;
           left:=nil;
           exit;
         end;
      end;


    function ttypeconvnode.typecheck_pchar_to_string : TNode;
      var
        newblock : tblocknode;
        newstat  : tstatementnode;
        restemp  : ttempcreatenode;
      begin
        if TStringDef(resultdef).stringtype=st_shortstring then
          begin
            newblock:=internalstatements(newstat);
            restemp:=ctempcreatenode.create(resultdef,resultdef.size,tt_persistent,false);
            addstatement(newstat,restemp);
            addstatement(newstat,ccallnode.createintern('fpc_pchar_to_shortstr',ccallparanode.create(left,ccallparanode.create(
              ctemprefnode.create(restemp),nil))));
            addstatement(newstat,ctempdeletenode.create_normal_temp(restemp));
            addstatement(newstat,ctemprefnode.create(restemp));
            result:=newblock;
          end
        else if TStringDef(resultdef).stringtype=st_ansistring then
          result := ccallnode.createinternres(
                      'fpc_pchar_to_'+TStringDef(resultdef).stringtypname,
                      ccallparanode.create(
                        cordconstnode.create(getparaencoding(resultdef),u16inttype,true),
                        ccallparanode.create(left,nil)
                      ),
                      resultdef
                    )
        else
          result := ccallnode.createinternres(
            'fpc_pchar_to_'+TStringDef(resultdef).stringtypname,
            ccallparanode.create(left,nil),resultdef);
        left:=nil;
      end;


    function ttypeconvnode.typecheck_interface_to_string : TNode;
      begin
        if assigned(TObjectDef(left.resultdef).iidstr) then
          begin
            if not(oo_has_valid_guid in TObjectDef(left.resultdef).objectoptions) then
              CGMessage1(type_e_interface_has_no_name,TObjectDef(left.resultdef).typename);
            result:=cstringconstnode.createstr(TObjectDef(left.resultdef).iidstr^);
            tstringconstnode(result).changestringtype(resultdef);
          end
        else
          internalerror(2013112913);
      end;


    function ttypeconvnode.typecheck_interface_to_guid : TNode;
      begin
        if assigned(TObjectDef(left.resultdef).iidguid) then
          begin
            if not(oo_has_valid_guid in TObjectDef(left.resultdef).objectoptions) then
              CGMessage1(type_e_interface_has_no_guid,TObjectDef(left.resultdef).typename);
            result:=cguidconstnode.create(TObjectDef(left.resultdef).iidguid^);
          end
        else
          internalerror(2013112914);
      end;


    function ttypeconvnode.typecheck_dynarray_to_openarray : TNode;
      begin
        if (actualtargetnode(@left)^.nodetype in [pointerconstn,niln]) then
          CGMessage(type_e_no_addr_of_constant);
        { a dynamic array is a pointer to an array, so to convert it to }
        { an open array, we have to dereference it (JM)                 }
        result:=ctypeconvnode.create_internal(left,cpointerdef.getreusable(resultdef));
        TypeCheckPass(result);
        { left is reused }
        left:=nil;
        result:=cderefnode.create(result);
        include(TDerefNode(result).derefnodeflags,drnf_no_checkpointer);
      end;


    function ttypeconvnode.typecheck_pwchar_to_string : TNode;
      var
        newblock : tblocknode;
        newstat  : tstatementnode;
        restemp  : ttempcreatenode;
      begin
        if TStringDef(resultdef).stringtype=st_shortstring then
          begin
            newblock:=internalstatements(newstat);
            restemp:=ctempcreatenode.create(resultdef,resultdef.size,tt_persistent,false);
            addstatement(newstat,restemp);
            addstatement(newstat,ccallnode.createintern('fpc_pwidechar_to_shortstr',ccallparanode.create(left,ccallparanode.create(
              ctemprefnode.create(restemp),nil))));
            addstatement(newstat,ctempdeletenode.create_normal_temp(restemp));
            addstatement(newstat,ctemprefnode.create(restemp));
            result:=newblock;
          end
        else if TStringDef(resultdef).stringtype=st_ansistring then
          begin
            result:=ccallnode.createinternres(
                        'fpc_pwidechar_to_'+TStringDef(resultdef).stringtypname,
                         ccallparanode.create(
                           cordconstnode.create(
                             getparaencoding(resultdef),
                             u16inttype,
                             true
                           ),
                           ccallparanode.create(left,nil)
                         ),
                         resultdef
                      );
          end
        else
          result := ccallnode.createinternres(
            'fpc_pwidechar_to_'+TStringDef(resultdef).stringtypname,
            ccallparanode.create(left,nil),resultdef);
        left:=nil;
      end;


    function ttypeconvnode.typecheck_variant_to_dynarray : TNode;
      begin
        result := ccallnode.createinternres(
          'fpc_variant_to_dynarray',
          ccallparanode.create(caddrnode.create_internal(crttinode.create(TStoredDef(resultdef),initrtti,rdt_normal)),
            ccallparanode.create(left,nil)
          ),resultdef);
        TypeCheckPass(result);
        left:=nil;
      end;


    function ttypeconvnode.typecheck_dynarray_to_variant : TNode;
      begin
        result := ccallnode.createinternres(
          'fpc_dynarray_to_variant',
          ccallparanode.create(caddrnode.create_internal(crttinode.create(TStoredDef(left.resultdef),initrtti,rdt_normal)),
            ccallparanode.create(ctypeconvnode.create_explicit(left,voidpointertype),nil)
          ),resultdef);
        TypeCheckPass(result);
        left:=nil;
      end;


    function ttypeconvnode.typecheck_variant_to_interface : TNode;
      begin
        if def_is_related(TObjectDef(resultdef),TObjectDef(search_system_type('IDISPATCH').typedef)) then
          result := ccallnode.createinternres(
            'fpc_variant_to_idispatch',
              ccallparanode.create(left,nil)
            ,resultdef)
        else
          result := ccallnode.createinternres(
            'fpc_variant_to_interface',
              ccallparanode.create(left,nil)
            ,resultdef);
        TypeCheckPass(result);
        left:=nil;
      end;


    function ttypeconvnode.typecheck_interface_to_variant : TNode;
      begin
        if def_is_related(TObjectDef(left.resultdef),TObjectDef(search_system_type('IDISPATCH').typedef)) then
          result := ccallnode.createinternres(
            'fpc_idispatch_to_variant',
              ccallparanode.create(left,nil)
            ,resultdef)
        else
          result := ccallnode.createinternres(
            'fpc_interface_to_variant',
              ccallparanode.create(left,nil)
            ,resultdef);
        TypeCheckPass(result);
        left:=nil;
      end;


    function ttypeconvnode.typecheck_variant_to_enum : TNode;

      begin
        result := ctypeconvnode.create_internal(left,sinttype);
        result := ctypeconvnode.create_internal(result,resultdef);
        TypeCheckPass(result);
        { left is reused }
        left := nil;
      end;


    function ttypeconvnode.typecheck_enum_to_variant : TNode;

      begin
        result := ctypeconvnode.create_internal(left,sinttype);
        result := ctypeconvnode.create_internal(result,cvarianttype);
        TypeCheckPass(result);
        { left is reused }
        left := nil;
      end;


    function ttypeconvnode.typecheck_array_2_dynarray : TNode;
      var
        newstatement : tstatementnode;
        temp         : ttempcreatenode;
        temp2        : ttempcreatenode;
      begin
        { create statements with call to getmem+initialize }
        result:=internalstatements(newstatement);

        { create temp for result }
        temp:=ctempcreatenode.create(resultdef,resultdef.size,tt_persistent,true);
        addstatement(newstatement,temp);

        { get temp for array of lengths }
        temp2:=ctempcreatenode.create(sinttype,sinttype.size,tt_persistent,false);
        addstatement(newstatement,temp2);

        { one dimensional }
        addstatement(newstatement,cassignmentnode.create(
            ctemprefnode.create(temp2),
            cordconstnode.create
               (TArrayDef(left.resultdef).highrange+1,s32inttype,true)));
        { create call to fpc_dynarr_setlength }
        addstatement(newstatement,ccallnode.createintern('fpc_dynarray_setlength',
            ccallparanode.create(caddrnode.create_internal
                  (ctemprefnode.create(temp2)),
               ccallparanode.create(cordconstnode.create
                  (1,s32inttype,true),
               ccallparanode.create(caddrnode.create_internal
                  (crttinode.create(TStoredDef(resultdef),initrtti,rdt_normal)),
               ccallparanode.create(
                 ctypeconvnode.create_internal(
                   ctemprefnode.create(temp),voidpointertype),
                 nil))))

          ));
        addstatement(newstatement,ctempdeletenode.create(temp2));

        { copy ... }
        addstatement(newstatement,cassignmentnode.create(
          ctypeconvnode.create_internal(cderefnode.create(ctypeconvnode.create_internal(ctemprefnode.create(temp),voidpointertype)),left.resultdef),
          left
        ));
        { left is reused }
        left:=nil;
        { the last statement should return the value as
          location and type, this is done be referencing the
          temp and converting it first from a persistent temp to
          normal temp }
        addstatement(newstatement,ctempdeletenode.create_normal_temp(temp));
        addstatement(newstatement,ctemprefnode.create(temp));
      end;


    function ttypeconvnode.typecheck_elem_2_openarray : TNode;
      begin
        result:=nil;
      end;


    function ttypeconvnode.typecheck_arrayconstructor_to_dynarray : TNode;
      var
        newstatement,
        assstatement : tstatementnode;
        arrnode : ttempcreatenode;
        temp2 : ttempcreatenode;
        assnode : TNode;
        paracount : integer;
        elemnode : tarrayconstructornode;
      begin
        { assignment of []? }
        if (
              (left.nodetype=arrayconstructorn) and
              not assigned(tarrayconstructornode(left).left)
            ) or
              is_emptyset(left)
            then
          begin
            result:=cnilnode.create;
            exit;
          end;

        if resultdef.typ<>arraydef then
          internalerror(2017050102);

        tarrayconstructornode(left).force_type(TArrayDef(resultdef).elementdef);

        result:=internalstatements(newstatement);
        { create temp for result }
        arrnode:=ctempcreatenode.create(totypedef,totypedef.size,tt_persistent,true);
        addstatement(newstatement,arrnode);

        paracount:=0;

        { create an assignment call for each element }
        assnode:=internalstatements(assstatement);
        if left.nodetype=arrayconstructorrangen then
          internalerror(2016021902);
        elemnode:=tarrayconstructornode(left);
        while assigned(elemnode) do
          begin
            { arr[i] := param_i }
            if not assigned(elemnode.left) then
              internalerror(2017050103);
            addstatement(assstatement,
              cassignmentnode.create(
                cvecnode.create(
                  ctemprefnode.create(arrnode),
                  cordconstnode.create(paracount,TArrayDef(totypedef).rangedef,false)),
                elemnode.left));
            elemnode.left:=nil;
            inc(paracount);
            elemnode:=tarrayconstructornode(elemnode.right);
            if assigned(elemnode) and (elemnode.nodetype<>arrayconstructorn) then
              internalerror(2016021903);
          end;

        { get temp for array of lengths }
        temp2:=ctempcreatenode.create_value(sinttype,sinttype.size,tt_persistent,false,cordconstnode.create(paracount,s32inttype,true));
        addstatement(newstatement,temp2);

        { create call to fpc_dynarr_setlength }
        addstatement(newstatement,ccallnode.createintern('fpc_dynarray_setlength',
            ccallparanode.create(caddrnode.create_internal
                  (ctemprefnode.create(temp2)),
               ccallparanode.create(cordconstnode.create
                  (1,s32inttype,true),
               ccallparanode.create(caddrnode.create_internal
                  (crttinode.create(TStoredDef(totypedef),initrtti,rdt_normal)),
               ccallparanode.create(
                 ctypeconvnode.create_internal(
                   ctemprefnode.create(arrnode),voidpointertype),
                 nil))))

          ));
        { add assignment statements }
        addstatement(newstatement,ctempdeletenode.create(temp2));
        addstatement(newstatement,assnode);
        { the last statement should return the value as
          location and type, this is done be referencing the
          temp and converting it first from a persistent temp to
          normal temp }
        addstatement(newstatement,ctempdeletenode.create_normal_temp(arrnode));
        addstatement(newstatement,ctemprefnode.create(arrnode));
      end;


    function ttypeconvnode.typecheck_arrayconstructor_to_array : TNode;
      var
        newstatement,
        assstatement : tstatementnode;
        arrnode : ttempcreatenode;
        temp2 : ttempcreatenode;
        assnode : TNode;
        paracount : integer;
        elemnode : tarrayconstructornode;
      begin
        tarrayconstructornode(left).force_type(TArrayDef(resultdef).elementdef);

        result:=internalstatements(newstatement);
        { create temp for result }
        arrnode:=ctempcreatenode.create(totypedef,totypedef.size,tt_persistent,true);
        addstatement(newstatement,arrnode);

        paracount:=0;

        { create an assignment call for each element }
        assnode:=internalstatements(assstatement);
        if left.nodetype=arrayconstructorrangen then
          internalerror(2020041402);
        elemnode:=tarrayconstructornode(left);
        while assigned(elemnode) do
          begin
            { arr[i] := param_i }
            if not assigned(elemnode.left) then
              internalerror(2020041403);
            addstatement(assstatement,
              cassignmentnode.create(
                cvecnode.create(
                  ctemprefnode.create(arrnode),
                  cordconstnode.create(paracount+TArrayDef(totypedef).lowrange,TArrayDef(totypedef).rangedef,false)),
                elemnode.left));
            elemnode.left:=nil;
            inc(paracount);
            elemnode:=tarrayconstructornode(elemnode.right);
            if assigned(elemnode) and (elemnode.nodetype<>arrayconstructorn) then
              internalerror(2020041404);
          end;

        { get temp for array of lengths }
        temp2:=ctempcreatenode.create_value(sinttype,sinttype.size,tt_persistent,false,cordconstnode.create(paracount,s32inttype,true));
        addstatement(newstatement,temp2);

        { add assignment statements }
        addstatement(newstatement,ctempdeletenode.create(temp2));
        addstatement(newstatement,assnode);
        { the last statement should return the value as
          location and type, this is done be referencing the
          temp and converting it first from a persistent temp to
          normal temp }
        addstatement(newstatement,ctempdeletenode.create_normal_temp(arrnode));
        addstatement(newstatement,ctemprefnode.create(arrnode));
      end;


    function ttypeconvnode._typecheck_int_to_int : TNode;
      begin
        result := typecheck_int_to_int;
      end;


    function ttypeconvnode._typecheck_cord_to_pointer : TNode;
      begin
        result := typecheck_cord_to_pointer;
      end;


    function ttypeconvnode._typecheck_chararray_to_string : TNode;
      begin
        result := typecheck_chararray_to_string;
      end;


    function ttypeconvnode._typecheck_string_to_chararray : TNode;
      begin
        result := typecheck_string_to_chararray;
      end;


    function ttypeconvnode._typecheck_string_to_string: TNode;
      begin
        result := typecheck_string_to_string;
      end;


    function ttypeconvnode._typecheck_char_to_string : TNode;
      begin
        result := typecheck_char_to_string;
      end;


    function ttypeconvnode._typecheck_char_to_chararray : TNode;
      begin
        result := typecheck_char_to_chararray;
      end;


    function ttypeconvnode._typecheck_int_to_real : TNode;
      begin
        result := typecheck_int_to_real;
      end;


    function ttypeconvnode._typecheck_real_to_real : TNode;
      begin
        result := typecheck_real_to_real;
      end;


    function ttypeconvnode._typecheck_real_to_currency : TNode;
      begin
        result := typecheck_real_to_currency;
      end;


    function ttypeconvnode._typecheck_cchar_to_pchar : TNode;
      begin
        result := typecheck_cchar_to_pchar;
      end;


    function ttypeconvnode._typecheck_cstring_to_pchar : TNode;
      begin
        result := typecheck_cstring_to_pchar;
      end;


    function ttypeconvnode._typecheck_cstring_to_int : TNode;
      begin
        result := typecheck_cstring_to_int;
      end;


    function ttypeconvnode._typecheck_char_to_char : TNode;
      begin
        result := typecheck_char_to_char;
      end;


    function ttypeconvnode._typecheck_arrayconstructor_to_set : TNode;
      begin
        result := typecheck_arrayconstructor_to_set;
      end;


    function ttypeconvnode._typecheck_set_to_set : TNode;
      begin
        result := typecheck_set_to_set;
      end;


    function ttypeconvnode._typecheck_pchar_to_string : TNode;
      begin
        result := typecheck_pchar_to_string;
      end;


    function ttypeconvnode._typecheck_interface_to_string : TNode;
      begin
        result := typecheck_interface_to_string;
      end;


    function ttypeconvnode._typecheck_interface_to_guid : TNode;
      begin
        result := typecheck_interface_to_guid;
      end;


    function ttypeconvnode._typecheck_dynarray_to_openarray : TNode;
      begin
        result := typecheck_dynarray_to_openarray;
      end;


    function ttypeconvnode._typecheck_pwchar_to_string : TNode;
      begin
        result := typecheck_pwchar_to_string;
      end;


    function ttypeconvnode._typecheck_variant_to_dynarray : TNode;
      begin
        result := typecheck_variant_to_dynarray;
      end;


    function ttypeconvnode._typecheck_dynarray_to_variant : TNode;
      begin
        result := typecheck_dynarray_to_variant;
      end;


    function ttypeconvnode._typecheck_variant_to_enum : TNode;
      begin
        result := typecheck_variant_to_enum;
      end;


    function ttypeconvnode._typecheck_enum_to_variant : TNode;
      begin
        result := typecheck_enum_to_variant;
      end;


    function ttypeconvnode._typecheck_proc_to_procvar : TNode;
      begin
        result := typecheck_proc_to_procvar;
      end;


    function ttypeconvnode._typecheck_variant_to_interface : TNode;
      begin
        result := typecheck_variant_to_interface;
      end;


    function ttypeconvnode._typecheck_interface_to_variant : TNode;
      begin
        result := typecheck_interface_to_variant;
      end;


    function ttypeconvnode._typecheck_array_2_dynarray : TNode;
      begin
        result := typecheck_array_2_dynarray;
      end;


    function ttypeconvnode._typecheck_elem_2_openarray : TNode;
      begin
        result := typecheck_elem_2_openarray;
      end;


    function ttypeconvnode._typecheck_arrayconstructor_to_dynarray : TNode;
      begin
        result:=typecheck_arrayconstructor_to_dynarray;
      end;


    function ttypeconvnode._typecheck_arrayconstructor_to_array : TNode;
      begin
        result:=typecheck_arrayconstructor_to_array;
      end;


    function ttypeconvnode._typecheck_procvar_to_funcref : TNode;
      begin
        result:=typecheck_procvar_2_funcref;
      end;


    function ttypeconvnode._typecheck_anonproc_to_funcref : TNode;
      begin
        result:=typecheck_anonproc_2_funcref;
      end;


    function ttypeconvnode.target_specific_general_typeconv: boolean;
      begin
        result:=false;
      end;


    function ttypeconvnode.target_specific_explicit_typeconv: boolean;
      begin
        result:=false;
      end;


    class function ttypeconvnode.target_specific_need_equal_typeconv(fromdef, todef: TDef): boolean;
      begin
        result:=false;
      end;


    type
      tsym_mapping = record
        oldsym:TSym;
        newsym:TSym;
      end;
      psym_mapping = ^tsym_mapping;


    function replace_self_sym(var n:TNode;arg:pointer):foreachnoderesult;
      var
        mapping : psym_mapping absolute arg;
        ld : tloadnode;
      begin
        if n.nodetype=loadn then
          begin
            ld:=tloadnode(n);
            if ld.symtableentry=mapping^.oldsym then
              begin
                ld.symtableentry:=mapping^.newsym;
                { make sure that the node is processed again }
                ld.resultdef:=nil;
                if assigned(ld.left) then
                  begin
                    { no longer loaded through the frame pointer }
                    ld.left.free;
                    ld.left:=nil;
                  end;
                TypeCheckPass(n);
              end;
          end;
        result:=fen_true;
      end;


    function ttypeconvnode.typecheck_proc_to_procvar : TNode;

      function is_self_sym(sym:TSym):boolean;
        begin
          result:=(sym.typ in [localvarsym,paravarsym]) and
                    (vo_is_self in TAbstractVarSym(sym).varoptions);
        end;

      var
        pd : TAbstractProcDef;
        copytype : TProcCopyTyp;
        source: PNode;
        fpsym,
        selfsym,
        sym : TSym;
        mapping : tsym_mapping;
        pi : tprocinfo;
        i : longint;
      begin
        result:=nil;
        pd:=TAbstractProcDef(left.resultdef);

        { create procvardef (default for create_proc_to_procvar is voiddef,
          but if later a regular inserttypeconvnode() is used to insert a type
          conversion to the actual procvardef, totypedef will be set to the
          real procvartype that we are converting to) }
        if assigned(totypedef) and
           (totypedef.typ=procvardef) then
          begin
            { have to do this in typecheckpass so that it's triggered for
              typed constant declarations }
            if po_is_block in TProcVarDef(totypedef).procoptions then
              begin
                { can only convert from procdef to procvardef, but in the mean
                  time other type conversions may have been inserted (pointers,
                  proc2procvar, ...) }
                source:=actualtargetnode(@left);
                while (source^.nodetype=typeconvn) and
                      (ttypeconvnode(source^).convtype=tc_proc_2_procvar) and
                      (is_void(source^.resultdef) or
                       (source^.resultdef.typ=procvardef)) do
                  begin
                    { won't skip proc2procvar }
                    source:=actualtargetnode(@ttypeconvnode(source^).left);
                  end;
                if (source^.nodetype=loadn) and
                   (source^.resultdef.typ=procdef) and
                   not is_nested_pd(TProcDef(source^.resultdef)) and
                   not is_objcclass(TDef(source^.resultdef.owner.defowner)) then
                  begin
                    result:=generate_block_for_procaddr(tloadnode(source^));
                    exit;
                  end
                else
                  CGMessage2(type_e_illegal_type_conversion,left.resultdef.typename,resultdef.typename);
              end
            else if (pd.typ=procdef) and
               (po_anonymous in pd.procoptions) then
              begin
                if left.nodetype<>loadn then
                  internalerror(2021062402);
                { get rid of any potential framepointer loading; if it's necessary
                  (for a nested procvar for example) it will be added again }
                if assigned(tloadnode(left).left) and (tloadnode(left).left.nodetype=loadparentfpn) then
                  begin
                    tloadnode(left).left.free;
                    tloadnode(left).left:=nil;
                    tloadnode(left).resultdef:=nil;
                  end;
                if TProcVarDef(totypedef).is_methodpointer then
                  begin
                    if assigned(TProcDef(pd).capturedsyms) and
                        (
                          (TProcDef(pd).capturedsyms.count>1) or
                          (
                            (TProcDef(pd).capturedsyms.count=1) and
                            not is_self_sym(TSym(PCapturedSymInfo(TProcDef(pd).capturedsyms[0])^.sym))
                          )
                        ) then
                      begin
                        result:=cerrornode.create;
                        exit;
                      end;

                    { so that insert_self_and_vmt_para correctly inserts the
                      Self, cause it otherwise skips that for anonymous functions }
                    include(pd.procoptions,po_methodpointer);
                    { we know this only captures Self, so we can move the
                      anonymous function to normal function level }
                    pd.parast.symtablelevel:=normal_function_level;
                    TProcDef(pd).localst.symtablelevel:=normal_function_level;

                    selfsym:=nil;
                    fpsym:=nil;
                    { find the framepointer parameter and an eventual self }
                    for i:=0 to TProcDef(pd).parast.symlist.count-1 do
                      begin
                        sym:=TSym(TProcDef(pd).parast.symlist[i]);
                        if sym.typ<>paravarsym then
                          continue;
                        if vo_is_parentfp in TParaVarSym(sym).varoptions then
                          fpsym:=sym;
                        if vo_is_self in TParaVarSym(sym).varoptions then
                          selfsym:=sym;
                        if assigned(fpsym) and assigned(selfsym) then
                          break;
                      end;

                    if assigned(fpsym) then
                      TProcDef(pd).parast.symlist.remove(fpsym);

                    { if we don't have a self parameter already we need to
                      insert a suitable one }

                    if not assigned(selfsym) then
                      begin
                        { replace the self symbol by the new parameter if it was
                          captured }
                        if assigned(TProcDef(pd).capturedsyms) and
                            (TProcDef(pd).capturedsyms.count>0) then
                          begin
                            if not assigned(TProcDef(pd).struct) then
                              { we can't use the captured symbol for the struct as that
                                might be the self of a type helper, thus we need to find
                                the parent procinfo that provides the Self }
                              TProcDef(pd).struct:=CurrentProcInfo.get_normal_proc.procdef.struct;
                            if not assigned(TProcDef(pd).struct) then
                              internalerror(2021062204);

                            insert_self_and_vmt_para(pd);

                            mapping.oldsym:=TSym(PCapturedSymInfo(TProcDef(pd).capturedsyms[0])^.sym);
                            mapping.newsym:=nil;

                            { find the new self parameter }
                            for i:=0 to TProcDef(pd).parast.symlist.count-1 do
                              begin
                                sym:=TSym(TProcDef(pd).parast.symlist[i]);
                                if (sym.typ=paravarsym) and (vo_is_self in TParaVarSym(sym).varoptions) then
                                  begin
                                    mapping.newsym:=sym;

                                    break;
                                  end;
                              end;

                            if not assigned(mapping.newsym) then
                              internalerror(2021062202);

                            { the anonymous function can only be a direct child of the
                              current_procinfo }
                            pi:=CurrentProcInfo.get_first_nestedproc;
                            while assigned(pi) do
                              begin
                                if pi.procdef=pd then
                                  break;
                                pi:=tprocinfo(pi.next);
                              end;

                            if not assigned(pi) then
                              internalerror(2021062203);

                            { replace all uses of the captured Self by the new Self
                              parameter }
                            foreachnodestatic(pm_preprocess,tcgprocinfo(pi).code,@replace_self_sym,@mapping);
                          end
                        else
                          begin
                            { for a nested function of a method struct is already
                              set }
                            if not assigned(TProcDef(pd).struct) then
                              { simply add a TObject as Self parameter }
                              TProcDef(pd).struct:=class_tobject;

                            insert_self_and_vmt_para(pd);

                            { there is no self, so load a nil value }
                            tloadnode(left).set_mp(cnilnode.create);
                          end;
                      end;

                    { the anonymous function no longer adheres to the nested
                      calling convention }
                    exclude(pd.procoptions,po_delphi_nested_cc);

                    TProcDef(pd).calcparas;

                    if not assigned(tloadnode(left).left) then
                      tloadnode(left).set_mp(load_self_node);
                  end
                else if TProcVarDef(totypedef).is_addressonly then
                  begin
                    if assigned(TProcDef(pd).capturedsyms) and (TProcDef(pd).capturedsyms.count>0) then
                      begin
                        result:=cerrornode.create;
                        exit;
                      end;

                    { remove framepointer and Self parameters }
                    for i:=TProcDef(pd).parast.symlist.count-1 downto 0 do
                      begin
                        sym:=TSym(TProcDef(pd).parast.symlist[i]);
                        if (sym.typ=paravarsym) and (TParaVarSym(sym).varoptions*[vo_is_parentfp,vo_is_self]<>[]) then
                          TProcDef(pd).parast.symlist.delete(i);
                      end;

                    { the anonymous function no longer adheres to the nested
                      calling convention }
                    exclude(pd.procoptions,po_delphi_nested_cc);

                    { we don't need to look through the existing nodes, cause
                      the parameter was never used anyway }
                    TProcDef(pd).calcparas;
                  end
                else
                  begin
                    { this is a nested function pointer, so ensure that the
                      anonymous function is handled as such }
                    if assigned(TProcDef(pd).capturedsyms) and
                        (TProcDef(pd).capturedsyms.count>0) and
                        (left.nodetype=loadn) then
                      begin
                        tloadnode(left).left:=cloadparentfpnode.create(TProcDef(tloadnode(left).symtable.defowner),lpf_forload);
                        TypeCheckPass(tloadnode(left).left);

                        pi:=CurrentProcInfo.get_first_nestedproc;
                        while assigned(pi) do
                          begin
                            if pi.procdef=pd then
                              break;
                            pi:=tprocinfo(pi.next);
                          end;

                        pi.set_needs_parentfp(TProcDef(tloadnode(left).symtable.defowner).parast.symtablelevel);
                      end;
                  end;
              end;
            resultdef:=totypedef;
          end
        else
         begin
           { only need the address of the method? this is needed
             for @tobject.create. In this case there will be a loadn without
             a methodpointer. }
           if (left.nodetype=loadn) and
              not assigned(tloadnode(left).left) and
              (not(m_nested_procvars in CurrentSettings.modeswitches) or
               not is_nested_pd(TAbstractProcDef(tloadnode(left).resultdef))) then
             copytype:=pc_address_only
           else
             copytype:=pc_normal;
           resultdef:=cprocvardef.getreusableprocaddr(pd,copytype);
         end;
      end;


    function ttypeconvnode.typecheck_procvar_2_funcref : TNode;
      var
        capturer : TSym;
        intfdef : TDef;
        ld,blck,hp : TNode;
        stmt : tstatementnode;
      begin
        result:=nil;

        if not(m_tp_procvar in CurrentSettings.modeswitches) and
           is_invokable(resultdef) and
           (left.nodetype=typeconvn) and
           (ttypeconvnode(left).convtype=tc_proc_2_procvar) and
           is_methodpointer(left.resultdef) and
           (po_classmethod in TProcVarDef(left.resultdef).procoptions) and
           not(po_staticmethod in TProcVarDef(left.resultdef).procoptions) and
           (proc_to_funcref_equal(TProcDef(ttypeconvnode(left).left.resultdef),TObjectDef(resultdef))>=te_convert_l1) then
          begin
            hp:=left;
            left:=ttypeconvnode(left).left;
            if (left.nodetype=loadn) and
               not assigned(tloadnode(left).left) then
              tloadnode(left).set_mp(cloadvmtaddrnode.create(ctypenode.create(TDef(tloadnode(left).symtable.defowner))));
            left:=ctypeconvnode.create_proc_to_procvar(left);
            ttypeconvnode(left).totypedef:=resultdef;
            TypeCheckPass(left);
            ttypeconvnode(hp).left:=nil;
            hp.free;
            hp := nil;
          end;

        intfdef:=capturer_add_procvar_or_proc(CurrentProcInfo,left,capturer,hp);
        if assigned(intfdef) then
          begin
            if assigned(capturer) then
              ld:=cloadnode.create(capturer,capturer.owner)
            else
              ld:=cnilnode.create;
            result:=ctypeconvnode.create_internal(
                      ctypeconvnode.create_internal(
                        ld,
                        intfdef),
                      totypedef);
            if assigned(hp) then
              begin
                blck:=internalstatements(stmt);
                addstatement(stmt,cassignmentnode.create(hp,left));
                left:=nil;
                addstatement(stmt,result);
                result:=blck;
              end;
          end;
        if not assigned(result) then
          result:=cerrornode.create;
      end;


    function ttypeconvnode.typecheck_anonproc_2_funcref : TNode;
      var
        capturer : TSym;
        intfdef : TDef;
        ldnode : TNode;
      begin
        intfdef:=capturer_add_anonymous_proc(CurrentProcInfo,TProcDef(left.resultdef),capturer);
        if assigned(intfdef) then
          begin
            if assigned(capturer) then
              ldnode:=cloadnode.create(capturer,capturer.owner)
            else
              ldnode:=cnilnode.create;
            result:=ctypeconvnode.create_internal(
                      ctypeconvnode.create_internal(
                        ldnode,
                        intfdef),
                      totypedef);
          end
        else
          result:=cerrornode.create;
      end;

    procedure ttypeconvnode.convert_deferred_stmt_expr;
    { A statement expression (if-, case-, try-expression) with anonymous
      functions as values is created without the assignments to its result
      temp, because the type of the temp is only known now (see pstatmnt).
      Retype the temp, add the assignments and typecheck again. }
      var
        stmt : tstatementnode;
        resulttemp : ttempcreatenode;
        valuenode,onnode : TNode;
        i : longint;

        procedure assign_to_temp(var n : TNode);
          begin
            if assigned(n) then
              n:=cassignmentnode.create(ctemprefnode.create(resulttemp),n);
          end;

      begin
        { skip the nothing node created by internalstatements }
        stmt:=tstatementnode(tblocknode(left).left);
        while stmt.left.nodetype=nothingn do
          stmt:=tstatementnode(stmt.right);

        resulttemp:=ttempcreatenode(stmt.left);
        resulttemp.tempinfo^.typedef:=resultdef;
        resulttemp.size:=resultdef.size;
        left.resultdef:=nil;

        { the statement computing the value }
        stmt:=tstatementnode(stmt.right);
        valuenode:=stmt.left;
        case valuenode.nodetype of
          ifn:
            begin
              assign_to_temp(tifnode(valuenode).right);
              assign_to_temp(tifnode(valuenode).t1);
              valuenode.resultdef:=nil;
            end;
          casen:
            begin
              for i:=0 to tcasenode(valuenode).blocks.count-1 do
                assign_to_temp(pcaseblock(tcasenode(valuenode).blocks[i])^.statement);
              assign_to_temp(tcasenode(valuenode).elseblock);
              valuenode.resultdef:=nil;
            end;
          tryexceptn:
            begin
              assign_to_temp(ttryexceptnode(valuenode).left);
              onnode:=ttryexceptnode(valuenode).right;
              while assigned(onnode) and (onnode.nodetype=onn) do
                begin
                  assign_to_temp(tonnode(onnode).right);
                  onnode:=tonnode(onnode).left;
                end;
              assign_to_temp(ttryexceptnode(valuenode).t1);
              valuenode.resultdef:=nil;
            end;
          else
            { simplified to a single value, e.g. constant condition }
            assign_to_temp(stmt.left);
        end;

        { the temp delete and temp ref }
        stmt:=tstatementnode(stmt.right);
        while assigned(stmt) do
          begin
            stmt.left.resultdef:=nil;
            stmt:=tstatementnode(stmt.right);
          end;

        TypeCheckPass(left);
      end;

    function ttypeconvnode.typecheck_call_helper(c : tconverttype) : TNode;
      const
         resultdefconvert : array[tconverttype] of pointer = (
          {none} nil,
          {equal} nil,
          {not_possible} nil,
          { string_2_string } @ttypeconvnode._typecheck_string_to_string,
          { char_2_string } @ttypeconvnode._typecheck_char_to_string,
          { char_2_chararray } @ttypeconvnode._typecheck_char_to_chararray,
          { pchar_2_string } @ttypeconvnode._typecheck_pchar_to_string,
          { cchar_2_pchar } @ttypeconvnode._typecheck_cchar_to_pchar,
          { cstring_2_pchar } @ttypeconvnode._typecheck_cstring_to_pchar,
          { cstring_2_int } @ttypeconvnode._typecheck_cstring_to_int,
          { ansistring_2_pchar } nil,
          { string_2_chararray } @ttypeconvnode._typecheck_string_to_chararray,
          { chararray_2_string } @ttypeconvnode._typecheck_chararray_to_string,
          { array_2_pointer } nil,
          { pointer_2_array } nil,
          { int_2_int } @ttypeconvnode._typecheck_int_to_int,
          { int_2_bool } nil,
          { bool_2_bool } nil,
          { bool_2_int } nil,
          { real_2_real } @ttypeconvnode._typecheck_real_to_real,
          { int_2_real } @ttypeconvnode._typecheck_int_to_real,
          { real_2_currency } @ttypeconvnode._typecheck_real_to_currency,
          { proc_2_procvar } @ttypeconvnode._typecheck_proc_to_procvar,
          { nil_2_methodprocvar } nil,
          { arrayconstructor_2_set } @ttypeconvnode._typecheck_arrayconstructor_to_set,
          { set_to_set } @ttypeconvnode._typecheck_set_to_set,
          { cord_2_pointer } @ttypeconvnode._typecheck_cord_to_pointer,
          { intf_2_string } @ttypeconvnode._typecheck_interface_to_string,
          { intf_2_guid } @ttypeconvnode._typecheck_interface_to_guid,
          { class_2_intf } nil,
          { char_2_char } @ttypeconvnode._typecheck_char_to_char,
          { dynarray_2_openarray} @ttypeconvnode._typecheck_dynarray_to_openarray,
          { pwchar_2_string} @ttypeconvnode._typecheck_pwchar_to_string,
          { variant_2_dynarray} @ttypeconvnode._typecheck_variant_to_dynarray,
          { dynarray_2_variant} @ttypeconvnode._typecheck_dynarray_to_variant,
          { variant_2_enum} @ttypeconvnode._typecheck_variant_to_enum,
          { enum_2_variant} @ttypeconvnode._typecheck_enum_to_variant,
          { variant_2_interface} @ttypeconvnode._typecheck_interface_to_variant,
          { interface_2_variant} @ttypeconvnode._typecheck_variant_to_interface,
          { array_2_dynarray} @ttypeconvnode._typecheck_array_2_dynarray,
          { elem_2_openarray } @ttypeconvnode._typecheck_elem_2_openarray,
          { arrayconstructor_2_dynarray } @ttypeconvnode._typecheck_arrayconstructor_to_dynarray,
          { arrayconstructor_2_array } @ttypeconvnode._typecheck_arrayconstructor_to_array,
          { anonproc_2_funcref } @ttypeconvnode._typecheck_anonproc_to_funcref,
          { procvar_2_funcref } @ttypeconvnode._typecheck_procvar_to_funcref
         );
      type
         tprocedureofobject = function : TNode of object;
      var
         r : TMethod;
      begin
         result:=nil;
         { this is a little bit dirty but it works }
         { and should be quite portable too        }
         r.Code:=resultdefconvert[c];
         r.Data:=self;
         if assigned(r.Code) then
          result:=tprocedureofobject(r)();
      end;


    function ttypeconvnode.pass_typecheck:TNode;
      var
        hdef : TDef;
        hp : TNode;
        currprocdef : TAbstractProcDef;
        aprocdef : TProcDef;
        eq : TEqualType;
        cdoptions : tcompare_defs_options;
        selfnode : TNode;
        newblock: tblocknode;
        newstatement: tstatementnode;
        tempnode: ttempcreatenode;
      begin
        result:=nil;
        resultdef:=totypedef;

        TypeCheckPass(left);
        if CodeGenError then
          exit;

        if is_deferred_stmt_expr(left) and
            ((resultdef.typ=procvardef) or is_funcref(resultdef)) then
          begin
            convert_deferred_stmt_expr;
            if CodeGenError then
              exit;
          end;

        { When absolute force tc_equal }
        if (nf_absolute in flags) then
          begin
            convtype:=tc_equal;
            { we need to check regability only if something is really regable }
            if ((TStoredDef(left.resultdef).is_intregable) or
               (TStoredDef(resultdef).is_fpuregable)) and
               (
               (TStoredDef(resultdef).is_intregable<>TStoredDef(left.resultdef).is_intregable) or
               (TStoredDef(resultdef).is_fpuregable<>TStoredDef(left.resultdef).is_fpuregable) or
               { like in pdecvar.read_absolute(): if the size changes, the
                 register size would also have to change (but second_nothing
                 does not handle this) }
               (TStoredDef(resultdef).size<>TStoredDef(left.resultdef).size)) then
              make_not_regable(left,[ra_addr_regable]);
            exit;
          end;

        { tp procvar support. Skip typecasts to procvar, record or set. Those
          convert on the procvar value. This is used to access the
          fields of a methodpointer }
        if not(nf_load_procvar in flags) and
           not(resultdef.typ in [procvardef,recorddef,setdef]) and
           not is_invokable(resultdef) and
           { in case of interface assignments of invokables they'll be converted
             to voidpointertype using an internal conversions; we must not call
             the invokable in that case }
           not (
             (nf_internal in flags) and
             is_invokable(left.resultdef)
           ) then
          maybe_call_procvar(left,true);

        if target_specific_general_typeconv then
          exit;

        if convtype=tc_none then
          begin
            cdoptions:=[cdo_allow_variant,cdo_warn_incompatible_univ];
            { overloaded operators require calls, which is not possible inside
              a constant declaration }
            if (block_type<>bt_const) and
               not(nf_internal in flags) then
              include(cdoptions,cdo_check_operator);
            if nf_explicit in flags then
              include(cdoptions,cdo_explicit);
            if nf_internal in flags then
              include(cdoptions,cdo_internal);
            aprocdef:=nil;
            eq:=compare_defs_ext(left.resultdef,resultdef,left.nodetype,convtype,aprocdef,cdoptions);
            case eq of
              te_exact,
              te_equal :
                begin
                  result := simplify(false);
                  if assigned(result) then
                    exit;

                  { in case of bitpacked accesses, the original type must
                    remain so that not too many/few bits are laoded }
                  if is_bitpacked_access(left) then
                    convtype:=tc_int_2_int;
                  { Only leave when there is no conversion to do.
                    We can still need to call a conversion routine,
                    like the routine to convert a stringconstnode }
                  if (convtype in [tc_equal,tc_not_possible]) and
                     { some conversions, like dynarray to pointer in Delphi
                       mode, must not be removed, because then we get memory
                       leaks due to missing temp finalization }
                     (not is_managed_type(left.resultdef) or
                     { different kinds of refcounted types may need calls
                       to different kinds of refcounting helpers }
                      (resultdef=left.resultdef)) then
                   begin

                       begin
                         left.resultdef:=resultdef;
                         if (nf_explicit in flags) and (left.nodetype = addrn) then
                           include(taddrnode(left).addrnodeflags,anf_typedaddr);
                         result:=left;
                         left:=nil;
                       end;
                     exit;
                   end;
                end;

              te_convert_l1,
              te_convert_l2,
              te_convert_l3,
              te_convert_l4,
              te_convert_l5,
              te_convert_l6:
                { nothing to do }
                ;

              te_convert_operator :
                begin
                  include(CurrentProcInfo.flags,pi_do_call);
                  addsymref(aprocdef.procsym,aprocdef);
                  hp:=ccallnode.create(ccallparanode.create(left,nil),TProcSym(aprocdef.procsym),nil,nil,[],nil);
                  { tell explicitly which def we must use !! (PM) }
                  tcallnode(hp).procdefinition:=aprocdef;
                  left:=nil;
                  result:=hp;
                  exit;
                end;

              te_incompatible :
                begin
                  { convert an array constructor to a set so that we still get
                    the error "set of Y incompatible to Z" instead of "array of
                    X incompatible to Z" }
                  if (resultdef.typ<>arraydef) and
                     is_array_constructor(left.resultdef) then
                    begin
                      arrayconstructor_to_set(left);
                      TypeCheckPass(left);
                    end;

                  { Procedures have a resultdef of voiddef and functions of their
                    own resultdef. They will therefore always be incompatible with
                    a procvar. Because isconvertable cannot check for procedures we
                    use an extra check for them.}
                  if (left.nodetype=calln) and
                     (tcallnode(left).required_para_count=0) and
                     (
                       (resultdef.typ=procvardef) or
                       is_invokable(resultdef)
                     ) and
                     (
                      (m_tp_procvar in CurrentSettings.modeswitches) or
                      (m_mac_procvar in CurrentSettings.modeswitches)
                     ) then
                   begin
                     if assigned(tcallnode(left).right) then
                      begin
                        { this is already a procvar, if it is really equal
                          is checked below }
                        convtype:=tc_equal;
                        hp:=tcallnode(left).right.getcopy;
                        currprocdef:=TAbstractProcDef(hp.resultdef);
                      end
                     else
                      begin
                        if resultdef.typ=procvardef then
                          begin
                            convtype:=tc_proc_2_procvar;
                            currprocdef:=TProcSym(Tcallnode(left).symtableprocentry).Find_procdef_byprocvardef(TProcVarDef(resultdef));
                          end
                        else
                          begin
                            convtype:=tc_procvar_2_funcref;
                            currprocdef:=TProcSym(tcallnode(left).symtableprocentry).find_procdef_byfuncrefdef(TObjectDef(resultdef));
                          end;
                        hp:=cloadnode.create_procvar(TProcSym(tcallnode(left).symtableprocentry),
                            TProcDef(currprocdef),tcallnode(left).symtableproc);
                        if (tcallnode(left).symtableprocentry.owner.symtabletype=ObjectSymtable) then
                         begin
                           selfnode:=tcallnode(left).methodpointer;
                           if assigned(selfnode) then
                            begin
                              { in case the nodetype is a typen, avoid the internal error
                                in set_mp and instead let the code error out normally }
                              if selfnode.nodetype<>typen then
                                tloadnode(hp).set_mp(selfnode.getcopy)
                            end
                           else
                             tloadnode(hp).set_mp(load_self_node);
                         end;
                        TypeCheckPass(hp);
                      end;
                     left.free;
                     left:=hp;
                     { Now check if the procedure we are going to assign to
                       the procvar, is compatible with the procvar's type }
                     if not(nf_explicit in flags) and
                        (
                          (
                            (resultdef.typ=procvardef) and
                            (proc_to_procvar_equal(currprocdef,TProcVarDef(resultdef),false)=te_incompatible)
                          ) or (
                            is_invokable(resultdef) and
                            (proc_to_funcref_equal(currprocdef,TObjectDef(resultdef))=te_incompatible)
                          )
                        ) then
                       IncompatibleTypes(left.resultdef,resultdef)
                     else
                       result:=typecheck_call_helper(convtype);
                     exit;
                   end
                  else if maybe_global_proc_to_nested(left,resultdef) or
                          maybe_classmethod_to_methodprocvar(left,resultdef) then
                    begin
                      result:=left;
                      left:=nil;
                      exit;
                    end;

                  { Handle explicit type conversions }
                  if nf_explicit in flags then
                   begin
                     { do common tc_equal cast, except when dealing with proc -> procvar
                       (may have to get rid of method pointer) }
                     if (left.resultdef.typ<>procdef) or
                        (resultdef.typ<>procvardef) then
                       convtype:=tc_equal
                     else
                       convtype:=tc_proc_2_procvar;

                     { ordinal constants can be resized to 1,2,4,8 bytes }
                     if (left.nodetype=ordconstn) then
                       begin
                         { Insert typeconv for ordinal to the correct size first on left, after
                           that the other conversion can be done }
                         hdef:=nil;
                         case longint(resultdef.size) of
                           1 :
                             hdef:=s8inttype;
                           2 :
                             hdef:=s16inttype;
                           4 :
                             hdef:=s32inttype;
                           8 :
                             hdef:=s64inttype;
                         end;
                         { we need explicit, because it can also be an enum }
                         if assigned(hdef) then
                           inserttypeconv_internal(left,hdef)
                         else
                           CGMessage2(type_e_illegal_type_conversion,left.resultdef.typename,resultdef.typename);
                       end;

                     { class/interface to class/interface, with checkobject support }
                     if is_class_or_interface_or_objc(resultdef) and
                        is_class_or_interface_or_objc(left.resultdef) then
                       begin
                         { check if the types are related }
                         if not(nf_internal in flags) and
                            (not(def_is_related(TObjectDef(left.resultdef),TObjectDef(resultdef)))) and
                            (not(def_is_related(TObjectDef(resultdef),TObjectDef(left.resultdef)))) then
                           begin
                             { Give an error when typecasting class to interface, this is compatible
                               with delphi }
                             if is_interface(resultdef) and
                                not is_interface(left.resultdef) then
                               CGMessage2(type_e_classes_not_related,
                                 FullTypeName(left.resultdef,resultdef),
                                 FullTypeName(resultdef,left.resultdef))
                             else
                               CGMessage2(type_w_classes_not_related,
                                 FullTypeName(left.resultdef,resultdef),
                                 FullTypeName(resultdef,left.resultdef))
                           end;

                         { Add runtime check? }
                         if not is_objc_class_or_protocol(resultdef) and
                            not is_objc_class_or_protocol(left.resultdef) and
                            (cs_check_object in CurrentSettings.localswitches) and
                            not(nf_internal in flags) then
                           begin
                             { we can translate the typeconvnode to 'as' when
                               typecasting to a class or interface }
                             { we need to make sure the result can still be
                               passed as a var parameter                    }
                             newblock:=internalstatements(newstatement);
                             if (valid_for_var(left,false)) then
                               begin
                                 tempnode:=ctempcreatenode.create(voidpointertype,voidpointertype.size,tt_persistent,true);
                                 addstatement(newstatement,tempnode);
                                 addstatement(newstatement,cassignmentnode.create(
                                   ctemprefnode.create(tempnode),
                                   caddrnode.create_internal(left)));
                                 left:=ctypeconvnode.create_internal(cderefnode.create(ctemprefnode.create(tempnode)),left.resultdef);
                               end
                             else
                               begin
                                 tempnode:=ctempcreatenode.create(left.resultdef,left.resultdef.size,tt_persistent,true);
                                 addstatement(newstatement,tempnode);
                                 addstatement(newstatement,cassignmentnode.create(
                                   ctemprefnode.create(tempnode),
                                   left));
                                 left:=ctemprefnode.create(tempnode);
                               end;
                             addstatement(newstatement,casnode.create(left.getcopy,cloadvmtaddrnode.create(ctypenode.create(resultdef))));
                             addstatement(newstatement,ctempdeletenode.create_normal_temp(tempnode));
                             addstatement(newstatement,ctypeconvnode.create_internal(left,resultdef));
                             left:=nil;
                             result:=newblock;
                             exit;
                           end;
                       end

                      else
                       begin
                         { only if the same size or formal def, and }
                         { don't allow type casting of constants to }
                         { structured types                         }
                         if not(
                                (left.resultdef.typ=formaldef) or
                                (
                                 is_void(left.resultdef)  and
                                 (left.nodetype=derefn)
                                ) or
                                (
                                 not(is_open_array(left.resultdef)) and
                                 not(is_array_constructor(left.resultdef)) and
                                 not(is_array_of_const(left.resultdef)) and
                                 { if the from type is an anonymous function then
                                   don't blindly convert it if the size is the same
                                   as compare_defs_ext already determined that the
                                   anonymous function is not compatible }
                                 not(
                                   (left.resultdef.typ=procdef) and
                                   (po_anonymous in TProcDef(left.resultdef).procoptions)
                                 ) and
                                 (left.resultdef.size=resultdef.size) and
                                 { disallow casts of const nodes }
                                 (not is_constnode(left) or
                                   { however, there are some exceptions }
                                   (not(resultdef.typ in [arraydef,recorddef,setdef,stringdef,
                                                          filedef,variantdef,objectdef]) or
                                   is_class_or_interface_or_objc(resultdef)
                                 ))
                                )
                               ) then
                           CGMessage2(type_e_illegal_type_conversion,left.resultdef.typename,resultdef.typename)
                         else
                           begin
                             { perform target-specific explicit typecast
                               checks }
                             if target_specific_explicit_typeconv then
                               begin
                                 result:=simplify(false);
                                 exit;
                               end;
                           end;
                       end;
                   end
                  else
                   IncompatibleTypes(left.resultdef,resultdef);
                end;
            end;
          end;
        { Give hint or warning for unportable code, exceptions are
           - typecasts from constants
           - void }
        if not(nf_internal in flags) and
           (left.nodetype<>ordconstn) and
           not(is_void(left.resultdef)) and
           (((left.resultdef.typ=orddef) and
             (resultdef.typ in [pointerdef,procvardef,classrefdef])) or
            ((resultdef.typ=orddef) and
             (left.resultdef.typ in [pointerdef,procvardef,classrefdef]))) then
          begin
            {Converting pointers to signed integers is a bad idea. Warn.}
            warn_pointer_to_signed:=(resultdef.typ=orddef) and (TOrdDef(resultdef).ordtype in [s8bit,s16bit,s32bit,s64bit]);
            { Give a warning when sizes don't match, because then info will be lost }
            if left.resultdef.size=resultdef.size then
              CGMessage(type_h_pointer_to_longint_conv_not_portable)
            else
              CGMessage(type_w_pointer_to_longint_conv_not_portable);
          end;

        { tc_cord_2_pointer still requires a type check, which
          simplify does not do }
        if (convtype<>tc_cord_2_pointer) then
          begin
            result := simplify(false);
            if assigned(result) then
              exit;
          end;

        { now call the resultdef helper to do constant folding }
        result:=typecheck_call_helper(convtype);
      end;

{ some code generators for 64 bit CPUs might not support 32 bit operations, so we can
  disable the following optimization in fpcdefs.inc. Currently the only CPU for which
  this applies is powerpc64
}
{$ifndef CPUNO32BITOPS}
    { checks whether we can safely remove typeconversions to bigger types
      in case range and overflow checking are off, and in case
      the result of this node tree is downcasted again to a
      smaller type value afterwards,

      the smaller types being allowed are described by validints, ordinal constants must fit into l..h

      We do this on 64 bit CPUs as well, they benefit from it as well }

    function checkremovebiginttypeconvs(n: TNode; out gotsint: boolean;validints : TOrdTypeSet;const l,h : Tconstexprint): boolean;
      var
        gotminus1,
        gotsigned,
        gotunsigned,
        gotdivmod: boolean;

      { checks whether a node has an accepted resultdef, or originally
        had one but was implicitly converted to s64bit                 }
      function wasoriginallysmallerint(n: TNode): boolean;
        begin
          if (n.resultdef.typ<>orddef) then
            exit(false);
          gotsigned:=gotsigned or is_signed(n.resultdef);
          gotunsigned:=gotunsigned or not(is_signed(n.resultdef));
          { actually, we should only check right (denominator) nodes here, but
            setting it always is a safe approximation }
          if ((n.nodetype=ordconstn) and
            (tordconstnode(n).value=-1)) then
            gotminus1:=true;
          if (TOrdDef(n.resultdef).ordtype in validints) then
            begin
              if is_signed(n.resultdef) then
                gotsint:=true;
              exit(true);
            end;
          { type conv to a bigger int, we do not like to use? }
          if (TOrdDef(n.resultdef).ordtype in ([s8bit,u8bit,s16bit,u16bit,s32bit,u32bit,s64bit,u64bit]-validints)) and
             { nf_explicit is also set for explicitly typecasted }
             { ordconstn's                                       }
             ([nf_internal,nf_explicit]*n.flags=[]) and
             { either a typeconversion node coming from a smaller type }
             (((n.nodetype=typeconvn) and
               (ttypeconvnode(n).left.resultdef.typ=orddef) and
               (TOrdDef(ttypeconvnode(n).left.resultdef).ordtype in validints)) or
             { or an ordconstnode which has a smaller type}
              ((n.nodetype=ordconstn) and
               (tordconstnode(n).value>=l) and
               (tordconstnode(n).value<=h))) then
            begin
              if ((n.nodetype=typeconvn) and
                  is_signed(ttypeconvnode(n).left.resultdef)) or
                 ((n.nodetype=ordconstn) and
                  (tordconstnode(n).value<0)) then
                begin
                  gotsint:=true;
                  gotsigned:=true;
                end
              else
                gotunsigned:=true;
              exit(true);
            end;
          result:=false;
        end;


      function docheckremoveinttypeconvs(n: TNode): boolean;
        begin
          if wasoriginallysmallerint(n) then
            exit(true);
          case n.nodetype of
            subn,orn,xorn:
              begin
                { the result could become negative in this case }
                if n.nodetype=subn then
                  gotsint:=true;
                result:=
                  docheckremoveinttypeconvs(TBinaryNode(n).left) and
                  docheckremoveinttypeconvs(TBinaryNode(n).right);
              end;
            unaryminusn:
              begin
                gotsint:=true;
                result:=docheckremoveinttypeconvs(TUnaryNode(n).left);
              end;
            shrn:
              begin
                result:=wasoriginallysmallerint(TBinaryNode(n).left) and
                  docheckremoveinttypeconvs(TBinaryNode(n).right);
              end;
            notn:
              result:=docheckremoveinttypeconvs(TUnaryNode(n).left);
            addn,muln,divn,modn,andn,shln:
              begin
                if n.nodetype in [divn,modn] then
                  gotdivmod:=true;
                result:=
                  (docheckremoveinttypeconvs(TBinaryNode(n).left) and
                   docheckremoveinttypeconvs(TBinaryNode(n).right) and

                   (not(n.nodetype in [modn,divn]) or (not(gotminus1)))
                  ) or
                  (
                    (n.nodetype=andn) and
                    (
                      { Right node is more likely to be a constant, so check
                        this one first }
                      wasoriginallysmallerint(TBinaryNode(n).right) or
                      wasoriginallysmallerint(TBinaryNode(n).left)
                    )
                  );
              end;
            else
              result:=false;
          end;
        end;

      begin { checkremove64bittypeconvs }
        gotdivmod:=false;
        gotsint:=false;
        gotminus1:=false;
        gotsigned:=false;
        gotunsigned:=false;
        result:=
          docheckremoveinttypeconvs(n) and
          (not(gotdivmod) or (gotsigned xor gotunsigned));
      end;


    { remove int type conversions and set the result to the given type }
    procedure doremoveinttypeconvs(level : dword;var n: TNode; todef: TDef; forceunsigned: boolean; signedtype,unsignedtype : TDef);

      function SmallerOrSigned(def: TDef): Boolean;
        begin
          Result := (def.size < signedtype.size) or
            (
              (def.size = signedtype.size) and
              is_signed(def)
            )
        end;

      var
        newblock: tblocknode;
        newstatements: tstatementnode;
        originaldivtree: TNode;
        tempnode: ttempcreatenode;
        NeedMinus1Check: Boolean;
      begin
        { we may not recurse into shr nodes:

          dword1:=dword1+((dword2+dword3) shr 2);

          while we can remove an extension on the outermost addition, we cannot
          remove it from the shr
        }
        { Don't downsize into a division operation either, as the numerator can
          be much larger than the result and non-linear properties prevent
          accurate truncation; fixes #39646 [Kit] }
        if (n.nodetype in [shrn,divn,modn]) and (level<>0) then
          begin
            inserttypeconv_internal(n,todef);
            exit;
          end;
        case n.nodetype of
          subn,addn,muln,divn,modn,xorn,andn,orn,shln,shrn:
            begin
              exclude(n.flags,nf_internal);
              if not forceunsigned and
                 is_signed(n.resultdef) then
                begin
                  originaldivtree:=nil;
                  NeedMinus1Check:=False;

                  if n.nodetype in [divn,modn] then
                    begin
                      { If the DIV operation is being downsized, we must explicitly check for a divisor of -1 }
                      NeedMinus1Check := True;

                      { If the operand size is equal or smaller, the -1 check isn't necessary }
                      if (
                          SmallerOrSigned(TBinaryNode(n).left.resultdef) or
                          (
                            (TBinaryNode(n).left.nodetype = typeconvn) and
                            SmallerOrSigned(ttypeconvnode(TBinaryNode(n).left).left.resultdef)
                          )
                        ) and
                        (
                          SmallerOrSigned(TBinaryNode(n).right.resultdef) or
                          (
                            (TBinaryNode(n).right.nodetype = typeconvn) and
                            SmallerOrSigned(ttypeconvnode(TBinaryNode(n).right).left.resultdef)
                          )
                        ) then
                        NeedMinus1Check := False;
                    end;


                  if NeedMinus1Check then
                    originaldivtree:=n.getcopy;

                  doremoveinttypeconvs(level+1,TBinaryNode(n).left,signedtype,false,signedtype,unsignedtype);
                  doremoveinttypeconvs(level+1,TBinaryNode(n).right,signedtype,false,signedtype,unsignedtype);
                  n.resultdef:=signedtype;

                  if NeedMinus1Check then
                    begin
                      newblock:=internalstatements(newstatements);
                      tempnode:=ctempcreatenode.create(n.resultdef,n.resultdef.size,tt_persistent,true);
                      addstatement(newstatements,tempnode);
                      addstatement(newstatements,cifnode.create_internal(
                        caddnode.create_internal(equaln,TBinaryNode(n).right.getcopy,cordconstnode.create(-1,n.resultdef,false)),
                          cassignmentnode.create_internal(
                            ctemprefnode.create(tempnode),
                            cmoddivnode.create(n.nodetype,TBinaryNode(originaldivtree).left.getcopy,cordconstnode.create(-1,TBinaryNode(originaldivtree).right.resultdef,false))
                          ),
                          cassignmentnode.create_internal(
                            ctemprefnode.create(tempnode),n
                          )
                        )
                      );
                      addstatement(newstatements,ctempdeletenode.create_normal_temp(tempnode));
                      addstatement(newstatements,ctemprefnode.create(tempnode));
                      n:=newblock;
                      DoTypeCheckPass(n);
                      originaldivtree.free;
                      originaldivtree := nil;
                    end;
                end
              else
                begin
                  doremoveinttypeconvs(level+1,TBinaryNode(n).left,unsignedtype,forceunsigned,signedtype,unsignedtype);
                  doremoveinttypeconvs(level+1,TBinaryNode(n).right,unsignedtype,forceunsigned,signedtype,unsignedtype);
                  n.resultdef:=unsignedtype;
                end;
              //if ((n.nodetype=andn) and (tbinarynode(n).left.nodetype=ordconstn) and
              //    ((tordconstnode(tbinarynode(n).left).value and $7fffffff)=tordconstnode(tbinarynode(n).left).value)
              //   ) then
              //  inserttypeconv_internal(tbinarynode(n).right,n.resultdef)
              //else if (n.nodetype=andn) and (tbinarynode(n).right.nodetype=ordconstn) and
              //  ((tordconstnode(tbinarynode(n).right).value and $7fffffff)=tordconstnode(tbinarynode(n).right).value) then
              //  inserttypeconv_internal(tbinarynode(n).left,n.resultdef);
            end;
          unaryminusn,notn:
            begin
              exclude(n.flags,nf_internal);
              if not forceunsigned and
                 is_signed(n.resultdef) then
                begin
                  doremoveinttypeconvs(level+1,TUnaryNode(n).left,signedtype,false,signedtype,unsignedtype);
                  n.resultdef:=signedtype;
                end
              else
                begin
                  doremoveinttypeconvs(level+1,TUnaryNode(n).left,unsignedtype,forceunsigned,signedtype,unsignedtype);
                  n.resultdef:=unsignedtype;
                end;
            end;
          typeconvn:
            begin
              ttypeconvnode(n).totypedef:=todef;
              { may change the type conversion, e.g. if the old conversion was
                from 64 bit to a 64 bit, and now becomes 64 bit to 32 bit }
              n.resultdef:=nil;
              ttypeconvnode(n).convtype:=tc_none;
              TypeCheckPass(n);
            end;
          else
            inserttypeconv_internal(n,todef);
        end;
      end;
{$endif not CPUNO32BITOPS}

    procedure swap_const_value (var val : TConstExprInt; size : longint);
      begin
        case size of
          1 : {do nothing };
          2 : if val.signed then
                val.svalue:=swapendian(smallint(val.svalue))
              else
                val.uvalue:=swapendian(word(val.uvalue));
          4 : if val.signed then
                val.svalue:=swapendian(longint(val.svalue))
              else
                val.uvalue:=swapendian(qword(val.uvalue));
          8 : if val.signed then
                val.svalue:=swapendian(int64(val.svalue))
              else
                val.uvalue:=swapendian(qword(val.uvalue));
	  else
            internalerror(2014111201);
        end;
      end;

    function ttypeconvnode.simplify(forinline : boolean): TNode;
      var
        hp: TNode;
        v: Tconstexprint;
        f: bestreal;
{$ifndef CPUNO32BITOPS}
        foundsint: boolean;
{$endif not CPUNO32BITOPS}
      begin
        result := nil;
        { Constant folding and other node transitions to
          remove the typeconv node }
        case left.nodetype of
          stringconstn :
            if (resultdef.typ=stringdef) and
               ((convtype=tc_equal) or
                ((convtype=tc_string_2_string) and
                 (
                  ((not is_widechararray(left.resultdef) and
                    not is_wide_or_unicode_string(left.resultdef)) or
                   (TStringDef(resultdef).stringtype in [st_widestring,st_unicodestring,st_ansistring])
                  )
                 )
                )
               ) then
              begin
                { output string consts in local ansistring encoding }
                if is_ansistring(resultdef) and
                  { do not mess with the result type for internally created nodes }
                  not(nf_internal in flags) and
                  ((TStringDef(resultdef).encoding=0) or (TStringDef(resultdef).encoding=globals.CP_NONE)) then
                  tstringconstnode(left).changestringtype(getansistringdef)
                else
                  tstringconstnode(left).changestringtype(resultdef);
                result:=left;
                left:=nil;
                exit;
              end
            else if
              (convtype<>tc_cstring_2_pchar)  and
              is_dynamicstring(left.resultdef) and
              (tstringconstnode(left).len=0) and
              (resultdef.typ=pointerdef) and
              cstringconstnode.emptydynstrnil then
            begin
              result:=cnilnode.create;
              exit;
            end;

          realconstn :
            begin
              if (convtype = tc_real_2_currency) then
                result := typecheck_real_to_currency
              else if (convtype = tc_real_2_real) then
                result := typecheck_real_to_real
              else
                exit;
              if not(assigned(result)) then
                begin
                  result := left;
                  left := nil;
                end;
              if (result.nodetype = realconstn) then
                begin
                  hp:=result;
                  result:=crealconstnode.create(trealconstnode(hp).value_real,resultdef);
                  if nf_is_currency in hp.flags then
                    include(result.flags,nf_is_currency);
                  if ([nf_explicit,nf_internal] * flags <> []) then
                    include(result.flags, nf_explicit);
                  hp.free;
                  hp := nil;
                end;
            end;

          niln :
            begin
              { nil to ordinal node }
              if (resultdef.typ=orddef) then
               begin
                 hp:=cordconstnode.create(0,resultdef,true);
                 if ([nf_explicit,nf_internal] * flags <> []) then
                   include(hp.flags, nf_explicit);
                 result:=hp;
                 exit;
               end
              else
               { fold nil to any pointer type }
               if (resultdef.typ=pointerdef) then
                begin
                  hp:=cnilnode.create;
                  hp.resultdef:=resultdef;
                  if ([nf_explicit,nf_internal] * flags <> []) then
                    include(hp.flags, nf_explicit);
                  result:=hp;
                  exit;
                end
              else
               { remove typeconv after niln, but not when the result is a
                 methodpointer. The typeconv of the methodpointer will then
                 take care of updating size of niln to OS_64 }
               if not((resultdef.typ=procvardef) and
                      not(TProcVarDef(resultdef).is_addressonly)) and
                  { converting (dynamic array) nil to a an open array is not allowed }
                  not is_open_array(resultdef) then
                 begin
                   left.resultdef:=resultdef;
                   if ([nf_explicit,nf_internal] * flags <> []) then
                     include(left.flags, nf_explicit);
                   result:=left;
                   left:=nil;
                   exit;
                 end;
            end;

          ordconstn :
            begin
              { ordinal constants can be directly converted }
              { but not char to char because it is a widechar to char or via versa }
              { which needs extra code to do the code page transistion             }
              { constant ordinal to pointer }
              if (resultdef.typ=pointerdef) and
                 (convtype<>tc_cchar_2_pchar) then
                begin
                   hp:=cpointerconstnode.create(TConstPtrUInt(tordconstnode(left).value.uvalue),resultdef);
                   if ([nf_explicit,nf_internal] * flags <> []) then
                     include(hp.flags, nf_explicit);
                   result:=hp;
                   exit;
                end
              else if is_ordinal(resultdef) and
                      not(convtype=tc_char_2_char) then
                begin
                   { replace the resultdef and recheck the range }
                   if ([nf_explicit,nf_absolute, nf_internal] * flags <> []) then
                     include(left.flags, nf_explicit)
                   else
                     { no longer an ordconst with an explicit typecast }
                     exclude(left.flags, nf_explicit);
                   { when converting from one boolean type to another, force }
                   { booleans to 0/1, and byte/word/long/qwordbool to 0/-1   }
                   { (Delphi-compatible)                                     }
                   if is_boolean(left.resultdef) and
                      is_boolean(resultdef) and
                      (is_cbool(left.resultdef) or
                       is_cbool(resultdef)) then
                     begin
                       if is_pasbool(resultdef) then
                         tordconstnode(left).value:=ord(tordconstnode(left).value<>0)
                       else
                         tordconstnode(left).value:=-ord(tordconstnode(left).value<>0);
                     end
                   else
                     begin
                       { for constant values on absolute variables, swapping is required }
                       if (TargetInfo.endian = endian_big) and (nf_absolute in flags) then
                         swap_const_value(tordconstnode(left).value,tordconstnode(left).resultdef.size);
                       if not(nf_generic_para in flags) then
                          adaptrange(
                            resultdef,tordconstnode(left).value,
                            { when evaluating an explicit typecast during inlining, don't warn about
                              lost bits; only warn if someone literally typed e.g. byte($1ff) }
                            (([nf_internal,nf_absolute]*flags)<>[]) or (forinline and (nf_explicit in flags)),
                            nf_explicit in flags,
                            cs_check_range in localswitches);
                       { swap value back, but according to new type }
                       if (TargetInfo.endian = endian_big) and (nf_absolute in flags) then
                         swap_const_value(tordconstnode(left).value,resultdef.size);

                       { cut off the new value? }
                       if resultdef.size<left.resultdef.size then
                         case resultdef.size of
                           1:
                             if is_signed(resultdef) then
                               tordconstnode(left).value:=tordconstnode(left).value and shortint($ff)
                             else
                               tordconstnode(left).value:=tordconstnode(left).value and byte($ff);
                           2:
                             if is_signed(resultdef) then
                               tordconstnode(left).value:=tordconstnode(left).value and smallint($ffff)
                             else
                               tordconstnode(left).value:=tordconstnode(left).value and word($ffff);
                           4:
                             if is_signed(resultdef) then
                               tordconstnode(left).value:=tordconstnode(left).value and longint($ffffffff)
                             else
                               tordconstnode(left).value:=tordconstnode(left).value and dword($ffffffff);
                         end;
                     end;
                   left.resultdef:=resultdef;
                   tordconstnode(left).typedef:=resultdef;
                   if is_signed(resultdef) then
                     tordconstnode(left).value.signed:=true
                   else
                     tordconstnode(left).value.signed:=false;
                   result:=left;
                   left:=nil;
                   exit;
                end
              else if (convtype=tc_int_2_int) and
                is_currency(resultdef) then
                begin
                  v:=tordconstnode(left).value;
                  if (nf_is_currency in flags) and not(nf_internal in flags) and not(nf_is_currency in left.flags) then
                    begin
                      result:=cordconstnode.create(v*10000,resultdef,false);
                      Include(result.flags, nf_is_currency);
                    end
                  else
                    result:=cordconstnode.create(v,resultdef,false);
                  exit;
                end
              else if (convtype=tc_int_2_real) and
                is_currency(resultdef) then
                begin
                  if (resultdef.typ<>floatdef) then
                    { It should be a floating-point-based Currency if int-to-real was selected }
                    InternalError(2024091801);

                  f := bestreal(tordconstnode(left).value);
                  if not(nf_internal in flags) and not(nf_is_currency in left.flags) then
                    begin
                      result:=crealconstnode.create(f*BestReal(10000.0),resultdef);
                      Include(result.flags,nf_is_currency);
                    end
                  else
                    result:=crealconstnode.create(f,resultdef);
                  exit;
                end;
            end;

          pointerconstn :
            begin
              { pointerconstn to any pointer is folded too }
              if (resultdef.typ=pointerdef) then
                begin
                   left.resultdef:=resultdef;
                   if ([nf_explicit,nf_internal] * flags <> []) then
                     include(left.flags, nf_explicit)
                   else
                     { no longer an ordconst with an explicit typecast }
                     exclude(left.flags, nf_explicit);
                   result:=left;
                   left:=nil;
                   exit;
                end
              { constant pointer to ordinal }
              else if is_ordinal(resultdef) then
                begin
                   hp:=cordconstnode.create(TConstExprInt(tpointerconstnode(left).value),
                     resultdef,not(nf_explicit in flags));
                   if ([nf_explicit,nf_internal] * flags <> []) then
                     include(hp.flags, nf_explicit);
                   result:=hp;
                   exit;
                end;
            end;
          else
            ;
        end;
{$ifndef CPUNO32BITOPS}
        { must be done before code below, because we need the
          typeconversions for ordconstn's as well }
        case convtype of
          tc_bool_2_int,
          tc_int_2_bool,
          tc_int_2_int:
            begin
              if (localswitches * [cs_check_range,cs_check_overflow] = []) and
                 (resultdef.typ in [pointerdef,orddef,enumdef]) then
                begin
                  { avoid unnecessary widening of intermediary calculations
                    to 64 bit                                               }
                  if (resultdef.size <= 4) and
                    is_64bitint(left.resultdef) and
                    (left.nodetype in [subn,addn,muln,divn,modn,xorn,andn,orn,notn,unaryminusn,shln,shrn]) and
                    checkremovebiginttypeconvs(left,foundsint,[s8bit,u8bit,s16bit,u16bit,s32bit,u32bit],int64(low(longint)),high(cardinal)) then
                    doremoveinttypeconvs(0,left,generrordef,not foundsint,s32inttype,u32inttype);


                  { the above simplification may have left a redundant equal
                    typeconv (e.g. int32 to int32). If that's the case, we remove it }
                  if equal_defs(left.resultdef,resultdef) then
                    begin
                      result:=left;
                      left:=nil;
                      exit;
                    end;
                  if (convtype=tc_int_2_int) and (left.nodetype=typeconvn) and (ttypeconvnode(left).convtype=tc_bool_2_int) then
                    begin
                      ttypeconvnode(left).totypedef:=resultdef;
                      ttypeconvnode(left).resultdef:=resultdef;
                      result:=left;
                      left:=nil;
                      exit;
                    end;
                end;
            end;
          else
            ;
        end;
{$endif not CPUNO32BITOPS}
      end;


    procedure Ttypeconvnode.mark_write;
      begin
        if not(convtype=tc_pointer_2_array) then
          left.mark_write;
      end;

    function ttypeconvnode.first_cord_to_pointer : TNode;

      begin
        result:=nil;
        internalerror(200104043);
      end;


    function ttypeconvnode.first_int_to_int : TNode;

      begin
        first_int_to_int:=nil;
        expectloc:=left.expectloc;
        if not is_void(left.resultdef) then
          begin
            if (left.expectloc<>LOC_REGISTER) and
                ((resultdef.size>left.resultdef.size) or
                 (left.expectloc in [LOC_SUBSETREF,LOC_CSUBSETREF,LOC_SUBSETREG,LOC_CSUBSETREG])) then
              expectloc:=LOC_REGISTER
            else
              if (left.expectloc=LOC_CREGISTER) and
                 (resultdef.size<left.resultdef.size) then
                expectloc:=LOC_REGISTER;
          end;
      end;


    function ttypeconvnode.first_cstring_to_pchar : TNode;

      begin
         result:=nil;
         expectloc:=LOC_REGISTER;
      end;


    function ttypeconvnode.first_cstring_to_int : TNode;

      begin
        result:=nil;
        internalerror(200510014);
      end;


    function ttypeconvnode.first_string_to_chararray : TNode;

      begin
         first_string_to_chararray:=nil;
         expectloc:=left.expectloc;
      end;


    function ttypeconvnode.first_char_to_string : TNode;

      begin
         first_char_to_string:=nil;
         if TStringDef(resultdef).stringtype=st_shortstring then
           inc(CurrentProcInfo.estimatedtempsize,256);
         expectloc:=LOC_REFERENCE;
      end;


    function ttypeconvnode.first_char_to_chararray : TNode;

      begin
        if resultdef.size <> 1 then
          begin
            { convert first to string, then to chararray }
            inserttypeconv(left,cshortstringtype);
            inserttypeconv(left,resultdef);
            result:=left;
            left := nil;
            exit;
          end;
        result := nil;
      end;


    function ttypeconvnode.first_nothing : TNode;
      begin
         first_nothing:=nil;
      end;


    function ttypeconvnode.first_array_to_pointer : TNode;

      begin
         first_array_to_pointer:=nil;
         make_not_regable(left,[ra_addr_regable]);
         expectloc:=LOC_REGISTER;
      end;


    function ttypeconvnode.first_int_to_real: TNode;
      var
        fname: string[32];
      begin
        begin
            { converting a 64bit integer to a float requires a helper }
            if is_64bitint(left.resultdef) or
              is_currency(left.resultdef) then
              begin
                { hack to avoid double division by 10000, as it's
                  already done by typecheckpass.resultdef_int_to_real }
                if is_currency(left.resultdef) then
                  left.resultdef := s64inttype;
                if is_signed(left.resultdef) then
                  fname:='int64_to_'
                else
                  { we can't do better currently }
                  fname:='qword_to_';
              end
            else
              { other integers are supposed to be 32 bit }
              begin
                if is_signed(left.resultdef) then
                  fname:='int32_to_'
                else
                  fname:='int64_to_';
                FirstPass(left);
              end;
            if TFloatDef(resultdef).floattype=s64real then
              fname:=fname+'float64'
            else
              fname:=fname+'float32';
            result:=ctypeconvnode.create_internal(ccallnode.createintern(fname,ccallparanode.create(
              left,nil)),resultdef);
            left:=nil;
            FirstPass(result);
            exit;
          end;
      end;


    function ttypeconvnode.first_real_to_real : TNode;
      begin
        first_real_to_real:=nil;
        if not use_vectorfpu(resultdef) then
          expectloc:=LOC_FPUREGISTER
        else
          expectloc:=LOC_MMREGISTER;
      end;


    function ttypeconvnode.first_pointer_to_array : TNode;

      begin
         first_pointer_to_array:=nil;
         expectloc:=LOC_REFERENCE;
      end;


    function ttypeconvnode.first_cchar_to_pchar : TNode;

      begin
         first_cchar_to_pchar:=nil;
         internalerror(200104021);
      end;


    function ttypeconvnode.first_bool_to_int : TNode;

      begin
         first_bool_to_int:=nil;
         { byte(boolean) or word(wordbool) or longint(longbool) must
           be accepted for var parameters }
         if (nf_explicit in flags) and
            (left.resultdef.size=resultdef.size) and
            (left.expectloc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_CREGISTER]) then
           begin
             expectloc:=left.expectloc;
             exit;
           end;
         expectloc:=LOC_REGISTER;
      end;


    function ttypeconvnode.first_int_to_bool : TNode;

      begin
         first_int_to_bool:=nil;
         { byte(boolean) or word(wordbool) or longint(longbool) must
           be accepted for var parameters }
         if (nf_explicit in flags) and
            (left.resultdef.size=resultdef.size) and
            (left.expectloc in [LOC_REFERENCE,LOC_CREFERENCE,LOC_CREGISTER]) then
           begin
             expectloc:=left.expectloc;
             exit;
           end;
         { when converting 64bit int to C-ctyle boolean, first convert to an int32 and then }
         { convert to a boolean (only necessary for 32bit processors) }
         { note: not if left is already a bool (qwordbool that is true, even if
             only because the highest bit is set, must remain true if it is
             --implicitly, unlike integers-- converted to another type of bool),
             Left can already be a bool because this routine can also be called
             from first_bool_to_bool }
         if not is_boolean(left.resultdef) and
            (left.resultdef.size > sizeof(aint)) and
            (left.resultdef.size<>resultdef.size)
            and is_cbool(resultdef) then
           begin
             left:=ctypeconvnode.create_internal(left,s32inttype);
             FirstPass(left);
             exit;
           end;
         expectloc:=LOC_REGISTER;
      end;


    function ttypeconvnode.first_bool_to_bool : TNode;
      begin
         first_bool_to_bool:=nil;
         if (left.expectloc in [LOC_FLAGS,LOC_JUMP]) and
            not is_cbool(resultdef) then
           expectloc := left.expectloc
         { the following cases use the code generation for bool_to_int/
           int_to_bool -> also set their expectlocs }
         else if (resultdef.size=left.resultdef.size) and
            (is_cbool(resultdef)=is_cbool(left.resultdef)) then
           result:=first_bool_to_int
         else
           result:=first_int_to_bool
      end;


    function ttypeconvnode.first_char_to_char : TNode;
      var
        fname: string[18];
      begin
        if (TOrdDef(resultdef).ordtype=uchar) and
           (TOrdDef(left.resultdef).ordtype=uwidechar) then
          fname := 'fpc_uchar_to_char'
        else if (TOrdDef(resultdef).ordtype=uwidechar) and
           (TOrdDef(left.resultdef).ordtype=uchar) then
          fname := 'fpc_char_to_uchar'
        else
          internalerror(2007081201);

        result := ccallnode.createintern(fname,ccallparanode.create(left,nil));
        left:=nil;
        FirstPass(result);
      end;


    function ttypeconvnode.first_proc_to_procvar : TNode;
      begin
         first_proc_to_procvar:=nil;
         { if we take the address of a nested function, the current function/
           procedure needs a stack frame since it's required to construct
           the nested procvar }
         if is_nested_pd(TProcVarDef(resultdef)) and
            (
              not (po_anonymous in TProcDef(left.resultdef).procoptions) or
              (po_delphi_nested_cc in TProcVarDef(resultdef).procoptions)
            ) then
           include(CurrentProcInfo.flags,pi_needs_stackframe);
         if TAbstractProcDef(resultdef).is_addressonly then
           expectloc:=LOC_REGISTER
         else
           expectloc:=left.expectloc;
      end;


    function ttypeconvnode.first_nil_to_methodprocvar : TNode;
      begin
        first_nil_to_methodprocvar:=nil;
        expectloc:=LOC_REGISTER;
      end;


    function ttypeconvnode.first_set_to_set : TNode;
      var
        newstatement : tstatementnode;
        temp         : ttempcreatenode;
      begin
        { in theory, we should do range checking here,
          but Delphi doesn't do it either (FK) }

        if left.nodetype=setconstn then
          begin
            left.resultdef:=resultdef;
            result:=left;
            left:=nil;
          end
        { equal sets for the code generator? }
        else if (left.resultdef.size=resultdef.size) and
                (TSetDef(left.resultdef).setbase=TSetDef(resultdef).setbase) then
          { TODO: This causes wrong (but Delphi-compatible) results for disjoint subsets}
          { e.g., this prints true because of this:
              var
                sa: set of 1..2;
                sb: set of 5..6;
                b: byte;
              begin
                b:=1;
                sa:=[1..2];
                sb:=sa;
                writeln(b in sb);
              end.
          }
          begin
            result:=left;
            left:=nil;
          end
        else
          begin
            result:=internalstatements(newstatement);

            { in case left is a smallset expression, it can be an addn or so. }
            { fpc_varset_load expects a formal const parameter, which doesn't }
            { accept set addn's -> assign to a temp first and pass the temp   }
            if not(left.expectloc in [LOC_REFERENCE,LOC_CREFERENCE]) then
              begin
                temp:=ctempcreatenode.create(left.resultdef,left.resultdef.size,tt_persistent,false);
                addstatement(newstatement,temp);
                { temp := left }
                addstatement(newstatement,cassignmentnode.create(
                  ctemprefnode.create(temp),left));
                addstatement(newstatement,ctempdeletenode.create_normal_temp(temp));
                addstatement(newstatement,ctemprefnode.create(temp));
                left:=result;
                FirstPass(left);
                { recreate the result's internalstatements list }
                result:=internalstatements(newstatement);
              end;

            { create temp for result }
            temp:=ctempcreatenode.create(resultdef,resultdef.size,tt_persistent,true);
            addstatement(newstatement,temp);

            addstatement(newstatement,ccallnode.createintern('fpc_varset_load',
              ccallparanode.create(cordconstnode.create(TSetDef(left.resultdef).setbase div 8 - TSetDef(resultdef).setbase div 8,sinttype,false),
              ccallparanode.create(cordconstnode.create(resultdef.size,sinttype,false),
              ccallparanode.create(ctemprefnode.create(temp),
              ccallparanode.create(cordconstnode.create(left.resultdef.size,sinttype,false),
              ccallparanode.create(left,nil))))))
            );
            addstatement(newstatement,ctempdeletenode.create_normal_temp(temp));
            addstatement(newstatement,ctemprefnode.create(temp));
            left:=nil;
          end;
      end;


    function ttypeconvnode.first_ansistring_to_pchar : TNode;
      begin
         first_ansistring_to_pchar:=nil;
         expectloc:=LOC_REGISTER;
      end;


    function ttypeconvnode.first_arrayconstructor_to_set : TNode;
      begin
        first_arrayconstructor_to_set:=nil;
        internalerror(200104022);
      end;


    function ttypeconvnode.first_class_to_intf : TNode;
      var
        hd : TObjectDef;
        ImplIntf : TImplementedInterface;
      begin
         result:=nil;
         expectloc:=LOC_REGISTER;
         hd:=TObjectDef(left.resultdef);
         while assigned(hd) do
           begin
             ImplIntf:=find_implemented_interface(hd,TObjectDef(resultdef));
             if assigned(ImplIntf) then
               begin
                 case ImplIntf.IType of
                   etStandard:
                     { handle in pass 2 }
                     ;
                   etFieldValue, etFieldValueClass:
                     if is_interface(TObjectDef(resultdef)) then
                       begin
                         result:=left;
                         propaccesslist_to_node(result,TPropertySym(implintf.implementsgetter).owner,TPropertySym(implintf.implementsgetter).propaccesslist[palt_read]);
                         { this ensures proper refcounting when field is of class type }
                         if not is_interface(result.resultdef) then
                           inserttypeconv(result, resultdef);
                         left:=nil;
                       end
                     else
                       begin
                         internalerror(200802213);
                       end;
                   etStaticMethodResult, etStaticMethodClass,
                   etVirtualMethodResult, etVirtualMethodClass:
                     if is_interface(TObjectDef(resultdef)) then
                       begin
                         { TODO: generating a call to TObject.GetInterface instead could yield
                           smaller code size. OTOH, refcounting gotchas are possible that way. }
                         { constructor create(l:tnode; v : tprocsym;st : TSymtable; mp: tnode; callflags:tcallnodeflags); }
                         result:=ccallnode.create(nil,TProcSym(TPropertySym(implintf.implementsgetter).propaccesslist[palt_read].firstsym^.sym),
                           TProcSym(TPropertySym(implintf.implementsgetter).propaccesslist[palt_read].firstsym^.sym).owner,
                           left,[],nil);
                         addsymref(TPropertySym(implintf.implementsgetter).propaccesslist[palt_read].firstsym^.sym);
                         { if it is a class, process it further in a similar way }
                         if not is_interface(result.resultdef) then
                           inserttypeconv(result, resultdef);
                         left:=nil;
                       end
                     else if is_class(TObjectDef(resultdef)) then
                       begin
                         internalerror(200802211);
                       end
                     else
                       internalerror(200802231);
                 end;
                 break;
               end;
             hd:=hd.childof;
           end;
         if hd=nil then
           internalerror(200802164);
      end;


    function ttypeconvnode.first_string_to_string : TNode;
      var
        procname: string[31];
        newblock : tblocknode;
        newstat  : tstatementnode;
        restemp  : ttempcreatenode;
      begin
        { get the correct procedure name }
        procname := 'fpc_'+TStringDef(left.resultdef).stringtypname+
                    '_to_'+TStringDef(resultdef).stringtypname;

        if TStringDef(resultdef).stringtype=st_shortstring then
          begin
            newblock:=internalstatements(newstat);
            restemp:=ctempcreatenode.create(resultdef,resultdef.size,tt_persistent,false);
            addstatement(newstat,restemp);
            addstatement(newstat,ccallnode.createintern(procname,ccallparanode.create(left,ccallparanode.create(
              ctemprefnode.create(restemp),nil))));
            addstatement(newstat,ctempdeletenode.create_normal_temp(restemp));
            addstatement(newstat,ctemprefnode.create(restemp));
            result:=newblock;
          end
        { encoding parameter required? }
        else if (TStringDef(resultdef).stringtype=st_ansistring) and
                (TStringDef(left.resultdef).stringtype in [st_widestring,st_unicodestring,st_shortstring,st_ansistring]) then
            result:=ccallnode.createinternres(procname,
              ccallparanode.create(cordconstnode.create(getparaencoding(resultdef),u16inttype,true),
              ccallparanode.create(left,nil)),resultdef)
        else
          result:=ccallnode.createinternres(procname,ccallparanode.create(left,nil),resultdef);

        left:=nil;
      end;


    function ttypeconvnode._first_int_to_int : TNode;
      begin
         result:=first_int_to_int;
      end;

    function ttypeconvnode._first_cstring_to_pchar : TNode;
      begin
         result:=first_cstring_to_pchar;
      end;

    function ttypeconvnode._first_cstring_to_int : TNode;
      begin
         result:=first_cstring_to_int;
      end;

    function ttypeconvnode._first_string_to_chararray : TNode;
      begin
         result:=first_string_to_chararray;
      end;

    function ttypeconvnode._first_char_to_string : TNode;
      begin
         result:=first_char_to_string;
      end;

    function ttypeconvnode._first_char_to_chararray: TNode;
      begin
        result:=first_char_to_chararray;
      end;

    function ttypeconvnode._first_nothing : TNode;
      begin
         result:=first_nothing;
      end;

    function ttypeconvnode._first_array_to_pointer : TNode;
      begin
         result:=first_array_to_pointer;
      end;

    function ttypeconvnode._first_int_to_real : TNode;
      begin
         result:=first_int_to_real;
      end;

    function ttypeconvnode._first_real_to_real : TNode;
      begin
         result:=first_real_to_real;
      end;

    function ttypeconvnode._first_pointer_to_array : TNode;
      begin
         result:=first_pointer_to_array;
      end;

    function ttypeconvnode._first_cchar_to_pchar : TNode;
      begin
         result:=first_cchar_to_pchar;
      end;

    function ttypeconvnode._first_bool_to_int : TNode;
      begin
         result:=first_bool_to_int;
      end;

    function ttypeconvnode._first_int_to_bool : TNode;
      begin
         result:=first_int_to_bool;
      end;

    function ttypeconvnode._first_bool_to_bool : TNode;
      begin
         result:=first_bool_to_bool;
      end;

    function ttypeconvnode._first_proc_to_procvar : TNode;
      begin
         result:=first_proc_to_procvar;
      end;

    function ttypeconvnode._first_nil_to_methodprocvar : TNode;
      begin
         result:=first_nil_to_methodprocvar;
      end;

    function ttypeconvnode._first_set_to_set : TNode;
      begin
         result:=first_set_to_set;
      end;

    function ttypeconvnode._first_cord_to_pointer : TNode;
      begin
         result:=first_cord_to_pointer;
      end;

    function ttypeconvnode._first_ansistring_to_pchar : TNode;
      begin
         result:=first_ansistring_to_pchar;
      end;

    function ttypeconvnode._first_arrayconstructor_to_set : TNode;
      begin
         result:=first_arrayconstructor_to_set;
      end;

    function ttypeconvnode._first_class_to_intf : TNode;
      begin
         result:=first_class_to_intf;
      end;

    function ttypeconvnode._first_char_to_char : TNode;
      begin
         result:=first_char_to_char;
      end;

    function ttypeconvnode._first_string_to_string : TNode;
      begin
        result:=first_string_to_string;
      end;

    function ttypeconvnode.first_call_helper(c : tconverttype) : TNode;

      const
         firstconvert : array[tconverttype] of pointer = (
           nil, { none }
           @ttypeconvnode._first_nothing, {equal}
           @ttypeconvnode._first_nothing, {not_possible}
           @ttypeconvnode._first_string_to_string,
           @ttypeconvnode._first_char_to_string,
           @ttypeconvnode._first_char_to_chararray,
           nil, { removed in typecheck_chararray_to_string }
           @ttypeconvnode._first_cchar_to_pchar,
           @ttypeconvnode._first_cstring_to_pchar,
           @ttypeconvnode._first_cstring_to_int,
           @ttypeconvnode._first_ansistring_to_pchar,
           @ttypeconvnode._first_string_to_chararray,
           nil, { removed in typecheck_chararray_to_string }
           @ttypeconvnode._first_array_to_pointer,
           @ttypeconvnode._first_pointer_to_array,
           @ttypeconvnode._first_int_to_int,
           @ttypeconvnode._first_int_to_bool,
           @ttypeconvnode._first_bool_to_bool,
           @ttypeconvnode._first_bool_to_int,
           @ttypeconvnode._first_real_to_real,
           @ttypeconvnode._first_int_to_real,
           nil, { removed in typecheck_real_to_currency }
           @ttypeconvnode._first_proc_to_procvar,
           @ttypeconvnode._first_nil_to_methodprocvar,
           @ttypeconvnode._first_arrayconstructor_to_set,
           @ttypeconvnode._first_set_to_set,
           @ttypeconvnode._first_cord_to_pointer,
           @ttypeconvnode._first_nothing,
           @ttypeconvnode._first_nothing,
           @ttypeconvnode._first_class_to_intf,
           @ttypeconvnode._first_char_to_char,
           @ttypeconvnode._first_nothing,
           @ttypeconvnode._first_nothing,
           nil,
           nil,
           nil,
           nil,
           nil,
           nil,
           nil,
           @ttypeconvnode._first_nothing,
           @ttypeconvnode._first_nothing,
           @ttypeconvnode._first_nothing,
           nil,
           nil
         );
      type
         tprocedureofobject = function : TNode of object;
      var
         r : TMethod;
      begin
         { this is a little bit dirty but it works }
         { and should be quite portable too        }
         r.Code:=firstconvert[c];
         r.Data:=self;
         if not assigned(r.Code) then
           internalerror(200312081);
         first_call_helper:=tprocedureofobject(r)()
      end;


    function ttypeconvnode.pass_1 : TNode;
      begin
        if warn_pointer_to_signed then
          cgmessage(type_w_pointer_to_signed);
        result:=nil;
        FirstPass(left);
        if CodeGenError then
         exit;
        expectloc:=left.expectloc;

        if nf_explicit in flags then
          { check if the result could be in a register }
          if (not(TStoredDef(resultdef).is_intregable) and
              not(TStoredDef(resultdef).is_const_intregable) and
              not(TStoredDef(resultdef).is_fpuregable)) or
             ((left.resultdef.typ = floatdef) and
              (resultdef.typ <> floatdef))  then
            make_not_regable(left,[ra_addr_regable]);

        result:=first_call_helper(convtype);
      end;


    function ttypeconvnode.retains_value_location:boolean;
      begin
        result:=assigned(left.resultdef) and
                (
                (convtype=tc_equal) or
                { typecasting from void is always allowed }
                is_void(left.resultdef) or
                (left.resultdef.typ=formaldef) or
                { int 2 int with same size reuses same location }
                (
                 (convtype=tc_int_2_int) and
                 (
                  not is_bitpacked_access(left) and
                  (resultdef.size=left.resultdef.size)
                 )
                ) or
                { int 2 bool/bool 2 int, explicit typecast, see also nx86cnv }
                ((convtype in [tc_int_2_bool,tc_bool_2_int,tc_bool_2_bool]) and
                 (nf_explicit in flags) and
                 (resultdef.size=left.resultdef.size)) or
                { on managed platforms, converting an element to an open array
                  involves creating an actual array -> value location changes }
                (convtype=tc_elem_2_openarray)
                );
      end;


    function ttypeconvnode.assign_allowed:boolean;
      begin
        result:=retains_value_location;

        { When using only a part of the value it can't be in a register since
          that will load the value in a new register first }
        { the same goes for changing the sign of equal-sized values which
          are smaller than an entire register }
        if result and
           { don't try to check the size of an open array or an array of const }
           (is_open_array(resultdef) or
            is_open_array(left.resultdef) or
            is_array_of_const(resultdef) or
            is_array_of_const(left.resultdef) or
            (resultdef.size<left.resultdef.size) or
            ((resultdef.size=left.resultdef.size) and
             (left.resultdef.size<sizeof(aint)) and
             (is_signed(resultdef) xor is_signed(left.resultdef)))) then
          make_not_regable(left,[ra_addr_regable]);
      end;


    function ttypeconvnode.docompare(p: TNode) : boolean;
      begin
        docompare :=
          inherited docompare(p) and
          (convtype = ttypeconvnode(p).convtype) and
          (convnodeflags = ttypeconvnode(p).convnodeflags) and
          equal_defs(totypedef,ttypeconvnode(p).totypedef);
      end;


    procedure ttypeconvnode._second_int_to_int;
      begin
        second_int_to_int;
      end;


    procedure ttypeconvnode._second_string_to_string;
      begin
        second_string_to_string;
      end;


    procedure ttypeconvnode._second_cstring_to_pchar;
      begin
        second_cstring_to_pchar;
      end;


    procedure ttypeconvnode._second_cstring_to_int;
      begin
        second_cstring_to_int;
      end;


    procedure ttypeconvnode._second_string_to_chararray;
      begin
        second_string_to_chararray;
      end;


    procedure ttypeconvnode._second_array_to_pointer;
      begin
        second_array_to_pointer;
      end;


    procedure ttypeconvnode._second_pointer_to_array;
      begin
        second_pointer_to_array;
      end;


    procedure ttypeconvnode._second_chararray_to_string;
      begin
        second_chararray_to_string;
      end;


    procedure ttypeconvnode._second_char_to_string;
      begin
        second_char_to_string;
      end;


    procedure ttypeconvnode._second_int_to_real;
      begin
        second_int_to_real;
      end;


    procedure ttypeconvnode._second_real_to_real;
      begin
        second_real_to_real;
      end;


    procedure ttypeconvnode._second_cord_to_pointer;
      begin
        second_cord_to_pointer;
      end;


    procedure ttypeconvnode._second_proc_to_procvar;
      begin
        second_proc_to_procvar;
      end;

    procedure ttypeconvnode._second_nil_to_methodprocvar;
      begin
        second_nil_to_methodprocvar;
      end;

    procedure ttypeconvnode._second_bool_to_int;
      begin
        second_bool_to_int;
      end;


    procedure ttypeconvnode._second_int_to_bool;
      begin
        second_int_to_bool;
      end;


    procedure ttypeconvnode._second_bool_to_bool;
      begin
        second_bool_to_bool;
      end;


    procedure ttypeconvnode._second_set_to_set;
      begin
        second_set_to_set;
      end;


    procedure ttypeconvnode._second_ansistring_to_pchar;
      begin
        second_ansistring_to_pchar;
      end;


    procedure ttypeconvnode._second_class_to_intf;
      begin
        second_class_to_intf;
      end;


    procedure ttypeconvnode._second_char_to_char;
      begin
        second_char_to_char;
      end;


    procedure ttypeconvnode._second_elem_to_openarray;
      begin
        second_elem_to_openarray;
      end;


    procedure ttypeconvnode._second_nothing;
      begin
        second_nothing;
      end;


    procedure ttypeconvnode.second_call_helper(c : tconverttype);
      const
         secondconvert : array[tconverttype] of pointer = (
           @ttypeconvnode._second_nothing, {none}
           @ttypeconvnode._second_nothing, {equal}
           @ttypeconvnode._second_nothing, {not_possible}
           @ttypeconvnode._second_nothing, {second_string_to_string, handled in resultdef pass }
           @ttypeconvnode._second_char_to_string,
           @ttypeconvnode._second_nothing, {char_to_charray}
           @ttypeconvnode._second_nothing, { pchar_to_string, handled in resultdef pass }
           @ttypeconvnode._second_nothing, {cchar_to_pchar}
           @ttypeconvnode._second_cstring_to_pchar,
           @ttypeconvnode._second_cstring_to_int,
           @ttypeconvnode._second_ansistring_to_pchar,
           @ttypeconvnode._second_string_to_chararray,
           @ttypeconvnode._second_nothing, { chararray_to_string, handled in resultdef pass }
           @ttypeconvnode._second_array_to_pointer,
           @ttypeconvnode._second_pointer_to_array,
           @ttypeconvnode._second_int_to_int,
           @ttypeconvnode._second_int_to_bool,
           @ttypeconvnode._second_bool_to_bool,
           @ttypeconvnode._second_bool_to_int,
           @ttypeconvnode._second_real_to_real,
           @ttypeconvnode._second_int_to_real,
           @ttypeconvnode._second_nothing, { real_to_currency, handled in resultdef pass }
           @ttypeconvnode._second_proc_to_procvar,
           @ttypeconvnode._second_nil_to_methodprocvar,
           @ttypeconvnode._second_nothing, { arrayconstructor_to_set }
           @ttypeconvnode._second_nothing, { second_set_to_set, handled in first pass }
           @ttypeconvnode._second_cord_to_pointer,
           @ttypeconvnode._second_nothing, { interface 2 string }
           @ttypeconvnode._second_nothing, { interface 2 guid   }
           @ttypeconvnode._second_class_to_intf,
           @ttypeconvnode._second_char_to_char,
           @ttypeconvnode._second_nothing,  { dynarray_2_openarray }
           @ttypeconvnode._second_nothing,  { pwchar_2_string }
           @ttypeconvnode._second_nothing,  { variant_2_dynarray }
           @ttypeconvnode._second_nothing,  { dynarray_2_variant}
           @ttypeconvnode._second_nothing,  { variant_2_enum }
           @ttypeconvnode._second_nothing,  { enum_2_variant }
           @ttypeconvnode._second_nothing,  { variant_2_interface }
           @ttypeconvnode._second_nothing,  { interface_2_variant }
           @ttypeconvnode._second_nothing,  { array_2_dynarray }
           @ttypeconvnode._second_elem_to_openarray,  { elem_2_openarray }
           @ttypeconvnode._second_nothing,  { arrayconstructor_2_dynarray }
           @ttypeconvnode._second_nothing,  { arrayconstructor_2_array }
           @ttypeconvnode._second_nothing,  { anonproc_2_funcref }
           @ttypeconvnode._second_nothing   { procvar_2_funcref }
         );
      type
         tprocedureofobject = procedure of object;

      var
         r : TMethod;

      begin
         { this is a little bit dirty but it works }
         { and should be quite portable too        }
         r.Code:=secondconvert[c];
         r.Data:=self;
         tprocedureofobject(r)();
      end;

{*****************************************************************************
                                TASNODE
*****************************************************************************}

    function tasisnode.target_specific_typecheck: boolean;
      begin
        result:=false;
      end;


    function tasisnode.pass_typecheck: TNode;
      var
        hp : TNode;
      begin
        result:=nil;
        TypeCheckPass(right);
        TypeCheckPass(left);

        set_varstate(right,vs_read,[vsf_must_be_valid]);
        set_varstate(left,vs_read,[vsf_must_be_valid]);

        if CodeGenError then
          exit;

        if target_specific_typecheck then
          begin
            // ok
          end
        else if (right.resultdef.typ=classrefdef) then
          begin
            { left maybe an interface reference }
            if is_interfacecom(left.resultdef) or
               is_javainterface(left.resultdef) then
              begin
                { relation checks are not possible }
              end
            { or left must be a class }
            else if is_class(left.resultdef) or
                    is_javaclass(left.resultdef) then
              begin
                { the operands must be related }
                if (not(def_is_related(TObjectDef(left.resultdef),
                   TObjectDef(TClassRefDef(right.resultdef).pointeddef)))) and
                   (not(def_is_related(TObjectDef(TClassRefDef(right.resultdef).pointeddef),
                   TObjectDef(left.resultdef)))) then
                  CGMessage2(type_e_classes_not_related,
                     FullTypeName(left.resultdef,TClassRefDef(right.resultdef).pointeddef),
                     FullTypeName(TClassRefDef(right.resultdef).pointeddef,left.resultdef));
              end
            else
              CGMessage1(type_e_class_or_cominterface_type_expected,left.resultdef.typename);
            case nodetype of
              isn:
                resultdef:=pasbool1type;
              asn:
                resultdef:=TClassRefDef(right.resultdef).pointeddef;
              else
                ;
            end;
          end
        else if is_interface(right.resultdef) or
                is_dispinterface(right.resultdef) or
                is_javainterface(right.resultdef) then
          begin
           case nodetype of
             isn:
               resultdef:=pasbool1type;
             asn:
               resultdef:=right.resultdef;
             else
               ;
           end;

            { left is a class or interface }
            if is_javainterface(right.resultdef) then
              begin
                if not is_java_class_or_interface(left.resultdef) then
                  CGMessage1(type_e_class_or_cominterface_type_expected,left.resultdef.typename);
              end
            else if not(is_class(left.resultdef) or
                   is_interfacecom(left.resultdef)) then
              CGMessage1(type_e_class_or_cominterface_type_expected,left.resultdef.typename)
            else
              begin

                { load the GUID of the interface }
                if (right.nodetype=typen) then
                  begin
                    if TObjectDef(right.resultdef).objecttype=odt_interfacecorba then
                      begin
                        if assigned(TObjectDef(right.resultdef).iidstr) then
                          begin
                            if not(oo_has_valid_guid in TObjectDef(right.resultdef).objectoptions) and not is_typeparam(right.resultdef) then
                              CGMessage1(type_e_interface_has_no_name,TObjectDef(right.resultdef).typename);
                            hp:=cstringconstnode.createstr(TObjectDef(right.resultdef).iidstr^);
                            tstringconstnode(hp).changestringtype(cshortstringtype);
                            right.free;
                            right:=hp;
                          end
                        else
                          internalerror(201006131);
                      end
                    else
                      begin
                        if assigned(TObjectDef(right.resultdef).iidguid) then
                          begin
                            if not(oo_has_valid_guid in TObjectDef(right.resultdef).objectoptions) and not is_typeparam(right.resultdef) then
                              CGMessage1(type_e_interface_has_no_guid,TObjectDef(right.resultdef).typename);
                            hp:=cguidconstnode.create(TObjectDef(right.resultdef).iidguid^);
                            right.free;
                            right:=hp;
                          end
                        else
                          internalerror(201006132);
                      end;
                    TypeCheckPass(right);
                  end;
              end;
          end
        else
          CGMessage1(type_e_class_or_interface_type_expected,right.resultdef.typename);
      end;

{*****************************************************************************
                                TISNODE
*****************************************************************************}

    constructor tisnode.create(l,r : TNode);

      begin
         inherited create(isn,l,r);
      end;


    constructor tisnode.create_internal(l, r: TNode);

      begin
        create(l,r);
        include(flags,nf_internal);
      end;


    function tisnode.pass_1 : TNode;
      var
        procname: string;
        statement : tstatementnode;
        tempnode : ttempcreatenode;
      begin
        result:=nil;
        { Passing a class type to an "is" expression cannot result in a class
          of that type to be constructed.
        }
        include(right.flags,nf_ignore_for_wpo);

        if is_class(left.resultdef) and
           (right.resultdef.typ=classrefdef) then
          begin
            if (right.nodetype=loadvmtaddrn) and
              (tloadvmtaddrnode(right).left.nodetype=typen) and
              (oo_is_sealed in TObjectDef(tloadvmtaddrnode(right).left.resultdef).objectoptions) and
              equal_defs(left.resultdef,TClassRefDef(right.resultdef).pointeddef) then
              begin
                if might_have_sideeffects(left) or
                  (node_complexity(left)>2) then
                  begin
                    result:=internalstatements(statement);
                    tempnode:=ctempcreatenode.create(left.resultdef,left.resultdef.size,tt_persistent,true);
                    addstatement(statement,tempnode);
                    addstatement(statement,cassignmentnode.create_internal(ctemprefnode.create(tempnode),left));
                    addstatement(statement,caddnode.create_internal(andn,
                      caddnode.create_internal(unequaln,ctemprefnode.create(tempnode),cnilnode.create),
                      caddnode.create_internal(equaln,cloadvmtaddrnode.create(ctemprefnode.create(tempnode)),right)
                      )
                    );

                    left:=nil;
                    right:=nil;
                  end
                else
                  begin
                    result:=caddnode.create_internal(andn,
                      caddnode.create_internal(unequaln,left.getcopy,cnilnode.create),
                      caddnode.create_internal(equaln,cloadvmtaddrnode.create(left.getcopy),right)
                      );
                    right:=nil;
                  end;
              end
            else
              result := ccallnode.createinternres('fpc_do_is',
                ccallparanode.create(left,ccallparanode.create(right,nil)),
                resultdef);
          end
        else
          begin
            if is_class(left.resultdef) then
              if is_shortstring(right.resultdef) then
                procname := 'fpc_class_is_corbaintf'
              else
                procname := 'fpc_class_is_intf'
            else
              if right.resultdef.typ=classrefdef then
                procname := 'fpc_intf_is_class'
              else
                procname := 'fpc_intf_is';
            result := ctypeconvnode.create_internal(ccallnode.createintern(procname,
               ccallparanode.create(right,ccallparanode.create(left,nil))),resultdef);
          end;
        left := nil;
        right := nil;
        //firstpass(call);
        if CodeGenError then
          exit;
      end;

    { dummy pass_2, it will never be called, but we need one since }
    { you can't instantiate an abstract class                      }
    procedure tisnode.pass_generate_code;
      begin
      end;


{*****************************************************************************
                                TASNODE
*****************************************************************************}

    constructor tasnode.create(l,r : TNode);

      begin
         inherited create(asn,l,r);
         call := nil;
      end;


    constructor tasnode.create_internal(l,r : TNode);

      begin
        create(l,r);
        include(flags,nf_internal);
      end;


    destructor tasnode.destroy;

      begin
        call.free;
        call := nil;
        inherited destroy;
      end;


    function tasnode.dogetcopy: TNode;
      begin
        result := inherited dogetcopy;
        if assigned(call) then
          tasnode(result).call := call.getcopy
        else
          tasnode(result).call := nil;
      end;


    function tasnode.docompare(p: TNode): boolean;
      begin
        result:=
          inherited docompare(p) and
          tasnode(p).call.isequal(call);
      end;


    function tasnode.pass_1 : TNode;
      var
        procname: string;
      begin
        result:=nil;
        { Passing a class type to an "as" expression cannot result in a class
          of that type to be constructed.

          We could put this inside the if-block below, but this way it is
          safe for sure even if the code below changes
        }
        if assigned(right) then
          include(right.flags,nf_ignore_for_wpo);

        if not assigned(call) then
          begin
            if is_class(left.resultdef) and
               (right.resultdef.typ=classrefdef) then
              call := ccallnode.createinternres('fpc_do_as',
                ccallparanode.create(left,ccallparanode.create(right,nil)),
                resultdef)
            else
              begin
                if is_class(left.resultdef) then
                  if is_shortstring(right.resultdef) then
                    procname := 'fpc_class_as_corbaintf'
                  else
                    procname := 'fpc_class_as_intf'
                else
                  if right.resultdef.typ=classrefdef then
                    procname := 'fpc_intf_as_class'
                  else
                    procname := 'fpc_intf_as';
                call := ctypeconvnode.create_internal(ccallnode.createintern(procname,
                   ccallparanode.create(right,ccallparanode.create(left,nil))),resultdef);
              end;
            left := nil;
            right := nil;
            FirstPass(call);
            if CodeGenError then
              exit;
           expectloc:=call.expectloc;
         end;
      end;

end.
